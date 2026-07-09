-- NTR Racing Phase 8H - Respawn Reset System
-- Reset now fades, discards the active race vehicle, and spawns a clean clone of
-- that same race vehicle at the checkpoint reset pose. This gives zero momentum
-- by design and lets checkpoint-facing come from the reset CFrame without
-- fighting an already-running physics assembly.
--
-- Scope:
--   * Replaces RaceTransitionClient_Active with presentation-only reset handling.
--   * Removes duplicate client StopVehicle from RaceSessionControlsClient_Active.
--   * Replaces isolated Racing service reset pivot helpers with clone-respawn
--     helpers and updates the active session's Vehicle reference.
--   * Does not edit rewards, route-guide config, route attributes, VFX, or
--     general free-roam vehicle spawn systems.

local MODE = "INSTALL" -- INSTALL or SMOKE

local function info(message)
	print("[NTR Racing Phase 8H] " .. tostring(message))
end

local function fail(message)
	error("[NTR Racing Phase 8H] " .. tostring(message), 2)
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

local function replaceFunctionBefore(source, functionName, nextFunctionName, replacement)
	local needle = "local function " .. functionName .. "("
	local startIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find function " .. functionName .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, needle, startIndex + 1, true)
	if second then
		fail("Function " .. functionName .. " matched more than once. Refusing ambiguous replacement.")
	end
	local nextNeedle = "\nlocal function " .. nextFunctionName .. "("
	local nextIndex = string.find(source, nextNeedle, startIndex + 1, true)
	if not nextIndex then
		fail("Could not find boundary function " .. nextFunctionName .. " after " .. functionName .. ".")
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, nextIndex)
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

local function serverRacingFolder()
	local serverScriptService = game:GetService("ServerScriptService")
	local root = serverScriptService:FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	return services and services:FindFirstChild("Racing")
end

local TRANSITION_CLIENT_SOURCE = [==[
-- NTR_RACING_PHASE8H_TRANSITION_CLIENT

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
	fadeOut("STAGING")
	task.delay(0.22, function() restoreCamera(reason) end)
	task.delay(0.78, function() fadeIn(0) end)
end

local function finishTransition(reason)
	restoreCamera(reason)
	fadeIn(0.18)
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

local function handleRacePayload(payload)
	if typeof(payload) ~= "table" then return end
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
	if typeof(payload) ~= "table" then return end
	local step = tostring(payload.Step or "")
	if step == "SessionActive" then
		setSessionActive(payload.Active == true, payload.Reason or step)
		if sessionActive then suppressFreeRoamHud() end
	elseif step == "FadeOut" then
		fadeOut(payload.Label or "")
	elseif step == "FadeIn" then
		fadeIn(payload.Delay)
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

RunService.Heartbeat:Connect(function()
	if sessionActive and os.clock() - lastHudPulse > 0.2 then
		lastHudPulse = os.clock()
		suppressFreeRoamHud()
	end
end)

player.CharacterAdded:Connect(function()
	task.delay(0.35, function()
		restoreCamera("CharacterAdded")
		if not sessionActive then fadeIn(0) end
	end)
end)

print("[NTR Racing Phase 8H Client] Transition/camera controller active; reset respawns server-side.")
]==]

local RESPAWN_SESSION_FUNCTION = [==[local function pivotVehicleForSession(player, vehicle, targetCFrame, frozen)
	-- NTR_RACING_PHASE8H_RESPAWN_RESET
	local vehiclesRoot = runtimeVehiclesRoot()
	local root = vehicleRootPart(vehicle)
	if not (vehiclesRoot and vehicle and vehicle.Parent and root) then
		return false, "Vehicle root missing."
	end

	local oldName = vehicle.Name
	local oldArchivable = vehicle.Archivable
	vehicle.Archivable = true
	local replacement = vehicle:Clone()
	vehicle.Archivable = oldArchivable
	if not replacement then
		return false, "Could not clone race vehicle."
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:Destroy()

	replacement.Name = oldName
	replacement.Parent = vehiclesRoot
	local replacementRoot = vehicleRootPart(replacement)
	if not replacementRoot then
		replacement:Destroy()
		return false, "Replacement vehicle root missing."
	end
	replacement.PrimaryPart = replacementRoot
	replacement:SetAttribute("NTR_RaceFrozen", false)
	replacement:SetAttribute("DriveReady", false)
	replacement:SetAttribute("DriverUserId", player.UserId)
	replacement:PivotTo(targetCFrame)
	zeroModelVelocity(replacement)
	seatPlayer(player, replacement)
	task.wait(0.08)
	if frozen == true then
		setVehicleFrozen(replacement, true)
		zeroModelVelocity(replacement)
	else
		prepareVehicleForDriving(player, replacement)
		task.delay(0.08, function()
			if replacement and replacement.Parent then
				zeroModelVelocity(replacement)
			end
		end)
		task.delay(0.24, function()
			if replacement and replacement.Parent then
				zeroModelVelocity(replacement)
			end
		end)
	end
	return true, "Vehicle respawned.", replacement
end]==]

local RESPAWN_RACE_FUNCTION = [==[local function pivotVehicleForRace(player, vehicle, targetCFrame, frozen)
	-- NTR_RACING_PHASE8H_RESPAWN_RESET
	local vehiclesRoot = runtimeVehiclesRoot()
	local root = vehicleRootPart(vehicle)
	if not (vehiclesRoot and vehicle and vehicle.Parent and root) then
		return false, "Vehicle root missing."
	end

	local oldName = vehicle.Name
	local oldArchivable = vehicle.Archivable
	vehicle.Archivable = true
	local replacement = vehicle:Clone()
	vehicle.Archivable = oldArchivable
	if not replacement then
		return false, "Could not clone race vehicle."
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:Destroy()

	replacement.Name = oldName
	replacement.Parent = vehiclesRoot
	local replacementRoot = vehicleRootPart(replacement)
	if not replacementRoot then
		replacement:Destroy()
		return false, "Replacement vehicle root missing."
	end
	replacement.PrimaryPart = replacementRoot
	replacement:SetAttribute("NTR_RaceFrozen", false)
	replacement:SetAttribute("DriveReady", false)
	replacement:SetAttribute("DriverUserId", player.UserId)
	replacement:PivotTo(targetCFrame)
	zeroModelVelocity(replacement)
	seatPlayer(player, replacement)
	task.wait(0.08)
	if frozen == true then
		setVehicleFrozen(replacement, true)
		zeroModelVelocity(replacement)
	else
		prepareVehicleForDriving(player, replacement)
		task.delay(0.08, function()
			if replacement and replacement.Parent then
				zeroModelVelocity(replacement)
			end
		end)
		task.delay(0.24, function()
			if replacement and replacement.Parent then
				zeroModelVelocity(replacement)
			end
		end)
	end
	return true, "Vehicle respawned.", replacement
end]==]

local TT_RESET_CALL = [==[	local ok, message = pivotVehicleForSession(player, run.Vehicle, resetCFrameForRun(run), run.State == "Staging")
	if ok then]==]

local TT_RESET_CALL_NEW = [==[	local ok, message, replacementVehicle = pivotVehicleForSession(player, run.Vehicle, resetCFrameForRun(run), run.State == "Staging")
	if ok and replacementVehicle then
		run.Vehicle = replacementVehicle
	end
	if ok then]==]

local RACE_RESET_CALL = [==[	local ok, message = pivotVehicleForRace(player, entry.Vehicle, resetCFrameForEntry(race, entry), race.State == "Staging")
	if ok then]==]

local RACE_RESET_CALL_NEW = [==[	local ok, message, replacementVehicle = pivotVehicleForRace(player, entry.Vehicle, resetCFrameForEntry(race, entry), race.State == "Staging")
	if ok and replacementVehicle then
		entry.Vehicle = replacementVehicle
	end
	if ok then]==]

local STOP_VEHICLE_BLOCK = [==[	if ok and kind == "Reset" then
		fireTransition("StopVehicle", { Reason = kind })
	end
	fireTransition("RestoreCamera", { Reason = kind })]==]

local NO_STOP_VEHICLE_BLOCK = [==[	if ok and kind == "Reset" then
		-- NTR_RACING_PHASE8H_NO_CLIENT_RESET_STOP
		-- The server respawns the reset vehicle; do not also poke it locally.
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
	info("Replaced RaceTransitionClient_Active with respawn-reset presentation client.")
end

local function patchSessionControls()
	local folder = clientRacingFolder()
	local scriptObject = folder and folder:FindFirstChild("RaceSessionControlsClient_Active")
	if not (scriptObject and scriptObject:IsA("LocalScript")) then
		fail("Could not find RaceSessionControlsClient_Active.")
	end
	if string.find(scriptObject.Source, "NTR_RACING_PHASE8H_NO_CLIENT_RESET_STOP", 1, true)
		or string.find(scriptObject.Source, "NTR_RACING_PHASE8G_NO_CLIENT_RESET_STOP", 1, true) then
		info("RaceSessionControlsClient_Active already avoids client reset StopVehicle.")
		return
	end
	scriptObject.Source = replaceOnce(scriptObject.Source, STOP_VEHICLE_BLOCK, NO_STOP_VEHICLE_BLOCK, "session controls reset StopVehicle block")
	info("Removed duplicate client StopVehicle call from reset button.")
end

local function patchTimeTrialService()
	local folder = serverRacingFolder()
	local service = folder and folder:FindFirstChild("TimeTrialService_Active")
	if not (service and service:IsA("Script")) then
		fail("Could not find TimeTrialService_Active.")
	end
	local source = service.Source
	if not string.find(source, "NTR_RACING_PHASE8H_RESPAWN_RESET", 1, true) then
		source = replaceFunctionBefore(source, "pivotVehicleForSession", "unseatPlayer", RESPAWN_SESSION_FUNCTION)
	end
	if not string.find(source, "replacementVehicle = pivotVehicleForSession", 1, true) then
		source = replaceOnce(source, TT_RESET_CALL, TT_RESET_CALL_NEW, "time-trial reset vehicle reference update")
	end
	service.Source = source
	info("Patched TimeTrialService_Active with respawn reset.")
end

local function patchRaceService()
	local folder = serverRacingFolder()
	local service = folder and folder:FindFirstChild("RaceMatchmakingService_Active")
	if not (service and service:IsA("Script")) then
		fail("Could not find RaceMatchmakingService_Active.")
	end
	local source = service.Source
	if not string.find(source, "NTR_RACING_PHASE8H_RESPAWN_RESET", 1, true) then
		source = replaceFunctionBefore(source, "pivotVehicleForRace", "unseatPlayer", RESPAWN_RACE_FUNCTION)
	end
	if not string.find(source, "replacementVehicle = pivotVehicleForRace", 1, true) then
		source = replaceOnce(source, RACE_RESET_CALL, RACE_RESET_CALL_NEW, "race reset vehicle reference update")
	end
	service.Source = source
	info("Patched RaceMatchmakingService_Active with respawn reset.")
end

local function smoke()
	local folder = clientRacingFolder()
	local transition = folder and folder:FindFirstChild("RaceTransitionClient_Active")
	assert(transition and transition:IsA("LocalScript"), "RaceTransitionClient_Active missing")
	assert(string.find(transition.Source, "NTR_RACING_PHASE8H_TRANSITION_CLIENT", 1, true), "Phase 8H transition marker missing")
	assert(string.find(transition.Source, "NTR_RACING_PHASE8H_RESET_PRESENTATION_ONLY", 1, true), "presentation-only reset marker missing")
	assert(not string.find(transition.Source, "AssemblyLinearVelocity = Vector3.zero", 1, true), "transition client still zeros vehicle velocity")
	assert(not string.find(transition.Source, "SyncDrivingYaw", 1, true), "transition client still requests yaw sync")
	local controls = folder and folder:FindFirstChild("RaceSessionControlsClient_Active")
	assert(controls and (
		string.find(controls.Source, "NTR_RACING_PHASE8H_NO_CLIENT_RESET_STOP", 1, true)
		or string.find(controls.Source, "NTR_RACING_PHASE8G_NO_CLIENT_RESET_STOP", 1, true)
	), "session controls still fire reset StopVehicle")
	local serverFolder = serverRacingFolder()
	local timeTrial = serverFolder and serverFolder:FindFirstChild("TimeTrialService_Active")
	local race = serverFolder and serverFolder:FindFirstChild("RaceMatchmakingService_Active")
	assert(timeTrial and string.find(timeTrial.Source, "NTR_RACING_PHASE8H_RESPAWN_RESET", 1, true), "time-trial respawn reset missing")
	assert(race and string.find(race.Source, "NTR_RACING_PHASE8H_RESPAWN_RESET", 1, true), "race respawn reset missing")
	info("Smoke passed: Phase 8H respawn reset system is installed.")
end

if MODE == "INSTALL" then
	installTransitionClient()
	patchSessionControls()
	patchTimeTrialService()
	patchRaceService()
	smoke()
	info("Installed. Restart Play before testing reset-to-checkpoint.")
	info("Reset now respawns a clean race vehicle clone at the reset pose.")
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
