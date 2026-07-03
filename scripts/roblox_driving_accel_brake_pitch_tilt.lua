--[[
	Neo Tokyo Racers - Acceleration / Braking Pitch Tilt
	Paste this whole file into the Roblox Studio Command Bar while NOT play-testing.

	This adds configurable front/back vehicle body tilt to DrivingControllerV47:
	- nose-up / nose-down pitch while accelerating
	- stronger forward pitch while braking
	- separate reverse acceleration pitch
	- optional extra pitch while boost or drift mini-boost is active

	Editable values are created under:
	ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DRIVING_MECHANICS_EditAttributes

	This is a guarded source-text patch against the current Align.CFrame block in
	DrivingControllerV47. If the live source shape has changed, it aborts and
	prints nearby source markers instead of patching.

	Modes:
	- INSTALL: create/update config attributes and patch the controller
	- AUDIT: print config/source state without changing anything
	- ROLLBACK: remove this pitch tilt patch and restore the previous align block
]]

local MODE = "INSTALL" -- "INSTALL", "AUDIT", or "ROLLBACK"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PATCH_ID = "NTR_ACCEL_BRAKE_PITCH_TILT_V1"
local LOG_PREFIX = "[NTR Pitch Tilt]"

local function log(message)
	print(LOG_PREFIX .. " " .. tostring(message))
end

local function fail(message)
	error(LOG_PREFIX .. " " .. tostring(message), 2)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA(className) then
		fail(("Expected %s.%s to be %s, found %s"):format(parent:GetFullName(), name, className, existing.ClassName))
	end
	if not existing then
		existing = Instance.new(className)
		existing.Name = name
		existing.Parent = parent
	end
	return existing
end

local function findNeoTokyoRoot()
	local root = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	if root then
		return root
	end
	fail("Missing ReplicatedStorage.NeoTokyoRacers")
end

local function findDrivingController(root)
	local path = {
		"Shared",
		"Modules",
		"Client",
		"Controllers",
		"DrivingControllerV47",
	}

	local current = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
	end

	if current and current:IsA("ModuleScript") then
		return current
	end

	fail("Missing ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingControllerV47")
end

local function ensureMechanicsConfig(root)
	local config = child(root, "Folder", "Config")
	local runtime = child(config, "Folder", "Runtime")
	local mechanics = child(runtime, "Folder", "DRIVING_MECHANICS_EditAttributes")

	local defaults = {
		AccelBrakeTiltEnabled = true,
		AccelerationTiltDegrees = 2.5,
		BrakeTiltDegrees = -3.5,
		ReverseAccelerationTiltDegrees = -1.5,
		BoostExtraTiltDegrees = 1.0,
		AccelBrakeTiltMaxDegrees = 5.0,
		AccelBrakeTiltSmoothing = 7.0,
		AccelBrakeTiltThrottleDeadzone = 0.05,
		BrakeTiltForwardSpeedMph = 4.0,
		AccelBrakeTiltDebugAttributes = true,
	}

	for name, value in pairs(defaults) do
		if mechanics:GetAttribute(name) == nil then
			mechanics:SetAttribute(name, value)
		end
	end

	mechanics:SetAttribute("AccelBrakeTiltNotes", "Positive/negative pitch direction may depend on the live vehicle orientation. If acceleration or braking tilts the wrong way, flip the sign of the matching degrees value.")
	return mechanics
end

local ORIGINAL_ALIGN_BLOCK = [[
		terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local wobblePitch, wobbleRoll = updateHoverWobble(dt, speedMph, grounded)
		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch, 0, state.CurrentBank + wobbleRoll)]]

local PATCHED_ALIGN_BLOCK = [[
		terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local wobblePitch, wobbleRoll = updateHoverWobble(dt, speedMph, grounded)
		-- NTR_ACCEL_BRAKE_PITCH_TILT_V1_BEGIN
		local accelBrakePitch = 0
		if configBool("DRIVING_MECHANICS_EditAttributes", "AccelBrakeTiltEnabled", true) then
			local throttleDeadzone = configNumber("DRIVING_MECHANICS_EditAttributes", "AccelBrakeTiltThrottleDeadzone", 0.05, 0, 0.5)
			local brakeForwardSpeedMph = configNumber("DRIVING_MECHANICS_EditAttributes", "BrakeTiltForwardSpeedMph", 4, 0, 80)
			local targetPitchDegrees = 0

			if throttle > throttleDeadzone then
				targetPitchDegrees = configNumber("DRIVING_MECHANICS_EditAttributes", "AccelerationTiltDegrees", 2.5, -12, 12) * math.clamp(throttle, 0, 1)
			elseif throttle < -throttleDeadzone then
				if forwardSpeed * MPH_PER_STUD > brakeForwardSpeedMph then
					targetPitchDegrees = configNumber("DRIVING_MECHANICS_EditAttributes", "BrakeTiltDegrees", -3.5, -12, 12) * math.clamp(math.abs(throttle), 0, 1)
				else
					targetPitchDegrees = configNumber("DRIVING_MECHANICS_EditAttributes", "ReverseAccelerationTiltDegrees", -1.5, -12, 12) * math.clamp(math.abs(throttle), 0, 1)
				end
			end

			if state.Vehicle:GetAttribute("Boosting") == true then
				targetPitchDegrees += configNumber("DRIVING_MECHANICS_EditAttributes", "BoostExtraTiltDegrees", 1.0, -12, 12)
			end

			local maxTiltDegrees = configNumber("DRIVING_MECHANICS_EditAttributes", "AccelBrakeTiltMaxDegrees", 5, 0, 16)
			targetPitchDegrees = math.clamp(targetPitchDegrees, -maxTiltDegrees, maxTiltDegrees)

			local smoothing = configNumber("DRIVING_MECHANICS_EditAttributes", "AccelBrakeTiltSmoothing", 7, 0, 30)
			if smoothing > 0 then
				local previous = state.AccelBrakePitchDegrees or targetPitchDegrees
				local alpha = math.clamp(dt * smoothing, 0, 1)
				state.AccelBrakePitchDegrees = previous + (targetPitchDegrees - previous) * alpha
			else
				state.AccelBrakePitchDegrees = targetPitchDegrees
			end

			accelBrakePitch = math.rad(state.AccelBrakePitchDegrees or 0)
			if configBool("DRIVING_MECHANICS_EditAttributes", "AccelBrakeTiltDebugAttributes", true) then
				state.Vehicle:SetAttribute("AccelBrakePitchDegrees", state.AccelBrakePitchDegrees or 0)
			end
		else
			state.AccelBrakePitchDegrees = 0
		end
		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch + accelBrakePitch, 0, state.CurrentBank + wobbleRoll)
		-- NTR_ACCEL_BRAKE_PITCH_TILT_V1_END]]

local function printSourceDiagnostics(source)
	local markers = {
		"local wobblePitch, wobbleRoll = updateHoverWobble",
		"state.Controls.Align.CFrame = CFrame.lookAt",
		"NTR_ACCEL_BRAKE_PITCH_TILT_V1_BEGIN",
	}

	for _, marker in ipairs(markers) do
		local index = string.find(source, marker, 1, true)
		if index then
			local startIndex = math.max(1, index - 350)
			local endIndex = math.min(#source, index + 900)
			log(("Found marker '%s'. Nearby source:\n%s"):format(marker, string.sub(source, startIndex, endIndex)))
		else
			log(("Marker not found: %s"):format(marker))
		end
	end
end

local function sourceHasPatch(source)
	return string.find(source, "NTR_ACCEL_BRAKE_PITCH_TILT_V1_BEGIN", 1, true) ~= nil
		and string.find(source, "NTR_ACCEL_BRAKE_PITCH_TILT_V1_END", 1, true) ~= nil
end

local function replacePlainOnce(source, needle, replacement)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		return source, 0
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1), 1
end

local function install(controller)
	local source = controller.Source
	if sourceHasPatch(source) then
		log("Controller already has acceleration/braking pitch tilt patch; config attributes refreshed.")
		controller:SetAttribute("AccelBrakePitchTiltPatch", PATCH_ID)
		return
	end

	local patched, replacements = replacePlainOnce(source, ORIGINAL_ALIGN_BLOCK, PATCHED_ALIGN_BLOCK)
	if replacements ~= 1 then
		printSourceDiagnostics(source)
		fail("Could not find the expected V75 align source block. Refresh the Studio mirror or inspect the live DrivingControllerV47 source before another patch.")
	end

	controller.Source = patched
	controller:SetAttribute("AccelBrakePitchTiltPatch", PATCH_ID)
	controller:SetAttribute("AccelBrakePitchTiltInstalledAt", os.date("!%Y-%m-%dT%H:%M:%SZ"))
	log("Installed acceleration/braking pitch tilt into DrivingControllerV47.")
end

local function rollback(controller)
	local source = controller.Source
	if not sourceHasPatch(source) then
		log("Controller does not have the acceleration/braking pitch tilt patch; nothing to roll back.")
		return
	end

	local restored, replacements = replacePlainOnce(source, PATCHED_ALIGN_BLOCK, ORIGINAL_ALIGN_BLOCK)
	if replacements ~= 1 then
		printSourceDiagnostics(source)
		fail("Could not cleanly remove the acceleration/braking pitch tilt patch.")
	end

	controller.Source = restored
	controller:SetAttribute("AccelBrakePitchTiltPatch", nil)
	controller:SetAttribute("AccelBrakePitchTiltInstalledAt", nil)
	log("Rolled back acceleration/braking pitch tilt from DrivingControllerV47.")
end

local function audit(controller, mechanics)
	local source = controller.Source
	log("DrivingControllerV47 path: " .. controller:GetFullName())
	log("Pitch tilt patch installed: " .. tostring(sourceHasPatch(source)))
	log("Config path: " .. mechanics:GetFullName())

	local names = {
		"AccelBrakeTiltEnabled",
		"AccelerationTiltDegrees",
		"BrakeTiltDegrees",
		"ReverseAccelerationTiltDegrees",
		"BoostExtraTiltDegrees",
		"AccelBrakeTiltMaxDegrees",
		"AccelBrakeTiltSmoothing",
		"AccelBrakeTiltThrottleDeadzone",
		"BrakeTiltForwardSpeedMph",
		"AccelBrakeTiltDebugAttributes",
	}

	for _, name in ipairs(names) do
		log(("%s = %s"):format(name, tostring(mechanics:GetAttribute(name))))
	end
end

local root = findNeoTokyoRoot()
local controller = findDrivingController(root)
local mechanics = ensureMechanicsConfig(root)

if MODE == "INSTALL" then
	install(controller)
	audit(controller, mechanics)
elseif MODE == "ROLLBACK" then
	rollback(controller)
	audit(controller, mechanics)
elseif MODE == "AUDIT" then
	audit(controller, mechanics)
else
	fail("Unknown MODE: " .. tostring(MODE))
end

log("Done. Restart Play mode after INSTALL or ROLLBACK so clients require the updated controller.")
