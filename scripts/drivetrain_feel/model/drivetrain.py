"""drivetrain_feel model part: the contract's drivetrain (CONTRACT sections 4, 5.1, 5.2) as amended by the fix spec
(reviews/15_fix_spec.md, sections B and C).

CONTRACT_DEFAULTS is section 4 verbatim (Config.Vehicles.Drivetrain.exotic). SPEC_DEFAULTS are the fix spec's section B
attributes, and PHYSICS_DEFAULTS the attributes physics/config.py adds beyond section 4. Profile is
Model.DrivetrainProfile and Gearbox.step is Model.StepDrivetrain, following physics/after/VehicleDynamics.lua for the
existing semantics and the fix spec for the new mechanisms (C5 drift hold, C6 FeelGearing envelope, C7 Overdrive exit and
TopGearOverspeed minimum, C9 digital cruise upshift).

Constants the code holds (not attributes) are in MODEL_CONSTANTS and listed in RESULTS.md.
"""
import math
import re

from today import G, MPH, clamp, lerp, smoothstep

CONTRACT_DEFAULTS = dict(
    # 4.1 feel dials
    Enabled=1, FeelWeight=1, FeelGearing=1, FeelAcceleration=1, FeelGrip=1, FeelSpin=1, FeelEngineBrake=1,
    # 4.2 engine and gearbox
    GearCount=7, GearRatios="3.15,2.18,1.66,1.33,1.10,0.93,0.80", IdleRpm=1100, RedlineRpm=8500, LimiterRpm=8600,
    TorqueCurve="0:0.55,0.3:0.80,0.5:0.93,0.7:1,0.85:0.98,1:0.86", GearTorqueExponent=0.8, TopGearOverspeed=1.06,
    LaunchRpmFraction=0.5,
    EngineRiseSeconds=0.06, EngineFallScale=1.5, ShiftRpmSeconds=0.05, ThrustSlipFlare=0.6,
    ShiftCutSeconds=0.06, ShiftCutTorque=0.45, ShiftBlendSeconds=0.06, DownshiftBlendSeconds=0.08, ShiftMinIntervalSeconds=0.25,
    UpshiftFlat=0.97, UpshiftPartLow=0.62, UpshiftPartHigh=0.85, UpshiftCruise=0.45, CruiseThrottleMin=0.05,
    UpshiftMinLand=0.33, LiftHoldSeconds=0.8,
    DownshiftBrakeLand=0.82, DownshiftCoastFraction=0.30, DownshiftCoastLand=0.65,
    KickdownThrottle=0.95, KickdownBelowFraction=0.45, KickdownLand=0.88, KickdownHoldSeconds=0.12,
    StopGearMph=3, LimiterOnSeconds=0.03, LimiterCutSeconds=0.045, LimiterHysteresisRpm=150,
    NeutralRevEnabled=1, NeutralRevTarget=1.02,
    # 4.3 traction, resistance, brakes, boost
    TractionG=1.15, TractionGripExponent=0.15, TractionTierBonusG=0.25, TierStartPI=250, TierFullPI=750,
    TractionAssist=0.35, SlideGripFraction=0.88,
    RollingDecel=0.8, RollingDecelPerStud=0.004, EngineBrakeDecel=1.5,
    BrakeDecel=70, BrakeForceExponent=0.35, BrakeFactorMin=0.75, BrakeFactorMax=1.4,
    BoostShapeEnabled=1, BoostShareMin=0.15, SpeedGuardStrength=2.0, SpeedGuardOverBoostTop=1.03, OverdriveEnabled=1,
    # 4.4 chassis and weight
    SteerRiseSeconds=0.2, SteerReturnRate=14, TouchSteerRate=10,
    YawOmega=9, YawDamping=0.75, YawWeightExponent=0.5, YawWeightMin=0.75, YawWeightMax=1.3, YawKinematicBelowMph=15,
    YawUnwindScale=2, YawRateMax=5,
    LateralCapG=3.4, LateralCapGripExponent=0.25, LateralCurveShape=1.4, YawCapMargin=0.9, GripRelaxStuds=2.0, DriftCapExempt=1,
    PitchDegreesPerG=2.4, PitchMaxDegrees=5, PitchOmega=9, PitchDamping=0.6, RollDegreesPerG=0.9, RollMaxDegrees=3,
    ImpactYawKick=0.6,
    # 4.5 spin-out
    SpinEnabled=1, SpinStabSeconds=0.4, SpinStabSteer=0.8, SpinAnalogRate=4, SpinWindowSeconds=0.7,
    PowerBrakeEnabled=1, PowerBrakeMinHold=0.3, PowerBrakeDumpSlip=0.5,
    SpinBelowMph=25, SpinFadeMph=12, SpinSteerStart=0.6, SpinSteerWidth=0.35, SpinSlipStart=0.12, SpinSlipWidth=0.25,
    SpinBuildRate=3.5, SpinDecayRate=2.5, SpinCatchRate=8, SpinSettleSeconds=0.3,
    SpinYawAccel=7, SpinMaxYawRate=3.6, SpinGripLoss=0.7, SpinThrustLoss=0.35, SpinHoldCap=0.35,
    SpinTierFloor=0.5, SpinTouchScale=0.5, SpinStartGraceSeconds=3, SpinStartGraceMph=38, SpinWarnLevel=0.25,
    # 4.6 HUD
    HudRedlineSweep=0.87, HudShiftLeadSeconds=0.25, HudShiftMinFraction=0.85, HudWarmBandFraction=0.12,
)

# Fix spec section B: new attributes on Drivetrain.exotic (switches are numbers 0/1).
SPEC_DEFAULTS = dict(
    SpinStabNeedsFlick=1, SpinFlickSeconds=0.15, SpinStabDumpSlip=0.3,
    DriftExemptGain=2, DriftYawExempt=1, DriftHoldDownshift=1, DriftAssistPlateauShare=0.9,
    DigitalCruiseEnabled=1, DigitalDutySeconds=1.5, DigitalCruiseDutyMax=0.7, DigitalCruiseSteadyMph=3,
    DigitalCruiseUpshift=0.6, DigitalCruiseLand=0.5,
)

# Attributes physics/config.py has beyond CONTRACT section 4.
PHYSICS_DEFAULTS = dict(SpinYawAuthorityLoss=0.85)

SWITCHES = ("Enabled", "NeutralRevEnabled", "BoostShapeEnabled", "OverdriveEnabled", "DriftCapExempt", "SpinEnabled",
            "PowerBrakeEnabled", "SpinStabNeedsFlick", "DriftHoldDownshift", "DigitalCruiseEnabled")

# Code constants (not attributes), as in the physics after-source.
MODEL_CONSTANTS = dict(
    SlideSmoothWidth=0.6,       # the slide factor reaches SlideGripFraction at slip 0.6 (smoothstep(slip / 0.6))
    LugFraction=0.2,            # VehicleDynamics LUG_FRACTION: below this ratio with throttle held, step down one gear
    SpinYawGate=0.15, SpinYawGateWidth=0.35,   # DrivingClient SPIN_YAW_GATE: ss((|r| - 0.15) / 0.35) in the spin target
    YawOmegaCap=60,             # R13 #6: the steer spring omega is capped (effectively kinematic above it)
    SelectGearFraction=0.9,     # DrivetrainSelectGear: lowest gear that puts the speed at or under 0.9 of its redline
)


# VehicleDynamics DRIVETRAIN_NUMBERS, copied as physics/after has it (read 2026-10-20): (attribute, default, minimum,
# maximum). rebuildTuning clamps every number to its range; a missing or non-number value takes the default first. The
# defaults are physics' fallbacks (the shipped Drivetrain.exotic values, so the proposal where it differs from section
# 4); the model always has a value from the defaults above, so here they only replace a non-number override.
DRIVETRAIN_NUMBERS = (
    ("FeelWeight", 1, 0, 2.5), ("FeelGearing", 1, 0, 2), ("FeelAcceleration", 1, 0.5, 1.5), ("FeelGrip", 1, 0.6, 1.6),
    ("FeelSpin", 1, 0, 2.5), ("FeelEngineBrake", 1, 0, 2),
    ("GearCount", 7, 1, 9), ("IdleRpm", 1100, 300, 4000), ("RedlineRpm", 8500, 2000, 20000), ("LimiterRpm", 8600, 2000, 24000),
    ("GearTorqueExponent", 0.8, 0, 2), ("TopGearOverspeed", 1.06, 1.02, 1.5), ("LaunchRpmFraction", 0.5, 0, 1),
    ("EngineRiseSeconds", 0.06, 0.01, 1), ("EngineFallScale", 1.5, 0.2, 5), ("ShiftRpmSeconds", 0.05, 0.005, 1),
    ("ThrustSlipFlare", 0.6, 0, 2), ("ShiftCutSeconds", 0.06, 0, 0.5), ("ShiftCutTorque", 0.45, 0, 1),
    ("ShiftBlendSeconds", 0.06, 0, 0.5), ("DownshiftBlendSeconds", 0.08, 0.01, 0.5), ("ShiftMinIntervalSeconds", 0.25, 0.05, 2),
    ("UpshiftFlat", 0.97, 0.5, 1), ("UpshiftPartLow", 0.62, 0.3, 1), ("UpshiftPartHigh", 0.85, 0.3, 1),
    ("UpshiftCruise", 0.45, 0.2, 1), ("CruiseThrottleMin", 0.05, 0, 0.3), ("UpshiftMinLand", 0.33, 0, 0.9),
    ("LiftHoldSeconds", 0.8, 0, 3), ("DigitalDutySeconds", 1.5, 0.05, 10), ("DigitalCruiseDutyMax", 0.7, 0, 1),
    ("DigitalCruiseSteadyMph", 3, 0, 50), ("DigitalCruiseUpshift", 0.6, 0.2, 1), ("DigitalCruiseLand", 0.5, 0, 0.95),
    ("DownshiftBrakeLand", 0.82, 0.3, 1), ("DownshiftCoastFraction", 0.3, 0, 0.9),
    ("DownshiftCoastLand", 0.65, 0.3, 1), ("KickdownThrottle", 0.95, 0.5, 1), ("KickdownBelowFraction", 0.45, 0, 1),
    ("KickdownLand", 0.88, 0.3, 1), ("KickdownHoldSeconds", 0.12, 0, 1), ("StopGearMph", 3, 0, 20),
    ("LimiterOnSeconds", 0.03, 0.005, 0.5), ("LimiterCutSeconds", 0.045, 0, 0.5), ("LimiterHysteresisRpm", 150, 0, 2000),
    ("NeutralRevTarget", 1.02, 0, 1.2),
    ("TractionG", 1.15, 0.3, 4), ("TractionGripExponent", 0.15, 0, 1), ("TractionTierBonusG", 0.25, 0, 2),
    ("TierStartPI", 250, 0, 2000), ("TierFullPI", 750, 0, 2000), ("TractionAssist", 0.35, 0, 1), ("SlideGripFraction", 0.88, 0.3, 1),
    ("RollingDecel", 0.8, 0, 10), ("RollingDecelPerStud", 0.004, 0, 0.1), ("EngineBrakeDecel", 1.5, 0, 20),
    ("BrakeDecel", 70, 5, 200), ("BrakeForceExponent", 0.35, 0, 2), ("BrakeFactorMin", 0.75, 0.1, 3), ("BrakeFactorMax", 1.4, 0.1, 3),
    ("BoostShareMin", 0.15, 0, 1), ("SpeedGuardStrength", 2, 0, 20), ("SpeedGuardOverBoostTop", 1.03, 1, 1.5),
    ("SteerRiseSeconds", 0.12, 0, 1), ("SteerReturnRate", 25, 1, 100), ("TouchSteerRate", 10, 1, 100),
    ("YawOmega", 20, 1, 60), ("YawDamping", 0.75, 0.1, 2), ("YawWeightExponent", 0.5, 0, 2), ("YawWeightMin", 0.75, 0.2, 2),
    ("YawWeightMax", 1.3, 0.2, 3), ("YawKinematicBelowMph", 15, 0, 80), ("YawUnwindScale", 2, 0.5, 5), ("YawRateMax", 5, 0.5, 5),
    ("LateralCapG", 3.4, 0.5, 20), ("LateralCapGripExponent", 0.25, 0, 1), ("LateralCurveShape", 1.4, 1, 1.9),
    ("YawCapMargin", 0.9, 0.3, 3), ("GripRelaxStuds", 2, 0, 20),
    ("DriftExemptGain", 4, 0, 10), ("DriftYawExempt", 1, 0, 1), ("DriftAssistPlateauShare", 0.9, 0, 1),
    ("PitchDegreesPerG", 2.4, 0, 10), ("PitchMaxDegrees", 5, 0, 15), ("PitchOmega", 9, 1, 40), ("PitchDamping", 0.6, 0.1, 2),
    ("RollDegreesPerG", 0.9, -5, 5), ("RollMaxDegrees", 3, 0, 10), ("ImpactYawKick", 0.6, 0, 5),
    ("SpinStabSeconds", 0.4, 0, 2), ("SpinStabSteer", 0.8, 0, 1), ("SpinAnalogRate", 4, 0.5, 50), ("SpinWindowSeconds", 0.9, 0, 5),
    ("PowerBrakeMinHold", 0.3, 0, 5), ("PowerBrakeDumpSlip", 0.5, 0, 2), ("SpinFlickSeconds", 0.15, 0, 2), ("SpinStabDumpSlip", 0.3, 0, 2),
    ("SpinBelowMph", 30, 0, 100), ("SpinFadeMph", 12, 0.5, 100), ("SpinSteerStart", 0.6, 0, 1), ("SpinSteerWidth", 0.35, 0.01, 1),
    ("SpinSlipStart", 0.04, 0, 2), ("SpinSlipWidth", 0.08, 0.01, 2),
    ("SpinBuildRate", 6, 0, 30), ("SpinDecayRate", 2.5, 0, 30), ("SpinCatchRate", 8, 0, 60), ("SpinSettleSeconds", 0.3, 0, 3),
    ("SpinYawAccel", 25, 0, 40), ("SpinMaxYawRate", 3.6, 0, 5), ("SpinGripLoss", 0.85, 0, 1), ("SpinThrustLoss", 0.35, 0, 1),
    ("SpinYawAuthorityLoss", 0.85, 0, 1), ("SpinHoldCap", 0.35, 0, 1), ("SpinTierFloor", 0.8, 0, 1), ("SpinTouchScale", 0.5, 0, 2),
    ("SpinStartGraceSeconds", 3, 0, 30), ("SpinStartGraceMph", 38, 0, 200), ("SpinWarnLevel", 0.25, 0, 1),
    ("HudRedlineSweep", 0.87, 0.5, 1), ("HudShiftLeadSeconds", 0.25, 0, 2), ("HudShiftMinFraction", 0.85, 0, 1), ("HudWarmBandFraction", 0.12, 0, 0.5),
)
DEFAULT_RATIOS = "3.15,2.18,1.66,1.33,1.10,0.93,0.80"                        # DRIVETRAIN_DEFAULT_RATIOS
DEFAULT_CURVE = "0:0.55,0.3:0.80,0.5:0.93,0.7:1,0.85:0.98,1:0.86"          # DRIVETRAIN_DEFAULT_CURVE

_LUA_DECIMAL = re.compile(r"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$")
_LUA_HEX = re.compile(r"^[+-]?0[xX][0-9a-fA-F]+$")


def is_number(value):
    """typeof(value) == "number" and value == value (a bool is not a number in Luau)."""
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value == value


def lua_tonumber(token):
    """tonumber() on one parser token: decimal or hex text, else None (Python-only forms such as '1_0' or 'inf' are
    rejected as Luau rejects them)."""
    if _LUA_DECIMAL.match(token):
        return float(token)
    if _LUA_HEX.match(token):
        return float(int(token, 16))
    return None


def switch_on(value, fallback=True):
    """switchOn: a number is on at >= 0.5 (NaN is off), a boolean as is, anything else (missing) the fallback."""
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value == value and value >= 0.5
    return fallback


def parse_ratios(text):
    """parseRatios: tokens split on commas and whitespace; keeps the first 9 numbers in (0, 100), sorts them descending
    and drops any ratio within 0.5% of the one kept before it."""
    out = []
    for token in re.findall(r"[^,\s]+", text):
        value = lua_tonumber(token)
        if value is not None and value == value and 0 < value < 100 and len(out) < 9:
            out.append(value)
    out.sort(reverse=True)
    kept = []
    for value in out:
        if not kept or value < kept[-1] * 0.995:
            kept.append(value)
    return kept


def parse_curve(text):
    """parseCurve: 'x:y' pairs (characters -, digits and .), at most 32, x clamped to [0, 1.5] and y to [0, 2],
    insertion-sorted by x (stable, so equal x keep their order)."""
    points = []
    for a, b in re.findall(r"([-0-9.]+)\s*:\s*([-0-9.]+)", text):
        x, y = lua_tonumber(a), lua_tonumber(b)
        if x is not None and y is not None and len(points) < 32:
            x, y = clamp(x, 0, 1.5), clamp(y, 0, 2)
            at = len(points)
            while at > 0 and points[at - 1][0] > x:
                at -= 1
            points.insert(at, (x, y))
    return points


def torque_at(points, x):
    """curveAt."""
    if not points:
        return 1.0
    if x <= points[0][0]:
        return points[0][1]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x <= x1:
            alpha = (x - x0) / (x1 - x0) if x1 > x0 else 1.0
            return y0 + (y1 - y0) * alpha
    return points[-1][1]


class Settings:
    """The class folder attributes plus the dial mappings (effective values). One object per tuning variant."""

    def __init__(self, overrides=None, constants=None):
        raw = dict(CONTRACT_DEFAULTS)
        raw.update(SPEC_DEFAULTS)
        raw.update(PHYSICS_DEFAULTS)
        raw.update(overrides or {})
        self.raw = raw
        a = dict(raw)
        # rebuildTuning: every number clamped to its DRIVETRAIN_NUMBERS range, the switches through switchOn, then the
        # cross-clamps, the strings parsed (default text when the parse leaves too little) and the gear count
        for name, default, lo, hi in DRIVETRAIN_NUMBERS:
            value = raw.get(name)
            a[name] = clamp(value if is_number(value) else default, lo, hi)
        self.switches = {name: switch_on(raw.get(name), True) for name in SWITCHES}
        a["LimiterRpm"] = clamp(a["LimiterRpm"], a["RedlineRpm"], a["RedlineRpm"] * 1.2)
        a["IdleRpm"] = min(a["IdleRpm"], a["RedlineRpm"] * 0.5)
        a["UpshiftPartHigh"] = max(a["UpshiftPartHigh"], a["UpshiftPartLow"])
        a["TierFullPI"] = max(a["TierFullPI"], a["TierStartPI"] + 1)
        a["BrakeFactorMax"] = max(a["BrakeFactorMax"], a["BrakeFactorMin"])
        a["YawWeightMax"] = max(a["YawWeightMax"], a["YawWeightMin"])
        a["SpinMaxYawRate"] = min(a["SpinMaxYawRate"], a["YawRateMax"])
        self.a = a
        self.k = dict(MODEL_CONSTANTS)
        self.k.update(constants or {})
        ratio_text = raw["GearRatios"] if isinstance(raw.get("GearRatios"), str) else DEFAULT_RATIOS
        ratios = parse_ratios(ratio_text) or parse_ratios(DEFAULT_RATIOS)
        curve_text = raw["TorqueCurve"] if isinstance(raw.get("TorqueCurve"), str) else DEFAULT_CURVE
        self.curve = parse_curve(curve_text)
        if len(self.curve) < 2:
            self.curve = parse_curve(DEFAULT_CURVE)
        self.gears = int(clamp(math.floor(a["GearCount"] + 0.5), 1, len(ratios)))   # tuning.Gears
        self.ratios = ratios[:self.gears]
        fw, fg = a["FeelWeight"], a["FeelGearing"]
        # dial mappings (physics NOTES are authoritative; these mirror the after-source and the fix spec)
        self.gearing = fg
        self.curve_depth = min(fg, 1.0)                                          # torque curve flattens toward 1 below 1
        self.cut_seconds = a["ShiftCutSeconds"] * fg                             # time-like
        self.blend_seconds = a["ShiftBlendSeconds"] * fg
        self.cut_torque = clamp(1 - (1 - a["ShiftCutTorque"]) * fg, 0, 1)       # depth scaled by the dial
        self.rev_drop = clamp(a["ShiftRpmSeconds"] / max(fg, 0.05), 0.005, 1)   # rev-drop time: faster at higher gearing
        soften = max(min(fw, 1.0), 0.05)
        self.steer_build = 1 / max(a["SteerRiseSeconds"] * fw, 0.001)           # keyboard build rate (lock per second)
        self.steer_return = a["SteerReturnRate"] / soften                        # below 1 the return sharpens
        self.touch_rate = a["TouchSteerRate"] / soften
        self.grip_relax = a["GripRelaxStuds"] * fw                               # 0 = no lag (today)
        self.yaw_kinematic = fw <= 0                                             # 0 = kinematic yaw (today)
        self.weight_dial = fw
        self.hold_cap = min(a["SpinHoldCap"] * a["FeelSpin"], 1.0)              # C4 (F7)
        self.warn_level = max(a["SpinWarnLevel"], self.hold_cap + 0.05)          # C4 (R14 #14)

    def on(self, name):
        if name in self.switches:
            return self.switches[name]
        return self.a[name] >= 0.5


class Profile:
    """Model.DrivetrainProfile(vehicle, stats, balance, maxMph): per car, cached, rebuilt on change."""

    def __init__(self, today, settings, pi):
        T, a, s = today, settings.a, settings
        self.s = s
        self.R, self.I, self.limiter_rpm = a["RedlineRpm"], a["IdleRpm"], a["LimiterRpm"]   # IdleRpm <= 0.5 R (Settings)
        self.ratios = s.ratios
        self.n = len(self.ratios)
        self.Vt = max(T.solve_top(), 5)                                          # today's drag-limited top
        self.Vb = max(T.solve_top(extra=T.boost_accel), self.Vt) if T.boost_power > 0 else self.Vt
        over = a["TopGearOverspeed"]
        self.over = over
        r1, rtop = self.ratios[0], self.ratios[-1]
        self.Vg = [self.Vt * over * rtop / r for r in self.ratios]               # gear redline speeds (mph)
        # C6: MultBase from GearTorqueExponent only; FeelGearing scales the step around a fixed speed envelope
        self.mult_base = [(r / r1) ** a["GearTorqueExponent"] for r in self.ratios]
        self.mid = self.mid_speeds(a)
        self.gearing = s.gearing
        self.A1 = T.base_forward * T.engine_factor * T.weight_factor * T.bal["Acceleration"] * a["FeelAcceleration"]
        self.Rb, self.Rs = a["RollingDecel"], a["RollingDecelPerStud"]
        tier = smoothstep((pi - a["TierStartPI"]) / (a["TierFullPI"] - a["TierStartPI"]))   # TierFullPI >= start + 1
        self.tier = tier
        grip_ratio = max(T.stats["LateralGrip"], 0.001) / 50
        grip_term = clamp(grip_ratio ** a["TractionGripExponent"], 0.9, 1.15)
        # R14 #13: the grip term scales the tier bonus too, as physics does
        self.a_trac = (a["TractionG"] + a["TractionTierBonusG"] * tier) * G * grip_term * a["FeelGrip"]
        self.slide_fraction, self.assist = a["SlideGripFraction"], a["TractionAssist"]
        self.slide_width = settings.k["SlideSmoothWidth"]
        # C6: Kd from the thrust top gear delivers at Vt (traction limit and slide factor), so top speed holds at any dial
        top_thrust_at_vt = self.delivered(self.A1 * self.mult(self.n, self.Vt) * self.torque(1 / over))
        self.Kd = max(top_thrust_at_vt - self.Rb - self.Rs * self.Vt / MPH, 0.5) / (self.Vt ** 2)
        self.boost_today = T.boost_accel if T.boost_power > 0 else 0.0
        share = 1.0
        if s.on("BoostShapeEnabled") and self.boost_today > 0:
            # Overdrive is in the Vb solve: past top-gear redline while boosting, thrust holds at tau(1) x mult_top
            x_vb = self.Vb / self.Vg[-1]
            engine = self.delivered(self.A1 * self.mult(self.n, self.Vb) * self.torque(min(x_vb, 1.0)))
            if x_vb >= 1 and not s.on("OverdriveEnabled"):
                engine *= a["LimiterOnSeconds"] / max(a["LimiterOnSeconds"] + a["LimiterCutSeconds"], 0.001)
            need = self.Kd * self.Vb ** 2 + self.Rb + self.Rs * self.Vb / MPH
            share = clamp((need - engine) / self.boost_today, a["BoostShareMin"], 1)
        self.share_hi = share
        # Dynamics WeightReference, BrakingForceReference and BrakeWeightExponent (config, with physics' fallbacks and clamps)
        w_ratio = T.w_ref / max(T.stats["Weight"], 1)
        brake_v2 = (a["BrakeDecel"] * clamp((max(T.stats["BrakingForce"], 0.001) / T.brake_ref) ** a["BrakeForceExponent"], a["BrakeFactorMin"], a["BrakeFactorMax"])
                    * clamp(w_ratio ** T.brake_weight_exp, 0.8, 1.2) * T.bal["Braking"])
        self.brake_v2 = brake_v2
        # R14 #12: physics form, FeelWeight 0 = today's brake, clamped to [0.35 min, max]
        brake = lerp(T.brake, brake_v2, s.weight_dial)
        self.brake = clamp(brake, 0.35 * min(T.brake, brake_v2), max(T.brake, brake_v2))
        self.guard_mph = min(T.max_mph, a["SpeedGuardOverBoostTop"] * self.Vb)
        # chassis numbers
        self.yaw_omega = a["YawOmega"] * clamp(w_ratio ** a["YawWeightExponent"], a["YawWeightMin"], a["YawWeightMax"])
        self.cap_base = a["LateralCapG"] * G * clamp(grip_ratio ** a["LateralCapGripExponent"], 0.85, 1.2) * a["FeelGrip"]
        self.spin_tier = a["SpinTierFloor"] + (1 - a["SpinTierFloor"]) * tier

    def mid_speeds(self, a):
        """Gear mid-band speeds for the C6 envelope (physics MidMph): halfway between the previous gear's redline speed
        (0 for first) and this gear's."""
        return [0.5 * ((self.Vg[g - 1] if g > 0 else 0.0) + self.Vg[g]) for g in range(self.n)]

    def envelope(self, mph):
        mids, base = self.mid, self.mult_base
        if mph <= mids[0]:
            return base[0]
        for i in range(1, self.n):
            if mph <= mids[i]:
                return base[i - 1] + (base[i] - base[i - 1]) * (mph - mids[i - 1]) / max(mids[i] - mids[i - 1], 1e-9)
        return base[-1]

    def mult(self, gear, mph):
        """C6: mult = env(v) + (MultBase[g] - env(v)) x FeelGearing (gear is 1-based)."""
        env = self.envelope(mph)
        return max(env + (self.mult_base[gear - 1] - env) * self.gearing, 0.0)

    def torque(self, x):
        """profileTorque: FeelGearing below 1 flattens the curve toward 1 (CurveDepth = min(FeelGearing, 1))."""
        return 1 + (torque_at(self.s.curve, x) - 1) * self.s.curve_depth

    def delivered(self, a_raw, dump=0.0):
        """Thrust after the traction limit and the sliding-grip factor (StepDrivetrain's thrust before cuts)."""
        slip = max(0.0, a_raw / self.a_trac - 1) * (1 - self.assist) + dump
        return min(a_raw, self.a_trac) * (1 - (1 - self.slide_fraction) * smoothstep(slip / self.slide_width))

    def share(self, mph, settings):
        if not settings.on("BoostShapeEnabled") or self.Vb <= 1:
            return 1.0
        return 1 - (1 - self.share_hi) * smoothstep(max(mph, 0) / self.Vb)

    def a_cap(self, today, speed_mph):
        """chassis.LateralCap: LateralCapBase x DownforceFactor x Balance.Grip."""
        return self.cap_base * today.downforce(speed_mph) * today.bal["Grip"]

    def select_gear(self, mph, fraction=0.9):
        """Model.DrivetrainSelectGear: the lowest gear that puts this speed at or under 0.9 of its redline."""
        for g in range(self.n):
            if mph <= self.Vg[g] * fraction:
                return g + 1
        return self.n


class Gearbox:
    """state.Gearbox plus Model.StepDrivetrain. Changed in place, no per-frame allocation in the Luau version."""

    def __init__(self, profile, settings, today):
        self.P, self.s, self.T = profile, settings, today
        # (t, kind, from, to, mph). kind: Up, Down and Launch are beginShift / LaunchGearbox events (ShiftRevision, the
        # cues); Force is a gear the step sets without one (R, 1st below StopGearMph, the select from N) and is never a
        # shift in any count
        self.shifts = []
        self.t = 0.0
        self.lim_bounces = 0
        self.cruise_ups = 0
        self.strength = 0.0       # box.LastStrength (kept across resets)
        self.boost_share = 1.0    # out.BoostShare
        self.reset(0.0)

    def reset(self, forward_mph=0.0, neutral=False):
        """Model.ResetGearbox: N (neutral), first gear, or the gear that matches the speed when moving; idle or road rpm,
        no cut, no limiter, LiftClock 10, Duty 0 and SteadyMph at the speed."""
        P, a = self.P, self.s.a
        gear = 1
        if neutral:
            gear = 0
        elif forward_mph > a["StopGearMph"]:
            gear = P.select_gear(forward_mph, self.s.k["SelectGearFraction"])
        self.gear = gear
        self.rpm = P.I
        if gear >= 1:
            self.rpm = clamp(forward_mph / P.Vg[gear - 1] * P.R, P.I, P.limiter_rpm)
        self.since_shift = 10.0
        self.shift_kind = None
        self.lim_state, self.lim_clock = 0, 0.0
        self.lift_clock, self.kick_clock = 10.0, 0.0
        self.overdrive = False
        self.duty, self.steady_mph = 0.0, forward_mph                           # C9: reset with the gearbox
        self.ws_eff = 0.0
        self.k_shift = self.k_lim = 1.0
        self.ratio = 0.0
        self.load = 0.0
        self.drive_thrust = 0.0
        self.dt = 1 / 60

    def place(self, mph):
        """Start mid-speed: exactly Model.ResetGearbox at that speed (the ResetPending path)."""
        self.reset(mph)

    def launch(self, strength=1.0):
        """Model.LaunchGearbox: first gear from N or a power-brake hold, keeping the revved rpm, Duty and the limiter."""
        self._log("Launch", 1, 0.0)
        self.gear, self.since_shift, self.shift_kind = 1, 0.0, "Launch"
        self.strength = clamp(strength, 0.0, 1.0)

    def _log(self, kind, to, mph):
        self.shifts.append((self.t, kind, self.gear, to, mph))

    def _begin(self, gear, kind, mph, strength):
        """beginShift: the gearing dial scales how hard an Up or Down shift is felt (0 = CVT-smooth)."""
        self._log(kind, gear, mph)
        self.gear, self.since_shift, self.shift_kind = gear, 0.0, kind
        self.strength = clamp(strength * min(self.s.gearing, 1.0), 0.0, 1.0)

    def _step_limiter(self, over, dt):
        """stepLimiter: drive for LimiterOnSeconds, then cut for LimiterCutSeconds; returns the share of the frame cut."""
        a = self.s.a
        on, cut_s = a["LimiterOnSeconds"], a["LimiterCutSeconds"]
        if not over:
            self.lim_state, self.lim_clock = 0, 0.0
            return 0.0
        if self.lim_state == 0:
            self.lim_state, self.lim_clock = 1, 0.0
        remaining, cut = dt, 0.0
        for _ in range(16):
            if remaining <= 0:
                break
            if self.lim_state == 1:
                use = min(remaining, max(on - self.lim_clock, 0.0))
                self.lim_clock += use
                remaining -= use
                if self.lim_clock >= on:
                    if cut_s <= 0:
                        break
                    self.lim_state, self.lim_clock = 2, 0.0
                    self.lim_bounces += 1
            else:
                use = min(remaining, max(cut_s - self.lim_clock, 0.0))
                self.lim_clock += use
                remaining -= use
                cut += use
                if self.lim_clock >= cut_s:
                    self.lim_state, self.lim_clock = 1, 0.0
        if dt > 0:
            return clamp(cut / dt, 0, 1)
        return 1.0 if self.lim_state == 2 else 0.0

    @staticmethod
    def _cut_integral(t, cut, blend, c):
        if t <= cut:
            return c * t
        u = t - cut
        if u < blend:
            return c * cut + c * u + (1 - c) * u * u / (2 * blend)
        return c * cut + c * blend + (1 - c) * blend * 0.5 + (u - blend)

    def upshift_point(self, thr):
        a = self.s.a
        if thr >= 0.9:
            return a["UpshiftFlat"]
        if thr >= 0.3:
            return a["UpshiftPartLow"] + (a["UpshiftPartHigh"] - a["UpshiftPartLow"]) * (thr - 0.3) / 0.6
        return a["UpshiftCruise"]

    def step(self, car, throttle, forward_speed, horizontal, drift_blend, spin, extra_slip, power_brake_held, intent,
             boost_applied, analog, dt):
        """Returns (acc, mode, snap, accelerating, braking, drive_thrust). Mirrors Model.StepDrivetrain line by line.
        horizontal is |v_h| in studs/s; boost_applied is last frame's (Drivetrain.BoostApplied); dt is the frame already
        clamped to [0, 0.1] (StepLongitudinal clamps it before StepDrivetrain). Also sets boost_share (out.BoostShare)."""
        P, s, a, T, k = self.P, self.s, self.s.a, self.T, self.s.k
        self.t += dt
        self.dt = dt
        fwd_mph = forward_speed * MPH
        abs_mph = abs(fwd_mph)
        dz = T.deadzone
        spin = clamp(spin, 0.0, 1.0)
        db = clamp(drift_blend, 0.0, 1.0)
        n, Vg, ratios, R, I = P.n, P.Vg, P.ratios, P.R, P.I
        if self.gear > n:
            self.gear = n
        # ---- mode: today's rules; auto-hold never snaps while the car spins or slides sideways
        acc = -T.aero(fwd_mph)
        mode, braking, accelerating, snap = "Coasting", False, False, False
        driven = 0.0
        if throttle > dz:
            car.hold = 0.0
            if fwd_mph < -T.stop_mph:
                mode, braking = "Braking", True
            else:
                mode, accelerating, driven = "Forward", True, throttle
        elif throttle < -dz:
            if fwd_mph > T.stop_mph:
                car.hold = 0.0
                mode, braking = "Braking", True
            elif abs_mph <= T.stop_mph:
                car.hold += dt
                if car.hold >= T.reverse_delay:
                    mode, accelerating = "Reverse", True
                    acc -= T.reverse * abs(throttle)
                else:
                    mode, snap = "Stopped", True
            else:
                mode, accelerating = "Reverse", True
                ratio_r = clamp(abs(min(fwd_mph, 0)) / T.reverse_max_mph, 0, 1)
                acc -= T.reverse * abs(throttle) * (1 - ratio_r) ** T.reverse_curve_exp
        else:
            car.hold = 0.0
            if abs_mph <= T.auto_hold_mph and spin <= 0.05 and horizontal <= 4:
                mode, snap = "Stopped", True
        # ---- gear: R while reversing, 1st below StopGearMph, else the auto brain
        gear = self.gear
        if mode == "Reverse":
            gear = -1
        elif gear == -1 and fwd_mph < -T.stop_mph and mode != "Braking":
            gear = -1
        elif fwd_mph < a["StopGearMph"]:
            gear = 1
        elif gear < 1:
            gear = P.select_gear(fwd_mph, k["SelectGearFraction"])
        if gear != self.gear:
            self._log("Force", gear, fwd_mph)                                   # no beginShift: no event, no cue
        self.gear = gear
        road = max(fwd_mph, 0.0)
        h_mph = horizontal * MPH
        road += (h_mph - road) * db                                             # rpm from |v_h| blended by DriftBlend
        ratio = road / Vg[gear - 1] if gear >= 1 else 0.0
        positive = max(throttle, 0.0)
        self.lift_clock = 0.0 if positive < a["CruiseThrottleMin"] else self.lift_clock + dt
        self.kick_clock = self.kick_clock + dt if positive >= a["KickdownThrottle"] else 0.0
        # C9: throttle duty and steady-speed averages (every frame while active)
        f = 1 - math.exp(-dt / a["DigitalDutySeconds"])                         # >= 0.05 (Settings)
        self.duty += (positive - self.duty) * f
        self.steady_mph += (fwd_mph - self.steady_mph) * f
        if gear >= 1 and fwd_mph >= a["StopGearMph"] and self.since_shift >= a["ShiftMinIntervalSeconds"]:
            # no shifting mid-drift or mid-spin, except an upshift off the limiter (and the C5 drift downshift)
            drift_hold = db > 0.3
            hold = drift_hold or spin > 0.1
            shifted = False
            if gear < n:
                up = ratio >= 1
                if not up and not hold and driven > 0:
                    if driven >= 0.9:
                        up = ratio >= a["UpshiftFlat"]                           # full throttle: never held by LiftHold
                    elif self.lift_clock >= a["LiftHoldSeconds"]:
                        if driven >= 0.3:
                            up = ratio >= self.upshift_point(driven)
                        elif driven > a["CruiseThrottleMin"]:
                            up = ratio >= a["UpshiftCruise"] and ratio * ratios[gear] / ratios[gear - 1] >= a["UpshiftMinLand"]
                strength = 1.0 if driven >= 0.9 else 0.3 + 0.7 * driven
                if not up and not hold and s.on("DigitalCruiseEnabled") and not analog:
                    # C9: keyboard/touch cruise short-shift (LiftHoldSeconds does not block it). analog is the latched
                    # last throttle device (Drivetrain.AnalogInput)
                    land = ratio * ratios[gear] / ratios[gear - 1]
                    if (a["CruiseThrottleMin"] < self.duty <= a["DigitalCruiseDutyMax"]
                            and abs(fwd_mph - self.steady_mph) <= a["DigitalCruiseSteadyMph"]
                            and ratio >= a["DigitalCruiseUpshift"]
                            and land >= max(a["DigitalCruiseLand"], a["UpshiftMinLand"])):
                        up, strength = True, 0.3 + 0.7 * self.duty
                        self.cruise_ups += 1
                if up:
                    self._begin(gear + 1, "Up", fwd_mph, strength)
                    shifted = True
            if not shifted and gear > 1:
                target = gear
                if not hold:
                    land = ratio * ratios[gear - 2] / ratios[gear - 1]
                    if braking and fwd_mph > 0:
                        if land <= a["DownshiftBrakeLand"]:
                            target = gear - 1
                    elif driven <= a["CruiseThrottleMin"]:
                        if ratio < a["DownshiftCoastFraction"] and land <= a["DownshiftCoastLand"]:
                            target = gear - 1
                    elif driven >= a["KickdownThrottle"] and self.kick_clock >= a["KickdownHoldSeconds"] and ratio < a["KickdownBelowFraction"]:
                        for lower in range(1, gear):
                            if ratio * ratios[lower - 1] / ratios[gear - 1] <= a["KickdownLand"]:
                                target = lower
                                break
                    elif ratio < k["LugFraction"] and land <= a["DownshiftCoastLand"]:
                        target = gear - 1
                elif drift_hold and spin <= 0.1 and s.on("DriftHoldDownshift"):
                    # C5: one downshift at a time inside the drift hold, by |v_h|, when the lower gear lands at or below
                    # DownshiftBrakeLand (no cut; upshifts stay blocked)
                    if h_mph / Vg[gear - 2] <= a["DownshiftBrakeLand"]:
                        target = gear - 1
                if target < gear:
                    self._begin(target, "Down", fwd_mph, 0.5)
            gear = self.gear
            ratio = road / Vg[gear - 1]
        rpm_road = ratio * R
        # Overdrive (F9): boosting past top-gear redline pins rpm at redline with no limiter; held while still above
        # top-gear redline after the boost ends (0.98 hysteresis)
        overdrive = (s.on("OverdriveEnabled") and gear >= 1 and gear == n and (boost_applied or self.overdrive)
                     and ratio >= (0.98 if self.overdrive else 1.0))
        self.overdrive = overdrive
        # ---- engine rpm target: road rpm, a clutch-slip launch in first, a free rev while spinning
        rpm_base = rpm_road
        if gear == -1:
            rpm_base = I + (0.55 * R - I) * clamp(abs_mph / 40, 0, 1)
        elif gear >= 1:
            launch = 1.0 if power_brake_held else driven
            if gear == 1 and launch > 0:
                rpm_base = max(rpm_base, I + launch * (a["LaunchRpmFraction"] * R - I))
            if spin > 0:
                rpm_base += (max(0.85 * R * driven, I) - rpm_base) * smoothstep(spin / 0.3)
        rpm_base = max(rpm_base, I)
        # ---- thrust (throttle applied once, linear), traction-limited, slide loss when the thrust slips
        raw = 0.0
        if driven > 0 and gear >= 1:
            raw = P.A1 * P.mult(gear, road) * P.torque((R if overdrive else self.rpm) / R) * driven
        trac = P.a_trac
        slip = 0.0
        if mode == "Forward" and fwd_mph >= -1 and intent == 1:
            slip = max(raw / trac - 1, 0.0) * (1 - a["TractionAssist"]) + max(extra_slip, 0.0)
        thrust = min(raw, trac)
        if slip > 0:
            thrust *= 1 - (1 - a["SlideGripFraction"]) * smoothstep(slip / k["SlideSmoothWidth"])
        # ---- limiter (never in Overdrive) and the upshift cut, both time-weighted across the frame
        hyst = a["LimiterHysteresisRpm"]
        over = (not overdrive) and gear >= 1 and driven > 0 and rpm_road >= ((R - hyst) if self.lim_state != 0 else R)
        lim_cut = self._step_limiter(over, dt)
        cut_s, blend_s, c = s.cut_seconds, s.blend_seconds, s.cut_torque
        shift_factor, load_factor, shift_cut = 1.0, 1.0, 0.0
        if self.shift_kind == "Up" and self.since_shift < cut_s + blend_s:
            frm = self.since_shift
            if dt > 0:
                shift_factor = (self._cut_integral(frm + dt, cut_s, blend_s, c) - self._cut_integral(frm, cut_s, blend_s, c)) / dt
                load_factor = (self._cut_integral(frm + dt, cut_s, blend_s, 0) - self._cut_integral(frm, cut_s, blend_s, 0)) / dt
                shift_cut = max(min(frm + dt, cut_s) - frm, 0.0) / dt
            elif frm < cut_s:
                shift_factor, load_factor, shift_cut = c, 0.0, 1.0
        thrust *=shift_factor * (1 - lim_cut) * (1 - a["SpinThrustLoss"] * spin)
        if mode != "Forward":
            thrust = 0.0
        # ---- engine rpm: lag toward the target (rev drop after an upshift, rev-matched rise after a downshift)
        target = min(rpm_base * (1 + a["ThrustSlipFlare"] * min(slip, 0.5)), P.limiter_rpm)
        if overdrive:
            target = R
        elif self.lim_state == 2:
            target = min(target, R - 2 * hyst)
        rev_drop = s.rev_drop
        if target < self.rpm:
            tau = rev_drop if (self.shift_kind == "Up" and self.since_shift < cut_s + blend_s + 3 * rev_drop) else a["EngineRiseSeconds"] * a["EngineFallScale"]
        else:
            tau = a["DownshiftBlendSeconds"] if (self.shift_kind == "Down" and self.since_shift < 3 * a["DownshiftBlendSeconds"]) else a["EngineRiseSeconds"]
        self.rpm += (target - self.rpm) * (1 - math.exp(-dt / max(tau, 0.001)))
        self.rpm = clamp(self.rpm, I, P.limiter_rpm)
        # ---- resistances, signed against the motion; engine braking only in gear and rolling forward
        if mode in ("Forward", "Braking", "Coasting"):
            motion = forward_speed / max(abs(forward_speed), 0.8)
            resistance = P.Kd * fwd_mph * fwd_mph + P.Rb + P.Rs * abs(forward_speed)
            eb = 0.0
            if mode != "Forward" and gear >= 1 and fwd_mph > 0:
                eb = (a["EngineBrakeDecel"] * a["FeelEngineBrake"] * P.mult(gear, road) / P.mult_base[-1]
                      * (0.35 + 0.65 * min(self.rpm / R, 1.0)) * (1 - shift_cut))
            acc = -motion * resistance - eb
            if mode == "Forward":
                acc += thrust
            elif mode == "Braking":
                acc -= motion * P.brake * abs(throttle)
        # speed guard holds the boosted top at SpeedGuardOverBoostTop x Vb; the reverse limiter is today's
        if fwd_mph > P.guard_mph:
            acc -= (fwd_mph - P.guard_mph) / MPH * a["SpeedGuardStrength"]
        elif fwd_mph < -T.reverse_max_mph:
            acc += (abs(fwd_mph) - T.reverse_max_mph) / MPH * T.soft_limiter
        self.boost_share = P.share(fwd_mph, s)                                  # out.BoostShare, from this frame's speed
        load = 0.0
        if mode == "Forward":
            load = driven if overdrive else driven * load_factor * (1 - lim_cut)
        elif mode == "Reverse":
            load = abs(throttle)
        elif power_brake_held:
            load = 1.0
        self.since_shift += dt
        self.ws_eff = slip
        self.k_shift, self.k_lim = shift_factor, 1 - lim_cut
        self.load = clamp(load, 0, 1)
        self.ratio = ratio
        self.rpm_road = rpm_road
        self.drive_thrust = thrust
        return acc, mode, snap, accelerating, braking, thrust

    def step_neutral(self, throttle, dt):
        """Model.StepNeutral, line by line: an anchored frame (race countdown, teleport). No forces, gear N, rpm follows
        the throttle up to NeutralRevTarget x redline and bounces off the limiter; the duty and steady-speed averages run
        (standing still). Returns the share of the frame the limiter cut."""
        P, s, a = self.P, self.s, self.s.a
        dt = clamp(dt, 0.0, 0.1)
        self.t += dt
        self.dt = dt
        R, I, limiter_rpm = P.R, P.I, P.limiter_rpm
        thr = clamp(throttle, 0.0, 1.0) if s.on("NeutralRevEnabled") else 0.0
        self.gear = 0
        f = 1 - math.exp(-dt / a["DigitalDutySeconds"])
        self.duty += (clamp(throttle, 0.0, 1.0) - self.duty) * f
        self.steady_mph -= self.steady_mph * f
        hyst = a["LimiterHysteresisRpm"]
        over = thr > 0 and self.rpm >= ((R - hyst) if self.lim_state != 0 else R)
        cut = self._step_limiter(over, dt)
        target = I + thr * (a["NeutralRevTarget"] * R - I)
        if self.lim_state == 2:
            target = min(target, R - 2 * hyst)
        target = clamp(target, I, limiter_rpm)
        tau = a["EngineRiseSeconds"] if target > self.rpm else a["EngineRiseSeconds"] * a["EngineFallScale"]
        self.rpm += (target - self.rpm) * (1 - math.exp(-dt / max(tau, 0.001)))
        self.rpm = clamp(self.rpm, I, limiter_rpm)
        self.since_shift += dt
        self.ws_eff = 0.0
        self.k_shift, self.k_lim = 1.0, 1 - cut
        self.load = thr * (1 - cut)
        self.ratio = self.rpm_road = 0.0
        self.drive_thrust = 0.0
        self.boost_share = 1.0
        return cut
