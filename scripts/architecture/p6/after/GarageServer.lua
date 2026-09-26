-- Canonical feature implementation; startup is owned by the composition root.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
-- Neo Tokyo Racers shadow server action controller.
-- Canonical garage action owner.
-- Do not enable while HOVER_RACING_V2_Server still owns GarageInvoke.OnServerInvoke.
-- Source hash: 3be69270


do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local CollectionService = game:GetService("CollectionService")

	local WORLD_NAME = "World"
	local kit = game:GetService("ReplicatedStorage")
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Garage")
	local invoke = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")
	local categoriesRoot = game:GetService("ServerStorage"):WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
	local world = game:GetService("Workspace"):WaitForChild("World")
	local garageServer_runtime = game:GetService("Workspace"):WaitForChild("World"):WaitForChild("Runtime")
	local vehiclesRoot = game:GetService("Workspace"):WaitForChild("World"):WaitForChild("Runtime"):WaitForChild("PlayerVehicles")
local STARTING_CASH = game:GetService("ReplicatedStorage").Config.Garage:GetAttribute("StartingCash") or 140000
	local FALLBACK_SPAWN_POS = Vector3.new(game:GetService("ReplicatedStorage").Config.Garage:GetAttribute("SpawnX") or 860, game:GetService("ReplicatedStorage").Config.Garage:GetAttribute("SpawnY") or 105, game:GetService("ReplicatedStorage").Config.Garage:GetAttribute("SpawnZ") or -1713)

	local function garageServer_spawnCFrame()
		local dealership = game:GetService("Workspace"):WaitForChild("World"):FindFirstChild("Dealership")
		local dealershipSpawn = dealership and game:GetService("Workspace"):WaitForChild("World"):WaitForChild("Dealership"):FindFirstChild("Spawn")
		local exitSpawn = dealershipSpawn and game:GetService("Workspace"):WaitForChild("World"):WaitForChild("Dealership"):WaitForChild("Spawn"):FindFirstChild("VehicleExitSpawnPoint")
		if exitSpawn and exitSpawn:IsA("BasePart") then
			return exitSpawn.CFrame
		end

		local spawnPoints = game:GetService("Workspace"):WaitForChild("World"):FindFirstChild("SpawnPoints")
		local fallbackSpawn = spawnPoints and game:GetService("Workspace"):WaitForChild("World"):WaitForChild("SpawnPoints"):FindFirstChild("VehicleSpawnPoint")
		if fallbackSpawn and fallbackSpawn:IsA("BasePart") then
			return fallbackSpawn.CFrame
		end

		return CFrame.lookAt(FALLBACK_SPAWN_POS, FALLBACK_SPAWN_POS + Vector3.new(0, 0, 1))
	end
	local PREVIEW_POS = Vector3.new(game:GetService("ReplicatedStorage").Config.Garage:GetAttribute("PreviewX") or 860, game:GetService("ReplicatedStorage").Config.Garage:GetAttribute("PreviewY") or 104, game:GetService("ReplicatedStorage").Config.Garage:GetAttribute("PreviewZ") or -1749)
	local ProfileServer = require(game.ServerStorage.Modules.Game.Player.ProfileServer)
	local MoneyService = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("MoneyService"))
	local garageProfileRuntime = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageProfile"))
	local moduleInventory = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageModuleInventory")) 
	local moduleInstances = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageModuleInstanceCustomization")) 
	local moduleTransactions = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageModuleTransaction")) 
	local vehicleCosmetics = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("VehicleCosmeticServer")) 
	local cosmeticCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehicleCosmeticCatalog"))
	local moduleUpgrades = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("Performance"):WaitForChild("VehicleModuleUpgradeRuntime"))

	local function garageServer_value(item, name)
		if not item then return nil end
		local attr = item:GetAttribute(name)
		if attr ~= nil then return attr end
		local child = item:FindFirstChild(name)
		if child and child:IsA("ValueBase") then return child.Value end
		return nil
	end

	local function garageServer_number(item, name, fallback)
		local value = garageServer_value(item, name)
		if typeof(value) == "number" then return value end
		if typeof(value) == "string" then
			local number = tonumber(value)
			if number then return number end
		end
		return fallback
	end

	local function garageServer_string(item, name, fallback)
		local value = garageServer_value(item, name)
		if typeof(value) == "string" and value ~= "" then return value end
		return fallback
	end

	local function primitiveAttributes(instance)
		local result = {}
		for key, value in pairs(instance:GetAttributes()) do
			local t = typeof(value)
			if t == "string" or t == "number" or t == "boolean" or t == "Color3" then
				result[key] = value
			end
		end
		return result
	end

	local normalizeProfile, getProfileServiceProfile, getProfile = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageProfileView"))({Players = Players, ProfileServer = ProfileServer, STARTING_CASH = STARTING_CASH})
	local cleanupBridge = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage"):FindFirstChild("GarageModuleInventoryCleanupBridge")
	if cleanupBridge and not cleanupBridge:IsA("BindableFunction") then
		error("GarageModuleInventoryCleanupBridge exists with the wrong class")
	end
	if not cleanupBridge then
		cleanupBridge = Instance.new("BindableFunction")
		cleanupBridge.Name = "GarageModuleInventoryCleanupBridge"
		cleanupBridge.Parent = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage")
	end
	cleanupBridge.OnInvoke = function(player, mode, expectedToken)
		local profile = getProfile(player)
		if mode == "Apply" then
			return moduleInventory.ApplyReviewedCleanup(profile, expectedToken)
		elseif mode == "Rollback" then
			return moduleInventory.RollbackReviewedCleanup(profile)
		elseif mode == "Commit" then
			return moduleInventory.CommitReviewedCleanup(profile)
		end
		return false, "Unknown cleanup bridge mode."
	end
	local ownedCockpitCount, ownedGarageProperties, profileGarageCapacity, maxGarageCapacity, capacityUpgradePrice, nextGaragePropertyPrice, buyGarageProperty, upgradeGarageCapacity, canBuyCockpit = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageCapacity"))({MoneyService = MoneyService})
	local mutatingActions = {
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

	local function countOwnedEntries(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function replaceTableContents(target, source)
		for key in pairs(target) do
			target[key] = nil
		end
		for key, value in pairs(source or {}) do
			target[key] = value
		end
	end

	local function mirrorLegacyProfileToPersistence(player, profile, action, dirty)
		local ok, message=ProfileServer.commit_garage(player,profile,"GarageAction:"..tostring(action),dirty==true)
		if not ok then error(message) end
	end
	local function findCockpitForDefaultColours(categoryId, cockpitId)
		for _, category in ipairs(categoriesRoot:GetChildren()) do
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

	local function colorAttribute(item, name, fallback)
		local value = item and item:GetAttribute(name)
		if typeof(value) == "Color3" then
			return value
		end
		return fallback
	end

	local function defaultCockpitColorsFor(profile)
		local cockpit = findCockpitForDefaultColours(profile.CurrentCategory or "bruiser", profile.CurrentCockpit or "bruiser_01")
		return {
			Primary = colorAttribute(cockpit, "DefaultPrimaryColor", Color3.fromRGB(0, 205, 230)),
			Secondary = colorAttribute(cockpit, "DefaultSecondaryColor", Color3.fromRGB(235, 247, 204)),
			Detail = colorAttribute(cockpit, "DefaultDetailColor", Color3.fromRGB(38, 44, 50)),
			Neon = colorAttribute(cockpit, "DefaultNeonColor", Color3.fromRGB(255, 255, 255)),
			FrontLights = colorAttribute(cockpit, "DefaultFrontLightsColor", Color3.fromRGB(252, 250, 255)),
			RearLights = colorAttribute(cockpit, "DefaultRearLightsColor", Color3.fromRGB(255, 116, 116)),
		}
	end

	local function syncInstalledModulePaintFromCockpit(profile, channel)
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

	local function applyDefaultCockpitColors(profile)
		profile.CockpitColors = defaultCockpitColorsFor(profile)
		syncInstalledModulePaintFromCockpit(profile)
	end

	local function setLeaderstats(player, profile)
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
	-- Existing reward callers retain their binding, but ProfileService is the only
	-- positive-Cash grant owner. This legacy profile is a committed projection only.
	local raceRewardBridgeReady = false
	local economyProjectionConnected = false
	local function profileEconomyBindings()
		local servicesRoot = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage") and game:GetService("ServerStorage"):WaitForChild("Runtime")
		local playerRoot = servicesRoot and game:GetService("ServerStorage"):WaitForChild("Runtime"):FindFirstChild("Player")
		local bindings = playerRoot and game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Player"):FindFirstChild("ProfileServiceBindings")
		local execute = bindings and bindings:FindFirstChild("ExecuteEconomyCommand")
		local committed = bindings and bindings:FindFirstChild("EconomyCashCommitted")
		return execute, committed
	end
	local function connectEconomyProjection()
		if economyProjectionConnected then return end
		local _, committed = profileEconomyBindings()
		if not (committed and committed:IsA("BindableEvent")) then return end
		committed.Event:Connect(function(player, committedCash)
			if not (player and player:IsA("Player")) then return end
			local current = ProfileServer.get_profile(player)
			if current then committedCash=current.Cash end
			setLeaderstats(player, {Cash=committedCash})
		end)
		economyProjectionConnected = true
	end
	local function ensureRaceRewardCashBridge()
		if raceRewardBridgeReady then return end
		local bindings = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage"):FindFirstChild("GarageProfileMutationBindings")
		if not bindings then
			bindings = Instance.new("Folder")
			bindings.Name = "GarageProfileMutationBindings"
			bindings.Parent = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage")
		end
		local grantCash = bindings:FindFirstChild("GrantCash")
		if not grantCash then
			grantCash = Instance.new("BindableFunction")
			grantCash.Name = "GrantCash"
			grantCash.Parent = bindings
		end
		grantCash.OnInvoke = function(action, payload)
			if action ~= "GrantCash" then
				return {Ok=false, Success=false, Message="Unknown garage mutation action."}
			end
			payload = typeof(payload) == "table" and payload or {}
			local player = payload.Player
			local execute = profileEconomyBindings()
			if not (player and execute and execute:IsA("BindableFunction")) then
				return {Ok=false, Success=false, Message="ProfileService economy command is unavailable."}
			end
			connectEconomyProjection()
			local result = execute:Invoke(player, {
				Version=1,
				Action="GrantCash",
				Amount=math.floor((tonumber(payload.Amount) or 0)+0.5),
				Reason=tostring(payload.Reason or ""),
				CommandId=(tostring(payload.Reason or "")=="StudioCashGrantHotkey")
					and game:GetService("HttpService"):GenerateGUID(false)
					or (tostring(payload.Reason or "")..":"..tostring(payload.RunId or "")..":"..tostring(player.UserId)),
				RunId=tostring(payload.RunId or ""),
				EventId=tostring(payload.EventId or ""),
			})
			if typeof(result) == "table" and result.Success == true then
				player:SetAttribute("LastRaceRewardAmount", result.Amount)
				player:SetAttribute("LastRaceRewardRunId", tostring(payload.RunId or ""))
				player:SetAttribute("LastRaceRewardEventId", tostring(payload.EventId or ""))
			end
			return result
		end
		connectEconomyProjection()
		task.spawn(function()
			for _ = 1, 100 do
				if economyProjectionConnected then return end
				task.wait(0.1)
				connectEconomyProjection()
			end
			warn("[Economy] Legacy Cash projection did not connect within 10 seconds.")
		end)
		raceRewardBridgeReady = true
	end
	ensureRaceRewardCashBridge()

	local attachDefaultModuleInstancesToCurrentVehicle
	local slug, garageServer_categoryFolder, findCockpit, findModule, moduleSourceCockpitId, moduleVariantName, moduleVariantOrder, findSourceCockpit, modulePurchasePrice, moduleLockedMessage, moduleTypeFromText, moduleTypeForModel, moduleFitsSlot = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageCatalogLookup"))({categoriesRoot = categoriesRoot, garageServer_number = garageServer_number, garageServer_string = garageServer_string})
	local httpService = game:GetService("HttpService")

	local function generateId(prefix)
		local guid = string.gsub(httpService:GenerateGUID(false), "-", "")
		return tostring(prefix or "id") .. "_" .. string.sub(guid, 1, 12)
	end

	local function countGarageEntries(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function cloneDictionary(dictionary)
		local copy = {}
		for key, value in pairs(dictionary or {}) do
			if typeof(value) == "table" then
				copy[key] = cloneDictionary(value)
			else
				copy[key] = value
			end
		end
		return copy
	end

	local function nextDisplaySpaceKey(profile)
		profile.GarageDisplaySpaces = typeof(profile.GarageDisplaySpaces) == "table" and profile.GarageDisplaySpaces or {}
		local capacity = profileGarageCapacity(profile)
		for index = 1, math.max(1, capacity) do
			local key = "Space" .. tostring(index)
			local space = profile.GarageDisplaySpaces[key]
			if typeof(space) ~= "table" or space.VehicleId == nil then
				profile.GarageDisplaySpaces[key] = typeof(space) == "table" and space or {}
				return key
			end
		end
		return "Space" .. tostring(countGarageEntries(profile.GarageDisplaySpaces) + 1)
	end

	local function assignDisplaySpace(profile, vehicleId)
		local key = nextDisplaySpaceKey(profile)
		profile.GarageDisplaySpaces[key] = profile.GarageDisplaySpaces[key] or {}
		profile.GarageDisplaySpaces[key].VehicleId = vehicleId
	end

	local function createVehicleInstance(profile, cockpitId, sourceName)
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		local cockpitInstanceId = generateId("cockpit")
		local vehicleId = generateId("vehicle")
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
			CockpitColors = cloneDictionary(profile.CockpitColors or {}),
			ThrustColor = profile.ThrustColor,
			Cosmetics = cosmeticCatalog.DefaultState(),
			Source = sourceName or "PersistencePhase14",
		}
		assignDisplaySpace(profile, vehicleId)
		return vehicleId, cockpitInstanceId
	end

	local function ensureInstanceInventory(profile)
		-- Creation is owned by explicit cockpit/module purchase paths, never reads or summaries.
		return moduleInventory.EnsureShape(profile)
	end
	local function syncInstanceDataFromLegacy(profile)
		local result = garageProfileRuntime.SyncInstanceDataFromLegacy(profile, {
			GenerateId = generateId,
			CloneDictionary = cloneDictionary,
			EnsureInstanceInventory = ensureInstanceInventory,
		})
		local syncCount = typeof(result) == "table" and tonumber(result.SyncCount) or 0
		local vehicleId = typeof(result) == "table" and result.VehicleId or nil
		local player = profile and profile._Player
		if player then
			player:SetAttribute("PersistencePhase19Synced", true)
			player:SetAttribute("PersistencePhase19VehicleId", tostring(vehicleId or ""))
			player:SetAttribute("PersistencePhase19ModuleSyncCount", syncCount or 0)
			player:SetAttribute("PersistencePhase20RuntimeModule", "GarageProfileRuntime")
			player:SetAttribute("PersistencePhase20VehicleId", tostring(vehicleId or ""))
			player:SetAttribute("PersistencePhase20ModuleSyncCount", syncCount or 0)
		end
		return syncCount or 0
	end
	local function defaultModuleIdsForCockpit(cockpit)
		if not cockpit then return {} end
		return {
			Engine = garageServer_string(cockpit, "DefaultEngineModuleId", nil),
			RearEngine = garageServer_string(cockpit, "DefaultRearEngineModuleId", garageServer_string(cockpit, "DefaultEngineBModuleId", nil)),
			Stabilisers = garageServer_string(cockpit, "DefaultStabilisersModuleId", garageServer_string(cockpit, "DefaultStabiliserModuleId", nil)),
			Boost = garageServer_string(cockpit, "DefaultBoostModuleId", nil),
		}
	end

	local function grantDefaultModulesForCurrentCockpit(profile)
		if not profile then return end
		local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local defaults = defaultModuleIdsForCockpit(cockpit)
		profile.OwnedModules = typeof(profile.OwnedModules) == "table" and profile.OwnedModules or {}
		profile.InstalledModules = typeof(profile.InstalledModules) == "table" and profile.InstalledModules or {}
		for _, moduleId in pairs(defaults) do
			if moduleId and moduleId ~= "" and findModule(profile.CurrentCategory, moduleId) then
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

	local function coreModulesEquipped(profile)
		local hasEngine, hasStabilisers, hasBoost = false, false, false
		for _, moduleId in pairs((profile and profile.InstalledModules) or {}) do
			local module = findModule(profile.CurrentCategory, moduleId)
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
attachDefaultModuleInstancesToCurrentVehicle = function(profile)
		if not profile then return end
		profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
		profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
		profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
		local vehicleId = profile.CurrentVehicleId
		local vehicle = vehicleId and profile.Vehicles and profile.Vehicles[vehicleId]
		if not vehicle then return end
		local cockpitInstance = profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local cockpitId = cockpitInstance and cockpitInstance.TemplateId or profile.CurrentCockpit
		local cockpit = findCockpit(vehicle.CategoryId or profile.CurrentCategory, cockpitId)
		local defaults = defaultModuleIdsForCockpit(cockpit)
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
			if moduleId and findModule(profile.CurrentCategory, moduleId) and not vehicle.InstalledModules[slotId] then
				local moduleInstanceId = generateId("module")
				profile.OwnedModules[moduleId] = true
				profile.OwnedModuleInstances[moduleInstanceId] = {
					TemplateId = moduleId,
					EquippedVehicleId = vehicleId,
					UpgradeLevels = cloneDictionary((profile.ModuleUpgradeLevels or {})[moduleId] or {}),
					Colors = cloneDictionary(profile.CockpitColors or {}),
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
	local function buyCockpitInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		local requestedCategory = tostring(args.CategoryId or profile.CurrentCategory or "")
		if requestedCategory ~= "" then profile.CurrentCategory = requestedCategory end
		local cockpitId = tostring(args.CockpitId or "")
		local cockpit = findCockpit(profile.CurrentCategory, cockpitId)
		if not cockpit then
			return false, "Cockpit not found."
		end
		ensureInstanceInventory(profile)
		if countGarageEntries(profile.Vehicles) >= profileGarageCapacity(profile) then
			return false, "Garage full. Buy more garage space to store more vehicles."
		end
		local price = garageServer_number(cockpit, "Price", 0)
		if profile.Cash < price then
			return false, "Not enough cash."
		end
		MoneyService.Debit(profile, price, "CockpitInstance")
		profile.CurrentCockpit = cockpitId
		profile.OwnedCockpits[cockpitId] = true
		applyDefaultCockpitColors(profile)
		local vehicleId = createVehicleInstance(profile, cockpitId, "BuyCockpitInstance")
		profile.CurrentVehicleId = vehicleId
		grantDefaultModulesForCurrentCockpit(profile)
						attachDefaultModuleInstancesToCurrentVehicle(profile)
		ensureInstanceInventory(profile)
		return true, "Cockpit instance purchased."
	end
	local function vehicleModuleContext(profile, vehicleId, slotId)
		local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId)]
		if typeof(vehicle)~="table" then return nil,nil,nil,"Vehicle instance not found." end
		local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local cockpit=cockpitInstance and findCockpit(vehicle.CategoryId or profile.CurrentCategory,tostring(cockpitInstance.TemplateId or ""))
		local mount=cockpit and cockpit:FindFirstChild("SLOT_"..tostring(slotId),true)
		if not cockpit then return vehicle,nil,nil,"Cockpit template not found." end
		if not mount then return vehicle,cockpit,nil,"Slot not found on this cockpit." end
		return vehicle,cockpit,mount
	end

	local function instanceFits(profile,instance,vehicleId,slotId)
		local vehicle,_,mount,contextMessage=vehicleModuleContext(profile,vehicleId,slotId); if not mount then return false,contextMessage end
		local module=findModule(vehicle.CategoryId or profile.CurrentCategory,tostring(instance and instance.TemplateId or "")); if not module then return false,"Module template not found." end
		local slotType=garageServer_string(mount,"ModuleType",moduleTypeFromText(slotId)); local moduleType=moduleTypeForModel(module)
		if slotType and slotType~="" and moduleType~=slotType then return false,"That module does not fit this slot." end
		if not moduleFitsSlot(module,slotId,garageServer_string(mount,"AllowedModuleFolder","")) then return false,"That module does not fit this slot." end
		return true
	end

	local function instanceRating(profile,instance,vehicleId)
		for _,key in ipairs({"Rating","PerformanceRating","PerformanceIndex","ModuleRating"}) do local value=tonumber(instance and instance[key]); if value then return value end end
		local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId or "")]; local categoryId=vehicle and vehicle.CategoryId or profile.CurrentCategory
		local module=findModule(categoryId,tostring(instance and instance.TemplateId or "")); if not module then return math.huge end
		for _,key in ipairs({"Rating","PerformanceRating","PerformanceIndex","ModuleRating"}) do local value=garageServer_number(module,key,nil); if value then return value end end
		local sourceId,cockpit=findSourceCockpit(profile,module); local sourceRating=cockpit and (garageServer_number(cockpit,"BaseRating",nil) or garageServer_number(cockpit,"PerformanceIndex",nil) or garageServer_number(cockpit,"Rating",nil))
		if not sourceRating then local tier=string.upper(tostring(cockpit and cockpit:GetAttribute("Tier") or "")); sourceRating=({E=1000,D=2000,C=3000,B=4000,A=5000,S=6000})[tier] or (sourceId and 7000 or 0) end
		return sourceRating+moduleVariantOrder(module)
	end

	local function coreSlotRequired(profile,vehicleId,slotId)
		if slotId=="Stabilisers" or slotId=="Boost" then return true end
		if slotId=="Engine1" or slotId=="Engine2" then
			local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId)]; local other=slotId=="Engine1" and "Engine2" or "Engine1"
			return not (vehicle and vehicle.InstalledModules and vehicle.InstalledModules[other])
		end
		return false
	end

	local function afterModuleTransaction(profile)
		local current=profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; profile.InstalledModules={}
		for slotId,instanceId in pairs((current and current.InstalledModules) or {}) do local instance=profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]; if typeof(instance)=="table" then profile.InstalledModules[slotId]=tostring(instance.TemplateId or "") end end
		return moduleInstances.HydrateAll(profile)
	end

	local function transactionHooks(profile)
		return {
			Fits=function(instance,vehicleId,slotId) return instanceFits(profile,instance,vehicleId,slotId) end,
			Rating=function(instance,vehicleId) return instanceRating(profile,instance,vehicleId) end,
			IsCoreSlot=coreSlotRequired,
			After=afterModuleTransaction,
			Validate=function(value) return moduleInstances.Validate(value) end,
		}
	end

	local function captureCurrentModuleState(profile)
		return moduleInstances.CaptureAll(profile,moduleUpgrades.GetLevels(profile._Player))
	end

	local function buyModuleInstance(profile,args)
		args=typeof(args)=="table" and args or {}; ensureInstanceInventory(profile)
		local moduleId=tostring(args.ModuleId or ""); local vehicleId=tostring(args.VehicleId or profile.CurrentVehicleId or ""); local slotId=tostring(args.SlotId or "")
		local module=findModule(profile.CurrentCategory,moduleId); if not module then return false,"Module not found." end
		local lockMessage=moduleLockedMessage(profile,module); if lockMessage then return false,lockMessage end
		local fits,fitMessage=instanceFits(profile,{TemplateId=moduleId},vehicleId,slotId); if not fits then return false,fitMessage end
		local captured,captureMessage=captureCurrentModuleState(profile); if not captured then return false,captureMessage end
		local moduleInstanceId=generateId("module")
		local record={TemplateId=moduleId,EquippedVehicleId=nil,UpgradeLevels={},V2UpgradePoints={},Colors={},NeonOwned=false,Source="BuyModuleInstance",AcquisitionKind="Purchase",AcquiredAtUnix=os.time()}
		return moduleTransactions.BuyAndEquip(profile,{InstanceId=moduleInstanceId,Record=record,Price=modulePurchasePrice(module),VehicleId=vehicleId,SlotId=slotId},transactionHooks(profile))
	end

	local function equipModuleInstance(profile,args)
		args=typeof(args)=="table" and args or {}; ensureInstanceInventory(profile)
		local captured,captureMessage=captureCurrentModuleState(profile); if not captured then return false,captureMessage end
		return moduleTransactions.Equip(profile,{InstanceId=tostring(args.ModuleInstanceId or ""),VehicleId=tostring(args.VehicleId or profile.CurrentVehicleId or ""),SlotId=tostring(args.SlotId or ""),AllowReassign=args.AllowReassign==true},transactionHooks(profile))
	end
	local function syncLegacyFromCurrentVehicle(profile)
		ensureInstanceInventory(profile)
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
		profile.CockpitColors = cloneDictionary(vehicle.CockpitColors or profile.CockpitColors or {})
		profile.ThrustColor = vehicle.ThrustColor or profile.ThrustColor
		profile.InstalledModules = {}
		profile.ModuleColors = {}
		profile.NeonOwned = {}
		for slotId, moduleInstanceId in pairs(vehicle.InstalledModules or {}) do
			local moduleInstance = profile.OwnedModuleInstances and profile.OwnedModuleInstances[moduleInstanceId]
			if typeof(moduleInstance) == "table" and moduleInstance.TemplateId then
				profile.InstalledModules[slotId] = tostring(moduleInstance.TemplateId)
				profile.ModuleColors[slotId] = cloneDictionary(moduleInstance.Colors or {})
				profile.NeonOwned[slotId] = moduleInstance.NeonOwned == true
			end
		end
		local hydrated,hydrateMessage,repairedColours=moduleInstances.HydrateAll(profile); if not hydrated then return false,hydrateMessage end
		return true, "Vehicle selected.", tonumber(repairedColours) or 0
	end

	local function selectVehicleInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		ensureInstanceInventory(profile)
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
		local ok, message, repairedColours = syncLegacyFromCurrentVehicle(profile)
		if ok then
			attachDefaultModuleInstancesToCurrentVehicle(profile)
			local resynced,resyncMessage,resyncRepairs=syncLegacyFromCurrentVehicle(profile)
			if not resynced then return false,resyncMessage,tonumber(repairedColours) or 0 end
			repairedColours=(tonumber(repairedColours) or 0)+(tonumber(resyncRepairs) or 0)
		end
		return ok, message, repairedColours
	end
	local function ensureCustomisationAccess(player,profile)
		ensureInstanceInventory(profile)
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
			ok,message,repairedColours=selectVehicleInstance(profile,{VehicleId=owned[1]})
		else
			ok,message,repairedColours=syncLegacyFromCurrentVehicle(profile)
		end
		if not ok then return {Success=false,Message=message or "Owned vehicle selection could not be repaired.",OwnedVehicleCount=#owned} end
		local valid,validationMessage=moduleInstances.Validate(profile)
		if not valid then return {Success=false,Message="Owned vehicle state is invalid: "..tostring(validationMessage),OwnedVehicleCount=#owned} end
		if stale or (tonumber(repairedColours) or 0)>0 then
			mirrorLegacyProfileToPersistence(player,profile,"EnsureCustomisationAccess",true)
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

	local accessBinding=game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage"):FindFirstChild("GarageCustomisationAccessBinding") or Instance.new("BindableFunction")
	accessBinding.Name="GarageCustomisationAccessBinding"
	accessBinding.Parent=game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage")
	accessBinding.OnInvoke=function(player)
		local ok,result=pcall(function()
			local profile=getProfile(player); profile._Player=player
			return ensureCustomisationAccess(player,profile)
		end)
		if ok and typeof(result)=="table" then return result end
		warn("[Customisation Access] binding failed: "..tostring(result))
		return {Success=false,Message="Customisation access is unavailable."}
	end
	local function cloneForSummary(value)
		if typeof(value) == "table" then
			local copy = {}
			for key, child in pairs(value) do
				copy[key] = cloneForSummary(child)
			end
			return copy
		end
		return value
	end

	local function restoreProfileSelection(profile, snapshot)
		profile.CurrentVehicleId = snapshot.CurrentVehicleId
		profile.CurrentCategory = snapshot.CurrentCategory
		profile.CurrentCockpit = snapshot.CurrentCockpit
		profile.CockpitColors = cloneForSummary(snapshot.CockpitColors)
		profile.ThrustColor = snapshot.ThrustColor
		profile.InstalledModules = cloneForSummary(snapshot.InstalledModules)
		profile.ModuleColors = cloneForSummary(snapshot.ModuleColors)
		profile.NeonOwned = cloneForSummary(snapshot.NeonOwned)
	end
	local function numberAttribute(instance, name, fallback)
		local value = instance and instance:GetAttribute(name)
		return typeof(value) == "number" and value or fallback
	end

	local function addModuleStats(totals, module)
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

	local function summaryTotals(profile)
		if typeof(totalStats) == "function" then
			return totalStats(profile)
		end
		local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = numberAttribute(cockpit, "TopSpeed", numberAttribute(cockpit, "MaxSpeed", 126)),
			Acceleration = numberAttribute(cockpit, "Acceleration", 42),
			Handling = numberAttribute(cockpit, "Handling", 48),
			Drift = numberAttribute(cockpit, "Drift", 46),
			Braking = numberAttribute(cockpit, "Braking", 44),
			Weight = numberAttribute(cockpit, "Weight", 118),
			Boost = numberAttribute(cockpit, "Boost", 0),
			BoostDuration = numberAttribute(cockpit, "BoostDuration", 2),
			BoostRecharge = numberAttribute(cockpit, "BoostRecharge", 9),
			BoostRechargeDelay = numberAttribute(cockpit, "BoostRechargeDelay", 0),
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			local module = findModule(profile.CurrentCategory, moduleId)
			if module then
				for _, stat in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostDuration", "BoostRecharge", "BoostRechargeDelay" }) do
					totals[stat] = (totals[stat] or 0) + numberAttribute(module, stat, 0)
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

	local function vehicleSummaries(profile,summaryPlayer)
		ensureInstanceInventory(profile)
		local snapshot = {
			CurrentVehicleId = profile.CurrentVehicleId,
			CurrentCategory = profile.CurrentCategory,
			CurrentCockpit = profile.CurrentCockpit,
			CockpitColors = cloneForSummary(profile.CockpitColors or {}),
			ThrustColor = profile.ThrustColor,
			InstalledModules = cloneForSummary(profile.InstalledModules or {}),
			ModuleColors = cloneForSummary(profile.ModuleColors or {}),
			NeonOwned = cloneForSummary(profile.NeonOwned or {}),
		}
		local summaries = {}
		for vehicleId, vehicle in pairs(profile.Vehicles or {}) do
			if typeof(vehicle) == "table" then
				profile.CurrentVehicleId = vehicleId
				local ok = syncLegacyFromCurrentVehicle(profile)
				if ok then
					local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
					local performance = moduleUpgrades.CalculateProfile(
						summaryPlayer or profile._Player,
						profile,
						summaryTotals(profile),
						cockpit,
						findModule,
						moduleTypeForModel
					)
					summaries[vehicleId] = {
						VehicleId = vehicleId,
						CockpitId = profile.CurrentCockpit,
						DisplayName = vehicle.DisplayName or profile.CurrentCockpit,
						Overall = performance and performance.Overall or nil,
						Headline = performance and performance.Headline or nil,
					}
				end
			end
		end
		restoreProfileSelection(profile, snapshot)
		return summaries
	end
	local garageServer_catalog = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageCatalogService"))({PREVIEW_POS = PREVIEW_POS, categoriesRoot = categoriesRoot, cosmeticCatalog = cosmeticCatalog, findSourceCockpit = findSourceCockpit, garageServer_number = garageServer_number, garageServer_string = garageServer_string, modulePurchasePrice = modulePurchasePrice, moduleSourceCockpitId = moduleSourceCockpitId, moduleTypeForModel = moduleTypeForModel, moduleTypeFromText = moduleTypeFromText, moduleUpgrades = moduleUpgrades, moduleVariantName = moduleVariantName, moduleVariantOrder = moduleVariantOrder, primitiveAttributes = primitiveAttributes, slug = slug})
	local totalStats, profileForClient = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageClientProfile"))({capacityUpgradePrice = capacityUpgradePrice, findCockpit = findCockpit, findModule = findModule, garageServer_categoryFolder = garageServer_categoryFolder, garageServer_number = garageServer_number, garageServer_string = garageServer_string, maxGarageCapacity = maxGarageCapacity, moduleTypeForModel = moduleTypeForModel, moduleUpgrades = moduleUpgrades, nextGaragePropertyPrice = nextGaragePropertyPrice, normalizeProfile = normalizeProfile, ownedCockpitCount = ownedCockpitCount, ownedGarageProperties = ownedGarageProperties, profileGarageCapacity = profileGarageCapacity, vehicleCosmetics = vehicleCosmetics, vehicleSummaries = vehicleSummaries})
	local seatPlayer, folderHasBuyableNeon, buildVehicle = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("VehicleBuildService"))({cosmeticCatalog = cosmeticCatalog, findCockpit = findCockpit, findModule = findModule, garageServer_spawnCFrame = garageServer_spawnCFrame, moduleTypeForModel = moduleTypeForModel, moduleUpgrades = moduleUpgrades, normalizeProfile = normalizeProfile, totalStats = totalStats, vehiclesRoot = vehiclesRoot})
	local rootPart, playerSpeedMph, spawnOwnedVehicleFromFreeRoam = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("VehicleSpawnService"))({CollectionService = CollectionService, FALLBACK_SPAWN_POS = FALLBACK_SPAWN_POS, Players = Players, Workspace = Workspace, buildVehicle = buildVehicle, coreModulesEquipped = coreModulesEquipped, getProfile = getProfile, mirrorLegacyProfileToPersistence = mirrorLegacyProfileToPersistence, selectVehicleInstance = selectVehicleInstance, vehiclesRoot = vehiclesRoot})
	local exitVehicle, despawnVehicle, reEnterVehicle = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("VehicleLifecycleService"))({Workspace = Workspace, buildVehicle = buildVehicle, coreModulesEquipped = coreModulesEquipped, findCockpit = findCockpit, garageServer_number = garageServer_number, getProfile = getProfile, mirrorLegacyProfileToPersistence = mirrorLegacyProfileToPersistence, playerSpeedMph = playerSpeedMph, rootPart = rootPart, seatPlayer = seatPlayer, selectVehicleInstance = selectVehicleInstance, vehicleSummaries = vehicleSummaries, vehiclesRoot = vehiclesRoot})
	local requestGuard = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageRequestGuard")).new()
	Players.PlayerRemoving:Connect(function(player) requestGuard.forget(player) end)
	local function handleGarageRequest(player, action, args)
		if player:GetAttribute("ProfileServiceLoaded") ~= true then
			local loaded = getProfileServiceProfile(player)
			if not loaded then return {Ok=false,Success=false,Message="Your profile is still loading. Please try again."} end
		end
		args = typeof(args) == "table" and args or {}
		if player:GetAttribute("RaceQueueActive")==true and (action=="SelectVehicleInstance" or action=="SpawnOwnedVehicleFromFreeRoam" or action=="SpawnVehicle" or action=="DespawnVehicle") then return {Ok=false,Success=false,Message="Leave the race queue before changing vehicles."} end
		if player:GetAttribute("OwnedGarageInside")==true and (action=="SelectVehicleInstance" or action=="SpawnOwnedVehicleFromFreeRoam" or action=="SpawnVehicle" or action=="DespawnVehicle" or action=="ExitVehicle" or action=="ReEnterVehicle") then return {Ok=false,Success=false,Message="Use the garage display spaces or exit door while inside your garage."} end
		local okCall, result = pcall(function()
			local profile = getProfile(player)
			profile._Player = player
			ensureInstanceInventory(profile) -- canonical shape only; no grants or migration
			local referencesOk,referencesResult=moduleInstances.ReconcileReferences(profile)
			if not referencesOk then return {Success=false,Message="Module inventory reference repair failed: "..tostring(referencesResult),Profile=profileForClient(profile)} end
			if tonumber(referencesResult) and referencesResult>0 then print("[Module Instance Authority] Reconciled "..tostring(referencesResult).." stale owner flag(s) from canonical vehicle-slot references") end
			local ok, message
			if action == "EnsureCustomisationAccess" then
				return ensureCustomisationAccess(player,profile)
			elseif action == "GetInitial" then
				setLeaderstats(player, profile)
				local catalogue,revision=garageServer_catalog(args.KnownCatalogRevision)
				return { Success = true, Catalog = catalogue, CatalogRevision = revision, CatalogProtocol = 1, Profile = profileForClient(profile) }
			elseif action == "SelectVehicleInstance" then
				ok, message = selectVehicleInstance(profile, args)
				setLeaderstats(player, profile)
			elseif action == "BuyCockpitInstance" then
				ok, message = buyCockpitInstance(profile, args)
				setLeaderstats(player, profile)
			elseif action == "BuyModuleInstance" then
				ok, message = buyModuleInstance(profile, args)
				setLeaderstats(player, profile)
			elseif action == "EquipModuleInstance" then
				ok, message = equipModuleInstance(profile, args)
				setLeaderstats(player, profile)
			elseif action == "BuyGarageProperty" then
				ok, message = buyGarageProperty(profile, args)
				setLeaderstats(player, profile)
			elseif action == "UpgradeGarageCapacity" then
				ok, message = upgradeGarageCapacity(profile)
				setLeaderstats(player, profile)
			elseif action == "BuyCockpit" then
				local cockpitId = tostring(args.CockpitId or "")
				local cockpit = findCockpit(profile.CurrentCategory, cockpitId)
				if not cockpit then ok, message = false, "Cockpit not found." else
					local price = garageServer_number(cockpit, "Price", 0)
					local capacityOk, capacityMessage = canBuyCockpit(profile, cockpitId)
					if not capacityOk then
						ok, message = false, capacityMessage
					elseif not profile.OwnedCockpits[cockpitId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							MoneyService.Debit(profile, price, "LegacyCockpit")
							profile.OwnedCockpits[cockpitId] = true
							ok, message = true, "Cockpit selected."
						end
					else ok, message = true, "Cockpit selected." end
					if ok then
						profile.CurrentCockpit = cockpitId
						applyDefaultCockpitColors(profile)
						grantDefaultModulesForCurrentCockpit(profile)
						attachDefaultModuleInstancesToCurrentVehicle(profile)
					end
					setLeaderstats(player, profile)
				end
			elseif action == "BuyVehicleCosmetic" then
				local cockpit=findCockpit(profile.CurrentCategory,profile.CurrentCockpit)
				ok,message=vehicleCosmetics.Purchase(profile,tostring(args.CosmeticId or ""),cockpit)
				setLeaderstats(player,profile)
			elseif action == "SetVehicleCosmeticColor" then
				ok,message=vehicleCosmetics.SetColour(profile,tostring(args.CosmeticId or ""),args.Color,function() return moduleInstances.CaptureAll(profile,moduleUpgrades.GetLevels(player)) end)
			elseif action == "SetAllNeonColor" then
				ok,message=vehicleCosmetics.SetAllNeon(profile,args.Color,function() return moduleInstances.CaptureAll(profile,moduleUpgrades.GetLevels(player)) end)
			elseif action == "SetCockpitColor" then
				local channel = tostring(args.Channel or "Primary")
				local color = args.Color
				local scope = tostring(args.Scope or "WholeVehicle")
				if typeof(color) ~= "Color3" then ok, message = false, "Invalid colour."
				elseif channel ~= "Primary" and channel ~= "Secondary" and channel ~= "Detail" and channel ~= "Neon" and channel ~= "FrontLights" and channel ~= "RearLights" then ok, message = false, "Invalid colour channel."
				elseif scope ~= "WholeVehicle" and scope ~= "CockpitOnly" then ok, message = false, "Invalid cockpit colour scope."
				else
					local oldCockpitColors=cloneDictionary(profile.CockpitColors or {})
					local oldModuleColors=cloneDictionary(profile.ModuleColors or {})
					local oldModuleInstances=cloneDictionary(profile.OwnedModuleInstances or {})
					local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]
					local oldVehicleCockpit=typeof(currentVehicle)=="table" and cloneDictionary(currentVehicle.CockpitColors or {}) or nil
					profile.CockpitColors[channel] = color
					if typeof(currentVehicle)=="table" then currentVehicle.CockpitColors=cloneDictionary(profile.CockpitColors) end
					if scope == "WholeVehicle" and (channel == "Primary" or channel == "Secondary" or channel == "Detail") then
						syncInstalledModulePaintFromCockpit(profile, channel)
						local captured,captureMessage=moduleInstances.CaptureAll(profile,moduleUpgrades.GetLevels(player))
						if not captured then profile.CockpitColors=oldCockpitColors; profile.ModuleColors=oldModuleColors; profile.OwnedModuleInstances=oldModuleInstances; if typeof(currentVehicle)=="table" then currentVehicle.CockpitColors=oldVehicleCockpit end; ok,message=false,captureMessage else ok,message=true,"Vehicle colour updated." end
					else ok,message=true,"Cockpit colour updated." end
				end
			elseif action == "BuyModule" then
				local slotId = tostring(args.SlotId or "")
				local moduleId = tostring(args.ModuleId or "")
				local module = findModule(profile.CurrentCategory, moduleId)
				local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
				local mount = cockpit and cockpit:FindFirstChild("SLOT_" .. slotId, true)
				local slotType = mount and garageServer_string(mount, "ModuleType", moduleTypeFromText(slotId))
				local moduleType = moduleTypeForModel(module)
				if not module then ok, message = false, "Module not found."
				elseif not mount then ok, message = false, "Slot not found on this cockpit."
				elseif slotType and slotType ~= "" and moduleType ~= slotType then ok, message = false, "That module does not fit this slot."
				elseif not moduleFitsSlot(module, slotId, mount and garageServer_string(mount, "AllowedModuleFolder", "")) then ok, message = false, "That module does not fit this slot."
				else
					local lockMessage = moduleLockedMessage(profile, module)
					if lockMessage then
						ok, message = false, lockMessage
					else
						local price = modulePurchasePrice(module)
						if not profile.OwnedModules[moduleId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							MoneyService.Debit(profile, price, "LegacyModule")
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
					setLeaderstats(player, profile)
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
							if channel ~= "Neon" or profile.NeonOwned[installedSlot] == true then 
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
				if ok then if slotId=="ALL" then ok,message=moduleInstances.CaptureAll(profile,moduleUpgrades.GetLevels(player)) else ok,message=moduleInstances.CaptureSlot(profile,slotId,moduleUpgrades.GetLevels(player)) end end
			elseif action == "UpgradeModule" then
				ok, message = moduleUpgrades.Purchase(
					player,
					profile,
					tostring(args.SlotId or ""),
					tostring(args.ModuleId or ""),
					tostring(args.UpgradeId or ""),
					findModule,
					moduleTypeForModel
				)
				setLeaderstats(player, profile)
				if ok then local captured,captureMessage=moduleInstances.CaptureSlot(profile,tostring(args.SlotId or ""),moduleUpgrades.GetLevels(player)); if not captured then ok,message=false,captureMessage end end
			elseif action == "Upgrade" then
				local upgradeId = tostring(args.UpgradeId or "")
				local category = garageServer_categoryFolder(profile.CurrentCategory)
				local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
				local template = upgradeRoot and upgradeRoot:FindFirstChild("UPGRADE_" .. upgradeId)
				if not template then ok, message = false, "Upgrade not found." else
					local level = profile.UpgradeLevels[upgradeId] or 0
					local maxLevel = garageServer_number(template, "MaxLevel", 5)
					local price = garageServer_number(template, "PricePerLevel", 0) * (level + 1)
					if level >= maxLevel then ok, message = false, "Already max level."
					elseif profile.Cash < price then ok, message = false, "Not enough cash."
					else MoneyService.Debit(profile, price, "LegacyUpgrade"); profile.UpgradeLevels[upgradeId] = level + 1; setLeaderstats(player, profile); ok, message = true, "Upgrade installed." end
				end
			elseif action == "BuyNeon" then
				local slotId = tostring(args.SlotId or "")
				local moduleId = profile.InstalledModules[slotId]
				local module = moduleId and findModule(profile.CurrentCategory, moduleId)
				if not module then ok, message = false, "Install that module first."
				elseif not folderHasBuyableNeon(module:FindFirstChild("NEON_OptionalLights", true)) then ok, message = false, "This module has no optional neon."
				else
					local price = math.max(0, garageServer_number(module, "NeonPrice", 5000)) 
					if not profile.NeonOwned[slotId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							MoneyService.Debit(profile, price, "Neon")
							profile.NeonOwned[slotId] = true
							profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
							profile.ModuleColors[slotId].Neon = profile.ModuleColors[slotId].Neon or Color3.fromRGB(255, 255, 255)
							ok, message = true, "Neon unlocked."
						end
					else ok, message = true, "Neon already unlocked." end
					setLeaderstats(player, profile)
				end
				if ok then local captured,captureMessage=moduleInstances.CaptureSlot(profile,slotId,moduleUpgrades.GetLevels(player)); if not captured then ok,message=false,captureMessage end end
			elseif action == "SetThrustColor" then
				-- Compatibility action remains gated by the vehicle-specific entitlement.
				ok,message=vehicleCosmetics.SetColour(profile,"ThrustColour",args.Color,function() return moduleInstances.CaptureAll(profile,moduleUpgrades.GetLevels(player)) end)
			elseif action == "DespawnVehicle" then
				ok, message = despawnVehicle(player)
			elseif action == "ExitVehicle" then
				ok, message = exitVehicle(player)
			elseif action == "ReEnterVehicle" then
				ok, message = reEnterVehicle(player)
			elseif action == "SpawnOwnedVehicleFromFreeRoam" then
				ok, message = spawnOwnedVehicleFromFreeRoam(player, profile, args)
			elseif action == "SpawnVehicle" then
				if not coreModulesEquipped(profile) then
					ok, message = false, "Equip at least one engine, stabilisers, and boost before customising or driving."
				else
					local vehicle, err = buildVehicle(player, profile)
					ok, message = vehicle ~= nil, err or "Vehicle spawned."
				end
			else
				ok, message = false, "Unknown garage action."
			end
			if ok == true then
				local validProfile,validationMessage=moduleInstances.Validate(profile); if not validProfile then error("Module instance invariant failed before persistence after "..tostring(action)..": "..tostring(validationMessage)) end
				mirrorLegacyProfileToPersistence(player, profile, action, mutatingActions[action] == true)
				if action=="BuyCockpitInstance" then
					local onboarding=game:GetService("ServerStorage"):WaitForChild("Runtime").Player:FindFirstChild("OnboardingProgress")
					if onboarding and onboarding:IsA("BindableEvent") then onboarding:Fire(player,"FirstVehiclePurchased") end
				end 

			end
			if action == "SetCockpitColor" or action == "SetModuleColor" or action == "SetThrustColor" or action == "SetVehicleCosmeticColor" or action == "SetAllNeonColor" then
				if args.ReturnProfile==true then return {Success=ok==true,Message=message,Profile=profileForClient(profile)} end
				return { Success = ok == true, Message = message, ColorOnly = true }
			end
			return { Success = ok == true, Message = message, Profile = profileForClient(profile) }
		end)
		if okCall and typeof(result) == "table" then return result end
		warn("[GarageServer] Garage action failed: " .. tostring(result))
		return { Success = false, Message = "Garage server action failed. Please try again." }
	end

	invoke.OnServerInvoke = function(player, action, args)
		return requestGuard.run(player, action, args, function() return handleGarageRequest(player, action, args) end)
	end
	local function initialiseGaragePlayer(player)
		local ok, message = pcall(function() if getProfileServiceProfile(player) then setLeaderstats(player, getProfile(player)) end end)
		if not ok and player.Parent == Players then warn("[Garage] Profile initialisation unavailable: " .. tostring(message)) end
	end
	Players.PlayerAdded:Connect(initialiseGaragePlayer)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(initialiseGaragePlayer, player) end

	print("[GarageServer] Consolidated server action controller is active.")
end


end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
