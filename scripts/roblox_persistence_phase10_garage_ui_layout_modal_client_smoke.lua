-- Neo Tokyo Racers - Persistence Phase 10 client smoke test
-- Run from the CLIENT Command Bar during Play.
-- This does not buy a garage.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
assert(player, "Run this from the CLIENT Command Bar in Play mode.")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("HOVER_RACING_V2_GarageUI", 10)
assert(gui, "Garage UI did not load.")

local categoryPanel = gui:FindFirstChild("Categories", true)
local garagePanel = gui:FindFirstChild("GarageCapacityPinnedLeft", true)
local cashPanel = gui:FindFirstChild("CashPinnedBottomLeft", true)
local backdrop = gui:FindFirstChild("GaragePropertyModalBackdrop", true)
local shop = gui:FindFirstChild("GaragePropertyShopPopup", true)
local buyMore = garagePanel and garagePanel:FindFirstChild("GarageCapacityUpgradeButton", true)

assert(categoryPanel, "Categories panel is missing.")
assert(garagePanel, "Garage Spaces panel is missing.")
assert(cashPanel, "Available Cash panel is missing.")
assert(backdrop and backdrop:IsA("TextButton"), "Garage property modal backdrop is missing.")
assert(shop, "Garage property shop popup is missing.")
assert(buyMore and buyMore:IsA("TextButton"), "Buy More button is missing.")

local categoryBottom = categoryPanel.AbsolutePosition.Y + categoryPanel.AbsoluteSize.Y
local garageTop = garagePanel.AbsolutePosition.Y
local garageBottom = garagePanel.AbsolutePosition.Y + garagePanel.AbsoluteSize.Y
local cashTop = cashPanel.AbsolutePosition.Y

assert(categoryBottom <= garageTop - 2, "Categories panel overlaps Garage Spaces panel.")
assert(garageBottom <= cashTop - 2, "Garage Spaces panel overlaps Available Cash panel.")
assert(backdrop.BackgroundTransparency == 0.3, "Backdrop should be 30% transparent black.")

print("[NTR Persistence Phase 10 Client Smoke] PASS: left panels stack as Categories, Garage Spaces, Available Cash without overlap.")
print("[NTR Persistence Phase 10 Client Smoke] Manual check: click BUY MORE and confirm the black dim backdrop appears behind the garage menu, then close it with X or by clicking the backdrop.")
