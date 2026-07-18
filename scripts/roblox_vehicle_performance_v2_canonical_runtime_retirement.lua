-- Neo Tokyo Racers - Canonical V2 runtime ownership and active legacy retirement
-- NTR_VEHICLE_PERFORMANCE_V2_CANONICAL_RUNTIME_V1
-- Run once from the Roblox Studio Command Bar in EDIT mode.

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_VEHICLE_PERFORMANCE_V2_CANONICAL_RUNTIME_V1"
local PREFIX = "[NTR Canonical V2 Runtime]"

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local performance = need(need(need(need(kit, "Shared", "Folder"), "Modules", "Folder"), "Common", "Folder"), "Performance", "Folder")
local runtime = need(performance, "VehiclePerformanceRuntime", "ModuleScript")
local upgrades = need(performance, "VehicleModuleUpgradeRuntime", "ModuleScript")
local resolver = need(performance, "VehiclePerformanceResolver", "ModuleScript")
local categories = need(need(need(kit, "Assets", "Folder"), "Vehicles", "Folder"), "Categories", "Folder")
local services = need(need(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder")
local vehicleServices = need(services, "Vehicle", "Folder")
local writer = need(vehicleServices, "VehiclePerformanceRuntimeService_Active", "Script")

assert(string.find(runtime.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE8_COMPAT_RUNTIME", 1, true) or string.find(runtime.Source, REVISION, 1, true), "Unexpected VehiclePerformanceRuntime baseline")
assert(string.find(upgrades.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE8_COMPAT_UPGRADE_RUNTIME", 1, true) or string.find(upgrades.Source, REVISION, 1, true), "Unexpected VehicleModuleUpgradeRuntime baseline")
assert(string.find(resolver.Source, "NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1", 1, true), "Confirmed canonical resolver baseline missing")
assert(string.find(writer.Source, "NTR Vehicle Phase AM Runtime", 1, true) or string.find(writer.Source, REVISION, 1, true), "Unexpected spawned performance writer baseline")

local runtimeSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_CANONICAL_RUNTIME_V1
-- Compatibility-shaped API with one unconditional V2 calculation owner.
local V2Runtime = require(script.Parent:WaitForChild("VehiclePerformanceV2Runtime"))
local Runtime = {}

local function installed(root)
	local result = {}
	if root then
		for _, item in ipairs(root:GetChildren()) do
			if item:IsA("Model") and item:GetAttribute("ModuleId") ~= nil then table.insert(result, item) end
		end
	end
	return result
end

function Runtime.CalculateBuild(_legacyTotals, cockpit, installedRoot)
	assert(cockpit and cockpit:GetAttribute("V2Materialised") == true, "Canonical V2 cockpit is not materialised")
	return V2Runtime.CalculateComponents(cockpit, installed(installedRoot), {})
end

local function rewrite(vehicle, name, values)
	local folder = vehicle:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then folder:Destroy(); folder = nil end
	if not folder then folder = Instance.new("Folder"); folder.Name = name; folder.Parent = vehicle end
	folder:ClearAllChildren()
	for key, value in pairs(values or {}) do
		if typeof(value) == "number" then local number = Instance.new("NumberValue"); number.Name = key; number.Value = value; number.Parent = folder end
	end
end

function Runtime.WriteToVehicle(vehicle, result)
	rewrite(vehicle, "RAW_PERFORMANCE_Runtime", result.Raw or {})
	rewrite(vehicle, "NORMALIZED_PERFORMANCE_Runtime", result.Normalized or result.EffectiveFactor or {})
	rewrite(vehicle, "HEADLINE_STATS_Runtime", result.Headline or {})
	for key, value in pairs(result.Raw or {}) do if typeof(value) == "number" then vehicle:SetAttribute("Performance_" .. key, value) end end
	local overall = result.Overall or {}
	vehicle:SetAttribute("PerformanceIndex", overall.PerformanceIndex or 100)
	vehicle:SetAttribute("PerformanceTier", overall.Tier or "E")
	vehicle:SetAttribute("PerformanceScore", overall.Score or 0)
	vehicle:SetAttribute("PerformanceRuntimeVersion", "V2_CANONICAL_RUNTIME_V1")
end

return Runtime
]==]

local upgradeSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_CANONICAL_RUNTIME_V1
-- Physical module instances and V2 upgrade allocations are the only live upgrade state.
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceV2Definitions"))
local V2 = require(script.Parent:WaitForChild("VehiclePerformanceV2UpgradeRuntime"))
local V2Runtime = require(script.Parent:WaitForChild("VehiclePerformanceV2Runtime"))
local Runtime = {}
local profiles = {}

local function currentVehicle(profile)
	local id = profile and profile.CurrentVehicleId
	return id and profile.Vehicles and profile.Vehicles[tostring(id)], id and tostring(id)
end

local function currentInstance(profile, slotId, moduleId)
	local vehicle, vehicleId = currentVehicle(profile)
	local instanceId = vehicle and vehicle.InstalledModules and vehicle.InstalledModules[slotId]
	local instance = instanceId and profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]
	if typeof(instance) == "table" and tostring(instance.TemplateId or "") == tostring(moduleId or "") then return tostring(instanceId), instance end
	for id, candidate in pairs(profile.OwnedModuleInstances or {}) do
		if typeof(candidate) == "table" and tostring(candidate.TemplateId or "") == tostring(moduleId or "") and tostring(candidate.EquippedVehicleId or "") == tostring(vehicleId or "") then return tostring(id), candidate end
	end
	return nil, nil
end

local function applyMigration(profile, findModule)
	if typeof(profile) ~= "table" then return end
	profile.OwnedModuleInstances = typeof(profile.OwnedModuleInstances) == "table" and profile.OwnedModuleInstances or {}
	local migration = typeof(profile.VehiclePerformanceV2Migration) == "table" and profile.VehiclePerformanceV2Migration or {}
	if migration.Version == "V2_ACCESSORY_ALIGNMENT_V1" and migration.RefundApplied == true then return end
	local refund, converted, missing = 0, 0, 0
	for _, instance in pairs(profile.OwnedModuleInstances) do
		if typeof(instance) == "table" then
			local module = findModule(profile.CurrentCategory, tostring(instance.TemplateId or ""))
			if module then
				local migrated, report = V2.MigrateModuleInstance(instance, module)
				for key, value in pairs(migrated) do instance[key] = value end
				refund += tonumber(report.RefundCredit) or 0; converted += tonumber(report.ConvertedPoints) or 0
			else missing += 1 end
		end
	end
	profile.Cash = (tonumber(profile.Cash) or 0) + refund
	profile.VehiclePerformanceV2Migration = {Version="V2_ACCESSORY_ALIGNMENT_V1", RefundApplied=true, RefundCredit=refund, ConvertedPoints=converted, MissingTemplates=missing, MigratedAtUnix=os.time()}
end

function Runtime.GetLevels(player)
	local profile = profiles[player.UserId]
	local result = {}
	if not profile then return result end
	for slotId, moduleId in pairs(profile.InstalledModules or {}) do
		local _, instance = currentInstance(profile, slotId, moduleId)
		if instance then result[tostring(moduleId)] = instance.V2UpgradePoints or {} end
	end
	return result
end

function Runtime.GetModuleLevels(player, moduleId)
	local all = Runtime.GetLevels(player)
	all[moduleId] = typeof(all[moduleId]) == "table" and all[moduleId] or {}
	return all[moduleId]
end

function Runtime.CatalogForModuleType(_moduleType, module)
	if not module or module:GetAttribute("V2Materialised") ~= true then return {} end
	local result = {}
	local base = V2.ApplyToModuleRaw(module, {})
	for _, path in ipairs(V2.Catalog(module, {})) do
		local one = {[path.PathId] = 1}
		local after = V2.ApplyToModuleRaw(module, one)
		local effects = {}
		for _, name in ipairs(Definitions.RawVariableOrder) do effects[name] = (after[name] or 0) - (base[name] or 0) end
		table.insert(result, {UpgradeId=path.PathId, DisplayName=path.DisplayName, MaxLevel=path.MaxPoints, BasePrice=tonumber(module:GetAttribute("Point1CostGuide")) or 0, PriceMultiplier=1, EffectsPerLevel=effects, V2TotalCapacity=path.Capacity})
	end
	return result
end

function Runtime.Purchase(player, profile, slotId, moduleId, upgradeId, findModule, _moduleTypeForModel)
	profiles[player.UserId] = profile
	applyMigration(profile, findModule)
	local installedId = profile.InstalledModules and profile.InstalledModules[slotId]
	moduleId = moduleId ~= "" and moduleId or installedId
	if installedId ~= moduleId then return false, "Install that module before upgrading it." end
	local module = moduleId and findModule(profile.CurrentCategory, moduleId)
	if not module then return false, "Module not found." end
	local instanceId = currentInstance(profile, slotId, moduleId)
	if not instanceId then return false, "Installed module instance not found." end
	local ok, preview = V2.PurchasePoint(profile, instanceId, module, upgradeId, {})
	if not ok then return false, preview end
	return true, tostring(upgradeId) .. " upgraded for $" .. tostring(preview.Cost) .. "."
end

function Runtime.ApplyToClone(player, moduleTemplate, moduleClone, _moduleTypeForModel)
	local profile = profiles[player.UserId]
	local slotId = tostring(moduleClone:GetAttribute("InstalledSlotId") or "")
	local moduleId = tostring(moduleTemplate:GetAttribute("ModuleId") or moduleTemplate.Name)
	local _, instance = profile and currentInstance(profile, slotId, moduleId)
	local raw = V2.ApplyToModuleRaw(moduleTemplate, instance and instance.V2UpgradePoints or {})
	for name, value in pairs(raw) do moduleClone:SetAttribute(name, value) end
	moduleClone:SetAttribute("V2UpgradePointsApplied", instance and "PROFILE" or "NONE")
end

function Runtime.CalculateProfile(player, profile, _legacyTotals, cockpit, findModule, _moduleTypeForModel)
	profiles[player.UserId] = profile
	assert(cockpit and cockpit:GetAttribute("V2Materialised") == true, "Canonical V2 cockpit is not materialised")
	applyMigration(profile, findModule)
	local modules, allocations = {}, {}
	for slotId, moduleId in pairs(profile.InstalledModules or {}) do
		local module = findModule(profile.CurrentCategory, moduleId)
		if module then
			table.insert(modules, module)
			local _, instance = currentInstance(profile, slotId, moduleId)
			allocations[tostring(module:GetAttribute("ModuleId") or module.Name)] = instance and instance.V2UpgradePoints or {}
		end
	end
	return V2Runtime.CalculateComponents(cockpit, modules, allocations)
end

return Runtime
]==]

local writerSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_CANONICAL_RUNTIME_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local PerformanceRuntime = require(performance:WaitForChild("VehiclePerformanceRuntime"))
local vehicles = Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("Runtime"):WaitForChild("PlayerVehicles")
local pending = {}

local function writeVehicle(vehicle)
	if not (vehicle and vehicle:IsA("Model") and vehicle.Parent == vehicles) or pending[vehicle] then return end
	pending[vehicle] = true
	task.spawn(function()
		local deadline = os.clock() + 5
		repeat
			if not vehicle.Parent then pending[vehicle] = nil; return end
			if vehicle:GetAttribute("V2Materialised") == true and vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") then break end
			task.wait(0.05)
		until os.clock() >= deadline
		local ok, result = pcall(function()
			local calculated = PerformanceRuntime.CalculateBuild(nil, vehicle, vehicle:FindFirstChild("INSTALLED_MODULES_Runtime"))
			PerformanceRuntime.WriteToVehicle(vehicle, calculated)
			return calculated
		end)
		pending[vehicle] = nil
		if ok then
			print(string.format("[NTR Canonical V2 Runtime] Wrote %s %s to %s", tostring(result.Overall.Tier), tostring(result.Overall.PerformanceIndex), vehicle.Name))
		else warn("[NTR Canonical V2 Runtime] Failed for " .. vehicle:GetFullName() .. ": " .. tostring(result)) end
	end)
end

vehicles.ChildAdded:Connect(writeVehicle)
for _, vehicle in ipairs(vehicles:GetChildren()) do writeVehicle(vehicle) end
print("[NTR Canonical V2 Runtime] Spawned-vehicle performance writer active.")
]==]

compile("VehiclePerformanceRuntime", runtimeSource)
compile("VehicleModuleUpgradeRuntime", upgradeSource)
compile("VehiclePerformanceRuntimeService_Active", writerSource)

local function sourceHas(object, marker) return string.find(object.Source, marker, 1, true) ~= nil end
local function audit()
	local pass, fail = 0, 0
	local function check(condition, message)
		if condition then pass += 1; print(PREFIX .. " PASS - " .. message) else fail += 1; warn(PREFIX .. " FAIL - " .. message) end
	end
	check(sourceHas(runtime, REVISION), "spawn calculation facade is canonical V2")
	check(sourceHas(upgrades, REVISION), "profile upgrade facade is canonical V2")
	check(sourceHas(writer, REVISION), "spawn writer no longer reads legacy totals")
	check(not string.find(runtime.Source, "VehiclePerformanceCalculator", 1, true) and not string.find(runtime.Source, "FromLegacyStats", 1, true), "runtime has no legacy calculator branch")
	check(not string.find(upgrades.Source, "VehicleUpgradeDefinitions", 1, true) and not string.find(upgrades.Source, "RuntimeUpgradePurchasesEnabled", 1, true), "upgrade runtime has no legacy purchase branch")
	check(not string.find(writer.Source, "TOTAL_STATS_Runtime", 1, true) and not string.find(writer.Source, "readLegacyTotals", 1, true), "writer has no legacy totals dependency")
	local cockpitCount, moduleCount, nonV2 = 0, 0, 0
	for _, item in ipairs(categories:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("RetiredFromCatalog") ~= true then
			if item:GetAttribute("CockpitId") ~= nil then cockpitCount += 1; if item:GetAttribute("V2Materialised") ~= true then nonV2 += 1 end end
			if item:GetAttribute("ModuleId") ~= nil then moduleCount += 1; if item:GetAttribute("V2Materialised") ~= true then nonV2 += 1 end end
		end
	end
	check(cockpitCount == 6, "six active cockpit templates found")
	check(moduleCount == 84, "84 active module templates found")
	check(nonV2 == 0, "every active cockpit and module is V2 materialised")
	local result = require(resolver)
	local targets = {bruiser_02={"E",200}, bruiser_03={"D",375}, bruiser_01={"C",525}, bruiser_04={"B",662}, bruiser_05={"A",787}, bruiser_06={"S",925}}
	for cockpitId, target in pairs(targets) do
		local calculated = result.Factory(categories, {CockpitId=cockpitId})
		local overall = calculated and calculated.Overall or {}
		check(overall.Tier == target[1] and math.abs((tonumber(overall.PerformanceIndex) or 0) - target[2]) <= 3, cockpitId .. " canonical target remains aligned")
	end
	print(string.format("%s SUMMARY - PASS=%d FAIL=%d", PREFIX, pass, fail))
	assert(fail == 0, "Post-install audit failed")
end

if MODE == "AUDIT" then audit(); return end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")
if sourceHas(runtime, REVISION) and sourceHas(upgrades, REVISION) and sourceHas(writer, REVISION) then audit(); print(PREFIX .. " already installed; no changes made"); return end

local oldRuntime, oldUpgrades, oldWriter = runtime.Source, upgrades.Source, writer.Source
local ok, err = pcall(function()
	runtime.Source = runtimeSource
	upgrades.Source = upgradeSource
	writer.Source = writerSource
	audit()
end)
if not ok then
	pcall(function() runtime.Source = oldRuntime end)
	pcall(function() upgrades.Source = oldUpgrades end)
	pcall(function() writer.Source = oldWriter end)
	error(PREFIX .. " rolled back: " .. tostring(err), 0)
end

print(PREFIX .. " INSTALL COMPLETE - Restart Play and verify garage PI, one upgrade purchase, module preview, and spawned vehicle parity.")
