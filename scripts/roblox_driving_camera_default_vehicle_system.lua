-- Neo Tokyo Racers - Roblox-owned default vehicle camera replacement V6
-- Run once in Studio Command Bar in Edit mode. No backups are created.
-- Replaces only the isolated DrivingCameraController ModuleScript.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before installing the default vehicle camera")

local PREFIX = "[NTR Default Vehicle Camera]"
local MODULE_NAME = "DrivingCameraController"
local OLD_MARKER = "NTR_DRIVING_CAMERA_SINGLE_OWNER_V1"
local V4_MARKER = "NTR_DRIVING_CAMERA_SMOOTHNESS_OWNERSHIP_V4"
local V5_MARKER = "NTR_DRIVING_CAMERA_RENDER_ANCHOR_V5"
local NEW_MARKER = "NTR_DRIVING_CAMERA_DEFAULT_VEHICLE_V6"
local FRAMING_MARKER = "NTR_DRIVING_CAMERA_INITIAL_FRAMING_V6_1"
local function info(message) print(PREFIX .. " " .. message) end
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
local module = controllers:WaitForChild(MODULE_NAME)
assert(module:IsA("ModuleScript"), module:GetFullName() .. " must be a ModuleScript")

local moduleSource = [==[-- NTR_DRIVING_CAMERA_DEFAULT_VEHICLE_V6
-- NTR_DRIVING_CAMERA_INITIAL_FRAMING_V6_1
-- Roblox owns Camera.CFrame, collision, orbit, and platform input.
-- This controller only selects the seat, locks a smooth distance, changes FOV, and applies one initial look angle.
local Controller = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RENDER_NAME = "NTR_DefaultVehicleCameraV6"
local INITIAL_RENDER_NAME = "NTR_DefaultVehicleCameraInitialFramingV6"
local OWNER = "DefaultVehicleCameraV6"
local MPH_PER_STUD = 0.625

local active, suspended, context, ownedCamera, subject = false, false, nil, nil, nil
local connections = {}
local previousType, previousSubject, previousFov, previousMinZoom, previousMaxZoom
local currentDistance, currentFov, accelBlend, boostBlend
local configFolder, configValues, nextConfigRefresh = nil, {}, 0
local initialLookFrames, debugWasEnabled, zoomIsLocked = 0, false, false

local function resolveFolder()
	if configFolder and configFolder.Parent then return configFolder end
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local config = kit and kit:FindFirstChild("Config")
	local runtime = config and config:FindFirstChild("Runtime")
	local result = runtime and runtime:FindFirstChild("DrivingCamera_Default_EditAttributes")
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
local function setLockedDistance(player, distance)
	distance = math.clamp(distance, 0.5, 400)
	if distance >= player.CameraMaxZoomDistance then
		player.CameraMaxZoomDistance = distance
		player.CameraMinZoomDistance = distance
	else
		player.CameraMinZoomDistance = distance
		player.CameraMaxZoomDistance = distance
	end
end
local function restoreZoom()
	local player = Players.LocalPlayer
	if not player or previousMinZoom == nil or previousMaxZoom == nil then return end
	if previousMinZoom <= player.CameraMaxZoomDistance then
		player.CameraMinZoomDistance = previousMinZoom
		player.CameraMaxZoomDistance = previousMaxZoom
	else
		player.CameraMaxZoomDistance = previousMaxZoom
		player.CameraMinZoomDistance = previousMinZoom
	end
	zoomIsLocked = false
end
local function clearDebug(cam)
	for _, name in ipairs({"NTRCameraMode", "NTRCameraSpeedMph", "NTRCameraTargetDistance", "NTRCameraCurrentDistance", "NTRCameraTargetFov", "NTRCameraCurrentFov"}) do
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
	cam:SetAttribute("NTRCameraMode", OWNER)
	cam:SetAttribute("NTRCameraSpeedMph", speed)
	cam:SetAttribute("NTRCameraTargetDistance", targetDistance)
	cam:SetAttribute("NTRCameraCurrentDistance", currentDistance)
	cam:SetAttribute("NTRCameraTargetFov", targetFov)
	cam:SetAttribute("NTRCameraCurrentFov", currentFov)
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
	cam:SetAttribute("NTRDrivingCameraManaged", true)
	cam:SetAttribute("NTRDrivingCameraOwner", OWNER)
	cam.CameraType = Enum.CameraType.Custom
	if subject and subject.Parent then cam.CameraSubject = subject end
end
local function suspend()
	if not active or suspended then return end
	suspended = true
	restoreZoom()
	if ownedCamera and ownedCamera.Parent then
		ownedCamera:SetAttribute("NTRDrivingCameraManaged", nil)
		ownedCamera:SetAttribute("NTRDrivingCameraOwner", nil)
	end
end
local function resume()
	if not active or not suspended then return end
	suspended = false
	local cam = camera()
	if cam then
		ownedCamera = cam
		takeDefaultCamera(cam)
		queueInitialLook()
	end
end
local function connectCompatibilityKeys()
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard or not flag("RespectTrailerCameraKeys", true) then return end
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
	local cam = camera()
	local player = Players.LocalPlayer
	if not cam or not player then return end
	ownedCamera = cam
	if cam.CameraType ~= Enum.CameraType.Custom or cam.CameraSubject ~= subject then takeDefaultCamera(cam) end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude * MPH_PER_STUD
	local accelerating = context.IsAccelerating and context.IsAccelerating() or false
	local boosting = context.IsBoosting and context.IsBoosting() or false
	accelBlend = lerp(accelBlend, accelerating and 1 or 0, responseAlpha(number("AccelerationBlendSmoothing", 4.5, 0.1, 30), dt))
	boostBlend = lerp(boostBlend, boosting and 1 or 0, responseAlpha(number("BoostBlendSmoothing", 6.5, 0.1, 30), dt))
	local high = smoothstep(number("HighSpeedStartMph", 70, 0, 500), number("HighSpeedFullMph", 180, 1, 600), speed)

	local targetDistance = lerp(number("DefaultDistanceStuds", 29, 2, 150), number("AccelerationDistanceStuds", 30, 2, 150), accelBlend)
	targetDistance = lerp(targetDistance, number("HighSpeedDistanceStuds", 34, 2, 150), high)
	targetDistance = lerp(targetDistance, number("BoostDistanceStuds", 37, 2, 150), boostBlend)
	currentDistance = currentDistance and lerp(currentDistance, targetDistance, responseAlpha(number("DistanceSmoothing", 7, 0.1, 30), dt)) or targetDistance
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
	cam.FieldOfView = currentFov

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
	if not subject then context = nil; warn("[NTR Default Vehicle Camera] No DriverSeat or Humanoid subject found"); return end
	previousType, previousSubject, previousFov = cam.CameraType, cam.CameraSubject, cam.FieldOfView
	previousMinZoom, previousMaxZoom = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	ownedCamera = cam
	active, suspended = true, false
	currentDistance, currentFov, accelBlend, boostBlend = nil, nil, 0, 0
	initialLookFrames, debugWasEnabled, zoomIsLocked = 0, false, false
	takeDefaultCamera(cam)
	connectCompatibilityKeys()
	queueInitialLook()
	RunService:BindToRenderStep(INITIAL_RENDER_NAME, Enum.RenderPriority.Camera.Value - 1, updateInitialLook)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, update)
end

function Controller.Stop()
	if active then
		RunService:UnbindFromRenderStep(INITIAL_RENDER_NAME)
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	restoreZoom()
	if ownedCamera and ownedCamera.Parent then
		local wasOwner = ownedCamera:GetAttribute("NTRDrivingCameraOwner") == OWNER
		ownedCamera:SetAttribute("NTRDrivingCameraManaged", nil)
		ownedCamera:SetAttribute("NTRDrivingCameraOwner", nil)
		clearDebug(ownedCamera)
		if wasOwner then
			if previousType then ownedCamera.CameraType = previousType end
			if previousSubject and previousSubject.Parent then ownedCamera.CameraSubject = previousSubject end
			if previousFov then ownedCamera.FieldOfView = previousFov end
		end
	end
	active, suspended, context, ownedCamera, subject = false, false, nil, nil, nil
	previousType, previousSubject, previousFov, previousMinZoom, previousMaxZoom = nil, nil, nil, nil, nil
	currentDistance, currentFov, accelBlend, boostBlend = nil, nil, nil, nil
	initialLookFrames, debugWasEnabled, zoomIsLocked = 0, false, false
end

return Controller
]==]

local current = module.Source
local currentLength, currentHash = normalisedHash(current)
if not string.find(current, NEW_MARKER, 1, true) then
	assert(string.find(current, OLD_MARKER, 1, true), "Existing camera module is not the expected isolated NTR controller")
	local isConfirmedV4 = string.find(current, V4_MARKER, 1, true) and currentLength == 18357 and currentHash == 1252247011
	local isGeneratedV5 = string.find(current, V5_MARKER, 1, true) and currentLength == 22165 and currentHash == 1737080285
	assert(isConfirmedV4 or isGeneratedV5,
		"Camera source differs from the confirmed V4 and generated V5 sources (length/hash " .. currentLength .. "/" .. currentHash .. "); refresh the mirror before replacing it")
	info(isConfirmedV4 and "PASS - Confirmed mirrored V4 source fingerprint." or "PASS - Confirmed generated V5 source fingerprint.")
else
	local isInstalledV6 = not string.find(current, FRAMING_MARKER, 1, true) and currentLength == 11569 and currentHash == 1053091569
	local isInstalledV61 = string.find(current, FRAMING_MARKER, 1, true) and currentLength == 12611 and currentHash == 581983456
	assert(isInstalledV6 or isInstalledV61,
		"Installed V6 camera source was manually changed (length/hash " .. currentLength .. "/" .. currentHash .. "); refusing to overwrite it")
	info(isInstalledV61 and "PASS - Initial Framing V6.1 is already installed; preserving its source." or "PASS - Confirmed mirrored V6 source fingerprint for V6.1 upgrade.")
end

local testModule = Instance.new("ModuleScript")
testModule.Name = "__NTR_DefaultVehicleCameraCompileCheck"
testModule.Source = moduleSource
testModule.Parent = controllers
local ok, result = pcall(require, testModule)
testModule:Destroy()
assert(ok and typeof(result) == "table" and typeof(result.Start) == "function" and typeof(result.Stop) == "function",
	"Default vehicle camera compile check failed: " .. tostring(result))
info("PASS - Replacement module compiled successfully.")

local legacy = runtime:FindFirstChild("DrivingCamera_EditAttributes")
assert(legacy == nil or legacy:IsA("Folder"), "DrivingCamera_EditAttributes must be a Folder when present")
local legacyAttributes = legacy and legacy:GetAttributes() or {}
local config = ensureFolder(runtime, "DrivingCamera_Default_EditAttributes")
local existingAttributes = config:GetAttributes()
local definitions = {
	{"Enabled", true, "Turns the default vehicle camera controller on."},
	{"LockPlayerZoom", true, "Prevents the player changing camera distance while driving."},
	{"ApplyInitialLookAngle", true, "Applies the configured look angle once when driving starts; Roblox owns the camera afterward."},
	{"InitialLookApplyFrames", 3, "Applies framing across more initialization frames so Roblox reliably adopts the configured angle; this is not continuous driving control."},
	{"DefaultDistanceStuds", 29, "Moves the normal camera farther from the vehicle."},
	{"AccelerationDistanceStuds", 30, "Moves the camera farther back while accelerating."},
	{"HighSpeedDistanceStuds", 34, "Moves the camera farther back at high speed."},
	{"BoostDistanceStuds", 37, "Moves the camera farther back during boost."},
	{"DefaultFieldOfView", 80, "Widens the normal driving view."},
	{"AccelerationFieldOfView", 83, "Widens the view while accelerating."},
	{"HighSpeedFieldOfView", 90, "Widens the view at high speed."},
	{"BoostFieldOfView", 96, "Widens the view during boost."},
	{"HighSpeedStartMph", 70, "Makes high-speed camera effects begin at a higher speed."},
	{"HighSpeedFullMph", 180, "Makes high-speed camera effects reach full strength at a higher speed."},
	{"DistanceSmoothing", 7, "Makes distance changes respond faster."},
	{"FieldOfViewSmoothing", 6, "Makes FOV changes respond faster."},
	{"AccelerationBlendSmoothing", 4.5, "Makes acceleration camera effects engage and release faster."},
	{"BoostBlendSmoothing", 6.5, "Makes boost camera effects engage and release faster."},
	{"DefaultPitchDegrees", 0, "Raises the initial camera position and makes it look down more steeply."},
	{"DefaultYawDegrees", 0, "Rotates the initial camera position farther around the vehicle."},
	{"DefaultHeightStuds", 7.25, "Raises the initial camera position above the vehicle."},
	{"LookAheadStuds", 8, "Moves the initial look target farther ahead of the vehicle."},
	{"LookTargetHeightStuds", 2.5, "Raises the initial point the camera looks toward."},
	{"ConfigRefreshSeconds", 0.25, "Waits longer before live config edits are reread."},
	{"RespectTrailerCameraKeys", true, "Lets P, C, and V release this controller until B resumes it."},
	{"DebugEnabled", false, "Publishes simple live camera diagnostics on Workspace.CurrentCamera."},
}

local copied, preserved = 0, 0
for _, item in ipairs(definitions) do
	local name, fallback, description = item[1], item[2], item[3]
	local existing = config:GetAttribute(name)
	if existing == nil then
		local legacyValue = legacy and legacy:GetAttribute(name)
		if legacyValue ~= nil and typeof(legacyValue) == typeof(fallback) then
			config:SetAttribute(name, legacyValue)
			copied += 1
		else
			config:SetAttribute(name, fallback)
		end
	else
		assert(typeof(existing) == typeof(fallback), name .. " has the wrong type")
		preserved += 1
	end
	local descriptionName = typeof(fallback) == "number" and name .. "_RaisingThisDoes" or name .. "_Description"
	if config:GetAttribute(descriptionName) == nil then config:SetAttribute(descriptionName, description) end
end
for name, value in pairs(existingAttributes) do
	assert(config:GetAttribute(name) == value, "Existing default camera config changed unexpectedly: " .. name)
end
config:SetAttribute("ApplyInitialLookAngle_Description", "Applies configured framing briefly on entry and after framing edits, then returns full camera ownership to Roblox.")
config:SetAttribute("ConfigVersion", "DRIVING_CAMERA_DEFAULT_VEHICLE_V6_1")
config:SetAttribute("ConfigNote", "Roblox owns continuous motion, collision and orbit. V6.1 applies initial framing for only InitialLookApplyFrames frames.")

module.Source = moduleSource
assert(string.find(module.Source, NEW_MARKER, 1, true), "Replacement camera marker missing after install")
assert(string.find(module.Source, FRAMING_MARKER, 1, true), "Initial framing repair marker missing after install")
if legacy then
	for name, value in pairs(legacyAttributes) do
		assert(legacy:GetAttribute(name) == value, "Legacy camera config changed unexpectedly: " .. name)
	end
end
info("PASS - Installed the Roblox-owned default vehicle camera Initial Framing V6.1 repair.")
info("PASS - Preserved " .. preserved .. " existing V6 values and copied " .. copied .. " compatible values from the legacy camera folder.")
info("The old DrivingCamera_EditAttributes folder remains untouched for rollback history and is no longer read.")
info("Start Play, spawn a vehicle, then test launch, high speed, boost, orbit, wall collision, zoom lock, and exit restoration.")
