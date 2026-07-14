-- Neo Tokyo Racers - Vehicle Performance V2 Phase 1 shadow calculator
-- Run once in the Roblox Studio Command Bar while NOT play-testing.
--
-- Creates isolated V2 config + calculator modules and runs smoke tests.
-- Restores ReverseEngageDelaySeconds to the confirmed 1.0-second baseline.
-- Does NOT switch live rating, physics, UI, upgrades, prices, or vehicle assets.
-- Creates no backup folders/scripts and performs no fragile text replacement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing Vehicle Performance V2 Phase 1")

local PREFIX = "[NTR Vehicle Performance V2 Phase 1]"
local passCount = 0
local warnCount = 0
local failCount = 0

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

local function ensureModule(parent, name, source)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("ModuleScript"), item:GetFullName() .. " must be a ModuleScript")
	else
		item = Instance.new("ModuleScript")
		item.Name = name
		item.Parent = parent
	end
	if item.Source ~= source then
		item.Source = source
	end
	return item
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local sharedConfig = shared:WaitForChild("Config")
local performance = shared:WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")

local liveDefinitions = performance:WaitForChild("VehiclePerformanceDefinitions")
local liveCalculator = performance:WaitForChild("VehiclePerformanceCalculator")
local liveRuntime = performance:WaitForChild("VehiclePerformanceRuntime")
assert(liveDefinitions:IsA("ModuleScript"), "Live V1 definitions module is invalid")
assert(liveCalculator:IsA("ModuleScript"), "Live V1 calculator module is invalid")
assert(liveRuntime:IsA("ModuleScript"), "Live V1 runtime module is invalid")

local liveDefinitionsSource = liveDefinitions.Source
local liveCalculatorSource = liveCalculator.Source
local liveRuntimeSource = liveRuntime.Source

local curves = {
	TopSpeed = { Reference = 130, Exponent = 0.55, TechnicalMinimum = 0, LowerIsBetter = false },
	EngineOutput = { Reference = 60, Exponent = 0.75, TechnicalMinimum = 0, LowerIsBetter = false },
	Weight = { Reference = 118, Exponent = 0.35, TechnicalMinimum = 60, LowerIsBetter = true },
	LateralGrip = { Reference = 50, Exponent = 0.55, TechnicalMinimum = 0, LowerIsBetter = false },
	SteeringResponse = { Reference = 50, Exponent = 0.45, TechnicalMinimum = 0, LowerIsBetter = false },
	HoverStability = { Reference = 50, Exponent = 0.35, TechnicalMinimum = 0, LowerIsBetter = false },
	DriftControl = { Reference = 50, Exponent = 0.40, TechnicalMinimum = 0, LowerIsBetter = false },
	DriftGrip = { Reference = 50, Exponent = 0.50, TechnicalMinimum = 0, LowerIsBetter = false },
	DriftChargeRate = { Reference = 50, Exponent = 0.45, TechnicalMinimum = 0, LowerIsBetter = false },
	BrakingForce = { Reference = 60, Exponent = 0.70, TechnicalMinimum = 0, LowerIsBetter = false },
	BoostForce = { Reference = 30, Exponent = 0.55, TechnicalMinimum = 0, LowerIsBetter = false },
	BoostDuration = { Reference = 2, Exponent = 0.45, TechnicalMinimum = 0.1, LowerIsBetter = false },
	BoostRecharge = { Reference = 9, Exponent = 0.50, TechnicalMinimum = 4, LowerIsBetter = true },
	BoostRechargeDelay = { Reference = 0.5, Exponent = 0.35, TechnicalMinimum = 0.05, LowerIsBetter = true },
	BoostEfficiency = { Reference = 50, Exponent = 0.45, TechnicalMinimum = 0, LowerIsBetter = false },
	Drag = { Reference = 50, Exponent = 0.35, TechnicalMinimum = 1, LowerIsBetter = true },
	Downforce = { Reference = 50, Exponent = 0.35, TechnicalMinimum = 0, LowerIsBetter = false },
}

local headlineWeights = {
	Speed = { TopSpeed = 0.70, Drag = 0.20, Weight = 0.10 },
	Acceleration = { EngineOutput = 0.60, Weight = 0.25, BoostForce = 0.15 },
	Handling = { LateralGrip = 0.35, SteeringResponse = 0.25, HoverStability = 0.20, Downforce = 0.10, Weight = 0.10 },
	Drift = { DriftControl = 0.35, DriftGrip = 0.25, DriftChargeRate = 0.25, SteeringResponse = 0.15 },
	Braking = { BrakingForce = 0.60, LateralGrip = 0.15, HoverStability = 0.15, Weight = 0.10 },
	Boost = { BoostForce = 0.35, BoostDuration = 0.20, BoostRecharge = 0.20, BoostRechargeDelay = 0.10, BoostEfficiency = 0.15 },
}

local overallWeights = {
	Speed = 0.22,
	Acceleration = 0.20,
	Handling = 0.20,
	Drift = 0.14,
	Braking = 0.10,
	Boost = 0.14,
}

local tierBands = { E = 100, D = 300, C = 450, B = 600, A = 725, S = 850 }

local config = ensureFolder(sharedConfig, "VehiclePerformanceV2_EditAttributes")
config:SetAttribute("SchemaVersion", "V2_PHASE1_SHADOW")
config:SetAttribute("ShadowOnly", true)
config:SetAttribute("RuntimeRatingEnabled", false)
config:SetAttribute("RuntimePhysicsEnabled", false)
config:SetAttribute("SourceSheetRevision", "NTR-BAL-002-P0")
config:SetAttribute("TuningNote", "Raw stats are uncapped. Only technical minimums protect inverse curves. V1 remains live during Phase 1.")

local curveRoot = ensureFolder(config, "StatCurves")
for variableName, values in pairs(curves) do
	local folder = ensureFolder(curveRoot, variableName)
	folder:SetAttribute("CurveType", "Power")
	folder:SetAttribute("Reference", values.Reference)
	folder:SetAttribute("Exponent", values.Exponent)
	folder:SetAttribute("TechnicalMinimum", values.TechnicalMinimum)
	folder:SetAttribute("LowerIsBetter", values.LowerIsBetter)
end

local headlineRoot = ensureFolder(config, "HeadlineWeights")
for headlineName, weights in pairs(headlineWeights) do
	local folder = ensureFolder(headlineRoot, headlineName)
	for variableName, weight in pairs(weights) do
		folder:SetAttribute(variableName, weight)
	end
end

local overallFolder = ensureFolder(config, "OverallRating")
for headlineName, weight in pairs(overallWeights) do
	overallFolder:SetAttribute(headlineName, weight)
end
overallFolder:SetAttribute("BaseContribution", 0.925)
overallFolder:SetAttribute("BalanceContribution", 0.075)
overallFolder:SetAttribute("InteractionBlend", 0.30)
overallFolder:SetAttribute("RatingScale", 150)
overallFolder:SetAttribute("PerformanceIndexMin", 100)
overallFolder:SetAttribute("PerformanceIndexMax", 999)
overallFolder:SetAttribute("InternalPrecision", 2)

local tierFolder = ensureFolder(config, "TierBands")
for tier, threshold in pairs(tierBands) do
	tierFolder:SetAttribute(tier, threshold)
end

local definitionsSource = [=[-- NTR_VEHICLE_PERFORMANCE_V2_PHASE1_SHADOW_DEFINITIONS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = {}

Definitions.RawVariableOrder = {
	"TopSpeed", "EngineOutput", "Weight", "LateralGrip", "SteeringResponse", "HoverStability",
	"DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostForce", "BoostDuration",
	"BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce",
}

Definitions.HeadlineOrder = { "Speed", "Acceleration", "Handling", "Drift", "Braking", "Boost" }

Definitions.DefaultCurves = {
	TopSpeed = { CurveType = "Power", Reference = 130, Exponent = 0.55, TechnicalMinimum = 0, LowerIsBetter = false },
	EngineOutput = { CurveType = "Power", Reference = 60, Exponent = 0.75, TechnicalMinimum = 0, LowerIsBetter = false },
	Weight = { CurveType = "Power", Reference = 118, Exponent = 0.35, TechnicalMinimum = 60, LowerIsBetter = true },
	LateralGrip = { CurveType = "Power", Reference = 50, Exponent = 0.55, TechnicalMinimum = 0, LowerIsBetter = false },
	SteeringResponse = { CurveType = "Power", Reference = 50, Exponent = 0.45, TechnicalMinimum = 0, LowerIsBetter = false },
	HoverStability = { CurveType = "Power", Reference = 50, Exponent = 0.35, TechnicalMinimum = 0, LowerIsBetter = false },
	DriftControl = { CurveType = "Power", Reference = 50, Exponent = 0.40, TechnicalMinimum = 0, LowerIsBetter = false },
	DriftGrip = { CurveType = "Power", Reference = 50, Exponent = 0.50, TechnicalMinimum = 0, LowerIsBetter = false },
	DriftChargeRate = { CurveType = "Power", Reference = 50, Exponent = 0.45, TechnicalMinimum = 0, LowerIsBetter = false },
	BrakingForce = { CurveType = "Power", Reference = 60, Exponent = 0.70, TechnicalMinimum = 0, LowerIsBetter = false },
	BoostForce = { CurveType = "Power", Reference = 30, Exponent = 0.55, TechnicalMinimum = 0, LowerIsBetter = false },
	BoostDuration = { CurveType = "Power", Reference = 2, Exponent = 0.45, TechnicalMinimum = 0.1, LowerIsBetter = false },
	BoostRecharge = { CurveType = "Power", Reference = 9, Exponent = 0.50, TechnicalMinimum = 4, LowerIsBetter = true },
	BoostRechargeDelay = { CurveType = "Power", Reference = 0.5, Exponent = 0.35, TechnicalMinimum = 0.05, LowerIsBetter = true },
	BoostEfficiency = { CurveType = "Power", Reference = 50, Exponent = 0.45, TechnicalMinimum = 0, LowerIsBetter = false },
	Drag = { CurveType = "Power", Reference = 50, Exponent = 0.35, TechnicalMinimum = 1, LowerIsBetter = true },
	Downforce = { CurveType = "Power", Reference = 50, Exponent = 0.35, TechnicalMinimum = 0, LowerIsBetter = false },
}

Definitions.DefaultHeadlineWeights = {
	Speed = { TopSpeed = 0.70, Drag = 0.20, Weight = 0.10 },
	Acceleration = { EngineOutput = 0.60, Weight = 0.25, BoostForce = 0.15 },
	Handling = { LateralGrip = 0.35, SteeringResponse = 0.25, HoverStability = 0.20, Downforce = 0.10, Weight = 0.10 },
	Drift = { DriftControl = 0.35, DriftGrip = 0.25, DriftChargeRate = 0.25, SteeringResponse = 0.15 },
	Braking = { BrakingForce = 0.60, LateralGrip = 0.15, HoverStability = 0.15, Weight = 0.10 },
	Boost = { BoostForce = 0.35, BoostDuration = 0.20, BoostRecharge = 0.20, BoostRechargeDelay = 0.10, BoostEfficiency = 0.15 },
}

Definitions.DefaultOverall = {
	Speed = 0.22, Acceleration = 0.20, Handling = 0.20, Drift = 0.14, Braking = 0.10, Boost = 0.14,
	BaseContribution = 0.925, BalanceContribution = 0.075, InteractionBlend = 0.30,
	RatingScale = 150, PerformanceIndexMin = 100, PerformanceIndexMax = 999, InternalPrecision = 2,
}

Definitions.DefaultTierBands = { E = 100, D = 300, C = 450, B = 600, A = 725, S = 850 }

function Definitions.GetConfig()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local shared = kit and kit:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	return config and config:FindFirstChild("VehiclePerformanceV2_EditAttributes")
end

local function readAttributes(folder, fallback)
	local result = {}
	for key, value in pairs(fallback or {}) do result[key] = value end
	if folder then
		for key, value in pairs(folder:GetAttributes()) do result[key] = value end
	end
	return result
end

function Definitions.GetCurve(variableName)
	local config = Definitions.GetConfig()
	local root = config and config:FindFirstChild("StatCurves")
	return readAttributes(root and root:FindFirstChild(variableName), Definitions.DefaultCurves[variableName] or {})
end

function Definitions.GetHeadlineWeights(headlineName)
	local config = Definitions.GetConfig()
	local root = config and config:FindFirstChild("HeadlineWeights")
	return readAttributes(root and root:FindFirstChild(headlineName), Definitions.DefaultHeadlineWeights[headlineName] or {})
end

function Definitions.GetOverallSettings()
	local config = Definitions.GetConfig()
	return readAttributes(config and config:FindFirstChild("OverallRating"), Definitions.DefaultOverall)
end

function Definitions.GetTierBands()
	local config = Definitions.GetConfig()
	return readAttributes(config and config:FindFirstChild("TierBands"), Definitions.DefaultTierBands)
end

return Definitions
]=]

local calculatorSource = [=[-- NTR_VEHICLE_PERFORMANCE_V2_PHASE1_SHADOW_CALCULATOR
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceV2Definitions"))

local Calculator = {}

local function finiteNumber(value, fallback)
	if typeof(value) == "number" and value == value and value > -math.huge and value < math.huge then
		return value
	end
	return fallback
end

local function rounded(value, places)
	local scale = 10 ^ math.max(0, math.floor(finiteNumber(places, 2)))
	return math.floor(value * scale + 0.5) / scale
end

function Calculator.CloneRaw(raw)
	local result = {}
	for _, variableName in ipairs(Definitions.RawVariableOrder) do
		result[variableName] = finiteNumber(raw and raw[variableName], 0)
	end
	return result
end

function Calculator.AddRaw(target, delta, multiplier)
	target = target or {}
	multiplier = finiteNumber(multiplier, 1)
	for _, variableName in ipairs(Definitions.RawVariableOrder) do
		target[variableName] = finiteNumber(target[variableName], 0) + finiteNumber(delta and delta[variableName], 0) * multiplier
	end
	return target
end

function Calculator.EffectiveFactor(variableName, rawValue)
	local curve = Definitions.GetCurve(variableName)
	assert(curve.CurveType == "Power", variableName .. " has unsupported V2 curve type " .. tostring(curve.CurveType))
	local reference = math.max(finiteNumber(curve.Reference, 1), 0.0001)
	local exponent = math.clamp(finiteNumber(curve.Exponent, 1), 0.01, 1)
	local technicalMinimum = finiteNumber(curve.TechnicalMinimum, 0)
	local raw = finiteNumber(rawValue, technicalMinimum)
	local factor
	if curve.LowerIsBetter == true then
		factor = (reference / math.max(raw, technicalMinimum, 0.0001)) ^ exponent
	else
		factor = (math.max(raw, technicalMinimum, 0) / reference) ^ exponent
	end
	assert(factor == factor and factor < math.huge, variableName .. " produced a non-finite effective factor")
	return factor
end

function Calculator.CurveRaw(raw)
	local result = {}
	for _, variableName in ipairs(Definitions.RawVariableOrder) do
		result[variableName] = Calculator.EffectiveFactor(variableName, raw and raw[variableName])
	end
	return result
end

local function weightedArithmetic(values, weights)
	local total = 0
	local weightTotal = 0
	for key, weight in pairs(weights or {}) do
		if typeof(weight) == "number" and typeof(values[key]) == "number" then
			total += values[key] * weight
			weightTotal += weight
		end
	end
	return weightTotal > 0 and total / weightTotal or 0
end

local function weightedGeometric(values, weights)
	local logTotal = 0
	local weightTotal = 0
	for key, weight in pairs(weights or {}) do
		local value = values[key]
		if typeof(weight) == "number" and typeof(value) == "number" then
			if value <= 0 and weight > 0 then return 0 end
			if weight > 0 then
				logTotal += math.log(value) * weight
				weightTotal += weight
			end
		end
	end
	return weightTotal > 0 and math.exp(logTotal / weightTotal) or 0
end

function Calculator.CalculateHeadlines(effective)
	local settings = Definitions.GetOverallSettings()
	local interactionBlend = math.clamp(finiteNumber(settings.InteractionBlend, 0.30), 0, 1)
	local headline = {}
	local detail = {}
	for _, headlineName in ipairs(Definitions.HeadlineOrder) do
		local weights = Definitions.GetHeadlineWeights(headlineName)
		local arithmetic = weightedArithmetic(effective, weights)
		local geometric = weightedGeometric(effective, weights)
		local factor = arithmetic * (1 - interactionBlend) + geometric * interactionBlend
		headline[headlineName] = factor * 100
		detail[headlineName] = { ArithmeticFactor = arithmetic, GeometricFactor = geometric, BlendedFactor = factor }
	end
	return headline, detail
end

local function threeLowestAverage(headline)
	local values = {}
	for _, headlineName in ipairs(Definitions.HeadlineOrder) do
		table.insert(values, finiteNumber(headline[headlineName], 0))
	end
	table.sort(values)
	return (values[1] + values[2] + values[3]) / 3
end

function Calculator.TierForIndex(performanceIndex)
	local bands = Definitions.GetTierBands()
	for _, item in ipairs({
		{ "S", finiteNumber(bands.S, 850) }, { "A", finiteNumber(bands.A, 725) },
		{ "B", finiteNumber(bands.B, 600) }, { "C", finiteNumber(bands.C, 450) },
		{ "D", finiteNumber(bands.D, 300) }, { "E", finiteNumber(bands.E, 100) },
	}) do
		if performanceIndex >= item[2] then return item[1] end
	end
	return "E"
end

function Calculator.CalculateOverall(headline)
	local settings = Definitions.GetOverallSettings()
	local weighted = weightedArithmetic(headline, settings)
	local weakestThree = threeLowestAverage(headline)
	local balanceContribution = math.clamp(finiteNumber(settings.BalanceContribution, 0.075), 0, 1)
	local baseContribution = math.clamp(finiteNumber(settings.BaseContribution, 1 - balanceContribution), 0, 1)
	local contributionTotal = math.max(baseContribution + balanceContribution, 0.0001)
	baseContribution /= contributionTotal
	balanceContribution /= contributionTotal
	local combined = math.max(weighted * baseContribution + weakestThree * balanceContribution, 0)
	local minimum = finiteNumber(settings.PerformanceIndexMin, 100)
	local maximum = math.max(finiteNumber(settings.PerformanceIndexMax, 999), minimum + 1)
	local ratingScale = math.max(finiteNumber(settings.RatingScale, 150), 0.0001)
	local internal = minimum + (maximum - minimum) * (1 - math.exp(-combined / ratingScale))
	local precision = finiteNumber(settings.InternalPrecision, 2)
	local retained = rounded(internal, precision)
	local displayed = math.round(retained)
	return {
		Score = combined,
		WeightedHeadlineScore = weighted,
		WeakestThreeScore = weakestThree,
		InternalPerformanceIndex = retained,
		PerformanceIndex = displayed,
		Tier = Calculator.TierForIndex(displayed),
	}
end

function Calculator.Calculate(raw)
	local rawCopy = Calculator.CloneRaw(raw)
	local effective = Calculator.CurveRaw(rawCopy)
	local headline, headlineDetail = Calculator.CalculateHeadlines(effective)
	return {
		Raw = rawCopy,
		EffectiveFactor = effective,
		Headline = headline,
		HeadlineDetail = headlineDetail,
		Overall = Calculator.CalculateOverall(headline),
	}
end

return Calculator
]=]

local definitionsV2 = ensureModule(performance, "VehiclePerformanceV2Definitions", definitionsSource)
local calculatorV2 = ensureModule(performance, "VehiclePerformanceV2Calculator", calculatorSource)
definitionsV2:SetAttribute("VehiclePerformanceVersion", "V2_PHASE1_SHADOW")
definitionsV2:SetAttribute("RuntimeEnabled", false)
calculatorV2:SetAttribute("VehiclePerformanceVersion", "V2_PHASE1_SHADOW")
calculatorV2:SetAttribute("RuntimeEnabled", false)

assert(liveDefinitions.Source == liveDefinitionsSource, "Live V1 definitions source changed unexpectedly")
assert(liveCalculator.Source == liveCalculatorSource, "Live V1 calculator source changed unexpectedly")
assert(liveRuntime.Source == liveRuntimeSource, "Live V1 runtime source changed unexpectedly")
pass("Live V1 definitions, calculator, and runtime sources were not changed")

local runtimeConfig = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("VehicleDynamics_EditAttributes")
runtimeConfig:SetAttribute("ReverseEngageDelaySeconds", 1.0)
assert(runtimeConfig:GetAttribute("ReverseEngageDelaySeconds") == 1.0, "Reverse delay restoration failed")
pass("ReverseEngageDelaySeconds restored to 1.0 without changing dynamics source")

local V2Definitions = require(definitionsV2)
local V2Calculator = require(calculatorV2)
assert(#V2Definitions.RawVariableOrder == 17, "V2 raw-variable count must be 17")
assert(#V2Definitions.HeadlineOrder == 6, "V2 headline count must be 6")
pass("V2 module contract loaded: 17 raw variables and 6 headlines")

local weightContractOk = true
for _, headlineName in ipairs(V2Definitions.HeadlineOrder) do
	local total = 0
	for _, weight in pairs(V2Definitions.GetHeadlineWeights(headlineName)) do
		if typeof(weight) == "number" then total += weight end
	end
	if math.abs(total - 1) > 0.0001 then
		weightContractOk = false
		fail(headlineName .. " V2 headline weights total " .. string.format("%.4f", total) .. ", expected 1.0000")
	end
end
local overallSettings = V2Definitions.GetOverallSettings()
local overallWeightTotal = 0
for _, headlineName in ipairs(V2Definitions.HeadlineOrder) do
	overallWeightTotal += tonumber(overallSettings[headlineName]) or 0
end
if math.abs(overallWeightTotal - 1) > 0.0001 then
	weightContractOk = false
	fail("V2 overall headline weights total " .. string.format("%.4f", overallWeightTotal) .. ", expected 1.0000")
end
if math.abs((overallSettings.BaseContribution or 0) + (overallSettings.BalanceContribution or 0) - 1) > 0.0001 then
	weightContractOk = false
	fail("V2 BaseContribution + BalanceContribution must total 1.0000")
end
if weightContractOk then pass("All headline and overall contribution weights total 1.0") end

local referenceRaw = {}
for _, variableName in ipairs(V2Definitions.RawVariableOrder) do
	referenceRaw[variableName] = V2Definitions.GetCurve(variableName).Reference
end
local referenceResult = V2Calculator.Calculate(referenceRaw)
local referenceFactorOk = true
for _, variableName in ipairs(V2Definitions.RawVariableOrder) do
	if math.abs(referenceResult.EffectiveFactor[variableName] - 1) > 0.0001 then
		referenceFactorOk = false
		fail(variableName .. " reference value did not produce factor 1.0")
	end
end
if referenceFactorOk then pass("All reference values produce neutral factor 1.0") end

local highEngineFactor = V2Calculator.EffectiveFactor("EngineOutput", 10000)
if highEngineFactor > 1.6 then
	pass("EngineOutput curve is uncapped for balance (10000 raw -> factor " .. string.format("%.2f", highEngineFactor) .. ")")
else
	fail("EngineOutput still appears capped near the V1 1.6 factor")
end

local lowGain = V2Calculator.EffectiveFactor("EngineOutput", 80) - V2Calculator.EffectiveFactor("EngineOutput", 60)
local highGain = V2Calculator.EffectiveFactor("EngineOutput", 620) - V2Calculator.EffectiveFactor("EngineOutput", 600)
if lowGain > highGain and highGain > 0 then
	pass(string.format("Diminishing return verified: +20 EngineOutput gains %.4f low vs %.4f high", lowGain, highGain))
else
	fail("EngineOutput marginal gain did not diminish while remaining positive")
end

local technicalWeightFactor = V2Calculator.EffectiveFactor("Weight", 0)
if technicalWeightFactor == technicalWeightFactor and technicalWeightFactor < math.huge then
	pass("Lower-is-better technical minimum prevents invalid zero-weight calculation")
else
	fail("Weight technical minimum produced a non-finite factor")
end

if referenceResult.Overall.InternalPerformanceIndex < 999 and referenceResult.Overall.InternalPerformanceIndex > 100 then
	pass(string.format("Asymptotic PI smoke passed: neutral reference build -> %.2f / %s %d", referenceResult.Overall.InternalPerformanceIndex, referenceResult.Overall.Tier, referenceResult.Overall.PerformanceIndex))
else
	fail("Asymptotic PI smoke produced an invalid neutral rating")
end

local lowBuild = V2Calculator.CloneRaw(referenceRaw)
lowBuild.EngineOutput = 60
local lowBuildUpgraded = V2Calculator.CloneRaw(lowBuild)
lowBuildUpgraded.EngineOutput += 20
local highBuild = V2Calculator.CloneRaw(referenceRaw)
highBuild.EngineOutput = 600
local highBuildUpgraded = V2Calculator.CloneRaw(highBuild)
highBuildUpgraded.EngineOutput += 20
local lowPiGain = V2Calculator.Calculate(lowBuildUpgraded).Overall.InternalPerformanceIndex - V2Calculator.Calculate(lowBuild).Overall.InternalPerformanceIndex
local highPiGain = V2Calculator.Calculate(highBuildUpgraded).Overall.InternalPerformanceIndex - V2Calculator.Calculate(highBuild).Overall.InternalPerformanceIndex
if lowPiGain > highPiGain and highPiGain > 0 then
	pass(string.format("Same +20 raw module delta gives larger PI gain low (%.2f) than high (%.2f)", lowPiGain, highPiGain))
else
	caution(string.format("Cross-tier PI smoke needs calibration: low gain %.2f, high gain %.2f", lowPiGain, highPiGain))
end

local V1Definitions = require(liveDefinitions)
local V1Calculator = require(liveCalculator)
local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local moduleById = {}
local cockpits = {}
for _, item in ipairs(categories:GetDescendants()) do
	if item:IsA("Model") and typeof(item:GetAttribute("ModuleId")) == "string" and item:GetAttribute("RetiredFromCatalog") ~= true then
		moduleById[item:GetAttribute("ModuleId")] = item
	elseif item:IsA("Model") and typeof(item:GetAttribute("CockpitId")) == "string" then
		table.insert(cockpits, item)
	end
end
table.sort(cockpits, function(a, b) return tostring(a:GetAttribute("CockpitId")) < tostring(b:GetAttribute("CockpitId")) end)
assert(#cockpits == 5, "Phase 1 expected the Phase 0 five-cockpit foundation, found " .. tostring(#cockpits))

local legacyNames = { "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostDuration", "BoostRecharge", "BoostRechargeDelay" }
local defaultNames = { "DefaultFrontEngineModuleId", "DefaultRearEngineModuleId", "DefaultStabilisersModuleId", "DefaultBoostModuleId" }

local function numberAttribute(item, name, fallback)
	local value = item and item:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

local function standardRaw(cockpit)
	local totals = {}
	for _, name in ipairs(legacyNames) do totals[name] = numberAttribute(cockpit, name, 0) end
	local defaults = {}
	for _, attributeName in ipairs(defaultNames) do
		local module = moduleById[cockpit:GetAttribute(attributeName)]
		assert(module, cockpit:GetFullName() .. " has unresolved " .. attributeName)
		table.insert(defaults, module)
		for _, name in ipairs(legacyNames) do totals[name] += numberAttribute(module, name, 0) end
	end
	local raw = V1Calculator.FromLegacyStats(totals)
	for _, variableName in ipairs(V1Definitions.RawVariableOrder) do
		local override = cockpit:GetAttribute("PerformanceOverride_" .. variableName)
		if typeof(override) == "number" then raw[variableName] = override end
		raw[variableName] = (raw[variableName] or 0) + numberAttribute(cockpit, "PerformanceDelta_" .. variableName, 0)
		for _, module in ipairs(defaults) do
			raw[variableName] += numberAttribute(module, "PerformanceDelta_" .. variableName, 0)
		end
	end
	return raw
end

local targets = {
	bruiser_01 = { Tier = "C", PI = 525 }, bruiser_02 = { Tier = "E", PI = 200 },
	bruiser_03 = { Tier = "D", PI = 375 }, bruiser_04 = { Tier = "B", PI = 662 },
	bruiser_05 = { Tier = "A", PI = 787 },
}

print(PREFIX .. " --- SHADOW CATALOGUE RESULTS (not live ratings) ---")
for _, cockpit in ipairs(cockpits) do
	local cockpitId = cockpit:GetAttribute("CockpitId")
	local result = V2Calculator.Calculate(standardRaw(cockpit))
	local target = targets[cockpitId]
	print(string.format(
		"%s SHADOW | %s | %s | %s %d (internal %.2f) | target %s %s | gap %+0.2f",
		PREFIX, tostring(cockpitId), tostring(cockpit:GetAttribute("DisplayName") or cockpit.Name),
		result.Overall.Tier, result.Overall.PerformanceIndex, result.Overall.InternalPerformanceIndex,
		target and target.Tier or "?", target and tostring(target.PI) or "?",
		target and (result.Overall.InternalPerformanceIndex - target.PI) or 0
	))
end
pass("Five current standard builds calculated in shadow without writing vehicle attributes")

if config:GetAttribute("RuntimeRatingEnabled") ~= false or config:GetAttribute("RuntimePhysicsEnabled") ~= false then
	fail("A Phase 1 runtime switch is unexpectedly enabled")
else
	pass("V2 rating and physics runtime switches remain disabled")
end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
if failCount == 0 then
	print(PREFIX .. " INSTALLED IN SHADOW - Play-test reverse delay only; player-facing ratings and physics remain V1.")
	print(PREFIX .. " NEXT - Refresh the Studio mirror, then copy the full Output into chat for catalogue calibration.")
else
	warn(PREFIX .. " BLOCKED - Do not proceed to V2 catalogue calibration until every FAIL is resolved.")
end
