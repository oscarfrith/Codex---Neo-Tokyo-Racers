-- Neo Tokyo Racers - Vehicle Performance V2 Phase 5 six-point upgrade paths
-- Run once in the Roblox Studio Command Bar while NOT play-testing.
--
-- Adds three shadow-only upgrade paths to every Lightweight/Power engine,
-- stabiliser, and boost definition. Each path accepts three points; a module
-- may spend six points total, so a completed build chooses two paths or mixes all three.
-- Does NOT change live module assets, live upgrades, prices, ratings, physics, or UI.
-- Creates no backup objects and performs no source text replacement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing Vehicle Performance V2 Phase 5")

local PREFIX = "[NTR Vehicle Performance V2 Phase 5]"
local passCount, warnCount, failCount = 0, 0, 0

local function pass(message)
	passCount += 1
	print(PREFIX .. " PASS - " .. message)
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
local calculatorV2 = performance:WaitForChild("VehiclePerformanceV2Calculator")
local profileRoot = config:WaitForChild("BalancedStockProfiles")
local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")

local schemaVersion = config:GetAttribute("SchemaVersion")
assert(schemaVersion == "V2_PHASE4_VARIANT_CALIBRATION" or schemaVersion == "V2_PHASE5_UPGRADE_PATHS",
	"Confirmed Phase 4/5 config is missing")
assert(config:GetAttribute("RuntimeRatingEnabled") == false, "V2 RuntimeRatingEnabled must remain false")
assert(config:GetAttribute("RuntimePhysicsEnabled") == false, "V2 RuntimePhysicsEnabled must remain false")

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
local upgradableVariants = { "Lightweight", "Power" }
local pointCostFractions = { 0.08, 0.10, 0.12, 0.15, 0.18, 0.22 }
local pointFraction = 0.03

local pathDefinitions = {
	FrontEngine = {
		{ Id = "Velocity", DisplayName = "Velocity", Deltas = { TopSpeed = 0.03 } },
		{ Id = "Output", DisplayName = "Output", Deltas = { EngineOutput = 0.03 } },
		{ Id = "Efficiency", DisplayName = "Efficiency", Deltas = { Weight = -0.03, EngineOutput = 0.015 } },
	},
	RearEngine = {
		{ Id = "Velocity", DisplayName = "Velocity", Deltas = { TopSpeed = 0.03 } },
		{ Id = "Output", DisplayName = "Output", Deltas = { EngineOutput = 0.03 } },
		{ Id = "Efficiency", DisplayName = "Efficiency", Deltas = { Weight = -0.03, EngineOutput = 0.015 } },
	},
	Stabilisers = {
		{ Id = "Grip", DisplayName = "Grip", Deltas = { LateralGrip = 0.03, BrakingForce = 0.03, Downforce = 0.03 } },
		{ Id = "Response", DisplayName = "Response", Deltas = { SteeringResponse = 0.03, HoverStability = 0.03 } },
		{ Id = "Drift", DisplayName = "Drift", Deltas = { DriftControl = 0.03, DriftGrip = 0.03, DriftChargeRate = 0.03, Drag = -0.03 } },
	},
	Boost = {
		{ Id = "Burst", DisplayName = "Burst", Deltas = { BoostForce = 0.03 } },
		{ Id = "Endurance", DisplayName = "Endurance", Deltas = { BoostDuration = 0.03, BoostEfficiency = 0.03 } },
		{ Id = "Recovery", DisplayName = "Recovery", Deltas = { BoostRecharge = -0.03, BoostRechargeDelay = -0.03, Drag = -0.03 } },
	},
}

local profiles = {}
for _, cockpitId in ipairs(profileOrder) do
	local profile = profileRoot:FindFirstChild(cockpitId)
	assert(profile and profile:IsA("Folder"), "Missing calibrated profile " .. cockpitId)
	local variants = profile:FindFirstChild("VariantDefinitions")
	assert(variants and variants:IsA("Folder"), "Missing Phase 4 variants for " .. cockpitId)
	for _, componentName in ipairs(replaceableComponents) do
		local component = variants:FindFirstChild(componentName)
		assert(component, cockpitId .. " is missing variant component " .. componentName)
		assert(component:FindFirstChild("Standard"), cockpitId .. " is missing Standard " .. componentName)
		for _, variantName in ipairs(upgradableVariants) do
			assert(component:FindFirstChild(variantName), cockpitId .. " is missing " .. variantName .. " " .. componentName)
		end
	end
	profiles[cockpitId] = profile
end
pass("Confirmed all six Phase 4 variant catalogues")

-- Preflight completed. Config-only mutation begins here.
config:SetAttribute("SchemaVersion", "V2_PHASE5_UPGRADE_PATHS")
config:SetAttribute("SourceSheetRevision", "NTR-BAL-006-P5")
config:SetAttribute("ShadowOnly", true)
config:SetAttribute("RuntimeRatingEnabled", false)
config:SetAttribute("RuntimePhysicsEnabled", false)
config:SetAttribute("TuningNote", "Lightweight and Power modules have three three-point paths with six total points. Live upgrade/runtime migration remains deferred.")

local policy = ensureFolder(config, "VariantPolicy")
policy:SetAttribute("SchemaVersion", "V2_PHASE5_UPGRADE_PATHS")
policy:SetAttribute("UpgradePathsDefined", true)
policy:SetAttribute("UpgradePointCapacity", 6)
policy:SetAttribute("MaxPointsPerPath", 3)
policy:SetAttribute("PerPointRawFraction", pointFraction)
policy:SetAttribute("UpgradeCostBasis", "Total points spent on module")
for point, fraction in ipairs(pointCostFractions) do
	policy:SetAttribute("Point" .. point .. "CostFraction", fraction)
end

for _, cockpitId in ipairs(profileOrder) do
	local profile = profiles[cockpitId]
	local variantsRoot = profile:WaitForChild("VariantDefinitions")
	variantsRoot:SetAttribute("SourceSheetRevision", "NTR-BAL-006-P5")
	local priceGuide = math.round((profile:GetAttribute("PriceGuide") or 0) * 0.12 / 100) * 100
	for _, componentName in ipairs(replaceableComponents) do
		local component = variantsRoot:WaitForChild(componentName)
		local standard = component:WaitForChild("Standard")
		standard:SetAttribute("UpgradePointCapacity", 0)
		local staleStandardPaths = standard:FindFirstChild("UpgradePaths")
		if staleStandardPaths then staleStandardPaths:Destroy() end
		for _, variantName in ipairs(upgradableVariants) do
			local variant = component:WaitForChild(variantName)
			variant:SetAttribute("UpgradePointCapacity", 6)
			variant:SetAttribute("MaxPointsPerPath", 3)
			for point, fraction in ipairs(pointCostFractions) do
				variant:SetAttribute("Point" .. point .. "CostGuide", math.max(100, math.round(priceGuide * fraction / 100) * 100))
			end
			local pathsRoot = ensureFolder(variant, "UpgradePaths")
			for _, existing in ipairs(pathsRoot:GetChildren()) do existing:Destroy() end
			for _, definition in ipairs(pathDefinitions[componentName]) do
				local path = ensureFolder(pathsRoot, definition.Id)
				path:SetAttribute("PathId", definition.Id)
				path:SetAttribute("DisplayName", definition.DisplayName)
				path:SetAttribute("MaxPoints", 3)
				path:SetAttribute("PerPointRawFraction", pointFraction)
				for variableName, delta in pairs(definition.Deltas) do
					path:SetAttribute("DeltaFraction_" .. variableName, delta)
				end
			end
		end
	end
end
pass("Installed three shadow paths and six point-cost guides on all 48 upgradable variants")

assert(liveDefinitions.Source == liveDefinitionsSource, "Live V1 definitions source changed unexpectedly")
assert(liveCalculator.Source == liveCalculatorSource, "Live V1 calculator source changed unexpectedly")
assert(liveRuntime.Source == liveRuntimeSource, "Live V1 runtime source changed unexpectedly")
pass("Live V1 definitions, calculator, and runtime sources were not changed")

local validationCalculator = calculatorV2:Clone()
validationCalculator.Name = "VehiclePerformanceV2Calculator_Phase5ValidationTemp"
validationCalculator.Parent = performance
local calculatorLoaded, V2Calculator = pcall(require, validationCalculator)
validationCalculator:Destroy()
assert(calculatorLoaded, "Fresh Phase 5 calculator validation load failed: " .. tostring(V2Calculator))

local function folderRaw(folder)
	local raw = {}
	for _, variableName in ipairs(rawVariableOrder) do raw[variableName] = folder:GetAttribute(variableName) end
	return raw
end

local function upgradedRaw(variant, pointsByPath)
	local raw = folderRaw(variant)
	for pathId, points in pairs(pointsByPath) do
		local path = variant:WaitForChild("UpgradePaths"):WaitForChild(pathId)
		for _, variableName in ipairs(rawVariableOrder) do
			local delta = path:GetAttribute("DeltaFraction_" .. variableName)
			if delta then raw[variableName] *= 1 + delta * points end
		end
	end
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

local pathsOk = true
local fullBuildsOk = true
print(PREFIX .. " --- NATIVE BUILD UPGRADE GAINS (shadow only) ---")
for _, cockpitId in ipairs(profileOrder) do
	local profile = profiles[cockpitId]
	for _, componentName in ipairs(replaceableComponents) do
		for _, variantName in ipairs(upgradableVariants) do
			local variant = profile:WaitForChild("VariantDefinitions"):WaitForChild(componentName):WaitForChild(variantName)
			local basePI = V2Calculator.Calculate(assembledRaw(profile, componentName, folderRaw(variant))).Overall.InternalPerformanceIndex
			local pathGains = {}
			local definitions = pathDefinitions[componentName]
			for _, definition in ipairs(definitions) do
				local previousPI = basePI
				local gains = {}
				for points = 1, 3 do
					local pi = V2Calculator.Calculate(assembledRaw(profile, componentName, upgradedRaw(variant, { [definition.Id] = points }))).Overall.InternalPerformanceIndex
					table.insert(gains, pi - basePI)
					if pi <= previousPI then
						pathsOk = false
						fail(string.format("%s %s %s %s point %d did not improve PI", cockpitId, componentName, variantName, definition.Id, points))
					end
					previousPI = pi
				end
				table.insert(pathGains, string.format("%s +%.2f/+%.2f/+%.2f", definition.Id, gains[1], gains[2], gains[3]))
			end
			local minFullGain, maxFullGain = math.huge, -math.huge
			for first = 1, #definitions - 1 do
				for second = first + 1, #definitions do
					local points = { [definitions[first].Id] = 3, [definitions[second].Id] = 3 }
					local fullPI = V2Calculator.Calculate(assembledRaw(profile, componentName, upgradedRaw(variant, points))).Overall.InternalPerformanceIndex
					local gain = fullPI - basePI
					minFullGain = math.min(minFullGain, gain)
					maxFullGain = math.max(maxFullGain, gain)
					if gain <= 0 then
						fullBuildsOk = false
						fail(string.format("%s %s %s full six-point pairing did not improve PI", cockpitId, componentName, variantName))
					end
				end
			end
			print(string.format("%s UPGRADE | %s %s %s | %s | full-six +%.2f to +%.2f",
				PREFIX, cockpitId, componentName, variantName, table.concat(pathGains, " | "), minFullGain, maxFullGain))
		end
	end
end
if pathsOk then pass("Every path point 1-3 increases native-build PI across all 48 upgradable variants") end
if fullBuildsOk then pass("Every two-path six-point allocation increases native-build PI") end

local diminishingOk = true
local forge = profiles.bruiser_02
local zenith = profiles.bruiser_06
for _, componentName in ipairs(replaceableComponents) do
	for _, variantName in ipairs(upgradableVariants) do
		local forgeVariant = forge:WaitForChild("VariantDefinitions"):WaitForChild(componentName):WaitForChild(variantName)
		local zenithVariant = zenith:WaitForChild("VariantDefinitions"):WaitForChild(componentName):WaitForChild(variantName)
		local forgeBasePI = V2Calculator.Calculate(assembledRaw(forge, componentName, folderRaw(forgeVariant))).Overall.InternalPerformanceIndex
		local zenithBasePI = V2Calculator.Calculate(assembledRaw(zenith, componentName, folderRaw(zenithVariant))).Overall.InternalPerformanceIndex
		for _, definition in ipairs(pathDefinitions[componentName]) do
			local forgePI = V2Calculator.Calculate(assembledRaw(forge, componentName, upgradedRaw(forgeVariant, { [definition.Id] = 1 }))).Overall.InternalPerformanceIndex
			local zenithPI = V2Calculator.Calculate(assembledRaw(zenith, componentName, upgradedRaw(zenithVariant, { [definition.Id] = 1 }))).Overall.InternalPerformanceIndex
			local forgeGain = forgePI - forgeBasePI
			local zenithGain = zenithPI - zenithBasePI
			if forgeGain <= zenithGain then
				diminishingOk = false
				fail(string.format("Diminishing PI check failed for %s %s %s: Forge +%.2f, Zenith +%.2f",
					componentName, variantName, definition.Id, forgeGain, zenithGain))
			end
		end
	end
end
if diminishingOk then pass("The same first path point gains less native-build PI at S than at E") end

local costOk = true
for _, cockpitId in ipairs(profileOrder) do
	local example = profiles[cockpitId]:WaitForChild("VariantDefinitions"):WaitForChild("FrontEngine"):WaitForChild("Lightweight")
	local previousCost, totalCost = 0, 0
	local costs = {}
	for point = 1, 6 do
		local cost = example:GetAttribute("Point" .. point .. "CostGuide")
		totalCost += cost
		table.insert(costs, tostring(cost))
		if cost <= previousCost then
			costOk = false
			fail(cockpitId .. " point costs are not strictly increasing")
		end
		previousCost = cost
	end
	local modulePrice = example:GetAttribute("PriceGuide")
	if totalCost >= modulePrice then
		costOk = false
		fail(cockpitId .. " cumulative point cost should remain below the module guide price")
	end
	print(string.format("%s COST | %s %s module | points %s | total %d (%.1f%%)",
		PREFIX, cockpitId, tostring(modulePrice), table.concat(costs, "/"), totalCost, totalCost / modulePrice * 100))
end
if costOk then pass("Point costs rise by total points spent and preserve exponential donor-tier pricing") end

local standardOk = true
for _, cockpitId in ipairs(profileOrder) do
	for _, componentName in ipairs(replaceableComponents) do
		local standard = profiles[cockpitId]:WaitForChild("VariantDefinitions"):WaitForChild(componentName):WaitForChild("Standard")
		if standard:GetAttribute("UpgradePointCapacity") ~= 0 or standard:FindFirstChild("UpgradePaths") then
			standardOk = false
			fail(cockpitId .. " Standard " .. componentName .. " became upgradable")
		end
	end
end
if standardOk then pass("All Standard modules remain non-upgradable") end

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
	print(PREFIX .. " INSTALLED IN SHADOW - Six-point upgrade choices and tier-scaled cost guides are ready for economy/runtime migration planning.")
	print(PREFIX .. " NEXT - Refresh the Studio mirror and copy the full Output into chat before changing live upgrades, assets, prices, rating, physics, or UI.")
else
	warn(PREFIX .. " BLOCKED - Do not migrate live upgrades or enable V2 runtime. Copy the full Output into chat.")
end
