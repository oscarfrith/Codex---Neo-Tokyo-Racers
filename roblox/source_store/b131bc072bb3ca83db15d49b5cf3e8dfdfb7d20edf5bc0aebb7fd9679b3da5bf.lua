-- Canonical feature implementation; startup is owned by the composition root.
-- GarageServer garage profile defaults, normalisation and hydration. Extracted verbatim from the GarageServer controller closure
-- (architecture P5); dependencies arrive through ctx and the same locals are returned in order.
return function(ctx)
	local Players = ctx.Players
	local ProfileServer = ctx.ProfileServer
	local STARTING_CASH = ctx.STARTING_CASH
	local function defaultProfile()
		return {
			Cash = STARTING_CASH,
			CurrentCategory = "bruiser",
			CurrentCockpit = "bruiser_01",
			OwnedCockpits = {}, 
			CockpitColors = {
				Primary = Color3.fromRGB(0, 205, 230),
				Secondary = Color3.fromRGB(235, 247, 204),
				Detail = Color3.fromRGB(38, 44, 50),
				Neon = Color3.fromRGB(255, 255, 255),
				FrontLights = Color3.fromRGB(252, 250, 255),
				RearLights = Color3.fromRGB(255, 116, 116),
			},
			ThrustColor = Color3.fromRGB(255, 255, 255),
			OwnedModules = {},
			InstalledModules = {},
			ModuleColors = {},
			NeonOwned = {},
			UpgradeLevels = { Brakes = 0, Converter = 0, FuelSystem = 0 },
			GarageCapacity = 2,
			OwnedGarageProperties = {},
			CurrentVehicleId = nil,
			Vehicles = {},
			OwnedCockpitInstances = {},
			OwnedModuleInstances = {},
			ModuleUpgradeLevels = {},
		}
	end

	local function normalizeProfile(profile)
		profile.Cash = typeof(profile.Cash) == "number" and profile.Cash or STARTING_CASH
		profile.CurrentCategory = profile.CurrentCategory or "bruiser"
		profile.CurrentCockpit = profile.CurrentCockpit or "bruiser_01"
		profile.OwnedCockpits = profile.OwnedCockpits or {} 
		profile.OwnedModules = profile.OwnedModules or {}
		profile.InstalledModules = profile.InstalledModules or {}
		profile.ModuleColors = profile.ModuleColors or {}
		profile.NeonOwned = profile.NeonOwned or {}
		profile.UpgradeLevels = profile.UpgradeLevels or { Brakes = 0, Converter = 0, FuelSystem = 0 }
		profile.GarageCapacity = math.max(1, math.floor(tonumber(profile.GarageCapacity) or 2))
		profile.OwnedGarageProperties = typeof(profile.OwnedGarageProperties) == "table" and profile.OwnedGarageProperties or {}
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
		profile.CurrentVehicleId = profile.CurrentVehicleId ~= nil and tostring(profile.CurrentVehicleId) or nil
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
		profile.CockpitColors = profile.CockpitColors or {}
		profile.CockpitColors.Primary = profile.CockpitColors.Primary or Color3.fromRGB(0, 205, 230)
		profile.CockpitColors.Secondary = profile.CockpitColors.Secondary or Color3.fromRGB(235, 247, 204)
		profile.CockpitColors.Detail = profile.CockpitColors.Detail or Color3.fromRGB(38, 44, 50)
		profile.CockpitColors.Neon = profile.CockpitColors.Neon or Color3.fromRGB(255, 255, 255)
		profile.CockpitColors.FrontLights = profile.CockpitColors.FrontLights or Color3.fromRGB(252, 250, 255)
		profile.CockpitColors.RearLights = profile.CockpitColors.RearLights or Color3.fromRGB(255, 116, 116)
		profile.ThrustColor = profile.ThrustColor or Color3.fromRGB(255, 255, 255)
		return profile
	end
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

	local function countSavedEntries(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function getProfileServiceProfile(player)
		local deadline=os.clock()+30
		repeat
			local profile=ProfileServer.get_profile(player)
			if profile then return profile end
			task.wait(0.1)
		until player.Parent~=Players or os.clock()>=deadline
		return nil,"Profile is not ready."
	end

	local function profileHasSavedInstanceData(savedProfile)
		if typeof(savedProfile) ~= "table" then
			return false
		end
		if countSavedEntries(savedProfile.Vehicles) > 0 then
			return true
		end
		if countSavedEntries(savedProfile.OwnedCockpitInstances) > 0 then
			return true
		end
		if countSavedEntries(savedProfile.OwnedModuleInstances) > 0 then
			return true
		end
		local garage = savedProfile.Garage
		if typeof(garage) == "table" and countSavedEntries(garage.OwnedGarageProperties) > 0 then
			return true
		end
		return false
	end

	local function currentVehicleFromSavedProfile(savedProfile)
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

	local function savedProfileToLegacySession(savedProfile)
		local legacy = defaultProfile()
		legacy.Cash = typeof(savedProfile.Cash) == "number" and savedProfile.Cash or legacy.Cash
		local garage = typeof(savedProfile.Garage) == "table" and savedProfile.Garage or {}
		legacy.GarageCapacity = math.max(1, math.floor(tonumber(garage.Capacity) or legacy.GarageCapacity or 2))
		legacy.OwnedGarageProperties = cloneValue(garage.OwnedGarageProperties or {})
		legacy.GarageDisplaySpaces = cloneValue(garage.DisplaySpaces or {})
		legacy.Vehicles = cloneValue(savedProfile.Vehicles or {})
		legacy.OwnedCockpitInstances = cloneValue(savedProfile.OwnedCockpitInstances or {})
		legacy.OwnedModuleInstances = cloneValue(savedProfile.OwnedModuleInstances or {})
		legacy.CurrentVehicleId = savedProfile.CurrentVehicleId ~= nil and tostring(savedProfile.CurrentVehicleId) or nil
		legacy.ModuleUpgradeLevels = {}

		local currentVehicleId, currentVehicle = currentVehicleFromSavedProfile(savedProfile)
		if currentVehicleId then
			legacy.CurrentVehicleId = currentVehicleId
		end
		if typeof(currentVehicle) == "table" then
			legacy.CurrentCategory = tostring(currentVehicle.CategoryId or legacy.CurrentCategory or "bruiser")
			legacy.CockpitColors = cloneValue(currentVehicle.CockpitColors or legacy.CockpitColors)
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
					legacy.ModuleUpgradeLevels[moduleId] = cloneValue(moduleInstance.UpgradeLevels)
				end
				for slotId, installedInstanceId in pairs(installedInstances) do
					if tostring(installedInstanceId) == tostring(instanceId) then
						legacy.InstalledModules[slotId] = moduleId
						legacy.ModuleColors[slotId] = cloneValue(moduleInstance.Colors or {})
						legacy.NeonOwned[slotId] = moduleInstance.NeonOwned == true
					end
				end
			end
		end

		return normalizeProfile(legacy)
	end

	-- Garage hydration is owned by ProfileServer.get_garage_profile.

	local function getProfile(player)
		local profile=ProfileServer.get_garage_profile(player, function(saved)
			return profileHasSavedInstanceData(saved) and savedProfileToLegacySession(saved) or defaultProfile()
		end)
		if not profile then error("Profile is not ready.") end
		return normalizeProfile(profile)
	end
	-- The legacy garage session remains a compatibility owner. This tiny bridge
	-- lets the reviewed one-time cleanup update it in the same transaction as
	-- ProfileService, so its normal mirror cannot restore stale inventory.
	return normalizeProfile, getProfileServiceProfile, getProfile
end
