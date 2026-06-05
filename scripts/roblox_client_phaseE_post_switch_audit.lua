-- Neo Tokyo Racers - Main Client Extraction Phase E Post-Switch Audit
-- Run in Roblox Studio Command Bar, Edit mode or Play mode.
--
-- Purpose:
--   Audits the project after the Phase D main client owner switch. Confirms the
--   new architecture-owned client is active, the legacy HOVER_RACING_V2_Client
--   is disabled, and no unexpected active scripts appeared.
--
-- Safe effects:
--   - Creates/updates a text report under:
--     ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports
--   - Prints a concise summary to Output.
--
-- Does NOT:
--   - Move, rename, disable, enable, delete, clone, or edit gameplay scripts.
--   - Change UI, driving, VFX, server actions, mobile controls, LOD, lighting,
--     traffic, assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_client_phaseE_post_switch_audit"

local function log(message)
	print("[NTR Client Phase E Audit] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No changes applied.")
		end
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function folder(parent, name)
	return child(parent, "Folder", name)
end

local function existsPath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return false, nil
		end
	end
	return true, current
end

local function isScriptLike(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript")
end

local function scriptState(instance)
	if not instance then return "missing" end
	if not isScriptLike(instance) then return "not-script:" .. instance.ClassName end
	return instance.Disabled and "disabled" or "enabled"
end

local function underExcludedArea(instance)
	return string.find(instance:GetFullName(), "Test %+ WIP Assets") ~= nil
end

local expectedActive = {
	-- Main client owner moved here in Phase D.
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"] = true,

	-- Intentional temporary client preview tool.
	["StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"] = true,

	-- Migrated/new active owners from Phases 15-20.
	["ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionService_Active"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active"] = true,
}

local expectedDisabled = {
	-- Disabled bootstraps/shadows that should stay non-live.
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Disabled",
	"ServerScriptService.NeoTokyoRacers.NeoTokyoRacersServer_Bootstrap_Disabled",
	"ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Shadow",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Shadow",

	-- Phase D replaced client owner.
	"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client",

	-- Replaced legacy owners from Phases 15-20.
	"ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server",
	"ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_DriverSeatPosition",
	"ServerScriptService.Lighting.LightingController",
	"ServerScriptService.Traffic Lights",
	"StarterPlayer.StarterPlayerScripts.LOD System",
	"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly",
	"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime",
	"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls",
	"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor",
}

local expectedStagedModules = {
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientState",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.GarageApiClient",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.CatalogClient",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientThemeAdapter",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.PaintClient",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewCameraController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewVehicleController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ColourPickerController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DealershipUIController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CockpitPaintUIController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ModuleShopUIController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CustomisationUIController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.NavigationController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.StatsPanelController",
}

local function expectedActiveCount()
	local count = 0
	for _ in pairs(expectedActive) do
		count += 1
	end
	return count
end

local knownActiveCount = 0
local unexpectedActive = {}
local activeInsideExcluded = {}
local missingExpectedActive = {}
local expectedActiveDisabled = {}
local missingExpectedDisabled = {}
local expectedDisabledEnabled = {}
local disabledLegacyOwners = {}
local activeLegacyNamed = {}
local missingStagedModules = {}
local stagedModuleIssues = {}

for path in pairs(expectedActive) do
	local exists, instance = existsPath(path)
	if not exists then
		table.insert(missingExpectedActive, path)
	elseif not isScriptLike(instance) then
		table.insert(missingExpectedActive, path .. " (" .. instance.ClassName .. ")")
	elseif instance.Disabled then
		table.insert(expectedActiveDisabled, path)
	else
		knownActiveCount += 1
	end
end

for _, path in ipairs(expectedDisabled) do
	local exists, instance = existsPath(path)
	if not exists then
		table.insert(missingExpectedDisabled, path)
	elseif isScriptLike(instance) then
		if instance.Disabled then
			if string.find(instance.Name, "HOVER_RACING", 1, true) then
				table.insert(disabledLegacyOwners, path)
			end
		else
			table.insert(expectedDisabledEnabled, path)
		end
	end
end

for _, path in ipairs(expectedStagedModules) do
	local exists, instance = existsPath(path)
	if not exists then
		table.insert(missingStagedModules, path)
	elseif not instance:IsA("ModuleScript") then
		table.insert(stagedModuleIssues, path .. " -> " .. instance.ClassName)
	end
end

for _, root in ipairs({ ServerScriptService, StarterPlayer, ReplicatedStorage, Workspace }) do
	for _, instance in ipairs(root:GetDescendants()) do
		if isScriptLike(instance) and not instance.Disabled then
			local fullName = instance:GetFullName()
			if underExcludedArea(instance) then
				table.insert(activeInsideExcluded, fullName)
			end
			if string.find(instance.Name, "HOVER_RACING", 1, true) then
				table.insert(activeLegacyNamed, fullName)
			end
			if not expectedActive[fullName] then
				table.insert(unexpectedActive, fullName)
			end
		end
	end
end

table.sort(unexpectedActive)
table.sort(activeInsideExcluded)
table.sort(missingExpectedActive)
table.sort(expectedActiveDisabled)
table.sort(missingExpectedDisabled)
table.sort(expectedDisabledEnabled)
table.sort(disabledLegacyOwners)
table.sort(activeLegacyNamed)
table.sort(missingStagedModules)
table.sort(stagedModuleIssues)

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Main Client Phase E Post-Switch Audit")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Read-only audit. No gameplay scripts were moved, renamed, disabled, enabled, deleted, cloned, or edited.")
line("")
line("## Summary")
line("")
line("- Expected active owners enabled: " .. tostring(knownActiveCount) .. " / " .. tostring(expectedActiveCount()))
line("- Missing expected active owners: " .. tostring(#missingExpectedActive))
line("- Expected active owners currently disabled: " .. tostring(#expectedActiveDisabled))
line("- Expected disabled owners currently enabled: " .. tostring(#expectedDisabledEnabled))
line("- Unexpected active scripts: " .. tostring(#unexpectedActive))
line("- Active scripts inside excluded Test + WIP Assets: " .. tostring(#activeInsideExcluded))
line("- Active legacy-named HOVER_RACING scripts: " .. tostring(#activeLegacyNamed))
line("- Disabled legacy-named HOVER_RACING owners: " .. tostring(#disabledLegacyOwners))
line("- Missing staged Phase A-C modules: " .. tostring(#missingStagedModules))
line("- Staged module type issues: " .. tostring(#stagedModuleIssues))
line("")

line("## Current Recommendation")
line("")
if #missingExpectedActive == 0
	and #expectedActiveDisabled == 0
	and #expectedDisabledEnabled == 0
	and #unexpectedActive == 0
	and #activeInsideExcluded == 0
	and #activeLegacyNamed == 0
	and #missingStagedModules == 0
	and #stagedModuleIssues == 0
then
	line("Status: Main client owner switch checkpoint is clean. Export Studio scripts to the GitHub mirror, then commit this migration checkpoint.")
else
	line("Status: Needs review before committing. Resolve the sections below first.")
end
line("")

local function listSection(title, items)
	line("## " .. title)
	line("")
	if #items == 0 then
		line("- None.")
	else
		for _, item in ipairs(items) do
			line("- " .. item)
		end
	end
	line("")
end

listSection("Missing Expected Active Owners", missingExpectedActive)
listSection("Expected Active Owners Currently Disabled", expectedActiveDisabled)
listSection("Expected Disabled Owners Currently Enabled", expectedDisabledEnabled)
listSection("Unexpected Active Scripts", unexpectedActive)
listSection("Active Scripts Inside Excluded Test + WIP Assets", activeInsideExcluded)
listSection("Active Legacy-Named HOVER_RACING Scripts", activeLegacyNamed)
listSection("Disabled Legacy-Named HOVER_RACING Owners", disabledLegacyOwners)
listSection("Missing Staged Phase A-C Modules", missingStagedModules)
listSection("Staged Module Type Issues", stagedModuleIssues)

line("## Expected Active Owners")
line("")
local activePaths = {}
for path in pairs(expectedActive) do
	table.insert(activePaths, path)
end
table.sort(activePaths)
for _, path in ipairs(activePaths) do
	local _, instance = existsPath(path)
	line("- " .. path .. " -> " .. scriptState(instance))
end
line("")

line("## Expected Disabled Owners")
line("")
for _, path in ipairs(expectedDisabled) do
	local _, instance = existsPath(path)
	line("- " .. path .. " -> " .. scriptState(instance))
end
line("")

line("## Staged Phase A-C Modules")
line("")
for _, path in ipairs(expectedStagedModules) do
	local exists, instance = existsPath(path)
	line("- " .. path .. " -> " .. (exists and instance.ClassName or "missing"))
end
line("")

line("## Next Safe Steps")
line("")
line("1. If the audit is clean, export Studio scripts to `roblox/exported_scripts` using the established script sync workflow.")
line("2. Commit the Phase A-E main client migration checkpoint.")
line("3. Keep disabled legacy owners for rollback until another stable milestone.")
line("4. Treat internal replacement of the active bootstrap with Phase A-C modules as a later refactor, not part of this checkpoint.")

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")
local reportValue = reportsFolder:FindFirstChild("MainClientPhaseE_PostSwitchAudit")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "MainClientPhaseE_PostSwitchAudit_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "MainClientPhaseE_PostSwitchAudit"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("ExpectedActiveEnabled", knownActiveCount)
reportValue:SetAttribute("MissingExpectedActive", #missingExpectedActive)
reportValue:SetAttribute("ExpectedActiveDisabled", #expectedActiveDisabled)
reportValue:SetAttribute("ExpectedDisabledEnabled", #expectedDisabledEnabled)
reportValue:SetAttribute("UnexpectedActive", #unexpectedActive)
reportValue:SetAttribute("ActiveInsideExcluded", #activeInsideExcluded)
reportValue:SetAttribute("ActiveLegacyNamed", #activeLegacyNamed)
reportValue:SetAttribute("MissingStagedModules", #missingStagedModules)

log("Audit complete. Report saved to " .. reportValue:GetFullName())
log("Unexpected active: " .. tostring(#unexpectedActive) .. "; active legacy named: " .. tostring(#activeLegacyNamed) .. "; missing staged modules: " .. tostring(#missingStagedModules))
print(reportValue.Value)
