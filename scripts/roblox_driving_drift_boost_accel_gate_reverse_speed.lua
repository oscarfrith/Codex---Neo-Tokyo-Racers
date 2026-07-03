--[[
	Neo Tokyo Racers - Drift Mini-Boost Acceleration Gate + Reverse Speed
	Paste this whole file into the Roblox Studio Command Bar while NOT play-testing.

	This updates DrivingControllerV47 so:
	- drift exit mini-boost only triggers if the player is accelerating as drift ends
	- reverse top speed defaults to 40 MPH
	- reverse top speed can be tuned later from DRIVING_MECHANICS_EditAttributes

	Editable values are created under:
	ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DRIVING_MECHANICS_EditAttributes

	This is a guarded source-text patch against the current drift-release and reverse
	speed blocks in DrivingControllerV47. If the live source shape has changed, it
	aborts and prints nearby source markers instead of guessing.

	Modes:
	- INSTALL: create/update config attributes and patch the controller
	- AUDIT: print config/source state without changing anything
	- ROLLBACK: remove this patch and restore the previous drift/reverse blocks
]]

local MODE = "INSTALL" -- "INSTALL", "AUDIT", or "ROLLBACK"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PATCH_ID = "NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1"
local LOG_PREFIX = "[NTR Drift Boost Gate]"

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
		ReverseMaxMph = 40,
		DriftMiniBoostRequiresAcceleration = true,
		DriftMiniBoostAccelerationThreshold = 0.05,
		DriftMiniBoostDebugAttributes = true,
	}

	for name, value in pairs(defaults) do
		if mechanics:GetAttribute(name) == nil then
			mechanics:SetAttribute(name, value)
		end
	end

	mechanics:SetAttribute("DriftMiniBoostNotes", "When DriftMiniBoostRequiresAcceleration is true, releasing drift only grants mini-boost if throttle is above DriftMiniBoostAccelerationThreshold. ReverseMaxMph controls reverse top speed.")
	return mechanics
end

local ORIGINAL_REVERSE_CONSTANT = "local REVERSE_MAX_MPH = 20"
local PATCHED_REVERSE_CONSTANT = "local REVERSE_MAX_MPH = 40"

local ORIGINAL_REVERSE_SPEED_BLOCK = [[
		local maxReverseStuds = REVERSE_MAX_MPH / MPH_PER_STUD]]

local PATCHED_REVERSE_SPEED_BLOCK = [[
		-- NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_REVERSE_BEGIN
		local reverseMaxMph = configNumber("DRIVING_MECHANICS_EditAttributes", "ReverseMaxMph", REVERSE_MAX_MPH, 5, 80)
		local maxReverseStuds = reverseMaxMph / MPH_PER_STUD
		-- NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_REVERSE_END]]

local ORIGINAL_DRIFT_RELEASE_BLOCK = [[
		elseif not state.DriftHeld and state.DriftCharge > 0 then
			if state.DriftCharge > 0.72 then
				local charge = state.DriftCharge
				state.MiniBoostTimer = math.clamp(0.22 + charge * 0.48, 0.35, 1.85)
				state.MiniBoostPower = math.clamp(48 + charge * 27, 58, 136)
			end
			state.DriftCharge = 0
		end]]

local PATCHED_DRIFT_RELEASE_BLOCK = [[
		elseif not state.DriftHeld and state.DriftCharge > 0 then
			-- NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_DRIFT_BEGIN
			local requiresAcceleration = configBool("DRIVING_MECHANICS_EditAttributes", "DriftMiniBoostRequiresAcceleration", true)
			local accelerationThreshold = configNumber("DRIVING_MECHANICS_EditAttributes", "DriftMiniBoostAccelerationThreshold", 0.05, 0, 1)
			local acceleratingOnDriftExit = throttle > accelerationThreshold
			if state.DriftCharge > 0.72 and (not requiresAcceleration or acceleratingOnDriftExit) then
				local charge = state.DriftCharge
				state.MiniBoostTimer = math.clamp(0.22 + charge * 0.48, 0.35, 1.85)
				state.MiniBoostPower = math.clamp(48 + charge * 27, 58, 136)
			end
			if configBool("DRIVING_MECHANICS_EditAttributes", "DriftMiniBoostDebugAttributes", true) then
				state.Vehicle:SetAttribute("DriftMiniBoostAcceleratingOnExit", acceleratingOnDriftExit)
				state.Vehicle:SetAttribute("DriftMiniBoostRequiresAcceleration", requiresAcceleration)
			end
			state.DriftCharge = 0
			-- NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_DRIFT_END
		end]]

local function replacePlainOnce(source, needle, replacement)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		return source, 0
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1), 1
end

local function printSourceDiagnostics(source)
	local markers = {
		"local REVERSE_MAX_MPH",
		"local maxReverseStuds",
		"elseif not state.DriftHeld and state.DriftCharge > 0 then",
		"NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1",
	}

	for _, marker in ipairs(markers) do
		local index = string.find(source, marker, 1, true)
		if index then
			local startIndex = math.max(1, index - 350)
			local endIndex = math.min(#source, index + 950)
			log(("Found marker '%s'. Nearby source:\n%s"):format(marker, string.sub(source, startIndex, endIndex)))
		else
			log(("Marker not found: %s"):format(marker))
		end
	end
end

local function sourceHasDriftPatch(source)
	return string.find(source, "NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_DRIFT_BEGIN", 1, true) ~= nil
		and string.find(source, "NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_DRIFT_END", 1, true) ~= nil
end

local function sourceHasReversePatch(source)
	return string.find(source, "NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_REVERSE_BEGIN", 1, true) ~= nil
		and string.find(source, "NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_REVERSE_END", 1, true) ~= nil
end

local function install(controller)
	local source = controller.Source
	local patched = source

	if not string.find(patched, PATCHED_REVERSE_CONSTANT, 1, true) then
		local replaced
		patched, replaced = replacePlainOnce(patched, ORIGINAL_REVERSE_CONSTANT, PATCHED_REVERSE_CONSTANT)
		if replaced ~= 1 then
			printSourceDiagnostics(source)
			fail("Could not update REVERSE_MAX_MPH from 20 to 40.")
		end
	end

	if not sourceHasReversePatch(patched) then
		local replaced
		patched, replaced = replacePlainOnce(patched, ORIGINAL_REVERSE_SPEED_BLOCK, PATCHED_REVERSE_SPEED_BLOCK)
		if replaced ~= 1 then
			printSourceDiagnostics(source)
			fail("Could not find the expected reverse speed source block.")
		end
	end

	if not sourceHasDriftPatch(patched) then
		local replaced
		patched, replaced = replacePlainOnce(patched, ORIGINAL_DRIFT_RELEASE_BLOCK, PATCHED_DRIFT_RELEASE_BLOCK)
		if replaced ~= 1 then
			printSourceDiagnostics(source)
			fail("Could not find the expected drift release mini-boost source block.")
		end
	end

	if patched ~= source then
		controller.Source = patched
		controller:SetAttribute("DriftBoostAccelGateReversePatch", PATCH_ID)
		controller:SetAttribute("DriftBoostAccelGateReverseInstalledAt", os.date("!%Y-%m-%dT%H:%M:%SZ"))
		log("Installed drift mini-boost acceleration gate and 40 MPH configurable reverse speed.")
	else
		log("Controller already has drift mini-boost acceleration gate and reverse speed patch; config attributes refreshed.")
	end
end

local function rollback(controller)
	local source = controller.Source
	local restored = source

	if sourceHasDriftPatch(restored) then
		local replaced
		restored, replaced = replacePlainOnce(restored, PATCHED_DRIFT_RELEASE_BLOCK, ORIGINAL_DRIFT_RELEASE_BLOCK)
		if replaced ~= 1 then
			printSourceDiagnostics(source)
			fail("Could not cleanly remove the drift mini-boost acceleration gate.")
		end
	end

	if sourceHasReversePatch(restored) then
		local replaced
		restored, replaced = replacePlainOnce(restored, PATCHED_REVERSE_SPEED_BLOCK, ORIGINAL_REVERSE_SPEED_BLOCK)
		if replaced ~= 1 then
			printSourceDiagnostics(source)
			fail("Could not cleanly remove the configurable reverse speed block.")
		end
	end

	restored = string.gsub(restored, "local REVERSE_MAX_MPH = 40", "local REVERSE_MAX_MPH = 20", 1)

	if restored ~= source then
		controller.Source = restored
		controller:SetAttribute("DriftBoostAccelGateReversePatch", nil)
		controller:SetAttribute("DriftBoostAccelGateReverseInstalledAt", nil)
		log("Rolled back drift mini-boost acceleration gate and reverse speed patch.")
	else
		log("Controller does not have this patch; nothing to roll back.")
	end
end

local function audit(controller, mechanics)
	local source = controller.Source
	log("DrivingControllerV47 path: " .. controller:GetFullName())
	log("Drift acceleration gate installed: " .. tostring(sourceHasDriftPatch(source)))
	log("Configurable reverse speed installed: " .. tostring(sourceHasReversePatch(source)))
	log("Reverse constant is 40: " .. tostring(string.find(source, PATCHED_REVERSE_CONSTANT, 1, true) ~= nil))
	log("Config path: " .. mechanics:GetFullName())

	local names = {
		"ReverseMaxMph",
		"DriftMiniBoostRequiresAcceleration",
		"DriftMiniBoostAccelerationThreshold",
		"DriftMiniBoostDebugAttributes",
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
