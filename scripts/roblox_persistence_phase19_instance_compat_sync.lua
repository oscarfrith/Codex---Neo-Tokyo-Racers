-- Persistence Phase 19 instance compatibility sync.
--
-- One-file workflow:
-- 1. Run from Roblox Studio Command Bar in Edit mode to install.
-- 2. Restart Play, then run this same file from the CLIENT Command Bar to smoke-check.
--
-- This phase keeps the Phase 18 ProfileService source handoff, then ensures
-- legacy UI/customisation writes are copied back into the active vehicle and
-- module instance fields before the profile is mirrored/saved.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local PHASE = "Persistence Phase 19 Instance Compatibility Sync"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 19 patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another Phase 19 patch.")
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
	info("Player attrs: Phase19Synced=" .. tostring(player:GetAttribute("NTR_PersistencePhase19Synced")) .. " syncCount=" .. tostring(player:GetAttribute("NTR_PersistencePhase19ModuleSyncCount")) .. " vehicle=" .. tostring(player:GetAttribute("NTR_PersistencePhase19VehicleId")))
	info("Manual check: change a module/cockpit colour or thrust colour, save/restart, and confirm it returns. This phase makes those legacy UI writes sync into instance data before mirroring.")
	return
end

if RunService:IsRunning() then
	runClientSmoke()
	return
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local serverScript = game:GetService("ServerScriptService")
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assert(serverScript:IsA("Script"), "Expected GarageActionController_Shadow_Disabled to be a Script.")

local source = serverScript.Source
assert(findPlain(source, "NTR_PERSISTENCE_PHASE18_PROFILE_SOURCE_HANDOFF"), "Expected Phase 18 ProfileService source handoff before Phase 19.")
assert(findPlain(source, "V84_ensureInstanceInventory"), "Expected Phase 14/17 instance inventory helper before Phase 19.")
assert(findPlain(source, "V80_mirrorLegacyProfileToPersistence"), "Expected Phase 4/5 persistence mirror before Phase 19.")

local marker = "-- NTR_PERSISTENCE_PHASE19_INSTANCE_COMPAT_SYNC"

local syncBlock = [=[
	-- NTR_PERSISTENCE_PHASE19_INSTANCE_COMPAT_SYNC
	local function V88_syncInstanceDataFromLegacy(profile)
		if typeof(profile) ~= "table" then
			return 0
		end
		V84_ensureInstanceInventory(profile)
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
			return 0
		end

		vehicle.CategoryId = profile.CurrentCategory or vehicle.CategoryId or "bruiser"
		vehicle.CockpitColors = V84_cloneDictionary(profile.CockpitColors or vehicle.CockpitColors or {})
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
				instanceId = V84_generateId("module")
				moduleInstance = {
					TemplateId = moduleIdText,
					EquippedVehicleId = vehicleId,
					UpgradeLevels = {},
					Colors = {},
					NeonOwned = false,
					Source = "PersistencePhase19LegacySync",
				}
				profile.OwnedModuleInstances[instanceId] = moduleInstance
			end
			vehicle.InstalledModules[slotId] = instanceId
			moduleInstance.TemplateId = moduleIdText
			moduleInstance.EquippedVehicleId = vehicleId
			moduleInstance.UpgradeLevels = V84_cloneDictionary(profile.ModuleUpgradeLevels[moduleIdText] or moduleInstance.UpgradeLevels or {})
			moduleInstance.Colors = V84_cloneDictionary(profile.ModuleColors[slotId] or moduleInstance.Colors or {})
			moduleInstance.NeonOwned = profile.NeonOwned[slotId] == true
			profile.OwnedModules[moduleIdText] = true
			syncCount += 1
		end

		local player = profile._Player
		if player then
			player:SetAttribute("NTR_PersistencePhase19Synced", true)
			player:SetAttribute("NTR_PersistencePhase19VehicleId", tostring(vehicleId or ""))
			player:SetAttribute("NTR_PersistencePhase19ModuleSyncCount", syncCount)
		end
		return syncCount
	end

]=]

if findPlain(source, marker) then
	info("Phase 19 sync is already installed; refreshing install attributes only.")
else
	local helperAnchor = [=[	-- NTR_PERSISTENCE_PHASE17_STARTUP_DEPENDENCY_REPAIR_DEFAULT_MODULES]=]
	source = replaceOnce(source, helperAnchor, syncBlock .. helperAnchor, "Phase 19 sync helper")

	local oldInitialMirror = [=[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				V80_mirrorLegacyProfileToPersistence(player, profile, action, false)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }]=]

	local newInitialMirror = [=[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				V88_syncInstanceDataFromLegacy(profile)
				V80_mirrorLegacyProfileToPersistence(player, profile, action, false)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }]=]

	source = replaceOnce(source, oldInitialMirror, newInitialMirror, "Phase 19 GetInitial sync before mirror")

	local oldMutationMirror = [=[			if ok == true then
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)
			end
			return { Success = ok == true, Message = message, Profile = V56_profileForClient(profile) }]=]

	local newMutationMirror = [=[			if ok == true then
				V88_syncInstanceDataFromLegacy(profile)
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)
			end
			return { Success = ok == true, Message = message, Profile = V56_profileForClient(profile) }]=]

	source = replaceOnce(source, oldMutationMirror, newMutationMirror, "Phase 19 mutating sync before mirror")
	serverScript.Source = source
end

serverScript:SetAttribute("PersistencePhase19InstanceCompatSync", true)
bootstrap:SetAttribute("PersistencePhase19InstanceCompatSync", true)

local finalSource = serverScript.Source
assert(findPlain(finalSource, marker), "Phase 19 sync marker was not installed.")
assert(findPlain(finalSource, "V88_syncInstanceDataFromLegacy(profile)"), "Phase 19 sync call was not installed.")
assert(findPlain(finalSource, "NTR_PersistencePhase19ModuleSyncCount"), "Phase 19 sync attributes were not installed.")

info("PASS: installed Phase 19 instance compatibility sync.")
info("Next: restart Play and run this same script from the CLIENT Command Bar. Then test a colour/thrust/module edit, save/restart, and confirm the edit persists.")
