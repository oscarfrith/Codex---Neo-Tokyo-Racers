-- Neo Tokyo Racers - Mobile Steering Thumbstick Installer
-- Run this whole file in the Roblox Studio Command Bar while NOT play-testing.
--
-- Replaces the four mobile left/drift arrow buttons with one fixed horizontal
-- thumbstick. The touch must begin on the visible stick or its forgiving hit
-- area, then remains captured until release even if the thumb moves outside it.
--
-- This is a guarded source patch against the current exported mobile controller.
-- Every expected source block is checked before either live script is changed.
--
-- Changes:
--   - MobileDriveControlsController_Active
--   - MobileDriveInputState
--   - ReplicatedStorage.NeoTokyoRacers.Shared.Config.MobileDriveControls_EditAttributes
--
-- Does not change driving physics, camera, pedals, boost, desktop controls,
-- gamepad controls, server systems, garage UI, VFX, or vehicle assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_mobile_drive_thumbstick_install"

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[NTR Mobile Thumbstick] Missing %s under %s. No source changes applied.")
			:format(name, parent and parent:GetFullName() or "nil"))
	end
	if className and not child:IsA(className) then
		error(("[NTR Mobile Thumbstick] %s is %s, expected %s. No source changes applied.")
			:format(child:GetFullName(), child.ClassName, className))
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		error(("[NTR Mobile Thumbstick] Preflight failed at %s. The live controller shape differs from the refreshed mirror; no source changes applied.")
			:format(label))
	end
	if string.find(source, oldText, last + 1, true) then
		error(("[NTR Mobile Thumbstick] Preflight found multiple matches at %s; no source changes applied.")
			:format(label))
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local ntr = requireChild(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = requireChild(ntr, "Shared", "Folder")
local modules = requireChild(shared, "Modules", "Folder")
local clientModules = requireChild(modules, "Client", "Folder")
local moduleControllers = requireChild(clientModules, "Controllers", "Folder")
local inputModule = requireChild(moduleControllers, "MobileDriveInputState", "ModuleScript")

local starterPlayerScripts = requireChild(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = requireChild(starterPlayerScripts, "NeoTokyoRacersClient", "Folder")
local clientControllers = requireChild(clientRoot, "Controllers", "Folder")
local runtimeControllers = requireChild(clientControllers, "Runtime", "Folder")
local mobileController = requireChild(runtimeControllers, "MobileDriveControlsController_Active", "LocalScript")

local source = mobileController.Source

source = replaceExact(source, [==[
local TOUCH = UserInputService.TouchEnabled
local HUD_PANEL = Color3.fromRGB(5, 9, 7)
]==], [==[
local TOUCH = UserInputService.TouchEnabled
local configFolder = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Config")
	:WaitForChild("MobileDriveControls_EditAttributes")

local function configNumber(name, fallback, minimum, maximum)
	local value = configFolder:GetAttribute(name)
	if typeof(value) ~= "number" then value = fallback end
	return math.clamp(value, minimum, maximum)
end

local HUD_PANEL = Color3.fromRGB(5, 9, 7)
]==], "config reader")

source = replaceExact(source, [==[
local driftLeft = button(leftPanel, "DriftLeft", "<<")
local turnLeft = button(leftPanel, "TurnLeft", "<")
local turnRight = button(leftPanel, "TurnRight", ">")
local driftRight = button(leftPanel, "DriftRight", ">>")
]==], [==[
local thumbHitArea = Instance.new("TextButton")
thumbHitArea.Name = "SteeringThumbstickHitArea"
thumbHitArea.AutoButtonColor = false
thumbHitArea.BackgroundTransparency = 1
thumbHitArea.BorderSizePixel = 0
thumbHitArea.Text = ""
thumbHitArea.Active = true
thumbHitArea.Parent = leftPanel

local thumbBase = Instance.new("Frame")
thumbBase.Name = "SteeringThumbstickBase"
thumbBase.AnchorPoint = Vector2.new(0.5, 0.5)
thumbBase.Position = UDim2.fromScale(0.5, 0.5)
thumbBase.BackgroundColor3 = HUD_PANEL_SOFT
thumbBase.BackgroundTransparency = 0.18
thumbBase.BorderSizePixel = 0
thumbBase.Active = false
thumbBase.Parent = thumbHitArea
corner(thumbBase, 999)
local thumbBaseStroke = stroke(thumbBase, HUD_ACCENT, 0.28, 2)

local thumbGuide = Instance.new("Frame")
thumbGuide.Name = "HorizontalGuide"
thumbGuide.AnchorPoint = Vector2.new(0.5, 0.5)
thumbGuide.Position = UDim2.fromScale(0.5, 0.5)
thumbGuide.Size = UDim2.fromScale(0.62, 0.035)
thumbGuide.BackgroundColor3 = HUD_ACCENT
thumbGuide.BackgroundTransparency = 0.58
thumbGuide.BorderSizePixel = 0
thumbGuide.Active = false
thumbGuide.Parent = thumbBase
corner(thumbGuide, 999)

local thumbKnob = Instance.new("Frame")
thumbKnob.Name = "SteeringThumbstickKnob"
thumbKnob.AnchorPoint = Vector2.new(0.5, 0.5)
thumbKnob.Position = UDim2.fromScale(0.5, 0.5)
thumbKnob.BackgroundColor3 = HUD_ACCENT
thumbKnob.BackgroundTransparency = 0.08
thumbKnob.BorderSizePixel = 0
thumbKnob.Active = false
thumbKnob.ZIndex = thumbBase.ZIndex + 2
thumbKnob.Parent = thumbBase
corner(thumbKnob, 999)
local thumbKnobStroke = stroke(thumbKnob, HUD_TEXT, 0.2, 1)

local driftText = Instance.new("TextLabel")
driftText.Name = "DriftThresholdLabel"
driftText.AnchorPoint = Vector2.new(0.5, 1)
driftText.Position = UDim2.fromScale(0.5, 0.94)
driftText.Size = UDim2.fromScale(0.8, 0.2)
driftText.BackgroundTransparency = 1
driftText.BorderSizePixel = 0
driftText.Text = ""
driftText.TextColor3 = HUD_TEXT
driftText.TextSize = 10
driftText.ZIndex = thumbKnob.ZIndex + 1
driftText.Active = false
applyText(driftText)
driftText.Parent = thumbBase
]==], "arrow UI replacement")

source = replaceExact(source, [==[
local buttonMap = {
	[accel] = "Accelerate",
	[brake] = "Brake",
	[turnLeft] = "TurnLeft",
	[turnRight] = "TurnRight",
	[driftLeft] = "DriftLeft",
	[driftRight] = "DriftRight",
	[boostButton] = "Boost",
}
]==], [==[
local buttonMap = {
	[accel] = "Accelerate",
	[brake] = "Brake",
	[boostButton] = "Boost",
}
]==], "button map")

source = replaceExact(source, [==[
local function setAction(b, active)
	local action = buttonMap[b]
	if not action then return end
	M.State[action] = active
	setPressed(b, active)
	refreshInput()
end

for b in pairs(buttonMap) do
]==], [==[
local function setAction(b, active)
	local action = buttonMap[b]
	if not action then return end
	M.State[action] = active
	setPressed(b, active)
	refreshInput()
end

local activeSteeringInput = nil
local mouseSteering = false
local driftRequested = false

local function publishSteering(steer, drift)
	if typeof(M.SetSteering) == "function" then
		M.SetSteering(steer, drift)
	else
		M.Steer = steer
		M.Drift = drift
	end
end

local function setThumbVisual(steer, drift)
	local travelRatio = configNumber("ThumbstickTravelRatio", 0.38, 0.2, 0.48)
	thumbKnob.Position = UDim2.fromScale(0.5 + steer * travelRatio, 0.5)
	local activeColour = drift and HUD_RED or HUD_ACCENT
	thumbKnob.BackgroundColor3 = activeColour
	thumbBaseStroke.Color = activeColour
	thumbBaseStroke.Transparency = math.abs(steer) > 0.01 and 0.08 or 0.28
	thumbKnobStroke.Thickness = drift and 2 or 1
	driftText.Text = drift and "DRIFT" or ""
end

local function updateSteering(position)
	local centerX = thumbBase.AbsolutePosition.X + thumbBase.AbsoluteSize.X * 0.5
	local travel = math.max(thumbBase.AbsoluteSize.X * configNumber("ThumbstickTravelRatio", 0.38, 0.2, 0.48), 1)
	local raw = math.clamp((position.X - centerX) / travel, -1, 1)
	local magnitude = math.abs(raw)
	local deadzone = configNumber("SteeringDeadzone", 0.12, 0, 0.45)
	local steer = 0
	if magnitude > deadzone then
		local scaled = math.clamp((magnitude - deadzone) / math.max(1 - deadzone, 0.01), 0, 1)
		local exponent = configNumber("SteeringResponseExponent", 1.15, 0.5, 3)
		steer = math.sign(raw) * (scaled ^ exponent)
	end

	local enterThreshold = configNumber("DriftEnterThreshold", 0.82, 0.5, 1)
	local exitThreshold = math.min(
		configNumber("DriftExitThreshold", 0.70, 0.35, 0.95),
		enterThreshold
	)
	if driftRequested then
		driftRequested = math.abs(steer) >= exitThreshold
	else
		driftRequested = math.abs(steer) >= enterThreshold
	end

	publishSteering(steer, driftRequested)
	setThumbVisual(steer, driftRequested)
end

local function releaseSteering()
	activeSteeringInput = nil
	mouseSteering = false
	driftRequested = false
	if typeof(M.ReleaseSteering) == "function" then
		M.ReleaseSteering()
	else
		M.Steer = 0
		M.Drift = false
	end
	setThumbVisual(0, false)
end

thumbHitArea.InputBegan:Connect(function(input)
	if activeSteeringInput then return end
	if input.UserInputType == Enum.UserInputType.Touch then
		activeSteeringInput = input
		updateSteering(input.Position)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		activeSteeringInput = input
		mouseSteering = true
		updateSteering(input.Position)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and input == activeSteeringInput then
		updateSteering(input.Position)
	elseif mouseSteering and input.UserInputType == Enum.UserInputType.MouseMovement then
		updateSteering(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeSteeringInput
		or (mouseSteering and input.UserInputType == Enum.UserInputType.MouseButton1) then
		releaseSteering()
	end
end)

for b in pairs(buttonMap) do
]==], "thumbstick input")

source = replaceExact(source, [==[
	for b in pairs(buttonMap) do
		setPressed(b, false)
	end
end
]==], [==[
	for b in pairs(buttonMap) do
		setPressed(b, false)
	end
	releaseSteering()
end
]==], "reset steering")

source = replaceExact(source, [==[
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
]==], [==[
	local configuredSize = configNumber("ThumbstickSizePixels", 118, 82, 180)
	local thumbSize = math.floor(math.clamp(configuredSize * (tiny and 0.88 or 1), 82, 160) + 0.5)
	local hitMultiplier = configNumber("TouchHitAreaMultiplier", 1.35, 1, 1.75)
	local hitSize = math.floor(thumbSize * hitMultiplier + 0.5)
	local panelWidth = math.max(hitSize, thumbSize)
	local mphH = tiny and 20 or 25
	local boostW = math.floor(math.clamp(thumbSize * 0.94, 92, 140) + 0.5)
	local boostH = math.floor(math.clamp(thumbSize * 0.34, 32, 46) + 0.5)
	local controlsY = mphH + boostH + gap * 2
	local totalHeight = controlsY + hitSize

	leftPanel.Position = UDim2.fromOffset(margin, height - margin - totalHeight)
	leftPanel.Size = UDim2.fromOffset(panelWidth, totalHeight)

	mphLabel.Position = UDim2.fromOffset(math.floor((panelWidth - boostW) * 0.5), 0)
	mphLabel.Size = UDim2.fromOffset(boostW, mphH)
	mphLabel.TextSize = tiny and 13 or 15

	boostButton.Position = UDim2.fromOffset(math.floor((panelWidth - boostW) * 0.5), mphH + gap)
	boostButton.Size = UDim2.fromOffset(boostW, boostH)
	boostText.TextSize = tiny and 11 or 12

	thumbHitArea.Position = UDim2.fromOffset(math.floor((panelWidth - hitSize) * 0.5), controlsY)
	thumbHitArea.Size = UDim2.fromOffset(hitSize, hitSize)
	thumbBase.Size = UDim2.fromOffset(thumbSize, thumbSize)
	local knobSize = math.floor(thumbSize * 0.42 + 0.5)
	thumbKnob.Size = UDim2.fromOffset(knobSize, knobSize)
	driftText.TextSize = tiny and 9 or 10
	setThumbVisual(M.Steer or 0, M.Drift == true)
]==], "responsive layout")

local inputModuleSource = [==[
local MobileDriveInputState = {
	Throttle = 0,
	Steer = 0,
	Drift = false,
	Boost = false,
	SpeedMph = 0,
	BoostPercent = 100,
	IsDriving = false,
	AnalogSteer = 0,
	AnalogDrift = false,
	State = {
		Accelerate = false,
		Brake = false,
		TurnLeft = false,
		TurnRight = false,
		DriftLeft = false,
		DriftRight = false,
		Boost = false,
	},
}

function MobileDriveInputState.Refresh()
	local state = MobileDriveInputState.State
	MobileDriveInputState.Throttle = math.clamp((state.Accelerate and 1 or 0) - (state.Brake and 1 or 0), -1, 1)
	local digitalSteer = math.clamp(
		((state.TurnRight or state.DriftRight) and 1 or 0)
			- ((state.TurnLeft or state.DriftLeft) and 1 or 0),
		-1,
		1
	)
	if math.abs(MobileDriveInputState.AnalogSteer) >= math.abs(digitalSteer) then
		MobileDriveInputState.Steer = MobileDriveInputState.AnalogSteer
	else
		MobileDriveInputState.Steer = digitalSteer
	end
	MobileDriveInputState.Drift = MobileDriveInputState.AnalogDrift
		or state.DriftLeft
		or state.DriftRight
	MobileDriveInputState.Boost = state.Boost
end

function MobileDriveInputState.SetSteering(steer, drift)
	MobileDriveInputState.AnalogSteer = math.clamp(tonumber(steer) or 0, -1, 1)
	MobileDriveInputState.AnalogDrift = drift == true
	MobileDriveInputState.Refresh()
end

function MobileDriveInputState.ReleaseSteering()
	MobileDriveInputState.AnalogSteer = 0
	MobileDriveInputState.AnalogDrift = false
	MobileDriveInputState.Refresh()
end

function MobileDriveInputState.Reset()
	for action in pairs(MobileDriveInputState.State) do
		MobileDriveInputState.State[action] = false
	end
	MobileDriveInputState.AnalogSteer = 0
	MobileDriveInputState.AnalogDrift = false
	MobileDriveInputState.Throttle = 0
	MobileDriveInputState.Steer = 0
	MobileDriveInputState.Drift = false
	MobileDriveInputState.Boost = false
end

return MobileDriveInputState
]==]

-- All guarded source transformations completed. Configuration and source writes
-- begin only after this point.
local configRoot = shared:FindFirstChild("Config")
if not configRoot then
	configRoot = Instance.new("Folder")
	configRoot.Name = "Config"
	configRoot.Parent = shared
elseif not configRoot:IsA("Folder") then
	error("[NTR Mobile Thumbstick] Shared.Config is not a Folder. No source changes applied.")
end

local config = configRoot:FindFirstChild("MobileDriveControls_EditAttributes")
if not config then
	config = Instance.new("Folder")
	config.Name = "MobileDriveControls_EditAttributes"
	config.Parent = configRoot
elseif not config:IsA("Folder") then
	error("[NTR Mobile Thumbstick] MobileDriveControls_EditAttributes is not a Folder. No source changes applied.")
end

local defaults = {
	ThumbstickSizePixels = 118,
	TouchHitAreaMultiplier = 1.35,
	ThumbstickTravelRatio = 0.38,
	SteeringDeadzone = 0.12,
	SteeringResponseExponent = 1.15,
	DriftEnterThreshold = 0.82,
	DriftExitThreshold = 0.70,
}

for name, value in pairs(defaults) do
	if config:GetAttribute(name) == nil then
		config:SetAttribute(name, value)
	end
end
config:SetAttribute("InstalledBy", SCRIPT_ID)

inputModule.Source = inputModuleSource
inputModule:SetAttribute("MobileInputVersion", "FixedThumbstickV1")
mobileController.Source = source
mobileController:SetAttribute("MobileControlsVersion", "FixedThumbstickV1")

print("[NTR Mobile Thumbstick] Installed fixed horizontal steering thumbstick.")
print("[NTR Mobile Thumbstick] Drift enters at 0.82 and exits at 0.70 by default.")
print("[NTR Mobile Thumbstick] Tune values under ReplicatedStorage.NeoTokyoRacers.Shared.Config.MobileDriveControls_EditAttributes.")
print("[NTR Mobile Thumbstick] Play-test fresh in a mobile emulator/device, then refresh the Studio mirror.")
