-- Owns the pure tests for Map.MapCanvas; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.Map.MapCanvas_test. Requires: none (modules come from env.Load; UI.MapMath from classic/sources).
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
	local MapCanvas, _, _, MapMath, restore = seams(env, fakeMarkers())
	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local scope = env.Scope()

	case("Calibration falls back to the Classic defaults and is cached", function()
		local calibration = MapCanvas.Calibration()
		near(calibration.FullStuds, 2048 * 2850 / 207, "FullStuds")
		expect(MapCanvas.Calibration(), calibration, "cached table")
	end)

	case("Side is MapMath.CanvasSide over the shorter side", function()
		local view = mapView(MapCanvas, 1600, 900, 5000)
		near(MapCanvas.Side(view), MapMath.CanvasSide(view.Calibration.FullStuds, 900, 5000), "side")
	end)

	case("Project equals MapMath.UnitToScreen on an unrotated view", function()
		local view = mapView(MapCanvas, 1600, 900, 5000)
		local side = MapCanvas.Side(view)
		local pu, pv = MapMath.WorldToUnit(view.Calibration, view.CentreX, view.CentreZ)
		local u, v = MapMath.WorldToUnit(view.Calibration, 900, 1200)
		local expected = MapMath.UnitToScreen(Vector2.new(pu, pv), Vector2.new(u, v), Vector2.new(800, 450), side)
		local x, y = MapCanvas.Project(view, 900, 1200)
		near(x, expected.X, "x", 1e-3)
		near(y, expected.Y, "y", 1e-3)
	end)

	case("Project equals MapMath.MinimapPoint on a rotating square view", function()
		local view = mapView(MapCanvas, 300, 300, 900, 37, true)
		local expectedX, expectedY = MapMath.MinimapPoint(view.Calibration, 400 - view.CentreX, -100 - view.CentreZ, 300 / 900, 37, 300)
		local x, y = MapCanvas.Project(view, 400, -100)
		near(x, expectedX, "x", 1e-3)
		near(y, expectedY, "y", 1e-3)
	end)

	case("the view centre projects to the middle of the view", function()
		local view = mapView(MapCanvas, 1280, 720, 2500, 12)
		local x, y = MapCanvas.Project(view, view.CentreX, view.CentreZ)
		near(x, 640, "x", 1e-6)
		near(y, 360, "y", 1e-6)
	end)

	case("HalfExtents uses the diagonal for a rotated or round view", function()
		local flat = mapView(MapCanvas, 400, 200, 1000)
		local hu, hv = MapCanvas.HalfExtents(flat, 1000)
		near(hu, 0.2, "hu")
		near(hv, 0.1, "hv")
		local round = mapView(MapCanvas, 300, 300, 1000, 0, true)
		local ru, rv = MapCanvas.HalfExtents(round, 1000)
		near(ru, 0.5 * math.sqrt(180000) / 1000, "ru")
		expect(ru, rv, "square")
	end)

	case("New builds on a detached frame; an unchanged Step writes nothing; Destroy empties the parent", function()
		local content = env.Detached("Frame")
		Metrics.Bind(content, Metrics.Fixed({ Size = Vector2.new(1920, 1080) }))
		local canvas = MapCanvas.New(content, { ZIndex = 1 }, scope)
		expect(canvas.Canvas:IsA("Frame"), true, "Canvas is a Frame")
		local view = mapView(MapCanvas, 1920, 1080, 5000)
		canvas.Step(view)
		local before = snapshot(content)
		canvas.Step(view)
		expect(snapshot(content), before, "second step")
		view.CentreX += 500
		canvas.Step(view)
		expect(snapshot(content) ~= before, true, "a pan moves the canvas")
		expect(#content:GetDescendants(), 2, "rotator and canvas only (tiles belong to the shared module)")
		canvas.Destroy()
		canvas.Destroy()
		expect(#content:GetChildren(), 0, "empty after Destroy")
	end)

	case("New refuses an unknown key", function()
		expect((pcall(MapCanvas.New, env.Detached("Frame"), { Nope = 1 }, scope)), false, "unknown key")
	end)

	restore()
	return results
end
