-- Phase AN UpgradeModule action hook. One garage Source write only.
local ServerScriptService = game:GetService("ServerScriptService")
local garage = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageActionController_Shadow_Disabled")
local marker = 'action == "UpgradeModule"'
if string.find(garage.Source, marker, 1, true) then print("[NTR Phase AN] Purchase action already present."); return end
local old = [[			elseif action == "Upgrade" then
]]
local new = [[			elseif action == "UpgradeModule" then
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
			elseif action == "Upgrade" then
]]
local a, b = string.find(garage.Source, old, 1, true)
assert(a and not string.find(garage.Source, old, b + 1, true), "Purchase action anchor must appear exactly once")
garage.Source = string.sub(garage.Source, 1, a - 1) .. new .. string.sub(garage.Source, b + 1)
garage:SetAttribute("VehicleUpgradePhase", "AN_Isolated")
print("[NTR Phase AN] Purchase action hook write submitted.")
