-- Neo Tokyo Racers - Mobile Thumbstick V2.1 Size Refinement
-- Run this whole file in the Roblox Studio Command Bar while NOT play-testing.
--
-- Use this only if the earlier FixedThumbstickV2 was already installed.
-- Fresh V1 places can run the updated V2 visual refinement directly instead.
--
-- Changes:
--   - fixes the outer ring at 1.3x the inner ring size
--   - uses a lighter translucent outer drift-band background
--   - positions DRIFT between the inner and outer ring edges
--   - reduces pedal scale from 1.5 to 1.275 (15% smaller)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[NTR Mobile Thumbstick V2.1] Missing %s under %s. No changes applied.")
			:format(name, parent and parent:GetFullName() or "nil"))
	end
	if className and not child:IsA(className) then
		error(("[NTR Mobile Thumbstick V2.1] %s is %s, expected %s. No changes applied.")
			:format(child:GetFullName(), child.ClassName, className))
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		error(("[NTR Mobile Thumbstick V2.1] Preflight failed at %s. Refresh the Studio mirror before another patch; no changes applied.")
			:format(label))
	end
	if string.find(source, oldText, last + 1, true) then
		error(("[NTR Mobile Thumbstick V2.1] Multiple matches at %s; no changes applied.")
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
local controllers = requireChild(clientRoot, "Controllers", "Folder")
local runtime = requireChild(controllers, "Runtime", "Folder")
local mobileController = requireChild(runtime, "MobileDriveControlsController_Active", "LocalScript")

local version = mobileController:GetAttribute("MobileControlsVersion")
if version == "FixedThumbstickV2.1" then
	print("[NTR Mobile Thumbstick V2.1] Already installed; no changes needed.")
	return
end
if version ~= "FixedThumbstickV2" then
	error("[NTR Mobile Thumbstick V2.1] Expected FixedThumbstickV2. Run the updated V2 installer instead if the place is still on V1.")
end

local source = mobileController.Source

source = replaceExact(source, [==[
thumbOuterRing.BackgroundColor3 = HUD_RED
thumbOuterRing.BackgroundTransparency = 0.93
]==], [==[
thumbOuterRing.BackgroundColor3 = Color3.fromRGB(72, 105, 88)
thumbOuterRing.BackgroundTransparency = 0.72
]==], "outer drift-band fill")

source = replaceExact(source, [==[
driftText.Position = UDim2.fromScale(0.5, -0.02)
driftText.Size = UDim2.fromScale(0.72, 0.2)
]==], [==[
driftText.Position = UDim2.fromScale(0.5, 0.015)
driftText.Size = UDim2.fromScale(0.72, 0.1)
]==], "drift text band position")

source = replaceExact(source, [==[
	local outerSize = math.floor(knobSize + thumbTravelPixels * 2 + 0.5)
]==], [==[
	local outerSize = math.floor(thumbSize * 1.3 + 0.5)
]==], "outer ring scale")

source = replaceExact(source, [==[
	local pedalScale = configNumber("PedalScale", 1.5, 1, 1.75)
]==], [==[
	local pedalScale = configNumber("PedalScale", 1.275, 1, 1.75)
]==], "pedal fallback scale")

-- V2 created this attribute at 1.5. This refinement intentionally changes that
-- installed default to the requested 15%-smaller value.
if config:GetAttribute("PedalScale") == 1.5 then
	config:SetAttribute("PedalScale", 1.275)
end

mobileController.Source = source
mobileController:SetAttribute("MobileControlsVersion", "FixedThumbstickV2.1")
mobileController:SetAttribute("LastUpdatedBy", "roblox_mobile_drive_thumbstick_v2_1_size_refinement")

print("[NTR Mobile Thumbstick V2.1] Outer ring is now 1.3x with a light translucent band.")
print("[NTR Mobile Thumbstick V2.1] DRIFT is positioned inside the ring band.")
print("[NTR Mobile Thumbstick V2.1] Pedal scale is now 1.275.")
print("[NTR Mobile Thumbstick V2.1] Play-test fresh, then refresh the Studio mirror.")
