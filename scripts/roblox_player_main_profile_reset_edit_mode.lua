-- Neo Tokyo Racers - Targeted main player profile reset
-- NTR_TARGETED_MAIN_PROFILE_RESET_V1
-- Run once from Studio's Edit-mode Command Bar. This permanently deletes the
-- configured main profile for TARGET_USER_ID. It does not touch intro or racing data.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Targeted Main Profile Reset] "
local TARGET_USER_ID = 7915427645
local REQUIRED_CONFIRMATION = "RESET_MAIN_PROFILE_7915427645"
local CONFIRMATION = "RESET_MAIN_PROFILE_7915427645"

local function fail(message)
	error(PREFIX .. tostring(message), 0)
end

local function expect(condition, message)
	if not condition then fail(message) end
end

local function countDictionary(value)
	local count = 0
	if typeof(value) == "table" then
		for _ in pairs(value) do count += 1 end
	end
	return count
end

expect(not RunService:IsRunning(), "Stop Play and run this command in Edit mode.")
expect(TARGET_USER_ID == 7915427645, "Target user ID changed unexpectedly.")
expect(CONFIRMATION == REQUIRED_CONFIRMATION, "Explicit reset confirmation does not match the target user.")

local editPlayerCount = #Players:GetPlayers()
if editPlayerCount > 0 then
	print(PREFIX .. "INFO Studio exposes " .. tostring(editPlayerCount)
		.. " Player object(s), but RunService confirms no simulation is running")
end

local ntrServer = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = ntrServer and ntrServer:FindFirstChild("Services")
local garage = services and services:FindFirstChild("Garage")
local garageController = garage and garage:FindFirstChild("GarageActionController_Shadow_Disabled")
local inventoryRuntime = garage and garage:FindFirstChild("GarageModuleInventoryRuntime")
expect(garageController and garageController:IsA("LuaSourceContainer"), "Garage action controller is missing.")
expect(inventoryRuntime and inventoryRuntime:IsA("ModuleScript"), "Garage module inventory guard runtime is missing.")
expect(string.find(garageController.Source, "NTR_GARAGE_MODULE_INVENTORY_GUARD_V1", 1, true) ~= nil,
	"Inventory creation guard marker is missing. Refusing to reset data until duplicate creation is blocked.")
expect(string.find(garageController.Source, "NTR_GARAGE_MODULE_INVENTORY_SHAPE_ONLY_V1", 1, true) ~= nil,
	"Shape-only inventory marker is missing. Refusing to reset data.")

local ntr = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
local shared = ntr and ntr:FindFirstChild("Shared")
local configRoot = shared and shared:FindFirstChild("Config")
local persistenceConfig = configRoot and configRoot:FindFirstChild("Persistence_EditAttributes")
expect(persistenceConfig ~= nil, "Persistence_EditAttributes is missing.")

local dataStoreName = tostring(persistenceConfig:GetAttribute("DataStoreName") or "NTR_PlayerProfiles_v1")
local profileKey = "player_" .. tostring(TARGET_USER_ID)
expect(dataStoreName ~= "", "Configured main profile DataStore name is empty.")
expect(profileKey == "player_7915427645", "Generated profile key does not match the approved target.")

local store = DataStoreService:GetDataStore(dataStoreName)
local readOk, existingProfile = pcall(function()
	return store:GetAsync(profileKey)
end)
expect(readOk, "Could not read the existing profile. Check Studio API access; nothing was deleted. Error: " .. tostring(existingProfile))

if existingProfile == nil then
	print(PREFIX .. "PASS profile was already absent")
	print(PREFIX .. "store=" .. dataStoreName .. " key=" .. profileKey .. " userId=" .. tostring(TARGET_USER_ID))
	print(PREFIX .. "NEXT start a fresh Play session; the default profile will be created")
	return
end

print(PREFIX .. string.format(
	"BEFORE cash=%s vehicles=%d cockpits=%d modules=%d garageProperties=%d",
	tostring(existingProfile.Cash),
	countDictionary(existingProfile.Vehicles),
	countDictionary(existingProfile.OwnedCockpitInstances),
	countDictionary(existingProfile.OwnedModuleInstances),
	countDictionary(typeof(existingProfile.Garage) == "table" and existingProfile.Garage.OwnedGarageProperties or nil)
))

local removeOk, removedValue = pcall(function()
	return store:RemoveAsync(profileKey)
end)
expect(removeOk, "RemoveAsync failed; reset is not confirmed. Error: " .. tostring(removedValue))

local verifyOk, remainingValue = pcall(function()
	return store:GetAsync(profileKey)
end)
expect(verifyOk, "Profile removal returned, but read-back verification failed: " .. tostring(remainingValue))
expect(remainingValue == nil, "Profile key still exists after RemoveAsync. Do not start Play; reset is not confirmed.")

print(PREFIX .. "PASS main profile permanently removed and read-back returned nil")
print(PREFIX .. "PASS store=" .. dataStoreName .. " key=" .. profileKey .. " userId=" .. tostring(TARGET_USER_ID))
print(PREFIX .. "PASS intro progress, personal bests, and global leaderboards were not touched")
print(PREFIX .. "NEXT start a fresh Play session and verify the default empty garage before purchasing")
