-- NTR Racing Phase 11C Binding Lookup Repair
-- Paste into Roblox Studio Command Bar in Edit mode, then restart Play.
--
-- Fixes the first Phase 11C runtime error:
-- TimeTrialService_Active:getRaceVehicleSpawner attempted to index nil with
-- FindFirstChild while looking up the garage RaceVehicleSpawner binding.
--
-- This repair replaces only the Phase 11C helper block in the isolated Racing
-- services with a direct, fully-guarded ServerScriptService lookup.

local PHASE = "NTR Racing Phase 11C Binding Lookup Repair"

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
	if not racing then
		fail("Missing ServerScriptService.NeoTokyoRacers.Services.Racing")
	end
	return racing
end

local saferHelpers = [=[
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

local function replaceHelper(scriptObj, nextAnchor)
	if not scriptObj then
		fail("Missing expected Racing service script.")
	end
	local source = scriptObj.Source
	local marker = "-- NTR_RACING_PHASE11C_SERVER_GRID_SPAWN_HELPERS"
	local startAt = string.find(source, marker, 1, true)
	if not startAt then
		fail(scriptObj.Name .. " does not contain Phase 11C helper marker.")
	end
	local endAt = string.find(source, nextAnchor, startAt, true)
	if not endAt then
		fail(scriptObj.Name .. " missing helper end anchor: " .. nextAnchor)
	end
	local current = string.sub(source, startAt, endAt - 1)
	if string.find(current, "NTR_RACING_PHASE11C_BINDING_LOOKUP_REPAIR", 1, true) then
		log(scriptObj.Name .. " already has the binding lookup repair.")
		return false
	end
	scriptObj.Source = string.sub(source, 1, startAt - 1) .. saferHelpers .. string.sub(source, endAt)
	log("Repaired " .. scriptObj.Name .. " binding lookup helper.")
	return true
end

local racing = racingServices()
local changedCount = 0
if replaceHelper(racing:FindFirstChild("TimeTrialService_Active"), "local function beginStagedTimeTrial") then
	changedCount += 1
end
if replaceHelper(racing:FindFirstChild("RaceMatchmakingService_Active"), "local function raceEventSummary") then
	changedCount += 1
end

log("Complete. Repaired helpers in " .. tostring(changedCount) .. " service(s). Restart Play before testing.")
