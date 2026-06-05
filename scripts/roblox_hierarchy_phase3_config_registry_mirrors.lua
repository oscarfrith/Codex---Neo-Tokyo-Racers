-- Neo Tokyo Racers - Phase 3 Config Registry + Mirrors
-- Paste this whole script into the Roblox Studio Command Bar in Edit mode.
--
-- Run after:
-- 1) scripts/roblox_hierarchy_phase1_architecture_resolver.lua
-- 2) scripts/roblox_hierarchy_phase2_live_references_registry.lua
--
-- What this does:
-- - Organises the future config layer under ReplicatedStorage.NeoTokyoRacers.Shared.Config.
-- - Adds ObjectValue references to the current live/authoritative config folders.
-- - Refreshes generated mirror folders for easy inspection.
-- - Adds a ConfigRegistry module for future targeted migrations.
--
-- What this intentionally does NOT do:
-- - It does not change any live config value.
-- - It does not switch live scripts to the new config paths.
-- - It does not move, rename, disable, delete, or edit current gameplay scripts.
-- - It does not touch Workspace["Test + WIP Assets"].

local MIGRATION_ID = "NTR_Phase3_ConfigRegistryMirrors_2026_05_28"
local MIGRATION_LABEL = "Neo Tokyo Racers Phase 3 Config Registry + Mirrors"

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayer = game:GetService("StarterPlayer"),
	StarterGui = game:GetService("StarterGui"),
	Workspace = game:GetService("Workspace"),
	Lighting = game:GetService("Lighting"),
	ServerStorage = game:GetService("ServerStorage"),
}

local createdCount = 0
local updatedCount = 0
local skippedCount = 0
local warnings = {}

local function log(message)
	print("[NTR Phase 3] " .. tostring(message))
end

local function warnLog(message)
	local text = "[NTR Phase 3 WARNING] " .. tostring(message)
	table.insert(warnings, text)
	warn(text)
end

local function splitPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end

local function findPath(path)
	local parts = splitPath(path)
	local current = services[parts[1]]
	if not current then
		return nil
	end

	for index = 2, #parts do
		current = current:FindFirstChild(parts[index])
		if not current then
			return nil
		end
	end

	return current
end

local function ensureFolder(parent, name)
	if not parent then
		warnLog("Cannot create folder '" .. tostring(name) .. "' because parent is missing.")
		skippedCount = skippedCount + 1
		return nil
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("Folder") then
			return existing
		end

		warnLog(parent:GetFullName() .. "." .. name .. " already exists as " .. existing.ClassName .. "; skipped folder creation.")
		skippedCount = skippedCount + 1
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	folder:SetAttribute("CreatedBy", MIGRATION_ID)
	createdCount = createdCount + 1
	return folder
end

local function ensureFolderPath(root, pathParts)
	local current = root
	for _, name in ipairs(pathParts) do
		current = ensureFolder(current, name)
		if not current then
			return nil
		end
	end
	return current
end

local function ensureStringValue(parent, name, value)
	if not parent then
		warnLog("Cannot create StringValue '" .. tostring(name) .. "' because parent is missing.")
		skippedCount = skippedCount + 1
		return nil
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("StringValue") then
			if existing.Value ~= value then
				existing.Value = value
				updatedCount = updatedCount + 1
			end
			existing:SetAttribute("UpdatedBy", MIGRATION_ID)
			return existing
		end

		warnLog(parent:GetFullName() .. "." .. name .. " already exists as " .. existing.ClassName .. "; skipped StringValue creation.")
		skippedCount = skippedCount + 1
		return nil
	end

	local valueObject = Instance.new("StringValue")
	valueObject.Name = name
	valueObject.Value = value
	valueObject.Parent = parent
	valueObject:SetAttribute("CreatedBy", MIGRATION_ID)
	createdCount = createdCount + 1
	return valueObject
end

local function ensureObjectValue(parent, name, targetPath)
	if not parent then
		warnLog("Cannot create ObjectValue '" .. tostring(name) .. "' because parent is missing.")
		skippedCount = skippedCount + 1
		return nil
	end

	local target = findPath(targetPath)
	if not target then
		warnLog("Live config reference skipped because target is missing: " .. targetPath)
		ensureStringValue(parent, name .. "_MissingPath", targetPath)
		skippedCount = skippedCount + 1
		return nil
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("ObjectValue") then
			if existing.Value ~= target then
				existing.Value = target
				updatedCount = updatedCount + 1
			end
			existing:SetAttribute("UpdatedBy", MIGRATION_ID)
			existing:SetAttribute("LivePath", targetPath)
			existing:SetAttribute("ReferenceOnly", true)
			return existing
		end

		warnLog(parent:GetFullName() .. "." .. name .. " already exists as " .. existing.ClassName .. "; skipped ObjectValue creation.")
		skippedCount = skippedCount + 1
		return nil
	end

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = name
	objectValue.Value = target
	objectValue.Parent = parent
	objectValue:SetAttribute("CreatedBy", MIGRATION_ID)
	objectValue:SetAttribute("LivePath", targetPath)
	objectValue:SetAttribute("ReferenceOnly", true)
	createdCount = createdCount + 1
	return objectValue
end

local function ensureModuleScript(parent, name, source)
	if not parent then
		warnLog("Cannot create ModuleScript '" .. tostring(name) .. "' because parent is missing.")
		skippedCount = skippedCount + 1
		return nil
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("ModuleScript") then
			if existing.Source ~= source then
				existing.Source = source
				updatedCount = updatedCount + 1
			end
			existing:SetAttribute("UpdatedBy", MIGRATION_ID)
			return existing
		end

		warnLog(parent:GetFullName() .. "." .. name .. " already exists as " .. existing.ClassName .. "; skipped ModuleScript creation.")
		skippedCount = skippedCount + 1
		return nil
	end

	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = name
	moduleScript.Source = source
	moduleScript.Parent = parent
	moduleScript:SetAttribute("CreatedBy", MIGRATION_ID)
	createdCount = createdCount + 1
	return moduleScript
end

local function markGeneratedMirror(instance, sourcePath)
	instance:SetAttribute("GeneratedBy", MIGRATION_ID)
	instance:SetAttribute("MirrorOnly", true)
	instance:SetAttribute("DoNotEditYet", true)
	instance:SetAttribute("SourcePath", sourcePath)

	for _, descendant in ipairs(instance:GetDescendants()) do
		descendant:SetAttribute("GeneratedBy", MIGRATION_ID)
		descendant:SetAttribute("MirrorOnly", true)
		descendant:SetAttribute("DoNotEditYet", true)
		descendant:SetAttribute("SourcePath", sourcePath)

		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		end
	end
end

local function mirrorObject(sourcePath, targetParent, mirrorName)
	if not targetParent then
		warnLog("Mirror skipped because target parent is missing for " .. sourcePath)
		skippedCount = skippedCount + 1
		return nil
	end

	local source = findPath(sourcePath)
	if not source then
		warnLog("Mirror skipped because source is missing: " .. sourcePath)
		ensureStringValue(targetParent, mirrorName .. "_MissingSourcePath", sourcePath)
		skippedCount = skippedCount + 1
		return nil
	end

	local existing = targetParent:FindFirstChild(mirrorName)
	if existing then
		if existing:GetAttribute("MirrorOnly") == true or existing:GetAttribute("GeneratedBy") == MIGRATION_ID then
			existing:Destroy()
			updatedCount = updatedCount + 1
		else
			warnLog("Mirror target exists and is not marked generated, left alone: " .. existing:GetFullName())
			skippedCount = skippedCount + 1
			return existing
		end
	end

	local ok, clone = pcall(function()
		return source:Clone()
	end)

	if not ok or not clone then
		warnLog("Mirror skipped because source could not be cloned: " .. sourcePath)
		skippedCount = skippedCount + 1
		return nil
	end

	clone.Name = mirrorName
	markGeneratedMirror(clone, sourcePath)
	clone.Parent = targetParent
	createdCount = createdCount + 1
	return clone
end

local replicatedStorage = services.ReplicatedStorage
local ntrRoot = replicatedStorage:FindFirstChild("NeoTokyoRacers")
if not ntrRoot then
	ntrRoot = ensureFolder(replicatedStorage, "NeoTokyoRacers")
end

local sharedRoot = ensureFolder(ntrRoot, "Shared")
local configRoot = ensureFolder(sharedRoot, "Config")
local modulesRoot = ensureFolder(sharedRoot, "Modules")
local dataModulesRoot = ensureFolderPath(modulesRoot, {"Data"})
local compatibilityRoot = ensureFolder(ntrRoot, "Compatibility")
local reportsRoot = ensureFolder(ntrRoot, "MigrationReports")

local configFolders = {
	Driving = ensureFolder(configRoot, "Driving"),
	Camera = ensureFolder(configRoot, "Camera"),
	UI = ensureFolder(configRoot, "UI"),
	Economy = ensureFolder(configRoot, "Economy"),
	VFX = ensureFolder(configRoot, "VFX"),
	Vehicles = ensureFolder(configRoot, "Vehicles"),
	World = ensureFolder(configRoot, "World"),
	Racing = ensureFolder(configRoot, "Racing"),
	Mobile = ensureFolder(configRoot, "Mobile"),
	Diagnostics = ensureFolder(configRoot, "Diagnostics"),
}

configFolders.WorldLighting = ensureFolderPath(configFolders.World, {"Lighting"})
configFolders.WorldLOD = ensureFolderPath(configFolders.World, {"LOD"})
configFolders.WorldTraffic = ensureFolderPath(configFolders.World, {"Traffic"})

for name, folder in pairs(configFolders) do
	if folder then
		folder:SetAttribute("ConfigLayerPhase", "Phase3")
		folder:SetAttribute("LiveLegacyConfigStillAuthoritative", true)
		folder:SetAttribute("CreatedOrUpdatedBy", MIGRATION_ID)
		ensureStringValue(folder, "README_" .. name, table.concat({
			"This is part of the future Neo Tokyo Racers config layer.",
			"Current live gameplay still reads the legacy HOVER_RACING_V2 config unless a specific system has been migrated.",
			"Objects ending in _CurrentLive are references to the current authoritative source.",
			"Objects ending in _Mirror are generated inspection copies and should not be edited yet."
		}, "\n"))
	end
end

ensureStringValue(configRoot, "README_ConfigLayer", table.concat({
	"Phase 3 config layer.",
	"Live legacy config remains authoritative for now.",
	"Use ConfigRegistry to find current live config paths and generated mirrors.",
	"Do not switch live scripts to these folders until the relevant system is migrated and play-tested."
}, "\n"))

local configDefinitions = {
	{
		key = "DrivingMechanics",
		displayName = "Driving Mechanics",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_MECHANICS_EditAttributes",
		targetFolder = configFolders.Driving,
		liveReferenceName = "DrivingMechanics_CurrentLive",
		mirrorName = "DrivingMechanics_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Primary editable driving attributes.",
	},
	{
		key = "HoverWobble",
		displayName = "Hover Wobble",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.HOVER_WOBBLE_EditAttributes",
		targetFolder = configFolders.Driving,
		liveReferenceName = "HoverWobble_CurrentLive",
		mirrorName = "HoverWobble_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Low-speed hover wobble tuning.",
	},
	{
		key = "DrivingCameraAssist",
		displayName = "Driving Camera Assist",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_CAMERA_ASSIST_EditAttributes",
		targetFolder = configFolders.Camera,
		liveReferenceName = "DrivingCameraAssist_CurrentLive",
		mirrorName = "DrivingCameraAssist_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Camera FOV, height, distance, acceleration/boost camera feel.",
	},
	{
		key = "UITheme",
		displayName = "UI Theme",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename",
		targetFolder = configFolders.UI,
		liveReferenceName = "UITheme_CurrentLive",
		mirrorName = "UITheme_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Current dark futuristic UI theme values.",
	},
	{
		key = "PaintPresets",
		displayName = "Paint Presets",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.PAINT_PRESETS_EditColoursHere",
		targetFolder = configFolders.UI,
		liveReferenceName = "PaintPresets_CurrentLive",
		mirrorName = "PaintPresets_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Default colour swatches / paint presets.",
	},
	{
		key = "GameBalance",
		displayName = "Game Balance",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.01_GAME_BALANCE_Editable",
		targetFolder = configFolders.Economy,
		liveReferenceName = "GameBalance_CurrentLive",
		mirrorName = "GameBalance_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Economy, module prices, and broad gameplay balance values.",
	},
	{
		key = "DriverSeatPosition",
		displayName = "Driver Seat Position",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.DRIVER_SEAT_POSITION_DoNotRename",
		targetFolder = configFolders.Vehicles,
		liveReferenceName = "DriverSeatPosition_CurrentLive",
		mirrorName = "DriverSeatPosition_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Driver seat/cockpit position tuning.",
	},
	{
		key = "StabiliserVFXDirection",
		displayName = "Stabiliser VFX Direction",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.STABILISER_VFX_DIRECTION_DoNotRename",
		targetFolder = configFolders.VFX,
		liveReferenceName = "StabiliserVFXDirection_CurrentLive",
		mirrorName = "StabiliserVFXDirection_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Left/right stabiliser VFX direction markers.",
	},
	{
		key = "LightingPresets",
		displayName = "Lighting Presets",
		livePath = "ReplicatedStorage.Shared.LightingPresets",
		targetFolder = configFolders.WorldLighting,
		liveReferenceName = "LightingPresets_CurrentLive",
		mirrorName = "LightingPresets_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Day/night lighting preset modules.",
	},
	{
		key = "SkyPresets",
		displayName = "Sky Presets",
		livePath = "ReplicatedStorage.Shared.SkyPresets",
		targetFolder = configFolders.WorldLighting,
		liveReferenceName = "SkyPresets_CurrentLive",
		mirrorName = "SkyPresets_Mirror",
		status = "LiveLegacyAuthoritative",
		notes = "Skybox preset storage.",
	},
	{
		key = "LODLivePaths",
		displayName = "LOD Live Paths",
		livePath = "ReplicatedStorage.FarLOD5",
		targetFolder = configFolders.WorldLOD,
		liveReferenceName = "FarLOD5_CurrentLive",
		mirrorName = nil,
		status = "LiveLegacyAuthoritativeReferenceOnly",
		notes = "FarLOD5 is an asset root, so Phase 3 references it but does not clone it.",
	},
	{
		key = "GeneratedCityBlocksLivePath",
		displayName = "Generated City Blocks Live Path",
		livePath = "Workspace.GeneratedCityBlocks",
		targetFolder = configFolders.WorldLOD,
		liveReferenceName = "GeneratedCityBlocks_CurrentLive",
		mirrorName = nil,
		status = "LiveLegacyAuthoritativeReferenceOnly",
		notes = "GeneratedCityBlocks is a world asset root, so Phase 3 references it but does not clone it.",
	},
}

log("Creating config live references and generated mirrors.")
for _, definition in ipairs(configDefinitions) do
	local targetFolder = definition.targetFolder
	if targetFolder then
		ensureObjectValue(targetFolder, definition.liveReferenceName, definition.livePath)
		ensureStringValue(targetFolder, definition.key .. "_LivePath", definition.livePath)
		ensureStringValue(targetFolder, definition.key .. "_Status", definition.status)
		ensureStringValue(targetFolder, definition.key .. "_Notes", definition.notes)

		if definition.mirrorName then
			mirrorObject(definition.livePath, targetFolder, definition.mirrorName)
		end
	else
		warnLog("Config definition skipped because target folder is missing: " .. definition.key)
	end
end

local configRegistrySource = [==[
-- Neo Tokyo Racers Config Registry
-- Added by Phase 3 config migration.
--
-- Current live scripts still read the legacy HOVER_RACING_V2 config paths.
-- This registry documents the live authoritative config and generated mirror locations.

local ConfigRegistry = {}

ConfigRegistry.Version = "Phase3_2026_05_28"
ConfigRegistry.LiveLegacyConfigStillAuthoritative = true

ConfigRegistry.Configs = {
	DrivingMechanics = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_MECHANICS_EditAttributes",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving.DrivingMechanics_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving",
		description = "Primary editable driving attributes.",
	},
	HoverWobble = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.HOVER_WOBBLE_EditAttributes",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving.HoverWobble_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving",
		description = "Low-speed hover wobble tuning.",
	},
	DrivingCameraAssist = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_CAMERA_ASSIST_EditAttributes",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Camera.DrivingCameraAssist_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Camera",
		description = "Camera FOV, height, distance, acceleration/boost camera feel.",
	},
	UITheme = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI.UITheme_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI",
		description = "Current UI theme values.",
	},
	PaintPresets = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.PAINT_PRESETS_EditColoursHere",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI.PaintPresets_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI",
		description = "Default colour swatches / paint presets.",
	},
	GameBalance = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.01_GAME_BALANCE_Editable",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Economy.GameBalance_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Economy",
		description = "Economy, module prices, and broad gameplay balance values.",
	},
	DriverSeatPosition = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.DRIVER_SEAT_POSITION_DoNotRename",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Vehicles.DriverSeatPosition_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Vehicles",
		description = "Driver seat/cockpit position tuning.",
	},
	StabiliserVFXDirection = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.STABILISER_VFX_DIRECTION_DoNotRename",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.VFX.StabiliserVFXDirection_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.VFX",
		description = "Left/right stabiliser VFX direction markers.",
	},
	LightingPresets = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.Shared.LightingPresets",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting.LightingPresets_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting",
		description = "Day/night lighting preset modules.",
	},
	SkyPresets = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.Shared.SkyPresets",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting.SkyPresets_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting",
		description = "Skybox preset storage.",
	},
	FarLOD5 = {
		status = "LiveLegacyAuthoritativeReferenceOnly",
		livePath = "ReplicatedStorage.FarLOD5",
		mirrorPath = nil,
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.LOD",
		description = "FarLOD5 asset root. Referenced only, not mirrored.",
	},
	GeneratedCityBlocks = {
		status = "LiveLegacyAuthoritativeReferenceOnly",
		livePath = "Workspace.GeneratedCityBlocks",
		mirrorPath = nil,
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.LOD",
		description = "Generated city block root. Referenced only, not mirrored.",
	},
}

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayer = game:GetService("StarterPlayer"),
	StarterGui = game:GetService("StarterGui"),
	Workspace = game:GetService("Workspace"),
	Lighting = game:GetService("Lighting"),
	ServerStorage = game:GetService("ServerStorage"),
}

local function splitPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end

local function resolvePath(path)
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local parts = splitPath(path)
	local current = services[parts[1]]
	if not current then
		return nil
	end

	for index = 2, #parts do
		current = current:FindFirstChild(parts[index])
		if not current then
			return nil
		end
	end

	return current
end

function ConfigRegistry.Get(configKey)
	return ConfigRegistry.Configs[configKey]
end

function ConfigRegistry.List()
	local keys = {}
	for key in pairs(ConfigRegistry.Configs) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function ConfigRegistry.ResolveLive(configKey)
	local config = ConfigRegistry.Configs[configKey]
	if not config then
		return nil
	end
	return resolvePath(config.livePath)
end

function ConfigRegistry.ResolveMirror(configKey)
	local config = ConfigRegistry.Configs[configKey]
	if not config or not config.mirrorPath then
		return nil
	end
	return resolvePath(config.mirrorPath)
end

function ConfigRegistry.ResolveTargetFolder(configKey)
	local config = ConfigRegistry.Configs[configKey]
	if not config then
		return nil
	end
	return resolvePath(config.targetFolder)
end

return ConfigRegistry
]==]

ensureModuleScript(configRoot, "ConfigRegistry", configRegistrySource)
ensureModuleScript(dataModulesRoot, "ConfigRegistry", configRegistrySource)

ensureStringValue(compatibilityRoot, "README_ConfigRegistry", table.concat({
	"Phase 3 added ConfigRegistry.",
	"Live scripts still read legacy config paths for now.",
	"Use ConfigRegistry for future targeted migrations instead of hard-coding HOVER_RACING_V2 paths.",
	"Do not edit generated _Mirror folders yet; edit current live config until a system is explicitly migrated."
}, "\n"))

local reportLines = {
	MIGRATION_LABEL,
	"Status: complete",
	"Created/refreshed Phase 3 config folders, live references, generated mirrors, and ConfigRegistry.",
	"Current live legacy config remains authoritative.",
	"No live gameplay scripts were changed.",
	"No live config values were changed.",
	"No assets or world folders were moved.",
	"Workspace.Test + WIP Assets was not touched.",
	"",
	"Config definitions processed: " .. tostring(#configDefinitions),
	"Created objects: " .. tostring(createdCount),
	"Updated objects: " .. tostring(updatedCount),
	"Skipped objects: " .. tostring(skippedCount),
	"Warnings: " .. tostring(#warnings),
	"",
	"Next recommended step:",
	"Play-test once. Then choose the first low-risk system to migrate to ConfigRegistry, preferably lighting or traffic lights.",
}

local reportText = table.concat(reportLines, "\n")
ensureStringValue(reportsRoot, "Phase3_Config_Registry_Mirrors_Report", reportText)

log("Complete.")
log("Created: " .. tostring(createdCount) .. " | Updated: " .. tostring(updatedCount) .. " | Skipped: " .. tostring(skippedCount) .. " | Warnings: " .. tostring(#warnings))

if #warnings > 0 then
	warnLog("Completed with warnings. Config mirrors/references are bridge objects only; check report before using them.")
end

print("Neo Tokyo Racers Phase 3 config registry + mirrors complete. Play-test once, then migrate one low-risk system to ConfigRegistry.")
