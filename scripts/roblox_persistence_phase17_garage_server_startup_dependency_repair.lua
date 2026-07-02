-- Persistence Phase 17 garage server startup dependency repair.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 17 server repairs
-- if the client smoke still fails GetInitial with shifted nil-call errors, e.g.
--
--   GarageActionController_Shadow_Disabled:1639: attempt to call a nil value
--
-- This is a guarded source-text repair. It restores the helper families used by
-- GetInitial, module cataloging, default cockpit modules, profile stats, and the
-- instance inventory bridge, then audits their presence and declaration order.

local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 17 Garage Startup Dependency Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function insertBefore(source, anchor, insertion, label)
	local at = findPlain(source, anchor)
	assert(at, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	return string.sub(source, 1, at - 1) .. insertion .. string.sub(source, at)
end

local function firstPosition(source, patterns)
	local best = nil
	for _, pattern in ipairs(patterns) do
		local at = findPlain(source, pattern)
		if at and (not best or at < best) then
			best = at
		end
	end
	return best
end

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local source = garage.Source
assert(findPlain(source, "V56_invoke.OnServerInvoke"), "Expected active garage OnServerInvoke block.")
assert(findPlain(source, "Catalog = V56_catalog()"), "Expected GetInitial to call V56_catalog().")
assert(findPlain(source, "V76_grantDefaultModulesForCurrentCockpit(profile)"), "Expected GetInitial/startup path to call V76_grantDefaultModulesForCurrentCockpit.")

local changed = false

local attachHeader = "V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)"
local normalizedSource, duplicateCount = string.gsub(
	source,
	"V85_attachDefaultModuleInstancesToCurrentVehicle%s*=%s*function%(profile%)%s+V85_attachDefaultModuleInstancesToCurrentVehicle%s*=%s*function%(profile%)",
	attachHeader
)
if duplicateCount > 0 then
	source = normalizedSource
	changed = true
	info("Normalized duplicated V85 attach header count: " .. tostring(duplicateCount))
end

local firstModuleTypeUse = firstPosition(source, {
	"V56_moduleTypeFromText(slotId)",
	"V56_moduleTypeForModel(module)",
	"V56_moduleTypeForModel(item",
	"V56_moduleTypeForModel(moduleTemplate",
})
assert(firstModuleTypeUse, "Could not find module-type helper usage.")

local moduleTypeDefinition = findPlain(source, "local function V56_moduleTypeFromText(text)")
local moduleTypeForModelDefinition = findPlain(source, "local function V56_moduleTypeForModel(module, root)")
if not moduleTypeDefinition or moduleTypeDefinition > firstModuleTypeUse or not moduleTypeForModelDefinition or moduleTypeForModelDefinition > firstModuleTypeUse then
	local moduleTypeAnchor = "\n\tlocal function V86_moduleFitsSlot"
	if not findPlain(source, moduleTypeAnchor) then
		moduleTypeAnchor = "\n\tlocal function V84_buyModuleInstance"
	end

	local moduleTypeBlock = [=[

	-- NTR_PERSISTENCE_PHASE17_STARTUP_DEPENDENCY_REPAIR_MODULE_TYPES
	local function V56_moduleTypeFromText(text)
		text = string.lower(tostring(text or ""))
		if string.find(text, "engine", 1, true) then return "Engine" end
		if string.find(text, "boost", 1, true) then return "Boost" end
		if string.find(text, "stabiliser", 1, true) or string.find(text, "stabilizer", 1, true) then return "Stabilisers" end
		if string.find(text, "front", 1, true) and string.find(text, "bumper", 1, true) then return "FrontBumper" end
		if string.find(text, "rear", 1, true) and string.find(text, "bumper", 1, true) then return "RearBumper" end
		if string.find(text, "spoiler", 1, true) then return "RearSpoiler" end
		if string.find(text, "side", 1, true) then return "SidePods" end
		return "Misc"
	end

	local function V56_moduleTypeForModel(module, root)
		if not module then return "Misc" end
		local attr = module:GetAttribute("ModuleType")
		if typeof(attr) == "string" and attr ~= "" then
			return attr
		end
		local text = module.Name
		local parent = module.Parent
		while parent and parent ~= root do
			text ..= " " .. parent.Name
			parent = parent.Parent
		end
		return V56_moduleTypeFromText(text)
	end
]=]

	source = insertBefore(source, moduleTypeAnchor, moduleTypeBlock, "Phase 17 module type helpers")
	changed = true
	info("Installed module-type helpers before their first use.")
else
	info("PASS: module-type helpers already exist before first use.")
end

local attachAt = findPlain(source, attachHeader)
assert(attachAt, "Could not find V85 attach helper header.")

local defaultDefinition = findPlain(source, "local function V76_defaultModuleIdsForCockpit(cockpit)")
if not defaultDefinition or defaultDefinition > attachAt then
	local defaultBlock = [=[

	-- NTR_PERSISTENCE_PHASE17_STARTUP_DEPENDENCY_REPAIR_DEFAULT_MODULES
	local function V76_defaultModuleIdsForCockpit(cockpit)
		if not cockpit then return {} end
		return {
			Engine = V56_string(cockpit, "DefaultEngineModuleId", nil),
			RearEngine = V56_string(cockpit, "DefaultRearEngineModuleId", V56_string(cockpit, "DefaultEngineBModuleId", nil)),
			Stabilisers = V56_string(cockpit, "DefaultStabilisersModuleId", V56_string(cockpit, "DefaultStabiliserModuleId", nil)),
			Boost = V56_string(cockpit, "DefaultBoostModuleId", nil),
		}
	end

	local function V76_grantDefaultModulesForCurrentCockpit(profile)
		if not profile then return end
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local defaults = V76_defaultModuleIdsForCockpit(cockpit)
		profile.OwnedModules = typeof(profile.OwnedModules) == "table" and profile.OwnedModules or {}
		profile.InstalledModules = typeof(profile.InstalledModules) == "table" and profile.InstalledModules or {}
		for _, moduleId in pairs(defaults) do
			if moduleId and moduleId ~= "" and V56_findModule(profile.CurrentCategory, moduleId) then
				profile.OwnedModules[moduleId] = true
			end
		end
		if defaults.Engine and defaults.Engine ~= "" then
			profile.InstalledModules.Engine1 = profile.InstalledModules.Engine1 or defaults.Engine
		end
		if defaults.RearEngine and defaults.RearEngine ~= "" then
			profile.InstalledModules.Engine2 = profile.InstalledModules.Engine2 or defaults.RearEngine
		elseif defaults.Engine and defaults.Engine ~= "" then
			profile.InstalledModules.Engine2 = profile.InstalledModules.Engine2 or defaults.Engine
		end
		if defaults.Stabilisers and defaults.Stabilisers ~= "" then
			profile.InstalledModules.Stabilisers = profile.InstalledModules.Stabilisers or defaults.Stabilisers
		end
		if defaults.Boost and defaults.Boost ~= "" then
			profile.InstalledModules.Boost = profile.InstalledModules.Boost or defaults.Boost
		end
	end

	local function V76_coreModulesEquipped(profile)
		local hasEngine, hasStabilisers, hasBoost = false, false, false
		for _, moduleId in pairs((profile and profile.InstalledModules) or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			local moduleType = module and module:GetAttribute("ModuleType")
			if moduleType == nil or moduleType == "" then
				local text = string.lower(tostring(moduleId or "") .. " " .. tostring(module and module.Name or ""))
				if string.find(text, "engine", 1, true) then
					moduleType = "Engine"
				elseif string.find(text, "stabiliser", 1, true) or string.find(text, "stabilizer", 1, true) then
					moduleType = "Stabilisers"
				elseif string.find(text, "boost", 1, true) then
					moduleType = "Boost"
				end
			end
			if moduleType == "Engine" then hasEngine = true end
			if moduleType == "Stabilisers" or moduleType == "Stabiliser" then hasStabilisers = true end
			if moduleType == "Boost" then hasBoost = true end
		end
		return hasEngine and hasStabilisers and hasBoost
	end
]=]

	source = string.sub(source, 1, attachAt - 1) .. defaultBlock .. string.sub(source, attachAt)
	changed = true
	info("Installed default/core module helpers before V85 attach and GetInitial.")
else
	info("PASS: default/core module helpers already exist before V85 attach.")
end

local finalAttachAt = findPlain(source, attachHeader)
assert(finalAttachAt, "V85 attach helper missing after default helper repair.")

local foundationMarker = "-- NTR_PERSISTENCE_PHASE17_V84_FOUNDATION_REPAIR"
local foundationAt = findPlain(source, foundationMarker)
local generateAt = findPlain(source, "local function V84_generateId(prefix)")
if not generateAt or generateAt > finalAttachAt then
	local foundationBlock = [=[

	-- NTR_PERSISTENCE_PHASE17_V84_FOUNDATION_REPAIR
	local V84_HttpService = game:GetService("HttpService")

	local function V84_generateId(prefix)
		local guid = string.gsub(V84_HttpService:GenerateGUID(false), "-", "")
		return tostring(prefix or "id") .. "_" .. string.sub(guid, 1, 12)
	end

	local function V84_countDictionary(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function V84_cloneDictionary(dictionary)
		local copy = {}
		for key, value in pairs(dictionary or {}) do
			if typeof(value) == "table" then
				copy[key] = V84_cloneDictionary(value)
			else
				copy[key] = value
			end
		end
		return copy
	end

	local function V84_nextDisplaySpaceKey(profile)
		profile.GarageDisplaySpaces = typeof(profile.GarageDisplaySpaces) == "table" and profile.GarageDisplaySpaces or {}
		local capacity = V82_profileGarageCapacity(profile)
		for index = 1, math.max(1, capacity) do
			local key = "Space" .. tostring(index)
			local space = profile.GarageDisplaySpaces[key]
			if typeof(space) ~= "table" or space.VehicleId == nil then
				profile.GarageDisplaySpaces[key] = typeof(space) == "table" and space or {}
				return key
			end
		end
		return "Space" .. tostring(V84_countDictionary(profile.GarageDisplaySpaces) + 1)
	end

	local function V84_assignDisplaySpace(profile, vehicleId)
		local key = V84_nextDisplaySpaceKey(profile)
		profile.GarageDisplaySpaces[key] = profile.GarageDisplaySpaces[key] or {}
		profile.GarageDisplaySpaces[key].VehicleId = vehicleId
	end

	local function V84_createVehicleInstance(profile, cockpitId, sourceName)
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		local cockpitInstanceId = V84_generateId("cockpit")
		local vehicleId = V84_generateId("vehicle")
		profile.OwnedCockpitInstances[cockpitInstanceId] = {
			TemplateId = cockpitId,
			VehicleId = vehicleId,
			AcquiredAtUnix = os.time(),
			Source = sourceName or "PersistencePhase14",
		}
		profile.Vehicles[vehicleId] = {
			DisplayName = tostring(cockpitId),
			CategoryId = profile.CurrentCategory or "bruiser",
			CockpitInstanceId = cockpitInstanceId,
			InstalledModules = {},
			CockpitColors = V84_cloneDictionary(profile.CockpitColors or {}),
			ThrustColor = profile.ThrustColor,
			Source = sourceName or "PersistencePhase14",
		}
		V84_assignDisplaySpace(profile, vehicleId)
		return vehicleId, cockpitInstanceId
	end

	local function V84_ensureInstanceInventory(profile)
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
		profile.GarageDisplaySpaces = typeof(profile.GarageDisplaySpaces) == "table" and profile.GarageDisplaySpaces or {}
		profile.OwnedCockpits = typeof(profile.OwnedCockpits) == "table" and profile.OwnedCockpits or {}
		profile.OwnedModules = typeof(profile.OwnedModules) == "table" and profile.OwnedModules or {}
		profile.InstalledModules = typeof(profile.InstalledModules) == "table" and profile.InstalledModules or {}
		profile.ModuleUpgradeLevels = typeof(profile.ModuleUpgradeLevels) == "table" and profile.ModuleUpgradeLevels or {}
		profile.ModuleColors = typeof(profile.ModuleColors) == "table" and profile.ModuleColors or {}
		profile.NeonOwned = typeof(profile.NeonOwned) == "table" and profile.NeonOwned or {}

		if next(profile.Vehicles) == nil then
			for cockpitId, owned in pairs(profile.OwnedCockpits) do
				if owned == true then
					local oldCurrent = profile.CurrentCockpit
					profile.CurrentCockpit = cockpitId
					local vehicleId = V84_createVehicleInstance(profile, cockpitId, "LegacyOwnedCockpits")
					profile.CurrentCockpit = oldCurrent
					if cockpitId == (profile.CurrentCockpit or "bruiser_01") then
						profile.CurrentVehicleId = vehicleId
					end
				end
			end
			if not profile.CurrentVehicleId then
				for vehicleId in pairs(profile.Vehicles) do
					profile.CurrentVehicleId = vehicleId
					break
				end
			end
		end

		local currentVehicle = profile.CurrentVehicleId and profile.Vehicles[profile.CurrentVehicleId] or nil
		if currentVehicle then
			currentVehicle.InstalledModules = typeof(currentVehicle.InstalledModules) == "table" and currentVehicle.InstalledModules or {}
			for slotId, moduleId in pairs(profile.InstalledModules) do
				local existingInstanceId = currentVehicle.InstalledModules[slotId]
				local existingInstance = existingInstanceId and profile.OwnedModuleInstances[existingInstanceId]
				if not existingInstance or existingInstance.TemplateId ~= moduleId then
					local moduleInstanceId = V84_generateId("module")
					profile.OwnedModuleInstances[moduleInstanceId] = {
						TemplateId = moduleId,
						EquippedVehicleId = profile.CurrentVehicleId,
						UpgradeLevels = V84_cloneDictionary((profile.ModuleUpgradeLevels or {})[moduleId] or {}),
						Colors = V84_cloneDictionary((profile.ModuleColors or {})[slotId] or {}),
						NeonOwned = profile.NeonOwned and profile.NeonOwned[slotId] == true or false,
						Source = "LegacyInstalledModules",
					}
					currentVehicle.InstalledModules[slotId] = moduleInstanceId
				end
			end
		end

		for moduleId, owned in pairs(profile.OwnedModules) do
			if owned == true then
				local found = false
				for _, moduleInstance in pairs(profile.OwnedModuleInstances) do
					if moduleInstance.TemplateId == moduleId then
						found = true
						break
					end
				end
				if not found then
					profile.OwnedModuleInstances[V84_generateId("module")] = {
						TemplateId = moduleId,
						EquippedVehicleId = nil,
						UpgradeLevels = V84_cloneDictionary((profile.ModuleUpgradeLevels or {})[moduleId] or {}),
						Colors = {},
						NeonOwned = false,
						Source = "LegacyOwnedModules",
					}
				end
			end
		end
	end
]=]

	source = string.sub(source, 1, finalAttachAt - 1) .. foundationBlock .. string.sub(source, finalAttachAt)
	changed = true
	info("Installed V84 instance-inventory foundation before V85 attach.")
else
	info("PASS: V84 foundation already exists before V85 attach.")
end

if not findPlain(source, "local function V56_totalStats(profile)") then
	local totalStatsHelper = [=[

	-- NTR_PERSISTENCE_PHASE17_TOTAL_STATS_REPAIR
	local function V56_totalStats(profile)
		V56_normalizeProfile(profile)
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = V56_number(cockpit, "TopSpeed", V56_number(cockpit, "MaxSpeed", 126)),
			Acceleration = V56_number(cockpit, "Acceleration", 42),
			Handling = V56_number(cockpit, "Handling", 48),
			Drift = V56_number(cockpit, "Drift", 46),
			Braking = V56_number(cockpit, "Braking", 44),
			Weight = V56_number(cockpit, "Weight", 118),
			Boost = V56_number(cockpit, "Boost", 0),
			BoostDuration = V56_number(cockpit, "BoostDuration", 2),
			BoostRecharge = V56_number(cockpit, "BoostRecharge", 9),
			BoostRechargeDelay = V56_number(cockpit, "BoostRechargeDelay", 0),
		}
		local statNames = {
			"TopSpeed",
			"Acceleration",
			"Handling",
			"Drift",
			"Braking",
			"Weight",
			"Boost",
			"BoostDuration",
			"BoostRecharge",
			"BoostRechargeDelay",
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			if module then
				for _, stat in ipairs(statNames) do
					totals[stat] = (totals[stat] or 0) + V56_number(module, stat, 0)
				end
			end
		end
		local category = V56_categoryFolder(profile.CurrentCategory)
		local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
		if upgradeRoot then
			for upgradeId, level in pairs(profile.UpgradeLevels or {}) do
				local upgrade = upgradeRoot:FindFirstChild("UPGRADE_" .. tostring(upgradeId))
				if upgrade then
					local statName = V56_string(upgrade, "StatName", V56_string(upgrade, "Stat", nil))
					local amount = V56_number(upgrade, "AmountPerLevel", V56_number(upgrade, "Amount", 0))
					if statName then
						totals[statName] = (totals[statName] or 0) + amount * (tonumber(level) or 0)
					end
				end
			end
		end
		return totals
	end
]=]

	source = insertBefore(source, "\n\tlocal function V56_profileForClient(profile)\n", totalStatsHelper, "Phase 17 total stats helper")
	changed = true
	info("Installed V56_totalStats before V56_profileForClient.")
end

if not findPlain(source, "local function V56_catalog()") then
	local catalogBlock = [=[

	-- NTR_PERSISTENCE_PHASE17_CATALOG_REPAIR
	local function V56_defaultSlots(cockpit)
		local slots = {}
		local root = cockpit and cockpit:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
		if root then
			for _, slot in ipairs(root:GetChildren()) do
				if slot:IsA("Folder") or slot:IsA("Model") or slot:IsA("BasePart") then
					local slotId = string.gsub(slot.Name, "^SLOT_", "")
					table.insert(slots, {
						SlotId = V56_string(slot, "SlotId", slotId),
						DisplayName = V56_string(slot, "DisplayName", slotId),
						ModuleType = V56_string(slot, "ModuleType", V56_moduleTypeFromText(slotId)),
						AllowedModuleFolder = V56_string(slot, "AllowedModuleFolder", ""),
						EnginePosition = V56_string(slot, "EnginePosition", ""),
						Order = V56_number(slot, "Order", #slots + 1),
					})
				end
			end
		end
		if #slots == 0 then
			slots = {
				{ SlotId = "Engine1", DisplayName = "Front Engine", ModuleType = "Engine", AllowedModuleFolder = "Engines", EnginePosition = "Front", Order = 1 },
				{ SlotId = "Engine2", DisplayName = "Rear Engine", ModuleType = "Engine", AllowedModuleFolder = "Engines_B", EnginePosition = "Rear", Order = 2 },
				{ SlotId = "Stabilisers", DisplayName = "Stabilisers", ModuleType = "Stabilisers", Order = 3 },
				{ SlotId = "Boost", DisplayName = "Boost", ModuleType = "Boost", Order = 4 },
				{ SlotId = "FrontBumper", DisplayName = "Front Bumper", ModuleType = "FrontBumper", Order = 5 },
				{ SlotId = "RearBumper", DisplayName = "Rear Bumper", ModuleType = "RearBumper", Order = 6 },
				{ SlotId = "RearSpoiler", DisplayName = "Rear Spoiler", ModuleType = "RearSpoiler", Order = 7 },
				{ SlotId = "SidePods", DisplayName = "Side Pods", ModuleType = "SidePods", Order = 8 },
			}
		end
		table.sort(slots, function(a, b)
			return (tonumber(a.Order) or 99) < (tonumber(b.Order) or 99)
		end)
		return slots
	end

	local function V56_nearestModuleFolder(root, item)
		local current = item and item.Parent
		local best = ""
		while current and current ~= root do
			if current:IsA("Folder") then
				best = current.Name
			end
			current = current.Parent
		end
		return best
	end

	local function V56_moduleCatalogVisible(item)
		if item:GetAttribute("RetiredFromCatalog") == true then
			return false
		end
		if item:GetAttribute("HiddenFromCatalog") == true then
			return false
		end
		if item:GetAttribute("CatalogVisible") == false then
			return false
		end
		return true
	end

	local function V56_readModule(item, root)
		local moduleType = V56_moduleTypeForModel(item, root)
		local moduleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item))
		local enginePosition = V56_string(item, "EnginePosition", "")
		local rearEngine = item:GetAttribute("RearEngine") == true
		if enginePosition == "" then
			if rearEngine or moduleFolder == "Engines_B" or string.find(tostring(item:GetAttribute("ModuleId") or item.Name or ""), "ENGINE_B", 1, true) then
				enginePosition = "Rear"
			elseif moduleFolder == "Engines" then
				enginePosition = "Front"
			end
		end
		local sourceCockpit = select(2, V85_findSourceCockpit(nil, item))
		local sourceCockpitId = V85_moduleSourceCockpitId(item)
		return {
			ModuleId = V56_string(item, "ModuleId", item.Name),
			DisplayName = V56_string(item, "DisplayName", V56_string(item, "ModuleName", item.Name)),
			ModuleType = moduleType,
			ModuleSlot = V56_string(item, "ModuleSlot", moduleType),
			ModuleFolder = moduleFolder,
			EnginePosition = enginePosition,
			RearEngine = rearEngine or enginePosition == "Rear",
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
			BoostRechargeDelay = V56_number(item, "BoostRechargeDelay", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType),
		}
	end

	local function V56_catalog()
		local catalog = {
			Categories = {},
			PaintPresets = {},
			PreviewPosition = V56_PREVIEW_POS,
		}
		local presetRoot = V56_kit:FindFirstChild("Config")
			and V56_kit.Config:FindFirstChild("UI")
			and V56_kit.Config.UI:FindFirstChild("PaintPresets")
		if presetRoot then
			for _, preset in ipairs(presetRoot:GetChildren()) do
				if preset:IsA("Color3Value") then
					table.insert(catalog.PaintPresets, { Name = preset.Name, Color = preset.Value })
				end
			end
		end
		if #catalog.PaintPresets == 0 then
			catalog.PaintPresets = {
				{ Name = "Cyan", Color = Color3.fromRGB(0, 205, 230) },
				{ Name = "White", Color = Color3.fromRGB(252, 250, 255) },
				{ Name = "Graphite", Color = Color3.fromRGB(38, 44, 50) },
				{ Name = "Lime", Color = Color3.fromRGB(172, 255, 197) },
				{ Name = "Red", Color = Color3.fromRGB(225, 56, 70) },
				{ Name = "Amber", Color = Color3.fromRGB(255, 187, 45) },
				{ Name = "Violet", Color = Color3.fromRGB(160, 90, 255) },
				{ Name = "Bone", Color = Color3.fromRGB(235, 247, 204) },
			}
		end

		for _, categoryFolder in ipairs(V56_categoriesRoot:GetChildren()) do
			if categoryFolder:IsA("Folder") or categoryFolder:IsA("Model") then
				local category = V56_primitiveAttributes(categoryFolder)
				category.CategoryId = category.CategoryId or V56_slug(categoryFolder.Name)
				category.DisplayName = category.DisplayName or categoryFolder.Name
				category.Cockpits = {}
				category.Slots = {}
				category.Modules = {}
				category.Upgrades = {}

				local cockpitRoot = categoryFolder:FindFirstChild("COCKPITS_ReplaceAssetsHere") or categoryFolder:FindFirstChild("Cockpits") or categoryFolder:FindFirstChild("COCKPITS")
				local firstCockpit
				if cockpitRoot then
					for _, cockpit in ipairs(cockpitRoot:GetDescendants()) do
						if cockpit:IsA("Model") and cockpit:GetAttribute("CockpitId") then
							firstCockpit = firstCockpit or cockpit
							local item = V56_primitiveAttributes(cockpit)
							item.CockpitId = item.CockpitId or cockpit.Name
							item.DisplayName = item.DisplayName or cockpit.Name
							item.Price = V56_number(cockpit, "Price", 0)
							item.TopSpeed = V56_number(cockpit, "TopSpeed", V56_number(cockpit, "MaxSpeed", 126))
							item.Acceleration = V56_number(cockpit, "Acceleration", 42)
							item.Handling = V56_number(cockpit, "Handling", 48)
							item.Drift = V56_number(cockpit, "Drift", 46)
							item.Braking = V56_number(cockpit, "Braking", 44)
							item.Weight = V56_number(cockpit, "Weight", 118)
							item.Boost = V56_number(cockpit, "Boost", 0)
							table.insert(category.Cockpits, item)
						end
					end
				end
				category.Slots = V56_defaultSlots(firstCockpit)

				local moduleRoot = categoryFolder:FindFirstChild("MODULES_InterchangeableWithinCategory")
				if moduleRoot then
					for _, module in ipairs(moduleRoot:GetDescendants()) do
						if module:IsA("Model") and module:GetAttribute("ModuleId") and V56_moduleCatalogVisible(module) then
							local item = V56_readModule(module, moduleRoot)
							category.Modules[item.ModuleType] = category.Modules[item.ModuleType] or {}
							table.insert(category.Modules[item.ModuleType], item)
						end
					end
				end
				local upgradeRoot = categoryFolder:FindFirstChild("UPGRADES_InvisiblePerformance")
				if upgradeRoot then
					for _, upgrade in ipairs(upgradeRoot:GetChildren()) do
						table.insert(category.Upgrades, V56_primitiveAttributes(upgrade))
					end
				end
				table.sort(category.Cockpits, function(a, b)
					return tostring(a.DisplayName) < tostring(b.DisplayName)
				end)
				if #category.Cockpits > 0 then
					table.insert(catalog.Categories, category)
				end
			end
		end
		table.sort(catalog.Categories, function(a, b)
			return tostring(a.DisplayName) < tostring(b.DisplayName)
		end)
		return catalog
	end
]=]

	local catalogAnchor = "\n\tlocal function V56_totalStats(profile)\n"
	if not findPlain(source, catalogAnchor) then
		catalogAnchor = "\n\tlocal function V56_profileForClient(profile)\n"
	end
	source = insertBefore(source, catalogAnchor, catalogBlock, "Phase 17 catalog helper family")
	changed = true
	info("Installed V56_catalog helper family.")
end

garage.Source = source
garage:SetAttribute("PersistencePhase17StartupDependencyRepair", true)

local finalSource = garage.Source
local finalFirstModuleUse = firstPosition(finalSource, {
	"V56_moduleTypeFromText(slotId)",
	"V56_moduleTypeForModel(module)",
	"V56_moduleTypeForModel(item",
	"V56_moduleTypeForModel(moduleTemplate",
})
local finalModuleTypeAt = findPlain(finalSource, "local function V56_moduleTypeFromText(text)")
local finalDefaultAt = findPlain(finalSource, "local function V76_defaultModuleIdsForCockpit(cockpit)")
local finalGenerateAt = findPlain(finalSource, "local function V84_generateId(prefix)")
local finalAttachAt2 = findPlain(finalSource, attachHeader)
local finalProfileAt = findPlain(finalSource, "local function V56_profileForClient(profile)")

local checks = {
	{ "V56_moduleTypeFromText before first module-type use", finalModuleTypeAt and finalFirstModuleUse and finalModuleTypeAt < finalFirstModuleUse },
	{ "V56_moduleTypeForModel", findPlain(finalSource, "local function V56_moduleTypeForModel(module, root)") },
	{ "V76_defaultModuleIdsForCockpit before V85 attach", finalDefaultAt and finalAttachAt2 and finalDefaultAt < finalAttachAt2 },
	{ "V76_grantDefaultModulesForCurrentCockpit", findPlain(finalSource, "local function V76_grantDefaultModulesForCurrentCockpit(profile)") },
	{ "V76_coreModulesEquipped", findPlain(finalSource, "local function V76_coreModulesEquipped(profile)") },
	{ "V84_generateId before V85 attach", finalGenerateAt and finalAttachAt2 and finalGenerateAt < finalAttachAt2 },
	{ "V84_ensureInstanceInventory", findPlain(finalSource, "local function V84_ensureInstanceInventory(profile)") },
	{ "V85 attach helper", finalAttachAt2 },
	{ "V86 module slot guard", findPlain(finalSource, "local function V86_moduleFitsSlot") },
	{ "V56_catalog", findPlain(finalSource, "local function V56_catalog()") },
	{ "V56_totalStats before profile response", findPlain(finalSource, "local function V56_totalStats(profile)") and finalProfileAt and findPlain(finalSource, "local function V56_totalStats(profile)") < finalProfileAt },
	{ "V56_profileForClient", finalProfileAt },
	{ "GetInitial returns catalog/profile", findPlain(finalSource, "Catalog = V56_catalog(), Profile = V56_profileForClient(profile)") },
}

for _, check in ipairs(checks) do
	assert(check[2], "Post-repair audit failed: missing or late " .. check[1])
	info("PASS: " .. check[1])
end

local _, remainingDuplicateCount = string.gsub(
	finalSource,
	"V85_attachDefaultModuleInstancesToCurrentVehicle%s*=%s*function%(profile%)%s+V85_attachDefaultModuleInstancesToCurrentVehicle%s*=%s*function%(profile%)",
	attachHeader
)
assert(remainingDuplicateCount == 0, "Post-repair audit failed: duplicate V85 attach header still present.")

if changed then
	info("PASS: repaired garage server startup dependency chain.")
else
	info("PASS: garage server startup dependency chain already looked correct.")
end

info("Next: stop Play, start a fresh Play session, then rerun scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua from the CLIENT Command Bar.")
