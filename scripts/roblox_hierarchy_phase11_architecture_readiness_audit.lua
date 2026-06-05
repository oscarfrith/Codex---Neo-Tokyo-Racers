-- Neo Tokyo Racers - Phase 11 Architecture Readiness Audit
-- Run in Roblox Studio Command Bar, Edit mode or Play mode.
--
-- Purpose:
--   Produces a non-destructive report showing whether the new architecture
--   scaffold is complete and what legacy/live systems still remain.
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
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_hierarchy_phase11_architecture_readiness_audit"

local function log(message)
	print("[NTR Phase11 Audit] " .. message)
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

local function isScriptLike(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript")
end

local function isModule(instance)
	return instance:IsA("ModuleScript")
end

local function disabledText(instance)
	if isScriptLike(instance) then
		return tostring(instance.Disabled)
	end
	return "n/a"
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

local function underExcludedArea(instance)
	local fullName = instance:GetFullName()
	return string.find(fullName, "Test %+ WIP Assets") ~= nil
end

local approvedActiveScripts = {
	["ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_DriverSeatPosition"] = true,
	["ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server"] = true,
	["ServerScriptService.Lighting.LightingController"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor"] = true,
	["StarterPlayer.StarterPlayerScripts.LOD System"] = true,
	["StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"] = true,
}

local expectedPaths = {
	-- Core new roots.
	"ReplicatedStorage.NeoTokyoRacers",
	"ReplicatedStorage.NeoTokyoRacers.Compatibility",
	"ReplicatedStorage.NeoTokyoRacers.Shared",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Config",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules",
	"ServerScriptService.NeoTokyoRacers",
	"ServerScriptService.NeoTokyoRacers.Services",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient",

	-- Phase 6 world services.
	"ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService",
	"ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Shadow",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Shadow",

	-- Phase 7 shared UI helpers.
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.UITheme",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.UIPool",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.UIFactory",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.ResponsiveLayout",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.ArrowScroller",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.StatBars",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.ColourUtils",

	-- Phase 8 client UI scaffold.
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Disabled",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DealershipUIController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CockpitPaintUIController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ModuleShopUIController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CustomisationUIController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewVehicleController",

	-- Phase 9 server scaffold.
	"ServerScriptService.NeoTokyoRacers.NeoTokyoRacersServer_Bootstrap_Disabled",
	"ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionService",
	"ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleBuildService",
	"ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleCatalogService",
	"ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleSpawnService",
	"ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleStatsService",
	"ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService",
	"ServerScriptService.NeoTokyoRacers.Services.Economy.EconomyService",

	-- Phase 10 runtime scaffold.
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Runtime.RuntimeMigrationMap",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Runtime.RuntimeControllerConfig",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DrivingBootstrapController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.VehicleAccessController",
}

local expectedDisabledScripts = {
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Disabled",
	"ServerScriptService.NeoTokyoRacers.NeoTokyoRacersServer_Bootstrap_Disabled",
	"ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Shadow",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Shadow",
}

local report = {}
local function line(text)
	table.insert(report, text)
end

local activeScripts = {}
local unexpectedActive = {}
local disabledScripts = {}
local legacyNamedActive = {}
local legacyNamedDisabled = {}
local activeInsideExcluded = {}
local moduleCount = 0

for _, root in ipairs({ ServerScriptService, StarterPlayer, ReplicatedStorage, Workspace }) do
	for _, instance in ipairs(root:GetDescendants()) do
		if isScriptLike(instance) then
			local fullName = instance:GetFullName()
			if instance.Disabled then
				table.insert(disabledScripts, fullName)
				if string.find(instance.Name, "HOVER_RACING", 1, true) then
					table.insert(legacyNamedDisabled, fullName)
				end
			else
				table.insert(activeScripts, fullName)
				if underExcludedArea(instance) then
					table.insert(activeInsideExcluded, fullName)
				end
				if string.find(instance.Name, "HOVER_RACING", 1, true) then
					table.insert(legacyNamedActive, fullName)
				end
				if not approvedActiveScripts[fullName] then
					table.insert(unexpectedActive, fullName)
				end
			end
		elseif isModule(instance) then
			moduleCount += 1
		end
	end
end

table.sort(activeScripts)
table.sort(unexpectedActive)
table.sort(disabledScripts)
table.sort(legacyNamedActive)
table.sort(legacyNamedDisabled)
table.sort(activeInsideExcluded)

local missingPaths = {}
local presentPaths = {}
for _, path in ipairs(expectedPaths) do
	local exists = existsPath(path)
	if exists then
		table.insert(presentPaths, path)
	else
		table.insert(missingPaths, path)
	end
end

local enabledExpectedDisabled = {}
for _, path in ipairs(expectedDisabledScripts) do
	local exists, instance = existsPath(path)
	if exists and isScriptLike(instance) and not instance.Disabled then
		table.insert(enabledExpectedDisabled, path)
	end
end

local oldTrafficExists, oldTraffic = existsPath("ServerScriptService.Traffic Lights")
local trafficServiceExists, trafficService = existsPath("ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService")
local oldTrafficActive = oldTrafficExists and isScriptLike(oldTraffic) and not oldTraffic.Disabled
local newTrafficActive = trafficServiceExists and isScriptLike(trafficService) and not trafficService.Disabled

local archiveExists = ServerStorage:FindFirstChild("NeoTokyoRacers_LegacyArchive") ~= nil

line("# Neo Tokyo Racers Phase 11 Architecture Readiness Audit")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Read-only audit with one report write. No gameplay scripts were moved, renamed, disabled, enabled, deleted, cloned, or edited.")
line("")
line("## Summary")
line("")
line("- Expected architecture paths present: " .. tostring(#presentPaths) .. " / " .. tostring(#expectedPaths))
line("- Expected architecture paths missing: " .. tostring(#missingPaths))
line("- Active scripts found: " .. tostring(#activeScripts))
line("- Unexpected active scripts: " .. tostring(#unexpectedActive))
line("- Active scripts inside excluded Test + WIP Assets: " .. tostring(#activeInsideExcluded))
line("- Disabled scripts found: " .. tostring(#disabledScripts))
line("- ModuleScripts counted in audited roots: " .. tostring(moduleCount))
line("- Active legacy-named HOVER_RACING scripts still required: " .. tostring(#legacyNamedActive))
line("- Disabled legacy-named HOVER_RACING scripts: " .. tostring(#legacyNamedDisabled))
line("- Legacy archive exists: " .. tostring(archiveExists))
line("- Old traffic script active: " .. tostring(oldTrafficActive))
line("- New traffic service active: " .. tostring(newTrafficActive))
line("")

line("## Current Recommendation")
line("")
if #missingPaths > 0 or #unexpectedActive > 0 or #enabledExpectedDisabled > 0 then
	line("Status: Needs review before final naming cleanup.")
else
	line("Status: Scaffold looks ready. Do not rename live HOVER_RACING scripts yet; they are still the working owners until UI/server/runtime extraction is complete.")
end
line("")

line("## Missing Expected Architecture Paths")
line("")
if #missingPaths == 0 then
	line("- None.")
else
	for _, path in ipairs(missingPaths) do
		line("- " .. path)
	end
end
line("")

line("## Expected Disabled Scripts That Are Enabled")
line("")
if #enabledExpectedDisabled == 0 then
	line("- None.")
else
	for _, path in ipairs(enabledExpectedDisabled) do
		line("- " .. path)
	end
end
line("")

line("## Unexpected Active Scripts")
line("")
if #unexpectedActive == 0 then
	line("- None.")
else
	for _, path in ipairs(unexpectedActive) do
		line("- " .. path)
	end
end
line("")

line("## Active Legacy-Named Scripts Still Live")
line("")
if #legacyNamedActive == 0 then
	line("- None.")
else
	for _, path in ipairs(legacyNamedActive) do
		line("- " .. path)
	end
end
line("")

line("## Active Scripts Inside Excluded Test + WIP Assets")
line("")
if #activeInsideExcluded == 0 then
	line("- None.")
else
	for _, path in ipairs(activeInsideExcluded) do
		line("- " .. path)
	end
end
line("")

line("## Disabled Legacy-Named Scripts")
line("")
if #legacyNamedDisabled == 0 then
	line("- None.")
else
	for _, path in ipairs(legacyNamedDisabled) do
		line("- " .. path)
	end
end
line("")

line("## Present Expected Architecture Paths")
line("")
for _, path in ipairs(presentPaths) do
	line("- " .. path)
end
line("")

line("## Next Safe Steps")
line("")
line("1. Keep current live HOVER_RACING scripts until each replacement owner has been switched and tested.")
line("2. Extract UI, server actions, and runtime owners in separate future phases.")
line("3. Run this audit again after each live switch.")
line("4. Only perform final legacy renaming/removal when unexpected active scripts are zero and no live behaviour depends on HOVER_RACING names.")

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")
local reportValue = reportsFolder:FindFirstChild("Phase11_ArchitectureReadinessAudit")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase11_ArchitectureReadinessAudit_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase11_ArchitectureReadinessAudit"
	reportValue.Parent = reportsFolder
end
reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))

log("Audit complete. Report saved to " .. reportValue:GetFullName())
log("Expected paths missing: " .. tostring(#missingPaths) .. "; unexpected active scripts: " .. tostring(#unexpectedActive) .. "; expected-disabled enabled: " .. tostring(#enabledExpectedDisabled))
print(reportValue.Value)
