-- Persistence Phase 17 module popup runtime anchor diagnostic.
--
-- Run from the Roblox Studio CLIENT Command Bar while in Play mode.
--
-- This is read-only. It checks the running PlayerScripts clone, visible
-- ModulePopup instances, target-card attributes, and ModulePopupAnchor
-- positions. Use it when the normal alignment diagnostic keeps reporting the
-- old 57px gap after an Edit-mode repair.

local Players = game:GetService("Players")

local PHASE = "Persistence Phase 17 Module Popup Runtime Anchor Diagnostic"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function hasText(source, needle)
	return type(source) == "string" and string.find(source, needle, 1, true) ~= nil
end

local function centerX(object)
	return object.AbsolutePosition.X + object.AbsoluteSize.X * 0.5
end

local function bottomY(object)
	return object.AbsolutePosition.Y + object.AbsoluteSize.Y
end

local function visibleWidthInCarousel(card, carousel)
	local left = math.max(card.AbsolutePosition.X, carousel.AbsolutePosition.X)
	local right = math.min(card.AbsolutePosition.X + card.AbsoluteSize.X, carousel.AbsolutePosition.X + carousel.AbsoluteSize.X)
	return math.max(0, right - left)
end

local function pathFromPlayerGui(object)
	local parts = {}
	local current = object
	while current do
		table.insert(parts, 1, current.Name)
		if current:IsA("PlayerGui") then
			break
		end
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local function isVisibleObject(object)
	local current = object
	while current do
		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end
		current = current.Parent
	end
	return true
end

local player = Players.LocalPlayer
assert(player, "Run this from the CLIENT Command Bar in Play mode.")

local playerGui = player:WaitForChild("PlayerGui")
local garageGui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
assert(garageGui, "HOVER_RACING_V2_GarageUI was not found. Open the garage/customisation UI first.")

local playerScripts = player:FindFirstChild("PlayerScripts")
local runtimeBootstrap = playerScripts
	and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	and playerScripts.NeoTokyoRacersClient:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

info("Runtime bootstrap found = " .. tostring(runtimeBootstrap ~= nil))
if runtimeBootstrap and runtimeBootstrap:IsA("LocalScript") then
	local ok, source = pcall(function()
		return runtimeBootstrap.Source
	end)
	info("Runtime source readable = " .. tostring(ok))
	if ok then
		info("Runtime marker ANCHOR_TARGET = " .. tostring(hasText(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET")))
		info("Runtime marker CARD_TRACKED_OVERLAY = " .. tostring(hasText(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_TRACKED_OVERLAY")))
		info("Runtime marker ACTION_RAIL = " .. tostring(hasText(source, "NTR_PERSISTENCE_PHASE17_MODULE_ACTION_RAIL")))
		info("Runtime pooled target reset = " .. tostring(hasText(source, "b:SetAttribute(\"NTRModulePopupTarget\", nil)")))
	end
end

local carousel
for _, item in ipairs(garageGui:GetDescendants()) do
	if item.Name == "ModuleOptionsScroll" then
		carousel = item
		break
	end
end
assert(carousel and carousel:IsA("ScrollingFrame"), "ModuleOptionsScroll was not found.")

info(string.format(
	"Carousel pos=(%.1f, %.1f) size=(%.1f, %.1f) canvasX=%.1f",
	carousel.AbsolutePosition.X,
	carousel.AbsolutePosition.Y,
	carousel.AbsoluteSize.X,
	carousel.AbsoluteSize.Y,
	carousel.CanvasPosition.X
))

local popups = {}
for _, item in ipairs(garageGui:GetDescendants()) do
	if item.Name == "ModulePopup" and item:IsA("GuiObject") then
		table.insert(popups, item)
	end
end
info("ModulePopup count = " .. tostring(#popups))
for index, popup in ipairs(popups) do
	info(string.format(
		"Popup %d visible=%s path=%s centerX=%.1f bottom=%.1f pos=(%.1f, %.1f) size=(%.1f, %.1f)",
		index,
		tostring(popup.Visible and isVisibleObject(popup)),
		pathFromPlayerGui(popup),
		centerX(popup),
		bottomY(popup),
		popup.AbsolutePosition.X,
		popup.AbsolutePosition.Y,
		popup.AbsoluteSize.X,
		popup.AbsoluteSize.Y
	))
end

local targetCards = {}
local visibleCards = {}
for _, item in ipairs(carousel:GetChildren()) do
	if item:IsA("GuiButton") and item.Visible then
		local visibleWidth = visibleWidthInCarousel(item, carousel)
		if item.AbsoluteSize.X >= 100 and item.AbsoluteSize.Y >= 50 and visibleWidth > 1 then
			table.insert(visibleCards, item)
		end
		if item:GetAttribute("NTRModulePopupTarget") == true then
			table.insert(targetCards, item)
		end
	end
end

info("Visible card count = " .. tostring(#visibleCards))
info("Target card count = " .. tostring(#targetCards))

for index, card in ipairs(targetCards) do
	local anchor = card:FindFirstChild("ModulePopupAnchor")
	local anchorSummary = "anchor=nil"
	if anchor and anchor:IsA("GuiObject") then
		anchorSummary = string.format(
			"anchor center=(%.1f, %.1f) pos=(%.1f, %.1f) size=(%.1f, %.1f)",
			centerX(anchor),
			anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y * 0.5,
			anchor.AbsolutePosition.X,
			anchor.AbsolutePosition.Y,
			anchor.AbsoluteSize.X,
			anchor.AbsoluteSize.Y
		)
	end
	info(string.format(
		"Target %d card path=%s centerX=%.1f top=%.1f size=(%.1f, %.1f) visibleWidth=%.1f %s",
		index,
		pathFromPlayerGui(card),
		centerX(card),
		card.AbsolutePosition.Y,
		card.AbsoluteSize.X,
		card.AbsoluteSize.Y,
		visibleWidthInCarousel(card, carousel),
		anchorSummary
	))
end

table.sort(visibleCards, function(a, b)
	return a.AbsolutePosition.X < b.AbsolutePosition.X
end)
for index = 1, math.min(10, #visibleCards) do
	local card = visibleCards[index]
	local anchor = card:FindFirstChild("ModulePopupAnchor")
	info(string.format(
		"Card %02d centerX=%.1f top=%.1f target=%s anchor=%s visibleWidth=%.1f",
		index,
		centerX(card),
		card.AbsolutePosition.Y,
		tostring(card:GetAttribute("NTRModulePopupTarget") == true),
		tostring(anchor ~= nil),
		visibleWidthInCarousel(card, carousel)
	))
end

info("Done. If runtime marker is not ANCHOR_TARGET, restart Play. If target count is not 1, fix pooled target reset. If target anchor Y is near 664 but popup bottom is 613, fix overlay positioning.")
