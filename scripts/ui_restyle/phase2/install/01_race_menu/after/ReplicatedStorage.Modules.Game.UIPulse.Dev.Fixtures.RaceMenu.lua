-- Owns the gallery fixtures for the race menu view (every state, over a fake model with canned events); it does not own the gallery, the real model, any remote, bindable or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.RaceMenu. Requires: Layers, RaceMenuModel (pure row rules only), RaceMenuView.
local pulse = script.Parent.Parent.Parent
local Layers = require(pulse.Kit.Layers)
local Model = require(pulse.RaceMenu.RaceMenuModel)
local View = require(pulse.RaceMenu.RaceMenuView)

-- Example data only, in the shape RaceConfigReader.GetEventSummary returns. No image ids: the no-image state is
-- what a fixture can show without naming an asset.
local function summary(eventId, name, routeId, routeType, laps, checkpoints, minPlayers, maxPlayers, reward)
	return {
		EventId = eventId,
		DisplayName = name,
		RouteId = routeId,
		RouteDisplayName = name,
		RouteType = routeType,
		Laps = laps,
		CheckpointCount = checkpoints,
		MinPlayers = minPlayers,
		MaxPlayers = maxPlayers,
		BaseReward = reward,
		TrackImage = "",
		MapImage = "",
	}
end

local function row(key, name, timeTrial, race)
	return { Key = key, DisplayName = name, TimeTrial = timeTrial, Race = race, Primary = timeTrial or race }
end

local function showroom()
	return row(
		"ShowroomLoop",
		"Showroom Loop",
		summary("ShowroomLoopTimeTrial", "Showroom Loop", "ShowroomLoop", "Circuit", 3, 17, 1, 1, 6000),
		summary("ShowroomLoopRace", "Showroom Loop", "ShowroomLoop", "Circuit", 3, 17, 2, 6, 10000)
	)
end

local function waterfront()
	return row(
		"WaterfrontSprint",
		"Waterfront Sprint",
		summary("WaterfrontSprintTimeTrial", "Waterfront Sprint", "WaterfrontSprint", "PointToPoint", 1, 24, 1, 1, 5000),
		summary("WaterfrontSprintRace", "Waterfront Sprint", "WaterfrontSprint", "PointToPoint", 1, 24, 2, 6, 8000)
	)
end

local function twoEvents()
	return { showroom(), waterfront() }
end

local function fiveEvents()
	return {
		row("AkaneRing", "Akane Ring", nil, summary("AkaneRingRace", "Akane Ring", "AkaneRing", "Circuit", 5, 31, 2, 8, 30000)),
		row("HarbourRun", "Harbour Run", summary("HarbourRunTimeTrial", "Harbour Run", "HarbourRun", "PointToPoint", 1, 12, 1, 1, 6000), nil),
		row("ShiftedCanalSprint", "Shifted Canal Sprint", nil, summary("ShiftedCanalRace", "Shifted Canal Sprint", "ShiftedCanalSprint", "Circuit", 3, 22, 2, 8, 20000)),
		showroom(),
		waterfront(),
	}
end

local function longEvents()
	local name = "Grand Neon Expressway Endurance Championship Invitational"
	return {
		row(
			"LongRoute",
			name,
			summary("LongRouteTimeTrial", name, "LongRoute", "PointToPoint", 10, 128, 1, 1, 9999999),
			summary("LongRouteRace", name, "LongRoute", "PointToPoint", 10, 128, 2, 16, 99999999)
		),
		showroom(),
	}
end

-- A stand-in for Kit.Data.Money(amount, false): plain digits with separators, so no fixture touches the Foundation.
local function money(amount)
	local text = tostring(math.floor(amount + 0.5))
	local changed
	repeat
		text, changed = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
	until changed == 0
	return "$" .. text
end

-- The fake model: the getters and reducers the view uses, canned state, no remote, bindable or attribute.
local function fakeModel(spec)
	local handlers = {}
	local changed = {}
	function changed.Connect(_, callback)
		local connection = { Connected = true }
		function connection.Disconnect()
			connection.Connected = false
			local index = table.find(handlers, connection)
			if index then
				table.remove(handlers, index)
			end
		end
		connection.Callback = callback
		table.insert(handlers, connection)
		return connection
	end
	local function emit(reason)
		for _, connection in ipairs(table.clone(handlers)) do
			if connection.Connected then
				connection.Callback(reason)
			end
		end
	end

	local allRows = spec.Rows or {}
	local items = {}
	for _, entry in ipairs(allRows) do
		items[entry] = Model.Describe(entry, money)
	end
	local filter = spec.Filter or "All"
	local rows = Model.FilterRows(allRows, filter)
	local version = 1
	local selected = rows[spec.Select or 1]
	local page = (spec.Page == "Detail" and selected) and "Detail" or "List"
	local status = spec.Status
	local busy = spec.Busy == true
	local open = spec.Open ~= false

	local model = { Changed = changed }
	function model.IsOpen()
		return open
	end
	function model.RowsVersion()
		return version
	end
	function model.Filter()
		return filter
	end
	function model.Page()
		return page
	end
	function model.Count()
		return #rows
	end
	function model.SelectedKey()
		return selected and selected.Key or nil
	end
	function model.Items()
		local result = {}
		for index, entry in ipairs(rows) do
			result[index] = items[entry]
		end
		return result
	end
	function model.Detail()
		if not selected then
			return nil, 0, #rows
		end
		return items[selected], table.find(rows, selected) or 0, #rows
	end
	function model.Status()
		return status
	end
	function model.Busy()
		return busy
	end
	function model.CanAct()
		return selected ~= nil
	end
	function model.TeleportText()
		return busy and Model.Strings.Teleporting or Model.Strings.Teleport
	end
	function model.Select(key)
		for _, entry in ipairs(rows) do
			if entry.Key == key then
				if selected ~= entry then
					selected = entry
					emit("Selection")
				end
				return true
			end
		end
		return false
	end
	function model.SetFilter(id)
		if not table.find(Model.Filters, id) or id == filter then
			return false
		end
		filter = id
		rows = Model.FilterRows(allRows, filter)
		version += 1
		if not (selected and table.find(rows, selected)) then
			selected = rows[1]
		end
		if not selected then
			page = "List"
		end
		emit("Filter")
		return true
	end
	function model.CycleFilter(step)
		local index = table.find(Model.Filters, filter) or 1
		model.SetFilter(Model.Filters[(index - 1 + step) % #Model.Filters + 1])
	end
	function model.SetPage(id)
		if (id == "List" or (id == "Detail" and selected ~= nil)) and id ~= page then
			page = id
			emit("Page")
		end
	end
	function model.Back()
		model.SetPage("List")
	end
	-- The gallery keeps the screen up: the action buttons show their result as the status line instead.
	function model.SetOpen(_wanted) end
	function model.Toggle() end
	function model.Teleport()
		busy = not busy
		status = nil
		emit("Busy")
		return false
	end
	function model.SetRoute()
		status = Model.Strings.NoRoute
		emit("Status")
		return false
	end
	return model
end

-- One mount for every state. `parent` is the gallery's full-stage frame; the view needs a Layer, so a stage of
-- its own is composed inside it with the item's frame.
local function mount(parent, props, scope, ctx)
	local host = Instance.new("Frame")
	host.Name = "RaceMenuStage"
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Size = UDim2.fromScale(1, 1)
	host.Parent = parent

	local layer = Layers.Stage(host, ctx, "Menu")
	local model = fakeModel(props)
	local view = View.Mount(layer, model, scope)

	local component = { Instance = host, Layer = layer, Model = model, View = view }
	local destroyed = false
	function component.Set(_patch) end
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		view.Destroy()
		layer.Destroy()
		host:Destroy()
	end
	scope:add(component)
	return component
end

local screen = {
	Id = "RaceMenu.Screen",
	Frame = "Menu",
	Slot = nil,
	Mount = mount,
	States = {
		{ Id = "Default", Props = { Rows = twoEvents() } },
		{ Id = "SecondSelected", Props = { Rows = twoEvents(), Select = 2 } },
		{ Id = "CompactDetail", Props = { Rows = twoEvents(), Page = "Detail" } },
		{ Id = "FiveEvents", Props = { Rows = fiveEvents(), Select = 3 } },
		{ Id = "FilterTimeTrials", Props = { Rows = fiveEvents(), Filter = "TimeTrials" } },
		{ Id = "FilterRaces", Props = { Rows = fiveEvents(), Filter = "Races" } },
		{ Id = "Empty", Props = { Rows = {} } },
		{ Id = "LongStrings", Props = { Rows = longEvents() } },
		{ Id = "LongStringsDetail", Props = { Rows = longEvents(), Page = "Detail" } },
		{ Id = "Teleporting", Props = { Rows = twoEvents(), Busy = true, Page = "Detail" } },
		{ Id = "TeleportFailed", Props = { Rows = twoEvents(), Status = "YOU MUST BE IN FREE ROAM TO TELEPORT TO A RACE START", Page = "Detail" } },
		{ Id = "NoRoute", Props = { Rows = twoEvents(), Status = Model.Strings.NoRoute, Page = "Detail" } },
		{ Id = "Closed", Props = { Rows = twoEvents(), Open = false } },
	},
}

return { screen }
