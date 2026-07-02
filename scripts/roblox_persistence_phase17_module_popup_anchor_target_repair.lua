-- Persistence Phase 17 module popup anchor-target repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Fixes the remaining case where the carousel clips correctly but
-- BUY/LOCKED/EQUIP is horizontally offset and too high. The previous
-- card-tracked overlay measured from a recycled card reference and clamped to
-- carousel bounds. This repair gives the currently selected rendered card an
-- explicit invisible top-centre PopupAnchor and positions the overlay from
-- that anchor only.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Anchor Target Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceRange(source, startIndex, endIndex, replacement)
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another popup patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another popup patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local function replaceOptional(source, before, after, label)
	if findPlain(source, before) then
		return replaceOnce(source, before, after, label)
	end
	return source, false
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "local function renderModuleOptions()"), "Expected renderModuleOptions in active client bootstrap.")
assert(findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_TRACKED_OVERLAY"), "Expected card-tracked overlay helper in active client bootstrap. Run/refresh the previous mirror before this repair.")

local changes = 0
local renderAnchor = "local function renderModuleOptions()"

local newHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET
NTRPersistencePhase15.ModulePopupActiveCard = nil
NTRPersistencePhase15.ModulePopupTrackerConnection = nil

function NTRPersistencePhase15.EnsureModulePopupLayer()
	if not UI then
		return nil
	end
	if UI.ModulePopupLayer and UI.ModulePopupLayer.Parent == UI.ModuleShop then
		return UI.ModulePopupLayer
	end
	if UI.ModulePopupLayer then
		pcall(function()
			UI.ModulePopupLayer:Destroy()
		end)
		UI.ModulePopupLayer = nil
	end
	if not UI.ModuleShop then
		return nil
	end
	local layer = Instance.new("Frame")
	layer.Name = "ModulePopupLayer"
	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Size = UDim2.fromScale(1, 1)
	layer.Position = UDim2.fromScale(0, 0)
	layer.ClipsDescendants = false
	layer.ZIndex = 70
	layer.Parent = UI.ModuleShop
	UI.ModulePopupLayer = layer
	return layer
end

function NTRPersistencePhase15.EnsureModulePopupObject()
	if not UI then
		return nil
	end
	local layer = NTRPersistencePhase15.EnsureModulePopupLayer() or UI.ModuleOptionsPanel
	if not layer then
		return nil
	end
	if UI.ModulePopup then
		local usable = pcall(function()
			UI.ModulePopup.Visible = UI.ModulePopup.Visible
		end)
		if usable then
			if UI.ModulePopup.Parent == nil then
				local parented = pcall(function()
					UI.ModulePopup.Parent = layer
				end)
				if parented then
					return UI.ModulePopup
				end
			elseif UI.ModulePopup.Parent then
				return UI.ModulePopup
			end
		end
	end
	local popup = panel(layer, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, 0), Vector2.zero)
	popup.Visible = false
	popup.ZIndex = 72
	UI.ModulePopup = popup
	return popup
end

function NTRPersistencePhase15.EnsureModulePopupAnchor(card)
	if not (card and card:IsA("GuiObject")) then
		return nil
	end
	local anchor = card:FindFirstChild("ModulePopupAnchor")
	if anchor and anchor:IsA("Frame") then
		return anchor
	end
	if anchor then
		anchor:Destroy()
	end
	anchor = Instance.new("Frame")
	anchor.Name = "ModulePopupAnchor"
	anchor.BackgroundTransparency = 1
	anchor.BorderSizePixel = 0
	anchor.Size = UDim2.fromOffset(2, 2)
	anchor.AnchorPoint = Vector2.new(0.5, 0.5)
	anchor.Position = UDim2.new(0.5, 0, 0, -6)
	anchor.ZIndex = math.max((card.ZIndex or 1) + 1, 71)
	anchor.Parent = card
	return anchor
end

function NTRPersistencePhase15.FindModulePopupTargetCard()
	if UI and UI.ModuleOptions then
		for _, item in ipairs(UI.ModuleOptions:GetChildren()) do
			if item:IsA("GuiButton") and item.Visible and item:GetAttribute("NTRModulePopupTarget") == true then
				return item
			end
		end
	end
	local card = NTRPersistencePhase15.ModulePopupActiveCard
	if card and card.Parent and card:IsA("GuiObject") and card.Visible then
		return card
	end
	return nil
end

function NTRPersistencePhase15.StopModulePopupTracker()
	NTRPersistencePhase15.ModulePopupActiveCard = nil
	if NTRPersistencePhase15.ModulePopupTrackerConnection then
		NTRPersistencePhase15.ModulePopupTrackerConnection:Disconnect()
		NTRPersistencePhase15.ModulePopupTrackerConnection = nil
	end
end

function NTRPersistencePhase15.HideModulePopup()
	NTRPersistencePhase15.StopModulePopupTracker()
	local popup = NTRPersistencePhase15.EnsureModulePopupObject()
	if not popup then
		return
	end
	popup.Visible = false
	local layer = NTRPersistencePhase15.EnsureModulePopupLayer()
	local parkingParent = layer or UI.ModuleOptionsPanel
	if parkingParent and popup.Parent ~= parkingParent then
		local ok = pcall(function()
			popup.Parent = parkingParent
		end)
		if not ok then
			UI.ModulePopup = nil
			NTRPersistencePhase15.EnsureModulePopupObject()
		end
	end
end

function NTRPersistencePhase15.UpdateModulePopupPosition()
	local popup = NTRPersistencePhase15.EnsureModulePopupObject()
	local card = NTRPersistencePhase15.FindModulePopupTargetCard()
	if not (popup and popup.Visible and card and UI and UI.ModuleOptions) then
		return
	end
	local layer = NTRPersistencePhase15.EnsureModulePopupLayer()
	if not layer then
		return
	end
	UI.ModuleOptions.ClipsDescendants = true

	local anchor = NTRPersistencePhase15.EnsureModulePopupAnchor(card)
	if not anchor then
		NTRPersistencePhase15.HideModulePopup()
		return
	end

	local cardLeft = card.AbsolutePosition.X
	local cardRight = cardLeft + card.AbsoluteSize.X
	local carouselLeft = UI.ModuleOptions.AbsolutePosition.X
	local carouselRight = carouselLeft + UI.ModuleOptions.AbsoluteSize.X
	local visibleLeft = math.max(cardLeft, carouselLeft)
	local visibleRight = math.min(cardRight, carouselRight)
	if visibleRight - visibleLeft < math.min(36, card.AbsoluteSize.X * 0.6) then
		NTRPersistencePhase15.HideModulePopup()
		return
	end

	local anchorX = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X * 0.5
	local anchorY = anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y * 0.5
	if anchorX < carouselLeft or anchorX > carouselRight then
		NTRPersistencePhase15.HideModulePopup()
		return
	end

	popup.Parent = layer
	popup.AnchorPoint = Vector2.new(0.5, 1)
	popup.Size = UDim2.fromOffset(126, 30)
	popup.Position = UDim2.fromOffset(
		math.floor((anchorX - layer.AbsolutePosition.X) + 0.5),
		math.floor((anchorY - layer.AbsolutePosition.Y) + 0.5)
	)
	popup.ZIndex = 72
	for _, child in ipairs(popup:GetDescendants()) do
		if child:IsA("GuiObject") then
			child.ZIndex = 73
		end
	end
end

function NTRPersistencePhase15.PositionModulePopupAboveCard(card)
	local popup = NTRPersistencePhase15.EnsureModulePopupObject()
	if not (popup and card) then
		return
	end
	local layer = NTRPersistencePhase15.EnsureModulePopupLayer()
	if not layer then
		return
	end
	if UI.ModuleOptions then
		UI.ModuleOptions.ClipsDescendants = true
	end
	NTRPersistencePhase15.EnsureModulePopupAnchor(card)
	popup.Parent = layer
	NTRPersistencePhase15.ModulePopupActiveCard = card
	NTRPersistencePhase15.UpdateModulePopupPosition()
end

function NTRPersistencePhase15.DeferModulePopupPosition(card)
	NTRPersistencePhase15.PositionModulePopupAboveCard(card)
	if not NTRPersistencePhase15.ModulePopupTrackerConnection then
		NTRPersistencePhase15.ModulePopupTrackerConnection = game:GetService("RunService").RenderStepped:Connect(function()
			local activeCard = NTRPersistencePhase15.FindModulePopupTargetCard()
			if not (UI and UI.ModulePopup and UI.ModulePopup.Visible and activeCard and activeCard.Parent) then
				NTRPersistencePhase15.StopModulePopupTracker()
				return
			end
			NTRPersistencePhase15.UpdateModulePopupPosition()
		end)
	end
	task.defer(function()
		NTRPersistencePhase15.UpdateModulePopupPosition()
	end)
end

]=]

local helperMarkers = {
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_TRACKED_OVERLAY",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_ACTION_RAIL",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_TABLE_REBUILD",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_TABLE",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_LAYER",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CLIPPED_CAROUSEL_OVERLAY",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_CHILD",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_ANCHOR",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_SCREEN_LAYER",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ABOVE_FRAME",
}

local replacedHelper = false
for _, marker in ipairs(helperMarkers) do
	local markerIndex = findPlain(source, marker)
	local renderIndex = findPlain(source, renderAnchor)
	if markerIndex and renderIndex and markerIndex < renderIndex then
		source = replaceRange(source, markerIndex, renderIndex, newHelper)
		replacedHelper = true
		changes += 1
		break
	end
end
assert(replacedHelper, "Could not find an existing module popup helper marker. Refresh the Studio mirror before another popup patch.")

local ownedCardBefore = [=[local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 86), UDim2.fromOffset(x, 3), cardColor)
			card.AutoButtonColor = not isInstalledHere]=]
local ownedCardAfter = [=[local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 86), UDim2.fromOffset(x, 3), cardColor)
			card:SetAttribute("NTRModuleCard", true)
			card:SetAttribute("NTRModulePopupTarget", selected and not isInstalledHere)
			NTRPersistencePhase15.EnsureModulePopupAnchor(card)
			card.AutoButtonColor = not isInstalledHere]=]
source = replaceOnce(source, ownedCardBefore, ownedCardAfter, "owned module card popup target attributes")
changes += 1

local buyCardBefore = [=[local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 86), UDim2.fromOffset(x, 3), cardColor)
			card.AutoButtonColor = not isInstalled]=]
local buyCardAfter = [=[local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 86), UDim2.fromOffset(x, 3), cardColor)
			card:SetAttribute("NTRModuleCard", true)
			card:SetAttribute("NTRModulePopupTarget", selected and not isInstalled)
			NTRPersistencePhase15.EnsureModulePopupAnchor(card)
			card.AutoButtonColor = not isInstalled]=]
source = replaceOnce(source, buyCardBefore, buyCardAfter, "buy module card popup target attributes")
changes += 1

local popupLayerOnGui = [=[UI.ModulePopupLayer = new("Frame", { Name = "ModulePopupLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), ClipsDescendants = false, ZIndex = 70 }, gui)]=]
local popupLayerOnShop = [=[UI.ModulePopupLayer = new("Frame", { Name = "ModulePopupLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), ClipsDescendants = false, ZIndex = 70 }, UI.ModuleShop)]=]
local changed
source, changed = replaceOptional(source, popupLayerOnGui, popupLayerOnShop, "parent module popup layer to module shop")
if changed then
	changes += 1
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModulePopupAnchorTargetRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET"), "Anchor-target popup marker was not installed.")
assert(not findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_TRACKED_OVERLAY"), "Old card-tracked overlay marker remains.")
assert(findPlain(finalSource, "card:SetAttribute(\"NTRModulePopupTarget\", selected and not isInstalledHere)"), "Owned card target attribute was not installed.")
assert(findPlain(finalSource, "card:SetAttribute(\"NTRModulePopupTarget\", selected and not isInstalled)"), "Buy card target attribute was not installed.")
assert(findPlain(finalSource, "function NTRPersistencePhase15.EnsureModulePopupAnchor(card)"), "PopupAnchor helper was not installed.")
assert(findPlain(finalSource, "anchor.Position = UDim2.new(0.5, 0, 0, -6)"), "PopupAnchor is not at the card top-centre 6px gap.")
assert(not findPlain(finalSource, "math.clamp(desiredX, minX, maxX)"), "Old popup X clamping remains.")

info("PASS: applied " .. tostring(changes) .. " anchor-target popup change(s).")
info("PASS: BUY/LOCKED/EQUIP now follows the selected card's invisible PopupAnchor and hides instead of clamping when the card is not sufficiently visible.")
info("Next: restart Play, click left/middle/right locked and buyable module cards, then rerun the alignment diagnostic. Expected dx near 0 and gap near 6.")
