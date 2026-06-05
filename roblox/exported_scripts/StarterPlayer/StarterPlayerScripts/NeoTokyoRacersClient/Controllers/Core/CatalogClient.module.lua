-- Neo Tokyo Racers catalog lookup boundary.
-- Phase A module. Mirrors HOVER_RACING_V2_Client catalog helper behaviour.

local CatalogClient = {}
CatalogClient.__index = CatalogClient

local function cloneArray(list)
	local copy = {}
	for i, value in ipairs(list or {}) do
		copy[i] = value
	end
	return copy
end

function CatalogClient.new(state)
	return setmetatable({
		State = state,
	}, CatalogClient)
end

function CatalogClient:GetCategory(categoryId)
	local state = self.State or {}
	local wanted = categoryId or state.CategoryId
	for _, category in ipairs((state.Catalog and state.Catalog.Categories) or {}) do
		if category.CategoryId == wanted then
			return category
		end
	end
	return nil
end

function CatalogClient:SortedSlots(categoryId)
	local category = self:GetCategory(categoryId)
	local slots = cloneArray(category and category.Slots)
	table.sort(slots, function(a, b)
		return (a.Order or 99) < (b.Order or 99)
	end)
	return slots
end

function CatalogClient:GetSlot(slotId)
	for _, slot in ipairs(self:SortedSlots()) do
		if slot.SlotId == slotId then
			return slot
		end
	end
	return nil
end

function CatalogClient:GetCockpit(cockpitId)
	local category = self:GetCategory()
	for _, cockpit in ipairs((category and category.Cockpits) or {}) do
		if cockpit.CockpitId == cockpitId then
			return cockpit
		end
	end
	return nil
end

function CatalogClient:GetModule(moduleId)
	local category = self:GetCategory()
	for _, list in pairs((category and category.Modules) or {}) do
		for _, module in ipairs(list) do
			if module.ModuleId == moduleId then
				return module
			end
		end
	end
	return nil
end

function CatalogClient:ModulesForSlot(slotId)
	local state = self.State or {}
	local slot = self:GetSlot(slotId)
	local category = self:GetCategory()
	local result = {}
	if not slot or not category then
		return result
	end

	local list = (category.Modules and category.Modules[slot.ModuleType]) or {}
	for _, module in ipairs(list) do
		if not slot.AllowedModuleFolder or slot.AllowedModuleFolder == "" or module.ModuleFolder == slot.AllowedModuleFolder then
			table.insert(result, module)
		end
	end

	local owned = (state.Profile and state.Profile.OwnedModules) or {}
	table.sort(result, function(a, b)
		local aOwned = owned[a.ModuleId] == true
		local bOwned = owned[b.ModuleId] == true
		if aOwned ~= bOwned then
			return not aOwned
		end
		return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
	end)

	return result
end

function CatalogClient.SlotDisplayName(slot)
	local slotId = typeof(slot) == "table" and slot.SlotId or tostring(slot or "")
	if slotId == "Engine1" then return "Front Engine" end
	if slotId == "Engine2" then return "Rear Engine" end
	if typeof(slot) == "table" then return slot.DisplayName or slot.SlotId end
	return slotId
end

return CatalogClient
