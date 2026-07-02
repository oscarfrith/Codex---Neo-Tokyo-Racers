-- Persistence Phase 17 module card colour, popup alignment, and sprint guard.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- UI/input-only follow-up:
-- - inverts buy-module card colours so locked cards are darker and buyable
--   cards are lighter;
-- - gives locked cards muted top text and a darker muted green price;
-- - centers BUY/LOCKED popups using the rendered card AbsolutePosition instead
--   of scroll-content math;
-- - hides the module popup whenever the horizontal module carousel scrolls;
-- - blocks sprint/FOV changes while the garage UI is open.
--
-- This uses guarded source replacement against the active client bootstrap and
-- sprint controller. If an anchor fails, refresh the Studio mirror before
-- another UI patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Card Colour Popup Sprint Guard"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 UI patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another Phase 17 UI patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local function replaceFirst(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 UI patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local function replaceOptional(source, before, after, label)
	if findPlain(source, before) then
		return replaceOnce(source, before, after, label)
	end
	return source, false
end

local clientRoot = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")

local bootstrap = clientRoot:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "local function renderModuleOptions()"), "Expected renderModuleOptions in active client bootstrap.")

local changes = 0
local changed = false

local oldBuyCardColor = [=[
			local cardColor = Theme.Card
			if isLocked or isInstalled then
				cardColor = Theme.Disabled
			elseif selected then
				cardColor = Theme.CardHot
			end
]=]

local newBuyCardColor = [=[
			local cardColor = Theme.Disabled
			if isLocked then
				cardColor = Theme.Card
			elseif selected then
				cardColor = Theme.CardHot
			end
]=]

source, changed = replaceOptional(source, oldBuyCardColor, newBuyCardColor, "buy-module card colour inversion")
if changed then changes += 1 end

local oldBuyLabels = [=[
			pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 9), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "$" .. tostring(moduleInfo.Price or 0), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 35), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
			pooledLabel(card, bottomText, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 61), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
]=]

local newBuyLabels = [=[
			local titleLabel = pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 9), 10, Enum.TextXAlignment.Center)
			if isLocked then
				titleLabel.TextColor3 = Theme.Muted
			end
			local priceLabel = pooledLabel(card, "$" .. tostring(moduleInfo.Price or 0), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 35), 10, Enum.TextXAlignment.Center)
			priceLabel.TextColor3 = isLocked and Theme.Cash:Lerp(Theme.Muted, 0.55) or Theme.Cash
			pooledLabel(card, bottomText, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 61), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
]=]

source, changed = replaceOptional(source, oldBuyLabels, newBuyLabels, "locked buy-module text colours")
if changed then changes += 1 end

local oldPopupX = [=[local popupX = math.clamp(x + 29 - UI.ModuleOptions.CanvasPosition.X, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))]=]
local newPopupX = [=[local popupX = math.clamp((card.AbsolutePosition.X - UI.ModuleOptionsPanel.AbsolutePosition.X) + (card.AbsoluteSize.X - 126) * 0.5, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))]=]

while findPlain(source, oldPopupX) do
	source, changed = replaceFirst(source, oldPopupX, newPopupX, "module popup absolute-position alignment")
	if changed then changes += 1 end
end

local oldModuleOptionsCreation = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)
	makeArrowScroller(UI.ModuleOptionsPanel, UI.ModuleOptions, "X", 344)
	UI.ModulePopup = panel(UI.ModuleOptionsPanel, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, -28), Vector2.zero)
	UI.ModulePopup.Visible = false]=]

local newModuleOptionsCreation = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)
	makeArrowScroller(UI.ModuleOptionsPanel, UI.ModuleOptions, "X", 344)
	UI.ModulePopup = panel(UI.ModuleOptionsPanel, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, -28), Vector2.zero)
	UI.ModulePopup.Visible = false
	UI.ModuleOptions:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if UI.ModulePopup then
			UI.ModulePopup.Visible = false
		end
	end)]=]

source, changed = replaceOptional(source, oldModuleOptionsCreation, newModuleOptionsCreation, "hide module popup on carousel scroll")
if changed then changes += 1 end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModuleCardColourPopupRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "local cardColor = Theme.Disabled"), "Buy-module colour inversion was not installed.")
assert(findPlain(finalSource, "titleLabel.TextColor3 = Theme.Muted"), "Locked title muted colour was not installed.")
assert(findPlain(finalSource, "Theme.Cash:Lerp(Theme.Muted, 0.55)"), "Muted locked price colour was not installed.")
assert(findPlain(finalSource, "card.AbsolutePosition.X - UI.ModuleOptionsPanel.AbsolutePosition.X"), "Absolute-position popup centering was not installed.")
assert(findPlain(finalSource, 'GetPropertyChangedSignal("CanvasPosition")'), "Popup hide-on-scroll was not installed.")

local runtimeFolder = clientRoot:FindFirstChild("Controllers")
	and clientRoot.Controllers:FindFirstChild("Runtime")
local sprint = runtimeFolder and runtimeFolder:FindFirstChild("CharacterSprintController_Active")
assert(sprint and sprint:IsA("LocalScript"), "Expected CharacterSprintController_Active LocalScript under NeoTokyoRacersClient.Controllers.Runtime.")

local sprintSource = sprint.Source
assert(findPlain(sprintSource, "local function shouldSprint()"), "Expected shouldSprint in CharacterSprintController_Active.")

local sprintChanges = 0

if not findPlain(sprintSource, "NTR_PERSISTENCE_PHASE17_GARAGE_MENU_SPRINT_GUARD") then
	local beforeShouldSprint = [=[
local function shouldSprint()
	return shiftHeld or mobileAutoSprint
end
]=]
	local afterShouldSprint = [=[
-- NTR_PERSISTENCE_PHASE17_GARAGE_MENU_SPRINT_GUARD
local function garageMenuOpen()
	local playerGui = PLAYER:FindFirstChild("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return gui and gui:IsA("ScreenGui") and gui.Enabled == true
end

local function shouldSprint()
	return not garageMenuOpen() and (shiftHeld or mobileAutoSprint)
end
]=]
	sprintSource, changed = replaceOnce(sprintSource, beforeShouldSprint, afterShouldSprint, "garage menu sprint guard helper")
	if changed then sprintChanges += 1 end
end

local oldUpdateSprintState = [=[
updateSprintState = function()
	if shouldSprint() then
		startSprint()
	else
		stopSprint({ restoreFov = true })
	end
end
]=]
local newUpdateSprintState = [=[
updateSprintState = function()
	if garageMenuOpen() then
		shiftHeld = false
		mobileAutoSprint = false
		stopSprint({ restoreFov = true })
		return
	end
	if shouldSprint() then
		startSprint()
	else
		stopSprint({ restoreFov = true })
	end
end
]=]
sprintSource, changed = replaceOptional(sprintSource, oldUpdateSprintState, newUpdateSprintState, "garage menu sprint state block")
if changed then sprintChanges += 1 end

local oldUpdateMobile = [=[
	if not mobileAutoSprintEnabled() or not humanoid or humanoid.Health <= 0 or isVehicleSeated() then
]=]
local newUpdateMobile = [=[
	if garageMenuOpen() or not mobileAutoSprintEnabled() or not humanoid or humanoid.Health <= 0 or isVehicleSeated() then
]=]
sprintSource, changed = replaceOptional(sprintSource, oldUpdateMobile, newUpdateMobile, "garage menu mobile sprint guard")
if changed then sprintChanges += 1 end

local oldInputBegan = [=[
	if input.KeyCode == sprintKeyCode() then
		shiftHeld = true
		updateSprintState()
	end
]=]
local newInputBegan = [=[
	if input.KeyCode == sprintKeyCode() then
		if garageMenuOpen() then
			shiftHeld = false
			stopSprint({ restoreFov = true })
			return
		end
		shiftHeld = true
		updateSprintState()
	end
]=]
sprintSource, changed = replaceOptional(sprintSource, oldInputBegan, newInputBegan, "garage menu keyboard sprint guard")
if changed then sprintChanges += 1 end

sprint.Source = sprintSource
sprint:SetAttribute("PersistencePhase17GarageMenuSprintGuard", true)

local finalSprintSource = sprint.Source
assert(findPlain(finalSprintSource, "garageMenuOpen()"), "Garage menu sprint guard was not installed.")
assert(findPlain(finalSprintSource, 'FindFirstChild("HOVER_RACING_V2_GarageUI")'), "Sprint guard does not check the garage UI.")

info("PASS: module buy-card colours now use lighter buyable cards and darker locked cards.")
info("PASS: locked card title/price text is muted, with price using a darker green.")
info("PASS: BUY/LOCKED popup uses card AbsolutePosition and hides when the carousel scrolls.")
info("PASS: sprint FOV changes are blocked while the garage UI is open.")
info("Client bootstrap changes applied: " .. tostring(changes) .. "; sprint-controller changes applied: " .. tostring(sprintChanges) .. ".")
info("Next: restart Play, open Build Modules > Buy Modules, test locked/unlocked colours, popup centering at far scroll positions, and Shift in menus.")
