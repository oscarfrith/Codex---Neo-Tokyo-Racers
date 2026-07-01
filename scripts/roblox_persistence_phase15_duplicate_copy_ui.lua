-- Neo Tokyo Racers - Persistence Phase 15
-- Visible duplicate-copy UI for the Phase 14 instance inventory bridge.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 14 is confirmed.
--
-- Scope:
-- - Patches only the active client bootstrap.
-- - Adds cockpit copy count plus a Buy Another button for owned cockpits.
-- - Adds module copy counts and Equip Copy / Buy Copy popup buttons.
-- - Keeps the existing legacy Select/Buy and installed-module UI shape.
-- - Does not change server, driving, VFX, DataStore, garage teleport, or assets.
--
-- This is guarded text replacement against the large client bootstrap. If it
-- cannot find the expected anchors, refresh the Studio mirror before another
-- Phase 15 patch.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 15"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function waitPath(root, ...)
	local item = root
	for _, name in ipairs({ ... }) do
		item = item:WaitForChild(name)
	end
	return item
end

local function replaceOnce(source, oldText, newText, label)
	local first = string.find(source, oldText, 1, true)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 15 UI patch.")
	end
	local second = string.find(source, oldText, first + #oldText, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting.")
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local clientRoot = waitPath(StarterPlayer, "StarterPlayerScripts", "NeoTokyoRacersClient")
local bootstrap = waitPath(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(string.find(source, "NTR_PERSISTENCE_PHASE13_GARAGE_PROPERTIES", 1, true), "Run Phase 13 before Phase 15.")

if string.find(source, "NTR_PERSISTENCE_PHASE15_DUPLICATE_COPY_UI", 1, true) then
	info("PASS: Phase 15 duplicate-copy UI is already installed.")
	return
end

local helperAnchor = [[local function callServer(action, args)
	local ok, result = pcall(function()
		return invoke:InvokeServer(action, args or {})
	end)
	if ok and typeof(result) == "table" then
		if result.Profile then State.Profile = result.Profile end
		return result
	end
	return { Success = false, Message = "Garage server did not respond." }
end
]]

local helperReplacement = helperAnchor .. [[

-- NTR_PERSISTENCE_PHASE15_DUPLICATE_COPY_UI
local NTRPersistencePhase15 = {}

function NTRPersistencePhase15.CountCockpitCopies(profile, cockpitId)
	local count = 0
	for _, instance in pairs((profile and profile.OwnedCockpitInstances) or {}) do
		if tostring(instance.TemplateId or "") == tostring(cockpitId or "") then
			count += 1
		end
	end
	if count == 0 and profile and profile.OwnedCockpits and profile.OwnedCockpits[cockpitId] == true then
		count = 1
	end
	return count
end

function NTRPersistencePhase15.CountModuleCopies(profile, moduleId)
	local count = 0
	for _, instance in pairs((profile and profile.OwnedModuleInstances) or {}) do
		if tostring(instance.TemplateId or "") == tostring(moduleId or "") then
			count += 1
		end
	end
	if count == 0 and profile and profile.OwnedModules and profile.OwnedModules[moduleId] == true then
		count = 1
	end
	return count
end

function NTRPersistencePhase15.FindFreeModuleCopy(profile, moduleId)
	for instanceId, instance in pairs((profile and profile.OwnedModuleInstances) or {}) do
		if tostring(instance.TemplateId or "") == tostring(moduleId or "") and (instance.EquippedVehicleId == nil or instance.EquippedVehicleId == "") then
			return instanceId
		end
	end
	return nil
end

function NTRPersistencePhase15.FindNewModuleCopyId(beforeProfile, afterProfile, moduleId)
	local before = (beforeProfile and beforeProfile.OwnedModuleInstances) or {}
	for instanceId, instance in pairs((afterProfile and afterProfile.OwnedModuleInstances) or {}) do
		if before[instanceId] == nil and tostring(instance.TemplateId or "") == tostring(moduleId or "") then
			return instanceId
		end
	end
	return nil
end
]]

local oldDealershipPanel = [[local function renderDealershipPanel()
	if not UI.StatsPanel then return end
	applyDealershipLayout()
	clear(UI.StatsPanel)
	local cockpit = getCockpit(State.SelectedCockpit) or {}
	NTRVehiclePhaseAO.renderStats(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))
	-- NTR_DEALERSHIP_MODULE_SLOTS_TEXT_REMOVED
	local owned = State.Profile and State.Profile.OwnedCockpits and State.Profile.OwnedCockpits[State.SelectedCockpit]
	local text = owned and "Select" or ("Buy $" .. tostring(cockpit.Price or 0))
	local selectButton = button(UI.StatsPanel, text, UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), owned and Theme.CardHot or Theme.Buy)
	selectButton.MouseButton1Click:Connect(function()
		local result = callServer("BuyCockpit", { CockpitId = State.SelectedCockpit })
		if result.Success then
			NTR_phase4UnlockPreviewAfterPurchase()
			-- NTR_VEHICLE_PHASE_AK_COCKPIT_PAINT_CAMERA_REPAIR
			setCameraSection("Engine1")
			showStage("CockpitPaint")
			renderCockpitPaint()
		else
			UI.Subtitle.Text = result.Message or "Could not buy cockpit."
		end
	end)
end
]]

local newDealershipPanel = [[local function renderDealershipPanel()
	if not UI.StatsPanel then return end
	applyDealershipLayout()
	clear(UI.StatsPanel)
	local cockpit = getCockpit(State.SelectedCockpit) or {}
	NTRVehiclePhaseAO.renderStats(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))
	-- NTR_DEALERSHIP_MODULE_SLOTS_TEXT_REMOVED
	local owned = State.Profile and State.Profile.OwnedCockpits and State.Profile.OwnedCockpits[State.SelectedCockpit]
	local copyCount = NTRPersistencePhase15.CountCockpitCopies(State.Profile, State.SelectedCockpit)
	if owned then
		local copyText = label(UI.StatsPanel, "Owned copies: " .. tostring(copyCount), UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -132 or -142), 10, Enum.TextXAlignment.Center)
		copyText.TextColor3 = Theme.Muted
	end
	local text = owned and "Select" or ("Buy $" .. tostring(cockpit.Price or 0))
	local selectHeight = owned and (UserInputService.TouchEnabled and 42 or 46) or (UserInputService.TouchEnabled and 58 or 76)
	local selectY = owned and (UserInputService.TouchEnabled and -104 or -112) or (UserInputService.TouchEnabled and -70 or -88)
	local selectButton = button(UI.StatsPanel, text, UDim2.new(1, 0, 0, selectHeight), UDim2.new(0, 0, 1, selectY), owned and Theme.CardHot or Theme.Buy)
	selectButton.MouseButton1Click:Connect(function()
		local result = callServer("BuyCockpit", { CockpitId = State.SelectedCockpit })
		if result.Success then
			NTR_phase4UnlockPreviewAfterPurchase()
			-- NTR_VEHICLE_PHASE_AK_COCKPIT_PAINT_CAMERA_REPAIR
			setCameraSection("Engine1")
			showStage("CockpitPaint")
			renderCockpitPaint()
		else
			UI.Subtitle.Text = result.Message or "Could not buy cockpit."
		end
	end)
	if owned then
		local buyAnother = button(UI.StatsPanel, "Buy Another $" .. tostring(cockpit.Price or 0), UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 42 or 46), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -54 or -56), Theme.Buy)
		buyAnother.MouseButton1Click:Connect(function()
			local result = callServer("BuyCockpitInstance", { CockpitId = State.SelectedCockpit })
			if result.Success then
				NTR_phase4UnlockPreviewAfterPurchase()
				UI.Subtitle.Text = "Bought another " .. tostring(cockpit.DisplayName or "cockpit") .. "."
				setCameraSection("Engine1")
				showStage("CockpitPaint")
				renderCockpitPaint()
			else
				UI.Subtitle.Text = result.Message or "Could not buy another cockpit."
				renderDealershipPanel()
			end
		end)
	end
end
]]

local oldModuleOptions = [[local function renderModuleOptions()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)
	optionPool:Begin()
	if UI.ModulePopup then
		clear(UI.ModulePopup)
		UI.ModulePopup.Visible = false
	end
	UI.ColorChannelFloat.Visible = false
	local list = modulesForSlot(State.SelectedSlot)
	local owned = (State.Profile and State.Profile.OwnedModules) or {}
	local installed = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[State.SelectedSlot]
	local x = 6
	for _, module in ipairs(list) do
		local isOwned = owned[module.ModuleId] == true
		local isInstalled = installed == module.ModuleId
		local card = pooledButton(optionPool, "", UDim2.fromOffset(160, 72), UDim2.fromOffset(x, 7), isInstalled and Theme.Disabled or (State.SelectedModuleId == module.ModuleId and Theme.CardHot or Theme.Card))
		card.AutoButtonColor = not isInstalled
		pooledLabel(card, module.DisplayName or module.ModuleId, UDim2.new(1, -10, 0, 30), UDim2.fromOffset(5, 12), 12, Enum.TextXAlignment.Center)
		pooledLabel(card, isOwned and (isInstalled and "equipped" or "owned") or ("$" .. tostring(module.Price or 0)), UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 41), 12, Enum.TextXAlignment.Center).TextColor3 = isOwned and Theme.Accent or Theme.Cash
		optionPool:Connect(card, card.MouseButton1Click, function()
			if isInstalled then return end
			State.SelectedModuleId = module.ModuleId
			State.PreviewModules = { [State.SelectedSlot] = module.ModuleId }
			buildPreview()
			renderModuleOptions()
		end)
		if State.SelectedModuleId == module.ModuleId and not isInstalled then
			UI.ModulePopup.Visible = true
			local popupX = math.clamp(x + 17 - UI.ModuleOptions.CanvasPosition.X, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))
			UI.ModulePopup.Position = UDim2.fromOffset(popupX, -28)
			local popup = button(UI.ModulePopup, isOwned and "Equip" or "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), isOwned and Theme.CardHot or Theme.Danger)
			popup.MouseButton1Click:Connect(function()
				local result = callServer("BuyModule", { SlotId = State.SelectedSlot, ModuleId = module.ModuleId })
				if result.Success then
					clearPreviewModules()
					State.ModuleMode = "Slots"
					buildPreview()
					renderStatsPanel()
					renderModuleShop()
				else
					UI.Subtitle.Text = result.Message or "Could not install module."
				end
			end)
		end
		x += 172
	end
	optionPool:End()
	local contentWidth = x + 6
	UI.ModuleOptions.CanvasSize = UDim2.fromOffset(math.max(contentWidth, UI.ModuleOptions.AbsoluteSize.X), 0)
	if contentWidth <= UI.ModuleOptions.AbsoluteSize.X + 2 then
		UI.ModuleOptions.CanvasPosition = Vector2.zero
	end
	renderStatsPanel()
end
]]

local newModuleOptions = [[local function renderModuleOptions()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)
	optionPool:Begin()
	if UI.ModulePopup then
		clear(UI.ModulePopup)
		UI.ModulePopup.Visible = false
		UI.ModulePopup.Size = UDim2.fromOffset(126, 30)
	end
	UI.ColorChannelFloat.Visible = false
	local list = modulesForSlot(State.SelectedSlot)
	local owned = (State.Profile and State.Profile.OwnedModules) or {}
	local installed = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[State.SelectedSlot]
	local x = 6
	for _, module in ipairs(list) do
		local isOwned = owned[module.ModuleId] == true
		local isInstalled = installed == module.ModuleId
		local copyCount = NTRPersistencePhase15.CountModuleCopies(State.Profile, module.ModuleId)
		local freeCopyId = NTRPersistencePhase15.FindFreeModuleCopy(State.Profile, module.ModuleId)
		local card = pooledButton(optionPool, "", UDim2.fromOffset(160, 72), UDim2.fromOffset(x, 7), isInstalled and Theme.Disabled or (State.SelectedModuleId == module.ModuleId and Theme.CardHot or Theme.Card))
		card.AutoButtonColor = not isInstalled
		pooledLabel(card, module.DisplayName or module.ModuleId, UDim2.new(1, -10, 0, 30), UDim2.fromOffset(5, 12), 12, Enum.TextXAlignment.Center)
		local statusText = isOwned and ((isInstalled and "equipped" or (freeCopyId and "free copy" or "owned")) .. " x" .. tostring(copyCount)) or ("$" .. tostring(module.Price or 0))
		pooledLabel(card, statusText, UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 41), 12, Enum.TextXAlignment.Center).TextColor3 = isOwned and Theme.Accent or Theme.Cash
		optionPool:Connect(card, card.MouseButton1Click, function()
			if isInstalled then return end
			State.SelectedModuleId = module.ModuleId
			State.PreviewModules = { [State.SelectedSlot] = module.ModuleId }
			buildPreview()
			renderModuleOptions()
		end)
		if State.SelectedModuleId == module.ModuleId and not isInstalled then
			UI.ModulePopup.Visible = true
			local popupHeight = isOwned and 66 or 30
			UI.ModulePopup.Size = UDim2.fromOffset(126, popupHeight)
			local popupX = math.clamp(x + 17 - UI.ModuleOptions.CanvasPosition.X, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))
			UI.ModulePopup.Position = UDim2.fromOffset(popupX, -popupHeight + 2)

			local function finishModuleInstall(result)
				if result.Success then
					clearPreviewModules()
					State.ModuleMode = "Slots"
					buildPreview()
					renderStatsPanel()
					renderModuleShop()
				else
					UI.Subtitle.Text = result.Message or "Could not install module."
				end
			end

			if isOwned then
				local equipCopy = button(UI.ModulePopup, freeCopyId and "Equip Copy" or "No Free Copy", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 0), freeCopyId and Theme.CardHot or Theme.Disabled)
				equipCopy.AutoButtonColor = freeCopyId ~= nil
				equipCopy.MouseButton1Click:Connect(function()
					if not freeCopyId then
						UI.Subtitle.Text = "Buy another copy before equipping this module here."
						return
					end
					finishModuleInstall(callServer("EquipModuleInstance", {
						ModuleInstanceId = freeCopyId,
						VehicleId = State.Profile and State.Profile.CurrentVehicleId,
						SlotId = State.SelectedSlot,
					}))
				end)

				local buyCopy = button(UI.ModulePopup, "Buy Copy $" .. tostring(module.Price or 0), UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 36), Theme.Buy)
				buyCopy.MouseButton1Click:Connect(function()
					local beforeProfile = State.Profile
					local buyResult = callServer("BuyModuleInstance", { ModuleId = module.ModuleId })
					if not buyResult.Success then
						UI.Subtitle.Text = buyResult.Message or "Could not buy module copy."
						return
					end
					local instanceId = NTRPersistencePhase15.FindNewModuleCopyId(beforeProfile, State.Profile, module.ModuleId)
					if not instanceId then
						UI.Subtitle.Text = "Bought module copy, but could not find the new copy to equip."
						renderModuleOptions()
						return
					end
					finishModuleInstall(callServer("EquipModuleInstance", {
						ModuleInstanceId = instanceId,
						VehicleId = State.Profile and State.Profile.CurrentVehicleId,
						SlotId = State.SelectedSlot,
					}))
				end)
			else
				local popup = button(UI.ModulePopup, "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Danger)
				popup.MouseButton1Click:Connect(function()
					local result = callServer("BuyModule", { SlotId = State.SelectedSlot, ModuleId = module.ModuleId })
					finishModuleInstall(result)
				end)
			end
		end
		x += 172
	end
	optionPool:End()
	local contentWidth = x + 6
	UI.ModuleOptions.CanvasSize = UDim2.fromOffset(math.max(contentWidth, UI.ModuleOptions.AbsoluteSize.X), 0)
	if contentWidth <= UI.ModuleOptions.AbsoluteSize.X + 2 then
		UI.ModuleOptions.CanvasPosition = Vector2.zero
	end
	renderStatsPanel()
end
]]

source = replaceOnce(source, helperAnchor, helperReplacement, "Phase 15 duplicate helper table")
source = replaceOnce(source, oldDealershipPanel, newDealershipPanel, "Phase 15 cockpit duplicate UI")
source = replaceOnce(source, oldModuleOptions, newModuleOptions, "Phase 15 module duplicate UI")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase15DuplicateCopyUI", true)

assert(string.find(bootstrap.Source, "NTR_PERSISTENCE_PHASE15_DUPLICATE_COPY_UI", 1, true), "Phase 15 helper marker missing after install.")
assert(string.find(bootstrap.Source, "BuyCockpitInstance", 1, true), "Phase 15 cockpit duplicate action missing after install.")
assert(string.find(bootstrap.Source, "BuyModuleInstance", 1, true), "Phase 15 module duplicate action missing after install.")
assert(string.find(bootstrap.Source, "EquipModuleInstance", 1, true), "Phase 15 equip duplicate action missing after install.")

info("PASS: installed visible duplicate-copy UI into active client bootstrap.")
info("Next: enter Play mode and run scripts/roblox_persistence_phase15_duplicate_copy_ui_client_smoke.lua from the CLIENT Command Bar.")
