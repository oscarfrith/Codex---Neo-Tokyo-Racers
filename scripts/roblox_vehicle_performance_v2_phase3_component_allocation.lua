-- Neo Tokyo Racers - Vehicle Performance V2 Phase 3 component allocation
-- Run once in the Roblox Studio Command Bar while NOT play-testing.
--
-- Splits each calibrated complete-stock shadow profile across its cockpit,
-- front engine, rear engine, stabilisers, and boost module.
-- Does NOT change live vehicle/module assets, prices, ratings, physics, UI, or upgrades.
-- Creates no backup objects and performs no source text replacement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing Vehicle Performance V2 Phase 3")

local PREFIX = "[NTR Vehicle Performance V2 Phase 3]"
local passCount, warnCount, failCount = 0, 0, 0

local function pass(message)
	passCount += 1
	print(PREFIX .. " PASS - " .. message)
end

local function caution(message)
	warnCount += 1
	warn(PREFIX .. " WARN - " .. message)
end

local function fail(message)
	failCount += 1
	warn(PREFIX .. " FAIL - " .. message)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("Folder"), item:GetFullName() .. " must be a Folder")
		return item
	end
	item = Instance.new("Folder")
	item.Name = name
	item.Parent = parent
	return item
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local config = shared:WaitForChild("Config"):WaitForChild("VehiclePerformanceV2_EditAttributes")
local performance = shared:WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local definitionsV2 = performance:WaitForChild("VehiclePerformanceV2Definitions")
local calculatorV2 = performance:WaitForChild("VehiclePerformanceV2Calculator")
local profileRoot = config:WaitForChild("BalancedStockProfiles")
local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")

local schemaVersion = config:GetAttribute("SchemaVersion")
assert(schemaVersion == "V2_PHASE2_CALIBRATION" or schemaVersion == "V2_PHASE3_COMPONENT_ALLOCATION",
	"Confirmed Phase 2/3 config is missing")
assert(config:GetAttribute("RuntimeRatingEnabled") == false, "V2 RuntimeRatingEnabled must remain false")
assert(config:GetAttribute("RuntimePhysicsEnabled") == false, "V2 RuntimePhysicsEnabled must remain false")
assert(string.find(calculatorV2.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE2_PERFORMANCE_ORIGIN", 1, true), "Phase 2 calculator marker is missing")

local liveDefinitions = performance:WaitForChild("VehiclePerformanceDefinitions")
local liveCalculator = performance:WaitForChild("VehiclePerformanceCalculator")
local liveRuntime = performance:WaitForChild("VehiclePerformanceRuntime")
local liveDefinitionsSource = liveDefinitions.Source
local liveCalculatorSource = liveCalculator.Source
local liveRuntimeSource = liveRuntime.Source

local assetDescendantCount = #categories:GetDescendants()
local cockpitCount, moduleCount = 0, 0
for _, item in ipairs(categories:GetDescendants()) do
	if item:IsA("Model") and typeof(item:GetAttribute("CockpitId")) == "string" then cockpitCount += 1 end
	if item:IsA("Model") and typeof(item:GetAttribute("ModuleId")) == "string" and item:GetAttribute("RetiredFromCatalog") ~= true then moduleCount += 1 end
end

local rawVariableOrder = {
	"TopSpeed", "EngineOutput", "Weight", "LateralGrip", "SteeringResponse", "HoverStability",
	"DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostForce", "BoostDuration",
	"BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce",
}
local profileOrder = { "bruiser_02", "bruiser_03", "bruiser_01", "bruiser_04", "bruiser_05", "bruiser_06" }
local componentOrder = { "Cockpit", "FrontEngine", "RearEngine", "Stabilisers", "Boost" }
local replaceableComponents = { "FrontEngine", "RearEngine", "Stabilisers", "Boost" }

local function shares(variableName)
	if variableName == "TopSpeed" or variableName == "EngineOutput" then
		return { 0.35, 0.325, 0.325, 0, 0 }
	elseif variableName == "Weight" then
		return { 0.70, 0.10, 0.10, 0.05, 0.05 }
	elseif variableName == "Drag" then
		return { 0.70, 0, 0, 0.15, 0.15 }
	elseif variableName == "BoostForce" or variableName == "BoostDuration" or variableName == "BoostRecharge"
		or variableName == "BoostRechargeDelay" or variableName == "BoostEfficiency" then
		return { 0.35, 0, 0, 0, 0.65 }
	else
		return { 0.35, 0, 0, 0.65, 0 }
	end
end

local profiles = {}
for _, cockpitId in ipairs(profileOrder) do
	local profile = profileRoot:FindFirstChild(cockpitId)
	assert(profile and profile:IsA("Folder"), "Missing calibrated profile " .. cockpitId)
	profiles[cockpitId] = profile
	for _, variableName in ipairs(rawVariableOrder) do
		assert(typeof(profile:GetAttribute(variableName)) == "number", cockpitId .. " is missing " .. variableName)
	end
end
pass("Confirmed six Phase 2 profiles and all 17 raw variables")

-- Preflight completed. Config-only mutation begins here.
config:SetAttribute("SchemaVersion", "V2_PHASE3_COMPONENT_ALLOCATION")
config:SetAttribute("SourceSheetRevision", "NTR-BAL-004-P3")
config:SetAttribute("ShadowOnly", true)
config:SetAttribute("RuntimeRatingEnabled", false)
config:SetAttribute("RuntimePhysicsEnabled", false)
config:SetAttribute("TuningNote", "Complete-stock V2 totals are split across cockpit and four replaceable standard modules. Live assets remain V1.")

local policy = ensureFolder(config, "ComponentAllocationPolicy")
policy:SetAttribute("SchemaVersion", "V2_PHASE3_COMPONENT_ALLOCATION")
policy:SetAttribute("CockpitGeneralShare", 0.35)
policy:SetAttribute("EngineSharePerSlot", 0.325)
policy:SetAttribute("HandlingStabiliserShare", 0.65)
policy:SetAttribute("BoostModuleShare", 0.65)
policy:SetAttribute("StandardModulesUpgradable", false)
policy:SetAttribute("StandardModuleUpgradePointCapacity", 0)

for _, cockpitId in ipairs(profileOrder) do
	local profile = profiles[cockpitId]
	local allocation = ensureFolder(profile, "ComponentAllocation")
	allocation:SetAttribute("SourceSheetRevision", "NTR-BAL-004-P3")
	allocation:SetAttribute("ShadowOnly", true)
	for componentIndex, componentName in ipairs(componentOrder) do
		local component = ensureFolder(allocation, componentName)
		component:SetAttribute("ComponentType", componentName)
		component:SetAttribute("SourceCockpitId", cockpitId)
		component:SetAttribute("Variant", "Standard")
		component:SetAttribute("Upgradable", false)
		component:SetAttribute("UpgradePointCapacity", 0)
		for _, variableName in ipairs(rawVariableOrder) do
			local variableShares = shares(variableName)
			component:SetAttribute(variableName, profile:GetAttribute(variableName) * variableShares[componentIndex])
		end
	end
end
pass("Installed five-component Standard allocation folders for all six shadow profiles")

assert(liveDefinitions.Source == liveDefinitionsSource, "Live V1 definitions source changed unexpectedly")
assert(liveCalculator.Source == liveCalculatorSource, "Live V1 calculator source changed unexpectedly")
assert(liveRuntime.Source == liveRuntimeSource, "Live V1 runtime source changed unexpectedly")
pass("Live V1 definitions, calculator, and runtime sources were not changed")

local V2Definitions = require(definitionsV2)
local validationCalculator = calculatorV2:Clone()
validationCalculator.Name = "VehiclePerformanceV2Calculator_Phase3ValidationTemp"
validationCalculator.Parent = performance
local calculatorLoaded, V2Calculator = pcall(require, validationCalculator)
validationCalculator:Destroy()
assert(calculatorLoaded, "Fresh Phase 3 calculator validation load failed: " .. tostring(V2Calculator))

local function componentMap(profile, componentName)
	local component = profile:WaitForChild("ComponentAllocation"):WaitForChild(componentName)
	local raw = {}
	for _, variableName in ipairs(rawVariableOrder) do raw[variableName] = component:GetAttribute(variableName) end
	return raw
end

local function assembledRaw(profile, replacements)
	local raw = {}
	for _, variableName in ipairs(rawVariableOrder) do raw[variableName] = 0 end
	for _, componentName in ipairs(componentOrder) do
		local component = replacements and replacements[componentName] or componentMap(profile, componentName)
		if not component then component = componentMap(profile, componentName) end
		for _, variableName in ipairs(rawVariableOrder) do raw[variableName] += component[variableName] end
	end
	return raw
end

local allRecombined = true
print(PREFIX .. " --- RECOMBINED STOCK RESULTS (shadow only) ---")
for _, cockpitId in ipairs(profileOrder) do
	local profile = profiles[cockpitId]
	local raw = assembledRaw(profile)
	for _, variableName in ipairs(rawVariableOrder) do
		local expected = profile:GetAttribute(variableName)
		if math.abs(raw[variableName] - expected) > 0.000001 then
			allRecombined = false
			fail(cockpitId .. " component sum does not match " .. variableName)
		end
	end
	local result = V2Calculator.Calculate(raw)
	local targetTier = profile:GetAttribute("TargetTier")
	local targetPI = profile:GetAttribute("TargetPI")
	local gap = result.Overall.InternalPerformanceIndex - targetPI
	if result.Overall.Tier ~= targetTier or math.abs(gap) > 3 then
		allRecombined = false
		fail(string.format("%s recombined to %s %.2f instead of %s %d", cockpitId, result.Overall.Tier, result.Overall.InternalPerformanceIndex, targetTier, targetPI))
	end
	print(string.format("%s STOCK | %s | %s %d (internal %.2f) | target %s %d | gap %+.2f",
		PREFIX, cockpitId, result.Overall.Tier, result.Overall.PerformanceIndex,
		result.Overall.InternalPerformanceIndex, targetTier, targetPI, gap))
end
if allRecombined then pass("All 102 component sums reproduce the six calibrated stock profiles and target tiers") end

local forge = profiles.bruiser_02
local forgeBase = V2Calculator.Calculate(assembledRaw(forge)).Overall.InternalPerformanceIndex
local moduleLaddersOk = true
for _, componentName in ipairs(replaceableComponents) do
	local previousPI = forgeBase
	local line = { componentName .. string.format(" E %.2f", previousPI) }
	for profileIndex = 2, #profileOrder do
		local donorId = profileOrder[profileIndex]
		local donorComponent = componentMap(profiles[donorId], componentName)
		local result = V2Calculator.Calculate(assembledRaw(forge, { [componentName] = donorComponent }))
		local pi = result.Overall.InternalPerformanceIndex
		table.insert(line, profiles[donorId]:GetAttribute("TargetTier") .. string.format(" %.2f", pi))
		if pi + 0.01 < previousPI then
			moduleLaddersOk = false
			fail(componentName .. " donor ladder decreased at " .. donorId)
		end
		previousPI = pi
	end
	if previousPI <= forgeBase then
		moduleLaddersOk = false
		fail(componentName .. " S-tier donor did not improve the Forge")
	end
	print(PREFIX .. " SWAP | Forge with donor " .. table.concat(line, " -> "))
end
if moduleLaddersOk then pass("Every replaceable Standard module becomes more effective across the E-S donor ladder") end

if #categories:GetDescendants() == assetDescendantCount and cockpitCount == 5 and moduleCount == 72 then
	pass("Live asset hierarchy remains unchanged at 5 cockpits and 72 active modules")
else
	caution(string.format("Asset counts were not the expected unchanged 5/72 baseline (cockpits=%d modules=%d descendants=%d->%d)",
		cockpitCount, moduleCount, assetDescendantCount, #categories:GetDescendants()))
end

if config:GetAttribute("RuntimeRatingEnabled") ~= false or config:GetAttribute("RuntimePhysicsEnabled") ~= false then
	fail("A V2 runtime switch is unexpectedly enabled")
else
	pass("V2 rating and physics runtime switches remain disabled")
end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
if failCount == 0 then
	print(PREFIX .. " INSTALLED IN SHADOW - Component ownership and cross-tier Standard module strength are ready for variant calibration.")
	print(PREFIX .. " NEXT - Refresh the Studio mirror and copy the full Output into chat before creating Zenith assets or changing live stats.")
else
	warn(PREFIX .. " BLOCKED - Do not create Zenith assets, assign live stats, or enable V2 runtime. Copy the full Output into chat.")
end
