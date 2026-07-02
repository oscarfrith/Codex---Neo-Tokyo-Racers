-- Persistence Phase 17 module popup position and cockpit-paint back lock.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- UI-only follow-up:
-- - positions BUY/LOCKED/EQUIP module popups from the rendered module card,
--   then repeats the position update on the next rendered frame after Roblox
--   layout has settled;
-- - places the popup above the bottom module-options frame with a small gap;
-- - hides the Back button only on the Paint Cockpit screen, so after buying a
--   cockpit the player must continue through customisation and spawn.
--
-- This is a guarded source patch against the active client bootstrap. If an
-- anchor fails, refresh the Studio mirror before another Phase 17 UI patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Position And Paint Back Lock"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceFirst(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 UI patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 UI patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another Phase 17 UI patch.")
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
assert(findPlain(source, "local function updateNav()"), "Expected updateNav in active client bootstrap.")
assert(findPlain(source, "local function renderModuleOptions()"), "Expected renderModuleOptions in active client bootstrap.")
assert(findPlain(source, "UI.Back = button(UI.NextPanel"), "Expected Back button in active client bootstrap.")

local changes = 0
local changed = false

if not findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ABOVE_FRAME") then
	local helper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ABOVE_FRAME
local function NTR_positionModulePopupAboveCard(card)
	if not (UI and UI.ModulePopup and UI.ModuleOptionsPanel and card) then
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
	local panelWidth = UI.ModuleOptionsPanel.AbsoluteSize.X
	if panelWidth <= 0 then
		panelWidth = popupWidth
	end
	local cardCenter = (card.AbsolutePosition.X - UI.ModuleOptionsPanel.AbsolutePosition.X) + (card.AbsoluteSize.X * 0.5)
	local popupX = math.clamp(cardCenter - (popupWidth * 0.5), 0, math.max(0, panelWidth - popupWidth))
	UI.ModulePopup.Position = UDim2.fromOffset(popupX, -(popupHeight + 8))
end

local function NTR_deferModulePopupPosition(card)
	NTR_positionModulePopupAboveCard(card)
	task.spawn(function()
		if RunService and RunService.RenderStepped then
			RunService.RenderStepped:Wait()
		else
			task.wait()
		end
		if UI and UI.ModulePopup and UI.ModulePopup.Visible then
			NTR_positionModulePopupAboveCard(card)
		end
	end)
end

]=]
	source, changed = replaceFirst(source, "local function renderModuleOptions()", helper .. "local function renderModuleOptions()", "module popup position helper")
	if changed then changes += 1 end
end

local oldPopupScrollMath = [=[				local popupX = math.clamp(x + 29 - UI.ModuleOptions.CanvasPosition.X, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))
				UI.ModulePopup.Position = UDim2.fromOffset(popupX, -28)]=]

local oldPopupAbsoluteMath = [=[				local popupX = math.clamp((card.AbsolutePosition.X - UI.ModuleOptionsPanel.AbsolutePosition.X) + (card.AbsoluteSize.X - 126) * 0.5, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))
				UI.ModulePopup.Position = UDim2.fromOffset(popupX, -28)]=]

local oldPopupAbsoluteMathNoIndent = [=[local popupX = math.clamp((card.AbsolutePosition.X - UI.ModuleOptionsPanel.AbsolutePosition.X) + (card.AbsoluteSize.X - 126) * 0.5, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))
				UI.ModulePopup.Position = UDim2.fromOffset(popupX, -28)]=]

local newPopupPosition = [=[				NTR_deferModulePopupPosition(card)]=]

local popupChanges = 0
while findPlain(source, oldPopupScrollMath) do
	source, changed = replaceFirst(source, oldPopupScrollMath, newPopupPosition, "module popup scroll-math position")
	if changed then
		changes += 1
		popupChanges += 1
	end
end
while findPlain(source, oldPopupAbsoluteMath) do
	source, changed = replaceFirst(source, oldPopupAbsoluteMath, newPopupPosition, "module popup absolute position")
	if changed then
		changes += 1
		popupChanges += 1
	end
end
while findPlain(source, oldPopupAbsoluteMathNoIndent) do
	source, changed = replaceFirst(source, oldPopupAbsoluteMathNoIndent, newPopupPosition, "module popup absolute position no-indent")
	if changed then
		changes += 1
		popupChanges += 1
	end
end

assert(popupChanges > 0 or findPlain(source, "NTR_deferModulePopupPosition(card)"), "Could not find any module popup position block to repair.")

local oldModuleOptionsCreation78 = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 78), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)
	makeArrowScroller(UI.ModuleOptionsPanel, UI.ModuleOptions, "X", 344)
	UI.ModulePopup = panel(UI.ModuleOptionsPanel, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, -28), Vector2.zero)
	UI.ModulePopup.Visible = false]=]

local oldModuleOptionsCreation92 = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)
	makeArrowScroller(UI.ModuleOptionsPanel, UI.ModuleOptions, "X", 344)
	UI.ModulePopup = panel(UI.ModuleOptionsPanel, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, -28), Vector2.zero)
	UI.ModulePopup.Visible = false]=]

local newModuleOptionsCreation92 = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)
	makeArrowScroller(UI.ModuleOptionsPanel, UI.ModuleOptions, "X", 344)
	UI.ModulePopup = panel(UI.ModuleOptionsPanel, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, -38), Vector2.zero)
	UI.ModulePopup.Visible = false
	UI.ModuleOptions:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if UI.ModulePopup then
			UI.ModulePopup.Visible = false
		end
	end)]=]

if not findPlain(source, 'GetPropertyChangedSignal("CanvasPosition")') then
	source, changed = replaceOptional(source, oldModuleOptionsCreation92, newModuleOptionsCreation92, "module popup hide on scroll with 92px scroll")
	if changed then changes += 1 end
	if not changed then
		source, changed = replaceOptional(source, oldModuleOptionsCreation78, newModuleOptionsCreation92, "module popup hide on scroll with 78px scroll")
		if changed then changes += 1 end
	end
end

local oldUpdateNav = [=[local function updateNav()
	local showNav = State.Stage ~= "CockpitShop"
	UI.NextPanel.Visible = showNav
	if UI.DealershipExitPanel then
		UI.DealershipExitPanel.Visible = State.Stage == "CockpitShop"
	end
	if State.Stage == "ModuleShop" then
		setNextText("Customise Modules")
	elseif State.Stage == "Customise" then
		setNextText("Start Driving")
	else
		setNextText("Next")
	end
end]=]

local newUpdateNav = [=[local function updateNav()
	local showNav = State.Stage ~= "CockpitShop"
	UI.NextPanel.Visible = showNav
	if UI.Back then
		UI.Back.Visible = showNav and State.Stage ~= "CockpitPaint"
	end
	if UI.DealershipExitPanel then
		UI.DealershipExitPanel.Visible = State.Stage == "CockpitShop"
	end
	if State.Stage == "ModuleShop" then
		setNextText("Customise Modules")
	elseif State.Stage == "Customise" then
		setNextText("Start Driving")
	else
		setNextText("Next")
	end
end]=]

source, changed = replaceOptional(source, oldUpdateNav, newUpdateNav, "paint cockpit Back-button lock")
if changed then changes += 1 end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17PopupAboveFramePaintBackLock", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ABOVE_FRAME"), "Popup helper marker was not installed.")
assert(findPlain(finalSource, "NTR_deferModulePopupPosition(card)"), "Popup call sites were not patched.")
assert(findPlain(finalSource, "popupHeight + 8"), "Popup above-frame gap was not installed.")
assert(findPlain(finalSource, 'GetPropertyChangedSignal("CanvasPosition")'), "Popup hide-on-scroll was not installed.")
assert(findPlain(finalSource, 'UI.Back.Visible = showNav and State.Stage ~= "CockpitPaint"'), "Paint Cockpit Back-button lock was not installed.")

if changes == 0 then
	info("PASS: popup positioning and Paint Cockpit Back-button lock were already present.")
else
	info("PASS: applied " .. tostring(changes) .. " client UI source change(s).")
end
info("PASS: module popup now re-centres from the rendered card after layout and sits above the bottom frame.")
info("PASS: module popup hides when the horizontal module carousel scrolls.")
info("PASS: Back button is hidden only on the Paint Cockpit screen; Next remains available.")
info("Next: restart Play, buy/select a cockpit, confirm Paint Cockpit has no Back button, then open Build Modules > Buy Modules and test BUY/LOCKED popup alignment at far scroll positions.")
