-- Neo Tokyo Racers - Persistence Phase 13 client smoke test
-- Run from the CLIENT Command Bar during Play.
-- This verifies BuyGarageProperty routing and the extracted garage menu controller.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PHASE = "Persistence Phase 13 Client Smoke"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(not RunService:IsServer(), "Run this smoke test from the CLIENT Command Bar during Play mode.")

local player = Players.LocalPlayer
assertTrue(player ~= nil, "LocalPlayer missing. Run during Play mode from the client.")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local invoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")
local catalog = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("GaragePropertyCatalog"))

local playerScripts = player:WaitForChild("PlayerScripts")
local clientRoot = playerScripts:WaitForChild("NeoTokyoRacersClient", 10)
assertTrue(clientRoot ~= nil, "NeoTokyoRacersClient did not clone into PlayerScripts.")
local controller = require(clientRoot:WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GaragePropertyMenuController"))
assertTrue(type(controller.Render) == "function", "GaragePropertyMenuController.Render is missing.")
assertTrue(type(controller.IsOwned) == "function", "GaragePropertyMenuController.IsOwned is missing.")

local initial = invoke:InvokeServer("GetInitial", {})
assertTrue(typeof(initial) == "table" and initial.Success == true, "GetInitial failed: " .. tostring(initial and initial.Message))
assertTrue(typeof(initial.Profile) == "table" and typeof(initial.Profile.Garage) == "table", "Initial profile missing Garage data.")
assertTrue(typeof(initial.Profile.Garage.OwnedGarageProperties) == "table", "Initial profile missing Garage.OwnedGarageProperties.")

local beforeProfile = initial.Profile
local beforeGarage = beforeProfile.Garage
local owned = beforeGarage.OwnedGarageProperties
local buyable = nil
for _, property in ipairs(catalog.List()) do
	if property.Available == true and owned[tostring(property.PropertyId)] == nil then
		buyable = property
		break
	end
end

if not buyable then
	info("PASS: all currently available garage properties are already owned.")
	return
end

local beforeCash = tonumber(beforeProfile.Cash) or 0
local price = tonumber(buyable.Price) or 0
local beforeCapacity = tonumber(beforeGarage.Capacity) or 0
local maxCapacity = tonumber(beforeGarage.MaxCapacity) or beforeCapacity

if beforeCapacity >= maxCapacity then
	info("PASS: garage capacity is already at the current maximum; no further purchase is expected in this session.")
	return
end

local result = invoke:InvokeServer("BuyGarageProperty", { PropertyId = buyable.PropertyId })
assertTrue(typeof(result) == "table", "BuyGarageProperty did not return a table.")

if beforeCash < price then
	assertTrue(result.Success == false, "BuyGarageProperty should fail when the player lacks cash.")
	assertTrue(tostring(result.Message or ""):find("Not enough cash", 1, true) ~= nil, "Expected not-enough-cash message, got: " .. tostring(result.Message))
	info("PASS: BuyGarageProperty action exists and correctly rejected insufficient cash.")
	return
end

assertTrue(result.Success == true, "BuyGarageProperty failed: " .. tostring(result.Message))
assertTrue(typeof(result.Profile) == "table" and typeof(result.Profile.Garage) == "table", "BuyGarageProperty response missing Garage profile.")
assertTrue(typeof(result.Profile.Garage.OwnedGarageProperties) == "table", "BuyGarageProperty response missing OwnedGarageProperties.")
assertTrue(result.Profile.Garage.OwnedGarageProperties[tostring(buyable.PropertyId)] ~= nil, "Purchased garage property was not recorded as owned.")
assertTrue((tonumber(result.Profile.Cash) or 0) == beforeCash - price, "Cash did not decrease by the property price.")
assertTrue((tonumber(result.Profile.Garage.Capacity) or 0) >= beforeCapacity, "Garage capacity should not decrease after property purchase.")

local mirrored = false
for _ = 1, 80 do
	if player:GetAttribute("NTR_PersistenceMirrorLastAction") == "BuyGarageProperty" then
		mirrored = true
		break
	end
	task.wait(0.1)
end
assertTrue(mirrored, "Persistence mirror did not record BuyGarageProperty.")

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI") or playerGui:WaitForChild("HOVER_RACING_V2_GarageUI", 2)
if gui then
	assertTrue(gui:FindFirstChild("GaragePropertyShopPopup", true) ~= nil, "Garage property shop popup is missing.")
	info("PASS: Garage UI is loaded and the garage property popup exists.")
else
	info("SKIP: Garage UI is not loaded yet. Reach the dealership desk/open the garage, then manually confirm Buy More opens the property gallery.")
end

info("PASS: BuyGarageProperty purchased " .. tostring(buyable.DisplayName or buyable.PropertyId) .. ".")
info("PASS: OwnedGarageProperties updated and persistence mirror recorded BuyGarageProperty.")
info("PASS: GaragePropertyMenuController is available on the client.")
