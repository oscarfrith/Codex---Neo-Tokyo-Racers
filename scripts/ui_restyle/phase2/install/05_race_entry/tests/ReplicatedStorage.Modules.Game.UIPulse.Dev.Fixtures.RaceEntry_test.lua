-- Pure tests for Dev.Fixtures.RaceEntry: the registration shape of API1 section 10, the states API2 6.3 asks for,
-- and that every canned snapshot has the shape the real RaceEntryModel produces (so the gallery shows what the
-- game shows). Mounting is covered by the three view tests.
return function(M, env)
	local results = {}
	local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
	local Model = env.Load(UIP .. "RaceEntry.RaceEntryModel")

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(detail) or nil })
	end

	local function keysOf(value)
		local keys = {}
		for key in pairs(value) do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		return table.concat(keys, ",")
	end

	-- A real model over fakes, driven to each page, as the reference for snapshot shapes.
	local function reference()
		local silent = {}
		function silent:Fire() end
		local remote = {}
		function remote:InvokeServer(action)
			if action == "GetTimeTrialPersonalBest" then
				return { Ok = true, BestSeconds = 61, BestMedal = "Gold", BestVehicleId = "v1" }
			end
			return { Ok = true, Entries = { { Rank = 1, UserId = 1, DisplayName = "A", VehicleName = "B", BestSeconds = 60 } } }
		end
		local model = Model.new({
			Remotes = { RaceRequest = remote, GarageInvoke = remote },
			Bindables = { LegacyAction = silent },
			Catalog = {
				Fetch = function()
					return {
						Success = true,
						Profile = { Vehicles = { v1 = { CockpitId = "c1" } }, VehicleSummaries = { v1 = { Overall = { Tier = "C", PerformanceIndex = 500 } } } },
						Catalog = { Categories = { { DisplayName = "Exotic", Cockpits = { { CockpitId = "c1", DisplayName = "One" } } } } },
					}
				end,
			},
			RaceConfig = {
				GetEventSummary = function()
					return nil
				end,
				GetTimeTrialMedals = function()
					return { Platinum = 58, Gold = 62, Silver = 68, Bronze = 75 }
				end,
			},
			Money = function(amount)
				return "$" .. tostring(amount)
			end,
			UserId = 1,
			Spawn = function(body)
				body()
			end,
		})
		model.Open({ Summary = { EventId = "a_tt", DisplayName = "A", BaseReward = 100, Laps = 2 }, EventId = "a_tt" })
		local shapes = {}
		shapes.Setup = model.Snapshot()
		model.Next()
		shapes.Records = model.Snapshot()
		model.ChooseVehicle()
		shapes.Vehicles = model.Snapshot()
		model.SelectMode("Race")
		shapes.Race = model.Snapshot()
		model.ChooseVehicle()
		shapes.RaceVehicles = model.Snapshot()
		return shapes
	end

	local FRAMES = { Hud = true, Menu = true, Scene = true, Bare = true }

	case("returns three items with the gallery shape", function()
		expect(type(M) == "table" and #M == 3, "three items")
		local ids = {}
		for _, item in ipairs(M) do
			expect(type(item.Id) == "string" and item.Id ~= "" and not string.find(item.Id, "[,|]"), "Id")
			expect(not ids[item.Id], "duplicate item id " .. item.Id)
			ids[item.Id] = true
			expect(FRAMES[item.Frame] and item.Frame == "Menu", item.Id .. ": Frame is Menu")
			expect(item.Slot == nil, item.Id .. ": mounted on the stage, the view takes the slots")
			expect(type(item.Mount) == "function", item.Id .. ": Mount")
			expect(type(item.States) == "table" and #item.States >= 1, item.Id .. ": States")
			local stateIds = {}
			for _, state in ipairs(item.States) do
				expect(type(state.Id) == "string" and state.Id ~= "", item.Id .. ": state Id")
				expect(not stateIds[state.Id], item.Id .. ": duplicate state " .. state.Id)
				stateIds[state.Id] = true
				expect(type(state.Props) == "table" and type(state.Props.Snapshot) == "table", item.Id .. "/" .. state.Id .. ": Props.Snapshot")
			end
		end
		for _, id in ipairs({ "RaceEntry.Setup", "RaceEntry.Records", "RaceEntry.Vehicles" }) do
			expect(ids[id], id .. " is registered")
		end
	end)

	case("the states API2 6.3 asks for are present", function()
		local wanted = {
			Setup = { "TimeTrial", "Loading", "LockedTier", "NoVehicles", "LongestStrings", "Race", "RaceLoading", "RaceLongestStrings" },
			Records = { "Top20", "Loading", "Empty", "Error", "LockedTier", "LongestStrings" },
			Vehicles = { "TimeTrial", "Race", "Empty", "NoGarage", "LongestStrings" },
		}
		for group, list in pairs(wanted) do
			local have = {}
			for _, state in ipairs(M._snapshots[group]) do
				have[state.Id] = true
			end
			for _, id in ipairs(list) do
				expect(have[id], group .. " has state " .. id)
			end
		end
	end)

	case("canned snapshots have the real model's shape", function()
		local shapes = reference()
		local function same(label, canned, real, field)
			expect(type(canned) == "table", label .. ": canned " .. field .. " missing")
			expect(type(real) == "table", label .. ": the reference has no " .. field)
			expect(keysOf(canned) == keysOf(real), label .. " " .. field .. ": " .. keysOf(canned) .. " ~= " .. keysOf(real))
		end
		local function common(label, canned, real)
			local cannedKeys, realKeys = table.clone(canned), table.clone(real)
			for _, page in ipairs({ "Setup", "Race", "Records", "Vehicles" }) do
				cannedKeys[page], realKeys[page] = nil, nil
			end
			expect(keysOf(cannedKeys) == keysOf(realKeys), label .. " common: " .. keysOf(cannedKeys) .. " ~= " .. keysOf(realKeys))
		end
		for _, state in ipairs(M._snapshots.Setup) do
			local snap = state.Snapshot
			local label = "Setup/" .. state.Id
			if snap.Race then
				common(label, snap, shapes.Race)
				same(label, snap.Race, shapes.Race.Race, "Race")
				same(label, snap.Race.Prizes[1], shapes.Race.Race.Prizes[1], "Race.Prizes[1]")
				same(label, snap.Race.Stats[1], shapes.Race.Race.Stats[1], "Race.Stats[1]")
				expect(#snap.Race.Facts == #shapes.Race.Race.Facts, label .. ": four facts")
			else
				common(label, snap, shapes.Setup)
				same(label, snap.Setup, shapes.Setup.Setup, "Setup")
				same(label, snap.Setup.Best, shapes.Setup.Setup.Best, "Setup.Best")
				same(label, snap.Setup.Medals[1], shapes.Setup.Setup.Medals[1], "Setup.Medals[1]")
				same(label, snap.Setup.Tiers[1], shapes.Setup.Setup.Tiers[1], "Setup.Tiers[1]")
			end
		end
		for _, state in ipairs(M._snapshots.Records) do
			local snap = state.Snapshot
			local label = "Records/" .. state.Id
			common(label, snap, shapes.Records)
			same(label, snap.Records, shapes.Records.Records, "Records")
			same(label, snap.Records.Best, shapes.Records.Records.Best, "Records.Best")
			same(label, snap.Records.Board, shapes.Records.Records.Board, "Records.Board")
			if snap.Records.Board.Rows[1] then
				same(label, snap.Records.Board.Rows[1], shapes.Records.Records.Board.Rows[1], "Records.Board.Rows[1]")
			end
		end
		for _, state in ipairs(M._snapshots.Vehicles) do
			local snap = state.Snapshot
			local label = "Vehicles/" .. state.Id
			local real = snap.Mode == "Race" and shapes.RaceVehicles or shapes.Vehicles
			common(label, snap, real)
			-- Selected is nil when nothing can be chosen; compare the rest.
			local canned, wanted = table.clone(snap.Vehicles), table.clone(real.Vehicles)
			canned.Selected, wanted.Selected = nil, nil
			same(label, canned, wanted, "Vehicles")
			if snap.Vehicles.Rows[1] then
				same(label, snap.Vehicles.Rows[1], real.Vehicles.Rows[1], "Vehicles.Rows[1]")
			end
			same(label, snap.Vehicles.Facts[1], real.Vehicles.Facts[1], "Vehicles.Facts[1]")
			expect(#snap.Vehicles.Facts == #real.Vehicles.Facts, label .. ": fact count")
		end
	end)

	case("the fake model: getters, state switches and a Changed signal", function()
		local model = M._fakeModel(M._snapshots.Setup[1].Snapshot)
		local fired = {}
		local connection = model.Changed:Connect(function(reason)
			table.insert(fired, reason)
		end)
		expect(model.IsOpen() == true and model.Page() == "Setup" and model.Mode() == "TimeTrial", "getters")
		local before = model.Revision()
		expect(model.SelectTier("D") == true and model.Tier() == "D", "tier switch")
		expect(model.SetLap(7) == true and model.Lap() == 7 and model.Snapshot().Setup.LapText == "7 LAPS", "lap switch")
		expect(model.Revision() == before + 2, "one revision per switch")
		expect(table.concat(fired, ",") == "Tier,Lap", "Changed fired with the reason")
		expect(model.Exit() == false and model.Start() == false and model.Next() == false, "actions are inert")
		connection:Disconnect()
		model.SelectTier("S")
		expect(#fired == 2, "disconnected")
		expect(M._snapshots.Setup[1].Snapshot.Tier == "C", "the canned snapshot is not changed by the fake")

		local vehicles = M._fakeModel(M._snapshots.Vehicles[1].Snapshot)
		expect(vehicles.SelectedVehicle() == "v3", "canned choice")
		expect(vehicles.SelectVehicle("v1") == false, "a locked vehicle is refused")
		expect(vehicles.SelectVehicle("v5") == true and vehicles.SelectedVehicle() == "v5", "an eligible one is taken")
	end)

	return results
end
