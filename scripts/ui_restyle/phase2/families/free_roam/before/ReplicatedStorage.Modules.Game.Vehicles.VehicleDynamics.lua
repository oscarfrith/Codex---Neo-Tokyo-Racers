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

function Model.ResolveStats(vehicle, legacy)
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
	if vehicle and boolAttribute(config, "DebugAttributes", true) then
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
	if vehicle and boolAttribute(config, "DebugAttributes", true) then
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
	local result={Enabled=true,LateralGrip=lateralGrip,DriftSideForce=numberAttribute(config,"BaseDriftSideForce",26,5,100)*driftControlFactor*balance.DriftSideForce,DriftTurnMultiplier=driftControlFactor*balance.DriftTurn,DriftChargeMultiplier=driftChargeFactor*balance.DriftCharge,AlignResponsiveness=numberAttribute(config,"BaseAlignResponsiveness",22,4,60)*stabilityFactor,DriftEngineAssist=numberAttribute(config,"DriftEngineAssist",0.20,0,1)*engineDriftFactor*balance.DriftEngineAssist,DriftVelocityAlignmentRate=numberAttribute(config,"DriftVelocityAlignmentRate",2.0,0,10)*driftControlFactor*balance.DriftAlignment,DriftVelocityAlignmentMaxAcceleration=numberAttribute(config,"DriftVelocityAlignmentMaxAcceleration",30,1,100)*driftGripFactor*balance.DriftAlignment}
	if vehicle and boolAttribute(config,"DebugAttributes",true) then vehicle:SetAttribute("DynamicsLateralGrip",lateralGrip); vehicle:SetAttribute("DynamicsNormalGrip",normalGrip); vehicle:SetAttribute("DynamicsDriftGrip",driftGrip); vehicle:SetAttribute("DynamicsDriftControlFactor",driftControlFactor); vehicle:SetAttribute("DynamicsDriftChargeFactor",driftChargeFactor); vehicle:SetAttribute("DynamicsDownforceFactor",downforceFactor); vehicle:SetAttribute("DynamicsHoverStabilityFactor",stabilityFactor); vehicle:SetAttribute("DynamicsDriftEngineAssist",result.DriftEngineAssist); vehicle:SetAttribute("DynamicsDriftVelocityAlignmentRate",result.DriftVelocityAlignmentRate) end
	return result
end

return Model
