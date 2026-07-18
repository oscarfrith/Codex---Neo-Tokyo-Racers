-- Neo Tokyo Racers - Garage module inventory guard installer
-- NTR_GARAGE_MODULE_INVENTORY_GUARD_INSTALL_V1
-- Run once in Studio Edit mode. This stops new reconciliation debris.
-- It does NOT clean or save any player profile.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Garage Module Guard] "
local SERVER_MARKER = "NTR_GARAGE_MODULE_INVENTORY_GUARD_V1"
local RUNTIME_MARKER = "NTR_GARAGE_MODULE_INVENTORY_RUNTIME_V1"

if RunService:IsRunning() then
	error(PREFIX .. "Stop Play and run this installer in Edit mode.", 0)
end

local ntr = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = ntr and ntr:FindFirstChild("Services")
local garage = services and services:FindFirstChild("Garage")
local controller = garage and garage:FindFirstChild("GarageActionController_Shadow_Disabled")
if not (controller and controller:IsA("LuaSourceContainer")) then
	error(PREFIX .. "GarageActionController_Shadow_Disabled is missing.", 0)
end

local runtimeSource = [=[-- NTR_GARAGE_MODULE_INVENTORY_RUNTIME_V1
-- Canonical instance-inventory shape and cleanup planning.
-- Runtime request methods never create or delete module instances.

local Runtime = {}

local function dictionaryCount(dictionary)
	local result = 0
	for _ in pairs(dictionary or {}) do result += 1 end
	return result
end

local function sortedKeys(dictionary)
	local result = {}
	for key in pairs(dictionary or {}) do table.insert(result, tostring(key)) end
	table.sort(result)
	return result
end

function Runtime.EnsureShape(profile)
	if typeof(profile) ~= "table" then return false, "Profile must be a table." end
	profile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
	profile.OwnedCockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
	profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	profile.GarageDisplaySpaces = typeof(profile.GarageDisplaySpaces) == "table" and profile.GarageDisplaySpaces or {}
	profile.OwnedCockpits = typeof(profile.OwnedCockpits) == "table" and profile.OwnedCockpits or {}
	profile.OwnedModules = typeof(profile.OwnedModules) == "table" and profile.OwnedModules or {}
	profile.InstalledModules = typeof(profile.InstalledModules) == "table" and profile.InstalledModules or {}
	profile.ModuleUpgradeLevels = typeof(profile.ModuleUpgradeLevels) == "table" and profile.ModuleUpgradeLevels or {}
	profile.ModuleColors = typeof(profile.ModuleColors) == "table" and profile.ModuleColors or {}
	profile.NeonOwned = typeof(profile.NeonOwned) == "table" and profile.NeonOwned or {}
	for _, vehicle in pairs(profile.Vehicles) do
		if typeof(vehicle) == "table" then
			vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}
		end
	end
	return true
end

function Runtime.ReferenceIndex(profile)
	if typeof(profile) ~= "table" then return {}, {} end
	local vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
	local moduleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	local references = {}
	local missing = {}
	for vehicleId, vehicle in pairs(vehicles) do
		if typeof(vehicle) == "table" then
			for slotId, instanceIdValue in pairs(vehicle.InstalledModules or {}) do
				local instanceId = tostring(instanceIdValue)
				references[instanceId] = references[instanceId] or {}
				table.insert(references[instanceId], {VehicleId = tostring(vehicleId), SlotId = tostring(slotId)})
				if typeof(moduleInstances[instanceId]) ~= "table" then
					table.insert(missing, {VehicleId = tostring(vehicleId), SlotId = tostring(slotId), InstanceId = instanceId})
				end
			end
		end
	end
	return references, missing
end

function Runtime.PlanCleanup(profile)
	if typeof(profile) ~= "table" then error("Profile must be a table.") end
	local moduleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	local references, missing = Runtime.ReferenceIndex(profile)
	local plan = {
		Version = "V1",
		TotalInstances = dictionaryCount(moduleInstances),
		DeleteIds = {},
		ProtectedIds = {},
		ReviewIds = {},
		DeleteByTemplate = {},
		ProtectedBySource = {},
		ReviewByReason = {},
		MissingReferences = missing,
	}

	for instanceIdValue, instance in pairs(moduleInstances) do
		local instanceId = tostring(instanceIdValue)
		if typeof(instance) ~= "table" then
			table.insert(plan.ReviewIds, instanceId)
			plan.ReviewByReason.InvalidRecord = (plan.ReviewByReason.InvalidRecord or 0) + 1
			continue
		end
		local source = tostring(instance.Source or "<missing-source>")
		local templateId = tostring(instance.TemplateId or "<missing-template>")
		local refs = references[instanceId] or {}
		local equippedVehicleId = instance.EquippedVehicleId ~= nil and tostring(instance.EquippedVehicleId) or ""

		if #refs > 0 then
			table.insert(plan.ProtectedIds, instanceId)
			plan.ProtectedBySource[source] = (plan.ProtectedBySource[source] or 0) + 1
		elseif source == "BuyModuleInstance" then
			table.insert(plan.ProtectedIds, instanceId)
			plan.ProtectedBySource[source] = (plan.ProtectedBySource[source] or 0) + 1
		elseif source == "LegacyInstalledModules" and equippedVehicleId ~= "" then
			table.insert(plan.DeleteIds, instanceId)
			plan.DeleteByTemplate[templateId] = (plan.DeleteByTemplate[templateId] or 0) + 1
		else
			table.insert(plan.ReviewIds, instanceId)
			local reason = "UnreferencedOtherSource"
			if source == "LegacyInstalledModules" then
				reason = "AvailableLegacy"
			elseif source == "IncludedWithCockpit" then
				reason = "UnreferencedCockpitGrant"
			end
			plan.ReviewByReason[reason] = (plan.ReviewByReason[reason] or 0) + 1
		end
	end

	table.sort(plan.DeleteIds)
	table.sort(plan.ProtectedIds)
	table.sort(plan.ReviewIds)
	local tokenParts = {plan.Version, tostring(plan.TotalInstances), tostring(#plan.DeleteIds)}
	for _, templateId in ipairs(sortedKeys(plan.DeleteByTemplate)) do
		table.insert(tokenParts, templateId .. "=" .. tostring(plan.DeleteByTemplate[templateId]))
	end
	plan.Token = table.concat(tokenParts, "|")
	return plan
end

function Runtime.StampAcquisition(instance, acquisitionKind, vehicleId)
	if typeof(instance) ~= "table" then return instance end
	instance.AcquisitionKind = tostring(acquisitionKind or instance.Source or "Unknown")
	instance.AcquiredAtUnix = tonumber(instance.AcquiredAtUnix) or os.time()
	if vehicleId ~= nil then instance.GrantedForVehicleId = tostring(vehicleId) end
	return instance
end

return Runtime
]=]

local originalControllerSource = controller.Source
local existingRuntime = garage:FindFirstChild("GarageModuleInventoryRuntime")
local originalRuntimeSource = existingRuntime and existingRuntime:IsA("ModuleScript") and existingRuntime.Source or nil
local createdRuntime = false

local function findPlain(source, anchor, startAt)
	local first, last = string.find(source, anchor, startAt or 1, true)
	if not first then error(PREFIX .. "Missing source anchor: " .. anchor, 0) end
	return first, last
end

local function replaceRange(source, startAnchor, endAnchor, replacement)
	local first = findPlain(source, startAnchor)
	local endFirst = findPlain(source, endAnchor, first + #startAnchor)
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, endFirst)
end

local function replaceOncePlain(source, anchor, replacement)
	local first, last = findPlain(source, anchor)
	if string.find(source, anchor, last + 1, true) then
		error(PREFIX .. "Source anchor is not unique: " .. anchor, 0)
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local function addAcquisitionFields(source)
	local includedAnchor = '\t\t\t\t\tSource = "IncludedWithCockpit",\n'
	local includedReplacement = table.concat({
		includedAnchor,
		'\t\t\t\t\tAcquisitionKind = "IncludedWithCockpit",\n',
		'\t\t\t\t\tGrantedForVehicleId = tostring(vehicleId),\n',
		'\t\t\t\t\tAcquiredAtUnix = os.time(),\n',
	})
	local buyAnchor = '\t\t\tSource = "BuyModuleInstance",\n'
	local buyReplacement = table.concat({
		buyAnchor,
		'\t\t\tAcquisitionKind = "Purchase",\n',
		'\t\t\tAcquiredAtUnix = os.time(),\n',
	})
	source = replaceOncePlain(source, includedAnchor, includedReplacement)
	source = replaceOncePlain(source, buyAnchor, buyReplacement)
	return source
end

local function buildControllerSource(source)
	if string.find(source, SERVER_MARKER, 1, true) then return source end
	local requireAnchor = '\tlocal V89_GarageProfileRuntime = require(script.Parent:WaitForChild("GarageProfileRuntime"))\n'
	local requireReplacement = table.concat({
		requireAnchor,
		'\tlocal V96_ModuleInventory = require(script.Parent:WaitForChild("GarageModuleInventoryRuntime")) -- ',
		SERVER_MARKER,
		'\n',
	})
	source = replaceOncePlain(source, requireAnchor, requireReplacement)

	local safeEnsure = [=[	local function V84_ensureInstanceInventory(profile)
		-- NTR_GARAGE_MODULE_INVENTORY_SHAPE_ONLY_V1
		-- Creation is owned by explicit cockpit/module purchase paths, never reads or summaries.
		return V96_ModuleInventory.EnsureShape(profile)
	end

]=]
	source = replaceRange(source,
		"\tlocal function V84_ensureInstanceInventory(profile)",
		"\t-- NTR_PERSISTENCE_PHASE19_INSTANCE_COMPAT_SYNC",
		safeEnsure)

	local invokeFirst = findPlain(source, "\tV56_invoke.OnServerInvoke = function(player, action, args)")
	local playerLineFirst, playerLineLast = findPlain(source, "\t\t\tprofile._Player = player", invokeFirst)
	local okLineFirst = findPlain(source, "\t\t\tlocal ok, message", playerLineLast)
	local invokeGuard = table.concat({
		"\t\t\tprofile._Player = player\n",
		"\t\t\tV84_ensureInstanceInventory(profile) -- canonical shape only; no grants or migration\n",
	})
	source = string.sub(source, 1, playerLineFirst - 1) .. invokeGuard .. string.sub(source, okLineFirst)

	local syncPattern = "([\r\n][ \t]*)V88_syncInstanceDataFromLegacy%(profile%)"
	local syncReplacement = "%1-- NTR_GARAGE_LEGACY_TO_INSTANCE_SYNC_RETIRED_V1"
	local syncCount
	source, syncCount = string.gsub(source, syncPattern, syncReplacement)
	if syncCount ~= 4 then
		error(PREFIX .. "Expected four normal-flow legacy sync calls, found " .. tostring(syncCount), 0)
	end

	source = addAcquisitionFields(source)
	return source
end

local okBuild, stagedOrError = pcall(buildControllerSource, originalControllerSource)
if not okBuild then error(stagedOrError, 0) end
local stagedControllerSource = stagedOrError
if #stagedControllerSource >= 195000 then
	error(PREFIX .. "Staged controller source is too large: " .. tostring(#stagedControllerSource), 0)
end

local function auditInstalled()
	local failures = {}
	local function expect(condition, message)
		if not condition then table.insert(failures, message) end
	end
	local source = controller.Source
	local runtime = garage:FindFirstChild("GarageModuleInventoryRuntime")
	expect(string.find(source, SERVER_MARKER, 1, true) ~= nil, "server guard marker missing")
	expect(string.find(source, "NTR_GARAGE_MODULE_INVENTORY_SHAPE_ONLY_V1", 1, true) ~= nil, "shape-only ensure missing")
	expect(string.find(source, "V76_grantDefaultModulesForCurrentCockpit(profile)\n\t\t\tV85_attachDefaultModuleInstancesToCurrentVehicle(profile)", 1, true) == nil,
		"per-request grant/attach block remains")
	local activeSyncCalls = 0
	for line in string.gmatch(source, "[^\r\n]+") do
		if string.match(line, "^%s*V88_syncInstanceDataFromLegacy%(profile%)%s*$") then activeSyncCalls += 1 end
	end
	expect(activeSyncCalls == 0, "normal-flow legacy sync calls remain: " .. tostring(activeSyncCalls))
	expect(runtime and runtime:IsA("ModuleScript"), "GarageModuleInventoryRuntime missing")
	expect(runtime and string.find(runtime.Source, RUNTIME_MARKER, 1, true) ~= nil, "runtime marker missing")
	if runtime and runtime:IsA("ModuleScript") then
		local okRequire, api = pcall(require, runtime)
		expect(okRequire, "runtime require failed: " .. tostring(api))
		expect(okRequire and typeof(api) == "table" and typeof(api.EnsureShape) == "function", "runtime EnsureShape contract missing")
		expect(okRequire and typeof(api) == "table" and typeof(api.PlanCleanup) == "function", "runtime PlanCleanup contract missing")
	end
	if #failures > 0 then return false, table.concat(failures, " | ") end
	return true, "source guard and cleanup planner installed"
end

local okAssign, assignError = pcall(function()
	if not existingRuntime then
		existingRuntime = Instance.new("ModuleScript")
		existingRuntime.Name = "GarageModuleInventoryRuntime"
		existingRuntime.Parent = garage
		createdRuntime = true
	elseif not existingRuntime:IsA("ModuleScript") then
		error("GarageModuleInventoryRuntime exists but is not a ModuleScript")
	end
	existingRuntime.Source = runtimeSource
	controller.Source = stagedControllerSource
	local okAudit, auditMessage = auditInstalled()
	if not okAudit then error(auditMessage) end
end)

if not okAssign then
	pcall(function() controller.Source = originalControllerSource end)
	if createdRuntime and existingRuntime then
		pcall(function() existingRuntime:Destroy() end)
	elseif existingRuntime and originalRuntimeSource then
		pcall(function() existingRuntime.Source = originalRuntimeSource end)
	end
	error(PREFIX .. "Rolled back after assignment failure: " .. tostring(assignError), 0)
end

print(PREFIX .. "INSTALL PASS - new instance inflation is stopped; no profile was cleaned or saved")
print(PREFIX .. "NEXT - restart Play, then run roblox_ui_garage_module_inventory_cleanup_dry_run.lua from the Server Command Bar")
