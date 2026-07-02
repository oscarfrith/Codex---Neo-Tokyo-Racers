-- Persistence Phase 20 garage profile runtime extraction.
--
-- One-file workflow:
-- 1. Run from Roblox Studio Command Bar in Edit mode to install.
-- 2. Restart Play, then run this same file from the CLIENT Command Bar to smoke-check.
--
-- This extracts the stable Phase 19 instance compatibility sync into:
-- ServerScriptService.NeoTokyoRacers.Services.Garage.GarageProfileRuntime
--
-- The big garage action controller keeps the same behavior, but now delegates
-- the sync to that ModuleScript. This is the first safe extraction step before
-- garage interiors/display vehicles are added.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local PHASE = "Persistence Phase 20 Garage Profile Runtime Extract"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 20 patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another Phase 20 patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local function runClientSmoke()
	local player = Players.LocalPlayer
	assert(player, "Client smoke must be run from the CLIENT Command Bar during Play.")

	local invoke = ReplicatedStorage
		:WaitForChild("NeoTokyoRacers")
		:WaitForChild("Shared")
		:WaitForChild("Remotes")
		:WaitForChild("Garage")
		:WaitForChild("GarageInvoke")

	local result = invoke:InvokeServer("GetInitial", {})
	assert(typeof(result) == "table" and result.Success == true, "GetInitial failed: " .. tostring(result and result.Message))
	local profile = result.Profile or {}
	local vehicleId = profile.CurrentVehicleId
	local vehicle = vehicleId and profile.Vehicles and profile.Vehicles[vehicleId] or nil
	assert(typeof(vehicle) == "table", "Current vehicle instance was not present in profile response.")

	local installedInstanceCount = 0
	local missingInstances = 0
	for _, moduleInstanceId in pairs(vehicle.InstalledModules or {}) do
		installedInstanceCount += 1
		if not ((profile.OwnedModuleInstances or {})[moduleInstanceId]) then
			missingInstances += 1
		end
	end
	assert(missingInstances == 0, "Current vehicle references missing module instances: " .. tostring(missingInstances))

	info("Smoke GetInitial OK.")
	info("CurrentVehicleId=" .. tostring(vehicleId) .. " installedInstanceSlots=" .. tostring(installedInstanceCount) .. " missingInstances=" .. tostring(missingInstances))
	info("Player attrs: RuntimeModule=" .. tostring(player:GetAttribute("NTR_PersistencePhase20RuntimeModule")) .. " syncCount=" .. tostring(player:GetAttribute("NTR_PersistencePhase20ModuleSyncCount")) .. " vehicle=" .. tostring(player:GetAttribute("NTR_PersistencePhase20VehicleId")))
	info("Expected RuntimeModule=GarageProfileRuntime. If so, the garage controller is delegating instance sync through the extracted server module.")
	return
end

if RunService:IsRunning() then
	runClientSmoke()
	return
end

local garageFolder = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")

local serverScript = garageFolder:WaitForChild("GarageActionController_Shadow_Disabled")
assert(serverScript:IsA("Script"), "Expected GarageActionController_Shadow_Disabled to be a Script.")

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local moduleSource = [=[-- GarageProfileRuntime
-- Persistence Phase 20 extraction target for garage profile helpers.

local HttpService = game:GetService("HttpService")

local GarageProfileRuntime = {}

local function cloneValue(value)
	if typeof(value) == "table" then
		local copy = {}
		for key, child in pairs(value) do
			copy[key] = cloneValue(child)
		end
		return copy
	end
	return value
end

local function countDictionary(dictionary)
	local count = 0
	for _ in pairs(dictionary or {}) do
		count += 1
	end
	return count
end

local function fallbackGenerateId(prefix)
	local guid = string.gsub(HttpService:GenerateGUID(false), "-", "")
	return tostring(prefix or "id") .. "_" .. string.sub(guid, 1, 12)
end

function GarageProfileRuntime.SyncInstanceDataFromLegacy(profile, options)
	options = typeof(options) == "table" and options or {}
	if typeof(profile) ~= "table" then
		return { SyncCount = 0, VehicleId = nil }
	end

	local ensureInstanceInventory = options.EnsureInstanceInventory
	if typeof(ensureInstanceInventory) == "function" then
		pcall(ensureInstanceInventory, profile)
	end

	local generateId = typeof(options.GenerateId) == "function" and options.GenerateId or fallbackGenerateId
	local cloneDictionary = typeof(options.CloneDictionary) == "function" and options.CloneDictionary or cloneValue

	profile.OwnedCockpits = typeof(profile.OwnedCockpits) == "table" and profile.OwnedCockpits or {}
	profile.OwnedModules = typeof(profile.OwnedModules) == "table" and profile.OwnedModules or {}
	profile.InstalledModules = typeof(profile.InstalledModules) == "table" and profile.InstalledModules or {}
	profile.ModuleColors = typeof(profile.ModuleColors) == "table" and profile.ModuleColors or {}
	profile.NeonOwned = typeof(profile.NeonOwned) == "table" and profile.NeonOwned or {}
	profile.ModuleUpgradeLevels = typeof(profile.ModuleUpgradeLevels) == "table" and profile.ModuleUpgradeLevels or {}
	profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
	profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
	profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}

	for _, cockpitInstance in pairs(profile.OwnedCockpitInstances) do
		if typeof(cockpitInstance) == "table" and cockpitInstance.TemplateId then
			profile.OwnedCockpits[tostring(cockpitInstance.TemplateId)] = true
		end
	end
	for _, moduleInstance in pairs(profile.OwnedModuleInstances) do
		if typeof(moduleInstance) == "table" and moduleInstance.TemplateId then
			profile.OwnedModules[tostring(moduleInstance.TemplateId)] = true
		end
	end

	local vehicleId = profile.CurrentVehicleId ~= nil and tostring(profile.CurrentVehicleId) or nil
	local vehicle = vehicleId and profile.Vehicles[vehicleId] or nil
	if typeof(vehicle) ~= "table" then
		for fallbackVehicleId, fallbackVehicle in pairs(profile.Vehicles) do
			if typeof(fallbackVehicle) == "table" then
				vehicleId = tostring(fallbackVehicleId)
				vehicle = fallbackVehicle
				profile.CurrentVehicleId = vehicleId
				break
			end
		end
	end
	if typeof(vehicle) ~= "table" then
		return { SyncCount = 0, VehicleId = nil }
	end

	vehicle.CategoryId = profile.CurrentCategory or vehicle.CategoryId or "bruiser"
	vehicle.CockpitColors = cloneDictionary(profile.CockpitColors or vehicle.CockpitColors or {})
	vehicle.ThrustColor = profile.ThrustColor or vehicle.ThrustColor
	vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}

	local syncCount = 0
	for slotId, moduleId in pairs(profile.InstalledModules) do
		local moduleIdText = tostring(moduleId)
		local instanceId = vehicle.InstalledModules[slotId]
		local moduleInstance = instanceId and profile.OwnedModuleInstances[instanceId] or nil
		if typeof(moduleInstance) ~= "table" or tostring(moduleInstance.TemplateId) ~= moduleIdText then
			instanceId = nil
			for candidateId, candidate in pairs(profile.OwnedModuleInstances) do
				if typeof(candidate) == "table" and tostring(candidate.TemplateId) == moduleIdText then
					local equippedVehicleId = candidate.EquippedVehicleId ~= nil and tostring(candidate.EquippedVehicleId) or ""
					if equippedVehicleId == "" or equippedVehicleId == vehicleId then
						instanceId = candidateId
						moduleInstance = candidate
						break
					end
				end
			end
		end
		if typeof(moduleInstance) ~= "table" then
			instanceId = generateId("module")
			moduleInstance = {
				TemplateId = moduleIdText,
				EquippedVehicleId = vehicleId,
				UpgradeLevels = {},
				Colors = {},
				NeonOwned = false,
				Source = "GarageProfileRuntimeLegacySync",
			}
			profile.OwnedModuleInstances[instanceId] = moduleInstance
		end
		vehicle.InstalledModules[slotId] = instanceId
		moduleInstance.TemplateId = moduleIdText
		moduleInstance.EquippedVehicleId = vehicleId
		moduleInstance.UpgradeLevels = cloneDictionary(profile.ModuleUpgradeLevels[moduleIdText] or moduleInstance.UpgradeLevels or {})
		moduleInstance.Colors = cloneDictionary(profile.ModuleColors[slotId] or moduleInstance.Colors or {})
		moduleInstance.NeonOwned = profile.NeonOwned[slotId] == true
		profile.OwnedModules[moduleIdText] = true
		syncCount += 1
	end

	return {
		SyncCount = syncCount,
		VehicleId = vehicleId,
		ModuleInstanceCount = countDictionary(profile.OwnedModuleInstances),
	}
end

return GarageProfileRuntime
]=]

local runtimeModule = garageFolder:FindFirstChild("GarageProfileRuntime")
if runtimeModule and not runtimeModule:IsA("ModuleScript") then
	error(runtimeModule:GetFullName() .. " exists but is not a ModuleScript.")
end
if not runtimeModule then
	runtimeModule = Instance.new("ModuleScript")
	runtimeModule.Name = "GarageProfileRuntime"
	runtimeModule.Parent = garageFolder
end
runtimeModule.Source = moduleSource
runtimeModule:SetAttribute("PersistencePhase20GarageProfileRuntime", true)

local source = serverScript.Source
assert(findPlain(source, "NTR_PERSISTENCE_PHASE19_INSTANCE_COMPAT_SYNC"), "Expected Phase 19 instance compatibility sync before Phase 20.")
assert(findPlain(source, "local function V88_syncInstanceDataFromLegacy(profile)"), "Expected Phase 19 sync helper before Phase 20.")

if not findPlain(source, "V89_GarageProfileRuntime") then
	source = replaceOnce(
		source,
		[=[	local V56_profiles = {}]=],
		[=[	local V56_profiles = {}
	local V89_GarageProfileRuntime = require(script.Parent:WaitForChild("GarageProfileRuntime"))]=],
		"Phase 20 GarageProfileRuntime require"
	)
end

local startIndex = findPlain(source, [=[	-- NTR_PERSISTENCE_PHASE19_INSTANCE_COMPAT_SYNC
	local function V88_syncInstanceDataFromLegacy(profile)]=])
assert(startIndex, "Could not find Phase 19 sync helper start. Refresh the Studio mirror before another Phase 20 patch.")
local endAnchor = [=[
	-- NTR_PERSISTENCE_PHASE17_STARTUP_DEPENDENCY_REPAIR_DEFAULT_MODULES]=]
local endIndex = findPlain(source, endAnchor, startIndex)
assert(endIndex, "Could not find Phase 19 sync helper end anchor. Refresh the Studio mirror before another Phase 20 patch.")

local delegateBlock = [=[	-- NTR_PERSISTENCE_PHASE19_INSTANCE_COMPAT_SYNC
	-- NTR_PERSISTENCE_PHASE20_GARAGE_PROFILE_RUNTIME_EXTRACT
	local function V88_syncInstanceDataFromLegacy(profile)
		local result = V89_GarageProfileRuntime.SyncInstanceDataFromLegacy(profile, {
			GenerateId = V84_generateId,
			CloneDictionary = V84_cloneDictionary,
			EnsureInstanceInventory = V84_ensureInstanceInventory,
		})
		local syncCount = typeof(result) == "table" and tonumber(result.SyncCount) or 0
		local vehicleId = typeof(result) == "table" and result.VehicleId or nil
		local player = profile and profile._Player
		if player then
			player:SetAttribute("NTR_PersistencePhase19Synced", true)
			player:SetAttribute("NTR_PersistencePhase19VehicleId", tostring(vehicleId or ""))
			player:SetAttribute("NTR_PersistencePhase19ModuleSyncCount", syncCount or 0)
			player:SetAttribute("NTR_PersistencePhase20RuntimeModule", "GarageProfileRuntime")
			player:SetAttribute("NTR_PersistencePhase20VehicleId", tostring(vehicleId or ""))
			player:SetAttribute("NTR_PersistencePhase20ModuleSyncCount", syncCount or 0)
		end
		return syncCount or 0
	end

]=]

if not findPlain(source, "NTR_PERSISTENCE_PHASE20_GARAGE_PROFILE_RUNTIME_EXTRACT") then
	source = string.sub(source, 1, startIndex - 1) .. delegateBlock .. string.sub(source, endIndex)
	serverScript.Source = source
else
	info("Phase 20 controller delegation already installed; refreshing install attributes only.")
end

serverScript:SetAttribute("PersistencePhase20GarageProfileRuntimeExtract", true)
bootstrap:SetAttribute("PersistencePhase20GarageProfileRuntimeExtract", true)

local finalSource = serverScript.Source
assert(findPlain(finalSource, "V89_GarageProfileRuntime"), "Phase 20 runtime require was not installed.")
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE20_GARAGE_PROFILE_RUNTIME_EXTRACT"), "Phase 20 delegation marker was not installed.")
assert(findPlain(finalSource, "NTR_PersistencePhase20RuntimeModule"), "Phase 20 smoke attributes were not installed.")

info("PASS: installed GarageProfileRuntime and delegated instance sync to it.")
info("Next: restart Play and run this same script from the CLIENT Command Bar. Expected RuntimeModule=GarageProfileRuntime and missingInstances=0.")
