-- Owns the in-race HUD state: the RaceEvent reducer, the reset and exit calls, the lap timer, pips, lap delta and route-map marker maths; no GuiObject, layout or frame binding.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.RaceHudModel. Requires: none (every handle arrives in deps).
--
-- Classic line references: S = ReplicatedStorage.Modules.Game.Racing.RaceSessionPresentationClient.
-- deps = {
--   Remotes = { RaceRequest, RaceQueueRequest },        RemoteFunctions (or fakes with :InvokeServer)
--   Bindable = (name) -> BindableEvent?,                "RaceTransitionRequest", "FreeRoamHudPresentationMode" (S162-163)
--   UserId = number,
--   MapConfig = (mode, eventId) -> table?,              raw HudMapCatalog values for the event (S48-75, S216-229), or nil
--   Subject = () -> BasePart?,                          the part the route-map marker follows (S55-65)
--   Clock = os.clock, Spawn = task.spawn, Delay = task.delay, Wait = task.wait }

local Model = {}

Model.FADE_SECONDS = 0.25 -- S191
Model.RESET_LABEL_SECONDS = 1.1 -- S195
Model.EXIT_LABEL_SECONDS = 1.2 -- S195
Model.FADE_IN_DELAY_SUCCESS = 0.3 -- S194
Model.FADE_IN_DELAY_FAILURE = 0.08 -- S194
Model.TIMER_MAX_SECONDS = 5999.999 -- the timer has nine cells: 99:59.999
Model.OWNER = "RaceSession" -- S164
Model.KEEP_TELEMETRY = true -- S164

-- A minimal Luau signal: Connect returns a connection with Disconnect, so Core.ConnectionScope can hold it.
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
	function signal:Fire(...)
		for _, connection in ipairs(table.clone(connections)) do
			if connection.Connected then
				connection.Handler(...)
			end
		end
	end
	return signal
end
Model._newSignal = newSignal

-- S28, copied exactly.
function Model.TimeText(seconds)
	seconds = tonumber(seconds)
	if not seconds or seconds < 0 then
		return "--:--.---"
	end
	local minutes = math.floor(seconds / 60)
	return string.format("%02d:%06.3f", minutes, seconds - minutes * 60)
end

-- The ordinal letters after a place number (the rule of the Classic results owner, line 158).
function Model.Ordinal(place)
	place = tonumber(place)
	return place == 1 and "ST" or place == 2 and "ND" or place == 3 and "RD" or "TH"
end

-- The first index of a window of `count` rows that holds row `index` near its middle. Pure.
function Model.WindowStart(total, index, count)
	if total <= count then
		return 1
	end
	if not index then
		return 1
	end
	local start = index - math.floor((count - 1) / 2)
	return math.clamp(start, 1, total - count + 1)
end

-- S216-229: the guards and derived values of one route-map session, from the raw config values. Pure.
function Model.PrepareMap(raw)
	if type(raw) ~= "table" then
		return { Enabled = false, Image = "", Opacity = 0.78 }
	end
	local imageWidth = math.max(1, tonumber(raw.ImageWidth) or 1024)
	local imageHeight = math.max(1, tonumber(raw.ImageHeight) or 1024)
	local radians = math.rad(tonumber(raw.RotationDegrees) or 0)
	local smoothing = tonumber(raw.Smoothing)
	return {
		Enabled = raw.Enabled == true,
		Anchor = raw.Anchor,
		ImageWidth = imageWidth,
		ImageHeight = imageHeight,
		StudsPerPixel = math.max(0.0001, tonumber(raw.StudsPerPixel) or 1),
		Cos = math.cos(radians),
		Sin = math.sin(radians),
		FlipX = raw.FlipX == true,
		FlipY = raw.FlipY == true,
		StartPixelX = tonumber(raw.StartPixelX) or imageWidth * 0.5,
		StartPixelY = tonumber(raw.StartPixelY) or imageHeight * 0.5,
		Clamp = raw.Clamp ~= false,
		Smoothing = math.max(0, smoothing or 12),
		MarkerRotationOffset = tonumber(raw.MarkerRotationOffset) or 0,
		PlayerMarkerScale = math.max(0.1, tonumber(raw.PlayerMarkerScale) or 1),
		Image = type(raw.Image) == "string" and raw.Image or "",
		Opacity = math.clamp(tonumber(raw.Opacity) or 0.78, 0, 1),
	}
end

-- S246-260: world position and look vector to a 0..1 point on the fitted image and a heading in degrees. Pure.
function Model.MapPoint(map, position, look, renderedX, renderedY)
	local anchor = map.Anchor
	local deltaX, deltaZ = position.X - anchor.X, position.Z - anchor.Z
	local mappedX = deltaX * map.Cos - deltaZ * map.Sin
	local mappedY = deltaX * map.Sin + deltaZ * map.Cos
	if map.FlipX then
		mappedX = -mappedX
	end
	if map.FlipY then
		mappedY = -mappedY
	end
	local x = (map.StartPixelX + mappedX / map.StudsPerPixel) / map.ImageWidth
	local y = (map.StartPixelY + mappedY / map.StudsPerPixel) / map.ImageHeight
	if renderedX > 0 and renderedY > 0 then
		local frameAspect = renderedX / renderedY
		local imageAspect = map.ImageWidth / map.ImageHeight
		if imageAspect > frameAspect then
			local heightFraction = frameAspect / imageAspect
			y = (1 - heightFraction) * 0.5 + y * heightFraction
		else
			local widthFraction = imageAspect / frameAspect
			x = (1 - widthFraction) * 0.5 + x * widthFraction
		end
	end
	if map.Clamp then
		x = math.clamp(x, 0, 1)
		y = math.clamp(y, 0, 1)
	end
	local lookX = look.X * map.Cos - look.Z * map.Sin
	local lookY = look.X * map.Sin + look.Z * map.Cos
	if map.FlipX then
		lookX = -lookX
	end
	if map.FlipY then
		lookY = -lookY
	end
	local heading = math.deg(math.atan2(lookX, -lookY)) + map.MarkerRotationOffset
	return x, y, heading
end

function Model.new(deps)
	assert(type(deps) == "table", "RaceHudModel.new needs deps")
	local self = {}
	local changed = newSignal()
	self.Changed = changed

	local active = nil -- S160
	local busy = false -- S188
	local endedRunId = nil
	local confirmOpen = false
	local confirmTitle = "EXIT RACE?" -- S179
	local resetText = "RESET" -- S166
	local exitText = "EXIT" -- S167
	local map = nil
	local markerX, markerY, markerHeading = nil, nil, nil

	local function fire(name, payload)
		local event = deps.Bindable(name)
		if event then
			event:Fire(payload)
		end
	end

	-- S77 and S193: the one remote call path of this owner. An untrusted reply becomes an empty table.
	local function call(remote, action, payload)
		local ok, result = pcall(function()
			return remote:InvokeServer(action, payload or {})
		end)
		return ok and type(result) == "table" and result or {}
	end

	-- S164.
	local function presentationMode(enabled)
		fire("FreeRoamHudPresentationMode", { Owner = Model.OWNER, Active = enabled == true, KeepTelemetry = Model.KEEP_TELEMETRY })
	end

	-- S189.
	local function transition(step, payload)
		payload = payload or {}
		payload.Step = step
		fire("RaceTransitionRequest", payload)
	end

	local function resetMarker() -- S209-211
		markerX, markerY, markerHeading = nil, nil, nil
	end

	local function prepareMap(mode, eventId) -- S216-231
		local ok, raw = pcall(deps.MapConfig, mode, eventId)
		map = Model.PrepareMap(ok and raw or nil)
		local found, subject = pcall(deps.Subject)
		map.Subject = found and subject or nil
		resetMarker()
	end

	local function gates(payload)
		active.NextGateIndex = tonumber(payload.NextGateIndex) or active.NextGateIndex
		active.GateCount = tonumber(payload.GateCount) or active.GateCount
	end

	-- S269, field for field; NextGateIndex, GateCount and DisplayName are read as well (API2 5.5: pips).
	local function show(payload, mode)
		active = active or {}
		active.Mode = mode
		active.RunId = payload.RunId
		active.EventId = payload.EventId
		active.VehicleTier = payload.VehicleTier or active.VehicleTier
		active.CurrentLap = tonumber(payload.CurrentLap) or active.CurrentLap or 1
		active.LapTarget = tonumber(payload.LapTarget) or active.LapTarget or 1
		active.ParticipantCount = tonumber(payload.ParticipantCount) or active.ParticipantCount or 1
		active.LapTimes = active.LapTimes or {}
		active.Positions = active.Positions or {}
		active.DisplayName = payload.DisplayName or active.DisplayName
		gates(payload)
		prepareMap(mode, active.EventId)
		presentationMode(true)
	end

	-- S270. The run that ended is remembered so a late payload of it cannot bring the HUD back (API2 5.5).
	local function hide()
		if active and active.RunId ~= nil then
			endedRunId = active.RunId
		end
		active = nil
		map = nil
		resetMarker()
		confirmOpen = false
		busy = false
		presentationMode(false)
		changed:Fire("hide")
	end

	-- A checkpoint or lap payload of the run that already ended, arriving with no session active.
	local function stale(payload)
		return active == nil and endedRunId ~= nil and payload.RunId ~= nil and payload.RunId == endedRunId
	end

	local function bestBefore(list, personalBest)
		local best = tonumber(personalBest)
		if best and best <= 0 then
			best = nil
		end
		for _, lap in ipairs(list) do
			local elapsed = type(lap) == "table" and tonumber(lap.Elapsed) or nil
			if elapsed and elapsed > 0 and (best == nil or elapsed < best) then
				best = elapsed
			end
		end
		return best
	end

	-- Lap against best lap only (programme contract 8): the lap just completed against the best lap known before it.
	local function setDelta(lap, seconds, reference)
		seconds = tonumber(seconds)
		if seconds and reference then
			active.Delta = { Lap = lap, Seconds = seconds - reference }
		else
			active.Delta = nil
		end
	end

	-- S271. Classic yields inside the event handler; here the HUD shows first and the best time fills in.
	local function queryPersonalBest()
		local run = active
		if not (run and run.Mode == "TimeTrial" and run.VehicleTier) then
			return
		end
		local result = call(deps.Remotes.RaceRequest, "GetTimeTrialPersonalBest", { EventId = run.EventId, VehicleTier = run.VehicleTier })
		if active ~= run then
			return
		end
		local record = type(result.Record) == "table" and result.Record or nil
		run.PersonalBest = tonumber(result.BestSeconds or (record and record.BestSeconds))
		changed:Fire("personalBest")
	end

	-- S190-196.
	local function invoke(kind)
		if busy or not active then
			return
		end
		busy = true
		confirmOpen = false
		changed:Fire("busy")
		transition("FadeOut", { Reason = kind, Label = kind == "Reset" and "RESETTING" or "EXITING" })
		deps.Wait(Model.FADE_SECONDS)
		local run = active
		if not run then
			-- The session ended during the fade. Classic errors here and leaves the fade up; this ends it.
			transition("RestoreCamera", { Reason = kind })
			transition("FadeIn", { Reason = kind, Delay = Model.FADE_IN_DELAY_FAILURE, Success = false })
			return
		end
		local remote = run.Mode == "Race" and deps.Remotes.RaceQueueRequest or deps.Remotes.RaceRequest
		local action = run.Mode == "Race" and (kind == "Reset" and "ResetToLastCheckpoint" or "ExitRaceToStart")
			or (kind == "Reset" and "ResetActiveTimeTrial" or "ExitActiveTimeTrial")
		local result = call(remote, action, { RunId = run.RunId, EventId = run.EventId })
		local success = result.Ok == true or result.Success == true
		transition("RestoreCamera", { Reason = kind })
		transition("FadeIn", { Reason = kind, Delay = success and Model.FADE_IN_DELAY_SUCCESS or Model.FADE_IN_DELAY_FAILURE, Success = success })
		if kind == "Reset" then
			resetText = success and "RESET DONE" or "RESET FAILED"
			changed:Fire("buttons")
			deps.Delay(Model.RESET_LABEL_SECONDS, function()
				resetText = "RESET"
				busy = false
				changed:Fire("buttons")
			end)
		elseif not success then
			exitText = "EXIT FAILED"
			changed:Fire("buttons")
			deps.Delay(Model.EXIT_LABEL_SECONDS, function()
				exitText = "EXIT"
				busy = false
				changed:Fire("buttons")
			end)
		end
	end

	-- S303-316: exactly the kinds the Classic owner handles.
	function self.Handle(payload)
		if type(payload) ~= "table" then
			return
		end
		local kind = tostring(payload.Type or "")
		if kind == "TimeTrialStaged" or kind == "TimeTrialCountdown" then
			endedRunId = nil
			show(payload, "TimeTrial")
			changed:Fire("show")
		elseif kind == "TimeTrialStarted" then
			endedRunId = nil
			show(payload, "TimeTrial")
			active.Running = true
			active.LapLocalStart = deps.Clock()
			changed:Fire("show")
			deps.Spawn(queryPersonalBest)
		elseif kind == "TimeTrialCheckpoint" then
			if stale(payload) then
				return
			end
			show(payload, "TimeTrial")
			changed:Fire("show")
		elseif kind == "TimeTrialLapCompleted" then
			if stale(payload) then
				return
			end
			show(payload, "TimeTrial")
			active.LapTimes = payload.LapTimes or active.LapTimes
			setDelta(payload.Lap, payload.Elapsed, bestBefore(active.LapTimes, active.PersonalBest))
			table.insert(active.LapTimes, { Lap = payload.Lap, Elapsed = payload.Elapsed })
			active.CurrentLap = payload.NextLap or payload.CurrentLap or active.CurrentLap
			active.LapLocalStart = deps.Clock()
			changed:Fire("lap")
		elseif kind == "TimeTrialReset" then
			if active then
				gates(payload)
			end
			changed:Fire("refresh")
		elseif kind == "RaceStaged" or kind == "RaceCountdown" then
			endedRunId = nil
			show(payload, "Race")
			changed:Fire("show")
		elseif kind == "RaceStarted" then
			endedRunId = nil
			show(payload, "Race")
			active.Running = true
			active.RaceLocalStart = deps.Clock()
			changed:Fire("show")
		elseif kind == "RaceCheckpoint" or kind == "RaceLapCompleted" then
			if stale(payload) then
				return
			end
			show(payload, "Race")
			if kind == "RaceLapCompleted" then
				active.RaceLaps = active.RaceLaps or {}
				setDelta(payload.Lap, payload.LapElapsed, bestBefore(active.RaceLaps, nil))
				table.insert(active.RaceLaps, { Lap = payload.Lap, Elapsed = payload.LapElapsed })
			end
			changed:Fire("show")
		elseif kind == "RacePositionUpdate" then
			-- The fix of API2 5.5: Classic shows the HUD here when none is active (S313), which brings it back
			-- after a finish or an exit. An update with no session, or for another run, is ignored. A payload or
			-- a session without a RunId cannot be told apart and is accepted while a session is active.
			if not active then
				return
			end
			if payload.RunId ~= nil and active.RunId ~= nil and payload.RunId ~= active.RunId then
				return
			end
			active.Place = payload.Place or active.Place
			active.ParticipantCount = payload.ParticipantCount or active.ParticipantCount
			active.CurrentLap = payload.CurrentLap or active.CurrentLap
			active.LapTarget = payload.LapTarget or active.LapTarget
			active.Positions = payload.Positions or active.Positions
			changed:Fire("positions")
		elseif kind == "TimeTrialFinished" or kind == "RaceFinished" or kind == "RaceEnded" then
			hide()
		elseif kind == "TimeTrialEnded" or kind == "TimeTrialError" or kind == "RaceExitedToStart" then
			hide()
		end
	end

	-- S197.
	function self.RequestReset()
		deps.Spawn(invoke, "Reset")
	end

	-- S198.
	function self.RequestExit()
		if not active then
			return
		end
		confirmTitle = active.Mode == "Race" and "EXIT RACE?" or "EXIT TIME TRIAL?"
		confirmOpen = true
		changed:Fire("confirm")
	end

	-- S199 (NO).
	function self.CancelExit()
		if not confirmOpen then
			return
		end
		confirmOpen = false
		changed:Fire("confirm")
	end

	-- S199 (YES).
	function self.ConfirmExit()
		confirmOpen = false
		changed:Fire("confirm")
		deps.Spawn(invoke, "Exit")
	end

	-- Called by the client when the seat or the character changes (replaces the throttled lookup of S240-244).
	function self.RefreshSubject()
		if map then
			local found, subject = pcall(deps.Subject)
			map.Subject = found and subject or nil
		end
	end

	function self.IsActive()
		return active ~= nil
	end
	function self.Mode()
		return active and active.Mode or nil
	end
	function self.RunId()
		return active and active.RunId or nil
	end
	function self.DisplayName()
		return active and active.DisplayName ~= nil and string.upper(tostring(active.DisplayName)) or ""
	end
	function self.VehicleTier()
		return active and active.VehicleTier ~= nil and tostring(active.VehicleTier) or nil
	end
	function self.Place()
		return active and tonumber(active.Place) or nil
	end
	-- The ordinal letters after the place; empty while no place is known.
	function self.PlaceSuffix()
		local place = active and tonumber(active.Place) or nil
		return place and Model.Ordinal(place) or ""
	end
	function self.ParticipantCount()
		return active and active.ParticipantCount or nil
	end
	function self.CurrentLap()
		return active and active.CurrentLap or 1
	end
	-- S300: an endless session shows the infinity sign.
	function self.LapTargetText()
		if not active then
			return "1"
		end
		return active.LapTarget == 0 and "∞" or tostring(active.LapTarget or 1)
	end
	function self.TimerHeading()
		return active and active.Mode == "Race" and "RACE TIME" or "CURRENT LAP"
	end
	-- S317: the client clock, from the arrival of the start (race) or of the last lap (time trial). nil = not running.
	function self.TimerSeconds()
		if not (active and active.Running) then
			return nil
		end
		local start = active.Mode == "TimeTrial" and active.LapLocalStart or active.RaceLocalStart
		if not start then
			return nil
		end
		return deps.Clock() - start
	end
	function self.TimerText()
		local seconds = self.TimerSeconds()
		return Model.TimeText(math.min(seconds or 0, Model.TIMER_MAX_SECONDS))
	end
	function self.PersonalBest()
		return active and active.PersonalBest or nil
	end
	-- { Lap, Seconds } of the last completed lap against the best lap before it; negative is faster.
	function self.Delta()
		return active and active.Delta or nil
	end
	function self.DeltaText()
		local delta = active and active.Delta
		if not delta then
			return nil
		end
		return string.format("LAP %s %+.3f", tostring(delta.Lap or ""), delta.Seconds)
	end
	-- Gates passed this lap and the gate count, from NextGateIndex and GateCount of the last payload.
	function self.Pips()
		local count = active and tonumber(active.GateCount) or nil
		if not count or count < 1 then
			return 0, 0
		end
		local passed = math.clamp((tonumber(active.NextGateIndex) or 1) - 1, 0, count)
		return passed, count
	end

	-- The board rows. Race: S285-295 (place and name, the local player marked), windowed round the player.
	-- Time trial: S272-283 (personal best, then the laps of this session), the last laps when they do not fit.
	function self.BoardRows(count)
		local rows = {}
		if not active then
			return rows
		end
		count = math.max(1, count or 4)
		if active.Mode == "Race" then
			local positions = type(active.Positions) == "table" and active.Positions or {}
			local mine = nil
			for index, entry in ipairs(positions) do
				if type(entry) == "table" and tonumber(entry.UserId) == deps.UserId then
					mine = index
					break
				end
			end
			local first = Model.WindowStart(#positions, mine, count)
			for index = first, math.min(#positions, first + count - 1) do
				local entry = positions[index]
				if type(entry) == "table" then
					table.insert(rows, {
						Key = "row" .. tostring(#rows + 1),
						Columns = { tostring(tonumber(entry.Place) or index), string.upper(tostring(entry.Name or "PLAYER")) },
						You = index == mine,
					})
				end
			end
		else
			table.insert(rows, { Key = "row1", Columns = { "PB", "BEST", Model.TimeText(active.PersonalBest) }, You = false })
			local laps = active.LapTimes
			local first = math.max(1, #laps - (count - 1) + 1)
			for index = first, #laps do
				local lap = laps[index]
				if type(lap) == "table" then
					table.insert(rows, {
						Key = "row" .. tostring(#rows + 1),
						Columns = { string.format("%02d", tonumber(lap.Lap) or index), "LAP " .. tostring(tonumber(lap.Lap) or index),
							Model.TimeText(lap.Elapsed) },
						You = false,
					})
				end
			end
		end
		return rows
	end

	function self.ResetText()
		return resetText
	end
	function self.ExitText()
		return exitText
	end
	function self.Busy()
		return busy
	end
	function self.ConfirmOpen()
		return confirmOpen
	end
	function self.ConfirmTitle()
		return confirmTitle
	end
	function self.ConfirmBody()
		return "CURRENT PROGRESS WILL BE LOST." -- S180
	end

	function self.MapImage()
		return map and map.Image or ""
	end
	function self.MapOpacity()
		return map and map.Opacity or 0.78
	end
	function self.MapMarkerScale()
		return map and map.PlayerMarkerScale or 1
	end
	-- S233-267, without a lookup: returns visible, x, y (0..1 of the image box) and the heading in degrees.
	function self.MapStep(dt, renderedX, renderedY)
		local state = map
		if not (active and state and state.Enabled and state.Anchor and state.Image ~= "") then
			resetMarker()
			return false, 0, 0, 0
		end
		local subject = state.Subject
		if not (subject and subject.Parent) then
			resetMarker()
			return false, 0, 0, 0
		end
		local x, y, heading = Model.MapPoint(state, subject.Position, subject.CFrame.LookVector, renderedX, renderedY)
		local alpha = state.Smoothing <= 0 and 1 or math.clamp((dt or 1 / 60) * state.Smoothing, 0, 1)
		if markerX == nil then
			markerX, markerY = x, y
		else
			markerX = markerX + (x - markerX) * alpha
			markerY = markerY + (y - markerY) * alpha
		end
		if markerHeading == nil then
			markerHeading = heading
		end
		local headingDelta = (heading - markerHeading + 180) % 360 - 180
		markerHeading = markerHeading + headingDelta * alpha
		return true, markerX, markerY, markerHeading
	end

	return self
end

return Model
