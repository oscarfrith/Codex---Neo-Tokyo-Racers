-- Persistence Phase 17 module popup tracker-layer repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Root fix for the module carousel / BUY-LOCKED popup yo-yo:
-- - module cards stay clipped inside the carousel ScrollingFrame;
-- - the popup is parked on a full-screen overlay under UI.ModuleShop, so it is
--   not clipped by the carousel;
-- - while visible, RenderStepped tracks the selected card's rendered
--   AbsolutePosition and keeps the popup centred with a 6px gap;
-- - scroll, rerender, Next, Back, and stage changes hide/park the popup.
--
-- This is a guarded source-text patch against the active client bootstrap. If
-- it aborts on a missing anchor, refresh the Studio mirror before another patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Tracker Layer Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
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

local function replaceRange(source, startIndex, endIndex, replacement)
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
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
assert(findPlain(source, "UI.Next.MouseButton1Click:Connect(function()"), "Expected Next click handler in active client bootstrap.")
assert(findPlain(source, "UI.Back.MouseButton1Click:Connect(function()"), "Expected Back click handler in active client bootstrap.")

local changes = 0
local changed = false
local renderAnchor = "local function renderModuleOptions()"

local newHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_LAYER
local NTR_activeModulePopupCard = nil
local NTR_modulePopupTrackerConnection = nil

local function NTR_ensureModulePopupLayer()
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

local function NTR_stopModulePopupTracker()
	NTR_activeModulePopupCard = nil
	if NTR_modulePopupTrackerConnection then
		NTR_modulePopupTrackerConnection:Disconnect()
		NTR_modulePopupTrackerConnection = nil
	end
end

local function NTR_updateModulePopupPosition()
	if not (UI and UI.ModulePopup and UI.ModulePopup.Visible and NTR_activeModulePopupCard and NTR_activeModulePopupCard.Parent) then
		return
	end
	local layer = NTR_ensureModulePopupLayer()
	if not layer then
		return
	end
	if UI.ModuleOptions then
		UI.ModuleOptions.ClipsDescendants = true
	end
	local card = NTR_activeModulePopupCard
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

local function NTR_hideModulePopup()
	NTR_stopModulePopupTracker()
	if not (UI and UI.ModulePopup) then
		return
	end
	UI.ModulePopup.Visible = false
	local layer = NTR_ensureModulePopupLayer()
	local parkingParent = layer or UI.ModuleOptionsPanel
	if parkingParent and UI.ModulePopup.Parent ~= parkingParent then
		UI.ModulePopup.Parent = parkingParent
	end
end

local function NTR_positionModulePopupAboveCard(card)
	if not (UI and UI.ModulePopup and card) then
		return
	end
	local layer = NTR_ensureModulePopupLayer()
	if not layer then
		return
	end
	if UI.ModuleOptions then
		UI.ModuleOptions.ClipsDescendants = true
	end
	UI.ModulePopup.Parent = layer
	NTR_activeModulePopupCard = card
	NTR_updateModulePopupPosition()
end

local function NTR_deferModulePopupPosition(card)
	NTR_positionModulePopupAboveCard(card)
	if not NTR_modulePopupTrackerConnection then
		NTR_modulePopupTrackerConnection = game:GetService("RunService").RenderStepped:Connect(function()
			if not (UI and UI.ModulePopup and UI.ModulePopup.Visible and NTR_activeModulePopupCard and NTR_activeModulePopupCard.Parent) then
				NTR_stopModulePopupTracker()
				return
			end
			NTR_updateModulePopupPosition()
		end)
	end
	task.defer(function()
		NTR_updateModulePopupPosition()
	end)
end

]=]

local helperMarkers = {
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
	source = insertBefore(source, renderAnchor, newHelper, "module popup tracker-layer helper")
	changes += 1
end

local badScopedShowStage = [=[local function showStage(stage)
	NTR_hideModulePopup()
	State.Stage = stage]=]
local safeShowStage = [=[local function showStage(stage)
	if UI and UI.ModulePopup then
		UI.ModulePopup.Visible = false
	end
	State.Stage = stage]=]
source, changed = replaceOptional(source, badScopedShowStage, safeShowStage, "safe inline stage popup cleanup")
if changed then
	changes += 1
end

local plainShowStage = [=[local function showStage(stage)
	State.Stage = stage]=]
source, changed = replaceOptional(source, plainShowStage, safeShowStage, "stage popup cleanup")
if changed then
	changes += 1
end

local renderStart = [=[local function renderModuleOptions()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)]=]
local renderStartWithHide = [=[local function renderModuleOptions()
	NTR_hideModulePopup()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)]=]
if not findPlain(source, renderStartWithHide) then
	source, changed = replaceOptional(source, renderStart, renderStartWithHide, "hide popup before module option rerender")
	if changed then
		changes += 1
	end
end

local moduleOptionsClipFalse = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = false }, UI.ModuleOptionsPanel)]=]
local moduleOptionsClipTrue = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)]=]
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
		NTR_hideModulePopup()
	end)]=]
source, changed = replaceOptional(source, oldCanvasHide, newCanvasHide, "hide popup on module carousel scroll")
if changed then
	changes += 1
end

local nextStart = [=[	UI.Next.MouseButton1Click:Connect(function()
		if State.Stage == "CockpitPaint" then]=]
local nextStartWithHide = [=[	UI.Next.MouseButton1Click:Connect(function()
		NTR_hideModulePopup()
		if State.Stage == "CockpitPaint" then]=]
if not findPlain(source, nextStartWithHide) then
	source, changed = replaceOptional(source, nextStart, nextStartWithHide, "hide module popup on Next")
	if changed then
		changes += 1
	end
end

local backStart = [=[	UI.Back.MouseButton1Click:Connect(function()
		if State.Stage == "CockpitPaint" then]=]
local backStartWithHide = [=[	UI.Back.MouseButton1Click:Connect(function()
		NTR_hideModulePopup()
		if State.Stage == "CockpitPaint" then]=]
if not findPlain(source, backStartWithHide) then
	source, changed = replaceOptional(source, backStart, backStartWithHide, "hide module popup on Back")
	if changed then
		changes += 1
	end
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModulePopupTrackerLayerRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_TRACKER_LAYER"), "Tracker-layer helper marker was not installed.")
assert(findPlain(finalSource, "UI.ModuleOptions.ClipsDescendants = true"), "Module carousel clipping was not restored.")
assert(findPlain(finalSource, "layer.Parent = UI.ModuleShop"), "Popup layer is not parented to UI.ModuleShop.")
assert(findPlain(finalSource, "NTR_modulePopupTrackerConnection = game:GetService(\"RunService\").RenderStepped:Connect"), "RenderStepped popup tracker was not installed.")
assert(findPlain(finalSource, "card.AbsolutePosition.X + (card.AbsoluteSize.X * 0.5)"), "Popup is not centred from the selected card's rendered centre.")
assert(findPlain(finalSource, "local function renderModuleOptions()\n\tNTR_hideModulePopup()"), "renderModuleOptions does not hide/park the popup before rerendering cards.")
assert(findPlain(finalSource, "UI.Next.MouseButton1Click:Connect(function()\n\t\tNTR_hideModulePopup()"), "Next does not hide module popup.")
assert(findPlain(finalSource, "UI.Back.MouseButton1Click:Connect(function()\n\t\tNTR_hideModulePopup()"), "Back does not hide module popup.")

info("PASS: applied " .. tostring(changes) .. " module popup tracker-layer source change(s).")
info("PASS: module cards stay clipped inside the carousel while the popup lives on a UI.ModuleShop overlay.")
info("PASS: the popup tracks the selected card's rendered centre every frame while visible.")
info("Next: restart Play, open Build Modules > Buy Modules, click left/middle/right locked or buyable cards, then scroll to confirm cards clip and popup hides.")
