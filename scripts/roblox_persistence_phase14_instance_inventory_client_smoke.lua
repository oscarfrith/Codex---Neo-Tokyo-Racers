-- Neo Tokyo Racers - Persistence Phase 14 client smoke test
-- Run from the CLIENT Command Bar during Play.
--
-- Verifies that the server now exposes instance-backed inventory fields and
-- duplicate-copy actions while keeping the existing dealership profile shape.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PHASE = "Persistence Phase 14 Client Smoke"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function assertTrue(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function countDictionary(dictionary)
	local count = 0
	for _ in pairs(dictionary or {}) do
		count += 1
	end
	return count
end

local function findNewKey(before, after)
	for key in pairs(after or {}) do
		if not before or before[key] == nil then
			return key
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
assertTrue(typeof(profile.OwnedCockpits) == "table", "Legacy OwnedCockpits missing.")
assertTrue(typeof(profile.OwnedModules) == "table", "Legacy OwnedModules missing.")
assertTrue(typeof(profile.InstalledModules) == "table", "Legacy InstalledModules missing.")
assertTrue(typeof(profile.Vehicles) == "table", "Phase 14 Vehicles table missing.")
assertTrue(typeof(profile.OwnedCockpitInstances) == "table", "Phase 14 OwnedCockpitInstances table missing.")
assertTrue(typeof(profile.OwnedModuleInstances) == "table", "Phase 14 OwnedModuleInstances table missing.")
assertTrue(profile.CurrentVehicleId ~= nil, "Phase 14 CurrentVehicleId missing.")
assertTrue(countDictionary(profile.Vehicles) >= 1, "Phase 14 should create at least one vehicle instance from legacy ownership.")

info("PASS: GetInitial exposes legacy UI fields plus Phase 14 instance inventory fields.")

local currentCockpit = tostring(profile.CurrentCockpit or "")
if currentCockpit ~= "" then
	local beforeVehicleCount = countDictionary(profile.Vehicles)
	local beforeCockpitInstances = profile.OwnedCockpitInstances
	local cockpitResult = invoke:InvokeServer("BuyCockpitInstance", { CockpitId = currentCockpit })
	assertTrue(typeof(cockpitResult) == "table", "BuyCockpitInstance did not return a table.")
	if cockpitResult.Success then
		local after = cockpitResult.Profile
		assertTrue(typeof(after) == "table" and typeof(after.Vehicles) == "table", "BuyCockpitInstance response missing Vehicles.")
		assertTrue(countDictionary(after.Vehicles) == beforeVehicleCount + 1, "BuyCockpitInstance did not add exactly one vehicle instance.")
		assertTrue(findNewKey(beforeCockpitInstances, after.OwnedCockpitInstances) ~= nil, "BuyCockpitInstance did not add a cockpit instance.")
		assertTrue(after.OwnedCockpits[currentCockpit] == true, "Legacy OwnedCockpits compatibility was not preserved.")
		info("PASS: BuyCockpitInstance created a duplicate-capable cockpit/vehicle instance.")
		profile = after
	else
		local message = tostring(cockpitResult.Message or "")
		assertTrue(message:find("Garage full", 1, true) or message:find("Not enough cash", 1, true), "Unexpected BuyCockpitInstance failure: " .. message)
		info("PASS: BuyCockpitInstance exists and was correctly blocked: " .. message)
		profile = cockpitResult.Profile or profile
	end
end

local chosenSlotId = nil
local chosenModuleId = nil
for slotId, moduleId in pairs(profile.InstalledModules or {}) do
	chosenSlotId = tostring(slotId)
	chosenModuleId = tostring(moduleId)
	break
end

if not chosenModuleId then
	info("SKIP: no installed modules were available to test BuyModuleInstance/EquipModuleInstance.")
	return
end

local beforeModuleInstances = profile.OwnedModuleInstances
local moduleResult = invoke:InvokeServer("BuyModuleInstance", { ModuleId = chosenModuleId })
assertTrue(typeof(moduleResult) == "table", "BuyModuleInstance did not return a table.")
if not moduleResult.Success then
	local message = tostring(moduleResult.Message or "")
	assertTrue(message:find("Not enough cash", 1, true), "Unexpected BuyModuleInstance failure: " .. message)
	info("PASS: BuyModuleInstance exists and was correctly blocked by cash: " .. message)
	return
end

local afterModuleBuy = moduleResult.Profile
assertTrue(typeof(afterModuleBuy) == "table" and typeof(afterModuleBuy.OwnedModuleInstances) == "table", "BuyModuleInstance response missing OwnedModuleInstances.")
local newModuleInstanceId = findNewKey(beforeModuleInstances, afterModuleBuy.OwnedModuleInstances)
assertTrue(newModuleInstanceId ~= nil, "BuyModuleInstance did not add a module instance.")
local newModuleInstance = afterModuleBuy.OwnedModuleInstances[newModuleInstanceId]
assertTrue(newModuleInstance.TemplateId == chosenModuleId, "New module instance has the wrong template id.")
assertTrue(newModuleInstance.EquippedVehicleId == nil, "New module instance should start unequipped.")
info("PASS: BuyModuleInstance created a separate unequipped module copy.")

local equipResult = invoke:InvokeServer("EquipModuleInstance", {
	ModuleInstanceId = newModuleInstanceId,
	VehicleId = afterModuleBuy.CurrentVehicleId,
	SlotId = chosenSlotId,
})
assertTrue(typeof(equipResult) == "table", "EquipModuleInstance did not return a table.")
assertTrue(equipResult.Success == true, "EquipModuleInstance failed: " .. tostring(equipResult.Message))
local afterEquip = equipResult.Profile
assertTrue(afterEquip.OwnedModuleInstances[newModuleInstanceId].EquippedVehicleId == afterEquip.CurrentVehicleId, "Equipped module copy did not record its vehicle.")
assertTrue(afterEquip.InstalledModules[chosenSlotId] == chosenModuleId, "Legacy InstalledModules compatibility was not preserved.")
info("PASS: EquipModuleInstance installed one specific module copy on the current vehicle.")
info("PASS: Phase 14 instance inventory bridge is working.")
