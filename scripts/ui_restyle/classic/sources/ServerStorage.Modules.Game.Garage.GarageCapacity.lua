-- Canonical feature implementation; startup is owned by the composition root.
-- GarageServer garage capacity, owned garage properties and property/capacity purchases. Extracted verbatim from the GarageServer controller closure
-- (architecture P5); dependencies arrive through ctx and the same locals are returned in order.
return function(ctx)
	local MoneyService = ctx.MoneyService
	local function garageCapacity()
		local shared = game:GetService("ReplicatedStorage")
		local configRoot = shared and game:GetService("ReplicatedStorage"):FindFirstChild("Config")
		local persistenceConfig = configRoot and game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("Player"):FindFirstChild("Persistence")
		local capacity = persistenceConfig and persistenceConfig:GetAttribute("StartingGarageCapacity")
		if typeof(capacity) ~= "number" then
			capacity = 2
		end
		return math.max(1, math.floor(capacity))
	end

	local function ownedCockpitCount(profile)
		local count = 0
		for _, owned in pairs((profile and profile.OwnedCockpits) or {}) do
			if owned == true then
				count += 1
			end
		end
		return count
	end
	local function persistenceConfigAttribute(name, fallback)
		local shared = game:GetService("ReplicatedStorage")
		local configRoot = shared and game:GetService("ReplicatedStorage"):FindFirstChild("Config")
		local persistenceConfig = configRoot and game:GetService("ServerStorage"):WaitForChild("Config"):WaitForChild("Player"):FindFirstChild("Persistence")
		local value = persistenceConfig and persistenceConfig:GetAttribute(name)
		if value == nil then
			return fallback
		end
		return value
	end

	local cachedGarageCatalog = nil

	local function garageCatalog()
		if not cachedGarageCatalog then cachedGarageCatalog=require(game:GetService("ReplicatedStorage").Modules.Game.Garage.GaragePropertyCatalog) end
		return cachedGarageCatalog
	end

	local function garageProperties()
		return garageCatalog().List()
	end

	local function propertyById(propertyId)
		return garageCatalog().ById(tostring(propertyId or ""))
	end

	local function startingGarageCapacity()
		return math.max(1, math.floor(tonumber(persistenceConfigAttribute("StartingGarageCapacity", 2)) or 2))
	end

	local function ownedGarageProperties(profile)
		profile.OwnedGarageProperties = typeof(profile.OwnedGarageProperties) == "table" and profile.OwnedGarageProperties or {}
		return profile.OwnedGarageProperties
	end

	local function isGaragePropertyOwned(profile, propertyId)
		local owned = ownedGarageProperties(profile)
		return owned[tostring(propertyId or "")] ~= nil
	end

	local function ownedGaragePropertySpaces(profile)
		local spaces = 0
		for propertyId in pairs(ownedGarageProperties(profile)) do
			local property = propertyById(propertyId)
			if property then
				spaces += math.max(0, math.floor(tonumber(property.Spaces) or 0))
			end
		end
		return spaces
	end

	local function totalCatalogGarageCapacity()
		local capacity = startingGarageCapacity()
		for _, property in ipairs(garageProperties()) do
			if property.Available == true then
				capacity += math.max(0, math.floor(tonumber(property.Spaces) or 0))
			end
		end
		return math.max(startingGarageCapacity(), capacity)
	end

	local function backfillLegacyGarageCapacity(profile)
		local legacyCapacity = math.max(startingGarageCapacity(), math.floor(tonumber(profile and profile.GarageCapacity) or startingGarageCapacity()))
		local owned = ownedGarageProperties(profile)
		local current = startingGarageCapacity() + ownedGaragePropertySpaces(profile)
		if current >= legacyCapacity then
			return
		end
		for _, property in ipairs(garageProperties()) do
			local propertyId = tostring(property.PropertyId or "")
			if property.Available == true and propertyId ~= "" and owned[propertyId] == nil then
				owned[propertyId] = {
					TemplateId = propertyId,
					DisplayName = tostring(property.DisplayName or propertyId),
					Spaces = math.max(1, math.floor(tonumber(property.Spaces) or 1)),
					AcquiredAtUnix = 0,
					Source = "LegacyCapacityBridge",
				}
				current += math.max(0, math.floor(tonumber(property.Spaces) or 0))
				if current >= legacyCapacity then
					break
				end
			end
		end
	end

	local function profileGarageCapacity(profile)
		if profile then
			backfillLegacyGarageCapacity(profile)
		end
		local propertyCapacity = startingGarageCapacity() + ownedGaragePropertySpaces(profile or {})
		local legacyCapacity = tonumber(profile and profile.GarageCapacity) or garageCapacity()
		return math.max(startingGarageCapacity(), math.floor(propertyCapacity), math.floor(legacyCapacity or 0))
	end

	local function maxGarageCapacity()
		local configured = math.max(1, math.floor(tonumber(persistenceConfigAttribute("MaxGarageCapacity", 10)) or 10))
		return math.min(configured, totalCatalogGarageCapacity())
	end

	local function capacityUpgradeStep()
		return math.max(1, math.floor(tonumber(persistenceConfigAttribute("GarageCapacityUpgradeStep", 1)) or 1))
	end

	local function capacityUpgradePrice(profile)
		local capacity = profileGarageCapacity(profile)
		local startCapacity = math.max(1, math.floor(tonumber(persistenceConfigAttribute("StartingGarageCapacity", 2)) or 2))
		local basePrice = math.max(0, tonumber(persistenceConfigAttribute("GarageCapacityUpgradeBasePrice", 50000)) or 50000)
		local multiplier = math.max(1, tonumber(persistenceConfigAttribute("GarageCapacityUpgradePriceMultiplier", 1.65)) or 1.65)
		local level = math.max(0, capacity - startCapacity)
		return math.floor(basePrice * (multiplier ^ level) + 0.5)
	end

	local function nextBuyableGarageProperty(profile)
		for _, property in ipairs(garageProperties()) do
			local propertyId = tostring(property.PropertyId or "")
			if property.Available == true and propertyId ~= "" and not isGaragePropertyOwned(profile, propertyId) then
				return property
			end
		end
		return nil
	end

	local function nextGaragePropertyPrice(profile)
		local property = nextBuyableGarageProperty(profile)
		return property and math.max(0, math.floor(tonumber(property.Price) or capacityUpgradePrice(profile))) or nil
	end

	local function buyGarageProperty(profile, args)
		if not profile then
			return false, "Garage profile missing."
		end
		args = typeof(args) == "table" and args or {}
		local propertyId = tostring(args.PropertyId or "")
		local property = propertyById(propertyId)
		if not property then
			return false, "Garage property is not available."
		end
		if property.Available ~= true then
			return false, "This garage location is not for sale yet."
		end
		if isGaragePropertyOwned(profile, propertyId) then
			return false, "You already own this garage."
		end
		local maxCapacity = maxGarageCapacity()
		if profileGarageCapacity(profile) >= maxCapacity then
			return false, "Garage collection is already at the current maximum."
		end
		local price = math.max(0, math.floor(tonumber(property.Price) or capacityUpgradePrice(profile)))
		if (profile.Cash or 0) < price then
			return false, "Not enough cash."
		end
		MoneyService.Debit(profile, price, "GarageProperty")
		ownedGarageProperties(profile)[propertyId] = {
			TemplateId = propertyId,
			DisplayName = tostring(property.DisplayName or propertyId),
			District = tostring(property.District or ""),
			Spaces = math.max(1, math.floor(tonumber(property.Spaces) or 1)),
			AcquiredAtUnix = os.time(),
			Source = "BuyGarageProperty",
		}
		profile.GarageCapacity = profileGarageCapacity(profile)
		return true, "Garage property purchased."
	end

	local function upgradeGarageCapacity(profile)
		local property = nextBuyableGarageProperty(profile)
		if not property then
			return false, "No garage properties are available right now."
		end
		return buyGarageProperty(profile, { PropertyId = property.PropertyId })
	end

	local function canBuyCockpit(profile, cockpitId)
		if not profile then
			return false, "Garage profile missing."
		end
		profile.OwnedCockpits = profile.OwnedCockpits or {}
		if profile.OwnedCockpits[cockpitId] == true then
			return true
		end
		local capacity = profileGarageCapacity(profile)
		local ownedCount = ownedCockpitCount(profile)
		if ownedCount >= capacity then
			return false, "Garage full. Upgrade your garage to store more vehicles."
		end
		return true
	end
	-- ProfileServer owns the only persistent profile table.
	return ownedCockpitCount, ownedGarageProperties, profileGarageCapacity, maxGarageCapacity, capacityUpgradePrice, nextGaragePropertyPrice, buyGarageProperty, upgradeGarageCapacity, canBuyCockpit
end
