"""Runs and metrics for CONTRACT section 9. Every function takes (config, car, settings_or_None, dt) and returns a dict.
settings None = today's path. All speeds in mph, times in seconds, angles in degrees."""
import math

from today import MPH, clamp
from vehicle import Inputs, Vehicle

SPIN_SLIP = 75.0      # a run "spins" when the slip angle (body heading against travel) passes this
SLIDE_SLIP = 35.0


def make(config, car, settings, **kw):
    return Vehicle(config, car, settings, **kw)


def vt_today(config, car, settings=None):
    return Vehicle(config, car, None).T.solve_top()


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
    v.set_speed(start, throttle_was=1.0)
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
    v.set_speed(start, throttle_was=1.0)
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
    v.set_speed(vt, throttle_was=1.0)
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
    one.set_speed(vt, throttle_was=1.0)
    t = 0.0
    while one.tank > 1 and t < 10:
        one.step(B, dt)
        t += dt
    return dict(vt=vt, endless=endless, one_tank=one.forward_mph, overdrive=od_frames / max(frames, 1), bounces=bounces,
                vb=v.P.Vb if v.P else v.T.solve_top(extra=v.T.boost_accel), share=v.P.share_hi if v.P else 1.0)


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
    """Analog throttle that holds a speed (used where the throttle is not the subject)."""
    return clamp((target - v.forward_mph) * 0.15 + 0.35, 0.0, 1.0)


def runon(config, car, settings, dt, mph=60.0, hold_seconds=1.2):
    v = make(config, car, settings)
    v.set_speed(mph, throttle_was=0.35)
    t = 0.0
    while t < 1.0:                                 # settle straight
        v.step(Inputs(throttle=hold_speed(v, mph), kind="keyboard"), dt)
        t += dt
    h0 = v.heading
    t = 0.0
    r_final, t63, peak = None, None, 0.0
    trace = []
    while t < hold_seconds - 1e-9:
        v.step(Inputs(throttle=hold_speed(v, mph), steer=1.0, kind="keyboard"), dt)
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
        v.step(Inputs(throttle=hold_speed(v, mph), steer=0.0, kind="keyboard"), dt)
        t += dt
    return dict(r=r_final, t63=t63, overshoot=peak / max(abs(r_final), 1e-6) - 1,
                runon=math.degrees(v.heading - h_release), runon_body=math.degrees(v.body - b_release),
                turned=math.degrees(h_release - h0), r_cmd=v.last.get("r_cmd"))


def steady_corner(config, car, settings, dt, mph):
    """Full lock with an analog throttle holding speed for 3 s: delivered lateral g, yaw rate, slip."""
    v = make(config, car, settings)
    v.set_speed(mph, throttle_was=0.5)
    t, lat, slip, yaw = 0.0, [], [], []
    while t < 3.0:
        v.step(Inputs(throttle=hold_speed(v, mph), steer=1.0, kind="keyboard"), dt)
        t += dt
        if t > 2.0:
            lat.append(abs(v.last["a_side"]) / 35.1)
            slip.append(v.slip_deg())
            yaw.append(abs(v.r))
    n = max(len(lat), 1)
    return dict(g=sum(lat) / n, slip=sum(slip) / n, yaw=sum(yaw) / n, mph=v.forward_mph)


# ---------------------------------------------------------------------------------------------- drift (driving_tune corner table)
def drift(config, car, settings, dt, seconds=2.0):
    v = make(config, car, settings)
    vt = v.T.solve_top()
    v.set_speed(0.85 * vt, throttle_was=1.0)
    entry = v.speed_mph
    t, distance, turned, max_slip, yaw_peak = 0.0, 0.0, 0.0, 0.0, 0.0
    previous = math.atan2(v.vx, v.vy)
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
    shifts_in_drift = len(v.gb.shifts) if v.gb else 0
    peak = exit_speed
    t = 0.0
    while t < 1.5:
        v.step(Inputs(throttle=1, steer=0, kind="keyboard"), dt)
        t += dt
        peak = max(peak, v.speed_mph)
    return dict(entry=entry, exit=exit_speed, turned=math.degrees(turned), radius=distance / max(abs(turned), 1e-6),
                slip=max_slip, yaw=math.degrees(yaw_peak), after=v.speed_mph, peak=peak, shifts=shifts_in_drift)


# ---------------------------------------------------------------------------------------------- shift churn
def tap(config, car, settings, dt, mph=40.0, seconds=12.0, count_from=2.0):
    """Keyboard W tapped to hold `mph`: W goes down below mph-1 for at least 0.15 s and until mph+1."""
    v = make(config, car, settings)
    v.set_speed(mph, throttle_was=0.0)
    t, pressed_at, w = 0.0, -1.0, False
    taps = 0
    while t < seconds - 1e-9:
        m = v.forward_mph
        if not w and m < mph - 1:
            w, pressed_at = True, t
            taps += 1
        elif w and m > mph + 1 and t - pressed_at >= 0.15:
            w = False
        v.step(Inputs.keys(w=w), dt)
        t += dt
    shifts = [e for e in v.gb.shifts if e[0] >= count_from] if v.gb else []
    return dict(shifts=len(shifts), taps=taps, gear=v.gb.gear if v.gb else None,
                events=[(round(e[0], 2), e[1], e[2], e[3]) for e in shifts][:8])


def cruise(config, car, settings, dt, mph=60.0, seconds=12.0):
    """Gamepad throttle near 0.5 holding 60 mph (verification row 4: no hunting)."""
    v = make(config, car, settings)
    v.set_speed(mph, throttle_was=0.5)
    t = 0.0
    while t < seconds - 1e-9:
        v.step(Inputs(throttle=hold_speed(v, mph), kind="gamepad"), dt)
        t += dt
    shifts = [e for e in v.gb.shifts if e[0] >= 2.0] if v.gb else []
    return dict(shifts=len(shifts), gear=v.gb.gear if v.gb else None)


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
                turned=abs(math.degrees(v.heading - h0)), gestures=list(v.gestures))


def spin_hold(config, car, settings, dt, mph, seconds=3.0, kind="keyboard", prelude=0.3):
    """Full lock first, then W pressed after `prelude` s and held (no lift before it): must not spin.
    The prelude is coasting (or standing) with the lock already on, as a player pulling out of a junction does."""
    v = make(config, car, settings)
    if mph > 0:
        v.set_speed(mph, throttle_was=0.0)

    def driver(t, v):
        w = t >= prelude
        return Inputs(throttle=1.0 if w else 0.0, steer=1, w=w, kind=kind)
    return _spin_run(v, driver, seconds + prelude, dt)


def uturn(config, car, settings, dt, mph, prelude=0.3):
    """Keyboard U-turn: D first, W after `prelude` s, both held until the heading has turned 180 degrees."""
    v = make(config, car, settings)
    if mph > 0:
        v.set_speed(mph, throttle_was=0.0)
    return _spin_run(v, lambda t, v: Inputs.keys(w=t >= prelude, d=True), 8.0, dt, stop_turn=180)


def stab(config, car, settings, dt, mph, kind="keyboard"):
    """Lift-and-stab with full lock: at `mph` on throttle, lift for 0.2 s while turning in, then full throttle.
    From rest: W 0.35 s, lift 0.2 s, stab."""
    v = make(config, car, settings)
    if mph > 0:
        v.set_speed(mph, throttle_was=1.0)
        lift_from, lift_to = 0.0, 0.2
    else:
        lift_from, lift_to = 0.35, 0.55

    def driver(t, v):
        w = not (lift_from <= t < lift_to)
        if kind == "gamepad":
            return Inputs(throttle=1.0 if w else 0.0, steer=1.0, w=w, kind="gamepad")
        return Inputs.keys(w=w, d=True)
    return _spin_run(v, driver, 3.5, dt)


def powerbrake(config, car, settings, dt, kind="keyboard", hold=0.6):
    """Power-brake launch: W and S held at a standstill for `hold` with full lock, then S released, W held."""
    v = make(config, car, settings)

    def driver(t, v):
        s = t < hold
        if kind == "touch":
            return Inputs(throttle=1 - (1 if s else 0), steer=1, w=True, s=s, kind="touch")
        return Inputs.keys(w=True, s=s, d=True)
    return _spin_run(v, driver, 3.5, dt)


def catch(config, car, settings, dt):
    """Power-brake spin, then a lift at 0.9 s: how quickly the car settles (yaw rate, slip 1 s later)."""
    v = make(config, car, settings)

    def driver(t, v):
        return Inputs.keys(w=(t < 0.9), s=(t < 0.6), d=(t < 0.9))
    out = _spin_run(v, driver, 0.9, dt)
    t, r_after = 0.0, []
    while t < 1.0:
        v.step(Inputs.keys(), dt)
        t += dt
        r_after.append(abs(v.r))
    out["r_after_0_3"] = r_after[int(0.3 / dt) - 1] if len(r_after) >= int(0.3 / dt) else None
    out["L_after"] = v.spin_L
    return out
