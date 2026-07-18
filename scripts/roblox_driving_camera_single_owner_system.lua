-- Neo Tokyo Racers - single-owner configurable driving camera / Render Anchor V5
-- Run once in Studio Command Bar in Edit mode. No backups are created.
-- Exact fingerprints/anchors guard the installed V4 module and retained compatibility paths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
assert(not RunService:IsRunning(), "Stop Play before installing the driving camera system")

local PREFIX = "[NTR Driving Camera]"
local MODULE_NAME = "DrivingCameraController"
local MODULE_MARKER = "NTR_DRIVING_CAMERA_SINGLE_OWNER_V1"
local BRIDGE_MARKER = "NTR_DRIVING_CAMERA_SINGLE_OWNER_BRIDGE"
local GUARD_MARKER = "NTR_DRIVING_CAMERA_SINGLE_OWNER_DEFAULT_GUARD"
local ZOOM_MARKER = "NTR_DRIVING_CAMERA_MANUAL_ZOOM_TOGGLE_V1"
local ORBIT_MARKER = "NTR_DRIVING_CAMERA_PC_ORBIT_INVERT_V2"
local CONTROL_MARKER = "NTR_DRIVING_CAMERA_MOUSE_CAPTURE_FILTERED_COLLISION_V3"
local SMOOTHNESS_MARKER = "NTR_DRIVING_CAMERA_SMOOTHNESS_OWNERSHIP_V4"
local RENDER_ANCHOR_MARKER = "NTR_DRIVING_CAMERA_RENDER_ANCHOR_V5"
local PREVIEW_GUARD_MARKER = "NTR_DRIVING_CAMERA_THRUST_PREVIEW_GUARD_V4"
local function info(message) print(PREFIX .. " " .. message) end
local function countPlain(source, needle)
	local count, position = 0, 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1; position = found + #needle
	end
end
local function normalisedHash(source)
	source = string.gsub(source, "\r\n", "\n")
	local hash = 0
	for index = 1, #source do hash = (hash * 131 + string.byte(source, index)) % 2147483647 end
	return #source, hash
end
local function ensureFolder(parent, name)
	local child = parent:FindFirstChild(name)
	if child then assert(child:IsA("Folder"), child:GetFullName() .. " must be a Folder")
	else child = Instance.new("Folder"); child.Name = name; child.Parent = parent end
	return child
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local runtime = kit:WaitForChild("Config"):WaitForChild("Runtime")
local controllers = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers")
local driving = controllers:WaitForChild("DrivingControllerV47")
assert(driving:IsA("ModuleScript"), "DrivingControllerV47 must be a ModuleScript")
local previewController = StarterPlayer:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Preview")
	:WaitForChild("ThrustPreviewController_Active")
assert(previewController:IsA("LocalScript"), "ThrustPreviewController_Active must be a LocalScript")

local bridgeSource = [==[-- NTR_DRIVING_CAMERA_SINGLE_OWNER_BRIDGE
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

]==]

local defaultCameraOld = [==[local function setVehicleCamera(vehicle)
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
end]==]

local defaultCameraNew = [==[-- NTR_DRIVING_CAMERA_SINGLE_OWNER_DEFAULT_GUARD
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
end]==]

local previewCameraOld = [==[local function forceDriveCamera()
	if not driveOpen() then return end
	local vehicle = getPlayerVehicle()
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	local camera = Workspace.CurrentCamera
	if camera and seat and seat:IsA("VehicleSeat") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = seat
	end
end]==]

local previewCameraNew = [==[-- NTR_DRIVING_CAMERA_THRUST_PREVIEW_GUARD_V4
local function forceDriveCamera()
	if not driveOpen() then return end
	local camera = Workspace.CurrentCamera
	if camera and camera:GetAttribute("NTRDrivingCameraManaged") == true then return end
	local vehicle = getPlayerVehicle()
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	if camera and seat and seat:IsA("VehicleSeat") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = seat
	end
end]==]

local moduleSource = [==[-- NTR_DRIVING_CAMERA_SINGLE_OWNER_V1
-- NTR_DRIVING_CAMERA_MANUAL_ZOOM_TOGGLE_V1
-- NTR_DRIVING_CAMERA_PC_ORBIT_INVERT_V2
-- NTR_DRIVING_CAMERA_MOUSE_CAPTURE_FILTERED_COLLISION_V3
-- NTR_DRIVING_CAMERA_SMOOTHNESS_OWNERSHIP_V4
-- NTR_DRIVING_CAMERA_RENDER_ANCHOR_V5
local Controller = {}
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RENDER_NAME, OWNER, MPH_PER_STUD = "NTR_DrivingCameraSingleOwner", "DrivingCameraControllerV1", 0.625

local active, suspended, context, ownedCamera = false, false, nil, nil
local connections, mouseHeld, touchInput = {}, false, nil
local previousMouseBehavior, previousMouseIconEnabled
local lastMouseDelta = Vector2.zero
local yaw, pitch, manualDistance, lastInput = 0, 0, 0, 0
local accelBlend, boostBlend = 0, 0
local currentPosition, currentLook, currentDistance, currentFov
local previousType, previousSubject, previousFov
local configFolder, configValues, nextConfigRefresh = nil, {}, 0
local nextDebugUpdate, debugWasEnabled, ownershipCorrections = 0, false, 0
local nextCollisionSample, collisionAllowedDistance, collisionHitPath, lastCollisionHit = 0, nil, "", 0
local collisionRaycastsLastSample = 0
local poseConnection, poseAFrame, poseBFrame, poseATime, poseBTime
local poseAVelocity, poseBVelocity = Vector3.zero, Vector3.zero
local renderAnchorPosition, poseSnapPending, poseSnapCount = nil, false, 0
local renderAnchorMode, renderAnchorSampleAgeMs = "Physics", 0
local rayParams = RaycastParams.new()
rayParams.FilterType, rayParams.IgnoreWater = Enum.RaycastFilterType.Exclude, true

local function resolveFolder()
	if configFolder and configFolder.Parent then return configFolder end
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local config = kit and kit:FindFirstChild("Config")
	local runtime = config and config:FindFirstChild("Runtime")
	local result = runtime and runtime:FindFirstChild("DrivingCamera_EditAttributes")
	configFolder = result and result:IsA("Folder") and result or nil
	return configFolder
end
local function refreshConfig(force)
	local now = os.clock()
	if not force and now < nextConfigRefresh then return end
	local config = resolveFolder()
	configValues = config and config:GetAttributes() or {}
	local interval = configValues.ConfigRefreshSeconds
	if typeof(interval) ~= "number" then interval = 0.25 end
	nextConfigRefresh = now + math.clamp(interval, 0.05, 2)
end
local function num(name, fallback, minimum, maximum)
	local value = configValues[name]
	if typeof(value) ~= "number" then value = fallback end
	if minimum ~= nil and maximum ~= nil then value = math.clamp(value, minimum, maximum) end
	return value
end
local function flag(name, fallback)
	local value = configValues[name]
	return typeof(value) == "boolean" and value or fallback
end
local function alpha(rate, dt) return 1 - math.exp(-math.max(rate, 0) * math.max(dt, 0)) end
local function lerp(a, b, t) return a + (b - a) * math.clamp(t, 0, 1) end
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
local function clearPoseBuffer()
	if poseConnection then poseConnection:Disconnect(); poseConnection = nil end
	poseAFrame, poseBFrame, poseATime, poseBTime = nil, nil, nil, nil
	poseAVelocity, poseBVelocity = Vector3.zero, Vector3.zero
	renderAnchorPosition, poseSnapPending = nil, false
	renderAnchorMode, renderAnchorSampleAgeMs = "Physics", 0
end
local function capturePose(force)
	local vehicle = context and context.Vehicle
	local root = vehicle and vehicle.Parent and vehicle.PrimaryPart
	if not root then return end
	local now, frame, velocity = os.clock(), root.CFrame, root.AssemblyLinearVelocity
	local movedFar = poseBFrame and (frame.Position - poseBFrame.Position).Magnitude >= num("RenderAnchorTeleportSnapStuds", 30, 1, 1000)
	local turnedFar = poseBFrame and math.deg(math.acos(math.clamp(frame.LookVector:Dot(poseBFrame.LookVector), -1, 1))) >= num("RenderAnchorRotationSnapDegrees", 100, 10, 180)
	local teleported = movedFar or turnedFar
	if force or not poseBFrame or teleported then
		poseAFrame, poseBFrame, poseATime, poseBTime = frame, frame, now, now
		poseAVelocity, poseBVelocity = velocity, velocity
		if teleported and not force then poseSnapPending = true; poseSnapCount += 1 end
	else
		poseAFrame, poseATime, poseAVelocity = poseBFrame, poseBTime, poseBVelocity
		poseBFrame, poseBTime, poseBVelocity = frame, now, velocity
	end
end
local function renderPose(root)
	if not flag("RenderAnchorEnabled", true) then
		renderAnchorMode, renderAnchorSampleAgeMs = "Physics", 0
		return root.CFrame, root.AssemblyLinearVelocity, false
	end
	if not poseBFrame then capturePose(true) end
	if not poseBFrame then
		renderAnchorMode, renderAnchorSampleAgeMs = "PhysicsFallback", 0
		return root.CFrame, root.AssemblyLinearVelocity, false
	end
	local now = os.clock()
	renderAnchorSampleAgeMs = math.max(now - poseBTime, 0) * 1000
	local targetTime = now - num("RenderAnchorInterpolationDelaySeconds", 1 / 60, 0, 0.1)
	local span = poseBTime - poseATime
	if span > 0 and targetTime <= poseBTime then
		local blend = math.clamp((targetTime - poseATime) / span, 0, 1)
		renderAnchorMode = "BufferedInterpolation"
		return poseAFrame:Lerp(poseBFrame, blend), poseAVelocity:Lerp(poseBVelocity, blend), true
	end
	local ahead = math.clamp(targetTime - poseBTime, 0, num("RenderAnchorMaxExtrapolationSeconds", 0.025, 0, 0.1))
	renderAnchorMode = ahead > 0 and "BoundedExtrapolation" or "LatestPhysicsPose"
	return poseBFrame + poseBVelocity * ahead, poseBVelocity, true
end
local function releaseMouse()
	if previousMouseBehavior ~= nil then UserInputService.MouseBehavior = previousMouseBehavior end
	if previousMouseIconEnabled ~= nil then UserInputService.MouseIconEnabled = previousMouseIconEnabled end
	previousMouseBehavior, previousMouseIconEnabled, mouseHeld = nil, nil, false
end
local function disconnectInputs()
	releaseMouse()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections); touchInput = nil
end
local function markInput() lastInput = os.clock() end
local function clampPitch()
	local minimum, maximum = num("MinimumPitchDegrees", -20, -80, 80), num("MaximumPitchDegrees", 35, -80, 80)
	if maximum < minimum then minimum, maximum = maximum, minimum end
	pitch = math.clamp(pitch, minimum, maximum)
end
local function orbit(dx, dy, scale)
	if not flag("ManualOrbitEnabled", true) then return end
	local sensitivity = num("MouseSensitivityDegreesPerPixel", 0.18, 0.01, 2) * scale
	local verticalDirection = flag("InvertVerticalOrbit", true) and 1 or -1
	yaw -= math.rad(dx * sensitivity); pitch += dy * sensitivity * verticalDirection; clampPitch(); markInput()
end
local function connectInputs()
	disconnectInputs()
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if flag("RespectTrailerCameraKeys", true) and input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.V then
				suspended = true; releaseMouse()
				local cam = camera(); if cam and cam:GetAttribute("NTRDrivingCameraOwner") == OWNER then cam:SetAttribute("NTRDrivingCameraOwner", nil) end
				return
			elseif input.KeyCode == Enum.KeyCode.B then suspended = false; currentPosition, currentLook, renderAnchorPosition = nil, nil, nil; return end
		end
		if suspended then return end
		-- Roblox can mark right mouse as processed before a Scriptable camera sees it.
		-- Capture the button first so PC orbit does not depend on that flag.
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if flag("ManualOrbitEnabled", true) and not mouseHeld then
				previousMouseBehavior, previousMouseIconEnabled = UserInputService.MouseBehavior, UserInputService.MouseIconEnabled
				mouseHeld = true
				if flag("LockMouseDuringOrbit", true) then UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end
				if flag("HideMouseDuringOrbit", true) then UserInputService.MouseIconEnabled = false end
				markInput()
			end
			return
		end
		if processed or not flag("ManualOrbitEnabled", true) then return end
		if input.UserInputType == Enum.UserInputType.Touch then
			local cam = camera(); local height = cam and cam.ViewportSize.Y or 0
			if height <= 0 or input.Position.Y <= height * 0.58 then touchInput = input; markInput() end
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input, processed)
		if suspended then return end
		if processed then return end
		if input.UserInputType == Enum.UserInputType.Touch and input == touchInput then orbit(input.Delta.X, input.Delta.Y, num("TouchSensitivityMultiplier", 0.65, 0.05, 3))
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and flag("ManualZoomEnabled", false) then manualDistance -= input.Position.Z * num("ZoomStepStuds", 2.5, 0.1, 20); markInput() end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then releaseMouse(); markInput()
		elseif input.UserInputType == Enum.UserInputType.Touch and input == touchInput then touchInput = nil; markInput() end
	end))
end
local function mouseOrbit()
	if not mouseHeld then lastMouseDelta = Vector2.zero; return end
	if not flag("ManualOrbitEnabled", true) then releaseMouse(); return end
	if flag("LockMouseDuringOrbit", true) then UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end
	if flag("HideMouseDuringOrbit", true) then UserInputService.MouseIconEnabled = false end
	local delta = UserInputService:GetMouseDelta()
	lastMouseDelta = delta
	if delta.Magnitude > 0 then orbit(delta.X, delta.Y, 1) end
end
local function gamepad(dt)
	if not UserInputService.GamepadEnabled or not flag("ManualOrbitEnabled", true) then return end
	local stick = Vector2.zero
	for _, input in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then stick = Vector2.new(input.Position.X, input.Position.Y); break end
	end
	if stick.Magnitude <= 0.14 then return end
	local degrees = num("GamepadOrbitDegreesPerSecond", 110, 10, 360)
	local verticalDirection = flag("InvertVerticalOrbit", true) and -1 or 1
	yaw -= stick.X * math.rad(degrees) * dt; pitch += stick.Y * degrees * dt * verticalDirection; clampPitch(); markInput()
end
local DEBUG_ATTRIBUTES = {"NTRCameraSpeedMph","NTRCameraTargetFov","NTRCameraCurrentFov","NTRCameraTargetDistance","NTRCameraCollisionActive","NTRCameraCollisionHit","NTRCameraMouseHeld","NTRCameraMouseDelta","NTRCameraFrameDeltaMs","NTRCameraRaycastsLastSample","NTRCameraOwnershipCorrections","NTRCameraRenderAnchorMode","NTRCameraRenderAnchorSampleAgeMs","NTRCameraRenderAnchorSnapCount"}
local function clearDebug(cam)
	for _, name in ipairs(DEBUG_ATTRIBUTES) do cam:SetAttribute(name, nil) end
end
local function debug(cam, dt, speed, targetFov, targetDistance, collision, collisionHit)
	local enabled = flag("DebugEnabled", false)
	if not enabled then
		if debugWasEnabled then clearDebug(cam) end
		debugWasEnabled = false
		return
	end
	debugWasEnabled = true
	local now = os.clock()
	if now < nextDebugUpdate then return end
	nextDebugUpdate = now + num("DebugUpdateIntervalSeconds", 0.25, 0.05, 2)
	if enabled then
		cam:SetAttribute("NTRCameraSpeedMph", speed); cam:SetAttribute("NTRCameraTargetFov", targetFov)
		cam:SetAttribute("NTRCameraCurrentFov", currentFov); cam:SetAttribute("NTRCameraTargetDistance", targetDistance)
		cam:SetAttribute("NTRCameraCollisionActive", collision)
		cam:SetAttribute("NTRCameraCollisionHit", collisionHit)
		cam:SetAttribute("NTRCameraMouseHeld", mouseHeld)
		cam:SetAttribute("NTRCameraMouseDelta", lastMouseDelta.Magnitude)
		cam:SetAttribute("NTRCameraFrameDeltaMs", dt * 1000)
		cam:SetAttribute("NTRCameraRaycastsLastSample", collisionRaycastsLastSample)
		cam:SetAttribute("NTRCameraOwnershipCorrections", ownershipCorrections)
		cam:SetAttribute("NTRCameraRenderAnchorMode", renderAnchorMode)
		cam:SetAttribute("NTRCameraRenderAnchorSampleAgeMs", renderAnchorSampleAgeMs)
		cam:SetAttribute("NTRCameraRenderAnchorSnapCount", poseSnapCount)
	end
end
local function validCollision(instance)
	if not instance then return false end
	if instance == Workspace.Terrain then return true end
	if not instance:IsA("BasePart") then return false end
	if instance:GetAttribute("CameraCollisionIgnore") == true or CollectionService:HasTag(instance, "NTR_CameraCollisionIgnore") then return false end
	if flag("CollisionRequireCanCollide", true) and not instance.CanCollide then return false end
	if instance.Transparency >= num("CollisionIgnoreTransparencyAtOrAbove", 0.95, 0, 1) then return false end
	return true
end
local function update(dt)
	if not active or suspended or not context then return end
	refreshConfig(false)
	if not flag("Enabled", true) then Controller.Stop(); return end
	local vehicle = context.Vehicle; local root = vehicle and vehicle.Parent and vehicle.PrimaryPart
	if not root then return end
	local cam = camera(); if not cam then return end
	ownedCamera = cam
	if cam.CameraType ~= Enum.CameraType.Scriptable then ownershipCorrections += 1; cam.CameraType = Enum.CameraType.Scriptable end
	if cam:GetAttribute("NTRDrivingCameraOwner") ~= OWNER then ownershipCorrections += 1; cam:SetAttribute("NTRDrivingCameraOwner", OWNER) end
	mouseOrbit()
	gamepad(dt)
	local anchorFrame, anchorVelocity, anchorEnabled = renderPose(root)
	if poseSnapPending then
		currentPosition, currentLook, renderAnchorPosition, poseSnapPending = nil, nil, nil, false
	end
	if anchorEnabled then
		local anchorPosition = anchorFrame.Position
		if renderAnchorPosition then
			local carry = anchorPosition - renderAnchorPosition
			if currentPosition then currentPosition += carry end
			if currentLook then currentLook += carry end
		end
		renderAnchorPosition = anchorPosition
	else
		renderAnchorPosition = nil
	end
	local velocity = anchorVelocity; local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = planarVelocity.Magnitude * MPH_PER_STUD
	local flatForward = Vector3.new(anchorFrame.LookVector.X, 0, anchorFrame.LookVector.Z)
	if flatForward.Magnitude < 0.05 then return end; flatForward = flatForward.Unit
	local accelerating = context.IsAccelerating and context.IsAccelerating() or false
	local boosting = context.IsBoosting and context.IsBoosting() or false
	accelBlend = lerp(accelBlend, accelerating and 1 or 0, alpha(num("AccelerationBlendSmoothing", 4.5, 0.1, 30), dt))
	boostBlend = lerp(boostBlend, boosting and 1 or 0, alpha(num("BoostBlendSmoothing", 6.5, 0.1, 30), dt))
	local high = smoothstep(num("HighSpeedStartMph", 70, 0, 500), num("HighSpeedFullMph", 180, 1, 600), speed)
	local targetFov = lerp(num("DefaultFieldOfView", 80, 40, 120), num("AccelerationFieldOfView", 83, 40, 120), accelBlend)
	targetFov = lerp(targetFov, num("HighSpeedFieldOfView", 90, 40, 120), high)
	targetFov = lerp(targetFov, num("BoostFieldOfView", 96, 40, 120), boostBlend)
	local minFov, maxFov = num("MinimumFieldOfView", 50, 35, 120), num("MaximumFieldOfView", 110, 40, 120)
	if maxFov < minFov then minFov, maxFov = maxFov, minFov end
	targetFov = math.clamp(targetFov, minFov, maxFov)
	currentFov = currentFov and lerp(currentFov, targetFov, alpha(num("FieldOfViewSmoothing", 6, 0.1, 30), dt)) or targetFov; cam.FieldOfView = currentFov
	if not flag("ManualZoomEnabled", false) then manualDistance = 0 end
	local defaultDistance = num("DefaultDistanceStuds", 29, 4, 150)
	local targetDistance = lerp(defaultDistance, num("AccelerationDistanceStuds", 30, 4, 150), accelBlend)
	targetDistance = lerp(targetDistance, num("HighSpeedDistanceStuds", 34, 4, 150), high)
	targetDistance = lerp(targetDistance, num("BoostDistanceStuds", 37, 4, 150), boostBlend)
	local minDistance, maxDistance = num("MinimumDistanceStuds", 16, 2, 150), num("MaximumDistanceStuds", 55, 3, 200)
	if maxDistance < minDistance then minDistance, maxDistance = maxDistance, minDistance end
	manualDistance = math.clamp(manualDistance, minDistance - defaultDistance, maxDistance - defaultDistance)
	targetDistance = math.clamp(targetDistance + manualDistance, minDistance, maxDistance)
	currentDistance = currentDistance and lerp(currentDistance, targetDistance, alpha(num("DistanceSmoothing", 7, 0.1, 30), dt)) or targetDistance
	if speed > 3 and os.clock() - lastInput > num("RecenterDelaySeconds", 1.15, 0, 10) then
		local t = alpha(num("RecenterSpeed", 2.15, 0.05, 20), dt)
		yaw, pitch = lerp(yaw, 0, t), lerp(pitch, num("DefaultPitchDegrees", 0, -60, 60), t)
	end
	local orbitForward = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(flatForward)
	local predicted = anchorFrame.Position + planarVelocity * num("VelocityLookAheadSeconds", 0.12, 0, 1)
	local height = num("DefaultHeightStuds", 7.25, 1, 40) + math.tan(math.rad(pitch)) * currentDistance
	local lookTarget = predicted + flatForward * num("LookAheadStuds", 8, -20, 50) + Vector3.new(0, num("LookTargetHeightStuds", 2.5, -10, 30), 0)
	local desired = predicted - orbitForward * currentDistance + Vector3.new(0, height, 0)
	local collision = false
	if flag("CollisionEnabled", true) then
		local origin = predicted + Vector3.new(0, num("CollisionOriginHeightStuds", 2.5, -5, 20), 0); local direction = desired - origin
		local now = os.clock()
		if now >= nextCollisionSample and direction.Magnitude > 0.1 then
			nextCollisionSample = now + 1 / num("CollisionSampleRateHz", 30, 10, 120)
			collisionRaycastsLastSample = 0
			local exclusions = {vehicle}; local char = character(); if char then table.insert(exclusions, char) end
			local accepted
			for _ = 1, math.floor(num("CollisionMaxIgnoredHits", 12, 1, 40)) do
				rayParams.FilterDescendantsInstances = exclusions
				local result = Workspace:Raycast(origin, direction, rayParams)
				collisionRaycastsLastSample += 1
				if not result then break end
				if validCollision(result.Instance) then accepted = result; break end
				table.insert(exclusions, result.Instance)
			end
			if accepted then
				collisionAllowedDistance = math.max(accepted.Distance - num("CollisionPaddingStuds", 0.75, 0, 5), 1.5)
				collisionHitPath = flag("DebugEnabled", false) and accepted.Instance:GetFullName() or ""
				lastCollisionHit = now
			elseif now - lastCollisionHit >= num("CollisionReleaseDelaySeconds", 0.12, 0, 1) then
				collisionAllowedDistance, collisionHitPath = nil, ""
			end
		end
		if collisionAllowedDistance and direction.Magnitude > 0.1 then
			desired = origin + direction.Unit * math.min(direction.Magnitude, collisionAllowedDistance)
			collision = collisionAllowedDistance < direction.Magnitude
		end
	else
		collisionAllowedDistance, collisionHitPath = nil, ""
	end
	local rate = collision and num("CollisionInwardSmoothing", 25, 1, 80) or num("PositionSmoothing", 10, 0.1, 40)
	currentPosition = currentPosition and currentPosition:Lerp(desired, alpha(rate, dt)) or desired
	currentLook = currentLook and currentLook:Lerp(lookTarget, alpha(num("RotationSmoothing", 8, 0.1, 40), dt)) or lookTarget
	if (currentLook - currentPosition).Magnitude > 0.05 then cam.CFrame = CFrame.lookAt(currentPosition, currentLook) end
	cam.Focus = CFrame.new(lookTarget)
	debug(cam, dt, speed, targetFov, targetDistance, collision, collisionHitPath)
end

function Controller.Start(newContext)
	Controller.Stop(); refreshConfig(true); if not flag("Enabled", true) or typeof(newContext) ~= "table" or not newContext.Vehicle then return end
	context = newContext; local cam = camera(); if not cam then context = nil; return end
	previousType, previousSubject, previousFov, ownedCamera = cam.CameraType, cam.CameraSubject, cam.FieldOfView, cam
	cam.CameraType = Enum.CameraType.Scriptable; cam:SetAttribute("NTRDrivingCameraManaged", true); cam:SetAttribute("NTRDrivingCameraOwner", OWNER)
	active, suspended, yaw, manualDistance, accelBlend, boostBlend = true, false, 0, 0, 0, 0
	pitch = num("DefaultPitchDegrees", 0, -60, 60); currentPosition, currentLook, currentDistance, currentFov = nil, nil, nil, nil
	lastInput = os.clock() - num("RecenterDelaySeconds", 1.15, 0, 10)
	nextDebugUpdate, debugWasEnabled, ownershipCorrections = 0, false, 0
	nextCollisionSample, collisionAllowedDistance, collisionHitPath, lastCollisionHit = 0, nil, "", 0
	collisionRaycastsLastSample, poseSnapCount = 0, 0
	capturePose(true); poseConnection = RunService.PostSimulation:Connect(function() capturePose(false) end)
	connectInputs()
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, update)
end
function Controller.Stop()
	if active then RunService:UnbindFromRenderStep(RENDER_NAME) end; disconnectInputs()
	clearPoseBuffer()
	if ownedCamera and ownedCamera.Parent then
		local wasOwner = ownedCamera:GetAttribute("NTRDrivingCameraOwner") == OWNER
		ownedCamera:SetAttribute("NTRDrivingCameraManaged", nil); ownedCamera:SetAttribute("NTRDrivingCameraOwner", nil); clearDebug(ownedCamera)
		if wasOwner then
			if previousType then ownedCamera.CameraType = previousType end
			if previousSubject and previousSubject.Parent then ownedCamera.CameraSubject = previousSubject end
			if previousFov then ownedCamera.FieldOfView = previousFov end
		end
	end
	active, suspended, context, ownedCamera = false, false, nil, nil
	previousType, previousSubject, previousFov = nil, nil, nil
	currentPosition, currentLook, currentDistance, currentFov = nil, nil, nil, nil
end
return Controller]==]

local existingModule = controllers:FindFirstChild(MODULE_NAME)
local bridgeInstalled = string.find(driving.Source, BRIDGE_MARKER, 1, true) ~= nil
local guardInstalled = string.find(driving.Source, GUARD_MARKER, 1, true) ~= nil
local moduleInstalled = existingModule and existingModule:IsA("ModuleScript") and string.find(existingModule.Source, MODULE_MARKER, 1, true) ~= nil
local zoomInstalled = moduleInstalled and string.find(existingModule.Source, ZOOM_MARKER, 1, true) ~= nil
local orbitInstalled = moduleInstalled and string.find(existingModule.Source, ORBIT_MARKER, 1, true) ~= nil
local controlInstalled = moduleInstalled and string.find(existingModule.Source, CONTROL_MARKER, 1, true) ~= nil
local smoothnessInstalled = moduleInstalled and string.find(existingModule.Source, SMOOTHNESS_MARKER, 1, true) ~= nil
local renderAnchorInstalled = moduleInstalled and string.find(existingModule.Source, RENDER_ANCHOR_MARKER, 1, true) ~= nil
local previewGuardInstalled = string.find(previewController.Source, PREVIEW_GUARD_MARKER, 1, true) ~= nil
local moduleNeedsUpgrade = moduleInstalled and not renderAnchorInstalled
assert(not existingModule or existingModule:IsA("ModuleScript"), MODULE_NAME .. " must be a ModuleScript")
assert(bridgeInstalled == (moduleInstalled == true), "Partial camera install detected; refresh the mirror and inspect before repair")
assert(bridgeInstalled == guardInstalled, "Partial default-camera guard detected; refresh the mirror and inspect before repair")
if orbitInstalled then assert(zoomInstalled, "PC orbit marker exists without the required zoom-toggle baseline") end
if controlInstalled then assert(orbitInstalled, "Mouse/collision V3 marker exists without the required orbit baseline") end
if smoothnessInstalled then assert(controlInstalled, "Smoothness V4 marker exists without the required V3 baseline") end
if renderAnchorInstalled then assert(smoothnessInstalled, "Render Anchor V5 marker exists without the required V4 baseline") end

if moduleNeedsUpgrade then
	local length, hash = normalisedHash(existingModule.Source)
	local originalV1 = length == 12702 and hash == 580073451
	local zoomV1 = length == 12852 and hash == 1013575364
	local orbitV2 = length == 13337 and hash == 563871801
	local controlV3 = length == 15809 and hash == 1313655054
	local smoothnessV4 = length == 18357 and hash == 1252247011
	assert(originalV1 or zoomV1 or orbitV2 or controlV3 or smoothnessV4,
		"Installed camera module differs from all canonical pre-V5 sources; refusing to overwrite it (length/hash " .. length .. "/" .. hash .. ")")
	local sourceName = smoothnessV4 and "Smoothness V4" or (controlV3 and "mouse/collision V3" or (orbitV2 and "PC-orbit V2" or (zoomV1 and "zoom-lock V1" or "original V1")))
	info("PASS - Existing camera module exactly matches the canonical " .. sourceName .. " source.")
end

local patchedPreview
if previewGuardInstalled then
	info("PASS - Thrust preview already respects the driving-camera owner.")
else
	assert(countPlain(previewController.Source, previewCameraOld) == 1,
		"Thrust preview camera function differs from the refreshed mirror; refusing fragile replacement")
	local first, last = string.find(previewController.Source, previewCameraOld, 1, true)
	patchedPreview = string.sub(previewController.Source, 1, first - 1) .. previewCameraNew .. string.sub(previewController.Source, last + 1)
	assert(countPlain(patchedPreview, PREVIEW_GUARD_MARKER) == 1, "Generated thrust-preview guard marker missing")
	info("PASS - Exact thrust-preview camera ownership conflict preflighted.")
end

local patchedDriving
if bridgeInstalled then
	info("PASS - Camera module and bridge already installed; preserving their live source.")
else
	assert(not existingModule, MODULE_NAME .. " already exists without the canonical marker")
	local startMarker, endMarker = "local function updateCameraAssist(dt)", "local function updateHoverWobble(dt"
	assert(countPlain(driving.Source, startMarker) == 1 and countPlain(driving.Source, endMarker) == 1, "V74 camera source markers are not unique")
	local first = assert(string.find(driving.Source, startMarker, 1, true))
	local blockEnd = assert(string.find(driving.Source, endMarker, first, true))
	local oldBlock = string.sub(driving.Source, first, blockEnd - 1)
	local length, hash = normalisedHash(oldBlock)
	assert(length == 4576 and hash == 1850554201,
		"Confirmed V74 camera block differs from the refreshed mirror (length/hash " .. length .. "/" .. hash .. ")")
	patchedDriving = string.sub(driving.Source, 1, first - 1) .. bridgeSource .. string.sub(driving.Source, blockEnd)
	assert(countPlain(patchedDriving, defaultCameraOld) == 1, "Default camera heartbeat anchor differs from the refreshed mirror")
	local guardFirst, guardLast = string.find(patchedDriving, defaultCameraOld, 1, true)
	patchedDriving = string.sub(patchedDriving, 1, guardFirst - 1) .. defaultCameraNew .. string.sub(patchedDriving, guardLast + 1)
	assert(string.find(patchedDriving, BRIDGE_MARKER, 1, true), "Generated bridge marker missing")
	assert(string.find(patchedDriving, GUARD_MARKER, 1, true), "Generated default-camera guard marker missing")
	info("PASS - Exact V74 block and default-camera heartbeat guard preflighted together.")
end

if not moduleInstalled or moduleNeedsUpgrade then
	local testModule = Instance.new("ModuleScript"); testModule.Name = "__NTR_DrivingCameraCompileCheck"; testModule.Source = moduleSource; testModule.Parent = controllers
	local ok, result = pcall(require, testModule); testModule:Destroy()
	assert(ok and typeof(result) == "table" and typeof(result.Start) == "function" and typeof(result.Stop) == "function", "Camera module compile check failed: " .. tostring(result))
	info("PASS - Isolated camera module compiled successfully.")
end

local config = ensureFolder(runtime, "DrivingCamera_EditAttributes")
local originalConfigAttributes = config:GetAttributes()
local definitions = {
	{"Enabled",true,"Turns this camera on; false uses the Roblox default camera."},
	{"DefaultDistanceStuds",29,"Moves the normal camera farther from the car."},{"MinimumDistanceStuds",16,"Raises the closest allowed zoom."},{"MaximumDistanceStuds",55,"Raises the farthest allowed zoom."},
	{"DefaultHeightStuds",7.25,"Raises the camera above the car."},{"LookAheadStuds",8,"Looks farther along the road."},{"LookTargetHeightStuds",2.5,"Raises the point the camera looks at."},
	{"DefaultFieldOfView",80,"Widens normal driving view."},{"AccelerationFieldOfView",83,"Widens view while accelerating."},{"HighSpeedFieldOfView",90,"Widens view at high speed."},{"BoostFieldOfView",96,"Widens view during boost."},
	{"MinimumFieldOfView",50,"Raises the narrowest allowed FOV."},{"MaximumFieldOfView",110,"Raises the widest allowed FOV."},{"HighSpeedStartMph",70,"Starts high-speed camera changes later."},{"HighSpeedFullMph",180,"Finishes high-speed camera changes later."},
	{"AccelerationDistanceStuds",30,"Moves the camera farther back while accelerating."},{"HighSpeedDistanceStuds",34,"Moves it farther back at high speed."},{"BoostDistanceStuds",37,"Moves it farther back during boost."},
	{"PositionSmoothing",10,"Makes position respond faster."},{"RotationSmoothing",8,"Makes aiming respond faster."},{"FieldOfViewSmoothing",6,"Makes FOV respond faster."},{"DistanceSmoothing",7,"Makes distance respond faster."},{"ConfigRefreshSeconds",0.25,"Waits longer before live camera config edits are reread; lower values update edits faster."},
	{"RenderAnchorInterpolationDelaySeconds",1/60,"Adds more buffered pose delay for extra smoothness; higher values also add camera latency."},{"RenderAnchorMaxExtrapolationSeconds",0.025,"Allows the render anchor to predict farther when a physics sample arrives late."},{"RenderAnchorTeleportSnapStuds",30,"Requires a larger one-step movement before the camera treats it as a teleport and snaps cleanly."},{"RenderAnchorRotationSnapDegrees",100,"Requires a larger one-step rotation before the camera treats it as a reset and snaps cleanly."},
	{"AccelerationBlendSmoothing",4.5,"Makes acceleration effects engage faster."},{"BoostBlendSmoothing",6.5,"Makes boost effects engage faster."},{"VelocityLookAheadSeconds",0.12,"Predicts farther along vehicle movement."},
	{"RecenterDelaySeconds",1.15,"Waits longer before recentring."},{"RecenterSpeed",2.15,"Recentres faster."},{"CollisionPaddingStuds",0.75,"Keeps farther from detected walls."},{"CollisionOriginHeightStuds",2.5,"Raises the collision ray origin."},{"CollisionInwardSmoothing",25,"Pulls inward from walls faster."},{"CollisionIgnoreTransparencyAtOrAbove",0.95,"Makes more semi-transparent parts count as camera blockers."},{"CollisionMaxIgnoredHits",12,"Allows the ray to skip more invalid trigger or LOD parts."},{"CollisionSampleRateHz",30,"Checks for camera obstructions more often; higher values cost more per second."},{"CollisionReleaseDelaySeconds",0.12,"Holds a detected obstruction longer before letting the camera move back out, reducing edge flicker."},
	{"MouseSensitivityDegreesPerPixel",0.18,"Makes mouse orbit more sensitive."},{"TouchSensitivityMultiplier",0.65,"Makes touch orbit more sensitive."},{"GamepadOrbitDegreesPerSecond",110,"Makes right-stick orbit faster."},{"ZoomStepStuds",2.5,"Changes distance more per wheel step."},
	{"MinimumPitchDegrees",-20,"Allows farther downward orbit."},{"MaximumPitchDegrees",35,"Allows farther upward orbit."},{"DefaultPitchDegrees",0,"Raises default orbit pitch."},
	{"CollisionEnabled",true,"Moves the camera in front of walls."},{"CollisionRequireCanCollide",true,"Ignores non-collidable trigger and visual parts when true."},{"RenderAnchorEnabled",true,"Uses buffered render-space vehicle motion; false restores the V4 direct physics-pose camera path."},{"ManualOrbitEnabled",true,"Allows mouse, touch, and gamepad orbit."},{"LockMouseDuringOrbit",true,"Locks the PC cursor while right mouse is held so movement is captured reliably."},{"HideMouseDuringOrbit",true,"Hides the PC cursor while right mouse orbit is held."},{"InvertVerticalOrbit",true,"Inverts look up/down for mouse, touch, and gamepad when true."},{"ManualZoomEnabled",false,"Allows player mouse-wheel zoom when true; false locks distance to the configured camera stages."},{"RespectTrailerCameraKeys",true,"Lets P/C/V suspend this camera until B."},{"DebugEnabled",false,"Shows throttled live camera diagnostics on CurrentCamera when true."},{"DebugUpdateIntervalSeconds",0.25,"Waits longer between debug Attribute updates; higher values reduce diagnostic overhead."},
}
local preserved = 0
for _, item in ipairs(definitions) do
	local name, fallback, description = item[1], item[2], item[3]; local old = config:GetAttribute(name)
	if old == nil then config:SetAttribute(name, fallback) else assert(typeof(old) == typeof(fallback), name .. " has the wrong type"); preserved += 1 end
	local descriptionName = typeof(fallback) == "number" and name .. "_RaisingThisDoes" or name .. "_Description"
	if config:GetAttribute(descriptionName) == nil then config:SetAttribute(descriptionName, description) end
end
for name, value in pairs(originalConfigAttributes) do
	assert(config:GetAttribute(name) == value, "Existing camera config changed unexpectedly: " .. name)
end
config:SetAttribute("ConfigVersion", "DRIVING_CAMERA_RENDER_ANCHOR_V5")
config:SetAttribute("ConfigNote", "Edit values in this one Folder; paired descriptions explain their effects.")

if not bridgeInstalled then
	local module = Instance.new("ModuleScript"); module.Name = MODULE_NAME; module.Source = moduleSource; module.Parent = controllers
	driving.Source = patchedDriving; existingModule = module
elseif moduleNeedsUpgrade then
	existingModule.Source = moduleSource
end
if patchedPreview then previewController.Source = patchedPreview end
assert(existingModule and string.find(existingModule.Source, MODULE_MARKER, 1, true), "Camera module marker missing")
assert(string.find(existingModule.Source, ZOOM_MARKER, 1, true), "Manual zoom toggle marker missing")
assert(string.find(existingModule.Source, ORBIT_MARKER, 1, true), "PC orbit/invert marker missing")
assert(string.find(existingModule.Source, CONTROL_MARKER, 1, true), "Mouse capture/filtered collision marker missing")
assert(string.find(existingModule.Source, SMOOTHNESS_MARKER, 1, true), "Smoothness/ownership V4 marker missing")
assert(string.find(existingModule.Source, RENDER_ANCHOR_MARKER, 1, true), "Render Anchor V5 marker missing")
assert(string.find(driving.Source, BRIDGE_MARKER, 1, true), "Camera bridge marker missing")
assert(string.find(driving.Source, GUARD_MARKER, 1, true), "Default-camera guard marker missing")
assert(string.find(previewController.Source, PREVIEW_GUARD_MARKER, 1, true), "Thrust-preview ownership guard missing")
info("PASS - Installed Camera Render Anchor V5 with buffered post-physics interpolation and anchor-relative translation carry.")
info("PASS - Verified " .. #definitions .. " flat described settings; preserved " .. preserved .. " existing values.")
info("Start Play, spawn a vehicle, and inspect Workspace.CurrentCamera Attributes while testing.")
