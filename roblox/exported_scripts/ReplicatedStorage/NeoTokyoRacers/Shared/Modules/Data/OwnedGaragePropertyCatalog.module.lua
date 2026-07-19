-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V1
local Catalog={}
local properties={
	{
		PropertyId="STARTER_TWO_BAY",
		DisplayName="Kanda Two-Bay",
		District="Kanda Stack Apartments",
		Description="A private two-bay workshop with vehicle display, interior customisation and secure access.",
		Image="",
		TemplateId="StarterTwoBay",
		DisplaySpaceIds={"Space01","Space02"},
		VehicleCapacityContribution=2,
		Price=0,
		Available=true,
		Starter=true,
		SortOrder=10,
	},
}
local function clone(value)
	if type(value)~="table" then return value end
	local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy
end
function Catalog.List()
	local result=clone(properties)
	table.sort(result,function(a,b) if a.SortOrder~=b.SortOrder then return a.SortOrder<b.SortOrder end return a.PropertyId<b.PropertyId end)
	return result
end
function Catalog.ById(propertyId)
	propertyId=tostring(propertyId or "")
	for _,property in ipairs(properties) do if property.PropertyId==propertyId then return clone(property) end end
	return nil
end
function Catalog.SpaceIds(propertyId)
	local property=Catalog.ById(propertyId); return property and clone(property.DisplaySpaceIds) or {}
end
function Catalog.IsSpace(propertyId,slotId)
	for _,candidate in ipairs(Catalog.SpaceIds(propertyId)) do if candidate==tostring(slotId or "") then return true end end
	return false
end
return Catalog
