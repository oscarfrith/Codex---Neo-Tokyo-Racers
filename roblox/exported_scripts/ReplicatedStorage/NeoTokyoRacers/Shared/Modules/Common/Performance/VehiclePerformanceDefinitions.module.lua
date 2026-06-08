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
