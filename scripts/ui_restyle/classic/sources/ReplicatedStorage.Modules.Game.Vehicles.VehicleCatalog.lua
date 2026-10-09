-- Immutable public definitions generated from canonical authoring attributes.
-- No asset lookup, remotes, profile state or mutation authority.
local data = require(script.Parent.VehicleCatalogData)
local Catalog = { SchemaVersion = data.SchemaVersion, Revision = data.Revision }
function Catalog.Get(attribute, id, includeRetired)
    local index = attribute == "CockpitId" and data.Cockpits or attribute == "ModuleId" and data.Modules
    local record = index and index[tostring(id or "")]
    if record and (includeRetired or record.RetiredFromCatalog ~= true) then return record end
end
function Catalog.Resolve(attribute, value)
    if typeof(value) == "Instance" then return Catalog.Get(attribute, value:GetAttribute(attribute) or value.Name, true) end
    if typeof(value) == "table" then return Catalog.Get(attribute, value[attribute], value.IsVehicleDefinition == true) end
    return Catalog.Get(attribute, value)
end
return table.freeze(Catalog)
