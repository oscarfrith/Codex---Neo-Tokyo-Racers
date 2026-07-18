-- NTR_GARAGE_MODULE_INVENTORY_RUNTIME_V1
-- Canonical instance-inventory shape and cleanup planning.
-- Runtime request methods never create or delete module instances.

local Runtime = {}

local function dictionaryCount(dictionary)
	local result = 0
	for _ in pairs(dictionary or {}) do result += 1 end
	return result
end

local function sortedKeys(dictionary)
	local result = {}
	for key in pairs(dictionary or {}) do table.insert(result, tostring(key)) end
	table.sort(result)
	return result
end

function Runtime.EnsureShape(profile)
	if typeof(profile) ~= "table" then return false, "Profile must be a table." end
	profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
	profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
	profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	profile.GarageDisplaySpaces = typeof(profile.GarageDisplaySpaces) == "table" and profile.GarageDisplaySpaces or {}
	profile.OwnedCockpits = typeof(profile.OwnedCockpits) == "table" and profile.OwnedCockpits or {}
	profile.OwnedModules = typeof(profile.OwnedModules) == "table" and profile.OwnedModules or {}
	profile.InstalledModules = typeof(profile.InstalledModules) == "table" and profile.InstalledModules or {}
	profile.ModuleUpgradeLevels = typeof(profile.ModuleUpgradeLevels) == "table" and profile.ModuleUpgradeLevels or {}
	profile.ModuleColors = typeof(profile.ModuleColors) == "table" and profile.ModuleColors or {}
	profile.NeonOwned = typeof(profile.NeonOwned) == "table" and profile.NeonOwned or {}
	for _, vehicle in pairs(profile.Vehicles) do
		if typeof(vehicle) == "table" then
			vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}
		end
	end
	return true
end

function Runtime.ReferenceIndex(profile)
	if typeof(profile) ~= "table" then return {}, {} end
	local vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
	local moduleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	local references = {}
	local missing = {}
	for vehicleId, vehicle in pairs(vehicles) do
		if typeof(vehicle) == "table" then
			for slotId, instanceIdValue in pairs(vehicle.InstalledModules or {}) do
				local instanceId = tostring(instanceIdValue)
				references[instanceId] = references[instanceId] or {}
				table.insert(references[instanceId], {VehicleId = tostring(vehicleId), SlotId = tostring(slotId)})
				if typeof(moduleInstances[instanceId]) ~= "table" then
					table.insert(missing, {VehicleId = tostring(vehicleId), SlotId = tostring(slotId), InstanceId = instanceId})
				end
			end
		end
	end
	return references, missing
end

function Runtime.PlanCleanup(profile)
	if typeof(profile) ~= "table" then error("Profile must be a table.") end
	local moduleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	local references, missing = Runtime.ReferenceIndex(profile)
	local plan = {
		Version = "V1",
		TotalInstances = dictionaryCount(moduleInstances),
		DeleteIds = {},
		ProtectedIds = {},
		ReviewIds = {},
		DeleteByTemplate = {},
		ProtectedBySource = {},
		ReviewByReason = {},
		MissingReferences = missing,
	}

	for instanceIdValue, instance in pairs(moduleInstances) do
		local instanceId = tostring(instanceIdValue)
		if typeof(instance) ~= "table" then
			table.insert(plan.ReviewIds, instanceId)
			plan.ReviewByReason.InvalidRecord = (plan.ReviewByReason.InvalidRecord or 0) + 1
			continue
		end
		local source = tostring(instance.Source or "<missing-source>")
		local templateId = tostring(instance.TemplateId or "<missing-template>")
		local refs = references[instanceId] or {}
		local equippedVehicleId = instance.EquippedVehicleId ~= nil and tostring(instance.EquippedVehicleId) or ""

		if #refs > 0 then
			table.insert(plan.ProtectedIds, instanceId)
			plan.ProtectedBySource[source] = (plan.ProtectedBySource[source] or 0) + 1
		elseif source == "BuyModuleInstance" then
			table.insert(plan.ProtectedIds, instanceId)
			plan.ProtectedBySource[source] = (plan.ProtectedBySource[source] or 0) + 1
		elseif source == "LegacyInstalledModules" and equippedVehicleId ~= "" then
			table.insert(plan.DeleteIds, instanceId)
			plan.DeleteByTemplate[templateId] = (plan.DeleteByTemplate[templateId] or 0) + 1
		else
			table.insert(plan.ReviewIds, instanceId)
			local reason = "UnreferencedOtherSource"
			if source == "LegacyInstalledModules" then
				reason = "AvailableLegacy"
			elseif source == "IncludedWithCockpit" then
				reason = "UnreferencedCockpitGrant"
			end
			plan.ReviewByReason[reason] = (plan.ReviewByReason[reason] or 0) + 1
		end
	end

	table.sort(plan.DeleteIds)
	table.sort(plan.ProtectedIds)
	table.sort(plan.ReviewIds)
	local tokenParts = {plan.Version, tostring(plan.TotalInstances), tostring(#plan.DeleteIds)}
	for _, templateId in ipairs(sortedKeys(plan.DeleteByTemplate)) do
		table.insert(tokenParts, templateId .. "=" .. tostring(plan.DeleteByTemplate[templateId]))
	end
	plan.Token = table.concat(tokenParts, "|")
	return plan
end

function Runtime.StampAcquisition(instance, acquisitionKind, vehicleId)
	if typeof(instance) ~= "table" then return instance end
	instance.AcquisitionKind = tostring(acquisitionKind or instance.Source or "Unknown")
	instance.AcquiredAtUnix = tonumber(instance.AcquiredAtUnix) or os.time()
	if vehicleId ~= nil then instance.GrantedForVehicleId = tostring(vehicleId) end
	return instance
end

-- NTR_GARAGE_MODULE_INVENTORY_APPLY_RUNTIME_V1
local cleanupSnapshots = setmetatable({}, {__mode = "k"})

local function cleanupClone(value, seen)
	if typeof(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for key, child in pairs(value) do
		copy[cleanupClone(key, seen)] = cleanupClone(child, seen)
	end
	return copy
end

local function cleanupReplace(target, replacement)
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(replacement or {}) do target[key] = cleanupClone(value) end
end

function Runtime.ApplyReviewedCleanup(profile, expectedToken)
	if typeof(profile) ~= "table" then return false, "Profile must be a table." end
	if cleanupSnapshots[profile] then return false, "A cleanup transaction is already active." end
	local plan = Runtime.PlanCleanup(profile)
	if plan.Token ~= expectedToken then return false, "Legacy-owner cleanup token changed." end
	if #plan.MissingReferences > 0 then return false, "Legacy owner has missing installed references." end
	local references = Runtime.ReferenceIndex(profile)
	for _, instanceId in ipairs(plan.DeleteIds) do
		local instance = profile.OwnedModuleInstances[instanceId]
		if typeof(instance) ~= "table"
			or instance.Source ~= "LegacyInstalledModules"
			or instance.EquippedVehicleId == nil
			or (references[instanceId] and #references[instanceId] > 0) then
			return false, "Unsafe legacy deletion candidate: " .. tostring(instanceId)
		end
	end
	for _, instanceId in ipairs(plan.ReviewIds) do
		local instance = profile.OwnedModuleInstances[instanceId]
		if typeof(instance) ~= "table" or instance.Source ~= "IncludedWithCockpit" then
			return false, "Unexpected legacy review record: " .. tostring(instanceId)
		end
	end

	cleanupSnapshots[profile] = {
		OwnedModuleInstances = cleanupClone(profile.OwnedModuleInstances),
		LegacyMigration = cleanupClone(profile.LegacyMigration),
	}
	local ok, result = pcall(function()
		for _, instanceId in ipairs(plan.DeleteIds) do
			profile.OwnedModuleInstances[instanceId] = nil
		end
		local postReferences = Runtime.ReferenceIndex(profile)
		for instanceIdValue, instance in pairs(profile.OwnedModuleInstances) do
			local instanceId = tostring(instanceIdValue)
			local refs = postReferences[instanceId] or {}
			if #refs > 1 then error("Multiple slot references for " .. instanceId) end
			if #refs == 1 then
				instance.EquippedVehicleId = tostring(refs[1].VehicleId)
			else
				instance.EquippedVehicleId = nil
			end
			instance.AcquisitionKind = instance.AcquisitionKind or tostring(instance.Source or "ExistingInventory")
		end
		profile.LegacyMigration = typeof(profile.LegacyMigration) == "table" and profile.LegacyMigration or {}
		profile.LegacyMigration.GarageModuleInventoryCleanup = {
			Version = "V1",
			AppliedAtUnix = os.time(),
			OriginalInstanceCount = plan.TotalInstances,
			RemovedInstanceCount = #plan.DeleteIds,
			PreservedCockpitGrantCount = #plan.ReviewIds,
		}
		local postPlan = Runtime.PlanCleanup(profile)
		if postPlan.TotalInstances ~= plan.TotalInstances - #plan.DeleteIds
			or #postPlan.DeleteIds ~= 0
			or #postPlan.MissingReferences ~= 0 then
			error("Legacy-owner post-cleanup validation failed.")
		end
		return {
			Original = plan.TotalInstances,
			Removed = #plan.DeleteIds,
			Remaining = postPlan.TotalInstances,
		}
	end)
	if not ok then
		local snapshot = cleanupSnapshots[profile]
		cleanupReplace(profile.OwnedModuleInstances, snapshot.OwnedModuleInstances)
		profile.LegacyMigration = snapshot.LegacyMigration
		cleanupSnapshots[profile] = nil
		return false, tostring(result)
	end
	return true, result
end

function Runtime.RollbackReviewedCleanup(profile)
	local snapshot = cleanupSnapshots[profile]
	if not snapshot then return true, "No legacy-owner cleanup transaction was active." end
	profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	cleanupReplace(profile.OwnedModuleInstances, snapshot.OwnedModuleInstances)
	profile.LegacyMigration = snapshot.LegacyMigration
	cleanupSnapshots[profile] = nil
	return true, "Legacy-owner cleanup rolled back."
end

function Runtime.CommitReviewedCleanup(profile)
	cleanupSnapshots[profile] = nil
	return true, "Legacy-owner cleanup committed."
end

return Runtime
