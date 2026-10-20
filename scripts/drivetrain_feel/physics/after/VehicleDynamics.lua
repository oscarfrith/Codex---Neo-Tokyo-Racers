-- Canonical feature implementation; startup is owned by the composition root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Model = {}
local MPH_PER_STUD = 0.625

local function configFolder()
	local kit = game:GetService("ReplicatedStorage")
	local config = kit and game:GetService("ReplicatedStorage"):FindFirstChild("Config")
	local vehicles = config and config:FindFirstChild("Vehicles")
	return vehicles and vehicles:FindFirstChild("Dynamics")
end
local categorisedNumberCacheFolder, categorisedNumberCache
local function categorisedNumber(folder, name)
	if not folder then return nil end
	if categorisedNumberCacheFolder ~= folder then
		categorisedNumberCacheFolder, categorisedNumberCache = folder, {}
		for _, category in ipairs(folder:GetChildren()) do
			if category:IsA("Folder") then
				for attributeName, attributeValue in pairs(category:GetAttributes()) do
					if typeof(attributeValue) == "number" then categorisedNumberCache[attributeName] = category end
				end
			end
		end
	end
	local category = categorisedNumberCache and categorisedNumberCache[name]
	return category and category:GetAttribute(name) or nil
end

local function numberAttribute(folder, name, fallback, minimum, maximum)
	local value = categorisedNumber(folder, name)
	if typeof(value) ~= "number" then value = folder and folder:GetAttribute(name) end
	if typeof(value) ~= "number" then value = fallback end
	if minimum ~= nil and maximum ~= nil then value = math.clamp(value, minimum, maximum) end
	return value
end
local function boolAttribute(folder, name, fallback)
	local value = folder and folder:GetAttribute(name)
	return typeof(value) == "boolean" and value or fallback
end
local function rawNumber(vehicle, name, fallback)
	local folder = vehicle and vehicle:FindFirstChild("RAW_PERFORMANCE_Runtime")
	local value = folder and folder:FindFirstChild(name)
	if value and value:IsA("NumberValue") then return value.Value end
	local attribute = vehicle and vehicle:GetAttribute("Performance_" .. name)
	return typeof(attribute) == "number" and attribute or fallback
end
local function curveMultiplier(raw, reference, exponent, minimum, maximum)
	return math.clamp((math.max(tonumber(raw) or reference, 0.001) / math.max(reference, 0.001)) ^ exponent, minimum, maximum)
end
local function smoothstep(alpha)
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

-- Performance balance (driving tune 2026-10-06). Multipliers applied where stats become forces; 1 = unchanged.
-- Tuning: Config.Vehicles.Dynamics.08_Balance. Stats, ratings and PerformanceIndex are not touched.
local BALANCE_OFF = table.freeze({Enabled=false, PerformanceIndex=0, BaseNerf=0, TopSpeed=1, Acceleration=1, Braking=1, Reverse=1, Drag=1, Boost=1, MiniBoost=1,
	Steering=1, Grip=1, DriftSideForce=1, DriftTurn=1, DriftEngineAssist=1, DriftAlignment=1, DriftCharge=1})
local balanceCacheVehicle, balanceCacheIndex, balanceCacheTime, balanceCacheRefresh, balanceCacheResult
local function setIfChanged(instance, name, value)
	if instance:GetAttribute(name) ~= value then instance:SetAttribute(name, value) end
end

-- Returns a frozen table; callers read it and never write it. Cheap to call several times a frame: the result
-- is reused until the vehicle, its PerformanceIndex or BalanceRefreshSeconds of time changes.
function Model.Balance(vehicle)
	local index = vehicle and vehicle:GetAttribute("PerformanceIndex")
	if typeof(index) ~= "number" or index ~= index then index = nil end
	local now = os.clock()
	if balanceCacheResult and balanceCacheVehicle == vehicle and balanceCacheIndex == index and now - balanceCacheTime < balanceCacheRefresh then
		return balanceCacheResult
	end
	local config = configFolder()
	local result
	if numberAttribute(config, "BalanceEnabled", 1, 0, 1) < 0.5 then
		result = BALANCE_OFF
	else
		result = Model.ComputeBalance(config, index)
	end
	balanceCacheVehicle, balanceCacheIndex, balanceCacheTime, balanceCacheResult = vehicle, index, now, result
	balanceCacheRefresh = numberAttribute(config, "BalanceRefreshSeconds", 0.25, 0, 5)
	if vehicle and boolAttribute(config, "DebugAttributes", true) then
		setIfChanged(vehicle, "DynamicsBalanceBaseNerf", result.BaseNerf)
		setIfChanged(vehicle, "DynamicsBalanceTopSpeed", result.TopSpeed)
		setIfChanged(vehicle, "DynamicsBalanceAcceleration", result.Acceleration)
		setIfChanged(vehicle, "DynamicsBalanceBraking", result.Braking)
		setIfChanged(vehicle, "DynamicsBalanceDrag", result.Drag)
		setIfChanged(vehicle, "DynamicsBalanceSteering", result.Steering)
		setIfChanged(vehicle, "DynamicsBalanceDriftTurn", result.DriftTurn)
		setIfChanged(vehicle, "DynamicsBalanceMiniBoost", result.MiniBoost)
	end
	return result
end

-- index = PerformanceIndex or nil. Pure: reads config only.
function Model.ComputeBalance(config, index)
	local lowIndex = numberAttribute(config, "BalanceLowPerformanceIndex", 200, 0, 2000)
	local highIndex = math.max(numberAttribute(config, "BalanceHighPerformanceIndex", 900, 0, 2000), lowIndex + 1)
	if index == nil then index = numberAttribute(config, "BalanceFallbackPerformanceIndex", 525, 0, 2000) end
	-- Straight line from the low to the high nerf, blended towards a smoothstep by BalanceCurveEase.
	-- Continuous and never decreasing in PerformanceIndex, flat outside the two ends: no steps at tier boundaries.
	local alpha = math.clamp((index - lowIndex) / (highIndex - lowIndex), 0, 1)
	alpha += (smoothstep(alpha) - alpha) * numberAttribute(config, "BalanceCurveEase", 0.5, 0, 1)
	local lowNerf = numberAttribute(config, "BalanceLowNerf", 0.1, 0, 0.6)
	local base = lowNerf + (numberAttribute(config, "BalanceHighNerf", 0.25, 0, 0.6) - lowNerf) * alpha
	local accelExtra = numberAttribute(config, "BalanceAccelBrakeExtraNerf", 0.15, 0, 0.6)
	local driftExtra = numberAttribute(config, "BalanceDriftExtraNerf", 0.2, 0, 0.6)
	local result = {Enabled = true, PerformanceIndex = index, BaseNerf = base}
	result.TopSpeed = math.clamp((1 - base * numberAttribute(config, "BalanceTopSpeedBaseShare", 1, 0, 2)), 0.1, 1.5)
	result.Acceleration = math.clamp((1 - base * numberAttribute(config, "BalanceAccelerationBaseShare", 1, 0, 2)) * (1 - accelExtra * numberAttribute(config, "BalanceAccelerationExtraShare", 1, 0, 2)), 0.1, 1.5)
	result.Braking = math.clamp((1 - base * numberAttribute(config, "BalanceBrakingBaseShare", 1, 0, 2)) * (1 - accelExtra * numberAttribute(config, "BalanceBrakingExtraShare", 1, 0, 2)), 0.1, 1.5)
	result.Reverse = math.clamp((1 - base * numberAttribute(config, "BalanceReverseBaseShare", 1, 0, 2)) * (1 - accelExtra * numberAttribute(config, "BalanceReverseExtraShare", 0, 0, 2)), 0.1, 1.5)
	result.Boost = math.clamp((1 - base * numberAttribute(config, "BalanceBoostBaseShare", 1, 0, 2)) * (1 - accelExtra * numberAttribute(config, "BalanceBoostExtraShare", 1, 0, 2)), 0.1, 1.5)
	result.Steering = math.clamp((1 - base * numberAttribute(config, "BalanceSteeringBaseShare", 0.4, 0, 2)), 0.1, 1.5)
	result.Grip = math.clamp((1 - base * numberAttribute(config, "BalanceGripBaseShare", 0.25, 0, 2)), 0.1, 1.5)
	result.DriftSideForce = math.clamp((1 - base * numberAttribute(config, "BalanceDriftSideForceBaseShare", 1, 0, 2)) * (1 - driftExtra * numberAttribute(config, "BalanceDriftSideForceExtraShare", 0, 0, 2)), 0.1, 1.5)
	result.DriftTurn = math.clamp((1 - base * numberAttribute(config, "BalanceDriftTurnBaseShare", 0, 0, 2)) * (1 - driftExtra * numberAttribute(config, "BalanceDriftTurnExtraShare", 1, 0, 2)), 0.1, 1.5)
	result.DriftEngineAssist = math.clamp((1 - base * numberAttribute(config, "BalanceDriftEngineAssistBaseShare", 0, 0, 2)) * (1 - driftExtra * numberAttribute(config, "BalanceDriftEngineAssistExtraShare", 1, 0, 2)), 0.1, 1.5)
	result.DriftAlignment = math.clamp((1 - base * numberAttribute(config, "BalanceDriftAlignmentBaseShare", 0.5, 0, 2)) * (1 - driftExtra * numberAttribute(config, "BalanceDriftAlignmentExtraShare", 1, 0, 2)), 0.1, 1.5)
	result.DriftCharge = math.clamp((1 - base * numberAttribute(config, "BalanceDriftChargeBaseShare", 0, 0, 2)) * (1 - driftExtra * numberAttribute(config, "BalanceDriftChargeExtraShare", 0.5, 0, 2)), 0.1, 1.5)
	result.MiniBoost = math.clamp((1 - base * numberAttribute(config, "BalanceMiniBoostBaseShare", 1, 0, 2)) * (1 - driftExtra * numberAttribute(config, "BalanceMiniBoostExtraShare", 1, 0, 2)), 0.1, 1.5)
	-- Top speed is set by air drag, not by the mapped cap (drag stops the cars well below it). Drag-limited speed
	-- goes as sqrt(acceleration / drag), so drag = acceleration / topSpeed^2 makes real top speed fall by exactly
	-- the top speed multiplier and the whole acceleration curve keep its shape.
	result.Drag = math.clamp(1 + (result.Acceleration / (result.TopSpeed * result.TopSpeed) - 1) * numberAttribute(config, "BalanceDragCoupling", 1, 0, 1), 0.25, 4)
	return table.freeze(result)
end

-- quiet = true (remote cars, drivetrain profile): no debug SetAttribute on the vehicle.
function Model.ResolveStats(vehicle, legacy, quiet)
	legacy = legacy or {}
	local config = configFolder()
	local detailed = boolAttribute(config, "Enabled", true) and boolAttribute(config, "DetailedStatsEnabled", true)
	local function value(name, fallbackName, fallback)
		local legacyValue = legacy[fallbackName or name]
		if typeof(legacyValue) ~= "number" then legacyValue = fallback end
		return detailed and rawNumber(vehicle, name, legacyValue) or legacyValue
	end
	local rawSteering = value("SteeringResponse", "SteeringResponse", 48)
	local steeringFactor = curveMultiplier(rawSteering,
		numberAttribute(config, "SteeringResponseReference", 50, 1, 500),
		numberAttribute(config, "SteeringResponseExponent", 0.42, 0.05, 1.5),
		numberAttribute(config, "SteeringResponseMinMultiplier", 0.78, 0.2, 2),
		numberAttribute(config, "SteeringResponseMaxMultiplier", 1.30, 0.2, 3))
	local rawDriftControl = value("DriftControl", "DriftControl", 46)
	local driftControlFactor = curveMultiplier(rawDriftControl,
		numberAttribute(config, "DriftControlReference", 50, 1, 500),
		numberAttribute(config, "PhysicalDriftControlExponent", 0.35, 0.05, 1.5),
		numberAttribute(config, "PhysicalDriftControlMinMultiplier", 0.82, 0.2, 2),
		numberAttribute(config, "PhysicalDriftControlMaxMultiplier", 1.25, 0.2, 3))
	local rawDuration = value("BoostDuration", "BoostDuration", 2)
	local rawRecharge = value("BoostRecharge", "BoostRecharge", 9)
	local rawDelay = value("BoostRechargeDelay", "BoostRechargeDelay", 0.5)
	local rawEfficiency = value("BoostEfficiency", "BoostEfficiency", 50)
	local efficiencyFactor = curveMultiplier(rawEfficiency, 50,
		numberAttribute(config, "BoostEfficiencyTimingExponent", 0.15, 0, 1), 0.90, 1.10)
	local duration = numberAttribute(config, "BoostDurationReferenceSeconds", 3.0, 0.5, 10)
		* curveMultiplier(rawDuration, 2, numberAttribute(config, "BoostDurationExponent", 0.32, 0.05, 1), 0.2, 3) * efficiencyFactor
	duration = math.clamp(duration, numberAttribute(config, "BoostDurationMinSeconds", 2.2, 0.5, 10), numberAttribute(config, "BoostDurationMaxSeconds", 4.2, 0.5, 12))
	local recharge = numberAttribute(config, "BoostRechargeReferenceSeconds", 8.5, 1, 30)
		* curveMultiplier(rawRecharge, 9, numberAttribute(config, "BoostRechargeExponent", 0.32, 0.05, 1), 0.2, 3) / efficiencyFactor
	recharge = math.clamp(recharge, numberAttribute(config, "BoostRechargeMinSeconds", 6.5, 0.5, 30), numberAttribute(config, "BoostRechargeMaxSeconds", 10.5, 0.5, 40))
	local delay = 0.65 * curveMultiplier(rawDelay, 0.5, numberAttribute(config, "BoostRechargeDelayExponent", 0.25, 0.05, 1), 0.2, 3)
	delay = math.clamp(delay, numberAttribute(config, "BoostRechargeDelayMinSeconds", 0.40, 0, 5), numberAttribute(config, "BoostRechargeDelayMaxSeconds", 1.0, 0, 5))
	local rawTopSpeed = value("TopSpeed", "TopSpeed", 126)
	local physicalTopSpeed = rawTopSpeed
	if boolAttribute(config, "Enabled", true) then
		local rawReference = numberAttribute(config, "TopSpeedRawReference", 137, 1, 1000)
		local physicalAtReference = numberAttribute(config, "PhysicalTopSpeedAtReferenceMph", 140, 20, 500)
		local exponent = numberAttribute(config, "PhysicalTopSpeedExponent", 0.55, 0.05, 2)
		physicalTopSpeed = physicalAtReference * (math.max(rawTopSpeed, 0.001) / rawReference) ^ exponent
		local minimumMph = numberAttribute(config, "PhysicalTopSpeedMinMph", 60, 20, 300)
		local maximumMph = numberAttribute(config, "PhysicalTopSpeedMaxMph", 300, 40, 500)
		local safetyMph = numberAttribute(config, "AbsoluteTopSpeedSafetyMph", 320, 80, 500)
		local upperMph = math.min(maximumMph, safetyMph)
		physicalTopSpeed = math.clamp(physicalTopSpeed, math.min(minimumMph, upperMph), upperMph)
	end
	if vehicle and not quiet and boolAttribute(config, "DebugAttributes", true) then
		vehicle:SetAttribute("DynamicsRawTopSpeed", rawTopSpeed)
		vehicle:SetAttribute("DynamicsMappedTopSpeedMph", physicalTopSpeed)
	end
	local result = {
		TopSpeed = physicalTopSpeed, RawTopSpeed = rawTopSpeed, EngineOutput = value("EngineOutput", "EngineOutput", 42), Weight = value("Weight", "Weight", 118),
		SteeringResponse = numberAttribute(config, "BasePhysicalSteeringResponse", 58, 10, 150) * steeringFactor, RawSteeringResponse = rawSteering,
		LateralGrip = value("LateralGrip", "LateralGrip", legacy.SteeringResponse or 48), HoverStability = value("HoverStability", "HoverStability", legacy.SteeringResponse or 48),
		DriftControl = numberAttribute(config, "BasePhysicalDriftControl", 50, 10, 150) * driftControlFactor, RawDriftControl = rawDriftControl,
		DriftGrip = value("DriftGrip", "DriftGrip", legacy.DriftControl or 46), DriftChargeRate = value("DriftChargeRate", "DriftChargeRate", legacy.DriftControl or 46),
		BrakingForce = value("BrakingForce", "BrakingForce", 44), BoostForce = value("BoostForce", "BoostForce", 0),
		BoostDuration = duration, BoostRecharge = recharge, BoostRechargeDelay = delay, BoostEfficiency = rawEfficiency,
		Drag = value("Drag", "Drag", 50), Downforce = value("Downforce", "Downforce", 50),
	}
	if vehicle and not quiet and boolAttribute(config, "DebugAttributes", true) then
		vehicle:SetAttribute("DynamicsRawSteeringResponse", rawSteering); vehicle:SetAttribute("DynamicsMappedSteeringResponse", result.SteeringResponse)
		vehicle:SetAttribute("DynamicsMappedBoostDuration", duration); vehicle:SetAttribute("DynamicsMappedBoostRecharge", recharge); vehicle:SetAttribute("DynamicsMappedBoostRechargeDelay", delay)
	end
	return result
end

local function oppositeSignAcceleration(forwardSpeed, amount)
	if forwardSpeed > 0 then return -amount elseif forwardSpeed < 0 then return amount end
	return 0
end

function Model.StepLongitudinal(params)
	local config = configFolder()
	if not boolAttribute(config, "Enabled", true) then return {Enabled=false,ReverseHoldTimer=0,LongitudinalAcceleration=0,Accelerating=false,Braking=false,SnapForwardStop=false} end
	local dt = math.clamp(tonumber(params.DeltaTime) or 0, 0, 0.1)
	local throttle = math.clamp(tonumber(params.Throttle) or 0, -1, 1)
	local forwardSpeed = tonumber(params.ForwardSpeed) or 0
	local forwardMph, absoluteMph = forwardSpeed * MPH_PER_STUD, math.abs(forwardSpeed * MPH_PER_STUD)
	local stats = params.Stats or {}
	local balance = Model.Balance(params.Vehicle)
	local absoluteTopSpeedSafetyMph = numberAttribute(config, "AbsoluteTopSpeedSafetyMph", 320, 80, 500)
	local maxMph = math.clamp(tonumber(params.MaxMph) or stats.TopSpeed or 126, 40, absoluteTopSpeedSafetyMph)
	local reverseMaxMph = math.clamp(tonumber(params.ReverseMaxMph) or 40, 5, 80)
	local deadzone = numberAttribute(config, "ThrottleDeadzone", 0.05, 0, 0.3)
	local stopThresholdMph = numberAttribute(config, "StopThresholdMph", 1.5, 0.1, 8)
	local autoHoldMph = numberAttribute(config, "AutoHoldMph", 1.25, 0.1, 8)
	local reverseDelay = numberAttribute(config, "ReverseEngageDelaySeconds", 1.0, 0, 1.5)
	local reverseHoldTimer = tonumber(params.ReverseHoldTimer) or 0

	local engineReference = numberAttribute(config, "EngineOutputReference", 60, 1, 300)
	local engineFactor = curveMultiplier(stats.EngineOutput, engineReference,
		numberAttribute(config, "EngineOutputExponent", 0.55, 0.05, 2),
		numberAttribute(config, "EngineOutputMinMultiplier", 0.72, 0.2, 2),
		numberAttribute(config, "EngineOutputMaxMultiplier", 1.48, 0.2, 3))
	local weightReference = numberAttribute(config, "WeightReference", 118, 1, 400)
	local weightFactor = curveMultiplier(weightReference / math.max(stats.Weight or weightReference, 1), 1,
		numberAttribute(config, "WeightAccelerationExponent", 0.22, 0, 1.5),
		numberAttribute(config, "WeightAccelerationMinMultiplier", 0.82, 0.2, 2),
		numberAttribute(config, "WeightAccelerationMaxMultiplier", 1.18, 0.2, 3))
	local launchEnd = numberAttribute(config, "LaunchRampEndMph", 14, 1, 60)
	local launchAlpha = smoothstep(math.max(forwardMph, 0) / launchEnd)
	local launchMultiplier = numberAttribute(config, "LaunchAccelerationMultiplier", 0.45, 0.1, 1)
	local launchShape = launchMultiplier + (1 - launchMultiplier) * launchAlpha
	local launchEngineInfluence = numberAttribute(config, "LaunchEngineInfluence", 0.35, 0, 1)
	local engineInfluence = launchEngineInfluence + (1 - launchEngineInfluence) * launchAlpha
	local effectiveEngineFactor = 1 + (engineFactor - 1) * engineInfluence
	local engineAlpha = math.clamp((engineFactor - numberAttribute(config,"EngineOutputMinMultiplier",0.72,0.2,2)) / math.max(numberAttribute(config,"EngineOutputMaxMultiplier",1.48,0.2,3)-numberAttribute(config,"EngineOutputMinMultiplier",0.72,0.2,2),0.001),0,1)
	local bandStart = numberAttribute(config, "PowerBandStartRatioLow", 0.48, 0.1, 0.9) + (numberAttribute(config, "PowerBandStartRatioHigh", 0.70, 0.1, 0.95)-numberAttribute(config, "PowerBandStartRatioLow", 0.48, 0.1, 0.9))*engineAlpha
	local speedRatio = math.clamp(math.max(forwardMph,0)/maxMph,0,1)
	local highAlpha = smoothstep((speedRatio-bandStart)/math.max(1-bandStart,0.05))
	local highFloor = numberAttribute(config, "HighSpeedAccelerationFloor", 0.06, 0, 0.5)
	local highFade = highFloor + (1-highFloor)*((1-highAlpha)^numberAttribute(config,"HighSpeedAccelerationExponent",0.80,0.1,3))
	local forwardAcceleration = numberAttribute(config,"BaseForwardAcceleration",32,5,80)*effectiveEngineFactor*weightFactor*launchShape*highFade*balance.Acceleration

	local brakeReference = numberAttribute(config,"BrakingForceReference",60,1,200)
	local brakingFactor = curveMultiplier(stats.BrakingForce,brakeReference,numberAttribute(config,"BrakingForceExponent",0.7,0.1,2),0.65,1.65)
	local brakeWeightFactor = math.clamp((weightReference/math.max(stats.Weight or weightReference,1))^numberAttribute(config,"BrakeWeightExponent",0.2,0,1),0.8,1.2)
	local brakeAcceleration = numberAttribute(config,"BaseBrakeDeceleration",30,8,90)*brakingFactor*brakeWeightFactor*balance.Braking
	local dragFactor = curveMultiplier(stats.Drag,numberAttribute(config,"DragReference",50,1,100),numberAttribute(config,"AerodynamicDragStatExponent",0.35,0,1),0.65,1.45)
	local aeroAcceleration = numberAttribute(config,"AerodynamicDragPerMphSquared",0.00012,0,0.002)*forwardMph*math.abs(forwardMph)*dragFactor*balance.Drag
	local reverseAcceleration = numberAttribute(config,"ReverseAcceleration",12,2,40)*engineFactor*weightFactor*balance.Reverse
	local reverseRatio = math.clamp(math.abs(math.min(forwardMph,0))/reverseMaxMph,0,1)
	local reverseCurve = (1-reverseRatio)^numberAttribute(config,"ReverseCurveExponent",0.8,0.1,3)
	local acceleration = -aeroAcceleration / MPH_PER_STUD
	-- Drivetrain feel: a car whose class has an active drivetrain takes the gearbox step. Every other car (no
	-- params.Drivetrain) continues below exactly as before.
	local drivetrain = params.Drivetrain
	if drivetrain and drivetrain.Active and drivetrain.Profile and drivetrain.Tuning then
		return Model.StepDrivetrain(params, drivetrain, dt, throttle, forwardSpeed, forwardMph, absoluteMph, maxMph, reverseMaxMph, deadzone, stopThresholdMph, autoHoldMph, reverseDelay, reverseHoldTimer, brakeAcceleration, reverseAcceleration, reverseCurve, aeroAcceleration, config)
	end
	local mode, braking, accelerating, snapForwardStop = "Coasting", false, false, false
	if throttle > deadzone then
		reverseHoldTimer=0
		if forwardMph < -stopThresholdMph then mode="Braking"; braking=true; acceleration+=brakeAcceleration*throttle else mode="Forward"; accelerating=true; acceleration+=forwardAcceleration*throttle end
	elseif throttle < -deadzone then
		if forwardMph > stopThresholdMph then reverseHoldTimer=0; mode="Braking"; braking=true; acceleration-=brakeAcceleration*math.abs(throttle)
		elseif absoluteMph <= stopThresholdMph then reverseHoldTimer+=dt; if reverseHoldTimer>=reverseDelay then mode="Reverse"; accelerating=true; acceleration-=reverseAcceleration*math.abs(throttle) else mode="Stopped"; snapForwardStop=true end
		else mode="Reverse"; accelerating=true; acceleration-=reverseAcceleration*math.abs(throttle)*reverseCurve end
	else
		reverseHoldTimer=0
		if absoluteMph<=autoHoldMph then mode="Stopped"; snapForwardStop=true else acceleration+=oppositeSignAcceleration(forwardSpeed,numberAttribute(config,"CoastBaseDeceleration",3.2,0,20)+math.abs(forwardSpeed)*numberAttribute(config,"CoastSpeedCoefficient",0.03,0,0.2)) end
	end
	local limiter=numberAttribute(config,"SoftLimiterStrength",2.5,0.1,20)
	if forwardMph>maxMph then acceleration-=((forwardMph-maxMph)/MPH_PER_STUD)*limiter elseif forwardMph < -reverseMaxMph then acceleration+=((math.abs(forwardMph)-reverseMaxMph)/MPH_PER_STUD)*limiter end
	local vehicle=params.Vehicle
	if vehicle and boolAttribute(config,"DebugAttributes",true) then
		vehicle:SetAttribute("DynamicsMode",mode); vehicle:SetAttribute("DynamicsForwardMph",forwardMph); vehicle:SetAttribute("DynamicsLongitudinalAcceleration",acceleration)
		vehicle:SetAttribute("DynamicsLaunchFactor",launchShape); vehicle:SetAttribute("DynamicsPowerBandStartRatio",bandStart); vehicle:SetAttribute("DynamicsHighSpeedAccelerationFactor",highFade)
		vehicle:SetAttribute("DynamicsEngineFactor",engineFactor); vehicle:SetAttribute("DynamicsWeightFactor",weightFactor); vehicle:SetAttribute("DynamicsAeroAcceleration",aeroAcceleration/MPH_PER_STUD); vehicle:SetAttribute("DynamicsReverseHoldTimer",reverseHoldTimer)
	end
	return {Enabled=true,ReverseHoldTimer=reverseHoldTimer,LongitudinalAcceleration=acceleration,Accelerating=accelerating,Braking=braking,SnapForwardStop=snapForwardStop,Mode=mode}
end

function Model.StepHandling(params)
	local config=configFolder()
	if not boolAttribute(config,"Enabled",true) or not boolAttribute(config,"HandlingEnabled",true) then return {Enabled=false} end
	local stats=params.Stats or {}; local vehicle=params.Vehicle; local speedMph=math.max(tonumber(params.SpeedMph) or 0,0); local driftBlend=math.clamp(tonumber(params.DriftBlend) or 0,0,1)
	local balance=Model.Balance(vehicle)
	local lateralFactor=curveMultiplier(stats.LateralGrip,numberAttribute(config,"LateralGripReference",50,1,300),numberAttribute(config,"LateralGripExponent",0.40,0.05,2),numberAttribute(config,"LateralGripMinMultiplier",0.82,0.2,2),numberAttribute(config,"LateralGripMaxMultiplier",1.22,0.2,3))
	local downforceReference=numberAttribute(config,"DownforceReference",50,1,300); local speedAlpha=math.clamp(speedMph/numberAttribute(config,"HighSpeedGripMph",140,20,300),0,1)
	local downforceFactor=math.clamp(1+((stats.Downforce or downforceReference)-downforceReference)/downforceReference*numberAttribute(config,"DownforceGripInfluence",0.22,0,1)*speedAlpha,0.88,1.15)
	local driftGripFactor=curveMultiplier(stats.DriftGrip,numberAttribute(config,"DriftGripReference",50,1,300),numberAttribute(config,"DriftGripExponent",0.35,0.05,2),0.85,1.25)
	local driftControlFactor=curveMultiplier(stats.RawDriftControl or stats.DriftControl,numberAttribute(config,"DriftControlReference",50,1,300),numberAttribute(config,"DriftControlExponent",0.32,0.05,2),0.88,1.25)
	local driftChargeFactor=curveMultiplier(stats.DriftChargeRate,numberAttribute(config,"DriftChargeReference",50,1,300),numberAttribute(config,"DriftChargeExponent",0.35,0.05,2),0.80,1.30)
	local stabilityFactor=curveMultiplier(stats.HoverStability,numberAttribute(config,"HoverStabilityReference",50,1,300),numberAttribute(config,"HoverStabilityExponent",0.25,0.05,2),0.88,1.15)
	local normalGrip=numberAttribute(config,"BaseNormalLateralGrip",6.6,1,20)*lateralFactor*downforceFactor*balance.Grip
	local driftGrip=numberAttribute(config,"BaseDriftLateralGrip",2.0,0.1,8)*driftGripFactor
	local lateralGrip=normalGrip+(driftGrip-normalGrip)*driftBlend
	local engineDriftFactor=curveMultiplier(stats.EngineOutput,numberAttribute(config,"EngineOutputReference",60,1,300),0.30,0.85,1.22)
	local result={Enabled=true,LateralGrip=lateralGrip,DriftSideForce=numberAttribute(config,"BaseDriftSideForce",26,5,100)*driftControlFactor*balance.DriftSideForce,DriftTurnMultiplier=driftControlFactor*balance.DriftTurn,DriftChargeMultiplier=driftChargeFactor*balance.DriftCharge,AlignResponsiveness=numberAttribute(config,"BaseAlignResponsiveness",22,4,60)*stabilityFactor,DriftEngineAssist=numberAttribute(config,"DriftEngineAssist",0.20,0,1)*engineDriftFactor*balance.DriftEngineAssist,DriftVelocityAlignmentRate=numberAttribute(config,"DriftVelocityAlignmentRate",2.0,0,10)*driftControlFactor*balance.DriftAlignment,DriftVelocityAlignmentMaxAcceleration=numberAttribute(config,"DriftVelocityAlignmentMaxAcceleration",30,1,100)*driftGripFactor*balance.DriftAlignment,NormalGrip=normalGrip,DownforceFactor=downforceFactor}
	if vehicle and boolAttribute(config,"DebugAttributes",true) then vehicle:SetAttribute("DynamicsLateralGrip",lateralGrip); vehicle:SetAttribute("DynamicsNormalGrip",normalGrip); vehicle:SetAttribute("DynamicsDriftGrip",driftGrip); vehicle:SetAttribute("DynamicsDriftControlFactor",driftControlFactor); vehicle:SetAttribute("DynamicsDriftChargeFactor",driftChargeFactor); vehicle:SetAttribute("DynamicsDownforceFactor",downforceFactor); vehicle:SetAttribute("DynamicsHoverStabilityFactor",stabilityFactor); vehicle:SetAttribute("DynamicsDriftEngineAssist",result.DriftEngineAssist); vehicle:SetAttribute("DynamicsDriftVelocityAlignmentRate",result.DriftVelocityAlignmentRate) end
	return result
end

-- Drivetrain feel (scripts/drivetrain_feel/CONTRACT.md): an automatic gearbox with rpm, traction, shaped boost, and the
-- chassis and spin tuning, per vehicle class, read from Config.Vehicles.Drivetrain.<CategoryId>. A class with no
-- folder, or with Enabled 0, or Drivetrain@Enabled 0, never reaches any of this.
local G_STUDS = 35.1 -- 1 g in studs/s^2 (0.625 mph per stud/s)
local DRIVETRAIN_DEFAULT_RATIOS = "3.15,2.18,1.66,1.33,1.10,0.93,0.80"
local DRIVETRAIN_DEFAULT_CURVE = "0:0.55,0.3:0.80,0.5:0.93,0.7:1,0.85:0.98,1:0.86"
local LUG_FRACTION = 0.2 -- below this fraction of redline with throttle held, step down one gear
-- {attribute, default, minimum, maximum}. Defaults equal the shipped Drivetrain.exotic values, so a missing attribute
-- keeps the designed feel. Read with GetAttributes() about 4 times a second, only rebuilt when something changed.
local DRIVETRAIN_NUMBERS = table.freeze({
	{"FeelWeight", 1, 0, 2.5}, {"FeelGearing", 1, 0, 2}, {"FeelAcceleration", 1, 0.5, 1.5}, {"FeelGrip", 1, 0.6, 1.6},
	{"FeelSpin", 1, 0, 2.5}, {"FeelEngineBrake", 1, 0, 2},
	{"GearCount", 7, 1, 9}, {"IdleRpm", 1100, 300, 4000}, {"RedlineRpm", 8500, 2000, 20000}, {"LimiterRpm", 8600, 2000, 24000},
	{"GearTorqueExponent", 0.8, 0, 2}, {"TopGearOverspeed", 1.06, 1, 1.5}, {"LaunchRpmFraction", 0.5, 0, 1},
	{"EngineRiseSeconds", 0.06, 0.01, 1}, {"EngineFallScale", 1.5, 0.2, 5}, {"ShiftRpmSeconds", 0.05, 0.005, 1},
	{"ThrustSlipFlare", 0.6, 0, 2}, {"ShiftCutSeconds", 0.06, 0, 0.5}, {"ShiftCutTorque", 0.45, 0, 1},
	{"ShiftBlendSeconds", 0.06, 0, 0.5}, {"DownshiftBlendSeconds", 0.08, 0.01, 0.5}, {"ShiftMinIntervalSeconds", 0.25, 0.05, 2},
	{"UpshiftFlat", 0.97, 0.5, 1}, {"UpshiftPartLow", 0.62, 0.3, 1}, {"UpshiftPartHigh", 0.85, 0.3, 1},
	{"UpshiftCruise", 0.45, 0.2, 1}, {"CruiseThrottleMin", 0.05, 0, 0.3}, {"UpshiftMinLand", 0.33, 0, 0.9},
	{"LiftHoldSeconds", 0.8, 0, 3}, {"DownshiftBrakeLand", 0.82, 0.3, 1}, {"DownshiftCoastFraction", 0.3, 0, 0.9},
	{"DownshiftCoastLand", 0.65, 0.3, 1}, {"KickdownThrottle", 0.95, 0.5, 1}, {"KickdownBelowFraction", 0.45, 0, 1},
	{"KickdownLand", 0.88, 0.3, 1}, {"KickdownHoldSeconds", 0.12, 0, 1}, {"StopGearMph", 3, 0, 20},
	{"LimiterOnSeconds", 0.03, 0.005, 0.5}, {"LimiterCutSeconds", 0.045, 0, 0.5}, {"LimiterHysteresisRpm", 150, 0, 2000},
	{"NeutralRevTarget", 1.02, 0, 1.2},
	{"TractionG", 1.15, 0.3, 4}, {"TractionGripExponent", 0.15, 0, 1}, {"TractionTierBonusG", 0.25, 0, 2},
	{"TierStartPI", 250, 0, 2000}, {"TierFullPI", 750, 0, 2000}, {"TractionAssist", 0.35, 0, 1}, {"SlideGripFraction", 0.88, 0.3, 1},
	{"RollingDecel", 0.8, 0, 10}, {"RollingDecelPerStud", 0.004, 0, 0.1}, {"EngineBrakeDecel", 1.5, 0, 20},
	{"BrakeDecel", 70, 5, 200}, {"BrakeForceExponent", 0.35, 0, 2}, {"BrakeFactorMin", 0.75, 0.1, 3}, {"BrakeFactorMax", 1.4, 0.1, 3},
	{"BoostShareMin", 0.15, 0, 1}, {"SpeedGuardStrength", 2, 0, 20}, {"SpeedGuardOverBoostTop", 1.03, 1, 1.5},
	{"SteerRiseSeconds", 0.2, 0, 1}, {"SteerReturnRate", 14, 1, 100}, {"TouchSteerRate", 10, 1, 100},
	{"YawOmega", 9, 1, 60}, {"YawDamping", 0.75, 0.1, 2}, {"YawWeightExponent", 0.5, 0, 2}, {"YawWeightMin", 0.75, 0.2, 2},
	{"YawWeightMax", 1.3, 0.2, 3}, {"YawKinematicBelowMph", 15, 0, 80}, {"YawUnwindScale", 2, 0.5, 5}, {"YawRateMax", 5, 0.5, 5},
	{"LateralCapG", 3.4, 0.5, 20}, {"LateralCapGripExponent", 0.25, 0, 1}, {"LateralCurveShape", 1.4, 1, 1.9},
	{"YawCapMargin", 0.9, 0.3, 3}, {"GripRelaxStuds", 2, 0, 20},
	{"PitchDegreesPerG", 2.4, 0, 10}, {"PitchMaxDegrees", 5, 0, 15}, {"PitchOmega", 9, 1, 40}, {"PitchDamping", 0.6, 0.1, 2},
	{"RollDegreesPerG", 0.9, -5, 5}, {"RollMaxDegrees", 3, 0, 10}, {"ImpactYawKick", 0.6, 0, 5},
	{"SpinStabSeconds", 0.4, 0, 2}, {"SpinStabSteer", 0.8, 0, 1}, {"SpinAnalogRate", 4, 0.5, 50}, {"SpinWindowSeconds", 0.7, 0, 5},
	{"PowerBrakeMinHold", 0.3, 0, 5}, {"PowerBrakeDumpSlip", 0.5, 0, 2},
	{"SpinBelowMph", 25, 0, 100}, {"SpinFadeMph", 12, 0.5, 100}, {"SpinSteerStart", 0.6, 0, 1}, {"SpinSteerWidth", 0.35, 0.01, 1},
	{"SpinSlipStart", 0.12, 0, 2}, {"SpinSlipWidth", 0.25, 0.01, 2},
	{"SpinBuildRate", 3.5, 0, 30}, {"SpinDecayRate", 2.5, 0, 30}, {"SpinCatchRate", 8, 0, 60}, {"SpinSettleSeconds", 0.3, 0, 3},
	{"SpinYawAccel", 7, 0, 40}, {"SpinMaxYawRate", 3.6, 0, 5}, {"SpinGripLoss", 0.7, 0, 1}, {"SpinThrustLoss", 0.35, 0, 1},
	{"SpinYawAuthorityLoss", 0.85, 0, 1}, {"SpinHoldCap", 0.35, 0, 1}, {"SpinTierFloor", 0.5, 0, 1}, {"SpinTouchScale", 0.5, 0, 2},
	{"SpinStartGraceSeconds", 3, 0, 30}, {"SpinStartGraceMph", 38, 0, 200}, {"SpinWarnLevel", 0.25, 0, 1},
	{"HudRedlineSweep", 0.87, 0.5, 1}, {"HudShiftLeadSeconds", 0.25, 0, 2}, {"HudShiftMinFraction", 0.85, 0, 1}, {"HudWarmBandFraction", 0.12, 0, 0.5},
})
-- 0/1 number switches (a boolean is accepted too); a missing switch counts as 1.
local DRIVETRAIN_SWITCHES = table.freeze({"NeutralRevEnabled", "BoostShapeEnabled", "OverdriveEnabled", "DriftCapExempt", "SpinEnabled", "PowerBrakeEnabled"})
local drivetrainTunings = {} -- [categoryId] = tuning table, changed in place
local drivetrainProfiles = setmetatable({}, {__mode = "k"}) -- [vehicle] = {CheckedAt, Tuning, PI, Profile}
local quietProfiles = setmetatable({}, {__mode = "k"}) -- the same for remote (quiet) callers, kept apart
local remoteGears = setmetatable({}, {__mode = "k"}) -- [vehicle] = {CheckedAt, PI, Revision, Profile, Legacy}

local function drivetrainRoot()
	local config = ReplicatedStorage:FindFirstChild("Config")
	local vehicles = config and config:FindFirstChild("Vehicles")
	return vehicles and vehicles:FindFirstChild("Drivetrain")
end

local function switchOn(value, fallback)
	if typeof(value) == "number" then return value == value and value >= 0.5 end
	if typeof(value) == "boolean" then return value end
	return fallback
end

local function parseRatios(text, out)
	table.clear(out)
	for token in string.gmatch(text, "[^,%s]+") do
		local value = tonumber(token)
		if value and value == value and value > 0 and value < 100 and #out < 9 then out[#out + 1] = value end
	end
	table.sort(out, function(a, b) return a > b end)
	local kept = 0
	for index = 1, #out do
		if kept == 0 or out[index] < out[kept] * 0.995 then
			kept += 1
			out[kept] = out[index]
		end
	end
	for index = #out, kept + 1, -1 do out[index] = nil end
	return kept
end

local function parseCurve(text, xs, ys)
	table.clear(xs)
	table.clear(ys)
	for a, b in string.gmatch(text, "([%-%d%.]+)%s*:%s*([%-%d%.]+)") do
		local x, y = tonumber(a), tonumber(b)
		if x and y and x == x and y == y and #xs < 32 then
			x, y = math.clamp(x, 0, 1.5), math.clamp(y, 0, 2)
			local at = #xs + 1
			while at > 1 and xs[at - 1] > x do
				xs[at], ys[at] = xs[at - 1], ys[at - 1]
				at -= 1
			end
			xs[at], ys[at] = x, y
		end
	end
	return #xs
end

local function curveAt(xs, ys, x)
	local count = #xs
	if count == 0 then return 1 end
	if x <= xs[1] then return ys[1] end
	for index = 2, count do
		if x <= xs[index] then
			local x0, x1 = xs[index - 1], xs[index]
			local alpha = x1 > x0 and (x - x0) / (x1 - x0) or 1
			return ys[index - 1] + (ys[index] - ys[index - 1]) * alpha
		end
	end
	return ys[count]
end

-- Torque fraction at rpm/redline. FeelGearing below 1 flattens the curve toward its peak (0 = CVT-smooth).
local function profileTorque(profile, x)
	local tuning = profile.Tuning
	return 1 + (curveAt(tuning.CurveX, tuning.CurveY, x) - 1) * profile.CurveDepth
end

local function rebuildTuning(tuning)
	local raw = tuning.Raw
	for _, spec in ipairs(DRIVETRAIN_NUMBERS) do
		local value = raw[spec[1]]
		if typeof(value) ~= "number" or value ~= value then value = spec[2] end
		tuning[spec[1]] = math.clamp(value, spec[3], spec[4])
	end
	for _, name in ipairs(DRIVETRAIN_SWITCHES) do tuning[name] = switchOn(raw[name], true) end
	tuning.LimiterRpm = math.clamp(tuning.LimiterRpm, tuning.RedlineRpm, tuning.RedlineRpm * 1.2)
	tuning.IdleRpm = math.min(tuning.IdleRpm, tuning.RedlineRpm * 0.5)
	tuning.UpshiftPartHigh = math.max(tuning.UpshiftPartHigh, tuning.UpshiftPartLow)
	tuning.TierFullPI = math.max(tuning.TierFullPI, tuning.TierStartPI + 1)
	tuning.BrakeFactorMax = math.max(tuning.BrakeFactorMax, tuning.BrakeFactorMin)
	tuning.YawWeightMax = math.max(tuning.YawWeightMax, tuning.YawWeightMin)
	tuning.SpinMaxYawRate = math.min(tuning.SpinMaxYawRate, tuning.YawRateMax)
	-- Strings are parsed only when their text changed.
	local ratioText = typeof(raw.GearRatios) == "string" and raw.GearRatios or DRIVETRAIN_DEFAULT_RATIOS
	if ratioText ~= tuning.RatioText then
		tuning.RatioText = ratioText
		if parseRatios(ratioText, tuning.Ratios) == 0 then parseRatios(DRIVETRAIN_DEFAULT_RATIOS, tuning.Ratios) end
	end
	local curveText = typeof(raw.TorqueCurve) == "string" and raw.TorqueCurve or DRIVETRAIN_DEFAULT_CURVE
	if curveText ~= tuning.CurveText then
		tuning.CurveText = curveText
		if parseCurve(curveText, tuning.CurveX, tuning.CurveY) < 2 then parseCurve(DRIVETRAIN_DEFAULT_CURVE, tuning.CurveX, tuning.CurveY) end
	end
	tuning.Gears = math.clamp(math.floor(tuning.GearCount + 0.5), 1, #tuning.Ratios)
end

-- The class of a vehicle: its CategoryId attribute, else the CockpitId prefix before "_" (lower case).
function Model.DrivetrainCategory(vehicle)
	if not vehicle then return nil end
	local id = vehicle:GetAttribute("CategoryId")
	if typeof(id) == "string" and id ~= "" then return string.lower(id) end
	local cockpit = vehicle:GetAttribute("CockpitId")
	if typeof(cockpit) == "string" and cockpit ~= "" then return string.lower(string.match(cockpit, "^([^_]+)_") or cockpit) end
	return nil
end

-- One tuning table per class, shared by the local car and remote cars. Re-read at most every 0.25 s (force: now).
-- tuning.Active is false when the class folder is missing or switched off; tuning.Revision counts changes.
function Model.DrivetrainTuning(categoryId, force)
	if typeof(categoryId) ~= "string" or categoryId == "" then return nil end
	local tuning = drivetrainTunings[categoryId]
	local now = os.clock()
	if tuning and not force and now - tuning.ReadAt < 0.25 then return tuning end
	if not tuning then
		tuning = {Raw = {}, RawCount = -1, Ratios = {}, CurveX = {}, CurveY = {}, Revision = 0, ReadAt = 0, Active = false, Folder = nil}
		drivetrainTunings[categoryId] = tuning
		rebuildTuning(tuning)
	end
	tuning.ReadAt = now
	local root = drivetrainRoot()
	local folder = root and root:FindFirstChild(categoryId)
	local active = folder ~= nil and folder:IsA("Folder") and switchOn(root:GetAttribute("Enabled"), true) and switchOn(folder:GetAttribute("Enabled"), true)
	local changed = folder ~= tuning.Folder or active ~= tuning.Active
	tuning.Folder = folder
	tuning.Active = active
	if active then
		local attributes = folder:GetAttributes()
		local raw, count = tuning.Raw, 0
		for name, value in pairs(attributes) do
			count += 1
			if raw[name] ~= value then changed = true end
		end
		if count ~= tuning.RawCount then changed = true end
		if changed then
			table.clear(raw)
			for name, value in pairs(attributes) do raw[name] = value end
			tuning.RawCount = count
			rebuildTuning(tuning)
		end
	end
	if changed then tuning.Revision += 1 end
	return tuning
end

local function profileStale(profile, tuning, index, maxMph, balance, stats)
	return profile.Tuning ~= tuning or profile.Revision ~= tuning.Revision or profile.PI ~= index or profile.MaxMph ~= maxMph
		or profile.BalanceAcceleration ~= balance.Acceleration or profile.BalanceDrag ~= balance.Drag or profile.BalanceBoost ~= balance.Boost
		or profile.BalanceBraking ~= balance.Braking or profile.EngineOutput ~= stats.EngineOutput or profile.Weight ~= stats.Weight
		or profile.BoostForce ~= stats.BoostForce or profile.Drag ~= stats.Drag or profile.BrakingForce ~= stats.BrakingForce
		or profile.LateralGrip ~= stats.LateralGrip
end

local function buildProfile(profile, tuning, stats, balance, maxMph, index, vehicle, quiet)
	local config = configFolder()
	profile.Tuning, profile.Revision, profile.PI, profile.MaxMph = tuning, tuning.Revision, index, maxMph
	profile.BalanceAcceleration, profile.BalanceDrag, profile.BalanceBoost, profile.BalanceBraking = balance.Acceleration, balance.Drag, balance.Boost, balance.Braking
	profile.EngineOutput, profile.Weight, profile.BoostForce, profile.Drag, profile.BrakingForce, profile.LateralGrip = stats.EngineOutput, stats.Weight, stats.BoostForce, stats.Drag, stats.BrakingForce, stats.LateralGrip
	-- Today's forward and drag terms (StepLongitudinal), evaluated at full throttle, give the speeds to keep: Vt (top
	-- speed) and Vb (boosted top). Every stat, clamp and Balance coupling therefore works as it does now.
	local engineMin = numberAttribute(config, "EngineOutputMinMultiplier", 0.72, 0.2, 2)
	local engineMax = numberAttribute(config, "EngineOutputMaxMultiplier", 1.48, 0.2, 3)
	local engineFactor = curveMultiplier(stats.EngineOutput, numberAttribute(config, "EngineOutputReference", 60, 1, 300),
		numberAttribute(config, "EngineOutputExponent", 0.55, 0.05, 2), engineMin, engineMax)
	local weightReference = numberAttribute(config, "WeightReference", 118, 1, 400)
	local weight = math.max(tonumber(stats.Weight) or weightReference, 1)
	local weightFactor = curveMultiplier(weightReference / weight, 1,
		numberAttribute(config, "WeightAccelerationExponent", 0.22, 0, 1.5),
		numberAttribute(config, "WeightAccelerationMinMultiplier", 0.82, 0.2, 2),
		numberAttribute(config, "WeightAccelerationMaxMultiplier", 1.18, 0.2, 3))
	local launchEnd = numberAttribute(config, "LaunchRampEndMph", 14, 1, 60)
	local launchMultiplier = numberAttribute(config, "LaunchAccelerationMultiplier", 0.45, 0.1, 1)
	local launchEngineInfluence = numberAttribute(config, "LaunchEngineInfluence", 0.35, 0, 1)
	local engineAlpha = math.clamp((engineFactor - engineMin) / math.max(engineMax - engineMin, 0.001), 0, 1)
	local bandLow = numberAttribute(config, "PowerBandStartRatioLow", 0.48, 0.1, 0.9)
	local bandStart = bandLow + (numberAttribute(config, "PowerBandStartRatioHigh", 0.70, 0.1, 0.95) - bandLow) * engineAlpha
	local highFloor = numberAttribute(config, "HighSpeedAccelerationFloor", 0.06, 0, 0.5)
	local highExponent = numberAttribute(config, "HighSpeedAccelerationExponent", 0.80, 0.1, 3)
	local baseForward = numberAttribute(config, "BaseForwardAcceleration", 32, 5, 80)
	local dragFactor = curveMultiplier(stats.Drag, numberAttribute(config, "DragReference", 50, 1, 100), numberAttribute(config, "AerodynamicDragStatExponent", 0.35, 0, 1), 0.65, 1.45)
	local aero = numberAttribute(config, "AerodynamicDragPerMphSquared", 0.00012, 0, 0.002) * dragFactor * balance.Drag
	local softLimiter = numberAttribute(config, "SoftLimiterStrength", 2.5, 0.1, 20)
	local function todayNet(mph, extra)
		local launchAlpha = smoothstep(math.max(mph, 0) / launchEnd)
		local launchShape = launchMultiplier + (1 - launchMultiplier) * launchAlpha
		local effectiveEngineFactor = 1 + (engineFactor - 1) * (launchEngineInfluence + (1 - launchEngineInfluence) * launchAlpha)
		local highAlpha = smoothstep((math.clamp(math.max(mph, 0) / maxMph, 0, 1) - bandStart) / math.max(1 - bandStart, 0.05))
		local highFade = highFloor + (1 - highFloor) * ((1 - highAlpha) ^ highExponent)
		local net = baseForward * effectiveEngineFactor * weightFactor * launchShape * highFade * balance.Acceleration + extra - aero * mph * math.abs(mph) / MPH_PER_STUD
		if mph > maxMph then net -= (mph - maxMph) / MPH_PER_STUD * softLimiter end
		return net
	end
	local function solveTop(extra)
		local low, high = 0, maxMph * 2 + 60
		if todayNet(high, extra) > 0 then return high end
		for _ = 1, 40 do
			local middle = (low + high) * 0.5
			if todayNet(middle, extra) > 0 then low = middle else high = middle end
		end
		return (low + high) * 0.5
	end
	local boostPower = math.max(tonumber(stats.BoostForce) or 0, 0)
	local boostToday = boostPower > 0 and (boostPower + 32) * 0.75 * balance.Boost or 0
	local vt = math.max(solveTop(0), 5)
	local vb = boostToday > 0 and math.max(solveTop(boostToday), vt) or vt
	profile.Vt, profile.Vb, profile.BoostToday = vt, vb, boostToday
	-- Gear redline speeds from this car's own top speed: top gear runs out TopGearOverspeed above Vt, so the top
	-- speed stays drag-limited. Thrust per gear falls as (ratio / first ratio) ^ (GearTorqueExponent x FeelGearing).
	local ratios, count = tuning.Ratios, tuning.Gears
	local gearing = tuning.FeelGearing
	local exponent = tuning.GearTorqueExponent * gearing
	table.clear(profile.Speeds)
	table.clear(profile.Mult)
	for gear = 1, count do
		profile.Speeds[gear] = vt * tuning.TopGearOverspeed * ratios[count] / ratios[gear]
		profile.Mult[gear] = (ratios[gear] / ratios[1]) ^ exponent
	end
	profile.GearCount = count
	profile.CurveDepth = math.min(gearing, 1)
	profile.A1 = baseForward * engineFactor * weightFactor * balance.Acceleration * tuning.FeelAcceleration
	profile.TierAlpha = smoothstep(((index or numberAttribute(config, "BalanceFallbackPerformanceIndex", 525, 0, 2000)) - tuning.TierStartPI) / (tuning.TierFullPI - tuning.TierStartPI))
	local gripRatio = math.max(tonumber(stats.LateralGrip) or 50, 0.001) / 50
	profile.Traction = (tuning.TractionG + tuning.TractionTierBonusG * profile.TierAlpha) * G_STUDS * math.clamp(gripRatio ^ tuning.TractionGripExponent, 0.9, 1.15) * tuning.FeelGrip
	-- Drag derived so that top-gear thrust at Vt balances resistance at Vt: the real top speed is today's.
	local topDrive = math.min(profile.A1 * profile.Mult[count] * profileTorque(profile, 1 / tuning.TopGearOverspeed), profile.Traction)
	profile.Kd = math.max(topDrive - tuning.RollingDecel - tuning.RollingDecelPerStud * vt / MPH_PER_STUD, 0.5) / (vt * vt)
	-- Boost fades with speed so the boosted top stays at today's Vb (Overdrive holds top-gear thrust at redline).
	local share = 1
	if tuning.BoostShapeEnabled and boostToday > 0 then
		local x = vb / profile.Speeds[count]
		local engine = profile.A1 * profile.Mult[count] * profileTorque(profile, math.min(x, 1))
		if x >= 1 and not tuning.OverdriveEnabled then engine *= tuning.LimiterOnSeconds / math.max(tuning.LimiterOnSeconds + tuning.LimiterCutSeconds, 0.001) end
		engine = math.min(engine, profile.Traction)
		local resistance = profile.Kd * vb * vb + tuning.RollingDecel + tuning.RollingDecelPerStud * vb / MPH_PER_STUD
		share = math.clamp((resistance - engine) / boostToday, tuning.BoostShareMin, 1)
	end
	profile.BoostShareHigh = share
	local brakeFactor = math.clamp((math.max(tonumber(stats.BrakingForce) or 60, 0.001) / numberAttribute(config, "BrakingForceReference", 60, 1, 200)) ^ tuning.BrakeForceExponent, tuning.BrakeFactorMin, tuning.BrakeFactorMax)
	profile.BrakeV2 = tuning.BrakeDecel * brakeFactor * math.clamp((weightReference / weight) ^ numberAttribute(config, "BrakeWeightExponent", 0.2, 0, 1), 0.8, 1.2) * balance.Braking
	profile.LateralCapBase = tuning.LateralCapG * G_STUDS * math.clamp(gripRatio ^ tuning.LateralCapGripExponent, 0.85, 1.2) * tuning.FeelGrip
	profile.YawOmega = tuning.YawOmega * math.clamp((weightReference / weight) ^ tuning.YawWeightExponent, tuning.YawWeightMin, tuning.YawWeightMax)
	profile.SpinTierScale = tuning.SpinTierFloor + (1 - tuning.SpinTierFloor) * profile.TierAlpha
	if vehicle and not quiet and boolAttribute(config, "DebugAttributes", true) then
		local text = ""
		for gear = 1, count do text ..= string.format("%s%.0f", gear > 1 and "/" or "", profile.Speeds[gear]) end
		vehicle:SetAttribute("DynamicsDesignTopMph", math.floor(vt * 10 + 0.5) / 10)
		vehicle:SetAttribute("DynamicsBoostTopMph", math.floor(vb * 10 + 0.5) / 10)
		vehicle:SetAttribute("DynamicsGearRedlineMph", text)
		vehicle:SetAttribute("DynamicsTraction", math.floor(profile.Traction * 10 + 0.5) / 10)
		vehicle:SetAttribute("DynamicsDrivetrainDrag", profile.Kd)
		vehicle:SetAttribute("DynamicsBoostShareHigh", math.floor(share * 1000 + 0.5) / 1000)
		vehicle:SetAttribute("DynamicsBrakeV2", math.floor(profile.BrakeV2 * 10 + 0.5) / 10)
		vehicle:SetAttribute("DynamicsLateralCapBase", math.floor(profile.LateralCapBase * 10 + 0.5) / 10)
	end
end

-- The per-car drivetrain profile (CONTRACT 5.1), or nil when the vehicle's class has no active drivetrain. Cached per
-- vehicle and rebuilt only when the tuning revision, PerformanceIndex, top speed, Balance or stats change.
-- quiet = true: no SetAttribute (remote cars).
function Model.DrivetrainProfile(vehicle, stats, balance, maxMph, quiet)
	if not vehicle or type(stats) ~= "table" or type(balance) ~= "table" then return nil end
	local cache = quiet and quietProfiles or drivetrainProfiles
	local entry = cache[vehicle]
	local now = os.clock()
	if not entry then
		entry = {CheckedAt = -math.huge, Tuning = nil, PI = nil, Profile = {Speeds = {}, Mult = {}}}
		cache[vehicle] = entry
	end
	if now - entry.CheckedAt >= 0.25 then
		entry.CheckedAt = now
		local category = Model.DrivetrainCategory(vehicle)
		entry.Tuning = category and Model.DrivetrainTuning(category) or nil
		local index = vehicle:GetAttribute("PerformanceIndex")
		entry.PI = typeof(index) == "number" and index == index and index or nil
	end
	local tuning = entry.Tuning
	if not tuning or not tuning.Active then return nil end
	maxMph = math.max(tonumber(maxMph) or 126, 40)
	local profile = entry.Profile
	if profileStale(profile, tuning, entry.PI, maxMph, balance, stats) then
		buildProfile(profile, tuning, stats, balance, maxMph, entry.PI, vehicle, quiet)
	end
	return profile
end

-- Lowest gear that puts this speed at or under 0.9 of its redline.
function Model.DrivetrainSelectGear(profile, mph)
	if not profile or not profile.GearCount then return 1 end
	for gear = 1, profile.GearCount do
		if mph <= profile.Speeds[gear] * 0.9 then return gear end
	end
	return profile.GearCount
end

-- Back to first gear (or N, or the gear that matches the speed when moving) at idle or road rpm, no cut, no limiter.
-- Revision counters are never reset: readers take the first value they see as a baseline.
function Model.ResetGearbox(box, tuning, profile, forwardMph, neutral)
	local gear = 1
	forwardMph = tonumber(forwardMph) or 0
	if neutral then
		gear = 0
	elseif profile and tuning and forwardMph > tuning.StopGearMph then
		gear = Model.DrivetrainSelectGear(profile, forwardMph)
	end
	local idle = tuning and tuning.IdleRpm or 1000
	local rpm = idle
	if gear >= 1 and profile and tuning and profile.Speeds[gear] then rpm = math.clamp(forwardMph / profile.Speeds[gear] * tuning.RedlineRpm, idle, tuning.LimiterRpm) end
	box.Gear, box.Rpm, box.SinceShift, box.ShiftKind = gear, rpm, 10, "None"
	box.LimiterState, box.LimiterClock, box.LiftClock, box.KickClock, box.Overdrive = 0, 0, 10, 0, false
	box.ShiftRevision, box.LimiterRevision = box.ShiftRevision or 0, box.LimiterRevision or 0
	box.LastKind, box.LastStrength = box.LastKind or "Up", box.LastStrength or 0
end

local function beginShift(box, tuning, gear, kind, strength)
	box.Gear, box.SinceShift, box.ShiftKind = gear, 0, kind
	-- The gearing dial also scales how hard a shift is felt (camera nod, audio crackle, vent flame); 0 = CVT-smooth.
	if kind ~= "Launch" then strength *= math.min(tuning.FeelGearing, 1) end
	box.LastKind, box.LastStrength = kind, math.clamp(strength, 0, 1)
	box.ShiftRevision += 1
end

-- Launch: first gear engaged from N or from a power-brake hold, keeping the revved rpm.
function Model.LaunchGearbox(box, strength)
	box.Gear, box.SinceShift, box.ShiftKind = 1, 0, "Launch"
	box.LastKind, box.LastStrength = "Launch", math.clamp(tonumber(strength) or 0, 0, 1)
	box.ShiftRevision += 1
end

-- Integral over [0, t] of the upshift torque multiplier: c during the cut, a linear ramp to 1 over the blend, then 1.
local function cutIntegral(t, cutSeconds, blendSeconds, c)
	if t <= cutSeconds then return c * t end
	local s = t - cutSeconds
	if s < blendSeconds then return c * cutSeconds + c * s + (1 - c) * s * s / (2 * blendSeconds) end
	return c * cutSeconds + c * blendSeconds + (1 - c) * blendSeconds * 0.5 + (s - blendSeconds)
end

-- Bouncing limiter: drive held for onSeconds, then cut for cutSeconds, repeating while over. Returns the share of this
-- frame spent cut, so the duty is the same at any frame rate.
local function stepLimiter(box, over, dt, onSeconds, cutSeconds)
	if not over then
		box.LimiterState, box.LimiterClock = 0, 0
		return 0
	end
	if box.LimiterState == 0 then box.LimiterState, box.LimiterClock = 1, 0 end
	local remaining, cut = dt, 0
	for _ = 1, 16 do
		if remaining <= 0 then break end
		if box.LimiterState == 1 then
			local use = math.min(remaining, math.max(onSeconds - box.LimiterClock, 0))
			box.LimiterClock += use
			remaining -= use
			if box.LimiterClock >= onSeconds then
				if cutSeconds <= 0 then break end
				box.LimiterState, box.LimiterClock = 2, 0
				box.LimiterRevision += 1
			end
		else
			local use = math.min(remaining, math.max(cutSeconds - box.LimiterClock, 0))
			box.LimiterClock += use
			remaining -= use
			cut += use
			if box.LimiterClock >= cutSeconds then box.LimiterState, box.LimiterClock = 1, 0 end
		end
	end
	if dt > 0 then return math.clamp(cut / dt, 0, 1) end
	return box.LimiterState == 2 and 1 or 0
end

local function upshiftPoint(tuning, throttle)
	if throttle >= 0.9 then return tuning.UpshiftFlat end
	if throttle >= 0.3 then return tuning.UpshiftPartLow + (tuning.UpshiftPartHigh - tuning.UpshiftPartLow) * (throttle - 0.3) / 0.6 end
	return tuning.UpshiftCruise
end

-- One frame of the gearbox and longitudinal forces (CONTRACT 5.2). drive is DrivingClient's drivetrain table: its
-- Gearbox and Result tables are changed in place (no allocation). Inputs it reads from drive: SpinAmount, DriftBlend,
-- HorizontalSpeed (studs/s), SteeringIntent, ExtraSlip, PowerBrakeHeld, BoostApplied (last frame).
function Model.StepDrivetrain(params, drive, dt, throttle, forwardSpeed, forwardMph, absoluteMph, maxMph, reverseMaxMph, deadzone, stopThresholdMph, autoHoldMph, reverseDelay, reverseHoldTimer, brakeAcceleration, reverseAcceleration, reverseCurve, aeroAcceleration, config)
	local tuning, profile, box, out = drive.Tuning, drive.Profile, drive.Gearbox, drive.Result
	local redline, idle, limiterRpm = tuning.RedlineRpm, tuning.IdleRpm, tuning.LimiterRpm
	local count, speeds, ratios = profile.GearCount, profile.Speeds, tuning.Ratios
	local gearing = tuning.FeelGearing
	local spin = tonumber(drive.SpinAmount) or 0
	if spin ~= spin then spin = 0 end
	spin = math.clamp(spin, 0, 1)
	local driftBlend = tonumber(drive.DriftBlend) or 0
	if driftBlend ~= driftBlend then driftBlend = 0 end
	driftBlend = math.clamp(driftBlend, 0, 1)
	local horizontal = tonumber(drive.HorizontalSpeed) or 0
	if horizontal ~= horizontal then horizontal = 0 end
	if box.Rpm ~= box.Rpm or box.Gear == nil then Model.ResetGearbox(box, tuning, profile, forwardMph, false) end
	if box.Gear > count then box.Gear = count end -- GearCount lowered while driving

	-- Mode: today's rules. Auto-hold never snaps while the car spins or slides sideways.
	local acceleration = -aeroAcceleration / MPH_PER_STUD
	local mode, braking, accelerating, snapForwardStop = "Coasting", false, false, false
	local driven = 0 -- throttle that drives the engine (Forward mode only)
	if throttle > deadzone then
		reverseHoldTimer = 0
		if forwardMph < -stopThresholdMph then mode = "Braking"; braking = true else mode = "Forward"; accelerating = true; driven = throttle end
	elseif throttle < -deadzone then
		if forwardMph > stopThresholdMph then reverseHoldTimer = 0; mode = "Braking"; braking = true
		elseif absoluteMph <= stopThresholdMph then reverseHoldTimer += dt; if reverseHoldTimer >= reverseDelay then mode = "Reverse"; accelerating = true; acceleration -= reverseAcceleration * math.abs(throttle) else mode = "Stopped"; snapForwardStop = true end
		else mode = "Reverse"; accelerating = true; acceleration -= reverseAcceleration * math.abs(throttle) * reverseCurve end
	else
		reverseHoldTimer = 0
		if absoluteMph <= autoHoldMph and spin <= 0.05 and horizontal <= 4 then mode = "Stopped"; snapForwardStop = true end
	end

	-- Gear: R while reversing (or still rolling back after it), 1st below StopGearMph, else the auto brain.
	local gear = box.Gear
	if mode == "Reverse" then
		gear = -1
	elseif gear == -1 and forwardMph < -stopThresholdMph and mode ~= "Braking" then
		gear = -1
	elseif forwardMph < tuning.StopGearMph then
		gear = 1
	elseif gear < 1 then
		gear = Model.DrivetrainSelectGear(profile, forwardMph)
	end
	box.Gear = gear
	-- Road speed for rpm: forward speed, blended to the whole horizontal speed by the drift.
	local roadMph = math.max(forwardMph, 0)
	roadMph += (horizontal * MPH_PER_STUD - roadMph) * driftBlend
	local ratio = gear >= 1 and roadMph / speeds[gear] or 0

	local positive = math.max(throttle, 0)
	if positive < tuning.CruiseThrottleMin then box.LiftClock = 0 else box.LiftClock += dt end
	if positive >= tuning.KickdownThrottle then box.KickClock += dt else box.KickClock = 0 end
	if gear >= 1 and forwardMph >= tuning.StopGearMph and box.SinceShift >= tuning.ShiftMinIntervalSeconds then
		-- No shifting mid-drift or mid-spin, except an upshift off the limiter.
		local hold = driftBlend > 0.3 or spin > 0.1
		local shifted = false
		if gear < count then
			local up = ratio >= 1
			if not up and not hold and driven > 0 then
				if driven >= 0.9 then
					up = ratio >= tuning.UpshiftFlat
				elseif box.LiftClock >= tuning.LiftHoldSeconds then
					if driven >= 0.3 then
						up = ratio >= upshiftPoint(tuning, driven)
					elseif driven > tuning.CruiseThrottleMin then
						up = ratio >= tuning.UpshiftCruise and ratio * ratios[gear + 1] / ratios[gear] >= tuning.UpshiftMinLand
					end
				end
			end
			if up then
				beginShift(box, tuning, gear + 1, "Up", driven >= 0.9 and 1 or 0.3 + 0.7 * driven)
				shifted = true
			end
		end
		if not shifted and gear > 1 and not hold then
			local land = ratio * ratios[gear - 1] / ratios[gear]
			local target = gear
			if braking and forwardMph > 0 then
				if land <= tuning.DownshiftBrakeLand then target = gear - 1 end
			elseif driven <= tuning.CruiseThrottleMin then
				if ratio < tuning.DownshiftCoastFraction and land <= tuning.DownshiftCoastLand then target = gear - 1 end
			elseif driven >= tuning.KickdownThrottle and box.KickClock >= tuning.KickdownHoldSeconds and ratio < tuning.KickdownBelowFraction then
				for lower = 1, gear - 1 do
					if ratio * ratios[lower] / ratios[gear] <= tuning.KickdownLand then target = lower; break end
				end
			elseif ratio < LUG_FRACTION and land <= tuning.DownshiftCoastLand then
				target = gear - 1
			end
			-- Downshifts never cut torque: a rev-matched blend only (the audio adds the blip).
			if target < gear then beginShift(box, tuning, target, "Down", 0.5) end
		end
		gear = box.Gear
		ratio = roadMph / speeds[gear]
	end
	local rpmRoad = ratio * redline
	-- Overdrive: boosting past top-gear redline pins the engine at redline with no limiter (small hysteresis).
	local overdrive = tuning.OverdriveEnabled and drive.BoostApplied == true and gear >= 1 and gear == count and ratio >= (box.Overdrive and 0.98 or 1)
	box.Overdrive = overdrive

	-- Engine rpm target: road rpm, a clutch-slip launch in first, a free rev while spinning.
	local rpmBase = rpmRoad
	if gear == -1 then
		rpmBase = idle + (0.55 * redline - idle) * math.clamp(math.abs(forwardMph) / 40, 0, 1)
	elseif gear >= 1 then
		local launch = drive.PowerBrakeHeld and 1 or driven
		if gear == 1 and launch > 0 then rpmBase = math.max(rpmBase, idle + launch * (tuning.LaunchRpmFraction * redline - idle)) end
		if spin > 0 then rpmBase += (math.max(0.85 * redline * driven, idle) - rpmBase) * smoothstep(spin / 0.3) end
	end
	rpmBase = math.max(rpmBase, idle)

	-- Thrust (throttle applied once, linear), traction-limited, with the slide loss when the thrust slips.
	local raw = 0
	if driven > 0 and gear >= 1 then raw = profile.A1 * profile.Mult[gear] * profileTorque(profile, (overdrive and redline or box.Rpm) / redline) * driven end
	local traction = profile.Traction
	local slip = 0
	if mode == "Forward" and forwardMph >= -1 and drive.SteeringIntent == 1 then
		slip = math.max(raw / traction - 1, 0) * (1 - tuning.TractionAssist) + math.max(tonumber(drive.ExtraSlip) or 0, 0)
		if slip ~= slip then slip = 0 end
	end
	local thrust = math.min(raw, traction)
	if slip > 0 then thrust *= 1 - (1 - tuning.SlideGripFraction) * smoothstep(slip / 0.6) end

	-- Limiter (never in Overdrive) and the upshift cut, both time-weighted across the frame.
	local hysteresis = tuning.LimiterHysteresisRpm
	local over = not overdrive and gear >= 1 and driven > 0 and rpmRoad >= (box.LimiterState ~= 0 and redline - hysteresis or redline)
	local limiterCut = stepLimiter(box, over, dt, tuning.LimiterOnSeconds, tuning.LimiterCutSeconds)
	local cutSeconds, blendSeconds = tuning.ShiftCutSeconds * gearing, tuning.ShiftBlendSeconds * gearing
	local cutTorque = math.clamp(1 - (1 - tuning.ShiftCutTorque) * gearing, 0, 1)
	local shiftFactor, loadFactor, shiftCut = 1, 1, 0
	if box.ShiftKind == "Up" and box.SinceShift < cutSeconds + blendSeconds then
		local from = box.SinceShift
		if dt > 0 then
			shiftFactor = (cutIntegral(from + dt, cutSeconds, blendSeconds, cutTorque) - cutIntegral(from, cutSeconds, blendSeconds, cutTorque)) / dt
			loadFactor = (cutIntegral(from + dt, cutSeconds, blendSeconds, 0) - cutIntegral(from, cutSeconds, blendSeconds, 0)) / dt
			shiftCut = math.max(math.min(from + dt, cutSeconds) - from, 0) / dt
		elseif from < cutSeconds then
			shiftFactor, loadFactor, shiftCut = cutTorque, 0, 1
		end
	end
	thrust *= shiftFactor * (1 - limiterCut) * (1 - tuning.SpinThrustLoss * spin)

	-- Engine rpm: a lag toward the target (rev drop after an upshift, rev-matched rise after a downshift).
	local target = math.min(rpmBase * (1 + tuning.ThrustSlipFlare * math.min(slip, 0.5)), limiterRpm)
	if overdrive then
		target = redline
	elseif box.LimiterState == 2 then
		target = math.min(target, redline - 2 * hysteresis)
	end
	local revDrop = math.clamp(tuning.ShiftRpmSeconds / math.max(gearing, 0.05), 0.005, 1)
	local tau
	if target < box.Rpm then
		tau = (box.ShiftKind == "Up" and box.SinceShift < cutSeconds + blendSeconds + 3 * revDrop) and revDrop or tuning.EngineRiseSeconds * tuning.EngineFallScale
	else
		tau = (box.ShiftKind == "Down" and box.SinceShift < 3 * tuning.DownshiftBlendSeconds) and tuning.DownshiftBlendSeconds or tuning.EngineRiseSeconds
	end
	box.Rpm += (target - box.Rpm) * (1 - math.exp(-dt / math.max(tau, 0.001)))
	if box.Rpm ~= box.Rpm then box.Rpm = math.max(target, idle) end
	box.Rpm = math.clamp(box.Rpm, idle, limiterRpm)

	-- Resistances are signed against the motion; engine braking only in gear and rolling forward.
	if mode == "Forward" or mode == "Braking" or mode == "Coasting" then
		local motion = forwardSpeed / math.max(math.abs(forwardSpeed), 0.8)
		local resistance = profile.Kd * forwardMph * forwardMph + tuning.RollingDecel + tuning.RollingDecelPerStud * math.abs(forwardSpeed)
		local engineBrake = 0
		if mode ~= "Forward" and gear >= 1 and forwardMph > 0 then
			engineBrake = tuning.EngineBrakeDecel * tuning.FeelEngineBrake * profile.Mult[gear] / profile.Mult[count] * (0.35 + 0.65 * math.min(box.Rpm / redline, 1)) * (1 - shiftCut)
		end
		acceleration = -motion * resistance - engineBrake
		if mode == "Forward" then
			acceleration += thrust
		elseif mode == "Braking" then
			-- FeelWeight 0 = today's brake, 1 = the designed (weaker) brake, above 1 weaker still.
			local brake = brakeAcceleration + (profile.BrakeV2 - brakeAcceleration) * tuning.FeelWeight
			brake = math.clamp(brake, 0.35 * math.min(brakeAcceleration, profile.BrakeV2), math.max(brakeAcceleration, profile.BrakeV2))
			acceleration -= motion * brake * math.abs(throttle)
		end
	end
	-- Speed guard holds the boosted top at SpeedGuardOverBoostTop x Vb; the reverse limiter is today's.
	local guardMph = math.min(maxMph, tuning.SpeedGuardOverBoostTop * profile.Vb)
	if forwardMph > guardMph then
		acceleration -= (forwardMph - guardMph) / MPH_PER_STUD * tuning.SpeedGuardStrength
	elseif forwardMph < -reverseMaxMph then
		acceleration += ((math.abs(forwardMph) - reverseMaxMph) / MPH_PER_STUD) * numberAttribute(config, "SoftLimiterStrength", 2.5, 0.1, 20)
	end
	if acceleration ~= acceleration then acceleration = 0 end
	local share = 1
	if tuning.BoostShapeEnabled and profile.Vb > 1 then share = 1 - (1 - profile.BoostShareHigh) * smoothstep(math.max(forwardMph, 0) / profile.Vb) end
	local load = 0
	if mode == "Forward" then
		load = overdrive and driven or driven * loadFactor * (1 - limiterCut)
	elseif mode == "Reverse" then
		load = math.abs(throttle)
	elseif drive.PowerBrakeHeld then
		load = 1
	end
	local planned = nil
	if gear >= 1 and gear < count and driven > tuning.CruiseThrottleMin then planned = upshiftPoint(tuning, driven) end
	box.SinceShift += dt

	out.Enabled, out.Drivetrain = true, true
	out.ReverseHoldTimer, out.LongitudinalAcceleration = reverseHoldTimer, acceleration
	out.Accelerating, out.Braking, out.SnapForwardStop, out.Mode = accelerating, braking, snapForwardStop, mode
	out.DriveThrust, out.Gear, out.Rpm, out.Load = thrust, gear, box.Rpm, math.clamp(load, 0, 1)
	out.ThrustSlip, out.WheelspinExcess, out.Cut = slip, slip, math.max(shiftCut, limiterCut)
	out.LimiterActive, out.Overdrive, out.BoostShare, out.PlannedUpshift, out.RoadRatio = box.LimiterState ~= 0, overdrive, share, planned, ratio
	local vehicle = params.Vehicle
	if vehicle and boolAttribute(config, "DebugAttributes", true) then
		vehicle:SetAttribute("DynamicsMode", mode); vehicle:SetAttribute("DynamicsForwardMph", forwardMph); vehicle:SetAttribute("DynamicsLongitudinalAcceleration", acceleration)
		vehicle:SetAttribute("DynamicsReverseHoldTimer", reverseHoldTimer)
		setIfChanged(vehicle, "DynamicsGear", gear)
		setIfChanged(vehicle, "DynamicsRpm", math.floor(box.Rpm / 10 + 0.5) * 10)
		setIfChanged(vehicle, "DynamicsWheelspin", math.floor(slip * 100 + 0.5) / 100)
		setIfChanged(vehicle, "DynamicsDriveThrust", math.floor(thrust * 10 + 0.5) / 10)
		setIfChanged(vehicle, "DynamicsEngineLoad", math.floor(out.Load * 100 + 0.5) / 100)
		setIfChanged(vehicle, "DynamicsBoostShare", math.floor(share * 100 + 0.5) / 100)
		setIfChanged(vehicle, "DynamicsOverdrive", overdrive)
	end
	return out
end

-- Neutral revs while the car is anchored (race countdown): no forces, gear N, rpm follows the throttle up to
-- NeutralRevTarget x redline and bounces off the limiter.
function Model.StepNeutral(drive, dt, throttle)
	local tuning, box, out = drive.Tuning, drive.Gearbox, drive.Result
	dt = math.clamp(tonumber(dt) or 0, 0, 0.1)
	local redline, idle, limiterRpm = tuning.RedlineRpm, tuning.IdleRpm, tuning.LimiterRpm
	local thr = tuning.NeutralRevEnabled and math.clamp(tonumber(throttle) or 0, 0, 1) or 0
	if thr ~= thr then thr = 0 end
	if box.Rpm ~= box.Rpm or box.Rpm == nil then box.Rpm = idle end
	box.Gear = 0
	local hysteresis = tuning.LimiterHysteresisRpm
	local over = thr > 0 and box.Rpm >= (box.LimiterState ~= 0 and redline - hysteresis or redline)
	local cut = stepLimiter(box, over, dt, tuning.LimiterOnSeconds, tuning.LimiterCutSeconds)
	local target = idle + thr * (tuning.NeutralRevTarget * redline - idle)
	if box.LimiterState == 2 then target = math.min(target, redline - 2 * hysteresis) end
	target = math.clamp(target, idle, limiterRpm)
	local tau = target > box.Rpm and tuning.EngineRiseSeconds or tuning.EngineRiseSeconds * tuning.EngineFallScale
	box.Rpm += (target - box.Rpm) * (1 - math.exp(-dt / math.max(tau, 0.001)))
	if box.Rpm ~= box.Rpm then box.Rpm = idle end
	box.Rpm = math.clamp(box.Rpm, idle, limiterRpm)
	box.SinceShift += dt
	out.Enabled, out.Drivetrain, out.Mode = true, true, "Stopped"
	out.ReverseHoldTimer, out.LongitudinalAcceleration, out.Accelerating, out.Braking, out.SnapForwardStop = 0, 0, false, false, false
	out.DriveThrust, out.Gear, out.Rpm, out.Load = 0, 0, box.Rpm, thr * (1 - cut)
	out.ThrustSlip, out.WheelspinExcess, out.Cut = 0, 0, cut
	out.LimiterActive, out.Overdrive, out.BoostShare, out.PlannedUpshift, out.RoadRatio = box.LimiterState ~= 0, false, 1, nil, 0
	return out
end

-- Gear and rpm for a remote car from its replicated speed and AudioDrive state (CONTRACT 3.3). No SetAttribute and
-- no allocation per call: the profile is cached per vehicle (weak keys), re-checked at most 4 times a second and
-- rebuilt only when its PerformanceIndex or the class tuning changed. Returns nil when the class has no active
-- drivetrain. previousGear is the gear this caller returned last time (hysteresis: one gear per call).
function Model.GearForSpeed(vehicle, speedMph, accelerating, braking, previousGear)
	if not vehicle then return nil end
	local entry = remoteGears[vehicle]
	local now = os.clock()
	if not entry then
		entry = {CheckedAt = -math.huge, PI = nil, Revision = nil, Profile = nil, Legacy = {}}
		remoteGears[vehicle] = entry
	end
	if now - entry.CheckedAt >= 0.25 then
		entry.CheckedAt = now
		local category = Model.DrivetrainCategory(vehicle)
		local tuning = category and Model.DrivetrainTuning(category) or nil
		if not tuning or not tuning.Active then
			entry.Profile = nil
		else
			local index = vehicle:GetAttribute("PerformanceIndex")
			if typeof(index) ~= "number" or index ~= index then index = nil end
			if entry.Profile == nil or entry.PI ~= index or entry.Revision ~= tuning.Revision then
				entry.PI, entry.Revision = index, tuning.Revision
				local config = configFolder()
				local balance = numberAttribute(config, "BalanceEnabled", 1, 0, 1) < 0.5 and BALANCE_OFF or Model.ComputeBalance(config, index)
				local legacy = entry.Legacy
				local function stat(name, fallback)
					local value = vehicle:GetAttribute(name)
					if typeof(value) == "number" then return value end
					local folder = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
					local number = folder and folder:FindFirstChild(name)
					if number and number:IsA("NumberValue") then return number.Value end
					return fallback
				end
				legacy.TopSpeed, legacy.EngineOutput, legacy.Weight = stat("TopSpeed", 126), stat("Acceleration", 42), stat("Weight", 118)
				legacy.LateralGrip, legacy.BrakingForce, legacy.BoostForce = stat("LateralGrip", stat("Handling", 48)), stat("Braking", 44), stat("Boost", 0)
				legacy.Drag, legacy.Downforce = 50, stat("Downforce", 50)
				local stats = Model.ResolveStats(vehicle, legacy, true)
				local maxMph = math.clamp(stats.TopSpeed * balance.TopSpeed, 40, numberAttribute(config, "AbsoluteTopSpeedSafetyMph", 320, 80, 500))
				entry.Profile = Model.DrivetrainProfile(vehicle, stats, balance, maxMph, true)
			end
		end
	end
	local profile = entry.Profile
	if not profile then return nil end
	local tuning = profile.Tuning
	local count, speeds = profile.GearCount, profile.Speeds
	local mph = math.max(tonumber(speedMph) or 0, 0)
	if mph ~= mph then mph = 0 end
	local gear = math.clamp(math.floor(tonumber(previousGear) or 1), 1, count)
	if mph < tuning.StopGearMph then
		gear = 1
	else
		local ratio = mph / speeds[gear]
		if not braking and gear < count and ratio >= (accelerating and 0.92 or 0.6) and mph / speeds[gear + 1] >= 0.5 then
			gear += 1
		elseif gear > 1 then
			if braking then
				if mph / speeds[gear - 1] <= tuning.DownshiftBrakeLand then gear -= 1 end
			elseif ratio < 0.45 then
				gear -= 1
			end
		end
	end
	local redline, idle = tuning.RedlineRpm, tuning.IdleRpm
	local rpm = mph / speeds[gear] * redline
	if gear == 1 and accelerating then rpm = math.max(rpm, idle + (tuning.LaunchRpmFraction * redline - idle)) end
	return gear, math.clamp(rpm, idle, tuning.LimiterRpm), redline, tuning.LimiterRpm, idle
end

return Model
