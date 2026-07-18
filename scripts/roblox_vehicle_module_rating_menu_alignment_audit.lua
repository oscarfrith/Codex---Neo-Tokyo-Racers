-- Neo Tokyo Racers - Vehicle/menu performance and module-rating alignment audit
-- NTR_VEHICLE_MODULE_RATING_MENU_ALIGNMENT_AUDIT_V1
-- READ-ONLY. Run once from the Roblox Studio Command Bar in EDIT mode.
-- This script does not create, edit, clone, reparent, destroy, save, or purchase anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this audit in Edit mode, not Play mode")

local PREFIX = "[NTR Performance Alignment Audit]"
local passCount, warnCount, failCount = 0, 0, 0
local function pass(message) passCount += 1; print(PREFIX .. " PASS - " .. message) end
local function caution(message) warnCount += 1; warn(PREFIX .. " WARN - " .. message) end
local function fail(message) failCount += 1; warn(PREFIX .. " FAIL - " .. message) end
local function finite(value) return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge end
local function textAttribute(item, name, fallback)
	local value = item and item:GetAttribute(name)
	return typeof(value) == "string" and value ~= "" and value or fallback
end
local function numericAttributes(item)
	local result = {}
	for name, value in pairs(item and item:GetAttributes() or {}) do if finite(value) then result[name] = value end end
	return result
end
local function contains(source, needle) return typeof(source) == "string" and string.find(source, needle, 1, true) ~= nil end
local function rounded(value) return math.floor((tonumber(value) or 0) * 100 + 0.5) / 100 end

local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
if not kit then fail("ReplicatedStorage.NeoTokyoRacers is missing"); print(PREFIX .. " SUMMARY - PASS=0 WARN=0 FAIL=1"); return end
local shared = kit:FindFirstChild("Shared")
local configRoot = shared and shared:FindFirstChild("Config")
local v2Config = configRoot and configRoot:FindFirstChild("VehiclePerformanceV2_EditAttributes")
local performanceRoot = shared and shared:FindFirstChild("Modules") and shared.Modules:FindFirstChild("Common") and shared.Modules.Common:FindFirstChild("Performance")
local categories = kit:FindFirstChild("Assets") and kit.Assets:FindFirstChild("Vehicles") and kit.Assets.Vehicles:FindFirstChild("Categories")
if not v2Config then fail("VehiclePerformanceV2_EditAttributes is missing") end
if not performanceRoot then fail("Shared performance module root is missing") end
if not categories then fail("Vehicle category root is missing") end
if failCount > 0 then print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount)); return end
pass("Required V2 config, performance modules, and vehicle catalogue are present")

local requiredModules = {
	"VehiclePerformanceV2Definitions", "VehiclePerformanceV2Calculator", "VehiclePerformanceV2Runtime", "VehiclePerformanceV2UpgradeRuntime",
}
local loaded = {}
for _, name in ipairs(requiredModules) do
	local module = performanceRoot:FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then
		fail(name .. " is missing")
	else
		local ok, result = pcall(require, module)
		if ok and typeof(result) == "table" then loaded[name] = result; pass(name .. " required successfully")
		else fail(name .. " failed to require: " .. tostring(result)) end
	end
end
if failCount > 0 then print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount)); return end
local Definitions = loaded.VehiclePerformanceV2Definitions
local V2Calculator = loaded.VehiclePerformanceV2Calculator
local V2Runtime = loaded.VehiclePerformanceV2Runtime
local V2Upgrade = loaded.VehiclePerformanceV2UpgradeRuntime

if v2Config:GetAttribute("RuntimeRatingEnabled") == true then pass("V2 rating switch is enabled") else fail("RuntimeRatingEnabled is not true") end
if v2Config:GetAttribute("RuntimePhysicsEnabled") == true then pass("V2 physics switch is enabled") else fail("RuntimePhysicsEnabled is not true") end
if v2Config:GetAttribute("RuntimeUpgradePurchasesEnabled") == true then pass("V2 instance-upgrade purchases are enabled") else caution("RuntimeUpgradePurchasesEnabled is not true") end
if v2Config:GetAttribute("ShadowComparisonEnabled") == false then pass("Obsolete V2 shadow comparison is disabled") else caution("ShadowComparisonEnabled remains active") end

local profileRoot = v2Config:FindFirstChild("BalancedStockProfiles")
if not profileRoot then fail("BalancedStockProfiles is missing") end
local targets = {}
if profileRoot then
	for _, folder in ipairs(profileRoot:GetChildren()) do
		if folder:IsA("Folder") then
			local cockpitId = textAttribute(folder, "CockpitId", folder.Name)
			targets[cockpitId] = {
				CockpitId = cockpitId,
				DisplayName = textAttribute(folder, "DisplayName", cockpitId),
				Tier = textAttribute(folder, "TargetTier", ""),
				PI = tonumber(folder:GetAttribute("TargetPI")),
			}
		end
	end
end
if (function() local n = 0; for _ in pairs(targets) do n += 1 end; return n end)() == 6 then pass("Six calibrated stock targets found") else fail("Expected six calibrated stock targets") end

local cockpits, modules, duplicateCockpits, duplicateModules = {}, {}, {}, {}
for _, item in ipairs(categories:GetDescendants()) do
	if item:IsA("Model") then
		local cockpitId = item:GetAttribute("CockpitId")
		local moduleId = item:GetAttribute("ModuleId")
		if typeof(cockpitId) == "string" and cockpitId ~= "" and item:GetAttribute("RetiredFromCatalog") ~= true then
			if cockpits[cockpitId] then duplicateCockpits[cockpitId] = true else cockpits[cockpitId] = item end
		elseif typeof(moduleId) == "string" and moduleId ~= "" and item:GetAttribute("RetiredFromCatalog") ~= true then
			if modules[moduleId] then duplicateModules[moduleId] = true else modules[moduleId] = item end
		end
	end
end
for id in pairs(duplicateCockpits) do fail("Duplicate active CockpitId " .. id) end
for id in pairs(duplicateModules) do fail("Duplicate active ModuleId " .. id) end
local cockpitCount, moduleCount, nonV2Cockpits, nonV2Modules = 0, 0, 0, 0
for _, cockpit in pairs(cockpits) do cockpitCount += 1; if cockpit:GetAttribute("V2Materialised") ~= true then nonV2Cockpits += 1 end end
for _, module in pairs(modules) do moduleCount += 1; if module:GetAttribute("V2Materialised") ~= true then nonV2Modules += 1 end end
if cockpitCount == 6 then pass("Exactly six active cockpits found") else fail("Expected six active cockpits, found " .. cockpitCount) end
if moduleCount == 84 then pass("Exactly 84 active modules found: 72 core V2 modules plus 12 legacy accessory modules") else caution("Expected 84 active modules, found " .. moduleCount) end
if nonV2Cockpits == 0 and nonV2Modules == 0 then
	pass("Every active cockpit and module is V2 materialised; active legacy calculation can be retired")
else
	fail(string.format("V2 materialisation is still required by %d cockpit(s) and %d module(s)", nonV2Cockpits, nonV2Modules))
	for moduleId, module in pairs(modules) do
		if module:GetAttribute("V2Materialised") ~= true then
			print(string.format("%s NON-V2 MODULE | %s | slot %s | %s", PREFIX, moduleId, tostring(module:GetAttribute("ModuleSlot") or module:GetAttribute("ModuleType") or "?"), module:GetFullName()))
		end
	end
end

local defaultNames = {
	FrontEngine = { "DefaultFrontEngineModuleId", "DefaultEngineModuleId" },
	RearEngine = { "DefaultRearEngineModuleId", "DefaultEngineBModuleId" },
	Stabilisers = { "DefaultStabilisersModuleId", "DefaultStabiliserModuleId" },
	Boost = { "DefaultBoostModuleId" },
}
local legacyModuleNames = { "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost" }
local function firstAttribute(item, names)
	for _, name in ipairs(names) do local value = item:GetAttribute(name); if typeof(value) == "string" and value ~= "" then return value end end
end
local function defaultBuild(cockpit)
	local bySlot, list = {}, {}
	for slotId, names in pairs(defaultNames) do
		local moduleId = firstAttribute(cockpit, names)
		local module = moduleId and modules[moduleId]
		if not module then return nil, nil, slotId .. " default does not resolve: " .. tostring(moduleId) end
		bySlot[slotId] = module
		table.insert(list, module)
	end
	return bySlot, list
end
local function legacyDealershipResult(cockpit, defaultList)
	local totals = numericAttributes(cockpit)
	for _, module in ipairs(defaultList or {}) do
		for _, name in ipairs(legacyModuleNames) do totals[name] = (totals[name] or 0) + (tonumber(module:GetAttribute(name)) or 0) end
	end
	-- This intentionally reproduces the current dealership compatibility path for comparison only.
	local compatibility = require(performanceRoot:WaitForChild("VehiclePerformanceCalculator"))
	return compatibility.CalculateLegacy(totals)
end

local stockRows = {}
for cockpitId, target in pairs(targets) do
	local cockpit = cockpits[cockpitId]
	if not cockpit then
		fail(target.DisplayName .. " cockpit " .. cockpitId .. " is missing")
	else
		local bySlot, defaultList, errorMessage = defaultBuild(cockpit)
		if not bySlot then
			fail(target.DisplayName .. " " .. errorMessage)
		else
			local canonical = V2Runtime.CalculateComponents(cockpit, defaultList, {})
			local legacy = legacyDealershipResult(cockpit, defaultList)
			local canonicalPI = canonical.Overall and canonical.Overall.PerformanceIndex or 0
			local canonicalTier = canonical.Overall and canonical.Overall.Tier or "?"
			local legacyPI = legacy.Overall and legacy.Overall.PerformanceIndex or 0
			local legacyTier = legacy.Overall and legacy.Overall.Tier or "?"
			local targetGap = canonicalPI - (target.PI or canonicalPI)
			local menuGap = legacyPI - canonicalPI
			if canonicalTier == target.Tier and math.abs(targetGap) <= 3 then
				pass(string.format("%s canonical stock build is %s %d (target %s %d)", target.DisplayName, canonicalTier, canonicalPI, target.Tier, target.PI))
			else
				fail(string.format("%s canonical stock build is %s %d; target is %s %s", target.DisplayName, canonicalTier, canonicalPI, target.Tier, tostring(target.PI)))
			end
			if legacyPI ~= canonicalPI or legacyTier ~= canonicalTier then
				caution(string.format("%s current dealership fallback diverges: %s %d versus canonical %s %d (gap %+.0f)", target.DisplayName, legacyTier, legacyPI, canonicalTier, canonicalPI, menuGap))
			else pass(target.DisplayName .. " dealership fallback happens to match canonical stock output") end
			table.insert(stockRows, { Target = target, Cockpit = cockpit, Defaults = bySlot, Canonical = canonical, Legacy = legacy })
			local h, r = canonical.Headline or {}, canonical.Raw or {}
			print(string.format("%s STOCK | %-9s | canonical %s %3d | legacy-menu %s %3d | target-gap %+.0f | menu-gap %+.0f | S %.1f A %.1f H %.1f D %.1f B %.1f X %.1f",
				PREFIX, target.DisplayName, canonicalTier, canonicalPI, legacyTier, legacyPI, targetGap, menuGap,
				h.Speed or 0, h.Acceleration or 0, h.Handling or 0, h.Drift or 0, h.Braking or 0, h.Boost or 0))
			print(string.format("%s DRIVE RAW | %-9s | top %.2f output %.2f weight %.2f grip %.2f steer %.2f stability %.2f drift %.2f/%.2f/%.2f brake %.2f boost %.2f dur %.2f recharge %.2f delay %.3f drag %.2f downforce %.2f",
				PREFIX, target.DisplayName, r.TopSpeed or 0, r.EngineOutput or 0, r.Weight or 0, r.LateralGrip or 0, r.SteeringResponse or 0, r.HoverStability or 0,
				r.DriftControl or 0, r.DriftGrip or 0, r.DriftChargeRate or 0, r.BrakingForce or 0, r.BoostForce or 0, r.BoostDuration or 0,
				r.BoostRecharge or 0, r.BoostRechargeDelay or 0, r.Drag or 0, r.Downforce or 0))
		end
	end
end
table.sort(stockRows, function(a, b) return (a.Target.PI or 0) < (b.Target.PI or 0) end)

local reference
for _, row in ipairs(stockRows) do if row.Target.CockpitId == "bruiser_01" then reference = row end end
local function moduleSlot(module)
	local id = string.upper(tostring(module:GetAttribute("ModuleId") or module.Name))
	local folder = string.lower(tostring(module:GetAttribute("ModuleFolder") or ""))
	local position = string.lower(tostring(module:GetAttribute("EnginePosition") or ""))
	if module:GetAttribute("RearEngine") == true or position == "rear" or folder == "engines_b" or string.find(id, "MODULE_ENGINE_B_", 1, true) then return "RearEngine" end
	if position == "front" or folder == "engines" or string.find(id, "MODULE_ENGINE_", 1, true) then return "FrontEngine" end
	if string.find(id, "STABILISER", 1, true) or string.find(folder, "stabil", 1, true) then return "Stabilisers" end
	if string.find(id, "BOOST", 1, true) or string.find(folder, "boost", 1, true) then return "Boost" end
end
local function moduleVariant(module)
	local explicit = textAttribute(module, "VariantName", nil)
	if explicit == "Standard" or explicit == "Lightweight" or explicit == "Power" then return explicit end
	local id = string.upper(tostring(module:GetAttribute("ModuleId") or module.Name))
	if string.find(id, "LIGHTWEIGHT", 1, true) then return "Lightweight" end
	if string.find(id, "POWER", 1, true) then return "Power" end
	return "Standard"
end
local function sourceCockpitId(module)
	local explicit = textAttribute(module, "SourceCockpitId", nil)
	if explicit then return explicit end
	local number = string.match(string.upper(tostring(module:GetAttribute("ModuleId") or module.Name)), "BRUISER_(%d%d)")
	return number and ("bruiser_" .. number) or nil
end
local function referenceRating(module, allocation)
	local slotId = moduleSlot(module)
	if not (reference and slotId and reference.Defaults[slotId]) then return nil end
	local list = {}
	for referenceSlot, referenceModule in pairs(reference.Defaults) do table.insert(list, referenceSlot == slotId and module or referenceModule) end
	local moduleId = tostring(module:GetAttribute("ModuleId") or module.Name)
	local result = V2Runtime.CalculateComponents(reference.Cockpit, list, allocation and { [moduleId] = allocation } or {})
	return result.Overall and result.Overall.PerformanceIndex, result
end

if not reference then
	fail("Viper reference stock build is unavailable; module-rating simulation cannot run")
else
	pass("Fixed Viper reference build is available for derived module ratings")
	local ladders = {}
	for _, module in pairs(modules) do
		local slotId, variant, sourceId = moduleSlot(module), moduleVariant(module), sourceCockpitId(module)
		if slotId and targets[sourceId] then
			local key = slotId .. ":" .. variant
			ladders[key] = ladders[key] or {}
			local rating = referenceRating(module)
			table.insert(ladders[key], { Module = module, Source = targets[sourceId], Rating = rating or 0 })
		end
	end
	for key, ladder in pairs(ladders) do
		table.sort(ladder, function(a, b) return (a.Source.PI or 0) < (b.Source.PI or 0) end)
		local values, monotonic = {}, #ladder == 6
		local previous = -math.huge
		for _, item in ipairs(ladder) do
			table.insert(values, string.format("%s=%d", item.Source.DisplayName, item.Rating))
			if item.Rating < previous then monotonic = false end
			previous = item.Rating
		end
		print(PREFIX .. " MODULE LADDER | " .. key .. " | " .. table.concat(values, "  "))
		if monotonic then pass(key .. " fixed-reference ratings progress from Forge through Zenith")
		else caution(key .. " fixed-reference ratings are not monotonic; calibration is required before publishing module ratings") end
	end

	local upgradeCandidate = modules["MODULE_ENGINE_BRUISER_01_POWER"]
	if upgradeCandidate then
		local paths = V2Upgrade.Catalog(upgradeCandidate, {})
		local first = paths and paths[1]
		if first and first.PathId then
			local baseRating = referenceRating(upgradeCandidate)
			local upgradedRating = referenceRating(upgradeCandidate, { [first.PathId] = 1 })
			print(string.format("%s MODULE UPGRADE SAMPLE | %s | stock %d -> one %s point %d", PREFIX, upgradeCandidate.Name, baseRating or 0, tostring(first.PathId), upgradedRating or 0))
			if upgradedRating and baseRating and upgradedRating > baseRating then pass("Saved instance upgrade allocation increases the derived module rating")
			else caution("First upgrade path did not increase the rounded fixed-reference module rating; use internal PI precision in the implementation") end
		else caution("Power front-engine upgrade catalogue is empty") end
	else caution("Viper Power front engine is missing for the upgrade-aware rating sample") end
end

local clientRoot = StarterPlayer:FindFirstChild("StarterPlayerScripts") and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
local ui = clientRoot and clientRoot:FindFirstChild("Controllers") and clientRoot.Controllers:FindFirstChild("UI")
local application = ui and ui:FindFirstChild("ModuleShopUIController")
if application and application:IsA("ModuleScript") then
	local source = application.Source
	if contains(source, "local function defaults(c)") and contains(source, "Calculator.CalculateLegacy(defaults(c))") then
		caution("Canonical garage still owns the divergent legacy dealership calculation; replace it with the shared V2 resolver")
	else pass("Canonical garage no longer contains the known legacy dealership calculation") end
	if contains(source, "VehiclePerformanceCalculator") then caution("Canonical garage still depends on the compatibility calculator")
	else pass("Canonical garage has no compatibility-calculator dependency") end
else fail("ModuleShopUIController is missing") end

local garage = ServerScriptService:FindFirstChild("NeoTokyoRacers")
garage = garage and garage:FindFirstChild("Services") and garage.Services:FindFirstChild("Garage") and garage.Services.Garage:FindFirstChild("GarageActionController_Shadow_Disabled")
if garage and garage:IsA("LuaSourceContainer") then
	if contains(garage.Source, "V77_ModuleUpgrades.CalculateProfile") then pass("Owned vehicle summaries route through the upgrade-aware performance runtime")
	else fail("Owned vehicle summaries do not use the expected upgrade-aware runtime") end
else fail("Garage server action owner is missing") end

local dynamics = shared.Modules and shared.Modules:FindFirstChild("Client") and shared.Modules.Client:FindFirstChild("Controllers") and shared.Modules.Client.Controllers:FindFirstChild("VehicleDynamicsModel")
if dynamics and dynamics:IsA("ModuleScript") then
	local source = dynamics.Source
	local requiredReads = { "RAW_PERFORMANCE_Runtime", "TopSpeed", "EngineOutput", "Weight", "LateralGrip", "SteeringResponse", "HoverStability", "DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostForce", "BoostDuration", "BoostRecharge", "BoostRechargeDelay", "Drag", "Downforce" }
	local missing = {}
	for _, token in ipairs(requiredReads) do if not contains(source, token) then table.insert(missing, token) end end
	if #missing == 0 then pass("Driving dynamics consumes the canonical V2 raw-stat contract") else fail("Driving dynamics is missing V2 inputs: " .. table.concat(missing, ", ")) end
else fail("VehicleDynamicsModel is missing") end

local dependencyHits = {}
for _, object in ipairs(game:GetDescendants()) do
	if object:IsA("LuaSourceContainer") and object ~= application then
		local ok, source = pcall(function() return object.Source end)
		if ok and (contains(source, "VehiclePerformanceCalculator") or contains(source, "CalculateLegacy")) then table.insert(dependencyHits, object:GetFullName()) end
	end
end
table.sort(dependencyHits)
print(PREFIX .. " LEGACY DEPENDENCY INVENTORY | count=" .. tostring(#dependencyHits))
for _, path in ipairs(dependencyHits) do print(PREFIX .. " LEGACY DEPENDENCY | " .. path) end
if #dependencyHits == 0 then pass("No additional legacy performance dependencies remain")
else caution(tostring(#dependencyHits) .. " additional compatibility dependencies require classification before removal") end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
if failCount == 0 then
	print(PREFIX .. " AUDIT COMPLETE - No changes were made. Return the complete Output before the canonical resolver installer is generated.")
else
	warn(PREFIX .. " BLOCKED - Resolve FAIL items before replacing performance ownership. No changes were made.")
end
