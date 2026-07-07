-- Neo Tokyo Racers - Race Entry/HUD/Route Guide Client
-- NTR_RACING_PHASE2_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local racingModules = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceHud"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 76
gui.Enabled = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 68)
panel.Size = UDim2.fromOffset(360, 92)
panel.BackgroundColor3 = Color3.fromRGB(6, 10, 13)
panel.BackgroundTransparency = 0.14
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 255, 190)
stroke.Transparency = 0.22
stroke.Thickness = 1.5
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 22)
title.Text = "TIME TRIAL"
title.TextColor3 = Color3.fromRGB(255, 226, 249)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
pcall(function()
	title.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
end)
title.Parent = panel

local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.BackgroundTransparency = 1
timer.Position = UDim2.fromOffset(12, 34)
timer.Size = UDim2.new(0.5, -12, 0, 28)
timer.Text = "0.000"
timer.TextColor3 = Color3.fromRGB(70, 255, 190)
timer.TextSize = 24
timer.TextXAlignment = Enum.TextXAlignment.Left
timer.Font = Enum.Font.GothamBold
timer.Parent = panel

local progress = Instance.new("TextLabel")
progress.Name = "Progress"
progress.BackgroundTransparency = 1
progress.Position = UDim2.new(0.5, 0, 0, 38)
progress.Size = UDim2.new(0.5, -12, 0, 22)
progress.Text = "CHECKPOINT 1/1"
progress.TextColor3 = Color3.fromRGB(255, 226, 249)
progress.TextSize = 12
progress.TextXAlignment = Enum.TextXAlignment.Right
progress.Font = Enum.Font.GothamBold
progress.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(12, 66)
status.Size = UDim2.new(1, -24, 0, 18)
status.Text = ""
status.TextColor3 = Color3.fromRGB(195, 221, 213)
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham
status.Parent = panel

local markerRoot = Workspace:FindFirstChild("_NTR_ClientOnly")
if not markerRoot then
	markerRoot = Instance.new("Folder")
	markerRoot.Name = "_NTR_ClientOnly"
	markerRoot.Parent = Workspace
end

local active = nil
local marker = nil
local markerGui = nil
local heartbeatConnection = nil

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	return string.format("%.3f", seconds)
end

local function clearMarker()
	if marker then
		marker:Destroy()
		marker = nil
	end
	if markerGui then
		markerGui:Destroy()
		markerGui = nil
	end
end

local function ensureMarker(part, isFinish)
	clearMarker()
	if not (part and part:IsA("BasePart")) then return end
	marker = Instance.new("SelectionBox")
	marker.Name = "RaceNextGateSelection"
	marker.Adornee = part
	marker.Color3 = isFinish and Color3.fromRGB(255, 226, 80) or Color3.fromRGB(70, 255, 190)
	marker.LineThickness = 0.08
	marker.SurfaceTransparency = 0.88
	marker.Parent = markerRoot

	markerGui = Instance.new("BillboardGui")
	markerGui.Name = "RaceNextGateBillboard"
	markerGui.Adornee = part
	markerGui.AlwaysOnTop = true
	markerGui.Size = UDim2.fromOffset(160, 42)
	markerGui.StudsOffset = Vector3.new(0, math.max(7, part.Size.Y * 0.5 + 5), 0)
	markerGui.Parent = markerRoot

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(6, 10, 13)
	label.BackgroundTransparency = 0.16
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Text = isFinish and "FINISH" or "CHECKPOINT"
	label.TextColor3 = isFinish and Color3.fromRGB(255, 226, 80) or Color3.fromRGB(70, 255, 190)
	label.TextStrokeTransparency = 0.2
	label.TextSize = 15
	label.Font = Enum.Font.GothamBold
	label.Parent = markerGui
	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 6)
	labelCorner.Parent = label
end

local function routeForActive()
	if not active then return nil end
	local route, routeError = RouteDefinition.GetRouteDefinition(active.RouteId)
	if not route then
		warn("[NTR Racing Phase 2 Client] " .. tostring(routeError))
	end
	return route
end

local function updateNextGate()
	local route = routeForActive()
	local gate = route and RouteDefinition.GetGate(route, active.NextGateIndex or 1)
	if gate then
		ensureMarker(gate.Part, gate.IsFinish)
		local label = gate.IsFinish and "FINISH" or "CHECKPOINT"
		progress.Text = string.format("%s %d/%d", label, active.NextGateIndex or 1, active.GateCount or 1)
	else
		clearMarker()
	end
end

local function startTicker()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not active or not active.StartLocalClock then return end
		timer.Text = formatTime(os.clock() - active.StartLocalClock)
	end)
end

local function stopTicker()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function showError(message)
	panel.Visible = true
	title.Text = "TIME TRIAL"
	timer.Text = "--"
	progress.Text = ""
	status.Text = tostring(message or "Time trial unavailable.")
	task.delay(2.2, function()
		if not active then
			panel.Visible = false
			status.Text = ""
		end
	end)
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "TimeTrialError" then
		showError(payload.Message)
	elseif kind == "TimeTrialCountdown" then
		active = {
			EventId = payload.EventId,
			RouteId = payload.RouteId,
			DisplayName = payload.DisplayName,
			NextGateIndex = payload.NextGateIndex or 1,
			GateCount = payload.GateCount or 1,
			CountdownUntil = os.clock() + (payload.Countdown or 3),
		}
		panel.Visible = true
		title.Text = tostring(payload.DisplayName or "TIME TRIAL")
		timer.Text = tostring(payload.Countdown or 3)
		status.Text = "GET READY"
		updateNextGate()
		task.spawn(function()
			while active and active.CountdownUntil and os.clock() < active.CountdownUntil do
				timer.Text = tostring(math.max(1, math.ceil(active.CountdownUntil - os.clock())))
				task.wait(0.1)
			end
		end)
	elseif kind == "TimeTrialStarted" then
		active = active or {}
		active.EventId = payload.EventId
		active.RouteId = payload.RouteId
		active.DisplayName = payload.DisplayName
		active.NextGateIndex = payload.NextGateIndex or 1
		active.GateCount = payload.GateCount or 1
		active.StartLocalClock = os.clock()
		active.CountdownUntil = nil
		panel.Visible = true
		title.Text = tostring(payload.DisplayName or "TIME TRIAL")
		status.Text = "RUNNING"
		updateNextGate()
		startTicker()
	elseif kind == "TimeTrialCheckpoint" then
		if not active then return end
		active.NextGateIndex = payload.NextGateIndex or active.NextGateIndex
		active.GateCount = payload.GateCount or active.GateCount
		status.Text = "CHECKPOINT " .. tostring(payload.CheckpointIndex or "")
		updateNextGate()
	elseif kind == "TimeTrialFinished" then
		stopTicker()
		clearMarker()
		active = nil
		panel.Visible = true
		title.Text = tostring(payload.DisplayName or "TIME TRIAL")
		timer.Text = formatTime(payload.Elapsed)
		progress.Text = "FINISHED"
		status.Text = tostring(payload.Message or "Finished")
	elseif kind == "TimeTrialEnded" then
		stopTicker()
		clearMarker()
		active = nil
		panel.Visible = false
	end
end)

print("[NTR Racing Phase 2 Client] Race HUD/guide active.")
