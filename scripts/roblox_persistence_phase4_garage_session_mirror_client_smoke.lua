-- Neo Tokyo Racers - Persistence Phase 4 Client Smoke Test
-- Calls the current GarageInvoke GetInitial path and verifies the server mirror attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PHASE = "Persistence Phase 4 Client Smoke"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

assertTrue(not RunService:IsServer(), "Run this smoke test from the CLIENT Command Bar during Play mode.")

local player = Players.LocalPlayer
assertTrue(player ~= nil, "LocalPlayer missing. Run during Play mode from the client.")

local invoke = ReplicatedStorage
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Shared")
	:WaitForChild("Remotes")
	:WaitForChild("Garage")
	:WaitForChild("GarageInvoke")

local result = invoke:InvokeServer("GetInitial", {})
assertTrue(typeof(result) == "table" and result.Success == true, "GetInitial failed: " .. tostring(result and result.Message))
assertTrue(typeof(result.Profile) == "table", "GetInitial did not return a profile table.")

local mirrored = false
for _ = 1, 80 do
	if player:GetAttribute("NTR_PersistenceMirrorLastAction") == "GetInitial" then
		mirrored = true
		break
	end
	task.wait(0.1)
end

assertTrue(mirrored, "Server did not set NTR_PersistenceMirrorLastAction=GetInitial.")
assertTrue((player:GetAttribute("NTR_PersistenceMirrorVehicleCount") or 0) >= 1, "Mirrored profile should contain at least one vehicle instance after GetInitial.")
assertTrue((player:GetAttribute("NTR_PersistenceMirrorModuleInstanceCount") or 0) >= 1, "Mirrored profile should contain default module instances after GetInitial.")

info("PASS: GetInitial still succeeds through the active garage RemoteFunction.")
info("PASS: Server mirrored the legacy garage profile into the persistence bridge.")
info("PASS: Mirrored vehicle count = " .. tostring(player:GetAttribute("NTR_PersistenceMirrorVehicleCount")))
info("PASS: Mirrored module instance count = " .. tostring(player:GetAttribute("NTR_PersistenceMirrorModuleInstanceCount")))
