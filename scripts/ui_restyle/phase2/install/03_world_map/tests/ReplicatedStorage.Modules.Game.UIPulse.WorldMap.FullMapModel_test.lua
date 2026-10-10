-- Owns the pure tests for WorldMap.FullMapModel; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.WorldMap.FullMapModel_test. Requires: none (modules come from env.Load; UI.MapMath from classic/sources).
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

local function attributes(initial)
	local store = table.clone(initial or {})
	local object = { Store = store, Writes = {} }
	function object:GetAttribute(name)
		return store[name]
	end
	function object:SetAttribute(name, value)
		store[name] = value
		table.insert(self.Writes, name .. "=" .. tostring(value))
	end
	return object
end

local function world(env, config)
	local MapMath = env.Load(MAPMATH)
	local log = {}
	local markers = fakeMarkers()
	local player, playerGui = attributes(), attributes()
	local delayed = {}
	local released = 0
	local deps
	deps = {
		Player = player,
		PlayerGui = playerGui,
		MapMath = MapMath,
		MapMarkers = markers,
		RouteGuide = {
			Clear = function(source)
				table.insert(log, "Clear:" .. tostring(source))
			end,
			SetDestination = function(source, position, options)
				table.insert(log, "SetDestination:" .. source .. ":" .. options.Label .. ":" .. tostring(options.Priority))
				deps.LastDestination = position
			end,
		},
		InputGate = {
			Acquire = function(owner, generation)
				table.insert(log, "Acquire:" .. owner .. ":" .. generation)
				return "token"
			end,
			Release = function(token, neutral)
				table.insert(log, "Release:" .. tostring(token) .. ":" .. tostring(neutral))
			end,
		},
		Presence = { Open = function(surface, kind)
			table.insert(log, "Presence:" .. surface .. ":" .. kind)
			return function()
				released += 1
			end
		end },
		Calibration = function()
			return MapMath.Calibration({})
		end,
		Config = function(name)
			return config and config[name]
		end,
		Subject = function()
			return deps.Root, deps.Vehicle
		end,
		PlayerCount = function()
			return deps.Players or 1
		end,
		IsCompact = function()
			return deps.Compact == true
		end,
		Delay = function(_, callback)
			table.insert(delayed, callback)
		end,
		RotationOffset = 0,
	}
	return deps, log, player, playerGui, markers, delayed, function()
		return released
	end
end

return function(Model, env)
	local results, case, expect, near = harness()

	case("construction writes FullMapOpen = false once and nothing else", function()
		local deps, log, player = world(env)
		Model.new(deps)
		expect(table.concat(player.Writes, ","), "FullMapOpen=false", "attribute writes")
		expect(#log, 0, "no shared call at construction")
	end)

	case("Open and Close: attribute, input gate, presence, signal, in the Classic order", function()
		local deps, log, player, _, _, _, released = world(env)
		local model = Model.new(deps)
		model:SetViewSize(1600, 900)
		local reasons = {}
		model.Changed:Connect(function(reason)
			table.insert(reasons, reason)
		end)
		expect(model:Open(), true, "opens")
		expect(model:Open(), true, "second open is a no-op")
		expect(player.Store.FullMapOpen, true, "attribute true")
		expect(table.concat(log, ","), "Acquire:FullMap:V1,Presence:FullMap:Map", "gate then presence")
		model:Close()
		model:Close()
		expect(player.Store.FullMapOpen, false, "attribute false")
		expect(log[3], "Release:token:true", "gate released with the neutral wait")
		expect(released(), 1, "presence released once")
		expect(table.concat(reasons, ","), "Open,Close", "signals")
		expect(table.concat(player.Writes, ","), "FullMapOpen=false,FullMapOpen=true,FullMapOpen=false", "three writes in all")
	end)

	case("every blocking attribute refuses Open and closes an open map", function()
		for _, name in Model.Blocking do
			local deps, _, player = world(env)
			local model = Model.new(deps)
			player.Store[name] = true
			expect(model:Open(), false, name .. " blocks")
			player.Store[name] = nil
			expect(model:Open(), true, name .. " cleared")
			player.Store[name] = true
			model:CloseIfBlocked()
			expect(model:IsOpen(), false, name .. " closes")
		end
		expect(#Model.Blocking, 8, "the eight Classic attributes")
	end)

	case("the other blockers: config, management desk, presentation owner, a racing vehicle", function()
		local deps, _, _, playerGui = world(env, { Enabled = false })
		expect(Model.new(deps):Open(), false, "Enabled = false")
		deps = world(env)
		local model = Model.new(deps)
		playerGui = deps.PlayerGui
		playerGui.Store.OwnedGarageManagementOpen = true
		expect(model:Open(), false, "management desk")
		playerGui.Store.OwnedGarageManagementOpen = nil
		deps.Vehicle = attributes({ RaceRunId = "run" })
		expect(model:Open(), false, "vehicle with a run id")
		deps.Vehicle = attributes({ RaceParticipant = true })
		expect(model:Open(), false, "race participant")
		deps.Vehicle = nil
		expect(model:Open(), true, "free")
		model:SetPresentation({ Owner = "RaceEntry", Active = true })
		expect(model:IsOpen(), false, "a presentation owner closes it")
		expect(model:Open(), false, "and blocks it")
		model:SetPresentation({ Owner = "RaceEntry", Active = false })
		expect(model:Open(), true, "released")
		model:SetPresentation("Racing")
		expect(model:IsOpen(), false, "the string form")
		model:SetPresentation("FreeRoam")
		expect(model:Open(), true, "the string form released")
	end)

	case("Toggle needs a showing minimap to open and nothing to close", function()
		local deps = world(env)
		local model = Model.new(deps)
		expect(model:Toggle(false), false, "no minimap, no open")
		expect(model:IsOpen(), false, "still closed")
		expect(model:Toggle(true), true, "opens")
		expect(model:Toggle(false), false, "closes whatever the minimap says")
		expect(model:IsOpen(), false, "closed")
	end)

	case("waypoint: the Classic calls, in order, and the reconcile rules", function()
		local deps, log, _, _, markers = world(env)
		local model = Model.new(deps)
		model:SetWaypoint(Vector3.new(1, 101, 2), "DEALERSHIP")
		expect(table.concat(log, ","), "Clear:Player,SetDestination:Waypoint:DEALERSHIP:5", "route calls")
		local marker = markers.Get("Waypoint")
		expect(marker.Icon, "Waypoint", "icon")
		expect(marker.Kind, "Waypoint", "kind")
		expect(marker.Priority, 50, "priority")
		expect(marker.EdgeClamp, true, "edge clamp")
		expect(marker.Label, "DEALERSHIP", "label")
		expect(model:HasWaypoint(), true, "has waypoint")
		model:ClearWaypoint()
		expect(log[3], "Clear:Waypoint", "clear call")
		expect(model:HasWaypoint(), false, "marker removed")

		model:SetWaypoint(Vector3.new(1, 101, 2))
		model:OnRouteChanged({ Source = "Player" })
		expect(model:HasWaypoint(), false, "a Player route replaces the waypoint")
		expect(log[#log], "Clear:Waypoint", "and clears its route source")
		model:SetWaypoint(Vector3.new(1, 101, 2))
		model:OnRouteChanged({ Source = "Waypoint" })
		expect(model:HasWaypoint(), true, "its own route keeps it")
		model:OnRouteChanged(nil)
		expect(model:HasWaypoint(), false, "no route, no marker")
		model:SetWaypoint(Vector3.new(1, 101, 2))
		model:OnArrived({ Source = "Player" })
		expect(model:HasWaypoint(), true, "another arrival keeps it")
		model:OnArrived({ Source = "Waypoint" })
		expect(model:HasWaypoint(), false, "arrival removes it")
	end)

	case("the tap rule: waypoint icon clears, a place routes to it, the map routes to the point", function()
		local deps, log, _, _, markers = world(env, { WaypointY = 77 })
		local model = Model.new(deps)
		model:SetViewSize(1000, 1000)
		model:Open()
		markers.Set("Poi_Dealer", { Position = Vector3.new(500, 3, -40), Icon = "Dealership", Label = "Dealer", Kind = "Place", Priority = 14 })
		markers.Set("Player_1", { Position = Vector3.new(5, 3, 5), Icon = "OtherPlayer", Label = "Someone", Kind = "Player", Priority = 1 })
		model:Tap(Vector2.new(-5, 10), nil)
		expect(model:HasWaypoint(), false, "outside the view does nothing")
		model:Tap(Vector2.new(10, 10), "Poi_Dealer")
		expect(deps.LastDestination, Vector3.new(500, 77, -40), "the place position at WaypointY")
		expect(log[#log], "SetDestination:Waypoint:DEALER:5", "upper-cased label")
		model:Tap(Vector2.new(10, 10), "Waypoint")
		expect(model:HasWaypoint(), false, "tapping the waypoint clears it")
		model:Tap(model.View.Centre, "Player_1")
		expect(log[#log], "SetDestination:Waypoint:WAYPOINT:5", "a player marker is not a destination")
		local x, z = deps.MapMath.UnitToWorld(model.Cal, model.Pan.X, model.Pan.Y)
		near(deps.LastDestination.X, x, "x under the view centre", 1e-3)
		near(deps.LastDestination.Z, z, "z under the view centre", 1e-3)
		expect(deps.LastDestination.Y, 77, "WaypointY")
	end)

	case("legend rows: YOU, other drivers, the Classic order, extras last, hidden markers skipped", function()
		local deps, _, _, _, markers = world(env)
		local model = Model.new(deps)
		markers.Set("a", { Icon = "Job", Kind = "Job", FullMap = true })
		markers.Set("b", { Icon = "Dealership", Kind = "Place", FullMap = true })
		markers.Set("c", { Icon = "Zebra", Kind = "Place", FullMap = true })
		markers.Set("d", { Icon = "Race", Kind = "Race", FullMap = false })
		markers.Set("e", { Icon = "", Kind = "Place", FullMap = true })
		local function icons()
			local list = {}
			for _, entry in model:LegendEntries() do
				table.insert(list, entry.Icon .. "=" .. entry.Label)
			end
			return table.concat(list, ",")
		end
		expect(icons(), "Player=YOU,Dealership=DEALERSHIP,Job=JOB,Zebra=ZEBRA", "one player")
		deps.Players = 2
		expect(icons(), "Player=YOU,OtherPlayer=OTHER DRIVERS,Dealership=DEALERSHIP,Job=JOB,Zebra=ZEBRA", "two players")
		expect(Model.KeyLabels.Garage, "MY GARAGE", "Classic label")
	end)

	case("the legend refresh is debounced and only fires while open", function()
		local deps, _, _, _, _, delayed = world(env)
		local model = Model.new(deps)
		local fired = 0
		model.Changed:Connect(function(reason)
			if reason == "Legend" then
				fired += 1
			end
		end)
		model:MarkLegendDirty()
		expect(#delayed, 0, "closed: nothing scheduled")
		model:Open()
		model:MarkLegendDirty()
		model:MarkLegendDirty()
		expect(#delayed, 1, "one timer for two marks")
		delayed[1]()
		expect(fired, 1, "one refresh")
		model:MarkLegendDirty()
		model:Close()
		delayed[2]()
		expect(fired, 1, "no refresh after close")
	end)

	case("zoom: steps, limits, remembered zoom, config clamps", function()
		local deps = world(env, { ZoomStep = 2, OpenVisibleStuds = 4000, MinVisibleStuds = 1000, MaxVisibleStuds = 99999999, KeyboardPanSpeed = 99 })
		local model = Model.new(deps)
		model:SetViewSize(1600, 900)
		expect(model.C.MaxVisibleStuds, 200000, "config clamped to the Classic maximum")
		expect(model.C.KeyboardPanSpeed, 10, "pan speed clamped")
		model:Open()
		near(model.VisibleStuds, 4000, "opens at OpenVisibleStuds")
		model:ZoomStep(1)
		near(model.VisibleStuds, 2000, "one step in")
		model:ZoomStep(5)
		near(model.VisibleStuds, 1000, "stops at the minimum")
		model:ShowAll()
		local _, maximum = model:StudLimits()
		near(model.VisibleStuds, maximum, "whole map is the fit limit", 1e-3)
		model:Close()
		model:Open()
		near(model.VisibleStuds, maximum, "zoom remembered", 1e-3)
	end)

	case("pointers: a short press taps, a drag pans, a pinch never taps", function()
		local deps = world(env)
		local model = Model.new(deps)
		model:SetViewSize(1000, 1000)
		model:Open()
		model:PointerBegan("Mouse", Vector2.new(100, 100))
		model:PointerMoved("Mouse", Vector2.new(103, 100))
		expect(model:PointerEnded("Mouse"), Vector2.new(100, 100), "under the drag threshold: a tap at the start point")
		local pan = model.Pan
		model:PointerBegan("Mouse", Vector2.new(500, 500))
		model:PointerMoved("Mouse", Vector2.new(400, 500))
		expect(model.Pan.X > pan.X, true, "dragging left moves the map point under the centre right")
		expect(model:PointerEnded("Mouse"), nil, "a drag is not a tap")
		model:PointerBegan("a", Vector2.new(400, 500))
		model:PointerBegan("b", Vector2.new(600, 500))
		local studs = model.VisibleStuds
		model:PointerMoved("b", Vector2.new(800, 500))
		expect(model.VisibleStuds < studs, true, "spreading two fingers zooms in")
		expect(model:PointerEnded("a"), nil, "no tap from a pinch")
		expect(model:PointerEnded("b"), nil, "nor from its second finger")
		model:PointerBegan("c", Vector2.new(10, 10))
		expect(model:PointerEnded("c"), Vector2.new(10, 10), "multi-touch is over")
		expect(model:PointerEnded("never"), nil, "unknown pointer")
	end)

	case("Step: keys pan, the stick pans, the centre target is approached; FillView reports the pan in studs", function()
		local deps = world(env)
		local model = Model.new(deps)
		model:SetViewSize(1000, 1000)
		model:Open()
		model:ZoomTo(1000)
		local pan = model.Pan
		model:Step(0.1, 1, 0)
		expect(model.Pan.X > pan.X, true, "right key moves right")
		pan = model.Pan
		model:SetStick(0, 1)
		model:Step(0.1, 0, 0)
		expect(model.Pan.Y < pan.Y, true, "stick up moves up")
		model:SetStick(0.1, 0.1)
		pan = model.Pan
		model:Step(0.1, 0, 0)
		expect(model.Pan, pan, "inside the dead zone")
		model.PanTarget = Vector2.new(0.5, 0.5)
		model:Step(10, 0, 0)
		expect(model.PanTarget, nil, "target reached")
		local view = model:FillView({})
		local x, z = deps.MapMath.UnitToWorld(model.Cal, model.Pan.X, model.Pan.Y)
		near(view.CentreX, x, "CentreX")
		near(view.CentreZ, z, "CentreZ")
		expect(view.FullMap, true, "FullMap")
		expect(view.Round, false, "Round")
		expect(view.RotationDegrees, 0, "no rotation")
		expect(view.Size, Vector2.new(1000, 1000), "Size")
		expect(view.Calibration, model.Cal, "Calibration")
	end)

	case("the legend starts closed on every Compact screen and open on Regular", function()
		local deps = world(env)
		local model = Model.new(deps)
		deps.Compact = true
		model:SetViewSize(700, 320)
		model:Open()
		expect(model:LegendOpen(), false, "narrow compact")
		model:Close()
		model:SetViewSize(844, 390)
		model:Open()
		expect(model:LegendOpen(), false, "wide compact")
		model:ToggleLegend()
		expect(model:LegendOpen(), true, "toggle opens it")
		model:Close()
		deps.Compact = false
		model:SetViewSize(1920, 1080)
		model:Open()
		expect(model:LegendOpen(), true, "regular")
	end)

	return results
end
