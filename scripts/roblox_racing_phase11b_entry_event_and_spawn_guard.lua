-- NTR Racing Phase 11B - Entry Event Pairing And Spawn Guard
-- Paste into Roblox Studio Command Bar in Edit mode.
--
-- Fixes:
-- - START RACE can accidentally send a time-trial event id to matchmaking.
-- - START RACE validates the race event before touching the selected vehicle.
-- - START RACE / START TIME TRIAL skips garage respawn when the selected card is
--   already the current vehicle, avoiding unnecessary fallback/customisation exits.
--
-- Note: choosing a different vehicle still uses the current garage spawn path.
-- A later server-side staging phase should spawn selected vehicles directly at
-- the race grid/start line after the race/time-trial request is accepted.

local PHASE = "NTR Racing Phase 11B"

local StarterPlayer = game:GetService("StarterPlayer")

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function racingClients()
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = starterScripts and starterScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	if not racing then fail("Missing StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing") end
	return racing
end

local function insertAfter(source, anchor, insertText, marker)
	if string.find(source, marker, 1, true) then
		return source, false
	end
	local at = string.find(source, anchor, 1, true)
	if not at then
		fail("Could not find source anchor for " .. marker)
	end
	local insertAt = at + #anchor
	return string.sub(source, 1, insertAt) .. insertText .. string.sub(source, insertAt + 1), true
end

local function replaceOnce(source, oldText, newText, marker)
	if string.find(source, marker, 1, true) then
		return source, false
	end
	local at = string.find(source, oldText, 1, true)
	if not at then
		fail("Could not find source block for " .. marker)
	end
	return string.sub(source, 1, at - 1) .. newText .. string.sub(source, at + #oldText), true
end

local scriptObj = racingClients():FindFirstChild("RaceEntryMenuClient_Active")
if not scriptObj then fail("Missing RaceEntryMenuClient_Active") end

local source = scriptObj.Source
local changedAny = false
local changed

local raceIdHelper = [=[

local function raceEventIdForStart()
	-- NTR_RACING_PHASE11B_RACE_EVENT_ID_PAIRING
	local entry = state.Entry or {}
	local paired = tostring(entry.RaceEventId or "")
	if paired ~= "" then
		return paired
	end
	local eventId = tostring(entry.EventId or "shifted_canal_sprint_race")
	if eventId:sub(-3) == "_tt" then
		return eventId:sub(1, -4) .. "_race"
	end
	return eventId ~= "" and eventId or "shifted_canal_sprint_race"
end
]=]
source, changed = insertAfter(source, [=[local function timeTrialEventIdForStart()
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
]=], raceIdHelper, "NTR_RACING_PHASE11B_RACE_EVENT_ID_PAIRING")
changedAny = changedAny or changed

if not string.find(source, "RaceEventId = payload.RaceEventId", 1, true) then
	source, changed = replaceOnce(source, [=[	state.Entry = {
		EventId = payload.EventId or summary.EventId or "shifted_canal_sprint_tt",
		TimeTrialEventId = payload.TimeTrialEventId,
		Mode = payload.Mode or summary.Mode or "TimeTrial",
		Summary = summary,
	}]=], [=[	state.Entry = {
		EventId = payload.EventId or summary.EventId or "shifted_canal_sprint_tt",
		RaceEventId = payload.RaceEventId, -- NTR_RACING_PHASE11B_STATE_RACE_EVENT_ID
		TimeTrialEventId = payload.TimeTrialEventId,
		Mode = payload.Mode or summary.Mode or "TimeTrial",
		Summary = summary,
	}]=], "NTR_RACING_PHASE11B_STATE_RACE_EVENT_ID")
	changedAny = changedAny or changed
end

source, changed = replaceOnce(source, [=[			local raceEventId = tostring(state.Entry and state.Entry.EventId or "shifted_canal_sprint_race")
			statusText("Spawning selected vehicle for race queue...", true)
			local spawn = callGarage("SpawnOwnedVehicleFromFreeRoam", {
				VehicleId = row.VehicleId,
				CockpitId = row.CockpitId,
			})
			if spawn.Success ~= true and spawn.Ok ~= true then
				local selectResult = callGarage("SelectVehicleInstance", {
					VehicleId = row.VehicleId,
					CockpitId = row.CockpitId,
				})
				if selectResult.Success ~= true and selectResult.Ok ~= true then
					statusText(selectResult.Message or selectResult.Error or spawn.Message or "Could not select vehicle.", false)
					return
				end
				spawn = callGarage("SpawnVehicle", {})
				if spawn.Success ~= true and spawn.Ok ~= true then
					statusText(spawn.Message or spawn.Error or "Could not spawn selected vehicle.", false)
					return
				end
			end]=], [=[			local raceEventId = raceEventIdForStart()
			local eventCheck = callRace("GetEntryDetails", {
				EventId = raceEventId,
				Mode = "Race",
			})
			if eventCheck.Ok ~= true and eventCheck.Success ~= true then
				statusText(eventCheck.Message or "Race event is not available.", false)
				return
			end
			local spawn = { Ok = true, Success = true }
			if row.Selected == true then
				statusText("Using current vehicle for race queue...", true)
			else
				statusText("Preparing selected vehicle for race queue...", true)
				spawn = callGarage("SpawnOwnedVehicleFromFreeRoam", {
					VehicleId = row.VehicleId,
					CockpitId = row.CockpitId,
				})
				if spawn.Success ~= true and spawn.Ok ~= true then
					local selectResult = callGarage("SelectVehicleInstance", {
						VehicleId = row.VehicleId,
						CockpitId = row.CockpitId,
					})
					if selectResult.Success ~= true and selectResult.Ok ~= true then
						statusText(selectResult.Message or selectResult.Error or spawn.Message or "Could not select vehicle.", false)
						return
					end
					spawn = callGarage("SpawnVehicle", {})
					if spawn.Success ~= true and spawn.Ok ~= true then
						statusText(spawn.Message or spawn.Error or "Could not spawn selected vehicle.", false)
						return
					end
				end
			end -- NTR_RACING_PHASE11B_RACE_VALIDATE_BEFORE_SPAWN]=], "NTR_RACING_PHASE11B_RACE_VALIDATE_BEFORE_SPAWN")
changedAny = changedAny or changed

source, changed = replaceOnce(source, [=[		statusText("Spawning selected vehicle...", true)
		local spawn = callGarage("SpawnOwnedVehicleFromFreeRoam", {
			VehicleId = row.VehicleId,
			CockpitId = row.CockpitId,
		})
		if spawn.Success ~= true and spawn.Ok ~= true then
			local selectResult = callGarage("SelectVehicleInstance", {
				VehicleId = row.VehicleId,
				CockpitId = row.CockpitId,
			})
			if selectResult.Success ~= true and selectResult.Ok ~= true then
				statusText(selectResult.Message or selectResult.Error or spawn.Message or "Could not select vehicle.", false)
				return
			end
			spawn = callGarage("SpawnVehicle", {})
			if spawn.Success ~= true and spawn.Ok ~= true then
				statusText(spawn.Message or spawn.Error or "Could not spawn selected vehicle.", false)
				return
			end
		end]=], [=[		local spawn = { Ok = true, Success = true }
		if row.Selected == true then
			statusText("Using current vehicle...", true)
		else
			statusText("Preparing selected vehicle...", true)
			spawn = callGarage("SpawnOwnedVehicleFromFreeRoam", {
				VehicleId = row.VehicleId,
				CockpitId = row.CockpitId,
			})
			if spawn.Success ~= true and spawn.Ok ~= true then
				local selectResult = callGarage("SelectVehicleInstance", {
					VehicleId = row.VehicleId,
					CockpitId = row.CockpitId,
				})
				if selectResult.Success ~= true and selectResult.Ok ~= true then
					statusText(selectResult.Message or selectResult.Error or spawn.Message or "Could not select vehicle.", false)
					return
				end
				spawn = callGarage("SpawnVehicle", {})
				if spawn.Success ~= true and spawn.Ok ~= true then
					statusText(spawn.Message or spawn.Error or "Could not spawn selected vehicle.", false)
					return
				end
			end
		end -- NTR_RACING_PHASE11B_TT_SKIP_CURRENT_RESPAWN]=], "NTR_RACING_PHASE11B_TT_SKIP_CURRENT_RESPAWN")
changedAny = changedAny or changed

if changedAny then
	scriptObj.Source = source
	log("Patched RaceEntryMenuClient_Active event pairing and spawn guard.")
else
	log("RaceEntryMenuClient_Active already has Phase 11B event/spawn guard.")
end
