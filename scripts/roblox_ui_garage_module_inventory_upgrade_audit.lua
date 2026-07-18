-- Neo Tokyo Racers - Garage module inventory and upgrade audit
-- NTR_GARAGE_MODULE_INVENTORY_UPGRADE_AUDIT_V1
-- Read only. Run during Play from Studio's Server Command Bar.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Garage Module Audit] "
local INFLATED_TEMPLATE_WARNING = 10
local passCount = 0
local warningCount = 0
local blockerCount = 0

local function pass(message)
	passCount += 1
	print(PREFIX .. "PASS " .. message)
end

local function warnLine(message)
	warningCount += 1
	warn(PREFIX .. "WARN " .. message)
end

local function blocker(message)
	blockerCount += 1
	warn(PREFIX .. "BLOCKER " .. message)
end

local function count(dictionary)
	local result = 0
	for _ in pairs(dictionary or {}) do
		result += 1
	end
	return result
end

local function sortedKeys(dictionary)
	local result = {}
	for key in pairs(dictionary or {}) do
		table.insert(result, tostring(key))
	end
	table.sort(result)
	return result
end

local function sortedRows(rows, compare)
	local result = table.clone(rows)
	table.sort(result, compare)
	return result
end

local function sourceContains(object, marker)
	if not object or not object:IsA("LuaSourceContainer") then
		return false
	end
	local ok, source = pcall(function()
		return object.Source
	end)
	return ok and string.find(source, marker, 1, true) ~= nil
end

if not RunService:IsRunning() then
	error(PREFIX .. "Start Play, switch the Command Bar to Server, then run this audit.", 0)
end
if not RunService:IsServer() or Players.LocalPlayer then
	error(PREFIX .. "Run this from the Server Command Bar, not Client.", 0)
end

local players = Players:GetPlayers()
if #players == 0 then
	error(PREFIX .. "No player is present. Join the Play session before running the audit.", 0)
end
local player = players[1]
if #players > 1 then
	warnLine("Multiple players are present; auditing the first player only: " .. player.Name)
end
print(PREFIX .. "PLAYER " .. player.Name .. " userId=" .. tostring(player.UserId))

local ntrServer = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = ntrServer and ntrServer:FindFirstChild("Services")
local playerServices = services and services:FindFirstChild("Player")
local bindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
local getProfile = bindings and bindings:FindFirstChild("GetProfile")
if not (getProfile and getProfile:IsA("BindableFunction")) then
	error(PREFIX .. "ProfileServiceBindings.GetProfile is missing.", 0)
end

local okProfile, profile = pcall(function()
	return getProfile:Invoke(player)
end)
if not okProfile or typeof(profile) ~= "table" then
	error(PREFIX .. "Could not read the live profile: " .. tostring(profile), 0)
end
pass("live profile acquired without invoking GarageInvoke")

local vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
local cockpitInstances = typeof(profile.OwnedCockpitInstances) == "table" and profile.OwnedCockpitInstances or {}
local moduleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}

local vehicleNames = {}
for vehicleId, vehicle in pairs(vehicles) do
	local cockpitInstance = typeof(vehicle) == "table" and cockpitInstances[vehicle.CockpitInstanceId] or nil
	local cockpitId = typeof(cockpitInstance) == "table" and cockpitInstance.TemplateId or nil
	vehicleNames[tostring(vehicleId)] = tostring(
		(typeof(vehicle) == "table" and vehicle.DisplayName)
		or cockpitId
		or vehicleId
	)
end

local references = {}
local missingReferences = 0
for vehicleId, vehicle in pairs(vehicles) do
	if typeof(vehicle) == "table" then
		for slotId, instanceIdValue in pairs(vehicle.InstalledModules or {}) do
			local instanceId = tostring(instanceIdValue)
			references[instanceId] = references[instanceId] or {}
			table.insert(references[instanceId], {
				VehicleId = tostring(vehicleId),
				SlotId = tostring(slotId),
			})
			if typeof(moduleInstances[instanceId]) ~= "table" then
				missingReferences += 1
				warnLine(string.format("vehicle %s slot %s references missing module instance %s",
					tostring(vehicleId), tostring(slotId), instanceId))
			end
		end
	end
end

local templateRowsById = {}
local sourceCounts = {}
local orphanCount = 0
local multiReferenceCount = 0
local equippedMismatchCount = 0
local invalidInstanceCount = 0

for instanceIdValue, instance in pairs(moduleInstances) do
	local instanceId = tostring(instanceIdValue)
	if typeof(instance) ~= "table" then
		invalidInstanceCount += 1
		warnLine("module instance " .. instanceId .. " is not a table")
		continue
	end

	local templateId = tostring(instance.TemplateId or "<missing-template>")
	local source = tostring(instance.Source or "<missing-source>")
	local equippedVehicleId = instance.EquippedVehicleId ~= nil and tostring(instance.EquippedVehicleId) or ""
	local refs = references[instanceId] or {}
	sourceCounts[source] = (sourceCounts[source] or 0) + 1
	templateRowsById[templateId] = templateRowsById[templateId] or {
		TemplateId = templateId,
		Count = 0,
		Sources = {},
		Equipped = 0,
		Available = 0,
	}
	local row = templateRowsById[templateId]
	row.Count += 1
	row.Sources[source] = (row.Sources[source] or 0) + 1
	if equippedVehicleId ~= "" then row.Equipped += 1 else row.Available += 1 end

	if #refs == 0 and equippedVehicleId ~= "" then
		orphanCount += 1
		warnLine(string.format("equipped instance has no slot reference: %s template=%s equippedVehicle=%s",
			instanceId, templateId, equippedVehicleId))
	elseif #refs > 1 then
		multiReferenceCount += 1
		warnLine(string.format("instance is referenced by %d slots: %s template=%s",
			#refs, instanceId, templateId))
	end

	for _, ref in ipairs(refs) do
		if equippedVehicleId == "" or equippedVehicleId ~= ref.VehicleId then
			equippedMismatchCount += 1
			warnLine(string.format("instance ownership mismatch: %s template=%s storedVehicle=%s referencedBy=%s/%s",
				instanceId, templateId, equippedVehicleId ~= "" and equippedVehicleId or "AVAILABLE",
				ref.VehicleId, ref.SlotId))
		end
	end
end

local templateRows = {}
for _, row in pairs(templateRowsById) do table.insert(templateRows, row) end
templateRows = sortedRows(templateRows, function(a, b)
	if a.Count == b.Count then return a.TemplateId < b.TemplateId end
	return a.Count > b.Count
end)

print(PREFIX .. string.format("INVENTORY SUMMARY vehicles=%d cockpitInstances=%d moduleInstances=%d templates=%d currentVehicle=%s",
	count(vehicles), count(cockpitInstances), count(moduleInstances), #templateRows, tostring(profile.CurrentVehicleId)))

print(PREFIX .. "INSTANCE SOURCES")
for _, source in ipairs(sortedKeys(sourceCounts)) do
	print(PREFIX .. "  " .. source .. " = " .. tostring(sourceCounts[source]))
end

print(PREFIX .. "MODULE COUNTS (highest first)")
local inflatedTemplateCount = 0
for _, row in ipairs(templateRows) do
	local sourceParts = {}
	for _, source in ipairs(sortedKeys(row.Sources)) do
		table.insert(sourceParts, source .. "=" .. tostring(row.Sources[source]))
	end
	print(PREFIX .. string.format("  %s total=%d equipped=%d available=%d sources={%s}",
		row.TemplateId, row.Count, row.Equipped, row.Available, table.concat(sourceParts, ", ")))
	if row.Count >= INFLATED_TEMPLATE_WARNING then
		inflatedTemplateCount += 1
	end
end
if inflatedTemplateCount > 0 then
	warnLine(string.format("%d module templates have at least %d persisted copies",
		inflatedTemplateCount, INFLATED_TEMPLATE_WARNING))
else
	pass("no module template reached the inflated-copy warning threshold")
end

if missingReferences == 0 then pass("all installed slot references resolve to instances") end
if orphanCount == 0 then pass("no equipped instances are orphaned") end
if multiReferenceCount == 0 then pass("no module instance is installed in multiple slots") end
if equippedMismatchCount == 0 then pass("instance vehicle ownership matches slot references") end
if invalidInstanceCount == 0 then pass("all module instance records are tables") end

local ntr = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
local shared = ntr and ntr:FindFirstChild("Shared")
local common = shared and shared:FindFirstChild("Modules") and shared.Modules:FindFirstChild("Common")
local performance = common and common:FindFirstChild("Performance")
local runtimeModule = performance and performance:FindFirstChild("VehicleModuleUpgradeRuntime")
local legacyModule = performance and performance:FindFirstChild("VehicleUpgradeDefinitions")
local upgradeRuntime
local legacyDefinitions
if runtimeModule and runtimeModule:IsA("ModuleScript") then
	local ok, result = pcall(require, runtimeModule)
	if ok then upgradeRuntime = result else blocker("upgrade runtime require failed: " .. tostring(result)) end
else
	blocker("VehicleModuleUpgradeRuntime is missing")
end
if legacyModule and legacyModule:IsA("ModuleScript") then
	local ok, result = pcall(require, legacyModule)
	if ok then legacyDefinitions = result else blocker("legacy upgrade definitions require failed: " .. tostring(result)) end
else
	blocker("VehicleUpgradeDefinitions is missing")
end

local performanceConfig = shared and shared:FindFirstChild("Config")
	and shared.Config:FindFirstChild("VehiclePerformanceV2_EditAttributes")
local runtimePurchasesEnabled = performanceConfig
	and performanceConfig:GetAttribute("RuntimeUpgradePurchasesEnabled") == true
print(PREFIX .. "UPGRADE CONFIG RuntimeUpgradePurchasesEnabled=" .. tostring(runtimePurchasesEnabled))

local categories = ntr and ntr:FindFirstChild("Assets")
	and ntr.Assets:FindFirstChild("Vehicles")
	and ntr.Assets.Vehicles:FindFirstChild("Categories")
if not categories then
	blocker("vehicle category assets are missing")
end

local moduleModels = {}
if categories then
	for _, descendant in ipairs(categories:GetDescendants()) do
		if descendant:IsA("Model") then
			local moduleId = descendant:GetAttribute("ModuleId")
			if moduleId ~= nil or string.sub(descendant.Name, 1, 7) == "MODULE_" then
				moduleModels[tostring(moduleId or descendant.Name)] = descendant
			end
		end
	end
end
print(PREFIX .. "MODULE ASSET INDEX count=" .. tostring(count(moduleModels)))

local currentVehicleId = profile.CurrentVehicleId and tostring(profile.CurrentVehicleId) or ""
local currentVehicle = vehicles[currentVehicleId]
local installed = typeof(currentVehicle) == "table" and currentVehicle.InstalledModules or {}
local zeroCatalogCount = 0
local missingModelCount = 0
local installedCount = 0

print(PREFIX .. "INSTALLED MODULE UPGRADE CATALOG")
for _, slotId in ipairs(sortedKeys(installed)) do
	installedCount += 1
	local instanceId = tostring(installed[slotId])
	local instance = moduleInstances[instanceId]
	local templateId = typeof(instance) == "table" and tostring(instance.TemplateId or "") or ""
	local model = moduleModels[templateId]
	if not model then
		missingModelCount += 1
		warnLine("slot " .. slotId .. " cannot resolve module model for template " .. templateId)
		continue
	end

	local moduleType = tostring(model:GetAttribute("ModuleType") or "")
	local legacyCount = legacyDefinitions and #legacyDefinitions.GetForModuleType(moduleType) or -1
	local catalog = nil
	local catalogError = nil
	if upgradeRuntime then
		local ok, result = pcall(upgradeRuntime.CatalogForModuleType, moduleType, model)
		if ok and typeof(result) == "table" then catalog = result else catalogError = tostring(result) end
	end
	local catalogCount = catalog and #catalog or -1
	print(PREFIX .. string.format(
		"  slot=%s instance=%s template=%s type=%s materialised=%s legacyDefinitions=%d runtimeCatalog=%d%s",
		slotId, instanceId, templateId, moduleType ~= "" and moduleType or "<missing>",
		tostring(model:GetAttribute("V2Materialised") == true), legacyCount, catalogCount,
		catalogError and (" error=" .. catalogError) or ""))
	if catalogCount == 0 then
		zeroCatalogCount += 1
		local reason
		if moduleType == "" then
			reason = "ModuleType is missing"
		elseif runtimePurchasesEnabled and model:GetAttribute("V2Materialised") == true then
			reason = "V2 materialised module returned no upgrade paths"
		elseif legacyCount == 0 then
			reason = "no legacy definitions match ModuleType=" .. moduleType
		else
			reason = "catalog unexpectedly empty"
		end
		warnLine("no upgrade cards for " .. templateId .. ": " .. reason)
	end
end

if installedCount == 0 then
	warnLine("current vehicle has no installed instance references to audit")
elseif zeroCatalogCount == 0 and missingModelCount == 0 then
	pass("every installed module resolves to a non-empty upgrade catalog")
end

local garageController = services and services:FindFirstChild("Garage")
	and services.Garage:FindFirstChild("GarageActionController_Shadow_Disabled")
if sourceContains(garageController, "V76_grantDefaultModulesForCurrentCockpit(profile)\n")
	and sourceContains(garageController, "V85_attachDefaultModuleInstancesToCurrentVehicle(profile)") then
	warnLine("garage request handler still contains default-grant/attach calls; source repair should move provisioning out of the per-request path")
else
	pass("no obvious per-request default provisioning marker detected")
end

print(PREFIX .. string.format(
	"SUMMARY pass=%d warn=%d blocker=%d inflatedTemplates=%d missingRefs=%d orphaned=%d multiReferenced=%d ownershipMismatches=%d emptyUpgradeCatalogs=%d",
	passCount, warningCount, blockerCount, inflatedTemplateCount, missingReferences, orphanCount,
	multiReferenceCount, equippedMismatchCount, zeroCatalogCount))
print(PREFIX .. "READ ONLY COMPLETE - no profile, inventory, config, source, or saved data was changed")
