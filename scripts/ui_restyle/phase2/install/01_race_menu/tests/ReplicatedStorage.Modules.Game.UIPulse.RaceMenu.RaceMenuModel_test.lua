-- Pure tests for RaceMenu.RaceMenuModel: row building, the client-side filter, selection, pages, and the teleport
-- and set-route sequences with their action and payload tables. Fakes only: no remote, no bindable, no yield.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function keysOf(t)
		local keys = {}
		for key in pairs(t) do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		return table.concat(keys, ",")
	end

	-- Fixtures ---------------------------------------------------------------------------------------------------
	local SUMMARIES = {
		TimeTrial = {
			ShowroomTT = { EventId = "ShowroomTT", DisplayName = "Showroom Loop", RouteId = "ShowroomLoop", RouteType = "Circuit", Laps = 3, CheckpointCount = 17, MinPlayers = 1, MaxPlayers = 1, BaseReward = 6000, TrackImage = "", MapImage = "111" },
			HarbourTT = { EventId = "HarbourTT", DisplayName = "harbour Run", RouteId = "HarbourRun", RouteType = "PointToPoint", Laps = 1, CheckpointCount = 12, MinPlayers = 1, MaxPlayers = 1, BaseReward = 5000, TrackImage = "rbxassetid://5", MapImage = "" },
		},
		Race = {
			ShowroomRace = { EventId = "ShowroomRace", DisplayName = "Showroom Loop (race)", RouteId = "ShowroomLoop", RouteType = "Circuit", Laps = 5, CheckpointCount = 17, MinPlayers = 2, MaxPlayers = 6, BaseReward = 10000, TrackImage = "222", MapImage = "" },
			AkaneRace = { EventId = "AkaneRace", DisplayName = "Akane Ring", RouteId = "AkaneRing", RouteType = "Circuit", Laps = 5, CheckpointCount = 31, MinPlayers = 2, MaxPlayers = 8, BaseReward = 30000 },
		},
	}

	local function folder(parent, name, className)
		local instance = Instance.new(className or "Folder")
		instance.Name = name
		instance.Parent = parent
		return instance
	end

	-- A detached Config.Racing with both catalogues. Destroyed by the harness through env.Detached.
	local function racingConfig()
		local root = env.Detached("Folder")
		root.Name = "Racing"
		local timeTrials = folder(root, "TimeTrialCatalog")
		folder(timeTrials, "ShowroomTT")
		local harbour = folder(timeTrials, "HarbourEntry", "Configuration")
		harbour:SetAttribute("EventId", "HarbourTT")
		folder(timeTrials, "BrokenEvent") -- the reader fails for it: no row
		folder(timeTrials, "NotAnEvent", "StringValue") -- neither Folder nor Configuration: ignored
		local races = folder(root, "RaceCatalog")
		folder(races, "ShowroomRace")
		folder(races, "AkaneRace")
		return root
	end

	local reader = {
		GetEventSummary = function(eventId, mode)
			local summary = SUMMARIES[mode] and SUMMARIES[mode][eventId]
			if not summary then
				error("no such event " .. tostring(eventId))
			end
			return summary
		end,
	}

	local function money(amount)
		return "$" .. tostring(amount)
	end

	-- A fake world: every bindable fire, wait, remote call and presence change lands in one ordered log.
	local function world(options)
		options = options or {}
		local log = {}
		local w = { Log = log, Reply = options.Reply, RouteFound = options.RouteFound ~= false }
		local function fakeBindable(name)
			return {
				IsA = function(_, className)
					return className == "BindableEvent"
				end,
				Fire = function(_, ...)
					table.insert(log, { Kind = "Fire", Name = name, Args = table.pack(...) })
				end,
			}
		end
		local bindables = {
			["UI.FreeRoamVehicleExited"] = fakeBindable("FreeRoamVehicleExited"),
			["UI.FreeRoamHudPresentationMode"] = fakeBindable("FreeRoamHudPresentationMode"),
			["UI.ShowTopNotification"] = fakeBindable("ShowTopNotification"),
			["Racing.RaceTransitionRequest"] = fakeBindable("RaceTransitionRequest"),
		}
		if options.MissingBindables then
			bindables = { ["UI.ShowTopNotification"] = { IsA = function() return false end } }
		end
		w.Deps = {
			RacingConfig = if options.NoConfig then nil else racingConfig(),
			RaceConfigReader = reader,
			RouteGuide = {
				SetDestinationById = function(id, sourceId)
					table.insert(log, { Kind = "Route", Id = id, Source = sourceId })
					return w.RouteFound
				end,
			},
			TeleportInvoke = {
				InvokeServer = function(_, action, payload)
					table.insert(log, { Kind = "Invoke", Action = action, Payload = payload })
					if w.Reply == "error" then
						error("remote failed")
					end
					return w.Reply
				end,
			},
			FindBindable = function(folderName, name)
				return bindables[folderName .. "." .. name]
			end,
			Money = money,
			Presence = {
				Open = function(surface, kind)
					table.insert(log, { Kind = "Presence", Surface = surface, PresenceKind = kind, Open = true })
					return function()
						table.insert(log, { Kind = "Presence", Surface = surface, Open = false })
					end
				end,
			},
			Wait = function(seconds)
				table.insert(log, { Kind = "Wait", Seconds = seconds })
				if w.DuringWait then
					local during = w.DuringWait
					w.DuringWait = nil
					during()
				end
			end,
			Spawn = function(callback, ...)
				callback(...)
			end,
		}
		w.Model = M.new(w.Deps)
		w.Reasons = {}
		w.Model.Changed:Connect(function(reason)
			table.insert(w.Reasons, reason)
		end)
		function w.Clear()
			table.clear(log)
			table.clear(w.Reasons)
		end
		function w.Kinds()
			local parts = {}
			for _, entry in ipairs(log) do
				local label = entry.Kind
				if entry.Kind == "Fire" then
					label = entry.Name
					local first = entry.Args[1]
					if entry.Name == "RaceTransitionRequest" then
						label = "Transition:" .. tostring(first.Step)
					elseif entry.Name == "FreeRoamHudPresentationMode" then
						label = "Presentation:" .. tostring(first.Active)
					end
				end
				table.insert(parts, label)
			end
			return table.concat(parts, " > ")
		end
		function w.Find(kind, name)
			for _, entry in ipairs(log) do
				if entry.Kind == kind and (name == nil or entry.Name == name) then
					return entry
				end
			end
			return nil
		end
		return w
	end

	-- Rows -------------------------------------------------------------------------------------------------------
	case("rows: one row per route, modes merged, sorted by lower-case name", function()
		local rows = M.BuildRows(racingConfig(), reader)
		expect(#rows == 3, "three routes, got " .. #rows)
		expect(rows[1].Key == "AkaneRing" and rows[2].Key == "HarbourRun" and rows[3].Key == "ShowroomLoop", "order")
		expect(rows[2].DisplayName == "harbour Run", "lower-case name sorts between A and S")
		local showroom = rows[3]
		expect(showroom.TimeTrial == SUMMARIES.TimeTrial.ShowroomTT, "time trial summary kept")
		expect(showroom.Race == SUMMARIES.Race.ShowroomRace, "race summary kept")
		expect(showroom.Primary == showroom.TimeTrial, "Primary is the time trial when present")
		expect(showroom.DisplayName == "Showroom Loop", "the name comes from the first summary seen (time trial)")
		expect(rows[1].TimeTrial == nil and rows[1].Primary == rows[1].Race, "race-only row: Primary is the race")
	end)

	case("rows: EventId attribute wins over the name; broken and non-event children give no row", function()
		local rows = M.BuildRows(racingConfig(), reader)
		for _, row in ipairs(rows) do
			expect(row.Key ~= "BrokenEvent" and row.Key ~= "NotAnEvent" and row.Key ~= "HarbourEntry", "unexpected row " .. row.Key)
		end
		expect(#M.CatalogEvents(nil, "RaceCatalog") == 0, "no config: no events")
		expect(#M.BuildRows(nil, reader) == 0, "no config: no rows")
		expect(#M.BuildRows(racingConfig(), nil) == 0, "no reader: no rows")
	end)

	case("rows: key and name fallbacks (84, 87)", function()
		local root = env.Detached("Folder")
		local catalog = folder(root, "RaceCatalog")
		folder(catalog, "Plain")
		local rows = M.BuildRows(root, { GetEventSummary = function() return { EventId = "E" } end })
		expect(#rows == 1 and rows[1].Key == "Plain" and rows[1].DisplayName == "Plain", "falls back to the event id")
	end)

	case("row text: media, availability, descriptor and asset rules", function()
		local rows = M.BuildRows(racingConfig(), reader)
		local akane, harbour, showroom = rows[1], rows[2], rows[3]
		expect(M.MediaFor(showroom, "TrackImage") == "222", "race value first")
		expect(M.MediaFor(showroom, "MapImage") == "111", "then the time trial value")
		expect(M.MediaFor(akane, "MapImage") == "", "missing everywhere is empty")
		expect(M.AvailabilityText(showroom) == "TIME TRIAL  \u{2022}  RACE", "both modes")
		expect(M.AvailabilityText(akane) == "RACE" and M.AvailabilityText(harbour) == "TIME TRIAL", "single modes")
		expect(M.RouteDescriptor(showroom) == "CIRCUIT  \u{2022}  5 LAPS", "circuit uses the race laps")
		expect(M.RouteDescriptor(harbour) == "POINT-TO-POINT  \u{2022}  12 CHECKPOINTS", "point to point")
		expect(M.Asset("") == "" and M.Asset(nil) == "", "empty asset")
		expect(M.Asset("123") == "rbxassetid://123", "a bare id gets the scheme")
		expect(M.Asset("rbxassetid://5") == "rbxassetid://5" and M.Asset("rbxthumb://x") == "rbxthumb://x", "schemes pass through")
	end)

	case("facts: the Classic rule 267-274", function()
		local rows = M.BuildRows(racingConfig(), reader)
		local facts = M.Facts(rows[3], money)
		expect(#facts == 5, "five facts")
		expect(facts[1].Id == "Route" and facts[1].Value == "CIRCUIT" and facts[1].Circuit == true, "route type from Primary")
		expect(facts[2].Classic == "5 LAPS" and facts[2].Value == "5", "laps from the race summary")
		expect(facts[3].Classic == "17 CHECKPOINTS", "checkpoints from Primary")
		expect(facts[4].Classic == "2-6 PLAYERS" and facts[4].Value == "2 TO 6", "players from the race summary")
		expect(facts[5].Kind == "Prize" and facts[5].Value == "$10000", "prize is the race reward through Money")
		local harbour = M.Facts(rows[2], money)
		expect(harbour[1].Value == "POINTTOPOINT" and harbour[1].Circuit == false, "upper-cased route type")
		expect(harbour[4].Value == "1" and harbour[4].Classic == "1-1 PLAYERS", "one player")
		expect(harbour[5].Value == "$5000", "time-trial reward when there is no race")
		expect(M.MoneyText(nil, 5) == "" and M.MoneyText(function() error("x") end, 5) == "", "a failing formatter gives an empty text")
		expect(M.MoneyText(money, "abc") == "$0", "non-numbers count as 0 (62)")
	end)

	case("describe: the strings a view shows", function()
		local rows = M.BuildRows(racingConfig(), reader)
		local item = M.Describe(rows[3], money)
		expect(item.Key == "ShowroomLoop" and item.Title == "SHOWROOM LOOP", "key and upper-case title")
		expect(item.Thumbnail == "rbxassetid://111", "thumbnail prefers the map (349-350)")
		expect(item.TrackImage == "rbxassetid://222" and item.MapImage == "rbxassetid://111", "images")
		expect(item.TypeLine == "CIRCUIT  \u{2022}  TIME TRIAL  \u{2022}  RACE", "type line")
		expect(item.Prize == "$10000" and item.Laps == "5" and item.Players == "2 TO 6", "list figures")
		local harbour = M.Describe(rows[2], money)
		expect(harbour.Thumbnail == "rbxassetid://5", "thumbnail falls back to the track image")
	end)

	case("filter: a client-side filter of the same rows", function()
		local rows = M.BuildRows(racingConfig(), reader)
		expect(#M.FilterRows(rows, "All") == 3, "all")
		local trials = M.FilterRows(rows, "TimeTrials")
		expect(#trials == 2 and trials[1].Key == "HarbourRun" and trials[2].Key == "ShowroomLoop", "time trials keep order")
		local races = M.FilterRows(rows, "Races")
		expect(#races == 2 and races[1].Key == "AkaneRing" and races[2] == rows[3], "races are the same row tables")
		expect(#M.FilterRows(rows, "Nonsense") == 0, "unknown filter shows nothing")
		for _, id in ipairs(M.Filters) do
			expect(id ~= "Race" and id ~= "Car" and id ~= "Garage", "a filter id must not be an onboarding lock name")
		end
	end)

	-- Open and close ---------------------------------------------------------------------------------------------
	case("open: presentation, presence, rows, first row selected; toggle closes", function()
		local w = world()
		local model = w.Model
		expect(model.IsOpen() == false and model.Count() == 0 and model.CanAct() == false, "closed and empty before the first open")
		model.Toggle()
		expect(model.IsOpen() == true, "open")
		expect(w.Kinds() == "Presentation:true > Presence", "published first, then presence: " .. w.Kinds())
		local payload = w.Find("Fire", "FreeRoamHudPresentationMode").Args[1]
		expect(keysOf(payload) == "Active,KeepTelemetry,Owner", "payload keys " .. keysOf(payload))
		expect(payload.Owner == "RaceBrowser" and payload.Active == true and payload.KeepTelemetry == false, "payload values")
		local presence = w.Find("Presence")
		expect(presence.Surface == "RaceBrowser" and presence.PresenceKind == "FullMenu", "presence surface and kind")
		expect(model.Count() == 3 and model.SelectedKey() == "AkaneRing", "first sorted row selected")
		expect(model.Filter() == "All" and model.Page() == "List" and model.Status() == nil, "defaults")
		expect(#w.Reasons == 1 and w.Reasons[1] == "Open", "one Changed(Open)")
		local items = model.Items()
		expect(#items == 3 and items[3].Title == "SHOWROOM LOOP", "items in order")
		local item, index, count = model.Detail()
		expect(item == items[1] and index == 1 and count == 3, "detail of the selection")

		w.Clear()
		model.Toggle()
		expect(model.IsOpen() == false, "closed")
		expect(w.Kinds() == "Presentation:false > Presence", "close publishes and releases: " .. w.Kinds())
		expect(w.Find("Presence").Open == false, "presence released")
		expect(w.Reasons[1] == "Open", "Changed(Open) on close")
	end)

	case("open: every open rebuilds rows and resets selection, filter and page", function()
		local w = world()
		local model = w.Model
		model.SetOpen(true)
		local firstVersion = model.RowsVersion()
		expect(model.SetFilter("Races") == true and model.Select("ShowroomLoop") == true, "filter and select")
		model.SetPage("Detail")
		expect(model.Page() == "Detail", "detail page")
		model.SetOpen(false)
		model.SetOpen(true)
		expect(model.Filter() == "All" and model.Page() == "List" and model.SelectedKey() == "AkaneRing", "reset on open")
		expect(model.RowsVersion() > firstVersion, "rows version moved")
	end)

	case("open: the empty state", function()
		local w = world({ NoConfig = true })
		local model = w.Model
		model.SetOpen(true)
		expect(model.Count() == 0 and model.SelectedKey() == nil and model.CanAct() == false, "nothing to select")
		local item, index, count = model.Detail()
		expect(item == nil and index == 0 and count == 0, "no detail")
		w.Clear()
		expect(model.Teleport() == false and model.SetRoute() == false, "both actions refuse")
		expect(#w.Log == 0, "and send nothing")
		model.SetPage("Detail")
		expect(model.Page() == "List", "no detail page without a selection")
	end)

	-- Selection, filter, page ------------------------------------------------------------------------------------
	case("selection: by key, Changed once, unknown key refused", function()
		local w = world()
		local model = w.Model
		model.SetOpen(true)
		w.Clear()
		expect(model.Select("ShowroomLoop") == true and model.SelectedKey() == "ShowroomLoop", "selected")
		expect(#w.Reasons == 1 and w.Reasons[1] == "Selection", "Changed(Selection)")
		expect(model.Select("ShowroomLoop") == true and #w.Reasons == 1, "same row: no second Changed")
		expect(model.Select("Nope") == false and model.SelectedKey() == "ShowroomLoop", "unknown key keeps the selection")
		local _, index = model.Detail()
		expect(index == 3, "index in the visible rows")
		expect(#w.Log == 0, "a selection fires nothing")
	end)

	case("filter: keeps a visible selection, else selects the first visible row", function()
		local w = world()
		local model = w.Model
		model.SetOpen(true)
		model.Select("ShowroomLoop")
		w.Clear()
		expect(model.SetFilter("TimeTrials") == true, "filter set")
		expect(model.Count() == 2 and model.SelectedKey() == "ShowroomLoop", "selection kept")
		expect(w.Reasons[1] == "Filter", "Changed(Filter)")
		local _, index, count = model.Detail()
		expect(index == 2 and count == 2, "index follows the filtered rows")
		model.SetFilter("All")
		model.Select("AkaneRing")
		model.SetFilter("TimeTrials")
		expect(model.SelectedKey() == "HarbourRun", "hidden selection moves to the first visible row")
		expect(model.Select("AkaneRing") == false, "a filtered-out row cannot be selected")
		expect(model.SetFilter("Bogus") == false and model.Filter() == "TimeTrials", "unknown filter refused")
		model.CycleFilter(1)
		expect(model.Filter() == "Races", "cycle forward")
		model.CycleFilter(1)
		expect(model.Filter() == "All", "cycle wraps")
		model.CycleFilter(-1)
		expect(model.Filter() == "Races", "cycle back wraps")
		expect(#w.Log == 0, "filtering fires nothing")
	end)

	case("page and back: detail returns to the list, the list closes", function()
		local w = world()
		local model = w.Model
		model.Back()
		expect(#w.Log == 0, "back while closed does nothing")
		model.SetOpen(true)
		model.SetPage("Detail")
		w.Clear()
		model.Back()
		expect(model.Page() == "List" and model.IsOpen() == true and w.Reasons[1] == "Page", "back to the list")
		model.Back()
		expect(model.IsOpen() == false, "back on the list closes")
	end)

	-- Teleport ---------------------------------------------------------------------------------------------------
	case("teleport tables: remote, action and payload keys (427)", function()
		expect(M.Remote.Path == "ReplicatedStorage.Remotes.Racing.RaceBrowserTeleportInvoke", "remote path")
		expect(M.Remote.Action == "TeleportToRaceStart", "action")
		expect(table.concat(M.Remote.Keys, ",") == "EventId,Mode", "keys")
		local rows = M.BuildRows(racingConfig(), reader)
		local action, payload = M.TeleportRequest(rows[3])
		expect(action == "TeleportToRaceStart" and keysOf(payload) == "EventId,Mode", "request shape")
		expect(payload.EventId == "ShowroomTT" and payload.Mode == "TimeTrial", "a row with both modes teleports to the time trial")
		local _, racePayload = M.TeleportRequest(rows[1])
		expect(racePayload.EventId == "AkaneRace" and racePayload.Mode == "Race", "a race-only row uses the race")
		expect(M.TeleportRequest({ Key = "x", DisplayName = "x" }) == nil, "no mode, no request")
	end)

	case("transition tables: the four payloads (423, 432, 439, 440)", function()
		local step, payload = M.TransitionPayload("TeleportBegin")
		expect(step == "FadeOut" and keysOf(payload) == "Label,Reason" and payload.Reason == "BrowserTeleport" and payload.Label == "TELEPORTING", "begin")
		step, payload = M.TransitionPayload("TeleportFailed")
		expect(step == "FadeIn" and keysOf(payload) == "Delay,Reason" and payload.Reason == "BrowserTeleportFailed" and payload.Delay == 0.08, "failed")
		step, payload = M.TransitionPayload("TeleportCamera")
		expect(step == "RestoreCamera" and keysOf(payload) == "Reason" and payload.Reason == "BrowserTeleport", "camera")
		step, payload = M.TransitionPayload("TeleportDone")
		expect(step == "FadeIn" and keysOf(payload) == "Delay,Reason" and payload.Reason == "BrowserTeleport" and payload.Delay == 0.3, "done")
		expect(pcall(M.TransitionPayload, "Other") == false, "unknown kind errors")
	end)

	case("teleport success: the Classic sequence 416-441", function()
		local w = world({ Reply = { Ok = true } })
		local model = w.Model
		model.SetOpen(true)
		model.Select("ShowroomLoop")
		w.Clear()
		local busyDuringWait, textDuringWait
		w.DuringWait = function()
			busyDuringWait = model.Busy()
			textDuringWait = model.TeleportText()
		end
		expect(model.Teleport() == true, "teleport succeeds")
		expect(
			w.Kinds() == "Transition:FadeOut > Wait > Invoke > FreeRoamVehicleExited > Presentation:false > Presence > Transition:RestoreCamera > Transition:FadeIn",
			"sequence: " .. w.Kinds()
		)
		expect(w.Find("Wait").Seconds == 0.25, "0.25 s fade wait")
		local invoke = w.Find("Invoke")
		expect(invoke.Action == "TeleportToRaceStart" and keysOf(invoke.Payload) == "EventId,Mode", "action and payload keys")
		expect(invoke.Payload.EventId == "ShowroomTT" and invoke.Payload.Mode == "TimeTrial", "payload values")
		local fadeOut = w.Find("Fire", "RaceTransitionRequest").Args[1]
		expect(keysOf(fadeOut) == "Label,Reason,Step" and fadeOut.Step == "FadeOut", "Step is added to the payload (392)")
		expect(busyDuringWait == true and textDuringWait == "TELEPORTING...", "busy text while waiting")
		expect(model.Busy() == false and model.TeleportText() == "TELEPORT", "busy cleared")
		expect(model.IsOpen() == false and model.Status() == nil, "closed without a status")
		expect(w.Reasons[1] == "Busy" and w.Reasons[#w.Reasons] == "Open", "Changed: Busy then Open")
		local last = w.Log[#w.Log].Args[1]
		expect(last.Reason == "BrowserTeleport" and last.Delay == 0.3, "final fade in")
	end)

	case("teleport success: Success = true counts, race-only row sends Mode Race", function()
		local w = world({ Reply = { Success = true } })
		w.Model.SetOpen(true)
		w.Clear()
		expect(w.Model.Teleport() == true, "Success is accepted")
		local invoke = w.Find("Invoke")
		expect(invoke.Payload.EventId == "AkaneRace" and invoke.Payload.Mode == "Race", "race-only payload")
	end)

	case("teleport failure: fade back in, inline message, menu stays open", function()
		local function failing(reply)
			local w = world({ Reply = reply })
			w.Model.SetOpen(true)
			w.Clear()
			expect(w.Model.Teleport() == false, "teleport fails")
			expect(w.Kinds() == "Transition:FadeOut > Wait > Invoke > Transition:FadeIn", "failure sequence: " .. w.Kinds())
			local fadeIn = w.Log[#w.Log].Args[1]
			expect(fadeIn.Reason == "BrowserTeleportFailed" and fadeIn.Delay == 0.08, "failed fade in")
			expect(w.Model.IsOpen() == true and w.Model.Busy() == false, "still open, not busy")
			expect(w.Reasons[1] == "Busy" and w.Reasons[2] == "Busy" and #w.Reasons == 2, "Changed twice")
			return w.Model.Status()
		end
		expect(failing({ Ok = false, Message = "NOT NOW" }) == "NOT NOW", "Message first")
		expect(failing({ Error = "BAD" }) == "BAD", "then Error")
		expect(failing({}) == "TELEPORT FAILED", "then the default")
		expect(failing({ Ok = "yes" }) == "TELEPORT FAILED", "Ok must be exactly true")
		expect(failing(nil) == "TELEPORT FAILED", "no reply")
		expect(failing("oops") == "TELEPORT FAILED", "a reply that is not a table")
		expect(failing("error") == "TELEPORT FAILED", "a remote error")
	end)

	case("teleport: busy guard, one call in flight, never retried", function()
		local w = world({ Reply = { Ok = false } })
		local model = w.Model
		model.SetOpen(true)
		w.Clear()
		local second
		w.DuringWait = function()
			second = model.Teleport()
		end
		model.Teleport()
		expect(second == false, "the second request is refused while busy")
		local invokes = 0
		for _, entry in ipairs(w.Log) do
			if entry.Kind == "Invoke" then
				invokes += 1
			end
		end
		expect(invokes == 1, "exactly one InvokeServer, got " .. invokes)
	end)

	case("teleport: a failure that outlives its opening does not draw into the next one", function()
		local w = world({ Reply = { Message = "LATE" } })
		local model = w.Model
		model.SetOpen(true)
		w.DuringWait = function()
			model.SetOpen(false)
			model.SetOpen(true)
		end
		expect(model.Teleport() == false, "fails")
		expect(model.Status() == nil, "the new opening has no status")
		expect(model.IsOpen() == true and model.Busy() == false, "open and idle")
	end)

	case("teleport: the row is fixed when the button is pressed", function()
		local w = world({ Reply = { Ok = true } })
		local model = w.Model
		model.SetOpen(true)
		model.Select("ShowroomLoop")
		w.Clear()
		w.DuringWait = function()
			model.Select("AkaneRing")
		end
		model.Teleport()
		local invoke = w.Find("Invoke")
		expect(invoke.Payload.EventId == "ShowroomTT" and invoke.Payload.Mode == "TimeTrial", "event and mode from the same row")
	end)

	-- Set route --------------------------------------------------------------------------------------------------
	case("set route success: guide, close, notification (444-454)", function()
		local w = world()
		local model = w.Model
		model.SetOpen(true)
		model.Select("HarbourRun")
		w.Clear()
		expect(model.SetRoute() == true, "route set")
		expect(w.Kinds() == "Route > Presentation:false > Presence > ShowTopNotification", "sequence: " .. w.Kinds())
		local route = w.Find("Route")
		expect(route.Id == "HarbourRun" and route.Source == "Player", "SetDestinationById(key, \"Player\")")
		local toast = w.Find("Fire", "ShowTopNotification")
		expect(toast.Args.n == 2 and toast.Args[1] == "ROUTE SET: HARBOUR RUN" and toast.Args[2] == 2.2, "toast text and duration")
		expect(model.IsOpen() == false, "closed")
	end)

	case("set route failure: inline message, stays open, nothing fired", function()
		local w = world({ RouteFound = false })
		local model = w.Model
		model.SetOpen(true)
		w.Clear()
		expect(model.SetRoute() == false, "no route")
		expect(w.Kinds() == "Route", "only the guide was asked: " .. w.Kinds())
		expect(model.Status() == "NO ROUTE FOR THIS EVENT YET" and model.IsOpen() == true, "status and still open")
		expect(w.Reasons[1] == "Status", "Changed(Status)")
		model.SetOpen(false)
		model.SetOpen(true)
		expect(model.Status() == nil, "the status clears on the next open")
	end)

	-- Robustness -------------------------------------------------------------------------------------------------
	case("missing bindables and a failing view never break a sequence", function()
		local w = world({ MissingBindables = true, Reply = { Ok = true } })
		local model = w.Model
		model.Changed:Connect(function() end)
		model.SetOpen(true)
		expect(model.IsOpen() == true and model.Count() == 3, "opens without the presentation bindable")
		w.Clear()
		expect(model.Teleport() == true, "teleport still completes")
		expect(w.Kinds() == "Wait > Invoke > Presence", "only the wait, the call and the presence release: " .. w.Kinds())
		model.SetOpen(true)
		w.Clear()
		expect(model.SetRoute() == true, "set route completes")
		expect(w.Find("Fire") == nil, "a non-bindable ShowTopNotification is not fired")
	end)

	case("signal: Once fires once, Disconnect stops delivery", function()
		local w = world()
		local model = w.Model
		local once, live = 0, 0
		model.Changed:Once(function()
			once += 1
		end)
		local connection = model.Changed:Connect(function()
			live += 1
		end)
		model.SetOpen(true)
		model.SetOpen(false)
		expect(once == 1 and live == 2, "once " .. once .. ", live " .. live)
		connection:Disconnect()
		model.SetOpen(true)
		expect(live == 2 and connection.Connected == false, "disconnected")
	end)

	return results
end
