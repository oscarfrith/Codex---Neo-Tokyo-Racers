-- Neo Tokyo Racers - Vehicle Performance V2 Phase 6 asset materialisation staging
-- Run once in the Roblox Studio Command Bar while NOT play-testing.
--
-- Builds a non-live, publish-ready-to-inspect six-vehicle asset catalogue in
-- ServerStorage from the current Viper cockpit/module visuals and the confirmed
-- Phase 5 shadow values. It does NOT add anything to the live Categories folder,
-- enable V2 runtime, change garage discovery, or alter current prices/upgrades/UI.
-- This is intentional staging, not a backup. No source text replacement is used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing Vehicle Performance V2 Phase 6")

local PREFIX = "[NTR Vehicle Performance V2 Phase 6]"
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
local profileRoot = config:WaitForChild("BalancedStockProfiles")
local performance = shared:WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local calculatorV2 = performance:WaitForChild("VehiclePerformanceV2Calculator")
local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")

assert(config:GetAttribute("SchemaVersion") == "V2_PHASE5_UPGRADE_PATHS", "Confirmed Phase 5 config is missing")
assert(config:GetAttribute("RuntimeRatingEnabled") == false, "V2 RuntimeRatingEnabled must remain false")
assert(config:GetAttribute("RuntimePhysicsEnabled") == false, "V2 RuntimePhysicsEnabled must remain false")

local liveDefinitions = performance:WaitForChild("VehiclePerformanceDefinitions")
local liveCalculator = performance:WaitForChild("VehiclePerformanceCalculator")
local liveRuntime = performance:WaitForChild("VehiclePerformanceRuntime")
local liveDefinitionsSource = liveDefinitions.Source
local liveCalculatorSource = liveCalculator.Source
local liveRuntimeSource = liveRuntime.Source
local liveCategoryDescendantCount = #categories:GetDescendants()

local rawVariableOrder = {
	"TopSpeed", "EngineOutput", "Weight", "LateralGrip", "SteeringResponse", "HoverStability",
	"DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostForce", "BoostDuration",
	"BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce",
}
local profileOrder = { "bruiser_02", "bruiser_03", "bruiser_01", "bruiser_04", "bruiser_05", "bruiser_06" }
local componentOrder = { "Cockpit", "FrontEngine", "RearEngine", "Stabilisers", "Boost" }
local replaceableComponents = { "FrontEngine", "RearEngine", "Stabilisers", "Boost" }
local variantOrder = { "Standard", "Lightweight", "Power" }
local componentSpecs = {
	FrontEngine = { Folder = "Engines", DonorId = "MODULE_ENGINE_BRUISER_01_%s", TargetId = "MODULE_ENGINE_BRUISER_%s_%s", ModuleType = "Engine", Rear = false },
	RearEngine = { Folder = "Engines_B", DonorId = "MODULE_ENGINE_B_BRUISER_01_%s", TargetId = "MODULE_ENGINE_B_BRUISER_%s_%s", ModuleType = "Engine", Rear = true },
	Stabilisers = { Folder = "Stabilisers", DonorId = "MODULE_STABILISER_BRUISER_01_%s", TargetId = "MODULE_STABILISER_BRUISER_%s_%s", ModuleType = "Stabilisers", Rear = false },
	Boost = { Folder = "Boost", DonorId = "MODULE_BOOST_BRUISER_01_%s", TargetId = "MODULE_BOOST_BRUISER_%s_%s", ModuleType = "Boost", Rear = false },
}

local liveCategory
local viperCockpit
for _, category in ipairs(categories:GetChildren()) do
	local cockpitRoot = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
	if cockpitRoot then
		for _, item in ipairs(cockpitRoot:GetDescendants()) do
			if item:IsA("Model") and item:GetAttribute("CockpitId") == "bruiser_01" then
				liveCategory = category
				viperCockpit = item
				break
			end
		end
	end
	if viperCockpit then break end
end
assert(liveCategory and viperCockpit, "Could not find the live Viper cockpit/category")
local liveModuleRoot = liveCategory:WaitForChild("MODULES_InterchangeableWithinCategory")

local function findLiveModule(moduleId)
	for _, item in ipairs(liveModuleRoot:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("ModuleId") == moduleId then return item end
	end
	return nil
end

local donorModules = {}
for componentName, spec in pairs(componentSpecs) do
	donorModules[componentName] = {}
	for _, variantName in ipairs(variantOrder) do
		local moduleId = string.format(spec.DonorId, string.upper(variantName))
		local donor = findLiveModule(moduleId)
		assert(donor and donor:FindFirstChild("ModuleRoot_DoNotRename", true), "Missing Viper donor " .. moduleId)
		donorModules[componentName][variantName] = donor
	end
end
assert(viperCockpit:FindFirstChild("ASSET_ReplaceWithYourCockpitModel"), "Viper cockpit visual root is missing")
pass("Confirmed the current Viper cockpit and all 12 core module visual donors")

local profiles = {}
for _, cockpitId in ipairs(profileOrder) do
	local profile = profileRoot:FindFirstChild(cockpitId)
	assert(profile and profile:IsA("Folder"), "Missing profile " .. cockpitId)
	assert(profile:FindFirstChild("ComponentAllocation"), "Missing allocation for " .. cockpitId)
	assert(profile:FindFirstChild("VariantDefinitions"), "Missing variants for " .. cockpitId)
	profiles[cockpitId] = profile
end
pass("Confirmed all six Phase 5 source profiles")

-- Preflight completed. Only the generated ServerStorage staging root is mutated below.
local serverNtr = ensureFolder(ServerStorage, "NeoTokyoRacers")
local staging = serverNtr:FindFirstChild("VehiclePerformanceV2_Staging")
if staging then
	assert(staging:IsA("Folder"), staging:GetFullName() .. " must be a Folder")
	assert(staging:GetAttribute("GeneratedBy") == "NTR_VEHICLE_PERFORMANCE_V2_PHASE6",
		"Existing staging root is not owned by Phase 6; inspect it manually")
	staging:ClearAllChildren()
else
	staging = Instance.new("Folder")
	staging.Name = "VehiclePerformanceV2_Staging"
	staging.Parent = serverNtr
end
staging:SetAttribute("GeneratedBy", "NTR_VEHICLE_PERFORMANCE_V2_PHASE6")
staging:SetAttribute("SchemaVersion", "V2_PHASE6_ASSET_MATERIALISATION_STAGING")
staging:SetAttribute("SourceSheetRevision", "NTR-BAL-007-P6")
staging:SetAttribute("ShadowOnly", true)
staging:SetAttribute("CatalogPublishReady", false)
staging:SetAttribute("PublishBlocker", "Requires V2 runtime/garage compatibility gate before moving into live Categories")

local stagedCategory = ensureFolder(staging, liveCategory.Name)
stagedCategory:SetAttribute("SourceCategory", liveCategory.Name)
stagedCategory:SetAttribute("DisplayName", liveCategory:GetAttribute("DisplayName") or liveCategory.Name)
local stagedCockpitRoot = ensureFolder(stagedCategory, "COCKPITS_ReplaceAssetsHere")
local stagedModuleRoot = ensureFolder(stagedCategory, "MODULES_InterchangeableWithinCategory")
for _, spec in pairs(componentSpecs) do ensureFolder(stagedModuleRoot, spec.Folder) end

local stagedCockpits = {}
local stagedModules = {}
local stagedByBuild = {}
local seenCockpitIds = {}
local seenModuleIds = {}

local function copyRawAttributes(target, source)
	for _, variableName in ipairs(rawVariableOrder) do
		local value = source:GetAttribute(variableName)
		assert(typeof(value) == "number", source:GetFullName() .. " missing numeric " .. variableName)
		target:SetAttribute(variableName, value)
	end
end

local function cleanRuntimeFolders(cockpit)
	for _, name in ipairs({ "INSTALLED_MODULES_Runtime", "TOTAL_STATS_Runtime" }) do
		local folder = cockpit:FindFirstChild(name)
		if folder then folder:ClearAllChildren() end
	end
end

for _, cockpitId in ipairs(profileOrder) do
	local profile = profiles[cockpitId]
	local short = string.match(cockpitId, "(%d+)$")
	assert(short, "Could not derive module suffix from " .. cockpitId)
	local displayName = tostring(profile:GetAttribute("DisplayName") or cockpitId)
	local cockpit = viperCockpit:Clone()
	cockpit.Name = "COCKPIT_BRUISER_" .. short
	cockpit:SetAttribute("CockpitId", cockpitId)
	cockpit:SetAttribute("DisplayName", displayName)
	cockpit:SetAttribute("Price", profile:GetAttribute("PriceGuide") or 0)
	cockpit:SetAttribute("TargetTier", profile:GetAttribute("TargetTier"))
	cockpit:SetAttribute("TargetStockPI", profile:GetAttribute("TargetPI"))
	cockpit:SetAttribute("V2Materialised", true)
	cockpit:SetAttribute("V2SourceRevision", "NTR-BAL-007-P6")
	cockpit:SetAttribute("CatalogPublishReady", false)
	copyRawAttributes(cockpit, profile:WaitForChild("ComponentAllocation"):WaitForChild("Cockpit"))
	cleanRuntimeFolders(cockpit)
	cockpit:SetAttribute("DefaultEngineModuleId", "MODULE_ENGINE_BRUISER_" .. short .. "_STANDARD")
	cockpit:SetAttribute("DefaultFrontEngineModuleId", "MODULE_ENGINE_BRUISER_" .. short .. "_STANDARD")
	cockpit:SetAttribute("DefaultEngineBModuleId", "MODULE_ENGINE_B_BRUISER_" .. short .. "_STANDARD")
	cockpit:SetAttribute("DefaultRearEngineModuleId", "MODULE_ENGINE_B_BRUISER_" .. short .. "_STANDARD")
	cockpit:SetAttribute("DefaultStabiliserModuleId", "MODULE_STABILISER_BRUISER_" .. short .. "_STANDARD")
	cockpit:SetAttribute("DefaultStabilisersModuleId", "MODULE_STABILISER_BRUISER_" .. short .. "_STANDARD")
	cockpit:SetAttribute("DefaultBoostModuleId", "MODULE_BOOST_BRUISER_" .. short .. "_STANDARD")
	cockpit.Parent = stagedCockpitRoot
	stagedCockpits[cockpitId] = cockpit
	stagedByBuild[cockpitId] = { Cockpit = cockpit }
	if seenCockpitIds[cockpitId] then fail("Duplicate staged cockpit id " .. cockpitId) end
	seenCockpitIds[cockpitId] = true

	for _, componentName in ipairs(replaceableComponents) do
		local spec = componentSpecs[componentName]
		local family = ensureFolder(stagedModuleRoot:WaitForChild(spec.Folder), "Bruiser_" .. short)
		stagedByBuild[cockpitId][componentName] = {}
		for index, variantName in ipairs(variantOrder) do
			local sourceDefinition = profile:WaitForChild("VariantDefinitions"):WaitForChild(componentName):WaitForChild(variantName)
			local module = donorModules[componentName][variantName]:Clone()
			local moduleId = string.format(spec.TargetId, short, string.upper(variantName))
			module.Name = moduleId
			module:SetAttribute("ModuleId", moduleId)
			module:SetAttribute("DisplayName", displayName .. " " .. variantName .. " " .. (componentName == "FrontEngine" and "Front Engine" or componentName == "RearEngine" and "Rear Engine" or componentName))
			module:SetAttribute("ModuleName", module:GetAttribute("DisplayName"))
			module:SetAttribute("ModuleType", spec.ModuleType)
			module:SetAttribute("ModuleSlot", spec.ModuleType)
			module:SetAttribute("ModuleFolder", spec.Folder)
			module:SetAttribute("EnginePosition", componentName == "FrontEngine" and "Front" or componentName == "RearEngine" and "Rear" or "")
			module:SetAttribute("RearEngine", spec.Rear)
			module:SetAttribute("SourceCockpitId", cockpitId)
			module:SetAttribute("VariantName", variantName)
			module:SetAttribute("VariantOrder", index * 10)
			module:SetAttribute("Tier", variantName)
			module:SetAttribute("Price", sourceDefinition:GetAttribute("PriceGuide") or 0)
			module:SetAttribute("PurchasePrice", sourceDefinition:GetAttribute("PriceGuide") or 0)
			module:SetAttribute("Upgradable", variantName ~= "Standard")
			module:SetAttribute("UpgradePointCapacity", sourceDefinition:GetAttribute("UpgradePointCapacity") or 0)
			module:SetAttribute("V2Materialised", true)
			module:SetAttribute("V2SourceRevision", "NTR-BAL-007-P6")
			module:SetAttribute("CatalogPublishReady", false)
			module:SetAttribute("RetiredFromCatalog", true)
			copyRawAttributes(module, sourceDefinition)
			for point = 1, 6 do
				local cost = sourceDefinition:GetAttribute("Point" .. point .. "CostGuide")
				if cost ~= nil then module:SetAttribute("Point" .. point .. "CostGuide", cost) end
			end
			if variantName ~= "Standard" then
				local upgradePaths = Instance.new("Folder")
				upgradePaths.Name = "VehiclePerformanceV2UpgradePaths"
				upgradePaths.Parent = module
				for _, path in ipairs(sourceDefinition:WaitForChild("UpgradePaths"):GetChildren()) do
					path:Clone().Parent = upgradePaths
				end
			end
			module.Parent = family
			stagedModules[moduleId] = module
			stagedByBuild[cockpitId][componentName][variantName] = module
			if seenModuleIds[moduleId] then fail("Duplicate staged module id " .. moduleId) end
			seenModuleIds[moduleId] = true
		end
	end
end

if #stagedCockpitRoot:GetChildren() == 6 then pass("Materialised six staged cockpit models from the current Viper visual") else fail("Expected six staged cockpits") end

local stagedModuleCount = 0
for _ in pairs(stagedModules) do stagedModuleCount += 1 end
if stagedModuleCount == 72 then pass("Materialised 72 staged core module models from the 12 Viper donors") else fail("Expected 72 staged core modules, found " .. stagedModuleCount) end

local geometryOk = true
for cockpitId, cockpit in pairs(stagedCockpits) do
	if not cockpit:FindFirstChild("ASSET_ReplaceWithYourCockpitModel") or not cockpit:FindFirstChild("CockpitRoot_DoNotRename", true) then
		geometryOk = false
		fail(cockpitId .. " staged cockpit geometry contract is incomplete")
	end
end
for moduleId, module in pairs(stagedModules) do
	if not module:FindFirstChild("ModuleRoot_DoNotRename", true) then
		geometryOk = false
		fail(moduleId .. " staged module geometry contract is incomplete")
	end
end
if geometryOk then pass("All staged cockpit and module geometry roots are complete") end

local valuesOk = true
local pathFolderCount = 0
local pathCount = 0
for _, cockpitId in ipairs(profileOrder) do
	local profile = profiles[cockpitId]
	for _, componentName in ipairs(replaceableComponents) do
		for _, variantName in ipairs(variantOrder) do
			local source = profile:WaitForChild("VariantDefinitions"):WaitForChild(componentName):WaitForChild(variantName)
			local module = stagedByBuild[cockpitId][componentName][variantName]
			for _, variableName in ipairs(rawVariableOrder) do
				if math.abs(module:GetAttribute(variableName) - source:GetAttribute(variableName)) > 0.000001 then
					valuesOk = false
					fail(module:GetAttribute("ModuleId") .. " mismatched " .. variableName)
				end
			end
			local paths = module:FindFirstChild("VehiclePerformanceV2UpgradePaths")
			if variantName == "Standard" then
				if paths or module:GetAttribute("UpgradePointCapacity") ~= 0 then
					valuesOk = false
					fail(module:GetAttribute("ModuleId") .. " Standard module became upgradable")
				end
			else
				if paths then
					pathFolderCount += 1
					pathCount += #paths:GetChildren()
				else
					valuesOk = false
					fail(module:GetAttribute("ModuleId") .. " is missing upgrade paths")
				end
			end
		end
	end
end
if valuesOk then pass("All 72 staged modules exactly match their confirmed Phase 5 raw definitions") end
if pathFolderCount == 48 and pathCount == 144 then pass("Materialised 48 six-point modules with 144 total path definitions") else fail(string.format("Expected 48 path folders/144 paths, found %d/%d", pathFolderCount, pathCount)) end

local validationCalculator = calculatorV2:Clone()
validationCalculator.Name = "VehiclePerformanceV2Calculator_Phase6ValidationTemp"
validationCalculator.Parent = performance
local loaded, V2Calculator = pcall(require, validationCalculator)
validationCalculator:Destroy()
assert(loaded, "Fresh Phase 6 calculator validation load failed: " .. tostring(V2Calculator))

local buildsOk = true
for _, cockpitId in ipairs(profileOrder) do
	local raw = {}
	for _, variableName in ipairs(rawVariableOrder) do raw[variableName] = 0 end
	local pieces = {
		stagedByBuild[cockpitId].Cockpit,
		stagedByBuild[cockpitId].FrontEngine.Standard,
		stagedByBuild[cockpitId].RearEngine.Standard,
		stagedByBuild[cockpitId].Stabilisers.Standard,
		stagedByBuild[cockpitId].Boost.Standard,
	}
	for _, piece in ipairs(pieces) do
		for _, variableName in ipairs(rawVariableOrder) do raw[variableName] += piece:GetAttribute(variableName) end
	end
	local result = V2Calculator.Calculate(raw)
	local profile = profiles[cockpitId]
	local targetTier = profile:GetAttribute("TargetTier")
	local targetPI = profile:GetAttribute("TargetPI")
	if result.Overall.Tier ~= targetTier or math.abs(result.Overall.InternalPerformanceIndex - targetPI) > 3 then
		buildsOk = false
		fail(string.format("%s staged stock build is %s %.2f, expected %s %.2f", cockpitId, result.Overall.Tier, result.Overall.InternalPerformanceIndex, targetTier, targetPI))
	end
	print(string.format("%s STAGED | %s %s | PI %.2f | price %d", PREFIX, cockpitId, targetTier, result.Overall.InternalPerformanceIndex, profile:GetAttribute("PriceGuide") or 0))
end
if buildsOk then pass("All six staged Standard builds reproduce their confirmed target tier/PI") end

if #categories:GetDescendants() == liveCategoryDescendantCount then pass("Live vehicle/category hierarchy was not changed") else fail("Live vehicle/category hierarchy changed unexpectedly") end
assert(liveDefinitions.Source == liveDefinitionsSource, "Live V1 definitions source changed unexpectedly")
assert(liveCalculator.Source == liveCalculatorSource, "Live V1 calculator source changed unexpectedly")
assert(liveRuntime.Source == liveRuntimeSource, "Live V1 runtime source changed unexpectedly")
pass("Live V1 performance sources were not changed")

if config:GetAttribute("RuntimeRatingEnabled") ~= false or config:GetAttribute("RuntimePhysicsEnabled") ~= false then
	fail("A V2 runtime switch is unexpectedly enabled")
else
	pass("V2 rating and physics runtime switches remain disabled")
end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
if failCount == 0 then
	print(PREFIX .. " STAGED ONLY - Inspect ServerStorage.NeoTokyoRacers.VehiclePerformanceV2_Staging; nothing is visible to the garage or players.")
	print(PREFIX .. " NEXT - Refresh the Studio mirror and copy the full Output into chat before any live catalogue/runtime migration.")
else
	warn(PREFIX .. " BLOCKED - Do not publish staged assets or enable V2 runtime. Copy the full Output into chat.")
end
