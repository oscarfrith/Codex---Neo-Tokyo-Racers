-- Neo Tokyo Racers - Persistence Phase 1 Audit
-- Read-only verification for PlayerProfileSchema.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PHASE = "Persistence Phase 1 Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function warnLine(message)
	warn("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local schemaModule = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Data")
	:WaitForChild("PlayerProfileSchema")

local schema = require(schemaModule)
local profile = schema.DefaultProfile(140000)

assertTrue(profile.SchemaVersion == 1, "SchemaVersion should be 1.")
assertTrue(profile.Garage.Capacity == 2, "Default garage capacity should be 2.")
assertTrue(profile.Garage.AccessMode == "Private", "Default garage access mode should be Private.")
assertTrue(profile.Garage.Customisation.FloorMaterial == "Metal", "Default floor material should be Metal.")
assertTrue(schema.CanAddVehicle(profile) == true, "Empty profile should be able to add a vehicle.")

profile.OwnedCockpitInstances.cockpit_001 = {
	TemplateId = "COCKPIT_BRUISER_01",
	VehicleId = "vehicle_001",
	AcquiredAtUnix = 0,
}
profile.OwnedModuleInstances.module_001 = {
	TemplateId = "MODULE_BOOST_BRUISER_01_STANDARD",
	EquippedVehicleId = "vehicle_001",
	UpgradeLevels = {},
	Colors = {
		Primary = Color3.fromRGB(0, 205, 230),
		Secondary = Color3.fromRGB(235, 247, 204),
		Detail = Color3.fromRGB(38, 44, 50),
		Neon = Color3.fromRGB(255, 255, 255),
		ThrustColor = Color3.fromRGB(255, 255, 255),
	},
	NeonOwned = false,
}
profile.OwnedModuleInstances.module_002 = {
	TemplateId = "MODULE_BOOST_BRUISER_01_STANDARD",
	EquippedVehicleId = nil,
	UpgradeLevels = {},
	Colors = {},
	NeonOwned = false,
}
profile.Vehicles.vehicle_001 = {
	DisplayName = "Bruiser 01",
	CategoryId = "bruiser",
	CockpitInstanceId = "cockpit_001",
	InstalledModules = {
		Boost = "module_001",
	},
	CockpitColors = {
		Primary = Color3.fromRGB(0, 205, 230),
		Secondary = Color3.fromRGB(235, 247, 204),
		Detail = Color3.fromRGB(38, 44, 50),
		Neon = Color3.fromRGB(255, 255, 255),
		FrontLights = Color3.fromRGB(252, 250, 255),
		RearLights = Color3.fromRGB(255, 116, 116),
	},
	ThrustColor = Color3.fromRGB(255, 255, 255),
}

local summary = schema.Summarize(profile)
assertTrue(summary.VehicleCount == 1, "Expected one vehicle instance in test profile.")
assertTrue(summary.CockpitInstanceCount == 1, "Expected one cockpit instance in test profile.")
assertTrue(summary.ModuleInstanceCount == 2, "Expected two owned module instances in test profile.")
assertTrue(summary.CanAddVehicle == true, "One vehicle in a two-capacity garage should still allow another vehicle.")

profile.Vehicles.vehicle_002 = {
	DisplayName = "Bruiser 02",
	CategoryId = "bruiser",
	CockpitInstanceId = "cockpit_002",
	InstalledModules = {},
	CockpitColors = {},
	ThrustColor = Color3.fromRGB(255, 255, 255),
}
assertTrue(schema.CanAddVehicle(profile) == false, "Two vehicles in a two-capacity garage should block another cockpit purchase.")

local safe, jsonOrError = schema.AssertDataStoreSafe(profile)
assertTrue(safe, "Profile should be DataStore-safe: " .. tostring(jsonOrError))

local encoded = schema.ToDataStore(profile)
local decoded = schema.FromDataStore(encoded, 140000)
assertTrue(typeof(encoded.Garage.Customisation.FloorColor) == "table", "Encoded Color3 should be a table.")
assertTrue(typeof(decoded.Garage.Customisation.FloorColor) == "Color3", "Decoded garage colour should be Color3.")
assertTrue(decoded.Garage.Capacity == 2, "Decoded garage capacity should remain 2.")
assertTrue(schema.Summarize(decoded).ModuleInstanceCount == 2, "Decoded duplicate module instances should remain separate.")

local jsonSize = #HttpService:JSONEncode(encoded)
if jsonSize > 50000 then
	warnLine("Test profile JSON is larger than expected: " .. tostring(jsonSize) .. " bytes.")
end

info("PASS: PlayerProfileSchema exists and requires.")
info("PASS: Default capacity is 2 and duplicate module instances are supported.")
info("PASS: Capacity gate blocks a third vehicle when two vehicles exist.")
info("PASS: Color3 values encode to DataStore-safe tables and decode back to Color3.")
info("PASS: Encoded test profile JSON size is " .. tostring(jsonSize) .. " bytes.")
info("No live gameplay scripts were changed by this audit.")
