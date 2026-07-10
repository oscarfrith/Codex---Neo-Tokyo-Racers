-- Neo Tokyo Racers - Racing Phase 11V Prototype Release Audit
-- Run in Roblox Studio Command Bar, Edit mode and optionally Play mode.
--
-- Read-only audit. This script does not modify instances, source, attributes,
-- rewards, route assets, VFX, matchmaking, driving, or UI.
--
-- V2 note:
--   Studio live editing can report IsClient=true and IsEdit=true. In that
--   context ServerScriptService is still inspectable, but runtime collision
--   groups may not be registered until Play/server scripts run.
--
-- Purpose:
--   Lock the post-11U prototype baseline before DataStore PB verification,
--   further UX polish, or broader multiplayer testing.

local PHASE = "NTR Racing Phase 11V Audit"
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
		if required == false then
			log("WARN", "Optional missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
		else
			log("FAIL", "Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
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
	if not (scriptObject and (scriptObject:IsA("Script") or scriptObject:IsA("LocalScript") or scriptObject:IsA("ModuleScript"))) then
		log(severity or "FAIL", tostring(label or marker) .. " source owner unavailable")
		return false
	end
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	if not ok or type(source) ~= "string" then
		log(severity or "FAIL", tostring(label or marker) .. " source unreadable in this context")
		return false
	end
	if string.find(source, marker, 1, true) then
		log("PASS", tostring(label or marker))
		return true
	end
	log(severity or "FAIL", "Missing marker/text: " .. tostring(label or marker))
	return false
end

local function sourceNotHas(scriptObject, marker, label, severity)
	if not (scriptObject and (scriptObject:IsA("Script") or scriptObject:IsA("LocalScript") or scriptObject:IsA("ModuleScript"))) then
		log(severity or "WARN", tostring(label or marker) .. " source owner unavailable")
		return false
	end
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	if not ok or type(source) ~= "string" then
		log(severity or "WARN", tostring(label or marker) .. " source unreadable in this context")
		return false
	end
	if string.find(source, marker, 1, true) then
		log(severity or "WARN", "Unexpected marker/text present: " .. tostring(label or marker))
		return false
	end
	log("PASS", "Absent as expected: " .. tostring(label or marker))
	return true
end

local function countChildren(parent, className)
	local count = 0
	for _, item in ipairs(parent and parent:GetChildren() or {}) do
		if not className or item:IsA(className) then
			count += 1
		end
	end
	return count
end

local function countDescendantParts(parent)
	local count = 0
	for _, item in ipairs(parent and parent:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

local function runtimeCollisionGroupsRequired()
	return not RunService:IsEdit()
end

local function auditCollisionGroups()
	local physicsService = game:GetService("PhysicsService")
	local groups = {}
	local ok, registered = pcall(function()
		return physicsService:GetRegisteredCollisionGroups()
	end)
	if ok then
		for _, group in ipairs(registered) do
			groups[tostring(group.name or group.Name)] = true
		end
	end
	local missingSeverity = runtimeCollisionGroupsRequired() and "FAIL" or "WARN"
	if groups.NTR_RaceSessionAsset then log("PASS", "NTR_RaceSessionAsset collision group registered") else log(missingSeverity, "NTR_RaceSessionAsset collision group not currently registered; expected in Edit before runtime services start") end
	if groups.NTR_RaceParticipant then log("PASS", "NTR_RaceParticipant collision group registered") else log(missingSeverity, "NTR_RaceParticipant collision group not currently registered; expected in Edit before runtime services start") end

	if not (groups.NTR_RaceSessionAsset and groups.NTR_RaceParticipant) then
		if runtimeCollisionGroupsRequired() then
			log("FAIL", "Runtime collision groups missing during Play/runtime context")
		else
			log("WARN", "Skipping live collision policy checks in Edit because one or more race collision groups are not registered yet")
		end
		return
	end

	local okAsset, assetParticipant = pcall(function()
		return physicsService:CollisionGroupsAreCollidable("NTR_RaceSessionAsset", "NTR_RaceParticipant")
	end)
	if okAsset and assetParticipant == true then log("PASS", "Race assets collide with race participants") else log("FAIL", "Race assets do not collide with race participants") end

	local okDefault, assetDefault = pcall(function()
		return physicsService:CollisionGroupsAreCollidable("NTR_RaceSessionAsset", "Default")
	end)
	if okDefault and assetDefault == false then log("PASS", "Race assets do not collide with Default") else log("WARN", "Race assets may collide with Default") end

	local okSelf, participantSelf = pcall(function()
		return physicsService:CollisionGroupsAreCollidable("NTR_RaceParticipant", "NTR_RaceParticipant")
	end)
	if okSelf and participantSelf == false then log("PASS", "Race participants do not collide with each other") else log("WARN", "Race participants may still collide with each other") end
end

local function auditRoute(route)
	local checkpoints = child(route, "Checkpoints", "Folder", true)
	local startZones = child(route, "StartZones", "Folder", true)
	local arrowMarkers = child(route, "ArrowMarkers", "Folder", true)
	local teleportPoints = child(route, "TeleportPoints", "Folder", true)
	local spawnGrid = child(route, "SpawnGrid", "Folder", true)
	local finish = child(route, "FinishLine", nil, false)

	local checkpointCount = countChildren(checkpoints, "BasePart")
	if checkpointCount >= 2 then log("PASS", "Checkpoint parts=" .. tostring(checkpointCount)) else log("FAIL", "Too few checkpoint parts=" .. tostring(checkpointCount)) end
	if startZones and startZones:FindFirstChild("RaceStartZone") then log("PASS", "RaceStartZone present") else log("FAIL", "RaceStartZone missing") end
	if startZones and startZones:FindFirstChild("TimeTrialStartZone") then log("PASS", "TimeTrialStartZone present") else log("FAIL", "TimeTrialStartZone missing") end
	if finish then log("PASS", "FinishLine present: " .. finish:GetFullName()) end

	local segmentFolders = 0
	local segmentParts = 0
	for _, item in ipairs(arrowMarkers and arrowMarkers:GetChildren() or {}) do
		if item:IsA("Folder") and string.match(item.Name, "^Checkpoint%d+%-%d+$") then
			segmentFolders += 1
			segmentParts += countDescendantParts(item)
		end
	end
	if segmentFolders >= checkpointCount then
		log("PASS", "Arrow segment folders=" .. tostring(segmentFolders))
	else
		log("WARN", "Arrow segment folder count looks low: " .. tostring(segmentFolders) .. " for checkpoints=" .. tostring(checkpointCount))
	end
	if segmentParts > 0 then log("PASS", "Arrow segment parts=" .. tostring(segmentParts)) else log("WARN", "No arrow segment parts found") end

	if countChildren(teleportPoints, "BasePart") >= 1 then log("PASS", "Teleport point parts present") else log("WARN", "No teleport point parts found") end
	if countChildren(spawnGrid, "BasePart") >= 2 then log("PASS", "Spawn grid has at least two parts") else log("WARN", "Spawn grid has fewer than two parts") end
end

local function auditPlayerGui()
	if not (RunService:IsClient() and not RunService:IsEdit()) then
		log("WARN", "PlayerGui checks skipped outside Play-client runtime context")
		return
	end
	local players = game:GetService("Players")
	local player = players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		log("WARN", "PlayerGui unavailable")
		return
	end

	local resultCoach = playerGui:FindFirstChild("NTR_TimeTrialResultCoach")
	if resultCoach then log("PASS", "Phase 11T result coach GUI exists in PlayerGui") else log("WARN", "Phase 11T result coach GUI not yet present in PlayerGui") end

	local hud = playerGui:FindFirstChild("NTR_RaceHud_Phase3")
	local hudPanel = hud and hud:FindFirstChild("Panel")
	if hudPanel and hudPanel:IsA("GuiObject") then
		if hudPanel.Visible then
			log("WARN", "NTR_RaceHud_Phase3.Panel is currently visible; expected only during an active run or before exit cleanup")
		else
			log("PASS", "NTR_RaceHud_Phase3.Panel currently hidden")
		end
	else
		log("WARN", "NTR_RaceHud_Phase3.Panel not found in PlayerGui yet")
	end
end

local function audit()
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local serverScriptService = game:GetService("ServerScriptService")
	local starterPlayer = game:GetService("StarterPlayer")
	local workspace = game:GetService("Workspace")

	log("INFO", "Context IsClient=" .. tostring(RunService:IsClient()) .. " IsServer=" .. tostring(RunService:IsServer()) .. " IsEdit=" .. tostring(RunService:IsEdit()))

	local ntr = child(replicatedStorage, "NeoTokyoRacers", "Folder", true)
	local shared = child(ntr, "Shared", "Folder", true)
	local remotes = child(shared, "Remotes", "Folder", true)
	local racingRemotes = child(remotes, "Racing", "Folder", true)
	child(racingRemotes, "RaceRequest", "RemoteFunction", true)
	child(racingRemotes, "RaceEvent", "RemoteEvent", true)
	child(racingRemotes, "RaceQueueRequest", "RemoteFunction", true)
	child(racingRemotes, "RaceQueueEvent", "RemoteEvent", true)

	local config = child(ntr, "Config", "Folder", true)
	local racingConfig = child(config, "Racing", "Folder", true)
	local rewards = child(racingConfig, "Rewards", "Folder", true)
	child(rewards, "TimeTrial", "Folder", true)
	child(rewards, "Race", "Folder", true)
	child(racingConfig, "PersonalBests", "Folder", true)
	child(racingConfig, "RouteGuide", "Folder", true)
	child(racingConfig, "Matchmaking", "Folder", true)

	if RunService:IsClient() and not RunService:IsEdit() then
		log("WARN", "Running from a Play client; skipping ServerScriptService source checks because server scripts are not replicated to clients.")
	else
		local serverRoot = child(serverScriptService, "NeoTokyoRacers", "Folder", true)
		local services = child(serverRoot, "Services", "Folder", true)
		local racingServices = child(services, "Racing", "Folder", true)
		local timeTrialService = child(racingServices, "TimeTrialService_Active", "Script", true)
		local raceMatchmakingService = child(racingServices, "RaceMatchmakingService_Active", "Script", true)
		local rewardService = child(racingServices, "RaceRewardService_Active", "Script", true)
		local pbService = child(racingServices, "RacePersonalBestService_Active", "Script", true)
		local assetService = child(racingServices, "RaceSessionAssetService_Active", "Script", true)

		sourceHas(timeTrialService, "ExitFinishedTimeTrial", "TimeTrialService result-exit action")
		sourceHas(timeTrialService, "NTR_RACING_PHASE11K_TT_FINISHED_EXIT_CLEANUP", "TimeTrialService finished-run cleanup marker")
		sourceHas(timeTrialService, "RecordTimeTrialBest", "TimeTrialService PB recording bridge")
		sourceHas(timeTrialService, "GetTimeTrialPersonalBest", "TimeTrialService PB lookup action")
		sourceHas(timeTrialService, "RewardGranted", "TimeTrialService reward payload")
		sourceHas(timeTrialService, "UpdateParticipantSegment", "TimeTrialService session-asset segment update")

		sourceHas(raceMatchmakingService, "RaceExitedToStart", "RaceMatchmaking exit-to-start event")
		sourceHas(raceMatchmakingService, "GrantRaceReward", "RaceMatchmaking reward bridge")
		sourceHas(raceMatchmakingService, "UpdateParticipantSegment", "RaceMatchmaking session-asset segment update")
		sourceHas(rewardService, "NTR Racing Phase 11A Rewards", "Race reward service current marker")
		sourceHas(pbService, "RecordTimeTrialBest", "Personal best service record binding")
		sourceHas(assetService, "ParticipantSegments", "Session asset service participant segment state")
		sourceHas(assetService, "RegisterCollisionGroup", "Session asset service uses non-deprecated collision registration")
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
	local pbBoard = child(racingControllers, "RacePersonalBestBoardClient_Active", "LocalScript", true)
	local resultCoach = child(racingControllers, "RaceTimeTrialResultCoachClient_Active", "LocalScript", true)
	local hudCleanup = child(racingControllers, "RaceHudExitCleanupClient_Active", "LocalScript", true)
	child(racingControllers, "RaceQueueClient_Active", "LocalScript", true)
	child(racingControllers, "RaceRouteGuideClient_Active", "LocalScript", true)
	child(racingControllers, "RaceSessionControlsClient_Active", "LocalScript", true)
	child(uiControllers, "FreeRoamNavController_Active", "LocalScript", true)
	child(runtimeControllers, "DriveHudController_Active", "LocalScript", true)

	sourceHas(raceEntry, "NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF", "RaceEntry time-trial exit-driving handoff")
	sourceHas(raceEntry, "FreeRoamVehicleExited", "RaceEntry fires FreeRoamVehicleExited")
	sourceHas(raceEntry, "ExitFinishedTimeTrial", "RaceEntry result exit action")
	sourceHas(raceEntry, "rememberPBFromResultPayload", "RaceEntry PB cache refresh")
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
	sourceHas(pbBoard, "GetTimeTrialPersonalBest", "PB board lookup")
	sourceHas(resultCoach, "NTR_RACING_PHASE11T_ISOLATED_TT_RESULT_COACH", "Phase 11T isolated result coach marker")
	sourceHas(resultCoach, "ExitFinishedTimeTrial", "Phase 11T exit action")
	sourceHas(hudCleanup, "NTR_RACING_PHASE11U_TT_HUD_EXIT_CLEANUP_V2_HUD_ONLY", "Phase 11U V2 narrow HUD cleanup marker")
	sourceHas(hudCleanup, "NTR_RaceHud_Phase3", "Phase 11U targets old top HUD")
	sourceNotHas(hudCleanup, "NTR_RaceSessionControls_Phase8D = true", "Phase 11U V1 broad control cleanup", "FAIL")

	local world = child(workspace, "NeoTokyoRacersWorld", "Folder", true)
	local routes = child(world, "RaceRoutes", "Folder", true)
	local route = child(routes, "ShiftedCanalSprint", "Folder", true)
	if route then
		auditRoute(route)
	end

	local raceInstances = world and world:FindFirstChild("RaceInstances")
	if raceInstances then
		local runtimeCount = #raceInstances:GetChildren()
		if runtimeCount == 0 then
			log("PASS", "RaceInstances is empty")
		else
			log("WARN", "RaceInstances active children=" .. tostring(runtimeCount) .. " (expected only during active race/time trial)")
			for _, instance in ipairs(raceInstances:GetChildren()) do
				log("INFO", "Active runtime race instance: " .. instance:GetFullName())
			end
		end
	else
		log("PASS", "RaceInstances folder is absent outside active sessions")
	end

	auditCollisionGroups()
	auditPlayerGui()

	print("[" .. PHASE .. "] SUMMARY pass=" .. results.pass .. " warn=" .. results.warn .. " fail=" .. results.fail)
	if results.fail == 0 then
		print("[" .. PHASE .. "] RESULT PASS gate clear if warnings are expected for current Play/Edit context.")
	else
		warn("[" .. PHASE .. "] RESULT FAIL review failed checks before the next feature phase.")
	end
end

audit()
