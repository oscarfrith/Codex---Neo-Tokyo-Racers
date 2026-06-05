local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("HOVER_RACING_V2_KIT")
local templates = kit:WaitForChild("VFX_TEMPLATES", 10)
local controllerModule
pcall(function()
	controllerModule = require(kit:WaitForChild("CLIENT_MODULES"):WaitForChild("VFX"):WaitForChild("VehicleVFXController"))
end)

local previewController
local previewVehicle
local lastPass = 0
local controls
local controlsDisabled = false

task.defer(function()
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
	if not playerModule then return end
	local ok, module = pcall(require, playerModule)
	if ok and module and module.GetControls then
		controls = module:GetControls()
	end
end)

local function requestLandscape()
	pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
	pcall(function() playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
end

local function garageOpen()
	local gui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return gui and gui.Enabled
end

local function driveOpen()
	local hud = playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	return hud and hud.Enabled
end

local function setRobloxTouchControls(enabled)
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = enabled
	end
	if controls then
		if enabled and controlsDisabled then
			controlsDisabled = false
			pcall(function() controls:Enable() end)
		elseif not enabled and not controlsDisabled then
			controlsDisabled = true
			pcall(function() controls:Disable() end)
		end
	end
end

local function getPlayerVehicle()
	local world = Workspace:FindFirstChild("HOVER_RACING_V2_WORLD")
	local root = world and world:FindFirstChild("PLAYER_VEHICLES_Runtime")
	if not root then return nil end
	for _, vehicle in ipairs(root:GetChildren()) do
		if vehicle:GetAttribute("OwnerUserId") == player.UserId then
			return vehicle
		end
	end
end

local function getPreviewRoot()
	return Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
end

local function getPreviewVehicle(root)
	if not root then return nil end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Model") then return child end
	end
end

local function hasChannel(object, channel)
	local current = object
	while current do
		if current:GetAttribute("PaintChannel") == channel then return true end
		if channel == "ThrustColor" and string.find(string.lower(current.Name), "thrust_color", 1, true) then return true end
		current = current.Parent
	end
	return false
end

local function isThrustFire(object)
	local lower = string.lower(object.Name)
	return string.find(lower, "booston_fire", 1, true)
		or string.find(lower, "engineoff_fire", 1, true)
		or string.find(lower, "engineon_fire", 1, true)
		or string.find(lower, "stabiliseron_fire", 1, true)
		or string.find(lower, "stabilizeron_fire", 1, true)
end

local function applyFireColour(object, color)
	if object:IsA("ParticleEmitter") then
		object.Color = ColorSequence.new(color)
	elseif object:IsA("Fire") then
		object.Color = color
		object.SecondaryColor = color
	elseif object:IsA("Smoke") then
		object.Color = color
	elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
		object.Color = color
	end
end

local function applyThrustOnly(root, color, forceEnabled)
	if not root then return end
	for _, object in ipairs(root:GetDescendants()) do
		if object:IsA("BasePart") and hasChannel(object, "ThrustColor") then
			object.Color = color
			object.Material = Enum.Material.Neon
			object.Transparency = 0
		elseif isThrustFire(object) then
			applyFireColour(object, color)
			if forceEnabled ~= nil then
				pcall(function() object.Enabled = forceEnabled end)
			end
		end
	end
end

local function updatePreviewVFX(root, dt)
	local force = root and root:GetAttribute("ForceThrustPreview") == true
	local vehicle = force and getPreviewVehicle(root) or nil
	if not force or not vehicle or not controllerModule or not templates then
		if previewController then
			previewController:Destroy()
			previewController = nil
			previewVehicle = nil
		end
		return
	end
	local thrust = root:GetAttribute("ThrustColor") or Color3.fromRGB(255, 255, 255)
	vehicle:SetAttribute("ThrustColor", thrust)
	if previewVehicle ~= vehicle then
		if previewController then previewController:Destroy() end
		previewVehicle = vehicle
		previewController = controllerModule.Attach(vehicle, templates, UserInputService.TouchEnabled)
	end
	if previewController then
		previewController:Update(dt, {
			Throttle = 1,
			Boost = 1,
			Drift = 1,
			DriftLeft = 1,
			DriftRight = 1,
			HoverDust = 0,
			Brake = 0,
		})
	end
end

local function forceDriveCamera()
	if not driveOpen() then return end
	local vehicle = getPlayerVehicle()
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	local camera = Workspace.CurrentCamera
	if camera and seat and seat:IsA("VehicleSeat") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = seat
	end
end

requestLandscape()
RunService.RenderStepped:Connect(function(dt)
	requestLandscape()
	if UserInputService.TouchEnabled then
		setRobloxTouchControls(not garageOpen() and not driveOpen())
	end
	forceDriveCamera()

	local now = os.clock()
	if now - lastPass < 0.05 then return end
	lastPass = now

	local preview = getPreviewRoot()
	if preview then
		local thrust = preview:GetAttribute("ThrustColor") or Color3.fromRGB(255, 255, 255)
		local force = preview:GetAttribute("ForceThrustPreview") == true
		updatePreviewVFX(preview, dt)
		applyThrustOnly(preview, thrust, force and true or nil)
	end

	local vehicle = getPlayerVehicle()
	if vehicle then
		local thrust = vehicle:GetAttribute("ThrustColor") or Color3.fromRGB(255, 255, 255)
		applyThrustOnly(vehicle, thrust, nil)
	end
end)
