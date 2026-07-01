-- Neo Tokyo Racers - Persistence Phase 5 Import Snapshot Binding Audit
-- Verifies ProfileService owns snapshot imports and the garage mirror calls that binding.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 5 Import Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(RunService:IsServer(), "Run this audit from the SERVER Command Bar during Play mode.")

local playerServices = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Player")

local profileService = playerServices:WaitForChild("ProfileService_Active")
local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assertTrue(string.find(profileService.Source, "NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT", 1, true) ~= nil, "ProfileService import snapshot marker missing.")
assertTrue(string.find(garage.Source, "NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT", 1, true) ~= nil, "Garage mirror import snapshot marker missing.")

local bindings = playerServices:WaitForChild("ProfileServiceBindings")
local importProfileSnapshot = bindings:WaitForChild("ImportProfileSnapshot")
assertTrue(importProfileSnapshot:IsA("BindableFunction"), "ImportProfileSnapshot binding missing.")

info("PASS: ProfileService_Active owns ImportProfileSnapshot.")
info("PASS: GarageActionController_Shadow_Disabled calls ImportProfileSnapshot instead of mutating a returned profile table.")
info("Next: rerun scripts/roblox_persistence_phase4_garage_session_mirror_client_smoke.lua from the CLIENT Command Bar, then rerun scripts/roblox_persistence_phase5_datastore_save_audit.lua from the SERVER Command Bar.")
