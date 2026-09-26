-- DuelRules (pure). Street Duels decision logic: challenge validation, stake parsing and gating, the duel
-- state machine, settlement (who is paid what, with which CommandId) and plausibility inputs.
-- No game services, no instances, no require: tests load this file with loadstring.
local DuelRules = {}

DuelRules.DEFAULT_STAKES = { 0, 5000, 25000, 100000 }
DuelRules.MAX_STAKE = 1000000 -- EconomyServer GrantCash per-command limit; a pot (2x stake) must stay under it

-- State machine ------------------------------------------------------------------------------------------
DuelRules.States = {
	Challenged = "Challenged",
	Accepted = "Accepted",
	Countdown = "Countdown",
	Racing = "Racing",
	Finished = "Finished",
	Forfeit = "Forfeit",
	Draw = "Draw",
	Expired = "Expired",
	Declined = "Declined",
}

-- Allowed transitions. Terminal states have no outgoing edges. Money is only escrowed from Accepted onwards,
-- so Expired/Declined (reachable only from Challenged) never move Cash.
DuelRules.Transitions = {
	Challenged = { Accepted = true, Expired = true, Declined = true },
	Accepted = { Countdown = true, Forfeit = true, Draw = true },
	Countdown = { Racing = true, Forfeit = true, Draw = true },
	Racing = { Finished = true, Forfeit = true, Draw = true },
	Finished = {},
	Forfeit = {},
	Draw = {},
	Expired = {},
	Declined = {},
}

function DuelRules.canTransition(from, to)
	local edges = DuelRules.Transitions[from]
	return edges ~= nil and edges[to] == true
end

function DuelRules.isTerminal(state)
	local edges = DuelRules.Transitions[state]
	return edges ~= nil and next(edges) == nil
end

-- True while stakes may be held in escrow (Accepted, Countdown, Racing).
function DuelRules.holdsEscrow(state)
	return state == "Accepted" or state == "Countdown" or state == "Racing"
end

-- Returns the new state or nil plus a reason; callers keep the old state on failure.
function DuelRules.transition(duel, to)
	if not DuelRules.canTransition(duel.State, to) then
		return nil, string.format("illegal duel transition %s -> %s", tostring(duel.State), tostring(to))
	end
	duel.State = to
	return to
end

-- Stakes -------------------------------------------------------------------------------------------------
local function wholeNonNegative(value)
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number == -math.huge then return nil end
	if number < 0 or number ~= math.floor(number) then return nil end
	return number
end

-- "0,5000,25000,100000" -> sorted unique whole amounts in [0, MAX_STAKE]; 0 (Free) is always present.
-- Garbage entries are dropped; an empty or unusable string falls back to DEFAULT_STAKES.
function DuelRules.parseStakes(text)
	local seen, list = {}, {}
	if type(text) == "string" then
		for token in string.gmatch(text, "[^,%s]+") do
			local amount = wholeNonNegative(token)
			if amount and amount <= DuelRules.MAX_STAKE and not seen[amount] then
				seen[amount] = true
				table.insert(list, amount)
			end
		end
	end
	if #list == 0 then
		for _, amount in ipairs(DuelRules.DEFAULT_STAKES) do
			table.insert(list, amount)
			seen[amount] = true
		end
	end
	if not seen[0] then table.insert(list, 0) end
	table.sort(list)
	return list
end

-- options = { Stakes, StakesEnabled, MinRank, ChallengerRank, TargetRank, PairStakeBlocked?, ChallengerCanAfford,
--   TargetCanAfford }
-- (CanAfford values are booleans for this exact stake). Returns ok, code.
function DuelRules.validateStake(stake, options)
	local amount = wholeNonNegative(stake)
	if amount == nil then return false, "StakeInvalid" end
	local listed = false
	for _, allowed in ipairs(options.Stakes or DuelRules.DEFAULT_STAKES) do
		if allowed == amount then listed = true break end
	end
	if not listed then return false, "StakeNotOffered" end
	if amount == 0 then return true, nil end
	if options.StakesEnabled ~= true then return false, "StakesDisabled" end
	local minRank = tonumber(options.MinRank) or 3
	if (tonumber(options.ChallengerRank) or 0) < minRank then return false, "ChallengerRank" end
	if (tonumber(options.TargetRank) or 0) < minRank then return false, "TargetRank" end
	if options.PairStakeBlocked == true then return false, "PairLimit" end
	if options.ChallengerCanAfford ~= true then return false, "ChallengerFunds" end
	if options.TargetCanAfford ~= true then return false, "TargetFunds" end
	return true, nil
end

-- Stakes both players may use. affordable(amount) -> (challengerOk, targetOk).
function DuelRules.availableStakes(options, affordable)
	local out = {}
	for _, amount in ipairs(options.Stakes or DuelRules.DEFAULT_STAKES) do
		local copy = table.clone(options)
		if amount > 0 then
			copy.ChallengerCanAfford, copy.TargetCanAfford = affordable(amount)
		end
		if DuelRules.validateStake(amount, copy) then table.insert(out, amount) end
	end
	return out
end

-- Challenge limiter (cooldown per challenger, pair mute after repeated ignores/declines) -------------------
-- limiter = DuelRules.newLimiter(); all functions take an explicit `now` (seconds, any monotonic clock).
function DuelRules.newLimiter()
	return { LastChallenge = {}, Rejections = {}, MutedUntil = {}, PairStakes = {} }
end

local function pairKey(fromId, toId)
	return tostring(fromId) .. ">" .. tostring(toId)
end
DuelRules.pairKey = pairKey

-- options = { Cooldown = 20, } ; returns ok, code, secondsLeft
function DuelRules.limiterAllows(limiter, now, fromId, toId, options)
	local cooldown = tonumber(options and options.Cooldown) or 20
	local last = limiter.LastChallenge[fromId]
	if last and now - last < cooldown then
		return false, "Cooldown", cooldown - (now - last)
	end
	local muted = limiter.MutedUntil[pairKey(fromId, toId)]
	if muted and now < muted then
		return false, "Muted", muted - now
	end
	return true, nil, 0
end

function DuelRules.recordChallenge(limiter, now, fromId)
	limiter.LastChallenge[fromId] = now
end

-- An ignored (expired) or declined challenge. After `MuteAfter` in a row the pair is muted for MuteSeconds.
function DuelRules.recordRejection(limiter, now, fromId, toId, options)
	local key = pairKey(fromId, toId)
	local count = (limiter.Rejections[key] or 0) + 1
	local muteAfter = tonumber(options and options.MuteAfter) or 3
	if count >= muteAfter then
		limiter.MutedUntil[key] = now + (tonumber(options and options.MuteSeconds) or 300)
		count = 0
	end
	limiter.Rejections[key] = count
	return count
end

function DuelRules.recordAccepted(limiter, fromId, toId)
	limiter.Rejections[pairKey(fromId, toId)] = nil
end

-- Staked duels per unordered pair in a rolling hour (anti-collusion cap on Cash moved between two players).
local PAIR_STAKE_WINDOW = 3600
local function unorderedKey(a, b)
	a, b = tonumber(a) or 0, tonumber(b) or 0
	if a > b then a, b = b, a end
	return tostring(a) .. ":" .. tostring(b)
end

function DuelRules.pairStakeCount(limiter, now, a, b)
	local count = 0
	for _, at in ipairs(limiter.PairStakes[unorderedKey(a, b)] or {}) do
		if now - at < PAIR_STAKE_WINDOW then count += 1 end
	end
	return count
end

function DuelRules.pairStakeAllowed(limiter, now, a, b, limitPerHour)
	return DuelRules.pairStakeCount(limiter, now, a, b) < (tonumber(limitPerHour) or 3)
end

function DuelRules.recordPairStake(limiter, now, a, b)
	local key = unorderedKey(a, b)
	local rows = limiter.PairStakes[key] or {}
	table.insert(rows, now)
	limiter.PairStakes[key] = rows
end

-- Drop entries that no longer affect decisions (call occasionally).
function DuelRules.pruneLimiter(limiter, now, cooldown)
	for id, at in pairs(limiter.LastChallenge) do
		if now - at >= (cooldown or 20) then limiter.LastChallenge[id] = nil end
	end
	for key, untilAt in pairs(limiter.MutedUntil) do
		if now >= untilAt then limiter.MutedUntil[key] = nil end
	end
	for key, rows in pairs(limiter.PairStakes) do
		for i = #rows, 1, -1 do
			if now - rows[i] >= PAIR_STAKE_WINDOW then table.remove(rows, i) end
		end
		if #rows == 0 then limiter.PairStakes[key] = nil end
	end
end

-- Challenge validation -----------------------------------------------------------------------------------
DuelRules.Messages = {
	Disabled = "Street Duels are off right now.",
	Self = "You cannot duel yourself.",
	TargetMissing = "That driver is no longer here.",
	NotDriving = "You need to be driving your own car.",
	TargetNotDriving = "They are not driving their own car.",
	Busy = "You are busy with another activity.",
	TargetBusy = "They are busy right now.",
	OutOfRange = "Get closer to challenge them.",
	Cooldown = "Wait a moment before challenging again.",
	Muted = "They are not taking challenges from you right now.",
	Pending = "A challenge is already pending.",
	StakeInvalid = "That stake is not valid.",
	StakeNotOffered = "That stake is not offered.",
	StakesDisabled = "Cash stakes are off right now.",
	ChallengerRank = "Cash stakes unlock at a higher Driver Rank.",
	TargetRank = "They have not unlocked Cash stakes yet.",
	ChallengerFunds = "You cannot cover that stake.",
	TargetFunds = "They cannot cover that stake.",
	Expired = "That challenge has expired.",
	NotYours = "That challenge is not for you.",
	NoFinish = "No finish line could be found here.",
	PairLimit = "You have raced each other for Cash enough this hour.",
	Closing = "The server is restarting. Try again in a moment.",
}

function DuelRules.message(code)
	return DuelRules.Messages[code] or "Duel unavailable."
end

-- Validation codes are written from the challenger's side; this maps a code to the target's side.
local SWAP = {
	NotDriving = "TargetNotDriving", TargetNotDriving = "NotDriving",
	Busy = "TargetBusy", TargetBusy = "Busy",
	ChallengerRank = "TargetRank", TargetRank = "ChallengerRank",
	ChallengerFunds = "TargetFunds", TargetFunds = "ChallengerFunds",
}
function DuelRules.swapPerspective(code)
	return SWAP[code] or code
end

-- input = { Closing?, Enabled, ChallengerId, TargetId, TargetPresent, ChallengerDriving, TargetDriving, ChallengerBusy,
--   TargetBusy, Distance, Range, Pending, Stake, Stakes, StakesEnabled, MinRank, ChallengerRank, TargetRank,
--   PairStakeBlocked?, ChallengerCanAfford, TargetCanAfford, Limiter?, Now?, Cooldown?, SkipLimiter? }
-- Order matters only for which message the player sees; every check must pass.
function DuelRules.validateChallenge(input)
	if input.Closing == true then return false, "Closing" end
	if input.Enabled ~= true then return false, "Disabled" end
	if input.ChallengerId == input.TargetId then return false, "Self" end
	if input.TargetPresent ~= true then return false, "TargetMissing" end
	if input.ChallengerDriving ~= true then return false, "NotDriving" end
	if input.TargetDriving ~= true then return false, "TargetNotDriving" end
	if input.ChallengerBusy == true then return false, "Busy" end
	if input.TargetBusy == true then return false, "TargetBusy" end
	if input.Pending == true then return false, "Pending" end
	local distance = tonumber(input.Distance)
	if distance == nil or distance ~= distance or distance > (tonumber(input.Range) or 60) then
		return false, "OutOfRange"
	end
	if input.SkipLimiter ~= true and input.Limiter then
		local ok, code = DuelRules.limiterAllows(input.Limiter, input.Now or 0, input.ChallengerId, input.TargetId,
			{ Cooldown = input.Cooldown })
		if not ok then return false, code end
	end
	local ok, code = DuelRules.validateStake(input.Stake, input)
	if not ok then return false, code end
	return true, nil
end

-- CommandIds ---------------------------------------------------------------------------------------------
function DuelRules.potCommandId(duelId)
	return "DuelPot:" .. tostring(duelId)
end

function DuelRules.refundCommandId(duelId, userId)
	return "DuelRefund:" .. tostring(duelId) .. ":" .. tostring(userId)
end

function DuelRules.xpCommandId(duelId, userId)
	return "DuelXp:" .. tostring(duelId) .. ":" .. tostring(userId)
end

-- Settlement ---------------------------------------------------------------------------------------------
-- duel = { Id, ChallengerId, TargetId, Stake, Escrow = { [userId] = amount } }
-- outcome: "Finished" | "Forfeit" (winnerId required) | "Draw" | "Expired" | "Declined"
-- xp = { Win = 30, Lose = 10, Draw = 0, Eligible = boolean }. XP is anti-farm gated: nothing unless Eligible
-- (the race ran for at least MinXpRaceSeconds), and a Forfeit pays no XP to anyone.
-- Returns a list of payouts { UserId, Cash, Xp, Reason, CommandId, Role } (entries with Cash = 0 and
-- Xp = 0 are omitted). Cash paid out always equals the escrow collected: a winner gets the whole escrow
-- (the pot), a draw returns each player's own escrow. Nothing is paid for Expired/Declined.
function DuelRules.settlement(duel, outcome, winnerId, xp)
	xp = xp or {}
	local eligible = xp.Eligible == true
	local payouts = {}
	local escrow = duel.Escrow or {}
	local players = { duel.ChallengerId, duel.TargetId }
	local function add(entry)
		if (entry.Cash or 0) > 0 or (entry.Xp or 0) > 0 then table.insert(payouts, entry) end
	end
	if outcome == "Finished" or outcome == "Forfeit" then
		assert(winnerId == duel.ChallengerId or winnerId == duel.TargetId, "settlement needs a duel participant as winner")
		local pot = 0
		for _, userId in ipairs(players) do pot += escrow[userId] or 0 end
		local loserId = winnerId == duel.ChallengerId and duel.TargetId or duel.ChallengerId
		local earnsXp = outcome == "Finished" and eligible
		add({ UserId = winnerId, Cash = pot, Xp = earnsXp and (tonumber(xp.Win) or 30) or 0, Reason = "DuelPot",
			CommandId = DuelRules.potCommandId(duel.Id), Role = "Winner" })
		add({ UserId = loserId, Cash = 0, Xp = earnsXp and (tonumber(xp.Lose) or 10) or 0, Reason = "DuelPot",
			CommandId = DuelRules.xpCommandId(duel.Id, loserId), Role = "Loser" })
	elseif outcome == "Draw" then
		for _, userId in ipairs(players) do
			add({ UserId = userId, Cash = escrow[userId] or 0, Xp = eligible and (tonumber(xp.Draw) or 0) or 0,
				Reason = "DuelRefund", CommandId = DuelRules.refundCommandId(duel.Id, userId), Role = "Draw" })
		end
	end
	return payouts
end

-- Persisted escrow: profile.DuelEscrow[duelId] = { Owed, Stake, At } ------------------------------------
-- Written in the same no-yield tick as each debit, so a saved profile always carries the debit and its
-- escrow entry together. At settlement each participant with escrow gets one ledger step:
--   { Action = "Owe", Amount } for a Cash recipient (pot or refund);
--   { Action = "Delete" } for a player owed nothing (loser/forfeiter). Every Delete needs a durable "Lost"
--   marker written BEFORE the pot is paid (the loser's saved profile may still hold the entry).
function DuelRules.ledgerPlan(duel, payouts)
	local plan = {}
	for userId, amount in pairs(duel.Escrow or {}) do
		if amount > 0 then plan[userId] = { Action = "Delete" } end
	end
	for _, payout in ipairs(payouts) do
		if (payout.Cash or 0) > 0 then plan[payout.UserId] = { Action = "Owe", Amount = payout.Cash } end
	end
	return plan
end

DuelRules.MIN_RECOVER_AGE = 600 -- seconds; longer than countdown + timeout + marker retries

-- Recovery for a leftover entry found when a player joins.
--   live:       the duel is still unsettled or settling on this server (leave it alone);
--   marker:     "Lost" (their stake went to the opponent), nil (none), "Unknown" (lookup failed);
--   ageSeconds: os.time() - entry.At. An unsettled stake younger than minAge may still be settling on
--               another server, so it is deferred rather than judged.
-- Returns { Action = "Skip" | "Defer" | "Pay" | "Delete", Amount?, RetryIn? }.
function DuelRules.recoveryAction(entry, live, marker, ageSeconds, minAge)
	if type(entry) ~= "table" then return { Action = "Delete" } end
	if live then return { Action = "Skip" } end
	local owed = wholeNonNegative(entry.Owed) or 0
	if owed > 0 then return { Action = "Pay", Amount = math.min(owed, 2 * DuelRules.MAX_STAKE) } end
	local stake = wholeNonNegative(entry.Stake) or 0
	if stake <= 0 then return { Action = "Delete" } end
	minAge = minAge or DuelRules.MIN_RECOVER_AGE
	local age = tonumber(ageSeconds) or 0
	if age < minAge then return { Action = "Defer", RetryIn = minAge - age } end
	if marker == "Lost" then return { Action = "Delete" } end
	if marker == "Unknown" then return { Action = "Skip" } end -- retry on a later join; never guess with Cash
	return { Action = "Pay", Amount = math.min(stake, DuelRules.MAX_STAKE) }
end

-- True when recovery must read the durable marker before deciding (unsettled stake, old enough).
function DuelRules.needsMarker(entry, live, ageSeconds, minAge)
	if live or type(entry) ~= "table" then return false end
	if (wholeNonNegative(entry.Owed) or 0) > 0 or (wholeNonNegative(entry.Stake) or 0) <= 0 then return false end
	return (tonumber(ageSeconds) or 0) >= (minAge or DuelRules.MIN_RECOVER_AGE)
end

function DuelRules.recoverCommandId(duelId, userId)
	return "DuelRecover:" .. tostring(duelId) .. ":" .. tostring(userId)
end

function DuelRules.lostMarkerKey(duelId, userId)
	return tostring(duelId) .. ":" .. tostring(userId)
end

function DuelRules.potFor(stake)
	return 2 * (wholeNonNegative(stake) or 0)
end

-- Finish selection ---------------------------------------------------------------------------------------
function DuelRules.midpoint(a, b)
	return (a + b) * 0.5
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function DuelRules.flatDistance(a, b)
	return (flat(a) - flat(b)).Magnitude
end

-- A finish is fair when both starts are inside [minStuds, maxStuds] (with slack for the pair spread) and
-- neither driver is more than `maxGap` studs closer in a straight line.
function DuelRules.finishFair(finish, a, b, minStuds, maxStuds, maxGap)
	local da, db = DuelRules.flatDistance(finish, a), DuelRules.flatDistance(finish, b)
	local slack = DuelRules.flatDistance(a, b)
	if math.min(da, db) < minStuds - slack or math.max(da, db) > maxStuds + slack then return false end
	return math.abs(da - db) <= (maxGap or 40)
end

-- Tries candidate(i) for i = 1..attempts and returns the first fair one. When none is fair, returns the
-- in-bounds candidate with the smallest gap (the pair is at most ChallengeRange apart, so the worst gap is
-- small); nil only when no candidate is in bounds.
function DuelRules.pickFinish(a, b, minStuds, maxStuds, attempts, candidate, maxGap)
	local best, bestGap = nil, math.huge
	for i = 1, attempts or 8 do
		local point = candidate(i)
		if point then
			if DuelRules.finishFair(point, a, b, minStuds, maxStuds, maxGap) then return point end
			if DuelRules.finishFair(point, a, b, minStuds, maxStuds, math.huge) then
				local gap = math.abs(DuelRules.flatDistance(point, a) - DuelRules.flatDistance(point, b))
				if gap < bestGap then best, bestGap = point, gap end
			end
		end
	end
	return best
end

-- Arrivals in one tick: arrivals = { { UserId, Distance } } (integrity is resolved before arrivals).
-- Returns ("Finished", winnerId), ("Draw", nil) for an exact same-tick tie, or (nil, nil) with no arrivals.
function DuelRules.resolveArrivals(arrivals)
	if #arrivals == 0 then return nil, nil end
	table.sort(arrivals, function(x, y) return x.Distance < y.Distance end)
	if #arrivals > 1 and arrivals[1].Distance == arrivals[2].Distance then return "Draw", nil end
	return "Finished", arrivals[1].UserId
end

-- Integrity policy. Staked duels always check and enforce, whatever RaceIntegrity.mode() says; free duels
-- follow the mode (Off: no checks, Log: warn only, Enforce: enforce).
function DuelRules.integrityChecks(stake, mode)
	return (tonumber(stake) or 0) > 0 or mode == "Log" or mode == "Enforce"
end

function DuelRules.integrityEnforced(stake, mode)
	return (tonumber(stake) or 0) > 0 or mode == "Enforce"
end

-- faulted = { [userId] = true } for racers at fault this tick (integrity flag under enforcement, broken
-- freeze at GO, lost vehicle). One faulted racer forfeits to the opponent; both at fault in the same tick is
-- a draw (refunds), so iteration order can never pick a winner. Returns (outcome, winnerId) or (nil, nil).
function DuelRules.faultOutcome(faulted, challengerId, targetId)
	local a, b = faulted[challengerId] == true, faulted[targetId] == true
	if a and b then return "Draw", nil end
	if a then return "Forfeit", targetId end
	if b then return "Forfeit", challengerId end
	return nil, nil
end

-- A car is still validly frozen at GO when the duel's freeze claim is intact, the root is anchored and it has
-- not moved more than `tolerance` studs (flat) from where it was frozen. Anything else means the car was
-- re-entered/unanchored and moved during the countdown.
function DuelRules.frozenIntact(frozenAt, position, duelFrozen, anchored, tolerance)
	if duelFrozen ~= true or anchored ~= true or frozenAt == nil or position == nil then return false end
	return DuelRules.flatDistance(frozenAt, position) <= (tolerance or 5)
end

-- Cumulative path check: the sum of straight chords between 10 Hz samples is a lower bound on the distance
-- travelled, so for a legitimate run it never exceeds maxSpeed x elapsed. Jitter and tolerance are added
-- once per run, not per sample, so small per-tick jumps cannot add up unchecked.
function DuelRules.pathAllowed(pathLength, elapsed, maxStudsPerSecond, jitter, toleranceStuds)
	return pathLength <= maxStudsPerSecond * (math.max(elapsed, 0) + (jitter or 0)) + (toleranceStuds or 0)
end

return DuelRules
