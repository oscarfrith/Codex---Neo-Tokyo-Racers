-- Neo Tokyo Racers - Racing Phase 8D Session Transition Camera Fade
-- Run in Roblox Studio Command Bar in Edit mode after Phase 8C.
--
-- Adds an isolated client transition controller for race/time-trial fades,
-- camera restoration, and free-roam HUD suppression. It canonically replaces
-- the small isolated RaceSessionControlsClient_Active.
--
-- Fragile parts: this also uses guarded exact source anchors against the
-- isolated RaceBrowserClient_Active so TELEPORT TO START can use the fade,
-- and against the Phase 8C reset helpers so reset-to-checkpoint can stop
-- vehicle momentum and face the checkpoint part direction. If either source
-- shape has drifted, refresh the Studio mirror before writing another repair.

local MODE = "INSTALL" -- INSTALL or SMOKE

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[NTR Racing Phase 8D] " .. tostring(message), 2)
end

local function replaceOnce(source, old, new, label)
	local first = string.find(source, old, 1, true)
	if not first then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, old, first + #old, true)
	if second then
		fail("Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, first - 1) .. new .. string.sub(source, first + #old)
end

local function replaceAllPlain(source, old, new)
	local count = 0
	while true do
		local first = string.find(source, old, 1, true)
		if not first then
			break
		end
		source = string.sub(source, 1, first - 1) .. new .. string.sub(source, first + #old)
		count += 1
	end
	return source, count
end

local function racingClientFolder()
	local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	return scripts:WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing")
end

local function racingServiceFolder()
	return ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing")
end

local function ensureBindable(parent, name)
	local child = parent:FindFirstChild(name)
	if child then
		if not child:IsA("BindableEvent") then
			fail(name .. " exists but is not a BindableEvent")
		end
		return child
	end
	child = Instance.new("BindableEvent")
	child.Name = name
	child.Parent = parent
	return child
end

local function transitionClientSource()
	return [====[
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
]====]
end

local function sessionControlsClientSource()
	return [====[
-- Neo Tokyo Racers - Racing Phase 8D Session Controls Client
-- NTR_RACING_PHASE8D_SESSION_CONTROLS_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local racingRemotes = shared:WaitForChild("Remotes"):WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")

local transitionRequest = script.Parent:WaitForChild("RaceTransitionRequest")
local themeFolder = kit:FindFirstChild("Config") and kit.Config:FindFirstChild("UI") and kit.Config.UI:FindFirstChild("Theme")

local function colorValue(name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	if item and item:IsA("Color3Value") then
		return item.Value
	end
	local attr = themeFolder and themeFolder:GetAttribute(name)
	return typeof(attr) == "Color3" and attr or fallback
end

local theme = {
	Panel = colorValue("Panel", Color3.fromRGB(8, 12, 16)),
	Text = colorValue("Text", Color3.fromRGB(240, 255, 249)),
	Accent = colorValue("Accent", Color3.fromRGB(70, 255, 190)),
	Exit = colorValue("Exit", Color3.fromRGB(230, 74, 116)),
	Selected = colorValue("Selected", Color3.fromRGB(255, 68, 196)),
}

local touch = UserInputService.TouchEnabled
local active = nil
local busy = false

local function fireTransition(step, payload)
	payload = payload or {}
	payload.Step = step
	transitionRequest:Fire(payload)
end

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 7)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color or theme.Accent
	item.Thickness = thickness or 1
	item.Transparency = transparency or 0.25
	item.Parent = parent
	return item
end

local function applyFont(label, bold)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json", bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
	end)
end

local function makeButton(parent, name, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = theme.Text
	button.TextSize = touch and 10 or 12
	button.TextWrapped = true
	applyFont(button, true)
	button.Parent = parent
	corner(button, 6)
	stroke(button, color == theme.Exit and theme.Exit or theme.Accent, 1.1, 0.2)
	return button
end

local oldGui = playerGui:FindFirstChild("NTR_RaceSessionControls_Phase8C")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceSessionControls_Phase8D"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 91
gui.Enabled = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -30)
panel.Size = touch and UDim2.fromOffset(390, 48) or UDim2.fromOffset(440, 46)
panel.BackgroundColor3 = theme.Panel
panel.BackgroundTransparency = 0.16
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 7)
stroke(panel, theme.Selected, 1.4, 0.18)

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = panel

local reset = makeButton(panel, "ResetLastCheckpoint", "RESET TO LAST CHECKPOINT", theme.Panel)
reset.Size = UDim2.new(0.62, -8, 1, 0)
local exit = makeButton(panel, "ExitSession", "QUIT RACE", theme.Exit)
exit.Size = UDim2.new(0.38, -8, 1, 0)

local function setActive(payload, mode)
	active = {
		Mode = mode,
		RunId = payload.RunId,
		EventId = payload.EventId,
		RouteId = payload.RouteId,
	}
	panel.Visible = true
	fireTransition("SessionActive", { Active = true, Reason = mode })
end

local function clearActive()
	active = nil
	busy = false
	panel.Visible = false
	reset.Text = "RESET TO LAST CHECKPOINT"
	exit.Text = "QUIT RACE"
	fireTransition("SessionActive", { Active = false, Reason = "ControlsClear" })
end

local function invokeTimeTrial(action)
	local ok, result = pcall(function()
		return raceRequest:InvokeServer(action, {
			RunId = active and active.RunId,
			EventId = active and active.EventId,
			RouteId = active and active.RouteId,
		})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Success = false, Message = tostring(result or "Request failed.") }
end

local function invokeRace(action)
	local ok, result = pcall(function()
		return queueRequest:InvokeServer(action, {
			RunId = active and active.RunId,
			EventId = active and active.EventId,
			RouteId = active and active.RouteId,
		})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Success = false, Message = tostring(result or "Request failed.") }
end

local function doAction(kind)
	if busy or not active then return end
	busy = true
	local labelText = kind == "Reset" and "RESETTING" or "QUITTING"
	fireTransition("FadeOut", { Reason = kind, Label = labelText })
	task.wait(0.25)
	local result
	if active.Mode == "Race" then
		result = invokeRace(kind == "Reset" and "ResetToLastCheckpoint" or "ExitRaceToStart")
	else
		result = invokeTimeTrial(kind == "Reset" and "ResetActiveTimeTrial" or "ExitActiveTimeTrial")
	end
	local ok = result and (result.Ok == true or result.Success == true)
	if ok and kind == "Reset" then
		fireTransition("StopVehicle", { Reason = kind })
	end
	fireTransition("RestoreCamera", { Reason = kind })
	fireTransition("FadeIn", { Reason = kind, Delay = ok and 0.3 or 0.08 })
	if kind == "Reset" then
		reset.Text = ok and "RESET DONE" or tostring(result and result.Message or "RESET FAILED")
		task.delay(1.2, function()
			reset.Text = "RESET TO LAST CHECKPOINT"
			busy = false
		end)
	else
		exit.Text = ok and "QUITTING..." or tostring(result and result.Message or "QUIT FAILED")
		task.delay(ok and 0.35 or 1.4, function()
			if ok then
				clearActive()
			else
				exit.Text = "QUIT RACE"
				busy = false
			end
		end)
	end
end

reset.MouseButton1Click:Connect(function()
	doAction("Reset")
end)

exit.MouseButton1Click:Connect(function()
	doAction("Exit")
end)

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "TimeTrialStaged" or kind == "TimeTrialCountdown" or kind == "TimeTrialStarted" then
		setActive(payload, "TimeTrial")
	elseif kind == "RaceStaged" or kind == "RaceCountdown" or kind == "RaceStarted" then
		setActive(payload, "Race")
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError" or kind == "RaceFinished" or kind == "RaceEnded" then
		clearActive()
	end
end)

queueEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "RaceStaged" or kind == "RaceCountdown" or kind == "RaceStarted" then
		setActive(payload, "Race")
	elseif kind == "RaceFinished" or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceQueueError" then
		clearActive()
	end
end)

print("[NTR Racing Phase 8D Client] Race session controls active.")
]====]
end

local function installTransitionEvents()
	local racing = racingClientFolder()
	ensureBindable(racing, "RaceTransitionRequest")
	ensureBindable(racing, "RaceTransitionStateChanged")
end

local function installTransitionClient()
	local racing = racingClientFolder()
	local client = racing:FindFirstChild("RaceTransitionClient_Active")
	if not client then
		client = Instance.new("LocalScript")
		client.Name = "RaceTransitionClient_Active"
		client.Parent = racing
	elseif not client:IsA("LocalScript") then
		fail("RaceTransitionClient_Active exists but is not a LocalScript")
	end
	client.Source = transitionClientSource()
	client.Disabled = false
end

local function installControlsClient()
	local racing = racingClientFolder()
	local client = racing:FindFirstChild("RaceSessionControlsClient_Active")
	if not client then
		client = Instance.new("LocalScript")
		client.Name = "RaceSessionControlsClient_Active"
		client.Parent = racing
	elseif not client:IsA("LocalScript") then
		fail("RaceSessionControlsClient_Active exists but is not a LocalScript")
	end
	client.Source = sessionControlsClientSource()
	client.Disabled = false
end

local function patchRaceBrowserTeleportFade()
	local browser = racingClientFolder():FindFirstChild("RaceBrowserClient_Active")
	if not browser then
		fail("RaceBrowserClient_Active missing. Install Phase 7B before Phase 8D.")
	end
	if not browser:IsA("LocalScript") then
		fail("RaceBrowserClient_Active is not a LocalScript")
	end
	local source = browser.Source
	if string.find(source, "NTR_RACING_PHASE8D_BROWSER_TELEPORT_FADE", 1, true) then
		local changed = 0
		local count = 0
		source, count = replaceAllPlain(source, 'task.wait(0.12)', 'task.wait(0.25)')
		changed += count
		source, count = replaceAllPlain(source, 'Reason = "BrowserTeleport", Delay = 0.08', 'Reason = "BrowserTeleport", Delay = 0.3')
		changed += count
		source, count = replaceAllPlain(source, 'Reason = "BrowserTeleportFailed", Delay = 0.05', 'Reason = "BrowserTeleportFailed", Delay = 0.08')
		changed += count
		source, count = replaceAllPlain(source, 'Reason = "BrowserTeleportFailed", Delay = 0.3', 'Reason = "BrowserTeleportFailed", Delay = 0.08')
		changed += count
		if changed > 0 then
			browser.Source = source
			print(("[NTR Racing Phase 8D] Updated existing browser teleport fade timings: %d replacements."):format(changed))
		end
		return
	end
	local oldHelper = [[local function fireFreeRoamVehicleExited()
	local ui = controllers and controllers:FindFirstChild("UI")
	local event = ui and ui:FindFirstChild("FreeRoamVehicleExited")
	if event and event:IsA("BindableEvent") then
		event:Fire()
	end
end]]
	local newHelper = oldHelper .. [[

local function fireRaceTransition(step, payload)
	-- NTR_RACING_PHASE8D_BROWSER_TELEPORT_FADE
	local event = script.Parent and script.Parent:FindFirstChild("RaceTransitionRequest")
	if event and event:IsA("BindableEvent") then
		payload = payload or {}
		payload.Step = step
		event:Fire(payload)
	end
end]]
	local oldTeleport = [[local function teleportToStart(row)
	if teleportBusy then
		return
	end
	if not row then
		subtitle.Text = "Select an event first."
		return
	end
	teleportBusy = true
	subtitle.Text = "Teleporting and clearing your current vehicle..."
	local ok, result = pcall(function()
		return raceBrowserTeleportInvoke:InvokeServer("TeleportToRaceStart", {
			EventId = row.Summary.EventId,
			Mode = row.Summary.Mode,
		})
	end)
	teleportBusy = false
	if not ok or typeof(result) ~= "table" or (result.Ok ~= true and result.Success ~= true) then
		subtitle.Text = (typeof(result) == "table" and tostring(result.Message or result.Error)) or "Teleport failed."
		return
	end
	fireFreeRoamVehicleExited()
	if setOpen then
		setOpen(false)
	end
	subtitle.Text = "Teleported. Enter the start zone and press E / tap to open the entry menu."
end]]
	local newTeleport = [[local function teleportToStart(row)
	if teleportBusy then
		return
	end
	if not row then
		subtitle.Text = "Select an event first."
		return
	end
	teleportBusy = true
	subtitle.Text = "Teleporting and clearing your current vehicle..."
	fireRaceTransition("FadeOut", { Reason = "BrowserTeleport", Label = "TELEPORTING" })
	task.wait(0.25)
	local ok, result = pcall(function()
		return raceBrowserTeleportInvoke:InvokeServer("TeleportToRaceStart", {
			EventId = row.Summary.EventId,
			Mode = row.Summary.Mode,
		})
	end)
	teleportBusy = false
	if not ok or typeof(result) ~= "table" or (result.Ok ~= true and result.Success ~= true) then
		fireRaceTransition("FadeIn", { Reason = "BrowserTeleportFailed", Delay = 0.08 })
		subtitle.Text = (typeof(result) == "table" and tostring(result.Message or result.Error)) or "Teleport failed."
		return
	end
	fireFreeRoamVehicleExited()
	if setOpen then
		setOpen(false)
	end
	fireRaceTransition("RestoreCamera", { Reason = "BrowserTeleport" })
	fireRaceTransition("FadeIn", { Reason = "BrowserTeleport", Delay = 0.3 })
	subtitle.Text = "Teleported. Enter the start zone and press E / tap to open the entry menu."
end]]
	source = replaceOnce(source, oldHelper, newHelper, "browser transition helper")
	source = replaceOnce(source, oldTeleport, newTeleport, "browser teleport fade")
	browser.Source = source
end

local function patchResetStationary(serviceName, label)
	local service = racingServiceFolder():FindFirstChild(serviceName)
	if not service then
		fail(serviceName .. " missing. Install Phase 8C before Phase 8D.")
	end
	if not service:IsA("Script") then
		fail(serviceName .. " is not a Script")
	end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE8D_RESET_STATIONARY", 1, true) then
		return
	end
	local oldBlock = [[	if frozen == true then
		setVehicleFrozen(vehicle, true)
	else
		prepareVehicleForDriving(player, vehicle)
	end
	return true, "Vehicle moved."]]
	local newBlock = [[	if frozen == true then
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
	return true, "Vehicle moved."]]
	service.Source = replaceOnce(source, oldBlock, newBlock, label .. " reset stationary handoff")
end

local function patchTimeTrialCheckpointFacing()
	local service = racingServiceFolder():FindFirstChild("TimeTrialService_Active")
	if not service then
		fail("TimeTrialService_Active missing. Install Phase 8C before Phase 8D.")
	end
	if not service:IsA("Script") then
		fail("TimeTrialService_Active is not a Script")
	end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE8D_CHECKPOINT_FACING", 1, true) then
		return
	end
	local oldBlock = [[local function resetCFrameForRun(run)
	local completedGateIndex = tonumber(run and run.LastCompletedGateIndex) or 0
	if completedGateIndex <= 0 then
		return startCFrameForRoute(run.Route, 1) * CFrame.new(0, 4, 0)
	end
	local gate = RouteDefinition.GetGate(run.Route, completedGateIndex)
	local nextGate = RouteDefinition.GetGate(run.Route, math.min(completedGateIndex + 1, run.GateCount or completedGateIndex + 1))
	local base = gate and gate.Part and gate.Part.CFrame or startCFrameForRoute(run.Route, 1)
	local cframe = base * CFrame.new(0, 4, 0)
	if nextGate and nextGate.Part then
		cframe = flatLookCFrame(cframe, nextGate.Part.Position)
	end
	return cframe
end]]
	local newBlock = [[local function resetCFrameForRun(run)
	-- NTR_RACING_PHASE8D_CHECKPOINT_FACING
	-- Completed-checkpoint resets should use the checkpoint part's authored facing.
	local completedGateIndex = tonumber(run and run.LastCompletedGateIndex) or 0
	if completedGateIndex <= 0 then
		return startCFrameForRoute(run.Route, 1) * CFrame.new(0, 4, 0)
	end
	local gate = RouteDefinition.GetGate(run.Route, completedGateIndex)
	if gate and gate.Part then
		return gate.Part.CFrame * CFrame.new(0, 4, 0)
	end
	return startCFrameForRoute(run.Route, 1) * CFrame.new(0, 4, 0)
end]]
	service.Source = replaceOnce(source, oldBlock, newBlock, "time-trial checkpoint-facing reset cframe")
end

local function patchRaceCheckpointFacing()
	local service = racingServiceFolder():FindFirstChild("RaceMatchmakingService_Active")
	if not service then
		fail("RaceMatchmakingService_Active missing. Install Phase 8C before Phase 8D.")
	end
	if not service:IsA("Script") then
		fail("RaceMatchmakingService_Active is not a Script")
	end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE8D_CHECKPOINT_FACING", 1, true) then
		return
	end
	local oldBlock = [[local function resetCFrameForEntry(race, entry)
	local completedGateIndex = tonumber(entry and entry.LastCompletedGateIndex) or 0
	if completedGateIndex <= 0 then
		return spawnCFrameForIndex(race.Route, entry.GridIndex or 1) * CFrame.new(0, 4, 0)
	end
	local gate = RouteDefinition.GetGate(race.Route, completedGateIndex)
	local nextGate = RouteDefinition.GetGate(race.Route, math.min(completedGateIndex + 1, race.GateCount or completedGateIndex + 1))
	local base = gate and gate.Part and gate.Part.CFrame or spawnCFrameForIndex(race.Route, entry.GridIndex or 1)
	local cframe = base * CFrame.new(0, 4, 0)
	if nextGate and nextGate.Part then
		cframe = flatLookCFrame(cframe, nextGate.Part.Position)
	end
	return cframe
end]]
	local newBlock = [[local function resetCFrameForEntry(race, entry)
	-- NTR_RACING_PHASE8D_CHECKPOINT_FACING
	-- Completed-checkpoint resets should use the checkpoint part's authored facing.
	local completedGateIndex = tonumber(entry and entry.LastCompletedGateIndex) or 0
	if completedGateIndex <= 0 then
		return spawnCFrameForIndex(race.Route, entry.GridIndex or 1) * CFrame.new(0, 4, 0)
	end
	local gate = RouteDefinition.GetGate(race.Route, completedGateIndex)
	if gate and gate.Part then
		return gate.Part.CFrame * CFrame.new(0, 4, 0)
	end
	return spawnCFrameForIndex(race.Route, entry.GridIndex or 1) * CFrame.new(0, 4, 0)
end]]
	service.Source = replaceOnce(source, oldBlock, newBlock, "race checkpoint-facing reset cframe")
end

local function patchTimeTrialResetCFramePayload()
	local service = racingServiceFolder():FindFirstChild("TimeTrialService_Active")
	if not service then
		fail("TimeTrialService_Active missing. Install Phase 8C before Phase 8D.")
	end
	if not service:IsA("Script") then
		fail("TimeTrialService_Active is not a Script")
	end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD", 1, true) then
		return
	end
	local oldBlock = [[			NextGateIndex = run.NextGateIndex,
			GateCount = run.GateCount,
			Message = "Reset to last checkpoint.",]]
	local newBlock = [[			NextGateIndex = run.NextGateIndex,
			GateCount = run.GateCount,
			ResetCFrame = resetCFrameForRun(run), -- NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD
			Message = "Reset to last checkpoint.",]]
	service.Source = replaceOnce(source, oldBlock, newBlock, "time-trial reset cframe payload")
end

local function patchRaceResetCFramePayload()
	local service = racingServiceFolder():FindFirstChild("RaceMatchmakingService_Active")
	if not service then
		fail("RaceMatchmakingService_Active missing. Install Phase 8C before Phase 8D.")
	end
	if not service:IsA("Script") then
		fail("RaceMatchmakingService_Active is not a Script")
	end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD", 1, true) then
		return
	end
	local oldBlock = [[			NextGateIndex = entry.NextGateIndex,
			GateCount = race.GateCount,
			Message = "Reset to last checkpoint.",]]
	local newBlock = [[			NextGateIndex = entry.NextGateIndex,
			GateCount = race.GateCount,
			ResetCFrame = resetCFrameForEntry(race, entry), -- NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD
			Message = "Reset to last checkpoint.",]]
	source = replaceOnce(source, oldBlock, newBlock, "race reset cframe payload primary")
	local oldRaceBlock = [[			NextGateIndex = entry.NextGateIndex,
			GateCount = race.GateCount,
		})]]
	local newRaceBlock = [[			NextGateIndex = entry.NextGateIndex,
			GateCount = race.GateCount,
			ResetCFrame = resetCFrameForEntry(race, entry), -- NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD
		})]]
	source = replaceOnce(source, oldRaceBlock, newRaceBlock, "race reset cframe payload queue")
	service.Source = source
end

local function ensureRemotes()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local racing = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
	assert(racing:FindFirstChild("RaceRequest"), "RaceRequest missing")
	assert(racing:FindFirstChild("RaceEvent"), "RaceEvent missing")
	assert(racing:FindFirstChild("RaceQueueRequest"), "RaceQueueRequest missing")
	assert(racing:FindFirstChild("RaceQueueEvent"), "RaceQueueEvent missing")
end

local function install()
	ensureRemotes()
	installTransitionEvents()
	installTransitionClient()
	installControlsClient()
	patchTimeTrialCheckpointFacing()
	patchRaceCheckpointFacing()
	patchTimeTrialResetCFramePayload()
	patchRaceResetCFramePayload()
	patchResetStationary("TimeTrialService_Active", "time-trial")
	patchResetStationary("RaceMatchmakingService_Active", "race")
	patchRaceBrowserTeleportFade()
	print("[NTR Racing Phase 8D] Installed transition fade/camera/HUD polish.")
	print("[NTR Racing Phase 8D] Reset-to-checkpoint now re-zeroes vehicle velocity after the driving handoff.")
	print("[NTR Racing Phase 8D] Reward config, route-guide config, and checkpoint visuals were not edited.")
end

local function smoke()
	local racing = racingClientFolder()
	local transitionEvent = racing:FindFirstChild("RaceTransitionRequest")
	assert(transitionEvent and transitionEvent:IsA("BindableEvent"), "RaceTransitionRequest missing")
	local transition = racing:FindFirstChild("RaceTransitionClient_Active")
	assert(transition and transition:IsA("LocalScript") and transition.Disabled == false, "RaceTransitionClient_Active missing/disabled")
	assert(string.find(transition.Source, "NTR_RACING_PHASE8D_TRANSITION_CLIENT", 1, true), "transition source marker missing")
	local controls = racing:FindFirstChild("RaceSessionControlsClient_Active")
	assert(controls and controls:IsA("LocalScript") and controls.Disabled == false, "RaceSessionControlsClient_Active missing/disabled")
	assert(string.find(controls.Source, "NTR_RACING_PHASE8D_SESSION_CONTROLS_CLIENT", 1, true), "controls source marker missing")
	assert(string.find(controls.Source, "QUIT RACE", 1, true), "QUIT RACE button text missing")
	local browser = racing:FindFirstChild("RaceBrowserClient_Active")
	assert(browser and string.find(browser.Source, "NTR_RACING_PHASE8D_BROWSER_TELEPORT_FADE", 1, true), "browser fade marker missing")
	local tt = racingServiceFolder():FindFirstChild("TimeTrialService_Active")
	assert(tt and string.find(tt.Source, "NTR_RACING_PHASE8D_RESET_STATIONARY", 1, true), "time-trial reset stationary marker missing")
	assert(tt and string.find(tt.Source, "NTR_RACING_PHASE8D_CHECKPOINT_FACING", 1, true), "time-trial checkpoint-facing marker missing")
	assert(tt and string.find(tt.Source, "NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD", 1, true), "time-trial reset cframe payload marker missing")
	local race = racingServiceFolder():FindFirstChild("RaceMatchmakingService_Active")
	assert(race and string.find(race.Source, "NTR_RACING_PHASE8D_RESET_STATIONARY", 1, true), "race reset stationary marker missing")
	assert(race and string.find(race.Source, "NTR_RACING_PHASE8D_CHECKPOINT_FACING", 1, true), "race checkpoint-facing marker missing")
	assert(race and string.find(race.Source, "NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD", 1, true), "race reset cframe payload marker missing")
	print("[NTR Racing Phase 8D] Smoke passed.")
end

if MODE == "INSTALL" then
	install()
	smoke()
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
