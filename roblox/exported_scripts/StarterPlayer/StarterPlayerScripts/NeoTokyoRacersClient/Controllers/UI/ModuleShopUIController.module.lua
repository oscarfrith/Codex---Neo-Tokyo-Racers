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
