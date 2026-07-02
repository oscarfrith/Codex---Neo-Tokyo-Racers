-- Persistence Phase 17 module button layout polish.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- UI-only follow-up for the module picker:
-- - gives module option cards more vertical room so the bottom label is not clipped;
-- - makes the OWNED MODULES / BUY MODULES tab buttons match the customise
--   section button height and use one vertically-centered label;
-- - shows "Locked" on locked buy-module cards instead of "Owned x0";
-- - keeps buyable cards on the lighter card colour and locked cards on the
--   darker disabled colour.
--
-- This is a guarded source patch against the active client bootstrap. If it
-- cannot find the expected anchors, refresh the Studio mirror before another
-- module UI patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Button Layout Polish"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another module button polish patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another module button polish patch.")
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
assert(findPlain(source, "UI.ModuleOptions = new(\"ScrollingFrame\""), "Expected ModuleOptions ScrollingFrame in active client bootstrap.")

local changes = 0
local changed = false

local beforeScroll = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 78), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)]=]
local afterScroll = [=[UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)]=]
source, changed = replaceOptional(source, beforeScroll, afterScroll, "module options scroll height")
if changed then changes += 1 end

local beforeTabs = [=[
	if State.ModuleOptionMode ~= "Owned" and State.ModuleOptionMode ~= "Buy" then
		local ownedButton = pooledButton(optionPool, "", UDim2.fromOffset(260, 72), UDim2.fromOffset(6, 7), Theme.Card)
		pooledLabel(ownedButton, "OWNED MODULES", UDim2.new(1, -12, 0, 34), UDim2.fromOffset(6, 9), 13, Enum.TextXAlignment.Center)
		pooledLabel(ownedButton, "owned x" .. tostring(#ownedInstances), UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 43), 11, Enum.TextXAlignment.Center).TextColor3 = Theme.Accent
		optionPool:Connect(ownedButton, ownedButton.MouseButton1Click, function()
			State.ModuleOptionMode = "Owned"
			State.SelectedModuleId = nil
			State.SelectedModuleInstanceId = nil
			clearPreviewModules()
			renderModuleOptions()
		end)

		local buyButton = pooledButton(optionPool, "", UDim2.fromOffset(260, 72), UDim2.fromOffset(278, 7), Theme.Buy)
		pooledLabel(buyButton, "BUY MODULES", UDim2.new(1, -12, 0, 34), UDim2.fromOffset(6, 9), 13, Enum.TextXAlignment.Center)
		pooledLabel(buyButton, "owned x" .. tostring(#ownedInstances), UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 43), 11, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
		optionPool:Connect(buyButton, buyButton.MouseButton1Click, function()
			State.ModuleOptionMode = "Buy"
			State.SelectedModuleId = nil
			State.SelectedModuleInstanceId = nil
			clearPreviewModules()
			renderModuleOptions()
		end)

		optionPool:End()
		UI.ModuleOptions.CanvasSize = UDim2.fromOffset(math.max(550, UI.ModuleOptions.AbsoluteSize.X), 0)
		UI.ModuleOptions.CanvasPosition = Vector2.zero
		renderStatsPanel()
		return
	end
]=]

local afterTabs = [=[
	if State.ModuleOptionMode ~= "Owned" and State.ModuleOptionMode ~= "Buy" then
		local ownedButton = pooledButton(optionPool, "", UDim2.fromOffset(170, 72), UDim2.fromOffset(6, 8), Theme.Card)
		pooledLabel(ownedButton, "OWNED MODULES", UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), 13, Enum.TextXAlignment.Center)
		optionPool:Connect(ownedButton, ownedButton.MouseButton1Click, function()
			State.ModuleOptionMode = "Owned"
			State.SelectedModuleId = nil
			State.SelectedModuleInstanceId = nil
			clearPreviewModules()
			renderModuleOptions()
		end)

		local buyButton = pooledButton(optionPool, "", UDim2.fromOffset(170, 72), UDim2.fromOffset(188, 8), Theme.Card)
		pooledLabel(buyButton, "BUY MODULES", UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), 13, Enum.TextXAlignment.Center)
		optionPool:Connect(buyButton, buyButton.MouseButton1Click, function()
			State.ModuleOptionMode = "Buy"
			State.SelectedModuleId = nil
			State.SelectedModuleInstanceId = nil
			clearPreviewModules()
			renderModuleOptions()
		end)

		optionPool:End()
		UI.ModuleOptions.CanvasSize = UDim2.fromOffset(math.max(370, UI.ModuleOptions.AbsoluteSize.X), 0)
		UI.ModuleOptions.CanvasPosition = Vector2.zero
		renderStatsPanel()
		return
	end
]=]
source, changed = replaceOptional(source, beforeTabs, afterTabs, "owned/buy tab buttons")
if changed then changes += 1 end

local beforeOwnedCardOld = [=[
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 76), UDim2.fromOffset(x, 5), cardColor)
			card.AutoButtonColor = not isInstalledHere
			pooledLabel(card, tostring(moduleInfo and (moduleInfo.DisplayName or moduleInfo.ModuleId) or instanceInfo.TemplateId), UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "#" .. tostring(index) .. " / " .. tostring(moduleInfo and (moduleInfo.VariantName or "") or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 32), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			local status = "owned"
			if isInstalledHere then
				status = "equipped here"
			elseif equippedElsewhere then
				status = "in another car"
			end
			pooledLabel(card, status, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isInstalledHere and Theme.Accent or Theme.Cash
]=]
local afterOwnedCard = [=[
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 86), UDim2.fromOffset(x, 3), cardColor)
			card.AutoButtonColor = not isInstalledHere
			local familyText = tostring(moduleInfo and (moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId) or "")
			local variantText = tostring(moduleInfo and (moduleInfo.VariantName or "") or "")
			local ownedCount = moduleInfo and NTRPersistencePhase15.CountModuleCopies(State.Profile, moduleInfo.ModuleId) or 1
			local bottomText = "Owned x" .. tostring(ownedCount)
			if isInstalledHere then
				bottomText = bottomText .. " / equipped"
			elseif equippedElsewhere then
				bottomText = bottomText .. " / in use"
			end
			pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 9), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "$" .. tostring(moduleInfo and (moduleInfo.Price or 0) or 0), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 35), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
			pooledLabel(card, bottomText, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 61), 10, Enum.TextXAlignment.Center).TextColor3 = isInstalledHere and Theme.Accent or Theme.Muted
]=]
source, changed = replaceOptional(source, beforeOwnedCardOld, afterOwnedCard, "old owned module card layout")
if changed then changes += 1 end

local beforeOwnedCardNew = [=[
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 76), UDim2.fromOffset(x, 5), cardColor)
			card.AutoButtonColor = not isInstalledHere
			local familyText = tostring(moduleInfo and (moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId) or "")
			local variantText = tostring(moduleInfo and (moduleInfo.VariantName or "") or "")
			local ownedCount = moduleInfo and NTRPersistencePhase15.CountModuleCopies(State.Profile, moduleInfo.ModuleId) or 1
			local bottomText = "Owned x" .. tostring(ownedCount)
			if isInstalledHere then
				bottomText = bottomText .. " / equipped"
			elseif equippedElsewhere then
				bottomText = bottomText .. " / in use"
			end
			pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "$" .. tostring(moduleInfo and (moduleInfo.Price or 0) or 0), UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 31), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
			pooledLabel(card, bottomText, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isInstalledHere and Theme.Accent or Theme.Muted
]=]
source, changed = replaceOptional(source, beforeOwnedCardNew, afterOwnedCard, "new owned module card layout")
if changed then changes += 1 end

local beforeBuyCardOld = [=[
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 76), UDim2.fromOffset(x, 5), cardColor)
			card.AutoButtonColor = not isInstalled
			pooledLabel(card, moduleInfo.DisplayName or moduleInfo.ModuleId, UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			local familyText = tostring(moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId or "")
			pooledLabel(card, familyText .. " / " .. tostring(moduleInfo.VariantName or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 32), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			local statusText = "$" .. tostring(moduleInfo.Price or 0)
			if isLocked then
				statusText = lockText
			end
			pooledLabel(card, statusText, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isLocked and Theme.Danger or Theme.Cash
]=]
local afterBuyCard = [=[
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 86), UDim2.fromOffset(x, 3), cardColor)
			card.AutoButtonColor = not isInstalled
			local familyText = tostring(moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId or "")
			local variantText = tostring(moduleInfo.VariantName or "")
			local ownedCount = NTRPersistencePhase15.CountModuleCopies(State.Profile, moduleInfo.ModuleId)
			local bottomText = isLocked and "Locked" or ("Owned x" .. tostring(ownedCount))
			pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 9), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "$" .. tostring(moduleInfo.Price or 0), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 35), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
			pooledLabel(card, bottomText, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 61), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
]=]
source, changed = replaceOptional(source, beforeBuyCardOld, afterBuyCard, "old buy module card layout")
if changed then changes += 1 end

local beforeBuyCardNew = [=[
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 76), UDim2.fromOffset(x, 5), cardColor)
			card.AutoButtonColor = not isInstalled
			local familyText = tostring(moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId or "")
			local variantText = tostring(moduleInfo.VariantName or "")
			local ownedCount = NTRPersistencePhase15.CountModuleCopies(State.Profile, moduleInfo.ModuleId)
			pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "$" .. tostring(moduleInfo.Price or 0), UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 31), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
			pooledLabel(card, "Owned x" .. tostring(ownedCount), UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isLocked and Theme.Danger or Theme.Muted
]=]
source, changed = replaceOptional(source, beforeBuyCardNew, afterBuyCard, "new buy module card layout")
if changed then changes += 1 end

local beforeBuyCardLockedExisting = [=[
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 86), UDim2.fromOffset(x, 3), cardColor)
			card.AutoButtonColor = not isInstalled
			local familyText = tostring(moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId or "")
			local variantText = tostring(moduleInfo.VariantName or "")
			local ownedCount = NTRPersistencePhase15.CountModuleCopies(State.Profile, moduleInfo.ModuleId)
			pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 9), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "$" .. tostring(moduleInfo.Price or 0), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 35), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
			pooledLabel(card, "Owned x" .. tostring(ownedCount), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 61), 10, Enum.TextXAlignment.Center).TextColor3 = isLocked and Theme.Danger or Theme.Muted
]=]
source, changed = replaceOptional(source, beforeBuyCardLockedExisting, afterBuyCard, "already-tall buy card locked text")
if changed then changes += 1 end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModuleButtonLayoutPolish", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, 'Size = UDim2.new(1, 0, 0, 92)'), "ModuleOptions scroll height was not updated to 92.")
assert(findPlain(finalSource, 'pooledLabel(ownedButton, "OWNED MODULES", UDim2.new(1, -12, 1, 0)'), "Owned modules tab was not simplified.")
assert(findPlain(finalSource, 'local bottomText = isLocked and "Locked" or ("Owned x" .. tostring(ownedCount))'), "Locked buy-card bottom text was not installed.")
assert(findPlain(finalSource, 'UDim2.fromOffset(184, 86)'), "Module option cards were not made taller.")

if changes == 0 then
	info("PASS: requested module button polish was already present.")
else
	info("PASS: applied " .. tostring(changes) .. " module button polish source change(s).")
end
info("PASS: module option scroll area is taller to prevent top/bottom clipping.")
info("PASS: OWNED MODULES / BUY MODULES tabs are compact single-label buttons matching customise button height.")
info("PASS: locked buy-module cards now show Locked in muted text and keep locked cards on the darker disabled colour.")
info("Next: restart Play, open Build Modules, check the first tab screen and the Buy Modules list on desktop/mobile widths.")
