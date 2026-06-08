-- Neo Tokyo Racers - Vehicle Phase AK module entry camera repair
--
-- Run this in Roblox Studio Command Bar after Phase AK if the preview camera is
-- too close/tilted down after buying a cockpit and entering Build Modules.
--
-- It changes only the CockpitPaint -> ModuleShop transition so the camera starts
-- on the same section as the Front Engine module camera before the player clicks
-- any module slot.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Vehicle Phase AK Module Entry Camera Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function replaceOnce(source, needle, replacement, label)
	local firstStart, firstEnd = string.find(source, needle, 1, true)
	if not firstStart then
		error(label .. " expected exactly 1 match, found 0")
	end
	local secondStart = string.find(source, needle, firstEnd + 1, true)
	if secondStart then
		error(label .. " expected exactly 1 match, found more than 1")
	end
	return string.sub(source, 1, firstStart - 1) .. replacement .. string.sub(source, firstEnd + 1)
end

local clientScript = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local source = clientScript.Source

if string.find(source, "NTR_VEHICLE_PHASE_AK_MODULE_ENTRY_CAMERA_REPAIR", 1, true) then
	info("Module entry camera repair already installed.")
	return
end

source = replaceOnce(source,
[[		if State.Stage == "CockpitPaint" then
			clearPreviewModules()
			State.ModuleMode = "Slots"
			showStage("ModuleShop")
			renderModuleShop()]],
[[		if State.Stage == "CockpitPaint" then
			clearPreviewModules()
			State.ModuleMode = "Slots"
			-- NTR_VEHICLE_PHASE_AK_MODULE_ENTRY_CAMERA_REPAIR
			setCameraSection("Engine1")
			showStage("ModuleShop")
			renderModuleShop()]],
	"CockpitPaint to ModuleShop camera transition")

clientScript.Source = source
info("Patched Build Modules entry camera to match the Front Engine view. Stop Play and start Play again.")
