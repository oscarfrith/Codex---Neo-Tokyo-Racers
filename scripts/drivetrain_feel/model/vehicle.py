"""2D flat-ground port of the DrivingClient heartbeat, today's path and the drivetrain path (CONTRACT 5.2-5.4 as amended
by the fix spec, reviews/15_fix_spec.md section C).

Heading h: forward = (sin h, cos h), right = (cos h, -sin h); positive steer turns right and raises h (the Luau code has
the opposite sign: command = -steeringInput x turnRate; every sign test here is the mirror of the Luau one).
state.YawHeading is `heading` (the Align target). The body follows it through the AlignOrientation, modelled as a
first-order lag at rate AlignResponsiveness (Responsiveness 22 x stability, about 40-45 ms), so forward/right and the
lateral grip use the body, exactly as root.CFrame does, while drift alignment uses YawHeading (getTerrainFrame).
Forces are applied as accelerations (mass cancels, DrivingClient:1086). No hover, no slopes, no collisions.

Order per frame, as the heartbeat: refreshInput (steer limiter, AnalogInput latch) -> drivetrainResume (first moving
frame after an anchored spell or a reset request) -> DriftBlend -> drivetrainGestures -> StepDrivetrain -> DRIVE-01
intent -> drivetrainLateral -> drift block -> boost -> turn rate -> drivetrainYaw (updateSpin inside). An anchored frame
(Vehicle.anchored) is refreshInput -> drivetrainAnchored (N, chassis reset, StepNeutral) and nothing else.
"""
import math

from drivetrain import Gearbox, Profile
from today import MPH, Today, balance, clamp, lerp, resolve_stats, smoothstep

BIG = 1e9


class Inputs:
    """One frame of input. kind is the steering device: keyboard (the steer limiter), touch (the touch limiter) or
    gamepad (the stick, zeroed at |x| <= 0.12). throttle_kind is the throttle device (default: kind): keyboard W/S
    (w, s), touch (the summed mobile throttle) or the gamepad triggers (accel R2, brake L2; throttle = accel - brake,
    and a plain throttle on a gamepad becomes accel or brake)."""
    __slots__ = ("throttle", "steer", "drift", "boost", "w", "s", "kind", "throttle_kind", "accel", "brake")

    def __init__(self, throttle=0.0, steer=0.0, drift=False, boost=False, w=None, s=None, kind="keyboard",
                 throttle_kind=None, accel=None, brake=None):
        self.steer, self.drift, self.boost, self.kind = steer, drift, boost, kind
        self.throttle_kind = kind if throttle_kind is None else throttle_kind
        if self.throttle_kind == "gamepad":
            if accel is None and brake is None:
                accel, brake = max(throttle, 0.0), max(-throttle, 0.0)
            accel, brake = clamp(accel or 0.0, 0.0, 1.0), clamp(brake or 0.0, 0.0, 1.0)
            throttle = accel - brake
        else:
            accel = brake = 0.0
        self.throttle, self.accel, self.brake = throttle, accel, brake
        self.w = (throttle > 0.5) if w is None else w
        self.s = (throttle < -0.5) if s is None else s

    @staticmethod
    def keys(w=False, s=False, a=False, d=False, drift=False, boost=False):
        """Keyboard: W and S cancel to 0 (DrivingClient:358-359), A and D cancel."""
        return Inputs(throttle=(1 if w else 0) - (1 if s else 0), steer=(1 if d else 0) - (1 if a else 0),
                      drift=drift, boost=boost, w=w, s=s, kind="keyboard")


def approach_steer(current, target, build, ret, dt):
    """DrivingClient approachSteer: build rate away from centre, return rate back toward it; a reversal returns to 0
    first (and stops there for the frame)."""
    rate, goal = build, target
    if current * target < 0 or abs(target) < abs(current):
        rate = ret
        if current * target < 0:
            goal = 0.0
    step = rate * dt
    if abs(goal - current) <= step:
        return goal
    return current + (step if goal > current else -step)


class Vehicle:
    def __init__(self, config, car, settings=None, balance_on=True, align_lag=True):
        self.c, self.car = config, car
        self.stats = resolve_stats(config, car.raw)
        self.bal = balance(config, car.pi, balance_on)
        self.T = Today(config, self.stats, self.bal)
        self.s = settings
        self.new = settings is not None and settings.on("Enabled")
        self.align_lag = align_lag
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
        self.db = 0.0
        self.charge = 0.0
        self.mini_timer = self.mini_power = 0.0
        self.tank = 100.0
        self.delay_timer = 0.0
        self.hold = 0.0
        self.intent = 1
        self.reverse_asked = False
        self.boosting = False
        self.boost_applied = False      # Drivetrain.BoostApplied (read by next frame's StepDrivetrain)
        self.analog_input = False       # Drivetrain.AnalogInput (latched last throttle device)
        self.was_anchored = False       # Drivetrain.WasAnchored
        self.reset_pending = False      # Drivetrain.ResetPending
        self.gestures = []
        self.last = {}
        self.reset_chassis()
        # free-roam runs start long after spawn: the start grace is already over (a harness choice; the grace table and
        # the race start test it). The flick latch starts as resetDrivetrainChassis leaves it (SteerLow false)
        self.grace_clock, self.grace_speed_reached, self.grace_needs_speed = BIG, True, False
        self.r = 0.0
        if self.gb:
            self.gb.reset(0.0)

    def reset_chassis(self):
        """resetDrivetrainChassis: yaw state (both parts), spin, gesture clocks, steer limiter, lateral filter."""
        self.r = self.r_steer = self.r_vel = self.r_spin = 0.0
        self.authority = 1.0
        self.a_lat = 0.0
        self.lat_cap = 0.0
        self.steer_kb = self.steer_touch = 0.0
        self.spin_L = 0.0
        self.spin_dir = 0
        self.spin_target = 0.0
        self.spin_accel = 0.0
        self.window = 0.0
        self.warn = False
        self.settling = False
        self.was_on = False
        self.armed = False
        self.rise_clock = 0.0
        self.low_clock = 0.0
        self.thr_clock = self.flick_clock = BIG
        self.prev_raw = 0.0
        self.steer_low = False
        self.caught = False
        self.pb_clock = 0.0
        self.pb_held = False
        self.dump_slip = self.dump_clock = 0.0
        self.extra_slip = 0.0
        # the start grace restarts without its speed clause (C3: false for every reset but the anchored resume and the
        # DriveReady edge); BoostApplied and BoostAccel clear
        self.grace_clock, self.grace_speed_reached, self.grace_needs_speed = 0.0, False, False
        self.boost_applied = False
        self.warn_seen = False

    def set_speed(self, mph):
        """Place the car at mph along +y, the gearbox exactly as Model.ResetGearbox leaves it at that speed (LiftClock 10,
        Duty 0, SteadyMph = mph: the ResetPending path's gearbox)."""
        self.vx, self.vy = 0.0, mph / MPH
        self.heading = self.body = 0.0
        if self.gb:
            self.gb.place(mph)

    def warm_start(self, throttle_was):
        """Scenario harness, not a Lua reset path: the car has been driving at throttle_was for a while before t=0, so
        the C9 duty average is there and the stab latch knows the throttle was on (spin.WasOn). A Lua reset at speed
        leaves Duty 0 and WasOn false."""
        self.was_on = throttle_was >= 0.3
        if self.gb:
            self.gb.duty = throttle_was

    def request_reset(self):
        """Controller.ResetVehicle (R): velocity zeroed, steering intent forward, the body squared to YawHeading, the
        chassis reset now and ResetPending set, so the next moving frame resets the chassis again and the gearbox at its
        road speed (drivetrainResume)."""
        self.vx = self.vy = 0.0
        self.intent, self.reverse_asked = 1, False
        self.body = self.heading
        if self.new:
            self.reset_chassis()
            self.reset_pending = True

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
        """C5: w = DriftCapExempt and clamp(DriftBlend x DriftExemptGain, 0, 1) or 0 (DriftCapExempt is a 0/1 switch)."""
        if not self.s.on("DriftCapExempt"):
            return 0.0
        return clamp(self.db * self.s.a["DriftExemptGain"], 0.0, 1.0)

    def _refresh_input(self, inp, raw, step):
        """refreshInput steering rate limit. C8: the steer for the frame is the trapezoid average of the limiter's start
        and end values. Gamepad analog is untouched; FeelWeight <= 0 bypasses approachSteer (R13 #13)."""
        s = self.s
        if s.weight_dial <= 0:
            self.steer_kb = raw if inp.kind == "keyboard" else 0.0
            self.steer_touch = raw if inp.kind == "touch" else 0.0
            return raw
        kb_target = raw if inp.kind == "keyboard" else 0.0
        touch_target = raw if inp.kind == "touch" else 0.0
        kb0, touch0 = self.steer_kb, self.steer_touch
        self.steer_kb = approach_steer(kb0, kb_target, s.steer_build, s.steer_return, step)
        self.steer_touch = approach_steer(touch0, touch_target, s.touch_rate, s.touch_rate, step)
        pad = raw if inp.kind == "gamepad" else 0.0
        return clamp(0.5 * (kb0 + self.steer_kb) + pad + 0.5 * (touch0 + self.steer_touch), -1, 1)

    def _gestures(self, inp, thr, raw, speed_mph, step):
        """drivetrainGestures with the fix spec C2 (lift, then flick and stab together) and C3 (grace clocks)."""
        a, s = self.s.a, self.s
        self.grace_clock += step
        if speed_mph > a["SpinStartGraceMph"]:
            self.grace_speed_reached = True
        self.window = max(self.window - step, 0.0)
        self.dump_clock += step
        self.thr_clock += step
        self.flick_clock += step
        analog = inp.throttle_kind == "gamepad" and inp.accel > 0.05          # Drivetrain.AnalogThrottle (R2 > 0.05)
        fwd = max(thr, 0.0)
        # throttle event: armed only by a lift (>= 0.3 to < 0.3); keyboard/touch back to >= 0.9 within SpinStabSeconds
        # of that lift; analog: the rise from < 0.3 to >= 0.9 faster than SpinAnalogRate per second, after an armed lift
        if self.armed:
            self.rise_clock += step
        if fwd < 0.3:
            if self.was_on:
                self.armed, self.rise_clock = True, 0.0
            self.was_on = False
            self.low_clock = 0.0
        else:
            self.was_on = True
            self.low_clock += step
            if self.armed and fwd >= 0.9:
                self.armed = False
                if analog:
                    ok = self.low_clock <= 0.6 / a["SpinAnalogRate"] + step
                else:
                    ok = self.rise_clock <= a["SpinStabSeconds"] + step
                if ok:
                    self.thr_clock = 0.0
        # flick event: |raw steer| rises from < 0.5 (or < SpinStabSteer when lower) to >= SpinStabSteer, or reverses sign
        # while past SpinStabSteer
        mag = abs(raw)
        if mag >= a["SpinStabSteer"] and (self.steer_low or raw * self.prev_raw < 0):
            self.flick_clock = 0.0
        if mag < min(0.5, a["SpinStabSteer"]):
            self.steer_low = True
        elif mag >= a["SpinStabSteer"]:
            self.steer_low = False
        self.prev_raw = raw
        flick_ok = (not s.on("SpinStabNeedsFlick")) or self.flick_clock <= a["SpinFlickSeconds"]
        if (self.thr_clock <= a["SpinFlickSeconds"] and flick_ok and fwd >= 0.9 and mag >= a["SpinStabSteer"]
                and speed_mph < a["SpinBelowMph"]):
            current = self.dump_slip * max(1 - self.dump_clock / max(a["SpinWindowSeconds"], 0.05), 0.0)
            self.window = a["SpinWindowSeconds"]
            self.dump_slip, self.dump_clock = max(current, a["SpinStabDumpSlip"]), 0.0
            self.thr_clock = self.flick_clock = BIG
            self.gestures.append((round(self.t, 3), "AnalogStab" if analog else "Stab", round(speed_mph, 1)))
        # power-brake: forward and brake held together at a standstill for PowerBrakeMinHold, then the brake released
        # with the throttle held: W and S together, or R2 and L2 both past 0.5 (touch has one summed throttle value, so no
        # power-brake input on touch)
        tk = inp.throttle_kind
        pb_input = (tk == "keyboard" and inp.w and inp.s) or (tk == "gamepad" and inp.accel > 0.5 and inp.brake > 0.5)
        if s.on("PowerBrakeEnabled") and pb_input and speed_mph < a["StopGearMph"]:
            self.pb_clock += step
        else:
            if self.pb_clock >= a["PowerBrakeMinHold"] and thr > 0.5:
                self.window = a["SpinWindowSeconds"]
                self.dump_slip, self.dump_clock = a["PowerBrakeDumpSlip"], 0.0
                self.gb.launch(1.0)
                self.gestures.append((round(self.t, 3), "PowerBrake", round(speed_mph, 1)))
            self.pb_clock = 0.0
        self.pb_held = self.pb_clock > 0
        self.extra_slip = self.dump_slip * max(1 - self.dump_clock / max(a["SpinWindowSeconds"], 0.05), 0.0) if self.dump_slip > 0 else 0.0
        return analog

    def _spin_update(self, step, thr, steer, raw, speed_mph, slip, command, touch):
        """updateSpin with C3 (grace) and C4 (hold cap x FeelSpin, warning above the hold cap)."""
        a, s, P, k = self.s.a, self.s, self.P, self.s.k
        L = self.spin_L
        target = 0.0
        grace_over = self.grace_clock >= a["SpinStartGraceSeconds"] and (
            a["SpinStartGraceMph"] <= 0 or not self.grace_needs_speed or self.grace_speed_reached)
        if s.on("SpinEnabled") and grace_over and self.db <= 0.12 and a["FeelSpin"] > 0:
            target = (smoothstep((slip - a["SpinSlipStart"]) / a["SpinSlipWidth"])
                      * smoothstep((abs(steer) - a["SpinSteerStart"]) / a["SpinSteerWidth"])
                      * (1 - smoothstep((speed_mph - a["SpinBelowMph"]) / a["SpinFadeMph"]))
                      * smoothstep((abs(self.r) - k["SpinYawGate"]) / k["SpinYawGateWidth"])
                      * a["FeelSpin"] * P.spin_tier * (a["SpinTouchScale"] if touch else 1.0))
            if self.window <= 0:
                target = min(target, s.hold_cap)
            target = clamp(target, 0.0, 1.0)
        catching = thr < 0.3 or (self.spin_dir != 0 and raw * self.spin_dir < 0 and abs(raw) > 0.3)
        rate = a["SpinDecayRate"]
        if catching:
            target, rate = 0.0, a["SpinCatchRate"]
        elif target > L:
            rate = a["SpinBuildRate"]
        previous = L
        L = clamp(L + (target - L) * (1 - math.exp(-rate * step)), 0.0, 1.0)
        self.spin_target = target
        rising = L > previous + 1e-4
        self.warn = L > s.warn_level and rising
        self.warn_seen = self.warn_seen or self.warn
        # C1: after a catch (until the spin builds again), while L falls, the spin yaw settles at >= 3 / SpinSettleSeconds
        if catching:
            self.caught = True
        elif rising:
            self.caught = False
        self.settling = self.caught and L < previous
        if L > 0.05 and self.spin_dir == 0:
            source = self.r if self.r != 0 else command
            self.spin_dir = 1 if source > 0 else (-1 if source < 0 else 0)
        elif L < 0.02:
            self.spin_dir = 0
        self.spin_L = L
        self.spin_accel = self.spin_dir * a["SpinYawAccel"] * a["FeelSpin"] * L * (0.6 + 0.4 * min(slip / 0.5, 1.0))

    def _lateral(self, side, speed_mph, hspeed, step):
        """drivetrainLateral: the normal grip on a peaked curve sin(C atan(u / C)) peaking at the cap, x (1 - SpinGripLoss
        L), built over GripRelaxStuds x FeelWeight; the drift share is today's uncapped grip by weight w (C5)."""
        a, s, P, T = self.s.a, self.s, self.P, self.T
        cap = P.a_cap(T, speed_mph)
        self.lat_cap = cap
        lateral_grip = T.lateral_grip(speed_mph, self.db)
        exempt = s.on("DriftCapExempt")
        grip = T.normal_grip_base * T.downforce(speed_mph) if exempt else lateral_grip
        target = -side * grip
        if cap > 0:
            C = a["LateralCurveShape"]
            target = cap * math.sin(C * math.atan(target / (cap * C)))
        target *= 1 - a["SpinGripLoss"] * self.spin_L
        relax = s.grip_relax
        if relax <= 0:
            self.a_lat = target
        else:
            self.a_lat += (target - self.a_lat) * (1 - math.exp(-step * max(hspeed, 8) / relax))
        applied = self.a_lat
        w = self.exempt()
        if exempt and w > 0:
            applied += (-side * lateral_grip - applied) * w
        return applied

    def _yaw(self, command, thr, steer, raw, speed_mph, fwd, slip, step, touch):
        """drivetrainYaw with C1 (r = r_steer + r_spin), C5 (drift weight w) and C7 (omega cap 60, frame-average rate).
        Returns the frame-average yaw rate that YawHeading integrates."""
        a, s, P, k = self.s.a, self.s, self.P, self.s.k
        w = self.exempt()
        if self.intent == 1 and fwd > 8 and self.lat_cap > 0:
            limit = a["YawCapMargin"] * self.lat_cap * (1 + 1.5 * self.db) / fwd
            capped = clamp(command, -limit, limit)
            command = capped + (command - capped) * w if s.on("DriftCapExempt") else capped
        self.last["r_cmd"] = command
        self._spin_update(step, thr, steer, raw, speed_mph, slip, command, touch)
        L = self.spin_L
        loss = a["SpinYawAuthorityLoss"]
        rate, rv, rs = self.r_steer, self.r_vel, self.r_spin
        omega = P.yaw_omega / max(s.weight_dial, 0.05)
        if abs(command) < abs(rate) or command * rate < 0:
            omega *= a["YawUnwindScale"]
        authority = 1 - loss * L
        if authority < self.authority:
            self.authority = authority
        else:
            self.authority += (authority - self.authority) * (1 - math.exp(-step / max(a["SpinSettleSeconds"], 0.01)))
        omega = min(max(omega * self.authority, 1.0), k["YawOmegaCap"])
        zeta = a["YawDamping"]
        k_s = max(P.yaw_omega * (1 - loss * L), 1.0) / (2 * zeta)
        if self.settling:
            k_s = max(k_s, 3 / max(a["SpinSettleSeconds"], 0.01))
        push = self.spin_accel
        spin_cap = min(a["SpinMaxYawRate"], a["YawRateMax"])
        steps = int(clamp(math.ceil(step * max(omega, k_s) * 4), 1, 16))
        h = step / steps
        decay = min(k_s * h, 1.0)
        sum_steer = sum_spin = 0.0
        d = self.spin_dir
        for _ in range(steps):
            total = rate + rs                                   # the push gate reads the sub-step's start values
            drive = push if (push != 0 and total * d > 0 and abs(total) < spin_cap) else 0.0
            rv += (omega * omega * (command - rate) - 2 * zeta * omega * rv) * h
            rate += rv * h
            rs += drive * h - rs * decay
            sum_steer += rate * h
            sum_spin += rs * h
        K = a["YawKinematicBelowMph"]
        dynamic = smoothstep(speed_mph / K) if K > 0 else 1.0
        if s.weight_dial <= 0:
            dynamic = 0.0
        dynamic *= 1 - w * a["DriftYawExempt"]
        rate = command + (rate - command) * dynamic
        rv *= dynamic
        ymax = a["YawRateMax"]
        rate = clamp(rate, -ymax, ymax)
        total = clamp(rate + rs, -ymax, ymax)
        self.r_steer, self.r_vel, self.r_spin, self.r = rate, rv, rs, total
        if step <= 0:
            return total
        return clamp(command + (sum_steer / step - command) * dynamic + sum_spin / step, -ymax, ymax)

    # ------------------------------------------------------------------------------------------ heartbeat
    def _input(self, inp, step):
        """refreshInput: the raw steer (readGamepad zeroes the stick at |x| <= 0.12), the steer limiter and the last
        throttle device latch. Runs on anchored frames too."""
        thr, raw_steer = clamp(inp.throttle, -1, 1), clamp(inp.steer, -1, 1)
        if inp.kind == "gamepad" and abs(raw_steer) <= 0.12:
            raw_steer = 0.0
        steer = raw_steer
        if self.new:
            steer = self._refresh_input(inp, raw_steer, step)
            # Drivetrain.AnalogInput: W/Up held (even cancelled by S) or a touch throttle > 0 latch digital; else R2 >
            # 0.05 latches analog; kept while no throttle is held
            tk = inp.throttle_kind
            if (tk == "keyboard" and inp.w) or (tk == "touch" and thr > 0):
                self.analog_input = False
            elif tk == "gamepad" and inp.accel > 0.05:
                self.analog_input = True
        return thr, raw_steer, steer

    def _resume(self, thr, forward_mph):
        """drivetrainResume: the first moving frame after an anchored spell or a reset request (after refreshInput)."""
        if self.was_anchored:
            # unanchored (race, duel or teleport start): with the throttle past 0.05 (C7), a launch from the revved rpm
            # and a launch slip from those revs (no spin window); the spin start grace begins with its speed clause (C3).
            # With no throttle the gearbox resets to the road speed. This is also the reset, so a pending one is dropped
            self.was_anchored = self.reset_pending = False
            a, gb = self.s.a, self.gb
            revved = clamp((gb.rpm / a["RedlineRpm"] - 0.5) / 0.4, 0.0, 1.0)
            self.reset_chassis()
            self.grace_needs_speed = True
            if thr > 0.05:
                gb.launch(max(thr, 0.0))
                if self.s.on("PowerBrakeEnabled"):
                    self.dump_slip, self.dump_clock = a["PowerBrakeDumpSlip"] * smoothstep(revved), 0.0
            else:
                gb.reset(forward_mph)
        elif self.reset_pending:
            self.reset_pending = False
            self.reset_chassis()
            self.gb.reset(forward_mph)

    def anchored(self, inp, dt):
        """An anchored frame (race countdown, teleport): refreshInput, then drivetrainAnchored: the first anchored frame
        puts the gearbox in N (ResetGearbox neutral), every frame resets the chassis and runs Model.StepNeutral. The car
        does not move; drift blend, gestures, boost and the tank do not run (the heartbeat returns early)."""
        self.t += dt
        step = clamp(dt, 0.0, 0.1)
        thr, _raw, _steer = self._input(inp, step)
        if not self.new:
            return self.last
        if not self.was_anchored:
            self.was_anchored = True
            self.gb.reset(0.0, neutral=True)
        self.reset_chassis()
        cut = self.gb.step_neutral(thr, dt)
        self.last.update(mode="Stopped", acc=0.0, drive=0.0, boost=0.0, a_side=0.0, cut=cut)
        return self.last

    def step(self, inp, dt):
        T = self.T
        self.t += dt
        step = clamp(dt, 0.0, 0.1)
        thr, raw_steer, steer = self._input(inp, step)
        touch = (inp.throttle_kind == "touch" and thr != 0) or (inp.kind == "touch" and raw_steer != 0)
        h = self.body
        fx, fy = math.sin(h), math.cos(h)
        rx, ry = math.cos(h), -math.sin(h)
        fwd = self.vx * fx + self.vy * fy
        side = self.vx * rx + self.vy * ry
        speed = math.hypot(self.vx, self.vy)
        speed_mph = speed * MPH
        if self.new:
            self._resume(thr, fwd * MPH)
        can_drift = inp.drift and fwd > 8 and speed_mph > 10 and abs(steer) > 0
        self.db += ((1.0 if can_drift else 0.0) - self.db) * clamp(dt * 5.2, 0, 1)
        drifting = self.db > 0.12
        boost_ok = inp.boost and self.tank > 1 and fwd > -4 and T.boost_power > 0
        mini_active = self.mini_timer > 0
        if self.new:
            self._gestures(inp, thr, raw_steer, speed_mph, step)
            # StepLongitudinal clamps dt to [0, 0.1] before StepDrivetrain
            acc, mode, snap, accelerating, braking, drive = self.gb.step(
                self, thr, fwd, speed, self.db, self.spin_L, self.extra_slip, self.pb_held, self.intent,
                self.boost_applied, self.analog_input, step)
        else:
            acc, mode, snap, self.hold, accelerating, braking = T.step_longitudinal(thr, fwd, self.hold, step)
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
        # lateral grip (DrivingClient:1297-1298, or drivetrainLateral when active)
        if self.new:
            a_side = self._lateral(side, speed_mph, speed, step)
        else:
            a_side = -side * T.lateral_grip(speed_mph, self.db)
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
                base = drive
                if self.new:
                    # C5: while DriveThrust > 0, assist from DriveThrust + (A1 x thr - DriveThrust) x
                    # DriftAssistPlateauShare; a frame with no drive thrust (a full limiter or shift cut) adds none
                    base = 0.0
                    if drive > 0:
                        base = drive + (self.P.A1 * max(thr, 0.0) - drive) * self.s.a["DriftAssistPlateauShare"]
                if base > 0:  # today: net LongitudinalAcceleration
                    assist = base * T.drift_engine_assist * self.db * alpha
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
        share = self.gb.boost_share if self.new else 1.0       # out.BoostShare (StepDrivetrain, before the snap)
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
        self.boost_applied = self.boosting
        ax += fx * boost_push
        ay += fy * boost_push
        # turn rate and yaw (DrivingClient:1428-1493)
        turn = T.turn_rate(fwd, speed_mph, self.intent, drifting, self.boosting)
        r_cmd = steering_input * turn
        if self.new:
            slip = self.gb.ws_eff
            self.heading += self._yaw(r_cmd, thr, steer, raw_steer, speed_mph, fwd, slip, step, touch) * dt
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
