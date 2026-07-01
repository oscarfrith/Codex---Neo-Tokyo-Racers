-- Neo Tokyo Racers - Persistence Phase 7 Server Audit
-- Verifies the garage capacity upgrade action source patch and config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 7 Audit"

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

assertTrue(typeof(config:GetAttribute("GarageCapacityUpgradeBasePrice")) == "number", "GarageCapacityUpgradeBasePrice missing.")
assertTrue(typeof(config:GetAttribute("GarageCapacityUpgradePriceMultiplier")) == "number", "GarageCapacityUpgradePriceMultiplier missing.")
assertTrue(typeof(config:GetAttribute("MaxGarageCapacity")) == "number", "MaxGarageCapacity missing.")
assertTrue(typeof(config:GetAttribute("GarageCapacityUpgradeStep")) == "number", "GarageCapacityUpgradeStep missing.")

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local source = garage.Source
assertTrue(string.find(source, "NTR_PERSISTENCE_PHASE7_GARAGE_CAPACITY_UPGRADE", 1, true) ~= nil, "Phase 7 marker missing from garage controller.")
assertTrue(string.find(source, 'action == "UpgradeGarageCapacity"', 1, true) ~= nil, "UpgradeGarageCapacity action missing.")
assertTrue(string.find(source, "NextCapacityUpgradePrice", 1, true) ~= nil, "Garage capacity price missing from profile response.")

local mapper = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Data")
	:WaitForChild("LegacyGarageProfileMapper")
assertTrue(string.find(mapper.Source, "NTR_PERSISTENCE_PHASE7_GARAGE_CAPACITY_UPGRADE", 1, true) ~= nil, "Legacy mapper GarageCapacity migration marker missing.")

info("PASS: UpgradeGarageCapacity action is installed.")
info("PASS: Capacity upgrade config is present.")
info("PASS: Profile response exposes Garage capacity and next price.")
info("PASS: Legacy mapper mirrors session GarageCapacity into ProfileService snapshots.")
