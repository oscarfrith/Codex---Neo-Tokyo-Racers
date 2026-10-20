"""camerafx part config (CONTRACT.md sections 2 and 8).

New number attributes on two existing folders, each with a <Name>_RaisingThisDoes string beside it. Switches are
numbers 0/1, never booleans: the camera flag() helper and the VFX type check ignore a configured false. The defaults
here equal the code fallbacks in camerafx/after/DrivingCameraClient.lua and camerafx/after/VehicleVFXClient.lua, so
removing a row (ROLLBACK) leaves the same behaviour under the new sources.
"""

CAMERA = ["ReplicatedStorage", "Config", "Vehicles", "Camera"]
VFX = ["ReplicatedStorage", "Config", "Vehicles", "StabiliserVFX"]

INSTANCES = []

# (folder, name, default, what raising it feels like and what 0 does)
_CAMERA = [
    ("ChaseDrivetrainEnabled", 1,
     "1 turns on the drivetrain camera cues (spin hold, shift nod and FOV pulse, limiter shimmer) for cars with a class drivetrain; 0 gives exactly the camera from before."),
    ("ChaseSpinModeEnabled", 1,
     "1 holds the view steady while the car spins; 0 lets the camera swing round with the car as before."),
    ("ChaseSpinEnterLevel", 0.2,
     "Needs a bigger spin (FeelSpin 0..1) before the camera holds its view; 0 holds it on the slightest spin."),
    ("ChaseSpinExitLevel", 0.1,
     "Releases the held spin view earlier as the spin dies down; 0 keeps holding until the spin has fully stopped."),
    ("ChaseSpinEaseInSeconds", 0.15,
     "Blends into the held spin view more gently; near 0 snaps straight into it."),
    ("ChaseSpinEaseOutSeconds", 0.8,
     "Returns the camera behind the car more slowly after a spin (the spin yaw-rate cap relaxes over this time); near 0 swings back at the normal camera follow speed, with no cap."),
    ("ChaseSpinTravelMinStuds", 12,
     "The held spin view follows the direction of travel only at a higher speed (studs/s); 0 always follows travel."),
    ("ChaseSpinTravelFadeStuds", 6,
     "Fades travel-following in over a wider speed band above ChaseSpinTravelMinStuds; 0 switches it on at once."),
    ("ChaseSpinTravelResponse", 3,
     "Turns the held spin view toward the direction of travel faster; 0 never turns it."),
    ("ChaseSpinYawRateMax", 1.5,
     "Lets the camera turn faster while the car spins (rad/s, from the first spin frame until the ease-out begins); lower keeps the view calmer, 0 is treated as 0.05 (almost still)."),
    ("ChaseShiftMinThrottle", 0.5,
     "Needs more throttle before an upshift nods the camera and pulses the FOV; 0 does it on every upshift (never on downshifts)."),
    ("ChaseShiftNodDegrees", 1.0,
     "Deeper camera nod on an upshift under load (degrees at full shift strength); 0 turns the nod off."),
    ("ChaseShiftNodOmega", 9,
     "Makes the upshift nod quicker and snappier; lower values give a slower, softer nod."),
    ("ChaseShiftFovDegrees", 1.2,
     "Bigger field-of-view pulse on an upshift under load (positive widens, negative narrows); 0 turns the pulse off."),
    ("ChaseShiftFovOmega", 10,
     "Makes the upshift FOV pulse shorter and sharper; lower values make it longer and softer."),
    ("ChaseLaunchKickStudsPerSecond", 6,
     "Throws the camera back harder on a launch shift from a standstill; 0 turns the kick off."),
    ("ChaseLimiterShimmerDegrees", 0.08,
     "Stronger roll buzz while the engine bounces off the rev limiter (never in neutral or on a shift cut); 0 turns it off."),
    ("ChaseLimiterShimmerHz", 12,
     "Faster limiter buzz; lower values give a slower wobble."),
    ("ChaseLimiterHoldSeconds", 0.15,
     "Keeps the limiter buzz going longer after each limiter bounce; 0 turns the buzz off."),
    ("ChaseLimiterShimmerResponse", 20,
     "Limiter buzz fades in and out faster; lower values ease it in and out."),
]

_VFX = [
    ("DrivetrainVFXEnabled", 1,
     "1 turns on the drivetrain effects (jets follow engine load, shift vent flame, spin stutter and dust, thrust-slip wash, strain shake) for cars with a class drivetrain; 0 gives exactly the effects from before."),
    ("DrivetrainThrustLoadEnabled", 1,
     "1 makes the thrust jets follow engine load in a forward gear, so shift and limiter cuts dim them; 0 keeps them on the raw throttle as before while the other drivetrain effects stay on."),
    ("DrivetrainThrustReleaseSeconds", 0.15,
     "Thrust jets fade more slowly when engine load drops, so shift and limiter cuts show less; values under 0.08 act as 0.08. With the throttle held a cut only dims the jets, never switches them off."),
    ("ShiftVentMinStrength", 0.7,
     "Only harder upshifts (FeelShiftStrength 0..1, which already includes the class FeelGearing dial) fire a vent flame; 0 fires one on every upshift of any strength (none at FeelGearing 0)."),
    ("ShiftVentCount", 10,
     "Bigger vent flame burst on a hard upshift (particles at full strength); 0 turns the vent flame off."),
    ("ShiftVentPopStrength", 0.6,
     "Hotter vent flame and brighter flash; it is multiplied by the shift strength, so the backfire flame tongue needs ShiftVentPopStrength x strength of 0.8 or more (never at the default 0.6); 0 is the smallest crackle."),
    ("ShiftVentFlashSeconds", 0.08,
     "Longer vent flash after a hard upshift; 0 is the shortest flash."),
    ("ShiftVentFlashGain", 1.4,
     "Brighter vent flash on cars without the Exotic V2 effects; 1 adds no extra brightness."),
    ("SpinStutterHz", 9,
     "Stabiliser jets alternate faster while the car spins (a brightness pulse, never on/off); 0 holds them steady."),
    ("SpinStutterMinSpin", 0.2,
     "A bigger spin (FeelSpin 0..1) is needed before the spin effects start; 0 reacts to the smallest spin."),
    ("SpinStutterFullSpin", 0.6,
     "Spin effects reach full strength only in a bigger spin; at or below SpinStutterMinSpin they switch straight to full."),
    ("SpinStutterFloor", 0.45,
     "Shallower stutter: the dim phase of each jet stays brighter; 1 means no pulse, 0 dims each side almost out."),
    ("SpinJetLevel", 1,
     "Stronger stabiliser jets during a spin; 0 turns the spin jets off."),
    ("SpinFadeSeconds", 0.25,
     "Spin effects linger longer after the spin ends; 0 stops them at once."),
    ("SpinDustLevel", 0.6,
     "More hover dust during a spin (templates driven by HoverDust; no effect on Exotic V2 cars, whose dust has its own ExoticV2Dust tuning); 0 adds none."),
    ("SpinDustBurstSeconds", 0.25,
     "Fewer ground-wash bursts during a spin (seconds between bursts); small values give a near continuous wash."),
    ("SpinDustBurstCount", 5,
     "Bigger ground-wash bursts during a spin (particles at full spin); 0 turns them off. On Exotic V2 every burst also gives the same small hover-jet surge whatever the count, and about 6 or more also fires the landing ring."),
    ("ThrustSlipMin", 0.1,
     "More thrust slip (FeelThrustSlip 0..1) is needed before the launch effects show; 0 shows them on any slip."),
    ("ThrustSlipFull", 0.6,
     "Launch effects reach full strength only at more slip; at or below ThrustSlipMin they switch straight to full."),
    ("ThrustSlipDustLevel", 0.5,
     "More hover dust while the thrust slips (templates driven by HoverDust; no effect on Exotic V2 cars, whose dust has its own ExoticV2Dust tuning); 0 adds none."),
    ("ThrustSlipWashSeconds", 0.2,
     "Fewer ground-wash bursts while the thrust slips (seconds between bursts); small values give a near continuous wash."),
    ("ThrustSlipWashCount", 5,
     "Bigger launch ground wash while the thrust slips (particles at full slip); 0 turns it off. On Exotic V2 every burst also gives the same small hover-jet surge whatever the count, and about 6 or more also fires the landing ring."),
    ("StrainRpmStart", 0.96,
     "The jets start shaking only closer to the redline (fraction of redline rpm); lower shakes earlier in every gear, 1 only on the limiter."),
    ("StrainOverdriveLevel", 0.6,
     "More jet shake in Overdrive (boosting past top-gear redline); 0 gives none."),
    ("StrainJitter", 0.12,
     "Stronger jet shake near the limiter and in Overdrive (share of thrust, at most 0.5); 0 turns the shake off."),
    ("StrainHz", 16,
     "Faster jet shake; lower values give a slow flutter."),
]

ATTRIBUTES = []
for _folder, _rows in ((CAMERA, _CAMERA), (VFX, _VFX)):
    for _name, _value, _raising in _rows:
        ATTRIBUTES.append((_folder, _name, _value))
        ATTRIBUTES.append((_folder, _name + "_RaisingThisDoes", _raising))
