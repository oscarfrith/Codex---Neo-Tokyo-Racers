-- Neo Tokyo Racers - Phase 4 Architecture Staging Scaffold
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates clean future architecture folders and reference markers without
--   moving, disabling, deleting, renaming, cloning, or replacing current live
--   gameplay scripts.
--
-- Safe effects:
--   - Creates missing organisation folders.
--   - Creates ObjectValue references to current live scripts/modules/folders.
--   - Adds note StringValues for future migration.
--
-- Does NOT:
--   - Change Disabled state of any Script/LocalScript.
--   - Change Source of any live script.
--   - Move live scripts.
--   - Parent anything into Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local function log(message)
	print("[NTR Phase4 Scaffold] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No further changes applied.")
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

local function stringValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA("StringValue") then
		if item then
			item.Name = name .. "_OldNonStringValue"
		end
		item = Instance.new("StringValue")
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function objectValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA("ObjectValue") then
		if item then
			item.Name = name .. "_OldNonObjectValue"
		end
		item = Instance.new("ObjectValue")
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function findPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

local rsRoot = folder(ReplicatedStorage, "NeoTokyoRacers")
local shared = folder(rsRoot, "Shared")
local sharedConfig = folder(shared, "Config")
local sharedModules = folder(shared, "Modules")
local compatibility = folder(rsRoot, "Compatibility")
local remotes = folder(rsRoot, "Remotes")
local references = folder(rsRoot, "LiveReferences")
local migration = folder(rsRoot, "MigrationNotes")

folder(sharedModules, "Data")
folder(sharedModules, "Vehicle")
folder(sharedModules, "UI")
folder(sharedModules, "VFX")
folder(sharedModules, "World")
folder(sharedModules, "Input")
folder(sharedModules, "Net")

folder(sharedConfig, "Vehicle")
folder(sharedConfig, "UI")
folder(sharedConfig, "VFX")
local worldConfig = folder(sharedConfig, "World")
folder(worldConfig, "Lighting")
folder(worldConfig, "LOD")
folder(worldConfig, "Traffic")

local sssRoot = folder(ServerScriptService, "NeoTokyoRacers")
local services = folder(sssRoot, "Services")
folder(services, "Garage")
folder(services, "Vehicle")
folder(services, "Profile")
folder(services, "Economy")
local worldServices = folder(services, "World")
folder(worldServices, "Traffic")
folder(worldServices, "Lighting")
folder(worldServices, "Race")

local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
folder(clientRoot, "Bootstrap")
local controllers = folder(clientRoot, "Controllers")
folder(controllers, "Garage")
folder(controllers, "Dealership")
folder(controllers, "Customisation")
folder(controllers, "Preview")
folder(controllers, "Driving")
folder(controllers, "Camera")
folder(controllers, "Mobile")
folder(controllers, "HUD")
folder(controllers, "VFX")
folder(controllers, "World")

local uiRoot = child(StarterGui, "ScreenGui", "NeoTokyoRacersUI")
uiRoot.ResetOnSpawn = false
uiRoot.IgnoreGuiInset = true
uiRoot.Enabled = false
folder(uiRoot, "Screens")
folder(uiRoot, "Components")
folder(uiRoot, "Templates")

local worldRoot = folder(Workspace, "NeoTokyoRacersWorld")
folder(worldRoot, "Runtime")
folder(worldRoot, "Routes")
folder(worldRoot, "Interactives")
folder(worldRoot, "References")

local kit = ReplicatedStorage:FindFirstChild("HOVER_RACING_V2_KIT")
local sharedLegacy = ReplicatedStorage:FindFirstChild("Shared")
local generatedCity = Workspace:FindFirstChild("GeneratedCityBlocks")
local hoverWorld = Workspace:FindFirstChild("HOVER_RACING_V2_WORLD")

local current = {
	ActiveKit = kit,
	LegacyShared = sharedLegacy,
	GeneratedCityBlocks = generatedCity,
	HoverWorld = hoverWorld,
	MainClient = starterPlayerScripts:FindFirstChild("HOVER_RACING_V2_Client"),
	MobileDriveControls = starterPlayerScripts:FindFirstChild("HOVER_RACING_V67_MobileDriveControls"),
	MobileHudSuppressor = starterPlayerScripts:FindFirstChild("HOVER_RACING_V71_MobilePcHudSuppressor"),
	CachedThrustRuntime = starterPlayerScripts:FindFirstChild("HOVER_RACING_V64_CachedThrustVisualRuntime"),
	ThrustPreview = starterPlayerScripts:FindFirstChild("HOVER_RACING_V46_ThrustPreviewOnly"),
	LODClient = starterPlayerScripts:FindFirstChild("LOD System"),
	LightingPreview = starterPlayerScripts:FindFirstChild("TEMP_LightingPreview"),
	MainServer = findPath(ServerScriptService, { "HOVER_RACING_V2_SERVER", "HOVER_RACING_V2_Server" }),
	DriverSeatPosition = findPath(ServerScriptService, { "HOVER_RACING_V2_SERVER", "HOVER_RACING_V2_DriverSeatPosition" }),
	LightingController = findPath(ServerScriptService, { "Lighting", "LightingController" }),
	TrafficLights = ServerScriptService:FindFirstChild("Traffic Lights"),
}

if kit then
	current.GarageInvoke = findPath(kit, { "REMOTES_DoNotRename", "GarageInvoke" })
	current.VehicleCategories = kit:FindFirstChild("VEHICLE_CATEGORIES")
	current.VFXTemplates = kit:FindFirstChild("VFX_TEMPLATES")
	current.UITheme = kit:FindFirstChild("UI_THEME_DoNotRename")
	current.EditMeFirst = kit:FindFirstChild("00_EDIT_ME_FIRST")
	current.ClientModules = kit:FindFirstChild("CLIENT_MODULES")
	current.SharedModules = kit:FindFirstChild("SHARED_MODULES")
end

if current.ClientModules then
	current.DrivingController = findPath(current.ClientModules, { "Controllers", "DrivingControllerV47" })
	current.MobileInputState = findPath(current.ClientModules, { "Controllers", "MobileDriveInputState" })
	current.UIPool = findPath(current.ClientModules, { "UI", "UIPool" })
	current.UIFactory = findPath(current.ClientModules, { "UI", "UIFactory" })
	current.VehicleVFXController = findPath(current.ClientModules, { "VFX", "VehicleVFXController" })
	current.CachedThrustVisualRuntimeModule = findPath(current.ClientModules, { "Visuals", "CachedThrustVisualRuntime" })
end

if current.SharedModules then
	current.VehicleStatsCache = current.SharedModules:FindFirstChild("VehicleStatsCache")
	current.VehicleData = current.SharedModules:FindFirstChild("VehicleData")
	current.DriveTuning = current.SharedModules:FindFirstChild("DriveTuning")
	current.ConfigReader = current.SharedModules:FindFirstChild("ConfigReader")
	current.UIThemeModule = current.SharedModules:FindFirstChild("UITheme")
end

for name, value in pairs(current) do
	if value then
		objectValue(references, name, value)
	end
end

stringValue(migration, "00_ReadMe", table.concat({
	"Phase 4 is a staging scaffold only.",
	"Current live scripts remain in their old locations.",
	"Use LiveReferences to inspect the current source of truth before migrating one system at a time.",
	"Recommended first migration candidate: ServerScriptService.Traffic Lights -> ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService.",
	"Do not touch Workspace.Test + WIP Assets during architecture cleanup.",
}, "\n"))

stringValue(migration, "01_ClientSplitTarget", table.concat({
	"Future client split:",
	"GarageClient, DealershipClient, CustomisationClient, PreviewVehicleClient, GarageCameraClient, DrivingClient, MobileControlsClient, HudClient, VFXClient, LODClient.",
	"Do not split all at once. Extract one controller at a time and keep behaviour identical.",
}, "\n"))

stringValue(migration, "02_ServerSplitTarget", table.concat({
	"Future server split:",
	"GarageService, VehicleBuildService, VehicleSpawnService, ProfileService, EconomyService, VehicleOwnershipService, TrafficLightService, LightingService.",
	"Treat the V56 consolidated action controller inside HOVER_RACING_V2_Server as the current action source of truth.",
}, "\n"))

stringValue(migration, "03_MobilePerformanceNotes", table.concat({
	"Mobile priorities:",
	"Cache vehicle stats at drive start.",
	"Keep VFX cached and client-side.",
	"Avoid broad PlayerGui/GetDescendants scans during driving.",
	"Replace HUD suppression workaround with one explicit HUD owner later.",
	"Keep world LOD updates throttled, not per-frame.",
}, "\n"))

log("Created/refreshed future architecture folders.")
log("Created/refreshed LiveReferences ObjectValues.")
log("No live scripts were moved, disabled, renamed, deleted, cloned, or edited.")
log("Next safe step: create a disabled shadow copy of the Traffic Lights service, then test before switching live behaviour.")
