-- Phase AN profile/player binding hook. One garage Source write only.
local ServerScriptService = game:GetService("ServerScriptService")
local garage = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageActionController_Shadow_Disabled")
local marker = "profile._Player = player"
if string.find(garage.Source, marker, 1, true) then print("[NTR Phase AN] Profile binding already present."); return end
local old = [[			local profile = V56_getProfile(player)
			V76_grantDefaultModulesForCurrentCockpit(profile)
]]
local new = [[			local profile = V56_getProfile(player)
			profile._Player = player
			V76_grantDefaultModulesForCurrentCockpit(profile)
]]
local a, b = string.find(garage.Source, old, 1, true)
assert(a and not string.find(garage.Source, old, b + 1, true), "Profile binding anchor must appear exactly once")
garage.Source = string.sub(garage.Source, 1, a - 1) .. new .. string.sub(garage.Source, b + 1)
print("[NTR Phase AN] Profile binding hook write submitted.")
