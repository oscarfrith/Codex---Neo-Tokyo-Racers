local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local M = require(game:GetService("ReplicatedStorage")
	:WaitForChild("HOVER_RACING_V2_KIT")
	:WaitForChild("CLIENT_MODULES")
	:WaitForChild("Controllers")
	:WaitForChild("MobileDriveInputState"))

local TOUCH = UserInputService.TouchEnabled
local HUD_PANEL = Color3.fromRGB(5, 9, 7)
local HUD_PANEL_SOFT = Color3.fromRGB(13, 25, 21)
local HUD_TEXT = Color3.fromRGB(218, 255, 231)
local HUD_ACCENT = Color3.fromRGB(172, 255, 197)
local HUD_RED = Color3.fromRGB(194, 67, 62)

local fontFace
pcall(function()
	fontFace = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
end)

local function applyText(object)
	if fontFace then
		pcall(function() object.FontFace = fontFace end)
	else
		object.Font = Enum.Font.GothamBold
	end
	object.TextStrokeColor3 = Color3.fromRGB(0, 10, 5)
	object.TextStrokeTransparency = 0.72
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 5)
	c.Parent = parent
	return c
end

local function stroke(parent, colour, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Name = "HUDStroke"
	s.Color = colour or HUD_ACCENT
	s.Transparency = transparency or 0.32
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local old = playerGui:FindFirstChild("HOVER_RACING_V67_MobileDriveControlsUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "HOVER_RACING_V67_MobileDriveControlsUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 140
gui.Enabled = TOUCH
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
root.Visible = false
root.Parent = gui

local leftPanel = Instance.new("Frame")
leftPanel.Name = "LeftControls"
leftPanel.BackgroundTransparency = 1
leftPanel.BorderSizePixel = 0
leftPanel.Parent = root

local rightPanel = Instance.new("Frame")
rightPanel.Name = "Pedals"
rightPanel.BackgroundTransparency = 1
rightPanel.BorderSizePixel = 0
rightPanel.Parent = root

local mphLabel = Instance.new("TextLabel")
mphLabel.Name = "MphLabel"
mphLabel.BackgroundTransparency = 1
mphLabel.BorderSizePixel = 0
mphLabel.Text = "0 MPH"
mphLabel.TextColor3 = HUD_ACCENT
mphLabel.TextSize = 15
mphLabel.TextXAlignment = Enum.TextXAlignment.Center
mphLabel.TextYAlignment = Enum.TextYAlignment.Center
applyText(mphLabel)
mphLabel.Parent = leftPanel

local function button(parent, name, text)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BackgroundColor3 = HUD_PANEL_SOFT
	b.BackgroundTransparency = 0.03
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = HUD_TEXT
	b.TextSize = 18
	b.TextWrapped = true
	b.ClipsDescendants = true
	applyText(b)
	b.Parent = parent
	corner(b, 5)
	stroke(b, HUD_ACCENT, 0.3, 1)
	return b
end

local boostButton = button(leftPanel, "BoostButton", "")
local boostFill = Instance.new("Frame")
boostFill.Name = "BoostFill"
boostFill.BackgroundColor3 = HUD_ACCENT
boostFill.BackgroundTransparency = 0.26
boostFill.BorderSizePixel = 0
boostFill.Size = UDim2.fromScale(1, 1)
boostFill.ZIndex = boostButton.ZIndex + 1
boostFill.Parent = boostButton
corner(boostFill, 5)

local boostText = Instance.new("TextLabel")
boostText.Name = "BoostText"
boostText.BackgroundTransparency = 1
boostText.BorderSizePixel = 0
boostText.Size = UDim2.fromScale(1, 1)
boostText.Text = "BOOST"
boostText.TextColor3 = HUD_TEXT
boostText.TextSize = 12
boostText.ZIndex = boostButton.ZIndex + 2
applyText(boostText)
boostText.Parent = boostButton

local driftLeft = button(leftPanel, "DriftLeft", "<<")
local turnLeft = button(leftPanel, "TurnLeft", "<")
local turnRight = button(leftPanel, "TurnRight", ">")
local driftRight = button(leftPanel, "DriftRight", ">>")

local function makePedal(name, label, colour)
	local b = button(rightPanel, name, "")
	local pad = Instance.new("Frame")
	pad.Name = "RubberPad"
	pad.Position = UDim2.fromScale(0.16, 0.1)
	pad.Size = UDim2.fromScale(0.68, 0.72)
	pad.BackgroundColor3 = HUD_PANEL
	pad.BackgroundTransparency = 0.02
	pad.BorderSizePixel = 0
	pad.ZIndex = b.ZIndex + 1
	pad.Parent = b
	corner(pad, 5)
	stroke(pad, colour or HUD_ACCENT, 0.48, 1)
	for index = 1, 5 do
		local rib = Instance.new("Frame")
		rib.Name = "GripRib"
		rib.AnchorPoint = Vector2.new(0.5, 0.5)
		rib.Position = UDim2.fromScale(0.5, 0.14 + index * 0.13)
		rib.Size = UDim2.fromScale(0.68, 0.035)
		rib.BackgroundColor3 = colour or HUD_ACCENT
		rib.BackgroundTransparency = 0.42
		rib.BorderSizePixel = 0
		rib.ZIndex = pad.ZIndex + 1
		rib.Parent = pad
		corner(rib, 3)
	end
	local text = Instance.new("TextLabel")
	text.Name = "PedalIcon"
	text.BackgroundTransparency = 1
	text.BorderSizePixel = 0
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Position = UDim2.fromScale(0.5, 0.98)
	text.Size = UDim2.fromScale(0.9, 0.22)
	text.Text = label
	text.TextColor3 = HUD_TEXT
	text.TextSize = 11
	text.ZIndex = b.ZIndex + 2
	applyText(text)
	text.Parent = b
	return b
end

local brake = makePedal("BrakePedal", "", HUD_RED)
local accel = makePedal("AcceleratorPedal", "", HUD_ACCENT)

local buttonMap = {
	[accel] = "Accelerate",
	[brake] = "Brake",
	[turnLeft] = "TurnLeft",
	[turnRight] = "TurnRight",
	[driftLeft] = "DriftLeft",
	[driftRight] = "DriftRight",
	[boostButton] = "Boost",
}

local function setPressed(b, active)
	b.BackgroundColor3 = active and HUD_ACCENT or HUD_PANEL_SOFT
	b.TextColor3 = active and HUD_PANEL or HUD_TEXT
	local s = b:FindFirstChild("HUDStroke")
	if s then
		s.Transparency = active and 0.06 or 0.3
		s.Thickness = active and 2 or 1
	end
	if b == boostButton then
		boostText.TextColor3 = active and HUD_PANEL or HUD_TEXT
	end
end

local function refreshInput()
	if typeof(M.Refresh) == "function" then
		M.Refresh()
	else
		local s = M.State
		M.Throttle = math.clamp((s.Accelerate and 1 or 0) - (s.Brake and 1 or 0), -1, 1)
		M.Steer = math.clamp(((s.TurnRight or s.DriftRight) and 1 or 0) - ((s.TurnLeft or s.DriftLeft) and 1 or 0), -1, 1)
		M.Drift = s.DriftLeft or s.DriftRight
		M.Boost = s.Boost
	end
end

local function setAction(b, active)
	local action = buttonMap[b]
	if not action then return end
	M.State[action] = active
	setPressed(b, active)
	refreshInput()
end

for b in pairs(buttonMap) do
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setAction(b, true)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setAction(b, false)
		end
	end)
	b.MouseLeave:Connect(function()
		setAction(b, false)
	end)
end

local function resetInput()
	if typeof(M.Reset) == "function" then
		M.Reset()
	else
		for action in pairs(M.State) do M.State[action] = false end
		M.Throttle, M.Steer, M.Drift, M.Boost = 0, 0, false, false
	end
	for b in pairs(buttonMap) do
		setPressed(b, false)
	end
end

local function findGarageVisible()
	for _, guiObject in ipairs(playerGui:GetChildren()) do
		if guiObject:IsA("ScreenGui") and guiObject.Enabled then
			local name = string.lower(guiObject.Name)
			if string.find(name, "garage", 1, true) or string.find(name, "dealership", 1, true) then
				return true
			end
			local rootObject = guiObject:FindFirstChild("GarageRoot", true) or guiObject:FindFirstChild("DealershipRoot", true)
			if rootObject and rootObject:IsA("GuiObject") and rootObject.Visible then
				return true
			end
		end
	end
	return false
end



-- V69_MOBILE_HUD_VISIBILITY_BEGIN
local function lowerText(value)
	return string.lower(tostring(value or ""))
end

local function isOwnMobileUi(item)
	return item == gui or item == root or item:IsDescendantOf(root) or item:IsDescendantOf(gui)
end

local function textLooksLikeDesktopDriveHud(item)
	if not (item:IsA("TextLabel") or item:IsA("TextButton")) then return false end
	local text = lowerText(item.Text)
	if text == "" then return false end
	return string.find(text, "wasd", 1, true) ~= nil
		or string.find(text, "shift", 1, true) ~= nil
		or string.find(text, "space", 1, true) ~= nil
		or string.find(text, "speed", 1, true) ~= nil
		or string.find(text, "drift", 1, true) ~= nil
		or string.find(text, "mph", 1, true) ~= nil
end

local function nameLooksLikeDesktopDriveHud(item)
	local name = lowerText(item.Name)
	return string.find(name, "desktopdrive", 1, true) ~= nil
		or string.find(name, "drivepanel", 1, true) ~= nil
		or string.find(name, "speedpanel", 1, true) ~= nil
		or string.find(name, "boostpanel", 1, true) ~= nil
		or string.find(name, "speedhud", 1, true) ~= nil
		or string.find(name, "boosthud", 1, true) ~= nil
		or string.find(name, "controlshint", 1, true) ~= nil
end

local function descendantLooksLikeDesktopDriveHud(item)
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("GuiObject") and not isOwnMobileUi(descendant) then
			local name = lowerText(descendant.Name)
			if nameLooksLikeDesktopDriveHud(descendant)
				or string.find(name, "speedlabel", 1, true) ~= nil
				or string.find(name, "driftlabel", 1, true) ~= nil
				or textLooksLikeDesktopDriveHud(descendant) then
				return true
			end
		end
	end
	return false
end

local function nearestSmallDesktopPanel(item)
	local current = item
	local best = item
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not isOwnMobileUi(current) then
			local name = lowerText(current.Name)
			if name ~= "drivehud" and name ~= "root" then
				best = current
			end
			if current:IsA("Frame") and name ~= "drivehud" and name ~= "root" then
				local styled = current.BackgroundTransparency < 1
					or current:FindFirstChildOfClass("UICorner") ~= nil
					or current:FindFirstChildOfClass("UIStroke") ~= nil
				if styled then
					return current
				end
			end
		end
		current = current.Parent
	end
	return best
end

local function findDriveHudCandidates()
	local results = {}
	local seen = {}
	local function add(item)
		if item and item:IsA("GuiObject") and not isOwnMobileUi(item) and not seen[item] then
			seen[item] = true
			table.insert(results, item)
		end
	end

	for _, item in ipairs(playerGui:GetDescendants()) do
		if item:IsA("GuiObject") and not isOwnMobileUi(item) then
			if nameLooksLikeDesktopDriveHud(item) then
				add(item)
			elseif textLooksLikeDesktopDriveHud(item) then
				add(nearestSmallDesktopPanel(item))
			elseif item:IsA("Frame") and descendantLooksLikeDesktopDriveHud(item) then
				add(item)
			end
		end
	end

	return results
end

local function shouldShow()
	return TOUCH and M.IsDriving == true and not findGarageVisible()
end
-- V69_MOBILE_HUD_VISIBILITY_END


local hiddenDesktop = {}
local function setDesktopDriveHudVisible(visible)
	if not TOUCH then return end
	for _, object in ipairs(findDriveHudCandidates()) do
		if object ~= root and not object:IsDescendantOf(root) then
			if not visible then
				if hiddenDesktop[object] == nil then
					hiddenDesktop[object] = object.Visible
				end
				object.Visible = false
			elseif hiddenDesktop[object] ~= nil then
				object.Visible = hiddenDesktop[object]
				hiddenDesktop[object] = nil
			end
		end
	end
end

local function setRobloxTouchControls(enabled)
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = enabled
	end
end

local function updateVisibility()
	local show = shouldShow()
	root.Visible = show
	setDesktopDriveHudVisible(not show)
	setRobloxTouchControls(not (show or findGarageVisible()))
	if not show then
		resetInput()
	end
end

local function layout()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local width = math.max(size.X, 1)
	local height = math.max(size.Y, 1)
	local tiny = width < 740 or height < 430
	local margin = tiny and 13 or 20
	local gap = tiny and 6 or 8

	local arrow = math.floor(math.clamp(width * 0.088, tiny and 42 or 50, tiny and 55 or 64) + 0.5)
	local rowWidth = arrow * 4 + gap * 3
	local mphH = tiny and 20 or 25
	local boostW = math.floor(math.clamp(rowWidth * 0.58, 92, 140) + 0.5)
	local boostH = math.floor(math.clamp(arrow * 0.72, 32, 46) + 0.5)

	leftPanel.Position = UDim2.fromOffset(margin, height - margin - arrow - boostH - mphH - gap * 2)
	leftPanel.Size = UDim2.fromOffset(rowWidth, arrow + boostH + mphH + gap * 2)

	mphLabel.Position = UDim2.fromOffset(math.floor((rowWidth - boostW) * 0.5), 0)
	mphLabel.Size = UDim2.fromOffset(boostW, mphH)
	mphLabel.TextSize = tiny and 13 or 15

	boostButton.Position = UDim2.fromOffset(math.floor((rowWidth - boostW) * 0.5), mphH + gap)
	boostButton.Size = UDim2.fromOffset(boostW, boostH)
	boostText.TextSize = tiny and 11 or 12

	local y = mphH + boostH + gap * 2
	local row = { driftLeft, turnLeft, turnRight, driftRight }
	for index, b in ipairs(row) do
		b.Position = UDim2.fromOffset((index - 1) * (arrow + gap), y)
		b.Size = UDim2.fromOffset(arrow, arrow)
		b.TextSize = (b == turnLeft or b == turnRight) and (tiny and 22 or 27) or (tiny and 17 or 21)
	end

	local accelW = math.floor(math.clamp(width * 0.1, tiny and 55 or 66, tiny and 72 or 86) + 0.5)
	local accelH = math.floor(math.clamp(height * 0.18, tiny and 88 or 108, tiny and 122 or 148) + 0.5)
	local brakeW = math.floor(accelW * 0.86 + 0.5)
	local brakeH = math.floor(accelH * 0.86 + 0.5)
	local pedalW = accelW + brakeW + gap

	rightPanel.Position = UDim2.fromOffset(width - margin - pedalW, height - margin - accelH)
	rightPanel.Size = UDim2.fromOffset(pedalW, accelH)
	brake.Position = UDim2.fromOffset(0, accelH - brakeH)
	brake.Size = UDim2.fromOffset(brakeW, brakeH)
	accel.Position = UDim2.fromOffset(brakeW + gap, 0)
	accel.Size = UDim2.fromOffset(accelW, accelH)
end

local cameraConnection
local function connectCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	connectCamera()
	task.defer(layout)
end)
connectCamera()

local timer = 0
RunService.RenderStepped:Connect(function(dt)
	if root.Visible then
		mphLabel.Text = tostring(math.floor((M.SpeedMph or 0) + 0.5)) .. " MPH"
		boostFill.Size = UDim2.fromScale(math.clamp((M.BoostPercent or 100) / 100, 0, 1), 1)
	end
	timer += dt
	if timer >= 0.1 then
		timer = 0
		updateVisibility()
	end
end)

task.defer(layout)
task.defer(updateVisibility)
