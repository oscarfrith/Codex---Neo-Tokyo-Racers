-- Neo Tokyo Racers - Racing Phase 11Y Time Trial Finish Lifecycle Recovery
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- Scope:
--   Patches only the isolated TimeTrialService_Active server script and the
--   isolated Phase 11T RaceTimeTrialResultCoachClient_Active client.
--   No reward config, route-guide config, arrows, VFX systems, matchmaking,
--   free-roam nav, garage server, or main bootstrap edits.
--
-- Why:
--   After a finished time trial, the race vehicle could briefly become a normal
--   driveable owner vehicle while the result-exit cleanup was still pending.
--   If the result exit was missed or hidden before server cleanup confirmed,
--   the player could stay in a stale driving/session state and later fail to
--   re-enter race/time-trial menus, use race-browser teleport, or spawn a car.

local PHASE = "NTR Racing Phase 11Y"

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function replaceOnce(source, old, new, label)
	local startIndex, endIndex = string.find(source, old, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. tostring(label))
	end
	local before = string.sub(source, 1, startIndex - 1)
	local after = string.sub(source, endIndex + 1)
	local replaced = before .. new .. after
	local second = string.find(replaced, old, 1, true)
	if second then
		fail("Source anchor still present after replacement: " .. tostring(label))
	end
	return replaced
end

local function serviceRoot()
	local serverScriptService = game:GetService("ServerScriptService")
	local root = serverScriptService:FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	local racing = services and services:FindFirstChild("Racing")
	if not racing then
		fail("Missing ServerScriptService.NeoTokyoRacers.Services.Racing")
	end
	return racing
end

local function racingClientRoot()
	local starterPlayer = game:GetService("StarterPlayer")
	local scripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = scripts and scripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	if not racing then
		fail("Missing StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing")
	end
	return racing
end

local function patchTimeTrialService()
	local scriptObject = serviceRoot():FindFirstChild("TimeTrialService_Active")
	if not (scriptObject and scriptObject:IsA("Script")) then
		fail("Missing TimeTrialService_Active Script")
	end
	local source = scriptObject.Source
	if string.find(source, "NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY", 1, true) then
		print("[" .. PHASE .. "] TimeTrialService already has Phase 11Y marker.")
		return
	end

	local oldDestroyBlock = [==[
local function destroyVehicleAfterUnseat(player, vehicle)
	if not (vehicle and vehicle.Parent) then return end
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:SetAttribute("NTR_RaceRunId", nil)
	vehicle:SetAttribute("NTR_RaceParticipant", nil)
	vehicle:SetAttribute("NTR_RaceMode", nil)
	unseatPlayer(player)
	task.wait(0.08)
	if vehicle and vehicle.Parent then
		vehicle:Destroy()
	end
end
]==]

	local newDestroyBlock = [==[
local function destroyVehicleAfterUnseat(player, vehicle)
	if not (vehicle and vehicle.Parent) then return end
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:SetAttribute("NTR_RaceRunId", nil)
	vehicle:SetAttribute("NTR_RaceParticipant", nil)
	vehicle:SetAttribute("NTR_RaceMode", nil)
	vehicle:SetAttribute("NTR_RaceFinishedPendingExit", nil) -- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
	unseatPlayer(player)
	task.wait(0.08)
	if vehicle and vehicle.Parent then
		vehicle:Destroy()
	end
end

local function cleanupPendingFinishedVehiclesForPlayer(player)
	-- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
	local root = runtimeVehiclesRoot()
	local cleaned = 0
	for _, vehicle in ipairs(root and root:GetChildren() or {}) do
		local ownerMatches = tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId
		local pendingFinished = vehicle:GetAttribute("NTR_RaceFinishedPendingExit") == true
		local orphanGridVehicle = vehicle:GetAttribute("NTR_RaceGridSpawned") == true
			and vehicle:GetAttribute("NTR_RaceRunId") == nil
			and vehicle:GetAttribute("NTR_RaceParticipant") ~= true
		if ownerMatches and (pendingFinished or orphanGridVehicle) then
			cleaned += 1
			destroyVehicleAfterUnseat(player, vehicle)
		end
	end
	return cleaned
end
]==]
	source = replaceOnce(source, oldDestroyBlock, newDestroyBlock, "destroyVehicleAfterUnseat plus recovery helper")

	local oldExitFinished = [==[
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
]==]

	local newExitFinished = [==[
local function exitFinishedTimeTrial(player)
	-- NTR_RACING_PHASE11K_TT_FINISHED_EXIT_CLEANUP
	-- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
	local run = finishedRunsByPlayer[player]
	if not run then
		local cleaned = cleanupPendingFinishedVehiclesForPlayer(player)
		if cleaned > 0 then
			fire(player, {
				Type = "TimeTrialEnded",
				Reason = "Recovered stale finished time trial",
			})
		end
		return {
			Ok = true,
			Success = true,
			Message = cleaned > 0 and "Recovered stale finished time trial cleanup." or "No finished time trial cleanup pending.",
		}
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
]==]
	source = replaceOnce(source, oldExitFinished, newExitFinished, "exitFinishedTimeTrial recovery")

	local oldFinishVehicleBlock = [==[
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
		run.Vehicle:SetAttribute("NTR_RaceRunId", nil)
		run.Vehicle:SetAttribute("NTR_RaceParticipant", nil)
		run.Vehicle:SetAttribute("NTR_RaceMode", nil)
		run.Vehicle:SetAttribute("DriveReady", true)
	end
]==]

	local newFinishVehicleBlock = [==[
	if run.Vehicle then
		-- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
		-- A finished time-trial vehicle is pending result-exit cleanup, not a
		-- normal free-roam car. Keep it still/unusable and unseat the player so
		-- camera, HUD, race-browser teleport, and future entry prompts recover
		-- even if the result panel exit is clicked late or twice.
		setVehicleFrozen(run.Vehicle, true)
		run.Vehicle:SetAttribute("NTR_RaceRunId", run.RunId)
		run.Vehicle:SetAttribute("NTR_RaceParticipant", true)
		run.Vehicle:SetAttribute("NTR_RaceMode", "TimeTrialFinished")
		run.Vehicle:SetAttribute("NTR_RaceFinishedPendingExit", true)
		run.Vehicle:SetAttribute("DriverUserId", nil)
		run.Vehicle:SetAttribute("DriveReady", false)
		run.Vehicle:SetAttribute("EngineVFXActive", false)
		unseatPlayer(player)
	end
]==]
	source = replaceOnce(source, oldFinishVehicleBlock, newFinishVehicleBlock, "finishRun pending vehicle state")

	local oldSendEntryStart = [==[
local function sendEntryMenu(player, zone)
	local mode = modeForZone(zone)
	local eventId = eventIdForZone(zone)
	local summary = RaceConfigReader.GetEventSummary(eventId, mode)
	local pos = nil
	local vehicle = currentVehicleForPlayer(player)
]==]

	local newSendEntryStart = [==[
local function sendEntryMenu(player, zone)
	-- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
	-- If a previous result-exit click was missed, pressing the start prompt is
	-- allowed to self-heal before opening the next entry menu.
	if finishedRunsByPlayer[player] then
		exitFinishedTimeTrial(player)
	else
		cleanupPendingFinishedVehiclesForPlayer(player)
	end
	local mode = modeForZone(zone)
	local eventId = eventIdForZone(zone)
	local summary = RaceConfigReader.GetEventSummary(eventId, mode)
	local pos = nil
	local vehicle = currentVehicleForPlayer(player)
]==]
	source = replaceOnce(source, oldSendEntryStart, newSendEntryStart, "sendEntryMenu stale finish self-heal")

	scriptObject.Source = source
	print("[" .. PHASE .. "] Patched TimeTrialService_Active.")
end

local function patchResultCoach()
	local scriptObject = racingClientRoot():FindFirstChild("RaceTimeTrialResultCoachClient_Active")
	if not (scriptObject and scriptObject:IsA("LocalScript")) then
		fail("Missing RaceTimeTrialResultCoachClient_Active LocalScript")
	end
	local source = scriptObject.Source
	if string.find(source, "NTR_RACING_PHASE11Y_RESULT_COACH_CONFIRMED_EXIT", 1, true) then
		print("[" .. PHASE .. "] Result coach already has Phase 11Y marker.")
		return
	end

	local oldExitButton = [==[
exit.MouseButton1Click:Connect(function()
	fireDrivingExitHandoff()
	status.Text = "Returning to start..."
	hide()
	local result = callRace("ExitFinishedTimeTrial", {})
	if result.Ok ~= true and result.Success ~= true then
		callRace("CancelTimeTrial", {})
	end
end)
]==]

	local newExitButton = [==[
exit.MouseButton1Click:Connect(function()
	-- NTR_RACING_PHASE11Y_RESULT_COACH_CONFIRMED_EXIT
	fireDrivingExitHandoff()
	status.Text = "Returning to start..."
	local result = callRace("ExitFinishedTimeTrial", {})
	if result.Ok == true or result.Success == true then
		hide()
		task.delay(0.12, fireDrivingExitHandoff)
		return
	end
	local fallback = callRace("CancelTimeTrial", {})
	if fallback.Ok == true or fallback.Success == true then
		hide()
		task.delay(0.12, fireDrivingExitHandoff)
	else
		status.Text = tostring(result.Message or fallback.Message or "Exit failed. Try again.")
	end
end)
]==]

	source = replaceOnce(source, oldExitButton, newExitButton, "result coach confirmed exit")
	scriptObject.Source = source
	print("[" .. PHASE .. "] Patched RaceTimeTrialResultCoachClient_Active.")
end

patchTimeTrialService()
patchResultCoach()

print("[" .. PHASE .. "] Installed. Restart Play before testing.")
