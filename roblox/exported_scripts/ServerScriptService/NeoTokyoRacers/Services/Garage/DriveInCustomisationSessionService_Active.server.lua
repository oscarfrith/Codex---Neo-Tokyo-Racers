-- Neo Tokyo Racers - Drive-In Customisation Session Service
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE2_SESSION_SERVICE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:FindFirstChild("Shared") or Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = kit
local remotes = shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = shared
local uiRemotes = remotes:FindFirstChild("UI") or Instance.new("Folder")
uiRemotes.Name = "UI"
uiRemotes.Parent = remotes

local remote = uiRemotes:FindFirstChild("DriveInCustomisationSession")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DriveInCustomisationSession"
	remote.Parent = uiRemotes
end

local saved = {}

local function holdPoint()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	local customisation = dealership and dealership:FindFirstChild("Customisation")
	local point = customisation and customisation:FindFirstChild("DriveInCustomisationPlayerHoldPoint")
	return point and point:IsA("BasePart") and point or nil
end

local function characterParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function lockPlayer(player)
	local _, humanoid, root = characterParts(player)
	if not humanoid or not root then return end
	if not saved[player] then
		saved[player] = {
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoRotate = humanoid.AutoRotate,
			RootAnchored = root.Anchored,
		}
	end
	humanoid.Sit = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	local point = holdPoint()
	if point then
		root.CFrame = point.CFrame + Vector3.new(0, 3, 0)
	end
	root.Anchored = true
	player:SetAttribute("NTR_DriveInServerLocked", true)
end

local function unlockPlayer(player)
	local _, humanoid, root = characterParts(player)
	local state = saved[player]
	if humanoid and state then
		humanoid.WalkSpeed = state.WalkSpeed or 16
		humanoid.JumpPower = state.JumpPower or humanoid.JumpPower
		humanoid.JumpHeight = state.JumpHeight or humanoid.JumpHeight
		humanoid.AutoRotate = state.AutoRotate ~= false
	end
	if root then
		root.Anchored = state and state.RootAnchored == true or false
	end
	saved[player] = nil
	player:SetAttribute("NTR_DriveInServerLocked", false)
end

remote.OnServerEvent:Connect(function(player, locked)
	if locked == true then
		lockPlayer(player)
	else
		unlockPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saved[player] = nil
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if player:GetAttribute("NTR_DriveInServerLocked") == true then
			lockPlayer(player)
		end
	end)
end)
