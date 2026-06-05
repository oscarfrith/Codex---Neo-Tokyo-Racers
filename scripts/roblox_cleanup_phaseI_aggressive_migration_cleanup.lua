-- Neo Tokyo Racers - Cleanup Phase I Aggressive Migration Cleanup
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Aggressively removes migration scaffolding clutter after Phase H has been
--   deleted and play-tested successfully.
--
-- This is intentionally more aggressive than Phase H.
--
-- Deletes:
--   - Old migration/cleanup report StringValues.
--   - Stale ReferenceOnly ObjectValues created during migration.
--   - MirrorOnly config folders/values created during early architecture phases.
--   - Non-live ScaffoldOnly / ShadowCopyOnly / SnapshotOnly scripts/modules.
--   - Empty placeholder folders left by the staged architecture.
--
-- Does NOT delete:
--   - Current active owner scripts.
--   - ReplicatedStorage.HOVER_RACING_V2_KIT.
--   - ReplicatedStorage.FarLOD5.
--   - Workspace.NeoTokyoRacersWorld.
--   - Workspace.HOVER_RACING_V2_WORLD.
--   - Workspace.Test + WIP Assets.
--   - StarterGui.NeoTokyoRacersUI.
--
-- Important:
--   The user confirmed a backup exists and requested a one-step aggressive pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_cleanup_phaseI_aggressive_migration_cleanup"

local function log(message)
	print("[NTR Cleanup Phase I] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	if ok then
		return result
	end
	return instance.Name
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. safeFullName(existing) .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No changes applied.")
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

local function isScriptLike(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript")
end

local function isCodeLike(instance)
	return isScriptLike(instance) or instance:IsA("ModuleScript")
end

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local protectedExactPaths = {
	["ReplicatedStorage.HOVER_RACING_V2_KIT"] = true,
	["ReplicatedStorage.FarLOD5"] = true,
	["ReplicatedStorage.Shared"] = true,
	["ReplicatedStorage.NeoTokyoRacers"] = true,
	["ServerScriptService.NeoTokyoRacers"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient"] = true,
	["StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"] = true,
	["StarterGui.NeoTokyoRacersUI"] = true,
	["Workspace.HOVER_RACING_V2_WORLD"] = true,
	["Workspace.NeoTokyoRacersWorld"] = true,
	["Workspace.Test + WIP Assets"] = true,
}

local protectedPrefixes = {
	"ReplicatedStorage.HOVER_RACING_V2_KIT.",
	"ReplicatedStorage.FarLOD5.",
	"ReplicatedStorage.Shared.",
	"StarterGui.NeoTokyoRacersUI.",
	"Workspace.HOVER_RACING_V2_WORLD.",
	"Workspace.NeoTokyoRacersWorld.",
	"Workspace.Test + WIP Assets.",
}

local protectedActiveOwners = {
	"ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled",
	"ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionService_Active",
	"ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active",
	"ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled",
	"StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview",
}

local protectedActiveOwnerSet = {}
for _, path in ipairs(protectedActiveOwners) do
	protectedActiveOwnerSet[path] = true
end

local function isProtected(instance)
	local path = safeFullName(instance)
	if protectedExactPaths[path] or protectedActiveOwnerSet[path] then
		return true
	end
	for _, prefix in ipairs(protectedPrefixes) do
		if startsWith(path, prefix) then
			return true
		end
	end
	return false
end

local function activeOwnersAreHealthy()
	local problems = {}
	for _, path in ipairs(protectedActiveOwners) do
		local instance = resolvePath(path)
		if not instance then
			table.insert(problems, path .. " missing")
		elseif isScriptLike(instance) and instance.Disabled then
			table.insert(problems, path .. " disabled")
		elseif not isScriptLike(instance) then
			table.insert(problems, path .. " is " .. instance.ClassName .. ", expected active Script/LocalScript")
		end
	end
	return #problems == 0, problems
end

local okOwners, ownerProblems = activeOwnersAreHealthy()
if not okOwners then
	error("Protected active owner check failed. No changes applied.\n" .. table.concat(ownerProblems, "\n"))
end

local roots = {
	ReplicatedStorage,
	ServerScriptService,
	StarterPlayer,
	StarterGui,
	Workspace,
}

local deleteQueue = {}
local queuedSet = {}

local function queue(instance, reason)
	if not instance or instance == game then
		return
	end

	local path = safeFullName(instance)
	if queuedSet[path] or isProtected(instance) then
		return
	end

	if isScriptLike(instance) and not instance.Disabled and not protectedActiveOwnerSet[path] then
		return
	end

	queuedSet[path] = true
	table.insert(deleteQueue, {
		instance = instance,
		path = path,
		reason = reason,
		depth = select(2, string.gsub(path, "%.", "")),
	})
end

local function hasAttribute(instance, name, expected)
	local value = instance:GetAttribute(name)
	if expected == nil then
		return value ~= nil
	end
	return value == expected
end

local function migrationStatusIsDeletable(instance)
	local status = instance:GetAttribute("MigrationStatus")
	return status == "ScaffoldOnly"
		or status == "ShadowCopyOnly"
		or status == "SnapshotOnly"
		or status == "DisabledFutureBootstrap"
end

local function isStarterPlayerScriptsPlaceholder(instance)
	local path = safeFullName(instance)
	return path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Bootstrap"
		or path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.ClientModules"
		or startsWith(path, "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.ClientModules.")
		or path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Camera"
		or path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Customisation"
		or path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Dealership"
		or path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Driving"
		or path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.HUD"
		or path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Mobile"
		or path == "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.VFX"
end

local function isServerPlaceholder(instance)
	local path = safeFullName(instance)
	return path == "ServerScriptService.NeoTokyoRacers.ServerModules"
		or startsWith(path, "ServerScriptService.NeoTokyoRacers.ServerModules.")
		or path == "ServerScriptService.NeoTokyoRacers.Services.Profile"
		or path == "ServerScriptService.NeoTokyoRacers.Services.World.Race"
end

local function isEmptyFolder(instance)
	return instance:IsA("Folder") and #instance:GetChildren() == 0
end

for _, root in ipairs(roots) do
	for _, instance in ipairs(root:GetDescendants()) do
		local path = safeFullName(instance)

		if path == "ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports" then
			queue(instance, "old migration reports")
		elseif path == "ReplicatedStorage.NeoTokyoRacers.Compatibility.CleanupReports" then
			queue(instance, "old cleanup reports; this script writes a fresh summary after deletion")
		elseif instance:IsA("ObjectValue") and hasAttribute(instance, "ReferenceOnly", true) then
			queue(instance, "stale migration reference ObjectValue")
		elseif instance:IsA("ObjectValue") and (
			string.find(instance.Name, "CurrentLive", 1, true)
				or string.find(instance.Name, "Previous", 1, true)
				or string.find(instance.Name, "Shadow", 1, true)
			) then
			queue(instance, "stale migration reference ObjectValue")
		elseif hasAttribute(instance, "MirrorOnly", true) then
			queue(instance, "mirror-only generated config/reference copy")
		elseif isCodeLike(instance) and migrationStatusIsDeletable(instance) and instance:GetAttribute("LiveEnabled") ~= true then
			queue(instance, "non-live scaffold/shadow/snapshot code")
		elseif isStarterPlayerScriptsPlaceholder(instance) then
			queue(instance, "empty/staged client placeholder folder")
		elseif isServerPlaceholder(instance) then
			queue(instance, "empty/staged server placeholder folder")
		elseif isEmptyFolder(instance) and (
			startsWith(path, "ServerScriptService.NeoTokyoRacers.ServerModules.")
				or startsWith(path, "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.ClientModules.")
			) then
			queue(instance, "empty placeholder subfolder")
		end
	end
end

table.sort(deleteQueue, function(a, b)
	if a.depth == b.depth then
		return a.path > b.path
	end
	return a.depth > b.depth
end)

local deleted = {}
local skipped = {}

for _, item in ipairs(deleteQueue) do
	local instance = item.instance
	if instance.Parent == nil then
		table.insert(skipped, item.path .. " -- parent already deleted")
	elseif isProtected(instance) then
		table.insert(skipped, item.path .. " -- protected")
	elseif isScriptLike(instance) and not instance.Disabled and not protectedActiveOwnerSet[item.path] then
		table.insert(skipped, item.path .. " -- enabled script")
	else
		instance:Destroy()
		table.insert(deleted, item.path .. " -- " .. item.reason)
	end
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local cleanupReports = folder(compatibility, "CleanupReports")

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

line("# Neo Tokyo Racers Cleanup Phase I Aggressive Migration Cleanup")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Aggressive one-step cleanup requested by user after confirming a backup exists.")
line("")
line("## Summary")
line("")
line("- Queued targets: " .. tostring(#deleteQueue))
line("- Deleted: " .. tostring(#deleted))
line("- Skipped: " .. tostring(#skipped))
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

listSection("Deleted", deleted)
listSection("Skipped", skipped)

line("## Protected Live Systems")
line("")
for _, path in ipairs(protectedActiveOwners) do
	line("- " .. path)
end
line("")

line("## Next Step")
line("")
line("Play-test fresh, then run Cleanup Phase G again. If active scripts remain at 11 and unexpected active scripts remain 0, this cleanup is stable.")

local reportValue = Instance.new("StringValue")
reportValue.Name = "CleanupPhaseI_AggressiveMigrationCleanup"
reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("DeletedCount", #deleted)
reportValue:SetAttribute("SkippedCount", #skipped)
reportValue.Parent = cleanupReports

log("Aggressive cleanup complete.")
log("Deleted: " .. tostring(#deleted) .. "; skipped: " .. tostring(#skipped))
log("Report: " .. reportValue:GetFullName())
print(reportValue.Value)
