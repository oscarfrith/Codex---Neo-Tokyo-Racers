-- Neo Tokyo Racers - Racing UI Phase 12 Race Result Snapshot Bridge
-- Paste into Roblox Studio Command Bar in Edit mode.
--
-- Relays the already-authoritative finish/reward values to the unified results
-- controller and enriches position rows with server-owned finish/vehicle data.
-- It does not alter finish order, reward calculation, reset, matchmaking, or cleanup.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 12"

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function matchmakingScript()
	local ntr = ServerScriptService:FindFirstChild("NeoTokyoRacers")
	local services = ntr and ntr:FindFirstChild("Services")
	local racing = services and services:FindFirstChild("Racing")
	local item = racing and racing:FindFirstChild("RaceMatchmakingService_Active")
	if not (item and item:IsA("LuaSourceContainer")) then
		fail("Missing active RaceMatchmakingService_Active")
	end
	return item
end

local function resultController()
	local scripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local ntr = scripts and scripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = ntr and ntr:FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	local item = racing and racing:FindFirstChild("RaceTimeTrialResultCoachClient_Active")
	if not (item and item:IsA("LuaSourceContainer")) then
		fail("Missing active unified result controller")
	end
	return item
end

local function replaceOnce(source, oldText, newText, label)
	local startAt, endAt = string.find(source, oldText, 1, true)
	if not startAt then
		fail("Could not find " .. label .. " anchor. Refresh the mirror before another repair.")
	end
	return string.sub(source, 1, startAt - 1) .. newText .. string.sub(source, endAt + 1)
end

local function installServerBridge()
	local item = matchmakingScript()
	local source = item.Source
	if string.find(source, "NTR_RACING_UI_PHASE12_RESULT_SNAPSHOT_BRIDGE", 1, true) then
		log("Server result snapshot bridge already installed.")
		return
	end

	local oldPositionFields = [=[			Finished = entry.Finished == true,
			NextGateIndex = entry.NextGateIndex,]=]
	local newPositionFields = [=[			Finished = entry.Finished == true,
			NextGateIndex = entry.NextGateIndex,
			FinishElapsed = tonumber(entry.FinishElapsed),
			VehicleId = tostring(entry.SelectedVehicleId or ""),
			VehicleName = tostring(entry.VehicleDisplayName or entry.SelectedVehicleId or ""), -- NTR_RACING_UI_PHASE12_RESULT_SNAPSHOT_BRIDGE]=]
	source = replaceOnce(source, oldPositionFields, newPositionFields, "position row")

	local oldFinishEvent = [=[	fireRace(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		NextGateIndex = race.GateCount,
		GateCount = race.GateCount,
	})]=]
	local newFinishEvent = [=[	fireRace(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		DisplayName = race.DisplayName,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
		NextGateIndex = race.GateCount,
		GateCount = race.GateCount,
		RaceMedal = rewardResult.Medal,
		RewardGranted = rewardResult.Granted == true,
		RewardAmount = tonumber(rewardResult.Amount) or 0,
		RewardMessage = tostring(rewardResult.Message or ""),
		SelectedVehicleId = tostring(entry.SelectedVehicleId or ""),
	})]=]
	source = replaceOnce(source, oldFinishEvent, newFinishEvent, "RaceFinished presentation event")
	item.Source = source
	log("Installed server-owned race result snapshot bridge.")
end

local function installClientRows()
	local item = resultController()
	local source = item.Source
	if string.find(source, "entry.FinishElapsed", 1, true) and string.find(source, "entry.VehicleName", 1, true) then
		log("Unified results rows already consume snapshot fields.")
		return
	end
	local oldText = [=[local positions=lastPositions or {} local rowH=touch and 28 or 34 for index,entry in ipairs(positions) do]=]
	local newText = [=[local positions=lastPositions or payload.Positions or {} local rowH=touch and 28 or 34 for index,entry in ipairs(positions) do]=]
	source = replaceOnce(source, oldText, newText, "results position source")
	local oldFinish = [=[local finish=you and timeText(payload.Elapsed) or (entry.Finished and "FINISHED" or "RACING") local values=]=]
	local newFinish = [=[local elapsed=tonumber(entry.FinishElapsed) or (you and tonumber(payload.Elapsed)) local finish=elapsed and timeText(elapsed) or (entry.Finished and "FINISHED" or "RACING") local vehicle=string.upper(tostring(entry.VehicleName or entry.VehicleId or "--")) local values=]=]
	source = replaceOnce(source, oldFinish, newFinish, "results finish time")
	source = replaceOnce(source, [=[{"--",.80,.20}]=], [=[{vehicle,.80,.20}]=], "results vehicle value")
	item.Source = source
	log("Updated unified results rows for authoritative finish and vehicle fields.")
end

local function smoke()
	local serverSource = matchmakingScript().Source
	local clientSource = resultController().Source
	assert(string.find(serverSource, "NTR_RACING_UI_PHASE12_RESULT_SNAPSHOT_BRIDGE", 1, true), "Server bridge marker missing")
	assert(string.find(serverSource, "RewardAmount = tonumber(rewardResult.Amount) or 0", 1, true), "RaceEvent reward relay missing")
	assert(string.find(clientSource, "entry.FinishElapsed", 1, true), "Client finish elapsed consumer missing")
	assert(string.find(clientSource, "entry.VehicleName", 1, true), "Client vehicle consumer missing")
	log("SMOKE PASS")
end

if MODE == "INSTALL" then
	installServerBridge()
	installClientRows()
	smoke()
	log("Install complete. Restart Play and finish a multiplayer race.")
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
