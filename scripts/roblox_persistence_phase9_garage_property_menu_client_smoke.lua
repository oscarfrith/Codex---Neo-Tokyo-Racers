-- Neo Tokyo Racers - Persistence Phase 9 client smoke test
-- Run from the CLIENT Command Bar during Play.
-- This only verifies UI/source shape; it does not buy a garage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
assert(player, "Run this from the CLIENT Command Bar in Play mode.")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("HOVER_RACING_V2_GarageUI", 10)
assert(gui, "Garage UI did not load.")

local panel = gui:FindFirstChild("GarageCapacityPinnedLeft", true)
assert(panel, "Garage capacity panel was not created.")

local upgradeButton = panel:FindFirstChild("GarageCapacityUpgradeButton", true)
assert(upgradeButton and upgradeButton:IsA("TextButton"), "Buy More button is missing.")
assert(upgradeButton.Text == "BUY MORE" or upgradeButton.Text == "MAXED", "Garage button text should be BUY MORE or MAXED, got: " .. tostring(upgradeButton.Text))

local priceLabel = panel:FindFirstChild("GarageCapacityPrice", true)
assert(not priceLabel or priceLabel.Visible == false or priceLabel.Text == "", "Next price text should be hidden from the compact panel.")

local shop = gui:FindFirstChild("GaragePropertyShopPopup", true)
assert(shop, "Garage property shop popup was not created.")
local body = shop:FindFirstChild("GaragePropertyShopBody", true)
assert(body, "Garage property shop body is missing.")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local catalog = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("GaragePropertyCatalog"))
assert(type(catalog.List) == "function", "GaragePropertyCatalog.List is missing on client.")
assert(#catalog.List() >= 1, "GaragePropertyCatalog returned no garage properties.")

print("[NTR Persistence Phase 9 Client Smoke] PASS: compact Garage Spaces panel uses BUY MORE and hides the old next-price text.")
print("[NTR Persistence Phase 9 Client Smoke] PASS: garage property shop popup and catalogue are present.")
print("[NTR Persistence Phase 9 Client Smoke] Manual check: click BUY MORE, confirm the garage-card menu opens, then buy Kanda Lift Bay if you want to test the temporary Phase 7 backend.")
