-- NTR_RACING_PHASE10A_SESSION_ASSET_VISIBILITY_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local activeParticipants = {}
local active = false

local function setHidden(model, hidden)
	for _, item in ipairs(model and model:GetDescendants() or {}) do
		if item:IsA("BasePart") and item:GetAttribute("NTR_SessionAsset") == true then
			item.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function isLocalParticipant()
	return activeParticipants[player.UserId] == true
end

local function apply()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local instances = world and world:FindFirstChild("RaceInstances")
	local hide = not (active and isLocalParticipant())
	for _, runFolder in ipairs(instances and instances:GetChildren() or {}) do
		local assets = runFolder:FindFirstChild("SessionAssets")
		if assets then
			setHidden(assets, hide)
		end
	end
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.Type == "RaceVisibilityUpdate" then
		active = payload.Active == true
		table.clear(activeParticipants)
		for _, userId in ipairs(payload.Participants or {}) do
			activeParticipants[tonumber(userId)] = true
		end
		apply()
	elseif payload.Type == "TimeTrialEnded" or payload.Type == "TimeTrialFinished" or payload.Type == "RaceEnded" or payload.Type == "RaceDNF" then
		task.delay(0.1, apply)
	end
end)

task.spawn(function()
	while true do
		apply()
		task.wait(1)
	end
end)

print("[NTR Racing Phase 10A Client] Session asset visibility active.")
