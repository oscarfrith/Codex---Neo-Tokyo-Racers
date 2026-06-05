-- Neo Tokyo Racers - Phase 2 Live References + Registry
-- Paste this whole script into the Roblox Studio Command Bar in Edit mode.
--
-- Run this after Phase 1:
-- scripts/roblox_hierarchy_phase1_architecture_resolver.lua
--
-- What this does:
-- - Adds ObjectValue references from the new NeoTokyoRacers architecture to current live systems.
-- - Adds a LiveSystemRegistry module for future migrations and debugging.
-- - Adds small README/report values so the hierarchy explains itself in Studio.
--
-- What this intentionally does NOT do:
-- - It does not move, rename, disable, delete, clone, or replace live scripts/assets.
-- - It does not change any current gameplay behaviour.
-- - It does not touch Workspace["Test + WIP Assets"].

local MIGRATION_ID = "NTR_Phase2_LiveReferencesRegistry_2026_05_28"
local MIGRATION_LABEL = "Neo Tokyo Racers Phase 2 Live References + Registry"

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayer = game:GetService("StarterPlayer"),
	StarterGui = game:GetService("StarterGui"),
	Workspace = game:GetService("Workspace"),
	Lighting = game:GetService("Lighting"),
}

local createdCount = 0
local updatedCount = 0
local skippedCount = 0
local warnings = {}

local function log(message)
	print("[NTR Phase 2] " .. tostring(message))
end

local function warnLog(message)
	local text = "[NTR Phase 2 WARNING] " .. tostring(message)
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
		warnLog("Cannot create folder '" .. tostring(name) .. "' because the parent was missing.")
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
		warnLog("Cannot create StringValue '" .. tostring(name) .. "' because the parent was missing.")
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
		warnLog("Cannot create ObjectValue '" .. tostring(name) .. "' because the parent was missing.")
		skippedCount = skippedCount + 1
		return nil
	end

	local target = findPath(targetPath)
	if not target then
		warnLog("Live reference skipped because target was missing: " .. targetPath)
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
		warnLog("Cannot create ModuleScript '" .. tostring(name) .. "' because the parent was missing.")
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

local replicatedStorage = services.ReplicatedStorage
local starterPlayerScripts = services.StarterPlayer:WaitForChild("StarterPlayerScripts")

local ntrRoot = replicatedStorage:FindFirstChild("NeoTokyoRacers")
if not ntrRoot then
	warnLog("Phase 1 root was missing, creating minimum ReplicatedStorage.NeoTokyoRacers root.")
	ntrRoot = ensureFolder(replicatedStorage, "NeoTokyoRacers")
end

local sharedRoot = ensureFolder(ntrRoot, "Shared")
local sharedRemotes = ensureFolder(sharedRoot, "Remotes")
local sharedModules = ensureFolder(sharedRoot, "Modules")
local assetsRoot = ensureFolder(ntrRoot, "Assets")
local compatibilityRoot = ensureFolder(ntrRoot, "Compatibility")
local reportsRoot = ensureFolder(ntrRoot, "MigrationReports")

local serverRoot = ensureFolder(services.ServerScriptService, "NeoTokyoRacers")
local serverServices = ensureFolder(serverRoot, "Services")
local serverModules = ensureFolder(serverRoot, "ServerModules")

local clientRoot = ensureFolder(starterPlayerScripts, "NeoTokyoRacersClient")
local clientControllers = ensureFolder(clientRoot, "Controllers")
local clientModules = ensureFolder(clientRoot, "ClientModules")

local worldRoot = ensureFolder(services.Workspace, "NeoTokyoRacersWorld")

local folders = {
	RemotesGarage = ensureFolderPath(sharedRemotes, {"Garage"}),
	RemotesVehicles = ensureFolderPath(sharedRemotes, {"Vehicles"}),
	RemotesRacing = ensureFolderPath(sharedRemotes, {"Racing"}),
	RemotesEconomy = ensureFolderPath(sharedRemotes, {"Economy"}),

	ModulesVehicle = ensureFolderPath(sharedModules, {"Vehicle"}),
	ModulesUI = ensureFolderPath(sharedModules, {"UI"}),
	ModulesVFX = ensureFolderPath(sharedModules, {"VFX"}),
	ModulesInput = ensureFolderPath(sharedModules, {"Input"}),
	ModulesData = ensureFolderPath(sharedModules, {"Data"}),
	ModulesWorld = ensureFolderPath(sharedModules, {"World"}),
	ModulesUtility = ensureFolderPath(sharedModules, {"Utility"}),

	AssetsVehicles = ensureFolderPath(assetsRoot, {"Vehicles"}),
	AssetsVehicleCategories = ensureFolderPath(assetsRoot, {"Vehicles", "Categories"}),
	AssetsVFX = ensureFolderPath(assetsRoot, {"VFX"}),
	AssetsVFXTemplates = ensureFolderPath(assetsRoot, {"VFX", "Templates"}),
	AssetsWorld = ensureFolderPath(assetsRoot, {"World"}),

	ServerServices = serverServices,
	ServerModules = serverModules,
	ClientControllers = clientControllers,
	ClientModules = clientModules,
	WorldCity = ensureFolderPath(worldRoot, {"City"}),
	WorldRuntime = ensureFolderPath(worldRoot, {"Runtime"}),
	WorldGarages = ensureFolderPath(worldRoot, {"Garages"}),
	WorldSpawnPoints = ensureFolderPath(worldRoot, {"SpawnPoints"}),
}

for _, folder in pairs(folders) do
	if folder then
		folder:SetAttribute("ContainsLiveReferencesOnly", true)
		folder:SetAttribute("CreatedOrUpdatedBy", MIGRATION_ID)
	end
end

ensureStringValue(ntrRoot, "README_Phase2", table.concat({
	"Phase 2 adds reference ObjectValues and a registry module.",
	"These references point to the current live systems and are safe to inspect in Studio.",
	"They do not move or replace current gameplay systems.",
	"Future migrations should update one system at a time to use PathResolver or LiveSystemRegistry."
}, "\n"))

local references = {
	{folders.RemotesGarage, "GarageInvoke_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename.GarageInvoke"},
	{folders.RemotesGarage, "GaragePush_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename.GaragePush"},

	{folders.ModulesVehicle, "DrivingControllerV47_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.DrivingControllerV47"},
	{folders.ModulesVehicle, "DrivingFallbackController_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.DrivingFallbackController"},
	{folders.ModulesVehicle, "DriveTuning_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES.DriveTuning"},
	{folders.ModulesVehicle, "VehicleData_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES.VehicleData"},
	{folders.ModulesVehicle, "VehicleStatsCache_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES.VehicleStatsCache"},

	{folders.ModulesInput, "MobileDriveInputState_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.MobileDriveInputState"},
	{folders.ModulesInput, "ReentryThrottle_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.ReentryThrottle"},

	{folders.ModulesUI, "UIFactory_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.UI.UIFactory"},
	{folders.ModulesUI, "UIPool_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.UI.UIPool"},
	{folders.ModulesUI, "UITheme_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES.UITheme"},

	{folders.ModulesVFX, "VehicleVFXController_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.VFX.VehicleVFXController"},
	{folders.ModulesVFX, "CachedThrustVisualRuntime_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Visuals.CachedThrustVisualRuntime"},

	{folders.ModulesData, "ConfigReader_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES.ConfigReader"},
	{folders.ModulesWorld, "LightingPresets_CurrentLive", "ReplicatedStorage.Shared.LightingPresets"},
	{folders.ModulesWorld, "SkyPresets_CurrentLive", "ReplicatedStorage.Shared.SkyPresets"},

	{folders.AssetsVehicleCategories, "VehicleCategories_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.VEHICLE_CATEGORIES"},
	{folders.AssetsVehicleCategories, "BRUISER_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.VEHICLE_CATEGORIES.BRUISER"},
	{folders.AssetsVFXTemplates, "VFXTemplates_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES"},
	{folders.AssetsVFXTemplates, "EngineJet_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES.EngineJet"},
	{folders.AssetsVFXTemplates, "BoostJet_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES.BoostJet"},
	{folders.AssetsVFXTemplates, "StabiliserJet_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES.StabiliserJet"},
	{folders.AssetsVFXTemplates, "HoverDust_CurrentLive", "ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES.HoverDust"},
	{folders.AssetsWorld, "FarLOD5_CurrentLive", "ReplicatedStorage.FarLOD5"},

	{folders.WorldCity, "GeneratedCityBlocks_CurrentLive", "Workspace.GeneratedCityBlocks"},
	{folders.WorldRuntime, "PlayerVehicles_CurrentLive", "Workspace.HOVER_RACING_V2_WORLD.PLAYER_VEHICLES_Runtime"},
	{folders.WorldGarages, "GaragePreviewPad_CurrentLive", "Workspace.HOVER_RACING_V2_WORLD.GaragePreviewPad"},
	{folders.WorldSpawnPoints, "VehicleSpawnPoint_CurrentLive", "Workspace.HOVER_RACING_V2_WORLD.VehicleSpawnPoint"},

	{folders.ServerServices, "GarageVehicleServer_CurrentLive", "ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server"},
	{folders.ServerServices, "DriverSeatPosition_CurrentLive", "ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_DriverSeatPosition"},
	{folders.ServerServices, "LightingController_CurrentLive", "ServerScriptService.Lighting.LightingController"},
	{folders.ServerServices, "TrafficLights_CurrentLive", "ServerScriptService.Traffic Lights"},

	{folders.ClientControllers, "MainGarageDrivingClient_CurrentLive", "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client"},
	{folders.ClientControllers, "MobileDriveControls_CurrentLive", "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls"},
	{folders.ClientControllers, "MobilePcHudSuppressor_CurrentLive", "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor"},
	{folders.ClientControllers, "LODSystem_CurrentLive", "StarterPlayer.StarterPlayerScripts.LOD System"},
	{folders.ClientControllers, "LightingPreview_CurrentLive", "StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"},
	{folders.ClientControllers, "ThrustPreviewOnly_CurrentLive", "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly"},
	{folders.ClientControllers, "CachedThrustVisualRuntimeScript_CurrentLive", "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime"},
}

log("Creating visual live references.")
for _, reference in ipairs(references) do
	ensureObjectValue(reference[1], reference[2], reference[3])
end

local liveSystemRegistrySource = [==[
-- Neo Tokyo Racers Live System Registry
-- Added by Phase 2 architecture setup.
--
-- This module describes the current live systems without moving them.
-- It is a bridge for future targeted migrations.

local Registry = {}

Registry.Version = "Phase2_2026_05_28"
Registry.Status = "Bridge registry. Live systems still run from legacy HOVER_RACING_V2 paths."

Registry.Systems = {
	VehicleGarageCustomisation = {
		status = "LiveLegacy",
		description = "Dealership, garage, customisation, spawn, economy/action handling.",
		livePaths = {
			"ReplicatedStorage.HOVER_RACING_V2_KIT",
			"ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server",
			"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client",
			"Workspace.HOVER_RACING_V2_WORLD",
		},
		targetRoots = {
			"ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles",
			"ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage",
			"ServerScriptService.NeoTokyoRacers.Services",
			"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers",
		},
		safetyNote = "Do not rewrite the whole server/client action layer in one pass.",
	},

	Driving = {
		status = "LiveLegacyWithConfirmedV47Controller",
		description = "Hover driving, mobile controls, camera assist, boost delay, low-speed wobble.",
		livePaths = {
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.DrivingControllerV47",
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.MobileDriveInputState",
			"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls",
			"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor",
		},
		targetRoots = {
			"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers",
			"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Vehicle",
			"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Input",
		},
		safetyNote = "Keep V47-style driving feel unless the user asks for a driving redesign.",
	},

	VFX = {
		status = "LiveLegacyWithCachedRuntime",
		description = "Engine, boost, stabiliser, hover dust, thrust colour, optional neon runtime.",
		livePaths = {
			"ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES",
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.VFX.VehicleVFXController",
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Visuals.CachedThrustVisualRuntime",
		},
		targetRoots = {
			"ReplicatedStorage.NeoTokyoRacers.Assets.VFX",
			"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.VFX",
		},
		safetyNote = "Past issues included neon/thrust flicker and unparented weld leaks. Migrate carefully.",
	},

	WorldLOD = {
		status = "LiveLegacy",
		description = "Generated city blocks, FarLOD5, and distance-based LOD client script.",
		livePaths = {
			"Workspace.GeneratedCityBlocks",
			"ReplicatedStorage.FarLOD5",
			"StarterPlayer.StarterPlayerScripts.LOD System",
		},
		targetRoots = {
			"Workspace.NeoTokyoRacersWorld.City",
			"ReplicatedStorage.NeoTokyoRacers.Assets.World",
			"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers",
		},
		safetyNote = "Do not move GeneratedCityBlocks or FarLOD5 until the LOD script reads through a resolver.",
	},

	Lighting = {
		status = "LiveLegacy",
		description = "Lighting presets, sky presets, lighting controller, and temporary preview script.",
		livePaths = {
			"ReplicatedStorage.Shared.LightingPresets",
			"ReplicatedStorage.Shared.SkyPresets",
			"ServerScriptService.Lighting.LightingController",
			"StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview",
		},
		targetRoots = {
			"ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting",
			"ServerScriptService.NeoTokyoRacers.Services",
		},
		safetyNote = "Night sky handling was a known issue. Fix sky swapping separately from hierarchy migration.",
	},

	TrafficLights = {
		status = "LiveLegacy",
		description = "Central traffic light material cycle controller.",
		livePaths = {
			"ServerScriptService.Traffic Lights",
		},
		targetRoots = {
			"ServerScriptService.NeoTokyoRacers.Services",
		},
		safetyNote = "Keep one central controller; avoid per-light scripts.",
	},
}

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayer = game:GetService("StarterPlayer"),
	StarterGui = game:GetService("StarterGui"),
	Workspace = game:GetService("Workspace"),
	Lighting = game:GetService("Lighting"),
}

local function splitPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end

function Registry.ResolvePath(path)
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

function Registry.GetSystem(systemName)
	return Registry.Systems[systemName]
end

function Registry.ListSystems()
	local names = {}
	for name in pairs(Registry.Systems) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Registry.ResolveSystem(systemName)
	local systemInfo = Registry.Systems[systemName]
	if not systemInfo then
		return nil
	end

	local resolved = {}
	for _, path in ipairs(systemInfo.livePaths or {}) do
		resolved[path] = Registry.ResolvePath(path)
	end

	return resolved
end

return Registry
]==]

ensureModuleScript(compatibilityRoot, "LiveSystemRegistry", liveSystemRegistrySource)

ensureStringValue(compatibilityRoot, "README_LiveSystemRegistry", table.concat({
	"LiveSystemRegistry documents the current live systems and their target roots.",
	"It is safe to require from future scripts, but current live scripts have not been switched yet.",
	"Use it to migrate one system at a time instead of doing large rewrites."
}, "\n"))

local reportText = table.concat({
	MIGRATION_LABEL,
	"Status: complete",
	"Created visual ObjectValue references to current live systems.",
	"Added ReplicatedStorage.NeoTokyoRacers.Compatibility.LiveSystemRegistry.",
	"No live scripts, remotes, assets, world folders, lighting objects, or Test + WIP Assets were moved.",
	"",
	"Next recommended step:",
	"Choose one low-risk system, probably Lighting or TrafficLights, and migrate that system to read via PathResolver/LiveSystemRegistry.",
	"",
	"Created objects: " .. tostring(createdCount),
	"Updated objects: " .. tostring(updatedCount),
	"Skipped objects: " .. tostring(skippedCount),
	"Warnings: " .. tostring(#warnings),
}, "\n")

ensureStringValue(reportsRoot, "Phase2_Live_References_Registry_Report", reportText)

log("Complete.")
log("Created: " .. tostring(createdCount) .. " | Updated: " .. tostring(updatedCount) .. " | Skipped: " .. tostring(skippedCount) .. " | Warnings: " .. tostring(#warnings))

if #warnings > 0 then
	warnLog("Completed with warnings. The script is reference-only, so warnings should not affect live gameplay.")
end

print("Neo Tokyo Racers Phase 2 live references + registry complete. Play-test once, then migrate one low-risk system at a time.")
