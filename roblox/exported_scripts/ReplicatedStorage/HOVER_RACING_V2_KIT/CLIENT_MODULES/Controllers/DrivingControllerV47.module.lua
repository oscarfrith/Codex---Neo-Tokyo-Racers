local Controller = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local REVERSE_MAX_MPH = 20
local HOVER_HEIGHT = 3
local SENSOR_START_HEIGHT = 2
local SENSOR_LENGTH = 24
local MPH_PER_STUD = 0.625
local CAMERA_RENDER_NAME = "HOVER_RACING_V75_CameraAssist"
local KIT_NAME = "HOVER_RACING_V2_KIT"

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
	local world = Workspace:FindFirstChild("HOVER_RACING_V2_WORLD")
	return world and world:FindFirstChild("PLAYER_VEHICLES_Runtime")
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
	local config = kit and kit:FindFirstChild("CONFIG")
	return config and config:FindFirstChild("DRIVING_CAMERA_ASSIST_EditAttributes")
end

local function configFolder(name)
	local kit = ReplicatedStorage:FindFirstChild(KIT_NAME)
	local config = kit and kit:FindFirstChild("CONFIG")
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

function configNumber(folderName, name, fallback, minimum, maximum)
	local folder = configFolder(folderName)
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "number" then
		value = fallback
	end
	if minimum and maximum then
		return math.clamp(value, minimum, maximum)
	end
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

local function updateCameraAssist(dt)
	if not state.IsDriving or not state.Vehicle or not state.Vehicle.Parent or not state.Vehicle.PrimaryPart then return end
	local cam = currentCamera()
	if not cam then return end
	local root = state.Vehicle.PrimaryPart

	local savedFov = state.SavedFieldOfView or cam.FieldOfView or 70
	local baseMultiplier = cameraNumber("BaseDrivingFovMultiplier", 1.15, 0.85, 1.6)
	local accelMultiplier = cameraNumber("AccelerationFovMultiplier", 1.015, 1, 1.2)
	local boostMultiplier = cameraNumber("BoostFovMultiplier", 1.07, 1, 1.35)
	local accelZoom = cameraNumber("AccelerationZoomOutStuds", 0.7, 0, 8)
	local boostZoom = cameraNumber("BoostZoomOutStuds", 3.2, 0, 14)
	local recenterDelay = cameraNumber("RecenterDelaySeconds", 1.15, 0.2, 4)
	local recenterSpeed = cameraNumber("RecenterSpeed", 2.15, 0.25, 8)
	local defaultHeight = cameraNumber("CameraHeight", 7.25, 2, 18)
	local defaultDistance = cameraNumber("CameraDistance", 29, 8, 90)

	local speedMph = root.AssemblyLinearVelocity.Magnitude * MPH_PER_STUD
	local moving = speedMph > 8
	local accelTarget = (state.AccelCameraActive and moving) and 1 or 0
	local boostTarget = state.BoostCameraActive and 1 or 0
	state.AccelCameraBlend += (accelTarget - state.AccelCameraBlend) * math.clamp(dt * 4.5, 0, 1)
	state.BoostCameraBlend += (boostTarget - state.BoostCameraBlend) * math.clamp(dt * 6.5, 0, 1)

	local fovMultiplier = baseMultiplier
	fovMultiplier *= 1 + (accelMultiplier - 1) * state.AccelCameraBlend
	fovMultiplier *= 1 + (boostMultiplier - 1) * state.BoostCameraBlend
	local targetFov = math.clamp(savedFov * fovMultiplier, 50, 110)
	state.CurrentFov = state.CurrentFov and (state.CurrentFov + (targetFov - state.CurrentFov) * math.clamp(dt * 5.5, 0, 1)) or targetFov
	cam.FieldOfView = state.CurrentFov

	local secondsSinceInput = os.clock() - state.LastCameraInputTime
	local shouldRecenter = moving and secondsSinceInput > recenterDelay

	local rootPosition = root.Position
	local currentDistance = (cam.CFrame.Position - rootPosition).Magnitude
	if currentDistance < 4 or currentDistance > 160 then
		currentDistance = defaultDistance
	end
	if state.PlayerAdjustedZoom and not shouldRecenter then
		state.ManualCameraDistance = currentDistance
	end
	if not shouldRecenter then return end

	local look = root.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	if flatForward.Magnitude < 0.05 then return end
	flatForward = flatForward.Unit

	local visualZoom = state.AccelCameraBlend * accelZoom + state.BoostCameraBlend * boostZoom
	local baseDistance = state.PlayerAdjustedZoom and (state.ManualCameraDistance or currentDistance) or defaultDistance
	local targetDistance = math.clamp(baseDistance + visualZoom, 6, 180)
	local targetHeight = math.min(defaultHeight, math.max(2.5, targetDistance * 0.55))
	local horizontalDistance = math.sqrt(math.max((targetDistance * targetDistance) - (targetHeight * targetHeight), 36))
	local targetPosition = rootPosition - flatForward * horizontalDistance + Vector3.new(0, targetHeight, 0)
	local lookTarget = rootPosition + flatForward * 8 + Vector3.new(0, math.min(targetHeight * 0.55, 4.5), 0)
	local targetCFrame = CFrame.lookAt(targetPosition, lookTarget)
	local alpha = math.clamp(dt * recenterSpeed, 0, 1)
	cam.CFrame = cam.CFrame:Lerp(targetCFrame, alpha)
end

local function startCameraAssist()
	local cam = currentCamera()
	state.SavedFieldOfView = cam and cam.FieldOfView or 70
	state.CurrentFov = state.SavedFieldOfView * cameraNumber("BaseDrivingFovMultiplier", 1.15, 0.85, 1.6)
	state.AccelCameraBlend = 0
	state.BoostCameraBlend = 0
	state.PlayerAdjustedZoom = false
	state.ManualCameraDistance = nil
	state.LastCameraInputTime = os.clock() - cameraNumber("RecenterDelaySeconds", 1.15, 0.2, 4)
	connectCameraInput()
	if not state.CameraAssistBound then
		state.CameraAssistBound = true
		RunService:BindToRenderStep(CAMERA_RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, updateCameraAssist)
	end
end

local function stopCameraAssist()
	if state.CameraAssistBound then
		RunService:UnbindFromRenderStep(CAMERA_RENDER_NAME)
		state.CameraAssistBound = false
	end
	disconnectCameraInput()
	local cam = currentCamera()
	if cam and state.SavedFieldOfView then
		cam.FieldOfView = state.SavedFieldOfView
	end
	state.SavedFieldOfView = nil
	state.CurrentFov = nil
	state.AccelCameraBlend = 0
	state.BoostCameraBlend = 0
	state.PlayerAdjustedZoom = false
	state.ManualCameraDistance = nil
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

local function setVehicleCamera(vehicle)
	local context = state.Context
	local cam = currentCamera()
	if not cam then return end
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
	setJumpLocked(true)
	showExistingDriveUi()
	state.Boost = 100
	state.DriftCharge = 0
	state.DriftBlend = 0
	state.MiniBoostTimer = 0
	state.MiniBoostPower = 0
	state.BoostRechargeDelayTimer = 0
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

		local maxMph = math.clamp(stat("TopSpeed", 126), 40, 260)
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

		local maxForwardStuds = maxMph / MPH_PER_STUD
		local maxReverseStuds = REVERSE_MAX_MPH / MPH_PER_STUD
		local hitPositions = {}
		local normalSum = Vector3.zero
		local hits = 0
		local liftPerCorner = mass * Workspace.Gravity / 4

		for index, corner in ipairs(state.Controls.Corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), state.RayParams)
			if result then
				local targetDistance = HOVER_HEIGHT + SENSOR_START_HEIGHT
				local heightError = targetDistance - result.Distance
				local pointVelocityY = root:GetVelocityAtPosition(origin).Y
				local forceAmount = liftPerCorner + mass * (heightError * 48 - pointVelocityY * 6)
				corner.Force.Force = Vector3.new(0, math.clamp(forceAmount, 0, liftPerCorner * 4.25), 0)
				hitPositions[index] = result.Position
				normalSum += result.Normal
				hits += 1
			else
				corner.Force.Force = Vector3.new(0, liftPerCorner * 0.05, 0)
			end
		end

		local terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local grounded = hits >= 2
		local steeringInput = steer
		if forwardSpeed < -4 then steeringInput = -steer end

		local canDrift = state.DriftHeld and forwardSpeed > 8 and speedMph > 10 and math.abs(steeringInput) > 0 and grounded
		local targetDriftBlend = canDrift and 1 or 0
		state.DriftBlend += (targetDriftBlend - state.DriftBlend) * math.clamp(dt * 5.2, 0, 1)
		local drifting = state.DriftBlend > 0.12

		local driveForce = Vector3.zero
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

		if drifting then
			local forwardDriftSlow = math.max(forwardSpeed, 0) * mass * (0.72 + 0.42 * state.DriftBlend)
			driveForce -= forward * forwardDriftSlow * state.DriftBlend
			driveForce += right * (-steeringInput) * mass * 34 * state.DriftBlend
			state.DriftCharge = math.min(3.25, state.DriftCharge + dt * (0.95 + math.abs(steeringInput) * 1.15) * state.DriftBlend)
		elseif not state.DriftHeld and state.DriftCharge > 0 then
			if state.DriftCharge > 0.72 then
				local charge = state.DriftCharge
				state.MiniBoostTimer = math.clamp(0.22 + charge * 0.48, 0.35, 1.85)
				state.MiniBoostPower = math.clamp(48 + charge * 27, 58, 136)
			end
			state.DriftCharge = 0
		end

		local boostHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space) or state.GamepadBoostHeld
		if boostHeld and state.Boost > 1 and forwardSpeed > -4 and boostPower > 0 then
			state.Boost = math.max(0, state.Boost - (100 / boostDuration) * dt)
			state.BoostRechargeDelayTimer = state.BoostRechargeDelaySeconds
			driveForce += forward * mass * (boostPower + 32) * 0.75
			state.Vehicle:SetAttribute("Boosting", true)
			state.BoostCameraActive = true
		elseif state.MiniBoostTimer > 0 then
			state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt)
			driveForce += forward * mass * state.MiniBoostPower * 0.92
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

		local speedFactor = math.clamp(math.abs(forwardSpeed) * MPH_PER_STUD / 45, 0.35, 1.35)
		local turnRate = (handling / 58) * 1.08 * speedFactor
		if drifting then turnRate *= 1.34 + (driftControl / 170) end
		state.YawHeading += -steeringInput * turnRate * dt

		local bankInput = forwardSpeed < -4 and -steeringInput or steeringInput
		local targetBank = math.rad(math.clamp(-bankInput * 12, -12, 12))
		if drifting then targetBank += math.rad(math.clamp(-bankInput * 5, -5, 5)) * state.DriftBlend end
		state.CurrentBank += (targetBank - state.CurrentBank) * math.clamp(dt * 3.2, 0, 1)

		terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local wobblePitch, wobbleRoll = updateHoverWobble(dt, speedMph, grounded)
		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch, 0, state.CurrentBank + wobbleRoll)

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
	if inputState == Enum.UserInputState.Begin and state.IsDriving then
		Controller.ResetVehicle()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

return Controller
