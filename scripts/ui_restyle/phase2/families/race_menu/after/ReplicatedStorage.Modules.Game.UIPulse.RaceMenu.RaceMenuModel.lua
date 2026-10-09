-- Owns the race menu state and actions (event rows, filter, selection, page, open and close, teleport, set route); it does not own any GuiObject, the server teleport, the route guide or the HUD it asks to hide.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuModel. Requires: none (every service, remote, bindable and shared module arrives through deps).
--
-- Line numbers in comments refer to the Classic race browser source that API2 5.2 names.
-- deps = {
--   RacingConfig     = ReplicatedStorage.Config.Racing (Folder) or nil,
--   RaceConfigReader = Racing.RaceConfigReader (GetEventSummary) or nil,
--   RouteGuide       = UI.RouteGuide (SetDestinationById) or nil,
--   TeleportInvoke   = Remotes.Racing.RaceBrowserTeleportInvoke or nil,
--   FindBindable     = function(folderName: "UI" | "Racing", name: string): Instance?   -- PlayerScripts.Runtime.<folder>.<name>
--   Money            = function(amount: number): string        -- Kit.Data.Money(amount, false)
--   Presence         = Kit.Presence or nil,
--   Wait             = task.wait, Spawn = task.spawn (tests pass fakes),
-- }
local Model = {}

local SURFACE = "RaceBrowser" -- presentation owner key (400) and the Presence surface (API2 5.2)

-- Filter ids are also the tab ids. None of them may be "Race": Classic onboarding writes Active on every
-- GuiButton with that name (programme contract 2.3).
Model.Filters = table.freeze({ "All", "TimeTrials", "Races" })
Model.Separator = "  \u{2022}  " -- the Classic separator (192, 199, 201)

Model.Strings = table.freeze({
	Teleport = "TELEPORT", -- 430, 596
	Teleporting = "TELEPORTING...", -- 421
	TeleportFailed = "TELEPORT FAILED", -- 433
	NoRoute = "NO ROUTE FOR THIS EVENT YET", -- 447
	RouteSetPrefix = "ROUTE SET: ", -- 453
})

-- The one remote action of this owner and its payload keys (427). Tests and contract.json read this table.
Model.Remote = table.freeze({
	Path = "ReplicatedStorage.Remotes.Racing.RaceBrowserTeleportInvoke",
	Action = "TeleportToRaceStart",
	Keys = table.freeze({ "EventId", "Mode" }),
})

-- The four RaceTransitionRequest payloads (423, 432, 439, 440). `Step` is added by transition(), as Classic 392.
function Model.TransitionPayload(kind: string): (string, { [string]: any })
	if kind == "TeleportBegin" then
		return "FadeOut", { Reason = "BrowserTeleport", Label = "TELEPORTING" } -- 423
	elseif kind == "TeleportFailed" then
		return "FadeIn", { Reason = "BrowserTeleportFailed", Delay = 0.08 } -- 432
	elseif kind == "TeleportCamera" then
		return "RestoreCamera", { Reason = "BrowserTeleport" } -- 439
	elseif kind == "TeleportDone" then
		return "FadeIn", { Reason = "BrowserTeleport", Delay = 0.3 } -- 440
	end
	error("[Pulse.RaceMenuModel] unknown transition '" .. tostring(kind) .. "'", 2)
end

-- Pure rules carried from Classic ---------------------------------------------------------------------------------

-- 70-77.
function Model.CatalogEvents(racingConfig: any, name: string): { any }
	local catalog = racingConfig and racingConfig:FindFirstChild(name)
	local result = {}
	for _, event in ipairs(catalog and catalog:GetChildren() or {}) do
		if event:IsA("Folder") or event:IsA("Configuration") then
			table.insert(result, event)
		end
	end
	return result
end

-- 79-94.
local function addMode(byRoute, mode, catalogName, racingConfig, reader)
	for _, event in ipairs(Model.CatalogEvents(racingConfig, catalogName)) do
		local eventId = tostring(event:GetAttribute("EventId") or event.Name)
		local ok, summary = pcall(function()
			return reader.GetEventSummary(eventId, mode)
		end)
		if ok and type(summary) == "table" then
			local key = tostring(summary.RouteId or eventId)
			local row = byRoute[key]
			if not row then
				row = { Key = key, DisplayName = tostring(summary.DisplayName or summary.RouteDisplayName or key) }
				byRoute[key] = row
			end
			row[mode] = summary
			if mode == "TimeTrial" or not row.Primary then
				row.Primary = summary
			end
		end
	end
end

-- 96-102. Returns the sorted rows; the caller selects rows[1] (105).
function Model.BuildRows(racingConfig: any, reader: any): { any }
	local byRoute = {}
	addMode(byRoute, "TimeTrial", "TimeTrialCatalog", racingConfig, reader)
	addMode(byRoute, "Race", "RaceCatalog", racingConfig, reader)
	local rows = {}
	for _, row in pairs(byRoute) do
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b)
		return string.lower(a.DisplayName) < string.lower(b.DisplayName)
	end)
	return rows
end

-- 180-186.
function Model.MediaFor(row: any, field: string): string
	local raceValue = row.Race and tostring(row.Race[field] or "") or ""
	if raceValue ~= "" then
		return raceValue
	end
	local timeTrialValue = row.TimeTrial and tostring(row.TimeTrial[field] or "") or ""
	if timeTrialValue ~= "" then
		return timeTrialValue
	end
	return row.Primary and tostring(row.Primary[field] or "") or ""
end

-- 188-193.
function Model.AvailabilityText(row: any): string
	local modes = {}
	if row.TimeTrial then
		table.insert(modes, "TIME TRIAL")
	end
	if row.Race then
		table.insert(modes, "RACE")
	end
	return table.concat(modes, Model.Separator)
end

-- 195-202.
function Model.RouteDescriptor(row: any): string
	local summary = row.Race or row.TimeTrial or row.Primary
	local routeType = string.upper(tostring(summary.RouteType or "CIRCUIT"))
	if routeType == "CIRCUIT" then
		return "CIRCUIT" .. Model.Separator .. tostring(summary.Laps or 1) .. " LAPS"
	end
	return "POINT-TO-POINT" .. Model.Separator .. tostring(summary.CheckpointCount or 0) .. " CHECKPOINTS"
end

-- RacingUIComponents.Asset (36-42 of that source), which Classic applies to every image it shows (120).
function Model.Asset(value: any): string
	local text = tostring(value or "")
	if text == "" then
		return ""
	end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then
		return text
	end
	if tonumber(text) then
		return "rbxassetid://" .. text
	end
	return text
end

-- The money text of a prize. `money` is Kit.Data.Money(amount, false), which replaces the private formatter 61-68;
-- the tonumber guard is Classic 62.
function Model.MoneyText(money: any, amount: any): string
	local value = tonumber(amount) or 0
	if type(money) == "function" then
		local ok, text = pcall(money, value)
		if ok and type(text) == "string" then
			return text
		end
	end
	return ""
end

-- 267-274. `Classic` is the text Classic drew for the row; Label and Value are the same facts split for the
-- Pulse fact list (mockup 02, c06).
function Model.Facts(row: any, money: any): { any }
	local summary = row.Primary -- 240
	local raceSummary = row.Race or summary -- 267
	local routeType = string.upper(tostring(summary.RouteType or "CIRCUIT"))
	local laps = tostring(raceSummary.Laps or 1)
	local checkpoints = tostring(summary.CheckpointCount or 0)
	local minPlayers = tostring(raceSummary.MinPlayers or 1)
	local maxPlayers = tostring(raceSummary.MaxPlayers or 1)
	local prize = Model.MoneyText(money, raceSummary.BaseReward or summary.BaseReward)
	return {
		{ Id = "Route", Label = "ROUTE", Value = routeType, Kind = "Text", Classic = routeType, Circuit = routeType == "CIRCUIT" },
		{ Id = "Laps", Label = "LAPS", Value = laps, Kind = "Text", Classic = laps .. " LAPS" },
		{ Id = "Checkpoints", Label = "CHECKPOINTS", Value = checkpoints, Kind = "Text", Classic = checkpoints .. " CHECKPOINTS" },
		{
			Id = "Players",
			Label = "PLAYERS",
			Value = if minPlayers == maxPlayers then minPlayers else minPlayers .. " TO " .. maxPlayers,
			Kind = "Text",
			Classic = minPlayers .. "-" .. maxPlayers .. " PLAYERS",
		},
		{ Id = "Prize", Label = "PRIZE", Value = prize, Kind = "Prize", Classic = "PRIZE" },
	}
end

-- Everything a view shows for one row, as plain strings. Built once per open.
function Model.Describe(row: any, money: any): { [string]: any }
	local facts = Model.Facts(row, money)
	local cardMap = Model.MediaFor(row, "MapImage") -- 349
	local trackImage = Model.MediaFor(row, "TrackImage")
	local availability = Model.AvailabilityText(row)
	return {
		Key = row.Key,
		Title = string.upper(row.DisplayName), -- 244, 353
		Availability = availability, -- 360
		Descriptor = Model.RouteDescriptor(row), -- 368
		TypeLine = facts[1].Value .. Model.Separator .. availability,
		Thumbnail = Model.Asset(cardMap ~= "" and cardMap or trackImage), -- 350
		TrackImage = Model.Asset(trackImage), -- 242
		MapImage = Model.Asset(cardMap), -- 254
		Laps = facts[2].Value,
		Players = facts[4].Value,
		Prize = facts[5].Value,
		Facts = facts,
	}
end

-- New in Pulse (API2 5.2): a client-side filter of the same rows.
function Model.FilterRows(rows: { any }, filter: string): { any }
	local result = {}
	for _, row in ipairs(rows) do
		if filter == "All" or (filter == "TimeTrials" and row.TimeTrial ~= nil) or (filter == "Races" and row.Race ~= nil) then
			table.insert(result, row)
		end
	end
	return result
end

-- What a teleport of `row` sends (418, 425, 427): the summary used, the action and the payload. nil when the row
-- has neither mode (419).
function Model.TeleportRequest(row: any): (string?, { [string]: any }?)
	local summary = row.TimeTrial or row.Race -- 418
	if not summary then
		return nil, nil
	end
	local mode = row.TimeTrial and "TimeTrial" or "Race" -- 425
	return Model.Remote.Action, { EventId = summary.EventId, Mode = mode } -- 427
end

-- Plumbing --------------------------------------------------------------------------------------------------------

-- A Luau signal (Connect, Once). Handlers run through `spawn`, so a failing view never stops a remote sequence.
local function newSignal(spawn)
	local handlers = {}
	local signal = {}
	function signal.Connect(_, callback)
		assert(type(callback) == "function", "[Pulse.RaceMenuModel] Changed:Connect expects a function")
		local connection = { Connected = true, Callback = callback }
		function connection.Disconnect()
			if not connection.Connected then
				return
			end
			connection.Connected = false
			local index = table.find(handlers, connection)
			if index then
				table.remove(handlers, index)
			end
		end
		table.insert(handlers, connection)
		return connection
	end
	function signal.Once(self, callback)
		local connection
		connection = signal.Connect(self, function(...)
			connection.Disconnect()
			callback(...)
		end)
		return connection
	end
	local function emit(...)
		for _, connection in ipairs(table.clone(handlers)) do
			if connection.Connected then
				spawn(connection.Callback, ...)
			end
		end
	end
	return signal, emit
end

-- Every remote call of this owner goes through here (API2 6.2). It is never retried.
local function call(remote, action, payload)
	return pcall(function()
		return remote:InvokeServer(action, payload)
	end)
end

local function isBindable(event)
	if event == nil then
		return false
	end
	local ok, yes = pcall(function()
		return event:IsA("BindableEvent")
	end)
	return ok and yes == true
end

function Model.new(deps: { [string]: any })
	assert(type(deps) == "table", "[Pulse.RaceMenuModel] deps table expected")
	local spawn = deps.Spawn or task.spawn
	local wait = deps.Wait or task.wait
	local money = deps.Money
	local presence = deps.Presence

	local self = {}
	local changed, emit = newSignal(spawn)
	self.Changed = changed

	local open = false
	local token = 0 -- the render token: bumped by every open and close
	local allRows = {}
	local rows = {} -- the filtered rows, in list order
	local items = {} -- row -> Describe(row)
	local rowsVersion = 0
	local filter = "All"
	local selected = nil
	local page = "List" -- Compact only: "List" or "Detail"
	local statusText = nil
	local teleportBusy = false -- 47
	local releasePresence = nil

	local function bindable(folderName, name)
		local find = deps.FindBindable
		if type(find) ~= "function" then
			return nil
		end
		local ok, event = pcall(find, folderName, name)
		if ok and isBindable(event) then
			return event
		end
		return nil
	end

	-- 383-386.
	local function fireDrivingExit()
		local event = bindable("UI", "FreeRoamVehicleExited")
		if event then
			event:Fire()
		end
	end

	-- 388-395.
	local function transition(kind)
		local step, payload = Model.TransitionPayload(kind)
		local event = bindable("Racing", "RaceTransitionRequest")
		if event then
			payload.Step = step
			event:Fire(payload)
		end
	end

	-- 397-401. Fired on every device (API2 5.2: the Classic touch branch 406-410 is not carried).
	local function publishPresentation(isOpen)
		local event = bindable("UI", "FreeRoamHudPresentationMode")
		if event then
			event:Fire({ Owner = SURFACE, Active = isOpen == true, KeepTelemetry = false })
		end
	end

	local function applyFilter()
		rows = Model.FilterRows(allRows, filter)
		rowsVersion += 1
	end

	-- 402-415. Fetch first, then draw: rows are built into locals and committed only if no newer open or close
	-- happened meanwhile (one render token).
	local function setOpen(wanted)
		wanted = wanted == true
		token += 1
		local mine = token
		open = wanted
		publishPresentation(wanted) -- 404
		if wanted then
			if not releasePresence and type(presence) == "table" and type(presence.Open) == "function" then
				local ok, release = pcall(presence.Open, SURFACE, "FullMenu")
				if ok and type(release) == "function" then
					releasePresence = release
				end
			end
			local built = Model.BuildRows(deps.RacingConfig, deps.RaceConfigReader) -- 414
			local described = {}
			for _, row in ipairs(built) do
				described[row] = Model.Describe(row, money)
			end
			if mine ~= token then
				return
			end
			allRows = built
			items = described
			filter = "All"
			page = "List"
			applyFilter()
			selected = rows[1] -- 105: the menu opens on the first sorted event every time
			statusText = nil -- 414
		else
			local release = releasePresence
			releasePresence = nil
			if release then
				pcall(release)
			end
		end
		emit("Open")
	end

	-- Getters ------------------------------------------------------------------------------------------------------
	function self.IsOpen(): boolean
		return open
	end
	function self.Token(): number
		return token
	end
	function self.RowsVersion(): number
		return rowsVersion
	end
	function self.Filter(): string
		return filter
	end
	function self.Page(): string
		return page
	end
	function self.Count(): number
		return #rows
	end
	function self.Rows(): { any }
		return table.clone(rows)
	end
	function self.Selected(): any
		return selected
	end
	function self.SelectedKey(): string?
		return selected and selected.Key or nil
	end
	-- The visible rows as view items, in order.
	function self.Items(): { any }
		local result = table.create(#rows)
		for index, row in ipairs(rows) do
			result[index] = items[row]
		end
		return result
	end
	-- The selected row's item, its 1-based place in the visible rows and their count; nil when nothing is selected.
	function self.Detail(): (any, number, number)
		if not selected then
			return nil, 0, #rows
		end
		return items[selected], table.find(rows, selected) or 0, #rows
	end
	function self.Status(): string?
		return statusText
	end
	function self.Busy(): boolean
		return teleportBusy
	end
	-- 230-239: both actions are available exactly when an event is selected.
	function self.CanAct(): boolean
		return selected ~= nil
	end
	-- 421, 430.
	function self.TeleportText(): string
		return teleportBusy and Model.Strings.Teleporting or Model.Strings.Teleport
	end

	-- Reducers -----------------------------------------------------------------------------------------------------
	function self.SetOpen(wanted: boolean)
		setOpen(wanted)
	end

	-- 606-608.
	function self.Toggle()
		setOpen(not open)
	end

	-- 375-379.
	function self.Select(key: string): boolean
		for _, row in ipairs(rows) do
			if row.Key == key then
				if selected ~= row then
					selected = row
					emit("Selection")
				end
				return true
			end
		end
		return false
	end

	function self.SetFilter(id: string): boolean
		if not table.find(Model.Filters, id) then
			return false
		end
		if id == filter then
			return true
		end
		filter = id
		applyFilter()
		if not (selected and table.find(rows, selected)) then
			selected = rows[1]
		end
		if not selected then
			page = "List"
		end
		emit("Filter")
		return true
	end

	-- Bumpers: step through the filters, wrapping.
	function self.CycleFilter(step: number)
		local index = table.find(Model.Filters, filter) or 1
		local count = #Model.Filters
		self.SetFilter(Model.Filters[(index - 1 + step) % count + 1])
	end

	function self.SetPage(id: string)
		if id ~= "List" and id ~= "Detail" then
			return
		end
		if id == "Detail" and not selected then
			return
		end
		if id ~= page then
			page = id
			emit("Page")
		end
	end

	-- Escape and ButtonB (new in Pulse, API2 5.2): detail goes back to the list, the list closes the menu.
	function self.Back()
		if not open then
			return
		end
		if page == "Detail" then
			self.SetPage("List")
		else
			setOpen(false)
		end
	end

	-- 416-441. YIELDS (the 0.25 s fade wait and the server call), so a view calls it in its own thread.
	function self.Teleport(): boolean
		if teleportBusy or not selected then -- 417
			return false
		end
		local action, payload = Model.TeleportRequest(selected) -- 418, 425
		if not action then -- 419
			return false
		end
		local mine = token
		teleportBusy = true -- 420
		statusText = nil -- 422
		emit("Busy") -- 421
		transition("TeleportBegin") -- 423
		wait(0.25) -- 424
		local ok, result = call(deps.TeleportInvoke, action, payload) -- 426-428
		teleportBusy = false -- 429
		if not ok or type(result) ~= "table" or (result.Ok ~= true and result.Success ~= true) then -- 431
			transition("TeleportFailed") -- 432
			local text = type(result) == "table" and tostring(result.Message or result.Error or Model.Strings.TeleportFailed)
				or Model.Strings.TeleportFailed -- 433
			if mine == token then
				statusText = text -- 434; a reply that outlived its opening does not draw into the next one
			end
			emit("Busy")
			return false
		end
		fireDrivingExit() -- 437
		setOpen(false) -- 438
		transition("TeleportCamera") -- 439
		transition("TeleportDone") -- 440
		return true
	end

	-- 444-454.
	function self.SetRoute(): boolean
		if not selected then -- 445
			return false
		end
		local row = selected
		local guide = deps.RouteGuide
		local ok, found = pcall(function()
			return guide.SetDestinationById(row.Key, "Player") -- 446
		end)
		if not ok or not found then
			statusText = Model.Strings.NoRoute -- 447
			emit("Status")
			return false
		end
		setOpen(false) -- 451
		local notify = bindable("UI", "ShowTopNotification") -- 452
		if notify then
			notify:Fire(Model.Strings.RouteSetPrefix .. string.upper(row.DisplayName), 2.2) -- 453
		end
		return true
	end

	return self
end

return Model
