--[[
	Hover Racing V2 - V74 Pre-V72 Camera Assist
	Paste this whole file into the Roblox Studio Command Bar while NOT play-testing.

	This restores the pre-V72/V62 driving camera style, then adds a light
	camera-assist layer for FOV and soft recentering.

	What it changes:
	- Replaces DrivingControllerV47 with V47-style driving and camera assist.
	- Adds ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_CAMERA_ASSIST_EditAttributes.
	- Keeps Roblox's normal vehicle camera as the base camera.
	- Applies +15% driving FOV, tiny acceleration FOV/zoom feel, stronger boost FOV/zoom feel.
	- Softly recentres camera angle/height after player camera input stops while moving.

	What it does NOT touch:
	- dealership UI
	- customisation UI
	- server action layer
	- vehicle folders/assets/catalogue
	- lighting/textures/materials
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local KIT_NAME = "HOVER_RACING_V2_KIT"
local CLIENT_SCRIPT_NAME = "HOVER_RACING_V2_Client"

local function log(message)
	print("[V74] " .. message)
end

local function requireChild(parent, name)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[V74] Missing %s under %s"):format(name, parent and parent:GetFullName() or "nil"))
	end
	return child
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then
		folder.Name = folder.Name .. "_OldNonFolder"
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function writeModule(parent, name, source)
	local module = parent:FindFirstChild(name)
	if module and not module:IsA("ModuleScript") then
		module.Name = module.Name .. "_OldNonModule"
		module = nil
	end
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = name
		module.Parent = parent
	end
	module.Source = source
	return module
end

local function stripMarkedBlock(source, beginMarker, endMarker)
	while true do
		local beginIndex = string.find(source, beginMarker, 1, true)
		if not beginIndex then break end
		local endIndex = string.find(source, endMarker, beginIndex, true)
		if not endIndex then break end
		source = string.sub(source, 1, beginIndex - 1) .. string.sub(source, endIndex + #endMarker + 1)
	end
	return source
end

local kit = requireChild(ReplicatedStorage, KIT_NAME)
local starterScripts = requireChild(StarterPlayer, "StarterPlayerScripts")
local clientScript = requireChild(starterScripts, CLIENT_SCRIPT_NAME)
local clientModules = ensureFolder(kit, "CLIENT_MODULES")
local controllerModules = ensureFolder(clientModules, "Controllers")
local configRoot = ensureFolder(kit, "CONFIG")
local cameraConfig = ensureFolder(configRoot, "DRIVING_CAMERA_ASSIST_EditAttributes")

local defaults = {
	BaseDrivingFovMultiplier = 1.15,
	CameraHeight = 7.25,
	CameraDistance = 29,
	AccelerationFovMultiplier = 1.015,
	BoostFovMultiplier = 1.07,
	AccelerationZoomOutStuds = 0.7,
	BoostZoomOutStuds = 3.2,
	RecenterDelaySeconds = 1.15,
	RecenterSpeed = 2.15,
}

for name, value in pairs(defaults) do
	if cameraConfig:GetAttribute(name) == nil then
		cameraConfig:SetAttribute(name, value)
	end
end

writeModule(controllerModules, "DrivingControllerV47", [===[
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
local CAMERA_RENDER_NAME = "HOVER_RACING_V74_CameraAssist"
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
	YawHeading = 0,
	CurrentBank = 0,
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
	if not shouldRecenter then return end

	local look = root.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	if flatForward.Magnitude < 0.05 then return end
	flatForward = flatForward.Unit

	local rootPosition = root.Position
	local currentDistance = (cam.CFrame.Position - rootPosition).Magnitude
	if currentDistance < 4 or currentDistance > 160 then
		currentDistance = defaultDistance
	end
	if state.PlayerAdjustedZoom and not shouldRecenter then
		state.ManualCameraDistance = currentDistance
	end

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
		warn("[V74] V47 driving could not find the spawned vehicle.")
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
	state.CurrentBank = 0
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
		local boostRecharge = math.max(stat("BoostRecharge", 9), 4)
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
			driveForce += forward * mass * (boostPower + 32) * 0.75
			state.Vehicle:SetAttribute("Boosting", true)
			state.BoostCameraActive = true
		elseif state.MiniBoostTimer > 0 then
			state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt)
			driveForce += forward * mass * state.MiniBoostPower * 0.92
			state.Vehicle:SetAttribute("Boosting", true)
			state.BoostCameraActive = true
		else
			state.Boost = math.min(100, state.Boost + (100 / boostRecharge) * dt)
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
		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(0, 0, state.CurrentBank)

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
]===])

local drivingModule = controllerModules:FindFirstChild("DrivingControllerV47")
if drivingModule then
	drivingModule:SetAttribute("HoverRacingVersion", "V74_PreV72CameraAssist")
end

local source = clientScript.Source
source = stripMarkedBlock(source, "-- V59_SAFE_DRIVING_FALLBACK_BEGIN", "-- V59_SAFE_DRIVING_FALLBACK_END")
source = stripMarkedBlock(source, "-- V60_APPEND_ONLY_DRIVING_FAILSAFE_BEGIN", "-- V60_APPEND_ONLY_DRIVING_FAILSAFE_END")
source = stripMarkedBlock(source, "-- V61_MODULE_DRIVING_FAILSAFE_BEGIN", "-- V61_MODULE_DRIVING_FAILSAFE_END")
source = stripMarkedBlock(source, "-- V62_RESTORE_V47_DRIVING_BEGIN", "-- V62_RESTORE_V47_DRIVING_END")
source = stripMarkedBlock(source, "-- V74_CAMERA_ASSIST_DRIVING_BEGIN", "-- V74_CAMERA_ASSIST_DRIVING_END")

if not string.find(source, "local function startDriving()", 1, true) then
	error("[V74] Could not find local function startDriving(). No client changes were applied.")
end

local wrapper = [===[

-- V74_CAMERA_ASSIST_DRIVING_BEGIN
do
	local okController, V74Driving = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("HOVER_RACING_V2_KIT"):WaitForChild("CLIENT_MODULES"):WaitForChild("Controllers"):WaitForChild("DrivingControllerV47"))
	end)
	if okController and typeof(V74Driving) == "table" and typeof(V74Driving.Start) == "function" then
		local V74OriginalStopDriving = typeof(stopDriving) == "function" and stopDriving or nil
		startDriving = function()
			return V74Driving.Start({
				GetCamera = function()
					return camera or game:GetService("Workspace").CurrentCamera
				end,
				ShowDriveUi = function()
					if typeof(ensureDriveHud) == "function" then pcall(ensureDriveHud) end
					if driveGui then driveGui.Enabled = true end
					if typeof(updateMobileDriveControls) == "function" then pcall(updateMobileDriveControls) end
				end,
				UpdateDriveUi = function(speedMph, boostPercent, driftingNow, driftChargeNow, miniBoostTimerNow)
					if mphLabel then mphLabel.Text = tostring(math.floor((speedMph or 0) + 0.5)) .. " MPH" end
					if boostFill then boostFill.Size = UDim2.fromScale(math.clamp((boostPercent or 0) / 100, 0, 1), 1) end
					if driftLabel then
						if driftingNow then
							driftLabel.Text = (driftChargeNow or 0) > 1.4 and "DRIFT CHARGED" or "DRIFT"
						elseif (miniBoostTimerNow or 0) > 0 then
							driftLabel.Text = "MINI BOOST"
						else
							driftLabel.Text = "SHIFT drift | SPACE boost | R reset"
						end
					end
					if typeof(updateMobileDriveControls) == "function" then pcall(updateMobileDriveControls) end
				end,
				GetMobileInput = function()
					local throttleValue, steerValue, driftValue, boostValue = 0, 0, false, false
					if typeof(mobileInputState) == "table" then
						throttleValue = mobileInputState.Throttle or 0
						steerValue = mobileInputState.Steer or 0
						driftValue = mobileInputState.Drift == true
						boostValue = mobileInputState.Boost == true
					elseif typeof(mobileControls) == "table" and typeof(mobileControls.State) == "table" then
						local s = mobileControls.State
						throttleValue = math.clamp((s.Accelerate and 1 or 0) - (s.Brake and 1 or 0), -1, 1)
						steerValue = math.clamp(((s.TurnRight or s.DriftRight) and 1 or 0) - ((s.TurnLeft or s.DriftLeft) and 1 or 0), -1, 1)
						driftValue = s.DriftLeft == true or s.DriftRight == true
						boostValue = s.Boost == true
					end
					return throttleValue, steerValue, driftValue, boostValue
				end,
				PublishMobile = function(speedMph, boostPercent)
					if typeof(mobileInputState) == "table" then
						mobileInputState.SpeedMph = speedMph or 0
						mobileInputState.BoostPercent = math.clamp(boostPercent or 0, 0, 100)
						mobileInputState.IsDriving = true
					end
				end,
				SetMobileDriving = function(enabled)
					if typeof(mobileInputState) == "table" then
						mobileInputState.IsDriving = enabled == true
						if not enabled and typeof(mobileInputState.Reset) == "function" then mobileInputState.Reset() end
					end
				end,
			})
		end
		stopDriving = function(...)
			V74Driving.Stop()
			if V74OriginalStopDriving then
				return V74OriginalStopDriving(...)
			end
		end
		print("[V74] V47-style driving controller with camera assist is active.")
	else
		warn("[V74] Could not install V47-style driving controller: " .. tostring(V74Driving))
	end
end
-- V74_CAMERA_ASSIST_DRIVING_END
]===]

clientScript.Source = source .. wrapper
clientScript.Disabled = false

log("Installed V47-style driving module, camera assist config, and tiny client wrapper. UI/customisation/server systems were not touched.")
print("Hover Racing V74 pre-V72 camera assist complete. Run in Edit mode, then Play fresh and spawn the vehicle.")
