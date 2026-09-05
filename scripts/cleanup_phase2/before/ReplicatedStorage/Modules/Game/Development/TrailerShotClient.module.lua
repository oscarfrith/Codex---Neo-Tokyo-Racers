-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
local config=game:GetService("ReplicatedStorage").NeoTokyoRacers.Config.Development.ClientTools
if not require(game:GetService("ReplicatedStorage").Modules.Core.ClientLifecycle).tool_enabled(game:GetService("RunService"):IsStudio(),config,[====[
TrailerShotEnabled]====]) then return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("TrailerShot01Camera")
-- StarterPlayer > StarterPlayerScripts > TrailerShot01Camera.client.lua
-- Press P to play Shot01.
-- Press B to cancel and return to normal camera.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local shots=workspace:FindFirstChild("TrailerShots")
local shotFolder=shots and shots:FindFirstChild("Shot01_StraightRoadPan")
assert(shotFolder,"TrailerShotEnabled requires Workspace.TrailerShots.Shot01_StraightRoadPan")

local cameraA = assert(shotFolder:FindFirstChild("Camera_A"),"Missing trailer marker Camera_A")
assert(cameraA:IsA("BasePart"),"Trailer marker must be a BasePart")
local cameraB = assert(shotFolder:FindFirstChild("Camera_B"),"Missing trailer marker Camera_B")
assert(cameraB:IsA("BasePart"),"Trailer marker must be a BasePart")
local lookAtTarget = assert(shotFolder:FindFirstChild("LookAt_Target"),"Missing trailer marker LookAt_Target")
assert(lookAtTarget:IsA("BasePart"),"Trailer marker must be a BasePart")

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

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
