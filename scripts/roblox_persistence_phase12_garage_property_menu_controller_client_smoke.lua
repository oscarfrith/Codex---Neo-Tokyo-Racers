-- Neo Tokyo Racers - Persistence Phase 12 client smoke test
-- Run from the CLIENT Command Bar during Play.
-- This verifies the extracted controller is cloned and the existing UI still appears.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
assert(player, "Run this from the CLIENT Command Bar in Play mode.")

local playerScripts = player:WaitForChild("PlayerScripts")
local clientRoot = playerScripts:WaitForChild("NeoTokyoRacersClient", 10)
assert(clientRoot, "NeoTokyoRacersClient did not clone into PlayerScripts.")

local moduleScript = clientRoot:WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GaragePropertyMenuController")
local ok, controller = pcall(require, moduleScript)
assert(ok, "GaragePropertyMenuController failed to require on client: " .. tostring(controller))
assert(type(controller.Render) == "function", "GaragePropertyMenuController.Render is missing on client.")
assert(type(controller.ListProperties) == "function", "GaragePropertyMenuController.ListProperties is missing on client.")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local properties = controller.ListProperties({ kit = kit })
assert(type(properties) == "table" and #properties >= 1, "GaragePropertyMenuController returned no properties on client.")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("HOVER_RACING_V2_GarageUI", 10)
assert(gui, "Garage UI did not load.")

local garagePanel = gui:FindFirstChild("GarageCapacityPinnedLeft", true)
local buyMore = garagePanel and garagePanel:FindFirstChild("GarageCapacityUpgradeButton", true)
local backdrop = gui:FindFirstChild("GaragePropertyModalBackdrop", true)
local shop = gui:FindFirstChild("GaragePropertyShopPopup", true)
local body = shop and shop:FindFirstChild("GaragePropertyShopBody", true)

assert(garagePanel, "Garage Spaces panel is missing.")
assert(buyMore and buyMore:IsA("TextButton"), "Buy More button is missing.")
assert(buyMore.Text == "BUY MORE" or buyMore.Text == "MAXED", "Garage button text should be BUY MORE or MAXED, got: " .. tostring(buyMore.Text))
assert(backdrop and backdrop:IsA("TextButton"), "Garage property modal backdrop is missing.")
assert(shop, "Garage property shop popup is missing.")
assert(body, "Garage property shop body is missing.")

print("[NTR Persistence Phase 12 Client Smoke] PASS: extracted GaragePropertyMenuController is available on the client.")
print("[NTR Persistence Phase 12 Client Smoke] PASS: Garage Spaces, Buy More, modal backdrop, and garage property popup still exist.")
print("[NTR Persistence Phase 12 Client Smoke] Manual check: click BUY MORE and confirm the garage-property cards still render above the dim backdrop.")
