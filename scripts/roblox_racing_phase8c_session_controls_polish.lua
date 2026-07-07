-- Neo Tokyo Racers - Racing Phase 8C Session Controls Polish
-- Run in Roblox Studio Command Bar in Edit mode after Phase 8B.
--
-- Adds server-owned reset/exit controls for active races/time trials, removes
-- the pre-staging driving handoff that caused first-start camera/spawn wobble,
-- and returns quitters to the route start teleport point.
--
-- This script uses guarded exact source patches against isolated Racing scripts.
-- If an anchor fails, refresh the Studio mirror before writing another repair.

local MODE = "INSTALL" -- INSTALL or SMOKE

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[NTR Racing Phase 8C] " .. tostring(message), 2)
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

local function racingClientFolder()
	local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	return scripts:WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing")
end

local function racingServiceFolder()
	return ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing")
end

local function ensureRemotes()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local shared = kit:WaitForChild("Shared")
	local remotes = shared:WaitForChild("Remotes")
	local racing = remotes:WaitForChild("Racing")
	if not racing:FindFirstChild("RaceQueueRequest") then
		fail("RaceQueueRequest missing. Install Phase 8 before Phase 8C.")
	end
	if not racing:FindFirstChild("RaceRequest") then
		fail("RaceRequest missing. Install Racing runtime before Phase 8C.")
	end
end

local function sessionControlsClientSource()
	return [====[
-- Neo Tokyo Racers - Racing Phase 8C Session Controls Client
-- NTR_RACING_PHASE8C_SESSION_CONTROLS_CLIENT

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
	Muted = colorValue("Muted", Color3.fromRGB(145, 170, 165)),
	Accent = colorValue("Accent", Color3.fromRGB(70, 255, 190)),
	Exit = colorValue("Exit", Color3.fromRGB(230, 74, 116)),
	Selected = colorValue("Selected", Color3.fromRGB(255, 68, 196)),
}

local touch = UserInputService.TouchEnabled
local active = nil
local busy = false

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
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
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

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceSessionControls_Phase8C"
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
local exit = makeButton(panel, "ExitSession", "EXIT TO START", theme.Exit)
exit.Size = UDim2.new(0.38, -8, 1, 0)

local function setActive(payload, mode)
	active = {
		Mode = mode,
		RunId = payload.RunId,
		EventId = payload.EventId,
		RouteId = payload.RouteId,
	}
	panel.Visible = true
end

local function clearActive()
	active = nil
	busy = false
	panel.Visible = false
	reset.Text = "RESET TO LAST CHECKPOINT"
	exit.Text = "EXIT TO START"
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
	local result
	if active.Mode == "Race" then
		result = invokeRace(kind == "Reset" and "ResetToLastCheckpoint" or "ExitRaceToStart")
	else
		result = invokeTimeTrial(kind == "Reset" and "ResetActiveTimeTrial" or "ExitActiveTimeTrial")
	end
	local ok = result and (result.Ok == true or result.Success == true)
	if kind == "Reset" then
		reset.Text = ok and "RESET DONE" or tostring(result and result.Message or "RESET FAILED")
		task.delay(1.2, function()
			reset.Text = "RESET TO LAST CHECKPOINT"
			busy = false
		end)
	else
		exit.Text = ok and "EXITING..." or tostring(result and result.Message or "EXIT FAILED")
		task.delay(ok and 0.5 or 1.4, function()
			if ok then
				clearActive()
			else
				exit.Text = "EXIT TO START"
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

print("[NTR Racing Phase 8C Client] Race session controls active.")
]====]
end

local function patchEntryMenuClient()
	local client = racingClientFolder():WaitForChild("RaceEntryMenuClient_Active")
	if not client:IsA("LocalScript") then
		fail("RaceEntryMenuClient_Active is not a LocalScript")
	end
	local source = client.Source
	if string.find(source, "NTR_RACING_PHASE8C_NO_PRE_STAGE_HANDOFF", 1, true) then
		return
	end
	local oldBlock = [[			local clientRoot = script.Parent.Parent
			local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
			local spawnedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
			if spawnedEvent and spawnedEvent:IsA("BindableEvent") then
				spawnedEvent:Fire()
			end
			task.wait(0.35)]]
	local newBlock = [[			-- NTR_RACING_PHASE8C_NO_PRE_STAGE_HANDOFF
			-- Do not fire the free-roam driving handoff before Racing teleports/freezes the car.
			-- TimeTrialStarted/RaceStarted fire the handoff at GO, matching the cleaner retry path.
			task.wait(0.35)]]
	local first = string.find(source, oldBlock, 1, true)
	if not first then
		fail("Could not find source anchor: pre-stage handoff block. Refresh the Studio mirror before another repair.")
	end
	source = string.sub(source, 1, first - 1) .. newBlock .. string.sub(source, first + #oldBlock)
	local second = string.find(source, oldBlock, 1, true)
	if not second then
		fail("Could not find second source anchor: pre-stage handoff block. Refresh the Studio mirror before another repair.")
	end
	source = string.sub(source, 1, second - 1) .. newBlock .. string.sub(source, second + #oldBlock)
	client.Source = source
end

local timeTrialHelpers = [====[

-- NTR_RACING_PHASE8C_SESSION_CONTROL_HELPERS
local function zeroModelVelocity(model)
	for _, descendant in ipairs(model and model:GetDescendants() or {}) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function flatLookCFrame(baseCFrame, targetPosition)
	local position = baseCFrame.Position
	if typeof(targetPosition) ~= "Vector3" then
		return baseCFrame
	end
	local target = Vector3.new(targetPosition.X, position.Y, targetPosition.Z)
	if (target - position).Magnitude < 1 then
		return baseCFrame
	end
	return CFrame.lookAt(position, target)
end

local function firstBasePart(folder)
	for _, item in ipairs(folder and folder:GetChildren() or {}) do
		if item:IsA("BasePart") then
			return item
		end
	end
	return nil
end

local function routeTeleportPoint(route, mode)
	local folder = route and route.Folder
	local points = folder and folder:FindFirstChild("TeleportPoints")
	if not points then return nil end
	mode = tostring(mode or "TimeTrial")
	local preferred = points:FindFirstChild(mode .. "TeleportPoint")
		or points:FindFirstChild(mode .. "StartTeleport")
		or points:FindFirstChild("RaceBrowserTeleportPoint")
		or points:FindFirstChild("StartTeleportPoint")
	if preferred and preferred:IsA("BasePart") then
		return preferred
	end
	return firstBasePart(points)
end

local function startCFrameForRoute(route, gateIndex)
	local base = RouteDefinition.GetFirstSpawnCFrame(route)
	local gate = RouteDefinition.GetGate(route, gateIndex or 1)
	if gate and gate.Part then
		return flatLookCFrame(base, gate.Part.Position)
	end
	return base
end

local function returnCFrameForRoute(route, mode)
	local point = routeTeleportPoint(route, mode)
	if point then
		return point.CFrame * CFrame.new(0, 4, 0)
	end
	return startCFrameForRoute(route, 1) * CFrame.new(0, 4, 0)
end

local function resetCFrameForRun(run)
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
end

local function pivotVehicleForSession(player, vehicle, targetCFrame, frozen)
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
	else
		prepareVehicleForDriving(player, vehicle)
	end
	return true, "Vehicle moved."
end

local function unseatPlayer(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
end

local function teleportCharacterTo(player, targetCFrame)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false, "Character root not ready."
	end
	local wasAnchored = root.Anchored
	root.Anchored = true
	zeroModelVelocity(character)
	character:PivotTo(targetCFrame)
	zeroModelVelocity(character)
	task.delay(0.2, function()
		if root and root.Parent then
			root.Anchored = wasAnchored
		end
	end)
	return true, "Teleported."
end

local function destroyVehicleAfterUnseat(player, vehicle)
	if not (vehicle and vehicle.Parent) then return end
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:SetAttribute("NTR_RaceRunId", nil)
	vehicle:SetAttribute("NTR_RaceParticipant", nil)
	vehicle:SetAttribute("NTR_RaceMode", nil)
	unseatPlayer(player)
	task.wait(0.08)
	if vehicle and vehicle.Parent then
		vehicle:Destroy()
	end
end

local function resetActiveTimeTrial(player)
	local run = activeRuns[player]
	if not run then
		return { Ok = false, Success = false, Message = "No active time trial." }
	end
	if not (run.State == "Running" or run.State == "Staging") then
		return { Ok = false, Success = false, Message = "Time trial cannot reset right now." }
	end
	if os.clock() - (run.LastResetClock or 0) < 1.5 then
		return { Ok = false, Success = false, Message = "Reset is cooling down." }
	end
	run.LastResetClock = os.clock()
	local ok, message = pivotVehicleForSession(player, run.Vehicle, resetCFrameForRun(run), run.State == "Staging")
	if ok then
		fire(player, {
			Type = "TimeTrialReset",
			RunId = run.RunId,
			EventId = run.EventId,
			RouteId = run.RouteId,
			NextGateIndex = run.NextGateIndex,
			GateCount = run.GateCount,
			Message = "Reset to last checkpoint.",
		})
	end
	return { Ok = ok, Success = ok, Message = message }
end

local function exitActiveTimeTrial(player)
	local run = activeRuns[player]
	if not run then
		return { Ok = false, Success = false, Message = "No active time trial." }
	end
	activeRuns[player] = nil
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)
	fire(player, {
		Type = "TimeTrialEnded",
		RunId = run.RunId,
		EventId = run.EventId,
		RouteId = run.RouteId,
		Reason = "Exited to start",
	})
	local target = returnCFrameForRoute(run.Route, "TimeTrial")
	destroyVehicleAfterUnseat(player, run.Vehicle)
	teleportCharacterTo(player, target)
	return { Ok = true, Success = true, Message = "Exited to race start." }
end
]====]

local raceHelpers = [====[

-- NTR_RACING_PHASE8C_SESSION_CONTROL_HELPERS
local function zeroModelVelocity(model)
	for _, descendant in ipairs(model and model:GetDescendants() or {}) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function flatLookCFrame(baseCFrame, targetPosition)
	local position = baseCFrame.Position
	if typeof(targetPosition) ~= "Vector3" then
		return baseCFrame
	end
	local target = Vector3.new(targetPosition.X, position.Y, targetPosition.Z)
	if (target - position).Magnitude < 1 then
		return baseCFrame
	end
	return CFrame.lookAt(position, target)
end

local function firstBasePart(folder)
	for _, item in ipairs(folder and folder:GetChildren() or {}) do
		if item:IsA("BasePart") then
			return item
		end
	end
	return nil
end

local function routeTeleportPoint(route, mode)
	local folder = route and route.Folder
	local points = folder and folder:FindFirstChild("TeleportPoints")
	if not points then return nil end
	mode = tostring(mode or "Race")
	local preferred = points:FindFirstChild(mode .. "TeleportPoint")
		or points:FindFirstChild(mode .. "StartTeleport")
		or points:FindFirstChild("RaceBrowserTeleportPoint")
		or points:FindFirstChild("StartTeleportPoint")
	if preferred and preferred:IsA("BasePart") then
		return preferred
	end
	return firstBasePart(points)
end

local function startCFrameForRoute(route, gateIndex)
	local base = RouteDefinition.GetFirstSpawnCFrame(route)
	local gate = RouteDefinition.GetGate(route, gateIndex or 1)
	if gate and gate.Part then
		return flatLookCFrame(base, gate.Part.Position)
	end
	return base
end

local function returnCFrameForRoute(route, mode)
	local point = routeTeleportPoint(route, mode)
	if point then
		return point.CFrame * CFrame.new(0, 4, 0)
	end
	return startCFrameForRoute(route, 1) * CFrame.new(0, 4, 0)
end

local function resetCFrameForEntry(race, entry)
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
end

local function pivotVehicleForRace(player, vehicle, targetCFrame, frozen)
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
	else
		prepareVehicleForDriving(player, vehicle)
	end
	return true, "Vehicle moved."
end

local function unseatPlayer(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
end

local function teleportCharacterTo(player, targetCFrame)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false, "Character root not ready."
	end
	local wasAnchored = root.Anchored
	root.Anchored = true
	zeroModelVelocity(character)
	character:PivotTo(targetCFrame)
	zeroModelVelocity(character)
	task.delay(0.2, function()
		if root and root.Parent then
			root.Anchored = wasAnchored
		end
	end)
	return true, "Teleported."
end

local function destroyVehicleAfterUnseat(player, vehicle)
	if not (vehicle and vehicle.Parent) then return end
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:SetAttribute("NTR_RaceRunId", nil)
	vehicle:SetAttribute("NTR_RaceParticipant", nil)
	vehicle:SetAttribute("NTR_RaceMode", nil)
	unseatPlayer(player)
	task.wait(0.08)
	if vehicle and vehicle.Parent then
		vehicle:Destroy()
	end
end

local function entryForPlayer(race, player)
	for _, entry in ipairs(race and race.Participants or {}) do
		if entry.Player == player then
			return entry
		end
	end
	return nil
end

local function fireActiveRaceVisibility(race)
	local participants = {}
	for _, entry in ipairs(race and race.Participants or {}) do
		if entry.Player and entry.DNF ~= true then
			table.insert(participants, entry.Player.UserId)
		end
	end
	raceEvent:FireAllClients({
		Type = "RaceVisibilityUpdate",
		Active = #participants > 0,
		RunId = race and race.RunId or "",
		Participants = participants,
	})
end

local function resetRacePlayer(player)
	local race = activeRaceByPlayer[player]
	local entry = entryForPlayer(race, player)
	if not (race and entry) then
		return { Ok = false, Success = false, Message = "No active race." }
	end
	if entry.Finished == true then
		return { Ok = false, Success = false, Message = "Race already finished." }
	end
	if not (race.State == "Running" or race.State == "Staging") then
		return { Ok = false, Success = false, Message = "Race cannot reset right now." }
	end
	if os.clock() - (entry.LastResetClock or 0) < 1.5 then
		return { Ok = false, Success = false, Message = "Reset is cooling down." }
	end
	entry.LastResetClock = os.clock()
	local ok, message = pivotVehicleForRace(player, entry.Vehicle, resetCFrameForEntry(race, entry), race.State == "Staging")
	if ok then
		fire(player, {
			Type = "RaceReset",
			RunId = race.RunId,
			EventId = race.EventId,
			RouteId = race.RouteId,
			NextGateIndex = entry.NextGateIndex,
			GateCount = race.GateCount,
			Message = "Reset to last checkpoint.",
		})
		fireRace(player, {
			Type = "RaceReset",
			RunId = race.RunId,
			EventId = race.EventId,
			RouteId = race.RouteId,
			NextGateIndex = entry.NextGateIndex,
			GateCount = race.GateCount,
		})
	end
	return { Ok = ok, Success = ok, Message = message }
end

local function exitRacePlayer(player)
	local race = activeRaceByPlayer[player]
	local entry = entryForPlayer(race, player)
	if not (race and entry) then
		return { Ok = false, Success = false, Message = "No active race." }
	end
	entry.Finished = true
	entry.DNF = true
	activeRaceByPlayer[player] = nil
	local target = returnCFrameForRoute(race.Route, "Race")
	fire(player, {
		Type = "RaceDNF",
		RunId = race.RunId,
		EventId = race.EventId,
		Message = "Exited race.",
	})
	fireRace(player, {
		Type = "RaceEnded",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Reason = "Exited race",
	})
	destroyVehicleAfterUnseat(player, entry.Vehicle)
	entry.Vehicle = nil
	teleportCharacterTo(player, target)
	fireActiveRaceVisibility(race)
	broadcastPositions(race)
	if allFinished(race) then
		cleanupRace(race, "All racers finished or exited.")
	end
	return { Ok = true, Success = true, Message = "Exited to race start." }
end
]====]

local function patchTimeTrialService()
	local service = racingServiceFolder():WaitForChild("TimeTrialService_Active")
	if not service:IsA("Script") then
		fail("TimeTrialService_Active is not a Script")
	end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE8C_SESSION_CONTROL_HELPERS", 1, true) then
		return
	end
	source = replaceOnce(source,
		[[local function prepareVehicleForDriving(player, vehicle)
	-- NTR_RACING_PHASE3E_RELEASE_HANDOFF
	local root = vehicleRootPart(vehicle)
	if not root then return end
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	vehicle:SetAttribute("NTR_RaceFrozen", false)
	vehicle:SetAttribute("DriveReady", true)
	vehicle:SetAttribute("ParkedShowcase", nil)
	vehicle:SetAttribute("DriverUserId", player.UserId)
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	seatPlayer(player, vehicle)
end]],
		[[local function prepareVehicleForDriving(player, vehicle)
	-- NTR_RACING_PHASE3E_RELEASE_HANDOFF
	local root = vehicleRootPart(vehicle)
	if not root then return end
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	vehicle:SetAttribute("NTR_RaceFrozen", false)
	vehicle:SetAttribute("DriveReady", true)
	vehicle:SetAttribute("ParkedShowcase", nil)
	vehicle:SetAttribute("DriverUserId", player.UserId)
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	seatPlayer(player, vehicle)
end]] .. timeTrialHelpers,
		"time-trial session control helpers")
	source = replaceOnce(source,
		[[	local stageCFrame = RouteDefinition.GetFirstSpawnCFrame(route)
	vehicle.PrimaryPart = root
	vehicle:PivotTo(stageCFrame + Vector3.new(0, 4, 0))]],
		[[	local stageCFrame = startCFrameForRoute(route, 1)
	vehicle.PrimaryPart = root
	vehicle:PivotTo(stageCFrame * CFrame.new(0, 4, 0))]],
		"time-trial stable staging cframe")
	source = replaceOnce(source,
		[[		NextGateIndex = 1,
		GateCount = RouteDefinition.GetGateCount(route),
		Splits = {},]],
		[[		NextGateIndex = 1,
		LastCompletedGateIndex = 0,
		GateCount = RouteDefinition.GetGateCount(route),
		Splits = {},]],
		"time-trial last checkpoint state")
	source = replaceOnce(source,
		[[	run.NextGateIndex += 1
	fire(player, {
		Type = "TimeTrialCheckpoint",]],
		[[	run.LastCompletedGateIndex = run.NextGateIndex
	run.NextGateIndex += 1
	fire(player, {
		Type = "TimeTrialCheckpoint",]],
		"time-trial checkpoint progress state")
	source = replaceOnce(source,
		[[	elseif action == "CancelTimeTrial" then
		endRun(player, "Cancelled")
		return { Ok = true, Success = true, Message = "Cancelled" }
	elseif action == "GetRouteSummary" then]],
		[[	elseif action == "CancelTimeTrial" then
		endRun(player, "Cancelled")
		return { Ok = true, Success = true, Message = "Cancelled" }
	elseif action == "ResetActiveTimeTrial" then
		return resetActiveTimeTrial(player)
	elseif action == "ExitActiveTimeTrial" then
		return exitActiveTimeTrial(player)
	elseif action == "GetRouteSummary" then]],
		"time-trial control request actions")
	service.Source = source
end

local function patchRaceMatchmakingService()
	local service = racingServiceFolder():WaitForChild("RaceMatchmakingService_Active")
	if not service:IsA("Script") then
		fail("RaceMatchmakingService_Active is not a Script")
	end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE8C_SESSION_CONTROL_HELPERS", 1, true) then
		return
	end
	source = replaceOnce(source,
		[[local function allFinished(race)
	for _, entry in ipairs(race.Participants or {}) do
		if entry.Finished ~= true then
			return false
		end
	end
	return true
end]],
		[[local function allFinished(race)
	for _, entry in ipairs(race.Participants or {}) do
		if entry.Finished ~= true then
			return false
		end
	end
	return true
end]] .. raceHelpers,
		"race session control helpers")
	source = replaceOnce(source,
		[[local function spawnCFrameForIndex(route, index)
	local grid = route and route.SpawnGrid
	local item = grid and grid[index]
	if item and item.Part then
		return item.Part.CFrame
	end
	return RouteDefinition.GetFirstSpawnCFrame(route) * CFrame.new((index - 1) * 10, 0, 0)
end]],
		[[local function spawnCFrameForIndex(route, index)
	local grid = route and route.SpawnGrid
	local item = grid and grid[index]
	local base = item and item.Part and item.Part.CFrame or RouteDefinition.GetFirstSpawnCFrame(route) * CFrame.new((index - 1) * 10, 0, 0)
	local gate = RouteDefinition.GetGate(route, 1)
	if gate and gate.Part then
		local position = base.Position
		local target = Vector3.new(gate.Part.Position.X, position.Y, gate.Part.Position.Z)
		if (target - position).Magnitude > 1 then
			return CFrame.lookAt(position, target)
		end
	end
	return base
end]],
		"race stable staging cframe")
	source = replaceOnce(source,
		[[				NextGateIndex = 1,
				LastTouchClock = 0,
				LastProgressElapsed = 0,]],
		[[				NextGateIndex = 1,
				LastCompletedGateIndex = 0,
				GridIndex = #participants + 1,
				LastTouchClock = 0,
				LastProgressElapsed = 0,]],
		"race last checkpoint state")
	source = replaceOnce(source,
		[[	entry.NextGateIndex += 1
	fire(entry.Player, {
		Type = "RaceCheckpoint",]],
		[[	entry.LastCompletedGateIndex = entry.NextGateIndex
	entry.NextGateIndex += 1
	fire(entry.Player, {
		Type = "RaceCheckpoint",]],
		"race checkpoint progress state")
	source = replaceOnce(source,
		[[	elseif action == "GetQueueStatus" then
		local eventId = queuedByPlayer[player]
		if not eventId then
			return { Ok = true, Queued = false }
		end
		local queue = queues[eventId]
		return {
			Ok = true,
			Queued = queue ~= nil,
			EventId = eventId,
			Count = queue and #queue.Players or 0,
			MinPlayers = queue and queue.MinPlayers or 0,
			MaxPlayers = queue and queue.MaxPlayers or 0,
			SecondsRemaining = queue and math.max(0, math.ceil((queue.Deadline or now()) - now())) or 0,
		}
	end]],
		[[	elseif action == "GetQueueStatus" then
		local eventId = queuedByPlayer[player]
		if not eventId then
			return { Ok = true, Queued = false }
		end
		local queue = queues[eventId]
		return {
			Ok = true,
			Queued = queue ~= nil,
			EventId = eventId,
			Count = queue and #queue.Players or 0,
			MinPlayers = queue and queue.MinPlayers or 0,
			MaxPlayers = queue and queue.MaxPlayers or 0,
			SecondsRemaining = queue and math.max(0, math.ceil((queue.Deadline or now()) - now())) or 0,
		}
	elseif action == "ResetToLastCheckpoint" then
		return resetRacePlayer(player)
	elseif action == "ExitRaceToStart" then
		return exitRacePlayer(player)
	end]],
		"race control request actions")
	service.Source = source
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

local function install()
	ensureRemotes()
	patchEntryMenuClient()
	patchTimeTrialService()
	patchRaceMatchmakingService()
	installControlsClient()
	print("[NTR Racing Phase 8C] Installed session controls polish.")
	print("[NTR Racing Phase 8C] First-start handoff now waits until GO, matching the cleaner Retry path.")
end

local function smoke()
	local racing = racingClientFolder()
	local controls = racing:FindFirstChild("RaceSessionControlsClient_Active")
	assert(controls and controls:IsA("LocalScript") and controls.Disabled == false, "RaceSessionControlsClient_Active missing/disabled")
	assert(string.find(controls.Source, "NTR_RACING_PHASE8C_SESSION_CONTROLS_CLIENT", 1, true), "controls source marker missing")
	local entry = racing:FindFirstChild("RaceEntryMenuClient_Active")
	assert(entry and string.find(entry.Source, "NTR_RACING_PHASE8C_NO_PRE_STAGE_HANDOFF", 1, true), "entry pre-stage handoff repair missing")
	local tt = racingServiceFolder():FindFirstChild("TimeTrialService_Active")
	assert(tt and string.find(tt.Source, "ResetActiveTimeTrial", 1, true), "time-trial reset action missing")
	local race = racingServiceFolder():FindFirstChild("RaceMatchmakingService_Active")
	assert(race and string.find(race.Source, "ExitRaceToStart", 1, true), "race exit action missing")
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local rewards = kit:WaitForChild("Config"):WaitForChild("Racing"):FindFirstChild("Rewards")
	assert(rewards == nil or (rewards:FindFirstChild("TimeTrial") and rewards:FindFirstChild("Race")), "Rewards folder shape looks unexpected")
	print("[NTR Racing Phase 8C] Smoke passed.")
end

if MODE == "INSTALL" then
	install()
	smoke()
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
