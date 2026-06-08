-- Neo Tokyo Racers - Vehicle Phase AN module-specific upgrades
-- Run in the Roblox Studio Command Bar while NOT play-testing.
--
-- FRAGILE PATCH WARNING:
-- This script uses exact guarded source replacement against the refreshed
-- Phase AM garage controller. All required matches are preflighted before
-- any live source or shared module is changed.
--
-- Phase AN:
-- - Stores upgrade levels per ModuleId and UpgradeId.
-- - Adds server-side purchase validation and pricing.
-- - Applies upgrade effects to cloned installed modules before Phase AM reads them.
-- - Returns module upgrade ownership and complete performance previews to clients.
-- - Keeps the old visible upgrade UI until the Phase AO UI cutover.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Vehicle Phase AN"
local SERVER_MARKER = "-- NTR_VEHICLE_PHASE_AN_MODULE_UPGRADES"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function countPlain(source, needle)
	local count = 0
	local position = 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1
		position = found + #needle
	end
end

local function preflight(source, needle, label)
	local count = countPlain(source, needle)
	if count ~= 1 then
		error(label .. " expected exactly 1 match, found " .. tostring(count))
	end
end

local function replaceOnce(source, oldText, newText)
	return string.gsub(source, oldText, function()
		return newText
	end, 1)
end

local function enablePurchasesBeforeFinalReturn(source)
	local updated, count = string.gsub(
		source,
		"return%s+UpgradeDefinitions%s*$",
		"UpgradeDefinitions.EnabledForPurchases = true\n\nreturn UpgradeDefinitions",
		1
	)
	if count ~= 1 then
		error("final upgrade definitions return expected exactly 1 match, found " .. tostring(count))
	end
	return updated
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Common")
	:WaitForChild("Performance")
local upgradeDefinitions = performance:WaitForChild("VehicleUpgradeDefinitions")
local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assert(upgradeDefinitions:IsA("ModuleScript"), upgradeDefinitions:GetFullName() .. " must be a ModuleScript")
assert(garage:IsA("Script"), garage:GetFullName() .. " must be a Script")

if string.find(garage.Source, SERVER_MARKER, 1, true) then
	info("Phase AN server patch is already installed.")
	return
end

local oldDefaultProfile = [[
			UpgradeLevels = { Brakes = 0, Converter = 0, FuelSystem = 0 },
]]
local newDefaultProfile = [[
			UpgradeLevels = { Brakes = 0, Converter = 0, FuelSystem = 0 },
			ModuleUpgradeLevels = {},
]]

local oldNormalize = [[
		profile.UpgradeLevels = profile.UpgradeLevels or { Brakes = 0, Converter = 0, FuelSystem = 0 }
]]
local newNormalize = [[
		profile.UpgradeLevels = profile.UpgradeLevels or { Brakes = 0, Converter = 0, FuelSystem = 0 }
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
]]

local helperAnchor = [[
	local function V56_readModule(item, root)
]]
local helperBlock = [[
	-- NTR_VEHICLE_PHASE_AN_MODULE_UPGRADES
	local V77_performanceModules = V56_kit
		:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Common")
		:WaitForChild("Performance")
	local V77_UpgradeDefinitions = require(V77_performanceModules:WaitForChild("VehicleUpgradeDefinitions"))
	local V77_PerformanceRuntime = require(V77_performanceModules:WaitForChild("VehiclePerformanceRuntime"))

	local function V77_moduleUpgradeLevels(profile, moduleId)
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
		local levels = profile.ModuleUpgradeLevels[moduleId]
		if typeof(levels) ~= "table" then
			levels = {}
			profile.ModuleUpgradeLevels[moduleId] = levels
		end
		return levels
	end

	local function V77_upgradeCatalogForModule(module)
		local moduleType = V56_moduleTypeForModel(module)
		local result = {}
		for _, definition in ipairs(V77_UpgradeDefinitions.GetForModuleType(moduleType)) do
			table.insert(result, {
				UpgradeId = definition.UpgradeId,
				DisplayName = definition.DisplayName,
				MaxLevel = definition.MaxLevel,
				BasePrice = definition.BasePrice,
				PriceMultiplier = definition.PriceMultiplier,
				EffectsPerLevel = definition.EffectsPerLevel,
			})
		end
		return result
	end

	local function V77_applyModuleUpgrades(profile, moduleTemplate, moduleClone)
		local moduleId = V56_string(moduleTemplate, "ModuleId", moduleTemplate.Name)
		local moduleType = V56_moduleTypeForModel(moduleTemplate)
		local levels = V77_moduleUpgradeLevels(profile, moduleId)
		for _, definition in ipairs(V77_UpgradeDefinitions.GetForModuleType(moduleType)) do
			local level = math.clamp(math.floor(tonumber(levels[definition.UpgradeId]) or 0), 0, definition.MaxLevel or 3)
			moduleClone:SetAttribute("AppliedUpgrade_" .. definition.UpgradeId, level)
			if level > 0 then
				for variableName, amountPerLevel in pairs(definition.EffectsPerLevel or {}) do
					if typeof(amountPerLevel) == "number" then
						local attributeName = "PerformanceDelta_" .. variableName
						local base = moduleClone:GetAttribute(attributeName)
						if typeof(base) ~= "number" then base = 0 end
						moduleClone:SetAttribute(attributeName, base + amountPerLevel * level)
					end
				end
			end
		end
	end

]]

local oldReadModuleEnd = [[
			BoostRecharge = V56_number(item, "BoostRecharge", 0),
		}
]]
local newReadModuleEnd = [[
			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			Upgrades = V77_upgradeCatalogForModule(item),
		}
]]

local oldProfileFields = [[
			UpgradeLevels = profile.UpgradeLevels,
			TotalStats = V56_totalStats(profile),
]]
local newProfileFields = [[
			UpgradeLevels = profile.UpgradeLevels,
			ModuleUpgradeLevels = profile.ModuleUpgradeLevels,
			Performance = V77_calculateProfilePerformance(profile),
			TotalStats = V56_totalStats(profile),
]]

local profilePerformanceAnchor = [[
	local function V56_profileForClient(profile)
]]
local profilePerformanceBlock = [[
	local function V77_calculateProfilePerformance(profile)
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local installedRoot = Instance.new("Folder")
		for slotId, moduleId in pairs(profile.InstalledModules or {}) do
			local moduleTemplate = V56_findModule(profile.CurrentCategory, moduleId)
			if moduleTemplate then
				local clone = moduleTemplate:Clone()
				clone:SetAttribute("InstalledSlotId", slotId)
				V77_applyModuleUpgrades(profile, moduleTemplate, clone)
				clone.Parent = installedRoot
			end
		end
		local result = V77_PerformanceRuntime.CalculateBuild(V56_totalStats(profile), cockpit, installedRoot)
		installedRoot:Destroy()
		return result
	end

]]

local oldCloneSetup = [[
				moduleClone:SetAttribute("InstalledSlotId", slotId)
				moduleClone.Parent = installedRoot
]]
local newCloneSetup = [[
				moduleClone:SetAttribute("InstalledSlotId", slotId)
				V77_applyModuleUpgrades(profile, moduleTemplate, moduleClone)
				moduleClone.Parent = installedRoot
]]

local oldUpgradeAction = [[
			elseif action == "Upgrade" then
]]
local newUpgradeAction = [[
			elseif action == "UpgradeModule" then
				local slotId = tostring(args.SlotId or "")
				local requestedModuleId = tostring(args.ModuleId or "")
				local upgradeId = tostring(args.UpgradeId or "")
				local installedModuleId = profile.InstalledModules[slotId]
				local moduleId = requestedModuleId ~= "" and requestedModuleId or installedModuleId
				local module = moduleId and V56_findModule(profile.CurrentCategory, moduleId)
				local moduleType = module and V56_moduleTypeForModel(module)
				local definition = moduleType and V77_UpgradeDefinitions.Find(moduleType, upgradeId)
				if not module then
					ok, message = false, "Module not found."
				elseif not profile.OwnedModules[moduleId] then
					ok, message = false, "You do not own that module."
				elseif installedModuleId ~= moduleId then
					ok, message = false, "Install that module before upgrading it."
				elseif not definition then
					ok, message = false, "That upgrade is not available for this module."
				else
					local levels = V77_moduleUpgradeLevels(profile, moduleId)
					local level = math.clamp(math.floor(tonumber(levels[upgradeId]) or 0), 0, definition.MaxLevel or 3)
					local nextLevel = level + 1
					local price = V77_UpgradeDefinitions.PriceForLevel(definition, nextLevel) or 0
					if level >= (definition.MaxLevel or 3) then
						ok, message = false, "Already max level."
					elseif profile.Cash < price then
						ok, message = false, "Not enough cash."
					else
						profile.Cash -= price
						levels[upgradeId] = nextLevel
						V56_setLeaderstats(player, profile)
						ok, message = true, definition.DisplayName .. " upgraded to level " .. tostring(nextLevel) .. "."
					end
				end
			elseif action == "Upgrade" then
]]

local serverSource = garage.Source
local required = {
	{ oldDefaultProfile, "default profile upgrade storage" },
	{ oldNormalize, "profile normalization upgrade storage" },
	{ helperAnchor, "module upgrade helper anchor" },
	{ oldReadModuleEnd, "module catalogue upgrade data" },
	{ profilePerformanceAnchor, "profile performance anchor" },
	{ oldProfileFields, "profile response upgrade data" },
	{ oldCloneSetup, "spawned module upgrade effects" },
	{ oldUpgradeAction, "UpgradeModule action anchor" },
}
for _, item in ipairs(required) do
	preflight(serverSource, item[1], item[2])
end

local definitionsSource = upgradeDefinitions.Source

serverSource = replaceOnce(serverSource, oldDefaultProfile, newDefaultProfile)
serverSource = replaceOnce(serverSource, oldNormalize, newNormalize)
serverSource = replaceOnce(serverSource, helperAnchor, helperBlock .. helperAnchor)
serverSource = replaceOnce(serverSource, oldReadModuleEnd, newReadModuleEnd)
serverSource = replaceOnce(serverSource, profilePerformanceAnchor, profilePerformanceBlock .. profilePerformanceAnchor)
serverSource = replaceOnce(serverSource, oldProfileFields, newProfileFields)
serverSource = replaceOnce(serverSource, oldCloneSetup, newCloneSetup)
serverSource = replaceOnce(serverSource, oldUpgradeAction, newUpgradeAction)
definitionsSource = enablePurchasesBeforeFinalReturn(definitionsSource)
definitionsSource = string.gsub(
	definitionsSource,
	"%-%- Phase AL data only%. Phase AN will connect these definitions to purchases%.",
	"-- Phase AN module-specific upgrade catalogue and pricing.",
	1
)

upgradeDefinitions.Source = definitionsSource
upgradeDefinitions:SetAttribute("Phase", "AN")
upgradeDefinitions:SetAttribute("EnabledForPurchases", true)
garage.Source = serverSource
garage:SetAttribute("VehicleUpgradePhase", "AN")

info("Installed module-ID-scoped upgrade ownership and UpgradeModule server validation.")
info("Catalog modules now return upgrade definitions and profiles return ModuleUpgradeLevels plus complete Performance.")
info("Spawned module clones receive purchased PerformanceDelta effects before Phase AM calculates the vehicle.")
info("The old visible generic upgrade UI remains unchanged until Phase AO.")
