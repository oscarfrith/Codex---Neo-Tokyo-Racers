-- Neo Tokyo Racers - Vehicle Phase AM physics activation switch
-- Run only after the Phase AM runtime audit reports zero warnings.
-- Rerun with ENABLE = false for immediate compatibility rollback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ENABLE = true

local config = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Config")
	:WaitForChild("VehiclePerformance_EditAttributes")
	:WaitForChild("RuntimeIntegration")

config:SetAttribute("PhysicsEnabled", ENABLE)
print("[NTR Vehicle Phase AM] Detailed runtime physics enabled: " .. tostring(ENABLE))
print("[NTR Vehicle Phase AM] Spawn a fresh vehicle before testing so all AM runtime values are present.")
