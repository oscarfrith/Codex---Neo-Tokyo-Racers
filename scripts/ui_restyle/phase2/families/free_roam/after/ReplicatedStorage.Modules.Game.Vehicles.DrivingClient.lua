-- Canonical feature implementation; startup is owned by the composition root.
local Controller = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DriveTuning = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DriveTuning")) 
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local GameplayInputGate = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("GameplayInputGate"))

local VehicleDynamicsModel = require(game:GetService("ReplicatedStorage").Modules.Game.Vehicles.VehicleDynamics)

local REVERSE_MAX_MPH = 40
local HOVER_HEIGHT = math.clamp(DriveTuning.Read().HoverHeightStuds, 0.5, 8) 
local SENSOR_START_HEIGHT = 2
local SENSOR_LENGTH = 24
local MPH_PER_STUD = 0.625
local CAMERA_RENDER_NAME = "DrivingCameraAssist"

local state = {
	Vehicle = nil,
	Controls = nil,
	Connection = nil,
	RayParams = nil,
	IsDriving = false,
	Boost = 100,
	DriftHeld = false,
	DriftCharge = 0,
	DriftBlend = 0,
	MiniBoostTimer = 0,
	MiniBoostPower = 0,
	BoostRechargeDelayTimer = 0,
	BoostRechargeDelaySeconds = 0.5,
	YawHeading = 0,
	CurrentBank = 0,
	SteeringProfileIntent = 1,
	WobbleSeedX = math.random() * 1000,
	WobbleSeedZ = math.random() * 1000,
	WobbleTime = 0,
	WobblePitch = 0,
	WobbleRoll = 0,
	WobbleYaw = 0,
	WobbleBob = 0,
	WobbleSeedY = math.random() * 1000,
	PoseConfig = {},
	PoseConfigTimer = 0,
	PoseProfileX = {},
	PoseProfileY = {},
	PoseHalfLength = 6,
	PoseSettle = nil,
	PoseSettleVelocity = 0,
	PoseLift = 0,
	PoseLiftVelocity = 0,
	PoseLean = 0,
	PosePitch = 0,
	PoseRideHeight = HOVER_HEIGHT,
	PoseRollTerm = 0,
	PosePitchTerm = 0,
	GamepadSteer = 0,
	GamepadAccel = 0,
	GamepadBrake = 0,
	GamepadBoostHeld = false,
	ResetCooldown = 0,
	SavedJumpPower = nil,
	SavedJumpHeight = nil,
	SavedAutoJump = nil,
	SavedJumpEnabled = nil,
	Context = nil,
	CameraAssistBound = false,
	CameraInputConnections = {},
	CameraMouseDown = false,
	CameraTouchInput = nil,
	PlayerAdjustedZoom = false,
	ManualCameraDistance = nil,
	LastCameraInputTime = 0,
	SavedFieldOfView = nil,
	CurrentFov = nil,
	AccelCameraBlend = 0,
	BoostCameraBlend = 0,
	AccelCameraActive = false,
	BoostCameraActive = false,
}

-- Drivetrain feel (scripts/drivetrain_feel/CONTRACT.md): gearbox, weight and spin-out for a vehicle class with an
-- enabled Config.Vehicles.Drivetrain.<CategoryId> folder. One table for the session, changed in place (no per-frame
-- allocation). Every use is guarded by Drivetrain.Active, so a car without an active class drives exactly as before.
-- VehicleDynamics.StepDrivetrain reads Tuning, Profile, Gearbox, Result and the per-frame inputs below.
local G_STUDS = 35.1 -- 1 g in studs/s^2
local SPIN_YAW_GATE, SPIN_YAW_GATE_WIDTH = 0.15, 0.35 -- rad/s: a spin needs the car to be turning already
local STAB_NONE = math.huge -- stab event clocks: time since the event, this large when there was none
local DRIVETRAIN_FEEL_ATTRIBUTES = {"FeelRpm", "FeelIdleRpm", "FeelRedlineRpm", "FeelLimiterRpm", "FeelGearCount", "FeelGear", "FeelLoad", "FeelShiftRevision", "FeelShiftKind", "FeelShiftStrength", "FeelCut", "FeelLimiterRevision", "FeelThrustSlip", "FeelSpin", "FeelSpinDirection", "FeelOverdrive"}
local GEAR_TEXT = {[-1] = "R", [0] = "N", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
local Drivetrain = {
	Active = false, Tuning = nil, Profile = nil, Category = nil, RefreshTimer = 0, Debug = false, DriveReady = false,
	WasAnchored = false, ResetPending = false, TelemetryReady = false, GateLocked = false,
	SteerKeyboard = 0, SteerTouch = 0, PowerBrakeInput = false, AnalogThrottle = false, TouchInput = false,
	BoostAccel = 0, ImpactKick = 0, RpmRate = 0, LastRpm = 0,
	-- inputs to VehicleDynamics.StepDrivetrain, set each frame
	SpinAmount = 0, DriftBlend = 0, HorizontalSpeed = 0, SteeringIntent = 1, ExtraSlip = 0, PowerBrakeHeld = false, BoostApplied = false, AnalogInput = false,
	Gearbox = { Gear = 1, Rpm = 0, SinceShift = 10, ShiftKind = "None", LimiterState = 0, LimiterClock = 0, LiftClock = 10, KickClock = 0, ShiftRevision = 0, LimiterRevision = 0, LastKind = "Up", LastStrength = 0, Overdrive = false, Duty = 0, SteadyMph = 0 },
	Result = {},
	-- YawRate = SteerYawRate (the steering spring) + SpinYawRate (the spin's own yaw), clamped to YawRateMax.
	Chassis = { YawRate = 0, SteerYawRate = 0, SpinYawRate = 0, YawAccel = 0, YawCommand = 0, Authority = 1, SpinAccel = 0, LateralAccel = 0, LateralApplied = 0, LateralCap = 0, Pitch = 0, PitchVelocity = 0, Roll = 0, RollVelocity = 0 },
	Spin = { L = 0, Dir = 0, Target = 0, Window = 0, Warn = false, Caught = false, Settling = false,
		WasOn = false, Armed = false, LiftClock = 0, RiseClock = 0, ThrottleClock = STAB_NONE, FlickClock = STAB_NONE, SteerLow = false, LastSteer = 0,
		PowerBrakeClock = 0, DumpSlip = 0, DumpClock = 0, GraceClock = 0, GraceSpeedReached = false, GraceNeedsSpeed = false },
	FeelCache = {},
	DebugCache = {},
	Telemetry = { Gear = "N", GearRevision = 0, RpmFraction = 0, ShiftLight = 0, Spin = 0, Overdrive = false },
}

-- Moves a steering value toward its target: build rate away from centre, return rate back toward (and across) it.
local function approachSteer(current, target, buildRate, returnRate, dt)
	if current ~= current then current = 0 end
	local rate = buildRate
	local goal = target
	if current * target < 0 or math.abs(target) < math.abs(current) then
		rate = returnRate
		if current * target < 0 then goal = 0 end
	end
	local step = rate * dt
	if math.abs(goal - current) <= step then return goal end
	return current + (goal > current and step or -step)
end

local function character()
	return player and player.Character
end

local function humanoid()
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function blockJumpAction()
	return Enum.ContextActionResult.Sink
end

local function setJumpLocked(locked)
	local h = humanoid()
	if not h then return end
	if locked then
		if state.SavedJumpPower == nil then
			state.SavedJumpPower = h.JumpPower
			state.SavedJumpHeight = h.JumpHeight
			state.SavedAutoJump = h.AutoJumpEnabled
			state.SavedJumpEnabled = h:GetStateEnabled(Enum.HumanoidStateType.Jumping)
		end
		h.Jump = false
		h.AutoJumpEnabled = false
		h.JumpPower = 0
		h.JumpHeight = 0
		h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		ContextActionService:BindActionAtPriority("BlockJumpWhileDriving", blockJumpAction, false, 4000, Enum.KeyCode.Space)
	else
		ContextActionService:UnbindAction("BlockJumpWhileDriving")
		h:SetStateEnabled(Enum.HumanoidStateType.Jumping, state.SavedJumpEnabled ~= false)
		h.JumpPower = state.SavedJumpPower or 50
		h.JumpHeight = state.SavedJumpHeight or 7.2
		h.AutoJumpEnabled = state.SavedAutoJump ~= false
		h.Jump = false
		state.SavedJumpPower = nil
		state.SavedJumpHeight = nil
		state.SavedAutoJump = nil
		state.SavedJumpEnabled = nil
	end
end

local function vehiclesRoot()
	local world = game:GetService("Workspace"):FindFirstChild("World")
	local runtime = world and game:GetService("Workspace"):WaitForChild("World"):FindFirstChild("Runtime")
	return runtime and game:GetService("Workspace"):WaitForChild("World"):WaitForChild("Runtime"):FindFirstChild("PlayerVehicles")
end

local function getPlayerVehicle()
	local root = vehiclesRoot()
	if not root or not player then return nil end
	for _, vehicle in ipairs(root:GetChildren()) do
		if vehicle:GetAttribute("OwnerUserId") == player.UserId then
			local primary = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
			if primary then
				vehicle.PrimaryPart = primary
				return vehicle
			end
		end
	end
	return nil
end

local function waitForPlayerVehicle(timeout)
	local startTime = os.clock()
	repeat
		local vehicle = getPlayerVehicle()
		if vehicle and vehicle.Parent and vehicle.PrimaryPart then return vehicle end
		task.wait(0.05)
	until os.clock() - startTime > (timeout or 5)
	return nil
end

local configNumber
local configBool

local function stat(name, fallback)
	local vehicle = state.Vehicle
	if not vehicle then return fallback end
	local value = vehicle:GetAttribute(name)
	if typeof(value) == "number" then return value end
	local statsFolder = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
	local number = statsFolder and statsFolder:FindFirstChild(name)
	if number and number:IsA("NumberValue") then return number.Value end
	return fallback
end

local function installedModuleNumber(moduleType, name, fallback)
	local vehicle = state.Vehicle
	if not vehicle then return fallback end
	local installedRoot = vehicle:FindFirstChild("INSTALLED_MODULES_Runtime")
	if not installedRoot then return fallback end
	for _, descendant in ipairs(installedRoot:GetDescendants()) do
		if descendant:IsA("Model") then
			local candidateType = tostring(descendant:GetAttribute("ModuleType") or "")
			if candidateType == moduleType then
				local value = descendant:GetAttribute(name)
				if typeof(value) == "number" then
					return value
				end
			end
		end
	end
	return fallback
end

local function refreshBoostRechargeDelay()
	local fallback = configNumber("Driving", "BoostRechargeDelaySeconds", 0.5, 0, 5)
	local vehicleValue = stat("BoostRechargeDelay", nil)
	if typeof(vehicleValue) == "number" then
		state.BoostRechargeDelaySeconds = math.clamp(vehicleValue, 0, 5)
		return
	end
	state.BoostRechargeDelaySeconds = math.clamp(installedModuleNumber("Boost", "BoostRechargeDelay", fallback), 0, 5)
end

local function cleanupDriveForces(root)
	if not root then return end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("VectorForce") or child:IsA("AlignOrientation") or child:IsA("AngularVelocity") or string.find(child.Name, "Drive_", 1, true) or string.find(child.Name, "ClientHover", 1, true) or string.find(child.Name, "V61_", 1, true) or string.find(child.Name, "V60_", 1, true) or string.find(child.Name, "V59_", 1, true) then
			child:Destroy()
		end
	end
end

local function makeAttachment(parent, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position or Vector3.zero
	attachment.Parent = parent
	return attachment
end

local function setupControls(vehicle)
	local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
	if not root then return nil end
	vehicle.PrimaryPart = root
	cleanupDriveForces(root)

	local centerAttachment = makeAttachment(root, "Drive_CenterAttachment", Vector3.zero)

	local driveForce = Instance.new("VectorForce")
	driveForce.Name = "Drive_ForwardForce"
	driveForce.Attachment0 = centerAttachment
	driveForce.ApplyAtCenterOfMass = true
	driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
	driveForce.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Name = "Drive_TerrainYawAlign"
	align.Attachment0 = centerAttachment
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.huge
	align.Responsiveness = 22
	align.RigidityEnabled = false
	align.Parent = root

	local halfX = math.max(root.Size.X * 0.5, 4)
	local halfZ = math.max(root.Size.Z * 0.5, 6)
	local offsets = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, halfZ),
	}

	local corners = {}
	for index, offset in ipairs(offsets) do
		local attachment = makeAttachment(root, "Drive_HoverCornerAttachment" .. index, offset)
		local force = Instance.new("VectorForce")
		force.Name = "Drive_HoverCornerForce" .. index
		force.Attachment0 = attachment
		force.ApplyAtCenterOfMass = false
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Parent = root
		corners[index] = { Offset = offset, Force = force }
	end

	return { Root = root, DriveForce = driveForce, Align = align, Corners = corners }
end

local function getTerrainFrame(root, hitPositions, normalSum, hits)
	local normal = Vector3.new(0, 1, 0)
	if hits > 0 and normalSum.Magnitude > 0.01 then
		normal = normalSum.Unit
	end

	local frontLeft, frontRight, rearLeft, rearRight = hitPositions[1], hitPositions[2], hitPositions[3], hitPositions[4]
	if frontLeft and frontRight and rearLeft and rearRight then
		local frontMid = (frontLeft + frontRight) * 0.5
		local rearMid = (rearLeft + rearRight) * 0.5
		local leftMid = (frontLeft + rearLeft) * 0.5
		local rightMid = (frontRight + rearRight) * 0.5
		local slopeForward = frontMid - rearMid
		local slopeRight = rightMid - leftMid
		if slopeForward.Magnitude > 0.05 and slopeRight.Magnitude > 0.05 then
			local planeNormal = slopeRight.Unit:Cross(slopeForward.Unit)
			if planeNormal.Y < 0 then planeNormal = -planeNormal end
			normal = planeNormal.Unit
		end
	end

	local flatForward = Vector3.new(math.sin(state.YawHeading), 0, math.cos(state.YawHeading))
	local terrainForward = flatForward - normal * flatForward:Dot(normal)
	if terrainForward.Magnitude < 0.05 then
		terrainForward = root.CFrame.LookVector - normal * root.CFrame.LookVector:Dot(normal)
	end
	return terrainForward.Unit, normal
end

local function readGamepad()
	local ok, inputs = pcall(function()
		return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	end)
	state.GamepadSteer = 0
	state.GamepadAccel = 0
	state.GamepadBrake = 0
	if ok then
		for _, input in ipairs(inputs) do
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				state.GamepadSteer = math.abs(input.Position.X) > 0.12 and input.Position.X or 0
			elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
				state.GamepadAccel = math.clamp(input.Position.Z, 0, 1)
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
				state.GamepadBrake = math.clamp(input.Position.Z, 0, 1)
			end
		end
	end
end

local function gamepadDown(keyCode)
	local ok, result = pcall(function()
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, keyCode)
	end)
	return ok and result == true
end

local function mobileInput()
	local context = state.Context
	if context and typeof(context.GetMobileInput) == "function" then
		local ok, throttle, steer, drift, boost = pcall(context.GetMobileInput)
		if ok then return throttle or 0, steer or 0, drift == true, boost == true end
	end
	return 0, 0, false, false
end

-- Returns throttle, steer, rawSteer. rawSteer is the summed input as before; steer equals it unless the drivetrain is
-- active, when keyboard and touch steering build up at a rate (gamepad analog is untouched).
local function refreshInput(dt)
	if GameplayInputGate.IsLocked() then
		state.GamepadSteer = 0
		state.GamepadAccel = 0
		state.GamepadBrake = 0
		state.GamepadBoostHeld = false
		state.DriftHeld = false
		state.DriftCharge = 0
		state.MiniBoostTimer = 0
		state.MiniBoostPower = 0
		state.AccelCameraActive = false
		state.BoostCameraActive = false
		if state.Vehicle then
			state.Vehicle:SetAttribute("Accelerating", false)
			state.Vehicle:SetAttribute("Boosting", false)
			state.Vehicle:SetAttribute("DriftingLeft", false)
			state.Vehicle:SetAttribute("DriftingRight", false)
		end
		-- Drivetrain: no stale gesture inputs while locked, and one reset on the lock edge (not every locked frame).
		Drivetrain.PowerBrakeInput, Drivetrain.AnalogThrottle, Drivetrain.TouchInput = false, false, false
		if Drivetrain.Active and not Drivetrain.GateLocked then Drivetrain.ResetPending = true end
		Drivetrain.GateLocked = true
		return 0, 0, 0
	end
	Drivetrain.GateLocked = false
	readGamepad()
	local throttle = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then throttle += 1 end
	local forwardKey = throttle > 0
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then throttle -= 1 end
	local bothKeys = forwardKey and throttle == 0

	local steer = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then steer -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer += 1 end

	local mobileThrottle, mobileSteer, mobileDrift, mobileBoost = mobileInput()
	throttle = math.clamp(throttle + state.GamepadAccel - state.GamepadBrake + mobileThrottle, -1, 1)
	local rawSteer = math.clamp(steer + state.GamepadSteer + mobileSteer, -1, 1)
	if Drivetrain.Active and Drivetrain.Tuning then
		-- Weight: keyboard steering builds to full lock in SteerRiseSeconds x FeelWeight; touch moves at TouchSteerRate.
		-- Below FeelWeight 1 the return and touch rates sharpen, so FeelWeight 0 is today's instant steering.
		local tuning = Drivetrain.Tuning
		if tuning.FeelWeight <= 0 then
			-- FeelWeight 0: today's instant steering exactly (no limiter, no frame average).
			Drivetrain.SteerKeyboard, Drivetrain.SteerTouch = steer, mobileSteer
			steer = rawSteer
		else
			local step = math.clamp(dt or 0, 0, 0.1)
			local soften = math.max(math.min(tuning.FeelWeight, 1), 0.05)
			local keyboard, touch = Drivetrain.SteerKeyboard, Drivetrain.SteerTouch
			if keyboard ~= keyboard then keyboard = 0 end
			if touch ~= touch then touch = 0 end
			Drivetrain.SteerKeyboard = approachSteer(keyboard, steer, 1 / math.max(tuning.SteerRiseSeconds * tuning.FeelWeight, 0.001), tuning.SteerReturnRate / soften, step)
			Drivetrain.SteerTouch = approachSteer(touch, mobileSteer, tuning.TouchSteerRate / soften, tuning.TouchSteerRate / soften, step)
			-- The frame's steer is the average of each limiter's start and end values (trapezoid), so the build-up and the
			-- run-on after a release do not depend on the frame rate.
			steer = math.clamp((keyboard + Drivetrain.SteerKeyboard) * 0.5 + state.GamepadSteer + (touch + Drivetrain.SteerTouch) * 0.5, -1, 1)
		end
		-- Spin gestures: W and S (or R2 and L2) held together cancel to 0 as before; the gesture is only recorded.
		Drivetrain.PowerBrakeInput = bothKeys or (state.GamepadAccel > 0.5 and state.GamepadBrake > 0.5)
		Drivetrain.AnalogThrottle = state.GamepadAccel > 0.05 and not forwardKey
		Drivetrain.TouchInput = mobileThrottle ~= 0 or mobileSteer ~= 0
		-- The last throttle device (kept while no throttle is held): a gamepad trigger is analog; keyboard and touch are
		-- 0/1, which the digital cruise upshift reads.
		if forwardKey or mobileThrottle > 0 then
			Drivetrain.AnalogInput = false
		elseif state.GamepadAccel > 0.05 then
			Drivetrain.AnalogInput = true
		end
	else
		steer = rawSteer
	end
	state.DriftHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space) or gamepadDown(Enum.KeyCode.ButtonB) or mobileDrift
	state.GamepadBoostHeld = gamepadDown(Enum.KeyCode.ButtonA) or mobileBoost
	return throttle, steer, rawSteer
end

local function cameraConfig()
	local kit = game:GetService("ReplicatedStorage")
	local config = kit and game:GetService("ReplicatedStorage"):WaitForChild("Config")
	return config and game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):FindFirstChild("CameraAssist")
end

local function configFolder(name)
	local kit = game:GetService("ReplicatedStorage")
	local config = kit and game:GetService("ReplicatedStorage"):WaitForChild("Config")
	return config and config:WaitForChild("Vehicles"):FindFirstChild(name)
end

local function cameraNumber(name, fallback, minimum, maximum)
	local folder = cameraConfig()
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "number" then
		value = fallback
	end
	if minimum and maximum then
		return math.clamp(value, minimum, maximum)
	end
	return value
end
local categorisedConfigNumberCaches = setmetatable({}, {__mode = "k"})
local function categorisedConfigNumber(folder, name)
	if not folder then return nil end
	local cache = categorisedConfigNumberCaches[folder]
	if not cache then
		cache = {}
		for _, category in ipairs(folder:GetChildren()) do
			if category:IsA("Folder") then
				for attributeName, attributeValue in pairs(category:GetAttributes()) do
					if typeof(attributeValue) == "number" then cache[attributeName] = category end
				end
			end
		end
		categorisedConfigNumberCaches[folder] = cache
	end
	local category = cache[name]
	return category and category:GetAttribute(name) or nil
end

function configNumber(folderName, name, fallback, minimum, maximum)
	local folder = configFolder(folderName)
	local value = categorisedConfigNumber(folder, name)
	if typeof(value) ~= "number" then value = folder and folder:GetAttribute(name) end
	if typeof(value) ~= "number" then value = fallback end
	if minimum and maximum then return math.clamp(value, minimum, maximum) end
	return value
end

function configBool(folderName, name, fallback)
	local folder = configFolder(folderName)
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "boolean" then
		return fallback
	end
	return value
end

local function currentCamera()
	local context = state.Context
	return context and typeof(context.GetCamera) == "function" and context.GetCamera() or Workspace.CurrentCamera
end

local function markCameraInput()
	state.LastCameraInputTime = os.clock()
end

local function touchCanOrbit(input)
	local cam = currentCamera()
	local viewport = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return input.Position.Y < viewport.Y * 0.58
end

local function disconnectCameraInput()
	for _, connection in ipairs(state.CameraInputConnections) do
		connection:Disconnect()
	end
	state.CameraInputConnections = {}
	state.CameraMouseDown = false
	state.CameraTouchInput = nil
end

local function connectCameraInput()
	disconnectCameraInput()
	table.insert(state.CameraInputConnections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			state.CameraMouseDown = true
			markCameraInput()
		elseif input.UserInputType == Enum.UserInputType.Touch and touchCanOrbit(input) then
			state.CameraTouchInput = input
			markCameraInput()
		end
	end))
	table.insert(state.CameraInputConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			state.CameraMouseDown = false
			markCameraInput()
		elseif input.UserInputType == Enum.UserInputType.Touch and state.CameraTouchInput == input then
			state.CameraTouchInput = nil
			markCameraInput()
		end
	end))
	table.insert(state.CameraInputConnections, UserInputService.InputChanged:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement and state.CameraMouseDown then
			markCameraInput()
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			state.PlayerAdjustedZoom = true
			markCameraInput()
		elseif input.UserInputType == Enum.UserInputType.Touch and state.CameraTouchInput == input then
			markCameraInput()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.14 then
			markCameraInput()
		end
	end))
end
local drivingCameraController
local function getDrivingCameraController()
	if drivingCameraController then return drivingCameraController end
	local moduleScript = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):FindFirstChild("DrivingCameraClient")
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		warn("[Driving Camera] DrivingCameraController missing; Roblox default camera remains active")
		return nil
	end
	local ok, result = pcall(require, moduleScript)
	if not ok or typeof(result) ~= "table" then
		warn("[Driving Camera] DrivingCameraController failed to load: " .. tostring(result))
		return nil
	end
	drivingCameraController = result
	return result
end

local function startCameraAssist()
	local controller = getDrivingCameraController()
	if controller and typeof(controller.Start) == "function" then
		controller.Start({
			Vehicle = state.Vehicle,
			GetCamera = currentCamera,
			GetCharacter = character,
			IsAccelerating = function() return state.AccelCameraActive end,
			IsBoosting = function() return state.BoostCameraActive end,
		})
	end
end

local function stopCameraAssist()
	if drivingCameraController and typeof(drivingCameraController.Stop) == "function" then drivingCameraController.Stop() end
	state.AccelCameraActive = false
	state.BoostCameraActive = false
	state.WobblePitch = 0
	state.WobbleRoll = 0
	state.WobbleYaw = 0
	state.WobbleBob = 0
	if state.Vehicle then
		state.Vehicle:SetAttribute("HoverPoseRideHeight", nil)
		state.Vehicle:SetAttribute("HoverPoseSettle", nil)
		state.Vehicle:SetAttribute("HoverPoseLift", nil)
	end
end

local function poseSmoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Hover pose tuning (Config.Vehicles.HoverPose and HoverWobble), re-read four times a second into one reused table.
local function refreshPoseConfig()
	local c = state.PoseConfig
	c.SettleEnabled = configBool("HoverPose", "SettleEnabled", true)
	c.SettleRestScale = configNumber("HoverPose", "SettleRestScale", 0.7, 0.3, 1)
	c.SettleStartMph = configNumber("HoverPose", "SettleStartMph", 1, 0, 40)
	c.SettleFullHeightMph = configNumber("HoverPose", "SettleFullHeightMph", 22, 2, 200)
	c.SettleFrequencyHz = configNumber("HoverPose", "SettleFrequencyHz", 1.3, 0.2, 4)
	c.SettleDamping = configNumber("HoverPose", "SettleDamping", 0.3, 0.1, 2)
	c.SettleThrottleLift = configNumber("HoverPose", "SettleThrottleLift", 0.6, 0, 1)
	c.SettleThrottleDeadzone = configNumber("HoverPose", "SettleThrottleDeadzone", 0.05, 0, 0.5)
	c.BankLiftEnabled = configBool("HoverPose", "BankLiftEnabled", true)
	c.BankLiftAmount = configNumber("HoverPose", "BankLiftAmount", 0.7, 0, 1.5)
	c.BankLiftMaxStuds = configNumber("HoverPose", "BankLiftMaxStuds", 2.4, 0, 6)
	c.BankLiftLeadSeconds = configNumber("HoverPose", "BankLiftLeadSeconds", 0.2, 0, 0.5)
	c.BankLiftRiseHz = configNumber("HoverPose", "BankLiftRiseHz", 4, 0.3, 6)
	c.BankLiftFallHz = configNumber("HoverPose", "BankLiftFallHz", 1.4, 0.3, 6)
	c.MinEdgeClearanceStuds = configNumber("HoverPose", "MinEdgeClearanceStuds", 0.25, 0, 2)
	c.LeanSpringCompensation = configNumber("HoverPose", "LeanSpringCompensation", 1, 0, 1)
	c.DebugAttributes = configBool("HoverPose", "DebugAttributes", false)
	c.WobbleFadeOutMph = configNumber("HoverWobble", "WobbleFadeOutMph", 20, 1, 80)
	c.WobbleAmountDegrees = configNumber("HoverWobble", "WobbleAmountDegrees", 1.5, 0, 8)
	c.WobbleSpeed = configNumber("HoverWobble", "WobbleSpeed", 1.15, 0.05, 8)
	c.WobbleRandomiseAmount = configNumber("HoverWobble", "WobbleRandomiseAmount", 0.65, 0, 2)
	c.WobblePitchMultiplier = configNumber("HoverWobble", "WobblePitchMultiplier", 0.75, 0, 3)
	c.WobbleRollMultiplier = configNumber("HoverWobble", "WobbleRollMultiplier", 1, 0, 3)
	c.WobbleSmoothing = configNumber("HoverWobble", "WobbleSmoothing", 4.5, 0.25, 18)
	c.WobbleDetailAmount = configNumber("HoverWobble", "WobbleDetailAmount", 0.6, 0, 2)
	c.WobbleBobStuds = configNumber("HoverWobble", "WobbleBobStuds", 0.06, 0, 0.4)
	c.WobbleYawDegrees = configNumber("HoverWobble", "WobbleYawDegrees", 0.35, 0, 4)
	c.WobbleRestBoost = configNumber("HoverWobble", "WobbleRestBoost", 0.3, 0, 2)
	c.WobbleRestMph = configNumber("HoverWobble", "WobbleRestMph", 4, 0.5, 40)
	c.WobbleAtSpeedAmount = configNumber("HoverWobble", "WobbleAtSpeedAmount", 0.15, 0, 1)
	c.WobbleAtSpeedSpeedBoost = configNumber("HoverWobble", "WobbleAtSpeedSpeedBoost", 1, 0, 4)
	return c
end

-- Runs once per Controller.Start: walks the visible parts and keeps the few box corners (|x|, y in root space)
-- that can be the lowest point of the body for some roll between 0 and 28 degrees. The bank lift reads only these.
local function measureHoverBody(vehicle)
	local xs, ys = state.PoseProfileX, state.PoseProfileY
	table.clear(xs)
	table.clear(ys)
	state.PoseHalfLength = 6
	local root = vehicle and vehicle.PrimaryPart
	if not root then return end
	local rootHalf = root.Size * 0.5
	local partX, partY = { rootHalf.X }, { -rootHalf.Y }
	local halfLength = rootHalf.Z
	local inverse = root.CFrame:Inverse()
	for _, part in ipairs(vehicle:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root and part.Transparency < 0.99 then
			local rel = inverse * part.CFrame
			local half = part.Size * 0.5
			local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
			local extentX = math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z
			local extentY = math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z
			local extentZ = math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
			local x = math.min(math.abs(rel.Position.X) + extentX, rootHalf.X + 6)
			local y = math.max(rel.Position.Y - extentY, -rootHalf.Y - 1.5)
			if x == x and y == y then
				partX[#partX + 1] = x
				partY[#partY + 1] = y
				if y < 0.5 then
					local z = math.min(math.abs(rel.Position.Z) + extentZ, rootHalf.Z + 12)
					if z == z then halfLength = math.max(halfLength, z) end
				end
			end
		end
	end
	for step = 0, 7 do
		local angle = math.rad(step * 4)
		local sinAngle, cosAngle = math.sin(angle), math.cos(angle)
		local best, bestDepth = 1, -math.huge
		for index = 1, #partX do
			local depth = partX[index] * sinAngle - partY[index] * cosAngle
			if depth > bestDepth then best, bestDepth = index, depth end
		end
		local seen = false
		for index = 1, #xs do
			if xs[index] == partX[best] and ys[index] == partY[best] then seen = true end
		end
		if not seen then
			xs[#xs + 1] = partX[best]
			ys[#ys + 1] = partY[best]
		end
	end
	state.PoseHalfLength = halfLength
	local text = ""
	for index = 1, #xs do
		text ..= string.format("%s%.2f,%.2f", index > 1 and ";" or "", xs[index], ys[index])
	end
	vehicle:SetAttribute("HoverPoseProfile", text)
	vehicle:SetAttribute("HoverPoseHalfLength", halfLength)
end

-- How far the lowest point of the body sits below the root centre at a given roll (positive studs).
local function poseBodyDepth(sinLean, cosLean)
	local xs, ys = state.PoseProfileX, state.PoseProfileY
	local count = #xs
	if count == 0 then return 4 * sinLean + 0.6 * cosLean end
	local best = -math.huge
	for index = 1, count do
		local depth = xs[index] * sinLean - ys[index] * cosLean
		if depth > best then best = depth end
	end
	return best
end

-- Ride height owner: rideHeight = HOVER_HEIGHT * settle + bankLift + bob. Writes state.PoseRideHeight and the
-- per-corner lean terms the hover loop adds to each corner target. Only the target moves; the corner springs
-- are unchanged, and nothing here reads the measured height after the first frame, so it cannot feed back.
local function updateHoverPose(dt, speedMph, forwardSpeed, throttle, hoverResults)
	dt = math.clamp(dt or 0, 1 / 240, 0.1)
	state.PoseConfigTimer -= dt
	if state.PoseConfigTimer <= 0 or state.PoseConfig.SettleRestScale == nil then
		state.PoseConfigTimer = 0.25
		refreshPoseConfig()
	end
	local c = state.PoseConfig
	if speedMph ~= speedMph then speedMph = 0 end
	local steps = math.clamp(math.ceil(dt * 60 - 0.001), 1, 6)
	local stepTime = dt / steps

	-- Settle: sink onto the cushion at a standstill, rise with speed or as soon as the throttle is pressed.
	local settle = 1
	if c.SettleEnabled then
		local curve = poseSmoothstep((speedMph - c.SettleStartMph) / math.max(c.SettleFullHeightMph - c.SettleStartMph, 1))
		local intent = 0
		if throttle > c.SettleThrottleDeadzone then
			intent = math.clamp(throttle, 0, 1)
		elseif throttle < -c.SettleThrottleDeadzone and forwardSpeed * MPH_PER_STUD < 4 then
			intent = math.clamp(-throttle, 0, 1)
		end
		local target = c.SettleRestScale + (1 - c.SettleRestScale) * math.max(curve, intent * c.SettleThrottleLift)
		if state.PoseSettle == nil then
			-- first frame after Start or after an anchored spell: begin from where the car actually is
			local sum, count = 0, 0
			for index = 1, 4 do
				local result = hoverResults[index]
				if result then
					sum += result.Distance - SENSOR_START_HEIGHT
					count += 1
				end
			end
			state.PoseSettle = count > 0 and math.clamp(sum / count / HOVER_HEIGHT, c.SettleRestScale, 1.3) or target
			state.PoseSettleVelocity = 0
		end
		local omega = c.SettleFrequencyHz * 2 * math.pi
		local position, velocity = state.PoseSettle, state.PoseSettleVelocity
		for _ = 1, steps do
			velocity += (omega * omega * (target - position) - 2 * c.SettleDamping * omega * velocity) * stepTime
			position += velocity * stepTime
		end
		if position ~= position or velocity ~= velocity then
			position, velocity = target, 0
		end
		state.PoseSettle = math.clamp(position, 0.3, 1.5)
		state.PoseSettleVelocity = math.clamp(velocity, -20, 20)
		settle = state.PoseSettle
	else
		state.PoseSettle = nil
		state.PoseSettleVelocity = 0
	end

	local bob = state.WobbleBob
	if bob ~= bob then bob = 0 end
	local base = HOVER_HEIGHT * settle + bob

	-- Bank lift: give back what the lowest point of the body loses to the lean (last frame's bank and wobble).
	local lean = state.CurrentBank + state.WobbleRoll
	local pitch = state.PosePitch
	if lean ~= lean then lean = 0 end
	if pitch ~= pitch then pitch = 0 end
	local leanRate = (lean - state.PoseLean) / dt
	state.PoseLean = lean
	local lift = 0
	if c.BankLiftEnabled then
		local ahead = math.abs(lean + leanRate * c.BankLiftLeadSeconds)
		local used = math.min(math.max(math.abs(lean), ahead), 0.6)
		local level = poseBodyDepth(0, 1)
		local loss = math.max(poseBodyDepth(math.sin(used), math.cos(used)) - level, 0)
		local want = loss * c.BankLiftAmount
		if c.MinEdgeClearanceStuds > 0 then
			local pitchDrop = state.PoseHalfLength * math.sin(math.min(math.abs(pitch), 0.5))
			want = math.max(want, c.MinEdgeClearanceStuds + level + loss + pitchDrop - base)
		end
		want = math.clamp(want, 0, c.BankLiftMaxStuds)
		local position, velocity = state.PoseLift, state.PoseLiftVelocity
		for _ = 1, steps do
			local omega = (want > position and c.BankLiftRiseHz or c.BankLiftFallHz) * 2 * math.pi
			velocity += (omega * omega * (want - position) - 2 * omega * velocity) * stepTime
			position += velocity * stepTime
		end
		if position ~= position or velocity ~= velocity then
			position, velocity = want, 0
		end
		state.PoseLift = math.clamp(position, 0, c.BankLiftMaxStuds)
		state.PoseLiftVelocity = math.clamp(velocity, -40, 40)
		lift = state.PoseLift
	else
		state.PoseLift = 0
		state.PoseLiftVelocity = 0
	end

	state.PoseRideHeight = math.clamp(base + lift, math.min(0.5, HOVER_HEIGHT), HOVER_HEIGHT * 2)
	-- Corner targets follow the commanded lean, so the four springs hold the same pose the AlignOrientation asks
	-- for instead of pushing the low side up and letting the high side fall.
	local compensation = c.LeanSpringCompensation
	state.PoseRollTerm = math.sin(lean) * math.cos(pitch) * compensation
	state.PosePitchTerm = math.sin(pitch) * compensation
	if c.DebugAttributes and state.Vehicle then
		state.Vehicle:SetAttribute("HoverPoseRideHeight", math.floor(state.PoseRideHeight * 100 + 0.5) / 100)
		state.Vehicle:SetAttribute("HoverPoseSettle", math.floor(settle * 100 + 0.5) / 100)
		state.Vehicle:SetAttribute("HoverPoseLift", math.floor(lift * 100 + 0.5) / 100)
	end
end

local function updateHoverWobble(dt, speedMph, grounded)
	dt = math.clamp(dt or 0, 0, 0.1)
	local c = state.PoseConfig
	if c.WobbleSpeed == nil then c = refreshPoseConfig() end
	local enabled = configBool("HoverWobble", "WobbleEnabled", true)
	if not enabled or not grounded then
		local decay = 1 - math.exp(-6 * dt)
		state.WobblePitch += (0 - state.WobblePitch) * decay
		state.WobbleRoll += (0 - state.WobbleRoll) * decay
		state.WobbleYaw += (0 - state.WobbleYaw) * decay
		state.WobbleBob += (0 - state.WobbleBob) * decay
		return state.WobblePitch, state.WobbleRoll
	end

	speedMph = speedMph or 0
	if speedMph ~= speedMph then speedMph = 0 end
	local speedFraction = math.clamp(speedMph / c.WobbleFadeOutMph, 0, 1)
	local idle = 1 - speedFraction
	local restBoost = 1 + c.WobbleRestBoost * (1 - poseSmoothstep(speedMph / c.WobbleRestMph))
	-- idle sway fades with speed as before; a small faster trace stays alive at speed
	local strength = math.max(idle, c.WobbleAtSpeedAmount) * restBoost
	local randomise = c.WobbleRandomiseAmount
	local detail = c.WobbleDetailAmount

	state.WobbleTime += dt * c.WobbleSpeed * (1 + c.WobbleAtSpeedSpeedBoost * speedFraction)
	local t = state.WobbleTime
	local seedX, seedY, seedZ = state.WobbleSeedX, state.WobbleSeedY, state.WobbleSeedZ
	local slowPitch = math.noise(seedX, t, 0) + math.noise(seedX + 17.3, t * 2.31, 0.5) * 0.45 * detail
	local slowRoll = math.noise(seedZ, 0, t * 1.13) + math.noise(seedZ + 41.9, 0.5, t * 2.57) * 0.45 * detail
	local flutterPitch = math.sin(t * 2.7 + seedX) * 0.22
	local flutterRoll = math.sin(t * 2.1 + seedZ) * 0.22
	local radians = math.rad(c.WobbleAmountDegrees) * strength
	local targetPitch = (slowPitch + flutterPitch * randomise) * radians * c.WobblePitchMultiplier
	local targetRoll = (slowRoll + flutterRoll * randomise) * radians * c.WobbleRollMultiplier
	local targetYaw = (math.noise(seedY, t * 0.71, 3.3) + math.sin(t * 0.83 + seedY) * 0.3 * randomise) * math.rad(c.WobbleYawDegrees) * idle * restBoost
	local targetBob = (math.sin(t * 1.57 + seedY) * 0.6 + math.noise(seedY + 9.1, t * 0.9, 7.7) * 0.9) * c.WobbleBobStuds * strength
	local alpha = 1 - math.exp(-c.WobbleSmoothing * dt)
	state.WobblePitch += (targetPitch - state.WobblePitch) * alpha
	state.WobbleRoll += (targetRoll - state.WobbleRoll) * alpha
	state.WobbleYaw += (targetYaw - state.WobbleYaw) * alpha
	state.WobbleBob += (targetBob - state.WobbleBob) * alpha
	if state.WobblePitch ~= state.WobblePitch or state.WobbleRoll ~= state.WobbleRoll or state.WobbleYaw ~= state.WobbleYaw or state.WobbleBob ~= state.WobbleBob then
		state.WobblePitch, state.WobbleRoll, state.WobbleYaw, state.WobbleBob = 0, 0, 0, 0
	end
	return state.WobblePitch, state.WobbleRoll
end
local function setVehicleCamera(vehicle)
	local cam = currentCamera()
	if not cam or cam:GetAttribute("DrivingCameraManaged") == true then return end
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	cam.CameraType = Enum.CameraType.Custom
	if seat and seat:IsA("VehicleSeat") then
		cam.CameraSubject = seat
	else
		local h = humanoid()
		if h then cam.CameraSubject = h end
	end
end

local function showExistingDriveUi()
	local context = state.Context
	if not context then return end
	if typeof(context.ShowDriveUi) == "function" then
		pcall(context.ShowDriveUi)
	end
	if typeof(context.SetMobileDriving) == "function" then
		pcall(context.SetMobileDriving, true)
	end
end

local function updateExistingDriveUi(speedMph)
	local context = state.Context
	if not context then return end
	if configBool("Driving", "SpeedDisplayCurveEnabled", true) then
		local low = configNumber("Driving", "SpeedDisplayLowMultiplier", 0.86, 0.5, 1.5)
		local high = math.max(low, configNumber("Driving", "SpeedDisplayHighMultiplier", 1.08, 0.5, 1.5))
		local alpha = math.clamp(speedMph / configNumber("Driving", "SpeedDisplayFullMph", 200, 10, 500), 0, 1)
		alpha = alpha * alpha * (3 - 2 * alpha)
		speedMph *= low + (high - low) * alpha
	end
	if typeof(context.UpdateDriveUi) == "function" then
		pcall(context.UpdateDriveUi, speedMph, state.Boost, state.DriftBlend > 0.12, state.DriftCharge, state.MiniBoostTimer)
	end
	if typeof(context.PublishMobile) == "function" then
		if Drivetrain.TelemetryReady then
			-- Drivetrain HUD telemetry (CONTRACT 3.2): one preallocated table, refilled every frame.
			pcall(context.PublishMobile, speedMph, state.Boost, Drivetrain.Telemetry)
		else
			pcall(context.PublishMobile, speedMph, state.Boost)
		end
	end
end

local FEEL_ATTRIBUTES = {"FeelThrottle", "FeelSpeedMph", "FeelSlip", "FeelBoostCharge", "FeelBoostKind", "FeelDriftCharge", "FeelGrounded", "FeelHover", "FeelImpactRevision", "FeelImpactStrength", "FeelLandRevision", "FeelLandStrength", "FeelPopRevision", "FeelPopStrength", "FeelImpactX", "FeelImpactZ", "FeelScrape",
	"FeelRpm", "FeelIdleRpm", "FeelRedlineRpm", "FeelLimiterRpm", "FeelGearCount", "FeelGear", "FeelLoad", "FeelShiftRevision", "FeelShiftKind", "FeelShiftStrength", "FeelCut", "FeelLimiterRevision", "FeelThrustSlip", "FeelSpin", "FeelSpinDirection", "FeelOverdrive"}
-- Car-local directions probed for a wall: left, right, ahead (-Z is forward).
local FEEL_WALL_PROBES = { { -1, 0 }, { 1, 0 }, { 0, -1 } }
local function clearFeelState(vehicle)
	if not vehicle then return end
	for _, name in ipairs(FEEL_ATTRIBUTES) do vehicle:SetAttribute(name, nil) end
end
local function quantise(value, step)
	return math.floor(value / step + 0.5) * step
end
-- Publishes the continuous Feel state read by the camera, audio and VFX owners (scripts/hover_feel/CONTRACT.md).
-- Client-local attributes. It observes the frame only: no force, input or equation depends on it.
local function publishFeelState(dt, vehicle, throttle, velocity, speedMph, sideSpeed, grounded, hits, driveForce, mass)
	local feel = state.Feel
	if not feel then return end
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	-- Impact: horizontal speed change that last frame's drive force does not explain.
	local root = vehicle.PrimaryPart
	local unexplained = Vector3.zero
	if feel.PreviousVelocity and not feel.Skip and dt <= 0.05 then
		unexplained = horizontal - feel.PreviousVelocity - feel.PreviousAcceleration * dt
		local strength = unexplained.Magnitude
		if strength >= configNumber("Driving", "FeelImpactMinStuds", 9, 1, 200) and os.clock() - feel.LastImpact > 0.12 then
			feel.ImpactRevision += 1
			feel.LastImpact = os.clock()
			if root then
				-- The car was pushed along the unexplained change, so the thing it hit lies the other way.
				local toward = root.CFrame:VectorToObjectSpace(-unexplained.Unit)
				vehicle:SetAttribute("FeelImpactX", quantise(toward.X, 0.05))
				vehicle:SetAttribute("FeelImpactZ", quantise(toward.Z, 0.05))
				if Drivetrain.Active and Drivetrain.Tuning then
					-- Drivetrain weight: a sideways push off the centre line turns the car through its yaw rate next frame
					-- (ImpactYawKick rad/s per 100 studs/s; a push on the nose turns it the way it was pushed).
					local push = root.CFrame:VectorToObjectSpace(unexplained)
					Drivetrain.ImpactKick = math.clamp(Drivetrain.ImpactKick + Drivetrain.Tuning.ImpactYawKick * push.X * toward.Z / 100, -3, 3)
				end
			end
			vehicle:SetAttribute("FeelImpactStrength", strength)
			vehicle:SetAttribute("FeelImpactRevision", feel.ImpactRevision)
		end
	end
	-- Scrape: something solid beside or ahead of the car while an unexplained force keeps acting on it.
	feel.ScrapeTimer += dt
	if root and feel.ScrapeTimer >= 0.1 then
		feel.ScrapeTimer = 0
		feel.WallX, feel.WallZ = nil, nil
		if speedMph > 15 and state.RayParams then
			local frame = root.CFrame
			local half = root.Size * 0.5
			for _, probe in ipairs(FEEL_WALL_PROBES) do
				local reach = frame:VectorToWorldSpace(Vector3.new(probe[1] * (half.X + 2), 0, probe[2] * (half.Z + 2)))
				if Workspace:Raycast(frame.Position, reach, state.RayParams) then
					feel.WallX, feel.WallZ = probe[1], probe[2]
					break
				end
			end
		end
	end
	local rubbing = feel.WallX ~= nil and math.clamp((unexplained.Magnitude / math.max(dt, 1 / 240) - 12) / 60, 0, 1) or 0
	feel.Scrape += (rubbing - feel.Scrape) * math.clamp(dt * 10, 0, 1)
	if feel.Scrape > 0.1 and feel.WallX then
		vehicle:SetAttribute("FeelImpactX", feel.WallX)
		vehicle:SetAttribute("FeelImpactZ", feel.WallZ)
	end
	vehicle:SetAttribute("FeelScrape", quantise(feel.Scrape, 0.05))
	feel.PreviousVelocity = horizontal
	feel.PreviousAcceleration = Vector3.new(driveForce.X, 0, driveForce.Z) / mass
	feel.Skip = feel.SkipNext
	-- Landing: airborne for a moment, then grounded again.
	if grounded then
		if feel.AirTime >= 0.15 then
			feel.LandRevision += 1
			vehicle:SetAttribute("FeelLandStrength", feel.FallSpeed)
			vehicle:SetAttribute("FeelLandRevision", feel.LandRevision)
		end
		feel.AirTime = 0
	else
		feel.AirTime += dt
		feel.FallSpeed = math.max(0, -velocity.Y)
	end
	local speedStuds = velocity.Magnitude
	vehicle:SetAttribute("FeelThrottle", quantise(math.clamp(throttle, -1, 1), 0.02))
	vehicle:SetAttribute("FeelSpeedMph", quantise(speedMph, 0.5))
	local slipFloorMph = 8
	if Drivetrain.Active then slipFloorMph = 2 end -- drivetrain classes: a low-speed spin shows as slip
	vehicle:SetAttribute("FeelSlip", speedMph >= slipFloorMph and quantise(math.clamp(sideSpeed / speedStuds, -1, 1), 0.02) or 0)
	vehicle:SetAttribute("FeelBoostCharge", math.floor(state.Boost + 0.5))
	vehicle:SetAttribute("FeelBoostKind", feel.BoostKind)
	vehicle:SetAttribute("FeelDriftCharge", quantise(math.clamp(state.DriftCharge / 3.25, 0, 1), 0.02))
	vehicle:SetAttribute("FeelGrounded", grounded)
	vehicle:SetAttribute("FeelHover", hits > 0 and quantise(math.clamp(feel.HoverSum / hits / HOVER_HEIGHT, -1, 1), 0.02) or 0)
	-- Pops: a bang and a hard run after lifting off sustained thrust. A boost that ends fires nothing.
	if configBool("Driving", "FeelPopsEnabled", true) then
		local now = os.clock()
		local pop = nil
		if throttle > 0.6 and speedMph > 40 then
			feel.LoadTime = math.min(feel.LoadTime + dt, 3)
		elseif throttle <= 0.1 then
			if feel.LoadTime >= 0.8 and feel.BoostKind == "" then
				-- Lift-off: one bang straight away, then a fast, hard run.
				pop = 0.9 + math.random() * 0.1
				feel.PopsLeft = math.random(3, 6)
				feel.NextPop = now + 0.07
			end
			feel.LoadTime = 0
		end
		if not pop and feel.PopsLeft > 0 and now >= feel.NextPop then
			feel.PopsLeft -= 1
			feel.NextPop = now + 0.05 + math.random() * 0.12
			pop = 0.5 + math.random() * 0.29
		end
		if pop then
			feel.PopRevision += 1
			vehicle:SetAttribute("FeelPopStrength", quantise(pop, 0.01))
			vehicle:SetAttribute("FeelPopRevision", feel.PopRevision)
		end
	end
	feel.PreviousBoostKind = feel.BoostKind
end

-- Drivetrain feel helpers. Called only while Drivetrain.Active (the class folder is enabled for this car).
local function setFeel(vehicle, name, value)
	local cache = Drivetrain.FeelCache
	if cache[name] ~= value then
		cache[name] = value
		vehicle:SetAttribute(name, value)
	end
end

local function setDebug(vehicle, name, value)
	local cache = Drivetrain.DebugCache
	if cache[name] ~= value then
		cache[name] = value
		vehicle:SetAttribute(name, value)
	end
end

local function clearDrivetrainFeel(vehicle)
	table.clear(Drivetrain.FeelCache)
	Drivetrain.TelemetryReady = false
	if not vehicle then return end
	for _, name in ipairs(DRIVETRAIN_FEEL_ATTRIBUTES) do vehicle:SetAttribute(name, nil) end
end

-- Clears the yaw rate (steering and spin parts), spin, gesture clocks and windows, steer limiter, lateral filter and
-- the pitch and roll springs, and restarts the spin start grace without its speed clause (the anchored resume and the
-- DriveReady edge turn that on). The flick latch starts clear and LastSteer at 0, so a wheel held through Start or R is
-- not a flick until it has passed back under min(0.5, SpinStabSteer). The gearbox is reset by the caller (it needs the
-- speed).
local function resetDrivetrainChassis()
	local chassis, spin = Drivetrain.Chassis, Drivetrain.Spin
	chassis.YawRate, chassis.SteerYawRate, chassis.SpinYawRate, chassis.YawAccel, chassis.YawCommand, chassis.Authority, chassis.SpinAccel = 0, 0, 0, 0, 0, 1, 0
	chassis.LateralAccel, chassis.LateralApplied = 0, 0
	chassis.Pitch, chassis.PitchVelocity, chassis.Roll, chassis.RollVelocity = 0, 0, 0, 0
	spin.L, spin.Dir, spin.Target, spin.Window, spin.Warn, spin.Caught, spin.Settling = 0, 0, 0, 0, false, false, false
	spin.WasOn, spin.Armed, spin.LiftClock, spin.RiseClock, spin.ThrottleClock, spin.FlickClock = false, false, 0, 0, STAB_NONE, STAB_NONE
	spin.SteerLow, spin.LastSteer, spin.PowerBrakeClock, spin.DumpSlip, spin.DumpClock = false, 0, 0, 0, 0
	spin.GraceClock, spin.GraceSpeedReached, spin.GraceNeedsSpeed = 0, false, false
	Drivetrain.SteerKeyboard, Drivetrain.SteerTouch = 0, 0
	Drivetrain.ImpactKick, Drivetrain.ExtraSlip, Drivetrain.PowerBrakeHeld = 0, 0, false
	Drivetrain.BoostApplied, Drivetrain.BoostAccel = false, 0
end

-- About 4 times a second and on Start: resolve the class, re-read its folder (VehicleDynamics compares GetAttributes()
-- and re-parses strings only when they changed) and switch the drivetrain on or off for this car.
local function refreshDrivetrain(vehicle, force)
	local category = VehicleDynamicsModel.DrivetrainCategory(vehicle)
	local tuning = category and VehicleDynamicsModel.DrivetrainTuning(category, force) or nil
	local active = tuning ~= nil and tuning.Active == true
	if active ~= Drivetrain.Active then
		if not active then clearDrivetrainFeel(vehicle) end
		resetDrivetrainChassis()
		Drivetrain.ResetPending = active
		Drivetrain.WasAnchored = false
		-- Switching on is not a DriveReady restart: the current value is the baseline.
		if active then Drivetrain.DriveReady = vehicle:GetAttribute("DriveReady") == true end
	end
	Drivetrain.Active = active
	Drivetrain.Tuning = active and tuning or nil
	Drivetrain.Category = category
	if not active then return end
	Drivetrain.Debug = configBool("Dynamics", "DebugAttributes", true)
	local ready = vehicle:GetAttribute("DriveReady") == true
	if ready and not Drivetrain.DriveReady then
		-- DriveReady coming back (after a staging spell) restarts the spin grace, with its speed clause.
		local spin = Drivetrain.Spin
		spin.GraceClock, spin.GraceSpeedReached, spin.GraceNeedsSpeed = 0, false, true
	end
	Drivetrain.DriveReady = ready
end

-- First moving frame after a reset request or an anchored spell.
local function drivetrainResume(throttle, forwardMph)
	if Drivetrain.WasAnchored then
		-- Unanchored (race, duel or teleport start): first gear at the revved rpm, a launch slip from those revs, and the
		-- spin start grace begins, with its speed clause. This is also the reset, so a pending one is dropped. With no
		-- throttle (a teleport) there is no Launch event: the gearbox just resets to the road speed.
		Drivetrain.WasAnchored = false
		Drivetrain.ResetPending = false
		local tuning, box = Drivetrain.Tuning, Drivetrain.Gearbox
		local revved = math.clamp((box.Rpm / tuning.RedlineRpm - 0.5) / 0.4, 0, 1)
		resetDrivetrainChassis()
		Drivetrain.Spin.GraceNeedsSpeed = true
		if throttle > 0.05 then
			VehicleDynamicsModel.LaunchGearbox(box, math.max(throttle, 0))
			if tuning.PowerBrakeEnabled then
				Drivetrain.Spin.DumpSlip = tuning.PowerBrakeDumpSlip * revved * revved * (3 - 2 * revved)
				Drivetrain.Spin.DumpClock = 0
			end
		else
			VehicleDynamicsModel.ResetGearbox(box, tuning, Drivetrain.Profile, forwardMph, false)
		end
	elseif Drivetrain.ResetPending then
		Drivetrain.ResetPending = false
		resetDrivetrainChassis()
		VehicleDynamicsModel.ResetGearbox(Drivetrain.Gearbox, Drivetrain.Tuning, Drivetrain.Profile, forwardMph, false)
	end
end

-- Spin gestures and the start grace, before the longitudinal step (they feed its launch revs and extra slip).
local function drivetrainGestures(dt, throttle, rawSteer, speedMph)
	local tuning, spin = Drivetrain.Tuning, Drivetrain.Spin
	local step = math.clamp(dt, 0, 0.1)
	spin.GraceClock += step
	if speedMph > tuning.SpinStartGraceMph then spin.GraceSpeedReached = true end
	spin.Window = math.max(spin.Window - step, 0)
	spin.DumpClock += step
	spin.ThrottleClock += step
	spin.FlickClock += step
	-- Stab: a lift, then a throttle stab and a steering flick together. A held wheel plus W (pull-outs, U-turns, a lifted
	-- U-turn) is never a stab.
	-- Throttle event: armed only by a lift (throttle from 0.3 or more to under 0.3). Keyboard and touch: back to 0.9 or
	-- more within SpinStabSeconds of the lift. Gamepad: the rise from under 0.3 to 0.9 or more faster than
	-- SpinAnalogRate per second.
	local forwardThrottle = math.max(throttle, 0)
	if forwardThrottle < 0.3 then
		if spin.WasOn then
			spin.Armed, spin.LiftClock = true, 0
		elseif spin.Armed then
			spin.LiftClock += step
		end
		spin.WasOn, spin.RiseClock = false, 0
	else
		spin.WasOn = true
		if spin.Armed then
			spin.LiftClock += step
			spin.RiseClock += step
			if forwardThrottle >= 0.9 then
				spin.Armed = false
				local quick
				if Drivetrain.AnalogThrottle then
					quick = spin.RiseClock <= 0.6 / tuning.SpinAnalogRate + step
				else
					quick = spin.LiftClock <= tuning.SpinStabSeconds + step
				end
				if quick then spin.ThrottleClock = 0 end
			end
		end
	end
	-- Flick event: |raw steer| rises from under 0.5 (or under SpinStabSteer when that is lower) to SpinStabSteer or more,
	-- or the raw steer reverses sign at SpinStabSteer or more.
	local steerSize = math.abs(rawSteer)
	if steerSize >= tuning.SpinStabSteer and (spin.SteerLow or rawSteer * spin.LastSteer < 0) then spin.FlickClock = 0 end
	if steerSize < math.min(0.5, tuning.SpinStabSteer) then
		spin.SteerLow = true
	elseif steerSize >= tuning.SpinStabSteer then
		spin.SteerLow = false
	end
	spin.LastSteer = rawSteer
	-- The stab fires when both events are within SpinFlickSeconds of now (either order) with the throttle and the lock
	-- still on, below SpinBelowMph (SpinStabNeedsFlick 0: the throttle event alone). It opens the spin window and dumps
	-- SpinStabDumpSlip of thrust slip, fading over the window like the power-brake.
	if spin.ThrottleClock <= tuning.SpinFlickSeconds and (not tuning.SpinStabNeedsFlick or spin.FlickClock <= tuning.SpinFlickSeconds)
		and forwardThrottle >= 0.9 and steerSize >= tuning.SpinStabSteer and speedMph < tuning.SpinBelowMph then
		local current = spin.DumpSlip * math.max(1 - spin.DumpClock / math.max(tuning.SpinWindowSeconds, 0.05), 0)
		spin.Window = tuning.SpinWindowSeconds
		spin.DumpSlip, spin.DumpClock = math.max(current, tuning.SpinStabDumpSlip), 0
		spin.ThrottleClock, spin.FlickClock = STAB_NONE, STAB_NONE
	end
	-- Power-brake: forward and brake held together at a standstill for PowerBrakeMinHold, then the brake released with
	-- the throttle still held. The force stays cancelled while both are held; the release dumps the revs as thrust slip.
	if tuning.PowerBrakeEnabled and Drivetrain.PowerBrakeInput and speedMph < tuning.StopGearMph then
		spin.PowerBrakeClock += step
	else
		if spin.PowerBrakeClock >= tuning.PowerBrakeMinHold and throttle > 0.5 then
			spin.Window = tuning.SpinWindowSeconds
			spin.DumpSlip, spin.DumpClock = tuning.PowerBrakeDumpSlip, 0
			VehicleDynamicsModel.LaunchGearbox(Drivetrain.Gearbox, 1)
		end
		spin.PowerBrakeClock = 0
	end
	Drivetrain.PowerBrakeHeld = spin.PowerBrakeClock > 0
	Drivetrain.ExtraSlip = spin.DumpSlip > 0 and spin.DumpSlip * math.max(1 - spin.DumpClock / math.max(tuning.SpinWindowSeconds, 0.05), 0) or 0
end

-- Critically sub-stepped spring (frame-rate independent); returns position, velocity.
local function springStep(position, velocity, target, omega, zeta, dt)
	local steps = math.clamp(math.ceil(dt * omega * 4), 1, 16)
	local h = dt / steps
	for _ = 1, steps do
		velocity += (omega * omega * (target - position) - 2 * zeta * omega * velocity) * h
		position += velocity * h
	end
	if position ~= position or velocity ~= velocity then return target, 0 end
	return position, velocity
end

-- Drift exemption weight (DriftCapExempt 1): clamp(DriftBlend x DriftExemptGain, 0, 1). It hands the lateral grip,
-- the yaw cap and (by DriftYawExempt) the yaw inertia back to today's drift, reaching full before the blend does so a
-- drift entry does not run into the grip cap. 0 when DriftCapExempt is 0.
local function driftExemptWeight(tuning)
	if not tuning.DriftCapExempt then return 0 end
	return math.clamp(state.DriftBlend * tuning.DriftExemptGain, 0, 1)
end

-- Lateral grip (replaces the linear damper while active): the normal grip saturates on a peaked curve
-- sin(C atan(u / C)) that peaks at the grip cap, builds over GripRelaxStuds x FeelWeight of travel, and loses
-- SpinGripLoss x spin. The drift share (driftExemptWeight) is today's uncapped damper. Returns the acceleration
-- along the car's right vector.
local function drivetrainLateral(dt, sideSpeed, handlingStep, lateralGrip, horizontalSpeed, balance)
	local tuning, profile, chassis = Drivetrain.Tuning, Drivetrain.Profile, Drivetrain.Chassis
	local step = math.clamp(dt, 0, 0.1)
	local cap = profile.LateralCapBase * (handlingStep.Enabled and handlingStep.DownforceFactor or 1) * balance.Grip
	chassis.LateralCap = cap
	local exempt = tuning.DriftCapExempt
	local grip = lateralGrip
	if exempt then grip = handlingStep.Enabled and handlingStep.NormalGrip or 6.6 end
	local target = -sideSpeed * grip
	if cap > 0 then
		local shape = tuning.LateralCurveShape
		target = cap * math.sin(shape * math.atan(target / (cap * shape)))
	end
	target *= 1 - tuning.SpinGripLoss * Drivetrain.Spin.L
	local relax = tuning.GripRelaxStuds * tuning.FeelWeight
	if relax <= 0 then
		chassis.LateralAccel = target
	else
		chassis.LateralAccel += (target - chassis.LateralAccel) * (1 - math.exp(-step * math.max(horizontalSpeed, 8) / relax))
	end
	if chassis.LateralAccel ~= chassis.LateralAccel then chassis.LateralAccel = 0 end
	local applied = chassis.LateralAccel
	local weight = driftExemptWeight(tuning)
	if weight > 0 then applied += (-sideSpeed * lateralGrip - applied) * weight end
	chassis.LateralApplied = applied
	return applied
end

-- Spin amount L (0..1): built from thrust slip, steering, low speed and an existing yaw rate; capped at
-- SpinHoldCap x FeelSpin outside a gesture window; caught by lifting or counter-steering. The direction latches at onset.
local function updateSpin(step, throttle, steer, rawSteer, speedMph, slip, command)
	local tuning, profile, chassis, spin = Drivetrain.Tuning, Drivetrain.Profile, Drivetrain.Chassis, Drivetrain.Spin
	local target = 0
	-- Start grace: SpinStartGraceSeconds; after an anchored start or a DriveReady restart also SpinStartGraceMph.
	local graceOver = spin.GraceClock >= tuning.SpinStartGraceSeconds and (tuning.SpinStartGraceMph <= 0 or not spin.GraceNeedsSpeed or spin.GraceSpeedReached)
	-- FeelSpin also scales the no-gesture cap, so the dial's upper half lets held locks wiggle harder (or spin).
	local holdCap = math.min(tuning.SpinHoldCap * tuning.FeelSpin, 1)
	if tuning.SpinEnabled and graceOver and state.DriftBlend <= 0.12 and tuning.FeelSpin > 0 then
		target = poseSmoothstep((slip - tuning.SpinSlipStart) / tuning.SpinSlipWidth)
			* poseSmoothstep((math.abs(steer) - tuning.SpinSteerStart) / tuning.SpinSteerWidth)
			* (1 - poseSmoothstep((speedMph - tuning.SpinBelowMph) / tuning.SpinFadeMph))
			* poseSmoothstep((math.abs(chassis.YawRate) - SPIN_YAW_GATE) / SPIN_YAW_GATE_WIDTH)
			* tuning.FeelSpin * profile.SpinTierScale * (Drivetrain.TouchInput and tuning.SpinTouchScale or 1)
		if spin.Window <= 0 then target = math.min(target, holdCap) end
		target = math.clamp(target, 0, 1)
		if target ~= target then target = 0 end
	end
	local catching = throttle < 0.3 or (spin.Dir ~= 0 and rawSteer * spin.Dir > 0 and math.abs(rawSteer) > 0.3)
	local rate = tuning.SpinDecayRate
	if catching then
		target, rate = 0, tuning.SpinCatchRate
	elseif target > spin.L then
		rate = tuning.SpinBuildRate
	end
	local previous = spin.L
	spin.L = math.clamp(spin.L + (target - spin.L) * (1 - math.exp(-rate * step)), 0, 1)
	if spin.L ~= spin.L then spin.L = 0 end
	spin.Target = target
	local rising = spin.L > previous + 1e-4
	-- The warning stays above the hold cap, so a capped wiggle never lights it.
	spin.Warn = spin.L > math.max(tuning.SpinWarnLevel, holdCap + 0.05) and rising
	-- After a catch (until the spin builds again) the spin's own yaw settles fast while L falls (drivetrainYaw).
	if catching then
		spin.Caught = true
	elseif rising then
		spin.Caught = false
	end
	spin.Settling = spin.Caught and spin.L < previous
	if spin.L > 0.05 and spin.Dir == 0 then
		local source = chassis.YawRate ~= 0 and chassis.YawRate or command
		spin.Dir = source > 0 and 1 or (source < 0 and -1 or 0)
	elseif spin.L < 0.02 then
		spin.Dir = 0
	end
	chassis.SpinAccel = spin.Dir * tuning.SpinYawAccel * tuning.FeelSpin * spin.L * (0.6 + 0.4 * math.min(slip / 0.5, 1))
end

-- Yaw rate (replaces the direct heading integration while active): two additive states, r = r_steer + r_spin.
-- r_steer: second-order spring toward command (YawOmega / FeelWeight, YawDamping), faster when unwinding, weakened by
-- the spin authority, kinematic below YawKinematicBelowMph (parking and standstill steering exactly as today) and,
-- by DriftYawExempt, in a drift. r_spin: the latched spin's own yaw, pushed while it turns the spin's way below
-- SpinMaxYawRate and settling at a rate that ignores FeelWeight, so spins do not depend on the weight dial.
-- command is today's full turn rate, grip-limited on forward intent. Returns the frame-average yaw rate, so the
-- heading run-on does not depend on the frame rate.
local function drivetrainYaw(dt, command, throttle, steer, rawSteer, speedMph, forwardSpeed, slip)
	local tuning, profile, chassis, spin = Drivetrain.Tuning, Drivetrain.Profile, Drivetrain.Chassis, Drivetrain.Spin
	local step = math.clamp(dt, 0, 0.1)
	if command ~= command then command = 0 end
	local exempt = driftExemptWeight(tuning)
	if state.SteeringProfileIntent == 1 and forwardSpeed > 8 and chassis.LateralCap > 0 then
		local limit = tuning.YawCapMargin * chassis.LateralCap * (1 + 1.5 * state.DriftBlend) / forwardSpeed
		local capped = math.clamp(command, -limit, limit)
		command = capped + (command - capped) * exempt
	end
	chassis.YawCommand = command
	updateSpin(step, throttle, steer, rawSteer, speedMph, slip, command)
	local rate, rateVelocity, spinRate = chassis.SteerYawRate + Drivetrain.ImpactKick, chassis.YawAccel, chassis.SpinYawRate
	Drivetrain.ImpactKick = 0
	local weight = tuning.FeelWeight
	local omega = profile.YawOmega / math.max(weight, 0.05)
	if math.abs(command) < math.abs(rate) or command * rate < 0 then omega *= tuning.YawUnwindScale end
	-- Authority drops with the spin and recovers over SpinSettleSeconds, so a caught car eases back to the command.
	local authority = 1 - tuning.SpinYawAuthorityLoss * spin.L
	if authority < chassis.Authority then
		chassis.Authority = authority
	else
		chassis.Authority += (authority - chassis.Authority) * (1 - math.exp(-step / math.max(tuning.SpinSettleSeconds, 0.01)))
	end
	-- At most 60 rad/s: effectively kinematic above, and the sub-steps stay stable through frame hitches.
	omega = math.min(math.max(omega * chassis.Authority, 1), 60)
	local zeta = tuning.YawDamping
	-- r_spin settles at the car's own yaw rate (no FeelWeight, no unwind scale); after a catch, while L falls, at least
	-- 3 / SpinSettleSeconds.
	local settle = math.max(profile.YawOmega * (1 - tuning.SpinYawAuthorityLoss * spin.L), 1) / (2 * zeta)
	if spin.Settling then settle = math.max(settle, 3 / math.max(tuning.SpinSettleSeconds, 0.01)) end
	local push = chassis.SpinAccel
	local spinCap = math.min(tuning.SpinMaxYawRate, tuning.YawRateMax)
	local steps = math.clamp(math.ceil(step * math.max(omega, settle) * 4), 1, 16)
	local h = step / steps
	local decay = math.min(settle * h, 1)
	local steerSum, spinSum = 0, 0
	for _ = 1, steps do
		-- The push gate reads the sub-step's start values.
		local total = rate + spinRate
		local extra = 0
		if push ~= 0 and total * spin.Dir > 0 and math.abs(total) < spinCap then extra = push end
		rateVelocity += (omega * omega * (command - rate) - 2 * zeta * omega * rateVelocity) * h
		rate += rateVelocity * h
		spinRate += extra * h - spinRate * decay
		steerSum += rate * h
		spinSum += spinRate * h
	end
	-- Kinematic blend, on r_steer only: below YawKinematicBelowMph and at FeelWeight 0 it is today's command; a drift
	-- takes DriftYawExempt of its exemption weight off the inertia too (the drift owns the yaw as it owns the grip).
	local dynamic = tuning.YawKinematicBelowMph > 0 and poseSmoothstep(speedMph / tuning.YawKinematicBelowMph) or 1
	if weight <= 0 then dynamic = 0 end
	dynamic *= 1 - exempt * tuning.DriftYawExempt
	rate = command + (rate - command) * dynamic
	rateVelocity *= dynamic
	rate = math.clamp(rate, -tuning.YawRateMax, tuning.YawRateMax)
	if rate ~= rate or rateVelocity ~= rateVelocity then rate, rateVelocity = command, 0 end
	if spinRate ~= spinRate then spinRate = 0 end
	local total = math.clamp(rate + spinRate, -tuning.YawRateMax, tuning.YawRateMax)
	chassis.SteerYawRate, chassis.YawAccel, chassis.SpinYawRate, chassis.YawRate = rate, rateVelocity, spinRate, total
	if step <= 0 then return total end
	local average = math.clamp(command + (steerSum / step - command) * dynamic + spinSum / step, -tuning.YawRateMax, tuning.YawRateMax)
	if average ~= average then return total end
	return average
end

-- Pitch from the real longitudinal acceleration (boost and mini-boost included) through a spring; replaces the
-- throttle-driven tilt while active and FeelWeight > 0. Returns radians.
local function drivetrainPitch(dt, longitudinal)
	local tuning, chassis = Drivetrain.Tuning, Drivetrain.Chassis
	local g = ((tonumber(longitudinal) or 0) + Drivetrain.BoostAccel) / G_STUDS
	local target = math.clamp(tuning.PitchDegreesPerG * tuning.FeelWeight * g, -tuning.PitchMaxDegrees, tuning.PitchMaxDegrees)
	if target ~= target then target = 0 end
	chassis.Pitch, chassis.PitchVelocity = springStep(chassis.Pitch, chassis.PitchVelocity, target, tuning.PitchOmega, tuning.PitchDamping, math.clamp(dt, 0, 0.1))
	state.AccelBrakePitchDegrees = chassis.Pitch
	if configBool("Driving", "AccelBrakeTiltDebugAttributes", true) then
		state.Vehicle:SetAttribute("AccelBrakePitchDegrees", chassis.Pitch)
	end
	return math.rad(chassis.Pitch)
end

-- A small body roll from lateral g on forward intent (RollDegreesPerG; 0 turns it off, negative flips it). Added on
-- top of the raw-steer bank, which is unchanged. Returns radians.
local function drivetrainRoll(dt)
	local tuning, chassis = Drivetrain.Tuning, Drivetrain.Chassis
	local target = 0
	if state.SteeringProfileIntent == 1 then
		target = math.clamp(tuning.RollDegreesPerG * tuning.FeelWeight * chassis.LateralApplied / G_STUDS * (1 - state.DriftBlend), -tuning.RollMaxDegrees, tuning.RollMaxDegrees)
		if target ~= target then target = 0 end
	end
	chassis.Roll, chassis.RollVelocity = springStep(chassis.Roll, chassis.RollVelocity, target, tuning.PitchOmega, tuning.PitchDamping, math.clamp(dt, 0, 0.1))
	return math.rad(chassis.Roll)
end

-- Feel attributes (written only on change) and the HUD telemetry for this frame's drivetrain step result.
local function publishDrivetrain(dt, out)
	local vehicle, tuning, box, spin = state.Vehicle, Drivetrain.Tuning, Drivetrain.Gearbox, Drivetrain.Spin
	if not vehicle or not tuning then return end
	local redline = tuning.RedlineRpm
	local rpm = tonumber(out.Rpm) or tuning.IdleRpm
	local step = math.clamp(dt, 1 / 240, 0.1)
	Drivetrain.RpmRate += ((rpm - Drivetrain.LastRpm) / step - Drivetrain.RpmRate) * (1 - math.exp(-10 * step))
	if Drivetrain.RpmRate ~= Drivetrain.RpmRate then Drivetrain.RpmRate = 0 end
	Drivetrain.LastRpm = rpm
	local gear = out.Gear or 0
	local overdrive = out.Overdrive == true
	if configBool("Driving", "FeelStateEnabled", true) then
		setFeel(vehicle, "FeelIdleRpm", tuning.IdleRpm)
		setFeel(vehicle, "FeelRedlineRpm", redline)
		setFeel(vehicle, "FeelLimiterRpm", tuning.LimiterRpm)
		setFeel(vehicle, "FeelGearCount", tuning.Gears)
		setFeel(vehicle, "FeelRpm", quantise(rpm, 10))
		setFeel(vehicle, "FeelGear", gear)
		setFeel(vehicle, "FeelLoad", quantise(math.clamp(out.Load or 0, 0, 1), 0.02))
		-- Kind and strength first, so a reader that sees the new revision reads the new event.
		setFeel(vehicle, "FeelShiftKind", box.LastKind)
		setFeel(vehicle, "FeelShiftStrength", quantise(box.LastStrength, 0.05))
		setFeel(vehicle, "FeelShiftRevision", box.ShiftRevision)
		setFeel(vehicle, "FeelCut", quantise(math.clamp(out.Cut or 0, 0, 1), 0.1))
		setFeel(vehicle, "FeelLimiterRevision", box.LimiterRevision)
		setFeel(vehicle, "FeelThrustSlip", quantise(math.clamp((out.ThrustSlip or 0) / 0.5, 0, 1), 0.05))
		setFeel(vehicle, "FeelSpin", quantise(spin.L, 0.05))
		-- +1 = a clockwise (rightward) spin, -1 = anticlockwise: the sign of the steering that caused it.
		setFeel(vehicle, "FeelSpinDirection", spin.Dir == 0 and 0 or -spin.Dir)
		setFeel(vehicle, "FeelOverdrive", overdrive and 1 or 0)
	end
	local telemetry = Drivetrain.Telemetry
	telemetry.Gear = GEAR_TEXT[gear] or "N"
	telemetry.GearRevision = box.ShiftRevision
	telemetry.RpmFraction = math.clamp(rpm / redline * tuning.HudRedlineSweep, 0, 1)
	telemetry.Spin = spin.L
	telemetry.Overdrive = overdrive
	-- Shift light: 4 spin warning, 3 limiter, 2 shift (HudShiftLeadSeconds before a planned upshift at or above
	-- HudShiftMinFraction of redline), 1 warm (HudWarmBandFraction of redline below that).
	local light = 0
	if spin.Warn then
		light = 4
	elseif out.LimiterActive then
		light = 3
	elseif out.PlannedUpshift and out.PlannedUpshift >= tuning.HudShiftMinFraction then
		local lead = math.min(math.max(Drivetrain.RpmRate, 0) * tuning.HudShiftLeadSeconds, 0.15 * redline)
		if tuning.HudShiftLeadSeconds > 0 then lead = math.max(lead, 0.05 * redline) end
		local flashRpm = out.PlannedUpshift * redline - lead
		if rpm >= flashRpm then
			light = 2
		elseif rpm >= flashRpm - tuning.HudWarmBandFraction * redline then
			light = 1
		end
	end
	telemetry.ShiftLight = light
	Drivetrain.TelemetryReady = true
	if Drivetrain.Debug then
		local chassis = Drivetrain.Chassis
		setDebug(vehicle, "DynamicsDrivetrainClass", Drivetrain.Category or "")
		setDebug(vehicle, "DynamicsYawRate", quantise(chassis.YawRate, 0.01))
		setDebug(vehicle, "DynamicsYawRateCommand", quantise(chassis.YawCommand, 0.01))
		setDebug(vehicle, "DynamicsSpinYawRate", quantise(chassis.SpinYawRate, 0.01))
		setDebug(vehicle, "DynamicsSpinGraceNeedsSpeed", spin.GraceNeedsSpeed)
		setDebug(vehicle, "DynamicsThrottleDuty", quantise(tonumber(box.Duty) or 0, 0.01))
		setDebug(vehicle, "DynamicsSpin", quantise(spin.L, 0.01))
		setDebug(vehicle, "DynamicsSpinTarget", quantise(spin.Target, 0.01))
		setDebug(vehicle, "DynamicsSpinWindow", quantise(spin.Window, 0.05))
		setDebug(vehicle, "DynamicsSpinGraceSeconds", math.min(quantise(spin.GraceClock, 0.5), 60))
		setDebug(vehicle, "DynamicsSpinGraceSpeedReached", spin.GraceSpeedReached)
		setDebug(vehicle, "DynamicsPowerBrakeHeld", Drivetrain.PowerBrakeHeld)
		setDebug(vehicle, "DynamicsExtraSlip", quantise(Drivetrain.ExtraSlip, 0.01))
		setDebug(vehicle, "DynamicsLateralAccel", quantise(chassis.LateralApplied, 0.1))
		setDebug(vehicle, "DynamicsLateralCap", quantise(chassis.LateralCap, 0.1))
		setDebug(vehicle, "DynamicsSteerKeyboard", quantise(Drivetrain.SteerKeyboard, 0.01))
		setDebug(vehicle, "DynamicsShiftLight", light)
	end
end

-- Anchored frame (race countdown, teleport): no forces, gear N, neutral revs with a bouncing limiter. Accelerating is
-- not set, so no remote audio state is sent.
local function drivetrainAnchored(dt, throttle)
	if not Drivetrain.WasAnchored then
		Drivetrain.WasAnchored = true
		VehicleDynamicsModel.ResetGearbox(Drivetrain.Gearbox, Drivetrain.Tuning, nil, 0, true)
	end
	resetDrivetrainChassis()
	publishDrivetrain(dt, VehicleDynamicsModel.StepNeutral(Drivetrain, dt, throttle))
end

local handleResetAction

function Controller.Stop()
	state.IsDriving = false
	state.SteeringProfileIntent = 1
	state.SteeringReverseAsked = false
	ContextActionService:UnbindAction("VehicleReset")
	if state.Vehicle then
		state.Vehicle:SetAttribute("DriveReady", false)
		clearFeelState(state.Vehicle)
		state.Vehicle:SetAttribute("Accelerating", false)
		state.Vehicle:SetAttribute("Boosting", false)
		state.Vehicle:SetAttribute("DriftingLeft", false)
		state.Vehicle:SetAttribute("DriftingRight", false)
	end
	if state.Connection then state.Connection:Disconnect(); state.Connection = nil end
	if state.Controls and state.Controls.Root then cleanupDriveForces(state.Controls.Root) end
	stopCameraAssist()
	if state.Context and typeof(state.Context.SetMobileDriving) == "function" then
		pcall(state.Context.SetMobileDriving, false)
	end
	-- Drivetrain session state (its Feel attributes were cleared with the rest above).
	Drivetrain.Active, Drivetrain.Tuning, Drivetrain.Profile, Drivetrain.Category = false, nil, nil, nil
	Drivetrain.WasAnchored, Drivetrain.ResetPending, Drivetrain.TelemetryReady, Drivetrain.DriveReady = false, false, false, false
	Drivetrain.GateLocked, Drivetrain.AnalogInput = false, false
	table.clear(Drivetrain.FeelCache)
	table.clear(Drivetrain.DebugCache)
	resetDrivetrainChassis()
	state.Controls = nil
	state.Vehicle = nil
	setJumpLocked(false)
end

function Controller.Start(context)
	Controller.Stop()
	state.Context = context or {}
	state.Vehicle = waitForPlayerVehicle(6)
	if not state.Vehicle or not state.Vehicle.PrimaryPart then
		warn("[DrivingClient] V47 driving could not find the spawned vehicle.")
		return false
	end

	state.IsDriving = true
	state.Vehicle:SetAttribute("DriveReady", true)
	state.Vehicle:SetAttribute("Accelerating", false)
	state.Vehicle:SetAttribute("Boosting", false)
	state.Vehicle:SetAttribute("DriftingLeft", false)
	state.Vehicle:SetAttribute("DriftingRight", false)
	setJumpLocked(true)
	showExistingDriveUi()
	state.Boost = 100
	state.DriftCharge = 0
	state.DriftBlend = 0
	state.MiniBoostTimer = 0
	state.MiniBoostPower = 0
	state.BoostRechargeDelayTimer = 0
	state.ReverseHoldTimer = 0
	state.CurrentBank = 0
	state.SteeringProfileIntent = 1
	state.WobbleTime = 0
	state.WobblePitch = 0
	state.WobbleRoll = 0
	state.WobbleSeedX = math.random() * 1000
	state.WobbleSeedZ = math.random() * 1000
	state.WobbleSeedY = math.random() * 1000
	state.WobbleYaw = 0
	state.WobbleBob = 0
	state.PoseSettle = nil
	state.PoseSettleVelocity = 0
	state.PoseLift = 0
	state.PoseLiftVelocity = 0
	state.PoseLean = 0
	state.PosePitch = 0
	state.PoseRideHeight = HOVER_HEIGHT
	state.PoseRollTerm = 0
	state.PosePitchTerm = 0
	state.PoseConfigTimer = 0
	measureHoverBody(state.Vehicle)
	state.AccelCameraActive = false
	state.BoostCameraActive = false
	state.Feel = { ImpactRevision = 0, LandRevision = 0, LastImpact = 0, AirTime = 0, FallSpeed = 0, HoverSum = 0, BoostKind = "", Skip = true, SkipNext = false, PopRevision = 0, PopsLeft = 0, NextPop = 0, LoadTime = 0, PreviousBoostKind = "", ScrapeTimer = 0, Scrape = 0 }
	-- Drivetrain: read the class folder now (then about 4 times a second); first gear at idle, start grace begins.
	refreshDrivetrain(state.Vehicle, true)
	Drivetrain.RefreshTimer = 0.25
	if Drivetrain.Active then
		resetDrivetrainChassis()
		VehicleDynamicsModel.ResetGearbox(Drivetrain.Gearbox, Drivetrain.Tuning, nil, 0, false)
	end

	local root = state.Vehicle.PrimaryPart
	local look = root.CFrame.LookVector
	state.YawHeading = math.atan2(look.X, look.Z)
	state.Controls = setupControls(state.Vehicle)
	if not state.Controls then
		Controller.Stop()
		return false
	end
	refreshBoostRechargeDelay()

	state.RayParams = RaycastParams.new()
	state.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	state.RayParams.FilterDescendantsInstances = { state.Vehicle, character() }

	setVehicleCamera(state.Vehicle)
	startCameraAssist()
	ContextActionService:BindActionAtPriority("VehicleReset", handleResetAction, false, 6000, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

	state.Connection = RunService.Heartbeat:Connect(function(dt)
		if not state.Vehicle or not state.Vehicle.Parent or not state.Vehicle.PrimaryPart or not state.Controls then
			Controller.Stop()
			return
		end

		local h = humanoid()
		if h then h.Jump = false end

		Drivetrain.RefreshTimer -= dt
		if Drivetrain.RefreshTimer <= 0 then
			Drivetrain.RefreshTimer = 0.25
			refreshDrivetrain(state.Vehicle, false)
		end
		if Drivetrain.Active then Drivetrain.TelemetryReady = false end
		local throttle, steer, rawSteer = refreshInput(dt)
		state.AccelCameraActive = throttle > 0
		root = state.Vehicle.PrimaryPart
		-- A parked (anchored) assembly reports infinite AssemblyMass; forces computed from it are NaN and
		-- persist until the vehicle is unanchored again, throwing it (and the camera) to NaN. Hold zero force instead.
		local rawMass = root.AssemblyMass
		if root.Anchored or rawMass ~= rawMass or rawMass == math.huge then
			if state.Controls.DriveForce then state.Controls.DriveForce.Force = Vector3.zero end
			for _, corner in ipairs(state.Controls.Corners) do corner.Force.Force = Vector3.zero end
			state.Feel.Skip = true
			state.Feel.PreviousVelocity = nil
			state.PoseSettle = nil
			state.PoseSettleVelocity = 0
			state.PoseLift = 0
			state.PoseLiftVelocity = 0
			state.PoseLean = state.CurrentBank + state.WobbleRoll
			if state.Vehicle:GetAttribute("FeelSpeedMph") ~= nil then
				state.Vehicle:SetAttribute("FeelSpeedMph", 0)
				state.Vehicle:SetAttribute("FeelThrottle", 0)
				state.Vehicle:SetAttribute("FeelBoostKind", "")
			end
			if Drivetrain.Active then
				drivetrainAnchored(dt, throttle)
			end
			updateExistingDriveUi(0)
			return
		end
		local mass = math.max(rawMass, 1)
		local velocity = root.AssemblyLinearVelocity
		local forward = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		local speedMph = velocity.Magnitude * MPH_PER_STUD
		local forwardSpeed = velocity:Dot(forward)
		local sideSpeed = velocity:Dot(right)
		local legacyDynamicsStats = {
			TopSpeed = stat("TopSpeed", 126),
			EngineOutput = stat("Acceleration", 42),
			Weight = stat("Weight", 118),
			SteeringResponse = stat("SteeringResponse", stat("Handling", 48)),
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
		}
		local dynamicsStats = VehicleDynamicsModel.ResolveStats(state.Vehicle, legacyDynamicsStats)
		local absoluteTopSpeedSafetyMph = configNumber("Dynamics", "AbsoluteTopSpeedSafetyMph", 320, 80, 500)
		-- Performance balance: multipliers from PerformanceIndex (1 = unchanged). VehicleDynamics applies the
		-- acceleration, braking, drag, grip and drift ones itself; the rest are applied below.
		local balance = VehicleDynamicsModel.Balance(state.Vehicle)
		local maxMph = math.clamp(dynamicsStats.TopSpeed * balance.TopSpeed, 40, absoluteTopSpeedSafetyMph)
		-- Drivetrain: this car's cached profile (rebuilt only when tuning, PI, stats or Balance change).
		local driveActive = false
		if Drivetrain.Active then
			Drivetrain.Profile = VehicleDynamicsModel.DrivetrainProfile(state.Vehicle, dynamicsStats, balance, maxMph, false)
			driveActive = Drivetrain.Profile ~= nil and Drivetrain.Profile.Tuning == Drivetrain.Tuning
			if driveActive then drivetrainResume(throttle, forwardSpeed * MPH_PER_STUD) end
		end
		local acceleration = math.max(legacyDynamicsStats.EngineOutput, 8)
		local braking = math.max(legacyDynamicsStats.BrakingForce, 16)
		local handling = math.max(dynamicsStats.SteeringResponse, 10)
		local driftControl = math.max(dynamicsStats.DriftControl, 10)
		local boostPower = math.max(dynamicsStats.BoostForce, 0)
		local boostDuration = math.max(dynamicsStats.BoostDuration, 1)
		local boostRecharge = math.max(dynamicsStats.BoostRecharge, 0.5)
		local weight = math.clamp(dynamicsStats.Weight, 60, 260)
		-- Use the bounded V2 delay resolved by VehicleDynamicsModel instead of the raw tier value cached at spawn.
		state.BoostRechargeDelaySeconds = math.clamp(dynamicsStats.BoostRechargeDelay, 0, 5)
		local weightFactor = math.clamp(118 / weight, 0.58, 1.25)
		acceleration *= weightFactor
		local steeringWeightExponent = configNumber("Dynamics", "SteeringWeightInfluenceExponent", 0.12, 0, 1)
		local steeringWeightFactor = math.clamp((118 / math.max(weight, 1)) ^ steeringWeightExponent,
			configNumber("Dynamics", "SteeringWeightMinMultiplier", 0.88, 0.5, 1.5),
			configNumber("Dynamics", "SteeringWeightMaxMultiplier", 1.12, 0.5, 1.5))
		handling *= steeringWeightFactor
		driftControl *= steeringWeightFactor
		braking *= math.clamp(115 / weight, 0.68, 1.15)
		acceleration *= balance.Acceleration
		braking *= balance.Reverse

		local maxForwardStuds = maxMph / MPH_PER_STUD
		local reverseMaxMph = configNumber("Driving", "ReverseMaxMph", REVERSE_MAX_MPH, 5, 80)
		local maxReverseStuds = reverseMaxMph / MPH_PER_STUD
		local hitPositions = {}
		local normalSum = Vector3.zero
		local hits = 0
		local liftPerCorner = mass * Workspace.Gravity / 4
		local hoverResults = {}

		for index, corner in ipairs(state.Controls.Corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), state.RayParams)
			hoverResults[index] = result
			if result then
				hitPositions[index] = result.Position
				normalSum += result.Normal
				hits += 1
			end
		end

		local terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local grounded = hits >= 2
		local slopeHoverEnabled = configBool("Driving", "SlopeHoverCompensationEnabled", true)
		local tangentVelocity = velocity - groundNormal * velocity:Dot(groundNormal)
		local expectedSlopeYVelocity = slopeHoverEnabled and tangentVelocity.Y or 0
		local velocityCompensation = configNumber("Driving", "SlopeHoverVelocityCompensation", 1.0, 0, 1.5)
		local heightStiffness = configNumber("Driving", "SlopeHoverHeightStiffness", 54, 8, 140)
		local normalVelocityDamping = configNumber("Driving", "SlopeHoverNormalVelocityDamping", 7, 0, 30)
		local maxLiftMultiplier = configNumber("Driving", "SlopeHoverMaxLiftMultiplier", 4.5, 1, 10)
		local missLiftMultiplier = configNumber("Driving", "SlopeHoverMissLiftMultiplier", 0.05, 0, 1)
		local forceAlongGroundNormal = configBool("Driving", "SlopeHoverForceAlongGroundNormal", false)
		local lastRelativeYVelocity = 0
		state.Feel.HoverSum = 0
		state.Feel.SkipNext = false
		state.Feel.BoostKind = ""

		updateHoverPose(dt, speedMph, forwardSpeed, throttle, hoverResults)
		for index, corner in ipairs(state.Controls.Corners) do
			local result = hoverResults[index]
			if result then
				local targetDistance = state.PoseRideHeight + SENSOR_START_HEIGHT + corner.Offset.X * state.PoseRollTerm - corner.Offset.Z * state.PosePitchTerm
				local heightError = targetDistance - result.Distance
				state.Feel.HoverSum += heightError
				local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
				local pointVelocityY = root:GetVelocityAtPosition(origin).Y
				local relativeYVelocity = pointVelocityY - expectedSlopeYVelocity * velocityCompensation
				lastRelativeYVelocity = relativeYVelocity
				local forceAmount = liftPerCorner + mass * (heightError * heightStiffness - relativeYVelocity * normalVelocityDamping)
				forceAmount = math.clamp(forceAmount, 0, liftPerCorner * maxLiftMultiplier)
				if forceAlongGroundNormal and groundNormal.Y > 0.15 then
					corner.Force.Force = groundNormal * (forceAmount / math.max(groundNormal.Y, 0.25))
				else
					corner.Force.Force = Vector3.new(0, forceAmount, 0)
				end
			else
				corner.Force.Force = Vector3.new(0, liftPerCorner * missLiftMultiplier, 0)
			end
		end

		if configBool("Driving", "SlopeHoverDebugAttributes", true) then
			state.Vehicle:SetAttribute("SlopeHoverExpectedYVelocity", expectedSlopeYVelocity)
			state.Vehicle:SetAttribute("SlopeHoverRelativeYVelocity", lastRelativeYVelocity)
			state.Vehicle:SetAttribute("SlopeHoverGroundNormalY", groundNormal.Y)
			state.Vehicle:SetAttribute("SlopeHoverTerrainForwardY", terrainForward.Y)
			state.Vehicle:SetAttribute("SlopeHoverHits", hits)
		end
		local steeringIntentDeadzone = configNumber("Driving", "SteeringIntentThrottleDeadzone", 0.05, 0, 0.5)
		local canDrift = state.DriftHeld and forwardSpeed > 8 and speedMph > 10 and math.abs(steer) > 0 and grounded
		local targetDriftBlend = canDrift and 1 or 0
		state.DriftBlend += (targetDriftBlend - state.DriftBlend) * math.clamp(dt * 5.2, 0, 1)
		local drifting = state.DriftBlend > 0.12
		local driveForce = Vector3.zero
		if driveActive then
			drivetrainGestures(dt, throttle, rawSteer, speedMph)
			Drivetrain.SpinAmount = Drivetrain.Spin.L
			Drivetrain.DriftBlend = state.DriftBlend
			Drivetrain.HorizontalSpeed = tangentVelocity.Magnitude
			Drivetrain.SteeringIntent = state.SteeringProfileIntent
		end
		local dynamicsStep = VehicleDynamicsModel.StepLongitudinal({
			Vehicle = state.Vehicle,
			DeltaTime = dt,
			Throttle = throttle,
			ForwardSpeed = forwardSpeed,
			MaxMph = maxMph,
			ReverseMaxMph = reverseMaxMph,
			Stats = dynamicsStats,
			ReverseHoldTimer = state.ReverseHoldTimer or 0,
			Drivetrain = driveActive and Drivetrain or nil,
		})
		if driveActive and dynamicsStep.Drivetrain ~= true then driveActive = false end -- Dynamics switched off

		if dynamicsStep.Enabled then
			state.ReverseHoldTimer = dynamicsStep.ReverseHoldTimer
			driveForce += forward * mass * dynamicsStep.LongitudinalAcceleration
			state.Vehicle:SetAttribute("Accelerating", dynamicsStep.Accelerating)
			state.Vehicle:SetAttribute("Braking", dynamicsStep.Braking)
			if dynamicsStep.SnapForwardStop then
				root.AssemblyLinearVelocity = velocity - forward * forwardSpeed
				state.Feel.SkipNext = true
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
				state.Feel.SkipNext = true
				driveForce += forward * mass * (math.abs(forwardSpeed) - maxReverseStuds) * 12
			end
			state.Vehicle:SetAttribute("Braking", false)
		end
		local steeringCoastDirectionMph = configNumber("Driving", "SteeringCoastDirectionMph", 0.5, 0.05, 5)
		local steeringSignedMph = forwardSpeed * MPH_PER_STUD
		if throttle > steeringIntentDeadzone then
			-- Three-point-turn exception: forward input owns yaw immediately,
			-- even while the vehicle still has backward velocity.
			state.SteeringProfileIntent = 1
			state.SteeringReverseAsked = false
		elseif throttle < -steeringIntentDeadzone then
			-- Preserve original forward handling throughout real forward braking.
			if (dynamicsStep.Enabled and dynamicsStep.Braking and forwardSpeed > 0) or steeringSignedMph > steeringCoastDirectionMph then
				state.SteeringProfileIntent = 1
			else
				state.SteeringProfileIntent = -1
				state.SteeringReverseAsked = true
			end
		elseif configBool("Driving", "SteeringCoastAssumeForward", true) then
			-- No throttle: forwards unless the player was reversing and is still rolling back, or the car is
			-- rolling back fast enough to be a real reverse (down a slope, after a hit).
			local reverseAt = state.SteeringReverseAsked and steeringCoastDirectionMph or configNumber("Driving", "SteeringCoastReverseMph", 8, 0.05, 80)
			if steeringSignedMph < -reverseAt then
				state.SteeringProfileIntent = -1
			else
				state.SteeringProfileIntent = 1
				state.SteeringReverseAsked = false
			end
		elseif steeringSignedMph < -steeringCoastDirectionMph then
			state.SteeringProfileIntent = -1
		elseif steeringSignedMph > steeringCoastDirectionMph then
			state.SteeringProfileIntent = 1
		end
		local steeringInput = state.SteeringProfileIntent < 0 and -steer or steer
		if configBool("Driving", "InputOwnedSteeringDebugAttributes", true) then
			state.Vehicle:SetAttribute("SteeringDriveMode", state.SteeringProfileIntent < 0 and "Reverse" or "Forward")
			state.Vehicle:SetAttribute("SteeringSignedMph", steeringSignedMph)
			state.Vehicle:SetAttribute("SteeringDynamicsMode", tostring(dynamicsStep.Mode or "Fallback"))
		end
		local handlingStep = typeof(VehicleDynamicsModel.StepHandling) == "function" and VehicleDynamicsModel.StepHandling({
			Vehicle = state.Vehicle,
			Stats = dynamicsStats,
			SpeedMph = speedMph,
			DriftBlend = state.DriftBlend,
		}) or { Enabled = false }
		local lateralGrip = handlingStep.Enabled and handlingStep.LateralGrip or (6.6 + (1.05 - 6.6) * state.DriftBlend)
		if driveActive then
			driveForce += right * mass * drivetrainLateral(dt, sideSpeed, handlingStep, lateralGrip, tangentVelocity.Magnitude, balance)
		else
			driveForce += -right * sideSpeed * mass * lateralGrip
		end
		if not dynamicsStep.Enabled then
			driveForce += -velocity * mass * (0.16 + 0.10 * state.DriftBlend)
		end
		local driftForwardDragBase = configNumber("Dynamics", "DriftForwardDragBase", 0.10, 0, 2)
		local driftForwardDragBlendExtra = configNumber("Dynamics", "DriftForwardDragBlendExtra", 0.06, 0, 2)
		local driftForwardDragCoefficient = 0
		if drifting then
			driftForwardDragCoefficient = (driftForwardDragBase + driftForwardDragBlendExtra * state.DriftBlend) * state.DriftBlend
			local forwardDriftSlow = math.max(forwardSpeed, 0) * mass * driftForwardDragCoefficient
			driveForce -= forward * forwardDriftSlow
			local driftSideForce = handlingStep.Enabled and handlingStep.DriftSideForce or 26
			local driftChargeMultiplier = handlingStep.Enabled and handlingStep.DriftChargeMultiplier or 1
			driveForce += right * (-steeringInput) * mass * driftSideForce * state.DriftBlend

			local driftThrottleMinimum = configNumber("Dynamics", "DriftThrottleMinimum", 0.05, 0, 1)
			local driftThrottleAlpha = math.clamp((throttle - driftThrottleMinimum) / math.max(1 - driftThrottleMinimum, 0.001), 0, 1)
			if driftThrottleAlpha > 0 then
				local engineAssist = handlingStep.Enabled and handlingStep.DriftEngineAssist or 0.20
				if driveActive then
					-- Drivetrain: the assist follows the engine's thrust, mostly its first-gear plateau (A1 x throttle, by
					-- DriftAssistPlateauShare), so a drift held in a high gear keeps today's push. Gated on DriveThrust > 0
					-- before the blend, as before: a frame with no drive thrust (a full limiter cut) adds no assist.
					if dynamicsStep.DriveThrust > 0 then
						local assistThrust = dynamicsStep.DriveThrust
						assistThrust += (Drivetrain.Profile.A1 * math.clamp(throttle, 0, 1) - assistThrust) * Drivetrain.Tuning.DriftAssistPlateauShare
						driveForce += forward * mass * assistThrust * engineAssist * state.DriftBlend * driftThrottleAlpha
					end
				elseif dynamicsStep.Enabled and dynamicsStep.LongitudinalAcceleration > 0 then
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
		elseif not state.DriftHeld and state.DriftCharge > 0 then
			local requiresAcceleration = configBool("Driving", "DriftMiniBoostRequiresAcceleration", true)
			local accelerationThreshold = configNumber("Driving", "DriftMiniBoostAccelerationThreshold", 0.05, 0, 1)
			local acceleratingOnDriftExit = throttle > accelerationThreshold
			local statScalingEnabled = configNumber("Dynamics", "DriftMiniBoostStatScalingEnabled", 1, 0, 1) >= 0.5
			local minimumCharge = configNumber("Dynamics", "DriftMiniBoostMinimumCharge", 0.72, 0, 10)
			if state.DriftCharge > minimumCharge and (not requiresAcceleration or acceleratingOnDriftExit) then
				local charge = state.DriftCharge
				if statScalingEnabled then
					local fullRewardCharge = math.max(configNumber("Dynamics", "DriftMiniBoostChargeForFullReward", 3.25, 0.01, 10), minimumCharge + 0.01)
					local rewardExponent = configNumber("Dynamics", "DriftMiniBoostRewardExponent", 0.85, 0.05, 4)
					local chargeQuality = math.clamp((charge - minimumCharge) / (fullRewardCharge - minimumCharge), 0, 1) ^ rewardExponent

					local baseMinDuration = configNumber("Dynamics", "DriftMiniBoostBaseMinDurationSeconds", 0.18, 0.01, 3)
					local baseMaxDuration = configNumber("Dynamics", "DriftMiniBoostBaseMaxDurationSeconds", 0.70, 0.01, 3)
					if baseMaxDuration < baseMinDuration then baseMinDuration, baseMaxDuration = baseMaxDuration, baseMinDuration end
					local durationReference = configNumber("Dynamics", "DriftMiniBoostBoostDurationReferenceSeconds", 3.0, 0.1, 12)
					local durationExponent = configNumber("Dynamics", "DriftMiniBoostBoostDurationExponent", 0.50, 0.05, 2)
					local durationMinMultiplier = configNumber("Dynamics", "DriftMiniBoostBoostDurationMinMultiplier", 0.80, 0.05, 3)
					local durationMaxMultiplier = configNumber("Dynamics", "DriftMiniBoostBoostDurationMaxMultiplier", 1.20, 0.05, 3)
					if durationMaxMultiplier < durationMinMultiplier then durationMinMultiplier, durationMaxMultiplier = durationMaxMultiplier, durationMinMultiplier end
					local durationMultiplier = math.clamp((math.max(dynamicsStats.BoostDuration or durationReference, 0.01) / durationReference) ^ durationExponent, durationMinMultiplier, durationMaxMultiplier)
					local absoluteMinDuration = configNumber("Dynamics", "DriftMiniBoostAbsoluteMinDurationSeconds", 0.12, 0.01, 3)
					local absoluteMaxDuration = configNumber("Dynamics", "DriftMiniBoostAbsoluteMaxDurationSeconds", 0.90, 0.01, 3)
					if absoluteMaxDuration < absoluteMinDuration then absoluteMinDuration, absoluteMaxDuration = absoluteMaxDuration, absoluteMinDuration end
					local baseDuration = baseMinDuration + (baseMaxDuration - baseMinDuration) * chargeQuality
					state.MiniBoostTimer = math.clamp(baseDuration * durationMultiplier, absoluteMinDuration, absoluteMaxDuration)

					local minAcceleration = configNumber("Dynamics", "DriftMiniBoostMinAcceleration", 32, 0, 300)
					local maxAcceleration = configNumber("Dynamics", "DriftMiniBoostMaxAcceleration", 72, 0, 300)
					if maxAcceleration < minAcceleration then minAcceleration, maxAcceleration = maxAcceleration, minAcceleration end
					local boostForceReference = configNumber("Dynamics", "DriftMiniBoostBoostForceReference", 30, 0.1, 300)
					local boostForceExponent = configNumber("Dynamics", "DriftMiniBoostBoostForceExponent", 0.55, 0.05, 2)
					local boostForceMinMultiplier = configNumber("Dynamics", "DriftMiniBoostBoostForceMinMultiplier", 0.65, 0.05, 3)
					local boostForceMaxMultiplier = configNumber("Dynamics", "DriftMiniBoostBoostForceMaxMultiplier", 1.25, 0.05, 3)
					if boostForceMaxMultiplier < boostForceMinMultiplier then boostForceMinMultiplier, boostForceMaxMultiplier = boostForceMaxMultiplier, boostForceMinMultiplier end
					local boostForceMultiplier = math.clamp((math.max(dynamicsStats.BoostForce or 0, 0.01) / boostForceReference) ^ boostForceExponent, boostForceMinMultiplier, boostForceMaxMultiplier)
					state.MiniBoostPower = (minAcceleration + (maxAcceleration - minAcceleration) * chargeQuality) * boostForceMultiplier

					if configBool("Driving", "DriftMiniBoostDebugAttributes", true) then
						state.Vehicle:SetAttribute("DriftMiniBoostChargeQuality", chargeQuality)
						state.Vehicle:SetAttribute("DriftMiniBoostDurationMultiplier", durationMultiplier)
						state.Vehicle:SetAttribute("DriftMiniBoostForceMultiplier", boostForceMultiplier)
						state.Vehicle:SetAttribute("DriftMiniBoostDurationSeconds", state.MiniBoostTimer)
						state.Vehicle:SetAttribute("DriftMiniBoostAcceleration", state.MiniBoostPower)
					end
				else
					state.MiniBoostTimer = math.clamp(0.22 + charge * 0.48, 0.35, 1.85)
					state.MiniBoostPower = math.clamp(48 + charge * 27, 58, 136)
				end
			end
			if configBool("Driving", "DriftMiniBoostDebugAttributes", true) then
				state.Vehicle:SetAttribute("DriftMiniBoostAcceleratingOnExit", acceleratingOnDriftExit)
				state.Vehicle:SetAttribute("DriftMiniBoostRequiresAcceleration", requiresAcceleration)
			end
			state.DriftCharge = 0
		end

		local boostHeld = not GameplayInputGate.IsLocked() and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) or state.GamepadBoostHeld)
		local miniBoostActive = state.MiniBoostTimer > 0
		local expiresDuringNormalBoost = configNumber("Dynamics", "DriftMiniBoostExpiresDuringNormalBoost", 1, 0, 1) >= 0.5
		if miniBoostActive and expiresDuringNormalBoost then
			state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt)
		end
		if boostHeld and state.Boost > 1 and forwardSpeed > -4 and boostPower > 0 then
			state.Boost = math.max(0, state.Boost - (100 / boostDuration) * dt)
			state.BoostRechargeDelayTimer = state.BoostRechargeDelaySeconds
			if driveActive then
				-- Drivetrain: boost fades with speed (BoostShare) so the boosted top speed stays today's.
				Drivetrain.BoostAccel = (boostPower + 32) * 0.75 * balance.Boost * dynamicsStep.BoostShare
				Drivetrain.BoostApplied = true
				driveForce += forward * mass * Drivetrain.BoostAccel
			else
				driveForce += forward * mass * (boostPower + 32) * 0.75 * balance.Boost
			end
			state.Vehicle:SetAttribute("Boosting", true)
			state.Feel.BoostKind = "Boost"
			state.BoostCameraActive = true
		elseif miniBoostActive then
			if not expiresDuringNormalBoost then state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt) end
			local forceMultiplier = configNumber("Dynamics", "DriftMiniBoostForceApplicationMultiplier", 0.85, 0, 3)
			if driveActive then
				Drivetrain.BoostAccel = state.MiniBoostPower * forceMultiplier * balance.MiniBoost * dynamicsStep.BoostShare
				Drivetrain.BoostApplied = true
				driveForce += forward * mass * Drivetrain.BoostAccel
			else
				driveForce += forward * mass * state.MiniBoostPower * forceMultiplier * balance.MiniBoost
			end
			state.Vehicle:SetAttribute("Boosting", true)
			state.Feel.BoostKind = "Mini"
			state.BoostCameraActive = true
		else
			if boostHeld and boostPower > 0 then
				state.BoostRechargeDelayTimer = state.BoostRechargeDelaySeconds
			elseif state.BoostRechargeDelayTimer > 0 then
				state.BoostRechargeDelayTimer = math.max(0, state.BoostRechargeDelayTimer - dt)
			else
				state.Boost = math.min(100, state.Boost + (100 / boostRecharge) * dt)
			end
			state.MiniBoostPower = 0
			state.Vehicle:SetAttribute("Boosting", false)
			state.BoostCameraActive = false
			if driveActive then Drivetrain.BoostAccel, Drivetrain.BoostApplied = 0, false end
		end

		state.Vehicle:SetAttribute("DriftingLeft", drifting and steeringInput < -0.05)
		state.Vehicle:SetAttribute("DriftingRight", drifting and steeringInput > 0.05)
		state.Controls.DriveForce.Force = driveForce
		local speedFactor = math.clamp(math.abs(forwardSpeed) * MPH_PER_STUD / 45, 0.35, 1.35)
		local turnRate = (handling / 58) * 1.08 * speedFactor * balance.Steering
		local speedSteeringMultiplier = 1
		if configBool("Driving", "SpeedSteeringEnabled", true) then
			local lowSpeedMph = configNumber("Driving", "SpeedSteeringLowSpeedMph", 0, 0, 260)
			local highSpeedMph = configNumber("Driving", "SpeedSteeringHighSpeedMph", 115, 1, 320)
			if highSpeedMph <= lowSpeedMph + 1 then
				highSpeedMph = lowSpeedMph + 1
			end

			local lowMultiplier = configNumber("Driving", "SpeedSteeringLowMultiplier", 1.45, 0.1, 4)
			local highMultiplier = configNumber("Driving", "SpeedSteeringHighMultiplier", 0.72, 0.1, 4)
			local curveExponent = configNumber("Driving", "SpeedSteeringCurveExponent", 1.85, 0.1, 8)
			local reverseMultiplier = configNumber("Driving", "ReverseSteeringMultiplier", 1.18, 0.1, 4)
			local reverseUsesCurve = configBool("Driving", "ReverseSteeringUsesSpeedCurve", true)

			local speedAlpha = math.clamp((speedMph - lowSpeedMph) / (highSpeedMph - lowSpeedMph), 0, 1)
			local lowSpeedInfluence = (1 - speedAlpha) ^ curveExponent
			local targetMultiplier = highMultiplier + (lowMultiplier - highMultiplier) * lowSpeedInfluence

			if state.SteeringProfileIntent < 0 then 
				if reverseUsesCurve then
					targetMultiplier *= reverseMultiplier
				else
					targetMultiplier = reverseMultiplier
				end
			end

			if drifting then
				local driftMinimum = configNumber("Driving", "SpeedSteeringDriftMinimumMultiplier", 0.92, 0.1, 4)
				targetMultiplier = math.max(targetMultiplier, driftMinimum)
			end

			local smoothing = configNumber("Driving", "SpeedSteeringSmoothing", 7, 0, 30)
			if smoothing > 0 then
				local previous = state.SpeedSteeringMultiplier or targetMultiplier
				local alpha = math.clamp(dt * smoothing, 0, 1)
				speedSteeringMultiplier = previous + (targetMultiplier - previous) * alpha
			else
				speedSteeringMultiplier = targetMultiplier
			end
			state.SpeedSteeringMultiplier = speedSteeringMultiplier

			if configBool("Driving", "SpeedSteeringDebugAttributes", true) then
				state.Vehicle:SetAttribute("SpeedSteeringMultiplier", speedSteeringMultiplier)
				state.Vehicle:SetAttribute("SpeedSteeringSpeedMph", speedMph)
			end
		else
			state.SpeedSteeringMultiplier = 1
		end
		local boostSteeringMultiplier = 1
		if state.Vehicle:GetAttribute("Boosting") == true then
			boostSteeringMultiplier = configNumber("Driving", "BoostSteeringMultiplier", 0.8, 0.1, 4)
			speedSteeringMultiplier *= boostSteeringMultiplier
		end
		if configBool("Driving", "SpeedSteeringDebugAttributes", true) then
			state.Vehicle:SetAttribute("SpeedSteeringMultiplier", speedSteeringMultiplier)
			state.Vehicle:SetAttribute("SpeedSteeringSpeedMph", speedMph)
			state.Vehicle:SetAttribute("BoostSteeringMultiplier", boostSteeringMultiplier)
		end
		turnRate *= speedSteeringMultiplier
		if drifting then
			local driftTurnMultiplier = handlingStep.Enabled and handlingStep.DriftTurnMultiplier or 1
			turnRate *= (1.34 + (driftControl / 170)) * driftTurnMultiplier
		end
		if driveActive then
			-- Drivetrain weight: the heading turns at a yaw rate with inertia (and the spin), not directly.
			state.YawHeading += drivetrainYaw(dt, -steeringInput * turnRate, throttle, steer, rawSteer, speedMph, forwardSpeed, dynamicsStep.WheelspinExcess or 0) * dt
		else
			state.YawHeading += -steeringInput * turnRate * dt
		end
		local turningBankDegrees = configNumber("Driving", "TurningBankDegrees", 12, 0, 30)
		local driftExtraBankDegrees = configNumber("Driving", "DriftExtraBankDegrees", 5, 0, 20)
		local bankInput = steer
		if driveActive then bankInput = rawSteer end -- DRIVE-01: the bank stays on the raw input
		local targetBankDegrees = math.clamp(-bankInput * turningBankDegrees, -turningBankDegrees, turningBankDegrees)
		if drifting then
			targetBankDegrees += math.clamp(-bankInput * driftExtraBankDegrees, -driftExtraBankDegrees, driftExtraBankDegrees) * state.DriftBlend
		end
		local targetBank = math.rad(targetBankDegrees)
		local bankResponse = configNumber("Driving", "TurningBankResponse", 2.2, 0.1, 30)
		local bankAlpha = 1 - math.exp(-bankResponse * math.max(dt, 0))
		state.CurrentBank += (targetBank - state.CurrentBank) * bankAlpha

		if configBool("Driving", "InputOwnedSteeringDebugAttributes", true) then
			state.Vehicle:SetAttribute("InputOwnedSteeringValue", steer)
			state.Vehicle:SetAttribute("SteeringProfileIntent", state.SteeringProfileIntent < 0 and "Reverse" or "Forward")
			state.Vehicle:SetAttribute("TurningBankTargetDegrees", targetBankDegrees)
			state.Vehicle:SetAttribute("TurningBankCurrentDegrees", math.deg(state.CurrentBank))
		end
		terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local wobblePitch, wobbleRoll = updateHoverWobble(dt, speedMph, grounded)
		local accelBrakePitch = 0
		if driveActive and Drivetrain.Tuning.FeelWeight > 0 and configBool("Driving", "AccelBrakeTiltEnabled", true) then
			accelBrakePitch = drivetrainPitch(dt, dynamicsStep.LongitudinalAcceleration)
		elseif configBool("Driving", "AccelBrakeTiltEnabled", true) then
			local throttleDeadzone = configNumber("Driving", "AccelBrakeTiltThrottleDeadzone", 0.05, 0, 0.5)
			local brakeForwardSpeedMph = configNumber("Driving", "BrakeTiltForwardSpeedMph", 4, 0, 80)
			local targetPitchDegrees = 0

			if throttle > throttleDeadzone then
				targetPitchDegrees = configNumber("Driving", "AccelerationTiltDegrees", 2.5, -12, 12) * math.clamp(throttle, 0, 1)
			elseif throttle < -throttleDeadzone then
				if forwardSpeed * MPH_PER_STUD > brakeForwardSpeedMph then
					targetPitchDegrees = configNumber("Driving", "BrakeTiltDegrees", -3.5, -12, 12) * math.clamp(math.abs(throttle), 0, 1)
				else
					targetPitchDegrees = configNumber("Driving", "ReverseAccelerationTiltDegrees", -1.5, -12, 12) * math.clamp(math.abs(throttle), 0, 1)
				end
			end

			if state.Vehicle:GetAttribute("Boosting") == true then
				targetPitchDegrees += configNumber("Driving", "BoostExtraTiltDegrees", 1.0, -12, 12)
			end

			local maxTiltDegrees = configNumber("Driving", "AccelBrakeTiltMaxDegrees", 5, 0, 16)
			targetPitchDegrees = math.clamp(targetPitchDegrees, -maxTiltDegrees, maxTiltDegrees)

			local smoothing = configNumber("Driving", "AccelBrakeTiltSmoothing", 7, 0, 30)
			if smoothing > 0 then
				local previous = state.AccelBrakePitchDegrees or targetPitchDegrees
				local alpha = math.clamp(dt * smoothing, 0, 1)
				state.AccelBrakePitchDegrees = previous + (targetPitchDegrees - previous) * alpha
			else
				state.AccelBrakePitchDegrees = targetPitchDegrees
			end

			accelBrakePitch = math.rad(state.AccelBrakePitchDegrees or 0)
			if configBool("Driving", "AccelBrakeTiltDebugAttributes", true) then
				state.Vehicle:SetAttribute("AccelBrakePitchDegrees", state.AccelBrakePitchDegrees or 0)
			end
		else
			state.AccelBrakePitchDegrees = 0
		end
		if handlingStep.Enabled then
			state.Controls.Align.Responsiveness = handlingStep.AlignResponsiveness
		else
			state.Controls.Align.Responsiveness = 22
		end
		state.PosePitch = wobblePitch + accelBrakePitch
		if driveActive then
			state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch + accelBrakePitch, state.WobbleYaw, state.CurrentBank + wobbleRoll + drivetrainRoll(dt))
		else
			state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch + accelBrakePitch, state.WobbleYaw, state.CurrentBank + wobbleRoll)
		end
		setVehicleCamera(state.Vehicle)

		if root.Position.Y < -50 then
			root.CFrame = CFrame.new(860, 106, -1713)
			state.Feel.SkipNext = true
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end

		if configBool("Driving", "FeelStateEnabled", true) then
			publishFeelState(dt, state.Vehicle, throttle, velocity, speedMph, sideSpeed, grounded, hits, driveForce, mass)
		else
			state.Feel.Skip = true
			state.Feel.PreviousVelocity = nil
		end
		if driveActive then publishDrivetrain(dt, dynamicsStep) end
		updateExistingDriveUi(speedMph)
	end)

	return true
end

function Controller.ResetVehicle()
	if state.Vehicle and state.Vehicle.PrimaryPart then
		local root = state.Vehicle.PrimaryPart
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		state.SteeringProfileIntent = 1
		state.SteeringReverseAsked = false
		state.CurrentBank = 0
		state.PoseLean = state.WobbleRoll
		state.PoseLiftVelocity = 0
		if state.Feel then state.Feel.Skip = true end
		if Drivetrain.Active then
			-- Drivetrain: no leftover yaw rate or spin after a reset; gearbox back to first at idle next frame.
			resetDrivetrainChassis()
			Drivetrain.ResetPending = true
		end
		root.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 5, 0), root.Position + Vector3.new(math.sin(state.YawHeading), 5, math.cos(state.YawHeading)))
	end
end

handleResetAction = function(_, inputState)
	if inputState == Enum.UserInputState.Begin and state.IsDriving and not GameplayInputGate.IsLocked() then
		Controller.ResetVehicle()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

return Controller
