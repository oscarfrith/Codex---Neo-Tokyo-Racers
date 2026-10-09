-- Pure tests for RaceSession.RaceHudModel: payload fixtures (shapes from the Classic source and the audit, section 0.4)
-- replayed through the model with fake remotes, bindables, clock and timers. Nothing yields; nothing is parented.
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

	local function near(a, b)
		return type(a) == "number" and math.abs(a - b) < 1e-6
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
		local log = { calls = {}, fires = {}, delays = {}, waits = {}, replies = {}, reasons = {} }
		local now = 100
		local function remote(name)
			local fake = {}
			function fake:InvokeServer(action, payload)
				table.insert(log.calls, { remote = name, action = action, payload = payload })
				local reply = log.replies[action]
				if reply == "error" then
					error("remote failed")
				end
				return reply
			end
			return fake
		end
		local function bindable(name)
			local fake = {}
			function fake:Fire(payload)
				table.insert(log.fires, { name = name, payload = payload })
			end
			return fake
		end
		local bindables = {
			RaceTransitionRequest = bindable("RaceTransitionRequest"),
			FreeRoamHudPresentationMode = bindable("FreeRoamHudPresentationMode"),
		}
		local model
		model = M.new({
			Remotes = { RaceRequest = remote("RaceRequest"), RaceQueueRequest = remote("RaceQueueRequest") },
			Bindable = function(name)
				return bindables[name]
			end,
			UserId = 42,
			MapConfig = function()
				return log.map
			end,
			Subject = function()
				return log.subject
			end,
			Clock = function()
				return now
			end,
			Spawn = function(fn, ...)
				fn(...)
			end,
			Delay = function(seconds, fn)
				table.insert(log.delays, { seconds = seconds, fn = fn })
			end,
			Wait = function(seconds)
				table.insert(log.waits, seconds)
				if log.duringWait then
					log.duringWait()
				end
			end,
		})
		model.Changed:Connect(function(reason)
			table.insert(log.reasons, reason)
		end)
		local function advance(seconds)
			now += seconds
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
		return model, log, advance, fired
	end

	-- Payload fixtures.
	local function raceStaged(run)
		return { Type = "RaceStaged", RunId = run, EventId = "canal", RouteId = "canal_route", DisplayName = "Shifted Canal Sprint",
			CurrentLap = 1, LapTarget = 3, ParticipantCount = 6, GateCount = 17, NextGateIndex = 1 }
	end
	local function raceStarted(run)
		return { Type = "RaceStarted", RunId = run, EventId = "canal", RouteId = "canal_route", DisplayName = "Shifted Canal Sprint",
			StartServerClock = 10, StartServerTime = 1000, GateCount = 17, NextGateIndex = 1, CurrentLap = 1, LapTarget = 3,
			ParticipantCount = 6 }
	end
	local function positions(run, place)
		return { Type = "RacePositionUpdate", RunId = run, Place = place, ParticipantCount = 6, CurrentLap = 2, CompletedLapCount = 1,
			LapTarget = 3, Positions = {
				{ UserId = 1, Name = "NeonRider", Place = 1 }, { UserId = 2, Name = "Vanta", Place = 2 },
				{ UserId = 3, Name = "Cyberwave", Place = 3 }, { UserId = 4, Name = "Nightdrift", Place = 4 },
				{ UserId = 42, Name = "Oscar", Place = 5 }, { UserId = 6, Name = "Mira_K", Place = 6 },
			} }
	end
	local function trialStarted(run)
		return { Type = "TimeTrialStarted", RunId = run, EventId = "loop", RouteId = "loop_route", DisplayName = "Showroom Loop",
			StartServerClock = 10, StartServerTime = 1000, GateCount = 12, NextGateIndex = 1, RouteType = "Circuit", LapTarget = 3,
			CurrentLap = 1, InfiniteLaps = false, VehicleTier = "C" }
	end
	local function trialLap(run, lap, elapsed)
		return { Type = "TimeTrialLapCompleted", RunId = run, EventId = "loop", Lap = lap, NextLap = lap + 1, LapTarget = 3,
			InfiniteLaps = false, Elapsed = elapsed, BestLapSeconds = elapsed, BestLapIndex = lap, GateCount = 12, NextGateIndex = 1 }
	end

	case("TimeText: the Classic format and the empty value", function()
		expect(M.TimeText(0) == "00:00.000", M.TimeText(0))
		expect(M.TimeText(63.275) == "01:03.275", M.TimeText(63.275))
		expect(M.TimeText(nil) == "--:--.---", "nil")
		expect(M.TimeText(-1) == "--:--.---", "negative")
		expect(M.TimeText("41.228") == "00:41.228", "string number")
	end)

	case("Ordinal and WindowStart", function()
		expect(M.Ordinal(1) == "ST" and M.Ordinal(2) == "ND" and M.Ordinal(3) == "RD" and M.Ordinal(4) == "TH", "ordinals")
		expect(M.Ordinal(11) == "TH", "Classic rule: only 1, 2 and 3 differ")
		expect(M.WindowStart(8, 5, 4) == 4, "middle")
		expect(M.WindowStart(8, 1, 4) == 1, "top")
		expect(M.WindowStart(8, 8, 4) == 5, "bottom")
		expect(M.WindowStart(3, 2, 4) == 1, "short list")
		expect(M.WindowStart(8, nil, 4) == 1, "player absent")
	end)

	case("race: staged shows the HUD and fires the presentation owner with KeepTelemetry true", function()
		local model, _, _, fired = harness()
		expect(not model.IsActive(), "inactive before")
		model.Handle(raceStaged("r1"))
		expect(model.IsActive() and model.Mode() == "Race", "active race")
		expect(model.RunId() == "r1", "run id")
		expect(model.CurrentLap() == 1 and model.LapTargetText() == "3", "lap")
		expect(model.ParticipantCount() == 6, "participants")
		expect(model.Place() == nil and model.PlaceSuffix() == "", "no place yet")
		local mode = fired("FreeRoamHudPresentationMode")
		expect(#mode == 1, "one presentation fire")
		expect(mode[1].Owner == "RaceSession" and mode[1].Active == true and mode[1].KeepTelemetry == true, "owner payload")
		expect(keys(mode[1]) == "Active,KeepTelemetry,Owner", keys(mode[1]))
		expect(model.TimerSeconds() == nil and model.TimerText() == "00:00.000", "timer not running")
		expect(model.TimerHeading() == "RACE TIME", "heading")
	end)

	case("race: timer from the client clock, pips from NextGateIndex and GateCount", function()
		local model, _, advance = harness()
		model.Handle(raceStaged("r1"))
		model.Handle(raceStarted("r1"))
		advance(63.275)
		expect(near(model.TimerSeconds(), 63.275), tostring(model.TimerSeconds()))
		expect(model.TimerText() == "01:03.275", model.TimerText())
		local passed, count = model.Pips()
		expect(passed == 0 and count == 17, "pips at the start")
		model.Handle({ Type = "RaceCheckpoint", RunId = "r1", EventId = "canal", NextGateIndex = 8, GateCount = 17, CheckpointIndex = 7,
			Elapsed = 20, LapElapsed = 20, CurrentLap = 1, LapTarget = 3 })
		passed, count = model.Pips()
		expect(passed == 7 and count == 17, "pips after seven gates")
		advance(10000)
		expect(model.TimerText() == "99:59.999", "timer text is capped at nine cells: " .. model.TimerText())
	end)

	case("race: position update gives place, suffix and a four-row window round the player", function()
		local model = harness()
		model.Handle(raceStarted("r1"))
		model.Handle(positions("r1", 5))
		expect(model.Place() == 5 and model.PlaceSuffix() == "TH", "place")
		expect(model.CurrentLap() == 2, "lap from the update")
		local rows = model.BoardRows(4)
		expect(#rows == 4, "four rows")
		expect(rows[1].Columns[1] == "3" and rows[4].Columns[1] == "6", rows[1].Columns[1] .. ".." .. rows[4].Columns[1])
		expect(rows[3].You == true and rows[3].Columns[2] == "OSCAR", "the player row is marked and upper case")
		expect(rows[1].You == false, "others are not")
		expect(rows[1].Key == "row1" and rows[4].Key == "row4", "stable keys")
		expect(#model.BoardRows(3) == 3, "compact window")
	end)

	case("fix: a position update with no session, or for another run, is ignored", function()
		local model, _, _, fired = harness()
		model.Handle(positions("r1", 2))
		expect(not model.IsActive(), "no session: HUD stays hidden (Classic showed it)")
		expect(#fired("FreeRoamHudPresentationMode") == 0, "nothing fired")
		model.Handle(raceStarted("r2"))
		model.Handle(positions("r1", 2))
		expect(model.Place() == nil, "another run is ignored")
		model.Handle(positions("r2", 4))
		expect(model.Place() == 4, "own run is taken")
	end)

	case("fix: the HUD does not return after finish, end or exit", function()
		for _, kind in ipairs({ "RaceFinished", "RaceEnded", "RaceExitedToStart" }) do
			local model, _, _, fired = harness()
			model.Handle(raceStarted("r1"))
			model.Handle({ Type = kind, RunId = "r1", EventId = "canal", Place = 2 })
			expect(not model.IsActive(), kind .. " hides")
			local mode = fired("FreeRoamHudPresentationMode")
			expect(mode[#mode].Active == false and mode[#mode].Owner == "RaceSession" and mode[#mode].KeepTelemetry == true,
				kind .. " releases the owner")
			model.Handle(positions("r1", 1))
			expect(not model.IsActive(), kind .. ": late position update")
			model.Handle({ Type = "RaceCheckpoint", RunId = "r1", NextGateIndex = 3, GateCount = 17 })
			expect(not model.IsActive(), kind .. ": late checkpoint of the ended run")
			model.Handle({ Type = "RaceLapCompleted", RunId = "r1", Lap = 1, LapElapsed = 60 })
			expect(not model.IsActive(), kind .. ": late lap of the ended run")
			model.Handle(raceStaged("r2"))
			expect(model.IsActive() and model.RunId() == "r2", kind .. ": a new run shows again")
		end
	end)

	case("time trial: hide kinds", function()
		for _, kind in ipairs({ "TimeTrialFinished", "TimeTrialEnded", "TimeTrialError" }) do
			local model = harness()
			model.Handle(trialStarted("t1"))
			expect(model.IsActive(), "active")
			model.Handle({ Type = kind, RunId = "t1" })
			expect(not model.IsActive(), kind)
			model.Handle({ Type = "TimeTrialCheckpoint", RunId = "t1", NextGateIndex = 2, GateCount = 12 })
			expect(not model.IsActive(), kind .. ": late checkpoint")
		end
	end)

	case("time trial: started asks for the personal best with the Classic action and keys", function()
		local model, log = harness()
		log.replies.GetTimeTrialPersonalBest = { BestSeconds = 63.275 }
		model.Handle(trialStarted("t1"))
		expect(#log.calls == 1, "one call")
		local call = log.calls[1]
		expect(call.remote == "RaceRequest" and call.action == "GetTimeTrialPersonalBest", call.remote .. "." .. call.action)
		expect(keys(call.payload) == "EventId,VehicleTier", keys(call.payload))
		expect(call.payload.EventId == "loop" and call.payload.VehicleTier == "C", "values")
		expect(near(model.PersonalBest(), 63.275), "best from BestSeconds")
		expect(model.TimerHeading() == "CURRENT LAP", "heading")
		expect(model.VehicleTier() == "C", "tier")

		local second, secondLog = harness()
		secondLog.replies.GetTimeTrialPersonalBest = { Record = { BestSeconds = 61.5 } }
		second.Handle(trialStarted("t1"))
		expect(near(second.PersonalBest(), 61.5), "best from Record.BestSeconds")

		local third, thirdLog = harness()
		thirdLog.replies.GetTimeTrialPersonalBest = "not a table"
		third.Handle(trialStarted("t1"))
		expect(third.PersonalBest() == nil and third.IsActive(), "an untrusted reply is no best, and no error")

		local fourth, fourthLog = harness()
		fourthLog.replies.GetTimeTrialPersonalBest = "error"
		fourth.Handle(trialStarted("t1"))
		expect(fourth.PersonalBest() == nil and fourth.IsActive(), "a failed call is no best, and no error")
	end)

	case("time trial: staged without a tier sends no personal-best call", function()
		local model, log = harness()
		model.Handle({ Type = "TimeTrialStaged", RunId = "t1", EventId = "loop", LapTarget = 3 })
		model.Handle({ Type = "TimeTrialStarted", RunId = "t1", EventId = "loop", LapTarget = 3 })
		expect(#log.calls == 0, "no VehicleTier, no call (Classic line 271)")
	end)

	case("time trial: laps, lap timer restart and the lap-against-best delta", function()
		local model, log, advance = harness()
		log.replies.GetTimeTrialPersonalBest = { BestSeconds = 63.275 }
		model.Handle(trialStarted("t1"))
		expect(model.Delta() == nil and model.DeltaText() == nil, "no delta before a lap")
		advance(64.611)
		expect(model.TimerText() == "01:04.611", model.TimerText())
		model.Handle(trialLap("t1", 1, 64.611))
		expect(model.CurrentLap() == 2, "next lap")
		expect(near(model.TimerSeconds(), 0), "lap timer restarts")
		expect(near(model.Delta().Seconds, 64.611 - 63.275) and model.Delta().Lap == 1, "lap 1 against the personal best")
		expect(model.DeltaText() == "LAP 1 +1.336", model.DeltaText())
		model.Handle(trialLap("t1", 2, 62.863))
		expect(near(model.Delta().Seconds, 62.863 - 63.275), "lap 2 against the best of best and lap 1")
		expect(model.DeltaText() == "LAP 2 -0.412", model.DeltaText())
		model.Handle(trialLap("t1", 3, 63.0))
		expect(near(model.Delta().Seconds, 63.0 - 62.863), "lap 3 against lap 2, now the best")
		local rows = model.BoardRows(4)
		expect(#rows == 4, "best row and three laps")
		expect(rows[1].Columns[2] == "BEST" and rows[1].Columns[3] == "01:03.275", "best row")
		expect(rows[2].Columns[1] == "01" and rows[2].Columns[3] == "01:04.611", "lap 1")
		expect(rows[4].Columns[1] == "03" and rows[4].Columns[3] == "01:03.000", "lap 3")
		local short = model.BoardRows(3)
		expect(#short == 3 and short[2].Columns[1] == "02" and short[3].Columns[1] == "03", "the last laps when they do not fit")
	end)

	case("time trial: first lap with no personal best has no delta", function()
		local model = harness()
		model.Handle(trialStarted("t1"))
		model.Handle(trialLap("t1", 1, 64.611))
		expect(model.Delta() == nil, "nothing to compare with")
		expect(model.BoardRows(4)[1].Columns[3] == "--:--.---", "no best time")
	end)

	case("time trial: endless laps show the infinity sign; reset keeps the session and takes the gate fields", function()
		local model, log = harness()
		model.Handle({ Type = "TimeTrialStarted", RunId = "t1", EventId = "loop", LapTarget = 0, CurrentLap = 1, GateCount = 12,
			NextGateIndex = 1 })
		expect(model.LapTargetText() == "∞", model.LapTargetText())
		model.Handle({ Type = "TimeTrialCheckpoint", RunId = "t1", EventId = "loop", NextGateIndex = 6, GateCount = 12, LapTarget = 0 })
		local passed = model.Pips()
		expect(passed == 5, "five gates")
		model.Handle({ Type = "TimeTrialReset", RunId = "t1", NextGateIndex = 1, GateCount = 12 })
		expect(model.IsActive(), "still active")
		passed = model.Pips()
		expect(passed == 0, "pips follow the reset payload")
		expect(log.reasons[#log.reasons] == "refresh", "refresh")
		local idle = harness()
		idle.Handle({ Type = "TimeTrialReset", RunId = "t1" })
		expect(not idle.IsActive(), "a reset with no session shows nothing (Classic line 309)")
	end)

	case("race: lap delta from LapElapsed against the earlier race laps", function()
		local model = harness()
		model.Handle(raceStarted("r1"))
		model.Handle({ Type = "RaceLapCompleted", RunId = "r1", EventId = "canal", Lap = 1, CurrentLap = 2, LapTarget = 3,
			LapElapsed = 62.9, NextGateIndex = 1, GateCount = 17 })
		expect(model.Delta() == nil, "first lap: nothing to compare")
		model.Handle({ Type = "RaceLapCompleted", RunId = "r1", EventId = "canal", Lap = 2, CurrentLap = 3, LapTarget = 3,
			LapElapsed = 62.5, NextGateIndex = 1, GateCount = 17 })
		expect(near(model.Delta().Seconds, -0.4), "second lap against the first")
		expect(model.CurrentLap() == 3, "lap from the payload")
	end)

	case("reset in a race: Classic remote, action, payload keys, transition steps and labels", function()
		local model, log, _, fired = harness()
		log.replies.ResetToLastCheckpoint = { Ok = true }
		model.Handle(raceStarted("r1"))
		model.RequestReset()
		expect(#log.calls == 1, "one call")
		local call = log.calls[1]
		expect(call.remote == "RaceQueueRequest" and call.action == "ResetToLastCheckpoint", call.remote .. "." .. call.action)
		expect(keys(call.payload) == "EventId,RunId" and call.payload.RunId == "r1" and call.payload.EventId == "canal", "payload")
		expect(#log.waits == 1 and log.waits[1] == 0.25, "0.25 s fade")
		local steps = fired("RaceTransitionRequest")
		expect(#steps == 3, "three steps")
		expect(steps[1].Step == "FadeOut" and steps[1].Reason == "Reset" and steps[1].Label == "RESETTING", "fade out")
		expect(steps[2].Step == "RestoreCamera" and steps[2].Reason == "Reset", "restore camera")
		expect(steps[3].Step == "FadeIn" and steps[3].Reason == "Reset" and steps[3].Delay == 0.3 and steps[3].Success == true, "fade in")
		expect(model.ResetText() == "RESET DONE" and model.Busy(), "label and guard")
		model.RequestReset()
		expect(#log.calls == 1, "busy: no second call")
		expect(#log.delays == 1 and log.delays[1].seconds == 1.1, "label timer")
		log.delays[1].fn()
		expect(model.ResetText() == "RESET" and not model.Busy(), "label restored")
	end)

	case("reset failure and an untrusted reply", function()
		local model, log, _, fired = harness()
		log.replies.ResetToLastCheckpoint = "nonsense"
		model.Handle(raceStarted("r1"))
		model.RequestReset()
		local steps = fired("RaceTransitionRequest")
		expect(steps[3].Delay == 0.08 and steps[3].Success == false, "failed fade in")
		expect(model.ResetText() == "RESET FAILED", model.ResetText())
	end)

	case("time trial reset and exit use RaceRequest with the Classic actions", function()
		local model, log = harness()
		log.replies.ResetActiveTimeTrial = { Success = true }
		log.replies.ExitActiveTimeTrial = { Ok = true }
		model.Handle(trialStarted("t1"))
		log.calls = {}
		model.RequestReset()
		expect(log.calls[1].remote == "RaceRequest" and log.calls[1].action == "ResetActiveTimeTrial", "reset")
		expect(keys(log.calls[1].payload) == "EventId,RunId", "reset keys")
		log.delays[1].fn()
		model.RequestExit()
		expect(model.ConfirmOpen() and model.ConfirmTitle() == "EXIT TIME TRIAL?", "confirmation title")
		model.ConfirmExit()
		expect(log.calls[2].remote == "RaceRequest" and log.calls[2].action == "ExitActiveTimeTrial", "exit")
		expect(keys(log.calls[2].payload) == "EventId,RunId", "exit keys")
	end)

	case("exit confirmation: cancel sends nothing, confirm sends ExitRaceToStart once", function()
		local model, log, _, fired = harness()
		log.replies.ExitRaceToStart = { Ok = true }
		model.RequestExit()
		expect(not model.ConfirmOpen(), "no session: no confirmation")
		model.Handle(raceStarted("r1"))
		model.RequestExit()
		expect(model.ConfirmOpen(), "open")
		expect(model.ConfirmTitle() == "EXIT RACE?" and model.ConfirmBody() == "CURRENT PROGRESS WILL BE LOST.", "Classic strings")
		model.CancelExit()
		expect(not model.ConfirmOpen() and #log.calls == 0, "cancel: closed, nothing sent")
		model.RequestExit()
		model.ConfirmExit()
		expect(not model.ConfirmOpen(), "closed")
		expect(#log.calls == 1 and log.calls[1].remote == "RaceQueueRequest" and log.calls[1].action == "ExitRaceToStart", "exit call")
		expect(keys(log.calls[1].payload) == "EventId,RunId", "exit keys")
		local steps = fired("RaceTransitionRequest")
		expect(steps[1].Label == "EXITING" and steps[1].Reason == "Exit", "fade label")
		expect(model.Busy(), "busy until the server ends the session (Classic)")
		model.ConfirmExit()
		expect(#log.calls == 1, "never sent twice")
		model.Handle({ Type = "RaceExitedToStart", RunId = "r1" })
		expect(not model.IsActive() and not model.Busy(), "hidden, guard released")
	end)

	case("exit failure: label, timer, guard released", function()
		local model, log = harness()
		log.replies.ExitRaceToStart = { Ok = false, Message = "no" }
		model.Handle(raceStarted("r1"))
		model.RequestExit()
		model.ConfirmExit()
		expect(model.ExitText() == "EXIT FAILED" and model.IsActive(), "failed, still racing")
		expect(log.delays[1].seconds == 1.2, "label timer")
		log.delays[1].fn()
		expect(model.ExitText() == "EXIT" and not model.Busy(), "restored")
	end)

	case("a session that ends during the fade sends no call and ends the fade", function()
		local model, log, _, fired = harness()
		model.Handle(raceStarted("r1"))
		log.duringWait = function()
			log.duringWait = nil
			model.Handle({ Type = "RaceEnded", RunId = "r1" })
		end
		model.RequestReset()
		expect(#log.calls == 0, "no call for a session that is gone")
		local steps = fired("RaceTransitionRequest")
		expect(steps[#steps].Step == "FadeIn" and steps[#steps].Success == false, "the fade is ended")
		expect(not model.IsActive(), "hidden")
	end)

	case("hide clears the confirmation; bad payloads are ignored", function()
		local model, log = harness()
		model.Handle(raceStarted("r1"))
		model.RequestExit()
		model.Handle({ Type = "RaceFinished", RunId = "r1" })
		expect(not model.ConfirmOpen(), "confirmation closed with the HUD")
		local before = #log.reasons
		model.Handle(nil)
		model.Handle("RaceStarted")
		model.Handle({ Type = "SomethingElse" })
		model.Handle({})
		expect(#log.reasons == before and not model.IsActive(), "ignored")
	end)

	case("dead Classic kinds still behave as Classic (TimeTrialCountdown, RaceCountdown)", function()
		local model = harness()
		model.Handle({ Type = "RaceCountdown", RunId = "r1", EventId = "canal" })
		expect(model.IsActive() and model.Mode() == "Race", "race")
		model.Handle({ Type = "RaceEnded", RunId = "r1" })
		model.Handle({ Type = "TimeTrialCountdown", RunId = "t1", EventId = "loop" })
		expect(model.IsActive() and model.Mode() == "TimeTrial", "time trial")
	end)

	case("route map: guards, projection and the marker step", function()
		local empty = M.PrepareMap(nil)
		expect(empty.Enabled == false and empty.Image == "", "no config: disabled")
		local map = M.PrepareMap({ Enabled = true, Anchor = Vector3.new(100, 0, 200), ImageWidth = 1000, ImageHeight = 500,
			StudsPerPixel = 2, Image = "map", Smoothing = 0 })
		expect(map.StartPixelX == 500 and map.StartPixelY == 250, "start pixel defaults to the image centre")
		local x, y, heading = M.MapPoint(map, Vector3.new(100, 0, 200), Vector3.new(0, 0, -1), 0, 0)
		expect(near(x, 0.5) and near(y, 0.5), "the anchor maps to the start pixel")
		expect(near(heading, 0), "looking along -Z is heading 0")
		x, y = M.MapPoint(map, Vector3.new(300, 0, 200), Vector3.new(1, 0, 0), 0, 0)
		expect(near(x, 0.6) and near(y, 0.5), "200 studs east is 100 px of 1000")
		x, y = M.MapPoint(map, Vector3.new(100000, 0, 200), Vector3.new(1, 0, 0), 0, 0)
		expect(near(x, 1), "clamped to the image")
		x, y = M.MapPoint(map, Vector3.new(100, 0, 200), Vector3.new(1, 0, 0), 300, 300)
		expect(near(x, 0.5) and near(y, 0.5), "letterboxed image keeps the centre")

		local model, log = harness()
		log.map = { Enabled = true, Anchor = Vector3.new(100, 0, 200), ImageWidth = 1000, ImageHeight = 500, StudsPerPixel = 2,
			Image = "map", Smoothing = 0, PlayerMarkerScale = 2 }
		log.subject = { Parent = true, Position = Vector3.new(300, 0, 200), CFrame = CFrame.new(300, 0, 200) }
		model.Handle(raceStarted("r1"))
		expect(model.MapImage() == "map" and model.MapMarkerScale() == 2, "image and scale")
		local visible, markerX, markerY = model.MapStep(1 / 60, 0, 0)
		expect(visible and near(markerX, 0.6) and near(markerY, 0.5), "marker follows the subject")
		log.subject.Parent = nil
		visible = model.MapStep(1 / 60, 0, 0)
		expect(visible == false, "a subject that left the world hides the marker")
		log.subject = { Parent = true, Position = Vector3.new(100, 0, 200), CFrame = CFrame.new(100, 0, 200) }
		model.RefreshSubject()
		visible, markerX = model.MapStep(1 / 60, 0, 0)
		expect(visible and near(markerX, 0.5), "RefreshSubject takes the new subject")
		model.Handle({ Type = "RaceEnded", RunId = "r1" })
		visible = model.MapStep(1 / 60, 0, 0)
		expect(visible == false and model.MapImage() == "", "no session: no marker, no image")

		local plain, plainLog = harness()
		plainLog.map = { Enabled = false, Image = "map" }
		plain.Handle(raceStarted("r1"))
		expect(plain.MapStep(1 / 60, 0, 0) == false, "disabled map: no marker")
	end)

	return results
end
