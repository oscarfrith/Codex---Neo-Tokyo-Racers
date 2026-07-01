-- Persistence Phase 16 client smoke.
--
-- Run from the CLIENT Command Bar in Play mode after installing:
-- scripts/roblox_persistence_phase16_module_family_locks_and_sorting.lua

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
local categories = initial.Catalog.Categories or {}
local category = categories[1]
assert(category, "No vehicle category in catalog.")

local function flattenModules()
	local result = {}
	for _, list in pairs(category.Modules or {}) do
		for _, module in ipairs(list) do
			table.insert(result, module)
		end
	end
	return result
end

local function ownsCockpit(cockpitId)
	if cockpitId == nil or tostring(cockpitId) == "" then
		return true
	end
	if profile.OwnedCockpits and profile.OwnedCockpits[cockpitId] == true then
		return true
	end
	for _, instance in pairs(profile.OwnedCockpitInstances or {}) do
		if tostring(instance.TemplateId or "") == tostring(cockpitId) then
			return true
		end
	end
	return false
end

local modules = flattenModules()
assert(#modules > 0, "No modules in catalog.")

local metadataCount = 0
local pricedStandardCount = 0
local lockedCandidate = nil
local ownedCandidate = nil

for _, module in ipairs(modules) do
	if module.SourceCockpitId ~= nil and module.SourceCockpitId ~= "" then
		metadataCount += 1
		if tostring(module.VariantName or "") == "Standard" and tonumber(module.Price or 0) and tonumber(module.Price or 0) > 0 then
			pricedStandardCount += 1
		end
		if ownsCockpit(module.SourceCockpitId) then
			ownedCandidate = ownedCandidate or module
		else
			lockedCandidate = lockedCandidate or module
		end
	end
end

assert(metadataCount > 0, "No module SourceCockpitId metadata found. Phase 16 server catalog patch may not be active.")
assert(pricedStandardCount > 0, "No priced Standard modules found. Extra standard module copies must cost money.")
assert(ownedCandidate, "Could not find an owned-source module candidate.")
assert(lockedCandidate, "Could not find a locked-source module candidate. If this player owns every cockpit, test with a fresh account/session.")

local lockedResult = invoke:InvokeServer("BuyModuleInstance", { ModuleId = lockedCandidate.ModuleId })
assert(typeof(lockedResult) == "table", "BuyModuleInstance did not return a table.")
assert(lockedResult.Success == false, "Locked module purchase unexpectedly succeeded: " .. tostring(lockedCandidate.ModuleId))
assert(string.find(tostring(lockedResult.Message or ""), "Buy", 1, true), "Locked purchase did not return a clear cockpit requirement message.")

print("[NTR Persistence Phase 16 Smoke] PASS: module catalog exposes source cockpit metadata.")
print("[NTR Persistence Phase 16 Smoke] PASS: extra Standard module copies have non-zero prices.")
print("[NTR Persistence Phase 16 Smoke] PASS: locked-source module purchase was blocked server-side.")
print("[NTR Persistence Phase 16 Smoke] Manual check: open Build Modules and verify owned/free copies appear left, buyable modules next, locked modules right.")
