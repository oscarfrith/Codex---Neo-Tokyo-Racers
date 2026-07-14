-- NTR_VEHICLE_PERFORMANCE_V2_PHASE7_DYNAMICS_ADAPTER
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceV2Calculator"))

local Adapter = {}

function Adapter.FromRaw(raw)
	raw = typeof(raw) == "table" and raw or {}
	return {
		TopSpeed = tonumber(raw.TopSpeed) or 0,
		EngineOutput = Calculator.EffectiveFactor("EngineOutput", raw.EngineOutput),
		Weight = Calculator.EffectiveFactor("Weight", raw.Weight),
		LateralGrip = Calculator.EffectiveFactor("LateralGrip", raw.LateralGrip),
		SteeringResponse = Calculator.EffectiveFactor("SteeringResponse", raw.SteeringResponse),
		HoverStability = Calculator.EffectiveFactor("HoverStability", raw.HoverStability),
		DriftControl = Calculator.EffectiveFactor("DriftControl", raw.DriftControl),
		DriftGrip = Calculator.EffectiveFactor("DriftGrip", raw.DriftGrip),
		DriftChargeRate = Calculator.EffectiveFactor("DriftChargeRate", raw.DriftChargeRate),
		BrakingForce = Calculator.EffectiveFactor("BrakingForce", raw.BrakingForce),
		BoostForce = Calculator.EffectiveFactor("BoostForce", raw.BoostForce),
		BoostDuration = Calculator.EffectiveFactor("BoostDuration", raw.BoostDuration),
		BoostRecharge = Calculator.EffectiveFactor("BoostRecharge", raw.BoostRecharge),
		BoostRechargeDelay = Calculator.EffectiveFactor("BoostRechargeDelay", raw.BoostRechargeDelay),
		BoostEfficiency = Calculator.EffectiveFactor("BoostEfficiency", raw.BoostEfficiency),
		Drag = Calculator.EffectiveFactor("Drag", raw.Drag),
		Downforce = Calculator.EffectiveFactor("Downforce", raw.Downforce),
	}
end

function Adapter.FromResult(result)
	return Adapter.FromRaw(result and result.Raw)
end

return Adapter
