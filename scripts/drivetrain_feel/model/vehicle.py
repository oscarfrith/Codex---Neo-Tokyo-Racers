"""2D flat-ground port of the DrivingClient heartbeat, today's path and the drivetrain path (CONTRACT 5.2-5.4).

Heading h: forward = (sin h, cos h), right = (cos h, -sin h); positive steer turns right and raises h.
state.YawHeading is `heading` (the Align target). The body follows it through the AlignOrientation, modelled as a
first-order lag at rate AlignResponsiveness (Responsiveness 22 x stability, about 40-45 ms), so forward/right and the
lateral grip use the body, exactly as root.CFrame does, while drift alignment uses YawHeading (getTerrainFrame).
Forces are applied as accelerations (mass cancels, DrivingClient:1086). No hover, no slopes, no collisions.
"""
import math

from drivetrain import Gearbox, Profile
from today import MPH, Today, balance, clamp, lerp, resolve_stats, smoothstep


class Inputs:
    __slots__ = ("throttle", "steer", "drift", "boost", "w", "s", "kind")

    def __init__(self, throttle=0.0, steer=0.0, drift=False, boost=False, w=None, s=None, kind="keyboard"):
        self.throttle, self.steer, self.drift, self.boost, self.kind = throttle, steer, drift, boost, kind
        self.w = (throttle > 0.5) if w is None else w
        self.s = (throttle < -0.5) if s is None else s

    @staticmethod
    def keys(w=False, s=False, a=False, d=False, drift=False, boost=False):
        """Keyboard: W and S cancel to 0 (DrivingClient:358-359), A and D cancel."""
        return Inputs(throttle=(1 if w else 0) - (1 if s else 0), steer=(1 if d else 0) - (1 if a else 0),
                      drift=drift, boost=boost, w=w, s=s, kind="keyboard")


def move_toward(value, target, step):
    if value < target:
        return min(value + step, target)
    return max(value - step, target)


class Vehicle:
    def __init__(self, config, car, settings=None, balance_on=True, align_lag=True, yaw_cap_drift="exempt"):
        self.c, self.car = config, car
        self.stats = resolve_stats(config, car.raw)
        self.bal = balance(config, car.pi, balance_on)
        self.T = Today(config, self.stats, self.bal)
        self.s = settings
        self.new = settings is not None and settings.a["Enabled"] >= 0.5
        self.align_lag = align_lag
        self.yaw_cap_drift = yaw_cap_drift  # "exempt": lerp out with DriftBlend x DriftCapExempt; "extra": draft x(1+1.5 DB)
        if self.new:
            self.P = Profile(self.T, settings, car.pi)
            self.gb = Gearbox(self.P, settings, self.T)
        else:
            self.P = self.gb = None
        self.reset()

    # ------------------------------------------------------------------------------------------ state
    def reset(self):
        self.t = 0.0
        self.x = self.y = self.vx = self.vy = 0.0
        self.heading = self.body = 0.0
        self.r = self.rdot = 0.0
        self.r_steer = self.r_spin = 0.0
        self.db = 0.0
        self.charge = 0.0
        self.mini_timer = self.mini_power = 0.0
        self.tank = 100.0
        self.delay_timer = 0.0
        self.hold = 0.0
        self.intent = 1
        self.reverse_asked = False
        self.boosting = False
        self.steer_lim = 0.0
        self.a_lat = 0.0
        self.spin_L = 0.0
        self.spin_dir = 0
        self.spin_peak = 0.0
        self.spin_dump = 0.0
        self.window = 0.0
        self.window_kind = None
        self.settle = 0.0
        self.g_thr_prev = 0.0
        self.lift_start = None
        self.last_low = None
        self.pb_hold = 0.0
        self.grace = False          # free-roam runs start long after spawn: start grace already over
        self.gestures = []
        self.last = {}
        if self.gb:
            self.gb.reset(1)

    def set_speed(self, mph, throttle_was=0.0):
        self.vx, self.vy = 0.0, mph / MPH
        self.heading = self.body = 0.0
        self.g_thr_prev = throttle_was
        if self.gb:
            self.gb.place(mph)
            self.gb.thr_prev = throttle_was

    @property
    def speed_mph(self):
        return math.hypot(self.vx, self.vy) * MPH

    @property
    def forward_mph(self):
        return (self.vx * math.sin(self.body) + self.vy * math.cos(self.body)) * MPH

    def slip_deg(self):
        if math.hypot(self.vx, self.vy) * MPH < 3:
            return 0.0
        direction = math.atan2(self.vx, self.vy)
        return abs(math.degrees((self.body - direction + math.pi) % (2 * math.pi) - math.pi))

    # ------------------------------------------------------------------------------------------ helpers
    def exempt(self):
        """Drift exemption weight: clamp(DriftBlend x DriftCapExempt, 0, 1). DriftCapExempt 1 = the contract's lerp by DriftBlend."""
        return clamp(self.db * self.s.a["DriftCapExempt"], 0.0, 1.0)

    def _limit_steer(self, raw, kind, dt):
        """CONTRACT 5.3 steering rate limit (refreshInput, after the inputs are summed). Gamepad untouched."""
        a, s = self.s.a, self.s
        cur = self.steer_lim
        if kind == "gamepad":
            self.steer_lim = raw
            return raw
        if kind == "touch":
            up = down = a["TouchSteerRate"]
        else:
            up = 1 / s.steer_rise if s.steer_rise > 1e-6 else 1e9
            down = a["SteerReturnRate"]
            if self.s.k["ReturnScalesWithWeight"]:
                down /= max(s.weight_dial, 0.02)    # FeelWeight 0: instant return, as today
        if raw * cur < 0:                       # reversing: return to centre first, then build
            cur = move_toward(cur, 0.0, down * dt)
            if cur == 0.0:
                cur = move_toward(cur, raw, up * dt * 0.5)
        elif abs(raw) < abs(cur):
            cur = move_toward(cur, raw, down * dt)
        else:
            cur = move_toward(cur, raw, up * dt)
        self.steer_lim = cur
        return cur

    def _gestures(self, inp, thr, raw_steer, speed_mph, dt):
        """CONTRACT 5.4 gestures. Each opens a SpinWindowSeconds window."""
        a = self.s.a
        self.window = max(0.0, self.window - dt)
        if self.window_kind == "PowerBrake" and self.window > 0:
            self.spin_dump = a["PowerBrakeDumpSlip"] * self.window / max(a["SpinWindowSeconds"], 1e-6)
        else:
            self.spin_dump = 0.0
            if self.window <= 0:
                self.window_kind = None
        if a["SpinEnabled"] < 0.5:
            self.g_thr_prev = thr
            return
        prev = self.g_thr_prev
        if thr < 0.3 <= prev:
            self.lift_start = self.t     # a lift: throttle fell from >= 0.3 to below 0.3
        if thr < 0.3:
            self.last_low = self.t       # last moment the throttle was below 0.3 (analog stab rate)
        steer_ok = abs(raw_steer) >= a["SpinStabSteer"] and speed_mph < a["SpinBelowMph"]
        opened = None
        if thr >= 0.9 > prev and steer_ok:
            if inp.kind == "gamepad":
                # analog stab: from below 0.3 to 0.9 faster than SpinAnalogRate per second
                if self.last_low is not None and (0.9 - 0.3) / max(self.t - self.last_low, 1e-6) > a["SpinAnalogRate"]:
                    opened = "AnalogStab"
            elif self.s.k["StabNeedsLift"]:
                if self.lift_start is not None and self.t - self.lift_start <= a["SpinStabSeconds"]:
                    opened = "Stab"              # lift-and-stab: a lift (>=0.3 to <0.3) then >= 0.9 within the window
            elif self.last_low is not None and self.t - self.last_low <= a["SpinStabSeconds"]:
                opened = "Stab"                  # literal reading: any rise from < 0.3 to >= 0.9 (every W press)
        # power-brake: W and S held at a standstill, then S released
        both = inp.w and inp.s
        if both and speed_mph < 1.5:
            self.pb_hold += dt
        elif self.pb_hold > 0:
            if a["PowerBrakeEnabled"] >= 0.5 and self.pb_hold >= a["PowerBrakeMinHold"] and inp.w and not inp.s:
                opened = "PowerBrake"
            self.pb_hold = 0.0
        if opened:
            self.window = a["SpinWindowSeconds"]
            self.window_kind = opened
            self.gestures.append((round(self.t, 3), opened, round(speed_mph, 1)))
            if opened == "PowerBrake":
                self.spin_dump = a["PowerBrakeDumpSlip"]
        self.g_thr_prev = thr

    def _spin_update(self, inp, thr, raw_steer, steer, speed_mph, drifting, dt):
        a, k, P = self.s.a, self.s.k, self.P
        L = self.spin_L
        if a["SpinEnabled"] < 0.5 or drifting or self.grace:
            target = 0.0
        else:
            ws = self.gb.ws_eff
            target = (smoothstep((ws - a["SpinSlipStart"]) / max(a["SpinSlipWidth"], 1e-6))
                      * smoothstep((abs(steer) - a["SpinSteerStart"]) / max(a["SpinSteerWidth"], 1e-6))
                      * (1 - smoothstep((speed_mph - a["SpinBelowMph"]) / max(a["SpinFadeMph"], 1e-6)))
                      * smoothstep((abs(self.r) - k["SpinYawGate"]) / k["SpinYawGateWidth"]))
            target *= a["FeelSpin"] * P.spin_tier * (a["SpinTouchScale"] if inp.kind == "touch" else 1.0)
            target = min(target, 1.0)
            if self.window <= 0:
                target = min(target, a["SpinHoldCap"])
        catching = thr < 0.3 or (self.spin_dir != 0 and raw_steer * self.spin_dir < 0 and abs(raw_steer) > 0.3)
        if catching and L > 0:
            target, rate = 0.0, a["SpinCatchRate"]
        elif target > L:
            rate = a["SpinBuildRate"]
        else:
            rate = a["SpinDecayRate"]
        previous = L
        L = clamp(L + (target - L) * (1 - math.exp(-rate * dt)), 0.0, 1.0)
        if self.spin_dir == 0 and L > 0.05:
            self.spin_dir = (1 if self.r > 0 else -1) if abs(self.r) > 0.05 else (1 if steer >= 0 else -1)
        self.spin_peak = max(self.spin_peak, L)
        if self.spin_peak >= 0.2 and L < 0.1 <= previous:
            self.settle = a["SpinSettleSeconds"]
        if L < 0.02:
            self.spin_dir = 0
            if L < previous or L == 0:
                self.spin_peak = 0.0 if self.settle <= 0 else self.spin_peak
        self.spin_L = L

    def _yaw(self, r_cmd, fwd, speed, speed_mph, dt):
        """CONTRACT 5.3 yaw-rate state: grip cap, second-order spring, unwind, kinematic blend, spin term, caps."""
        a, k, s, P, T = self.s.a, self.s.k, self.s, self.P, self.T
        L = self.spin_L
        if self.intent == 1 and fwd > 8:
            cap = a["YawCapMargin"] * P.a_cap(T, speed_mph, s) / max(speed, 1e-6)
            if self.yaw_cap_drift == "extra":
                cap *= 1 + k["YawCapDriftExtra"] * self.db
                r_cmd = clamp(r_cmd, -cap, cap)
            else:
                r_cmd = lerp(clamp(r_cmd, -cap, cap), r_cmd, self.exempt())
        self.last["r_cmd"] = r_cmd
        if k["SpinYawModel"] == "additive":
            self._yaw_additive(r_cmd, speed_mph, L, dt)
            return
        if s.yaw_kinematic and L < 0.02 and self.settle <= 0:
            self.r, self.rdot = r_cmd, 0.0          # FeelWeight 0: today's kinematic yaw
            return
        base = a["YawOmega"] * P.yaw_weight
        omega = base / max(s.weight_dial, 0.05)
        # unwind faster after a steer release; not while a spin is what holds r above r_cmd (it would fight the spin)
        if (abs(r_cmd) < abs(self.r) or r_cmd * self.r < 0) and L < k["UnwindMaxSpin"]:
            omega *= a["YawUnwindScale"]
        if k["SpinSoftensToBase"]:
            # the spin softens toward an omega that FeelWeight does not scale, so FeelSpin works at every FeelWeight
            omega = max(lerp(omega, base * (1 - k["SpinYawAuthorityLoss"]), L), 1.0)
        else:
            omega = max(omega * (1 - k["SpinYawAuthorityLoss"] * L), 1.0)
        if self.settle > 0:
            self.settle = max(0.0, self.settle - dt)
            self.r += (r_cmd - self.r) * (1 - math.exp(-dt * 3 / max(a["SpinSettleSeconds"], 1e-3)))
            self.rdot = 0.0
        else:
            n = max(1, int(math.ceil(dt * omega / 0.2)))
            h = dt / n
            zeta = a["YawDamping"]
            for _ in range(n):  # semi-implicit sub-steps keep the spring stable at 20 Hz
                self.rdot += (omega * omega * (r_cmd - self.r) - 2 * zeta * omega * self.rdot) * h
                self.r += self.rdot * h
        if L > 0 and self.spin_dir != 0 and self.r * self.spin_dir > 0:
            accel = a["SpinYawAccel"] * L * (0.6 + 0.4 * min(self.gb.ws_eff / 0.5, 1))
            self.r += self.spin_dir * accel * dt
        w = smoothstep(speed_mph / max(a["YawKinematicBelowMph"], 1e-6))
        if k["DriftYawExempt"]:
            w *= 1 - self.exempt()          # variant: the drift owns yaw, as it owns lateral grip
        spin_w = smoothstep(L / k["SpinDynamicBlendL"]) if k["SpinDynamicBlendL"] else 0.0
        w = max(w, spin_w, 1.0 if self.settle > 0 else 0.0)
        self.r = r_cmd + (self.r - r_cmd) * w
        self.rdot *= w
        limit = a["YawRateMax"]
        if L > 0.02:
            limit = min(limit, max(a["SpinMaxYawRate"], abs(r_cmd)))
        self.r = clamp(self.r, -limit, limit)

    def _yaw_additive(self, r_cmd, speed_mph, L, dt):
        """Variant: r = r_steer + r_spin. r_steer is the steering spring (FeelWeight, unwind, kinematic blend, drift
        exemption); r_spin is driven by SpinYawAccel while r x dir > 0 and decays at k_s = max(w_base (1 - 0.85 L), 1) / (2 zeta),
        which gives the same steady spin offset as the single-state spring at FeelWeight 1. FeelWeight never touches r_spin."""
        a, k, s, P = self.s.a, self.s.k, self.s, self.P
        base = a["YawOmega"] * P.yaw_weight
        zeta = a["YawDamping"]
        if s.yaw_kinematic:
            self.r_steer, self.rdot = r_cmd, 0.0
        else:
            omega = base / max(s.weight_dial, 0.05)
            if abs(r_cmd) < abs(self.r_steer) or r_cmd * self.r_steer < 0:
                omega *= a["YawUnwindScale"]
            omega = max(omega * (1 - k["SpinYawAuthorityLoss"] * L), 1.0)
            n = max(1, int(math.ceil(dt * omega / 0.2)))
            h = dt / n
            for _ in range(n):
                self.rdot += (omega * omega * (r_cmd - self.r_steer) - 2 * zeta * omega * self.rdot) * h
                self.r_steer += self.rdot * h
            w = smoothstep(speed_mph / max(a["YawKinematicBelowMph"], 1e-6))
            if k["DriftYawExempt"]:
                w *= 1 - self.exempt()
            self.r_steer = r_cmd + (self.r_steer - r_cmd) * w
            self.rdot *= w
        k_s = max(base * (1 - k["SpinYawAuthorityLoss"] * L), 1.0) / (2 * zeta)
        if self.settle > 0:
            self.settle = max(0.0, self.settle - dt)
            k_s = max(k_s, 3 / max(a["SpinSettleSeconds"], 1e-3))
        alpha = 0.0
        if L > 0 and self.spin_dir != 0 and (self.r_steer + self.r_spin) * self.spin_dir > 0:
            alpha = self.spin_dir * a["SpinYawAccel"] * L * (0.6 + 0.4 * min(self.gb.ws_eff / 0.5, 1))
        target = alpha / k_s
        self.r_spin = target + (self.r_spin - target) * math.exp(-k_s * dt)
        limit = a["YawRateMax"]
        if L > 0.02:
            limit = min(limit, max(a["SpinMaxYawRate"], abs(r_cmd)))
        total = clamp(self.r_steer + self.r_spin, -limit, limit)
        self.r_spin = total - self.r_steer
        self.r = total

    # ------------------------------------------------------------------------------------------ heartbeat
    def step(self, inp, dt):
        T = self.T
        self.t += dt
        thr, raw_steer = clamp(inp.throttle, -1, 1), clamp(inp.steer, -1, 1)
        steer = self._limit_steer(raw_steer, inp.kind, dt) if self.new else raw_steer
        h = self.body
        fx, fy = math.sin(h), math.cos(h)
        rx, ry = math.cos(h), -math.sin(h)
        fwd = self.vx * fx + self.vy * fy
        side = self.vx * rx + self.vy * ry
        speed = math.hypot(self.vx, self.vy)
        speed_mph = speed * MPH
        can_drift = inp.drift and fwd > 8 and speed_mph > 10 and abs(steer) > 0
        self.db += ((1.0 if can_drift else 0.0) - self.db) * clamp(dt * 5.2, 0, 1)
        drifting = self.db > 0.12
        boost_ok = inp.boost and self.tank > 1 and fwd > -4 and T.boost_power > 0
        mini_active = self.mini_timer > 0
        if self.new:
            self._gestures(inp, thr, raw_steer, speed_mph, dt)
            acc, mode, snap, accelerating, braking, drive = self.gb.step(self, thr, fwd, speed_mph, self.db, boost_ok or mini_active, dt)
        else:
            acc, mode, snap, self.hold, accelerating, braking = T.step_longitudinal(thr, fwd, self.hold, dt)
            drive = acc if acc > 0 else 0.0   # drift engine assist reads LongitudinalAcceleration > 0 today
        ax, ay = fx * acc, fy * acc
        if snap:
            self.vx -= fx * fwd
            self.vy -= fy * fwd
            fwd = 0.0
        # DRIVE-01 steering intent (DrivingClient:1255-1285)
        signed = fwd * MPH
        if thr > T.intent_deadzone:
            self.intent, self.reverse_asked = 1, False
        elif thr < -T.intent_deadzone:
            if (braking and fwd > 0) or signed > T.coast_dir_mph:
                self.intent = 1
            else:
                self.intent, self.reverse_asked = -1, True
        elif T.coast_assume_forward:
            reverse_at = T.coast_dir_mph if self.reverse_asked else T.coast_reverse_mph
            if signed < -reverse_at:
                self.intent = -1
            else:
                self.intent, self.reverse_asked = 1, False
        elif signed < -T.coast_dir_mph:
            self.intent = -1
        elif signed > T.coast_dir_mph:
            self.intent = 1
        steering_input = -steer if self.intent < 0 else steer
        if self.new:
            self._spin_update(inp, thr, raw_steer, steer, speed_mph, drifting, dt)
        # lateral grip (DrivingClient:1297-1298, or CONTRACT 5.3 when active)
        lat = T.lateral_grip(speed_mph, self.db)
        if self.new:
            a, k = self.s.a, self.s.k
            a_lin = -side * lat * (1 - a["SpinGripLoss"] * self.spin_L)
            a_cap = self.P.a_cap(T, speed_mph, self.s)
            C = a["LateralCurveShape"]
            B = k["LateralCurveB"] or 1.0 / C
            shaped = a_cap * math.sin(C * math.atan(B * a_lin / a_cap))
            if self.s.grip_relax > 1e-6:
                self.a_lat += (shaped - self.a_lat) * (1 - math.exp(-dt * max(speed, 8) / self.s.grip_relax))
            else:
                self.a_lat = shaped
            a_side = lerp(self.a_lat, a_lin, self.exempt())
        else:
            a_side = -side * lat
        ax += rx * a_side
        ay += ry * a_side
        # drift block (DrivingClient:1305-1390)
        if drifting:
            coefficient = (T.drift_drag_base + T.drift_drag_extra * self.db) * self.db
            slow = max(fwd, 0) * coefficient
            ax -= fx * slow
            ay -= fy * slow
            push = T.drift_side_force * self.db * (-steering_input)
            ax += rx * push
            ay += ry * push
            alpha = clamp((thr - T.drift_throttle_min) / max(1 - T.drift_throttle_min, 0.001), 0, 1)
            if alpha > 0:
                if self.new and self.s.k["DriftAssistPlateauShare"] > 0:
                    # variant: blend the gear's gross thrust toward today's flat plateau A1 x thr
                    drive = lerp(drive, self.P.A1 * clamp(thr, 0, 1), self.s.k["DriftAssistPlateauShare"])
                if drive > 0:  # today: net LongitudinalAcceleration; new: gross DriveThrust (fix 7)
                    assist = drive * T.drift_engine_assist * self.db * alpha
                    ax += fx * assist
                    ay += fy * assist
                if speed > 1:
                    tfx, tfy = math.sin(self.heading), math.cos(self.heading)
                    rate = T.drift_align_rate * self.db * alpha
                    gx, gy = (tfx * speed - self.vx) * rate, (tfy * speed - self.vy) * rate
                    magnitude = math.hypot(gx, gy)
                    if magnitude > T.drift_align_max:
                        gx, gy = gx / magnitude * T.drift_align_max, gy / magnitude * T.drift_align_max
                    ax += gx
                    ay += gy
            self.charge = min(3.25, self.charge + dt * (0.95 + abs(steering_input) * 1.15) * self.db * T.drift_charge_mult)
        elif not inp.drift and self.charge > 0:
            if self.charge > T.mini_min_charge and thr > T.mini_threshold:
                q = clamp((self.charge - T.mini_min_charge) / (T.mini_full - T.mini_min_charge), 0, 1) ** T.mini_exp
                self.mini_timer = T.mini_duration(q)
                self.mini_power = T.mini_power(q)
            self.charge = 0.0
        # boost (DrivingClient:1392-1423); new: x BoostShare(v) (fix 6)
        if mini_active:
            self.mini_timer = max(0.0, self.mini_timer - dt)
        share = self.P.share(fwd * MPH, self.s) if self.new else 1.0
        boost_push = 0.0
        if boost_ok:
            self.tank = max(0.0, self.tank - (100 / T.boost_duration) * dt)
            self.delay_timer = T.boost_delay
            boost_push = T.boost_accel * share
            self.boosting = True
        elif mini_active:
            boost_push = self.mini_power * T.mini_apply * T.bal["MiniBoost"] * share
            self.boosting = True
        else:
            if inp.boost and T.boost_power > 0:
                self.delay_timer = T.boost_delay
            elif self.delay_timer > 0:
                self.delay_timer = max(0.0, self.delay_timer - dt)
            else:
                self.tank = min(100.0, self.tank + (100 / T.boost_recharge) * dt)
            self.mini_power = 0.0
            self.boosting = False
        ax += fx * boost_push
        ay += fy * boost_push
        # turn rate and yaw (DrivingClient:1428-1493)
        turn = T.turn_rate(fwd, speed_mph, self.intent, drifting, self.boosting)
        r_cmd = steering_input * turn
        if self.new:
            r_before = self.r
            self._yaw(r_cmd, fwd, speed, speed_mph, dt)
            if self.s.yaw_kinematic and self.spin_L < 0.02:
                self.heading += self.r * dt                  # FeelWeight 0: today's line
            else:
                self.heading += 0.5 * (r_before + self.r) * dt   # frame-average yaw rate: frame-rate independent run-on
        else:
            self.r = r_cmd
            self.last["r_cmd"] = r_cmd
            self.heading += self.r * dt                      # DrivingClient:1493
        # integrate (forces act until the next Heartbeat)
        self.vx += ax * dt
        self.vy += ay * dt
        self.x += self.vx * dt
        self.y += self.vy * dt
        if self.align_lag:
            self.body += (self.heading - self.body) * (1 - math.exp(-T.align_responsiveness * dt))
        else:
            self.body = self.heading
        last = self.last
        last["mode"], last["acc"], last["drive"], last["boost"] = mode, acc, drive, boost_push
        last["a_side"], last["turn"] = a_side, turn
        return last
