-- Canonical feature implementation (docs/architecture/map-markers-contract.md, owner Agent F).
-- Pure client registry of map markers. The minimap and the full map render from it through
-- MapIconLayer; this module draws nothing, has no remotes, saves or loops.
-- On first require it registers the static places in Config.UI.MapPois (ids "Poi_<name>") and
-- reads icon asset ids from Config.UI.MapIcons. Both folders are optional.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Signal"))

local MapMarkers = {}
MapMarkers.Changed = Signal.new() -- (id, marker or nil)
MapMarkers.IconsChanged = Signal.new() -- () icon asset ids in Config.UI.MapIcons changed

local KINDS = { Place = true, Race = true, Job = true, Waypoint = true, Activity = true, Player = true }
local EDGE_DEFAULT = { Waypoint = true, Activity = true }
local markers = {}

local function copy(id, marker)
	assert(type(id) == "string" and id ~= "", "MapMarkers id required")
	assert(type(marker) == "table", "MapMarkers marker table required")
	assert(typeof(marker.Position) == "Vector3", "MapMarkers marker Position must be a Vector3")
	local kind = KINDS[marker.Kind] and marker.Kind or "Place"
	local priority = tonumber(marker.Priority)
	if priority == nil or priority ~= priority then priority = 10 end
	local edge = marker.EdgeClamp
	if edge == nil then edge = EDGE_DEFAULT[kind] == true end
	return {
		Id = id,
		Position = marker.Position,
		Icon = tostring(marker.Icon or ""),
		Label = tostring(marker.Label or id),
		Kind = kind,
		Priority = priority,
		Color = typeof(marker.Color) == "Color3" and marker.Color or nil,
		Minimap = marker.Minimap ~= false,
		FullMap = marker.FullMap ~= false,
		EdgeClamp = edge == true,
		Pulse = marker.Pulse == true,
		-- Optional extras used by the full-map legend.
		Order = tonumber(marker.Order),
		RouteId = marker.RouteId ~= nil and tostring(marker.RouteId) or nil,
		DestinationId = marker.DestinationId ~= nil and tostring(marker.DestinationId) or nil,
		Static = marker.Static == true,
	}
end

function MapMarkers.Set(id, marker)
	local record = copy(id, marker)
	markers[id] = record
	MapMarkers.Changed:Fire(id, record)
	return record
end

function MapMarkers.Remove(id)
	if markers[id] == nil then return end
	markers[id] = nil
	MapMarkers.Changed:Fire(id, nil)
end

function MapMarkers.Get(id)
	return markers[id]
end

function MapMarkers.All()
	return table.clone(markers)
end

-- Icon asset ids ------------------------------------------------------------------------------
local iconFolder

-- Returns "rbxassetid://<id>" (or the stored content string), or "" when no asset is set.
function MapMarkers.IconAsset(key)
	if key == nil or key == "" or not iconFolder then return "" end
	local ok, value = pcall(function() return iconFolder:GetAttribute(tostring(key)) end)
	if not ok then return "" end
	local text = tostring(value or "")
	if text == "" or text == "0" then return "" end
	if string.match(text, "^%d+$") then return "rbxassetid://" .. text end
	return text
end

-- Static places ---------------------------------------------------------------------------------
local function registerPoi(folder)
	local position = folder:GetAttribute("Position")
	if typeof(position) ~= "Vector3" then return end -- not placed yet (e.g. integrator TODO)
	local kind = tostring(folder:GetAttribute("Kind") or "Place")
	MapMarkers.Set("Poi_" .. folder.Name, {
		Position = position,
		Icon = tostring(folder:GetAttribute("Icon") or (kind == "Race" and "Race" or "")),
		Label = tostring(folder:GetAttribute("Label") or folder.Name),
		Kind = kind,
		Priority = tonumber(folder:GetAttribute("Priority")) or (kind == "Race" and 12 or 14),
		EdgeClamp = folder:GetAttribute("EdgeClamp") == true,
		Order = tonumber(folder:GetAttribute("Order")) or 100,
		RouteId = folder:GetAttribute("RouteId"),
		DestinationId = folder:GetAttribute("DestinationId"),
		Static = true,
	})
end

task.spawn(function()
	local config = ReplicatedStorage:WaitForChild("Config", 15)
	local ui = config and config:WaitForChild("UI", 15)
	if not ui then return end
	iconFolder = ui:WaitForChild("MapIcons", 10)
	if iconFolder then
		iconFolder.AttributeChanged:Connect(function() MapMarkers.IconsChanged:Fire() end)
		MapMarkers.IconsChanged:Fire()
	else
		warn("[MapMarkers] Config.UI.MapIcons missing; renderers use fallback badges.")
	end
	local pois = ui:WaitForChild("MapPois", 10)
	if not pois then
		warn("[MapMarkers] Config.UI.MapPois missing; no static places on the map.")
		return
	end
	local function watch(folder)
		registerPoi(folder)
		folder.AttributeChanged:Connect(function()
			MapMarkers.Remove("Poi_" .. folder.Name)
			registerPoi(folder)
		end)
	end
	for _, folder in ipairs(pois:GetChildren()) do watch(folder) end
	pois.ChildAdded:Connect(watch)
	pois.ChildRemoved:Connect(function(folder) MapMarkers.Remove("Poi_" .. folder.Name) end)
end)

return MapMarkers
