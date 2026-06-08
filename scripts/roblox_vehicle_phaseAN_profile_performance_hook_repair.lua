-- Phase AN profile performance response hook
-- Performs exactly one garage Source write.

local ServerScriptService = game:GetService("ServerScriptService")

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local marker = "Performance = V77_ModuleUpgrades.CalculateProfile"
if string.find(garage.Source, marker, 1, true) then
	print("[NTR Vehicle Phase AN Repair] Profile performance hook already present.")
	return
end

local oldText = [[			ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels(profile._Player),
			TotalStats = V56_totalStats(profile),
]]
local newText = [[			ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels(profile._Player),
			Performance = V77_ModuleUpgrades.CalculateProfile(
				profile._Player,
				profile,
				V56_totalStats(profile),
				V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit),
				V56_findModule,
				V56_moduleTypeForModel
			),
			TotalStats = V56_totalStats(profile),
]]

local startIndex, endIndex = string.find(garage.Source, oldText, 1, true)
assert(startIndex and not string.find(garage.Source, oldText, endIndex + 1, true), "Profile performance anchor must appear exactly once")

garage.Source = string.sub(garage.Source, 1, startIndex - 1) .. newText .. string.sub(garage.Source, endIndex + 1)
print("[NTR Vehicle Phase AN Repair] Added complete performance result to profile response.")
