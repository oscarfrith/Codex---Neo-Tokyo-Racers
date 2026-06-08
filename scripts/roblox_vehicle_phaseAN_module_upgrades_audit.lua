-- Neo Tokyo Racers - Vehicle Phase AN read-only audit
-- Run in Edit mode after the Phase AN installer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Common")
	:WaitForChild("Performance")
local definitionsModule = performance:WaitForChild("VehicleUpgradeDefinitions")
local Upgrades = require(definitionsModule)
local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local warnings = {}
local function addWarning(message)
	table.insert(warnings, message)
	warn("[NTR Vehicle Phase AN Audit] " .. message)
end

local purchaseAttributeEnabled = definitionsModule:GetAttribute("EnabledForPurchases") == true
local purchaseSourceEnabled = string.find(
	definitionsModule.Source,
	"UpgradeDefinitions.EnabledForPurchases = true",
	1,
	true
) ~= nil
if not (purchaseAttributeEnabled and purchaseSourceEnabled) then
	addWarning("VehicleUpgradeDefinitions purchase enable source/attribute is incomplete")
end
if definitionsModule:GetAttribute("Phase") ~= "AN" then
	addWarning("VehicleUpgradeDefinitions Phase attribute is not AN")
end
local garagePhase = garage:GetAttribute("VehicleUpgradePhase")
if garagePhase ~= "AN" and garagePhase ~= "AN_Isolated" then
	addWarning("Garage controller VehicleUpgradePhase attribute is not AN")
end

local source = garage.Source
local isolated = string.find(source, "-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES", 1, true) ~= nil
local requiredTexts = isolated and {
	"-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES",
	"ModuleUpgradeLevels",
	"V77_ModuleUpgrades.ApplyToClone",
	"Upgrades = V77_ModuleUpgrades.CatalogForModuleType",
	'action == "UpgradeModule"',
} or {
	"-- NTR_VEHICLE_PHASE_AN_MODULE_UPGRADES",
	"ModuleUpgradeLevels",
	"V77_applyModuleUpgrades",
	"V77_calculateProfilePerformance",
	'action == "UpgradeModule"',
}
for _, requiredText in ipairs(requiredTexts) do
	if not string.find(source, requiredText, 1, true) then
		addWarning("Garage controller is missing " .. requiredText)
	end
end

if isolated then
	local helper = performance:FindFirstChild("VehicleModuleUpgradeRuntime")
	if not (helper and helper:IsA("ModuleScript") and helper:GetAttribute("Phase") == "AN") then
		addWarning("VehicleModuleUpgradeRuntime helper is missing or not Phase AN")
	end
end

local upgradeCount = 0
local duplicateTypeKeys = {}
for moduleType, definitions in pairs(Upgrades.ByModuleType) do
	local seen = {}
	for _, definition in ipairs(definitions) do
		upgradeCount += 1
		if seen[definition.UpgradeId] then
			table.insert(duplicateTypeKeys, moduleType .. "." .. definition.UpgradeId)
		end
		seen[definition.UpgradeId] = true
		if not definition.DisplayName or not definition.MaxLevel or not definition.BasePrice then
			addWarning(moduleType .. "." .. tostring(definition.UpgradeId) .. " is missing required fields")
		end
		if typeof(definition.EffectsPerLevel) ~= "table" or next(definition.EffectsPerLevel) == nil then
			addWarning(moduleType .. "." .. tostring(definition.UpgradeId) .. " has no effects")
		end
	end
end
for _, key in ipairs(duplicateTypeKeys) do
	addWarning("Duplicate upgrade ID within module type: " .. key)
end

local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local activeModules = 0
local modulesWithoutUpgrades = 0
for _, item in ipairs(categories:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("ModuleId") ~= nil and item:GetAttribute("RetiredFromCatalog") ~= true then
		activeModules += 1
		local moduleType = tostring(item:GetAttribute("ModuleType") or "")
		if #Upgrades.GetForModuleType(moduleType) == 0 then
			modulesWithoutUpgrades += 1
			addWarning(item:GetFullName() .. " has no upgrade definitions for ModuleType " .. moduleType)
		end
	end
end

local runtimeService = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Vehicle")
	:FindFirstChild("VehiclePerformanceRuntimeService_Active")
if not (runtimeService and runtimeService:IsA("Script") and not runtimeService.Disabled) then
	addWarning("VehiclePerformanceRuntimeService_Active is missing or disabled")
end

print("[NTR Vehicle Phase AN Audit] Planned upgrades: " .. tostring(upgradeCount))
print("[NTR Vehicle Phase AN Audit] Active modules: " .. tostring(activeModules))
print("[NTR Vehicle Phase AN Audit] Active modules without definitions: " .. tostring(modulesWithoutUpgrades))
print("[NTR Vehicle Phase AN Audit] Purchase definitions enabled: " .. tostring(purchaseAttributeEnabled and purchaseSourceEnabled))
print("[NTR Vehicle Phase AN Audit] Cached require value: " .. tostring(Upgrades.EnabledForPurchases) .. " (may remain false until a fresh Play/Edit VM)")
print("[NTR Vehicle Phase AN Audit] Warnings: " .. tostring(#warnings))
print("[NTR Vehicle Phase AN Audit] Read-only audit complete. Phase AO UI remains unchanged.")
