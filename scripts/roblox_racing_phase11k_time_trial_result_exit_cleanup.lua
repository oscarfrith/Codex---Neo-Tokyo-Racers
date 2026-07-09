-- Neo Tokyo Racers - Racing Phase 11K Time Trial Result Exit Cleanup
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- Purpose:
--   Fixes a post-finish cleanup gap where the time-trial result EXIT button called
--   CancelTimeTrial after the server had already removed the active run. That could
--   hide the UI without destroying the finished race vehicle / teleporting the player
--   back to the route start, leaving one player in a stale race/free-roam state.
--
-- Scope:
--   Patches only the isolated Racing TimeTrialService and RaceEntryMenuClient.
--   No reward config, route-guide config, arrows, matchmaking, VFX, or driving edits.

local PHASE = "NTR Racing Phase 11K"

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

local function getSource(path)
	local object = findPath(path)
	if not object then
		fail("Missing " .. path)
	end
	if not (object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript")) then
		fail(path .. " is " .. object.ClassName .. ", expected script.")
	end
	return object, object.Source
end

local function replaceOnce(source, needle, replacement, label)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label)
	end
	local before = string.sub(source, 1, startIndex - 1)
	local after = string.sub(source, endIndex + 1)
	return before .. replacement .. after
end

local function patchTimeTrialService()
	local path = "ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active"
	local scriptObject, source = getSource(path)
	if string.find(source, "NTR_RACING_PHASE11K_TT_FINISHED_EXIT_CLEANUP", 1, true) then
		print("[" .. PHASE .. "] TimeTrialService already has Phase 11K cleanup.")
		return false
	end

	source = replaceOnce(source,
		"local activeRuns = {}\nlocal activeRunsById = {}\nlocal gateConnections = {}\n",
		"local activeRuns = {}\nlocal activeRunsById = {}\nlocal finishedRunsByPlayer = {} -- NTR_RACING_PHASE11K_TT_FINISHED_EXIT_CLEANUP\nlocal gateConnections = {}\n",
		"finished run cache declaration"
	)

	source = replaceOnce(source,
		"local function resetActiveTimeTrial(player)\n",
		[[local function clearFinishedRunForPlayer(player)
	finishedRunsByPlayer[player] = nil
end

local function storeFinishedRunForExit(player, run)
	if not (player and run) then return end
	finishedRunsByPlayer[player] = run
end

local function exitFinishedTimeTrial(player)
	-- NTR_RACING_PHASE11K_TT_FINISHED_EXIT_CLEANUP
	local run = finishedRunsByPlayer[player]
	if not run then
		return { Ok = true, Success = true, Message = "No finished time trial cleanup pending." }
	end
	finishedRunsByPlayer[player] = nil
	fireVisibility(run, false)
	clearSessionFolder(run)
	local target = returnCFrameForRoute(run.Route, "TimeTrial")
	destroyVehicleAfterUnseat(player, run.Vehicle)
	local ok, message = teleportCharacterTo(player, target)
	fire(player, {
		Type = "TimeTrialEnded",
		RunId = run.RunId,
		EventId = run.EventId,
		RouteId = run.RouteId,
		Reason = "Exited results",
	})
	return {
		Ok = ok == true,
		Success = ok == true,
		Message = ok and "Exited to race start." or tostring(message or "Exit cleanup failed."),
	}
end

local function resetActiveTimeTrial(player)
]],
		"finished result exit helpers before resetActiveTimeTrial"
	)

	source = replaceOnce(source,
		"local function endRun(player, reason)\n\tlocal run = activeRuns[player]\n",
		"local function endRun(player, reason)\n\tclearFinishedRunForPlayer(player)\n\tlocal run = activeRuns[player]\n",
		"endRun clears finished cache"
	)

	source = replaceOnce(source,
		"local function finishRun(player, resultElapsed, finishReason)\n\t-- NTR_RACING_PHASE9A_FINISH_BEST_SESSION_RESULT\n\tlocal run = activeRuns[player]\n\tif not run then return end\n",
		"local function finishRun(player, resultElapsed, finishReason)\n\t-- NTR_RACING_PHASE9A_FINISH_BEST_SESSION_RESULT\n\tlocal run = activeRuns[player]\n\tif not run then return end\n\tclearFinishedRunForPlayer(player)\n",
		"finishRun clears old finished cache"
	)

	source = replaceOnce(source,
		"local function beginStagedTimeTrial(player, eventId, vehicleId, requestedLapCount)\n\t-- NTR_RACING_PHASE9A_BEGIN_SESSION\n\teventId = resolveTimeTrialEventId(eventId)\n",
		"local function beginStagedTimeTrial(player, eventId, vehicleId, requestedLapCount)\n\t-- NTR_RACING_PHASE9A_BEGIN_SESSION\n\tclearFinishedRunForPlayer(player)\n\teventId = resolveTimeTrialEventId(eventId)\n",
		"beginStagedTimeTrial clears stale finished cache"
	)

	source = replaceOnce(source,
		"\tfireVisibility(run, false)\n\tclearSessionFolder(run)\n\tsendTimeTrialResult(player, run, elapsed, finishReason or \"Finished\", true)\nend\n",
		"\tfireVisibility(run, false)\n\tclearSessionFolder(run)\n\tstoreFinishedRunForExit(player, run)\n\tsendTimeTrialResult(player, run, elapsed, finishReason or \"Finished\", true)\nend\n",
		"finishRun stores finished run for result exit"
	)

	source = replaceOnce(source,
		"\telseif action == \"CancelTimeTrial\" then\n\t\tendRun(player, \"Cancelled\")\n\t\treturn { Ok = true, Success = true, Message = \"Cancelled\" }\n",
		"\telseif action == \"CancelTimeTrial\" then\n\t\tif activeRuns[player] then\n\t\t\tendRun(player, \"Cancelled\")\n\t\t\treturn { Ok = true, Success = true, Message = \"Cancelled\" }\n\t\tend\n\t\treturn exitFinishedTimeTrial(player)\n\telseif action == \"ExitFinishedTimeTrial\" then\n\t\treturn exitFinishedTimeTrial(player)\n",
		"CancelTimeTrial finished-run fallback"
	)

	source = replaceOnce(source,
		"Players.PlayerRemoving:Connect(function(player)\n\tpersonalBests[player.UserId] = nil\n\tendRun(player, \"Player left\")\nend)\n",
		"Players.PlayerRemoving:Connect(function(player)\n\tpersonalBests[player.UserId] = nil\n\tclearFinishedRunForPlayer(player)\n\tendRun(player, \"Player left\")\nend)\n",
		"PlayerRemoving clears finished cache"
	)

	scriptObject.Source = source
	print("[" .. PHASE .. "] Patched TimeTrialService finished-result exit cleanup.")
	return true
end

local function patchRaceEntryMenuClient()
	local path = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active"
	local scriptObject, source = getSource(path)
	if string.find(source, "NTR_RACING_PHASE11K_RESULT_EXIT_ACTION", 1, true) then
		print("[" .. PHASE .. "] RaceEntryMenuClient already has Phase 11K result exit action.")
		return false
	end

	source = replaceOnce(source,
		"resultExit.MouseButton1Click:Connect(function()\n\thideResult()\n\tstopTicker()\n\tclearMarker()\n\tstate.ActiveRun = nil\n\thud.Visible = false\n\tcallRace(\"CancelTimeTrial\", {})\nend)\n",
		[[resultExit.MouseButton1Click:Connect(function()
	-- NTR_RACING_PHASE11K_RESULT_EXIT_ACTION
	hideResult()
	stopTicker()
	clearMarker()
	state.ActiveRun = nil
	hud.Visible = false
	local result = callRace("ExitFinishedTimeTrial", {})
	if result.Ok ~= true and result.Success ~= true then
		callRace("CancelTimeTrial", {})
	end
end)
]],
		"result EXIT calls finished cleanup"
	)

	scriptObject.Source = source
	print("[" .. PHASE .. "] Patched RaceEntryMenuClient result EXIT action.")
	return true
end

local changedTimeTrial = patchTimeTrialService()
local changedClient = patchRaceEntryMenuClient()

print("[" .. PHASE .. "] Complete. changedTimeTrial=" .. tostring(changedTimeTrial) .. " changedClient=" .. tostring(changedClient))
print("[" .. PHASE .. "] Restart Play, finish a time trial, press EXIT on the result panel, then verify re-entry, free-roam vehicle spawn, and TELEPORT TO START all work for both players.")
