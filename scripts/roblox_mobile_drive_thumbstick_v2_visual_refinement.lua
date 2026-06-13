-- Neo Tokyo Racers - Mobile Thumbstick V2 Visual Refinement
-- Run this whole file in the Roblox Studio Command Bar while NOT play-testing.
--
-- Requires the V1 fixed thumbstick installed by:
--   scripts/roblox_mobile_drive_thumbstick_install.lua
--
-- Adds:
--   - an outer drift ring with 1.8x the inner ring radius
--   - persistent DRIFT text at the top of the outer ring
--   - knob travel aligned to the configured drift threshold boundary
--   - a slightly raised MPH/boost stack to clear the larger ring
--   - 1.275x pedal sizing with the surrounding button frames hidden
--
-- This is guarded exact source replacement against the deterministic V1 source.
-- If any expected block differs, no live source is changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_mobile_drive_thumbstick_v2_visual_refinement"

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[NTR Mobile Thumbstick V2] Missing %s under %s. No source changes applied.")
			:format(name, parent and parent:GetFullName() or "nil"))
	end
	if className and not child:IsA(className) then
		error(("[NTR Mobile Thumbstick V2] %s is %s, expected %s. No source changes applied.")
			:format(child:GetFullName(), child.ClassName, className))
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		error(("[NTR Mobile Thumbstick V2] Preflight failed at %s. Refresh the Studio mirror before another patch; no source changes applied.")
			:format(label))
	end
	if string.find(source, oldText, last + 1, true) then
		error(("[NTR Mobile Thumbstick V2] Preflight found multiple matches at %s; no source changes applied.")
			:format(label))
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local ntr = requireChild(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = requireChild(ntr, "Shared", "Folder")
local configRoot = requireChild(shared, "Config", "Folder")
local config = requireChild(configRoot, "MobileDriveControls_EditAttributes", "Folder")

local starterPlayerScripts = requireChild(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = requireChild(starterPlayerScripts, "NeoTokyoRacersClient", "Folder")
local clientControllers = requireChild(clientRoot, "Controllers", "Folder")
local runtimeControllers = requireChild(clientControllers, "Runtime", "Folder")
local mobileController = requireChild(runtimeControllers, "MobileDriveControlsController_Active", "LocalScript")

local currentVersion = mobileController:GetAttribute("MobileControlsVersion")
if currentVersion == "FixedThumbstickV2" then
	print("[NTR Mobile Thumbstick V2] Already installed; no changes needed.")
	return
end
if currentVersion ~= "FixedThumbstickV1" then
	error("[NTR Mobile Thumbstick V2] Expected MobileControlsVersion FixedThumbstickV1. Run the V1 installer first or refresh the mirror; no source changes applied.")
end

local source = mobileController.Source

source = replaceExact(source, [==[
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
]==], [==[
local thumbOuterRing = Instance.new("Frame")
thumbOuterRing.Name = "SteeringDriftOuterRing"
thumbOuterRing.AnchorPoint = Vector2.new(0.5, 0.5)
thumbOuterRing.Position = UDim2.fromScale(0.5, 0.5)
thumbOuterRing.BackgroundColor3 = Color3.fromRGB(48, 68, 57)
thumbOuterRing.BackgroundTransparency = 0.68
thumbOuterRing.BorderSizePixel = 0
thumbOuterRing.Active = false
thumbOuterRing.Parent = thumbHitArea
corner(thumbOuterRing, 999)
local thumbOuterStroke = stroke(thumbOuterRing, HUD_ACCENT, 0.24, 2)

local thumbBase = Instance.new("Frame")
thumbBase.Name = "SteeringThumbstickBase"
thumbBase.AnchorPoint = Vector2.new(0.5, 0.5)
thumbBase.Position = UDim2.fromScale(0.5, 0.5)
thumbBase.BackgroundColor3 = HUD_PANEL_SOFT
thumbBase.BackgroundTransparency = 0.18
thumbBase.BorderSizePixel = 0
thumbBase.Active = false
thumbBase.ZIndex = thumbOuterRing.ZIndex + 1
thumbBase.Parent = thumbOuterRing
corner(thumbBase, 999)
local thumbBaseStroke = stroke(thumbBase, HUD_ACCENT, 0.22, 2)

local thumbGuide = Instance.new("Frame")
thumbGuide.Name = "HorizontalGuide"
thumbGuide.AnchorPoint = Vector2.new(0.5, 0.5)
thumbGuide.Position = UDim2.fromScale(0.5, 0.5)
thumbGuide.Size = UDim2.fromScale(0.62, 0.035)
thumbGuide.BackgroundColor3 = HUD_ACCENT
thumbGuide.BackgroundTransparency = 0.58
thumbGuide.BorderSizePixel = 0
thumbGuide.Active = false
thumbGuide.ZIndex = thumbBase.ZIndex + 1
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
thumbKnob.ZIndex = thumbBase.ZIndex + 3
thumbKnob.Parent = thumbOuterRing
corner(thumbKnob, 999)
local thumbKnobStroke = stroke(thumbKnob, HUD_TEXT, 0.2, 1)

local driftText = Instance.new("TextLabel")
driftText.Name = "DriftThresholdLabel"
driftText.AnchorPoint = Vector2.new(0.5, 0)
driftText.Position = UDim2.fromScale(0.5, 0.015)
driftText.Size = UDim2.fromScale(0.72, 0.1)
driftText.BackgroundTransparency = 1
driftText.BorderSizePixel = 0
driftText.Text = "DRIFT"
driftText.TextColor3 = HUD_ACCENT
driftText.TextTransparency = 0.08
driftText.TextSize = 10
driftText.ZIndex = thumbKnob.ZIndex + 1
driftText.Active = false
applyText(driftText)
driftText.Parent = thumbOuterRing

local thumbTravelPixels = 1
local thumbDriftThreshold = 0.82
]==], "concentric drift ring UI")

source = replaceExact(source, [==[
local function makePedal(name, label, colour)
	local b = button(rightPanel, name, "")
	local pad = Instance.new("Frame")
]==], [==[
local function makePedal(name, label, colour)
	local b = button(rightPanel, name, "")
	b.BackgroundTransparency = 1
	local outerStroke = b:FindFirstChild("HUDStroke")
	if outerStroke then outerStroke.Transparency = 1 end
	local pad = Instance.new("Frame")
]==], "hide pedal outer frames")

source = replaceExact(source, [==[
	pad.Position = UDim2.fromScale(0.16, 0.1)
	pad.Size = UDim2.fromScale(0.68, 0.72)
]==], [==[
	pad.Position = UDim2.fromScale(0.08, 0.05)
	pad.Size = UDim2.fromScale(0.84, 0.86)
]==], "expand visible pedal pads")

source = replaceExact(source, [==[
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
]==], [==[
local function setPressed(b, active)
	if b == accel or b == brake then
		b.BackgroundTransparency = 1
		local outerStroke = b:FindFirstChild("HUDStroke")
		if outerStroke then outerStroke.Transparency = 1 end
		local pad = b:FindFirstChild("RubberPad")
		if pad then
			pad.BackgroundTransparency = active and 0 or 0.02
			local padStroke = pad:FindFirstChild("HUDStroke")
			if padStroke then
				padStroke.Transparency = active and 0.12 or 0.48
				padStroke.Thickness = active and 2 or 1
			end
		end
		return
	end

	b.BackgroundColor3 = active and HUD_ACCENT or HUD_PANEL_SOFT
	b.BackgroundTransparency = active and 0.03 or 0.03
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
]==], "clean pedal pressed state")

source = replaceExact(source, [==[
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
]==], [==[
local function setThumbVisual(steer, drift)
	thumbKnob.Position = UDim2.fromOffset(
		thumbOuterRing.AbsoluteSize.X * 0.5 + steer * thumbTravelPixels,
		thumbOuterRing.AbsoluteSize.Y * 0.5
	)
	local activeColour = drift and HUD_RED or HUD_ACCENT
	thumbKnob.BackgroundColor3 = activeColour
	thumbBaseStroke.Color = drift and HUD_RED or HUD_ACCENT
	thumbBaseStroke.Transparency = math.abs(steer) > 0.01 and 0.08 or 0.22
	thumbOuterStroke.Color = drift and HUD_RED or HUD_ACCENT
	thumbOuterStroke.Transparency = drift and 0.04 or 0.24
	thumbOuterStroke.Thickness = drift and 3 or 2
	thumbKnobStroke.Thickness = drift and 2 or 1
	driftText.TextColor3 = drift and HUD_RED or HUD_ACCENT
	driftText.TextTransparency = drift and 0 or 0.08
end

local function updateSteering(position)
	local centerX = thumbOuterRing.AbsolutePosition.X + thumbOuterRing.AbsoluteSize.X * 0.5
	local raw = math.clamp((position.X - centerX) / math.max(thumbTravelPixels, 1), -1, 1)
]==], "align visual and input travel")

source = replaceExact(source, [==[
	local enterThreshold = configNumber("DriftEnterThreshold", 0.82, 0.5, 1)
	local exitThreshold = math.min(
		configNumber("DriftExitThreshold", 0.70, 0.35, 0.95),
		enterThreshold
	)
]==], [==[
	local configuredEnter = configNumber("DriftEnterThreshold", 0.82, 0.5, 1)
	local configuredExit = math.min(
		configNumber("DriftExitThreshold", 0.70, 0.35, 0.95),
		configuredEnter
	)
	local enterThreshold = thumbDriftThreshold
	local exitThreshold = enterThreshold * math.clamp(
		configuredExit / math.max(configuredEnter, 0.01),
		0.55,
		0.98
	)
]==], "visual drift threshold")

source = replaceExact(source, [==[
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
]==], [==[
	local configuredSize = configNumber("ThumbstickSizePixels", 118, 82, 180)
	local thumbSize = math.floor(math.clamp(configuredSize * (tiny and 0.88 or 1), 82, 160) + 0.5)
	local knobSize = math.floor(thumbSize * 0.42 + 0.5)
	local outerSize = math.floor(thumbSize * 1.8 + 0.5)
	local regularTravel = math.max((thumbSize - knobSize) * 0.5, 1)
	thumbTravelPixels = math.max((outerSize - knobSize) * 0.5, 1)
	thumbDriftThreshold = math.clamp(regularTravel / thumbTravelPixels, 0.05, 0.95)
	local hitMultiplier = configNumber("TouchHitAreaMultiplier", 1.35, 1, 1.75)
	local hitSize = math.floor(outerSize * hitMultiplier + 0.5)
	local panelWidth = math.max(hitSize, outerSize)
	local mphH = tiny and 20 or 25
	local boostW = math.floor(math.clamp(thumbSize * 0.94, 92, 140) + 0.5)
	local boostH = math.floor(math.clamp(thumbSize * 0.34, 32, 46) + 0.5)
	local hudLift = math.floor(configNumber("HudLiftPixels", 12, 0, 40) + 0.5)
	local controlsY = mphH + boostH + gap * 2 + hudLift
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
	thumbOuterRing.Size = UDim2.fromOffset(outerSize, outerSize)
	thumbBase.Size = UDim2.fromOffset(thumbSize, thumbSize)
	thumbKnob.Size = UDim2.fromOffset(knobSize, knobSize)
	driftText.TextSize = tiny and 9 or 10
	setThumbVisual(M.Steer or 0, M.Drift == true)
]==], "outer ring layout and HUD lift")

source = replaceExact(source, [==[
	local accelW = math.floor(math.clamp(width * 0.1, tiny and 55 or 66, tiny and 72 or 86) + 0.5)
	local accelH = math.floor(math.clamp(height * 0.18, tiny and 88 or 108, tiny and 122 or 148) + 0.5)
	local brakeW = math.floor(accelW * 0.86 + 0.5)
	local brakeH = math.floor(accelH * 0.86 + 0.5)
]==], [==[
	local pedalScale = configNumber("PedalScale", 1.275, 1, 1.75)
	local baseAccelW = math.clamp(width * 0.1, tiny and 55 or 66, tiny and 72 or 86)
	local baseAccelH = math.clamp(height * 0.18, tiny and 88 or 108, tiny and 122 or 148)
	local accelW = math.floor(math.min(baseAccelW * pedalScale, width * 0.16) + 0.5)
	local accelH = math.floor(math.min(baseAccelH * pedalScale, height * 0.34) + 0.5)
	local brakeW = math.floor(accelW * 0.86 + 0.5)
	local brakeH = math.floor(accelH * 0.86 + 0.5)
]==], "larger pedal layout")

local defaults = {
	PedalScale = 1.275,
	HudLiftPixels = 12,
}
for name, value in pairs(defaults) do
	if config:GetAttribute(name) == nil then
		config:SetAttribute(name, value)
	end
end

mobileController.Source = source
mobileController:SetAttribute("MobileControlsVersion", "FixedThumbstickV2")
mobileController:SetAttribute("LastUpdatedBy", SCRIPT_ID)

print("[NTR Mobile Thumbstick V2] Installed concentric regular-turn/drift rings.")
print("[NTR Mobile Thumbstick V2] Outer ring radius is 1.8x with a darker translucent drift band.")
print("[NTR Mobile Thumbstick V2] Pointer travel and drift activation align with the inner-ring boundary.")
print("[NTR Mobile Thumbstick V2] Pedals use 1.275x sizing and hidden outer frames.")
print("[NTR Mobile Thumbstick V2] Tune PedalScale and HudLiftPixels under MobileDriveControls_EditAttributes.")
print("[NTR Mobile Thumbstick V2] Play-test fresh, then refresh the Studio mirror.")
