-- Neo Tokyo Racers legacy garage profile mapper.
-- Persistence Phase 14. Converts current V56 session-memory profiles into
-- instance-based PlayerProfileSchema profiles, preserving live instance fields
-- when they already exist.

local LegacyGarageProfileMapper = {}

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

local function slug(value)
	value = string.lower(tostring(value or "item"))
	value = string.gsub(value, "%s+", "_")
	value = string.gsub(value, "[^%w_]", "")
	return value ~= "" and value or "item"
end

local function sortedKeys(dictionary)
	local keys = {}
	for key in pairs(dictionary or {}) do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	return keys
end

local function moveKeyToFront(keys, preferred)
	preferred = tostring(preferred or "")
	for index, key in ipairs(keys) do
		if key == preferred then
			table.remove(keys, index)
			table.insert(keys, 1, key)
			break
		end
	end
	return keys
end

local function countDictionary(dictionary)
	local count = 0
	for _ in pairs(dictionary or {}) do
		count += 1
	end
	return count
end

local function instanceId(prefix, templateId, index)
	return tostring(prefix) .. "_" .. slug(templateId) .. "_" .. string.format("%03d", index)
end

local function moduleInstanceId(slotId, moduleId, index)
	if slotId and slotId ~= "" then
		return "module_" .. slug(slotId) .. "_" .. slug(moduleId)
	end
	return instanceId("module", moduleId, index)
end

local function copyColors(colors)
	return typeof(colors) == "table" and cloneValue(colors) or {}
end

local function cockpitColorsFromLegacy(legacy)
	return copyColors(legacy and legacy.CockpitColors)
end

local function moduleUpgradeLevelsFor(legacy, moduleId)
	local allLevels = legacy and legacy.ModuleUpgradeLevels
	if typeof(allLevels) ~= "table" then
		return {}
	end
	local byModule = allLevels[moduleId]
	return typeof(byModule) == "table" and cloneValue(byModule) or {}
end

local function ensureDisplaySpaces(profile)
	profile.Garage.DisplaySpaces = typeof(profile.Garage.DisplaySpaces) == "table" and profile.Garage.DisplaySpaces or {}
	local index = 0
	for vehicleId in pairs(profile.Vehicles or {}) do
		index += 1
		local key = "Space" .. tostring(index)
		profile.Garage.DisplaySpaces[key] = typeof(profile.Garage.DisplaySpaces[key]) == "table" and profile.Garage.DisplaySpaces[key] or {}
		profile.Garage.DisplaySpaces[key].VehicleId = profile.Garage.DisplaySpaces[key].VehicleId or vehicleId
	end
end

local function copyLiveInstanceInventory(legacyProfile, profile)
	if typeof(legacyProfile.Vehicles) ~= "table"
		or typeof(legacyProfile.OwnedCockpitInstances) ~= "table"
		or typeof(legacyProfile.OwnedModuleInstances) ~= "table" then
		return false
	end

	-- NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY
	profile.Vehicles = cloneValue(legacyProfile.Vehicles)
	profile.OwnedCockpitInstances = cloneValue(legacyProfile.OwnedCockpitInstances)
	profile.OwnedModuleInstances = cloneValue(legacyProfile.OwnedModuleInstances)
	profile.CurrentVehicleId = legacyProfile.CurrentVehicleId ~= nil and tostring(legacyProfile.CurrentVehicleId) or profile.CurrentVehicleId
	if typeof(legacyProfile.Garage) == "table" then
		profile.Garage.DisplaySpaces = cloneValue(legacyProfile.Garage.DisplaySpaces or profile.Garage.DisplaySpaces)
	end
	if not profile.CurrentVehicleId then
		for vehicleId in pairs(profile.Vehicles) do
			profile.CurrentVehicleId = vehicleId
			break
		end
	end
	ensureDisplaySpaces(profile)
	return true
end

function LegacyGarageProfileMapper.Convert(legacyProfile, schema, options)
	assert(typeof(schema) == "table" and typeof(schema.DefaultProfile) == "function", "PlayerProfileSchema module is required")
	options = typeof(options) == "table" and options or {}
	legacyProfile = typeof(legacyProfile) == "table" and legacyProfile or {}

	local profile = schema.DefaultProfile(legacyProfile.Cash)
	profile.Cash = typeof(legacyProfile.Cash) == "number" and legacyProfile.Cash or profile.Cash
	profile.LegacyMigration = {
		Source = "PersistencePhase14_LegacyGarageProfileMapper",
		MigratedAtUnix = os.time(),
		LegacyCurrentCategory = legacyProfile.CurrentCategory,
		LegacyCurrentCockpit = legacyProfile.CurrentCockpit,
		Notes = {},
	}
	profile.Garage.OwnedGarageProperties = cloneValue(legacyProfile.OwnedGarageProperties or legacyProfile.GarageProperties or {})

	local copiedLiveInstances = copyLiveInstanceInventory(legacyProfile, profile)

	local ownedCockpits = typeof(legacyProfile.OwnedCockpits) == "table" and legacyProfile.OwnedCockpits or {}
	if next(ownedCockpits) == nil then
		ownedCockpits[legacyProfile.CurrentCockpit or "bruiser_01"] = true
	end

	local cockpitIds = sortedKeys(ownedCockpits)
	moveKeyToFront(cockpitIds, legacyProfile.CurrentCockpit or "bruiser_01")

	local preserveLegacyCapacity = options.PreserveLegacyCapacity ~= false
	if preserveLegacyCapacity then
		local legacyCapacity = tonumber(legacyProfile.GarageCapacity)
		profile.Garage.Capacity = math.max(profile.Garage.Capacity or 2, #cockpitIds, legacyCapacity or 0, countDictionary(profile.Vehicles))
	else
		profile.Garage.Capacity = tonumber(options.Capacity) or profile.Garage.Capacity or 2
	end

	if not copiedLiveInstances then
		local vehicleIndex = 0
		for _, cockpitId in ipairs(cockpitIds) do
			if ownedCockpits[cockpitId] == true then
				vehicleIndex += 1
				local cockpitInstanceId = instanceId("cockpit", cockpitId, vehicleIndex)
				local vehicleId = instanceId("vehicle", cockpitId, vehicleIndex)
				profile.OwnedCockpitInstances[cockpitInstanceId] = {
					TemplateId = cockpitId,
					VehicleId = vehicleId,
					AcquiredAtUnix = 0,
					Source = "LegacyOwnedCockpits",
				}
				profile.Vehicles[vehicleId] = {
					DisplayName = tostring(cockpitId),
					CategoryId = legacyProfile.CurrentCategory or "bruiser",
					CockpitInstanceId = cockpitInstanceId,
					InstalledModules = {},
					CockpitColors = cockpitColorsFromLegacy(legacyProfile),
					ThrustColor = legacyProfile.ThrustColor,
					Source = "LegacyOwnedCockpits",
				}
				if cockpitId == (legacyProfile.CurrentCockpit or "bruiser_01") then
					profile.CurrentVehicleId = vehicleId
				end
			end
		end

		if not profile.CurrentVehicleId then
			for vehicleId in pairs(profile.Vehicles) do
				profile.CurrentVehicleId = vehicleId
				break
			end
		end

		local currentVehicle = profile.CurrentVehicleId and profile.Vehicles[profile.CurrentVehicleId] or nil
		local installedModules = typeof(legacyProfile.InstalledModules) == "table" and legacyProfile.InstalledModules or {}
		local moduleIndex = 0
		local createdByTemplate = {}
		for _, slotId in ipairs(sortedKeys(installedModules)) do
			local moduleId = installedModules[slotId]
			if typeof(moduleId) == "string" and moduleId ~= "" then
				moduleIndex += 1
				local id = moduleInstanceId(slotId, moduleId, moduleIndex)
				profile.OwnedModuleInstances[id] = {
					TemplateId = moduleId,
					EquippedVehicleId = profile.CurrentVehicleId,
					UpgradeLevels = moduleUpgradeLevelsFor(legacyProfile, moduleId),
					Colors = copyColors(legacyProfile.ModuleColors and legacyProfile.ModuleColors[slotId]),
					NeonOwned = legacyProfile.NeonOwned and legacyProfile.NeonOwned[slotId] == true or false,
					Source = "LegacyInstalledModules",
				}
				if currentVehicle then
					currentVehicle.InstalledModules[slotId] = id
				end
				createdByTemplate[moduleId] = createdByTemplate[moduleId] or id
			end
		end

		local ownedModules = typeof(legacyProfile.OwnedModules) == "table" and legacyProfile.OwnedModules or {}
		for _, moduleId in ipairs(sortedKeys(ownedModules)) do
			if ownedModules[moduleId] == true and not createdByTemplate[moduleId] then
				moduleIndex += 1
				local id = moduleInstanceId(nil, moduleId, moduleIndex)
				profile.OwnedModuleInstances[id] = {
					TemplateId = moduleId,
					EquippedVehicleId = nil,
					UpgradeLevels = moduleUpgradeLevelsFor(legacyProfile, moduleId),
					Colors = {},
					NeonOwned = false,
					Source = "LegacyOwnedModules",
				}
				createdByTemplate[moduleId] = id
			end
		end
		ensureDisplaySpaces(profile)
	else
		table.insert(profile.LegacyMigration.Notes, "Live instance inventory copied directly from the Phase 14 garage profile fields.")
	end

	profile.LegacyMigration.LegacyVehicleCount = countDictionary(profile.Vehicles)
	profile.LegacyMigration.LegacyModuleInstanceCount = countDictionary(profile.OwnedModuleInstances)
	table.insert(profile.LegacyMigration.Notes, "Boolean legacy ownership remains for current UI compatibility; instance fields are the future duplicate-copy source.")

	return schema.Normalize(profile)
end

function LegacyGarageProfileMapper.SummarizeConversion(legacyProfile, schema, options)
	local profile = LegacyGarageProfileMapper.Convert(legacyProfile, schema, options)
	local summary = schema.Summarize(profile)
	summary.CurrentVehicleId = profile.CurrentVehicleId
	return summary
end

return LegacyGarageProfileMapper
