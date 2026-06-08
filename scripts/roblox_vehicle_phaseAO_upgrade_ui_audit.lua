-- Neo Tokyo Racers - Vehicle Phase AO read-only UI audit
-- Run in Edit mode after the Phase AO installer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Common")
	:WaitForChild("Performance")
local upgradeDefinitions = performance:WaitForChild("VehicleUpgradeDefinitions")
local Upgrades = require(upgradeDefinitions)
local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local warnings = {}
local function addWarning(message)
	table.insert(warnings, message)
	warn("[NTR Vehicle Phase AO Audit] " .. message)
end

local source = bootstrap.Source
local requiredTexts = {
	"-- NTR_VEHICLE_PHASE_AO_MODULE_UPGRADE_UI",
	"NTRVehiclePhaseAO.renderModuleUpgrades",
	'NTRVehiclePhaseAO.renderStats(UI.StatsPanel, stats)',
	'NTRVehiclePhaseAO.renderStats(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))',
	'callServer("UpgradeModule"',
	'State.CustomizeMode = "ModuleUpgrades"',
	'local upgrades = button(UI.CustomiseContent, "Performance"',
	'"PERFORMANCE"',
}
for _, requiredText in ipairs(requiredTexts) do
	if not string.find(source, requiredText, 1, true) then
		addWarning("Client bootstrap is missing " .. requiredText)
	end
end

local removedTexts = {
	'for _, upgrade in ipairs({ "Brakes", "Converter", "FuelSystem" })',
	'local upgrade = button(UI.CustomiseContent, "UPGRADE (LVL 1)"',
	"Visible module upgrades are ready to expand",
	'callServer("Upgrade", { UpgradeId = target })',
}
for _, removedText in ipairs(removedTexts) do
	if string.find(source, removedText, 1, true) then
		addWarning("Legacy visible upgrade UI remains: " .. removedText)
	end
end

if bootstrap:GetAttribute("VehicleUpgradeUIPhase") ~= "AO" then
	addWarning("Client bootstrap VehicleUpgradeUIPhase attribute is not AO")
end
if upgradeDefinitions:GetAttribute("EnabledForPurchases") ~= true then
	addWarning("Phase AN purchase definitions are not enabled")
end

local upgradeCount = 0
local moduleTypeCount = 0
for _, definitions in pairs(Upgrades.ByModuleType or {}) do
	moduleTypeCount += 1
	upgradeCount += #definitions
end

print("[NTR Vehicle Phase AO Audit] Module types with upgrades: " .. tostring(moduleTypeCount))
print("[NTR Vehicle Phase AO Audit] Module-specific upgrades: " .. tostring(upgradeCount))
print("[NTR Vehicle Phase AO Audit] Phase AN purchases enabled: " .. tostring(upgradeDefinitions:GetAttribute("EnabledForPurchases") == true))
print("[NTR Vehicle Phase AO Audit] Client phase attribute: " .. tostring(bootstrap:GetAttribute("VehicleUpgradeUIPhase")))
print("[NTR Vehicle Phase AO Audit] Warnings: " .. tostring(#warnings))
print("[NTR Vehicle Phase AO Audit] Read-only audit complete.")
