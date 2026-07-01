-- Persistence Phase 17 repair v2.
--
-- Run from Roblox Studio Command Bar in Edit mode if the first Phase 17 install
-- caused the client bootstrap parse error:
-- "Incomplete statement: expected assignment or a function call".
--
-- This removes the partially-installed Phase 17 client helper by marker, inserts
-- a cleaner helper block, replaces the module picker using the stable
-- `renderModuleShop = function()` boundary, and keeps the Phase 16/17 server
-- purchase locks intact.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Repair V2"

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

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, oldText, newText, label)
	local first = findPlain(source, oldText)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	local second = findPlain(source, oldText, first + #oldText)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting: " .. label)
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local function insertBeforeOnce(source, anchor, insertText, label)
	local first = findPlain(source, anchor)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	local second = findPlain(source, anchor, first + #anchor)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting: " .. label)
	end
	return string.sub(source, 1, first - 1) .. insertText .. string.sub(source, first)
end

local function replaceRange(source, startText, endText, replacement, label)
	local startIndex = findPlain(source, startText)
	if not startIndex then
		error("Could not find start for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	local endIndex = findPlain(source, endText, startIndex + #startText)
	if not endIndex then
		error("Could not find end for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local function removeRangeIfPresent(source, startText, endText, label)
	local startIndex = findPlain(source, startText)
	if not startIndex then
		return source, false
	end
	local endIndex = findPlain(source, endText, startIndex + #startText)
	if not endIndex then
		error("Found start but not end while removing " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	return string.sub(source, 1, startIndex - 1) .. string.sub(source, endIndex), true
end

local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")
assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local serverSource = garage.Source
assert(findPlain(serverSource, "NTR_PERSISTENCE_PHASE16_MODULE_FAMILY_LOCKS"), "Run Phase 16 before Phase 17 repair.")

if not findPlain(serverSource, "NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD") then
	local serverSlotGuard = [=[

	-- NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD
	local function V86_moduleFitsSlot(moduleModel, slotId, allowedModuleFolder)
		if not moduleModel then return false end
		local moduleFolder = V56_string(moduleModel, "ModuleFolder", "")
		local moduleId = tostring(moduleModel:GetAttribute("ModuleId") or moduleModel.Name or "")
		local displayName = tostring(moduleModel:GetAttribute("DisplayName") or moduleModel.Name or "")
		local isRearEngine = moduleModel:GetAttribute("RearEngine") == true
			or moduleFolder == "Engines_B"
			or string.find(moduleId, "ENGINE_B", 1, true) ~= nil
			or string.find(string.lower(displayName), "rear", 1, true) ~= nil
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
	serverSource = insertBeforeOnce(serverSource, [[
	V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)
]], serverSlotGuard, "Phase 17 server slot guard helper")

	serverSource = replaceOnce(serverSource, [[				elseif slotType and slotType ~= "" and moduleType ~= slotType then ok, message = false, "That module does not fit this slot."
]], [[				elseif slotType and slotType ~= "" and moduleType ~= slotType then ok, message = false, "That module does not fit this slot."
				elseif not V86_moduleFitsSlot(module, slotId, mount and V56_string(mount, "AllowedModuleFolder", "")) then ok, message = false, "That module does not fit this slot."
]], "Phase 17 legacy BuyModule front/rear guard")

	serverSource = replaceOnce(serverSource, [[		if slotType and slotType ~= "" and moduleType ~= slotType then
			return false, "That module does not fit this slot."
		end

]], [[		if slotType and slotType ~= "" and moduleType ~= slotType then
			return false, "That module does not fit this slot."
		end
		if not V86_moduleFitsSlot(module, slotId, mount and V56_string(mount, "AllowedModuleFolder", "")) then
			return false, "That module does not fit this slot."
		end

]], "Phase 17 EquipModuleInstance front/rear guard")
	garage.Source = serverSource
	garage:SetAttribute("PersistencePhase17ModuleTabs", true)
end

local clientRoot = waitPath(StarterPlayer, "StarterPlayerScripts", "NeoTokyoRacersClient")
local bootstrap = waitPath(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local clientSource = bootstrap.Source
assert(findPlain(clientSource, "NTR_PERSISTENCE_PHASE16_MODULE_SORTING"), "Run Phase 16 before Phase 17 repair.")

clientSource = removeRangeIfPresent(clientSource, "-- NTR_PERSISTENCE_PHASE17_MODULE_TABS", "local function modulesForSlot(slotId)", "old Phase 17 client helper")

local clientHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V2
function NTRPersistencePhase15.ModuleIsRearEngine(moduleInfo)
	if not moduleInfo then return false end
	local moduleFolder = tostring(moduleInfo.ModuleFolder or "")
	local moduleId = tostring(moduleInfo.ModuleId or "")
	local displayName = string.lower(tostring(moduleInfo.DisplayName or moduleInfo.ModuleId or ""))
	return moduleInfo.RearEngine == true
		or moduleFolder == "Engines_B"
		or string.find(moduleId, "ENGINE_B", 1, true) ~= nil
		or string.find(displayName, "rear", 1, true) ~= nil
end

function NTRPersistencePhase15.ModuleFitsSelectedSlot(moduleInfo, slotInfo)
	if not moduleInfo or not slotInfo then return false end
	local slotId = tostring(slotInfo.SlotId or "")
	local moduleFolder = tostring(moduleInfo.ModuleFolder or "")
	if slotId == "Engine1" then
		return not NTRPersistencePhase15.ModuleIsRearEngine(moduleInfo)
	end
	if slotId == "Engine2" then
		return NTRPersistencePhase15.ModuleIsRearEngine(moduleInfo)
	end
	if slotInfo.AllowedModuleFolder and slotInfo.AllowedModuleFolder ~= "" then
		return moduleFolder == slotInfo.AllowedModuleFolder
	end
	return true
end

function NTRPersistencePhase15.ModuleMatchesSelectedSlot(moduleInfo, slotInfo)
	if not moduleInfo or not slotInfo then return false end
	if tostring(moduleInfo.ModuleType or "") ~= tostring(slotInfo.ModuleType or "") then
		return false
	end
	return NTRPersistencePhase15.ModuleFitsSelectedSlot(moduleInfo, slotInfo)
end

function NTRPersistencePhase15.OwnedModuleInstancesForSlot(profile, slotInfo, getModuleFn)
	local result = {}
	for instanceId, instance in pairs((profile and profile.OwnedModuleInstances) or {}) do
		local moduleInfo = getModuleFn(tostring(instance.TemplateId or ""))
		if NTRPersistencePhase15.ModuleMatchesSelectedSlot(moduleInfo, slotInfo) then
			table.insert(result, {
				InstanceId = instanceId,
				Instance = instance,
				Module = moduleInfo,
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
clientSource = insertBeforeOnce(clientSource, "local function modulesForSlot(slotId)", clientHelper, "Phase 17 v2 client helper methods")

local newModulesForSlot = [[local function modulesForSlot(slotId)
	local slotInfo = getSlot(slotId)
	local category = getCategory()
	local result = {}
	if not slotInfo or not category then return result end
	local list = (category.Modules and category.Modules[slotInfo.ModuleType]) or {}
	for _, moduleInfo in ipairs(list) do
		if NTRPersistencePhase15.ModuleFitsSelectedSlot(moduleInfo, slotInfo) then
			table.insert(result, moduleInfo)
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
clientSource = replaceRange(clientSource, "local function modulesForSlot(slotId)", "local function slotDisplayName(slot)", newModulesForSlot, "Phase 17 v2 slot-filtered module list")

clientSource = string.gsub(clientSource, "State%.ModuleMode = \"Options\"\n(%s*)setCameraSection%(slot%.SlotId%)", "State.ModuleMode = \"Options\"\n%1State.ModuleOptionMode = nil\n%1setCameraSection(slot.SlotId)", 1)

local newRenderModuleOptions = [[local function renderModuleOptions()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)
	optionPool:Begin()
	if UI.ModulePopup then
		clear(UI.ModulePopup)
		UI.ModulePopup.Visible = false
		UI.ModulePopup.Size = UDim2.fromOffset(126, 30)
	end
	UI.ColorChannelFloat.Visible = false
	local slotInfo = getSlot(State.SelectedSlot)
	local ownedInstances = NTRPersistencePhase15.OwnedModuleInstancesForSlot(State.Profile, slotInfo, getModule)
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
			local moduleInfo = ownedRecord.Module
			local instance = ownedRecord.Instance
			local instanceId = ownedRecord.InstanceId
			local isInstalledHere = installedInstanceId == instanceId
			local equippedElsewhere = instance.EquippedVehicleId ~= nil and instance.EquippedVehicleId ~= "" and instance.EquippedVehicleId ~= (State.Profile and State.Profile.CurrentVehicleId)
			local selected = State.SelectedModuleInstanceId == instanceId
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 76), UDim2.fromOffset(x, 5), isInstalledHere and Theme.Disabled or (selected and Theme.CardHot or Theme.Card))
			card.AutoButtonColor = not isInstalledHere
			pooledLabel(card, tostring(moduleInfo and (moduleInfo.DisplayName or moduleInfo.ModuleId) or instance.TemplateId), UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "#" .. tostring(index) .. " / " .. tostring(moduleInfo and (moduleInfo.VariantName or "") or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 32), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			local status = isInstalledHere and "equipped here" or (equippedElsewhere and "in another car" or "owned")
			pooledLabel(card, status, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isInstalledHere and Theme.Accent or Theme.Cash
			optionPool:Connect(card, card.MouseButton1Click, function()
				if not moduleInfo then return end
				State.SelectedModuleId = moduleInfo.ModuleId
				State.SelectedModuleInstanceId = instanceId
				State.PreviewModules = { [State.SelectedSlot] = moduleInfo.ModuleId }
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
		for _, moduleInfo in ipairs(buyList) do
			local isInstalled = installed == moduleInfo.ModuleId
			local lockText = NTRPersistencePhase15.ModuleLockText(State.Profile, moduleInfo)
			local isLocked = lockText ~= nil
			local selected = State.SelectedModuleId == moduleInfo.ModuleId and State.SelectedModuleInstanceId == nil
			local card = pooledButton(optionPool, "", UDim2.fromOffset(184, 76), UDim2.fromOffset(x, 5), isLocked and Theme.Disabled or (isInstalled and Theme.Disabled or (selected and Theme.CardHot or Theme.Card)))
			card.AutoButtonColor = not isInstalled
			pooledLabel(card, moduleInfo.DisplayName or moduleInfo.ModuleId, UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			local familyText = tostring(moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId or "")
			pooledLabel(card, familyText .. " / " .. tostring(moduleInfo.VariantName or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 32), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			local statusText = isLocked and lockText or ("$" .. tostring(moduleInfo.Price or 0))
			pooledLabel(card, statusText, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isLocked and Theme.Danger or Theme.Cash
			optionPool:Connect(card, card.MouseButton1Click, function()
				State.SelectedModuleId = moduleInfo.ModuleId
				State.SelectedModuleInstanceId = nil
				State.PreviewModules = { [State.SelectedSlot] = moduleInfo.ModuleId }
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
				local buy = button(UI.ModulePopup, isLocked and "LOCKED" or "BUY", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), isLocked and Theme.Disabled or Theme.Buy)
				buy.AutoButtonColor = not isLocked
				buy.MouseButton1Click:Connect(function()
					if isLocked then
						UI.Subtitle.Text = lockText or "Buy the source cockpit before buying this module."
						return
					end
					local beforeProfile = State.Profile
					local buyResult = callServer("BuyModuleInstance", { ModuleId = moduleInfo.ModuleId })
					if not buyResult.Success then
						UI.Subtitle.Text = buyResult.Message or "Could not buy module."
						return
					end
					local instanceId = NTRPersistencePhase15.FindNewModuleCopyId(beforeProfile, State.Profile, moduleInfo.ModuleId)
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
clientSource = replaceRange(clientSource, "local function renderModuleOptions()", "renderModuleShop = function()", newRenderModuleOptions, "Phase 17 v2 owned/buy module tabs")

bootstrap.Source = clientSource
bootstrap:SetAttribute("PersistencePhase17ModuleTabs", true)

assert(findPlain(bootstrap.Source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS_V2"), "Phase 17 v2 client marker missing after repair.")
assert(findPlain(bootstrap.Source, "OWNED MODULES"), "Phase 17 owned modules tab missing after repair.")
assert(findPlain(bootstrap.Source, "BUY MODULES"), "Phase 17 buy modules tab missing after repair.")
assert(not findPlain(bootstrap.Source, "Buy Copy"), "Phase 17 v2 should remove Buy Copy text from active module picker.")
assert(not findPlain(bootstrap.Source, "No Free Copy"), "Phase 17 v2 should remove No Free Copy text from active module picker.")

info("PASS: repaired Phase 17 owned/buy module picker source.")
info("Next: restart Play, then run scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua from the CLIENT Command Bar.")
