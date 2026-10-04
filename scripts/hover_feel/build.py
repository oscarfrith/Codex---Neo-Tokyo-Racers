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

FEEL_HELPERS = '''local FEEL_ATTRIBUTES = {"FeelThrottle", "FeelSpeedMph", "FeelSlip", "FeelBoostCharge", "FeelBoostKind", "FeelDriftCharge", "FeelGrounded", "FeelHover", "FeelImpactRevision", "FeelImpactStrength", "FeelLandRevision", "FeelLandStrength"}
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
	if feel.PreviousVelocity and not feel.Skip and dt <= 0.05 then
		local strength = (horizontal - feel.PreviousVelocity - feel.PreviousAcceleration * dt).Magnitude
		if strength >= configNumber("Driving", "FeelImpactMinStuds", 9, 1, 200) and os.clock() - feel.LastImpact > 0.12 then
			feel.ImpactRevision += 1
			feel.LastImpact = os.clock()
			vehicle:SetAttribute("FeelImpactStrength", strength)
			vehicle:SetAttribute("FeelImpactRevision", feel.ImpactRevision)
		end
	end
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
end

'''

# (old, new, expected count). Every insertion keeps the original text and adds to it.
DRIVING_EDITS = [
    ("local handleResetAction\n", FEEL_HELPERS + "local handleResetAction\n", 1),
    ('\t\tstate.Vehicle:SetAttribute("DriveReady", false)\n',
     '\t\tstate.Vehicle:SetAttribute("DriveReady", false)\n\t\tclearFeelState(state.Vehicle)\n', 1),
    ("\tstate.AccelCameraActive = false\n\tstate.BoostCameraActive = false\n\n\tlocal root = state.Vehicle.PrimaryPart\n",
     "\tstate.AccelCameraActive = false\n\tstate.BoostCameraActive = false\n"
     "\tstate.Feel = { ImpactRevision = 0, LandRevision = 0, LastImpact = 0, AirTime = 0, FallSpeed = 0, HoverSum = 0, BoostKind = \"\", Skip = true, SkipNext = false }\n"
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
    (CAMERA_CONFIG, "ScriptedChaseEnabled", True),
    (CAMERA_CONFIG, "ScriptedChaseEnabled_Description", "True: scripted chase camera (lens locked to the car, springs for every relative motion). False: the V6.1 camera where Roblox owns motion, collision and orbit."),
    (CAMERA_CONFIG, "ChaseHeightStuds", 6.5),
    (CAMERA_CONFIG, "ChaseHeightStuds_RaisingThisDoes", "Raises the chase camera above the vehicle."),
    (CAMERA_CONFIG, "ChasePivotHeightStuds", 2.5),
    (CAMERA_CONFIG, "ChasePivotHeightStuds_RaisingThisDoes", "Raises the point the chase camera orbits around."),
    (CAMERA_CONFIG, "ChaseAimAheadStuds", 12),
    (CAMERA_CONFIG, "ChaseAimAheadStuds_RaisingThisDoes", "Aims the chase camera farther ahead of the vehicle, which moves the vehicle lower in frame."),
    (CAMERA_CONFIG, "ChaseAimHeightStuds", 3.2),
    (CAMERA_CONFIG, "ChaseAimHeightStuds_RaisingThisDoes", "Raises the point the chase camera looks at."),
    (CAMERA_CONFIG, "ChaseYawResponse", 7.5),
    (CAMERA_CONFIG, "ChaseYawResponse_RaisingThisDoes", "Makes the chase camera swing behind the vehicle faster when it turns."),
    (CAMERA_CONFIG, "ChaseSlipFollow", 0.35),
    (CAMERA_CONFIG, "ChaseSlipFollow_RaisingThisDoes", "Moves the chase camera farther toward the direction of travel while the vehicle slides, showing more of its side."),
    (CAMERA_CONFIG, "ChaseLookAheadSeconds", 0.22),
    (CAMERA_CONFIG, "ChaseLookAheadSeconds_RaisingThisDoes", "Turns the view farther into a corner."),
    (CAMERA_CONFIG, "ChaseLookAheadMaxDegrees", 9),
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

    rows = list(CONFIG)
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
        attributes.append(row)

    data = json.dumps({"placeId": PLACE_ID, "base": BASE, "scripts": scripts, "attributes": attributes,
                       "instances": instances}, sort_keys=True)
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
