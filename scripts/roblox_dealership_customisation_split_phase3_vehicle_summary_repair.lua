-- Neo Tokyo Racers - Dealership / Customisation Split Phase 3 Repair
-- Repairs the per-vehicle summary helper after a nil call in V90_vehicleSummaries.
--
-- Run from Roblox Studio Command Bar in Edit mode after the Phase 3 installer if
-- entering/opening the customisation menu reports:
--
-- GarageActionController_Shadow_Disabled:<line>: attempt to call a nil value
-- function V90_vehicleSummaries
--
-- Cause:
-- The Phase 3 helper was inserted before the local V56_totalStats function is
-- lexically visible, so calling V56_totalStats(profile) can resolve to nil in
-- live Luau. This repair adds a compact local summary-total fallback and uses it
-- when V56_totalStats is not callable from the helper's scope.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PHASE = "Dealership Customisation Split Phase 3 Summary Repair"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_SUMMARY_REPAIR"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 3 summary repair.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Aborting.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before)
end

local function runClientSmoke()
	local player = Players.LocalPlayer
	assert(player, "Client smoke must be run from the CLIENT Command Bar during Play.")
	local invoke = ReplicatedStorage
		:WaitForChild("NeoTokyoRacers")
		:WaitForChild("Shared")
		:WaitForChild("Remotes")
		:WaitForChild("Garage")
		:WaitForChild("GarageInvoke")
	local result = invoke:InvokeServer("GetInitial", {})
	assert(typeof(result) == "table" and result.Success == true, "GetInitial failed: " .. tostring(result and result.Message))
	local count = 0
	for vehicleId, summary in pairs((result.Profile and result.Profile.VehicleSummaries) or {}) do
		count += 1
		local overall = summary.Overall or {}
		info("Vehicle " .. tostring(vehicleId) .. " rating=" .. tostring(overall.Tier or "--") .. " " .. tostring(overall.PerformanceIndex or "---"))
	end
	info("VehicleSummaries smoke OK. count=" .. tostring(count))
end

if RunService:IsRunning() then
	runClientSmoke()
	return
end

local serverScript = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")
assert(serverScript:IsA("Script"), "Expected GarageActionController_Shadow_Disabled to be a Script.")

local source = serverScript.Source
assert(findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_INSTANCE_CARDS"), "Install Phase 3 before running this repair.")

if findPlain(source, MARKER) then
	info("Phase 3 summary repair is already installed.")
	return
end

local helperAnchor = [=[	local function V90_restoreProfileSelection(profile, snapshot)
		profile.CurrentVehicleId = snapshot.CurrentVehicleId
		profile.CurrentCategory = snapshot.CurrentCategory
		profile.CurrentCockpit = snapshot.CurrentCockpit
		profile.CockpitColors = V90_cloneForSummary(snapshot.CockpitColors)
		profile.ThrustColor = snapshot.ThrustColor
		profile.InstalledModules = V90_cloneForSummary(snapshot.InstalledModules)
		profile.ModuleColors = V90_cloneForSummary(snapshot.ModuleColors)
		profile.NeonOwned = V90_cloneForSummary(snapshot.NeonOwned)
	end

	local function V90_vehicleSummaries(profile)]=]

local helperReplacement = [=[	local function V90_restoreProfileSelection(profile, snapshot)
		profile.CurrentVehicleId = snapshot.CurrentVehicleId
		profile.CurrentCategory = snapshot.CurrentCategory
		profile.CurrentCockpit = snapshot.CurrentCockpit
		profile.CockpitColors = V90_cloneForSummary(snapshot.CockpitColors)
		profile.ThrustColor = snapshot.ThrustColor
		profile.InstalledModules = V90_cloneForSummary(snapshot.InstalledModules)
		profile.ModuleColors = V90_cloneForSummary(snapshot.ModuleColors)
		profile.NeonOwned = V90_cloneForSummary(snapshot.NeonOwned)
	end

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_SUMMARY_REPAIR
	local function V90_numberAttribute(instance, name, fallback)
		local value = instance and instance:GetAttribute(name)
		return typeof(value) == "number" and value or fallback
	end

	local function V90_addModuleStats(totals, module)
		if not module then return totals end
		for _, name in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostForce", "EngineOutput", "LateralGrip", "SteeringResponse", "HoverStability", "DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostDuration", "BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce" }) do
			local value = module:GetAttribute(name)
			if typeof(value) == "number" then
				totals[name] = (totals[name] or 0) + value
			end
			local delta = module:GetAttribute("PerformanceDelta_" .. name)
			if typeof(delta) == "number" then
				totals[name] = (totals[name] or 0) + delta
			end
		end
		return totals
	end

	local function V90_summaryTotals(profile)
		if typeof(V56_totalStats) == "function" then
			return V56_totalStats(profile)
		end
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = V90_numberAttribute(cockpit, "TopSpeed", V90_numberAttribute(cockpit, "MaxSpeed", 126)),
			Acceleration = V90_numberAttribute(cockpit, "Acceleration", 42),
			Handling = V90_numberAttribute(cockpit, "Handling", 48),
			Drift = V90_numberAttribute(cockpit, "Drift", 46),
			Braking = V90_numberAttribute(cockpit, "Braking", 44),
			Weight = V90_numberAttribute(cockpit, "Weight", 118),
			Boost = V90_numberAttribute(cockpit, "Boost", 0),
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			V90_addModuleStats(totals, V56_findModule(profile.CurrentCategory, moduleId))
		end
		return totals
	end

	local function V90_vehicleSummaries(profile)]=]

source = replaceOnce(source, helperAnchor, helperReplacement, "summary fallback helper")
source = replaceOnce(
	source,
	[=[						V56_totalStats(profile),]=],
	[=[						V90_summaryTotals(profile),]=],
	"summary total calculation call"
)

serverScript.Source = source
info("Installed Phase 3 VehicleSummaries nil-call repair. Restart Play and open the customisation zone again.")
