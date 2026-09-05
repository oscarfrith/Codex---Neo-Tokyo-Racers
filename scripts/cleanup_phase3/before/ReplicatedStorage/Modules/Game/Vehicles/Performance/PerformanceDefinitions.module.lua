-- NTR_VEHICLE_PERFORMANCE_V2_PHASE1_SHADOW_DEFINITIONS
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
