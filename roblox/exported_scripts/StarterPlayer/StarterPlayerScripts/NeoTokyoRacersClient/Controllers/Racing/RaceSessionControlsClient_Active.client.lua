-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
-- Neo Tokyo Racers - Racing Phase 8D Session Controls Client
-- NTR_RACING_PHASE8D_SESSION_CONTROLS_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Foundation = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ResponsiveUIFoundation"))
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
	return Foundation.Corner(parent,radius or 7)
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
	-- NTR_RACING_PHASE8F_CLEAN_BUTTON_TEXT
	-- Michroma at this small size rasterises unevenly in Roblox buttons.
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextStrokeTransparency = 1
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
	button.TextSize = touch and 11 or 13
	button.TextWrapped = false
	button.TextScaled = false
	button.TextStrokeTransparency = 1
	button.LineHeight = 1
	applyFont(button, true)
	button.Parent = parent
	corner(button, 6)
	stroke(button, color == theme.Exit and theme.Exit or theme.Accent, Foundation.StrokeWidth("Structural"), 0.2)
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
stroke(panel, theme.Selected, Foundation.StrokeWidth("Emphasis"), 0.18)

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
		-- NTR_RACING_PHASE8G_NO_CLIENT_RESET_STOP
		-- The reset event from the server owns presentation; do not also poke the vehicle here.
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
