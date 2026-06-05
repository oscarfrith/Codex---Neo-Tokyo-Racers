-- Neo Tokyo Racers - Main Client Extraction Phase C
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates staged garage screen controller modules for the future extraction of
--   HOVER_RACING_V2_Client. This phase prepares dealership, cockpit paint,
--   module shop, customisation, navigation, and stats-panel boundaries without
--   changing live gameplay.
--
-- Safe effects:
--   - Creates/updates ModuleScripts under:
--     StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit, disable, enable, rename, move, or delete HOVER_RACING_V2_Client.
--   - Switch live dealership, paint, module, customisation, navigation, or stats UI.
--   - Change preview building, camera logic, server actions, vehicle logic, driving,
--     VFX runtime, mobile controls, LOD, lighting, traffic, assets, or
--     Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_client_phaseC_garage_screen_controllers"
local PHASE8_SCRIPT_ID = "roblox_hierarchy_phase8_client_ui_controller_scaffold"
local PHASE_A_SCRIPT_ID = "roblox_client_phaseA_core_boundary_modules"
local PHASE_B_SCRIPT_ID = "roblox_client_phaseB_preview_colour_modules"

local function log(message)
	print("[NTR Client Phase C] " .. message)
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

local function canOverwrite(module)
	if module.Source == "" then
		return true
	end
	local createdBy = module:GetAttribute("CreatedBy")
	local status = module:GetAttribute("MigrationStatus")
	return createdBy == SCRIPT_ID
		or createdBy == PHASE8_SCRIPT_ID
		or status == "ScaffoldOnly"
		or status == "PhaseC_GarageScreenBoundary"
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

	if not canOverwrite(module) then
		error("Target " .. module:GetFullName() .. " already exists and was not created by the scaffold or this phase. No changes applied.")
	end

	module.Source = source
	module:SetAttribute("CreatedBy", SCRIPT_ID)
	module:SetAttribute("MigrationStatus", "PhaseC_GarageScreenBoundary")
	module:SetAttribute("LiveEnabled", false)
	module:SetAttribute("Description", description or "")
	module:SetAttribute("LastUpdated", os.date("%Y-%m-%d %H:%M:%S"))
	return module
end

local dealershipSource = [=[
-- Neo Tokyo Racers dealership screen controller.
-- Phase C module. Builds dealership view data; live UI is not switched yet.

local DealershipUIController = {}

local controllersFolder = script.Parent.Parent
local coreFolder = controllersFolder:WaitForChild("Core")
local CatalogClient = require(coreFolder:WaitForChild("CatalogClient"))

DealershipUIController.Stage = "CockpitShop"

function DealershipUIController.Create(state)
	return {
		State = state,
		Catalog = CatalogClient.new(state),
	}
end

function DealershipUIController.BuildViewModel(state)
	local catalog = CatalogClient.new(state)
	local selectedCategory = catalog:GetCategory()
	local selectedCockpit = catalog:GetCockpit(state.SelectedCockpit)
	local categories = {}
	local cockpits = {}

	for _, category in ipairs((state.Catalog and state.Catalog.Categories) or {}) do
		table.insert(categories, {
			CategoryId = category.CategoryId,
			DisplayName = category.DisplayName or string.upper(tostring(category.CategoryId or "CATEGORY")),
			Selected = category.CategoryId == state.CategoryId,
		})
	end

	for _, cockpit in ipairs((selectedCategory and selectedCategory.Cockpits) or {}) do
		table.insert(cockpits, {
			CockpitId = cockpit.CockpitId,
			DisplayName = cockpit.DisplayName or cockpit.CockpitId,
			Price = cockpit.Price or 0,
			Stats = cockpit.Stats or {},
			Slots = cockpit.Slots or selectedCategory.Slots or {},
			Selected = cockpit.CockpitId == state.SelectedCockpit,
			Owned = state.Profile
				and state.Profile.OwnedCockpits
				and state.Profile.OwnedCockpits[cockpit.CockpitId] == true,
		})
	end

	return {
		Stage = DealershipUIController.Stage,
		Title = "Dealership",
		Subtitle = "Choose a vehicle category, then pick a cockpit.",
		Cash = state.Profile and state.Profile.Cash or 0,
		CategoryId = state.CategoryId,
		SelectedCockpitId = state.SelectedCockpit,
		SelectedCockpit = selectedCockpit,
		Categories = categories,
		Cockpits = cockpits,
		Stats = selectedCockpit and selectedCockpit.Stats or {},
		ModuleSlots = selectedCockpit and selectedCockpit.Slots or (selectedCategory and selectedCategory.Slots) or {},
		PrimaryAction = selectedCockpit and "SELECT" or nil,
	}
end

function DealershipUIController.SelectCategory(state, categoryId)
	state.CategoryId = categoryId
	local category = CatalogClient.new(state):GetCategory(categoryId)
	if category and category.Cockpits and category.Cockpits[1] then
		state.SelectedCockpit = category.Cockpits[1].CockpitId
	end
	return state.SelectedCockpit
end

function DealershipUIController.SelectCockpit(state, cockpitId)
	state.SelectedCockpit = cockpitId
	return cockpitId
end

function DealershipUIController.Render(context)
	local viewModel = DealershipUIController.BuildViewModel(context.State)
	if context.Renderers and context.Renderers.Dealership then
		return context.Renderers.Dealership(viewModel, context)
	end
	return viewModel
end

return DealershipUIController
]=]

local cockpitPaintSource = [=[
-- Neo Tokyo Racers cockpit paint screen controller.
-- Phase C module. Coordinates cockpit colour channels and staged colour picker calls.

local CockpitPaintUIController = {}

local controllersFolder = script.Parent.Parent
local uiFolder = controllersFolder:WaitForChild("UI")
local ColourPickerController = require(uiFolder:WaitForChild("ColourPickerController"))

CockpitPaintUIController.Stage = "CockpitPaint"
CockpitPaintUIController.DefaultChannels = { "Primary", "Secondary", "Detail" }

function CockpitPaintUIController.BuildViewModel(state)
	local cockpitColors = (state.Profile and state.Profile.CockpitColors) or {}
	return {
		Stage = CockpitPaintUIController.Stage,
		Title = "Paint Cockpit",
		Subtitle = "Choose primary, secondary, and detail colours.",
		Channels = CockpitPaintUIController.DefaultChannels,
		SelectedChannel = state.ColorChannel or "Primary",
		CurrentColor = cockpitColors[state.ColorChannel or "Primary"] or Color3.fromRGB(255, 255, 255),
		Cash = state.Profile and state.Profile.Cash or 0,
	}
end

function CockpitPaintUIController.ApplyLocalColor(state, channel, color)
	if not state.Profile then
		state.Profile = {}
	end
	if not state.Profile.CockpitColors then
		state.Profile.CockpitColors = {}
	end
	state.Profile.CockpitColors[channel] = color
	ColourPickerController.SyncStateFromColor(state, color)
end

function CockpitPaintUIController.Render(context)
	local viewModel = CockpitPaintUIController.BuildViewModel(context.State)
	if context.Renderers and context.Renderers.CockpitPaint then
		return context.Renderers.CockpitPaint(viewModel, context)
	end
	return viewModel
end

return CockpitPaintUIController
]=]

local moduleShopSource = [=[
-- Neo Tokyo Racers module shop screen controller.
-- Phase C module. Builds fixed-slot and module option view data.

local ModuleShopUIController = {}

local controllersFolder = script.Parent.Parent
local coreFolder = controllersFolder:WaitForChild("Core")
local previewFolder = controllersFolder:WaitForChild("Preview")
local CatalogClient = require(coreFolder:WaitForChild("CatalogClient"))
local PreviewCameraController = require(previewFolder:WaitForChild("PreviewCameraController"))

ModuleShopUIController.Stage = "ModuleShop"

local function installedModuleId(state, slotId)
	return state.Profile and state.Profile.InstalledModules and state.Profile.InstalledModules[slotId]
end

local function isOwned(state, moduleId)
	return state.Profile and state.Profile.OwnedModules and state.Profile.OwnedModules[moduleId] == true
end

function ModuleShopUIController.BuildSlotViewModel(state)
	local catalog = CatalogClient.new(state)
	local slots = {}
	for _, slot in ipairs(catalog:SortedSlots()) do
		local equipped = installedModuleId(state, slot.SlotId)
		table.insert(slots, {
			SlotId = slot.SlotId,
			DisplayName = CatalogClient.SlotDisplayName(slot.SlotId),
			ModuleType = slot.ModuleType,
			Order = slot.Order or 999,
			EquippedModuleId = equipped,
			StatusText = equipped and "equipped" or "empty",
			Selected = state.SelectedSlot == slot.SlotId,
		})
	end
	return slots
end

function ModuleShopUIController.BuildOptionsViewModel(state)
	local catalog = CatalogClient.new(state)
	local slot = catalog:GetSlot(state.SelectedSlot)
	local options = {}
	if not slot then
		return options
	end

	for _, moduleData in ipairs(catalog:ModulesForSlot(slot)) do
		local equipped = installedModuleId(state, state.SelectedSlot) == moduleData.ModuleId
		local owned = isOwned(state, moduleData.ModuleId)
		table.insert(options, {
			ModuleId = moduleData.ModuleId,
			DisplayName = moduleData.DisplayName or moduleData.ModuleId,
			Price = moduleData.Price or 0,
			Stats = moduleData.Stats or {},
			Owned = owned,
			Equipped = equipped,
			Selected = state.SelectedModuleId == moduleData.ModuleId,
			ActionText = owned and "EQUIP" or "BUY",
		})
	end
	return options
end

function ModuleShopUIController.SelectSlot(state, slotId)
	state.SelectedSlot = slotId
	state.SelectedModuleId = nil
	state.ModuleMode = "Options"
	PreviewCameraController.SetCameraSection(state, slotId)
end

function ModuleShopUIController.SelectModule(state, moduleId)
	state.SelectedModuleId = moduleId
	if state.SelectedSlot then
		state.PreviewModules = state.PreviewModules or {}
		state.PreviewModules[state.SelectedSlot] = moduleId
	end
end

function ModuleShopUIController.AfterBuyOrEquip(state)
	state.ModuleMode = "Slots"
	state.SelectedModuleId = nil
	state.PreviewModules = {}
end

function ModuleShopUIController.BuildViewModel(state)
	return {
		Stage = ModuleShopUIController.Stage,
		Title = "Build Modules",
		Subtitle = "Choose a fixed module slot.",
		Mode = state.ModuleMode or "Slots",
		SelectedSlot = state.SelectedSlot,
		Slots = ModuleShopUIController.BuildSlotViewModel(state),
		Options = ModuleShopUIController.BuildOptionsViewModel(state),
		Cash = state.Profile and state.Profile.Cash or 0,
		NextText = "CUSTOMISE MODULES",
	}
end

function ModuleShopUIController.Render(context)
	local viewModel = ModuleShopUIController.BuildViewModel(context.State)
	if context.Renderers and context.Renderers.ModuleShop then
		return context.Renderers.ModuleShop(viewModel, context)
	end
	return viewModel
end

return ModuleShopUIController
]=]

local customisationSource = [=[
-- Neo Tokyo Racers customisation screen controller.
-- Phase C module. Builds customisation target/action data without switching live UI.

local CustomisationUIController = {}

local controllersFolder = script.Parent.Parent
local coreFolder = controllersFolder:WaitForChild("Core")
local uiFolder = controllersFolder:WaitForChild("UI")
local CatalogClient = require(coreFolder:WaitForChild("CatalogClient"))
local ColourPickerController = require(uiFolder:WaitForChild("ColourPickerController"))

CustomisationUIController.Stage = "Customise"

local INVISIBLE_UPGRADES = {
	{ TargetId = "Brakes", DisplayName = "Brakes" },
	{ TargetId = "Converter", DisplayName = "Converter" },
	{ TargetId = "FuelSystem", DisplayName = "Fuel System" },
}

function CustomisationUIController.BuildTargets(state)
	local catalog = CatalogClient.new(state)
	local targets = {
		{ TargetId = "ALL", DisplayName = "Customise All", Kind = "All" },
		{ TargetId = "Cockpit", DisplayName = "Cockpit", Kind = "Cockpit" },
		{ TargetId = "THRUST_COLOR", DisplayName = "Thrust Color", Kind = "ThrustColor" },
	}

	for _, slot in ipairs(catalog:SortedSlots()) do
		if state.Profile and state.Profile.InstalledModules and state.Profile.InstalledModules[slot.SlotId] then
			table.insert(targets, {
				TargetId = slot.SlotId,
				DisplayName = CatalogClient.SlotDisplayName(slot.SlotId),
				Kind = "Module",
				ModuleId = state.Profile.InstalledModules[slot.SlotId],
			})
		end
	end

	for _, upgrade in ipairs(INVISIBLE_UPGRADES) do
		table.insert(targets, upgrade)
	end

	for _, target in ipairs(targets) do
		target.Selected = state.CustomizeTarget == target.TargetId
	end

	return targets
end

function CustomisationUIController.ChannelsForTarget(state, detectedChannels)
	if state.CustomizeTarget == "THRUST_COLOR" then
		return { "ThrustColor" }
	end
	if state.CustomizeTarget == "Cockpit" then
		return { "Primary", "Secondary", "Detail", "FrontLights", "RearLights" }
	end
	if state.CustomizeTarget == "ALL" then
		return { "Primary", "Secondary", "Detail", "Neon" }
	end
	return detectedChannels or { "Primary", "Secondary", "Detail", "Neon" }
end

function CustomisationUIController.BuildActions(state, selectedTarget)
	if selectedTarget == "THRUST_COLOR" then
		return {
			{ ActionId = "Colour", DisplayName = "COLOUR", Tone = "Grey" },
		}
	end
	if selectedTarget == "Cockpit" or selectedTarget == "ALL" then
		return {
			{ ActionId = "Colour", DisplayName = "COLOUR", Tone = "Grey" },
		}
	end
	return {
		{ ActionId = "Colour", DisplayName = "COLOUR", Tone = "Grey" },
		{ ActionId = "Cosmetics", DisplayName = "COSMETICS", Tone = "Grey" },
		{ ActionId = "Upgrade", DisplayName = "UPGRADE", Tone = "Green" },
	}
end

function CustomisationUIController.ApplyLocalColor(state, channel, color)
	if state.CustomizeTarget == "THRUST_COLOR" or channel == "ThrustColor" then
		if not state.Profile then state.Profile = {} end
		state.Profile.ThrustColor = color
		ColourPickerController.SyncStateFromColor(state, color)
		return
	end

	if state.CustomizeTarget == "Cockpit" or state.CustomizeTarget == "ALL" then
		if not state.Profile then state.Profile = {} end
		if not state.Profile.CockpitColors then state.Profile.CockpitColors = {} end
		state.Profile.CockpitColors[channel] = color
	else
		if not state.Profile then state.Profile = {} end
		if not state.Profile.ModuleColors then state.Profile.ModuleColors = {} end
		state.Profile.ModuleColors[state.CustomizeTarget] = state.Profile.ModuleColors[state.CustomizeTarget] or {}
		state.Profile.ModuleColors[state.CustomizeTarget][channel] = color
	end
	ColourPickerController.SyncStateFromColor(state, color)
end

function CustomisationUIController.BuildViewModel(state)
	local selectedTarget = state.CustomizeTarget or "ALL"
	return {
		Stage = CustomisationUIController.Stage,
		Title = "Customise",
		Subtitle = "Upgrade performance, change module colours, or unlock lights.",
		SelectedTarget = selectedTarget,
		Mode = state.CustomizeMode or "Overview",
		Targets = CustomisationUIController.BuildTargets(state),
		Actions = CustomisationUIController.BuildActions(state, selectedTarget),
		Channels = CustomisationUIController.ChannelsForTarget(state),
		Cash = state.Profile and state.Profile.Cash or 0,
		NextText = "START DRIVING",
	}
end

function CustomisationUIController.Render(context)
	local viewModel = CustomisationUIController.BuildViewModel(context.State)
	if context.Renderers and context.Renderers.Customisation then
		return context.Renderers.Customisation(viewModel, context)
	end
	return viewModel
end

return CustomisationUIController
]=]

local navigationSource = [=[
-- Neo Tokyo Racers garage navigation controller.
-- Phase C module. Encodes next/back stage routing without switching live UI.

local NavigationController = {}

NavigationController.StageOrder = {
	CockpitShop = "CockpitPaint",
	CockpitPaint = "ModuleShop",
	ModuleShop = "Customise",
	Customise = "SpawnVehicle",
}

NavigationController.BackOrder = {
	CockpitPaint = "CockpitShop",
	ModuleShop = "CockpitPaint",
	Customise = "ModuleShop",
}

NavigationController.NextLabels = {
	CockpitShop = "SELECT",
	CockpitPaint = "NEXT",
	ModuleShop = "CUSTOMISE MODULES",
	Customise = "START DRIVING",
}

function NavigationController.NextStage(stage)
	return NavigationController.StageOrder[stage]
end

function NavigationController.BackStage(stage)
	return NavigationController.BackOrder[stage]
end

function NavigationController.NextLabel(stage)
	return NavigationController.NextLabels[stage] or "NEXT"
end

function NavigationController.BuildViewModel(state)
	return {
		Stage = state.Stage,
		NextTarget = NavigationController.NextStage(state.Stage),
		BackTarget = NavigationController.BackStage(state.Stage),
		NextText = NavigationController.NextLabel(state.Stage),
		BackVisible = NavigationController.BackStage(state.Stage) ~= nil,
	}
end

return NavigationController
]=]

local statsPanelSource = [=[
-- Neo Tokyo Racers stats panel controller.
-- Phase C module. Builds stat bar data and preview deltas for future UI screens.

local StatsPanelController = {}

StatsPanelController.StatOrder = {
	"TopSpeed",
	"Acceleration",
	"Handling",
	"Drift",
	"Braking",
	"Weight",
	"Boost",
}

function StatsPanelController.Normalise(stat, value)
	local divisor = stat == "Weight" and 180 or 180
	return math.clamp((value or 0) / divisor, 0, 1)
end

function StatsPanelController.BuildRows(stats, baseStats)
	stats = stats or {}
	baseStats = baseStats or stats
	local rows = {}
	for _, stat in ipairs(StatsPanelController.StatOrder) do
		local value = stats[stat] or 0
		local baseValue = baseStats[stat] or value
		local amount = StatsPanelController.Normalise(stat, value)
		local baseAmount = StatsPanelController.Normalise(stat, baseValue)
		table.insert(rows, {
			Stat = stat,
			Value = value,
			BaseValue = baseValue,
			Amount = amount,
			BaseAmount = baseAmount,
			Delta = value - baseValue,
			DeltaTone = value > baseValue and "Positive" or (value < baseValue and "Negative" or "None"),
		})
	end
	return rows
end

function StatsPanelController.BuildViewModel(stats, baseStats)
	return {
		Title = "Vehicle Stats",
		Rows = StatsPanelController.BuildRows(stats, baseStats),
	}
end

return StatsPanelController
]=]

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local coreControllers = folder(controllers, "Core")
local previewControllers = folder(controllers, "Preview")
local uiControllers = folder(controllers, "UI")

local requiredPhaseA = {
	"ClientState",
	"GarageApiClient",
	"CatalogClient",
	"ClientThemeAdapter",
	"PaintClient",
}

local requiredPhaseBPreview = {
	"PreviewCameraController",
	"PreviewVehicleController",
}

local requiredPhaseBUI = {
	"ColourPickerController",
}

local readinessIssues = {}
for _, moduleName in ipairs(requiredPhaseA) do
	local module = coreControllers:FindFirstChild(moduleName)
	if not module or not module:IsA("ModuleScript") then
		table.insert(readinessIssues, "Missing Phase A module: " .. moduleName)
	elseif module:GetAttribute("CreatedBy") ~= PHASE_A_SCRIPT_ID then
		table.insert(readinessIssues, "Phase A module has unexpected CreatedBy: " .. module:GetFullName())
	end
end

for _, moduleName in ipairs(requiredPhaseBPreview) do
	local module = previewControllers:FindFirstChild(moduleName)
	if not module or not module:IsA("ModuleScript") then
		table.insert(readinessIssues, "Missing Phase B preview module: " .. moduleName)
	elseif module:GetAttribute("CreatedBy") ~= PHASE_B_SCRIPT_ID then
		table.insert(readinessIssues, "Phase B preview module has unexpected CreatedBy: " .. module:GetFullName())
	end
end

for _, moduleName in ipairs(requiredPhaseBUI) do
	local module = uiControllers:FindFirstChild(moduleName)
	if not module or not module:IsA("ModuleScript") then
		table.insert(readinessIssues, "Missing Phase B UI module: " .. moduleName)
	elseif module:GetAttribute("CreatedBy") ~= PHASE_B_SCRIPT_ID then
		table.insert(readinessIssues, "Phase B UI module has unexpected CreatedBy: " .. module:GetFullName())
	end
end

if #readinessIssues > 0 then
	error("Phase A/B modules are not ready. Run/test Phase A and Phase B first. Issues: " .. table.concat(readinessIssues, "; "))
end

local modules = {
	DealershipUIController = writeModule(uiControllers, "DealershipUIController", dealershipSource, "Future dealership category/cockpit screen controller."),
	CockpitPaintUIController = writeModule(uiControllers, "CockpitPaintUIController", cockpitPaintSource, "Future cockpit paint screen controller."),
	ModuleShopUIController = writeModule(uiControllers, "ModuleShopUIController", moduleShopSource, "Future fixed-slot module shop screen controller."),
	CustomisationUIController = writeModule(uiControllers, "CustomisationUIController", customisationSource, "Future vehicle customisation screen controller."),
	NavigationController = writeModule(uiControllers, "NavigationController", navigationSource, "Future next/back stage routing controller."),
	StatsPanelController = writeModule(uiControllers, "StatsPanelController", statsPanelSource, "Future stat bar and preview delta controller."),
}

local checks = {}
local function check(name, fn)
	local ok, result = pcall(fn)
	table.insert(checks, {
		Name = name,
		Passed = ok and result ~= false,
		Detail = ok and tostring(result == nil and "ok" or result) or tostring(result),
	})
end

local sampleState = {
	Stage = "CockpitShop",
	CategoryId = "bruiser",
	SelectedCockpit = "bruiser_01",
	SelectedSlot = "Engine1",
	SelectedModuleId = nil,
	ModuleMode = "Slots",
	CustomizeTarget = "ALL",
	CustomizeMode = "Overview",
	ColorChannel = "Primary",
	Catalog = {
		Categories = {
			{
				CategoryId = "bruiser",
				DisplayName = "Bruiser",
				Slots = {
					{ SlotId = "Engine1", ModuleType = "Engine", Order = 1 },
					{ SlotId = "Engine2", ModuleType = "Engine", Order = 2 },
				},
				Cockpits = {
					{ CockpitId = "bruiser_01", DisplayName = "Bruiser Origin", Price = 0, Stats = { TopSpeed = 120 } },
				},
				Modules = {
					Engine = {
						{ ModuleId = "engine_a", DisplayName = "Engine A", Price = 11000, Stats = { Boost = 8 } },
					},
				},
			},
		},
	},
	Profile = {
		Cash = 140000,
		OwnedCockpits = { bruiser_01 = true },
		OwnedModules = {},
		InstalledModules = { Engine1 = "engine_a" },
		CockpitColors = {},
		ModuleColors = {},
	},
}

check("DealershipUIController view model", function()
	local controller = require(modules.DealershipUIController)
	local view = controller.BuildViewModel(sampleState)
	if view.Stage ~= "CockpitShop" then return false end
	if #view.Cockpits < 1 then return false end
	if view.Cash ~= 140000 then return false end
	return "ok"
end)

check("CockpitPaintUIController channels", function()
	local controller = require(modules.CockpitPaintUIController)
	local view = controller.BuildViewModel(sampleState)
	if #view.Channels ~= 3 then return false end
	controller.ApplyLocalColor(sampleState, "Primary", Color3.fromRGB(1, 2, 3))
	if sampleState.Profile.CockpitColors.Primary ~= Color3.fromRGB(1, 2, 3) then return false end
	return "ok"
end)

check("ModuleShopUIController slots/options", function()
	local controller = require(modules.ModuleShopUIController)
	local view = controller.BuildViewModel(sampleState)
	if #view.Slots ~= 2 then return false end
	controller.SelectSlot(sampleState, "Engine1")
	controller.SelectModule(sampleState, "engine_a")
	if sampleState.PreviewModules.Engine1 ~= "engine_a" then return false end
	return "ok"
end)

check("CustomisationUIController targets/actions", function()
	local controller = require(modules.CustomisationUIController)
	local view = controller.BuildViewModel(sampleState)
	if #view.Targets < 4 then return false end
	if #view.Actions < 1 then return false end
	return "ok"
end)

check("NavigationController route labels", function()
	local controller = require(modules.NavigationController)
	if controller.NextStage("ModuleShop") ~= "Customise" then return false end
	if controller.NextLabel("Customise") ~= "START DRIVING" then return false end
	return "ok"
end)

check("StatsPanelController rows", function()
	local controller = require(modules.StatsPanelController)
	local view = controller.BuildViewModel({ TopSpeed = 120, Boost = 30 }, { TopSpeed = 100, Boost = 30 })
	if #view.Rows ~= 7 then return false end
	if view.Rows[1].Delta <= 0 then return false end
	return "ok"
end)

local passed = 0
for _, item in ipairs(checks) do
	if item.Passed then
		passed += 1
	end
end

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Main Client Phase C Report")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Garage screen controller modules were staged. Live `HOVER_RACING_V2_Client` was not edited.")
line("")
line("## Summary")
line("")
line("- Live client edited: false")
line("- Live behaviour changed: false")
line("- Phase A modules present: true")
line("- Phase B modules present: true")
line("- Modules written: 6")
line("- Passed checks: " .. tostring(passed) .. " / " .. tostring(#checks))
line("")
line("## Modules")
line("")
for name, module in pairs(modules) do
	line("- " .. name .. ": " .. module:GetFullName())
end
line("")
line("## Checks")
line("")
for _, item in ipairs(checks) do
	line("- " .. item.Name .. ": " .. (item.Passed and "passed" or "failed") .. " (" .. item.Detail .. ")")
end
line("")
line("## Safety")
line("")
line("- The staged modules are not active owners yet.")
line("- The main client still owns live dealership, paint, module shop, customisation, navigation, and stats rendering.")
line("- Phase D should be treated as the risky switch phase and should only begin after a full normal Play test.")

local reportValue = reportsFolder:FindFirstChild("MainClientPhaseC_GarageScreenReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "MainClientPhaseC_GarageScreenReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "MainClientPhaseC_GarageScreenReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("LiveClientEdited", false)
reportValue:SetAttribute("LiveBehaviourChanged", false)
reportValue:SetAttribute("PassedChecks", passed)
reportValue:SetAttribute("TotalChecks", #checks)

log("Phase C garage screen modules staged.")
log("Checks passed: " .. tostring(passed) .. " / " .. tostring(#checks))
log("Report saved to " .. reportValue:GetFullName())
print(reportValue.Value)
