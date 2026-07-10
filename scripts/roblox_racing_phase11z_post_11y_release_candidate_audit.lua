-- Neo Tokyo Racers - Racing Phase 11Z Post-11Y Release Candidate Audit
-- Run in Roblox Studio Command Bar.
--
-- Read-only audit. This script does not create, delete, move, or patch
-- gameplay objects. It is the post-11Y lifecycle gate before choosing broader
-- multiplayer testing, polish, or larger deferred systems.

local PHASE = "NTR Racing Phase 11Z Post-11Y RC Audit"
local EXPECTED_ROUTE_ID = "ShiftedCanalSprint"
local EXPECTED_TT_EVENT_ID = "shifted_canal_sprint_tt"
local EXPECTED_CHECKPOINTS = 14
local SAMPLE_TIERS = { "E", "D", "C", "B", "A", "S" }

local results = {
	pass = 0,
	warn = 0,
	fail = 0,
	info = 0,
}

local function log(kind, message)
	kind = tostring(kind or "INFO")
	local key = string.lower(kind)
	results[key] = (results[key] or 0) + 1
	local line = "[" .. PHASE .. "] " .. kind .. " " .. tostring(message)
	if kind == "WARN" or kind == "FAIL" then
		warn(line)
	else
		print(line)
	end
end

local function child(parent, name, className, required)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		log(required and "FAIL" or "WARN", "Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
		return nil
	end
	if className and not item:IsA(className) then
		log("FAIL", item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
		return item
	end
	log("PASS", "Found " .. item:GetFullName())
	return item
end

local function sourceHas(scriptObject, marker, label, severity)
	if not scriptObject then
		log(severity or "FAIL", tostring(label or marker) .. " source owner unavailable")
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
		log("PASS", tostring(label or marker))
		return true
	end
	log(severity or "FAIL", "Missing marker/text: " .. tostring(label or marker))
	return false
end

local function valueOf(parent, name)
	local item = parent and parent:FindFirstChild(name)
	if item and item:IsA("ValueBase") then
		return item.Value, item
	end
	return nil, item
end

local function countDescendantsOfClass(root, className)
	local count = 0
	for _, descendant in ipairs(root and root:GetDescendants() or {}) do
		if descendant:IsA(className) then
			count += 1
		end
	end
	return count
end

local function countChildrenOfClass(root, className)
	local count = 0
	for _, item in ipairs(root and root:GetChildren() or {}) do
		if item:IsA(className) then
			count += 1
		end
	end
	return count
end

local function auditCollisionGroups(physicsService, runService)
	local groups = {}
	local ok, registered = pcall(function()
		return physicsService:GetRegisteredCollisionGroups()
	end)
	if ok then
		for _, groupInfo in ipairs(registered) do
			groups[groupInfo.name] = true
		end
	else
		log("WARN", "Could not read registered collision groups: " .. tostring(registered))
	end

	local editContext = runService:IsEdit()
	local missingSeverity = editContext and "WARN" or "FAIL"
	if groups.NTR_RaceSessionAsset then
		log("PASS", "NTR_RaceSessionAsset collision group registered")
	else
		log(missingSeverity, "NTR_RaceSessionAsset collision group not currently registered")
	end
	if groups.NTR_RaceParticipant then
		log("PASS", "NTR_RaceParticipant collision group registered")
	else
		log(missingSeverity, "NTR_RaceParticipant collision group not currently registered")
	end

	if groups.NTR_RaceSessionAsset and groups.NTR_RaceParticipant then
		local okAssetParticipant, assetParticipant = pcall(function()
			return physicsService:CollisionGroupsAreCollidable("NTR_RaceSessionAsset", "NTR_RaceParticipant")
		end)
		local okAssetDefault, assetDefault = pcall(function()
			return physicsService:CollisionGroupsAreCollidable("NTR_RaceSessionAsset", "Default")
		end)
		local okParticipantSelf, participantSelf = pcall(function()
			return physicsService:CollisionGroupsAreCollidable("NTR_RaceParticipant", "NTR_RaceParticipant")
		end)

		if okAssetParticipant and assetParticipant == true then log("PASS", "Race assets collide with race participants") else log("FAIL", "Race assets do not collide with race participants") end
		if okAssetDefault and assetDefault == false then log("PASS", "Race assets do not collide with Default") else log("WARN", "Race assets may collide with Default") end
		if okParticipantSelf and participantSelf == false then log("PASS", "Race participants do not collide with each other") else log("WARN", "Race participants may still collide with each other") end
	end
end

local function auditRoute(route)
	local checkpoints = child(route, "Checkpoints", "Folder", true)
	local startZones = child(route, "StartZones", "Folder", true)
	local arrows = child(route, "ArrowMarkers", "Folder", true)
	local teleportPoints = child(route, "TeleportPoints", "Folder", true)
	local spawnGrid = child(route, "SpawnGrid", "Folder", true)
	child(route, "FinishLine", nil, true)

	child(startZones, "RaceStartZone", nil, true)
	child(startZones, "TimeTrialStartZone", nil, true)
	child(teleportPoints, "RaceBrowserTeleportPoint", "BasePart", true)

	local checkpointCount = countChildrenOfClass(checkpoints, "BasePart")
	if checkpointCount >= 2 then
		log("PASS", "Checkpoint parts=" .. tostring(checkpointCount))
	else
		log("FAIL", "Too few checkpoint parts=" .. tostring(checkpointCount))
	end
	if checkpointCount ~= EXPECTED_CHECKPOINTS then
		log("WARN", "Checkpoint count differs from expected prototype route count. expected=" .. tostring(EXPECTED_CHECKPOINTS) .. " actual=" .. tostring(checkpointCount))
	end

	local segmentFolders = 0
	for _, item in ipairs(arrows and arrows:GetChildren() or {}) do
		if item:IsA("Folder") and string.match(item.Name, "^Checkpoint%d+%-%d+$") then
			segmentFolders += 1
		end
	end
	if segmentFolders >= checkpointCount then
		log("PASS", "Arrow segment folders=" .. tostring(segmentFolders))
	else
		log("WARN", "Arrow segment folders look low. folders=" .. tostring(segmentFolders) .. " checkpoints=" .. tostring(checkpointCount))
	end

	local arrowParts = countDescendantsOfClass(arrows, "BasePart")
	if arrowParts > 0 then
		log("PASS", "Arrow marker parts=" .. tostring(arrowParts))
	else
		log("WARN", "No arrow marker parts found")
	end

	local spawnParts = countChildrenOfClass(spawnGrid, "BasePart")
	if spawnParts >= 2 then
		log("PASS", "Spawn grid supports multiplayer starts. parts=" .. tostring(spawnParts))
	else
		log("WARN", "Spawn grid has fewer than two parts. parts=" .. tostring(spawnParts))
	end
end

local function auditPlayClient(player, raceRequest)
	if not player then
		log("WARN", "No LocalPlayer for Play-client PB/UI smoke")
		return
	end
	log("INFO", "LocalPlayer=" .. player.Name .. " UserId=" .. tostring(player.UserId) .. " PBLoaded=" .. tostring(player:GetAttribute("NTR_TimeTrialPBLoaded")) .. " PBDataStoreEnabled=" .. tostring(player:GetAttribute("NTR_TimeTrialPBDataStoreEnabled")) .. " PBLastError=" .. tostring(player:GetAttribute("NTR_TimeTrialPBLastError")))

	if raceRequest and raceRequest:IsA("RemoteFunction") then
		local foundAny = false
		for _, tier in ipairs(SAMPLE_TIERS) do
			local ok, result = pcall(function()
				return raceRequest:InvokeServer("GetTimeTrialPersonalBest", {
					EventId = EXPECTED_TT_EVENT_ID,
					VehicleTier = tier,
				})
			end)
			if ok and typeof(result) == "table" and result.Ok ~= false then
				if tonumber(result.BestSeconds) then
					foundAny = true
					log("PASS", "PB lookup tier=" .. tier .. " best=" .. string.format("%.3f", tonumber(result.BestSeconds)) .. " medal=" .. tostring(result.BestMedal or ""))
				else
					log("PASS", "PB lookup tier=" .. tier .. " healthy but empty")
				end
			else
				log("WARN", "PB lookup tier=" .. tier .. " returned warning: " .. tostring(ok and (result and result.Message) or result))
			end
		end
		if foundAny then
			log("PASS", "At least one saved/session PB is visible through the race request action")
		else
			log("WARN", "No PBs found through the lookup action yet. This is OK only if this player has no saved PBs in the selected store.")
		end
	else
		log("FAIL", "RaceRequest RemoteFunction unavailable for Play-client PB smoke")
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local raceHud = playerGui and playerGui:FindFirstChild("NTR_RaceHud_Phase3")
	local hudPanel = raceHud and raceHud:FindFirstChild("Panel", true)
	if hudPanel and hudPanel.Visible then
		log("WARN", "NTR_RaceHud_Phase3.Panel is currently visible. Expected only during an active run or before exit cleanup.")
	elseif hudPanel then
		log("PASS", "NTR_RaceHud_Phase3.Panel currently hidden")
	else
		log("WARN", "NTR_RaceHud_Phase3.Panel not present in current PlayerGui yet")
	end
	if playerGui and playerGui:FindFirstChild("NTR_TimeTrialResultCoach") then
		log("PASS", "Time-trial result coach GUI exists in PlayerGui")
	else
		log("WARN", "Time-trial result coach GUI not present in PlayerGui yet")
	end
end

local function auditRuntimeVehicles(world, playersService, runService)
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	if not vehicles then
		log("WARN", "Runtime.PlayerVehicles not found; vehicle lifecycle smoke skipped")
		return
	end

	local pendingFinished = {}
	local orphanGrid = {}
	for _, vehicle in ipairs(vehicles:GetChildren()) do
		local owner = tonumber(vehicle:GetAttribute("OwnerUserId"))
		local pending = vehicle:GetAttribute("NTR_RaceFinishedPendingExit") == true
		local gridSpawned = vehicle:GetAttribute("NTR_RaceGridSpawned") == true
		local runId = tostring(vehicle:GetAttribute("NTR_RaceRunId") or "")
		local participant = vehicle:GetAttribute("NTR_RaceParticipant") == true
		local mode = tostring(vehicle:GetAttribute("NTR_RaceMode") or "")
		local driveReady = vehicle:GetAttribute("DriveReady")
		local driverUserId = vehicle:GetAttribute("DriverUserId")

		if pending then
			table.insert(pendingFinished, vehicle)
			if driveReady == false then
				log("PASS", "Pending finished TT vehicle is drive-disabled: " .. vehicle:GetFullName())
			else
				log("FAIL", "Pending finished TT vehicle is drive-ready: " .. vehicle:GetFullName())
			end
			if mode == "TimeTrialFinished" then
				log("PASS", "Pending finished TT vehicle mode is TimeTrialFinished owner=" .. tostring(owner))
			else
				log("WARN", "Pending finished TT vehicle has unexpected mode=" .. mode .. " path=" .. vehicle:GetFullName())
			end
			if driverUserId == nil then
				log("PASS", "Pending finished TT vehicle has no DriverUserId")
			else
				log("FAIL", "Pending finished TT vehicle still has DriverUserId=" .. tostring(driverUserId))
			end
		end

		if gridSpawned and runId == "" and not pending and not participant then
			table.insert(orphanGrid, vehicle)
		end
	end

	if #pendingFinished == 0 then
		log("PASS", "No finished time-trial vehicles pending cleanup in current context")
	else
		log("WARN", "Finished time-trial vehicles pending cleanup=" .. tostring(#pendingFinished) .. ". Expected only while the result panel is still open before pressing exit.")
	end

	if #orphanGrid == 0 then
		log("PASS", "No orphan grid-spawned race vehicles found")
	else
		for _, vehicle in ipairs(orphanGrid) do
			log("FAIL", "Orphan grid-spawned vehicle found outside pending cleanup: " .. vehicle:GetFullName())
		end
	end

	local localPlayer = playersService.LocalPlayer
	if localPlayer and runService:IsClient() then
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat and seat:IsA("VehicleSeat") then
			local current = seat
			local vehicle = nil
			while current do
				if current:IsA("Model") and current:GetAttribute("OwnerUserId") ~= nil then
					vehicle = current
					break
				end
				current = current.Parent
			end
			if vehicle and vehicle:GetAttribute("NTR_RaceFinishedPendingExit") == true then
				log("FAIL", "Local player is still seated in a finished-pending TT vehicle")
			elseif vehicle then
				log("INFO", "Local player is seated in vehicle " .. vehicle:GetFullName())
			else
				log("INFO", "Local player is seated, but not in a recognized runtime vehicle")
			end
		else
			log("PASS", "Local player is not seated in a vehicle in current audit context")
		end
	end
end

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")
local starterPlayer = game:GetService("StarterPlayer")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local physicsService = game:GetService("PhysicsService")
local runService = game:GetService("RunService")

local runningFromPlayClient = runService:IsClient() and not runService:IsEdit()
log("INFO", "Context IsClient=" .. tostring(runService:IsClient()) .. " IsServer=" .. tostring(runService:IsServer()) .. " IsEdit=" .. tostring(runService:IsEdit()))

local ntr = child(replicatedStorage, "NeoTokyoRacers", "Folder", true)
local shared = child(ntr, "Shared", "Folder", true)
local remotes = child(shared, "Remotes", "Folder", true)
local racingRemotes = child(remotes, "Racing", "Folder", true)
local raceRequest = child(racingRemotes, "RaceRequest", "RemoteFunction", true)
child(racingRemotes, "RaceEvent", "RemoteEvent", true)
child(racingRemotes, "RaceQueueRequest", "RemoteFunction", true)
child(racingRemotes, "RaceQueueEvent", "RemoteEvent", true)

local config = child(ntr, "Config", "Folder", true)
local racingConfig = child(config, "Racing", "Folder", true)
local rewards = child(racingConfig, "Rewards", "Folder", true)
child(rewards, "TimeTrial", "Folder", true)
child(rewards, "Race", "Folder", true)
local personalBests = child(racingConfig, "PersonalBests", "Folder", true)
local dataStoreEnabled = valueOf(personalBests, "DataStoreEnabled")
local dataStoreName = valueOf(personalBests, "DataStoreName")
if dataStoreEnabled == true then
	log("PASS", "PersonalBests.DataStoreEnabled=true")
else
	log("WARN", "PersonalBests.DataStoreEnabled is not true. Saved PB testing may have been disabled after verification.")
end
log("INFO", "PersonalBests.DataStoreName=" .. tostring(dataStoreName))
child(racingConfig, "RouteGuide", "Folder", true)
child(racingConfig, "Matchmaking", "Folder", true)

local serverRoot = serverScriptService:FindFirstChild("NeoTokyoRacers")
local services = serverRoot and serverRoot:FindFirstChild("Services")
local racingServices = services and services:FindFirstChild("Racing")
if runningFromPlayClient and not racingServices then
	log("WARN", "Skipping ServerScriptService source checks from Play client; server scripts are not replicated.")
else
	local tt = child(racingServices, "TimeTrialService_Active", "Script", true)
	local race = child(racingServices, "RaceMatchmakingService_Active", "Script", true)
	local assets = child(racingServices, "RaceSessionAssetService_Active", "Script", true)
	local rewardsService = child(racingServices, "RaceRewardService_Active", "Script", true)
	local pb = child(racingServices, "RacePersonalBestService_Active", "Script", true)
	child(racingServices, "RaceBrowserTeleportService_Active", "Script", true)

	sourceHas(tt, "ExitFinishedTimeTrial", "TimeTrial result exit action")
	sourceHas(tt, "NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY", "Phase 11Y finished TT lifecycle recovery marker")
	sourceHas(tt, "RecordTimeTrialBest", "TimeTrial persistent PB record bridge")
	sourceHas(tt, "GetTimeTrialPersonalBest", "TimeTrial PB lookup action")
	sourceHas(tt, "LapTarget", "TimeTrial lap target support")
	sourceHas(race, "ExitRaceToStart", "Race exit-to-start action")
	sourceHas(race, "NTR_RACING_PHASE11D_FINISH_BOUNDARY", "Race finish boundary cleanup marker")
	sourceHas(race, "GrantRaceReward", "Race reward bridge")
	sourceHas(assets, "NTR_RACING_PHASE10B_FOLDER_ARROW_BARRIER_SERVICE", "Race session asset service marker")
	sourceHas(assets, "ParticipantSegments", "Session asset participant segment state")
	sourceHas(rewardsService, "GrantTimeTrialReward", "Time-trial reward binding")
	sourceHas(rewardsService, "GrantRaceReward", "Race reward binding")
	sourceHas(pb, "NTR_RACING_PHASE11M_PERSONAL_BEST_SERVICE", "PB service marker")
	sourceHas(pb, "DataStore skipped for non-production UserId.", "PB service Studio UserId guard")
end

local starterScripts = child(starterPlayer, "StarterPlayerScripts", nil, true)
local clientRoot = child(starterScripts, "NeoTokyoRacersClient", nil, true)
local controllers = child(clientRoot, "Controllers", "Folder", true)
local racingControllers = child(controllers, "Racing", "Folder", true)
local uiControllers = child(controllers, "UI", "Folder", true)
local runtimeControllers = child(controllers, "Runtime", "Folder", true)

local entry = child(racingControllers, "RaceEntryMenuClient_Active", "LocalScript", true)
local transition = child(racingControllers, "RaceTransitionClient_Active", "LocalScript", true)
local sessionAssets = child(racingControllers, "RaceSessionAssetsClient_Active", "LocalScript", true)
local visibility = child(racingControllers, "RaceParticipantVisibilityClient_Active", "LocalScript", true)
local pbBoard = child(racingControllers, "RacePersonalBestBoardClient_Active", "LocalScript", true)
local resultCoach = child(racingControllers, "RaceTimeTrialResultCoachClient_Active", "LocalScript", true)
local hudCleanup = child(racingControllers, "RaceHudExitCleanupClient_Active", "LocalScript", true)
child(racingControllers, "RaceQueueClient_Active", "LocalScript", true)
child(racingControllers, "RaceRouteGuideClient_Active", "LocalScript", true)
child(racingControllers, "RaceSessionControlsClient_Active", "LocalScript", true)
child(uiControllers, "FreeRoamNavController_Active", "LocalScript", true)
child(runtimeControllers, "DriveHudController_Active", "LocalScript", true)

sourceHas(entry, "NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF", "Entry client time-trial exit driving handoff")
sourceHas(entry, "GetTimeTrialPersonalBest", "Entry client PB lookup")
sourceHas(entry, "NTR_RACING_PHASE11L_ENTRY_MENU_LEGACY_VIS_DISABLED", "Entry legacy visibility disabled")
sourceHas(transition, "TimeTrialFinished", "Transition handles time-trial finish")
sourceHas(sessionAssets, "NTR_RACING_PHASE11L_ARROW_VISUAL_PROXY_SYNC_V2_TRANSPARENCY_RESTORE", "Arrow visual proxy sync V2")
sourceHas(visibility, "NTR_RACING_PHASE11L_MULTI_SESSION_VISIBILITY_OWNER", "Multi-session visibility owner")
sourceHas(pbBoard, "NTR_RACING_PHASE11O_TIME_TRIAL_PB_BOARD_V2_MENU_CLOSE_SYNC", "PB board menu-close sync")
sourceHas(resultCoach, "NTR_RACING_PHASE11T_ISOLATED_TT_RESULT_COACH", "Isolated result coach")
sourceHas(resultCoach, "NTR_RACING_PHASE11Y_RESULT_COACH_CONFIRMED_EXIT", "Result coach waits for confirmed cleanup before hiding")
sourceHas(hudCleanup, "NTR_RACING_PHASE11U_TT_HUD_EXIT_CLEANUP_V2_HUD_ONLY", "Narrow HUD cleanup")

local world = child(workspace, "NeoTokyoRacersWorld", "Folder", true)
local routes = child(world, "RaceRoutes", "Folder", true)
local route = child(routes, EXPECTED_ROUTE_ID, "Folder", true)
if route then
	auditRoute(route)
end

local raceInstances = world and world:FindFirstChild("RaceInstances")
if raceInstances then
	local runtimeCount = #raceInstances:GetChildren()
	if runtimeCount == 0 then
		log("PASS", "RaceInstances exists and is empty outside active sessions")
	else
		log("WARN", "RaceInstances has active children=" .. tostring(runtimeCount) .. ". Expected only during active race/time trial.")
		for _, instance in ipairs(raceInstances:GetChildren()) do
			log("INFO", "Active RaceInstance child: " .. instance:GetFullName())
		end
	end
else
	log("PASS", "RaceInstances folder is absent outside active sessions")
end

auditRuntimeVehicles(world, players, runService)
auditCollisionGroups(physicsService, runService)
if runningFromPlayClient then
	auditPlayClient(players.LocalPlayer, raceRequest)
else
	log("WARN", "Play-client UI/PB smoke skipped outside Play client. Run this audit again from the Play client after one time-trial finish/exit.")
end

print("[" .. PHASE .. "] SUMMARY pass=" .. tostring(results.pass) .. " warn=" .. tostring(results.warn) .. " fail=" .. tostring(results.fail))
if results.fail == 0 then
	print("[" .. PHASE .. "] RESULT PASS if warnings match the current context. Next recommended step: run after repeated solo TT finish/exit and a 2-player same-server race smoke, then choose polish vs next feature.")
else
	warn("[" .. PHASE .. "] RESULT FAIL. Review failed checks before adding broader racing features.")
end
