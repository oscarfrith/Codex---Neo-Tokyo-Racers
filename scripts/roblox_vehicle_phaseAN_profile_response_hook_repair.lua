-- Phase AN profile response hook. One garage Source write only.
local ServerScriptService = game:GetService("ServerScriptService")
local garage = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageActionController_Shadow_Disabled")
local marker = "ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels"
if string.find(garage.Source, marker, 1, true) then print("[NTR Phase AN] Profile response already present."); return end
local old = [[			UpgradeLevels = profile.UpgradeLevels,
			TotalStats = V56_totalStats(profile),
]]
local new = [[			UpgradeLevels = profile.UpgradeLevels,
			ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels(profile._Player),
			TotalStats = V56_totalStats(profile),
]]
local a, b = string.find(garage.Source, old, 1, true)
assert(a and not string.find(garage.Source, old, b + 1, true), "Profile response anchor must appear exactly once")
garage.Source = string.sub(garage.Source, 1, a - 1) .. new .. string.sub(garage.Source, b + 1)
print("[NTR Phase AN] Profile response hook write submitted.")
