-- Persistence Phase 16: module family locks, paid extra standard copies, and owned-first sorting.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 15 is confirmed.
--
-- Scope:
-- - Patches the active garage server controller so module purchases are gated
--   by the cockpit family the module comes from.
-- - Adds module catalogue metadata used by the UI: SourceCockpitId,
--   SourceCockpitDisplayName, VariantName, and VariantOrder.
-- - Ensures newly bought cockpit instances get one included starter module set
--   attached to that vehicle instance, while extra module copies are paid.
-- - Patches the active client bootstrap so module option cards show owned/free
--   copies first, unlocked purchasable modules next, and locked modules last.
-- - Does not change driving, VFX, garage teleporting, DataStore ownership, or
--   garage property UI.
--
-- This is a guarded text patch against the Phase 14/15 live scripts. If an
-- anchor is missing, refresh the Studio mirror before writing another patch.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 16"

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
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 16 patch.")
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
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 16 patch.")
	end
	local second = string.find(source, anchor, first + #anchor, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting.")
	end
	return string.sub(source, 1, first + #anchor) .. insertText .. string.sub(source, first + #anchor + 1)
end

local function replaceFunctionBlock(source, functionStart, nextStart, replacement, label)
	local first = string.find(source, functionStart, 1, true)
	if not first then
		error("Could not find function start for " .. label .. ". Refresh the Studio mirror before another Phase 16 patch.")
	end
	local nextIndex = string.find(source, nextStart, first + #functionStart, true)
	if not nextIndex then
		error("Could not find function end anchor for " .. label .. ". Refresh the Studio mirror before another Phase 16 patch.")
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, nextIndex)
end

local function replaceFunctionBlockByTail(source, functionStart, tailText, replacement, label)
	local first = string.find(source, functionStart, 1, true)
	if not first then
		error("Could not find function start for " .. label .. ". Refresh the Studio mirror before another Phase 16 patch.")
	end
	local tailStart = string.find(source, tailText, first + #functionStart, true)
	if not tailStart then
		error("Could not find function tail for " .. label .. ". Refresh the Studio mirror before another Phase 16 patch.")
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, tailStart + #tailText)
end

local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")
assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local serverSource = garage.Source
assert(string.find(serverSource, "NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY_HELPERS", 1, true), "Run Phase 14 before Phase 16.")

local serverShouldUpdate = false
if not string.find(serverSource, "NTR_PERSISTENCE_PHASE16_MODULE_FAMILY_LOCKS", 1, true) then
	local serverHelper = [=[

	-- NTR_PERSISTENCE_PHASE16_MODULE_FAMILY_LOCKS
	local V85_attachDefaultModuleInstancesToCurrentVehicle

	local function V85_moduleSourceCockpitId(module)
		if not module then return nil end
		local explicit = module:GetAttribute("SourceCockpitId")
		if explicit ~= nil and tostring(explicit) ~= "" then
			return tostring(explicit)
		end
		local item = module.Parent
		while item and item ~= V56_categoriesRoot do
			local name = tostring(item.Name or "")
			local numberText = string.match(name, "^Bruiser[_%s%-]*(%d+)$") or string.match(name, "BRUISER[_%s%-]*(%d+)")
			if numberText then
				return "bruiser_" .. string.format("%02d", tonumber(numberText) or 0)
			end
			item = item.Parent
		end
		local moduleId = tostring(module:GetAttribute("ModuleId") or module.Name or "")
		local numberText = string.match(moduleId, "BRUISER_(%d+)")
		if numberText then
			return "bruiser_" .. string.format("%02d", tonumber(numberText) or 0)
		end
		return nil
	end

	local function V85_moduleVariantName(module)
		local explicit = module and module:GetAttribute("VariantName")
		if explicit ~= nil and tostring(explicit) ~= "" then
			return tostring(explicit)
		end
		local text = string.upper(tostring(module and (module:GetAttribute("ModuleId") or module.Name) or ""))
		if string.find(text, "LIGHTWEIGHT", 1, true) then return "Lightweight" end
		if string.find(text, "POWER", 1, true) then return "Power" end
		local level = string.match(text, "LVL(%d+)") or string.match(text, "LEVEL(%d+)")
		if level then return "Level " .. tostring(level) end
		if string.find(text, "STANDARD", 1, true) then return "Standard" end
		return "Standard"
	end

	local function V85_moduleVariantOrder(module)
		local explicit = module and tonumber(module:GetAttribute("VariantOrder"))
		if explicit then return explicit end
		local variant = string.lower(V85_moduleVariantName(module))
		if variant == "standard" then return 10 end
		if variant == "lightweight" then return 20 end
		if variant == "power" then return 30 end
		local level = tonumber(string.match(variant, "(%d+)"))
		if level then return 100 + level end
		return 999
	end

	local function V85_findSourceCockpit(profile, module)
		local sourceCockpitId = V85_moduleSourceCockpitId(module)
		if not sourceCockpitId then return nil, nil end
		return sourceCockpitId, V56_findCockpit(profile and profile.CurrentCategory or "bruiser", sourceCockpitId)
	end

	local function V85_playerOwnsSourceCockpit(profile, module)
		local sourceCockpitId = V85_moduleSourceCockpitId(module)
		if not sourceCockpitId then return true, nil end
		if profile and profile.OwnedCockpits and profile.OwnedCockpits[sourceCockpitId] == true then
			return true, sourceCockpitId
		end
		for _, instance in pairs((profile and profile.OwnedCockpitInstances) or {}) do
			if tostring(instance.TemplateId or "") == sourceCockpitId then
				return true, sourceCockpitId
			end
		end
		return false, sourceCockpitId
	end

	local function V85_modulePurchasePrice(module)
		if not module then return 0 end
		local explicit = tonumber(module:GetAttribute("ExtraCopyPrice") or module:GetAttribute("ModuleCopyPrice") or module:GetAttribute("PurchasePrice"))
		if explicit and explicit > 0 then
			return math.floor(explicit)
		end
		local price = V56_number(module, "Price", 0)
		if price > 0 then return price end
		local sourceCockpitId = V85_moduleSourceCockpitId(module)
		local cockpit = sourceCockpitId and V56_findCockpit("bruiser", sourceCockpitId)
		local cockpitPrice = cockpit and V56_number(cockpit, "Price", 0) or 0
		return math.max(1000, math.floor(cockpitPrice * 0.12))
	end

	local function V85_moduleLockedMessage(profile, module)
		local ownsSource, sourceCockpitId = V85_playerOwnsSourceCockpit(profile, module)
		if ownsSource then return nil end
		local cockpit = sourceCockpitId and V56_findCockpit(profile.CurrentCategory, sourceCockpitId)
		local cockpitName = cockpit and V56_string(cockpit, "DisplayName", sourceCockpitId) or sourceCockpitId or "the source cockpit"
		return "Buy " .. cockpitName .. " before buying this module family."
	end

]=]

	serverSource = insertAfterOnce(serverSource, [[	local function V56_findModule(categoryId, moduleId)
		local category = V56_categoryFolder(categoryId)
		local root = category and (category:FindFirstChild("MODULES_InterchangeableWithinCategory") or category)
		return V56_findByAttribute(root, "ModuleId", moduleId)
	end
]], serverHelper, "Phase 16 server helpers")

	local oldReadModule = [[	local function V56_readModule(item, root)
		local moduleType = V56_moduleTypeForModel(item, root)
		return {
			ModuleId = V56_string(item, "ModuleId", item.Name),
			DisplayName = V56_string(item, "DisplayName", V56_string(item, "ModuleName", item.Name)),
			ModuleType = moduleType,
			ModuleSlot = V56_string(item, "ModuleSlot", moduleType),
			ModuleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item)),
			Price = V56_number(item, "Price", 0),
			Power = V56_number(item, "Power", 0),
			Weight = V56_number(item, "Weight", 0),
			TopSpeed = V56_number(item, "TopSpeed", 0),
			Acceleration = V56_number(item, "Acceleration", 0),
			Handling = V56_number(item, "Handling", 0),
			Drift = V56_number(item, "Drift", 0),
			Braking = V56_number(item, "Braking", 0),
			Boost = V56_number(item, "Boost", 0),
			BoostDuration = V56_number(item, "BoostDuration", 0),
			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType),
		}
	end
]]

	local newReadModule = [[	local function V56_readModule(item, root)
		local moduleType = V56_moduleTypeForModel(item, root)
		local sourceCockpitId = V85_moduleSourceCockpitId(item)
		local sourceCockpit = sourceCockpitId and V56_findCockpit("bruiser", sourceCockpitId)
		return {
			ModuleId = V56_string(item, "ModuleId", item.Name),
			DisplayName = V56_string(item, "DisplayName", V56_string(item, "ModuleName", item.Name)),
			ModuleType = moduleType,
			ModuleSlot = V56_string(item, "ModuleSlot", moduleType),
			ModuleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item)),
			SourceCockpitId = sourceCockpitId,
			SourceCockpitDisplayName = sourceCockpit and V56_string(sourceCockpit, "DisplayName", sourceCockpitId) or sourceCockpitId,
			VariantName = V85_moduleVariantName(item),
			VariantOrder = V85_moduleVariantOrder(item),
			Price = V85_modulePurchasePrice(item),
			Power = V56_number(item, "Power", 0),
			Weight = V56_number(item, "Weight", 0),
			TopSpeed = V56_number(item, "TopSpeed", 0),
			Acceleration = V56_number(item, "Acceleration", 0),
			Handling = V56_number(item, "Handling", 0),
			Drift = V56_number(item, "Drift", 0),
			Braking = V56_number(item, "Braking", 0),
			Boost = V56_number(item, "Boost", 0),
			BoostDuration = V56_number(item, "BoostDuration", 0),
			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType),
		}
	end
]]

	serverSource = replaceOnce(serverSource, oldReadModule, newReadModule, "Phase 16 module catalogue metadata")

	local attachDefaultBlock = [=[

	V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)
		if not profile then return end
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
		local vehicleId = profile.CurrentVehicleId
		local vehicle = vehicleId and profile.Vehicles and profile.Vehicles[vehicleId]
		if not vehicle then return end
		local cockpitInstance = profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local cockpitId = cockpitInstance and cockpitInstance.TemplateId or profile.CurrentCockpit
		local cockpit = V56_findCockpit(vehicle.CategoryId or profile.CurrentCategory, cockpitId)
		local defaults = V76_defaultModuleIdsForCockpit(cockpit)
		local slotDefaults = {
			Engine1 = defaults.Engine,
			Engine2 = defaults.RearEngine,
			Stabilisers = defaults.Stabilisers,
			Boost = defaults.Boost,
		}
		vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}
		profile.OwnedModules = profile.OwnedModules or {}
		profile.InstalledModules = profile.InstalledModules or {}
		for slotId, moduleId in pairs(slotDefaults) do
			if moduleId and V56_findModule(profile.CurrentCategory, moduleId) and not vehicle.InstalledModules[slotId] then
				local moduleInstanceId = V84_generateId("module")
				profile.OwnedModules[moduleId] = true
				profile.OwnedModuleInstances[moduleInstanceId] = {
					TemplateId = moduleId,
					EquippedVehicleId = vehicleId,
					UpgradeLevels = V84_cloneDictionary((profile.ModuleUpgradeLevels or {})[moduleId] or {}),
					Colors = V84_cloneDictionary(profile.CockpitColors or {}),
					NeonOwned = false,
					Source = "IncludedWithCockpit",
				}
				vehicle.InstalledModules[slotId] = moduleInstanceId
			end
			if vehicleId == profile.CurrentVehicleId and moduleId then
				profile.InstalledModules[slotId] = moduleId
			end
		end
	end
]=]
	serverSource = replaceOnce(serverSource, [[
	local function V84_buyCockpitInstance(profile, args)
]], attachDefaultBlock .. [[
	local function V84_buyCockpitInstance(profile, args)
]], "Phase 16 included default module instance helper")

	serverSource = string.gsub(serverSource, "V76_grantDefaultModulesForCurrentCockpit%(profile%)\n", "V76_grantDefaultModulesForCurrentCockpit(profile)\n\t\t\t\t\t\tV85_attachDefaultModuleInstancesToCurrentVehicle(profile)\n")

	local legacyBuyModulePriceOld = [[				else
					local price = V56_number(module, "Price", 0)
					if not profile.OwnedModules[moduleId] then
]]
	local legacyBuyModulePriceNew = [[				else
					local lockMessage = V85_moduleLockedMessage(profile, module)
					if lockMessage then
						ok, message = false, lockMessage
					else
						local price = V85_modulePurchasePrice(module)
						if not profile.OwnedModules[moduleId] then
]]
	serverSource = replaceOnce(serverSource, legacyBuyModulePriceOld, legacyBuyModulePriceNew, "Phase 16 legacy module lock open")

	local buyModuleCloseAnchor = [[						profile.ModuleColors[slotId].ThrustColor = profile.ThrustColor
					end
					V56_setLeaderstats(player, profile)
				end
]]
	local buyModuleCloseReplacement = [[						profile.ModuleColors[slotId].ThrustColor = profile.ThrustColor
					end
					end
					V56_setLeaderstats(player, profile)
				end
]]
	serverSource = replaceOnce(serverSource, buyModuleCloseAnchor, buyModuleCloseReplacement, "Phase 16 legacy module lock close")

	local buyModuleInstanceOld = [[		local price = V56_number(module, "Price", 0)
		if profile.Cash < price then
			return false, "Not enough cash."
		end
]]
	local buyModuleInstanceNew = [[		local lockMessage = V85_moduleLockedMessage(profile, module)
		if lockMessage then
			return false, lockMessage
		end
		local price = V85_modulePurchasePrice(module)
		if profile.Cash < price then
			return false, "Not enough cash."
		end
]]
	serverSource = replaceOnce(serverSource, buyModuleInstanceOld, buyModuleInstanceNew, "Phase 16 module instance source lock")

	serverShouldUpdate = true
end

local clientRoot = waitPath(StarterPlayer, "StarterPlayerScripts", "NeoTokyoRacersClient")
local bootstrap = waitPath(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local clientSource = bootstrap.Source
assert(string.find(clientSource, "NTR_PERSISTENCE_PHASE15_DUPLICATE_COPY_UI", 1, true), "Run Phase 15 before Phase 16.")

local clientShouldUpdate = false
if not string.find(clientSource, "NTR_PERSISTENCE_PHASE16_MODULE_SORTING", 1, true) then
	local clientHelper = [=[

-- NTR_PERSISTENCE_PHASE16_MODULE_SORTING
function NTRPersistencePhase15.OwnsSourceCockpit(profile, sourceCockpitId)
	if sourceCockpitId == nil or tostring(sourceCockpitId) == "" then
		return true
	end
	if profile and profile.OwnedCockpits and profile.OwnedCockpits[sourceCockpitId] == true then
		return true
	end
	for _, instance in pairs((profile and profile.OwnedCockpitInstances) or {}) do
		if tostring(instance.TemplateId or "") == tostring(sourceCockpitId) then
			return true
		end
	end
	return false
end

function NTRPersistencePhase15.ModuleSortGroup(profile, module)
	local moduleId = module and module.ModuleId
	local count = NTRPersistencePhase15.CountModuleCopies(profile, moduleId)
	if count > 0 then return 1 end
	if not NTRPersistencePhase15.OwnsSourceCockpit(profile, module and module.SourceCockpitId) then return 3 end
	return 2
end

function NTRPersistencePhase15.ModuleLockText(profile, module)
	if NTRPersistencePhase15.OwnsSourceCockpit(profile, module and module.SourceCockpitId) then
		return nil
	end
	return "LOCKED: " .. tostring((module and module.SourceCockpitDisplayName) or "cockpit")
end
]=]

	clientSource = insertAfterOnce(clientSource, [[function NTRPersistencePhase15.FindNewModuleCopyId(beforeProfile, afterProfile, moduleId)
	local before = (beforeProfile and beforeProfile.OwnedModuleInstances) or {}
	for instanceId, instance in pairs((afterProfile and afterProfile.OwnedModuleInstances) or {}) do
		if before[instanceId] == nil and tostring(instance.TemplateId or "") == tostring(moduleId or "") then
			return instanceId
		end
	end
	return nil
end
]], clientHelper, "Phase 16 client helper methods")

	local newModulesForSlot = [[local function modulesForSlot(slotId)
	local slot = getSlot(slotId)
	local category = getCategory()
	local result = {}
	if not slot or not category then return result end
	local list = (category.Modules and category.Modules[slot.ModuleType]) or {}
	for _, module in ipairs(list) do
		table.insert(result, module)
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
	clientSource = replaceFunctionBlock(clientSource, "local function modulesForSlot(slotId)", "local function slotDisplayName(slot)", newModulesForSlot, "Phase 16 module option sorting")

	local newRenderModuleOptions = [[local function renderModuleOptions()
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
		local copyCount = NTRPersistencePhase15.CountModuleCopies(State.Profile, module.ModuleId)
		local isOwned = copyCount > 0 or owned[module.ModuleId] == true
		local isInstalled = installed == module.ModuleId
		local lockText = NTRPersistencePhase15.ModuleLockText(State.Profile, module)
		local isLocked = lockText ~= nil and copyCount <= 0
		local freeCopyId = NTRPersistencePhase15.FindFreeModuleCopy(State.Profile, module.ModuleId)
		local cardColor = isLocked and Theme.Disabled or (isInstalled and Theme.Disabled or (State.SelectedModuleId == module.ModuleId and Theme.CardHot or Theme.Card))
		local card = pooledButton(optionPool, "", UDim2.fromOffset(172, 76), UDim2.fromOffset(x, 5), cardColor)
		card.AutoButtonColor = not isInstalled and not isLocked
		pooledLabel(card, module.DisplayName or module.ModuleId, UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 8), 11, Enum.TextXAlignment.Center)
		local familyText = tostring(module.SourceCockpitDisplayName or module.SourceCockpitId or "")
		if familyText ~= "" then
			pooledLabel(card, familyText .. " / " .. tostring(module.VariantName or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 33), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
		end
		local statusText
		if isLocked then
			statusText = lockText
		elseif isOwned then
			statusText = ((isInstalled and "equipped" or (freeCopyId and "free copy" or "owned")) .. " x" .. tostring(copyCount))
		else
			statusText = "$" .. tostring(module.Price or 0)
		end
		pooledLabel(card, statusText, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isLocked and Theme.Danger or (isOwned and Theme.Accent or Theme.Cash)
		optionPool:Connect(card, card.MouseButton1Click, function()
			if isInstalled then return end
			if isLocked then
				UI.Subtitle.Text = lockText or "Buy the source cockpit before buying this module."
				return
			end
			State.SelectedModuleId = module.ModuleId
			State.PreviewModules = { [State.SelectedSlot] = module.ModuleId }
			buildPreview()
			renderModuleOptions()
		end)
		if State.SelectedModuleId == module.ModuleId and not isInstalled and not isLocked then
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
		x += 184
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
	clientSource = replaceFunctionBlockByTail(clientSource, "local function renderModuleOptions()", renderModuleOptionsTail, newRenderModuleOptions, "Phase 16 module option cards")

	clientShouldUpdate = true
end

if serverShouldUpdate then
	garage.Source = serverSource
	garage:SetAttribute("PersistencePhase16ModuleFamilyLocks", true)
end

if clientShouldUpdate then
	bootstrap.Source = clientSource
	bootstrap:SetAttribute("PersistencePhase16ModuleSorting", true)
end

assert(string.find(garage.Source, "NTR_PERSISTENCE_PHASE16_MODULE_FAMILY_LOCKS", 1, true), "Phase 16 server marker missing after install.")
assert(string.find(garage.Source, "V85_moduleLockedMessage", 1, true), "Phase 16 module lock helper missing after install.")
assert(string.find(garage.Source, "IncludedWithCockpit", 1, true), "Phase 16 included starter module marker missing after install.")
assert(string.find(bootstrap.Source, "NTR_PERSISTENCE_PHASE16_MODULE_SORTING", 1, true), "Phase 16 client sorting marker missing after install.")
assert(string.find(bootstrap.Source, "LOCKED:", 1, true), "Phase 16 locked card text missing after install.")

info("PASS: installed module family locks, paid extra standard copies, and owned-first module sorting.")
info("Next: enter Play mode and run scripts/roblox_persistence_phase16_module_family_locks_and_sorting_client_smoke.lua from the CLIENT Command Bar.")
