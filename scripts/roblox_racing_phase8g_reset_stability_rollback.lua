-- NTR Racing Phase 8G - Reset Stability Rollback
-- Fixes the car/camera/streaming regression from Phase 8E/8F by removing all
-- client-side reset vehicle pokes and rolling back the racing service reset
-- helper to the last stable Phase 8D shape when needed.
--
-- This prioritises a stable, drivable reset over checkpoint-facing polish.

local MODE = "INSTALL" -- INSTALL or SMOKE

local function info(message)
	print("[NTR Racing Phase 8G] " .. tostring(message))
end

local function fail(message)
	error("[NTR Racing Phase 8G] " .. tostring(message), 2)
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

local function serverRacingFolder()
	local serverScriptService = game:GetService("ServerScriptService")
	local root = serverScriptService:FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	return services and services:FindFirstChild("Racing")
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
-- NTR_RACING_PHASE8G_TRANSITION_CLIENT

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
gui.Name = "NTR_RaceTransitionFade_Phase8G"
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
	print(("[NTR Racing Phase 8G] Session HUD state active=%s reason=%s"):format(tostring(active), tostring(reason or "")))
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
	print(("[NTR Racing Phase 8G] Camera restore reason=%s type=%s subject=%s"):format(tostring(reason or ""), tostring(camera.CameraType), subjectName))
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
	-- NTR_RACING_PHASE8G_RESET_NO_CLIENT_VEHICLE_POKE
	-- Server owns reset movement. The client only handles presentation/camera.
	setSessionActive(true, reason)
	suppressFreeRoamHud()
	fadeOut("RESETTING")
	task.delay(0.18, function()
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
		print("[NTR Racing Phase 8G] Ignored StopVehicle transition; server owns reset movement.")
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

print("[NTR Racing Phase 8G Client] Transition/camera controller active; reset uses no client vehicle poke.")
]==]

local PHASE8E_BOOTSTRAP_HANDOFF = [==[local V93_spawnedEvent = V93_freeRoamVehicleSpawnedEvent()
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

local STABLE_BOOTSTRAP_HANDOFF = [==[local V93_spawnedEvent = V93_freeRoamVehicleSpawnedEvent()
if V93_spawnedEvent then
	V93_spawnedEvent.Event:Connect(function()
		task.defer(startDriving)
	end)
end]==]

local PHASE8E_TIME_TRIAL_PIVOT = [==[local function pivotVehicleForSession(player, vehicle, targetCFrame, frozen)
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

local STABLE_TIME_TRIAL_PIVOT = [==[local function pivotVehicleForSession(player, vehicle, targetCFrame, frozen)
	-- NTR_RACING_PHASE8G_STABLE_RESET_HANDOFF
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

local PHASE8E_RACE_PIVOT = [==[local function pivotVehicleForRace(player, vehicle, targetCFrame, frozen)
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

local STABLE_RACE_PIVOT = [==[local function pivotVehicleForRace(player, vehicle, targetCFrame, frozen)
	-- NTR_RACING_PHASE8G_STABLE_RESET_HANDOFF
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

local STOP_VEHICLE_BLOCK = [==[	if ok and kind == "Reset" then
		fireTransition("StopVehicle", { Reason = kind })
	end
	fireTransition("RestoreCamera", { Reason = kind })]==]

local NO_STOP_VEHICLE_BLOCK = [==[	if ok and kind == "Reset" then
		-- NTR_RACING_PHASE8G_NO_CLIENT_RESET_STOP
		-- The reset event from the server owns presentation; do not also poke the vehicle here.
	end
	fireTransition("RestoreCamera", { Reason = kind })]==]

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
	info("Replaced RaceTransitionClient_Active with no-client-vehicle-poke reset transition.")
end

local function restoreBootstrapHandoff()
	local scriptObject = bootstrapScript()
	if not scriptObject then
		fail("Could not find NeoTokyoRacersClient_Bootstrap_Shadow_Disabled.")
	end
	if not string.find(scriptObject.Source, "NTR_RACING_PHASE8F_YAW_ONLY_BRIDGE", 1, true) then
		info("Bootstrap yaw bridge not present; normal handoff left unchanged.")
		return
	end
	scriptObject.Source = replaceOnce(scriptObject.Source, PHASE8E_BOOTSTRAP_HANDOFF, STABLE_BOOTSTRAP_HANDOFF, "Phase 8F yaw-only bootstrap bridge")
	info("Restored bootstrap FreeRoamVehicleSpawned handoff to stable payload-less shape.")
end

local function rollbackServerResetHelpers()
	local folder = serverRacingFolder()
	if not folder then
		fail("Could not find ServerScriptService NeoTokyoRacers.Services.Racing.")
	end
	local timeTrial = folder:FindFirstChild("TimeTrialService_Active")
	local race = folder:FindFirstChild("RaceMatchmakingService_Active")
	if not (timeTrial and timeTrial:IsA("Script")) then
		fail("Could not find TimeTrialService_Active.")
	end
	if not (race and race:IsA("Script")) then
		fail("Could not find RaceMatchmakingService_Active.")
	end
	if string.find(timeTrial.Source, "NTR_RACING_PHASE8E_RESET_HANDOFF", 1, true) then
		timeTrial.Source = replaceOnce(timeTrial.Source, PHASE8E_TIME_TRIAL_PIVOT, STABLE_TIME_TRIAL_PIVOT, "Phase 8E time-trial reset handoff")
		info("Rolled TimeTrialService_Active reset helper back to stable Phase 8G shape.")
	elseif string.find(timeTrial.Source, "NTR_RACING_PHASE8G_STABLE_RESET_HANDOFF", 1, true) then
		info("TimeTrialService_Active already has stable Phase 8G reset helper.")
	else
		info("TimeTrialService_Active does not contain Phase 8E reset handoff; left unchanged.")
	end
	if string.find(race.Source, "NTR_RACING_PHASE8E_RESET_HANDOFF", 1, true) then
		race.Source = replaceOnce(race.Source, PHASE8E_RACE_PIVOT, STABLE_RACE_PIVOT, "Phase 8E race reset handoff")
		info("Rolled RaceMatchmakingService_Active reset helper back to stable Phase 8G shape.")
	elseif string.find(race.Source, "NTR_RACING_PHASE8G_STABLE_RESET_HANDOFF", 1, true) then
		info("RaceMatchmakingService_Active already has stable Phase 8G reset helper.")
	else
		info("RaceMatchmakingService_Active does not contain Phase 8E reset handoff; left unchanged.")
	end
end

local function patchSessionControls()
	local folder = clientRacingFolder()
	local scriptObject = folder and folder:FindFirstChild("RaceSessionControlsClient_Active")
	if not (scriptObject and scriptObject:IsA("LocalScript")) then
		fail("Could not find RaceSessionControlsClient_Active.")
	end
	if string.find(scriptObject.Source, "NTR_RACING_PHASE8G_NO_CLIENT_RESET_STOP", 1, true) then
		info("RaceSessionControlsClient_Active already avoids client reset StopVehicle.")
		return
	end
	scriptObject.Source = replaceOnce(scriptObject.Source, STOP_VEHICLE_BLOCK, NO_STOP_VEHICLE_BLOCK, "session controls reset StopVehicle block")
	info("Removed duplicate client StopVehicle call from reset button.")
end

local function smoke()
	local folder = clientRacingFolder()
	local transition = folder and folder:FindFirstChild("RaceTransitionClient_Active")
	assert(transition and transition:IsA("LocalScript"), "RaceTransitionClient_Active missing")
	assert(string.find(transition.Source, "NTR_RACING_PHASE8G_TRANSITION_CLIENT", 1, true), "Phase 8G transition marker missing")
	assert(string.find(transition.Source, "NTR_RACING_PHASE8G_RESET_NO_CLIENT_VEHICLE_POKE", 1, true), "no-client vehicle poke reset marker missing")
	assert(not string.find(transition.Source, "AssemblyLinearVelocity = Vector3.zero", 1, true), "transition client still zeros vehicle velocity")
	assert(not string.find(transition.Source, "SyncDrivingYaw", 1, true), "transition client still requests yaw sync")
	local boot = bootstrapScript()
	assert(boot and not string.find(boot.Source, "NTR_RACING_PHASE8F_YAW_ONLY_BRIDGE", 1, true), "Phase 8F yaw bridge still present")
	local controls = folder and folder:FindFirstChild("RaceSessionControlsClient_Active")
	assert(controls and string.find(controls.Source, "NTR_RACING_PHASE8G_NO_CLIENT_RESET_STOP", 1, true), "session controls still fire reset StopVehicle")
	info("Smoke passed: reset has no client vehicle poke and no Phase 8F yaw bridge.")
end

if MODE == "INSTALL" then
	installTransitionClient()
	restoreBootstrapHandoff()
	rollbackServerResetHelpers()
	patchSessionControls()
	smoke()
	info("Installed. Restart Play before testing reset stability.")
	info("This intentionally prioritises stable drivable reset over checkpoint-facing polish.")
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
