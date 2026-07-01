-- Neo Tokyo Racers - Persistence Phase 2 Client Probe
-- Optional client-side check for whether ProfileService replicated player attributes.
-- This does not replace the server audit.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PHASE = "Persistence Phase 2 Client Probe"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

if RunService:IsServer() then
	info("This probe is intended for the CLIENT Command Bar. For the full audit, run scripts/roblox_persistence_phase2_profile_service_audit.lua from the SERVER Command Bar.")
	return
end

local player = Players.LocalPlayer
if not player then
	error("No LocalPlayer found. Run this during Play mode from the client.")
end

local loaded = false
for _ = 1, 80 do
	if player:GetAttribute("NTR_ProfileServiceLoaded") == true then
		loaded = true
		break
	end
	task.wait(0.1)
end

if not loaded then
	error("ProfileService did not replicate NTR_ProfileServiceLoaded=true to the local player. Confirm Phase 2 installer was run, then use the SERVER audit for details.")
end

info("PASS: Local player has NTR_ProfileServiceLoaded=true.")
info("SchemaVersion=" .. tostring(player:GetAttribute("NTR_ProfileSchemaVersion")))
info("DataStoreEnabled=" .. tostring(player:GetAttribute("NTR_ProfileDataStoreEnabled")))
info("Now run scripts/roblox_persistence_phase2_profile_service_audit.lua from the SERVER Command Bar for the full bindable/runtime profile audit.")
