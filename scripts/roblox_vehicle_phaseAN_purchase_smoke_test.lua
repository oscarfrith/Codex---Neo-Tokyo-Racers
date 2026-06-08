-- Neo Tokyo Racers - Vehicle Phase AN client purchase smoke test
-- Run from the CLIENT Command Bar during Play after opening the dealership once.
--
-- Default is read-only. Set PURCHASE_ONE_LEVEL = true only when ready to spend
-- session cash on the first available upgrade for the selected installed slot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PURCHASE_ONE_LEVEL = false
local SLOT_ID = "Engine1"

local invoke = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Remotes")
	:WaitForChild("Garage")
	:WaitForChild("GarageInvoke")

local initial = invoke:InvokeServer("GetInitial", {})
assert(initial.Success, initial.Message or "GetInitial failed")

local profile = initial.Profile
local moduleId = profile.InstalledModules and profile.InstalledModules[SLOT_ID]
assert(moduleId, "No installed module in slot " .. SLOT_ID)

local selectedModule
for _, category in ipairs(initial.Catalog.Categories or {}) do
	for _, modules in pairs(category.Modules or {}) do
		for _, module in ipairs(modules) do
			if module.ModuleId == moduleId then
				selectedModule = module
				break
			end
		end
	end
end
assert(selectedModule, "Installed module is missing from catalog: " .. tostring(moduleId))

local upgrade = selectedModule.Upgrades and selectedModule.Upgrades[1]
assert(upgrade, "Module has no Phase AN upgrades: " .. tostring(moduleId))

local levels = profile.ModuleUpgradeLevels and profile.ModuleUpgradeLevels[moduleId] or {}
local currentLevel = levels and levels[upgrade.UpgradeId] or 0
local nextPrice = math.floor((upgrade.BasePrice or 0) * ((upgrade.PriceMultiplier or 1) ^ currentLevel))

print("[NTR Vehicle Phase AN Smoke] Slot: " .. SLOT_ID)
print("[NTR Vehicle Phase AN Smoke] Module: " .. tostring(selectedModule.DisplayName) .. " (" .. tostring(moduleId) .. ")")
print("[NTR Vehicle Phase AN Smoke] Upgrade: " .. tostring(upgrade.DisplayName))
print("[NTR Vehicle Phase AN Smoke] Current level: " .. tostring(currentLevel) .. "/" .. tostring(upgrade.MaxLevel))
print("[NTR Vehicle Phase AN Smoke] Next price: $" .. tostring(nextPrice))
print("[NTR Vehicle Phase AN Smoke] Profile rating: " .. tostring(profile.Performance and profile.Performance.Overall and profile.Performance.Overall.Tier) .. " " .. tostring(profile.Performance and profile.Performance.Overall and profile.Performance.Overall.PerformanceIndex))

if PURCHASE_ONE_LEVEL then
	local result = invoke:InvokeServer("UpgradeModule", {
		SlotId = SLOT_ID,
		ModuleId = moduleId,
		UpgradeId = upgrade.UpgradeId,
	})
	print("[NTR Vehicle Phase AN Smoke] Purchase success: " .. tostring(result.Success))
	print("[NTR Vehicle Phase AN Smoke] Message: " .. tostring(result.Message))
	local updated = result.Profile
	local updatedLevels = updated and updated.ModuleUpgradeLevels and updated.ModuleUpgradeLevels[moduleId] or {}
	print("[NTR Vehicle Phase AN Smoke] Updated level: " .. tostring(updatedLevels and updatedLevels[upgrade.UpgradeId] or 0))
	print("[NTR Vehicle Phase AN Smoke] Updated rating: " .. tostring(updated and updated.Performance and updated.Performance.Overall and updated.Performance.Overall.Tier) .. " " .. tostring(updated and updated.Performance and updated.Performance.Overall and updated.Performance.Overall.PerformanceIndex))
else
	print("[NTR Vehicle Phase AN Smoke] Read-only mode. Set PURCHASE_ONE_LEVEL = true to test a purchase.")
end
