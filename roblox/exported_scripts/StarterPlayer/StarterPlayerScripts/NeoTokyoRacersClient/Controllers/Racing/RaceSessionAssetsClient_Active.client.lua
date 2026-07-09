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
	elseif kind == "TimeTrialEnded" or kind == "TimeTrialFinished" or kind == "RaceFinished" or kind == "RaceEnded" or kind == "RaceDNF" or kind == "RaceExitedToStart" then
		-- NTR_RACING_PHASE11D_ARROW_CLIENT_CLEAR_FINISH
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
