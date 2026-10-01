"""Shared library for vehicle frame-class blockout specs (design exploration only).

A spec is one JSON file per frame class. See CONTRACT.md for the schema.
Root space: +X right, +Y up, forward is -Z (matches CockpitRoot in Studio). Units are studs.
"""
import json
import math

import numpy as np

CANON_SLOTS = ["Engine1", "Engine2", "Stabilisers", "Boost",
               "FrontBumper", "RearBumper", "RearSpoiler", "SidePods"]
EXTRA_SLOTS = ["Hood", "Roof", "Accessory"]
ALL_SLOTS = CANON_SLOTS + EXTRA_SLOTS
SHAPES = ["block", "wedge", "cyl_x", "cyl_y", "cyl_z", "ball"]
CHANNELS = ["primary", "secondary", "detail", "glass", "neon", "thrust", "driver"]
FACES = ["-x", "+x", "-y", "+y", "-z", "+z"]

# Whole-vehicle limit shared by every class (keeps road, garage and camera assumptions sane).
GLOBAL_MIN = np.array([-12.0, -2.5, -19.0])
GLOBAL_MAX = np.array([12.0, 10.0, 19.0])
TOL = 0.051
MAX_GAP = 1.0  # a module (or cockpit) must come this close to its seam face

SLOT_COLOURS = {
    "Cockpit": "#e8e8ea", "Engine1": "#ff6b35", "Engine2": "#f7c531", "Stabilisers": "#35c2ff",
    "Boost": "#ff3df0", "FrontBumper": "#7bd44a", "RearBumper": "#2f9e62", "RearSpoiler": "#9b6bff",
    "SidePods": "#ff9fb0", "Hood": "#c9a36b", "Roof": "#7fd9d0", "Accessory": "#b0b6c4",
}


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def rot_matrix(rot):
    """Roblox Orientation (degrees X, Y, Z), applied in Y-X-Z order."""
    rx, ry, rz = [math.radians(a) for a in rot]
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def _prism(n, axis, size):
    """N-gon prism whose axis is 0/1/2; returns (verts, faces)."""
    sx, sy, sz = size
    half = np.array([sx, sy, sz]) / 2.0
    others = [a for a in (0, 1, 2) if a != axis]
    r = min(half[others[0]], half[others[1]])
    ring0, ring1 = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        p = np.zeros(3)
        p[others[0]] = r * math.cos(a)
        p[others[1]] = r * math.sin(a)
        q0, q1 = p.copy(), p.copy()
        q0[axis] = -half[axis]
        q1[axis] = half[axis]
        ring0.append(q0)
        ring1.append(q1)
    verts = ring0 + ring1
    faces = [list(range(n)), list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return np.array(verts), faces


def local_mesh(shape, size):
    sx, sy, sz = [float(v) for v in size]
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    if shape == "block":
        v = np.array([[x, y, z] for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)])
        f = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
        return v, f
    if shape == "wedge":
        # Roblox WedgePart: full base, tall face at +Z (back), thin edge at -Z (front).
        v = np.array([[-hx, -hy, -hz], [hx, -hy, -hz], [-hx, -hy, hz], [hx, -hy, hz], [-hx, hy, hz], [hx, hy, hz]])
        f = [[0, 1, 3, 2], [2, 3, 5, 4], [0, 4, 5, 1], [0, 2, 4], [1, 5, 3]]
        return v, f
    if shape == "cyl_x":
        return _prism(12, 0, (sx, sy, sz))
    if shape == "cyl_y":
        return _prism(12, 1, (sx, sy, sz))
    if shape == "cyl_z":
        return _prism(12, 2, (sx, sy, sz))
    if shape == "ball":
        r = min(hx, hy, hz)
        verts, faces = [], []
        rows, cols = 5, 10
        for i in range(rows + 1):
            t = math.pi * i / rows
            for j in range(cols):
                p = 2 * math.pi * j / cols
                verts.append([r * math.sin(t) * math.cos(p), r * math.cos(t), r * math.sin(t) * math.sin(p)])
        for i in range(rows):
            for j in range(cols):
                a, b = i * cols + j, i * cols + (j + 1) % cols
                faces.append([a, b, b + cols, a + cols])
        return np.array(verts), faces
    raise ValueError("unknown shape " + str(shape))


def expand_parts(parts):
    """Resolve mirror=true into explicit left/right parts. Returns a new list of dicts."""
    out = []
    for p in parts:
        base = {"shape": p["shape"], "size": list(p["size"]), "pos": list(p["pos"]),
                "rot": list(p.get("rot", [0, 0, 0])), "ch": p.get("ch", "primary"),
                "note": p.get("note", "")}
        out.append(base)
        if p.get("mirror"):
            m = dict(base)
            m["pos"] = [-base["pos"][0], base["pos"][1], base["pos"][2]]
            m["rot"] = [base["rot"][0], -base["rot"][1], -base["rot"][2]]
            out.append(m)
    return out


def world_mesh(part, offset=(0, 0, 0)):
    v, f = local_mesh(part["shape"], part["size"])
    R = rot_matrix(part.get("rot", [0, 0, 0]))
    w = v @ R.T + np.array(part["pos"], dtype=float) + np.array(offset, dtype=float)
    return w, f


def boxes_of(env):
    """Envelope -> list of (min, max) arrays. Accepts one box or a list; box may have mirror=true."""
    items = env if isinstance(env, list) else [env]
    out = []
    for b in items:
        lo, hi = np.array(b["min"], dtype=float), np.array(b["max"], dtype=float)
        out.append((lo, hi))
        if b.get("mirror"):
            out.append((np.array([-hi[0], lo[1], lo[2]]), np.array([-lo[0], hi[1], hi[2]])))
    return out


def _in_union(pt, boxes):
    return any(np.all(pt >= lo - TOL) and np.all(pt <= hi + TOL) for lo, hi in boxes)


def _overlap(a, b):
    lo, hi = np.maximum(a[0], b[0]), np.minimum(a[1], b[1])
    d = hi - lo
    return float(np.prod(d)) if np.all(d > TOL) else 0.0


def _face_plane(box, face):
    axis = "xyz".index(face[1])
    value = box[0][axis] if face[0] == "-" else box[1][axis]
    return axis, value


def _reaches(parts, boxes, face, inside=True):
    """True if some part comes within MAX_GAP of the given face of any envelope box, inside its rectangle.

    inside=True: the parts live in this envelope (a module reaching its own anchor face).
    inside=False: the parts live on the far side of the face (the parent reaching the seam).
    """
    for box in boxes:
        axis, value = _face_plane(box, face)
        others = [a for a in (0, 1, 2) if a != axis]
        for p in parts:
            w, _ = world_mesh(p)
            lo, hi = w.min(axis=0), w.max(axis=0)
            near = (lo[axis] if face[0] == "-" else hi[axis]) if inside else (hi[axis] if face[0] == "-" else lo[axis])
            if abs(near - value) <= MAX_GAP and all(hi[o] > box[0][o] - MAX_GAP and lo[o] < box[1][o] + MAX_GAP for o in others):
                return True
    return False


def validate(spec):
    """Returns (errors, warnings, stats)."""
    errors, warnings = [], []
    std = spec.get("standard", {})
    slots = std.get("slots", {})
    for key in ("id", "displayName", "standard", "cockpits", "modules", "builds"):
        if key not in spec:
            errors.append("missing top-level key: " + key)
    if errors:
        return errors, warnings, {}
    if "cockpitEnvelope" not in std:
        return ["standard.cockpitEnvelope missing"], warnings, {}
    cockpit_boxes = boxes_of(std["cockpitEnvelope"])

    for s in CANON_SLOTS:
        if s not in slots:
            errors.append("standard.slots missing canonical slot " + s)
    for s in slots:
        if s not in ALL_SLOTS:
            errors.append("unknown slot id %s (allowed: %s)" % (s, ", ".join(ALL_SLOTS)))

    env = {"Cockpit": cockpit_boxes}
    for s, d in slots.items():
        if "envelope" not in d or "label" not in d:
            errors.append("slot %s needs label and envelope" % s)
            continue
        env[s] = boxes_of(d["envelope"])
        anchor = d.get("anchor")
        if not anchor or anchor.get("to") not in (["cockpit"] + list(slots.keys())) or anchor.get("face") not in FACES:
            errors.append("slot %s needs anchor {to: 'cockpit'|<slot>, face: one of %s}" % (s, FACES))
    if errors:
        return errors, warnings, {}

    # Envelope algebra: everything inside the global limit, no two envelopes overlap.
    names = list(env.keys())
    for n in names:
        for lo, hi in env[n]:
            if np.any(lo < GLOBAL_MIN - TOL) or np.any(hi > GLOBAL_MAX + TOL):
                errors.append("%s envelope leaves the global limit %s..%s" % (n, GLOBAL_MIN.tolist(), GLOBAL_MAX.tolist()))
            if np.any(hi - lo <= 0):
                errors.append("%s envelope has min >= max" % n)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            vol = sum(_overlap(x, y) for x in env[a] for y in env[b])
            if vol > 0:
                errors.append("envelopes %s and %s overlap (%.1f cubic studs); envelopes must be disjoint" % (a, b, vol))

    def check_parts(label, parts, boxes):
        n = 0
        for idx, p in enumerate(parts):
            if p.get("shape") not in SHAPES:
                errors.append("%s part %d: bad shape %r" % (label, idx, p.get("shape")))
                continue
            if p.get("ch", "primary") not in CHANNELS:
                errors.append("%s part %d: bad ch %r" % (label, idx, p.get("ch")))
            if len(p.get("size", [])) != 3 or len(p.get("pos", [])) != 3 or min(p["size"]) < 0.05:
                errors.append("%s part %d: bad size/pos" % (label, idx))
                continue
        for p in expand_parts([q for q in parts if q.get("shape") in SHAPES and len(q.get("size", [])) == 3]):
            n += 1
            w, _ = world_mesh(p)
            bad = [v for v in w if not _in_union(v, boxes)]
            if bad:
                worst = max(bad, key=lambda v: float(np.max(np.abs(v))))
                errors.append("%s: %s at pos %s leaves its envelope (e.g. vertex %s)" % (
                    label, p["shape"], p["pos"], [round(float(c), 2) for c in worst]))
        return n

    counts = {}
    for cid, c in spec["cockpits"].items():
        counts["cockpit:" + cid] = check_parts("cockpit " + cid, c.get("parts", []), cockpit_boxes)
        cparts = expand_parts(c.get("parts", []))
        for s, d in slots.items():
            if d["anchor"]["to"] == "cockpit" and not _reaches(cparts, env[s], d["anchor"]["face"], inside=False):
                warnings.append("cockpit %s does not reach the %s seam (face %s) within %.1f studs: visible hole when a module is fitted" % (
                    cid, s, d["anchor"]["face"], MAX_GAP))

    for s, mods in spec["modules"].items():
        if s not in slots:
            errors.append("modules for undefined slot " + s)
            continue
        for mid, m in mods.items():
            counts["%s:%s" % (s, mid)] = check_parts("module %s/%s" % (s, mid), m.get("parts", []), env[s])
            mparts = expand_parts(m.get("parts", []))
            if mparts and not _reaches(mparts, env[s], slots[s]["anchor"]["face"]):
                warnings.append("module %s/%s does not reach its anchor face %s within %.1f studs (floats detached)" % (
                    s, mid, slots[s]["anchor"]["face"], MAX_GAP))
            # children anchored on this slot need every module here to reach their seam
            for cs, cd in slots.items():
                if cd["anchor"]["to"] == s and mparts and not _reaches(mparts, env[cs], cd["anchor"]["face"], inside=False):
                    warnings.append("module %s/%s does not reach the %s seam (child slot face %s)" % (s, mid, cs, cd["anchor"]["face"]))

    # Coverage requirements so the row actually demonstrates interchange.
    if len(spec["cockpits"]) < 3:
        errors.append("need at least 3 cockpits")
    for s in CANON_SLOTS:
        if len(spec["modules"].get(s, {})) < 2:
            errors.append("need at least 2 modules for canonical slot " + s)
    for s in slots:
        if s in EXTRA_SLOTS and len(spec["modules"].get(s, {})) < 2:
            warnings.append("extra slot %s has fewer than 2 modules" % s)
    used_c, used_m = {}, set()
    for i, b in enumerate(spec["builds"]):
        if b.get("cockpit") not in spec["cockpits"]:
            errors.append("build %d: unknown cockpit %r" % (i, b.get("cockpit")))
            continue
        used_c[b["cockpit"]] = used_c.get(b["cockpit"], 0) + 1
        for s, mid in b.get("modules", {}).items():
            if mid not in spec["modules"].get(s, {}):
                errors.append("build %d: unknown module %s/%s" % (i, s, mid))
            used_m.add((s, mid))
        for s in CANON_SLOTS:
            if s not in b.get("modules", {}):
                warnings.append("build %d (%s) leaves canonical slot %s empty" % (i, b.get("name"), s))
    if len(spec["builds"]) < 6:
        errors.append("need at least 6 builds")
    for cid in spec["cockpits"]:
        if used_c.get(cid, 0) < 2:
            warnings.append("cockpit %s appears in fewer than 2 builds" % cid)
    for s, mods in spec["modules"].items():
        for mid in mods:
            if (s, mid) not in used_m:
                warnings.append("module %s/%s is never used in a build" % (s, mid))

    total = 0
    for i, b in enumerate(spec["builds"]):
        if b.get("cockpit") not in spec["cockpits"]:
            continue
        n = counts.get("cockpit:" + b["cockpit"], 0) + sum(counts.get("%s:%s" % (s, m), 0) for s, m in b.get("modules", {}).items())
        total += n
        if n > 160:
            warnings.append("build %d (%s) has %d parts; keep under 160" % (i, b.get("name"), n))
    stats = {"cockpits": len(spec["cockpits"]), "modules": sum(len(m) for m in spec["modules"].values()),
             "builds": len(spec["builds"]), "parts_in_builds": total}
    return errors, warnings, stats


def build_parts(spec, build, exploded=False):
    """Returns list of (slot, part, offset) for a build; slot is 'Cockpit' for cockpit parts."""
    out = []
    for p in expand_parts(spec["cockpits"][build["cockpit"]]["parts"]):
        out.append(("Cockpit", p, (0, 0, 0)))
    for s, mid in build.get("modules", {}).items():
        off = spec["standard"]["slots"][s].get("explode", [0, 0, 0]) if exploded else (0, 0, 0)
        for p in expand_parts(spec["modules"][s][mid]["parts"]):
            out.append((s, p, off))
    return out
