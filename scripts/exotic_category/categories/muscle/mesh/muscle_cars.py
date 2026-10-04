"""Modern Muscle: shared hardware helpers and the per-car build helper (runs inside Blender).

Each car lives in its own file, car_a.py to car_f.py (muscle_01 to muscle_06), and imports these helpers.
lineup.py builds all six together and renders the swap sheets. The hero car and reference is car_f.py.
"""
import os

import exokit as K
import musclekit as M
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
# One crisp character line runs the length of the body side: a fine groove at the same height on the nose,
# the tub and the tail (ring range on the body side), and one on each pod flank.
LINE = (2.78, 2.9)
POD_LINE = (2.66, 2.86)
SLOTS = ("COCKPIT", "NOSE", "TAIL", "FPOD", "RPOD", "STAB", "BOOST", "WING")
# Every module slot except the cockpit has three versions on the same mounting: STD, GT and EVO.
TRIMS = ("STD", "GT", "EVO")
LVL = {"STD": 0, "GT": 1, "EVO": 2}


def pick(trim, std, gt=None, evo=None):
    """The value for a trim. GT defaults to STD, EVO defaults to GT."""
    gt = std if gt is None else gt
    return {"STD": std, "GT": gt, "EVO": gt if evo is None else evo}[trim]


def keys(letter, trim="STD", **swap):
    """Module keys of one build: every slot in one trim, the cockpit always STD. swap overrides single
    slots with (letter, trim), for example keys("F", "GT", WING=("C", "EVO"))."""
    out = []
    for slot in SLOTS:
        l, tr = swap.get(slot, (letter, trim))
        out.append(f"{l}_{slot}_{'STD' if slot == 'COCKPIT' else tr}")
    return out


# ---------------------------------------------------------------- shared hardware

def tube(z0, z1, x, y, r):
    """Round tube along the car."""
    return Loft([(z0, {}), (z1, {})], cx=x, w=r, yb=y - r, yt=y + r, nt=2, nb=2, yw=0.5)


def xtube(x0, x1, z, y, r):
    """Round tube across the car (points sideways)."""
    return Loft([(x0, {}), (x1, {})], axis="x", cx=z, w=r, yb=y - r, yt=y + r, nt=2, nb=2, yw=0.5)


def barrel(name, z0, z1, x, y, r, depth=0.6, collar=True, ry=None, n=2):
    """Jet nozzle firing backwards: a metal tube with a glowing throat. r is the half width; ry the half
    height (defaults to r) and n the corner sharpness (2 is round, 4 to 5 a rounded rectangle), so a nozzle
    can take the squared shape of the car instead of a plain pipe."""
    ry = r if ry is None else ry
    t = Loft([(z0, {}), (z1, {})], cx=x, w=r, yb=y - ry, yt=y + ry, nt=n, nb=n, yw=0.5)
    t.build(name, "metal", mirror=x != 0, caps=(True, False))
    t.throat(name + "n", "max", lip="metal", back="thrust", scale=0.84, depth=depth, mirror=x != 0)
    if collar:
        c = z0 + (z1 - z0) * 0.45
        Loft([(c, {}), (c + 0.22, {})], cx=x, w=r + 0.09, yb=y - ry - 0.09, yt=y + ry + 0.09, nt=n, nb=n,
             yw=0.5).build(name + "c", "detail", mirror=x != 0)


def bazooka(name, x0, x1, z, y, r, back=0.8, down=0.6, wide=1.3, flat=0.7, n=4.5):
    """Drift thruster: a nozzle that leaves the sill sideways and sweeps back and down. Its mouth is a
    rounded rectangle, longer along the car than it is tall, to match the squared rear nozzles. The glow is
    a plate set a little way inside the open end, so the mouth reads as a clean frame."""
    def at(x, k):
        s = (x - x0) / (x1 - x0)
        yc = y - down * s
        return (x, dict(cx=z + back * s, w=r * wide * k, yb=yc - r * flat * k, yt=yc + r * flat * k))
    kw = dict(axis="x", nt=n, nb=n, yw=0.5)
    Loft([at(x0, 1.0), at(x1, 1.0)], **kw).build(name, "metal", mirror=True, caps=(True, False))
    Loft([at(x1 - 0.34, 0.88), at(x1 - 0.3, 0.88)], **kw).build(name + "glow", "thrust", mirror=True)
    Loft([at(x1 - 0.3, 0.88), at(x1, 0.88)], **kw).build(name + "bore", "detail", mirror=True, caps=(False, False))


def halo(name, x, y, z, r):
    """Round lamp: a dark can with a ring of light round its mouth. Faces forward."""
    t = tube(z, z + 0.4, x, y, r)
    t.build(name, "detail", mirror=True, caps=(False, True))
    t.throat(name + "h", "min", lip="lights", wall="detail", back="detail", scale=0.7, depth=0.14, mirror=True)


def bolts(name, x, ys, zs, size=0.14):
    for i, y in enumerate(ys):
        for j, z in enumerate(zs):
            box(f"{name}{i}{j}", (x, y, z), (0.08, size, size), "metal", mirror=True)


def lift_glow(hull, spans):
    for i, (t0, t1) in enumerate(spans):
        for side in (1, -1):
            hull.patch(f"lift{i}{side}", t0, t1, 0.2, 0.85, "thrust", side=side, mirror=True)


def flange(z0, z1, y0, y1):
    """Dark mounting block between a pod and the body side. It fills the gap, set back from both skins."""
    box("flange", ((M.BODY_W + M.POD_IN) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (M.POD_IN - M.BODY_W, y1 - y0, z1 - z0),
        "detail", mirror=True)


def tub(doors=()):
    """The body between the two seams. Every cockpit uses the same section. doors: optional shut lines."""
    regs = [R(Z_F + GAP, Z_R - GAP, 0.0, 2.0, "secondary", 0.02),
            R(Z_F + GAP, Z_R - GAP, LINE[0], LINE[1], "primary", 0.025)]
    regs += [R(z, z + 0.14, 2.05, 3.95, "detail", 0.03) for z in doors]
    Hull([(Z_F, SEAM_F), (Z_R, SEAM_R)]).build("tub", "primary", t0=Z_F + GAP, t1=Z_R - GAP, regions=regs)
    Hull([(Z_F - 0.08, SEAM_F), (Z_R + 0.08, SEAM_R)]).build("liner", "detail", scale=0.96)


# ---------------------------------------------------------------- staging and shots

VIEWS = (("front", 146, 11, 50), ("rear", 34, 12, 50), ("side", 90, 4, 46), ("top", 180, 80, 56),
         ("frontlow", 162, 5, 44), ("rearhigh", 20, 28, 52))
CLOSE = (("c_nose", (0, 1.6, -11.5), 168, 8, 17), ("c_fpod", (5.4, 0.6, -10.0), 128, 10, 16),
         ("c_sill", (5.2, 0.2, -1.0), 95, 12, 17), ("c_rpod", (5.4, 0.8, 8.5), 55, 12, 17),
         ("c_tail", (0, 2.0, 12.0), 8, 8, 17), ("c_cabin", (0, 4.2, 0), 120, 18, 20),
         ("c_cabinfront", (0, 4.2, -2), 205, 14, 20), ("c_cabinrear", (0, 4.2, 2), 40, 16, 20))


TRIM_VIEWS = (("front", 146, 11, 50), ("rear", 34, 12, 50), ("side", 90, 4, 46), ("rearhigh", 20, 28, 52))
TRIM_CLOSE = (("c_nose", (0, 2.2, -10.5), 160, 14, 19), ("c_fpod", (5.4, 0.6, -10.0), 128, 10, 16),
              ("c_rpod", (5.4, 0.8, 8.5), 55, 12, 17), ("c_tail", (0, 2.4, 12.0), 12, 12, 19))
ROW_DX = 19.0


def build_car(name, letter, fn, render=True, close=True, out=None):
    """Build one car alone in every trim it has, check it against the envelopes and render it.

    Per trim: previews/<name>_<trim>_<view>.jpg (front, rear, side, rearhigh) and, for GT and EVO, four
    close-ups previews/<name>_<trim>_c_<part>.jpg. STD also gets the full set of views and close-ups under
    the old names previews/<name>_<view>.jpg. previews/<name>_kits_front.jpg and _kits_rear.jpg show
    STD, GT and EVO side by side (STD on the left seen from the front)."""
    out = out or OUT
    K.reset()
    K.stage()
    fn()
    K.finish_library()
    trims = [tr for tr in TRIMS if f"{letter}_NOSE_{tr}" in K.MODS]
    for tr in trims:
        K.place(f"{name}{tr.lower()}", keys(letter, tr), 0, 0)
    for i, tr in enumerate(trims):
        K.place(f"{name}row{tr.lower()}", keys(letter, tr), (i - (len(trims) - 1) / 2) * -ROW_DX, 0)
    problems = K.check()
    paths = []
    if render:
        os.makedirs(out, exist_ok=True)

        def shot(fname, target, az, el, dist, only, res=(1600, 900), lens=50):
            paths.append(K.shot(os.path.join(out, fname), target, az, el, dist, lens=lens, res=res, only=only))

        std = [f"{name}std"]
        for view, az, el, dist in VIEWS:
            shot(f"{name}_{view}.jpg", (0, 1.6, 0), az, el, dist, std)
        if close:
            for view, target, az, el, dist in CLOSE:
                shot(f"{name}_{view}.jpg", target, az, el, dist, std, res=(1400, 800))
        for tr in trims[1:]:
            one = [f"{name}{tr.lower()}"]
            for view, az, el, dist in TRIM_VIEWS:
                shot(f"{name}_{tr.lower()}_{view}.jpg", (0, 1.8, 0), az, el, dist + 4, one)
            if close:
                for view, target, az, el, dist in TRIM_CLOSE:
                    shot(f"{name}_{tr.lower()}_{view}.jpg", target, az, el, dist, one, res=(1400, 800))
        if len(trims) > 1:
            row = [f"{name}row{tr.lower()}" for tr in trims]
            shot(f"{name}_kits_front.jpg", (0, 1.6, 0), 160, 14, 92, row, res=(2400, 1000), lens=60)
            shot(f"{name}_kits_rear.jpg", (0, 1.6, 0), 20, 14, 92, row, res=(2400, 1000), lens=60)
    tris = {k: v["tris"] for k, v in K.MODS.items()}
    by_trim = {tr: sum(v for k, v in tris.items() if k.endswith("_" + tr) or (k.endswith("COCKPIT_STD")))
               for tr in trims}
    return {"problems": problems, "trims": trims, "tris_per_build": by_trim, "shots": paths}
