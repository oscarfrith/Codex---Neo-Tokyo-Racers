-- Neo Tokyo Racers - Phase AN spawned clone effect hook repair
-- Run in Edit mode after the catalogue hook repair.
-- Performs exactly one garage Source write.

local ServerScriptService = game:GetService("ServerScriptService")

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local marker = "V77_ModuleUpgrades.ApplyToClone"
if string.find(garage.Source, marker, 1, true) then
	print("[NTR Vehicle Phase AN Repair] Spawned clone effect hook already present.")
	return
end

local oldText = [[				moduleClone:SetAttribute("InstalledSlotId", slotId)
				moduleClone.Parent = installedRoot
]]
local newText = [[				moduleClone:SetAttribute("InstalledSlotId", slotId)
				V77_ModuleUpgrades.ApplyToClone(player, moduleTemplate, moduleClone, V56_moduleTypeForModel)
				moduleClone.Parent = installedRoot
]]

local startIndex, endIndex = string.find(garage.Source, oldText, 1, true)
assert(startIndex and not string.find(garage.Source, oldText, endIndex + 1, true), "Spawned clone anchor must appear exactly once")

garage.Source = string.sub(garage.Source, 1, startIndex - 1) .. newText .. string.sub(garage.Source, endIndex + 1)
print("[NTR Vehicle Phase AN Repair] Spawned clone effect hook Source write submitted. Rerun the Phase AN audit as a separate Command Bar action.")
