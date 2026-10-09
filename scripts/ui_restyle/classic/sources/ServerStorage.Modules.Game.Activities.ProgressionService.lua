-- Canonical feature implementation; startup is owned by the composition root.
-- Driver Rank owner (Street Life). Saves profile.Progression through ProfileServer, grants rank-up Cash
-- through EconomyServer (reason RankReward), replicates Rank/XpIntoRank/XpForNext Player attributes and
-- pushes Rank:Up on ActivityEvent. XP sources: drive-to-earn and race/time-trial Cash (via
-- EconomyCashCommitted) and activities (ActivityPayout). Idempotent per CommandId within a session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Signal"))

local Service = {}
Service.RankChanged = Signal.new() -- (player, newRank, oldRank)
local state

local modules = ServerStorage:WaitForChild("Modules")
local ProfileServer = require(modules:WaitForChild("Game"):WaitForChild("Player"):WaitForChild("ProfileServer"))
local FeatureFlags = require(modules:WaitForChild("Core"):WaitForChild("FeatureFlags"))
local Rules = require(modules.Game:WaitForChild("Activities"):WaitForChild("ProgressionRules"))

local config = ReplicatedStorage:WaitForChild("Config"):WaitForChild("Activities"):WaitForChild("Progression")
local activityEvent
local executeEconomy

local claims = {} -- [player] = { Lookup = {}, Order = {} }
local driveCarry = {} -- [player] = fractional XP carried between drive grants
local driveCounter = 0

local function settings()
	return Rules.Settings(function(key) return config:GetAttribute(key) end)
end

local function enabled()
	return FeatureFlags.IsEnabled("EnableDriverRank", true)
end

local function progressionOf(player)
	local profile = ProfileServer.get_profile(player)
	if not profile then return nil, nil end
	profile.Progression = Rules.Normalize(profile.Progression, settings())
	return profile, profile.Progression
end

local function publish(player, progression)
	local s = settings()
	player:SetAttribute("Rank", progression.Rank)
	player:SetAttribute("XpIntoRank", progression.Xp)
	player:SetAttribute("XpForNext", progression.Rank >= s.MaxRank and 0 or Rules.XpForRank(progression.Rank, s))
end

local function claim(player, commandId)
	local record = claims[player]
	if not record then record = { Lookup = {}, Order = {} }; claims[player] = record end
	if record.Lookup[commandId] then return false end
	record.Lookup[commandId] = true
	table.insert(record.Order, commandId)
	if #record.Order > 512 then record.Lookup[table.remove(record.Order, 1)] = nil end
	return true
end

local function grantRankCash(player, rank)
	local amount = Rules.RankCash(rank, settings())
	if amount <= 0 or not executeEconomy then return 0 end
	local ok, result
	for attempt = 1, 6 do
		if player.Parent ~= Players then return 0 end
		ok, result = pcall(function()
			return executeEconomy:Invoke(player, { Version = 1, Action = "GrantCash", Amount = amount, Reason = "RankReward", CommandId = "RankReward:" .. player.UserId .. ":" .. rank })
		end)
		if ok and type(result) == "table" and (result.Ok or result.Success) then return tonumber(result.Amount) or amount end
		-- XP from drive/race cash arrives inside the EconomyServer per-player lock, so a first try can be Busy.
		if not (ok and type(result) == "table" and result.RejectionReason == "Busy") then break end
		task.wait(0.25 * attempt)
	end
	warn("[ProgressionService] rank cash not granted for rank " .. rank .. ": " .. tostring(ok and type(result) == "table" and result.RejectionReason or result))
	return 0
end

-- Adds XP. Returns { Xp, Rank, RankedUp } (Xp = xp into current rank). Never yields before the save mark.
function Service.AddXp(player, amount, reason, commandId)
	amount = math.floor(tonumber(amount) or 0)
	if not enabled() or amount <= 0 or typeof(player) ~= "Instance" or player.Parent ~= Players then return { Xp = 0, Rank = Service.GetRank(player), RankedUp = false } end
	assert(type(commandId) == "string" and commandId ~= "", "AddXp needs a CommandId")
	local profile, progression = progressionOf(player)
	if not profile then return { Xp = 0, Rank = 1, RankedUp = false } end
	if not claim(player, commandId) then return { Xp = progression.Xp, Rank = progression.Rank, RankedUp = false, AlreadyApplied = true } end
	local oldRank = progression.Rank
	local reached = Rules.Apply(progression, amount, settings())
	ProfileServer.mark_dirty(player, profile, "Progression:" .. tostring(reason))
	publish(player, progression)
	if #reached > 0 then
		Service.RankChanged:Fire(player, progression.Rank, oldRank)
		pcall(function() require(modules.Game.Player:WaitForChild("AnalyticsServer")).Custom(player, "RankUp", progression.Rank) end)
		task.defer(function()
			local cash = 0
			for _, rank in ipairs(reached) do cash += grantRankCash(player, rank) end
			if activityEvent and player.Parent == Players then
				activityEvent:FireClient(player, { Type = "Rank:Up", Rank = progression.Rank, Cash = cash })
			end
		end)
	end
	return { Xp = progression.Xp, Rank = progression.Rank, RankedUp = #reached > 0 }
end

function Service.GetRank(player)
	return tonumber(typeof(player) == "Instance" and player:GetAttribute("Rank")) or 1
end

function Service.XpForRank(rank)
	return Rules.XpForRank(rank, settings())
end

local function track(player)
	task.spawn(function()
		for _ = 1, 120 do
			if player.Parent ~= Players then return end
			local profile, progression = progressionOf(player)
			if profile then
				publish(player, progression)
				return
			end
			task.wait(0.5)
		end
	end)
end

function Service.start()
	if state then assert(state == "ready", "Service already starting or failed"); return end
	state = "starting"
	local ok, message = xpcall(function()
		activityEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Activities"):WaitForChild("ActivityEvent")
		local bindings = ServerStorage:WaitForChild("Runtime"):WaitForChild("Player"):WaitForChild("ProfileServiceBindings")
		executeEconomy = bindings:WaitForChild("ExecuteEconomyCommand")
		local committed = bindings:WaitForChild("EconomyCashCommitted")
		committed.Event:Connect(function(player, _, details)
			if type(details) ~= "table" or typeof(player) ~= "Instance" then return end
			local amount = tonumber(details.Amount) or 0
			if amount <= 0 then return end
			local reason = tostring(details.Reason)
			if reason == "DriveToEarnCash" then
				local xp, carry = Rules.DriveXp(amount, driveCarry[player], settings())
				driveCarry[player] = carry
				if xp > 0 then
					driveCounter += 1
					Service.AddXp(player, xp, "Drive", "DriveXp:" .. player.UserId .. ":" .. driveCounter)
				end
			elseif reason == "RaceReward" or reason == "TimeTrialReward" then
				Service.AddXp(player, Rules.RaceXp(amount, settings()), reason, "RaceXp:" .. tostring(details.CommandId))
			end
		end)
		Players.PlayerAdded:Connect(track)
		for _, player in ipairs(Players:GetPlayers()) do track(player) end
		Players.PlayerRemoving:Connect(function(player)
			claims[player] = nil
			driveCarry[player] = nil
		end)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return Service
