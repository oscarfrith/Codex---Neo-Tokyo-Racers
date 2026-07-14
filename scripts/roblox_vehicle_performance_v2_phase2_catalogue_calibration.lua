-- Neo Tokyo Racers - Vehicle Performance V2 Phase 2 catalogue calibration
-- Run once in the Roblox Studio Command Bar while NOT play-testing.
--
-- Installs six balanced complete-stock shadow profiles and calibrates the V2 PI curve.
-- Does NOT switch live ratings, physics, UI, upgrades, prices, or vehicle assets.
-- Creates no backup folders/scripts. It performs one guarded exact replacement only
-- inside the isolated V2 calculator installed by Phase 1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing Vehicle Performance V2 Phase 2")

local PREFIX = "[NTR Vehicle Performance V2 Phase 2]"
local MARKER = "NTR_VEHICLE_PERFORMANCE_V2_PHASE2_PERFORMANCE_ORIGIN"
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

local function countPlain(source, needle)
	local count, startAt = 0, 1
	while true do
		local found = string.find(source, needle, startAt, true)
		if not found then return count end
		count += 1
		startAt = found + #needle
	end
end

local function replacePlainOnce(source, oldText, newText, label)
	local count = countPlain(source, oldText)
	assert(count == 1, label .. " expected exactly one source anchor, found " .. tostring(count))
	local startAt, endAt = string.find(source, oldText, 1, true)
	return string.sub(source, 1, startAt - 1) .. newText .. string.sub(source, endAt + 1)
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local sharedConfig = shared:WaitForChild("Config")
local performance = shared:WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local config = sharedConfig:WaitForChild("VehiclePerformanceV2_EditAttributes")
local definitionsV2 = performance:WaitForChild("VehiclePerformanceV2Definitions")
local calculatorV2 = performance:WaitForChild("VehiclePerformanceV2Calculator")
local liveDefinitions = performance:WaitForChild("VehiclePerformanceDefinitions")
local liveCalculator = performance:WaitForChild("VehiclePerformanceCalculator")
local liveRuntime = performance:WaitForChild("VehiclePerformanceRuntime")

assert(config:IsA("Folder"), "Phase 1 V2 config is missing or invalid")
assert(definitionsV2:IsA("ModuleScript"), "Phase 1 V2 definitions module is missing")
assert(calculatorV2:IsA("ModuleScript"), "Phase 1 V2 calculator module is missing")
assert(string.find(definitionsV2.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE1_SHADOW_DEFINITIONS", 1, true), "Phase 1 definitions marker is missing")
assert(string.find(calculatorV2.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE1_SHADOW_CALCULATOR", 1, true), "Phase 1 calculator marker is missing")
assert(config:GetAttribute("RuntimeRatingEnabled") == false, "V2 RuntimeRatingEnabled must remain false")
assert(config:GetAttribute("RuntimePhysicsEnabled") == false, "V2 RuntimePhysicsEnabled must remain false")

local liveDefinitionsSource = liveDefinitions.Source
local liveCalculatorSource = liveCalculator.Source
local liveRuntimeSource = liveRuntime.Source

local oldOriginBlock = [=[	local ratingScale = math.max(finiteNumber(settings.RatingScale, 150), 0.0001)
	local internal = minimum + (maximum - minimum) * (1 - math.exp(-combined / ratingScale))]=]
local newOriginBlock = [=[	-- NTR_VEHICLE_PERFORMANCE_V2_PHASE2_PERFORMANCE_ORIGIN
	local performanceOrigin = finiteNumber(settings.PerformanceOrigin, 0)
	local ratingInput = math.max(combined - performanceOrigin, 0)
	local ratingScale = math.max(finiteNumber(settings.RatingScale, 50.43508980641478), 0.0001)
	local internal = minimum + (maximum - minimum) * (1 - math.exp(-ratingInput / ratingScale))]=]

local nextCalculatorSource = calculatorV2.Source
if not string.find(nextCalculatorSource, MARKER, 1, true) then
	assert(countPlain(nextCalculatorSource, oldOriginBlock) == 1,
		"The isolated V2 calculator origin anchor is not unique. Stop and refresh/inspect the mirror; do not attempt another source repair.")
	nextCalculatorSource = replacePlainOnce(nextCalculatorSource, oldOriginBlock, newOriginBlock, "V2 performance-origin block")
end

local rawVariableOrder = {
	"TopSpeed", "EngineOutput", "Weight", "LateralGrip", "SteeringResponse", "HoverStability",
	"DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostForce", "BoostDuration",
	"BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce",
}

local profiles = {
	{
		CockpitId = "bruiser_02", DisplayName = "Forge", TargetTier = "E", TargetPI = 200, PriceGuide = 40000,
		Raw = { 56, 27, 220, 18, 15, 10, 14, 18, 16, 28, 9, 0.55, 14, 1.5, 15, 100, 11 },
	},
	{
		CockpitId = "bruiser_03", DisplayName = "Vector", TargetTier = "D", TargetPI = 375, PriceGuide = 120000,
		Raw = { 94, 37, 220, 27, 24, 20, 22, 27, 24, 37, 15, 0.96, 14, 1.29, 24, 100, 19 },
	},
	{
		CockpitId = "bruiser_01", DisplayName = "Viper", TargetTier = "C", TargetPI = 525, PriceGuide = 350000,
		Raw = { 137, 50, 184, 38, 36, 34, 34, 38, 36, 48, 23, 1.44, 12, 0.76, 36, 74, 33 },
	},
	{
		CockpitId = "bruiser_04", DisplayName = "Nightline", TargetTier = "B", TargetPI = 662, PriceGuide = 1100000,
		Raw = { 192, 63, 108, 53, 54, 56, 54, 54, 54, 63, 32, 2.21, 8.28, 0.46, 53, 45, 54 },
	},
	{
		CockpitId = "bruiser_05", DisplayName = "Rally", TargetTier = "A", TargetPI = 787, PriceGuide = 3500000,
		Raw = { 278, 83, 61, 78, 85, 98, 92, 81, 84, 84, 46, 3.39, 5.63, 0.25, 84, 25, 99 },
	},
	{
		CockpitId = "bruiser_06", DisplayName = "Zenith", TargetTier = "S", TargetPI = 925, PriceGuide = 10000000,
		Raw = { 360, 149, 60, 173, 210, 220, 210, 159, 182, 148, 107, 6, 4, 0.086, 203, 1.475, 220 },
	},
}

-- All source/config preflight checks have passed. Mutations begin here.
calculatorV2.Source = nextCalculatorSource

config:SetAttribute("SchemaVersion", "V2_PHASE2_CALIBRATION")
config:SetAttribute("ShadowOnly", true)
config:SetAttribute("RuntimeRatingEnabled", false)
config:SetAttribute("RuntimePhysicsEnabled", false)
config:SetAttribute("SourceSheetRevision", "NTR-BAL-003-P2")
config:SetAttribute("TuningNote", "Six balanced E-S stock profiles calibrated in shadow. Raw stats remain uncapped; runtime remains V1.")

local topSpeedCurve = config:WaitForChild("StatCurves"):WaitForChild("TopSpeed")
topSpeedCurve:SetAttribute("Reference", 180)

local overall = config:WaitForChild("OverallRating")
overall:SetAttribute("RatingScale", 50.43508980641478)
overall:SetAttribute("PerformanceOrigin", 54.05258886598588)

local profileRoot = ensureFolder(config, "BalancedStockProfiles")
profileRoot:SetAttribute("SourceSheetRevision", "NTR-BAL-003-P2")
profileRoot:SetAttribute("ShadowOnly", true)
for _, profile in ipairs(profiles) do
	local folder = ensureFolder(profileRoot, profile.CockpitId)
	folder:SetAttribute("CockpitId", profile.CockpitId)
	folder:SetAttribute("DisplayName", profile.DisplayName)
	folder:SetAttribute("TargetTier", profile.TargetTier)
	folder:SetAttribute("TargetPI", profile.TargetPI)
	folder:SetAttribute("PriceGuide", profile.PriceGuide)
	folder:SetAttribute("Status", "SHADOW_ONLY")
	for index, variableName in ipairs(rawVariableOrder) do
		folder:SetAttribute(variableName, profile.Raw[index])
	end
end

assert(liveDefinitions.Source == liveDefinitionsSource, "Live V1 definitions source changed unexpectedly")
assert(liveCalculator.Source == liveCalculatorSource, "Live V1 calculator source changed unexpectedly")
assert(liveRuntime.Source == liveRuntimeSource, "Live V1 runtime source changed unexpectedly")
pass("Live V1 definitions, calculator, and runtime sources were not changed")

assert(string.find(calculatorV2.Source, MARKER, 1, true), "Performance-origin marker was not installed")
pass("Isolated V2 calculator now supports the calibrated PerformanceOrigin")

local V2Definitions = require(definitionsV2)

-- Command Bar sessions can retain the Phase 1 require result even after Source changes.
-- Validate through a short-lived clone so this run executes the saved Phase 2 source.
-- The clone is destroyed immediately and is never a backup or runtime object.
local validationCalculator = calculatorV2:Clone()
validationCalculator.Name = "VehiclePerformanceV2Calculator_Phase2ValidationTemp"
validationCalculator.Parent = performance
local calculatorLoaded, V2Calculator = pcall(require, validationCalculator)
validationCalculator:Destroy()
assert(calculatorLoaded, "Fresh Phase 2 calculator validation load failed: " .. tostring(V2Calculator))
pass("Fresh calculator instance bypassed the Studio Command Bar require cache")
local settings = V2Definitions.GetOverallSettings()
assert(math.abs((settings.PerformanceOrigin or 0) - 54.05258886598588) < 0.000001, "PerformanceOrigin config was not loaded")
assert(math.abs((settings.RatingScale or 0) - 50.43508980641478) < 0.000001, "RatingScale config was not loaded")
assert(math.abs(V2Definitions.GetCurve("TopSpeed").Reference - 180) < 0.000001, "TopSpeed reference was not loaded")
pass("Calibrated curve settings loaded from editable V2 config")

local function rawMap(profile)
	local result = {}
	for index, variableName in ipairs(rawVariableOrder) do result[variableName] = profile.Raw[index] end
	return result
end

local previousRaw
local allProfilesOk = true
print(PREFIX .. " --- BALANCED STOCK SHADOW RESULTS (not live ratings) ---")
for _, profile in ipairs(profiles) do
	local raw = rawMap(profile)
	local result = V2Calculator.Calculate(raw)
	local minimumHeadline, maximumHeadline = math.huge, -math.huge
	for _, headlineName in ipairs(V2Definitions.HeadlineOrder) do
		local value = result.Headline[headlineName]
		minimumHeadline = math.min(minimumHeadline, value)
		maximumHeadline = math.max(maximumHeadline, value)
	end
	local spread = maximumHeadline - minimumHeadline
	local gap = result.Overall.InternalPerformanceIndex - profile.TargetPI
	if result.Overall.Tier ~= profile.TargetTier or math.abs(gap) > 3 or spread > 1 then
		allProfilesOk = false
		fail(string.format("%s calibration mismatch: %s %.2f, target %s %d, gap %+.2f, spread %.2f",
			profile.DisplayName, result.Overall.Tier, result.Overall.InternalPerformanceIndex,
			profile.TargetTier, profile.TargetPI, gap, spread))
	end
	if previousRaw then
		for index, variableName in ipairs(rawVariableOrder) do
			local curve = V2Definitions.GetCurve(variableName)
			local monotonic = curve.LowerIsBetter and raw[variableName] <= previousRaw[variableName]
				or (not curve.LowerIsBetter and raw[variableName] >= previousRaw[variableName])
			if not monotonic then
				allProfilesOk = false
				fail(profile.DisplayName .. " breaks E-S raw-stat progression for " .. variableName)
			end
		end
	end
	previousRaw = raw
	print(string.format(
		"%s PROFILE | %s %s | %s %d (internal %.2f) | target %s %d | gap %+.2f | spread %.2f | S %.2f A %.2f H %.2f D %.2f B %.2f X %.2f",
		PREFIX, profile.CockpitId, profile.DisplayName, result.Overall.Tier, result.Overall.PerformanceIndex,
		result.Overall.InternalPerformanceIndex, profile.TargetTier, profile.TargetPI, gap, spread,
		result.Headline.Speed, result.Headline.Acceleration, result.Headline.Handling,
		result.Headline.Drift, result.Headline.Braking, result.Headline.Boost
	))
end
if allProfilesOk then pass("All six profiles match their target tiers, sit within 3 PI, remain balanced, and progress monotonically") end

local lowRaw = rawMap(profiles[1])
local highRaw = rawMap(profiles[6])
local lowUpgraded = V2Calculator.CloneRaw(lowRaw)
local highUpgraded = V2Calculator.CloneRaw(highRaw)
lowUpgraded.EngineOutput += 20
highUpgraded.EngineOutput += 20
local lowGain = V2Calculator.Calculate(lowUpgraded).Overall.InternalPerformanceIndex - V2Calculator.Calculate(lowRaw).Overall.InternalPerformanceIndex
local highGain = V2Calculator.Calculate(highUpgraded).Overall.InternalPerformanceIndex - V2Calculator.Calculate(highRaw).Overall.InternalPerformanceIndex
if lowGain > highGain and highGain > 0 then
	pass(string.format("Same +20 EngineOutput remains useful but diminishes across tiers: E +%.2f PI vs S +%.2f PI", lowGain, highGain))
else
	fail(string.format("Cross-tier diminishing return failed: E +%.2f PI vs S +%.2f PI", lowGain, highGain))
end

if config:GetAttribute("RuntimeRatingEnabled") ~= false or config:GetAttribute("RuntimePhysicsEnabled") ~= false then
	fail("A V2 runtime switch is unexpectedly enabled")
else
	pass("V2 rating and physics runtime switches remain disabled")
end

local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local existingCockpitIds = {}
for _, item in ipairs(categories:GetDescendants()) do
	if item:IsA("Model") and typeof(item:GetAttribute("CockpitId")) == "string" then
		existingCockpitIds[item:GetAttribute("CockpitId")] = true
	end
end
if existingCockpitIds.bruiser_06 then
	caution("bruiser_06 already exists; Phase 2 still did not change its model or assets")
else
	pass("Zenith remains a shadow definition only; no sixth vehicle asset was created")
end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
if failCount == 0 then
	print(PREFIX .. " INSTALLED IN SHADOW - Six balanced profiles are calibrated; player-facing ratings and physics remain V1.")
	print(PREFIX .. " NEXT - Refresh the Studio mirror, then copy the full Output into chat before any vehicle-asset or runtime phase.")
else
	warn(PREFIX .. " BLOCKED - Do not build/assign vehicle assets or enable V2 runtime. Copy the full Output into chat.")
end
