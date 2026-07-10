-- Neo Tokyo Racers - Racing Phase 11S Stability Baseline Audit
-- Run in Roblox Studio Command Bar, Edit or Play mode.
--
-- Read-only audit after Phase 11Q/11R. This script does not modify instances,
-- source, attributes, rewards, arrows, VFX, matchmaking, or driving.
--
-- V2 note:
--   If run from a Play client, ServerScriptService is intentionally hidden by
--   Roblox replication. Server-only service/source checks are skipped there
--   instead of counted as failures. Run in Edit mode or a server context for
--   full server-source coverage.
--
-- Use it to confirm the current prototype racing baseline before the next
-- feature phase: time-trial finish/exit handoff, PB readouts, rewards, route
-- arrows/session assets, race matchmaking, and key remotes/config.

local PHASE = "NTR Racing Phase 11S Audit"
local RunService = game:GetService("RunService")

local results = {
	pass = 0,
	warn = 0,
	fail = 0,
}

local function log(kind, message)
	kind = string.upper(tostring(kind or "INFO"))
	local prefix = "[" .. PHASE .. "] " .. kind .. " "
	if kind == "PASS" then
		results.pass += 1
		print(prefix .. tostring(message))
	elseif kind == "WARN" then
		results.warn += 1
		warn(prefix .. tostring(message))
	elseif kind == "FAIL" then
		results.fail += 1
		warn(prefix .. tostring(message))
	else
		print(prefix .. tostring(message))
	end
end

local function child(parent, name, className, required)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		if required ~= false then
			log("FAIL", "Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
		else
			log("WARN", "Optional missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
		end
		return nil
	end
	if className and not item:IsA(className) then
		log("FAIL", item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. tostring(className))
		return item
	end
	log("PASS", "Found " .. item:GetFullName())
	return item
end

local function sourceHas(scriptObject, marker, label, severity)
	if not (scriptObject and scriptObject.Source) then
		log(severity or "FAIL", tostring(label or marker) .. " source unavailable")
		return false
	end
	if string.find(scriptObject.Source, marker, 1, true) then
		log("PASS", tostring(label or marker))
		return true
	end
	log(severity or "FAIL", "Missing marker/text: " .. tostring(label or marker))
	return false
end

local function sourceNotHas(scriptObject, marker, label, severity)
	if not (scriptObject and scriptObject.Source) then
		log(severity or "WARN", tostring(label or marker) .. " source unavailable")
		return false
	end
	if string.find(scriptObject.Source, marker, 1, true) then
		log(severity or "WARN", "Unexpected marker/text present: " .. tostring(label or marker))
		return false
	end
	log("PASS", "Absent as expected: " .. tostring(label or marker))
	return true
end

local function countChildren(folder, className)
	local count = 0
	for _, item in ipairs(folder and folder:GetChildren() or {}) do
		if not className or item:IsA(className) then
			count += 1
		end
	end
	return count
end

local function audit()
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local serverScriptService = game:GetService("ServerScriptService")
	local starterPlayer = game:GetService("StarterPlayer")
	local workspace = game:GetService("Workspace")

	local ntr = child(replicatedStorage, "NeoTokyoRacers", "Folder", true)
	local shared = child(ntr, "Shared", "Folder", true)
	local remotes = child(shared, "Remotes", "Folder", true)
	local racingRemotes = child(remotes, "Racing", "Folder", true)
	child(racingRemotes, "RaceRequest", "RemoteFunction", true)
	child(racingRemotes, "RaceEvent", "RemoteEvent", true)
	child(racingRemotes, "RaceQueueEvent", "RemoteEvent", true)

	local config = child(ntr, "Config", "Folder", true)
	local racingConfig = child(config, "Racing", "Folder", true)
	child(racingConfig, "Rewards", "Folder", true)
	child(racingConfig, "PersonalBests", "Folder", true)

	if RunService:IsClient() then
		log("WARN", "Running from a Play client; skipping ServerScriptService source checks because server scripts are not replicated to clients.")
	else
		local serverRoot = child(serverScriptService, "NeoTokyoRacers", "Folder", true)
		local services = child(serverRoot, "Services", "Folder", true)
		local racingServices = child(services, "Racing", "Folder", true)
		local timeTrialService = child(racingServices, "TimeTrialService_Active", "Script", true)
		local raceMatchmakingService = child(racingServices, "RaceMatchmakingService_Active", "Script", true)
		child(racingServices, "RaceRewardService_Active", "Script", true)
		child(racingServices, "RacePersonalBestService_Active", "Script", true)
		child(racingServices, "RaceSessionAssetService_Active", "Script", true)

		sourceHas(timeTrialService, "ExitFinishedTimeTrial", "TimeTrialService result-exit action")
		sourceHas(timeTrialService, "NTR_RACING_PHASE11K_TT_FINISHED_EXIT_CLEANUP", "TimeTrialService finished-run cleanup marker")
		sourceHas(timeTrialService, "RecordTimeTrialBest", "TimeTrialService PB recording bridge")
		sourceHas(timeTrialService, "GetTimeTrialPersonalBest", "TimeTrialService PB lookup action")
		sourceHas(timeTrialService, "RewardGranted", "TimeTrialService reward result payload")
		sourceHas(timeTrialService, "TimeTrialFinished", "TimeTrialService finish event payload")

		sourceHas(raceMatchmakingService, "RaceExitedToStart", "RaceMatchmaking exit-to-start event")
		sourceHas(raceMatchmakingService, "GrantRaceReward", "RaceMatchmaking reward bridge")
	end

	local starterScripts = child(starterPlayer, "StarterPlayerScripts", nil, true)
	local clientRoot = child(starterScripts, "NeoTokyoRacersClient", "Folder", true)
	local controllers = child(clientRoot, "Controllers", "Folder", true)
	local racingControllers = child(controllers, "Racing", "Folder", true)
	local uiControllers = child(controllers, "UI", "Folder", true)
	local runtimeControllers = child(controllers, "Runtime", "Folder", true)

	local raceEntry = child(racingControllers, "RaceEntryMenuClient_Active", "LocalScript", true)
	local transition = child(racingControllers, "RaceTransitionClient_Active", "LocalScript", true)
	local assetsClient = child(racingControllers, "RaceSessionAssetsClient_Active", "LocalScript", true)
	local visibilityClient = child(racingControllers, "RaceParticipantVisibilityClient_Active", "LocalScript", true)
	child(racingControllers, "RaceQueueClient_Active", "LocalScript", true)
	child(racingControllers, "RacePersonalBestBoardClient_Active", "LocalScript", true)
	child(racingControllers, "RaceRouteGuideClient_Active", "LocalScript", true)
	child(uiControllers, "FreeRoamNavController_Active", "LocalScript", true)
	child(runtimeControllers, "DriveHudController_Active", "LocalScript", true)

	sourceHas(raceEntry, "NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF", "RaceEntry time-trial exit-driving handoff")
	sourceHas(raceEntry, "FreeRoamVehicleExited", "RaceEntry fires FreeRoamVehicleExited")
	sourceHas(raceEntry, "ExitFinishedTimeTrial", "RaceEntry result exit action")
	sourceHas(raceEntry, "rememberPBFromResultPayload", "RaceEntry PB card cache refresh")
	sourceHas(raceEntry, "GetTimeTrialPersonalBest", "RaceEntry PB lookup")
	sourceNotHas(raceEntry, "NTR_RACING_PHASE11P_RESULT_COACH_TEXT", "Unconfirmed Phase 11P text polish marker", "WARN")
	sourceNotHas(raceEntry, "NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF\tlocal clientRoot", "Malformed 11Q helper comment/clientRoot line", "FAIL")

	sourceHas(transition, "Session HUD state active=", "RaceTransition session-active logging", "WARN")
	sourceHas(transition, "TimeTrialFinished", "RaceTransition handles time-trial finish")
	sourceHas(transition, "TimeTrialEnded", "RaceTransition handles time-trial end")

	sourceHas(assetsClient, "ParticipantSegments", "Session asset visual proxy segment sync")
	sourceHas(assetsClient, "NTR_ArrowOriginalTransparency", "Arrow transparency restore baseline")
	sourceHas(visibilityClient, "NTR_VFXRuntimeHost", "Visibility/VFX host hiding")
	sourceHas(visibilityClient, "DisplayDistanceType", "Name tag hiding baseline")

	local world = child(workspace, "NeoTokyoRacersWorld", "Folder", true)
	local routes = child(world, "RaceRoutes", "Folder", true)
	local route = child(routes, "ShiftedCanalSprint", "Folder", false)
	if route then
		local checkpoints = child(route, "Checkpoints", "Folder", true)
		local startZones = child(route, "StartZones", "Folder", true)
		local arrowMarkers = child(route, "ArrowMarkers", "Folder", true)
		local teleportPoints = child(route, "TeleportPoints", "Folder", true)
		local spawnGrid = child(route, "SpawnGrid", "Folder", true)
		log("INFO", "ShiftedCanalSprint checkpoint children=" .. tostring(countChildren(checkpoints)))
		log("INFO", "ShiftedCanalSprint start zones=" .. tostring(countChildren(startZones)))
		log("INFO", "ShiftedCanalSprint arrow segment folders=" .. tostring(countChildren(arrowMarkers, "Folder")))
		log("INFO", "ShiftedCanalSprint teleport points=" .. tostring(countChildren(teleportPoints)))
		log("INFO", "ShiftedCanalSprint spawn grid children=" .. tostring(countChildren(spawnGrid)))
	end

	local raceInstances = world and world:FindFirstChild("RaceInstances")
	if raceInstances then
		log("INFO", "Runtime RaceInstances children=" .. tostring(#raceInstances:GetChildren()))
		for _, childInstance in ipairs(raceInstances:GetChildren()) do
			log("WARN", "Runtime race instance still present: " .. childInstance:GetFullName())
		end
	else
		log("PASS", "No RaceInstances folder currently present, or no runtime race instances to inspect.")
	end

	print("[" .. PHASE .. "] SUMMARY pass=" .. results.pass .. " warn=" .. results.warn .. " fail=" .. results.fail)
	if results.fail == 0 then
		print("[" .. PHASE .. "] RESULT PASS gate clear if warnings are expected/prototype-only.")
	else
		warn("[" .. PHASE .. "] RESULT FAIL review failed checks before the next feature phase.")
	end
end

audit()
