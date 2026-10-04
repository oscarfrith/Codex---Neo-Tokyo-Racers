"""Modern Muscle cars on the Muscle frame (musclekit.py). Runs inside Blender:

    import muscle_cars; muscle_cars.build_all()

Hero car first (gate 1): F = muscle_06 Brawler, after the Dodge Challenger SRT Demon. STD trim only so far.
Design language of F: blunt upright nose with a full-width slot grille, halo lamp pairs on the front pods,
twin shaker turbine through the bonnet, flat slab sides, short notchback cabin, square tail with one
full-width light bar, giant round barrels on the rear pods, fat bazookas in the sills, ducktail lip.
"""
import os

import exokit as K
import musclekit as M
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
SLOTS = ("COCKPIT", "NOSE", "TAIL", "FPOD", "RPOD", "STAB", "BOOST", "WING")


# ---------------------------------------------------------------- shared hardware

def tube(z0, z1, x, y, r):
    """Round tube along the car."""
    return Loft([(z0, {}), (z1, {})], cx=x, w=r, yb=y - r, yt=y + r, nt=2, nb=2, yw=0.5)


def xtube(x0, x1, z, y, r):
    """Round tube across the car (points sideways)."""
    return Loft([(x0, {}), (x1, {})], axis="x", cx=z, w=r, yb=y - r, yt=y + r, nt=2, nb=2, yw=0.5)


def barrel(name, z0, z1, x, y, r, depth=0.6, collar=True):
    """Bare turbine barrel firing backwards: tube, a dark collar and a glowing throat."""
    t = tube(z0, z1, x, y, r)
    t.build(name, "metal", mirror=x != 0, caps=(True, False))
    t.throat(name + "n", "max", lip="metal", back="thrust", scale=0.84, depth=depth, mirror=x != 0)
    if collar:
        c = z0 + (z1 - z0) * 0.45
        tube(c, c + 0.22, x, y, r + 0.09).build(name + "c", "detail", mirror=x != 0)


def bazooka(name, x0, x1, z, y, r):
    """Sideways drift thruster: a fat tube with a glowing throat at its outer end."""
    t = xtube(x0, x1, z, y, r)
    t.build(name, "metal", mirror=True, caps=(True, False))
    t.throat(name + "n", "max", lip="metal", back="thrust", scale=0.82, depth=0.45, mirror=True)
    xtube(x1 - 0.5, x1 - 0.32, z, y, r + 0.07).build(name + "c", "detail", mirror=True)


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


def tub():
    """The body between the two seams. Every cockpit uses it unchanged."""
    Hull([(Z_F, SEAM_F), (Z_R, SEAM_R)]).build("tub", "primary", t0=Z_F + GAP, t1=Z_R - GAP, regions=[
        R(Z_F + GAP, Z_R - GAP, 0.0, 2.35, "secondary", 0.02)])
    Hull([(Z_F - 0.08, SEAM_F), (Z_R + 0.08, SEAM_R)]).build("liner", "detail", scale=0.96)


# ---------------------------------------------------------------- car F: Brawler (muscle_06)

def f_cockpit():
    """Short upright notchback cabin with a low glasshouse."""
    K.begin("F", "COCKPIT")
    tub()
    gh = Hull([(-5.8, dict(w=3.5, yb=2.9, yt=3.02, ys=2.95, tum=0.15, drop=0.02)),
               (-3.1, dict(w=3.6, yt=5.1, tum=0.8)),
               (-1.6, dict(yt=5.34)), (1.4, dict(yt=5.34)),
               (3.0, dict(w=3.6, yt=5.12, tum=0.85)),
               (4.7, dict(w=3.5, yb=2.95, yt=3.2, ys=3.05, tum=0.2, drop=0.03))],
              w=3.68, yb=2.9, ys=3.12, rb=0.04, tum=0.9, drop=0.1, wcf=0.78, d2=0.03, crown=0.025)
    gh.build("cabin", "primary", regions=[
        R(-5.5, -3.3, 4.12, 6.0, "glass", 0.03),           # windscreen
        R(-3.0, -0.35, 3.1, 3.88, "glass", 0.03, side=0),   # door glass
        R(0.05, 2.5, 3.1, 3.88, "glass", 0.03, side=0),     # quarter glass
        R(3.2, 4.45, 4.12, 6.0, "glass", 0.03),             # rear window
        R(-3.1, 2.8, 5.1, 6.0, "secondary", 0.02)])         # roof stripe


def f_nose():
    """Blunt upright nose, full-width slot grille, long flat bonnet with the twin shaker turbine."""
    K.begin("F", "NOSE")
    nose = Hull([(-12.4, dict(w=3.8, yb=0.1, yt=2.5, ys=2.05, rb=0.2, tum=0.12, drop=0.12)),
                 (-10.6, dict(w=3.9, yb=-0.3, yt=2.72, ys=2.2, rb=0.35)),
                 (Z_F, SEAM_F)], **{**SEAM_F})
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.4, Z_F - GAP, 0.0, 2.35, "secondary", 0.02),
        R(-12.4, Z_F - GAP, 5.0, 6.0, "secondary", 0.02),
        R(-9.6, -5.9, 5.45, 6.0, "detail", 0.1)])
    nose.cap("grilleback", "min", "detail")
    # brow and bumper stand ahead of the grille back, so the slot between them is a real recess
    Hull([(-13.0, dict(yb=2.05, yt=2.34, ys=2.2)), (-12.4, dict(yb=2.0, yt=2.5, ys=2.25))], w=3.8, rb=0.04, tum=0.1,
         drop=0.08, wcf=0.7, d2=0.02, crown=0.02).build("brow", "primary", regions=[
             R(-13.0, -12.4, 5.0, 6.0, "secondary", 0.0)])
    Hull([(-13.15, dict(yb=0.4, yt=1.35, ys=1.1)), (-12.4, dict(yb=0.1, yt=1.5, ys=1.2))], w=3.8, rb=0.15, tum=0.1,
         drop=0.08, wcf=0.7, d2=0.0, crown=0.0).build("bumper", "primary")
    for i, y in enumerate((1.62, 1.84)):
        box(f"bar{i}", (0, y, -12.62), (7.5, 0.06, 0.12), "metal")
    box("intake", (0, 0.86, -13.17), (4.6, 0.46, 0.08), "detail")
    Loft([(-13.5, dict(w=3.2)), (-12.7, dict(w=3.85)), (-11.2, dict(w=3.9))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "secondary")
    # twin shaker turbine through the bonnet
    box("shakerbase", (0, 3.06, -7.75), (2.9, 0.34, 3.3), "detail")
    for name, x in (("shaker", 0.74),):
        t = Loft([(-10.2, dict(w=0.76, yb=3.02, yt=4.54)), (-9.5, dict(w=0.64, yb=3.14, yt=4.42)), (-6.3, {})], cx=x, w=0.64,
                 yb=3.14, yt=4.42, nt=2, nb=2, yw=0.5)
        t.build(name, "metal", mirror=True, caps=(False, True))
        t.throat(name + "in", "min", lip="metal", wall="detail", back="detail", scale=0.86, depth=0.7, mirror=True)
        tube(-10.0, -9.5, x, 3.78, 0.2).build(name + "hub", "metal", mirror=True)
        for i, z in enumerate((-9.1, -7.9)):
            tube(z, z + 0.2, x, 3.78, 0.71).build(f"{name}band{i}", "detail", mirror=True)
    box("shakertie", (0, 3.78, -8.3), (0.5, 0.5, 2.2), "detail")


def f_pod(pod, z0, z1, shield, vent):
    """Square bolted-on engine box: black lower band, sunk heat shield with bolts, slatted top vent."""
    regs = [R(z0 + 0.15, z1 - 0.15, 1.0, 2.3, "secondary", 0.02),
            R(shield[0], shield[1], 2.3, 2.9, "detail", 0.1, side=1),
            R(vent[0], vent[1], 4.5, 6.0, "detail", 0.12)]
    return regs


def f_fpod():
    K.begin("F", "FPOD")
    pod = Hull([(-12.6, dict(w=1.2, yb=-0.6, yt=1.75, ys=1.4)), (-11.3, dict(yb=-1.2)), (POD_FZ, SIDE_F)], **SIDE_F)
    pod.build("skin", "primary", mirror=True, caps=(True, False),
              regions=f_pod(pod, -12.5, POD_FZ, (-10.8, -7.3), (-10.6, -7.6)))
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.62, depth=0.5, mirror=True)
    for i, x in enumerate((4.88, 5.92)):
        halo(f"halo{i}", x, 0.95, -12.95, 0.42)
    box("mouth", (5.4, -0.05, -12.62), (1.9, 0.5, 0.1), "detail", mirror=True)
    for i, y in enumerate((-0.15, 0.05)):
        box(f"mouthbar{i}", (5.4, y, -12.66), (1.9, 0.05, 0.1), "metal", mirror=True)
    for i in range(5):
        box(f"slat{i}", (5.4, 2.14, -10.2 + i * 0.58), (1.9, 0.06, 0.2), "secondary", mirror=True)
    bolts("bolt", 6.66, (0.2, 1.35), (-10.55, -7.55))
    xt = xtube(6.3, 6.9, -6.75, -0.35, 0.5)
    xt.build("sidepipe", "metal", mirror=True, caps=(True, False))
    xt.throat("sidepipen", "max", lip="metal", wall="detail", back="detail", scale=0.8, depth=0.4, mirror=True)
    flange(-11.4, -6.4, -0.3, 1.9)
    lift_glow(pod, [(-10.6, -7.4)])


def f_rpod():
    K.begin("F", "RPOD")
    big = dict(w=1.4, yb=-1.5, yt=3.3, ys=2.75)
    pod = Hull([(POD_RZ, SIDE_R), (5.1, big), (10.3, big), (11.1, dict(w=1.35, yb=-1.2, yt=3.0, ys=2.5))], **SIDE_R)
    pod.build("skin", "primary", mirror=True, caps=(False, True),
              regions=f_pod(pod, POD_RZ, 11.1, (5.7, 9.7), (5.6, 9.4)))
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    for i in range(6):
        box(f"slat{i}", (5.45, 3.2, 5.95 + i * 0.6), (1.8, 0.06, 0.2), "secondary", mirror=True)
    bolts("bolt", 6.81, (0.1, 1.85), (5.95, 9.45))
    barrel("barrel", 10.3, 12.4, 5.45, 0.85, 1.18, depth=0.8)
    flange(4.4, 10.6, -0.3, 2.3)
    lift_glow(pod, [(5.6, 9.6)])


def f_stab():
    """Sill unit with two fat bazookas firing sideways."""
    K.begin("F", "STAB")
    sill = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.95, w=0.85, yb=-1.2, yt=1.0, ys=0.72, rb=0.2, tum=0.1,
                drop=0.08, wcf=0.6, d2=0.0, crown=0.0)
    sill.build("skin", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 1.0, 2.25, "secondary", 0.02),
        R(-4.3, 2.3, 2.35, 2.92, "detail", 0.08, side=1)])
    for i, z in enumerate((-2.7, 0.7)):
        bazooka(f"bazooka{i}", 5.3, 6.75, z, -0.12, 0.56)
    bolts("bolt", 5.78, (0.45,), (-4.1, -1.0, 2.1), size=0.12)
    lift_glow(sill, [(-5.0, -3.6), (1.6, 3.0)])


def f_tail():
    """Square-cut tail with one full-width light bar. The lower rear centre is open for the overdrive."""
    K.begin("F", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (9.6, dict(yt=3.15)), (10.5, dict(yb=-0.3)), (11.2, dict(yb=1.25, rb=0.2)),
                 (12.2, dict(w=3.8, yb=1.3, yt=3.2, ys=2.6, rb=0.2, tum=0.15, drop=0.12))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.2, 0.0, 2.35, "secondary", 0.02),
        R(Z_R + GAP, 12.2, 5.0, 6.0, "secondary", 0.02)])
    tail.throat("fascia", "max", lip="primary", wall="detail", back="detail", scale=0.9, depth=0.25)
    box("lightbar", (0, 2.4, 12.02), (6.5, 0.3, 0.14), "lights_red")
    box("lightbarframe", (0, 2.4, 11.99), (6.8, 0.5, 0.1), "secondary")


def f_boost():
    """Two huge barrels close together under the bumper."""
    K.begin("F", "BOOST")
    Hull([(10.8, {}), (12.05, {})], w=2.6, yb=-0.45, yt=1.2, rb=0.25, ys=0.9, tum=0.15, drop=0.0, wcf=0.5, d2=0.0,
         crown=0.0).build("housing", "secondary")
    box("trim", (0, 1.24, 11.6), (5.0, 0.08, 0.8), "primary")
    barrel("barrel", 11.5, 13.15, 0.86, 0.36, 0.74, depth=0.55)


def f_wing():
    """One-piece ducktail lip."""
    K.begin("F", "WING")
    Hull([(11.0, dict(yt=3.24, ys=3.1)), (12.4, dict(w=3.7, yt=3.85, ys=3.45))], w=3.78, yb=3.04, rb=0.02, tum=0.06,
         drop=0.03, wcf=0.7, d2=0.01, crown=0.02).build("lip", "primary")
    box("gurney", (0, 3.87, 12.36), (7.3, 0.09, 0.09), "secondary")


def car_f():
    f_cockpit()
    f_nose()
    f_tail()
    f_fpod()
    f_rpod()
    f_stab()
    f_boost()
    f_wing()


# ---------------------------------------------------------------- staging and shots

VIEWS = (("front", 146, 11, 50), ("rear", 34, 12, 50), ("side", 90, 4, 46), ("top", 180, 80, 56),
         ("frontlow", 162, 5, 44), ("rearhigh", 20, 28, 52))


def build_all(render=True):
    K.reset()
    K.stage()
    car_f()
    K.finish_library()
    K.place("brawler", [f"F_{s}_STD" for s in SLOTS], 0, 0)
    problems = K.check()
    paths = []
    if render:
        os.makedirs(OUT, exist_ok=True)
        for name, az, el, dist in VIEWS:
            paths.append(K.shot(os.path.join(OUT, f"brawler_{name}.jpg"), (0, 1.6, 0), az, el, dist, res=(1600, 900)))
    tris = {k: v["tris"] for k, v in K.MODS.items()}
    return {"problems": problems, "tris": tris, "total": sum(tris.values()), "shots": paths}
