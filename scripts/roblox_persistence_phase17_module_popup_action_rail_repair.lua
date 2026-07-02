-- Persistence Phase 17 module action rail repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Root fix for the popup/card clipping yo-yo:
-- - module cards stay clipped inside the carousel;
-- - BUY/LOCKED/EQUIP is no longer attached to recycled scrolling cards;
-- - the action button lives on a stable overlay and is positioned as a fixed
--   action rail centred above the module-options frame;
-- - the selected module card still controls which action appears.
--
-- This deliberately trades "floating above exact selected card" for a stable,
-- mobile-safe action position that cannot drift with CanvasPosition, padding,
-- UIListLayout timing, or pooled/destroyed card instances.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Action Rail Repair"

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
-- NTR_PERSISTENCE_PHASE17_MODULE_ACTION_RAIL
NTRPersistencePhase15.ModulePopupActiveCard = nil

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

function NTRPersistencePhase15.HideModulePopup()
	NTRPersistencePhase15.ModulePopupActiveCard = nil
	if NTRPersistencePhase15.ModulePopupTrackerConnection then
		NTRPersistencePhase15.ModulePopupTrackerConnection:Disconnect()
		NTRPersistencePhase15.ModulePopupTrackerConnection = nil
	end
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

function NTRPersistencePhase15.PositionModulePopupAboveCard(_card)
	local popup = NTRPersistencePhase15.EnsureModulePopupObject()
	if not popup then
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
	popup.AnchorPoint = Vector2.new(0.5, 1)
	popup.Size = UDim2.fromOffset(126, 30)
	local anchorPanel = UI.ModuleOptionsPanel or UI.ModuleSlotPanel or UI.ModuleShop
	local popupX = (anchorPanel.AbsolutePosition.X + (anchorPanel.AbsoluteSize.X * 0.5)) - layer.AbsolutePosition.X
	local popupY = anchorPanel.AbsolutePosition.Y - layer.AbsolutePosition.Y - 6
	popup.Position = UDim2.fromOffset(math.floor(popupX + 0.5), math.floor(popupY + 0.5))
	popup.ZIndex = 72
	for _, child in ipairs(popup:GetDescendants()) do
		if child:IsA("GuiObject") then
			child.ZIndex = 73
		end
	end
end

function NTRPersistencePhase15.DeferModulePopupPosition(card)
	NTRPersistencePhase15.PositionModulePopupAboveCard(card)
	task.defer(function()
		if UI and UI.ModulePopup and UI.ModulePopup.Visible then
			NTRPersistencePhase15.PositionModulePopupAboveCard(card)
		end
	end)
end

]=]

local helperMarkers = {
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
bootstrap:SetAttribute("PersistencePhase17ModuleActionRailRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_MODULE_ACTION_RAIL"), "Module action rail marker was not installed.")
assert(findPlain(finalSource, "anchorPanel.AbsolutePosition.X + (anchorPanel.AbsoluteSize.X * 0.5)"), "Action rail centring was not installed.")
assert(findPlain(finalSource, "UI.ModuleOptions.ClipsDescendants = true"), "Module carousel clipping was not restored.")
assert(findPlain(finalSource, "function NTRPersistencePhase15.EnsureModulePopupObject()"), "ModulePopup validation/rebuild helper was not installed.")
assert(findPlain(finalSource, "NTRPersistencePhase15.HideModulePopup()"), "Hide call sites do not use the table-backed helper.")
assert(findPlain(finalSource, "NTRPersistencePhase15.DeferModulePopupPosition(card)"), "Popup action call sites do not use the table-backed helper.")
assert(not findPlain(finalSource, "RenderStepped:Connect(function()\n\t\t\tlocal popup = NTRPersistencePhase15.EnsureModulePopupObject()"), "Old per-frame popup tracker remains.")

info("PASS: applied " .. tostring(changes) .. " module action rail change(s).")
info("PASS: module cards stay clipped and BUY/LOCKED/EQUIP now uses a stable centred action rail above the module frame.")
info("PASS: stale/destroyed ModulePopup references are still rebuilt safely.")
info("Next: restart Play, go Paint Cockpit -> Build Modules, click module cards, and confirm no popup drift or carousel spill.")
