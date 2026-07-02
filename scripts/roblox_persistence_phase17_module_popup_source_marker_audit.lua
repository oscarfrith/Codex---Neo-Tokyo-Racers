-- Persistence Phase 17 module popup source marker audit.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Read-only. Prints which module popup helper is currently installed in the
-- active client bootstrap, so we can distinguish a failed install from a bad
-- visual repair.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Source Marker Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
local markers = {
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET",
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_TRACKED_OVERLAY",
	"NTR_PERSISTENCE_PHASE17_MODULE_ACTION_RAIL",
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_TABLE",
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_LAYER",
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CLIPPED_CAROUSEL_OVERLAY",
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_CHILD",
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_ANCHOR",
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_SCREEN_LAYER",
	"NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ABOVE_FRAME",
}

info("Active client: " .. bootstrap:GetFullName())
for _, marker in ipairs(markers) do
	info(marker .. " = " .. tostring(findPlain(source, marker)))
end

info("Attribute PersistencePhase17ModulePopupAnchorTargetRepair = " .. tostring(bootstrap:GetAttribute("PersistencePhase17ModulePopupAnchorTargetRepair")))
info("Attribute PersistencePhase17ModulePopupCardTrackedOverlayRepair = " .. tostring(bootstrap:GetAttribute("PersistencePhase17ModulePopupCardTrackedOverlayRepair")))

if findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET") then
	info("RESULT: anchor-target helper is installed. If popup gap is still ~57px, the next fix should inspect runtime anchors.")
elseif findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_TRACKED_OVERLAY") then
	info("RESULT: old card-tracked overlay helper is still installed. Run scripts/roblox_persistence_phase17_module_popup_anchor_target_repair.lua in Edit mode, then restart Play.")
elseif findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_ACTION_RAIL") then
	info("RESULT: rejected action-rail helper is still installed. Run the anchor-target repair in Edit mode.")
else
	info("RESULT: no known popup helper marker found. Refresh the Studio mirror before another repair.")
end
