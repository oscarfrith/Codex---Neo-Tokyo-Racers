--[[
	Neo Tokyo Racers - Speed Sensitive Steering Curve
	Paste this whole file into the Roblox Studio Command Bar while NOT play-testing.

	This adds a configurable steering multiplier curve to DrivingControllerV47:
	- stronger turning at low speed
	- softer turning at high speed
	- optional separate reverse steering multiplier
	- optional boost steering multiplier for normal boost and drift mini-boost
	- editable tuning attributes under:
	  ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DRIVING_MECHANICS_EditAttributes

	This is a guarded source-text patch against one small turn-rate block in the
	current DrivingControllerV47 module. If the live source shape has changed, it
	aborts and prints nearby source markers instead of patching.

	Modes:
	- INSTALL: create/update config attributes and patch the controller
	- AUDIT: print config/source state without changing anything
	- ROLLBACK: remove this steering patch and restore the previous turn-rate block
]]

local MODE = "INSTALL" -- "INSTALL", "AUDIT", or "ROLLBACK"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PATCH_ID = "NTR_SPEED_SENSITIVE_STEERING_V1"
local LOG_PREFIX = "[NTR Speed Steering]"

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
		SpeedSteeringEnabled = true,
		SpeedSteeringLowSpeedMph = 0,
		SpeedSteeringHighSpeedMph = 115,
		SpeedSteeringLowMultiplier = 1.45,
		SpeedSteeringHighMultiplier = 0.72,
		SpeedSteeringCurveExponent = 1.85,
		SpeedSteeringSmoothing = 7,
		SpeedSteeringDriftMinimumMultiplier = 0.92,
		ReverseSteeringMultiplier = 1.18,
		ReverseSteeringUsesSpeedCurve = true,
		BoostSteeringMultiplier = 0.8,
		SpeedSteeringDebugAttributes = true,
	}

	for name, value in pairs(defaults) do
		if mechanics:GetAttribute(name) == nil then
			mechanics:SetAttribute(name, value)
		end
	end

	mechanics:SetAttribute("SpeedSteeringNotes", "LowMultiplier boosts low-speed turning, HighMultiplier softens high-speed turning, CurveExponent controls how aggressively low-speed assist ramps in, ReverseSteeringMultiplier tunes reverse separately, BoostSteeringMultiplier stacks on top while normal boost or drift mini-boost is active.")
	return mechanics
end

local ORIGINAL_TURN_BLOCK = [[
		local speedFactor = math.clamp(math.abs(forwardSpeed) * MPH_PER_STUD / 45, 0.35, 1.35)
		local turnRate = (handling / 58) * 1.08 * speedFactor
		if drifting then turnRate *= 1.34 + (driftControl / 170) end
		state.YawHeading += -steeringInput * turnRate * dt]]

local PATCHED_TURN_BLOCK = [[
		-- NTR_SPEED_SENSITIVE_STEERING_V1_BEGIN
		local speedFactor = math.clamp(math.abs(forwardSpeed) * MPH_PER_STUD / 45, 0.35, 1.35)
		local turnRate = (handling / 58) * 1.08 * speedFactor
		local speedSteeringMultiplier = 1
		if configBool("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringEnabled", true) then
			local lowSpeedMph = configNumber("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringLowSpeedMph", 0, 0, 260)
			local highSpeedMph = configNumber("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringHighSpeedMph", 115, 1, 320)
			if highSpeedMph <= lowSpeedMph + 1 then
				highSpeedMph = lowSpeedMph + 1
			end

			local lowMultiplier = configNumber("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringLowMultiplier", 1.45, 0.1, 4)
			local highMultiplier = configNumber("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringHighMultiplier", 0.72, 0.1, 4)
			local curveExponent = configNumber("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringCurveExponent", 1.85, 0.1, 8)
			local reverseMultiplier = configNumber("DRIVING_MECHANICS_EditAttributes", "ReverseSteeringMultiplier", 1.18, 0.1, 4)
			local reverseUsesCurve = configBool("DRIVING_MECHANICS_EditAttributes", "ReverseSteeringUsesSpeedCurve", true)

			local speedAlpha = math.clamp((speedMph - lowSpeedMph) / (highSpeedMph - lowSpeedMph), 0, 1)
			local lowSpeedInfluence = (1 - speedAlpha) ^ curveExponent
			local targetMultiplier = highMultiplier + (lowMultiplier - highMultiplier) * lowSpeedInfluence

			if forwardSpeed < -4 then
				if reverseUsesCurve then
					targetMultiplier *= reverseMultiplier
				else
					targetMultiplier = reverseMultiplier
				end
			end

			if drifting then
				local driftMinimum = configNumber("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringDriftMinimumMultiplier", 0.92, 0.1, 4)
				targetMultiplier = math.max(targetMultiplier, driftMinimum)
			end

			local smoothing = configNumber("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringSmoothing", 7, 0, 30)
			if smoothing > 0 then
				local previous = state.SpeedSteeringMultiplier or targetMultiplier
				local alpha = math.clamp(dt * smoothing, 0, 1)
				speedSteeringMultiplier = previous + (targetMultiplier - previous) * alpha
			else
				speedSteeringMultiplier = targetMultiplier
			end
			state.SpeedSteeringMultiplier = speedSteeringMultiplier

			if configBool("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringDebugAttributes", true) then
				state.Vehicle:SetAttribute("SpeedSteeringMultiplier", speedSteeringMultiplier)
				state.Vehicle:SetAttribute("SpeedSteeringSpeedMph", speedMph)
			end
		else
			state.SpeedSteeringMultiplier = 1
		end
		local boostSteeringMultiplier = 1
		if state.Vehicle:GetAttribute("Boosting") == true then
			boostSteeringMultiplier = configNumber("DRIVING_MECHANICS_EditAttributes", "BoostSteeringMultiplier", 0.8, 0.1, 4)
			speedSteeringMultiplier *= boostSteeringMultiplier
		end
		if configBool("DRIVING_MECHANICS_EditAttributes", "SpeedSteeringDebugAttributes", true) then
			state.Vehicle:SetAttribute("SpeedSteeringMultiplier", speedSteeringMultiplier)
			state.Vehicle:SetAttribute("SpeedSteeringSpeedMph", speedMph)
			state.Vehicle:SetAttribute("BoostSteeringMultiplier", boostSteeringMultiplier)
		end
		turnRate *= speedSteeringMultiplier
		if drifting then turnRate *= 1.34 + (driftControl / 170) end
		state.YawHeading += -steeringInput * turnRate * dt
		-- NTR_SPEED_SENSITIVE_STEERING_V1_END]]

local function printSourceDiagnostics(source)
	local markers = {
		"local speedFactor = math.clamp",
		"NTR_SPEED_SENSITIVE_STEERING_V1_BEGIN",
		"state.YawHeading += -steeringInput * turnRate * dt",
	}

	for _, marker in ipairs(markers) do
		local index = string.find(source, marker, 1, true)
		if index then
			local startIndex = math.max(1, index - 350)
			local endIndex = math.min(#source, index + 650)
			log(("Found marker '%s'. Nearby source:\n%s"):format(marker, string.sub(source, startIndex, endIndex)))
		else
			log(("Marker not found: %s"):format(marker))
		end
	end
end

local function sourceHasPatch(source)
	return string.find(source, "NTR_SPEED_SENSITIVE_STEERING_V1_BEGIN", 1, true) ~= nil
		and string.find(source, "NTR_SPEED_SENSITIVE_STEERING_V1_END", 1, true) ~= nil
end

local function sourceHasBoostSteering(source)
	return string.find(source, "BoostSteeringMultiplier", 1, true) ~= nil
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
		if not sourceHasBoostSteering(source) then
			local pattern = "%s*%-%- NTR_SPEED_SENSITIVE_STEERING_V1_BEGIN.-%-%- NTR_SPEED_SENSITIVE_STEERING_V1_END"
			local upgraded, replacements = string.gsub(source, pattern, function()
				return "\n" .. PATCHED_TURN_BLOCK
			end, 1)
			if replacements ~= 1 then
				printSourceDiagnostics(source)
				fail("Speed-sensitive steering patch is present, but the marked block could not be upgraded for BoostSteeringMultiplier.")
			end
			controller.Source = upgraded
			controller:SetAttribute("SpeedSensitiveSteeringPatch", PATCH_ID)
			controller:SetAttribute("SpeedSensitiveSteeringInstalledAt", os.date("!%Y-%m-%dT%H:%M:%SZ"))
			log("Upgraded existing speed-sensitive steering patch with BoostSteeringMultiplier.")
			return
		end
		log("Controller already has speed-sensitive steering patch; config attributes refreshed.")
		controller:SetAttribute("SpeedSensitiveSteeringPatch", PATCH_ID)
		return
	end

	local patched, replacements = replacePlainOnce(source, ORIGINAL_TURN_BLOCK, PATCHED_TURN_BLOCK)
	if replacements ~= 1 then
		printSourceDiagnostics(source)
		fail("Could not find the expected V75 turn-rate source block. Refresh the Studio mirror or inspect the live DrivingControllerV47 source before another patch.")
	end

	controller.Source = patched
	controller:SetAttribute("SpeedSensitiveSteeringPatch", PATCH_ID)
	controller:SetAttribute("SpeedSensitiveSteeringInstalledAt", os.date("!%Y-%m-%dT%H:%M:%SZ"))
	log("Installed speed-sensitive steering curve into DrivingControllerV47.")
end

local function rollback(controller)
	local source = controller.Source
	if not sourceHasPatch(source) then
		log("Controller does not have the speed-sensitive steering patch; nothing to roll back.")
		return
	end

	local pattern = "%s*%-%- NTR_SPEED_SENSITIVE_STEERING_V1_BEGIN.-%-%- NTR_SPEED_SENSITIVE_STEERING_V1_END"
	local restored, replacements = string.gsub(source, pattern, "\n" .. ORIGINAL_TURN_BLOCK, 1)
	if replacements ~= 1 then
		printSourceDiagnostics(source)
		fail("Could not cleanly remove the speed-sensitive steering patch.")
	end

	controller.Source = restored
	controller:SetAttribute("SpeedSensitiveSteeringPatch", nil)
	controller:SetAttribute("SpeedSensitiveSteeringInstalledAt", nil)
	log("Rolled back speed-sensitive steering curve from DrivingControllerV47.")
end

local function audit(controller, mechanics)
	local source = controller.Source
	log("DrivingControllerV47 path: " .. controller:GetFullName())
	log("Patch installed: " .. tostring(sourceHasPatch(source)))
	log("Boost steering installed: " .. tostring(sourceHasBoostSteering(source)))
	log("Config path: " .. mechanics:GetFullName())

	local names = {
		"SpeedSteeringEnabled",
		"SpeedSteeringLowSpeedMph",
		"SpeedSteeringHighSpeedMph",
		"SpeedSteeringLowMultiplier",
		"SpeedSteeringHighMultiplier",
		"SpeedSteeringCurveExponent",
		"SpeedSteeringSmoothing",
		"SpeedSteeringDriftMinimumMultiplier",
		"ReverseSteeringMultiplier",
		"ReverseSteeringUsesSpeedCurve",
		"BoostSteeringMultiplier",
		"SpeedSteeringDebugAttributes",
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
