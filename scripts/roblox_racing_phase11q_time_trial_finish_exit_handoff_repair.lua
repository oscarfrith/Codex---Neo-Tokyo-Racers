-- Neo Tokyo Racers - Racing Phase 11Q Time Trial Finish/Exit Handoff Repair
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- Why:
--   Phase 11P copy polish installed, but testing showed the time-trial result
--   flow could leave the main driving controller/HUD thinking the player was
--   still driving after exiting results. The refreshed mirror shows race start
--   fires FreeRoamVehicleSpawned, but result finish/exit does not fire the
--   matching FreeRoamVehicleExited handoff.
--
-- What this does:
--   1. Rolls back Phase 11P result copy polish to the previous confirmed result UI text.
--   2. Adds a tiny FreeRoamVehicleExited handoff in the isolated race entry client.
--   3. Fires that handoff on time-trial finish, result exit, and time-trial end.
--
-- Scope:
--   Patches only RaceEntryMenuClient_Active.
--   No reward config, route-guide config, arrows, VFX, matchmaking, driving physics,
--   DataStore, global leaderboard, or bootstrap edits.

local PHASE = "NTR Racing Phase 11Q"
local MARKER = "NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF"

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function findPath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return nil
		end
	end
	return current
end

local function replaceOnce(source, old, new, label)
	local startIndex, endIndex = string.find(source, old, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. tostring(label))
	end
	return string.sub(source, 1, startIndex - 1) .. new .. string.sub(source, endIndex + 1)
end

local function rollbackPhase11PIfPresent(source)
	if not string.find(source, "NTR_RACING_PHASE11P_RESULT_COACH_TEXT", 1, true) then
		return source, false
	end

	source = replaceOnce(
		source,
		[[local resultExit = button(resultPanel, "EXIT TO START", UDim2.new(0.5, -18, 0, 46), UDim2.new(0.5, 4, 1, -60), theme.Exit)
-- NTR_RACING_PHASE11P_RESULT_COACH_TEXT]],
		[[local resultExit = button(resultPanel, "EXIT", UDim2.new(0.5, -18, 0, 46), UDim2.new(0.5, 4, 1, -60), theme.Exit)]],
		"Phase 11P exit button rollback"
	)

	source = replaceOnce(
		source,
		[[	resultTime.Text = formatTime(payload.Elapsed)
	local elapsed = tonumber(payload.Elapsed) or 0
	local previousBest = tonumber(payload.PreviousBestSeconds)
	local best = tonumber(payload.PersonalBestSeconds)
	if payload.IsPersonalBest == true then
		local delta = previousBest and elapsed > 0 and (previousBest - elapsed) or nil
		if delta and delta > 0.0005 then
			resultBest.Text = "NEW PERSONAL BEST  " .. formatTime(best or elapsed) .. "  (-" .. formatTime(delta) .. ")"
		else
			resultBest.Text = "NEW PERSONAL BEST  " .. formatTime(best or elapsed)
		end
	elseif best then
		local gap = elapsed > 0 and (elapsed - best) or nil
		if gap and gap > 0.0005 then
			resultBest.Text = "PERSONAL BEST  " .. formatTime(best) .. "  (+" .. formatTime(gap) .. ")"
		else
			resultBest.Text = "PERSONAL BEST  " .. formatTime(best)
		end
	else
		resultBest.Text = "PERSONAL BEST  --"
	end
	local nextDelta = math.abs(tonumber(payload.NextMedalDelta) or 0)
	if payload.NextMedalName and payload.NextMedalSeconds then
		resultNext.Text = "NEXT " .. string.upper(tostring(payload.NextMedalName)) .. "  " .. formatTime(payload.NextMedalSeconds) .. "  |  NEED -" .. formatTime(nextDelta)
	elseif medal == "Platinum" then
		resultNext.Text = "PLATINUM TARGET CLEARED."
	else
		resultNext.Text = "No medal targets configured for this tier yet."
	end]],
		[[	resultTime.Text = formatTime(payload.Elapsed)
	local best = tonumber(payload.PersonalBestSeconds)
	if payload.IsPersonalBest == true then
		resultBest.Text = "NEW PERSONAL BEST  " .. formatTime(best or payload.Elapsed)
	elseif best then
		resultBest.Text = "PERSONAL BEST  " .. formatTime(best)
	else
		resultBest.Text = "PERSONAL BEST  --"
	end
	if payload.NextMedalName and payload.NextMedalSeconds then
		resultNext.Text = "Next medal: " .. tostring(payload.NextMedalName) .. " at " .. formatTime(payload.NextMedalSeconds) .. "  (" .. formatTime(math.abs(tonumber(payload.NextMedalDelta) or 0)) .. " faster)"
	elseif medal == "Platinum" then
		resultNext.Text = "Platinum target cleared."
	else
		resultNext.Text = "No medal targets configured for this tier yet."
	end]],
		"Phase 11P result text rollback"
	)

	source = replaceOnce(
		source,
		[[	if payload.RewardGranted == true and rewardAmount > 0 then
		resultReward.Text = "PRIZE  $" .. tostring(math.floor(rewardAmount + 0.5))
	elseif payload.RewardMessage and payload.RewardMessage ~= "" then
		resultReward.Text = tostring(payload.RewardMessage)
	else
		resultReward.Text = "No cash prize this run."
	end]],
		[[	if payload.RewardGranted == true and rewardAmount > 0 then
		resultReward.Text = "REWARD  $" .. tostring(math.floor(rewardAmount + 0.5))
	elseif payload.RewardMessage and payload.RewardMessage ~= "" then
		resultReward.Text = tostring(payload.RewardMessage)
	else
		resultReward.Text = "No cash reward this run."
	end]],
		"Phase 11P reward text rollback"
	)

	return source, true
end

local function installHandoff(source)
	if string.find(source, MARKER, 1, true) then
		return source, false
	end

	local handoffAnchor = [[local function fireDrivingHandoff()
	-- NTR_RACING_PHASE3E_CLIENT_HANDOFF
	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local spawnedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
	if spawnedEvent and spawnedEvent:IsA("BindableEvent") then
		spawnedEvent:Fire()
	end
end]]

	local handoffReplacement = handoffAnchor
		.. "\n\nlocal function fireDrivingExitHandoff()\n"
		.. "\t-- " .. MARKER .. "\n"
		.. "\tlocal clientRoot = script.Parent.Parent\n"
		.. "\tlocal uiFolder = clientRoot and clientRoot:FindFirstChild(\"UI\")\n"
		.. "\tlocal exitedEvent = uiFolder and uiFolder:FindFirstChild(\"FreeRoamVehicleExited\")\n"
		.. "\tif exitedEvent and exitedEvent:IsA(\"BindableEvent\") then\n"
		.. "\t\texitedEvent:Fire()\n"
		.. "\tend\n"
		.. "end"

	source = replaceOnce(source, handoffAnchor, handoffReplacement, "FreeRoamVehicleExited handoff helper")

	source = replaceOnce(
		source,
		[[resultExit.MouseButton1Click:Connect(function()
	-- NTR_RACING_PHASE11K_RESULT_EXIT_ACTION
	hideResult()
	stopTicker()
	clearMarker()
	state.ActiveRun = nil
	hud.Visible = false
	local result = callRace("ExitFinishedTimeTrial", {})]],
		[[resultExit.MouseButton1Click:Connect(function()
	-- NTR_RACING_PHASE11K_RESULT_EXIT_ACTION
	hideResult()
	fireDrivingExitHandoff()
	stopTicker()
	clearMarker()
	state.ActiveRun = nil
	hud.Visible = false
	local result = callRace("ExitFinishedTimeTrial", {})]],
		"result exit driving handoff"
	)

	source = replaceOnce(
		source,
		[[	elseif kind == "TimeTrialFinished" then
		rememberPBFromResultPayload(payload)
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = true]],
		[[	elseif kind == "TimeTrialFinished" then
		rememberPBFromResultPayload(payload)
		fireDrivingExitHandoff()
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = true]],
		"time trial finished driving handoff"
	)

	source = replaceOnce(
		source,
		[[	elseif kind == "TimeTrialEnded" then
		hideResult()
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = false]],
		[[	elseif kind == "TimeTrialEnded" then
		hideResult()
		fireDrivingExitHandoff()
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = false]],
		"time trial ended driving handoff"
	)

	return source, true
end

local function patchRaceEntryMenuClient()
	local scriptObject = findPath("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active")
	if not scriptObject or not scriptObject:IsA("LocalScript") then
		fail("Could not find RaceEntryMenuClient_Active LocalScript.")
	end

	local source = scriptObject.Source
	local rolledBack
	source, rolledBack = rollbackPhase11PIfPresent(source)

	local installed
	source, installed = installHandoff(source)

	if rolledBack or installed then
		scriptObject.Source = source
	end

	print("[" .. PHASE .. "] RaceEntryMenuClient patch complete. rolledBackPhase11P=" .. tostring(rolledBack) .. " installedHandoff=" .. tostring(installed))
	return rolledBack or installed
end

local changed = patchRaceEntryMenuClient()
print("[" .. PHASE .. "] Complete. changed=" .. tostring(changed))
print("[" .. PHASE .. "] Restart Play. Finish a time trial, confirm the result panel appears, exit results, then confirm drive HUD clears and race browser teleport/re-entry work.")
