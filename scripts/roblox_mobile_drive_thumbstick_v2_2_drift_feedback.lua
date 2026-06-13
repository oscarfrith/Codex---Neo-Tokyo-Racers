-- Neo Tokyo Racers - Mobile Thumbstick V2.2 Drift Feedback
-- Run this whole file in the Roblox Studio Command Bar while NOT play-testing.
--
-- Use this when FixedThumbstickV2 or FixedThumbstickV2.1 is already installed.
-- Fresh V1 places should run the updated V2 visual refinement directly.
--
-- Changes:
--   - outer ring radius becomes 1.8x the inner ring radius
--   - outer band becomes slightly darker and translucent
--   - idle outer border and DRIFT text use the light green HUD accent
--   - knob reaches the usable outer edge
--   - crossing the inner-ring edge activates drift and turns knob, text, and
--     outer border red together

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[NTR Mobile Thumbstick V2.2] Missing %s under %s. No changes applied.")
			:format(name, parent and parent:GetFullName() or "nil"))
	end
	if className and not child:IsA(className) then
		error(("[NTR Mobile Thumbstick V2.2] %s is %s, expected %s. No changes applied.")
			:format(child:GetFullName(), child.ClassName, className))
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		error(("[NTR Mobile Thumbstick V2.2] Preflight failed at %s. Refresh the Studio mirror before another patch; no changes applied.")
			:format(label))
	end
	if string.find(source, oldText, last + 1, true) then
		error(("[NTR Mobile Thumbstick V2.2] Multiple matches at %s; no changes applied.")
			:format(label))
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local ntr = requireChild(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = requireChild(ntr, "Shared", "Folder")
local configRoot = requireChild(shared, "Config", "Folder")
local config = requireChild(configRoot, "MobileDriveControls_EditAttributes", "Folder")
local starterScripts = requireChild(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = requireChild(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = requireChild(clientRoot, "Controllers", "Folder")
local runtime = requireChild(controllers, "Runtime", "Folder")
local mobileController = requireChild(runtime, "MobileDriveControlsController_Active", "LocalScript")

local version = mobileController:GetAttribute("MobileControlsVersion")
if version == "FixedThumbstickV2.2" then
	print("[NTR Mobile Thumbstick V2.2] Already installed; no changes needed.")
	return
end
if version ~= "FixedThumbstickV2" and version ~= "FixedThumbstickV2.1" then
	error("[NTR Mobile Thumbstick V2.2] Expected FixedThumbstickV2 or FixedThumbstickV2.1. Fresh V1 places should run the updated V2 installer.")
end

local source = mobileController.Source

if version == "FixedThumbstickV2" then
	source = replaceExact(source, [==[
thumbOuterRing.BackgroundColor3 = HUD_RED
thumbOuterRing.BackgroundTransparency = 0.93
]==], [==[
thumbOuterRing.BackgroundColor3 = Color3.fromRGB(48, 68, 57)
thumbOuterRing.BackgroundTransparency = 0.68
]==], "V2 outer band")

	source = replaceExact(source, [==[
local thumbOuterStroke = stroke(thumbOuterRing, HUD_RED, 0.24, 2)
]==], [==[
local thumbOuterStroke = stroke(thumbOuterRing, HUD_ACCENT, 0.24, 2)
]==], "V2 outer border")

	source = replaceExact(source, [==[
driftText.TextColor3 = HUD_RED
]==], [==[
driftText.TextColor3 = HUD_ACCENT
]==], "V2 drift text colour")

	source = replaceExact(source, [==[
driftText.Position = UDim2.fromScale(0.5, -0.02)
driftText.Size = UDim2.fromScale(0.72, 0.2)
]==], [==[
driftText.Position = UDim2.fromScale(0.5, 0.015)
driftText.Size = UDim2.fromScale(0.72, 0.1)
]==], "V2 drift text band position")

	source = replaceExact(source, [==[
	local outerSize = math.floor(knobSize + thumbTravelPixels * 2 + 0.5)
]==], [==[
	local outerSize = math.floor(thumbSize * 1.8 + 0.5)
]==], "V2 outer size")

	source = replaceExact(source, [==[
	local pedalScale = configNumber("PedalScale", 1.5, 1, 1.75)
]==], [==[
	local pedalScale = configNumber("PedalScale", 1.275, 1, 1.75)
]==], "V2 pedal scale")
else
	source = replaceExact(source, [==[
thumbOuterRing.BackgroundColor3 = Color3.fromRGB(72, 105, 88)
thumbOuterRing.BackgroundTransparency = 0.72
]==], [==[
thumbOuterRing.BackgroundColor3 = Color3.fromRGB(48, 68, 57)
thumbOuterRing.BackgroundTransparency = 0.68
]==], "V2.1 outer band")

	source = replaceExact(source, [==[
local thumbOuterStroke = stroke(thumbOuterRing, HUD_RED, 0.24, 2)
]==], [==[
local thumbOuterStroke = stroke(thumbOuterRing, HUD_ACCENT, 0.24, 2)
]==], "V2.1 outer border")

	source = replaceExact(source, [==[
driftText.TextColor3 = HUD_RED
]==], [==[
driftText.TextColor3 = HUD_ACCENT
]==], "V2.1 drift text colour")

	source = replaceExact(source, [==[
	local outerSize = math.floor(thumbSize * 1.3 + 0.5)
]==], [==[
	local outerSize = math.floor(thumbSize * 1.8 + 0.5)
]==], "V2.1 outer size")
end

source = replaceExact(source, [==[
local thumbTravelPixels = 1
]==], [==[
local thumbTravelPixels = 1
local thumbDriftThreshold = 0.82
]==], "drift threshold state")

source = replaceExact(source, [==[
	thumbBaseStroke.Transparency = math.abs(steer) > 0.01 and 0.08 or 0.22
	thumbOuterStroke.Transparency = drift and 0.04 or 0.24
	thumbOuterStroke.Thickness = drift and 3 or 2
	thumbKnobStroke.Thickness = drift and 2 or 1
	driftText.TextColor3 = drift and HUD_TEXT or HUD_RED
	driftText.TextTransparency = drift and 0 or 0.08
]==], [==[
	thumbBaseStroke.Transparency = math.abs(steer) > 0.01 and 0.08 or 0.22
	thumbOuterStroke.Color = drift and HUD_RED or HUD_ACCENT
	thumbOuterStroke.Transparency = drift and 0.04 or 0.24
	thumbOuterStroke.Thickness = drift and 3 or 2
	thumbKnobStroke.Thickness = drift and 2 or 1
	driftText.TextColor3 = drift and HUD_RED or HUD_ACCENT
	driftText.TextTransparency = drift and 0 or 0.08
]==], "coordinated drift colours")

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
]==], "visible drift threshold")

source = replaceExact(source, [==[
	local regularTravel = math.max((thumbSize - knobSize) * 0.5, 1)
	thumbTravelPixels = regularTravel / enterThreshold
	local outerSize = math.floor(thumbSize * 1.8 + 0.5)
]==], [==[
	local outerSize = math.floor(thumbSize * 1.8 + 0.5)
	local regularTravel = math.max((thumbSize - knobSize) * 0.5, 1)
	thumbTravelPixels = math.max((outerSize - knobSize) * 0.5, 1)
	thumbDriftThreshold = math.clamp(regularTravel / thumbTravelPixels, 0.05, 0.95)
]==], "full outer-edge travel")

if config:GetAttribute("PedalScale") == 1.5 then
	config:SetAttribute("PedalScale", 1.275)
end

mobileController.Source = source
mobileController:SetAttribute("MobileControlsVersion", "FixedThumbstickV2.2")
mobileController:SetAttribute("LastUpdatedBy", "roblox_mobile_drive_thumbstick_v2_2_drift_feedback")

print("[NTR Mobile Thumbstick V2.2] Installed 1.8x-radius outer drift ring.")
print("[NTR Mobile Thumbstick V2.2] Knob, DRIFT text, and outer border now turn red together on drift.")
print("[NTR Mobile Thumbstick V2.2] Pointer reaches the usable outer edge.")
print("[NTR Mobile Thumbstick V2.2] Play-test fresh, then refresh the Studio mirror.")
