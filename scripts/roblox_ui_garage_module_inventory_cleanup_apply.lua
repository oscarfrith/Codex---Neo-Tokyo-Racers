-- Neo Tokyo Racers - Garage module inventory cleanup apply
-- NTR_GARAGE_MODULE_INVENTORY_CLEANUP_APPLY_V1
-- RETIRED 2026-07-16: do not run. The approved testing workflow now uses the
-- targeted offline main-profile reset instead of migrating the corrupt inventory.
-- Run once during a fresh Play session from Studio's Server Command Bar.
-- This script changes and saves one locked player profile.

error("[NTR Garage Module Cleanup Apply] RETIRED - use roblox_player_main_profile_reset_edit_mode.lua in Edit mode instead.", 0)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Garage Module Cleanup Apply] "
local TARGET_USER_ID = 7915427645
local EXPECTED_TOTAL = 1428
local EXPECTED_DELETE = 1358
local EXPECTED_PROTECTED = 50
local EXPECTED_REVIEW = 20
local EXPECTED_REMAINING = 70
local EXPECTED_TOKEN = [=[V1|1428|1358|MODULE_BOOST_BRUISER_01_STANDARD=99|MODULE_BOOST_BRUISER_02_STANDARD=109|MODULE_BOOST_BRUISER_03_STANDARD=23|MODULE_BOOST_BRUISER_05_STANDARD=4|MODULE_BOOST_BRUISER_06_STANDARD=103|MODULE_ENGINE_BRUISER_01_STANDARD=99|MODULE_ENGINE_BRUISER_02_LIGHTWEIGHT=1|MODULE_ENGINE_BRUISER_02_STANDARD=111|MODULE_ENGINE_BRUISER_03_STANDARD=23|MODULE_ENGINE_BRUISER_05_STANDARD=4|MODULE_ENGINE_BRUISER_06_STANDARD=103|MODULE_ENGINE_B_BRUISER_01_STANDARD=99|MODULE_ENGINE_B_BRUISER_02_LIGHTWEIGHT=1|MODULE_ENGINE_B_BRUISER_02_STANDARD=111|MODULE_ENGINE_B_BRUISER_03_STANDARD=23|MODULE_ENGINE_B_BRUISER_05_STANDARD=4|MODULE_ENGINE_B_BRUISER_06_STANDARD=103|MODULE_STABILISER_BRUISER_01_STANDARD=99|MODULE_STABILISER_BRUISER_02_STANDARD=109|MODULE_STABILISER_BRUISER_03_STANDARD=23|MODULE_STABILISER_BRUISER_05_STANDARD=4|MODULE_STABILISER_BRUISER_06_STANDARD=103]=]

local function fail(message)
	error(PREFIX .. tostring(message), 0)
end

local function expect(condition, message)
	if not condition then fail(message) end
end

local function dictionaryCount(dictionary)
	local result = 0
	for _ in pairs(dictionary or {}) do result += 1 end
	return result
end

local function cloneValue(value, seen)
	if typeof(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for key, child in pairs(value) do
		copy[cloneValue(key, seen)] = cloneValue(child, seen)
	end
	return copy
end

local function replaceDictionary(target, replacement)
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(replacement) do target[key] = cloneValue(value) end
end

if not RunService:IsRunning() or not RunService:IsServer() or Players.LocalPlayer then
	fail("Run during Play from the Server Command Bar.")
end

local player = Players:GetPlayerByUserId(TARGET_USER_ID)
expect(player ~= nil, "Target user " .. tostring(TARGET_USER_ID) .. " is not present. No changes made.")

local ntr = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = ntr and ntr:FindFirstChild("Services")
local garage = services and services:FindFirstChild("Garage")
local playerServices = services and services:FindFirstChild("Player")
local bindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
local getProfile = bindings and bindings:FindFirstChild("GetProfile")
local getSummary = bindings and bindings:FindFirstChild("GetSummary")
local markDirty = bindings and bindings:FindFirstChild("MarkDirty")
local saveNow = bindings and bindings:FindFirstChild("SaveNow")
local cleanupTransaction = bindings and bindings:FindFirstChild("GarageModuleInventoryCleanupTransaction")
local runtimeModule = garage and garage:FindFirstChild("GarageModuleInventoryRuntime")
local cleanupBridge = garage and garage:FindFirstChild("GarageModuleInventoryCleanupBridge")

for name, binding in pairs({
	GetProfile = getProfile,
	GetSummary = getSummary,
	MarkDirty = markDirty,
	SaveNow = saveNow,
	GarageModuleInventoryCleanupTransaction = cleanupTransaction,
}) do
	expect(binding and binding:IsA("BindableFunction"), name .. " binding missing. No changes made.")
end
expect(runtimeModule and runtimeModule:IsA("ModuleScript"), "GarageModuleInventoryRuntime missing. No changes made.")
expect(cleanupBridge and cleanupBridge:IsA("BindableFunction"), "Dual-owner cleanup bridge missing. Stop Play and install roblox_ui_garage_module_inventory_cleanup_bridge_install.lua first.")

local profile = getProfile:Invoke(player)
local summary = getSummary:Invoke(player)
expect(typeof(profile) == "table", "Live profile unavailable. No changes made.")
expect(typeof(summary) == "table", "Profile summary unavailable. No changes made.")
expect(summary.DataStoreEnabled == true, "Saved profiles are disabled. Enable ProfileService DataStore access before cleanup; no changes made.")
expect(typeof(profile.OwnedModuleInstances) == "table", "OwnedModuleInstances missing. No changes made.")

local runtime = require(runtimeModule)
local plan = runtime.PlanCleanup(profile)
local references = runtime.ReferenceIndex(profile)

expect(plan.Token == EXPECTED_TOKEN, "Dry-run token changed. Re-run the dry run and review it; no changes made.")
expect(plan.TotalInstances == EXPECTED_TOTAL, "Expected " .. EXPECTED_TOTAL .. " total instances; got " .. tostring(plan.TotalInstances) .. ".")
expect(#plan.DeleteIds == EXPECTED_DELETE, "Expected " .. EXPECTED_DELETE .. " deletion candidates; got " .. tostring(#plan.DeleteIds) .. ".")
expect(#plan.ProtectedIds == EXPECTED_PROTECTED, "Expected " .. EXPECTED_PROTECTED .. " protected instances; got " .. tostring(#plan.ProtectedIds) .. ".")
expect(#plan.ReviewIds == EXPECTED_REVIEW, "Expected " .. EXPECTED_REVIEW .. " review instances; got " .. tostring(#plan.ReviewIds) .. ".")
expect(#plan.MissingReferences == 0, "Installed slot references are missing. No changes made.")

for _, instanceId in ipairs(plan.DeleteIds) do
	local instance = profile.OwnedModuleInstances[instanceId]
	expect(typeof(instance) == "table", "Deletion candidate " .. instanceId .. " is invalid.")
	expect(instance.Source == "LegacyInstalledModules", "Deletion candidate " .. instanceId .. " has an unexpected source.")
	expect(instance.EquippedVehicleId ~= nil and tostring(instance.EquippedVehicleId) ~= "", "Deletion candidate " .. instanceId .. " does not carry the corruption signature.")
	expect(not references[instanceId] or #references[instanceId] == 0, "Deletion candidate " .. instanceId .. " is referenced.")
end

for _, instanceId in ipairs(plan.ReviewIds) do
	local instance = profile.OwnedModuleInstances[instanceId]
	expect(typeof(instance) == "table", "Review instance " .. instanceId .. " is invalid.")
	expect(instance.Source == "IncludedWithCockpit", "Review instance " .. instanceId .. " is not a cockpit grant.")
	expect(not references[instanceId] or #references[instanceId] == 0, "Review instance " .. instanceId .. " is unexpectedly referenced.")
end

local originalInventory = cloneValue(profile.OwnedModuleInstances)
local originalMigration = cloneValue(profile.LegacyMigration)
local changed = false
local legacyOwnerChanged = false
local cleanupLockActive = false

local function endCleanupLock()
	if not cleanupLockActive then
		return true, {BlockedCount = 0, LastBlockedReason = ""}
	end
	local callOk, endOk, result = pcall(function()
		return cleanupTransaction:Invoke(player, "End")
	end)
	if callOk and endOk == true then
		cleanupLockActive = false
		return true, result
	end
	return false, result or endOk
end

local function rollback(reason)
	replaceDictionary(profile.OwnedModuleInstances, originalInventory)
	profile.LegacyMigration = originalMigration
	if legacyOwnerChanged then
		pcall(function() cleanupBridge:Invoke(player, "Rollback", EXPECTED_TOKEN) end)
		legacyOwnerChanged = false
	end
	local dirtyOk = markDirty:Invoke(player, "GarageModuleInventoryCleanupV1Rollback")
	local saveCallOk, saveOk, saveMessage = pcall(function()
		return saveNow:Invoke(player)
	end)
	if not dirtyOk or not saveCallOk or saveOk ~= true then
		endCleanupLock()
		fail(tostring(reason) .. " In-memory rollback completed, but rollback persistence could not be confirmed: " .. tostring(saveMessage))
	end
	local unlockOk, unlockMessage = endCleanupLock()
	if not unlockOk then
		fail(tostring(reason) .. " Original inventory was restored and saved, but the cleanup import lock could not be released: " .. tostring(unlockMessage) .. ". Stop Play before retrying.")
	end
	fail(tostring(reason) .. " Cleanup was rolled back and the original inventory was saved.")
end

local lockCallOk, lockOk, lockMessage = pcall(function()
	return cleanupTransaction:Invoke(player, "Begin")
end)
expect(lockCallOk and lockOk == true,
	"Profile cleanup transaction could not start: " .. tostring(lockMessage or lockOk))
cleanupLockActive = true

local bridgeCallOk, bridgeOk, bridgeResult = pcall(function()
	return cleanupBridge:Invoke(player, "Apply", EXPECTED_TOKEN)
end)
if not bridgeCallOk or bridgeOk ~= true then
	endCleanupLock()
	fail("Legacy compatibility owner could not join the cleanup transaction: " .. tostring(bridgeResult or bridgeOk))
end
legacyOwnerChanged = true
local legacyTotalsValid = typeof(bridgeResult) == "table"
	and bridgeResult.Original == EXPECTED_TOTAL
	and bridgeResult.Removed == EXPECTED_DELETE
	and bridgeResult.Remaining == EXPECTED_REMAINING
if not legacyTotalsValid then
	pcall(function() cleanupBridge:Invoke(player, "Rollback", EXPECTED_TOKEN) end)
	legacyOwnerChanged = false
	endCleanupLock()
	fail("Legacy compatibility owner returned unexpected cleanup totals.")
end

local applyOk, applyError = pcall(function()
	changed = true
	for _, instanceId in ipairs(plan.DeleteIds) do
		profile.OwnedModuleInstances[instanceId] = nil
	end

	-- These are legitimate grants displaced by the bad reconciliation loop.
	-- Preserve them as available inventory rather than deleting them.
	for _, instanceId in ipairs(plan.ReviewIds) do
		local instance = profile.OwnedModuleInstances[instanceId]
		instance.EquippedVehicleId = nil
		instance.AcquisitionKind = "IncludedWithCockpit"
	end

	-- Make installed-slot references authoritative for equipped state. A protected
	-- purchase can legitimately be available even when its old record still names
	-- the vehicle it was previously installed on.
	local postReferences = runtime.ReferenceIndex(profile)
	for instanceIdValue, instance in pairs(profile.OwnedModuleInstances) do
		local instanceId = tostring(instanceIdValue)
		local refs = postReferences[instanceId] or {}
		expect(#refs <= 1, "Instance " .. instanceId .. " is referenced by more than one slot.")
		expect(typeof(instance) == "table", "Preserved instance " .. instanceId .. " is invalid.")
		if #refs == 1 then
			instance.EquippedVehicleId = tostring(refs[1].VehicleId)
		else
			instance.EquippedVehicleId = nil
		end
		instance.AcquisitionKind = instance.AcquisitionKind or tostring(instance.Source or "ExistingInventory")
	end

	profile.LegacyMigration = typeof(profile.LegacyMigration) == "table" and profile.LegacyMigration or {}
	profile.LegacyMigration.GarageModuleInventoryCleanup = {
		Version = "V1",
		AppliedAtUnix = os.time(),
		OriginalInstanceCount = EXPECTED_TOTAL,
		RemovedInstanceCount = EXPECTED_DELETE,
		PreservedCockpitGrantCount = EXPECTED_REVIEW,
	}
	local postPlan = runtime.PlanCleanup(profile)
	local finalReferences, finalMissing = runtime.ReferenceIndex(profile)
	expect(postPlan.TotalInstances == EXPECTED_REMAINING, "Post-cleanup total should be " .. EXPECTED_REMAINING .. "; got " .. tostring(postPlan.TotalInstances) .. ".")
	expect(#postPlan.DeleteIds == 0, "Post-cleanup still has automatic deletion candidates.")
	expect(#postPlan.ProtectedIds == EXPECTED_PROTECTED, "Post-cleanup protected count changed.")
	expect(#postPlan.ReviewIds == EXPECTED_REVIEW, "Post-cleanup cockpit-grant count changed.")
	expect(#finalMissing == 0, "Post-cleanup installed slot reference is missing.")

	local sourceCounts = {}
	for instanceId, instance in pairs(profile.OwnedModuleInstances) do
		expect(typeof(instance) == "table", "Post-cleanup instance " .. tostring(instanceId) .. " is invalid.")
		local source = tostring(instance.Source or "<missing>")
		sourceCounts[source] = (sourceCounts[source] or 0) + 1
		local refs = finalReferences[tostring(instanceId)] or {}
		expect(#refs <= 1, "Post-cleanup instance " .. tostring(instanceId) .. " has multiple references.")
		if #refs == 1 then
			expect(tostring(instance.EquippedVehicleId or "") == tostring(refs[1].VehicleId), "Equipped vehicle mismatch for " .. tostring(instanceId) .. ".")
		else
			expect(instance.EquippedVehicleId == nil, "Unreferenced instance " .. tostring(instanceId) .. " still claims an equipped vehicle.")
		end
	end
	expect(dictionaryCount(profile.OwnedModuleInstances) == EXPECTED_REMAINING, "Inventory count changed during post-check.")
	expect(sourceCounts.LegacyInstalledModules == 44, "Expected 44 referenced legacy instances after cleanup.")
	expect(sourceCounts.BuyModuleInstance == 6, "Expected all 6 purchased instances after cleanup.")
	expect(sourceCounts.IncludedWithCockpit == 20, "Expected all 20 cockpit grants after cleanup.")
end)

if not applyOk then
	if changed then rollback("Post-cleanup validation failed: " .. tostring(applyError)) end
	fail("Pre-mutation validation failed: " .. tostring(applyError))
end

local dirtyOk, dirtyMessage = markDirty:Invoke(player, "GarageModuleInventoryCleanupV1")
if dirtyOk ~= true then rollback("Could not mark the cleaned profile dirty: " .. tostring(dirtyMessage)) end

local saveCallOk, saveOk, saveMessage = pcall(function()
	return saveNow:Invoke(player)
end)
if not saveCallOk or saveOk ~= true then
	rollback("Cleaned profile could not be saved: " .. tostring(saveMessage or saveOk))
end

local savedSummary = getSummary:Invoke(player)
local savedProfile = getProfile:Invoke(player)
local sameLiveProfile = typeof(savedProfile) == "table" and rawequal(savedProfile, profile)
local savedInventoryCount = typeof(savedProfile) == "table"
	and dictionaryCount(savedProfile.OwnedModuleInstances)
	or -1
local summaryInstances = "<missing>"
local summaryDirty = "<missing>"
local summaryDataStore = "<missing>"
if typeof(savedSummary) == "table" then
	summaryInstances = tostring(savedSummary.ModuleInstanceCount)
	summaryDirty = tostring(savedSummary.Dirty)
	summaryDataStore = tostring(savedSummary.DataStoreEnabled)
end
print(PREFIX .. string.format(
	"SAVE VERIFY liveInstances=%d summaryInstances=%s sameProfile=%s dirty=%s dataStore=%s message=%s",
	savedInventoryCount,
	summaryInstances,
	tostring(sameLiveProfile),
	summaryDirty,
	summaryDataStore,
	tostring(saveMessage)
))
if typeof(savedSummary) ~= "table"
	or savedSummary.DataStoreEnabled ~= true
	or not sameLiveProfile
	or savedInventoryCount ~= EXPECTED_REMAINING then
	rollback("Saved cleanup state failed direct verification; the live ProfileService session identity changed=" .. tostring(not sameLiveProfile) .. ".")
end

local commitCallOk, commitOk, commitMessage = pcall(function()
	return cleanupBridge:Invoke(player, "Commit", EXPECTED_TOKEN)
end)
if not commitCallOk or commitOk ~= true then
	rollback("Legacy compatibility owner could not commit cleanup: " .. tostring(commitMessage or commitOk))
end
legacyOwnerChanged = false

local unlockOk, lockResult = endCleanupLock()
if not unlockOk then
	fail("Cleanup was saved and committed, but the profile import lock could not be released: " .. tostring(lockResult) .. ". Stop Play before continuing.")
end
local blockedImportCount = typeof(lockResult) == "table" and tonumber(lockResult.BlockedCount) or 0
local lastBlockedReason = typeof(lockResult) == "table" and tostring(lockResult.LastBlockedReason or "") or ""
local replacedSessionDuringTransaction = typeof(lockResult) == "table" and lockResult.ReplacedSessionDuringTransaction == true

print(PREFIX .. "PASS player=" .. player.Name .. " userId=" .. tostring(player.UserId))
print(PREFIX .. "PASS removed=" .. tostring(EXPECTED_DELETE) .. " remaining=" .. tostring(EXPECTED_REMAINING))
print(PREFIX .. "PASS preserved referenced=50 purchased=6 cockpitGrantsAvailable=20")
print(PREFIX .. "PASS all installed references resolve and equipped ownership is canonical")
print(PREFIX .. "PASS DataStore save confirmed: " .. tostring(saveMessage))
print(PREFIX .. "PASS blockedExternalImports=" .. tostring(blockedImportCount) .. " lastReason=" .. lastBlockedReason)
print(PREFIX .. "PASS replacedSessionDuringTransaction=" .. tostring(replacedSessionDuringTransaction))
print(PREFIX .. "NEXT stop Play, start a fresh Play session, then rerun the cleanup dry run to verify persistence")
