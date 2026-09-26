-- Canonical feature implementation; startup is owned by the composition root.
-- GarageServer vehicle total stats and the client profile projection. Extracted verbatim from the GarageServer controller closure
-- (architecture P5); dependencies arrive through ctx and the same locals are returned in order.
return function(ctx)
	local capacityUpgradePrice = ctx.capacityUpgradePrice
	local findCockpit = ctx.findCockpit
	local findModule = ctx.findModule
	local garageServer_categoryFolder = ctx.garageServer_categoryFolder
	local garageServer_number = ctx.garageServer_number
	local garageServer_string = ctx.garageServer_string
	local maxGarageCapacity = ctx.maxGarageCapacity
	local moduleTypeForModel = ctx.moduleTypeForModel
	local moduleUpgrades = ctx.moduleUpgrades
	local nextGaragePropertyPrice = ctx.nextGaragePropertyPrice
	local normalizeProfile = ctx.normalizeProfile
	local ownedCockpitCount = ctx.ownedCockpitCount
	local ownedGarageProperties = ctx.ownedGarageProperties
	local profileGarageCapacity = ctx.profileGarageCapacity
	local vehicleCosmetics = ctx.vehicleCosmetics
	local vehicleSummaries = ctx.vehicleSummaries
	local function totalStats(profile)
		normalizeProfile(profile)
		local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = garageServer_number(cockpit, "TopSpeed", garageServer_number(cockpit, "MaxSpeed", 126)),
			Acceleration = garageServer_number(cockpit, "Acceleration", 42),
			Handling = garageServer_number(cockpit, "Handling", 48),
			Drift = garageServer_number(cockpit, "Drift", 46),
			Braking = garageServer_number(cockpit, "Braking", 44),
			Weight = garageServer_number(cockpit, "Weight", 118),
			Boost = garageServer_number(cockpit, "Boost", 0),
			BoostDuration = garageServer_number(cockpit, "BoostDuration", 2),
			BoostRecharge = garageServer_number(cockpit, "BoostRecharge", 9),
			BoostRechargeDelay = garageServer_number(cockpit, "BoostRechargeDelay", 0),
		}
		local statNames = {
			"TopSpeed",
			"Acceleration",
			"Handling",
			"Drift",
			"Braking",
			"Weight",
			"Boost",
			"BoostDuration",
			"BoostRecharge",
			"BoostRechargeDelay",
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			local module = findModule(profile.CurrentCategory, moduleId)
			if module then
				for _, stat in ipairs(statNames) do
					totals[stat] = (totals[stat] or 0) + garageServer_number(module, stat, 0)
				end
			end
		end
		local category = garageServer_categoryFolder(profile.CurrentCategory)
		local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
		if upgradeRoot then
			for upgradeId, level in pairs(profile.UpgradeLevels or {}) do
				local upgrade = upgradeRoot:FindFirstChild("UPGRADE_" .. tostring(upgradeId))
				if upgrade then
					local statName = garageServer_string(upgrade, "StatName", garageServer_string(upgrade, "Stat", nil))
					local amount = garageServer_number(upgrade, "AmountPerLevel", garageServer_number(upgrade, "Amount", 0))
					if statName then
						totals[statName] = (totals[statName] or 0) + amount * (tonumber(level) or 0)
					end
				end
			end
		end
		return totals
	end

	local function profileForClient(profile)
		normalizeProfile(profile)
		vehicleCosmetics.Ensure(profile)
		return {
			Cash = profile.Cash,
			CurrentCategory = profile.CurrentCategory,
			CurrentCockpit = profile.CurrentCockpit,
			CurrentVehicleId = profile.CurrentVehicleId,
			Vehicles = profile.Vehicles,
			OwnedCockpitInstances = profile.OwnedCockpitInstances,
			OwnedModuleInstances = profile.OwnedModuleInstances,
			VehicleSummaries = vehicleSummaries(profile),
			OwnedCockpits = profile.OwnedCockpits,
			CockpitColors = profile.CockpitColors,
			ThrustColor = profile.ThrustColor,
			OwnedModules = profile.OwnedModules,
			InstalledModules = profile.InstalledModules,
			ModuleColors = profile.ModuleColors,
			NeonOwned = profile.NeonOwned,
			UpgradeLevels = profile.UpgradeLevels,
			Garage = {
				Capacity = profileGarageCapacity(profile),
				MaxCapacity = maxGarageCapacity(),
				NextCapacityUpgradePrice = nextGaragePropertyPrice(profile) or capacityUpgradePrice(profile),
				NextGaragePropertyPrice = nextGaragePropertyPrice(profile),
				OwnedVehicleCount = ownedCockpitCount(profile),
				OwnedGarageProperties = ownedGarageProperties(profile),
			},
			ModuleUpgradeLevels = moduleUpgrades.GetLevels(profile._Player),
			Performance = moduleUpgrades.CalculateProfile(
				profile._Player,
				profile,
				totalStats(profile),
				findCockpit(profile.CurrentCategory, profile.CurrentCockpit),
				findModule,
				moduleTypeForModel
			),
			TotalStats = totalStats(profile),
		}
	end

	return totalStats, profileForClient
end
