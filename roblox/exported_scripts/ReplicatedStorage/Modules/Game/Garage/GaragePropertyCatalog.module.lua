-- Neo Tokyo Racers garage property catalogue.
-- Persistence Phase 13. Server and client seed data for purchasable garage locations.

local GaragePropertyCatalog = {}

GaragePropertyCatalog.Properties = {
	{
		PropertyId = "APT_BLOCK_A_SLOT_01",
		DisplayName = "Kanda Lift Bay",
		District = "Kanda Stack Apartments",
		Description = "Compact apartment-block garage with one extra vehicle space.",
		Spaces = 1,
		Price = 50000,
		Image = "",
		Available = true,
		SortOrder = 10,
	},
	{
		PropertyId = "APT_BLOCK_B_SLOT_02",
		DisplayName = "Shibuya Twin Bay",
		District = "Shibuya Heights",
		Description = "Two-space apartment-block garage for growing collections.",
		Spaces = 2,
		Price = 125000,
		Image = "",
		Available = true,
		SortOrder = 20,
	},
	{
		PropertyId = "HARBOR_STACK_SLOT_03",
		DisplayName = "Harbor Stack Garage",
		District = "Harbor Megablock",
		Description = "Three-space collector garage for later progression tiers.",
		Spaces = 3,
		Price = 260000,
		Image = "",
		Available = true,
		SortOrder = 30,
	},
	{
		PropertyId = "ROPPONGI_SKY_VAULT_04",
		DisplayName = "Roppongi Sky Vault",
		District = "Roppongi Arcology",
		Description = "High-rise two-space showcase garage for late starter progression.",
		Spaces = 2,
		Price = 420000,
		Image = "",
		Available = true,
		SortOrder = 40,
	},
}

function GaragePropertyCatalog.List()
	table.sort(GaragePropertyCatalog.Properties, function(a, b)
		return (a.SortOrder or 9999) < (b.SortOrder or 9999)
	end)
	return GaragePropertyCatalog.Properties
end

function GaragePropertyCatalog.ById(propertyId)
	propertyId = tostring(propertyId or "")
	for _, property in ipairs(GaragePropertyCatalog.List()) do
		if tostring(property.PropertyId) == propertyId then
			return property
		end
	end
	return nil
end

function GaragePropertyCatalog.TotalAvailableSpaces()
	local spaces = 0
	for _, property in ipairs(GaragePropertyCatalog.List()) do
		if property.Available == true then
			spaces += math.max(0, math.floor(tonumber(property.Spaces) or 0))
		end
	end
	return spaces
end

return GaragePropertyCatalog
