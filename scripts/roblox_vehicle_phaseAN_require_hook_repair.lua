-- Phase AN helper require hook. One garage Source write only.
local ServerScriptService = game:GetService("ServerScriptService")
local garage = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageActionController_Shadow_Disabled")
local marker = "-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES"
if string.find(garage.Source, marker, 1, true) then print("[NTR Phase AN] Require hook already present."); return end
local old = "\tlocal V56_profiles = {}\n"
local new = [[	local V56_profiles = {}

	-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES
	local V77_ModuleUpgrades = require(V56_kit
		:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Common")
		:WaitForChild("Performance")
		:WaitForChild("VehicleModuleUpgradeRuntime"))
]]
local a, b = string.find(garage.Source, old, 1, true)
assert(a and not string.find(garage.Source, old, b + 1, true), "Require anchor must appear exactly once")
garage.Source = string.sub(garage.Source, 1, a - 1) .. new .. string.sub(garage.Source, b + 1)
print("[NTR Phase AN] Require hook write submitted.")
