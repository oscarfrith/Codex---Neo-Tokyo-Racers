-- Neo Tokyo Racers - configurable stat-scaled post-drift mini boost
-- Run once in Roblox Studio Command Bar in Edit mode.
--
-- Adds only previously missing Attributes to the existing 03_Drifting folder.
-- Every pre-existing config Attribute is snapshotted and verified unchanged.
-- The two related exact source anchors are preflighted together before mutation.
-- No backups are created.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before installing drift mini-boost scaling")

local PREFIX = "[NTR Drift Mini Boost]"
local MARKER = "NTR_DRIFT_MINI_BOOST_STAT_SCALING_V1"
local function info(message) print(PREFIX .. " " .. message) end
local function countPlain(source, needle)
	local count, position = 0, 1
	while true do
		local found = string.find(source, needle, position, true)
		if not found then return count end
		count += 1; position = found + #needle
	end
end
local function replacePlainOnce(source, oldText, newText, label)
	local count = countPlain(source, oldText)
	assert(count == 1, label .. " expected exactly one live source match, found " .. tostring(count))
	local first, last = string.find(source, oldText, 1, true)
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local runtime = kit:WaitForChild("Config"):WaitForChild("Runtime")
local vehicleConfig = runtime:WaitForChild("VehicleDynamics_EditAttributes")
local driftingConfig = vehicleConfig:WaitForChild("03_Drifting")
local controllers = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers")
local driving = controllers:WaitForChild("DrivingControllerV47")
assert(vehicleConfig:IsA("Folder") and driftingConfig:IsA("Folder"), "Phase 3 flat driving config is required")
assert(driving:IsA("ModuleScript"), "DrivingControllerV47 must be a ModuleScript")
assert(string.find(driving.Source, "NTR_DRIVING_FEEL_PHASE3_DRIFT_DRIVE", 1, true), "Confirmed Driving Feel Phase 3 marker is missing")

local rewardOld = [==[if state.DriftCharge > 0.72 and (not requiresAcceleration or acceleratingOnDriftExit) then
				local charge = state.DriftCharge
				state.MiniBoostTimer = math.clamp(0.22 + charge * 0.48, 0.35, 1.85)
				state.MiniBoostPower = math.clamp(48 + charge * 27, 58, 136)
			end]==]

local rewardNew = [==[-- NTR_DRIFT_MINI_BOOST_STAT_SCALING_V1
			local statScalingEnabled = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostStatScalingEnabled", 1, 0, 1) >= 0.5
			local minimumCharge = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostMinimumCharge", 0.72, 0, 10)
			if state.DriftCharge > minimumCharge and (not requiresAcceleration or acceleratingOnDriftExit) then
				local charge = state.DriftCharge
				if statScalingEnabled then
					local fullRewardCharge = math.max(configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostChargeForFullReward", 3.25, 0.01, 10), minimumCharge + 0.01)
					local rewardExponent = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostRewardExponent", 0.85, 0.05, 4)
					local chargeQuality = math.clamp((charge - minimumCharge) / (fullRewardCharge - minimumCharge), 0, 1) ^ rewardExponent

					local baseMinDuration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBaseMinDurationSeconds", 0.18, 0.01, 3)
					local baseMaxDuration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBaseMaxDurationSeconds", 0.70, 0.01, 3)
					if baseMaxDuration < baseMinDuration then baseMinDuration, baseMaxDuration = baseMaxDuration, baseMinDuration end
					local durationReference = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostDurationReferenceSeconds", 3.0, 0.1, 12)
					local durationExponent = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostDurationExponent", 0.50, 0.05, 2)
					local durationMinMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostDurationMinMultiplier", 0.80, 0.05, 3)
					local durationMaxMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostDurationMaxMultiplier", 1.20, 0.05, 3)
					if durationMaxMultiplier < durationMinMultiplier then durationMinMultiplier, durationMaxMultiplier = durationMaxMultiplier, durationMinMultiplier end
					local durationMultiplier = math.clamp((math.max(dynamicsStats.BoostDuration or durationReference, 0.01) / durationReference) ^ durationExponent, durationMinMultiplier, durationMaxMultiplier)
					local absoluteMinDuration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostAbsoluteMinDurationSeconds", 0.12, 0.01, 3)
					local absoluteMaxDuration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostAbsoluteMaxDurationSeconds", 0.90, 0.01, 3)
					if absoluteMaxDuration < absoluteMinDuration then absoluteMinDuration, absoluteMaxDuration = absoluteMaxDuration, absoluteMinDuration end
					local baseDuration = baseMinDuration + (baseMaxDuration - baseMinDuration) * chargeQuality
					state.MiniBoostTimer = math.clamp(baseDuration * durationMultiplier, absoluteMinDuration, absoluteMaxDuration)

					local minAcceleration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostMinAcceleration", 32, 0, 300)
					local maxAcceleration = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostMaxAcceleration", 72, 0, 300)
					if maxAcceleration < minAcceleration then minAcceleration, maxAcceleration = maxAcceleration, minAcceleration end
					local boostForceReference = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostForceReference", 30, 0.1, 300)
					local boostForceExponent = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostForceExponent", 0.55, 0.05, 2)
					local boostForceMinMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostForceMinMultiplier", 0.65, 0.05, 3)
					local boostForceMaxMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostBoostForceMaxMultiplier", 1.25, 0.05, 3)
					if boostForceMaxMultiplier < boostForceMinMultiplier then boostForceMinMultiplier, boostForceMaxMultiplier = boostForceMaxMultiplier, boostForceMinMultiplier end
					local boostForceMultiplier = math.clamp((math.max(dynamicsStats.BoostForce or 0, 0.01) / boostForceReference) ^ boostForceExponent, boostForceMinMultiplier, boostForceMaxMultiplier)
					state.MiniBoostPower = (minAcceleration + (maxAcceleration - minAcceleration) * chargeQuality) * boostForceMultiplier

					if configBool("DRIVING_MECHANICS_EditAttributes", "DriftMiniBoostDebugAttributes", true) then
						state.Vehicle:SetAttribute("DriftMiniBoostChargeQuality", chargeQuality)
						state.Vehicle:SetAttribute("DriftMiniBoostDurationMultiplier", durationMultiplier)
						state.Vehicle:SetAttribute("DriftMiniBoostForceMultiplier", boostForceMultiplier)
						state.Vehicle:SetAttribute("DriftMiniBoostDurationSeconds", state.MiniBoostTimer)
						state.Vehicle:SetAttribute("DriftMiniBoostAcceleration", state.MiniBoostPower)
					end
				else
					state.MiniBoostTimer = math.clamp(0.22 + charge * 0.48, 0.35, 1.85)
					state.MiniBoostPower = math.clamp(48 + charge * 27, 58, 136)
				end
			end]==]

local boostOld = [==[local boostHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space) or state.GamepadBoostHeld
		if boostHeld and state.Boost > 1 and forwardSpeed > -4 and boostPower > 0 then
			state.Boost = math.max(0, state.Boost - (100 / boostDuration) * dt)
			state.BoostRechargeDelayTimer = state.BoostRechargeDelaySeconds
			driveForce += forward * mass * (boostPower + 32) * 0.75
			state.Vehicle:SetAttribute("Boosting", true)
			state.BoostCameraActive = true
		elseif state.MiniBoostTimer > 0 then
			state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt)
			driveForce += forward * mass * state.MiniBoostPower * 0.92
			state.Vehicle:SetAttribute("Boosting", true)
			state.BoostCameraActive = true
		else
			if boostHeld and boostPower > 0 then
				state.BoostRechargeDelayTimer = state.BoostRechargeDelaySeconds
			elseif state.BoostRechargeDelayTimer > 0 then
				state.BoostRechargeDelayTimer = math.max(0, state.BoostRechargeDelayTimer - dt)
			else
				state.Boost = math.min(100, state.Boost + (100 / boostRecharge) * dt)
			end
			state.MiniBoostPower = 0
			state.Vehicle:SetAttribute("Boosting", false)
			state.BoostCameraActive = false
		end]==]

local boostNew = [==[local boostHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space) or state.GamepadBoostHeld
		local miniBoostActive = state.MiniBoostTimer > 0
		local expiresDuringNormalBoost = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostExpiresDuringNormalBoost", 1, 0, 1) >= 0.5
		if miniBoostActive and expiresDuringNormalBoost then
			state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt)
		end
		if boostHeld and state.Boost > 1 and forwardSpeed > -4 and boostPower > 0 then
			state.Boost = math.max(0, state.Boost - (100 / boostDuration) * dt)
			state.BoostRechargeDelayTimer = state.BoostRechargeDelaySeconds
			driveForce += forward * mass * (boostPower + 32) * 0.75
			state.Vehicle:SetAttribute("Boosting", true)
			state.BoostCameraActive = true
		elseif miniBoostActive then
			if not expiresDuringNormalBoost then state.MiniBoostTimer = math.max(0, state.MiniBoostTimer - dt) end
			local forceMultiplier = configNumber("VehicleDynamics_EditAttributes", "DriftMiniBoostForceApplicationMultiplier", 0.85, 0, 3)
			driveForce += forward * mass * state.MiniBoostPower * forceMultiplier
			state.Vehicle:SetAttribute("Boosting", true)
			state.BoostCameraActive = true
		else
			if boostHeld and boostPower > 0 then
				state.BoostRechargeDelayTimer = state.BoostRechargeDelaySeconds
			elseif state.BoostRechargeDelayTimer > 0 then
				state.BoostRechargeDelayTimer = math.max(0, state.BoostRechargeDelayTimer - dt)
			else
				state.Boost = math.min(100, state.Boost + (100 / boostRecharge) * dt)
			end
			state.MiniBoostPower = 0
			state.Vehicle:SetAttribute("Boosting", false)
			state.BoostCameraActive = false
		end]==]

local alreadyInstalled = string.find(driving.Source, MARKER, 1, true) ~= nil
local patchedSource = driving.Source
if alreadyInstalled then
	assert(countPlain(driving.Source, rewardOld) == 0 and countPlain(driving.Source, boostOld) == 0, "Both legacy and V1 drift mini-boost blocks are present")
	info("PASS - Drift mini-boost stat scaling source is already installed; preserving live source.")
else
	assert(countPlain(driving.Source, rewardOld) == 1, "Drift reward anchor differs from the refreshed 11:55:47 mirror")
	assert(countPlain(driving.Source, boostOld) == 1, "Boost priority/timer anchor differs from the refreshed 11:55:47 mirror")
	patchedSource = replacePlainOnce(patchedSource, rewardOld, rewardNew, "stat-scaled drift reward")
	patchedSource = replacePlainOnce(patchedSource, boostOld, boostNew, "non-queued drift boost timer")
	assert(string.find(patchedSource, MARKER, 1, true), "Generated drift mini-boost marker missing")
	info("PASS - Both related live source anchors preflighted and generated together.")

	local testModule = Instance.new("ModuleScript")
	testModule.Name = "__NTR_DriftMiniBoostCompileCheck"
	testModule.Source = patchedSource
	testModule.Parent = controllers
	local ok, result = pcall(require, testModule)
	testModule:Destroy()
	assert(ok and typeof(result) == "table", "Generated DrivingController compile check failed: " .. tostring(result))
	info("PASS - Generated controller source compiled successfully.")
end

-- Snapshot every existing Attribute in the full dynamics config before adding anything.
local existingAttributes = {}
local function snapshot(instance)
	for name, value in pairs(instance:GetAttributes()) do
		table.insert(existingAttributes, {Instance = instance, Name = name, Value = value})
	end
	for _, child in ipairs(instance:GetChildren()) do snapshot(child) end
end
snapshot(vehicleConfig)

local definitions = {
	{"DriftMiniBoostStatScalingEnabled",1,"Enables the new charge, BoostForce, and BoostDuration scaling when raised to 1; set 0 for the legacy reward formula."},
	{"DriftMiniBoostExpiresDuringNormalBoost",1,"Makes the post-drift reward expire instead of queueing behind normal boost when raised to 1."},
	{"DriftMiniBoostMinimumCharge",0.72,"Requires more earned drift charge before any post-drift reward is granted."},
	{"DriftMiniBoostChargeForFullReward",3.25,"Requires a longer or faster-charging drift to reach the full reward."},
	{"DriftMiniBoostRewardExponent",0.85,"Makes partially charged drifts produce less duration and force."},
	{"DriftMiniBoostBaseMinDurationSeconds",0.18,"Makes the shortest charge-based post-drift boost last longer."},
	{"DriftMiniBoostBaseMaxDurationSeconds",0.70,"Makes a fully charged reference post-drift boost last longer before stat scaling."},
	{"DriftMiniBoostBoostDurationReferenceSeconds",3.0,"Requires a higher mapped BoostDuration to reach the neutral duration multiplier."},
	{"DriftMiniBoostBoostDurationExponent",0.50,"Widens post-drift duration differences between low- and high-duration boost modules."},
	{"DriftMiniBoostBoostDurationMinMultiplier",0.80,"Raises the duration floor for low-duration boost modules."},
	{"DriftMiniBoostBoostDurationMaxMultiplier",1.20,"Raises the duration multiplier ceiling for high-duration boost modules."},
	{"DriftMiniBoostAbsoluteMinDurationSeconds",0.12,"Raises the absolute shortest post-drift boost duration."},
	{"DriftMiniBoostAbsoluteMaxDurationSeconds",0.90,"Raises the final safety cap for post-drift boost duration."},
	{"DriftMiniBoostMinAcceleration",32,"Makes the weakest qualifying post-drift boost accelerate harder."},
	{"DriftMiniBoostMaxAcceleration",72,"Makes a fully charged reference post-drift boost accelerate harder."},
	{"DriftMiniBoostBoostForceReference",30,"Requires a higher BoostForce stat to reach the neutral post-drift force multiplier."},
	{"DriftMiniBoostBoostForceExponent",0.55,"Widens post-drift power differences between low- and high-force boost modules."},
	{"DriftMiniBoostBoostForceMinMultiplier",0.65,"Raises the post-drift power floor for low-force boost modules."},
	{"DriftMiniBoostBoostForceMaxMultiplier",1.25,"Raises the post-drift power multiplier ceiling for high-force boost modules."},
	{"DriftMiniBoostForceApplicationMultiplier",0.85,"Raises the final physical force applied by every post-drift boost."},
}

local added = 0
for _, definition in ipairs(definitions) do
	local name, fallback, description = definition[1], definition[2], definition[3]
	local existing = driftingConfig:GetAttribute(name)
	if existing == nil then driftingConfig:SetAttribute(name, fallback); added += 1
	else assert(typeof(existing) == "number", driftingConfig:GetFullName() .. "." .. name .. " must be numeric") end
	local descriptionName = name .. "_RaisingThisDoes"
	if driftingConfig:GetAttribute(descriptionName) == nil then driftingConfig:SetAttribute(descriptionName, description) end
end

for _, saved in ipairs(existingAttributes) do
	assert(saved.Instance:GetAttribute(saved.Name) == saved.Value,
		"Existing config value changed unexpectedly: " .. saved.Instance:GetFullName() .. "." .. saved.Name)
end
info("PASS - Verified all " .. tostring(#existingAttributes) .. " pre-existing config Attributes are unchanged; added " .. tostring(added) .. " new values.")

if not alreadyInstalled then driving.Source = patchedSource end
assert(string.find(driving.Source, MARKER, 1, true), "Installed drift mini-boost marker missing")
for _, saved in ipairs(existingAttributes) do
	assert(saved.Instance:GetAttribute(saved.Name) == saved.Value,
		"Existing config value changed after source install: " .. saved.Instance:GetFullName() .. "." .. saved.Name)
end

info("PASS - BoostForce now scales post-drift power; mapped BoostDuration scales its bounded duration.")
info("PASS - Normal boost no longer pauses and queues the post-drift reward timer.")
info("Restart Play and compare low-, middle-, and high-tier boost modules after equal-charge drifts.")
