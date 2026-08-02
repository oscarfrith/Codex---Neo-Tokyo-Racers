--[[
	Neo Tokyo Racers - Steering Drive Mode And Input-Owned Turn Bank V1.2

	Run the complete file in the Roblox Studio Edit-mode Command Bar.

	V1.2 preserves the complete working V1.1 bank block byte-for-byte and repairs
	only steering direction/profile ownership:
	- original reverse steering is restored while reversing or coasting backward
	- forward braking retains forward steering and its normal multiplier
	- forward throttle selects forward steering immediately, even while still moving backward
	- raw left/right input remains the sole visual bank owner at every speed

	INSTALL accepts exact installed V1.1, V1, or pre-V1 source.
	A failed transaction restores the source/config state present before the run.
	Explicit ROLLBACK restores the exact pre-V1 source blocks.

	Modes:
	- INSTALL: install/repair V1.2
	- AUDIT: read-only V1.2 verification
	- ROLLBACK: restore pre-V1 source and remove V1/V1.1/V1.2 attributes

	This uses guarded exact source replacement. No backup objects are created.
]]

local MODE = "INSTALL" -- "INSTALL", "AUDIT", or "ROLLBACK"

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Roblox Studio Edit mode.")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TAG = "[NTR Steering Drive Mode And Input-Owned Turn Bank V1.2]"
local REVISION = "NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2"
local RUN_ID = HttpService:GenerateGUID(false)

local V1_CONFIG_NAMES = {
	"ReverseDirectionEnterMph",
	"ForwardDirectionEnterMph",
	"DirectionIntentThrottleDeadzone",
	"ReverseBankFlipResponse",
	"ForwardBankRestoreResponse",
	"SteeringBankResponse",
	"ReverseBankDebugAttributes",
	"ReverseTurnBankDirectionNotes",
}

local V1_1_DEFAULTS = {
	TurningBankDegrees = 12,
	DriftExtraBankDegrees = 5,
	TurningBankResponse = 2.2,
	SteeringIntentThrottleDeadzone = 0.05,
	SteeringCoastDirectionMph = 0.5,
	InputOwnedSteeringDebugAttributes = true,
}

local function countPlain(source, needle)
	local count, cursor = 0, 1
	while true do
		local first, last = string.find(source, needle, cursor, true)
		if not first then return count end
		count += 1
		cursor = last + 1
	end
end

local function replaceOnce(source, needle, replacement, label)
	assert(type(source) == "string", label .. " source missing")
	assert(countPlain(source, needle) == 1, label .. " anchor count changed")
	local first = assert(string.find(source, needle, 1, true), label .. " anchor missing")
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, first + #needle)
end

local function compile(source, name)
	local fn, problem = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(problem))
end

local function snapshotAttributes(instance)
	local result = {}
	for name, value in pairs(instance:GetAttributes()) do result[name] = value end
	return result
end

local function restoreAttributes(instance, snapshot)
	for name in pairs(instance:GetAttributes()) do
		if snapshot[name] == nil then instance:SetAttribute(name, nil) end
	end
	for name, value in pairs(snapshot) do instance:SetAttribute(name, value) end
end

local ORIGINAL = {}
local V1 = {}
local V1_1 = {}
local V1_2 = {}

ORIGINAL.State = [=[	CurrentBank = 0,
	WobbleSeedX = math.random() * 1000,]=]

V1.State = [=[	CurrentBank = 0,
	-- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_STATE
	TravelDirection = 1,
	BankIntentDirection = 1,
	BankDirectionBlend = 1,
	WobbleSeedX = math.random() * 1000,]=]

V1_1.State = [=[	CurrentBank = 0,
	-- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_STATE
	SteeringProfileIntent = 1,
	WobbleSeedX = math.random() * 1000,]=]

V1_2.State = V1_1.State

ORIGINAL.Stop = [=[function Controller.Stop()
	state.IsDriving = false
	ContextActionService:UnbindAction("HOVER_RACING_V2_V47_Reset")]=]

V1.Stop = [=[function Controller.Stop()
	state.IsDriving = false
	-- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_STOP_RESET
	state.TravelDirection = 1
	state.BankIntentDirection = 1
	state.BankDirectionBlend = 1
	ContextActionService:UnbindAction("HOVER_RACING_V2_V47_Reset")]=]

V1_1.Stop = [=[function Controller.Stop()
	state.IsDriving = false
	-- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_STOP_RESET
	state.SteeringProfileIntent = 1
	ContextActionService:UnbindAction("HOVER_RACING_V2_V47_Reset")]=]

V1_2.Stop = V1_1.Stop

ORIGINAL.Start = [=[	state.ReverseHoldTimer = 0
	state.CurrentBank = 0
	state.WobbleTime = 0]=]

V1.Start = [=[	state.ReverseHoldTimer = 0
	state.CurrentBank = 0
	-- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_START_RESET
	state.TravelDirection = 1
	state.BankIntentDirection = 1
	state.BankDirectionBlend = 1
	state.WobbleTime = 0]=]

V1_1.Start = [=[	state.ReverseHoldTimer = 0
	state.CurrentBank = 0
	-- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_START_RESET
	state.SteeringProfileIntent = 1
	state.WobbleTime = 0]=]

V1_2.Start = V1_1.Start

ORIGINAL.Direction = [=[		local steeringInput = steer
		if forwardSpeed < -4 then steeringInput = -steer end

		local canDrift =]=]

V1.Direction = [=[		-- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_CLASSIFIER_BEGIN
		local planarVelocity = velocity - groundNormal * velocity:Dot(groundNormal)
		local signedTravelMph = planarVelocity:Dot(terrainForward) * MPH_PER_STUD
		local reverseEnterMph = math.abs(configNumber("DRIVING_MECHANICS_EditAttributes", "ReverseDirectionEnterMph", 0.25, 0.01, 5))
		local forwardEnterMph = math.abs(configNumber("DRIVING_MECHANICS_EditAttributes", "ForwardDirectionEnterMph", 0.25, 0.01, 5))
		local intentDeadzone = configNumber("DRIVING_MECHANICS_EditAttributes", "DirectionIntentThrottleDeadzone", 0.05, 0, 0.5)

		if signedTravelMph <= -reverseEnterMph then
			state.TravelDirection = -1
		elseif signedTravelMph >= forwardEnterMph then
			state.TravelDirection = 1
		end

		if signedTravelMph <= -reverseEnterMph then
			state.BankIntentDirection = -1
		elseif signedTravelMph >= forwardEnterMph then
			state.BankIntentDirection = 1
		elseif throttle < -intentDeadzone then
			state.BankIntentDirection = -1
		elseif throttle > intentDeadzone then
			state.BankIntentDirection = 1
		end

		local steeringInput = state.TravelDirection < 0 and -steer or steer
		-- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_CLASSIFIER_END

		local canDrift =]=]

V1_1.Direction = [=[		-- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_INPUT_BEGIN
		local steeringIntentDeadzone = configNumber("DRIVING_MECHANICS_EditAttributes", "SteeringIntentThrottleDeadzone", 0.05, 0, 0.5)
		if throttle < -steeringIntentDeadzone then
			state.SteeringProfileIntent = -1
		elseif throttle > steeringIntentDeadzone then
			state.SteeringProfileIntent = 1
		end
		local steeringInput = steer
		-- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_INPUT_END

		local canDrift =]=]

V1_2.Direction = [=[		-- NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_INPUT_BEGIN
		local steeringIntentDeadzone = configNumber("DRIVING_MECHANICS_EditAttributes", "SteeringIntentThrottleDeadzone", 0.05, 0, 0.5)
		-- NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_INPUT_END

		local canDrift =]=]

ORIGINAL.CanDrift = [=[state.DriftHeld and forwardSpeed > 8 and speedMph > 10 and math.abs(steeringInput) > 0 and grounded]=]
V1.CanDrift = ORIGINAL.CanDrift
V1_1.CanDrift = ORIGINAL.CanDrift
V1_2.CanDrift = [=[state.DriftHeld and forwardSpeed > 8 and speedMph > 10 and math.abs(steer) > 0 and grounded]=]

ORIGINAL.Mode = [=[		end

		-- NTR_DRIVING_FEEL_PHASE2_HANDLING_BRIDGE]=]
V1.Mode = ORIGINAL.Mode
V1_1.Mode = ORIGINAL.Mode
V1_2.Mode = [=[		end

		-- NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_MODE_BEGIN
		local steeringCoastDirectionMph = configNumber("DRIVING_MECHANICS_EditAttributes", "SteeringCoastDirectionMph", 0.5, 0.05, 5)
		local steeringSignedMph = forwardSpeed * MPH_PER_STUD
		if throttle > steeringIntentDeadzone then
			-- Three-point-turn exception: forward input owns yaw immediately,
			-- even while the vehicle still has backward velocity.
			state.SteeringProfileIntent = 1
		elseif throttle < -steeringIntentDeadzone then
			-- Preserve original forward handling throughout real forward braking.
			if (dynamicsStep.Enabled and dynamicsStep.Braking and forwardSpeed > 0) or steeringSignedMph > steeringCoastDirectionMph then
				state.SteeringProfileIntent = 1
			else
				state.SteeringProfileIntent = -1
			end
		elseif steeringSignedMph < -steeringCoastDirectionMph then
			state.SteeringProfileIntent = -1
		elseif steeringSignedMph > steeringCoastDirectionMph then
			state.SteeringProfileIntent = 1
		end
		local steeringInput = state.SteeringProfileIntent < 0 and -steer or steer
		if configBool("DRIVING_MECHANICS_EditAttributes", "InputOwnedSteeringDebugAttributes", true) then
			state.Vehicle:SetAttribute("SteeringDriveMode", state.SteeringProfileIntent < 0 and "Reverse" or "Forward")
			state.Vehicle:SetAttribute("SteeringSignedMph", steeringSignedMph)
			state.Vehicle:SetAttribute("SteeringDynamicsMode", tostring(dynamicsStep.Mode or "Fallback"))
		end
		-- NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_MODE_END

		-- NTR_DRIVING_FEEL_PHASE2_HANDLING_BRIDGE]=]

ORIGINAL.Curve = [=[			if forwardSpeed < -4 then
				if reverseUsesCurve then]=]

V1.Curve = [=[			if state.TravelDirection < 0 then -- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_CURVE
				if reverseUsesCurve then]=]

V1_1.Curve = [=[			if state.SteeringProfileIntent < 0 then -- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_CURVE
				if reverseUsesCurve then]=]

V1_2.Curve = [=[			if state.SteeringProfileIntent < 0 then -- NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_CURVE
				if reverseUsesCurve then]=]

ORIGINAL.Bank = [=[		local bankInput = forwardSpeed < -4 and -steeringInput or steeringInput
		local targetBank = math.rad(math.clamp(-bankInput * 12, -12, 12))
		if drifting then targetBank += math.rad(math.clamp(-bankInput * 5, -5, 5)) * state.DriftBlend end
		state.CurrentBank += (targetBank - state.CurrentBank) * math.clamp(dt * 3.2, 0, 1)]=]

V1.Bank = [=[		-- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_BANK_BEGIN
		local bankDirectionTarget = state.BankIntentDirection < 0 and -1 or 1
		local bankDirectionResponse
		if bankDirectionTarget < (state.BankDirectionBlend or 1) then
			bankDirectionResponse = configNumber("DRIVING_MECHANICS_EditAttributes", "ReverseBankFlipResponse", 9, 0.1, 30)
		else
			bankDirectionResponse = configNumber("DRIVING_MECHANICS_EditAttributes", "ForwardBankRestoreResponse", 1.75, 0.1, 30)
		end
		local directionAlpha = 1 - math.exp(-bankDirectionResponse * math.max(dt, 0))
		state.BankDirectionBlend = (state.BankDirectionBlend or bankDirectionTarget)
			+ (bankDirectionTarget - (state.BankDirectionBlend or bankDirectionTarget)) * directionAlpha

		local bankInput = steer * state.BankDirectionBlend
		local targetBank = math.rad(math.clamp(-bankInput * 12, -12, 12))
		if drifting then targetBank += math.rad(math.clamp(-bankInput * 5, -5, 5)) * state.DriftBlend end
		local bankResponse = configNumber("DRIVING_MECHANICS_EditAttributes", "SteeringBankResponse", 3.2, 0.1, 30)
		local bankAlpha = 1 - math.exp(-bankResponse * math.max(dt, 0))
		state.CurrentBank += (targetBank - state.CurrentBank) * bankAlpha

		if configBool("DRIVING_MECHANICS_EditAttributes", "ReverseBankDebugAttributes", true) then
			state.Vehicle:SetAttribute("TurnBankSignedTravelMph", signedTravelMph)
			state.Vehicle:SetAttribute("TurnBankTravelDirection", state.TravelDirection < 0 and "Reverse" or "Forward")
			state.Vehicle:SetAttribute("TurnBankIntentDirection", state.BankIntentDirection < 0 and "Reverse" or "Forward")
			state.Vehicle:SetAttribute("TurnBankDirectionBlend", state.BankDirectionBlend)
			state.Vehicle:SetAttribute("TurnBankTargetDegrees", math.deg(targetBank))
		end
		-- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_BANK_END]=]

V1_1.Bank = [=[		-- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_BANK_BEGIN
		local turningBankDegrees = configNumber("DRIVING_MECHANICS_EditAttributes", "TurningBankDegrees", 12, 0, 30)
		local driftExtraBankDegrees = configNumber("DRIVING_MECHANICS_EditAttributes", "DriftExtraBankDegrees", 5, 0, 20)
		local bankInput = steer
		local targetBankDegrees = math.clamp(-bankInput * turningBankDegrees, -turningBankDegrees, turningBankDegrees)
		if drifting then
			targetBankDegrees += math.clamp(-bankInput * driftExtraBankDegrees, -driftExtraBankDegrees, driftExtraBankDegrees) * state.DriftBlend
		end
		local targetBank = math.rad(targetBankDegrees)
		local bankResponse = configNumber("DRIVING_MECHANICS_EditAttributes", "TurningBankResponse", 2.2, 0.1, 30)
		local bankAlpha = 1 - math.exp(-bankResponse * math.max(dt, 0))
		state.CurrentBank += (targetBank - state.CurrentBank) * bankAlpha

		if configBool("DRIVING_MECHANICS_EditAttributes", "InputOwnedSteeringDebugAttributes", true) then
			state.Vehicle:SetAttribute("InputOwnedSteeringValue", steer)
			state.Vehicle:SetAttribute("SteeringProfileIntent", state.SteeringProfileIntent < 0 and "Reverse" or "Forward")
			state.Vehicle:SetAttribute("TurningBankTargetDegrees", targetBankDegrees)
			state.Vehicle:SetAttribute("TurningBankCurrentDegrees", math.deg(state.CurrentBank))
		end
		-- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_BANK_END]=]

V1_2.Bank = V1_1.Bank

ORIGINAL.Reset = [=[		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 5, 0), root.Position + Vector3.new(math.sin(state.YawHeading), 5, math.cos(state.YawHeading)))]=]

V1.Reset = [=[		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_VEHICLE_RESET
		state.TravelDirection = 1
		state.BankIntentDirection = 1
		state.BankDirectionBlend = 1
		state.CurrentBank = 0
		root.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 5, 0), root.Position + Vector3.new(math.sin(state.YawHeading), 5, math.cos(state.YawHeading)))]=]

V1_1.Reset = [=[		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_VEHICLE_RESET
		state.SteeringProfileIntent = 1
		state.CurrentBank = 0
		root.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 5, 0), root.Position + Vector3.new(math.sin(state.YawHeading), 5, math.cos(state.YawHeading)))]=]

V1_2.Reset = V1_1.Reset

local BLOCK_NAMES = {"State", "Stop", "Start", "Direction", "CanDrift", "Mode", "Curve", "Bank", "Reset"}
local V1_1_MARKERS = {
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_STATE",
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_STOP_RESET",
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_START_RESET",
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_INPUT_BEGIN",
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_INPUT_END",
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_CURVE",
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_BANK_BEGIN",
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_BANK_END",
	"NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_VEHICLE_RESET",
}
local V1_2_MARKERS = {
	"NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_INPUT_BEGIN",
	"NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_INPUT_END",
	"NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_MODE_BEGIN",
	"NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_MODE_END",
	"NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_CURVE",
}

local function sourceVersion(source)
	if source:find("NTR_DRIVING_STEERING_DRIVE_MODE_TURN_BANK_V1_2_MODE_BEGIN", 1, true) then return "V1.2" end
	if source:find("NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_INPUT_BEGIN", 1, true) then return "V1.1" end
	if source:find("NTR_DRIVING_REVERSE_TURN_BANK_DIRECTION_V1_CLASSIFIER_BEGIN", 1, true) then return "V1" end
	return "PRE_V1"
end

local function assertV1_1Shape(source)
	for _, marker in ipairs(V1_1_MARKERS) do
		assert(countPlain(source, marker) == 1, "V1.1 marker count changed: " .. marker)
	end
end

local function assertV1_2Shape(source)
	for _, marker in ipairs(V1_2_MARKERS) do
		assert(countPlain(source, marker) == 1, "V1.2 marker count changed: " .. marker)
	end
	assert(countPlain(source, "NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_BANK_BEGIN") == 1, "working V1.1 bank begin marker changed")
	assert(countPlain(source, "NTR_DRIVING_INPUT_OWNED_STEERING_TURN_BANK_V1_1_BANK_END") == 1, "working V1.1 bank end marker changed")
	assert(countPlain(source, V1_1.Bank) == 1, "working V1.1 bank block changed")
end

local function replaceVersion(source, fromBlocks, toBlocks, label)
	for _, name in ipairs(BLOCK_NAMES) do
		source = replaceOnce(source, fromBlocks[name], toBlocks[name], label .. " " .. name)
	end
	return source
end

local function projectInstall(source)
	local version = sourceVersion(source)
	if version == "V1.2" then
		assertV1_2Shape(source)
		return source, version
	elseif version == "V1.1" then
		assertV1_1Shape(source)
		assert(countPlain(source, V1_1.Bank) == 1, "input V1.1 bank block changed")
		source = replaceVersion(source, V1_1, V1_2, "V1.1 to V1.2")
	elseif version == "V1" then
		source = replaceVersion(source, V1, V1_2, "V1 to V1.2")
	else
		source = replaceVersion(source, ORIGINAL, V1_2, "pre-V1 to V1.2")
	end
	assertV1_2Shape(source)
	return source, version
end

local function projectRollback(source)
	local version = sourceVersion(source)
	if version == "V1.2" then
		source = replaceVersion(source, V1_2, ORIGINAL, "V1.2 rollback")
	elseif version == "V1.1" then
		source = replaceVersion(source, V1_1, ORIGINAL, "V1.1 rollback")
	elseif version == "V1" then
		source = replaceVersion(source, V1, ORIGINAL, "V1 rollback")
	end
	assert(sourceVersion(source) == "PRE_V1", "rollback did not restore pre-V1 source")
	return source, version
end

local root = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local controller = assert(
	root:FindFirstChild("Shared")
		and root.Shared:FindFirstChild("Modules")
		and root.Shared.Modules:FindFirstChild("Client")
		and root.Shared.Modules.Client:FindFirstChild("Controllers")
		and root.Shared.Modules.Client.Controllers:FindFirstChild("DrivingControllerV47"),
	"DrivingControllerV47 missing"
)
assert(controller:IsA("ModuleScript"), controller:GetFullName() .. " must be a ModuleScript")
local mechanics = assert(
	root:FindFirstChild("Config")
		and root.Config:FindFirstChild("Runtime")
		and root.Config.Runtime:FindFirstChild("DRIVING_MECHANICS_EditAttributes"),
	"DRIVING_MECHANICS_EditAttributes missing"
)
assert(mechanics:IsA("Folder"), mechanics:GetFullName() .. " must be a Folder")

local function audit()
	local source = controller.Source
	assert(sourceVersion(source) == "V1.2", "V1.2 source markers missing")
	assertV1_2Shape(source)
	assert(source:find("local steeringInput = state.SteeringProfileIntent < 0 and -steer or steer", 1, true), "steering drive-mode direction missing")
	assert(source:find("local bankInput = steer", 1, true), "raw input bank direction missing")
	assert(source:find("state.SteeringProfileIntent < 0", 1, true), "input-owned steering profile missing")
	assert(not source:find("state.TravelDirection", 1, true), "V1 travel direction remains")
	assert(not source:find("state.BankIntentDirection", 1, true), "V1 bank intent remains")
	for name in pairs(V1_1_DEFAULTS) do
		assert(mechanics:GetAttribute(name) ~= nil, "V1.1 config missing: " .. name)
	end
	for _, name in ipairs(V1_CONFIG_NAMES) do
		assert(mechanics:GetAttribute(name) == nil, "superseded V1 config remains: " .. name)
	end
	assert(controller:GetAttribute("ReverseTurnBankDirectionRevision") == nil, "V1 controller revision remains")
	assert(controller:GetAttribute("InputOwnedSteeringTurnBankRevision") == nil, "superseded V1.1 controller revision remains")
	assert(controller:GetAttribute("SteeringDriveModeTurnBankRevision") == REVISION, "V1.2 controller revision missing")
	print(TAG .. " AUDIT PASS"
		.. " bankDegrees=" .. tostring(mechanics:GetAttribute("TurningBankDegrees"))
		.. " response=" .. tostring(mechanics:GetAttribute("TurningBankResponse"))
		.. " throttleDeadzone=" .. tostring(mechanics:GetAttribute("SteeringIntentThrottleDeadzone"))
		.. " coastDirectionMph=" .. tostring(mechanics:GetAttribute("SteeringCoastDirectionMph")))
end

local originalSource = controller.Source
local originalControllerAttributes = snapshotAttributes(controller)
local originalMechanicsAttributes = snapshotAttributes(mechanics)

if MODE == "AUDIT" then
	audit()
	print(TAG .. " DONE mode=AUDIT runId=" .. RUN_ID)
	return
end

local projectedSource, inputVersion
if MODE == "INSTALL" then
	projectedSource, inputVersion = projectInstall(originalSource)
elseif MODE == "ROLLBACK" then
	projectedSource, inputVersion = projectRollback(originalSource)
else
	error(TAG .. " unknown MODE: " .. tostring(MODE))
end
compile(projectedSource, "DrivingControllerV47_Projected_" .. MODE)

local ok, problem = pcall(function()
	if MODE == "INSTALL" then
		for _, name in ipairs(V1_CONFIG_NAMES) do mechanics:SetAttribute(name, nil) end
		for name, value in pairs(V1_1_DEFAULTS) do
			if mechanics:GetAttribute(name) == nil then mechanics:SetAttribute(name, value) end
		end
		mechanics:SetAttribute("InputOwnedSteeringTurnBankNotes", "Raw left/right input remains the sole bank owner. SteeringDriveMode restores original reverse yaw, retains forward mode while braking, and switches to forward immediately on forward throttle during a three-point turn.")
		controller.Source = projectedSource
		controller:SetAttribute("ReverseTurnBankDirectionRevision", nil)
		controller:SetAttribute("ReverseTurnBankDirectionInstalledAtUtc", nil)
		controller:SetAttribute("InputOwnedSteeringTurnBankRevision", nil)
		controller:SetAttribute("InputOwnedSteeringTurnBankInstalledAtUtc", nil)
		controller:SetAttribute("SteeringDriveModeTurnBankRevision", REVISION)
		controller:SetAttribute("SteeringDriveModeTurnBankInstalledAtUtc", os.date("!%Y-%m-%dT%H:%M:%SZ"))
		compile(controller.Source, "DrivingControllerV47_Committed_INSTALL")
		audit()
	else
		controller.Source = projectedSource
		for _, name in ipairs(V1_CONFIG_NAMES) do mechanics:SetAttribute(name, nil) end
		for name in pairs(V1_1_DEFAULTS) do mechanics:SetAttribute(name, nil) end
		mechanics:SetAttribute("InputOwnedSteeringTurnBankNotes", nil)
		controller:SetAttribute("ReverseTurnBankDirectionRevision", nil)
		controller:SetAttribute("ReverseTurnBankDirectionInstalledAtUtc", nil)
		controller:SetAttribute("InputOwnedSteeringTurnBankRevision", nil)
		controller:SetAttribute("InputOwnedSteeringTurnBankInstalledAtUtc", nil)
		controller:SetAttribute("SteeringDriveModeTurnBankRevision", nil)
		controller:SetAttribute("SteeringDriveModeTurnBankInstalledAtUtc", nil)
		compile(controller.Source, "DrivingControllerV47_Committed_ROLLBACK")
		assert(sourceVersion(controller.Source) == "PRE_V1", "rollback source is not pre-V1")
		print(TAG .. " ROLLBACK AUDIT PASS")
	end
end)

if not ok then
	pcall(function()
		controller.Source = originalSource
		restoreAttributes(controller, originalControllerAttributes)
		restoreAttributes(mechanics, originalMechanicsAttributes)
	end)
	error(TAG .. " " .. MODE .. " ROLLED BACK: " .. tostring(problem))
end

print(TAG .. " " .. MODE .. " PASS revision=" .. REVISION .. " input=" .. tostring(inputVersion) .. " runId=" .. RUN_ID)
if MODE == "INSTALL" then
	print(TAG .. " READY: restart Play; test reverse-left, backward coast, forward braking and backward-to-forward three-point turns; confirm the V1.1 bank remains correct; verify drift/pitch/wobble/slope/camera; then refresh the full Studio mirror.")
end
