-- Neo Tokyo Racers - Persistence Phase 11 client smoke test
-- Run from the CLIENT Command Bar during Play.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
assert(player, "Run this from the CLIENT Command Bar in Play mode.")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("HOVER_RACING_V2_GarageUI", 10)
assert(gui, "Garage UI did not load.")

local garagePanel = gui:FindFirstChild("GarageCapacityPinnedLeft", true)
assert(garagePanel, "Garage Spaces panel is missing.")

print("[NTR Persistence Phase 11 Client Smoke] PASS: Garage Spaces panel exists for the cockpit-selection screen.")
print("[NTR Persistence Phase 11 Client Smoke] Manual check: go to Cockpit Paint, Build Modules, and Customise. Garage Spaces should hide outside the first cockpit-selection screen, then reappear when backing to cockpit selection.")
