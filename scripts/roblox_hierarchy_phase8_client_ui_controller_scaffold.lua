-- Neo Tokyo Racers - Phase 8 Client UI Controller Scaffold
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates the final client UI controller folder/module layout so the current
--   giant HOVER_RACING_V2_Client can be split safely in later passes.
--
-- Safe effects:
--   - Creates disabled/staged client UI controller ModuleScripts.
--   - Creates a disabled bootstrap LocalScript for the future client entrypoint.
--   - Creates a migration map documenting which current V2 client functions
--     should move into each new controller.
--   - Adds references under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit HOVER_RACING_V2_Client.
--   - Require or enable the new controllers.
--   - Switch live menus/customisation/driving.
--   - Touch server actions, vehicle physics, VFX, mobile controls, LOD, lighting,
--     traffic, city assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_hierarchy_phase8_client_ui_controller_scaffold"

local function log(message)
	print("[NTR Phase8 UI Scaffold] " .. message)
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

local function writeLocalScript(parent, name, source)
	local scriptObject = parent:FindFirstChild(name)
	if scriptObject and not scriptObject:IsA("LocalScript") then
		error("Existing " .. scriptObject:GetFullName() .. " is a " .. scriptObject.ClassName .. ", expected LocalScript. No changes applied.")
	end
	if not scriptObject then
		scriptObject = Instance.new("LocalScript")
		scriptObject.Name = name
		scriptObject.Disabled = true
		scriptObject.Parent = parent
	end

	local createdBy = scriptObject:GetAttribute("CreatedBy")
	if scriptObject.Source ~= "" and createdBy ~= SCRIPT_ID then
		log("Skipped existing manually-created LocalScript: " .. scriptObject:GetFullName())
		return scriptObject, false
	end

	scriptObject.Disabled = true
	scriptObject.Source = source
	scriptObject:SetAttribute("CreatedBy", SCRIPT_ID)
	scriptObject:SetAttribute("MigrationStatus", "DisabledFutureBootstrap")
	scriptObject:SetAttribute("LiveEnabled", false)
	return scriptObject, true
end

local starterPlayerScripts = child(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local currentClient = starterPlayerScripts:FindFirstChild("HOVER_RACING_V2_Client")
if not currentClient or not currentClient:IsA("LocalScript") then
	error("Could not find StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client. Run this from the current working project before changing live client names.")
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local shared = folder(ntr, "Shared")
local sharedModules = folder(shared, "Modules")
local sharedUI = folder(sharedModules, "UI")
local compatibility = folder(ntr, "Compatibility")

local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local uiControllers = folder(controllers, "UI")
local garageControllers = folder(controllers, "Garage")
local previewControllers = folder(controllers, "Preview")
local runtimeControllers = folder(controllers, "Runtime")
local clientStateFolder = folder(clientRoot, "State")

clientRoot:SetAttribute("MigrationStatus", "ScaffoldOnly")
clientRoot:SetAttribute("LiveEnabled", false)
clientRoot:SetAttribute("CurrentLiveClient", currentClient:GetFullName())

objectValue(compatibility, "CurrentLiveClient", currentClient)
objectValue(compatibility, "FutureClientRoot", clientRoot)

local baseControllerSource = [=[
-- Neo Tokyo Racers staged client controller.
-- Scaffold only: this module is not required by live gameplay yet.
--
-- Migration rule:
--   Move one existing menu surface at a time from HOVER_RACING_V2_Client.
--   Do not pull driving, VFX, server actions, or mobile HUD logic into this file.

local Controller = {}
Controller.__index = Controller

function Controller.new(context)
	return setmetatable({
		Context = context,
		Connections = {},
		Active = false,
	}, Controller)
end

function Controller:Start()
	self.Active = true
end

function Controller:Stop()
	self.Active = false
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
-- Neo Tokyo Racers UI migration map.
-- Scaffold only. This records the intended split from HOVER_RACING_V2_Client.

return {
	SourceOfTruth = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client",
	Status = "ScaffoldOnly",
	SafetyRule = "Do not switch live UI until each controller is moved and tested one at a time.",

	Controllers = {
		DealershipUIController = {
			Stage = "CockpitShop",
			CurrentFunctions = {
				"renderCockpitShop",
				"renderDealershipPanel",
				"renderStatsPanel",
				"applyDealershipLayout",
			},
			DoNotMoveYet = {
				"startDriving",
				"setupControls",
				"DrivingControllerV47 bootstrap",
			},
		},

		CockpitPaintUIController = {
			Stage = "CockpitPaint",
			CurrentFunctions = {
				"renderCockpitPaint",
				"renderColourPicker",
				"syncPicker",
				"pickerColor",
				"makeSlider",
			},
		},

		ModuleShopUIController = {
			Stage = "ModuleShop",
			CurrentFunctions = {
				"renderModuleShop",
				"renderSlotSelection",
				"renderModuleOptions",
				"modulesForSlot",
				"slotDisplayName",
			},
		},

		CustomisationUIController = {
			Stage = "Customise",
			CurrentFunctions = {
				"renderCustomise",
				"renderCustomiseLeft",
				"renderCosmetics",
				"getUpgrade",
			},
		},

		PreviewVehicleController = {
			Responsibility = "Garage preview model only",
			CurrentFunctions = {
				"buildPreview",
				"clearPreviewModules",
				"pivotModuleToSlot",
				"applyColors",
				"setCameraSection",
				"updateCamera",
			},
		},

		NavigationController = {
			Responsibility = "Next/back/stage routing only",
			CurrentFunctions = {
				"showStage",
				"updateNav",
				"setNextText",
				"showTop",
			},
		},

		StatsPanelController = {
			Responsibility = "Stats panel rendering and preview deltas",
			CurrentFunctions = {
				"renderStatsOnly",
				"currentStats",
			},
		},

		CashPanelController = {
			Responsibility = "Available cash and Get More panel",
			CurrentFunctions = {
				"showCashShop",
			},
		},
	},
}
]=]

local uiStateSource = [=[
-- Shared garage UI state shape for future controllers.
-- Scaffold only; live HOVER_RACING_V2_Client still owns current state.

local GarageUIState = {}

function GarageUIState.default()
	return {
		Stage = "CockpitShop",
		SelectedCategoryId = "BRUISER",
		SelectedCockpitId = nil,
		SelectedSlot = nil,
		SelectedModuleId = nil,
		CustomizeTarget = "ALL",
		CustomizeMode = "Overview",
		PreviewModules = {},
		PreviewUpgradeId = nil,
		Profile = nil,
	}
end

return GarageUIState
]=]

local routerSource = [=[
-- Future garage UI router.
-- Scaffold only; do not require from live scripts until Phase 8B/8C.

local GarageUIRouter = {}
GarageUIRouter.__index = GarageUIRouter

function GarageUIRouter.new(context)
	return setmetatable({
		Context = context,
		Stage = "CockpitShop",
		Controllers = {},
	}, GarageUIRouter)
end

function GarageUIRouter:Register(stage, controller)
	self.Controllers[stage] = controller
end

function GarageUIRouter:Show(stage)
	local previous = self.Controllers[self.Stage]
	if previous and previous.Stop then
		previous:Stop()
	end

	self.Stage = stage

	local nextController = self.Controllers[stage]
	if nextController and nextController.Start then
		nextController:Start()
	end
end

return GarageUIRouter
]=]

local bootstrapSource = [=[
-- Neo Tokyo Racers future client bootstrap.
-- Disabled scaffold only. Current live client remains:
-- StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client

warn("[NeoTokyoRacersClient] Disabled scaffold was enabled manually. It does not start live UI yet.")
]=]

writeModule(sharedUI, "GarageUIMigrationMap", migrationMapSource, "Maps current HOVER_RACING_V2_Client UI functions to future controller modules.")
writeModule(sharedUI, "GarageUIState", uiStateSource, "Shared state shape for future garage UI controllers.")
writeModule(sharedUI, "GarageUIRouter", routerSource, "Future stage router for garage/dealership/customisation UI.")

writeModule(uiControllers, "DealershipUIController", baseControllerSource, "Future dealership cockpit/category grid controller.")
writeModule(uiControllers, "CockpitPaintUIController", baseControllerSource, "Future cockpit colour picker controller.")
writeModule(uiControllers, "ModuleShopUIController", baseControllerSource, "Future fixed slot module shop controller.")
writeModule(uiControllers, "CustomisationUIController", baseControllerSource, "Future upgrade/cosmetic/module colour customisation controller.")
writeModule(uiControllers, "ColourPickerController", baseControllerSource, "Future shared HSB/default colour picker controller.")
writeModule(uiControllers, "StatsPanelController", baseControllerSource, "Future vehicle stats and preview delta controller.")
writeModule(uiControllers, "NavigationController", baseControllerSource, "Future next/back/top-title routing controller.")
writeModule(uiControllers, "CashPanelController", baseControllerSource, "Future available cash and Get More panel controller.")
writeModule(garageControllers, "GarageCameraController", baseControllerSource, "Future garage orbit camera controller.")
writeModule(previewControllers, "PreviewVehicleController", baseControllerSource, "Future garage preview vehicle builder/controller.")
writeModule(runtimeControllers, "DrivingClientBridge", baseControllerSource, "Future bridge between garage exit and current driving controller. Do not replace DrivingControllerV47 here.")
writeModule(clientStateFolder, "ClientSessionState", uiStateSource, "Future client session state. Current live state remains inside HOVER_RACING_V2_Client.")

writeLocalScript(clientRoot, "NeoTokyoRacersClient_Bootstrap_Disabled", bootstrapSource)

log("Created staged client UI controller structure under StarterPlayerScripts.NeoTokyoRacersClient.")
log("Created shared Garage UI migration map/router/state modules under ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.")
log("No live UI, driving, VFX, server, lighting, LOD, or traffic behaviour was changed.")
