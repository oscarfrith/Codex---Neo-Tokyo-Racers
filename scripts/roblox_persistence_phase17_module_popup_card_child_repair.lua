-- Persistence Phase 17 module popup card-child repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- UI-only repair for BUY/LOCKED/EQUIP module popups:
-- - while visible, parents the popup directly to the selected module card;
-- - uses card-local centre positioning, so scrolling/padding cannot offset it;
-- - parks the popup back on a stable UI parent when hidden;
-- - hides the popup before module-card rerenders and on carousel/nav changes.
--
-- This is a guarded source-text patch against the active client bootstrap. If
-- it aborts on a missing anchor, refresh the Studio mirror before another patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Card Child Repair"

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
local renderIndex = findPlain(source, renderAnchor)

local newHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_CHILD
local function NTR_modulePopupParkingParent()
	if UI then
		return UI.ModulePopupLayer or UI.ModuleOptionsPanel or UI.Root
	end
	return nil
end

local function NTR_hideModulePopup()
	if not (UI and UI.ModulePopup) then
		return
	end
	UI.ModulePopup.Visible = false
	local parkingParent = NTR_modulePopupParkingParent()
	if parkingParent and UI.ModulePopup.Parent ~= parkingParent then
		UI.ModulePopup.Parent = parkingParent
	end
end

local function NTR_positionModulePopupAboveCard(card)
	if not (UI and UI.ModulePopup and card) then
		return
	end
	if UI.ModuleOptions then
		UI.ModuleOptions.ClipsDescendants = false
	end
	if UI.ModuleOptionsPanel then
		UI.ModuleOptionsPanel.ClipsDescendants = false
	end
	if card:IsA("GuiObject") then
		card.ClipsDescendants = false
	end
	UI.ModulePopup.Parent = card
	UI.ModulePopup.AnchorPoint = Vector2.new(0.5, 1)
	UI.ModulePopup.Size = UDim2.fromOffset(126, 30)
	UI.ModulePopup.Position = UDim2.new(0.5, 0, 0, -6)
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
			local ok = pcall(function()
				game:GetService("RunService").RenderStepped:Wait()
			end)
			if not ok then
				task.wait()
			end
			if not (UI and UI.ModulePopup and UI.ModulePopup.Visible and UI.ModulePopup.Parent == card) then
				return
			end
			NTR_positionModulePopupAboveCard(card)
		end
	end)
end

]=]

local helperMarkers = {
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_CHILD",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_ANCHOR",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_SCREEN_LAYER",
	"-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ABOVE_FRAME",
}

local replacedHelper = false
for _, marker in ipairs(helperMarkers) do
	local markerIndex = findPlain(source, marker)
	renderIndex = findPlain(source, renderAnchor)
	if markerIndex and renderIndex and markerIndex < renderIndex then
		source = replaceRange(source, markerIndex, renderIndex, newHelper)
		replacedHelper = true
		changes += 1
		break
	end
end
if not replacedHelper then
	source = insertBefore(source, renderAnchor, newHelper, "module popup card-child helper")
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

local moduleOptionsClipTrue = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)]=]
local moduleOptionsClipFalse = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = false }, UI.ModuleOptionsPanel)]=]
source, changed = replaceOptional(source, moduleOptionsClipTrue, moduleOptionsClipFalse, "module options clip disable")
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
bootstrap:SetAttribute("PersistencePhase17ModulePopupCardChildRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CARD_CHILD"), "Card-child helper marker was not installed.")
assert(findPlain(finalSource, "UI.ModulePopup.Parent = card"), "Popup is not parented to the selected module card.")
assert(findPlain(finalSource, "UI.ModulePopup.Position = UDim2.new(0.5, 0, 0, -6)"), "Popup is not anchored 6px above the selected card.")
assert(findPlain(finalSource, "local function renderModuleOptions()\n\tNTR_hideModulePopup()"), "renderModuleOptions does not hide/park the popup before rerendering cards.")
assert(findPlain(finalSource, "UI.Next.MouseButton1Click:Connect(function()\n\t\tNTR_hideModulePopup()"), "Next does not hide module popup.")
assert(findPlain(finalSource, "UI.Back.MouseButton1Click:Connect(function()\n\t\tNTR_hideModulePopup()"), "Back does not hide module popup.")

info("PASS: applied " .. tostring(changes) .. " module popup card-child source change(s).")
info("PASS: BUY/LOCKED/EQUIP popups now become children of the selected module card while visible.")
info("PASS: popup centre is card-local at X=50%, with a 6px gap above the card.")
info("PASS: popups are hidden/parked before module rerenders, on carousel scroll, and on Next/Back.")
info("Next: restart Play, open Build Modules > Buy Modules, click cards at the far left/middle/right, then scroll and use Next/Back to confirm the popup disappears.")
