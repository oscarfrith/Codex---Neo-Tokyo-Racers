-- NTR Racing Phase 11C - Server Grid Vehicle Spawn
-- Paste into Roblox Studio Command Bar in Edit mode.
--
-- This phase removes the race-entry client as the owner of vehicle spawning.
-- The menu now sends the selected VehicleId only; the Racing services ask the
-- Garage server to spawn that selected vehicle directly at the grid/start line.
--
-- Source patch note: this uses guarded exact-source anchors against isolated
-- Racing scripts plus one small server binding inside the Garage action script.
-- If any anchor fails, refresh the Studio mirror before another repair.

local PHASE = "NTR Racing Phase 11C"

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function serverServices()
	local root = ServerScriptService:FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	if not services then fail("Missing ServerScriptService.NeoTokyoRacers.Services") end
	return services
end

local function racingServices()
	local racing = serverServices():FindFirstChild("Racing")
	if not racing then fail("Missing ServerScriptService.NeoTokyoRacers.Services.Racing") end
	return racing
end

local function garageServices()
	local garage = serverServices():FindFirstChild("Garage")
	if not garage then fail("Missing ServerScriptService.NeoTokyoRacers.Services.Garage") end
	return garage
end

local function racingClients()
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = starterScripts and starterScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	if not racing then fail("Missing StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing") end
	return racing
end

local function replaceOnce(source, oldText, newText, label)
	local at = string.find(source, oldText, 1, true)
	if not at then
		fail("Could not find source block: " .. label)
	end
	return string.sub(source, 1, at - 1) .. newText .. string.sub(source, at + #oldText), true
end

local function insertBefore(source, anchor, insertText, marker)
	if string.find(source, marker, 1, true) then
		return source, false
	end
	local at = string.find(source, anchor, 1, true)
	if not at then
		fail("Could not find source anchor before " .. marker)
	end
	return string.sub(source, 1, at - 1) .. insertText .. string.sub(source, at), true
end

local function insertAfter(source, anchor, insertText, marker)
	if string.find(source, marker, 1, true) then
		return source, false
	end
	local at = string.find(source, anchor, 1, true)
	if not at then
		fail("Could not find source anchor after " .. marker)
	end
	local insertAt = at + #anchor
	return string.sub(source, 1, insertAt) .. insertText .. string.sub(source, insertAt + 1), true
end

local function patchGarageBinding()
	local scriptObj = garageServices():FindFirstChild("GarageActionController_Shadow_Disabled")
	if not scriptObj then fail("Missing GarageActionController_Shadow_Disabled") end
	local source = scriptObj.Source
	local bindingBlock = [=[

	-- NTR_RACING_PHASE11C_GRID_VEHICLE_BINDING
	local function V95_selectedRaceVehicleReady(profile, args)
		args = typeof(args) == "table" and args or {}
		local okSelect, selectMessage = V89_selectVehicleInstance(profile, {
			VehicleId = args.VehicleId,
			CockpitId = args.CockpitId,
		})
		if not okSelect then
			return false, selectMessage
		end
		if not V76_coreModulesEquipped(profile) then
			return false, "Equip at least one engine, stabilisers, and boost before racing."
		end
		return true, "Vehicle ready."
	end

	local function V95_spawnOwnedVehicleForRace(player, profile, args)
		args = typeof(args) == "table" and args or {}
		local spawnCFrame = args.SpawnCFrame
		if typeof(spawnCFrame) ~= "CFrame" then
			return { Ok = false, Success = false, Message = "Race spawn CFrame missing." }
		end
		local okReady, readyMessage = V95_selectedRaceVehicleReady(profile, args)
		if not okReady then
			return { Ok = false, Success = false, Message = readyMessage }
		end
		local vehicle, err = V56_buildVehicle(player, profile, spawnCFrame)
		if not vehicle then
			return { Ok = false, Success = false, Message = err or "Race vehicle spawn failed." }
		end
		vehicle:SetAttribute("NTR_RaceGridSpawned", true)
		vehicle:SetAttribute("DriveReady", false)
		return {
			Ok = true,
			Success = true,
			Message = "Race vehicle spawned.",
			Vehicle = vehicle,
			VehicleId = tostring(profile.CurrentVehicleId or ""),
		}
	end

	local function V95_ensureRaceVehicleSpawnBinding()
		local binding = script:FindFirstChild("RaceVehicleSpawner")
		if binding and not binding:IsA("BindableFunction") then
			binding:Destroy()
			binding = nil
		end
		if not binding then
			binding = Instance.new("BindableFunction")
			binding.Name = "RaceVehicleSpawner"
			binding.Parent = script
		end
		binding.OnInvoke = function(action, payload)
			payload = typeof(payload) == "table" and payload or {}
			local player = payload.Player
			if not (player and player:IsA("Player")) then
				return { Ok = false, Success = false, Message = "Player missing." }
			end
			local profile = V56_getProfile(player)
			if action == "ValidateForRace" then
				local okReady, readyMessage = V95_selectedRaceVehicleReady(profile, payload)
				if okReady then
					V88_syncInstanceDataFromLegacy(profile)
					V80_mirrorLegacyProfileToPersistence(player, profile, "SelectVehicleInstance", false)
				end
				return {
					Ok = okReady == true,
					Success = okReady == true,
					Message = readyMessage,
					VehicleId = tostring(profile.CurrentVehicleId or ""),
				}
			elseif action == "SpawnForRace" then
				local result = V95_spawnOwnedVehicleForRace(player, profile, payload)
				if result.Ok == true then
					V88_syncInstanceDataFromLegacy(profile)
					V80_mirrorLegacyProfileToPersistence(player, profile, "SpawnRaceVehicle", false)
				end
				return result
			end
			return { Ok = false, Success = false, Message = "Unknown race vehicle action." }
		end
	end
	V95_ensureRaceVehicleSpawnBinding()
]=]
	local changed
	source, changed = insertBefore(source, [=[
	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_SERVER
]=], bindingBlock, "NTR_RACING_PHASE11C_GRID_VEHICLE_BINDING")
	if changed then
		scriptObj.Source = source
		log("Installed Garage race vehicle spawn binding.")
	else
		log("Garage race vehicle spawn binding already installed.")
	end
end

local raceSpawnerHelpers = [=[
-- NTR_RACING_PHASE11C_SERVER_GRID_SPAWN_HELPERS
-- NTR_RACING_PHASE11C_BINDING_LOOKUP_REPAIR
local function getRaceVehicleSpawner()
	local okService, serverScriptService = pcall(function()
		return game:GetService("ServerScriptService")
	end)
	if not okService or not serverScriptService then
		return nil, "ServerScriptService unavailable."
	end
	local serverRoot = serverScriptService:FindFirstChild("NeoTokyoRacers")
	if not serverRoot then
		return nil, "NeoTokyoRacers server root missing."
	end
	local services = serverRoot:FindFirstChild("Services")
	if not services then
		return nil, "NeoTokyoRacers services folder missing."
	end
	local garage = services:FindFirstChild("Garage")
	if not garage then
		return nil, "Garage services folder missing."
	end
	local action = garage:FindFirstChild("GarageActionController_Shadow_Disabled")
	if not action then
		return nil, "Garage action controller missing."
	end
	local binding = action:FindFirstChild("RaceVehicleSpawner")
	if binding and binding:IsA("BindableFunction") then
		return binding, nil
	end
	return nil, "RaceVehicleSpawner binding missing. Run Phase 11C in Edit mode, then restart Play."
end

local function invokeRaceVehicleSpawner(action, payload)
	local binding, bindingError = getRaceVehicleSpawner()
	if not binding then
		return { Ok = false, Success = false, Message = bindingError or "Race vehicle spawner is not ready." }
	end
	local ok, result = pcall(function()
		return binding:Invoke(action, payload or {})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Success = false, Message = "Race vehicle spawner failed: " .. tostring(result) }
end

local function validateRaceVehicleForPlayer(player, vehicleId, cockpitId)
	local result = invokeRaceVehicleSpawner("ValidateForRace", {
		Player = player,
		VehicleId = vehicleId,
		CockpitId = cockpitId,
	})
	if result.Ok == true or result.Success == true then
		return true, result.Message or "Vehicle ready.", result.VehicleId
	end
	return false, result.Message or "Selected vehicle is not ready."
end

local function spawnRaceVehicleForPlayer(player, vehicleId, cockpitId, spawnCFrame)
	local result = invokeRaceVehicleSpawner("SpawnForRace", {
		Player = player,
		VehicleId = vehicleId,
		CockpitId = cockpitId,
		SpawnCFrame = spawnCFrame,
	})
	if (result.Ok == true or result.Success == true) and result.Vehicle then
		return result.Vehicle, nil, result.VehicleId
	end
	return nil, result.Message or "Could not spawn selected vehicle at grid.", result.VehicleId
end

]=]

local function ensureServerScriptServiceLocal(source)
	if string.find(source, "local ServerScriptService = game:GetService(\"ServerScriptService\")", 1, true) then
		return source, false
	end
	return insertAfter(source, [=[local Workspace = game:GetService("Workspace")
]=], [=[local ServerScriptService = game:GetService("ServerScriptService")
]=], "ServerScriptService")
end

local function patchTimeTrialService()
	local scriptObj = racingServices():FindFirstChild("TimeTrialService_Active")
	if not scriptObj then fail("Missing TimeTrialService_Active") end
	local source = scriptObj.Source
	local changedAny = false
	local changed
	source, changed = ensureServerScriptServiceLocal(source)
	changedAny = changedAny or changed
	source, changed = insertBefore(source, [=[local function beginStagedTimeTrial(player, eventId, vehicleId, requestedLapCount)
]=], raceSpawnerHelpers, "NTR_RACING_PHASE11C_SERVER_GRID_SPAWN_HELPERS")
	changedAny = changedAny or changed

	local oldBlock = [=[	if activeRuns[player] then
		return false, "Already in a race/time trial."
	end
	local vehicle, vehicleError = currentVehicleForPlayer(player)
	if not vehicle then
		return false, vehicleError
	end
	local route, routeError = RaceConfigReader.GetRouteForEvent(eventId, "TimeTrial")
	if not route then
		return false, routeError
	end
	if RouteDefinition.GetGateCount(route) < 2 then
		return false, "Route needs checkpoints and a finish line."
	end
	local summary = RaceConfigReader.GetEventSummary(eventId, "TimeTrial") or {}
	local routeType = tostring(summary.RouteType or route.RouteType or "Circuit")
	if routeType ~= "PointToPoint" then
		routeType = "Circuit"
	end
	local maxLapCount = math.clamp(tonumber(summary.MaxLapCount) or 10, 1, 10)
	local minLapCount = math.clamp(tonumber(summary.MinLapCount) or 1, 1, maxLapCount)
	local lapTarget = tonumber(requestedLapCount)
	if routeType == "PointToPoint" then
		lapTarget = 1
	elseif lapTarget == 0 and summary.AllowInfiniteLaps == true then
		lapTarget = 0
	else
		lapTarget = math.clamp(math.floor(lapTarget or tonumber(summary.DefaultLapCount) or 1), minLapCount, maxLapCount)
	end
	local tier = tostring(vehicle:GetAttribute("PerformanceTier") or "")]=]
	local newBlock = [=[	if activeRuns[player] then
		return false, "Already in a race/time trial."
	end
	local route, routeError = RaceConfigReader.GetRouteForEvent(eventId, "TimeTrial")
	if not route then
		return false, routeError
	end
	if RouteDefinition.GetGateCount(route) < 2 then
		return false, "Route needs checkpoints and a finish line."
	end
	local summary = RaceConfigReader.GetEventSummary(eventId, "TimeTrial") or {}
	local routeType = tostring(summary.RouteType or route.RouteType or "Circuit")
	if routeType ~= "PointToPoint" then
		routeType = "Circuit"
	end
	local maxLapCount = math.clamp(tonumber(summary.MaxLapCount) or 10, 1, 10)
	local minLapCount = math.clamp(tonumber(summary.MinLapCount) or 1, 1, maxLapCount)
	local lapTarget = tonumber(requestedLapCount)
	if routeType == "PointToPoint" then
		lapTarget = 1
	elseif lapTarget == 0 and summary.AllowInfiniteLaps == true then
		lapTarget = 0
	else
		lapTarget = math.clamp(math.floor(lapTarget or tonumber(summary.DefaultLapCount) or 1), minLapCount, maxLapCount)
	end
	local stageCFrame = startCFrameForRoute(route, 1) * CFrame.new(0, 4, 0)
	local vehicle, vehicleError, selectedVehicleId = spawnRaceVehicleForPlayer(player, vehicleId, nil, stageCFrame)
	if not vehicle then
		return false, vehicleError
	end
	local tier = tostring(vehicle:GetAttribute("PerformanceTier") or "") -- NTR_RACING_PHASE11C_TT_GRID_SPAWN]=]
	if not string.find(source, "NTR_RACING_PHASE11C_TT_GRID_SPAWN", 1, true) then
		source, changed = replaceOnce(source, oldBlock, newBlock, "time-trial grid vehicle spawn")
		changedAny = changedAny or changed
	end
	local gsubCount
	source, gsubCount = string.gsub(source, "SelectedVehicleId = tostring%(%s*vehicleId or \"\"%s*%),", "SelectedVehicleId = tostring(selectedVehicleId or vehicleId or \"\"),", 1)
	changedAny = changedAny or gsubCount > 0
	if changedAny then
		scriptObj.Source = source
		log("Patched TimeTrialService_Active to spawn selected vehicles at the start grid.")
	else
		log("TimeTrialService_Active already has Phase 11C grid spawn.")
	end
end

local function patchRaceMatchmakingService()
	local scriptObj = racingServices():FindFirstChild("RaceMatchmakingService_Active")
	if not scriptObj then fail("Missing RaceMatchmakingService_Active") end
	local source = scriptObj.Source
	local changedAny = false
	local changed
	source, changed = ensureServerScriptServiceLocal(source)
	changedAny = changedAny or changed
	source, changed = insertBefore(source, [=[local function raceEventSummary(eventId)
]=], raceSpawnerHelpers, "NTR_RACING_PHASE11C_SERVER_GRID_SPAWN_HELPERS")
	changedAny = changedAny or changed

	if not string.find(source, "NTR_RACING_PHASE11C_JOIN_VALIDATE_SELECTED", 1, true) then
		source, changed = replaceOnce(source, [=[	local vehicle, vehicleError = currentVehicleForPlayer(player)
	if not vehicle then
		return false, vehicleError
	end
	local summary, route, eventError = raceEventSummary(eventId)]=], [=[	local selectedOk, selectedMessage, selectedVehicleId = validateRaceVehicleForPlayer(player, vehicleId, nil)
	if not selectedOk then
		return false, selectedMessage
	end
	local summary, route, eventError = raceEventSummary(eventId) -- NTR_RACING_PHASE11C_JOIN_VALIDATE_SELECTED]=], "race queue selected vehicle validation")
		changedAny = changedAny or changed
	end
	local gsubCount
	source, gsubCount = string.gsub(source, "queue.VehicleIds%[player%] = tostring%(%s*vehicleId or \"\"%s*%)", "queue.VehicleIds[player] = tostring(selectedVehicleId or vehicleId or \"\")", 1)
	changedAny = changedAny or gsubCount > 0

	if not string.find(source, "NTR_RACING_PHASE11C_RACE_GRID_SPAWN", 1, true) then
		source, changed = replaceOnce(source, [=[	for _, player in ipairs(queue.Players) do
		queuedByPlayer[player] = nil
		local vehicle, vehicleError = currentVehicleForPlayer(player)
		if vehicle then
			table.insert(participants, {
				Player = player,
				Vehicle = vehicle,
				SelectedVehicleId = tostring(queue.VehicleIds[player] or ""),
				NextGateIndex = 1,
				LastCompletedGateIndex = 0,
				GridIndex = #participants + 1,
				LastTouchClock = 0,
				LastProgressElapsed = 0,
			})
		else
			fire(player, {
				Type = "RaceQueueError",
				EventId = queue.EventId,
				Message = vehicleError or "Vehicle unavailable before race start.",
			})
		end
	end]=], [=[	for _, player in ipairs(queue.Players) do
		queuedByPlayer[player] = nil
		local gridIndex = #participants + 1
		local selectedVehicleId = tostring(queue.VehicleIds[player] or "")
		local spawnCFrame = spawnCFrameForIndex(queue.Route, gridIndex) * CFrame.new(0, 4, 0)
		local vehicle, vehicleError, spawnedVehicleId = spawnRaceVehicleForPlayer(player, selectedVehicleId, nil, spawnCFrame)
		if vehicle then
			table.insert(participants, {
				Player = player,
				Vehicle = vehicle,
				SelectedVehicleId = tostring(spawnedVehicleId or selectedVehicleId or ""),
				NextGateIndex = 1,
				LastCompletedGateIndex = 0,
				GridIndex = gridIndex,
				LastTouchClock = 0,
				LastProgressElapsed = 0,
			})
		else
			fire(player, {
				Type = "RaceQueueError",
				EventId = queue.EventId,
				Message = vehicleError or "Could not spawn selected vehicle at race grid.",
			})
		end
	end -- NTR_RACING_PHASE11C_RACE_GRID_SPAWN]=], "race start grid vehicle spawn")
		changedAny = changedAny or changed
	end

	if changedAny then
		scriptObj.Source = source
		log("Patched RaceMatchmakingService_Active to validate selected vehicles and spawn them at the grid.")
	else
		log("RaceMatchmakingService_Active already has Phase 11C grid spawn.")
	end
end

local function patchEntryMenuClient()
	local scriptObj = racingClients():FindFirstChild("RaceEntryMenuClient_Active")
	if not scriptObj then fail("Missing RaceEntryMenuClient_Active") end
	local source = scriptObj.Source
	local changedAny = false
	local changed

	if not string.find(source, "NTR_RACING_PHASE11B_RACE_EVENT_ID_PAIRING", 1, true) then
		local helper = [=[

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
]=], helper, "NTR_RACING_PHASE11B_RACE_EVENT_ID_PAIRING")
		changedAny = changedAny or changed
	end

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
	}]=], "entry state RaceEventId")
		changedAny = changedAny or changed
	end

	if not string.find(source, "NTR_RACING_PHASE11C_CLIENT_RACE_NO_SPAWN", 1, true) then
		local phase11bRaceBlock = [=[			local raceEventId = raceEventIdForStart()
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
			end -- NTR_RACING_PHASE11B_RACE_VALIDATE_BEFORE_SPAWN]=]
		local oldRaceBlock = [=[			local raceEventId = tostring(state.Entry and state.Entry.EventId or "shifted_canal_sprint_race")
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
			end]=]
		local newRaceBlock = [=[			local raceEventId = raceEventIdForStart()
			local eventCheck = callRace("GetEntryDetails", {
				EventId = raceEventId,
				Mode = "Race",
			})
			if eventCheck.Ok ~= true and eventCheck.Success ~= true then
				statusText(eventCheck.Message or "Race event is not available.", false)
				return
			end
			statusText("Joining race queue. Your selected vehicle will spawn on the grid.", true)
			-- NTR_RACING_PHASE11C_CLIENT_RACE_NO_SPAWN]=]
		if string.find(source, phase11bRaceBlock, 1, true) then
			source, changed = replaceOnce(source, phase11bRaceBlock, newRaceBlock, "Phase 11B race client spawn removal")
		else
			source, changed = replaceOnce(source, oldRaceBlock, newRaceBlock, "old race client spawn removal")
		end
		changedAny = changedAny or changed
	end

	if not string.find(source, "NTR_RACING_PHASE11C_CLIENT_TT_NO_SPAWN", 1, true) then
		local phase11bTtBlock = [=[		local spawn = { Ok = true, Success = true }
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
		end -- NTR_RACING_PHASE11B_TT_SKIP_CURRENT_RESPAWN]=]
		local oldTtBlock = [=[		statusText("Spawning selected vehicle...", true)
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
		end]=]
		local newTtBlock = [=[		statusText("Staging selected vehicle at the start line.", true)
		-- NTR_RACING_PHASE11C_CLIENT_TT_NO_SPAWN]=]
		if string.find(source, phase11bTtBlock, 1, true) then
			source, changed = replaceOnce(source, phase11bTtBlock, newTtBlock, "Phase 11B time-trial client spawn removal")
		else
			source, changed = replaceOnce(source, oldTtBlock, newTtBlock, "old time-trial client spawn removal")
		end
		changedAny = changedAny or changed
	end

	if changedAny then
		scriptObj.Source = source
		log("Patched RaceEntryMenuClient_Active so menu selection no longer spawns free-roam vehicles.")
	else
		log("RaceEntryMenuClient_Active already has Phase 11C client no-spawn flow.")
	end
end

patchGarageBinding()
patchTimeTrialService()
patchRaceMatchmakingService()
patchEntryMenuClient()

log("Install complete. Restart Play and test race/time-trial start without sitting in a vehicle first.")
