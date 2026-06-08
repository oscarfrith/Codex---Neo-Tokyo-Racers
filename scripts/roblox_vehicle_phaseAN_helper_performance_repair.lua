-- Phase AN helper performance calculation repair
-- Performs one ModuleScript Source write and does not patch the garage controller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local helper = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Common")
	:WaitForChild("Performance")
	:WaitForChild("VehicleModuleUpgradeRuntime")

if string.find(helper.Source, "function Runtime.CalculateProfile", 1, true) then
	print("[NTR Vehicle Phase AN Repair] Helper profile performance function already present.")
	return
end

local returnStart = string.find(helper.Source, "return Runtime", 1, true)
assert(returnStart, "VehicleModuleUpgradeRuntime final return was not found")

local functionSource = [==[
function Runtime.CalculateProfile(player, profile, legacyTotals, cockpit, findModule, moduleTypeForModel)
	local performanceRuntime = require(script.Parent:WaitForChild("VehiclePerformanceRuntime"))
	local installedRoot = Instance.new("Folder")
	for slotId, moduleId in pairs(profile.InstalledModules or {}) do
		local moduleTemplate = findModule(profile.CurrentCategory, moduleId)
		if moduleTemplate then
			local clone = moduleTemplate:Clone()
			clone:SetAttribute("InstalledSlotId", slotId)
			Runtime.ApplyToClone(player, moduleTemplate, clone, moduleTypeForModel)
			clone.Parent = installedRoot
		end
	end
	local result = performanceRuntime.CalculateBuild(legacyTotals, cockpit, installedRoot)
	installedRoot:Destroy()
	return result
end

]==]

helper.Source = string.sub(helper.Source, 1, returnStart - 1) .. functionSource .. string.sub(helper.Source, returnStart)
helper:SetAttribute("Phase", "AN")

print("[NTR Vehicle Phase AN Repair] Added complete profile performance calculation to helper.")
