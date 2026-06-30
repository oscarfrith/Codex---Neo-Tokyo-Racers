-- Neo Tokyo Racers - Mobile Thumbstick V2.4 Large Edge Drift
-- Run this whole file in the Roblox Studio Command Bar while NOT play-testing.
--
-- Guarded follow-up for the V2.3 mobile thumbstick:
--   - increases the visible inner thumbstick circle by 1.4x
--   - makes the visible outer drift ring 1.35x the enlarged inner circle
--   - keeps steering snappy with no deadzone and linear response
--   - moves drift activation near the outer edge of the usable ring
--   - slightly reduces the invisible touch hit area now that the visible ring is larger

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_mobile_drive_thumbstick_v2_4_large_edge_drift"

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[NTR Mobile Thumbstick V2.4] Missing %s under %s. No changes applied.")
			:format(name, parent and parent:GetFullName() or "nil"))
	end
	if className and not child:IsA(className) then
		error(("[NTR Mobile Thumbstick V2.4] %s is %s, expected %s. No changes applied.")
			:format(child:GetFullName(), child.ClassName, className))
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		error(("[NTR Mobile Thumbstick V2.4] Preflight failed at %s. This expects the tested V2.3 source; no changes applied.")
			:format(label))
	end
	if string.find(source, oldText, last + 1, true) then
		error(("[NTR Mobile Thumbstick V2.4] Multiple matches at %s; no changes applied.")
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

local source = mobileController.Source
local version = mobileController:GetAttribute("MobileControlsVersion")

if version == "FixedThumbstickV2.4" then
	print("[NTR Mobile Thumbstick V2.4] Already installed; refreshing config attributes only.")
else
	source = replaceExact(source, [==[
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
]==], [==[
	local enterThreshold = configNumber("DriftEnterThreshold", 0.95, 0.65, 0.99)
	local exitThreshold = math.min(
		configNumber("DriftExitThreshold", 0.88, 0.55, 0.98),
		enterThreshold
	)
]==], "edge-only drift threshold")

	source = replaceExact(source, [==[
	local configuredSize = configNumber("ThumbstickSizePixels", 118, 82, 180)
	local thumbSize = math.floor(math.clamp(configuredSize * (tiny and 0.88 or 1), 82, 160) + 0.5)
	local knobSize = math.floor(thumbSize * 0.42 + 0.5)
	local enterThreshold = configNumber("DriftEnterThreshold", 0.82, 0.5, 1)
	local outerSize = math.floor(thumbSize * 1.25 + 0.5)
	local regularTravel = math.max((thumbSize - knobSize) * 0.5, 1)
	thumbTravelPixels = math.max((outerSize - knobSize) * 0.5, 1)
	thumbDriftThreshold = math.clamp(regularTravel / thumbTravelPixels, 0.05, 0.95)
	local hitMultiplier = configNumber("TouchHitAreaMultiplier", 1.1, 1, 1.35)
]==], [==[
	local configuredSize = configNumber("ThumbstickSizePixels", 118, 82, 180)
	local innerScale = configNumber("ThumbstickInnerScale", 1.4, 1, 1.6)
	local thumbSize = math.floor(math.clamp(configuredSize * innerScale * (tiny and 0.82 or 1), 100, 220) + 0.5)
	local knobSize = math.floor(thumbSize * 0.42 + 0.5)
	local outerScale = configNumber("ThumbstickOuterRingScale", 1.35, 1.25, 1.75)
	local outerSize = math.floor(thumbSize * outerScale + 0.5)
	thumbTravelPixels = math.max((outerSize - knobSize) * 0.5, 1)
	thumbDriftThreshold = math.clamp(configNumber("DriftEnterThreshold", 0.95, 0.65, 0.99), 0.05, 0.99)
	local hitMultiplier = configNumber("TouchHitAreaMultiplier", 1.05, 1, 1.2)
]==], "large thumbstick layout")

	mobileController.Source = source
	mobileController:SetAttribute("MobileControlsVersion", "FixedThumbstickV2.4")
	mobileController:SetAttribute("LastUpdatedBy", SCRIPT_ID)
	mobileController:SetAttribute("LastUpdatedAt", os.date("%Y-%m-%d %H:%M:%S"))
end

config:SetAttribute("SteeringDeadzone", 0)
config:SetAttribute("SteeringResponseExponent", 1)
config:SetAttribute("ThumbstickInnerScale", 1.4)
config:SetAttribute("ThumbstickOuterRingScale", 1.35)
config:SetAttribute("DriftEnterThreshold", 0.95)
config:SetAttribute("DriftExitThreshold", 0.88)
config:SetAttribute("TouchHitAreaMultiplier", 1.05)
config:SetAttribute("BoostToOuterRingBufferPixels", 6)

print("[NTR Mobile Thumbstick V2.4] Installed large edge-drift mobile steering tune.")
print("[NTR Mobile Thumbstick V2.4] Inner circle: 1.4x. Outer ring: 1.35x the enlarged inner circle.")
print("[NTR Mobile Thumbstick V2.4] Drift now enters at 95% outer-ring travel and exits at 88%.")
print("[NTR Mobile Thumbstick V2.4] If the ring is too large on small phones, lower ThumbstickInnerScale first.")
print("[NTR Mobile Thumbstick V2.4] Play-test on mobile/emulator, then refresh the Studio mirror.")
