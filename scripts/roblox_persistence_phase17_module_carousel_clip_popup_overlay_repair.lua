-- Persistence Phase 17 module carousel clip + popup overlay repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- UI-only repair after the card-child popup fix:
-- - restores clipping on the module ScrollingFrame so module cards cannot spill
--   over the cash/customise/back side panels;
-- - keeps BUY/LOCKED/EQUIP popups accurately centred by moving only the popup
--   onto a full-screen overlay and positioning it from the selected card's
--   rendered screen centre;
-- - keeps popup cleanup on scroll, rerender, Next, and Back.
--
-- This is a guarded source-text patch against the active client bootstrap. If
-- it aborts on a missing anchor, refresh the Studio mirror before another patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Carousel Clip Popup Overlay Repair"

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
-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CLIPPED_CAROUSEL_OVERLAY
local function NTR_findAncestorScreenGui(instance)
	local current = instance
	while current do
		if current:IsA("ScreenGui") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function NTR_ensureModulePopupLayer()
	if not UI then
		return nil
	end
	if UI.ModulePopupLayer and UI.ModulePopupLayer.Parent then
		return UI.ModulePopupLayer
	end
	local screenGui = nil
	if UI.ModuleShop then
		screenGui = NTR_findAncestorScreenGui(UI.ModuleShop)
	end
	if not screenGui and UI.ModuleOptionsPanel then
		screenGui = NTR_findAncestorScreenGui(UI.ModuleOptionsPanel)
	end
	local parent = screenGui or UI.ModuleOptionsPanel
	if not parent then
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
	layer.Parent = parent
	UI.ModulePopupLayer = layer
	return layer
end

local function NTR_hideModulePopup()
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
	if UI.ModuleOptions then
		UI.ModuleOptions.ClipsDescendants = true
	end
	local layer = NTR_ensureModulePopupLayer()
	if not layer then
		return
	end
	UI.ModulePopup.Parent = layer
	UI.ModulePopup.AnchorPoint = Vector2.new(0.5, 1)
	UI.ModulePopup.Size = UDim2.fromOffset(126, 30)
	local popupX = (card.AbsolutePosition.X + (card.AbsoluteSize.X * 0.5)) - layer.AbsolutePosition.X
	local popupY = card.AbsolutePosition.Y - layer.AbsolutePosition.Y - 6
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
			local ok = pcall(function()
				game:GetService("RunService").RenderStepped:Wait()
			end)
			if not ok then
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

local helperMarkers = {
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
	source = insertBefore(source, renderAnchor, newHelper, "module clipped-carousel popup helper")
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
bootstrap:SetAttribute("PersistencePhase17ModuleCarouselClipPopupOverlayRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_CLIPPED_CAROUSEL_OVERLAY"), "Clipped-carousel popup helper marker was not installed.")
assert(findPlain(finalSource, "UI.ModuleOptions.ClipsDescendants = true"), "Runtime module carousel clipping was not restored.")
assert(findPlain(finalSource, "UI.ModulePopup.Parent = layer"), "Popup is not moved to the overlay layer.")
assert(findPlain(finalSource, "card.AbsolutePosition.X + (card.AbsoluteSize.X * 0.5)"), "Popup is not centred from the selected card's screen centre.")
assert(findPlain(finalSource, "local function renderModuleOptions()\n\tNTR_hideModulePopup()"), "renderModuleOptions does not hide/park the popup before rerendering cards.")
assert(findPlain(finalSource, "UI.Next.MouseButton1Click:Connect(function()\n\t\tNTR_hideModulePopup()"), "Next does not hide module popup.")
assert(findPlain(finalSource, "UI.Back.MouseButton1Click:Connect(function()\n\t\tNTR_hideModulePopup()"), "Back does not hide module popup.")

info("PASS: applied " .. tostring(changes) .. " clipped-carousel popup source change(s).")
info("PASS: module carousel clipping is restored so cards stay inside the bottom UI frame.")
info("PASS: BUY/LOCKED/EQUIP popups use an overlay but are still centred from the selected card's rendered centre.")
info("Next: restart Play, open Build Modules > Buy Modules, scroll left/right, and click cards near both edges to confirm cards clip while the popup remains centred above the selected card.")
