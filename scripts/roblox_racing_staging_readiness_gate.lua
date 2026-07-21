-- Neo Tokyo Racers - Race Staging Readiness Gate
-- Canonical source-only installer for the confirmed Loading Phase 4 baseline.
-- Run once in Roblox Studio Command Bar while in Edit mode.
--
-- This is a guarded source transaction. It creates no in-game backups, checks
-- exact current anchors/markers, compiles every projected source before any
-- mutation, and restores all source assignments if final verification fails.

local MODE = "INSTALL" -- INSTALL or AUDIT

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Studio Edit mode.")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "NTR Race Staging Readiness Gate"
local REVISION = "NTR_RACING_STAGING_READINESS_GATE_V1"

local function info(message)
	print(("[%s] %s"):format(PHASE, tostring(message)))
end

local function find(root, path)
	local current = root
	for segment in string.gmatch(path, "[^.]+") do
		current = current and current:FindFirstChild(segment)
	end
	return current
end

local function replaceOnce(source, old, new, label)
	local first, last = string.find(source, old, 1, true)
	assert(first, label .. " anchor missing. Refresh the Studio mirror before repairing this installer.")
	assert(not string.find(source, old, last + 1, true), label .. " anchor is not unique.")
	return string.sub(source, 1, first - 1) .. new .. string.sub(source, last + 1)
end

local function replaceSpanOnce(source, startAnchor, endAnchor, replacement, label)
	local first, startLast = string.find(source, startAnchor, 1, true)
	assert(first, label .. " start anchor missing. Refresh the Studio mirror before repairing this installer.")
	assert(not string.find(source, startAnchor, startLast + 1, true), label .. " start anchor is not unique.")
	local finish, finishLast = string.find(source, endAnchor, startLast + 1, true)
	assert(finish, label .. " end anchor missing. Refresh the Studio mirror before repairing this installer.")
	assert(not string.find(source, endAnchor, finishLast + 1, true), label .. " end anchor is not unique after the start anchor.")
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, finishLast + 1)
end

local function compile(label, source)
	local fn, problem = loadstring(source, "=" .. label)
	assert(fn, label .. " compile failed: " .. tostring(problem))
end

local kit = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local racingServices = assert(find(ServerScriptService, "NeoTokyoRacers.Services.Racing"), "Server racing services missing")
local clientRacing = assert(find(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing"), "Client racing controllers missing")
local clientUI = assert(find(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"), "Client UI controllers missing")

local timeTrial = assert(racingServices:FindFirstChild("TimeTrialService_Active"), "TimeTrialService_Active missing")
local matchmaking = assert(racingServices:FindFirstChild("RaceMatchmakingService_Active"), "RaceMatchmakingService_Active missing")
local transition = assert(clientRacing:FindFirstChild("RaceTransitionClient_Active"), "RaceTransitionClient_Active missing")
local countdown = assert(clientRacing:FindFirstChild("RaceCountdownPresentationController_Active"), "RaceCountdownPresentationController_Active missing")
local loadingState = assert(clientUI:FindFirstChild("LoadingPresentationState"), "LoadingPresentationState missing")
local loadingInvoke = assert(clientUI:FindFirstChild("LoadingTransitionInvoke"), "LoadingTransitionInvoke missing")

assert(timeTrial:IsA("Script"), "TimeTrialService_Active must be a Script")
assert(matchmaking:IsA("Script"), "RaceMatchmakingService_Active must be a Script")
assert(transition:IsA("LocalScript"), "RaceTransitionClient_Active must be a LocalScript")
assert(countdown:IsA("LocalScript"), "RaceCountdownPresentationController_Active must be a LocalScript")
assert(loadingState:IsA("Folder"), "LoadingPresentationState must be a Folder")
assert(loadingInvoke:IsA("BindableFunction"), "LoadingTransitionInvoke must be a BindableFunction")

for object, marker in pairs({
	[timeTrial] = "NTR_RACING_PHASE3_TIME_TRIAL_SERVICE",
	[matchmaking] = "NTR_RACING_PHASE8_MATCHMAKING_SERVICE",
	[transition] = "NTR_LOADING_SYSTEM_PHASE4_RACE_TRANSITION_BRIDGE_V1",
	[countdown] = "NTR_RACING_FLOW_COUNTDOWN_VISUAL_V2",
}) do
	assert(string.find(object.Source, marker, 1, true), object.Name .. " is missing confirmed marker " .. marker)
	compile(object.Name .. "_baseline", object.Source)
end

local projected = {}

local timeTrialSource = timeTrial.Source
if not string.find(timeTrialSource, REVISION, 1, true) then
	timeTrialSource = replaceOnce(timeTrialSource,
		[=[local COUNTDOWN_SECONDS=math.max(1,math.floor(tonumber(countdownValue.Value) or 5))]=],
		[=[local COUNTDOWN_SECONDS=math.max(1,math.floor(tonumber(countdownValue.Value) or 5))
local STAGING_READY_TIMEOUT_SECONDS = 18 -- NTR_RACING_STAGING_READINESS_GATE_V1
local COUNTDOWN_VISIBLE_TIMEOUT_SECONDS = 8]=],
		"time-trial readiness constants")
	timeTrialSource = replaceOnce(timeTrialSource,
		[=[		Splits = {},
	}]=],
		[=[		Splits = {},
		Readiness = { AssetsReady = false, CountdownVisible = false },
	}]=],
		"time-trial readiness state")
	timeTrialSource = replaceOnce(timeTrialSource,
		[=[		Medals = RaceConfigReader.GetTimeTrialMedals(eventId, tier),
		RouteType = routeType,
		LapTarget = lapTarget,
		CurrentLap = 1,
		InfiniteLaps = lapTarget == 0,
	})]=],
		[=[		Medals = RaceConfigReader.GetTimeTrialMedals(eventId, tier),
		RouteType = routeType,
		LapTarget = lapTarget,
		CurrentLap = 1,
		InfiniteLaps = lapTarget == 0,
		StreamPosition = stageCFrame.Position,
	})]=],
		"time-trial stream position")
	timeTrialSource = replaceSpanOnce(timeTrialSource,
		[=[	task.spawn(function()
		for seconds = COUNTDOWN_SECONDS, 1, -1 do]=],
		[=[	end)

	return true, lapTarget == 0 and "Staging infinite time trial." or ("Staging " .. tostring(lapTarget) .. "-lap time trial.")]=],
		[=[	task.spawn(function()
		local assetsDeadline = os.clock() + STAGING_READY_TIMEOUT_SECONDS
		while os.clock() < assetsDeadline do
			local live = activeRuns[player]
			if not (live and live.RunId == runId and live.State == "Staging") then return end
			if live.Readiness and live.Readiness.AssetsReady == true then break end
			task.wait(0.05)
		end
		local live = activeRuns[player]
		if not (live and live.RunId == runId and live.State == "Staging") then return end
		if not (live.Readiness and live.Readiness.AssetsReady == true) then
			fire(player, { Type = "TimeTrialError", RunId = runId, EventId = eventId, Message = "Race start readiness timed out." })
			endRun(player, "Race start readiness timed out.")
			return
		end

		fire(player, {
			Type = "TimeTrialCountdownReveal",
			RunId = runId,
			EventId = eventId,
			RouteId = route.RouteId,
			DisplayName = run.DisplayName,
			Countdown = COUNTDOWN_SECONDS,
		})

		local visibleDeadline = os.clock() + COUNTDOWN_VISIBLE_TIMEOUT_SECONDS
		while os.clock() < visibleDeadline do
			live = activeRuns[player]
			if not (live and live.RunId == runId and live.State == "Staging") then return end
			if live.Readiness and live.Readiness.CountdownVisible == true then break end
			task.wait(0.05)
		end
		live = activeRuns[player]
		if not (live and live.RunId == runId and live.State == "Staging") then return end
		if not (live.Readiness and live.Readiness.CountdownVisible == true) then
			fire(player, { Type = "TimeTrialError", RunId = runId, EventId = eventId, Message = "Countdown presentation readiness timed out." })
			endRun(player, "Countdown presentation readiness timed out.")
			return
		end

		local goAt = Workspace:GetServerTimeNow() + COUNTDOWN_SECONDS
		fire(player, {
			Type = "TimeTrialCountdownScheduled",
			RunId = runId,
			EventId = eventId,
			RouteId = route.RouteId,
			DisplayName = run.DisplayName,
			Countdown = COUNTDOWN_SECONDS,
			GoAtServerTime = goAt,
		})
		while Workspace:GetServerTimeNow() < goAt do
			live = activeRuns[player]
			if not (live and live.RunId == runId and live.State == "Staging") then return end
			task.wait(0.03)
		end

		live = activeRuns[player]
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
			StartServerTime = goAt,
			GateCount = run.GateCount,
			NextGateIndex = 1,
			RouteType = routeType,
			LapTarget = lapTarget,
			CurrentLap = 1,
			InfiniteLaps = lapTarget == 0,
		})
	end)

	return true, lapTarget == 0 and "Staging infinite time trial." or ("Staging " .. tostring(lapTarget) .. "-lap time trial.")]=],
		"time-trial readiness countdown")
	timeTrialSource = replaceOnce(timeTrialSource,
		[=[	payload = typeof(payload) == "table" and payload or {}
	if action == "GetEntryDetails" then]=],
		[=[	payload = typeof(payload) == "table" and payload or {}
	if action == "AcknowledgeStagingReady" then
		local run = activeRuns[player]
		if not (run and run.State == "Staging" and tostring(payload.RunId or "") == run.RunId) then
			return { Ok = false, Success = false, Message = "Stale or invalid time-trial readiness acknowledgement." }
		end
		local phase = tostring(payload.Phase or "")
		if phase ~= "AssetsReady" and phase ~= "CountdownVisible" then
			return { Ok = false, Success = false, Message = "Invalid readiness phase." }
		end
		run.Readiness = run.Readiness or {}
		run.Readiness[phase] = true
		if payload.Degraded == true then warn(("[NTR Race Readiness] Time trial %s reported degraded %s readiness: %s"):format(run.RunId, phase, tostring(payload.Detail or ""))) end
		return { Ok = true, Success = true, RunId = run.RunId, Phase = phase }
	elseif action == "GetEntryDetails" then]=],
		"time-trial readiness acknowledgement")
end
compile(timeTrial.Name, timeTrialSource)
projected[timeTrial] = timeTrialSource

local matchmakingSource = matchmaking.Source
if not string.find(matchmakingSource, REVISION, 1, true) then
	matchmakingSource = replaceOnce(matchmakingSource,
		[=[local matchmakingConfig = config:WaitForChild("Matchmaking")]=],
		[=[local matchmakingConfig = config:WaitForChild("Matchmaking")
local STAGING_READY_TIMEOUT_SECONDS = 18 -- NTR_RACING_STAGING_READINESS_GATE_V1
local COUNTDOWN_VISIBLE_TIMEOUT_SECONDS = 8]=],
		"race readiness constants")
	matchmakingSource = replaceOnce(matchmakingSource,
		[=[		Participants = participants,
		NextFinishPlace = 1,]=],
		[=[		Participants = participants,
		NextFinishPlace = 1,
		Readiness = { AssetsReady = {}, CountdownVisible = {} },]=],
		"race readiness state")
	matchmakingSource = replaceOnce(matchmakingSource,
		[=[			ParticipantCount = #participants,
			Countdown = numberValue(matchmakingConfig, "CountdownSeconds", 3),]=],
		[=[			ParticipantCount = #participants,
			Countdown = numberValue(matchmakingConfig, "CountdownSeconds", 5),
			StreamPosition = spawnCFrameForIndex(queue.Route, entry.GridIndex or 1).Position,]=],
		"queue staged stream position")
	matchmakingSource = replaceOnce(matchmakingSource,
		[=[		fireRace(entry.Player, {
			Type = "RaceStaged",
			RunId = runId,
			EventId = queue.EventId,
			RouteId = race.RouteId,
			DisplayName = race.DisplayName,
			GateCount = race.GateCount,]=],
		[=[		fireRace(entry.Player, {
			Type = "RaceStaged",
			RunId = runId,
			EventId = queue.EventId,
			RouteId = race.RouteId,
			DisplayName = race.DisplayName,
			Countdown = numberValue(matchmakingConfig, "CountdownSeconds", 5),
			StreamPosition = spawnCFrameForIndex(queue.Route, entry.GridIndex or 1).Position,
			GateCount = race.GateCount,]=],
		"race staged stream position")
	matchmakingSource = replaceSpanOnce(matchmakingSource,
		[=[	task.spawn(function()
		local countdown = math.max(1, math.floor(numberValue(matchmakingConfig, "CountdownSeconds", 3)))]=],
		[=[	end)
	info("Started " .. runId .. " with " .. tostring(#participants) .. " racers.")]=],
		[=[	task.spawn(function()
		local function everyActiveParticipantReady(bucket)
			for _, entry in ipairs(participants) do
				if entry.Finished ~= true and entry.Player.Parent == Players and bucket[entry.Player.UserId] ~= true then return false end
			end
			return true
		end
		local function cancelReadiness(reason)
			if activeRaces[runId] ~= race or race.State ~= "Staging" then return end
			for _, entry in ipairs(participants) do
				if entry.Finished ~= true and entry.Player.Parent == Players then
					local payload = { Type = "RaceQueueError", RunId = runId, EventId = queue.EventId, Message = reason }
					fire(entry.Player, payload)
					fireRace(entry.Player, payload)
				end
			end
			cleanupRace(race, reason)
		end

		local assetsDeadline = now() + STAGING_READY_TIMEOUT_SECONDS
		while now() < assetsDeadline do
			if activeRaces[runId] ~= race or race.State ~= "Staging" then return end
			if everyActiveParticipantReady(race.Readiness.AssetsReady) then break end
			task.wait(0.05)
		end
		if activeRaces[runId] ~= race or race.State ~= "Staging" then return end
		if not everyActiveParticipantReady(race.Readiness.AssetsReady) then
			cancelReadiness("Race start readiness timed out.")
			return
		end

		local countdown = math.max(1, math.floor(numberValue(matchmakingConfig, "CountdownSeconds", 5)))
		for _, entry in ipairs(participants) do
			if entry.Finished ~= true and entry.Player.Parent == Players then
				local payload = { Type = "RaceCountdownReveal", RunId = runId, EventId = queue.EventId, RouteId = race.RouteId, DisplayName = race.DisplayName, Countdown = countdown }
				fire(entry.Player, payload)
				fireRace(entry.Player, payload)
			end
		end

		local visibleDeadline = now() + COUNTDOWN_VISIBLE_TIMEOUT_SECONDS
		while now() < visibleDeadline do
			if activeRaces[runId] ~= race or race.State ~= "Staging" then return end
			if everyActiveParticipantReady(race.Readiness.CountdownVisible) then break end
			task.wait(0.05)
		end
		if activeRaces[runId] ~= race or race.State ~= "Staging" then return end
		if not everyActiveParticipantReady(race.Readiness.CountdownVisible) then
			cancelReadiness("Countdown presentation readiness timed out.")
			return
		end

		local goAt = Workspace:GetServerTimeNow() + countdown
		for _, entry in ipairs(participants) do
			if entry.Finished ~= true and entry.Player.Parent == Players then
				local payload = { Type = "RaceCountdownScheduled", RunId = runId, EventId = queue.EventId, RouteId = race.RouteId, DisplayName = race.DisplayName, Countdown = countdown, GoAtServerTime = goAt }
				fire(entry.Player, payload)
				fireRace(entry.Player, payload)
			end
		end
		while Workspace:GetServerTimeNow() < goAt do
			if activeRaces[runId] ~= race or race.State ~= "Staging" then return end
			task.wait(0.03)
		end
		if activeRaces[runId] ~= race or race.State ~= "Staging" then return end
		race.State = "Running"
		race.StartClock = now()
		for _, entry in ipairs(participants) do entry.LapStartedClock = race.StartClock end
		for _, entry in ipairs(participants) do
			if entry.Finished ~= true and entry.Player.Parent == Players then
				prepareVehicleForDriving(entry.Player, entry.Vehicle)
				local payload = {
					Type = "RaceStarted", RunId = runId, EventId = queue.EventId, RouteId = race.RouteId,
					DisplayName = race.DisplayName, StartServerClock = race.StartClock, StartServerTime = goAt,
					GateCount = race.GateCount, NextGateIndex = 1, CurrentLap = 1, LapTarget = race.LapTarget,
					ParticipantCount = #participants,
				}
				fire(entry.Player, payload)
				fireRace(entry.Player, payload)
			end
		end
		task.delay(numberValue(matchmakingConfig, "RaceFinishTimeoutSeconds", 300), function()
			if activeRaces[runId] == race and race.State == "Running" then
				for _, entry in ipairs(participants) do
					if entry.Finished ~= true then
						fire(entry.Player, { Type = "RaceDNF", RunId = runId, EventId = queue.EventId, Message = "Race timed out." })
					end
				end
				cleanupRace(race, "Timed out")
			end
		end)
	end)
	info("Started " .. runId .. " with " .. tostring(#participants) .. " racers.")]=],
		"multiplayer readiness countdown")
	matchmakingSource = replaceOnce(matchmakingSource,
		[=[	payload = typeof(payload) == "table" and payload or {}
	if action == "JoinQueue" then]=],
		[=[	payload = typeof(payload) == "table" and payload or {}
	if action == "AcknowledgeStagingReady" then
		local race = activeRaceByPlayer[player]
		local entry = entryForPlayer(race, player)
		if not (race and entry and race.State == "Staging" and tostring(payload.RunId or "") == race.RunId) then
			return { Ok = false, Success = false, Message = "Stale or invalid race readiness acknowledgement." }
		end
		local phase = tostring(payload.Phase or "")
		if phase ~= "AssetsReady" and phase ~= "CountdownVisible" then
			return { Ok = false, Success = false, Message = "Invalid readiness phase." }
		end
		race.Readiness = race.Readiness or { AssetsReady = {}, CountdownVisible = {} }
		race.Readiness[phase] = race.Readiness[phase] or {}
		race.Readiness[phase][player.UserId] = true
		if payload.Degraded == true then warn(("[NTR Race Readiness] Race %s player %s reported degraded %s readiness: %s"):format(race.RunId, player.Name, phase, tostring(payload.Detail or ""))) end
		return { Ok = true, Success = true, RunId = race.RunId, Phase = phase }
	elseif action == "JoinQueue" then]=],
		"race readiness acknowledgement")
end
compile(matchmaking.Name, matchmakingSource)
projected[matchmaking] = matchmakingSource

local transitionSource = transition.Source
if not string.find(transitionSource, REVISION, 1, true) then
	transitionSource = replaceOnce(transitionSource,
		[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")]=],
		[=[local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider") -- NTR_RACING_STAGING_READINESS_GATE_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")]=],
		"transition content provider")
	transitionSource = replaceOnce(transitionSource,
		[=[local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")]=],
		[=[local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")]=],
		"transition readiness remotes")
	transitionSource = replaceOnce(transitionSource,
		[=[local finishHold = false -- NTR_RACING_PHASE11D_FINISH_HOLD]=],
		[=[local finishHold = false -- NTR_RACING_PHASE11D_FINISH_HOLD
local activeStaging = nil]=],
		"transition staging state")
	transitionSource = replaceOnce(transitionSource,
		[=[local function handleRacePayload(payload)
	if typeof(payload) ~= "table" then return end]=],
		[=[local function acknowledgeStaging(stage, phase, degraded, detail)
	if activeStaging ~= stage then return false end
	local remote = stage.Mode == "TimeTrial" and raceRequest or queueRequest
	local ok, result = pcall(function()
		return remote:InvokeServer("AcknowledgeStagingReady", {
			RunId = stage.RunId,
			Phase = phase,
			Degraded = degraded == true,
			Detail = tostring(detail or ""),
		})
	end)
	if not ok or typeof(result) ~= "table" or result.Ok ~= true then
		warn(("[NTR Race Readiness] %s acknowledgement failed for %s: %s"):format(phase, stage.RunId, tostring(ok and result and result.Message or result)))
		return false
	end
	return true
end

local function stagedVehicle(runId)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then return nil end
	local vehicle = vehicleFromSeat(seat)
	if not vehicle or tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then return nil end
	if tostring(vehicle:GetAttribute("NTR_RaceRunId") or "") ~= tostring(runId or "") then return nil end
	if vehicle:GetAttribute("NTR_RaceParticipant") ~= true then return nil end
	return vehicle
end

local function prepareStaging(payload, kind)
	local runId = tostring(payload.RunId or "")
	if runId == "" then return end
	if activeStaging and activeStaging.RunId == runId then return end
	local stage = { RunId = runId, Mode = kind == "TimeTrialStaged" and "TimeTrial" or "Race", RevealHandling = false }
	activeStaging = stage
	task.spawn(function()
		local deadline = os.clock() + 7.5
		local vehicle = nil
		local presenter = racingFolder:FindFirstChild("RaceCountdownPresentationController_Active")
		while activeStaging == stage and os.clock() < deadline do
			vehicle = stagedVehicle(runId)
			if vehicle and presenter and presenter:GetAttribute("NTR_CountdownPresentationReady") == true then break end
			task.wait(0.05)
		end
		if activeStaging ~= stage then return end
		local preparationFinished = false
		local preparationOk = true
		local preparationDetail = ""
		task.spawn(function()
			local ok, problem = pcall(function()
				local streamPosition = payload.StreamPosition
				if typeof(streamPosition) == "Vector3" then player:RequestStreamAroundAsync(streamPosition, 5) end
				if vehicle and vehicle.Parent then ContentProvider:PreloadAsync({ vehicle }) end
			end)
			preparationOk = ok
			preparationDetail = ok and "" or tostring(problem)
			preparationFinished = true
		end)
		while activeStaging == stage and not preparationFinished and os.clock() < deadline do task.wait(0.05) end
		if activeStaging ~= stage then return end
		local presenterReady = presenter and presenter:GetAttribute("NTR_CountdownPresentationReady") == true
		local degraded = not (vehicle and presenterReady and preparationFinished and preparationOk)
		local detail = preparationDetail
		if not vehicle then detail = "Staged vehicle/seat was not confirmed locally." elseif not presenterReady then detail = "Countdown presenter was not ready." elseif not preparationFinished then detail = "Streaming/preload preparation reached its client deadline." end
		acknowledgeStaging(stage, "AssetsReady", degraded, detail)
	end)
end

local function revealCountdown(payload, kind)
	local stage = activeStaging
	if not stage or stage.RunId ~= tostring(payload.RunId or "") or stage.RevealHandling then return end
	stage.RevealHandling = true
	task.spawn(function()
		restoreCamera(kind)
		local hadLoading = loadingGeneration ~= nil
		finishTransition(kind)
		if not hadLoading then task.wait(0.55) end
		if activeStaging == stage then acknowledgeStaging(stage, "CountdownVisible", false, "") end
	end)
end

local function handleRacePayload(payload)
	if typeof(payload) ~= "table" then return end]=],
		"transition readiness helpers")
	transitionSource = replaceOnce(transitionSource,
		[=[	if kind == "TimeTrialStaged" or kind == "RaceStaged" then
		finishHold = false
		startTransition(kind)
	elseif kind == "TimeTrialCountdown" or kind == "RaceCountdown" then]=],
		[=[	if kind == "TimeTrialStaged" or kind == "RaceStaged" then
		finishHold = false
		if not activeStaging or activeStaging.RunId ~= tostring(payload.RunId or "") then
			startTransition(kind)
			prepareStaging(payload, kind)
		end
	elseif kind == "TimeTrialCountdownReveal" or kind == "RaceCountdownReveal" then
		revealCountdown(payload, kind)
	elseif kind == "TimeTrialCountdownScheduled" or kind == "RaceCountdownScheduled" then
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		restoreCamera(kind)
	elseif kind == "TimeTrialCountdown" or kind == "RaceCountdown" then]=],
		"transition readiness event routing")
	transitionSource = replaceOnce(transitionSource,
		[=[	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		finishHold = false]=],
		[=[	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		activeStaging = nil
		finishHold = false]=],
		"transition start cleanup")
	transitionSource = replaceOnce(transitionSource,
		[=[		local success = kind ~= "TimeTrialError" and kind ~= "RaceQueueError"
		if not finishLoading(success, success and "READY" or "RETURNING", kind) then fadeIn(0.18) end]=],
		[=[		activeStaging = nil
		local success = kind ~= "TimeTrialError" and kind ~= "RaceQueueError"
		if not finishLoading(success, success and "READY" or "RETURNING", kind) then fadeIn(0.18) end]=],
		"transition terminal cleanup")
end
compile(transition.Name, transitionSource)
projected[transition] = transitionSource

local COUNTDOWN_SOURCE = [=[
-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP
-- NTR_RACING_FLOW_COUNTDOWN_VISUAL_V2
-- NTR_RACING_STAGING_READINESS_GATE_V1
-- Shared synchronized five-to-GO countdown for Race and Time Trial.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local event=kit.Shared.Remotes.Racing:WaitForChild("RaceEvent")
local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents"))
local C=UI.Colour
local config=kit.Config.Racing:WaitForChild("FlowUI")
local function N(name,fallback) local item=config:FindFirstChild(name) return item and item:IsA("NumberValue") and item.Value or fallback end
local old=playerGui:FindFirstChild("NTR_RaceCountdown") if old then old:Destroy() end
local gui=Instance.new("ScreenGui") gui.Name="NTR_RaceCountdown" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=205 gui.Parent=playerGui
local canvas=Instance.new("Frame") canvas.AnchorPoint=Vector2.new(.5,.5) canvas.Position=UDim2.fromScale(.5,.5) canvas.Size=UDim2.fromOffset(1920,1080) canvas.BackgroundTransparency=1 canvas.Parent=gui
local scale=Instance.new("UIScale") scale.Parent=canvas
local function resize() local camera=Workspace.CurrentCamera local v=camera and camera.ViewportSize or Vector2.new(1920,1080) scale.Scale=math.min(v.X/1920,v.Y/1080) end resize() if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
local size=N("CountdownCardSize",260)
local card=Instance.new("Frame") card.Name="CountdownCard" card.AnchorPoint=Vector2.new(.5,.5) card.Position=UDim2.fromScale(.5,.5) card.Size=UDim2.fromOffset(size,size) card.BackgroundColor3=C("PanelDeep") card.BackgroundTransparency=N("CountdownCardTransparency",.18) card.BorderSizePixel=0 card.ClipsDescendants=true card.Visible=false card.Parent=canvas
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,18) corner.Parent=card
local gradient=Instance.new("UIGradient") gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C("PanelBlue")),ColorSequenceKeypoint.new(.52,C("PanelDeep")),ColorSequenceKeypoint.new(1,C("PanelSoft"))}) gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.52,.18),NumberSequenceKeypoint.new(1,.05)}) gradient.Rotation=N("CountdownGradientRotation",115) gradient.Parent=card
local heading=UI.Label(card,{Text="GET READY",Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,0,0,38),TextSize=18,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center})
local number=UI.Label(card,{Text="5",Position=UDim2.fromScale(0,0),Size=UDim2.fromScale(1,1),TextSize=N("CountdownTextSize",130),Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Center}) number.TextXAlignment=Enum.TextXAlignment.Center number.TextYAlignment=Enum.TextYAlignment.Center
local token=0
local function hide() token+=1 card.Visible=false end
local function show(text,isGo) token+=1 local mine=token card.Visible=true heading.Text=isGo and "" or "GET READY" number.Text=text number.TextSize=isGo and N("GoTextSize",96) or N("CountdownTextSize",130) number.TextColor3=isGo and C("Telemetry") or C("Text") if isGo then task.delay(N("GoDuration",.85),function() if token==mine then card.Visible=false end end) end end
local function schedule(payload)
	token+=1
	local mine=token
	local goAt=tonumber(payload.GoAtServerTime)
	local maximum=math.max(1,math.floor(tonumber(payload.Countdown) or N("CountdownSeconds",5)))
	if not goAt then show(tostring(maximum),false) return end
	task.spawn(function()
		local previous=nil
		while token==mine do
			local remaining=goAt-Workspace:GetServerTimeNow()
			if remaining<=0 then return end
			local seconds=math.clamp(math.ceil(remaining),1,maximum)
			if seconds~=previous then
				previous=seconds
				card.Visible=true heading.Text="GET READY" number.Text=tostring(seconds) number.TextSize=N("CountdownTextSize",130) number.TextColor3=C("Text")
			end
			task.wait(.03)
		end
	end)
end
event.OnClientEvent:Connect(function(payload)
	if type(payload)~="table" then return end local kind=tostring(payload.Type or "")
	if kind=="TimeTrialStaged" or kind=="RaceStaged" or kind=="TimeTrialCountdownReveal" or kind=="RaceCountdownReveal" then hide()
	elseif kind=="TimeTrialCountdownScheduled" or kind=="RaceCountdownScheduled" then schedule(payload)
	elseif kind=="TimeTrialCountdown" or kind=="RaceCountdown" then show(tostring(payload.Countdown or ""),false)
	elseif kind=="TimeTrialStarted" or kind=="RaceStarted" then show("GO!",true)
	elseif kind=="TimeTrialFinished" or kind=="TimeTrialEnded" or kind=="TimeTrialError" or kind=="RaceFinished" or kind=="RaceDNF" or kind=="RaceEnded" or kind=="RaceExitedToStart" or kind=="RaceQueueError" then hide() end
end)
script:SetAttribute("NTR_CountdownPresentationReady",true)
print("[NTR Race Readiness] Synchronized countdown presenter active.")
]=]

compile(countdown.Name, COUNTDOWN_SOURCE)
projected[countdown] = string.find(countdown.Source, REVISION, 1, true) and countdown.Source or COUNTDOWN_SOURCE

for object, source in pairs(projected) do
	compile(object.Name .. "_projected", source)
	assert(string.find(source, REVISION, 1, true), object.Name .. " projected revision marker missing")
end

if MODE == "AUDIT" then
	info("AUDIT PASS: all four projected sources compile and the confirmed Loading Phase 4 foundation is present. No Studio objects changed.")
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local originals = {}
local function rollback(problem)
	for object, source in pairs(originals) do
		if object and object.Parent then pcall(function() object.Source = source end) end
	end
	error("[" .. PHASE .. "] rolled back: " .. tostring(problem), 0)
end

local ok, problem = xpcall(function()
	for object, source in pairs(projected) do
		originals[object] = object.Source
		object.Source = source
	end
	for object in pairs(projected) do
		assert(string.find(object.Source, REVISION, 1, true), object.Name .. " final revision marker missing")
		compile(object.Name .. "_final", object.Source)
	end
	assert(loadingState.Parent == clientUI and loadingInvoke.Parent == clientUI, "Loading Phase 4 ownership changed during install")
end, debug.traceback)

if not ok then rollback(problem) end

info("PASS: readiness gate installed as one source-only transaction.")
info("Restart Play. Verify loading -> fully revealed synchronized 5-second countdown -> GO in Time Trial and a two-client Race test.")
info("Also verify one client leaving during staging does not block remaining racers, and reset/results/rewards remain unchanged.")
