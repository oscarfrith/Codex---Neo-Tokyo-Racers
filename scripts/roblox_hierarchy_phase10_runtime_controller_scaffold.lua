-- Neo Tokyo Racers - Phase 10 Runtime Controller Scaffold
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates the final runtime controller structure for driving, mobile input,
--   HUD ownership, VFX ownership, and vehicle enter/exit handling.
--
-- Safe effects:
--   - Creates staged runtime ModuleScripts under StarterPlayerScripts.NeoTokyoRacersClient.
--   - Creates shared runtime migration/config modules under ReplicatedStorage.NeoTokyoRacers.
--   - Adds ObjectValue references to current active runtime scripts/modules.
--
-- Does NOT:
--   - Edit, disable, rename, or replace any active runtime script.
--   - Change DrivingControllerV47, mobile controls, HUD suppressor, VFX runtime,
--     garage UI, server actions, LOD, lighting, traffic, or assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_hierarchy_phase10_runtime_controller_scaffold"

local function log(message)
	print("[NTR Phase10 Runtime Scaffold] " .. message)
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

local function writeModule(parent, name, source, description)
	local module = parent:FindFirstChild(name)
	if module and not module:IsA("ModuleScript") then
		error("Existing " .. module:GetFullName() .. " is a " .. module.ClassName .. ", expected ModuleScript. No changes applied.")
	end
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = name
		module.Parent = parent
	end

	local createdBy = module:GetAttribute("CreatedBy")
	if module.Source ~= "" and createdBy ~= SCRIPT_ID then
		log("Skipped existing manually-created module: " .. module:GetFullName())
		return module, false
	end

	module.Source = source
	module:SetAttribute("CreatedBy", SCRIPT_ID)
	module:SetAttribute("MigrationStatus", "ScaffoldOnly")
	module:SetAttribute("LiveEnabled", false)
	module:SetAttribute("Description", description or "")
	return module, true
end

local starterPlayerScripts = child(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local activeClient = starterPlayerScripts:FindFirstChild("HOVER_RACING_V2_Client")
local activeMobileControls = starterPlayerScripts:FindFirstChild("HOVER_RACING_V67_MobileDriveControls")
local activeHudSuppressor = starterPlayerScripts:FindFirstChild("HOVER_RACING_V71_MobilePcHudSuppressor")
local activeThrustPreview = starterPlayerScripts:FindFirstChild("HOVER_RACING_V46_ThrustPreviewOnly")
local activeCachedRuntime = starterPlayerScripts:FindFirstChild("HOVER_RACING_V64_CachedThrustVisualRuntime")

if not activeClient or not activeClient:IsA("LocalScript") then
	error("Could not find active HOVER_RACING_V2_Client. No changes applied.")
end

local kit = ReplicatedStorage:FindFirstChild("HOVER_RACING_V2_KIT")
if not kit then
	error("Could not find ReplicatedStorage.HOVER_RACING_V2_KIT. No changes applied.")
end

local clientModules = kit:FindFirstChild("CLIENT_MODULES")
local controllers = clientModules and clientModules:FindFirstChild("Controllers")
local visuals = clientModules and clientModules:FindFirstChild("Visuals")
local vfx = clientModules and clientModules:FindFirstChild("VFX")

local drivingController = controllers and controllers:FindFirstChild("DrivingControllerV47")
local mobileInputState = controllers and controllers:FindFirstChild("MobileDriveInputState")
local reentryThrottle = controllers and controllers:FindFirstChild("ReentryThrottle")
local cachedThrustRuntime = visuals and visuals:FindFirstChild("CachedThrustVisualRuntime")
local vehicleVFXController = vfx and vfx:FindFirstChild("VehicleVFXController")

if not drivingController or not drivingController:IsA("ModuleScript") then
	error("Could not find DrivingControllerV47 module. No changes applied.")
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local shared = folder(ntr, "Shared")
local sharedModules = folder(shared, "Modules")
local sharedRuntime = folder(sharedModules, "Runtime")
local compatibility = folder(ntr, "Compatibility")

local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local clientControllers = folder(clientRoot, "Controllers")
local runtimeControllers = folder(clientControllers, "Runtime")
local runtimeState = folder(clientRoot, "RuntimeState")

clientRoot:SetAttribute("RuntimeScaffoldStatus", "Prepared")

objectValue(compatibility, "CurrentRuntimeMainClient", activeClient)
if activeMobileControls then objectValue(compatibility, "CurrentRuntimeMobileControls", activeMobileControls) end
if activeHudSuppressor then objectValue(compatibility, "CurrentRuntimeMobileHudSuppressor", activeHudSuppressor) end
if activeThrustPreview then objectValue(compatibility, "CurrentRuntimeThrustPreview", activeThrustPreview) end
if activeCachedRuntime then objectValue(compatibility, "CurrentRuntimeCachedThrustScript", activeCachedRuntime) end
objectValue(compatibility, "CurrentDrivingControllerV47", drivingController)
if mobileInputState then objectValue(compatibility, "CurrentMobileDriveInputState", mobileInputState) end
if reentryThrottle then objectValue(compatibility, "CurrentReentryThrottle", reentryThrottle) end
if cachedThrustRuntime then objectValue(compatibility, "CurrentCachedThrustVisualRuntime", cachedThrustRuntime) end
if vehicleVFXController then objectValue(compatibility, "CurrentVehicleVFXController", vehicleVFXController) end

local controllerBaseSource = [=[
-- Neo Tokyo Racers staged runtime controller.
-- Scaffold only: this module is not required by live gameplay yet.
--
-- Migration rule:
--   Move one runtime owner at a time. Do not disable V67/V71/V64/V46 until
--   the replacement owner has been tested on desktop and mobile.

local Controller = {}
Controller.__index = Controller

function Controller.new(context)
	return setmetatable({
		Context = context,
		Connections = {},
		Started = false,
	}, Controller)
end

function Controller:Start()
	self.Started = true
end

function Controller:Stop()
	self.Started = false
	for _, connection in ipairs(self.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(self.Connections)
end

return Controller
]=]

local migrationMapSource = [=[
-- Neo Tokyo Racers runtime migration map.
-- Scaffold only. Current live runtime scripts remain active.

return {
	Status = "ScaffoldOnly",
	SafetyRule = "Do not remove patch-style runtime scripts until a single replacement owner has been tested.",

	CurrentRuntimeOwners = {
		MainClient = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client",
		Driving = "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.DrivingControllerV47",
		MobileControls = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls",
		MobileHudSuppressor = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor",
		CachedThrustScript = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime",
		ThrustPreview = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly",
		VFXModules = {
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Visuals.CachedThrustVisualRuntime",
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.VFX.VehicleVFXController",
		},
	},

	TargetControllers = {
		DrivingBootstrapController = {
			Responsibility = "Starts/stops DrivingControllerV47 and owns the handoff from garage to driving.",
			DoNotReplace = "DrivingControllerV47",
		},
		DriveCameraController = {
			Responsibility = "Future owner for in-car camera assist only.",
		},
		DriveHudController = {
			Responsibility = "Single owner for desktop/mobile drive HUD visibility and values.",
			ReplacesLater = "HOVER_RACING_V71_MobilePcHudSuppressor",
		},
		MobileDriveControlsController = {
			Responsibility = "Single owner for mobile pedals, steering, drift, and boost buttons.",
			ReplacesLater = "HOVER_RACING_V67_MobileDriveControls",
		},
		RuntimeVFXController = {
			Responsibility = "Single owner for live driving VFX state, cache, colours, and cleanup.",
			ReplacesLater = {
				"HOVER_RACING_V64_CachedThrustVisualRuntime",
				"HOVER_RACING_V46_ThrustPreviewOnly while driving",
			},
		},
		VehicleAccessController = {
			Responsibility = "Exit/re-enter prompts, cockpit touch re-entry, and future ProximityPrompt boundary.",
		},
	},
}
]=]

local runtimeConfigSource = [=[
-- Future runtime controller config.
-- Scaffold only; live values remain in the current scripts/modules until migration.

return {
	MobileHudCheckInterval = 0.12,
	ReentryCheckInterval = 0.15,
	PreferSingleHudOwner = true,
	PreferCachedVFX = true,
	KeepDrivingControllerV47 = true,
	DesktopAndMobileMustBothBeTested = true,
}
]=]

local runtimeStateSource = [=[
-- Future runtime session state boundary.
-- Scaffold only; current live runtime state remains in the active scripts.

return {
	IsDriving = false,
	CurrentVehicle = nil,
	InputMode = "Unknown",
	IsMobile = false,
}
]=]

writeModule(sharedRuntime, "RuntimeMigrationMap", migrationMapSource, "Maps current active runtime scripts/modules to future single-owner controllers.")
writeModule(sharedRuntime, "RuntimeControllerConfig", runtimeConfigSource, "Future runtime consolidation tuning and safety config.")

writeModule(runtimeControllers, "DrivingBootstrapController", controllerBaseSource, "Future owner for starting/stopping DrivingControllerV47.")
writeModule(runtimeControllers, "DriveCameraController", controllerBaseSource, "Future owner for in-car camera assist only.")
writeModule(runtimeControllers, "DriveHudController", controllerBaseSource, "Future single owner for desktop/mobile driving HUD.")
writeModule(runtimeControllers, "MobileDriveControlsController", controllerBaseSource, "Future single owner for mobile driving controls.")
writeModule(runtimeControllers, "RuntimeVFXController", controllerBaseSource, "Future single owner for live driving VFX runtime/cache.")
writeModule(runtimeControllers, "VehicleAccessController", controllerBaseSource, "Future owner for exit/re-enter and cockpit access.")
writeModule(runtimeState, "RuntimeSessionState", runtimeStateSource, "Future runtime state boundary.")

log("Created staged runtime controller structure under StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.")
log("Created runtime migration map/config under ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Runtime.")
log("No live runtime scripts or modules were edited, disabled, renamed, required, or replaced.")
