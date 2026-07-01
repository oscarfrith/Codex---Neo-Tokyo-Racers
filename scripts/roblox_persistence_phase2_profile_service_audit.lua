-- Neo Tokyo Racers - Persistence Phase 2 Audit
-- Read-only Play-mode verification for ProfileService_Active.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 2 Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(RunService:IsServer(), "Run this audit from the SERVER Command Bar during Play mode. The client Command Bar cannot read ServerScriptService or server BindableFunctions.")

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = ntr:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Persistence_EditAttributes")
local schema = require(ntr:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("PlayerProfileSchema"))

local playerServices = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Player")

local service = playerServices:WaitForChild("ProfileService_Active")
assertTrue(service:IsA("Script"), "ProfileService_Active must be a Script.")
assertTrue(service.Disabled == false, "ProfileService_Active should be enabled.")

local bindings = playerServices:WaitForChild("ProfileServiceBindings")
local getProfile = bindings:WaitForChild("GetProfile")
local getSummary = bindings:WaitForChild("GetSummary")
local markDirty = bindings:WaitForChild("MarkDirty")
local saveNow = bindings:WaitForChild("SaveNow")
local isLoaded = bindings:WaitForChild("IsLoaded")

assertTrue(getProfile:IsA("BindableFunction"), "GetProfile binding missing.")
assertTrue(getSummary:IsA("BindableFunction"), "GetSummary binding missing.")
assertTrue(markDirty:IsA("BindableFunction"), "MarkDirty binding missing.")
assertTrue(saveNow:IsA("BindableFunction"), "SaveNow binding missing.")
assertTrue(isLoaded:IsA("BindableFunction"), "IsLoaded binding missing.")

local player = Players:GetPlayers()[1]
assertTrue(player ~= nil, "Run this audit during Play mode with at least one player.")

local loaded = false
for _ = 1, 80 do
	local ok, result = pcall(function()
		return isLoaded:Invoke(player)
	end)
	if ok and result == true then
		loaded = true
		break
	end
	task.wait(0.1)
end
assertTrue(loaded, "ProfileService did not report the player as loaded.")

local profile = getProfile:Invoke(player)
assertTrue(typeof(profile) == "table", "GetProfile should return a profile table.")
assertTrue(profile.SchemaVersion == schema.SchemaVersion, "Profile schema version mismatch.")
assertTrue(profile.Garage and profile.Garage.Capacity == 2, "Profile should have the default two-space garage.")

local summary = getSummary:Invoke(player)
assertTrue(typeof(summary) == "table", "GetSummary should return a summary table.")
assertTrue(summary.Loaded == true, "Summary should report Loaded=true.")
assertTrue(summary.GarageCapacity == 2, "Summary should report GarageCapacity=2.")
assertTrue(summary.VehicleCount == 0, "Phase 2 default profile should not create vehicles yet.")
assertTrue(summary.DataStoreEnabled == (config:GetAttribute("DataStoreEnabled") == true), "Summary DataStoreEnabled mismatch.")

local dirtyOk, dirtyMessage = markDirty:Invoke(player, "Phase2Audit")
assertTrue(dirtyOk == true, "MarkDirty failed: " .. tostring(dirtyMessage))

local dirtySummary = getSummary:Invoke(player)
assertTrue(dirtySummary.Dirty == true, "Summary should report Dirty=true after MarkDirty.")

local saveOk, saveMessage = saveNow:Invoke(player)
assertTrue(saveOk == true, "SaveNow failed: " .. tostring(saveMessage))

local savedSummary = getSummary:Invoke(player)
assertTrue(savedSummary.Dirty == false, "Summary should report Dirty=false after SaveNow.")

local runtimeMarker = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("State")
	:WaitForChild("RuntimeProfiles")
	:FindFirstChild(tostring(player.UserId))
assertTrue(runtimeMarker ~= nil, "Runtime profile marker missing.")
assertTrue(runtimeMarker:GetAttribute("Loaded") == true, "Runtime marker should report Loaded=true.")
assertTrue(runtimeMarker:GetAttribute("GarageCapacity") == 2, "Runtime marker should report GarageCapacity=2.")

info("PASS: ProfileService_Active is enabled and loaded the local player.")
info("PASS: BindableFunctions are present for future garage bridge phases.")
info("PASS: Default schema profile has two garage spaces and zero vehicles.")
info("PASS: MarkDirty and SaveNow completed. Save message: " .. tostring(saveMessage))
info("DataStoreEnabled=" .. tostring(config:GetAttribute("DataStoreEnabled")) .. ". If false, SaveNow is dry-run/session-only.")
