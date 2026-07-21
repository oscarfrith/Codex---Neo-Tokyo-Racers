local Controller = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- NTR_LOADING_SYSTEM_PHASE1_INPUT_GATE_V1
local GameplayInputGate = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("GameplayInputGate"))

local VehicleDynamicsModel
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

local REVERSE_MAX_MPH = 40
local HOVER_HEIGHT = 3
local SENSOR_START_HEIGHT = 2
local SENSOR_LENGTH = 24
local MPH_PER_STUD = 0.625
local CAMERA_RENDER_NAME = "HOVER_RACING_V75_CameraAssist"
local KIT_NAME = "NeoTokyoRacers"

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
	WobbleSeedX = math.random() * 1000,
	WobbleSeedZ = math.random() * 1000,
	WobbleTime = 0,
	WobblePitch = 0,
	WobbleRoll = 0,
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
		ContextActionService:BindActionAtPriority("HOVER_RACING_V2_BlockJumpWhileDriving", blockJumpAction, false, 4000, Enum.KeyCode.Space)
	else
		ContextActionService:UnbindAction("HOVER_RACING_V2_BlockJumpWhileDriving")
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
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
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
	local fallback = configNumber("DRIVING_MECHANICS_EditAttributes", "BoostRechargeDelaySeconds", 0.5, 0, 5)
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

local function refreshInput()
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
		return 0, 0
	end
	readGamepad()
	local throttle = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then throttle += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then throttle -= 1 end

	local steer = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then steer -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer += 1 end

	local mobileThrottle, mobileSteer, mobileDrift, mobileBoost = mobileInput()
	throttle = math.clamp(throttle + state.GamepadAccel - state.GamepadBrake + mobileThrottle, -1, 1)
	steer = math.clamp(steer + state.GamepadSteer + mobileSteer, -1, 1)
	state.DriftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) or gamepadDown(Enum.KeyCode.ButtonB) or mobileDrift
	state.GamepadBoostHeld = gamepadDown(Enum.KeyCode.ButtonA) or mobileBoost
	return throttle, steer
end

local function cameraConfig()
	local kit = ReplicatedStorage:FindFirstChild(KIT_NAME)
	local config = kit and kit:WaitForChild("Config"):WaitForChild("Runtime")
	return config and config:FindFirstChild("DRIVING_CAMERA_ASSIST_EditAttributes")
end

local function configFolder(name)
	local kit = ReplicatedStorage:FindFirstChild(KIT_NAME)
	local config = kit and kit:WaitForChild("Config"):WaitForChild("Runtime")
	return config and config:FindFirstChild(name)
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

-- NTR_DRIVING_FEEL_FLAT_CATEGORY_CONFIG_READER
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

-- NTR_DRIVING_CAMERA_SINGLE_OWNER_BRIDGE
local drivingCameraController
local function getDrivingCameraController()
	if drivingCameraController then return drivingCameraController end
	local moduleScript = script.Parent:FindFirstChild("DrivingCameraController")
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		warn("[NTR Driving Camera] DrivingCameraController missing; Roblox default camera remains active")
		return nil
	end
	local ok, result = pcall(require, moduleScript)
	if not ok or typeof(result) ~= "table" then
		warn("[NTR Driving Camera] DrivingCameraController failed to load: " .. tostring(result))
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
end

local function updateHoverWobble(dt, speedMph, grounded)
	local enabled = configBool("HOVER_WOBBLE_EditAttributes", "WobbleEnabled", true)
	if not enabled or not grounded then
		state.WobblePitch += (0 - state.WobblePitch) * math.clamp(dt * 6, 0, 1)
		state.WobbleRoll += (0 - state.WobbleRoll) * math.clamp(dt * 6, 0, 1)
		return state.WobblePitch, state.WobbleRoll
	end

	local fadeOutMph = configNumber("HOVER_WOBBLE_EditAttributes", "WobbleFadeOutMph", 20, 1, 80)
	local strength = 1 - math.clamp((speedMph or 0) / fadeOutMph, 0, 1)
	local amountDegrees = configNumber("HOVER_WOBBLE_EditAttributes", "WobbleAmountDegrees", 1.15, 0, 8)
	local speed = configNumber("HOVER_WOBBLE_EditAttributes", "WobbleSpeed", 1.15, 0.05, 8)
	local randomise = configNumber("HOVER_WOBBLE_EditAttributes", "WobbleRandomiseAmount", 0.65, 0, 2)
	local pitchMultiplier = configNumber("HOVER_WOBBLE_EditAttributes", "WobblePitchMultiplier", 0.75, 0, 3)
	local rollMultiplier = configNumber("HOVER_WOBBLE_EditAttributes", "WobbleRollMultiplier", 1, 0, 3)
	local smoothing = configNumber("HOVER_WOBBLE_EditAttributes", "WobbleSmoothing", 4.5, 0.25, 18)

	state.WobbleTime += dt * speed
	local t = state.WobbleTime
	local slowPitch = math.noise(state.WobbleSeedX, t, 0)
	local slowRoll = math.noise(state.WobbleSeedZ, 0, t * 1.13)
	local flutterPitch = math.sin(t * 2.7 + state.WobbleSeedX) * 0.22
	local flutterRoll = math.sin(t * 2.1 + state.WobbleSeedZ) * 0.22
	local radians = math.rad(amountDegrees) * strength
	local targetPitch = (slowPitch + flutterPitch * randomise) * radians * pitchMultiplier
	local targetRoll = (slowRoll + flutterRoll * randomise) * radians * rollMultiplier
	local alpha = math.clamp(dt * smoothing, 0, 1)
	state.WobblePitch += (targetPitch - state.WobblePitch) * alpha
	state.WobbleRoll += (targetRoll - state.WobbleRoll) * alpha
	return state.WobblePitch, state.WobbleRoll
end

-- NTR_DRIVING_CAMERA_SINGLE_OWNER_DEFAULT_GUARD
local function setVehicleCamera(vehicle)
	local cam = currentCamera()
	if not cam or cam:GetAttribute("NTRDrivingCameraManaged") == true then return end
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
	if typeof(context.UpdateDriveUi) == "function" then
		pcall(context.UpdateDriveUi, speedMph, state.Boost, state.DriftBlend > 0.12, state.DriftCharge, state.MiniBoostTimer)
	end
	if typeof(context.PublishMobile) == "function" then
		pcall(context.PublishMobile, speedMph, state.Boost)
	end
end

local handleResetAction

function Controller.Stop()
	state.IsDriving = false
	ContextActionService:UnbindAction("HOVER_RACING_V2_V47_Reset")
	if state.Vehicle then
		state.Vehicle:SetAttribute("DriveReady", false)
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
	state.Controls = nil
	state.Vehicle = nil
	setJumpLocked(false)
end

function Controller.Start(context)
	Controller.Stop()
	state.Context = context or {}
	state.Vehicle = waitForPlayerVehicle(6)
	if not state.Vehicle or not state.Vehicle.PrimaryPart then
		warn("[V75] V47 driving could not find the spawned vehicle.")
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
	state.WobbleTime = 0
	state.WobblePitch = 0
	state.WobbleRoll = 0
	state.WobbleSeedX = math.random() * 1000
	state.WobbleSeedZ = math.random() * 1000
	state.AccelCameraActive = false
	state.BoostCameraActive = false

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
	ContextActionService:BindActionAtPriority("HOVER_RACING_V2_V47_Reset", handleResetAction, false, 6000, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

	state.Connection = RunService.Heartbeat:Connect(function(dt)
		if not state.Vehicle or not state.Vehicle.Parent or not state.Vehicle.PrimaryPart or not state.Controls then
			Controller.Stop()
			return
		end

		local h = humanoid()
		if h then h.Jump = false end

		local throttle, steer = refreshInput()
		state.AccelCameraActive = throttle > 0
		root = state.Vehicle.PrimaryPart
		local mass = math.max(root.AssemblyMass, 1)
		local velocity = root.AssemblyLinearVelocity
		local forward = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		local speedMph = velocity.Magnitude * MPH_PER_STUD
		local forwardSpeed = velocity:Dot(forward)
		local sideSpeed = velocity:Dot(right)

		-- NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE
		-- NTR_DRIVING_FEEL_PHASE1_DETAILED_STATS
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
		-- NTR_DRIVING_FEEL_PHYSICAL_TOP_SPEED_CONTROLLER_LIMIT
		local absoluteTopSpeedSafetyMph = configNumber("VehicleDynamics_EditAttributes", "AbsoluteTopSpeedSafetyMph", 320, 80, 500)
		local maxMph = math.clamp(dynamicsStats.TopSpeed, 40, absoluteTopSpeedSafetyMph)
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
		-- NTR_DRIVING_FEEL_PHASE3_TIER_SAFE_WEIGHT
		local steeringWeightExponent = configNumber("VehicleDynamics_EditAttributes", "SteeringWeightInfluenceExponent", 0.12, 0, 1)
		local steeringWeightFactor = math.clamp((118 / math.max(weight, 1)) ^ steeringWeightExponent,
			configNumber("VehicleDynamics_EditAttributes", "SteeringWeightMinMultiplier", 0.88, 0.5, 1.5),
			configNumber("VehicleDynamics_EditAttributes", "SteeringWeightMaxMultiplier", 1.12, 0.5, 1.5))
		handling *= steeringWeightFactor
		driftControl *= steeringWeightFactor
		braking *= math.clamp(115 / weight, 0.68, 1.15)

		local maxForwardStuds = maxMph / MPH_PER_STUD
		-- NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_REVERSE_BEGIN
		local reverseMaxMph = configNumber("DRIVING_MECHANICS_EditAttributes", "ReverseMaxMph", REVERSE_MAX_MPH, 5, 80)
		local maxReverseStuds = reverseMaxMph / MPH_PER_STUD
		-- NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_REVERSE_END
		-- NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1_BEGIN
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
		local slopeHoverEnabled = configBool("DRIVING_MECHANICS_EditAttributes", "SlopeHoverCompensationEnabled", true)
		local tangentVelocity = velocity - groundNormal * velocity:Dot(groundNormal)
		local expectedSlopeYVelocity = slopeHoverEnabled and tangentVelocity.Y or 0
		local velocityCompensation = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverVelocityCompensation", 1.0, 0, 1.5)
		local heightStiffness = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverHeightStiffness", 54, 8, 140)
		local normalVelocityDamping = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverNormalVelocityDamping", 7, 0, 30)
		local maxLiftMultiplier = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverMaxLiftMultiplier", 4.5, 1, 10)
		local missLiftMultiplier = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverMissLiftMultiplier", 0.05, 0, 1)
		local forceAlongGroundNormal = configBool("DRIVING_MECHANICS_EditAttributes", "SlopeHoverForceAlongGroundNormal", false)
		local lastRelativeYVelocity = 0

		for index, corner in ipairs(state.Controls.Corners) do
			local result = hoverResults[index]
			if result then
				local targetDistance = HOVER_HEIGHT + SENSOR_START_HEIGHT
				local heightError = targetDistance - result.Distance
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

		if configBool("DRIVING_MECHANICS_EditAttributes", "SlopeHoverDebugAttributes", true) then
			state.Vehicle:SetAttribute("SlopeHoverExpectedYVelocity", expectedSlopeYVelocity)
			state.Vehicle:SetAttribute("SlopeHoverRelativeYVelocity", lastRelativeYVelocity)
			state.Vehicle:SetAttribute("SlopeHoverGroundNormalY", groundNormal.Y)
			state.Vehicle:SetAttribute("SlopeHoverTerrainForwardY", terrainForward.Y)
			state.Vehicle:SetAttribute("SlopeHoverHits", hits)
		end
		-- NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1_END
		local steeringInput = steer
		if forwardSpeed < -4 then steeringInput = -steer end

		local canDrift = state.DriftHeld and forwardSpeed > 8 and speedMph > 10 and math.abs(steeringInput) > 0 and grounded
		local targetDriftBlend = canDrift and 1 or 0
		state.DriftBlend += (targetDriftBlend - state.DriftBlend) * math.clamp(dt * 5.2, 0, 1)
		local drifting = state.DriftBlend > 0.12

		-- NTR_DRIVING_FEEL_PHASE1_DYNAMICS_BRIDGE
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

		-- NTR_DRIVING_FEEL_PHASE2_HANDLING_BRIDGE
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

		-- NTR_DRIVING_FEEL_PHASE2_1_DRIFT_MOMENTUM
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
		elseif not state.DriftHeld and state.DriftCharge > 0 then
			-- NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_DRIFT_BEGIN
			local requiresAcceleration = configBool("DRIVING_MECHANICS_EditAttributes", "DriftMiniBoostRequiresAcceleration", true)
			local accelerationThreshold = configNumber("DRIVING_MECHANICS_EditAttributes", "DriftMiniBoostAccelerationThreshold", 0.05, 0, 1)
			local acceleratingOnDriftExit = throttle > accelerationThreshold
			-- NTR_DRIFT_MINI_BOOST_STAT_SCALING_V1
			local statScalingEnabled = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostStatScalingEnabled", 1, 0, 1) >= 0.5
			local minimumCharge = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostMinimumCharge", 0.72, 0, 10)
			if state.DriftCharge > minimumCharge and (not requiresAcceleration or acceleratingOnDriftExit) then
				local charge = state.DriftCharge
				if statScalingEnabled then
					local fullRewardCharge = math.max(configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostChargeForFullReward", 3.25, 0.01, 10), minimumCharge + 0.01)
					local rewardExponent = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostRewardExponent", 0.85, 0.05, 4)
					local chargeQuality = math.clamp((charge - minimumCharge) / (fullRewardCharge - minimumCharge), 0, 1) ^ rewardExponent

					local baseMinDuration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBaseMinDurationSeconds", 0.18, 0.01, 3)
					local baseMaxDuration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBaseMaxDurationSeconds", 0.70, 0.01, 3)
					if baseMaxDuration < baseMinDuration then baseMinDuration, baseMaxDuration = baseMaxDuration, baseMinDuration end
					local durationReference = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostDurationReferenceSeconds", 3.0, 0.1, 12)
					local durationExponent = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostDurationExponent", 0.50, 0.05, 2)
					local durationMinMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostDurationMinMultiplier", 0.80, 0.05, 3)
					local durationMaxMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostDurationMaxMultiplier", 1.20, 0.05, 3)
					if durationMaxMultiplier < durationMinMultiplier then durationMinMultiplier, durationMaxMultiplier = durationMaxMultiplier, durationMinMultiplier end
					local durationMultiplier = math.clamp((math.max(dynamicsStats.BoostDuration or durationReference, 0.01) / durationReference) ^ durationExponent, durationMinMultiplier, durationMaxMultiplier)
					local absoluteMinDuration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostAbsoluteMinDurationSeconds", 0.12, 0.01, 3)
					local absoluteMaxDuration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostAbsoluteMaxDurationSeconds", 0.90, 0.01, 3)
					if absoluteMaxDuration < absoluteMinDuration then absoluteMinDuration, absoluteMaxDuration = absoluteMaxDuration, absoluteMinDuration end
					local baseDuration = baseMinDuration + (baseMaxDuration - baseMinDuration) * chargeQuality
					state.MiniBoostTimer = math.clamp(baseDuration * durationMultiplier, absoluteMinDuration, absoluteMaxDuration)

					local minAcceleration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostMinAcceleration", 32, 0, 300)
					local maxAcceleration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostMaxAcceleration", 72, 0, 300)
					if maxAcceleration < minAcceleration then minAcceleration, maxAcceleration = maxAcceleration, minAcceleration end
					local boostForceReference = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostForceReference", 30, 0.1, 300)
					local boostForceExponent = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostForceExponent", 0.55, 0.05, 2)
					local boostForceMinMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostForceMinMultiplier", 0.65, 0.05, 3)
					local boostForceMaxMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostForceMaxMultiplier", 1.25, 0.05, 3)
					if boostForceMaxMultiplier < boostForceMinMultiplier then boostForceMinMultiplier, boostForceMaxMultiplier = boostForceMaxMultiplier, boostForceMinMultiplier end
					local boostForceMultiplier = math.clamp((math.max(dynamicsStats.BoostForce or 0, 0.01) / boostForceReference) ^ boostForceExponent, boostForceMinMultiplier, boostForceMaxMultiplier)
					state.MiniBoostPower = (minAcceleration + (maxAcceleration - minAcceleration) * chargeQuality) * boostForceMultiplier

					if configBool("DRIVING_MECHANICS_EditAttributes", "DriftMiniBoostDebugAttributes", true) then
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
			if configBool("DRIVING_MECHANICS_EditAttributes", "DriftMiniBoostDebugAttributes", true) then
				state.Vehicle:SetAttribute("DriftMiniBoostAcceleratingOnExit", acceleratingOnDriftExit)
				state.Vehicle:SetAttribute("DriftMiniBoostRequiresAcceleration", requiresAcceleration)
			end
			state.DriftCharge = 0
			-- NTR_DRIFT_BOOST_ACCEL_GATE_REVERSE_40_V1_DRIFT_END
		end

		local boostHeld = not GameplayInputGate.IsLocked() and (UserInputService:IsKeyDown(Enum.KeyCode.Space) or state.GamepadBoostHeld)
		local miniBoostActive = state.MiniBoostTimer > 0
		local expiresDuringNormalBoost = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostExpiresDuringNormalBoost", 1, 0, 1) >= 0.5
		if miniBoostActive and expiresDuringNormalBoost then
			state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt)
		end
		if boostHeld and state.Boost > 1 and forwardSpeed > -4 and boostPower > 0 then
			state.Boost = math.max(0, state.Boost - (100 / boostDuration) * dt)
			state.BoostRechargeDelayTimer = state.BoostRechargeDelaySeconds
			driveForce += forward * mass * (boostPower + 32) * 0.75
			state.Vehicle:SetAttribute("Boosting", true)
			state.BoostCameraActive = true
		elseif miniBoostActive then
			if not expiresDuringNormalBoost then state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt) end
			local forceMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostForceApplicationMultiplier", 0.85, 0, 3)
			driveForce += forward * mass * state.MiniBoostPower * forceMultiplier
			state.Vehicle:SetAttribute("Boosting", true)
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
		end

		state.Vehicle:SetAttribute("DriftingLeft", drifting and steeringInput < -0.05)
		state.Vehicle:SetAttribute("DriftingRight", drifting and steeringInput > 0.05)
		state.Controls.DriveForce.Force = driveForce
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
		if drifting then
			local driftTurnMultiplier = handlingStep.Enabled and handlingStep.DriftTurnMultiplier or 1
			turnRate *= (1.34 + (driftControl / 170)) * driftTurnMultiplier
		end
		state.YawHeading += -steeringInput * turnRate * dt
		-- NTR_SPEED_SENSITIVE_STEERING_V1_END

		local bankInput = forwardSpeed < -4 and -steeringInput or steeringInput
		local targetBank = math.rad(math.clamp(-bankInput * 12, -12, 12))
		if drifting then targetBank += math.rad(math.clamp(-bankInput * 5, -5, 5)) * state.DriftBlend end
		state.CurrentBank += (targetBank - state.CurrentBank) * math.clamp(dt * 3.2, 0, 1)

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
		if handlingStep.Enabled then
			state.Controls.Align.Responsiveness = handlingStep.AlignResponsiveness
		else
			state.Controls.Align.Responsiveness = 22
		end
		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch + accelBrakePitch, 0, state.CurrentBank + wobbleRoll)
		-- NTR_ACCEL_BRAKE_PITCH_TILT_V1_END

		setVehicleCamera(state.Vehicle)

		if root.Position.Y < -50 then
			root.CFrame = CFrame.new(860, 106, -1713)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end

		updateExistingDriveUi(speedMph)
	end)

	return true
end

function Controller.ResetVehicle()
	if state.Vehicle and state.Vehicle.PrimaryPart then
		local root = state.Vehicle.PrimaryPart
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
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
