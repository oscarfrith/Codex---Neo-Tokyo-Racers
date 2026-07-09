-- NTR Racing Phase 8F - Reset Yaw Bridge And Button Text Repair
-- Fixes the Phase 8E regression where reset-to-checkpoint restarted the full
-- driving handoff, which could disable the car/camera and disturb streaming.
--
-- This phase uses one tiny bootstrap bridge because yawHeading is local to the
-- register-limited driving bootstrap. The bridge only syncs yaw from the current
-- vehicle root; it does not restart driving.

local MODE = "INSTALL" -- INSTALL or SMOKE

local function info(message)
	print("[NTR Racing Phase 8F] " .. tostring(message))
end

local function fail(message)
	error("[NTR Racing Phase 8F] " .. tostring(message), 2)
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

local function clientRoot()
	local starterPlayer = game:GetService("StarterPlayer")
	local starterScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
	return starterScripts and starterScripts:FindFirstChild("NeoTokyoRacersClient")
end

local function clientRacingFolder()
	local root = clientRoot()
	local controllers = root and root:FindFirstChild("Controllers")
	return controllers and controllers:FindFirstChild("Racing")
end

local function bootstrapScript()
	local root = clientRoot()
	local scriptObject = root and root:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	if scriptObject and scriptObject:IsA("LocalScript") then
		return scriptObject
	end
	return nil
end

local TRANSITION_CLIENT_SOURCE = [==[
-- NTR_RACING_PHASE8F_TRANSITION_CLIENT

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
gui.Name = "NTR_RaceTransitionFade_Phase8F"
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
	print(("[NTR Racing Phase 8F] Session HUD state active=%s reason=%s"):format(tostring(active), tostring(reason or "")))
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

local function requestStreamNearVehicle(vehicle)
	local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	if root and root:IsA("BasePart") then
		task.spawn(function()
			pcall(function()
				Workspace:RequestStreamAroundAsync(root.Position)
			end)
		end)
	end
end

local function syncDrivingYaw(reason)
	local now = os.clock()
	if now - lastDrivingSyncClock < 0.18 then
		return
	end
	lastDrivingSyncClock = now
	local event = freeRoamVehicleSpawnedEvent()
	if event then
		event:Fire({
			Action = "SyncDrivingYaw",
			Reason = tostring(reason or "RaceReset"),
		})
		print(("[NTR Racing Phase 8F] Requested yaw-only driving sync after reset reason=%s"):format(tostring(reason or "")))
	else
		warn("[NTR Racing Phase 8F] Could not find FreeRoamVehicleSpawned BindableEvent for yaw-only reset sync.")
	end
end

local function stopOwnedVehicleMomentum(reason)
	local vehicle = currentOwnedVehicle()
	if not vehicle then
		return
	end
	requestStreamNearVehicle(vehicle)
	local schedule = { 0, 0.03, 0.1, 0.22, 0.45, 0.75 }
	for _, delaySeconds in ipairs(schedule) do
		task.delay(delaySeconds, function()
			if zeroVehicleVelocity(vehicle) then
				vehicle:SetAttribute("NTR_RaceResetStationaryClient", os.clock())
			end
		end)
	end
	print(("[NTR Racing Phase 8F] Local reset momentum stop reason=%s vehicle=%s"):format(tostring(reason or ""), vehicle:GetFullName()))
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
	print(("[NTR Racing Phase 8F] Camera restore reason=%s type=%s subject=%s"):format(tostring(reason or ""), tostring(camera.CameraType), subjectName))
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

print("[NTR Racing Phase 8F Client] Transition fade/camera/yaw-only reset controller active.")
]==]

local OLD_BOOTSTRAP_HANDOFF = [==[local V93_spawnedEvent = V93_freeRoamVehicleSpawnedEvent()
if V93_spawnedEvent then
	V93_spawnedEvent.Event:Connect(function()
		task.defer(startDriving)
	end)
end]==]

local NEW_BOOTSTRAP_HANDOFF = [==[local V93_spawnedEvent = V93_freeRoamVehicleSpawnedEvent()
if V93_spawnedEvent then
	V93_spawnedEvent.Event:Connect(function(payload)
		if typeof(payload) == "table" and payload.Action == "SyncDrivingYaw" then
			-- NTR_RACING_PHASE8F_YAW_ONLY_BRIDGE
			local vehicle = currentVehicle or V57_playerVehicle()
			local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
			if vehicle and root and root:IsA("BasePart") then
				vehicle.PrimaryPart = root
				local look = root.CFrame.LookVector
				yawHeading = math.atan2(look.X, look.Z)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				if controls and controls.Align then
					controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + look, Vector3.new(0, 1, 0))
				end
				print("[NTR Racing Phase 8F] Synced driving yaw only after reset.")
			else
				warn("[NTR Racing Phase 8F] Could not sync driving yaw; active vehicle/root missing.")
			end
			return
		end
		task.defer(startDriving)
	end)
end]==]

local OLD_SESSION_FONT = [==[local function applyFont(label, bold)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json", bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
	end)
end]==]

local NEW_SESSION_FONT = [==[local function applyFont(label, bold)
	-- NTR_RACING_PHASE8F_CLEAN_BUTTON_TEXT
	-- Michroma at this small size rasterises unevenly in Roblox buttons.
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextStrokeTransparency = 1
end]==]

local OLD_SESSION_BUTTON_STYLE = [==[	button.TextSize = touch and 10 or 12
	button.TextWrapped = true
	applyFont(button, true)]==]

local NEW_SESSION_BUTTON_STYLE = [==[	button.TextSize = touch and 11 or 13
	button.TextWrapped = false
	button.TextScaled = false
	button.TextStrokeTransparency = 1
	button.LineHeight = 1
	applyFont(button, true)]==]

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
	info("Replaced RaceTransitionClient_Active with Phase 8F yaw-only reset controller.")
end

local function patchBootstrapYawBridge()
	local scriptObject = bootstrapScript()
	if not scriptObject then
		fail("Could not find NeoTokyoRacersClient_Bootstrap_Shadow_Disabled.")
	end
	if string.find(scriptObject.Source, "NTR_RACING_PHASE8F_YAW_ONLY_BRIDGE", 1, true) then
		info("Bootstrap yaw-only bridge already installed.")
		return
	end
	scriptObject.Source = replaceOnce(scriptObject.Source, OLD_BOOTSTRAP_HANDOFF, NEW_BOOTSTRAP_HANDOFF, "FreeRoamVehicleSpawned handoff bridge")
	info("Patched bootstrap with tiny yaw-only reset bridge.")
end

local function patchSessionControlText()
	local folder = clientRacingFolder()
	local scriptObject = folder and folder:FindFirstChild("RaceSessionControlsClient_Active")
	if not (scriptObject and scriptObject:IsA("LocalScript")) then
		fail("Could not find RaceSessionControlsClient_Active.")
	end
	local source = scriptObject.Source
	if not string.find(source, "NTR_RACING_PHASE8F_CLEAN_BUTTON_TEXT", 1, true) then
		source = replaceOnce(source, OLD_SESSION_FONT, NEW_SESSION_FONT, "session controls applyFont")
	end
	if string.find(source, "button.TextWrapped = true", 1, true) then
		source = replaceOnce(source, OLD_SESSION_BUTTON_STYLE, NEW_SESSION_BUTTON_STYLE, "session controls button text style")
	end
	scriptObject.Source = source
	info("Patched race session control button text rendering.")
end

local function smoke()
	local folder = clientRacingFolder()
	local transition = folder and folder:FindFirstChild("RaceTransitionClient_Active")
	assert(transition and transition:IsA("LocalScript"), "RaceTransitionClient_Active missing")
	assert(string.find(transition.Source, "NTR_RACING_PHASE8F_TRANSITION_CLIENT", 1, true), "Phase 8F transition marker missing")
	assert(not string.find(transition.Source, "event:Fire()", 1, true), "old full driving handoff fire still present in transition client")
	local boot = bootstrapScript()
	assert(boot and string.find(boot.Source, "NTR_RACING_PHASE8F_YAW_ONLY_BRIDGE", 1, true), "bootstrap yaw-only bridge marker missing")
	local controls = folder and folder:FindFirstChild("RaceSessionControlsClient_Active")
	assert(controls and string.find(controls.Source, "NTR_RACING_PHASE8F_CLEAN_BUTTON_TEXT", 1, true), "clean button text marker missing")
	info("Smoke passed: yaw-only reset bridge and clean button text are installed.")
end

if MODE == "INSTALL" then
	installTransitionClient()
	patchBootstrapYawBridge()
	patchSessionControlText()
	smoke()
	info("Installed. Restart Play before testing reset-to-checkpoint again.")
	info("This repairs Phase 8E by syncing only yaw instead of restarting the full driving handoff.")
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
