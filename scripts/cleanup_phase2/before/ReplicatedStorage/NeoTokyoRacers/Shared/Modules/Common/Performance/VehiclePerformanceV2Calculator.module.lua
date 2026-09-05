-- NTR_VEHICLE_PERFORMANCE_V2_PHASE1_SHADOW_CALCULATOR
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
	-- NTR_VEHICLE_PERFORMANCE_V2_PHASE2_PERFORMANCE_ORIGIN
	local performanceOrigin = finiteNumber(settings.PerformanceOrigin, 0)
	local ratingInput = math.max(combined - performanceOrigin, 0)
	local ratingScale = math.max(finiteNumber(settings.RatingScale, 50.43508980641478), 0.0001)
	local internal = minimum + (maximum - minimum) * (1 - math.exp(-ratingInput / ratingScale))
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
