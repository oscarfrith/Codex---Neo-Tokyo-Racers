-- Neo Tokyo Racers - Phase 21 Post-Switch Architecture Audit
-- Run in Roblox Studio Command Bar, Edit mode or Play mode.
--
-- Purpose:
--   Audits the architecture after Phases 15-20 to confirm the new owner
--   scripts are active, replaced legacy owners are disabled, and no unexpected
--   active scripts have appeared.
--
-- Safe effects:
--   - Creates/updates a text report under
--     ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports.
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

local SCRIPT_ID = "roblox_hierarchy_phase21_post_switch_audit"

local function log(message)
	print("[NTR Phase21 Audit] " .. message)
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
	-- Main legacy client remains active until the separate UI/customisation extraction project.
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client"] = true,

	-- Intentional temporary client preview tool.
	["StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"] = true,

	-- Migrated/new active owners.
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

	-- Replaced legacy owners.
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

local knownActiveCount = 0
local unexpectedActive = {}
local activeInsideExcluded = {}
local missingExpectedActive = {}
local expectedActiveDisabled = {}
local missingExpectedDisabled = {}
local expectedDisabledEnabled = {}
local disabledLegacyOwners = {}
local activeLegacyNamed = {}

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

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Phase 21 Post-Switch Architecture Audit")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Read-only audit. No gameplay scripts were moved, renamed, disabled, enabled, deleted, cloned, or edited.")
line("")
line("## Summary")
line("")
line("- Expected active owners enabled: " .. tostring(knownActiveCount) .. " / " .. tostring((function() local n = 0 for _ in pairs(expectedActive) do n += 1 end return n end)()))
line("- Missing expected active owners: " .. tostring(#missingExpectedActive))
line("- Expected active owners currently disabled: " .. tostring(#expectedActiveDisabled))
line("- Expected disabled owners currently enabled: " .. tostring(#expectedDisabledEnabled))
line("- Unexpected active scripts: " .. tostring(#unexpectedActive))
line("- Active scripts inside excluded Test + WIP Assets: " .. tostring(#activeInsideExcluded))
line("- Active legacy-named HOVER_RACING scripts: " .. tostring(#activeLegacyNamed))
line("- Disabled legacy-named HOVER_RACING owners: " .. tostring(#disabledLegacyOwners))
line("")

line("## Current Recommendation")
line("")
if #missingExpectedActive == 0 and #expectedActiveDisabled == 0 and #expectedDisabledEnabled == 0 and #unexpectedActive == 0 and #activeInsideExcluded == 0 then
	line("Status: Post-switch architecture is clean. Commit this checkpoint before attempting the large main client extraction.")
else
	line("Status: Needs review before committing or proceeding. Resolve the sections below first.")
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

line("## Expected Active Owners")
line("")
local activePaths = {}
for path in pairs(expectedActive) do table.insert(activePaths, path) end
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

line("## Next Safe Steps")
line("")
line("1. If the audit is clean, commit the Phase 16-21 checkpoint.")
line("2. Do not delete old disabled owners yet; keep rollback paths until a later cleanup commit.")
line("3. Treat `HOVER_RACING_V2_Client` extraction as a separate larger refactor, not a quick owner switch.")
line("4. Leave `TEMP_LightingPreview` active unless the lighting workflow changes.")

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")
local reportValue = reportsFolder:FindFirstChild("Phase21_PostSwitchArchitectureAudit")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase21_PostSwitchArchitectureAudit_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase21_PostSwitchArchitectureAudit"
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

log("Audit complete. Report saved to " .. reportValue:GetFullName())
log("Unexpected active: " .. tostring(#unexpectedActive) .. "; expected-disabled enabled: " .. tostring(#expectedDisabledEnabled) .. "; missing expected active: " .. tostring(#missingExpectedActive))
print(reportValue.Value)
