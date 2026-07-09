-- Neo Tokyo Racers - Racing Phase 11H Visibility, VFX, and Name Tag Gate
-- Run in Roblox Studio Command Bar in Edit mode, then restart Play.
--
-- Canonically replaces only the isolated Racing visibility client:
-- StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active
--
-- Purpose:
-- - free-roam players should not see active race/time-trial players, vehicles, VFX, or name tags;
-- - active racers/time-trial players should not see unrelated free-roam players, vehicles, VFX, or name tags;
-- - racers in the same race can still see each other.

local PHASE = "NTR Racing Phase 11H"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function child(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		fail("Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
	end
	if className and not item:IsA(className) then
		fail(item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
	end
	return item
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function scriptParent()
	local StarterPlayer = game:GetService("StarterPlayer")
	local starterScripts = child(StarterPlayer, "StarterPlayerScripts")
	local clientRoot = ensureFolder(starterScripts, "NeoTokyoRacersClient")
	local controllers = ensureFolder(clientRoot, "Controllers")
	return ensureFolder(controllers, "Racing")
end

local SOURCE = [==[
-- NTR_RACING_PHASE11H_VISIBILITY_VFX_NAMETAG_GATE

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

local active = false
local activeRunId = nil
local activeParticipants = {}
local originals = setmetatable({}, { __mode = "k" })
local lastRestoreClock = 0

local function runtimeVehiclesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function clearParticipants()
	table.clear(activeParticipants)
end

local function setParticipants(list)
	clearParticipants()
	for _, userId in ipairs(list or {}) do
		local numeric = tonumber(userId)
		if numeric ~= nil then
			activeParticipants[numeric] = true
		end
	end
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
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		remember(instance, "Transparency", instance.Transparency)
		instance.Transparency = hidden and 1 or originalValue(instance, "Transparency", instance.Transparency)
	elseif isToggleable(instance) then
		-- Do not restore VFX/light Enabled here. The real VFX owner should decide
		-- when visible again; this gate only forces hidden session effects off.
		if hidden then
			instance.Enabled = false
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

local function localIsParticipant()
	return activeParticipants[player.UserId] == true
end

local function playerIsParticipant(other)
	return activeParticipants[other.UserId] == true
end

local function vehicleOwnerUserId(vehicle)
	return tonumber(vehicle and vehicle:GetAttribute("OwnerUserId"))
end

local function vehicleIsParticipant(vehicle)
	local ownerId = vehicleOwnerUserId(vehicle)
	return (ownerId ~= nil and activeParticipants[ownerId] == true)
		or (vehicle and vehicle:GetAttribute("NTR_RaceParticipant") == true)
end

local function shouldHideParticipantState(isParticipant)
	if active ~= true then
		return false
	end
	local localParticipant = localIsParticipant()
	if localParticipant then
		return not isParticipant
	end
	return isParticipant
end

local function applyVisibility()
	for _, other in ipairs(Players:GetPlayers()) do
		setModelHidden(other.Character, shouldHideParticipantState(playerIsParticipant(other)))
	end

	local vehiclesRoot = runtimeVehiclesRoot()
	for _, vehicle in ipairs(vehiclesRoot and vehiclesRoot:GetChildren() or {}) do
		if vehicle:IsA("Model") then
			setModelHidden(vehicle, shouldHideParticipantState(vehicleIsParticipant(vehicle)))
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

local function removeLocalParticipantAndMaybeDeactivate()
	activeParticipants[player.UserId] = nil
	if next(activeParticipants) == nil then
		active = false
		activeRunId = nil
	end
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "RaceVisibilityUpdate" then
		active = payload.Active == true
		activeRunId = tostring(payload.RunId or "")
		setParticipants(payload.Participants or {})
		applyVisibility()
	elseif kind == "RaceFinished"
		or kind == "RaceDNF"
		or kind == "RaceExitedToStart"
		or kind == "RaceEnded"
		or kind == "TimeTrialFinished"
		or kind == "TimeTrialEnded" then
		removeLocalParticipantAndMaybeDeactivate()
		if active then
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
	if active then
		-- Run late every frame while a race/time-trial visibility boundary exists.
		-- This wins over VFX controllers that re-enable particles during RenderStepped.
		applyVisibility()
	elseif os.clock() - lastRestoreClock > 0.5 then
		lastRestoreClock = os.clock()
		restoreVisibility()
	end
end)

print("[NTR Racing Phase 11H Client] Race participant visibility, VFX, and name tag gate active.")
]==]

local parent = scriptParent()
local visibilityClient = parent:FindFirstChild("RaceParticipantVisibilityClient_Active")
if not visibilityClient then
	visibilityClient = Instance.new("LocalScript")
	visibilityClient.Name = "RaceParticipantVisibilityClient_Active"
	visibilityClient.Parent = parent
end
if not visibilityClient:IsA("LocalScript") then
	fail(visibilityClient:GetFullName() .. " is " .. visibilityClient.ClassName .. ", expected LocalScript")
end

visibilityClient.Source = SOURCE
visibilityClient.Disabled = false

info("Installed canonical RaceParticipantVisibilityClient_Active Phase 11H gate.")
info("Restart Play. Test free-roam vs race/time-trial clients: hidden participants should have no body, vehicle, VFX, or name tag visibility.")
