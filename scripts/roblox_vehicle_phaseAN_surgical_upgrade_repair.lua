-- Neo Tokyo Racers - Vehicle Phase AN surgical upgrade repair
-- Run in Edit mode.
--
-- Applies and verifies one small garage source edit at a time. Safe to rerun.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Common")
	:WaitForChild("Performance")
local helper = performance:WaitForChild("VehicleModuleUpgradeRuntime")
local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assert(helper:IsA("ModuleScript"), "VehicleModuleUpgradeRuntime must be a ModuleScript")
assert(garage:IsA("Script"), "GarageActionController_Shadow_Disabled must be a Script")

local function countPlain(source, needle)
	local count, position = 0, 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1
		position = found + #needle
	end
end

local function installHook(name, marker, oldText, newText)
	local current = garage.Source
	if string.find(current, marker, 1, true) then
		print("[NTR Vehicle Phase AN Surgical] " .. name .. ": already present")
		return
	end

	local matches = countPlain(current, oldText)
	if matches ~= 1 then
		error(name .. " expected exactly 1 anchor match, found " .. tostring(matches))
	end

	local updated = string.gsub(current, oldText, function()
		return newText
	end, 1)
	garage.Source = updated

	if not string.find(garage.Source, marker, 1, true) then
		error(name .. " source write was not retained")
	end
	print("[NTR Vehicle Phase AN Surgical] " .. name .. ": installed and verified")
end

installHook(
	"helper require",
	"-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES",
	[[	local V56_profiles = {}
]],
	[[	local V56_profiles = {}

	-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES
	local V77_ModuleUpgrades = require(V56_kit
		:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Common")
		:WaitForChild("Performance")
		:WaitForChild("VehicleModuleUpgradeRuntime"))
]]
)

installHook(
	"profile player binding",
	"profile._Player = player",
	[[			local profile = V56_getProfile(player)
			V76_grantDefaultModulesForCurrentCockpit(profile)
]],
	[[			local profile = V56_getProfile(player)
			profile._Player = player
			V76_grantDefaultModulesForCurrentCockpit(profile)
]]
)

installHook(
	"profile upgrade response",
	"ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels",
	[[			UpgradeLevels = profile.UpgradeLevels,
			TotalStats = V56_totalStats(profile),
]],
	[[			UpgradeLevels = profile.UpgradeLevels,
			ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels(profile._Player),
			TotalStats = V56_totalStats(profile),
]]
)

installHook(
	"catalogue upgrade definitions",
	"Upgrades = V77_ModuleUpgrades.CatalogForModuleType",
	[[			BoostRecharge = V56_number(item, "BoostRecharge", 0),
		}
]],
	[[			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType),
		}
]]
)

installHook(
	"spawned module effects",
	"V77_ModuleUpgrades.ApplyToClone",
	[[				moduleClone:SetAttribute("InstalledSlotId", slotId)
				moduleClone.Parent = installedRoot
]],
	[[				moduleClone:SetAttribute("InstalledSlotId", slotId)
				V77_ModuleUpgrades.ApplyToClone(player, moduleTemplate, moduleClone, V56_moduleTypeForModel)
				moduleClone.Parent = installedRoot
]]
)

installHook(
	"UpgradeModule server action",
	[[action == "UpgradeModule"]],
	[[			elseif action == "Upgrade" then
]],
	[[			elseif action == "UpgradeModule" then
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
)

garage:SetAttribute("VehicleUpgradePhase", "AN_Isolated")

print("[NTR Vehicle Phase AN Surgical] All Phase AN hooks installed and verified.")
print("[NTR Vehicle Phase AN Surgical] Run the Phase AN audit next.")
