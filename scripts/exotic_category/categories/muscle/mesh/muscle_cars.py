"""Modern Muscle cars on the Muscle frame (musclekit.py). Runs inside Blender:

    import muscle_cars; muscle_cars.build_all()

Hero car first (gate 1): F = muscle_06 Brawler, after the Dodge Challenger SRT Demon. STD trim only so far.
Design language of F: blunt nose that tapers in plan, deep full-width slot grille, halo lamp pairs on the
front pods, twin shaker turbine through a raised bonnet bulge, long bonnet, low glasshouse with a fast rear
window and a short deck, hips that rise over the rear pods, square tail with one full-width light bar,
giant round barrels on the rear pods, fat bazookas in the sills, ducktail lip.
Pass 2 (2026-10-04): less boxy. The body has tumblehome and crown, the pods are fenders with rounded
shoulders instead of plain boxes, and the cabin is longer and lower at the back.
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


def tub(doors=(-2.1, 1.3)):
    """The body between the two seams, with door shut lines. Every cockpit uses the same section."""
    regs = [R(Z_F + GAP, Z_R - GAP, 0.0, 2.0, "secondary", 0.02)]
    regs += [R(z, z + 0.14, 2.05, 3.95, "detail", 0.03) for z in doors]
    Hull([(Z_F, SEAM_F), (Z_R, SEAM_R)]).build("tub", "primary", t0=Z_F + GAP, t1=Z_R - GAP, regions=regs)
    Hull([(Z_F - 0.08, SEAM_F), (Z_R + 0.08, SEAM_R)]).build("liner", "detail", scale=0.96)
    box("handle", (M.BODY_W - 0.02, 2.62, doors[1] - 0.6), (0.08, 0.1, 0.6), "metal", mirror=True)


# ---------------------------------------------------------------- car F: Brawler (muscle_06)

def f_cockpit():
    """Low glasshouse: raked windscreen, long doors, a fast rear window down to a short deck."""
    K.begin("F", "COCKPIT")
    tub()
    gh = Hull([(-5.9, dict(w=3.42, yb=3.1, yt=3.2, ys=3.14, tum=0.15, drop=0.02)),
               (-3.7, dict(w=3.5, yt=5.2, tum=0.9)),
               (-2.6, dict(yt=5.48)), (1.8, dict(yt=5.48)),
               (2.9, dict(w=3.5, yt=5.3, tum=0.95)),
               (5.9, dict(w=3.3, yb=3.15, yt=3.3, ys=3.2, tum=0.25, drop=0.03))],
              w=3.55, yb=3.1, ys=3.3, rb=0.04, tum=0.95, drop=0.12, wcf=0.78, d2=0.03, crown=0.04)
    gh.build("cabin", "primary", regions=[
        R(-5.65, -3.85, 4.12, 6.0, "glass", 0.03),    # windscreen
        R(-4.7, -0.35, 3.08, 3.9, "glass", 0.03),     # door glass, follows the screen pillar
        R(0.0, 4.4, 3.08, 3.9, "glass", 0.03),        # quarter glass, follows the roof down
        R(3.15, 5.6, 4.15, 6.0, "glass", 0.03),       # rear window
        R(-3.6, 2.9, 5.1, 6.0, "secondary", 0.02)])   # roof stripe


def f_nose():
    """Nose that tapers in plan, deep slot grille, long bonnet with a raised bulge and the twin shaker turbine."""
    K.begin("F", "NOSE")
    nose = Hull([(-12.5, dict(w=3.55, yb=0.2, yt=2.55, ys=2.0, rb=0.25, tum=0.25, drop=0.18)),
                 (-11.6, dict(w=3.8, yb=-0.1, yt=2.75, ys=2.15, rb=0.35)),
                 (-9.5, dict(w=3.9, yt=2.95, ys=2.3)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.5, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-12.3, Z_F - GAP, 5.15, 6.0, "secondary", -0.07),   # raised bonnet bulge, in the stripe colour
        R(-9.6, -5.9, 5.5, 6.0, "detail", 0.1)])
    nose.cap("grilleback", "min", "detail")
    # brow and bumper stand ahead of the grille back, so the slot between them is a real recess
    Hull([(-13.05, dict(w=3.42, yb=2.1, yt=2.38, ys=2.22)), (-12.5, dict(w=3.55, yb=2.05, yt=2.55, ys=2.28))], rb=0.04,
         tum=0.2, drop=0.1, wcf=0.7, d2=0.02, crown=0.03).build("brow", "primary")
    Hull([(-13.2, dict(w=3.38, yb=0.5, yt=1.4, ys=1.15)), (-12.5, dict(w=3.55, yb=0.2, yt=1.55, ys=1.25))], rb=0.3,
         tum=0.15, drop=0.1, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    for i, y in enumerate((1.7, 1.92)):
        box(f"bar{i}", (0, y, -12.72), (7.0, 0.06, 0.12), "metal")
    box("intake", (0, 0.94, -13.22), (4.2, 0.4, 0.08), "detail")
    Loft([(-13.55, dict(w=3.0)), (-12.8, dict(w=3.6)), (-11.2, dict(w=3.85))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "secondary")
    # twin shaker turbine through the bonnet
    y = 3.95
    box("shakerbase", (0, y - 0.72, -7.75), (2.9, 0.34, 3.3), "detail")
    t = Loft([(-10.2, dict(w=0.76, yb=y - 0.76, yt=y + 0.76)), (-9.5, {}), (-6.3, {})], cx=0.74, w=0.64, yb=y - 0.64,
             yt=y + 0.64, nt=2, nb=2, yw=0.5)
    t.build("shaker", "metal", mirror=True, caps=(False, True))
    t.throat("shakerin", "min", lip="metal", wall="detail", back="detail", scale=0.86, depth=0.7, mirror=True)
    tube(-10.0, -9.5, 0.74, y, 0.2).build("shakerhub", "metal", mirror=True)
    for i, z in enumerate((-9.1, -7.9)):
        tube(z, z + 0.2, 0.74, y, 0.71).build(f"shakerband{i}", "detail", mirror=True)
    box("shakertie", (0, y, -8.3), (0.5, 0.5, 2.2), "detail")


def f_pod_regions(z0, z1, shield, vent):
    """Engine fender: black rocker, a sunk heat shield on the flank and a slatted vent on top."""
    return [R(z0 + 0.15, z1 - 0.15, 1.0, 2.0, "secondary", 0.02),
            R(shield[0], shield[1], 2.25, 2.9, "detail", 0.1, side=1),
            R(vent[0], vent[1], 4.6, 6.0, "detail", 0.12)]


def f_fpod():
    """Front engine fender: a flat lamp face with a halo pair, rounded shoulders, rising to the pod face."""
    K.begin("F", "FPOD")
    pod = Hull([(-12.7, dict(cx=5.38, w=1.2, yb=-0.75, yt=1.85, ys=1.25, rb=0.3, tum=0.25, drop=0.18)),
                (-12.2, dict(cx=5.4, w=1.28, yb=-1.05, yt=2.1, ys=1.45)),
                (-10.5, dict(w=1.32, yt=2.35)), (-8.0, dict(w=1.32, yt=2.42)),
                (POD_FZ, SIDE_F)], **SIDE_F)
    pod.build("skin", "primary", mirror=True, caps=(True, False),
              regions=f_pod_regions(-12.75, POD_FZ, (-10.4, -7.3), (-10.2, -7.6)))
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.62, depth=0.5, mirror=True)
    for i, x in enumerate((4.9, 5.86)):
        halo(f"halo{i}", x, 0.95, -13.0, 0.42)
    box("mouth", (5.38, -0.2, -12.74), (1.7, 0.4, 0.1), "detail", mirror=True)
    box("mouthbar", (5.38, -0.2, -12.78), (1.7, 0.05, 0.1), "metal", mirror=True)
    for i in range(4):
        box(f"slat{i}", (5.4, 2.36, -9.85 + i * 0.6), (1.3, 0.06, 0.2), "secondary", mirror=True)
    bolts("bolt", 6.66, (0.15, 1.3), (-10.15, -7.55))
    xt = xtube(6.3, 6.9, -6.75, -0.35, 0.48)
    xt.build("sidepipe", "metal", mirror=True, caps=(True, False))
    xt.throat("sidepipen", "max", lip="metal", wall="detail", back="detail", scale=0.8, depth=0.4, mirror=True)
    flange(-11.2, -6.4, -0.3, 1.9)
    lift_glow(pod, [(-10.4, -7.4)])


def f_rpod():
    """Rear engine fender: a tall rounded haunch with a giant barrel at the tail."""
    K.begin("F", "RPOD")
    big = dict(w=1.4, yb=-1.5, yt=3.45, ys=2.5)
    pod = Hull([(POD_RZ, SIDE_R), (5.4, big), (9.6, big), (11.2, dict(cx=5.4, w=1.3, yb=-1.1, yt=3.0, ys=2.3))],
               **SIDE_R)
    pod.build("skin", "primary", mirror=True, caps=(False, True),
              regions=f_pod_regions(POD_RZ, 11.2, (5.8, 9.6), (5.9, 9.2)))
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    for i in range(5):
        box(f"slat{i}", (5.45, 3.4, 6.3 + i * 0.6), (1.3, 0.06, 0.2), "secondary", mirror=True)
    bolts("bolt", 6.75, (0.0, 1.75), (6.05, 9.35))
    barrel("barrel", 10.3, 12.5, 5.45, 0.9, 1.15, depth=0.8)
    flange(4.4, 10.6, -0.3, 2.3)
    lift_glow(pod, [(5.8, 9.6)])


def f_stab():
    """Sill unit with two fat bazookas firing sideways."""
    K.begin("F", "STAB")
    sill = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.95, w=0.85, yb=-1.2, yt=1.0, ys=0.6, rb=0.3, tum=0.2,
                drop=0.12, wcf=0.6, d2=0.0, crown=0.04)
    sill.build("skin", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 1.0, 2.0, "secondary", 0.02),
        R(-4.3, 2.3, 2.2, 2.9, "detail", 0.08, side=1)])
    for i, z in enumerate((-2.7, 0.7)):
        bazooka(f"bazooka{i}", 5.3, 6.75, z, -0.2, 0.54)
    bolts("bolt", 5.76, (0.38,), (-4.1, -1.0, 2.1), size=0.12)
    lift_glow(sill, [(-5.0, -3.6), (1.6, 3.0)])


def f_tail():
    """Short deck, hips level with the rear pods, square tail with one full-width light bar."""
    K.begin("F", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.3)), (9.8, dict(yt=3.3)), (10.6, dict(yb=-0.3)),
                 (11.3, dict(yb=1.3, rb=0.25)),
                 (12.3, dict(w=3.7, yb=1.35, yt=3.3, ys=2.6, rb=0.25, tum=0.3, drop=0.2))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.3, 0.0, 2.0, "secondary", 0.02),
        R(6.2, 12.3, 5.15, 6.0, "secondary", 0.02)])
    tail.throat("fascia", "max", lip="primary", wall="detail", back="detail", scale=0.9, depth=0.25)
    box("lightbar", (0, 2.45, 12.12), (6.2, 0.3, 0.14), "lights_red")
    box("lightbarframe", (0, 2.45, 12.09), (6.5, 0.5, 0.1), "secondary")


def f_boost():
    """Two huge barrels close together under the bumper."""
    K.begin("F", "BOOST")
    Hull([(10.8, {}), (12.1, {})], w=2.6, yb=-0.45, yt=1.25, rb=0.3, ys=0.9, tum=0.2, drop=0.0, wcf=0.5, d2=0.0,
         crown=0.0).build("housing", "secondary")
    box("trim", (0, 1.29, 11.6), (4.8, 0.08, 0.8), "primary")
    barrel("barrel", 11.5, 13.2, 0.86, 0.38, 0.74, depth=0.55)


def f_wing():
    """One-piece ducktail lip."""
    K.begin("F", "WING")
    Hull([(11.0, dict(yt=3.42, ys=3.3)), (12.5, dict(w=3.6, yt=4.05, ys=3.6))], w=3.7, yb=3.22, rb=0.02, tum=0.1,
         drop=0.04, wcf=0.7, d2=0.01, crown=0.03).build("lip", "primary")
    box("gurney", (0, 4.07, 12.46), (7.1, 0.09, 0.09), "secondary")


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
