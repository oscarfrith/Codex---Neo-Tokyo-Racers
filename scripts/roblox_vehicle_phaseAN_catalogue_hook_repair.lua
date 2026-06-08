-- Neo Tokyo Racers - Phase AN catalogue hook repair
-- Run in Edit mode. Performs exactly one garage Source write.

local ServerScriptService = game:GetService("ServerScriptService")

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local marker = "Upgrades = V77_ModuleUpgrades.CatalogForModuleType"
if string.find(garage.Source, marker, 1, true) then
	print("[NTR Vehicle Phase AN Repair] Catalogue hook already present.")
	return
end

local oldText = [[			BoostRecharge = V56_number(item, "BoostRecharge", 0),
		}
]]
local newText = [[			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType),
		}
]]

local startIndex, endIndex = string.find(garage.Source, oldText, 1, true)
assert(startIndex and not string.find(garage.Source, oldText, endIndex + 1, true), "Catalogue anchor must appear exactly once")

garage.Source = string.sub(garage.Source, 1, startIndex - 1) .. newText .. string.sub(garage.Source, endIndex + 1)
print("[NTR Vehicle Phase AN Repair] Catalogue hook Source write submitted. Run the next repair as a separate Command Bar action.")
