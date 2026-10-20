"""CONTRACT section 9 regression targets: evaluate one settings variant on the six stock Exotic cars.

    evaluate(config, settings, dt) -> dict with every number and a pass/fail per target
"""
import scenarios as sc
from cars import stock_cars

TARGETS = (
    ("top", "top speed within 3% of today (every car)"),
    ("s0100", "S 0-100 mph 3.8 to 4.8 s"),
    ("s090", "S time to 0.9 x Vt at most 12 s"),
    ("runon", "yaw run-on after a release at 60 mph at most 5 deg (every car)"),
    ("tap", "at most 2 shifts in 10 s of tapping W at 40 mph (every car)"),
    ("drift", "drift radius within 10% of today (every car)"),
    ("uturn", "U-turn at 0 and 15 mph without a spin (every car)"),
    ("gesture", "stab and power-brake spin on C to S cars"),
    ("pbE", "power-brake can spin an E car"),
    ("hold", "W + full lock held from 0-25 mph never spins (every car)"),
    ("boost", "endless-boost top within today's +3% (every car)"),
)


def evaluate(config, settings, dt=1 / 60, cars=None, quick=False):
    cars = cars or stock_cars()
    rows = []
    for car in cars:
        r = dict(car=car)
        st = sc.straight(config, car, settings, dt, seconds=40 if quick else 60)
        r["straight"] = st
        r["top_err"] = st["top"] / st["vt"] - 1
        r["runon"] = sc.runon(config, car, settings, dt)
        r["tap"] = sc.tap(config, car, settings, dt)
        d0 = sc.drift(config, car, None, dt)
        d1 = sc.drift(config, car, settings, dt)
        r["drift0"], r["drift"] = d0, d1
        r["drift_err"] = d1["radius"] / d0["radius"] - 1
        r["uturn"] = [sc.uturn(config, car, settings, dt, v) for v in (0, 15)]
        r["hold"] = [sc.spin_hold(config, car, settings, dt, v) for v in (0, 5, 10, 15, 20, 25)]
        r["stab"] = [sc.stab(config, car, settings, dt, v) for v in (0, 10, 20)]
        r["pb"] = sc.powerbrake(config, car, settings, dt)
        if not quick:
            r["boost"] = sc.boost(config, car, settings, dt)
            r["boost0"] = sc.boost(config, car, None, dt)
        rows.append(r)
    res = dict(rows=rows)
    tiers = {r["car"].tier: r for r in rows}
    S = tiers.get("S")
    res["top"] = all(abs(r["top_err"]) <= 0.03 for r in rows)
    res["s0100"] = bool(S and S["straight"]["t100"] and 3.8 <= S["straight"]["t100"] <= 4.8)
    res["s090"] = bool(S and S["straight"]["t90"] and S["straight"]["t90"] <= 12)
    res["runon"] = all(r["runon"]["runon"] <= 5 for r in rows)
    res["tap"] = all(r["tap"]["shifts"] <= 2 for r in rows)
    res["drift"] = all(abs(r["drift_err"]) <= 0.10 for r in rows)
    res["uturn"] = all(u["verdict"] != "SPIN" for r in rows for u in r["uturn"])
    res["hold"] = all(h["verdict"] != "SPIN" for r in rows for h in r["hold"])
    res["gesture"] = all(r["pb"]["verdict"] == "SPIN" and all(s["verdict"] == "SPIN" for s in r["stab"])
                         for r in rows if r["car"].tier in ("C", "B", "A", "S"))
    res["pbE"] = bool(tiers.get("E") and tiers["E"]["pb"]["verdict"] == "SPIN")
    if not quick:
        res["boost"] = all(r["boost"]["endless"] <= r["boost0"]["endless"] * 1.03 + 0.5 for r in rows)
    else:
        res["boost"] = None
    return res


def summary(res):
    out = []
    for key, text in TARGETS:
        value = res.get(key)
        out.append("%s %s" % ("PASS" if value else ("-" if value is None else "FAIL"), key))
    return " ".join(out)


def brief(res):
    lines = []
    for r in res["rows"]:
        st = r["straight"]
        lines.append("%s 0-100 %s t90 %s runon %.1f tap %d drift %+.0f%% exit %+.0f%% | hold %s | uturn %s | stab %s | pb %s" % (
            r["car"].tier, "%.2f" % st["t100"] if st["t100"] else "-", "%.1f" % st["t90"] if st["t90"] else "-",
            r["runon"]["runon"], r["tap"]["shifts"], 100 * r["drift_err"], 100 * (r["drift"]["exit"] / r["drift0"]["exit"] - 1),
            "/".join("%.0f" % h["slip"] for h in r["hold"]), "/".join("%.0f" % u["slip"] for u in r["uturn"]),
            "/".join("%.0f" % s["slip"] for s in r["stab"]), "%.0f" % r["pb"]["slip"]))
    return "\n".join(lines)
