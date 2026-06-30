-- StarterPlayer > StarterPlayerScripts > TrailerVehicleCamera.client.lua
-- C = side view
-- V = reverse/front-facing view
-- B = normal camera

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SIDE_VIEW_KEY = Enum.KeyCode.C
local REVERSE_VIEW_KEY = Enum.KeyCode.V
local NORMAL_VIEW_KEY = Enum.KeyCode.B

local activeMode = "Normal"
local renderConnection = nil

-- Tweak these for your hovercraft/trailer shots
local SIDE_SETTINGS = {
	FieldOfView = 70,

	-- Negative = left side, positive = right side
	SideOffset = -28,

	-- Positive = behind vehicle, negative = ahead of vehicle
	BackOffset = 6,

	HeightOffset = 7,

	-- How far ahead of the vehicle the camera looks
	LookAhead = 18,

	LookHeight = 4,

	-- Higher = snappier, lower = smoother
	Smoothness = 8,
}

local REVERSE_SETTINGS = {
	FieldOfView = 70,

	-- Camera sits in front of the vehicle
	FrontOffset = 32,

	HeightOffset = 7,

	-- Aim slightly behind the vehicle so you see the front/side nicely
	LookBack = 8,

	LookHeight = 4,

	Smoothness = 8,
}

local currentCameraCFrame = nil

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getVehicleRoot()
	local character = getCharacter()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid or not humanoid.SeatPart then
		return nil
	end

	local seat = humanoid.SeatPart
	local vehicle = seat:FindFirstAncestorOfClass("Model")

	if not vehicle then
		return seat
	end

	-- Best option if your vehicle has PrimaryPart set
	if vehicle.PrimaryPart then
		return vehicle.PrimaryPart
	end

	-- Fallback names you may have in your hovercraft model
	local root =
		vehicle:FindFirstChild("VehicleRoot", true)
		or vehicle:FindFirstChild("Chassis", true)
		or vehicle:FindFirstChild("Main", true)
		or vehicle:FindFirstChild("Body", true)
		or seat

	return root
end

local function disconnectRender()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function returnToNormalCamera()
	activeMode = "Normal"
	disconnectRender()

	camera.CameraType = Enum.CameraType.Custom

	local character = getCharacter()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		camera.CameraSubject = humanoid
	end

	currentCameraCFrame = nil
end

local function setTrailerCameraMode(mode)
	disconnectRender()

	activeMode = mode
	camera.CameraType = Enum.CameraType.Scriptable

	currentCameraCFrame = camera.CFrame

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local vehicleRoot = getVehicleRoot()

		if not vehicleRoot then
			returnToNormalCamera()
			return
		end

		local vehicleCF = vehicleRoot.CFrame
		local desiredCFrame

		if activeMode == "Side" then
			local settings = SIDE_SETTINGS
			camera.FieldOfView = settings.FieldOfView

			local cameraPosition =
				vehicleCF.Position
				+ vehicleCF.RightVector * settings.SideOffset
			- vehicleCF.LookVector * settings.BackOffset
				+ Vector3.new(0, settings.HeightOffset, 0)

			local lookAtPosition =
				vehicleCF.Position
				+ vehicleCF.LookVector * settings.LookAhead
				+ Vector3.new(0, settings.LookHeight, 0)

			desiredCFrame = CFrame.lookAt(cameraPosition, lookAtPosition)

			local alpha = math.clamp(deltaTime * settings.Smoothness, 0, 1)
			currentCameraCFrame = currentCameraCFrame:Lerp(desiredCFrame, alpha)

		elseif activeMode == "Reverse" then
			local settings = REVERSE_SETTINGS
			camera.FieldOfView = settings.FieldOfView

			local cameraPosition =
				vehicleCF.Position
				+ vehicleCF.LookVector * settings.FrontOffset
				+ Vector3.new(0, settings.HeightOffset, 0)

			local lookAtPosition =
				vehicleCF.Position
			- vehicleCF.LookVector * settings.LookBack
				+ Vector3.new(0, settings.LookHeight, 0)

			desiredCFrame = CFrame.lookAt(cameraPosition, lookAtPosition)

			local alpha = math.clamp(deltaTime * settings.Smoothness, 0, 1)
			currentCameraCFrame = currentCameraCFrame:Lerp(desiredCFrame, alpha)
		end

		camera.CFrame = currentCameraCFrame
		camera.Focus = CFrame.new(vehicleRoot.Position)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == SIDE_VIEW_KEY then
		if activeMode == "Side" then
			returnToNormalCamera()
		else
			setTrailerCameraMode("Side")
		end

	elseif input.KeyCode == REVERSE_VIEW_KEY then
		if activeMode == "Reverse" then
			returnToNormalCamera()
		else
			setTrailerCameraMode("Reverse")
		end

	elseif input.KeyCode == NORMAL_VIEW_KEY then
		returnToNormalCamera()
	end
end)