"""Shared library for vehicle frame-class blockout specs (design exploration only). Spec format v2.

A spec is one JSON file per frame class. See CONTRACT.md for the schema.
Root space: +X right, +Y up, forward is -Z (matches CockpitRoot in Studio). Units are studs.
"""
import json
import math

import numpy as np
from PIL import Image, ImageDraw

FUNDAMENTAL = ["Engine1", "Engine2", "Stabilisers", "Boost"]
CANON_SLOTS = FUNDAMENTAL + ["FrontBumper", "RearBumper", "RearSpoiler", "SidePods"]
EXTRA_SLOTS = ["FrontBody", "RearBody", "Hood", "Roof", "Accessory"]
ALL_SLOTS = FUNDAMENTAL + ["FrontBody", "RearBody", "SidePods", "FrontBumper", "RearBumper", "RearSpoiler", "Hood", "Roof", "Accessory"]
BIG_SLOTS = FUNDAMENTAL + ["FrontBody", "RearBody", "SidePods", "RearSpoiler"]
SHAPES = ["block", "wedge", "cyl_x", "cyl_y", "cyl_z", "ball"]
CHANNELS = ["primary", "secondary", "detail", "glass", "neon", "thrust", "driver"]
FACES = ["-x", "+x", "-y", "+y", "-z", "+z"]

# Whole-vehicle limit shared by every class (keeps road, garage and camera assumptions sane).
GLOBAL_MIN = np.array([-12.0, -2.5, -19.0])
GLOBAL_MAX = np.array([12.0, 10.0, 19.0])
TOL = 0.051
MAX_GAP = 1.0        # a module (or cockpit) must come this close to its seam face
CONTACT_WARN = 0.6   # nearest-part gap between a module and each possible parent
CONTACT_FAIL = 1.0
DISTINCT_BIG = 0.35  # minimum silhouette distinctness between two modules of a big slot
DISTINCT_SMALL = 0.25
DISTINCT_COCKPIT = 0.25
MAX_PARTS = 220

SLOT_COLOURS = {
    "Cockpit": "#e8e8ea", "Engine1": "#ff6b35", "Engine2": "#f7c531", "Stabilisers": "#35c2ff",
    "Boost": "#ff3df0", "FrontBody": "#c77b4a", "RearBody": "#9aa53b", "SidePods": "#ff9fb0",
    "FrontBumper": "#7bd44a", "RearBumper": "#2f9e62", "RearSpoiler": "#9b6bff",
    "Hood": "#c9a36b", "Roof": "#7fd9d0", "Accessory": "#b0b6c4",
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
    half = np.array(size, dtype=float) / 2.0
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
    faces = [list(range(n)), list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return np.array(ring0 + ring1), faces


def local_mesh(shape, size):
    sx, sy, sz = [float(v) for v in size]
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    if shape == "block":
        v = np.array([[x, y, z] for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)])
        return v, [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    if shape == "wedge":
        # Roblox WedgePart: full base, tall face at +Z (back), thin edge at -Z (front).
        v = np.array([[-hx, -hy, -hz], [hx, -hy, -hz], [-hx, -hy, hz], [hx, -hy, hz], [-hx, hy, hz], [hx, hy, hz]])
        return v, [[0, 1, 3, 2], [2, 3, 5, 4], [0, 4, 5, 1], [0, 2, 4], [1, 5, 3]]
    if shape in ("cyl_x", "cyl_y", "cyl_z"):
        return _prism(12, "xyz".index(shape[-1]), (sx, sy, sz))
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
    """Resolve mirror=true into explicit parts. Mirrored copies carry _m=True."""
    out = []
    for p in parts:
        base = {"shape": p["shape"], "size": list(p["size"]), "pos": list(p["pos"]),
                "rot": list(p.get("rot", [0, 0, 0])), "ch": p.get("ch", "primary"),
                "note": p.get("note", ""), "_m": False}
        out.append(base)
        if p.get("mirror"):
            m = dict(base)
            m["pos"] = [-base["pos"][0], base["pos"][1], base["pos"][2]]
            m["rot"] = [base["rot"][0], -base["rot"][1], -base["rot"][2]]
            m["_m"] = True
            out.append(m)
    return out


def world_mesh(part, offset=(0, 0, 0)):
    v, f = local_mesh(part["shape"], part["size"])
    R = rot_matrix(part.get("rot", [0, 0, 0]))
    w = v @ R.T + np.array(part["pos"], dtype=float) + np.array(offset, dtype=float)
    return w, f


def boxes_of(env):
    """Envelope -> list of (min, max) arrays. Accepts one box or a list; a box may set mirror=true."""
    items = env if isinstance(env, list) else [env]
    out = []
    for b in items:
        lo, hi = np.array(b["min"], dtype=float), np.array(b["max"], dtype=float)
        out.append((lo, hi))
        if b.get("mirror"):
            out.append((np.array([-hi[0], lo[1], lo[2]]), np.array([-lo[0], hi[1], hi[2]])))
    return out


def anchors_of(slotdef):
    a = slotdef.get("anchor")
    if a is None:
        return []
    return a if isinstance(a, list) else [a]


def resolve_modules(spec, build):
    """Kit modules overlaid with the build's own overrides. A null override removes the slot."""
    mods = {}
    kit = build.get("kit")
    if kit and kit in spec.get("kits", {}):
        mods.update(spec["kits"][kit].get("modules", {}))
    mods.update(build.get("modules", {}))
    return {s: m for s, m in mods.items() if m}


def build_kind(spec, build):
    if build.get("modules"):
        return "mixed"
    own = spec["cockpits"].get(build.get("cockpit"), {}).get("kit")
    return "native" if build.get("kit") == own else "swap"


def build_parts(spec, build, exploded=False):
    """Returns list of (slot, part, offset); slot is 'Cockpit' for cockpit parts."""
    out = []
    for p in expand_parts(spec["cockpits"][build["cockpit"]]["parts"]):
        out.append(("Cockpit", p, (0, 0, 0)))
    for s, mid in resolve_modules(spec, build).items():
        ex = spec["standard"]["slots"][s].get("explode", [0, 0, 0]) if exploded else [0, 0, 0]
        for p in expand_parts(spec["modules"][s][mid]["parts"]):
            off = (-ex[0], ex[1], ex[2]) if p["_m"] else tuple(ex)
            out.append((s, p, off))
    return out


def _in_union(pt, boxes):
    return any(np.all(pt >= lo - TOL) and np.all(pt <= hi + TOL) for lo, hi in boxes)


def _overlap(a, b):
    lo, hi = np.maximum(a[0], b[0]), np.minimum(a[1], b[1])
    d = hi - lo
    return float(np.prod(d)) if np.all(d > TOL) else 0.0


def _sample_points(w, faces):
    """Vertices plus face centres and edge midpoints, so a part cannot cut an inside corner unseen."""
    pts = [v for v in w]
    for f in faces:
        fv = w[f]
        pts.append(fv.mean(axis=0))
        for i in range(len(f)):
            pts.append((fv[i] + fv[(i + 1) % len(f)]) / 2)
    return pts


def _aabbs(parts):
    out = []
    for p in parts:
        w, _ = world_mesh(p)
        out.append((w.min(axis=0), w.max(axis=0)))
    return out


def _min_gap(a_boxes, b_boxes):
    best = 1e9
    for alo, ahi in a_boxes:
        for blo, bhi in b_boxes:
            d = np.maximum(0.0, np.maximum(alo - bhi, blo - ahi))
            g = float(np.linalg.norm(d))
            if g < best:
                best = g
    return best


def _reaches(parts, boxes, face, inside=True):
    """True if some part comes within MAX_GAP of the given face of any envelope box, inside its rectangle."""
    for lo_b, hi_b in boxes:
        axis = "xyz".index(face[1])
        value = lo_b[axis] if face[0] == "-" else hi_b[axis]
        others = [a for a in (0, 1, 2) if a != axis]
        for lo, hi in _aabbs(parts):
            near = (lo[axis] if face[0] == "-" else hi[axis]) if inside else (hi[axis] if face[0] == "-" else lo[axis])
            if abs(near - value) <= MAX_GAP and all(hi[o] > lo_b[o] - MAX_GAP and lo[o] < hi_b[o] + MAX_GAP for o in others):
                return True
    return False


_VIEWS = {"side": (2, 1), "top": (0, 2), "front": (0, 1)}


def _mask(meshes, lo, hi, view, ppu=6):
    a, b = _VIEWS[view]
    w = max(2, int(math.ceil((hi[a] - lo[a]) * ppu)) + 2)
    h = max(2, int(math.ceil((hi[b] - lo[b]) * ppu)) + 2)
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for verts, faces in meshes:
        for f in faces:
            d.polygon([((verts[i][a] - lo[a]) * ppu + 1, (verts[i][b] - lo[b]) * ppu + 1) for i in f], fill=255)
    return np.asarray(img) > 0


def distinctness(parts_a, parts_b):
    """1 - mean silhouette IoU over side, top and front views. 0 = same outline, 1 = nothing shared."""
    ma = [world_mesh(p) for p in parts_a]
    mb = [world_mesh(p) for p in parts_b]
    if not ma or not mb:
        return 1.0
    allv = np.vstack([m[0] for m in ma + mb])
    lo, hi = allv.min(axis=0), allv.max(axis=0)
    ious = []
    for view in _VIEWS:
        A, B = _mask(ma, lo, hi, view), _mask(mb, lo, hi, view)
        union = np.logical_or(A, B).sum()
        ious.append(float(np.logical_and(A, B).sum()) / union if union else 1.0)
    return 1.0 - sum(ious) / len(ious)


def distinct_table(groups):
    """Pairwise distinctness for the options of one slot (or the cockpits of a class).

    groups: {id: parts}. Returns {(a, b): (free, raw)}.
    raw  = 1 - silhouette IoU of the whole option (side, top, front).
    free = the same score after removing the area every option shares (the pads, seams and chassis the
           frame standard forces on all of them), so it measures only the part a designer is free to vary.
           With fewer than three options there is no meaningful shared core and free equals raw.
    """
    ids = [g for g in groups if groups[g]]
    meshes = {g: [world_mesh(p) for p in groups[g]] for g in ids}
    if len(ids) < 2:
        return {}
    allv = np.vstack([m[0] for g in ids for m in meshes[g]])
    lo, hi = allv.min(axis=0), allv.max(axis=0)
    masks = {g: {v: _mask(meshes[g], lo, hi, v) for v in _VIEWS} for g in ids}
    core = {v: np.logical_and.reduce([masks[g][v] for g in ids]) for v in _VIEWS} if len(ids) >= 3 else None
    out = {}
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            raw, free = [], []
            for v in _VIEWS:
                A, B = masks[a][v], masks[b][v]
                u = np.logical_or(A, B).sum()
                raw.append(1.0 - (float(np.logical_and(A, B).sum()) / u if u else 1.0))
                if core is not None:
                    A2, B2 = A & ~core[v], B & ~core[v]
                    u2 = np.logical_or(A2, B2).sum()
                    free.append(1.0 - (float(np.logical_and(A2, B2).sum()) / u2 if u2 else 1.0))
            r = sum(raw) / len(raw)
            out[(a, b)] = (sum(free) / len(free) if free else r, r)
    return out


def validate(spec):
    """Returns (errors, warnings, stats)."""
    errors, warnings = [], []
    for key in ("id", "displayName", "standard", "cockpits", "modules", "kits", "builds"):
        if key not in spec:
            errors.append("missing top-level key: " + key)
    if errors:
        return errors, warnings, {}
    std = spec["standard"]
    slots = std.get("slots", {})
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
        anchors = anchors_of(d)
        if not anchors:
            errors.append("slot %s needs anchor {to, face} (or a list of them)" % s)
        for a in anchors:
            if a.get("to") not in (["cockpit"] + list(slots.keys())) or a.get("face") not in FACES:
                errors.append("slot %s: bad anchor %r (to: 'cockpit' or a slot id; face: one of %s)" % (s, a, FACES))
    if errors:
        return errors, warnings, {}

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
        ok = []
        for idx, p in enumerate(parts):
            if p.get("shape") not in SHAPES:
                errors.append("%s part %d: bad shape %r" % (label, idx, p.get("shape")))
            elif p.get("ch", "primary") not in CHANNELS:
                errors.append("%s part %d: bad ch %r" % (label, idx, p.get("ch")))
            elif len(p.get("size", [])) != 3 or len(p.get("pos", [])) != 3 or min(p["size"]) < 0.05:
                errors.append("%s part %d: bad size/pos" % (label, idx))
            else:
                ok.append(p)
                shape, size, ch = p["shape"], p["size"], p.get("ch", "primary")
                if shape.startswith("cyl_"):
                    axis = "xyz".index(shape[-1])
                    length = size[axis]
                    dia = min(size[a] for a in (0, 1, 2) if a != axis)
                    glow = ch in ("thrust", "neon", "glass")
                    if dia >= 1.8 and length <= 0.45 * dia and (not glow or dia >= 3.0):
                        warnings.append("%s part %d: disc-like cylinder (%.1f across, %.1f thick) reads as a wheel or rotor; use a nozzle or pod longer than it is wide" % (label, idx, dia, length))
        exp = expand_parts(ok)
        for p in exp:
            w, f = world_mesh(p)
            bad = [v for v in _sample_points(w, f) if not _in_union(v, boxes)]
            if bad:
                worst = max(bad, key=lambda v: float(np.max(np.abs(v))))
                errors.append("%s: %s at pos %s leaves its envelope (e.g. point %s)" % (
                    label, p["shape"], p["pos"], [round(float(c), 2) for c in worst]))
        return exp

    cparts = {cid: check_parts("cockpit " + cid, c.get("parts", []), cockpit_boxes) for cid, c in spec["cockpits"].items()}
    mparts = {}
    for s, mods in spec["modules"].items():
        if s not in slots:
            errors.append("modules for undefined slot " + s)
            continue
        for mid, m in mods.items():
            mparts[(s, mid)] = check_parts("module %s/%s" % (s, mid), m.get("parts", []), env[s])
            if s in FUNDAMENTAL and not any(p.get("ch") == "thrust" for p in m.get("parts", [])):
                errors.append("module %s/%s is a fundamental (engine, stabiliser or boost) but has no 'thrust' part: show its jet" % (s, mid))

    # Seams and contact: every child must reach, and nearly touch, every possible parent.
    cbox = {cid: _aabbs(p) for cid, p in cparts.items()}
    mbox = {k: _aabbs(p) for k, p in mparts.items()}
    worst_gap = 0.0
    for s, d in slots.items():
        for a in anchors_of(d):
            parents = [("cockpit " + cid, cparts[cid], cbox[cid]) for cid in cparts] if a["to"] == "cockpit" else \
                [("%s/%s" % (a["to"], mid), mparts[(a["to"], mid)], mbox[(a["to"], mid)]) for mid in spec["modules"].get(a["to"], {}) if (a["to"], mid) in mparts]
            for pname, pp, pb in parents:
                if pp and not _reaches(pp, env[s], a["face"], inside=False):
                    warnings.append("%s does not reach the %s seam (face %s): hole when a %s part is fitted" % (pname, s, a["face"], s))
            for mid in spec["modules"].get(s, {}):
                mp = mparts.get((s, mid))
                if not mp:
                    continue
                if not _reaches(mp, env[s], a["face"]):
                    warnings.append("module %s/%s does not reach its anchor face %s (to %s)" % (s, mid, a["face"], a["to"]))
                for pname, pp, pb in parents:
                    if not pp:
                        continue
                    g = _min_gap(mbox[(s, mid)], pb)
                    worst_gap = max(worst_gap, g)
                    if g > CONTACT_FAIL:
                        errors.append("module %s/%s floats %.2f studs clear of %s" % (s, mid, g, pname))
                    elif g > CONTACT_WARN:
                        warnings.append("module %s/%s sits %.2f studs from %s (shadow gap should be 0.2 to 0.6)" % (s, mid, g, pname))

    # Coverage.
    if len(spec["cockpits"]) < 4:
        errors.append("need at least 4 cockpits")
    for s in CANON_SLOTS:
        need = 3 if s in FUNDAMENTAL else 2
        if len(spec["modules"].get(s, {})) < need:
            errors.append("need at least %d modules for slot %s" % (need, s))
        elif s in FUNDAMENTAL and len(spec["modules"].get(s, {})) < 4:
            warnings.append("slot %s has fewer than 4 modules (one per signature kit is the target)" % s)
    for s in slots:
        if s in EXTRA_SLOTS and len(spec["modules"].get(s, {})) < (3 if s in ("FrontBody", "RearBody") else 2):
            warnings.append("extra slot %s has too few modules" % s)

    for kid, k in spec["kits"].items():
        for s, mid in k.get("modules", {}).items():
            if mid and mid not in spec["modules"].get(s, {}):
                errors.append("kit %s: unknown module %s/%s" % (kid, s, mid))
        for s in FUNDAMENTAL:
            if not k.get("modules", {}).get(s):
                errors.append("kit %s has no %s module: every vehicle needs engines, stabilisers and boost" % (kid, s))
        for s in slots:
            if s in ("FrontBody", "RearBody") and not k.get("modules", {}).get(s):
                warnings.append("kit %s leaves %s empty" % (kid, s))
    for cid, c in spec["cockpits"].items():
        if c.get("kit") not in spec["kits"]:
            errors.append("cockpit %s needs kit: the id of its signature kit" % cid)
    sig = [c.get("kit") for c in spec["cockpits"].values()]
    if len(set(sig)) < len(sig):
        errors.append("each cockpit needs its own signature kit (two cockpits share one)")

    kinds = {cid: set() for cid in spec["cockpits"]}
    used = set()
    sizes = {}
    any_mixed = False
    for i, b in enumerate(spec["builds"]):
        cid = b.get("cockpit")
        if cid not in spec["cockpits"]:
            errors.append("build %d: unknown cockpit %r" % (i, cid))
            continue
        if b.get("kit") and b["kit"] not in spec["kits"]:
            errors.append("build %d: unknown kit %r" % (i, b["kit"]))
            continue
        mods = resolve_modules(spec, b)
        bad = [(s, m) for s, m in mods.items() if m not in spec["modules"].get(s, {})]
        for s, m in bad:
            errors.append("build %d: unknown module %s/%s" % (i, s, m))
        if bad:
            continue
        kind = build_kind(spec, b)
        kinds[cid].add(kind)
        any_mixed = any_mixed or kind == "mixed"
        for s in FUNDAMENTAL:
            if s not in mods:
                errors.append("build %d (%s) has no %s: engines, stabilisers and boost are required on every vehicle" % (i, b.get("name"), s))
        used.update(mods.items())
        n = len(cparts[cid]) + sum(len(mparts.get((s, m), [])) for s, m in mods.items())
        if n > MAX_PARTS:
            warnings.append("build %d (%s) has %d parts; keep under %d" % (i, b.get("name"), n, MAX_PARTS))
        boxes = cbox[cid] + [bx for s, m in mods.items() for bx in mbox.get((s, m), [])]
        if boxes:
            lo = np.min([x[0] for x in boxes], axis=0)
            hi = np.max([x[1] for x in boxes], axis=0)
            sizes[b.get("name", str(i))] = [round(float(v), 1) for v in (hi - lo)]
    for cid, ks in kinds.items():
        if "native" not in ks:
            errors.append("cockpit %s has no native build (the cockpit wearing its own signature kit, no overrides)" % cid)
        if "swap" not in ks:
            errors.append("cockpit %s has no swap build (the cockpit wearing another cockpit's signature kit, no overrides)" % cid)
    if not any_mixed:
        warnings.append("no mixed build (a build with per-slot overrides)")
    for s, mods in spec["modules"].items():
        for mid in mods:
            in_kit = any(k.get("modules", {}).get(s) == mid for k in spec["kits"].values())
            if (s, mid) not in used and not in_kit:
                warnings.append("module %s/%s is in no kit and no build" % (s, mid))

    # Distinctness: options in one slot, and the cockpits themselves, must not look alike.
    distinct, distinct_raw = {}, {}
    for s, mods in spec["modules"].items():
        low = DISTINCT_BIG if s in BIG_SLOTS else DISTINCT_SMALL
        table = distinct_table({m: mparts.get((s, m)) or [] for m in mods})
        for (a, b), (free, raw) in table.items():
            if free < low:
                warnings.append("modules %s/%s and %s/%s look alike (distinctness %.2f of the free outline, %.2f whole; want %.2f or more)" % (s, a, s, b, free, raw, low))
        if table:
            distinct[s] = round(float(min(v[0] for v in table.values())), 2)
            distinct_raw[s] = round(float(min(v[1] for v in table.values())), 2)
    table = distinct_table(cparts)
    for (a, b), (free, raw) in table.items():
        if free < DISTINCT_COCKPIT:
            warnings.append("cockpits %s and %s look alike (distinctness %.2f of the free outline, %.2f whole; want %.2f or more)" % (a, b, free, raw, DISTINCT_COCKPIT))
    if table:
        distinct["Cockpit"] = round(float(min(v[0] for v in table.values())), 2)
        distinct_raw["Cockpit"] = round(float(min(v[1] for v in table.values())), 2)

    stats = {"cockpits": len(spec["cockpits"]), "kits": len(spec["kits"]),
             "modules": sum(len(m) for m in spec["modules"].values()), "builds": len(spec["builds"]),
             "worst_gap": round(worst_gap, 2), "min_distinctness": distinct, "min_distinctness_whole": distinct_raw, "build_sizes_WHL": sizes}
    return errors, warnings, stats
