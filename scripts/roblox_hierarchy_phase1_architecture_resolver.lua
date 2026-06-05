-- Neo Tokyo Racers - Phase 1 Architecture Setup
-- Paste this whole script into the Roblox Studio Command Bar in Edit mode.
--
-- What this does:
-- - Creates the future NeoTokyoRacers folder architecture.
-- - Adds a compatibility PathResolver module that points to the current live folders.
-- - Mirrors key editable config folders into the new structure for planning/reference.
--
-- What this intentionally does NOT do:
-- - It does not move, rename, disable, or delete any existing live gameplay objects.
-- - It does not touch Workspace["Test + WIP Assets"].
-- - It does not switch any existing scripts to the new paths yet.

local MIGRATION_ID = "NTR_Phase1_ArchitectureResolver_2026_05_28"
local MIGRATION_LABEL = "Neo Tokyo Racers Phase 1 Architecture Setup"

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
	print("[NTR Phase 1] " .. tostring(message))
end

local function warnLog(message)
	local text = "[NTR Phase 1 WARNING] " .. tostring(message)
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
	local rootName = parts[1]
	local current = services[rootName]
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
		return nil, false
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("Folder") then
			return existing, false
		end

		warnLog(parent:GetFullName() .. "." .. name .. " already exists as " .. existing.ClassName .. "; skipped folder creation.")
		skippedCount = skippedCount + 1
		return nil, false
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	folder:SetAttribute("CreatedBy", MIGRATION_ID)
	createdCount = createdCount + 1
	return folder, true
end

local function ensureScreenGui(parent, name)
	if not parent then
		warnLog("Cannot create ScreenGui '" .. tostring(name) .. "' because the parent was missing.")
		skippedCount = skippedCount + 1
		return nil, false
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("ScreenGui") then
			return existing, false
		end

		warnLog(parent:GetFullName() .. "." .. name .. " already exists as " .. existing.ClassName .. "; skipped ScreenGui creation.")
		skippedCount = skippedCount + 1
		return nil, false
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = parent
	screenGui:SetAttribute("CreatedBy", MIGRATION_ID)
	screenGui:SetAttribute("Phase1PlaceholderOnly", true)
	createdCount = createdCount + 1
	return screenGui, true
end

local function ensureFolderPath(root, pathParts)
	if not root then
		warnLog("Cannot create folder path because the root parent was missing.")
		skippedCount = skippedCount + 1
		return nil
	end

	local current = root
	for _, name in ipairs(pathParts) do
		local nextFolder = ensureFolder(current, name)
		if not nextFolder then
			return nil
		end
		current = nextFolder
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

	local stringValue = Instance.new("StringValue")
	stringValue.Name = name
	stringValue.Value = value
	stringValue.Parent = parent
	stringValue:SetAttribute("CreatedBy", MIGRATION_ID)
	createdCount = createdCount + 1
	return stringValue
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

local function markGenerated(instance)
	instance:SetAttribute("GeneratedBy", MIGRATION_ID)
	instance:SetAttribute("MirrorOnly", true)
	instance:SetAttribute("DoNotEditYet", true)

	for _, descendant in ipairs(instance:GetDescendants()) do
		descendant:SetAttribute("GeneratedBy", MIGRATION_ID)
		descendant:SetAttribute("MirrorOnly", true)
		descendant:SetAttribute("DoNotEditYet", true)

		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		end
	end
end

local function mirrorObject(sourcePath, targetParent, mirrorName)
	local source = findPath(sourcePath)
	if not source then
		warnLog("Mirror skipped because source was missing: " .. sourcePath)
		skippedCount = skippedCount + 1
		return nil
	end

	local existing = targetParent:FindFirstChild(mirrorName)
	if existing then
		if existing:GetAttribute("MirrorOnly") == true or existing:GetAttribute("GeneratedBy") == MIGRATION_ID then
			existing:Destroy()
			updatedCount = updatedCount + 1
		else
			warnLog("Mirror target already exists and is not marked generated, so it was left alone: " .. existing:GetFullName())
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
	clone:SetAttribute("SourcePath", sourcePath)
	clone:SetAttribute("SourceClassName", source.ClassName)
	clone:SetAttribute("CurrentLiveSource", true)
	markGenerated(clone)
	clone.Parent = targetParent
	createdCount = createdCount + 1
	return clone
end

local replicatedStorage = services.ReplicatedStorage
local serverScriptService = services.ServerScriptService
local starterPlayerScripts = services.StarterPlayer:WaitForChild("StarterPlayerScripts")
local starterGui = services.StarterGui
local workspaceService = services.Workspace

log("Creating clean future architecture roots.")

local ntrRoot = ensureFolder(replicatedStorage, "NeoTokyoRacers")
if not ntrRoot then
	error("[NTR Phase 1] Could not create or access ReplicatedStorage.NeoTokyoRacers.")
end

ntrRoot:SetAttribute("ArchitecturePhase", "Phase1")
ntrRoot:SetAttribute("LiveSystemsStillUseLegacyPaths", true)
ntrRoot:SetAttribute("DoNotDeleteLegacySystemsYet", true)
ntrRoot:SetAttribute("CreatedOrUpdatedBy", MIGRATION_ID)

local sharedConfig = ensureFolderPath(ntrRoot, {"Shared", "Config"})
local sharedRemotes = ensureFolderPath(ntrRoot, {"Shared", "Remotes"})
local sharedModules = ensureFolderPath(ntrRoot, {"Shared", "Modules"})
local assetsRoot = ensureFolderPath(ntrRoot, {"Assets"})
local compatibilityRoot = ensureFolderPath(ntrRoot, {"Compatibility"})
local reportsRoot = ensureFolderPath(ntrRoot, {"MigrationReports"})

ensureFolderPath(sharedConfig, {"Driving"})
ensureFolderPath(sharedConfig, {"Camera"})
ensureFolderPath(sharedConfig, {"UI"})
ensureFolderPath(sharedConfig, {"Economy"})
ensureFolderPath(sharedConfig, {"VFX"})
ensureFolderPath(sharedConfig, {"Vehicles"})
ensureFolderPath(sharedConfig, {"World"})
ensureFolderPath(sharedConfig, {"World", "Lighting"})
ensureFolderPath(sharedConfig, {"World", "LOD"})
ensureFolderPath(sharedConfig, {"World", "Traffic"})
ensureFolderPath(sharedConfig, {"Racing"})

ensureFolderPath(sharedRemotes, {"Garage"})
ensureFolderPath(sharedRemotes, {"Vehicles"})
ensureFolderPath(sharedRemotes, {"Racing"})
ensureFolderPath(sharedRemotes, {"Economy"})
ensureFolderPath(sharedRemotes, {"UI"})

ensureFolderPath(sharedModules, {"Utility"})
ensureFolderPath(sharedModules, {"Data"})
ensureFolderPath(sharedModules, {"Vehicle"})
ensureFolderPath(sharedModules, {"UI"})
ensureFolderPath(sharedModules, {"VFX"})
ensureFolderPath(sharedModules, {"World"})
ensureFolderPath(sharedModules, {"Input"})

ensureFolderPath(assetsRoot, {"Vehicles"})
ensureFolderPath(assetsRoot, {"Vehicles", "Categories"})
ensureFolderPath(assetsRoot, {"VFX"})
ensureFolderPath(assetsRoot, {"VFX", "Templates"})
ensureFolderPath(assetsRoot, {"UI"})
ensureFolderPath(assetsRoot, {"UI", "Theme"})
ensureFolderPath(assetsRoot, {"World"})

local serverRoot = ensureFolder(serverScriptService, "NeoTokyoRacers")
if serverRoot then
	ensureFolderPath(serverRoot, {"Services"})
	ensureFolderPath(serverRoot, {"ServerModules"})
	ensureFolderPath(serverRoot, {"ServerModules", "Data"})
	ensureFolderPath(serverRoot, {"ServerModules", "Validation"})
	ensureFolderPath(serverRoot, {"ServerModules", "Runtime"})
	ensureFolderPath(serverRoot, {"ServerModules", "Economy"})
	ensureFolderPath(serverRoot, {"ServerModules", "Vehicle"})
	ensureFolderPath(serverRoot, {"ServerModules", "World"})
	serverRoot:SetAttribute("Phase1PlaceholderOnly", true)
end

local clientRoot = ensureFolder(starterPlayerScripts, "NeoTokyoRacersClient")
if clientRoot then
	ensureFolderPath(clientRoot, {"Controllers"})
	ensureFolderPath(clientRoot, {"ClientModules"})
	ensureFolderPath(clientRoot, {"ClientModules", "Input"})
	ensureFolderPath(clientRoot, {"ClientModules", "UI"})
	ensureFolderPath(clientRoot, {"ClientModules", "Vehicle"})
	ensureFolderPath(clientRoot, {"ClientModules", "VFX"})
	ensureFolderPath(clientRoot, {"ClientModules", "Camera"})
	clientRoot:SetAttribute("Phase1PlaceholderOnly", true)
end

local uiRoot = ensureScreenGui(starterGui, "NeoTokyoRacersUI")
if uiRoot then
	ensureFolderPath(uiRoot, {"Screens"})
	ensureFolderPath(uiRoot, {"Components"})
	ensureFolderPath(uiRoot, {"Theme"})
	uiRoot:SetAttribute("Phase1PlaceholderOnly", true)
end

local worldRoot = ensureFolder(workspaceService, "NeoTokyoRacersWorld")
if worldRoot then
	ensureFolderPath(worldRoot, {"City"})
	ensureFolderPath(worldRoot, {"Runtime"})
	ensureFolderPath(worldRoot, {"Runtime", "PlayerVehicles"})
	ensureFolderPath(worldRoot, {"RaceRoutes"})
	ensureFolderPath(worldRoot, {"Garages"})
	ensureFolderPath(worldRoot, {"SpawnPoints"})
	worldRoot:SetAttribute("Phase1PlaceholderOnly", true)
	worldRoot:SetAttribute("DoNotTouchTestAndWIPAssets", true)
end

ensureStringValue(ntrRoot, "README_Phase1", table.concat({
	"NeoTokyoRacers is the future clean architecture root.",
	"Current live gameplay still uses the legacy HOVER_RACING_V2 paths.",
	"This Phase 1 setup is intentionally non-destructive.",
	"Do not move live systems into these folders until each system has been migrated and play-tested."
}, "\n"))

ensureStringValue(compatibilityRoot, "README_Compatibility", table.concat({
	"PathResolver maps future logical names to the current live hierarchy.",
	"Use this for new code and targeted migrations.",
	"Do not mass-replace existing scripts without play-testing one system at a time."
}, "\n"))

ensureStringValue(ntrRoot, "DO_NOT_TOUCH_Test_WIP_Assets", "Workspace.Test + WIP Assets is intentionally excluded from this migration.")

local pathResolverSource = [==[
-- Neo Tokyo Racers Compatibility Path Resolver
-- Added by Phase 1 architecture setup.
--
-- The current game still runs from the legacy HOVER_RACING_V2 paths.
-- New code can ask for logical names here, then later the mappings can
-- be changed one system at a time without mass-rewriting every script.

local PathResolver = {}

PathResolver.Version = "Phase1_2026_05_28"
PathResolver.LiveSystemsStillUseLegacyPaths = true

PathResolver.PathStrings = {
	NTRRoot = "ReplicatedStorage.NeoTokyoRacers",
	NTRShared = "ReplicatedStorage.NeoTokyoRacers.Shared",
	NTRConfig = "ReplicatedStorage.NeoTokyoRacers.Shared.Config",
	NTRRemotes = "ReplicatedStorage.NeoTokyoRacers.Shared.Remotes",
	NTRModules = "ReplicatedStorage.NeoTokyoRacers.Shared.Modules",
	NTRAssets = "ReplicatedStorage.NeoTokyoRacers.Assets",
	NTRWorld = "Workspace.NeoTokyoRacersWorld",

	LegacyKit = "ReplicatedStorage.HOVER_RACING_V2_KIT",
	LegacyWorld = "Workspace.HOVER_RACING_V2_WORLD",
	VehicleCategories = "ReplicatedStorage.HOVER_RACING_V2_KIT.VEHICLE_CATEGORIES",
	GarageRemotes = "ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename",
	ClientModules = "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES",
	SharedModules = "ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES",
	VFXTemplates = "ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES",
	EditableConfig = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG",
	GameBalance = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST",
	UITheme = "ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename",
	PaintPresets = "ReplicatedStorage.HOVER_RACING_V2_KIT.PAINT_PRESETS_EditColoursHere",

	VehicleRuntime = "Workspace.HOVER_RACING_V2_WORLD.PLAYER_VEHICLES_Runtime",
	GaragePreviewPad = "Workspace.HOVER_RACING_V2_WORLD.GaragePreviewPad",
	VehicleSpawnPoint = "Workspace.HOVER_RACING_V2_WORLD.VehicleSpawnPoint",

	GeneratedCityBlocks = "Workspace.GeneratedCityBlocks",
	FarLOD5 = "ReplicatedStorage.FarLOD5",
	LightingPresets = "ReplicatedStorage.Shared.LightingPresets",
	SkyPresets = "ReplicatedStorage.Shared.SkyPresets",
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

local function resolvePath(path, shouldWait, timeout)
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local parts = splitPath(path)
	local current = services[parts[1]]
	if not current then
		return nil
	end

	for index = 2, #parts do
		local name = parts[index]
		if shouldWait then
			current = current:WaitForChild(name, timeout or 5)
		else
			current = current:FindFirstChild(name)
		end

		if not current then
			return nil
		end
	end

	return current
end

function PathResolver.GetPath(name)
	return PathResolver.PathStrings[name]
end

function PathResolver.SetPath(name, path)
	assert(typeof(name) == "string", "PathResolver.SetPath name must be a string")
	assert(typeof(path) == "string", "PathResolver.SetPath path must be a string")
	PathResolver.PathStrings[name] = path
end

function PathResolver.Resolve(name)
	return resolvePath(PathResolver.PathStrings[name], false)
end

function PathResolver.WaitFor(name, timeout)
	return resolvePath(PathResolver.PathStrings[name], true, timeout)
end

function PathResolver.ResolveRequired(name)
	local instance = PathResolver.Resolve(name)
	if not instance then
		error(("PathResolver could not resolve '%s' at '%s'"):format(tostring(name), tostring(PathResolver.PathStrings[name])), 2)
	end
	return instance
end

function PathResolver.List()
	local copy = {}
	for name, path in pairs(PathResolver.PathStrings) do
		copy[name] = path
	end
	return copy
end

return PathResolver
]==]

ensureModuleScript(compatibilityRoot, "PathResolver", pathResolverSource)

log("Mirroring key editable configs. These are reference copies only; live scripts still use old folders.")

local configRoot = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config")
local configDriving = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving")
local configCamera = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config.Camera")
local configUI = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI")
local configEconomy = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config.Economy")
local configVFX = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config.VFX")
local configVehicles = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config.Vehicles")
local configLighting = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting")
local configLOD = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.LOD")

if configRoot then
	configRoot:SetAttribute("MirrorsAreReferenceOnly", true)
	configRoot:SetAttribute("CurrentLiveConfigStillUsesLegacyPaths", true)
end

local mirrorJobs = {
	{
		sourcePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_MECHANICS_EditAttributes",
		targetParent = configDriving,
		mirrorName = "DRIVING_MECHANICS_EditAttributes_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.HOVER_WOBBLE_EditAttributes",
		targetParent = configDriving,
		mirrorName = "HOVER_WOBBLE_EditAttributes_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_CAMERA_ASSIST_EditAttributes",
		targetParent = configCamera,
		mirrorName = "DRIVING_CAMERA_ASSIST_EditAttributes_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename",
		targetParent = configUI,
		mirrorName = "UI_THEME_DoNotRename_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.PAINT_PRESETS_EditColoursHere",
		targetParent = configUI,
		mirrorName = "PAINT_PRESETS_EditColoursHere_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.01_GAME_BALANCE_Editable",
		targetParent = configEconomy,
		mirrorName = "01_GAME_BALANCE_Editable_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.DRIVER_SEAT_POSITION_DoNotRename",
		targetParent = configVehicles,
		mirrorName = "DRIVER_SEAT_POSITION_DoNotRename_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.STABILISER_VFX_DIRECTION_DoNotRename",
		targetParent = configVFX,
		mirrorName = "STABILISER_VFX_DIRECTION_DoNotRename_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.Shared.LightingPresets",
		targetParent = configLighting,
		mirrorName = "LightingPresets_Mirror",
	},
	{
		sourcePath = "ReplicatedStorage.Shared.SkyPresets",
		targetParent = configLighting,
		mirrorName = "SkyPresets_Mirror",
	},
}

for _, job in ipairs(mirrorJobs) do
	if job.targetParent then
		mirrorObject(job.sourcePath, job.targetParent, job.mirrorName)
	else
		warnLog("Mirror skipped because target parent was missing for " .. job.sourcePath)
	end
end

if configLOD then
	ensureStringValue(configLOD, "FarLOD5_LivePath_Reference", "ReplicatedStorage.FarLOD5")
	ensureStringValue(configLOD, "GeneratedCityBlocks_LivePath_Reference", "Workspace.GeneratedCityBlocks")
end

local reportText = table.concat({
	MIGRATION_LABEL,
	"Status: complete",
	"Created/updated future architecture roots only.",
	"Live systems still use legacy HOVER_RACING_V2 paths.",
	"No existing gameplay scripts, assets, remotes, or world folders were moved.",
	"Workspace.Test + WIP Assets was not touched.",
	"",
	"Next recommended step:",
	"Play-test the game. If everything still works, future migrations can update one system at a time to use PathResolver.",
	"",
	"Created objects: " .. tostring(createdCount),
	"Updated objects: " .. tostring(updatedCount),
	"Skipped objects: " .. tostring(skippedCount),
	"Warnings: " .. tostring(#warnings),
}, "\n")

ensureStringValue(reportsRoot, "Phase1_Architecture_Setup_Report", reportText)

log("Complete.")
log("Created: " .. tostring(createdCount) .. " | Updated: " .. tostring(updatedCount) .. " | Skipped: " .. tostring(skippedCount) .. " | Warnings: " .. tostring(#warnings))

if #warnings > 0 then
	warnLog("Completed with warnings. Check the output above, but no live gameplay objects were intentionally changed.")
end

print("Neo Tokyo Racers Phase 1 architecture setup complete. Now Play-test: menus, customisation, spawn, driving, VFX, LOD, lighting, traffic lights.")
