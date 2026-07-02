-- Persistence Phase 17 module popup tracker register-limit repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Repairs the "Out of local registers when trying to allocate V75Driving"
-- failure after the popup tracker-layer repair by moving popup helpers off
-- top-level local functions and onto the existing NTRPersistencePhase15 table.
--
-- Visual behavior is intentionally preserved:
-- - module cards stay clipped in the carousel;
-- - BUY/LOCKED/EQUIP lives on the UI.ModuleShop overlay;
-- - popup position tracks the selected card's rendered centre while visible.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Tracker Register Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another popup/register patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another popup/register patch.")
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

local function replaceRange(source, startIndex, endIndex, replacement)
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local function insertBefore(source, needle, insertText, label)
	local first = findPlain(source, needle)
	assert(first, "Could not find insert anchor for " .. label .. ". Refresh the Studio mirror before another popup/register patch.")
	return string.sub(source, 1, first - 1) .. insertText .. string.sub(source, first)
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "local NTRPersistencePhase15 = {}") or findPlain(source, "NTRPersistencePhase15 = NTRPersistencePhase15 or {}"), "Expected NTRPersistencePhase15 helper table in active client bootstrap.")
assert(findPlain(source, "local function renderModuleOptions()"), "Expected renderModuleOptions in active client bootstrap.")

local changes = 0
local renderAnchor = "local function renderModuleOptions()"

local newHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_TABLE
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
		UI.ModulePopupLayer:Destroy()
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

function NTRPersistencePhase15.StopModulePopupTracker()
	NTRPersistencePhase15.ModulePopupActiveCard = nil
	if NTRPersistencePhase15.ModulePopupTrackerConnection then
		NTRPersistencePhase15.ModulePopupTrackerConnection:Disconnect()
		NTRPersistencePhase15.ModulePopupTrackerConnection = nil
	end
end

function NTRPersistencePhase15.UpdateModulePopupPosition()
	local card = NTRPersistencePhase15.ModulePopupActiveCard
	if not (UI and UI.ModulePopup and UI.ModulePopup.Visible and card and card.Parent) then
		return
	end
	local layer = NTRPersistencePhase15.EnsureModulePopupLayer()
	if not layer then
		return
	end
	if UI.ModuleOptions then
		UI.ModuleOptions.ClipsDescendants = true
	end
	local popupX = (card.AbsolutePosition.X + (card.AbsoluteSize.X * 0.5)) - layer.AbsolutePosition.X
	local popupY = card.AbsolutePosition.Y - layer.AbsolutePosition.Y - 6
	UI.ModulePopup.AnchorPoint = Vector2.new(0.5, 1)
	UI.ModulePopup.Size = UDim2.fromOffset(126, 30)
	UI.ModulePopup.Position = UDim2.fromOffset(math.floor(popupX + 0.5), math.floor(popupY + 0.5))
	UI.ModulePopup.ZIndex = 72
	for _, child in ipairs(UI.ModulePopup:GetDescendants()) do
		if child:IsA("GuiObject") then
			child.ZIndex = 73
		end
	end
end

function NTRPersistencePhase15.HideModulePopup()
	NTRPersistencePhase15.StopModulePopupTracker()
	if not (UI and UI.ModulePopup) then
		return
	end
	UI.ModulePopup.Visible = false
	local layer = NTRPersistencePhase15.EnsureModulePopupLayer()
	local parkingParent = layer or UI.ModuleOptionsPanel
	if parkingParent and UI.ModulePopup.Parent ~= parkingParent then
		UI.ModulePopup.Parent = parkingParent
	end
end

function NTRPersistencePhase15.PositionModulePopupAboveCard(card)
	if not (UI and UI.ModulePopup and card) then
		return
	end
	local layer = NTRPersistencePhase15.EnsureModulePopupLayer()
	if not layer then
		return
	end
	if UI.ModuleOptions then
		UI.ModuleOptions.ClipsDescendants = true
	end
	UI.ModulePopup.Parent = layer
	NTRPersistencePhase15.ModulePopupActiveCard = card
	NTRPersistencePhase15.UpdateModulePopupPosition()
end

function NTRPersistencePhase15.DeferModulePopupPosition(card)
	NTRPersistencePhase15.PositionModulePopupAboveCard(card)
	if not NTRPersistencePhase15.ModulePopupTrackerConnection then
		NTRPersistencePhase15.ModulePopupTrackerConnection = game:GetService("RunService").RenderStepped:Connect(function()
			if not (UI and UI.ModulePopup and UI.ModulePopup.Visible and NTRPersistencePhase15.ModulePopupActiveCard and NTRPersistencePhase15.ModulePopupActiveCard.Parent) then
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
	source = insertBefore(source, renderAnchor, newHelper, "register-safe module popup tracker helper")
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

local oldCanvasHide = [=[UI.ModuleOptions:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if UI.ModulePopup then
			UI.ModulePopup.Visible = false
		end
	end)]=]
local newCanvasHide = [=[UI.ModuleOptions:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		NTRPersistencePhase15.HideModulePopup()
	end)]=]
source, changed = replaceOptional(source, oldCanvasHide, newCanvasHide, "hide popup on module carousel scroll")
if changed then
	changes += 1
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModulePopupTrackerRegisterRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_TABLE"), "Register-safe tracker marker was not installed.")
assert(not findPlain(finalSource, "local function NTR_hideModulePopup"), "Old local NTR_hideModulePopup helper remains.")
assert(not findPlain(finalSource, "local function NTR_deferModulePopupPosition"), "Old local NTR_deferModulePopupPosition helper remains.")
assert(findPlain(finalSource, "NTRPersistencePhase15.HideModulePopup()"), "Call sites were not moved to NTRPersistencePhase15.HideModulePopup().")
assert(findPlain(finalSource, "NTRPersistencePhase15.DeferModulePopupPosition(card)"), "Popup call sites were not moved to NTRPersistencePhase15.DeferModulePopupPosition(card).")
assert(findPlain(finalSource, "UI.ModuleOptions.ClipsDescendants = true"), "Module carousel clipping was not restored.")
assert(findPlain(finalSource, "layer.Parent = UI.ModuleShop"), "Popup layer is not parented to UI.ModuleShop.")

info("PASS: applied " .. tostring(changes) .. " register-safe popup tracker change(s).")
info("PASS: popup tracker helpers now live on NTRPersistencePhase15 instead of top-level local functions.")
info("PASS: this preserves clipped module cards plus tracked BUY/LOCKED/EQUIP popup positioning.")
info("Next: restart Play. The client bootstrap should no longer hit the V75Driving local-register limit.")
