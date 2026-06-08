-- Neo Tokyo Racers - Vehicle Phase AM runtime integration
-- Run in the Roblox Studio Command Bar while NOT play-testing.
--
-- IMPORTANT:
-- This installer uses guarded source-text replacement against the active garage
-- controller and DrivingControllerV47. It preflights every required match before
-- changing either source. A mismatch stops the install without a partial patch.
--
-- Phase AM gate 1:
-- - Calculates full-build raw, headline, overall, PI, and tier data at spawn.
-- - Adds editable per-cockpit overrides and per-module deltas.
-- - Patches driving to understand the new variables.
-- - Leaves RuntimeIntegration.PhysicsEnabled false until the audit passes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Vehicle Phase AM"
local SERVER_MARKER = "-- NTR_VEHICLE_PHASE_AM_RUNTIME_WRITE"
local DRIVING_MARKER = "-- NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function countPlain(source, needle)
	local count = 0
	local position = 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1
		position = found + #needle
	end
end

local function replaceOnce(source, oldText, newText, label)
	local count = countPlain(source, oldText)
	if count ~= 1 then
		error(label .. " expected exactly 1 match, found " .. tostring(count))
	end
	return string.gsub(source, oldText, function()
		return newText
	end, 1)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureModule(parent, name, source)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("ModuleScript") then
		error(item:GetFullName() .. " must be a ModuleScript")
	end
	if not item then
		item = Instance.new("ModuleScript")
		item.Name = name
		item.Parent = parent
	end
	item.Source = source
	return item
end

local function setDefaultAttribute(item, name, value)
	if item:GetAttribute(name) == nil then
		item:SetAttribute(name, value)
	end
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local performance = shared:WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
assert(performance:FindFirstChild("VehiclePerformanceDefinitions"), "Phase AL definitions are missing")
assert(performance:FindFirstChild("VehiclePerformanceCalculator"), "Phase AL calculator is missing")

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local driving = shared
	:WaitForChild("Modules")
	:WaitForChild("Client")
	:WaitForChild("Controllers")
	:WaitForChild("DrivingControllerV47")

assert(garage:IsA("Script"), garage:GetFullName() .. " must be a Script")
assert(driving:IsA("ModuleScript"), driving:GetFullName() .. " must be a ModuleScript")

local serverOld = [[
		local totals = V56_totalStats(profile)
		for stat, value in pairs(totals) do vehicle:SetAttribute(stat, value) end
		local runtime = vehicle:FindFirstChild("TOTAL_STATS_Runtime") or Instance.new("Folder")
		runtime.Name = "TOTAL_STATS_Runtime"
		runtime.Parent = vehicle
		runtime:ClearAllChildren()
		for stat, value in pairs(totals) do
			local v = Instance.new("NumberValue")
			v.Name = stat
			v.Value = value
			v.Parent = runtime
		end
]]

local serverNew = [[
		local totals = V56_totalStats(profile)
		for stat, value in pairs(totals) do vehicle:SetAttribute(stat, value) end
		local runtime = vehicle:FindFirstChild("TOTAL_STATS_Runtime") or Instance.new("Folder")
		runtime.Name = "TOTAL_STATS_Runtime"
		runtime.Parent = vehicle
		runtime:ClearAllChildren()
		for stat, value in pairs(totals) do
			local v = Instance.new("NumberValue")
			v.Name = stat
			v.Value = value
			v.Parent = runtime
		end

		-- NTR_VEHICLE_PHASE_AM_RUNTIME_WRITE
		local performanceModules = V56_kit
			:WaitForChild("Shared")
			:WaitForChild("Modules")
			:WaitForChild("Common")
			:WaitForChild("Performance")
		local PerformanceRuntime = require(performanceModules:WaitForChild("VehiclePerformanceRuntime"))
		local performanceResult = PerformanceRuntime.CalculateBuild(totals, cockpit, installedRoot)
		PerformanceRuntime.WriteToVehicle(vehicle, performanceResult)
]]

local drivingStatOld = [[
local function stat(name, fallback)
	local vehicle = state.Vehicle
	if not vehicle then return fallback end
	local value = vehicle:GetAttribute(name)
	if typeof(value) == "number" then return value end
	local statsFolder = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
	local number = statsFolder and statsFolder:FindFirstChild(name)
	if number and number:IsA("NumberValue") then return number.Value end
	return fallback
end
]]

local drivingStatNew = [[
-- NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE
local function legacyStat(name, fallback)
	local vehicle = state.Vehicle
	if not vehicle then return fallback end
	local value = vehicle:GetAttribute(name)
	if typeof(value) == "number" then return value end
	local statsFolder = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
	local number = statsFolder and statsFolder:FindFirstChild(name)
	if number and number:IsA("NumberValue") then return number.Value end
	return fallback
end

local function performanceConfig()
	local kit = ReplicatedStorage:FindFirstChild(KIT_NAME)
	local shared = kit and kit:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	local performance = config and config:FindFirstChild("VehiclePerformance_EditAttributes")
	return performance and performance:FindFirstChild("RuntimeIntegration")
end

local function performancePhysicsEnabled()
	local config = performanceConfig()
	return config and config:GetAttribute("PhysicsEnabled") == true
end

local function rawStat(name, fallback)
	if not performancePhysicsEnabled() then return fallback end
	local vehicle = state.Vehicle
	local folder = vehicle and vehicle:FindFirstChild("RAW_PERFORMANCE_Runtime")
	local value = folder and folder:FindFirstChild(name)
	if value and value:IsA("NumberValue") then return value.Value end
	local attribute = vehicle and vehicle:GetAttribute("Performance_" .. name)
	return typeof(attribute) == "number" and attribute or fallback
end

local function influence(name, fallback)
	local config = performanceConfig()
	local value = config and config:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

local function relativeFactor(rawName, baseline, influenceName, defaultInfluence, minimum, maximum)
	if not performancePhysicsEnabled() then return 1 end
	baseline = math.max(math.abs(baseline or 0), 0.001)
	local ratio = rawStat(rawName, baseline) / baseline
	local blended = 1 + (ratio - 1) * influence(influenceName, defaultInfluence)
	return math.clamp(blended, minimum, maximum)
end

local function neutralFactor(rawName, neutral, influenceName, defaultInfluence, minimum, maximum)
	if not performancePhysicsEnabled() then return 1 end
	local value = rawStat(rawName, neutral)
	local blended = 1 + ((value - neutral) / 50) * influence(influenceName, defaultInfluence)
	return math.clamp(blended, minimum, maximum)
end

local function stat(name, fallback)
	if performancePhysicsEnabled() then
		local aliases = {
			Acceleration = "EngineOutput",
			Handling = "SteeringResponse",
			Drift = "DriftControl",
			Braking = "BrakingForce",
			Boost = "BoostForce",
		}
		local rawName = aliases[name]
		if rawName then
			return rawStat(rawName, legacyStat(name, fallback))
		end
	end
	return legacyStat(name, fallback)
end
]]

local drivingVariablesOld = [[
		local boostRecharge = math.max(stat("BoostRecharge", 9), 0.5)
		local weight = math.clamp(stat("Weight", 118), 60, 260)
		local weightFactor = math.clamp(118 / weight, 0.58, 1.25)
]]

local drivingVariablesNew = [[
		local boostRecharge = math.max(stat("BoostRecharge", 9), 0.5)
		local weight = math.clamp(stat("Weight", 118), 60, 260)
		local legacyHandling = math.max(legacyStat("Handling", 48), 1)
		local legacyDrift = math.max(legacyStat("Drift", 46), 1)
		local gripFactor = relativeFactor("LateralGrip", legacyHandling, "LateralGripInfluence", 1, 0.65, 1.45)
		local stabilityFactor = relativeFactor("HoverStability", legacyHandling, "HoverStabilityInfluence", 1, 0.70, 1.35)
		local driftGripFactor = relativeFactor("DriftGrip", legacyDrift, "DriftGripInfluence", 1, 0.65, 1.45)
		local driftChargeFactor = relativeFactor("DriftChargeRate", legacyDrift, "DriftChargeInfluence", 1, 0.60, 1.60)
		local dragFactor = neutralFactor("Drag", 50, "DragInfluence", 0.55, 0.70, 1.30)
		local downforceFactor = neutralFactor("Downforce", 50, "DownforceInfluence", 0.45, 0.80, 1.20)
		local boostEfficiencyFactor = neutralFactor("BoostEfficiency", 50, "BoostEfficiencyInfluence", 0.65, 0.70, 1.35)
		local weightFactor = math.clamp(118 / weight, 0.58, 1.25)
]]

local drivingGripOld = [[
		local lateralGrip = 6.6 + (1.05 - 6.6) * state.DriftBlend
		driveForce += -right * sideSpeed * mass * lateralGrip
		driveForce += -velocity * mass * (0.16 + 0.10 * state.DriftBlend)
]]

local drivingGripNew = [[
		local normalGrip = 6.6 * gripFactor * downforceFactor
		local driftGrip = 1.05 * driftGripFactor
		local lateralGrip = normalGrip + (driftGrip - normalGrip) * state.DriftBlend
		driveForce += -right * sideSpeed * mass * lateralGrip
		driveForce += -velocity * mass * (0.16 + 0.10 * state.DriftBlend) * dragFactor
]]

local drivingChargeOld = [[
			state.DriftCharge = math.min(3.25, state.DriftCharge + dt * (0.95 + math.abs(steeringInput) * 1.15) * state.DriftBlend)
]]

local drivingChargeNew = [[
			state.DriftCharge = math.min(3.25, state.DriftCharge + dt * (0.95 + math.abs(steeringInput) * 1.15) * state.DriftBlend * driftChargeFactor)
]]

local drivingBoostDrainOld = [[
			state.Boost = math.max(0, state.Boost - (100 / boostDuration) * dt)
]]

local drivingBoostDrainNew = [[
			state.Boost = math.max(0, state.Boost - (100 / boostDuration) * dt / boostEfficiencyFactor)
]]

local drivingBoostRechargeOld = [[
				state.Boost = math.min(100, state.Boost + (100 / boostRecharge) * dt)
]]

local drivingBoostRechargeNew = [[
				state.Boost = math.min(100, state.Boost + (100 / boostRecharge) * dt * boostEfficiencyFactor)
]]

local drivingAlignOld = [[
		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch, 0, state.CurrentBank + wobbleRoll)
]]

local drivingAlignNew = [[
		state.Controls.Align.Responsiveness = 22 * stabilityFactor
		state.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(wobblePitch, 0, state.CurrentBank + wobbleRoll)
]]

local garageSource = garage.Source
local drivingSource = driving.Source

if not string.find(garageSource, SERVER_MARKER, 1, true) then
	garageSource = replaceOnce(garageSource, serverOld, serverNew, "garage runtime stat writer")
end

if not string.find(drivingSource, DRIVING_MARKER, 1, true) then
	drivingSource = replaceOnce(drivingSource, drivingStatOld, drivingStatNew, "driving stat bridge")
	drivingSource = replaceOnce(drivingSource, drivingVariablesOld, drivingVariablesNew, "driving detailed variables")
	drivingSource = replaceOnce(drivingSource, drivingGripOld, drivingGripNew, "driving grip and drag")
	drivingSource = replaceOnce(drivingSource, drivingChargeOld, drivingChargeNew, "driving drift charge")
	drivingSource = replaceOnce(drivingSource, drivingBoostDrainOld, drivingBoostDrainNew, "driving boost drain")
	drivingSource = replaceOnce(drivingSource, drivingBoostRechargeOld, drivingBoostRechargeNew, "driving boost recharge")
	drivingSource = replaceOnce(drivingSource, drivingAlignOld, drivingAlignNew, "driving hover stability")
end

local runtimeSource = [==[
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceCalculator"))

local Runtime = {}

local function numberAttribute(item, name)
	local value = item and item:GetAttribute(name)
	return typeof(value) == "number" and value or nil
end

local function collectInstalledModels(installedRoot)
	local result = {}
	if not installedRoot then return result end
	for _, item in ipairs(installedRoot:GetChildren()) do
		if item:IsA("Model") and item:GetAttribute("ModuleId") ~= nil then
			table.insert(result, item)
		end
	end
	return result
end

function Runtime.CalculateBuild(legacyTotals, cockpit, installedRoot)
	local raw = Calculator.FromLegacyStats(legacyTotals)

	for _, variableName in ipairs(Definitions.RawVariableOrder) do
		local override = numberAttribute(cockpit, "PerformanceOverride_" .. variableName)
		if override ~= nil then
			raw[variableName] = override
		end
		local cockpitDelta = numberAttribute(cockpit, "PerformanceDelta_" .. variableName)
		if cockpitDelta ~= nil then
			raw[variableName] = (raw[variableName] or 0) + cockpitDelta
		end
	end

	for _, module in ipairs(collectInstalledModels(installedRoot)) do
		for _, variableName in ipairs(Definitions.RawVariableOrder) do
			local delta = numberAttribute(module, "PerformanceDelta_" .. variableName)
			if delta ~= nil then
				raw[variableName] = (raw[variableName] or 0) + delta
			end
		end
	end

	return Calculator.Calculate(raw)
end

local function rewriteNumberFolder(vehicle, name, values)
	local folder = vehicle:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = vehicle
	end
	folder:ClearAllChildren()
	for key, value in pairs(values) do
		if typeof(value) == "number" then
			local number = Instance.new("NumberValue")
			number.Name = key
			number.Value = value
			number.Parent = folder
		end
	end
	return folder
end

function Runtime.WriteToVehicle(vehicle, result)
	assert(typeof(vehicle) == "Instance", "vehicle is required")
	assert(typeof(result) == "table", "performance result is required")

	rewriteNumberFolder(vehicle, "RAW_PERFORMANCE_Runtime", result.Raw or {})
	rewriteNumberFolder(vehicle, "NORMALIZED_PERFORMANCE_Runtime", result.Normalized or {})
	rewriteNumberFolder(vehicle, "HEADLINE_STATS_Runtime", result.Headline or {})

	for key, value in pairs(result.Raw or {}) do
		if typeof(value) == "number" then
			vehicle:SetAttribute("Performance_" .. key, value)
		end
	end

	local overall = result.Overall or {}
	vehicle:SetAttribute("PerformanceIndex", overall.PerformanceIndex or 100)
	vehicle:SetAttribute("PerformanceTier", overall.Tier or "E")
	vehicle:SetAttribute("PerformanceScore", overall.Score or 0)
	vehicle:SetAttribute("PerformanceRuntimeVersion", "AM_1")
end

return Runtime
]==]

local config = shared:WaitForChild("Config"):WaitForChild("VehiclePerformance_EditAttributes")
local runtimeConfig = ensureFolder(config, "RuntimeIntegration")
setDefaultAttribute(runtimeConfig, "PhysicsEnabled", false)
setDefaultAttribute(runtimeConfig, "LateralGripInfluence", 1)
setDefaultAttribute(runtimeConfig, "HoverStabilityInfluence", 1)
setDefaultAttribute(runtimeConfig, "DriftGripInfluence", 1)
setDefaultAttribute(runtimeConfig, "DriftChargeInfluence", 1)
setDefaultAttribute(runtimeConfig, "DragInfluence", 0.55)
setDefaultAttribute(runtimeConfig, "DownforceInfluence", 0.45)
setDefaultAttribute(runtimeConfig, "BoostEfficiencyInfluence", 0.65)
setDefaultAttribute(runtimeConfig, "EditNote", "Keep PhysicsEnabled false until the Phase AM runtime audit passes. Influence values blend each detailed variable into V75 driving.")

local cockpitDeltaNames = {
	"LateralGrip",
	"SteeringResponse",
	"HoverStability",
	"DriftControl",
	"DriftGrip",
	"DriftChargeRate",
	"BrakingForce",
	"BoostEfficiency",
	"Drag",
	"Downforce",
}

local moduleDeltaNames = {
	Engine = { "EngineOutput", "Weight", "TopSpeed", "Drag" },
	Stabilisers = { "LateralGrip", "SteeringResponse", "HoverStability", "DriftControl", "DriftGrip", "DriftChargeRate" },
	Boost = { "BoostForce", "BoostDuration", "BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Weight" },
	FrontBumper = { "BrakingForce", "Downforce", "Drag", "Weight" },
	RearBumper = { "HoverStability", "DriftControl", "Drag", "Weight" },
	RearSpoiler = { "Downforce", "Drag", "LateralGrip", "TopSpeed", "BrakingForce", "DriftControl", "DriftGrip" },
	SidePods = { "DriftGrip", "LateralGrip", "Downforce", "Drag", "Weight", "HoverStability" },
}

local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local tuningModels = 0
for _, item in ipairs(categories:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("CockpitId") ~= nil then
		for _, variableName in ipairs(cockpitDeltaNames) do
			setDefaultAttribute(item, "PerformanceDelta_" .. variableName, 0)
		end
		tuningModels += 1
	elseif item:IsA("Model") and item:GetAttribute("ModuleId") ~= nil and item:GetAttribute("RetiredFromCatalog") ~= true then
		local moduleType = tostring(item:GetAttribute("ModuleType") or "")
		for _, variableName in ipairs(moduleDeltaNames[moduleType] or {}) do
			setDefaultAttribute(item, "PerformanceDelta_" .. variableName, 0)
		end
		tuningModels += 1
	end
end

local runtimeModule = ensureModule(performance, "VehiclePerformanceRuntime", runtimeSource)
runtimeModule:SetAttribute("Phase", "AM")
performance:SetAttribute("Phase", "AM")
performance:SetAttribute("AuditOnly", false)

garage.Source = garageSource
driving.Source = drivingSource

info("Installed VehiclePerformanceRuntime and patched spawned-vehicle runtime stat writing.")
info("DrivingControllerV47 now understands detailed variables with compatibility fallbacks.")
info("Added editable zero-value performance deltas to " .. tostring(tuningModels) .. " active cockpit/module models.")
info("PhysicsEnabled remains false. Play-test a spawned vehicle, then run the Phase AM runtime audit.")
