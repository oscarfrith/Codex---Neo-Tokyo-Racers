-- Neo Tokyo Racers - Racing Phase 11J Prototype Baseline Audit
-- Read-only. Run in Roblox Studio Command Bar.
--
-- Recommended:
-- 1) Run once in Edit mode after Phase 11I is confirmed.
-- 2) Optionally run during Play while a time trial or race is active.
--
-- This script does not patch source, create instances, delete objects, or change config.

local PHASE = "NTR Racing Phase 11J Audit"

local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local passCount = 0
local warnCount = 0
local failCount = 0

local function out(level, message)
	local text = "[" .. PHASE .. "] " .. level .. " - " .. tostring(message)
	if level == "FAIL" then
		warn(text)
	else
		print(text)
	end
end

local function pass(message)
	passCount += 1
	out("PASS", message)
end

local function warnAudit(message)
	warnCount += 1
	out("WARN", message)
end

local function fail(message)
	failCount += 1
	out("FAIL", message)
end

local function service(name)
	local ok, result = pcall(function()
		return game:GetService(name)
	end)
	return ok and result or nil
end

local function findPath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		if not current then return nil end
		if current == game then
			current = service(token) or current:FindFirstChild(token)
		else
			current = current:FindFirstChild(token)
		end
	end
	return current
end

local function checkPath(path, className, label, required)
	local item = findPath(path)
	if not item then
		if required == false then
			warnAudit((label or path) .. " missing.")
		else
			fail((label or path) .. " missing.")
		end
		return nil
	end
	if className and not item:IsA(className) then
		fail((label or path) .. " is " .. item.ClassName .. ", expected " .. className .. ".")
		return item
	end
	pass((label or path) .. " present.")
	return item
end

local function sourceContains(path, marker, label, required)
	local scriptObject = findPath(path)
	if not scriptObject then
		if RunService:IsClient() and string.sub(path, 1, #"ServerScriptService.") == "ServerScriptService." then
			warnAudit((label or marker) .. " source owner is server-only; run in Edit mode or a server context for this marker check.")
			return false
		end
		if required == false then
			warnAudit((label or marker) .. " source owner missing.")
		else
			fail((label or marker) .. " source owner missing.")
		end
		return false
	end
	if not (scriptObject:IsA("Script") or scriptObject:IsA("LocalScript") or scriptObject:IsA("ModuleScript")) then
		fail((label or path) .. " is not a script.")
		return false
	end
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	if not ok then
		if RunService:IsClient() and string.sub(path, 1, #"ServerScriptService.") == "ServerScriptService." then
			warnAudit((label or path) .. " source is server-only; run in Edit mode or a server context for this marker check.")
			return false
		end
		warnAudit((label or path) .. " source unreadable in this context.")
		return false
	end
	if string.find(source, marker, 1, true) then
		pass((label or marker) .. " marker present.")
		return true
	end
	if required == false then
		warnAudit((label or marker) .. " marker missing.")
	else
		fail((label or marker) .. " marker missing.")
	end
	return false
end

local function attrSummary(instance, names)
	local chunks = {}
	for _, name in ipairs(names) do
		table.insert(chunks, name .. "=" .. tostring(instance and instance:GetAttribute(name)))
	end
	return table.concat(chunks, ", ")
end

local function countChildrenOfClass(parent, className)
	local count = 0
	for _, child in ipairs(parent and parent:GetChildren() or {}) do
		if not className or child:IsA(className) then
			count += 1
		end
	end
	return count
end

local function countDescendantParts(parent)
	local count = 0
	for _, descendant in ipairs(parent and parent:GetDescendants() or {}) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

local function checkCollisionGroups()
	local groups = {}
	local ok, registered = pcall(function()
		return PhysicsService:GetRegisteredCollisionGroups()
	end)
	if ok then
		for _, group in ipairs(registered) do
			groups[tostring(group.name or group.Name)] = true
		end
	end
	if groups.NTR_RaceSessionAsset then pass("NTR_RaceSessionAsset collision group registered.") else fail("NTR_RaceSessionAsset collision group missing.") end
	if groups.NTR_RaceParticipant then pass("NTR_RaceParticipant collision group registered.") else fail("NTR_RaceParticipant collision group missing.") end
	local okAsset, assetParticipant = pcall(function()
		return PhysicsService:CollisionGroupsAreCollidable("NTR_RaceSessionAsset", "NTR_RaceParticipant")
	end)
	if okAsset and assetParticipant == true then pass("Race assets collide with race participants.") else fail("Race assets do not collide with race participants.") end
	local okDefault, assetDefault = pcall(function()
		return PhysicsService:CollisionGroupsAreCollidable("NTR_RaceSessionAsset", "Default")
	end)
	if okDefault and assetDefault == false then pass("Race assets do not collide with Default.") else warnAudit("Race assets may collide with Default.") end
	local okSelf, participantSelf = pcall(function()
		return PhysicsService:CollisionGroupsAreCollidable("NTR_RaceParticipant", "NTR_RaceParticipant")
	end)
	if okSelf and participantSelf == false then pass("Race participants do not collide with each other.") else warnAudit("Race participants may still collide with each other.") end
end

local function checkRoute(routeId)
	local route = checkPath("Workspace.NeoTokyoRacersWorld.RaceRoutes." .. routeId, "Folder", "Route " .. routeId, true)
	if not route then return end

	local startZones = route:FindFirstChild("StartZones")
	if startZones then
		pass("StartZones folder present.")
		if startZones:FindFirstChild("RaceStartZone") then pass("RaceStartZone present.") else fail("RaceStartZone missing.") end
		if startZones:FindFirstChild("TimeTrialStartZone") then pass("TimeTrialStartZone present.") else fail("TimeTrialStartZone missing.") end
	else
		fail("StartZones folder missing.")
	end

	local checkpoints = route:FindFirstChild("Checkpoints")
	local checkpointCount = countChildrenOfClass(checkpoints, "BasePart")
	if checkpointCount >= 2 then pass("Checkpoint parts found: " .. checkpointCount .. ".") else fail("Too few checkpoint parts: " .. checkpointCount .. ".") end

	local spawnGrid = route:FindFirstChild("SpawnGrid")
	local gridCount = countChildrenOfClass(spawnGrid, "BasePart")
	if gridCount >= 2 then pass("SpawnGrid parts found: " .. gridCount .. ".") else warnAudit("SpawnGrid has fewer than 2 parts: " .. gridCount .. ".") end

	local teleportPoints = route:FindFirstChild("TeleportPoints")
	if teleportPoints and countChildrenOfClass(teleportPoints, "BasePart") >= 1 then
		pass("TeleportPoints has at least one arrival part.")
	else
		warnAudit("TeleportPoints missing or empty.")
	end

	local arrowMarkers = route:FindFirstChild("ArrowMarkers")
	if not arrowMarkers then
		fail("ArrowMarkers folder missing.")
		return
	end
	local segmentFolders = 0
	local segmentParts = 0
	for _, child in ipairs(arrowMarkers:GetChildren()) do
		if child:IsA("Folder") and string.match(child.Name, "^Checkpoint%d+%-") then
			segmentFolders += 1
			segmentParts += countDescendantParts(child)
		end
	end
	if segmentFolders >= checkpointCount then
		pass("Arrow segment folders found: " .. segmentFolders .. ".")
	else
		warnAudit("Arrow segment folder count looks low: " .. segmentFolders .. " for " .. checkpointCount .. " checkpoints.")
	end
	if segmentParts > 0 then pass("Arrow segment parts found: " .. segmentParts .. ".") else warnAudit("No arrow segment parts found.") end
end

local function checkRacingConfig()
	checkPath("ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing.RaceRequest", "RemoteFunction", "RaceRequest remote", true)
	checkPath("ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing.RaceEvent", "RemoteEvent", "RaceEvent remote", true)
	checkPath("ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing.RaceQueueRequest", "RemoteFunction", "RaceQueueRequest remote", true)
	checkPath("ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing.RaceQueueEvent", "RemoteEvent", "RaceQueueEvent remote", true)
	checkPath("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Racing.RaceRouteDefinition", "ModuleScript", "RaceRouteDefinition module", true)
	checkPath("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Racing.RaceConfigReader", "ModuleScript", "RaceConfigReader module", true)
	checkPath("ReplicatedStorage.NeoTokyoRacers.Config.Racing.Rewards.TimeTrial", "Folder", "Rewards.TimeTrial config", true)
	checkPath("ReplicatedStorage.NeoTokyoRacers.Config.Racing.Rewards.Race", "Folder", "Rewards.Race config", true)
	checkPath("ReplicatedStorage.NeoTokyoRacers.Config.Racing.Matchmaking", "Folder", "Matchmaking config", true)
end

local function checkSourceMarkers()
	sourceContains("ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active", "NTR_RACING_PHASE11C_SERVER_GRID_SPAWN_HELPERS", "TimeTrial server grid spawn", true)
	sourceContains("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active", "NTR_RACING_PHASE11C_SERVER_GRID_SPAWN_HELPERS", "Race matchmaking grid spawn", true)
	sourceContains("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active", "NTR_RACING_PHASE11D_FINISH_BOUNDARY", "Race finish boundary cleanup", true)
	sourceContains("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active", "NTR_RACING_PHASE10B_FOLDER_ARROW_BARRIER_SERVICE", "Folder arrow barrier service", true)
	sourceContains("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active", "NTR_RACING_PHASE11G_STUDIO_USERID_FIX", "Studio UserId session asset fix", true)
	sourceContains("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active", "NTR_RACING_PHASE11H_VISIBILITY_VFX_NAMETAG_GATE", "Visibility/VFX/name tag gate", true)
	sourceContains("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active", "NTR_RACING_PHASE11I_IDLE_VFX_FLUSH", "Idle VFX flush", true)
	sourceContains("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTransitionClient_Active", "NTR_RACING_PHASE8D_TRANSITION_CLIENT", "Race transition client", false)
end

local function checkRuntime()
	if not RunService:IsRunning() then
		warnAudit("Not in Play mode. Runtime race/vehicle checks skipped.")
		return
	end
	local instances = findPath("Workspace.NeoTokyoRacersWorld.RaceInstances")
	if instances then
		pass("RaceInstances folder present in Play.")
		for _, runFolder in ipairs(instances:GetChildren()) do
			print("[" .. PHASE .. "] RUNTIME - " .. runFolder:GetFullName() .. " attrs: " .. attrSummary(runFolder, { "Mode", "RouteId", "ParticipantCount", "State" }))
			local proxies = runFolder:FindFirstChild("SessionAssets") and runFolder.SessionAssets:FindFirstChild("ArrowBarrierProxies")
			if proxies then
				print("[" .. PHASE .. "] RUNTIME - proxies=" .. tostring(#proxies:GetChildren())
					.. " ActiveProxyCount=" .. tostring(proxies:GetAttribute("ActiveProxyCount"))
					.. " ActiveSegmentCount=" .. tostring(proxies:GetAttribute("ActiveSegmentCount"))
					.. " ParticipantSegments=" .. tostring(proxies:GetAttribute("ParticipantSegments")))
			end
		end
	else
		warnAudit("RaceInstances folder not present in Play.")
	end

	local vehicles = findPath("Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles")
	if vehicles then
		pass("Runtime PlayerVehicles folder present.")
		for _, vehicle in ipairs(vehicles:GetChildren()) do
			if vehicle:IsA("Model") then
				print("[" .. PHASE .. "] RUNTIME - vehicle=" .. vehicle.Name .. " "
					.. attrSummary(vehicle, { "OwnerUserId", "DriverUserId", "NTR_RaceParticipant", "NTR_RaceRunId", "NTR_RaceMode", "DriveReady" }))
			end
		end
	else
		warnAudit("Runtime PlayerVehicles folder missing in Play.")
	end
end

print("[" .. PHASE .. "] Starting prototype baseline audit. IsRunning=" .. tostring(RunService:IsRunning()) .. " IsClient=" .. tostring(RunService:IsClient()) .. " IsServer=" .. tostring(RunService:IsServer()))

checkRacingConfig()
checkRoute("ShiftedCanalSprint")
checkCollisionGroups()
checkSourceMarkers()
checkRuntime()

print("[" .. PHASE .. "] Summary: PASS=" .. tostring(passCount) .. " WARN=" .. tostring(warnCount) .. " FAIL=" .. tostring(failCount))
if failCount == 0 then
	print("[" .. PHASE .. "] Baseline audit completed without failures. Review warnings before treating the prototype racing baseline as locked.")
else
	warn("[" .. PHASE .. "] Baseline audit found failures. Fix these before adding persistence/leaderboard features.")
end
