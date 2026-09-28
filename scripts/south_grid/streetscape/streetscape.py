"""South Grid streetscape generator (agent ST).

python scripts/south_grid/streetscape/streetscape.py
  -> streetscape_streets.json     kerbs + paving + rounded kerb corners on every road-facing parcel frontage, lamps, trees, bollards
  -> streetscape_step.json        the Y100/Y200 retaining wall: V stair-streets, ledge, upper market terrace, graffiti, shutters
  -> streetscape_waterfront.json  north quay promenade: boardwalk, railings, benches, lamps, trees, two fishing piers
  -> streetscape_westpark.json    pocket park in the open west lot: curving paths, lawns, futsal cage, trees
  -> streetscape_eastlot.json     street-racing hangout on the east wedge: lock-ups, car meet pad with bays, floodlights, containers

Hard rules enforced by check() before saving (offending elements are dropped and reported):
  * nothing may overlap a road footprint (context.json blockout_roads) unless its underside is >= road top + 60;
  * nothing may sit deeper than 12 studs inside a parcel (the 0-12 frontage strip is ours);
Coordinates are Roblox world studs; see common/sgspec.py for rotation conventions.
"""
import math, pathlib, random, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "common"))
sys.path.insert(0, str(HERE))
from sgspec import Spec, rot_matrix, CATALOG, PROPS  # noqa: E402
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location("st_site", HERE / "site.py")
site = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(site)

RNG = random.Random(9281)
FRONTAGE = 12.0          # stud depth of the frontage strip we may use inside a parcel
KERB_W = 1.5

# ---------------------------------------------------------------- palette
PAVE_1 = (150, 144, 138)     # row 1 (The Blocks): worn warm-grey paving
PAVE_2 = (170, 162, 154)     # row 2 terrace: lighter
PAVE_PINK = (184, 132, 120)  # accent paving, same family as the dealership streets
KERB = (206, 204, 198)
ASPH = (78, 80, 86)
CONC = (150, 148, 142)
CONC_D = (112, 110, 106)
GRASS = (92, 132, 66)
TIMBER = (132, 98, 70)
YELLOW = (226, 186, 40)
METAL = (92, 96, 102)


# ---------------------------------------------------------------- neighbours (building agents' current specs)
def _load_buildings():
    import glob, json
    out = []
    for f in glob.glob(str(HERE.parent / "buildings" / "*" / "*.json")):
        try:
            doc = json.load(open(f))
        except Exception:
            continue
        for e in doc.get("elements", []):
            if e["t"] == "part": size = e["size"]
            elif e["t"] == "kit": size = [v * e.get("scale", 1) for v in CATALOG[e["item"]]["size"]]
            else: continue
            R = rot_matrix(*e["rot"]); r = math.sqrt(sum(v * v for v in size)) / 2
            out.append((doc.get("id"), e, size, R, r))
    return out


BUILDINGS = _load_buildings()


def building_at(x, y, z, tol=0.3):
    """Id of a building spec whose part/kit box contains the point (None if free)."""
    for bid, e, size, R, r in BUILDINGS:
        px, py, pz = e["pos"]
        if abs(x - px) > r or abs(y - py) > r or abs(z - pz) > r:
            continue
        d = (x - px, y - py, z - pz)
        if all(abs(R[0][k] * d[0] + R[1][k] * d[1] + R[2][k] * d[2]) <= size[k] / 2 - tol for k in range(3)):
            return bid
    return None


# ---------------------------------------------------------------- geometry helpers
def yaw_z(dx, dz):
    """yaw (deg) so that the part's local +Z points along (dx, dz)."""
    return math.degrees(math.atan2(dx, dz))


def yaw_front(fx, fz):
    """yaw (deg) so that the part's local -Z (front) faces (fx, fz)."""
    return math.degrees(math.atan2(-fx, -fz))


def seg(s, p0, p1, width, y0, y1, **kw):
    """Block from p0 to p1 (xz), local Z along the segment, local X = width."""
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dz)
    return s.part("Block", (width, y1 - y0, L), ((p0[0] + p1[0]) / 2, (y0 + y1) / 2, (p0[1] + p1[1]) / 2),
                  rot=(0, yaw_z(dx, dz), 0), **kw)


def lamp(s, x, y, z, head_dir):
    """Street Lamp Tall A: pivot at the pole foot, head reaches 13 studs along the model's -Z."""
    s.clone("Street Lamp Tall A", (x, y, z), rot=(0, yaw_front(*head_dir), 0))


def planter_tree(s, x, y, z, kind="Tree Large Poplar Group", size=9, yaw=0):
    s.part("Block", (size, 2.5, size), (x, y + 1.25, z), rot=(0, yaw, 0), mat="Concrete", var="Concrete Square Tiles",
           color=CONC_D, layer="LOD3", name="Planter")
    s.clone(kind, (x, y + 2.5, z), rot=(0, RNG.choice((0, 90, 180, 270)), 0), layer="LOD3")


def catmull(pts, step=10.0):
    """Sample a Catmull-Rom spline through pts at roughly `step` spacing."""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        n = max(2, int(math.hypot(p2[0] - p1[0], p2[1] - p1[1]) / step))
        for k in range(n):
            t = k / n; t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                                    (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    out.append(tuple(pts[-1]))
    return out


def path_strip(s, pts, width, y_top, color=PAVE_PINK, var="Paving Slab", mat="CeramicTiles", thick=0.6, name="Path"):
    """Curving path as short rotated slabs (1 stud overlap at every joint)."""
    for a, b in zip(pts, pts[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dz)
        if L < 0.5: continue
        ux, uz = dx / L, dz / L
        seg(s, (a[0] - ux * 0.6, a[1] - uz * 0.6), (b[0] + ux * 0.6, b[1] + uz * 0.6), width, y_top - thick, y_top,
            mat=mat, var=var, color=color, layer="LOD3", name=name)


# ---------------------------------------------------------------- validation
def footprint_samples(e):
    """Sample points of the element's ground footprint plus its world-Y span."""
    if e["t"] == "clone":
        h = PROPS.get(e["key"], {"size": [4, 4, 4]})["size"][1]
        return [(e["pos"][0], e["pos"][2])], e["pos"][1], e["pos"][1] + h
    if e["t"] == "part":
        size = e["size"]
    else:
        size = [v * e["scale"] for v in CATALOG[e["item"]]["size"]]
    R = rot_matrix(*e["rot"])
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    ext_y = abs(R[1][0]) * hx + abs(R[1][1]) * hy + abs(R[1][2]) * hz
    half = [hx, hy, hz]
    # the two local axes that lie most horizontally span the ground footprint (handles vertical cylinders / tilted parts)
    ax = sorted(range(3), key=lambda i: -(R[0][i] ** 2 + R[2][i] ** 2) * max(half[i], 0.01))[:2]
    a, b = ax
    ia = max(0.0, half[a] - 0.6); ib = max(0.0, half[b] - 0.6)
    na = max(1, int(2 * ia / 4) + 1); nb = max(1, int(2 * ib / 4) + 1)
    pts = []
    for i in range(na + 1):
        for k in range(nb + 1):
            la = -ia + 2 * ia * i / na; lb = -ib + 2 * ib * k / nb
            pts.append((e["pos"][0] + R[0][a] * la + R[0][b] * lb, e["pos"][2] + R[2][a] * la + R[2][b] * lb))
    return pts, e["pos"][1] - ext_y, e["pos"][1] + ext_y


def check(s, drop=True):
    """Drop (and report) anything that overlaps a road envelope or reaches deeper than the frontage strip into a parcel."""
    keep, bad = [], []
    for e in s.elements:
        pts, y0, y1 = footprint_samples(e)
        why = None
        for (x, z) in pts:
            r = site.road_hit(x, z, 0.0, y0 + 0.01, y1)
            if r is not None:
                why = f"on road (top {r}) at {round(x)},{round(z)}"; break
            p = site.in_parcel(x, z, FRONTAGE + 0.75)
            if p:
                why = f"inside parcel {p} at {round(x)},{round(z)}"; break
        if why is None and BUILDINGS:
            fp = footprint_samples(e)[0]
            small = e["t"] != "part" or max(e["size"][0], e["size"][2]) < 40
            if small:
                for (x, z) in fp:
                    for yy in (y0 + 0.6, (y0 + y1) / 2, y1 - 0.6):
                        b = building_at(x, yy, z)
                        if b:
                            why = f"yields to building {b} at {round(x)},{round(yy)},{round(z)}"; break
                    if why: break
        if why:
            bad.append((e.get("name"), e["group"], why))
        else:
            keep.append(e)
    if bad:
        print(f"  [{s.sid}] dropped {len(bad)} element(s):")
        for b in bad[:12]:
            print("    ", b)
    if drop:
        s.elements = keep
    return bad


# ================================================================== 1. STREETS
R_CORNER = 24.0
N_ARC = 5
LAMP_STEP = 72.0


def edge_defs(q):
    """Parcel edges as (name, start, end, inward normal). Start->end runs clockwise-ish; corners are start/end."""
    x0, x1, z0, z1 = q["x0"], q["x1"], q["z0"], q["z1"]
    return [("N", (x0, z0), (x1, z0), (0, 1)), ("E", (x1, z0), (x1, z1), (-1, 0)),
            ("S", (x1, z1), (x0, z1), (0, -1)), ("W", (x0, z1), (x0, z0), (1, 0))]


def facing_runs(a, b, n, step=2.0, ground_y=100):
    """Runs [t0,t1] along edge a->b where the outside is road and the 12-stud strip is clear. Returns (t0,t1,roadTop)."""
    L = math.hypot(b[0] - a[0], b[1] - a[1]); ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    runs, cur, top = [], None, None
    t = 0.0
    while t <= L + 1e-6:
        px, pz = a[0] + ux * t, a[1] + uz * t
        r = site.street_road(px - n[0] * 4, pz - n[1] * 4)
        clear = all(site.road_hit(px + n[0] * d, pz + n[1] * d, 0.0, 95, 140 if r is not None and r < 150 else 240) is None for d in (0.6, 0.9, 1.5, 6, 11.4))
        if r is not None and abs(r - (ground_y + 1)) > 3:
            r = None   # the road beside this edge is not at the parcel's street level (e.g. a raised embankment road)
        if r is not None and clear:
            clear = all(building_at(px + n[0] * d, ground_y + yy, pz + n[1] * d) is None for d in (1.0, 6.0, 11.0) for yy in (2.5, 8.0))
        ok = r is not None and clear
        if ok and cur is None: cur, top = t, r
        if not ok and cur is not None:
            runs.append((cur, t - step, top)); cur = None
        t += step
    if cur is not None: runs.append((cur, L, top))
    return [(t0, t1, tp) for (t0, t1, tp) in runs if t1 - t0 >= 16], L, (ux, uz)


def build_streets():
    s = Spec("streetscape_streets", kind="streetscape", title="South Grid streets: kerbs, paving, corners, lamps, trees")
    lamp_count = 0
    for P in site.PARCELS:
        if P["id"] == "P06":
            continue  # same parcel as P12
        q = P["parcel"]; pid = P["id"]
        row2 = P["groundY"] >= 150
        pave_col = PAVE_2 if row2 else PAVE_1
        edges = edge_defs(q)
        info = {}
        for name, a, b, n in edges:
            runs, L, u = facing_runs(a, b, n, ground_y=P["groundY"])
            info[name] = dict(a=a, b=b, n=n, runs=runs, L=L, u=u)
        # corners: corner k is the END of edge k and the START of edge k+1
        rounded = {}
        order = ["N", "E", "S", "W"]
        for k, nm in enumerate(order):
            e1, e2 = info[nm], info[order[(k + 1) % 4]]
            end_ok = e1["runs"] and e1["runs"][-1][1] >= e1["L"] - 2
            start_ok = e2["runs"] and e2["runs"][0][0] <= 2
            rounded[nm] = bool(end_ok and start_ok)
        s.group(f"Streets {pid}")
        for k, nm in enumerate(order):
            E = info[nm]; a, n, (ux, uz) = E["a"], E["n"], E["u"]
            prev = order[(k - 1) % 4]
            for i, (t0, t1, rtop) in enumerate(E["runs"]):
                top = rtop + 1.0
                g0 = rtop - 1.0
                c0 = t0 <= 2; c1 = t1 >= E["L"] - 2
                if c0 and rounded[prev]: t0 = R_CORNER
                if c1 and rounded[nm]: t1 = E["L"] - R_CORNER
                if t1 - t0 < 4: continue
                p0 = (a[0] + ux * t0, a[1] + uz * t0); p1 = (a[0] + ux * t1, a[1] + uz * t1)
                off = lambda p, d: (p[0] + n[0] * d, p[1] + n[1] * d)
                seg(s, off(p0, KERB_W + (FRONTAGE - KERB_W) / 2), off(p1, KERB_W + (FRONTAGE - KERB_W) / 2),
                    FRONTAGE - KERB_W, g0, top, mat="CeramicTiles", var="Paving Slab", color=pave_col, name="Pavement")
                seg(s, off(p0, KERB_W / 2), off(p1, KERB_W / 2), KERB_W, g0, top + 0.15, mat="Concrete", color=KERB, name="Kerb")
                # kerb returns where a run stops mid-edge (another road crosses the strip)
                for tt, pp, sgn in ((t0, p0, 1), (t1, p1, -1)):
                    at_corner = (tt == t0 and c0) or (tt == t1 and c1)
                    beyond = (pp[0] - ux * sgn * 3, pp[1] - uz * sgn * 3)
                    blocked_by_building = any(building_at(beyond[0] + n[0] * d, top + 3, beyond[1] + n[1] * d) for d in (2, 6, 10, 11.5))
                    if not at_corner and not blocked_by_building:
                        q0 = pp
                        seg(s, off(q0, 0), off(q0, FRONTAGE), KERB_W, g0, top + 0.15, mat="Concrete", color=KERB, name="Kerb Return")
                        s.clone("bollard thick", (off(q0, 4)[0] + ux * sgn * 2, top, off(q0, 4)[1] + uz * sgn * 2))
                # street furniture rhythm: lamp every 72, tree between, bollards near ends
                length = t1 - t0
                nl = max(1, int(round(length / LAMP_STEP)))
                stepL = length / nl
                for j in range(nl):
                    tl = t0 + stepL * (j + 0.5)
                    pl = (a[0] + ux * tl, a[1] + uz * tl)
                    lp = off(pl, 2.8)
                    s.group(f"Streets {pid}")
                    lamp(s, lp[0], top, lp[1], (-n[0], -n[1])); lamp_count += 1
                    if j < nl - 1 or nl == 1:
                        tt = tl + stepL / 2 if j < nl - 1 else tl + min(stepL / 2, (t1 - tl) - 8)
                        if t0 + 10 < tt < t1 - 10:
                            pt = off((a[0] + ux * tt, a[1] + uz * tt), 6.5)
                            kind = "Tree Small Bamboo Group" if (row2 and (j % 2)) else "Tree Large Poplar Group"
                            planter_tree(s, pt[0], top, pt[1], kind=kind, size=8, yaw=yaw_z(ux, uz))
        # rounded corners
        for k, nm in enumerate(order):
            if not rounded[nm]:
                continue
            e1, e2 = info[nm], info[order[(k + 1) % 4]]
            cx, cz = e1["b"]
            n1, n2 = e1["n"], e2["n"]
            rtop = e1["runs"][-1][2]; top = rtop + 1.0; g0 = rtop - 1.0
            C = (cx + (n1[0] + n2[0]) * R_CORNER, cz + (n1[1] + n2[1]) * R_CORNER)
            s.group(f"Streets {pid} corner {nm}")
            # asphalt infill between the arc and the square parcel corner, at road level
            sq = 0.55 * R_CORNER
            s.part("Block", (sq, 2, sq), (cx + (n1[0] + n2[0]) * sq / 2, rtop - 1, cz + (n1[1] + n2[1]) * sq / 2),
                   mat="Asphalt", var="Asphalt New", color=ASPH, name="Corner Infill")
            for nn, mm in ((n1, n2), (n2, n1)):
                w = 0.16 * R_CORNER
                cxx = cx + nn[0] * w / 2 + mm[0] * R_CORNER / 2; czz = cz + nn[1] * w / 2 + mm[1] * R_CORNER / 2
                sx = abs(nn[0]) * w + abs(mm[0]) * R_CORNER; sz = abs(nn[1]) * w + abs(mm[1]) * R_CORNER
                s.part("Block", (sx, 2, sz), (cxx, rtop - 1, czz), mat="Asphalt", var="Asphalt New", color=ASPH, name="Corner Infill")
            d = math.radians(90 / N_ARC)
            chord = 2 * R_CORNER * math.sin(d / 2)
            for i in range(N_ARC):
                phi = d * (i + 0.5)
                ux_ = -n1[0] * math.cos(phi) - n2[0] * math.sin(phi); uz_ = -n1[1] * math.cos(phi) - n2[1] * math.sin(phi)
                r_in = max((R_CORNER - FRONTAGE) / max(math.cos(f), math.sin(f)) for f in (phi - d / 2, phi, phi + d / 2)) + 0.5
                r_out = R_CORNER - KERB_W - 0.5
                rm = (r_in + r_out) / 2
                yaw = yaw_z(ux_, uz_)
                s.part("Block", (chord + 0.5, top - g0, r_out - r_in + 0.4), (C[0] + ux_ * rm, (top + g0) / 2, C[1] + uz_ * rm),
                       rot=(0, yaw, 0), mat="CeramicTiles", var="Paving Slab", color=PAVE_PINK, name="Corner Paving")
                rk = R_CORNER - KERB_W / 2 - 0.5
                s.part("Block", (chord + 0.25, top + 0.15 - g0, KERB_W), (C[0] + ux_ * rk, (top + 0.15 + g0) / 2, C[1] + uz_ * rk),
                       rot=(0, yaw, 0), mat="Concrete", color=KERB, name="Corner Kerb")
                if i in (1, 3):
                    rb = R_CORNER - 3.2
                    s.clone("bollard thick", (C[0] + ux_ * rb, top, C[1] + uz_ * rb))
    return s


# ================================================================== 2. THE STEP (retaining wall between the rows)
WALL_Z = 4661.5          # face of the Y200 terrace (row-2 base) towards the Y100 road
LEDGE_Z0 = 4650.5        # north edge of the ledge = south edge of the Y100 road (z=4613, width 75)
ROW2_ROAD_Z = 4705.5     # north edge of the row-2 road (z=4743)
V_STAIRS = [-1250.0, -560.0, 690.0, 1480.0]
FLIGHT_RUN, FLIGHT_RISE, MID_LAND, TOP_LAND = 80.0, 50.0, 12.0, 16.0


def x_runs(z_list, x0, x1, ok, step=4.0):
    runs, cur, x = [], None, x0
    while x <= x1:
        good = all(ok(x, z) for z in z_list)
        if good and cur is None: cur = x
        if not good and cur is not None: runs.append((cur, x - step)); cur = None
        x += step
    if cur is not None: runs.append((cur, x1))
    return [(a + 1.5, b - 1.5) for a, b in runs if b - a > 6]


def build_step():
    s = Spec("streetscape_step", kind="streetscape", title="The Step: stair-streets, ledge and market terrace on the Y100/Y200 retaining wall")
    stair_spans = []
    for xc in V_STAIRS:
        half = TOP_LAND / 2 + 2 * FLIGHT_RUN + MID_LAND
        stair_spans.append((xc - half - 2, xc + half + 2))
    in_stair = lambda x, pad=0: any(a - pad <= x <= b + pad for a, b in stair_spans)

    # ---- ledge pavement at Y100 (kerb + slab), broken only by the boulevard piers
    s.group("Step Ledge")
    ledge_ok = lambda x, z: site.road_hit(x, z, 0.6, 99, 140) is None and (site.ground(x, z) or 0) <= 110
    ledge_runs = x_runs([LEDGE_Z0 + 1.2, WALL_Z - 1.0], -1700, 1900, ledge_ok)
    for x0, x1 in ledge_runs:
        if x1 - x0 < 20: continue
        seg(s, (x0, LEDGE_Z0 + KERB_W + (WALL_Z - LEDGE_Z0 - KERB_W) / 2), (x1, LEDGE_Z0 + KERB_W + (WALL_Z - LEDGE_Z0 - KERB_W) / 2),
            WALL_Z - LEDGE_Z0 - KERB_W, 99, 102, mat="CeramicTiles", var="Paving Slab", color=PAVE_1, name="Ledge Pavement")
        seg(s, (x0, LEDGE_Z0 + KERB_W / 2), (x1, LEDGE_Z0 + KERB_W / 2), KERB_W, 99, 102.15, mat="Concrete", color=KERB, name="Kerb")
    print("  ledge runs", [(round(a), round(b)) for a, b in ledge_runs])

    # ---- V stair-streets: two flights climb towards a central tower landing at Y200
    zs = LEDGE_Z0 + KERB_W + 0.7; zc = (zs + WALL_Z) / 2; wz = WALL_Z - zs
    for si, xc in enumerate(V_STAIRS):
        s.group(f"Stair Street {si + 1}")
        s.part("Block", (TOP_LAND, 102, wz), (xc, 151, zc), mat="Concrete", var="SG Weathered Concrete", color=CONC, name="Stair Tower")
        s.part("Block", (TOP_LAND, 0.4, wz), (xc, 202.2, zc), mat="CeramicTiles", var="Textile Paving", color=(196, 176, 70), name="Landing Tactile")
        for sgn in (-1, 1):
            # upper flight: Y150 -> Y200, rising towards the tower
            xa = xc + sgn * (TOP_LAND / 2)                       # top end
            xb = xa + sgn * FLIGHT_RUN                           # bottom end at Y150
            xm0, xm1 = xb, xb + sgn * MID_LAND                   # mid landing
            xd = xm1 + sgn * FLIGHT_RUN                          # bottom end at Y100
            yaw_up = -90 if sgn > 0 else 90                      # wedge rises towards the tower
            s.part("Wedge", (wz, FLIGHT_RISE, FLIGHT_RUN), ((xa + xb) / 2, 150 + FLIGHT_RISE / 2, zc), rot=(0, yaw_up, 0),
                   mat="Concrete", var="Concrete Square Tiles", color=(168, 164, 156), name="Flight Upper")
            s.part("Block", (FLIGHT_RUN, 50, wz), ((xa + xb) / 2, 125, zc), mat="Concrete", var="SG Weathered Concrete", color=CONC_D, name="Flight Upper Base")
            s.part("Block", (MID_LAND, 50, wz), ((xm0 + xm1) / 2, 125, zc), mat="Concrete", var="SG Weathered Concrete", color=CONC, name="Mid Landing")
            s.part("Block", (MID_LAND, 0.4, wz), ((xm0 + xm1) / 2, 150.2, zc), mat="CeramicTiles", var="Textile Paving", color=(196, 176, 70), name="Landing Tactile")
            s.part("Wedge", (wz, FLIGHT_RISE, FLIGHT_RUN), ((xm1 + xd) / 2, 100 + FLIGHT_RISE / 2, zc), rot=(0, yaw_up, 0),
                   mat="Concrete", var="Concrete Square Tiles", color=(168, 164, 156), name="Flight Lower")
            # road-side balustrades (sloped), and a flat one on the mid landing
            ang = math.degrees(math.atan2(FLIGHT_RISE, FLIGHT_RUN)); Ls = math.hypot(FLIGHT_RISE, FLIGHT_RUN)
            zb = zs + 0.6
            for (xt, xbm, ybot) in ((xa, xb, 150), (xm1, xd, 100)):
                mx = (xt + xbm) / 2; my = ybot + FLIGHT_RISE / 2 + 2.2
                s.part("Block", (Ls, 3.4, 1.2), (mx, my, zb), rot=(0, 0, -sgn * ang), mat="Concrete", color=(186, 184, 178), name="Balustrade")
            s.part("Block", (MID_LAND, 3.4, 1.2), ((xm0 + xm1) / 2, 151.7, zb), mat="Concrete", color=(186, 184, 178), name="Balustrade")
            # graffiti on the flight base (visible from the road)
            s.part("Block", (FLIGHT_RUN - 4, 36, 0.6), ((xa + xb) / 2, 128, zs - 0.35), mat="Concrete",
                   var=("SG Graffiti A" if (si + sgn) % 2 else "SG Graffiti B"), color=(200, 200, 200), layer="LOD2", name="Graffiti Stair")
        # sign strip on the tower top
        s.part("Block", (TOP_LAND - 2, 1.2, 0.6), (xc, 196, LEDGE_Z0 + KERB_W - 0.1), mat="Neon", color=(255, 90, 170), layer="LOD2", name="Neon Strip")

    # ---- wall face dressing on the ledge between the stairs: graffiti bands, shutters in the wall, pipes, vending
    s.group("Step Wall Life")
    fz = WALL_Z - 0.5
    for x0, x1 in ledge_runs:
        # free wall stretches between stair-streets
        stretches, a = [], x0 + 4
        for (sa, sb) in sorted(stair_spans) + [(x1 - 4, x1 - 4)]:
            if sb < a: continue
            if min(sa, x1 - 4) - a > 30: stretches.append((a, min(sa, x1 - 4)))
            a = max(a, sb)
        for (a, b) in stretches:
            # 1) continuous graffiti band along the lower wall, 40-stud tiles, alternating A/B pieces of 80/120/160
            x = a; k = 0
            while b - x >= 40:
                w = min(b - x, (80, 120, 160, 80)[k % 4]); w = 40 * int(w // 40)
                h = (44, 56, 40, 64)[k % 4]
                s.part("Block", (w, h, 1.0), (x + w / 2, 102 + h / 2, fz), mat="Concrete", var=("SG Graffiti A" if k % 2 == 0 else "SG Graffiti B"),
                       color=(205, 205, 205), layer="LOD2", name="Graffiti Wall")
                x += w; k += 1
            # 2) life in front of the band: shops in the wall, vending, pipes, benches, planters, laundry from the parapet
            x = a + 12; k = 0
            while x + 30 < b - 8:
                mod = k % 5
                if mod == 0:       # shop / lock-up set into the wall: shutter + lintel + sign + vending pair
                    s.part("Block", (20, 13, 1.0), (x + 12, 108.5, WALL_Z - 1.4), mat="Metal", var="Metal Shutters", color=RNG.choice([(150, 152, 156), (170, 120, 110), (110, 140, 160)]),
                           layer="LOD2", name="Wall Shutter")
                    s.part("Block", (24, 3, 3), (x + 12, 116.5, WALL_Z - 1.5), mat="Concrete", color=CONC_D, layer="LOD2", name="Shutter Lintel")
                    s.part("Block", (10, 2.4, 0.6), (x + 12, 120, WALL_Z - 3.3), mat="Neon", color=RNG.choice([(80, 230, 255), (255, 90, 170), (255, 200, 60)]),
                           layer="LOD2", name="Shop Sign")
                    s.kit("vending_machine", (x + 28, 106.5, WALL_Z - 2.2), rot=(0, 0, 0))
                    s.kit("vending_machine", (x + 34, 106.5, WALL_Z - 2.2), rot=(0, 0, 0))
                    x += 44
                elif mod == 1:     # downpipes climbing the full wall + AC units
                    s.kit("pipe_bundle_40", (x + 3, 122, WALL_Z - 1.6), rot=(0, 0, 0))
                    s.kit("pipe_bundle_40", (x + 3, 162, WALL_Z - 1.6), rot=(0, 0, 0))
                    s.kit("ac_cluster", (x + 12, 152, WALL_Z - 2.1), rot=(0, 0, 0))
                    s.kit("ac_cluster", (x + 12, 172, WALL_Z - 2.1), rot=(0, 0, 0))
                    x += 26
                elif mod == 2:     # bench + wall planter
                    s.kit("bench_concrete", (x + 8, 103.5, WALL_Z - 2.3), rot=(0, 0, 0))
                    s.part("Block", (16, 3, 5), (x + 26, 103.5, WALL_Z - 2.6), mat="Concrete", var="Concrete Square Tiles", color=CONC_D, layer="LOD3", name="Wall Planter")
                    s.clone("path bush group A", (x + 26, 105, WALL_Z - 2.6), rot=(0, 90, 0), layer="LOD3")
                    x += 40
                elif mod == 3:     # laundry strung below the parapet, hanging over the wall face (never beyond the ledge)
                    s.kit("laundry_line_36", (x + 18, 192, WALL_Z - 1.0), rot=(0, 0, 0))
                    s.kit("laundry_line_36", (x + 18, 180, WALL_Z - 1.0), rot=(0, 0, 0))
                    x += 40
                else:              # vending trio against the wall
                    for j in range(3):
                        s.kit("vending_machine", (x + 3 + 6 * j, 106.5, WALL_Z - 2.2), rot=(0, 0, 0))
                    x += 30
                k += 1
        # ledge lamps (heads over the Y100 road) on a 72 rhythm, skipping stairs
        xl = x0 + 30
        while xl < x1 - 10:
            if not in_stair(xl, 3):
                lamp(s, xl, 102, LEDGE_Z0 + 3.0, (0, -1))
            xl += LAMP_STEP
    # big murals on the stair towers
    for si, xc in enumerate(V_STAIRS):
        s.group(f"Stair Street {si + 1}")
        s.part("Block", (TOP_LAND - 2, 80, 0.6), (xc, 145, zs - 0.35), mat="Concrete", var=("SG Graffiti B" if si % 2 else "SG Graffiti A"),
               color=(210, 210, 210), layer="LOD2", name="Tower Mural")

    # ---- upper terrace (Y200): market street between the parapet and the row-2 road
    s.group("Step Terrace")
    terr_ok = lambda x, z: site.road_hit(x, z, 0.0, 199, 225) is None and 190 <= (site.ground(x, z) or 0) <= 210
    t_runs = x_runs([WALL_Z + 0.6 + k * (ROW2_ROAD_Z - WALL_Z - 1.2) / 10 for k in range(11)], -1800, 2000, terr_ok)
    print("  terrace runs", [(round(a), round(b)) for a, b in t_runs])
    tz_mid = (WALL_Z + ROW2_ROAD_Z - KERB_W) / 2
    for x0, x1 in t_runs:
        if x1 - x0 < 30: continue
        seg(s, (x0, tz_mid), (x1, tz_mid), ROW2_ROAD_Z - KERB_W - WALL_Z, 199, 202, mat="CeramicTiles", var="Paving Slab", color=PAVE_2, name="Terrace Paving")
        seg(s, (x0, ROW2_ROAD_Z - KERB_W / 2), (x1, ROW2_ROAD_Z - KERB_W / 2), KERB_W, 199, 202.15, mat="Concrete", color=KERB, name="Kerb")
        # parapet along the wall edge with openings at the stair heads
        cuts = sorted([(xc - TOP_LAND / 2, xc + TOP_LAND / 2) for xc in V_STAIRS if x0 < xc < x1])
        a = x0
        for c0, c1 in cuts + [(x1, x1)]:
            if c0 - a > 2:
                seg(s, (a, WALL_Z + 0.9), (c0, WALL_Z + 0.9), 1.8, 199, 205.5, mat="Concrete", var="SG Weathered Concrete", color=CONC, name="Parapet")
                seg(s, (a, WALL_Z + 0.9), (c0, WALL_Z + 0.9), 2.4, 205.5, 206.3, mat="Metal", color=YELLOW, layer="LOD2", name="Parapet Rail")
            a = c1
        # furniture: market clusters by each stair head, vending/benches/trees in between
        xl = x0 + 24
        while xl < x1 - 12:
            lamp(s, xl, 202, ROW2_ROAD_Z - 3.0, (0, 1))
            if xl + 36 < x1 - 12:
                planter_tree(s, xl + 36, 202, ROW2_ROAD_Z - 7.5, kind=RNG.choice(["Tree Large Poplar Group", "Tree Small Bamboo Group"]), size=9)
            xl += LAMP_STEP
        for xc in V_STAIRS:
            if not (x0 + 60 < xc < x1 - 60): continue
            s.group(f"Market {int(xc)}")
            s.part("Block", (TOP_LAND + 8, 0.4, 20), (xc, 202.2, WALL_Z + 12), mat="CeramicTiles", var="Paving Slab", color=PAVE_PINK, name="Stairhead Paving")
            for sgn in (-1, 1):
                for j in range(3):
                    sx = xc + sgn * (TOP_LAND / 2 + 6 + 10 + j * 22)
                    s.kit("market_stall", (sx, 209, WALL_Z + 2 + 7 + 0.2), rot=(0, 180, 0),
                          color=RNG.choice([(220, 70, 80), (60, 150, 210), (240, 180, 50), (90, 180, 110)]))
                vx = xc + sgn * (TOP_LAND / 2 + 6 + 3 * 22 + 8)
                s.kit("vending_machine", (vx, 206.5, WALL_Z + 4.2), rot=(0, 180, 0))
                s.kit("vending_machine", (vx + sgn * 6, 206.5, WALL_Z + 4.2), rot=(0, 180, 0))
                s.kit("bench_concrete", (xc + sgn * 40, 203.5, WALL_Z + 24), rot=(0, 180, 0))
    return s


# ================================================================== 3. WATERFRONT
QUAY_Z = 3915.5          # north edge of the row-1 baseplates = water's edge
WF_ROAD_Z = 4002.5       # north edge of the z=4040 road
PIERS = [-600.0, 760.0]


def build_waterfront():
    s = Spec("streetscape_waterfront", kind="streetscape", title="Waterfront promenade and fishing piers")
    ok = lambda x, z: site.road_hit(x, z, 0.6, 99, 130) is None and 95 <= (site.ground(x, z) or 0) <= 110
    runs = x_runs([QUAY_Z + 1, 3960, WF_ROAD_Z - 1], -1020, 1420, ok)
    print("  waterfront runs", [(round(a), round(b)) for a, b in runs])
    for ri, (x0, x1) in enumerate(runs):
        if x1 - x0 < 40: continue
        s.group("Promenade")
        # road-side pavement + kerb (12 wide)
        seg(s, (x0, WF_ROAD_Z - KERB_W - 5.25), (x1, WF_ROAD_Z - KERB_W - 5.25), 10.5, 99, 102, mat="CeramicTiles", var="Paving Slab", color=PAVE_1, name="Pavement")
        seg(s, (x0, WF_ROAD_Z - KERB_W / 2), (x1, WF_ROAD_Z - KERB_W / 2), KERB_W, 99, 102.15, mat="Concrete", color=KERB, name="Kerb")
        # green verge
        seg(s, (x0, 3979.5), (x1, 3979.5), 21, 99, 100.8, mat="Ground", var="Bush Grassy", color=GRASS, name="Verge")
        seg(s, (x0, 3968.5), (x1, 3968.5), 1.2, 99, 101.6, mat="Concrete", color=KERB, name="Verge Edge")
        # promenade: pink paving band + timber boardwalk at the quay
        seg(s, (x0, 3957), (x1, 3957), 22, 99, 100.9, mat="CeramicTiles", var="Paving Slab", color=PAVE_PINK, name="Promenade Paving")
        seg(s, (x0, 3931.5), (x1, 3931.5), 29, 99, 100.9, mat="Wood", var="Plywood", color=TIMBER, name="Boardwalk")
        seg(s, (x0, QUAY_Z + 1.5), (x1, QUAY_Z + 1.5), 3, 97, 101.6, mat="Concrete", var="SG Weathered Concrete", color=KERB, name="Quay Coping")
        # railings (178 long clones) along the quay; gaps at the piers
        cuts = [x0 + 2] + sum([[px - 8, px + 8] for px in PIERS if x0 < px < x1], []) + [x1 - 2]
        for ra, rb in zip(cuts[0::2], cuts[1::2]):
            xr = ra
            while xr + 178 <= rb:
                s.clone("Railings Left", (xr + 89, 101.6, QUAY_Z + 2.2), rot=(0, 90, 0)); xr += 178
            while xr + 12 <= rb:
                s.clone("railing simple", (xr + 6, 101.6, QUAY_Z + 2.2), rot=(0, 90, 0)); xr += 12
        # rhythm: lamps both along the road and the boardwalk; trees on the verge; benches facing the water
        xl = x0 + 20; j = 0
        while xl < x1 - 10:
            lamp(s, xl, 102, WF_ROAD_Z - 2.8, (0, 1))
            lamp(s, xl + 36, 100.9, 3947.5, (0, -1))
            if xl + 36 < x1 - 20:
                s.clone("Tree Large Poplar Group" if j % 3 else "Tree Large Maple", (xl + (36 if j % 3 else 0) - 18, 100.8, 3980), rot=(0, (j * 67) % 360, 0), layer="LOD3")
            if xl + 18 < x1 - 20 and not any(abs(xl + 18 - px) < 20 for px in PIERS):
                s.kit("bench_concrete", (xl + 18, 102.4, 3928), rot=(0, 0, 0))
                s.kit("bench_concrete", (xl + 54, 102.4, 3928), rot=(0, 0, 0))
            if j % 4 == 1:
                s.clone("path bush group A", (xl + 54, 100.8, 3980), rot=(0, 90, 0), layer="LOD3")
            xl += LAMP_STEP; j += 1
    # kiosks near the piers + fishing piers
    for pi, px in enumerate(PIERS):
        s.group(f"Pier {pi + 1}")
        L, W = 96.0, 14.0
        z_end = QUAY_Z - L
        s.part("Block", (W, 1.2, L + 2), (px, 100.3, QUAY_Z - L / 2 + 1), mat="Wood", var="Plywood", color=TIMBER, name="Pier Deck")
        s.part("Block", (40, 1.2, 16), (px, 100.3, z_end - 6), mat="Wood", var="Plywood", color=TIMBER, name="Pier Head")
        s.part("Block", (W + 2, 3, L + 2), (px, 98.2, QUAY_Z - L / 2 + 1), mat="Concrete", color=CONC_D, name="Pier Beam")
        for zz in [QUAY_Z - 12 - 16 * k for k in range(6)] + [z_end - 10]:
            for dx in ((-W / 2 + 1.5, W / 2 - 1.5) if zz > z_end else (-17, -6, 6, 17)):
                s.part("Cylinder", (30, 3, 3), (px + dx, 84, zz), rot=(0, 0, 90), mat="Concrete", color=CONC_D, layer="LOD3", name="Pile")
        for dx in (-W / 2 + 0.6, W / 2 - 0.6):
            s.part("Block", (1.2, 1.0, L - 2), (px + dx, 104.2, QUAY_Z - L / 2), mat="Metal", color=YELLOW, layer="LOD2", name="Pier Rail")
            for zz in [QUAY_Z - 4 - 16 * k for k in range(6)]:
                s.part("Block", (1.2, 3.2, 1.2), (px + dx, 102.5, zz), mat="Metal", color=METAL, layer="LOD1", name="Rail Post")
        s.part("Block", (40, 1.0, 1.2), (px, 104.2, z_end - 13.4), mat="Metal", color=YELLOW, layer="LOD2", name="Pier Rail")
        s.part("Block", (1.2, 1.0, 16), (px - 19.4, 104.2, z_end - 6), mat="Metal", color=YELLOW, layer="LOD2", name="Pier Rail")
        s.part("Block", (1.2, 1.0, 16), (px + 19.4, 104.2, z_end - 6), mat="Metal", color=YELLOW, layer="LOD2", name="Pier Rail")
        lamp(s, px + 16, 100.9, z_end - 10, (0, 1))
        s.kit("bench_concrete", (px - 8, 102.4, z_end - 11), rot=(0, 0, 0))
        s.kit("bench_concrete", (px + 8, 102.4, z_end - 11), rot=(0, 0, 0))
        # fishing kiosk + vending on the promenade next to the pier root
        s.kit("market_stall", (px + 30, 107.9, 3957), rot=(0, 0, 0), color=(60, 150, 210) if pi else (240, 180, 50))
        s.kit("vending_machine", (px - 24, 105.4, 3960), rot=(0, 0, 0))
        s.kit("vending_machine", (px - 30, 105.4, 3960), rot=(0, 0, 0))
    return s


# ================================================================== 4. WEST POCKET PARK
def build_westpark():
    s = Spec("streetscape_westpark", kind="streetscape", title="West lot pocket park with futsal cage")
    G = 100.0
    # --- park ground: 6-stud grass columns clipped to the free Y100 lot, a kerb polyline along the curved road
    s.group("Park Ground")
    free = lambda x, z: (site.road_hit(x, z, 1.0, 99, 110) is None and site.in_parcel(x, z) is None
                         and 95 <= (site.ground(x, z) or 0) <= 110)
    CW = 6.0
    kerb_pts = []
    x = -1998.0
    while x < -1462:
        # free z-runs at the column centre and both column edges (1-stud resolution), intersected
        cols = []
        for xx in (x - CW / 2 + 0.3, x, x + CW / 2 - 0.3):
            cols.append({int(z) for z in range(3880, 4300) if free(xx, z)})
        ok = sorted(cols[0] & cols[1] & cols[2])
        runs, cur, prev = [], None, None
        for z in ok:
            if cur is None: cur = z
            elif z != prev + 1: runs.append((cur, prev)); cur = z
            prev = z
        if cur is not None: runs.append((cur, prev))
        for (z0, z1) in runs:
            if z1 - z0 < 8: continue
            z0g = z0 + 2.0
            s.part("Block", (CW + 0.2, 1.0, z1 - z0g), (x, G + 0.25, (z0g + z1) / 2), mat="Ground", var="Bush Grassy", color=(84, 120, 62),
                   name="Park Grass")
            if site.road_hit(x, z0 - 2, 0, 99, 110) is not None:   # this run starts at the road: remember the kerb line
                kerb_pts.append((x, z0 + 0.8))
        x += CW
    # kerb along the road edge (short segments following the column tops)
    for a, b in zip(kerb_pts, kerb_pts[1:]):
        if abs(b[0] - a[0]) <= CW + 0.1 and abs(b[1] - a[1]) < 6:
            seg(s, (a[0] - 0.3, a[1]), (b[0] + 0.3, b[1]), KERB_W, G - 1, G + 1.3, mat="Concrete", color=KERB, name="Park Kerb")
    # cover the small hole to the sea north of P01 (a gap in the blockout baseplates)
    s.part("Block", (24, 2, 50), (-1540, G - 0.25, 4052), mat="Ground", var="Bush Grassy", color=(84, 120, 62), name="Hole Cover")

    # --- futsal cage (60 x 40) aligned with the curved road above it
    s.group("Futsal Cage")
    cx, cz, cyaw = -1845.0, 4032.0, -14.0
    a = math.radians(cyaw); ex = (math.cos(a), -math.sin(a)); ez = (math.sin(a), math.cos(a))  # local X / Z in world
    W_, D_ = 60.0, 40.0
    P = lambda lx, lz: (cx + ex[0] * lx + ez[0] * lz, cz + ex[1] * lx + ez[1] * lz)
    s.part("Block", (W_ + 6, 0.8, D_ + 6), (cx, G + 0.4, cz), rot=(0, cyaw, 0), mat="Concrete", color=(120, 122, 118), name="Court Base")
    s.part("Block", (W_, 0.3, D_), (cx, G + 0.95, cz), rot=(0, cyaw, 0), mat="SmoothPlastic", color=(48, 120, 110), name="Court Surface")
    for lx, lz, sx, sz in ((0, 0, 1, D_ - 2), (0, -D_ / 2 + 1, W_ - 2, 1), (0, D_ / 2 - 1, W_ - 2, 1), (-W_ / 2 + 1, 0, 1, D_ - 2), (W_ / 2 - 1, 0, 1, D_ - 2)):
        p = P(lx, lz)
        s.part("Block", (sx, 0.1, sz), (p[0], G + 1.15, p[1]), rot=(0, cyaw, 0), mat="SmoothPlastic", color=(235, 235, 230), collide=False, layer="LOD1", name="Court Line")
    p = P(0, 0)
    s.part("Cylinder", (0.1, 14, 14), (p[0], G + 1.12, p[1]), rot=(0, cyaw, 90), mat="SmoothPlastic", color=(235, 235, 230), collide=False, layer="LOD1", name="Centre Circle")
    s.part("Cylinder", (0.12, 12, 12), (p[0], G + 1.14, p[1]), rot=(0, cyaw, 90), mat="SmoothPlastic", color=(48, 120, 110), collide=False, layer="LOD1", name="Centre Circle Fill")
    # cage: chainlink panels round the court (a gate gap on the south side)
    for side in range(4):
        if side in (0, 2):  # long sides along local X at lz = -+(D/2+2)
            lz = (-1 if side == 0 else 1) * (D_ / 2 + 2)
            for k in range(3):
                if side == 2 and k == 1: continue
                p = P(-20 + 20 * k, lz)
                s.kit("chainlink_fence_20", (p[0], G + 6.8, p[1]), rot=(0, cyaw, 0), scale=1.0)
        else:
            lx = (-1 if side == 1 else 1) * (W_ / 2 + 2)
            for k in range(2):
                p = P(lx, -10 + 20 * k + (1 if k else -1) * 1)
                s.kit("chainlink_fence_20", (p[0], G + 6.8, p[1]), rot=(0, cyaw + 90, 0))
    # goals (tube frames) at both ends
    for sg in (-1, 1):
        for lz in (-6, 6):
            p = P(sg * (W_ / 2 - 1.5), lz)
            s.part("Block", (1, 7, 1), (p[0], G + 4.6, p[1]), rot=(0, cyaw, 0), mat="Metal", color=(230, 230, 230), layer="LOD1", name="Goal Post")
        p = P(sg * (W_ / 2 - 1.5), 0)
        s.part("Block", (1, 1, 13), (p[0], G + 8.6, p[1]), rot=(0, cyaw, 0), mat="Metal", color=(230, 230, 230), layer="LOD1", name="Goal Bar")
    # floodlight poles for the cage
    for lx, lz in ((-W_ / 2 - 5, -D_ / 2 - 5), (W_ / 2 + 5, D_ / 2 + 5)):
        p = P(lx, lz)
        lamp(s, p[0], G + 0.8, p[1], (-(ex[0] * lx + ez[0] * lz), -(ex[1] * lx + ez[1] * lz)))
    s.part("Block", (W_ + 10, 3.5, 1.2), (P(0, -D_ / 2 - 2.6)[0], G + 14.3, P(0, -D_ / 2 - 2.6)[1]), rot=(0, cyaw, 0),
           mat="Concrete", var="SG Graffiti A", color=(210, 210, 210), layer="LOD2", name="Cage Banner")

    # --- lawns (round, edged) and a paved circle at the path junction
    s.group("Park Lawns")
    for (x, z, d) in ((-1952, 4000, 64), (-1720, 4032, 44), (-1880, 4128, 44), (-1805, 4205, 26), (-1620, 4040, 30)):
        s.part("Cylinder", (1.2, d + 3, d + 3), (x, G + 0.6, z), rot=(0, 0, 90), mat="Concrete", color=KERB, name="Lawn Edge")
        s.part("Cylinder", (1.4, d, d), (x, G + 0.7, z), rot=(0, 0, 90), mat="Grass", color=GRASS, name="Lawn")
    s.part("Cylinder", (1.0, 30, 30), (-1780, G + 0.5, 4095), rot=(0, 0, 90), mat="CeramicTiles", var="Paving Slab", color=PAVE_PINK, name="Plaza Circle")
    planter_tree(s, -1780, G + 1.0, 4095, kind="Tree Large Maple", size=10)

    # --- curving paths (segments)
    s.group("Park Paths")
    main = [(-2000, 4062), (-1975, 4050), (-1905, 4082), (-1845, 4072), (-1790, 4088), (-1735, 4068), (-1665, 4064), (-1585, 4052), (-1520, 4044), (-1470, 4028)]
    south = [(-1780, 4095), (-1812, 4150), (-1800, 4210), (-1782, 4255)]
    north = [(-1905, 4082), (-1928, 4030), (-1960, 3955), (-1930, 3920)]
    for pts in (main, south, north):
        path_strip(s, catmull(pts, 9), 9, G + 1.0)
    # --- trees, bushes, benches, lamps along the paths
    s.group("Park Planting")
    for (x, z, k) in ((-1985, 3985, "Tree Large Maple"), (-1935, 4005, "Tree Large Poplar Group"), (-1700, 4040, "Tree Large Maple"),
                      (-1868, 4135, "Tree Large Poplar Group"), (-1895, 4118, "Tree Small Bamboo Group"), (-1640, 4032, "Tree Large Poplar Group"),
                      (-1600, 4046, "Tree Small Bamboo Group"), (-1810, 4205, "Tree Large Poplar Group"), (-1790, 4238, "Tree Small Bamboo Group"),
                      (-1760, 4180, "Tree Small Bamboo Group"), (-1960, 4020, "Tree Small Bamboo Group"), (-2010, 4030, "Tree Large Poplar Group")):
        s.clone(k, (x, G + 1.4, z), rot=(0, RNG.randrange(0, 360, 30), 0), layer="LOD3")
    for (x, z, yaw) in ((-1985, 4070, 0), (-1560, 4058, 90), (-1850, 4110, 150)):
        s.clone("Bush Large", (x, G, z), rot=(0, yaw, 0), layer="LOD3")
    for (x, z, f) in ((-1870, 4090, (0, 1)), (-1760, 4080, (0, 1)), (-1690, 4056, (0, -1)), (-1560, 4036, (0, -1)), (-1818, 4178, (1, 0))):
        s.kit("bench_concrete", (x, G + 2.5, z), rot=(0, yaw_front(*f), 0))
    for (x, z, h) in ((-1940, 4064, (0, -1)), (-1815, 4082, (0, 1)), (-1700, 4076, (0, -1)), (-1600, 4062, (0, 1)), (-1500, 4040, (0, 1)),
                      (-1797, 4160, (1, 0)), (-1790, 4240, (1, 0)), (-1945, 3990, (1, 0))):
        lamp(s, x, G + 1.0, z, h)
    s.kit("vending_machine", (-1818, G + 5.5, 4060), rot=(0, 180 - 14, 0))
    s.kit("vending_machine", (-1812, G + 5.5, 4059), rot=(0, 180 - 14, 0))
    return s


# ================================================================== 5. EAST WEDGE: street-racing hangout
# Lot A (ground Y200) is bounded by the yaw -75 roads (north z=3910, south z=4414), the yaw -20 road (west) and the yaw -167 road (east).
# Local lot frame: U along (-0.966, 0.259) (west along the N/S roads), N along (0.259, 0.966) (southward).
_a = math.radians(-75)
UV = (math.sin(_a), math.cos(_a))        # local +Z of a yaw -75 part = direction along the road
NV = (math.cos(_a), -math.sin(_a))       # local +X of a yaw -75 part


def lot(u, n):
    return (UV[0] * u + NV[0] * n, UV[1] * u + NV[1] * n)


def build_eastlot():
    s = Spec("streetscape_eastlot", kind="streetscape", title="East wedge street-racing hangout")
    G = 200.0
    YAW = -75.0
    n_lo = NV[0] * 2221 + NV[1] * 3910 + 37.5   # south edge of north road
    n_hi = NV[0] * 2273 + NV[1] * 4414 - 37.5   # north edge of south road
    u_of = lambda x, z: UV[0] * x + UV[1] * z
    # find usable u-range per n by sampling
    def u_range(n, pad=6):
        """Longest contiguous free u-run at this n (lot A only; other lots across the roads are ignored)."""
        good = lambda u: (lambda p: site.road_hit(p[0], p[1], pad, 199, 230) is None and 190 <= (site.ground(p[0], p[1]) or 0) <= 210)(lot(u, n))
        runs, cur = [], None
        for u in range(-1700, -600, 2):
            if good(u):
                cur = u if cur is None else cur
            elif cur is not None:
                runs.append((cur, u - 2)); cur = None
        if cur is not None: runs.append((cur, -600))
        return max(runs, key=lambda r: r[1] - r[0]) if runs else None
    print("  lot n range", round(n_lo), round(n_hi), [(round(n), u_range(n)) for n in (n_lo + 10, (n_lo + n_hi) / 2, n_hi - 10)])

    def box(size, u, n, y, name, yaw_off=0, **kw):
        x, z = lot(u, n)
        return s.part("Block", size, (x, y, z), rot=(0, YAW + yaw_off, 0), name=name, **kw)

    # Lot A is a triangle: apex at the north road, base along the south road, sides on the yaw -20 (west) and yaw -167 (east) roads.
    # ---- car meet pad along the wide southern base, bay lines as thin parts on the pad (never on a road)
    s.group("Car Meet")
    pad_n1 = n_hi - 16; pad_n0 = pad_n1 - 150
    mid_n = (pad_n0 + pad_n1) / 2
    ur = [u_range(pad_n0 + (pad_n1 - pad_n0) * k / 6, 10) for k in range(7)]
    pu0 = max(r[0] for r in ur) + 6; pu1 = min(r[1] for r in ur) - 6
    pad_len = pu1 - pu0; pad_dep = pad_n1 - pad_n0; pu_c = (pu0 + pu1) / 2
    box((pad_dep, 1.0, pad_len), pu_c, mid_n, G + 0.5, "Meet Pad", mat="Asphalt", var="Asphalt New", color=(58, 60, 66))
    print("  pad", round(pad_len), "x", round(pad_dep))
    bay_w, bay_d = 12.0, 22.0
    nb = int((pad_len - 24) // bay_w)
    ub0 = pu_c + nb * bay_w / 2
    rows = ((pad_n0 + 3 + bay_d / 2, -1), (mid_n - bay_d / 2, 1), (mid_n + bay_d / 2, -1), (pad_n1 - 3 - bay_d / 2, 1))
    for row_n, sgn in rows:
        for i in range(nb + 1):
            box((bay_d, 0.12, 1.0), ub0 - i * bay_w, row_n, G + 1.06, "Bay Line", mat="SmoothPlastic", color=(236, 236, 230), collide=False, layer="LOD1")
        box((1.0, 0.12, nb * bay_w + 1), pu_c, row_n + sgn * bay_d / 2, G + 1.06, "Bay Head Line", mat="SmoothPlastic", color=(236, 236, 230),
            collide=False, layer="LOD1")
    box((2.0, 0.14, nb * bay_w + 1), pu_c, mid_n, G + 1.08, "Spine Line", mat="SmoothPlastic", color=YELLOW, collide=False, layer="LOD1")
    # start line across the north aisle (on the pad)
    ln = (pad_n0 + 3 + bay_d + mid_n - bay_d) / 2
    box((4.0, 0.14, 30), pu_c, ln, G + 1.08, "Start Line", mat="SmoothPlastic", color=(236, 236, 230), collide=False, layer="LOD1")
    # jersey barriers along the pad's north edge (entrance gap in the middle)
    u = pu0 + 2
    while u + 10 < pu1:
        if abs(u + 5 - pu_c) > 22:
            box((2.4, 3.2, 10), u + 5, pad_n0 - 3, G + 1.6, "Barrier", mat="Concrete", color=(200, 196, 188), layer="LOD2")
        u += 12
    for (uu, nn) in ((pu0 - 3, pad_n0 - 7), (pu1 + 3, pad_n0 - 7), (pu0 - 3, pad_n1 + 5), (pu1 + 3, pad_n1 + 5), (pu_c, pad_n1 + 5)):
        x, z = lot(uu, nn)
        s.part("Block", (2.5, 60, 2.5), (x, G + 30, z), rot=(0, YAW, 0), mat="Metal", color=METAL, layer="LOD2", name="Mast")
        s.part("Block", (5, 4, 10), (x, G + 61, z), rot=(0, YAW, 0), mat="Metal", color=(60, 62, 66), layer="LOD2", name="Floodlight Head")
        s.part("Block", (4, 0.4, 9), (x, G + 58.9, z), rot=(0, YAW, 0), mat="Neon", color=(255, 244, 214), layer="LOD2", name="Floodlight Lens")

    # ---- lock-up garages along the west (yaw -20) road, doors facing into the lot
    s.group("Lockups West")
    wyaw = -20.0
    wdir = (math.sin(math.radians(wyaw)), math.cos(math.radians(wyaw)))       # along the road
    wn = (math.cos(math.radians(wyaw)), -math.sin(math.radians(wyaw)))        # into the lot (east)
    uw, depth, hgt = 20.0, 24.0, 16.0
    line0 = (2055 + wn[0] * (37.5 + 5 + depth / 2), 4342 + wn[1] * (37.5 + 5 + depth / 2))
    placed = []
    for t in range(-460, 300, int(uw)):
        c = (line0[0] + wdir[0] * t, line0[1] + wdir[1] * t)
        corners = [(c[0] + wn[0] * lx + wdir[0] * lz, c[1] + wn[1] * lx + wdir[1] * lz) for lx in (-depth / 2, depth / 2 + 4) for lz in (-uw / 2, uw / 2)]
        if all(site.road_hit(x, z, 1, 199, 230) is None and 190 <= (site.ground(x, z) or 0) <= 210 and NV[0] * x + NV[1] * z < pad_n0 - 8 for x, z in corners):
            placed.append((t, c))
    for i, (t, c) in enumerate(placed):
        s.part("Block", (depth, hgt, uw), (c[0], G + hgt / 2, c[1]), rot=(0, wyaw, 0), mat="Concrete", var="SG Weathered Concrete", color=(150, 146, 140), name="Lockup Unit")
        s.part("Block", (depth + 5, 1.6, uw + 0.2), (c[0] + wn[0] * 2.5, G + hgt + 0.8, c[1] + wn[1] * 2.5), rot=(0, wyaw, 0), mat="Concrete", color=CONC_D, name="Lockup Roof")
        f = (c[0] + wn[0] * (depth / 2 + 0.2), c[1] + wn[1] * (depth / 2 + 0.2))
        if i % 3 == 1:
            s.part("Block", (0.6, 12, uw - 4), (f[0], G + 6, f[1]), rot=(0, wyaw, 0), mat="SmoothPlastic", color=(28, 30, 34), layer="LOD2", name="Open Bay (dark)")
            s.part("Block", (0.6, 2.2, uw - 4), (f[0] + wn[0] * 0.1, G + 13.6, f[1] + wn[1] * 0.1), rot=(0, wyaw, 0), mat="Metal", var="Metal Shutters",
                   color=(170, 172, 176), layer="LOD2", name="Rolled Shutter")
            s.part("Block", (0.4, 0.8, uw - 6), (f[0] - wn[0] * 0.4, G + 15.2, f[1] - wn[1] * 0.4), rot=(0, wyaw, 0), mat="Neon",
                   color=RNG.choice([(80, 230, 255), (255, 90, 170)]), layer="LOD2", name="Bay Neon")
            tp = (f[0] + wn[0] * 4 + wdir[0] * 6, f[1] + wn[1] * 4 + wdir[1] * 6)
            for k in range(3):
                s.part("Cylinder", (1.6, 5, 5), (tp[0], G + 0.8 + 1.6 * k, tp[1]), rot=(0, 0, 90), mat="Plastic", color=(34, 34, 36), layer="LOD1", name="Tyre")
            cp = (f[0] + wn[0] * 2.5 - wdir[0] * 6, f[1] + wn[1] * 2.5 - wdir[1] * 6)
            s.part("Block", (3, 4, 5), (cp[0], G + 2, cp[1]), rot=(0, wyaw, 0), mat="Metal", color=(200, 40, 44), layer="LOD1", name="Tool Chest")
        else:
            s.part("Block", (0.6, 12, uw - 4), (f[0], G + 6, f[1]), rot=(0, wyaw, 0), mat="Metal", var="Metal Shutters",
                   color=RNG.choice([(150, 152, 156), (120, 140, 150), (160, 150, 130)]), layer="LOD2", name="Shutter")
        s.part("Block", (0.6, 4, uw), (f[0] + wn[0] * 0.2, G + hgt - 1.8, f[1] + wn[1] * 0.2), rot=(0, wyaw, 0), mat="Concrete",
               var=("SG Graffiti A" if i % 2 else "SG Graffiti B"), color=(205, 205, 205), layer="LOD2", name="Fascia Graffiti")
        b = (c[0] - wn[0] * (depth / 2 + 0.4), c[1] - wn[1] * (depth / 2 + 0.4))
        s.part("Block", (0.6, 12, uw), (b[0], G + 7, b[1]), rot=(0, wyaw, 0), mat="Concrete", var=("SG Graffiti B" if i % 2 else "SG Graffiti A"),
               color=(205, 205, 205), layer="LOD2", name="Graffiti Back Wall")
    print("  west lock-ups", len(placed))

    # ---- container stack at the north apex
    s.group("Containers")
    cn = n_lo + 26
    rs = u_range(cn + 6, 8)
    cu = (rs[0] + rs[1]) / 2 - 22
    cols = [(170, 60, 44), (40, 90, 150), (60, 130, 90), (210, 160, 40), (120, 120, 126)]
    k = 0
    for row in range(2):
        for lvl in range(3 - row):
            for j in range(2):
                if row == 1 and lvl == 1 and j == 1: continue
                box((12, 12, 40), cu + j * 44 + (8 if lvl == 1 else 0), cn + row * 13, G + 6 + lvl * 12, "Container", mat="CorrodedMetal" if k % 3 == 0 else "Metal",
                    color=cols[k % len(cols)], layer="LOD3")
                k += 1

    # ---- chain-link along the east (yaw -167) road side of the lot, lamps along the south kerb
    s.group("Lot Fence")
    eyaw = -167.0
    edir = (math.sin(math.radians(eyaw)), math.cos(math.radians(eyaw)))
    ein = (math.cos(math.radians(eyaw)), -math.sin(math.radians(eyaw)))
    base = (2595 + ein[0] * (37.5 + 4), 4465 + ein[1] * (37.5 + 4))
    for t in range(-680, 680, 20):
        x, z = base[0] + edir[0] * t, base[1] + edir[1] * t
        ends = [(x + edir[0] * 10, z + edir[1] * 10), (x - edir[0] * 10, z - edir[1] * 10)]
        if all(site.road_hit(a, b, 1, 199, 230) is None and 190 <= (site.ground(a, b) or 0) <= 210 and n_lo + 2 < NV[0] * a + NV[1] * b < n_hi - 2 for a, b in ends):
            s.kit("chainlink_fence_20", (x, G + 6, z), rot=(0, eyaw + 90, 0))
            if t % 80 == 0:
                lamp(s, x + ein[0] * 3, G, z + ein[1] * 3, (-ein[0], -ein[1]))
    r = u_range(n_hi - 3, 3)
    u = r[0] + 20
    while u < r[1] - 10:
        x, z = lot(u, n_hi - 3)
        lamp(s, x, G, z, NV)
        u += LAMP_STEP

    # ---- Y100 triangle east of P05: second lock-up row facing the Y100 diagonal road
    s.group("Lockups Y100")
    G1 = 100.0
    ryaw = -20.0; rd = (math.sin(math.radians(ryaw)), math.cos(math.radians(ryaw))); rn_ = (math.cos(math.radians(ryaw)), -math.sin(math.radians(ryaw)))
    # road 1891,4384 (yaw -20); its west edge line, then garages 22 deep set 14 back from it
    edge = (1891 - rn_[0] * 37.5, 4384 - rn_[1] * 37.5)
    for t in range(-240, 240, 20):
        cxz = (edge[0] + rd[0] * t - rn_[0] * (14 + 11), edge[1] + rd[1] * t - rn_[1] * (14 + 11))
        pts, ok = [], True
        for lx in (-11, 11):
            for lz in (-10, 10):
                p = (cxz[0] + rn_[0] * lx + rd[0] * lz, cxz[1] + rn_[1] * lx + rd[1] * lz)
                if site.on_road(p[0], p[1], 1) is not None or site.in_parcel(p[0], p[1]) or not (95 <= (site.ground(p[0], p[1]) or 0) <= 110):
                    ok = False
        if not ok: continue
        s.part("Block", (22, 15, 20), (cxz[0], G1 + 7.5, cxz[1]), rot=(0, ryaw, 0), mat="Concrete", var="SG Weathered Concrete", color=(146, 142, 136), name="Lockup Unit")
        f = (cxz[0] + rn_[0] * 11.2, cxz[1] + rn_[1] * 11.2)
        s.part("Block", (0.6, 11, 16), (f[0], G1 + 5.5, f[1]), rot=(0, ryaw, 0), mat="Metal", var="Metal Shutters", color=RNG.choice([(150, 152, 156), (170, 120, 110), (110, 140, 160)]),
               layer="LOD2", name="Shutter")
        s.part("Block", (0.6, 2, 18), (f[0], G1 + 13, f[1]), rot=(0, ryaw, 0), mat="Concrete", var=RNG.choice(["SG Graffiti A", "SG Graffiti B"]), color=(205, 205, 205),
               layer="LOD2", name="Fascia Graffiti")
    # apron + kerb along that road edge
    a0 = (edge[0] - rd[0] * 250, edge[1] - rd[1] * 250); a1 = (edge[0] + rd[0] * 250, edge[1] + rd[1] * 250)
    # sample apron pieces of 40 so they clip cleanly at the triangle ends
    for t in range(-240, 240, 40):
        c0 = (edge[0] + rd[0] * t, edge[1] + rd[1] * t); c1 = (edge[0] + rd[0] * (t + 40), edge[1] + rd[1] * (t + 40))
        seg(s, (c0[0] - rn_[0] * 7.5, c0[1] - rn_[1] * 7.5), (c1[0] - rn_[0] * 7.5, c1[1] - rn_[1] * 7.5), 12, 99, 102, mat="CeramicTiles", var="Paving Slab",
            color=PAVE_1, name="Apron")
        seg(s, (c0[0] - rn_[0] * 0.75, c0[1] - rn_[1] * 0.75), (c1[0] - rn_[0] * 0.75, c1[1] - rn_[1] * 0.75), KERB_W, 99, 102.15, mat="Concrete", color=KERB, name="Kerb")
        if t % 80 == 0:
            m = ((c0[0] + c1[0]) / 2 - rn_[0] * 3, (c0[1] + c1[1]) / 2 - rn_[1] * 3)
            lamp(s, m[0], 102, m[1], rn_)
    return s


def main():
    out = {}
    for fn in (build_streets, build_step, build_waterfront, build_westpark, build_eastlot):
        sp = fn()
        for e in sp.elements:   # street props (kit items) live on LOD2; surfaces/kerbs/foliage stay LOD3
            if e["t"] == "kit" and e["layer"] == "LOD3":
                e["layer"] = "LOD2"
        check(sp)
        path = HERE / f"{sp.sid}.json"
        out[sp.sid] = sp.save(str(path))
    tot = {k: sum(v[k] for v in out.values()) for k in ("tris", "parts", "kit")}
    nclone = 0
    import json
    for sid in out:
        nclone += sum(1 for e in json.load(open(HERE / f"{sid}.json"))["elements"] if e["t"] == "clone")
    print("TOTAL", tot, "clones", nclone)


if __name__ == "__main__":
    main()
