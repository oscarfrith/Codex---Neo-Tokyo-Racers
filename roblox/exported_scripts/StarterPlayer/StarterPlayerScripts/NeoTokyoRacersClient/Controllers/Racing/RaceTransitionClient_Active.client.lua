-- NTR_RACING_PHASE8H_TRANSITION_CLIENT

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider") -- NTR_RACING_STAGING_READINESS_GATE_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local racingFolder = script.Parent
local transitionRequest = racingFolder:WaitForChild("RaceTransitionRequest")
local transitionStateChanged = racingFolder:FindFirstChild("RaceTransitionStateChanged")
local uiControllers = assert(racingFolder.Parent:FindFirstChild("UI"), "Racing loading UI folder missing")
local loadingInvoke = uiControllers:WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE4_RACE_TRANSITION_BRIDGE_V1
local loadingGeneration = nil
local loadingFinishing = false

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")

local sessionActive = false
local lastHudPulse = 0
local savedHudEnabled = {}
local currentFadeTween = nil
local finishHold = false -- NTR_RACING_PHASE11D_FINISH_HOLD
local activeStaging = nil

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceTransitionFade_Phase8H"
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

local function loadingAction(action, payload)
	local ok, result = pcall(function() return loadingInvoke:Invoke(action, payload or {}) end)
	if ok then return result end
	warn("[NTR Racing Loading] " .. tostring(action) .. " failed: " .. tostring(result))
	return nil
end

local function beginLoading(destination, status)
	if loadingGeneration then return loadingGeneration end
	loadingGeneration = loadingAction("Begin", { Destination = destination or "RaceSession", Status = status or "LOADING RACE" })
	return loadingGeneration
end

local function finishLoading(success, status, reason)
	local current = loadingGeneration
	if not current then return loadingFinishing end
	loadingGeneration = nil
	loadingFinishing = true
	loadingAction(success and "Complete" or "Fail", {
		Generation = current,
		Status = status or (success and "READY TO RACE" or "RETURNING"),
		Reason = reason,
	})
	loadingFinishing = false
	return true
end

local function fireState()
	if transitionStateChanged and transitionStateChanged:IsA("BindableEvent") then
		transitionStateChanged:Fire({ Active = sessionActive })
	end
end

local function setSessionActive(active, reason)
	active = active == true
	if sessionActive == active then return end
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
	print(("[NTR Racing Phase 8H] Session HUD state active=%s reason=%s"):format(tostring(active), tostring(reason or "")))
end

local function suppressFreeRoamHud() end -- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP
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
		if targetTransparency >= 1 then fade.Visible = false end
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
	if not camera then return end
	local subject = preferredCameraSubject()
	camera.CameraType = Enum.CameraType.Custom
	if subject then camera.CameraSubject = subject end
	local subjectName = subject and subject:GetFullName() or "nil"
	print(("[NTR Racing Phase 8H] Camera restore reason=%s type=%s subject=%s"):format(tostring(reason or ""), tostring(camera.CameraType), subjectName))
end

local function restoreCamera(reason)
	restoreCameraOnce(reason)
	task.delay(0.12, function() restoreCameraOnce(reason) end)
	task.delay(0.45, function() restoreCameraOnce(reason) end)
end

local function startTransition(reason)
	setSessionActive(true, reason)
	suppressFreeRoamHud()
	if not beginLoading(string.find(tostring(reason), "TimeTrial", 1, true) and "TimeTrialSession" or "RaceSession", "STAGING") then fadeOut("STAGING") end
	task.delay(0.22, function() restoreCamera(reason) end)
end

local function finishTransition(reason)
	restoreCamera(reason)
	if not finishLoading(true, "READY TO RACE", reason) then fadeIn(0.18) end
end

local function resetTransition(reason)
	-- NTR_RACING_PHASE8H_RESET_PRESENTATION_ONLY
	-- Server respawns the race vehicle. Client only covers it with fade/camera.
	setSessionActive(true, reason)
	suppressFreeRoamHud()
	fadeOut("RESETTING")
	task.delay(0.32, function() restoreCamera(reason) end)
	fadeIn(0.82)
end

local function acknowledgeStaging(stage, phase, degraded, detail)
	if activeStaging ~= stage then return false end
	local remote = stage.Mode == "TimeTrial" and raceRequest or queueRequest
	local ok, result = pcall(function()
		return remote:InvokeServer("AcknowledgeStagingReady", {
			RunId = stage.RunId,
			Phase = phase,
			Degraded = degraded == true,
			Detail = tostring(detail or ""),
		})
	end)
	if not ok or typeof(result) ~= "table" or result.Ok ~= true then
		warn(("[NTR Race Readiness] %s acknowledgement failed for %s: %s"):format(phase, stage.RunId, tostring(ok and result and result.Message or result)))
		return false
	end
	return true
end

local function stagedVehicle(runId)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then return nil end
	local vehicle = vehicleFromSeat(seat)
	if not vehicle or tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then return nil end
	if tostring(vehicle:GetAttribute("NTR_RaceRunId") or "") ~= tostring(runId or "") then return nil end
	if vehicle:GetAttribute("NTR_RaceParticipant") ~= true then return nil end
	return vehicle
end

local function prepareStaging(payload, kind)
	local runId = tostring(payload.RunId or "")
	if runId == "" then return end
	if activeStaging and activeStaging.RunId == runId then return end
	local stage = { RunId = runId, Mode = kind == "TimeTrialStaged" and "TimeTrial" or "Race", RevealHandling = false }
	activeStaging = stage
	task.spawn(function()
		local deadline = os.clock() + 7.5
		local vehicle = nil
		local presenter = racingFolder:FindFirstChild("RaceCountdownPresentationController_Active")
		while activeStaging == stage and os.clock() < deadline do
			vehicle = stagedVehicle(runId)
			if vehicle and presenter and presenter:GetAttribute("NTR_CountdownPresentationReady") == true then break end
			task.wait(0.05)
		end
		if activeStaging ~= stage then return end
		local preparationFinished = false
		local preparationOk = true
		local preparationDetail = ""
		task.spawn(function()
			local ok, problem = pcall(function()
				local streamPosition = payload.StreamPosition
				if typeof(streamPosition) == "Vector3" then player:RequestStreamAroundAsync(streamPosition, 5) end
				if vehicle and vehicle.Parent then ContentProvider:PreloadAsync({ vehicle }) end
			end)
			preparationOk = ok
			preparationDetail = ok and "" or tostring(problem)
			preparationFinished = true
		end)
		while activeStaging == stage and not preparationFinished and os.clock() < deadline do task.wait(0.05) end
		if activeStaging ~= stage then return end
		local presenterReady = presenter and presenter:GetAttribute("NTR_CountdownPresentationReady") == true
		local degraded = not (vehicle and presenterReady and preparationFinished and preparationOk)
		local detail = preparationDetail
		if not vehicle then detail = "Staged vehicle/seat was not confirmed locally." elseif not presenterReady then detail = "Countdown presenter was not ready." elseif not preparationFinished then detail = "Streaming/preload preparation reached its client deadline." end
		acknowledgeStaging(stage, "AssetsReady", degraded, detail)
	end)
end

local function revealCountdown(payload, kind)
	local stage = activeStaging
	if not stage or stage.RunId ~= tostring(payload.RunId or "") or stage.RevealHandling then return end
	stage.RevealHandling = true
	task.spawn(function()
		restoreCamera(kind)
		local hadLoading = loadingGeneration ~= nil
		finishTransition(kind)
		if not hadLoading then task.wait(0.55) end
		if activeStaging == stage then acknowledgeStaging(stage, "CountdownVisible", false, "") end
	end)
end

local function handleRacePayload(payload)
	if typeof(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "TimeTrialStaged" or kind == "RaceStaged" then
		finishHold = false
		if not activeStaging or activeStaging.RunId ~= tostring(payload.RunId or "") then
			startTransition(kind)
			prepareStaging(payload, kind)
		end
	elseif kind == "TimeTrialCountdownReveal" or kind == "RaceCountdownReveal" then
		revealCountdown(payload, kind)
	elseif kind == "TimeTrialCountdownScheduled" or kind == "RaceCountdownScheduled" then
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		restoreCamera(kind)
	elseif kind == "TimeTrialCountdown" or kind == "RaceCountdown" then
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		restoreCamera(kind)
	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		activeStaging = nil
		finishHold = false
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		finishTransition(kind)
	elseif kind == "TimeTrialReset" or kind == "RaceReset" then
		resetTransition(kind)
	elseif kind == "RaceFinished" then
		-- NTR_RACING_PHASE11D_FINISH_HOLD
		finishHold = true
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		fadeOut("")
	elseif kind == "RaceExitedToStart" then
		finishHold = false
		setSessionActive(false, kind)
		restoreCamera(kind)
		if not finishLoading(true, "READY", kind) then fadeIn(0.28) end
	elseif kind == "RaceEnded" and finishHold then
		suppressFreeRoamHud()
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError"
		or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceQueueError" then
		finishHold = false
		setSessionActive(false, kind)
		restoreCamera(kind)
		activeStaging = nil
		local success = kind ~= "TimeTrialError" and kind ~= "RaceQueueError"
		if not finishLoading(success, success and "READY" or "RETURNING", kind) then fadeIn(0.18) end
	end
end

transitionRequest.Event:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local step = tostring(payload.Step or "")
	if step == "SessionActive" then
		setSessionActive(payload.Active == true, payload.Reason or step)
		if sessionActive then suppressFreeRoamHud() end
	elseif step == "FadeOut" then
		if tostring(payload.Reason or "") == "Reset" then fadeOut(payload.Label or "")
		else beginLoading(payload.Destination or "RaceStart", payload.Label or "LOADING") end
	elseif step == "FadeIn" then
		if tostring(payload.Reason or "") == "Reset" then fadeIn(payload.Delay)
		else
			local failed = payload.Success == false or string.find(tostring(payload.Reason or ""), "Failed", 1, true) ~= nil
			finishLoading(not failed, failed and "RETURNING" or "READY", payload.Reason)
		end
	elseif step == "BeginLoading" then
		if not beginLoading(payload.Destination, payload.Status) then fadeOut(payload.Status or "LOADING") end
	elseif step == "CompleteLoading" then
		if not finishLoading(true, payload.Status, payload.Reason) then fadeIn(payload.Delay) end
	elseif step == "FailLoading" then
		if not finishLoading(false, payload.Status, payload.Reason) then fadeIn(payload.Delay) end
	elseif step == "RestoreCamera" then
		restoreCamera(payload.Reason or step)
	elseif step == "StopVehicle" then
		print("[NTR Racing Phase 8H] Ignored StopVehicle transition; reset respawns server-side.")
	elseif step == "StartTransition" then
		startTransition(payload.Reason or step)
	end
end)

raceEvent.OnClientEvent:Connect(function(payload)
	handleRacePayload(payload)
end)

queueEvent.OnClientEvent:Connect(function(payload)
	handleRacePayload(payload)
end)

-- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP: no HUD suppression heartbeat; presentation owners publish lifecycle state.

player.CharacterAdded:Connect(function()
	task.delay(0.35, function()
		restoreCamera("CharacterAdded")
		if not sessionActive then fadeIn(0) end
	end)
end)

print("[NTR Racing Phase 8H Client] Transition/camera controller active; reset respawns server-side.")
