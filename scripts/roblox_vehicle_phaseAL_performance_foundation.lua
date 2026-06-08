-- Neo Tokyo Racers - Vehicle Phase AL
-- Performance definitions, calculator, upgrade definitions, and editable config.
--
-- Safe foundation phase:
-- - Does not patch active server/client scripts.
-- - Does not change driving physics, UI, purchases, or profile data.
-- - Creates shared ModuleScripts and editable configuration only.
-- - Runs a read-only catalogue audit after installation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PHASE = "Vehicle Phase AL"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureModule(parent, name, source)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("ModuleScript") then
		error(item:GetFullName() .. " must be a ModuleScript")
	end
	if not item then
		item = Instance.new("ModuleScript")
		item.Name = name
		item.Parent = parent
	end
	item.Source = source
	return item
end

local function setDefaultAttribute(item, name, value)
	if item:GetAttribute(name) == nil then
		item:SetAttribute(name, value)
	end
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = ensureFolder(kit, "Shared")
local modules = ensureFolder(shared, "Modules")
local common = ensureFolder(modules, "Common")
local performanceModules = ensureFolder(common, "Performance")
local sharedConfig = ensureFolder(shared, "Config")
local config = ensureFolder(sharedConfig, "VehiclePerformance_EditAttributes")

setDefaultAttribute(config, "Version", "AL_1")
setDefaultAttribute(config, "AuditOnly", true)
setDefaultAttribute(config, "AuditTolerancePoints", 12)
setDefaultAttribute(config, "EditNote", "Phase AL only. Edit child-folder attributes to tune normalization, headline weights, rating weights, tiers, and module context UI.")

local normalization = ensureFolder(config, "Normalization")
local normalizationDefaults = {
	TopSpeed = { 40, 220, false, "Top Speed", "MPH", 0 },
	EngineOutput = { 0, 100, false, "Engine Output", "", 0 },
	Weight = { 60, 220, true, "Weight", "", 0 },
	LateralGrip = { 0, 100, false, "Lateral Grip", "", 0 },
	SteeringResponse = { 0, 100, false, "Steering Response", "", 0 },
	HoverStability = { 0, 100, false, "Hover Stability", "", 0 },
	DriftControl = { 0, 100, false, "Drift Control", "", 0 },
	DriftGrip = { 0, 100, false, "Drift Grip", "", 0 },
	DriftChargeRate = { 0, 100, false, "Drift Charge", "", 0 },
	BrakingForce = { 0, 100, false, "Braking Force", "", 0 },
	BoostForce = { 0, 60, false, "Boost Force", "", 0 },
	BoostDuration = { 1, 4, false, "Boost Duration", "s", 2 },
	BoostRecharge = { 4, 14, true, "Recharge", "s", 1 },
	BoostRechargeDelay = { 0, 1.5, true, "Recharge Delay", "s", 2 },
	BoostEfficiency = { 0, 100, false, "Boost Efficiency", "", 0 },
	Drag = { 0, 100, true, "Drag", "", 0 },
	Downforce = { 0, 100, false, "Downforce", "", 0 },
}

for variableName, values in pairs(normalizationDefaults) do
	local folder = ensureFolder(normalization, variableName)
	setDefaultAttribute(folder, "Min", values[1])
	setDefaultAttribute(folder, "Max", values[2])
	setDefaultAttribute(folder, "LowerIsBetter", values[3])
	setDefaultAttribute(folder, "DisplayName", values[4])
	setDefaultAttribute(folder, "Unit", values[5])
	setDefaultAttribute(folder, "DecimalPlaces", values[6])
end

local headlineWeights = ensureFolder(config, "HeadlineWeights")
local headlineDefaults = {
	Speed = {
		TopSpeed = 0.70,
		Drag = 0.20,
		Weight = 0.10,
	},
	Acceleration = {
		EngineOutput = 0.60,
		Weight = 0.25,
		BoostForce = 0.15,
	},
	Handling = {
		LateralGrip = 0.35,
		SteeringResponse = 0.25,
		HoverStability = 0.20,
		Downforce = 0.10,
		Weight = 0.10,
	},
	Drift = {
		DriftControl = 0.35,
		DriftGrip = 0.25,
		DriftChargeRate = 0.25,
		SteeringResponse = 0.15,
	},
	Braking = {
		BrakingForce = 0.60,
		LateralGrip = 0.15,
		HoverStability = 0.15,
		Weight = 0.10,
	},
	Boost = {
		BoostForce = 0.35,
		BoostDuration = 0.20,
		BoostRecharge = 0.20,
		BoostRechargeDelay = 0.10,
		BoostEfficiency = 0.15,
	},
}

for headlineName, weights in pairs(headlineDefaults) do
	local folder = ensureFolder(headlineWeights, headlineName)
	for variableName, weight in pairs(weights) do
		setDefaultAttribute(folder, variableName, weight)
	end
end

local overallWeights = ensureFolder(config, "OverallRating")
setDefaultAttribute(overallWeights, "Speed", 0.22)
setDefaultAttribute(overallWeights, "Acceleration", 0.20)
setDefaultAttribute(overallWeights, "Handling", 0.20)
setDefaultAttribute(overallWeights, "Drift", 0.14)
setDefaultAttribute(overallWeights, "Braking", 0.10)
setDefaultAttribute(overallWeights, "Boost", 0.14)
setDefaultAttribute(overallWeights, "BaseContribution", 0.85)
setDefaultAttribute(overallWeights, "BalanceContribution", 0.15)
setDefaultAttribute(overallWeights, "PerformanceIndexMin", 100)
setDefaultAttribute(overallWeights, "PerformanceIndexMax", 999)

local tierBands = ensureFolder(config, "TierBands")
setDefaultAttribute(tierBands, "E", 100)
setDefaultAttribute(tierBands, "D", 300)
setDefaultAttribute(tierBands, "C", 450)
setDefaultAttribute(tierBands, "B", 600)
setDefaultAttribute(tierBands, "A", 725)
setDefaultAttribute(tierBands, "S", 850)

local compatibility = ensureFolder(config, "CompatibilityDefaults")
setDefaultAttribute(compatibility, "NeutralDrag", 50)
setDefaultAttribute(compatibility, "NeutralDownforce", 50)
setDefaultAttribute(compatibility, "NeutralBoostEfficiency", 50)
setDefaultAttribute(compatibility, "DefaultBoostDuration", 2)
setDefaultAttribute(compatibility, "DefaultBoostRecharge", 9)
setDefaultAttribute(compatibility, "DefaultBoostRechargeDelay", 0.5)

local contexts = ensureFolder(config, "ModuleContexts")
local contextDefaults = {
	Engine = { "Acceleration", "Speed", "EngineOutput,Weight,TopSpeed,Drag" },
	Stabilisers = { "Handling", "Drift", "LateralGrip,SteeringResponse,HoverStability,DriftControl,DriftGrip,DriftChargeRate" },
	Boost = { "Boost", "Acceleration", "BoostForce,BoostDuration,BoostRecharge,BoostRechargeDelay,BoostEfficiency,Weight" },
	FrontBumper = { "Braking", "Handling", "BrakingForce,Downforce,Drag,Weight" },
	RearBumper = { "Handling", "Drift", "HoverStability,DriftControl,Drag,Weight" },
	RearSpoiler = { "Handling", "Speed", "Downforce,Drag,LateralGrip,TopSpeed" },
	SidePods = { "Drift", "Handling", "DriftGrip,LateralGrip,Downforce,Drag,Weight" },
}

for moduleType, values in pairs(contextDefaults) do
	local folder = ensureFolder(contexts, moduleType)
	setDefaultAttribute(folder, "PrimaryHeadline", values[1])
	setDefaultAttribute(folder, "SecondaryHeadline", values[2])
	setDefaultAttribute(folder, "Variables", values[3])
	setDefaultAttribute(folder, "MaxHeadlineGroups", 2)
	setDefaultAttribute(folder, "MaxVariablesPerGroup", 4)
end

local definitionsSource = [==[
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = {}

Definitions.RawVariableOrder = {
	"TopSpeed",
	"EngineOutput",
	"Weight",
	"LateralGrip",
	"SteeringResponse",
	"HoverStability",
	"DriftControl",
	"DriftGrip",
	"DriftChargeRate",
	"BrakingForce",
	"BoostForce",
	"BoostDuration",
	"BoostRecharge",
	"BoostRechargeDelay",
	"BoostEfficiency",
	"Drag",
	"Downforce",
}

Definitions.HeadlineOrder = {
	"Speed",
	"Acceleration",
	"Handling",
	"Drift",
	"Braking",
	"Boost",
}

Definitions.DefaultNormalization = {
	TopSpeed = { Min = 40, Max = 220, LowerIsBetter = false, DisplayName = "Top Speed", Unit = "MPH", DecimalPlaces = 0 },
	EngineOutput = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Engine Output", Unit = "", DecimalPlaces = 0 },
	Weight = { Min = 60, Max = 220, LowerIsBetter = true, DisplayName = "Weight", Unit = "", DecimalPlaces = 0 },
	LateralGrip = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Lateral Grip", Unit = "", DecimalPlaces = 0 },
	SteeringResponse = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Steering Response", Unit = "", DecimalPlaces = 0 },
	HoverStability = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Hover Stability", Unit = "", DecimalPlaces = 0 },
	DriftControl = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Drift Control", Unit = "", DecimalPlaces = 0 },
	DriftGrip = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Drift Grip", Unit = "", DecimalPlaces = 0 },
	DriftChargeRate = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Drift Charge", Unit = "", DecimalPlaces = 0 },
	BrakingForce = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Braking Force", Unit = "", DecimalPlaces = 0 },
	BoostForce = { Min = 0, Max = 60, LowerIsBetter = false, DisplayName = "Boost Force", Unit = "", DecimalPlaces = 0 },
	BoostDuration = { Min = 1, Max = 4, LowerIsBetter = false, DisplayName = "Boost Duration", Unit = "s", DecimalPlaces = 2 },
	BoostRecharge = { Min = 4, Max = 14, LowerIsBetter = true, DisplayName = "Recharge", Unit = "s", DecimalPlaces = 1 },
	BoostRechargeDelay = { Min = 0, Max = 1.5, LowerIsBetter = true, DisplayName = "Recharge Delay", Unit = "s", DecimalPlaces = 2 },
	BoostEfficiency = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Boost Efficiency", Unit = "", DecimalPlaces = 0 },
	Drag = { Min = 0, Max = 100, LowerIsBetter = true, DisplayName = "Drag", Unit = "", DecimalPlaces = 0 },
	Downforce = { Min = 0, Max = 100, LowerIsBetter = false, DisplayName = "Downforce", Unit = "", DecimalPlaces = 0 },
}

Definitions.DefaultHeadlineWeights = {
	Speed = { TopSpeed = 0.70, Drag = 0.20, Weight = 0.10 },
	Acceleration = { EngineOutput = 0.60, Weight = 0.25, BoostForce = 0.15 },
	Handling = { LateralGrip = 0.35, SteeringResponse = 0.25, HoverStability = 0.20, Downforce = 0.10, Weight = 0.10 },
	Drift = { DriftControl = 0.35, DriftGrip = 0.25, DriftChargeRate = 0.25, SteeringResponse = 0.15 },
	Braking = { BrakingForce = 0.60, LateralGrip = 0.15, HoverStability = 0.15, Weight = 0.10 },
	Boost = { BoostForce = 0.35, BoostDuration = 0.20, BoostRecharge = 0.20, BoostRechargeDelay = 0.10, BoostEfficiency = 0.15 },
}

Definitions.DefaultOverallWeights = {
	Speed = 0.22,
	Acceleration = 0.20,
	Handling = 0.20,
	Drift = 0.14,
	Braking = 0.10,
	Boost = 0.14,
}

Definitions.DefaultTierBands = {
	E = 100,
	D = 300,
	C = 450,
	B = 600,
	A = 725,
	S = 850,
}

function Definitions.GetConfig()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local shared = kit and kit:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	return config and config:FindFirstChild("VehiclePerformance_EditAttributes")
end

local function readAttributes(folder, fallback)
	local result = {}
	for key, value in pairs(fallback or {}) do
		result[key] = value
	end
	if folder then
		for key, value in pairs(folder:GetAttributes()) do
			result[key] = value
		end
	end
	return result
end

function Definitions.GetNormalization(variableName)
	local config = Definitions.GetConfig()
	local root = config and config:FindFirstChild("Normalization")
	return readAttributes(root and root:FindFirstChild(variableName), Definitions.DefaultNormalization[variableName] or {})
end

function Definitions.GetHeadlineWeights(headlineName)
	local config = Definitions.GetConfig()
	local root = config and config:FindFirstChild("HeadlineWeights")
	return readAttributes(root and root:FindFirstChild(headlineName), Definitions.DefaultHeadlineWeights[headlineName] or {})
end

function Definitions.GetOverallSettings()
	local config = Definitions.GetConfig()
	local folder = config and config:FindFirstChild("OverallRating")
	local result = readAttributes(folder, Definitions.DefaultOverallWeights)
	result.BaseContribution = result.BaseContribution or 0.85
	result.BalanceContribution = result.BalanceContribution or 0.15
	result.PerformanceIndexMin = result.PerformanceIndexMin or 100
	result.PerformanceIndexMax = result.PerformanceIndexMax or 999
	return result
end

function Definitions.GetTierBands()
	local config = Definitions.GetConfig()
	local folder = config and config:FindFirstChild("TierBands")
	return readAttributes(folder, Definitions.DefaultTierBands)
end

function Definitions.GetCompatibilityDefaults()
	local config = Definitions.GetConfig()
	local folder = config and config:FindFirstChild("CompatibilityDefaults")
	return readAttributes(folder, {
		NeutralDrag = 50,
		NeutralDownforce = 50,
		NeutralBoostEfficiency = 50,
		DefaultBoostDuration = 2,
		DefaultBoostRecharge = 9,
		DefaultBoostRechargeDelay = 0.5,
	})
end

function Definitions.GetModuleContext(moduleType)
	local config = Definitions.GetConfig()
	local root = config and config:FindFirstChild("ModuleContexts")
	return readAttributes(root and root:FindFirstChild(moduleType), {})
end

return Definitions
]==]

local calculatorSource = [==[
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))

local Calculator = {}

local function number(value, fallback)
	return typeof(value) == "number" and value or fallback
end

local function read(source, name, fallback)
	if typeof(source) == "Instance" then
		return number(source:GetAttribute(name), fallback)
	end
	if typeof(source) == "table" then
		return number(source[name], fallback)
	end
	return fallback
end

function Calculator.FromLegacyStats(source)
	local compatibility = Definitions.GetCompatibilityDefaults()
	local handling = read(source, "Handling", 48)
	local drift = read(source, "Drift", 46)
	local boost = read(source, "BoostForce", read(source, "Boost", 0))
	return {
		TopSpeed = read(source, "TopSpeed", read(source, "MaxSpeed", 126)),
		EngineOutput = read(source, "EngineOutput", read(source, "Acceleration", 42)),
		Weight = read(source, "Weight", 118),
		LateralGrip = read(source, "LateralGrip", handling),
		SteeringResponse = read(source, "SteeringResponse", handling),
		HoverStability = read(source, "HoverStability", handling),
		DriftControl = read(source, "DriftControl", drift),
		DriftGrip = read(source, "DriftGrip", drift),
		DriftChargeRate = read(source, "DriftChargeRate", drift),
		BrakingForce = read(source, "BrakingForce", read(source, "Braking", 44)),
		BoostForce = boost,
		BoostDuration = read(source, "BoostDuration", compatibility.DefaultBoostDuration),
		BoostRecharge = read(source, "BoostRecharge", compatibility.DefaultBoostRecharge),
		BoostRechargeDelay = read(source, "BoostRechargeDelay", compatibility.DefaultBoostRechargeDelay),
		BoostEfficiency = read(source, "BoostEfficiency", compatibility.NeutralBoostEfficiency),
		Drag = read(source, "Drag", compatibility.NeutralDrag),
		Downforce = read(source, "Downforce", compatibility.NeutralDownforce),
	}
end

function Calculator.CloneRaw(raw)
	local result = {}
	for _, name in ipairs(Definitions.RawVariableOrder) do
		result[name] = number(raw and raw[name], 0)
	end
	return result
end

function Calculator.AddRaw(target, delta, multiplier)
	target = target or {}
	multiplier = number(multiplier, 1)
	for _, name in ipairs(Definitions.RawVariableOrder) do
		local amount = number(delta and delta[name], 0)
		target[name] = number(target[name], 0) + amount * multiplier
	end
	return target
end

function Calculator.NormalizeVariable(variableName, rawValue)
	local definition = Definitions.GetNormalization(variableName)
	local minimum = number(definition.Min, 0)
	local maximum = number(definition.Max, 100)
	local span = math.max(maximum - minimum, 0.0001)
	local score = math.clamp((number(rawValue, minimum) - minimum) / span * 100, 0, 100)
	if definition.LowerIsBetter == true then
		score = 100 - score
	end
	return score
end

function Calculator.NormalizeRaw(raw)
	local result = {}
	for _, name in ipairs(Definitions.RawVariableOrder) do
		result[name] = Calculator.NormalizeVariable(name, raw[name])
	end
	return result
end

local function weightedAverage(values, weights)
	local total = 0
	local weightTotal = 0
	for key, weight in pairs(weights or {}) do
		if typeof(weight) == "number" and typeof(values[key]) == "number" then
			total += values[key] * weight
			weightTotal += weight
		end
	end
	if weightTotal <= 0 then return 0 end
	return total / weightTotal
end

function Calculator.CalculateHeadline(normalized)
	local result = {}
	for _, headlineName in ipairs(Definitions.HeadlineOrder) do
		result[headlineName] = weightedAverage(normalized, Definitions.GetHeadlineWeights(headlineName))
	end
	return result
end

local function threeLowestAverage(headline)
	local values = {}
	for _, name in ipairs(Definitions.HeadlineOrder) do
		table.insert(values, number(headline[name], 0))
	end
	table.sort(values)
	return (values[1] + values[2] + values[3]) / 3
end

function Calculator.TierForIndex(performanceIndex)
	local bands = Definitions.GetTierBands()
	local ordered = {
		{ "S", number(bands.S, 850) },
		{ "A", number(bands.A, 725) },
		{ "B", number(bands.B, 600) },
		{ "C", number(bands.C, 450) },
		{ "D", number(bands.D, 300) },
		{ "E", number(bands.E, 100) },
	}
	for _, item in ipairs(ordered) do
		if performanceIndex >= item[2] then
			return item[1]
		end
	end
	return "E"
end

function Calculator.CalculateOverall(headline)
	local settings = Definitions.GetOverallSettings()
	local base = weightedAverage(headline, settings)
	local balance = threeLowestAverage(headline)
	local finalScore = math.clamp(
		base * number(settings.BaseContribution, 0.85)
			+ balance * number(settings.BalanceContribution, 0.15),
		0,
		100
	)
	local minimum = number(settings.PerformanceIndexMin, 100)
	local maximum = number(settings.PerformanceIndexMax, 999)
	local performanceIndex = math.round(minimum + finalScore / 100 * (maximum - minimum))
	return {
		Score = finalScore,
		PerformanceIndex = performanceIndex,
		Tier = Calculator.TierForIndex(performanceIndex),
		BaseScore = base,
		BalanceScore = balance,
	}
end

function Calculator.Calculate(raw)
	local rawCopy = Calculator.CloneRaw(raw)
	local normalized = Calculator.NormalizeRaw(rawCopy)
	local headline = Calculator.CalculateHeadline(normalized)
	return {
		Raw = rawCopy,
		Normalized = normalized,
		Headline = headline,
		Overall = Calculator.CalculateOverall(headline),
	}
end

function Calculator.CalculateLegacy(source)
	return Calculator.Calculate(Calculator.FromLegacyStats(source))
end

return Calculator
]==]

local upgradesSource = [==[
-- Phase AL data only. Phase AN will connect these definitions to purchases.
local UpgradeDefinitions = {}

UpgradeDefinitions.EnabledForPurchases = false

UpgradeDefinitions.ByModuleType = {
	Engine = {
		{ UpgradeId = "FuelInjection", DisplayName = "Fuel Injection", MaxLevel = 3, BasePrice = 4000, PriceMultiplier = 2.0, EffectsPerLevel = { EngineOutput = 2, TopSpeed = 1 } },
		{ UpgradeId = "PowerConverter", DisplayName = "Power Converter", MaxLevel = 3, BasePrice = 5000, PriceMultiplier = 2.0, EffectsPerLevel = { TopSpeed = 3, EngineOutput = 1, Weight = 2 } },
		{ UpgradeId = "LightweightInternals", DisplayName = "Lightweight Internals", MaxLevel = 3, BasePrice = 5500, PriceMultiplier = 2.0, EffectsPerLevel = { Weight = -4, SteeringResponse = 1 } },
		{ UpgradeId = "TorqueMapping", DisplayName = "Torque Mapping", MaxLevel = 3, BasePrice = 4500, PriceMultiplier = 2.0, EffectsPerLevel = { EngineOutput = 3, TopSpeed = -1 } },
	},
	Stabilisers = {
		{ UpgradeId = "VectoringFirmware", DisplayName = "Vectoring Firmware", MaxLevel = 3, BasePrice = 4500, PriceMultiplier = 2.0, EffectsPerLevel = { LateralGrip = 2, SteeringResponse = 1 } },
		{ UpgradeId = "DriftCalibration", DisplayName = "Drift Calibration", MaxLevel = 3, BasePrice = 4500, PriceMultiplier = 2.0, EffectsPerLevel = { DriftControl = 2, DriftChargeRate = 2, LateralGrip = -1 } },
		{ UpgradeId = "ReactiveDampers", DisplayName = "Reactive Dampers", MaxLevel = 3, BasePrice = 5000, PriceMultiplier = 2.0, EffectsPerLevel = { HoverStability = 2, BrakingForce = 2 } },
		{ UpgradeId = "LightweightArms", DisplayName = "Lightweight Arms", MaxLevel = 3, BasePrice = 5500, PriceMultiplier = 2.0, EffectsPerLevel = { Weight = -3, DriftGrip = 1 } },
	},
	Boost = {
		{ UpgradeId = "HighFlowInjectors", DisplayName = "High-Flow Injectors", MaxLevel = 3, BasePrice = 5000, PriceMultiplier = 2.0, EffectsPerLevel = { BoostForce = 4, BoostRecharge = 0.3 } },
		{ UpgradeId = "ExpandedCell", DisplayName = "Expanded Cell", MaxLevel = 3, BasePrice = 5500, PriceMultiplier = 2.0, EffectsPerLevel = { BoostDuration = 0.25, Weight = 3 } },
		{ UpgradeId = "RapidRecharge", DisplayName = "Rapid Recharge", MaxLevel = 3, BasePrice = 5500, PriceMultiplier = 2.0, EffectsPerLevel = { BoostRecharge = -0.6, BoostRechargeDelay = -0.08, BoostForce = -1 } },
		{ UpgradeId = "LightweightCell", DisplayName = "Lightweight Cell", MaxLevel = 3, BasePrice = 5000, PriceMultiplier = 2.0, EffectsPerLevel = { Weight = -3, BoostDuration = -0.1, BoostEfficiency = 2 } },
	},
	FrontBumper = {
		{ UpgradeId = "BrakeDucts", DisplayName = "Brake Ducts", MaxLevel = 3, BasePrice = 3500, PriceMultiplier = 2.0, EffectsPerLevel = { BrakingForce = 3, Weight = 1 } },
		{ UpgradeId = "FrontSplitter", DisplayName = "Front Splitter", MaxLevel = 3, BasePrice = 4000, PriceMultiplier = 2.0, EffectsPerLevel = { Downforce = 3, Drag = 1 } },
		{ UpgradeId = "LightweightMounts", DisplayName = "Lightweight Mounts", MaxLevel = 3, BasePrice = 4000, PriceMultiplier = 2.0, EffectsPerLevel = { Weight = -3, BrakingForce = -1 } },
	},
	RearBumper = {
		{ UpgradeId = "RearDiffuser", DisplayName = "Rear Diffuser", MaxLevel = 3, BasePrice = 4000, PriceMultiplier = 2.0, EffectsPerLevel = { HoverStability = 2, DriftControl = 1, Drag = 1 } },
		{ UpgradeId = "LightweightMounts", DisplayName = "Lightweight Mounts", MaxLevel = 3, BasePrice = 4000, PriceMultiplier = 2.0, EffectsPerLevel = { Weight = -3 } },
	},
	RearSpoiler = {
		{ UpgradeId = "DownforcePackage", DisplayName = "Downforce Package", MaxLevel = 3, BasePrice = 4500, PriceMultiplier = 2.0, EffectsPerLevel = { Downforce = 4, BrakingForce = 1, Drag = 2 } },
		{ UpgradeId = "LowDragProfile", DisplayName = "Low-Drag Profile", MaxLevel = 3, BasePrice = 4500, PriceMultiplier = 2.0, EffectsPerLevel = { Drag = -3, Downforce = -1 } },
		{ UpgradeId = "DriftAero", DisplayName = "Drift Aero", MaxLevel = 3, BasePrice = 4500, PriceMultiplier = 2.0, EffectsPerLevel = { DriftControl = 2, DriftGrip = 1, Drag = 1 } },
	},
	SidePods = {
		{ UpgradeId = "CorneringVanes", DisplayName = "Cornering Vanes", MaxLevel = 3, BasePrice = 4000, PriceMultiplier = 2.0, EffectsPerLevel = { LateralGrip = 2, DriftGrip = 2 } },
		{ UpgradeId = "AirflowChannels", DisplayName = "Airflow Channels", MaxLevel = 3, BasePrice = 4000, PriceMultiplier = 2.0, EffectsPerLevel = { Drag = -1, HoverStability = 1 } },
		{ UpgradeId = "LightweightShells", DisplayName = "Lightweight Shells", MaxLevel = 3, BasePrice = 4000, PriceMultiplier = 2.0, EffectsPerLevel = { Weight = -3 } },
	},
}

function UpgradeDefinitions.GetForModuleType(moduleType)
	return UpgradeDefinitions.ByModuleType[moduleType] or {}
end

function UpgradeDefinitions.Find(moduleType, upgradeId)
	for _, definition in ipairs(UpgradeDefinitions.GetForModuleType(moduleType)) do
		if definition.UpgradeId == upgradeId then
			return definition
		end
	end
end

function UpgradeDefinitions.PriceForLevel(definition, nextLevel)
	if not definition then return nil end
	local level = math.max(1, tonumber(nextLevel) or 1)
	return math.floor((definition.BasePrice or 0) * ((definition.PriceMultiplier or 1) ^ (level - 1)))
end

return UpgradeDefinitions
]==]

local definitionsModule = ensureModule(performanceModules, "VehiclePerformanceDefinitions", definitionsSource)
local calculatorModule = ensureModule(performanceModules, "VehiclePerformanceCalculator", calculatorSource)
ensureModule(performanceModules, "VehicleUpgradeDefinitions", upgradesSource)

definitionsModule:SetAttribute("Phase", "AL")
calculatorModule:SetAttribute("Phase", "AL")
performanceModules:SetAttribute("Phase", "AL")
performanceModules:SetAttribute("AuditOnly", true)

local Calculator = require(calculatorModule)
local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local audited = 0
local lowestIndex = math.huge
local highestIndex = -math.huge
local warnings = 0

for _, item in ipairs(categories:GetDescendants()) do
	if item:IsA("Model") and (item:GetAttribute("CockpitId") or item:GetAttribute("ModuleId")) then
		local result = Calculator.CalculateLegacy(item)
		audited += 1
		lowestIndex = math.min(lowestIndex, result.Overall.PerformanceIndex)
		highestIndex = math.max(highestIndex, result.Overall.PerformanceIndex)
		for _, value in pairs(result.Headline) do
			if value < 0 or value > 100 then
				warnings += 1
			end
		end
	end
end

if audited == 0 then
	lowestIndex = 0
	highestIndex = 0
	warnings += 1
end

info("Installed shared performance definitions, calculator, upgrade definitions, and editable config.")
info("Audit-only catalogue scan: " .. tostring(audited) .. " cockpit/module models.")
info("Standalone template rating range: " .. tostring(lowestIndex) .. " to " .. tostring(highestIndex) .. ".")
info("Audit warnings: " .. tostring(warnings) .. ". No active gameplay or UI was changed.")
