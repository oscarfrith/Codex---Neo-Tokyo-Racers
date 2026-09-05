-- NTR_VEHICLE_PERFORMANCE_V2_PHASE7_RUNTIME
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceV2Definitions"))
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceV2Calculator"))
local UpgradeRuntime = require(script.Parent:WaitForChild("VehiclePerformanceV2UpgradeRuntime"))
local DynamicsAdapter = require(script.Parent:WaitForChild("VehiclePerformanceV2DynamicsAdapter"))

local Runtime = {}

local function finite(value, fallback)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge and value or fallback
end

function Runtime.ZeroRaw()
	local raw = {}
	for _, name in ipairs(Definitions.RawVariableOrder) do raw[name] = 0 end
	return raw
end

function Runtime.ReadComponentRaw(item)
	local raw = Runtime.ZeroRaw()
	for _, name in ipairs(Definitions.RawVariableOrder) do
		raw[name] = finite(item and item:GetAttribute(name), finite(item and item:GetAttribute("PerformanceDelta_" .. name), 0))
	end
	return raw
end

function Runtime.ReadRuntimeRaw(vehicle)
	local raw = Runtime.ZeroRaw()
	local folder = vehicle and vehicle:FindFirstChild("RAW_PERFORMANCE_Runtime")
	for _, name in ipairs(Definitions.RawVariableOrder) do
		local valueObject = folder and folder:FindFirstChild(name)
		raw[name] = finite(valueObject and valueObject:IsA("NumberValue") and valueObject.Value,
			finite(vehicle and vehicle:GetAttribute("Performance_" .. name), 0))
	end
	return raw
end

function Runtime.AddRaw(target, source)
	for _, name in ipairs(Definitions.RawVariableOrder) do target[name] = finite(target[name], 0) + finite(source and source[name], 0) end
	return target
end

function Runtime.CalculateComponents(cockpit, modules, allocationsByModuleId)
	local raw = Runtime.ReadComponentRaw(cockpit)
	for _, module in ipairs(modules or {}) do
		local moduleId = tostring(module:GetAttribute("ModuleId") or module.Name)
		local allocation = allocationsByModuleId and allocationsByModuleId[moduleId]
		Runtime.AddRaw(raw, UpgradeRuntime.ApplyToModuleRaw(module, allocation))
	end
	return Calculator.Calculate(raw)
end

function Runtime.CalculateRuntimeVehicle(vehicle)
	return Calculator.Calculate(Runtime.ReadRuntimeRaw(vehicle))
end

function Runtime.CompatibilityView(result)
	local headline, overall, raw = result.Headline or {}, result.Overall or {}, result.Raw or {}
	return {
		Overall = { Tier = overall.Tier, PerformanceIndex = overall.PerformanceIndex, InternalPerformanceIndex = overall.InternalPerformanceIndex, Score = overall.Score },
		Headline = { Speed = headline.Speed, Acceleration = headline.Acceleration, Handling = headline.Handling, Drift = headline.Drift, Braking = headline.Braking, Boost = headline.Boost },
		Driving = {
			TopSpeed = raw.TopSpeed, EngineOutput = raw.EngineOutput, Weight = raw.Weight,
			LateralGrip = raw.LateralGrip, SteeringResponse = raw.SteeringResponse, HoverStability = raw.HoverStability,
			DriftControl = raw.DriftControl, DriftGrip = raw.DriftGrip, DriftChargeRate = raw.DriftChargeRate,
			BrakingForce = raw.BrakingForce, BoostForce = raw.BoostForce, BoostDuration = raw.BoostDuration,
			BoostRecharge = raw.BoostRecharge, BoostRechargeDelay = raw.BoostRechargeDelay,
			BoostEfficiency = raw.BoostEfficiency, Drag = raw.Drag, Downforce = raw.Downforce,
		},
		DynamicsFactors = DynamicsAdapter.FromRaw(raw),
	}
end

local function rewriteFolder(parent, name, values)
	local folder = parent:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then folder:Destroy(); folder = nil end
	if not folder then folder = Instance.new("Folder"); folder.Name = name; folder.Parent = parent end
	folder:ClearAllChildren()
	for key, value in pairs(values or {}) do
		if typeof(value) == "number" then local number = Instance.new("NumberValue"); number.Name = key; number.Value = value; number.Parent = folder end
	end
end

function Runtime.WriteShadow(vehicle, result)
	local view = Runtime.CompatibilityView(result)
	rewriteFolder(vehicle, "V2_SHADOW_RAW_PERFORMANCE_Runtime", result.Raw)
	rewriteFolder(vehicle, "V2_SHADOW_HEADLINE_STATS_Runtime", result.Headline)
	vehicle:SetAttribute("V2ShadowPerformanceIndex", view.Overall.PerformanceIndex)
	vehicle:SetAttribute("V2ShadowInternalPerformanceIndex", view.Overall.InternalPerformanceIndex)
	vehicle:SetAttribute("V2ShadowPerformanceTier", view.Overall.Tier)
	vehicle:SetAttribute("V2ShadowRuntimeVersion", "V2_PHASE7_INTEGRATED_SHADOW")
	return view
end

function Runtime.CatalogPreview(module, allocation)
	local raw = UpgradeRuntime.ApplyToModuleRaw(module, allocation)
	return {
		ModuleId = tostring(module:GetAttribute("ModuleId") or module.Name),
		DisplayName = tostring(module:GetAttribute("DisplayName") or module.Name),
		Price = tonumber(module:GetAttribute("Price")) or 0,
		Allocation = UpgradeRuntime.NormalizeAllocation(module, allocation),
		Raw = raw,
		Paths = UpgradeRuntime.Catalog(module, allocation),
	}
end

return Runtime
