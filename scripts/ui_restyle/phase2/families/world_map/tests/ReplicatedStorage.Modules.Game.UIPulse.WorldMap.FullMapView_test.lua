-- Owns the pure tests for WorldMap.FullMapView; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.WorldMap.FullMapView_test. Requires: none (modules come from env.Load; UI.MapMath from classic/sources).
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

local function signal()
	local handlers = {}
	local object = {}
	function object:Connect(handler)
		table.insert(handlers, handler)
		return { Disconnect = function() end }
	end
	function object:Fire(...)
		for _, handler in handlers do
			handler(...)
		end
	end
	return object
end

local function fakeModel(state)
	local model = { Changed = signal(), View = { W = 1, H = 1, Short = 1, Centre = Vector2.new(0.5, 0.5) }, SubjectRoot = nil, State = state, Calls = {} }
	function model:IsOpen() return self.State.Open ~= false end
	function model:LegendOpen() return self.State.Legend ~= false end
	function model:District() return self.State.District or "" end
	function model:HasWaypoint() return self.State.Waypoint == true end
	function model:HintMode() return self.State.Gamepad and "Gamepad" or "Pointer" end
	function model:Heading() return nil end
	function model:SetViewSize(w, h) self.View.W, self.View.H = math.max(1, w), math.max(1, h) end
	function model:LegendEntries()
		local entries = { { Icon = "Player", Kind = "Player", Label = "YOU" } }
		for _, icon in self.State.Icons or {} do
			table.insert(entries, { Icon = icon, Kind = "Place", Label = icon })
		end
		return entries
	end
	for _, name in { "ToggleLegend", "ZoomStep", "CentreOnPlayer", "ShowAll", "Close", "ClearWaypoint" } do
		model[name] = function(self)
			table.insert(self.Calls, name)
		end
	end
	return model
end

return function(View, env)
	local results, case, expect = harness()
	local MapCanvas, _, _, _, restore = seams(env, fakeMarkers({
		Poi_A = { Position = Vector3.new(100, 0, -250), Icon = "Dealership", Kind = "Place", Priority = 14, Minimap = true, FullMap = true, EdgeClamp = false },
	}))
	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local Layers = env.Load(UIP .. "Kit.Layers")
	local Tokens = env.Load(UIP .. "Kit.Tokens")

	case("HintGroup follows the Classic rule", function()
		expect(View.HintGroup(true, "Touch"), "Gamepad", "gamepad wins")
		expect(View.HintGroup(false, "Touch"), "Touch", "touch")
		expect(View.HintGroup(false, "KeyboardAndMouse"), "Keyboard", "keyboard")
		expect(View.HintGroup(false, "Gamepad"), "Keyboard", "preferred gamepad without a pad input yet")
		expect(View.TouchHint, "DRAG TO PAN   PINCH TO ZOOM   TAP TO SET OR CLEAR A WAYPOINT", "Classic touch line")
	end)

	case("LegendHeight grows by rows and stops at the cap", function()
		local space = Tokens.Space
		expect(View.LegendHeight(2, false) - View.LegendHeight(1, false), space.StatRowHeight, "one Regular row")
		expect(View.LegendHeight(2, true) - View.LegendHeight(1, true), space.CompactActionTile, "one Compact row")
		expect(View.LegendHeight(500, false), View.LegendHeight(501, false), "Regular cap")
		expect(View.LegendHeight(500, true), View.LegendHeight(501, true), "Compact cap")
	end)

	local presets = {
		R1080 = Metrics.Fixed({ Size = Vector2.new(1920, 1080) }),
		C844 = Metrics.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch" }),
	}
	for name, ctx in presets do
		case(name .. ": mounts on a detached stage, renders twice without a write, steps, destroys clean", function()
			local scope = env.Scope()
			local parent = env.Detached("Frame")
			parent.Size = UDim2.fromOffset(ctx.Size.X, ctx.Size.Y)
			Metrics.Bind(parent, ctx)
			local layer = Layers.Stage(parent, ctx, "Menu")
			local model = fakeModel({ District = "AKANE DISTRICT", Legend = true, Waypoint = true, Icons = { "Waypoint", "Dealership", "Garage", "Race", "TimeTrial", "Job", "SomethingNew" } })
			local view = View.Mount(layer, model, scope)
			expect(#parent:GetDescendants() <= 400, true, "instance count " .. tostring(#parent:GetDescendants()))
			local before = snapshot(parent)
			view.Render(nil)
			view.Render("Legend")
			view.Render("Input")
			expect(snapshot(parent), before, "unchanged state, unchanged tree")

			-- A legend change patches rows in place.
			local count = #parent:GetDescendants()
			model.State.Icons = { "Race", "Job", "Dealership", "Garage", "Waypoint", "TimeTrial", "Duel" }
			model.State.Waypoint = false
			model.Changed:Fire("Legend")
			expect(#parent:GetDescendants(), count, "same row count: nothing created or destroyed")
			model.State.Legend = false
			model.Changed:Fire("Legend")
			model.State.Gamepad = true
			model.Changed:Fire("Input")
			expect(#parent:GetDescendants(), count, "legend closed and gamepad hints: nothing created or destroyed")

			local mapTable = mapView(MapCanvas, ctx.Size.X, ctx.Size.Y, 5000, 0, false, true)
			view.Step(mapTable, nil)
			local stepped = snapshot(parent)
			view.Step(mapTable, nil)
			expect(snapshot(parent), stepped, "an unchanged step writes nothing")
			expect(view.HitTest(Vector2.new(ctx.Size.X / 2, ctx.Size.Y / 2)), "Poi_A", "hit test goes to the icon layer")
			-- The stage root is inset on Compact, so the map view's own origin is the reference, not (0, 0).
			local origin = view.MapView.AbsolutePosition
			expect(view.ToLocal(Vector2.new(origin.X + 5, origin.Y + 6)), Vector2.new(5, 6), "ToLocal is relative to the map view")

			view.Destroy()
			view.Destroy()
			scope:destroy()
		end)
	end

	restore()
	return results
end
