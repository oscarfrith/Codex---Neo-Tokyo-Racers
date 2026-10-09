-- Pure tests for RaceSession.ResultsModel: result payload fixtures (shapes from the Classic source and the audit,
-- section 0.4) replayed through the model with fake remotes, bindables, attributes and timers. No test crosses a real
-- time-trial finish: every result here is a table literal.
return function(M, _env)
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

	local function keys(payload)
		local list = {}
		for key in pairs(payload) do
			table.insert(list, key)
		end
		table.sort(list)
		return table.concat(list, ",")
	end

	local function harness()
		local log = { calls = {}, fires = {}, delays = {}, spawned = {}, replies = {}, reasons = {}, attributes = {}, listeners = {},
			order = {} }
		local function remote(name)
			local fake = {}
			function fake:InvokeServer(action, payload)
				table.insert(log.calls, { remote = name, action = action, payload = payload })
				table.insert(log.order, "call:" .. action)
				local reply = log.replies[action]
				if reply == "error" then
					error("remote failed")
				end
				return reply
			end
			return fake
		end
		local bindables = {}
		for _, name in ipairs({ "RaceTransitionRequest", "FreeRoamHudPresentationMode", "FreeRoamVehicleExited", "StartRaceQueueRequest" }) do
			local fake = {}
			function fake:Fire(payload)
				table.insert(log.fires, { name = name, payload = payload })
				table.insert(log.order, "fire:" .. name .. (type(payload) == "table" and payload.Step and (":" .. payload.Step) or ""))
			end
			bindables[name] = fake
		end
		local model = M.new({
			Remotes = { RaceRequest = remote("RaceRequest"), RaceQueueRequest = remote("RaceQueueRequest") },
			Bindable = function(name)
				if log.missing and log.missing[name] then
					return nil
				end
				return bindables[name]
			end,
			UserId = 42,
			GetAttribute = function(name)
				return log.attributes[name]
			end,
			OnAttribute = function(name, handler)
				local entry = { name = name, handler = handler, connected = true }
				table.insert(log.listeners, entry)
				return function()
					entry.connected = false
				end
			end,
			-- The leaderboard read is held so a test can decide when (and whether) it returns.
			Spawn = function(fn, ...)
				if log.holdSpawn then
					table.insert(log.spawned, { fn = fn, args = { ... } })
				else
					fn(...)
				end
			end,
			Delay = function(seconds, fn)
				table.insert(log.delays, { seconds = seconds, fn = fn })
			end,
		})
		model.Changed:Connect(function(reason)
			table.insert(log.reasons, reason)
		end)
		local function setAttribute(name, value)
			log.attributes[name] = value
			for _, entry in ipairs(log.listeners) do
				if entry.connected and entry.name == name then
					entry.handler()
				end
			end
		end
		local function fired(name)
			local list = {}
			for _, entry in ipairs(log.fires) do
				if entry.name == name then
					table.insert(list, entry.payload)
				end
			end
			return list
		end
		return model, log, setAttribute, fired
	end

	-- Payload fixtures: MatchmakingServer.finishEntry and TimeTrialServer.sendTimeTrialResult.
	local function raceFinished(place)
		return { Type = "RaceFinished", RunId = "r1", EventId = "canal", RouteId = "canal_route", DisplayName = "Shifted Canal Sprint",
			Place = place, ParticipantCount = 6, Elapsed = 191.842, GateCount = 17, NextGateIndex = 1, CurrentLap = 3,
			CompletedLapCount = 3, LapTarget = 3, LapTimes = { { Lap = 1, Elapsed = 64.1 } }, BestLapSeconds = 62.966, BestLapIndex = 2,
			RaceMedal = "Silver", RewardGranted = true, RewardAmount = 20000, RewardMessage = "ok", SelectedVehicleId = "seraph" }
	end
	local function racePositions()
		return { Type = "RacePositionUpdate", RunId = "r1", Place = 2, ParticipantCount = 3, Positions = {
			{ UserId = 1, Name = "NeonRider", Place = 1, Finished = true, FinishElapsed = 190.018, VehicleId = "seraph", VehicleName = "Seraph" },
			{ UserId = 42, Name = "Oscar", Place = 2, Finished = true, VehicleId = "seraph" },
			{ UserId = 3, Name = "Cyberwave", Place = 3, Finished = false, VehicleName = "Rosso" },
			{ UserId = 4, Place = 4, Finished = true },
		} }
	end
	local function trialFinished(overrides)
		local payload = { Type = "TimeTrialFinished", EventId = "loop", RouteId = "loop_route", DisplayName = "Showroom Loop", RunId = "t1",
			Elapsed = 189.358, GateCount = 12, VehicleTier = "C", VehicleIndex = 540, SelectedVehicleId = "aurora", Medal = "Gold",
			MedalRank = 2, NextMedalName = "Platinum", NextMedalSeconds = 58, PreviousBestSeconds = 63.275, PersonalBestSeconds = 61.842,
			IsPersonalBest = true, LapTimes = { { Lap = 1, Elapsed = 64.611 }, { Lap = 2, Elapsed = 61.842 }, { Lap = 3, Elapsed = 62.905 } },
			BestLapSeconds = 61.842, BestLapIndex = 2, CompletedLapCount = 3, CurrentLap = 3, LapTarget = 3, RouteType = "Circuit",
			FinishReason = "LapTarget", CanRetry = true, RewardGranted = true, RewardAmount = 12500, RewardCash = 12500 }
		for key, value in pairs(overrides or {}) do
			payload[key] = value
		end
		return payload
	end
	local function boardReply(count)
		local entries = {}
		for index = 1, count do
			entries[index] = { Rank = index, UserId = index == 7 and 42 or 1000 + index, DisplayName = "Player" .. index,
				BestSeconds = 59 + index * 0.4, VehicleName = "Aurora" }
		end
		return { Ok = true, Entries = entries }
	end

	case("TimeText and PlaceText: the Classic results formats", function()
		expect(M.TimeText(191.842) == "3:11.842", M.TimeText(191.842))
		expect(M.TimeText(61.842) == "1:01.842", M.TimeText(61.842))
		expect(M.TimeText(0) == "--:--.---" and M.TimeText(nil) == "--:--.---", "empty")
		expect(M.PlaceText(1) == "1ST PLACE" and M.PlaceText(2) == "2ND PLACE" and M.PlaceText(3) == "3RD PLACE", "podium")
		expect(M.PlaceText(4) == "4TH PLACE" and M.PlaceText(nil) == "-- PLACE", "others")
	end)

	case("race result: every value shown is a payload field", function()
		local model, log, _, fired = harness()
		expect(not model.IsOpen(), "closed before")
		model.Handle(raceFinished(2))
		expect(model.IsOpen() and model.Mode() == "Race", "open")
		expect(model.Title() == "RACE COMPLETE", model.Title())
		expect(model.SubTitle() == "SHIFTED CANAL SPRINT", model.SubTitle())
		expect(model.RewardAmount() == 20000, "RewardAmount, not computed")
		local strip = model.Strip()
		expect(#strip == 2 and strip[1].Value == "2ND PLACE" and strip[2].Value == "3:11.842", "place and finish time")
		expect(strip[2].Label == "FINISH TIME", "Classic label")
		expect(model.AgainText() == "RACE AGAIN" and model.ExitText() == "EXIT TO START", "buttons")
		local heading, facts = model.Facts(4)
		expect(heading == "RACE HIGHLIGHTS" and #facts == 2, "highlights")
		expect(facts[1].Label == "FASTEST LAP" and facts[1].Value == "--", "no payload fills it: Classic shows --")
		expect(facts[2].Label == "HIGHEST SPEED" and facts[2].Value == "--", "no payload fills it")
		expect(#log.calls == 0, "a race result sends no remote call")
		local mode = fired("FreeRoamHudPresentationMode")
		expect(#mode == 1 and mode[1].Owner == "RaceResults" and mode[1].Active == true and mode[1].KeepTelemetry == false, "owner")
		expect(keys(mode[1]) == "Active,KeepTelemetry,Owner", keys(mode[1]))
		expect(model.LeaderboardState() == "None", "no leaderboard in a race")
	end)

	case("race rows: from the last position update, else the payload; the Classic finish column", function()
		local model = harness()
		model.Handle(racePositions())
		expect(not model.IsOpen(), "a position update alone opens nothing")
		model.Handle(raceFinished(2))
		local board = model.Table(6)
		expect(board.Heading == "RACE RESULTS", board.Heading)
		expect(table.concat(board.Header, "|") == "POS|PLAYER|FINISH TIME|VEHICLE", "header")
		expect(#board.Rows == 4, "four racers")
		expect(table.concat(board.Rows[1].Columns, "|") == "1|NEONRIDER|3:10.018|SERAPH", table.concat(board.Rows[1].Columns, "|"))
		expect(table.concat(board.Rows[2].Columns, "|") == "2|OSCAR|3:11.842|SERAPH", "own time comes from the payload Elapsed")
		expect(board.Rows[2].You == true and board.Rows[1].You == false, "own row")
		expect(table.concat(board.Rows[3].Columns, "|") == "3|CYBERWAVE|RACING|ROSSO", "still racing")
		expect(table.concat(board.Rows[4].Columns, "|") == "4|PLAYER|FINISHED|--", "fallbacks")

		local later = racePositions()
		later.Positions[3].Finished = true
		later.Positions[3].FinishElapsed = 192.45
		model.Handle(later)
		expect(model.Table(6).Rows[3].Columns[3] == "3:12.450", "a later update fills in the row")

		local fresh = harness()
		local payload = raceFinished(1)
		payload.Positions = { { UserId = 42, Name = "Oscar", Place = 1 } }
		fresh.Handle(payload)
		expect(#fresh.Table(6).Rows == 1, "payload positions when no update was seen")
		local empty = harness()
		empty.Handle(raceFinished(1))
		expect(#empty.Table(6).Rows == 0, "no rows, no error")
	end)

	case("table window follows the local player", function()
		local model, log = harness()
		log.replies.GetTimeTrialLeaderboard = boardReply(20)
		model.Handle(trialFinished())
		local board = model.Table(6)
		expect(#board.Rows == 6, "six rows")
		expect(board.Rows[1].Columns[1] == "5" and board.Rows[6].Columns[1] == "10", "rows 5 to 10 round rank 7")
		expect(board.Rows[3].You == true, "own row marked")
		expect(board.Rows[1].Key == "row1" and board.Rows[6].Key == "row6", "stable keys for the pool")
		expect(#model.Table(20).Rows == 20, "the whole reply is available")
	end)

	case("time-trial result: fields as Classic reads them", function()
		local model, log = harness()
		log.replies.GetTimeTrialLeaderboard = boardReply(3)
		model.Handle(trialFinished())
		expect(model.Mode() == "TimeTrial" and model.Title() == "TIME TRIAL COMPLETE", model.Title())
		expect(model.SubTitle() == "SHOWROOM LOOP", model.SubTitle())
		expect(model.BestLapText() == "1:01.842", model.BestLapText())
		expect(model.RewardAmount() == 12500, "RewardAmount")
		local strip = model.Strip()
		expect(strip[1].Value == "GOLD" and strip[2].Value == "NEW PERSONAL BEST" and strip[2].Kind == "Chip", "medal and best chip")
		local heading, laps = model.Facts(4)
		expect(heading == "SESSION LAPS" and #laps == 3, "laps")
		expect(laps[1].Label == "01" and laps[1].Value == "1:04.611", "lap 1")
		expect(laps[2].Value == "1:01.842  BEST", "the best lap is marked from BestLapIndex")
		local _, last = model.Facts(2)
		expect(#last == 2 and last[1].Label == "02", "the last laps when they do not fit")
		expect(model.AgainText() == "TRY AGAIN", "button")
		local board = model.Table(6)
		expect(board.Heading == "GLOBAL TOP 20 — TIER C", board.Heading)
		expect(table.concat(board.Header, "|") == "POS|PLAYER|TIME|VEHICLE", "header")
		expect(table.concat(board.Rows[1].Columns, "|") == "1|PLAYER1|0:59.400|AURORA", table.concat(board.Rows[1].Columns, "|"))
	end)

	case("time-trial variants: quit, no medal, best lap falls back to Elapsed", function()
		local model = harness()
		model.Handle(trialFinished({ FinishReason = "Quit", Medal = false, IsPersonalBest = false, BestLapSeconds = false, RewardAmount = false }))
		expect(model.Title() == "TIME TRIAL ENDED", model.Title())
		local strip = model.Strip()
		expect(#strip == 1 and strip[1].Value == "FINISHED", "no medal reads FINISHED, no best chip")
		expect(model.BestLapText() == "3:09.358", "Elapsed when there is no best lap")
		expect(model.RewardAmount() == 0, "no reward is 0")
		local bare = harness()
		bare.Handle({ Type = "TimeTrialFinished" })
		expect(bare.SubTitle() == "TIME TRIAL" and bare.BestLapText() == "--:--.---", "an empty payload still draws")
		local _, laps = bare.Facts(4)
		expect(#laps == 0, "no laps")
	end)

	case("leaderboard: the Classic call; buttons do not wait for it; every reply state", function()
		local model, log = harness()
		log.holdSpawn = true
		model.Handle(trialFinished())
		expect(model.IsOpen() and model.AgainText() == "TRY AGAIN", "the result and its buttons are up before the call returns")
		expect(model.LeaderboardState() == "Loading" and model.Table(6).Message == "LOADING GLOBAL RANKINGS", "loading")
		expect(#log.calls == 0 and #log.spawned == 1, "the read runs in its own task")
		log.replies.GetTimeTrialLeaderboard = boardReply(2)
		log.spawned[1].fn(table.unpack(log.spawned[1].args))
		local call = log.calls[1]
		expect(call.remote == "RaceRequest" and call.action == "GetTimeTrialLeaderboard", call.remote .. "." .. call.action)
		expect(keys(call.payload) == "EventId,Limit,VehicleTier", keys(call.payload))
		expect(call.payload.EventId == "loop" and call.payload.VehicleTier == "C" and call.payload.Limit == 20, "values")
		expect(model.LeaderboardState() == "Rows" and #model.Table(6).Rows == 2 and model.Table(6).Message == "", "rows")

		for state, reply in pairs({ Empty = { Ok = true, Entries = {} }, Unavailable = { Ok = false }, }) do
			local other, otherLog = harness()
			otherLog.replies.GetTimeTrialLeaderboard = reply
			other.Handle(trialFinished())
			expect(other.LeaderboardState() == state, state)
			expect(other.Table(6).Message == (state == "Empty" and "NO GLOBAL RECORDS YET" or "GLOBAL RANKINGS UNAVAILABLE"), state .. " message")
		end
		for _, reply in ipairs({ "error", "text", 5 }) do
			local other, otherLog = harness()
			otherLog.replies.GetTimeTrialLeaderboard = reply
			other.Handle(trialFinished())
			expect(other.LeaderboardState() == "Unavailable" and other.IsOpen(), "a failed or untrusted reply is unavailable")
		end
		local odd, oddLog = harness()
		oddLog.replies.GetTimeTrialLeaderboard = { Ok = true, Entries = { "junk", { Rank = 2, Username = "u", BestSeconds = 60 } } }
		odd.Handle(trialFinished())
		expect(#odd.Table(6).Rows == 1 and odd.Table(6).Rows[1].Columns[2] == "U", "a row that is not a table is skipped")
	end)

	case("leaderboard: a late reply cannot draw into a newer result", function()
		local model, log = harness()
		log.holdSpawn = true
		model.Handle(trialFinished())
		model.Handle({ Type = "TimeTrialStaged", RunId = "t2" })
		expect(not model.IsOpen(), "hidden by the next session")
		log.replies.GetTimeTrialLeaderboard = boardReply(5)
		local before = #log.reasons
		log.spawned[1].fn(table.unpack(log.spawned[1].args))
		expect(#log.reasons == before, "the stale reply changes nothing")
		model.Handle(raceFinished(1))
		expect(model.LeaderboardState() == "None", "and the next result starts clean")
	end)

	case("time-trial EXIT TO START: Classic order, payloads and the driving exit", function()
		local model, log, _, fired = harness()
		log.replies.ExitFinishedTimeTrial = { Ok = true }
		model.Handle(trialFinished())
		log.calls, log.fires, log.order = {}, {}, {}
		model.Exit()
		expect(#log.calls == 1 and log.calls[1].remote == "RaceRequest" and log.calls[1].action == "ExitFinishedTimeTrial", "call")
		expect(next(log.calls[1].payload) == nil, "empty payload")
		expect(table.concat(log.order, " ") == "fire:RaceTransitionRequest:BeginLoading call:ExitFinishedTimeTrial "
			.. "fire:FreeRoamVehicleExited fire:FreeRoamHudPresentationMode fire:RaceTransitionRequest:CompleteLoading",
			table.concat(log.order, " "))
		local steps = fired("RaceTransitionRequest")
		expect(steps[1].Destination == "RaceStart" and steps[1].Status == "RETURNING TO START", "begin payload")
		expect(steps[2].Status == "READY", "complete payload")
		expect(not model.IsOpen(), "hidden")
		local mode = fired("FreeRoamHudPresentationMode")
		expect(mode[1].Active == false and mode[1].Owner == "RaceResults" and mode[1].KeepTelemetry == false, "owner released")
	end)

	case("time-trial exit failure: FailLoading with the reason, message as the title, still open", function()
		local model, log, _, fired = harness()
		log.replies.ExitFinishedTimeTrial = { Ok = false, Message = "Not finished" }
		model.Handle(trialFinished())
		log.fires = {}
		model.Exit()
		local steps = fired("RaceTransitionRequest")
		expect(steps[2].Step == "FailLoading" and steps[2].Status == "RETURNING" and steps[2].Reason == "Not finished", "fail payload")
		expect(model.Title() == "NOT FINISHED" and model.IsOpen() and not model.Busy(), model.Title())
		expect(#fired("FreeRoamVehicleExited") == 0, "no driving exit on failure")
		local silent, silentLog = harness()
		silentLog.replies.ExitFinishedTimeTrial = {}
		silent.Handle(trialFinished())
		silent.Exit()
		expect(silent.Title() == "EXIT FAILED", silent.Title())
	end)

	case("race EXIT TO START: RaceQueueRequest, and no driving exit", function()
		local model, log, _, fired = harness()
		log.replies.ExitRaceToStart = { Success = true }
		model.Handle(raceFinished(2))
		log.order = {}
		model.Exit()
		expect(log.calls[1].remote == "RaceQueueRequest" and log.calls[1].action == "ExitRaceToStart", "call")
		expect(next(log.calls[1].payload) == nil, "empty payload")
		expect(table.concat(log.order, " ") == "fire:RaceTransitionRequest:BeginLoading call:ExitRaceToStart "
			.. "fire:FreeRoamHudPresentationMode fire:RaceTransitionRequest:CompleteLoading", table.concat(log.order, " "))
		expect(#fired("FreeRoamVehicleExited") == 0, "Classic fires no driving exit for a race")
		expect(not model.IsOpen(), "hidden")
	end)

	case("exit shows EXITING... while the call is out and is never sent twice", function()
		local model, log = harness()
		local seen = nil
		local fake = {}
		function fake:InvokeServer(action)
			seen = { title = model.Title(), busy = model.Busy() }
			model.Exit() -- a second press while the first is out
			table.insert(log.calls, { action = action })
			return { Ok = false }
		end
		local guarded = M.new({
			Remotes = { RaceRequest = fake, RaceQueueRequest = fake },
			Bindable = function()
				return nil
			end,
			UserId = 42,
			GetAttribute = function()
				return nil
			end,
			OnAttribute = function()
				return function() end
			end,
			Spawn = function(fn, ...)
				fn(...)
			end,
			Delay = function() end,
		})
		model = guarded
		guarded.Handle(raceFinished(1))
		guarded.Exit()
		expect(seen and seen.title == "EXITING..." and seen.busy == true, "title and guard during the call")
		expect(#log.calls == 1, "one call")
	end)

	case("TRY AGAIN: StartStagedTimeTrial with the Classic keys; hides only on success", function()
		local model, log = harness()
		log.replies.StartStagedTimeTrial = { Ok = true }
		model.Handle(trialFinished())
		log.calls = {}
		model.Again()
		local call = log.calls[1]
		expect(call.remote == "RaceRequest" and call.action == "StartStagedTimeTrial", call.remote .. "." .. call.action)
		expect(keys(call.payload) == "EventId,LapCount,VehicleId", keys(call.payload))
		expect(call.payload.EventId == "loop" and call.payload.VehicleId == "aurora" and call.payload.LapCount == 3, "values")
		expect(not model.IsOpen(), "hidden on success")
		local failed, failedLog = harness()
		failedLog.replies.StartStagedTimeTrial = { Ok = false }
		failed.Handle(trialFinished())
		failed.Again()
		expect(failed.IsOpen() and not failed.Busy(), "still open on failure")
	end)

	case("RACE AGAIN: fires StartRaceQueueRequest from the two attributes, no remote", function()
		local model, log, _, fired = harness()
		log.attributes.LastRacingEventId = "canal"
		log.attributes.LastRacingVehicleId = "seraph"
		model.Handle(raceFinished(2))
		model.Again()
		local start = fired("StartRaceQueueRequest")
		expect(#start == 1 and keys(start[1]) == "DisplayName,EventId,VehicleId", "payload keys")
		expect(start[1].EventId == "canal" and start[1].VehicleId == "seraph" and start[1].DisplayName == "Shifted Canal Sprint", "values")
		expect(#log.calls == 0 and not model.IsOpen(), "no remote; hidden first")

		local noVehicle, noVehicleLog, _, noVehicleFired = harness()
		noVehicleLog.attributes.LastRacingEventId = "canal"
		noVehicle.Handle(raceFinished(2))
		noVehicle.Again()
		expect(#noVehicleFired("StartRaceQueueRequest") == 0 and noVehicle.IsOpen(), "no vehicle id: nothing fired, still open")

		local fallback, fallbackLog, _, fallbackFired = harness()
		fallbackLog.attributes.LastRacingVehicleId = "seraph"
		fallback.Handle(raceFinished(2))
		fallback.Again()
		expect(fallbackFired("StartRaceQueueRequest")[1].EventId == "canal", "event id falls back to the payload")

		local missing, missingLog = harness()
		missingLog.attributes.LastRacingEventId = "canal"
		missingLog.attributes.LastRacingVehicleId = "seraph"
		missingLog.missing = { StartRaceQueueRequest = true }
		missing.Handle(raceFinished(2))
		missing.Again()
		expect(missing.IsOpen(), "no bindable: still open, no error")
	end)

	case("hide kinds, and the owner is released on each", function()
		for _, kind in ipairs({ "TimeTrialEnded", "RaceStaged", "RaceStarted", "TimeTrialStaged", "TimeTrialStarted", "RaceExitedToStart" }) do
			local model, _, _, fired = harness()
			model.Handle(raceFinished(1))
			model.Handle({ Type = kind })
			expect(not model.IsOpen() and model.Mode() == nil, kind)
			local mode = fired("FreeRoamHudPresentationMode")
			expect(mode[#mode].Active == false, kind .. " releases the owner")
		end
		local model = harness()
		model.Handle(raceFinished(1))
		for _, kind in ipairs({ "RaceEnded", "RaceCheckpoint", "RaceDNF", "TimeTrialError", "QueueUpdate" }) do
			model.Handle({ Type = kind })
		end
		model.Handle("text")
		expect(model.IsOpen(), "kinds Classic does not handle leave the results up")
	end)

	case("driver XP: the change in XpIntoRank after the result", function()
		local model, log, setAttribute = harness()
		log.attributes.Rank = 4
		log.attributes.XpIntoRank = 300
		model.Handle(raceFinished(2))
		expect(model.Xp().State == "Pending", "pending until an attribute changes")
		expect(log.delays[1].seconds == 2, "two-second wait")
		setAttribute("XpIntoRank", 420)
		expect(model.Xp().State == "Xp" and model.Xp().Gain == 120, "gain is attribute after minus attribute at the result")
		log.delays[1].fn()
		expect(model.Xp().State == "Xp", "kept after the wait")
		setAttribute("XpIntoRank", 999)
		expect(model.Xp().Gain == 120, "changes after the wait are not attributed to this result")
	end)

	case("driver XP: a rank change shows the new rank; none within two seconds hides it", function()
		local model, log, setAttribute = harness()
		log.attributes.Rank = 4
		log.attributes.XpIntoRank = 950
		model.Handle(trialFinished())
		setAttribute("XpIntoRank", 30)
		setAttribute("Rank", 5)
		expect(model.Xp().State == "Rank" and model.Xp().Rank == 5 and model.Xp().RankGain == 1, "rank up")

		local quiet, quietLog = harness()
		quietLog.attributes.Rank = 4
		quietLog.attributes.XpIntoRank = 300
		quiet.Handle(raceFinished(2))
		quietLog.delays[1].fn()
		expect(quiet.Xp().State == "Hidden", "hidden when nothing arrives")

		local unknown, unknownLog, setUnknown = harness()
		unknown.Handle(raceFinished(2))
		setUnknown("XpIntoRank", 50)
		expect(unknown.Xp().State == "Pending", "no baseline attribute: nothing is invented")
		unknownLog.delays[1].fn()
		expect(unknown.Xp().State == "Hidden", "then hidden")
	end)

	case("driver XP: a hidden or replaced result stops listening", function()
		local model, log, setAttribute = harness()
		log.attributes.Rank = 4
		log.attributes.XpIntoRank = 300
		model.Handle(raceFinished(2))
		model.Handle({ Type = "RaceStaged" })
		local before = #log.reasons
		setAttribute("XpIntoRank", 420)
		log.delays[1].fn()
		expect(#log.reasons == before, "nothing after hide")
		for _, entry in ipairs(log.listeners) do
			expect(entry.connected == false, "listeners released")
		end
	end)

	return results
end
