-- Neo Tokyo Racers - Persistence Phase 14
-- Instance inventory bridge for duplicate cockpit/module ownership.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 13 is confirmed.
--
-- This phase deliberately keeps the existing dealership UI response shape while
-- adding instance-backed fields and server actions for future duplicate-copy UI:
-- - Vehicles
-- - CurrentVehicleId
-- - OwnedCockpitInstances
-- - OwnedModuleInstances
-- - BuyCockpitInstance
-- - BuyModuleInstance
-- - EquipModuleInstance
--
-- The active UI can still read legacy OwnedCockpits/OwnedModules/InstalledModules.
-- Future UI phases can switch to the instance fields after this bridge is tested.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 14"

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

local function insertAfter(source, anchor, insertion, label)
	if string.find(source, insertion, 1, true) then
		return source, false
	end
	local first = string.find(source, anchor, 1, true)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 14 patch.")
	end
	return string.sub(source, 1, first + #anchor - 1) .. insertion .. string.sub(source, first + #anchor), true
end

local function insertBefore(source, anchor, insertion, label)
	if string.find(source, insertion, 1, true) then
		return source, false
	end
	local first = string.find(source, anchor, 1, true)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 14 patch.")
	end
	return string.sub(source, 1, first - 1) .. insertion .. string.sub(source, first), true
end

local function ensureMirrorMutatingActions(source)
	local actions = {
		"BuyCockpitInstance",
		"BuyModuleInstance",
		"EquipModuleInstance",
	}
	local changed = false
	local tableStart = string.find(source, "local V80_mutatingActions = {", 1, true)
	if not tableStart then
		error("Could not find V80_mutatingActions table. Run Phase 4/13 before Phase 14.")
	end
	local tableEnd = string.find(source, "\n\t}", tableStart, true)
	if not tableEnd then
		error("Could not find the end of V80_mutatingActions table.")
	end
	for _, actionName in ipairs(actions) do
		if not string.find(source, actionName .. " = true", 1, true) then
			source = string.sub(source, 1, tableEnd - 1) .. "\t\t" .. actionName .. " = true,\n" .. string.sub(source, tableEnd)
			tableEnd += string.len("\t\t" .. actionName .. " = true,\n")
			changed = true
		end
	end
	return source, changed
end

local function patchLegacyMapper(dataModules)
	local mapper = waitPath(dataModules, "LegacyGarageProfileMapper")
	assert(mapper:IsA("ModuleScript"), "LegacyGarageProfileMapper must be a ModuleScript.")
	if string.find(mapper.Source, "NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY", 1, true) then
		info("LegacyGarageProfileMapper already has Phase 14 instance inventory support.")
		return
	end

	mapper.Source = [==[
-- Neo Tokyo Racers legacy garage profile mapper.
-- Persistence Phase 14. Converts current V56 session-memory profiles into
-- instance-based PlayerProfileSchema profiles, preserving live instance fields
-- when they already exist.

local LegacyGarageProfileMapper = {}

local function cloneValue(value)
	if typeof(value) == "table" then
		local copy = {}
		for key, child in pairs(value) do
			copy[key] = cloneValue(child)
		end
		return copy
	end
	return value
end

local function slug(value)
	value = string.lower(tostring(value or "item"))
	value = string.gsub(value, "%s+", "_")
	value = string.gsub(value, "[^%w_]", "")
	return value ~= "" and value or "item"
end

local function sortedKeys(dictionary)
	local keys = {}
	for key in pairs(dictionary or {}) do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	return keys
end

local function moveKeyToFront(keys, preferred)
	preferred = tostring(preferred or "")
	for index, key in ipairs(keys) do
		if key == preferred then
			table.remove(keys, index)
			table.insert(keys, 1, key)
			break
		end
	end
	return keys
end

local function countDictionary(dictionary)
	local count = 0
	for _ in pairs(dictionary or {}) do
		count += 1
	end
	return count
end

local function instanceId(prefix, templateId, index)
	return tostring(prefix) .. "_" .. slug(templateId) .. "_" .. string.format("%03d", index)
end

local function moduleInstanceId(slotId, moduleId, index)
	if slotId and slotId ~= "" then
		return "module_" .. slug(slotId) .. "_" .. slug(moduleId)
	end
	return instanceId("module", moduleId, index)
end

local function copyColors(colors)
	return typeof(colors) == "table" and cloneValue(colors) or {}
end

local function cockpitColorsFromLegacy(legacy)
	return copyColors(legacy and legacy.CockpitColors)
end

local function moduleUpgradeLevelsFor(legacy, moduleId)
	local allLevels = legacy and legacy.ModuleUpgradeLevels
	if typeof(allLevels) ~= "table" then
		return {}
	end
	local byModule = allLevels[moduleId]
	return typeof(byModule) == "table" and cloneValue(byModule) or {}
end

local function ensureDisplaySpaces(profile)
	profile.Garage.DisplaySpaces = typeof(profile.Garage.DisplaySpaces) == "table" and profile.Garage.DisplaySpaces or {}
	local index = 0
	for vehicleId in pairs(profile.Vehicles or {}) do
		index += 1
		local key = "Space" .. tostring(index)
		profile.Garage.DisplaySpaces[key] = typeof(profile.Garage.DisplaySpaces[key]) == "table" and profile.Garage.DisplaySpaces[key] or {}
		profile.Garage.DisplaySpaces[key].VehicleId = profile.Garage.DisplaySpaces[key].VehicleId or vehicleId
	end
end

local function copyLiveInstanceInventory(legacyProfile, profile)
	if typeof(legacyProfile.Vehicles) ~= "table"
		or typeof(legacyProfile.OwnedCockpitInstances) ~= "table"
		or typeof(legacyProfile.OwnedModuleInstances) ~= "table" then
		return false
	end

	-- NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY
	profile.Vehicles = cloneValue(legacyProfile.Vehicles)
	profile.OwnedCockpitInstances = cloneValue(legacyProfile.OwnedCockpitInstances)
	profile.OwnedModuleInstances = cloneValue(legacyProfile.OwnedModuleInstances)
	profile.CurrentVehicleId = legacyProfile.CurrentVehicleId ~= nil and tostring(legacyProfile.CurrentVehicleId) or profile.CurrentVehicleId
	if typeof(legacyProfile.Garage) == "table" then
		profile.Garage.DisplaySpaces = cloneValue(legacyProfile.Garage.DisplaySpaces or profile.Garage.DisplaySpaces)
	end
	if not profile.CurrentVehicleId then
		for vehicleId in pairs(profile.Vehicles) do
			profile.CurrentVehicleId = vehicleId
			break
		end
	end
	ensureDisplaySpaces(profile)
	return true
end

function LegacyGarageProfileMapper.Convert(legacyProfile, schema, options)
	assert(typeof(schema) == "table" and typeof(schema.DefaultProfile) == "function", "PlayerProfileSchema module is required")
	options = typeof(options) == "table" and options or {}
	legacyProfile = typeof(legacyProfile) == "table" and legacyProfile or {}

	local profile = schema.DefaultProfile(legacyProfile.Cash)
	profile.Cash = typeof(legacyProfile.Cash) == "number" and legacyProfile.Cash or profile.Cash
	profile.LegacyMigration = {
		Source = "PersistencePhase14_LegacyGarageProfileMapper",
		MigratedAtUnix = os.time(),
		LegacyCurrentCategory = legacyProfile.CurrentCategory,
		LegacyCurrentCockpit = legacyProfile.CurrentCockpit,
		Notes = {},
	}
	profile.Garage.OwnedGarageProperties = cloneValue(legacyProfile.OwnedGarageProperties or legacyProfile.GarageProperties or {})

	local copiedLiveInstances = copyLiveInstanceInventory(legacyProfile, profile)

	local ownedCockpits = typeof(legacyProfile.OwnedCockpits) == "table" and legacyProfile.OwnedCockpits or {}
	if next(ownedCockpits) == nil then
		ownedCockpits[legacyProfile.CurrentCockpit or "bruiser_01"] = true
	end

	local cockpitIds = sortedKeys(ownedCockpits)
	moveKeyToFront(cockpitIds, legacyProfile.CurrentCockpit or "bruiser_01")

	local preserveLegacyCapacity = options.PreserveLegacyCapacity ~= false
	if preserveLegacyCapacity then
		local legacyCapacity = tonumber(legacyProfile.GarageCapacity)
		profile.Garage.Capacity = math.max(profile.Garage.Capacity or 2, #cockpitIds, legacyCapacity or 0, countDictionary(profile.Vehicles))
	else
		profile.Garage.Capacity = tonumber(options.Capacity) or profile.Garage.Capacity or 2
	end

	if not copiedLiveInstances then
		local vehicleIndex = 0
		for _, cockpitId in ipairs(cockpitIds) do
			if ownedCockpits[cockpitId] == true then
				vehicleIndex += 1
				local cockpitInstanceId = instanceId("cockpit", cockpitId, vehicleIndex)
				local vehicleId = instanceId("vehicle", cockpitId, vehicleIndex)
				profile.OwnedCockpitInstances[cockpitInstanceId] = {
					TemplateId = cockpitId,
					VehicleId = vehicleId,
					AcquiredAtUnix = 0,
					Source = "LegacyOwnedCockpits",
				}
				profile.Vehicles[vehicleId] = {
					DisplayName = tostring(cockpitId),
					CategoryId = legacyProfile.CurrentCategory or "bruiser",
					CockpitInstanceId = cockpitInstanceId,
					InstalledModules = {},
					CockpitColors = cockpitColorsFromLegacy(legacyProfile),
					ThrustColor = legacyProfile.ThrustColor,
					Source = "LegacyOwnedCockpits",
				}
				if cockpitId == (legacyProfile.CurrentCockpit or "bruiser_01") then
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

		local currentVehicle = profile.CurrentVehicleId and profile.Vehicles[profile.CurrentVehicleId] or nil
		local installedModules = typeof(legacyProfile.InstalledModules) == "table" and legacyProfile.InstalledModules or {}
		local moduleIndex = 0
		local createdByTemplate = {}
		for _, slotId in ipairs(sortedKeys(installedModules)) do
			local moduleId = installedModules[slotId]
			if typeof(moduleId) == "string" and moduleId ~= "" then
				moduleIndex += 1
				local id = moduleInstanceId(slotId, moduleId, moduleIndex)
				profile.OwnedModuleInstances[id] = {
					TemplateId = moduleId,
					EquippedVehicleId = profile.CurrentVehicleId,
					UpgradeLevels = moduleUpgradeLevelsFor(legacyProfile, moduleId),
					Colors = copyColors(legacyProfile.ModuleColors and legacyProfile.ModuleColors[slotId]),
					NeonOwned = legacyProfile.NeonOwned and legacyProfile.NeonOwned[slotId] == true or false,
					Source = "LegacyInstalledModules",
				}
				if currentVehicle then
					currentVehicle.InstalledModules[slotId] = id
				end
				createdByTemplate[moduleId] = createdByTemplate[moduleId] or id
			end
		end

		local ownedModules = typeof(legacyProfile.OwnedModules) == "table" and legacyProfile.OwnedModules or {}
		for _, moduleId in ipairs(sortedKeys(ownedModules)) do
			if ownedModules[moduleId] == true and not createdByTemplate[moduleId] then
				moduleIndex += 1
				local id = moduleInstanceId(nil, moduleId, moduleIndex)
				profile.OwnedModuleInstances[id] = {
					TemplateId = moduleId,
					EquippedVehicleId = nil,
					UpgradeLevels = moduleUpgradeLevelsFor(legacyProfile, moduleId),
					Colors = {},
					NeonOwned = false,
					Source = "LegacyOwnedModules",
				}
				createdByTemplate[moduleId] = id
			end
		end
		ensureDisplaySpaces(profile)
	else
		table.insert(profile.LegacyMigration.Notes, "Live instance inventory copied directly from the Phase 14 garage profile fields.")
	end

	profile.LegacyMigration.LegacyVehicleCount = countDictionary(profile.Vehicles)
	profile.LegacyMigration.LegacyModuleInstanceCount = countDictionary(profile.OwnedModuleInstances)
	table.insert(profile.LegacyMigration.Notes, "Boolean legacy ownership remains for current UI compatibility; instance fields are the future duplicate-copy source.")

	return schema.Normalize(profile)
end

function LegacyGarageProfileMapper.SummarizeConversion(legacyProfile, schema, options)
	local profile = LegacyGarageProfileMapper.Convert(legacyProfile, schema, options)
	local summary = schema.Summarize(profile)
	summary.CurrentVehicleId = profile.CurrentVehicleId
	return summary
end

return LegacyGarageProfileMapper
]==]

	mapper:SetAttribute("PersistencePhase14InstanceInventory", true)
	info("Patched LegacyGarageProfileMapper to preserve live instance inventory fields.")
end

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local dataModules = waitPath(ntr, "Shared", "Modules", "Data")
patchLegacyMapper(dataModules)

local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")
assert(garage:IsA("Script"), "GarageActionController_Shadow_Disabled must be a Script.")

local source = garage.Source
assert(string.find(source, "NTR_PERSISTENCE_PHASE13_GARAGE_PROPERTIES", 1, true), "Run and verify Persistence Phase 13 before Phase 14.")

local changed = false
local didChange

source, didChange = insertAfter(source, [[			OwnedGarageProperties = {},
]], [[			-- NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY
			CurrentVehicleId = nil,
			Vehicles = {},
			OwnedCockpitInstances = {},
			OwnedModuleInstances = {},
]], "garage default instance inventory")
changed = changed or didChange

source, didChange = insertAfter(source, [[		profile.OwnedGarageProperties = typeof(profile.OwnedGarageProperties) == "table" and profile.OwnedGarageProperties or {}
]], [[		-- NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
		profile.CurrentVehicleId = profile.CurrentVehicleId ~= nil and tostring(profile.CurrentVehicleId) or nil
]], "garage normalize instance inventory")
changed = changed or didChange

source, didChange = ensureMirrorMutatingActions(source)
changed = changed or didChange

local helperBlock = [=[
	-- NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY_HELPERS
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
		profile.GarageDisplaySpaces = profile.GarageDisplaySpaces or {}
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

		if next(profile.Vehicles) == nil then
			for cockpitId, owned in pairs(profile.OwnedCockpits or {}) do
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
			for slotId, moduleId in pairs(profile.InstalledModules or {}) do
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

		for moduleId, owned in pairs(profile.OwnedModules or {}) do
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

	local function V84_buyCockpitInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		local cockpitId = tostring(args.CockpitId or "")
		local cockpit = V56_findCockpit(profile.CurrentCategory, cockpitId)
		if not cockpit then
			return false, "Cockpit not found."
		end
		V84_ensureInstanceInventory(profile)
		if V84_countDictionary(profile.Vehicles) >= V82_profileGarageCapacity(profile) then
			return false, "Garage full. Buy more garage space to store more vehicles."
		end
		local price = V56_number(cockpit, "Price", 0)
		if profile.Cash < price then
			return false, "Not enough cash."
		end
		profile.Cash -= price
		profile.CurrentCockpit = cockpitId
		profile.OwnedCockpits[cockpitId] = true
		V76_applyDefaultCockpitColors(profile)
		local vehicleId = V84_createVehicleInstance(profile, cockpitId, "BuyCockpitInstance")
		profile.CurrentVehicleId = vehicleId
		V76_grantDefaultModulesForCurrentCockpit(profile)
		V84_ensureInstanceInventory(profile)
		return true, "Cockpit instance purchased."
	end

	local function V84_buyModuleInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		local moduleId = tostring(args.ModuleId or "")
		local module = V56_findModule(profile.CurrentCategory, moduleId)
		if not module then
			return false, "Module not found."
		end
		local price = V56_number(module, "Price", 0)
		if profile.Cash < price then
			return false, "Not enough cash."
		end
		profile.Cash -= price
		profile.OwnedModules[moduleId] = true
		local moduleInstanceId = V84_generateId("module")
		profile.OwnedModuleInstances[moduleInstanceId] = {
			TemplateId = moduleId,
			EquippedVehicleId = nil,
			UpgradeLevels = V84_cloneDictionary((profile.ModuleUpgradeLevels or {})[moduleId] or {}),
			Colors = {},
			NeonOwned = false,
			Source = "BuyModuleInstance",
		}
		return true, "Module instance purchased.", moduleInstanceId
	end

	local function V84_equipModuleInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		V84_ensureInstanceInventory(profile)
		local moduleInstanceId = tostring(args.ModuleInstanceId or "")
		local vehicleId = tostring(args.VehicleId or profile.CurrentVehicleId or "")
		local slotId = tostring(args.SlotId or "")
		local moduleInstance = profile.OwnedModuleInstances[moduleInstanceId]
		local vehicle = profile.Vehicles[vehicleId]
		if not moduleInstance then
			return false, "Module instance not found."
		end
		if not vehicle then
			return false, "Vehicle instance not found."
		end
		if moduleInstance.EquippedVehicleId ~= nil and moduleInstance.EquippedVehicleId ~= vehicleId then
			return false, "That module copy is already installed on another vehicle."
		end
		local module = V56_findModule(profile.CurrentCategory, tostring(moduleInstance.TemplateId or ""))
		local cockpitInstance = profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local cockpit = cockpitInstance and V56_findCockpit(vehicle.CategoryId or profile.CurrentCategory, cockpitInstance.TemplateId)
		local mount = cockpit and cockpit:FindFirstChild("SLOT_" .. slotId, true)
		local slotType = mount and V56_string(mount, "ModuleType", V56_moduleTypeFromText(slotId))
		local moduleType = V56_moduleTypeForModel(module)
		if not module then
			return false, "Module template not found."
		end
		if not mount then
			return false, "Slot not found on this cockpit."
		end
		if slotType and slotType ~= "" and moduleType ~= slotType then
			return false, "That module does not fit this slot."
		end

		vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}
		local previousInstanceId = vehicle.InstalledModules[slotId]
		if previousInstanceId and profile.OwnedModuleInstances[previousInstanceId] then
			profile.OwnedModuleInstances[previousInstanceId].EquippedVehicleId = nil
		end
		vehicle.InstalledModules[slotId] = moduleInstanceId
		moduleInstance.EquippedVehicleId = vehicleId
		moduleInstance.Colors = typeof(moduleInstance.Colors) == "table" and moduleInstance.Colors or {}
		if vehicleId == profile.CurrentVehicleId then
			profile.InstalledModules[slotId] = moduleInstance.TemplateId
			profile.ModuleColors[slotId] = moduleInstance.Colors
		end
		return true, "Module instance equipped."
	end

]=]

source, didChange = insertBefore(source, "\n\tlocal function V56_profileForClient(profile)", helperBlock, "Phase 14 helper block")
changed = changed or didChange

source, didChange = insertAfter(source, [[			V76_grantDefaultModulesForCurrentCockpit(profile)
]], [[			V84_ensureInstanceInventory(profile)
]], "Phase 14 action-start inventory ensure")
changed = changed or didChange

source, didChange = insertAfter(source, [[			CurrentCockpit = profile.CurrentCockpit,
]], [[			CurrentVehicleId = profile.CurrentVehicleId,
			Vehicles = profile.Vehicles,
			OwnedCockpitInstances = profile.OwnedCockpitInstances,
			OwnedModuleInstances = profile.OwnedModuleInstances,
]], "Phase 14 client profile instance fields")
changed = changed or didChange

local actionBranch = [=[			elseif action == "BuyCockpitInstance" then
				ok, message = V84_buyCockpitInstance(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyModuleInstance" then
				ok, message = V84_buyModuleInstance(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "EquipModuleInstance" then
				ok, message = V84_equipModuleInstance(profile, args)
				V56_setLeaderstats(player, profile)
]=]

source, didChange = insertBefore(source, [[			elseif action == "BuyGarageProperty" then
]], actionBranch, "Phase 14 instance action branches")
changed = changed or didChange

garage.Source = source
garage:SetAttribute("PersistencePhase14InstanceInventoryBridge", true)

assert(string.find(garage.Source, "function V84_buyCockpitInstance", 1, true), "Phase 14 cockpit instance action was not installed.")
assert(string.find(garage.Source, "BuyCockpitInstance = true", 1, true), "Phase 14 mirror mutating action was not installed.")
assert(string.find(garage.Source, "OwnedCockpitInstances = profile.OwnedCockpitInstances", 1, true), "Phase 14 client profile fields were not exposed.")

if changed then
	info("PASS: installed Phase 14 instance inventory bridge.")
else
	info("PASS: Phase 14 instance inventory bridge was already installed.")
end
info("Next: enter Play mode and run scripts/roblox_persistence_phase14_instance_inventory_client_smoke.lua from the CLIENT Command Bar.")
