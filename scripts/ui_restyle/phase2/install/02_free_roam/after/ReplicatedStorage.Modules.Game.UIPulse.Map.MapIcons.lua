-- Owns the Pulse icon layer of one map surface (a keyed pool of marker icons, placed upright each step); not the marker registry (UI.MapMarkers), the map canvas or the route line.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Map.MapIcons. Requires: Tokens, Sprites, Metrics, Surface, Collections, Map.MapCanvas (UI.MapMarkers and UI.MapMath lazily through seams).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Sprites = require(Kit.Sprites)
local Metrics = require(Kit.Metrics)
local Surface = require(Kit.Surface)
local Collections = require(Kit.Collections)
local MapCanvas = require(script.Parent.MapCanvas)

local MapIcons = {}

-- Test seams.
MapIcons._markers = function()
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local gameFolder = modules and modules:FindFirstChild("Game")
	local ui = gameFolder and gameFolder:FindFirstChild("UI")
	local module = ui and ui:FindFirstChild("MapMarkers")
	assert(module, "[Pulse.MapIcons] ReplicatedStorage.Modules.Game.UI.MapMarkers is missing")
	return require(module)
end
MapIcons._defer = task.defer

local HOLDER_Z = 3
local MAX_PRIORITY_Z = 60
-- Visibility goes through the component: Surface re-applies its own Visible on every Set and on every layout
-- change, so a direct Root.Visible write is undone there while the cached Shown still says shown.
local SHOW = { Visible = true }
local HIDE = { Visible = false }

-- A marker whose Icon key is not on the sheet falls back by kind (Classic drew a one-letter text glyph).
local KIND_FALLBACK = { Race = "Race", Waypoint = "Waypoint", Player = "OtherPlayer", Job = "Job", Activity = "Job", Place = "Job" }

function MapIcons.GlyphFor(icon: any, kind: any): string
	if type(icon) == "string" and Sprites.MapIcons.Glyphs[icon] then
		return icon
	end
	return KIND_FALLBACK[kind] or "Job"
end

-- Where a projected point is drawn. Returns x, y, shown. Pure.
-- Rect view (MapIconLayer 289-296): outside the overscan box an edge-clamped marker slides to the rim, any
-- other marker hides. Round view: the same rule against the circle.
function MapIcons.Place(x: number, y: number, w: number, h: number, round: boolean, edgeClamp: boolean, inset: number, overscan: number): (number, number, boolean)
	if x ~= x or y ~= y or w <= 0 or h <= 0 then
		return 0, 0, false
	end
	local cx, cy = w * 0.5, h * 0.5
	local ox, oy = x - cx, y - cy
	if round then
		local radius = math.min(cx, cy)
		local distance = math.sqrt(ox * ox + oy * oy)
		if distance <= math.max(0, radius - inset) then
			return x, y, true
		end
		if edgeClamp then
			local scale = distance > 0 and math.max(0, radius - inset) / distance or 0
			return cx + ox * scale, cy + oy * scale, true
		end
		return x, y, distance <= radius + overscan
	end
	if x >= -overscan and y >= -overscan and x <= w + overscan and y <= h + overscan then
		return x, y, true
	end
	if not edgeClamp then
		return x, y, false
	end
	-- MapMath.ClampToRect.
	local hx, hy = math.max(0, cx - inset), math.max(0, cy - inset)
	local scale = math.huge
	if math.abs(ox) > 1e-9 then
		scale = math.min(scale, hx / math.abs(ox))
	end
	if math.abs(oy) > 1e-9 then
		scale = math.min(scale, hy / math.abs(oy))
	end
	if scale == math.huge then
		scale = 0
	end
	scale = math.min(scale, 1)
	return cx + ox * scale, cy + oy * scale, true
end

-- points: {{Id, X, Y, Priority}}. MapMath.PickNearest (closest within radius; higher priority wins within 2 px). Pure.
function MapIcons.Pick(points: { any }, x: number, y: number, radius: number): string?
	local bestId, bestDistance, bestPriority = nil, math.huge, -math.huge
	for _, point in points do
		local distance = math.sqrt((point.X - x) ^ 2 + (point.Y - y) ^ 2)
		if distance <= radius then
			local priority = point.Priority or 0
			if distance < bestDistance - 2 or (math.abs(distance - bestDistance) <= 2 and priority > bestPriority) then
				bestId, bestDistance, bestPriority = point.Id, distance, priority
			end
		end
	end
	return bestId
end

local function holder(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = HOLDER_Z
	frame.Parent = parent
	return frame
end

function MapIcons.New(content: Frame, overlay: Frame, props: { IconSize: number, FullMap: boolean }, scope: any): any
	assert(typeof(content) == "Instance" and content:IsA("GuiObject"), "[Pulse.MapIcons] New needs a content GuiObject")
	assert(typeof(overlay) == "Instance" and overlay:IsA("GuiObject"), "[Pulse.MapIcons] New needs an overlay GuiObject")
	assert(type(props) == "table" and type(props.IconSize) == "number", "[Pulse.MapIcons] New needs IconSize")
	for key in props do
		if key ~= "IconSize" and key ~= "FullMap" then
			error("[Pulse.MapIcons] unknown key " .. tostring(key), 2)
		end
	end

	local Markers = MapIcons._markers()
	MapCanvas._load()
	local ctx = Metrics.Of(content)
	local flag = props.FullMap == true and "FullMap" or "Minimap"
	local white = Tokens.Colour.White

	local mainHolder = holder("MapIcons", content)
	local edgeHolder = holder("MapIconsEdge", overlay)

	local made = {}
	local function makeIn(parent, prefix)
		return function(index)
			local component = Surface.MapIcon(parent, {
				Name = prefix .. tostring(index),
				Icon = "Waypoint",
				Tint = white,
				Size = props.IconSize,
				Visible = false,
			}, scope)
			table.insert(made, component)
			-- Root and the cached draw state live with the pooled item, so a reused item never repeats a write.
			return { Component = component, Root = component.Instance, X = nil, Y = nil, Shown = false, Z = nil }
		end
	end
	local function reset(item)
		if item.Shown then
			item.Shown = false
			item.Component.Set(HIDE)
		end
	end
	local mainPool = Collections.Pool(makeIn(mainHolder, "Icon"), reset)
	local edgePool = Collections.Pool(makeIn(edgeHolder, "EdgeIcon"), reset)

	local records = {} -- marker id -> { Item, Pool, Edge, Marker }
	local frame = {}
	local hits = {}
	local visible = true
	local destroyed = false
	local syncQueued = false
	local iconPx, inset, overscan = 1, 1, 1

	local function measure()
		iconPx = ctx.Px(props.IconSize)
		inset = iconPx * 0.5 + 1
		overscan = iconPx * 0.5
	end
	measure()

	local function release(id)
		local record = records[id]
		if record then
			records[id] = nil
			reset(record.Item) -- hidden here too, whatever the pool does on Release
			record.Pool.Release(record.Item)
		end
	end

	local function style(record)
		local marker, item = record.Marker, record.Item
		item.Component.Set({ Icon = MapIcons.GlyphFor(marker.Icon, marker.Kind), Tint = marker.Color or white })
		local z = 1 + math.clamp(math.floor(tonumber(marker.Priority) or 0), 0, MAX_PRIORITY_Z)
		if item.Z ~= z then
			item.Z = z
			item.Root.ZIndex = z
		end
	end

	-- Pool growth and restyling happen here, on the marker signal, never inside Step.
	local function sync()
		syncQueued = false
		if destroyed then
			return
		end
		local all = Markers.All()
		for id, record in records do
			local marker = all[id]
			if not marker or marker[flag] == false or (marker.EdgeClamp == true) ~= record.Edge then
				release(id)
			end
		end
		for id, marker in all do
			if marker[flag] ~= false then
				local record = records[id]
				if not record then
					local edge = marker.EdgeClamp == true
					local pool = edge and edgePool or mainPool
					record = { Item = pool.Take(), Pool = pool, Edge = edge, Marker = nil }
					records[id] = record
				end
				if record.Marker ~= marker then
					record.Marker = marker
					style(record)
				end
			end
		end
	end

	local function queueSync()
		if syncQueued or destroyed then
			return
		end
		syncQueued = true
		MapIcons._defer(sync)
	end

	local self = {}

	function self.Step(view)
		if destroyed or not visible then
			return
		end
		MapCanvas.Frame(view, frame)
		local calibration = view.Calibration
		local w, h, round = view.Size.X, view.Size.Y, view.Round == true
		for _, record in records do
			local item = record.Item
			local position = record.Marker.Position
			local x, y = MapCanvas.Point(frame, calibration, position.X, position.Z)
			local px, py, shown = MapIcons.Place(x, y, w, h, round, record.Edge, inset, overscan)
			if shown then
				px, py = math.floor(px + 0.5), math.floor(py + 0.5)
				if px ~= item.X or py ~= item.Y then
					item.X, item.Y = px, py
					item.Root.Position = UDim2.fromOffset(px, py)
				end
			end
			if shown ~= item.Shown then
				item.Shown = shown
				item.Component.Set(shown and SHOW or HIDE)
			end
		end
	end

	-- point: content-local pixels. The radius is 0.75 of the drawn icon (MapIconLayer 320).
	function self.HitTest(point: Vector2): string?
		if destroyed or not visible then
			return nil
		end
		table.clear(hits)
		for id, record in records do
			local item = record.Item
			if item.Shown and item.X then
				table.insert(hits, { Id = id, X = item.X, Y = item.Y, Priority = record.Marker.Priority })
			end
		end
		return MapIcons.Pick(hits, point.X, point.Y, iconPx * 0.75)
	end

	function self.SetVisible(show: boolean)
		show = show == true
		if show == visible then
			return
		end
		visible = show
		mainHolder.Visible = show
		edgeHolder.Visible = show
	end

	function self.Count(): number
		local count = 0
		for _ in records do
			count += 1
		end
		return count
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		table.clear(records)
		for _, component in made do
			component.Destroy()
		end
		table.clear(made)
		mainHolder:Destroy()
		edgeHolder:Destroy()
	end

	scope:connect(Markers.Changed, queueSync)
	scope:connect(ctx.Changed, function(change)
		if type(change) ~= "table" or change.Layout then
			measure()
		end
	end)
	scope:add(self.Destroy)
	sync()
	return self
end

return MapIcons
