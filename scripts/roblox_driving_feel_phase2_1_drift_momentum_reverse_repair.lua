-- Neo Tokyo Racers - Driving Feel Phase 2.1 drift momentum + reverse repair
-- Run in the Roblox Studio Command Bar while NOT play-testing.
--
-- IMPORTANT: this uses two guarded plain-text source replacements against the
-- post-Phase2 mirror generated 2026-07-13. Both anchors are preflighted before
-- either source is written. It creates no backups and touches no bootstrap/UI/VFX.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before running Driving Feel Phase 2.1")

local PHASE = "Driving Feel Phase 2.1"
local MODULE_MARKER = "-- NTR_DRIVING_FEEL_PHASE2_1_REVERSE_RELEASE"
local CONTROLLER_MARKER = "-- NTR_DRIVING_FEEL_PHASE2_1_DRIFT_MOMENTUM"

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

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local controllers = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Client")
	:WaitForChild("Controllers")
local dynamics = controllers:WaitForChild("VehicleDynamicsModel")
local driving = controllers:WaitForChild("DrivingControllerV47")
assert(dynamics:IsA("ModuleScript"), dynamics:GetFullName() .. " must be a ModuleScript")
assert(driving:IsA("ModuleScript"), driving:GetFullName() .. " must be a ModuleScript")

local reverseOld = [[		elseif absoluteMph <= stopThresholdMph then
			reverseHoldTimer += dt
			snapForwardStop = true
			if reverseHoldTimer >= reverseDelay then
				mode = "Reverse"
				accelerating = true
				acceleration -= reverseAcceleration * math.abs(throttle)
			else
				mode = "Stopped"
			end
]]

local reverseNew = [[		elseif absoluteMph <= stopThresholdMph then
			reverseHoldTimer += dt
			if reverseHoldTimer >= reverseDelay then
				-- NTR_DRIVING_FEEL_PHASE2_1_REVERSE_RELEASE
				mode = "Reverse"
				accelerating = true
				acceleration -= reverseAcceleration * math.abs(throttle)
			else
				mode = "Stopped"
				snapForwardStop = true
			end
]]

local driftOld = [[		if drifting then
			local forwardDriftSlow = math.max(forwardSpeed, 0) * mass * (0.72 + 0.42 * state.DriftBlend)
			driveForce -= forward * forwardDriftSlow * state.DriftBlend
]]

local driftNew = [[		-- NTR_DRIVING_FEEL_PHASE2_1_DRIFT_MOMENTUM
		local driftForwardDragBase = configNumber("VehicleDynamics_EditAttributes", "DriftForwardDragBase", 0.18, 0, 2)
		local driftForwardDragBlendExtra = configNumber("VehicleDynamics_EditAttributes", "DriftForwardDragBlendExtra", 0.10, 0, 2)
		local driftForwardDragCoefficient = 0
		if drifting then
			driftForwardDragCoefficient = (driftForwardDragBase + driftForwardDragBlendExtra * state.DriftBlend) * state.DriftBlend
			local forwardDriftSlow = math.max(forwardSpeed, 0) * mass * driftForwardDragCoefficient
			driveForce -= forward * forwardDriftSlow
			state.Vehicle:SetAttribute("DynamicsDriftForwardDragCoefficient", driftForwardDragCoefficient)
]]

local moduleSource = dynamics.Source
local controllerSource = driving.Source
local moduleInstalled = string.find(moduleSource, MODULE_MARKER, 1, true) ~= nil
local controllerInstalled = string.find(controllerSource, CONTROLLER_MARKER, 1, true) ~= nil

if not moduleInstalled then
	assert(countPlain(moduleSource, reverseOld) == 1, "reverse-state anchor mismatch; inspect refreshed VehicleDynamicsModel source")
end
if not controllerInstalled then
	assert(countPlain(controllerSource, driftOld) == 1, "drift-momentum anchor mismatch; inspect refreshed DrivingControllerV47 source")
end

local patchedModule = moduleInstalled and moduleSource or replacePlainOnce(moduleSource, reverseOld, reverseNew, "reverse-state repair")
local patchedController = controllerInstalled and controllerSource or replacePlainOnce(controllerSource, driftOld, driftNew, "drift-momentum repair")

local config = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("VehicleDynamics_EditAttributes")
if not moduleInstalled then
	config:SetAttribute("ReverseEngageDelaySeconds", 1.0)
end
if not controllerInstalled then
	config:SetAttribute("DriftForwardDragBase", 0.18)
	config:SetAttribute("DriftForwardDragBlendExtra", 0.10)
	config:SetAttribute("Phase2_1TuningNote", "Full drift uses Base + BlendExtra. Old slowdown was 0.72 + 0.42. Reverse delay starts within StopThresholdMph.")
end

if not moduleInstalled then dynamics.Source = patchedModule end
if not controllerInstalled then driving.Source = patchedController end
dynamics:SetAttribute("DrivingFeelPhase2_1ReverseRelease", true)
driving:SetAttribute("DrivingFeelPhase2_1DriftMomentum", true)

assert(string.find(dynamics.Source, MODULE_MARKER, 1, true), "post-install reverse marker missing")
assert(string.find(driving.Source, CONTROLLER_MARKER, 1, true), "post-install drift marker missing")
assert(config:GetAttribute("ReverseEngageDelaySeconds") ~= nil, "reverse delay config missing")
assert(config:GetAttribute("DriftForwardDragBase") ~= nil, "drift momentum config missing")

info(moduleInstalled and controllerInstalled and "Already installed; preserved current tuning." or "Installed drift momentum and reverse repair.")
info("Full-drift forward drag default is now 0.28 instead of 1.14.")
info("Reverse now releases stopped hold after a 1.0 second continuous brake hold.")
info("Rollback drift feel: set DriftForwardDragBase=0.72 and DriftForwardDragBlendExtra=0.42.")

