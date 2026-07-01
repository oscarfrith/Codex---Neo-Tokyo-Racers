-- Neo Tokyo Racers - Persistence Phase 7
-- Adds a server-validated garage capacity upgrade action.
--
-- This uses guarded exact source replacement against:
-- - ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
-- - ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.LegacyGarageProfileMapper
--
-- Scope:
-- - Current V56 garage profile remains the live source of truth.
-- - Adds session GarageCapacity to the current profile response.
-- - Adds UpgradeGarageCapacity server action for later UI.
-- - Mirrors upgraded capacity into ProfileService snapshots.
-- - Does not change module ownership, cockpit instance ownership, driving, VFX, garage interiors, or UI layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 7"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function waitPath(root, ...)
	local item = root
	for _, name in ipairs({ ... }) do
		item = item:WaitForChild(name)
	end
	return item
end

local function replaceOnce(source, oldText, newText, label)
	local first = string.find(source, oldText, 1, true)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before making another garage capacity patch.")
	end
	local second = string.find(source, oldText, first + #oldText, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting.")
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local persistenceConfig = waitPath(ntr, "Shared", "Config", "Persistence_EditAttributes")
if persistenceConfig:GetAttribute("GarageCapacityUpgradeBasePrice") == nil then
	persistenceConfig:SetAttribute("GarageCapacityUpgradeBasePrice", 50000)
end
if persistenceConfig:GetAttribute("GarageCapacityUpgradePriceMultiplier") == nil then
	persistenceConfig:SetAttribute("GarageCapacityUpgradePriceMultiplier", 1.65)
end
if persistenceConfig:GetAttribute("MaxGarageCapacity") == nil then
	persistenceConfig:SetAttribute("MaxGarageCapacity", 10)
end
if persistenceConfig:GetAttribute("GarageCapacityUpgradeStep") == nil then
	persistenceConfig:SetAttribute("GarageCapacityUpgradeStep", 1)
end

local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")
if not garage:IsA("Script") then
	error("GarageActionController_Shadow_Disabled must be a Script.")
end

local source = garage.Source
if not string.find(source, "NTR_PERSISTENCE_PHASE6_GARAGE_CAPACITY_GATE", 1, true) then
	error("Run Persistence Phase 6 before Phase 7.")
end
if not string.find(source, "NTR_PERSISTENCE_PHASE7_GARAGE_CAPACITY_UPGRADE", 1, true) then
	local oldDefaultProfile = [[			UpgradeLevels = { Brakes = 0, Converter = 0, FuelSystem = 0 },
			ModuleUpgradeLevels = {},
]]
	local newDefaultProfile = [[			UpgradeLevels = { Brakes = 0, Converter = 0, FuelSystem = 0 },
			GarageCapacity = 2,
			ModuleUpgradeLevels = {},
]]

	local oldNormalize = [[		profile.UpgradeLevels = profile.UpgradeLevels or { Brakes = 0, Converter = 0, FuelSystem = 0 }
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
]]
	local newNormalize = [[		profile.UpgradeLevels = profile.UpgradeLevels or { Brakes = 0, Converter = 0, FuelSystem = 0 }
		profile.GarageCapacity = math.max(1, math.floor(tonumber(profile.GarageCapacity) or 2))
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
]]

	local oldBeforeCanBuy = [[	local function V81_canBuyCockpit(profile, cockpitId)
]]
	local newBeforeCanBuy = [[	-- NTR_PERSISTENCE_PHASE7_GARAGE_CAPACITY_UPGRADE
	local function V82_persistenceConfigAttribute(name, fallback)
		local shared = V56_kit:FindFirstChild("Shared")
		local configRoot = shared and shared:FindFirstChild("Config")
		local persistenceConfig = configRoot and configRoot:FindFirstChild("Persistence_EditAttributes")
		local value = persistenceConfig and persistenceConfig:GetAttribute(name)
		if value == nil then
			return fallback
		end
		return value
	end

	local function V82_profileGarageCapacity(profile)
		local capacity = tonumber(profile and profile.GarageCapacity) or V81_garageCapacity()
		return math.max(1, math.floor(capacity))
	end

	local function V82_maxGarageCapacity()
		return math.max(1, math.floor(tonumber(V82_persistenceConfigAttribute("MaxGarageCapacity", 10)) or 10))
	end

	local function V82_capacityUpgradeStep()
		return math.max(1, math.floor(tonumber(V82_persistenceConfigAttribute("GarageCapacityUpgradeStep", 1)) or 1))
	end

	local function V82_capacityUpgradePrice(profile)
		local capacity = V82_profileGarageCapacity(profile)
		local startCapacity = math.max(1, math.floor(tonumber(V82_persistenceConfigAttribute("StartingGarageCapacity", 2)) or 2))
		local basePrice = math.max(0, tonumber(V82_persistenceConfigAttribute("GarageCapacityUpgradeBasePrice", 50000)) or 50000)
		local multiplier = math.max(1, tonumber(V82_persistenceConfigAttribute("GarageCapacityUpgradePriceMultiplier", 1.65)) or 1.65)
		local level = math.max(0, capacity - startCapacity)
		return math.floor(basePrice * (multiplier ^ level) + 0.5)
	end

	local function V82_upgradeGarageCapacity(profile)
		if not profile then
			return false, "Garage profile missing."
		end
		profile.GarageCapacity = V82_profileGarageCapacity(profile)
		local maxCapacity = V82_maxGarageCapacity()
		if profile.GarageCapacity >= maxCapacity then
			return false, "Garage capacity is already maxed."
		end
		local price = V82_capacityUpgradePrice(profile)
		if (profile.Cash or 0) < price then
			return false, "Not enough cash."
		end
		profile.Cash -= price
		profile.GarageCapacity = math.min(maxCapacity, profile.GarageCapacity + V82_capacityUpgradeStep())
		return true, "Garage capacity upgraded."
	end

	local function V81_canBuyCockpit(profile, cockpitId)
]]

	local oldCanBuyCapacity = [[		local capacity = V81_garageCapacity()
		local ownedCount = V81_ownedCockpitCount(profile)
]]
	local newCanBuyCapacity = [[		local capacity = V82_profileGarageCapacity(profile)
		local ownedCount = V81_ownedCockpitCount(profile)
]]

	local oldProfileForClient = [[			NeonOwned = profile.NeonOwned,
			UpgradeLevels = profile.UpgradeLevels,
			ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels(profile._Player),
]]
	local newProfileForClient = [[			NeonOwned = profile.NeonOwned,
			UpgradeLevels = profile.UpgradeLevels,
			Garage = {
				Capacity = V82_profileGarageCapacity(profile),
				MaxCapacity = V82_maxGarageCapacity(),
				NextCapacityUpgradePrice = V82_capacityUpgradePrice(profile),
				OwnedVehicleCount = V81_ownedCockpitCount(profile),
			},
			ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels(profile._Player),
]]

	local oldActionAnchor = [[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
]]
	local newActionAnchor = [[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
]]

	local oldBeforeBuyCockpit = [[			elseif action == "BuyCockpit" then
				local cockpitId = tostring(args.CockpitId or "")
]]
	local newBeforeBuyCockpit = [[			elseif action == "UpgradeGarageCapacity" then
				ok, message = V82_upgradeGarageCapacity(profile)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyCockpit" then
				local cockpitId = tostring(args.CockpitId or "")
]]

	source = replaceOnce(source, oldDefaultProfile, newDefaultProfile, "Phase 7 default GarageCapacity")
	source = replaceOnce(source, oldNormalize, newNormalize, "Phase 7 normalize GarageCapacity")
	source = replaceOnce(source, oldBeforeCanBuy, newBeforeCanBuy, "Phase 7 capacity upgrade helpers")
	source = replaceOnce(source, oldCanBuyCapacity, newCanBuyCapacity, "Phase 7 can-buy capacity source")
	source = replaceOnce(source, oldProfileForClient, newProfileForClient, "Phase 7 profile response Garage data")
	source = replaceOnce(source, oldBeforeBuyCockpit, newBeforeBuyCockpit, "Phase 7 UpgradeGarageCapacity action")
	garage.Source = source
	info("Patched GarageActionController_Shadow_Disabled with UpgradeGarageCapacity.")
else
	info("GarageActionController_Shadow_Disabled already has Phase 7 upgrade action.")
end

local mapper = waitPath(ntr, "Shared", "Modules", "Data", "LegacyGarageProfileMapper")
if not mapper:IsA("ModuleScript") then
	error("LegacyGarageProfileMapper must be a ModuleScript.")
end
local mapperSource = mapper.Source
if not string.find(mapperSource, "NTR_PERSISTENCE_PHASE7_GARAGE_CAPACITY_UPGRADE", 1, true) then
	local oldMapperCapacity = [[	local preserveLegacyCapacity = options.PreserveLegacyCapacity ~= false
	if preserveLegacyCapacity then
		profile.Garage.Capacity = math.max(profile.Garage.Capacity or 2, #cockpitIds)
	else
		profile.Garage.Capacity = tonumber(options.Capacity) or profile.Garage.Capacity or 2
	end
]]
	local newMapperCapacity = [[	local preserveLegacyCapacity = options.PreserveLegacyCapacity ~= false
	if preserveLegacyCapacity then
		-- NTR_PERSISTENCE_PHASE7_GARAGE_CAPACITY_UPGRADE
		local legacyCapacity = tonumber(legacyProfile.GarageCapacity)
		profile.Garage.Capacity = math.max(profile.Garage.Capacity or 2, #cockpitIds, legacyCapacity or 0)
	else
		profile.Garage.Capacity = tonumber(options.Capacity) or profile.Garage.Capacity or 2
	end
]]
	mapperSource = replaceOnce(mapperSource, oldMapperCapacity, newMapperCapacity, "Phase 7 mapper legacy GarageCapacity")
	mapper.Source = mapperSource
	info("Patched LegacyGarageProfileMapper to mirror legacy GarageCapacity.")
else
	info("LegacyGarageProfileMapper already mirrors legacy GarageCapacity.")
end

info("Run scripts/roblox_persistence_phase7_garage_capacity_upgrade_audit.lua from the SERVER Command Bar in Play mode.")
info("Then run scripts/roblox_persistence_phase7_garage_capacity_upgrade_client_smoke.lua from the CLIENT Command Bar in Play mode.")
