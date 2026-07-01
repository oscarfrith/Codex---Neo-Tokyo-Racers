-- Neo Tokyo Racers - Persistence Phase 5 rollback/safety switch.
-- Disables real DataStore writes for ProfileService mirrored snapshots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PHASE = "Persistence Phase 5 Disable"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local config = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Config")
	:WaitForChild("Persistence_EditAttributes")

config:SetAttribute("DataStoreEnabled", false)
config:SetAttribute("ProfileServicePhase", "Phase5_DataStoreMirrorSaves_Disabled")
config:SetAttribute("Phase5Note", "DataStore writes disabled. ProfileService saves are dry-run/session-only again.")

info("Set Persistence_EditAttributes.DataStoreEnabled = false")
info("ProfileService SaveNow/autosave calls are dry-run/session-only again.")
