-- Neo Tokyo Racers - Mobile Thumbstick V2.3 Snappy Steering
-- Run this whole file in the Roblox Studio Command Bar while NOT play-testing.
--
-- Changes only the mobile driving thumbstick controller/config:
--   - removes steering deadzone by default
--   - makes steering response linear by default
--   - shrinks outer drift ring to 1.25x the inner ring size
--   - lowers the boost button so it sits close above the visible drift ring
--   - keeps changes config-driven where practical

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_mobile_drive_thumbstick_v2_3_snappy_steering"

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[NTR Mobile Thumbstick V2.3] Missing %s under %s. No changes applied.")
			:format(name, parent and parent:GetFullName() or "nil"))
	end
	if className and not child:IsA(className) then
		error(("[NTR Mobile Thumbstick V2.3] %s is %s, expected %s. No changes applied.")
			:format(child:GetFullName(), child.ClassName, className))
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		error(("[NTR Mobile Thumbstick V2.3] Preflight failed at %s. Refresh the Studio mirror before another patch; no changes applied.")
			:format(label))
	end
	if string.find(source, oldText, last + 1, true) then
		error(("[NTR Mobile Thumbstick V2.3] Multiple matches at %s; no changes applied.")
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

if version == "FixedThumbstickV2.3" then
	print("[NTR Mobile Thumbstick V2.3] Already installed; refreshing config attributes only.")
else
	source = replaceExact(source, [==[
	local deadzone = configNumber("SteeringDeadzone", 0.12, 0, 0.45)
]==], [==[
	local deadzone = configNumber("SteeringDeadzone", 0, 0, 0.25)
]==], "steering deadzone default")

	source = replaceExact(source, [==[
		local exponent = configNumber("SteeringResponseExponent", 1.15, 0.5, 3)
]==], [==[
		local exponent = configNumber("SteeringResponseExponent", 1, 0.5, 2)
]==], "linear steering response default")

	source = replaceExact(source, [==[
	local hitMultiplier = configNumber("TouchHitAreaMultiplier", 1.35, 1, 1.75)
]==], [==[
	local hitMultiplier = configNumber("TouchHitAreaMultiplier", 1.1, 1, 1.35)
]==], "touch hit area multiplier")

	source = replaceExact(source, [==[
	local outerSize = math.floor(thumbSize * 1.8 + 0.5)
]==], [==[
	local outerSize = math.floor(thumbSize * 1.25 + 0.5)
]==], "outer drift ring size")

	source = replaceExact(source, [==[
	local hudLift = math.floor(configNumber("HudLiftPixels", 12, 0, 40) + 0.5)
	local controlsY = mphH + boostH + gap * 2 + hudLift
	local totalHeight = controlsY + hitSize
]==], [==[
	local hudLift = math.floor(configNumber("HudLiftPixels", 12, 0, 40) + 0.5)
	local boostBuffer = tiny and 4 or 6
	local controlsY = mphH + gap + boostH + boostBuffer
	local totalHeight = controlsY + hitSize + hudLift
]==], "boost-to-thumbstick vertical spacing")

	mobileController.Source = source
	mobileController:SetAttribute("MobileControlsVersion", "FixedThumbstickV2.3")
	mobileController:SetAttribute("LastUpdatedBy", SCRIPT_ID)
	mobileController:SetAttribute("LastUpdatedAt", os.date("%Y-%m-%d %H:%M:%S"))
end

config:SetAttribute("SteeringDeadzone", 0)
config:SetAttribute("SteeringResponseExponent", 1)
config:SetAttribute("TouchHitAreaMultiplier", 1.1)
config:SetAttribute("ThumbstickOuterRingScale", 1.25)
config:SetAttribute("BoostToOuterRingBufferPixels", 6)

print("[NTR Mobile Thumbstick V2.3] Installed snappy mobile steering tune.")
print("[NTR Mobile Thumbstick V2.3] Deadzone default/attribute: 0. Steering response exponent: 1.")
print("[NTR Mobile Thumbstick V2.3] Outer drift ring scale: 1.25x inner ring.")
print("[NTR Mobile Thumbstick V2.3] Boost button now sits close above the visible outer ring.")
print("[NTR Mobile Thumbstick V2.3] Play-test on mobile/emulator, then refresh the Studio mirror.")
