-- Neo Tokyo Racers - Fresh main profile baseline audit
-- NTR_FRESH_MAIN_PROFILE_BASELINE_AUDIT_V1
-- Run from Studio's Server Command Bar during a fresh Play session after buying
-- exactly one cockpit and then stopping/rejoining once. This script is read-only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Fresh Profile Baseline Audit] "
local TARGET_USER_ID = 7915427645
local EXPECTED_VEHICLES = 1
local EXPECTED_COCKPITS = 1
local EXPECTED_MODULES = 4
local EXPECTED_INSTALLED_REFERENCES = 4

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
	"Run this during Play from the Server Command Bar.")

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

if #failures > 0 then
	error(PREFIX .. table.concat(failures, " | "), 0)
end

local profile = getProfile:Invoke(player)
local summary = getSummary:Invoke(player)
check(typeof(profile) == "table", "Live profile is unavailable.")
check(typeof(summary) == "table", "Profile summary is unavailable.")

if typeof(profile) == "table" and typeof(summary) == "table" then
	local vehicles = countDictionary(profile.Vehicles)
	local cockpits = countDictionary(profile.OwnedCockpitInstances)
	local modules = countDictionary(profile.OwnedModuleInstances)
	local properties = countDictionary(profile.Garage and profile.Garage.OwnedGarageProperties)
	local currentVehicleId = profile.CurrentVehicleId and tostring(profile.CurrentVehicleId) or ""

	check(summary.DataStoreEnabled == true, "Main profile DataStore is not enabled.")
	check(vehicles == EXPECTED_VEHICLES,
		"Expected " .. EXPECTED_VEHICLES .. " vehicle; got " .. tostring(vehicles) .. ".")
	check(cockpits == EXPECTED_COCKPITS,
		"Expected " .. EXPECTED_COCKPITS .. " cockpit instance; got " .. tostring(cockpits) .. ".")
	check(modules == EXPECTED_MODULES,
		"Expected " .. EXPECTED_MODULES .. " module instances; got " .. tostring(modules) .. ".")
	check(tonumber(summary.ModuleInstanceCount) == modules, "Summary module count does not match the live profile.")
	check(currentVehicleId ~= "" and typeof(profile.Vehicles[currentVehicleId]) == "table",
		"CurrentVehicleId does not resolve to the purchased vehicle.")

	local runtime = require(runtimeModule)
	local references, missingReferences = runtime.ReferenceIndex(profile)
	local referenceCount = 0
	local multiplyReferenced = 0
	for _, refs in pairs(references) do
		referenceCount += #refs
		if #refs > 1 then multiplyReferenced += 1 end
	end

	local sourceCounts = {}
	local staleEquippedClaims = 0
	local equippedMismatches = 0
	for instanceIdValue, instance in pairs(profile.OwnedModuleInstances or {}) do
		local instanceId = tostring(instanceIdValue)
		if typeof(instance) ~= "table" then
			check(false, "Invalid module instance " .. instanceId .. ".")
		else
			local source = tostring(instance.Source or "<missing>")
			sourceCounts[source] = (sourceCounts[source] or 0) + 1
			local refs = references[instanceId] or {}
			if #refs == 0 and instance.EquippedVehicleId ~= nil then
				staleEquippedClaims += 1
			elseif #refs == 1 and tostring(instance.EquippedVehicleId or "") ~= tostring(refs[1].VehicleId) then
				equippedMismatches += 1
			end
		end
	end

	local plan = runtime.PlanCleanup(profile)
	check(referenceCount == EXPECTED_INSTALLED_REFERENCES,
		"Expected " .. EXPECTED_INSTALLED_REFERENCES .. " installed module references; got " .. tostring(referenceCount) .. ".")
	check(#missingReferences == 0, "One or more installed module references are missing.")
	check(multiplyReferenced == 0, "A module instance is installed in more than one slot.")
	check(staleEquippedClaims == 0, "An unreferenced module still claims an equipped vehicle.")
	check(equippedMismatches == 0, "An installed module has the wrong EquippedVehicleId.")
	check((sourceCounts.IncludedWithCockpit or 0) == EXPECTED_MODULES,
		"Expected all four baseline modules to be IncludedWithCockpit.")
	check((sourceCounts.LegacyInstalledModules or 0) == 0, "LegacyInstalledModules records were regenerated.")
	check((sourceCounts.BuyModuleInstance or 0) == 0, "Purchased modules exist before the purchase test.")
	check(#plan.DeleteIds == 0, "The fresh profile already contains cleanup deletion candidates.")
	check(#plan.ReviewIds == 0, "The fresh profile contains displaced cockpit grants.")

	print(PREFIX .. string.format(
		"SUMMARY cash=%s vehicles=%d cockpits=%d modules=%d installedRefs=%d garageProperties=%d",
		tostring(profile.Cash), vehicles, cockpits, modules, referenceCount, properties
	))
	print(PREFIX .. "SOURCES included=" .. tostring(sourceCounts.IncludedWithCockpit or 0)
		.. " purchased=" .. tostring(sourceCounts.BuyModuleInstance or 0)
		.. " legacy=" .. tostring(sourceCounts.LegacyInstalledModules or 0))
end

if #failures > 0 then
	for _, message in ipairs(failures) do warn(PREFIX .. "FAIL " .. message) end
	error(PREFIX .. "AUDIT FAIL count=" .. tostring(#failures), 0)
end

print(PREFIX .. "AUDIT PASS - fresh profile persisted with one vehicle and exactly four canonical included modules")
print(PREFIX .. "NEXT buy one module copy, rejoin, and rerun the next inventory-growth audit")
