-- NTR_VEHICLE_PERFORMANCE_V2_PHASE7_UPGRADE_RUNTIME
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceV2Definitions"))
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceV2Calculator"))
local LegacyDefinitions = require(script.Parent:WaitForChild("VehicleUpgradeDefinitions"))

local Runtime = {}
local legacyMap = {
	FuelInjection = "Output", PowerConverter = "Velocity", LightweightInternals = "Efficiency", TorqueMapping = "Output",
	VectoringFirmware = "Grip", DriftCalibration = "Drift", ReactiveDampers = "Response", LightweightArms = "Response",
	HighFlowInjectors = "Burst", ExpandedCell = "Endurance", RapidRecharge = "Recovery", LightweightCell = "Endurance",
}
local legacyOrder = {
	"FuelInjection", "PowerConverter", "LightweightInternals", "TorqueMapping",
	"VectoringFirmware", "DriftCalibration", "ReactiveDampers", "LightweightArms",
	"HighFlowInjectors", "ExpandedCell", "RapidRecharge", "LightweightCell",
}

local function clone(value)
	if typeof(value) ~= "table" then return value end
	local result = {}; for key, child in pairs(value) do result[key] = clone(child) end; return result
end

local function pathsRoot(module)
	return module and (module:FindFirstChild("VehiclePerformanceV2UpgradePaths") or module:FindFirstChild("UpgradePaths"))
end

local function sortedPaths(module)
	local result = {}
	local root = pathsRoot(module)
	if root then for _, path in ipairs(root:GetChildren()) do if path:IsA("Folder") then table.insert(result, path) end end end
	table.sort(result, function(a, b) return tostring(a:GetAttribute("PathId") or a.Name) < tostring(b:GetAttribute("PathId") or b.Name) end)
	return result
end

function Runtime.NormalizeAllocation(module, allocation)
	allocation = typeof(allocation) == "table" and allocation or {}
	local capacity = math.max(0, math.floor(tonumber(module and module:GetAttribute("UpgradePointCapacity")) or 0))
	local result, spent = {}, 0
	for _, path in ipairs(sortedPaths(module)) do
		local id = tostring(path:GetAttribute("PathId") or path.Name)
		local maxPath = math.max(0, math.floor(tonumber(path:GetAttribute("MaxPoints")) or module:GetAttribute("MaxPointsPerPath") or 3))
		local points = math.clamp(math.floor(tonumber(allocation[id]) or 0), 0, maxPath)
		points = math.min(points, math.max(0, capacity - spent))
		result[id] = points
		spent += points
	end
	return result, spent, capacity
end

function Runtime.ApplyToModuleRaw(module, allocation)
	local normalized = Runtime.NormalizeAllocation(module, allocation)
	local raw = {}
	for _, name in ipairs(Definitions.RawVariableOrder) do raw[name] = tonumber(module and module:GetAttribute(name)) or tonumber(module and module:GetAttribute("PerformanceDelta_" .. name)) or 0 end
	for _, path in ipairs(sortedPaths(module)) do
		local id = tostring(path:GetAttribute("PathId") or path.Name)
		local points = normalized[id] or 0
		if points > 0 then
			for _, name in ipairs(Definitions.RawVariableOrder) do
				local fraction = path:GetAttribute("DeltaFraction_" .. name)
				if typeof(fraction) == "number" then raw[name] *= 1 + fraction * points end
			end
		end
	end
	return raw
end

function Runtime.NextPointCost(module, allocation)
	local _, spent, capacity = Runtime.NormalizeAllocation(module, allocation)
	if spent >= capacity then return nil end
	return tonumber(module:GetAttribute("Point" .. tostring(spent + 1) .. "CostGuide")) or 0
end

function Runtime.Catalog(module, allocation)
	local normalized, spent, capacity = Runtime.NormalizeAllocation(module, allocation)
	local result = {}
	for _, path in ipairs(sortedPaths(module)) do
		local id = tostring(path:GetAttribute("PathId") or path.Name)
		table.insert(result, {
			PathId = id, DisplayName = tostring(path:GetAttribute("DisplayName") or id),
			Points = normalized[id] or 0, MaxPoints = tonumber(path:GetAttribute("MaxPoints")) or 3,
			TotalPoints = spent, Capacity = capacity, NextPointCost = Runtime.NextPointCost(module, normalized),
		})
	end
	return result
end

function Runtime.PreviewPoint(module, allocation, pathId, baseBuildRaw)
	local normalized, spent, capacity = Runtime.NormalizeAllocation(module, allocation)
	local root = pathsRoot(module)
	local path = root and root:FindFirstChild(tostring(pathId))
	if not path then return false, "Upgrade path not found." end
	local maxPath = tonumber(path:GetAttribute("MaxPoints")) or 3
	if (normalized[pathId] or 0) >= maxPath then return false, "Path already maxed." end
	if spent >= capacity then return false, "Module has no upgrade points remaining." end
	local nextAllocation = clone(normalized)
	nextAllocation[pathId] = (nextAllocation[pathId] or 0) + 1
	local beforeRaw, afterRaw = Runtime.ApplyToModuleRaw(module, normalized), Runtime.ApplyToModuleRaw(module, nextAllocation)
	local rawDelta = {}; for _, name in ipairs(Definitions.RawVariableOrder) do rawDelta[name] = afterRaw[name] - beforeRaw[name] end
	local preview = { Cost = Runtime.NextPointCost(module, normalized), Allocation = nextAllocation, RawDelta = rawDelta }
	if typeof(baseBuildRaw) == "table" then
		local beforeBuild, afterBuild = Calculator.CloneRaw(baseBuildRaw), Calculator.CloneRaw(baseBuildRaw)
		Calculator.AddRaw(beforeBuild, beforeRaw); Calculator.AddRaw(afterBuild, afterRaw)
		local beforeResult, afterResult = Calculator.Calculate(beforeBuild), Calculator.Calculate(afterBuild)
		preview.Before = beforeResult; preview.After = afterResult
		preview.InternalPerformanceIndexGain = afterResult.Overall.InternalPerformanceIndex - beforeResult.Overall.InternalPerformanceIndex
	end
	return true, preview
end

function Runtime.PurchasePoint(profile, moduleInstanceId, module, pathId, baseBuildRaw)
	if typeof(profile) ~= "table" then return false, "Profile is required." end
	local instance = profile.OwnedModuleInstances and profile.OwnedModuleInstances[moduleInstanceId]
	if typeof(instance) ~= "table" then return false, "Module instance not found." end
	if tostring(instance.TemplateId or "") ~= tostring(module:GetAttribute("ModuleId") or module.Name) then return false, "Module template mismatch." end
	local ok, preview = Runtime.PreviewPoint(module, instance.V2UpgradePoints, pathId, baseBuildRaw)
	if not ok then return false, preview end
	local cost = tonumber(preview.Cost) or 0
	if (tonumber(profile.Cash) or 0) < cost then return false, "Not enough cash." end
	profile.Cash -= cost
	instance.V2UpgradePoints = preview.Allocation
	instance.V2UpgradeVersion = "V2_PHASE7"
	return true, preview
end

local function legacyDefinition(upgradeId)
	for moduleType, definitions in pairs(LegacyDefinitions.ByModuleType or {}) do
		for _, definition in ipairs(definitions) do if definition.UpgradeId == upgradeId then return definition, moduleType end end
	end
	return nil
end

function Runtime.MigrateModuleInstance(moduleInstance, module)
	local migrated = clone(moduleInstance or {})
	if typeof(migrated.V2UpgradePoints) == "table" then
		migrated.V2UpgradePoints = Runtime.NormalizeAllocation(module, migrated.V2UpgradePoints)
		migrated.V2UpgradeVersion = "V2_PHASE7"
		return migrated, { AlreadyV2 = true, ConvertedPoints = 0, RefundCredit = 0 }
	end
	local allocation, converted, refund = {}, 0, 0
	local legacy = typeof(migrated.UpgradeLevels) == "table" and migrated.UpgradeLevels or {}
	for _, upgradeId in ipairs(legacyOrder) do
		local level = math.clamp(math.floor(tonumber(legacy[upgradeId]) or 0), 0, 3)
		local definition = legacyDefinition(upgradeId)
		for point = 1, level do
			local pathId = legacyMap[upgradeId]
			local proposal = clone(allocation); proposal[pathId] = (proposal[pathId] or 0) + 1
			local normalized, spent = Runtime.NormalizeAllocation(module, proposal)
			if spent > converted and (normalized[pathId] or 0) > (allocation[pathId] or 0) then allocation = normalized; converted = spent else
				if definition then refund += math.floor((definition.BasePrice or 0) * ((definition.PriceMultiplier or 1) ^ (point - 1))) end
			end
		end
	end
	migrated.V2UpgradePoints = Runtime.NormalizeAllocation(module, allocation)
	migrated.V2UpgradeVersion = "V2_PHASE7"
	migrated.V2LegacyUpgradeLevels = clone(legacy)
	migrated.V2MigrationRefundCredit = refund
	return migrated, { AlreadyV2 = false, ConvertedPoints = converted, RefundCredit = refund }
end

function Runtime.MigrateProfileCopy(profile, moduleResolver)
	local migrated = clone(profile or {})
	migrated.OwnedModuleInstances = typeof(migrated.OwnedModuleInstances) == "table" and migrated.OwnedModuleInstances or {}
	local report = { ModuleInstances = 0, ConvertedPoints = 0, RefundCredit = 0, MissingTemplates = {} }
	for instanceId, instance in pairs(migrated.OwnedModuleInstances) do
		local module = moduleResolver(tostring(instance.TemplateId or ""))
		if module then
			local converted, item = Runtime.MigrateModuleInstance(instance, module)
			migrated.OwnedModuleInstances[instanceId] = converted
			report.ModuleInstances += 1; report.ConvertedPoints += item.ConvertedPoints; report.RefundCredit += item.RefundCredit
		else table.insert(report.MissingTemplates, tostring(instance.TemplateId or instanceId)) end
	end
	migrated.VehiclePerformanceV2Migration = { Version = "V2_PHASE7", PreviewOnly = true, RefundCredit = report.RefundCredit }
	return migrated, report
end

return Runtime
