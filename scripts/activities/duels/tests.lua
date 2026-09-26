-- Pure tests for DuelRules (Edit or Play; source loaded over loopback, no game module require, no instances).
local Http = game:GetService("HttpService")
local base = "http://127.0.0.1:8767/activities/duels/"
local DuelRules = assert(loadstring(Http:GetAsync(base .. "DuelRules.lua")))()
local results, failures = {}, 0
local function check(name, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. detail .. ")") or ""))
end
local function same(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end

-- State machine -------------------------------------------------------------------------------------------
local S = DuelRules.States
local legal = {
	{ "Challenged", "Accepted" }, { "Challenged", "Expired" }, { "Challenged", "Declined" },
	{ "Accepted", "Countdown" }, { "Accepted", "Forfeit" }, { "Accepted", "Draw" },
	{ "Countdown", "Racing" }, { "Countdown", "Forfeit" }, { "Countdown", "Draw" },
	{ "Racing", "Finished" }, { "Racing", "Forfeit" }, { "Racing", "Draw" },
}
for _, edge in ipairs(legal) do
	check("transition " .. edge[1] .. " -> " .. edge[2], DuelRules.canTransition(edge[1], edge[2]))
end
local illegal = {
	{ "Challenged", "Racing" }, { "Challenged", "Finished" }, { "Challenged", "Draw" }, { "Challenged", "Forfeit" },
	{ "Accepted", "Finished" }, { "Accepted", "Expired" }, { "Countdown", "Finished" }, { "Racing", "Countdown" },
	{ "Racing", "Expired" }, { "Finished", "Draw" }, { "Draw", "Finished" }, { "Forfeit", "Draw" },
	{ "Expired", "Accepted" }, { "Declined", "Accepted" }, { "Nope", "Accepted" },
}
for _, edge in ipairs(illegal) do
	check("no transition " .. edge[1] .. " -> " .. edge[2], not DuelRules.canTransition(edge[1], edge[2]))
end
for _, terminal in ipairs({ "Finished", "Forfeit", "Draw", "Expired", "Declined" }) do
	check(terminal .. " is terminal", DuelRules.isTerminal(terminal) and not DuelRules.holdsEscrow(terminal))
end
check("escrow states", DuelRules.holdsEscrow("Accepted") and DuelRules.holdsEscrow("Countdown") and DuelRules.holdsEscrow("Racing")
	and not DuelRules.holdsEscrow("Challenged"))
local walk = { State = S.Challenged }
check("walk to Finished", DuelRules.transition(walk, "Accepted") and DuelRules.transition(walk, "Countdown")
	and DuelRules.transition(walk, "Racing") and DuelRules.transition(walk, "Finished") and walk.State == "Finished")
local newState, why = DuelRules.transition(walk, "Draw")
check("terminal transition refused and state kept", newState == nil and why ~= nil and walk.State == "Finished")

-- Stakes --------------------------------------------------------------------------------------------------
check("parse default string", same(DuelRules.parseStakes("0,5000,25000,100000"), { 0, 5000, 25000, 100000 }))
check("parse unsorted/dupes/spaces", same(DuelRules.parseStakes(" 25000, 5000,5000 ,100000"), { 0, 5000, 25000, 100000 }))
check("parse drops junk/negative/fractional/over-limit", same(DuelRules.parseStakes("abc,-5,12.5,5000,2000000,nan,inf"), { 0, 5000 }))
check("parse empty falls back", same(DuelRules.parseStakes(""), DuelRules.DEFAULT_STAKES))
check("parse nil falls back", same(DuelRules.parseStakes(nil), DuelRules.DEFAULT_STAKES))
check("parse adds free", DuelRules.parseStakes("5000")[1] == 0)

local stakes = { 0, 5000, 25000, 100000 }
local function stakeOptions(overrides)
	local options = { Stakes = stakes, StakesEnabled = true, MinRank = 3, ChallengerRank = 5, TargetRank = 5,
		ChallengerCanAfford = true, TargetCanAfford = true }
	for key, value in pairs(overrides or {}) do options[key] = value end
	return options
end
local function stakeCode(stake, overrides)
	local ok, code = DuelRules.validateStake(stake, stakeOptions(overrides))
	return ok and "ok" or code
end
check("free stake always ok", stakeCode(0, { StakesEnabled = false, ChallengerRank = 1, TargetRank = 1,
	ChallengerCanAfford = false, TargetCanAfford = false }) == "ok")
check("listed stake ok", stakeCode(25000) == "ok")
check("unlisted stake", stakeCode(1234) == "StakeNotOffered")
check("negative stake", stakeCode(-5000) == "StakeInvalid")
check("fractional stake", stakeCode(5000.5) == "StakeInvalid")
check("nan stake", stakeCode(0 / 0) == "StakeInvalid")
check("string junk stake", stakeCode("lots") == "StakeInvalid")
check("nil stake", stakeCode(nil) == "StakeInvalid")
check("stakes disabled", stakeCode(5000, { StakesEnabled = false }) == "StakesDisabled")
check("challenger rank gate", stakeCode(5000, { ChallengerRank = 2 }) == "ChallengerRank")
check("target rank gate", stakeCode(5000, { TargetRank = 2 }) == "TargetRank")
check("rank exactly min ok", stakeCode(5000, { ChallengerRank = 3, TargetRank = 3 }) == "ok")
check("challenger funds", stakeCode(5000, { ChallengerCanAfford = false }) == "ChallengerFunds")
check("target funds", stakeCode(5000, { TargetCanAfford = false }) == "TargetFunds")
local available = DuelRules.availableStakes(stakeOptions(), function(amount) return amount <= 25000, amount <= 5000 end)
check("available stakes respect both wallets", same(available, { 0, 5000 }), table.concat(available, ","))
local lowRank = DuelRules.availableStakes(stakeOptions({ TargetRank = 1 }), function() return true, true end)
check("available stakes free only below rank", same(lowRank, { 0 }))

-- Challenge validation, cooldown and mute ----------------------------------------------------------------
local limiter = DuelRules.newLimiter()
local function challengeInput(overrides)
	local input = stakeOptions({ Enabled = true, ChallengerId = 1, TargetId = 2, TargetPresent = true,
		ChallengerDriving = true, TargetDriving = true, ChallengerBusy = false, TargetBusy = false,
		Distance = 30, Range = 60, Pending = false, Stake = 0, Limiter = limiter, Now = 1000, Cooldown = 20 })
	for key, value in pairs(overrides or {}) do input[key] = value end
	return input
end
local function challengeCode(overrides)
	local ok, code = DuelRules.validateChallenge(challengeInput(overrides))
	return ok and "ok" or code
end
check("valid challenge", challengeCode() == "ok")
check("disabled", challengeCode({ Enabled = false }) == "Disabled")
check("self", challengeCode({ TargetId = 1 }) == "Self")
check("target missing", challengeCode({ TargetPresent = false }) == "TargetMissing")
check("not driving", challengeCode({ ChallengerDriving = false }) == "NotDriving")
check("target not driving", challengeCode({ TargetDriving = false }) == "TargetNotDriving")
check("busy", challengeCode({ ChallengerBusy = true }) == "Busy")
check("target busy", challengeCode({ TargetBusy = true }) == "TargetBusy")
check("pending", challengeCode({ Pending = true }) == "Pending")
check("range edge ok", challengeCode({ Distance = 60 }) == "ok")
check("out of range", challengeCode({ Distance = 60.5 }) == "OutOfRange")
check("nan distance", challengeCode({ Distance = 0 / 0 }) == "OutOfRange")
check("stake checked in challenge", challengeCode({ Stake = 5000, TargetCanAfford = false }) == "TargetFunds")

DuelRules.recordChallenge(limiter, 1000, 1)
check("cooldown blocks", challengeCode({ Now = 1010 }) == "Cooldown")
check("cooldown skipped on accept revalidation", challengeCode({ Now = 1010, SkipLimiter = true }) == "ok")
check("cooldown ends at 20 s", challengeCode({ Now = 1020 }) == "ok")
check("cooldown is per challenger", challengeCode({ Now = 1010, ChallengerId = 3 }) == "ok")

local muteOptions = { MuteAfter = 3, MuteSeconds = 300 }
DuelRules.recordRejection(limiter, 1100, 1, 2, muteOptions)
DuelRules.recordRejection(limiter, 1130, 1, 2, muteOptions)
check("two rejections do not mute", challengeCode({ Now = 1160 }) == "ok")
DuelRules.recordAccepted(limiter, 1, 2)
DuelRules.recordRejection(limiter, 1170, 1, 2, muteOptions)
check("accept resets rejection count", challengeCode({ Now = 1200 }) == "ok")
DuelRules.recordRejection(limiter, 1200, 1, 2, muteOptions)
DuelRules.recordRejection(limiter, 1230, 1, 2, muteOptions)
check("third rejection mutes pair", challengeCode({ Now = 1260 }) == "Muted")
check("mute is directional", challengeCode({ Now = 1260, ChallengerId = 2, TargetId = 1 }) == "ok")
check("mute does not block other targets", challengeCode({ Now = 1260, TargetId = 4 }) == "ok")
check("mute lasts 5 minutes", challengeCode({ Now = 1529 }) == "Muted" and challengeCode({ Now = 1530 }) == "ok")
DuelRules.pruneLimiter(limiter, 5000, 20)
check("prune clears expired entries", next(limiter.LastChallenge) == nil and next(limiter.MutedUntil) == nil)
check("perspective swap", DuelRules.swapPerspective("ChallengerFunds") == "TargetFunds"
	and DuelRules.swapPerspective("Busy") == "TargetBusy" and DuelRules.swapPerspective("Expired") == "Expired")

-- Settlement ----------------------------------------------------------------------------------------------
local xp = { Win = 30, Lose = 10, Draw = 0, Eligible = true }
local function staked(stake)
	return { Id = "duel_7", ChallengerId = 11, TargetId = 22, Stake = stake,
		Escrow = stake > 0 and { [11] = stake, [22] = stake } or {} }
end
local function byUser(payouts)
	local out = {}
	for _, payout in ipairs(payouts) do out[payout.UserId] = payout end
	return out
end
local function cashTotal(payouts)
	local total = 0
	for _, payout in ipairs(payouts) do total += payout.Cash end
	return total
end

local win = byUser(DuelRules.settlement(staked(25000), "Finished", 22, xp))
check("winner gets pot", win[22] and win[22].Cash == 50000 and win[22].Xp == 30 and win[22].Reason == "DuelPot")
check("winner CommandId", win[22] and win[22].CommandId == "DuelPot:duel_7")
check("loser xp only", win[11] and win[11].Cash == 0 and win[11].Xp == 10 and win[11].CommandId == "DuelXp:duel_7:11")
check("pot conserved on finish", cashTotal(DuelRules.settlement(staked(25000), "Finished", 11, xp)) == 50000)
check("potFor", DuelRules.potFor(25000) == 50000 and DuelRules.potFor(0) == 0)

local forfeit = byUser(DuelRules.settlement(staked(100000), "Forfeit", 11, xp))
check("forfeit: opponent gets pot", forfeit[11] and forfeit[11].Cash == 200000)
check("forfeit: forfeiter gets nothing", forfeit[22] == nil)
check("forfeit: winner gets no XP (anti-farm)", forfeit[11] and forfeit[11].Xp == 0)
local short = byUser(DuelRules.settlement(staked(5000), "Finished", 22, { Win = 30, Lose = 10, Eligible = false }))
check("short race: pot paid, no XP", short[22] and short[22].Cash == 10000 and short[22].Xp == 0 and short[11] == nil)
check("free short race pays nothing", #DuelRules.settlement(staked(0), "Finished", 11, { Win = 30, Lose = 10, Eligible = false }) == 0)
check("free forfeit pays nothing", #DuelRules.settlement(staked(0), "Forfeit", 11, xp) == 0)
check("pot conserved on forfeit", cashTotal(DuelRules.settlement(staked(100000), "Forfeit", 22, xp)) == 200000)

local draw = DuelRules.settlement(staked(5000), "Draw", nil, xp)
local drawBy = byUser(draw)
check("draw refunds each stake", drawBy[11] and drawBy[11].Cash == 5000 and drawBy[22] and drawBy[22].Cash == 5000)
check("draw reason and ids", drawBy[11].Reason == "DuelRefund" and drawBy[11].CommandId == "DuelRefund:duel_7:11"
	and drawBy[22].CommandId == "DuelRefund:duel_7:22")
check("draw conserves escrow", cashTotal(draw) == 10000)
local halfEscrow = { Id = "duel_8", ChallengerId = 11, TargetId = 22, Stake = 5000, Escrow = { [11] = 5000 } }
local half = byUser(DuelRules.settlement(halfEscrow, "Draw", nil, xp))
check("draw refunds only what was escrowed", half[11] and half[11].Cash == 5000 and half[22] == nil)

check("free win: xp only", (function()
	local free = byUser(DuelRules.settlement(staked(0), "Finished", 11, xp))
	return free[11].Cash == 0 and free[11].Xp == 30 and free[22].Cash == 0 and free[22].Xp == 10
end)())
check("free draw pays nothing", #DuelRules.settlement(staked(0), "Draw", nil, xp) == 0)
check("expired pays nothing", #DuelRules.settlement(staked(5000), "Expired", nil, xp) == 0)
check("declined pays nothing", #DuelRules.settlement(staked(5000), "Declined", nil, xp) == 0)
check("winner must be a participant", not pcall(DuelRules.settlement, staked(5000), "Finished", 99, xp))
check("draw xp configurable", byUser(DuelRules.settlement(staked(0), "Draw", nil, { Draw = 5, Eligible = true }))[11].Xp == 5)
check("draw xp gated", #DuelRules.settlement(staked(0), "Draw", nil, { Draw = 5, Eligible = false }) == 0)

-- CommandIds ----------------------------------------------------------------------------------------------
check("pot id deterministic", DuelRules.potCommandId("duel_1") == DuelRules.potCommandId("duel_1"))
check("refund id deterministic", DuelRules.refundCommandId("duel_1", 5) == "DuelRefund:duel_1:5")
local ids = {}
local unique = true
for _, duelId in ipairs({ "duel_1", "duel_2", "duel_10" }) do
	for _, id in ipairs({ DuelRules.potCommandId(duelId), DuelRules.refundCommandId(duelId, 11),
		DuelRules.refundCommandId(duelId, 22), DuelRules.xpCommandId(duelId, 11), DuelRules.xpCommandId(duelId, 22) }) do
		if ids[id] then unique = false end
		ids[id] = true
		if #id > 240 then unique = false end
	end
end
check("command ids unique across duels/users/kinds and bounded", unique)
local perOutcomeUnique = true
for _, outcome in ipairs({ { "Finished", 11 }, { "Forfeit", 22 }, { "Draw" } }) do
	local seen = {}
	for _, payout in ipairs(DuelRules.settlement(staked(5000), outcome[1], outcome[2], xp)) do
		if seen[payout.CommandId] then perOutcomeUnique = false end
		seen[payout.CommandId] = true
	end
end
check("command ids unique within each settlement", perOutcomeUnique)

-- Finish selection and arrivals ---------------------------------------------------------------------------
local a, b = Vector3.new(0, 101, 0), Vector3.new(30, 101, 0)
check("midpoint", DuelRules.midpoint(a, b) == Vector3.new(15, 101, 0))
check("flat distance ignores height", DuelRules.flatDistance(Vector3.new(0, 0, 0), Vector3.new(3, 500, 4)) == 5)
check("fair finish on bisector", DuelRules.finishFair(Vector3.new(15, 101, 1000), a, b, 800, 1500, 40))
check("finish too near", not DuelRules.finishFair(Vector3.new(15, 101, 300), a, b, 800, 1500, 40))
check("finish too far", not DuelRules.finishFair(Vector3.new(15, 101, 3000), a, b, 800, 1500, 40))
local spread = Vector3.new(60, 101, 0)
check("unfair finish along the pair axis", not DuelRules.finishFair(Vector3.new(1000, 101, 0), a, spread, 800, 1500, 40))
local tries = 0
local picked = DuelRules.pickFinish(a, b, 800, 1500, 8, function(i)
	tries = i
	if i < 3 then return nil end
	if i == 3 then return Vector3.new(15, 101, 200) end
	return Vector3.new(15, 101, 900)
end, 40)
check("pickFinish skips nil/unfair candidates", picked == Vector3.new(15, 101, 900) and tries == 4)
check("pickFinish gives up", DuelRules.pickFinish(a, b, 800, 1500, 3, function() return nil end) == nil)
check("pickFinish gives up when all out of bounds", DuelRules.pickFinish(a, b, 800, 1500, 3, function()
	return Vector3.new(15, 101, 100)
end) == nil)
local axis = { Vector3.new(1000, 101, 0), Vector3.new(700, 101, 700), Vector3.new(15, 101, 5000) }
local fallback = DuelRules.pickFinish(a, spread, 800, 1500, 3, function(i) return axis[i] end, 40)
check("pickFinish falls back to least-unfair in-bounds point", fallback == Vector3.new(700, 101, 700))

local outcome, winner = DuelRules.resolveArrivals({})
check("no arrivals", outcome == nil and winner == nil)
outcome, winner = DuelRules.resolveArrivals({ { UserId = 11, Distance = 30 } })
check("single arrival wins", outcome == "Finished" and winner == 11)
outcome, winner = DuelRules.resolveArrivals({ { UserId = 11, Distance = 30 }, { UserId = 22, Distance = 12 } })
check("closer arrival wins same tick", outcome == "Finished" and winner == 22)
outcome = DuelRules.resolveArrivals({ { UserId = 11, Distance = 20 }, { UserId = 22, Distance = 20 } })
check("exact tie draws", outcome == "Draw")

-- Integrity policy (B2): staked duels always enforce; free duels follow the mode --------------------------
for _, mode in ipairs({ "Off", "Log", "Enforce" }) do
	check("staked checks+enforces in " .. mode, DuelRules.integrityChecks(5000, mode) and DuelRules.integrityEnforced(5000, mode))
end
check("free Off: no checks", not DuelRules.integrityChecks(0, "Off") and not DuelRules.integrityEnforced(0, "Off"))
check("free Log: checks, not enforced", DuelRules.integrityChecks(0, "Log") and not DuelRules.integrityEnforced(0, "Log"))
check("free Enforce: enforced", DuelRules.integrityChecks(0, "Enforce") and DuelRules.integrityEnforced(0, "Enforce"))
outcome, winner = DuelRules.faultOutcome({ [11] = true }, 11, 22)
check("flagged challenger forfeits to target", outcome == "Forfeit" and winner == 22)
outcome, winner = DuelRules.faultOutcome({ [22] = true }, 11, 22)
check("flagged target forfeits to challenger", outcome == "Forfeit" and winner == 11)
outcome = DuelRules.faultOutcome({ [11] = true, [22] = true }, 11, 22)
check("both flagged draws", outcome == "Draw")
check("nobody flagged", DuelRules.faultOutcome({}, 11, 22) == nil)
check("flagged winner cannot take the pot", (function()
	local verdict, gets = DuelRules.faultOutcome({ [22] = true }, 11, 22)
	local pay = byUser(DuelRules.settlement(staked(25000), verdict, gets, xp))
	return pay[11] and pay[11].Cash == 50000 and pay[22] == nil
end)())

-- Cumulative path check (R3; 400 mph limit = 640 studs/s, jitter 0.35 s and 24 studs once per run) --------
local maxSpeed = 400 / 0.625
check("plausible path allowed", DuelRules.pathAllowed(1200, 2, maxSpeed, 0.35, 24))
check("1000 studs in 1 s flagged", not DuelRules.pathAllowed(1000, 1, maxSpeed, 0.35, 24))
check("single 60-stud tick allowed", DuelRules.pathAllowed(60, 0.1, maxSpeed, 0.35, 24))
check("teleport tick flagged", not DuelRules.pathAllowed(800, 0.1, maxSpeed, 0.35, 24))
-- 300 studs every 0.1 s passes a per-tick check with jitter each tick (<= 640 x 0.45 + 24 = 312) but not the
-- cumulative check: after 1 s the path is 3000 studs against 640 x 1.35 + 24 = 888.
local path, sneaky = 0, true
for i = 1, 10 do
	path += 300
	if not DuelRules.pathAllowed(path, i * 0.1, maxSpeed, 0.35, 24) then sneaky = false end
end
check("repeated sub-threshold hops are caught", not sneaky)
check("just under the limit allowed", DuelRules.pathAllowed(640 * 2.35 + 23.9, 2, maxSpeed, 0.35, 24))

-- Pair stake cap (R4) and closing gate (R6) ---------------------------------------------------------------
local pairs3 = DuelRules.newLimiter()
check("pair stake allowed initially", DuelRules.pairStakeAllowed(pairs3, 0, 11, 22, 3))
DuelRules.recordPairStake(pairs3, 0, 11, 22)
DuelRules.recordPairStake(pairs3, 100, 22, 11)
DuelRules.recordPairStake(pairs3, 200, 11, 22)
check("pair stake count is unordered", DuelRules.pairStakeCount(pairs3, 300, 22, 11) == 3)
check("pair stake capped at 3/hour", not DuelRules.pairStakeAllowed(pairs3, 300, 11, 22, 3))
check("other pairs unaffected", DuelRules.pairStakeAllowed(pairs3, 300, 11, 33, 3))
check("cap rolls off after an hour", DuelRules.pairStakeAllowed(pairs3, 3601, 11, 22, 3))
DuelRules.pruneLimiter(pairs3, 4000, 20)
check("prune clears old pair stakes", next(pairs3.PairStakes) == nil)
check("pair limit blocks cash stakes", stakeCode(5000, { PairStakeBlocked = true }) == "PairLimit")
check("pair limit leaves free duels", stakeCode(0, { PairStakeBlocked = true }) == "ok")
check("closing refuses challenges", challengeCode({ Closing = true }) == "Closing")

-- Persisted escrow ledger and recovery (B1) ---------------------------------------------------------------
local function plan(stake, outcome, winnerId)
	local duel = staked(stake)
	return DuelRules.ledgerPlan(duel, DuelRules.settlement(duel, outcome, winnerId, xp))
end
local finishedPlan = plan(5000, "Finished", 22)
check("ledger: winner owed pot, loser deleted", finishedPlan[22].Action == "Owe" and finishedPlan[22].Amount == 10000
	and finishedPlan[11].Action == "Delete")
local forfeitPlan = plan(5000, "Forfeit", 11)
check("ledger: forfeiter deleted", forfeitPlan[11].Action == "Owe" and forfeitPlan[11].Amount == 10000 and forfeitPlan[22].Action == "Delete")
local drawPlan = plan(5000, "Draw")
check("ledger: draw owes each stake", drawPlan[11].Amount == 5000 and drawPlan[22].Amount == 5000
	and drawPlan[11].Action == "Owe" and drawPlan[22].Action == "Owe")
check("ledger: free duel has no entries", next(plan(0, "Finished", 11)) == nil)
local owedTotal = 0
for _, step in pairs(finishedPlan) do owedTotal += step.Amount or 0 end
check("ledger owes exactly the escrow", owedTotal == 10000)

local OLD = DuelRules.MIN_RECOVER_AGE + 1
local function act(entry, live, marker, age)
	local r = DuelRules.recoveryAction(entry, live, marker, age or OLD, DuelRules.MIN_RECOVER_AGE)
	return r.Action .. (r.Amount and (":" .. r.Amount) or "") .. (r.RetryIn and ("@" .. r.RetryIn) or "")
end
check("recover: owed pot paid", act({ Owed = 10000, Stake = 5000 }, false, nil) == "Pay:10000")
check("recover: owed paid even when young", act({ Owed = 10000, Stake = 5000 }, false, nil, 5) == "Pay:10000")
check("recover: owed ignores marker", act({ Owed = 5000, Stake = 5000 }, false, "Lost") == "Pay:5000")
check("recover: old unsettled stake refunded", act({ Owed = 0, Stake = 5000 }, false, nil) == "Pay:5000")
check("recover: young unsettled stake deferred", act({ Owed = 0, Stake = 5000 }, false, nil, 100) == "Defer@" .. (DuelRules.MIN_RECOVER_AGE - 100))
check("recover: young entry deferred even with a marker", act({ Owed = 0, Stake = 5000 }, false, "Lost", 100):sub(1, 5) == "Defer")
check("recover: lost stake cleared, not refunded", act({ Owed = 0, Stake = 5000 }, false, "Lost") == "Delete")
check("recover: marker lookup failed -> retry later", act({ Owed = 0, Stake = 5000 }, false, "Unknown") == "Skip")
check("recover: no expiry rule (very old unmarked entry refunded)", act({ Owed = 0, Stake = 5000 }, false, nil, 1e9) == "Pay:5000")
check("recover: live duel skipped", act({ Owed = 10000, Stake = 5000 }, true, nil) == "Skip")
check("recover: junk entry deleted", act("junk", false, nil) == "Delete" and act({ Owed = -5, Stake = "x" }, false, nil) == "Delete")
check("recover: amounts clamped", act({ Owed = 1e12, Stake = 5000 }, false, nil) == "Pay:" .. 2 * DuelRules.MAX_STAKE)
check("needsMarker only for old unsettled stakes", DuelRules.needsMarker({ Owed = 0, Stake = 5000 }, false, OLD, DuelRules.MIN_RECOVER_AGE)
	and not DuelRules.needsMarker({ Owed = 0, Stake = 5000 }, false, 10, DuelRules.MIN_RECOVER_AGE)
	and not DuelRules.needsMarker({ Owed = 100, Stake = 5000 }, false, OLD, DuelRules.MIN_RECOVER_AGE)
	and not DuelRules.needsMarker({ Owed = 0, Stake = 5000 }, true, OLD, DuelRules.MIN_RECOVER_AGE)
	and not DuelRules.needsMarker({ Owed = 0, Stake = 0 }, false, OLD, DuelRules.MIN_RECOVER_AGE))
check("min recover age covers countdown + timeout", DuelRules.MIN_RECOVER_AGE >= 3 + 150 + 120)
check("recover id deterministic", DuelRules.recoverCommandId("duel_1-abc", 7) == "DuelRecover:duel_1-abc:7")
check("recover id differs from pot/refund ids", DuelRules.recoverCommandId("d", 7) ~= DuelRules.refundCommandId("d", 7))
check("lost marker key per user", DuelRules.lostMarkerKey("d", 1) ~= DuelRules.lostMarkerKey("d", 2))

-- Freeze at GO (B2): re-entering during the countdown unanchors/moves the car ---------------------------------
local frozenAt = Vector3.new(100, 101, 100)
check("frozen intact", DuelRules.frozenIntact(frozenAt, Vector3.new(102, 105, 101), true, true, 5))
check("moved car broken", not DuelRules.frozenIntact(frozenAt, Vector3.new(110, 101, 100), true, true, 5))
check("unanchored car broken", not DuelRules.frozenIntact(frozenAt, frozenAt, true, false, 5))
check("lost DuelFrozen claim broken", not DuelRules.frozenIntact(frozenAt, frozenAt, nil, true, 5))
check("missing freeze point broken", not DuelRules.frozenIntact(nil, frozenAt, true, true, 5))
outcome, winner = DuelRules.faultOutcome({ [11] = true, [22] = true }, 11, 22)
check("both broken at GO draws (no pairs() order)", outcome == "Draw" and winner == nil)

-- Scenarios (money conservation across settlement + recovery). A loser's stake reaches the winner only with
-- a Lost marker; otherwise both are refunded.
local function scenario(markerWritten, loserEntrySaved)
	local duel = staked(25000)
	local payouts = DuelRules.settlement(duel, "Forfeit", 22, xp)
	local steps = DuelRules.ledgerPlan(duel, payouts)
	local winnerCash, loserCash = 0, 0
	if markerWritten then
		for _, payout in ipairs(payouts) do if payout.UserId == 22 then winnerCash += payout.Cash end end
	else
		winnerCash, loserCash = duel.Escrow[22], duel.Escrow[11] -- refunds instead
	end
	if steps[11].Action == "Delete" and loserEntrySaved and markerWritten then
		-- The loser's saved profile still holds the entry (profile closed or save diverged): recovery later.
		local r = DuelRules.recoveryAction({ Owed = 0, Stake = 25000 }, false, "Lost", OLD, DuelRules.MIN_RECOVER_AGE)
		loserCash += r.Amount or 0
	end
	return winnerCash + loserCash
end
check("scenario: pot with marker, loser entry left behind", scenario(true, true) == 50000)
check("scenario: pot with marker, loser entry deleted", scenario(true, false) == 50000)
check("scenario: marker failed -> refunds", scenario(false, true) == 50000)
check("scenario: shutdown draw refunds each stake once on rejoin", (function()
	local total = 0
	for _ = 1, 2 do
		local r = DuelRules.recoveryAction({ Owed = 0, Stake = 25000 }, false, nil, OLD, DuelRules.MIN_RECOVER_AGE)
		total += r.Amount or 0
	end
	return total == 50000
end)())
check("scenario: winner's own-stake claim before the marker", (function()
	local duel = staked(25000)
	local steps = DuelRules.ledgerPlan(duel, DuelRules.settlement(duel, "Finished", 11, xp))
	-- settle() writes the winner's Owed as their own escrow while a Delete step exists
	local provisional = (steps[22].Action == "Delete") and duel.Escrow[11] or steps[11].Amount
	return provisional == 25000 and steps[11].Amount == 50000
end)())

return { failures = failures, results = results }
