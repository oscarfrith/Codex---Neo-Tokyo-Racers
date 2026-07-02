-- Persistence Phase 17 module popup card-tracked overlay repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- This replaces the rejected action-rail workaround. The module cards remain
-- clipped inside the bottom carousel, while BUY/LOCKED/EQUIP lives on a stable
-- overlay and tracks the clicked card's rendered centre.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Card Tracked Overlay Repair"

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

local function replaceAllPlain(source, before, after)
	local count = 0
	local position = 1
	while true do
		local first = findPlain(source, before, position)
		if not first then
			break
		end
		source = string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before)
		position = first + #after
		count += 1
	end
	return source, count
end

local function insertBefore(source, needle, insertText, label)
	local first = findPlain(source, needle)
	assert(first, "Could not find insert anchor for " .. label .. ". Refresh the Studio mirror before another popup patch.")
	return string.sub(source, 1, first - 1) .. insertText .. string.sub(source, first)
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "local function renderModuleOptions()"), "Expected renderModuleOptions in active client bootstrap.")
assert(findPlain(source, "NTRPersistencePhase15"), "Expected NTRPersistencePhase15 helper table in active client bootstrap.")

local changes = 0
local renderAnchor = "local function renderModuleOptions()"

local newHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_TRACKED_OVERLAY
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
		local destroyed = pcall(function()
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
	local card = NTRPersistencePhase15.ModulePopupActiveCard
	local popup = NTRPersistencePhase15.EnsureModulePopupObject()
	if not (popup and popup.Visible and card and card.Parent and UI and UI.ModuleOptions) then
		return
	end
	local layer = NTRPersistencePhase15.EnsureModulePopupLayer()
	if not layer then
		return
	end
	UI.ModuleOptions.ClipsDescendants = true

	local cardLeft = card.AbsolutePosition.X
	local cardRight = cardLeft + card.AbsoluteSize.X
	local cardTop = card.AbsolutePosition.Y
	local carouselLeft = UI.ModuleOptions.AbsolutePosition.X
	local carouselRight = carouselLeft + UI.ModuleOptions.AbsoluteSize.X
	local visibleLeft = math.max(cardLeft, carouselLeft)
	local visibleRight = math.min(cardRight, carouselRight)
	if visibleRight - visibleLeft < math.min(24, card.AbsoluteSize.X * 0.35) then
		NTRPersistencePhase15.HideModulePopup()
		return
	end

	local popupWidth = 126
	local halfWidth = popupWidth * 0.5
	local desiredX = cardLeft + (card.AbsoluteSize.X * 0.5)
	local minX = carouselLeft + halfWidth
	local maxX = carouselRight - halfWidth
	if maxX < minX then
		minX = carouselLeft
		maxX = carouselRight
	end
	local popupScreenX = math.clamp(desiredX, minX, maxX)
	local popupScreenY = cardTop - 6

	popup.Parent = layer
	popup.AnchorPoint = Vector2.new(0.5, 1)
	popup.Size = UDim2.fromOffset(popupWidth, 30)
	popup.Position = UDim2.fromOffset(
		math.floor((popupScreenX - layer.AbsolutePosition.X) + 0.5),
		math.floor((popupScreenY - layer.AbsolutePosition.Y) + 0.5)
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
	popup.Parent = layer
	NTRPersistencePhase15.ModulePopupActiveCard = card
	NTRPersistencePhase15.UpdateModulePopupPosition()
end

function NTRPersistencePhase15.DeferModulePopupPosition(card)
	NTRPersistencePhase15.PositionModulePopupAboveCard(card)
	if not NTRPersistencePhase15.ModulePopupTrackerConnection then
		NTRPersistencePhase15.ModulePopupTrackerConnection = game:GetService("RunService").RenderStepped:Connect(function()
			local activeCard = NTRPersistencePhase15.ModulePopupActiveCard
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
if not replacedHelper then
	source = insertBefore(source, renderAnchor, newHelper, "card-tracked module popup helper")
	changes += 1
end

local count
source, count = replaceAllPlain(source, "NTR_hideModulePopup()", "NTRPersistencePhase15.HideModulePopup()")
changes += count
source, count = replaceAllPlain(source, "NTR_deferModulePopupPosition(card)", "NTRPersistencePhase15.DeferModulePopupPosition(card)")
changes += count

local renderStart = [=[local function renderModuleOptions()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)]=]
local renderStartWithHide = [=[local function renderModuleOptions()
	NTRPersistencePhase15.HideModulePopup()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)]=]
if not findPlain(source, renderStartWithHide) then
	local changed
	source, changed = replaceOptional(source, renderStart, renderStartWithHide, "hide popup before module option rerender")
	if changed then
		changes += 1
	end
end

local moduleOptionsClipFalse = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = false }, UI.ModuleOptionsPanel)]=]
local moduleOptionsClipTrue = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)]=]
local changed
source, changed = replaceOptional(source, moduleOptionsClipFalse, moduleOptionsClipTrue, "restore module carousel clipping")
if changed then
	changes += 1
end

local popupLayerOnGui = [=[UI.ModulePopupLayer = new("Frame", { Name = "ModulePopupLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), ClipsDescendants = false, ZIndex = 70 }, gui)]=]
local popupLayerOnShop = [=[UI.ModulePopupLayer = new("Frame", { Name = "ModulePopupLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), ClipsDescendants = false, ZIndex = 70 }, UI.ModuleShop)]=]
source, changed = replaceOptional(source, popupLayerOnGui, popupLayerOnShop, "parent module popup layer to module shop")
if changed then
	changes += 1
end

local oldDirectCanvasHide = [=[UI.ModuleOptions:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if UI.ModulePopup then
			UI.ModulePopup.Visible = false
		end
	end)]=]
local tableCanvasHide = [=[UI.ModuleOptions:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		NTRPersistencePhase15.HideModulePopup()
	end)]=]
source, changed = replaceOptional(source, oldDirectCanvasHide, tableCanvasHide, "hide popup on carousel scroll")
if changed then
	changes += 1
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModulePopupCardTrackedOverlayRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_TRACKED_OVERLAY"), "Card-tracked popup marker was not installed.")
assert(not findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_ACTION_RAIL"), "Rejected action-rail helper remains.")
assert(findPlain(finalSource, "local desiredX = cardLeft + (card.AbsoluteSize.X * 0.5)"), "Popup no longer anchors to the selected card centre.")
assert(findPlain(finalSource, "math.clamp(desiredX, minX, maxX)"), "Popup carousel-bound clamping was not installed.")
assert(findPlain(finalSource, "UI.ModuleOptions.ClipsDescendants = true"), "Module carousel clipping was not restored.")
assert(findPlain(finalSource, "function NTRPersistencePhase15.EnsureModulePopupObject()"), "ModulePopup validation/rebuild helper was not installed.")
assert(findPlain(finalSource, "NTRPersistencePhase15.HideModulePopup()"), "Hide call sites do not use the table-backed helper.")
assert(findPlain(finalSource, "NTRPersistencePhase15.DeferModulePopupPosition(card)"), "Popup action call sites do not use the table-backed helper.")

info("PASS: applied " .. tostring(changes) .. " card-tracked popup overlay change(s).")
info("PASS: module carousel stays clipped, while BUY/LOCKED/EQUIP tracks the clicked card centre with a 6px gap.")
info("Next: restart Play, go Paint Cockpit -> Build Modules, and test buyable/locked cards at left, middle, and far-right scroll positions.")
