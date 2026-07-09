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
