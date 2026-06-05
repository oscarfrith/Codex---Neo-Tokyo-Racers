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
