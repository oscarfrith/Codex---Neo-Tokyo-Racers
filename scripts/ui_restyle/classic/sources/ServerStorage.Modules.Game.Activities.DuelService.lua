-- DuelService (ServerStorage.Modules.Game.Activities.DuelService). Street Duels with optional Cash stakes.
-- High-Risk economy rules (see scripts/activities/duels/CONTRACT.md):
--   * validate everything, then Begin x2 + Debit x2 + persisted escrow entries in one tick with no yield
--     (validate-then-debit, ECON-01);
--   * every debit writes profile.DuelEscrow[duelId] in the same tick; both profiles are force-saved during
--     the countdown and a staked duel only races when both saves succeeded (otherwise it is a Draw);
--   * a loser's stake is only handed to the winner after a durable "Lost" marker (DataStore) exists for the
--     loser; if the marker cannot be written the duel settles as refunds, so recovery can never mint Cash;
--   * settlement records what each player is owed, a successful grant deletes the entry, and leftovers are
--     recovered when the player next joins any server;
--   * settle() runs once per duel (Settled flag) and pays with deterministic CommandIds.
-- Started by ServerScriptService.ServerBase; never self-starting.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Modules = ServerStorage:WaitForChild("Modules")
local Activities = Modules:WaitForChild("Game"):WaitForChild("Activities")
local ActivityService = require(Activities:WaitForChild("ActivityService"))
local ActivityPayout = require(Activities:WaitForChild("ActivityPayout"))
local ProgressionService = require(Activities:WaitForChild("ProgressionService"))
local DuelRules = require(Activities:WaitForChild("DuelRules"))
local RaceIntegrity = require(Modules.Game:WaitForChild("Racing"):WaitForChild("RaceIntegrity"))
local ProfileServer = require(Modules.Game:WaitForChild("Player"):WaitForChild("ProfileServer"))
local FeatureFlags = require(Modules:WaitForChild("Core"):WaitForChild("FeatureFlags"))

local DuelService = {}
local state = "idle"

local KIND = "Duel"
local MPH_TO_STUDS = 1 / 0.625
local TICK_SECONDS = 0.1
local LEDGER_KEY = "DuelEscrow"
local MARKER_STORE = "NTR_DuelLostStakes_v1"
local FROZEN_TOLERANCE_STUDS = 5
local WINNER_SAVE_SECONDS = 5
local PROFILE_WAIT_SECONDS = 60

-- Duel ids must be unique across servers (they key saved escrow entries and markers).
local serverTag = string.sub(string.gsub(game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false), "[^%w]", ""), 1, 12)

local duels = {} -- [duelId] = duel (unsettled)
local settling = {} -- [duelId] = true while a settled duel's payouts are running
local byUser = {} -- [userId] = duelId (pending or live; one duel per player)
local recovering = {} -- [userId] = true while recovery runs
local limiter = DuelRules.newLimiter()
local closing = false
local connections = {}

local function tag(text)
	return "[DUEL] " .. text
end

-- Config -------------------------------------------------------------------------------------------------
local function settings()
	local folder = ActivityService.Config("Duels")
	local function number(key, default, minimum, maximum)
		return ActivityService.Number(folder, key, default, minimum, maximum)
	end
	local function bool(key, default)
		local value = folder and folder:GetAttribute(key)
		if type(value) ~= "boolean" then return default end
		return value
	end
	return {
		Enabled = bool("Enabled", true) and FeatureFlags.IsEnabled("EnableDuels", true),
		-- Cash stakes need the config switch AND the server flag, which defaults OFF (dashboard opt-in).
		StakesEnabled = bool("StakesEnabled", false) and FeatureFlags.IsEnabled("EnableDuelStakes", false),
		Stakes = DuelRules.parseStakes(folder and folder:GetAttribute("Stakes")),
		StakeMinRank = number("StakeMinRank", 3, 1, 100),
		PairStakeLimit = number("PairStakeLimitPerHour", 3, 0, 100),
		Range = number("ChallengeRange", 60, 10, 300),
		ChallengeTimeout = number("ChallengeTimeout", 12, 5, 60),
		Cooldown = number("ChallengeCooldown", 20, 0, 600),
		MuteAfter = number("MuteAfter", 3, 1, 20),
		MuteSeconds = number("MuteSeconds", 300, 0, 3600),
		Countdown = number("CountdownSeconds", 3, 1, 10),
		FinishRadius = number("FinishRadius", 40, 10, 200),
		MinFinish = number("MinFinish", 800, 200, 5000),
		MaxFinish = number("MaxFinish", 1500, 300, 8000),
		FinishGap = number("FinishMaxGap", 40, 0, 400),
		Timeout = number("TimeoutSeconds", 150, 30, 900),
		MinXpRace = number("MinXpRaceSeconds", 15, 0, 300),
		WinXp = number("WinXp", 30, 0, 10000),
		LoseXp = number("LoseXp", 10, 0, 10000),
		DrawXp = number("DrawXp", 0, 0, 10000),
		Jitter = number("IntegrityJitterSeconds", 0.35, 0, 3),
		Tolerance = number("IntegrityToleranceStuds", 24, 0, 500),
	}
end

-- Helpers ------------------------------------------------------------------------------------------------
local function rootOf(vehicle)
	return vehicle and vehicle.PrimaryPart
end

local function present(player)
	return player ~= nil and player.Parent == Players
end

local function otherOf(duel, userId)
	return userId == duel.ChallengerId and duel.Target or duel.Challenger
end

local function push(player, payload)
	if present(player) then ActivityService.Push(player, payload) end
end

local function pushBoth(duel, payload)
	push(duel.Challenger, payload)
	push(duel.Target, payload)
end

local function forget(duel)
	duels[duel.Id] = nil
	if byUser[duel.ChallengerId] == duel.Id then byUser[duel.ChallengerId] = nil end
	if byUser[duel.TargetId] == duel.Id then byUser[duel.TargetId] = nil end
end

-- Persisted escrow ledger (profile.DuelEscrow). All calls are synchronous and never yield. ---------------
local function liveProfile(player)
	return present(player) and ProfileServer.get_profile(player) or nil
end

-- Returns true when the live profile was changed (false when it is closed or not loaded).
local function ledgerEdit(player, duelId, edit)
	local profile = liveProfile(player)
	if not profile then return false end
	local ledger = profile[LEDGER_KEY]
	if type(ledger) ~= "table" then
		ledger = {}
		profile[LEDGER_KEY] = ledger
	end
	edit(ledger)
	if next(ledger) == nil then profile[LEDGER_KEY] = nil end
	ProfileServer.mark_dirty(player, profile, "DuelEscrow")
	return true
end

local function ledgerOpen(player, duelId, stake)
	return ledgerEdit(player, duelId, function(ledger)
		ledger[duelId] = { Owed = 0, Stake = stake, At = os.time() }
	end)
end

local function ledgerOwe(player, duelId, amount)
	return ledgerEdit(player, duelId, function(ledger)
		local entry = ledger[duelId] or { Stake = 0, At = os.time() }
		entry.Owed = amount
		ledger[duelId] = entry
	end)
end

local function ledgerDelete(player, duelId)
	return ledgerEdit(player, duelId, function(ledger)
		ledger[duelId] = nil
	end)
end

-- Durable cross-server "stake lost" markers (DataStore, no expiry; all calls may yield) -------------------
local markerStore
local function markers()
	markerStore = markerStore or DataStoreService:GetDataStore(MARKER_STORE)
	return markerStore
end

local function withRetries(label, attempts, action)
	for attempt = 1, attempts do
		local ok, result = pcall(action)
		if ok then return true, result end
		warn(tag(label .. " failed (attempt " .. attempt .. "): " .. tostring(result)))
		if attempt < attempts then task.wait(0.5 * attempt) end
	end
	return false, nil
end

local function writeLostMarker(duelId, userId)
	local key = DuelRules.lostMarkerKey(duelId, userId)
	return (withRetries("lost-marker write " .. key, 3, function()
		markers():UpdateAsync(key, function()
			return "Lost"
		end)
	end))
end

local function removeLostMarker(duelId, userId)
	local key = DuelRules.lostMarkerKey(duelId, userId)
	return (withRetries("lost-marker undo " .. key, 3, function()
		markers():RemoveAsync(key)
	end))
end

-- "Lost", nil (no marker) or "Unknown" (lookup failed, including Studio without DataStore access).
local function readLostMarker(duelId, userId)
	local ok, value = withRetries("lost-marker read", 2, function()
		return markers():GetAsync(DuelRules.lostMarkerKey(duelId, userId))
	end)
	if not ok then return "Unknown" end
	return value == "Lost" and "Lost" or nil
end

-- Force-save through ProfileServer (SaveNow -> saveProfile(player, true)); retried until `deadline`.
local saveNow
local function forceSave(userId, deadline)
	for _ = 1, 6 do
		local player = Players:GetPlayerByUserId(userId)
		if not player then return false end
		saveNow = saveNow or ServerStorage:WaitForChild("Runtime"):WaitForChild("Player")
			:WaitForChild("ProfileServiceBindings"):WaitForChild("SaveNow")
		local ok, saved, message = pcall(function()
			return saveNow:Invoke(player)
		end)
		if ok and saved == true then return true end
		warn(tag(string.format("force-save user=%d failed: %s", userId, tostring(ok and message or saved))))
		if Workspace:GetServerTimeNow() + 0.4 >= deadline then return false end
		task.wait(0.3)
	end
	return false
end

-- Collects every validation input for a challenger/target pair. Reads only; never yields.
local function gather(cfg, challenger, target, stake, options)
	options = options or {}
	local challengerVehicle = ActivityService.GetDrivenVehicle(challenger)
	local targetVehicle = target and present(target) and ActivityService.GetDrivenVehicle(target) or nil
	local a, b = rootOf(challengerVehicle), rootOf(targetVehicle)
	local challengerBusy = ActivityService.IsBusy(challenger)
	local targetBusy = target and present(target) and ActivityService.IsBusy(target) or false
	local amount = tonumber(stake)
	local positive = amount ~= nil and amount > 0 and amount == math.floor(amount)
	local pending = false
	if not options.IgnorePending then
		pending = byUser[challenger.UserId] ~= nil or (target ~= nil and byUser[target.UserId] ~= nil)
	end
	local targetId = target and target.UserId or -1
	return {
		Closing = closing,
		Enabled = cfg.Enabled,
		ChallengerId = challenger.UserId,
		TargetId = targetId,
		TargetPresent = present(target),
		ChallengerDriving = a ~= nil,
		TargetDriving = b ~= nil,
		ChallengerBusy = challengerBusy == true,
		TargetBusy = targetBusy == true,
		Distance = (a and b) and DuelRules.flatDistance(a.Position, b.Position) or math.huge,
		Range = cfg.Range,
		Pending = pending,
		Stake = stake,
		Stakes = cfg.Stakes,
		StakesEnabled = cfg.StakesEnabled,
		MinRank = cfg.StakeMinRank,
		ChallengerRank = ProgressionService.GetRank(challenger),
		TargetRank = target and present(target) and ProgressionService.GetRank(target) or 0,
		PairStakeBlocked = not DuelRules.pairStakeAllowed(limiter, os.clock(), challenger.UserId, targetId, cfg.PairStakeLimit),
		ChallengerCanAfford = positive and ActivityPayout.CanAfford(challenger, amount) or false,
		TargetCanAfford = positive and target ~= nil and present(target) and ActivityPayout.CanAfford(target, amount) or false,
		Limiter = limiter,
		Now = os.clock(),
		Cooldown = cfg.Cooldown,
		SkipLimiter = options.SkipLimiter == true,
		ChallengerVehicle = challengerVehicle,
		TargetVehicle = targetVehicle,
	}
end

-- Vehicle freeze (pattern from MatchmakingServer.setVehicleFrozen; only the root is anchored here) -------
local function freeze(vehicle)
	local root = rootOf(vehicle)
	if not root then return end
	for _, item in ipairs(vehicle:GetDescendants()) do
		if item:IsA("BasePart") then
			item.AssemblyLinearVelocity = Vector3.zero
			item.AssemblyAngularVelocity = Vector3.zero
		end
	end
	vehicle:SetAttribute("DuelFrozen", true)
	vehicle:SetAttribute("DriveReady", false)
	root.Anchored = true
end

-- Only a car its owner is still driving is unanchored; a parked or abandoned car keeps its anchor and just
-- loses the DuelFrozen claim (the vehicle/parking owners take over from there).
local function release(vehicle, owner)
	if not vehicle or vehicle:GetAttribute("DuelFrozen") ~= true then return end
	vehicle:SetAttribute("DuelFrozen", nil)
	local root = rootOf(vehicle)
	if not root or vehicle:GetAttribute("ParkedFixed") ~= nil then return end
	if not present(owner) or ActivityService.GetDrivenVehicle(owner) ~= vehicle then return end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = false
	vehicle:SetAttribute("DriveReady", true)
	pcall(function()
		root:SetNetworkOwner(owner)
	end)
end

-- Payouts ------------------------------------------------------------------------------------------------
-- Same CommandId on every attempt: EconomyServer answers AlreadyCommitted for a claimed id, so a retry after
-- a lost reply or a Busy lock cannot grant twice.
local function payWithRetry(player, payout)
	local last
	for attempt = 1, 4 do
		if not present(player) then last = "player gone" break end
		local ok, result = pcall(ActivityPayout.Pay, player, {
			Cash = payout.Cash,
			Xp = payout.Xp,
			Reason = payout.Reason,
			CommandId = payout.CommandId,
			Label = payout.Reason == "DuelRefund" and "Duel stake refund" or "Street Duel",
			JobCeiling = false,
		})
		if ok and type(result) == "table" and result.Ok then return result end
		last = ok and (type(result) == "table" and result.Message or "no result") or result
		if attempt < 4 and not closing then task.wait(0.25 * attempt) end
	end
	warn(tag(string.format("PAYOUT FAILED user=%s cash=%d xp=%d command=%s reason=%s",
		tostring(payout.UserId), payout.Cash or 0, payout.Xp or 0, payout.CommandId, tostring(last))))
	return nil
end

-- Recovery (on join) -------------------------------------------------------------------------------------
local function recoverMinAge()
	local cfg = settings()
	-- Longer than countdown + race timeout + save/marker retries, so no live settlement is judged early.
	return math.max(DuelRules.MIN_RECOVER_AGE, cfg.Countdown + cfg.Timeout + 120)
end

local recover
recover = function(userId)
	if recovering[userId] or not Players:GetPlayerByUserId(userId) then return end
	recovering[userId] = true
	local retryIn
	local ok, err = pcall(function()
		local deadline = os.clock() + PROFILE_WAIT_SECONDS
		local profile = liveProfile(Players:GetPlayerByUserId(userId))
		while not profile and Players:GetPlayerByUserId(userId) and os.clock() < deadline do
			task.wait(0.5)
			profile = liveProfile(Players:GetPlayerByUserId(userId))
		end
		local ledger = profile and profile[LEDGER_KEY]
		if type(ledger) ~= "table" then return end
		local minAge = recoverMinAge()
		local ids = {}
		for duelId in pairs(ledger) do table.insert(ids, duelId) end
		for _, duelId in ipairs(ids) do
			-- Re-resolve the player and profile each time: earlier iterations yield (grants, marker reads).
			local player = Players:GetPlayerByUserId(userId)
			local current = liveProfile(player)
			local currentLedger = current and current[LEDGER_KEY]
			if type(currentLedger) ~= "table" then break end
			local entry = currentLedger[duelId]
			if entry == nil then continue end
			local live = (duels[duelId] ~= nil and not duels[duelId].Settled) or settling[duelId] == true
			local age = os.time() - (type(entry) == "table" and tonumber(entry.At) or 0)
			local marker = nil
			if DuelRules.needsMarker(entry, live, age, minAge) then marker = readLostMarker(duelId, userId) end
			local action = DuelRules.recoveryAction(entry, live, marker, age, minAge)
			if action.Action == "Pay" then
				player = Players:GetPlayerByUserId(userId)
				if player and payWithRetry(player, { UserId = userId, Cash = action.Amount, Xp = 0, Reason = "DuelRefund",
					CommandId = DuelRules.recoverCommandId(duelId, userId) }) then
					ledgerDelete(player, duelId) -- same thread, straight after the grant
					print(tag(string.format("RECOVERED %s user=%d cash=%d", duelId, userId, action.Amount)))
				end
			elseif action.Action == "Delete" then
				ledgerDelete(Players:GetPlayerByUserId(userId), duelId)
				print(tag(string.format("CLEARED %s user=%d (marker=%s)", duelId, userId, tostring(marker))))
			elseif action.Action == "Defer" then
				retryIn = math.min(retryIn or math.huge, action.RetryIn)
			end
		end
	end)
	recovering[userId] = nil
	if not ok then warn(tag("recovery failed user=" .. userId .. ": " .. tostring(err))) end
	if retryIn and not closing then
		task.delay(retryIn + 5, recover, userId)
	end
end

-- Pending challenges -------------------------------------------------------------------------------------
-- Closes a duel that never escrowed money (Challenged -> Expired | Declined).
local function closePending(duel, outcome, code, rejected)
	if duel.State ~= DuelRules.States.Challenged then return end
	assert(DuelRules.transition(duel, outcome))
	if rejected then
		local cfg = settings()
		DuelRules.recordRejection(limiter, os.clock(), duel.ChallengerId, duel.TargetId,
			{ MuteAfter = cfg.MuteAfter, MuteSeconds = cfg.MuteSeconds })
	end
	forget(duel)
	-- `code` is from the challenger's side; the target sees the swapped message.
	push(duel.Challenger, { Type = "Duel:Closed", DuelId = duel.Id, Outcome = outcome, Message = code and DuelRules.message(code) or nil })
	push(duel.Target, { Type = "Duel:Closed", DuelId = duel.Id, Outcome = outcome,
		Message = code and DuelRules.message(DuelRules.swapPerspective(code)) or nil })
end

-- Settlement ---------------------------------------------------------------------------------------------
local ACTIVITY_OUTCOME = { Winner = "Complete", Loser = "Failed", Draw = "Cancelled" }

-- The only path that moves escrowed Cash. Runs once per duel. Everything before run() is synchronous.
-- Losers' entries are NOT deleted here: run() first writes their durable Lost markers, then raises the
-- winner's saved claim to the pot, and only then deletes the losers' entries. Any failure on that path turns
-- the settlement into refunds for both players.
local function settle(duel, outcome, winnerId, why, synchronous)
	if duel.Settled then return end
	if not DuelRules.canTransition(duel.State, outcome) then
		warn(tag(string.format("%s cannot go %s -> %s; settling as Draw", duel.Id, tostring(duel.State), tostring(outcome))))
		outcome, winnerId = "Draw", nil
	end
	assert(DuelRules.transition(duel, outcome))
	duel.Settled = true
	local cfg = settings()
	local elapsed = duel.StartedClock and (os.clock() - duel.StartedClock) or 0
	local payouts = DuelRules.settlement(duel, outcome, winnerId, {
		Win = cfg.WinXp, Lose = cfg.LoseXp, Draw = cfg.DrawXp, Eligible = elapsed >= cfg.MinXpRace,
	})
	local escrow = duel.Escrow
	duel.Escrow = {} -- ownership of the stakes has moved into `payouts` and the saved ledger

	local steps = DuelRules.ledgerPlan({ Escrow = escrow }, payouts)
	local losers = {}
	for userId, step in pairs(steps) do
		if step.Action == "Delete" then table.insert(losers, userId) end
	end
	table.sort(losers)
	for userId, step in pairs(steps) do
		if step.Action == "Owe" then
			-- Until the losers' markers exist, the winner's saved claim is only their own stake.
			local amount = (#losers > 0 and userId == winnerId) and (escrow[userId] or 0) or step.Amount
			ledgerOwe(Players:GetPlayerByUserId(userId), duel.Id, amount)
		end
	end
	forget(duel)
	settling[duel.Id] = true

	for userId, racer in pairs(duel.Racers) do
		release(racer.Vehicle, racer.Player)
		local recordId = duel.Records[userId]
		local current = present(racer.Player) and ActivityService.Current(racer.Player)
		if recordId and current and current.Id == recordId then
			local role = outcome == "Draw" and "Draw" or (userId == winnerId and "Winner" or "Loser")
			ActivityService.End(racer.Player, recordId, ACTIVITY_OUTCOME[role])
		end
	end

	local function refundsInstead(attempted)
		-- Undo the markers of EVERY loser whose write was attempted: a write that errored may still have landed.
		-- RemoveAsync is idempotent; only a failed removal of a possibly-written marker burns that stake.
		local stuck = {}
		for _, userId in ipairs(attempted) do
			if not removeLostMarker(duel.Id, userId) then stuck[userId] = true end
		end
		for _, payout in ipairs(payouts) do
			if payout.Role == "Winner" and (payout.Cash or 0) > 0 then
				local own = escrow[payout.UserId] or 0
				payout.Cash, payout.Reason = own, "DuelRefund"
				payout.CommandId = DuelRules.refundCommandId(duel.Id, payout.UserId)
				ledgerOwe(Players:GetPlayerByUserId(payout.UserId), duel.Id, own)
			end
		end
		for _, userId in ipairs(losers) do
			local stake = escrow[userId] or 0
			if stuck[userId] then
				-- The marker says Lost and cannot be removed: refunding now could be matched by nothing, but a
				-- later recovery would clear the entry, so the stake is burned rather than minted. Loud.
				ledgerDelete(Players:GetPlayerByUserId(userId), duel.Id)
				warn(tag(string.format("BURNED %s user=%d stake=%d (Lost marker could not be undone)", duel.Id, userId, stake)))
			else
				ledgerOwe(Players:GetPlayerByUserId(userId), duel.Id, stake)
				table.insert(payouts, { UserId = userId, Cash = stake, Xp = 0, Reason = "DuelRefund",
					CommandId = DuelRules.refundCommandId(duel.Id, userId), Role = "Refund" })
			end
		end
		warn(tag(duel.Id .. " pot not released; settled as refunds"))
	end

	local function run()
		if #losers > 0 then
			local attempted, potOk = {}, true
			for _, userId in ipairs(losers) do
				table.insert(attempted, userId)
				if not writeLostMarker(duel.Id, userId) then potOk = false end
			end
			if potOk then
				-- Raise the winner's saved claim to the pot (fails if they are gone or their profile closed).
				potOk = steps[winnerId] ~= nil and ledgerOwe(Players:GetPlayerByUserId(winnerId), duel.Id, steps[winnerId].Amount)
			end
			if potOk then
				-- Persist the raised claim before anything else (a crash now must not leave markers without it).
				potOk = forceSave(winnerId, Workspace:GetServerTimeNow() + WINNER_SAVE_SECONDS)
				if not potOk then warn(tag(duel.Id .. " winner force-save failed after markers; settling as refunds")) end
			end
			if potOk then
				for _, userId in ipairs(losers) do
					ledgerDelete(Players:GetPlayerByUserId(userId), duel.Id) -- offline losers: the marker covers it
				end
			else
				refundsInstead(attempted)
			end
		end
		local paid = {}
		for _, payout in ipairs(payouts) do
			local player = Players:GetPlayerByUserId(payout.UserId)
			local mine = paid[payout.UserId] or { Cash = 0, Xp = 0 }
			paid[payout.UserId] = mine
			-- Cash alone first (GrantCash does not yield), then the ledger entry is deleted in the same thread;
			-- XP (ProgressionService may yield) follows with its own CommandId.
			if payout.Cash > 0 then
				if player and payWithRetry(player, { UserId = payout.UserId, Cash = payout.Cash, Xp = 0,
					Reason = payout.Reason, CommandId = payout.CommandId }) then
					ledgerDelete(player, duel.Id)
					mine.Cash += payout.Cash
				else
					warn(tag(string.format("UNPAID %s user=%d cash=%d command=%s (left in saved escrow for recovery)",
						duel.Id, payout.UserId, payout.Cash, payout.CommandId)))
				end
			end
			if payout.Xp > 0 and player and payWithRetry(player, { UserId = payout.UserId, Cash = 0, Xp = payout.Xp,
				Reason = payout.Reason, CommandId = payout.CommandId .. ":xp" }) then
				mine.Xp += payout.Xp
			end
		end
		settling[duel.Id] = nil
		for _, userId in ipairs({ duel.ChallengerId, duel.TargetId }) do
			local player = Players:GetPlayerByUserId(userId)
			local mine = paid[userId]
			push(player, {
				Type = "Duel:Result", DuelId = duel.Id, Outcome = outcome, Reason = why,
				WinnerUserId = winnerId, Cash = mine and mine.Cash or 0, Xp = mine and mine.Xp or 0,
				Stake = duel.Stake,
			})
			-- A player who left and rejoined this server while we were paying gets any leftover now.
			if player and not closing then task.spawn(recover, userId) end
		end
		print(tag(string.format("%s %s winner=%s why=%s stake=%d", duel.Id, outcome, tostring(winnerId), tostring(why), duel.Stake)))
	end
	if synchronous then run() else task.spawn(run) end
end

local function forfeit(duel, loser, why)
	if duel.Settled then return end
	if duel.State == DuelRules.States.Challenged then
		closePending(duel, "Expired", nil, false)
		return
	end
	if closing then
		settle(duel, "Draw", nil, "ServerClosing", true)
		return
	end
	settle(duel, "Forfeit", otherOf(duel, loser.UserId).UserId, why, false)
end

-- Race lifecycle -----------------------------------------------------------------------------------------
-- Picks a fair road finish near the pair. May yield on the first road-graph load, so it runs before the
-- commit block, never inside it.
local function chooseFinish(cfg, a, b)
	local middle = DuelRules.midpoint(a, b)
	local rng = Random.new()
	return DuelRules.pickFinish(a, b, cfg.MinFinish, cfg.MaxFinish, 8, function()
		return ActivityService.RandomRoadPoint(middle, cfg.MinFinish, cfg.MaxFinish, rng)
	end, cfg.FinishGap)
end

-- Runs in the accept tick straight after the commit block (no yield).
local function startCountdown(duel, cfg, finish)
	duel.Finish = finish
	for _, racer in pairs(duel.Racers) do
		freeze(racer.Vehicle)
		racer.FrozenAt = rootOf(racer.Vehicle).Position
	end
	assert(DuelRules.transition(duel, "Countdown"))
	duel.GoAt = Workspace:GetServerTimeNow() + cfg.Countdown
	if duel.Stake > 0 then
		-- Persist both debits + escrow entries before anyone can win the pot (B1). GO checks the results.
		duel.Saved = {}
		for userId in pairs(duel.Racers) do
			task.spawn(function()
				duel.Saved[userId] = forceSave(userId, duel.GoAt)
			end)
		end
	end
	for userId, racer in pairs(duel.Racers) do
		local opponent = otherOf(duel, userId)
		push(racer.Player, {
			Type = "Duel:Countdown", DuelId = duel.Id, GoAtServerTime = duel.GoAt, Finish = finish,
			OpponentUserId = opponent.UserId, OpponentName = opponent.DisplayName,
			Stake = duel.Stake, Pot = DuelRules.potFor(duel.Stake), FinishRadius = cfg.FinishRadius,
		})
	end
end

local function go(duel)
	if duel.Stake > 0 then
		local saved = duel.Saved or {}
		if not (saved[duel.ChallengerId] and saved[duel.TargetId]) then
			settle(duel, "Draw", nil, "SaveFailed", false)
			return
		end
	end
	-- A car must still be frozen where the duel froze it (re-entering a car during the countdown unanchors it)
	-- and be driven by its owner. Faults are judged for both racers together.
	local faults = {}
	for userId, racer in pairs(duel.Racers) do
		local vehicle = racer.Vehicle
		local root = rootOf(vehicle)
		local intact = vehicle ~= nil and vehicle.Parent ~= nil and root ~= nil
			and ActivityService.GetDrivenVehicle(racer.Player) == vehicle
			and DuelRules.frozenIntact(racer.FrozenAt, root.Position, vehicle:GetAttribute("DuelFrozen"), root.Anchored,
				FROZEN_TOLERANCE_STUDS)
		if not intact then faults[userId] = true end
	end
	local verdict, winnerId = DuelRules.faultOutcome(faults, duel.ChallengerId, duel.TargetId)
	if verdict then
		settle(duel, verdict, winnerId, "NotReadyAtGo", false)
		return
	end
	for _, racer in pairs(duel.Racers) do
		racer.Start = racer.FrozenAt -- the path is measured from the freeze point
		racer.Last = racer.FrozenAt
		racer.Path = 0
		racer.Warned = false
		release(racer.Vehicle, racer.Player)
	end
	assert(DuelRules.transition(duel, "Racing"))
	duel.StartedClock = os.clock()
	pushBoth(duel, { Type = "Duel:Go", DuelId = duel.Id })
end

local function stepRacing(duel, cfg)
	local elapsed = os.clock() - duel.StartedClock
	if elapsed >= cfg.Timeout then
		settle(duel, "Draw", nil, "Timeout", false)
		return
	end
	local mode = RaceIntegrity.mode()
	local checks = DuelRules.integrityChecks(duel.Stake, mode)
	local enforced = DuelRules.integrityEnforced(duel.Stake, mode)
	local maxSpeed = RaceIntegrity.limitMph() * MPH_TO_STUDS
	local lost = {}
	for userId, racer in pairs(duel.Racers) do
		local vehicle = racer.Vehicle
		if not (rootOf(vehicle) and vehicle.Parent) or ActivityService.GetVehicle(racer.Player) ~= vehicle then
			lost[userId] = true
		end
	end
	local lostVerdict, lostWinner = DuelRules.faultOutcome(lost, duel.ChallengerId, duel.TargetId)
	if lostVerdict then
		settle(duel, lostVerdict, lostWinner, "VehicleLost", false)
		return
	end
	local flagged, arrivals = {}, {}
	for userId, racer in pairs(duel.Racers) do
		local position = rootOf(racer.Vehicle).Position
		racer.Path += DuelRules.flatDistance(racer.Last, position)
		racer.Last = position
		if checks and not DuelRules.pathAllowed(racer.Path, elapsed, maxSpeed, cfg.Jitter, cfg.Tolerance) then
			if not racer.Warned then
				racer.Warned = true
				warn(string.format("[RACE-01] %s duel %s user=%d stake=%d path %.0f studs in %.2fs (limit %.0f mph)",
					enforced and "Enforce" or "Log", duel.Id, userId, duel.Stake, racer.Path, elapsed, maxSpeed * 0.625))
			end
			if enforced then flagged[userId] = true end
		end
		local toFinish = DuelRules.flatDistance(position, duel.Finish)
		if toFinish <= cfg.FinishRadius then
			table.insert(arrivals, { UserId = userId, Distance = toFinish })
		end
	end
	local verdict, integrityWinner = DuelRules.faultOutcome(flagged, duel.ChallengerId, duel.TargetId)
	if verdict then
		settle(duel, verdict, integrityWinner, "Integrity", false)
		return
	end
	local outcome, winnerId = DuelRules.resolveArrivals(arrivals)
	if outcome == "Finished" then
		settle(duel, "Finished", winnerId, "Finished", false)
	elseif outcome == "Draw" then
		settle(duel, "Draw", nil, "Tie", false)
	end
end

local accumulator, pruneAt = 0, 0
local function tick(dt)
	accumulator += dt
	if accumulator < TICK_SECONDS then return end
	accumulator = 0
	local cfg = settings()
	local clock = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local list = {}
	for _, duel in pairs(duels) do table.insert(list, duel) end
	for _, duel in ipairs(list) do
		if not duel.Settled and duels[duel.Id] == duel then
			local ok, message = pcall(function()
				if duel.State == "Challenged" and clock >= duel.ExpiresClock and not duel.Accepting then
					closePending(duel, "Expired", "Expired", true)
				elseif duel.State == "Countdown" and serverNow >= duel.GoAt then
					go(duel)
				elseif duel.State == "Racing" then
					stepRacing(duel, cfg)
				end
			end)
			if not ok then
				warn(tag("tick error " .. duel.Id .. ": " .. tostring(message)))
				if DuelRules.holdsEscrow(duel.State) then settle(duel, "Draw", nil, "Error", false) end
			end
		end
	end
	if clock >= pruneAt then
		pruneAt = clock + 30
		DuelRules.pruneLimiter(limiter, clock, cfg.Cooldown)
	end
end

-- Actions ------------------------------------------------------------------------------------------------
local function reply(ok, code, extra)
	local result = extra or {}
	result.Ok = ok
	if code then result.Message = DuelRules.message(code) result.Code = code end
	return result
end

local function challenge(player, args)
	args = type(args) == "table" and args or {}
	local targetId = tonumber(args.TargetUserId)
	local target = targetId and Players:GetPlayerByUserId(targetId) or nil
	local cfg = settings()

	if args.Preview == true then
		-- Stake menu for the client: the stakes both players may use right now (no state change).
		local input = gather(cfg, player, target, 0)
		local ok, code = DuelRules.validateChallenge(input)
		if not ok then return reply(false, code) end
		local stakes = DuelRules.availableStakes(input, function(amount)
			return ActivityPayout.CanAfford(player, amount), ActivityPayout.CanAfford(target, amount)
		end)
		return reply(true, nil, { Stakes = stakes, StakeMinRank = cfg.StakeMinRank })
	end

	local stake = tonumber(args.Stake)
	local input = gather(cfg, player, target, stake)
	local ok, code = DuelRules.validateChallenge(input)
	if not ok then return reply(false, code) end

	local now = os.clock()
	local duel = {
		Id = ActivityService.NewId("duel") .. "-" .. serverTag,
		State = DuelRules.States.Challenged,
		Challenger = player, Target = target,
		ChallengerId = player.UserId, TargetId = target.UserId,
		Stake = stake,
		Escrow = {}, Records = {}, Racers = {},
		ExpiresClock = now + cfg.ChallengeTimeout,
		Settled = false,
	}
	duels[duel.Id] = duel
	byUser[duel.ChallengerId] = duel.Id
	byUser[duel.TargetId] = duel.Id
	DuelRules.recordChallenge(limiter, now, player.UserId)
	local expiresAt = Workspace:GetServerTimeNow() + cfg.ChallengeTimeout
	push(target, {
		Type = "Duel:Challenge", DuelId = duel.Id, FromUserId = player.UserId, FromName = player.DisplayName,
		Stake = stake, ExpiresAt = expiresAt,
	})
	return reply(true, nil, { DuelId = duel.Id, ExpiresAt = expiresAt })
end

-- Accept: re-validate, pick the finish, re-validate, then commit in one tick with no yield. Every failure
-- branch leaves no Cash moved or refunds the single debit that did happen.
local function accept(player, duel)
	local cfg = settings()
	local challenger = duel.Challenger
	if not present(challenger) then
		closePending(duel, "Expired", "TargetMissing", false)
		return reply(false, "TargetMissing")
	end
	local function revalidate()
		local input = gather(cfg, challenger, player, duel.Stake, { SkipLimiter = true, IgnorePending = true })
		local ok, code = DuelRules.validateChallenge(input)
		if not ok then
			closePending(duel, "Expired", code, false)
			return nil, reply(false, DuelRules.swapPerspective(code))
		end
		return input, nil
	end
	local input, failure = revalidate()
	if not input then return failure end

	-- Finish first: it may yield, and nothing has been committed yet. `Accepting` stops a second tap from
	-- running another accept meanwhile; the duel may be closed (leave, expiry) while we wait.
	duel.Accepting = true
	local a, b = rootOf(input.ChallengerVehicle).Position, rootOf(input.TargetVehicle).Position
	local found, finish = pcall(chooseFinish, cfg, a, b)
	duel.Accepting = nil
	if duels[duel.Id] ~= duel or duel.State ~= DuelRules.States.Challenged then return reply(false, "Expired") end
	if not (found and finish) then
		if not found then warn(tag("finish selection failed: " .. tostring(finish))) end
		closePending(duel, "Expired", "NoFinish", false)
		return reply(false, "NoFinish")
	end
	input, failure = revalidate() -- the world may have changed during the yield
	if not input then return failure end

	-- ===== commit block: no yields from here to the transition =====
	local stake = duel.Stake
	if stake > 0 and not (liveProfile(challenger) and liveProfile(player)) then
		closePending(duel, "Expired", "TargetMissing", false)
		return reply(false, "TargetMissing")
	end
	local challengerRecord = ActivityService.Begin(challenger, KIND, { DuelId = duel.Id, Role = "Challenger" })
	if not challengerRecord then
		closePending(duel, "Expired", "Busy", false)
		return reply(false, "TargetBusy")
	end
	local targetRecord = ActivityService.Begin(player, KIND, { DuelId = duel.Id, Role = "Target" })
	if not targetRecord then
		ActivityService.End(challenger, challengerRecord.Id, "Cancelled")
		closePending(duel, "Expired", "TargetBusy", false)
		return reply(false, "Busy")
	end
	if stake > 0 then
		local debited = ActivityPayout.Debit(challenger, stake, "DuelStake")
		if not debited then
			ActivityService.End(challenger, challengerRecord.Id, "Cancelled")
			ActivityService.End(player, targetRecord.Id, "Cancelled")
			closePending(duel, "Expired", "ChallengerFunds", false)
			return reply(false, "TargetFunds")
		end
		ledgerOpen(challenger, duel.Id, stake) -- same tick as the debit
		duel.Escrow[duel.ChallengerId] = stake
		debited = ActivityPayout.Debit(player, stake, "DuelStake")
		if not debited then
			-- Should be impossible after validation in the same tick. Refund the first debit immediately;
			-- the challenger's ledger entry becomes Owed = stake until the refund lands.
			duel.Escrow = {}
			ledgerOwe(challenger, duel.Id, stake)
			ActivityService.End(challenger, challengerRecord.Id, "Cancelled")
			ActivityService.End(player, targetRecord.Id, "Cancelled")
			closePending(duel, "Expired", "TargetFunds", false)
			warn(tag("second debit failed for " .. duel.Id .. "; refunding challenger"))
			task.spawn(function()
				local current = Players:GetPlayerByUserId(duel.ChallengerId)
				if current and payWithRetry(current, { UserId = duel.ChallengerId, Cash = stake, Xp = 0, Reason = "DuelRefund",
					CommandId = DuelRules.refundCommandId(duel.Id, duel.ChallengerId) }) then
					ledgerDelete(current, duel.Id)
				end
			end)
			return reply(false, "ChallengerFunds")
		end
		ledgerOpen(player, duel.Id, stake) -- same tick as the debit
		duel.Escrow[duel.TargetId] = stake
		DuelRules.recordPairStake(limiter, os.clock(), duel.ChallengerId, duel.TargetId)
	end
	duel.Records[duel.ChallengerId] = challengerRecord.Id
	duel.Records[duel.TargetId] = targetRecord.Id
	duel.Racers[duel.ChallengerId] = { Player = challenger, Vehicle = input.ChallengerVehicle }
	duel.Racers[duel.TargetId] = { Player = player, Vehicle = input.TargetVehicle }
	assert(DuelRules.transition(duel, "Accepted"))
	-- ===== end commit block =====

	DuelRules.recordAccepted(limiter, duel.ChallengerId, duel.TargetId)
	local started, message = pcall(startCountdown, duel, cfg, finish)
	if not started then
		warn(tag("countdown failed " .. duel.Id .. ": " .. tostring(message)))
		settle(duel, "Draw", nil, "Error", false)
	end
	return reply(true, nil, { DuelId = duel.Id })
end

local function respond(player, args)
	args = type(args) == "table" and args or {}
	local duel = type(args.DuelId) == "string" and duels[args.DuelId] or nil
	if not duel or duel.TargetId ~= player.UserId then return reply(false, "NotYours") end
	if duel.Accepting then return reply(false, "Pending") end
	if closing then
		closePending(duel, "Expired", "Closing", false)
		return reply(false, "Closing")
	end
	if duel.State ~= DuelRules.States.Challenged or os.clock() >= duel.ExpiresClock then
		closePending(duel, "Expired", "Expired", true)
		return reply(false, "Expired")
	end
	if args.Accept ~= true then
		closePending(duel, "Declined", nil, true)
		return reply(true, nil, { Declined = true })
	end
	return accept(player, duel)
end

-- Core cleanup (exit vehicle past grace, despawn, garage, race join, death, leave). The cancelled player
-- forfeits; the opponent is paid by settle() (the cancelled player is never paid here).
local function onCancel(player, record, reason)
	local duelId = (type(record) == "table" and type(record.Data) == "table" and record.Data.DuelId) or byUser[player.UserId]
	local duel = duelId and duels[duelId]
	if not duel or duel.Settled then return end
	-- Core has already ended this record; do not End it again from settle().
	duel.Records[player.UserId] = nil
	forfeit(duel, player, "Cancelled:" .. tostring(reason))
end

local function onPlayerRemoving(player)
	local duelId = byUser[player.UserId]
	local duel = duelId and duels[duelId]
	if duel and not duel.Settled then
		forfeit(duel, player, "Left")
	end
end

-- Best effort: profiles are usually already closing here, so these refunds normally fail and the saved
-- escrow entries (Owed = 0 or own stake, no Lost marker) are refunded on the players' next join instead
-- (after the MIN_RECOVER_AGE deferral for Owed = 0 entries).
local function onClose()
	closing = true
	local list = {}
	for _, duel in pairs(duels) do table.insert(list, duel) end
	for _, duel in ipairs(list) do
		if duel.State == DuelRules.States.Challenged then
			closePending(duel, "Expired", nil, false)
		elseif not duel.Settled then
			settle(duel, "Draw", nil, "ServerClosing", true)
		end
	end
end

function DuelService.start()
	if state ~= "idle" then return end
	state = "starting"
	local ok, message = xpcall(function()
		ActivityService.Register(KIND, {
			Actions = { DuelChallenge = challenge, DuelRespond = respond },
			OnCancel = onCancel,
			RequiresVehicle = true,
		})
		table.insert(connections, RunService.Heartbeat:Connect(function(dt)
			local okTick, err = pcall(tick, dt)
			if not okTick then warn(tag("tick failed: " .. tostring(err))) end
		end))
		table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
		table.insert(connections, Players.PlayerAdded:Connect(function(player)
			task.spawn(recover, player.UserId)
		end))
		for _, player in ipairs(Players:GetPlayers()) do task.spawn(recover, player.UserId) end
		game:BindToClose(onClose)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

-- Read-only diagnostics for Studio harnesses.
function DuelService.Snapshot()
	local out = {}
	for id, duel in pairs(duels) do
		local escrow = 0
		for _, amount in pairs(duel.Escrow) do escrow += amount end
		out[id] = { State = duel.State, Stake = duel.Stake, Escrow = escrow, ChallengerId = duel.ChallengerId, TargetId = duel.TargetId }
	end
	return out
end

return DuelService
