"""Agent D helpers: box/cylinder shorthands on the 20/40 grid plus self-checks (roads, coplanar faces, floating parts, height)."""
import json, math, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
SG = HERE.parent.parent
sys.path.insert(0, str(SG / "common"))
from sgspec import Spec, aabb, CATALOG, PARCELS  # noqa: E402

CTX = json.load(open(SG / "common" / "context.json"))
GROUND = 200.0

# ---- palette (poor district: weathered, not glossy) ----
CONC = (150, 148, 142)       # Blocks grey
CONC_D = (118, 116, 112)     # darker bands / stained
CONC_L = (176, 173, 166)     # lighter fins
WHITE = (214, 212, 204)      # Metabolist white (aged)
WHITE_D = (190, 188, 180)
PATCH = [(170, 205, 185), (225, 160, 140), (232, 214, 150), (160, 196, 222), (205, 170, 205)]
STEEL = (70, 74, 80)
RUST = (140, 96, 70)


def box(s, x0, x1, y0, y1, z0, z1, mat="Concrete", var="", color=CONC, **kw):
    lo = (min(x0, x1), min(y0, y1), min(z0, z1))
    hi = (max(x0, x1), max(y0, y1), max(z0, z1))
    size = tuple(hi[i] - lo[i] for i in range(3))
    pos = tuple((hi[i] + lo[i]) / 2 for i in range(3))
    return s.part("Block", size, pos, mat=mat, var=var, color=color, **kw)


def vcyl(s, x, z, y0, y1, d, mat="Concrete", var="", color=WHITE, **kw):
    """Vertical cylinder (Roblox cylinders run along local X; roll 90 stands them up)."""
    return s.part("Cylinder", (y1 - y0, d, d), (x, (y0 + y1) / 2, z), rot=(0, 0, 90), mat=mat, var=var, color=color, **kw)


def hcyl_x(s, x0, x1, y, z, d, **kw):
    return s.part("Cylinder", (x1 - x0, d, d), ((x0 + x1) / 2, y, z), **kw)


# ---- checks ----
def _road_polys():
    out = []
    for r in CTX["blockout_roads"]:
        _, x, z, w, l, yaw, top, cy = r[:8]
        a = math.radians(yaw); c, s_ = math.cos(a), math.sin(a)
        pts = [(x + c * dx + s_ * dz, z - s_ * dx + c * dz) for dx, dz in ((-w / 2, -l / 2), (w / 2, -l / 2), (w / 2, l / 2), (-w / 2, l / 2))]
        out.append((pts, top, r[8]))
    return out


def _sat(poly, rect):
    """Separating-axis overlap of convex polygon vs axis-aligned rect (x0,z0,x1,z1)."""
    x0, z0, x1, z1 = rect
    rp = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    for P in (poly, rp):
        for i in range(len(P)):
            ax, az = P[i]; bx, bz = P[(i + 1) % len(P)]
            nx, nz = -(bz - az), bx - ax
            pa = [nx * p[0] + nz * p[1] for p in poly]; pb = [nx * p[0] + nz * p[1] for p in rp]
            if max(pa) <= min(pb) + 1e-6 or max(pb) <= min(pa) + 1e-6:
                return False
    return True


def bounds(e):
    if e["t"] == "part":
        return aabb(e["size"], e["pos"], e["rot"])
    if e["t"] == "kit":
        it = CATALOG[e["item"]]
        return aabb([v * e.get("scale", 1) for v in it["size"]], e["pos"], e["rot"])
    return None


def _faces(e):
    """Axis-aligned faces of Block parts with 90-degree yaw only (and cylinder caps)."""
    if e["t"] != "part":
        return []
    rx, ry, rz = e["rot"]
    lo, hi = bounds(e)
    out = []
    if e["shape"] == "Block" and rx % 90 == 0 and ry % 90 == 0 and rz % 90 == 0:
        for ax in range(3):
            o = [i for i in range(3) if i != ax]
            rect = (lo[o[0]], lo[o[1]], hi[o[0]], hi[o[1]])
            out.append((ax, round(lo[ax], 2), -1, rect))
            out.append((ax, round(hi[ax], 2), 1, rect))
    elif e["shape"] == "Cylinder" and tuple(e["rot"]) == (0, 0, 90):
        rect = (lo[0], lo[2], hi[0], hi[2])
        out.append((1, round(lo[1], 2), -1, rect)); out.append((1, round(hi[1], 2), 1, rect))
    return out


def _inside(p, b, eps=0.05):
    return all(b[0][i] + eps < p[i] < b[1][i] - eps for i in range(3))


def _covers(p, key, b, eps=0.05):
    """Face at plane key=(axis, coord, normal) is pressed flat against box b lying on its normal side."""
    ax, c, sgn = key
    if abs((b[0][ax] if sgn > 0 else b[1][ax]) - c) > 0.01:
        return False
    return all(b[0][i] + eps < p[i] < b[1][i] - eps for i in range(3) if i != ax)


def check(elements, sid, others=(), ymax=850, ymin_top=480, road_clear=60, ground_setback=8):
    probs = []
    roads = _road_polys()
    # roads
    for i, e in enumerate(elements):
        b = bounds(e)
        if not b:
            continue
        lo, hi = b
        for poly, top, name in roads:
            if _sat(poly, (lo[0] + 0.01, lo[2] + 0.01, hi[0] - 0.01, hi[2] - 0.01)) and lo[1] < top + road_clear:
                probs.append(f"ROAD {name}: {e.get('name')} #{i} bottom {lo[1]:.0f} over road top {top}")
            # ground-level setback so the pavement stays walkable
            if lo[1] < GROUND + 20 and _sat(poly, (lo[0] - ground_setback, lo[2] - ground_setback, hi[0] + ground_setback, hi[2] + ground_setback)) and not (e["t"] == "kit" and e["item"] in ("market_stall", "vending_machine", "bench_concrete")):
                probs.append(f"SETBACK {name}: {e.get('name')} #{i} within {ground_setback} of road at ground level")
    # coplanar
    planes = {}
    boxes_ = [bounds(e) if (e["t"] == "part" and e["shape"] == "Block" and e["transparency"] == 0 and _faces(e)) else None for e in elements]
    for i, e in enumerate(elements):
        for ax, c, sgn, rect in _faces(e):
            planes.setdefault((ax, c, sgn), []).append((i, rect))
    for key, lst in planes.items():
        for a in range(len(lst)):
            for b in range(a + 1, len(lst)):
                ra, rb = lst[a][1], lst[b][1]
                w = min(ra[2], rb[2]) - max(ra[0], rb[0]); h = min(ra[3], rb[3]) - max(ra[1], rb[1])
                if w > 0.05 and h > 0.05:
                    # hidden if the overlap sits inside a third solid box (e.g. back faces embedded in a wall)
                    cx, cy_ = (max(ra[0], rb[0]) + min(ra[2], rb[2])) / 2, (max(ra[1], rb[1]) + min(ra[3], rb[3])) / 2
                    pt = [0, 0, 0]; o = [i for i in range(3) if i != key[0]]
                    pt[key[0]] = key[1]; pt[o[0]] = cx; pt[o[1]] = cy_
                    if any(_inside(pt, boxes_[k]) or _covers(pt, key, boxes_[k]) for k in range(len(boxes_)) if k not in (lst[a][0], lst[b][0]) and boxes_[k]):
                        continue
                    ea, eb = elements[lst[a][0]], elements[lst[b][0]]
                    probs.append(f"COPLANAR axis{key[0]}@{key[1]} {ea.get('name')}#{lst[a][0]} / {eb.get('name')}#{lst[b][0]} ({w:.1f}x{h:.1f})")
    # floating: union of touching boxes must reach the ground or a neighbour spec
    allb = [bounds(e) for e in elements]
    idx = [i for i, b in enumerate(allb) if b]
    parent = {i: i for i in idx}

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    tol = 0.6
    touch = lambda A, B: all(A[0][k] <= B[1][k] + tol and B[0][k] <= A[1][k] + tol for k in range(3))
    for ai in range(len(idx)):
        for bi in range(ai + 1, len(idx)):
            i, j = idx[ai], idx[bi]
            if touch(allb[i], allb[j]):
                parent[find(i)] = find(j)
    obounds = [bounds(e) for e in others if bounds(e)]
    grounded = set()
    for i in idx:
        if allb[i][0][1] <= GROUND + 1 or any(touch(allb[i], ob) for ob in obounds):
            grounded.add(find(i))
    for i in idx:
        if find(i) not in grounded:
            probs.append(f"FLOATING {elements[i].get('name')} #{i} at {elements[i]['pos']}")
    top = max(b[1][1] for b in allb if b)
    if top > ymax or top < ymin_top:
        probs.append(f"HEIGHT top {top:.0f} outside {ymin_top}-{ymax}")
    print(f"{sid}: top Y {top:.0f}; {len(probs)} check problems")
    for p in probs[:60]:
        print("  ", p)
    return probs


def load_elements(path):
    try:
        return json.load(open(path))["elements"]
    except Exception:
        return []
