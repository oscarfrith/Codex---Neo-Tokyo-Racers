-- Neo Tokyo Racers - Driving Feel Phase 3 tier-safe curves and drift drive
-- Run in Roblox Studio Command Bar in Edit mode, then restart Play.
--
-- One consolidated installer:
--   * canonically replaces the isolated VehicleDynamicsModel;
--   * makes two guarded exact-source replacements in DrivingControllerV47;
--   * installs editable feel attributes under VehicleDynamics_EditAttributes.
-- It creates no backups and does not touch UI, VFX, economy, rating, or bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing Driving Feel Phase 3")

local PREFIX = "[NTR Driving Feel Phase 3]"
local function info(message) print(PREFIX .. " " .. message) end
local function countPlain(source, needle)
	local count, position = 0, 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1
		position = found + #needle
	end
end
local function replacePlainOnce(source, oldText, newText, label)
	local count = countPlain(source, oldText)
	assert(count == 1, label .. " expected exactly one live source match, found " .. tostring(count))
	local first, last = string.find(source, oldText, 1, true)
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local controllers = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers")
local driving = controllers:WaitForChild("DrivingControllerV47")
local dynamics = controllers:WaitForChild("VehicleDynamicsModel")
local config = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("VehicleDynamics_EditAttributes")
assert(driving:IsA("ModuleScript") and dynamics:IsA("ModuleScript"), "Driving controller/dynamics owners must be ModuleScripts")
assert(string.find(driving.Source, "NTR_DRIVING_FEEL_PHASE2_HANDLING_BRIDGE", 1, true), "Confirmed Phase 2 handling bridge is missing")
assert(string.find(driving.Source, "NTR_DRIVING_FEEL_PHASE2_1_DRIFT_MOMENTUM", 1, true), "Confirmed Phase 2.1 drift bridge is missing")

local weightOld = [[		local weightFactor = math.clamp(118 / weight, 0.58, 1.25)
		acceleration *= weightFactor
		handling *= math.clamp(125 / weight, 0.62, 1.22)
		driftControl *= math.clamp(122 / weight, 0.65, 1.2)
		braking *= math.clamp(115 / weight, 0.68, 1.15)
]]

local weightNew = [[		-- Use the bounded V2 delay resolved by VehicleDynamicsModel instead of the raw tier value cached at spawn.
		state.BoostRechargeDelaySeconds = math.clamp(dynamicsStats.BoostRechargeDelay, 0, 5)
		local weightFactor = math.clamp(118 / weight, 0.58, 1.25)
		acceleration *= weightFactor
		-- NTR_DRIVING_FEEL_PHASE3_TIER_SAFE_WEIGHT
		local steeringWeightExponent = configNumber("VehicleDynamics_EditAttributes", "SteeringWeightInfluenceExponent", 0.12, 0, 1)
		local steeringWeightFactor = math.clamp((118 / math.max(weight, 1)) ^ steeringWeightExponent,
			configNumber("VehicleDynamics_EditAttributes", "SteeringWeightMinMultiplier", 0.88, 0.5, 1.5),
			configNumber("VehicleDynamics_EditAttributes", "SteeringWeightMaxMultiplier", 1.12, 0.5, 1.5))
		handling *= steeringWeightFactor
		driftControl *= steeringWeightFactor
		braking *= math.clamp(115 / weight, 0.68, 1.15)
]]

local driftOld = [[		-- NTR_DRIVING_FEEL_PHASE2_1_DRIFT_MOMENTUM
		local driftForwardDragBase = configNumber("VehicleDynamics_EditAttributes", "DriftForwardDragBase", 0.18, 0, 2)
		local driftForwardDragBlendExtra = configNumber("VehicleDynamics_EditAttributes", "DriftForwardDragBlendExtra", 0.10, 0, 2)
		local driftForwardDragCoefficient = 0
		if drifting then
			driftForwardDragCoefficient = (driftForwardDragBase + driftForwardDragBlendExtra * state.DriftBlend) * state.DriftBlend
			local forwardDriftSlow = math.max(forwardSpeed, 0) * mass * driftForwardDragCoefficient
			driveForce -= forward * forwardDriftSlow
			state.Vehicle:SetAttribute("DynamicsDriftForwardDragCoefficient", driftForwardDragCoefficient)
			local driftSideForce = handlingStep.Enabled and handlingStep.DriftSideForce or 34
			local driftChargeMultiplier = handlingStep.Enabled and handlingStep.DriftChargeMultiplier or 1
			driveForce += right * (-steeringInput) * mass * driftSideForce * state.DriftBlend
			state.DriftCharge = math.min(3.25, state.DriftCharge + dt * (0.95 + math.abs(steeringInput) * 1.15) * state.DriftBlend * driftChargeMultiplier)
]]

local driftNew = [[		-- NTR_DRIVING_FEEL_PHASE2_1_DRIFT_MOMENTUM
		-- NTR_DRIVING_FEEL_PHASE3_DRIFT_DRIVE
		local driftForwardDragBase = configNumber("VehicleDynamics_EditAttributes", "DriftForwardDragBase", 0.10, 0, 2)
		local driftForwardDragBlendExtra = configNumber("VehicleDynamics_EditAttributes", "DriftForwardDragBlendExtra", 0.06, 0, 2)
		local driftForwardDragCoefficient = 0
		if drifting then
			driftForwardDragCoefficient = (driftForwardDragBase + driftForwardDragBlendExtra * state.DriftBlend) * state.DriftBlend
			local forwardDriftSlow = math.max(forwardSpeed, 0) * mass * driftForwardDragCoefficient
			driveForce -= forward * forwardDriftSlow
			local driftSideForce = handlingStep.Enabled and handlingStep.DriftSideForce or 26
			local driftChargeMultiplier = handlingStep.Enabled and handlingStep.DriftChargeMultiplier or 1
			driveForce += right * (-steeringInput) * mass * driftSideForce * state.DriftBlend

			local driftThrottleMinimum = configNumber("VehicleDynamics_EditAttributes", "DriftThrottleMinimum", 0.05, 0, 1)
			local driftThrottleAlpha = math.clamp((throttle - driftThrottleMinimum) / math.max(1 - driftThrottleMinimum, 0.001), 0, 1)
			if driftThrottleAlpha > 0 then
				local engineAssist = handlingStep.Enabled and handlingStep.DriftEngineAssist or 0.20
				if dynamicsStep.Enabled and dynamicsStep.LongitudinalAcceleration > 0 then
					driveForce += forward * mass * dynamicsStep.LongitudinalAcceleration * engineAssist * state.DriftBlend * driftThrottleAlpha
				end
				local alignmentRate = handlingStep.Enabled and handlingStep.DriftVelocityAlignmentRate or 2.0
				local alignmentMax = handlingStep.Enabled and handlingStep.DriftVelocityAlignmentMaxAcceleration or 30
				local horizontalSpeed = tangentVelocity.Magnitude
				if horizontalSpeed > 1 then
					local desiredVelocity = terrainForward * horizontalSpeed
					local alignmentAcceleration = (desiredVelocity - tangentVelocity) * alignmentRate * state.DriftBlend * driftThrottleAlpha
					if alignmentAcceleration.Magnitude > alignmentMax then alignmentAcceleration = alignmentAcceleration.Unit * alignmentMax end
					driveForce += alignmentAcceleration * mass
					state.Vehicle:SetAttribute("DynamicsDriftAlignmentAcceleration", alignmentAcceleration.Magnitude)
				end
			end
			state.Vehicle:SetAttribute("DynamicsDriftForwardDragCoefficient", driftForwardDragCoefficient)
			state.Vehicle:SetAttribute("DynamicsDriftThrottleAlpha", driftThrottleAlpha)
			state.DriftCharge = math.min(3.25, state.DriftCharge + dt * (0.95 + math.abs(steeringInput) * 1.15) * state.DriftBlend * driftChargeMultiplier)
]]

local controllerSource = driving.Source
local hasWeightMarker = string.find(controllerSource, "NTR_DRIVING_FEEL_PHASE3_TIER_SAFE_WEIGHT", 1, true) ~= nil
local hasDriftMarker = string.find(controllerSource, "NTR_DRIVING_FEEL_PHASE3_DRIFT_DRIVE", 1, true) ~= nil
assert(hasWeightMarker == hasDriftMarker, "Partial Phase 3 controller install detected; refresh the Studio mirror before repair")
if not hasWeightMarker then
	assert(countPlain(controllerSource, weightOld) == 1, "Tier-safe weight source anchor differs from the confirmed mirror")
	assert(countPlain(controllerSource, driftOld) == 1, "Drift-drive source anchor differs from the confirmed mirror")
end
info("PASS - Preflighted both guarded controller anchors before mutation.")

local dynamicsSource = [==[
-- NTR_DRIVING_FEEL_PHASE3_TIER_CURVE_DYNAMICS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Model = {}
local MPH_PER_STUD = 0.625

local function configFolder()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local config = kit and kit:FindFirstChild("Config")
	local runtime = config and config:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("VehicleDynamics_EditAttributes")
end
local function numberAttribute(folder, name, fallback, minimum, maximum)
	local value = folder and folder:GetAttribute(name)
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
	local result = {
		TopSpeed = value("TopSpeed", "TopSpeed", 126), EngineOutput = value("EngineOutput", "EngineOutput", 42), Weight = value("Weight", "Weight", 118),
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
	local maxMph = math.clamp(tonumber(params.MaxMph) or stats.TopSpeed or 126, 40, 260)
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
	local forwardAcceleration = numberAttribute(config,"BaseForwardAcceleration",32,5,80)*effectiveEngineFactor*weightFactor*launchShape*highFade

	local brakeReference = numberAttribute(config,"BrakingForceReference",60,1,200)
	local brakingFactor = curveMultiplier(stats.BrakingForce,brakeReference,numberAttribute(config,"BrakingForceExponent",0.7,0.1,2),0.65,1.65)
	local brakeWeightFactor = math.clamp((weightReference/math.max(stats.Weight or weightReference,1))^numberAttribute(config,"BrakeWeightExponent",0.2,0,1),0.8,1.2)
	local brakeAcceleration = numberAttribute(config,"BaseBrakeDeceleration",30,8,90)*brakingFactor*brakeWeightFactor
	local dragFactor = curveMultiplier(stats.Drag,numberAttribute(config,"DragReference",50,1,100),numberAttribute(config,"AerodynamicDragStatExponent",0.35,0,1),0.65,1.45)
	local aeroAcceleration = numberAttribute(config,"AerodynamicDragPerMphSquared",0.00012,0,0.002)*forwardMph*math.abs(forwardMph)*dragFactor
	local reverseAcceleration = numberAttribute(config,"ReverseAcceleration",12,2,40)*engineFactor*weightFactor
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
	local lateralFactor=curveMultiplier(stats.LateralGrip,numberAttribute(config,"LateralGripReference",50,1,300),numberAttribute(config,"LateralGripExponent",0.40,0.05,2),numberAttribute(config,"LateralGripMinMultiplier",0.82,0.2,2),numberAttribute(config,"LateralGripMaxMultiplier",1.22,0.2,3))
	local downforceReference=numberAttribute(config,"DownforceReference",50,1,300); local speedAlpha=math.clamp(speedMph/numberAttribute(config,"HighSpeedGripMph",140,20,300),0,1)
	local downforceFactor=math.clamp(1+((stats.Downforce or downforceReference)-downforceReference)/downforceReference*numberAttribute(config,"DownforceGripInfluence",0.22,0,1)*speedAlpha,0.88,1.15)
	local driftGripFactor=curveMultiplier(stats.DriftGrip,numberAttribute(config,"DriftGripReference",50,1,300),numberAttribute(config,"DriftGripExponent",0.35,0.05,2),0.85,1.25)
	local driftControlFactor=curveMultiplier(stats.RawDriftControl or stats.DriftControl,numberAttribute(config,"DriftControlReference",50,1,300),numberAttribute(config,"DriftControlExponent",0.32,0.05,2),0.88,1.25)
	local driftChargeFactor=curveMultiplier(stats.DriftChargeRate,numberAttribute(config,"DriftChargeReference",50,1,300),numberAttribute(config,"DriftChargeExponent",0.35,0.05,2),0.80,1.30)
	local stabilityFactor=curveMultiplier(stats.HoverStability,numberAttribute(config,"HoverStabilityReference",50,1,300),numberAttribute(config,"HoverStabilityExponent",0.25,0.05,2),0.88,1.15)
	local normalGrip=numberAttribute(config,"BaseNormalLateralGrip",6.6,1,20)*lateralFactor*downforceFactor
	local driftGrip=numberAttribute(config,"BaseDriftLateralGrip",2.0,0.1,8)*driftGripFactor
	local lateralGrip=normalGrip+(driftGrip-normalGrip)*driftBlend
	local engineDriftFactor=curveMultiplier(stats.EngineOutput,numberAttribute(config,"EngineOutputReference",60,1,300),0.30,0.85,1.22)
	local result={Enabled=true,LateralGrip=lateralGrip,DriftSideForce=numberAttribute(config,"BaseDriftSideForce",26,5,100)*driftControlFactor,DriftTurnMultiplier=driftControlFactor,DriftChargeMultiplier=driftChargeFactor,AlignResponsiveness=numberAttribute(config,"BaseAlignResponsiveness",22,4,60)*stabilityFactor,DriftEngineAssist=numberAttribute(config,"DriftEngineAssist",0.20,0,1)*engineDriftFactor,DriftVelocityAlignmentRate=numberAttribute(config,"DriftVelocityAlignmentRate",2.0,0,10)*driftControlFactor,DriftVelocityAlignmentMaxAcceleration=numberAttribute(config,"DriftVelocityAlignmentMaxAcceleration",30,1,100)*driftGripFactor}
	if vehicle and boolAttribute(config,"DebugAttributes",true) then vehicle:SetAttribute("DynamicsLateralGrip",lateralGrip); vehicle:SetAttribute("DynamicsNormalGrip",normalGrip); vehicle:SetAttribute("DynamicsDriftGrip",driftGrip); vehicle:SetAttribute("DynamicsDriftControlFactor",driftControlFactor); vehicle:SetAttribute("DynamicsDriftChargeFactor",driftChargeFactor); vehicle:SetAttribute("DynamicsDownforceFactor",downforceFactor); vehicle:SetAttribute("DynamicsHoverStabilityFactor",stabilityFactor); vehicle:SetAttribute("DynamicsDriftEngineAssist",result.DriftEngineAssist); vehicle:SetAttribute("DynamicsDriftVelocityAlignmentRate",result.DriftVelocityAlignmentRate) end
	return result
end

return Model
]==]

-- Compile the canonical module before any live source/config mutation.
local temporary = Instance.new("ModuleScript")
temporary.Name = "VehicleDynamicsModel_Phase3PreflightTemp"
temporary.Source = dynamicsSource
temporary.Parent = controllers
local loaded, loadResult = pcall(require, temporary)
temporary:Destroy()
assert(loaded and typeof(loadResult) == "table", "Canonical Phase 3 dynamics module failed to load: " .. tostring(loadResult))
info("PASS - Preflight-loaded the canonical tier-safe dynamics module.")

local patchedController = controllerSource
if not hasWeightMarker then
	patchedController = replacePlainOnce(patchedController, weightOld, weightNew, "tier-safe handling weight block")
	patchedController = replacePlainOnce(patchedController, driftOld, driftNew, "drift drive/alignment block")
end

local firstInstall = config:GetAttribute("DrivingFeelCalibrationVersion") ~= "PHASE3_TIER_CURVE_DRIFT_DRIVE"
if firstInstall then
	local values = {
		BaseForwardAcceleration=32, LaunchAccelerationMultiplier=0.45, LaunchRampEndMph=14, LaunchEngineInfluence=0.35,
		EngineOutputReference=60, EngineOutputExponent=0.55, EngineOutputMinMultiplier=0.72, EngineOutputMaxMultiplier=1.48,
		WeightReference=118, WeightAccelerationExponent=0.22, WeightAccelerationMinMultiplier=0.82, WeightAccelerationMaxMultiplier=1.18,
		PowerBandStartRatioLow=0.48, PowerBandStartRatioHigh=0.70, HighSpeedAccelerationExponent=0.80, HighSpeedAccelerationFloor=0.06,
		AerodynamicDragPerMphSquared=0.00012, AerodynamicDragStatExponent=0.35,
		BasePhysicalSteeringResponse=58, SteeringResponseReference=50, SteeringResponseExponent=0.42, SteeringResponseMinMultiplier=0.78, SteeringResponseMaxMultiplier=1.30,
		SteeringWeightInfluenceExponent=0.12, SteeringWeightMinMultiplier=0.88, SteeringWeightMaxMultiplier=1.12,
		BasePhysicalDriftControl=50, PhysicalDriftControlExponent=0.35, PhysicalDriftControlMinMultiplier=0.82, PhysicalDriftControlMaxMultiplier=1.25,
		LateralGripExponent=0.40, LateralGripMinMultiplier=0.82, LateralGripMaxMultiplier=1.22, DownforceGripInfluence=0.22,
		BaseDriftLateralGrip=2.0, BaseDriftSideForce=26, DriftGripExponent=0.35, DriftControlExponent=0.32, DriftChargeExponent=0.35,
		DriftForwardDragBase=0.10, DriftForwardDragBlendExtra=0.06, DriftEngineAssist=0.20, DriftVelocityAlignmentRate=2.0, DriftVelocityAlignmentMaxAcceleration=30, DriftThrottleMinimum=0.05,
		BoostDurationReferenceSeconds=3.0, BoostDurationExponent=0.32, BoostDurationMinSeconds=2.2, BoostDurationMaxSeconds=4.2,
		BoostRechargeReferenceSeconds=8.5, BoostRechargeExponent=0.32, BoostRechargeMinSeconds=6.5, BoostRechargeMaxSeconds=10.5,
		BoostRechargeDelayExponent=0.25, BoostRechargeDelayMinSeconds=0.40, BoostRechargeDelayMaxSeconds=1.0, BoostEfficiencyTimingExponent=0.15,
	}
	for name, value in pairs(values) do config:SetAttribute(name, value) end
	config:SetAttribute("AccelerationTuningNote", "Launch* controls 0-14 MPH; PowerBand* controls where tiered pull fades; AerodynamicDrag* controls high-speed resistance.")
	config:SetAttribute("HandlingTuningNote", "SteeringResponse min/max multipliers compress E-S steering without changing rating stats.")
	config:SetAttribute("DriftTuningNote", "DriftGrip reduces boat-like slide; EngineAssist and VelocityAlignment pull momentum around the corner; SideForce creates rotation.")
	config:SetAttribute("BoostTuningNote", "Duration/Recharge min/max seconds are physical bounds; raw V2 boost stats still determine position within them.")
end

dynamics.Source = dynamicsSource
if not hasWeightMarker then driving.Source = patchedController end
config:SetAttribute("DrivingFeelCalibrationVersion", "PHASE3_TIER_CURVE_DRIFT_DRIVE")
dynamics:SetAttribute("DrivingFeelPhase3TierCurves", true)
driving:SetAttribute("DrivingFeelPhase3DriftDrive", true)

assert(string.find(dynamics.Source, "NTR_DRIVING_FEEL_PHASE3_TIER_CURVE_DYNAMICS", 1, true), "Canonical dynamics marker missing")
assert(string.find(driving.Source, "NTR_DRIVING_FEEL_PHASE3_TIER_SAFE_WEIGHT", 1, true), "Tier-safe controller marker missing")
assert(string.find(driving.Source, "NTR_DRIVING_FEEL_PHASE3_DRIFT_DRIVE", 1, true), "Drift-drive controller marker missing")
assert(config:GetAttribute("DrivingFeelCalibrationVersion") == "PHASE3_TIER_CURVE_DRIFT_DRIVE", "Phase 3 config marker missing")

info("PASS - Installed one consolidated tier-safe acceleration/handling/boost/drift calibration.")
info("PASS - E-S steering and boost timing now use bounded diminishing physical ranges.")
info("PASS - Acceleration now has soft launch, mid-speed power band, tier-dependent high-speed pull, and quadratic aero drag.")
info("PASS - Drift now has more grip, less sideways shove/drag, throttle engine assist, and force-based velocity alignment.")
info(firstInstall and "BASELINE VALUES INSTALLED - Restart Play and test Forge E, Viper C, and Zenith S." or "RERUN COMPLETE - Existing editable Phase 3 tuning values were preserved.")
