-- Neo Tokyo Racers - Vehicle Phase AN isolated upgrade repair
-- Run in Edit mode after the main Phase AN installer printed success but the
-- garage source audit still reported missing Phase AN markers.
--
-- This repair uses one isolated ModuleScript and four small guarded garage edits.
-- It verifies the source write before printing success.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MARKER = "-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES"

local function countPlain(source, needle)
	local count, position = 0, 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1
		position = found + #needle
	end
end

local function replaceOnce(source, oldText, newText, label)
	local count = countPlain(source, oldText)
	if count ~= 1 then
		error(label .. " expected exactly 1 match, found " .. tostring(count))
	end
	return string.gsub(source, oldText, function()
		return newText
	end, 1)
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Common")
	:WaitForChild("Performance")
local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local serviceModule = performance:FindFirstChild("VehicleModuleUpgradeRuntime")
if serviceModule and not serviceModule:IsA("ModuleScript") then
	error(serviceModule:GetFullName() .. " must be a ModuleScript")
end
if not serviceModule then
	serviceModule = Instance.new("ModuleScript")
	serviceModule.Name = "VehicleModuleUpgradeRuntime"
	serviceModule.Parent = performance
end

local serviceSource = [==[
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local UpgradeDefinitions = require(script.Parent:WaitForChild("VehicleUpgradeDefinitions"))

local Runtime = {}
local levelsByUserId = {}

local function playerLevels(player)
	local levels = levelsByUserId[player.UserId]
	if not levels then
		levels = {}
		levelsByUserId[player.UserId] = levels
	end
	return levels
end

function Runtime.GetLevels(player)
	return playerLevels(player)
end

function Runtime.GetModuleLevels(player, moduleId)
	local all = playerLevels(player)
	local levels = all[moduleId]
	if typeof(levels) ~= "table" then
		levels = {}
		all[moduleId] = levels
	end
	return levels
end

function Runtime.CatalogForModuleType(moduleType)
	local result = {}
	for _, definition in ipairs(UpgradeDefinitions.GetForModuleType(moduleType)) do
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

function Runtime.Purchase(player, profile, slotId, moduleId, upgradeId, findModule, moduleTypeForModel)
	local installedModuleId = profile.InstalledModules and profile.InstalledModules[slotId]
	moduleId = moduleId ~= "" and moduleId or installedModuleId
	local module = moduleId and findModule(profile.CurrentCategory, moduleId)
	local moduleType = module and moduleTypeForModel(module)
	local definition = moduleType and UpgradeDefinitions.Find(moduleType, upgradeId)

	if not module then return false, "Module not found." end
	if not (profile.OwnedModules and profile.OwnedModules[moduleId]) then return false, "You do not own that module." end
	if installedModuleId ~= moduleId then return false, "Install that module before upgrading it." end
	if not definition then return false, "That upgrade is not available for this module." end

	local levels = Runtime.GetModuleLevels(player, moduleId)
	local level = math.clamp(math.floor(tonumber(levels[upgradeId]) or 0), 0, definition.MaxLevel or 3)
	if level >= (definition.MaxLevel or 3) then return false, "Already max level." end

	local nextLevel = level + 1
	local price = UpgradeDefinitions.PriceForLevel(definition, nextLevel) or 0
	if profile.Cash < price then return false, "Not enough cash." end

	profile.Cash -= price
	levels[upgradeId] = nextLevel
	return true, definition.DisplayName .. " upgraded to level " .. tostring(nextLevel) .. "."
end

function Runtime.ApplyToClone(player, moduleTemplate, moduleClone, moduleTypeForModel)
	local moduleId = tostring(moduleTemplate:GetAttribute("ModuleId") or moduleTemplate.Name)
	local moduleType = moduleTypeForModel(moduleTemplate)
	local levels = Runtime.GetModuleLevels(player, moduleId)
	for _, definition in ipairs(UpgradeDefinitions.GetForModuleType(moduleType)) do
		local level = math.clamp(math.floor(tonumber(levels[definition.UpgradeId]) or 0), 0, definition.MaxLevel or 3)
		moduleClone:SetAttribute("AppliedUpgrade_" .. definition.UpgradeId, level)
		for variableName, amount in pairs(definition.EffectsPerLevel or {}) do
			if level > 0 and typeof(amount) == "number" and table.find(Definitions.RawVariableOrder, variableName) then
				local attributeName = "PerformanceDelta_" .. variableName
				local base = moduleClone:GetAttribute(attributeName)
				moduleClone:SetAttribute(attributeName, (typeof(base) == "number" and base or 0) + amount * level)
			end
		end
	end
end

return Runtime
]==]

local source = garage.Source
if not string.find(source, MARKER, 1, true) then
	source = replaceOnce(
		source,
		[[	local V56_profiles = {}
]],
		[[	local V56_profiles = {}

	-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES
	local V77_ModuleUpgrades = require(V56_kit
		:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Common")
		:WaitForChild("Performance")
		:WaitForChild("VehicleModuleUpgradeRuntime"))
]],
		"Phase AN helper require"
	)
end

if not string.find(source, "ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels", 1, true) then
	source = replaceOnce(
		source,
		[[			UpgradeLevels = profile.UpgradeLevels,
			TotalStats = V56_totalStats(profile),
]],
		[[			UpgradeLevels = profile.UpgradeLevels,
			ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels(profile._Player),
			TotalStats = V56_totalStats(profile),
]],
		"Phase AN profile response"
	)
end

if not string.find(source, "profile._Player = player", 1, true) then
	source = replaceOnce(
		source,
		[[			local profile = V56_getProfile(player)
			V76_grantDefaultModulesForCurrentCockpit(profile)
]],
		[[			local profile = V56_getProfile(player)
			profile._Player = player
			V76_grantDefaultModulesForCurrentCockpit(profile)
]],
		"Phase AN profile player binding"
	)
end

if not string.find(source, "V77_ModuleUpgrades.ApplyToClone", 1, true) then
	source = replaceOnce(
		source,
		[[				moduleClone:SetAttribute("InstalledSlotId", slotId)
				moduleClone.Parent = installedRoot
]],
		[[				moduleClone:SetAttribute("InstalledSlotId", slotId)
				V77_ModuleUpgrades.ApplyToClone(player, moduleTemplate, moduleClone, V56_moduleTypeForModel)
				moduleClone.Parent = installedRoot
]],
		"Phase AN spawned module effects"
	)
end

if not string.find(source, 'action == "UpgradeModule"', 1, true) then
	source = replaceOnce(
		source,
		[[			elseif action == "Upgrade" then
]],
		[[			elseif action == "UpgradeModule" then
				ok, message = V77_ModuleUpgrades.Purchase(
					player,
					profile,
					tostring(args.SlotId or ""),
					tostring(args.ModuleId or ""),
					tostring(args.UpgradeId or ""),
					V56_findModule,
					V56_moduleTypeForModel
				)
				V56_setLeaderstats(player, profile)
			elseif action == "Upgrade" then
]],
		"Phase AN UpgradeModule action"
	)
end

if not string.find(source, "Upgrades = V77_ModuleUpgrades.CatalogForModuleType", 1, true) then
	source = replaceOnce(
		source,
		[[			BoostRecharge = V56_number(item, "BoostRecharge", 0),
		}
]],
		[[			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType),
		}
]],
		"Phase AN module catalogue upgrades"
	)
end

serviceModule.Source = serviceSource
serviceModule:SetAttribute("Phase", "AN")
garage.Source = source
garage:SetAttribute("VehicleUpgradePhase", "AN_Isolated")

if not string.find(garage.Source, MARKER, 1, true) then
	error("Studio did not retain the Phase AN isolated garage source write")
end
if not string.find(garage.Source, "V77_ModuleUpgrades.ApplyToClone", 1, true) then
	error("Studio retained an incomplete Phase AN isolated garage source write")
end
if not string.find(garage.Source, 'action == "UpgradeModule"', 1, true) then
	error("Studio retained the Phase AN clone hook but not the purchase action")
end
if not string.find(garage.Source, "Upgrades = V77_ModuleUpgrades.CatalogForModuleType", 1, true) then
	error("Studio retained the Phase AN purchase action but not catalogue upgrades")
end

print("[NTR Vehicle Phase AN Repair] Installed isolated module upgrade runtime.")
print("[NTR Vehicle Phase AN Repair] Garage source write verified immediately.")
print("[NTR Vehicle Phase AN Repair] Run the Phase AN audit next.")
