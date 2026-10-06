-- Canonical feature implementation; startup is owned by the composition root.
-- Two modes, chosen by Config.Vehicles.Camera ScriptedChaseEnabled (scripts/hover_feel/CONTRACT.md):
--   Scripted chase (default): this controller owns Camera.CFrame while driving. The lens is locked to the vehicle's
--     render position; every relative motion (yaw follow, pull-back, vertical ride, shake) is a smoothed scalar
--     solved with closed-form springs, so it is the same at any frame rate.
--   V6.1: Roblox owns Camera.CFrame, collision, orbit, and platform input; this controller only selects the seat,
--     locks a smooth distance, changes FOV, and applies one initial look angle.
-- Field of view goes through Core.CameraService in both modes.
local Controller = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CameraService = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("CameraService"))

local RENDER_NAME = "VehicleCamera"
local INITIAL_RENDER_NAME = "VehicleCameraInitialFraming"
local OWNER = "DefaultVehicleCameraV6"
local CHASE_OWNER = "ScriptedChaseV1"
local MPH_PER_STUD = 0.625

local active, suspended, context, ownedCamera, subject = false, false, nil, nil, nil
local connections = {}
local previousType, previousSubject, previousFov, previousMinZoom, previousMaxZoom
local currentDistance, currentFov, accelBlend, boostBlend
local configFolder, configValues, nextConfigRefresh = nil, {}, 0
local initialLookFrames, debugWasEnabled, zoomIsLocked = 0, false, false
local chaseMode, chase, look = false, nil, nil
local speedLines = nil

local function resolveFolder()
	if configFolder and configFolder.Parent then return configFolder end
	local kit = game:GetService("ReplicatedStorage")
	local config = kit and game:GetService("ReplicatedStorage"):FindFirstChild("Config")
	local runtime = config and game:GetService("ReplicatedStorage"):FindFirstChild("Config")
	local result = runtime and game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):FindFirstChild("Camera")
	configFolder = result and result:IsA("Folder") and result or nil
	return configFolder
end
local function refreshConfig(force)
	local now = os.clock()
	if not force and now < nextConfigRefresh then return end
	local folder = resolveFolder()
	configValues = folder and folder:GetAttributes() or {}
	local interval = configValues.ConfigRefreshSeconds
	if typeof(interval) ~= "number" then interval = 0.25 end
	nextConfigRefresh = now + math.clamp(interval, 0.05, 2)
end
local function number(name, fallback, minimum, maximum)
	local value = configValues[name]
	if typeof(value) ~= "number" then value = fallback end
	if minimum ~= nil and maximum ~= nil then value = math.clamp(value, minimum, maximum) end
	return value
end
local function flag(name, fallback)
	local value = configValues[name]
	return typeof(value) == "boolean" and value or fallback
end
-- Unlike flag, a configured false is honoured.
local function switch(name, fallback)
	local value = configValues[name]
	if typeof(value) == "boolean" then return value end
	return fallback
end
local function responseAlpha(rate, dt)
	return 1 - math.exp(-math.max(rate, 0) * math.max(dt, 0))
end
local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end
local function smoothstep(a, b, value)
	if b <= a then return value >= b and 1 or 0 end
	local t = math.clamp((value - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
local function camera()
	local result = context and context.GetCamera and context.GetCamera() or Workspace.CurrentCamera
	return result and result:IsA("Camera") and result or nil
end
local function character()
	if context and context.GetCharacter then return context.GetCharacter() end
	return Players.LocalPlayer and Players.LocalPlayer.Character or nil
end
local function resolveSubject(vehicle)
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	if seat and seat:IsA("VehicleSeat") then return seat end
	local char = character()
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	return humanoid
end
local function finite(value)
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local function finiteVector(value)
	return finite(value.X) and finite(value.Y) and finite(value.Z)
end
local function setLockedDistance(player, distance)
	-- math.clamp passes NaN through; a NaN zoom bound makes Roblox's camera error every frame.
	if not finite(distance) then return end
	-- CameraService owns the player zoom limits (priority 100 while driving).
	CameraService.SetZoomLimits("DrivingCamera", distance, distance, 100)
end
local function restoreZoom()
	CameraService.ClearZoomLimits("DrivingCamera")
	zoomIsLocked = false
end
local function clearDebug(cam)
	for _, name in ipairs({"CameraMode", "CameraSpeedMph", "CameraTargetDistance", "CameraCurrentDistance", "CameraTargetFov", "CameraCurrentFov"}) do
		cam:SetAttribute(name, nil)
	end
end
local function publishDebug(cam, speed, targetDistance, targetFov)
	if not flag("DebugEnabled", false) then
		if debugWasEnabled then clearDebug(cam) end
		debugWasEnabled = false
		return
	end
	debugWasEnabled = true
	cam:SetAttribute("CameraMode", chaseMode and CHASE_OWNER or OWNER)
	cam:SetAttribute("CameraSpeedMph", speed)
	cam:SetAttribute("CameraTargetDistance", targetDistance)
	cam:SetAttribute("CameraCurrentDistance", currentDistance)
	cam:SetAttribute("CameraTargetFov", targetFov)
	cam:SetAttribute("CameraCurrentFov", currentFov)
end
local function applyInitialLook(cam, vehicle)
	if not flag("ApplyInitialLookAngle", true) then return end
	local root = vehicle and vehicle.PrimaryPart or subject
	if not root or not root:IsA("BasePart") then return end
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.05 then return end
	forward = forward.Unit
	local yaw = math.rad(number("DefaultYawDegrees", 0, -180, 180))
	forward = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(forward)
	local distance = currentDistance or number("DefaultDistanceStuds", 29, 2, 150)
	local height = number("DefaultHeightStuds", 7.25, -10, 50)
		+ math.tan(math.rad(number("DefaultPitchDegrees", 0, -45, 45))) * distance
	local target = root.Position
		+ forward * number("LookAheadStuds", 8, -20, 50)
		+ Vector3.new(0, number("LookTargetHeightStuds", 2.5, -10, 30), 0)
	local position = root.Position - forward * distance + Vector3.new(0, height, 0)
	if (target - position).Magnitude > 0.1 then
		cam.CFrame = CFrame.lookAt(position, target)
		cam.Focus = CFrame.new(target)
	end
end
local function queueInitialLook()
	refreshConfig(true)
	if chaseMode then initialLookFrames = 0; return end
	if flag("ApplyInitialLookAngle", true) then
		initialLookFrames = math.floor(number("InitialLookApplyFrames", 3, 1, 12))
	else
		initialLookFrames = 0
	end
end
local function updateInitialLook()
	if not active or suspended or initialLookFrames <= 0 or not context then return end
	local cam = camera()
	local vehicle = context.Vehicle
	if not cam or not vehicle or not vehicle.Parent then return end
	applyInitialLook(cam, vehicle)
	initialLookFrames -= 1
end
local function takeDefaultCamera(cam)
	cam:SetAttribute("DrivingCameraManaged", true)
	cam:SetAttribute("DrivingCameraOwner", OWNER)
	cam.CameraType = Enum.CameraType.Custom
	if subject and subject.Parent then cam.CameraSubject = subject end
end

-- Scripted chase -----------------------------------------------------------------------------------------------

-- Closed-form critically damped step toward target.
local function critical(x, v, target, omega, dt)
	local e = x - target
	local decay = math.exp(-omega * dt)
	local temp = (v + omega * e) * dt
	return target + (e + temp) * decay, (v - omega * temp) * decay
end
-- Closed-form underdamped step toward zero (zeta < 1).
local function damped(x, v, omega, zeta, dt)
	local wd = omega * math.sqrt(1 - zeta * zeta)
	local decay = math.exp(-zeta * omega * dt)
	local c, s = math.cos(wd * dt), math.sin(wd * dt)
	local b = (v + zeta * omega * x) / wd
	return decay * (x * c + b * s), decay * ((b * wd - zeta * omega * x) * c - (x * wd + zeta * omega * b) * s)
end
local function wrapAngle(angle)
	return (angle + math.pi) % (2 * math.pi) - math.pi
end
-- Yaw whose CFrame.Angles(0, yaw, 0).LookVector points along the flat direction.
local function yawOf(flat)
	return math.atan2(-flat.X, -flat.Z)
end
local function yawDirection(yaw)
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end
local function takeScriptedCamera(cam)
	cam:SetAttribute("DrivingCameraManaged", true)
	cam:SetAttribute("DrivingCameraOwner", CHASE_OWNER)
	cam.CameraType = Enum.CameraType.Scriptable
	if subject and subject.Parent then cam.CameraSubject = subject end
end
local function resetLook()
	look = { Yaw = 0, YawVelocity = 0, Pitch = 0, PitchVelocity = 0, MouseHeld = false, Touch = nil, LastInput = 0, StickYaw = 0, StickPitch = 0, StickActive = false, LockedMouse = false }
end
local function releaseMouse()
	if look and look.LockedMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		look.LockedMouse = false
	end
end
local function resetChase(root, cam)
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local heading = flat.Magnitude > 0.05 and yawOf(flat.Unit) or 0
	local position = root.Position
	chase = {
		Heading = heading, Yaw = heading, YawVelocity = 0,
		LookAhead = 0, LookAheadVelocity = 0,
		Y = position.Y, YVelocity = 0, Climb = 0,
		Pitch = 0, PitchVelocity = 0,
		Lag = 0, LagVelocity = 0,
		Roll = 0, RollVelocity = 0,
		Shift = 0, ShiftVelocity = 0,
		ForwardSpeed = nil, Acceleration = 0, AccelerationVelocity = 0,
		Punch = 0, PunchVelocity = 0,
		KickPitch = 0, KickPitchVelocity = 0, KickRoll = 0, KickRollVelocity = 0, Bump = 0, BumpVelocity = 0,
		Occlusion = 1, Ignore = nil, IgnoreCount = 0,
		Position = position, Time = 0,
		WasBoosting = false,
		ImpactRevision = context and context.Vehicle and context.Vehicle:GetAttribute("FeelImpactRevision") or nil,
		LandRevision = context and context.Vehicle and context.Vehicle:GetAttribute("FeelLandRevision") or nil,
		EntryCFrame = cam and cam.CFrame or nil, EntryTime = 0,
		RayParams = nil,
	}
end
local function chaseRayParams(vehicle)
	if chase.RayParams and chase.IgnoreCount < 400 then return chase.RayParams end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local ignore = { vehicle }
	local char = character()
	if char then table.insert(ignore, char) end
	-- Other players' vehicles never push the camera in.
	if vehicle.Parent then table.insert(ignore, vehicle.Parent) end
	params.FilterDescendantsInstances = ignore
	chase.RayParams, chase.Ignore, chase.IgnoreCount = params, ignore, #ignore
	return params
end
-- Returns the fraction of the pivot-to-lens path that is clear. See-through and thin parts are added to the filter.
local function occlusionFraction(vehicle, pivot, offset)
	local length = offset.Magnitude
	if length < 0.5 then return 1 end
	local params = chaseRayParams(vehicle)
	local radius = number("ChaseOcclusionRadiusStuds", 0.6, 0.05, 3)
	for _ = 1, 3 do
		local result = Workspace:Spherecast(pivot, radius, offset, params)
		if not result then return 1 end
		local part = result.Instance
		local size = part.Size
		local thin = (size.X < 2.5 and 1 or 0) + (size.Y < 2.5 and 1 or 0) + (size.Z < 2.5 and 1 or 0)
		if part.Transparency > 0.6 or thin >= 2 then
			table.insert(chase.Ignore, part)
			chase.IgnoreCount += 1
			params.FilterDescendantsInstances = chase.Ignore
		else
			return math.clamp(result.Distance / length, 0, 1)
		end
	end
	return 1
end
local function updateLook(dt)
	local now = os.clock()
	local held = look.MouseHeld or look.Touch ~= nil
	if look.StickActive then
		look.Yaw, look.YawVelocity = critical(look.Yaw, look.YawVelocity, look.StickYaw, 10, dt)
		look.Pitch, look.PitchVelocity = critical(look.Pitch, look.PitchVelocity, look.StickPitch, 10, dt)
	elseif not held and now - look.LastInput > number("ChaseLookReturnDelaySeconds", 0.25, 0, 5) then
		local rate = number("ChaseLookReturnRate", 6, 0.5, 30)
		look.Yaw, look.YawVelocity = critical(look.Yaw, look.YawVelocity, 0, rate, dt)
		look.Pitch, look.PitchVelocity = critical(look.Pitch, look.PitchVelocity, 0, rate, dt)
	else
		look.YawVelocity, look.PitchVelocity = 0, 0
	end
end
local function orbitLook(deltaX, deltaY, scale)
	look.Yaw = wrapAngle(look.Yaw - deltaX * scale)
	look.Pitch = math.clamp(look.Pitch + deltaY * scale * 0.8, math.rad(-25), math.rad(55))
	look.LastInput = os.clock()
end
local function connectChaseInput()
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or suspended or not chaseMode then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			look.MouseHeld = true
			look.LastInput = os.clock()
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			look.LockedMouse = true
		elseif input.UserInputType == Enum.UserInputType.Touch and look.Touch == nil then
			local cam = camera()
			local viewport = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			if input.Position.Y < viewport.Y * 0.58 then
				look.Touch = input
				look.LastInput = os.clock()
			end
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			look.MouseHeld = false
			look.LastInput = os.clock()
			releaseMouse()
		elseif input.UserInputType == Enum.UserInputType.Touch and look.Touch == input then
			look.Touch = nil
			look.LastInput = os.clock()
		end
	end))
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(function()
		look.MouseHeld, look.Touch = false, nil
		releaseMouse()
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if suspended or not chaseMode then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement and look.MouseHeld then
			orbitLook(input.Delta.X, input.Delta.Y, number("ChaseLookMouseRadiansPerPixel", 0.0045, 0.0002, 0.05))
		elseif input.UserInputType == Enum.UserInputType.Touch and look.Touch == input then
			orbitLook(input.Delta.X, input.Delta.Y, number("ChaseLookTouchRadiansPerPixel", 0.0075, 0.0002, 0.05))
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local position = input.Position
			if position.Magnitude > 0.18 then
				look.StickActive = true
				look.StickYaw = -position.X * math.rad(150)
				look.StickPitch = -position.Y * math.rad(25)
				look.LastInput = os.clock()
			else
				look.StickActive = false
			end
		end
	end))
end
-- Speed lines: thin streaks at the screen edges that fade in with speed and boost. One ScreenGui owned by this
-- controller for the length of a drive; a CanvasGroup carries the fade so only one property changes per frame.
local function destroySpeedLines()
	if speedLines then
		speedLines.Gui:Destroy()
		speedLines = nil
	end
end
local function placeSpeedLine(line, viewport)
	local angle = math.random() * 2 * math.pi
	local half = viewport.Magnitude * 0.5
	local length = half * (0.14 + math.random() * 0.26)
	local radius = half * (0.5 + math.random() * 0.45)
	line.Rotation = math.deg(angle)
	line.Size = UDim2.fromOffset(length, 2 + math.random() * 2.5)
	line.Position = UDim2.new(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
end
local function buildSpeedLines()
	destroySpeedLines()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui or not switch("ChaseSpeedLinesEnabled", true) then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DrivingSpeedEffect"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -10
	gui.Enabled = false
	local group = Instance.new("CanvasGroup")
	group.Name = "Lines"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.GroupTransparency = 1
	group.Active = false
	group.Interactable = false
	group.Parent = gui
	local count = math.floor(number("ChaseSpeedLineCount", 64, 0, 120))
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then count = math.floor(count * 0.5) end
	local cam = camera()
	local viewport = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local lines = {}
	for index = 1, count do
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		-- Each streak fades out toward the centre of the screen.
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
		gradient.Parent = line
		placeSpeedLine(line, viewport)
		line.Parent = group
		lines[index] = line
	end
	gui.Parent = playerGui
	speedLines = { Gui = gui, Group = group, Lines = lines, Next = 1, Timer = 0, Shown = 0 }
end
local function updateSpeedLines(dt, speed, boostAmount)
	if not speedLines or #speedLines.Lines == 0 then return end
	local amount = smoothstep(number("ChaseSpeedLineStartMph", 110, 0, 500), number("ChaseSpeedLineFullMph", 230, 1, 600), speed) * 0.6 + boostAmount * 0.4
	amount = math.clamp(amount, 0, 1) * number("ChaseSpeedLineOpacity", 0.7, 0, 1)
	if amount < 0.02 then
		if speedLines.Shown ~= 0 then
			speedLines.Shown = 0
			speedLines.Gui.Enabled = false
		end
		return
	end
	if speedLines.Shown == 0 then speedLines.Gui.Enabled = true end
	if math.abs(amount - speedLines.Shown) > 0.01 then
		speedLines.Shown = amount
		speedLines.Group.GroupTransparency = 1 - amount
	end
	-- Re-place a few streaks every tick so the field flickers outward instead of sitting still.
	speedLines.Timer += dt
	if speedLines.Timer >= 0.04 then
		speedLines.Timer = 0
		local cam = camera()
		local viewport = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		local lines = speedLines.Lines
		for _ = 1, math.min(#lines, 6) do
			placeSpeedLine(lines[speedLines.Next], viewport)
			speedLines.Next = speedLines.Next % #lines + 1
		end
	end
end
local function chaseEvents(vehicle, boosting)
	local shake = number("ChaseShakeScale", 1, 0, 4)
	local impact = vehicle:GetAttribute("FeelImpactRevision")
	if impact ~= chase.ImpactRevision then
		chase.ImpactRevision = impact
		local strength = vehicle:GetAttribute("FeelImpactStrength")
		if finite(strength) and impact ~= nil then
			local amount = math.clamp(strength / 80, 0.1, 1.5) * shake
			local side = (math.random() < 0.5) and -1 or 1
			chase.KickPitchVelocity -= amount * 1.1
			chase.KickRollVelocity += amount * 0.9 * side
			chase.BumpVelocity += amount * 7
		end
	end
	local land = vehicle:GetAttribute("FeelLandRevision")
	if land ~= chase.LandRevision then
		chase.LandRevision = land
		local strength = vehicle:GetAttribute("FeelLandStrength")
		if finite(strength) and land ~= nil then
			local amount = math.clamp(strength / 40, 0.3, 1.5) * shake
			chase.KickPitchVelocity -= amount * 0.6
			chase.BumpVelocity -= amount * 6
		end
	end
	if boosting and not chase.WasBoosting then
		-- Sized so the spring peaks at the configured value: velocity = peak * omega * e.
		chase.PunchVelocity += number("ChaseBoostPunchDegrees", 4, 0, 20) * 6 * math.exp(1)
		chase.LagVelocity += number("ChaseBoostKickStudsPerSecond", 9, 0, 40)
	end
	chase.WasBoosting = boosting
end
local function updateChase(dt)
	if not active or suspended or not context then return end
	refreshConfig(false)
	if not flag("Enabled", true) then Controller.Stop(); return end
	if not switch("ScriptedChaseEnabled", true) then Controller.Start(context); return end
	local vehicle = context.Vehicle
	local root = vehicle and vehicle.Parent and vehicle.PrimaryPart
	if not root then return end
	local cam = camera()
	if not cam then return end
	ownedCamera = cam
	if cam.CameraType ~= Enum.CameraType.Scriptable or cam:GetAttribute("DrivingCameraManaged") ~= true then takeScriptedCamera(cam) end
	dt = math.clamp(dt, 1 / 400, 0.1)

	local rootCFrame = root.CFrame
	local position = rootCFrame.Position
	local velocity = root.AssemblyLinearVelocity
	local lookVector = rootCFrame.LookVector
	if not finiteVector(position) or not finiteVector(velocity) or not finiteVector(lookVector) then return end
	local flat = Vector3.new(lookVector.X, 0, lookVector.Z)
	local heading = flat.Magnitude > 0.05 and yawOf(flat.Unit) or chase.Heading
	-- A teleport, reset or respawn cuts instead of swinging.
	if (position - chase.Position).Magnitude > number("ChaseCutDistanceStuds", 60, 5, 1000) or math.abs(wrapAngle(heading - chase.Heading)) > math.max(0.5, 8 * dt) then
		resetChase(root, nil)
	end
	chase.Position, chase.Heading = position, heading
	chase.Time += dt

	local forward = yawDirection(heading)
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local speedStuds = horizontal.Magnitude
	local speed = speedStuds * MPH_PER_STUD
	local forwardSpeed = horizontal:Dot(forward)
	local boosting = context.IsBoosting and context.IsBoosting() or false
	local accelerating = context.IsAccelerating and context.IsAccelerating() or false
	chaseEvents(vehicle, boosting)

	-- Yaw: follow the heading, leaning toward where the car is actually travelling when it slides.
	local slip = 0
	if forwardSpeed > 0 and speedStuds > 1 then
		slip = math.clamp(wrapAngle(yawOf(horizontal.Unit) - heading), math.rad(-60), math.rad(60)) * smoothstep(10, 40, speedStuds)
	end
	local yawTarget = heading + slip * number("ChaseSlipFollow", 0.35, 0, 1)
	yawTarget = chase.Yaw + wrapAngle(yawTarget - chase.Yaw)
	chase.Yaw, chase.YawVelocity = critical(chase.Yaw, chase.YawVelocity, yawTarget, number("ChaseYawResponse", 7.5, 0.5, 40), dt)
	local lookAheadLimit = math.rad(number("ChaseLookAheadMaxDegrees", 9, 0, 45))
	local lookAheadTarget = math.clamp(root.AssemblyAngularVelocity.Y * number("ChaseLookAheadSeconds", 0.22, 0, 2), -lookAheadLimit, lookAheadLimit)
	if not finite(lookAheadTarget) then lookAheadTarget = 0 end
	chase.LookAhead, chase.LookAheadVelocity = critical(chase.LookAhead, chase.LookAheadVelocity, lookAheadTarget, 2, dt)
	-- Roll: the view leans into the turn, and further into a slide.
	local rollLimit = math.rad(number("ChaseRollMaxDegrees", 11, 0, 30))
	local yawRate = root.AssemblyAngularVelocity.Y
	local rollTarget = (finite(yawRate) and yawRate or 0) * math.rad(number("ChaseTurnRollDegreesPerRadian", 3.2, 0, 20)) * smoothstep(8, 60, speedStuds)
		- slip * number("ChaseSlipRoll", 0.22, 0, 1)
	chase.Roll, chase.RollVelocity = critical(chase.Roll, chase.RollVelocity, math.clamp(rollTarget, -rollLimit, rollLimit), number("ChaseRollResponse", 5, 0.5, 30), dt)
	-- Side shift: in a slide the view moves toward the inside of the corner, so the car sits off-centre
	-- and the road it is turning into opens up.
	local shiftTarget = math.clamp(slip / math.rad(40), -1, 1) * number("ChaseDriftShiftStuds", 5, 0, 20)
	chase.Shift, chase.ShiftVelocity = critical(chase.Shift, chase.ShiftVelocity, shiftTarget, number("ChaseDriftShiftResponse", 3.5, 0.5, 30), dt)

	-- Vertical: a spring riding the low-passed climb rate, so bumps are filtered and a steady grade leaves no lag.
	chase.Climb += (velocity.Y - chase.Climb) * responseAlpha(4, dt)
	local heightError, heightVelocity = critical(chase.Y + chase.Climb * dt - position.Y, chase.YVelocity - chase.Climb, 0, number("ChaseVerticalResponse", 6, 0.5, 40), dt)
	heightError = math.clamp(heightError, -8, 8)
	chase.Y, chase.YVelocity = position.Y + heightError, heightVelocity + chase.Climb
	chase.Pitch, chase.PitchVelocity = critical(chase.Pitch, chase.PitchVelocity, math.asin(math.clamp(lookVector.Y, -1, 1)) * number("ChasePitchFollow", 0.5, 0, 1), 3, dt)

	-- Distance: configured state blends, pull-back under acceleration, push-in under braking.
	accelBlend = lerp(accelBlend, accelerating and 1 or 0, responseAlpha(number("AccelerationBlendSmoothing", 4.5, 0.1, 30), dt))
	boostBlend = lerp(boostBlend, boosting and 1 or 0, responseAlpha(number("BoostBlendSmoothing", 6.5, 0.1, 30), dt))
	local high = smoothstep(number("HighSpeedStartMph", 70, 0, 500), number("HighSpeedFullMph", 180, 1, 600), speed)
	local targetDistance = lerp(number("DefaultDistanceStuds", 29, 2, 150), number("AccelerationDistanceStuds", 30, 2, 150), accelBlend)
	targetDistance = lerp(targetDistance, number("HighSpeedDistanceStuds", 34, 2, 150), high)
	targetDistance = lerp(targetDistance, number("BoostDistanceStuds", 37, 2, 150), boostBlend)
	currentDistance = currentDistance and lerp(currentDistance, targetDistance, responseAlpha(number("DistanceSmoothing", 7, 0.1, 30), dt)) or targetDistance
	if not finite(currentDistance) then currentDistance = number("DefaultDistanceStuds", 29, 2, 150) end
	local rawAcceleration = chase.ForwardSpeed and math.clamp((forwardSpeed - chase.ForwardSpeed) / dt, -600, 600) or 0
	chase.ForwardSpeed = forwardSpeed
	chase.Acceleration, chase.AccelerationVelocity = critical(chase.Acceleration, chase.AccelerationVelocity, rawAcceleration, 8, dt)
	local lagLimit = number("ChaseAccelLagMaxStuds", 3, 0, 12)
	local lagTarget = math.clamp(chase.Acceleration * number("ChaseAccelLagStudsPerAccel", 0.045, 0, 0.5), -lagLimit, lagLimit)
	chase.Lag, chase.LagVelocity = critical(chase.Lag, chase.LagVelocity, lagTarget, 4.5, dt)

	-- Field of view: configured state blends plus a boost punch; the dolly offsets part of the widening.
	local defaultFov = number("DefaultFieldOfView", 80, 40, 120)
	local targetFov = lerp(defaultFov, number("AccelerationFieldOfView", 83, 40, 120), accelBlend)
	targetFov = lerp(targetFov, number("HighSpeedFieldOfView", 90, 40, 120), high)
	targetFov = lerp(targetFov, number("BoostFieldOfView", 96, 40, 120), boostBlend)
	currentFov = currentFov and lerp(currentFov, targetFov, responseAlpha(number("FieldOfViewSmoothing", 6, 0.1, 30), dt)) or targetFov
	if not finite(currentFov) then currentFov = defaultFov end
	chase.Punch, chase.PunchVelocity = critical(chase.Punch, chase.PunchVelocity, 0, 6, dt)
	local fov = math.clamp(currentFov + chase.Punch, 40, 120)
	CameraService.SetFieldOfView("DrivingCamera", fov, 100)
	local dolly = (math.tan(math.rad(defaultFov) * 0.5) / math.tan(math.rad(fov) * 0.5)) ^ number("ChaseFovDollyExponent", 0.25, 0, 1)

	-- Shake: impulses ring out through two oscillators; boost and high speed add a small continuous buffet.
	chase.KickPitch, chase.KickPitchVelocity = damped(chase.KickPitch, chase.KickPitchVelocity, 55, 0.3, dt)
	chase.KickRoll, chase.KickRollVelocity = damped(chase.KickRoll, chase.KickRollVelocity, 55, 0.3, dt)
	chase.Bump, chase.BumpVelocity = damped(chase.Bump, chase.BumpVelocity, 30, 0.5, dt)
	local shake = number("ChaseShakeScale", 1, 0, 4)
	local buffet = high * shake
	local rumble = boostBlend * shake * math.sin(chase.Time * 2 * math.pi * 23) * math.rad(0.08)
	local buffetY = math.noise(chase.Time * 4.2, 11.5) * 0.035 * buffet
	local buffetRoll = math.noise(chase.Time * 4.2, 47.25) * math.rad(0.05) * buffet + rumble

	-- Pose: pivot above the car (XZ locked to it), lens on an orbit behind, aim ahead of the car.
	updateLook(dt)
	local pivotHeight = number("ChasePivotHeightStuds", 2.5, -5, 20)
	local lensHeight = number("ChaseHeightStuds", 6.5, -5, 40) - pivotHeight
	local distance = math.max((currentDistance + chase.Lag) * dolly, 2)
	local elevation = math.clamp(math.atan2(lensHeight, distance) - chase.Pitch + look.Pitch, math.rad(-12), math.rad(75))
	local reach = math.sqrt(distance * distance + lensHeight * lensHeight)
	local viewYaw = chase.Yaw + look.Yaw
	local pivot = Vector3.new(position.X, chase.Y + pivotHeight, position.Z)
	local offset = -yawDirection(viewYaw) * (math.cos(elevation) * reach) + Vector3.new(0, math.sin(elevation) * reach, 0)
	local viewRight = Vector3.new(math.cos(viewYaw), 0, -math.sin(viewYaw))
	local sideShift = viewRight * chase.Shift

	-- Occlusion: snap in, ease out, never closer than the minimum.
	local clear = occlusionFraction(vehicle, pivot, offset + sideShift * 0.6)
	local minimum = math.clamp(number("ChaseMinDistanceStuds", 8, 1, 60) / reach, 0, 1)
	clear = math.max(clear, minimum)
	if clear < chase.Occlusion then
		chase.Occlusion = clear
	else
		chase.Occlusion = math.min(clear, lerp(chase.Occlusion, 1, responseAlpha(4, dt)))
	end
	local lens = pivot + (offset + sideShift * 0.6) * chase.Occlusion + Vector3.new(0, chase.Bump + buffetY, 0)
	local aim = Vector3.new(position.X, chase.Y + number("ChaseAimHeightStuds", 3.2, -5, 30), position.Z)
		+ yawDirection(viewYaw + chase.LookAhead) * number("ChaseAimAheadStuds", 12, 0, 60) + sideShift
	if (aim - lens).Magnitude < 0.1 then return end
	local result = CFrame.lookAt(lens, aim) * CFrame.Angles(chase.KickPitch, 0, chase.KickRoll + buffetRoll + chase.Roll)

	-- Getting in: blend from wherever the camera was.
	if chase.EntryCFrame then
		chase.EntryTime += dt
		local blendSeconds = number("ChaseEntryBlendSeconds", 0.7, 0, 3)
		if blendSeconds <= 0 or chase.EntryTime >= blendSeconds or (chase.EntryCFrame.Position - lens).Magnitude > 250 then
			chase.EntryCFrame = nil
		else
			result = chase.EntryCFrame:Lerp(result, smoothstep(0, 1, chase.EntryTime / blendSeconds))
		end
	end
	if not finiteVector(result.Position) or not finiteVector(result.LookVector) then
		-- A non-finite value has entered a spring; start the solver again from the car rather than freezing.
		resetChase(root, nil)
		return
	end
	cam.CFrame = result
	cam.Focus = CFrame.new(pivot)
	updateSpeedLines(dt, speed, boostBlend)
	publishDebug(cam, speed, targetDistance, targetFov)
end

-- Shared lifecycle ---------------------------------------------------------------------------------------------

local function suspend()
	if not active or suspended then return end
	suspended = true
	restoreZoom()
	releaseMouse()
	if speedLines then speedLines.Shown = 0; speedLines.Gui.Enabled = false end
	CameraService.ClearFieldOfView("DrivingCamera") -- trailer tools own FOV while suspended
	if ownedCamera and ownedCamera.Parent then
		ownedCamera:SetAttribute("DrivingCameraManaged", nil)
		ownedCamera:SetAttribute("DrivingCameraOwner", nil)
	end
end
local function resume()
	if not active or not suspended then return end
	suspended = false
	local cam = camera()
	if cam then
		ownedCamera = cam
		if chaseMode then
			local root = context and context.Vehicle and context.Vehicle.PrimaryPart
			if root then resetChase(root, cam) end
			resetLook()
			takeScriptedCamera(cam)
		else
			takeDefaultCamera(cam)
			queueInitialLook()
		end
	end
end
-- The trailer cameras are a Studio-only opt-in tool. The chase camera gives way to them only when they are on;
-- otherwise P, C and V would drop a player out of the chase camera for no reason.
local function trailerToolsEnabled()
	if not RunService:IsStudio() then return false end
	local development = ReplicatedStorage:FindFirstChild("Config") and ReplicatedStorage.Config:FindFirstChild("Development")
	local tools = development and development:FindFirstChild("ClientTools")
	return tools ~= nil and tools:GetAttribute("TrailerVehicleCameraEnabled") == true
end
local function connectCompatibilityKeys()
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard or not flag("RespectTrailerCameraKeys", true) then return end
		if chaseMode and not trailerToolsEnabled() then return end
		if input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.V then
			suspend()
		elseif input.KeyCode == Enum.KeyCode.B then
			resume()
		end
	end))
	local folder = resolveFolder()
	if folder then
		for _, name in ipairs({"ApplyInitialLookAngle", "DefaultPitchDegrees", "DefaultYawDegrees", "DefaultHeightStuds", "LookAheadStuds", "LookTargetHeightStuds", "InitialLookApplyFrames"}) do
			table.insert(connections, folder:GetAttributeChangedSignal(name):Connect(queueInitialLook))
		end
	end
end
local function update(dt)
	if not active or suspended or not context then return end
	refreshConfig(false)
	if not flag("Enabled", true) then Controller.Stop(); return end
	local vehicle = context.Vehicle
	local root = vehicle and vehicle.Parent and vehicle.PrimaryPart
	if not root then return end
	if switch("ScriptedChaseEnabled", true) then Controller.Start(context); return end
	local cam = camera()
	local player = Players.LocalPlayer
	if not cam or not player then return end
	ownedCamera = cam
	if cam.CameraType ~= Enum.CameraType.Custom or cam.CameraSubject ~= subject then takeDefaultCamera(cam) end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude * MPH_PER_STUD
	if not finite(speed) then speed = 0 end
	local accelerating = context.IsAccelerating and context.IsAccelerating() or false
	local boosting = context.IsBoosting and context.IsBoosting() or false
	accelBlend = lerp(accelBlend, accelerating and 1 or 0, responseAlpha(number("AccelerationBlendSmoothing", 4.5, 0.1, 30), dt))
	boostBlend = lerp(boostBlend, boosting and 1 or 0, responseAlpha(number("BoostBlendSmoothing", 6.5, 0.1, 30), dt))
	local high = smoothstep(number("HighSpeedStartMph", 70, 0, 500), number("HighSpeedFullMph", 180, 1, 600), speed)

	local targetDistance = lerp(number("DefaultDistanceStuds", 29, 2, 150), number("AccelerationDistanceStuds", 30, 2, 150), accelBlend)
	targetDistance = lerp(targetDistance, number("HighSpeedDistanceStuds", 34, 2, 150), high)
	targetDistance = lerp(targetDistance, number("BoostDistanceStuds", 37, 2, 150), boostBlend)
	currentDistance = currentDistance and lerp(currentDistance, targetDistance, responseAlpha(number("DistanceSmoothing", 7, 0.1, 30), dt)) or targetDistance
	if not finite(currentDistance) then currentDistance = finite(targetDistance) and targetDistance or number("DefaultDistanceStuds", 29, 2, 150) end
	if flag("LockPlayerZoom", true) then
		setLockedDistance(player, currentDistance)
		zoomIsLocked = true
	elseif zoomIsLocked then
		restoreZoom()
	end

	local targetFov = lerp(number("DefaultFieldOfView", 80, 40, 120), number("AccelerationFieldOfView", 83, 40, 120), accelBlend)
	targetFov = lerp(targetFov, number("HighSpeedFieldOfView", 90, 40, 120), high)
	targetFov = lerp(targetFov, number("BoostFieldOfView", 96, 40, 120), boostBlend)
	currentFov = currentFov and lerp(currentFov, targetFov, responseAlpha(number("FieldOfViewSmoothing", 6, 0.1, 30), dt)) or targetFov
	if not finite(currentFov) then currentFov = finite(targetFov) and targetFov or number("DefaultFieldOfView", 80, 40, 120) end
	CameraService.SetFieldOfView("DrivingCamera", currentFov, 100)

	publishDebug(cam, speed, targetDistance, targetFov)
end

function Controller.Start(newContext)
	Controller.Stop()
	refreshConfig(true)
	if not flag("Enabled", true) or typeof(newContext) ~= "table" or not newContext.Vehicle then return end
	context = newContext
	local cam = camera()
	local player = Players.LocalPlayer
	if not cam or not player then context = nil; return end
	subject = resolveSubject(newContext.Vehicle)
	if not subject then context = nil; warn("[Default Vehicle Camera] No DriverSeat or Humanoid subject found"); return end
	previousType, previousSubject, previousFov = cam.CameraType, cam.CameraSubject, cam.FieldOfView
	previousMinZoom, previousMaxZoom = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	if not (finite(previousMinZoom) and finite(previousMaxZoom) and previousMinZoom <= previousMaxZoom) then
		local starter = game:GetService("StarterPlayer")
		previousMinZoom, previousMaxZoom = starter.CameraMinZoomDistance, starter.CameraMaxZoomDistance
	end
	-- Restarting inside a session (mode switch) must not record this controller's own camera type as the one to restore.
	if previousType == Enum.CameraType.Scriptable then previousType = Enum.CameraType.Custom end
	ownedCamera = cam
	active, suspended = true, false
	currentDistance, currentFov, accelBlend, boostBlend = nil, nil, 0, 0
	initialLookFrames, debugWasEnabled, zoomIsLocked = 0, false, false
	local root = newContext.Vehicle.PrimaryPart
	chaseMode = switch("ScriptedChaseEnabled", true) and root ~= nil
	connectCompatibilityKeys()
	if chaseMode then
		resetChase(root, cam)
		resetLook()
		takeScriptedCamera(cam)
		connectChaseInput()
		buildSpeedLines()
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, updateChase)
	else
		takeDefaultCamera(cam)
		queueInitialLook()
		RunService:BindToRenderStep(INITIAL_RENDER_NAME, Enum.RenderPriority.Camera.Value - 1, updateInitialLook)
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, update)
	end
end

function Controller.Stop()
	if active then
		if not chaseMode then RunService:UnbindFromRenderStep(INITIAL_RENDER_NAME) end
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	restoreZoom()
	releaseMouse()
	destroySpeedLines()
	CameraService.ClearFieldOfView("DrivingCamera")
	if ownedCamera and ownedCamera.Parent then
		local owner = ownedCamera:GetAttribute("DrivingCameraOwner")
		local wasOwner = owner == OWNER or owner == CHASE_OWNER
		ownedCamera:SetAttribute("DrivingCameraManaged", nil)
		ownedCamera:SetAttribute("DrivingCameraOwner", nil)
		clearDebug(ownedCamera)
		if wasOwner then
			if previousType then ownedCamera.CameraType = previousType end
			if previousSubject and previousSubject.Parent then ownedCamera.CameraSubject = previousSubject end
		end
	end
	active, suspended, context, ownedCamera, subject = false, false, nil, nil, nil
	previousType, previousSubject, previousFov, previousMinZoom, previousMaxZoom = nil, nil, nil, nil, nil
	currentDistance, currentFov, accelBlend, boostBlend = nil, nil, nil, nil
	initialLookFrames, debugWasEnabled, zoomIsLocked = 0, false, false
	chaseMode, chase, look = false, nil, nil
end

return Controller
