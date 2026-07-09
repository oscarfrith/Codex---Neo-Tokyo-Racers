-- Neo Tokyo Racers - Racing Phase 8 Queue Client
-- NTR_RACING_PHASE8_QUEUE_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local racingRemotes = shared:WaitForChild("Remotes"):WaitForChild("Racing")
local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")
local RouteDefinition = require(shared:WaitForChild("Modules"):WaitForChild("Racing"):WaitForChild("RaceRouteDefinition"))

local racingFolder = script.Parent
local startQueueEvent = racingFolder:WaitForChild("StartRaceQueueRequest")

local themeFolder = kit:FindFirstChild("Config") and kit.Config:FindFirstChild("UI") and kit.Config.UI:FindFirstChild("Theme")

local function colorAttr(name, fallback)
	local value = themeFolder and themeFolder:GetAttribute(name)
	return typeof(value) == "Color3" and value or fallback
end

local theme = {
	Panel = colorAttr("Panel", Color3.fromRGB(12, 15, 18)),
	Text = colorAttr("Text", Color3.fromRGB(240, 250, 255)),
	Muted = colorAttr("Muted", Color3.fromRGB(165, 180, 190)),
	Accent = colorAttr("Accent", Color3.fromRGB(67, 255, 210)),
	Selected = colorAttr("Selected", Color3.fromRGB(255, 111, 220)),
	Exit = colorAttr("Exit", Color3.fromRGB(210, 72, 72)),
	Buy = colorAttr("Buy", Color3.fromRGB(67, 255, 165)),
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 7)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Thickness = thickness or 1
	item.Transparency = transparency or 0.2
	item.Parent = parent
	return item
end

local function label(parent, text, size, position, textSize, color, bold)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Text = text or ""
	item.Size = size
	item.Position = position
	item.TextColor3 = color or theme.Text
	item.TextSize = textSize or 13
	item.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function button(parent, name, text, size, position, color)
	local item = Instance.new("TextButton")
	item.Name = name
	item.AutoButtonColor = true
	item.BackgroundColor3 = color or theme.Panel
	item.BackgroundTransparency = 0.06
	item.BorderSizePixel = 0
	item.Text = text
	item.TextColor3 = theme.Text
	item.TextSize = 12
	item.Font = Enum.Font.GothamBold
	item.Size = size
	item.Position = position
	item.Parent = parent
	corner(item, 6)
	stroke(item, theme.Selected, 1.2, 0.25)
	return item
end

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceQueue_Phase8"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 88
gui.Enabled = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 74)
panel.Size = UDim2.fromOffset(430, 132)
panel.BackgroundColor3 = theme.Panel
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 7)
stroke(panel, theme.Selected, 1.5, 0.18)

local title = label(panel, "OPEN RACE QUEUE", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 10), 14, theme.Text, true)
title.TextXAlignment = Enum.TextXAlignment.Center
local status = label(panel, "Waiting for racers.", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 38), 12, theme.Accent, true)
status.TextXAlignment = Enum.TextXAlignment.Center
local details = label(panel, "", UDim2.new(1, -148, 0, 48), UDim2.fromOffset(12, 72), 11, theme.Muted, false)
local leave = button(panel, "LeaveQueue", "LEAVE", UDim2.fromOffset(112, 38), UDim2.new(1, -124, 1, -50), theme.Exit)

local state = {
	Queued = false,
	ActiveRun = nil,
	StartLocalClock = nil,
	FinishedRun = nil, -- NTR_RACING_PHASE11D_FINISH_EXIT_UI
}


local ticker = nil

local function formatTime(seconds)
	return string.format("%.3f", math.max(0, tonumber(seconds) or 0))
end

local function setVisible(visible)
	panel.Visible = visible == true
end

local function setQueueText(payload)
	title.Text = tostring(payload.DisplayName or "OPEN RACE QUEUE")
	status.Text = tostring(payload.Message or "Waiting for racers.")
	details.Text = "Open category  |  " .. tostring(payload.Count or 0) .. "/" .. tostring(payload.MaxPlayers or 0) .. " racers\nMin players: " .. tostring(payload.MinPlayers or 0) .. "  |  Starts in: " .. tostring(payload.SecondsRemaining or 0) .. "s"
	setVisible(true)
end

local function stopTicker()
	if ticker then
		ticker:Disconnect()
		ticker = nil
	end
end

local function startTicker()
	stopTicker()
	ticker = RunService.Heartbeat:Connect(function()
		if state.ActiveRun and state.StartLocalClock then
			status.Text = "RACE LIVE  |  " .. formatTime(os.clock() - state.StartLocalClock)
		end
	end)
end

local function invokeQueue(action, payload)
	local ok, result = pcall(function()
		return queueRequest:InvokeServer(action, payload or {})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Success = false, Message = tostring(result or "Queue request failed.") }
end

local function fireDrivingHandoff()
	-- NTR_RACING_PHASE8B_RACE_DRIVE_HANDOFF
	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local spawnedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
	if spawnedEvent and spawnedEvent:IsA("BindableEvent") then
		spawnedEvent:Fire()
	end
end

local function requestStreamAroundRoute(routeId, nextGateIndex)
	local route = RouteDefinition.GetRouteDefinition(routeId)
	local gate = route and RouteDefinition.GetGate(route, nextGateIndex or 1)
	local part = gate and gate.Part
	if part then
		pcall(function()
			Workspace:RequestStreamAroundAsync(part.Position)
		end)
	end
end

startQueueEvent.Event:Connect(function(payload)
	payload = typeof(payload) == "table" and payload or {}
	state.Queued = true
	title.Text = tostring(payload.DisplayName or "OPEN RACE QUEUE")
	status.Text = "Joining race queue..."
	details.Text = "Open category matchmaking."
	setVisible(true)
	local result = invokeQueue("JoinQueue", {
		EventId = payload.EventId,
		VehicleId = payload.VehicleId,
	})
	if result.Ok ~= true and result.Success ~= true then
		state.Queued = false
		status.Text = tostring(result.Message or "Could not join race queue.")
		task.delay(3, function()
			if state.Queued ~= true and not state.ActiveRun then
				setVisible(false)
			end
		end)
	end
end)

leave.MouseButton1Click:Connect(function()
	-- NTR_RACING_PHASE11D_FINISH_EXIT_UI
	if state.FinishedRun then
		leave.Active = false
		leave.AutoButtonColor = false
		status.Text = "RETURNING TO START"
		local result = invokeQueue("ExitRaceToStart", {})
		if result.Ok ~= true and result.Success ~= true then
			leave.Active = true
			leave.AutoButtonColor = true
			status.Text = tostring(result.Message or "Could not exit race.")
		end
		return
	end
	local action = state.ActiveRun and "ExitRaceToStart" or "LeaveQueue"
	local result = invokeQueue(action, {})
	state.Queued = false
	status.Text = tostring(result.Message or "Left queue.")
	task.delay(1.2, function()
		if state.Queued ~= true and not state.ActiveRun and not state.FinishedRun then
			setVisible(false)
		end
	end)
end)


queueEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "QueueJoined" or kind == "QueueUpdate" then
		state.Queued = true
		state.ActiveRun = nil
		state.FinishedRun = nil
		gui.DisplayOrder = 88
		leave.Text = "LEAVE"
		leave.Active = true
		leave.AutoButtonColor = true
		stopTicker()
		setQueueText(payload)
	elseif kind == "QueueLeft" then
		state.Queued = false
		state.FinishedRun = nil
		status.Text = tostring(payload.Message or "Left queue.")
		task.delay(1.2, function()
			if state.Queued ~= true and not state.ActiveRun and not state.FinishedRun then
				setVisible(false)
			end
		end)
	elseif kind == "RaceQueueError" then
		state.Queued = false
		state.ActiveRun = nil
		state.FinishedRun = nil
		stopTicker()
		status.Text = tostring(payload.Message or "Race queue unavailable.")
		setVisible(true)
	elseif kind == "RaceStaged" then
		state.Queued = false
		state.ActiveRun = payload
		state.FinishedRun = nil
		state.StartLocalClock = nil
		gui.DisplayOrder = 88
		leave.Text = "QUIT RACE"
		leave.Active = true
		leave.AutoButtonColor = true
		title.Text = tostring(payload.DisplayName or "RACE")
		status.Text = "STAGING"
		details.Text = "Racers: " .. tostring(payload.ParticipantCount or "?") .. "  |  Checkpoints: " .. tostring(payload.GateCount or "?")
		setVisible(true)
	elseif kind == "RaceCountdown" then
		title.Text = tostring(payload.DisplayName or "RACE")
		status.Text = tostring(payload.Countdown or 3)
		details.Text = "Get ready."
		setVisible(true)
	elseif kind == "RaceStarted" then
		state.ActiveRun = payload
		state.FinishedRun = nil
		gui.DisplayOrder = 88
		leave.Text = "QUIT RACE"
		leave.Active = true
		leave.AutoButtonColor = true
		state.StartLocalClock = os.clock()
		title.Text = tostring(payload.DisplayName or "RACE")
		details.Text = "Position updates appear at checkpoints."
		setVisible(true)
		task.defer(requestStreamAroundRoute, payload.RouteId, payload.NextGateIndex or 1)
		task.defer(fireDrivingHandoff)
		task.delay(0.25, fireDrivingHandoff)
		startTicker()
	elseif kind == "RaceCheckpoint" then
		details.Text = "Checkpoint " .. tostring((payload.NextGateIndex or 1) - 1) .. "/" .. tostring(payload.GateCount or "?")
	elseif kind == "RacePositionUpdate" then
		status.Text = "POSITION  " .. tostring(payload.Place or "?") .. "/" .. tostring(payload.ParticipantCount or "?")
	elseif kind == "RaceFinished" then
		-- NTR_RACING_PHASE11D_FINISH_EXIT_UI
		stopTicker()
		state.ActiveRun = nil
		state.FinishedRun = payload
		gui.DisplayOrder = 230
		leave.Text = "EXIT"
		leave.Active = true
		leave.AutoButtonColor = true
		title.Text = tostring(payload.DisplayName or "RACE COMPLETE")
		status.Text = "FINISHED  P" .. tostring(payload.Place or "?") .. "/" .. tostring(payload.ParticipantCount or "?")
		local rewardAmount = tonumber(payload.RewardAmount) or 0
		local medal = tostring(payload.RaceMedal or "")
		local rewardLine
		if payload.RewardGranted == true and rewardAmount > 0 then
			rewardLine = (medal ~= "" and (medal .. "  |  ") or "") .. "REWARD  $" .. tostring(math.floor(rewardAmount + 0.5))
		elseif payload.RewardMessage and payload.RewardMessage ~= "" then
			rewardLine = tostring(payload.RewardMessage)
		else
			rewardLine = "No cash reward for this placement."
		end
		details.Text = "Time: " .. formatTime(payload.Elapsed) .. "\n" .. rewardLine
		setVisible(true)
	elseif kind == "RaceDNF" then
		stopTicker()
		state.ActiveRun = nil
		state.FinishedRun = nil
		status.Text = "DNF"
		details.Text = tostring(payload.Message or "Race ended.")
	elseif kind == "RaceExitedToStart" then
		stopTicker()
		state.Queued = false
		state.ActiveRun = nil
		state.FinishedRun = nil
		gui.DisplayOrder = 88
		leave.Text = "LEAVE"
		leave.Active = true
		leave.AutoButtonColor = true
		setVisible(false)
	elseif kind == "RaceEnded" then
		stopTicker()
		state.Queued = false
		state.ActiveRun = nil
		if state.FinishedRun then
			setVisible(true)
			return
		end
		task.delay(4, function()
			if state.Queued ~= true and not state.ActiveRun and not state.FinishedRun then
				setVisible(false)
			end
		end)
	end
end)


print("[NTR Racing Phase 8 Client] Race queue client active.")
