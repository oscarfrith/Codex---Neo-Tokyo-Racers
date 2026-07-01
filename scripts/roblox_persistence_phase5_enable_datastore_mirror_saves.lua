-- Neo Tokyo Racers - Persistence Phase 5
-- Enables real DataStore writes for ProfileService mirrored snapshots.
--
-- Prerequisites:
-- - Persistence Phases 1-4 installed and passing.
-- - Studio Game Settings > Security > Enable Studio Access to API Services, for Studio tests.
--
-- This does not make ProfileService the live garage source of truth yet.
-- It only allows ProfileService_Active SaveNow/autosave to write the mirrored profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PHASE = "Persistence Phase 5 Enable"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local config = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Config")
	:WaitForChild("Persistence_EditAttributes")

config:SetAttribute("DataStoreEnabled", true)
config:SetAttribute("DataStoreName", config:GetAttribute("DataStoreName") or "NTR_PlayerProfiles_v1")
config:SetAttribute("ProfileServicePhase", "Phase5_DataStoreMirrorSaves")
config:SetAttribute("Phase5Note", "DataStore writes enabled for mirrored ProfileService snapshots. Active garage actions still use the V56 session profile.")

info("Set Persistence_EditAttributes.DataStoreEnabled = true")
info("DataStoreName = " .. tostring(config:GetAttribute("DataStoreName")))
info("Run scripts/roblox_persistence_phase4_garage_session_mirror_client_smoke.lua from the CLIENT Command Bar to populate the mirror, then run scripts/roblox_persistence_phase5_datastore_save_audit.lua from the SERVER Command Bar.")
