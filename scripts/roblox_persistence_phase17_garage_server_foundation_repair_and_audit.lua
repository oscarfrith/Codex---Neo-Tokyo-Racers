-- Persistence Phase 17 garage server foundation repair + audit.
--
-- Run from Roblox Studio Command Bar in Edit mode if the Phase 17 smoke keeps
-- surfacing one nil helper at a time, for example:
--
--   GarageActionController_Shadow_Disabled:1297: attempt to call a nil value
--
-- Why this exists:
-- Phase 17 added V85_attachDefaultModuleInstancesToCurrentVehicle before some
-- Phase 14 V84 instance-inventory helpers. In Luau, locals declared later are
-- not visible to a function body declared earlier, so a later repair can make
-- one nil disappear while exposing the next one. This script restores the V84
-- helper foundation before the V85 attach function and then audits the related
-- Phase 14/16/17 helper calls together.

local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 17 Garage Server Foundation Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function insertBefore(source, anchor, insertion, label)
	local first = findPlain(source, anchor)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	return string.sub(source, 1, first - 1) .. insertion .. string.sub(source, first)
end

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local source = garage.Source
assert(findPlain(source, "NTR_PERSISTENCE_PHASE16_MODULE_FAMILY_LOCKS"), "Expected Phase 16 module-family locks to be present.")
assert(findPlain(source, "V85_attachDefaultModuleInstancesToCurrentVehicle"), "Expected Phase 16/17 attach helper references to be present.")

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

local attachAt = findPlain(source, attachHeader)
assert(attachAt, "Could not find the V85 attach function header after duplicate-header normalization.")

local helperMarker = "-- NTR_PERSISTENCE_PHASE17_V84_FOUNDATION_REPAIR"
local helperAt = findPlain(source, helperMarker)
local existingGenerateAt = findPlain(source, "local function V84_generateId(prefix)")
local hasFoundationBeforeAttach = helperAt and helperAt < attachAt
if existingGenerateAt and existingGenerateAt < attachAt then
	hasFoundationBeforeAttach = true
end

if not hasFoundationBeforeAttach then
	local helperBlock = [=[

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

	source = string.sub(source, 1, attachAt - 1) .. helperBlock .. string.sub(source, attachAt)
	changed = true
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
end

garage.Source = source
garage:SetAttribute("PersistencePhase17GarageFoundationRepair", true)

local finalSource = garage.Source
local finalAttachAt = findPlain(finalSource, attachHeader)
local checks = {
	{ "V84 foundation marker", findPlain(finalSource, helperMarker) },
	{ "V84_generateId before V85 attach", findPlain(finalSource, "local function V84_generateId(prefix)") and finalAttachAt and findPlain(finalSource, "local function V84_generateId(prefix)") < finalAttachAt },
	{ "V84_countDictionary", findPlain(finalSource, "local function V84_countDictionary(dictionary)") },
	{ "V84_cloneDictionary", findPlain(finalSource, "local function V84_cloneDictionary(dictionary)") },
	{ "V84_createVehicleInstance", findPlain(finalSource, "local function V84_createVehicleInstance(profile, cockpitId, sourceName)") },
	{ "V84_ensureInstanceInventory", findPlain(finalSource, "local function V84_ensureInstanceInventory(profile)") },
	{ "V85 attach function", finalAttachAt },
	{ "V86 module slot guard", findPlain(finalSource, "local function V86_moduleFitsSlot") },
	{ "V56_totalStats", findPlain(finalSource, "local function V56_totalStats(profile)") },
}

for _, check in ipairs(checks) do
	local label, ok = check[1], check[2]
	assert(ok, "Post-repair audit failed: missing " .. label)
	info("PASS: " .. label)
end

local _, remainingDuplicateCount = string.gsub(
	finalSource,
	"V85_attachDefaultModuleInstancesToCurrentVehicle%s*=%s*function%(profile%)%s+V85_attachDefaultModuleInstancesToCurrentVehicle%s*=%s*function%(profile%)",
	attachHeader
)
assert(remainingDuplicateCount == 0, "Post-repair audit failed: duplicate V85 attach header still present.")

if changed then
	info("PASS: repaired the garage server helper foundation.")
else
	info("PASS: garage server helper foundation already looked correct.")
end

info("Next: stop Play, start a fresh Play session, then rerun scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua from the CLIENT Command Bar.")
