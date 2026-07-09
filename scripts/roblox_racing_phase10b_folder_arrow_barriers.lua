-- NTR Racing Phase 10B - Folder-Based Arrow Barriers
-- Paste into Roblox Studio Command Bar in Edit mode.
--
-- This phase adopts authored ArrowMarkers as the race/time-trial barrier workflow:
--   Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.ArrowMarkers.Checkpoint0-1
--   Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.ArrowMarkers.Checkpoint1-2
--   ...
--   Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.ArrowMarkers.Checkpoint14-0
--
-- Loose "race arrows group" models are moved into Unassigned_Arrows so you can
-- drag them into the correct segment folders without losing placement.
-- This script canonically replaces the isolated Phase 10A asset service/client
-- and adds small guarded segment-update hooks to the isolated Racing services.

local MODE = "INSTALL" -- INSTALL or SMOKE
local MOVE_LOOSE_ARROW_GROUPS_TO_UNASSIGNED = true
local DEFAULT_COLLIDER_THICKNESS = 3
local SEGMENT_WINDOW_BEHIND = 1
local SEGMENT_WINDOW_AHEAD = 1
local PHASE = "NTR Racing Phase 10B"

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function getOrCreate(parent, className, name)
	local item = parent:FindFirstChild(name)
	if item and item.ClassName ~= className then
		fail("Expected " .. parent:GetFullName() .. "." .. name .. " to be " .. className .. ", got " .. item.ClassName)
	end
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function racingServices()
	local root = ServerScriptService:FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	local racing = services and services:FindFirstChild("Racing")
	if not racing then fail("Missing ServerScriptService.NeoTokyoRacers.Services.Racing") end
	return racing
end

local function racingClientControllers()
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = starterScripts and starterScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	if not racing then fail("Missing StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing") end
	return racing
end

local function raceRoutesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local routes = world and world:FindFirstChild("RaceRoutes")
	if not routes then fail("Missing Workspace.NeoTokyoRacersWorld.RaceRoutes") end
	return routes
end

local function parseCheckpointIndex(part)
	local attr = tonumber(part:GetAttribute("CheckpointIndex"))
	if attr then return attr end
	local fromName = string.match(part.Name, "[Cc]heckpoint%s*(%d+)") or string.match(part.Name, "^(%d+)$")
	return tonumber(fromName)
end

local function maxCheckpointIndex(route)
	local checkpoints = route:FindFirstChild("Checkpoints")
	local maxIndex = 0
	for _, item in ipairs(checkpoints and checkpoints:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			local index = parseCheckpointIndex(item)
			if index and index > maxIndex then
				maxIndex = index
			end
		end
	end
	return maxIndex
end

local function parseSegmentName(name)
	local from, to = string.match(name, "^Checkpoint(%d+)%-(%d+)$")
	if from then return tonumber(from), tonumber(to), "Checkpoint" .. from .. "-" .. to end
	from = string.match(name, "^Checkpoint(%d+)%-Finish$")
	if from then return tonumber(from), "Finish", "Checkpoint" .. from .. "-Finish" end
	return nil
end

local function markArrowPart(part, segmentFolder, routeId)
	if not part:IsA("BasePart") then return end
	if part:GetAttribute("NTR_ArrowOriginalTransparency") == nil then
		part:SetAttribute("NTR_ArrowOriginalTransparency", part.Transparency)
	end
	part:SetAttribute("NTR_RaceArrowPart", true)
	part:SetAttribute("NTR_RaceRouteId", routeId)
	part:SetAttribute("NTR_ArrowSegmentKey", segmentFolder:GetAttribute("SegmentKey"))
	part:SetAttribute("NTR_ArrowColliderThickness", tonumber(part:GetAttribute("NTR_ArrowColliderThickness")) or DEFAULT_COLLIDER_THICKNESS)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

local function setupRouteArrowFolders(route)
	local arrowMarkers = getOrCreate(route, "Folder", "ArrowMarkers")
	arrowMarkers:SetAttribute("NTR_Phase10B_FolderSegments", true)
	arrowMarkers:SetAttribute("SegmentWindowBehind", tonumber(arrowMarkers:GetAttribute("SegmentWindowBehind")) or SEGMENT_WINDOW_BEHIND)
	arrowMarkers:SetAttribute("SegmentWindowAhead", tonumber(arrowMarkers:GetAttribute("SegmentWindowAhead")) or SEGMENT_WINDOW_AHEAD)
	arrowMarkers:SetAttribute("DefaultColliderThickness", tonumber(arrowMarkers:GetAttribute("DefaultColliderThickness")) or DEFAULT_COLLIDER_THICKNESS)

	local routeType = tostring(route:GetAttribute("RouteType") or "Circuit")
	if routeType ~= "PointToPoint" then routeType = "Circuit" end
	local maxIndex = maxCheckpointIndex(route)
	if maxIndex < 1 then
		log("Skipped " .. route.Name .. ": no checkpoint index found.")
		return 0, 0
	end

	local created = 0
	for index = 0, maxIndex - 1 do
		local name = "Checkpoint" .. tostring(index) .. "-" .. tostring(index + 1)
		local folder = getOrCreate(arrowMarkers, "Folder", name)
		folder:SetAttribute("NTR_ArrowSegmentFolder", true)
		folder:SetAttribute("SegmentFrom", index)
		folder:SetAttribute("SegmentTo", index + 1)
		folder:SetAttribute("SegmentKey", name)
		folder:SetAttribute("Enabled", folder:GetAttribute("Enabled") ~= false)
		created += 1
	end

	local finalName = routeType == "Circuit" and ("Checkpoint" .. tostring(maxIndex) .. "-0") or ("Checkpoint" .. tostring(maxIndex) .. "-Finish")
	local finalFolder = getOrCreate(arrowMarkers, "Folder", finalName)
	finalFolder:SetAttribute("NTR_ArrowSegmentFolder", true)
	finalFolder:SetAttribute("SegmentFrom", maxIndex)
	finalFolder:SetAttribute("SegmentTo", routeType == "Circuit" and 0 or "Finish")
	finalFolder:SetAttribute("SegmentKey", finalName)
	finalFolder:SetAttribute("Enabled", finalFolder:GetAttribute("Enabled") ~= false)
	created += 1

	local moved = 0
	local unassigned = getOrCreate(arrowMarkers, "Folder", "Unassigned_Arrows")
	unassigned:SetAttribute("NTR_ArrowUnassigned", true)
	if MOVE_LOOSE_ARROW_GROUPS_TO_UNASSIGNED then
		for _, child in ipairs(arrowMarkers:GetChildren()) do
			local lower = string.lower(child.Name)
			if child ~= unassigned and child:IsA("Model") and string.find(lower, "race arrows", 1, true) then
				child.Parent = unassigned
				moved += 1
			end
		end
	end

	for _, folder in ipairs(arrowMarkers:GetChildren()) do
		local from, to, key = parseSegmentName(folder.Name)
		if folder:IsA("Folder") and from ~= nil then
			folder:SetAttribute("NTR_ArrowSegmentFolder", true)
			folder:SetAttribute("SegmentFrom", from)
			folder:SetAttribute("SegmentTo", to)
			folder:SetAttribute("SegmentKey", key)
			for _, item in ipairs(folder:GetDescendants()) do
				markArrowPart(item, folder, route.Name)
			end
		end
	end

	log("Prepared " .. route.Name .. " ArrowMarkers: segment folders=" .. tostring(created) .. ", loose groups moved to Unassigned_Arrows=" .. tostring(moved))
	return created, moved
end

local SERVICE_SOURCE = [==[
-- NTR_RACING_PHASE10B_FOLDER_ARROW_BARRIER_SERVICE

local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

local PHASE = "NTR Racing Phase 10B Assets"
local ASSET_GROUP = "NTR_RaceSessionAsset"
local PARTICIPANT_GROUP = "NTR_RaceParticipant"

local racingRoot = script.Parent
local bindings = racingRoot:FindFirstChild("RaceSessionAssetBindings") or Instance.new("Folder")
bindings.Name = "RaceSessionAssetBindings"
bindings.Parent = racingRoot

local sessionBinding = bindings:FindFirstChild("SessionAssets") or Instance.new("BindableFunction")
sessionBinding.Name = "SessionAssets"
sessionBinding.Parent = bindings

local sessions = {}
local originalGroups = {}

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function ensureGroup(name)
	pcall(function() PhysicsService:RegisterCollisionGroup(name) end)
end

local function configureCollisionGroups()
	ensureGroup(ASSET_GROUP)
	ensureGroup(PARTICIPANT_GROUP)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ASSET_GROUP, "Default", false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(ASSET_GROUP, PARTICIPANT_GROUP, true) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(PARTICIPANT_GROUP, "Default", true) end)
end

local function setPartCollisionGroup(part, groupName)
	if not (part and part:IsA("BasePart")) then return end
	if originalGroups[part] == nil then
		originalGroups[part] = part.CollisionGroup
	end
	pcall(function()
		part.CollisionGroup = groupName
	end)
end

local function restorePartCollisionGroup(part)
	if not (part and part:IsA("BasePart")) then return end
	local original = originalGroups[part]
	if original ~= nil then
		pcall(function()
			part.CollisionGroup = original
		end)
		originalGroups[part] = nil
	end
end

local function setModelGroup(model, groupName)
	for _, item in ipairs(model and model:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			setPartCollisionGroup(item, groupName)
		end
	end
end

local function restoreModelGroup(model)
	for _, item in ipairs(model and model:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			restorePartCollisionGroup(item)
		end
	end
end

local function routeFoldersRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	return world and world:FindFirstChild("RaceRoutes")
end

local function parseSegmentFolder(folder)
	if not (folder and folder:IsA("Folder")) then return nil end
	local from = tonumber(folder:GetAttribute("SegmentFrom"))
	local to = folder:GetAttribute("SegmentTo")
	local key = tostring(folder:GetAttribute("SegmentKey") or folder.Name)
	if from == nil then
		local a, b = string.match(folder.Name, "^Checkpoint(%d+)%-(%d+)$")
		if a then
			from = tonumber(a)
			to = tonumber(b)
			key = "Checkpoint" .. a .. "-" .. b
		else
			a = string.match(folder.Name, "^Checkpoint(%d+)%-Finish$")
			if a then
				from = tonumber(a)
				to = "Finish"
				key = "Checkpoint" .. a .. "-Finish"
			end
		end
	end
	if from == nil then return nil end
	if tonumber(to) ~= nil then to = tonumber(to) end
	return {
		Folder = folder,
		From = from,
		To = to,
		Key = key,
	}
end

local function collectSegments(routeFolder)
	local arrowRoot = routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	local segments = {}
	local maxFrom = 0
	local wraps = false
	for _, child in ipairs(arrowRoot and arrowRoot:GetChildren() or {}) do
		local segment = parseSegmentFolder(child)
		if segment and child:GetAttribute("Enabled") ~= false then
			segments[segment.From] = segment
			if segment.From > maxFrom then maxFrom = segment.From end
			if segment.To == 0 then wraps = true end
		end
	end
	return segments, maxFrom, wraps
end

local function segmentWindow(routeFolder, currentSegment)
	local segments, maxFrom, wraps = collectSegments(routeFolder)
	local arrowRoot = routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	local behind = tonumber(arrowRoot and arrowRoot:GetAttribute("SegmentWindowBehind")) or 1
	local ahead = tonumber(arrowRoot and arrowRoot:GetAttribute("SegmentWindowAhead")) or 1
	local current = math.floor(tonumber(currentSegment) or 0)
	local result = {}
	for offset = -behind, ahead do
		local index = current + offset
		if wraps and maxFrom > 0 then
			index = ((index % (maxFrom + 1)) + (maxFrom + 1)) % (maxFrom + 1)
		end
		local segment = segments[index]
		if segment then
			result[segment.Key] = segment
		end
	end
	return result
end

local function inflateSize(size, thickness)
	thickness = math.max(0.25, tonumber(thickness) or 3)
	if size.X <= size.Y and size.X <= size.Z then
		return Vector3.new(math.max(size.X, thickness), size.Y, size.Z)
	elseif size.Y <= size.X and size.Y <= size.Z then
		return Vector3.new(size.X, math.max(size.Y, thickness), size.Z)
	end
	return Vector3.new(size.X, size.Y, math.max(size.Z, thickness))
end

local function hideAuthoringArrows(routeFolder)
	local arrowRoot = routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	for _, item in ipairs(arrowRoot and arrowRoot:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			if item:GetAttribute("NTR_ArrowOriginalTransparency") == nil then
				item:SetAttribute("NTR_ArrowOriginalTransparency", item.Transparency)
			end
			item.Transparency = 1
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
		end
	end
end

local function makeProxy(sourcePart, state, segmentKey)
	local proxy = Instance.new("Part")
	proxy.Name = "ArrowProxy_" .. tostring(segmentKey)
	proxy.Anchored = true
	proxy.CanCollide = true
	proxy.CanTouch = false
	proxy.CanQuery = true
	proxy.Transparency = 1
	proxy.Size = inflateSize(sourcePart.Size, sourcePart:GetAttribute("NTR_ArrowColliderThickness") or state.DefaultColliderThickness)
	proxy.CFrame = sourcePart.CFrame
	proxy:SetAttribute("NTR_SessionAsset", true)
	proxy:SetAttribute("NTR_ArrowProxy", true)
	proxy:SetAttribute("RunId", state.RunId)
	proxy:SetAttribute("RouteId", state.RouteId)
	proxy:SetAttribute("SegmentKey", tostring(segmentKey))
	setPartCollisionGroup(proxy, ASSET_GROUP)
	proxy.Parent = state.ProxyFolder
	table.insert(state.Assets, proxy)
	return proxy
end

local function rebuildProxies(state)
	if not state then return end
	for _, child in ipairs(state.ProxyFolder:GetChildren()) do
		child:Destroy()
	end
	table.clear(state.Assets)
	local union = {}
	for _, segment in pairs(state.ParticipantSegments) do
		for key, folderInfo in pairs(segmentWindow(state.RouteFolder, segment)) do
			union[key] = folderInfo
		end
	end
	local created = 0
	for key, infoData in pairs(union) do
		for _, item in ipairs(infoData.Folder:GetDescendants()) do
			if item:IsA("BasePart") then
				makeProxy(item, state, key)
				created += 1
			end
		end
	end
	state.ProxyFolder:SetAttribute("ActiveProxyCount", created)
	state.ProxyFolder:SetAttribute("LastRebuiltClock", os.clock())
end

local function applyParticipants(runId, participants)
	local state = sessions[runId]
	if not state then return end
	for _, participant in ipairs(participants or {}) do
		local player = participant.Player
		local vehicle = participant.Vehicle
		if player then
			state.ParticipantSegments[player.UserId] = state.ParticipantSegments[player.UserId] or 0
			if player.Character then
				setModelGroup(player.Character, PARTICIPANT_GROUP)
				table.insert(state.ParticipantModels, player.Character)
			end
		end
		if vehicle then
			setModelGroup(vehicle, PARTICIPANT_GROUP)
			table.insert(state.ParticipantModels, vehicle)
		end
	end
	rebuildProxies(state)
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

local function createForRun(payload)
	payload = typeof(payload) == "table" and payload or {}
	local runId = tostring(payload.RunId or "")
	local routeFolder = payload.RouteFolder or (payload.Route and payload.Route.Folder)
	local sessionFolder = payload.SessionFolder
	if runId == "" or not (routeFolder and routeFolder.Parent) or not (sessionFolder and sessionFolder.Parent) then
		return { Ok = false, Created = 0, Message = "Missing route/session data." }
	end
	clearForRun({ RunId = runId })
	hideAuthoringArrows(routeFolder)
	local assetsFolder = sessionFolder:FindFirstChild("SessionAssets") or Instance.new("Folder")
	assetsFolder.Name = "SessionAssets"
	assetsFolder.Parent = sessionFolder
	local proxyFolder = assetsFolder:FindFirstChild("ArrowBarrierProxies") or Instance.new("Folder")
	proxyFolder.Name = "ArrowBarrierProxies"
	proxyFolder.Parent = assetsFolder
	local arrowRoot = routeFolder:FindFirstChild("ArrowMarkers")
	local state = {
		RunId = runId,
		RouteId = tostring(payload.RouteId or routeFolder.Name),
		RouteFolder = routeFolder,
		SessionFolder = sessionFolder,
		ProxyFolder = proxyFolder,
		Assets = {},
		ParticipantModels = {},
		ParticipantSegments = {},
		DefaultColliderThickness = tonumber(arrowRoot and arrowRoot:GetAttribute("DefaultColliderThickness")) or 3,
	}
	sessions[runId] = state
	applyParticipants(runId, payload.Participants or {})
	info("Created arrow barrier session for " .. runId .. " with " .. tostring(#state.Assets) .. " active proxies.")
	return { Ok = true, Created = #state.Assets }
end

local function updateParticipantSegment(payload)
	payload = typeof(payload) == "table" and payload or {}
	local runId = tostring(payload.RunId or "")
	local state = sessions[runId]
	if not state then return { Ok = false, Message = "No session for run." } end
	local userId = tonumber(payload.UserId) or 0
	if userId <= 0 then return { Ok = false, Message = "Missing UserId." } end
	state.ParticipantSegments[userId] = math.max(0, math.floor(tonumber(payload.CurrentSegment) or 0))
	rebuildProxies(state)
	return { Ok = true, Created = #state.Assets }
end

sessionBinding.OnInvoke = function(action, payload)
	if action == "CreateForRun" then
		return createForRun(payload)
	elseif action == "ClearForRun" then
		return clearForRun(payload)
	elseif action == "ApplyParticipants" then
		payload = typeof(payload) == "table" and payload or {}
		applyParticipants(tostring(payload.RunId or ""), payload.Participants or {})
		return { Ok = true }
	elseif action == "UpdateParticipantSegment" then
		return updateParticipantSegment(payload)
	end
	return { Ok = false, Message = "Unknown session asset action." }
end

configureCollisionGroups()

task.defer(function()
	local routes = routeFoldersRoot()
	for _, routeFolder in ipairs(routes and routes:GetChildren() or {}) do
		hideAuthoringArrows(routeFolder)
	end
end)

info("Folder arrow barrier service active. Visual arrows stay client-local; invisible box proxies collide only with race participants.")
]==]

local CLIENT_SOURCE = [==[
-- NTR_RACING_PHASE10B_FOLDER_ARROW_VISIBILITY_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local activeRunId = nil
local activeRouteId = nil
local currentSegment = 0
local activeParticipants = {}

local function raceRoutesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	return world and world:FindFirstChild("RaceRoutes")
end

local function parseSegmentFolder(folder)
	if not (folder and folder:IsA("Folder")) then return nil end
	local from = tonumber(folder:GetAttribute("SegmentFrom"))
	local to = folder:GetAttribute("SegmentTo")
	local key = tostring(folder:GetAttribute("SegmentKey") or folder.Name)
	if from == nil then
		local a, b = string.match(folder.Name, "^Checkpoint(%d+)%-(%d+)$")
		if a then
			from = tonumber(a)
			to = tonumber(b)
			key = "Checkpoint" .. a .. "-" .. b
		else
			a = string.match(folder.Name, "^Checkpoint(%d+)%-Finish$")
			if a then
				from = tonumber(a)
				to = "Finish"
				key = "Checkpoint" .. a .. "-Finish"
			end
		end
	end
	if from == nil then return nil end
	if tonumber(to) ~= nil then to = tonumber(to) end
	return { Folder = folder, From = from, To = to, Key = key }
end

local function collectSegments(routeFolder)
	local arrowRoot = routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	local segments = {}
	local maxFrom = 0
	local wraps = false
	for _, child in ipairs(arrowRoot and arrowRoot:GetChildren() or {}) do
		local segment = parseSegmentFolder(child)
		if segment and child:GetAttribute("Enabled") ~= false then
			segments[segment.From] = segment
			if segment.From > maxFrom then maxFrom = segment.From end
			if segment.To == 0 then wraps = true end
		end
	end
	return segments, maxFrom, wraps
end

local function visibleKeys(routeFolder, segmentIndex)
	local segments, maxFrom, wraps = collectSegments(routeFolder)
	local arrowRoot = routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	local behind = tonumber(arrowRoot and arrowRoot:GetAttribute("SegmentWindowBehind")) or 1
	local ahead = tonumber(arrowRoot and arrowRoot:GetAttribute("SegmentWindowAhead")) or 1
	local current = math.floor(tonumber(segmentIndex) or 0)
	local keys = {}
	for offset = -behind, ahead do
		local index = current + offset
		if wraps and maxFrom > 0 then
			index = ((index % (maxFrom + 1)) + (maxFrom + 1)) % (maxFrom + 1)
		end
		local segment = segments[index]
		if segment then keys[segment.Key] = true end
	end
	return keys
end

local function setFolderVisible(folder, visible)
	for _, item in ipairs(folder and folder:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			if visible then
				local original = tonumber(item:GetAttribute("NTR_ArrowOriginalTransparency"))
				item.LocalTransparencyModifier = 0
				item.Transparency = original ~= nil and original or 0
			else
				item.LocalTransparencyModifier = 1
			end
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
		end
	end
end

local function hideAll()
	local routes = raceRoutesRoot()
	for _, routeFolder in ipairs(routes and routes:GetChildren() or {}) do
		local arrowRoot = routeFolder:FindFirstChild("ArrowMarkers")
		for _, item in ipairs(arrowRoot and arrowRoot:GetChildren() or {}) do
			if item:IsA("Folder") or item:IsA("Model") then
				setFolderVisible(item, false)
			elseif item:IsA("BasePart") then
				item.LocalTransparencyModifier = 1
			end
		end
	end
end

local function isLocalParticipant()
	return activeParticipants[player.UserId] == true
end

local function apply()
	hideAll()
	if not (activeRunId and activeRouteId and isLocalParticipant()) then return end
	local routes = raceRoutesRoot()
	local routeFolder = routes and routes:FindFirstChild(activeRouteId)
	local arrowRoot = routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	if not arrowRoot then return end
	local keys = visibleKeys(routeFolder, currentSegment)
	for _, child in ipairs(arrowRoot:GetChildren()) do
		local segment = parseSegmentFolder(child)
		if segment and keys[segment.Key] == true then
			setFolderVisible(child, true)
		end
	end
end

local function updateSegmentFromPayload(payload)
	local nextGate = tonumber(payload.NextGateIndex) or 1
	currentSegment = math.max(0, nextGate - 1)
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "RaceVisibilityUpdate" then
		table.clear(activeParticipants)
		for _, userId in ipairs(payload.Participants or {}) do
			activeParticipants[tonumber(userId)] = true
		end
		if payload.Active ~= true then
			activeRunId = nil
			activeRouteId = nil
		end
		apply()
		return
	end
	if kind == "TimeTrialStaged" or kind == "TimeTrialStarted" or kind == "TimeTrialCheckpoint" or kind == "TimeTrialLapCompleted" or kind == "TimeTrialReset"
		or kind == "RaceStaged" or kind == "RaceStarted" or kind == "RaceCheckpoint" or kind == "RaceReset" then
		activeRunId = tostring(payload.RunId or activeRunId or "")
		activeRouteId = tostring(payload.RouteId or activeRouteId or "")
		updateSegmentFromPayload(payload)
		apply()
	elseif kind == "TimeTrialEnded" or kind == "TimeTrialFinished" or kind == "RaceEnded" or kind == "RaceDNF" then
		activeRunId = nil
		activeRouteId = nil
		currentSegment = 0
		apply()
	end
end)

task.defer(function()
	hideAll()
end)

print("[NTR Racing Phase 10B Client] Folder arrow segment visibility active.")
]==]

local function installCanonicalScripts()
	local services = racingServices()
	local service = getOrCreate(services, "Script", "RaceSessionAssetService_Active")
	service.Source = SERVICE_SOURCE
	service.Disabled = false

	local clients = racingClientControllers()
	local client = getOrCreate(clients, "LocalScript", "RaceSessionAssetsClient_Active")
	client.Source = CLIENT_SOURCE
	client.Disabled = false
	log("Installed canonical Phase 10B RaceSessionAssetService_Active and RaceSessionAssetsClient_Active.")
end

local function insertAfter(source, anchor, insertText, marker, scriptName)
	if string.find(source, marker, 1, true) then
		return source, false
	end
	local at = string.find(source, anchor, 1, true)
	if not at then
		fail("Could not find source anchor in " .. scriptName .. ": " .. anchor)
	end
	local insertAt = at + #anchor
	return string.sub(source, 1, insertAt) .. insertText .. string.sub(source, insertAt + 1), true
end

local function patchScriptSource(scriptObj, patcher)
	if not scriptObj then fail("Missing script to patch.") end
	local source = scriptObj.Source
	local newSource, changed = patcher(source, scriptObj.Name)
	if changed then
		scriptObj.Source = newSource
		log("Patched " .. scriptObj:GetFullName())
	else
		log(scriptObj.Name .. " already has Phase 10B segment hooks.")
	end
end

local function patchTimeTrialService()
	local scriptObj = racingServices():FindFirstChild("TimeTrialService_Active")
	patchScriptSource(scriptObj, function(source, scriptName)
		local changedAny = false
		local insert

		insert = [=[

		-- NTR_RACING_PHASE10B_RESET_SEGMENT_UPDATE
		callSessionAssetService("UpdateParticipantSegment", {
			RunId = run.RunId,
			UserId = player.UserId,
			CurrentSegment = math.max(0, (tonumber(run.NextGateIndex) or 1) - 1),
		})]=]
		source, changedAny = insertAfter(source, [=[		callSessionAssetService("ApplyParticipants", {
			RunId = run.RunId,
			Participants = {
				{ Player = player, Vehicle = run.Vehicle },
			},
		})]=], insert, "NTR_RACING_PHASE10B_RESET_SEGMENT_UPDATE", scriptName)

		insert = [=[

			-- NTR_RACING_PHASE10B_LAP_SEGMENT_UPDATE
			callSessionAssetService("UpdateParticipantSegment", {
				RunId = run.RunId,
				UserId = player.UserId,
				CurrentSegment = 0,
			})]=]
		local changed
		source, changed = insertAfter(source, [=[			run.NextGateIndex = 1
			run.LastCompletedGateIndex = 0
			run.Splits = {}]=], insert, "NTR_RACING_PHASE10B_LAP_SEGMENT_UPDATE", scriptName)
		changedAny = changedAny or changed

		insert = [=[

	-- NTR_RACING_PHASE10B_CHECKPOINT_SEGMENT_UPDATE
	callSessionAssetService("UpdateParticipantSegment", {
		RunId = run.RunId,
		UserId = player.UserId,
		CurrentSegment = math.max(0, (tonumber(run.NextGateIndex) or 1) - 1),
	})]=]
		source, changed = insertAfter(source, [=[	run.LastCompletedGateIndex = run.NextGateIndex
	run.NextGateIndex += 1]=], insert, "NTR_RACING_PHASE10B_CHECKPOINT_SEGMENT_UPDATE", scriptName)
		changedAny = changedAny or changed
		return source, changedAny
	end)
end

local function patchRaceService()
	local scriptObj = racingServices():FindFirstChild("RaceMatchmakingService_Active")
	patchScriptSource(scriptObj, function(source, scriptName)
		local changedAny = false
		local insert

		insert = [=[

		-- NTR_RACING_PHASE10B_RESET_SEGMENT_UPDATE
		callSessionAssetService("UpdateParticipantSegment", {
			RunId = race.RunId,
			UserId = player.UserId,
			CurrentSegment = math.max(0, (tonumber(entry.NextGateIndex) or 1) - 1),
		})]=]
		source, changedAny = insertAfter(source, [=[		callSessionAssetService("ApplyParticipants", {
			RunId = race.RunId,
			Participants = {
				{ Player = player, Vehicle = entry.Vehicle },
			},
		})]=], insert, "NTR_RACING_PHASE10B_RESET_SEGMENT_UPDATE", scriptName)

		insert = [=[

	-- NTR_RACING_PHASE10B_CHECKPOINT_SEGMENT_UPDATE
	callSessionAssetService("UpdateParticipantSegment", {
		RunId = race.RunId,
		UserId = entry.Player.UserId,
		CurrentSegment = math.max(0, (tonumber(entry.NextGateIndex) or 1) - 1),
	})]=]
		local changed
		source, changed = insertAfter(source, [=[	entry.LastCompletedGateIndex = entry.NextGateIndex
	entry.NextGateIndex += 1]=], insert, "NTR_RACING_PHASE10B_CHECKPOINT_SEGMENT_UPDATE", scriptName)
		changedAny = changedAny or changed
		return source, changedAny
	end)
end

local function setupArrowRoutes()
	local routes = raceRoutesRoot()
	local totalCreated = 0
	local totalMoved = 0
	for _, route in ipairs(routes:GetChildren()) do
		if route:IsA("Folder") then
			local created, moved = setupRouteArrowFolders(route)
			totalCreated += created or 0
			totalMoved += moved or 0
		end
	end
	log("Arrow route setup complete. Segment folders touched=" .. tostring(totalCreated) .. ", loose arrow groups moved=" .. tostring(totalMoved))
end

local function smoke()
	local routes = raceRoutesRoot()
	local routeCount = 0
	local segmentCount = 0
	local unassignedCount = 0
	for _, route in ipairs(routes:GetChildren()) do
		if route:IsA("Folder") then
			routeCount += 1
			local arrowRoot = route:FindFirstChild("ArrowMarkers")
			for _, child in ipairs(arrowRoot and arrowRoot:GetChildren() or {}) do
				if parseSegmentName(child.Name) then
					segmentCount += 1
				elseif child.Name == "Unassigned_Arrows" then
					unassignedCount += #child:GetChildren()
				end
			end
		end
	end
	local service = racingServices():FindFirstChild("RaceSessionAssetService_Active")
	local client = racingClientControllers():FindFirstChild("RaceSessionAssetsClient_Active")
	log("Smoke: routes=" .. routeCount .. ", segmentFolders=" .. segmentCount .. ", unassignedArrowGroups=" .. unassignedCount)
	log("Smoke: asset service=" .. tostring(service and service.Source:find("NTR_RACING_PHASE10B_FOLDER_ARROW_BARRIER_SERVICE", 1, true) ~= nil) .. ", client=" .. tostring(client and client.Source:find("NTR_RACING_PHASE10B_FOLDER_ARROW_VISIBILITY_CLIENT", 1, true) ~= nil))
end

if MODE == "SMOKE" then
	smoke()
elseif MODE == "INSTALL" then
	setupArrowRoutes()
	installCanonicalScripts()
	patchTimeTrialService()
	patchRaceService()
	smoke()
	log("Install complete. Move arrow groups from Unassigned_Arrows into CheckpointA-B folders, then restart Play to test.")
else
	fail("Unknown MODE: " .. tostring(MODE))
end
