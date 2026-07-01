-- Neo Tokyo Racers - Persistence Phase 6 Audit
-- Verifies the garage capacity gate source patch and config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 6 Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(RunService:IsServer(), "Run this audit from the SERVER Command Bar during Play mode.")

local config = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Config")
	:WaitForChild("Persistence_EditAttributes")

local capacity = config:GetAttribute("StartingGarageCapacity")
assertTrue(typeof(capacity) == "number" and capacity >= 1, "StartingGarageCapacity should be a positive number.")

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assertTrue(garage:IsA("Script") and garage.Disabled == false, "GarageActionController_Shadow_Disabled should be enabled.")
local source = garage.Source
assertTrue(string.find(source, "NTR_PERSISTENCE_PHASE6_GARAGE_CAPACITY_GATE", 1, true) ~= nil, "Phase 6 capacity gate marker missing.")
assertTrue(string.find(source, "V81_canBuyCockpit(profile, cockpitId)", 1, true) ~= nil, "BuyCockpit capacity check missing.")
assertTrue(string.find(source, "Garage full. Upgrade your garage to store more vehicles.", 1, true) ~= nil, "Capacity-block message missing.")

info("PASS: Garage capacity gate is installed in the active garage controller.")
info("PASS: StartingGarageCapacity = " .. tostring(capacity))
info("Manual verification: with two owned cockpits, buying a third cockpit should show 'Garage full. Upgrade your garage to store more vehicles.'")
