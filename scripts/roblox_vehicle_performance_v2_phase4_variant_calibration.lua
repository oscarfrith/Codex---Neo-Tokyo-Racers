-- Neo Tokyo Racers - Vehicle Performance V2 Phase 4 variant calibration
-- Run once in the Roblox Studio Command Bar while NOT play-testing.
--
-- Adds shadow-only Standard/Lightweight/Power definitions for all four replaceable
-- component types across the six donor tiers and validates comparable PI value.
-- Does NOT change live vehicle/module assets, prices, ratings, physics, UI, or upgrades.
-- Creates no backup objects and performs no source text replacement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing Vehicle Performance V2 Phase 4")

local PREFIX = "[NTR Vehicle Performance V2 Phase 4]"
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
assert(schemaVersion == "V2_PHASE3_COMPONENT_ALLOCATION" or schemaVersion == "V2_PHASE4_VARIANT_CALIBRATION",
	"Confirmed Phase 3/4 config is missing")
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

local rawVariableOrder = {
	"TopSpeed", "EngineOutput", "Weight", "LateralGrip", "SteeringResponse", "HoverStability",
	"DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostForce", "BoostDuration",
	"BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce",
}
local profileOrder = { "bruiser_02", "bruiser_03", "bruiser_01", "bruiser_04", "bruiser_05", "bruiser_06" }
local componentOrder = { "Cockpit", "FrontEngine", "RearEngine", "Stabilisers", "Boost" }
local replaceableComponents = { "FrontEngine", "RearEngine", "Stabilisers", "Boost" }
local variantOrder = { "Standard", "Lightweight", "Power" }

local profiles = {}
for _, cockpitId in ipairs(profileOrder) do
	local profile = profileRoot:FindFirstChild(cockpitId)
	assert(profile and profile:IsA("Folder"), "Missing calibrated profile " .. cockpitId)
	local allocation = profile:FindFirstChild("ComponentAllocation")
	assert(allocation and allocation:IsA("Folder"), "Missing Phase 3 allocation for " .. cockpitId)
	for _, componentName in ipairs(componentOrder) do
		assert(allocation:FindFirstChild(componentName), cockpitId .. " is missing component " .. componentName)
	end
	profiles[cockpitId] = profile
end
pass("Confirmed all six Phase 3 component allocations")

local V2Definitions = require(definitionsV2)
local lowerIsBetter = {}
for _, variableName in ipairs(rawVariableOrder) do lowerIsBetter[variableName] = V2Definitions.GetCurve(variableName).LowerIsBetter == true end

local function highMultiplier(componentName, variantName)
	if variantName == "Standard" then return 1 end
	if variantName == "Power" then return 1.10 end
	if componentName == "Boost" then return 1.03 end
	return 1.08
end

local function lowMultiplier(variantName)
	if variantName == "Lightweight" then return 0.88 end
	if variantName == "Power" then return 1.04 end
	return 1
end

-- Preflight completed. Config-only mutation begins here.
config:SetAttribute("SchemaVersion", "V2_PHASE4_VARIANT_CALIBRATION")
config:SetAttribute("SourceSheetRevision", "NTR-BAL-005-P4")
config:SetAttribute("ShadowOnly", true)
config:SetAttribute("RuntimeRatingEnabled", false)
config:SetAttribute("RuntimePhysicsEnabled", false)
config:SetAttribute("TuningNote", "Lightweight and Power base variants are calibrated as similarly valuable choices. Upgrade paths and live assets remain deferred.")

local policy = ensureFolder(config, "VariantPolicy")
policy:SetAttribute("SchemaVersion", "V2_PHASE4_VARIANT_CALIBRATION")
policy:SetAttribute("LightweightEngineHigherMultiplier", 1.08)
policy:SetAttribute("LightweightStabilisersHigherMultiplier", 1.08)
policy:SetAttribute("LightweightBoostHigherMultiplier", 1.03)
policy:SetAttribute("LightweightLowerBetterMultiplier", 0.88)
policy:SetAttribute("PowerHigherMultiplier", 1.10)
policy:SetAttribute("PowerLowerBetterMultiplier", 1.04)
policy:SetAttribute("VariantPriceCockpitFraction", 0.12)
policy:SetAttribute("UpgradePointCapacity", 6)
policy:SetAttribute("UpgradePathsDefined", false)

for _, cockpitId in ipairs(profileOrder) do
	local profile = profiles[cockpitId]
	local variantsRoot = ensureFolder(profile, "VariantDefinitions")
	variantsRoot:SetAttribute("SourceSheetRevision", "NTR-BAL-005-P4")
	variantsRoot:SetAttribute("ShadowOnly", true)
	local priceGuide = math.round((profile:GetAttribute("PriceGuide") or 0) * 0.12 / 100) * 100
	for _, componentName in ipairs(replaceableComponents) do
		local source = profile:WaitForChild("ComponentAllocation"):WaitForChild(componentName)
		local componentRoot = ensureFolder(variantsRoot, componentName)
		for _, variantName in ipairs(variantOrder) do
			local variant = ensureFolder(componentRoot, variantName)
			local high = highMultiplier(componentName, variantName)
			local low = lowMultiplier(variantName)
			variant:SetAttribute("Variant", variantName)
			variant:SetAttribute("ComponentType", componentName)
			variant:SetAttribute("SourceCockpitId", cockpitId)
			variant:SetAttribute("HigherBetterMultiplier", high)
			variant:SetAttribute("LowerBetterMultiplier", low)
			variant:SetAttribute("Upgradable", variantName ~= "Standard")
			variant:SetAttribute("UpgradePointCapacity", variantName == "Standard" and 0 or 6)
			variant:SetAttribute("PriceGuide", variantName == "Standard" and 0 or priceGuide)
			for _, variableName in ipairs(rawVariableOrder) do
				local multiplier = lowerIsBetter[variableName] and low or high
				variant:SetAttribute(variableName, source:GetAttribute(variableName) * multiplier)
			end
		end
	end
end
pass("Installed Standard, Lightweight, and Power shadow definitions for 24 donor components")

assert(liveDefinitions.Source == liveDefinitionsSource, "Live V1 definitions source changed unexpectedly")
assert(liveCalculator.Source == liveCalculatorSource, "Live V1 calculator source changed unexpectedly")
assert(liveRuntime.Source == liveRuntimeSource, "Live V1 runtime source changed unexpectedly")
pass("Live V1 definitions, calculator, and runtime sources were not changed")

local validationCalculator = calculatorV2:Clone()
validationCalculator.Name = "VehiclePerformanceV2Calculator_Phase4ValidationTemp"
validationCalculator.Parent = performance
local calculatorLoaded, V2Calculator = pcall(require, validationCalculator)
validationCalculator:Destroy()
assert(calculatorLoaded, "Fresh Phase 4 calculator validation load failed: " .. tostring(V2Calculator))

local function folderRaw(folder)
	local raw = {}
	for _, variableName in ipairs(rawVariableOrder) do raw[variableName] = folder:GetAttribute(variableName) end
	return raw
end

local function assembledRaw(profile, replacementComponent, replacementRaw)
	local raw = {}
	for _, variableName in ipairs(rawVariableOrder) do raw[variableName] = 0 end
	for _, componentName in ipairs(componentOrder) do
		local componentRaw
		if componentName == replacementComponent then
			componentRaw = replacementRaw
		else
			componentRaw = folderRaw(profile:WaitForChild("ComponentAllocation"):WaitForChild(componentName))
		end
		for _, variableName in ipairs(rawVariableOrder) do raw[variableName] += componentRaw[variableName] end
	end
	return raw
end

local balanceOk = true
print(PREFIX .. " --- NATIVE BUILD VARIANT GAINS (shadow only) ---")
for _, cockpitId in ipairs(profileOrder) do
	local profile = profiles[cockpitId]
	local stockRaw = assembledRaw(profile)
	local stockPI = V2Calculator.Calculate(stockRaw).Overall.InternalPerformanceIndex
	for _, componentName in ipairs(replaceableComponents) do
		local componentVariants = profile:WaitForChild("VariantDefinitions"):WaitForChild(componentName)
		local standard = componentVariants:WaitForChild("Standard")
		local lightweight = componentVariants:WaitForChild("Lightweight")
		local power = componentVariants:WaitForChild("Power")
		for _, variableName in ipairs(rawVariableOrder) do
			local allocated = profile:WaitForChild("ComponentAllocation"):WaitForChild(componentName)
			if math.abs(standard:GetAttribute(variableName) - allocated:GetAttribute(variableName)) > 0.000001 then
				balanceOk = false
				fail(cockpitId .. " Standard variant changed " .. componentName .. "." .. variableName)
			end
		end
		local lightweightPI = V2Calculator.Calculate(assembledRaw(profile, componentName, folderRaw(lightweight))).Overall.InternalPerformanceIndex
		local powerPI = V2Calculator.Calculate(assembledRaw(profile, componentName, folderRaw(power))).Overall.InternalPerformanceIndex
		local lightweightGain = lightweightPI - stockPI
		local powerGain = powerPI - stockPI
		local difference = math.abs(lightweightGain - powerGain)
		if lightweightGain <= 0 or powerGain <= 0 or difference > 1.5 then
			balanceOk = false
			fail(string.format("%s %s variants not comparably valuable: Lightweight +%.2f, Power +%.2f", cockpitId, componentName, lightweightGain, powerGain))
		end
		if lightweight:GetAttribute("UpgradePointCapacity") ~= 6 or power:GetAttribute("UpgradePointCapacity") ~= 6
			or standard:GetAttribute("UpgradePointCapacity") ~= 0 then
			balanceOk = false
			fail(cockpitId .. " " .. componentName .. " has an invalid upgrade-point capacity")
		end
		print(string.format("%s VARIANT | %s %s | stock %.2f | Lightweight +%.2f | Power +%.2f | difference %.2f",
			PREFIX, cockpitId, componentName, stockPI, lightweightGain, powerGain, difference))
	end
end
if balanceOk then pass("All 48 non-Standard variants improve PI and each Lightweight/Power pair is within 1.5 PI") end

local forge = profiles.bruiser_02
local laddersOk = true
for _, componentName in ipairs(replaceableComponents) do
	for _, variantName in ipairs({ "Lightweight", "Power" }) do
		local previousPI = -math.huge
		local line = {}
		for _, donorId in ipairs(profileOrder) do
			local donor = profiles[donorId]:WaitForChild("VariantDefinitions"):WaitForChild(componentName):WaitForChild(variantName)
			local pi = V2Calculator.Calculate(assembledRaw(forge, componentName, folderRaw(donor))).Overall.InternalPerformanceIndex
			table.insert(line, profiles[donorId]:GetAttribute("TargetTier") .. string.format(" %.2f", pi))
			if pi + 0.01 < previousPI then
				laddersOk = false
				fail(componentName .. " " .. variantName .. " donor ladder decreased at " .. donorId)
			end
			previousPI = pi
		end
		print(PREFIX .. " LADDER | Forge + " .. componentName .. " " .. variantName .. " donor: " .. table.concat(line, " -> "))
	end
end
if laddersOk then pass("All eight Lightweight/Power donor ladders increase monotonically from E to S") end

if #categories:GetDescendants() == assetDescendantCount then
	pass("Live vehicle/module asset hierarchy was not changed")
else
	fail("Live vehicle/module asset hierarchy changed unexpectedly")
end

if config:GetAttribute("RuntimeRatingEnabled") ~= false or config:GetAttribute("RuntimePhysicsEnabled") ~= false then
	fail("A V2 runtime switch is unexpectedly enabled")
else
	pass("V2 rating and physics runtime switches remain disabled")
end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
if failCount == 0 then
	print(PREFIX .. " INSTALLED IN SHADOW - Base variants and six-point capacity are ready for upgrade-path calibration.")
	print(PREFIX .. " NEXT - Refresh the Studio mirror and copy the full Output into chat before defining point paths or changing live module assets.")
else
	warn(PREFIX .. " BLOCKED - Do not define upgrade paths, create Zenith assets, change live modules, or enable V2 runtime. Copy the full Output into chat.")
end
