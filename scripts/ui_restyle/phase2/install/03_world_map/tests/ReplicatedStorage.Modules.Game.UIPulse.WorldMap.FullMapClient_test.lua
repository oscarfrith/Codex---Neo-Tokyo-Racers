-- Owns the pure tests for WorldMap.FullMapClient; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.WorldMap.FullMapClient_test. Requires: none (modules come from env.Load; UI.MapMath from classic/sources).
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

return function(Client, _env)
	local results, case, expect = harness()

	case("the public API is safe before start", function()
		expect(Client.Open(), false, "Open")
		expect(Client.Toggle(), false, "Toggle")
		expect(Client.IsOpen(), false, "IsOpen")
		Client.Close()
		expect(type(Client.start), "function", "start")
	end)

	case("_moveVector reads WASD and the arrows", function()
		local function down(...)
			local set = {}
			for _, code in { ... } do
				set[code] = true
			end
			return function(code)
				return set[code] == true
			end
		end
		local x, y = Client._moveVector(down())
		expect(x, 0, "idle x")
		expect(y, 0, "idle y")
		x, y = Client._moveVector(down(Enum.KeyCode.A, Enum.KeyCode.W))
		expect(x, -1, "A")
		expect(y, -1, "W")
		x, y = Client._moveVector(down(Enum.KeyCode.Right, Enum.KeyCode.Down))
		expect(x, 1, "Right")
		expect(y, 1, "Down")
		x, y = Client._moveVector(down(Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.S))
		expect(x, 0, "opposites cancel")
		expect(y, 0, "opposites cancel")
	end)

	case("_isGamepad", function()
		expect(Client._isGamepad("Gamepad1"), true, "Gamepad1")
		expect(Client._isGamepad("Keyboard"), false, "Keyboard")
		expect(Client._isGamepad(nil), false, "nil")
	end)

	case("_keyCommand keeps the Classic keys", function()
		local expected = {
			[Enum.KeyCode.E] = "ZoomIn", [Enum.KeyCode.Equals] = "ZoomIn", [Enum.KeyCode.KeypadPlus] = "ZoomIn",
			[Enum.KeyCode.Q] = "ZoomOut", [Enum.KeyCode.Minus] = "ZoomOut", [Enum.KeyCode.KeypadMinus] = "ZoomOut",
			[Enum.KeyCode.C] = "Centre", [Enum.KeyCode.F] = "ShowAll", [Enum.KeyCode.Backspace] = "Clear", [Enum.KeyCode.Delete] = "Clear",
		}
		for code, command in expected do
			expect(Client._keyCommand(code), command, code.Name)
		end
		expect(Client._keyCommand(Enum.KeyCode.M), nil, "M is the toggle, not a command")
		expect(Client._keyCommand(Enum.KeyCode.Z), nil, "unbound key")
	end)

	case("_padCommand keeps the Classic buttons", function()
		local expected = {
			[Enum.KeyCode.ButtonA] = "Tap", [Enum.KeyCode.ButtonB] = "Close", [Enum.KeyCode.ButtonX] = "Clear",
			[Enum.KeyCode.ButtonY] = "Centre", [Enum.KeyCode.ButtonL1] = "ZoomOut", [Enum.KeyCode.ButtonR1] = "ZoomIn",
		}
		for code, command in expected do
			expect(Client._padCommand(code), command, code.Name)
		end
		expect(Client._padCommand(Enum.KeyCode.ButtonSelect), nil, "Select is the toggle action")
	end)

	case("_inTopBar: a press on the Roblox top-left buttons is not the map's", function()
		expect(Client._inTopBar(Vector2.new(60, 20), 58, 208), true, "on the Roblox buttons")
		expect(Client._inTopBar(Vector2.new(300, 20), 58, 208), false, "right of the buttons")
		expect(Client._inTopBar(Vector2.new(60, 58), 58, 208), false, "under the bar")
		expect(Client._inTopBar(Vector2.new(60, 20), 0, 0), false, "no bar, no keep-out")
	end)

	return results
end
