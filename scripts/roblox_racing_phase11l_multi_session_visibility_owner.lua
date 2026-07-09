-- Neo Tokyo Racers - Racing Phase 11L Multi-Session Visibility Owner
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- Fixes overlapping race/time-trial visibility state:
--   * Canonically replaces the isolated RaceParticipantVisibilityClient with a
--     multi-session gate keyed by RunId.
--   * Disables the older simple visibility loop inside RaceEntryMenuClient so
--     it can no longer fight the dedicated visibility owner.
--
-- Scope: isolated Racing clients only. No reward config, route-guide config,
-- matchmaking, arrows, driving, VFX runtime rebuilds, or bootstrap edits.

local PHASE = "NTR Racing Phase 11L"

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function findPath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return nil
		end
	end
	return current
end

local function getScript(path)
	local object = findPath(path)
	if not object then
		fail("Missing " .. path)
	end
	if not (object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript")) then
		fail(path .. " is " .. object.ClassName .. ", expected script.")
	end
	return object
end

local function replaceOnce(source, needle, replacement, label)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1)
end

local PARTICIPANT_VISIBILITY_SOURCE = [==[
-- NTR_RACING_PHASE11L_MULTI_SESSION_VISIBILITY_OWNER

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local RENDER_BIND_NAME = "NTR_RaceParticipantVisibilityGate"
local LATE_RENDER_PRIORITY = 10000

local sessionsByRunId = {}
local originals = setmetatable({}, { __mode = "k" })
local lastRestoreClock = 0

local function runtimeVehiclesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function remember(instance, key, value)
	if not instance then return end
	local data = originals[instance]
	if not data then
		data = {}
		originals[instance] = data
	end
	if data[key] == nil then
		data[key] = value
	end
end

local function originalValue(instance, key, fallback)
	local data = originals[instance]
	if data and data[key] ~= nil then
		return data[key]
	end
	return fallback
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

local function addOrUpdateSession(payload)
	local runId = tostring(payload.RunId or "")
	if runId == "" then
		return
	end
	if payload.Active == true then
		sessionsByRunId[runId] = {
			RunId = runId,
			Participants = participantSet(payload.Participants or {}),
			UpdatedClock = os.clock(),
		}
	else
		sessionsByRunId[runId] = nil
	end
end

local function removeLocalFromRun(runId)
	runId = tostring(runId or "")
	if runId == "" then return end
	local session = sessionsByRunId[runId]
	if session and session.Participants then
		session.Participants[player.UserId] = nil
		if next(session.Participants) == nil then
			sessionsByRunId[runId] = nil
		end
	end
end

local function hasAnyActiveSession()
	return next(sessionsByRunId) ~= nil
end

local function localSessionSet()
	local set = {}
	for runId, session in pairs(sessionsByRunId) do
		if session.Participants and session.Participants[player.UserId] == true then
			set[runId] = true
		end
	end
	return set
end

local function localIsInSession()
	return next(localSessionSet()) ~= nil
end

local function participantRunsForUserId(userId)
	local runs = {}
	userId = tonumber(userId)
	if userId == nil then
		return runs
	end
	for runId, session in pairs(sessionsByRunId) do
		if session.Participants and session.Participants[userId] == true then
			runs[runId] = true
		end
	end
	return runs
end

local function sharesAnyRun(a, b)
	for runId in pairs(a or {}) do
		if b and b[runId] == true then
			return true
		end
	end
	return false
end

local function shouldHideRuns(subjectRuns, explicitRunId)
	if not hasAnyActiveSession() then
		return false
	end

	local localRuns = localSessionSet()
	local localInSession = next(localRuns) ~= nil
	if explicitRunId and explicitRunId ~= "" then
		subjectRuns = subjectRuns or {}
		subjectRuns[explicitRunId] = true
	end

	local subjectInSession = next(subjectRuns or {}) ~= nil
	if localInSession then
		return not sharesAnyRun(localRuns, subjectRuns)
	end
	return subjectInSession
end

local function isToggleable(instance)
	return instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
		or instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
end

local function flushLingeringVfx(instance)
	if instance:IsA("ParticleEmitter") or instance:IsA("Trail") then
		pcall(function()
			instance:Clear()
		end)
	end
end

local function forceRuntimeVfxHostHidden(instance, hidden)
	if not hidden then return end
	if instance:IsA("BasePart") and instance:GetAttribute("NTR_VFXRuntimeHost") == true then
		instance.LocalTransparencyModifier = 1
		instance.Transparency = 1
	end
end

local function setGuiHidden(instance, hidden)
	if not (instance:IsA("BillboardGui") or instance:IsA("SurfaceGui")) then
		return
	end
	remember(instance, "Enabled", instance.Enabled)
	if hidden then
		instance.Enabled = false
	else
		instance.Enabled = originalValue(instance, "Enabled", instance.Enabled)
	end
end

local function setHighlightHidden(instance, hidden)
	if not (instance:IsA("Highlight") or instance:IsA("SelectionBox")) then
		return
	end
	remember(instance, "Enabled", instance.Enabled)
	if hidden then
		instance.Enabled = false
	else
		instance.Enabled = originalValue(instance, "Enabled", instance.Enabled)
	end
end

local function setHumanoidNameHidden(humanoid, hidden)
	if not humanoid then return end
	remember(humanoid, "DisplayDistanceType", humanoid.DisplayDistanceType)
	remember(humanoid, "NameDisplayDistance", humanoid.NameDisplayDistance)
	remember(humanoid, "HealthDisplayDistance", humanoid.HealthDisplayDistance)
	if hidden then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
	else
		humanoid.DisplayDistanceType = originalValue(humanoid, "DisplayDistanceType", humanoid.DisplayDistanceType)
		humanoid.NameDisplayDistance = originalValue(humanoid, "NameDisplayDistance", humanoid.NameDisplayDistance)
		humanoid.HealthDisplayDistance = originalValue(humanoid, "HealthDisplayDistance", humanoid.HealthDisplayDistance)
	end
end

local function setInstanceHidden(instance, hidden)
	if instance:IsA("BasePart") then
		remember(instance, "LocalTransparencyModifier", instance.LocalTransparencyModifier)
		instance.LocalTransparencyModifier = hidden and 1 or originalValue(instance, "LocalTransparencyModifier", 0)
		forceRuntimeVfxHostHidden(instance, hidden)
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		remember(instance, "Transparency", instance.Transparency)
		instance.Transparency = hidden and 1 or originalValue(instance, "Transparency", instance.Transparency)
	elseif isToggleable(instance) then
		if hidden then
			instance.Enabled = false
			flushLingeringVfx(instance)
		end
	else
		setGuiHidden(instance, hidden)
		setHighlightHidden(instance, hidden)
	end
end

local function setModelHidden(model, hidden)
	if not model then return end
	if model:IsA("Model") then
		setHumanoidNameHidden(model:FindFirstChildOfClass("Humanoid"), hidden)
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		setInstanceHidden(descendant, hidden)
		if descendant:IsA("Humanoid") then
			setHumanoidNameHidden(descendant, hidden)
		end
	end
end

local function vehicleOwnerUserId(vehicle)
	return tonumber(vehicle and vehicle:GetAttribute("OwnerUserId"))
end

local function vehicleRunId(vehicle)
	return tostring(vehicle and vehicle:GetAttribute("NTR_RaceRunId") or "")
end

local function applyVisibility()
	for _, other in ipairs(Players:GetPlayers()) do
		local runs = participantRunsForUserId(other.UserId)
		setModelHidden(other.Character, shouldHideRuns(runs, nil))
	end

	local vehiclesRoot = runtimeVehiclesRoot()
	for _, vehicle in ipairs(vehiclesRoot and vehiclesRoot:GetChildren() or {}) do
		if vehicle:IsA("Model") then
			local runs = participantRunsForUserId(vehicleOwnerUserId(vehicle))
			setModelHidden(vehicle, shouldHideRuns(runs, vehicleRunId(vehicle)))
		end
	end
end

local function restoreVisibility()
	for _, other in ipairs(Players:GetPlayers()) do
		setModelHidden(other.Character, false)
	end
	local vehiclesRoot = runtimeVehiclesRoot()
	for _, vehicle in ipairs(vehiclesRoot and vehiclesRoot:GetChildren() or {}) do
		if vehicle:IsA("Model") then
			setModelHidden(vehicle, false)
		end
	end
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "RaceVisibilityUpdate" then
		addOrUpdateSession(payload)
		applyVisibility()
	elseif kind == "RaceFinished"
		or kind == "RaceDNF"
		or kind == "RaceExitedToStart"
		or kind == "RaceEnded"
		or kind == "TimeTrialFinished"
		or kind == "TimeTrialEnded"
		or kind == "TimeTrialError" then
		removeLocalFromRun(payload.RunId)
		if hasAnyActiveSession() then
			applyVisibility()
		else
			restoreVisibility()
		end
	end
end)

Players.PlayerAdded:Connect(function(other)
	other.CharacterAdded:Connect(function()
		task.defer(applyVisibility)
	end)
end)

for _, other in ipairs(Players:GetPlayers()) do
	other.CharacterAdded:Connect(function()
		task.defer(applyVisibility)
	end)
end

RunService:BindToRenderStep(RENDER_BIND_NAME, LATE_RENDER_PRIORITY, function()
	if hasAnyActiveSession() then
		applyVisibility()
	elseif os.clock() - lastRestoreClock > 0.5 then
		lastRestoreClock = os.clock()
		restoreVisibility()
	end
end)

print("[NTR Racing Phase 11L Client] Multi-session race/time-trial visibility owner active.")
]==]

local SESSION_ASSETS_CLIENT_SOURCE = [==[
-- NTR_RACING_PHASE11L_MULTI_SESSION_ASSET_VISIBILITY

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local sessionsByRunId = {}
local localRuns = {}

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
	return session and session.Participants and session.Participants[player.UserId] == true
end

local function bestLocalRun()
	for runId, state in pairs(localRuns) do
		if localIsParticipant(runId) then
			return runId, state
		end
	end
	return nil, nil
end

local function apply()
	hideAll()
	local runId, state = bestLocalRun()
	if not (runId and state and state.RouteId and state.RouteId ~= "") then return end
	local routes = raceRoutesRoot()
	local routeFolder = routes and routes:FindFirstChild(state.RouteId)
	local arrowRoot = routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	if not arrowRoot then return end
	local keys = visibleKeys(routeFolder, state.CurrentSegment or 0)
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

task.defer(function()
	hideAll()
end)

print("[NTR Racing Phase 11L Client] Multi-session folder arrow visibility active.")
]==]

local function replaceParticipantVisibilityClient()
	local scriptObject = getScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active")
	if string.find(scriptObject.Source, "NTR_RACING_PHASE11L_MULTI_SESSION_VISIBILITY_OWNER", 1, true) then
		print("[" .. PHASE .. "] RaceParticipantVisibilityClient already replaced.")
		return false
	end
	scriptObject.Source = PARTICIPANT_VISIBILITY_SOURCE
	print("[" .. PHASE .. "] Replaced RaceParticipantVisibilityClient with multi-session owner.")
	return true
end

local function patchEntryMenuLegacyVisibility()
	local scriptObject = getScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active")
	local source = scriptObject.Source
	if string.find(source, "NTR_RACING_PHASE11L_ENTRY_MENU_LEGACY_VIS_DISABLED", 1, true) then
		print("[" .. PHASE .. "] RaceEntryMenuClient legacy visibility is already disabled.")
		return false
	end

	local oldLoop = [[task.spawn(function()
	while true do
		applyVisibility()
		task.wait(0.5)
	end
end)
]]
	local newLoop = [[-- NTR_RACING_PHASE11L_ENTRY_MENU_LEGACY_VIS_DISABLED
-- Visibility is owned by RaceParticipantVisibilityClient_Active.
-- Keep the old helper definitions inert so this menu client cannot fight the
-- multi-session VFX/name-tag gate when races and time trials overlap.
]]
	source = replaceOnce(source, oldLoop, newLoop, "entry menu legacy visibility loop")

	local oldBranch = [[	elseif kind == "RaceVisibilityUpdate" then
		state.Visibility = {
			Active = payload.Active == true,
			RunId = payload.RunId,
			Participants = payload.Participants or {},
		}
		applyVisibility()
]]
	local newBranch = [[	elseif kind == "RaceVisibilityUpdate" then
		-- NTR_RACING_PHASE11L_ENTRY_MENU_LEGACY_VIS_DISABLED
		-- Dedicated RaceParticipantVisibilityClient_Active owns session hiding.
]]
	source = replaceOnce(source, oldBranch, newBranch, "entry menu RaceVisibilityUpdate branch")

	scriptObject.Source = source
	print("[" .. PHASE .. "] Disabled RaceEntryMenuClient legacy visibility loop.")
	return true
end

local function replaceSessionAssetsClient()
	local scriptObject = getScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionAssetsClient_Active")
	if string.find(scriptObject.Source, "NTR_RACING_PHASE11L_MULTI_SESSION_ASSET_VISIBILITY", 1, true) then
		print("[" .. PHASE .. "] RaceSessionAssetsClient already replaced.")
		return false
	end
	scriptObject.Source = SESSION_ASSETS_CLIENT_SOURCE
	print("[" .. PHASE .. "] Replaced RaceSessionAssetsClient with multi-session arrow visibility.")
	return true
end

local replacedVisibility = replaceParticipantVisibilityClient()
local patchedEntry = patchEntryMenuLegacyVisibility()
local replacedAssets = replaceSessionAssetsClient()

print("[" .. PHASE .. "] Complete. replacedVisibility=" .. tostring(replacedVisibility) .. " patchedEntry=" .. tostring(patchedEntry) .. " replacedAssets=" .. tostring(replacedAssets))
print("[" .. PHASE .. "] Restart Play and retest: player A remains in multiplayer race, player B exits/starts time trial, and neither player sees the other session's vehicle, name tags, or idle VFX.")
