local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local UpgradeDefinitions = require(script.Parent:WaitForChild("VehicleUpgradeDefinitions"))

local Runtime = {}
local levelsByUserId = {}

local function playerLevels(player)
	assert(player, "player is required")
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

function Runtime.CalculateProfile(player, profile, legacyTotals, cockpit, findModule, moduleTypeForModel)
	local performanceRuntime = require(script.Parent:WaitForChild("VehiclePerformanceRuntime"))
	local installedRoot = Instance.new("Folder")
	for slotId, moduleId in pairs(profile.InstalledModules or {}) do
		local moduleTemplate = findModule(profile.CurrentCategory, moduleId)
		if moduleTemplate then
			local clone = moduleTemplate:Clone()
			clone:SetAttribute("InstalledSlotId", slotId)
			Runtime.ApplyToClone(player, moduleTemplate, clone, moduleTypeForModel)
			clone.Parent = installedRoot
		end
	end
	local result = performanceRuntime.CalculateBuild(legacyTotals, cockpit, installedRoot)
	installedRoot:Destroy()
	return result
end

return Runtime
