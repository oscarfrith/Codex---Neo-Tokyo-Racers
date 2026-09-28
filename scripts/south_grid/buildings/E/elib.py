"""Agent E helpers (P09, P10, X1): bounds-based boxes, face-relative placement, Blocks balcony grids.
All sizes on the 20/40-stud grid; a storey is 40/3 studs. Faces: N (-Z, street front of kit items), S (+Z), E (+X), W (-X).
"""
import pathlib, random, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "common"))
from sgspec import Spec, CATALOG  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
G = 200.0            # row-2 ground
ST = 40.0 / 3.0      # storey


def Y(k):
    """Top of floor k (k=0 is ground)."""
    return G + k * ST


# palette
CONC = (150, 148, 142)      # Blocks weathered concrete
CONC_D = (112, 110, 106)
CONC_L = (182, 180, 174)
WHITE = (218, 218, 212)     # Metabolist precast
WIN = (206, 204, 198)       # tint under window variants (keep light so the texture reads)
PATCH = (222, 206, 186)
SHUT = (104, 108, 114)
METAL = (78, 82, 88)
DARK = (46, 50, 58)
GLASS = (60, 92, 120)
NEON_PINK = (255, 70, 170)
NEON_CYAN = (60, 230, 255)
NEON_AMBER = (255, 170, 50)

FACE_ROT = {"N": 0, "S": 180, "E": -90, "W": 90}
FACE_SIGN = {"N": -1, "S": 1, "E": 1, "W": -1}


def box(s, x0, x1, y0, y1, z0, z1, mat="Concrete", var="SG Weathered Concrete", color=CONC, name="Block", layer=None, **kw):
    x0, x1 = min(x0, x1), max(x0, x1)
    y0, y1 = min(y0, y1), max(y0, y1)
    z0, z1 = min(z0, z1), max(z0, z1)
    return s.part("Block", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                  mat=mat, var=var, color=color, name=name, layer=layer, **kw)


def win_box(s, x0, x1, y0, y1, z0, z1, var="SG Windows Blocks", color=WIN, name="Windows"):
    return box(s, x0, x1, y0, y1, z0, z1, mat="SmoothPlastic", var=var, color=color, name=name)


def cyl(s, cx, cz, d, y0, y1, mat="Concrete", var="SG Capsule Panels", color=WHITE, name="Core", layer=None):
    """Vertical cylinder (Roblox cylinder axis is X, so roll 90)."""
    return s.part("Cylinder", (y1 - y0, d, d), (cx, (y0 + y1) / 2, cz), rot=(0, 0, 90), mat=mat, var=var, color=color,
                  name=name, layer=layer)


def fbox(s, face, plane, d0, d1, u0, u1, y0, y1, **kw):
    """Box on a facade: d0..d1 = distance out from the face plane, u = along the face (x for N/S, z for E/W)."""
    sg = FACE_SIGN[face]
    a, b = plane + sg * d0, plane + sg * d1
    if face in "NS":
        return box(s, u0, u1, y0, y1, a, b, **kw)
    return box(s, a, b, y0, y1, u0, u1, **kw)


def fkit(s, item, face, plane, d, u, y, **kw):
    """Kit item facing out of a facade; d = distance of its centre from the face plane."""
    sg = FACE_SIGN[face]
    p = plane + sg * d
    pos = (u, y, p) if face in "NS" else (p, y, u)
    return s.kit(item, pos, rot=(0, FACE_ROT[face], 0), **kw)


def kit_depth(item):
    return CATALOG[item]["size"][2]


def balcony_grid(s, face, plane, u0, u1, k0, k1, rng, depth=8, bay=40, row_vars=None, laundry=0.11, enclose=0.12,
                 ac=0.02, fins=True, skip=()):
    """The Blocks deep balcony grid: one slab+parapet Part per storey row, full-height fins every `bay`,
    random enclosed bays (patched panels), laundry lines and AC clusters from the kit.
    skip: list of (u0, u1, k0, k1) windows where no clutter is placed (landings, cores)."""
    row_vars = row_vars or ["SG Patched Panels", "SG Weathered Concrete", "SG Patched Panels", "SG Patched Panels"]
    n_bays = max(1, int(round((u1 - u0) / bay)))
    bw = (u1 - u0) / n_bays
    for k in range(k0, k1):
        v = row_vars[(k * 7 + int(u0)) % len(row_vars)]
        col = PATCH if v == "SG Patched Panels" else CONC
        mat = "SmoothPlastic" if v == "SG Patched Panels" else "Concrete"
        fbox(s, face, plane, 0, depth, u0, u1, Y(k) - 1.2, Y(k) + 4.8, mat=mat, var=v, color=col, name="BalconyRow")
    if fins:
        for i in range(n_bays + 1):
            u = u0 + i * bw
            fbox(s, face, plane, 0, depth + 0.6, u - 1.2, u + 1.2, Y(k0) - 1.2, Y(k1), color=CONC_D, name="BalconyFin")
    # roof lip of the grid
    fbox(s, face, plane, 0, depth + 0.6, u0 - 1.2, u1 + 1.2, Y(k1) - 1.2, Y(k1) + 2, color=CONC_D, name="BalconyTop")

    def skipped(uc, k):
        return any(a <= uc <= b and c <= k < d for a, b, c, d in skip)

    for k in range(k0, k1):
        for i in range(n_bays):
            uc = u0 + (i + 0.5) * bw
            if skipped(uc, k):
                continue
            r = rng.random()
            if r < enclose and k + 1 < k1:
                # boarded / glazed-in balcony: a patched box over one bay, one storey
                fbox(s, face, plane, 0.2, depth - 0.4, uc - bw / 2 + 1.2, uc + bw / 2 - 1.2, Y(k) + 4.8, Y(k + 1) - 1.2,
                     mat="SmoothPlastic", var="SG Patched Panels", color=rng.choice([(200, 225, 205), (235, 190, 175), (235, 222, 170), (190, 214, 232)]),
                     name="EnclosedBalcony")
            elif r < enclose + laundry and k + 1 < k1:
                fkit(s, "laundry_line_36", face, plane, depth + 0.6, uc, Y(k + 1) - 1.2 - 3.6, layer="LOD2",
                     color=rng.choice([(230, 120, 150), (120, 170, 230), (240, 230, 210), (240, 200, 90), (150, 210, 160)]))
            elif r < enclose + laundry + ac:
                fkit(s, "ac_cluster", face, plane, depth + 2, uc + rng.choice([-10, 10]), Y(k) + 1.3, layer="LOD2")


def roof_clutter(s, x0, x1, z0, z1, y, rng, tanks=1, shacks=1, dishes=1, masts=0, overrun=True):
    """Rooftop: lift overrun, tanks, shacks, dishes, masts placed on a coarse 20-stud grid inside the roof."""
    cells = [(x, z) for x in range(int(x0) + 20, int(x1) - 10, 20) for z in range(int(z0) + 20, int(z1) - 10, 20)]
    rng.shuffle(cells)
    used = []

    def take(sx, sz):
        for c in list(cells):
            if all(abs(c[0] - u[0]) > (sx + u[2]) / 2 + 2 or abs(c[1] - u[1]) > (sz + u[3]) / 2 + 2 for u in used):
                if x0 + sx / 2 < c[0] < x1 - sx / 2 and z0 + sz / 2 < c[1] < z1 - sz / 2:
                    cells.remove(c)
                    used.append((c[0], c[1], sx, sz))
                    return c
        return None

    if overrun:
        c = take(30, 30)
        if c:
            box(s, c[0] - 15, c[0] + 15, y, y + 20, c[1] - 15, c[1] + 15, color=CONC_D, name="LiftOverrun")
    for _ in range(tanks):
        c = take(16, 16)
        if c:
            s.kit("water_tank", (c[0], y + 11, c[1]))
    for _ in range(shacks):
        c = take(20, 20)
        if c:
            s.kit("rooftop_shack", (c[0], y + 6, c[1]), rot=(0, rng.choice([0, 90, 180, -90]), 0),
                  color=rng.choice([(120, 150, 160), (170, 120, 100), (140, 150, 110)]))
    for _ in range(dishes):
        c = take(14, 14)
        if c:
            s.kit("dish_cluster", (c[0], y + 6, c[1]), rot=(0, rng.choice([0, 180, -90]), 0), layer="LOD2")
    for _ in range(masts):
        c = take(8, 8)
        if c:
            s.kit("antenna_mast", (c[0], y + 30, c[1]))


def parapet(s, x0, x1, z0, z1, y, h=4, t=2, color=CONC_D):
    """Roof parapet as 4 chunky walls."""
    box(s, x0, x1, y, y + h, z0, z0 + t, color=color, name="Parapet")
    box(s, x0, x1, y, y + h, z1 - t, z1, color=color, name="Parapet")
    box(s, x0, x0 + t, y, y + h, z0 + t, z1 - t, color=color, name="Parapet")
    box(s, x1 - t, x1, y, y + h, z0 + t, z1 - t, color=color, name="Parapet")


def new_spec(sid, title, lean):
    return Spec(sid, kind="building", title=title, lean=lean), random.Random(sum(map(ord, sid)) * 131 + 7)
