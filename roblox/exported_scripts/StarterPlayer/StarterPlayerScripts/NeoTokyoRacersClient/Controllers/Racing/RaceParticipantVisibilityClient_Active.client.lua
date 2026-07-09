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
