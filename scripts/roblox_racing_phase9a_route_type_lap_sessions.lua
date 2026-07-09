-- NTR Racing Phase 9A - Route Type + Time Trial Lap Sessions
--
-- Adds the first Gran Turismo-style time-trial session layer:
--   * RouteType = "Circuit" | "PointToPoint" route attribute support.
--   * Time-trial lap choice: 1-10 plus Infinite from the race entry menu.
--   * Circuit time trials loop after the finish line and track best lap.
--   * Rewards are granted once from the best session lap/result, never per lap.
--   * Quit with at least one completed lap shows the best medal/prize summary.
--
-- Scope guard:
--   * Does not edit Config.Racing.Rewards.
--   * Does not edit Config.Racing.RouteGuide.
--   * Does not edit the register-limited main client bootstrap.
--   * Preserves Phase 8H respawn reset if it is installed.

local MODE = "INSTALL" -- INSTALL or SMOKE

local function info(message)
	print("[NTR Racing Phase 9A] " .. tostring(message))
end

local function fail(message)
	error("[NTR Racing Phase 9A] " .. tostring(message), 2)
end

local function replaceFunctionBefore(source, functionName, nextFunctionName, replacement)
	local functionPrefix = string.find(functionName, ".", 1, true) and "function " or "local function "
	local nextPrefix = string.find(nextFunctionName, ".", 1, true) and "function " or "local function "
	local needle = functionPrefix .. functionName .. "("
	local startIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find function " .. functionName .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, needle, startIndex + 1, true)
	if second then
		fail("Function " .. functionName .. " matched more than once. Refusing ambiguous replacement.")
	end
	local nextNeedle = "\n" .. nextPrefix .. nextFunctionName .. "("
	local nextIndex = string.find(source, nextNeedle, startIndex + 1, true)
	if not nextIndex then
		fail("Could not find boundary function " .. nextFunctionName .. " after " .. functionName .. ".")
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, nextIndex)
end

local function replacePlain(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. tostring(label) .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, oldText, endIndex + 1, true)
	if second then
		fail("Source anchor matched more than once: " .. tostring(label) .. ". Refusing ambiguous replacement.")
	end
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
end

local function insertBefore(source, marker, insertText, label)
	local index = string.find(source, marker, 1, true)
	if not index then
		fail("Could not find insert anchor: " .. tostring(label) .. ".")
	end
	return string.sub(source, 1, index - 1) .. insertText .. string.sub(source, index)
end

local function kit()
	return game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers")
end

local function racingModulesFolder()
	return kit():WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Racing")
end

local function serverRacingFolder()
	local root = game:GetService("ServerScriptService"):FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	return services and services:FindFirstChild("Racing")
end

local function clientRacingFolder()
	local starterScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	local clientRoot = starterScripts and starterScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	return controllers and controllers:FindFirstChild("Racing")
end

local function racingConfig()
	return kit():WaitForChild("Config"):WaitForChild("Racing")
end

local function ensureRouteAndEventAttributes()
	local world = game:GetService("Workspace"):FindFirstChild("NeoTokyoRacersWorld")
	local routes = world and world:FindFirstChild("RaceRoutes")
	for _, route in ipairs(routes and routes:GetChildren() or {}) do
		if route:GetAttribute("RouteType") == nil then
			route:SetAttribute("RouteType", "Circuit")
		end
	end

	local catalog = racingConfig():FindFirstChild("TimeTrialCatalog")
	for _, event in ipairs(catalog and catalog:GetChildren() or {}) do
		if event:GetAttribute("DefaultLapCount") == nil then event:SetAttribute("DefaultLapCount", 1) end
		if event:GetAttribute("MinLapCount") == nil then event:SetAttribute("MinLapCount", 1) end
		if event:GetAttribute("MaxLapCount") == nil then event:SetAttribute("MaxLapCount", 10) end
		if event:GetAttribute("AllowInfiniteLaps") == nil then event:SetAttribute("AllowInfiniteLaps", true) end
	end
	info("Seeded RouteType and lap-selection attributes where missing.")
end

local CONFIG_READER_SUMMARY = [==[function Reader.GetEventSummary(eventId, mode)
	local event, eventError = Reader.GetEvent(mode or "TimeTrial", eventId)
	if not event then
		return nil, eventError
	end
	local routeId = stringAttribute(event, "RouteId", "")
	local route = routeId ~= "" and RouteDefinition.GetRouteDefinition(routeId) or nil
	local media = route and route.Media or {}
	local defaultLapCount = numberAttribute(event, "DefaultLapCount", numberAttribute(event, "Laps", 1))
	local minLapCount = numberAttribute(event, "MinLapCount", 1)
	local maxLapCount = numberAttribute(event, "MaxLapCount", 10)
	if maxLapCount < minLapCount then
		maxLapCount = minLapCount
	end
	return {
		EventId = stringAttribute(event, "EventId", tostring(eventId)),
		DisplayName = stringAttribute(event, "DisplayName", event.Name),
		Mode = stringAttribute(event, "Mode", mode or "TimeTrial"),
		RouteId = routeId,
		RouteDisplayName = route and route.DisplayName or routeId,
		RouteType = route and route.RouteType or stringAttribute(event, "RouteType", "Circuit"),
		AllowedVehicleTiers = stringAttribute(event, "AllowedVehicleTiers", "E,D,C,B,A,S"),
		RecommendedTier = stringAttribute(event, "RecommendedTier", "D"),
		BaseReward = numberAttribute(event, "BaseReward", 0),
		Laps = defaultLapCount,
		DefaultLapCount = defaultLapCount,
		MinLapCount = minLapCount,
		MaxLapCount = maxLapCount,
		AllowInfiniteLaps = event:GetAttribute("AllowInfiniteLaps") ~= false,
		MinPlayers = numberAttribute(event, "MinPlayers", 1),
		MaxPlayers = numberAttribute(event, "MaxPlayers", 1),
		TrackImage = stringAttribute(event, "TrackImage", media.TrackImage or ""),
		MapImage = stringAttribute(event, "MapImage", media.MapImage or ""),
		CheckpointCount = route and route.ValidationSummary.CheckpointCount or 0,
		GateCount = route and RouteDefinition.GetGateCount(route) or 0,
		ArrowCount = route and #(route.ArrowMarkers or {}) or 0,
	}
end

]==]

local TIME_TRIAL_RESULT_HELPER = [==[sendTimeTrialResult = function(player, run, elapsed, finishReason, canRetry)
	-- NTR_RACING_PHASE9A_SESSION_RESULT
	elapsed = tonumber(elapsed) or 0
	local medals = RaceConfigReader.GetTimeTrialMedals(run.EventId, run.VehicleTier)
	local medal, medalTarget = medalForElapsed(elapsed, medals)
	local nextName, nextSeconds, nextDelta = nextMedalTarget(elapsed, medal, medals)
	local bucket = bestBucket(player, run.EventId, run.VehicleTier)
	local previousBest = tonumber(bucket.BestSeconds)
	local isPersonalBest = previousBest == nil or elapsed < previousBest
	if isPersonalBest then
		bucket.BestSeconds = elapsed
		bucket.BestMedal = medal
		bucket.BestVehicleId = run.SelectedVehicleId
		bucket.BestVehicleTier = run.VehicleTier
		bucket.UpdatedClock = os.clock()
	end

	local reward = grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)

	fire(player, {
		Type = "TimeTrialFinished",
		EventId = run.EventId,
		RouteId = run.RouteId,
		DisplayName = run.DisplayName,
		RunId = run.RunId,
		Elapsed = elapsed,
		GateCount = run.GateCount,
		VehicleTier = run.VehicleTier,
		VehicleIndex = run.VehicleIndex,
		SelectedVehicleId = run.SelectedVehicleId,
		Medals = medals,
		Medal = medal,
		MedalRank = medalRank(medal),
		MedalTargetSeconds = medalTarget,
		NextMedalName = nextName,
		NextMedalSeconds = nextSeconds,
		NextMedalDelta = nextDelta,
		PreviousBestSeconds = previousBest,
		PersonalBestSeconds = bucket.BestSeconds,
		PersonalBestMedal = bucket.BestMedal,
		IsPersonalBest = isPersonalBest,
		Splits = run.Splits or {},
		LapTimes = run.LapTimes or {},
		BestLapSeconds = run.BestLapSeconds,
		BestLapIndex = run.BestLapIndex,
		CompletedLapCount = run.CompletedLapCount or 0,
		CurrentLap = run.CurrentLap or 1,
		LapTarget = run.LapTarget or 1,
		RouteType = run.RouteType or "Circuit",
		FinishReason = finishReason or "Finished",
		CanRetry = canRetry ~= false,
		RewardGranted = reward.Granted == true,
		RewardAmount = tonumber(reward.Amount) or 0,
		RewardCash = reward.Cash,
		RewardMessage = reward.Message,
		Message = (reward.Granted == true and ("Best session result!  $" .. tostring(reward.Amount or 0) .. " earned")) or (isPersonalBest and "New personal best!" or tostring(reward.Message or "Finished.")),
	})
	info(player.Name .. " finished " .. tostring(run.EventId) .. " result=" .. string.format("%.3f", elapsed) .. "s reason=" .. tostring(finishReason or "Finished") .. " medal=" .. tostring(medal) .. " pb=" .. tostring(isPersonalBest))
end

local function finishRun(player, resultElapsed, finishReason)
	-- NTR_RACING_PHASE9A_FINISH_BEST_SESSION_RESULT
	local run = activeRuns[player]
	if not run then return end
	local elapsed = tonumber(resultElapsed) or run.BestLapSeconds or (os.clock() - run.StartClock)
	activeRuns[player] = nil
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
		run.Vehicle:SetAttribute("NTR_RaceRunId", nil)
		run.Vehicle:SetAttribute("NTR_RaceParticipant", nil)
		run.Vehicle:SetAttribute("NTR_RaceMode", nil)
		run.Vehicle:SetAttribute("DriveReady", true)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)
	sendTimeTrialResult(player, run, elapsed, finishReason or "Finished", true)
end

]==]

local ADVANCE_CHECKPOINT = [==[local function advanceCheckpoint(player, touchedPart)
	-- NTR_RACING_PHASE9A_LAP_ADVANCE
	local run = activeRuns[player]
	if not (run and run.State == "Running") then return end
	local gate = RouteDefinition.GetGate(run.Route, run.NextGateIndex)
	if not (gate and gate.Part == touchedPart) then return end
	local now = os.clock()
	if now - (run.LastTouchClock or 0) < 0.12 then return end
	run.LastTouchClock = now

	if gate.IsFinish then
		if tostring(run.RouteType or "Circuit") == "Circuit" then
			local lapElapsed = now - (run.LapStartedClock or run.StartClock or now)
			run.CompletedLapCount = (run.CompletedLapCount or 0) + 1
			run.LapTimes = run.LapTimes or {}
			table.insert(run.LapTimes, {
				Lap = run.CompletedLapCount,
				Elapsed = lapElapsed,
			})
			if not run.BestLapSeconds or lapElapsed < run.BestLapSeconds then
				run.BestLapSeconds = lapElapsed
				run.BestLapIndex = run.CompletedLapCount
			end
			run.LastCompletedGateIndex = run.NextGateIndex
			fire(player, {
				Type = "TimeTrialLapCompleted",
				EventId = run.EventId,
				RouteId = run.RouteId,
				RunId = run.RunId,
				Lap = run.CompletedLapCount,
				NextLap = run.CompletedLapCount + 1,
				LapTarget = run.LapTarget or 1,
				InfiniteLaps = (run.LapTarget or 1) == 0,
				Elapsed = lapElapsed,
				BestLapSeconds = run.BestLapSeconds,
				BestLapIndex = run.BestLapIndex,
				GateCount = run.GateCount,
				NextGateIndex = 1,
			})
			if (run.LapTarget or 1) > 0 and run.CompletedLapCount >= run.LapTarget then
				finishRun(player, run.BestLapSeconds or lapElapsed, "LapTarget")
				return
			end
			run.CurrentLap = run.CompletedLapCount + 1
			run.LapStartedClock = now
			run.NextGateIndex = 1
			run.LastCompletedGateIndex = 0
			run.Splits = {}
			fire(player, {
				Type = "TimeTrialCheckpoint",
				EventId = run.EventId,
				RouteId = run.RouteId,
				NextGateIndex = run.NextGateIndex,
				GateCount = run.GateCount,
				CheckpointIndex = gate.Index,
				Elapsed = lapElapsed,
				Splits = run.Splits,
				CurrentLap = run.CurrentLap,
				LapTarget = run.LapTarget or 1,
				InfiniteLaps = (run.LapTarget or 1) == 0,
			})
			return
		end
		finishRun(player, nil, "PointToPoint")
		return
	end

	local splitElapsed = now - (run.LapStartedClock or run.StartClock or now)
	table.insert(run.Splits, {
		CheckpointIndex = gate.Index,
		Elapsed = splitElapsed,
		Lap = run.CurrentLap or 1,
	})
	run.LastCompletedGateIndex = run.NextGateIndex
	run.NextGateIndex += 1
	fire(player, {
		Type = "TimeTrialCheckpoint",
		EventId = run.EventId,
		RouteId = run.RouteId,
		NextGateIndex = run.NextGateIndex,
		GateCount = run.GateCount,
		CheckpointIndex = gate.Index,
		Elapsed = splitElapsed,
		Splits = run.Splits,
		CurrentLap = run.CurrentLap or 1,
		LapTarget = run.LapTarget or 1,
		InfiniteLaps = (run.LapTarget or 1) == 0,
	})
end

]==]

local BEGIN_STAGED_TIME_TRIAL = [==[local function beginStagedTimeTrial(player, eventId, vehicleId, requestedLapCount)
	-- NTR_RACING_PHASE9A_BEGIN_SESSION
	eventId = resolveTimeTrialEventId(eventId)
	if activeRuns[player] then
		return false, "Already in a race/time trial."
	end
	local vehicle, vehicleError = currentVehicleForPlayer(player)
	if not vehicle then
		return false, vehicleError
	end
	local route, routeError = RaceConfigReader.GetRouteForEvent(eventId, "TimeTrial")
	if not route then
		return false, routeError
	end
	if RouteDefinition.GetGateCount(route) < 2 then
		return false, "Route needs checkpoints and a finish line."
	end
	local summary = RaceConfigReader.GetEventSummary(eventId, "TimeTrial") or {}
	local routeType = tostring(summary.RouteType or route.RouteType or "Circuit")
	if routeType ~= "PointToPoint" then
		routeType = "Circuit"
	end
	local maxLapCount = math.clamp(tonumber(summary.MaxLapCount) or 10, 1, 10)
	local minLapCount = math.clamp(tonumber(summary.MinLapCount) or 1, 1, maxLapCount)
	local lapTarget = tonumber(requestedLapCount)
	if routeType == "PointToPoint" then
		lapTarget = 1
	elseif lapTarget == 0 and summary.AllowInfiniteLaps == true then
		lapTarget = 0
	else
		lapTarget = math.clamp(math.floor(lapTarget or tonumber(summary.DefaultLapCount) or 1), minLapCount, maxLapCount)
	end
	local tier = tostring(vehicle:GetAttribute("PerformanceTier") or "")
	local index = tonumber(vehicle:GetAttribute("PerformanceIndex")) or tonumber(vehicle:GetAttribute("PerformanceScore")) or 0
	local runId = "TT_" .. tostring(player.UserId) .. "_" .. tostring(math.floor(os.clock() * 1000))
	local run = {
		State = "Staging",
		RunId = runId,
		Player = player,
		EventId = eventId,
		RouteId = route.RouteId,
		DisplayName = summary.DisplayName or route.DisplayName,
		Route = route,
		RouteType = routeType,
		LapTarget = lapTarget,
		CurrentLap = 1,
		CompletedLapCount = 0,
		LapTimes = {},
		Vehicle = vehicle,
		SelectedVehicleId = tostring(vehicleId or ""),
		VehicleTier = tier,
		VehicleIndex = index,
		NextGateIndex = 1,
		LastCompletedGateIndex = 0,
		GateCount = RouteDefinition.GetGateCount(route),
		Splits = {},
	}
	activeRuns[player] = run
	activeRunsById[runId] = run
	run.SessionFolder = createSessionFolder(run)
	vehicle:SetAttribute("NTR_RaceRunId", runId)
	vehicle:SetAttribute("NTR_RaceParticipant", true)
	vehicle:SetAttribute("NTR_RaceMode", "TimeTrial")

	local staged, stageError = stageVehicle(player, vehicle, route)
	if not staged then
		endRun(player, stageError)
		return false, stageError
	end

	connectRouteTouches(route)
	fireVisibility(run, true)
	fire(player, {
		Type = "TimeTrialStaged",
		RunId = runId,
		EventId = eventId,
		RouteId = route.RouteId,
		DisplayName = run.DisplayName,
		Countdown = COUNTDOWN_SECONDS,
		GateCount = run.GateCount,
		NextGateIndex = 1,
		VehicleTier = tier,
		VehicleIndex = index,
		Medals = RaceConfigReader.GetTimeTrialMedals(eventId, tier),
		RouteType = routeType,
		LapTarget = lapTarget,
		CurrentLap = 1,
		InfiniteLaps = lapTarget == 0,
	})

	task.spawn(function()
		for seconds = COUNTDOWN_SECONDS, 1, -1 do
			local live = activeRuns[player]
			if not (live and live.RunId == runId and live.State == "Staging") then return end
			fire(player, {
				Type = "TimeTrialCountdown",
				RunId = runId,
				EventId = eventId,
				RouteId = route.RouteId,
				DisplayName = run.DisplayName,
				Countdown = seconds,
				GateCount = run.GateCount,
				NextGateIndex = 1,
				RouteType = routeType,
				LapTarget = lapTarget,
				CurrentLap = 1,
				InfiniteLaps = lapTarget == 0,
			})
			task.wait(1)
		end
		local live = activeRuns[player]
		if not (live and live.RunId == runId and live.State == "Staging") then return end
		local currentVehicle, currentError = currentVehicleForPlayer(player)
		if currentVehicle ~= vehicle then
			endRun(player, currentError or "Vehicle changed before start.")
			return
		end
		live.State = "Running"
		live.StartClock = os.clock()
		live.LapStartedClock = live.StartClock
		live.LastTouchClock = 0
		prepareVehicleForDriving(player, vehicle)
		fire(player, {
			Type = "TimeTrialStarted",
			RunId = runId,
			EventId = eventId,
			RouteId = route.RouteId,
			DisplayName = run.DisplayName,
			StartServerClock = live.StartClock,
			GateCount = run.GateCount,
			NextGateIndex = 1,
			RouteType = routeType,
			LapTarget = lapTarget,
			CurrentLap = 1,
			InfiniteLaps = lapTarget == 0,
		})
	end)

	return true, lapTarget == 0 and "Staging infinite time trial." or ("Staging " .. tostring(lapTarget) .. "-lap time trial.")
end

]==]

local EXIT_ACTIVE_TIME_TRIAL = [==[local function exitActiveTimeTrial(player)
	-- NTR_RACING_PHASE9A_QUIT_WITH_BEST_LAP_RESULT
	local run = activeRuns[player]
	if not run then
		return { Ok = false, Success = false, Message = "No active time trial." }
	end
	activeRuns[player] = nil
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)
	if run.BestLapSeconds then
		sendTimeTrialResult(player, run, run.BestLapSeconds, "Quit", true)
	else
		fire(player, {
			Type = "TimeTrialEnded",
			RunId = run.RunId,
			EventId = run.EventId,
			RouteId = run.RouteId,
			Reason = "Exited to start",
		})
	end
	local target = returnCFrameForRoute(run.Route, "TimeTrial")
	destroyVehicleAfterUnseat(player, run.Vehicle)
	teleportCharacterTo(player, target)
	return { Ok = true, Success = true, Message = run.BestLapSeconds and "Session complete." or "Exited to race start." }
end

]==]

local CLIENT_LAP_HELPERS = [==[local function lapLabel(count)
	count = tonumber(count)
	if count == 0 then
		return "INFINITE"
	end
	return tostring(math.clamp(math.floor(count or 1), 1, 10)) .. " LAP"
end

local function lapSettings()
	local summary = state.Entry and state.Entry.Summary or {}
	local minLap = math.clamp(math.floor(tonumber(summary.MinLapCount) or 1), 1, 10)
	local maxLap = math.clamp(math.floor(tonumber(summary.MaxLapCount) or 10), minLap, 10)
	local defaultLap = math.clamp(math.floor(tonumber(summary.DefaultLapCount or summary.Laps) or 1), minLap, maxLap)
	return {
		RouteType = tostring(summary.RouteType or "Circuit"),
		Min = minLap,
		Max = maxLap,
		Default = defaultLap,
		AllowInfinite = summary.AllowInfiniteLaps ~= false,
	}
end

local function makeLapSelector(parent, position)
	-- NTR_RACING_PHASE9A_LAP_SELECTOR
	local settings = lapSettings()
	state.SelectedLapCount = settings.Default
	if settings.RouteType == "PointToPoint" then
		state.SelectedLapCount = 1
	end

	local wrap = Instance.new("Frame")
	wrap.Name = "LapSelector"
	wrap.BackgroundColor3 = theme.Card
	wrap.BackgroundTransparency = 0.1
	wrap.BorderSizePixel = 0
	wrap.Position = position or UDim2.fromOffset(0, 160)
	wrap.Size = UDim2.new(1, 0, 0, touch and 82 or 92)
	wrap.Parent = parent
	corner(wrap, 6)
	stroke(wrap, theme.Accent, 1, 0.48)

	local title = label(wrap, settings.RouteType == "PointToPoint" and "POINT TO POINT" or "TIME TRIAL LAPS", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 6), touch and 9 or 11, theme.Accent, true)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local selected = label(wrap, lapLabel(state.SelectedLapCount), UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 27), touch and 12 or 14, theme.Text, true)
	selected.TextXAlignment = Enum.TextXAlignment.Center

	if settings.RouteType == "PointToPoint" then
		local note = label(wrap, "This route finishes once.", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 54), touch and 9 or 10, theme.Muted, false)
		note.TextXAlignment = Enum.TextXAlignment.Center
		return wrap
	end

	local minus = button(wrap, "-", UDim2.fromOffset(42, 30), UDim2.new(0, 8, 1, -36), theme.Panel)
	local plus = button(wrap, "+", UDim2.fromOffset(42, 30), UDim2.new(1, -50, 1, -36), theme.Panel)
	local infinite = button(wrap, "INFINITE", UDim2.new(1, -116, 0, 30), UDim2.new(0, 58, 1, -36), theme.Card)
	infinite.Visible = settings.AllowInfinite

	local function refresh()
		selected.Text = lapLabel(state.SelectedLapCount)
		infinite.BackgroundColor3 = state.SelectedLapCount == 0 and theme.CardHot or theme.Card
	end

	minus.MouseButton1Click:Connect(function()
		if state.SelectedLapCount == 0 then
			state.SelectedLapCount = settings.Max
		else
			state.SelectedLapCount = math.max(settings.Min, (tonumber(state.SelectedLapCount) or settings.Default) - 1)
		end
		refresh()
	end)
	plus.MouseButton1Click:Connect(function()
		state.SelectedLapCount = math.min(settings.Max, (tonumber(state.SelectedLapCount) or settings.Default) + 1)
		refresh()
	end)
	infinite.MouseButton1Click:Connect(function()
		state.SelectedLapCount = 0
		refresh()
	end)
	refresh()
	return wrap
end

]==]

local function patchRouteDefinition()
	local module = racingModulesFolder():FindFirstChild("RaceRouteDefinition")
	if not (module and module:IsA("ModuleScript")) then fail("RaceRouteDefinition missing.") end
	if string.find(module.Source, "RouteType = stringAttribute(route, \"RouteType\", \"Circuit\")", 1, true) then
		info("RaceRouteDefinition already has RouteType.")
		return
	end
	module.Source = replacePlain(
		module.Source,
		[[		DisplayName = stringAttribute(route, "DisplayName", tostring(routeId)),
		SourceType = stringAttribute(route, "SourceType", "Official"),]],
		[[		DisplayName = stringAttribute(route, "DisplayName", tostring(routeId)),
		RouteType = stringAttribute(route, "RouteType", "Circuit"),
		SourceType = stringAttribute(route, "SourceType", "Official"),]],
		"route definition RouteType field"
	)
	info("Patched RaceRouteDefinition RouteType field.")
end

local function patchConfigReader()
	local module = racingModulesFolder():FindFirstChild("RaceConfigReader")
	if not (module and module:IsA("ModuleScript")) then fail("RaceConfigReader missing.") end
	if string.find(module.Source, "NTR_RACING_PHASE9A_CONFIG_READER", 1, true) then
		info("RaceConfigReader already patched.")
		return
	end
	local source = replaceFunctionBefore(module.Source, "Reader.GetEventSummary", "Reader.GetTimeTrialMedals", "-- NTR_RACING_PHASE9A_CONFIG_READER\n" .. CONFIG_READER_SUMMARY)
	module.Source = source
	info("Patched RaceConfigReader summary with route type/lap attributes.")
end

local function patchTimeTrialService()
	local folder = serverRacingFolder()
	local service = folder and folder:FindFirstChild("TimeTrialService_Active")
	if not (service and service:IsA("Script")) then fail("TimeTrialService_Active missing.") end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE9A_LAP_ADVANCE", 1, true) then
		info("TimeTrialService_Active already patched.")
		return
	end
	if not string.find(source, "NTR_RACING_PHASE8H_RESPAWN_RESET", 1, true) then
		warn("[NTR Racing Phase 9A] Phase 8H respawn reset marker not found in live TimeTrialService_Active. Phase 9A will not change reset helpers, but confirm 8H is installed before testing reset again.")
	end
	if not string.find(source, "local sendTimeTrialResult", 1, true) then
		source = insertBefore(source, "local function exitActiveTimeTrial(player)", "local sendTimeTrialResult\n", "time-trial result helper forward declaration")
	end
	source = replaceFunctionBefore(source, "finishRun", "advanceCheckpoint", TIME_TRIAL_RESULT_HELPER)
	source = replaceFunctionBefore(source, "advanceCheckpoint", "connectRouteTouches", ADVANCE_CHECKPOINT)
	source = replaceFunctionBefore(source, "beginStagedTimeTrial", "eventIdForZone", BEGIN_STAGED_TIME_TRIAL)
	source = replaceFunctionBefore(source, "exitActiveTimeTrial", "stageVehicle", EXIT_ACTIVE_TIME_TRIAL)
	local patchedSource, lapPayloadCount = string.gsub(source, "beginStagedTimeTrial%(player, eventId, payload%.VehicleId%)", "beginStagedTimeTrial(player, eventId, payload.VehicleId, payload.LapCount)")
	if lapPayloadCount < 1 then
		fail("Could not patch StartStagedTimeTrial lap payload. Refresh the Studio mirror before another repair.")
	end
	source = patchedSource
	service.Source = source
	info("Patched TimeTrialService_Active with circuit lap sessions and quit summary.")
end

local function patchEntryClient()
	local folder = clientRacingFolder()
	local client = folder and folder:FindFirstChild("RaceEntryMenuClient_Active")
	if not (client and client:IsA("LocalScript")) then fail("RaceEntryMenuClient_Active missing.") end
	local source = client.Source
	if string.find(source, "NTR_RACING_PHASE9A_LAP_SELECTOR", 1, true) then
		info("RaceEntryMenuClient_Active already patched.")
		return
	end
	source = replacePlain(source, "	ActiveRun = nil,\n	Visibility = nil,", "	ActiveRun = nil,\n	Visibility = nil,\n	SelectedLapCount = nil,", "client state SelectedLapCount")
	source = insertBefore(source, "local showEntry\n", CLIENT_LAP_HELPERS, "client lap helpers before showEntry")
	source = replacePlain(source, "			VehicleId = row.VehicleId,\n		})", "			VehicleId = row.VehicleId,\n			LapCount = state.SelectedLapCount or 1,\n		})", "time trial start payload lap count")
	source = replacePlain(source, [[	label(right, "Checkpoints: " .. tostring(summary.CheckpointCount or 0) .. "   Route gates: " .. tostring(summary.GateCount or 0), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 102), touch and 10 or 12, theme.Muted, false)
	label(right, "Base reward: $" .. tostring(summary.BaseReward or 0), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 132), touch and 10 or 12, theme.Muted, false)
	label(right, "Time trials are solo and staged away from free-roam clutter. Multiplayer race matchmaking will use the same menu after the solo flow is stable.", UDim2.new(1, 0, 0, 120), UDim2.fromOffset(0, 176), touch and 10 or 12, theme.Text, false)]],
	[[	label(right, "Checkpoints: " .. tostring(summary.CheckpointCount or 0) .. "   Route gates: " .. tostring(summary.GateCount or 0), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 102), touch and 10 or 12, theme.Muted, false)
	label(right, "Base reward: $" .. tostring(summary.BaseReward or 0), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 132), touch and 10 or 12, theme.Muted, false)
	makeLapSelector(right, UDim2.fromOffset(0, 164))
	label(right, "Time trials are solo. Circuit sessions use your best completed lap for medals and one payout when the session ends, so Infinite is for practice without per-lap cash farming.", UDim2.new(1, 0, 0, 116), UDim2.fromOffset(0, 266), touch and 10 or 12, theme.Text, false)]],
	"entry menu route/lap summary block")
	source = replacePlain(source, [[	resultTitle.Text = tostring(payload.DisplayName or "TIME TRIAL COMPLETE")]],
	[[	if tostring(payload.FinishReason or "") == "Quit" then
		resultTitle.Text = tostring(payload.DisplayName or "TIME TRIAL SESSION")
	elseif tostring(payload.RouteType or "") == "Circuit" and tonumber(payload.CompletedLapCount) and tonumber(payload.CompletedLapCount) > 1 then
		resultTitle.Text = tostring(payload.DisplayName or "BEST LAP")
	else
		resultTitle.Text = tostring(payload.DisplayName or "TIME TRIAL COMPLETE")
	end]],
	"result title route/session wording")
	source = replacePlain(source, [[	resultSplits.Text = splitSummary(payload.Splits)]],
	[[	if payload.LapTimes and #payload.LapTimes > 0 then
		local laps = {}
		for _, lap in ipairs(payload.LapTimes) do
			if #laps >= 4 then break end
			table.insert(laps, "LAP " .. tostring(lap.Lap or "?") .. "  " .. formatTime(lap.Elapsed))
		end
		resultSplits.Text = table.concat(laps, "\n")
	else
		resultSplits.Text = splitSummary(payload.Splits)
	end]],
	"result lap-time summary")
	source = replacePlain(source, [[	elseif kind == "TimeTrialCheckpoint" then
		if not state.ActiveRun then return end]],
	[[	elseif kind == "TimeTrialLapCompleted" then
		if not state.ActiveRun then return end
		state.ActiveRun.NextGateIndex = 1
		state.ActiveRun.GateCount = payload.GateCount or state.ActiveRun.GateCount
		state.ActiveRun.StartLocalClock = os.clock()
		hudStatus.Text = "BEST LAP " .. formatTime(payload.BestLapSeconds or payload.Elapsed)
		hudTimer.Text = "0.000"
		updateNextGate()
	elseif kind == "TimeTrialCheckpoint" then
		if not state.ActiveRun then return end]],
	"lap completed event handler")
	client.Source = source
	info("Patched RaceEntryMenuClient_Active with lap selector and session result display.")
end

local function smoke()
	local routeModule = racingModulesFolder():FindFirstChild("RaceRouteDefinition")
	local configModule = racingModulesFolder():FindFirstChild("RaceConfigReader")
	local timeTrial = serverRacingFolder() and serverRacingFolder():FindFirstChild("TimeTrialService_Active")
	local entryClient = clientRacingFolder() and clientRacingFolder():FindFirstChild("RaceEntryMenuClient_Active")
	assert(routeModule and string.find(routeModule.Source, "RouteType = stringAttribute(route, \"RouteType\", \"Circuit\")", 1, true), "RouteType missing from RaceRouteDefinition")
	assert(configModule and string.find(configModule.Source, "NTR_RACING_PHASE9A_CONFIG_READER", 1, true), "RaceConfigReader Phase 9A marker missing")
	assert(timeTrial and string.find(timeTrial.Source, "NTR_RACING_PHASE9A_LAP_ADVANCE", 1, true), "TimeTrialService Phase 9A lap advance missing")
	assert(entryClient and string.find(entryClient.Source, "NTR_RACING_PHASE9A_LAP_SELECTOR", 1, true), "RaceEntryMenu lap selector missing")
	info("Smoke passed: Phase 9A route type/lap session markers are installed.")
end

if MODE == "INSTALL" then
	ensureRouteAndEventAttributes()
	patchRouteDefinition()
	patchConfigReader()
	patchTimeTrialService()
	patchEntryClient()
	smoke()
	info("Installed. Restart Play before testing lap-selection time trials.")
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
