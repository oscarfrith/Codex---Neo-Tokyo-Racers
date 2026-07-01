-- Neo Tokyo Racers - Persistence Phase 3
-- Installs a legacy garage profile mapper/bridge for converting today's V56 session profile
-- shape into the new instance-based PlayerProfileSchema shape.
--
-- Safe bridge-prep phase:
-- - Does not patch GarageActionController_Shadow_Disabled.
-- - Does not switch the active garage profile source of truth.
-- - Does not write DataStores.
-- - Creates conversion tools so the next phase can bridge live garage actions with much less risk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 3"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureModule(parent, name, source)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("ModuleScript") then
		error(item:GetFullName() .. " must be a ModuleScript")
	end
	if not item then
		item = Instance.new("ModuleScript")
		item.Name = name
		item.Parent = parent
	end
	item.Source = source
	return item
end

local function ensureScript(parent, name, source)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Script") then
		error(item:GetFullName() .. " must be a Script")
	end
	if not item then
		item = Instance.new("Script")
		item.Name = name
		item.Parent = parent
	end
	item.Source = source
	item.Disabled = false
	return item
end

local mapperSource = [==[
-- Neo Tokyo Racers legacy garage profile mapper.
-- Persistence Phase 3. Converts current V56 session-memory profiles into
-- instance-based PlayerProfileSchema profiles.

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
	if value == "" then
		return "item"
	end
	return value
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
	if preferred == "" then
		return keys
	end
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
	if typeof(byModule) == "table" then
		return cloneValue(byModule)
	end
	return {}
end

function LegacyGarageProfileMapper.Convert(legacyProfile, schema, options)
	assert(typeof(schema) == "table" and typeof(schema.DefaultProfile) == "function", "PlayerProfileSchema module is required")
	options = typeof(options) == "table" and options or {}
	legacyProfile = typeof(legacyProfile) == "table" and legacyProfile or {}

	local profile = schema.DefaultProfile(legacyProfile.Cash)
	profile.Cash = typeof(legacyProfile.Cash) == "number" and legacyProfile.Cash or profile.Cash
	profile.LegacyMigration = {
		Source = "PersistencePhase3_LegacyGarageProfileMapper",
		MigratedAtUnix = os.time(),
		LegacyCurrentCategory = legacyProfile.CurrentCategory,
		LegacyCurrentCockpit = legacyProfile.CurrentCockpit,
		Notes = {},
	}

	local ownedCockpits = typeof(legacyProfile.OwnedCockpits) == "table" and legacyProfile.OwnedCockpits or {}
	if next(ownedCockpits) == nil then
		ownedCockpits[legacyProfile.CurrentCockpit or "bruiser_01"] = true
	end

	local cockpitIds = sortedKeys(ownedCockpits)
	moveKeyToFront(cockpitIds, legacyProfile.CurrentCockpit or "bruiser_01")

	local preserveLegacyCapacity = options.PreserveLegacyCapacity ~= false
	if preserveLegacyCapacity then
		profile.Garage.Capacity = math.max(profile.Garage.Capacity or 2, #cockpitIds)
	else
		profile.Garage.Capacity = tonumber(options.Capacity) or profile.Garage.Capacity or 2
	end

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
			local spaceKey = "Space" .. tostring(vehicleIndex)
			profile.Garage.DisplaySpaces[spaceKey] = profile.Garage.DisplaySpaces[spaceKey] or {}
			profile.Garage.DisplaySpaces[spaceKey].VehicleId = vehicleId
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

	profile.LegacyMigration.LegacyVehicleCount = countDictionary(profile.Vehicles)
	profile.LegacyMigration.LegacyModuleInstanceCount = countDictionary(profile.OwnedModuleInstances)
	table.insert(profile.LegacyMigration.Notes, "Legacy boolean ownership cannot represent duplicate purchased copies; Phase 3 creates one instance for each installed module and one unequipped instance for each remaining owned module template.")

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

local bridgeSource = [==[
-- Neo Tokyo Racers legacy garage profile bridge.
-- Persistence Phase 3. Server-only conversion bindables for future garage profile bridge phases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "LegacyGarageProfileBridge"

local function log(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureBindableFunction(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("BindableFunction") then
		error(item:GetFullName() .. " must be a BindableFunction")
	end
	if not item then
		item = Instance.new("BindableFunction")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local dataModules = ntr:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data")
local schema = require(dataModules:WaitForChild("PlayerProfileSchema"))
local mapper = require(dataModules:WaitForChild("LegacyGarageProfileMapper"))

local serverRoot = ServerScriptService:WaitForChild("NeoTokyoRacers")
local services = ensureFolder(serverRoot, "Services")
local playerServices = ensureFolder(services, "Player")
local bindings = ensureFolder(playerServices, "LegacyGarageProfileBridgeBindings")

local convertBinding = ensureBindableFunction(bindings, "ConvertLegacyProfile")
local summarizeBinding = ensureBindableFunction(bindings, "SummarizeLegacyProfile")

convertBinding.OnInvoke = function(legacyProfile, options)
	return mapper.Convert(legacyProfile, schema, options)
end

summarizeBinding.OnInvoke = function(legacyProfile, options)
	return mapper.SummarizeConversion(legacyProfile, schema, options)
end

log("Legacy garage profile mapper bridge active. No live garage actions are patched.")
]==]

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = ensureFolder(ntr, "Shared")
local modules = ensureFolder(shared, "Modules")
local dataModules = ensureFolder(modules, "Data")
if not dataModules:FindFirstChild("PlayerProfileSchema") then
	error("Run Persistence Phase 1 before Phase 3.")
end
ensureModule(dataModules, "LegacyGarageProfileMapper", mapperSource)

local serverRoot = ensureFolder(ServerScriptService, "NeoTokyoRacers")
local services = ensureFolder(serverRoot, "Services")
local playerServices = ensureFolder(services, "Player")
ensureScript(playerServices, "LegacyGarageProfileBridge_Active", bridgeSource)

info("Installed ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.LegacyGarageProfileMapper")
info("Installed ServerScriptService.NeoTokyoRacers.Services.Player.LegacyGarageProfileBridge_Active")
info("No active garage action, DataStore, dealership, vehicle, driving, or VFX scripts were patched.")
