-- NTR Racing Phase 11A repair - RaceMatchmaking parse repair
-- Paste into Roblox Studio Command Bar in Edit mode.
--
-- Use this if Play reports:
--   RaceMatchmakingService_Active:<line>: Expected <eof>, got 'end'
--
-- Root fix: remove any partial Phase 11A race reward bridge / finishEntry
-- patch from the isolated race service, then install one clean canonical
-- reward-enabled finishEntry block. This does not edit reward config.

local PHASE = "NTR Racing Phase 11A Parse Repair"

local ServerScriptService = game:GetService("ServerScriptService")

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function racingServices()
	local root = ServerScriptService:FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	local racing = services and services:FindFirstChild("Racing")
	if not racing then fail("Missing ServerScriptService.NeoTokyoRacers.Services.Racing") end
	return racing
end

local function stripFunction(source, functionName)
	local startIndex = string.find(source, "local function " .. functionName .. "%(", 1, false)
	if not startIndex then
		return source, false
	end
	local nextIndex = string.find(source, "\nlocal function ", startIndex + 1, true)
	if not nextIndex then
		fail("Could not find end boundary after " .. functionName)
	end
	return string.sub(source, 1, startIndex - 1) .. string.sub(source, nextIndex + 1), true
end

local function replaceBetween(source, startMarker, endMarker, replacement)
	local startIndex = string.find(source, startMarker, 1, true)
	if not startIndex then
		fail("Could not find start marker: " .. startMarker)
	end
	local endIndex = string.find(source, endMarker, startIndex + #startMarker, true)
	if not endIndex then
		fail("Could not find end marker after " .. startMarker .. ": " .. endMarker)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. "\n\n" .. string.sub(source, endIndex)
end

local REWARD_BRIDGE = [=[
local function callRaceRewardService(action, payload)
	-- NTR_RACING_PHASE11A_RACE_REWARD_BRIDGE_CANONICAL
	local bindings = script.Parent:FindFirstChild("RaceRewardBindings")
	local binding = bindings and bindings:FindFirstChild("GrantRaceReward")
	if not (binding and binding:IsA("BindableFunction")) then
		return nil
	end
	local ok, result = pcall(function()
		return binding:Invoke(action, payload or {})
	end)
	if ok then
		return result
	end
	warn("[NTR Racing Phase 11A] Race reward service failed: " .. tostring(result))
	return nil
end
]=]

local FINISH_ENTRY = [=[
local function finishEntry(race, entry)
	-- NTR_RACING_PHASE11A_FINISH_ENTRY_CANONICAL
	if entry.Finished then return end
	entry.Finished = true
	entry.FinishElapsed = now() - race.StartClock
	entry.FinishPlace = race.NextFinishPlace
	race.NextFinishPlace += 1
	local rewardResult = callRaceRewardService("GrantRaceReward", {
		Player = entry.Player,
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
	}) or {}
	if entry.Vehicle then
		prepareVehicleForDriving(entry.Player, entry.Vehicle)
	end
	fire(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		DisplayName = race.DisplayName,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
		GateCount = race.GateCount,
		RaceMedal = rewardResult.Medal,
		RewardGranted = rewardResult.Granted == true,
		RewardAmount = tonumber(rewardResult.Amount) or 0,
		RewardMessage = tostring(rewardResult.Message or ""),
	})
	fireRace(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		NextGateIndex = race.GateCount,
		GateCount = race.GateCount,
	})
	broadcastPositions(race)
	if allFinished(race) then
		task.delay(5, function()
			cleanupRace(race, "Finished")
		end)
	end
end
]=]

local scriptObj = racingServices():FindFirstChild("RaceMatchmakingService_Active")
if not scriptObj then fail("Missing RaceMatchmakingService_Active") end

local source = scriptObj.Source
local strippedBridge = false
source, strippedBridge = stripFunction(source, "callRaceRewardService")

source = replaceBetween(
	source,
	"local function finishEntry(race, entry)",
	"local function advanceCheckpoint(race, entry, touchedPart)",
	REWARD_BRIDGE .. "\n\n" .. FINISH_ENTRY
)

scriptObj.Source = source
log("Repaired RaceMatchmakingService_Active. Removed partial bridge=" .. tostring(strippedBridge) .. ". Restart Play.")
