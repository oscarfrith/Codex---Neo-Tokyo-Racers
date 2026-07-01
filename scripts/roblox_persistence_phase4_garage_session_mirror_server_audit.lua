-- Neo Tokyo Racers - Persistence Phase 4 Server Audit
-- Verifies the guarded garage session mirror patch and server-side dependencies.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 4 Server Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(RunService:IsServer(), "Run this audit from the SERVER Command Bar during Play mode.")

local serverRoot = ServerScriptService:WaitForChild("NeoTokyoRacers")
local playerServices = serverRoot:WaitForChild("Services"):WaitForChild("Player")
local garage = serverRoot:WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageActionController_Shadow_Disabled")

assertTrue(garage:IsA("Script") and garage.Disabled == false, "GarageActionController_Shadow_Disabled should be an enabled Script.")
local source = garage.Source
assertTrue(string.find(source, "NTR_PERSISTENCE_PHASE4_SESSION_MIRROR", 1, true) ~= nil, "Phase 4 marker missing from garage controller source.")
assertTrue(string.find(source, "V80_mirrorLegacyProfileToPersistence(player, profile, action, false)", 1, true) ~= nil, "GetInitial mirror call missing.")
assertTrue(string.find(source, "V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)", 1, true) ~= nil, "Final response mirror call missing.")

local profileBindings = playerServices:WaitForChild("ProfileServiceBindings")
local bridgeBindings = playerServices:WaitForChild("LegacyGarageProfileBridgeBindings")
assertTrue(profileBindings:FindFirstChild("GetProfile") ~= nil, "ProfileService GetProfile binding missing.")
assertTrue(profileBindings:FindFirstChild("MarkDirty") ~= nil, "ProfileService MarkDirty binding missing.")
assertTrue(bridgeBindings:FindFirstChild("ConvertLegacyProfile") ~= nil, "Legacy bridge ConvertLegacyProfile binding missing.")

info("PASS: Garage controller contains the Phase 4 session mirror patch.")
info("PASS: ProfileService and legacy bridge bindables required by the mirror are present.")
info("PASS: No DataStore setting is changed by this audit.")
info("Next: run scripts/roblox_persistence_phase4_garage_session_mirror_client_smoke.lua from the CLIENT Command Bar during Play mode.")
