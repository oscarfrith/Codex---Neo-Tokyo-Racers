-- NTR_RACING_PHASE11L_ARROW_VISUAL_PROXY_SYNC

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local sessionsByRunId = {}
local localRuns = {}
local lastApplyClock = 0

local function worldRoot()
	return Workspace:FindFirstChild("NeoTokyoRacersWorld")
end

local function raceRoutesRoot()
	local world = worldRoot()
	return world and world:FindFirstChild("RaceRoutes")
end

local function raceInstancesRoot()
	local world = worldRoot()
	return world and world:FindFirstChild("RaceInstances")
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
				item.LocalTransparencyModifier = 0
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

local function participantSet(list)
	local set = {}
	for _, userId in ipairs(list or {}) do
		local numeric = tonumber(userId)
		if numeric ~= nil then
			set[numeric] = true
		end
	end
	return set
end

local function updateVisibilitySession(payload)
	local runId = tostring(payload.RunId or "")
	if runId == "" then return end
	if payload.Active == true then
		sessionsByRunId[runId] = {
			RunId = runId,
			Participants = participantSet(payload.Participants or {}),
		}
	else
		sessionsByRunId[runId] = nil
		localRuns[runId] = nil
	end
end

local function localIsParticipant(runId)
	local session = sessionsByRunId[tostring(runId or "")]
	if session and session.Participants and session.Participants[player.UserId] == true then
		return true
	end
	-- If the local player has direct run events, keep visuals alive even if a
	-- visibility update arrives late or is cleared before the end event.
	return localRuns[tostring(runId or "")] ~= nil
end

local function bestLocalRun()
	for runId, state in pairs(localRuns) do
		if localIsParticipant(runId) then
			return runId, state
		end
	end
	return nil, nil
end

local function proxyFolderForRun(runId)
	local instances = raceInstancesRoot()
	local runFolder = instances and instances:FindFirstChild(tostring(runId or ""))
	local assets = runFolder and runFolder:FindFirstChild("SessionAssets")
	local proxies = assets and assets:FindFirstChild("ArrowBarrierProxies")
	return proxies
end

local function proxySegmentForRun(runId)
	local proxies = proxyFolderForRun(runId)
	local text = tostring(proxies and proxies:GetAttribute("ParticipantSegments") or "")
	local localUser = tostring(player.UserId)
	for userId, segment in string.gmatch(text, "([^:,]+):([^,]+)") do
		if tostring(userId) == localUser then
			local numeric = tonumber(segment)
			if numeric ~= nil then
				return math.max(0, math.floor(numeric))
			end
		end
	end
	return nil
end

local function apply()
	hideAll()
	local runId, state = bestLocalRun()
	if not (runId and state and state.RouteId and state.RouteId ~= "") then return end
	local routes = raceRoutesRoot()
	local routeFolder = routes and routes:FindFirstChild(state.RouteId)
	local arrowRoot = routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	if not arrowRoot then return end
	local segmentIndex = proxySegmentForRun(runId)
	if segmentIndex == nil then
		segmentIndex = state.CurrentSegment or 0
	end
	state.LastAppliedSegment = segmentIndex
	local keys = visibleKeys(routeFolder, segmentIndex)
	for _, child in ipairs(arrowRoot:GetChildren()) do
		local segment = parseSegmentFolder(child)
		if segment and keys[segment.Key] == true then
			setFolderVisible(child, true)
		end
	end
end

local function updateLocalRunFromPayload(payload)
	local runId = tostring(payload.RunId or "")
	if runId == "" then return end
	localRuns[runId] = localRuns[runId] or { RunId = runId, CurrentSegment = 0 }
	localRuns[runId].RouteId = tostring(payload.RouteId or localRuns[runId].RouteId or "")
	local nextGate = tonumber(payload.NextGateIndex) or 1
	localRuns[runId].CurrentSegment = math.max(0, nextGate - 1)
end

local function removeLocalRun(runId)
	runId = tostring(runId or "")
	if runId ~= "" then
		localRuns[runId] = nil
	end
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "RaceVisibilityUpdate" then
		updateVisibilitySession(payload)
		apply()
		return
	end
	if kind == "TimeTrialStaged" or kind == "TimeTrialStarted" or kind == "TimeTrialCheckpoint" or kind == "TimeTrialLapCompleted" or kind == "TimeTrialReset"
		or kind == "RaceStaged" or kind == "RaceStarted" or kind == "RaceCheckpoint" or kind == "RaceReset" then
		updateLocalRunFromPayload(payload)
		apply()
	elseif kind == "TimeTrialEnded" or kind == "TimeTrialFinished" or kind == "RaceFinished" or kind == "RaceEnded" or kind == "RaceDNF" or kind == "RaceExitedToStart" then
		removeLocalRun(payload.RunId)
		apply()
	end
end)

task.spawn(function()
	while true do
		if next(localRuns) ~= nil and os.clock() - lastApplyClock > 0.2 then
			lastApplyClock = os.clock()
			apply()
		end
		task.wait(0.1)
	end
end)

task.defer(function()
	hideAll()
end)

print("[NTR Racing Phase 11L Client] Arrow visuals sync from server proxy segments.")
