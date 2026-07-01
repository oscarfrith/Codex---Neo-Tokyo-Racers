-- Neo Tokyo Racers - Persistence Phase 7 Client Smoke Test
-- Invokes UpgradeGarageCapacity once and verifies the profile response.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PHASE = "Persistence Phase 7 Client Smoke"

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

local invoke = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Remotes")
	:WaitForChild("Garage")
	:WaitForChild("GarageInvoke")

local initial = invoke:InvokeServer("GetInitial", {})
assertTrue(typeof(initial) == "table" and initial.Success == true, "GetInitial failed: " .. tostring(initial and initial.Message))
assertTrue(typeof(initial.Profile) == "table" and typeof(initial.Profile.Garage) == "table", "Initial profile missing Garage data.")

local beforeCapacity = initial.Profile.Garage.Capacity
local beforeCash = initial.Profile.Cash
local price = initial.Profile.Garage.NextCapacityUpgradePrice
local maxCapacity = initial.Profile.Garage.MaxCapacity

assertTrue(typeof(beforeCapacity) == "number", "Garage capacity missing.")
assertTrue(typeof(price) == "number", "Next capacity upgrade price missing.")
assertTrue(typeof(maxCapacity) == "number", "Max capacity missing.")

if beforeCapacity >= maxCapacity then
	info("Garage capacity already maxed; smoke test cannot purchase another capacity upgrade in this session.")
	return
end

assertTrue(beforeCash >= price, "Not enough test cash for capacity upgrade. Cash=" .. tostring(beforeCash) .. " price=" .. tostring(price))

local result = invoke:InvokeServer("UpgradeGarageCapacity", {})
assertTrue(typeof(result) == "table" and result.Success == true, "UpgradeGarageCapacity failed: " .. tostring(result and result.Message))
assertTrue(typeof(result.Profile) == "table" and typeof(result.Profile.Garage) == "table", "Upgrade response missing Garage data.")
assertTrue(result.Profile.Garage.Capacity == beforeCapacity + 1, "Capacity should increase by 1. Before=" .. tostring(beforeCapacity) .. " after=" .. tostring(result.Profile.Garage.Capacity))
assertTrue(result.Profile.Cash == beforeCash - price, "Cash should decrease by the upgrade price.")

local mirrored = false
for _ = 1, 80 do
	if player:GetAttribute("NTR_PersistenceMirrorLastAction") == "UpgradeGarageCapacity" then
		mirrored = true
		break
	end
	task.wait(0.1)
end
assertTrue(mirrored, "Persistence mirror did not record UpgradeGarageCapacity.")

info("PASS: UpgradeGarageCapacity succeeded.")
info("PASS: Capacity " .. tostring(beforeCapacity) .. " -> " .. tostring(result.Profile.Garage.Capacity))
info("PASS: Cash " .. tostring(beforeCash) .. " -> " .. tostring(result.Profile.Cash))
info("PASS: Persistence mirror recorded UpgradeGarageCapacity.")
