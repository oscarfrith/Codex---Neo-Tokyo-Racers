-- NTR Racing Phase 8E - Reset Handoff Yaw Sync
-- Purpose:
--   Fix reset-to-checkpoint facing at the root cause: the active driving loop keeps
--   an internal yawHeading while driving, so a server PivotTo can be pulled back
--   toward the old heading on the next heartbeat. This phase keeps the server
--   authoritative for the reset pose and makes the client restart the existing
--   driving handoff after a reset so yawHeading is re-read from the reset CFrame.
--
-- Scope:
--   * Canonically replaces the isolated RaceTransitionClient_Active.
--   * Patches only the reset vehicle pivot helpers in the isolated racing services.
--   * Does not edit reward config, route-guide config, checkpoint visuals, or the
--     register-limited main client bootstrap.

local MODE = "INSTALL" -- INSTALL or SMOKE

local function info(message)
	print("[NTR Racing Phase 8E] " .. tostring(message))
end

local function fail(message)
	error("[NTR Racing Phase 8E] " .. tostring(message), 2)
end

local function replaceOnce(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. tostring(label) .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, oldText, endIndex + 1, true)
	if second then
		fail("Source anchor matched more than once: " .. tostring(label) .. ". Refusing ambiguous replacement.")
	end
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
end

local function kitRoot()
	local replicatedStorage = game:GetService("ReplicatedStorage")
	return replicatedStorage:FindFirstChild("NeoTokyoRacers")
end

local function serverRacingFolder()
	local serverScriptService = game:GetService("ServerScriptService")
	local root = serverScriptService:FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	return services and services:FindFirstChild("Racing")
end

local function clientRacingFolder()
	local starterPlayer = game:GetService("StarterPlayer")
	local starterScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = starterScripts and starterScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	return controllers and controllers:FindFirstChild("Racing")
end

local TRANSITION_CLIENT_SOURCE = [==[
-- NTR_RACING_PHASE8E_TRANSITION_CLIENT

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
local lastDrivingSyncClock = 0

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceTransitionFade_Phase8E"
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
	print(("[NTR Racing Phase 8E] Session HUD state active=%s reason=%s"):format(tostring(active), tostring(reason or "")))
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

local function freeRoamVehicleSpawnedEvent()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local uiFolder = controllers and controllers:FindFirstChild("UI")
	local event = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
	if event and event:IsA("BindableEvent") then
		return event
	end
	return nil
end

local function syncDrivingYaw(reason)
	local now = os.clock()
	if now - lastDrivingSyncClock < 0.18 then
		return
	end
	lastDrivingSyncClock = now
	local event = freeRoamVehicleSpawnedEvent()
	if event then
		event:Fire()
		print(("[NTR Racing Phase 8E] Fired driving yaw sync after reset reason=%s"):format(tostring(reason or "")))
	else
		warn("[NTR Racing Phase 8E] Could not find FreeRoamVehicleSpawned BindableEvent for reset yaw sync.")
	end
end

local function stopOwnedVehicleMomentum(reason)
	local vehicle = currentOwnedVehicle()
	if not vehicle then
		return
	end
	local schedule = { 0, 0.03, 0.1, 0.22, 0.45, 0.75 }
	for _, delaySeconds in ipairs(schedule) do
		task.delay(delaySeconds, function()
			if zeroVehicleVelocity(vehicle) then
				vehicle:SetAttribute("NTR_RaceResetStationaryClient", os.clock())
			end
		end)
	end
	print(("[NTR Racing Phase 8E] Local reset momentum stop reason=%s vehicle=%s"):format(tostring(reason or ""), vehicle:GetFullName()))
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
	print(("[NTR Racing Phase 8E] Camera restore reason=%s type=%s subject=%s"):format(tostring(reason or ""), tostring(camera.CameraType), subjectName))
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

local function resetTransition(reason)
	setSessionActive(true, reason)
	suppressFreeRoamHud()
	fadeOut("RESETTING")
	stopOwnedVehicleMomentum(reason)
	task.delay(0.08, function()
		syncDrivingYaw(reason)
	end)
	task.delay(0.18, function()
		stopOwnedVehicleMomentum(reason .. "_PostYawSync")
		restoreCamera(reason)
	end)
	fadeIn(0.62)
end

local function handleRacePayload(payload)
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
		resetTransition(kind)
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
		stopOwnedVehicleMomentum(payload.Reason or step)
	elseif step == "StartTransition" then
		startTransition(payload.Reason or step)
	elseif step == "SyncDrivingYaw" then
		syncDrivingYaw(payload.Reason or step)
	end
end)

raceEvent.OnClientEvent:Connect(function(payload)
	handleRacePayload(payload)
end)

queueEvent.OnClientEvent:Connect(function(payload)
	handleRacePayload(payload)
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

print("[NTR Racing Phase 8E Client] Transition fade/camera/reset yaw-sync controller active.")
]==]

local OLD_TIME_TRIAL_PIVOT = [==[local function pivotVehicleForSession(player, vehicle, targetCFrame, frozen)
	local root = vehicleRootPart(vehicle)
	if not root then
		return false, "Vehicle root missing."
	end
	vehicle.PrimaryPart = root
	vehicle:PivotTo(targetCFrame)
	zeroModelVelocity(vehicle)
	seatPlayer(player, vehicle)
	task.wait(0.06)
	if frozen == true then
		setVehicleFrozen(vehicle, true)
		zeroModelVelocity(vehicle)
	else
		prepareVehicleForDriving(player, vehicle)
		-- NTR_RACING_PHASE8D_RESET_STATIONARY
		-- Reset should return the vehicle to a clean stationary checkpoint state,
		-- even if the driving handoff applies one more physics step after seating.
		task.delay(0.08, function()
			if vehicle and vehicle.Parent then
				zeroModelVelocity(vehicle)
			end
		end)
		task.delay(0.24, function()
			if vehicle and vehicle.Parent then
				zeroModelVelocity(vehicle)
			end
		end)
	end
	return true, "Vehicle moved."
end]==]

local NEW_TIME_TRIAL_PIVOT = [==[local function pivotVehicleForSession(player, vehicle, targetCFrame, frozen)
	-- NTR_RACING_PHASE8E_RESET_HANDOFF
	local root = vehicleRootPart(vehicle)
	if not root then
		return false, "Vehicle root missing."
	end
	vehicle.PrimaryPart = root
	vehicle:SetAttribute("NTR_RaceResetting", true)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.Anchored = true
	vehicle:PivotTo(targetCFrame)
	zeroModelVelocity(vehicle)
	seatPlayer(player, vehicle)
	task.wait(0.08)
	if frozen == true then
		setVehicleFrozen(vehicle, true)
		zeroModelVelocity(vehicle)
	else
		root.Anchored = false
		prepareVehicleForDriving(player, vehicle)
		vehicle:SetAttribute("NTR_RaceResetYawSync", os.clock())
		-- Reset should return the vehicle to a clean stationary checkpoint state,
		-- even if the driving handoff applies one more physics step after seating.
		task.delay(0.08, function()
			if vehicle and vehicle.Parent then
				zeroModelVelocity(vehicle)
			end
		end)
		task.delay(0.24, function()
			if vehicle and vehicle.Parent then
				zeroModelVelocity(vehicle)
			end
		end)
	end
	task.delay(0.5, function()
		if vehicle and vehicle.Parent then
			vehicle:SetAttribute("NTR_RaceResetting", nil)
		end
	end)
	return true, "Vehicle moved."
end]==]

local OLD_RACE_PIVOT = [==[local function pivotVehicleForRace(player, vehicle, targetCFrame, frozen)
	local root = vehicleRootPart(vehicle)
	if not root then
		return false, "Vehicle root missing."
	end
	vehicle.PrimaryPart = root
	vehicle:PivotTo(targetCFrame)
	zeroModelVelocity(vehicle)
	seatPlayer(player, vehicle)
	task.wait(0.06)
	if frozen == true then
		setVehicleFrozen(vehicle, true)
		zeroModelVelocity(vehicle)
	else
		prepareVehicleForDriving(player, vehicle)
		-- NTR_RACING_PHASE8D_RESET_STATIONARY
		-- Reset should return the vehicle to a clean stationary checkpoint state,
		-- even if the driving handoff applies one more physics step after seating.
		task.delay(0.08, function()
			if vehicle and vehicle.Parent then
				zeroModelVelocity(vehicle)
			end
		end)
		task.delay(0.24, function()
			if vehicle and vehicle.Parent then
				zeroModelVelocity(vehicle)
			end
		end)
	end
	return true, "Vehicle moved."
end]==]

local NEW_RACE_PIVOT = [==[local function pivotVehicleForRace(player, vehicle, targetCFrame, frozen)
	-- NTR_RACING_PHASE8E_RESET_HANDOFF
	local root = vehicleRootPart(vehicle)
	if not root then
		return false, "Vehicle root missing."
	end
	vehicle.PrimaryPart = root
	vehicle:SetAttribute("NTR_RaceResetting", true)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.Anchored = true
	vehicle:PivotTo(targetCFrame)
	zeroModelVelocity(vehicle)
	seatPlayer(player, vehicle)
	task.wait(0.08)
	if frozen == true then
		setVehicleFrozen(vehicle, true)
		zeroModelVelocity(vehicle)
	else
		root.Anchored = false
		prepareVehicleForDriving(player, vehicle)
		vehicle:SetAttribute("NTR_RaceResetYawSync", os.clock())
		-- Reset should return the vehicle to a clean stationary checkpoint state,
		-- even if the driving handoff applies one more physics step after seating.
		task.delay(0.08, function()
			if vehicle and vehicle.Parent then
				zeroModelVelocity(vehicle)
			end
		end)
		task.delay(0.24, function()
			if vehicle and vehicle.Parent then
				zeroModelVelocity(vehicle)
			end
		end)
	end
	task.delay(0.5, function()
		if vehicle and vehicle.Parent then
			vehicle:SetAttribute("NTR_RaceResetting", nil)
		end
	end)
	return true, "Vehicle moved."
end]==]

local function installTransitionClient()
	local folder = clientRacingFolder()
	if not folder then
		fail("Could not find StarterPlayerScripts NeoTokyoRacersClient.Controllers.Racing.")
	end
	local scriptObject = folder:FindFirstChild("RaceTransitionClient_Active")
	if not scriptObject then
		scriptObject = Instance.new("LocalScript")
		scriptObject.Name = "RaceTransitionClient_Active"
		scriptObject.Parent = folder
	end
	if not scriptObject:IsA("LocalScript") then
		fail("RaceTransitionClient_Active exists but is " .. scriptObject.ClassName .. ", expected LocalScript.")
	end
	scriptObject.Source = TRANSITION_CLIENT_SOURCE
	info("Replaced RaceTransitionClient_Active with Phase 8E reset yaw-sync client.")
end

local function patchTimeTrialService()
	local folder = serverRacingFolder()
	local service = folder and folder:FindFirstChild("TimeTrialService_Active")
	if not (service and service:IsA("Script")) then
		fail("Could not find TimeTrialService_Active.")
	end
	if string.find(service.Source, "NTR_RACING_PHASE8E_RESET_HANDOFF", 1, true) then
		info("TimeTrialService_Active already has Phase 8E reset handoff.")
		return
	end
	service.Source = replaceOnce(service.Source, OLD_TIME_TRIAL_PIVOT, NEW_TIME_TRIAL_PIVOT, "time-trial pivotVehicleForSession reset handoff")
	info("Patched TimeTrialService_Active reset handoff.")
end

local function patchRaceService()
	local folder = serverRacingFolder()
	local service = folder and folder:FindFirstChild("RaceMatchmakingService_Active")
	if not (service and service:IsA("Script")) then
		fail("Could not find RaceMatchmakingService_Active.")
	end
	if string.find(service.Source, "NTR_RACING_PHASE8E_RESET_HANDOFF", 1, true) then
		info("RaceMatchmakingService_Active already has Phase 8E reset handoff.")
		return
	end
	service.Source = replaceOnce(service.Source, OLD_RACE_PIVOT, NEW_RACE_PIVOT, "race pivotVehicleForRace reset handoff")
	info("Patched RaceMatchmakingService_Active reset handoff.")
end

local function smoke()
	local folder = clientRacingFolder()
	local transition = folder and folder:FindFirstChild("RaceTransitionClient_Active")
	assert(transition and transition:IsA("LocalScript"), "RaceTransitionClient_Active missing")
	assert(string.find(transition.Source, "NTR_RACING_PHASE8E_TRANSITION_CLIENT", 1, true), "Phase 8E transition client marker missing")
	assert(not string.find(transition.Source, "vehicle:PivotTo(resetCFrame)", 1, true), "old client reset PivotTo still present")
	local serverFolder = serverRacingFolder()
	local timeTrial = serverFolder and serverFolder:FindFirstChild("TimeTrialService_Active")
	local race = serverFolder and serverFolder:FindFirstChild("RaceMatchmakingService_Active")
	assert(timeTrial and string.find(timeTrial.Source, "NTR_RACING_PHASE8E_RESET_HANDOFF", 1, true), "time-trial reset handoff marker missing")
	assert(race and string.find(race.Source, "NTR_RACING_PHASE8E_RESET_HANDOFF", 1, true), "race reset handoff marker missing")
	info("Smoke passed: Phase 8E reset handoff markers are installed.")
end

if MODE == "INSTALL" then
	if not kitRoot() then
		fail("ReplicatedStorage.NeoTokyoRacers missing.")
	end
	installTransitionClient()
	patchTimeTrialService()
	patchRaceService()
	smoke()
	info("Installed. Restart Play before testing reset-to-checkpoint facing.")
	info("Root cause addressed: reset now resyncs the existing driving handoff so yawHeading is read from the checkpoint-facing reset pose.")
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
