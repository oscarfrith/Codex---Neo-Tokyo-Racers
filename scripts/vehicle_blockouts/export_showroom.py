"""Flatten a blockout spec into a showroom layout the Studio builder can place without any logic.

Usage: py -3 scripts/vehicle_blockouts/export_showroom.py [<id> ...]   (no ids = every spec)
Writes scripts/vehicle_blockouts/showroom/<id>.json.

Layout of one class block (studs, relative to the block origin; cars face -Z):
  column 0            frame standard (envelopes) and, behind it, the exploded first build
  matrix              rows = cockpits, columns = signature kits (every cockpit wearing every kit)
  last column         the mixed builds from the spec
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import vbspec  # noqa: E402

SX, SZ = 46.0, 46.0
FIXED = {"detail": "#22252b", "glass": "#5f8fb0", "thrust": "#8ff6ff", "driver": "#d9b38c"}
DEFAULT_PAINT = {"primary": "#c9302c", "secondary": "#f2f2f2", "neon": "#00e5ff"}


def colour(slot, part, paint, by_slot):
    ch = part.get("ch", "primary")
    if by_slot:
        return FIXED[ch] if ch in ("glass", "driver") else vbspec.SLOT_COLOURS.get(slot, "#cccccc")
    return FIXED.get(ch) or (paint or {}).get(ch) or DEFAULT_PAINT.get(ch, "#cccccc")


def vehicle(spec, build, paint, exploded=False, by_slot=False):
    groups = {}
    order = []
    mods = vbspec.resolve_modules(spec, build)
    for slot, part, off in vbspec.build_parts(spec, build, exploded=exploded):
        if slot not in groups:
            label = "Cockpit" if slot == "Cockpit" else spec["standard"]["slots"][slot]["label"]
            mid = build["cockpit"] if slot == "Cockpit" else mods[slot]
            name = spec["cockpits"][mid]["name"] if slot == "Cockpit" else spec["modules"][slot][mid]["name"]
            groups[slot] = {"slot": slot, "label": label, "id": mid, "name": name, "parts": []}
            order.append(slot)
        groups[slot]["parts"].append({
            "s": part["shape"], "z": [round(v, 3) for v in part["size"]],
            "p": [round(part["pos"][i] + off[i], 3) for i in range(3)],
            "r": [round(v, 2) for v in part["rot"]], "c": part.get("ch", "primary"),
            "h": colour(slot, part, paint, by_slot)})
    return [groups[s] for s in order]


def export(path):
    spec = vbspec.load(path)
    errors, _, _ = vbspec.validate(spec)
    if errors and "--force" not in sys.argv:
        print("%s: %d validation error(s); not exported" % (spec.get("id"), len(errors)))
        return False
    std = spec["standard"]
    hover = (std.get("datums") or {}).get("hoverPlane", -2)
    cockpits = list(spec["cockpits"].keys())
    kits = list(spec["kits"].keys())
    native_paint = {}
    mixed = []
    for b in spec["builds"]:
        kind = vbspec.build_kind(spec, b)
        if kind == "native":
            native_paint[b["cockpit"]] = b.get("paint", {})
        elif kind == "mixed":
            mixed.append(b)
    stations, headers = [], []
    envelopes = []
    for lo, hi in vbspec.boxes_of(std["cockpitEnvelope"]):
        envelopes.append({"slot": "Cockpit", "label": "COCKPIT", "lo": lo.tolist(), "hi": hi.tolist()})
    for s in vbspec.ALL_SLOTS:
        if s in std["slots"]:
            for lo, hi in vbspec.boxes_of(std["slots"][s]["envelope"]):
                envelopes.append({"slot": s, "label": std["slots"][s]["label"], "lo": lo.tolist(), "hi": hi.tolist()})
    first = {"cockpit": cockpits[0], "kit": spec["cockpits"][cockpits[0]]["kit"]}
    stations.append({"name": "Exploded: %s" % spec["cockpits"][cockpits[0]]["name"], "sub": "one colour per module slot",
                     "x": 0, "z": SZ * 1.4, "lift": 6, "figure": False,
                     "groups": vehicle(spec, first, {}, exploded=True, by_slot=True)})
    x0 = SX * 1.7
    for r, cid in enumerate(cockpits):
        headers.append({"text": spec["cockpits"][cid]["name"], "sub": "cockpit", "x": x0 - SX * 0.62, "z": r * SZ, "y": 9, "w": 16})
        for k, kid in enumerate(kits):
            own = spec["cockpits"][cid]["kit"] == kid
            stations.append({"name": "%s + %s" % (spec["cockpits"][cid]["name"], spec["kits"][kid]["name"]),
                             "sub": "native kit" if own else "swapped kit", "x": x0 + k * SX, "z": r * SZ, "lift": 0,
                             "figure": k == 0, "cockpit": cid, "kit": kid,
                             "groups": vehicle(spec, {"cockpit": cid, "kit": kid}, native_paint.get(cid, {}))})
    for k, kid in enumerate(kits):
        headers.append({"text": spec["kits"][kid]["name"] + " kit", "sub": spec["kits"][kid].get("culture", ""),
                        "x": x0 + k * SX, "z": -SZ * 0.62, "y": -3, "w": 26})
    xm = x0 + len(kits) * SX + SX * 0.35
    if mixed:
        headers.append({"text": "Mixed builds", "sub": "parts from several kits", "x": xm, "z": -SZ * 0.62, "y": -3, "w": 26})
    for r, b in enumerate(mixed):
        stations.append({"name": b.get("name", "Mixed"), "sub": "mixed", "x": xm, "z": r * SZ, "lift": 0, "figure": False,
                         "cockpit": b["cockpit"], "groups": vehicle(spec, b, b.get("paint", {}))})
    rows = max(len(cockpits), len(mixed), 2)
    width = xm + SX * 0.8 if mixed else x0 + len(kits) * SX
    out = {"id": spec["id"], "displayName": spec["displayName"], "tagline": spec.get("tagline", ""), "hover": hover,
           "envelopes": envelopes, "stations": stations, "headers": headers,
           "floor": {"x0": -SX * 0.7, "x1": width, "z0": -SZ * 0.95, "z1": (rows - 1) * SZ + SZ * 0.6}}
    os.makedirs(os.path.join(HERE, "showroom"), exist_ok=True)
    dst = os.path.join(HERE, "showroom", spec["id"] + ".json")
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
    parts = sum(len(g["parts"]) for s in stations for g in s["groups"])
    print("%s: %d vehicles, %d parts, block %.0f x %.0f -> %s" % (spec["id"], len(stations), parts, width + SX * 0.7, rows * SZ + SZ * 0.55, dst))
    return True


if __name__ == "__main__":
    ids = [a for a in sys.argv[1:] if not a.startswith("--")]
    paths = [os.path.join(HERE, "specs", i + ".json") for i in ids] if ids else sorted(glob.glob(os.path.join(HERE, "specs", "*.json")))
    ok = all([export(p) for p in paths])
    sys.exit(0 if ok else 1)
