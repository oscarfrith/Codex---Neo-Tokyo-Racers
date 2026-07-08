-- Neo Tokyo Racers - Racing Phase 8D Transition Client
-- NTR_RACING_PHASE8D_TRANSITION_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local racingFolder = script.Parent
local transitionRequest = racingFolder:WaitForChild("RaceTransitionRequest")
local transitionStateChanged = racingFolder:FindFirstChild("RaceTransitionStateChanged")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")

local sessionActive = false
local lastHudPulse = 0
local savedHudEnabled = {}
local currentFadeTween = nil

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceTransitionFade_Phase8D"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 210
gui.Enabled = true
gui.Parent = playerGui

local fade = Instance.new("Frame")
fade.Name = "Fade"
fade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fade.BackgroundTransparency = 1
fade.BorderSizePixel = 0
fade.Size = UDim2.fromScale(1, 1)
fade.Visible = false
fade.Parent = gui

local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.5, 0.5)
label.Size = UDim2.fromOffset(360, 44)
label.Text = ""
label.TextColor3 = Color3.fromRGB(230, 255, 246)
label.TextSize = 17
label.TextTransparency = 1
label.TextStrokeTransparency = 0.45
label.Font = Enum.Font.GothamBold
pcall(function()
	label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Bold)
end)
label.Parent = fade

local suppressGuiNames = {
	NTR_FreeRoamLeftNav = true,
	NTR_FreeRoamVehicleExitButton = true,
	NTR_FreeRoamCarMenu = true,
	NTR_FreeRoamCarMenu_Phase3 = true,
}

local function fireState()
	if transitionStateChanged and transitionStateChanged:IsA("BindableEvent") then
		transitionStateChanged:Fire({
			Active = sessionActive,
		})
	end
end

local function setSessionActive(active, reason)
	active = active == true
	if sessionActive == active then
		return
	end
	sessionActive = active
	if not active then
		for guiObject, original in pairs(savedHudEnabled) do
			if guiObject and guiObject.Parent and guiObject:IsA("ScreenGui") then
				guiObject.Enabled = original ~= false
			end
		end
		table.clear(savedHudEnabled)
	end
	fireState()
	print(("[NTR Racing Phase 8D] Session HUD state active=%s reason=%s"):format(tostring(active), tostring(reason or "")))
end

local function suppressFreeRoamHud()
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and suppressGuiNames[child.Name] then
			if savedHudEnabled[child] == nil then
				savedHudEnabled[child] = child.Enabled
			end
			child.Enabled = false
		end
	end
end

local function tweenFade(targetTransparency, duration)
	if currentFadeTween then
		currentFadeTween:Cancel()
		currentFadeTween = nil
	end
	fade.Visible = true
	currentFadeTween = TweenService:Create(
		fade,
		TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = targetTransparency }
	)
	currentFadeTween:Play()
	currentFadeTween.Completed:Once(function()
		currentFadeTween = nil
		if targetTransparency >= 1 then
			fade.Visible = false
		end
	end)
end

local function fadeOut(text)
	label.Text = tostring(text or "")
	label.TextTransparency = label.Text == "" and 1 or 0.08
	tweenFade(0, 0.24)
end

local function fadeIn(delaySeconds)
	task.delay(tonumber(delaySeconds) or 0, function()
		label.TextTransparency = 1
		tweenFade(1, 0.3)
	end)
end

local function vehicleFromSeat(seat)
	local current = seat
	while current do
		if current:IsA("Model") and current:GetAttribute("OwnerUserId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function currentOwnedVehicle()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") then
		local vehicle = vehicleFromSeat(seat)
		if vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then
			return vehicle
		end
	end
	return nil
end

local function zeroVehicleVelocity(vehicle)
	if not (vehicle and vehicle.Parent) then
		return false
	end
	local stopped = false
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			stopped = true
		end
	end
	return stopped
end

local function stopOwnedVehicleMomentum(reason, resetCFrame)
	local vehicle = currentOwnedVehicle()
	if not vehicle then
		return
	end
	local hasResetCFrame = typeof(resetCFrame) == "CFrame"
	if hasResetCFrame then
		vehicle:PivotTo(resetCFrame)
	end
	local schedule = { 0, 0.03, 0.1, 0.22, 0.45, 0.75 }
	for _, delaySeconds in ipairs(schedule) do
		task.delay(delaySeconds, function()
			if zeroVehicleVelocity(vehicle) then
				vehicle:SetAttribute("NTR_RaceResetStationaryClient", os.clock())
			end
		end)
	end
	print(("[NTR Racing Phase 8D] Local reset momentum stop reason=%s cframe=%s vehicle=%s"):format(tostring(reason or ""), tostring(hasResetCFrame), vehicle:GetFullName()))
end

local function preferredCameraSubject()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") then
		local vehicle = vehicleFromSeat(seat)
		if vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then
			return seat
		end
	end
	return humanoid
end

local function restoreCameraOnce(reason)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local subject = preferredCameraSubject()
	camera.CameraType = Enum.CameraType.Custom
	if subject then
		camera.CameraSubject = subject
	end
	local subjectName = subject and subject:GetFullName() or "nil"
	print(("[NTR Racing Phase 8D] Camera restore reason=%s type=%s subject=%s"):format(tostring(reason or ""), tostring(camera.CameraType), subjectName))
end

local function restoreCamera(reason)
	restoreCameraOnce(reason)
	task.delay(0.12, function()
		restoreCameraOnce(reason)
	end)
	task.delay(0.45, function()
		restoreCameraOnce(reason)
	end)
end

local function startTransition(reason)
	setSessionActive(true, reason)
	suppressFreeRoamHud()
	fadeOut("STAGING")
	task.delay(0.22, function()
		restoreCamera(reason)
	end)
	task.delay(0.78, function()
		fadeIn(0)
	end)
end

local function finishTransition(reason)
	restoreCamera(reason)
	fadeIn(0.18)
end

local function handleRacePayload(payload, sourceName)
	if typeof(payload) ~= "table" then
		return
	end
	local kind = tostring(payload.Type or "")
	if kind == "TimeTrialStaged" or kind == "RaceStaged" then
		startTransition(kind)
	elseif kind == "TimeTrialCountdown" or kind == "RaceCountdown" then
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		restoreCamera(kind)
	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		finishTransition(kind)
	elseif kind == "TimeTrialReset" or kind == "RaceReset" then
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		stopOwnedVehicleMomentum(kind, payload.ResetCFrame)
		restoreCamera(kind)
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError"
		or kind == "RaceFinished" or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceQueueError" then
		setSessionActive(false, kind)
		restoreCamera(kind)
		fadeIn(0.18)
	end
end

transitionRequest.Event:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local step = tostring(payload.Step or "")
	if step == "SessionActive" then
		setSessionActive(payload.Active == true, payload.Reason or step)
		if sessionActive then
			suppressFreeRoamHud()
		end
	elseif step == "FadeOut" then
		fadeOut(payload.Label or "")
	elseif step == "FadeIn" then
		fadeIn(payload.Delay)
	elseif step == "RestoreCamera" then
		restoreCamera(payload.Reason or step)
	elseif step == "StopVehicle" then
		stopOwnedVehicleMomentum(payload.Reason or step, payload.ResetCFrame)
	elseif step == "StartTransition" then
		startTransition(payload.Reason or step)
	end
end)

raceEvent.OnClientEvent:Connect(function(payload)
	handleRacePayload(payload, "RaceEvent")
end)

queueEvent.OnClientEvent:Connect(function(payload)
	handleRacePayload(payload, "RaceQueueEvent")
end)

RunService.Heartbeat:Connect(function()
	if sessionActive and os.clock() - lastHudPulse > 0.2 then
		lastHudPulse = os.clock()
		suppressFreeRoamHud()
	end
end)

player.CharacterAdded:Connect(function()
	task.delay(0.35, function()
		restoreCamera("CharacterAdded")
		if not sessionActive then
			fadeIn(0)
		end
	end)
end)

print("[NTR Racing Phase 8D Client] Transition fade/camera/HUD controller active.")
