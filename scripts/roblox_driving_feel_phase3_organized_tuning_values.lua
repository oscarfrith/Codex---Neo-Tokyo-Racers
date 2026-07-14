-- Neo Tokyo Racers - Driving Feel Phase 3 organised tuning values
-- Run once in Roblox Studio Command Bar in Edit mode, after Phase 3.
--
-- Migrates every current numeric VehicleDynamics_EditAttributes value into one
-- category Folder whose Attributes alternate as:
--   SettingName (number) / SettingName_RaisingThisDoes (string)
-- Existing category values, nested organiser values, and flat live attributes
-- all win over defaults in that order. Reruns preserve organised values.
-- This script creates no backups and changes no driving formula.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before organising Driving Feel tuning values")

local PREFIX = "[NTR Driving Feel Organiser]"
local function info(message) print(PREFIX .. " " .. message) end
local function countPlain(source, needle)
	local count, position = 0, 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1
		position = found + #needle
	end
end
local function replacePlainOnce(source, oldText, newText, label)
	local count = countPlain(source, oldText)
	assert(count == 1, label .. " expected exactly one live source match, found " .. tostring(count))
	local first, last = string.find(source, oldText, 1, true)
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end
local function ensureFolder(parent, name)
	local child = parent:FindFirstChild(name)
	if child then assert(child:IsA("Folder"), child:GetFullName() .. " must be a Folder")
	else child = Instance.new("Folder"); child.Name = name; child.Parent = parent end
	return child
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local controllers = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers")
local driving = controllers:WaitForChild("DrivingControllerV47")
local dynamics = controllers:WaitForChild("VehicleDynamicsModel")
local config = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("VehicleDynamics_EditAttributes")
assert(driving:IsA("ModuleScript") and dynamics:IsA("ModuleScript"), "Driving owners must be ModuleScripts")
assert(string.find(driving.Source, "NTR_DRIVING_FEEL_PHASE3_TIER_SAFE_WEIGHT", 1, true), "Install Driving Feel Phase 3 first")
assert(string.find(dynamics.Source, "NTR_DRIVING_FEEL_PHASE3_TIER_CURVE_DYNAMICS", 1, true), "Install Driving Feel Phase 3 first")

local controllerOld = [[function configNumber(folderName, name, fallback, minimum, maximum)
	local folder = configFolder(folderName)
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "number" then
		value = fallback
	end
	if minimum and maximum then
		return math.clamp(value, minimum, maximum)
	end
	return value
end]]

local controllerNested = [[-- NTR_DRIVING_FEEL_ORGANISED_CONFIG_READER
local organisedConfigNumberCaches = setmetatable({}, {__mode = "k"})
local function organisedConfigNumber(folder, name)
	if not folder then return nil end
	local cache = organisedConfigNumberCaches[folder]
	if not cache then
		cache = {}
		for _, category in ipairs(folder:GetChildren()) do
			if category:IsA("Folder") then
				for _, setting in ipairs(category:GetChildren()) do
					if setting:IsA("Folder") then
						local valueObject = setting:FindFirstChild("01_Value")
						if valueObject and valueObject:IsA("NumberValue") then cache[setting.Name] = valueObject end
					end
				end
			end
		end
		organisedConfigNumberCaches[folder] = cache
	end
	local valueObject = cache[name]
	return valueObject and valueObject.Value or nil
end

function configNumber(folderName, name, fallback, minimum, maximum)
	local folder = configFolder(folderName)
	local value = organisedConfigNumber(folder, name)
	if typeof(value) ~= "number" then value = folder and folder:GetAttribute(name) end
	if typeof(value) ~= "number" then value = fallback end
	if minimum and maximum then return math.clamp(value, minimum, maximum) end
	return value
end]]

local controllerFlat = [[-- NTR_DRIVING_FEEL_FLAT_CATEGORY_CONFIG_READER
local categorisedConfigNumberCaches = setmetatable({}, {__mode = "k"})
local function categorisedConfigNumber(folder, name)
	if not folder then return nil end
	local cache = categorisedConfigNumberCaches[folder]
	if not cache then
		cache = {}
		for _, category in ipairs(folder:GetChildren()) do
			if category:IsA("Folder") then
				for attributeName, attributeValue in pairs(category:GetAttributes()) do
					if typeof(attributeValue) == "number" then cache[attributeName] = category end
				end
			end
		end
		categorisedConfigNumberCaches[folder] = cache
	end
	local category = cache[name]
	return category and category:GetAttribute(name) or nil
end

function configNumber(folderName, name, fallback, minimum, maximum)
	local folder = configFolder(folderName)
	local value = categorisedConfigNumber(folder, name)
	if typeof(value) ~= "number" then value = folder and folder:GetAttribute(name) end
	if typeof(value) ~= "number" then value = fallback end
	if minimum and maximum then return math.clamp(value, minimum, maximum) end
	return value
end]]

local moduleOld = [[local function numberAttribute(folder, name, fallback, minimum, maximum)
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "number" then value = fallback end
	if minimum ~= nil and maximum ~= nil then value = math.clamp(value, minimum, maximum) end
	return value
end]]

local moduleNested = [[-- NTR_DRIVING_FEEL_ORGANISED_CONFIG_READER
local organisedNumberCacheFolder, organisedNumberCache
local function organisedNumber(folder, name)
	if not folder then return nil end
	if organisedNumberCacheFolder ~= folder then
		organisedNumberCacheFolder, organisedNumberCache = folder, {}
		for _, category in ipairs(folder:GetChildren()) do
			if category:IsA("Folder") then
				for _, setting in ipairs(category:GetChildren()) do
					if setting:IsA("Folder") then
						local valueObject = setting:FindFirstChild("01_Value")
						if valueObject and valueObject:IsA("NumberValue") then organisedNumberCache[setting.Name] = valueObject end
					end
				end
			end
		end
	end
	local valueObject = organisedNumberCache and organisedNumberCache[name]
	return valueObject and valueObject.Value or nil
end

local function numberAttribute(folder, name, fallback, minimum, maximum)
	local value = organisedNumber(folder, name)
	if typeof(value) ~= "number" then value = folder and folder:GetAttribute(name) end
	if typeof(value) ~= "number" then value = fallback end
	if minimum ~= nil and maximum ~= nil then value = math.clamp(value, minimum, maximum) end
	return value
end]]

local moduleFlat = [[-- NTR_DRIVING_FEEL_FLAT_CATEGORY_CONFIG_READER
local categorisedNumberCacheFolder, categorisedNumberCache
local function categorisedNumber(folder, name)
	if not folder then return nil end
	if categorisedNumberCacheFolder ~= folder then
		categorisedNumberCacheFolder, categorisedNumberCache = folder, {}
		for _, category in ipairs(folder:GetChildren()) do
			if category:IsA("Folder") then
				for attributeName, attributeValue in pairs(category:GetAttributes()) do
					if typeof(attributeValue) == "number" then categorisedNumberCache[attributeName] = category end
				end
			end
		end
	end
	local category = categorisedNumberCache and categorisedNumberCache[name]
	return category and category:GetAttribute(name) or nil
end

local function numberAttribute(folder, name, fallback, minimum, maximum)
	local value = categorisedNumber(folder, name)
	if typeof(value) ~= "number" then value = folder and folder:GetAttribute(name) end
	if typeof(value) ~= "number" then value = fallback end
	if minimum ~= nil and maximum ~= nil then value = math.clamp(value, minimum, maximum) end
	return value
end]]

local controllerHasFlat = string.find(driving.Source, "NTR_DRIVING_FEEL_FLAT_CATEGORY_CONFIG_READER", 1, true) ~= nil
local moduleHasFlat = string.find(dynamics.Source, "NTR_DRIVING_FEEL_FLAT_CATEGORY_CONFIG_READER", 1, true) ~= nil
local controllerHasNested = string.find(driving.Source, "NTR_DRIVING_FEEL_ORGANISED_CONFIG_READER", 1, true) ~= nil
local moduleHasNested = string.find(dynamics.Source, "NTR_DRIVING_FEEL_ORGANISED_CONFIG_READER", 1, true) ~= nil
assert(controllerHasFlat == moduleHasFlat and controllerHasNested == moduleHasNested, "Partial organised-reader install detected; refresh the mirror before repair")
assert(not (controllerHasFlat and controllerHasNested), "Conflicting organised-reader markers detected; refresh the mirror before repair")
if controllerHasNested then
	assert(countPlain(driving.Source, controllerNested) == 1, "Controller nested reader differs from the generated V1 organiser")
	assert(countPlain(dynamics.Source, moduleNested) == 1, "Dynamics nested reader differs from the generated V1 organiser")
elseif not controllerHasFlat then
	assert(countPlain(driving.Source, controllerOld) == 1, "Controller config reader differs from the confirmed Phase 3 shape")
	assert(countPlain(dynamics.Source, moduleOld) == 1, "Dynamics config reader differs from the confirmed Phase 3 shape")
end
info("PASS - Phase 3 markers and both flat-category reader anchors preflighted.")

local C = {
	ACCELERATION = "01_Acceleration",
	HANDLING = "02_Handling",
	DRIFTING = "03_Drifting",
	BOOST = "04_Boost",
	BRAKING = "05_Braking_Reverse_Parking",
	GRIP = "06_Grip_Hover",
	ADVANCED = "07_Advanced",
}
for _, categoryName in ipairs({C.ACCELERATION,C.HANDLING,C.DRIFTING,C.BOOST,C.BRAKING,C.GRIP,C.ADVANCED}) do
	ensureFolder(config, categoryName)
end

-- name, category, effective Phase 3 fallback, effect of raising the value
local definitions = {
	{"BaseForwardAcceleration",C.ACCELERATION,32,"Increases forward acceleration across the speed range."},
	{"LaunchAccelerationMultiplier",C.ACCELERATION,0.45,"Makes the initial launch below the ramp speed stronger."},
	{"LaunchRampEndMph",C.ACCELERATION,14,"Extends the softer launch section to a higher speed."},
	{"LaunchEngineInfluence",C.ACCELERATION,0.35,"Makes engine-power differences more noticeable during launch."},
	{"EngineOutputReference",C.ACCELERATION,60,"Requires more EngineOutput to reach the reference acceleration multiplier."},
	{"EngineOutputExponent",C.ACCELERATION,0.55,"Widens acceleration differences between weak and powerful engines."},
	{"EngineOutputMinMultiplier",C.ACCELERATION,0.72,"Raises the minimum acceleration available to low-power vehicles."},
	{"EngineOutputMaxMultiplier",C.ACCELERATION,1.48,"Raises the maximum acceleration available to high-power vehicles."},
	{"WeightReference",C.ACCELERATION,118,"Moves the weight point that counts as neutral for acceleration and braking."},
	{"WeightAccelerationExponent",C.ACCELERATION,0.22,"Makes vehicle weight affect acceleration more strongly."},
	{"WeightAccelerationMinMultiplier",C.ACCELERATION,0.82,"Improves the worst acceleration multiplier for heavy vehicles."},
	{"WeightAccelerationMaxMultiplier",C.ACCELERATION,1.18,"Improves the best acceleration multiplier for light vehicles."},
	{"PowerBandStartRatioLow",C.ACCELERATION,0.48,"Lets low-power vehicles retain strong pull closer to top speed."},
	{"PowerBandStartRatioHigh",C.ACCELERATION,0.70,"Lets high-power vehicles retain strong pull closer to top speed."},
	{"HighSpeedAccelerationExponent",C.ACCELERATION,0.80,"Makes acceleration fall away more sharply after the power band."},
	{"HighSpeedAccelerationFloor",C.ACCELERATION,0.06,"Leaves more engine pull available very near top speed."},
	{"AerodynamicDragPerMphSquared",C.ACCELERATION,0.00012,"Adds more speed-squared air resistance at high speed."},
	{"AerodynamicDragStatExponent",C.ACCELERATION,0.35,"Makes the vehicle Drag stat influence air resistance more strongly."},
	{"DragReference",C.ACCELERATION,50,"Requires a higher Drag stat to reach the neutral air-resistance point."},
	{"SoftLimiterStrength",C.ACCELERATION,2.5,"Pushes the vehicle back under its forward or reverse speed limit more strongly."},

	{"BasePhysicalSteeringResponse",C.HANDLING,58,"Makes every vehicle turn more quickly."},
	{"SteeringResponseReference",C.HANDLING,50,"Requires more SteeringResponse stat to reach neutral steering."},
	{"SteeringResponseExponent",C.HANDLING,0.42,"Widens the steering difference between low- and high-stat vehicles."},
	{"SteeringResponseMinMultiplier",C.HANDLING,0.78,"Improves the minimum steering available to low-stat vehicles."},
	{"SteeringResponseMaxMultiplier",C.HANDLING,1.30,"Raises the maximum steering available to high-stat vehicles."},
	{"SteeringWeightInfluenceExponent",C.HANDLING,0.12,"Makes weight influence steering and drift control more strongly."},
	{"SteeringWeightMinMultiplier",C.HANDLING,0.88,"Improves the worst steering multiplier for heavy vehicles."},
	{"SteeringWeightMaxMultiplier",C.HANDLING,1.12,"Improves the best steering multiplier for light vehicles."},

	{"BasePhysicalDriftControl",C.DRIFTING,50,"Increases the baseline drift turning authority for every vehicle."},
	{"PhysicalDriftControlExponent",C.DRIFTING,0.35,"Widens physical drift-control differences between vehicle stats."},
	{"PhysicalDriftControlMinMultiplier",C.DRIFTING,0.82,"Improves minimum drift control on low-stat vehicles."},
	{"PhysicalDriftControlMaxMultiplier",C.DRIFTING,1.25,"Raises maximum drift control on high-stat vehicles."},
	{"BaseDriftLateralGrip",C.DRIFTING,2.0,"Adds drift grip and reduces boat-like sideways sliding."},
	{"BaseDriftSideForce",C.DRIFTING,26,"Adds more sideways turning force while drifting."},
	{"DriftGripReference",C.DRIFTING,50,"Requires more DriftGrip stat to reach neutral drift grip."},
	{"DriftGripExponent",C.DRIFTING,0.35,"Makes the DriftGrip stat affect remaining slide more strongly."},
	{"DriftControlReference",C.DRIFTING,50,"Requires more DriftControl stat to reach neutral drift authority."},
	{"DriftControlExponent",C.DRIFTING,0.32,"Makes DriftControl affect turning and alignment more strongly."},
	{"DriftChargeReference",C.DRIFTING,50,"Requires more DriftChargeRate to reach neutral drift-charge speed."},
	{"DriftChargeExponent",C.DRIFTING,0.35,"Makes DriftChargeRate change drift-charge speed more strongly."},
	{"DriftForwardDragBase",C.DRIFTING,0.10,"Removes more forward speed throughout a drift."},
	{"DriftForwardDragBlendExtra",C.DRIFTING,0.06,"Adds more forward-speed loss as the drift reaches full blend."},
	{"DriftEngineAssist",C.DRIFTING,0.20,"Adds more forward engine drive while acceleration is held in a drift."},
	{"DriftVelocityAlignmentRate",C.DRIFTING,2.0,"Pulls vehicle momentum around the direction of the corner more quickly."},
	{"DriftVelocityAlignmentMaxAcceleration",C.DRIFTING,30,"Allows a stronger maximum momentum-alignment force during a drift."},
	{"DriftThrottleMinimum",C.DRIFTING,0.05,"Requires more accelerator input before drift drive and alignment activate."},

	{"BoostDurationReferenceSeconds",C.BOOST,3.0,"Makes the reference boost charge last longer."},
	{"BoostDurationExponent",C.BOOST,0.32,"Widens boost-duration differences between low- and high-stat vehicles."},
	{"BoostDurationMinSeconds",C.BOOST,2.2,"Makes the shortest possible boost last longer."},
	{"BoostDurationMaxSeconds",C.BOOST,4.2,"Makes the longest possible boost last longer."},
	{"BoostRechargeReferenceSeconds",C.BOOST,8.5,"Makes the reference boost recharge take longer."},
	{"BoostRechargeExponent",C.BOOST,0.32,"Widens recharge-time differences between low- and high-stat vehicles."},
	{"BoostRechargeMinSeconds",C.BOOST,6.5,"Makes even the fastest possible recharge take longer."},
	{"BoostRechargeMaxSeconds",C.BOOST,10.5,"Makes the slowest possible recharge take longer."},
	{"BoostRechargeDelayExponent",C.BOOST,0.25,"Makes the vehicle recharge-delay stat affect the physical delay more strongly."},
	{"BoostRechargeDelayMinSeconds",C.BOOST,0.40,"Raises the shortest delay before boost starts recharging."},
	{"BoostRechargeDelayMaxSeconds",C.BOOST,1.0,"Raises the longest delay before boost starts recharging."},
	{"BoostEfficiencyTimingExponent",C.BOOST,0.15,"Makes BoostEfficiency influence boost duration and recharge more strongly."},

	{"BaseBrakeDeceleration",C.BRAKING,30,"Makes braking stronger for every vehicle."},
	{"BrakingForceReference",C.BRAKING,60,"Requires more BrakingForce stat to reach neutral braking performance."},
	{"BrakingForceExponent",C.BRAKING,0.7,"Widens braking differences between low- and high-stat vehicles."},
	{"BrakeWeightExponent",C.BRAKING,0.2,"Makes vehicle weight influence braking more strongly."},
	{"CoastBaseDeceleration",C.BRAKING,3.2,"Makes an unpowered vehicle slow down more quickly at all speeds."},
	{"CoastSpeedCoefficient",C.BRAKING,0.03,"Adds more coasting slowdown as speed increases."},
	{"ThrottleDeadzone",C.BRAKING,0.05,"Requires more input before acceleration or braking registers."},
	{"StopThresholdMph",C.BRAKING,1.5,"Allows stopped/brake-to-reverse logic to engage at a higher speed."},
	{"AutoHoldMph",C.BRAKING,1.25,"Engages the stationary parking hold at a higher speed."},
	{"ReverseEngageDelaySeconds",C.BRAKING,1.0,"Makes the brake-to-reverse pause longer."},
	{"ReverseAcceleration",C.BRAKING,12,"Makes reverse acceleration stronger."},
	{"ReverseCurveExponent",C.BRAKING,0.8,"Makes reverse acceleration fade more sharply near reverse top speed."},

	{"BaseNormalLateralGrip",C.GRIP,6.6,"Adds more normal cornering grip to every vehicle."},
	{"LateralGripReference",C.GRIP,50,"Requires more LateralGrip stat to reach neutral cornering grip."},
	{"LateralGripExponent",C.GRIP,0.40,"Widens cornering-grip differences between vehicle stats."},
	{"LateralGripMinMultiplier",C.GRIP,0.82,"Improves the minimum grip available to low-stat vehicles."},
	{"LateralGripMaxMultiplier",C.GRIP,1.22,"Raises maximum grip for high-stat vehicles."},
	{"DownforceReference",C.GRIP,50,"Requires more Downforce stat to reach neutral high-speed grip."},
	{"DownforceGripInfluence",C.GRIP,0.22,"Makes Downforce add more grip as speed rises."},
	{"HighSpeedGripMph",C.GRIP,140,"Delays the point where the full downforce grip contribution is reached."},
	{"HoverStabilityReference",C.GRIP,50,"Requires more HoverStability stat to reach neutral alignment response."},
	{"HoverStabilityExponent",C.GRIP,0.25,"Widens hover-alignment differences between stability stats."},
	{"BaseAlignResponsiveness",C.GRIP,22,"Makes hover orientation align more quickly for every vehicle."},
}

local definitionNames = {}
for _, definition in ipairs(definitions) do definitionNames[definition[1]] = true end

-- Discover custom numeric values from every supported prior layout.
local discoveredUnknown = {}
local function rememberUnknown(name, categoryName, value)
	if typeof(value) == "number" and not definitionNames[name] and not discoveredUnknown[name] then
		discoveredUnknown[name] = {name, categoryName or C.ADVANCED, value,
			"Raises this advanced numeric value; inspect its name and driving documentation before changing it."}
	end
end
for name, value in pairs(config:GetAttributes()) do
	rememberUnknown(name, C.ADVANCED, value)
end
for _, category in ipairs(config:GetChildren()) do
	if category:IsA("Folder") then
		for name, value in pairs(category:GetAttributes()) do
			if not string.find(name, "_RaisingThisDoes", 1, true) then rememberUnknown(name, category.Name, value) end
		end
		for _, setting in ipairs(category:GetChildren()) do
			if setting:IsA("Folder") then
				local oldValue = setting:FindFirstChild("01_Value")
				if oldValue and oldValue:IsA("NumberValue") then rememberUnknown(setting.Name, category.Name, oldValue.Value) end
			end
		end
	end
end
for name, definition in pairs(discoveredUnknown) do table.insert(definitions, definition); definitionNames[name] = true end

local function nestedValue(name)
	for _, category in ipairs(config:GetChildren()) do
		if category:IsA("Folder") then
			local setting = category:FindFirstChild(name)
			local valueObject = setting and setting:IsA("Folder") and setting:FindFirstChild("01_Value")
			if valueObject and valueObject:IsA("NumberValue") then return valueObject.Value end
		end
	end
	return nil
end

local migratedValues, createdAttributes = {}, 0
for _, definition in ipairs(definitions) do
	local name, categoryName, fallback, raiseEffect = definition[1], definition[2], definition[3], definition[4]
	local category = ensureFolder(config, categoryName)
	local value = category:GetAttribute(name)
	if typeof(value) ~= "number" then value = nestedValue(name) end
	if typeof(value) ~= "number" then value = config:GetAttribute(name) end
	if typeof(value) ~= "number" then value = fallback end
	if typeof(category:GetAttribute(name)) ~= "number" then createdAttributes += 1 end
	category:SetAttribute(name, value)
	category:SetAttribute(name .. "_RaisingThisDoes", raiseEffect)
	migratedValues[name] = {Category = category, Value = value}
end

-- Verify every paired category Attribute before changing source or removing old layouts.
for name, migrated in pairs(migratedValues) do
	assert(migrated.Category:GetAttribute(name) == migrated.Value, "Categorised value verification failed for " .. name)
	assert(typeof(migrated.Category:GetAttribute(name .. "_RaisingThisDoes")) == "string", "Description verification failed for " .. name)
end
info("PASS - Preserved and flattened " .. tostring(#definitions) .. " numeric settings (" .. tostring(createdAttributes) .. " category attributes newly created).")

if not controllerHasFlat then
	local controllerAnchor = controllerHasNested and controllerNested or controllerOld
	local moduleAnchor = moduleHasNested and moduleNested or moduleOld
	local patchedController = replacePlainOnce(driving.Source, controllerAnchor, controllerFlat, "controller flat-category config reader")
	local patchedDynamics = replacePlainOnce(dynamics.Source, moduleAnchor, moduleFlat, "dynamics flat-category config reader")
	driving.Source = patchedController
	dynamics.Source = patchedDynamics
end

assert(string.find(driving.Source, "NTR_DRIVING_FEEL_FLAT_CATEGORY_CONFIG_READER", 1, true), "Controller flat-category reader marker missing")
assert(string.find(dynamics.Source, "NTR_DRIVING_FEEL_FLAT_CATEGORY_CONFIG_READER", 1, true), "Dynamics flat-category reader marker missing")

-- Category Attributes are now authoritative. Clear migrated flat numbers and remove
-- only the obsolete per-setting folders created by the V1 organiser.
for name in pairs(migratedValues) do
	if typeof(config:GetAttribute(name)) == "number" then config:SetAttribute(name, nil) end
end
local removedSettingFolders = 0
for _, category in ipairs(config:GetChildren()) do
	if category:IsA("Folder") then
		for _, setting in ipairs(category:GetChildren()) do
			if setting:IsA("Folder") then
				local valueObject = setting:FindFirstChild("01_Value")
				local noteObject = setting:FindFirstChild("02_RaisingThisDoes")
				if valueObject and valueObject:IsA("NumberValue") and noteObject and noteObject:IsA("StringValue") then
					setting:Destroy()
					removedSettingFolders += 1
				end
			end
		end
	end
end
config:SetAttribute("OrganisedTuningVersion", "PHASE3_FLAT_CATEGORY_ATTRIBUTES_V2")
config:SetAttribute("OrganisedTuningNote", "Select one category Folder and edit its numeric Attributes. Each matching _RaisingThisDoes string explains the higher-value effect.")

info("PASS - Flat category Attributes are now the numeric source of truth; removed " .. tostring(removedSettingFolders) .. " obsolete setting folders.")
info("PASS - Existing edited numbers were preserved exactly and no driving formula was changed.")
info("Restart Play and verify acceleration, handling, drifting, boost, braking, reverse, grip, and hover behavior.")
