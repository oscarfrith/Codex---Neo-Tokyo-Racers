-- Owns the gallery fixtures for the three race-entry views over a fake model with canned snapshots; it owns no screen, never touches the real model, a remote or a player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.RaceEntry. Requires: Layers, RaceEntry.SetupView, RaceEntry.RecordsView, RaceEntry.VehicleView.
local pulse = script.Parent.Parent.Parent
local Layers = require(pulse.Kit.Layers)
local SetupView = require(pulse.RaceEntry.SetupView)
local RecordsView = require(pulse.RaceEntry.RecordsView)
local VehicleView = require(pulse.RaceEntry.VehicleView)

local TIERS = { "E", "D", "C", "B", "A", "S" }
local BULLET = "  \u{2022}  "
local DOT = " \u{00B7} "
local DASH = "\u{2013}"

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end
	return copy
end

local function lapText(laps)
	return tostring(laps) .. (laps == 1 and " LAP" or " LAPS")
end

-- A stand-in with the getters of RaceEntryModel. The three switches a view can drive on its own page (tier, lap,
-- vehicle) change the canned state and fire Changed; everything else is inert (the gallery's state buttons
-- change page and mode).
local function fakeModel(snapshot)
	local state = deepCopy(snapshot)
	state.Revision = 1
	local listeners = {}
	local model = { Calls = {} }

	local changed = {}
	function changed:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect()
			connection.Connected = false
			local index = table.find(listeners, callback)
			if index then
				table.remove(listeners, index)
			end
		end
		table.insert(listeners, callback)
		return connection
	end
	model.Changed = changed

	local function fire(reason)
		state.Revision += 1
		for _, callback in ipairs(table.clone(listeners)) do
			callback(reason)
		end
	end

	local function note(name, value)
		table.insert(model.Calls, { Name = name, Value = value })
	end

	function model.Snapshot()
		return state
	end

	function model.Revision()
		return state.Revision
	end

	function model.IsOpen()
		return state.Open == true
	end

	function model.Mode()
		return state.Mode
	end

	function model.Page()
		return state.Page
	end

	function model.Tier()
		return state.Tier
	end

	function model.Lap()
		return state.Lap
	end

	function model.SelectedVehicle()
		return state.Vehicles and state.Vehicles.SelectedId or ""
	end

	function model.LapText(laps)
		return lapText(laps)
	end

	function model.SelectTier(tier)
		note("SelectTier", tier)
		local setup = state.Setup
		if not setup or tier == state.Tier then
			return false
		end
		state.Tier = tier
		setup.PrizeLabel = "TIER " .. tier .. DOT .. "PLATINUM PRIZE"
		fire("Tier")
		return true
	end

	function model.SetLap(value)
		note("SetLap", value)
		local setup = state.Setup
		if not setup then
			return false
		end
		local lap = math.clamp(math.floor(tonumber(value) or state.Lap), setup.MinLap, setup.MaxLap)
		if lap == state.Lap then
			return false
		end
		state.Lap = lap
		setup.Lap = lap
		setup.LapText = lapText(lap)
		fire("Lap")
		return true
	end

	function model.SelectVehicle(vehicleId)
		note("SelectVehicle", vehicleId)
		local vehicles = state.Vehicles
		if not vehicles or vehicleId == vehicles.SelectedId then
			return false
		end
		for index, row in ipairs(vehicles.Rows) do
			if row.VehicleId == vehicleId and row.Eligible then
				vehicles.SelectedId = vehicleId
				vehicles.Selected = row
				vehicles.Count = tostring(index) .. "/" .. tostring(#vehicles.Rows)
				vehicles.Enabled = true
				fire("Vehicle")
				return true
			end
		end
		return false
	end

	for _, name in ipairs({ "Open", "Exit", "SelectMode", "StepLap", "Next", "ChooseVehicle", "Back", "Start" }) do
		model[name] = function(value)
			note(name, value)
			return false
		end
	end

	return model
end

-- Canned data --------------------------------------------------------------------------------------------------

local function tiers(owned)
	local list = {}
	for index, tier in ipairs(TIERS) do
		list[index] = { Tier = tier, Owned = string.find(owned, tier, 1, true) ~= nil }
	end
	return list
end

local function medals(yours)
	local times = { Platinum = "0:58.000", Gold = "1:02.000", Silver = "1:08.000", Bronze = "1:15.000" }
	local rows = {}
	for index, name in ipairs({ "Platinum", "Gold", "Silver", "Bronze" }) do
		local mine = name == yours
		rows[index] = { Id = name, Label = string.upper(name) .. (mine and (DOT .. "YOURS") or ""), Time = times[name], Yours = mine }
	end
	return rows
end

local BEST = { Loading = false, Has = true, TimeText = "1:03.275", Medal = "Gold", MedalText = "GOLD", VehicleText = "STINGER" }
local BEST_NONE = { Loading = false, Has = false, TimeText = "--:--.---", Medal = "", MedalText = "--", VehicleText = "NO VEHICLE RECORD" }
local BEST_LOADING = { Loading = true, Has = false, TimeText = "--:--.---", Medal = "", MedalText = "--", VehicleText = "NO VEHICLE RECORD" }
local BEST_LONG = { Loading = false, Has = true, TimeText = "19:59.999", Medal = "Platinum", MedalText = "PLATINUM", VehicleText = "SHIFTED CANAL INTERCEPTOR GT" }

local function base(page, mode, tier, lap, title, ready)
	return { Revision = 1, Open = true, Ready = ready ~= false, Mode = mode, Page = page, Tier = tier, Lap = lap, Title = title }
end

local function setup(options)
	local tier = options.Tier or "C"
	local lap = options.Lap or 3
	local best = options.Best or BEST
	local owned = options.Owned or "DCS"
	local has = string.find(owned, tier, 1, true) ~= nil
	local ready = options.Ready ~= false
	local snap = base("Setup", "TimeTrial", tier, lap, options.Title or "SHOWROOM LOOP", ready)
	snap.Setup = {
		Tiers = tiers(owned),
		Info = lapText(lap) .. DOT .. "17 CHECKPOINTS",
		InfoShort = lapText(lap) .. DOT .. "17 CP",
		MapImage = "",
		Lap = lap,
		MinLap = 1,
		MaxLap = 10,
		LapText = lapText(lap),
		PrizeLabel = "TIER " .. tier .. DOT .. "PLATINUM PRIZE",
		PrizeText = options.Prize or "$25,000",
		BonusText = "DAILY BONUS 2X",
		Best = best,
		BestCaption = "YOUR BEST" .. BULLET .. best.VehicleText,
		Medals = medals(best.Medal),
		RecordsText = "VIEW RECORDS",
		RecordsShort = "RECORDS",
		ChooseText = (not ready) and "LOADING" or (has and "CHOOSE VEHICLE" or ("OWN A " .. tier .. " CLASS VEHICLE TO ENTER")),
		Enabled = ready and has,
	}
	return snap
end

local function race(options)
	local ready = options.Ready ~= false
	local snap = base("Setup", "Race", "C", 3, options.Title or "SHOWROOM LOOP", ready)
	local prizeTexts = options.Prizes or { "$25,000", "$21,250", "$16,250" }
	snap.Race = {
		Facts = {
			"OPEN CATEGORY",
			"CIRCUIT" .. BULLET .. (options.Laps or "3") .. " LAPS",
			"TRACK LENGTH" .. BULLET .. (options.Length or "--") .. " MI",
			"2" .. DASH .. (options.Players or "6") .. " PLAYERS",
		},
		MapImage = "",
		MapLabel = "MULTIPLAYER RACE",
		Name = options.Title or "SHOWROOM LOOP",
		FormatLabel = "RACE FORMAT",
		FormatText = (options.Laps or "3") .. " LAPS",
		PrizesLabel = "PLACEMENT PRIZES",
		Prizes = {
			{ Id = "1ST", Label = "1ST", Medal = "Gold", Amount = 25000, Text = prizeTexts[1] },
			{ Id = "2ND", Label = "2ND", Medal = "Silver", Amount = 21250, Text = prizeTexts[2] },
			{ Id = "3RD", Label = "3RD", Medal = "Bronze", Amount = 16250, Text = prizeTexts[3] },
		},
		Stats = {
			{ Id = "Checkpoints", Label = "CHECKPOINTS", Text = options.Checkpoints or "17" },
			{ Id = "Players", Label = "MAX PLAYERS", Text = options.Players or "6" },
		},
		ChooseText = ready and "CHOOSE VEHICLE" or "LOADING",
		Enabled = ready,
	}
	return snap
end

local BOARD_NAMES = { "NEONRIDER", "CYBERWAVE", "NIGHTDRIFT", "KOBAYASHI_R", "PULSEHEAD", "VANTA", "OSCAR", "LOWLIGHT", "MIRA_K", "HALCYON" }
local BOARD_CARS = { "SERAPH", "SERAPH", "ROSSO", "AURORA", "AURORA", "ENDURA", "STINGER", "AURORA", "ZEPHYR", "AURORA" }

local function boardRows(count, long)
	local rows = {}
	for index = 1, count do
		local slot = (index - 1) % #BOARD_NAMES + 1
		local name = long and "WWWWWWWWWWWWWWWWWWWW" or BOARD_NAMES[slot]
		local car = long and "SHIFTED CANAL INTERCEPTOR GT" or BOARD_CARS[slot]
		rows[index] = {
			Key = "Row" .. tostring(index),
			You = index == 7,
			Columns = { tostring(index), name, car, string.format("0:%02d.%03d", 56 + (index % 4), (index * 137) % 1000) },
		}
	end
	return rows
end

local function records(options)
	local tier = options.Tier or "C"
	local best = options.Best or BEST
	local owned = options.Owned or "DCS"
	local has = string.find(owned, tier, 1, true) ~= nil
	local board = options.Board or { State = "Rows", Message = "", Rows = boardRows(20, false) }
	local leader = board.Rows[1]
	local snap = base("Records", "TimeTrial", tier, 3, options.Title or "SHOWROOM LOOP", true)
	snap.Records = {
		PageLabel = "RECORDS",
		Tiers = tiers(owned),
		WorldLabel = "WORLD RECORD" .. DOT .. "TIER " .. tier,
		WorldName = leader and leader.Columns[2] or "NO RECORD SET",
		WorldTime = leader and leader.Columns[4] or "--:--.---",
		TargetsLabel = "MEDAL TARGETS",
		Medals = medals(best.Medal),
		YourLabel = "YOUR RECORD",
		Best = best,
		BoardLabel = "GLOBAL TOP 20",
		Columns = { "POS", "PLAYER", "VEHICLE", "TIME" },
		Board = board,
		ChooseText = has and "CHOOSE VEHICLE" or ("OWN A " .. tier .. " CLASS VEHICLE TO ENTER"),
		Enabled = has,
	}
	return snap
end

local GARAGE = {
	{ VehicleId = "v1", CockpitId = "seraph", Name = "Seraph", Image = "", Tier = "S", Rating = 939, Category = "EXOTIC" },
	{ VehicleId = "v2", CockpitId = "endura", Name = "Endura", Image = "", Tier = "B", Rating = 675, Category = "EXOTIC" },
	{ VehicleId = "v3", CockpitId = "aurora", Name = "Aurora", Image = "", Tier = "C", Rating = 540, Category = "EXOTIC" },
	{ VehicleId = "v4", CockpitId = "kestrel", Name = "Kestrel", Image = "", Tier = "C", Rating = 512, Category = "PIERCER" },
	{ VehicleId = "v5", CockpitId = "zephyr", Name = "Zephyr", Image = "", Tier = "C", Rating = 498, Category = "EXOTIC" },
	{ VehicleId = "v6", CockpitId = "stinger", Name = "Stinger", Image = "", Tier = "D", Rating = 316, Category = "EXOTIC" },
}

local function vehicles(options)
	local raceMode = options.Mode == "Race"
	local tier = options.Tier or "C"
	local rows = {}
	local selected, position, eligible = nil, 0, 0
	for index, source in ipairs(options.Rows or GARAGE) do
		local row = deepCopy(source)
		row.Eligible = raceMode or row.Tier == tier
		rows[index] = row
		if row.Eligible then
			eligible += 1
			if selected == nil and (options.Select == nil or options.Select == row.VehicleId) then
				selected, position = row, index
			end
		end
	end
	local snap = base("Vehicles", raceMode and "Race" or "TimeTrial", tier, 3, options.Title or "SHOWROOM LOOP", true)
	local facts
	if raceMode then
		facts = {
			{ Id = "Mode", Icon = "race_flag", Label = "MODE", Value = "RACE", Kind = "Text" },
			{ Id = "Laps", Icon = "laps", Label = "LAPS", Value = "3" .. DOT .. "17 CHECKPOINTS", Kind = "Text" },
			{ Id = "Players", Icon = "players", Label = "PLAYERS", Value = "2" .. DASH .. "6", Kind = "Text" },
			{ Id = "Prize", Icon = "trophy", Label = "1ST PRIZE", Value = options.Prize or "$25,000", Kind = "Prize" },
		}
	else
		facts = {
			{ Id = "Mode", Icon = "race_flag", Label = "MODE", Value = "TIME TRIAL", Kind = "Text" },
			{ Id = "Laps", Icon = "laps", Label = "LAPS", Value = "3" .. DOT .. "17 CHECKPOINTS", Kind = "Text" },
			{ Id = "Best", Icon = "timer", Label = "YOUR BEST", Value = "1:03.275", Kind = "Text" },
			{ Id = "Prize", Icon = "trophy", Label = "PLATINUM PRIZE", Value = options.Prize or "$25,000", Kind = "Prize" },
		}
	end
	snap.Vehicles = {
		Sub = raceMode and "CHOOSE RACE VEHICLE" or "CHOOSE TIME TRIAL VEHICLE",
		Heading = raceMode and "OPEN CATEGORY" or ("TIER " .. tier),
		Count = tostring(position) .. "/" .. tostring(#rows),
		Context = (options.Title or "SHOWROOM LOOP") .. BULLET .. "3 LAPS",
		LockedSub = "TIER " .. tier .. " ONLY",
		Rows = rows,
		SelectedId = selected and selected.VehicleId or "",
		Selected = selected,
		EmptyText = eligible == 0 and (raceMode and "NO OWNED VEHICLES" or ("NO OWNED " .. tier .. " CLASS VEHICLES")) or "",
		Facts = facts,
		StartText = selected and (raceMode and "JOIN RACE" or "START TIME TRIAL") or "SELECT A VEHICLE",
		Enabled = selected ~= nil,
	}
	return snap
end

local LONG_TITLE = "SHIFTED CANAL SPRINT REVERSE"
local LONG_GARAGE = {
	{ VehicleId = "v1", CockpitId = "long1", Name = "Shifted Canal Interceptor GT", Image = "", Tier = "S", Rating = 999, Category = "EXPERIMENTAL PROTOTYPE" },
	{ VehicleId = "v2", CockpitId = "long2", Name = "Shifted Canal Interceptor RS", Image = "", Tier = "C", Rating = 599, Category = "EXPERIMENTAL PROTOTYPE" },
	{ VehicleId = "v3", CockpitId = "long3", Name = "Unrated", Image = "", Tier = "--", Rating = 0, Category = "OTHER" },
}

local SNAPSHOTS = {
	Setup = {
		{ Id = "TimeTrial", Snapshot = setup({}) },
		{ Id = "Loading", Snapshot = setup({ Ready = false, Owned = "", Tier = "E", Best = BEST_LOADING }) },
		{ Id = "LockedTier", Snapshot = setup({ Tier = "A", Best = BEST_NONE }) },
		{ Id = "NoVehicles", Snapshot = setup({ Owned = "", Tier = "E", Best = BEST_NONE }) },
		{ Id = "NoRecord", Snapshot = setup({ Best = BEST_NONE }) },
		{ Id = "LongestStrings", Snapshot = setup({ Title = LONG_TITLE, Lap = 10, Prize = "$3,613,709", Best = BEST_LONG }) },
		{ Id = "Race", Snapshot = race({}) },
		{ Id = "RaceLoading", Snapshot = race({ Ready = false }) },
		{ Id = "RaceLongestStrings", Snapshot = race({ Title = LONG_TITLE, Laps = "10", Length = "12.34", Players = "12", Checkpoints = "128", Prizes = { "$50,000", "$42,500", "$32,500" } }) },
	},
	Records = {
		{ Id = "Top20", Snapshot = records({}) },
		{ Id = "Loading", Snapshot = records({ Best = BEST_LOADING, Board = { State = "Loading", Message = "LOADING", Rows = {} } }) },
		{ Id = "Empty", Snapshot = records({ Best = BEST_NONE, Board = { State = "Empty", Message = "NO GLOBAL RECORDS YET", Rows = {} } }) },
		{ Id = "Error", Snapshot = records({ Board = { State = "Unavailable", Message = "GLOBAL RANKINGS UNAVAILABLE\n\nYour personal record is still shown on the left.", Rows = {} } }) },
		{ Id = "LockedTier", Snapshot = records({ Tier = "A", Best = BEST_NONE, Board = { State = "Rows", Message = "", Rows = boardRows(3, false) } }) },
		{ Id = "LongestStrings", Snapshot = records({ Title = LONG_TITLE, Best = BEST_LONG, Board = { State = "Rows", Message = "", Rows = boardRows(20, true) } }) },
	},
	Vehicles = {
		{ Id = "TimeTrial", Snapshot = vehicles({ Select = "v3" }) },
		{ Id = "Race", Snapshot = vehicles({ Mode = "Race" }) },
		{ Id = "Empty", Snapshot = vehicles({ Tier = "A" }) },
		{ Id = "NoGarage", Snapshot = vehicles({ Mode = "Race", Rows = {} }) },
		{ Id = "LongestStrings", Snapshot = vehicles({ Title = LONG_TITLE, Rows = LONG_GARAGE, Prize = "$3,613,709" }) },
	},
}

-- Registration -----------------------------------------------------------------------------------------------

local function mounter(view)
	return function(parent, props, scope, ctx)
		local stage = Instance.new("Frame")
		stage.Name = "RaceEntryStage"
		stage.BackgroundTransparency = 1
		stage.BorderSizePixel = 0
		stage.Size = UDim2.fromScale(1, 1)
		stage.Parent = parent
		local layer = Layers.Stage(stage, ctx, "Menu")
		local model = fakeModel(props.Snapshot)
		local mounted = view.Mount(layer, model, scope)
		scope:connect(model.Changed, function(reason)
			mounted.Render(reason)
		end)
		mounted.Render("Fixture")
		local destroyed = false
		return {
			Instance = stage,
			Model = model,
			View = mounted,
			Layer = layer,
			Set = function() end,
			Destroy = function()
				if destroyed then
					return
				end
				destroyed = true
				mounted.Destroy()
				layer.Destroy()
				stage:Destroy()
			end,
		}
	end
end

local function item(id, view, states)
	local list = {}
	for index, state in ipairs(states) do
		list[index] = { Id = state.Id, Props = { Snapshot = state.Snapshot } }
	end
	return { Id = id, Frame = "Menu", Slot = nil, Mount = mounter(view), States = list }
end

local fixtures = {
	item("RaceEntry.Setup", SetupView, SNAPSHOTS.Setup),
	item("RaceEntry.Records", RecordsView, SNAPSHOTS.Records),
	item("RaceEntry.Vehicles", VehicleView, SNAPSHOTS.Vehicles),
}

-- For the pure tests (ipairs readers such as the gallery never see these).
fixtures._fakeModel = fakeModel
fixtures._snapshots = SNAPSHOTS

return fixtures
