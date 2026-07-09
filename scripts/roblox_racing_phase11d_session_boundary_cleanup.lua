-- Neo Tokyo Racers - Racing Phase 11D Session Boundary Cleanup
-- Run in Roblox Studio Command Bar in Edit mode, then restart Play.
--
-- This is a guarded source patch against isolated Racing scripts. It repairs:
-- 1) race finish cleanup so finished players leave active arrow/collision participation immediately,
-- 2) race finish fade/result hold/exit flow,
-- 3) race/time-trial participant visibility so free roam cannot see race VFX,
-- 4) race grid collision participant registration after server-spawned grid vehicles are fully staged.

local PHASE = "NTR Racing Phase 11D"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function child(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		fail("Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
	end
	if className and not item:IsA(className) then
		fail(item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
	end
	return item
end

local function findScript(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = child(current, token)
	end
	if not (current:IsA("Script") or current:IsA("LocalScript") or current:IsA("ModuleScript")) then
		fail(path .. " is not a script")
	end
	return current
end

local function replaceOnce(source, needle, replacement, label)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label)
	end
	local second = string.find(source, needle, endIndex + 1, true)
	if second then
		fail("Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1)
end

local function replaceFunctionBefore(source, functionName, nextFunctionName, replacement, label)
	local startIndex = string.find(source, "local function " .. functionName .. "(", 1, true)
	if not startIndex then
		fail("Could not find function start: " .. label)
	end
	local nextIndex = string.find(source, "\n\nlocal function " .. nextFunctionName .. "(", startIndex, true)
	if not nextIndex then
		nextIndex = string.find(source, "\nlocal function " .. nextFunctionName .. "(", startIndex, true)
	end
	if not nextIndex then
		fail("Could not find next function boundary: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, nextIndex)
end

local function replaceBlockBefore(source, startNeedle, endNeedle, replacement, label)
	local startIndex = string.find(source, startNeedle, 1, true)
	if not startIndex then
		fail("Could not find block start: " .. label)
	end
	local endIndex = string.find(source, endNeedle, startIndex, true)
	if not endIndex then
		fail("Could not find block end: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local function patchRaceSessionAssetService()
	local scriptObj = findScript("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11D_REMOVE_PARTICIPANT", 1, true) then
		info("RaceSessionAssetService already has Phase 11D participant removal.")
		return
	end

	local anchor = [==[local function clearForRun(payload)
	payload = typeof(payload) == "table" and payload or {}
	local runId = tostring(payload.RunId or "")
	local state = sessions[runId]
	if not state then
		return { Ok = true, Cleared = 0 }
	end
	local cleared = #state.Assets
	if state.ProxyFolder and state.ProxyFolder.Parent then
		state.ProxyFolder:Destroy()
	end
	for _, model in ipairs(state.ParticipantModels or {}) do
		if model and model.Parent then
			restoreModelGroup(model)
		end
	end
	sessions[runId] = nil
	info("Cleared " .. tostring(cleared) .. " arrow barrier proxies for " .. runId .. ".")
	return { Ok = true, Cleared = cleared }
end
]==]
	local replacement = [==[local function removeParticipant(payload)
	-- NTR_RACING_PHASE11D_REMOVE_PARTICIPANT
	payload = typeof(payload) == "table" and payload or {}
	local runId = tostring(payload.RunId or "")
	local state = sessions[runId]
	if not state then
		return { Ok = true, Removed = false, Message = "No active session." }
	end
	local player = payload.Player
	local userId = tonumber(payload.UserId) or (player and player.UserId) or 0
	if userId > 0 then
		state.ParticipantSegments[userId] = nil
	end
	if player and player.Character then
		restoreModelGroup(player.Character)
	end
	local vehicle = payload.Vehicle
	if vehicle then
		restoreModelGroup(vehicle)
	end
	rebuildProxies(state)
	return { Ok = true, Removed = true }
end

local function clearForRun(payload)
	payload = typeof(payload) == "table" and payload or {}
	local runId = tostring(payload.RunId or "")
	local state = sessions[runId]
	if not state then
		return { Ok = true, Cleared = 0 }
	end
	local cleared = #state.Assets
	if state.ProxyFolder and state.ProxyFolder.Parent then
		state.ProxyFolder:Destroy()
	end
	for _, model in ipairs(state.ParticipantModels or {}) do
		if model and model.Parent then
			restoreModelGroup(model)
		end
	end
	sessions[runId] = nil
	info("Cleared " .. tostring(cleared) .. " arrow barrier proxies for " .. runId .. ".")
	return { Ok = true, Cleared = cleared }
end
]==]
	source = replaceOnce(source, anchor, replacement, "insert removeParticipant before clearForRun")

	anchor = [==[	elseif action == "UpdateParticipantSegment" then
		return updateParticipantSegment(payload)
	end
	return { Ok = false, Message = "Unknown session asset action." }
end
]==]
	replacement = [==[	elseif action == "UpdateParticipantSegment" then
		return updateParticipantSegment(payload)
	elseif action == "RemoveParticipant" then
		return removeParticipant(payload)
	end
	return { Ok = false, Message = "Unknown session asset action." }
end
]==]
	source = replaceOnce(source, anchor, replacement, "session asset RemoveParticipant dispatch")
	scriptObj.Source = source
	info("Patched RaceSessionAssetService participant removal.")
end

local function patchRaceMatchmakingService()
	local scriptObj = findScript("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11D_FINISH_BOUNDARY", 1, true) then
		info("RaceMatchmakingService already has Phase 11D finish boundary.")
		return
	end

	source = replaceOnce(source, [==[local activeRaceByPlayer = {}
local activeRaces = {}
local gateConnections = {}
]==], [==[local activeRaceByPlayer = {}
local activeRaces = {}
local finishedReturnByPlayer = {} -- NTR_RACING_PHASE11D_FINISHED_RETURN_STATE
local gateConnections = {}
]==], "finished return state table")

	source = replaceOnce(source, [==[local function fireActiveRaceVisibility(race)
	local participants = {}
	for _, entry in ipairs(race and race.Participants or {}) do
		if entry.Player and entry.DNF ~= true then
			table.insert(participants, entry.Player.UserId)
		end
	end
	raceEvent:FireAllClients({
		Type = "RaceVisibilityUpdate",
		Active = #participants > 0,
		RunId = race and race.RunId or "",
		Participants = participants,
	})
end
]==], [==[local function fireActiveRaceVisibility(race)
	-- NTR_RACING_PHASE11D_ACTIVE_VISIBILITY
	local participants = {}
	for _, entry in ipairs(race and race.Participants or {}) do
		if entry.Player and entry.DNF ~= true and entry.Finished ~= true then
			table.insert(participants, entry.Player.UserId)
		end
	end
	raceEvent:FireAllClients({
		Type = "RaceVisibilityUpdate",
		Active = #participants > 0,
		RunId = race and race.RunId or "",
		Participants = participants,
	})
end
]==], "fireActiveRaceVisibility excludes finished racers")

	source = replaceFunctionBefore(source, "exitRacePlayer", "callRaceRewardService", [==[local function exitRacePlayer(player)
	-- NTR_RACING_PHASE11D_EXIT_TO_START
	local race = activeRaceByPlayer[player]
	local entry = entryForPlayer(race, player)
	if not (race and entry) then
		local finishedReturn = finishedReturnByPlayer[player]
		if finishedReturn then
			finishedReturnByPlayer[player] = nil
			teleportCharacterTo(player, finishedReturn.Target)
			fireRace(player, {
				Type = "RaceExitedToStart",
				RunId = finishedReturn.RunId,
				EventId = finishedReturn.EventId,
				RouteId = finishedReturn.RouteId,
				Reason = "Exited results",
			})
			fire(player, {
				Type = "RaceExitedToStart",
				RunId = finishedReturn.RunId,
				EventId = finishedReturn.EventId,
				RouteId = finishedReturn.RouteId,
				Message = "Returned to race start.",
			})
			return { Ok = true, Success = true, Message = "Exited to race start." }
		end
		return { Ok = false, Success = false, Message = "No active race." }
	end
	local wasFinished = entry.Finished == true and entry.DNF ~= true
	entry.Finished = true
	entry.DNF = wasFinished and false or true
	activeRaceByPlayer[player] = nil
	local target = returnCFrameForRoute(race.Route, "Race")
	finishedReturnByPlayer[player] = nil
	callSessionAssetService("RemoveParticipant", {
		RunId = race.RunId,
		UserId = player.UserId,
		Player = player,
		Vehicle = entry.Vehicle,
	})
	if wasFinished ~= true then
		fire(player, {
			Type = "RaceDNF",
			RunId = race.RunId,
			EventId = race.EventId,
			Message = "Exited race.",
		})
	end
	destroyVehicleAfterUnseat(player, entry.Vehicle)
	entry.Vehicle = nil
	teleportCharacterTo(player, target)
	fireRace(player, {
		Type = "RaceExitedToStart",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Reason = wasFinished and "Exited results" or "Exited race",
	})
	fire(player, {
		Type = "RaceExitedToStart",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Message = "Returned to race start.",
	})
	fireActiveRaceVisibility(race)
	broadcastPositions(race)
	if allFinished(race) then
		cleanupRace(race, "All racers finished or exited.")
	end
	return { Ok = true, Success = true, Message = "Exited to race start." }
end
]==], "exitRacePlayer clean finished exit")

	source = replaceOnce(source, [==[local function finishEntry(race, entry)
	-- NTR_RACING_PHASE11A_FINISH_ENTRY_CANONICAL
	if entry.Finished then return end
	entry.Finished = true
	entry.FinishElapsed = now() - race.StartClock
	entry.FinishPlace = race.NextFinishPlace
	race.NextFinishPlace += 1
	local rewardResult = callRaceRewardService("GrantRaceReward", {
		Player = entry.Player,
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
	}) or {}
	if entry.Vehicle then
		prepareVehicleForDriving(entry.Player, entry.Vehicle)
	end
	fire(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		DisplayName = race.DisplayName,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
		GateCount = race.GateCount,
		RaceMedal = rewardResult.Medal,
		RewardGranted = rewardResult.Granted == true,
		RewardAmount = tonumber(rewardResult.Amount) or 0,
		RewardMessage = tostring(rewardResult.Message or ""),
	})
	fireRace(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		NextGateIndex = race.GateCount,
		GateCount = race.GateCount,
	})
	broadcastPositions(race)
	if allFinished(race) then
		task.delay(5, function()
			cleanupRace(race, "Finished")
		end)
	end
end
]==], [==[local function finishEntry(race, entry)
	-- NTR_RACING_PHASE11D_FINISH_BOUNDARY
	if entry.Finished then return end
	entry.Finished = true
	entry.DNF = false
	entry.FinishElapsed = now() - race.StartClock
	entry.FinishPlace = race.NextFinishPlace
	race.NextFinishPlace += 1
	local finishVehicle = entry.Vehicle
	finishedReturnByPlayer[entry.Player] = {
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Target = returnCFrameForRoute(race.Route, "Race"),
	}
	callSessionAssetService("RemoveParticipant", {
		RunId = race.RunId,
		UserId = entry.Player and entry.Player.UserId,
		Player = entry.Player,
		Vehicle = finishVehicle,
	})
	fireActiveRaceVisibility(race)
	local rewardResult = callRaceRewardService("GrantRaceReward", {
		Player = entry.Player,
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
	}) or {}
	fire(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		DisplayName = race.DisplayName,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
		GateCount = race.GateCount,
		RaceMedal = rewardResult.Medal,
		RewardGranted = rewardResult.Granted == true,
		RewardAmount = tonumber(rewardResult.Amount) or 0,
		RewardMessage = tostring(rewardResult.Message or ""),
	})
	fireRace(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		NextGateIndex = race.GateCount,
		GateCount = race.GateCount,
	})
	task.delay(0.45, function()
		if finishVehicle and finishVehicle.Parent and entry.Vehicle == finishVehicle then
			destroyVehicleAfterUnseat(entry.Player, finishVehicle)
			entry.Vehicle = nil
		end
	end)
	broadcastPositions(race)
	if allFinished(race) then
		task.delay(5, function()
			cleanupRace(race, "Finished")
		end)
	end
end
]==], "finishEntry boundary replacement")

	source = replaceOnce(source, [==[	for index, entry in ipairs(participants) do
		activeRaceByPlayer[entry.Player] = race
		local root = vehicleRootPart(entry.Vehicle)
		if root then
			entry.Vehicle.PrimaryPart = root
			entry.Vehicle:PivotTo(spawnCFrameForIndex(queue.Route, index) + Vector3.new(0, 4, 0))
		end
		entry.Vehicle:SetAttribute("ParkedShowcase", nil)
		entry.Vehicle:SetAttribute("DriverUserId", entry.Player.UserId)
		entry.Vehicle:SetAttribute("NTR_RaceRunId", runId)
		entry.Vehicle:SetAttribute("NTR_RaceParticipant", true)
		entry.Vehicle:SetAttribute("NTR_RaceMode", "Race")
		seatPlayer(entry.Player, entry.Vehicle)
		task.wait(0.04)
		setVehicleFrozen(entry.Vehicle, true)
	end

	fireVisibility(race, true)
]==], [==[	for index, entry in ipairs(participants) do
		activeRaceByPlayer[entry.Player] = race
		local root = vehicleRootPart(entry.Vehicle)
		if root then
			entry.Vehicle.PrimaryPart = root
			entry.Vehicle:PivotTo(spawnCFrameForIndex(queue.Route, index) + Vector3.new(0, 4, 0))
		end
		entry.Vehicle:SetAttribute("ParkedShowcase", nil)
		entry.Vehicle:SetAttribute("DriverUserId", entry.Player.UserId)
		entry.Vehicle:SetAttribute("NTR_RaceRunId", runId)
		entry.Vehicle:SetAttribute("NTR_RaceParticipant", true)
		entry.Vehicle:SetAttribute("NTR_RaceMode", "Race")
		seatPlayer(entry.Player, entry.Vehicle)
		task.wait(0.04)
		setVehicleFrozen(entry.Vehicle, true)
	end

	callSessionAssetService("ApplyParticipants", {
		RunId = race.RunId,
		Participants = participants,
	})
	for _, entry in ipairs(participants) do
		callSessionAssetService("UpdateParticipantSegment", {
			RunId = race.RunId,
			UserId = entry.Player.UserId,
			CurrentSegment = 0,
		})
	end

	fireVisibility(race, true)
]==], "race grid post-stage participant collision reapply")

	source = replaceOnce(source, [==[Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player, "Player left.")
	local race = activeRaceByPlayer[player]
]==], [==[Players.PlayerRemoving:Connect(function(player)
	finishedReturnByPlayer[player] = nil
	removeFromQueue(player, "Player left.")
	local race = activeRaceByPlayer[player]
]==], "clear finished return state on player removing")

	scriptObj.Source = source
	info("Patched RaceMatchmakingService finish/exit/session boundary.")
end

local function patchRaceSessionAssetsClient()
	local scriptObj = findScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionAssetsClient_Active")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11D_ARROW_CLIENT_CLEAR_FINISH", 1, true) then
		info("RaceSessionAssetsClient already clears on RaceFinished.")
		return
	end
	source = replaceOnce(source, [==[	elseif kind == "TimeTrialEnded" or kind == "TimeTrialFinished" or kind == "RaceEnded" or kind == "RaceDNF" then
		activeRunId = nil
		activeRouteId = nil
		currentSegment = 0
		apply()
	end
]==], [==[	elseif kind == "TimeTrialEnded" or kind == "TimeTrialFinished" or kind == "RaceFinished" or kind == "RaceEnded" or kind == "RaceDNF" or kind == "RaceExitedToStart" then
		-- NTR_RACING_PHASE11D_ARROW_CLIENT_CLEAR_FINISH
		activeRunId = nil
		activeRouteId = nil
		currentSegment = 0
		apply()
	end
]==], "RaceSessionAssetsClient clear on RaceFinished")
	scriptObj.Source = source
	info("Patched RaceSessionAssetsClient finish clearing.")
end

local function patchRaceQueueClient()
	local scriptObj = findScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceQueueClient_Active")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11D_FINISH_EXIT_UI", 1, true) then
		info("RaceQueueClient already has Phase 11D finish exit UI.")
		return
	end
	source = replaceBlockBefore(source, "local state = {", "\n\nlocal ticker = nil", [==[local state = {
	Queued = false,
	ActiveRun = nil,
	StartLocalClock = nil,
	FinishedRun = nil, -- NTR_RACING_PHASE11D_FINISH_EXIT_UI
}
]==], "RaceQueue state FinishedRun")
	source = replaceBlockBefore(source, "leave.MouseButton1Click:Connect(function()", "\n\nqueueEvent.OnClientEvent:Connect(function(payload)", [==[leave.MouseButton1Click:Connect(function()
	-- NTR_RACING_PHASE11D_FINISH_EXIT_UI
	if state.FinishedRun then
		leave.Active = false
		leave.AutoButtonColor = false
		status.Text = "RETURNING TO START"
		local result = invokeQueue("ExitRaceToStart", {})
		if result.Ok ~= true and result.Success ~= true then
			leave.Active = true
			leave.AutoButtonColor = true
			status.Text = tostring(result.Message or "Could not exit race.")
		end
		return
	end
	local action = state.ActiveRun and "ExitRaceToStart" or "LeaveQueue"
	local result = invokeQueue(action, {})
	state.Queued = false
	status.Text = tostring(result.Message or "Left queue.")
	task.delay(1.2, function()
		if state.Queued ~= true and not state.ActiveRun and not state.FinishedRun then
			setVisible(false)
		end
	end)
end)
]==], "RaceQueue leave button behavior")
	source = replaceBlockBefore(source, "queueEvent.OnClientEvent:Connect(function(payload)", "\n\nprint(\"[NTR Racing Phase 8 Client] Race queue client active.\")", [==[queueEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "QueueJoined" or kind == "QueueUpdate" then
		state.Queued = true
		state.ActiveRun = nil
		state.FinishedRun = nil
		gui.DisplayOrder = 88
		leave.Text = "LEAVE"
		leave.Active = true
		leave.AutoButtonColor = true
		stopTicker()
		setQueueText(payload)
	elseif kind == "QueueLeft" then
		state.Queued = false
		state.FinishedRun = nil
		status.Text = tostring(payload.Message or "Left queue.")
		task.delay(1.2, function()
			if state.Queued ~= true and not state.ActiveRun and not state.FinishedRun then
				setVisible(false)
			end
		end)
	elseif kind == "RaceQueueError" then
		state.Queued = false
		state.ActiveRun = nil
		state.FinishedRun = nil
		stopTicker()
		status.Text = tostring(payload.Message or "Race queue unavailable.")
		setVisible(true)
	elseif kind == "RaceStaged" then
		state.Queued = false
		state.ActiveRun = payload
		state.FinishedRun = nil
		state.StartLocalClock = nil
		gui.DisplayOrder = 88
		leave.Text = "QUIT RACE"
		leave.Active = true
		leave.AutoButtonColor = true
		title.Text = tostring(payload.DisplayName or "RACE")
		status.Text = "STAGING"
		details.Text = "Racers: " .. tostring(payload.ParticipantCount or "?") .. "  |  Checkpoints: " .. tostring(payload.GateCount or "?")
		setVisible(true)
	elseif kind == "RaceCountdown" then
		title.Text = tostring(payload.DisplayName or "RACE")
		status.Text = tostring(payload.Countdown or 3)
		details.Text = "Get ready."
		setVisible(true)
	elseif kind == "RaceStarted" then
		state.ActiveRun = payload
		state.FinishedRun = nil
		gui.DisplayOrder = 88
		leave.Text = "QUIT RACE"
		leave.Active = true
		leave.AutoButtonColor = true
		state.StartLocalClock = os.clock()
		title.Text = tostring(payload.DisplayName or "RACE")
		details.Text = "Position updates appear at checkpoints."
		setVisible(true)
		task.defer(requestStreamAroundRoute, payload.RouteId, payload.NextGateIndex or 1)
		task.defer(fireDrivingHandoff)
		task.delay(0.25, fireDrivingHandoff)
		startTicker()
	elseif kind == "RaceCheckpoint" then
		details.Text = "Checkpoint " .. tostring((payload.NextGateIndex or 1) - 1) .. "/" .. tostring(payload.GateCount or "?")
	elseif kind == "RacePositionUpdate" then
		status.Text = "POSITION  " .. tostring(payload.Place or "?") .. "/" .. tostring(payload.ParticipantCount or "?")
	elseif kind == "RaceFinished" then
		-- NTR_RACING_PHASE11D_FINISH_EXIT_UI
		stopTicker()
		state.ActiveRun = nil
		state.FinishedRun = payload
		gui.DisplayOrder = 230
		leave.Text = "EXIT"
		leave.Active = true
		leave.AutoButtonColor = true
		title.Text = tostring(payload.DisplayName or "RACE COMPLETE")
		status.Text = "FINISHED  P" .. tostring(payload.Place or "?") .. "/" .. tostring(payload.ParticipantCount or "?")
		local rewardAmount = tonumber(payload.RewardAmount) or 0
		local medal = tostring(payload.RaceMedal or "")
		local rewardLine
		if payload.RewardGranted == true and rewardAmount > 0 then
			rewardLine = (medal ~= "" and (medal .. "  |  ") or "") .. "REWARD  $" .. tostring(math.floor(rewardAmount + 0.5))
		elseif payload.RewardMessage and payload.RewardMessage ~= "" then
			rewardLine = tostring(payload.RewardMessage)
		else
			rewardLine = "No cash reward for this placement."
		end
		details.Text = "Time: " .. formatTime(payload.Elapsed) .. "\n" .. rewardLine
		setVisible(true)
	elseif kind == "RaceDNF" then
		stopTicker()
		state.ActiveRun = nil
		state.FinishedRun = nil
		status.Text = "DNF"
		details.Text = tostring(payload.Message or "Race ended.")
	elseif kind == "RaceExitedToStart" then
		stopTicker()
		state.Queued = false
		state.ActiveRun = nil
		state.FinishedRun = nil
		gui.DisplayOrder = 88
		leave.Text = "LEAVE"
		leave.Active = true
		leave.AutoButtonColor = true
		setVisible(false)
	elseif kind == "RaceEnded" then
		stopTicker()
		state.Queued = false
		state.ActiveRun = nil
		if state.FinishedRun then
			setVisible(true)
			return
		end
		task.delay(4, function()
			if state.Queued ~= true and not state.ActiveRun and not state.FinishedRun then
				setVisible(false)
			end
		end)
	end
end)
]==], "RaceQueue canonical event handler")
	scriptObj.Source = source
	info("Patched RaceQueueClient finish result/exit button flow.")
end

local function patchRaceTransitionClient()
	local scriptObj = findScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTransitionClient_Active")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11D_FINISH_HOLD", 1, true) then
		info("RaceTransitionClient already has Phase 11D finish hold.")
		return
	end
	source = replaceOnce(source, [==[local currentFadeTween = nil
]==], [==[local currentFadeTween = nil
local finishHold = false -- NTR_RACING_PHASE11D_FINISH_HOLD
]==], "transition finishHold state")
	source = replaceOnce(source, [==[	if kind == "TimeTrialStaged" or kind == "RaceStaged" then
		startTransition(kind)
	elseif kind == "TimeTrialCountdown" or kind == "RaceCountdown" then
]==], [==[	if kind == "TimeTrialStaged" or kind == "RaceStaged" then
		finishHold = false
		startTransition(kind)
	elseif kind == "TimeTrialCountdown" or kind == "RaceCountdown" then
]==], "transition clear hold on staged")
	source = replaceOnce(source, [==[	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		finishTransition(kind)
	elseif kind == "TimeTrialReset" or kind == "RaceReset" then
]==], [==[	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		finishHold = false
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		finishTransition(kind)
	elseif kind == "TimeTrialReset" or kind == "RaceReset" then
]==], "transition clear hold on started")
	source = replaceOnce(source, [==[	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError"
		or kind == "RaceFinished" or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceQueueError" then
		setSessionActive(false, kind)
		restoreCamera(kind)
		fadeIn(0.18)
	end
]==], [==[	elseif kind == "RaceFinished" then
		-- NTR_RACING_PHASE11D_FINISH_HOLD
		finishHold = true
		setSessionActive(true, kind)
		suppressFreeRoamHud()
		fadeOut("")
	elseif kind == "RaceExitedToStart" then
		finishHold = false
		setSessionActive(false, kind)
		restoreCamera(kind)
		fadeIn(0.28)
	elseif kind == "RaceEnded" and finishHold then
		suppressFreeRoamHud()
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError"
		or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceQueueError" then
		finishHold = false
		setSessionActive(false, kind)
		restoreCamera(kind)
		fadeIn(0.18)
	end
]==], "transition finish hold event handling")
	scriptObj.Source = source
	info("Patched RaceTransitionClient finish fade hold.")
end

local function installParticipantVisibilityClient()
	local racingFolder = child(child(child(child(game, "StarterPlayer"), "StarterPlayerScripts"), "NeoTokyoRacersClient"), "Controllers")
	racingFolder = child(racingFolder, "Racing")
	local scriptObj = racingFolder:FindFirstChild("RaceParticipantVisibilityClient_Active")
	if not scriptObj then
		scriptObj = Instance.new("LocalScript")
		scriptObj.Name = "RaceParticipantVisibilityClient_Active"
		scriptObj.Parent = racingFolder
	end
	scriptObj.Disabled = false
	scriptObj.Source = [==[-- NTR_RACING_PHASE11D_PARTICIPANT_VISIBILITY_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local active = false
local activeParticipants = {}
local original = {}
local lastApply = 0

local function runtimeVehicles()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function participantSet(list)
	table.clear(activeParticipants)
	for _, userId in ipairs(list or {}) do
		activeParticipants[tonumber(userId)] = true
	end
end

local function remember(item, key, value)
	local data = original[item]
	if not data then
		data = {}
		original[item] = data
	end
	if data[key] == nil then
		data[key] = value
	end
end

local function setObjectHidden(item, hidden)
	if item:IsA("BasePart") then
		item.LocalTransparencyModifier = hidden and 1 or 0
	elseif item:IsA("Decal") or item:IsA("Texture") then
		remember(item, "Transparency", item.Transparency)
		item.Transparency = hidden and 1 or (original[item] and original[item].Transparency or item.Transparency)
	elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
		remember(item, "Enabled", item.Enabled)
		local data = original[item]
		item.Enabled = hidden and false or (data and data.Enabled or item.Enabled)
	elseif item:IsA("BillboardGui") or item:IsA("SurfaceGui") then
		remember(item, "Enabled", item.Enabled)
		local data = original[item]
		item.Enabled = hidden and false or (data and data.Enabled or item.Enabled)
	end
end

local function setModelHidden(model, hidden)
	for _, item in ipairs(model and model:GetDescendants() or {}) do
		setObjectHidden(item, hidden)
	end
end

local function ownerForVehicle(vehicle)
	return tonumber(vehicle and vehicle:GetAttribute("OwnerUserId"))
end

local function apply()
	if active ~= true then
		for _, other in ipairs(Players:GetPlayers()) do
			setModelHidden(other.Character, false)
		end
		for _, vehicle in ipairs(runtimeVehicles() and runtimeVehicles():GetChildren() or {}) do
			setModelHidden(vehicle, false)
		end
		return
	end
	local localIsParticipant = activeParticipants[player.UserId] == true
	for _, other in ipairs(Players:GetPlayers()) do
		local otherIsParticipant = activeParticipants[other.UserId] == true
		setModelHidden(other.Character, (localIsParticipant and not otherIsParticipant) or ((not localIsParticipant) and otherIsParticipant))
	end
	for _, vehicle in ipairs(runtimeVehicles() and runtimeVehicles():GetChildren() or {}) do
		local vehicleIsParticipant = activeParticipants[ownerForVehicle(vehicle)] == true
		setModelHidden(vehicle, (localIsParticipant and not vehicleIsParticipant) or ((not localIsParticipant) and vehicleIsParticipant))
	end
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "RaceVisibilityUpdate" then
		active = payload.Active == true
		participantSet(payload.Participants or {})
		apply()
	elseif kind == "RaceFinished" or kind == "RaceDNF" or kind == "RaceExitedToStart" or kind == "RaceEnded" or kind == "TimeTrialFinished" or kind == "TimeTrialEnded" then
		if activeParticipants[player.UserId] == true then
			activeParticipants[player.UserId] = nil
		end
		if next(activeParticipants) == nil then
			active = false
		end
		apply()
	end
end)

RunService.Heartbeat:Connect(function()
	if os.clock() - lastApply > 0.25 then
		lastApply = os.clock()
		apply()
	end
end)

print("[NTR Racing Phase 11D Client] Participant body/VFX visibility isolation active.")
]==]
	info("Installed RaceParticipantVisibilityClient_Active.")
end

patchRaceSessionAssetService()
patchRaceMatchmakingService()
patchRaceSessionAssetsClient()
patchRaceQueueClient()
patchRaceTransitionClient()
installParticipantVisibilityClient()

info("Install complete. Restart Play and test a 2-player race finish/exit flow.")
