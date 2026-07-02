-- GarageProfileRuntime
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
