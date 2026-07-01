-- Persistence Phase 17: owned/buy module tabs and per-instance owned module cards.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 16 is confirmed.
--
-- Scope:
-- - Keeps the Phase 16 source-cockpit purchase locks.
-- - Restores strict front/rear engine slot filtering in the client and server.
-- - Adds an intermediate bottom menu with OWNED MODULES and BUY MODULES.
-- - Shows owned module copies as separate buttons by module instance.
-- - Removes Buy Copy / Equip Copy / No Free Copy from the module picker.
-- - Buying from BUY MODULES buys a new module instance and auto-equips it.
-- - Equipping from OWNED MODULES uses a BUY-coloured EQUIP button.
-- - Selecting any visible module, including locked buy modules, previews it.
--
-- This is a guarded text patch against the Phase 16 live scripts. If an anchor
-- is missing, refresh the Studio mirror before writing another repair.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17"

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
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 patch.")
	end
	local second = string.find(source, oldText, first + #oldText, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting: " .. label)
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local function insertAfterOnce(source, anchor, insertText, label)
	local first = string.find(source, anchor, 1, true)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 patch.")
	end
	local second = string.find(source, anchor, first + #anchor, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting: " .. label)
	end
	return string.sub(source, 1, first + #anchor) .. insertText .. string.sub(source, first + #anchor + 1)
end

local function replaceFunctionBlock(source, functionStart, nextStart, replacement, label)
	local first = string.find(source, functionStart, 1, true)
	if not first then
		error("Could not find function start for " .. label .. ". Refresh the Studio mirror before another Phase 17 patch.")
	end
	local nextIndex = string.find(source, nextStart, first + #functionStart, true)
	if not nextIndex then
		error("Could not find function end anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 patch.")
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, nextIndex)
end

local function replaceFunctionBlockByTail(source, functionStart, tailText, replacement, label)
	local first = string.find(source, functionStart, 1, true)
	if not first then
		error("Could not find function start for " .. label .. ". Refresh the Studio mirror before another Phase 17 patch.")
	end
	local tailStart = string.find(source, tailText, first + #functionStart, true)
	if not tailStart then
		error("Could not find function tail for " .. label .. ". Refresh the Studio mirror before another Phase 17 patch.")
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, tailStart + #tailText)
end

local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")
assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local serverSource = garage.Source
assert(string.find(serverSource, "NTR_PERSISTENCE_PHASE16_MODULE_FAMILY_LOCKS", 1, true), "Run Phase 16 before Phase 17.")

local serverShouldUpdate = false
if not string.find(serverSource, "NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD", 1, true) then
	local serverSlotGuard = [=[

	-- NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD
	local function V86_moduleFitsSlot(module, slotId, allowedModuleFolder)
		if not module then return false end
		local moduleFolder = V56_string(module, "ModuleFolder", "")
		local moduleId = tostring(module:GetAttribute("ModuleId") or module.Name or "")
		local isRearEngine = module:GetAttribute("RearEngine") == true or moduleFolder == "Engines_B" or string.find(moduleId, "ENGINE_B", 1, true) ~= nil
		if slotId == "Engine1" then
			return not isRearEngine
		end
		if slotId == "Engine2" then
			return isRearEngine
		end
		if allowedModuleFolder and allowedModuleFolder ~= "" then
			return moduleFolder == allowedModuleFolder
		end
		return true
	end
]=]
	serverSource = insertAfterOnce(serverSource, [[	local function V85_moduleLockedMessage(profile, module)
		local ownsSource, sourceCockpitId = V85_playerOwnsSourceCockpit(profile, module)
		if ownsSource then return nil end
		local cockpit = sourceCockpitId and V56_findCockpit(profile.CurrentCategory, sourceCockpitId)
		local cockpitName = cockpit and V56_string(cockpit, "DisplayName", sourceCockpitId) or sourceCockpitId or "the source cockpit"
		return "Buy " .. cockpitName .. " before buying this module family."
	end
]], serverSlotGuard, "Phase 17 server slot guard helper")

	local oldLegacySlotCheck = [[				elseif slotType and slotType ~= "" and moduleType ~= slotType then ok, message = false, "That module does not fit this slot."
]]
	local newLegacySlotCheck = [[				elseif slotType and slotType ~= "" and moduleType ~= slotType then ok, message = false, "That module does not fit this slot."
				elseif not V86_moduleFitsSlot(module, slotId, mount and V56_string(mount, "AllowedModuleFolder", "")) then ok, message = false, "That module does not fit this slot."
]]
	serverSource = replaceOnce(serverSource, oldLegacySlotCheck, newLegacySlotCheck, "Phase 17 legacy BuyModule front/rear guard")

	local oldInstanceSlotCheck = [[		if slotType and slotType ~= "" and moduleType ~= slotType then
			return false, "That module does not fit this slot."
		end

]]
	local newInstanceSlotCheck = [[		if slotType and slotType ~= "" and moduleType ~= slotType then
			return false, "That module does not fit this slot."
		end
		if not V86_moduleFitsSlot(module, slotId, mount and V56_string(mount, "AllowedModuleFolder", "")) then
			return false, "That module does not fit this slot."
		end

]]
	serverSource = replaceOnce(serverSource, oldInstanceSlotCheck, newInstanceSlotCheck, "Phase 17 EquipModuleInstance front/rear guard")
	serverShouldUpdate = true
end

local clientRoot = waitPath(StarterPlayer, "StarterPlayerScripts", "NeoTokyoRacersClient")
local bootstrap = waitPath(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local clientSource = bootstrap.Source
assert(string.find(clientSource, "NTR_PERSISTENCE_PHASE16_MODULE_SORTING", 1, true), "Run Phase 16 before Phase 17.")

local clientShouldUpdate = false
if not string.find(clientSource, "NTR_PERSISTENCE_PHASE17_MODULE_TABS", 1, true) then
	local clientHelper = [=[

-- NTR_PERSISTENCE_PHASE17_MODULE_TABS
function NTRPersistencePhase15.ModuleFitsSelectedSlot(module, slot)
	if not module or not slot then return false end
	local slotId = tostring(slot.SlotId or "")
	local moduleFolder = tostring(module.ModuleFolder or "")
	local moduleId = tostring(module.ModuleId or "")
	local isRearEngine = module.RearEngine == true or moduleFolder == "Engines_B" or string.find(moduleId, "ENGINE_B", 1, true) ~= nil
	if slotId == "Engine1" then
		return not isRearEngine
	end
	if slotId == "Engine2" then
		return isRearEngine
	end
	if slot.AllowedModuleFolder and slot.AllowedModuleFolder ~= "" then
		return moduleFolder == slot.AllowedModuleFolder
	end
	return true
end

function NTRPersistencePhase15.ModuleMatchesSelectedSlot(module, slot)
	if not module or not slot then return false end
	if tostring(module.ModuleType or "") ~= tostring(slot.ModuleType or "") then
		return false
	end
	return NTRPersistencePhase15.ModuleFitsSelectedSlot(module, slot)
end

function NTRPersistencePhase15.OwnedModuleInstancesForSlot(profile, slot, getModuleFn)
	local result = {}
	for instanceId, instance in pairs((profile and profile.OwnedModuleInstances) or {}) do
		local module = getModuleFn(tostring(instance.TemplateId or ""))
		if NTRPersistencePhase15.ModuleMatchesSelectedSlot(module, slot) then
			table.insert(result, {
				InstanceId = instanceId,
				Instance = instance,
				Module = module,
			})
		end
	end
	table.sort(result, function(a, b)
		local am, bm = a.Module or {}, b.Module or {}
		local af = tostring(am.SourceCockpitDisplayName or am.SourceCockpitId or "")
		local bf = tostring(bm.SourceCockpitDisplayName or bm.SourceCockpitId or "")
		if af ~= bf then return af < bf end
		local av = tonumber(am.VariantOrder) or 999
		local bv = tonumber(bm.VariantOrder) or 999
		if av ~= bv then return av < bv end
		if tostring(am.DisplayName or "") ~= tostring(bm.DisplayName or "") then
			return tostring(am.DisplayName or "") < tostring(bm.DisplayName or "")
		end
		return tostring(a.InstanceId) < tostring(b.InstanceId)
	end)
	return result
end
]=]
	clientSource = insertAfterOnce(clientSource, [[function NTRPersistencePhase15.ModuleLockText(profile, module)
	if NTRPersistencePhase15.OwnsSourceCockpit(profile, module and module.SourceCockpitId) then
		return nil
	end
	return "LOCKED: " .. tostring((module and module.SourceCockpitDisplayName) or "cockpit")
end
]], clientHelper, "Phase 17 client helper methods")

	local newModulesForSlot = [[local function modulesForSlot(slotId)
	local slot = getSlot(slotId)
	local category = getCategory()
	local result = {}
	if not slot or not category then return result end
	local list = (category.Modules and category.Modules[slot.ModuleType]) or {}
	for _, module in ipairs(list) do
		if NTRPersistencePhase15.ModuleFitsSelectedSlot(module, slot) then
			table.insert(result, module)
		end
	end
	table.sort(result, function(a, b)
		local ag = NTRPersistencePhase15.ModuleSortGroup(State.Profile, a)
		local bg = NTRPersistencePhase15.ModuleSortGroup(State.Profile, b)
		if ag ~= bg then return ag < bg end
		local ac = tostring(a.SourceCockpitDisplayName or a.SourceCockpitId or "")
		local bc = tostring(b.SourceCockpitDisplayName or b.SourceCockpitId or "")
		if ac ~= bc then return ac < bc end
		local av = tonumber(a.VariantOrder) or 999
		local bv = tonumber(b.VariantOrder) or 999
		if av ~= bv then return av < bv end
		return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
	end)
	return result
end

]]
	clientSource = replaceFunctionBlock(clientSource, "local function modulesForSlot(slotId)", "local function slotDisplayName(slot)", newModulesForSlot, "Phase 17 slot-filtered module list")

	clientSource = replaceOnce(clientSource, [[			State.ModuleMode = "Options"
			setCameraSection(slot.SlotId)
			renderModuleShop()
]], [[			State.ModuleMode = "Options"
			State.ModuleOptionMode = nil
			setCameraSection(slot.SlotId)
			renderModuleShop()
]], "Phase 17 reset owned/buy mode when selecting slot")

	local newRenderModuleOptions = [[local function renderModuleOptions()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)
	optionPool:Begin()
	if UI.ModulePopup then
		clear(UI.ModulePopup)
		UI.ModulePopup.Visible = false
		UI.ModulePopup.Size = UDim2.fromOffset(126, 30)
	end
	UI.ColorChannelFloat.Visible = false
	local slot = getSlot(State.SelectedSlot)
	local ownedInstances = NTRPersistencePhase15.OwnedModuleInstancesForSlot(State.Profile, slot, getModule)
	local buyList = modulesForSlot(State.SelectedSlot)
	local installed = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[State.SelectedSlot]
	local currentVehicle = State.Profile and State.Profile.CurrentVehicleId and State.Profile.Vehicles and State.Profile.Vehicles[State.Profile.CurrentVehicleId]
	local installedInstanceId = currentVehicle and currentVehicle.InstalledModules and currentVehicle.InstalledModules[State.SelectedSlot]

	local function finishModuleInstall(result)
		if result.Success then
			clearPreviewModules()
			State.ModuleMode = "Slots"
			State.ModuleOptionMode = nil
			buildPreview()
			renderStatsPanel()
			renderModuleShop()
		else
			UI.Subtitle.Text = result.Message or "Could not install module."
		end
	end

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

	local x = 6
	if State.ModuleOptionMode == "Owned" then
		if #ownedInstances == 0 then
			local empty = pooledButton(optionPool, "No owned modules", UDim2.fromOffset(190, 72), UDim2.fromOffset(x, 7), Theme.Disabled)
			empty.AutoButtonColor = false
			x += 202
		end
		for index, ownedRecord in ipairs(ownedInstances) do
			local module = ownedRecord.Module
			local instance = ownedRecord.Instance
			local instanceId = ownedRecord.InstanceId
			local isInstalledHere = installedInstanceId == instanceId
			local equippedElsewhere = instance.EquippedVehicleId ~= nil and instance.EquippedVehicleId ~= "" and instance.EquippedVehicleId ~= (State.Profile and State.Profile.CurrentVehicleId)
			local selected = State.SelectedModuleInstanceId == instanceId
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 76), UDim2.fromOffset(x, 5), isInstalledHere and Theme.Disabled or (selected and Theme.CardHot or Theme.Card))
			card.AutoButtonColor = not isInstalledHere
			pooledLabel(card, tostring(module and (module.DisplayName or module.ModuleId) or instance.TemplateId), UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "#" .. tostring(index) .. " / " .. tostring(module and (module.VariantName or "") or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 32), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			local status = isInstalledHere and "equipped here" or (equippedElsewhere and "in another car" or "owned")
			pooledLabel(card, status, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isInstalledHere and Theme.Accent or Theme.Cash
			optionPool:Connect(card, card.MouseButton1Click, function()
				if not module then return end
				State.SelectedModuleId = module.ModuleId
				State.SelectedModuleInstanceId = instanceId
				State.PreviewModules = { [State.SelectedSlot] = module.ModuleId }
				buildPreview()
				renderModuleOptions()
			end)
			if selected and not isInstalledHere then
				UI.ModulePopup.Visible = true
				UI.ModulePopup.Size = UDim2.fromOffset(126, 30)
				local popupX = math.clamp(x + 29 - UI.ModuleOptions.CanvasPosition.X, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))
				UI.ModulePopup.Position = UDim2.fromOffset(popupX, -28)
				local equip = button(UI.ModulePopup, "EQUIP", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Buy)
				equip.MouseButton1Click:Connect(function()
					finishModuleInstall(callServer("EquipModuleInstance", {
						ModuleInstanceId = instanceId,
						VehicleId = State.Profile and State.Profile.CurrentVehicleId,
						SlotId = State.SelectedSlot,
					}))
				end)
			end
			x += 196
		end
	else
		for _, module in ipairs(buyList) do
			local isInstalled = installed == module.ModuleId
			local lockText = NTRPersistencePhase15.ModuleLockText(State.Profile, module)
			local isLocked = lockText ~= nil
			local selected = State.SelectedModuleId == module.ModuleId and State.SelectedModuleInstanceId == nil
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 76), UDim2.fromOffset(x, 5), isLocked and Theme.Disabled or (isInstalled and Theme.Disabled or (selected and Theme.CardHot or Theme.Card)))
			card.AutoButtonColor = not isInstalled
			pooledLabel(card, module.DisplayName or module.ModuleId, UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			local familyText = tostring(module.SourceCockpitDisplayName or module.SourceCockpitId or "")
			pooledLabel(card, familyText .. " / " .. tostring(module.VariantName or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 32), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			local statusText = isLocked and lockText or ("$" .. tostring(module.Price or 0))
			pooledLabel(card, statusText, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isLocked and Theme.Danger or Theme.Cash
			optionPool:Connect(card, card.MouseButton1Click, function()
				State.SelectedModuleId = module.ModuleId
				State.SelectedModuleInstanceId = nil
				State.PreviewModules = { [State.SelectedSlot] = module.ModuleId }
				buildPreview()
				renderModuleOptions()
				if isLocked then
					UI.Subtitle.Text = lockText or "Buy the source cockpit before buying this module."
				end
			end)
			if selected and not isInstalled then
				UI.ModulePopup.Visible = true
				UI.ModulePopup.Size = UDim2.fromOffset(126, 30)
				local popupX = math.clamp(x + 29 - UI.ModuleOptions.CanvasPosition.X, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))
				UI.ModulePopup.Position = UDim2.fromOffset(popupX, -28)
				local buyColor = isLocked and Theme.Disabled or Theme.Buy
				local buy = button(UI.ModulePopup, isLocked and "LOCKED" or "BUY", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), buyColor)
				buy.AutoButtonColor = not isLocked
				buy.MouseButton1Click:Connect(function()
					if isLocked then
						UI.Subtitle.Text = lockText or "Buy the source cockpit before buying this module."
						return
					end
					local beforeProfile = State.Profile
					local buyResult = callServer("BuyModuleInstance", { ModuleId = module.ModuleId })
					if not buyResult.Success then
						UI.Subtitle.Text = buyResult.Message or "Could not buy module."
						return
					end
					local instanceId = NTRPersistencePhase15.FindNewModuleCopyId(beforeProfile, State.Profile, module.ModuleId)
					if not instanceId then
						UI.Subtitle.Text = "Bought module, but could not find the new copy to equip."
						renderModuleOptions()
						return
					end
					finishModuleInstall(callServer("EquipModuleInstance", {
						ModuleInstanceId = instanceId,
						VehicleId = State.Profile and State.Profile.CurrentVehicleId,
						SlotId = State.SelectedSlot,
					}))
				end)
			end
			x += 196
		end
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
	local renderModuleOptionsTail = [[	optionPool:End()
	local contentWidth = x + 6
	UI.ModuleOptions.CanvasSize = UDim2.fromOffset(math.max(contentWidth, UI.ModuleOptions.AbsoluteSize.X), 0)
	if contentWidth <= UI.ModuleOptions.AbsoluteSize.X + 2 then
		UI.ModuleOptions.CanvasPosition = Vector2.zero
	end
	renderStatsPanel()
end

]]
	clientSource = replaceFunctionBlockByTail(clientSource, "local function renderModuleOptions()", renderModuleOptionsTail, newRenderModuleOptions, "Phase 17 owned/buy module tabs")

	clientShouldUpdate = true
end

if serverShouldUpdate then
	garage.Source = serverSource
	garage:SetAttribute("PersistencePhase17ModuleTabs", true)
end

if clientShouldUpdate then
	bootstrap.Source = clientSource
	bootstrap:SetAttribute("PersistencePhase17ModuleTabs", true)
end

assert(string.find(garage.Source, "NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD", 1, true), "Phase 17 server slot guard marker missing after install.")
assert(string.find(bootstrap.Source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS", 1, true), "Phase 17 client tabs marker missing after install.")
assert(string.find(bootstrap.Source, "OWNED MODULES", 1, true), "Phase 17 owned modules tab missing after install.")
assert(string.find(bootstrap.Source, "BUY MODULES", 1, true), "Phase 17 buy modules tab missing after install.")
assert(not string.find(bootstrap.Source, "Buy Copy", 1, true), "Phase 17 should remove Buy Copy text from active module picker.")
assert(not string.find(bootstrap.Source, "No Free Copy", 1, true), "Phase 17 should remove No Free Copy text from active module picker.")

info("PASS: installed owned/buy module tabs, per-instance owned cards, and front/rear engine filtering.")
info("Next: enter Play mode and run scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua from the CLIENT Command Bar.")
