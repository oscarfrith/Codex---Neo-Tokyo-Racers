-- Read-only access shared by authoritative instance calculations and public records.
local Definition = {}
function Definition.Attribute(item, name)
    if typeof(item) == "Instance" then return item:GetAttribute(name) end
    return item and item[name]
end
function Definition.Paths(item)
    if typeof(item) == "Instance" then
        local root = item:FindFirstChild("VehiclePerformanceV2UpgradePaths") or item:FindFirstChild("UpgradePaths")
        local paths = {}
        if root then for _, path in root:GetChildren() do if path:IsA("Folder") then table.insert(paths, path) end end end
        return paths
    end
    return item and table.clone(item.UpgradePaths or {}) or {}
end
function Definition.Path(item, name)
    if typeof(item) == "Instance" then
        local root = item:FindFirstChild("VehiclePerformanceV2UpgradePaths") or item:FindFirstChild("UpgradePaths")
        return root and root:FindFirstChild(name)
    end
    for _, path in Definition.Paths(item) do if path.Name == name then return path end end
end
return table.freeze(Definition)
