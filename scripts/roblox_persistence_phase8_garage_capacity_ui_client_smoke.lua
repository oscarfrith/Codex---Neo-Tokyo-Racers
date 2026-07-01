-- Neo Tokyo Racers - Persistence Phase 8 client smoke test
-- Run from the CLIENT Command Bar during Play.
-- This does not click the upgrade button, so it will not spend cash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
assert(player, "Run this from the CLIENT Command Bar in Play mode.")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("HOVER_RACING_V2_GarageUI", 10)
assert(gui, "Garage UI did not load.")

local panel = gui:FindFirstChild("GarageCapacityPinnedLeft", true)
assert(panel, "Garage capacity panel was not created.")

local countLabel = panel:FindFirstChild("GarageCapacityCount", true)
local priceLabel = panel:FindFirstChild("GarageCapacityPrice", true)
local upgradeButton = panel:FindFirstChild("GarageCapacityUpgradeButton", true)

assert(countLabel and countLabel:IsA("TextLabel"), "Garage capacity count label is missing.")
assert(priceLabel and priceLabel:IsA("TextLabel"), "Garage capacity price label is missing.")
assert(upgradeButton and upgradeButton:IsA("TextButton"), "Garage capacity upgrade button is missing.")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local invoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")
local result = invoke:InvokeServer("GetInitial", {})

assert(type(result) == "table" and result.Success == true, "GetInitial failed before UI smoke verification.")
assert(type(result.Profile) == "table", "GetInitial did not return a profile.")
assert(type(result.Profile.Garage) == "table", "Profile.Garage is missing. Run Phase 7 before Phase 8.")
assert(tonumber(result.Profile.Garage.Capacity), "Profile.Garage.Capacity is missing.")
assert(tonumber(result.Profile.Garage.MaxCapacity), "Profile.Garage.MaxCapacity is missing.")

print("[NTR Persistence Phase 8 Client Smoke] PASS: garage capacity panel exists.")
print("[NTR Persistence Phase 8 Client Smoke] PASS: server profile exposes garage capacity " .. tostring(result.Profile.Garage.OwnedVehicleCount) .. "/" .. tostring(result.Profile.Garage.Capacity) .. ".")
print("[NTR Persistence Phase 8 Client Smoke] Manual check: click the Upgrade button once, confirm cash drops and spaces increase, then confirm buying beyond the old 2-space limit is allowed only after upgrading.")
