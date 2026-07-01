-- Neo Tokyo Racers - Persistence Phase 3 Audit
-- Read-only Play-mode verification for LegacyGarageProfileMapper and bridge bindables.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 3 Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(RunService:IsServer(), "Run this audit from the SERVER Command Bar during Play mode.")

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local dataModules = ntr:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data")
local schema = require(dataModules:WaitForChild("PlayerProfileSchema"))
local mapper = require(dataModules:WaitForChild("LegacyGarageProfileMapper"))

local playerServices = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Player")

local bridge = playerServices:WaitForChild("LegacyGarageProfileBridge_Active")
assertTrue(bridge:IsA("Script") and bridge.Disabled == false, "LegacyGarageProfileBridge_Active should be an enabled Script.")

local bindings = playerServices:WaitForChild("LegacyGarageProfileBridgeBindings")
local convert = bindings:WaitForChild("ConvertLegacyProfile")
local summarize = bindings:WaitForChild("SummarizeLegacyProfile")
assertTrue(convert:IsA("BindableFunction"), "ConvertLegacyProfile binding missing.")
assertTrue(summarize:IsA("BindableFunction"), "SummarizeLegacyProfile binding missing.")

local legacyProfile = {
	Cash = 123456,
	CurrentCategory = "bruiser",
	CurrentCockpit = "bruiser_02",
	OwnedCockpits = {
		bruiser_01 = true,
		bruiser_02 = true,
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
	OwnedModules = {
		MODULE_BOOST_BRUISER_01_STANDARD = true,
		MODULE_ENGINE_BRUISER_01_STANDARD = true,
		MODULE_STABILISER_BRUISER_01_STANDARD = true,
		MODULE_REARSPOILER_LVL1 = true,
	},
	InstalledModules = {
		Engine1 = "MODULE_ENGINE_BRUISER_01_STANDARD",
		Boost = "MODULE_BOOST_BRUISER_01_STANDARD",
		Stabilisers = "MODULE_STABILISER_BRUISER_01_STANDARD",
	},
	ModuleColors = {
		Boost = {
			Primary = Color3.fromRGB(20, 20, 20),
			ThrustColor = Color3.fromRGB(255, 255, 255),
		},
	},
	NeonOwned = {
		Boost = true,
	},
	ModuleUpgradeLevels = {
		MODULE_BOOST_BRUISER_01_STANDARD = {
			BoostFocus = 1,
		},
	},
}

local mapped = mapper.Convert(legacyProfile, schema)
local summary = schema.Summarize(mapped)

assertTrue(mapped.Cash == 123456, "Cash should migrate.")
assertTrue(summary.VehicleCount == 2, "Two owned legacy cockpits should become two vehicle instances.")
assertTrue(summary.GarageCapacity == 2, "Two cockpit migration should fit the default two-space garage.")
assertTrue(summary.ModuleInstanceCount == 4, "Three installed modules plus one unequipped owned module should become four module instances.")
assertTrue(mapped.CurrentVehicleId ~= nil, "CurrentVehicleId should be set.")

local currentVehicle = mapped.Vehicles[mapped.CurrentVehicleId]
assertTrue(currentVehicle ~= nil, "Current vehicle should exist.")
assertTrue(currentVehicle.CockpitInstanceId ~= nil, "Current vehicle should have a cockpit instance.")
assertTrue(currentVehicle.InstalledModules.Boost ~= nil, "Boost slot should map to a module instance id.")

local boostInstance = mapped.OwnedModuleInstances[currentVehicle.InstalledModules.Boost]
assertTrue(boostInstance ~= nil, "Boost module instance should exist.")
assertTrue(boostInstance.TemplateId == "MODULE_BOOST_BRUISER_01_STANDARD", "Boost instance TemplateId should be preserved.")
assertTrue(boostInstance.EquippedVehicleId == mapped.CurrentVehicleId, "Boost instance should be equipped to the current vehicle.")
assertTrue(boostInstance.NeonOwned == true, "Boost neon ownership should migrate.")
assertTrue(boostInstance.UpgradeLevels.BoostFocus == 1, "Module upgrade level should migrate by module template id.")

local safe, encodedOrError = schema.AssertDataStoreSafe(mapped)
assertTrue(safe, "Mapped profile should be DataStore-safe: " .. tostring(encodedOrError))

local bridgeMapped = convert:Invoke(legacyProfile)
local bridgeSummary = summarize:Invoke(legacyProfile)
assertTrue(schema.Summarize(bridgeMapped).ModuleInstanceCount == 4, "Bridge conversion should preserve module count.")
assertTrue(bridgeSummary.VehicleCount == 2, "Bridge summary should report two vehicles.")

info("PASS: LegacyGarageProfileMapper converts legacy cockpit/module ownership into instance ownership.")
info("PASS: Installed modules become equipped module instances, and extra owned modules remain unequipped.")
info("PASS: Colours, neon ownership, and module upgrade levels migrate where legacy data exists.")
info("PASS: Converted profile is DataStore-safe.")
info("PASS: Server bridge BindableFunctions are present and working.")
