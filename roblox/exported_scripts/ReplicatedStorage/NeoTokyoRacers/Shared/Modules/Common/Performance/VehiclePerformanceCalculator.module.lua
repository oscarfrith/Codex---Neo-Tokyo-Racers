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
