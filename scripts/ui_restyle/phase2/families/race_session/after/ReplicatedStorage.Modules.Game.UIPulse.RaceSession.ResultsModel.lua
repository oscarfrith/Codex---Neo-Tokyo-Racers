-- Owns the race and time-trial results state: a projection of the server payload, the leaderboard read, the exit and again calls and the driver XP watch; no GuiObject, no computed result.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.ResultsModel. Requires: none (every handle arrives in deps).
--
-- Classic line references: R = ReplicatedStorage.Modules.Game.Racing.RaceTimeTrialResultCoachClient.
-- deps = {
--   Remotes = { RaceRequest, RaceQueueRequest },        RemoteFunctions (or fakes with :InvokeServer)
--   Bindable = (name) -> BindableEvent?,                "RaceTransitionRequest", "FreeRoamHudPresentationMode",
--                                                       "FreeRoamVehicleExited", "StartRaceQueueRequest"
--   UserId = number,
--   GetAttribute = (name) -> any,                       on the local player: LastRacingEventId, LastRacingVehicleId,
--                                                       Rank, XpIntoRank
--   OnAttribute = (name, handler) -> (() -> ()),        change listener on the local player; returns a disconnect
--   Spawn = task.spawn, Delay = task.delay,
--   Now = os.clock? }                                   optional clock (seconds), for the driver XP window
--
-- Every value shown is a payload field, a leaderboard reply field or a replicated attribute. Nothing is derived
-- except the driver XP change (programme contract 8). The server grants the reward (and so the XP, through
-- EconomyCashCommitted) before it fires the result, so the attributes can replicate just before or just after the
-- payload: the baseline is the value before a change seen in the last XP_BEFORE_SECONDS, else the value at the result.

local Model = {}

Model.OWNER = "RaceResults" -- R95
Model.KEEP_TELEMETRY = false -- R95
Model.LEADERBOARD_LIMIT = 20 -- R140
Model.XP_WAIT_SECONDS = 2 -- programme contract 8
Model.XP_BEFORE_SECONDS = 1 -- an attribute change this soon before the payload belongs to the result

local function newSignal()
	local connections = {}
	local signal = {}
	function signal:Connect(handler)
		local connection = { Connected = true }
		function connection:Disconnect()
			if not connection.Connected then
				return
			end
			connection.Connected = false
			local index = table.find(connections, connection)
			if index then
				table.remove(connections, index)
			end
		end
		connection.Handler = handler
		table.insert(connections, connection)
		return connection
	end
	-- A listener that errors (a view that failed to draw) must not stop the exit or again call that fired it.
	function signal:Fire(...)
		for _, connection in ipairs(table.clone(connections)) do
			if connection.Connected then
				local ok, problem = pcall(connection.Handler, ...)
				if not ok then
					warn("[Pulse.ResultsModel] a Changed listener failed: " .. tostring(problem))
				end
			end
		end
	end
	return signal
end
Model._newSignal = newSignal

-- R40-45, copied exactly.
function Model.TimeText(seconds)
	seconds = tonumber(seconds)
	if not seconds or seconds <= 0 then
		return "--:--.---"
	end
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%06.3f", minutes, seconds - minutes * 60)
end

-- R158.
function Model.PlaceText(place)
	place = tonumber(place)
	local suffix = place == 1 and "ST" or place == 2 and "ND" or place == 3 and "RD" or "TH"
	return (place and tostring(place) .. suffix or "--") .. " PLACE"
end

-- The first value that is not nil and not an empty string. The server sends "" for a name it does not have
-- (MatchmakingServer.broadcastPositions, GlobalLeaderboardServer), so `a or b` alone never reaches the fallback.
function Model.FirstText(...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if value ~= nil and tostring(value) ~= "" then
			return tostring(value)
		end
	end
	return nil
end

-- The first index of a window of `count` rows that holds row `index` near its middle. Pure.
function Model.WindowStart(total, index, count)
	if total <= count or not index then
		return 1
	end
	return math.clamp(index - math.floor((count - 1) / 2), 1, total - count + 1)
end

function Model.new(deps)
	assert(type(deps) == "table", "ResultsModel.new needs deps")
	local self = {}
	local changed = newSignal()
	self.Changed = changed

	local activeMode = nil -- R32
	local lastResult = nil -- R32
	local lastPositions = nil -- R32
	local completeText = "COMPLETE" -- R206
	local busy = false
	local showToken = 0
	local leaderboard = { State = "None", Entries = {} }
	local xp = { State = "Hidden" }
	local xpRelease = {}
	local now = deps.Now or os.clock

	-- Kept for the session: the values before the latest burst of Rank / XpIntoRank changes, and when it began.
	local seenRank = tonumber(deps.GetAttribute("Rank"))
	local seenInto = tonumber(deps.GetAttribute("XpIntoRank"))
	local recent = nil -- { At, Rank, Into }
	local function noteAttribute()
		local rank = tonumber(deps.GetAttribute("Rank"))
		local into = tonumber(deps.GetAttribute("XpIntoRank"))
		if rank == seenRank and into == seenInto then
			return
		end
		local at = now()
		if not recent or at - recent.At > Model.XP_BEFORE_SECONDS then
			recent = { At = at, Rank = seenRank, Into = seenInto }
		end
		seenRank, seenInto = rank, into
	end
	deps.OnAttribute("Rank", noteAttribute)
	deps.OnAttribute("XpIntoRank", noteAttribute)

	local function fire(name, payload)
		local event = deps.Bindable(name)
		if not event then
			return
		end
		if payload == nil then
			event:Fire()
		else
			event:Fire(payload)
		end
	end

	-- R36-39: the one remote call path of this owner.
	local function call(remote, action, payload)
		local ok, result = pcall(function()
			return remote:InvokeServer(action, payload or {})
		end)
		return ok and type(result) == "table" and result or { Ok = false, Success = false, Message = tostring(result) }
	end

	-- R23.
	local function transition(step, payload)
		payload = payload or {}
		payload.Step = step
		fire("RaceTransitionRequest", payload)
	end

	-- R92-96. One HUD owner for every form factor, so it is published on touch as well (API2 5.5).
	local function publishPresentation(open)
		fire("FreeRoamHudPresentationMode", { Owner = Model.OWNER, Active = open == true, KeepTelemetry = Model.KEEP_TELEMETRY })
	end

	local function releaseXp()
		for _, disconnect in ipairs(xpRelease) do
			disconnect()
		end
		xpRelease = {}
	end

	-- R105-107.
	local function hide()
		showToken += 1
		releaseXp()
		activeMode = nil
		lastResult = nil
		busy = false
		publishPresentation(false)
		changed:Fire("hide")
	end

	-- Driver XP (programme contract 8): the change in the replicated Rank and XpIntoRank attributes round the
	-- result (just before it, or within two seconds after it); hidden when there is none.
	local function watchXp(mine)
		releaseXp()
		xp = { State = "Pending" }
		local baseRank = tonumber(deps.GetAttribute("Rank"))
		local baseInto = tonumber(deps.GetAttribute("XpIntoRank"))
		if recent and now() - recent.At <= Model.XP_BEFORE_SECONDS and recent.Rank and recent.Into then
			baseRank, baseInto = recent.Rank, recent.Into
		end
		recent = nil
		local function check()
			if mine ~= showToken then
				return
			end
			local rank = tonumber(deps.GetAttribute("Rank"))
			local into = tonumber(deps.GetAttribute("XpIntoRank"))
			if not (rank and into and baseRank and baseInto) then
				return
			end
			if rank ~= baseRank then
				xp = { State = "Rank", Rank = rank, RankGain = rank - baseRank }
				changed:Fire("xp")
			elseif into ~= baseInto then
				xp = { State = "Xp", Gain = into - baseInto }
				changed:Fire("xp")
			end
		end
		check() -- the change came before the payload
		table.insert(xpRelease, deps.OnAttribute("Rank", check))
		table.insert(xpRelease, deps.OnAttribute("XpIntoRank", check))
		deps.Delay(Model.XP_WAIT_SECONDS, function()
			if mine ~= showToken then
				return
			end
			releaseXp()
			if xp.State == "Pending" then
				xp = { State = "Hidden" }
				changed:Fire("xp")
			end
		end)
	end

	-- R140-141. The buttons exist before this returns (API2 5.5); a late reply cannot draw into a newer result.
	local function loadLeaderboard(mine, payload)
		local reply = call(deps.Remotes.RaceRequest, "GetTimeTrialLeaderboard",
			{ EventId = payload.EventId, VehicleTier = payload.VehicleTier, Limit = Model.LEADERBOARD_LIMIT })
		if mine ~= showToken then
			return
		end
		local entries = type(reply.Entries) == "table" and reply.Entries or {}
		if #entries == 0 then
			leaderboard = { State = reply.Ok and "Empty" or "Unavailable", Entries = {} }
		else
			leaderboard = { State = "Rows", Entries = entries }
		end
		changed:Fire("leaderboard")
	end

	-- R196-199.
	local function show(mode, payload)
		showToken += 1
		local mine = showToken
		lastResult = payload
		activeMode = mode
		busy = false
		publishPresentation(true)
		if mode == "Race" then
			completeText = "RACE COMPLETE" -- R151
			leaderboard = { State = "None", Entries = {} }
		else
			completeText = payload.FinishReason == "Quit" and "TIME TRIAL ENDED" or "TIME TRIAL COMPLETE" -- R125
			leaderboard = { State = "Loading", Entries = {} }
		end
		watchXp(mine)
		changed:Fire("show")
		if mode ~= "Race" then
			deps.Spawn(loadLeaderboard, mine, payload)
		end
	end

	-- R143-147 (time trial) and R189-193 (race): EXIT TO START.
	local function exit()
		local payload, mode = lastResult, activeMode
		if busy or not payload then
			return
		end
		busy = true
		completeText = "EXITING..."
		changed:Fire("busy")
		transition("BeginLoading", { Destination = "RaceStart", Status = "RETURNING TO START" })
		local result
		if mode == "Race" then
			result = call(deps.Remotes.RaceQueueRequest, "ExitRaceToStart", {})
		else
			result = call(deps.Remotes.RaceRequest, "ExitFinishedTimeTrial", {})
		end
		local success = result.Ok == true or result.Success == true
		busy = false
		if success then
			if mode ~= "Race" then
				fire("FreeRoamVehicleExited")
			end
			hide()
			transition("CompleteLoading", { Status = "READY" })
		else
			transition("FailLoading", { Status = "RETURNING", Reason = result.Message })
			completeText = string.upper(tostring(result.Message or "EXIT FAILED"))
			changed:Fire("busy")
		end
	end

	-- R147 (TRY AGAIN) and R193 (RACE AGAIN).
	local function again()
		local payload, mode = lastResult, activeMode
		if busy or not payload then
			return
		end
		if mode == "Race" then
			local eventId = tostring(deps.GetAttribute("LastRacingEventId") or payload.EventId or "")
			local vehicleId = tostring(deps.GetAttribute("LastRacingVehicleId") or "")
			local start = deps.Bindable("StartRaceQueueRequest")
			if start and eventId ~= "" and vehicleId ~= "" then
				hide()
				start:Fire({ EventId = eventId, VehicleId = vehicleId, DisplayName = payload.DisplayName })
			end
			return
		end
		busy = true
		changed:Fire("busy")
		local result = call(deps.Remotes.RaceRequest, "StartStagedTimeTrial",
			{ EventId = payload.EventId, VehicleId = payload.SelectedVehicleId, LapCount = payload.LapTarget })
		busy = false
		if result.Ok == true or result.Success == true then
			hide()
		else
			-- Classic shows nothing here; the reason goes in the title so a refused retry is not silent.
			if lastResult == payload then
				completeText = string.upper(tostring(result.Message or "RETRY FAILED"))
			end
			changed:Fire("busy")
		end
	end

	-- R214-221: exactly the kinds the Classic owner handles.
	function self.Handle(payload)
		if type(payload) ~= "table" then
			return
		end
		local kind = tostring(payload.Type or "")
		if kind == "RacePositionUpdate" then
			lastPositions = payload.Positions or lastPositions
			if activeMode == "Race" and lastResult then
				changed:Fire("positions")
			end
		elseif kind == "RaceFinished" then
			show("Race", payload)
		elseif kind == "TimeTrialFinished" then
			show("TimeTrial", payload)
		elseif kind == "TimeTrialEnded" then
			hide()
		elseif kind == "RaceStaged" or kind == "RaceStarted" or kind == "TimeTrialStaged" or kind == "TimeTrialStarted"
			or kind == "RaceExitedToStart" then
			hide()
		end
	end

	function self.Exit()
		deps.Spawn(exit)
	end
	function self.Again()
		deps.Spawn(again)
	end

	function self.IsOpen()
		return lastResult ~= nil
	end
	function self.Mode()
		return activeMode
	end
	function self.Busy()
		return busy
	end
	-- The big line: R125, R151, and the EXITING... / failure text of R144-146.
	function self.Title()
		return completeText
	end
	-- R125 and R151: the event name.
	function self.SubTitle()
		if not lastResult then
			return ""
		end
		return string.upper(tostring(lastResult.DisplayName or (activeMode == "Race" and "RACE" or "TIME TRIAL")))
	end
	-- R132 and R163: the payload's RewardAmount, a number for Kit.Data.Money.
	function self.RewardAmount()
		return lastResult and (tonumber(lastResult.RewardAmount) or 0) or 0
	end
	-- R133: the time-trial hero time.
	function self.BestLapText()
		if not lastResult then
			return Model.TimeText(nil)
		end
		return Model.TimeText(lastResult.BestLapSeconds or lastResult.Elapsed)
	end
	function self.AgainText()
		return activeMode == "Race" and "RACE AGAIN" or "TRY AGAIN" -- R147, R193
	end
	function self.ExitText()
		return "EXIT TO START" -- R143, R189
	end

	-- { State = "Hidden" | "Pending" | "Xp" | "Rank", Gain?, Rank?, RankGain? }
	function self.Xp()
		return xp
	end

	-- The strip under the hero numbers: { { Label, Value, Kind = "Text" | "Chip" } }.
	function self.Strip()
		local items = {}
		local payload = lastResult
		if not payload then
			return items
		end
		if activeMode == "Race" then
			table.insert(items, { Label = "FINISH", Value = Model.PlaceText(payload.Place), Kind = "Text" }) -- R158-159
			table.insert(items, { Label = "FINISH TIME", Value = Model.TimeText(payload.Elapsed), Kind = "Text" }) -- R164-165
		else
			table.insert(items, { Label = "", Value = string.upper(tostring(payload.Medal or "Finished")), Kind = "Text" }) -- R130-131
			if payload.IsPersonalBest then
				table.insert(items, { Label = "", Value = "NEW PERSONAL BEST", Kind = "Chip" }) -- R134
			end
		end
		return items
	end

	-- The small list beside the table. Time trial: R135-137, the session laps (the last `count` when they do not
	-- fit). Race: R166-172, the two highlight rows, which no payload fills ("--", as Classic).
	function self.Facts(count)
		local payload = lastResult
		if not payload then
			return "", {}
		end
		local rows = {}
		if activeMode == "Race" then
			table.insert(rows, { Id = "fact1", Icon = "timer", Label = "FASTEST LAP", Value = "--", Kind = "Text" })
			table.insert(rows, { Id = "fact2", Icon = "gauge", Label = "HIGHEST SPEED", Value = "--", Kind = "Text" })
			return "RACE HIGHLIGHTS", rows
		end
		local laps = type(payload.LapTimes) == "table" and payload.LapTimes or {}
		count = math.max(1, count or #laps)
		local first = math.max(1, #laps - count + 1)
		for index = first, #laps do
			local lap = laps[index]
			if type(lap) == "table" then
				local best = tonumber(lap.Lap) == tonumber(payload.BestLapIndex)
				table.insert(rows, {
					Id = "fact" .. tostring(#rows + 1),
					Label = string.format("%02d", tonumber(lap.Lap) or index),
					Value = Model.TimeText(lap.Elapsed) .. (best and "  BEST" or ""),
					Kind = "Text",
				})
			end
		end
		return "SESSION LAPS", rows
	end

	-- The table: heading, column header, rows (windowed round the local player) and the empty-state message.
	-- Race: R176-187, from the last RacePositionUpdate, else the payload. Time trial: R138-142.
	function self.Table(count)
		local payload = lastResult
		local result = { Heading = "", Header = { "POS", "PLAYER", "TIME", "VEHICLE" }, Rows = {}, Message = "" }
		if not payload then
			return result
		end
		local source = {}
		local mine = nil
		if activeMode == "Race" then
			result.Heading = "RACE RESULTS"
			result.Header = { "POS", "PLAYER", "FINISH TIME", "VEHICLE" }
			local positions = lastPositions or payload.Positions or {}
			positions = type(positions) == "table" and positions or {}
			for index, entry in ipairs(positions) do
				if type(entry) == "table" then
					local you = tonumber(entry.UserId) == deps.UserId
					local elapsed = tonumber(entry.FinishElapsed) or (you and tonumber(payload.Elapsed))
					local finish = elapsed and Model.TimeText(elapsed) or (entry.Finished and "FINISHED" or "RACING")
					table.insert(source, { You = you, Columns = { tostring(entry.Place or index),
						string.upper(Model.FirstText(entry.Name, "PLAYER")), finish,
						string.upper(Model.FirstText(entry.VehicleName, entry.VehicleId, "--")) } })
					if you and not mine then
						mine = #source
					end
				end
			end
		else
			result.Heading = "GLOBAL TOP 20 — TIER " .. tostring(payload.VehicleTier or "--")
			if leaderboard.State == "Loading" then
				result.Message = "LOADING GLOBAL RANKINGS"
			elseif leaderboard.State == "Empty" then
				result.Message = "NO GLOBAL RECORDS YET"
			elseif leaderboard.State == "Unavailable" then
				result.Message = "GLOBAL RANKINGS UNAVAILABLE"
			end
			for index, entry in ipairs(leaderboard.Entries) do
				if type(entry) == "table" then
					local you = tonumber(entry.UserId) == deps.UserId
					table.insert(source, { You = you, Columns = { tostring(entry.Rank or index),
						string.upper(Model.FirstText(entry.DisplayName, entry.Username, "PLAYER")), Model.TimeText(entry.BestSeconds),
						string.upper(Model.FirstText(entry.VehicleName, entry.VehicleId, "--")) } })
					if you and not mine then
						mine = #source
					end
				end
			end
		end
		count = math.max(1, count or #source)
		local first = Model.WindowStart(#source, mine, count)
		for index = first, math.min(#source, first + count - 1) do
			local row = source[index]
			row.Key = "row" .. tostring(#result.Rows + 1)
			table.insert(result.Rows, row)
		end
		return result
	end

	function self.LeaderboardState()
		return leaderboard.State
	end

	return self
end

return Model
