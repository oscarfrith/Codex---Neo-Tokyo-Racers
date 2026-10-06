"""Driving tune, balance part: offline model of the client driving physics.

    py -3 scripts/driving_tune/balance/model.py            (before/after table per stock car, PI sweep checks)
    py -3 scripts/driving_tune/balance/model.py --sweep    (also prints the multiplier curve every 50 PI)

What is ported, line for line, from scripts/driving_tune/before/ (live v3 sources, 2026-10-06):
  VehicleDynamics.ResolveStats    top speed mapping, steering, drift control, boost duration
  VehicleDynamics.StepLongitudinal  whole function (all clamps)
  VehicleDynamics.StepHandling    whole function
  DrivingClient heartbeat         lateral grip, drift block, mini-boost, boost, turn rate (flat ground, 2D)
Config comes from before/config.json through the same clamps the Luau readers use. The balance multipliers
are computed by balance(), which mirrors Model.Balance in edits.py and reads its numbers from edits.py
(so the model and the installed config cannot drift apart).

What it is not: Roblox physics. Flat ground, no hover, no AlignOrientation lag (yaw is applied directly, as
state.YawHeading is), fixed 1/120 s steps. Numbers are label "generated", never "measured in Play".

Stock stats: Config.Vehicles.Performance.BalancedStockProfiles (six Piercer stock totals) read from
roblox/captures/exotic-before/capture.json through scripts/exotic_category/balance/rating.py. That capture is
Backup v2 on 2026-10-02; v3 is that place plus the Exotic category, so the Piercer profiles are the same data.
"""
import importlib.util
import io
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(ROOT))
MPH_PER_STUD = 0.625
DT = 1.0 / 120.0


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def smoothstep(a):
    a = clamp(a, 0, 1)
    return a * a * (3 - 2 * a)


# ---------------------------------------------------------------------------------------------- config
class Config:
    def __init__(self, extra=None):
        records = json.load(io.open(os.path.join(ROOT, "before", "config.json"), encoding="utf-8"))
        self.dynamics, self.driving = {}, {}
        root = {}
        for record in records:
            attrs = record["attrs"] or {}
            if record["path"].startswith("Vehicles/Dynamics/"):
                for key, value in attrs.items():
                    if isinstance(value, (int, float)) and not isinstance(value, bool):
                        self.dynamics[key] = value
            elif record["path"] == "Vehicles/Dynamics":
                root = attrs
            elif record["path"] == "Vehicles/Driving":
                self.driving = attrs
        for key, value in root.items():  # categorised numbers win; the root folder is the second lookup
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                self.dynamics.setdefault(key, value)
        self.dynamics.update(extra or {})

    def num(self, name, fallback, lo=None, hi=None):  # VehicleDynamics.numberAttribute / configNumber("Dynamics")
        value = self.dynamics.get(name, fallback)
        if lo is not None and hi is not None:
            value = clamp(value, lo, hi)
        return value

    def drv(self, name, fallback, lo=None, hi=None):  # configNumber("Driving")
        value = self.driving.get(name, fallback)
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            value = fallback
        if lo is not None and hi is not None:
            value = clamp(value, lo, hi)
        return value

    def drvbool(self, name, fallback):
        value = self.driving.get(name, fallback)
        return value if isinstance(value, bool) else fallback


def curve(raw, reference, exponent, lo, hi):
    raw = reference if raw is None else raw
    return clamp((max(raw, 0.001) / max(reference, 0.001)) ** exponent, lo, hi)


# ---------------------------------------------------------------------------------------------- balance
def load_edits():
    spec = importlib.util.spec_from_file_location("balance_edits", os.path.join(HERE, "edits.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def balance_config():
    """The 08_Balance numbers exactly as edits.py will install them."""
    edits = load_edits()
    attrs = edits.INSTANCES[0]["attributes"]
    return {k: v for k, v in attrs.items() if isinstance(v, (int, float))}


ONE = dict(Enabled=False, BaseNerf=0, TopSpeed=1, Acceleration=1, Braking=1, Reverse=1, Drag=1, Boost=1, MiniBoost=1,
           Steering=1, Grip=1, DriftSideForce=1, DriftTurn=1, DriftEngineAssist=1, DriftAlignment=1, DriftCharge=1)


def balance(pi, b):
    """Mirror of Model.Balance (edits.py). b = the 08_Balance numbers; None or BalanceEnabled 0 = all ones."""
    if b is None or b.get("BalanceEnabled", 1) < 0.5:
        return dict(ONE)
    g = lambda name, fallback, lo, hi: clamp(b.get(name, fallback), lo, hi)
    low_pi = g("BalanceLowPerformanceIndex", 200, 0, 2000)
    high_pi = max(g("BalanceHighPerformanceIndex", 900, 0, 2000), low_pi + 1)
    if pi is None:
        pi = g("BalanceFallbackPerformanceIndex", 525, 0, 2000)
    alpha = clamp((pi - low_pi) / (high_pi - low_pi), 0, 1)
    ease = g("BalanceCurveEase", 0.5, 0, 1)
    alpha = alpha + (alpha * alpha * (3 - 2 * alpha) - alpha) * ease
    low, high = g("BalanceLowNerf", 0.10, 0, 0.6), g("BalanceHighNerf", 0.25, 0, 0.6)
    base = low + (high - low) * alpha
    accel_extra = g("BalanceAccelBrakeExtraNerf", 0.15, 0, 0.6)
    drift_extra = g("BalanceDriftExtraNerf", 0.20, 0, 0.6)

    def m(name, base_share, extra, extra_share):
        s = g("Balance%sBaseShare" % name, base_share, 0, 2)
        e = g("Balance%sExtraShare" % name, extra_share, 0, 2)
        return clamp((1 - base * s) * (1 - extra * e), 0.1, 1.5)

    out = dict(Enabled=True, BaseNerf=base)
    out["TopSpeed"] = m("TopSpeed", 1, 0, 0)
    out["Acceleration"] = m("Acceleration", 1, accel_extra, 1)
    out["Braking"] = m("Braking", 1, accel_extra, 1)
    out["Reverse"] = m("Reverse", 1, accel_extra, 0)
    out["Boost"] = m("Boost", 1, accel_extra, 1)
    out["Steering"] = m("Steering", 0.4, 0, 0)
    out["Grip"] = m("Grip", 0.25, 0, 0)
    out["DriftSideForce"] = m("DriftSideForce", 1, drift_extra, 0)
    out["DriftTurn"] = m("DriftTurn", 0, drift_extra, 1)
    out["DriftEngineAssist"] = m("DriftEngineAssist", 0, drift_extra, 1)
    out["DriftAlignment"] = m("DriftAlignment", 0.5, drift_extra, 1)
    out["DriftCharge"] = m("DriftCharge", 0, drift_extra, 0.5)
    out["MiniBoost"] = m("MiniBoost", 1, drift_extra, 1)
    coupling = g("BalanceDragCoupling", 1, 0, 1)
    out["Drag"] = clamp(1 + (out["Acceleration"] / (out["TopSpeed"] ** 2) - 1) * coupling, 0.25, 4)
    return out


# ---------------------------------------------------------------------------------------------- ResolveStats
def resolve_stats(c, raw):
    steering_factor = curve(raw["SteeringResponse"], c.num("SteeringResponseReference", 50, 1, 500),
                            c.num("SteeringResponseExponent", 0.42, 0.05, 1.5),
                            c.num("SteeringResponseMinMultiplier", 0.78, 0.2, 2),
                            c.num("SteeringResponseMaxMultiplier", 1.30, 0.2, 3))
    drift_factor = curve(raw["DriftControl"], c.num("DriftControlReference", 50, 1, 500),
                         c.num("PhysicalDriftControlExponent", 0.35, 0.05, 1.5),
                         c.num("PhysicalDriftControlMinMultiplier", 0.82, 0.2, 2),
                         c.num("PhysicalDriftControlMaxMultiplier", 1.25, 0.2, 3))
    eff = curve(raw["BoostEfficiency"], 50, c.num("BoostEfficiencyTimingExponent", 0.15, 0, 1), 0.90, 1.10)
    duration = c.num("BoostDurationReferenceSeconds", 3.0, 0.5, 10) * curve(
        raw["BoostDuration"], 2, c.num("BoostDurationExponent", 0.32, 0.05, 1), 0.2, 3) * eff
    duration = clamp(duration, c.num("BoostDurationMinSeconds", 2.2, 0.5, 10), c.num("BoostDurationMaxSeconds", 4.2, 0.5, 12))
    raw_top = raw["TopSpeed"]
    reference = c.num("TopSpeedRawReference", 137, 1, 1000)
    at_reference = c.num("PhysicalTopSpeedAtReferenceMph", 140, 20, 500)
    exponent = c.num("PhysicalTopSpeedExponent", 0.55, 0.05, 2)
    top = at_reference * (max(raw_top, 0.001) / reference) ** exponent
    minimum = c.num("PhysicalTopSpeedMinMph", 60, 20, 300)
    maximum = c.num("PhysicalTopSpeedMaxMph", 300, 40, 500)
    safety = c.num("AbsoluteTopSpeedSafetyMph", 320, 80, 500)
    upper = min(maximum, safety)
    top = clamp(top, min(minimum, upper), upper)
    stats = dict(raw)
    stats.update(TopSpeed=top, RawTopSpeed=raw_top,
                 SteeringResponse=c.num("BasePhysicalSteeringResponse", 58, 10, 150) * steering_factor,
                 DriftControl=c.num("BasePhysicalDriftControl", 50, 10, 150) * drift_factor,
                 RawDriftControl=raw["DriftControl"], BoostDuration=duration)
    return stats


# ---------------------------------------------------------------------------------------------- StepLongitudinal
def step_longitudinal(c, stats, throttle, forward_speed, max_mph, reverse_max_mph, bal, hold=0.0, dt=DT):
    forward_mph = forward_speed * MPH_PER_STUD
    absolute_mph = abs(forward_mph)
    safety = c.num("AbsoluteTopSpeedSafetyMph", 320, 80, 500)
    max_mph = clamp(max_mph, 40, safety)
    reverse_max_mph = clamp(reverse_max_mph, 5, 80)
    deadzone = c.num("ThrottleDeadzone", 0.05, 0, 0.3)
    stop_threshold = c.num("StopThresholdMph", 1.5, 0.1, 8)
    auto_hold = c.num("AutoHoldMph", 1.25, 0.1, 8)
    reverse_delay = c.num("ReverseEngageDelaySeconds", 1.0, 0, 1.5)
    e_min, e_max = c.num("EngineOutputMinMultiplier", 0.72, 0.2, 2), c.num("EngineOutputMaxMultiplier", 1.48, 0.2, 3)
    engine_factor = curve(stats["EngineOutput"], c.num("EngineOutputReference", 60, 1, 300),
                          c.num("EngineOutputExponent", 0.55, 0.05, 2), e_min, e_max)
    weight_reference = c.num("WeightReference", 118, 1, 400)
    weight_factor = curve(weight_reference / max(stats["Weight"], 1), 1, c.num("WeightAccelerationExponent", 0.22, 0, 1.5),
                          c.num("WeightAccelerationMinMultiplier", 0.82, 0.2, 2),
                          c.num("WeightAccelerationMaxMultiplier", 1.18, 0.2, 3))
    launch_alpha = smoothstep(max(forward_mph, 0) / c.num("LaunchRampEndMph", 14, 1, 60))
    launch_multiplier = c.num("LaunchAccelerationMultiplier", 0.45, 0.1, 1)
    launch_shape = launch_multiplier + (1 - launch_multiplier) * launch_alpha
    launch_influence = c.num("LaunchEngineInfluence", 0.35, 0, 1)
    engine_influence = launch_influence + (1 - launch_influence) * launch_alpha
    effective_engine = 1 + (engine_factor - 1) * engine_influence
    engine_alpha = clamp((engine_factor - e_min) / max(e_max - e_min, 0.001), 0, 1)
    band_low = c.num("PowerBandStartRatioLow", 0.48, 0.1, 0.9)
    band_start = band_low + (c.num("PowerBandStartRatioHigh", 0.70, 0.1, 0.95) - band_low) * engine_alpha
    speed_ratio = clamp(max(forward_mph, 0) / max_mph, 0, 1)
    high_alpha = smoothstep((speed_ratio - band_start) / max(1 - band_start, 0.05))
    high_floor = c.num("HighSpeedAccelerationFloor", 0.06, 0, 0.5)
    high_fade = high_floor + (1 - high_floor) * ((1 - high_alpha) ** c.num("HighSpeedAccelerationExponent", 0.80, 0.1, 3))
    forward_acceleration = c.num("BaseForwardAcceleration", 32, 5, 80) * effective_engine * weight_factor * launch_shape * high_fade * bal["Acceleration"]
    braking_factor = curve(stats["BrakingForce"], c.num("BrakingForceReference", 60, 1, 200), c.num("BrakingForceExponent", 0.7, 0.1, 2), 0.65, 1.65)
    brake_weight = clamp((weight_reference / max(stats["Weight"], 1)) ** c.num("BrakeWeightExponent", 0.2, 0, 1), 0.8, 1.2)
    brake_acceleration = c.num("BaseBrakeDeceleration", 30, 8, 90) * braking_factor * brake_weight * bal["Braking"]
    drag_factor = curve(stats["Drag"], c.num("DragReference", 50, 1, 100), c.num("AerodynamicDragStatExponent", 0.35, 0, 1), 0.65, 1.45)
    aero = c.num("AerodynamicDragPerMphSquared", 0.00012, 0, 0.002) * forward_mph * abs(forward_mph) * drag_factor * bal["Drag"]
    reverse_acceleration = c.num("ReverseAcceleration", 12, 2, 40) * engine_factor * weight_factor * bal["Reverse"]
    reverse_ratio = clamp(abs(min(forward_mph, 0)) / reverse_max_mph, 0, 1)
    reverse_curve = (1 - reverse_ratio) ** c.num("ReverseCurveExponent", 0.8, 0.1, 3)
    acceleration = -aero / MPH_PER_STUD
    mode, snap = "Coasting", False
    if throttle > deadzone:
        hold = 0
        if forward_mph < -stop_threshold:
            mode = "Braking"; acceleration += brake_acceleration * throttle
        else:
            mode = "Forward"; acceleration += forward_acceleration * throttle
    elif throttle < -deadzone:
        if forward_mph > stop_threshold:
            hold = 0; mode = "Braking"; acceleration -= brake_acceleration * abs(throttle)
        elif absolute_mph <= stop_threshold:
            hold += dt
            if hold >= reverse_delay:
                mode = "Reverse"; acceleration -= reverse_acceleration * abs(throttle)
            else:
                mode = "Stopped"; snap = True
        else:
            mode = "Reverse"; acceleration -= reverse_acceleration * abs(throttle) * reverse_curve
    else:
        hold = 0
        if absolute_mph <= auto_hold:
            mode = "Stopped"; snap = True
        else:
            amount = c.num("CoastBaseDeceleration", 3.2, 0, 20) + abs(forward_speed) * c.num("CoastSpeedCoefficient", 0.03, 0, 0.2)
            acceleration += -amount if forward_speed > 0 else (amount if forward_speed < 0 else 0)
    limiter = c.num("SoftLimiterStrength", 2.5, 0.1, 20)
    if forward_mph > max_mph:
        acceleration -= ((forward_mph - max_mph) / MPH_PER_STUD) * limiter
    elif forward_mph < -reverse_max_mph:
        acceleration += ((abs(forward_mph) - reverse_max_mph) / MPH_PER_STUD) * limiter
    return acceleration, mode, snap, hold


# ---------------------------------------------------------------------------------------------- StepHandling
def step_handling(c, stats, speed_mph, drift_blend, bal):
    lateral = curve(stats["LateralGrip"], c.num("LateralGripReference", 50, 1, 300), c.num("LateralGripExponent", 0.40, 0.05, 2),
                    c.num("LateralGripMinMultiplier", 0.82, 0.2, 2), c.num("LateralGripMaxMultiplier", 1.22, 0.2, 3))
    down_ref = c.num("DownforceReference", 50, 1, 300)
    speed_alpha = clamp(speed_mph / c.num("HighSpeedGripMph", 140, 20, 300), 0, 1)
    downforce = clamp(1 + (stats["Downforce"] - down_ref) / down_ref * c.num("DownforceGripInfluence", 0.22, 0, 1) * speed_alpha, 0.88, 1.15)
    drift_grip_factor = curve(stats["DriftGrip"], c.num("DriftGripReference", 50, 1, 300), c.num("DriftGripExponent", 0.35, 0.05, 2), 0.85, 1.25)
    drift_control = curve(stats["RawDriftControl"], c.num("DriftControlReference", 50, 1, 300), c.num("DriftControlExponent", 0.32, 0.05, 2), 0.88, 1.25)
    drift_charge = curve(stats["DriftChargeRate"], c.num("DriftChargeReference", 50, 1, 300), c.num("DriftChargeExponent", 0.35, 0.05, 2), 0.80, 1.30)
    normal_grip = c.num("BaseNormalLateralGrip", 6.6, 1, 20) * lateral * downforce * bal["Grip"]
    drift_grip = c.num("BaseDriftLateralGrip", 2.0, 0.1, 8) * drift_grip_factor
    engine_drift = curve(stats["EngineOutput"], c.num("EngineOutputReference", 60, 1, 300), 0.30, 0.85, 1.22)
    return dict(
        LateralGrip=normal_grip + (drift_grip - normal_grip) * drift_blend,
        DriftSideForce=c.num("BaseDriftSideForce", 26, 5, 100) * drift_control * bal["DriftSideForce"],
        DriftTurnMultiplier=drift_control * bal["DriftTurn"],
        DriftChargeMultiplier=drift_charge * bal["DriftCharge"],
        DriftEngineAssist=c.num("DriftEngineAssist", 0.20, 0, 1) * engine_drift * bal["DriftEngineAssist"],
        DriftVelocityAlignmentRate=c.num("DriftVelocityAlignmentRate", 2.0, 0, 10) * drift_control * bal["DriftAlignment"],
        DriftVelocityAlignmentMaxAcceleration=c.num("DriftVelocityAlignmentMaxAcceleration", 30, 1, 100) * drift_grip_factor * bal["DriftAlignment"],
    )


# ---------------------------------------------------------------------------------------------- heartbeat (2D)
class Car:
    """Flat-ground port of the DrivingClient heartbeat force sum. x = right, y = forward at heading 0."""

    def __init__(self, c, raw, pi, bcfg):
        self.c, self.raw, self.pi = c, raw, pi
        self.bal = balance(pi, bcfg)
        self.stats = resolve_stats(c, raw)
        self.vx = self.vy = 0.0
        self.heading = 0.0  # radians, clockwise from +y (a right turn increases it)
        self.x = self.y = 0.0
        self.drift_blend = 0.0
        self.drift_charge = 0.0
        self.mini_timer = 0.0
        self.mini_power = 0.0
        self.boost = 100.0
        self.hold = 0.0
        self.boosting = False
        self.max_mph = clamp(self.stats["TopSpeed"] * self.bal["TopSpeed"], 40, c.num("AbsoluteTopSpeedSafetyMph", 320, 80, 500))

    def speed_mph(self):
        return math.hypot(self.vx, self.vy) * MPH_PER_STUD

    def step(self, throttle=0.0, steer=0.0, drift_held=False, boost_held=False, dt=DT):
        c, stats, bal = self.c, self.stats, self.bal
        fx, fy = math.sin(self.heading), math.cos(self.heading)
        rx, ry = math.cos(self.heading), -math.sin(self.heading)
        forward_speed = self.vx * fx + self.vy * fy
        side_speed = self.vx * rx + self.vy * ry
        speed_mph = self.speed_mph()
        weight = clamp(stats["Weight"], 60, 260)
        handling = max(stats["SteeringResponse"], 10)
        drift_control = max(stats["DriftControl"], 10)
        boost_power = max(stats["BoostForce"], 0)
        boost_duration = max(stats["BoostDuration"], 1)
        swf = clamp((118 / max(weight, 1)) ** c.num("SteeringWeightInfluenceExponent", 0.12, 0, 1),
                    c.num("SteeringWeightMinMultiplier", 0.88, 0.5, 1.5), c.num("SteeringWeightMaxMultiplier", 1.12, 0.5, 1.5))
        handling *= swf
        drift_control *= swf
        can_drift = drift_held and forward_speed > 8 and speed_mph > 10 and abs(steer) > 0
        self.drift_blend += ((1 if can_drift else 0) - self.drift_blend) * clamp(dt * 5.2, 0, 1)
        drifting = self.drift_blend > 0.12
        ax = ay = 0.0
        reverse_max = c.drv("ReverseMaxMph", 40, 5, 80)
        longitudinal, mode, snap, self.hold = step_longitudinal(c, stats, throttle, forward_speed, self.max_mph, reverse_max, bal, self.hold, dt)
        ax += fx * longitudinal; ay += fy * longitudinal
        if snap:
            self.vx -= fx * forward_speed; self.vy -= fy * forward_speed
            forward_speed = 0
        steering_input = steer  # forward driving only in this model
        h = step_handling(c, stats, speed_mph, self.drift_blend, bal)
        ax += -rx * side_speed * h["LateralGrip"]; ay += -ry * side_speed * h["LateralGrip"]
        if drifting:
            coefficient = (c.num("DriftForwardDragBase", 0.10, 0, 2) + c.num("DriftForwardDragBlendExtra", 0.06, 0, 2) * self.drift_blend) * self.drift_blend
            slow = max(forward_speed, 0) * coefficient
            ax -= fx * slow; ay -= fy * slow
            side = h["DriftSideForce"] * self.drift_blend * (-steering_input)
            ax += rx * side; ay += ry * side
            minimum = c.num("DriftThrottleMinimum", 0.05, 0, 1)
            throttle_alpha = clamp((throttle - minimum) / max(1 - minimum, 0.001), 0, 1)
            if throttle_alpha > 0:
                if longitudinal > 0:
                    assist = longitudinal * h["DriftEngineAssist"] * self.drift_blend * throttle_alpha
                    ax += fx * assist; ay += fy * assist
                horizontal = math.hypot(self.vx, self.vy)
                if horizontal > 1:
                    k = h["DriftVelocityAlignmentRate"] * self.drift_blend * throttle_alpha
                    gx, gy = (fx * horizontal - self.vx) * k, (fy * horizontal - self.vy) * k
                    magnitude = math.hypot(gx, gy)
                    cap = h["DriftVelocityAlignmentMaxAcceleration"]
                    if magnitude > cap:
                        gx, gy = gx / magnitude * cap, gy / magnitude * cap
                    ax += gx; ay += gy
            self.drift_charge = min(3.25, self.drift_charge + dt * (0.95 + abs(steering_input) * 1.15) * self.drift_blend * h["DriftChargeMultiplier"])
        elif not drift_held and self.drift_charge > 0:
            minimum_charge = c.num("DriftMiniBoostMinimumCharge", 0.72, 0, 10)
            if self.drift_charge > minimum_charge and throttle > c.drv("DriftMiniBoostAccelerationThreshold", 0.05, 0, 1):
                full = max(c.num("DriftMiniBoostChargeForFullReward", 3.25, 0.01, 10), minimum_charge + 0.01)
                quality = clamp((self.drift_charge - minimum_charge) / (full - minimum_charge), 0, 1) ** c.num("DriftMiniBoostRewardExponent", 0.85, 0.05, 4)
                d_lo, d_hi = sorted((c.num("DriftMiniBoostBaseMinDurationSeconds", 0.18, 0.01, 3), c.num("DriftMiniBoostBaseMaxDurationSeconds", 0.70, 0.01, 3)))
                d_ref = c.num("DriftMiniBoostBoostDurationReferenceSeconds", 3.0, 0.1, 12)
                m_lo, m_hi = sorted((c.num("DriftMiniBoostBoostDurationMinMultiplier", 0.80, 0.05, 3), c.num("DriftMiniBoostBoostDurationMaxMultiplier", 1.20, 0.05, 3)))
                d_mult = clamp((max(stats["BoostDuration"], 0.01) / d_ref) ** c.num("DriftMiniBoostBoostDurationExponent", 0.50, 0.05, 2), m_lo, m_hi)
                a_lo, a_hi = sorted((c.num("DriftMiniBoostAbsoluteMinDurationSeconds", 0.12, 0.01, 3), c.num("DriftMiniBoostAbsoluteMaxDurationSeconds", 0.90, 0.01, 3)))
                self.mini_timer = clamp((d_lo + (d_hi - d_lo) * quality) * d_mult, a_lo, a_hi)
                p_lo, p_hi = sorted((c.num("DriftMiniBoostMinAcceleration", 32, 0, 300), c.num("DriftMiniBoostMaxAcceleration", 72, 0, 300)))
                f_lo, f_hi = sorted((c.num("DriftMiniBoostBoostForceMinMultiplier", 0.65, 0.05, 3), c.num("DriftMiniBoostBoostForceMaxMultiplier", 1.25, 0.05, 3)))
                f_mult = clamp((max(stats["BoostForce"], 0.01) / c.num("DriftMiniBoostBoostForceReference", 30, 0.1, 300)) ** c.num("DriftMiniBoostBoostForceExponent", 0.55, 0.05, 2), f_lo, f_hi)
                self.mini_power = (p_lo + (p_hi - p_lo) * quality) * f_mult
            self.drift_charge = 0
        mini_active = self.mini_timer > 0
        if mini_active:
            self.mini_timer = max(0, self.mini_timer - dt)
        if boost_held and self.boost > 1 and forward_speed > -4 and boost_power > 0:
            self.boost = max(0, self.boost - (100 / boost_duration) * dt)
            b = (boost_power + 32) * 0.75 * bal["Boost"]
            ax += fx * b; ay += fy * b
            boosting = True
        elif mini_active:
            b = self.mini_power * c.num("DriftMiniBoostForceApplicationMultiplier", 0.85, 0, 3) * bal["MiniBoost"]
            ax += fx * b; ay += fy * b
            boosting = True
        else:
            self.mini_power = 0
            boosting = False
        speed_factor = clamp(abs(forward_speed) * MPH_PER_STUD / 45, 0.35, 1.35)
        turn_rate = (handling / 58) * 1.08 * speed_factor * bal["Steering"]
        low, high = c.drv("SpeedSteeringLowSpeedMph", 0, 0, 260), c.drv("SpeedSteeringHighSpeedMph", 115, 1, 320)
        high = max(high, low + 1)
        speed_alpha = clamp((speed_mph - low) / (high - low), 0, 1)
        hi_mult = c.drv("SpeedSteeringHighMultiplier", 0.72, 0.1, 4)
        target = hi_mult + (c.drv("SpeedSteeringLowMultiplier", 1.45, 0.1, 4) - hi_mult) * (1 - speed_alpha) ** c.drv("SpeedSteeringCurveExponent", 1.85, 0.1, 8)
        if drifting:
            target = max(target, c.drv("SpeedSteeringDriftMinimumMultiplier", 0.92, 0.1, 4))
        if boosting:  # line 1172 reads the Boosting attribute that lines 1095/1102/1114 set earlier in the same frame
            target *= c.drv("BoostSteeringMultiplier", 0.8, 0.1, 4)
        turn_rate *= target
        if drifting:
            turn_rate *= (1.34 + drift_control / 170) * h["DriftTurnMultiplier"]
        self.boosting = boosting
        self.vx += ax * dt; self.vy += ay * dt
        self.x += self.vx * dt; self.y += self.vy * dt
        self.heading += steering_input * turn_rate * dt
        return dict(turn_rate=turn_rate, drifting=drifting, mode=mode)


# ---------------------------------------------------------------------------------------------- runs
def straight(c, raw, pi, bcfg):
    car = Car(c, raw, pi, bcfg)
    t, t60, t100, trace = 0.0, None, None, []
    while t < 90:
        car.step(throttle=1)
        t += DT
        mph = car.speed_mph()
        trace.append(mph)
        if t60 is None and mph >= 60: t60 = t
        if t100 is None and mph >= 100: t100 = t
    top = trace[-1]
    t_top = next(i for i, mph in enumerate(trace) if mph >= 0.98 * top) * DT
    # boost from top speed, for the car's own boost duration
    boost_end = top
    while car.boost > 1:
        car.step(throttle=1, boost_held=True)
        boost_end = car.speed_mph()
    # endless boost equilibrium (what a chain of boosts tends to)
    eq = Car(c, raw, pi, bcfg); eq.vy = top / MPH_PER_STUD
    for _ in range(int(40 / DT)):
        eq.boost = 100; eq.step(throttle=1, boost_held=True)
    # braking from 100 mph (or from top speed if the car cannot reach 100)
    brake = Car(c, raw, pi, bcfg)
    start = min(100.0, top)
    brake.vy = start / MPH_PER_STUD
    bt, y0 = 0.0, brake.y
    while brake.speed_mph() > 1.5 and bt < 30:
        brake.step(throttle=-1); bt += DT
    return dict(max_mph=car.max_mph, top=top, t60=t60, t100=t100, t_top=t_top, boost_end=boost_end, boost_eq=eq.speed_mph(),
                brake_from=start, brake_t=bt, brake_d=brake.y - y0, boost_s=max(car.stats["BoostDuration"], 1))


def corner(c, raw, pi, bcfg, top, drift, seconds=2.0):
    """Enter at 85% of the car's own top speed, hold throttle and full right steer for `seconds`."""
    car = Car(c, raw, pi, bcfg)
    car.vy = 0.85 * top / MPH_PER_STUD
    entry = car.speed_mph()
    t, distance, max_slip, yaw_peak = 0.0, 0.0, 0.0, 0.0
    v_dir0 = math.atan2(car.vx, car.vy)
    turned = 0.0
    previous = v_dir0
    while t < seconds:
        info = car.step(throttle=1, steer=1, drift_held=drift)
        t += DT
        distance += math.hypot(car.vx, car.vy) * DT
        direction = math.atan2(car.vx, car.vy)
        delta = (direction - previous + math.pi) % (2 * math.pi) - math.pi
        turned += delta; previous = direction
        slip = abs((car.heading - direction + math.pi) % (2 * math.pi) - math.pi)
        max_slip = max(max_slip, slip)
        yaw_peak = max(yaw_peak, info["turn_rate"])
    exit_speed = car.speed_mph()
    result = dict(entry=entry, exit=exit_speed, turned=math.degrees(turned), radius=distance / max(turned, 1e-6),
                  slip=math.degrees(max_slip), yaw=math.degrees(yaw_peak), charge=car.drift_charge,
                  heading=math.degrees(car.heading))
    if drift:  # release, straighten, take the mini-boost
        peak = exit_speed
        for _ in range(int(1.5 / DT)):
            car.step(throttle=1, steer=0, drift_held=False)
            peak = max(peak, car.speed_mph())
        result["after"] = car.speed_mph(); result["peak"] = peak
    return result


def profiles():
    sys.path.insert(0, os.path.join(REPO, "scripts", "exotic_category", "balance"))
    import rating
    rows = []
    for cockpit, attrs in rating.Capture().stock_profiles().items():
        rows.append((attrs["TargetPI"], attrs["TargetTier"], attrs["DisplayName"], attrs))
    rows.sort(key=lambda row: row[0])
    return rows


def interpolate(rows, pi):
    """Stat set for any PI: piecewise-linear between the six stock profiles (for the smoothness sweep only)."""
    keys = list(SERAPH)
    if pi <= rows[0][0]: return {k: rows[0][3][k] for k in keys}
    if pi >= rows[-1][0]: return {k: rows[-1][3][k] for k in keys}
    for (p0, _, _, a), (p1, _, _, b) in zip(rows, rows[1:]):
        if p0 <= pi <= p1:
            f = (pi - p0) / (p1 - p0)
            return {k: a[k] + (b[k] - a[k]) * f for k in keys}


SERAPH = dict(TopSpeed=772.5, EngineOutput=171.2, Weight=84.0, SteeringResponse=273.7, LateralGrip=192.5, HoverStability=208.1,
              DriftControl=198.6, DriftGrip=176.9, DriftChargeRate=202.5, BrakingForce=164.7, BoostForce=119.1, BoostDuration=8.8,
              BoostRecharge=6.6, BoostRechargeDelay=0.1, BoostEfficiency=225.9, Downforce=245.8, Drag=1.3)
SERAPH_PI = 946
# Measured in Play by the integrator, 2026-10-06, v3, full throttle, no boost, flat road, 60 Hz: (seconds, mph)
SERAPH_RUN = [(0.25, 17), (0.5, 34), (0.8, 50), (1.05, 65), (1.3, 80), (1.55, 94), (1.8, 107), (2.1, 120), (2.3, 131), (2.6, 142),
              (2.85, 151), (3.1, 160), (3.35, 167), (3.6, 174), (3.9, 181), (4.15, 186), (4.4, 191), (4.65, 195), (4.9, 199),
              (5.2, 202), (5.45, 205), (5.7, 207)]


def validate(c):
    print("\nValidation against the measured Seraph run (S, PI 946, balance off). mapped cap %.0f mph (live attribute: 320)" % resolve_stats(c, SERAPH)["TopSpeed"])
    for dt, label in ((DT, "1/120 s steps"), (1 / 60.0, "1/60 s steps")):
        car, t, index, worst, line = Car(c, SERAPH, SERAPH_PI, None), 0.0, 0, 0.0, []
        while index < len(SERAPH_RUN):
            car.step(throttle=1, dt=dt); t += dt
            if t >= SERAPH_RUN[index][0] - 1e-9:
                worst = max(worst, abs(car.speed_mph() - SERAPH_RUN[index][1]))
                line.append("%.2fs %d/%.0f" % (SERAPH_RUN[index][0], SERAPH_RUN[index][1], car.speed_mph()))
                index += 1
        print(label + ": measured/model  " + ", ".join(line))
        print("  largest difference %.1f mph" % worst)
    coast = Car(c, SERAPH, SERAPH_PI, None); coast.vy = 34 / MPH_PER_STUD
    for _ in range(int(round(1.6 / DT))): coast.step()
    print("coast from 34 mph for 1.6 s: measured 16 mph, model %.1f mph" % coast.speed_mph())


def pct(after, before):
    return "%+.0f%%" % ((after / before - 1) * 100)


def main():
    c = Config()
    bcfg = balance_config()
    rows = profiles()
    validate(c)
    rows.append((SERAPH_PI, "S", "Seraph (live, Exotic)", SERAPH))
    print("Balance config:", json.dumps(bcfg, sort_keys=True))
    print("\nMultipliers by PI")
    names = ["BaseNerf", "TopSpeed", "Acceleration", "Braking", "Reverse", "Drag", "Boost", "MiniBoost", "Steering", "Grip",
             "DriftSideForce", "DriftTurn", "DriftEngineAssist", "DriftAlignment", "DriftCharge"]
    points = [100, 200, 300, 375, 450, 525, 600, 662, 725, 787, 850, 925, 1000]
    if "--sweep" in sys.argv:
        points = list(range(100, 1001, 50))
    print("| PI | " + " | ".join(names) + " |")
    print("|" + "---|" * (len(names) + 1))
    for pi in points:
        b = balance(pi, bcfg)
        print("| %d | " % pi + " | ".join("%.3f" % b[n] for n in names) + " |")

    print("\nStraight line (generated, not measured). b = before, a = after.")
    print("| Tier PI car | cap mph b/a | top mph b/a | 0-60 s b/a | 0-100 s b/a | to 98% top s b/a | brake 100-0 s b/a | brake studs b/a | boost end mph b/a | endless boost mph b/a |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    f = lambda v: "-" if v is None else "%.2f" % v
    results = []
    for pi, tier, name, raw in rows:
        b, a = straight(c, raw, pi, None), straight(c, raw, pi, bcfg)
        results.append((pi, tier, name, raw, b, a))
        print("| %s %d %s | %.0f / %.0f | %.1f / %.1f (%s) | %s / %s | %s / %s | %.1f / %.1f | %.2f / %.2f (%s) | %.0f / %.0f (%s) | %.1f / %.1f (%s) | %.1f / %.1f (%s) |" % (
            tier, pi, name, b["max_mph"], a["max_mph"], b["top"], a["top"], pct(a["top"], b["top"]), f(b["t60"]), f(a["t60"]),
            f(b["t100"]), f(a["t100"]), b["t_top"], a["t_top"], b["brake_t"], a["brake_t"], pct(a["brake_t"], b["brake_t"]),
            b["brake_d"], a["brake_d"], pct(a["brake_d"], b["brake_d"]), b["boost_end"], a["boost_end"], pct(a["boost_end"], b["boost_end"]),
            b["boost_eq"], a["boost_eq"], pct(a["boost_eq"], b["boost_eq"])))

    print("\nCorner, 2.0 s full steer with throttle from 85% of own top speed. grip = no drift, drift = drift held.")
    print("| Tier PI | case | entry mph | exit mph | path turned deg | path radius studs | peak slip deg | peak yaw deg/s | charge | 1.5 s after release mph |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for pi, tier, name, raw, b, a in results:
        for label, cfg, top in (("before", None, b["top"]), ("after", bcfg, a["top"])):
            for drift in (False, True):
                r = corner(c, raw, pi, cfg, top, drift)
                print("| %s %d | %s %s | %.0f | %.0f | %.0f | %.0f | %.0f | %.0f | %.2f | %s |" % (
                    tier, pi, label, "drift" if drift else "grip", r["entry"], r["exit"], r["turned"], r["radius"], r["slip"], r["yaw"],
                    r["charge"], ("%.0f" % r["after"]) if drift else "-"))

    print("\nSmoothness sweep (stats interpolated between the six stock profiles, every 5 PI from 150 to 1000)")
    stock = rows[:6]
    for label, cfg in (("before", None), ("after", bcfg)):
        previous, worst_top, worst_60, worst_step, where = None, 0.0, 0.0, 0.0, 0
        for pi in range(150, 1001, 5):
            a = straight(c, interpolate(stock, pi), pi, cfg)
            if previous:
                if a["top"] - previous["top"] < worst_top:
                    worst_top, where = a["top"] - previous["top"], pi
                if a["t60"] and previous["t60"]:
                    worst_60 = max(worst_60, a["t60"] - previous["t60"])
                worst_step = max(worst_step, abs(a["top"] - previous["top"]))
            previous = a
        print("%s: largest top speed loss for +5 PI: %.3f mph (at PI %d); largest 0-60 time gain for +5 PI: %.3f s; largest top speed step: %.2f mph" % (label, worst_top, where, worst_60, worst_step))
    tops = [a["top"] for *_, a in results[:6]]
    print("stock tops after, E to S:", ", ".join("%.1f" % t for t in tops), "monotonic" if tops == sorted(tops) else "NOT MONOTONIC")
    t60 = [a["t60"] for *_, a in results[:6]]
    print("stock 0-60 after, E to S:", ", ".join("%.2f" % t for t in t60), "never slower than the tier below" if all(y <= x + 0.02 for x, y in zip(t60, t60[1:])) else "NOT MONOTONIC")
    # same stats, PI raised by 1: the pure cost of the curve
    worst = 0.0
    for pi in range(150, 1000, 1):
        b0, b1 = balance(pi, bcfg), balance(pi + 1, bcfg)
        worst = max(worst, max(abs(b1[n] - b0[n]) for n in names))
    print("largest change of any multiplier for +1 PI: %.5f" % worst)


if __name__ == "__main__":
    main()
