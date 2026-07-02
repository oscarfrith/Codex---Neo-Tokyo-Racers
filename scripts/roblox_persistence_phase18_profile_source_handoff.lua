-- Persistence Phase 18 profile source handoff.
--
-- One-file workflow:
-- 1. Run from Roblox Studio Command Bar in Edit mode to install.
-- 2. Restart Play, then run this same file from the CLIENT Command Bar to smoke-check.
--
-- This makes the active garage session hydrate from ProfileService's saved
-- instance profile on first use, while preserving the existing garage action
-- controller behavior and legacy response fields.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local PHASE = "Persistence Phase 18 Profile Source Handoff"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 18 patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another Phase 18 patch.")
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

	local vehicleCount = 0
	for _ in pairs(profile.Vehicles or {}) do
		vehicleCount += 1
	end
	local moduleInstanceCount = 0
	for _ in pairs(profile.OwnedModuleInstances or {}) do
		moduleInstanceCount += 1
	end
	local propertyCount = 0
	for _ in pairs((profile.Garage and profile.Garage.OwnedGarageProperties) or profile.OwnedGarageProperties or {}) do
		propertyCount += 1
	end

	info("Smoke GetInitial OK.")
	info("Profile CurrentVehicleId=" .. tostring(profile.CurrentVehicleId) .. " vehicles=" .. tostring(vehicleCount) .. " moduleInstances=" .. tostring(moduleInstanceCount) .. " garageProperties=" .. tostring(propertyCount))
	info("Player attrs: Hydrated=" .. tostring(player:GetAttribute("NTR_PersistencePhase18Hydrated")) .. " source=" .. tostring(player:GetAttribute("NTR_PersistencePhase18HydrationSource")) .. " savedVehicles=" .. tostring(player:GetAttribute("NTR_PersistencePhase18SavedVehicleCount")))
	info("If this is a fresh Play after a DataStore save, Hydrated should be true and savedVehicles should be greater than 0. In a brand-new/no-save test, Hydrated can be false because there is no saved instance profile yet.")
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
assert(findPlain(source, "NTR_PERSISTENCE_PHASE17_STARTUP_DEPENDENCY_REPAIR_DEFAULT_MODULES"), "Expected Phase 17 startup dependency baseline before Phase 18.")
assert(findPlain(source, "ImportProfileSnapshot"), "Expected Phase 5 ImportProfileSnapshot mirror before Phase 18.")

local marker = "-- NTR_PERSISTENCE_PHASE18_PROFILE_SOURCE_HANDOFF"

local oldGetProfile = [=[	local function V56_getProfile(player)
		local profile = V56_profiles[player.UserId]
		if not profile then
			profile = V56_defaultProfile()
			V56_profiles[player.UserId] = profile
		end
		return V56_normalizeProfile(profile)
	end]=]

local handoffBlock = [=[	-- NTR_PERSISTENCE_PHASE18_PROFILE_SOURCE_HANDOFF
	local function V87_cloneValue(value)
		if typeof(value) == "table" then
			local copy = {}
			for key, child in pairs(value) do
				copy[key] = V87_cloneValue(child)
			end
			return copy
		end
		return value
	end

	local function V87_countDictionary(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function V87_getProfileServiceProfile(player)
		local getProfile = nil
		local deadline = os.clock() + 5
		while os.clock() < deadline do
			local servicesRoot = script.Parent and script.Parent.Parent
			local playerServices = servicesRoot and servicesRoot:FindFirstChild("Player")
			local profileBindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
			getProfile = profileBindings and profileBindings:FindFirstChild("GetProfile")
			if getProfile and getProfile:IsA("BindableFunction") then
				local ok, profileOrError = pcall(function()
					return getProfile:Invoke(player)
				end)
				if ok and typeof(profileOrError) == "table" then
					return profileOrError, nil
				end
				if not ok then
					return nil, tostring(profileOrError)
				end
			end
			task.wait(0.1)
		end
		return nil, "ProfileService profile not loaded"
	end

	local function V87_profileHasSavedInstanceData(savedProfile)
		if typeof(savedProfile) ~= "table" then
			return false
		end
		if V87_countDictionary(savedProfile.Vehicles) > 0 then
			return true
		end
		if V87_countDictionary(savedProfile.OwnedCockpitInstances) > 0 then
			return true
		end
		if V87_countDictionary(savedProfile.OwnedModuleInstances) > 0 then
			return true
		end
		local garage = savedProfile.Garage
		if typeof(garage) == "table" and V87_countDictionary(garage.OwnedGarageProperties) > 0 then
			return true
		end
		return false
	end

	local function V87_currentVehicleFromSavedProfile(savedProfile)
		local vehicles = typeof(savedProfile.Vehicles) == "table" and savedProfile.Vehicles or {}
		local vehicleId = savedProfile.CurrentVehicleId ~= nil and tostring(savedProfile.CurrentVehicleId) or nil
		local vehicle = vehicleId and vehicles[vehicleId] or nil
		if typeof(vehicle) == "table" then
			return vehicleId, vehicle
		end
		for fallbackVehicleId, fallbackVehicle in pairs(vehicles) do
			if typeof(fallbackVehicle) == "table" then
				return tostring(fallbackVehicleId), fallbackVehicle
			end
		end
		return nil, nil
	end

	local function V87_savedProfileToLegacySession(savedProfile)
		local legacy = V56_defaultProfile()
		legacy.Cash = typeof(savedProfile.Cash) == "number" and savedProfile.Cash or legacy.Cash
		local garage = typeof(savedProfile.Garage) == "table" and savedProfile.Garage or {}
		legacy.GarageCapacity = math.max(1, math.floor(tonumber(garage.Capacity) or legacy.GarageCapacity or 2))
		legacy.OwnedGarageProperties = V87_cloneValue(garage.OwnedGarageProperties or {})
		legacy.GarageDisplaySpaces = V87_cloneValue(garage.DisplaySpaces or {})
		legacy.Vehicles = V87_cloneValue(savedProfile.Vehicles or {})
		legacy.OwnedCockpitInstances = V87_cloneValue(savedProfile.OwnedCockpitInstances or {})
		legacy.OwnedModuleInstances = V87_cloneValue(savedProfile.OwnedModuleInstances or {})
		legacy.CurrentVehicleId = savedProfile.CurrentVehicleId ~= nil and tostring(savedProfile.CurrentVehicleId) or nil
		legacy.ModuleUpgradeLevels = {}

		local currentVehicleId, currentVehicle = V87_currentVehicleFromSavedProfile(savedProfile)
		if currentVehicleId then
			legacy.CurrentVehicleId = currentVehicleId
		end
		if typeof(currentVehicle) == "table" then
			legacy.CurrentCategory = tostring(currentVehicle.CategoryId or legacy.CurrentCategory or "bruiser")
			legacy.CockpitColors = V87_cloneValue(currentVehicle.CockpitColors or legacy.CockpitColors)
			legacy.ThrustColor = currentVehicle.ThrustColor or legacy.ThrustColor
			local cockpitInstance = currentVehicle.CockpitInstanceId and legacy.OwnedCockpitInstances[currentVehicle.CockpitInstanceId] or nil
			if typeof(cockpitInstance) == "table" and cockpitInstance.TemplateId then
				legacy.CurrentCockpit = tostring(cockpitInstance.TemplateId)
			end
		end

		legacy.OwnedCockpits = {}
		for _, cockpitInstance in pairs(legacy.OwnedCockpitInstances) do
			if typeof(cockpitInstance) == "table" and cockpitInstance.TemplateId then
				legacy.OwnedCockpits[tostring(cockpitInstance.TemplateId)] = true
			end
		end
		legacy.OwnedCockpits[legacy.CurrentCockpit or "bruiser_01"] = true

		legacy.OwnedModules = {}
		legacy.InstalledModules = {}
		legacy.ModuleColors = {}
		legacy.NeonOwned = {}
		local installedInstances = typeof(currentVehicle) == "table" and typeof(currentVehicle.InstalledModules) == "table" and currentVehicle.InstalledModules or {}
		for instanceId, moduleInstance in pairs(legacy.OwnedModuleInstances) do
			if typeof(moduleInstance) == "table" and moduleInstance.TemplateId then
				local moduleId = tostring(moduleInstance.TemplateId)
				legacy.OwnedModules[moduleId] = true
				if typeof(moduleInstance.UpgradeLevels) == "table" then
					legacy.ModuleUpgradeLevels[moduleId] = V87_cloneValue(moduleInstance.UpgradeLevels)
				end
				for slotId, installedInstanceId in pairs(installedInstances) do
					if tostring(installedInstanceId) == tostring(instanceId) then
						legacy.InstalledModules[slotId] = moduleId
						legacy.ModuleColors[slotId] = V87_cloneValue(moduleInstance.Colors or {})
						legacy.NeonOwned[slotId] = moduleInstance.NeonOwned == true
					end
				end
			end
		end

		return V56_normalizeProfile(legacy)
	end

	local function V87_tryHydrateProfileFromPersistence(player)
		local savedProfile, loadMessage = V87_getProfileServiceProfile(player)
		if not V87_profileHasSavedInstanceData(savedProfile) then
			player:SetAttribute("NTR_PersistencePhase18Hydrated", false)
			player:SetAttribute("NTR_PersistencePhase18HydrationSource", tostring(loadMessage or "NoSavedInstanceData"))
			player:SetAttribute("NTR_PersistencePhase18SavedVehicleCount", 0)
			return nil
		end
		local legacy = V87_savedProfileToLegacySession(savedProfile)
		player:SetAttribute("NTR_PersistencePhase18Hydrated", true)
		player:SetAttribute("NTR_PersistencePhase18HydrationSource", "ProfileService")
		player:SetAttribute("NTR_PersistencePhase18SavedVehicleCount", V87_countDictionary(savedProfile.Vehicles))
		player:SetAttribute("NTR_PersistencePhase18SavedModuleInstanceCount", V87_countDictionary(savedProfile.OwnedModuleInstances))
		return legacy
	end

	local function V56_getProfile(player)
		local profile = V56_profiles[player.UserId]
		if not profile then
			profile = V87_tryHydrateProfileFromPersistence(player) or V56_defaultProfile()
			V56_profiles[player.UserId] = profile
		end
		return V56_normalizeProfile(profile)
	end]=]

if findPlain(source, marker) then
	info("Phase 18 handoff is already installed; refreshing install attributes only.")
else
	source = replaceOnce(source, oldGetProfile, handoffBlock, "Phase 18 ProfileService source handoff")
	serverScript.Source = source
end

serverScript:SetAttribute("PersistencePhase18ProfileSourceHandoff", true)
bootstrap:SetAttribute("PersistencePhase18ProfileSourceHandoff", true)

local finalSource = serverScript.Source
assert(findPlain(finalSource, marker), "Phase 18 source handoff marker was not installed.")
assert(findPlain(finalSource, "V87_tryHydrateProfileFromPersistence"), "Phase 18 hydration helper was not installed.")
assert(findPlain(finalSource, "NTR_PersistencePhase18Hydrated"), "Phase 18 hydration attributes were not installed.")

info("PASS: installed Phase 18 ProfileService source handoff.")
info("Next: restart Play and run this same script from the CLIENT Command Bar. For a true persistence test, enable DataStore saves, create/buy something, save/restart, then run the smoke.")
