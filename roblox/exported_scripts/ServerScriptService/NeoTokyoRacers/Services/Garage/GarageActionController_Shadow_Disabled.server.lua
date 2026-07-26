-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1
-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP
-- Neo Tokyo Racers shadow server action controller.
-- Disabled switch candidate generated from the current V56 action block.
-- Do not enable while HOVER_RACING_V2_Server still owns GarageInvoke.OnServerInvoke.
-- Source hash: 3be69270

-- V56_CONSOLIDATED_ACTION_CONTROLLER_BEGIN
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local CollectionService = game:GetService("CollectionService")

	local V56_KIT_NAME = "NeoTokyoRacers"
	local V56_WORLD_NAME = "NeoTokyoRacersWorld"
	local V56_kit = ReplicatedStorage:WaitForChild(V56_KIT_NAME)
	local V56_remotes = V56_kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
	local V56_invoke = V56_remotes:WaitForChild("GarageInvoke")
	local V56_categoriesRoot = V56_kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
	local V56_world = Workspace:WaitForChild(V56_WORLD_NAME)
	local V56_runtime = V56_world:WaitForChild("Runtime")
	local V56_vehiclesRoot = V56_runtime:WaitForChild("PlayerVehicles")
local V56_STARTING_CASH = V56_kit:GetAttribute("StartingCash") or 140000
	local V56_FALLBACK_SPAWN_POS = Vector3.new(V56_kit:GetAttribute("SpawnX") or 860, V56_kit:GetAttribute("SpawnY") or 105, V56_kit:GetAttribute("SpawnZ") or -1713)

	local function V56_spawnCFrame()
		local dealership = V56_world:FindFirstChild("Dealership")
		local dealershipSpawn = dealership and dealership:FindFirstChild("Spawn")
		local exitSpawn = dealershipSpawn and dealershipSpawn:FindFirstChild("VehicleExitSpawnPoint")
		if exitSpawn and exitSpawn:IsA("BasePart") then
			return exitSpawn.CFrame
		end

		local spawnPoints = V56_world:FindFirstChild("SpawnPoints")
		local fallbackSpawn = spawnPoints and spawnPoints:FindFirstChild("VehicleSpawnPoint")
		if fallbackSpawn and fallbackSpawn:IsA("BasePart") then
			return fallbackSpawn.CFrame
		end

		return CFrame.lookAt(V56_FALLBACK_SPAWN_POS, V56_FALLBACK_SPAWN_POS + Vector3.new(0, 0, 1))
	end
	local V56_PREVIEW_POS = Vector3.new(V56_kit:GetAttribute("PreviewX") or 860, V56_kit:GetAttribute("PreviewY") or 104, V56_kit:GetAttribute("PreviewZ") or -1749)
	local V56_profiles = {}
	local V89_GarageProfileRuntime = require(script.Parent:WaitForChild("GarageProfileRuntime"))
	local V96_ModuleInventory = require(script.Parent:WaitForChild("GarageModuleInventoryRuntime")) -- NTR_GARAGE_MODULE_INVENTORY_GUARD_V1
	local V97_ModuleInstances = require(script.Parent:WaitForChild("GarageModuleInstanceCustomizationRuntime")) -- NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1
	local V98_ModuleTransactions = require(script.Parent:WaitForChild("GarageModuleTransactionRuntime")) -- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1
	local V101_VehicleCosmetics = require(script.Parent:WaitForChild("VehicleCosmeticServerRuntime")) -- NTR_CUSTOMISATION_VEHICLE_COSMETIC_ACTION_BRIDGE_V1
	local V101_CosmeticCatalog = require(V56_kit.Shared.Modules.Data:WaitForChild("VehicleCosmeticCatalog"))

	-- NTR_VEHICLE_PHASE_AN_ISOLATED_UPGRADES
	local V77_ModuleUpgrades = require(V56_kit
		:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Common")
		:WaitForChild("Performance")
		:WaitForChild("VehicleModuleUpgradeRuntime"))

	local function V56_value(item, name)
		if not item then return nil end
		local attr = item:GetAttribute(name)
		if attr ~= nil then return attr end
		local child = item:FindFirstChild(name)
		if child and child:IsA("ValueBase") then return child.Value end
		return nil
	end

	local function V56_number(item, name, fallback)
		local value = V56_value(item, name)
		if typeof(value) == "number" then return value end
		if typeof(value) == "string" then
			local number = tonumber(value)
			if number then return number end
		end
		return fallback
	end

	local function V56_string(item, name, fallback)
		local value = V56_value(item, name)
		if typeof(value) == "string" and value ~= "" then return value end
		return fallback
	end

	local function V56_primitiveAttributes(instance)
		local result = {}
		for key, value in pairs(instance:GetAttributes()) do
			local t = typeof(value)
			if t == "string" or t == "number" or t == "boolean" or t == "Color3" then
				result[key] = value
			end
		end
		return result
	end

	local function V56_defaultProfile()
		return {
			Cash = V56_STARTING_CASH,
			CurrentCategory = "bruiser",
			CurrentCockpit = "bruiser_01",
			OwnedCockpits = {}, -- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY
			CockpitColors = {
				Primary = Color3.fromRGB(0, 205, 230),
				Secondary = Color3.fromRGB(235, 247, 204),
				Detail = Color3.fromRGB(38, 44, 50),
				Neon = Color3.fromRGB(255, 255, 255),
				FrontLights = Color3.fromRGB(252, 250, 255),
				RearLights = Color3.fromRGB(255, 116, 116),
			},
			ThrustColor = Color3.fromRGB(255, 255, 255),
			OwnedModules = {},
			InstalledModules = {},
			ModuleColors = {},
			NeonOwned = {},
			UpgradeLevels = { Brakes = 0, Converter = 0, FuelSystem = 0 },
			GarageCapacity = 2,
			-- NTR_PERSISTENCE_PHASE13_GARAGE_PROPERTIES
			OwnedGarageProperties = {},
			-- NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY
			CurrentVehicleId = nil,
			Vehicles = {},
			OwnedCockpitInstances = {},
			OwnedModuleInstances = {},
			ModuleUpgradeLevels = {},
			ModuleUpgradeLevels = {},
			ModuleUpgradeLevels = {},
		}
	end

	local function V56_normalizeProfile(profile)
		profile.Cash = typeof(profile.Cash) == "number" and profile.Cash or V56_STARTING_CASH
		profile.CurrentCategory = profile.CurrentCategory or "bruiser"
		profile.CurrentCockpit = profile.CurrentCockpit or "bruiser_01"
		profile.OwnedCockpits = profile.OwnedCockpits or {} -- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY
		profile.OwnedModules = profile.OwnedModules or {}
		profile.InstalledModules = profile.InstalledModules or {}
		profile.ModuleColors = profile.ModuleColors or {}
		profile.NeonOwned = profile.NeonOwned or {}
		profile.UpgradeLevels = profile.UpgradeLevels or { Brakes = 0, Converter = 0, FuelSystem = 0 }
		profile.GarageCapacity = math.max(1, math.floor(tonumber(profile.GarageCapacity) or 2))
		profile.OwnedGarageProperties = typeof(profile.OwnedGarageProperties) == "table" and profile.OwnedGarageProperties or {}
		-- NTR_PERSISTENCE_PHASE14_INSTANCE_INVENTORY
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
		profile.CurrentVehicleId = profile.CurrentVehicleId ~= nil and tostring(profile.CurrentVehicleId) or nil
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
		profile.CockpitColors = profile.CockpitColors or {}
		profile.CockpitColors.Primary = profile.CockpitColors.Primary or Color3.fromRGB(0, 205, 230)
		profile.CockpitColors.Secondary = profile.CockpitColors.Secondary or Color3.fromRGB(235, 247, 204)
		profile.CockpitColors.Detail = profile.CockpitColors.Detail or Color3.fromRGB(38, 44, 50)
		profile.CockpitColors.Neon = profile.CockpitColors.Neon or Color3.fromRGB(255, 255, 255)
		profile.CockpitColors.FrontLights = profile.CockpitColors.FrontLights or Color3.fromRGB(252, 250, 255)
		profile.CockpitColors.RearLights = profile.CockpitColors.RearLights or Color3.fromRGB(255, 116, 116)
		profile.ThrustColor = profile.ThrustColor or Color3.fromRGB(255, 255, 255)
		return profile
	end

	-- NTR_PERSISTENCE_PHASE18_PROFILE_SOURCE_HANDOFF
	local function V87_cloneValue(value)
		if typeof(value) == "table" then
			local copy = {}
			for key, child in pairs(value) do
				copy[key] = V87_cloneValue(child)
			end
			return copy
		end
		return value
	end

	local function V87_countDictionary(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function V87_getProfileServiceProfile(player)
		local getProfile = nil
		local deadline = os.clock() + 5
		while os.clock() < deadline do
			local servicesRoot = script.Parent and script.Parent.Parent
			local playerServices = servicesRoot and servicesRoot:FindFirstChild("Player")
			local profileBindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
			getProfile = profileBindings and profileBindings:FindFirstChild("GetProfile")
			if getProfile and getProfile:IsA("BindableFunction") then
				local ok, profileOrError = pcall(function()
					return getProfile:Invoke(player)
				end)
				if ok and typeof(profileOrError) == "table" then
					return profileOrError, nil
				end
				if not ok then
					return nil, tostring(profileOrError)
				end
			end
			task.wait(0.1)
		end
		return nil, "ProfileService profile not loaded"
	end

	local function V87_profileHasSavedInstanceData(savedProfile)
		if typeof(savedProfile) ~= "table" then
			return false
		end
		if V87_countDictionary(savedProfile.Vehicles) > 0 then
			return true
		end
		if V87_countDictionary(savedProfile.OwnedCockpitInstances) > 0 then
			return true
		end
		if V87_countDictionary(savedProfile.OwnedModuleInstances) > 0 then
			return true
		end
		local garage = savedProfile.Garage
		if typeof(garage) == "table" and V87_countDictionary(garage.OwnedGarageProperties) > 0 then
			return true
		end
		return false
	end

	local function V87_currentVehicleFromSavedProfile(savedProfile)
		local vehicles = typeof(savedProfile.Vehicles) == "table" and savedProfile.Vehicles or {}
		local vehicleId = savedProfile.CurrentVehicleId ~= nil and tostring(savedProfile.CurrentVehicleId) or nil
		local vehicle = vehicleId and vehicles[vehicleId] or nil
		if typeof(vehicle) == "table" then
			return vehicleId, vehicle
		end
		for fallbackVehicleId, fallbackVehicle in pairs(vehicles) do
			if typeof(fallbackVehicle) == "table" then
				return tostring(fallbackVehicleId), fallbackVehicle
			end
		end
		return nil, nil
	end

	local function V87_savedProfileToLegacySession(savedProfile)
		local legacy = V56_defaultProfile()
		legacy.Cash = typeof(savedProfile.Cash) == "number" and savedProfile.Cash or legacy.Cash
		local garage = typeof(savedProfile.Garage) == "table" and savedProfile.Garage or {}
		legacy.GarageCapacity = math.max(1, math.floor(tonumber(garage.Capacity) or legacy.GarageCapacity or 2))
		legacy.OwnedGarageProperties = V87_cloneValue(garage.OwnedGarageProperties or {})
		legacy.GarageDisplaySpaces = V87_cloneValue(garage.DisplaySpaces or {})
		legacy.Vehicles = V87_cloneValue(savedProfile.Vehicles or {})
		legacy.OwnedCockpitInstances = V87_cloneValue(savedProfile.OwnedCockpitInstances or {})
		legacy.OwnedModuleInstances = V87_cloneValue(savedProfile.OwnedModuleInstances or {})
		legacy.CurrentVehicleId = savedProfile.CurrentVehicleId ~= nil and tostring(savedProfile.CurrentVehicleId) or nil
		legacy.ModuleUpgradeLevels = {}

		local currentVehicleId, currentVehicle = V87_currentVehicleFromSavedProfile(savedProfile)
		if currentVehicleId then
			legacy.CurrentVehicleId = currentVehicleId
		end
		if typeof(currentVehicle) == "table" then
			legacy.CurrentCategory = tostring(currentVehicle.CategoryId or legacy.CurrentCategory or "bruiser")
			legacy.CockpitColors = V87_cloneValue(currentVehicle.CockpitColors or legacy.CockpitColors)
			legacy.ThrustColor = currentVehicle.ThrustColor or legacy.ThrustColor
			local cockpitInstance = currentVehicle.CockpitInstanceId and legacy.OwnedCockpitInstances[currentVehicle.CockpitInstanceId] or nil
			if typeof(cockpitInstance) == "table" and cockpitInstance.TemplateId then
				legacy.CurrentCockpit = tostring(cockpitInstance.TemplateId)
			end
		end

		legacy.OwnedCockpits = {}
		for _, cockpitInstance in pairs(legacy.OwnedCockpitInstances) do
			if typeof(cockpitInstance) == "table" and cockpitInstance.TemplateId then
				legacy.OwnedCockpits[tostring(cockpitInstance.TemplateId)] = true
			end
		end
		legacy.OwnedCockpits[legacy.CurrentCockpit or "bruiser_01"] = true

		legacy.OwnedModules = {}
		legacy.InstalledModules = {}
		legacy.ModuleColors = {}
		legacy.NeonOwned = {}
		local installedInstances = typeof(currentVehicle) == "table" and typeof(currentVehicle.InstalledModules) == "table" and currentVehicle.InstalledModules or {}
		for instanceId, moduleInstance in pairs(legacy.OwnedModuleInstances) do
			if typeof(moduleInstance) == "table" and moduleInstance.TemplateId then
				local moduleId = tostring(moduleInstance.TemplateId)
				legacy.OwnedModules[moduleId] = true
				if typeof(moduleInstance.UpgradeLevels) == "table" then
					legacy.ModuleUpgradeLevels[moduleId] = V87_cloneValue(moduleInstance.UpgradeLevels)
				end
				for slotId, installedInstanceId in pairs(installedInstances) do
					if tostring(installedInstanceId) == tostring(instanceId) then
						legacy.InstalledModules[slotId] = moduleId
						legacy.ModuleColors[slotId] = V87_cloneValue(moduleInstance.Colors or {})
						legacy.NeonOwned[slotId] = moduleInstance.NeonOwned == true
					end
				end
			end
		end

		return V56_normalizeProfile(legacy)
	end

	local function V87_tryHydrateProfileFromPersistence(player)
		local savedProfile, loadMessage = V87_getProfileServiceProfile(player)
		if not V87_profileHasSavedInstanceData(savedProfile) then
			player:SetAttribute("NTR_PersistencePhase18Hydrated", false)
			player:SetAttribute("NTR_PersistencePhase18HydrationSource", tostring(loadMessage or "NoSavedInstanceData"))
			player:SetAttribute("NTR_PersistencePhase18SavedVehicleCount", 0)
			return nil
		end
		local legacy = V87_savedProfileToLegacySession(savedProfile)
		player:SetAttribute("NTR_PersistencePhase18Hydrated", true)
		player:SetAttribute("NTR_PersistencePhase18HydrationSource", "ProfileService")
		player:SetAttribute("NTR_PersistencePhase18SavedVehicleCount", V87_countDictionary(savedProfile.Vehicles))
		player:SetAttribute("NTR_PersistencePhase18SavedModuleInstanceCount", V87_countDictionary(savedProfile.OwnedModuleInstances))
		return legacy
	end

	local function V56_getProfile(player)
		local profile = V56_profiles[player.UserId]
		if not profile then
			profile = V87_tryHydrateProfileFromPersistence(player) or V56_defaultProfile()
			V56_profiles[player.UserId] = profile
		end
		return V56_normalizeProfile(profile)
	end

	-- NTR_GARAGE_MODULE_INVENTORY_DUAL_OWNER_BRIDGE_V1
	-- The legacy garage session remains a compatibility owner. This tiny bridge
	-- lets the reviewed one-time cleanup update it in the same transaction as
	-- ProfileService, so its normal mirror cannot restore stale inventory.
	local V97_cleanupBridge = script.Parent:FindFirstChild("GarageModuleInventoryCleanupBridge")
	if V97_cleanupBridge and not V97_cleanupBridge:IsA("BindableFunction") then
		error("GarageModuleInventoryCleanupBridge exists with the wrong class")
	end
	if not V97_cleanupBridge then
		V97_cleanupBridge = Instance.new("BindableFunction")
		V97_cleanupBridge.Name = "GarageModuleInventoryCleanupBridge"
		V97_cleanupBridge.Parent = script.Parent
	end
	V97_cleanupBridge.OnInvoke = function(player, mode, expectedToken)
		local profile = V56_getProfile(player)
		if mode == "Apply" then
			return V96_ModuleInventory.ApplyReviewedCleanup(profile, expectedToken)
		elseif mode == "Rollback" then
			return V96_ModuleInventory.RollbackReviewedCleanup(profile)
		elseif mode == "Commit" then
			return V96_ModuleInventory.CommitReviewedCleanup(profile)
		end
		return false, "Unknown cleanup bridge mode."
	end

	-- NTR_PERSISTENCE_PHASE6_GARAGE_CAPACITY_GATE
	local function V81_garageCapacity()
		local shared = V56_kit:FindFirstChild("Shared")
		local configRoot = shared and shared:FindFirstChild("Config")
		local persistenceConfig = configRoot and configRoot:FindFirstChild("Persistence_EditAttributes")
		local capacity = persistenceConfig and persistenceConfig:GetAttribute("StartingGarageCapacity")
		if typeof(capacity) ~= "number" then
			capacity = 2
		end
		return math.max(1, math.floor(capacity))
	end

	local function V81_ownedCockpitCount(profile)
		local count = 0
		for _, owned in pairs((profile and profile.OwnedCockpits) or {}) do
			if owned == true then
				count += 1
			end
		end
		return count
	end

	-- NTR_PERSISTENCE_PHASE7_GARAGE_CAPACITY_UPGRADE
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

	local V83_cachedGarageCatalog = nil

	local function V83_garageCatalog()
		if V83_cachedGarageCatalog then
			return V83_cachedGarageCatalog
		end
		local shared = V56_kit:FindFirstChild("Shared")
		local modules = shared and shared:FindFirstChild("Modules")
		local data = modules and modules:FindFirstChild("Data")
		local catalogModule = data and data:FindFirstChild("GaragePropertyCatalog")
		if catalogModule and catalogModule:IsA("ModuleScript") then
			local ok, result = pcall(require, catalogModule)
			if ok and typeof(result) == "table" then
				V83_cachedGarageCatalog = result
				return result
			end
		end
		return nil
	end

	local function V83_garageProperties()
		local catalogModule = V83_garageCatalog()
		if catalogModule and typeof(catalogModule.List) == "function" then
			local ok, properties = pcall(catalogModule.List)
			if ok and typeof(properties) == "table" then
				return properties
			end
		end
		return {}
	end

	local function V83_propertyById(propertyId)
		propertyId = tostring(propertyId or "")
		local catalogModule = V83_garageCatalog()
		if catalogModule and typeof(catalogModule.ById) == "function" then
			local ok, property = pcall(catalogModule.ById, propertyId)
			if ok and typeof(property) == "table" then
				return property
			end
		end
		for _, property in ipairs(V83_garageProperties()) do
			if tostring(property.PropertyId) == propertyId then
				return property
			end
		end
		return nil
	end

	local function V83_startingGarageCapacity()
		return math.max(1, math.floor(tonumber(V82_persistenceConfigAttribute("StartingGarageCapacity", 2)) or 2))
	end

	local function V83_ownedGarageProperties(profile)
		profile.OwnedGarageProperties = typeof(profile.OwnedGarageProperties) == "table" and profile.OwnedGarageProperties or {}
		return profile.OwnedGarageProperties
	end

	local function V83_isGaragePropertyOwned(profile, propertyId)
		local owned = V83_ownedGarageProperties(profile)
		return owned[tostring(propertyId or "")] ~= nil
	end

	local function V83_ownedGaragePropertySpaces(profile)
		local spaces = 0
		for propertyId in pairs(V83_ownedGarageProperties(profile)) do
			local property = V83_propertyById(propertyId)
			if property then
				spaces += math.max(0, math.floor(tonumber(property.Spaces) or 0))
			end
		end
		return spaces
	end

	local function V83_totalCatalogGarageCapacity()
		local capacity = V83_startingGarageCapacity()
		for _, property in ipairs(V83_garageProperties()) do
			if property.Available == true then
				capacity += math.max(0, math.floor(tonumber(property.Spaces) or 0))
			end
		end
		return math.max(V83_startingGarageCapacity(), capacity)
	end

	local function V83_backfillLegacyGarageCapacity(profile)
		local legacyCapacity = math.max(V83_startingGarageCapacity(), math.floor(tonumber(profile and profile.GarageCapacity) or V83_startingGarageCapacity()))
		local owned = V83_ownedGarageProperties(profile)
		local current = V83_startingGarageCapacity() + V83_ownedGaragePropertySpaces(profile)
		if current >= legacyCapacity then
			return
		end
		for _, property in ipairs(V83_garageProperties()) do
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

	local function V82_profileGarageCapacity(profile)
		if profile then
			V83_backfillLegacyGarageCapacity(profile)
		end
		local propertyCapacity = V83_startingGarageCapacity() + V83_ownedGaragePropertySpaces(profile or {})
		local legacyCapacity = tonumber(profile and profile.GarageCapacity) or V81_garageCapacity()
		return math.max(V83_startingGarageCapacity(), math.floor(propertyCapacity), math.floor(legacyCapacity or 0))
	end

	local function V82_maxGarageCapacity()
		local configured = math.max(1, math.floor(tonumber(V82_persistenceConfigAttribute("MaxGarageCapacity", 10)) or 10))
		return math.min(configured, V83_totalCatalogGarageCapacity())
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

	local function V83_nextBuyableGarageProperty(profile)
		for _, property in ipairs(V83_garageProperties()) do
			local propertyId = tostring(property.PropertyId or "")
			if property.Available == true and propertyId ~= "" and not V83_isGaragePropertyOwned(profile, propertyId) then
				return property
			end
		end
		return nil
	end

	local function V83_nextGaragePropertyPrice(profile)
		local property = V83_nextBuyableGarageProperty(profile)
		return property and math.max(0, math.floor(tonumber(property.Price) or V82_capacityUpgradePrice(profile))) or nil
	end

	local function V83_buyGarageProperty(profile, args)
		if not profile then
			return false, "Garage profile missing."
		end
		args = typeof(args) == "table" and args or {}
		local propertyId = tostring(args.PropertyId or "")
		local property = V83_propertyById(propertyId)
		if not property then
			return false, "Garage property is not available."
		end
		if property.Available ~= true then
			return false, "This garage location is not for sale yet."
		end
		if V83_isGaragePropertyOwned(profile, propertyId) then
			return false, "You already own this garage."
		end
		local maxCapacity = V82_maxGarageCapacity()
		if V82_profileGarageCapacity(profile) >= maxCapacity then
			return false, "Garage collection is already at the current maximum."
		end
		local price = math.max(0, math.floor(tonumber(property.Price) or V82_capacityUpgradePrice(profile)))
		if (profile.Cash or 0) < price then
			return false, "Not enough cash."
		end
		profile.Cash -= price
		V83_ownedGarageProperties(profile)[propertyId] = {
			TemplateId = propertyId,
			DisplayName = tostring(property.DisplayName or propertyId),
			District = tostring(property.District or ""),
			Spaces = math.max(1, math.floor(tonumber(property.Spaces) or 1)),
			AcquiredAtUnix = os.time(),
			Source = "BuyGarageProperty",
		}
		profile.GarageCapacity = V82_profileGarageCapacity(profile)
		return true, "Garage property purchased."
	end

	local function V82_upgradeGarageCapacity(profile)
		local property = V83_nextBuyableGarageProperty(profile)
		if not property then
			return false, "No garage properties are available right now."
		end
		return V83_buyGarageProperty(profile, { PropertyId = property.PropertyId })
	end

	local function V81_canBuyCockpit(profile, cockpitId)
		if not profile then
			return false, "Garage profile missing."
		end
		profile.OwnedCockpits = profile.OwnedCockpits or {}
		if profile.OwnedCockpits[cockpitId] == true then
			return true
		end
		local capacity = V82_profileGarageCapacity(profile)
		local ownedCount = V81_ownedCockpitCount(profile)
		if ownedCount >= capacity then
			return false, "Garage full. Upgrade your garage to store more vehicles."
		end
		return true
	end

	-- NTR_PERSISTENCE_PHASE4_SESSION_MIRROR
	local V80_persistenceBindings = nil
	local V80_mutatingActions = {
		BuyCockpit = true,
		BuyGarageProperty = true,
		SetCockpitColor = true,
		BuyModule = true,
		SetModuleColor = true,
		UpgradeModule = true,
		Upgrade = true,
		BuyNeon = true,
		SetThrustColor = true,
		BuyVehicleCosmetic = true,
		SetVehicleCosmeticColor = true,
		SetAllNeonColor = true,
		SpawnVehicle = false,
		SpawnOwnedVehicleFromFreeRoam = true,
		ExitVehicle = false,
		DespawnVehicle = false,
		ReEnterVehicle = false,
		GetInitial = false,		BuyCockpitInstance = true,
		BuyModuleInstance = true,
		EquipModuleInstance = true,

	}

	local function V80_countDictionary(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function V80_replaceTableContents(target, source)
		for key in pairs(target) do
			target[key] = nil
		end
		for key, value in pairs(source or {}) do
			target[key] = value
		end
	end

	local function V80_getPersistenceBindings()
		if V80_persistenceBindings then
			return V80_persistenceBindings
		end
		local servicesRoot = script.Parent and script.Parent.Parent
		local playerServices = servicesRoot and servicesRoot:FindFirstChild("Player")
		local profileBindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
		local bridgeBindings = playerServices and playerServices:FindFirstChild("LegacyGarageProfileBridgeBindings")
		local getProfile = profileBindings and profileBindings:FindFirstChild("GetProfile")
		local markDirty = profileBindings and profileBindings:FindFirstChild("MarkDirty")
		local importProfileSnapshot = profileBindings and profileBindings:FindFirstChild("ImportProfileSnapshot")
		local convert = bridgeBindings and bridgeBindings:FindFirstChild("ConvertLegacyProfile")
		if getProfile and markDirty and importProfileSnapshot and convert then
			V80_persistenceBindings = {
				GetProfile = getProfile,
				MarkDirty = markDirty,
				ImportProfileSnapshot = importProfileSnapshot,
				ConvertLegacyProfile = convert,
			}
		end
		return V80_persistenceBindings
	end

	local function V80_mirrorLegacyProfileToPersistence(player, profile, action, markDirty)
		local bindings = V80_getPersistenceBindings()
		if not bindings then
			return
		end
		local okConvert, converted = pcall(function()
			return bindings.ConvertLegacyProfile:Invoke(profile, { PreserveLegacyCapacity = true })
		end)
		if not okConvert or typeof(converted) ~= "table" then
			warn("[NTR Persistence Phase 4] Legacy profile conversion failed: " .. tostring(converted))
			return
		end
		-- NTR_OWNED_GARAGE_PHASE6_PERSISTENCE_PRESERVE_V1
		local currentSaved=bindings.GetProfile:Invoke(player); if typeof(currentSaved)=="table" and typeof(currentSaved.OwnedGarage)=="table" then converted.OwnedGarage=V87_cloneValue(currentSaved.OwnedGarage) end
		local okImport, importOk, importMessage = pcall(function()
			-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT
			return bindings.ImportProfileSnapshot:Invoke(player, converted, "GarageAction:" .. tostring(action or "Unknown"), markDirty == true)
		end)
		if not okImport or importOk ~= true then
			warn("[NTR Persistence Phase 5] ProfileService snapshot import failed: " .. tostring(importOk or importMessage))
			return
		end
		player:SetAttribute("NTR_PersistenceMirrorLastAction", tostring(action or "Unknown"))
		player:SetAttribute("NTR_PersistenceMirrorVehicleCount", V80_countDictionary(converted.Vehicles))
		player:SetAttribute("NTR_PersistenceMirrorModuleInstanceCount", V80_countDictionary(converted.OwnedModuleInstances))
		-- Dirty marking is owned by ImportProfileSnapshot after Phase 5.
	end

	-- NTR_VEHICLE_PHASE_AK_PER_COCKPIT_COLOURS
	local function V76_findCockpitForDefaultColours(categoryId, cockpitId)
		for _, category in ipairs(V56_categoriesRoot:GetChildren()) do
			local categoryMatches = category:GetAttribute("CategoryId") == categoryId
				or category.Name == categoryId
				or string.lower(category.Name) == string.lower(tostring(categoryId))
			if categoryMatches then
				local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
				for _, item in ipairs((root or category):GetDescendants()) do
					if item:IsA("Model") and item:GetAttribute("CockpitId") == cockpitId then
						return item
					end
				end
			end
		end
	end

	local function V76_colorAttribute(item, name, fallback)
		local value = item and item:GetAttribute(name)
		if typeof(value) == "Color3" then
			return value
		end
		return fallback
	end

	local function V76_defaultCockpitColorsFor(profile)
		local cockpit = V76_findCockpitForDefaultColours(profile.CurrentCategory or "bruiser", profile.CurrentCockpit or "bruiser_01")
		return {
			Primary = V76_colorAttribute(cockpit, "DefaultPrimaryColor", Color3.fromRGB(0, 205, 230)),
			Secondary = V76_colorAttribute(cockpit, "DefaultSecondaryColor", Color3.fromRGB(235, 247, 204)),
			Detail = V76_colorAttribute(cockpit, "DefaultDetailColor", Color3.fromRGB(38, 44, 50)),
			Neon = V76_colorAttribute(cockpit, "DefaultNeonColor", Color3.fromRGB(255, 255, 255)),
			FrontLights = V76_colorAttribute(cockpit, "DefaultFrontLightsColor", Color3.fromRGB(252, 250, 255)),
			RearLights = V76_colorAttribute(cockpit, "DefaultRearLightsColor", Color3.fromRGB(255, 116, 116)),
		}
	end

	local function V76_syncInstalledModulePaintFromCockpit(profile, channel)
		if not profile then return end
		profile.ModuleColors = profile.ModuleColors or {}
		local cockpitColors = profile.CockpitColors or {}
		for slotId in pairs(profile.InstalledModules or {}) do
			profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
			local moduleColors = profile.ModuleColors[slotId]
			if channel then
				moduleColors[channel] = cockpitColors[channel]
			else
				moduleColors.Primary = cockpitColors.Primary
				moduleColors.Secondary = cockpitColors.Secondary
				moduleColors.Detail = cockpitColors.Detail
			end
			moduleColors.Neon = moduleColors.Neon or Color3.fromRGB(255, 255, 255)
			moduleColors.ThrustColor = profile.ThrustColor
		end
	end

	local function V76_applyDefaultCockpitColors(profile)
		profile.CockpitColors = V76_defaultCockpitColorsFor(profile)
		-- NTR_VEHICLE_PHASE_AK_SPAWN_MODULE_COLOUR_SYNC
		V76_syncInstalledModulePaintFromCockpit(profile)
	end

	local function V56_setLeaderstats(player, profile)
		local stats = player:FindFirstChild("leaderstats")
		if not stats then
			stats = Instance.new("Folder")
			stats.Name = "leaderstats"
			stats.Parent = player
		end
		local cash = stats:FindFirstChild("Cash")
		if not cash then
			cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Parent = stats
		end
		cash.Value = math.floor(profile.Cash or 0)
	end

	-- NTR_RACING_PHASE6_GARAGE_CASH_BRIDGE
	local V91_RaceRewardBridgeReady = false
	local function V91_ensureRaceRewardCashBridge()
		if V91_RaceRewardBridgeReady then
			return
		end
		local bindings = script.Parent:FindFirstChild("GarageProfileMutationBindings")
		if not bindings then
			bindings = Instance.new("Folder")
			bindings.Name = "GarageProfileMutationBindings"
			bindings.Parent = script.Parent
		end
		local grantCash = bindings:FindFirstChild("GrantCash")
		if not grantCash then
			grantCash = Instance.new("BindableFunction")
			grantCash.Name = "GrantCash"
			grantCash.Parent = bindings
		end
		grantCash.OnInvoke = function(action, payload)
			if action ~= "GrantCash" then
				return { Ok = false, Success = false, Message = "Unknown garage mutation action." }
			end
			payload = typeof(payload) == "table" and payload or {}
			local player = payload.Player
			local amount = math.floor((tonumber(payload.Amount) or 0) + 0.5)
			if not player or amount <= 0 then
				return { Ok = false, Success = false, Message = "Missing player or positive amount." }
			end
			local profile = V56_getProfile(player)
			profile.Cash = math.max(0, math.floor((tonumber(profile.Cash) or 0) + amount))
			V56_setLeaderstats(player, profile)
			V80_mirrorLegacyProfileToPersistence(player, profile, tostring(payload.Reason or "RaceRewardGrant"), true)
			player:SetAttribute("NTR_LastRaceRewardAmount", amount)
			player:SetAttribute("NTR_LastRaceRewardRunId", tostring(payload.RunId or ""))
			player:SetAttribute("NTR_LastRaceRewardEventId", tostring(payload.EventId or ""))
			return { Ok = true, Success = true, Amount = amount, Cash = profile.Cash }
		end
		V91_RaceRewardBridgeReady = true
	end
	V91_ensureRaceRewardCashBridge()

	local function V56_slug(name)
		name = string.lower(tostring(name or ""))
		name = string.gsub(name, "%s+", "_")
		name = string.gsub(name, "[^%w_]", "")
		return name
	end

	local function V56_categoryFolder(categoryId)
		for _, category in ipairs(V56_categoriesRoot:GetChildren()) do
			if category:GetAttribute("CategoryId") == categoryId
				or category.Name == categoryId
				or string.lower(category.Name) == string.lower(tostring(categoryId)) then
				return category
			end
		end
		return V56_categoriesRoot:GetChildren()[1]
	end

	local function V56_findByAttribute(root, attr, value)
		if not root then return nil end
		for _, item in ipairs(root:GetDescendants()) do
			if item:GetAttribute(attr) == value then return item end
		end
	end

	local function V56_findCockpit(categoryId, cockpitId)
		local category = V56_categoryFolder(categoryId)
		local root = category and (category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS"))
		return V56_findByAttribute(root or category, "CockpitId", cockpitId)
	end

	local function V56_findModule(categoryId, moduleId)
		local category = V56_categoryFolder(categoryId)
		local root = category and (category:FindFirstChild("MODULES_InterchangeableWithinCategory") or category)
		return V56_findByAttribute(root, "ModuleId", moduleId)
	end


	-- NTR_PERSISTENCE_PHASE16_MODULE_FAMILY_LOCKS
	local V85_attachDefaultModuleInstancesToCurrentVehicle

	local function V85_moduleSourceCockpitId(module)
		if not module then return nil end
		local explicit = module:GetAttribute("SourceCockpitId")
		if explicit ~= nil and tostring(explicit) ~= "" then
			return tostring(explicit)
		end
		local item = module.Parent
		while item and item ~= V56_categoriesRoot do
			local name = tostring(item.Name or "")
			local numberText = string.match(name, "^Bruiser[_%s%-]*(%d+)$") or string.match(name, "BRUISER[_%s%-]*(%d+)")
			if numberText then
				return "bruiser_" .. string.format("%02d", tonumber(numberText) or 0)
			end
			item = item.Parent
		end
		local moduleId = tostring(module:GetAttribute("ModuleId") or module.Name or "")
		local numberText = string.match(moduleId, "BRUISER_(%d+)")
		if numberText then
			return "bruiser_" .. string.format("%02d", tonumber(numberText) or 0)
		end
		return nil
	end

	local function V85_moduleVariantName(module)
		local explicit = module and module:GetAttribute("VariantName")
		if explicit ~= nil and tostring(explicit) ~= "" then
			return tostring(explicit)
		end
		local text = string.upper(tostring(module and (module:GetAttribute("ModuleId") or module.Name) or ""))
		if string.find(text, "LIGHTWEIGHT", 1, true) then return "Lightweight" end
		if string.find(text, "POWER", 1, true) then return "Power" end
		local level = string.match(text, "LVL(%d+)") or string.match(text, "LEVEL(%d+)")
		if level then return "Level " .. tostring(level) end
		if string.find(text, "STANDARD", 1, true) then return "Standard" end
		return "Standard"
	end

	local function V85_moduleVariantOrder(module)
		local explicit = module and tonumber(module:GetAttribute("VariantOrder"))
		if explicit then return explicit end
		local variant = string.lower(V85_moduleVariantName(module))
		if variant == "standard" then return 10 end
		if variant == "lightweight" then return 20 end
		if variant == "power" then return 30 end
		local level = tonumber(string.match(variant, "(%d+)"))
		if level then return 100 + level end
		return 999
	end

	local function V85_findSourceCockpit(profile, module)
		local sourceCockpitId = V85_moduleSourceCockpitId(module)
		if not sourceCockpitId then return nil, nil end
		return sourceCockpitId, V56_findCockpit(profile and profile.CurrentCategory or "bruiser", sourceCockpitId)
	end

	local function V85_playerOwnsSourceCockpit(profile, module)
		local sourceCockpitId = V85_moduleSourceCockpitId(module)
		if not sourceCockpitId then return true, nil end
		if profile and profile.OwnedCockpits and profile.OwnedCockpits[sourceCockpitId] == true then
			return true, sourceCockpitId
		end
		for _, instance in pairs((profile and profile.OwnedCockpitInstances) or {}) do
			if tostring(instance.TemplateId or "") == sourceCockpitId then
				return true, sourceCockpitId
			end
		end
		return false, sourceCockpitId
	end

	local function V85_modulePurchasePrice(module)
		if not module then return 0 end
		local explicit = tonumber(module:GetAttribute("ExtraCopyPrice") or module:GetAttribute("ModuleCopyPrice") or module:GetAttribute("PurchasePrice"))
		if explicit and explicit > 0 then
			return math.floor(explicit)
		end
		local price = V56_number(module, "Price", 0)
		if price > 0 then return price end
		local sourceCockpitId = V85_moduleSourceCockpitId(module)
		local cockpit = sourceCockpitId and V56_findCockpit("bruiser", sourceCockpitId)
		local cockpitPrice = cockpit and V56_number(cockpit, "Price", 0) or 0
		return math.max(1000, math.floor(cockpitPrice * 0.12))
	end

	local function V85_moduleLockedMessage(profile, module)
		local ownsSource, sourceCockpitId = V85_playerOwnsSourceCockpit(profile, module)
		if ownsSource then return nil end
		local cockpit = sourceCockpitId and V56_findCockpit(profile.CurrentCategory, sourceCockpitId)
		local cockpitName = cockpit and V56_string(cockpit, "DisplayName", sourceCockpitId) or sourceCockpitId or "the source cockpit"
		return "Buy " .. cockpitName .. " before buying this module family."
	end


	
	-- NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD
	local function V86_moduleEnginePosition(moduleModel)
		if not moduleModel then return "" end
		local explicit = tostring(moduleModel:GetAttribute("EnginePosition") or "")
		if explicit == "Front" or explicit == "Rear" then
			return explicit
		end
		local moduleFolder = V56_string(moduleModel, "ModuleFolder", "")
		local moduleId = tostring(moduleModel:GetAttribute("ModuleId") or moduleModel.Name or "")
		local displayName = string.lower(tostring(moduleModel:GetAttribute("DisplayName") or moduleModel.Name or ""))
		if moduleModel:GetAttribute("RearEngine") == true then
			return "Rear"
		end
		if moduleFolder == "Engines_B" then
			return "Rear"
		end
		if string.find(moduleId, "ENGINE_B", 1, true) ~= nil then
			return "Rear"
		end
		if string.find(displayName, "rear", 1, true) ~= nil then
			return "Rear"
		end
		if moduleFolder == "Engines" then
			return "Front"
		end
		return ""
	end

	-- NTR_PERSISTENCE_PHASE17_STARTUP_DEPENDENCY_REPAIR_MODULE_TYPES
	local function V56_moduleTypeFromText(text)
		text = string.lower(tostring(text or ""))
		if string.find(text, "engine", 1, true) then return "Engine" end
		if string.find(text, "boost", 1, true) then return "Boost" end
		if string.find(text, "stabiliser", 1, true) or string.find(text, "stabilizer", 1, true) then return "Stabilisers" end
		if string.find(text, "front", 1, true) and string.find(text, "bumper", 1, true) then return "FrontBumper" end
		if string.find(text, "rear", 1, true) and string.find(text, "bumper", 1, true) then return "RearBumper" end
		if string.find(text, "spoiler", 1, true) then return "RearSpoiler" end
		if string.find(text, "side", 1, true) then return "SidePods" end
		return "Misc"
	end

	local function V56_moduleTypeForModel(module, root)
		if not module then return "Misc" end
		local attr = module:GetAttribute("ModuleType")
		if typeof(attr) == "string" and attr ~= "" then
			return attr
		end
		local text = module.Name
		local parent = module.Parent
		while parent and parent ~= root do
			text ..= " " .. parent.Name
			parent = parent.Parent
		end
		return V56_moduleTypeFromText(text)
	end

	local function V86_moduleFitsSlot(moduleModel, slotId, allowedModuleFolder)
		if not moduleModel then return false end
		local moduleFolder = V56_string(moduleModel, "ModuleFolder", "")
		local enginePosition = V86_moduleEnginePosition(moduleModel)
		if slotId == "Engine1" then
			return enginePosition ~= "Rear"
		end
		if slotId == "Engine2" then
			return enginePosition == "Rear"
		end
		if allowedModuleFolder and allowedModuleFolder ~= "" then
			return moduleFolder == allowedModuleFolder
		end
		return true
	end

	
	-- NTR_PERSISTENCE_PHASE17_V84_FOUNDATION_REPAIR
	local V84_HttpService = game:GetService("HttpService")

	local function V84_generateId(prefix)
		local guid = string.gsub(V84_HttpService:GenerateGUID(false), "-", "")
		return tostring(prefix or "id") .. "_" .. string.sub(guid, 1, 12)
	end

	local function V84_countDictionary(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function V84_cloneDictionary(dictionary)
		local copy = {}
		for key, value in pairs(dictionary or {}) do
			if typeof(value) == "table" then
				copy[key] = V84_cloneDictionary(value)
			else
				copy[key] = value
			end
		end
		return copy
	end

	local function V84_nextDisplaySpaceKey(profile)
		profile.GarageDisplaySpaces = typeof(profile.GarageDisplaySpaces) == "table" and profile.GarageDisplaySpaces or {}
		local capacity = V82_profileGarageCapacity(profile)
		for index = 1, math.max(1, capacity) do
			local key = "Space" .. tostring(index)
			local space = profile.GarageDisplaySpaces[key]
			if typeof(space) ~= "table" or space.VehicleId == nil then
				profile.GarageDisplaySpaces[key] = typeof(space) == "table" and space or {}
				return key
			end
		end
		return "Space" .. tostring(V84_countDictionary(profile.GarageDisplaySpaces) + 1)
	end

	local function V84_assignDisplaySpace(profile, vehicleId)
		local key = V84_nextDisplaySpaceKey(profile)
		profile.GarageDisplaySpaces[key] = profile.GarageDisplaySpaces[key] or {}
		profile.GarageDisplaySpaces[key].VehicleId = vehicleId
	end

	local function V84_createVehicleInstance(profile, cockpitId, sourceName)
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		local cockpitInstanceId = V84_generateId("cockpit")
		local vehicleId = V84_generateId("vehicle")
		profile.OwnedCockpitInstances[cockpitInstanceId] = {
			TemplateId = cockpitId,
			VehicleId = vehicleId,
			AcquiredAtUnix = os.time(),
			Source = sourceName or "PersistencePhase14",
		}
		profile.Vehicles[vehicleId] = {
			DisplayName = tostring(cockpitId),
			CategoryId = profile.CurrentCategory or "bruiser",
			CockpitInstanceId = cockpitInstanceId,
			InstalledModules = {},
			CockpitColors = V84_cloneDictionary(profile.CockpitColors or {}),
			ThrustColor = profile.ThrustColor,
			Cosmetics = V101_CosmeticCatalog.DefaultState(),
			Source = sourceName or "PersistencePhase14",
		}
		V84_assignDisplaySpace(profile, vehicleId)
		return vehicleId, cockpitInstanceId
	end

	local function V84_ensureInstanceInventory(profile)
		-- NTR_GARAGE_MODULE_INVENTORY_SHAPE_ONLY_V1
		-- Creation is owned by explicit cockpit/module purchase paths, never reads or summaries.
		return V96_ModuleInventory.EnsureShape(profile)
	end

	-- NTR_PERSISTENCE_PHASE19_INSTANCE_COMPAT_SYNC
	-- NTR_PERSISTENCE_PHASE20_GARAGE_PROFILE_RUNTIME_EXTRACT
	local function V88_syncInstanceDataFromLegacy(profile)
		local result = V89_GarageProfileRuntime.SyncInstanceDataFromLegacy(profile, {
			GenerateId = V84_generateId,
			CloneDictionary = V84_cloneDictionary,
			EnsureInstanceInventory = V84_ensureInstanceInventory,
		})
		local syncCount = typeof(result) == "table" and tonumber(result.SyncCount) or 0
		local vehicleId = typeof(result) == "table" and result.VehicleId or nil
		local player = profile and profile._Player
		if player then
			player:SetAttribute("NTR_PersistencePhase19Synced", true)
			player:SetAttribute("NTR_PersistencePhase19VehicleId", tostring(vehicleId or ""))
			player:SetAttribute("NTR_PersistencePhase19ModuleSyncCount", syncCount or 0)
			player:SetAttribute("NTR_PersistencePhase20RuntimeModule", "GarageProfileRuntime")
			player:SetAttribute("NTR_PersistencePhase20VehicleId", tostring(vehicleId or ""))
			player:SetAttribute("NTR_PersistencePhase20ModuleSyncCount", syncCount or 0)
		end
		return syncCount or 0
	end

	-- NTR_PERSISTENCE_PHASE17_STARTUP_DEPENDENCY_REPAIR_DEFAULT_MODULES
	local function V76_defaultModuleIdsForCockpit(cockpit)
		if not cockpit then return {} end
		return {
			Engine = V56_string(cockpit, "DefaultEngineModuleId", nil),
			RearEngine = V56_string(cockpit, "DefaultRearEngineModuleId", V56_string(cockpit, "DefaultEngineBModuleId", nil)),
			Stabilisers = V56_string(cockpit, "DefaultStabilisersModuleId", V56_string(cockpit, "DefaultStabiliserModuleId", nil)),
			Boost = V56_string(cockpit, "DefaultBoostModuleId", nil),
		}
	end

	local function V76_grantDefaultModulesForCurrentCockpit(profile)
		if not profile then return end
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local defaults = V76_defaultModuleIdsForCockpit(cockpit)
		profile.OwnedModules = typeof(profile.OwnedModules) == "table" and profile.OwnedModules or {}
		profile.InstalledModules = typeof(profile.InstalledModules) == "table" and profile.InstalledModules or {}
		for _, moduleId in pairs(defaults) do
			if moduleId and moduleId ~= "" and V56_findModule(profile.CurrentCategory, moduleId) then
				profile.OwnedModules[moduleId] = true
			end
		end
		if defaults.Engine and defaults.Engine ~= "" then
			profile.InstalledModules.Engine1 = profile.InstalledModules.Engine1 or defaults.Engine
		end
		if defaults.RearEngine and defaults.RearEngine ~= "" then
			profile.InstalledModules.Engine2 = profile.InstalledModules.Engine2 or defaults.RearEngine
		elseif defaults.Engine and defaults.Engine ~= "" then
			profile.InstalledModules.Engine2 = profile.InstalledModules.Engine2 or defaults.Engine
		end
		if defaults.Stabilisers and defaults.Stabilisers ~= "" then
			profile.InstalledModules.Stabilisers = profile.InstalledModules.Stabilisers or defaults.Stabilisers
		end
		if defaults.Boost and defaults.Boost ~= "" then
			profile.InstalledModules.Boost = profile.InstalledModules.Boost or defaults.Boost
		end
	end

	local function V76_coreModulesEquipped(profile)
		local hasEngine, hasStabilisers, hasBoost = false, false, false
		for _, moduleId in pairs((profile and profile.InstalledModules) or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			local moduleType = module and module:GetAttribute("ModuleType")
			if moduleType == nil or moduleType == "" then
				local text = string.lower(tostring(moduleId or "") .. " " .. tostring(module and module.Name or ""))
				if string.find(text, "engine", 1, true) then
					moduleType = "Engine"
				elseif string.find(text, "stabiliser", 1, true) or string.find(text, "stabilizer", 1, true) then
					moduleType = "Stabilisers"
				elseif string.find(text, "boost", 1, true) then
					moduleType = "Boost"
				end
			end
			if moduleType == "Engine" then hasEngine = true end
			if moduleType == "Stabilisers" or moduleType == "Stabiliser" then hasStabilisers = true end
			if moduleType == "Boost" then hasBoost = true end
		end
		return hasEngine and hasStabilisers and hasBoost
	end
V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)
		if not profile then return end
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
		local vehicleId = profile.CurrentVehicleId
		local vehicle = vehicleId and profile.Vehicles and profile.Vehicles[vehicleId]
		if not vehicle then return end
		local cockpitInstance = profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local cockpitId = cockpitInstance and cockpitInstance.TemplateId or profile.CurrentCockpit
		local cockpit = V56_findCockpit(vehicle.CategoryId or profile.CurrentCategory, cockpitId)
		local defaults = V76_defaultModuleIdsForCockpit(cockpit)
		local slotDefaults = {
			Engine1 = defaults.Engine,
			Engine2 = defaults.RearEngine,
			Stabilisers = defaults.Stabilisers,
			Boost = defaults.Boost,
		}
		vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}
		profile.OwnedModules = profile.OwnedModules or {}
		profile.InstalledModules = profile.InstalledModules or {}
		for slotId, moduleId in pairs(slotDefaults) do
			if moduleId and V56_findModule(profile.CurrentCategory, moduleId) and not vehicle.InstalledModules[slotId] then
				local moduleInstanceId = V84_generateId("module")
				profile.OwnedModules[moduleId] = true
				profile.OwnedModuleInstances[moduleInstanceId] = {
					TemplateId = moduleId,
					EquippedVehicleId = vehicleId,
					UpgradeLevels = V84_cloneDictionary((profile.ModuleUpgradeLevels or {})[moduleId] or {}),
					Colors = V84_cloneDictionary(profile.CockpitColors or {}),
					NeonOwned = false,
					Source = "IncludedWithCockpit",
					AcquisitionKind = "IncludedWithCockpit",
					GrantedForVehicleId = tostring(vehicleId),
					AcquiredAtUnix = os.time(),
				}
				vehicle.InstalledModules[slotId] = moduleInstanceId
			end
			if vehicleId == profile.CurrentVehicleId and moduleId then
				profile.InstalledModules[slotId] = moduleId
			end
		end
	end
	local function V84_buyCockpitInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		-- NTR_GARAGE_CANONICAL_CATEGORY_PURCHASE
		local requestedCategory = tostring(args.CategoryId or profile.CurrentCategory or "")
		if requestedCategory ~= "" then profile.CurrentCategory = requestedCategory end
		local cockpitId = tostring(args.CockpitId or "")
		local cockpit = V56_findCockpit(profile.CurrentCategory, cockpitId)
		if not cockpit then
			return false, "Cockpit not found."
		end
		V84_ensureInstanceInventory(profile)
		if V84_countDictionary(profile.Vehicles) >= V82_profileGarageCapacity(profile) then
			return false, "Garage full. Buy more garage space to store more vehicles."
		end
		local price = V56_number(cockpit, "Price", 0)
		if profile.Cash < price then
			return false, "Not enough cash."
		end
		profile.Cash -= price
		profile.CurrentCockpit = cockpitId
		profile.OwnedCockpits[cockpitId] = true
		V76_applyDefaultCockpitColors(profile)
		local vehicleId = V84_createVehicleInstance(profile, cockpitId, "BuyCockpitInstance")
		profile.CurrentVehicleId = vehicleId
		V76_grantDefaultModulesForCurrentCockpit(profile)
						V85_attachDefaultModuleInstancesToCurrentVehicle(profile)
		V84_ensureInstanceInventory(profile)
		return true, "Cockpit instance purchased."
	end

	-- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1
	local function V98_vehicleModuleContext(profile, vehicleId, slotId)
		local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId)]
		if typeof(vehicle)~="table" then return nil,nil,nil,"Vehicle instance not found." end
		local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local cockpit=cockpitInstance and V56_findCockpit(vehicle.CategoryId or profile.CurrentCategory,tostring(cockpitInstance.TemplateId or ""))
		local mount=cockpit and cockpit:FindFirstChild("SLOT_"..tostring(slotId),true)
		if not cockpit then return vehicle,nil,nil,"Cockpit template not found." end
		if not mount then return vehicle,cockpit,nil,"Slot not found on this cockpit." end
		return vehicle,cockpit,mount
	end

	local function V98_instanceFits(profile,instance,vehicleId,slotId)
		local vehicle,_,mount,contextMessage=V98_vehicleModuleContext(profile,vehicleId,slotId); if not mount then return false,contextMessage end
		local module=V56_findModule(vehicle.CategoryId or profile.CurrentCategory,tostring(instance and instance.TemplateId or "")); if not module then return false,"Module template not found." end
		local slotType=V56_string(mount,"ModuleType",V56_moduleTypeFromText(slotId)); local moduleType=V56_moduleTypeForModel(module)
		if slotType and slotType~="" and moduleType~=slotType then return false,"That module does not fit this slot." end
		if not V86_moduleFitsSlot(module,slotId,V56_string(mount,"AllowedModuleFolder","")) then return false,"That module does not fit this slot." end
		return true
	end

	local function V98_instanceRating(profile,instance,vehicleId)
		for _,key in ipairs({"Rating","PerformanceRating","PerformanceIndex","ModuleRating"}) do local value=tonumber(instance and instance[key]); if value then return value end end
		local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId or "")]; local categoryId=vehicle and vehicle.CategoryId or profile.CurrentCategory
		local module=V56_findModule(categoryId,tostring(instance and instance.TemplateId or "")); if not module then return math.huge end
		for _,key in ipairs({"Rating","PerformanceRating","PerformanceIndex","ModuleRating"}) do local value=V56_number(module,key,nil); if value then return value end end
		local sourceId,cockpit=V85_findSourceCockpit(profile,module); local sourceRating=cockpit and (V56_number(cockpit,"BaseRating",nil) or V56_number(cockpit,"PerformanceIndex",nil) or V56_number(cockpit,"Rating",nil))
		if not sourceRating then local tier=string.upper(tostring(cockpit and cockpit:GetAttribute("Tier") or "")); sourceRating=({E=1000,D=2000,C=3000,B=4000,A=5000,S=6000})[tier] or (sourceId and 7000 or 0) end
		return sourceRating+V85_moduleVariantOrder(module)
	end

	local function V98_coreSlotRequired(profile,vehicleId,slotId)
		if slotId=="Stabilisers" or slotId=="Boost" then return true end
		if slotId=="Engine1" or slotId=="Engine2" then
			local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId)]; local other=slotId=="Engine1" and "Engine2" or "Engine1"
			return not (vehicle and vehicle.InstalledModules and vehicle.InstalledModules[other])
		end
		return false
	end

	local function V98_afterModuleTransaction(profile)
		local current=profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; profile.InstalledModules={}
		for slotId,instanceId in pairs((current and current.InstalledModules) or {}) do local instance=profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]; if typeof(instance)=="table" then profile.InstalledModules[slotId]=tostring(instance.TemplateId or "") end end
		return V97_ModuleInstances.HydrateAll(profile)
	end

	local function V98_transactionHooks(profile)
		return {
			Fits=function(instance,vehicleId,slotId) return V98_instanceFits(profile,instance,vehicleId,slotId) end,
			Rating=function(instance,vehicleId) return V98_instanceRating(profile,instance,vehicleId) end,
			IsCoreSlot=V98_coreSlotRequired,
			After=V98_afterModuleTransaction,
			Validate=function(value) return V97_ModuleInstances.Validate(value) end,
		}
	end

	local function V98_captureCurrentModuleState(profile)
		return V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(profile._Player))
	end

	local function V84_buyModuleInstance(profile,args)
		args=typeof(args)=="table" and args or {}; V84_ensureInstanceInventory(profile)
		local moduleId=tostring(args.ModuleId or ""); local vehicleId=tostring(args.VehicleId or profile.CurrentVehicleId or ""); local slotId=tostring(args.SlotId or "")
		local module=V56_findModule(profile.CurrentCategory,moduleId); if not module then return false,"Module not found." end
		local lockMessage=V85_moduleLockedMessage(profile,module); if lockMessage then return false,lockMessage end
		local fits,fitMessage=V98_instanceFits(profile,{TemplateId=moduleId},vehicleId,slotId); if not fits then return false,fitMessage end
		local captured,captureMessage=V98_captureCurrentModuleState(profile); if not captured then return false,captureMessage end
		local moduleInstanceId=V84_generateId("module")
		local record={TemplateId=moduleId,EquippedVehicleId=nil,UpgradeLevels={},V2UpgradePoints={},Colors={},NeonOwned=false,Source="BuyModuleInstance",AcquisitionKind="Purchase",AcquiredAtUnix=os.time()}
		return V98_ModuleTransactions.BuyAndEquip(profile,{InstanceId=moduleInstanceId,Record=record,Price=V85_modulePurchasePrice(module),VehicleId=vehicleId,SlotId=slotId},V98_transactionHooks(profile))
	end

	local function V84_equipModuleInstance(profile,args)
		args=typeof(args)=="table" and args or {}; V84_ensureInstanceInventory(profile)
		local captured,captureMessage=V98_captureCurrentModuleState(profile); if not captured then return false,captureMessage end
		return V98_ModuleTransactions.Equip(profile,{InstanceId=tostring(args.ModuleInstanceId or ""),VehicleId=tostring(args.VehicleId or profile.CurrentVehicleId or ""),SlotId=tostring(args.SlotId or ""),AllowReassign=args.AllowReassign==true},V98_transactionHooks(profile))
	end

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE2_OWNED_ZONE
	local function V89_syncLegacyFromCurrentVehicle(profile)
		V84_ensureInstanceInventory(profile)
		local vehicleId = profile.CurrentVehicleId
		local vehicle = vehicleId and profile.Vehicles and profile.Vehicles[vehicleId]
		if typeof(vehicle) ~= "table" then
			return false, "Vehicle instance not found."
		end
		local cockpitInstance = vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		if typeof(cockpitInstance) ~= "table" then
			return false, "Cockpit instance not found."
		end
		local cockpitId = tostring(cockpitInstance.TemplateId or "")
		if cockpitId == "" then
			return false, "Cockpit template missing."
		end
		profile.CurrentCategory = tostring(vehicle.CategoryId or profile.CurrentCategory or "bruiser")
		profile.CurrentCockpit = cockpitId
		profile.OwnedCockpits = typeof(profile.OwnedCockpits) == "table" and profile.OwnedCockpits or {}
		profile.OwnedCockpits[cockpitId] = true
		profile.CockpitColors = V84_cloneDictionary(vehicle.CockpitColors or profile.CockpitColors or {})
		profile.ThrustColor = vehicle.ThrustColor or profile.ThrustColor
		profile.InstalledModules = {}
		profile.ModuleColors = {}
		profile.NeonOwned = {}
		for slotId, moduleInstanceId in pairs(vehicle.InstalledModules or {}) do
			local moduleInstance = profile.OwnedModuleInstances and profile.OwnedModuleInstances[moduleInstanceId]
			if typeof(moduleInstance) == "table" and moduleInstance.TemplateId then
				profile.InstalledModules[slotId] = tostring(moduleInstance.TemplateId)
				profile.ModuleColors[slotId] = V84_cloneDictionary(moduleInstance.Colors or {})
				profile.NeonOwned[slotId] = moduleInstance.NeonOwned == true
			end
		end
		local hydrated,hydrateMessage,repairedColours=V97_ModuleInstances.HydrateAll(profile); if not hydrated then return false,hydrateMessage end
		return true, "Vehicle selected.", tonumber(repairedColours) or 0
	end

	local function V89_selectVehicleInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		V84_ensureInstanceInventory(profile)
		local requestedVehicleId = tostring(args.VehicleId or "")
		local requestedCockpitId = tostring(args.CockpitId or "")
		local selectedVehicleId = nil
		if requestedVehicleId ~= "" and profile.Vehicles[requestedVehicleId] then
			selectedVehicleId = requestedVehicleId
		elseif requestedCockpitId ~= "" then
			for vehicleId, vehicle in pairs(profile.Vehicles or {}) do
				local cockpitInstance = vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
				if typeof(cockpitInstance) == "table" and tostring(cockpitInstance.TemplateId or "") == requestedCockpitId then
					selectedVehicleId = vehicleId
					break
				end
			end
		end
		if not selectedVehicleId then
			return false, "Owned vehicle not found."
		end
		profile.CurrentVehicleId = selectedVehicleId
		local ok, message, repairedColours = V89_syncLegacyFromCurrentVehicle(profile)
		if ok then
			V85_attachDefaultModuleInstancesToCurrentVehicle(profile)
			local resynced,resyncMessage,resyncRepairs=V89_syncLegacyFromCurrentVehicle(profile)
			if not resynced then return false,resyncMessage,tonumber(repairedColours) or 0 end
			repairedColours=(tonumber(repairedColours) or 0)+(tonumber(resyncRepairs) or 0)
		end
		return ok, message, repairedColours
	end

	-- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
	local function V102_ensureCustomisationAccess(player,profile)
		V84_ensureInstanceInventory(profile)
		local owned,ownedLookup={},{}
		for vehicleId,vehicle in pairs(profile.Vehicles or {}) do
			local cockpitInstance=typeof(vehicle)=="table" and vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
			if typeof(cockpitInstance)=="table" and tostring(cockpitInstance.TemplateId or "")~="" then
				local id=tostring(vehicleId); table.insert(owned,id); ownedLookup[id]=true
			end
		end
		table.sort(owned)
		if #owned==0 then return {Success=false,Message="OWN A VEHICLE TO CUSTOMISE",OwnedVehicleCount=0} end
		local current=tostring(profile.CurrentVehicleId or "")
		local stale=current=="" or ownedLookup[current]~=true
		local ok,message,repairedColours
		if stale then
			ok,message,repairedColours=V89_selectVehicleInstance(profile,{VehicleId=owned[1]})
		else
			ok,message,repairedColours=V89_syncLegacyFromCurrentVehicle(profile)
		end
		if not ok then return {Success=false,Message=message or "Owned vehicle selection could not be repaired.",OwnedVehicleCount=#owned} end
		local valid,validationMessage=V97_ModuleInstances.Validate(profile)
		if not valid then return {Success=false,Message="Owned vehicle state is invalid: "..tostring(validationMessage),OwnedVehicleCount=#owned} end
		if stale or (tonumber(repairedColours) or 0)>0 then
			V80_mirrorLegacyProfileToPersistence(player,profile,"EnsureCustomisationAccess",true)
		end
		return {
			Success=true,
			Message=stale and "Owned vehicle selection repaired." or "Customisation access ready.",
			OwnedVehicleCount=#owned,
			VehicleId=profile.CurrentVehicleId,
			SelectionRepaired=stale,
			PhysicalColourChannelsRepaired=tonumber(repairedColours) or 0,
		}
	end

	local V102_accessBinding=script.Parent:FindFirstChild("GarageCustomisationAccessBinding") or Instance.new("BindableFunction")
	V102_accessBinding.Name="GarageCustomisationAccessBinding"
	V102_accessBinding.Parent=script.Parent
	V102_accessBinding.OnInvoke=function(player)
		local ok,result=pcall(function()
			local profile=V56_getProfile(player); profile._Player=player
			return V102_ensureCustomisationAccess(player,profile)
		end)
		if ok and typeof(result)=="table" then return result end
		warn("[NTR Customisation Access] binding failed: "..tostring(result))
		return {Success=false,Message="Customisation access is unavailable."}
	end

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_INSTANCE_CARDS
	local function V90_cloneForSummary(value)
		if typeof(value) == "table" then
			local copy = {}
			for key, child in pairs(value) do
				copy[key] = V90_cloneForSummary(child)
			end
			return copy
		end
		return value
	end

	local function V90_restoreProfileSelection(profile, snapshot)
		profile.CurrentVehicleId = snapshot.CurrentVehicleId
		profile.CurrentCategory = snapshot.CurrentCategory
		profile.CurrentCockpit = snapshot.CurrentCockpit
		profile.CockpitColors = V90_cloneForSummary(snapshot.CockpitColors)
		profile.ThrustColor = snapshot.ThrustColor
		profile.InstalledModules = V90_cloneForSummary(snapshot.InstalledModules)
		profile.ModuleColors = V90_cloneForSummary(snapshot.ModuleColors)
		profile.NeonOwned = V90_cloneForSummary(snapshot.NeonOwned)
	end

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_SUMMARY_REPAIR
	local function V90_numberAttribute(instance, name, fallback)
		local value = instance and instance:GetAttribute(name)
		return typeof(value) == "number" and value or fallback
	end

	local function V90_addModuleStats(totals, module)
		if not module then return totals end
		for _, name in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostForce", "EngineOutput", "LateralGrip", "SteeringResponse", "HoverStability", "DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostDuration", "BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce" }) do
			local value = module:GetAttribute(name)
			if typeof(value) == "number" then
				totals[name] = (totals[name] or 0) + value
			end
			local delta = module:GetAttribute("PerformanceDelta_" .. name)
			if typeof(delta) == "number" then
				totals[name] = (totals[name] or 0) + delta
			end
		end
		return totals
	end

	local function V90_summaryTotals(profile)
		-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE4_RATING_BADGE_BUILD_MODULES
		if typeof(V56_totalStats) == "function" then
			return V56_totalStats(profile)
		end
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = V90_numberAttribute(cockpit, "TopSpeed", V90_numberAttribute(cockpit, "MaxSpeed", 126)),
			Acceleration = V90_numberAttribute(cockpit, "Acceleration", 42),
			Handling = V90_numberAttribute(cockpit, "Handling", 48),
			Drift = V90_numberAttribute(cockpit, "Drift", 46),
			Braking = V90_numberAttribute(cockpit, "Braking", 44),
			Weight = V90_numberAttribute(cockpit, "Weight", 118),
			Boost = V90_numberAttribute(cockpit, "Boost", 0),
			BoostDuration = V90_numberAttribute(cockpit, "BoostDuration", 2),
			BoostRecharge = V90_numberAttribute(cockpit, "BoostRecharge", 9),
			BoostRechargeDelay = V90_numberAttribute(cockpit, "BoostRechargeDelay", 0),
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			if module then
				for _, stat in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostDuration", "BoostRecharge", "BoostRechargeDelay" }) do
					totals[stat] = (totals[stat] or 0) + V90_numberAttribute(module, stat, 0)
				end
			end
		end
		local category = V56_categoryFolder(profile.CurrentCategory)
		local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
		if upgradeRoot then
			for upgradeId, level in pairs(profile.UpgradeLevels or {}) do
				local upgrade = upgradeRoot:FindFirstChild("UPGRADE_" .. tostring(upgradeId))
				if upgrade then
					local statName = V56_string(upgrade, "StatName", V56_string(upgrade, "Stat", nil))
					local amount = V56_number(upgrade, "AmountPerLevel", V56_number(upgrade, "Amount", 0))
					if statName then
						totals[statName] = (totals[statName] or 0) + amount * (tonumber(level) or 0)
					end
				end
			end
		end
		return totals
	end

	local function V90_vehicleSummaries(profile,summaryPlayer)
		V84_ensureInstanceInventory(profile)
		local snapshot = {
			CurrentVehicleId = profile.CurrentVehicleId,
			CurrentCategory = profile.CurrentCategory,
			CurrentCockpit = profile.CurrentCockpit,
			CockpitColors = V90_cloneForSummary(profile.CockpitColors or {}),
			ThrustColor = profile.ThrustColor,
			InstalledModules = V90_cloneForSummary(profile.InstalledModules or {}),
			ModuleColors = V90_cloneForSummary(profile.ModuleColors or {}),
			NeonOwned = V90_cloneForSummary(profile.NeonOwned or {}),
		}
		local summaries = {}
		for vehicleId, vehicle in pairs(profile.Vehicles or {}) do
			if typeof(vehicle) == "table" then
				profile.CurrentVehicleId = vehicleId
				local ok = V89_syncLegacyFromCurrentVehicle(profile)
				if ok then
					local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
					local performance = V77_ModuleUpgrades.CalculateProfile(
						summaryPlayer or profile._Player,
						profile,
						V90_summaryTotals(profile),
						cockpit,
						V56_findModule,
						V56_moduleTypeForModel
					)
					summaries[vehicleId] = {
						VehicleId = vehicleId,
						CockpitId = profile.CurrentCockpit,
						DisplayName = vehicle.DisplayName or profile.CurrentCockpit,
						Overall = performance and performance.Overall or nil,
						-- NTR_GARAGE_REPLACEMENT_HEADLINE_SUMMARY_V1
						Headline = performance and performance.Headline or nil,
					}
				end
			end
		end
		V90_restoreProfileSelection(profile, snapshot)
		return summaries
	end

	-- NTR_PERSISTENCE_PHASE17_TOTAL_STATS_REPAIR
	-- NTR_PERSISTENCE_PHASE17_CATALOG_REPAIR
	local function V56_defaultSlots(cockpit)
		local slots = {}
		local root = cockpit and cockpit:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
		if root then
			for _, slot in ipairs(root:GetChildren()) do
				if slot:IsA("Folder") or slot:IsA("Model") or slot:IsA("BasePart") then
					local slotId = string.gsub(slot.Name, "^SLOT_", "")
					table.insert(slots, {
						SlotId = V56_string(slot, "SlotId", slotId),
						DisplayName = V56_string(slot, "DisplayName", slotId),
						ModuleType = V56_string(slot, "ModuleType", V56_moduleTypeFromText(slotId)),
						AllowedModuleFolder = V56_string(slot, "AllowedModuleFolder", ""),
						EnginePosition = V56_string(slot, "EnginePosition", ""),
						Order = V56_number(slot, "Order", #slots + 1),
					})
				end
			end
		end
		if #slots == 0 then
			slots = {
				{ SlotId = "Engine1", DisplayName = "Front Engine", ModuleType = "Engine", AllowedModuleFolder = "Engines", EnginePosition = "Front", Order = 1 },
				{ SlotId = "Engine2", DisplayName = "Rear Engine", ModuleType = "Engine", AllowedModuleFolder = "Engines_B", EnginePosition = "Rear", Order = 2 },
				{ SlotId = "Stabilisers", DisplayName = "Stabilisers", ModuleType = "Stabilisers", Order = 3 },
				{ SlotId = "Boost", DisplayName = "Boost", ModuleType = "Boost", Order = 4 },
				{ SlotId = "FrontBumper", DisplayName = "Front Bumper", ModuleType = "FrontBumper", Order = 5 },
				{ SlotId = "RearBumper", DisplayName = "Rear Bumper", ModuleType = "RearBumper", Order = 6 },
				{ SlotId = "RearSpoiler", DisplayName = "Rear Spoiler", ModuleType = "RearSpoiler", Order = 7 },
				{ SlotId = "SidePods", DisplayName = "Side Pods", ModuleType = "SidePods", Order = 8 },
			}
		end
		table.sort(slots, function(a, b)
			return (tonumber(a.Order) or 99) < (tonumber(b.Order) or 99)
		end)
		return slots
	end

	local function V56_nearestModuleFolder(root, item)
		local current = item and item.Parent
		local best = ""
		while current and current ~= root do
			if current:IsA("Folder") then
				best = current.Name
			end
			current = current.Parent
		end
		return best
	end

	local function V56_moduleCatalogVisible(item)
		if item:GetAttribute("RetiredFromCatalog") == true then
			return false
		end
		if item:GetAttribute("HiddenFromCatalog") == true then
			return false
		end
		if item:GetAttribute("CatalogVisible") == false then
			return false
		end
		return true
	end

	local function V56_readModule(item, root)
		-- NTR_CUSTOMISATION_NEON_CAPABILITY_PROJECTION_V1
		local moduleType = V56_moduleTypeForModel(item, root)
		local moduleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item))
		local enginePosition = V56_string(item, "EnginePosition", "")
		local rearEngine = item:GetAttribute("RearEngine") == true
		if enginePosition == "" then
			if rearEngine or moduleFolder == "Engines_B" or string.find(tostring(item:GetAttribute("ModuleId") or item.Name or ""), "ENGINE_B", 1, true) then
				enginePosition = "Rear"
			elseif moduleFolder == "Engines" then
				enginePosition = "Front"
			end
		end
		local neonAvailable=false
		local neonFolder=item:FindFirstChild("NEON_OptionalLights",true)
		if neonFolder then
			for _,descendant in ipairs(neonFolder:GetDescendants()) do
				if descendant:IsA("BasePart") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") or descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
					neonAvailable=true
					break
				end
			end
		end
		return {
			ModuleId = V56_string(item, "ModuleId", item.Name),
			DisplayName = V56_string(item, "DisplayName", V56_string(item, "ModuleName", item.Name)),
			ModuleType = moduleType,
			ModuleSlot = V56_string(item, "ModuleSlot", moduleType),
			ModuleFolder = moduleFolder,
			EnginePosition = enginePosition,
			RearEngine = rearEngine or enginePosition == "Rear",
			SourceCockpitId = V85_moduleSourceCockpitId(item),
			SourceCockpitDisplayName = (select(2, V85_findSourceCockpit(nil, item)) and V56_string(select(2, V85_findSourceCockpit(nil, item)), "DisplayName", V85_moduleSourceCockpitId(item))) or V85_moduleSourceCockpitId(item),
			VariantName = V85_moduleVariantName(item),
			VariantOrder = V85_moduleVariantOrder(item),
			Price = V85_modulePurchasePrice(item),
			NeonAvailable = neonAvailable,
			NeonPrice = math.max(0, V56_number(item, "NeonPrice", 5000)),
			Power = V56_number(item, "Power", 0),
			Weight = V56_number(item, "Weight", 0),
			TopSpeed = V56_number(item, "TopSpeed", 0),
			Acceleration = V56_number(item, "Acceleration", 0),
			Handling = V56_number(item, "Handling", 0),
			Drift = V56_number(item, "Drift", 0),
			Braking = V56_number(item, "Braking", 0),
			Boost = V56_number(item, "Boost", 0),
			BoostDuration = V56_number(item, "BoostDuration", 0),
			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			BoostRechargeDelay = V56_number(item, "BoostRechargeDelay", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType, item),
		}
	end
	local function V56_catalog()
		local catalog = {
			Categories = {},
			PaintPresets = {},
			VehicleCosmetics = V101_CosmeticCatalog.List(),
			PreviewPosition = V56_PREVIEW_POS,
		}
		local presetRoot = V56_kit:FindFirstChild("Config")
			and V56_kit.Config:FindFirstChild("UI")
			and V56_kit.Config.UI:FindFirstChild("PaintPresets")
		if presetRoot then
			for _, preset in ipairs(presetRoot:GetChildren()) do
				if preset:IsA("Color3Value") then
					table.insert(catalog.PaintPresets, { Name = preset.Name, Color = preset.Value })
				end
			end
		end
		if #catalog.PaintPresets == 0 then
			catalog.PaintPresets = {
				{ Name = "Cyan", Color = Color3.fromRGB(0, 205, 230) },
				{ Name = "White", Color = Color3.fromRGB(252, 250, 255) },
				{ Name = "Graphite", Color = Color3.fromRGB(38, 44, 50) },
				{ Name = "Lime", Color = Color3.fromRGB(172, 255, 197) },
				{ Name = "Red", Color = Color3.fromRGB(225, 56, 70) },
				{ Name = "Amber", Color = Color3.fromRGB(255, 187, 45) },
				{ Name = "Violet", Color = Color3.fromRGB(160, 90, 255) },
				{ Name = "Bone", Color = Color3.fromRGB(235, 247, 204) },
			}
		end

		for _, categoryFolder in ipairs(V56_categoriesRoot:GetChildren()) do
			if categoryFolder:IsA("Folder") or categoryFolder:IsA("Model") then
				local category = V56_primitiveAttributes(categoryFolder)
				category.CategoryId = category.CategoryId or V56_slug(categoryFolder.Name)
				category.DisplayName = category.DisplayName or categoryFolder.Name
				category.Cockpits = {}
				category.Slots = {}
				category.Modules = {}
				category.Upgrades = {}

				local cockpitRoot = categoryFolder:FindFirstChild("COCKPITS_ReplaceAssetsHere") or categoryFolder:FindFirstChild("Cockpits") or categoryFolder:FindFirstChild("COCKPITS")
				local firstCockpit
				if cockpitRoot then
					for _, cockpit in ipairs(cockpitRoot:GetDescendants()) do
						if cockpit:IsA("Model") and cockpit:GetAttribute("CockpitId") then
							firstCockpit = firstCockpit or cockpit
							local item = V56_primitiveAttributes(cockpit)
							item.CockpitId = item.CockpitId or cockpit.Name
							item.DisplayName = item.DisplayName or cockpit.Name
							item.Price = V56_number(cockpit, "Price", 0)
							item.TopSpeed = V56_number(cockpit, "TopSpeed", V56_number(cockpit, "MaxSpeed", 126))
							item.Acceleration = V56_number(cockpit, "Acceleration", 42)
							item.Handling = V56_number(cockpit, "Handling", 48)
							item.Drift = V56_number(cockpit, "Drift", 46)
							item.Braking = V56_number(cockpit, "Braking", 44)
							item.Weight = V56_number(cockpit, "Weight", 118)
							item.Boost = V56_number(cockpit, "Boost", 0)
							table.insert(category.Cockpits, item)
						end
					end
				end
				category.Slots = V56_defaultSlots(firstCockpit)

				local moduleRoot = categoryFolder:FindFirstChild("MODULES_InterchangeableWithinCategory")
				if moduleRoot then
					for _, module in ipairs(moduleRoot:GetDescendants()) do
						if module:IsA("Model") and module:GetAttribute("ModuleId") and V56_moduleCatalogVisible(module) then
							local item = V56_readModule(module, moduleRoot)
							category.Modules[item.ModuleType] = category.Modules[item.ModuleType] or {}
							table.insert(category.Modules[item.ModuleType], item)
						end
					end
				end
				local upgradeRoot = categoryFolder:FindFirstChild("UPGRADES_InvisiblePerformance")
				if upgradeRoot then
					for _, upgrade in ipairs(upgradeRoot:GetChildren()) do
						table.insert(category.Upgrades, V56_primitiveAttributes(upgrade))
					end
				end
				table.sort(category.Cockpits, function(a, b)
					return tostring(a.DisplayName) < tostring(b.DisplayName)
				end)
				if #category.Cockpits > 0 then
					table.insert(catalog.Categories, category)
				end
			end
		end
		table.sort(catalog.Categories, function(a, b)
			return tostring(a.DisplayName) < tostring(b.DisplayName)
		end)
		return catalog
	end

	local function V56_totalStats(profile)
		V56_normalizeProfile(profile)
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = V56_number(cockpit, "TopSpeed", V56_number(cockpit, "MaxSpeed", 126)),
			Acceleration = V56_number(cockpit, "Acceleration", 42),
			Handling = V56_number(cockpit, "Handling", 48),
			Drift = V56_number(cockpit, "Drift", 46),
			Braking = V56_number(cockpit, "Braking", 44),
			Weight = V56_number(cockpit, "Weight", 118),
			Boost = V56_number(cockpit, "Boost", 0),
			BoostDuration = V56_number(cockpit, "BoostDuration", 2),
			BoostRecharge = V56_number(cockpit, "BoostRecharge", 9),
			BoostRechargeDelay = V56_number(cockpit, "BoostRechargeDelay", 0),
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
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			if module then
				for _, stat in ipairs(statNames) do
					totals[stat] = (totals[stat] or 0) + V56_number(module, stat, 0)
				end
			end
		end
		local category = V56_categoryFolder(profile.CurrentCategory)
		local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
		if upgradeRoot then
			for upgradeId, level in pairs(profile.UpgradeLevels or {}) do
				local upgrade = upgradeRoot:FindFirstChild("UPGRADE_" .. tostring(upgradeId))
				if upgrade then
					local statName = V56_string(upgrade, "StatName", V56_string(upgrade, "Stat", nil))
					local amount = V56_number(upgrade, "AmountPerLevel", V56_number(upgrade, "Amount", 0))
					if statName then
						totals[statName] = (totals[statName] or 0) + amount * (tonumber(level) or 0)
					end
				end
			end
		end
		return totals
	end

	local function V56_profileForClient(profile)
		V56_normalizeProfile(profile)
		V101_VehicleCosmetics.Ensure(profile)
		return {
			Cash = profile.Cash,
			CurrentCategory = profile.CurrentCategory,
			CurrentCockpit = profile.CurrentCockpit,
			CurrentVehicleId = profile.CurrentVehicleId,
			Vehicles = profile.Vehicles,
			OwnedCockpitInstances = profile.OwnedCockpitInstances,
			OwnedModuleInstances = profile.OwnedModuleInstances,
			VehicleSummaries = V90_vehicleSummaries(profile),
			OwnedCockpits = profile.OwnedCockpits,
			CockpitColors = profile.CockpitColors,
			ThrustColor = profile.ThrustColor,
			OwnedModules = profile.OwnedModules,
			InstalledModules = profile.InstalledModules,
			ModuleColors = profile.ModuleColors,
			NeonOwned = profile.NeonOwned,
			UpgradeLevels = profile.UpgradeLevels,
			Garage = {
				Capacity = V82_profileGarageCapacity(profile),
				MaxCapacity = V82_maxGarageCapacity(),
				NextCapacityUpgradePrice = V83_nextGaragePropertyPrice(profile) or V82_capacityUpgradePrice(profile),
				NextGaragePropertyPrice = V83_nextGaragePropertyPrice(profile),
				OwnedVehicleCount = V81_ownedCockpitCount(profile),
				OwnedGarageProperties = V83_ownedGarageProperties(profile),
			},
			ModuleUpgradeLevels = V77_ModuleUpgrades.GetLevels(profile._Player),
			Performance = V77_ModuleUpgrades.CalculateProfile(
				profile._Player,
				profile,
				V56_totalStats(profile),
				V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit),
				V56_findModule,
				V56_moduleTypeForModel
			),
			TotalStats = V56_totalStats(profile),
		}
	end

	local function V56_resolvePaintChannel(object)
		local current = object
		while current do
			if current.Name == "PRIMARY_ReplaceWithPrimaryMeshes" then return "Primary" end
			if current.Name == "SECONDARY_ReplaceWithSecondaryMeshes" then return "Secondary" end
			if current.Name == "DETAIL_ReplaceWithDetailMeshes" then return "Detail" end
			if current.Name == "NEON_OptionalLights" then return "Neon" end
			if current.Name == "THRUST_COLOR_WhiteByDefault" then return "ThrustColor" end
			current = current.Parent
		end
		current = object
		while current do
			local attr = current:GetAttribute("PaintChannel")
			if typeof(attr) == "string" and attr ~= "" then return attr end
			current = current.Parent
		end
	end

	local function V56_pathHas(object, text)
		text = string.lower(text)
		local current = object
		while current do
			if string.find(string.lower(current.Name), text, 1, true) then return true end
			current = current.Parent
		end
		return false
	end

	local function V56_applyColors(model, colors, neonVisible)
		colors = colors or {}
		for _, object in ipairs(model:GetDescendants()) do
			if object:IsA("BasePart") then
				local channel = V56_resolvePaintChannel(object)
				if object:GetAttribute("TemplateRole") == "FixedSlotMount" then
					object.Transparency = 1
					object.CanCollide = false
					object.CanQuery = false
					object.CanTouch = false
				elseif channel == "ThrustColor" then
					object.Color = colors.ThrustColor or Color3.fromRGB(255, 255, 255)
					object.Material = Enum.Material.Neon
					object.Transparency = 0
				elseif channel == "Neon" then
					local colour = colors.Neon or Color3.fromRGB(255, 255, 255)
					if V56_pathHas(object, "cockpit") then
						if V56_pathHas(object, "front") then colour = colors.FrontLights or Color3.fromRGB(252, 250, 255) end
						if V56_pathHas(object, "rear") or V56_pathHas(object, "back") then colour = colors.RearLights or Color3.fromRGB(255, 116, 116) end
					end
					object.Color = colour
					object.Material = Enum.Material.Neon
					object.Transparency = neonVisible and 0 or 1
				elseif channel == "Primary" then
					object.Color = colors.Primary or object.Color
				elseif channel == "Secondary" then
					object.Color = colors.Secondary or object.Color
				elseif channel == "Detail" then
					object.Color = colors.Detail or object.Color
				end
			elseif object:IsA("ParticleEmitter") then
				local lower = string.lower(object.Name)
				if string.find(lower, "fire", 1, true) then
					object.Color = ColorSequence.new(colors.ThrustColor or Color3.fromRGB(255, 255, 255))
				end
			elseif object:IsA("SpotLight") then
				local channel = object:GetAttribute("LightChannel")
				if object:GetAttribute("NTRCockpitLightSystem") == "PhaseAE_RootOnly" then
					if channel == "FrontLights" then
						object.Color = colors.FrontLights or Color3.fromRGB(252, 250, 255)
					elseif channel == "RearLights" then
						object.Color = colors.RearLights or Color3.fromRGB(255, 116, 116)
					end
					object.Enabled = true
					object.Shadows = false
				end
			elseif object:IsA("SpotLight") then
				local channel = object:GetAttribute("LightChannel")
				if object:GetAttribute("RootCockpitSpotLight") == true or channel == "FrontLights" or channel == "RearLights" then
					if channel == "FrontLights" then
						object.Color = colors.FrontLights or Color3.fromRGB(252, 250, 255)
					elseif channel == "RearLights" then
						object.Color = colors.RearLights or Color3.fromRGB(255, 116, 116)
					end
					object.Shadows = false
				end
			end
		end
	end

	local function V56_clearPlayerVehicle(player)
		for _, vehicle in ipairs(V56_vehiclesRoot:GetChildren()) do
			if vehicle:GetAttribute("OwnerUserId") == player.UserId then vehicle:Destroy() end
		end
	end

	local function V56_getSlotMount(vehicle, slotId)
		local slotRoot = vehicle and vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
		local slot = slotRoot and slotRoot:FindFirstChild("SLOT_" .. tostring(slotId), true)
		return slot and slot:FindFirstChild("Mount_DoNotRename")
	end

	local function V56_pivotModuleToSlot(moduleClone, mount)
		local root = moduleClone.PrimaryPart or moduleClone:FindFirstChild("ModuleRoot_DoNotRename", true)
		if root then moduleClone.PrimaryPart = root end
		local moduleAttachment = moduleClone:FindFirstChild("MountAttachment", true)
		local mountAttachment = mount and mount:FindFirstChild("MountAttachment")
		if moduleAttachment and mountAttachment then
			moduleClone:PivotTo(mountAttachment.WorldCFrame * moduleAttachment.CFrame:Inverse())
		elseif mount then
			moduleClone:PivotTo(mount.CFrame)
		end
	end

	local function V56_partAlreadyRootWelded(part, root)
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("WeldConstraint") then
				local part0 = child.Part0
				local part1 = child.Part1
				if (part0 == root and part1 == part) or (part0 == part and part1 == root) then
					return true
				end
			end
		end
		return false
	end

	local function V56_weldVehicle(model, root)
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				-- Skip cockpit spotlight lens parts: they already have PhaseAB_CockpitLightLensRootWeld
				-- and a second V56_FixedVehicleWeld would cause duplicate-constraint jitter.
				if descendant:GetAttribute("TemplateRole") == "CockpitSpotLightLens" then
					descendant.Anchored = false
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.Massless = true
					continue
				end
				descendant.Anchored = false
				descendant.CanCollide = descendant == root
				descendant.CanQuery = false
				if descendant ~= root then
					descendant.Massless = true
					if not V56_partAlreadyRootWelded(descendant, root) then
						local weld = Instance.new("WeldConstraint")
						weld.Name = "V56_FixedVehicleWeld"
						weld.Part0 = root
						weld.Part1 = descendant
						weld.Parent = descendant
					end
				end
			end
		end
	end

	local function V56_makeDriverSeat(vehicle, root)
		local seat = vehicle:FindFirstChild("DriverSeat", true)
		if seat and seat:IsA("VehicleSeat") then
			seat.Transparency = 1
			seat.CanCollide = false
			seat.CanQuery = false
			seat.CanTouch = false
			seat.Massless = true
			return seat
		end
		seat = Instance.new("VehicleSeat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2.2, 0.45, 2.2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CanQuery = false
		seat.CanTouch = false
		seat.Massless = true
		seat.Anchored = false
		seat.CFrame = root.CFrame * CFrame.new(0, 2.2, 8)
		seat.Parent = vehicle
		local weld = Instance.new("WeldConstraint")
		weld.Name = "DriverSeatWeld"
		weld.Part0 = root
		weld.Part1 = seat
		weld.Parent = seat
		return seat
	end

	local function V56_seatPlayer(player, vehicle, seat)
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		if root then pcall(function() root:SetNetworkOwner(player) end) end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRoot and seat then humanoidRoot.CFrame = seat.CFrame + Vector3.new(0, 2, 0) end
		if humanoid and seat then
			task.wait(0.08)
			seat:Sit(humanoid)
		end
	end

	local function V56_folderHasBuyableNeon(folder)
		if not folder then return false end
		for _, descendant in ipairs(folder:GetDescendants()) do
			if descendant:IsA("BasePart") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") or descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then return true end
		end
		return false
	end

	local function V56_buildVehicle(player, profile, spawnCFrameOverride)
		V56_normalizeProfile(profile)
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		if not cockpit then return nil, "Cockpit template not found." end
		V56_clearPlayerVehicle(player)
		local vehicle = cockpit:Clone()
		vehicle.Name = player.Name .. "_FixedSlotHovercar"
		vehicle:SetAttribute("OwnerUserId", player.UserId)
		vehicle:SetAttribute("CategoryId", profile.CurrentCategory)
		vehicle:SetAttribute("CockpitId", profile.CurrentCockpit)
		vehicle:SetAttribute("ThrustColor", profile.ThrustColor)
		vehicle:SetAttribute("HoverHeight", math.clamp(require(V56_kit.Shared.Modules.Common:WaitForChild("DriveTuning")).Read().HoverHeightStuds, 0.5, 8)) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_ATTRIBUTE_V1
		vehicle:SetAttribute("DriveReady", true)
		vehicle:SetAttribute("DriverUserId", player.UserId)
		vehicle.Parent = V56_vehiclesRoot
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		if not root then vehicle:Destroy(); return nil, "CockpitRoot_DoNotRename missing." end
		vehicle.PrimaryPart = root
		V56_applyColors(vehicle, profile.CockpitColors, true)
		local cosmeticVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]
		V101_CosmeticCatalog.ApplyPresentation(vehicle,cosmeticVehicle)

		local installedRoot = vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") or Instance.new("Folder")
		installedRoot.Name = "INSTALLED_MODULES_Runtime"
		installedRoot.Parent = vehicle
		installedRoot:ClearAllChildren()

		for slotId, moduleId in pairs(profile.InstalledModules or {}) do
			local moduleTemplate = V56_findModule(profile.CurrentCategory, moduleId)
			local mount = V56_getSlotMount(vehicle, slotId)
			if moduleTemplate and mount then
				local moduleClone = moduleTemplate:Clone()
				moduleClone.Name = "INSTALLED_" .. tostring(slotId) .. "_" .. moduleTemplate.Name
				moduleClone:SetAttribute("InstalledSlotId", slotId)
				V77_ModuleUpgrades.ApplyToClone(player, moduleTemplate, moduleClone, V56_moduleTypeForModel)
				moduleClone.Parent = installedRoot
				V56_pivotModuleToSlot(moduleClone, mount)
				local moduleColors = profile.ModuleColors[slotId] or {
					Primary = profile.CockpitColors.Primary,
					Secondary = profile.CockpitColors.Secondary,
					Detail = profile.CockpitColors.Detail,
					Neon = Color3.fromRGB(255, 255, 255),
					ThrustColor = profile.ThrustColor,
				}
				moduleColors.ThrustColor = profile.ThrustColor
				V56_applyColors(moduleClone, moduleColors, profile.NeonOwned[slotId] == true)
			end
		end

		local totals = V56_totalStats(profile)
		for stat, value in pairs(totals) do vehicle:SetAttribute(stat, value) end
		local runtime = vehicle:FindFirstChild("TOTAL_STATS_Runtime") or Instance.new("Folder")
		runtime.Name = "TOTAL_STATS_Runtime"
		runtime.Parent = vehicle
		runtime:ClearAllChildren()
		for stat, value in pairs(totals) do
			local v = Instance.new("NumberValue")
			v.Name = stat
			v.Value = value
			v.Parent = runtime
		end

		local seat = V56_makeDriverSeat(vehicle, root)
		V56_weldVehicle(vehicle, root)
		vehicle:PivotTo(spawnCFrameOverride or V56_spawnCFrame())
		V56_seatPlayer(player, vehicle, seat)
		return vehicle
	end

	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_SERVER
	local V91_lastFreeRoamSpawnByUserId = {}
	local V91_ROAD_SPAWN_TAG = "NTR_RoadSpawnPoint"
	local V91_ROAD_GREY = Vector3.new(95, 95, 95)

	local function V91_spawnConfigRoot()
		local config = V56_kit:FindFirstChild("Config")
		local runtime = config and config:FindFirstChild("Runtime")
		return runtime and runtime:FindFirstChild("FreeRoamVehicleSpawn")
	end

	local function V91_configNumber(name, fallback)
		local root = V91_spawnConfigRoot()
		local item = root and root:FindFirstChild(name)
		if item and item:IsA("NumberValue") then
			return item.Value
		end
		return fallback
	end

	local function V91_configBool(name, fallback)
		local root = V91_spawnConfigRoot()
		local item = root and root:FindFirstChild(name)
		if item and item:IsA("BoolValue") then
			return item.Value
		end
		return fallback
	end

	local function V91_playerVehicle(player)
		for _, candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then
				return candidate
			end
		end
		return nil
	end

	local function V91_rootPart(model)
		if not model then
			return nil
		end
		return model.PrimaryPart or model:FindFirstChild("CockpitRoot_DoNotRename", true)
	end

	local function V91_playerSpeedMph(player)
		local studsToMph = V91_configNumber("StudsPerSecondToMph", 0.625)
		local vehicleRoot = V91_rootPart(V91_playerVehicle(player))
		if vehicleRoot and vehicleRoot:IsA("BasePart") then
			return vehicleRoot.AssemblyLinearVelocity.Magnitude * studsToMph
		end
		local character = player.Character
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRoot and humanoidRoot:IsA("BasePart") then
			return humanoidRoot.AssemblyLinearVelocity.Magnitude * studsToMph
		end
		return 0
	end


	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_SPEED_GATE_DRIVING_ONLY
	local function V94_playerIsDrivingOwnedVehicle(player)
		local vehicle = V91_playerVehicle(player)
		if not vehicle then return false end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		return seat ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
	end
	local function V91_requestPosition(player)
		if V94_playerIsDrivingOwnedVehicle(player) then
			local vehicleRoot = V91_rootPart(V91_playerVehicle(player))
			if vehicleRoot and vehicleRoot:IsA("BasePart") then
				return vehicleRoot.Position
			end
		end
		local character = player.Character
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRoot and humanoidRoot:IsA("BasePart") then
			return humanoidRoot.Position
		end
		return V56_FALLBACK_SPAWN_POS
	end

	local function V91_colorRgb(color)
		return Vector3.new(math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end

	local function V91_isAllowedRoadPart(part)
		local lower = string.lower(part.Name)
		if lower == "road" then
			local rgb = V91_colorRgb(part.Color)
			return math.abs(rgb.X - V91_ROAD_GREY.X) <= 3
				and math.abs(rgb.Y - V91_ROAD_GREY.Y) <= 3
				and math.abs(rgb.Z - V91_ROAD_GREY.Z) <= 3
		end
		return string.find(lower, "road marking", 1, true) ~= nil
	end

	local function V91_markerEnabled(marker)
		if marker:GetAttribute("SpawnEnabled") == false then
			return false
		end
		if marker:GetAttribute("Disabled") == true then
			return false
		end
		return true
	end

	local function V91_markerSpawnCFrame(marker)
		local heightOffset = V91_configNumber("SpawnHeightOffset", 4)
		local position = marker.Position + Vector3.new(0, heightOffset, 0)
		return CFrame.lookAt(position, position + marker.CFrame.LookVector)
	end

	local function V91_spawnIsClear(player, spawnCFrame)
		local clearanceRadius = V91_configNumber("SpawnClearanceRadius", 16)
		local querySize = Vector3.new(clearanceRadius * 2, 10, clearanceRadius * 2)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excludes = { V56_vehiclesRoot }
		if player.Character then
			table.insert(excludes, player.Character)
		end
		local spawnPoints = V56_world:FindFirstChild("SpawnPoints")
		local roadMarkers = spawnPoints and spawnPoints:FindFirstChild("RoadSpawnMarkers")
		if roadMarkers then
			table.insert(excludes, roadMarkers)
		end
		params.FilterDescendantsInstances = excludes

		local parts = Workspace:GetPartBoundsInBox(spawnCFrame, querySize, params)
		for _, part in ipairs(parts) do
			if part:IsA("BasePart") and part.CanCollide and not V91_isAllowedRoadPart(part) then
				return false, part:GetFullName()
			end
		end
		return true, nil
	end

	local function V91_nearestRoadSpawnCFrame(player)
		local origin = V91_requestPosition(player)
		local radius = V91_configNumber("RoadSearchRadius", 350)
		local markers = {}
		for _, marker in ipairs(CollectionService:GetTagged(V91_ROAD_SPAWN_TAG)) do
			if marker:IsA("BasePart") and marker:IsDescendantOf(Workspace) and V91_markerEnabled(marker) then
				local offset = marker.Position - origin
				local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if flatDistance <= radius then
					table.insert(markers, { Marker = marker, Distance = flatDistance })
				end
			end
		end
		table.sort(markers, function(a, b)
			return a.Distance < b.Distance
		end)
		for _, entry in ipairs(markers) do
			local cf = V91_markerSpawnCFrame(entry.Marker)
			local clear = V91_spawnIsClear(player, cf)
			if clear then
				return cf, entry.Marker
			end
		end
		if V91_configBool("AllowFallbackToPlayerOffset", false) then
			local position = origin + Vector3.new(0, V91_configNumber("SpawnHeightOffset", 4), 0)
			return CFrame.lookAt(position, position + Vector3.new(0, 0, -1)), nil
		end
		return nil, nil
	end

	local function V91_spawnOwnedVehicleFromFreeRoam(player, profile, args)
		args = typeof(args) == "table" and args or {}
		local now = os.clock()
		local cooldown = V91_configNumber("SpawnCooldownSeconds", 1)
		local last = V91_lastFreeRoamSpawnByUserId[player.UserId] or 0
		if now - last < cooldown then
			return false, "Spawn is cooling down."
		end

		local maxSpeed = V91_configNumber("MaxSpawnSpeedMph", 10)
		if V94_playerIsDrivingOwnedVehicle(player) then
			local speedMph = V91_playerSpeedMph(player)
			if speedMph > maxSpeed then
				return false, "Slow below " .. tostring(math.floor(maxSpeed + 0.5)) .. " MPH to spawn."
			end
		end

		local okSelect, selectMessage = V89_selectVehicleInstance(profile, args)
		if not okSelect then
			return false, selectMessage
		end
		if not V76_coreModulesEquipped(profile) then
			return false, "Equip at least one engine, stabilisers, and boost before driving."
		end

		local spawnCFrame, marker = V91_nearestRoadSpawnCFrame(player)
		if not spawnCFrame then
			return false, "No clear road spawn nearby."
		end

		V91_lastFreeRoamSpawnByUserId[player.UserId] = now
		local vehicle, err = V56_buildVehicle(player, profile, spawnCFrame)
		if not vehicle then
			return false, err or "Vehicle spawn failed."
		end
		if marker then
			vehicle:SetAttribute("FreeRoamSpawnMarker", marker:GetFullName())
		end
		return true, "Vehicle spawned."
	end


	-- NTR_RACING_PHASE11C_GRID_VEHICLE_BINDING
	local function V95_selectedRaceVehicleReady(profile, args)
		args = typeof(args) == "table" and args or {}
		local okSelect, selectMessage = V89_selectVehicleInstance(profile, {
			VehicleId = args.VehicleId,
			CockpitId = args.CockpitId,
		})
		if not okSelect then
			return false, selectMessage
		end
		if not V76_coreModulesEquipped(profile) then
			return false, "Equip at least one engine, stabilisers, and boost before racing."
		end
		return true, "Vehicle ready."
	end

	local function V95_spawnOwnedVehicleForRace(player, profile, args)
		args = typeof(args) == "table" and args or {}
		local spawnCFrame = args.SpawnCFrame
		if typeof(spawnCFrame) ~= "CFrame" then
			return { Ok = false, Success = false, Message = "Race spawn CFrame missing." }
		end
		local okReady, readyMessage = V95_selectedRaceVehicleReady(profile, args)
		if not okReady then
			return { Ok = false, Success = false, Message = readyMessage }
		end
		local vehicle, err = V56_buildVehicle(player, profile, spawnCFrame)
		if not vehicle then
			return { Ok = false, Success = false, Message = err or "Race vehicle spawn failed." }
		end
		vehicle:SetAttribute("NTR_RaceGridSpawned", true)
		vehicle:SetAttribute("DriveReady", false)
		return {
			Ok = true,
			Success = true,
			Message = "Race vehicle spawned.",
			Vehicle = vehicle,
			VehicleId = tostring(profile.CurrentVehicleId or ""),
		}
	end

	local function V95_ensureRaceVehicleSpawnBinding()
		local binding = script:FindFirstChild("RaceVehicleSpawner")
		if binding and not binding:IsA("BindableFunction") then
			binding:Destroy()
			binding = nil
		end
		if not binding then
			binding = Instance.new("BindableFunction")
			binding.Name = "RaceVehicleSpawner"
			binding.Parent = script
		end
		binding.OnInvoke = function(action, payload)
			payload = typeof(payload) == "table" and payload or {}
			local player = payload.Player
			if not (player and player:IsA("Player")) then
				return { Ok = false, Success = false, Message = "Player missing." }
			end
			local profile = V56_getProfile(player)
			if action == "ValidateForRace" then
				local okReady, readyMessage = V95_selectedRaceVehicleReady(profile, payload)
				if okReady then
					-- NTR_GARAGE_LEGACY_TO_INSTANCE_SYNC_RETIRED_V1
					V80_mirrorLegacyProfileToPersistence(player, profile, "SelectVehicleInstance", false)
				end
				return {
					Ok = okReady == true,
					Success = okReady == true,
					Message = readyMessage,
					VehicleId = tostring(profile.CurrentVehicleId or ""),
				}
			elseif action == "SpawnForRace" then
				local result = V95_spawnOwnedVehicleForRace(player, profile, payload)
				if result.Ok == true then
					-- NTR_GARAGE_LEGACY_TO_INSTANCE_SYNC_RETIRED_V1
					V80_mirrorLegacyProfileToPersistence(player, profile, "SpawnRaceVehicle", false)
				end
				return result
			end
			return { Ok = false, Success = false, Message = "Unknown race vehicle action." }
		end
	end
	V95_ensureRaceVehicleSpawnBinding()
	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_SERVER
	local function V92_playerVehicle(player)
		for _, candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then
				return candidate
			end
		end
		return nil
	end

	-- NTR_VEHICLE_FIXED_PARKING_AND_RIGHT_EXIT_V1
	-- NTR_VEHICLE_SPEED_SENSITIVE_EXIT_COAST_V1_1
	local function V102_vehicleInteractionSettings()
		local editable=V56_kit:FindFirstChild("Config") and V56_kit.Config:FindFirstChild("Editable")
		local balance=editable and editable:FindFirstChild("01_GAME_BALANCE_Editable")
		return balance and balance:FindFirstChild("VehicleInteractions")
	end

	local function V92_vehicleExitCFrame(vehicle)
		if not vehicle then return nil end
		local basis=vehicle:FindFirstChild("DriverSeat",true)
		if not (basis and basis:IsA("BasePart")) then
			basis=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		end
		if not (basis and basis:IsA("BasePart")) then return nil end
		local settings=V102_vehicleInteractionSettings()
		local right=math.clamp(V56_number(settings,"ExitRightStuds",6),3,12)
		local up=math.clamp(V56_number(settings,"ExitUpStuds",2.5),1,6)
		return basis.CFrame*CFrame.new(right,up,0)
	end

	local function V92_unseatAndMovePlayer(player, vehicle)
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local exitCFrame=V92_vehicleExitCFrame(vehicle)
		if humanoid then humanoid.Sit=false end
		if character and exitCFrame then
			character:PivotTo(exitCFrame)
			local humanoidRoot=character:FindFirstChild("HumanoidRootPart")
			if humanoidRoot then
				humanoidRoot.AssemblyLinearVelocity=Vector3.zero
				humanoidRoot.AssemblyAngularVelocity=Vector3.zero
			end
		end
	end

	local function V102_fixParkedVehicle(vehicle)
		local root=vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true))
		if not (root and root:IsA("BasePart")) then return false end
		vehicle.PrimaryPart=root
		pcall(function() root:SetNetworkOwner(nil) end)
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		root.Anchored=true
		vehicle:SetAttribute("NTR_ExitCoasting",nil)
		vehicle:SetAttribute("NTR_ExitCoastStartedAt",nil)
		vehicle:SetAttribute("NTR_ExitCoastStopReason","Immediate")
		vehicle:SetAttribute("NTR_ParkedFixed",true)
		return true
	end

	local function V102_beginExitCoast(player,vehicle,root,linearVelocity,angularVelocity)
		root.Anchored=false
		vehicle:SetAttribute("NTR_ParkedFixed",nil)
		vehicle:SetAttribute("NTR_ExitCoasting",true)
		vehicle:SetAttribute("NTR_ExitCoastStartedAt",Workspace:GetServerTimeNow())
		vehicle:SetAttribute("NTR_ExitCoastStopReason",nil)
		V92_unseatAndMovePlayer(player,vehicle)
		if root.Parent then
			root.AssemblyLinearVelocity=linearVelocity
			root.AssemblyAngularVelocity=angularVelocity
			pcall(function() root:SetNetworkOwner(player) end)
		end
	end

	local function V56_exitVehicle(player)
		local vehicle=V92_playerVehicle(player)
		if not vehicle then return false,"No vehicle to exit." end
		if vehicle:GetAttribute("NTR_RaceParticipant")==true or vehicle:GetAttribute("NTR_RaceRunId")~=nil then
			return false,"Use the race exit while participating in a race."
		end
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local seat=humanoid and humanoid.SeatPart
		if not (seat and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)) then
			return false,"You are not seated in your vehicle."
		end
		local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		if not (root and root:IsA("BasePart")) then return false,"Vehicle root missing." end
		vehicle.PrimaryPart=root
		local linearVelocity=root.AssemblyLinearVelocity
		local angularVelocity=root.AssemblyAngularVelocity
		local horizontalVelocity=Vector3.new(linearVelocity.X,0,linearVelocity.Z)
		local settings=V102_vehicleInteractionSettings()
		local immediateParkMaxMph=math.clamp(V56_number(settings,"ExitImmediateParkMaxMph",10),0,50)
		local speedMph=horizontalVelocity.Magnitude*0.625

		vehicle:SetAttribute("DriveReady",true)
		vehicle:SetAttribute("DriverUserId",nil)
		vehicle:SetAttribute("ParkedShowcase",true)
		vehicle:SetAttribute("EngineVFXActive",true)

		if speedMph<=immediateParkMaxMph then
			if not V102_fixParkedVehicle(vehicle) then return false,"Vehicle could not be fixed." end
			V92_unseatAndMovePlayer(player,vehicle)
			return true,"Exited and parked vehicle."
		end

		V102_beginExitCoast(player,vehicle,root,linearVelocity,angularVelocity)
		return true,"Exited vehicle while it coasts to a stop."
	end


	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_DESPAWN_ONLY_MOVE_IF_SEATED
	local function V94_playerIsSeatedInVehicle(player, vehicle)
		if not vehicle then return false end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		return seat ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
	end
	local function V92_despawnVehicle(player,options)
		options=typeof(options)=="table" and options or {}; local vehicle=V92_playerVehicle(player)
		if not vehicle then return false,"No vehicle to despawn.",false end
		local character=player.Character; local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		if V94_playerIsSeatedInVehicle(player,vehicle) then
			if options.PreserveCharacterPosition==true then if humanoid then humanoid.Sit=false end else V92_unseatAndMovePlayer(player,vehicle) end
		elseif humanoid and humanoid.SeatPart and humanoid.SeatPart:IsDescendantOf(vehicle) then humanoid.Sit=false end
		vehicle:Destroy()
		local detached=true
		if options.WaitForDetach==true and humanoid then
			local deadline=os.clock()+math.clamp(tonumber(options.DetachTimeoutSeconds) or 1,.1,3)
			while humanoid.Parent and humanoid.SeatPart and os.clock()<deadline do task.wait() end
			detached=humanoid.SeatPart==nil
		end
		return true,detached and "Vehicle despawned." or "Vehicle removed but seat detachment was not confirmed.",detached
	end

	local function V56_reEnterVehicle(player)
		local vehicle
		for _,candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId")==player.UserId then vehicle=candidate break end
		end
		if not vehicle then return false,"No vehicle nearby." end
		if vehicle:GetAttribute("NTR_ExitCoasting")==true then return false,"Vehicle is still coasting." end -- NTR_VEHICLE_COAST_REENTRY_GUARD_V1_1
		local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		local seat=vehicle:FindFirstChild("DriverSeat",true)
		if not (root and root:IsA("BasePart")) then return false,"Vehicle root missing." end
		if not (seat and seat:IsA("VehicleSeat")) then return false,"Driver seat missing." end
		vehicle.PrimaryPart=root
		root.Anchored=false -- NTR_VEHICLE_FIXED_PARKING_AND_RIGHT_EXIT_V1
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		vehicle:SetAttribute("NTR_ExitCoasting",nil)
		vehicle:SetAttribute("NTR_ExitCoastStartedAt",nil)
		vehicle:SetAttribute("NTR_ExitCoastStopReason",nil)
		vehicle:SetAttribute("NTR_ParkedFixed",nil)
		vehicle:SetAttribute("ParkedShowcase",false)
		vehicle:SetAttribute("DriveReady",true)
		vehicle:SetAttribute("DriverUserId",player.UserId)
		pcall(function() root:SetNetworkOwner(player) end)
		V56_seatPlayer(player,vehicle,seat)
		return true,"Entered vehicle."
	end

	-- NTR_OWNED_GARAGE_PHASE6_LIFECYCLE_BRIDGE_V1
	-- NTR_OWNED_GARAGE_PHASE8_TRANSITION_DESPAWN_HANDSHAKE_V1
	local V100_ownedGarageLifecycle=script.Parent:WaitForChild("OwnedGarageVehicleLifecycleBridge")
	V100_ownedGarageLifecycle.OnInvoke=function(operation,payload)
		payload=typeof(payload)=="table" and payload or {}; local player=payload.Player
		if not (player and player:IsA("Player")) then return {Success=false,Message="Player is required."} end
		local profile=V56_getProfile(player)
		if operation=="GetDrivenVehicle" then
			local vehicle=V92_playerVehicle(player); if not (vehicle and V94_playerIsSeatedInVehicle(player,vehicle)) then return {Success=false,Message="No driven vehicle."} end
			local root=V91_rootPart(vehicle); local vehicleId=tostring(profile.CurrentVehicleId or ""); if vehicleId=="" then return {Success=false,Message="Driven vehicle identity is unavailable."} end
			return {Success=true,VehicleId=vehicleId,SpeedMph=V91_playerSpeedMph(player),VehicleCFrame=root and root.CFrame or nil}
		elseif operation=="DespawnForGarage" then
			local requested=tostring(payload.VehicleId or ""); if requested=="" or requested~=tostring(profile.CurrentVehicleId or "") then return {Success=false,Message="Driven vehicle identity changed."} end
			local ok,message,detached=V92_despawnVehicle(player,{PreserveCharacterPosition=payload.PreserveCharacterPosition==true,WaitForDetach=payload.WaitForDetach==true,DetachTimeoutSeconds=payload.DetachTimeoutSeconds}); return {Success=ok==true and detached~=false,VehicleRemoved=ok==true,Detached=detached~=false,Message=message}
		elseif operation=="SpawnFromGarage" then
			local vehicleId=tostring(payload.VehicleId or ""); local previousVehicleId=tostring(profile.CurrentVehicleId or ""); local selected,message=V89_selectVehicleInstance(profile,{VehicleId=vehicleId}); if not selected then return {Success=false,Message=message} end
			if not V76_coreModulesEquipped(profile) then if previousVehicleId~="" then V89_selectVehicleInstance(profile,{VehicleId=previousVehicleId}) end; return {Success=false,Message="Equip at least one engine, stabilisers, and boost before driving."} end
			local vehicle,buildMessage=V56_buildVehicle(player,profile,payload.SpawnCFrame); if not vehicle then if previousVehicleId~="" then V89_selectVehicleInstance(profile,{VehicleId=previousVehicleId}) end; return {Success=false,Message=buildMessage or "Vehicle spawn failed."} end
			V80_mirrorLegacyProfileToPersistence(player,profile,"OwnedGarageDriveOut",true); return {Success=true,Message="Vehicle spawned from garage.",Vehicle=vehicle,VehicleId=vehicleId}
		elseif operation=="GetOwnedGarageVehicleCards" then
			-- NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE
			-- NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE_V1_4_PLAYER_CONTEXT
			local summaries=V90_vehicleSummaries(profile,player); local cards={}; local displayed={}
			for garageId,property in pairs((profile.OwnedGarage and profile.OwnedGarage.Properties) or {}) do for slotId,vehicleId in pairs(property.DisplaySpaces or {}) do if vehicleId and vehicleId~=false and tostring(vehicleId)~="" then displayed[tostring(vehicleId)]={GarageId=tostring(garageId),SlotId=tostring(slotId)} end end end
			for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if typeof(vehicle)=="table" then
				local id=tostring(vehicleId); local summary=summaries[id] or summaries[vehicleId] or {}; local cockpitInstance=vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local cockpitId=tostring((cockpitInstance and cockpitInstance.TemplateId) or summary.CockpitId or vehicle.CockpitId or ""); local categoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "BRUISER"); local cockpit=V56_findCockpit(categoryId,cockpitId); local image=""
				for _,key in ipairs({"MenuImage","CockpitImage","ThumbnailImage","ImageId","Image"}) do local value=cockpit and cockpit:GetAttribute(key); if value~=nil and tostring(value)~="" then image=tostring(value); break end; local child=cockpit and cockpit:FindFirstChild(key); if child and child:IsA("StringValue") and child.Value~="" then image=child.Value; break end end
				local overall=summary.Overall or {}; local location=displayed[id]; table.insert(cards,{VehicleId=id,CockpitId=cockpitId,CategoryId=categoryId,DisplayName=tostring(cockpit and cockpit:GetAttribute("DisplayName") or summary.DisplayName or vehicle.DisplayName or cockpitId or id),Image=image,Tier=tostring(overall.Tier or "E"),Rating=math.floor(tonumber(overall.PerformanceIndex) or 0),DisplayedGarageId=location and location.GarageId or nil,DisplayedSlotId=location and location.SlotId or nil})
			end end
			return {Success=true,Vehicles=cards}
		end
		return {Success=false,Message="Unknown owned garage lifecycle operation."}
	end
	V100_ownedGarageLifecycle:SetAttribute("OwnedGarageLifecycleReady",true)

	V56_invoke.OnServerInvoke = function(player, action, args)
		args = typeof(args) == "table" and args or {}
		if player:GetAttribute("NTR_RaceQueueActive")==true and (action=="SelectVehicleInstance" or action=="SpawnOwnedVehicleFromFreeRoam" or action=="SpawnVehicle" or action=="DespawnVehicle") then return {Ok=false,Success=false,Message="Leave the race queue before changing vehicles."} end
		-- NTR_OWNED_GARAGE_PHASE5_EXTERNAL_ACTION_GUARD_V1
		if player:GetAttribute("NTR_OwnedGarageInside")==true and (action=="SelectVehicleInstance" or action=="SpawnOwnedVehicleFromFreeRoam" or action=="SpawnVehicle" or action=="DespawnVehicle" or action=="ExitVehicle" or action=="ReEnterVehicle") then return {Ok=false,Success=false,Message="Use the garage display spaces or exit door while inside your garage."} end
		local okCall, result = pcall(function()
			local profile = V56_getProfile(player)
			profile._Player = player
			V84_ensureInstanceInventory(profile) -- canonical shape only; no grants or migration
			-- NTR_GARAGE_MODULE_REFERENCE_RECONCILE_V1
			local referencesOk,referencesResult=V97_ModuleInstances.ReconcileReferences(profile)
			if not referencesOk then return {Success=false,Message="Module inventory reference repair failed: "..tostring(referencesResult),Profile=V56_profileForClient(profile)} end
			if tonumber(referencesResult) and referencesResult>0 then print("[NTR Module Instance Authority] Reconciled "..tostring(referencesResult).." stale owner flag(s) from canonical vehicle-slot references") end
			local ok, message
			if action == "EnsureCustomisationAccess" then
				return V102_ensureCustomisationAccess(player,profile)
			elseif action == "GetInitial" then
				-- NTR_PROFILE_SERVICE_READ_ONLY_IMPORT_GUARD_V1
				V56_setLeaderstats(player, profile)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }
			elseif action == "SelectVehicleInstance" then
				ok, message = V89_selectVehicleInstance(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyCockpitInstance" then
				ok, message = V84_buyCockpitInstance(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyModuleInstance" then
				ok, message = V84_buyModuleInstance(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "EquipModuleInstance" then
				ok, message = V84_equipModuleInstance(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyGarageProperty" then
				ok, message = V83_buyGarageProperty(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "UpgradeGarageCapacity" then
				ok, message = V82_upgradeGarageCapacity(profile)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyCockpit" then
				local cockpitId = tostring(args.CockpitId or "")
				local cockpit = V56_findCockpit(profile.CurrentCategory, cockpitId)
				if not cockpit then ok, message = false, "Cockpit not found." else
					local price = V56_number(cockpit, "Price", 0)
					local capacityOk, capacityMessage = V81_canBuyCockpit(profile, cockpitId)
					if not capacityOk then
						ok, message = false, capacityMessage
					elseif not profile.OwnedCockpits[cockpitId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							profile.Cash -= price
							profile.OwnedCockpits[cockpitId] = true
							ok, message = true, "Cockpit selected."
						end
					else ok, message = true, "Cockpit selected." end
					if ok then
						profile.CurrentCockpit = cockpitId
						V76_applyDefaultCockpitColors(profile)
						V76_grantDefaultModulesForCurrentCockpit(profile)
						V85_attachDefaultModuleInstancesToCurrentVehicle(profile)
					end
					V56_setLeaderstats(player, profile)
				end
			elseif action == "BuyVehicleCosmetic" then
				local cockpit=V56_findCockpit(profile.CurrentCategory,profile.CurrentCockpit)
				ok,message=V101_VehicleCosmetics.Purchase(profile,tostring(args.CosmeticId or ""),cockpit)
				V56_setLeaderstats(player,profile)
			elseif action == "SetVehicleCosmeticColor" then
				ok,message=V101_VehicleCosmetics.SetColour(profile,tostring(args.CosmeticId or ""),args.Color,function() return V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)) end)
			elseif action == "SetAllNeonColor" then
				ok,message=V101_VehicleCosmetics.SetAllNeon(profile,args.Color,function() return V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)) end)
			elseif action == "SetCockpitColor" then
				local channel = tostring(args.Channel or "Primary")
				local color = args.Color
				local scope = tostring(args.Scope or "WholeVehicle")
				if typeof(color) ~= "Color3" then ok, message = false, "Invalid colour."
				elseif channel ~= "Primary" and channel ~= "Secondary" and channel ~= "Detail" and channel ~= "Neon" and channel ~= "FrontLights" and channel ~= "RearLights" then ok, message = false, "Invalid colour channel."
				elseif scope ~= "WholeVehicle" and scope ~= "CockpitOnly" then ok, message = false, "Invalid cockpit colour scope."
				else
					local oldCockpitColors=V84_cloneDictionary(profile.CockpitColors or {})
					local oldModuleColors=V84_cloneDictionary(profile.ModuleColors or {})
					local oldModuleInstances=V84_cloneDictionary(profile.OwnedModuleInstances or {})
					local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]
					local oldVehicleCockpit=typeof(currentVehicle)=="table" and V84_cloneDictionary(currentVehicle.CockpitColors or {}) or nil
					profile.CockpitColors[channel] = color
					if typeof(currentVehicle)=="table" then currentVehicle.CockpitColors=V84_cloneDictionary(profile.CockpitColors) end
					if scope == "WholeVehicle" and (channel == "Primary" or channel == "Secondary" or channel == "Detail") then
						V76_syncInstalledModulePaintFromCockpit(profile, channel)
						local captured,captureMessage=V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player))
						if not captured then profile.CockpitColors=oldCockpitColors; profile.ModuleColors=oldModuleColors; profile.OwnedModuleInstances=oldModuleInstances; if typeof(currentVehicle)=="table" then currentVehicle.CockpitColors=oldVehicleCockpit end; ok,message=false,captureMessage else ok,message=true,"Vehicle colour updated." end
					else ok,message=true,"Cockpit colour updated." end
				end
				-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
			elseif action == "BuyModule" then
				local slotId = tostring(args.SlotId or "")
				local moduleId = tostring(args.ModuleId or "")
				local module = V56_findModule(profile.CurrentCategory, moduleId)
				local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
				local mount = cockpit and cockpit:FindFirstChild("SLOT_" .. slotId, true)
				local slotType = mount and V56_string(mount, "ModuleType", V56_moduleTypeFromText(slotId))
				local moduleType = V56_moduleTypeForModel(module)
				if not module then ok, message = false, "Module not found."
				elseif not mount then ok, message = false, "Slot not found on this cockpit."
				elseif slotType and slotType ~= "" and moduleType ~= slotType then ok, message = false, "That module does not fit this slot."
				elseif not V86_moduleFitsSlot(module, slotId, mount and V56_string(mount, "AllowedModuleFolder", "")) then ok, message = false, "That module does not fit this slot."
				else
					local lockMessage = V85_moduleLockedMessage(profile, module)
					if lockMessage then
						ok, message = false, lockMessage
					else
						local price = V85_modulePurchasePrice(module)
						if not profile.OwnedModules[moduleId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							profile.Cash -= price
							profile.OwnedModules[moduleId] = true
							ok, message = true, "Module installed."
						end
					else ok, message = true, "Module installed." end
					if ok then
						profile.InstalledModules[slotId] = moduleId
						profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {
							Primary = profile.CockpitColors.Primary,
							Secondary = profile.CockpitColors.Secondary,
							Detail = profile.CockpitColors.Detail,
							Neon = Color3.fromRGB(255, 255, 255),
							ThrustColor = profile.ThrustColor,
						}
						profile.ModuleColors[slotId].Neon = profile.ModuleColors[slotId].Neon or Color3.fromRGB(255, 255, 255)
						profile.ModuleColors[slotId].ThrustColor = profile.ThrustColor
					end
					end
					V56_setLeaderstats(player, profile)
				end
			elseif action == "SetModuleColor" then
				local slotId = tostring(args.SlotId or "")
				local channel = tostring(args.Channel or "Primary")
				local color = args.Color
				if typeof(color) ~= "Color3" then ok, message = false, "Invalid colour."
				elseif channel ~= "Primary" and channel ~= "Secondary" and channel ~= "Detail" and channel ~= "Neon" then ok, message = false, "Invalid channel."
				elseif slotId ~= "ALL" and not profile.InstalledModules[slotId] then ok, message = false, "No module selected."
				else
					if slotId == "ALL" then
						if channel ~= "Neon" then profile.CockpitColors[channel] = color end
						for installedSlot in pairs(profile.InstalledModules) do
							if channel ~= "Neon" or profile.NeonOwned[installedSlot] == true then -- NTR_CUSTOMISATION_BULK_NEON_OWNERSHIP_GUARD_V1
								profile.ModuleColors[installedSlot] = profile.ModuleColors[installedSlot] or {}
								profile.ModuleColors[installedSlot][channel] = color
							end
						end
					else
						profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
						profile.ModuleColors[slotId][channel] = color
					end
					ok, message = true, "Colour updated."
				end
				if ok then if slotId=="ALL" then ok,message=V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)) else ok,message=V97_ModuleInstances.CaptureSlot(profile,slotId,V77_ModuleUpgrades.GetLevels(player)) end end
			elseif action == "UpgradeModule" then
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
				if ok then local captured,captureMessage=V97_ModuleInstances.CaptureSlot(profile,tostring(args.SlotId or ""),V77_ModuleUpgrades.GetLevels(player)); if not captured then ok,message=false,captureMessage end end
			elseif action == "Upgrade" then
				local upgradeId = tostring(args.UpgradeId or "")
				local category = V56_categoryFolder(profile.CurrentCategory)
				local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
				local template = upgradeRoot and upgradeRoot:FindFirstChild("UPGRADE_" .. upgradeId)
				if not template then ok, message = false, "Upgrade not found." else
					local level = profile.UpgradeLevels[upgradeId] or 0
					local maxLevel = V56_number(template, "MaxLevel", 5)
					local price = V56_number(template, "PricePerLevel", 0) * (level + 1)
					if level >= maxLevel then ok, message = false, "Already max level."
					elseif profile.Cash < price then ok, message = false, "Not enough cash."
					else profile.Cash -= price; profile.UpgradeLevels[upgradeId] = level + 1; V56_setLeaderstats(player, profile); ok, message = true, "Upgrade installed." end
				end
			elseif action == "BuyNeon" then
				local slotId = tostring(args.SlotId or "")
				local moduleId = profile.InstalledModules[slotId]
				local module = moduleId and V56_findModule(profile.CurrentCategory, moduleId)
				if not module then ok, message = false, "Install that module first."
				elseif not V56_folderHasBuyableNeon(module:FindFirstChild("NEON_OptionalLights", true)) then ok, message = false, "This module has no optional neon."
				else
					local price = math.max(0, V56_number(module, "NeonPrice", 5000)) -- NTR_CUSTOMISATION_NEON_PRICE_GUARD_V1
					if not profile.NeonOwned[slotId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							profile.Cash -= price
							profile.NeonOwned[slotId] = true
							profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
							profile.ModuleColors[slotId].Neon = profile.ModuleColors[slotId].Neon or Color3.fromRGB(255, 255, 255)
							ok, message = true, "Neon unlocked."
						end
					else ok, message = true, "Neon already unlocked." end
					V56_setLeaderstats(player, profile)
				end
				if ok then local captured,captureMessage=V97_ModuleInstances.CaptureSlot(profile,slotId,V77_ModuleUpgrades.GetLevels(player)); if not captured then ok,message=false,captureMessage end end
			elseif action == "SetThrustColor" then
				-- Compatibility action remains gated by the vehicle-specific entitlement.
				ok,message=V101_VehicleCosmetics.SetColour(profile,"ThrustColour",args.Color,function() return V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)) end)
			elseif action == "DespawnVehicle" then
				ok, message = V92_despawnVehicle(player)
			elseif action == "ExitVehicle" then
				ok, message = V56_exitVehicle(player)
			elseif action == "ReEnterVehicle" then
				ok, message = V56_reEnterVehicle(player)
			elseif action == "SpawnOwnedVehicleFromFreeRoam" then
				ok, message = V91_spawnOwnedVehicleFromFreeRoam(player, profile, args)
			elseif action == "SpawnVehicle" then
				if not V76_coreModulesEquipped(profile) then
					ok, message = false, "Equip at least one engine, stabilisers, and boost before customising or driving."
				else
					local vehicle, err = V56_buildVehicle(player, profile)
					ok, message = vehicle ~= nil, err or "Vehicle spawned."
				end
			else
				ok, message = false, "Unknown garage action."
			end
			if ok == true then
				local validProfile,validationMessage=V97_ModuleInstances.Validate(profile); if not validProfile then error("Module instance invariant failed before persistence after "..tostring(action)..": "..tostring(validationMessage)) end
				-- NTR_GARAGE_LEGACY_TO_INSTANCE_SYNC_RETIRED_V1
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)
				if action=="BuyCockpitInstance" then
					local onboarding=game:GetService("ServerScriptService").NeoTokyoRacers.Services.Player:FindFirstChild("OnboardingProgress")
					if onboarding and onboarding:IsA("BindableEvent") then onboarding:Fire(player,"FirstVehiclePurchased") end
				end -- NTR_GARAGE_ONBOARDING_PURCHASE_BOUNDARY_V1

			end
			if action == "SetCockpitColor" or action == "SetModuleColor" or action == "SetThrustColor" or action == "SetVehicleCosmeticColor" or action == "SetAllNeonColor" then
				if args.ReturnProfile==true then return {Success=ok==true,Message=message,Profile=V56_profileForClient(profile)} end
				return { Success = ok == true, Message = message, ColorOnly = true }
			end
			return { Success = ok == true, Message = message, Profile = V56_profileForClient(profile) }
		end)
		if okCall and typeof(result) == "table" then return result end
		warn("[V56] Garage action failed: " .. tostring(result))
		local profile = V56_getProfile(player)
		return { Success = false, Message = "Garage server action failed: " .. tostring(result), Profile = V56_profileForClient(profile) }
	end

	Players.PlayerAdded:Connect(function(player)
		V56_setLeaderstats(player, V56_getProfile(player))
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		V56_setLeaderstats(player, V56_getProfile(player))
	end

	print("[V56] Consolidated server action controller is active.")
end
-- V56_CONSOLIDATED_ACTION_CONTROLLER_END
