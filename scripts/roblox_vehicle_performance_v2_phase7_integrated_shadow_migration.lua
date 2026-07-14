-- Neo Tokyo Racers - Vehicle Performance V2 Phase 7 integrated shadow migration
-- Run in Roblox Studio Edit mode (not Play mode).
--
-- One consolidated pre-live integration gate. It installs isolated V2 runtime,
-- upgrade/persistence migration, catalogue-preview, and shadow comparison owners.
-- It does not publish staged assets, patch the garage/bootstrap/driving sources,
-- enable V2 rating/physics, spend player cash, or mutate live player profiles.
-- No source text replacement is used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing Vehicle Performance V2 Phase 7")

local PREFIX = "[NTR Vehicle Performance V2 Phase 7]"
local passCount, warnCount, failCount = 0, 0, 0
local function pass(message) passCount += 1; print(PREFIX .. " PASS - " .. message) end
local function fail(message) failCount += 1; warn(PREFIX .. " FAIL - " .. message) end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item then assert(item:IsA("Folder"), item:GetFullName() .. " must be a Folder"); return item end
	item = Instance.new("Folder")
	item.Name = name
	item.Parent = parent
	return item
end

local function ensureModule(parent, name, source)
	local item = parent:FindFirstChild(name)
	if item then assert(item:IsA("ModuleScript"), item:GetFullName() .. " must be a ModuleScript") else
		item = Instance.new("ModuleScript")
		item.Name = name
		item.Parent = parent
	end
	item.Source = source
	item:SetAttribute("NTRVehiclePerformanceV2Phase", 7)
	return item
end

local function ensureScript(parent, name, source)
	local item = parent:FindFirstChild(name)
	if item then assert(item:IsA("Script"), item:GetFullName() .. " must be a Script") else
		item = Instance.new("Script")
		item.Name = name
		item.Parent = parent
	end
	item.Source = source
	item.Disabled = false
	item:SetAttribute("NTRVehiclePerformanceV2Phase", 7)
	return item
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local config = shared:WaitForChild("Config"):WaitForChild("VehiclePerformanceV2_EditAttributes")
local performance = shared:WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local calculatorV2 = performance:WaitForChild("VehiclePerformanceV2Calculator")
local definitionsV2 = performance:WaitForChild("VehiclePerformanceV2Definitions")
local liveDefinitions = performance:WaitForChild("VehiclePerformanceDefinitions")
local liveCalculator = performance:WaitForChild("VehiclePerformanceCalculator")
local liveRuntime = performance:WaitForChild("VehiclePerformanceRuntime")
local liveUpgradeRuntime = performance:WaitForChild("VehicleModuleUpgradeRuntime")
local liveUpgradeDefinitions = performance:WaitForChild("VehicleUpgradeDefinitions")
local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")

local liveSources = {
	Definitions = liveDefinitions.Source,
	Calculator = liveCalculator.Source,
	Runtime = liveRuntime.Source,
	UpgradeRuntime = liveUpgradeRuntime.Source,
	UpgradeDefinitions = liveUpgradeDefinitions.Source,
}
local liveCategoryCount = #categories:GetDescendants()

assert(config:GetAttribute("SchemaVersion") == "V2_PHASE5_UPGRADE_PATHS"
	or config:GetAttribute("SchemaVersion") == "V2_PHASE7_INTEGRATED_SHADOW", "Confirmed Phase 5/7 config is missing")
assert(config:GetAttribute("RuntimeRatingEnabled") == false, "RuntimeRatingEnabled must remain false")
assert(config:GetAttribute("RuntimePhysicsEnabled") == false, "RuntimePhysicsEnabled must remain false")

local serverNtr = ServerStorage:FindFirstChild("NeoTokyoRacers")
local staging = serverNtr and serverNtr:FindFirstChild("VehiclePerformanceV2_Staging")
assert(staging and staging:IsA("Folder"), "Phase 6 staging is missing; rerun the canonical Phase 6 installer before Phase 7")
assert(staging:GetAttribute("GeneratedBy") == "NTR_VEHICLE_PERFORMANCE_V2_PHASE6", "Phase 6 staging ownership marker is missing")
assert(staging:GetAttribute("SchemaVersion") == "V2_PHASE6_ASSET_MATERIALISATION_STAGING", "Phase 6 staging schema is wrong")
assert(staging:GetAttribute("CatalogPublishReady") == false, "Phase 6 staging must not be publish-ready")

local stagedCategory
for _, child in ipairs(staging:GetChildren()) do
	if child:FindFirstChild("COCKPITS_ReplaceAssetsHere") and child:FindFirstChild("MODULES_InterchangeableWithinCategory") then stagedCategory = child; break end
end
assert(stagedCategory, "Phase 6 staged category hierarchy is missing")
local stagedCockpitRoot = stagedCategory:WaitForChild("COCKPITS_ReplaceAssetsHere")
local stagedModuleRoot = stagedCategory:WaitForChild("MODULES_InterchangeableWithinCategory")

local stagedCockpits, stagedModules = {}, {}
for _, item in ipairs(stagedCockpitRoot:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("CockpitId") then stagedCockpits[item:GetAttribute("CockpitId")] = item end
end
for _, item in ipairs(stagedModuleRoot:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("ModuleId") then stagedModules[item:GetAttribute("ModuleId")] = item end
end
local function count(dictionary) local result = 0; for _ in pairs(dictionary) do result += 1 end; return result end
assert(count(stagedCockpits) == 6, "Phase 7 requires exactly six staged cockpits")
assert(count(stagedModules) == 72, "Phase 7 requires exactly 72 staged modules")
pass("Preflighted the real Phase 6 staging hierarchy at six cockpits/72 modules")

local dynamicsAdapterSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_PHASE7_DYNAMICS_ADAPTER
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceV2Calculator"))

local Adapter = {}

function Adapter.FromRaw(raw)
	raw = typeof(raw) == "table" and raw or {}
	return {
		TopSpeed = tonumber(raw.TopSpeed) or 0,
		EngineOutput = Calculator.EffectiveFactor("EngineOutput", raw.EngineOutput),
		Weight = Calculator.EffectiveFactor("Weight", raw.Weight),
		LateralGrip = Calculator.EffectiveFactor("LateralGrip", raw.LateralGrip),
		SteeringResponse = Calculator.EffectiveFactor("SteeringResponse", raw.SteeringResponse),
		HoverStability = Calculator.EffectiveFactor("HoverStability", raw.HoverStability),
		DriftControl = Calculator.EffectiveFactor("DriftControl", raw.DriftControl),
		DriftGrip = Calculator.EffectiveFactor("DriftGrip", raw.DriftGrip),
		DriftChargeRate = Calculator.EffectiveFactor("DriftChargeRate", raw.DriftChargeRate),
		BrakingForce = Calculator.EffectiveFactor("BrakingForce", raw.BrakingForce),
		BoostForce = Calculator.EffectiveFactor("BoostForce", raw.BoostForce),
		BoostDuration = Calculator.EffectiveFactor("BoostDuration", raw.BoostDuration),
		BoostRecharge = Calculator.EffectiveFactor("BoostRecharge", raw.BoostRecharge),
		BoostRechargeDelay = Calculator.EffectiveFactor("BoostRechargeDelay", raw.BoostRechargeDelay),
		BoostEfficiency = Calculator.EffectiveFactor("BoostEfficiency", raw.BoostEfficiency),
		Drag = Calculator.EffectiveFactor("Drag", raw.Drag),
		Downforce = Calculator.EffectiveFactor("Downforce", raw.Downforce),
	}
end

function Adapter.FromResult(result)
	return Adapter.FromRaw(result and result.Raw)
end

return Adapter
]==]

local runtimeSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_PHASE7_RUNTIME
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceV2Definitions"))
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceV2Calculator"))
local UpgradeRuntime = require(script.Parent:WaitForChild("VehiclePerformanceV2UpgradeRuntime"))
local DynamicsAdapter = require(script.Parent:WaitForChild("VehiclePerformanceV2DynamicsAdapter"))

local Runtime = {}

local function finite(value, fallback)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge and value or fallback
end

function Runtime.ZeroRaw()
	local raw = {}
	for _, name in ipairs(Definitions.RawVariableOrder) do raw[name] = 0 end
	return raw
end

function Runtime.ReadComponentRaw(item)
	local raw = Runtime.ZeroRaw()
	for _, name in ipairs(Definitions.RawVariableOrder) do
		raw[name] = finite(item and item:GetAttribute(name), finite(item and item:GetAttribute("PerformanceDelta_" .. name), 0))
	end
	return raw
end

function Runtime.ReadRuntimeRaw(vehicle)
	local raw = Runtime.ZeroRaw()
	local folder = vehicle and vehicle:FindFirstChild("RAW_PERFORMANCE_Runtime")
	for _, name in ipairs(Definitions.RawVariableOrder) do
		local valueObject = folder and folder:FindFirstChild(name)
		raw[name] = finite(valueObject and valueObject:IsA("NumberValue") and valueObject.Value,
			finite(vehicle and vehicle:GetAttribute("Performance_" .. name), 0))
	end
	return raw
end

function Runtime.AddRaw(target, source)
	for _, name in ipairs(Definitions.RawVariableOrder) do target[name] = finite(target[name], 0) + finite(source and source[name], 0) end
	return target
end

function Runtime.CalculateComponents(cockpit, modules, allocationsByModuleId)
	local raw = Runtime.ReadComponentRaw(cockpit)
	for _, module in ipairs(modules or {}) do
		local moduleId = tostring(module:GetAttribute("ModuleId") or module.Name)
		local allocation = allocationsByModuleId and allocationsByModuleId[moduleId]
		Runtime.AddRaw(raw, UpgradeRuntime.ApplyToModuleRaw(module, allocation))
	end
	return Calculator.Calculate(raw)
end

function Runtime.CalculateRuntimeVehicle(vehicle)
	return Calculator.Calculate(Runtime.ReadRuntimeRaw(vehicle))
end

function Runtime.CompatibilityView(result)
	local headline, overall, raw = result.Headline or {}, result.Overall or {}, result.Raw or {}
	return {
		Overall = { Tier = overall.Tier, PerformanceIndex = overall.PerformanceIndex, InternalPerformanceIndex = overall.InternalPerformanceIndex, Score = overall.Score },
		Headline = { Speed = headline.Speed, Acceleration = headline.Acceleration, Handling = headline.Handling, Drift = headline.Drift, Braking = headline.Braking, Boost = headline.Boost },
		Driving = {
			TopSpeed = raw.TopSpeed, EngineOutput = raw.EngineOutput, Weight = raw.Weight,
			LateralGrip = raw.LateralGrip, SteeringResponse = raw.SteeringResponse, HoverStability = raw.HoverStability,
			DriftControl = raw.DriftControl, DriftGrip = raw.DriftGrip, DriftChargeRate = raw.DriftChargeRate,
			BrakingForce = raw.BrakingForce, BoostForce = raw.BoostForce, BoostDuration = raw.BoostDuration,
			BoostRecharge = raw.BoostRecharge, BoostRechargeDelay = raw.BoostRechargeDelay,
			BoostEfficiency = raw.BoostEfficiency, Drag = raw.Drag, Downforce = raw.Downforce,
		},
		DynamicsFactors = DynamicsAdapter.FromRaw(raw),
	}
end

local function rewriteFolder(parent, name, values)
	local folder = parent:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then folder:Destroy(); folder = nil end
	if not folder then folder = Instance.new("Folder"); folder.Name = name; folder.Parent = parent end
	folder:ClearAllChildren()
	for key, value in pairs(values or {}) do
		if typeof(value) == "number" then local number = Instance.new("NumberValue"); number.Name = key; number.Value = value; number.Parent = folder end
	end
end

function Runtime.WriteShadow(vehicle, result)
	local view = Runtime.CompatibilityView(result)
	rewriteFolder(vehicle, "V2_SHADOW_RAW_PERFORMANCE_Runtime", result.Raw)
	rewriteFolder(vehicle, "V2_SHADOW_HEADLINE_STATS_Runtime", result.Headline)
	vehicle:SetAttribute("V2ShadowPerformanceIndex", view.Overall.PerformanceIndex)
	vehicle:SetAttribute("V2ShadowInternalPerformanceIndex", view.Overall.InternalPerformanceIndex)
	vehicle:SetAttribute("V2ShadowPerformanceTier", view.Overall.Tier)
	vehicle:SetAttribute("V2ShadowRuntimeVersion", "V2_PHASE7_INTEGRATED_SHADOW")
	return view
end

function Runtime.CatalogPreview(module, allocation)
	local raw = UpgradeRuntime.ApplyToModuleRaw(module, allocation)
	return {
		ModuleId = tostring(module:GetAttribute("ModuleId") or module.Name),
		DisplayName = tostring(module:GetAttribute("DisplayName") or module.Name),
		Price = tonumber(module:GetAttribute("Price")) or 0,
		Allocation = UpgradeRuntime.NormalizeAllocation(module, allocation),
		Raw = raw,
		Paths = UpgradeRuntime.Catalog(module, allocation),
	}
end

return Runtime
]==]

local upgradeSource = [==[
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
]==]

local shadowServiceSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_PHASE7_SHADOW_SERVICE
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("VehiclePerformanceV2_EditAttributes")
local runtime = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance"):WaitForChild("VehiclePerformanceV2Runtime"))
local pending = setmetatable({}, { __mode = "k" })

local function evaluate(vehicle)
	if config:GetAttribute("ShadowComparisonEnabled") ~= true then return end
	if not vehicle:IsA("Model") or not vehicle:FindFirstChild("RAW_PERFORMANCE_Runtime") then return end
	local ok, result = pcall(runtime.CalculateRuntimeVehicle, vehicle)
	if ok then runtime.WriteShadow(vehicle, result) else warn("[NTR V2 Shadow] " .. vehicle:GetFullName() .. ": " .. tostring(result)) end
end

local function schedule(vehicle)
	if pending[vehicle] then return end
	pending[vehicle] = true
	task.delay(0.2, function()
		pending[vehicle] = nil
		if vehicle.Parent then evaluate(vehicle) end
	end)
end

local function consider(item)
	local folder
	if item.Name == "RAW_PERFORMANCE_Runtime" and item:IsA("Folder") then folder = item
	elseif item.Parent and item.Parent.Name == "RAW_PERFORMANCE_Runtime" and item.Parent:IsA("Folder") then folder = item.Parent end
	if folder and folder.Parent and folder.Parent:IsA("Model") then schedule(folder.Parent) end
end

Workspace.DescendantAdded:Connect(consider)
print("[NTR Vehicle Performance V2 Phase 7] Shadow comparison service active; live V1 rating/physics remain authoritative.")
]==]

-- Compile/load the isolated sources against a fresh dependency set before any
-- canonical object or config mutation. The temporary folder is always removed.
local freshRoot = Instance.new("Folder")
freshRoot.Name = "VehiclePerformanceV2_Phase7PreflightTemp"
freshRoot.Parent = performance
definitionsV2:Clone().Parent = freshRoot
calculatorV2:Clone().Parent = freshRoot
liveUpgradeDefinitions:Clone().Parent = freshRoot
local freshUpgradeModule = Instance.new("ModuleScript")
freshUpgradeModule.Name = "VehiclePerformanceV2UpgradeRuntime"
freshUpgradeModule.Source = upgradeSource
freshUpgradeModule.Parent = freshRoot
local freshDynamicsModule = Instance.new("ModuleScript")
freshDynamicsModule.Name = "VehiclePerformanceV2DynamicsAdapter"
freshDynamicsModule.Source = dynamicsAdapterSource
freshDynamicsModule.Parent = freshRoot
local freshRuntimeModule = Instance.new("ModuleScript")
freshRuntimeModule.Name = "VehiclePerformanceV2Runtime"
freshRuntimeModule.Source = runtimeSource
freshRuntimeModule.Parent = freshRoot
local upgradeLoaded, UpgradeRuntime = pcall(require, freshUpgradeModule)
local dynamicsLoaded, DynamicsAdapter = pcall(require, freshDynamicsModule)
local runtimeLoaded, RuntimeV2 = pcall(require, freshRuntimeModule)
freshRoot:Destroy()
assert(upgradeLoaded, "Fresh V2 upgrade runtime failed to load: " .. tostring(UpgradeRuntime))
assert(dynamicsLoaded, "Fresh V2 dynamics adapter failed to load: " .. tostring(DynamicsAdapter))
assert(runtimeLoaded, "Fresh V2 runtime failed to load: " .. tostring(RuntimeV2))
pass("Preflight-loaded fresh Phase 7 modules without retaining validation objects")

-- All preflights above have completed. Mutation is isolated to new V2 owners,
-- V2 config attributes, and non-live Phase 6 staging readiness markers.
local upgradeModule = ensureModule(performance, "VehiclePerformanceV2UpgradeRuntime", upgradeSource)
local dynamicsModule = ensureModule(performance, "VehiclePerformanceV2DynamicsAdapter", dynamicsAdapterSource)
local runtimeModule = ensureModule(performance, "VehiclePerformanceV2Runtime", runtimeSource)
local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
local vehicleServices = ensureFolder(services, "Vehicle")
local shadowService = ensureScript(vehicleServices, "VehiclePerformanceV2ShadowService_Active", shadowServiceSource)
pass("Installed isolated V2 runtime, six-point upgrade/migration, preview, and shadow owners")

config:SetAttribute("SchemaVersion", "V2_PHASE7_INTEGRATED_SHADOW")
config:SetAttribute("SourceSheetRevision", "NTR-BAL-008-P7")
config:SetAttribute("ShadowOnly", true)
config:SetAttribute("ShadowComparisonEnabled", true)
config:SetAttribute("RuntimeRatingEnabled", false)
config:SetAttribute("RuntimePhysicsEnabled", false)
config:SetAttribute("RuntimeUpgradePurchasesEnabled", false)
config:SetAttribute("RuntimeProfileMigrationEnabled", false)
config:SetAttribute("LiveCataloguePublishEnabled", false)
config:SetAttribute("IntegrationNote", "Phase 7 isolated owners installed. V1 remains authoritative until the atomic Phase 8 switch.")
local integration = ensureFolder(config, "Integration")
integration:SetAttribute("SchemaVersion", "V2_PHASE7_INTEGRATED_SHADOW")
integration:SetAttribute("ModuleInstanceAllocationField", "V2UpgradePoints")
integration:SetAttribute("UpgradePointCapacity", 6)
integration:SetAttribute("MaxPointsPerPath", 3)
integration:SetAttribute("LegacyOverflowPolicy", "PreserveLegacyLevelsAndCalculateCashRefundCredit")
integration:SetAttribute("ProfileMigrationMode", "PreviewCopyOnly")
integration:SetAttribute("ShadowAttributePrefix", "V2Shadow")
integration:SetAttribute("LiveRatingOwner", "V1")
integration:SetAttribute("LivePhysicsOwner", "VehicleDynamicsModel_V1Compatible")
pass("Installed explicit disabled integration switches and migration policy")

for _, cockpit in pairs(stagedCockpits) do cockpit:SetAttribute("V2IntegrationReady", true); cockpit:SetAttribute("CatalogPublishReady", false) end
for _, module in pairs(stagedModules) do module:SetAttribute("V2IntegrationReady", true); module:SetAttribute("CatalogPublishReady", false) end
staging:SetAttribute("V2IntegrationReady", true)
staging:SetAttribute("CatalogPublishReady", false)
staging:SetAttribute("IntegrationSchemaVersion", "V2_PHASE7_INTEGRATED_SHADOW")
pass("Marked only the non-live staging catalogue as integration-ready, never publish-ready")

local profileOrder = { "bruiser_02", "bruiser_03", "bruiser_01", "bruiser_04", "bruiser_05", "bruiser_06" }
local expectedTier = { bruiser_02 = "E", bruiser_03 = "D", bruiser_01 = "C", bruiser_04 = "B", bruiser_05 = "A", bruiser_06 = "S" }
local expectedPI = { bruiser_02 = 200, bruiser_03 = 375, bruiser_01 = 525, bruiser_04 = 662, bruiser_05 = 787, bruiser_06 = 925 }
local stockOk = true
for _, cockpitId in ipairs(profileOrder) do
	local short = string.match(cockpitId, "(%d+)$")
	local modules = {
		stagedModules["MODULE_ENGINE_BRUISER_" .. short .. "_STANDARD"],
		stagedModules["MODULE_ENGINE_B_BRUISER_" .. short .. "_STANDARD"],
		stagedModules["MODULE_STABILISER_BRUISER_" .. short .. "_STANDARD"],
		stagedModules["MODULE_BOOST_BRUISER_" .. short .. "_STANDARD"],
	}
	local result = RuntimeV2.CalculateComponents(stagedCockpits[cockpitId], modules)
	if result.Overall.Tier ~= expectedTier[cockpitId] or math.abs(result.Overall.InternalPerformanceIndex - expectedPI[cockpitId]) > 3 then
		stockOk = false; fail(string.format("%s stock result %s %.2f", cockpitId, result.Overall.Tier, result.Overall.InternalPerformanceIndex))
	end
	print(string.format("%s SHADOW STOCK | %s | %s %.2f", PREFIX, cockpitId, result.Overall.Tier, result.Overall.InternalPerformanceIndex))
end
if stockOk then pass("Integrated runtime reproduces all six E-S stock targets") end

local standardOk = true
for moduleId, module in pairs(stagedModules) do
	if module:GetAttribute("VariantName") == "Standard" then
		local _, spent, capacity = UpgradeRuntime.NormalizeAllocation(module, { Output = 3, Velocity = 3 })
		if spent ~= 0 or capacity ~= 0 then standardOk = false; fail(moduleId .. " Standard module accepted upgrade points") end
	end
end
if standardOk then pass("Standard modules remain non-upgradable through the runtime API") end

local sample = stagedModules.MODULE_ENGINE_BRUISER_01_POWER
assert(sample, "Missing Viper Power engine sample")
local normalized, spent, capacity = UpgradeRuntime.NormalizeAllocation(sample, { Output = 9, Velocity = 9, Efficiency = 9, Unknown = 9 })
if spent == 6 and capacity == 6 and (normalized.Output or 0) <= 3 and (normalized.Velocity or 0) <= 3 and (normalized.Efficiency or 0) <= 3 then
	pass("Allocation normalization enforces six total points and three per path")
else fail("Allocation normalization did not enforce point caps") end

local sampleProfile = {
	Cash = 1000000,
	OwnedModuleInstances = {
		module_sample = { TemplateId = "MODULE_ENGINE_BRUISER_01_POWER", UpgradeLevels = { FuelInjection = 3, PowerConverter = 3, LightweightInternals = 3 } },
	},
}
local migrated, migrationReport = UpgradeRuntime.MigrateProfileCopy(sampleProfile, function(moduleId) return stagedModules[moduleId] end)
local migratedInstance = migrated.OwnedModuleInstances.module_sample
local _, migratedPoints = UpgradeRuntime.NormalizeAllocation(sample, migratedInstance.V2UpgradePoints)
if migratedPoints == 6 and migrationReport.RefundCredit > 0 and typeof(migratedInstance.V2LegacyUpgradeLevels) == "table" then
	pass("Legacy upgrades convert to six points while preserving originals and calculating overflow refund credit")
else fail("Legacy upgrade migration/refund policy failed") end

local schema = require(shared:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("PlayerProfileSchema"))
local safe, safeMessage = schema.AssertDataStoreSafe(migrated)
if safe then pass("Migrated V2 module-instance allocations are DataStore-safe") else fail("Migrated profile is not DataStore-safe: " .. tostring(safeMessage)) end

local purchaseProfile = {
	Cash = 1000000,
	OwnedModuleInstances = {
		module_purchase = { TemplateId = "MODULE_ENGINE_BRUISER_01_POWER", V2UpgradePoints = {} },
	},
}
local beforeCash = purchaseProfile.Cash
local purchaseOk, purchasePreview = UpgradeRuntime.PurchasePoint(purchaseProfile, "module_purchase", sample, "Efficiency", {})
if purchaseOk and purchaseProfile.Cash == beforeCash - purchasePreview.Cost and purchasePreview.Cost > 0 then
	pass("Isolated six-point purchase API returns a preview and deducts the configured next-point cost")
else fail("Isolated six-point purchase API failed") end

local compatibility = RuntimeV2.CompatibilityView(RuntimeV2.CalculateComponents(stagedCockpits.bruiser_01, {
	stagedModules.MODULE_ENGINE_BRUISER_01_STANDARD,
	stagedModules.MODULE_ENGINE_B_BRUISER_01_STANDARD,
	stagedModules.MODULE_STABILISER_BRUISER_01_STANDARD,
	stagedModules.MODULE_BOOST_BRUISER_01_STANDARD,
}))
if compatibility.Overall.Tier == "C" and typeof(compatibility.Headline.Acceleration) == "number"
	and typeof(compatibility.Driving.EngineOutput) == "number" and typeof(compatibility.DynamicsFactors.EngineOutput) == "number" then
	pass("Compatibility view exposes overall, headline, raw driving, and shared-curve physics contracts")
else fail("Compatibility view is incomplete") end

-- Preview the Power front engine inside a complete Viper build. An isolated
-- module against an otherwise zero-stat build can be PI-neutral because the
-- headline interaction layer correctly treats several empty factors as zero.
local previewBaseRaw = RuntimeV2.ReadComponentRaw(stagedCockpits.bruiser_01)
for _, supportingModule in ipairs({
	stagedModules.MODULE_ENGINE_B_BRUISER_01_STANDARD,
	stagedModules.MODULE_STABILISER_BRUISER_01_STANDARD,
	stagedModules.MODULE_BOOST_BRUISER_01_STANDARD,
}) do
	RuntimeV2.AddRaw(previewBaseRaw, UpgradeRuntime.ApplyToModuleRaw(supportingModule, {}))
end
local previewOk, preview = UpgradeRuntime.PreviewPoint(sample, {}, "Output", previewBaseRaw)
if previewOk and preview.Cost > 0 and preview.InternalPerformanceIndexGain > 0 then pass("Upgrade preview reports raw, price, and unrounded PI impact") else fail("Upgrade preview did not produce a positive PI impact") end

-- The V2-prefixed writes live in the isolated runtime module; the service only
-- schedules Runtime.WriteShadow. Audit the actual write owner, not the caller.
if string.find(runtimeModule.Source, "V2ShadowPerformanceIndex", 1, true)
	and not string.find(runtimeModule.Source, 'SetAttribute("PerformanceIndex"', 1, true)
	and not string.find(runtimeModule.Source, 'SetAttribute("Performance_', 1, true)
	and not string.find(shadowService.Source, 'SetAttribute("PerformanceIndex"', 1, true)
	and not string.find(shadowService.Source, 'SetAttribute("Performance_', 1, true) then
	pass("Shadow service writes only V2-prefixed diagnostics and cannot replace live rating/raw attributes")
else fail("Shadow service contains a live performance-attribute write") end

if liveDefinitions.Source == liveSources.Definitions and liveCalculator.Source == liveSources.Calculator
	and liveRuntime.Source == liveSources.Runtime and liveUpgradeRuntime.Source == liveSources.UpgradeRuntime
	and liveUpgradeDefinitions.Source == liveSources.UpgradeDefinitions then
	pass("All live V1 performance and upgrade sources remain byte-for-byte unchanged")
else fail("A live V1 performance/upgrade source changed") end

if #categories:GetDescendants() == liveCategoryCount then pass("Live vehicle catalogue hierarchy remains unchanged") else fail("Live vehicle catalogue hierarchy changed") end

if config:GetAttribute("RuntimeRatingEnabled") == false and config:GetAttribute("RuntimePhysicsEnabled") == false
	and config:GetAttribute("RuntimeUpgradePurchasesEnabled") == false and config:GetAttribute("RuntimeProfileMigrationEnabled") == false
	and config:GetAttribute("LiveCataloguePublishEnabled") == false then
	pass("All live V2 rating, physics, purchase, migration, and publication switches remain disabled")
else fail("A live V2 switch was enabled") end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
if failCount == 0 then
	print(PREFIX .. " EDIT INSTALL COMPLETE - Restart Play before testing so ModuleScript require caches are fresh.")
	print(PREFIX .. " PLAY TEST - Spawn a vehicle and confirm V2ShadowPerformanceIndex/Tier appear while PerformanceIndex/Tier and driving remain V1-owned.")
	print(PREFIX .. " NO LIVE MIGRATION - Do not move staged assets or enable any V2 switch. Refresh the Studio mirror and paste full Edit + Play Output into chat.")
else
	warn(PREFIX .. " BLOCKED - Do not continue to Phase 8. Copy the complete Output into chat.")
end
