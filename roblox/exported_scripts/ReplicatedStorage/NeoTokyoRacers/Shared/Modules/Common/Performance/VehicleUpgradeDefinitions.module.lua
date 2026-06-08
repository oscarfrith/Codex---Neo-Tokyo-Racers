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
