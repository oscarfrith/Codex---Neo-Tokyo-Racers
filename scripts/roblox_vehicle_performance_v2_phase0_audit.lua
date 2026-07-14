-- Neo Tokyo Racers - Vehicle Performance V2 Phase 0 live audit
-- READ-ONLY. Run in the Roblox Studio Command Bar in Edit mode.
-- This script creates, edits, clones, reparents, or destroys nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PREFIX = "[NTR Vehicle Performance V2 Phase 0]"
local passCount = 0
local warnCount = 0
local failCount = 0

local function pass(message)
	passCount += 1
	print(PREFIX .. " PASS - " .. message)
end

local function caution(message)
	warnCount += 1
	warn(PREFIX .. " WARN - " .. message)
end

local function fail(message)
	failCount += 1
	warn(PREFIX .. " FAIL - " .. message)
end

local function numberAttribute(item, name, fallback)
	local value = item and item:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

local function findModelByAttribute(root, attributeName, attributeValue)
	if not root then return nil end
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute(attributeName) == attributeValue then
			return item
		end
	end
	return nil
end

local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
if not kit then
	fail("ReplicatedStorage.NeoTokyoRacers is missing")
	print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
	return
end
pass("NeoTokyoRacers root found")

local shared = kit:FindFirstChild("Shared")
local modules = shared and shared:FindFirstChild("Modules")
local common = modules and modules:FindFirstChild("Common")
local performance = common and common:FindFirstChild("Performance")
local client = modules and modules:FindFirstChild("Client")
local controllers = client and client:FindFirstChild("Controllers")
local configRoot = shared and shared:FindFirstChild("Config")
local config = configRoot and configRoot:FindFirstChild("VehiclePerformance_EditAttributes")

if not performance then fail("Shared.Modules.Common.Performance is missing") else pass("Performance module folder found") end
if not config then fail("Shared.Config.VehiclePerformance_EditAttributes is missing") else pass("Performance config found") end

local requiredModuleNames = {
	"VehiclePerformanceDefinitions",
	"VehiclePerformanceCalculator",
	"VehiclePerformanceRuntime",
	"VehicleUpgradeDefinitions",
}
for _, name in ipairs(requiredModuleNames) do
	local item = performance and performance:FindFirstChild(name)
	if item and item:IsA("ModuleScript") then
		pass(name .. " found")
	else
		fail(name .. " ModuleScript is missing")
	end
end

local Definitions
local Calculator
local Upgrades
if performance then
	local okDefinitions, definitionsResult = pcall(require, performance:FindFirstChild("VehiclePerformanceDefinitions"))
	local okCalculator, calculatorResult = pcall(require, performance:FindFirstChild("VehiclePerformanceCalculator"))
	local okUpgrades, upgradesResult = pcall(require, performance:FindFirstChild("VehicleUpgradeDefinitions"))
	if okDefinitions then Definitions = definitionsResult else fail("VehiclePerformanceDefinitions did not require: " .. tostring(definitionsResult)) end
	if okCalculator then Calculator = calculatorResult else fail("VehiclePerformanceCalculator did not require: " .. tostring(calculatorResult)) end
	if okUpgrades then Upgrades = upgradesResult else fail("VehicleUpgradeDefinitions did not require: " .. tostring(upgradesResult)) end
end

local vehicles = kit:FindFirstChild("Assets")
vehicles = vehicles and vehicles:FindFirstChild("Vehicles")
local categories = vehicles and vehicles:FindFirstChild("Categories")
if not categories then
	fail("Assets.Vehicles.Categories is missing")
else
	pass("Vehicle category root found")
end

local cockpits = {}
local activeModules = {}
local moduleById = {}
if categories then
	for _, item in ipairs(categories:GetDescendants()) do
		if item:IsA("Model") and typeof(item:GetAttribute("CockpitId")) == "string" then
			table.insert(cockpits, item)
		elseif item:IsA("Model") and typeof(item:GetAttribute("ModuleId")) == "string" and item:GetAttribute("RetiredFromCatalog") ~= true then
			table.insert(activeModules, item)
			moduleById[item:GetAttribute("ModuleId")] = item
		end
	end
end
table.sort(cockpits, function(a, b) return tostring(a:GetAttribute("CockpitId")) < tostring(b:GetAttribute("CockpitId")) end)

if #cockpits == 5 then pass("Current cockpit count is 5") else caution("Current cockpit count is " .. #cockpits .. "; Phase 0 expected 5") end
if #activeModules == 72 then pass("Current active-module count is 72") else caution("Current active-module count is " .. #activeModules .. "; Phase 0 expected 72") end

local upgradeCount = 0
if Upgrades and typeof(Upgrades.ByModuleType) == "table" then
	for _, definitions in pairs(Upgrades.ByModuleType) do
		if typeof(definitions) == "table" then upgradeCount += #definitions end
	end
end
if upgradeCount == 23 then pass("Current upgrade-definition count is 23") else caution("Current upgrade-definition count is " .. upgradeCount .. "; Phase 0 expected 23") end

local expectedRawCount = 17
if Definitions and #Definitions.RawVariableOrder == expectedRawCount then
	pass("Raw performance contract contains 17 variables")
else
	fail("Raw performance variable contract is not the expected 17-variable foundation")
end

local reservedCockpitId = "bruiser_06"
if findModelByAttribute(categories, "CockpitId", reservedCockpitId) then
	caution("Reserved Zenith CockpitId bruiser_06 already exists; do not clone another in a later phase")
else
	pass("Reserved Zenith CockpitId bruiser_06 is available")
end

local reservedModuleSuffix = "BRUISER_06"
local reservedModuleCollision = false
for moduleId in pairs(moduleById) do
	if string.find(string.upper(moduleId), reservedModuleSuffix, 1, true) then
		reservedModuleCollision = true
		caution("Reserved Zenith module-id family already has " .. moduleId)
	end
end
if not reservedModuleCollision then pass("Reserved BRUISER_06 module-id family is available") end

local viper = findModelByAttribute(categories, "CockpitId", "bruiser_01")
if not viper then
	fail("Piercer Viper cockpit bruiser_01 is missing")
else
	pass("Piercer Viper source cockpit found at " .. viper:GetFullName())
end

local defaultAttributeNames = {
	"DefaultFrontEngineModuleId",
	"DefaultRearEngineModuleId",
	"DefaultStabilisersModuleId",
	"DefaultBoostModuleId",
}
local viperDefaultIds = {}
if viper then
	for _, attributeName in ipairs(defaultAttributeNames) do
		local moduleId = viper:GetAttribute(attributeName)
		if typeof(moduleId) == "string" and moduleById[moduleId] then
			table.insert(viperDefaultIds, moduleId)
			pass(attributeName .. " resolves to " .. moduleId)
		else
			fail(attributeName .. " does not resolve to an active module")
		end
	end
end

local expectedViperDonors = {
	"MODULE_ENGINE_BRUISER_01_STANDARD", "MODULE_ENGINE_BRUISER_01_LIGHTWEIGHT", "MODULE_ENGINE_BRUISER_01_POWER",
	"MODULE_ENGINE_B_BRUISER_01_STANDARD", "MODULE_ENGINE_B_BRUISER_01_LIGHTWEIGHT", "MODULE_ENGINE_B_BRUISER_01_POWER",
	"MODULE_STABILISER_BRUISER_01_STANDARD", "MODULE_STABILISER_BRUISER_01_LIGHTWEIGHT", "MODULE_STABILISER_BRUISER_01_POWER",
	"MODULE_BOOST_BRUISER_01_STANDARD", "MODULE_BOOST_BRUISER_01_LIGHTWEIGHT", "MODULE_BOOST_BRUISER_01_POWER",
}
local donorMissing = 0
for _, moduleId in ipairs(expectedViperDonors) do
	local donor = moduleById[moduleId]
	if not donor then
		donorMissing += 1
		fail("Viper donor module is missing: " .. moduleId)
	elseif not donor:FindFirstChild("ModuleRoot_DoNotRename", true) then
		donorMissing += 1
		fail("Viper donor has no ModuleRoot_DoNotRename: " .. moduleId)
	end
end
if donorMissing == 0 then pass("All 12 Viper Standard/Lightweight/Power donor modules have geometry roots") end

local legacyAttributeNames = {
	"TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostDuration", "BoostRecharge", "BoostRechargeDelay",
}

local function calculateStandardBuild(cockpit)
	if not Calculator or not Definitions then return nil, "calculator unavailable" end
	local totals = {}
	for _, name in ipairs(legacyAttributeNames) do
		totals[name] = numberAttribute(cockpit, name, 0)
	end
	local defaults = {}
	for _, attributeName in ipairs(defaultAttributeNames) do
		local moduleId = cockpit:GetAttribute(attributeName)
		local module = typeof(moduleId) == "string" and moduleById[moduleId] or nil
		if not module then return nil, attributeName .. " unresolved" end
		table.insert(defaults, module)
		for _, name in ipairs(legacyAttributeNames) do
			totals[name] = (totals[name] or 0) + numberAttribute(module, name, 0)
		end
	end
	local raw = Calculator.FromLegacyStats(totals)
	for _, variableName in ipairs(Definitions.RawVariableOrder) do
		local override = cockpit:GetAttribute("PerformanceOverride_" .. variableName)
		if typeof(override) == "number" then raw[variableName] = override end
		raw[variableName] = (raw[variableName] or 0) + numberAttribute(cockpit, "PerformanceDelta_" .. variableName, 0)
		for _, module in ipairs(defaults) do
			raw[variableName] += numberAttribute(module, "PerformanceDelta_" .. variableName, 0)
		end
	end
	return Calculator.Calculate(raw)
end

print(PREFIX .. " --- CURRENT V1 STANDARD BUILDS (reference only) ---")
for _, cockpit in ipairs(cockpits) do
	local result, reason = calculateStandardBuild(cockpit)
	local cockpitId = tostring(cockpit:GetAttribute("CockpitId"))
	local displayName = tostring(cockpit:GetAttribute("DisplayName") or cockpit.Name)
	if result then
		print(string.format(
			"%s STOCK | %s | %s | %s %d | Speed %.1f Accel %.1f Handling %.1f Drift %.1f Braking %.1f Boost %.1f",
			PREFIX, cockpitId, displayName, result.Overall.Tier, result.Overall.PerformanceIndex,
			result.Headline.Speed, result.Headline.Acceleration, result.Headline.Handling,
			result.Headline.Drift, result.Headline.Braking, result.Headline.Boost
		))
	else
		caution(cockpitId .. " standard build could not be calculated: " .. tostring(reason))
	end
end

local dynamics = controllers and controllers:FindFirstChild("VehicleDynamicsModel")
if not dynamics or not dynamics:IsA("ModuleScript") then
	fail("VehicleDynamicsModel is missing")
else
	pass("VehicleDynamicsModel found")
	local okSource, source = pcall(function() return dynamics.Source end)
	if okSource then
		local expectedClampMarkers = {
			"local engineFactor = math.clamp(", "local weightFactor = math.clamp(", "local brakingFactor = math.clamp(",
			"local lateralFactor = math.clamp(", "local driftGripFactor = math.clamp(", "local stabilityFactor = math.clamp(",
		}
		local found = 0
		for _, marker in ipairs(expectedClampMarkers) do
			if string.find(source, marker, 1, true) then found += 1 end
		end
		if found > 0 then
			caution("VehicleDynamicsModel still contains " .. found .. " expected V1 safety/balance clamp markers; Phase 1 must reconcile them with shared V2 curves")
		else
			caution("Expected V1 clamp markers were not found; inspect live dynamics source before Phase 1")
		end
	else
		caution("Studio did not allow Source inspection for VehicleDynamicsModel")
	end
end

local drivingConfigRoot = kit:FindFirstChild("Config")
local drivingConfig = drivingConfigRoot and drivingConfigRoot:FindFirstChild("Runtime")
drivingConfig = drivingConfig and drivingConfig:FindFirstChild("VehicleDynamics_EditAttributes")
if drivingConfig then
	local reverseDelay = drivingConfig:GetAttribute("ReverseEngageDelaySeconds")
	local driftDragBase = drivingConfig:GetAttribute("DriftForwardDragBase")
	local driftDragExtra = drivingConfig:GetAttribute("DriftForwardDragBlendExtra")
	local fullDriftDrag = typeof(driftDragBase) == "number" and typeof(driftDragExtra) == "number" and (driftDragBase + driftDragExtra) or nil
	print(string.format("%s CONFIRMED-BASELINE CHECK | ReverseEngageDelaySeconds=%s | DriftForwardDragBase=%s | DriftForwardDragBlendExtra=%s | FullDrift=%s", PREFIX, tostring(reverseDelay), tostring(driftDragBase), tostring(driftDragExtra), tostring(fullDriftDrag)))
	if reverseDelay == 1 and fullDriftDrag and math.abs(fullDriftDrag - 0.28) < 0.0001 then
		pass("Confirmed Driving Feel Phase 2.1 reverse/drift values are present; Phase 0 made no changes")
	else
		caution("Driving Feel config differs from the confirmed 1.0-second reverse / 0.28 full-drift baseline; explain before Phase 1")
	end
else
	caution("VehicleDynamics_EditAttributes was not found at NeoTokyoRacers.Config.Runtime")
end

print(PREFIX .. " --- SIX-VEHICLE TARGET GUIDE (not live values) ---")
for _, row in ipairs({
	{"E", "Bruiser Forge", "bruiser_02", 200, 40000},
	{"D", "Bruiser Vector", "bruiser_03", 375, 120000},
	{"C", "Piercer Viper", "bruiser_01", 525, 350000},
	{"B", "Bruiser Nightline", "bruiser_04", 662, 1100000},
	{"A", "Bruiser Rally", "bruiser_05", 787, 3500000},
	{"S", "Piercer Zenith", "bruiser_06", 925, 10000000},
}) do
	print(string.format("%s TARGET | %s | %s | %s | PI %d | $%d guide", PREFIX, row[1], row[2], row[3], row[4], row[5]))
end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
if failCount == 0 then
	print(PREFIX .. " READY - Copy the full Output into chat. No Studio objects were changed.")
else
	warn(PREFIX .. " BLOCKED - Resolve FAIL items before creating the V2 calculator or six vehicle templates.")
end
