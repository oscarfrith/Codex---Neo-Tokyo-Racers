-- Neo Tokyo Racers - Persistence Phase 5 Save Audit
-- Server-side test that the mirrored ProfileService profile can be saved to DataStore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 5 Save Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(RunService:IsServer(), "Run this audit from the SERVER Command Bar during Play mode.")

local config = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Config")
	:WaitForChild("Persistence_EditAttributes")

assertTrue(config:GetAttribute("DataStoreEnabled") == true, "DataStoreEnabled is not true. Run scripts/roblox_persistence_phase5_enable_datastore_mirror_saves.lua first.")

local player = Players:GetPlayers()[1]
assertTrue(player ~= nil, "Run this audit during Play mode with at least one player.")

local playerServices = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Player")

local bindings = playerServices:WaitForChild("ProfileServiceBindings")
local getSummary = bindings:WaitForChild("GetSummary")
local markDirty = bindings:WaitForChild("MarkDirty")
local saveNow = bindings:WaitForChild("SaveNow")
local importProfileSnapshot = bindings:FindFirstChild("ImportProfileSnapshot")
assertTrue(importProfileSnapshot and importProfileSnapshot:IsA("BindableFunction"), "ImportProfileSnapshot binding missing. Run scripts/roblox_persistence_phase5_import_snapshot_binding_repair.lua, then rerun the Phase 4 client smoke.")

local summary = getSummary:Invoke(player)
assertTrue(typeof(summary) == "table", "GetSummary did not return a table.")
assertTrue(summary.DataStoreEnabled == true, "ProfileService summary does not see DataStoreEnabled=true.")
assertTrue((summary.VehicleCount or 0) >= 1, "Mirrored profile has no vehicles. Run scripts/roblox_persistence_phase4_garage_session_mirror_client_smoke.lua from the CLIENT Command Bar first.")
assertTrue((summary.ModuleInstanceCount or 0) >= 1, "Mirrored profile has no module instances. Run the Phase 4 client smoke first.")

local dirtyOk, dirtyMessage = markDirty:Invoke(player, "Phase5DataStoreSaveAudit")
assertTrue(dirtyOk == true, "MarkDirty failed: " .. tostring(dirtyMessage))

local saveOk, saveMessage = saveNow:Invoke(player)
assertTrue(saveOk == true, "SaveNow failed. If this mentions API/DataStore access, enable Studio API services or test in a published experience. Message: " .. tostring(saveMessage))

local savedSummary = getSummary:Invoke(player)
assertTrue(savedSummary.Dirty == false, "Profile should not remain dirty after successful SaveNow.")
assertTrue(savedSummary.DataStoreEnabled == true, "DataStoreEnabled should still be true after save.")
assertTrue((savedSummary.VehicleCount or 0) >= 1, "Saved summary lost vehicle instances.")
assertTrue((savedSummary.ModuleInstanceCount or 0) >= 1, "Saved summary lost module instances.")

info("PASS: ProfileService sees DataStoreEnabled=true.")
info("PASS: Mirrored profile contains " .. tostring(savedSummary.VehicleCount) .. " vehicle instance(s) and " .. tostring(savedSummary.ModuleInstanceCount) .. " module instance(s).")
info("PASS: SaveNow completed successfully. Message: " .. tostring(saveMessage))
info("Next optional check: stop Play, start a fresh Play session, then run scripts/roblox_persistence_phase5_datastore_load_audit.lua from the SERVER Command Bar.")
