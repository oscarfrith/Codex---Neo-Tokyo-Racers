-- Neo Tokyo Racers - Cleanup Phase H Delete Legacy Inactive Items
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Deletes only the exact inactive legacy/report/rollback paths confirmed by
--   Cleanup Phase G on 2026-05-29.
--
-- How to use:
--   1. Keep MODE = "DRY_RUN" first and run once.
--   2. If the dry run looks correct, set MODE = "DELETE" and run again.
--   3. Play-test after deletion.
--
-- Safe effects:
--   - In DRY_RUN, changes nothing and reports what would be deleted.
--   - In DELETE, destroys only exact allowlisted paths below.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.CleanupReports.
--
-- Does NOT:
--   - Touch Workspace.Test + WIP Assets.
--   - Touch HOVER_RACING_V2_WORLD, spawn points, preview pads, live vehicle runtime folders, city blocks, FarLOD5, or HOVER_RACING_V2_KIT.
--   - Touch current active NeoTokyoRacers owner scripts.

local MODE = "DRY_RUN" -- "DRY_RUN" or "DELETE"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_cleanup_phaseH_delete_legacy_inactive_items"

local function log(message)
	print("[NTR Cleanup Phase H] " .. message)
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

local function resolvePath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return nil
		end
	end
	return current
end

local protectedExactPaths = {
	["ReplicatedStorage.HOVER_RACING_V2_KIT"] = true,
	["ReplicatedStorage.FarLOD5"] = true,
	["ReplicatedStorage.NeoTokyoRacers"] = true,
	["ServerScriptService.NeoTokyoRacers"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient"] = true,
	["Workspace.HOVER_RACING_V2_WORLD"] = true,
	["Workspace.NeoTokyoRacersWorld"] = true,
	["Workspace.Test + WIP Assets"] = true,
}

local protectedActiveOwnerPaths = {
	["ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionService_Active"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"] = true,
	["StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"] = true,
}

local deleteTargets = {
	-- Old standalone report folders superseded by NeoTokyoRacers.Compatibility reports.
	{ path = "ReplicatedStorage.NTR_AUDIT_REPORTS", expectedClass = "Folder", reason = "old standalone audit report folder" },
	{ path = "ReplicatedStorage.NTR_INVENTORY_REPORTS", expectedClass = "Folder", reason = "old standalone inventory report folder" },

	-- Legacy server/script containers replaced by active NeoTokyoRacers services.
	{ path = "ServerScriptService.HOVER_RACING_SERVER", expectedClass = "Folder", reason = "empty/legacy server script container" },
	{ path = "ServerScriptService.HOVER_RACING_V2_SERVER", expectedClass = "Folder", reason = "legacy server owner container replaced by GarageActionController_Shadow_Disabled and DriverSeatPositionService_Active" },
	{ path = "ServerScriptService.Lighting", expectedClass = "Folder", reason = "legacy lighting owner container replaced by LightingService_Active" },
	{ path = "ServerScriptService.Traffic Lights", expectedClass = "Script", mustBeDisabled = true, reason = "legacy traffic script replaced by TrafficLightService" },

	-- Legacy archived rollback folder now covered by the user's backup.
	{ path = "ServerStorage.NeoTokyoRacers_LegacyArchive", expectedClass = "Folder", reason = "legacy disabled-script archive" },

	-- Disabled future/rollback scripts no longer needed after confirmed owner switches.
	{ path = "ServerScriptService.NeoTokyoRacers.NeoTokyoRacersServer_Bootstrap_Disabled", expectedClass = "Script", mustBeDisabled = true, reason = "disabled future server bootstrap rollback script" },
	{ path = "ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Shadow", expectedClass = "Script", mustBeDisabled = true, reason = "disabled lighting shadow rollback script" },
	{ path = "ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService_Shadow", expectedClass = "Script", mustBeDisabled = true, reason = "disabled traffic shadow rollback script" },
	{ path = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Shadow", expectedClass = "LocalScript", mustBeDisabled = true, reason = "disabled LOD shadow rollback script" },
	{ path = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Disabled", expectedClass = "LocalScript", mustBeDisabled = true, reason = "disabled future client bootstrap rollback script" },

	-- Legacy client owner scripts replaced by active NeoTokyoRacersClient owners.
	{ path = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_CLIENT", expectedClass = "Folder", reason = "old empty/staged legacy client folder" },
	{ path = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client", expectedClass = "LocalScript", mustBeDisabled = true, reason = "legacy main client owner replaced by NeoTokyoRacersClient_Bootstrap_Shadow_Disabled" },
	{ path = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly", expectedClass = "LocalScript", mustBeDisabled = true, reason = "legacy thrust preview owner replaced by ThrustPreviewController_Active" },
	{ path = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime", expectedClass = "LocalScript", mustBeDisabled = true, reason = "legacy VFX runtime owner replaced by RuntimeVFXController_Active" },
	{ path = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls", expectedClass = "LocalScript", mustBeDisabled = true, reason = "legacy mobile controls owner replaced by MobileDriveControlsController_Active" },
	{ path = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor", expectedClass = "LocalScript", mustBeDisabled = true, reason = "legacy drive HUD owner replaced by DriveHudController_Active" },
	{ path = "StarterPlayer.StarterPlayerScripts.LOD System", expectedClass = "LocalScript", mustBeDisabled = true, reason = "legacy LOD owner replaced by LODClient_Active" },
}

if MODE ~= "DRY_RUN" and MODE ~= "DELETE" then
	error("MODE must be DRY_RUN or DELETE. No changes applied.")
end

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Cleanup Phase H Legacy Inactive Delete")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Mode: " .. MODE)
line("")

local missing = {}
local blocked = {}
local deleted = {}
local wouldDelete = {}

for protectedPath in pairs(protectedActiveOwnerPaths) do
	local instance = resolvePath(protectedPath)
	if not instance or not isScriptLike(instance) or instance.Disabled then
		table.insert(blocked, protectedPath .. " -- protected active owner missing or disabled")
	end
end

for _, target in ipairs(deleteTargets) do
	local path = target.path
	local instance = resolvePath(path)

	if not instance then
		table.insert(missing, path .. " -- already missing")
	elseif protectedExactPaths[path] or protectedActiveOwnerPaths[path] then
		table.insert(blocked, path .. " -- path is protected")
	elseif instance.ClassName ~= target.expectedClass then
		table.insert(blocked, path .. " -- expected " .. target.expectedClass .. ", found " .. instance.ClassName)
	elseif target.mustBeDisabled and (not isScriptLike(instance) or not instance.Disabled) then
		table.insert(blocked, path .. " -- expected disabled script before deletion")
	else
		if MODE == "DELETE" then
			instance:Destroy()
			table.insert(deleted, path .. " -- " .. target.reason)
		else
			table.insert(wouldDelete, path .. " -- " .. target.reason)
		end
	end
end

table.sort(missing)
table.sort(blocked)
table.sort(deleted)
table.sort(wouldDelete)

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsRoot = folder(compatibility, "CleanupReports")

line("## Summary")
line("")
line("- Targets configured: " .. tostring(#deleteTargets))
line("- Would delete: " .. tostring(#wouldDelete))
line("- Deleted: " .. tostring(#deleted))
line("- Missing/already gone: " .. tostring(#missing))
line("- Blocked: " .. tostring(#blocked))
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

listSection("Would Delete", wouldDelete)
listSection("Deleted", deleted)
listSection("Missing / Already Gone", missing)
listSection("Blocked", blocked)

if #blocked > 0 then
	line("## Result")
	line("")
	line("Blocked items were found. Review before running DELETE again.")
elseif MODE == "DRY_RUN" then
	line("## Result")
	line("")
	line("Dry run complete. If the Would Delete list looks correct, set MODE to DELETE and run again.")
else
	line("## Result")
	line("")
	line("Delete complete. Play-test fresh, then run the Phase G audit again to confirm cleanup.")
end

local reportValue = reportsRoot:FindFirstChild("CleanupPhaseH_DeleteLegacyInactiveItems")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "CleanupPhaseH_DeleteLegacyInactiveItems_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "CleanupPhaseH_DeleteLegacyInactiveItems"
	reportValue.Parent = reportsRoot
end

reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("Mode", MODE)
reportValue:SetAttribute("DeletedCount", #deleted)
reportValue:SetAttribute("WouldDeleteCount", #wouldDelete)
reportValue:SetAttribute("BlockedCount", #blocked)

log("Mode: " .. MODE)
log("Would delete: " .. tostring(#wouldDelete) .. "; deleted: " .. tostring(#deleted) .. "; blocked: " .. tostring(#blocked) .. "; missing: " .. tostring(#missing))
log("Report: " .. reportValue:GetFullName())
print(reportValue.Value)
