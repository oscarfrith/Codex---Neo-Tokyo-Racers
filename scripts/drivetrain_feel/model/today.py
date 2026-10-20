"""drivetrain_feel model part: today's driving equations (PR98 live, captured 2026-10-20).

Ported from scripts/drivetrain_feel/before/ (the exact live bytes):
  VehicleDynamics.ComputeBalance      whole function (08_Balance numbers from before/config.json)
  VehicleDynamics.ResolveStats        top speed map, steering, drift control, boost timings
  VehicleDynamics.StepLongitudinal    whole function, every clamp
  VehicleDynamics.StepHandling        whole function
  DrivingClient heartbeat             DRIVE-01 intent, lateral grip, drift block, mini-boost, boost, turn rate
Config: scripts/drivetrain_feel/before/config.json through the same clamps the Luau readers use.

Starts from scripts/driving_tune/balance/model.py (v3 port) and re-reads everything against the PR98 sources; the
v3 port read the v3 config, PR98 differs only by 08_Balance (and SpeedDisplay / SteeringCoast on Driving).
Numbers produced from here are "generated", never "measured in Play".
"""
import io
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DELIVERY = os.path.dirname(HERE)
MPH = 0.625          # MPH_PER_STUD, DrivingClient:21 / VehicleDynamics:4
G = 35.1             # studs/s^2 per g at 1 stud = 0.2794 m (the speed convention 1 stud/s = 0.625 mph)


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def smoothstep(a):
    a = clamp(a, 0.0, 1.0)
    return a * a * (3 - 2 * a)


def lerp(a, b, t):
    return a + (b - a) * t


def curve(raw, reference, exponent, lo, hi):
    """VehicleDynamics.curveMultiplier."""
    raw = reference if raw is None else raw
    return clamp((max(raw, 0.001) / max(reference, 0.001)) ** exponent, lo, hi)


# ---------------------------------------------------------------------------------------------- config
class Config:
    """Live Config.Vehicles.{Dynamics/*, Driving} numbers and bools from before/config.json."""

    def __init__(self, path=None):
        path = path or os.path.join(DELIVERY, "before", "config.json")
        records = json.load(io.open(path, encoding="utf-8"))
        self.dynamics, self.driving, self.dynamics_root = {}, {}, {}
        for record in records:
            attrs = record.get("attrs") or {}
            if record["path"].startswith("Vehicles/Dynamics/"):
                for key, value in attrs.items():
                    if isinstance(value, (int, float)) and not isinstance(value, bool):
                        self.dynamics[key] = value
            elif record["path"] == "Vehicles/Dynamics":
                self.dynamics_root = attrs
            elif record["path"] == "Vehicles/Driving":
                self.driving = attrs
        for key, value in self.dynamics_root.items():  # categorised numbers win; the root folder is the second lookup
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                self.dynamics.setdefault(key, value)

    def num(self, name, fallback, lo=None, hi=None):  # numberAttribute / configNumber("Dynamics")
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

    def drvbool(self, name, fallback):  # configBool("Driving")
        value = self.driving.get(name, fallback)
        return value if isinstance(value, bool) else fallback


# ---------------------------------------------------------------------------------------------- balance
ONE = dict(Enabled=False, BaseNerf=0, TopSpeed=1, Acceleration=1, Braking=1, Reverse=1, Drag=1, Boost=1, MiniBoost=1,
           Steering=1, Grip=1, DriftSideForce=1, DriftTurn=1, DriftEngineAssist=1, DriftAlignment=1, DriftCharge=1)


def balance(c, pi, enabled=True):
    """VehicleDynamics.Model.Balance / ComputeBalance. enabled=False gives the pre-balance car (all ones)."""
    if not enabled or c.num("BalanceEnabled", 1, 0, 1) < 0.5:
        return dict(ONE)
    low_pi = c.num("BalanceLowPerformanceIndex", 200, 0, 2000)
    high_pi = max(c.num("BalanceHighPerformanceIndex", 900, 0, 2000), low_pi + 1)
    if pi is None:
        pi = c.num("BalanceFallbackPerformanceIndex", 525, 0, 2000)
    alpha = clamp((pi - low_pi) / (high_pi - low_pi), 0, 1)
    alpha += (smoothstep(alpha) - alpha) * c.num("BalanceCurveEase", 0.5, 0, 1)
    low = c.num("BalanceLowNerf", 0.1, 0, 0.6)
    base = low + (c.num("BalanceHighNerf", 0.25, 0, 0.6) - low) * alpha
    accel_extra = c.num("BalanceAccelBrakeExtraNerf", 0.15, 0, 0.6)
    drift_extra = c.num("BalanceDriftExtraNerf", 0.2, 0, 0.6)

    def m(name, base_share, extra, extra_share):
        s = c.num("Balance%sBaseShare" % name, base_share, 0, 2)
        e = c.num("Balance%sExtraShare" % name, extra_share, 0, 2)
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
    out["Drag"] = clamp(1 + (out["Acceleration"] / (out["TopSpeed"] ** 2) - 1) * c.num("BalanceDragCoupling", 1, 0, 1), 0.25, 4)
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
    recharge = c.num("BoostRechargeReferenceSeconds", 8.5, 1, 30) * curve(
        raw["BoostRecharge"], 9, c.num("BoostRechargeExponent", 0.32, 0.05, 1), 0.2, 3) / eff
    recharge = clamp(recharge, c.num("BoostRechargeMinSeconds", 6.5, 0.5, 30), c.num("BoostRechargeMaxSeconds", 10.5, 0.5, 40))
    delay = 0.65 * curve(raw["BoostRechargeDelay"], 0.5, c.num("BoostRechargeDelayExponent", 0.25, 0.05, 1), 0.2, 3)
    delay = clamp(delay, c.num("BoostRechargeDelayMinSeconds", 0.40, 0, 5), c.num("BoostRechargeDelayMaxSeconds", 1.0, 0, 5))
    raw_top = raw["TopSpeed"]
    top = c.num("PhysicalTopSpeedAtReferenceMph", 140, 20, 500) * (max(raw_top, 0.001) / c.num("TopSpeedRawReference", 137, 1, 1000)) ** c.num("PhysicalTopSpeedExponent", 0.55, 0.05, 2)
    upper = min(c.num("PhysicalTopSpeedMaxMph", 300, 40, 500), c.num("AbsoluteTopSpeedSafetyMph", 320, 80, 500))
    top = clamp(top, min(c.num("PhysicalTopSpeedMinMph", 60, 20, 300), upper), upper)
    stats = dict(raw)
    stats.update(TopSpeed=top, RawTopSpeed=raw_top,
                 SteeringResponse=c.num("BasePhysicalSteeringResponse", 58, 10, 150) * steering_factor,
                 DriftControl=c.num("BasePhysicalDriftControl", 50, 10, 150) * drift_factor,
                 RawDriftControl=raw["DriftControl"], BoostDuration=duration, BoostRecharge=recharge, BoostRechargeDelay=delay)
    return stats


# ---------------------------------------------------------------------------------------------- per-car numbers
class Today:
    """Every number today's StepLongitudinal / StepHandling / heartbeat computes from config, stats and balance.
    Computed once per car (stats and PI are fixed in a run), then read by the step functions."""

    def __init__(self, c, stats, bal):
        self.c, self.stats, self.bal = c, stats, bal
        n = c.num
        self.safety = n("AbsoluteTopSpeedSafetyMph", 320, 80, 500)
        self.max_mph = clamp(stats["TopSpeed"] * bal["TopSpeed"], 40, self.safety)   # DrivingClient:1116
        self.reverse_max_mph = clamp(c.drv("ReverseMaxMph", 40, 5, 80), 5, 80)
        self.deadzone = n("ThrottleDeadzone", 0.05, 0, 0.3)
        self.stop_mph = n("StopThresholdMph", 1.5, 0.1, 8)
        self.auto_hold_mph = n("AutoHoldMph", 1.25, 0.1, 8)
        self.reverse_delay = n("ReverseEngageDelaySeconds", 1.0, 0, 1.5)
        e_min, e_max = n("EngineOutputMinMultiplier", 0.72, 0.2, 2), n("EngineOutputMaxMultiplier", 1.48, 0.2, 3)
        self.engine_factor = curve(stats["EngineOutput"], n("EngineOutputReference", 60, 1, 300), n("EngineOutputExponent", 0.55, 0.05, 2), e_min, e_max)
        w_ref = n("WeightReference", 118, 1, 400)
        weight = stats["Weight"]
        self.weight_factor = curve(w_ref / max(weight, 1), 1, n("WeightAccelerationExponent", 0.22, 0, 1.5),
                                   n("WeightAccelerationMinMultiplier", 0.82, 0.2, 2), n("WeightAccelerationMaxMultiplier", 1.18, 0.2, 3))
        self.launch_end = n("LaunchRampEndMph", 14, 1, 60)
        self.launch_mult = n("LaunchAccelerationMultiplier", 0.45, 0.1, 1)
        self.launch_influence = n("LaunchEngineInfluence", 0.35, 0, 1)
        engine_alpha = clamp((self.engine_factor - e_min) / max(e_max - e_min, 0.001), 0, 1)
        band_low = n("PowerBandStartRatioLow", 0.48, 0.1, 0.9)
        self.band_start = band_low + (n("PowerBandStartRatioHigh", 0.70, 0.1, 0.95) - band_low) * engine_alpha
        self.high_floor = n("HighSpeedAccelerationFloor", 0.06, 0, 0.5)
        self.high_exp = n("HighSpeedAccelerationExponent", 0.80, 0.1, 3)
        self.base_forward = n("BaseForwardAcceleration", 32, 5, 80)
        braking_factor = curve(stats["BrakingForce"], n("BrakingForceReference", 60, 1, 200), n("BrakingForceExponent", 0.7, 0.1, 2), 0.65, 1.65)
        self.brake_weight = clamp((w_ref / max(weight, 1)) ** n("BrakeWeightExponent", 0.2, 0, 1), 0.8, 1.2)
        self.brake = n("BaseBrakeDeceleration", 30, 8, 90) * braking_factor * self.brake_weight * bal["Braking"]
        self.drag_factor = curve(stats["Drag"], n("DragReference", 50, 1, 100), n("AerodynamicDragStatExponent", 0.35, 0, 1), 0.65, 1.45)
        self.aero_k = n("AerodynamicDragPerMphSquared", 0.00012, 0, 0.002) * self.drag_factor * bal["Drag"]
        self.reverse = n("ReverseAcceleration", 12, 2, 40) * self.engine_factor * self.weight_factor * bal["Reverse"]
        self.reverse_curve_exp = n("ReverseCurveExponent", 0.8, 0.1, 3)
        self.coast_base = n("CoastBaseDeceleration", 3.2, 0, 20)
        self.coast_k = n("CoastSpeedCoefficient", 0.03, 0, 0.2)
        self.soft_limiter = n("SoftLimiterStrength", 2.5, 0.1, 20)
        # StepHandling (static parts)
        self.lateral_factor = curve(stats["LateralGrip"], n("LateralGripReference", 50, 1, 300), n("LateralGripExponent", 0.40, 0.05, 2),
                                    n("LateralGripMinMultiplier", 0.82, 0.2, 2), n("LateralGripMaxMultiplier", 1.22, 0.2, 3))
        self.down_ref = n("DownforceReference", 50, 1, 300)
        self.high_grip_mph = n("HighSpeedGripMph", 140, 20, 300)
        self.down_influence = n("DownforceGripInfluence", 0.22, 0, 1)
        self.drift_grip_factor = curve(stats["DriftGrip"], n("DriftGripReference", 50, 1, 300), n("DriftGripExponent", 0.35, 0.05, 2), 0.85, 1.25)
        self.drift_control_factor = curve(stats["RawDriftControl"], n("DriftControlReference", 50, 1, 300), n("DriftControlExponent", 0.32, 0.05, 2), 0.88, 1.25)
        self.drift_charge_factor = curve(stats["DriftChargeRate"], n("DriftChargeReference", 50, 1, 300), n("DriftChargeExponent", 0.35, 0.05, 2), 0.80, 1.30)
        self.stability_factor = curve(stats["HoverStability"], n("HoverStabilityReference", 50, 1, 300), n("HoverStabilityExponent", 0.25, 0.05, 2), 0.88, 1.15)
        self.normal_grip_base = n("BaseNormalLateralGrip", 6.6, 1, 20) * self.lateral_factor * bal["Grip"]
        self.drift_grip = n("BaseDriftLateralGrip", 2.0, 0.1, 8) * self.drift_grip_factor
        engine_drift = curve(stats["EngineOutput"], n("EngineOutputReference", 60, 1, 300), 0.30, 0.85, 1.22)
        self.drift_side_force = n("BaseDriftSideForce", 26, 5, 100) * self.drift_control_factor * bal["DriftSideForce"]
        self.drift_turn_mult = self.drift_control_factor * bal["DriftTurn"]
        self.drift_charge_mult = self.drift_charge_factor * bal["DriftCharge"]
        self.align_responsiveness = n("BaseAlignResponsiveness", 22, 4, 60) * self.stability_factor
        self.drift_engine_assist = n("DriftEngineAssist", 0.20, 0, 1) * engine_drift * bal["DriftEngineAssist"]
        self.drift_align_rate = n("DriftVelocityAlignmentRate", 2.0, 0, 10) * self.drift_control_factor * bal["DriftAlignment"]
        self.drift_align_max = n("DriftVelocityAlignmentMaxAcceleration", 30, 1, 100) * self.drift_grip_factor * bal["DriftAlignment"]
        self.drift_drag_base = n("DriftForwardDragBase", 0.10, 0, 2)
        self.drift_drag_extra = n("DriftForwardDragBlendExtra", 0.06, 0, 2)
        self.drift_throttle_min = n("DriftThrottleMinimum", 0.05, 0, 1)
        # heartbeat (DrivingClient:1117-1137)
        self.weight = clamp(weight, 60, 260)
        swf = clamp((118 / max(self.weight, 1)) ** n("SteeringWeightInfluenceExponent", 0.12, 0, 1),
                    n("SteeringWeightMinMultiplier", 0.88, 0.5, 1.5), n("SteeringWeightMaxMultiplier", 1.12, 0.5, 1.5))
        self.handling = max(stats["SteeringResponse"], 10) * swf
        self.drift_control = max(stats["DriftControl"], 10) * swf
        self.boost_power = max(stats["BoostForce"], 0)
        self.boost_duration = max(stats["BoostDuration"], 1)
        self.boost_recharge = max(stats["BoostRecharge"], 0.5)
        self.boost_delay = clamp(stats["BoostRechargeDelay"], 0, 5)
        self.boost_accel = (self.boost_power + 32) * 0.75 * bal["Boost"]                 # DrivingClient:1401
        # mini-boost (DrivingClient:1334-1383; stat scaling on in PR98)
        self.mini_min_charge = n("DriftMiniBoostMinimumCharge", 0.72, 0, 10)
        self.mini_full = max(n("DriftMiniBoostChargeForFullReward", 3.25, 0.01, 10), self.mini_min_charge + 0.01)
        self.mini_exp = n("DriftMiniBoostRewardExponent", 0.85, 0.05, 4)
        d_lo, d_hi = sorted((n("DriftMiniBoostBaseMinDurationSeconds", 0.18, 0.01, 3), n("DriftMiniBoostBaseMaxDurationSeconds", 0.70, 0.01, 3)))
        m_lo, m_hi = sorted((n("DriftMiniBoostBoostDurationMinMultiplier", 0.80, 0.05, 3), n("DriftMiniBoostBoostDurationMaxMultiplier", 1.20, 0.05, 3)))
        d_mult = clamp((max(stats["BoostDuration"], 0.01) / n("DriftMiniBoostBoostDurationReferenceSeconds", 3.0, 0.1, 12)) ** n("DriftMiniBoostBoostDurationExponent", 0.50, 0.05, 2), m_lo, m_hi)
        a_lo, a_hi = sorted((n("DriftMiniBoostAbsoluteMinDurationSeconds", 0.12, 0.01, 3), n("DriftMiniBoostAbsoluteMaxDurationSeconds", 0.90, 0.01, 3)))
        p_lo, p_hi = sorted((n("DriftMiniBoostMinAcceleration", 32, 0, 300), n("DriftMiniBoostMaxAcceleration", 72, 0, 300)))
        f_lo, f_hi = sorted((n("DriftMiniBoostBoostForceMinMultiplier", 0.65, 0.05, 3), n("DriftMiniBoostBoostForceMaxMultiplier", 1.25, 0.05, 3)))
        f_mult = clamp((max(stats["BoostForce"], 0.01) / n("DriftMiniBoostBoostForceReference", 30, 0.1, 300)) ** n("DriftMiniBoostBoostForceExponent", 0.55, 0.05, 2), f_lo, f_hi)
        self.mini_duration = lambda q: clamp((d_lo + (d_hi - d_lo) * q) * d_mult, a_lo, a_hi)
        self.mini_power = lambda q: (p_lo + (p_hi - p_lo) * q) * f_mult
        self.mini_apply = n("DriftMiniBoostForceApplicationMultiplier", 0.85, 0, 3)
        self.mini_threshold = c.drv("DriftMiniBoostAccelerationThreshold", 0.05, 0, 1)
        # turn rate (DrivingClient:1428-1491)
        self.ss_low = c.drv("SpeedSteeringLowSpeedMph", 0, 0, 260)
        self.ss_high = max(c.drv("SpeedSteeringHighSpeedMph", 115, 1, 320), self.ss_low + 1)
        self.ss_low_mult = c.drv("SpeedSteeringLowMultiplier", 1.45, 0.1, 4)
        self.ss_high_mult = c.drv("SpeedSteeringHighMultiplier", 0.72, 0.1, 4)
        self.ss_exp = c.drv("SpeedSteeringCurveExponent", 1.85, 0.1, 8)
        self.reverse_steer = c.drv("ReverseSteeringMultiplier", 1.18, 0.1, 4)
        self.reverse_uses_curve = c.drvbool("ReverseSteeringUsesSpeedCurve", True)
        self.drift_min_mult = c.drv("SpeedSteeringDriftMinimumMultiplier", 0.92, 0.1, 4)
        self.boost_steer = c.drv("BoostSteeringMultiplier", 0.8, 0.1, 4)
        self.intent_deadzone = c.drv("SteeringIntentThrottleDeadzone", 0.05, 0, 0.5)
        self.coast_dir_mph = c.drv("SteeringCoastDirectionMph", 0.5, 0.05, 5)
        self.coast_reverse_mph = c.drv("SteeringCoastReverseMph", 8, 0.05, 80)
        self.coast_assume_forward = c.drvbool("SteeringCoastAssumeForward", True)

    # --- StepLongitudinal pieces -----------------------------------------------------------------
    def forward_accel(self, forward_mph):
        """Today's forward acceleration at throttle 1 (studs/s^2)."""
        launch_alpha = smoothstep(max(forward_mph, 0) / self.launch_end)
        launch_shape = self.launch_mult + (1 - self.launch_mult) * launch_alpha
        influence = self.launch_influence + (1 - self.launch_influence) * launch_alpha
        effective_engine = 1 + (self.engine_factor - 1) * influence
        ratio = clamp(max(forward_mph, 0) / self.max_mph, 0, 1)
        high_alpha = smoothstep((ratio - self.band_start) / max(1 - self.band_start, 0.05))
        high_fade = self.high_floor + (1 - self.high_floor) * ((1 - high_alpha) ** self.high_exp)
        return self.base_forward * effective_engine * self.weight_factor * launch_shape * high_fade * self.bal["Acceleration"]

    def aero(self, forward_mph):
        """Today's aero term in studs/s^2 (signed with velocity)."""
        return self.aero_k * forward_mph * abs(forward_mph) / MPH

    def limiter(self, forward_mph):
        if forward_mph > self.max_mph:
            return -((forward_mph - self.max_mph) / MPH) * self.soft_limiter
        if forward_mph < -self.reverse_max_mph:
            return ((abs(forward_mph) - self.reverse_max_mph) / MPH) * self.soft_limiter
        return 0.0

    def step_longitudinal(self, throttle, forward_speed, hold, dt):
        """Port of Model.StepLongitudinal. Returns (acc, mode, snap, hold, accelerating, braking)."""
        forward_mph = forward_speed * MPH
        absolute_mph = abs(forward_mph)
        acceleration = -self.aero(forward_mph)
        mode, snap, accelerating, braking = "Coasting", False, False, False
        dz = self.deadzone
        if throttle > dz:
            hold = 0
            if forward_mph < -self.stop_mph:
                mode, braking = "Braking", True
                acceleration += self.brake * throttle
            else:
                mode, accelerating = "Forward", True
                acceleration += self.forward_accel(forward_mph) * throttle
        elif throttle < -dz:
            if forward_mph > self.stop_mph:
                hold = 0
                mode, braking = "Braking", True
                acceleration -= self.brake * abs(throttle)
            elif absolute_mph <= self.stop_mph:
                hold += dt
                if hold >= self.reverse_delay:
                    mode, accelerating = "Reverse", True
                    acceleration -= self.reverse * abs(throttle)
                else:
                    mode, snap = "Stopped", True
            else:
                mode, accelerating = "Reverse", True
                ratio = clamp(abs(min(forward_mph, 0)) / self.reverse_max_mph, 0, 1)
                acceleration -= self.reverse * abs(throttle) * (1 - ratio) ** self.reverse_curve_exp
        else:
            hold = 0
            if absolute_mph <= self.auto_hold_mph:
                mode, snap = "Stopped", True
            else:
                amount = self.coast_base + abs(forward_speed) * self.coast_k
                acceleration += -amount if forward_speed > 0 else (amount if forward_speed < 0 else 0)
        acceleration += self.limiter(forward_mph)
        return acceleration, mode, snap, hold, accelerating, braking

    # --- StepHandling (speed-dependent part) ------------------------------------------------------
    def downforce(self, speed_mph):
        speed_alpha = clamp(speed_mph / self.high_grip_mph, 0, 1)
        return clamp(1 + (self.stats["Downforce"] - self.down_ref) / self.down_ref * self.down_influence * speed_alpha, 0.88, 1.15)

    def lateral_grip(self, speed_mph, drift_blend):
        normal = self.normal_grip_base * self.downforce(speed_mph)
        return normal + (self.drift_grip - normal) * drift_blend

    # --- turn rate --------------------------------------------------------------------------------
    def turn_rate(self, forward_speed, speed_mph, intent, drifting, boosting):
        speed_factor = clamp(abs(forward_speed) * MPH / 45, 0.35, 1.35)
        rate = (self.handling / 58) * 1.08 * speed_factor * self.bal["Steering"]
        alpha = clamp((speed_mph - self.ss_low) / (self.ss_high - self.ss_low), 0, 1)
        target = self.ss_high_mult + (self.ss_low_mult - self.ss_high_mult) * (1 - alpha) ** self.ss_exp
        if intent < 0:
            target = target * self.reverse_steer if self.reverse_uses_curve else self.reverse_steer
        if drifting:
            target = max(target, self.drift_min_mult)
        if boosting:
            target *= self.boost_steer
        rate *= target
        if drifting:
            rate *= (1.34 + self.drift_control / 170) * self.drift_turn_mult
        return rate

    def solve_top(self, extra=0.0, lo=1.0, hi=None):
        """Bisection: forward(v) + extra + aero/limiter terms = 0 at throttle 1 (today's equations)."""
        hi = hi or self.safety * 1.5
        f = lambda v: self.forward_accel(v) + extra - self.aero(v) + self.limiter(v)
        if f(hi) > 0:
            return hi
        for _ in range(60):
            mid = 0.5 * (lo + hi)
            if f(mid) > 0:
                lo = mid
            else:
                hi = mid
        return 0.5 * (lo + hi)
