"""Runs and metrics for CONTRACT section 9 and the fix spec section D. Every function takes
(config, car, settings_or_None, dt) and returns a dict. settings None = today's path. All speeds in mph, times in
seconds, angles in degrees."""
import math

from today import MPH, clamp
from vehicle import Inputs, Vehicle

SPIN_SLIP = 75.0      # a run "spins" when the slip angle (body heading against travel) passes this
SLIDE_SLIP = 35.0


def make(config, car, settings, **kw):
    return Vehicle(config, car, settings, **kw)


def vt_today(config, car, settings=None):
    return Vehicle(config, car, None).T.solve_top()


def start_at(v, mph, throttle_was):
    """A mid-speed start: the car placed at mph with the gearbox as Model.ResetGearbox leaves it, then the harness warm
    start (Vehicle.warm_start, not a Lua reset path) for a car that was on throttle_was before t=0."""
    v.set_speed(mph)
    v.warm_start(throttle_was)


def shift_events(v, since=0):
    """The Up and Down shifts (beginShift events) logged from index `since`; forced gear changes and launches are not
    shifts."""
    return [e for e in v.gb.shifts[since:] if e[1] in ("Up", "Down")] if v.gb else []


# ---------------------------------------------------------------------------------------------- straight line
def straight(config, car, settings, dt, seconds=60.0):
    v = make(config, car, settings)
    vt = v.T.solve_top()
    W = Inputs.keys(w=True)
    t, out = 0.0, dict(t60=None, t100=None, t90=None, s10=None, s15=None, vt=vt)
    min_k = 1.0
    lost = 0.0
    while t < seconds - 1e-9:
        v.step(W, dt)
        t += dt
        m = v.forward_mph
        if out["t60"] is None and m >= 60: out["t60"] = t
        if out["t100"] is None and m >= 100: out["t100"] = t
        if out["t90"] is None and m >= 0.9 * vt: out["t90"] = t
        if out["s10"] is None and t >= 10 - 1e-9: out["s10"] = m
        if out["s15"] is None and t >= 15 - 1e-9: out["s15"] = m
        if v.gb:
            min_k = min(min_k, v.gb.k_shift)
            lost += (1 - v.gb.k_shift) * dt
    out["top"] = v.forward_mph
    if v.gb:
        out["redlines"] = [round(x) for x in v.P.Vg]
        out["shifts"] = [(round(a, 2), round(m)) for a, kind, f, to, m in v.gb.shifts if kind == "Up"]
        out["min_k"] = min_k
        ups = sum(1 for e in v.gb.shifts if e[1] == "Up")
        out["lost_ms"] = 1000 * lost / max(ups, 1)   # thrust-time removed per upshift (fix 5: frame-rate independent)
        out["bounces"] = v.gb.lim_bounces
        out["P"] = v.P
    return out


def brake(config, car, settings, dt):
    v = make(config, car, settings)
    start = min(100.0, 0.95 * v.T.solve_top())
    start_at(v, start, 1.0)
    S = Inputs.keys(s=True)
    t, y0 = 0.0, v.y
    downs = 0
    while v.forward_mph > 1.5 and t < 30:
        v.step(S, dt)
        t += dt
    if v.gb:
        downs = sum(1 for e in v.gb.shifts if e[1] == "Down" and e[3] >= 1)
    return dict(start=start, t=t, d=v.y - y0, g=start / MPH / t / 35.1 if t > 0 else 0, downs=downs)


def lift(config, car, settings, dt, seconds=2.0):
    v = make(config, car, settings)
    start = min(100.0, 0.95 * v.T.solve_top())
    start_at(v, start, 1.0)
    N = Inputs()
    t = 0.0
    while t < seconds - 1e-9:
        v.step(N, dt)
        t += dt
    downs = sum(1 for e in v.gb.shifts if e[1] == "Down") if v.gb else 0
    return dict(start=start, end=v.forward_mph, downs=downs, gear=v.gb.gear if v.gb else None)


def boost(config, car, settings, dt):
    """Endless boost from top speed (what a chain of boosts tends to), and one tank from top speed."""
    v = make(config, car, settings)
    vt = v.T.solve_top()
    start_at(v, vt, 1.0)
    B = Inputs(throttle=1, boost=True)
    od_frames = frames = 0
    t = 0.0
    while t < 60:
        v.tank = 100
        v.step(B, dt)
        t += dt
        if t > 50:
            frames += 1
            if v.gb and v.gb.overdrive:
                od_frames += 1
    endless = v.forward_mph
    bounces = v.gb.lim_bounces if v.gb else 0
    one = make(config, car, settings)
    start_at(one, vt, 1.0)
    t = 0.0
    while one.tank > 1 and t < 10:
        one.step(B, dt)
        t += dt
    one_tank = one.forward_mph
    # after the tank, W held: the Overdrive exit (F9) should not bounce the limiter
    b0 = one.gb.lim_bounces if one.gb else 0
    t = 0.0
    while t < 4:
        one.step(Inputs(throttle=1), dt)
        t += dt
    exit_bounces = (one.gb.lim_bounces - b0) if one.gb else 0
    return dict(vt=vt, endless=endless, one_tank=one_tank, overdrive=od_frames / max(frames, 1), bounces=bounces,
                exit_bounces=exit_bounces, vb=v.P.Vb if v.P else v.T.solve_top(extra=v.T.boost_accel),
                share=v.P.share_hi if v.P else 1.0)


def boost_launch(config, car, settings, dt):
    """Boost held from a standstill: 0-60 and 0-100 with one tank (the 'shock wave' start)."""
    v = make(config, car, settings)
    B = Inputs(throttle=1, boost=True)
    t, t60, t100 = 0.0, None, None
    while t < 20:
        v.step(B, dt)
        t += dt
        if t60 is None and v.forward_mph >= 60: t60 = t
        if t100 is None and v.forward_mph >= 100: t100 = t
    return dict(t60=t60, t100=t100)


# ---------------------------------------------------------------------------------------------- yaw run-on and turn-in
def hold_speed(v, target):
    """Analog throttle that holds a speed (used where the throttle is not the subject). Only a gamepad trigger gives a
    fractional throttle, so callers send it with throttle_kind="gamepad" (AnalogInput latches true: no C9 cruise)."""
    return clamp((target - v.forward_mph) * 0.15 + 0.35, 0.0, 1.0)


def runon(config, car, settings, dt, mph=60.0, hold_seconds=1.2):
    v = make(config, car, settings)
    start_at(v, mph, 0.35)
    t = 0.0
    while t < 1.0:                                 # settle straight
        v.step(Inputs(throttle=hold_speed(v, mph), kind="keyboard", throttle_kind="gamepad"), dt)
        t += dt
    h0 = v.heading
    t = 0.0
    r_final, t63, peak = None, None, 0.0
    trace = []
    while t < hold_seconds - 1e-9:
        v.step(Inputs(throttle=hold_speed(v, mph), steer=1.0, kind="keyboard", throttle_kind="gamepad"), dt)
        t += dt
        trace.append((t, v.r))
        peak = max(peak, abs(v.r))
    r_final = v.r
    for tt, r in trace:
        if abs(r) >= 0.632 * abs(r_final):
            t63 = tt
            break
    h_release, b_release = v.heading, v.body
    t = 0.0
    while t < 1.5:
        v.step(Inputs(throttle=hold_speed(v, mph), steer=0.0, kind="keyboard", throttle_kind="gamepad"), dt)
        t += dt
    return dict(r=r_final, t63=t63, overshoot=peak / max(abs(r_final), 1e-6) - 1,
                runon=math.degrees(v.heading - h_release), runon_body=math.degrees(v.body - b_release),
                turned=math.degrees(h_release - h0), r_cmd=v.last.get("r_cmd"))


def steady_corner(config, car, settings, dt, mph):
    """Full lock with an analog throttle holding speed for 3 s: delivered lateral g, yaw rate, slip."""
    v = make(config, car, settings)
    start_at(v, mph, 0.5)
    t, lat, slip, yaw = 0.0, [], [], []
    while t < 3.0:
        v.step(Inputs(throttle=hold_speed(v, mph), steer=1.0, kind="keyboard", throttle_kind="gamepad"), dt)
        t += dt
        if t > 2.0:
            lat.append(abs(v.last["a_side"]) / 35.1)
            slip.append(v.slip_deg())
            yaw.append(abs(v.r))
    n = max(len(lat), 1)
    return dict(g=sum(lat) / n, slip=sum(slip) / n, yaw=sum(yaw) / n, mph=v.forward_mph)


# ---------------------------------------------------------------------------------------------- drift (driving_tune corner table)
def drift(config, car, settings, dt, seconds=2.0, pre_steer=0.0):
    """2 s of W + D + drift from 85% of Vt. pre_steer > 0: W + D for that long first, then the drift (the radius is
    measured from the drift press)."""
    v = make(config, car, settings)
    vt = v.T.solve_top()
    start_at(v, 0.85 * vt, 1.0)
    t = 0.0
    while t < pre_steer - 1e-9:
        v.step(Inputs(throttle=1, steer=1, kind="keyboard"), dt)
        t += dt
    entry = v.speed_mph
    t, distance, turned, max_slip, yaw_peak = 0.0, 0.0, 0.0, 0.0, 0.0
    previous = math.atan2(v.vx, v.vy)
    shifts0 = len(v.gb.shifts) if v.gb else 0
    while t < seconds - 1e-9:
        v.step(Inputs(throttle=1, steer=1, drift=True, kind="keyboard"), dt)
        t += dt
        distance += math.hypot(v.vx, v.vy) * dt
        direction = math.atan2(v.vx, v.vy)
        delta = (direction - previous + math.pi) % (2 * math.pi) - math.pi
        turned += delta
        previous = direction
        max_slip = max(max_slip, v.slip_deg())
        yaw_peak = max(yaw_peak, abs(v.r))
    exit_speed = v.speed_mph
    shifts_in_drift = len(shift_events(v, shifts0))
    gear = v.gb.gear if v.gb else None
    peak = exit_speed
    t = 0.0
    while t < 1.5:
        v.step(Inputs(throttle=1, steer=0, kind="keyboard"), dt)
        t += dt
        peak = max(peak, v.speed_mph)
    return dict(entry=entry, exit=exit_speed, turned=math.degrees(turned), radius=distance / max(abs(turned), 1e-6),
                slip=max_slip, yaw=math.degrees(yaw_peak), after=v.speed_mph, peak=peak, shifts=shifts_in_drift, gear=gear)


# ---------------------------------------------------------------------------------------------- shift churn
def tap(config, car, settings, dt, mph=40.0, seconds=12.0, count_from=2.0, rpm_from=7.0):
    """Keyboard W tapped to hold `mph`: W goes down below mph-1 for at least 0.15 s and until mph+1. Shifts are counted
    over the last 10 s; the mean rpm fraction over the last 5 s."""
    v = make(config, car, settings)
    v.set_speed(mph)
    t, pressed_at, w = 0.0, -1.0, False
    taps = 0
    rpm_sum = rpm_n = 0.0
    while t < seconds - 1e-9:
        m = v.forward_mph
        if not w and m < mph - 1:
            w, pressed_at = True, t
            taps += 1
        elif w and m > mph + 1 and t - pressed_at >= 0.15:
            w = False
        v.step(Inputs.keys(w=w), dt)
        t += dt
        if v.gb and t > rpm_from:
            rpm_sum += v.gb.rpm / v.P.R
            rpm_n += 1
    shifts = [e for e in v.gb.shifts if e[0] >= count_from and e[1] in ("Up", "Down")] if v.gb else []
    return dict(shifts=len(shifts), taps=taps, gear=v.gb.gear if v.gb else None, rpm=rpm_sum / rpm_n if rpm_n else None,
                events=[(round(e[0], 2), e[1], e[2], e[3]) for e in shifts][:8])


def cruise(config, car, settings, dt, mph=60.0, seconds=12.0):
    """Gamepad throttle near 0.5 holding 60 mph (verification row 4: no hunting)."""
    v = make(config, car, settings)
    start_at(v, mph, 0.5)
    t = 0.0
    rpm_sum = rpm_n = 0.0
    while t < seconds - 1e-9:
        v.step(Inputs(throttle=hold_speed(v, mph), kind="gamepad"), dt)
        t += dt
        if v.gb and t > seconds - 5:
            rpm_sum += v.gb.rpm / v.P.R
            rpm_n += 1
    shifts = [e for e in v.gb.shifts if e[0] >= 2.0 and e[1] in ("Up", "Down")] if v.gb else []
    return dict(shifts=len(shifts), gear=v.gb.gear if v.gb else None, rpm=rpm_sum / rpm_n if rpm_n else None)


# ---------------------------------------------------------------------------------------------- spin envelope
def _spin_run(v, driver, seconds, dt, stop_turn=None):
    t, max_slip, max_L, t_spin, max_r = 0.0, 0.0, 0.0, None, 0.0
    h0 = v.heading
    while t < seconds - 1e-9:
        v.step(driver(t, v), dt)
        t += dt
        slip = v.slip_deg()
        if slip > max_slip:
            max_slip = slip
        if t_spin is None and slip > SPIN_SLIP:
            t_spin = t
        max_L = max(max_L, v.spin_L)
        max_r = max(max_r, abs(v.r))
        if stop_turn is not None and abs(math.degrees(v.heading - h0)) >= stop_turn:
            break
    verdict = "SPIN" if max_slip > SPIN_SLIP else ("slide" if max_slip > SLIDE_SLIP else "grip")
    return dict(slip=max_slip, L=max_L, t_spin=t_spin, verdict=verdict, t=t, r=max_r, mph=v.speed_mph,
                turned=abs(math.degrees(v.heading - h0)), gestures=list(v.gestures), warn=getattr(v, "warn_seen", False))


def spin_hold(config, car, settings, dt, mph, seconds=3.0, kind="keyboard", prelude=0.3):
    """Full lock first, then W pressed after `prelude` s and held (no lift before it): must not spin.
    The prelude is coasting (or standing) with the lock already on, as a player pulling out of a junction does."""
    v = make(config, car, settings)
    if mph > 0:
        v.set_speed(mph)

    def driver(t, v):
        w = t >= prelude
        return Inputs(throttle=1.0 if w else 0.0, steer=1, w=w, kind=kind)
    return _spin_run(v, driver, seconds + prelude, dt)


def uturn(config, car, settings, dt, mph, prelude=0.3):
    """Keyboard U-turn: D first, W after `prelude` s, both held until the heading has turned 180 degrees."""
    v = make(config, car, settings)
    if mph > 0:
        v.set_speed(mph)
    return _spin_run(v, lambda t, v: Inputs.keys(w=t >= prelude, d=True), 8.0, dt, stop_turn=180)


def lifted(config, car, settings, dt, lift_s, mph=15.0, turn=True, on_s=0.3):
    """On W at `mph` with D held from the start; after `on_s` lift W for `lift_s`, then W again (the wheel never moves):
    a lifted U-turn (until 180 degrees) or a lifted hold (3 s). Must not spin: the stab needs a flick (F2)."""
    v = make(config, car, settings)
    start_at(v, mph, 1.0)

    def driver(t, v):
        return Inputs.keys(w=not (on_s <= t < on_s + lift_s), d=True)
    return _spin_run(v, driver, 8.0 if turn else on_s + lift_s + 3.0, dt, stop_turn=180 if turn else None)


def pullout(config, car, settings, dt):
    """From rest, A and W pressed on the same frame and held 3 s."""
    v = make(config, car, settings)
    return _spin_run(v, lambda t, v: Inputs.keys(w=True, a=True), 3.0, dt)


def junction(config, car, settings, dt, mph=20.0):
    """On W at 20 mph: lift for 0.3 s, D, then W 0.25 s later; held 3 s."""
    v = make(config, car, settings)
    start_at(v, mph, 1.0)
    return _spin_run(v, lambda t, v: Inputs.keys(w=t >= 0.55, d=t >= 0.3), 3.55, dt)


def feather(config, car, settings, dt, mph=15.0, on_s=0.15, off_s=0.15):
    """D held at 15 mph while W is feathered (on 0.15 s, off 0.15 s) for 3 s."""
    v = make(config, car, settings)
    start_at(v, mph, 1.0)
    period = on_s + off_s
    return _spin_run(v, lambda t, v: Inputs.keys(w=(t % period) < on_s, d=True), 3.0, dt)


def pad_ramp(config, car, settings, dt, mph, ramp):
    """Gamepad: stick at full lock first, then the trigger ramped 0 -> 1 over `ramp` s and held. From rest the ramp starts
    at 0.3 s. At speed the car is on the trigger with the stick held, lifts at 0.3 s for 0.2 s, then ramps (an armed
    analog rise without a flick)."""
    v = make(config, car, settings)
    start = 0.3
    if mph > 0:
        start_at(v, mph, 1.0)
        start = 0.5

    def driver(t, v):
        if mph > 0 and t < 0.3:
            thr = 1.0
        elif t < start:
            thr = 0.0
        else:
            thr = clamp((t - start) / max(ramp, 1e-6), 0.0, 1.0)
        return Inputs(throttle=thr, steer=1.0, kind="gamepad")
    return _spin_run(v, driver, start + 3.0, dt)


def touch_powerbrake(config, car, settings, dt, hold=0.6):
    """Touch: gas and brake held together with the lock for 0.6 s at rest (the summed throttle is 0, so physics records
    no power-brake on touch), then the brake released."""
    v = make(config, car, settings)

    def driver(t, v):
        s = t < hold
        return Inputs(throttle=0.0 if s else 1.0, steer=1, w=True, s=s, kind="touch")
    return _spin_run(v, driver, hold + 3.0, dt)


def stab(config, car, settings, dt, mph, kind="keyboard"):
    """Flick-stab: at `mph` on throttle, lift for 0.2 s with the wheel straight, then full lock and full throttle on the
    same frame. From rest: W 0.35 s straight, lift 0.2 s, then D and W together. Gamepad: trigger and stick slammed."""
    v = make(config, car, settings)
    if mph > 0:
        start_at(v, mph, 1.0)
        lift_from, lift_to = 0.0, 0.2
    else:
        lift_from, lift_to = 0.35, 0.55

    def driver(t, v):
        w = not (lift_from <= t < lift_to)
        d = t >= lift_to
        if kind == "gamepad":
            return Inputs(throttle=1.0 if w else 0.0, steer=1.0 if d else 0.0, kind="gamepad")
        return Inputs.keys(w=w, d=d)
    return _spin_run(v, driver, lift_to + 3.0, dt)


def powerbrake(config, car, settings, dt, kind="keyboard", hold=0.6):
    """Power-brake launch: W and S held at a standstill for `hold` with full lock, then S released, W held."""
    v = make(config, car, settings)

    def driver(t, v):
        s = t < hold
        return Inputs.keys(w=True, s=s, d=True)
    return _spin_run(v, driver, 3.5, dt)


def grace_powerbrake(config, car, settings, dt, wait, needs_speed):
    """C3 (F4): the start grace begins (spawn or R: speed clause off; anchored start or DriveReady: on), the car stands
    for `wait` s, then a power-brake (W + S + D for 0.6 s, S released)."""
    v = make(config, car, settings)
    v.grace_clock, v.grace_speed_reached, v.grace_needs_speed = 0.0, False, needs_speed

    def driver(t, v):
        if t < wait:
            return Inputs.keys()
        return Inputs.keys(w=True, s=t < wait + 0.6, d=True)
    return _spin_run(v, driver, wait + 3.5, dt)


def catch(config, car, settings, dt):
    """Power-brake spin, then a lift at 0.9 s: how quickly the car settles (yaw rate 0.3 s later)."""
    v = make(config, car, settings)

    def driver(t, v):
        return Inputs.keys(w=(t < 0.9), s=(t < 0.6), d=(t < 0.9))
    out = _spin_run(v, driver, 0.9, dt)
    t, r_after = 0.0, []
    while t < 1.0:
        v.step(Inputs.keys(), dt)
        t += dt
        r_after.append(abs(v.r))
    out["r_after_0_3"] = r_after[int(round(0.3 / dt)) - 1] if len(r_after) >= int(round(0.3 / dt)) else None
    out["L_after"] = v.spin_L
    return out


# ---------------------------------------------------------------------------------------------- race start (C7, C3)
def race_start(config, car, settings, dt, countdown=3.0, seconds=4.0, rev=True, w_after=0.0, d=False):
    """Race countdown and start: the car anchored for `countdown` s (neutral revs, W held when `rev`), then unanchored
    and driven `seconds` with W from `w_after` s after the go (0: W held through the go, a Launch from the revs; > 0: no
    throttle on the first moving frame, so the gearbox resets to the road speed), D held when `d`. Reports the revs and
    the countdown limiter bounces at the go, the Launch event (C7: only with throttle > 0.05), the launch slip from the
    revs, the start grace speed clause (C3), 0-60 / 0-100 and the largest slip angle."""
    v = make(config, car, settings)
    t, R = 0.0, (v.P.R if v.P else 1.0)
    while t < countdown - 1e-9:
        v.anchored(Inputs.keys(w=rev), dt)
        t += dt
    out = dict(rpm_go=v.gb.rpm / R if v.gb else None, gear_go=v.gb.gear if v.gb else None,
               bounces=v.gb.lim_bounces if v.gb else 0, duty_go=v.gb.duty if v.gb else None)
    n0 = len(v.gb.shifts) if v.gb else 0

    def driver(t, v):
        return Inputs.keys(w=t >= w_after - 1e-9, d=d)
    v.step(driver(0.0, v), dt)                          # the go: drivetrainResume on the first moving frame
    out["launch"] = any(e[1] == "Launch" for e in v.gb.shifts[n0:]) if v.gb else False
    out["dump"] = v.dump_slip if v.gb else 0.0
    out["needs_speed"] = v.grace_needs_speed if v.gb else False
    out["gear_after_go"] = v.gb.gear if v.gb else None
    t, t60, t100, max_slip = dt, None, None, v.slip_deg()
    while t < seconds - 1e-9:
        v.step(driver(t, v), dt)
        t += dt
        if t60 is None and v.forward_mph >= 60: t60 = t
        if t100 is None and v.forward_mph >= 100: t100 = t
        max_slip = max(max_slip, v.slip_deg())
    out.update(t60=t60, t100=t100, slip=max_slip, grace_speed_reached=v.grace_speed_reached,
               ups=len(shift_events(v, n0)), gear=v.gb.gear if v.gb else None, mph=v.forward_mph)
    return out


# The fix spec section D spin cases: (key, label, must spin?, runner(config, car, settings, dt)).
MUST_NOT = (
    ("hold0", "hold W + lock from 0", lambda c, car, s, dt: spin_hold(c, car, s, dt, 0)),
    ("hold5", "hold from 5", lambda c, car, s, dt: spin_hold(c, car, s, dt, 5)),
    ("hold10", "hold from 10", lambda c, car, s, dt: spin_hold(c, car, s, dt, 10)),
    ("hold15", "hold from 15", lambda c, car, s, dt: spin_hold(c, car, s, dt, 15)),
    ("hold20", "hold from 20", lambda c, car, s, dt: spin_hold(c, car, s, dt, 20)),
    ("hold25", "hold from 25", lambda c, car, s, dt: spin_hold(c, car, s, dt, 25)),
    ("uturn0", "U-turn from 0", lambda c, car, s, dt: uturn(c, car, s, dt, 0)),
    ("uturn15", "U-turn from 15", lambda c, car, s, dt: uturn(c, car, s, dt, 15)),
    ("liftU15", "lifted U-turn 15 mph, lift 0.15 s", lambda c, car, s, dt: lifted(c, car, s, dt, 0.15)),
    ("liftU30", "lifted U-turn 15 mph, lift 0.3 s", lambda c, car, s, dt: lifted(c, car, s, dt, 0.3)),
    ("liftH15", "lifted hold 15 mph, lift 0.15 s", lambda c, car, s, dt: lifted(c, car, s, dt, 0.15, turn=False)),
    ("liftH30", "lifted hold 15 mph, lift 0.3 s", lambda c, car, s, dt: lifted(c, car, s, dt, 0.3, turn=False)),
    ("pullout", "A + W together from rest", pullout),
    ("junction", "junction turn-in at 20 mph", junction),
    ("feather", "W feathered, D held, 15 mph", feather),
    ("pad0_1", "gamepad ramp 0.1 s from rest", lambda c, car, s, dt: pad_ramp(c, car, s, dt, 0, 0.1)),
    ("pad0_2", "gamepad ramp 0.2 s from rest", lambda c, car, s, dt: pad_ramp(c, car, s, dt, 0, 0.2)),
    ("pad0_3", "gamepad ramp 0.3 s from rest", lambda c, car, s, dt: pad_ramp(c, car, s, dt, 0, 0.3)),
    ("pad15_1", "gamepad ramp 0.1 s at 15 mph", lambda c, car, s, dt: pad_ramp(c, car, s, dt, 15, 0.1)),
    ("pad15_2", "gamepad ramp 0.2 s at 15 mph", lambda c, car, s, dt: pad_ramp(c, car, s, dt, 15, 0.2)),
    ("pad15_3", "gamepad ramp 0.3 s at 15 mph", lambda c, car, s, dt: pad_ramp(c, car, s, dt, 15, 0.3)),
    ("touchpb", "touch power-brake", touch_powerbrake),
)
MUST_SPIN = (
    ("stab0", "flick-stab from rest", lambda c, car, s, dt: stab(c, car, s, dt, 0)),
    ("stab10", "flick-stab at 10 mph", lambda c, car, s, dt: stab(c, car, s, dt, 10)),
    ("stab20", "flick-stab at 20 mph", lambda c, car, s, dt: stab(c, car, s, dt, 20)),
    ("padstab", "gamepad flick-stab at 10 mph", lambda c, car, s, dt: stab(c, car, s, dt, 10, kind="gamepad")),
    ("pb", "power-brake (keyboard)", powerbrake),
)
