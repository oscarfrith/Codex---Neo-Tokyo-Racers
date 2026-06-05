local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local KIT_NAME = "HOVER_RACING_V2_KIT"
local WORLD_NAME = "HOVER_RACING_V2_WORLD"

local kit = ReplicatedStorage:WaitForChild(KIT_NAME)
local remotes = kit:WaitForChild("REMOTES_DoNotRename")
local invoke = remotes:WaitForChild("GarageInvoke")
local categoriesRoot = kit:WaitForChild("VEHICLE_CATEGORIES")
local world = Workspace:WaitForChild(WORLD_NAME)
local vehiclesRoot = world:WaitForChild("PLAYER_VEHICLES_Runtime")

local STARTING_CASH = kit:GetAttribute("StartingCash") or 140000
local SPAWN_POS = Vector3.new(kit:GetAttribute("SpawnX") or 860, kit:GetAttribute("SpawnY") or 105, kit:GetAttribute("SpawnZ") or -1713)
local STATS = { "Weight", "Power", "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Boost", "BoostDuration", "BoostRecharge" }

local profiles = {}

local function colour(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function defaultProfile()
	return {
		Cash = STARTING_CASH,
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
		ThrustColor = colour(255, 255, 255),
		OwnedModules = {},
		InstalledModules = {},
		ModuleColors = {},
		NeonOwned = {},
		UpgradeLevels = { Brakes = 0, Converter = 0, FuelSystem = 0 },
		ModuleUpgradeLevels = {},
	}
end

local function getProfile(player)
	local profile = profiles[player.UserId]
	if not profile then
		profile = defaultProfile()
		profiles[player.UserId] = profile
	end
	return profile
end

local function attrs(instance)
	local result = {}
	for key, value in pairs(instance:GetAttributes()) do
		local t = typeof(value)
		if t == "string" or t == "number" or t == "boolean" or t == "Color3" then
			result[key] = value
		end
	end
	return result
end

local function getCategoryFolder(categoryId)
	for _, category in ipairs(categoriesRoot:GetChildren()) do
		if category:GetAttribute("CategoryId") == categoryId then
			return category
		end
	end
end

local function findCockpit(categoryId, cockpitId)
	local category = getCategoryFolder(categoryId)
	local root = category and category:FindFirstChild("COCKPITS_ReplaceAssetsHere")
	if not root then return nil end
	for _, item in ipairs(root:GetChildren()) do
		if item:IsA("Model") and item:GetAttribute("CockpitId") == cockpitId then
			return item
		end
	end
end

local function findModule(categoryId, moduleId)
	local category = getCategoryFolder(categoryId)
	local root = category and category:FindFirstChild("MODULES_InterchangeableWithinCategory")
	if not root then return nil end
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("ModuleId") == moduleId then
			return item
		end
	end
end

local function getSlotTemplate(categoryId, cockpitId, slotId)
	local cockpit = findCockpit(categoryId, cockpitId)
	return cockpit and cockpit:FindFirstChild("SLOT_" .. slotId, true)
end

local function sortedSlots(cockpit)
	local result = {}
	local root = cockpit and cockpit:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename")
	if root then
		for _, slot in ipairs(root:GetChildren()) do
			table.insert(result, attrs(slot))
		end
	end
	table.sort(result, function(a, b)
		return (a.Order or 99) < (b.Order or 99)
	end)
	return result
end

local function modulesByType(categoryId, moduleType)
	local category = getCategoryFolder(categoryId)
	local root = category and category:FindFirstChild("MODULES_InterchangeableWithinCategory")
	local result = {}
	if root then
		for _, item in ipairs(root:GetDescendants()) do
			if item:IsA("Model") and item:GetAttribute("ModuleType") == moduleType then
				table.insert(result, attrs(item))
			end
		end
	end
	table.sort(result, function(a, b)
		local af, bf = tostring(a.ModuleFolder or ""), tostring(b.ModuleFolder or "")
		if af ~= bf then return af < bf end
		return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
	end)
	return result
end

local function serializeCatalog()
	local catalog = {
		Categories = {},
		PaintPresets = {},
		PreviewPosition = Vector3.new(kit:GetAttribute("PreviewX") or 860, kit:GetAttribute("PreviewY") or 104, kit:GetAttribute("PreviewZ") or -1749),
	}

	local presets = kit:FindFirstChild("PAINT_PRESETS_EditColoursHere")
	if presets then
		for _, preset in ipairs(presets:GetChildren()) do
			if preset:IsA("Color3Value") then
				table.insert(catalog.PaintPresets, { Name = preset.Name, Color = preset.Value })
			end
		end
	end

	for _, category in ipairs(categoriesRoot:GetChildren()) do
		local cat = attrs(category)
		cat.Cockpits = {}
		cat.Slots = {}
		cat.Modules = {}
		cat.Upgrades = {}

		local cockpitRoot = category:FindFirstChild("COCKPITS_ReplaceAssetsHere")
		if cockpitRoot then
			for _, cockpit in ipairs(cockpitRoot:GetChildren()) do
				if cockpit:IsA("Model") then
					local c = attrs(cockpit)
					c.AvailableModules = {}
					local slots = sortedSlots(cockpit)
					if #cat.Slots == 0 then
						cat.Slots = slots
					end
					for _, slot in ipairs(slots) do
						local moduleType = slot.ModuleType
						if moduleType then
							c.AvailableModules[moduleType] = (c.AvailableModules[moduleType] or 0) + 1
						end
					end
					table.insert(cat.Cockpits, c)
				end
			end
		end

		local moduleRoot = category:FindFirstChild("MODULES_InterchangeableWithinCategory")
		if moduleRoot then
			for _, folder in ipairs(moduleRoot:GetChildren()) do
				local moduleType = folder:GetAttribute("ModuleType")
				if moduleType then
					cat.Modules[moduleType] = modulesByType(cat.CategoryId, moduleType)
				end
			end
		end

		local upgradeRoot = category:FindFirstChild("UPGRADES_InvisiblePerformance")
		if upgradeRoot then
			for _, upgrade in ipairs(upgradeRoot:GetChildren()) do
				table.insert(cat.Upgrades, attrs(upgrade))
			end
		end

		table.sort(cat.Cockpits, function(a, b)
			return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
		end)
		table.insert(catalog.Categories, cat)
	end

	return catalog
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
	cash.Value = profile.Cash or 0
end

local function statNumber(instance, stat)
	return instance and tonumber(instance:GetAttribute(stat)) or 0
end

local function computeTotalStats(profile)
	local totals = {}
	local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
	for _, stat in ipairs(STATS) do
		totals[stat] = statNumber(cockpit, stat)
	end
	for _, moduleId in pairs(profile.InstalledModules or {}) do
		local module = findModule(profile.CurrentCategory, moduleId)
		if module then
			for _, stat in ipairs(STATS) do
				totals[stat] += statNumber(module, stat)
			end
		end
	end
	local category = getCategoryFolder(profile.CurrentCategory)
	local upgrades = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
	if upgrades then
		for upgradeId, level in pairs(profile.UpgradeLevels or {}) do
			local upgrade = upgrades:FindFirstChild("UPGRADE_" .. upgradeId)
			if upgrade then
				local statName = upgrade:GetAttribute("StatName")
				local amount = tonumber(upgrade:GetAttribute("AmountPerLevel")) or 0
				if statName then
					totals[statName] = (totals[statName] or 0) + amount * (tonumber(level) or 0)
				end
			end
		end
	end
	return totals
end

local function profileForClient(profile)
	profile.CockpitColors = profile.CockpitColors or {}
	profile.CockpitColors.FrontLights = profile.CockpitColors.FrontLights or Color3.fromRGB(252, 250, 255)
	profile.CockpitColors.RearLights = profile.CockpitColors.RearLights or Color3.fromRGB(255, 116, 116)
	profile.ThrustColor = profile.ThrustColor or Color3.fromRGB(255, 255, 255)
	return {
		Cash = profile.Cash,
		CurrentCategory = profile.CurrentCategory,
		CurrentCockpit = profile.CurrentCockpit,
		OwnedCockpits = profile.OwnedCockpits,
		CockpitColors = profile.CockpitColors,
		ThrustColor = profile.ThrustColor,
		OwnedModules = profile.OwnedModules,
		InstalledModules = profile.InstalledModules,
		ModuleColors = profile.ModuleColors,
		NeonOwned = profile.NeonOwned,
		UpgradeLevels = profile.UpgradeLevels,
		TotalStats = computeTotalStats(profile),
	}
end


local function buyableValue(item, name)
	if not item then return nil end
	local attr = item:GetAttribute(name)
	if attr ~= nil then return attr end
	local child = item:FindFirstChild(name)
	if child and child:IsA("ValueBase") then return child.Value end
	return nil
end

local function buyableNumber(item, name, fallback)
	local value = buyableValue(item, name)
	if typeof(value) == "number" then return value end
	if typeof(value) == "string" then
		local number = tonumber(value)
		if number then return number end
	end
	return fallback
end

local function buyableString(item, name, fallback)
	local value = buyableValue(item, name)
	if typeof(value) == "string" then return value end
	return fallback
end


local function buyCockpit(player, args)
	local profile = getProfile(player)
	profile.OwnedCockpits = profile.OwnedCockpits or {}
	profile.CockpitColors = profile.CockpitColors or {}
	local cockpitId = tostring(args.CockpitId or "")
	local cockpit = findCockpit(profile.CurrentCategory, cockpitId)
	if not cockpit then return false, "Cockpit not found." end
	local price = buyableNumber(cockpit, "Price", 0)
	if not profile.OwnedCockpits[cockpitId] then
		if profile.Cash < price then return false, "Not enough cash." end
		profile.Cash -= price
		profile.OwnedCockpits[cockpitId] = true
	end
	profile.CurrentCockpit = cockpitId
	profile.CockpitColors.FrontLights = profile.CockpitColors.FrontLights or Color3.fromRGB(252, 250, 255)
	profile.CockpitColors.RearLights = profile.CockpitColors.RearLights or Color3.fromRGB(255, 116, 116)
	profile.CockpitColors.Neon = profile.CockpitColors.Neon or Color3.fromRGB(255, 255, 255)
	profile.ThrustColor = profile.ThrustColor or Color3.fromRGB(255, 255, 255)
	setLeaderstats(player, profile)
	return true, "Cockpit selected."
end


local function setCockpitColor(player, args)
	local profile = getProfile(player)
	profile.CockpitColors = profile.CockpitColors or {}
	local channel = tostring(args.Channel or "Primary")
	local color = args.Color
	if typeof(color) ~= "Color3" then return false, "Invalid colour." end
	if channel ~= "Primary" and channel ~= "Secondary" and channel ~= "Detail" and channel ~= "Neon" and channel ~= "FrontLights" and channel ~= "RearLights" then
		return false, "Invalid colour channel."
	end
	profile.CockpitColors[channel] = color
	return true, "Colour updated."
end


local function buyModule(player, args)
	local profile = getProfile(player)
	profile.ModuleColors = profile.ModuleColors or {}
	profile.OwnedModules = profile.OwnedModules or {}
	profile.InstalledModules = profile.InstalledModules or {}
	profile.ThrustColor = profile.ThrustColor or Color3.fromRGB(255, 255, 255)
	local slotId = tostring(args.SlotId or "")
	local moduleId = tostring(args.ModuleId or "")
	local module = findModule(profile.CurrentCategory, moduleId)
	if not module then return false, "Module not found." end

	local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
	local mount = cockpit and cockpit:FindFirstChild("SLOT_" .. slotId, true)
	if not mount then return false, "Slot not found on this cockpit." end
	local expectedType = mount:GetAttribute("ModuleType")
	if expectedType ~= module:GetAttribute("ModuleType") then return false, "That module does not fit this slot." end

	local price = module:GetAttribute("Price") or 0
	if not profile.OwnedModules[moduleId] then
		if profile.Cash < price then return false, "Not enough cash." end
		profile.Cash -= price
		profile.OwnedModules[moduleId] = true
	end
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
	setLeaderstats(player, profile)
	return true, "Module installed."
end


local function setModuleColor(player, args)
	local profile = getProfile(player)
	profile.ModuleColors = profile.ModuleColors or {}
	profile.CockpitColors = profile.CockpitColors or {}
	local slotId = tostring(args.SlotId or "")
	local channel = tostring(args.Channel or "Primary")
	local color = args.Color
	if typeof(color) ~= "Color3" then return false, "Invalid colour." end
	if channel ~= "Primary" and channel ~= "Secondary" and channel ~= "Detail" and channel ~= "Neon" then
		return false, "Invalid channel."
	end
	if not profile.InstalledModules[slotId] and slotId ~= "ALL" then return false, "No module selected." end

	if slotId == "ALL" then
		if channel ~= "Neon" then
			profile.CockpitColors[channel] = color
		end
		for installedSlot in pairs(profile.InstalledModules or {}) do
			profile.ModuleColors[installedSlot] = profile.ModuleColors[installedSlot] or {}
			profile.ModuleColors[installedSlot][channel] = color
		end
	else
		profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
		profile.ModuleColors[slotId][channel] = color
	end
	return true, "Colour updated."
end


local function upgrade(player, args)
	local profile = getProfile(player)
	profile.UpgradeLevels = profile.UpgradeLevels or { Brakes = 0, Converter = 0, FuelSystem = 0 }
	local upgradeId = tostring(args.UpgradeId or "")
	local category = getCategoryFolder(profile.CurrentCategory)
	local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
	local template = upgradeRoot and upgradeRoot:FindFirstChild("UPGRADE_" .. upgradeId)
	if not template then return false, "Upgrade not found." end
	local level = profile.UpgradeLevels[upgradeId] or 0
	local maxLevel = buyableNumber(template, "MaxLevel", 5)
	if level >= maxLevel then return false, "Already max level." end
	local price = buyableNumber(template, "PricePerLevel", 0) * (level + 1)
	if not buyableHasEnoughCash(profile, price) then return false, "Not enough cash." end
	profile.Cash -= price
	profile.UpgradeLevels[upgradeId] = level + 1
	setLeaderstats(player, profile)
	return true, "Upgrade installed."
end


local function V46_folderHasBuyableNeon(folder)
	if not folder then return false end
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
			or descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight") then
			return true
		end
	end
	return false
end

local function V46_moduleHasOptionalNeon(module)
	if not module then return false end
	local folder = module:FindFirstChild("NEON_OptionalLights", true)
	return V46_folderHasBuyableNeon(folder)
end

local function folderHasBuyableNeon(folder)
	if not folder then return false end
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
			or descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight") then
			return true
		end
	end
	return false
end

local function moduleHasOptionalNeon(module)
	if not module then return false end
	return folderHasBuyableNeon(module:FindFirstChild("NEON_OptionalLights", true))
end

local function buyNeon(player, args)
	local profile = getProfile(player)
	profile.NeonOwned = profile.NeonOwned or {}
	profile.ModuleColors = profile.ModuleColors or {}
	local slotId = tostring(args.SlotId or "")
	local moduleId = profile.InstalledModules and profile.InstalledModules[slotId]
	if not moduleId then return false, "Install that module first." end
	local module = findModule(profile.CurrentCategory, moduleId)
	if not module then return false, "Module template not found." end
	if not moduleHasOptionalNeon(module) then return false, "This module has no optional neon." end
	if not profile.NeonOwned[slotId] then
		local price = module:GetAttribute("NeonPrice") or 5000
		if profile.Cash < price then return false, "Not enough cash." end
		profile.Cash -= price
		profile.NeonOwned[slotId] = true
		profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
		profile.ModuleColors[slotId].Neon = profile.ModuleColors[slotId].Neon or Color3.fromRGB(255, 255, 255)
	end
	setLeaderstats(player, profile)
	return true, "Neon unlocked."
end

local function setThrustColor(player, args)
	local profile = getProfile(player)
	local color = args.Color
	if typeof(color) ~= "Color3" then return false, "Invalid thrust colour." end
	profile.ThrustColor = color
	for slotId, moduleId in pairs(profile.InstalledModules or {}) do
		local module = findModule(profile.CurrentCategory, moduleId)
		local moduleType = module and module:GetAttribute("ModuleType")
		if moduleType == "Engine" or moduleType == "Boost" or moduleType == "Stabilisers" then
			profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
			profile.ModuleColors[slotId].ThrustColor = color
		end
	end
	return true, "Thrust colour updated."
end


local function exitVehicle(player)
	local vehicle = nil
	for _, candidate in ipairs(vehiclesRoot:GetChildren()) do
		if candidate:GetAttribute("OwnerUserId") == player.UserId then
			vehicle = candidate
			break
		end
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

local function reEnterVehicle(player)
	local vehicle = nil
	for _, candidate in ipairs(vehiclesRoot:GetChildren()) do
		if candidate:GetAttribute("OwnerUserId") == player.UserId then
			vehicle = candidate
			break
		end
	end
	if not vehicle then return false, "No vehicle nearby." end
	local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
	local seat = vehicle:FindFirstChild("DriverSeat", true)
	if root then
		vehicle.PrimaryPart = root
		pcall(function() root:SetNetworkOwner(player) end)
	end
	if seat and seat:IsA("VehicleSeat") then
		vehicle:SetAttribute("DriveReady", true)
		vehicle:SetAttribute("DriverUserId", player.UserId)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRoot then humanoidRoot.CFrame = seat.CFrame + Vector3.new(0, 2, 0) end
		if humanoid then
			task.wait(0.05)
			seat:Sit(humanoid)
		end
		return true, "Entered vehicle."
	end
	return false, "Driver seat missing."
end


invoke.OnServerInvoke = function(player, action, args)
	args = typeof(args) == "table" and args or {}
	local profile = getProfile(player)
	local ok, message

	if action == "GetInitial" then
		setLeaderstats(player, profile)
		return { Success = true, Catalog = serializeCatalog(), Profile = profileForClient(profile) }
	elseif action == "BuyCockpit" then
		ok, message = buyCockpit(player, args)
	elseif action == "SetCockpitColor" then
		ok, message = setCockpitColor(player, args)
	elseif action == "BuyModule" then
		ok, message = buyModule(player, args)
	elseif action == "SetModuleColor" then
		ok, message = setModuleColor(player, args)
	elseif action == "Upgrade" then
		ok, message = upgrade(player, args)
	elseif action == "BuyNeon" then
		ok, message = buyNeon(player, args)
	elseif action == "SetThrustColor" then
		local color = args.Color
		if typeof(color) == "Color3" then
			profile.ThrustColor = color
			for slotId in pairs(profile.InstalledModules or {}) do
				profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
				profile.ModuleColors[slotId].ThrustColor = color
			end
			ok, message = true, "Thrust colour updated."
		else
			ok, message = false, "Invalid thrust colour."
		end
	elseif action == "ExitVehicle" then
		ok, message = exitVehicle(player)
	elseif action == "ReEnterVehicle" then
		ok, message = reEnterVehicle(player)
	elseif action == "SpawnVehicle" then
		local vehicle, err = buildVehicle(player, profile)
		ok, message = vehicle ~= nil, err or "Vehicle spawned."
	else
		ok, message = false, "Unknown garage action."
	end

	return { Success = ok == true, Message = message, Profile = profileForClient(profile) }
end


Players.PlayerAdded:Connect(function(player)
	setLeaderstats(player, getProfile(player))
end)

Players.PlayerRemoving:Connect(function(player)
	profiles[player.UserId] = nil
end)


-- V56_CONSOLIDATED_ACTION_CONTROLLER_BEGIN
do
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local V56_KIT_NAME = "HOVER_RACING_V2_KIT"
	local V56_WORLD_NAME = "HOVER_RACING_V2_WORLD"
	local V56_kit = ReplicatedStorage:WaitForChild(V56_KIT_NAME)
	local V56_remotes = V56_kit:WaitForChild("REMOTES_DoNotRename")
	local V56_invoke = V56_remotes:WaitForChild("GarageInvoke")
	local V56_categoriesRoot = V56_kit:WaitForChild("VEHICLE_CATEGORIES")
	local V56_world = Workspace:FindFirstChild(V56_WORLD_NAME)
	if not V56_world then
		V56_world = Instance.new("Folder")
		V56_world.Name = V56_WORLD_NAME
		V56_world.Parent = Workspace
	end
	local V56_vehiclesRoot = V56_world:FindFirstChild("PLAYER_VEHICLES_Runtime")
	if not V56_vehiclesRoot then
		V56_vehiclesRoot = Instance.new("Folder")
		V56_vehiclesRoot.Name = "PLAYER_VEHICLES_Runtime"
		V56_vehiclesRoot.Parent = V56_world
	end
	local V56_STARTING_CASH = V56_kit:GetAttribute("StartingCash") or 140000
	local V56_SPAWN_POS = Vector3.new(V56_kit:GetAttribute("SpawnX") or 860, V56_kit:GetAttribute("SpawnY") or 105, V56_kit:GetAttribute("SpawnZ") or -1713)
	local V56_PREVIEW_POS = Vector3.new(V56_kit:GetAttribute("PreviewX") or 860, V56_kit:GetAttribute("PreviewY") or 104, V56_kit:GetAttribute("PreviewZ") or -1749)
	local V56_profiles = {}

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
		if typeof(attr) == "string" and attr ~= "" then return attr end
		local text = module.Name
		local parent = module.Parent
		while parent and parent ~= root do
			text ..= " " .. parent.Name
			parent = parent.Parent
		end
		return V56_moduleTypeFromText(text)
	end

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
						Order = V56_number(slot, "Order", #slots + 1),
					})
				end
			end
		end
		if #slots == 0 then
			slots = {
				{ SlotId = "Engine1", DisplayName = "Front Engine", ModuleType = "Engine", Order = 1 },
				{ SlotId = "Engine2", DisplayName = "Rear Engine", ModuleType = "Engine", Order = 2 },
				{ SlotId = "Stabilisers", DisplayName = "Stabilisers", ModuleType = "Stabilisers", Order = 3 },
				{ SlotId = "Boost", DisplayName = "Boost", ModuleType = "Boost", Order = 4 },
				{ SlotId = "FrontBumper", DisplayName = "Front Bumper", ModuleType = "FrontBumper", Order = 5 },
				{ SlotId = "RearBumper", DisplayName = "Rear Bumper", ModuleType = "RearBumper", Order = 6 },
				{ SlotId = "RearSpoiler", DisplayName = "Rear Spoiler", ModuleType = "RearSpoiler", Order = 7 },
				{ SlotId = "SidePods", DisplayName = "Side Pods", ModuleType = "SidePods", Order = 8 },
			}
		end
		table.sort(slots, function(a, b) return (a.Order or 99) < (b.Order or 99) end)
		return slots
	end

	local function V56_nearestModuleFolder(root, item)
		local current = item.Parent
		local best = ""
		while current and current ~= root do
			if current:IsA("Folder") then best = current.Name end
			current = current.Parent
		end
		return best
	end

	local function V56_readModule(item, root)
		local moduleType = V56_moduleTypeForModel(item, root)
		return {
			ModuleId = V56_string(item, "ModuleId", item.Name),
			DisplayName = V56_string(item, "DisplayName", V56_string(item, "ModuleName", item.Name)),
			ModuleType = moduleType,
			ModuleSlot = V56_string(item, "ModuleSlot", moduleType),
			ModuleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item)),
			Price = V56_number(item, "Price", 0),
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
		}
	end

	local function V56_catalog()
		local catalog = {
			Categories = {},
			PaintPresets = {},
			PreviewPosition = V56_PREVIEW_POS,
		}
		local presetRoot = V56_kit:FindFirstChild("PAINT_PRESETS_EditColoursHere")
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
						if module:IsA("Model") and module:GetAttribute("ModuleId") then
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
				table.sort(category.Cockpits, function(a, b) return tostring(a.DisplayName) < tostring(b.DisplayName) end)
				if #category.Cockpits > 0 then table.insert(catalog.Categories, category) end
			end
		end
		table.sort(catalog.Categories, function(a, b) return tostring(a.DisplayName) < tostring(b.DisplayName) end)
		return catalog
	end

	local function V56_totalStats(profile)
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
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			if module then
				for _, stat in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostDuration", "BoostRecharge" }) do
					totals[stat] = (totals[stat] or 0) + V56_number(module, stat, 0)
				end
			end
		end
		local category = V56_categoryFolder(profile.CurrentCategory)
		local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
		if upgradeRoot then
			for upgradeId, level in pairs(profile.UpgradeLevels or {}) do
				local upgrade = upgradeRoot:FindFirstChild("UPGRADE_" .. upgradeId)
				if upgrade then
					local statName = V56_string(upgrade, "StatName", V56_string(upgrade, "Stat", nil))
					local amount = V56_number(upgrade, "AmountPerLevel", V56_number(upgrade, "Amount", 0))
					if statName then totals[statName] = (totals[statName] or 0) + amount * level end
				end
			end
		end
		return totals
	end

	local function V56_profileForClient(profile)
		V56_normalizeProfile(profile)
		return {
			Cash = profile.Cash,
			CurrentCategory = profile.CurrentCategory,
			CurrentCockpit = profile.CurrentCockpit,
			OwnedCockpits = profile.OwnedCockpits,
			CockpitColors = profile.CockpitColors,
			ThrustColor = profile.ThrustColor,
			OwnedModules = profile.OwnedModules,
			InstalledModules = profile.InstalledModules,
			ModuleColors = profile.ModuleColors,
			NeonOwned = profile.NeonOwned,
			UpgradeLevels = profile.UpgradeLevels,
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

	local function V56_weldVehicle(model, root)
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = descendant == root
				descendant.CanQuery = false
				if descendant ~= root then
					descendant.Massless = true
					local weld = Instance.new("WeldConstraint")
					weld.Name = "V56_FixedVehicleWeld"
					weld.Part0 = root
					weld.Part1 = descendant
					weld.Parent = descendant
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
		vehicle:PivotTo(CFrame.lookAt(V56_SPAWN_POS, V56_SPAWN_POS + Vector3.new(0, 0, 1)))
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
			local ok, message
			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }
			elseif action == "BuyCockpit" then
				local cockpitId = tostring(args.CockpitId or "")
				local cockpit = V56_findCockpit(profile.CurrentCategory, cockpitId)
				if not cockpit then ok, message = false, "Cockpit not found." else
					local price = V56_number(cockpit, "Price", 0)
					if not profile.OwnedCockpits[cockpitId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							profile.Cash -= price
							profile.OwnedCockpits[cockpitId] = true
							ok, message = true, "Cockpit selected."
						end
					else ok, message = true, "Cockpit selected." end
					if ok then profile.CurrentCockpit = cockpitId end
					V56_setLeaderstats(player, profile)
				end
			elseif action == "SetCockpitColor" then
				local channel = tostring(args.Channel or "Primary")
				local color = args.Color
				if typeof(color) ~= "Color3" then ok, message = false, "Invalid colour."
				elseif channel ~= "Primary" and channel ~= "Secondary" and channel ~= "Detail" and channel ~= "Neon" and channel ~= "FrontLights" and channel ~= "RearLights" then ok, message = false, "Invalid colour channel."
				else profile.CockpitColors[channel] = color; ok, message = true, "Colour updated." end
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
				else
					local price = V56_number(module, "Price", 0)
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
				local vehicle, err = V56_buildVehicle(player, profile)
				ok, message = vehicle ~= nil, err or "Vehicle spawned."
			else
				ok, message = false, "Unknown garage action."
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
