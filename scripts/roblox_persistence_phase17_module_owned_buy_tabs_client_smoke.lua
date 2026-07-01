-- Persistence Phase 17 client smoke.
--
-- Run from the CLIENT Command Bar in Play mode after installing:
-- scripts/roblox_persistence_phase17_module_owned_buy_tabs.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
assert(player, "Run this from the CLIENT Command Bar in Play mode.")

local remotes = ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local invoke = remotes:WaitForChild("GarageInvoke")

local initial = invoke:InvokeServer("GetInitial", {})
assert(typeof(initial) == "table" and initial.Success == true, "GetInitial failed.")
assert(typeof(initial.Catalog) == "table", "Missing catalog.")
assert(typeof(initial.Profile) == "table", "Missing profile.")

local profile = initial.Profile
local category = (initial.Catalog.Categories or {})[1]
assert(category, "No vehicle category in catalog.")

local function isRearEngine(module)
	local moduleFolder = tostring(module.ModuleFolder or "")
	local moduleId = tostring(module.ModuleId or "")
	local enginePosition = tostring(module.EnginePosition or "")
	if enginePosition == "Front" then
		return false
	end
	if enginePosition == "Rear" then
		return true
	end
	return module.RearEngine == true or moduleFolder == "Engines_B" or string.find(moduleId, "ENGINE_B", 1, true) ~= nil
end

local engineModules = (category.Modules and category.Modules.Engine) or {}
assert(#engineModules > 0, "No Engine modules in catalog.")

local frontCount = 0
local rearCount = 0
for _, module in ipairs(engineModules) do
	if isRearEngine(module) then
		rearCount += 1
	else
		frontCount += 1
	end
end

assert(typeof(profile.OwnedModuleInstances) == "table", "OwnedModuleInstances missing from profile.")
assert(typeof(profile.Vehicles) == "table", "Vehicles missing from profile.")

local ownedInstanceCount = 0
for _ in pairs(profile.OwnedModuleInstances) do
	ownedInstanceCount += 1
end
assert(ownedInstanceCount > 0, "No owned module instances found. Buy/select a cockpit first so starter modules exist.")

if frontCount > 0 and rearCount > 0 then
	print("[NTR Persistence Phase 17 Smoke] PASS: catalog contains separately identifiable front and rear engine templates. Front=" .. tostring(frontCount) .. ", Rear=" .. tostring(rearCount))
else
	warn("[NTR Persistence Phase 17 Smoke] WARNING: catalog did not expose both front and rear engine metadata to this smoke. Manual slot UI check is required. Front=" .. tostring(frontCount) .. ", Rear=" .. tostring(rearCount))
end
print("[NTR Persistence Phase 17 Smoke] PASS: profile exposes " .. tostring(ownedInstanceCount) .. " owned module instance(s) for per-copy cards.")
print("[NTR Persistence Phase 17 Smoke] Manual check: select Front Engine and confirm rear engines are hidden; select Rear Engine and confirm front engines are hidden.")
print("[NTR Persistence Phase 17 Smoke] Manual check: module slot first shows OWNED MODULES and BUY MODULES; owned copy cards are separate; buy menu uses BUY and owned menu uses EQUIP.")
