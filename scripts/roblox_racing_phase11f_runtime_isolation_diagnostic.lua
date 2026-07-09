-- Neo Tokyo Racers - Racing Phase 11F Runtime Isolation Diagnostic
-- Read-only diagnostic. Run in Roblox Studio Command Bar while Play is running.
--
-- Best timing:
-- 1) Start a 2-player local server race.
-- 2) Drive past checkpoint 2 where the arrow/barrier collision stops working.
-- 3) Paste/run this script in the Command Bar.
-- 4) Copy the Output block back to Codex.
--
-- This script does not patch sources, create instances, or change collision state.

local PHASE = "NTR Racing Phase 11F Diagnostic"
local WATCH_SECONDS = 24
local SAMPLE_INTERVAL = 3
local MAX_PROXY_SAMPLES = 10
local MAX_VEHICLE_SAMPLES = 8

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function warnLog(message)
	warn("[" .. PHASE .. "] " .. tostring(message))
end

local function findPath(path)
	local current = game
	local serviceNames = {
		Workspace = true,
		ServerScriptService = true,
		ReplicatedStorage = true,
		StarterPlayer = true,
		Players = true,
		Lighting = true,
		ServerStorage = true,
	}
	for token in string.gmatch(path, "[^%.]+") do
		if not current then
			return nil
		end
		if current == game and serviceNames[token] then
			local ok, service = pcall(function()
				return game:GetService(token)
			end)
			current = ok and service or nil
		else
			current = current:FindFirstChild(token)
		end
	end
	return current
end

local function sourceHas(path, marker)
	local obj = findPath(path)
	if not obj then
		return false, "missing"
	end
	if not (obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")) then
		return false, obj.ClassName
	end
	local ok, source = pcall(function()
		return obj.Source
	end)
	if not ok then
		return false, "source unreadable"
	end
	return string.find(source, marker, 1, true) ~= nil, tostring(#source) .. " chars"
end

local function describeScript(path, marker)
	local obj = findPath(path)
	if not obj then
		log("Script missing: " .. path)
		return
	end
	local disabledText = ""
	if obj:IsA("Script") or obj:IsA("LocalScript") then
		disabledText = " Disabled=" .. tostring(obj.Disabled)
	end
	if marker then
		local hasMarker, detail = sourceHas(path, marker)
		log("Script " .. path .. disabledText .. " marker=" .. tostring(hasMarker) .. " detail=" .. tostring(detail))
	else
		log("Script " .. path .. disabledText)
	end
end

local function collisionGroupNames()
	local names = {}
	local ok, groups = pcall(function()
		return PhysicsService:GetRegisteredCollisionGroups()
	end)
	if ok and typeof(groups) == "table" then
		for _, group in ipairs(groups) do
			table.insert(names, tostring(group.name or group.Name))
		end
	end
	table.sort(names)
	return names
end

local function areCollidable(a, b)
	local ok, result = pcall(function()
		return PhysicsService:CollisionGroupsAreCollidable(a, b)
	end)
	if ok then
		return tostring(result)
	end
	return "error:" .. tostring(result)
end

local function partCollisionGroup(part)
	local ok, group = pcall(function()
		return part.CollisionGroup
	end)
	if ok and group then
		return tostring(group)
	end
	local okLegacy, legacy = pcall(function()
		return PhysicsService:GetCollisionGroupName(part.CollisionGroupId)
	end)
	if okLegacy then
		return tostring(legacy)
	end
	return "unknown"
end

local function countPartsByGroup(model)
	local counts = {}
	local total = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			total += 1
			local group = partCollisionGroup(descendant)
			counts[group] = (counts[group] or 0) + 1
		end
	end
	local chunks = {}
	for group, count in pairs(counts) do
		table.insert(chunks, group .. "=" .. tostring(count))
	end
	table.sort(chunks)
	return total, table.concat(chunks, ", ")
end

local function countLocalVfx(model)
	local total = 0
	local enabled = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
			or descendant:IsA("Fire")
			or descendant:IsA("Smoke")
			or descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight") then
			total += 1
			local ok, isEnabled = pcall(function()
				return descendant.Enabled
			end)
			if ok and isEnabled == true then
				enabled += 1
			end
		end
	end
	return total, enabled
end

local function dumpStaticState()
	log("RunService IsRunning=" .. tostring(RunService:IsRunning()) .. " IsServer=" .. tostring(RunService:IsServer()) .. " IsClient=" .. tostring(RunService:IsClient()))
	describeScript("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active", "NTR_RACING_PHASE11E_COLLISION_POLICY")
	describeScript("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active", "NTR_RACING_PHASE11E_CHECKPOINT_COLLISION_REAPPLY")
	describeScript("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime", "NTR_RACING_PHASE11E_VFX_GATE")
	describeScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active")
	describeScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active")
	describeScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionAssetsClient_Active")

	local groups = collisionGroupNames()
	log("Collision groups registered: " .. table.concat(groups, ", "))
	log("Collidable NTR_RaceSessionAsset <-> NTR_RaceParticipant = " .. areCollidable("NTR_RaceSessionAsset", "NTR_RaceParticipant"))
	log("Collidable NTR_RaceParticipant <-> NTR_RaceParticipant = " .. areCollidable("NTR_RaceParticipant", "NTR_RaceParticipant"))
	log("Collidable NTR_RaceParticipant <-> Default = " .. areCollidable("NTR_RaceParticipant", "Default"))
	log("Collidable NTR_RaceSessionAsset <-> Default = " .. areCollidable("NTR_RaceSessionAsset", "Default"))
end

local function dumpProxyFolder(proxyFolder)
	local countsByGroup = {}
	local segmentCounts = {}
	local samples = {}
	local totalParts = 0
	for _, descendant in ipairs(proxyFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			totalParts += 1
			local group = partCollisionGroup(descendant)
			countsByGroup[group] = (countsByGroup[group] or 0) + 1
			local segmentKey = descendant:GetAttribute("SegmentKey")
			if segmentKey ~= nil then
				segmentCounts[tostring(segmentKey)] = (segmentCounts[tostring(segmentKey)] or 0) + 1
			end
			if #samples < MAX_PROXY_SAMPLES then
				table.insert(samples, descendant.Name
					.. " segment=" .. tostring(segmentKey)
					.. " group=" .. group
					.. " collide=" .. tostring(descendant.CanCollide)
					.. " pos=" .. tostring(descendant.Position))
			end
		end
	end
	local groupChunks = {}
	for group, count in pairs(countsByGroup) do
		table.insert(groupChunks, group .. "=" .. tostring(count))
	end
	table.sort(groupChunks)
	local segmentChunks = {}
	for segment, count in pairs(segmentCounts) do
		table.insert(segmentChunks, segment .. "=" .. tostring(count))
	end
	table.sort(segmentChunks)

	log("Proxy folder " .. proxyFolder:GetFullName()
		.. " children=" .. tostring(#proxyFolder:GetChildren())
		.. " parts=" .. tostring(totalParts)
		.. " ActiveProxyCount=" .. tostring(proxyFolder:GetAttribute("ActiveProxyCount"))
		.. " ActiveSegmentCount=" .. tostring(proxyFolder:GetAttribute("ActiveSegmentCount"))
		.. " ParticipantSegments=" .. tostring(proxyFolder:GetAttribute("ParticipantSegments"))
		.. " LastRebuiltClock=" .. tostring(proxyFolder:GetAttribute("LastRebuiltClock")))
	log("Proxy groups: " .. table.concat(groupChunks, ", "))
	log("Proxy segment counts: " .. table.concat(segmentChunks, ", "))
	for _, sample in ipairs(samples) do
		log("Proxy sample: " .. sample)
	end
end

local function dumpRaceInstances()
	local world = findPath("Workspace.NeoTokyoRacersWorld")
	local instances = world and world:FindFirstChild("RaceInstances")
	if not instances then
		log("No Workspace.NeoTokyoRacersWorld.RaceInstances folder found.")
		return
	end
	local children = instances:GetChildren()
	log("RaceInstances count=" .. tostring(#children))
	for _, runFolder in ipairs(children) do
		log("Run folder " .. runFolder.Name
			.. " Mode=" .. tostring(runFolder:GetAttribute("Mode"))
			.. " RouteId=" .. tostring(runFolder:GetAttribute("RouteId"))
			.. " State=" .. tostring(runFolder:GetAttribute("State"))
			.. " Participants=" .. tostring(runFolder:GetAttribute("Participants")))
		local sessionAssets = runFolder:FindFirstChild("SessionAssets")
		local proxyFolder = sessionAssets and sessionAssets:FindFirstChild("ArrowBarrierProxies")
		if proxyFolder then
			dumpProxyFolder(proxyFolder)
		else
			log("No ArrowBarrierProxies under " .. runFolder:GetFullName())
		end
	end
end

local function dumpRuntimeVehicles()
	local vehiclesRoot = findPath("Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles")
	if not vehiclesRoot then
		log("No Runtime.PlayerVehicles folder found.")
		return
	end
	local vehicles = vehiclesRoot:GetChildren()
	log("Runtime vehicles count=" .. tostring(#vehicles))
	local samples = 0
	for _, vehicle in ipairs(vehicles) do
		if vehicle:IsA("Model") then
			samples += 1
			if samples > MAX_VEHICLE_SAMPLES then
				break
			end
			local totalParts, groupSummary = countPartsByGroup(vehicle)
			local vfxTotal, vfxEnabled = countLocalVfx(vehicle)
			log("Vehicle " .. vehicle:GetFullName()
				.. " OwnerUserId=" .. tostring(vehicle:GetAttribute("OwnerUserId"))
				.. " DriverUserId=" .. tostring(vehicle:GetAttribute("DriverUserId"))
				.. " RaceParticipant=" .. tostring(vehicle:GetAttribute("NTR_RaceParticipant"))
				.. " RaceRunId=" .. tostring(vehicle:GetAttribute("NTR_RaceRunId"))
				.. " RaceMode=" .. tostring(vehicle:GetAttribute("NTR_RaceMode"))
				.. " parts=" .. tostring(totalParts)
				.. " groups={" .. groupSummary .. "}"
				.. " vfxEnabled=" .. tostring(vfxEnabled) .. "/" .. tostring(vfxTotal))
		end
	end
end

local function dumpRacingRemotes()
	local racing = findPath("ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing")
	if not racing then
		log("Racing remotes folder missing.")
		return
	end
	local names = {}
	for _, child in ipairs(racing:GetChildren()) do
		table.insert(names, child.Name .. ":" .. child.ClassName)
	end
	table.sort(names)
	log("Racing remotes: " .. table.concat(names, ", "))
end

local function dumpSample(sampleIndex)
	log("---- sample " .. tostring(sampleIndex) .. " ----")
	dumpRaceInstances()
	dumpRuntimeVehicles()
	dumpRacingRemotes()
end

dumpStaticState()
if not RunService:IsRunning() then
	warnLog("Studio is not in Play mode. Static source/collision data was printed, but runtime race/vehicle state needs Play mode during the broken race.")
end

local sampleIndex = 1
dumpSample(sampleIndex)
local startTime = os.clock()
while os.clock() - startTime < WATCH_SECONDS do
	task.wait(SAMPLE_INTERVAL)
	sampleIndex += 1
	dumpSample(sampleIndex)
end

log("Diagnostic complete. Paste the full Output block back into Codex.")
