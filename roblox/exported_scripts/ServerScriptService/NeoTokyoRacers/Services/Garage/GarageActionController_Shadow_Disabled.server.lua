-- Neo Tokyo Racers shadow server action controller.
-- Disabled switch candidate generated from the current V56 action block.
-- Do not enable while HOVER_RACING_V2_Server still owns GarageInvoke.OnServerInvoke.
-- Source hash: 3be69270

-- V56_CONSOLIDATED_ACTION_CONTROLLER_BEGIN
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

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
			OwnedCockpits = { bruiser_01 = true },
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
		profile.OwnedCockpits = profile.OwnedCockpits or { bruiser_01 = true }
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

	local function V56_getProfile(player)
		local profile = V56_profiles[player.UserId]
		if not profile then
			profile = V56_defaultProfile()
			V56_profiles[player.UserId] = profile
		end
		return V56_normalizeProfile(profile)
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
		SpawnVehicle = false,
		ExitVehicle = false,
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

	V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)	V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)
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

	local function V84_buyModuleInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		local moduleId = tostring(args.ModuleId or "")
		local module = V56_findModule(profile.CurrentCategory, moduleId)
		if not module then
			return false, "Module not found."
		end
		local lockMessage = V85_moduleLockedMessage(profile, module)
		if lockMessage then
			return false, lockMessage
		end
		local price = V85_modulePurchasePrice(module)
		if profile.Cash < price then
			return false, "Not enough cash."
		end
		profile.Cash -= price
		profile.OwnedModules[moduleId] = true
		local moduleInstanceId = V84_generateId("module")
		profile.OwnedModuleInstances[moduleInstanceId] = {
			TemplateId = moduleId,
			EquippedVehicleId = nil,
			UpgradeLevels = V84_cloneDictionary((profile.ModuleUpgradeLevels or {})[moduleId] or {}),
			Colors = {},
			NeonOwned = false,
			Source = "BuyModuleInstance",
		}
		return true, "Module instance purchased.", moduleInstanceId
	end

	local function V84_equipModuleInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		V84_ensureInstanceInventory(profile)
		local moduleInstanceId = tostring(args.ModuleInstanceId or "")
		local vehicleId = tostring(args.VehicleId or profile.CurrentVehicleId or "")
		local slotId = tostring(args.SlotId or "")
		local moduleInstance = profile.OwnedModuleInstances[moduleInstanceId]
		local vehicle = profile.Vehicles[vehicleId]
		if not moduleInstance then
			return false, "Module instance not found."
		end
		if not vehicle then
			return false, "Vehicle instance not found."
		end
		if moduleInstance.EquippedVehicleId ~= nil and moduleInstance.EquippedVehicleId ~= vehicleId then
			return false, "That module copy is already installed on another vehicle."
		end
		local module = V56_findModule(profile.CurrentCategory, tostring(moduleInstance.TemplateId or ""))
		local cockpitInstance = profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local cockpit = cockpitInstance and V56_findCockpit(vehicle.CategoryId or profile.CurrentCategory, cockpitInstance.TemplateId)
		local mount = cockpit and cockpit:FindFirstChild("SLOT_" .. slotId, true)
		local slotType = mount and V56_string(mount, "ModuleType", V56_moduleTypeFromText(slotId))
		local moduleType = V56_moduleTypeForModel(module)
		if not module then
			return false, "Module template not found."
		end
		if not mount then
			return false, "Slot not found on this cockpit."
		end
		if slotType and slotType ~= "" and moduleType ~= slotType then
			return false, "That module does not fit this slot."
		end
		if not V86_moduleFitsSlot(module, slotId, mount and V56_string(mount, "AllowedModuleFolder", "")) then
			return false, "That module does not fit this slot."
		end

		vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}
		local previousInstanceId = vehicle.InstalledModules[slotId]
		if previousInstanceId and profile.OwnedModuleInstances[previousInstanceId] then
			profile.OwnedModuleInstances[previousInstanceId].EquippedVehicleId = nil
		end
		vehicle.InstalledModules[slotId] = moduleInstanceId
		moduleInstance.EquippedVehicleId = vehicleId
		moduleInstance.Colors = typeof(moduleInstance.Colors) == "table" and moduleInstance.Colors or {}
		if vehicleId == profile.CurrentVehicleId then
			profile.InstalledModules[slotId] = moduleInstance.TemplateId
			profile.ModuleColors[slotId] = moduleInstance.Colors
		end
		return true, "Module instance equipped."
	end


	local function V56_profileForClient(profile)
		V56_normalizeProfile(profile)
		return {
			Cash = profile.Cash,
			CurrentCategory = profile.CurrentCategory,
			CurrentCockpit = profile.CurrentCockpit,
			CurrentVehicleId = profile.CurrentVehicleId,
			Vehicles = profile.Vehicles,
			OwnedCockpitInstances = profile.OwnedCockpitInstances,
			OwnedModuleInstances = profile.OwnedModuleInstances,
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
			seat.Massless = true
			return seat
		end
		seat = Instance.new("VehicleSeat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2.2, 0.45, 2.2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CanQuery = false
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

	local function V56_buildVehicle(player, profile)
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
		vehicle:SetAttribute("HoverHeight", 3)
		vehicle:SetAttribute("DriveReady", true)
		vehicle:SetAttribute("DriverUserId", player.UserId)
		vehicle.Parent = V56_vehiclesRoot
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		if not root then vehicle:Destroy(); return nil, "CockpitRoot_DoNotRename missing." end
		vehicle.PrimaryPart = root
		V56_applyColors(vehicle, profile.CockpitColors, true)

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
		vehicle:PivotTo(V56_spawnCFrame())
		V56_seatPlayer(player, vehicle, seat)
		return vehicle
	end

	local function V56_exitVehicle(player)
		local vehicle
		for _, candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then vehicle = candidate; break end
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
		if humanoid then humanoid.Sit = false end
		if humanoidRoot and root then humanoidRoot.CFrame = root.CFrame * CFrame.new(-14, 3, 0) end
		if vehicle then
			vehicle:SetAttribute("DriveReady", false)
			vehicle:SetAttribute("DriverUserId", nil)
		end
		return true, "Exited vehicle."
	end

	local function V56_reEnterVehicle(player)
		local vehicle
		for _, candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then vehicle = candidate; break end
		end
		if not vehicle then return false, "No vehicle nearby." end
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		local seat = vehicle:FindFirstChild("DriverSeat", true)
		if root then vehicle.PrimaryPart = root; pcall(function() root:SetNetworkOwner(player) end) end
		if not (seat and seat:IsA("VehicleSeat")) then return false, "Driver seat missing." end
		vehicle:SetAttribute("DriveReady", true)
		vehicle:SetAttribute("DriverUserId", player.UserId)
		V56_seatPlayer(player, vehicle, seat)
		return true, "Entered vehicle."
	end

	V56_invoke.OnServerInvoke = function(player, action, args)
		args = typeof(args) == "table" and args or {}
		local okCall, result = pcall(function()
			local profile = V56_getProfile(player)
			profile._Player = player
			V76_grantDefaultModulesForCurrentCockpit(profile)
						V85_attachDefaultModuleInstancesToCurrentVehicle(profile)
			V84_ensureInstanceInventory(profile)
			local ok, message
			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				V80_mirrorLegacyProfileToPersistence(player, profile, action, false)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }
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
			elseif action == "SetCockpitColor" then
				local channel = tostring(args.Channel or "Primary")
				local color = args.Color
				if typeof(color) ~= "Color3" then ok, message = false, "Invalid colour."
				elseif channel ~= "Primary" and channel ~= "Secondary" and channel ~= "Detail" and channel ~= "Neon" and channel ~= "FrontLights" and channel ~= "RearLights" then ok, message = false, "Invalid colour channel."
				else
					profile.CockpitColors[channel] = color
					if channel == "Primary" or channel == "Secondary" or channel == "Detail" then
						V76_syncInstalledModulePaintFromCockpit(profile, channel)
					end
					ok, message = true, "Colour updated."
				end
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
							profile.ModuleColors[installedSlot] = profile.ModuleColors[installedSlot] or {}
							profile.ModuleColors[installedSlot][channel] = color
						end
					else
						profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
						profile.ModuleColors[slotId][channel] = color
					end
					ok, message = true, "Colour updated."
				end
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
					local price = V56_number(module, "NeonPrice", 5000)
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
			elseif action == "SetThrustColor" then
				local color = args.Color
				if typeof(color) ~= "Color3" then ok, message = false, "Invalid thrust colour." else
					profile.ThrustColor = color
					for slotId in pairs(profile.InstalledModules) do
						profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
						profile.ModuleColors[slotId].ThrustColor = color
					end
					ok, message = true, "Thrust colour updated."
				end
			elseif action == "ExitVehicle" then
				ok, message = V56_exitVehicle(player)
			elseif action == "ReEnterVehicle" then
				ok, message = V56_reEnterVehicle(player)
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
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)
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
