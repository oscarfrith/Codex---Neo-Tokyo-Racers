-- Neo Tokyo Racers player profile schema.
-- Persistence Phase 1 foundation. This module is data-only and does not save/load DataStores.

local HttpService = game:GetService("HttpService")

local PlayerProfileSchema = {}

PlayerProfileSchema.SchemaVersion = 1

PlayerProfileSchema.AccessModes = {
	Private = true,
	FriendsOnly = true,
	InviteOnly = true,
	Public = true,
}

PlayerProfileSchema.DefaultMaterials = {
	FloorMaterial = "Metal",
	WallMaterial = "Concrete",
	CeilingMaterial = "Concrete",
	TrimMaterial = "Metal",
}

local function cloneValue(value)
	if typeof(value) == "table" then
		local copy = {}
		for key, child in pairs(value) do
			copy[key] = cloneValue(child)
		end
		return copy
	end
	return value
end

local function defaultColor(r, g, b)
	return Color3.fromRGB(r, g, b)
end

function PlayerProfileSchema.GenerateId(prefix)
	prefix = tostring(prefix or "id")
	local guid = string.gsub(HttpService:GenerateGUID(false), "-", "")
	return prefix .. "_" .. string.sub(guid, 1, 12)
end

function PlayerProfileSchema.DefaultGarageCustomisation()
	return {
		FloorColor = defaultColor(28, 34, 38),
		WallColor = defaultColor(18, 22, 28),
		CeilingColor = defaultColor(14, 18, 24),
		AccentColor = defaultColor(67, 255, 202),
		LightingAccentColor = defaultColor(67, 255, 202),
		FloorMaterial = "Metal",
		WallMaterial = "Concrete",
		CeilingMaterial = "Concrete",
		TrimMaterial = "Metal",
		Decorations = {},
	}
end

function PlayerProfileSchema.DefaultGarage()
	return {
		Capacity = 2,
		ActiveGarageId = "garage_001",
		EntranceId = "ApartmentBlock_Default",
		AccessMode = "Private",
		-- NTR_PERSISTENCE_PHASE13_GARAGE_PROPERTIES
		OwnedGarageProperties = {},
		InvitedUserIds = {},
		DisplaySpaces = {
			Space1 = { VehicleId = nil },
			Space2 = { VehicleId = nil },
		},
		Customisation = PlayerProfileSchema.DefaultGarageCustomisation(),
	}
end

function PlayerProfileSchema.DefaultProfile(startingCash)
	return {
		SchemaVersion = PlayerProfileSchema.SchemaVersion,
		Cash = typeof(startingCash) == "number" and startingCash or 140000,
		Garage = PlayerProfileSchema.DefaultGarage(),
		Vehicles = {},
		OwnedCockpitInstances = {},
		OwnedModuleInstances = {},
		OwnedDecorations = {},
		CurrentVehicleId = nil,
		LegacyMigration = {
			Source = "PersistencePhase1_Default",
			MigratedAtUnix = 0,
		},
	}
end

local function countDictionary(dictionary)
	local count = 0
	for _ in pairs(dictionary or {}) do
		count += 1
	end
	return count
end

local function normalizeAccessMode(mode)
	mode = tostring(mode or "Private")
	if PlayerProfileSchema.AccessModes[mode] then
		return mode
	end
	return "Private"
end

local function normalizeMaterialName(value, fallback)
	value = tostring(value or fallback or "Metal")
	local ok, material = pcall(function()
		return Enum.Material[value]
	end)
	if ok and material ~= nil then
		return value
	end
	return fallback or "Metal"
end

local function normalizeColor(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if typeof(value) == "table" then
		local r = value.r or value.R or value[1]
		local g = value.g or value.G or value[2]
		local b = value.b or value.B or value[3]
		if typeof(r) == "number" and typeof(g) == "number" and typeof(b) == "number" then
			if r <= 1 and g <= 1 and b <= 1 then
				return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
			end
			return Color3.fromRGB(math.clamp(math.floor(r + 0.5), 0, 255), math.clamp(math.floor(g + 0.5), 0, 255), math.clamp(math.floor(b + 0.5), 0, 255))
		end
	end
	return fallback
end

local function normalizeGarageCustomisation(customisation)
	local defaults = PlayerProfileSchema.DefaultGarageCustomisation()
	customisation = typeof(customisation) == "table" and customisation or {}
	customisation.FloorColor = normalizeColor(customisation.FloorColor, defaults.FloorColor)
	customisation.WallColor = normalizeColor(customisation.WallColor, defaults.WallColor)
	customisation.CeilingColor = normalizeColor(customisation.CeilingColor, defaults.CeilingColor)
	customisation.AccentColor = normalizeColor(customisation.AccentColor, defaults.AccentColor)
	customisation.LightingAccentColor = normalizeColor(customisation.LightingAccentColor, defaults.LightingAccentColor)
	customisation.FloorMaterial = normalizeMaterialName(customisation.FloorMaterial, defaults.FloorMaterial)
	customisation.WallMaterial = normalizeMaterialName(customisation.WallMaterial, defaults.WallMaterial)
	customisation.CeilingMaterial = normalizeMaterialName(customisation.CeilingMaterial, defaults.CeilingMaterial)
	customisation.TrimMaterial = normalizeMaterialName(customisation.TrimMaterial, defaults.TrimMaterial)
	customisation.Decorations = typeof(customisation.Decorations) == "table" and customisation.Decorations or {}
	return customisation
end

local function ensureDisplaySpaces(garage)
	garage.DisplaySpaces = typeof(garage.DisplaySpaces) == "table" and garage.DisplaySpaces or {}
	for index = 1, math.max(1, math.floor(garage.Capacity or 2)) do
		local key = "Space" .. tostring(index)
		garage.DisplaySpaces[key] = typeof(garage.DisplaySpaces[key]) == "table" and garage.DisplaySpaces[key] or { VehicleId = nil }
	end
	return garage.DisplaySpaces
end

function PlayerProfileSchema.Normalize(profile, startingCash)
	profile = typeof(profile) == "table" and profile or PlayerProfileSchema.DefaultProfile(startingCash)
	profile.SchemaVersion = PlayerProfileSchema.SchemaVersion
	profile.Cash = typeof(profile.Cash) == "number" and profile.Cash or (typeof(startingCash) == "number" and startingCash or 140000)
	profile.Garage = typeof(profile.Garage) == "table" and profile.Garage or PlayerProfileSchema.DefaultGarage()
	profile.Garage.Capacity = math.max(1, math.floor(tonumber(profile.Garage.Capacity) or 2))
	profile.Garage.ActiveGarageId = tostring(profile.Garage.ActiveGarageId or "garage_001")
	profile.Garage.EntranceId = tostring(profile.Garage.EntranceId or "ApartmentBlock_Default")
	profile.Garage.AccessMode = normalizeAccessMode(profile.Garage.AccessMode)
	profile.Garage.OwnedGarageProperties = typeof(profile.Garage.OwnedGarageProperties) == "table" and profile.Garage.OwnedGarageProperties or {}
	profile.Garage.InvitedUserIds = typeof(profile.Garage.InvitedUserIds) == "table" and profile.Garage.InvitedUserIds or {}
	profile.Garage.Customisation = normalizeGarageCustomisation(profile.Garage.Customisation)
	ensureDisplaySpaces(profile.Garage)
	profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
	profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
	profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	profile.OwnedDecorations = typeof(profile.OwnedDecorations) == "table" and profile.OwnedDecorations or {}
	profile.CurrentVehicleId = profile.CurrentVehicleId ~= nil and tostring(profile.CurrentVehicleId) or nil
	profile.LegacyMigration = typeof(profile.LegacyMigration) == "table" and profile.LegacyMigration or {}
	return profile
end

function PlayerProfileSchema.CanAddVehicle(profile)
	profile = PlayerProfileSchema.Normalize(profile)
	return countDictionary(profile.Vehicles) < profile.Garage.Capacity
end

function PlayerProfileSchema.Summarize(profile)
	profile = PlayerProfileSchema.Normalize(profile)
	return {
		SchemaVersion = profile.SchemaVersion,
		Cash = profile.Cash,
		GarageCapacity = profile.Garage.Capacity,
		AccessMode = profile.Garage.AccessMode,
		VehicleCount = countDictionary(profile.Vehicles),
		GaragePropertyCount = countDictionary(profile.Garage.OwnedGarageProperties),
		CockpitInstanceCount = countDictionary(profile.OwnedCockpitInstances),
		ModuleInstanceCount = countDictionary(profile.OwnedModuleInstances),
		DecorationKindCount = countDictionary(profile.OwnedDecorations),
		CanAddVehicle = PlayerProfileSchema.CanAddVehicle(profile),
	}
end

local function encodeColor(color)
	return {
		__type = "Color3",
		r = math.floor(color.R * 255 + 0.5),
		g = math.floor(color.G * 255 + 0.5),
		b = math.floor(color.B * 255 + 0.5),
	}
end

local function encodeValue(value)
	local t = typeof(value)
	if t == "Color3" then
		return encodeColor(value)
	end
	if t == "EnumItem" then
		return tostring(value.Name)
	end
	if t == "table" then
		local copy = {}
		for key, child in pairs(value) do
			local encodedChild = encodeValue(child)
			if encodedChild ~= nil then
				copy[key] = encodedChild
			end
		end
		return copy
	end
	if t == "string" or t == "number" or t == "boolean" or t == "nil" then
		return value
	end
	return nil
end

local function decodeValue(value)
	if typeof(value) == "table" then
		if value.__type == "Color3" then
			return normalizeColor(value, Color3.new(1, 1, 1))
		end
		local copy = {}
		for key, child in pairs(value) do
			if key ~= "__type" then
				copy[key] = decodeValue(child)
			end
		end
		return copy
	end
	return value
end

function PlayerProfileSchema.ToDataStore(profile)
	return encodeValue(PlayerProfileSchema.Normalize(cloneValue(profile)))
end

function PlayerProfileSchema.FromDataStore(data, startingCash)
	return PlayerProfileSchema.Normalize(decodeValue(data), startingCash)
end

function PlayerProfileSchema.AssertDataStoreSafe(profile)
	local encoded = PlayerProfileSchema.ToDataStore(profile)
	local ok, result = pcall(function()
		return HttpService:JSONEncode(encoded)
	end)
	if not ok then
		return false, tostring(result)
	end
	return true, result
end

return PlayerProfileSchema
