-- Neo Tokyo Racers - Garage module inventory cleanup dual-owner bridge installer
-- NTR_GARAGE_MODULE_INVENTORY_CLEANUP_BRIDGE_INSTALL_V1
-- Run once in Studio Edit mode after the inventory guard installer.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Garage Module Cleanup Bridge] "
local CONTROLLER_MARKER = "NTR_GARAGE_MODULE_INVENTORY_DUAL_OWNER_BRIDGE_V1"
local RUNTIME_MARKER = "NTR_GARAGE_MODULE_INVENTORY_APPLY_RUNTIME_V1"
local PROFILE_MARKER = "NTR_GARAGE_MODULE_INVENTORY_IMPORT_LOCK_V1"

if RunService:IsRunning() then
	error(PREFIX .. "Stop Play and run this installer in Edit mode.", 0)
end

local ntr = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = ntr and ntr:FindFirstChild("Services")
local garage = services and services:FindFirstChild("Garage")
local playerServices = services and services:FindFirstChild("Player")
local controller = garage and garage:FindFirstChild("GarageActionController_Shadow_Disabled")
local runtimeModule = garage and garage:FindFirstChild("GarageModuleInventoryRuntime")
local profileService = playerServices and playerServices:FindFirstChild("ProfileService_Active")
if not (controller and controller:IsA("LuaSourceContainer")) then
	error(PREFIX .. "GarageActionController_Shadow_Disabled is missing.", 0)
end
if not (runtimeModule and runtimeModule:IsA("ModuleScript")) then
	error(PREFIX .. "GarageModuleInventoryRuntime is missing; install the guard first.", 0)
end
if not (profileService and profileService:IsA("LuaSourceContainer")) then
	error(PREFIX .. "ProfileService_Active is missing.", 0)
end
if not string.find(controller.Source, "NTR_GARAGE_MODULE_INVENTORY_GUARD_V1", 1, true) then
	error(PREFIX .. "Inventory guard marker missing; install the guard first.", 0)
end

local originalControllerSource = controller.Source
local originalRuntimeSource = runtimeModule.Source
local originalProfileSource = profileService.Source

local function replaceOnce(source, anchor, replacement, label)
	local first, last = string.find(source, anchor, 1, true)
	if not first then error(PREFIX .. "Missing source anchor: " .. tostring(label), 0) end
	if string.find(source, anchor, last + 1, true) then
		error(PREFIX .. "Source anchor is not unique: " .. tostring(label), 0)
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local runtimeExtension = [=[-- NTR_GARAGE_MODULE_INVENTORY_APPLY_RUNTIME_V1
local cleanupSnapshots = setmetatable({}, {__mode = "k"})

local function cleanupClone(value, seen)
	if typeof(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for key, child in pairs(value) do
		copy[cleanupClone(key, seen)] = cleanupClone(child, seen)
	end
	return copy
end

local function cleanupReplace(target, replacement)
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(replacement or {}) do target[key] = cleanupClone(value) end
end

function Runtime.ApplyReviewedCleanup(profile, expectedToken)
	if typeof(profile) ~= "table" then return false, "Profile must be a table." end
	if cleanupSnapshots[profile] then return false, "A cleanup transaction is already active." end
	local plan = Runtime.PlanCleanup(profile)
	if plan.Token ~= expectedToken then return false, "Legacy-owner cleanup token changed." end
	if #plan.MissingReferences > 0 then return false, "Legacy owner has missing installed references." end
	local references = Runtime.ReferenceIndex(profile)
	for _, instanceId in ipairs(plan.DeleteIds) do
		local instance = profile.OwnedModuleInstances[instanceId]
		if typeof(instance) ~= "table"
			or instance.Source ~= "LegacyInstalledModules"
			or instance.EquippedVehicleId == nil
			or (references[instanceId] and #references[instanceId] > 0) then
			return false, "Unsafe legacy deletion candidate: " .. tostring(instanceId)
		end
	end
	for _, instanceId in ipairs(plan.ReviewIds) do
		local instance = profile.OwnedModuleInstances[instanceId]
		if typeof(instance) ~= "table" or instance.Source ~= "IncludedWithCockpit" then
			return false, "Unexpected legacy review record: " .. tostring(instanceId)
		end
	end

	cleanupSnapshots[profile] = {
		OwnedModuleInstances = cleanupClone(profile.OwnedModuleInstances),
		LegacyMigration = cleanupClone(profile.LegacyMigration),
	}
	local ok, result = pcall(function()
		for _, instanceId in ipairs(plan.DeleteIds) do
			profile.OwnedModuleInstances[instanceId] = nil
		end
		local postReferences = Runtime.ReferenceIndex(profile)
		for instanceIdValue, instance in pairs(profile.OwnedModuleInstances) do
			local instanceId = tostring(instanceIdValue)
			local refs = postReferences[instanceId] or {}
			if #refs > 1 then error("Multiple slot references for " .. instanceId) end
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
			OriginalInstanceCount = plan.TotalInstances,
			RemovedInstanceCount = #plan.DeleteIds,
			PreservedCockpitGrantCount = #plan.ReviewIds,
		}
		local postPlan = Runtime.PlanCleanup(profile)
		if postPlan.TotalInstances ~= plan.TotalInstances - #plan.DeleteIds
			or #postPlan.DeleteIds ~= 0
			or #postPlan.MissingReferences ~= 0 then
			error("Legacy-owner post-cleanup validation failed.")
		end
		return {
			Original = plan.TotalInstances,
			Removed = #plan.DeleteIds,
			Remaining = postPlan.TotalInstances,
		}
	end)
	if not ok then
		local snapshot = cleanupSnapshots[profile]
		cleanupReplace(profile.OwnedModuleInstances, snapshot.OwnedModuleInstances)
		profile.LegacyMigration = snapshot.LegacyMigration
		cleanupSnapshots[profile] = nil
		return false, tostring(result)
	end
	return true, result
end

function Runtime.RollbackReviewedCleanup(profile)
	local snapshot = cleanupSnapshots[profile]
	if not snapshot then return true, "No legacy-owner cleanup transaction was active." end
	profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	cleanupReplace(profile.OwnedModuleInstances, snapshot.OwnedModuleInstances)
	profile.LegacyMigration = snapshot.LegacyMigration
	cleanupSnapshots[profile] = nil
	return true, "Legacy-owner cleanup rolled back."
end

function Runtime.CommitReviewedCleanup(profile)
	cleanupSnapshots[profile] = nil
	return true, "Legacy-owner cleanup committed."
end

]=]

local controllerBridge = [=[	-- NTR_GARAGE_MODULE_INVENTORY_DUAL_OWNER_BRIDGE_V1
	-- The legacy garage session remains a compatibility owner. This tiny bridge
	-- lets the reviewed one-time cleanup update it in the same transaction as
	-- ProfileService, so its normal mirror cannot restore stale inventory.
	local V97_cleanupBridge = script.Parent:FindFirstChild("GarageModuleInventoryCleanupBridge")
	if V97_cleanupBridge and not V97_cleanupBridge:IsA("BindableFunction") then
		error("GarageModuleInventoryCleanupBridge exists with the wrong class")
	end
	if not V97_cleanupBridge then
		V97_cleanupBridge = Instance.new("BindableFunction")
		V97_cleanupBridge.Name = "GarageModuleInventoryCleanupBridge"
		V97_cleanupBridge.Parent = script.Parent
	end
	V97_cleanupBridge.OnInvoke = function(player, mode, expectedToken)
		local profile = V56_getProfile(player)
		if mode == "Apply" then
			return V96_ModuleInventory.ApplyReviewedCleanup(profile, expectedToken)
		elseif mode == "Rollback" then
			return V96_ModuleInventory.RollbackReviewedCleanup(profile)
		elseif mode == "Commit" then
			return V96_ModuleInventory.CommitReviewedCleanup(profile)
		end
		return false, "Unknown cleanup bridge mode."
	end

]=]

local stagedRuntime = originalRuntimeSource
if not string.find(stagedRuntime, RUNTIME_MARKER, 1, true) then
	stagedRuntime = replaceOnce(stagedRuntime, "return Runtime", runtimeExtension .. "return Runtime", "runtime return")
end

local stagedController = originalControllerSource
if not string.find(stagedController, CONTROLLER_MARKER, 1, true) then
	stagedController = replaceOnce(
		stagedController,
		"\t-- NTR_PERSISTENCE_PHASE6_GARAGE_CAPACITY_GATE",
		controllerBridge .. "\t-- NTR_PERSISTENCE_PHASE6_GARAGE_CAPACITY_GATE",
		"post-profile compatibility bridge"
	)
end

local stagedProfile = originalProfileSource
if not string.find(stagedProfile, PROFILE_MARKER, 1, true) then
	stagedProfile = replaceOnce(
		stagedProfile,
		'local importProfileSnapshotBinding = ensureBindableFunction(bindings, "ImportProfileSnapshot")',
		'local importProfileSnapshotBinding = ensureBindableFunction(bindings, "ImportProfileSnapshot")\nlocal garageCleanupTransactionBinding = ensureBindableFunction(bindings, "GarageModuleInventoryCleanupTransaction") -- ' .. PROFILE_MARKER,
		"profile cleanup transaction binding"
	)
	stagedProfile = replaceOnce(
		stagedProfile,
		"local sessions = {}",
		"local sessions = {}\nlocal garageCleanupTransactions = {}",
		"profile cleanup transaction state"
	)
	stagedProfile = replaceOnce(
		stagedProfile,
		"local function importProfileSnapshot(player, snapshot, reason, dirty)\n\t-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT",
		[=[local function importProfileSnapshot(player, snapshot, reason, dirty)
	-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT
	local cleanupTransaction = player and garageCleanupTransactions[player.UserId]
	if cleanupTransaction then
		cleanupTransaction.BlockedCount += 1
		cleanupTransaction.LastBlockedReason = tostring(reason or "unspecified")
		warnLine("PROFILE IMPORT BLOCKED during garage inventory cleanup player=" .. player.Name
			.. " reason=" .. cleanupTransaction.LastBlockedReason)
		return false, "Profile import blocked during garage inventory cleanup transaction."
	end]=],
		"profile import cleanup gate"
	)
	stagedProfile = replaceOnce(
		stagedProfile,
		[=[importProfileSnapshotBinding.OnInvoke = function(player, snapshot, reason, dirty)
	return importProfileSnapshot(player, snapshot, reason, dirty)
end

isLoadedBinding.OnInvoke]=],
		[=[importProfileSnapshotBinding.OnInvoke = function(player, snapshot, reason, dirty)
	return importProfileSnapshot(player, snapshot, reason, dirty)
end

garageCleanupTransactionBinding.OnInvoke = function(player, mode)
	if not player then return false, "Player is required." end
	local userId = player.UserId
	if mode == "Begin" then
		if garageCleanupTransactions[userId] then
			return false, "A garage inventory cleanup transaction is already active."
		end
		garageCleanupTransactions[userId] = {BlockedCount = 0, LastBlockedReason = ""}
		return true, "Garage inventory cleanup transaction started."
	elseif mode == "End" then
		local result = garageCleanupTransactions[userId]
		garageCleanupTransactions[userId] = nil
		return true, result or {BlockedCount = 0, LastBlockedReason = ""}
	end
	return false, "Unknown garage inventory cleanup transaction mode."
end

isLoadedBinding.OnInvoke]=],
		"profile cleanup transaction handler"
	)
end
if #stagedController >= 195000 then
	error(PREFIX .. "Staged controller source is too large: " .. tostring(#stagedController), 0)
end

local function audit()
	local failures = {}
	local function check(condition, message)
		if not condition then table.insert(failures, message) end
	end
	check(string.find(controller.Source, CONTROLLER_MARKER, 1, true) ~= nil, "controller bridge marker missing")
	check(string.find(controller.Source, "GarageModuleInventoryCleanupBridge", 1, true) ~= nil, "bridge binding missing")
	check(string.find(runtimeModule.Source, RUNTIME_MARKER, 1, true) ~= nil, "runtime apply marker missing")
	check(string.find(runtimeModule.Source, "function Runtime.ApplyReviewedCleanup", 1, true) ~= nil, "runtime apply method missing")
	check(string.find(runtimeModule.Source, "function Runtime.RollbackReviewedCleanup", 1, true) ~= nil, "runtime rollback method missing")
	check(string.find(profileService.Source, PROFILE_MARKER, 1, true) ~= nil, "profile import-lock marker missing")
	check(string.find(profileService.Source, "GarageModuleInventoryCleanupTransaction", 1, true) ~= nil, "profile cleanup transaction binding missing")
	check(string.find(profileService.Source, "PROFILE IMPORT BLOCKED during garage inventory cleanup", 1, true) ~= nil, "profile import gate missing")
	if #failures > 0 then return false, table.concat(failures, " | ") end
	return true, "dual-owner bridge and profile import lock installed"
end

local ok, installError = pcall(function()
	runtimeModule.Source = stagedRuntime
	controller.Source = stagedController
	profileService.Source = stagedProfile
	local auditOk, auditMessage = audit()
	if not auditOk then error(auditMessage) end
end)

if not ok then
	pcall(function() runtimeModule.Source = originalRuntimeSource end)
	pcall(function() controller.Source = originalControllerSource end)
	pcall(function() profileService.Source = originalProfileSource end)
	error(PREFIX .. "Installation rolled back: " .. tostring(installError), 0)
end

controller:SetAttribute("GarageModuleInventoryDualOwnerBridgeVersion", 1)
runtimeModule:SetAttribute("GarageModuleInventoryApplyRuntimeVersion", 1)
profileService:SetAttribute("GarageModuleInventoryCleanupImportLockVersion", 1)
print(PREFIX .. "INSTALL PASS - canonical and legacy owners share cleanup transaction; profile imports are locked during commit")
print(PREFIX .. "NEXT start a fresh Play session and run the updated cleanup apply script")
