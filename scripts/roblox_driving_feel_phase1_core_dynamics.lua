-- Neo Tokyo Racers - Driving Feel Phase 1 core dynamics
-- Run in the Roblox Studio Command Bar while NOT play-testing.
--
-- This installer uses guarded plain-text replacements against the fresh
-- 2026-07-13 DrivingControllerV47 source. It preflights every source anchor
-- before writing anything. A mismatch stops the install without patching the
-- driving source. It creates no in-game backup objects.
--
-- Phase 1 safely combines the systems that own longitudinal force:
-- - Reconnects detailed runtime stats with legacy fallbacks.
-- - Replaces the extreme launch/linear limiter with a progressive power curve.
-- - Adds aerodynamic resistance and configurable coasting resistance.
-- - Separates braking, stopped hold, reverse delay, and reverse acceleration.
-- - Keeps hover, camera, steering, drift, boost, VFX, and UI publication paths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before running Driving Feel Phase 1")

local PHASE = "Driving Feel Phase 1"
local MARKER = "-- NTR_DRIVING_FEEL_PHASE1_DYNAMICS_BRIDGE"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function countPlain(source, needle)
	local count = 0
	local position = 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1
		position = found + #needle
	end
end

local function replacePlainOnce(source, oldText, newText, label)
	local count = countPlain(source, oldText)
	assert(count == 1, label .. " expected exactly 1 plain-text match, found " .. tostring(count))
	local first, last = string.find(source, oldText, 1, true)
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("Folder"), item:GetFullName() .. " must be a Folder")
		return item
	end
	item = Instance.new("Folder")
	item.Name = name
	item.Parent = parent
	return item
end

local function setDefaultAttribute(instance, name, value)
	if instance:GetAttribute(name) == nil then
		instance:SetAttribute(name, value)
	end
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local controllers = shared
	:WaitForChild("Modules")
	:WaitForChild("Client")
	:WaitForChild("Controllers")
local driving = controllers:WaitForChild("DrivingControllerV47")
assert(driving:IsA("ModuleScript"), driving:GetFullName() .. " must be a ModuleScript")

local requireOld = [[local player = Players.LocalPlayer
]]

local safeRequireBlock = [[local VehicleDynamicsModel
do
	local dynamicsModule = script.Parent:FindFirstChild("VehicleDynamicsModel")
	local ok, result = false, nil
	if dynamicsModule and dynamicsModule:IsA("ModuleScript") then
		ok, result = pcall(require, dynamicsModule)
	end
	if ok and typeof(result) == "table" and typeof(result.ResolveStats) == "function" and typeof(result.StepLongitudinal) == "function" then
		VehicleDynamicsModel = result
	else
		warn("[NTR Driving Feel Phase 1] VehicleDynamicsModel unavailable; using legacy-force fallback: " .. tostring(result))
		VehicleDynamicsModel = {
			ResolveStats = function(_, legacyStats)
				return legacyStats
			end,
			StepLongitudinal = function()
				return { Enabled = false }
			end,
		}
	end
end
]]

local requireNew = [[local player = Players.LocalPlayer

]] .. safeRequireBlock

local unsafeRequireOld = [[local VehicleDynamicsModel = require(script.Parent:WaitForChild("VehicleDynamicsModel"))
]]

local variablesOld = [[		local maxMph = math.clamp(stat("TopSpeed", 126), 40, 260)
		local acceleration = math.max(stat("Acceleration", 42), 8)
		local braking = math.max(stat("Braking", 44), 16)
		local handling = math.max(stat("Handling", 48), 10)
		local driftControl = math.max(stat("Drift", 46), 10)
		local boostPower = math.max(stat("Boost", 0), 0)
		local boostDuration = math.max(stat("BoostDuration", 2), 1)
		local boostRecharge = math.max(stat("BoostRecharge", 9), 0.5)
		local weight = math.clamp(stat("Weight", 118), 60, 260)
		local weightFactor = math.clamp(118 / weight, 0.58, 1.25)
		acceleration *= weightFactor
		handling *= math.clamp(125 / weight, 0.62, 1.22)
		driftControl *= math.clamp(122 / weight, 0.65, 1.2)
		braking *= math.clamp(115 / weight, 0.68, 1.15)
]]

local variablesNew = [[		-- NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE
		-- NTR_DRIVING_FEEL_PHASE1_DETAILED_STATS
		local legacyDynamicsStats = {
			TopSpeed = stat("TopSpeed", 126),
			EngineOutput = stat("Acceleration", 42),
			Weight = stat("Weight", 118),
			SteeringResponse = stat("Handling", 48),
			DriftControl = stat("Drift", 46),
			BrakingForce = stat("Braking", 44),
			BoostForce = stat("Boost", 0),
			BoostDuration = stat("BoostDuration", 2),
			BoostRecharge = stat("BoostRecharge", 9),
			BoostRechargeDelay = stat("BoostRechargeDelay", 0.5),
			Drag = 50,
		}
		local dynamicsStats = VehicleDynamicsModel.ResolveStats(state.Vehicle, legacyDynamicsStats)
		local maxMph = math.clamp(dynamicsStats.TopSpeed, 40, 260)
		local acceleration = math.max(legacyDynamicsStats.EngineOutput, 8)
		local braking = math.max(legacyDynamicsStats.BrakingForce, 16)
		local handling = math.max(dynamicsStats.SteeringResponse, 10)
		local driftControl = math.max(dynamicsStats.DriftControl, 10)
		local boostPower = math.max(dynamicsStats.BoostForce, 0)
		local boostDuration = math.max(dynamicsStats.BoostDuration, 1)
		local boostRecharge = math.max(dynamicsStats.BoostRecharge, 0.5)
		local weight = math.clamp(dynamicsStats.Weight, 60, 260)
		local weightFactor = math.clamp(118 / weight, 0.58, 1.25)
		acceleration *= weightFactor
		handling *= math.clamp(125 / weight, 0.62, 1.22)
		driftControl *= math.clamp(122 / weight, 0.65, 1.2)
		braking *= math.clamp(115 / weight, 0.68, 1.15)
]]

local driveOld = [[		local driveForce = Vector3.zero
		if throttle > 0 and forwardSpeed < maxForwardStuds then
			local speedLimiter = math.clamp(1 - (math.max(forwardSpeed, 0) / maxForwardStuds), 0.08, 1)
			driveForce += forward * mass * acceleration * 3.1 * speedLimiter
			state.Vehicle:SetAttribute("Accelerating", true)
		elseif throttle < 0 and forwardSpeed > -maxReverseStuds then
			local reverseLimiter = math.clamp(1 - (math.abs(math.min(forwardSpeed, 0)) / maxReverseStuds), 0.08, 1)
			driveForce -= forward * mass * braking * 1.1 * reverseLimiter
			state.Vehicle:SetAttribute("Accelerating", false)
		else
			state.Vehicle:SetAttribute("Accelerating", false)
		end

		if forwardSpeed > maxForwardStuds then
			driveForce -= forward * mass * (forwardSpeed - maxForwardStuds) * 8
		elseif forwardSpeed < -maxReverseStuds then
			local lateralVelocity = velocity - forward * forwardSpeed
			root.AssemblyLinearVelocity = lateralVelocity - forward * maxReverseStuds
			driveForce += forward * mass * (math.abs(forwardSpeed) - maxReverseStuds) * 12
		end

		local lateralGrip = 6.6 + (1.05 - 6.6) * state.DriftBlend
		driveForce += -right * sideSpeed * mass * lateralGrip
		driveForce += -velocity * mass * (0.16 + 0.10 * state.DriftBlend)
]]

local driveNew = [[		-- NTR_DRIVING_FEEL_PHASE1_DYNAMICS_BRIDGE
		local driveForce = Vector3.zero
		local dynamicsStep = VehicleDynamicsModel.StepLongitudinal({
			Vehicle = state.Vehicle,
			DeltaTime = dt,
			Throttle = throttle,
			ForwardSpeed = forwardSpeed,
			MaxMph = maxMph,
			ReverseMaxMph = reverseMaxMph,
			Stats = dynamicsStats,
			ReverseHoldTimer = state.ReverseHoldTimer or 0,
		})

		if dynamicsStep.Enabled then
			state.ReverseHoldTimer = dynamicsStep.ReverseHoldTimer
			driveForce += forward * mass * dynamicsStep.LongitudinalAcceleration
			state.Vehicle:SetAttribute("Accelerating", dynamicsStep.Accelerating)
			state.Vehicle:SetAttribute("Braking", dynamicsStep.Braking)
			if dynamicsStep.SnapForwardStop then
				root.AssemblyLinearVelocity = velocity - forward * forwardSpeed
				forwardSpeed = 0
			end
		else
			if throttle > 0 and forwardSpeed < maxForwardStuds then
				local speedLimiter = math.clamp(1 - (math.max(forwardSpeed, 0) / maxForwardStuds), 0.08, 1)
				driveForce += forward * mass * acceleration * 3.1 * speedLimiter
				state.Vehicle:SetAttribute("Accelerating", true)
			elseif throttle < 0 and forwardSpeed > -maxReverseStuds then
				local reverseLimiter = math.clamp(1 - (math.abs(math.min(forwardSpeed, 0)) / maxReverseStuds), 0.08, 1)
				driveForce -= forward * mass * braking * 1.1 * reverseLimiter
				state.Vehicle:SetAttribute("Accelerating", false)
			else
				state.Vehicle:SetAttribute("Accelerating", false)
			end

			if forwardSpeed > maxForwardStuds then
				driveForce -= forward * mass * (forwardSpeed - maxForwardStuds) * 8
			elseif forwardSpeed < -maxReverseStuds then
				local lateralVelocity = velocity - forward * forwardSpeed
				root.AssemblyLinearVelocity = lateralVelocity - forward * maxReverseStuds
				driveForce += forward * mass * (math.abs(forwardSpeed) - maxReverseStuds) * 12
			end
			state.Vehicle:SetAttribute("Braking", false)
		end

		local lateralGrip = 6.6 + (1.05 - 6.6) * state.DriftBlend
		driveForce += -right * sideSpeed * mass * lateralGrip
		if not dynamicsStep.Enabled then
			driveForce += -velocity * mass * (0.16 + 0.10 * state.DriftBlend)
		end
]]

local resetOld = [[	state.MiniBoostPower = 0
	state.BoostRechargeDelayTimer = 0
]]

local resetNew = [[	state.MiniBoostPower = 0
	state.BoostRechargeDelayTimer = 0
	state.ReverseHoldTimer = 0
]]

local dynamicsSource = [==[
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
	if minimum ~= nil and maximum ~= nil then
		value = math.clamp(value, minimum, maximum)
	end
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

function Model.ResolveStats(vehicle, legacy)
	legacy = legacy or {}
	local config = configFolder()
	local useDetailed = boolAttribute(config, "Enabled", true)
		and boolAttribute(config, "DetailedStatsEnabled", true)
	local function value(name, fallbackName, fallback)
		local legacyValue = legacy[fallbackName or name]
		if typeof(legacyValue) ~= "number" then legacyValue = fallback end
		if useDetailed then return rawNumber(vehicle, name, legacyValue) end
		return legacyValue
	end
	return {
		TopSpeed = value("TopSpeed", "TopSpeed", 126),
		EngineOutput = value("EngineOutput", "EngineOutput", 42),
		Weight = value("Weight", "Weight", 118),
		SteeringResponse = value("SteeringResponse", "SteeringResponse", 48),
		DriftControl = value("DriftControl", "DriftControl", 46),
		BrakingForce = value("BrakingForce", "BrakingForce", 44),
		BoostForce = value("BoostForce", "BoostForce", 0),
		BoostDuration = value("BoostDuration", "BoostDuration", 2),
		BoostRecharge = value("BoostRecharge", "BoostRecharge", 9),
		BoostRechargeDelay = value("BoostRechargeDelay", "BoostRechargeDelay", 0.5),
		Drag = value("Drag", "Drag", 50),
	}
end

local function oppositeSignAcceleration(forwardSpeed, amount)
	if forwardSpeed > 0 then return -amount end
	if forwardSpeed < 0 then return amount end
	return 0
end

function Model.StepLongitudinal(params)
	local config = configFolder()
	if not boolAttribute(config, "Enabled", true) then
		return {
			Enabled = false,
			ReverseHoldTimer = 0,
			LongitudinalAcceleration = 0,
			Accelerating = false,
			Braking = false,
			SnapForwardStop = false,
		}
	end

	local dt = math.clamp(tonumber(params.DeltaTime) or 0, 0, 0.1)
	local throttle = math.clamp(tonumber(params.Throttle) or 0, -1, 1)
	local forwardSpeed = tonumber(params.ForwardSpeed) or 0
	local forwardMph = forwardSpeed * MPH_PER_STUD
	local absoluteMph = math.abs(forwardMph)
	local stats = params.Stats or {}
	local maxMph = math.clamp(tonumber(params.MaxMph) or stats.TopSpeed or 126, 40, 260)
	local reverseMaxMph = math.clamp(tonumber(params.ReverseMaxMph) or 40, 5, 80)
	local deadzone = numberAttribute(config, "ThrottleDeadzone", 0.05, 0, 0.3)
	local stopThresholdMph = numberAttribute(config, "StopThresholdMph", 1.5, 0.1, 8)
	local autoHoldMph = numberAttribute(config, "AutoHoldMph", 1.25, 0.1, 8)
	local reverseDelay = numberAttribute(config, "ReverseEngageDelaySeconds", 0.3, 0, 1.5)
	local reverseHoldTimer = tonumber(params.ReverseHoldTimer) or 0

	local engineReference = numberAttribute(config, "EngineOutputReference", 60, 1, 200)
	local engineExponent = numberAttribute(config, "EngineOutputExponent", 0.75, 0.1, 2)
	local engineFactor = math.clamp((math.max(stats.EngineOutput or engineReference, 1) / engineReference) ^ engineExponent, 0.6, 1.6)
	local weightReference = numberAttribute(config, "WeightReference", 118, 1, 400)
	local weightExponent = numberAttribute(config, "WeightAccelerationExponent", 0.35, 0, 1.5)
	local weightFactor = math.clamp((weightReference / math.max(stats.Weight or weightReference, 1)) ^ weightExponent, 0.72, 1.25)
	local baseForwardAcceleration = numberAttribute(config, "BaseForwardAcceleration", 24, 5, 80)
	local curveExponent = numberAttribute(config, "AccelerationCurveExponent", 0.65, 0.1, 3)
	local speedRatio = math.clamp(math.max(forwardMph, 0) / maxMph, 0, 1)
	local accelerationCurve = (1 - speedRatio) ^ curveExponent
	local forwardAcceleration = baseForwardAcceleration * engineFactor * weightFactor * accelerationCurve

	local brakeReference = numberAttribute(config, "BrakingForceReference", 60, 1, 200)
	local brakingExponent = numberAttribute(config, "BrakingForceExponent", 0.7, 0.1, 2)
	local brakingFactor = math.clamp((math.max(stats.BrakingForce or brakeReference, 1) / brakeReference) ^ brakingExponent, 0.65, 1.65)
	local brakeWeightExponent = numberAttribute(config, "BrakeWeightExponent", 0.2, 0, 1)
	local brakeWeightFactor = math.clamp((weightReference / math.max(stats.Weight or weightReference, 1)) ^ brakeWeightExponent, 0.8, 1.2)
	local brakeAcceleration = numberAttribute(config, "BaseBrakeDeceleration", 30, 8, 90) * brakingFactor * brakeWeightFactor

	local dragReference = numberAttribute(config, "DragReference", 50, 1, 100)
	local dragFactor = math.clamp(math.max(stats.Drag or dragReference, 1) / dragReference, 0.65, 1.45)
	local aeroCoefficient = numberAttribute(config, "AerodynamicDragCoefficient", 0.012, 0, 0.2) * dragFactor
	local coastBase = numberAttribute(config, "CoastBaseDeceleration", 3.2, 0, 20)
	local coastSpeedCoefficient = numberAttribute(config, "CoastSpeedCoefficient", 0.03, 0, 0.2)
	local reverseAcceleration = numberAttribute(config, "ReverseAcceleration", 12, 2, 40) * engineFactor * weightFactor
	local reverseRatio = math.clamp(math.abs(math.min(forwardMph, 0)) / reverseMaxMph, 0, 1)
	local reverseCurve = (1 - reverseRatio) ^ numberAttribute(config, "ReverseCurveExponent", 0.8, 0.1, 3)

	local acceleration = oppositeSignAcceleration(forwardSpeed, math.abs(forwardSpeed) * aeroCoefficient)
	local mode = "Coasting"
	local braking = false
	local accelerating = false
	local snapForwardStop = false

	if throttle > deadzone then
		reverseHoldTimer = 0
		if forwardMph < -stopThresholdMph then
			mode = "Braking"
			braking = true
			acceleration += brakeAcceleration * throttle
		else
			mode = "Forward"
			accelerating = true
			acceleration += forwardAcceleration * throttle
		end
	elseif throttle < -deadzone then
		if forwardMph > stopThresholdMph then
			reverseHoldTimer = 0
			mode = "Braking"
			braking = true
			acceleration -= brakeAcceleration * math.abs(throttle)
		elseif absoluteMph <= stopThresholdMph then
			reverseHoldTimer += dt
			snapForwardStop = true
			if reverseHoldTimer >= reverseDelay then
				mode = "Reverse"
				accelerating = true
				acceleration -= reverseAcceleration * math.abs(throttle)
			else
				mode = "Stopped"
			end
		else
			mode = "Reverse"
			accelerating = true
			acceleration -= reverseAcceleration * math.abs(throttle) * reverseCurve
		end
	else
		reverseHoldTimer = 0
		if absoluteMph <= autoHoldMph then
			mode = "Stopped"
			snapForwardStop = true
		else
			local coastDeceleration = coastBase + math.abs(forwardSpeed) * coastSpeedCoefficient
			acceleration += oppositeSignAcceleration(forwardSpeed, coastDeceleration)
		end
	end

	local softLimiterStrength = numberAttribute(config, "SoftLimiterStrength", 2.5, 0.1, 20)
	if forwardMph > maxMph then
		acceleration -= ((forwardMph - maxMph) / MPH_PER_STUD) * softLimiterStrength
	elseif forwardMph < -reverseMaxMph then
		acceleration += ((math.abs(forwardMph) - reverseMaxMph) / MPH_PER_STUD) * softLimiterStrength
	end

	local vehicle = params.Vehicle
	if vehicle and boolAttribute(config, "DebugAttributes", true) then
		vehicle:SetAttribute("DynamicsMode", mode)
		vehicle:SetAttribute("DynamicsForwardMph", forwardMph)
		vehicle:SetAttribute("DynamicsLongitudinalAcceleration", acceleration)
		vehicle:SetAttribute("DynamicsAccelerationCurve", accelerationCurve)
		vehicle:SetAttribute("DynamicsEngineFactor", engineFactor)
		vehicle:SetAttribute("DynamicsWeightFactor", weightFactor)
		vehicle:SetAttribute("DynamicsReverseHoldTimer", reverseHoldTimer)
	end

	return {
		Enabled = true,
		ReverseHoldTimer = reverseHoldTimer,
		LongitudinalAcceleration = acceleration,
		Accelerating = accelerating,
		Braking = braking,
		SnapForwardStop = snapForwardStop,
		Mode = mode,
	}
end

return Model
]==]

local source = driving.Source
local alreadyInstalled = string.find(source, MARKER, 1, true) ~= nil
local patchedSource = source
local sourceChanged = false

if not alreadyInstalled then
	-- Preflight every anchor before creating config/module or changing source.
	assert(countPlain(source, requireOld) == 1, "controller require anchor mismatch; refresh/inspect live source")
	assert(countPlain(source, variablesOld) == 1, "controller detailed-stat block anchor mismatch; refresh/inspect live source")
	assert(countPlain(source, driveOld) == 1, "controller drive-force block anchor mismatch; refresh/inspect live source")
	assert(countPlain(source, resetOld) == 1, "controller state-reset anchor mismatch; refresh/inspect live source")

	patchedSource = replacePlainOnce(patchedSource, requireOld, requireNew, "dynamics module require")
	patchedSource = replacePlainOnce(patchedSource, variablesOld, variablesNew, "detailed-stat variables")
	patchedSource = replacePlainOnce(patchedSource, driveOld, driveNew, "longitudinal dynamics")
	patchedSource = replacePlainOnce(patchedSource, resetOld, resetNew, "reverse timer reset")
	sourceChanged = true
elseif countPlain(source, unsafeRequireOld) == 1 then
	-- Canonical recovery for the first Phase 1 install: never hang startup if the
	-- isolated module is unexpectedly absent from a later Play session.
	patchedSource = replacePlainOnce(patchedSource, unsafeRequireOld, safeRequireBlock, "safe dynamics require fallback")
	sourceChanged = true
end

local runtimeConfig = kit:WaitForChild("Config"):WaitForChild("Runtime")
local config = ensureFolder(runtimeConfig, "VehicleDynamics_EditAttributes")
setDefaultAttribute(config, "Enabled", true)
setDefaultAttribute(config, "DetailedStatsEnabled", true)
setDefaultAttribute(config, "BaseForwardAcceleration", 24)
setDefaultAttribute(config, "EngineOutputReference", 60)
setDefaultAttribute(config, "EngineOutputExponent", 0.75)
setDefaultAttribute(config, "WeightReference", 118)
setDefaultAttribute(config, "WeightAccelerationExponent", 0.35)
setDefaultAttribute(config, "AccelerationCurveExponent", 0.65)
setDefaultAttribute(config, "AerodynamicDragCoefficient", 0.012)
setDefaultAttribute(config, "DragReference", 50)
setDefaultAttribute(config, "CoastBaseDeceleration", 3.2)
setDefaultAttribute(config, "CoastSpeedCoefficient", 0.03)
setDefaultAttribute(config, "BaseBrakeDeceleration", 30)
setDefaultAttribute(config, "BrakingForceReference", 60)
setDefaultAttribute(config, "BrakingForceExponent", 0.7)
setDefaultAttribute(config, "BrakeWeightExponent", 0.2)
setDefaultAttribute(config, "ThrottleDeadzone", 0.05)
setDefaultAttribute(config, "StopThresholdMph", 1.5)
setDefaultAttribute(config, "AutoHoldMph", 1.25)
setDefaultAttribute(config, "ReverseEngageDelaySeconds", 0.3)
setDefaultAttribute(config, "ReverseAcceleration", 12)
setDefaultAttribute(config, "ReverseCurveExponent", 0.8)
setDefaultAttribute(config, "SoftLimiterStrength", 2.5)
setDefaultAttribute(config, "DebugAttributes", true)
setDefaultAttribute(config, "Phase", "DrivingFeelPhase1")
setDefaultAttribute(config, "TuningNote", "Phase 1 longitudinal dynamics. Disable Enabled for immediate legacy-force rollback.")

local dynamicsModule = controllers:FindFirstChild("VehicleDynamicsModel")
if dynamicsModule then
	assert(dynamicsModule:IsA("ModuleScript"), dynamicsModule:GetFullName() .. " must be a ModuleScript")
else
	dynamicsModule = Instance.new("ModuleScript")
	dynamicsModule.Name = "VehicleDynamicsModel"
	dynamicsModule.Parent = controllers
end
dynamicsModule.Source = dynamicsSource
dynamicsModule:SetAttribute("Phase", "DrivingFeelPhase1")
dynamicsModule:SetAttribute("CanonicalSource", true)

if sourceChanged then
	driving.Source = patchedSource
end
if not alreadyInstalled then
	driving:SetAttribute("DrivingFeelPhase1InstalledAt", os.date("!%Y-%m-%dT%H:%M:%SZ"))
	driving:SetAttribute("DrivingFeelPhase1Patch", "NTR_DRIVING_FEEL_PHASE1_DYNAMICS_BRIDGE")
end
driving:SetAttribute("DrivingFeelPhase1SafeRequire", true)

assert(string.find(driving.Source, MARKER, 1, true), "post-install dynamics marker missing")
assert(controllers:FindFirstChild("VehicleDynamicsModel") == dynamicsModule, "post-install dynamics module missing")
assert(#dynamicsModule.Source > 1000, "post-install dynamics module source is unexpectedly short")
assert(config:GetAttribute("Enabled") ~= nil, "post-install config is incomplete")

info(alreadyInstalled and "Already installed; refreshed canonical module and preserved config tuning." or "Installed core dynamics bridge and isolated VehicleDynamicsModel.")
info("Detailed runtime stats are connected with legacy fallbacks.")
info("Module: " .. dynamicsModule:GetFullName() .. " (" .. tostring(#dynamicsModule.Source) .. " source bytes)")
info("Config: " .. config:GetFullName())
info("Rollback: set VehicleDynamics_EditAttributes.Enabled=false, then restart Play.")
info("Restart Play and test acceleration, coasting, braking-to-stop, reverse delay, top speed, boost, drift, slopes, and reset.")
