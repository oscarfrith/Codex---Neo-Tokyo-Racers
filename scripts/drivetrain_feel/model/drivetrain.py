"""drivetrain_feel model part: the contract's drivetrain (CONTRACT sections 4, 5.1, 5.2).

CONTRACT_DEFAULTS is section 4 verbatim (Config.Vehicles.Drivetrain.exotic). Profile is Model.DrivetrainProfile
(section 5.1) and Gearbox.step is Model.StepDrivetrain (section 5.2, all nine mandatory fixes).

Where the contract is silent the model uses the design draft as corrected by the critiques; those constants are in
MODEL_CONSTANTS and listed in RESULTS.md so the physics part can match or override them.
"""
import math

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

# Constants the contract does not name (draft / critique values). The model treats them as code constants.
MODEL_CONSTANTS = dict(
    SlideSmoothWidth=0.6,       # a_drive slide factor reaches SlideGripFraction at ws_eff 0.6 (draft 3.2)
    BrakeDownshiftGap=0.2,      # seconds between braking downshifts (draft 3.2)
    YawCapDriftExtra=1.5,       # yaw cap x (1 + 1.5 DriftBlend) (draft 3.4.2) - see DriftCapExempt handling
    SpinYawGate=0.15, SpinYawGateWidth=0.35,   # ss((|r| - 0.15)/0.35) in L_t (draft 3.5)
    SpinYawAuthorityLoss=0.85,  # yaw spring w x (1 - 0.85 L), floored at 1/s (draft 3.4.2 + critique 4)
    SpinDynamicBlendL=0.2,      # spin forces the yaw state dynamic below YawKinematicBelowMph: w = max(ss(mph/K), ss(L/0.2))
    DriftYawExempt=False,       # contract: yaw spring always on. True = variant: yaw blends to kinematic with DriftBlend
    DriftHoldDownshift=False,   # contract: gear held in a drift. True = variant that downshifts by |v_h| in a drift
    DriftAssistPlateauShare=0.0,  # contract fix 7: drift assist from gross DriveThrust (0). >0 = variant blending toward A1 x thr
    StabNeedsLift=True,         # a stab is a lift-and-stab; False = literal "any rise from < 0.3" (every W press is a stab)
    UnwindMaxSpin=0.1,
    SpinYawModel="soften",      # "soften": one yaw state, spin softens the spring (draft). "additive": r = r_steer + r_spin
    SpinSoftensToBase=True,     # yaw spring softens with L toward YawOmega x weight x (1 - 0.85), not toward the FeelWeight-scaled omega
    ReturnScalesWithWeight=True,  # keyboard steer return = SteerReturnRate / FeelWeight (FeelWeight 0 = today's instant return)          # YawUnwindScale applies only while L < 0.1 (otherwise the unwind spring fights the spin)
    LateralCurveB=None,         # None = 1/C: the peaked curve has today's slope at small slip (identity for small requests)
    LowRpmFloorIdle=True,
)


def parse_list(text):
    return [float(part) for part in str(text).replace(" ", "").split(",") if part]


def parse_curve(text):
    points = []
    for part in str(text).replace(" ", "").split(","):
        if ":" in part:
            x, y = part.split(":")
            points.append((float(x), float(y)))
    points.sort()
    return points


def torque_at(points, x):
    if x <= points[0][0]:
        return points[0][1]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / max(x1 - x0, 1e-9)
    return points[-1][1]


class Settings:
    """The class folder attributes plus the dial mappings (effective values). One object per tuning variant."""

    def __init__(self, overrides=None, constants=None):
        self.a = dict(CONTRACT_DEFAULTS)
        self.a.update(overrides or {})
        self.k = dict(MODEL_CONSTANTS)
        self.k.update(constants or {})
        a = self.a
        self.ratios = parse_list(a["GearRatios"])[:int(a["GearCount"])]
        self.curve = parse_curve(a["TorqueCurve"])
        fw, fg = a["FeelWeight"], a["FeelGearing"]
        # dial mappings (the model's reading of CONTRACT 4.1; the physics NOTES are authoritative)
        self.p = a["GearTorqueExponent"] * fg                                    # amount-like
        self.cut_seconds = a["ShiftCutSeconds"] * fg                             # time-like
        self.blend_seconds = a["ShiftBlendSeconds"] * fg
        self.cut_torque = clamp(1 - (1 - a["ShiftCutTorque"]) * fg, 0, 1)       # depth scaled by the dial
        self.shift_rpm_seconds = a["ShiftRpmSeconds"] * fg                       # rev drop: 0 = instant
        self.steer_rise = a["SteerRiseSeconds"] * fw                             # 0 = instant (today)
        self.grip_relax = a["GripRelaxStuds"] * fw                               # 0 = no lag (today)
        self.yaw_kinematic = fw < 0.05                                           # 0 = kinematic yaw (today)
        self.weight_dial = fw                                                    # brake lerp today -> V2, omega / fw


class Profile:
    """Model.DrivetrainProfile(vehicle, stats, balance, maxMph): per car, cached, rebuilt on change."""

    def __init__(self, today, settings, pi):
        T, a, s = today, settings.a, settings
        self.R, self.I, self.limiter_rpm = a["RedlineRpm"], a["IdleRpm"], a["LimiterRpm"]
        self.ratios = s.ratios
        self.n = len(self.ratios)
        self.Vt = T.solve_top()                                                 # today's drag-limited top
        self.Vb = T.solve_top(extra=T.boost_accel) if T.boost_power > 0 else self.Vt   # today's endless-boost top
        over = a["TopGearOverspeed"]
        r1, rtop = self.ratios[0], self.ratios[-1]
        self.Vg = [self.Vt * over * rtop / r for r in self.ratios]               # gear redline speeds (mph)
        self.mult = [(r / r1) ** s.p for r in self.ratios]
        self.A1 = T.base_forward * T.engine_factor * T.weight_factor * T.bal["Acceleration"] * a["FeelAcceleration"]
        self.Rb, self.Rs = a["RollingDecel"], a["RollingDecelPerStud"]
        tier = smoothstep((pi - a["TierStartPI"]) / max(a["TierFullPI"] - a["TierStartPI"], 1))
        self.tier = tier
        grip_term = clamp((T.stats["LateralGrip"] / 50) ** a["TractionGripExponent"], 0.9, 1.15)
        self.a_trac = (a["TractionG"] * G * grip_term + a["TractionTierBonusG"] * G * tier) * a["FeelGrip"]
        self.slide_fraction, self.assist = a["SlideGripFraction"], a["TractionAssist"]
        self.slide_width = settings.k["SlideSmoothWidth"]
        # Kd from the thrust top gear actually delivers at Vt (traction-limited when FeelGearing is near 0)
        top_thrust_at_vt = self.delivered(self.A1 * self.mult[-1] * torque_at(s.curve, 1 / over))
        self.Kd = max(top_thrust_at_vt - self.Rb - self.Rs * self.Vt / MPH, 0.5) / (self.Vt ** 2)
        self.boost_today = T.boost_accel
        x_vb = self.Vb / self.Vg[-1]
        # Overdrive is in the Vb solve: past top-gear redline while boosting, thrust holds at tau(1) x mult_top
        a_top_vb = self.delivered(self.A1 * self.mult[-1] * torque_at(s.curve, min(x_vb, 1.0)))
        if x_vb > 1 and a["OverdriveEnabled"] < 0.5:
            a_top_vb *= 0.4   # limiter duty without Overdrive (on 30 ms / cut 45 ms)
        need = self.Kd * self.Vb ** 2 + self.Rb + self.Rs * self.Vb / MPH - a_top_vb
        self.share_hi = clamp(need / max(self.boost_today, 1e-6), a["BoostShareMin"], 1) if self.boost_today > 0 else 1
        brake_v2 = (a["BrakeDecel"] * clamp((T.stats["BrakingForce"] / 60) ** a["BrakeForceExponent"], a["BrakeFactorMin"], a["BrakeFactorMax"])
                    * T.brake_weight * T.bal["Braking"])
        self.brake_v2 = brake_v2
        self.brake = max(lerp(T.brake, brake_v2, s.weight_dial), 0.2 * brake_v2)  # FeelWeight 0 = today's brake
        self.engine_brake = a["EngineBrakeDecel"] * a["FeelEngineBrake"]
        self.guard_mph = min(T.max_mph, a["SpeedGuardOverBoostTop"] * self.Vb)
        # chassis numbers
        self.yaw_weight = clamp((118 / T.weight) ** a["YawWeightExponent"], a["YawWeightMin"], a["YawWeightMax"])
        self.cap_grip = clamp((T.stats["LateralGrip"] / 50) ** a["LateralCapGripExponent"], 0.85, 1.2)
        self.spin_tier = a["SpinTierFloor"] + (1 - a["SpinTierFloor"]) * tier

    def delivered(self, a_raw, dump=0.0):
        """Thrust after the traction limit and the sliding-grip factor (StepDrivetrain's a_drive before cuts)."""
        ws_eff = max(0.0, a_raw / self.a_trac - 1) * (1 - self.assist) + dump
        return min(a_raw, self.a_trac) * (1 - (1 - self.slide_fraction) * smoothstep(ws_eff / self.slide_width))

    def share(self, mph, settings):
        if settings.a["BoostShapeEnabled"] < 0.5:
            return 1.0
        return 1 - (1 - self.share_hi) * smoothstep(max(mph, 0) / self.Vb)

    def a_cap(self, today, speed_mph, settings):
        return settings.a["LateralCapG"] * G * self.cap_grip * today.downforce(speed_mph) * today.bal["Grip"] * settings.a["FeelGrip"]

    def gear_for_speed(self, mph, settings):
        """The gear the full-throttle auto box would hold at this speed (used to start runs mid-speed)."""
        up = settings.a["UpshiftFlat"]
        for g in range(self.n):
            if mph < up * self.Vg[g]:
                return g + 1
        return self.n


def frame_average_square(phase, dt, on, off):
    """Mean of a periodic on/off gate (1 for `on` seconds, then 0 for `off`) over [phase, phase + dt]."""
    period = on + off
    if period <= 0:
        return 1.0

    def integral(t):
        cycles, rem = divmod(t, period)
        return cycles * on + min(rem, on)
    return (integral(phase + dt) - integral(phase)) / dt if dt > 0 else 1.0


def frame_average_cut(t0, dt, cut, blend, depth):
    """Mean of the shift torque factor over [t0, t0 + dt] after the shift started at 0:
    depth for `cut` seconds, then a linear ramp to 1 over `blend`, then 1."""
    def integral(t):
        if t <= 0:
            return t
        total = min(t, cut) * depth
        if t > cut:
            u = min(t - cut, blend)
            total += depth * u + (1 - depth) * (u * u) / (2 * blend) if blend > 0 else 0
        if t > cut + blend:
            total += t - cut - blend
        return total
    return (integral(t0 + dt) - integral(t0)) / dt if dt > 0 else 1.0


class Gearbox:
    """state.Gearbox plus Model.StepDrivetrain. Changed in place, no per-frame allocation in the Luau version."""

    def __init__(self, profile, settings, today):
        self.P, self.s, self.T = profile, settings, today
        self.reset(gear=1)

    def reset(self, gear=1, rpm=None):
        self.gear = gear
        self.rpm = rpm if rpm is not None else self.P.I
        self.t = 0.0
        self.last_shift = -10.0
        self.shift_kind = None
        self.cut_start = None
        self.lift_time = -10.0
        self.thr_prev = 0.0
        self.kick_hold = 0.0
        self.lim_active = False
        self.lim_phase = 0.0
        self.lim_bounces = 0
        self.shifts = []          # (t, kind, from, to, mph)
        self.ws_eff = 0.0
        self.k_shift = 1.0
        self.k_lim = 1.0
        self.overdrive = False
        self.rpm_road = 0.0
        self.load = 0.0
        self.dt = 1 / 60
        self.drive_thrust = self.a_res = self.a_eb = 0.0

    def place(self, mph):
        """Start mid-speed in the gear the auto box would hold, at road rpm."""
        g = self.P.gear_for_speed(mph, self.s)
        self.reset(gear=g, rpm=max(self.P.I, mph / self.P.Vg[g - 1] * self.P.R))

    def step(self, car, throttle, forward_speed, hspeed_mph, drift_blend, boost_applied, dt):
        """Returns (acc, mode, snap, accelerating, braking, drive_thrust). Mirrors StepLongitudinal's modes."""
        P, s, a, T = self.P, self.s, self.s.a, self.T
        self.t += dt
        self.dt = dt
        t = self.t
        fwd_mph = forward_speed * MPH
        abs_mph = abs(fwd_mph)
        dz = T.deadzone
        L = car.spin_L
        thr = throttle
        # throttle history: lift hold and kickdown hold
        if thr < a["CruiseThrottleMin"] <= self.thr_prev:
            self.lift_time = t
        self.kick_hold = self.kick_hold + dt if thr >= a["KickdownThrottle"] else 0.0
        self.thr_prev = thr
        # ---- mode (today's StepLongitudinal branches)
        mode, snap, accelerating, braking = "Coasting", False, False, False
        if thr > dz:
            car.hold = 0
            if fwd_mph < -T.stop_mph:
                mode, braking = "Braking", True
            else:
                mode, accelerating = "Forward", True
        elif thr < -dz:
            if fwd_mph > T.stop_mph:
                car.hold = 0
                mode, braking = "Braking", True
            elif abs_mph <= T.stop_mph:
                car.hold += dt
                if car.hold >= T.reverse_delay:
                    mode, accelerating = "Reverse", True
                else:
                    mode, snap = "Stopped", True
            else:
                mode, accelerating = "Reverse", True
        else:
            car.hold = 0
            if abs_mph <= T.auto_hold_mph:
                mode = "Stopped"
                # fix 2: no auto-hold snap mid-spin or while still sliding sideways
                snap = L <= 0.05 and hspeed_mph / MPH <= 4
        # ---- gear selection
        v_eff = lerp(max(fwd_mph, 0), hspeed_mph, drift_blend)                  # fix 3: |v_h| blended by DriftBlend
        if mode == "Reverse" or (mode == "Stopped" and thr < -dz):
            if self.gear != -1:
                self._event("Down", -1, fwd_mph)
            self.gear = -1
        elif self.gear < 1:
            self.gear = 1
        if self.gear >= 1 and v_eff < a["StopGearMph"] and self.gear > 1:
            self._event("Down", 1, fwd_mph)
            self.gear = 1
        overdrive = False
        rpm_road = 0.0
        if self.gear >= 1:
            g = self.gear
            x = v_eff / P.Vg[g - 1]
            rpm_road = x * P.R
            since = t - self.last_shift
            hold = drift_blend > 0.3 or L > 0.1                                   # fix 3
            shifted = False
            if g < P.n and since >= a["ShiftMinIntervalSeconds"]:
                up = False
                if rpm_road >= P.R and not (boost_applied and a["OverdriveEnabled"] >= 0.5 and g == P.n):
                    up = mode in ("Forward", "Coasting")                           # an upshift on the limiter is always allowed
                elif not hold and mode == "Forward" and t - self.lift_time >= a["LiftHoldSeconds"]:
                    U = None
                    if thr >= 0.9:
                        U = a["UpshiftFlat"]
                    elif thr >= 0.3:
                        U = lerp(a["UpshiftPartLow"], a["UpshiftPartHigh"], (thr - 0.3) / 0.6)
                    elif thr >= a["CruiseThrottleMin"]:                            # fix 4: no cruise upshift at a lift
                        U = a["UpshiftCruise"]
                    if U is not None and rpm_road >= U * P.R:
                        land = rpm_road * P.ratios[g] / P.ratios[g - 1]
                        up = thr >= 0.3 or land >= a["UpshiftMinLand"] * P.R
                if up:
                    self._shift_up(thr, fwd_mph)
                    shifted = True
            drift_down = hold and L <= 0.1 and self.s.k["DriftHoldDownshift"] and mode == "Forward"
            if not shifted and self.gear > 1 and drift_down:
                # variant (not the contract): in a drift, step down by |v_h| like a braking downshift
                g = self.gear
                if since >= a["ShiftMinIntervalSeconds"] and rpm_road * P.ratios[g - 2] / P.ratios[g - 1] <= a["DownshiftBrakeLand"] * P.R:
                    self._shift_down(g - 1, fwd_mph)
            elif not shifted and self.gear > 1 and not hold:
                g = self.gear
                land_down = rpm_road * P.ratios[g - 2] / P.ratios[g - 1]
                if mode == "Braking" and fwd_mph > 0:
                    if since >= self.s.k["BrakeDownshiftGap"] and land_down <= a["DownshiftBrakeLand"] * P.R:
                        self._shift_down(g - 1, fwd_mph)
                elif mode == "Coasting":
                    if since >= a["ShiftMinIntervalSeconds"] and x < a["DownshiftCoastFraction"] and land_down <= a["DownshiftCoastLand"] * P.R:
                        self._shift_down(g - 1, fwd_mph)
                elif mode == "Forward" and thr >= a["KickdownThrottle"] and self.kick_hold >= a["KickdownHoldSeconds"] \
                        and x < a["KickdownBelowFraction"] and since >= a["ShiftMinIntervalSeconds"]:
                    target = g
                    while target > 1 and rpm_road * P.ratios[target - 2] / P.ratios[g - 1] <= a["KickdownLand"] * P.R:
                        target -= 1
                    if target < g:
                        self._shift_down(target, fwd_mph)
            g = self.gear
            x = v_eff / P.Vg[g - 1]
            rpm_road = x * P.R
            overdrive = a["OverdriveEnabled"] >= 0.5 and boost_applied and g == P.n and rpm_road >= P.R
        self.rpm_road = rpm_road
        self.overdrive = overdrive
        # ---- thrust (fix 1: throttle enters once)
        a_drive = 0.0
        ws_eff = 0.0
        dump = car.spin_dump
        k_shift = k_lim = 1.0
        if mode == "Forward" and self.gear >= 1:
            g = self.gear
            x_eng = 1.0 if overdrive else min(self.rpm / P.R, 1.0)
            a_raw = P.A1 * P.mult[g - 1] * torque_at(s.curve, x_eng) * clamp(thr, 0, 1)
            ws = max(0.0, a_raw / P.a_trac - 1)
            gate = fwd_mph >= -1 and car.intent == 1                              # fix 2
            ws_eff = (ws * (1 - a["TractionAssist"]) + dump) if gate else 0.0
            a_drive = min(a_raw, P.a_trac) * (1 - (1 - a["SlideGripFraction"]) * smoothstep(ws_eff / self.s.k["SlideSmoothWidth"]))
            # fix 5: cuts are time-weighted over the frame
            if self.cut_start is not None:
                since_cut = t - dt - self.cut_start
                if since_cut < s.cut_seconds + s.blend_seconds:
                    k_shift = frame_average_cut(max(since_cut, 0.0), dt, s.cut_seconds, s.blend_seconds, s.cut_torque)
                else:
                    self.cut_start = None
            lim_cond = rpm_road >= P.R and not overdrive
            if not self.lim_active and lim_cond:
                self.lim_active, self.lim_phase = True, 0.0
            elif self.lim_active and rpm_road < P.R - a["LimiterHysteresisRpm"]:
                self.lim_active = False
            if self.lim_active:
                on, off = a["LimiterOnSeconds"], a["LimiterCutSeconds"]
                k_lim = frame_average_square(self.lim_phase, dt, on, off)
                before = int(self.lim_phase // (on + off))
                self.lim_phase += dt
                self.lim_bounces += int(self.lim_phase // (on + off)) - before
            a_drive *= k_shift * k_lim * (1 - a["SpinThrustLoss"] * L)
        else:
            self.lim_active = False
        self.ws_eff = ws_eff
        self.k_shift, self.k_lim = k_shift, k_lim
        self.load = clamp(thr, 0, 1) * k_shift * k_lim
        # ---- engine rpm
        if self.gear == -1:
            rpm_t = P.I + (0.55 * P.R - P.I) * min(abs_mph / 40, 1)
        else:
            rpm_base = rpm_road
            if self.gear == 1 and thr > dz and mode == "Forward":
                rpm_base = max(rpm_road, P.I + thr * (a["LaunchRpmFraction"] * P.R - P.I))
            rpm_base = max(rpm_base, P.I)
            rpm_t = min(rpm_base * (1 + a["ThrustSlipFlare"] * min(ws_eff, 0.5)), 1.01 * P.R)
            if L > 0.1:
                rpm_t = max(rpm_t, 0.85 * P.R * clamp(thr, 0, 1))                # fix 3: free-rev in a spin
            if overdrive:
                rpm_t = P.R                                                      # fix 6: pinned, no cut
        since = t - self.last_shift
        if self.shift_kind == "Up" and since < s.cut_seconds + s.blend_seconds + 0.05:
            tau = s.shift_rpm_seconds
        elif self.shift_kind == "Down" and since < a["DownshiftBlendSeconds"] + 0.05:
            tau = a["DownshiftBlendSeconds"]
        else:
            tau = a["EngineRiseSeconds"] * (1 if rpm_t > self.rpm else a["EngineFallScale"])
        self.rpm += (rpm_t - self.rpm) * (1 - math.exp(-dt / max(tau, 1e-4)))
        # ---- resistance (fix 2: signed against velocity)
        sgn = forward_speed / max(abs(forward_speed), 0.8)
        a_res = -sgn * (P.Kd * fwd_mph * fwd_mph + P.Rb + P.Rs * abs(forward_speed))
        a_eb = 0.0
        if thr <= dz and self.gear >= 1 and fwd_mph > 0 and self.cut_start is None:
            a_eb = -sgn * P.engine_brake * (P.mult[self.gear - 1] / P.mult[-1]) * (0.35 + 0.65 * min(self.rpm / P.R, 1))
        if mode == "Forward":
            acc = a_drive + a_res
        elif mode == "Coasting":
            acc = a_res + a_eb
        elif mode == "Braking":
            acc = (P.brake * thr if fwd_mph < 0 else -P.brake * abs(thr)) + a_res + (a_eb if fwd_mph > 0 else 0.0)
        elif mode == "Reverse":
            ratio = clamp(abs(min(fwd_mph, 0)) / T.reverse_max_mph, 0, 1)
            curve_term = (1 - ratio) ** T.reverse_curve_exp if abs_mph > T.stop_mph else 1.0
            acc = -T.reverse * abs(thr) * curve_term + a_res
        else:  # Stopped
            acc = a_res
        acc += T.limiter(fwd_mph)
        if fwd_mph > P.guard_mph:                                                 # fix 6: speed guard
            acc -= (fwd_mph - P.guard_mph) / MPH * a["SpeedGuardStrength"]
        self.drive_thrust = a_drive
        self.a_res, self.a_eb = a_res, a_eb
        return acc, mode, snap, accelerating, braking, a_drive

    def _event(self, kind, to, mph):
        self.shifts.append((self.t, kind, self.gear, to, mph))

    def _shift_up(self, thr, mph):
        self._event("Up", self.gear + 1, mph)
        self.gear += 1
        self.last_shift = self.t
        self.shift_kind = "Up"
        self.cut_start = self.t - self.dt   # the cut starts with this frame's force interval

    def _shift_down(self, to, mph):
        self._event("Down", to, mph)
        self.gear = to
        self.last_shift = self.t
        self.shift_kind = "Down"                                                   # fix 4: no torque cut on downshifts
