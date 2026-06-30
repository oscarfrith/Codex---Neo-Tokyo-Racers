-- StarterPlayer > StarterPlayerScripts > TrailerShot01Camera.client.lua
-- Press P to play Shot01.
-- Press B to cancel and return to normal camera.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local shotFolder = workspace:WaitForChild("TrailerShots"):WaitForChild("Shot01_StraightRoadPan")

local cameraA = shotFolder:WaitForChild("Camera_A")
local cameraB = shotFolder:WaitForChild("Camera_B")
local lookAtTarget = shotFolder:WaitForChild("LookAt_Target")

local SHOT_KEY = Enum.KeyCode.P
local CANCEL_KEY = Enum.KeyCode.B

local SHOT_DURATION = 12
local FIELD_OF_VIEW = 80

local isPlaying = false
local renderConnection = nil

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function returnToNormalCamera()
	isPlaying = false

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	camera.CameraType = Enum.CameraType.Custom

	local character = getCharacter()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function smoothStep(alpha)
	return alpha * alpha * (3 - 2 * alpha)
end

local function playShot01()
	if isPlaying then
		return
	end

	isPlaying = true

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FIELD_OF_VIEW

	local startTime = os.clock()

	renderConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / SHOT_DURATION, 0, 1)
		local smoothAlpha = smoothStep(alpha)

		local cameraPosition = cameraA.Position:Lerp(cameraB.Position, smoothAlpha)
		local lookAtPosition = lookAtTarget.Position

		camera.CFrame = CFrame.lookAt(cameraPosition, lookAtPosition)

		if alpha >= 1 then
			returnToNormalCamera()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == SHOT_KEY then
		playShot01()
	elseif input.KeyCode == CANCEL_KEY then
		returnToNormalCamera()
	end
end)
