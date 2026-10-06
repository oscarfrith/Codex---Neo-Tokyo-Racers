"""Numeric sanity check of the pose maths (settle spring, bank lift, corner springs). Mirrors the Luau in edits.py.

    py -3 scripts/driving_tune/pose/sim.py

Model: the car is a point mass on the four corner springs (4 * 54 stiffness, 4 * 7 damping per unit mass, as in
DrivingClient) following the ride-height target; bank follows the game's exponential (TurningBankResponse 2.2);
the body is the worst-case box corner measured on the Seraph in Play (7.07 wide, 1.15 below the root centre).
"""
import math

HOVER = 2.3
C = dict(SettleRestScale=0.70, SettleStartMph=1.0, SettleFullHeightMph=22.0, SettleFrequencyHz=1.3,
         SettleDamping=0.3, SettleThrottleLift=0.6, BankLiftAmount=0.7, BankLiftLeadSeconds=0.2,
         BankLiftRiseHz=4.0, BankLiftFallHz=1.4, BankLiftMaxStuds=2.4, MinEdgeClearanceStuds=0.25)
PROFILE = [(3.75, -0.6), (4.5, -1.15), (7.07, -1.15)]   # (|x|, y) candidates in root space
HALF_LENGTH = 13.15


def smoothstep(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def depth(lean):
    s, c = math.sin(abs(lean)), math.cos(lean)
    return max(x * s - y * c for x, y in PROFILE)


class Pose:
    def __init__(self, settle):
        self.settle, self.settle_v, self.lift, self.lift_v, self.last_lean = settle, 0.0, 0.0, 0.0, 0.0

    def step(self, dt, mph, throttle_intent, lean, pitch, bob=0.0):
        dt = min(max(dt, 1 / 240), 0.1)
        rest = C["SettleRestScale"]
        curve = smoothstep((mph - C["SettleStartMph"]) / max(C["SettleFullHeightMph"] - C["SettleStartMph"], 1))
        target = rest + (1 - rest) * max(curve, C["SettleThrottleLift"] * throttle_intent)
        steps = min(max(math.ceil(dt * 60 - 1e-6), 1), 6)
        h = dt / steps
        w = C["SettleFrequencyHz"] * 2 * math.pi
        for _ in range(steps):
            self.settle_v += (w * w * (target - self.settle) - 2 * C["SettleDamping"] * w * self.settle_v) * h
            self.settle += self.settle_v * h
        self.settle = min(max(self.settle, 0.3), 1.5)
        rate = (lean - self.last_lean) / dt
        self.last_lean = lean
        ahead = lean + rate * C["BankLiftLeadSeconds"]
        used = min(max(abs(lean), abs(ahead)), 0.6)
        level = depth(0)
        loss = max(depth(used) - level, 0)
        base = HOVER * self.settle + bob
        pitch_drop = HALF_LENGTH * math.sin(min(abs(pitch), 0.5))
        want = max(loss * C["BankLiftAmount"], C["MinEdgeClearanceStuds"] + level + loss + pitch_drop - base, 0)
        want = min(want, C["BankLiftMaxStuds"])
        for _ in range(steps):
            w2 = (C["BankLiftRiseHz"] if want > self.lift else C["BankLiftFallHz"]) * 2 * math.pi
            self.lift_v += (w2 * w2 * (want - self.lift) - 2 * w2 * self.lift_v) * h
            self.lift += self.lift_v * h
        self.lift = min(max(self.lift, 0), C["BankLiftMaxStuds"])
        return min(max(base + self.lift, 0.5), HOVER * 2)


def run(hz, scenario, seconds):
    dt = 1.0 / hz
    pose = Pose(1.0 if scenario(0)[0] > 30 else C["SettleRestScale"])
    height = pose.step(dt, *scenario(0))
    vel, bank, t = 0.0, 0.0, 0.0
    log = []
    while t < seconds:
        mph, intent, bank_target, pitch = scenario(t)
        ride = pose.step(dt, mph, intent, bank, pitch)
        # physical corner springs, substepped like the engine (240 Hz)
        sub = max(1, round(dt * 240))
        for _ in range(sub):
            vel += (216 * (ride - height) - 28 * vel) * (dt / sub)
            height += vel * (dt / sub)
        bank += (bank_target - bank) * (1 - math.exp(-2.2 * dt))
        clearance = height - depth(bank) - HALF_LENGTH * math.sin(abs(pitch))
        log.append((t, mph, ride, height, clearance, pose.settle, pose.lift, bank))
        t += dt
    return log


def brake_scene(t):          # cruise 80, brake from t=1 at 35 mph/s, sit, pull away at t=8
    if t < 1: return 80, 1, 0, 0
    if t < 1 + 80 / 35: return 80 - 35 * (t - 1), 0, 0, 0
    if t < 8: return 0, 0, 0, 0
    return min((t - 8) * 30, 80), 1, 0, math.radians(2.5) * (1 - math.exp(-7 * (t - 8)))   # accel tilt, smoothing 7


def lean_rest(t):            # standstill, full steer from t=1 to t=4
    return 0, 0, math.radians(12) if 1 <= t < 4 else 0, 0


def lean_speed(t):           # 80 mph, full drift lean from t=1 to t=4, flick to the other side until t=6
    return 80, 1, math.radians(17) if 1 <= t < 4 else (math.radians(-17) if 4 <= t < 6 else 0), 0


def report():
    rest_height = HOVER * C["SettleRestScale"]
    for hz in (60, 30, 10):
        log = run(hz, brake_scene, 12)
        sit = [r for r in log if 3.3 <= r[0] < 8]
        low = min(r[3] for r in sit)
        late = [r[3] for r in sit if r[0] > 6.5]
        away = [r for r in log if r[0] >= 8]
        print("%2d Hz brake-sit-go: min height %.3f (rest %.3f, overshoot %.3f = %.0f%% of the drop), ripple after 3 s %.4f, "
              "min clearance %.3f, pull-away peak %.3f, finite %s" % (
                  hz, low, rest_height, rest_height - low, 100 * (rest_height - low) / (HOVER - rest_height),
                  max(late) - min(late), min(r[4] for r in log), max(r[3] for r in away),
                  all(math.isfinite(v) for r in log for v in r)))
        for name, scene in (("lean at rest (12 deg)", lean_rest), ("lean at 80 mph (17 deg, flick)", lean_speed)):
            log = run(hz, scene, 9)
            print("   %-32s min clearance %.3f, peak height %.3f, peak lift %.3f, end height %.3f, max ride step/frame %.3f" % (
                name, min(r[4] for r in log), max(r[3] for r in log), max(r[6] for r in log), log[-1][3],
                max(abs(b[2] - a[2]) for a, b in zip(log, log[1:]))))
    # parked hand-over: exit at rest (seeded from the measured height, 0.1 stud dip), and exit while coasting at 40 mph
    for hz in (60, 10):
        dt = 1.0 / hz
        for name, mph0 in (("exit at rest", 0.0), ("exit coasting at 40 mph", 40.0)):
            start = HOVER * (1.0 if mph0 > 22 else C["SettleRestScale"])
            pose = Pose(start / HOVER)
            w = C["SettleFrequencyHz"] * 2 * math.pi
            pose.settle_v = -(0.1 / HOVER) * w / 0.65
            height, vel, t, mph, low, first = start, 0.0, 0.0, mph0, start, None
            while t < 8:
                mph *= math.exp(-0.8 * dt)       # ExitCoastDragPerSecond
                ride = pose.step(dt, mph, 0, 0, 0)
                if first is None: first = ride
                for _ in range(max(1, round(dt * 240))):
                    vel += (192 * (ride - height) - 24 * vel) * (dt / max(1, round(dt * 240)))
                    height += vel * (dt / max(1, round(dt * 240)))
                low = min(low, height); t += dt
            print("%2d Hz parked %-24s first-frame target step %.3f, lowest %.3f, end %.3f (rest %.3f)" % (
                hz, name, abs(first - start), low, height, HOVER * C["SettleRestScale"]))
    # without the lift, for comparison (today, corner springs not raising the car)
    print("no lift, 17 deg at 2.3: clearance %.3f; 12 deg at 2.3: %.3f" % (
        HOVER - depth(math.radians(17)), HOVER - depth(math.radians(12))))


if __name__ == "__main__":
    report()
