-- Neo Tokyo Racers - Persistence Phase 15 client smoke test
-- Run from the CLIENT Command Bar during Play.
--
-- This is intentionally light: it does not spend cash. It verifies the Phase 14
-- instance fields still exist and, if the garage UI is open, checks for visible
-- Phase 15 duplicate-copy controls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PHASE = "Persistence Phase 15 Client Smoke"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function findButtonContaining(root, text)
	text = string.upper(tostring(text or ""))
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("TextButton") and string.find(string.upper(item.Text or ""), text, 1, true) then
			return item
		end
	end
	return nil
end

assertTrue(not RunService:IsServer(), "Run this smoke test from the CLIENT Command Bar during Play mode.")

local player = Players.LocalPlayer
assertTrue(player ~= nil, "LocalPlayer missing. Run during Play mode from the client.")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local invoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")

local initial = invoke:InvokeServer("GetInitial", {})
assertTrue(typeof(initial) == "table" and initial.Success == true, "GetInitial failed: " .. tostring(initial and initial.Message))
local profile = initial.Profile
assertTrue(typeof(profile) == "table", "GetInitial profile missing.")
assertTrue(typeof(profile.Vehicles) == "table", "Vehicles table missing. Run Phase 14 first.")
assertTrue(typeof(profile.OwnedCockpitInstances) == "table", "OwnedCockpitInstances table missing. Run Phase 14 first.")
assertTrue(typeof(profile.OwnedModuleInstances) == "table", "OwnedModuleInstances table missing. Run Phase 14 first.")

info("PASS: Phase 14 instance inventory fields are still present.")

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI") or playerGui:WaitForChild("HOVER_RACING_V2_GarageUI", 2)
if not gui then
	info("SKIP: Garage UI is not loaded yet. Reach the dealership desk/open the garage, then manually confirm Buy Another and module copy buttons.")
	return
end

local buyAnother = findButtonContaining(gui, "BUY ANOTHER")
if buyAnother then
	info("PASS: cockpit Buy Another button is visible.")
else
	info("SKIP: cockpit Buy Another button is not visible right now. Open cockpit selection on an owned cockpit to verify it.")
end

local copyButton = findButtonContaining(gui, "COPY")
if copyButton then
	info("PASS: a module copy button is visible.")
else
	info("SKIP: module copy buttons appear only after selecting an owned, not-currently-installed module option.")
end

info("PASS: Phase 15 smoke completed without forcing a purchase.")
