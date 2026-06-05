-- Neo Tokyo Racers - Dealership Intro Progress Service Active
-- Installed by scripts/roblox_dealership_intro_phase8_dynamic_arrow_tether_once.lua
--
-- Persists the first dealership desk objective completion per player.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LOG_PREFIX = "[NTR Dealership Intro Progress]"
local COMPLETE_ATTRIBUTE = "NTRDealershipIntroObjectiveComplete"
local LOADED_ATTRIBUTE = "NTRDealershipIntroObjectiveLoaded"
local REMOTE_FOLDER_NAME = "DealershipIntro"
local GET_REMOTE_NAME = "GetDealershipIntroObjectiveComplete"
local COMPLETE_REMOTE_NAME = "CompleteDealershipIntroObjective"
local DEFAULT_DATASTORE_NAME = "NTR_DealershipIntro_v1"

local function log(message)
	print(LOG_PREFIX .. " " .. message)
end

local function warnLine(message)
	warn(LOG_PREFIX .. " " .. message)
end

local function getAttribute(instance, name, fallback)
	if not instance then
		return fallback
	end

	local value = instance:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") then
			error(existing:GetFullName() .. " is " .. existing.ClassName .. ", expected Folder.")
		end
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing.ClassName ~= className then
			error(existing:GetFullName() .. " is " .. existing.ClassName .. ", expected " .. className .. ".")
		end
		return existing
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function getIntro()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	return dealership and dealership:FindFirstChild("Intro")
end

local function getDeskTrigger(intro)
	local deskFolder = intro and intro:FindFirstChild("Desk")
	local deskTrigger = deskFolder and deskFolder:FindFirstChild("GarageDeskTrigger")
	if deskTrigger and deskTrigger:IsA("BasePart") then
		return deskTrigger
	end
	return nil
end

local function getDataStore()
	local intro = getIntro()
	local dataStoreName = tostring(getAttribute(intro, "DataStoreName", DEFAULT_DATASTORE_NAME))
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(dataStoreName)
	end)
	if ok then
		return store
	end

	warnLine("Could not open DataStore `" .. dataStoreName .. "`; progress will be session-only. " .. tostring(store))
	return nil
end

local dataStore = getDataStore()

local neoTokyo = ensureFolder(ReplicatedStorage, "NeoTokyoRacers")
local shared = ensureFolder(neoTokyo, "Shared")
local remotes = ensureFolder(shared, "Remotes")
local remoteFolder = ensureFolder(remotes, REMOTE_FOLDER_NAME)
local getCompleteRemote = ensureRemote(remoteFolder, GET_REMOTE_NAME, "RemoteFunction")
local completeRemote = ensureRemote(remoteFolder, COMPLETE_REMOTE_NAME, "RemoteEvent")

local function dataKey(player)
	return "desk_objective_" .. tostring(player.UserId)
end

local function loadPlayer(player)
	player:SetAttribute(LOADED_ATTRIBUTE, false)

	local complete = false
	if dataStore then
		local ok, result = pcall(function()
			return dataStore:GetAsync(dataKey(player))
		end)
		if ok then
			complete = result == true
		else
			warnLine("GetAsync failed for " .. player.Name .. "; using session fallback. " .. tostring(result))
		end
	end

	if player.Parent then
		player:SetAttribute(COMPLETE_ATTRIBUTE, complete)
		player:SetAttribute(LOADED_ATTRIBUTE, true)
	end
end

local function savePlayerComplete(player)
	player:SetAttribute(COMPLETE_ATTRIBUTE, true)
	player:SetAttribute(LOADED_ATTRIBUTE, true)

	if not dataStore then
		return false
	end

	local ok, err = pcall(function()
		dataStore:SetAsync(dataKey(player), true)
	end)
	if not ok then
		warnLine("SetAsync failed for " .. player.Name .. "; completion is set for this session only. " .. tostring(err))
		return false
	end

	return true
end

local function waitForLoaded(player)
	local started = os.clock()
	while player.Parent and player:GetAttribute(LOADED_ATTRIBUTE) ~= true and os.clock() - started < 8 do
		task.wait(0.1)
	end
	return player:GetAttribute(COMPLETE_ATTRIBUTE) == true
end

local function isNearDesk(player)
	local intro = getIntro()
	local deskTrigger = getDeskTrigger(intro)
	if not deskTrigger then
		warnLine("Cannot validate completion distance; GarageDeskTrigger was not found.")
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local activationDistance = tonumber(getAttribute(deskTrigger, "ActivationDistance", nil))
		or tonumber(getAttribute(intro, "DeskActivationDistance", 5))
		or 5
	local maxDistance = tonumber(getAttribute(intro, "CompletionServerMaxDistance", 20)) or 20
	maxDistance = math.max(maxDistance, activationDistance + 8)
	return (root.Position - deskTrigger.Position).Magnitude <= maxDistance
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

getCompleteRemote.OnServerInvoke = function(player)
	return waitForLoaded(player)
end

completeRemote.OnServerEvent:Connect(function(player)
	if waitForLoaded(player) then
		return
	end

	if not isNearDesk(player) then
		warnLine("Rejected completion from " .. player.Name .. " because they are not near GarageDeskTrigger.")
		return
	end

	local persisted = savePlayerComplete(player)
	log("Marked dealership desk objective complete for " .. player.Name .. (persisted and " and saved it." or " for this session."))
end)

log("Ready. Remotes: " .. remoteFolder:GetFullName())
