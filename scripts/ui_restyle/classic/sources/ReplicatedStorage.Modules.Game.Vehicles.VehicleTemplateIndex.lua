-- Physical preview lookup only. Public performance/browsing use VehicleCatalog.
-- Relative paths are generated once per authoring revision; no descendant scans.
local Catalog = require(script.Parent.VehicleCatalog)
local Index = {}
function Index.Find(root, attribute, id)
    if not root or id == nil then return nil end
    local record = Catalog.Get(attribute, id, true)
    if not record then return nil end
    local item = root
    for _, name in record.TemplatePath do
        item = item:FindFirstChild(name)
        if not item then return nil end
    end
    if item:IsA("Model") and tostring(item:GetAttribute(attribute) or item.Name) == tostring(id) then return item end
end
return table.freeze(Index)
