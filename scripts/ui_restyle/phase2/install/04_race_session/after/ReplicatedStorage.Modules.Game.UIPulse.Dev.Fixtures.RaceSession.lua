-- Owns the gallery items of the RaceSession family (in-race HUD, countdown, queue banner, wrong-way prompt, results); canned state only: no real model, remote, bindable or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.RaceSession. Requires: Layers, Overlay, RaceSession.RaceHudView, ResultsView, CountdownClient, QueueClient (resolved on the first mount).

local cache
local function modules()
	if not cache then
		local pulse = script.Parent.Parent.Parent
		cache = {
			Layers = require(pulse.Kit.Layers),
			Overlay = require(pulse.Kit.Overlay),
			HudView = require(pulse.RaceSession.RaceHudView),
			ResultsView = require(pulse.RaceSession.ResultsView),
			Countdown = require(pulse.RaceSession.CountdownClient),
			Queue = require(pulse.RaceSession.QueueClient),
		}
	end
	return cache
end

local function copy(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

local function checkKeys(item, allowed, patch)
	assert(type(patch) == "table", item .. " fixture expects a table")
	for key in pairs(patch) do
		if not allowed[key] then
			error(string.format("%s fixture: unknown key '%s'", item, tostring(key)), 3)
		end
	end
end

local function keySet(list)
	local set = {}
	for _, key in ipairs(list) do
		set[key] = true
	end
	return set
end

-- The whole stage, whatever anchor the gallery mounted the item on: these items use the real slots.
local function stageOf(parent)
	return parent:FindFirstAncestor("Stage") or parent
end

-- A signal nobody fires: the fixture renders through Set.
local function quietSignal()
	local signal = {}
	function signal:Connect()
		local connection = {}
		function connection:Disconnect() end
		return connection
	end
	return signal
end

------------------------------------------------------------------------------------------------------------------------
-- In-race HUD
------------------------------------------------------------------------------------------------------------------------

local HUD_KEYS = keySet({ "Active", "Mode", "Place", "Suffix", "Participants", "Lap", "Target", "Tier", "Heading", "Timer",
	"DeltaLap", "DeltaSeconds", "PipsPassed", "PipsCount", "Rows", "ResetText", "ExitText", "Confirm", "ConfirmTitle",
	"MapImage", "Name" })

-- The getters RaceHudView calls, over a canned state table that Set may patch.
local function fakeHudModel(state)
	local model = { Changed = quietSignal() }
	function model.IsActive()
		return state.Active ~= false
	end
	function model.Mode()
		return state.Mode or "Race"
	end
	function model.Place()
		return state.Place
	end
	function model.PlaceSuffix()
		return state.Suffix or ""
	end
	function model.ParticipantCount()
		return state.Participants
	end
	function model.CurrentLap()
		return state.Lap or 1
	end
	function model.LapTargetText()
		return state.Target or "1"
	end
	function model.VehicleTier()
		return state.Tier
	end
	function model.TimerHeading()
		return state.Heading or (model.Mode() == "Race" and "RACE TIME" or "CURRENT LAP")
	end
	function model.TimerSeconds()
		return nil -- the fixture timer does not run: the text is the canned one
	end
	function model.TimerText()
		return state.Timer or "00:00.000"
	end
	function model.Delta()
		return state.DeltaSeconds and { Lap = state.DeltaLap, Seconds = state.DeltaSeconds } or nil
	end
	function model.DeltaText()
		return state.DeltaSeconds and string.format("LAP %s %+.3f", tostring(state.DeltaLap or ""), state.DeltaSeconds) or nil
	end
	function model.Pips()
		return state.PipsPassed or 0, state.PipsCount or 0
	end
	function model.BoardRows(count)
		local rows = {}
		for index, row in ipairs(state.Rows or {}) do
			if index > count then
				break
			end
			rows[index] = { Key = "row" .. tostring(index), Columns = row.Columns, You = row.You == true }
		end
		return rows
	end
	function model.ResetText()
		return state.ResetText or "RESET"
	end
	function model.ExitText()
		return state.ExitText or "EXIT"
	end
	function model.ConfirmOpen()
		return state.Confirm == true
	end
	function model.ConfirmTitle()
		return state.ConfirmTitle or (model.Mode() == "Race" and "EXIT RACE?" or "EXIT TIME TRIAL?")
	end
	function model.ConfirmBody()
		return "CURRENT PROGRESS WILL BE LOST."
	end
	function model.MapImage()
		return state.MapImage or ""
	end
	function model.MapOpacity()
		return 0.78
	end
	function model.MapMarkerScale()
		return 1
	end
	function model.MapStep()
		return false, 0, 0, 0
	end
	function model.DisplayName()
		return state.Name or ""
	end
	function model.RequestReset() end
	function model.RequestExit()
		state.Confirm = true
	end
	function model.CancelExit()
		state.Confirm = false
	end
	function model.ConfirmExit()
		state.Confirm = false
	end
	return model
end

local function mountHud(parent, props, scope, ctx)
	checkKeys("RaceSession.RaceHud", HUD_KEYS, props)
	local m = modules()
	local stage = stageOf(parent)
	local layer = m.Layers.Stage(stage, ctx, "Hud")
	local state = copy(props)
	local model = fakeHudModel(state)
	local view = m.HudView.Mount(layer, model, scope, { ConfirmHost = stage, NoPresence = true })
	local originalExit = model.RequestExit
	model.RequestExit = function()
		originalExit()
		view.Render("confirm")
	end
	view.Render("fixture")
	local component = { Instance = layer.Root }
	function component.Set(patch)
		checkKeys("RaceSession.RaceHud", HUD_KEYS, patch)
		for key, value in pairs(patch) do
			state[key] = value
		end
		view.Render("set")
	end
	local destroyed = false
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		view.Destroy()
		layer.Destroy()
	end
	return component
end

local RACE_ROWS = {
	{ Columns = { "1", "NEONRIDER" } },
	{ Columns = { "2", "OSCAR" }, You = true },
	{ Columns = { "3", "CYBERWAVE" } },
	{ Columns = { "4", "NIGHTDRIFT" } },
}
local LONG_ROWS = {
	{ Columns = { "11", "WWWWWWWWWWWWWWWWWWWW" } },
	{ Columns = { "12", "MMMMMMMMMMMMMMMMMMMM" }, You = true },
	{ Columns = { "13", "A_VERY_LONG_USERNAME" } },
	{ Columns = { "14", "ANOTHER_LONG_NAME_20" } },
}
local TRIAL_ROWS = {
	{ Columns = { "PB", "PERSONAL BEST", "01:03.275" } },
	{ Columns = { "01", "LAP 1", "01:04.611" } },
	{ Columns = { "02", "LAP 2", "01:02.863" } },
}

local hudItem = {
	Id = "RaceSession.RaceHud",
	Frame = "Hud",
	Slot = nil,
	States = {
		{ Id = "Race", Props = { Mode = "Race", Place = 2, Suffix = "ND", Participants = 6, Lap = 2, Target = "3",
			Timer = "01:03.275", DeltaLap = 1, DeltaSeconds = -0.412, PipsPassed = 7, PipsCount = 17, Rows = RACE_ROWS,
			Name = "SHIFTED CANAL SPRINT" } },
		{ Id = "RaceStagedNoPosition", Props = { Mode = "Race", Participants = 6, Lap = 1, Target = "3", Rows = {} } },
		{ Id = "RaceSlowerLap", Props = { Mode = "Race", Place = 1, Suffix = "ST", Participants = 2, Lap = 3, Target = "3",
			Timer = "03:11.842", DeltaLap = 2, DeltaSeconds = 1.208, PipsPassed = 17, PipsCount = 17, Rows = RACE_ROWS } },
		{ Id = "RaceLongest", Props = { Mode = "Race", Place = 12, Suffix = "TH", Participants = 16, Lap = 99, Target = "99",
			Timer = "99:59.999", DeltaLap = 98, DeltaSeconds = -59.999, PipsPassed = 31, PipsCount = 32, Rows = LONG_ROWS,
			ResetText = "RESET FAILED", ExitText = "EXIT FAILED", Name = "THE LONGEST EVENT NAME IN THE CATALOGUE" } },
		{ Id = "TimeTrial", Props = { Mode = "TimeTrial", Lap = 3, Target = "3", Tier = "C", Timer = "00:41.228", DeltaLap = 2,
			DeltaSeconds = -0.412, PipsPassed = 11, PipsCount = 17, Rows = TRIAL_ROWS, Name = "SHOWROOM LOOP" } },
		{ Id = "TimeTrialEndless", Props = { Mode = "TimeTrial", Lap = 14, Target = "∞", Tier = "S", Timer = "00:07.004",
			Rows = { TRIAL_ROWS[1] } } },
		{ Id = "TimeTrialNoBest", Props = { Mode = "TimeTrial", Lap = 1, Target = "1",
			Rows = { { Columns = { "PB", "PERSONAL BEST", "--:--.---" } } } } },
		{ Id = "ResetDone", Props = { Mode = "Race", Place = 3, Suffix = "RD", Participants = 6, Lap = 1, Target = "3",
			ResetText = "RESET DONE", Rows = RACE_ROWS } },
		{ Id = "ExitConfirmRace", Props = { Mode = "Race", Place = 2, Suffix = "ND", Participants = 6, Lap = 2, Target = "3",
			Rows = RACE_ROWS, Confirm = true } },
		{ Id = "ExitConfirmTimeTrial", Props = { Mode = "TimeTrial", Lap = 2, Target = "3", Tier = "C", Rows = TRIAL_ROWS,
			Confirm = true } },
		{ Id = "Hidden", Props = { Active = false } },
	},
	Mount = mountHud,
}

------------------------------------------------------------------------------------------------------------------------
-- Countdown
------------------------------------------------------------------------------------------------------------------------

local COUNTDOWN_KEYS = keySet({ "Visible", "Heading", "Text", "Go" })

local function mountCountdown(parent, props, scope, ctx)
	checkKeys("RaceSession.Countdown", COUNTDOWN_KEYS, props)
	local m = modules()
	local layer = m.Layers.Stage(stageOf(parent), ctx, "Hud")
	local state = copy(props)
	local view = m.Countdown._mountView(layer, scope)
	view.Render(state)
	local component = { Instance = layer.Root }
	function component.Set(patch)
		checkKeys("RaceSession.Countdown", COUNTDOWN_KEYS, patch)
		for key, value in pairs(patch) do
			state[key] = value
		end
		view.Render(state)
	end
	local destroyed = false
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		view.Destroy()
		layer.Destroy()
	end
	return component
end

local countdownItem = {
	Id = "RaceSession.Countdown",
	Frame = "Hud",
	Slot = nil,
	States = {
		{ Id = "Three", Props = { Visible = true, Heading = "GET READY", Text = "3", Go = false } },
		{ Id = "Five", Props = { Visible = true, Heading = "GET READY", Text = "5", Go = false } },
		{ Id = "Ten", Props = { Visible = true, Heading = "GET READY", Text = "10", Go = false } },
		{ Id = "Go", Props = { Visible = true, Heading = "", Text = "GO!", Go = true } },
		{ Id = "Hidden", Props = { Visible = false, Heading = "GET READY", Text = "5", Go = false } },
	},
	Mount = mountCountdown,
}

------------------------------------------------------------------------------------------------------------------------
-- Queue banner
------------------------------------------------------------------------------------------------------------------------

local QUEUE_KEYS = keySet({ "Visible", "Title", "Status", "Players", "Starts", "LeaveEnabled" })

local function mountQueue(parent, props, scope, ctx)
	checkKeys("RaceSession.QueueBanner", QUEUE_KEYS, props)
	local m = modules()
	local layer = m.Layers.Stage(stageOf(parent), ctx, "Hud")
	local state = copy(props)
	local view = m.Queue._mountView(layer, scope, {})
	view.Render(state)
	local component = { Instance = layer.Root }
	function component.Set(patch)
		checkKeys("RaceSession.QueueBanner", QUEUE_KEYS, patch)
		for key, value in pairs(patch) do
			state[key] = value
		end
		view.Render(state)
	end
	local destroyed = false
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		view.Destroy()
		layer.Destroy()
	end
	return component
end

local queueItem = {
	Id = "RaceSession.QueueBanner",
	Frame = "Hud",
	Slot = nil,
	States = {
		{ Id = "Joining", Props = { Visible = true, Title = "SHIFTED CANAL SPRINT", Status = "JOINING QUEUE", Players = "0 / 0",
			Starts = "0s", LeaveEnabled = true } },
		{ Id = "Waiting", Props = { Visible = true, Title = "SHIFTED CANAL SPRINT", Status = "WAITING FOR RACERS",
			Players = "1 / 6", Starts = "0s", LeaveEnabled = true } },
		{ Id = "Counting", Props = { Visible = true, Title = "SHIFTED CANAL SPRINT", Status = "STARTING SOON", Players = "2 / 6",
			Starts = "25s", LeaveEnabled = true } },
		{ Id = "Leaving", Props = { Visible = true, Title = "SHIFTED CANAL SPRINT", Status = "LEAVING QUEUE", Players = "2 / 6",
			Starts = "25s", LeaveEnabled = false } },
		{ Id = "Failed", Props = { Visible = true, Title = "RACE QUEUE", Status = "QUEUE FAILED", Players = "0 / 0", Starts = "0s",
			LeaveEnabled = true } },
		{ Id = "Longest", Props = { Visible = true, Title = "THE LONGEST EVENT NAME IN THE CATALOGUE",
			Status = "YOU NEED A TIER S VEHICLE TO JOIN THIS QUEUE", Players = "16 / 16", Starts = "120s", LeaveEnabled = true } },
		{ Id = "Hidden", Props = { Visible = false } },
	},
	Mount = mountQueue,
}

------------------------------------------------------------------------------------------------------------------------
-- Wrong-way prompt (the replaced span of the route-guide fork)
------------------------------------------------------------------------------------------------------------------------

local WRONG_KEYS = keySet({ "Visible" })

local function mountWrongWay(parent, props, scope, ctx)
	checkKeys("RaceSession.WrongWay", WRONG_KEYS, props)
	local m = modules()
	local layer = m.Layers.Stage(stageOf(parent), ctx, "Hud")
	local banner = m.Overlay.PromptBanner(layer.Slot("PromptStack"), { Name = "WrongWayPrompt", Action = "WRONG WAY" }, scope)
	banner.Instance.Visible = props.Visible ~= false
	local component = { Instance = layer.Root }
	function component.Set(patch)
		checkKeys("RaceSession.WrongWay", WRONG_KEYS, patch)
		if patch.Visible ~= nil then
			banner.Instance.Visible = patch.Visible == true
		end
	end
	local destroyed = false
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		banner.Destroy()
		layer.Destroy()
	end
	return component
end

local wrongWayItem = {
	Id = "RaceSession.WrongWay",
	Frame = "Hud",
	Slot = nil,
	States = {
		{ Id = "Shown", Props = { Visible = true } },
		{ Id = "Hidden", Props = { Visible = false } },
	},
	Mount = mountWrongWay,
}

------------------------------------------------------------------------------------------------------------------------
-- Results
------------------------------------------------------------------------------------------------------------------------

local RESULT_KEYS = keySet({ "Open", "Mode", "Title", "Sub", "Reward", "BestLap", "Xp", "Strip", "FactsHeading", "Facts",
	"Heading", "Header", "Rows", "Message", "Busy" })

local function fakeResultsModel(state)
	local model = { Changed = quietSignal() }
	function model.IsOpen()
		return state.Open ~= false
	end
	function model.Mode()
		return state.Mode or "Race"
	end
	function model.Busy()
		return state.Busy == true
	end
	function model.Title()
		return state.Title or (model.Mode() == "Race" and "RACE COMPLETE" or "TIME TRIAL COMPLETE")
	end
	function model.SubTitle()
		return state.Sub or ""
	end
	function model.RewardAmount()
		return state.Reward or 0
	end
	function model.BestLapText()
		return state.BestLap or "--:--.---"
	end
	function model.AgainText()
		return model.Mode() == "Race" and "RACE AGAIN" or "TRY AGAIN"
	end
	function model.ExitText()
		return "EXIT TO START"
	end
	function model.Xp()
		return state.Xp or { State = "Hidden" }
	end
	function model.Strip()
		return state.Strip or {}
	end
	function model.Facts(count)
		local rows = {}
		for index, row in ipairs(state.Facts or {}) do
			if index > count then
				break
			end
			rows[index] = { Id = "fact" .. tostring(index), Icon = row.Icon, Label = row.Label, Value = row.Value, Kind = "Text" }
		end
		return state.FactsHeading or "", rows
	end
	function model.Table(count)
		local rows = {}
		for index, row in ipairs(state.Rows or {}) do
			if index > count then
				break
			end
			rows[index] = { Key = "row" .. tostring(index), Columns = row.Columns, You = row.You == true }
		end
		return { Heading = state.Heading or "", Header = state.Header or { "POS", "PLAYER", "TIME", "VEHICLE" }, Rows = rows,
			Message = state.Message or "" }
	end
	function model.Exit() end
	function model.Again() end
	return model
end

local function mountResults(parent, props, scope, ctx)
	checkKeys("RaceSession.Results", RESULT_KEYS, props)
	local m = modules()
	local layer = m.Layers.Stage(stageOf(parent), ctx, "Menu")
	local state = copy(props)
	local view = m.ResultsView.Mount(layer, fakeResultsModel(state), scope, { NoPresence = true })
	view.Render("fixture")
	local component = { Instance = layer.Root }
	function component.Set(patch)
		checkKeys("RaceSession.Results", RESULT_KEYS, patch)
		for key, value in pairs(patch) do
			state[key] = value
		end
		view.Render("set")
	end
	local destroyed = false
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		view.Destroy()
		layer.Destroy()
	end
	return component
end

local RACE_HEADER = { "POS", "PLAYER", "FINISH TIME", "VEHICLE" }
local RACE_RESULT_ROWS = {
	{ Columns = { "1", "NEONRIDER", "3:10.018", "SERAPH" } },
	{ Columns = { "2", "OSCAR", "3:11.842", "SERAPH" }, You = true },
	{ Columns = { "3", "CYBERWAVE", "3:12.450", "ROSSO" } },
	{ Columns = { "4", "NIGHTDRIFT", "FINISHED", "AURORA" } },
	{ Columns = { "5", "VANTA", "RACING", "ENDURA" } },
	{ Columns = { "6", "MIRA_K", "RACING", "ZEPHYR" } },
}
local RACE_FACTS = {
	{ Icon = "timer", Label = "FASTEST LAP", Value = "--" },
	{ Icon = "gauge", Label = "HIGHEST SPEED", Value = "--" },
}
local RACE_STRIP = { { Label = "FINISH", Value = "2ND PLACE", Kind = "Text" }, { Label = "FINISH TIME", Value = "3:11.842", Kind = "Text" } }
local BOARD_ROWS = {
	{ Columns = { "5", "PULSEHEAD", "0:59.340", "AURORA" } },
	{ Columns = { "6", "VANTA", "1:00.027", "ENDURA" } },
	{ Columns = { "7", "OSCAR", "1:01.842", "AURORA" }, You = true },
	{ Columns = { "8", "LOWLIGHT", "1:02.618", "AURORA" } },
	{ Columns = { "9", "MIRA_K", "1:03.090", "ZEPHYR" } },
	{ Columns = { "10", "HALCYON", "1:03.777", "AURORA" } },
}
local LAP_FACTS = {
	{ Label = "01", Value = "1:04.611" },
	{ Label = "02", Value = "1:01.842  BEST" },
	{ Label = "03", Value = "1:02.905" },
}
local TRIAL_HEADING = "GLOBAL TOP 20 — TIER C"

local function race(extra)
	local props = { Mode = "Race", Sub = "SHIFTED CANAL SPRINT", Reward = 20000, Strip = RACE_STRIP, FactsHeading = "RACE HIGHLIGHTS",
		Facts = RACE_FACTS, Heading = "RACE RESULTS", Header = RACE_HEADER, Rows = RACE_RESULT_ROWS }
	for key, value in pairs(extra) do
		props[key] = value
	end
	return props
end

local function trial(extra)
	local props = { Mode = "TimeTrial", Sub = "SHOWROOM LOOP", Reward = 12500, BestLap = "1:01.842",
		Strip = { { Label = "", Value = "GOLD", Kind = "Text" }, { Label = "", Value = "NEW PERSONAL BEST", Kind = "Chip" } },
		FactsHeading = "SESSION LAPS", Facts = LAP_FACTS, Heading = TRIAL_HEADING, Rows = BOARD_ROWS }
	for key, value in pairs(extra) do
		props[key] = value
	end
	return props
end

local resultsItem = {
	Id = "RaceSession.Results",
	Frame = "Menu",
	Slot = nil,
	States = {
		{ Id = "RaceXp", Props = race({ Xp = { State = "Xp", Gain = 120 } }) },
		{ Id = "RaceXpPending", Props = race({ Xp = { State = "Pending" } }) },
		{ Id = "RaceNoXp", Props = race({ Xp = { State = "Hidden" } }) },
		{ Id = "RaceRankUp", Props = race({ Xp = { State = "Rank", Rank = 12, RankGain = 1 } }) },
		{ Id = "RaceNoReward", Props = race({ Reward = 0, Strip = { { Label = "FINISH", Value = "-- PLACE", Kind = "Text" },
			{ Label = "FINISH TIME", Value = "--:--.---", Kind = "Text" } }, Rows = {} }) },
		{ Id = "RaceExiting", Props = race({ Title = "EXITING...", Busy = true }) },
		{ Id = "RaceExitFailed", Props = race({ Title = "EXIT FAILED" }) },
		{ Id = "TimeTrialPersonalBest", Props = trial({ Xp = { State = "Xp", Gain = 80 } }) },
		{ Id = "TimeTrialFinished", Props = trial({ Strip = { { Label = "", Value = "FINISHED", Kind = "Text" } }, Reward = 0 }) },
		{ Id = "TimeTrialQuit", Props = trial({ Title = "TIME TRIAL ENDED", Strip = { { Label = "", Value = "FINISHED", Kind = "Text" } },
			Reward = 0, BestLap = "--:--.---", Facts = {} }) },
		{ Id = "TimeTrialLoadingBoard", Props = trial({ Rows = {}, Message = "LOADING GLOBAL RANKINGS" }) },
		{ Id = "TimeTrialEmptyBoard", Props = trial({ Rows = {}, Message = "NO GLOBAL RECORDS YET" }) },
		{ Id = "TimeTrialBoardUnavailable", Props = trial({ Rows = {}, Message = "GLOBAL RANKINGS UNAVAILABLE" }) },
		{ Id = "TimeTrialTryAgainBusy", Props = trial({ Busy = true }) },
		{ Id = "Longest", Props = race({ Title = "THE SERVER SAID SOMETHING VERY LONG ABOUT THIS EXIT",
			Sub = "THE LONGEST EVENT NAME IN THE CATALOGUE", Reward = 123456789, Xp = { State = "Xp", Gain = 9999999 },
			Strip = { { Label = "FINISH", Value = "16TH PLACE", Kind = "Text" }, { Label = "FINISH TIME", Value = "99:59.999", Kind = "Text" } },
			Rows = {
				{ Columns = { "15", "WWWWWWWWWWWWWWWWWWWW", "99:59.999", "A VERY LONG VEHICLE NAME" } },
				{ Columns = { "16", "MMMMMMMMMMMMMMMMMMMM", "99:59.999", "A VERY LONG VEHICLE NAME" }, You = true },
			} }) },
		{ Id = "Hidden", Props = { Open = false } },
	},
	Mount = mountResults,
}

return { hudItem, countdownItem, queueItem, wrongWayItem, resultsItem }
