-- Neo Tokyo Racers - Canonical module instance lifecycle audit
-- NTR_MODULE_INSTANCE_LIFECYCLE_AUDIT_V1
-- Run from Studio's Server Command Bar during Play. This script is read-only.
-- It automatically recognizes:
--   BASELINE             one vehicle with four included modules
--   PURCHASED_AVAILABLE  one additional purchased module, not equipped
--   PURCHASED_EQUIPPED   the same purchased module equipped, with one included module available

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Module Instance Lifecycle Audit] "
local TARGET_USER_ID = 7915427645

local failures = {}
local function check(condition, message)
	if not condition then table.insert(failures, message) end
end

local function countDictionary(value)
	local count = 0
	if typeof(value) == "table" then
		for _ in pairs(value) do count += 1 end
	end
	return count
end

check(RunService:IsRunning() and RunService:IsServer() and not Players.LocalPlayer,
	"Run during Play from the Server Command Bar.")

local player = Players:GetPlayerByUserId(TARGET_USER_ID)
check(player ~= nil, "Target player is not present.")

local ntr = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = ntr and ntr:FindFirstChild("Services")
local playerServices = services and services:FindFirstChild("Player")
local garage = services and services:FindFirstChild("Garage")
local bindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
local getProfile = bindings and bindings:FindFirstChild("GetProfile")
local getSummary = bindings and bindings:FindFirstChild("GetSummary")
local runtimeModule = garage and garage:FindFirstChild("GarageModuleInventoryRuntime")
check(getProfile and getProfile:IsA("BindableFunction"), "GetProfile binding is missing.")
check(getSummary and getSummary:IsA("BindableFunction"), "GetSummary binding is missing.")
check(runtimeModule and runtimeModule:IsA("ModuleScript"), "GarageModuleInventoryRuntime is missing.")

if #failures > 0 then error(PREFIX .. table.concat(failures, " | "), 0) end

local profile = getProfile:Invoke(player)
local summary = getSummary:Invoke(player)
check(typeof(profile) == "table", "Live profile is unavailable.")
check(typeof(summary) == "table", "Profile summary is unavailable.")
if #failures > 0 then error(PREFIX .. table.concat(failures, " | "), 0) end

local runtime = require(runtimeModule)
local references, missingReferences = runtime.ReferenceIndex(profile)
local vehicles = countDictionary(profile.Vehicles)
local cockpits = countDictionary(profile.OwnedCockpitInstances)
local modules = countDictionary(profile.OwnedModuleInstances)
local currentVehicleId = profile.CurrentVehicleId and tostring(profile.CurrentVehicleId) or ""

check(summary.DataStoreEnabled == true, "Main profile DataStore is not enabled.")
check(vehicles == 1, "Lifecycle test requires exactly one vehicle; got " .. tostring(vehicles) .. ".")
check(cockpits == 1, "Lifecycle test requires exactly one cockpit; got " .. tostring(cockpits) .. ".")
check(currentVehicleId ~= "" and typeof(profile.Vehicles[currentVehicleId]) == "table",
	"CurrentVehicleId does not resolve to the lifecycle-test vehicle.")
check(modules == 4 or modules == 5,
	"Expected four baseline modules or five after one purchase; got " .. tostring(modules) .. ".")
check(tonumber(summary.ModuleInstanceCount) == modules, "Summary module count does not match the live profile.")
check(#missingReferences == 0, "An installed module reference is missing.")

local referenceCount = 0
local multiplyReferenced = 0
for _, refs in pairs(references) do
	referenceCount += #refs
	if #refs > 1 then multiplyReferenced += 1 end
end
check(referenceCount == 4, "Exactly four installed-slot references are required; got " .. tostring(referenceCount) .. ".")
check(multiplyReferenced == 0, "A module instance is referenced by more than one slot.")

local sourceCounts = {}
local purchasedIds = {}
local availableIncludedIds = {}
local staleEquippedClaims = 0
local equippedMismatches = 0
local invalidInstances = 0

for instanceIdValue, instance in pairs(profile.OwnedModuleInstances or {}) do
	local instanceId = tostring(instanceIdValue)
	if typeof(instance) ~= "table" then
		invalidInstances += 1
		continue
	end
	local source = tostring(instance.Source or "<missing>")
	sourceCounts[source] = (sourceCounts[source] or 0) + 1
	local refs = references[instanceId] or {}
	if source == "BuyModuleInstance" then table.insert(purchasedIds, instanceId) end
	if source == "IncludedWithCockpit" and #refs == 0 then table.insert(availableIncludedIds, instanceId) end
	if #refs == 0 then
		if instance.EquippedVehicleId ~= nil then staleEquippedClaims += 1 end
	elseif #refs == 1 then
		if tostring(instance.EquippedVehicleId or "") ~= tostring(refs[1].VehicleId) then
			equippedMismatches += 1
		end
	end
end

check(invalidInstances == 0, "Inventory contains invalid module records.")
check((sourceCounts.LegacyInstalledModules or 0) == 0, "LegacyInstalledModules records were regenerated.")
check((sourceCounts.IncludedWithCockpit or 0) == 4, "The original four cockpit grants were not preserved.")
check((sourceCounts.BuyModuleInstance or 0) == modules - 4,
	"Purchased instance count does not match total inventory growth.")
check(staleEquippedClaims == 0, "An available module still claims an equipped vehicle.")
check(equippedMismatches == 0, "An installed module has the wrong EquippedVehicleId.")

local stage = "UNKNOWN"
local purchasedInstanceId = purchasedIds[1]
local purchasedReferences = purchasedInstanceId and (references[purchasedInstanceId] or {}) or {}

if modules == 4 then
	stage = "BASELINE"
	check(#purchasedIds == 0, "Baseline unexpectedly contains a purchased module.")
	check(#availableIncludedIds == 0, "Baseline cockpit grant is not installed.")
elseif modules == 5 and #purchasedIds == 1 then
	local purchasedInstance = profile.OwnedModuleInstances[purchasedInstanceId]
	check(typeof(purchasedInstance) == "table", "Purchased instance cannot be resolved.")
	if #purchasedReferences == 0 then
		stage = "PURCHASED_AVAILABLE"
		check(purchasedInstance.EquippedVehicleId == nil, "Available purchased module claims an equipped vehicle.")
		check(#availableIncludedIds == 0, "A cockpit grant was displaced before the purchased module was equipped.")
	elseif #purchasedReferences == 1 then
		stage = "PURCHASED_EQUIPPED"
		check(#availableIncludedIds == 1, "Equipping the purchased module should leave exactly one cockpit grant available.")
		check(tostring(purchasedInstance.EquippedVehicleId or "") == tostring(purchasedReferences[1].VehicleId),
			"Purchased module equipped ownership does not match its installed reference.")
	else
		check(false, "Purchased module is installed in more than one slot.")
	end
else
	check(false, "Lifecycle state is not one baseline plus one purchased copy.")
end

local plan = runtime.PlanCleanup(profile)
check(#plan.DeleteIds == 0, "Lifecycle state contains automatic deletion candidates.")
if stage == "PURCHASED_EQUIPPED" then
	check(#plan.ReviewIds == 1 and tostring(plan.ReviewIds[1]) == tostring(availableIncludedIds[1]),
		"The only review record should be the legitimately displaced available cockpit grant.")
else
	check(#plan.ReviewIds == 0, "Baseline/available-purchase state contains an unexpected review record.")
end

print(PREFIX .. string.format(
	"SUMMARY stage=%s cash=%s vehicles=%d cockpits=%d modules=%d installedRefs=%d includedAvailable=%d",
	stage,
	tostring(profile.Cash),
	vehicles,
	cockpits,
	modules,
	referenceCount,
	#availableIncludedIds
))
print(PREFIX .. "SOURCES included=" .. tostring(sourceCounts.IncludedWithCockpit or 0)
	.. " purchased=" .. tostring(sourceCounts.BuyModuleInstance or 0)
	.. " legacy=" .. tostring(sourceCounts.LegacyInstalledModules or 0))
if purchasedInstanceId then print(PREFIX .. "PURCHASED instanceId=" .. purchasedInstanceId) end

if #failures > 0 then
	for _, message in ipairs(failures) do warn(PREFIX .. "FAIL " .. message) end
	error(PREFIX .. "AUDIT FAIL count=" .. tostring(#failures), 0)
end

print(PREFIX .. "AUDIT PASS stage=" .. stage)
if stage == "BASELINE" then
	print(PREFIX .. "NEXT buy exactly one module copy, do not equip it, stop/rejoin, then rerun this audit")
elseif stage == "PURCHASED_AVAILABLE" then
	print(PREFIX .. "NEXT equip this purchased copy, stop/rejoin, then rerun this audit")
else
	print(PREFIX .. "NEXT lifecycle contract confirmed; proceed to shared module-instance view model and card renderer")
end
