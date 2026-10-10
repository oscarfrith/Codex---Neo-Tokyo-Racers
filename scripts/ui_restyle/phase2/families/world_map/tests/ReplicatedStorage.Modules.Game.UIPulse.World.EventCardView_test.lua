-- Owns the pure tests for World.EventCardView; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.World.EventCardView_test. Requires: none (modules come from env.Load; UI.MapMath from classic/sources).
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

return function(View, env)
	local results, case, expect = harness()
	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local Layers = env.Load(UIP .. "Kit.Layers")
	local Tokens = env.Load(UIP .. "Kit.Tokens")
	local Data = env.Load(UIP .. "Kit.Data")

	case("Rows: your car and best need a vehicle, the best a time trial, the prize a formatted text", function()
		local rows = View.Rows({ Mode = "TimeTrial", Tier = "S", Rating = 939.4 }, 63.275, "$10,000", false)
		expect(#rows, 3, "three rows")
		expect(rows[1].Id .. rows[1].Value, "YouS 939", "you")
		expect(rows[2].Id .. rows[2].Value, "Best01:03.275", "best")
		expect(rows[3].Kind, "Prize", "prize kind")
		expect(#View.Rows({ Mode = "Race", Tier = "S", Rating = 939 }, nil, "$10,000", false), 2, "a race has no best row")
		expect(#View.Rows({ Mode = "TimeTrial", Tier = "" }, nil, nil, false), 0, "on foot, no prize yet")
		local compact = View.Rows({ Mode = "TimeTrial", Tier = "S", Rating = 939 }, 0, "$10,000", true)
		expect(#compact, 2, "Compact drops the car row")
		expect(compact[1].Value, "--:--.---", "no best yet")
	end)

	case("Height and SlotFor", function()
		expect(View.Height(3, false) - View.Height(2, false), Tokens.Space.FactRowHeight, "Regular row")
		expect(View.Height(3, true) - View.Height(2, true), Tokens.Space.CompactActionTile, "Compact row")
		expect(View.SlotFor({ ChatKeepOut = Vector2.new(483, 286) }), "RightColumn", "chat showing")
		expect(View.SlotFor({ ChatKeepOut = Vector2.zero }), "TopLeftHud", "chat hidden")
		expect(View.SlotFor({}), "TopLeftHud", "no chat field")
		expect(View.SlotFor({ Class = "Compact", Arrangement = "TouchDrive", ChatKeepOut = Vector2.new(300, 200) }), "TopLeftHud", "a touch phone never takes the minimap's column")
		expect(View.SlotFor({ Class = "Compact", Arrangement = "Standard", ChatKeepOut = Vector2.new(300, 200) }), "RightColumn", "a small window keeps the chat rule")
	end)

	case("Compact sizes: the measured height, the widths and the room check", function()
		expect(View.CompactHeight(32, 42, 12, 1), 98, "844x390: two lines, two rows")
		expect(View.CompactHeight(27, 36, 10, 0.85), (20 + 27 + 36) / 0.85, "568x320")
		expect(View.CompactHeight(32, 0, 12, 0), 56, "a zero scale is ignored")
		local width, titleWidth, lineWidth = View.CompactWidths()
		expect(width, Tokens.Space.CompactSidePanelWidth, "panel width")
		expect(lineWidth, width - Tokens.Space.CompactMargin * 2, "format line")
		expect(titleWidth, lineWidth - Tokens.Space.CompactStatusHeight, "title clear of the chequer")
		expect(View.Fits(64, 98, 270), true, "under the Roblox buttons")
		expect(View.Fits(242, 98, 270), false, "under an open chat window there is no room")
		expect(View.TopOffset(nil, 64, 10), 0, "nothing else in the corner")
		expect(View.TopOffset(40, 64, 10), 0, "something above the slot is not in the way")
		expect(View.TopOffset(103.5, 64, 10), 50, "under the objective card, a gap below it")
	end)

	local presets = {
		R1080 = Metrics.Fixed({ Size = Vector2.new(1920, 1080) }),
		C844 = Metrics.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch" }),
	}
	for name, ctx in presets do
		case(name .. ": hidden at mount, shows, fills in, ignores a stale reply, hides, destroys", function()
			local savedFoundation = Data._foundation
			Data._foundation = function()
				local function money(value)
					return "$" .. tostring(value)
				end
				return { FormatCompactMoney = money, FormatFullMoney = money, FormatFreeRoamMoney = money }
			end
			local ok, message = pcall(function()
				local scope = env.Scope()
				local parent = env.Detached("Frame")
				Metrics.Bind(parent, ctx)
				local layer = Layers.Stage(parent, ctx, "Hud")
				local card = View.Mount(layer, {}, scope)
				expect(card.IsShown(), false, "hidden at mount")
				expect(card.Instance.Visible, false, "root hidden")
				expect(#parent:GetDescendants() <= 120, true, "instance count " .. tostring(#parent:GetDescendants()))
				card.Show({ EventId = "showroom_tt", Mode = "TimeTrial", RouteId = "ShowroomLoop", Tier = "S", Rating = 939 })
				expect(card.IsShown(), true, "shown")
				expect(card.Instance.Visible, true, "root visible")
				card.Update("another|TimeTrial", { Summary = { DisplayName = "Wrong" }, Best = {} })
				local before = snapshot(parent)
				card.Render(nil)
				expect(snapshot(parent), before, "unchanged state, unchanged tree")
				card.Update("showroom_tt|TimeTrial", { Summary = { DisplayName = "Showroom Loop", DefaultLapCount = 3, CheckpointCount = 17, BaseReward = 10000 }, Best = { S = 63.275 } })
				expect(snapshot(parent) ~= before, true, "the reply fills the card in")
				local filled = snapshot(parent)
				card.Update("showroom_tt|TimeTrial", { Summary = { DisplayName = "Showroom Loop", DefaultLapCount = 3, CheckpointCount = 17, BaseReward = 10000 }, Best = { S = 63.275 } })
				expect(snapshot(parent), filled, "the same reply again writes nothing")
				card.Hide()
				card.Hide()
				expect(card.Instance.Visible, false, "hidden")
				card.Destroy()
				card.Destroy()
				scope:destroy()
			end)
			Data._foundation = savedFoundation
			if not ok then
				error(message, 0)
			end
		end)
	end

	return results
end
