-- Neo Tokyo Racers - Driving Feel Phase 2 handling and drift calibration
-- Run in the Roblox Studio Command Bar while NOT play-testing.
--
-- IMPORTANT: this installer uses guarded plain-text source replacement against
-- the post-Phase1 mirror generated 2026-07-13 12:30:18. It preflights every
-- required module/controller anchor before writing either source. If any anchor
-- differs, it stops without a partial source patch. It creates no backups and
-- does not touch the register-limited client bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before running Driving Feel Phase 2")

local PHASE = "Driving Feel Phase 2"
local MODULE_MARKER = "-- NTR_DRIVING_FEEL_PHASE2_HANDLING_MODEL"
local CONTROLLER_MARKER = "-- NTR_DRIVING_FEEL_PHASE2_HANDLING_BRIDGE"

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

local function setDefaultAttribute(instance, name, value)
	if instance:GetAttribute(name) == nil then
		instance:SetAttribute(name, value)
	end
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local controllers = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Client")
	:WaitForChild("Controllers")
local driving = controllers:WaitForChild("DrivingControllerV47")
local dynamics = controllers:WaitForChild("VehicleDynamicsModel")
assert(driving:IsA("ModuleScript"), driving:GetFullName() .. " must be a ModuleScript")
assert(dynamics:IsA("ModuleScript"), dynamics:GetFullName() .. " must be a ModuleScript")

local moduleStatsOld = [[		SteeringResponse = value("SteeringResponse", "SteeringResponse", 48),
		DriftControl = value("DriftControl", "DriftControl", 46),
		BrakingForce = value("BrakingForce", "BrakingForce", 44),
		BoostForce = value("BoostForce", "BoostForce", 0),
		BoostDuration = value("BoostDuration", "BoostDuration", 2),
		BoostRecharge = value("BoostRecharge", "BoostRecharge", 9),
		BoostRechargeDelay = value("BoostRechargeDelay", "BoostRechargeDelay", 0.5),
		Drag = value("Drag", "Drag", 50),
]]

local moduleStatsNew = [[		SteeringResponse = value("SteeringResponse", "SteeringResponse", 48),
		LateralGrip = value("LateralGrip", "LateralGrip", legacy.SteeringResponse or 48),
		HoverStability = value("HoverStability", "HoverStability", legacy.SteeringResponse or 48),
		DriftControl = value("DriftControl", "DriftControl", 46),
		DriftGrip = value("DriftGrip", "DriftGrip", legacy.DriftControl or 46),
		DriftChargeRate = value("DriftChargeRate", "DriftChargeRate", legacy.DriftControl or 46),
		BrakingForce = value("BrakingForce", "BrakingForce", 44),
		BoostForce = value("BoostForce", "BoostForce", 0),
		BoostDuration = value("BoostDuration", "BoostDuration", 2),
		BoostRecharge = value("BoostRecharge", "BoostRecharge", 9),
		BoostRechargeDelay = value("BoostRechargeDelay", "BoostRechargeDelay", 0.5),
		Drag = value("Drag", "Drag", 50),
		Downforce = value("Downforce", "Downforce", 50),
]]

local handlingFunction = [==[

-- NTR_DRIVING_FEEL_PHASE2_HANDLING_MODEL
function Model.StepHandling(params)
	local config = configFolder()
	if not boolAttribute(config, "Enabled", true) or not boolAttribute(config, "HandlingEnabled", true) then
		return { Enabled = false }
	end

	local stats = params.Stats or {}
	local vehicle = params.Vehicle
	local speedMph = math.max(tonumber(params.SpeedMph) or 0, 0)
	local driftBlend = math.clamp(tonumber(params.DriftBlend) or 0, 0, 1)

	local lateralReference = numberAttribute(config, "LateralGripReference", 50, 1, 150)
	local lateralExponent = numberAttribute(config, "LateralGripExponent", 0.55, 0.1, 2)
	local lateralFactor = math.clamp((math.max(stats.LateralGrip or lateralReference, 1) / lateralReference) ^ lateralExponent, 0.72, 1.35)

	local downforceReference = numberAttribute(config, "DownforceReference", 50, 1, 150)
	local downforceInfluence = numberAttribute(config, "DownforceGripInfluence", 0.3, 0, 1)
	local highSpeedGripMph = numberAttribute(config, "HighSpeedGripMph", 140, 20, 300)
	local speedAlpha = math.clamp(speedMph / highSpeedGripMph, 0, 1)
	local downforceDelta = ((stats.Downforce or downforceReference) - downforceReference) / downforceReference
	local downforceFactor = math.clamp(1 + downforceDelta * downforceInfluence * speedAlpha, 0.82, 1.22)

	local driftGripReference = numberAttribute(config, "DriftGripReference", 50, 1, 150)
	local driftGripExponent = numberAttribute(config, "DriftGripExponent", 0.5, 0.1, 2)
	local driftGripFactor = math.clamp((math.max(stats.DriftGrip or driftGripReference, 1) / driftGripReference) ^ driftGripExponent, 0.75, 1.4)

	local driftControlReference = numberAttribute(config, "DriftControlReference", 50, 1, 150)
	local driftControlExponent = numberAttribute(config, "DriftControlExponent", 0.4, 0.1, 2)
	local driftControlFactor = math.clamp((math.max(stats.DriftControl or driftControlReference, 1) / driftControlReference) ^ driftControlExponent, 0.85, 1.35)

	local driftChargeReference = numberAttribute(config, "DriftChargeReference", 50, 1, 150)
	local driftChargeExponent = numberAttribute(config, "DriftChargeExponent", 0.5, 0.1, 2)
	local driftChargeFactor = math.clamp((math.max(stats.DriftChargeRate or driftChargeReference, 1) / driftChargeReference) ^ driftChargeExponent, 0.7, 1.45)

	local stabilityReference = numberAttribute(config, "HoverStabilityReference", 50, 1, 150)
	local stabilityExponent = numberAttribute(config, "HoverStabilityExponent", 0.35, 0.1, 2)
	local stabilityFactor = math.clamp((math.max(stats.HoverStability or stabilityReference, 1) / stabilityReference) ^ stabilityExponent, 0.82, 1.25)

	local normalGrip = numberAttribute(config, "BaseNormalLateralGrip", 6.6, 1, 20) * lateralFactor * downforceFactor
	local driftGrip = numberAttribute(config, "BaseDriftLateralGrip", 1.05, 0.1, 8) * driftGripFactor
	local lateralGrip = normalGrip + (driftGrip - normalGrip) * driftBlend
	local driftSideForce = numberAttribute(config, "BaseDriftSideForce", 34, 5, 100) * driftControlFactor
	local alignResponsiveness = numberAttribute(config, "BaseAlignResponsiveness", 22, 4, 60) * stabilityFactor

	if vehicle and boolAttribute(config, "DebugAttributes", true) then
		vehicle:SetAttribute("DynamicsLateralGrip", lateralGrip)
		vehicle:SetAttribute("DynamicsNormalGrip", normalGrip)
		vehicle:SetAttribute("DynamicsDriftGrip", driftGrip)
		vehicle:SetAttribute("DynamicsDriftControlFactor", driftControlFactor)
		vehicle:SetAttribute("DynamicsDriftChargeFactor", driftChargeFactor)
		vehicle:SetAttribute("DynamicsDownforceFactor", downforceFactor)
		vehicle:SetAttribute("DynamicsHoverStabilityFactor", stabilityFactor)
	end

	return {
		Enabled = true,
		LateralGrip = lateralGrip,
		DriftSideForce = driftSideForce,
		DriftTurnMultiplier = driftControlFactor,
		DriftChargeMultiplier = driftChargeFactor,
		AlignResponsiveness = alignResponsiveness,
	}
end
]==]

local controllerStatsOld = [[			SteeringResponse = stat("Handling", 48),
			DriftControl = stat("Drift", 46),
			BrakingForce = stat("Braking", 44),
			BoostForce = stat("Boost", 0),
			BoostDuration = stat("BoostDuration", 2),
			BoostRecharge = stat("BoostRecharge", 9),
			BoostRechargeDelay = stat("BoostRechargeDelay", 0.5),
			Drag = 50,
]]

local controllerStatsNew = [[			SteeringResponse = stat("SteeringResponse", stat("Handling", 48)),
			LateralGrip = stat("LateralGrip", stat("Handling", 48)),
			HoverStability = stat("HoverStability", stat("Handling", 48)),
			DriftControl = stat("DriftControl", stat("Drift", 46)),
			DriftGrip = stat("DriftGrip", stat("Drift", 46)),
			DriftChargeRate = stat("DriftChargeRate", stat("Drift", 46)),
			BrakingForce = stat("Braking", 44),
			BoostForce = stat("Boost", 0),
			BoostDuration = stat("BoostDuration", 2),
			BoostRecharge = stat("BoostRecharge", 9),
			BoostRechargeDelay = stat("BoostRechargeDelay", 0.5),
			Drag = 50,
			Downforce = stat("Downforce", 50),
]]

local gripOld = [[		local lateralGrip = 6.6 + (1.05 - 6.6) * state.DriftBlend
		driveForce += -right * sideSpeed * mass * lateralGrip
		if not dynamicsStep.Enabled then
			driveForce += -velocity * mass * (0.16 + 0.10 * state.DriftBlend)
		end
]]

local gripNew = [[		-- NTR_DRIVING_FEEL_PHASE2_HANDLING_BRIDGE
		local handlingStep = typeof(VehicleDynamicsModel.StepHandling) == "function" and VehicleDynamicsModel.StepHandling({
			Vehicle = state.Vehicle,
			Stats = dynamicsStats,
			SpeedMph = speedMph,
			DriftBlend = state.DriftBlend,
		}) or { Enabled = false }
		local lateralGrip = handlingStep.Enabled and handlingStep.LateralGrip or (6.6 + (1.05 - 6.6) * state.DriftBlend)
		driveForce += -right * sideSpeed * mass * lateralGrip
		if not dynamicsStep.Enabled then
			driveForce += -velocity * mass * (0.16 + 0.10 * state.DriftBlend)
		end
]]

local driftOld = [[			driveForce += right * (-steeringInput) * mass * 34 * state.DriftBlend
			state.DriftCharge = math.min(3.25, state.DriftCharge + dt * (0.95 + math.abs(steeringInput) * 1.15) * state.DriftBlend)
]]

local driftNew = [[			local driftSideForce = handlingStep.Enabled and handlingStep.DriftSideForce or 34
			local driftChargeMultiplier = handlingStep.Enabled and handlingStep.DriftChargeMultiplier or 1
			driveForce += right * (-steeringInput) * mass * driftSideForce * state.DriftBlend
			state.DriftCharge = math.min(3.25, state.DriftCharge + dt * (0.95 + math.abs(steeringInput) * 1.15) * state.DriftBlend * driftChargeMultiplier)
]]

local turnOld = [[		turnRate *= speedSteeringMultiplier
		if drifting then turnRate *= 1.34 + (driftControl / 170) end
]]

local turnNew = [[		turnRate *= speedSteeringMultiplier
		if drifting then
			local driftTurnMultiplier = handlingStep.Enabled and handlingStep.DriftTurnMultiplier or 1
			turnRate *= (1.34 + (driftControl / 170)) * driftTurnMultiplier
		end
]]

local alignOld = [[		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch + accelBrakePitch, 0, state.CurrentBank + wobbleRoll)
]]

local alignNew = [[		if handlingStep.Enabled then
			state.Controls.Align.Responsiveness = handlingStep.AlignResponsiveness
		else
			state.Controls.Align.Responsiveness = 22
		end
		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch + accelBrakePitch, 0, state.CurrentBank + wobbleRoll)
]]

local moduleSource = dynamics.Source
local controllerSource = driving.Source
local moduleInstalled = string.find(moduleSource, MODULE_MARKER, 1, true) ~= nil
local controllerInstalled = string.find(controllerSource, CONTROLLER_MARKER, 1, true) ~= nil

if not moduleInstalled then
	assert(countPlain(moduleSource, moduleStatsOld) == 1, "dynamics detailed-stat anchor mismatch; inspect refreshed module source")
	assert(countPlain(moduleSource, "\nreturn Model\n") == 1, "dynamics return anchor mismatch; inspect refreshed module source")
end
if not controllerInstalled then
	assert(countPlain(controllerSource, controllerStatsOld) == 1, "controller stat table anchor mismatch; inspect refreshed controller source")
	assert(countPlain(controllerSource, gripOld) == 1, "controller lateral-grip anchor mismatch; inspect refreshed controller source")
	assert(countPlain(controllerSource, driftOld) == 1, "controller drift-force anchor mismatch; inspect refreshed controller source")
	assert(countPlain(controllerSource, turnOld) == 1, "controller drift-turn anchor mismatch; inspect refreshed controller source")
	assert(countPlain(controllerSource, alignOld) == 1, "controller alignment anchor mismatch; inspect refreshed controller source")
end

local patchedModule = moduleSource
local patchedController = controllerSource
if not moduleInstalled then
	patchedModule = replacePlainOnce(patchedModule, moduleStatsOld, moduleStatsNew, "dynamics detailed handling stats")
	patchedModule = replacePlainOnce(patchedModule, "\nreturn Model\n", handlingFunction .. "\nreturn Model\n", "dynamics handling model")
end
if not controllerInstalled then
	patchedController = replacePlainOnce(patchedController, controllerStatsOld, controllerStatsNew, "controller detailed handling stats")
	patchedController = replacePlainOnce(patchedController, gripOld, gripNew, "controller lateral grip bridge")
	patchedController = replacePlainOnce(patchedController, driftOld, driftNew, "controller drift force/charge bridge")
	patchedController = replacePlainOnce(patchedController, turnOld, turnNew, "controller drift turn bridge")
	patchedController = replacePlainOnce(patchedController, alignOld, alignNew, "controller hover stability bridge")
end

local config = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("VehicleDynamics_EditAttributes")
setDefaultAttribute(config, "HandlingEnabled", true)
setDefaultAttribute(config, "LateralGripReference", 50)
setDefaultAttribute(config, "LateralGripExponent", 0.55)
setDefaultAttribute(config, "DownforceReference", 50)
setDefaultAttribute(config, "DownforceGripInfluence", 0.3)
setDefaultAttribute(config, "HighSpeedGripMph", 140)
setDefaultAttribute(config, "DriftGripReference", 50)
setDefaultAttribute(config, "DriftGripExponent", 0.5)
setDefaultAttribute(config, "DriftControlReference", 50)
setDefaultAttribute(config, "DriftControlExponent", 0.4)
setDefaultAttribute(config, "DriftChargeReference", 50)
setDefaultAttribute(config, "DriftChargeExponent", 0.5)
setDefaultAttribute(config, "HoverStabilityReference", 50)
setDefaultAttribute(config, "HoverStabilityExponent", 0.35)
setDefaultAttribute(config, "BaseNormalLateralGrip", 6.6)
setDefaultAttribute(config, "BaseDriftLateralGrip", 1.05)
setDefaultAttribute(config, "BaseDriftSideForce", 34)
setDefaultAttribute(config, "BaseAlignResponsiveness", 22)
setDefaultAttribute(config, "Phase2TuningNote", "Disable HandlingEnabled to keep Phase 1 longitudinal dynamics with legacy handling/drift behavior.")

if not moduleInstalled then dynamics.Source = patchedModule end
if not controllerInstalled then driving.Source = patchedController end
dynamics:SetAttribute("DrivingFeelPhase2HandlingModel", true)
driving:SetAttribute("DrivingFeelPhase2HandlingBridge", true)

assert(string.find(dynamics.Source, MODULE_MARKER, 1, true), "post-install Phase 2 module marker missing")
assert(string.find(driving.Source, CONTROLLER_MARKER, 1, true), "post-install Phase 2 controller marker missing")
assert(config:GetAttribute("HandlingEnabled") ~= nil, "post-install Phase 2 config incomplete")

info(moduleInstalled and controllerInstalled and "Already installed; preserved existing tuning." or "Installed detailed handling/drift calibration.")
info("Normal grip now uses LateralGrip plus speed-scaled Downforce.")
info("Drift grip, turn authority, side force, and charge rate now use their detailed variables.")
info("Hover alignment responsiveness now uses HoverStability.")
info("Rollback only Phase 2: set VehicleDynamics_EditAttributes.HandlingEnabled=false, then restart Play.")
