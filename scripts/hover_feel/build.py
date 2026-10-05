"""Hover feel delivery: builds the after-sources and the guarded installer (contract: CONTRACT.md).

    py -3 scripts/hover_feel/serve.py        (leave running; the installer reads sources from it)
    py -3 scripts/hover_feel/build.py        (writes after/DrivingClient.lua and out_audit/apply/rollback.lua)
    py -3 scripts/hover_feel/build.py DrivingClient DrivingCameraClient    (only the named scripts; audio and vfx
                                                                            config is included with their scripts)

Scripts:
  DrivingClient          anchored insertions that publish the Feel state; no force, input or equation changes.
  DrivingCameraClient    whole file, written by hand in after/.
  VehicleAudioClient...  whole files from audio/after/ and vfx/after/ when present.
Config: attributes and new instances from CONFIG below plus audio/config_spec.json and vfx/config_spec.json.

before/ holds the exact live sources captured from Space Racers v3 on 2026-10-04 (serve.py POST route).
Each build appends the after-hashes to applied_hashes.json so a later build can be applied over an earlier one.
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "scripts/hover_feel/"
PLACE_ID = 93959280828322
VEHICLES = ["ReplicatedStorage", "Modules", "Game", "Vehicles"]
AUDIO = ["ReplicatedStorage", "Modules", "Game", "Audio"]
CAMERA_CONFIG = ["ReplicatedStorage", "Config", "Vehicles", "Camera"]
DRIVING_CONFIG = ["ReplicatedStorage", "Config", "Vehicles", "Driving"]

FEEL_HELPERS = '''local FEEL_ATTRIBUTES = {"FeelThrottle", "FeelSpeedMph", "FeelSlip", "FeelBoostCharge", "FeelBoostKind", "FeelDriftCharge", "FeelGrounded", "FeelHover", "FeelImpactRevision", "FeelImpactStrength", "FeelLandRevision", "FeelLandStrength", "FeelPopRevision", "FeelPopStrength", "FeelImpactX", "FeelImpactZ", "FeelScrape"}
-- Car-local directions probed for a wall: left, right, ahead (-Z is forward).
local FEEL_WALL_PROBES = { { -1, 0 }, { 1, 0 }, { 0, -1 } }
local function clearFeelState(vehicle)
	if not vehicle then return end
	for _, name in ipairs(FEEL_ATTRIBUTES) do vehicle:SetAttribute(name, nil) end
end
local function quantise(value, step)
	return math.floor(value / step + 0.5) * step
end
-- Publishes the continuous Feel state read by the camera, audio and VFX owners (scripts/hover_feel/CONTRACT.md).
-- Client-local attributes. It observes the frame only: no force, input or equation depends on it.
local function publishFeelState(dt, vehicle, throttle, velocity, speedMph, sideSpeed, grounded, hits, driveForce, mass)
	local feel = state.Feel
	if not feel then return end
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	-- Impact: horizontal speed change that last frame's drive force does not explain.
	local root = vehicle.PrimaryPart
	local unexplained = Vector3.zero
	if feel.PreviousVelocity and not feel.Skip and dt <= 0.05 then
		unexplained = horizontal - feel.PreviousVelocity - feel.PreviousAcceleration * dt
		local strength = unexplained.Magnitude
		if strength >= configNumber("Driving", "FeelImpactMinStuds", 9, 1, 200) and os.clock() - feel.LastImpact > 0.12 then
			feel.ImpactRevision += 1
			feel.LastImpact = os.clock()
			if root then
				-- The car was pushed along the unexplained change, so the thing it hit lies the other way.
				local toward = root.CFrame:VectorToObjectSpace(-unexplained.Unit)
				vehicle:SetAttribute("FeelImpactX", quantise(toward.X, 0.05))
				vehicle:SetAttribute("FeelImpactZ", quantise(toward.Z, 0.05))
			end
			vehicle:SetAttribute("FeelImpactStrength", strength)
			vehicle:SetAttribute("FeelImpactRevision", feel.ImpactRevision)
		end
	end
	-- Scrape: something solid beside or ahead of the car while an unexplained force keeps acting on it.
	feel.ScrapeTimer += dt
	if root and feel.ScrapeTimer >= 0.1 then
		feel.ScrapeTimer = 0
		feel.WallX, feel.WallZ = nil, nil
		if speedMph > 15 and state.RayParams then
			local frame = root.CFrame
			local half = root.Size * 0.5
			for _, probe in ipairs(FEEL_WALL_PROBES) do
				local reach = frame:VectorToWorldSpace(Vector3.new(probe[1] * (half.X + 2), 0, probe[2] * (half.Z + 2)))
				if Workspace:Raycast(frame.Position, reach, state.RayParams) then
					feel.WallX, feel.WallZ = probe[1], probe[2]
					break
				end
			end
		end
	end
	local rubbing = feel.WallX ~= nil and math.clamp((unexplained.Magnitude / math.max(dt, 1 / 240) - 12) / 60, 0, 1) or 0
	feel.Scrape += (rubbing - feel.Scrape) * math.clamp(dt * 10, 0, 1)
	if feel.Scrape > 0.1 and feel.WallX then
		vehicle:SetAttribute("FeelImpactX", feel.WallX)
		vehicle:SetAttribute("FeelImpactZ", feel.WallZ)
	end
	vehicle:SetAttribute("FeelScrape", quantise(feel.Scrape, 0.05))
	feel.PreviousVelocity = horizontal
	feel.PreviousAcceleration = Vector3.new(driveForce.X, 0, driveForce.Z) / mass
	feel.Skip = feel.SkipNext
	-- Landing: airborne for a moment, then grounded again.
	if grounded then
		if feel.AirTime >= 0.15 then
			feel.LandRevision += 1
			vehicle:SetAttribute("FeelLandStrength", feel.FallSpeed)
			vehicle:SetAttribute("FeelLandRevision", feel.LandRevision)
		end
		feel.AirTime = 0
	else
		feel.AirTime += dt
		feel.FallSpeed = math.max(0, -velocity.Y)
	end
	local speedStuds = velocity.Magnitude
	vehicle:SetAttribute("FeelThrottle", quantise(math.clamp(throttle, -1, 1), 0.02))
	vehicle:SetAttribute("FeelSpeedMph", quantise(speedMph, 0.5))
	vehicle:SetAttribute("FeelSlip", speedMph >= 8 and quantise(math.clamp(sideSpeed / speedStuds, -1, 1), 0.02) or 0)
	vehicle:SetAttribute("FeelBoostCharge", math.floor(state.Boost + 0.5))
	vehicle:SetAttribute("FeelBoostKind", feel.BoostKind)
	vehicle:SetAttribute("FeelDriftCharge", quantise(math.clamp(state.DriftCharge / 3.25, 0, 1), 0.02))
	vehicle:SetAttribute("FeelGrounded", grounded)
	vehicle:SetAttribute("FeelHover", hits > 0 and quantise(math.clamp(feel.HoverSum / hits / HOVER_HEIGHT, -1, 1), 0.02) or 0)
	-- Pops: a bang and a hard run after lifting off sustained thrust. A boost that ends fires nothing.
	if configBool("Driving", "FeelPopsEnabled", true) then
		local now = os.clock()
		local pop = nil
		if throttle > 0.6 and speedMph > 40 then
			feel.LoadTime = math.min(feel.LoadTime + dt, 3)
		elseif throttle <= 0.1 then
			if feel.LoadTime >= 0.8 and feel.BoostKind == "" then
				-- Lift-off: one bang straight away, then a fast, hard run.
				pop = 0.9 + math.random() * 0.1
				feel.PopsLeft = math.random(3, 6)
				feel.NextPop = now + 0.07
			end
			feel.LoadTime = 0
		end
		if not pop and feel.PopsLeft > 0 and now >= feel.NextPop then
			feel.PopsLeft -= 1
			feel.NextPop = now + 0.05 + math.random() * 0.12
			pop = 0.5 + math.random() * 0.29
		end
		if pop then
			feel.PopRevision += 1
			vehicle:SetAttribute("FeelPopStrength", quantise(pop, 0.01))
			vehicle:SetAttribute("FeelPopRevision", feel.PopRevision)
		end
	end
	feel.PreviousBoostKind = feel.BoostKind
end

'''

# (old, new, expected count). Every insertion keeps the original text and adds to it.
DRIVING_EDITS = [
    ("local handleResetAction\n", FEEL_HELPERS + "local handleResetAction\n", 1),
    ('\t\tstate.Vehicle:SetAttribute("DriveReady", false)\n',
     '\t\tstate.Vehicle:SetAttribute("DriveReady", false)\n\t\tclearFeelState(state.Vehicle)\n', 1),
    ("\tstate.AccelCameraActive = false\n\tstate.BoostCameraActive = false\n\n\tlocal root = state.Vehicle.PrimaryPart\n",
     "\tstate.AccelCameraActive = false\n\tstate.BoostCameraActive = false\n"
     "\tstate.Feel = { ImpactRevision = 0, LandRevision = 0, LastImpact = 0, AirTime = 0, FallSpeed = 0, HoverSum = 0, BoostKind = \"\", Skip = true, SkipNext = false, PopRevision = 0, PopsLeft = 0, NextPop = 0, LoadTime = 0, PreviousBoostKind = \"\", ScrapeTimer = 0, Scrape = 0 }\n"
     "\n\tlocal root = state.Vehicle.PrimaryPart\n", 1),
    ("\t\tlocal lastRelativeYVelocity = 0\n",
     "\t\tlocal lastRelativeYVelocity = 0\n\t\tstate.Feel.HoverSum = 0\n\t\tstate.Feel.SkipNext = false\n\t\tstate.Feel.BoostKind = \"\"\n", 1),
    ("\t\t\t\tlocal heightError = targetDistance - result.Distance\n",
     "\t\t\t\tlocal heightError = targetDistance - result.Distance\n\t\t\t\tstate.Feel.HoverSum += heightError\n", 1),
    ("\t\t\t\troot.AssemblyLinearVelocity = velocity - forward * forwardSpeed\n",
     "\t\t\t\troot.AssemblyLinearVelocity = velocity - forward * forwardSpeed\n\t\t\t\tstate.Feel.SkipNext = true\n", 1),
    ("\t\t\t\troot.AssemblyLinearVelocity = lateralVelocity - forward * maxReverseStuds\n",
     "\t\t\t\troot.AssemblyLinearVelocity = lateralVelocity - forward * maxReverseStuds\n\t\t\t\tstate.Feel.SkipNext = true\n", 1),
    ('\t\t\tdriveForce += forward * mass * (boostPower + 32) * 0.75\n\t\t\tstate.Vehicle:SetAttribute("Boosting", true)\n',
     '\t\t\tdriveForce += forward * mass * (boostPower + 32) * 0.75\n\t\t\tstate.Vehicle:SetAttribute("Boosting", true)\n\t\t\tstate.Feel.BoostKind = "Boost"\n', 1),
    ('\t\t\tdriveForce += forward * mass * state.MiniBoostPower * forceMultiplier\n\t\t\tstate.Vehicle:SetAttribute("Boosting", true)\n',
     '\t\t\tdriveForce += forward * mass * state.MiniBoostPower * forceMultiplier\n\t\t\tstate.Vehicle:SetAttribute("Boosting", true)\n\t\t\tstate.Feel.BoostKind = "Mini"\n', 1),
    ("\t\t\troot.CFrame = CFrame.new(860, 106, -1713)\n",
     "\t\t\troot.CFrame = CFrame.new(860, 106, -1713)\n\t\t\tstate.Feel.SkipNext = true\n", 1),
    # Parked (anchored): nothing is simulated, so publish rest values and make the first frame after release
    # skip impact detection instead of comparing against the velocity from before the car was parked.
    ("\t\t\tupdateExistingDriveUi(0)\n\t\t\treturn\n",
     "\t\t\tstate.Feel.Skip = true\n\t\t\tstate.Feel.PreviousVelocity = nil\n"
     "\t\t\tif state.Vehicle:GetAttribute(\"FeelSpeedMph\") ~= nil then\n"
     "\t\t\t\tstate.Vehicle:SetAttribute(\"FeelSpeedMph\", 0)\n\t\t\t\tstate.Vehicle:SetAttribute(\"FeelThrottle\", 0)\n"
     "\t\t\t\tstate.Vehicle:SetAttribute(\"FeelBoostKind\", \"\")\n\t\t\tend\n"
     "\t\t\tupdateExistingDriveUi(0)\n\t\t\treturn\n", 1),
    ("\t\tupdateExistingDriveUi(speedMph)\n\tend)\n",
     "\t\tif configBool(\"Driving\", \"FeelStateEnabled\", true) then\n"
     "\t\t\tpublishFeelState(dt, state.Vehicle, throttle, velocity, speedMph, sideSpeed, grounded, hits, driveForce, mass)\n"
     "\t\telse\n\t\t\tstate.Feel.Skip = true\n\t\t\tstate.Feel.PreviousVelocity = nil\n"
     "\t\tend\n"
     "\t\tupdateExistingDriveUi(speedMph)\n\tend)\n", 1),
    ("\t\tstate.CurrentBank = 0\n\t\troot.CFrame = CFrame.lookAt(",
     "\t\tstate.CurrentBank = 0\n\t\tif state.Feel then state.Feel.Skip = true end\n\t\troot.CFrame = CFrame.lookAt(", 1),
]

# Config attributes written on existing folders: (path, key, value).
CONFIG = [
    (DRIVING_CONFIG, "FeelStateEnabled", True),
    (DRIVING_CONFIG, "FeelImpactMinStuds", 9),
    (DRIVING_CONFIG, "FeelPopsEnabled", True),
    (["ReplicatedStorage", "Config", "Audio", "Global"], "BoostLoopFadeOutSeconds", 2.2, [0.9]),
    (["ReplicatedStorage", "Config", "Audio", "Global"], "BoostEndVent", 0),
    (CAMERA_CONFIG, "ScriptedChaseEnabled", True),
    (CAMERA_CONFIG, "ScriptedChaseEnabled_Description", "True: scripted chase camera (lens locked to the car, springs for every relative motion). False: the V6.1 camera where Roblox owns motion, collision and orbit."),
    (CAMERA_CONFIG, "ChaseHeightStuds", 9, [6.5, 8]),
    (CAMERA_CONFIG, "ChaseHeightStuds_RaisingThisDoes", "Raises the chase camera above the vehicle."),
    (CAMERA_CONFIG, "ChasePivotHeightStuds", 2.5),
    (CAMERA_CONFIG, "ChasePivotHeightStuds_RaisingThisDoes", "Raises the point the chase camera orbits around."),
    (CAMERA_CONFIG, "ChaseAimAheadStuds", 15, [12]),
    (CAMERA_CONFIG, "ChaseAimAheadStuds_RaisingThisDoes", "Aims the chase camera farther ahead of the vehicle, which moves the vehicle lower in frame."),
    (CAMERA_CONFIG, "ChaseAimHeightStuds", 2.2, [3.2, 2.4]),
    (CAMERA_CONFIG, "ChaseAimHeightStuds_RaisingThisDoes", "Raises the point the chase camera looks at."),
    (CAMERA_CONFIG, "ChaseYawResponse", 7.5),
    (CAMERA_CONFIG, "ChaseYawResponse_RaisingThisDoes", "Makes the chase camera swing behind the vehicle faster when it turns."),
    (CAMERA_CONFIG, "ChaseSlipFollow", 0.5, [0.35]),
    (CAMERA_CONFIG, "ChaseSlipFollow_RaisingThisDoes", "Moves the chase camera farther toward the direction of travel while the vehicle slides, showing more of its side."),
    (CAMERA_CONFIG, "ChaseLookAheadSeconds", 0.3, [0.22]),
    (CAMERA_CONFIG, "ChaseLookAheadSeconds_RaisingThisDoes", "Turns the view farther into a corner."),
    (CAMERA_CONFIG, "ChaseLookAheadMaxDegrees", 13, [9]),
    (CAMERA_CONFIG, "ChaseLookAheadMaxDegrees_RaisingThisDoes", "Allows the view to turn farther into a corner."),
    (CAMERA_CONFIG, "ChaseVerticalResponse", 6),
    (CAMERA_CONFIG, "ChaseVerticalResponse_RaisingThisDoes", "Makes the chase camera follow bumps and drops more tightly."),
    (CAMERA_CONFIG, "ChasePitchFollow", 0.5),
    (CAMERA_CONFIG, "ChasePitchFollow_RaisingThisDoes", "Makes the chase camera follow more of the vehicle's nose-up and nose-down pitch on slopes."),
    (CAMERA_CONFIG, "ChaseAccelLagStudsPerAccel", 0.045),
    (CAMERA_CONFIG, "ChaseAccelLagStudsPerAccel_RaisingThisDoes", "Pulls the chase camera back more under acceleration and pushes it in more under braking."),
    (CAMERA_CONFIG, "ChaseAccelLagMaxStuds", 3),
    (CAMERA_CONFIG, "ChaseAccelLagMaxStuds_RaisingThisDoes", "Allows a larger pull-back and push-in."),
    (CAMERA_CONFIG, "ChaseBoostPunchDegrees", 4),
    (CAMERA_CONFIG, "ChaseBoostPunchDegrees_RaisingThisDoes", "Widens the brief field-of-view punch when a boost starts."),
    (CAMERA_CONFIG, "ChaseBoostKickStudsPerSecond", 9),
    (CAMERA_CONFIG, "ChaseBoostKickStudsPerSecond_RaisingThisDoes", "Throws the chase camera back harder when a boost starts."),
    (CAMERA_CONFIG, "ChaseFovDollyExponent", 0.25),
    (CAMERA_CONFIG, "ChaseFovDollyExponent_RaisingThisDoes", "Moves the chase camera closer as the field of view widens, keeping the vehicle nearer its normal size on screen."),
    (CAMERA_CONFIG, "ChaseShakeScale", 1),
    (CAMERA_CONFIG, "ChaseShakeScale_RaisingThisDoes", "Strengthens impact, landing, boost and high-speed camera shake. 0 turns shake off."),
    (CAMERA_CONFIG, "ChaseMinDistanceStuds", 8),
    (CAMERA_CONFIG, "ChaseMinDistanceStuds_RaisingThisDoes", "Keeps the chase camera farther from the vehicle when a wall pushes it in."),
    (CAMERA_CONFIG, "ChaseOcclusionRadiusStuds", 0.6),
    (CAMERA_CONFIG, "ChaseOcclusionRadiusStuds_RaisingThisDoes", "Keeps the chase camera farther from walls."),
    (CAMERA_CONFIG, "ChaseEntryBlendSeconds", 0.7),
    (CAMERA_CONFIG, "ChaseEntryBlendSeconds_RaisingThisDoes", "Lengthens the blend into the chase camera when driving starts."),
    (CAMERA_CONFIG, "ChaseLookReturnDelaySeconds", 0.25),
    (CAMERA_CONFIG, "ChaseLookReturnDelaySeconds_RaisingThisDoes", "Waits longer after free look before the chase camera returns behind the vehicle."),
    (CAMERA_CONFIG, "ChaseLookReturnRate", 6),
    (CAMERA_CONFIG, "ChaseLookReturnRate_RaisingThisDoes", "Returns the chase camera behind the vehicle faster after free look."),
    (CAMERA_CONFIG, "ChaseLookMouseRadiansPerPixel", 0.0045),
    (CAMERA_CONFIG, "ChaseLookMouseRadiansPerPixel_RaisingThisDoes", "Makes right-mouse free look turn faster."),
    (CAMERA_CONFIG, "ChaseLookTouchRadiansPerPixel", 0.0075),
    (CAMERA_CONFIG, "ChaseLookTouchRadiansPerPixel_RaisingThisDoes", "Makes touch free look turn faster."),
    (CAMERA_CONFIG, "ChaseRollMaxDegrees", 11),
    (CAMERA_CONFIG, "ChaseRollMaxDegrees_RaisingThisDoes", "Allows the chase camera to lean farther in turns and drifts."),
    (CAMERA_CONFIG, "ChaseTurnRollDegreesPerRadian", 3.2),
    (CAMERA_CONFIG, "ChaseTurnRollDegreesPerRadian_RaisingThisDoes", "Leans the chase camera more for the same rate of turn."),
    (CAMERA_CONFIG, "ChaseSlipRoll", 0.22),
    (CAMERA_CONFIG, "ChaseSlipRoll_RaisingThisDoes", "Leans the chase camera more while the vehicle slides or drifts."),
    (CAMERA_CONFIG, "ChaseRollResponse", 5),
    (CAMERA_CONFIG, "ChaseRollResponse_RaisingThisDoes", "Makes the chase camera lean and recover faster."),
    (CAMERA_CONFIG, "ChaseDriftShiftStuds", 5),
    (CAMERA_CONFIG, "ChaseDriftShiftStuds_RaisingThisDoes", "Moves the view farther toward the inside of the corner while the vehicle slides, putting the vehicle more off-centre. 0 turns the side shift off."),
    (CAMERA_CONFIG, "ChaseDriftShiftResponse", 3.5),
    (CAMERA_CONFIG, "ChaseDriftShiftResponse_RaisingThisDoes", "Makes the drift side shift arrive and recover faster."),
    (CAMERA_CONFIG, "ChaseSpeedLinesEnabled", True),
    (CAMERA_CONFIG, "ChaseSpeedLinesEnabled_Description", "Shows speed streaks at the screen edges at high speed and during boost."),
    (CAMERA_CONFIG, "ChaseSpeedLineCount", 64, [46]),
    (CAMERA_CONFIG, "ChaseSpeedLineCount_RaisingThisDoes", "Draws more speed streaks (halved on touch devices). Read when a drive starts."),
    (CAMERA_CONFIG, "ChaseSpeedLineStartMph", 110),
    (CAMERA_CONFIG, "ChaseSpeedLineStartMph_RaisingThisDoes", "Makes speed streaks begin at a higher speed."),
    (CAMERA_CONFIG, "ChaseSpeedLineFullMph", 230),
    (CAMERA_CONFIG, "ChaseSpeedLineFullMph_RaisingThisDoes", "Makes speed streaks reach full strength at a higher speed."),
    (CAMERA_CONFIG, "ChaseSpeedLineOpacity", 0.7, [0.55]),
    (CAMERA_CONFIG, "ChaseSpeedLineOpacity_RaisingThisDoes", "Makes speed streaks more visible."),
    (CAMERA_CONFIG, "ChaseCutDistanceStuds", 60),
    (CAMERA_CONFIG, "ChaseCutDistanceStuds_RaisingThisDoes", "Requires a longer single-frame jump before the chase camera cuts instead of following."),
]

# name -> (instance path, before file, after file); after files that do not exist yet are left out of the build.
SCRIPTS = {
    "DrivingClient": (VEHICLES + ["DrivingClient"], "before/DrivingClient.lua", "after/DrivingClient.lua"),
    "DrivingCameraClient": (VEHICLES + ["DrivingCameraClient"], "before/DrivingCameraClient.lua", "after/DrivingCameraClient.lua"),
    "VehicleAudioClient": (AUDIO + ["VehicleAudioClient"], "before/VehicleAudioClient.lua", "audio/after/VehicleAudioClient.lua"),
    "VehicleAudioCatalog": (AUDIO + ["VehicleAudioCatalog"], "before/VehicleAudioCatalog.lua", "audio/after/VehicleAudioCatalog.lua"),
    "VehicleVFXClient": (VEHICLES + ["VehicleVFXClient"], "before/VehicleVFXClient.lua", "vfx/after/VehicleVFXClient.lua"),
    "VehiclePreviewVFXClient": (VEHICLES + ["VehiclePreviewVFXClient"], "before/VehiclePreviewVFXClient.lua", "vfx/after/VehiclePreviewVFXClient.lua"),
}


# Synthesised file -> [(rev layer folder or None, attribute)] on EXOTIC_V10_AUDIO (table in audio/NOTES.md).
SLOTS = {
    "v10_idle_1000": [("V10Idle1000", "AssetId")],
    "v10_on_2000": [("V10On2000", "AssetId")], "v10_on_3500": [("V10On3500", "AssetId")],
    "v10_on_5000": [("V10On5000", "AssetId")], "v10_on_6500": [("V10On6500", "AssetId")],
    "v10_on_8000": [("V10On8000", "AssetId")],
    "v10_off_3000": [("V10Off3000", "AssetId")], "v10_off_6000": [("V10Off6000", "AssetId")],
    "boost_loop": [(None, "BoostLoopAssetId")], "thruster_roar": [(None, "BoostBodyAssetId")],
    "boost_ignite": [(None, "BoostIgnitionAssetId")],
    "boost_release": [(None, "BoostReleaseAssetId"), (None, "BoostEmptyAssetId"), (None, "FullBoostSpentAssetId")],
    "turbine_low": [(None, "TurbineLowAssetId")], "turbine_high": [(None, "TurbineHighAssetId")],
    "energy_hum": [(None, "EnergyHumAssetId")], "supercharger_whine": [(None, "SuperchargerWhineAssetId")],
    "stabiliser_strain": [(None, "SlipStrainAssetId")], "drift_charge": [(None, "DriftChargeAssetId")],
    "wind_rush": [(None, "DriverWindAssetId")], "wind_buffet": [(None, "WindBuffetAssetId")],
    "turbo_flutter": [(None, "TurboFlutterAssetId")], "drift_release": [(None, "DriftChargeReleaseAssetId")],
    "pop_1": [(None, "Pop1AssetId")], "pop_2": [(None, "Pop2AssetId")], "pop_3": [(None, "Pop3AssetId")],
    "pop_4": [(None, "Pop4AssetId")], "bang_1": [(None, "Bang1AssetId")], "bang_2": [(None, "Bang2AssetId")],
    "impact_light": [(None, "ImpactLightAssetId")], "impact_medium": [(None, "ImpactMediumAssetId")],
    "impact_heavy": [(None, "ImpactHeavyAssetId")], "impact_severe": [(None, "ImpactSevereAssetId")],
    "land_thump": [(None, "LandingThumpAssetId")],
}


# Uploaded but not used since round 4 (Oscar: too much going on, some of it cartoony): the rising drift-charge
# tone and its release zap, the boost-end release sound (the boost now just fades), the high turbine layer.
SWITCHED_OFF = {"drift_charge", "drift_release", "boost_release", "turbine_high"}


def djb2(text):
    x = 5381
    for b in text.encode("utf-8"):
        x = (x * 33 + b) % 4294967296
    return x


def read(relative):
    return io.open(os.path.join(HERE, relative), encoding="utf-8", newline="").read()


def captured_attributes():
    """(dotted path, key) -> value, from the capture taken with the before-sources."""
    dump = json.load(io.open(os.path.join(HERE, "before", "config.json"), encoding="utf-8"))
    found = {}
    for records in dump.values():
        for record in records:
            path = "ReplicatedStorage/Config/" + record["path"]
            for key, value in (record["attrs"] or {}).items():
                found[(path, key)] = value
    return found


def main():
    before = read("before/DrivingClient.lua")
    after = before
    for old, new, count in DRIVING_EDITS:
        if after.count(old) != count:
            raise SystemExit("anchor found %d times, expected %d: %r" % (after.count(old), count, old[:70]))
        after = after.replace(old, new)
    os.makedirs(os.path.join(HERE, "after"), exist_ok=True)
    io.open(os.path.join(HERE, "after", "DrivingClient.lua"), "w", encoding="utf-8", newline="").write(after)

    history_path = os.path.join(HERE, "applied_hashes.json")
    history = json.load(open(history_path)) if os.path.exists(history_path) else {}
    scripts = {}
    only = set(sys.argv[1:])
    for name, (path, before_file, after_file) in SCRIPTS.items():
        if only and name not in only:
            continue
        if not os.path.exists(os.path.join(HERE, after_file)):
            continue
        b, a = djb2(read(before_file)), djb2(read(after_file))
        if a == b:
            continue
        prior = [h for h in history.get(name, []) if h not in (a, b)]
        scripts[name] = {"path": path, "before": b, "after": a, "prior": prior,
                         "file": {"before": before_file, "after": after_file}}
        history[name] = prior + [a]
    json.dump(history, open(history_path, "w"), indent=1, sort_keys=True)

    rows = [(row[0], row[1], row[2]) for row in CONFIG]
    superseded = {("/".join(row[0]), row[1]): row[3] for row in CONFIG if len(row) > 3}
    instances = []
    for part in ("audio", "vfx"):
        spec_path = os.path.join(HERE, part, "config_spec.json")
        if os.path.exists(spec_path) and any(s["file"]["after"].startswith(part + "/") for s in scripts.values()):
            spec = json.load(io.open(spec_path, encoding="utf-8"))
            rows += [(row["path"], row["key"], row["value"]) for row in spec.get("attributes", [])]
            instances += spec.get("instances", [])
    captured = captured_attributes()
    attributes = []
    for path, key, value in rows:
        row = {"path": path, "key": key, "value": value}
        old = captured.get(("/".join(path), key))
        if old is not None:
            row["before"] = old
        if ("/".join(path), key) in superseded:
            row["was"] = superseded[("/".join(path), key)]
        attributes.append(row)

    # Round 2 changes to config the audio part already installed: forced updates, removals and new children.
    updates, late = [], []
    round2 = os.path.join(HERE, "audio", "config_round2.json")
    if os.path.exists(round2) and any(s["file"]["after"].startswith("audio/") for s in scripts.values()):
        spec = json.load(io.open(round2, encoding="utf-8"))
        updates += [{"path": r["path"], "key": r["key"], "value": r["value"]} for r in spec.get("attributes", [])]
        updates += [{"path": r["path"], "key": r["key"]} for r in spec.get("remove", [])]
        late += spec.get("instances", [])
        allowed = ("ReplicatedStorage/Config/Audio/VehicleProfiles/EXOTIC_V10_AUDIO", "ReplicatedStorage/Config/Audio/")
        new_keys = {("/".join(a["path"]), a["key"]) for a in attributes if "before" not in a}
        for row in updates:
            where = "/".join(row["path"])
            if not where.startswith(allowed[0]) and (where, row["key"]) not in new_keys:
                raise SystemExit("round 2 update touches config this delivery did not create: %s @%s" % (where, row["key"]))

    if updates:
        profile = ["ReplicatedStorage", "Config", "Audio", "VehicleProfiles", "EXOTIC_V10_AUDIO"]
        # Mix for the uploaded set, from Oscar's feedback. Round 3: less whine, more depth, boost that stands
        # apart. Round 4: fewer layers at once, nothing cartoony, boost end is a plain fade, harder pops.
        for key, value in (("SuperchargerWhineGain", 0.12), ("SuperchargerWhinePitchMax", 1.3),
                           ("TurbineLowGain", 0.16), ("TurbineOctaves", 1.2),
                           ("EnergyHumGain", 0.18), ("SlipStrainPitch", 1), ("SlipStrainGain", 0.24),
                           ("TwinEngineGain", 0.45), ("BlowOffGain", 0.25), ("TurboFlutterGain", 0.3),
                           ("BoostDuckDb", 6), ("BoostLoopGain", 0.9), ("BoostBodyGain", 0.7),
                           ("BoostIgnitionGain", 1), ("BoostIgnitionMiniGain", 1),
                           ("Pop1Gain", 0.95), ("Pop2Gain", 0.95), ("Pop3Gain", 0.95), ("Pop4Gain", 0.95),
                           ("Bang1Gain", 1), ("Bang2Gain", 1),
                           ("ImpactLightGain", 0.45), ("ImpactMediumGain", 0.65), ("ImpactHeavyGain", 0.85),
                           ("ImpactSevereGain", 1), ("LandingThumpGain", 0.6),
                           ("TurboWhistleAssetId", ""),
                           ("ProfileRevision", 3)):
            updates.append({"path": profile, "key": key, "value": value})
        updates.append({"path": profile + ["RevLayers", "StandInExhaust"], "key": "Gain", "value": 0.65})
        # Uploaded sounds: audio/asset_ids.json (file name -> asset id) written into their slots.
        ids_path = os.path.join(HERE, "audio", "asset_ids.json")
        ids = json.load(io.open(ids_path, encoding="utf-8")) if os.path.exists(ids_path) else {}
        filled = 0
        for name, asset in sorted(ids.items()):
            if name.startswith("_"):
                continue
            if name not in SLOTS:
                raise SystemExit("asset_ids.json: no slot for " + name)
            for layer, key in SLOTS[name]:
                updates.append({"path": profile + (["RevLayers", layer] if layer else []), "key": key,
                                "value": "" if name in SWITCHED_OFF else "rbxassetid://%d" % asset})
            filled += 1
        if filled:
            updates.append({"path": profile, "key": "ProfileRevision", "value": 3 + filled})

    # Exotic V2 tuning changed after the first install (new attributes of this delivery, so forced here).
    stabiliser = ["ReplicatedStorage", "Config", "Vehicles", "StabiliserVFX"]
    if any(sc["file"]["after"].startswith("vfx/") for sc in scripts.values()):
        for key, value in (("ExoticV2DustBase", 0), ("ExoticV2DustSpeedGain", 0), ("ExoticV2DustSquashGain", 0),
                           ("ExoticV2PreviewDust", 0), ("ExoticV2RemoteDust", 0), ("ExoticV2PadBase", 0.55)):
            updates.append({"path": stabiliser, "key": key, "value": value})

    # Exotic V2 effect templates: built in Studio by vfx/templates_exotic.lua from the uploaded texture ids
    # (vfx/texture_ids.json: texture name -> asset id).
    builders = []
    if os.path.exists(os.path.join(HERE, "vfx", "templates_exotic.lua")) and any(
            s["file"]["after"].startswith("vfx/") for s in scripts.values()):
        ids_path = os.path.join(HERE, "vfx", "texture_ids.json")
        texture_ids = json.load(io.open(ids_path, encoding="utf-8")) if os.path.exists(ids_path) else {}
        builders.append({"file": "vfx/templates_exotic.lua",
                         "parent": ["ReplicatedStorage", "Assets", "VFX", "VehicleTemplates"],
                         "textures": {name: "rbxassetid://%d" % asset for name, asset in texture_ids.items()
                                      if not name.startswith("_")}})

    data = json.dumps({"placeId": PLACE_ID, "base": BASE, "scripts": scripts, "attributes": attributes,
                       "instances": instances, "updates": updates, "lateInstances": late,
                       "builders": builders}, sort_keys=True)
    if "]==]" in data:
        raise SystemExit("config text contains the long-string terminator")
    engine = read("installer_engine.lua")
    for mode in ("AUDIT", "APPLY", "ROLLBACK"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])\n%s' % (mode, data, engine)
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print(json.dumps({name: {"before": "%08x" % s["before"], "after": "%08x" % s["after"], "prior": len(s["prior"])}
                      for name, s in scripts.items()}, sort_keys=True))
    print("attributes", len(attributes), "instances", len(instances))


if __name__ == "__main__":
    main()
