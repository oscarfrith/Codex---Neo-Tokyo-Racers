-- Neo Tokyo Racers - Racing Phase 3D Time Trial Event Pairing Repair
-- Fixes the case where START TIME TRIAL is clicked from RaceStartZone:
-- the client spawned the selected car through the garage path, then sent the
-- Race event id to StartStagedTimeTrial, so the race service never staged the
-- vehicle at the grid.
--
-- This patches only isolated Racing service/client scripts. It does not touch
-- the main bootstrap, garage server, driving, VFX, dealership, or customisation.
--
-- Usage:
--   Run in Roblox Studio Command Bar in Edit mode, then restart Play.

local PHASE = "NTR Racing Phase 3D"

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 0)
end

local function replaceExact(source, needle, replacement, label)
	local startIndex, endIndex = source:find(needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another racing Phase 3D repair.")
	end
	return source:sub(1, startIndex - 1) .. replacement .. source:sub(endIndex + 1)
end

local function patchServer()
	local serverRoot = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Racing")
	local service = serverRoot and serverRoot:FindFirstChild("TimeTrialService_Active")
	if not (service and service:IsA("Script")) then
		fail("Could not find TimeTrialService_Active. Run Racing Phase 3 first.")
	end

	local source = service.Source
	if source:find("NTR_RACING_PHASE3D_EVENT_PAIRING", 1, true) then
		info("TimeTrialService_Active already has Phase 3D pairing repair.")
		return
	end

	local oldAnchor = [[
local function beginStagedTimeTrial(player, eventId, vehicleId)
	if activeRuns[player] then
]]

	local newAnchor = [[
local function resolveTimeTrialEventId(eventId)
	-- NTR_RACING_PHASE3D_EVENT_PAIRING
	eventId = tostring(eventId or "shifted_canal_sprint_tt")
	local direct = RaceConfigReader.GetTimeTrialEvent(eventId)
	if direct then
		return eventId
	end

	local raceSummary = RaceConfigReader.GetEventSummary(eventId, "Race")
	local raceRouteId = raceSummary and raceSummary.RouteId or ""
	local config = kit:FindFirstChild("Config")
	local racing = config and config:FindFirstChild("Racing")
	local catalog = racing and racing:FindFirstChild("TimeTrialCatalog")
	if raceRouteId ~= "" and catalog then
		for _, candidate in ipairs(catalog:GetChildren()) do
			local routeId = tostring(candidate:GetAttribute("RouteId") or "")
			if routeId == raceRouteId then
				local paired = tostring(candidate:GetAttribute("EventId") or candidate.Name)
				if paired ~= "" then
					return paired
				end
			end
		end
	end

	if eventId:sub(-5) == "_race" then
		return eventId:sub(1, -6) .. "_tt"
	end
	return "shifted_canal_sprint_tt"
end

local function beginStagedTimeTrial(player, eventId, vehicleId)
	eventId = resolveTimeTrialEventId(eventId)
	if activeRuns[player] then
]]

	source = replaceExact(source, oldAnchor, newAnchor, "beginStagedTimeTrial start")

	local oldPayload = [[
	fire(player, {
		Type = "OpenRaceEntry",
		EventId = eventId,
		Mode = mode,
		Summary = summary,
		Message = mode == "Race" and "Race matchmaking is coming soon. Time trial is available now." or "",
	})
]]

	local newPayload = [[
	fire(player, {
		Type = "OpenRaceEntry",
		EventId = eventId,
		TimeTrialEventId = resolveTimeTrialEventId(eventId),
		Mode = mode,
		Summary = summary,
		Message = mode == "Race" and "Race matchmaking is coming soon. Time trial is available now." or "",
	})
]]

	source = replaceExact(source, oldPayload, newPayload, "OpenRaceEntry payload")
	service.Source = source
	service.Disabled = false
	info("Patched TimeTrialService_Active to resolve paired time-trial events.")
end

local function patchClient()
	local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local racingFolder = controllers and controllers:FindFirstChild("Racing")
	local client = racingFolder and racingFolder:FindFirstChild("RaceEntryMenuClient_Active")
	if not (client and client:IsA("LocalScript")) then
		fail("Could not find RaceEntryMenuClient_Active. Run Racing Phase 3 first.")
	end

	local source = client.Source
	if source:find("NTR_RACING_PHASE3D_CLIENT_PAIRING", 1, true) then
		info("RaceEntryMenuClient_Active already has Phase 3D pairing repair.")
		return
	end

	local oldHelperAnchor = [[
local function ownedRows()
	local profile = refreshProfile() or {}
]]

	local newHelperAnchor = [[
local function timeTrialEventIdForStart()
	-- NTR_RACING_PHASE3D_CLIENT_PAIRING
	local entry = state.Entry or {}
	local paired = tostring(entry.TimeTrialEventId or "")
	if paired ~= "" then
		return paired
	end
	local eventId = tostring(entry.EventId or "shifted_canal_sprint_tt")
	if eventId:sub(-5) == "_race" then
		return eventId:sub(1, -6) .. "_tt"
	end
	return eventId ~= "" and eventId or "shifted_canal_sprint_tt"
end

local function ownedRows()
	local profile = refreshProfile() or {}
]]

	source = replaceExact(source, oldHelperAnchor, newHelperAnchor, "timeTrialEventIdForStart insertion")

	local oldState = [[
	state.Entry = {
		EventId = payload.EventId or summary.EventId or "shifted_canal_sprint_tt",
		Mode = payload.Mode or summary.Mode or "TimeTrial",
		Summary = summary,
	}
]]

	local newState = [[
	state.Entry = {
		EventId = payload.EventId or summary.EventId or "shifted_canal_sprint_tt",
		TimeTrialEventId = payload.TimeTrialEventId,
		Mode = payload.Mode or summary.Mode or "TimeTrial",
		Summary = summary,
	}
]]

	source = replaceExact(source, oldState, newState, "state.Entry TimeTrialEventId")

	local oldStartBlock = [[
		statusText("Spawning selected vehicle...", true)
		local spawn = callGarage("SpawnOwnedVehicleFromFreeRoam", {
			VehicleId = row.VehicleId,
			CockpitId = row.CockpitId,
		})
]]

	local newStartBlock = [[
		local timeTrialEventId = timeTrialEventIdForStart()
		local eventCheck = callRace("GetEntryDetails", {
			EventId = timeTrialEventId,
			Mode = "TimeTrial",
		})
		if eventCheck.Ok ~= true and eventCheck.Success ~= true then
			statusText(eventCheck.Message or "Time trial event is not available.", false)
			return
		end
		statusText("Spawning selected vehicle...", true)
		local spawn = callGarage("SpawnOwnedVehicleFromFreeRoam", {
			VehicleId = row.VehicleId,
			CockpitId = row.CockpitId,
		})
]]

	source = replaceExact(source, oldStartBlock, newStartBlock, "pre-spawn time-trial event check")

	local oldRaceCall = [[
		local startResult = callRace("StartStagedTimeTrial", {
			EventId = state.Entry and state.Entry.EventId or "shifted_canal_sprint_tt",
			VehicleId = row.VehicleId,
		})
]]

	local newRaceCall = [[
		local startResult = callRace("StartStagedTimeTrial", {
			EventId = timeTrialEventId,
			VehicleId = row.VehicleId,
		})
]]

	source = replaceExact(source, oldRaceCall, newRaceCall, "StartStagedTimeTrial paired event id")
	client.Source = source
	client.Disabled = false
	info("Patched RaceEntryMenuClient_Active to start the paired time-trial event before spawning loops.")
end

patchServer()
patchClient()

info("Installed Phase 3D event pairing repair.")
info("Restart Play, enter RaceStartZone, choose START TIME TRIAL, pick a vehicle once, and verify it stages at SpawnGrid/Grid_01.")
