"""physics part config (CONTRACT.md sections 2 and 4): ReplicatedStorage.Config.Vehicles.Drivetrain and its exotic class.

One new folder, Drivetrain, with one child folder per vehicle class (CategoryId, lower case). This delivery creates only
"exotic". Every numeric attribute has a <Name>_RaisingThisDoes string next to it. Switches are numbers 0 or 1, never
booleans. The defaults equal the code fallbacks in physics/after/VehicleDynamics.lua (DRIVETRAIN_NUMBERS), so a
missing attribute keeps the designed feel; a missing class folder (or Enabled 0) gives exactly the old driving.

DrivingClient re-reads the class folder about 4 times a second (GetAttributes, change detection), so edits made during
Play apply within about 0.25 s; GearRatios and TorqueCurve are parsed only when their text changes.
"""

VEHICLES = ["ReplicatedStorage", "Config", "Vehicles"]

ROOT_NOTES = (
    "Drivetrain feel per vehicle class (scripts/drivetrain_feel/CONTRACT.md). Each child Folder is named after a "
    "CategoryId (exotic, bruiser, muscle) and switches the gearbox, weight and spin-out on for that class; a class with "
    "no folder drives exactly as before. To add a class: duplicate the exotic folder, rename the copy to the CategoryId, "
    "and retune it (start with the Feel* dials, then GearRatios, RedlineRpm and TorqueCurve). No code change is needed. "
    "Enabled 0 here switches every class off at once; Enabled 0 on a class folder switches only that class off."
)

EXOTIC_NOTES = (
    "Exotic V10 hybrid, 7-speed automatic. Tune the Feel dials first (1 = the designed feel): FeelWeight (mass: yaw "
    "inertia, steering build-up, grip build, pitch and roll, braking; 0 = today's light instant feel), FeelGearing "
    "(how much you feel the gears; 0 = CVT-smooth, no cut), FeelAcceleration (thrust in every gear; top speed stays "
    "today's), FeelGrip (cornering limit and traction), FeelSpin (how readily and hard it spins; 0 = never), "
    "FeelEngineBrake (lift-off slowing; 0 = drag and rolling only). Every number has a _RaisingThisDoes note."
)

# (name, default, what raising it feels like and what 0 does)
_EXOTIC = [
    # Switch and Feel dials (CONTRACT 4.1)
    ("Enabled", 1, "1 = this class uses the drivetrain (gearbox, weight, spin-out, rpm HUD); 0 = it drives, sounds and displays exactly as before."),
    ("FeelWeight", 1, "Heavier car: more yaw inertia, slower steering build-up on keys and touch, slower grip build, more pitch and roll, longer braking. 0 = today's light, instant feel (range 0-2.5)."),
    ("FeelGearing", 1, "Gears felt more: bigger torque steps between gears, longer and deeper shift cuts, snappier rev drops, stronger shift cues. 0 = CVT-smooth with no cut (range 0-2)."),
    ("FeelAcceleration", 1, "More engine thrust in every gear (quicker 0-60 and mid-range); top speed stays today's. Range 0.5-1.5."),
    ("FeelGrip", 1, "Higher cornering grip limit and more traction off the line (less wheelspin). Range 0.6-1.6."),
    ("FeelSpin", 1, "Spins more readily and more violently. 0 = it never spins (range 0-2.5)."),
    ("FeelEngineBrake", 1, "Stronger slowing when you lift off, more in low gears. 0 = coasting is only drag and rolling resistance (range 0-2)."),
    # Engine and gears (4.2)
    ("GearCount", 7, "More forward gears are used (up to the number of GearRatios, at most 9); fewer gears give longer, bigger steps."),
    ("IdleRpm", 1100, "Higher idle and lowest rpm (gauge, sound); 0 is not allowed (minimum 300)."),
    ("RedlineRpm", 8500, "Higher redline: the rpm scale stretches (gauge, sound, shift points scale with it); gear speeds do not change."),
    ("LimiterRpm", 8600, "Limiter sits further above redline (flare and limiter peak); clamped to 1-1.2 x RedlineRpm."),
    ("GearTorqueExponent", 0.8, "Bigger drop in thrust in each higher gear (more real, slower top-end pull). 0 = the same thrust in every gear."),
    ("TopGearOverspeed", 1.06, "Top gear runs out further above the top speed, so the engine sits lower in its rev range at top speed. 1 = top speed exactly at redline."),
    ("LaunchRpmFraction", 0.5, "Higher launch and power-brake revs in first gear (clutch slip, fraction of redline). 0 = first gear follows road speed from idle."),
    # Rev response and shift timing
    ("EngineRiseSeconds", 0.06, "Revs rise more lazily (heavier flywheel feel); falls scale with it through EngineFallScale. Minimum 0.01."),
    ("EngineFallScale", 1.5, "Revs fall more slowly than they rise (x EngineRiseSeconds). 1 = same speed up and down."),
    ("ShiftRpmSeconds", 0.05, "Slower rev drop after an upshift (divided by FeelGearing). Minimum 0.005."),
    ("ThrustSlipFlare", 0.6, "Revs flare higher when the thrust slips (launch, burnout). 0 = no flare."),
    ("ShiftCutSeconds", 0.06, "Longer torque cut on each upshift (x FeelGearing). 0 = no cut."),
    ("ShiftCutTorque", 0.45, "Share of thrust kept during the upshift cut: higher = gentler cut, 1 = no cut, 0 = full cut."),
    ("ShiftBlendSeconds", 0.06, "Slower thrust return after the upshift cut (x FeelGearing). 0 = thrust returns at once."),
    ("DownshiftBlendSeconds", 0.08, "Slower rev-matched rise after a downshift (no torque cut on downshifts). Minimum 0.01."),
    ("ShiftMinIntervalSeconds", 0.25, "Longer minimum time between shifts (less hunting, slower gear changes). Minimum 0.05."),
    # Upshift points
    ("UpshiftFlat", 0.97, "Holds each gear closer to redline at full throttle (fraction of redline). Above 1 is not allowed."),
    ("UpshiftPartLow", 0.62, "Later upshifts at light part throttle (0.3 throttle), fraction of redline."),
    ("UpshiftPartHigh", 0.85, "Later upshifts at heavy part throttle (0.9 throttle), fraction of redline."),
    ("UpshiftCruise", 0.45, "Later short-shifts when cruising (throttle between CruiseThrottleMin and 0.3), fraction of redline."),
    ("CruiseThrottleMin", 0.05, "More throttle needed before any cruise upshift; below it no upshift at all (except off the limiter)."),
    ("UpshiftMinLand", 0.33, "A cruise upshift must land at a higher rpm (fraction of redline), so it short-shifts less. 0 = no limit."),
    ("LiftHoldSeconds", 0.8, "Holds the gear longer after a lift before a part-throttle upshift (less churn when tapping). 0 = no hold."),
    # Downshifts and kickdown
    ("DownshiftBrakeLand", 0.82, "Braking downshifts happen earlier, landing at up to this fraction of redline (more engine braking, more blips)."),
    ("DownshiftCoastFraction", 0.3, "Coasting downshifts happen at higher rpm (fraction of redline). 0 = no coasting downshifts."),
    ("DownshiftCoastLand", 0.65, "Coasting and lugging downshifts may land at a higher rpm (fraction of redline)."),
    ("KickdownThrottle", 0.95, "More throttle needed for a kickdown (several gears at once)."),
    ("KickdownBelowFraction", 0.45, "Kickdown also fires at higher rpm (fraction of redline). 0 = no kickdown."),
    ("KickdownLand", 0.88, "Kickdown may drop to a lower gear, landing at up to this fraction of redline (harder kick)."),
    ("KickdownHoldSeconds", 0.12, "Full throttle must be held longer before a kickdown (fewer accidental kickdowns). 0 = instant."),
    # Limiter and neutral revs
    ("StopGearMph", 3, "First gear is selected below a higher speed (mph); also the standstill speed for the power-brake."),
    ("LimiterOnSeconds", 0.03, "Longer drive bursts between limiter cuts (slower bounce). Minimum 0.005."),
    ("LimiterCutSeconds", 0.045, "Longer limiter cuts (harder, slower bounce). 0 = the limiter holds without cutting."),
    ("LimiterHysteresisRpm", 150, "Deeper limiter bounce: the rpm drops further below redline in each cut. 0 = minimal bounce."),
    ("NeutralRevEnabled", 1, "1 = the engine revs in neutral with the throttle during a countdown (no force); 0 = idles until GO."),
    ("NeutralRevTarget", 1.02, "Higher neutral revs at full throttle (fraction of redline); above 1 bounces the limiter. 0 = stays at idle."),
    # Traction (4.3)
    ("TractionG", 1.15, "More traction off the line (g): less wheelspin and fewer spins, quicker launches up to the thrust."),
    ("TractionGripExponent", 0.15, "LateralGrip stat matters more for traction. 0 = every car gets the same traction."),
    ("TractionTierBonusG", 0.25, "Upgraded cars (PI toward TierFullPI) get more extra traction, felt off the line. 0 = no tier bonus."),
    ("TierStartPI", 250, "PI where the tier traction bonus and spin authority start rising; higher = only stronger cars get them."),
    ("TierFullPI", 750, "PI where the tier traction bonus and spin authority are full; higher = slower build across tiers."),
    ("TractionAssist", 0.35, "Removes more of the thrust slip (fewer launch flares and spins). 0 = no assist, 1 = never slips."),
    ("SlideGripFraction", 0.88, "Less thrust lost while the thrust slips (1 = slipping costs nothing; lower = burnouts are slower)."),
    # Resistance
    ("RollingDecel", 0.8, "More constant rolling resistance (studs/s^2): coasts down sooner. 0 = none (top speed is kept by re-deriving drag)."),
    ("RollingDecelPerStud", 0.004, "More speed-proportional resistance: coasts down sooner at speed. 0 = none (top speed is kept)."),
    ("EngineBrakeDecel", 1.5, "Stronger engine braking on a lift (studs/s^2 in top gear, more in low gears; x FeelEngineBrake). 0 = none."),
    # Brakes
    ("BrakeDecel", 70, "Stronger brakes at FeelWeight 1 (studs/s^2 at the reference brake stat). FeelWeight 0 uses today's brakes instead."),
    ("BrakeForceExponent", 0.35, "Braking stat matters more for brake strength. 0 = every car brakes the same."),
    ("BrakeFactorMin", 0.75, "Weakest cars brake harder (lower clamp of the braking stat factor)."),
    ("BrakeFactorMax", 1.4, "Strongest cars may brake harder (upper clamp of the braking stat factor)."),
    # Boost
    ("BoostShapeEnabled", 1, "1 = boost fades with speed so the boosted top speed stays today's; 0 = full boost at every speed (the speed guard still holds the top)."),
    ("BoostShareMin", 0.15, "Keeps more boost near the boosted top speed (lower bound of the fade); 1 = no fade."),
    ("SpeedGuardStrength", 2, "Holds the boosted top speed harder above SpeedGuardOverBoostTop x boosted top. 0 = no guard."),
    ("SpeedGuardOverBoostTop", 1.03, "Lets the car go further past today's boosted top speed before the guard bites (1 = exactly today's)."),
    ("OverdriveEnabled", 1, "1 = boosting past top-gear redline pins the engine at redline with no limiter cut (Overdrive); 0 = it hits the limiter."),
    # Steering build-up (4.4)
    ("SteerRiseSeconds", 0.2, "Slower keyboard steering build-up to full lock (x FeelWeight). 0 = instant like today."),
    ("SteerReturnRate", 14, "Keyboard steering returns to centre faster (per second, at FeelWeight 1 or more)."),
    ("TouchSteerRate", 10, "Touch steering follows the finger faster (per second, at FeelWeight 1 or more); gamepad is never limited."),
    # Yaw
    ("YawOmega", 9, "Quicker, stiffer turn-in (rad/s; divided by FeelWeight); lower = more yaw inertia and lag."),
    ("YawDamping", 0.75, "Less overshoot and settle after turn-in; lower = more wobble that reads as mass."),
    ("YawWeightExponent", 0.5, "Weight stat matters more for yaw inertia. 0 = every car turns in the same."),
    ("YawWeightMin", 0.75, "Heaviest cars turn in quicker (lower clamp of the weight factor)."),
    ("YawWeightMax", 1.3, "Lightest cars may turn in quicker (upper clamp of the weight factor)."),
    ("YawKinematicBelowMph", 15, "Turning stays exactly like today up to a higher speed (parking, U-turns); inertia blends in above it. 0 = inertia at every speed."),
    ("YawUnwindScale", 2, "Car stops turning faster after you release the steering (less run-on). 1 = same as turn-in."),
    ("YawRateMax", 5, "Highest yaw rate allowed (rad/s, at most 5 so the camera never cuts)."),
    # Lateral grip
    ("LateralCapG", 3.4, "Higher cornering grip limit (g): tighter fast corners, later understeer. Lower = heavier, wider lines."),
    ("LateralCapGripExponent", 0.25, "LateralGrip stat matters more for the grip limit. 0 = every car has the same limit."),
    ("LateralCurveShape", 1.4, "Grip falls away more once past the limit (sharper peak). 1 = grip never drops past the limit (1-1.9)."),
    ("YawCapMargin", 0.9, "Car may turn faster than its grip carries it at the limit (more slide, less understeer). Lower = more understeer."),
    ("GripRelaxStuds", 2, "Grip builds over more travel when the car starts to slide (looser, heavier feel; x FeelWeight). 0 = instant."),
    ("DriftCapExempt", 1, "1 = drifts keep today's uncapped grip and yaw (drift lines unchanged); 0 = the grip limit also applies in drifts."),
    # Body motion
    ("PitchDegreesPerG", 2.4, "More nose-up under acceleration and nose-down under braking and shift cuts (degrees per g, x FeelWeight). 0 = level."),
    ("PitchMaxDegrees", 5, "Allows a larger pitch angle (degrees). 0 = no pitch."),
    ("PitchOmega", 9, "Pitch and roll follow quicker and snappier (rad/s); lower = slower, floatier body motion."),
    ("PitchDamping", 0.6, "Less bounce on pitch and roll; lower = more overshoot."),
    ("RollDegreesPerG", 0.9, "More body roll away from the turn from cornering g (degrees per g, x FeelWeight). 0 = off; negative leans into the turn instead. The steering bank is separate and unchanged."),
    ("RollMaxDegrees", 3, "Allows a larger body roll angle (degrees). 0 = no roll."),
    # Impact yaw
    ("ImpactYawKick", 0.6, "Hits off the car's centre line turn it more (rad/s per 100 studs/s of impact). 0 = impacts never turn the car."),
    # Spin-out: gestures and window (4.5)
    ("SpinEnabled", 1, "1 = low-speed spin-outs are possible; 0 = the car never spins."),
    ("SpinStabSeconds", 0.4, "A slower throttle stab (seconds from under 0.3 to 0.9 throttle) still opens a spin window. 0 = only an instant stab."),
    ("SpinStabSteer", 0.8, "More steering lock needed for a stab to open a spin window (0-1)."),
    ("SpinAnalogRate", 4, "Gamepad throttle must rise faster (per second) to count as a stab; lower = easier stabs on a trigger."),
    ("SpinWindowSeconds", 0.7, "Spin window after a stab or power-brake lasts longer: a bigger spin can build. 0 = gestures do nothing."),
    ("PowerBrakeEnabled", 1, "1 = holding forward and brake at a standstill, then releasing brake, dumps the revs (burnout start); 0 = off."),
    ("PowerBrakeMinHold", 0.3, "Forward and brake must be held together longer before the release counts (seconds)."),
    ("PowerBrakeDumpSlip", 0.5, "Harder burnout and more spin on a power-brake release (extra thrust slip, fading over the window). 0 = no dump."),
    # When it can build
    ("SpinBelowMph", 25, "Spins can start at higher speed (mph; full authority below it, then fading over SpinFadeMph)."),
    ("SpinFadeMph", 12, "Spin authority fades out over a wider speed band above SpinBelowMph."),
    ("SpinSteerStart", 0.6, "More steering needed before a spin can build (0-1)."),
    ("SpinSteerWidth", 0.35, "Spin authority reaches full only at more steering past SpinSteerStart."),
    ("SpinSlipStart", 0.12, "More thrust slip needed before a spin can build (fewer spins)."),
    ("SpinSlipWidth", 0.25, "Spin authority reaches full only at more thrust slip past SpinSlipStart."),
    # Rates
    ("SpinBuildRate", 3.5, "Spins build faster (per second). 0 = never builds."),
    ("SpinDecayRate", 2.5, "Spins die down faster on their own (per second)."),
    ("SpinCatchRate", 8, "Lifting (under 0.3 throttle) or counter-steering catches the spin faster (per second)."),
    ("SpinSettleSeconds", 0.3, "Car eases back to normal steering more slowly after a catch (seconds). 0 = snaps back."),
    # Effect on the car
    ("SpinYawAccel", 7, "Spins rotate the car harder (rad/s^2 at full spin, x FeelSpin). 0 = no rotation push."),
    ("SpinMaxYawRate", 3.6, "Faster spin rotation allowed (rad/s; never above YawRateMax)."),
    ("SpinGripLoss", 0.7, "More sideways grip lost in a spin (0-1): the car slides further."),
    ("SpinThrustLoss", 0.35, "More thrust lost in a spin (0-1)."),
    ("SpinYawAuthorityLoss", 0.85, "Steering loses more of its hold on the yaw in a spin (0-1): the spin carries on more freely."),
    ("SpinHoldCap", 0.35, "A bigger wiggle is allowed without a gesture (largest spin amount outside a stab or power-brake window). 0 = only gestures spin."),
    # Who and when
    ("SpinTierFloor", 0.5, "Low-PI cars get more spin authority (share at TierStartPI; full at TierFullPI)."),
    ("SpinTouchScale", 0.5, "Touch players spin more readily (x spin target). 0 = no spins on touch."),
    ("SpinStartGraceSeconds", 3, "Longer no-spin grace after a start, reset or unanchor (seconds)."),
    ("SpinStartGraceMph", 38, "The grace also lasts until the car has gone faster than this (mph), whichever is later. 0 = time only."),
    ("SpinWarnLevel", 0.25, "The amber spin warning (HUD shift light 4) comes later, at a bigger spin amount."),
    # HUD (4.6)
    ("HudRedlineSweep", 0.87, "Redline sits further round the gauge arc (fraction of the sweep); the limiter is just past it."),
    ("HudShiftLeadSeconds", 0.25, "Shift light comes on earlier before a planned upshift (seconds of rpm climb). 0 = only at the shift point."),
    ("HudShiftMinFraction", 0.85, "Shift light only for upshifts planned nearer redline (fraction); 0 = also for cruise short-shifts."),
    ("HudWarmBandFraction", 0.12, "Warm light starts further below the flash point (fraction of redline). 0 = no warm stage."),
]

_EXOTIC_STRINGS = {
    "GearRatios": "3.15,2.18,1.66,1.33,1.10,0.93,0.80",
    "GearRatios_RaisingThisDoes": "Gear ratios, first to top, comma separated. Wider gaps = bigger rev drops and torque steps; the gear speeds come from each car's own top speed, so only the ratios between gears matter.",
    "TorqueCurve": "0:0.55,0.3:0.80,0.5:0.93,0.7:1,0.85:0.98,1:0.86",
    "TorqueCurve_RaisingThisDoes": "Engine torque shape as rpm/redline:torque pairs (peak 1). Raising a point gives more pull at that rpm; a flatter curve feels like a big lazy engine, a peaky one like a screamer.",
    "Notes": EXOTIC_NOTES,
}

_exotic_attributes = {}
for _name, _value, _raising in _EXOTIC:
    _exotic_attributes[_name] = _value
    _exotic_attributes[_name + "_RaisingThisDoes"] = _raising
_exotic_attributes.update(_EXOTIC_STRINGS)

INSTANCES = [
    {
        "parent": VEHICLES,
        "name": "Drivetrain",
        "class": "Folder",
        "attributes": {
            "Enabled": 1,
            "Enabled_RaisingThisDoes": "1 = classes with a folder here use the drivetrain; 0 = every class drives exactly as before (instant recovery).",
            "DrivetrainFeelInstalled": True,
            "Notes": ROOT_NOTES,
        },
        "children": [
            {"name": "exotic", "class": "Folder", "attributes": _exotic_attributes},
        ],
    },
]

ATTRIBUTES = []
