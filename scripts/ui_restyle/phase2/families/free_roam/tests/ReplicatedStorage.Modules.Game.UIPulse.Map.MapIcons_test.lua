-- Owns the pure tests for Map.MapIcons; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.Map.MapIcons_test. Requires: none (modules come from env.Load; UI.MapMath from classic/sources).
local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
local MAPMATH = "ReplicatedStorage.Modules.Game.UI.MapMath"

local function harness()
	local results = {}
	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end
	local function expect(actual, expected, what)
		if actual ~= expected then
			error(tostring(what) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
		end
	end
	local function near(actual, expected, what, tolerance)
		if type(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 1e-6) then
			error(tostring(what) .. ": expected about " .. tostring(expected) .. ", got " .. tostring(actual), 2)
		end
	end
	return results, case, expect, near
end

local SNAPSHOT = { "Visible", "Position", "Size", "Rotation", "ZIndex", "Text", "Image", "ImageRectOffset", "ImageColor3", "BackgroundTransparency", "Parent" }
local function snapshot(root)
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	local parts = { tostring(#list) }
	for _, instance in list do
		for _, property in SNAPSHOT do
			local ok, value = pcall(function()
				return (instance :: any)[property]
			end)
			if ok then
				table.insert(parts, property .. "=" .. tostring(value))
			end
		end
	end
	return table.concat(parts, ";")
end

local function fakeTiles()
	return { new = function()
		return { Complete = true, Cull = function() end, Destroy = function() end }
	end }
end

local function fakeMarkers(all)
	local handlers = {}
	local markers = { Store = all or {} }
	markers.Changed = { Connect = function(_, handler)
		table.insert(handlers, handler)
		return { Disconnect = function() end }
	end }
	function markers.All()
		return table.clone(markers.Store)
	end
	function markers.Get(id)
		return markers.Store[id]
	end
	function markers.Set(id, marker)
		marker.Id = id
		markers.Store[id] = marker
		for _, handler in handlers do
			handler(id, marker)
		end
		return marker
	end
	function markers.Remove(id)
		markers.Store[id] = nil
		for _, handler in handlers do
			handler(id, nil)
		end
	end
	return markers
end

-- Points the shared-module seams of the Map modules at fakes and at the real, pure MapMath source.
local function seams(env, markers)
	local MapCanvas = env.Load(UIP .. "Map.MapCanvas")
	local MapIcons = env.Load(UIP .. "Map.MapIcons")
	local MapRoute = env.Load(UIP .. "Map.MapRoute")
	local saved = { MapCanvas._math, MapCanvas._tiles, MapCanvas._hudConfig, MapIcons._markers, MapIcons._defer, MapRoute._config }
	local MapMath = env.Load(MAPMATH)
	MapCanvas._reset()
	MapCanvas._math = function()
		return MapMath
	end
	MapCanvas._tiles = fakeTiles
	MapCanvas._hudConfig = function()
		return nil
	end
	MapIcons._markers = function()
		return markers
	end
	MapIcons._defer = function(callback)
		callback()
	end
	MapRoute._config = function()
		return nil
	end
	MapCanvas._load()
	return MapCanvas, MapIcons, MapRoute, MapMath, function()
		MapCanvas._math, MapCanvas._tiles, MapCanvas._hudConfig = saved[1], saved[2], saved[3]
		MapIcons._markers, MapIcons._defer, MapRoute._config = saved[4], saved[5], saved[6]
		MapCanvas._reset()
	end
end

local function mapView(MapCanvas, w, h, studs, rotation, round, fullMap)
	return { Calibration = MapCanvas.Calibration(), CentreX = 100, CentreZ = -250, VisibleStuds = studs, RotationDegrees = rotation or 0,
		Size = Vector2.new(w, h), Round = round == true, FullMap = fullMap == true }
end

return function(_M, env)
	local results, case, expect, near = harness()
	local markers = fakeMarkers({
		Poi_A = { Position = Vector3.new(100, 0, -250), Icon = "Dealership", Kind = "Place", Priority = 14, Minimap = true, FullMap = true, EdgeClamp = false },
		Poi_B = { Position = Vector3.new(90000, 0, 90000), Icon = "Race", Kind = "Race", Priority = 12, Minimap = true, FullMap = true, EdgeClamp = false },
		Waypoint = { Position = Vector3.new(90000, 0, -250), Icon = "Waypoint", Kind = "Waypoint", Priority = 50, Minimap = true, FullMap = true, EdgeClamp = true },
		MiniOnly = { Position = Vector3.new(120, 0, -250), Icon = "Job", Kind = "Job", Priority = 20, Minimap = true, FullMap = false, EdgeClamp = false },
	})
	local MapCanvas, MapIcons, _, _, restore = seams(env, markers)
	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local scope = env.Scope()

	case("GlyphFor keeps sheet names and falls back by kind", function()
		expect(MapIcons.GlyphFor("Garage", "Place"), "Garage", "known")
		expect(MapIcons.GlyphFor("", "Race"), "Race", "empty race")
		expect(MapIcons.GlyphFor("SomethingNew", "Waypoint"), "Waypoint", "unknown waypoint")
		expect(MapIcons.GlyphFor(nil, "Player"), "OtherPlayer", "nil player")
		expect(MapIcons.GlyphFor("SomethingNew", "Place"), "Job", "unknown place")
		expect(MapIcons.GlyphFor("SomethingNew", nil), "Job", "no kind")
	end)

	case("Place, rect: inside shows, outside hides, an edge marker slides to the rim", function()
		local x, y, shown = MapIcons.Place(50, 60, 200, 100, false, false, 10, 8)
		expect(shown, true, "inside")
		expect(x, 50, "x kept")
		expect(y, 60, "y kept")
		local _, _, far = MapIcons.Place(400, 50, 200, 100, false, false, 10, 8)
		expect(far, false, "outside hides")
		local _, _, overscan = MapIcons.Place(205, 50, 200, 100, false, false, 10, 8)
		expect(overscan, true, "inside the overscan")
		local cx, cy, clamped = MapIcons.Place(400, 50, 200, 100, false, true, 10, 8)
		expect(clamped, true, "edge marker shows")
		near(cx, 190, "clamped x")
		near(cy, 50, "clamped y")
		local _, _, nan = MapIcons.Place(0 / 0, 5, 200, 100, false, true, 10, 8)
		expect(nan, false, "nan hides")
	end)

	case("Place, round: the rim is the circle", function()
		local _, _, inside = MapIcons.Place(100, 100, 200, 200, true, false, 10, 8)
		expect(inside, true, "centre")
		local _, _, corner = MapIcons.Place(5, 5, 200, 200, true, false, 10, 8)
		expect(corner, false, "a corner is outside the circle")
		local x, y, clamped = MapIcons.Place(400, 100, 200, 200, true, true, 10, 8)
		expect(clamped, true, "edge marker shows")
		near(x, 190, "rim x")
		near(y, 100, "rim y")
	end)

	case("Pick is MapMath.PickNearest", function()
		local points = { { Id = "a", X = 10, Y = 10, Priority = 1 }, { Id = "b", X = 11, Y = 10, Priority = 9 }, { Id = "c", X = 60, Y = 60, Priority = 0 } }
		expect(MapIcons.Pick(points, 10, 10, 20), "b", "priority wins within 2 px")
		expect(MapIcons.Pick(points, 58, 58, 20), "c", "nearest")
		expect(MapIcons.Pick(points, 200, 200, 20), nil, "none in radius")
	end)

	case("pool: surface flag, compare before write, reuse without churn, edge markers in the overlay", function()
		local content, overlay = env.Detached("Frame"), env.Detached("Frame")
		local ctx = Metrics.Fixed({ Size = Vector2.new(1920, 1080) })
		Metrics.Bind(content, ctx)
		Metrics.Bind(overlay, ctx)
		local icons = MapIcons.New(content, overlay, { IconSize = 46, FullMap = true }, scope)
		expect(icons.Count(), 3, "MiniOnly is not on the full map")
		local view = mapView(MapCanvas, 1920, 1080, 5000, 0, false, true)
		icons.Step(view)
		expect(icons.HitTest(Vector2.new(960, 540)), "Poi_A", "the marker under the view centre")
		expect(icons.HitTest(Vector2.new(300, 300)), nil, "nothing there")
		local edge = overlay:FindFirstChild("MapIconsEdge")
		expect(edge ~= nil and #edge:GetChildren(), 1, "one edge-clamped icon in the overlay")
		local beforeContent, beforeOverlay = snapshot(content), snapshot(overlay)
		icons.Step(view)
		expect(snapshot(content), beforeContent, "second step, content")
		expect(snapshot(overlay), beforeOverlay, "second step, overlay")

		-- A restyle of a shown icon keeps it shown: Surface re-applies the component's own Visible on Set.
		local main = content:FindFirstChild("MapIcons")
		local function shownIcons()
			local n = 0
			for _, child in main:GetChildren() do
				if child.Visible then
					n += 1
				end
			end
			return n
		end
		expect(shownIcons(), 1, "one icon in view")
		markers.Set("Poi_A", { Position = Vector3.new(100, 0, -250), Icon = "Garage", Kind = "Place", Priority = 14, Minimap = true, FullMap = true, EdgeClamp = false })
		expect(shownIcons(), 1, "a restyled icon stays shown")

		-- A marker leaves and another arrives: the pooled instance is reused.
		local count = #content:GetDescendants()
		markers.Remove("Poi_B")
		markers.Set("Poi_C", { Position = Vector3.new(200, 0, -250), Icon = "Garage", Kind = "Place", Priority = 14, Minimap = true, FullMap = true, EdgeClamp = false })
		icons.Step(view)
		expect(#content:GetDescendants(), count, "no instance created or destroyed")
		expect(icons.Count(), 3, "three records")

		icons.SetVisible(false)
		expect(icons.HitTest(Vector2.new(960, 540)), nil, "a hidden layer hits nothing")
		icons.Destroy()
		icons.Destroy()
		expect(#content:GetChildren() + #overlay:GetChildren(), 0, "empty after Destroy")
	end)

	restore()
	return results
end
