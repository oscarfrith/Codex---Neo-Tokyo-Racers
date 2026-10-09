-- Owns the pure tests for Map.MapRoute; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.Map.MapRoute_test. Requires: none (modules come from env.Load; UI.MapMath from classic/sources).
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

local function line(count, step)
	local us, vs = {}, {}
	for index = 1, count do
		us[index], vs[index] = (index - 1) * step, 0.5
	end
	return us, vs
end

return function(_M, env)
	local results, case, expect = harness()
	local MapCanvas, _, MapRoute, _, restore = seams(env, fakeMarkers())
	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local scope = env.Scope()

	case("FormatDistance is RoadRouting.FormatDistance", function()
		expect(MapRoute.FormatDistance(0, 5760), "<0.1 MI", "zero")
		expect(MapRoute.FormatDistance(575, 5760), "<0.1 MI", "below a tenth")
		expect(MapRoute.FormatDistance(5760 * 0.8, 5760), "0.8 MI", "0.8")
		expect(MapRoute.FormatDistance(-5, nil), "<0.1 MI", "negative, default studs per mile")
	end)

	case("Clip keeps every visible segment when they fit", function()
		local us, vs = line(11, 0.1)
		local out = {}
		local n = MapRoute.Clip(us, vs, 11, 1, -1, 2, 0, 1, 64, out)
		expect(n, 10, "ten segments")
		expect(out[1], 1, "first from")
		expect(out[2], 2, "first to")
		expect(out[20], 11, "last to")
	end)

	case("Clip drops segments outside the box and those behind the progress segment", function()
		local us, vs = line(11, 0.1)
		local out = {}
		expect(MapRoute.Clip(us, vs, 11, 1, 0.35, 0.55, 0, 1, 64, out), 3, "segments 4, 5 and 6 overlap 0.35..0.55")
		expect(out[1], 4, "starts at point 4")
		expect(MapRoute.Clip(us, vs, 11, 6, -1, 2, 0, 1, 64, out), 5, "from segment 6 on")
		expect(out[1], 6, "first is the progress segment")
		expect(MapRoute.Clip(us, vs, 11, 1, -1, 2, 0.6, 0.9, 64, out), 0, "the box misses the line")
		expect(MapRoute.Clip(us, vs, 1, 1, -1, 2, 0, 1, 64, out), 0, "one point is no route")
	end)

	case("Clip never returns more than the pool: a long route is thinned, still end to end", function()
		local us, vs = line(1001, 0.001)
		local out = {}
		local n = MapRoute.Clip(us, vs, 1001, 1, -1, 2, 0, 1, MapRoute.MaxSegments, out)
		expect(n <= 64, true, "at most 64, got " .. tostring(n))
		expect(n >= 32, true, "thinned by halving only, got " .. tostring(n))
		expect(out[1], 1, "starts at the first point")
		expect(out[n * 2], 1001, "ends at the last point")
		for index = 1, n - 1 do
			expect(out[index * 2], out[index * 2 + 1], "contiguous at " .. tostring(index))
		end
		expect(MapRoute.MaxSegments, 64, "pool size")
	end)

	case("the layer holds 64 pooled segments; an unchanged Step writes nothing; a small pan re-clips nothing", function()
		local canvasParent, overlay = env.Detached("Frame"), env.Detached("Frame")
		local ctx = Metrics.Fixed({ Size = Vector2.new(1920, 1080) })
		Metrics.Bind(canvasParent, ctx)
		Metrics.Bind(overlay, ctx)
		local canvas = MapCanvas.New(canvasParent, {}, scope)
		local route = MapRoute.New(canvas.Canvas, overlay, { Width = 6 }, scope)
		local holder = canvas.Canvas:FindFirstChild("RouteLine")
		expect(holder ~= nil and #holder:GetChildren(), 64, "64 segments")
		local points = {}
		for index = 1, 200 do
			points[index] = Vector2.new(100 + index * 20, -250 + index * 7)
		end
		local routeState = { Points = points, Version = 1, Segment = 1, Point = points[1], Remaining = 4000, Active = { Label = "WAYPOINT", Kind = "FreeRoam" } }
		local view = mapView(MapCanvas, 1920, 1080, 5000, 0, false, true)
		route.Step(view, routeState)
		expect(holder.Visible, true, "shown with a route")
		local before, beforeOverlay = snapshot(holder), snapshot(overlay)
		route.Step(view, routeState)
		expect(snapshot(holder), before, "second step")
		expect(snapshot(overlay), beforeOverlay, "second step, chip")
		view.CentreX += 40
		route.Step(view, routeState)
		expect(snapshot(holder), before, "a small pan writes no segment")
		expect(#holder:GetChildren(), 64, "still 64 after a pan")
		route.Step(view, { Points = nil, Version = 1, Active = nil })
		expect(holder.Visible, false, "hidden with no route")
		route.Step(view, routeState)
		route.SetVisible(false)
		expect(holder.Visible, false, "hidden by SetVisible")
		route.Destroy()
		route.Destroy()
		expect(canvas.Canvas:FindFirstChild("RouteLine"), nil, "destroyed")
	end)

	restore()
	return results
end
