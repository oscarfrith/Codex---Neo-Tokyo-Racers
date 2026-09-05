-- NTR_VEHICLE_PERFORMANCE_V2_CANONICAL_RUNTIME_V1
-- Physical module instances and V2 upgrade allocations are the only live upgrade state.
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceV2Definitions"))
local V2 = require(script.Parent:WaitForChild("VehiclePerformanceV2UpgradeRuntime"))
local V2Runtime = require(script.Parent:WaitForChild("VehiclePerformanceV2Runtime"))
local Runtime = {}
local profiles = {}

local function currentVehicle(profile)
	local id = profile and profile.CurrentVehicleId
	return id and profile.Vehicles and profile.Vehicles[tostring(id)], id and tostring(id)
end

local function currentInstance(profile, slotId, moduleId)
	local vehicle, vehicleId = currentVehicle(profile)
	local instanceId = vehicle and vehicle.InstalledModules and vehicle.InstalledModules[slotId]
	local instance = instanceId and profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]
	if typeof(instance) == "table" and tostring(instance.TemplateId or "") == tostring(moduleId or "") then return tostring(instanceId), instance end
	for id, candidate in pairs(profile.OwnedModuleInstances or {}) do
		if typeof(candidate) == "table" and tostring(candidate.TemplateId or "") == tostring(moduleId or "") and tostring(candidate.EquippedVehicleId or "") == tostring(vehicleId or "") then return tostring(id), candidate end
	end
	return nil, nil
end

local function applyMigration(profile, findModule)
	if typeof(profile) ~= "table" then return end
	profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	local migration = typeof(profile.VehiclePerformanceV2Migration) == "table" and profile.VehiclePerformanceV2Migration or {}
	if migration.Version == "V2_ACCESSORY_ALIGNMENT_V1" and migration.RefundApplied == true then return end
	local refund, converted, missing = 0, 0, 0
	for _, instance in pairs(profile.OwnedModuleInstances) do
		if typeof(instance) == "table" then
			local module = findModule(profile.CurrentCategory, tostring(instance.TemplateId or ""))
			if module then
				local migrated, report = V2.MigrateModuleInstance(instance, module)
				for key, value in pairs(migrated) do instance[key] = value end
				refund += tonumber(report.RefundCredit) or 0; converted += tonumber(report.ConvertedPoints) or 0
			else missing += 1 end
		end
	end
	profile.Cash = (tonumber(profile.Cash) or 0) + refund
	profile.VehiclePerformanceV2Migration = {Version="V2_ACCESSORY_ALIGNMENT_V1", RefundApplied=true, RefundCredit=refund, ConvertedPoints=converted, MissingTemplates=missing, MigratedAtUnix=os.time()}
end

function Runtime.GetLevels(player)
	local profile = profiles[player.UserId]
	local result = {}
	if not profile then return result end
	for slotId, moduleId in pairs(profile.InstalledModules or {}) do
		local _, instance = currentInstance(profile, slotId, moduleId)
		if instance then result[tostring(moduleId)] = instance.V2UpgradePoints or {} end
	end
	return result
end

function Runtime.GetModuleLevels(player, moduleId)
	local all = Runtime.GetLevels(player)
	all[moduleId] = typeof(all[moduleId]) == "table" and all[moduleId] or {}
	return all[moduleId]
end

function Runtime.CatalogForModuleType(_moduleType, module)
	if not module or module:GetAttribute("V2Materialised") ~= true then return {} end
	local result = {}
	local base = V2.ApplyToModuleRaw(module, {})
	for _, path in ipairs(V2.Catalog(module, {})) do
		local one = {[path.PathId] = 1}
		local after = V2.ApplyToModuleRaw(module, one)
		local effects = {}
		for _, name in ipairs(Definitions.RawVariableOrder) do effects[name] = (after[name] or 0) - (base[name] or 0) end
		table.insert(result, {UpgradeId=path.PathId, DisplayName=path.DisplayName, MaxLevel=path.MaxPoints, BasePrice=tonumber(module:GetAttribute("Point1CostGuide")) or 0, PriceMultiplier=1, EffectsPerLevel=effects, V2TotalCapacity=path.Capacity})
	end
	return result
end

function Runtime.Purchase(player, profile, slotId, moduleId, upgradeId, findModule, _moduleTypeForModel)
	profiles[player.UserId] = profile
	applyMigration(profile, findModule)
	local installedId = profile.InstalledModules and profile.InstalledModules[slotId]
	moduleId = moduleId ~= "" and moduleId or installedId
	if installedId ~= moduleId then return false, "Install that module before upgrading it." end
	local module = moduleId and findModule(profile.CurrentCategory, moduleId)
	if not module then return false, "Module not found." end
	local instanceId = currentInstance(profile, slotId, moduleId)
	if not instanceId then return false, "Installed module instance not found." end
	local ok, preview = V2.PurchasePoint(profile, instanceId, module, upgradeId, {})
	if not ok then return false, preview end
	return true, tostring(upgradeId) .. " upgraded for $" .. tostring(preview.Cost) .. "."
end

function Runtime.ApplyToClone(player, moduleTemplate, moduleClone, _moduleTypeForModel)
	local profile = profiles[player.UserId]
	local slotId = tostring(moduleClone:GetAttribute("InstalledSlotId") or "")
	local moduleId = tostring(moduleTemplate:GetAttribute("ModuleId") or moduleTemplate.Name)
	local _, instance = profile and currentInstance(profile, slotId, moduleId)
	local raw = V2.ApplyToModuleRaw(moduleTemplate, instance and instance.V2UpgradePoints or {})
	for name, value in pairs(raw) do moduleClone:SetAttribute(name, value) end
	moduleClone:SetAttribute("V2UpgradePointsApplied", instance and "PROFILE" or "NONE")
end

function Runtime.CalculateProfile(player, profile, _legacyTotals, cockpit, findModule, _moduleTypeForModel)
	profiles[player.UserId] = profile
	assert(cockpit and cockpit:GetAttribute("V2Materialised") == true, "Canonical V2 cockpit is not materialised")
	applyMigration(profile, findModule)
	local modules, allocations = {}, {}
	for slotId, moduleId in pairs(profile.InstalledModules or {}) do
		local module = findModule(profile.CurrentCategory, moduleId)
		if module then
			table.insert(modules, module)
			local _, instance = currentInstance(profile, slotId, moduleId)
			allocations[tostring(module:GetAttribute("ModuleId") or module.Name)] = instance and instance.V2UpgradePoints or {}
		end
	end
	return V2Runtime.CalculateComponents(cockpit, modules, allocations)
end

return Runtime
