-- NTR_RACING_PHASE11D_PARTICIPANT_VISIBILITY_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local active = false
local activeParticipants = {}
local original = {}
local lastApply = 0

local function runtimeVehicles()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function participantSet(list)
	table.clear(activeParticipants)
	for _, userId in ipairs(list or {}) do
		activeParticipants[tonumber(userId)] = true
	end
end

local function remember(item, key, value)
	local data = original[item]
	if not data then
		data = {}
		original[item] = data
	end
	if data[key] == nil then
		data[key] = value
	end
end

local function setObjectHidden(item, hidden)
	if item:IsA("BasePart") then
		item.LocalTransparencyModifier = hidden and 1 or 0
	elseif item:IsA("Decal") or item:IsA("Texture") then
		remember(item, "Transparency", item.Transparency)
		item.Transparency = hidden and 1 or (original[item] and original[item].Transparency or item.Transparency)
	elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
		remember(item, "Enabled", item.Enabled)
		local data = original[item]
		item.Enabled = hidden and false or (data and data.Enabled or item.Enabled)
	elseif item:IsA("BillboardGui") or item:IsA("SurfaceGui") then
		remember(item, "Enabled", item.Enabled)
		local data = original[item]
		item.Enabled = hidden and false or (data and data.Enabled or item.Enabled)
	end
end

local function setModelHidden(model, hidden)
	for _, item in ipairs(model and model:GetDescendants() or {}) do
		setObjectHidden(item, hidden)
	end
end

local function ownerForVehicle(vehicle)
	return tonumber(vehicle and vehicle:GetAttribute("OwnerUserId"))
end

local function apply()
	if active ~= true then
		for _, other in ipairs(Players:GetPlayers()) do
			setModelHidden(other.Character, false)
		end
		for _, vehicle in ipairs(runtimeVehicles() and runtimeVehicles():GetChildren() or {}) do
			setModelHidden(vehicle, false)
		end
		return
	end
	local localIsParticipant = activeParticipants[player.UserId] == true
	for _, other in ipairs(Players:GetPlayers()) do
		local otherIsParticipant = activeParticipants[other.UserId] == true
		setModelHidden(other.Character, (localIsParticipant and not otherIsParticipant) or ((not localIsParticipant) and otherIsParticipant))
	end
	for _, vehicle in ipairs(runtimeVehicles() and runtimeVehicles():GetChildren() or {}) do
		local vehicleIsParticipant = activeParticipants[ownerForVehicle(vehicle)] == true
		setModelHidden(vehicle, (localIsParticipant and not vehicleIsParticipant) or ((not localIsParticipant) and vehicleIsParticipant))
	end
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "RaceVisibilityUpdate" then
		active = payload.Active == true
		participantSet(payload.Participants or {})
		apply()
	elseif kind == "RaceFinished" or kind == "RaceDNF" or kind == "RaceExitedToStart" or kind == "RaceEnded" or kind == "TimeTrialFinished" or kind == "TimeTrialEnded" then
		if activeParticipants[player.UserId] == true then
			activeParticipants[player.UserId] = nil
		end
		if next(activeParticipants) == nil then
			active = false
		end
		apply()
	end
end)

RunService.Heartbeat:Connect(function()
	if os.clock() - lastApply > 0.25 then
		lastApply = os.clock()
		apply()
	end
end)

print("[NTR Racing Phase 11D Client] Participant body/VFX visibility isolation active.")
