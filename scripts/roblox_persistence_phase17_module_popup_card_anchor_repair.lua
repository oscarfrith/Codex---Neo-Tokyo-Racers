-- Persistence Phase 17 module popup card-anchor repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- UI-only repair for BUY/LOCKED/EQUIP module popups:
-- - creates a tiny invisible anchor at the selected module card's top centre;
-- - positions the popup from that anchor instead of from the bottom frame;
-- - uses a small 6px gap, matching the tight Paint Cockpit channel-button feel;
-- - keeps the popup on the full-screen overlay layer when present;
-- - hides the popup whenever Next, Back, or a stage change runs.
--
-- This uses guarded source replacement against the active client bootstrap. If
-- an anchor fails, refresh the Studio mirror before another popup patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Card Anchor Repair"

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
assert(findPlain(source, "UI.Next.MouseButton1Click:Connect(function()"), "Expected Next click handler in active client bootstrap.")
assert(findPlain(source, "UI.Back.MouseButton1Click:Connect(function()"), "Expected Back click handler in active client bootstrap.")

local changes = 0
local changed = false

local helperEnd = "local function renderModuleOptions()"
local helperStart = "-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_ANCHOR"
local oldScreenLayerStart = "-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_SCREEN_LAYER"
local oldAboveFrameStart = "-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ABOVE_FRAME"

local newHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_ANCHOR
local function NTR_hideModulePopup()
	if UI and UI.ModulePopup then
		UI.ModulePopup.Visible = false
	end
end

local function NTR_modulePopupAnchor(card)
	if not card then
		return nil
	end
	local anchor = card:FindFirstChild("NTR_ModulePopupAnchor")
	if not anchor then
		anchor = new("Frame", {
			Name = "NTR_ModulePopupAnchor",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			ClipsDescendants = false,
			ZIndex = 1,
		}, card)
	end
	return anchor
end

local function NTR_positionModulePopupAboveCard(card)
	if not (UI and UI.ModulePopup and card) then
		return
	end
	if UI.ModulePopupLayer and UI.ModulePopup.Parent ~= UI.ModulePopupLayer then
		UI.ModulePopup.Parent = UI.ModulePopupLayer
	end
	local layer = UI.ModulePopupLayer or UI.ModulePopup.Parent
	if not layer then
		return
	end
	local anchor = NTR_modulePopupAnchor(card)
	if not anchor then
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
	local anchorCenterX = anchor.AbsolutePosition.X + (anchor.AbsoluteSize.X * 0.5)
	local popupX = math.clamp(anchorCenterX - layer.AbsolutePosition.X - (popupWidth * 0.5), 6, math.max(6, layerWidth - popupWidth - 6))
	local popupY = anchor.AbsolutePosition.Y - layer.AbsolutePosition.Y - popupHeight - 6
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
		for _ = 1, 4 do
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
	source = replaceRange(source, helperStart, helperEnd, newHelper, "module popup card-anchor helper")
	changes += 1
elseif findPlain(source, oldScreenLayerStart) then
	source = replaceRange(source, oldScreenLayerStart, helperEnd, newHelper, "module popup screen-layer helper replacement")
	changes += 1
elseif findPlain(source, oldAboveFrameStart) then
	source = replaceRange(source, oldAboveFrameStart, helperEnd, newHelper, "module popup above-frame helper replacement")
	changes += 1
else
	source = insertBefore(source, helperEnd, newHelper, "module popup card-anchor helper insert")
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

local oldShowStage = [=[local function showStage(stage)
	State.Stage = stage]=]
local newShowStage = [=[local function showStage(stage)
	NTR_hideModulePopup()
	State.Stage = stage]=]
source, changed = replaceOptional(source, oldShowStage, newShowStage, "hide module popup on stage change")
if changed then
	changes += 1
end

local oldNextClick = [=[	UI.Next.MouseButton1Click:Connect(function()
		if State.Stage == "CockpitPaint" then]=]
local newNextClick = [=[	UI.Next.MouseButton1Click:Connect(function()
		NTR_hideModulePopup()
		if State.Stage == "CockpitPaint" then]=]
source, changed = replaceOptional(source, oldNextClick, newNextClick, "hide module popup on Next")
if changed then
	changes += 1
end

local oldBackClick = [=[	UI.Back.MouseButton1Click:Connect(function()
		if State.Stage == "CockpitPaint" then]=]
local newBackClick = [=[	UI.Back.MouseButton1Click:Connect(function()
		NTR_hideModulePopup()
		if State.Stage == "CockpitPaint" then]=]
source, changed = replaceOptional(source, oldBackClick, newBackClick, "hide module popup on Back")
if changed then
	changes += 1
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModulePopupCardAnchorRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_ANCHOR"), "Card-anchor helper marker was not installed.")
assert(findPlain(finalSource, "NTR_ModulePopupAnchor"), "Invisible module-card popup anchor was not installed.")
assert(findPlain(finalSource, "anchor.AbsolutePosition.Y - layer.AbsolutePosition.Y - popupHeight - 6"), "Card-anchor popup Y/gap was not installed.")
assert(findPlain(finalSource, "NTR_hideModulePopup()"), "Module popup hide helper calls were not installed.")
assert(findPlain(finalSource, "UI.Next.MouseButton1Click:Connect(function()\n\t\tNTR_hideModulePopup()"), "Next does not hide module popup.")
assert(findPlain(finalSource, "UI.Back.MouseButton1Click:Connect(function()\n\t\tNTR_hideModulePopup()"), "Back does not hide module popup.")

info("PASS: applied " .. tostring(changes) .. " module popup card-anchor source change(s).")
info("PASS: BUY/LOCKED/EQUIP popups now attach to an invisible top-centre anchor on the selected module card.")
info("PASS: popup spacing is 6px above the selected card, matching the tighter Paint Cockpit control spacing.")
info("PASS: Next, Back, and stage changes hide any visible module popup.")
info("Next: restart Play, open Build Modules > Buy Modules, click locked/buyable cards at left and far right, then click Back/Next to confirm the popup disappears.")
