-- Neo Tokyo Racers - Phase 9 Server Services Scaffold
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates the final server-side Garage/Vehicle/Profile service layout so the
--   current V56 action layer can be moved safely in later passes.
--
-- Safe effects:
--   - Creates staged ModuleScripts under ServerScriptService.NeoTokyoRacers.Services.
--   - Creates a disabled future server bootstrap Script.
--   - Creates a migration map documenting which V56 functions belong in each service.
--   - Adds compatibility references to the current live server and GarageInvoke.
--
-- Does NOT:
--   - Edit HOVER_RACING_V2_Server.
--   - Disable or replace the current V56 GarageInvoke handler.
--   - Require or enable the new services.
--   - Touch the client UI, driving, VFX, mobile controls, LOD, lighting, traffic,
--     city assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SCRIPT_ID = "roblox_hierarchy_phase9_server_services_scaffold"

local function log(message)
	print("[NTR Phase9 Server Scaffold] " .. message)
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

local function writeServerScript(parent, name, source)
	local scriptObject = parent:FindFirstChild(name)
	if scriptObject and not scriptObject:IsA("Script") then
		error("Existing " .. scriptObject:GetFullName() .. " is a " .. scriptObject.ClassName .. ", expected Script. No changes applied.")
	end
	if not scriptObject then
		scriptObject = Instance.new("Script")
		scriptObject.Name = name
		scriptObject.Disabled = true
		scriptObject.Parent = parent
	end

	local createdBy = scriptObject:GetAttribute("CreatedBy")
	if scriptObject.Source ~= "" and createdBy ~= SCRIPT_ID then
		log("Skipped existing manually-created Script: " .. scriptObject:GetFullName())
		return scriptObject, false
	end

	scriptObject.Disabled = true
	scriptObject.Source = source
	scriptObject:SetAttribute("CreatedBy", SCRIPT_ID)
	scriptObject:SetAttribute("MigrationStatus", "DisabledFutureBootstrap")
	scriptObject:SetAttribute("LiveEnabled", false)
	return scriptObject, true
end

local currentServerFolder = ServerScriptService:FindFirstChild("HOVER_RACING_V2_SERVER")
local currentServer = currentServerFolder and currentServerFolder:FindFirstChild("HOVER_RACING_V2_Server")
if not currentServer or not currentServer:IsA("Script") then
	error("Could not find ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server. Run this from the current working project before changing live server names.")
end

local kit = ReplicatedStorage:FindFirstChild("HOVER_RACING_V2_KIT")
local garageInvoke = kit and kit:FindFirstChild("REMOTES_DoNotRename") and kit.REMOTES_DoNotRename:FindFirstChild("GarageInvoke")
if not garageInvoke or not garageInvoke:IsA("RemoteFunction") then
	error("Could not find ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename.GarageInvoke. No changes applied.")
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local shared = folder(ntr, "Shared")
local sharedModules = folder(shared, "Modules")
local sharedData = folder(sharedModules, "Data")
local compatibility = folder(ntr, "Compatibility")

local serverRoot = folder(ServerScriptService, "NeoTokyoRacers")
local services = folder(serverRoot, "Services")
local garageServices = folder(services, "Garage")
local vehicleServices = folder(services, "Vehicle")
local playerServices = folder(services, "Player")
local economyServices = folder(services, "Economy")
local serverState = folder(serverRoot, "State")

serverRoot:SetAttribute("MigrationStatus", "ScaffoldOnly")
serverRoot:SetAttribute("LiveEnabled", false)
serverRoot:SetAttribute("CurrentLiveServer", currentServer:GetFullName())

objectValue(compatibility, "CurrentLiveServer", currentServer)
objectValue(compatibility, "CurrentGarageInvoke", garageInvoke)
objectValue(compatibility, "FutureServerRoot", serverRoot)

local serviceBaseSource = [=[
-- Neo Tokyo Racers staged server service.
-- Scaffold only: this module is not required by live gameplay yet.
--
-- Migration rule:
--   Move one coherent group from the V56 action layer at a time.
--   Do not replace GarageInvoke.OnServerInvoke until all services have parity tests.

local Service = {}
Service.__index = Service

function Service.new(context)
	return setmetatable({
		Context = context,
		Started = false,
	}, Service)
end

function Service:Start()
	self.Started = true
end

function Service:Stop()
	self.Started = false
end

return Service
]=]

local migrationMapSource = [=[
-- Neo Tokyo Racers server service migration map.
-- Scaffold only. Current live source remains HOVER_RACING_V2_Server V56 block.

return {
	SourceOfTruth = "ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server",
	CurrentActionLayer = "V56_CONSOLIDATED_ACTION_CONTROLLER",
	Status = "ScaffoldOnly",
	SafetyRule = "Do not replace GarageInvoke.OnServerInvoke until new services are tested against current V56 behaviour.",

	Services = {
		ProfileService = {
			Responsibility = "In-memory player profile defaults, normalization, profile lookup, leaderstats sync.",
			CurrentFunctions = {
				"V56_defaultProfile",
				"V56_normalizeProfile",
				"V56_getProfile",
				"V56_setLeaderstats",
			},
		},

		EconomyService = {
			Responsibility = "Cash checks, prices, purchases, and future Robux/Get More integration boundary.",
			CurrentFunctions = {
				"V56_number",
				"V56_value",
				"V56_string",
				"purchase checks inside BuyCockpit/BuyModule/BuyNeon/Upgrade actions",
			},
		},

		VehicleCatalogService = {
			Responsibility = "Read vehicle categories, cockpits, module slots, module templates, and serialised catalog data.",
			CurrentFunctions = {
				"V56_categoryFolder",
				"V56_findByAttribute",
				"V56_findCockpit",
				"V56_findModule",
				"V56_moduleTypeFromText",
				"V56_moduleTypeForModel",
				"V56_defaultSlots",
				"V56_nearestModuleFolder",
				"V56_readModule",
				"V56_catalog",
			},
		},

		VehicleStatsService = {
			Responsibility = "Compute total stats from cockpit, equipped modules, and upgrades.",
			CurrentFunctions = {
				"V56_totalStats",
				"V56_profileForClient",
			},
		},

		VehicleBuildService = {
			Responsibility = "Clone cockpit/modules, apply colours, weld decorative model, create seat, and prepare runtime attributes.",
			CurrentFunctions = {
				"V56_resolvePaintChannel",
				"V56_pathHas",
				"V56_applyColors",
				"V56_getSlotMount",
				"V56_pivotModuleToSlot",
				"V56_weldVehicle",
				"V56_makeDriverSeat",
				"V56_folderHasBuyableNeon",
				"V56_buildVehicle",
			},
		},

		VehicleSpawnService = {
			Responsibility = "Own current player vehicle lifecycle, seat player, exit/re-enter vehicle.",
			CurrentFunctions = {
				"V56_clearPlayerVehicle",
				"V56_seatPlayer",
				"V56_exitVehicle",
				"V56_reEnterVehicle",
			},
		},

		GarageActionService = {
			Responsibility = "Route GarageInvoke actions to services and return the exact current response shape.",
			CurrentFunctions = {
				"V56_invoke.OnServerInvoke",
				"Init",
				"BuyCockpit",
				"SetCockpitColor",
				"BuyModule",
				"SetModuleColor",
				"Upgrade",
				"BuyNeon",
				"SetThrustColor",
				"SpawnVehicle",
				"ExitVehicle",
				"ReEnterVehicle",
			},
		},
	},
}
]=]

local serverContextSource = [=[
-- Future shared server context.
-- Scaffold only; current live server still creates local variables directly.

local ServerContext = {}

function ServerContext.default()
	return {
		KitName = "HOVER_RACING_V2_KIT",
		WorldName = "HOVER_RACING_V2_WORLD",
		GarageInvokePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename.GarageInvoke",
		PlayerVehicleRootName = "PLAYER_VEHICLES_Runtime",
		StartingCashAttribute = "StartingCash",
		SpawnAttributes = { "SpawnX", "SpawnY", "SpawnZ" },
		PreviewAttributes = { "PreviewX", "PreviewY", "PreviewZ" },
	}
end

return ServerContext
]=]

local bootstrapSource = [=[
-- Neo Tokyo Racers future server bootstrap.
-- Disabled scaffold only. Current live server remains:
-- ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server

warn("[NeoTokyoRacersServer] Disabled scaffold was enabled manually. It does not replace GarageInvoke yet.")
]=]

writeModule(sharedData, "ServerServiceMigrationMap", migrationMapSource, "Maps current V56 server functions to future service modules.")
writeModule(sharedData, "ServerContext", serverContextSource, "Future shared server context/settings shape.")

writeModule(playerServices, "ProfileService", serviceBaseSource, "Future player profile defaults, normalization, lookup, and leaderstats service.")
writeModule(economyServices, "EconomyService", serviceBaseSource, "Future cash/price/purchase service.")
writeModule(vehicleServices, "VehicleCatalogService", serviceBaseSource, "Future vehicle category/catalog reader service.")
writeModule(vehicleServices, "VehicleStatsService", serviceBaseSource, "Future total stats/profile-for-client service.")
writeModule(vehicleServices, "VehicleBuildService", serviceBaseSource, "Future clone/colour/weld/seat vehicle build service.")
writeModule(vehicleServices, "VehicleSpawnService", serviceBaseSource, "Future player vehicle spawn/exit/re-enter lifecycle service.")
writeModule(garageServices, "GarageActionService", serviceBaseSource, "Future GarageInvoke action routing service.")
writeModule(serverState, "RuntimeProfiles", [=[
-- Future runtime profile state boundary.
-- Scaffold only; current V56 server still owns the active profiles table.

return {}
]=], "Future in-memory profile table boundary. Not live yet.")

writeServerScript(serverRoot, "NeoTokyoRacersServer_Bootstrap_Disabled", bootstrapSource)

log("Created staged server service structure under ServerScriptService.NeoTokyoRacers.Services.")
log("Created server migration map/context under ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.")
log("No live GarageInvoke, server action, client, driving, VFX, LOD, lighting, traffic, or asset behaviour was changed.")
