-- Neo Tokyo Racers - Persistence Phase 5 Load Audit
-- Optional server-side check after a fresh Play/rejoin that ProfileService loaded saved mirrored data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 5 Load Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(RunService:IsServer(), "Run this audit from the SERVER Command Bar during Play mode after a fresh Play/rejoin.")

local config = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Config")
	:WaitForChild("Persistence_EditAttributes")

assertTrue(config:GetAttribute("DataStoreEnabled") == true, "DataStoreEnabled is not true. Run the Phase 5 enable script before the fresh Play session.")

local player = Players:GetPlayers()[1]
assertTrue(player ~= nil, "Run this audit during Play mode with at least one player.")

local bindings = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Player")
	:WaitForChild("ProfileServiceBindings")

local isLoaded = bindings:WaitForChild("IsLoaded")
local getSummary = bindings:WaitForChild("GetSummary")

local loaded = false
for _ = 1, 80 do
	if isLoaded:Invoke(player) == true then
		loaded = true
		break
	end
	task.wait(0.1)
end
assertTrue(loaded, "ProfileService did not load the player profile.")

local summary = getSummary:Invoke(player)
assertTrue(typeof(summary) == "table", "GetSummary did not return a table.")
assertTrue(summary.DataStoreEnabled == true, "ProfileService summary does not see DataStoreEnabled=true.")
assertTrue((summary.VehicleCount or 0) >= 1, "No saved vehicle instances loaded. Confirm the Phase 5 save audit passed in a previous session.")
assertTrue((summary.ModuleInstanceCount or 0) >= 1, "No saved module instances loaded. Confirm the Phase 5 save audit passed in a previous session.")

info("PASS: Fresh session loaded saved mirrored ProfileService data.")
info("PASS: Loaded vehicle count = " .. tostring(summary.VehicleCount))
info("PASS: Loaded module instance count = " .. tostring(summary.ModuleInstanceCount))
info("Reminder: the active garage UI still uses the V56 session profile until a later source-of-truth bridge phase.")
