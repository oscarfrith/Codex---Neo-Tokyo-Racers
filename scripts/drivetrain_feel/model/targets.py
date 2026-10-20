"""Regression targets: CONTRACT section 9 as written plus the fix spec section D, on the six stock Exotic cars and the
as-spawned Seraph. Everything at 60 Hz; run-on, tap, spin and drift also at 30 and 144 Hz.

    evaluate(config, settings) -> dict with every number, a pass/fail per target and the worst case per target
"""
import scenarios as sc
from cars import SERAPH_SPAWNED, stock_cars

RATES = (30, 60, 144)
GESTURE_TIERS = ("C", "B", "A", "S")

TARGETS = (
    ("top", "top speed within 3% of today (every car)"),
    ("s0100", "S 0-100 mph 3.8 to 4.8 s"),
    ("s090", "S time to 0.9 x Vt at most 12 s"),
    ("runon", "yaw run-on (YawHeading) after a release at 60 mph at most 5 deg"),
    ("tap", "at most 2 shifts in 10 s of tapping W at 40 mph"),
    ("taprpm", "tapping W at 40 mph: mean rpm fraction over the last 5 s at most 0.65"),
    ("drift", "drift radius within 10% of today, simultaneous entry"),
    ("driftpre", "drift radius within 10% of today, steer 0.25 s before the drift"),
    ("hold", "W + full lock held from 0-25 mph stays under 75 deg"),
    ("uturn", "U-turn at 0 and 15 mph stays under 75 deg"),
    ("nospin", "lifted U-turn and hold, pull-out, junction, feathering, gamepad ramps, touch power-brake stay under 75 deg"),
    ("gesture", "flick-stab at 0/10/20 mph, gamepad flick-stab and power-brake pass 75 deg on C-S"),
    ("pbE", "power-brake passes 75 deg on E"),
    ("boost", "endless-boost top within -3% to +3% of today"),
)
RATE_TARGETS = ("runon", "tap", "taprpm", "drift", "driftpre", "hold", "uturn", "nospin", "gesture", "pbE")

_today_cache = {}


def all_cars():
    return stock_cars() + [SERAPH_SPAWNED]


def _today(key, fn):
    if key not in _today_cache:
        _today_cache[key] = fn()
    return _today_cache[key]


def _nospin_group(key):
    if key.startswith("hold"):
        return "hold"
    if key.startswith("uturn"):
        return "uturn"
    return "nospin"


def evaluate(config, settings, cars=None, rates=RATES, quick=False, spin_only=False):
    """quick: 60 Hz only, 40 s straight runs, no boost. spin_only: only the spin cases (for spin tuning)."""
    cars = cars or all_cars()
    if quick:
        rates = (60,)
    rows = []
    for car in cars:
        r = dict(car=car, hz={})
        if not spin_only:
            st = sc.straight(config, car, settings, 1 / 60, seconds=40 if quick else 60)
            r["straight"] = st
            r["top_err"] = st["top"] / st["vt"] - 1
            if not quick:
                r["boost"] = sc.boost(config, car, settings, 1 / 60)
                r["boost0"] = _today((car.label, "boost"), lambda: sc.boost(config, car, None, 1 / 60))
        for hz in rates:
            dt = 1 / hz
            h = dict()
            if not spin_only:
                h["runon"] = sc.runon(config, car, settings, dt)
                h["tap"] = sc.tap(config, car, settings, dt)
                for pre, name in ((0.0, "drift"), (0.25, "driftpre")):
                    d0 = _today((car.label, name, hz), lambda: sc.drift(config, car, None, dt, pre_steer=pre))
                    d1 = sc.drift(config, car, settings, dt, pre_steer=pre)
                    h[name + "0"], h[name] = d0, d1
                    h[name + "_err"] = d1["radius"] / d0["radius"] - 1
            h["spin"] = {key: run(config, car, settings, dt) for key, _label, run in sc.MUST_NOT + sc.MUST_SPIN}
            r["hz"][hz] = h
        rows.append(r)
    return judge(rows, rates, spin_only)


def judge(rows, rates, spin_only=False):
    res = dict(rows=rows, worst={}, rates=rates)
    worst = res["worst"]

    def fail(key, text):
        res[key] = False
        worst.setdefault(key, []).append(text)

    for key, _ in TARGETS:
        res[key] = True
    S = next((r for r in rows if r["car"].tier == "S" and "spawned" not in r["car"].name), None)
    if not spin_only:
        for r in rows:
            lab = "%s %s" % (r["car"].tier, r["car"].name)
            if abs(r["top_err"]) > 0.03:
                fail("top", "%s %+.1f%%" % (lab, 100 * r["top_err"]))
            if "boost" in r:
                e = r["boost"]["endless"] / r["boost0"]["endless"] - 1
                if abs(e) > 0.03:
                    fail("boost", "%s %+.1f%%" % (lab, 100 * e))
            for hz, h in r["hz"].items():
                if h["runon"]["runon"] > 5:
                    fail("runon", "%s %d Hz %.1f deg" % (lab, hz, h["runon"]["runon"]))
                if h["tap"]["shifts"] > 2:
                    fail("tap", "%s %d Hz %d shifts" % (lab, hz, h["tap"]["shifts"]))
                if (h["tap"]["rpm"] or 0) > 0.65:
                    fail("taprpm", "%s %d Hz %.2f" % (lab, hz, h["tap"]["rpm"]))
                for name in ("drift", "driftpre"):
                    if abs(h[name + "_err"]) > 0.10:
                        fail(name, "%s %d Hz %+.0f%%" % (lab, hz, 100 * h[name + "_err"]))
        if S:
            t100, t90 = S["straight"]["t100"], S["straight"]["t90"]
            if not (t100 and 3.8 <= t100 <= 4.8):
                fail("s0100", "S %s s" % ("-" if t100 is None else "%.2f" % t100))
            if not (t90 and t90 <= 12):
                fail("s090", "S %s s" % ("-" if t90 is None else "%.1f" % t90))
        if not any("boost" in r for r in rows):
            res["boost"] = None
    else:
        for key in ("top", "s0100", "s090", "runon", "tap", "taprpm", "drift", "driftpre", "boost"):
            res[key] = None
    for r in rows:
        lab = "%s %s" % (r["car"].tier, r["car"].name)
        for hz, h in r["hz"].items():
            for key, label, _ in sc.MUST_NOT:
                x = h["spin"][key]
                if x["slip"] > sc.SPIN_SLIP:
                    fail(_nospin_group(key), "%s %d Hz %s %.0f deg" % (lab, hz, label, x["slip"]))
            for key, label, _ in sc.MUST_SPIN:
                x = h["spin"][key]
                if x["slip"] > sc.SPIN_SLIP:
                    continue
                if r["car"].tier in GESTURE_TIERS:
                    fail("gesture", "%s %d Hz %s %.0f deg" % (lab, hz, label, x["slip"]))
                elif r["car"].tier == "E" and key == "pb":
                    fail("pbE", "%s %d Hz %s %.0f deg" % (lab, hz, label, x["slip"]))
    return res


def margins(res):
    """Smallest required-spin slip and largest must-not-spin slip over every car and rate (75 = spin)."""
    lo, hi = 1e9, 0.0
    lo_at = hi_at = ""
    for r in res["rows"]:
        lab = "%s %s" % (r["car"].tier, r["car"].name.split(" ")[0])
        for hz, h in r["hz"].items():
            for key, label, _ in sc.MUST_NOT:
                x = h["spin"][key]["slip"]
                if x > hi:
                    hi, hi_at = x, "%s %s %d Hz" % (lab, key, hz)
            for key, label, _ in sc.MUST_SPIN:
                if r["car"].tier in GESTURE_TIERS or (r["car"].tier == "E" and key == "pb"):
                    x = h["spin"][key]["slip"]
                    if x < lo:
                        lo, lo_at = x, "%s %s %d Hz" % (lab, key, hz)
    return dict(gesture=lo, gesture_at=lo_at, nospin=hi, nospin_at=hi_at)


def summary(res):
    out = []
    for key, text in TARGETS:
        value = res.get(key)
        out.append("%s %s" % ("PASS" if value else ("-" if value is None else "FAIL"), key))
    return " ".join(out)


def failures(res):
    lines = []
    for key, _ in TARGETS:
        if res.get(key) is False:
            items = res["worst"].get(key, [])
            lines.append("%s: %s%s" % (key, "; ".join(items[:6]), " (+%d more)" % (len(items) - 6) if len(items) > 6 else ""))
    return "\n".join(lines)
