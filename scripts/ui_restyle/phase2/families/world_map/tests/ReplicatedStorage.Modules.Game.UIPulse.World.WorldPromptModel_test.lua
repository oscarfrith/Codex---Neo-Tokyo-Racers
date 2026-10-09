-- Owns the pure tests for World.WorldPromptModel; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.World.WorldPromptModel_test. Requires: none (modules come from env.Load; UI.MapMath from classic/sources).
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

local function fakePresence(open)
	return { Any = function(kind)
		return open[kind] == true
	end }
end

return function(Model, _env)
	local results, case, expect = harness()

	case("Classify knows every prompt family and nothing else", function()
		local expected = {
			RaceEntryPrompt = "RaceEntry", EnterVehiclePrompt = "EnterVehicle", DriveOutPrompt = "DriveOut", FootExitPrompt = "FootExit",
			ManageGaragePrompt = "ManageGarage", OwnedGarageDriveInEntryPrompt = "GarageDriveIn", OwnedGarageFootEntryPrompt = "GarageFootEntry",
			CanonicalDealership = "Entrance", CanonicalCustomisation = "Entrance", CanonicalDriveIn = "Entrance",
			PassengerRidePrompt = "PassengerRide", JobPrompt = "Job",
		}
		local count = 0
		for name, family in expected do
			count += 1
			expect(Model.Classify(name), family, name)
		end
		expect(count, 12, "twelve names in ten families")
		expect(Model.Classify("ProximityPrompt"), nil, "an unknown prompt is left alone")
		expect(Model.Classify("TimeTrialStartPrompt"), nil, "the retired legacy prompt")
		expect(Model.Classify(nil), nil, "nil")
	end)

	case("Visible hides what the default UI shows wrongly", function()
		local me = { LocalUserId = 7, OwnerUserId = 7, Visitor = false, Blocked = false }
		expect(Model.Visible("EnterVehicle", me), true, "my car")
		expect(Model.Visible("EnterVehicle", { LocalUserId = 7, OwnerUserId = 8 }), false, "someone else's car")
		expect(Model.Visible("EnterVehicle", { LocalUserId = 7 }), false, "no owner")
		expect(Model.Visible("DriveOut", { Visitor = true }), false, "visitor: Drive Out")
		expect(Model.Visible("ManageGarage", { Visitor = true }), false, "visitor: Manage Garage")
		expect(Model.Visible("FootExit", { Visitor = true }), true, "a visitor may leave")
		expect(Model.Visible("DriveOut", { Visitor = false }), true, "owner: Drive Out")
		for _, family in { "RaceEntry", "EnterVehicle", "DriveOut", "FootExit", "ManageGarage", "GarageDriveIn", "GarageFootEntry", "Entrance", "PassengerRide", "Job" } do
			expect(Model.Visible(family, { Blocked = true, LocalUserId = 7, OwnerUserId = 7 }), false, family .. " while a major surface is open")
		end
	end)

	case("PresenceBlocked: every kind but Race", function()
		expect(Model.PresenceBlocked(fakePresence({})), false, "nothing open")
		expect(Model.PresenceBlocked(fakePresence({ Race = true })), false, "a race does not hide prompts")
		for _, kind in { "FullMenu", "Garage", "Results", "Map", "Modal", "SidePanel", "Loading" } do
			expect(Model.PresenceBlocked(fakePresence({ [kind] = true })), true, kind)
		end
		expect(Model.PresenceBlocked(nil), false, "no presence module")
	end)

	case("BannerProps: live texts upper-cased, keys passed through, Main only for the race start", function()
		local props = Model.BannerProps("RaceEntry", { ActionText = "Start Time Trial", ObjectText = "Time Trial", KeyboardKeyCode = Enum.KeyCode.E, GamepadKeyCode = Enum.KeyCode.ButtonX, HoldDuration = 0 })
		expect(props.Action, "START TIME TRIAL", "action")
		expect(props.Object, "TIME TRIAL", "object")
		expect(props.Key, Enum.KeyCode.E, "key")
		expect(props.PadKey, Enum.KeyCode.ButtonX, "pad key")
		expect(props.Main, true, "main")
		expect(props.Hold, false, "no hold")
		local ride = Model.BannerProps("PassengerRide", { ActionText = "RIDE", ObjectText = "", KeyboardKeyCode = Enum.KeyCode.F, GamepadKeyCode = Enum.KeyCode.ButtonY, HoldDuration = 0.5 })
		expect(ride.Main, false, "not main")
		expect(ride.Object, nil, "empty object text is no object")
		expect(ride.Key, Enum.KeyCode.F, "F")
		expect(ride.PadKey, Enum.KeyCode.ButtonY, "Y")
		expect(ride.Hold, true, "hold")
	end)

	case("Next: the banner state machine", function()
		local rows = {
			-- state, event, visible, next state, effect
			{ nil, "Track", nil, "Custom", "Custom" },
			{ nil, "TrackShowing", nil, "Pending", nil },
			{ nil, "Shown", true, nil, nil },
			{ "Custom", "Shown", true, "Shown", "Show" },
			{ "Custom", "Shown", false, "Suppressed", nil },
			{ "Shown", "Shown", true, "Shown", nil },
			{ "Shown", "Hidden", nil, "Custom", "Hide" },
			{ "Suppressed", "Hidden", nil, "Custom", nil },
			{ "Custom", "Hidden", nil, "Custom", nil },
			{ "Pending", "Shown", true, "Shown", "Show" },
			{ "Pending", "Shown", false, "Suppressed", nil },
			{ "Pending", "Hidden", nil, "Custom", "Custom" },
			{ "Custom", "ShownDefault", nil, "Pending", nil },
			{ "Shown", "ShownDefault", nil, "Pending", "Hide" },
			{ "Shown", "Refresh", false, "Suppressed", "Hide" },
			{ "Shown", "Refresh", true, "Shown", nil },
			{ "Suppressed", "Refresh", true, "Shown", "Show" },
			{ "Suppressed", "Refresh", false, "Suppressed", nil },
			{ "Custom", "Refresh", true, "Custom", nil },
			{ "Shown", "Fail", nil, "Failed", "Default" },
			{ "Custom", "Fail", nil, "Failed", "Default" },
			{ "Failed", "Shown", true, "Failed", nil },
			{ "Failed", "Hidden", nil, "Failed", nil },
			{ "Failed", "Track", nil, "Failed", nil },
			{ "Failed", "Fail", nil, "Failed", nil },
		}
		for index, row in rows do
			local nextState, effect = Model.Next(row[1], row[2], row[3])
			local label = "row " .. tostring(index) .. " (" .. tostring(row[1]) .. " + " .. row[2] .. ")"
			expect(nextState, row[4], label .. " state")
			expect(effect, row[5], label .. " effect")
		end
	end)

	case("Apply and Refresh: a visitor's desk banner, presence hiding and restoring, the fail-safe", function()
		local open = {}
		local visitor = false
		local model = Model.new({
			Presence = fakePresence(open),
			LocalUserId = 7,
			Facts = function(prompt)
				return { Visitor = visitor, OwnerUserId = prompt.Owner }
			end,
		})
		local desk = { Name = "ManageGaragePrompt" }
		local car = { Name = "EnterVehiclePrompt", Owner = 8 }
		local unknown = { Name = "Whatever" }
		expect((model:Apply(unknown, "Track")), nil, "an unknown prompt is never tracked")
		expect(model:Record(unknown), nil, "no record")
		expect((model:Apply(desk, "Track")), "Custom", "track sets Custom")
		expect((model:Apply(car, "Track")), "Custom", "track sets Custom")
		expect((model:Apply(car, "Shown")), nil, "someone else's car: no banner")
		expect((model:Apply(desk, "Shown")), "Show", "owner sees the desk banner")
		expect(model:Record(desk).Id ~= model:Record(car).Id, true, "distinct banner ids")

		open.Map = true
		local changes = model:Refresh()
		expect(#changes, 1, "one banner flips")
		expect(changes[1].Prompt, desk, "the desk")
		expect(changes[1].Effect, "Hide", "hidden while the map is open")
		expect(#model:Refresh(), 0, "a second refresh changes nothing")
		open.Map = nil
		expect(model:Refresh()[1].Effect, "Show", "shown again")
		visitor = true
		expect(model:Refresh()[1].Effect, "Hide", "hidden for a visitor")

		expect((model:Apply(desk, "Fail")), "Default", "fail puts Default back")
		expect((model:Apply(desk, "Shown")), nil, "and the prompt is left alone")
		expect(model:Record(desk).State, "Failed", "for good")
		model:Forget(car)
		expect(model:Record(car), nil, "forgotten on removal")
	end)

	case("regression: a race start prompt on foot gets its banner, and its record outlives a collection", function()
		local model = Model.new({ Presence = fakePresence({}), LocalUserId = 7, Facts = function() return { Visitor = false } end })
		expect(getmetatable(model.Records), nil, "records are held strongly (no weak keys)")
		local race = { Name = "RaceEntryPrompt", ActionText = "Join Race" }
		expect((model:Apply(race, "Track")), "Custom", "track sets Custom")
		expect((model:Apply(race, "Shown")), "Show", "on foot, no vehicle facts: the banner shows")
		expect((model:Apply(race, "Hidden")), "Hide", "and hides")
		-- First seen while the engine shows it, Style already Custom (a lost record): still a banner, never nothing.
		local late = { Name = "RaceEntryPrompt", ActionText = "Join Race" }
		expect((model:Apply(late, "TrackShowing")), nil, "tracked as Pending")
		expect((model:Apply(late, "Shown")), "Show", "a Custom prompt that shows gets its banner from Pending")
		expect(model:Record(late).State, "Shown", "state Shown")
		local visitorModel = Model.new({ Presence = fakePresence({}), LocalUserId = 7, Facts = function() return { Visitor = true } end })
		expect((visitorModel:Apply(race, "Track")), "Custom", "a visitor still tracks it")
		expect((visitorModel:Apply(race, "Shown")), "Show", "the race start banner is not a visitor-hidden family")
	end)

	case("TimeText and CardText", function()
		expect(Model.TimeText(63.275), "01:03.275", "padded minutes")
		expect(Model.TimeText(0), "--:--.---", "no time")
		expect(Model.TimeText(nil), "--:--.---", "nil")
		local text = Model.CardText({ EventId = "e", Mode = "TimeTrial", RouteId = "ShowroomLoop" }, { DisplayName = "Showroom Loop", DefaultLapCount = 3, CheckpointCount = 17, BaseReward = 10000 })
		expect(text.Title, "SHOWROOM LOOP", "title")
		expect(text.Sub, "TIME TRIAL · 3 LAPS · 17 CHECKPOINTS", "format line")
		expect(text.Prize, 10000, "prize is the server's number, unchanged")
		local bare = Model.CardText({ EventId = "e", Mode = "Race", RouteId = "ShowroomLoop" }, nil)
		expect(bare.Title, "SHOWROOMLOOP", "route id until the summary arrives")
		expect(bare.Sub, "RACE", "mode only")
		expect(bare.Prize, nil, "no prize yet")
		local single = Model.CardText({ EventId = "e", Mode = "Race" }, { DisplayName = "X", DefaultLapCount = 1, CheckpointCount = 1, BaseReward = 0 })
		expect(single.Sub, "RACE · 1 LAP · 1 CHECKPOINT", "singular")
		expect(single.Prize, nil, "zero prize is no prize")
	end)

	case("FetchEvent: the two existing reads, exact action and keys, one after the other, once per show, cached", function()
		local calls = {}
		local replies = {
			GetEntryDetails = { Ok = true, Summary = { DisplayName = "Showroom Loop" } },
			GetTimeTrialPersonalBest = { Ok = true, Found = true, Record = { BestSeconds = 63.275 } },
		}
		local remote = {}
		function remote:InvokeServer(action, payload)
			local keys = {}
			for key in payload do
				table.insert(keys, key)
			end
			table.sort(keys)
			table.insert(calls, action .. "(" .. table.concat(keys, ",") .. ")")
			return replies[action]
		end
		local model = Model.new({ RaceRequest = function()
			return remote
		end, Spawn = function(callback)
			callback()
		end })
		local updates = {}
		local function onUpdate(entry)
			table.insert(updates, entry)
		end
		model:FetchEvent("showroom_tt", "TimeTrial", "S", onUpdate)
		expect(table.concat(calls, " "), "GetEntryDetails(EventId,Mode) GetTimeTrialPersonalBest(EventId,VehicleTier)", "first show")
		expect(#updates, 2, "cached state at once, then the replies")
		expect(updates[2].Summary.DisplayName, "Showroom Loop", "summary")
		expect(updates[2].Best.S, 63.275, "best from Record.BestSeconds")

		model:FetchEvent("showroom_tt", "TimeTrial", "S", onUpdate)
		expect(#calls, 3, "second show: details come from the cache")
		expect(calls[3], "GetTimeTrialPersonalBest(EventId,VehicleTier)", "the personal best is read once per show")

		model:FetchEvent("showroom_tt", "TimeTrial", "", onUpdate)
		expect(#calls, 3, "on foot: no tier, no request")
		model:FetchEvent("showroom_race", "Race", "S", onUpdate)
		expect(calls[4], "GetEntryDetails(EventId,Mode)", "a race reads details only")
		expect(#calls, 4, "no personal best for a race")

		-- Untrusted replies.
		replies.GetEntryDetails = "nope"
		replies.GetTimeTrialPersonalBest = { Ok = false }
		local seen
		model:FetchEvent("other_tt", "TimeTrial", "D", function(entry)
			seen = entry
		end)
		expect(seen.Summary, nil, "a bad reply leaves no summary")
		expect(seen.Best.D, 0, "no best")
		expect(seen.Busy, false, "not left busy")

		-- No remote: the card still renders.
		local offline = Model.new({ RaceRequest = function()
			return nil
		end, Spawn = function(callback)
			callback()
		end })
		local count = 0
		offline:FetchEvent("e", "TimeTrial", "S", function()
			count += 1
		end)
		expect(count, 2, "updates without a remote")
	end)

	return results
end
