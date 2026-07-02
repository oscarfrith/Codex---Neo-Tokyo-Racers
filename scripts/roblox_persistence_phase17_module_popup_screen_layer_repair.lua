-- Persistence Phase 17 module popup screen-layer repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- UI-only repair for module BUY/LOCKED/EQUIP popups:
-- - moves the popup from the padded ModuleOptions panel into a full-screen
--   overlay layer;
-- - positions the popup in screen coordinates from the selected card's actual
--   AbsolutePosition;
-- - places the popup above the bottom module-options frame with an 8px gap;
-- - rechecks the position over the next rendered frames after scrolling/layout
--   settles;
-- - keeps the existing hide-on-scroll behavior.
--
-- This uses guarded source replacement against the active client bootstrap. If
-- an anchor fails, refresh the Studio mirror before another popup patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Screen Layer Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceRange(source, startNeedle, endNeedle, replacement, label)
	local startIndex = findPlain(source, startNeedle)
	assert(startIndex, "Could not find start anchor for " .. label .. ". Refresh the Studio mirror before another popup patch.")
	local endIndex = findPlain(source, endNeedle, startIndex + #startNeedle)
	assert(endIndex, "Could not find end anchor for " .. label .. ". Refresh the Studio mirror before another popup patch.")
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local function insertBefore(source, needle, insertText, label)
	local first = findPlain(source, needle)
	assert(first, "Could not find insert anchor for " .. label .. ". Refresh the Studio mirror before another popup patch.")
	return string.sub(source, 1, first - 1) .. insertText .. string.sub(source, first)
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
assert(findPlain(source, "UI.ModuleOptionsPanel = panel(UI.ModuleShop"), "Expected ModuleOptionsPanel creation in active client bootstrap.")
assert(findPlain(source, "UI.ModulePopup"), "Expected ModulePopup references in active client bootstrap.")

local changes = 0
local changed = false

local helperStart = "-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ABOVE_FRAME"
local helperEnd = "local function renderModuleOptions()"
local newHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_SCREEN_LAYER
local function NTR_positionModulePopupAboveCard(card)
	if not (UI and UI.ModulePopup and UI.ModuleOptionsPanel and card) then
		return
	end
	if UI.ModulePopupLayer and UI.ModulePopup.Parent ~= UI.ModulePopupLayer then
		UI.ModulePopup.Parent = UI.ModulePopupLayer
	end
	local layer = UI.ModulePopupLayer or UI.ModulePopup.Parent
	if not layer then
		return
	end
	local popupWidth = UI.ModulePopup.AbsoluteSize.X
	if popupWidth <= 0 then
		popupWidth = 126
	end
	local popupHeight = UI.ModulePopup.AbsoluteSize.Y
	if popupHeight <= 0 then
		popupHeight = 30
	end
	local layerWidth = layer.AbsoluteSize.X
	if layerWidth <= 0 then
		layerWidth = popupWidth
	end
	local cardCenterX = card.AbsolutePosition.X + (card.AbsoluteSize.X * 0.5)
	local popupX = math.clamp(cardCenterX - layer.AbsolutePosition.X - (popupWidth * 0.5), 6, math.max(6, layerWidth - popupWidth - 6))
	local popupY = UI.ModuleOptionsPanel.AbsolutePosition.Y - layer.AbsolutePosition.Y - popupHeight - 8
	UI.ModulePopup.Position = UDim2.fromOffset(math.floor(popupX + 0.5), math.floor(popupY + 0.5))
	UI.ModulePopup.ZIndex = 72
	for _, child in ipairs(UI.ModulePopup:GetDescendants()) do
		if child:IsA("GuiObject") then
			child.ZIndex = 73
		end
	end
end

local function NTR_deferModulePopupPosition(card)
	NTR_positionModulePopupAboveCard(card)
	task.spawn(function()
		for _ = 1, 3 do
			if RunService and RunService.RenderStepped then
				RunService.RenderStepped:Wait()
			else
				task.wait()
			end
			if not (UI and UI.ModulePopup and UI.ModulePopup.Visible) then
				return
			end
			NTR_positionModulePopupAboveCard(card)
		end
	end)
end

]=]

if findPlain(source, helperStart) then
	source = replaceRange(source, helperStart, helperEnd, newHelper, "module popup screen-layer helper")
	changes += 1
elseif not findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_SCREEN_LAYER") then
	source = insertBefore(source, helperEnd, newHelper, "module popup screen-layer helper insert")
	changes += 1
end

local oldPanelPopupCreation = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)
	makeArrowScroller(UI.ModuleOptionsPanel, UI.ModuleOptions, "X", 344)
	UI.ModulePopup = panel(UI.ModuleOptionsPanel, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, -28), Vector2.zero)
	UI.ModulePopup.Visible = false
	UI.ModuleOptions:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if UI.ModulePopup then
			UI.ModulePopup.Visible = false
		end
	end)]=]

local newScreenLayerPopupCreation = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)
	makeArrowScroller(UI.ModuleOptionsPanel, UI.ModuleOptions, "X", 344)
	-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_SCREEN_LAYER_CREATE
	UI.ModulePopupLayer = new("Frame", { Name = "ModulePopupLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), ClipsDescendants = false, ZIndex = 70 }, gui)
	UI.ModulePopup = panel(UI.ModulePopupLayer, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, 0), Vector2.zero)
	UI.ModulePopup.ZIndex = 72
	UI.ModulePopup.Visible = false
	UI.ModuleOptions:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if UI.ModulePopup then
			UI.ModulePopup.Visible = false
		end
	end)]=]

source, changed = replaceOptional(source, oldPanelPopupCreation, newScreenLayerPopupCreation, "module popup screen-layer creation")
if changed then
	changes += 1
end

local oldAlreadyLayerNoZ = [=[UI.ModulePopupLayer = new("Frame", { Name = "ModulePopupLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), ClipsDescendants = false }, gui)
	UI.ModulePopup = panel(UI.ModulePopupLayer, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, 0), Vector2.zero)
	UI.ModulePopup.Visible = false]=]

local newAlreadyLayerWithZ = [=[UI.ModulePopupLayer = new("Frame", { Name = "ModulePopupLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), ClipsDescendants = false, ZIndex = 70 }, gui)
	UI.ModulePopup = panel(UI.ModulePopupLayer, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, 0), Vector2.zero)
	UI.ModulePopup.ZIndex = 72
	UI.ModulePopup.Visible = false]=]

source, changed = replaceOptional(source, oldAlreadyLayerNoZ, newAlreadyLayerWithZ, "module popup screen-layer z-index")
if changed then
	changes += 1
end

assert(findPlain(source, "NTR_deferModulePopupPosition(card)"), "Expected popup call sites to use NTR_deferModulePopupPosition(card).")
assert(findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_SCREEN_LAYER"), "Expected screen-layer helper marker after patch.")
assert(findPlain(source, "UI.ModulePopupLayer"), "Expected ModulePopupLayer creation/reference after patch.")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModulePopupScreenLayerRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "card.AbsolutePosition.X + (card.AbsoluteSize.X * 0.5)"), "Screen-coordinate card centering was not installed.")
assert(findPlain(finalSource, "UI.ModuleOptionsPanel.AbsolutePosition.Y"), "Above-frame popup Y positioning was not installed.")
assert(findPlain(finalSource, "UI.ModulePopupLayer = new(\"Frame\""), "ModulePopupLayer creation was not installed.")
assert(findPlain(finalSource, "UI.ModulePopup.Parent = UI.ModulePopupLayer"), "Popup reparent guard was not installed.")
assert(findPlain(finalSource, "for _ = 1, 3 do"), "Multi-frame popup positioning retry was not installed.")

if changes == 0 then
	info("PASS: module popup screen-layer repair was already present.")
else
	info("PASS: applied " .. tostring(changes) .. " module popup screen-layer source change(s).")
end
info("PASS: BUY/LOCKED/EQUIP popups now use a full-screen overlay layer and selected-card screen coordinates.")
info("PASS: popups are positioned above the bottom module-options frame with an 8px gap.")
info("PASS: popups re-centre across the next rendered frames and still hide when the carousel scrolls.")
info("Next: restart Play, open Build Modules > Buy Modules, scroll far right, click several locked and buyable cards, and confirm the popup is centred above each selected card.")
