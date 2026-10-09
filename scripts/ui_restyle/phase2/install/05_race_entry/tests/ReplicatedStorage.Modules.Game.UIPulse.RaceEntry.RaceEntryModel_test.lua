-- Pure tests for RaceEntry.RaceEntryModel (API2 6.4). Every service, remote, bindable and shared module is a fake
-- passed through deps; nothing yields (the fake Spawn runs at once or queues), nothing is created in the place.
return function(M, _env)
	local results = {}

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(detail) or nil })
	end

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function eq(actual, expected, label)
		if actual ~= expected then
			error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
		end
	end

	local function keysOf(value)
		local keys = {}
		for key in pairs(value) do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		return table.concat(keys, ",")
	end

	-- Classic RaceEntryPresentationClient lines 98-108, copied verbatim as the reference for the prize rule.
	local function referencePrize(raceRewards, baseReward, medal)
		local function numberAttribute(parent, name, fallback)
			local value = parent and tonumber(parent:GetAttribute(name))
			return value == nil and fallback or value
		end
		local multiplier = numberAttribute(raceRewards, medal .. "RewardMultiplier", medal == "Gold" and 1 or medal == "Silver" and 0.85 or 0.65)
		local nearest = math.max(1, numberAttribute(raceRewards, "RewardRoundToNearest", 250))
		local amount = math.floor(((tonumber(baseReward) or 0) * multiplier) / nearest + 0.5) * nearest
		return math.clamp(amount, numberAttribute(raceRewards, "MinReward", 0), numberAttribute(raceRewards, "MaxReward", 10000))
	end

	local function attributes(values)
		return {
			GetAttribute = function(_, name)
				return values[name]
			end,
		}
	end

	local LIVE_REWARDS = { GoldRewardMultiplier = 1, SilverRewardMultiplier = 0.85, BronzeRewardMultiplier = 0.65, RewardRoundToNearest = 250, MinReward = 0, MaxReward = 50000 }

	local SUMMARY = { EventId = "showroom_tt", DisplayName = "Showroom Loop", MinLapCount = 1, MaxLapCount = 5, DefaultLapCount = 3, BaseReward = 25000, CheckpointCount = 17 }
	local PAYLOAD = { Summary = SUMMARY, EventId = "showroom_tt" }

	local function profile()
		return {
			Vehicles = {
				v1 = { CockpitId = "seraph" },
				v2 = { CockpitId = "endura" },
				v3 = { CockpitId = "aurora" },
				v4 = { CockpitInstanceId = "inst4" },
				v5 = { CockpitId = "zephyr" },
				v6 = { CockpitId = "stinger" },
				v7 = { CockpitId = "zephyr" },
				v8 = { CockpitId = "aurora" },
			},
			OwnedCockpitInstances = { inst4 = { TemplateId = "kestrel" } },
			VehicleSummaries = {
				v1 = { Overall = { Tier = "S", PerformanceIndex = 939 } },
				v2 = { Overall = { Tier = "B", PerformanceIndex = 675 } },
				v3 = { Overall = { Tier = "C", PerformanceIndex = 540 } },
				v4 = { Overall = { Tier = "c", PerformanceIndex = 512 } },
				v5 = { Overall = { Tier = "C", PerformanceIndex = 498 } },
				v6 = { Overall = { Tier = "D", PerformanceIndex = 316 } },
				v7 = { Overall = { Tier = "C", PerformanceIndex = 498 } },
				v8 = { Overall = { Tier = "C", PerformanceIndex = 498 } },
			},
		}
	end

	local function catalog()
		return {
			Categories = {
				{ DisplayName = "Exotic", Cockpits = {
					{ CockpitId = "seraph", DisplayName = "Seraph", MenuImage = "111" },
					{ CockpitId = "endura", Name = "Endura", Image = "rbxassetid://222" },
					{ Id = "aurora", DisplayName = "Aurora" },
					{ CockpitId = "zephyr", DisplayName = "Zephyr" },
					{ CockpitId = "stinger", DisplayName = "Stinger" },
				} },
				{ Name = "Piercer", Cockpits = {
					{ CockpitId = "kestrel", DisplayName = "Kestrel" },
				} },
			},
		}
	end

	local BEST_SECONDS = { S = 50, C = 63.275, D = 70 }

	-- One fake world: remotes, bindables, shared modules, a Spawn that queues (or runs at once) and an event log.
	local function world(options)
		options = options or {}
		local w = { queue = {}, log = {}, fired = {}, presentation = {}, presence = {}, events = {} }
		w.replies = {
			GetInitial = function()
				return { Success = true, Profile = profile(), Catalog = catalog() }
			end,
			GetTimeTrialPersonalBest = function(payload)
				return { Ok = true, BestSeconds = BEST_SECONDS[payload.VehicleTier], BestMedal = "Gold", BestVehicleId = "v3" }
			end,
			GetTimeTrialLeaderboard = function()
				return { Ok = true, Entries = {
					{ Rank = 1, UserId = 11, DisplayName = "Neonrider", VehicleName = "Seraph", BestSeconds = 57.412 },
					{ UserId = 42, Username = "oscar", VehicleId = "v3", BestSeconds = 62 },
					"junk",
					{ UserId = 13, BestSeconds = 0 },
				} }
			end,
		}
		local function answer(action, payload)
			local reply = w.replies[action]
			if type(reply) == "function" then
				return reply(payload)
			end
			return reply
		end
		local function remote(name)
			local object = { Name = name }
			function object:InvokeServer(action, payload)
				table.insert(w.log, { Remote = name, Action = action, Payload = payload, Via = "InvokeServer" })
				return answer(action, payload)
			end
			return object
		end
		w.raceRequest = remote("RaceRequest")
		w.garageInvoke = remote("GarageInvoke")
		w.legacy = {}
		function w.legacy:Fire(...)
			local packed = table.pack(...)
			table.insert(w.fired, packed)
			table.insert(w.events, "Legacy:" .. tostring(packed[1]))
		end
		w.presentationEvent = {}
		function w.presentationEvent:Fire(payload)
			table.insert(w.presentation, payload)
			table.insert(w.events, "Presentation:" .. tostring(payload.Active))
		end
		w.deps = {
			Remotes = { RaceRequest = w.raceRequest, GarageInvoke = w.garageInvoke },
			Bindables = {
				LegacyAction = w.legacy,
				PresentationMode = function()
					return w.presentationEvent
				end,
			},
			Catalog = {
				Fetch = function(target, payload)
					table.insert(w.log, { Remote = target.Name, Action = "GetInitial", Payload = payload, Via = "Fetch" })
					return answer("GetInitial", payload)
				end,
			},
			RaceConfig = {
				GetEventSummary = function(eventId, mode)
					if options.SummaryError then
						error("no config")
					end
					if eventId == "showroom_race" and mode == "Race" then
						return { EventId = eventId, DisplayName = "Showroom Loop Race", Laps = 4, MinPlayers = 2, MaxPlayers = 6, BaseReward = 20000, CheckpointCount = 17, MapImage = "999" }
					elseif eventId == "showroom_tt" and mode == "TimeTrial" then
						return { EventId = eventId, DisplayName = "Showroom Loop", MapImage = "" }
					end
					return nil, "not found"
				end,
				GetTimeTrialMedals = function(_eventId, tier)
					if options.MedalError then
						error("no medals")
					end
					return { Platinum = 58, Gold = 62, Silver = 68, Bronze = tier == "C" and 75 or 80 }
				end,
			},
			Money = function(amount)
				return "$" .. tostring(math.floor(tonumber(amount) or 0))
			end,
			UserId = 42,
			RaceRewards = attributes(options.Rewards or LIVE_REWARDS),
			Copy = function(name)
				return name == "DailyBonusDisplay" and "3X" or nil
			end,
			Presence = {
				Open = function(surface, kind)
					table.insert(w.presence, "open:" .. surface .. ":" .. kind)
					return function()
						table.insert(w.presence, "release:" .. surface)
					end
				end,
			},
			Spawn = function(body)
				if options.Queued then
					table.insert(w.queue, body)
				else
					body()
				end
			end,
		}
		function w.run(index)
			local body = table.remove(w.queue, index or 1)
			expect(body ~= nil, "nothing queued at " .. tostring(index or 1))
			body()
		end
		function w.flush()
			while #w.queue > 0 do
				w.run(1)
			end
		end
		function w.calls(action)
			local list = {}
			for _, entry in ipairs(w.log) do
				if entry.Action == action then
					table.insert(list, entry)
				end
			end
			return list
		end
		w.model = M.new(w.deps)
		w.model.Changed:Connect(function(reason)
			table.insert(w.events, "Changed:" .. tostring(reason))
		end)
		return w
	end

	local function opened(options)
		local w = world(options)
		w.model.Open(PAYLOAD)
		w.flush()
		return w, w.model
	end

	-- Pure rules ------------------------------------------------------------------------------------------------

	case("timeText: the Classic format", function()
		eq(M._timeText(0), "--:--.---", "zero")
		eq(M._timeText(nil), "--:--.---", "nil")
		eq(M._timeText("abc"), "--:--.---", "text")
		eq(M._timeText(-3), "--:--.---", "negative")
		eq(M._timeText(58), "0:58.000", "58")
		eq(M._timeText(63.275), "1:03.275", "63.275")
		eq(M._timeText(600.5), "10:00.500", "600.5")
		eq(M._timeText("62"), "1:02.000", "numeric text")
	end)

	case("prize preview equals the Classic rule for sample inputs", function()
		local configs = {
			{ Name = "absent", Object = nil },
			{ Name = "live", Object = attributes(LIVE_REWARDS) },
			{ Name = "odd", Object = attributes({ GoldRewardMultiplier = 1.5, SilverRewardMultiplier = 0.9, RewardRoundToNearest = 0, MinReward = 500, MaxReward = 9000 }) },
			{ Name = "text", Object = attributes({ GoldRewardMultiplier = "0.5", RewardRoundToNearest = "100", MinReward = "0", MaxReward = "100000" }) },
			{ Name = "coarse", Object = attributes({ RewardRoundToNearest = 1000, MinReward = 2000, MaxReward = 30000 }) },
		}
		local bases = { 0, 1, 124, 125, 126, 374, 375, 1000, 7777, 12345, 25000, 49999, 80000, "7500", "x" }
		local count = 0
		for _, config in ipairs(configs) do
			for _, medal in ipairs({ "Gold", "Silver", "Bronze" }) do
				for _, base in ipairs(bases) do
					eq(M._roundedRacePrize(config.Object, base, medal), referencePrize(config.Object, base, medal), config.Name .. " " .. medal .. " " .. tostring(base))
					count += 1
				end
				eq(M._roundedRacePrize(config.Object, nil, medal), referencePrize(config.Object, nil, medal), config.Name .. " " .. medal .. " nil")
			end
		end
		expect(count == 225, "every sample ran")
		eq(M._roundedRacePrize(attributes(LIVE_REWARDS), 25000, "Silver"), 21250, "live silver of 25000")
		eq(M._roundedRacePrize(attributes(LIVE_REWARDS), 25000, "Bronze"), 16250, "live bronze of 25000")
		eq(M._roundedRacePrize(nil, 80000, "Gold"), 10000, "default MaxReward")
	end)

	case("prize preview in the race snapshot equals the Classic rule for every tier", function()
		for _, tier in ipairs(M.Tiers) do
			local _, model = opened()
			model.SelectTier(tier)
			model.SelectMode("Race")
			local race = model.Snapshot().Race
			expect(race ~= nil, "race page for tier " .. tier)
			local medals = { "Gold", "Silver", "Bronze" }
			local places = { "1ST", "2ND", "3RD" }
			for index, prize in ipairs(race.Prizes) do
				local expected = referencePrize(attributes(LIVE_REWARDS), 20000, medals[index])
				eq(prize.Amount, expected, tier .. " " .. places[index])
				eq(prize.Text, "$" .. tostring(expected), tier .. " text " .. places[index])
				eq(prize.Label, places[index], "label")
			end
			eq(#race.Prizes, 3, "three placements")
		end
	end)

	case("pairedEventId: payload ids first, then the suffix rule", function()
		eq(M._pairedEventId({ EventId = "a_tt" }, {}, "Race"), "a_race", "tt to race")
		eq(M._pairedEventId({ EventId = "a_race" }, {}, "TimeTrial"), "a_tt", "race to tt")
		eq(M._pairedEventId({ EventId = "a_tt" }, {}, "TimeTrial"), "a_tt", "tt stays")
		eq(M._pairedEventId({ EventId = "plain" }, {}, "Race"), "plain", "no suffix")
		eq(M._pairedEventId({ EventId = "a_tt", RaceEventId = "other" }, {}, "Race"), "other", "RaceEventId wins")
		eq(M._pairedEventId({ EventId = "a_race", TimeTrialEventId = "tt2" }, {}, "TimeTrial"), "tt2", "TimeTrialEventId wins")
		eq(M._pairedEventId({}, { EventId = "s_tt" }, "Race"), "s_race", "summary id")
		eq(M._pairedEventId({}, {}, "Race"), "", "nothing")
	end)

	case("lapBounds and lapText", function()
		local low, high = M._lapBounds({})
		eq(low, 1, "default min")
		eq(high, 10, "default max")
		low, high = M._lapBounds({ MinLapCount = 3, MaxLapCount = 2 })
		eq(low, 3, "min kept")
		eq(high, 3, "max raised to min")
		low, high = M._lapBounds({ MinLapCount = 0, MaxLapCount = 99 })
		eq(low, 1, "min floor")
		eq(high, 10, "max ceiling")
		eq(M._lapText(1), "1 LAP", "singular")
		eq(M._lapText(3), "3 LAPS", "plural")
	end)

	case("ownedTiers: upper-cased, highest owned selected, E when none", function()
		local owned, selected = M._ownedTiers(profile())
		expect(owned.S and owned.B and owned.C and owned.D, "S B C D owned")
		expect(not owned.E and not owned.A, "E and A not owned")
		eq(selected, "S", "highest")
		owned, selected = M._ownedTiers({})
		eq(selected, "E", "none")
		expect(next(owned) == nil, "empty set")
		owned, selected = M._ownedTiers({ VehicleSummaries = { a = "junk", b = { Overall = { Tier = "d" } }, c = {} } })
		eq(selected, "D", "junk rows skipped")
		_, selected = M._ownedTiers("not a table")
		eq(selected, "E", "bad profile")
	end)

	case("indexCatalog: name and image from the first match, category from the last", function()
		local index = M._indexCatalog({ Categories = {
			{ DisplayName = "First", Cockpits = { { CockpitId = "x", DisplayName = "One", MenuImage = "5" }, { CockpitId = "x", DisplayName = "Two" } } },
			{ Name = "Second", Cockpits = { { CockpitId = "x", DisplayName = "Three", Image = "7" }, "junk" } },
			"junk",
		} })
		eq(index.x.Name, "One", "name")
		eq(index.x.Image, "5", "image")
		eq(index.x.Category, "SECOND", "category")
		expect(next(M._indexCatalog(nil)) == nil, "nil catalogue")
	end)

	case("image ids are normalised as RacingUIComponents.Asset does", function()
		eq(M._image(nil), "", "nil")
		eq(M._image(""), "", "empty")
		eq(M._image("123"), "rbxassetid://123", "digits")
		eq(M._image(123), "rbxassetid://123", "number")
		eq(M._image("rbxassetid://9"), "rbxassetid://9", "asset url")
		eq(M._image("rbxthumb://type=Asset&id=1"), "rbxthumb://type=Asset&id=1", "thumb url")
		eq(M._image("other"), "other", "other text")
	end)

	-- Open and fetch ----------------------------------------------------------------------------------------------

	case("open: the page and its footer state exist before any reply; presentation and presence are published", function()
		local w = world({ Queued = true })
		local model = w.model
		local before = model.Snapshot()
		eq(before.Open, false, "closed at start")
		eq(before.Title, "RACE ENTRY", "title before any open")
		model.Open(PAYLOAD)
		eq(#w.log, 0, "no remote before the queued fetch runs")
		local snap = model.Snapshot()
		eq(snap.Open, true, "open")
		eq(snap.Page, "Setup", "page")
		eq(snap.Mode, "TimeTrial", "mode")
		eq(snap.Ready, false, "not ready")
		eq(snap.Title, "SHOWROOM LOOP", "title")
		eq(snap.Lap, 3, "default lap")
		expect(snap.Setup ~= nil and snap.Race == nil and snap.Records == nil and snap.Vehicles == nil, "exactly the Setup page")
		eq(snap.Setup.ChooseText, "LOADING", "footer text while loading")
		eq(snap.Setup.Enabled, false, "gated while loading")
		eq(snap.Setup.Best.Loading, true, "best loading")
		eq(#w.presentation, 1, "one presentation fire")
		eq(keysOf(w.presentation[1]), "Active,KeepTelemetry,Owner", "presentation keys")
		eq(w.presentation[1].Owner, "RaceEntry", "owner")
		eq(w.presentation[1].Active, true, "active")
		eq(w.presentation[1].KeepTelemetry, false, "keep telemetry")
		eq(w.presence[1], "open:RaceEntry:FullMenu", "presence")
		expect(model.SelectTier("C") == false and model.Next() == false and model.ChooseVehicle() == false, "tier, next and choose wait for the profile")

		w.run(1)
		eq(#w.log, 1, "one call")
		eq(w.log[1].Remote, "GarageInvoke", "garage remote")
		eq(w.log[1].Action, "GetInitial", "action")
		eq(w.log[1].Via, "Fetch", "through GarageCatalogClient.Fetch")
		eq(keysOf(w.log[1].Payload), "", "empty payload")
		snap = model.Snapshot()
		eq(snap.Ready, true, "ready")
		eq(snap.Tier, "S", "highest owned tier")
		eq(snap.Setup.ChooseText, "CHOOSE VEHICLE", "owned tier")
		eq(snap.Setup.Enabled, true, "enabled")
		eq(#w.queue, 1, "the personal best is asked after the profile")
		w.run(1)
		eq(w.log[2].Remote, "RaceRequest", "race remote")
		eq(w.log[2].Action, "GetTimeTrialPersonalBest", "pb action")
		eq(w.log[2].Via, "InvokeServer", "direct invoke")
		eq(keysOf(w.log[2].Payload), "EventId,VehicleTier", "pb keys")
		eq(w.log[2].Payload.EventId, "showroom_tt", "pb event")
		eq(w.log[2].Payload.VehicleTier, "S", "pb tier")
		eq(model.Snapshot().Setup.Best.TimeText, "0:50.000", "pb shown")
	end)

	case("setup snapshot: Classic texts and values", function()
		local _, model = opened()
		model.SelectTier("C")
		local setup = model.Snapshot().Setup
		eq(setup.PrizeText, "$25000", "prize is the summary BaseReward through Money")
		eq(setup.BonusText, "DAILY BONUS 3X", "daily bonus copy")
		eq(setup.LapText, "3 LAPS", "lap text")
		eq(setup.MinLap, 1, "min lap")
		eq(setup.MaxLap, 5, "max lap")
		eq(setup.MapImage, "rbxassetid://999", "race catalogue media first")
		eq(setup.Best.TimeText, "1:03.275", "best")
		eq(setup.Best.MedalText, "GOLD", "medal")
		eq(setup.BestCaption, "YOUR BEST  \u{2022}  AURORA", "caption")
		eq(#setup.Medals, 4, "four targets")
		eq(setup.Medals[1].Id, "Platinum", "order")
		eq(setup.Medals[1].Time, "0:58.000", "platinum")
		eq(setup.Medals[4].Time, "1:15.000", "tier bronze")
		eq(setup.Medals[2].Yours, true, "gold is yours")
		eq(#setup.Tiers, 6, "six tiers")
		eq(setup.Tiers[1].Tier, "E", "first tier")
		eq(setup.Tiers[1].Owned, false, "E not owned")
		eq(setup.Tiers[6].Owned, true, "S owned")
	end)

	case("the personal best is asked once per event and tier per open", function()
		local w, model = opened()
		model.SelectTier("C")
		model.SelectTier("D")
		model.SelectTier("C")
		model.SelectTier("S")
		eq(#w.calls("GetTimeTrialPersonalBest"), 3, "S, C and D once each")
		model.SelectTier("C")
		model.Next()
		eq(#w.calls("GetTimeTrialPersonalBest"), 3, "Records reuses it")
		model.Back()
		model.SelectMode("Race")
		model.SelectMode("TimeTrial")
		eq(#w.calls("GetTimeTrialPersonalBest"), 3, "mode switches reuse it")
		model.Exit()
		model.Open(PAYLOAD)
		eq(#w.calls("GetTimeTrialPersonalBest"), 4, "a new open asks again")
		eq(#w.calls("GetInitial"), 2, "GetInitial on every open")
	end)

	-- Page flow ---------------------------------------------------------------------------------------------------

	case("page flow, time trial: Setup, Records, Vehicles and back", function()
		local w, model = opened()
		model.SelectTier("C")
		eq(model.Page(), "Setup", "starts on Setup")
		expect(model.Next(), "next")
		eq(model.Page(), "Records", "Records")
		local board = w.calls("GetTimeTrialLeaderboard")
		eq(#board, 1, "leaderboard asked on entering Records")
		eq(keysOf(board[1].Payload), "EventId,Limit,VehicleTier", "leaderboard keys")
		eq(board[1].Payload.Limit, 20, "limit")
		eq(board[1].Payload.VehicleTier, "C", "tier")
		eq(board[1].Payload.EventId, "showroom_tt", "event")
		eq(board[1].Remote, "RaceRequest", "remote")
		expect(model.Snapshot().Records ~= nil and model.Snapshot().Setup == nil, "only the Records page")
		expect(model.SelectTier("D") == false, "the tier row is read-only on Records")
		expect(model.ChooseVehicle(), "choose")
		eq(model.Page(), "Vehicles", "Vehicles")
		expect(model.Snapshot().Vehicles ~= nil and model.Snapshot().Records == nil, "only the Vehicles page")
		expect(model.Back(), "back")
		eq(model.Page(), "Records", "Vehicles goes back to Records in a time trial")
		expect(model.Back(), "back again")
		eq(model.Page(), "Setup", "Records goes back to Setup")
		expect(model.Back() == false, "nothing behind Setup")
		eq(#w.calls("GetTimeTrialLeaderboard"), 1, "leaderboard asked once per tier per open")
	end)

	case("page flow, race: Setup, Vehicles and back; no ownership gate", function()
		local w, model = opened()
		expect(model.SelectMode("Race"), "race tab")
		eq(model.Page(), "Setup", "Setup")
		local snap = model.Snapshot()
		expect(snap.Race ~= nil and snap.Setup == nil, "race setup page")
		eq(snap.Race.Facts[1], "OPEN CATEGORY", "fact 1")
		eq(snap.Race.Facts[2], "CIRCUIT  \u{2022}  4 LAPS", "fact 2")
		eq(snap.Race.Facts[3], "TRACK LENGTH  \u{2022}  -- MI", "fact 3")
		eq(snap.Race.Facts[4], "2\u{2013}6 PLAYERS", "fact 4")
		eq(snap.Race.FormatText, "4 LAPS", "format")
		eq(snap.Race.Name, "SHOWROOM LOOP RACE", "name")
		eq(snap.Race.Stats[1].Text, "17", "checkpoints")
		eq(snap.Race.Stats[2].Text, "6", "max players")
		expect(model.Next() == false, "no Records page in a race")
		expect(model.ChooseVehicle(), "choose")
		eq(model.Page(), "Vehicles", "Vehicles")
		eq(model.Lap(), 4, "the lap count becomes the race's")
		expect(model.Back(), "back")
		eq(model.Page(), "Setup", "Vehicles goes back to Setup in a race")
		eq(model.Mode(), "Race", "still race")
		eq(#w.calls("GetTimeTrialLeaderboard"), 0, "no leaderboard in a race")
	end)

	case("the Setup shortcut goes to Vehicles and Back follows the Classic rule", function()
		local _, model = opened()
		model.SelectTier("C")
		expect(model.ChooseVehicle(), "shortcut")
		eq(model.Page(), "Vehicles", "Vehicles")
		model.Back()
		eq(model.Page(), "Records", "Records")
	end)

	case("the tabs work from every page and land on Setup", function()
		local _, model = opened()
		model.SelectTier("C")
		model.Next()
		expect(model.SelectMode("Race"), "race from Records")
		eq(model.Page(), "Setup", "Setup")
		model.ChooseVehicle()
		expect(model.SelectMode("TimeTrial"), "time trial from Vehicles")
		eq(model.Page(), "Setup", "Setup")
		eq(model.Mode(), "TimeTrial", "mode")
		expect(model.SelectMode("TimeTrial") == false, "same mode on Setup changes nothing")
		expect(model.SelectMode("Other") == false, "unknown mode")
	end)

	case("gates: NEXT and CHOOSE need a vehicle of the selected tier", function()
		local _, model = opened()
		expect(model.SelectTier("A"), "an unowned tier can be selected, as in Classic")
		local setup = model.Snapshot().Setup
		eq(setup.ChooseText, "OWN A A CLASS VEHICLE TO ENTER", "gate text")
		eq(setup.Enabled, false, "disabled")
		expect(model.Next() == false, "next refused")
		expect(model.ChooseVehicle() == false, "choose refused")
		eq(model.Page(), "Setup", "still Setup")
		expect(model.SelectTier("Z") == false, "unknown tier")
		expect(model.SelectTier("A") == false, "same tier")
	end)

	case("lap selector: clamped to the event's bounds, Setup only", function()
		local _, model = opened()
		eq(model.Lap(), 3, "default")
		expect(model.StepLap(1), "plus")
		eq(model.Lap(), 4, "4")
		model.SetLap(99)
		eq(model.Lap(), 5, "max")
		expect(model.StepLap(1) == false, "at max")
		model.SetLap(-4)
		eq(model.Lap(), 1, "min")
		expect(model.StepLap(-1) == false, "at min")
		eq(model.Snapshot().Setup.LapText, "1 LAP", "text")
		model.SelectTier("C")
		model.Next()
		expect(model.SetLap(3) == false, "not on Records")
	end)

	case("open resets mode, page and lap", function()
		local _, model = opened()
		model.SelectMode("Race")
		model.ChooseVehicle()
		model.Open({ Summary = { EventId = "b_tt", DisplayName = "Other", DefaultLapCount = 9, MaxLapCount = 4 }, EventId = "b_tt" })
		eq(model.Mode(), "TimeTrial", "mode")
		eq(model.Page(), "Setup", "page")
		eq(model.Lap(), 4, "lap clamped to the new event")
		eq(model.Snapshot().Title, "OTHER", "title")
		model.Open("junk")
		eq(model.Snapshot().Title, "RACE ENTRY", "a bad payload still opens")
		eq(model.Lap(), 1, "lap default")
	end)

	-- Vehicles --------------------------------------------------------------------------------------------------

	case("vehicle rows: rating order, ties, eligibility and the default selection", function()
		local _, model = opened()
		model.SelectTier("C")
		model.ChooseVehicle()
		local vehicles = model.Snapshot().Vehicles
		local order, eligible = {}, {}
		for index, row in ipairs(vehicles.Rows) do
			order[index] = row.VehicleId
			if row.Eligible then
				table.insert(eligible, row.VehicleId)
			end
		end
		eq(table.concat(order, ","), "v1,v2,v3,v4,v8,v5,v7,v6", "rating, highest first; then name; then id")
		eq(table.concat(eligible, ","), "v3,v4,v8,v5,v7", "time trial: the selected tier only")
		eq(vehicles.SelectedId, "v3", "first eligible selected")
		eq(vehicles.Selected.Name, "Aurora", "selected row")
		eq(vehicles.Count, "3/8", "count")
		eq(vehicles.Heading, "TIER C", "heading")
		eq(vehicles.Sub, "CHOOSE TIME TRIAL VEHICLE", "sub")
		eq(vehicles.StartText, "START TIME TRIAL", "start text")
		eq(vehicles.Enabled, true, "start enabled")
		eq(vehicles.EmptyText, "", "not empty")
		eq(vehicles.Context, "SHOWROOM LOOP  \u{2022}  3 LAPS", "context")
		local byId = {}
		for _, row in ipairs(vehicles.Rows) do
			byId[row.VehicleId] = row
		end
		eq(byId.v1.Image, "rbxassetid://111", "image normalised")
		eq(byId.v2.Image, "rbxassetid://222", "image kept")
		eq(byId.v3.Image, "", "no image")
		eq(byId.v4.CockpitId, "kestrel", "cockpit through the owned instance")
		eq(byId.v4.Tier, "C", "tier upper-cased")
		eq(byId.v4.Category, "PIERCER", "category")
		eq(byId.v2.Name, "Endura", "name from Name")
		eq(byId.v1.Rating, 939, "rating")

		expect(model.SelectVehicle("v1") == false, "an ineligible vehicle cannot be chosen")
		expect(model.SelectVehicle("nope") == false, "an unknown vehicle cannot be chosen")
		expect(model.SelectVehicle("v4"), "an eligible one can")
		eq(model.Snapshot().Vehicles.SelectedId, "v4", "selected")
		eq(model.Snapshot().Vehicles.Count, "4/8", "count follows")
	end)

	case("vehicle rows: a race takes every owned vehicle", function()
		local _, model = opened()
		model.SelectMode("Race")
		model.ChooseVehicle()
		local vehicles = model.Snapshot().Vehicles
		for _, row in ipairs(vehicles.Rows) do
			expect(row.Eligible, row.VehicleId .. " eligible")
		end
		eq(#vehicles.Rows, 8, "all eight")
		eq(vehicles.SelectedId, "v1", "highest rating selected")
		eq(vehicles.Heading, "OPEN CATEGORY", "heading")
		eq(vehicles.Sub, "CHOOSE RACE VEHICLE", "sub")
		eq(vehicles.StartText, "JOIN RACE", "start text")
	end)

	case("vehicle rows: nothing owned", function()
		local w = world()
		w.replies.GetInitial = function()
			return { Success = true, Profile = { Vehicles = {} } }
		end
		local model = w.model
		model.Open(PAYLOAD)
		model.SelectMode("Race")
		expect(model.ChooseVehicle(), "the race page has no gate")
		local vehicles = model.Snapshot().Vehicles
		eq(vehicles.SelectedId, "", "nothing selected")
		eq(vehicles.StartText, "SELECT A VEHICLE", "start text")
		eq(vehicles.Enabled, false, "disabled")
		eq(vehicles.EmptyText, "NO OWNED VEHICLES", "empty text")
		expect(model.Start() == false, "start refused")
		eq(#w.fired, 0, "nothing fired")
	end)

	-- Start, queue and exit ---------------------------------------------------------------------------------------

	case("StartSelectedVehicle payload, time trial (Classic line 679)", function()
		local w, model = opened()
		model.SelectTier("C")
		model.StepLap(-1)
		model.ChooseVehicle()
		model.SelectVehicle("v4")
		w.events = {}
		expect(model.Start(), "start")
		eq(#w.fired, 1, "one fire")
		local fired = w.fired[1]
		eq(fired.n, 2, "two arguments")
		eq(fired[1], "StartSelectedVehicle", "action")
		eq(keysOf(fired[2]), "CockpitId,EventId,LapCount,Mode,Tier,VehicleId", "payload keys")
		eq(fired[2].Mode, "TimeTrial", "Mode")
		eq(fired[2].EventId, "showroom_tt", "EventId")
		eq(fired[2].VehicleId, "v4", "VehicleId")
		eq(fired[2].CockpitId, "kestrel", "CockpitId")
		eq(fired[2].Tier, "C", "Tier")
		eq(fired[2].LapCount, 2, "LapCount")
		eq(table.concat(w.events, " "), "Presentation:false Changed:Close Legacy:StartSelectedVehicle", "hidden first, then the fire")
		eq(model.IsOpen(), false, "closed")
		eq(w.presence[#w.presence], "release:RaceEntry", "presence released")
		expect(model.Start() == false, "a second press does nothing")
		expect(model.Exit() == false, "exit after start does nothing")
		eq(#w.fired, 1, "still one fire")
	end)

	case("StartSelectedVehicle payload, race (the queue join request)", function()
		local w, model = opened()
		model.SelectTier("D")
		model.SelectMode("Race")
		model.ChooseVehicle()
		model.SelectVehicle("v2")
		expect(model.Start(), "start")
		local fired = w.fired[1]
		eq(fired[1], "StartSelectedVehicle", "action")
		eq(keysOf(fired[2]), "CockpitId,EventId,LapCount,Mode,Tier,VehicleId", "payload keys")
		eq(fired[2].Mode, "Race", "Mode")
		eq(fired[2].EventId, "showroom_race", "the paired race event")
		eq(fired[2].VehicleId, "v2", "VehicleId")
		eq(fired[2].CockpitId, "endura", "CockpitId")
		eq(fired[2].Tier, "D", "Tier is the time-trial tier, as Classic sends it")
		eq(fired[2].LapCount, 4, "LapCount is the race's")
		for _, entry in ipairs(w.log) do
			expect(entry.Action ~= "JoinQueue" and entry.Action ~= "StartStagedTimeTrial" and entry.Action ~= "SpawnOwnedVehicleFromFreeRoam", "this owner never calls " .. entry.Action)
		end
	end)

	case("exit: hidden first, then Close with no payload, once", function()
		local w, model = opened()
		w.events = {}
		expect(model.Exit(), "exit")
		eq(#w.fired, 1, "one fire")
		eq(w.fired[1].n, 1, "one argument")
		eq(w.fired[1][1], "Close", "action")
		eq(table.concat(w.events, " "), "Presentation:false Changed:Close Legacy:Close", "order")
		eq(w.presentation[#w.presentation].Active, false, "presentation off")
		eq(keysOf(w.presentation[#w.presentation]), "Active,KeepTelemetry,Owner", "presentation keys")
		expect(model.Exit() == false, "second exit")
		eq(#w.fired, 1, "still one")
		expect(model.SelectMode("Race") == false and model.SetLap(2) == false and model.Back() == false, "nothing works while closed")
	end)

	case("a failing Changed listener does not stop the close fire", function()
		local w, model = opened()
		model.Changed:Connect(function()
			error("listener failure (expected by this test)")
		end)
		expect(model.Exit(), "exit")
		eq(w.fired[1][1], "Close", "Close still fired")
	end)

	-- Stale replies and rapid input -------------------------------------------------------------------------------

	case("rapid input: a late reply never changes what the current page shows", function()
		local w = world({ Queued = true })
		local model = w.model
		model.Open(PAYLOAD)
		w.run(1) -- profile
		eq(#w.queue, 1, "S best queued")
		model.SelectTier("C")
		model.SelectTier("D")
		eq(#w.queue, 3, "S, C and D queued")
		w.run(2) -- the C reply arrives while D is selected
		local snap = model.Snapshot()
		eq(snap.Tier, "D", "tier D")
		eq(snap.Setup.Best.Loading, true, "D still loading; C's time is not shown")
		eq(snap.Setup.Best.TimeText, "--:--.---", "no time")
		w.run(2) -- D
		eq(model.Snapshot().Setup.Best.TimeText, "1:10.000", "D's own reply")
		model.SelectTier("C")
		eq(model.Snapshot().Setup.Best.TimeText, "1:03.275", "C's reply was kept for C")
		eq(#w.queue, 1, "no second ask for C")

		model.Exit()
		local revision = model.Revision()
		w.run(1) -- the S reply of the ended open
		eq(model.Revision(), revision, "a reply after close changes nothing")
	end)

	case("rapid input: a profile reply from an earlier open is dropped", function()
		local w = world({ Queued = true })
		local model = w.model
		model.Open(PAYLOAD)
		model.Exit()
		model.Open({ Summary = { EventId = "b_tt", DisplayName = "Second" }, EventId = "b_tt" })
		eq(#w.queue, 2, "two profile fetches queued")
		w.run(1)
		eq(model.Snapshot().Ready, false, "the first open's reply is ignored")
		eq(model.Snapshot().Title, "SECOND", "second event")
		w.run(1)
		eq(model.Snapshot().Ready, true, "the second open's reply is used")
		eq(#w.fired, 1, "one Close, no duplicate")
	end)

	case("one page per snapshot and one snapshot per revision", function()
		-- Queued, and only the profile is let through: every step below is then exactly one notification.
		local w = world({ Queued = true })
		local model = w.model
		model.Open(PAYLOAD)
		w.flush()
		model.SelectTier("C")
		local function pages(snap)
			local count = 0
			for _, key in ipairs({ "Setup", "Race", "Records", "Vehicles" }) do
				if snap[key] ~= nil then
					count += 1
				end
			end
			return count
		end
		local steps = { model.Next, model.ChooseVehicle, model.Back, model.Back, function()
			model.SelectMode("Race")
		end, model.ChooseVehicle, model.Back }
		for index, step in ipairs(steps) do
			local before = model.Revision()
			step()
			eq(model.Revision(), before + 1, "step " .. index .. " is one revision")
			local snap = model.Snapshot()
			eq(pages(snap), 1, "step " .. index .. " has one page")
			eq(snap.Revision, model.Revision(), "snapshot revision")
			expect(model.Snapshot() == snap, "the snapshot is built once per revision")
		end
		model.Exit()
		eq(pages(model.Snapshot()), 0, "no page while closed")
	end)

	-- Untrusted replies -------------------------------------------------------------------------------------------

	case("a failed GetInitial leaves a working page", function()
		local w = world()
		w.replies.GetInitial = function()
			error("server did not respond")
		end
		local model = w.model
		model.Open(PAYLOAD)
		local snap = model.Snapshot()
		eq(snap.Ready, true, "ready")
		eq(snap.Tier, "E", "tier E")
		eq(snap.Setup.ChooseText, "OWN A E CLASS VEHICLE TO ENTER", "gate")
		expect(model.Exit(), "exit works")
	end)

	case("odd reply shapes do not break a page", function()
		local w = world()
		w.replies.GetInitial = function()
			return { Profile = { Vehicles = { a = "junk", b = { CockpitId = "x" } }, VehicleSummaries = "junk" }, Catalog = "junk" }
		end
		w.replies.GetTimeTrialPersonalBest = "not a table"
		w.replies.GetTimeTrialLeaderboard = { Ok = false, Message = "down" }
		local model = w.model
		model.Open(PAYLOAD)
		local setup = model.Snapshot().Setup
		eq(setup.Best.TimeText, "--:--.---", "no best")
		eq(setup.Best.MedalText, "--", "no medal")
		eq(setup.BestCaption, "YOUR BEST  \u{2022}  NO VEHICLE RECORD", "caption")
		model.SelectMode("Race")
		model.ChooseVehicle()
		local vehicles = model.Snapshot().Vehicles
		eq(#vehicles.Rows, 1, "the junk vehicle is skipped")
		eq(vehicles.Rows[1].Tier, "--", "no summary")
		eq(vehicles.Rows[1].Name, "x", "cockpit id as the name")
	end)

	case("records: rows, your row, and the empty and unavailable states", function()
		local w, model = opened()
		model.SelectTier("C")
		model.Next()
		local records = model.Snapshot().Records
		eq(records.Board.State, "Rows", "rows")
		eq(#records.Board.Rows, 3, "the junk entry is skipped")
		eq(table.concat(records.Board.Rows[1].Columns, "|"), "1|NEONRIDER|SERAPH|0:57.412", "row 1")
		eq(table.concat(records.Board.Rows[2].Columns, "|"), "2|OSCAR|V3|1:02.000", "row 2")
		eq(table.concat(records.Board.Rows[3].Columns, "|"), "4|PLAYER 13|--|--:--.---", "row 3 keeps its index")
		eq(records.Board.Rows[2].You, true, "your row")
		eq(records.Board.Rows[1].You, false, "not yours")
		eq(records.WorldName, "NEONRIDER", "world record holder")
		eq(records.WorldTime, "0:57.412", "world record time")
		eq(table.concat(records.Columns, "|"), "POS|PLAYER|VEHICLE|TIME", "columns")
		eq(records.ChooseText, "CHOOSE VEHICLE", "choose")
		eq(records.Enabled, true, "enabled")
		eq(records.Best.TimeText, "1:03.275", "your record")
		eq(records.Best.VehicleText, "AURORA", "your vehicle")

		local empty = world()
		empty.replies.GetTimeTrialLeaderboard = { Ok = true, Entries = {} }
		empty.model.Open(PAYLOAD)
		empty.model.Next()
		local board = empty.model.Snapshot().Records.Board
		eq(board.State, "Empty", "empty")
		eq(board.Message, "NO GLOBAL RECORDS YET", "empty message")
		eq(empty.model.Snapshot().Records.WorldName, "NO RECORD SET", "no leader")

		local down = world()
		down.replies.GetTimeTrialLeaderboard = function()
			error("timeout")
		end
		down.model.Open(PAYLOAD)
		down.model.Next()
		board = down.model.Snapshot().Records.Board
		eq(board.State, "Unavailable", "unavailable")
		eq(board.Message, "GLOBAL RANKINGS UNAVAILABLE\n\nYour personal record is still shown on the left.", "unavailable message")
		expect(down.model.Back(), "the footer still works")
		expect(w ~= nil, "world kept")
	end)

	case("records: loading state before the leaderboard reply", function()
		local w = world({ Queued = true })
		local model = w.model
		model.Open(PAYLOAD)
		w.flush()
		model.Next()
		local records = model.Snapshot().Records
		eq(records.Board.State, "Loading", "loading")
		eq(#records.Board.Rows, 0, "no rows")
		eq(records.ChooseText, "CHOOSE VEHICLE", "the footer exists before the reply")
		eq(records.Enabled, true, "and is enabled")
		w.flush()
		eq(model.Snapshot().Records.Board.State, "Rows", "rows after the reply")
	end)

	case("GetTimeTrialMedals and GetEventSummary are protected", function()
		local w = world({ MedalError = true, SummaryError = true })
		local model = w.model
		model.Open(PAYLOAD)
		local setup = model.Snapshot().Setup
		eq(#setup.Medals, 4, "four rows still")
		eq(setup.Medals[1].Time, "--:--.---", "no target")
		eq(setup.MapImage, "", "no media")
		model.SelectMode("Race")
		local race = model.Snapshot().Race
		eq(race.Name, "SHOWROOM LOOP", "falls back to the payload summary")
		eq(race.FormatText, "3 LAPS", "summary laps")
	end)

	case("constructor refuses missing deps", function()
		expect(not pcall(M.new, nil), "nil deps")
		expect(not pcall(M.new, {}), "empty deps")
		expect(not pcall(M.new, { Remotes = {}, Bindables = {} }), "empty tables")
	end)

	return results
end
