-- Phase AN stale UpgradeModule action repair
-- Replaces any retained UpgradeModule branch, including the earlier V77_UpgradeDefinitions variant,
-- with the isolated VehicleModuleUpgradeRuntime purchase call.
-- Performs exactly one garage Source write.

local ServerScriptService = game:GetService("ServerScriptService")

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local source = garage.Source
local branchStart = string.find(source, '\t\t\telseif action == "UpgradeModule" then', 1, true)
assert(branchStart, "UpgradeModule branch was not found")
local nextBranch = string.find(source, '\t\t\telseif action == "Upgrade" then', branchStart + 1, true)
assert(nextBranch, "Legacy Upgrade branch after UpgradeModule was not found")

local replacement = [[			elseif action == "UpgradeModule" then
				ok, message = V77_ModuleUpgrades.Purchase(
					player,
					profile,
					tostring(args.SlotId or ""),
					tostring(args.ModuleId or ""),
					tostring(args.UpgradeId or ""),
					V56_findModule,
					V56_moduleTypeForModel
				)
				V56_setLeaderstats(player, profile)
]]

garage.Source = string.sub(source, 1, branchStart - 1) .. replacement .. string.sub(source, nextBranch)
garage:SetAttribute("VehicleUpgradePhase", "AN_Isolated")

print("[NTR Vehicle Phase AN Repair] Replaced stale UpgradeModule branch with isolated purchase runtime.")
