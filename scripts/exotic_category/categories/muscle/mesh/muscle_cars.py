"""Modern Muscle cars on the Muscle frame (musclekit.py). Runs inside Blender:

    import muscle_cars; muscle_cars.build_all()

Hero car first (gate 1): F = muscle_06 Brawler, after the Dodge Challenger SRT Demon. STD trim only so far.
Design language of F: blunt nose that tapers in plan, deep full-width slot grille, halo lamp pairs on the
front pods, twin shaker turbine through a raised bonnet bulge, long bonnet, low glasshouse with a fast rear
window and a short deck, hips that rise over the rear pods, square tail with one full-width light bar,
giant round barrels on the rear pods, fat bazookas in the sills, ducktail lip.
Pass 4 (2026-10-04, Oscar): clean and minimal. The standard trim carries shape, lamps, glass, stripe and
jets only. Vents, louvres, bolts, scoops and pipes are kept for the GT and EVO upgrade modules.
Pass 2 (2026-10-04): less boxy. The body has tumblehome and crown, the pods are fenders with rounded
shoulders instead of plain boxes, and the cabin is longer and lower at the back.
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
POD_LINE = (2.72, 2.86)
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


def bazooka(name, x0, x1, z, y, r, back=0.8, down=0.6):
    """Drift thruster: a fat tube that leaves the sill sideways and sweeps back and down, glowing at its
    outer end. back and down are how far the outer end sits behind and below the inner end."""
    t = Loft([(x0, dict(cx=z, yb=y - r, yt=y + r)), (x1, dict(cx=z + back, yb=y - down - r, yt=y - down + r))],
             axis="x", w=r, nt=2, nb=2, yw=0.5)
    t.build(name, "metal", mirror=True, caps=(True, False))
    t.throat(name + "n", "max", lip="metal", back="thrust", scale=0.82, depth=0.45, mirror=True)


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


# ---------------------------------------------------------------- car F: Brawler (muscle_06)

def f_cockpit():
    """Wide, long glasshouse nearly the full width of the body: raked windscreen, long roof, a fast rear
    window down to a short deck."""
    K.begin("F", "COCKPIT")
    tub()
    gh = Hull([(-6.0, dict(w=3.55, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02)),
               (-3.5, dict(w=3.66, yt=5.4, tum=0.62)),
               (-2.4, dict(yt=5.7)), (1.9, dict(yt=5.7)),
               (3.0, dict(w=3.66, yt=5.5, tum=0.68)),
               (6.3, dict(w=3.5, yb=3.15, yt=3.3, ys=3.2, tum=0.2, drop=0.03))],
              w=3.68, yb=3.1, ys=3.3, rb=0.04, tum=0.65, drop=0.12, wcf=0.8, d2=0.03, crown=0.04)
    gh.build("cabin", "primary", regions=[
        R(-5.75, -3.65, 4.12, 6.0, "glass", 0.03),    # windscreen
        R(-4.75, -0.3, 3.08, 3.9, "glass", 0.03),     # door glass, follows the screen pillar
        R(0.0, 4.7, 3.08, 3.9, "glass", 0.03),        # quarter glass, follows the roof down
        R(3.25, 6.0, 4.15, 6.0, "glass", 0.03),       # rear window
        R(-3.4, 3.0, 5.1, 6.0, "secondary", 0.02)])   # roof stripe


def f_nose():
    """Nose that tapers in plan and drops toward the front, deep slot grille over a sculpted bumper, long
    bonnet with a raised bulge and the twin shaker turbine."""
    K.begin("F", "NOSE")
    nose = Hull([(-12.2, dict(w=3.55, yb=0.15, yt=2.4, ys=1.9, rb=0.25, tum=0.25, drop=0.18)),
                 (-11.4, dict(w=3.8, yb=-0.15, yt=2.62, ys=2.05, rb=0.35)),
                 (-9.2, dict(w=3.9, yt=2.9, ys=2.25)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.2, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.6, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-12.0, Z_F - GAP, 5.15, 6.0, "secondary", -0.07),   # raised bonnet bulge, in the stripe colour
        R(-9.6, -5.9, 5.5, 6.0, "detail", 0.1)])
    nose.cap("grilleback", "min", "detail")
    # brow and bumper stand well ahead of the grille back, so the slot between them is a deep recess
    Hull([(-13.05, dict(w=3.4, yb=1.95, yt=2.22, ys=2.06)), (-12.2, dict(w=3.55, yb=1.9, yt=2.4, ys=2.12))], rb=0.04,
         tum=0.2, drop=0.1, wcf=0.7, d2=0.02, crown=0.03).build("brow", "primary")
    Hull([(-13.25, dict(w=3.36, yb=0.45, yt=1.3, ys=1.05)), (-12.2, dict(w=3.55, yb=0.15, yt=1.42, ys=1.15))], rb=0.3,
         tum=0.15, drop=0.1, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    box("bar", (0, 1.66, -12.7), (6.9, 0.07, 0.12), "metal")
    box("intake", (0, 0.86, -13.27), (4.4, 0.44, 0.08), "detail")
    Loft([(-13.6, dict(w=3.0)), (-12.9, dict(w=3.6)), (-11.2, dict(w=3.85))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "secondary")
    # twin shaker turbine through the bonnet
    y = 3.95
    box("shakerbase", (0, y - 0.72, -7.75), (2.9, 0.34, 3.3), "detail")
    t = Loft([(-10.2, dict(w=0.76, yb=y - 0.76, yt=y + 0.76)), (-9.5, {}), (-6.3, {})], cx=0.74, w=0.64, yb=y - 0.64,
             yt=y + 0.64, nt=2, nb=2, yw=0.5)
    t.build("shaker", "metal", mirror=True, caps=(False, True))
    t.throat("shakerin", "min", lip="metal", wall="detail", back="detail", scale=0.86, depth=0.7, mirror=True)
    tube(-10.0, -9.5, 0.74, y, 0.2).build("shakerhub", "metal", mirror=True)


def f_pod_regions(z0, z1):
    """Engine fender, standard trim: clean body colour over a black rocker, with one character line."""
    return [R(z0 + 0.15, z1 - 0.15, 1.0, 2.0, "secondary", 0.02),
            R(z0 + 0.7, z1 - 0.3, POD_LINE[0], POD_LINE[1], "primary", 0.025, side=1)]


def f_fpod():
    """Front engine fender: a flat lamp face with a halo pair, low at the front and rising to the pod face."""
    K.begin("F", "FPOD")
    pod = Hull([(-12.7, dict(cx=5.38, w=1.2, yb=-0.75, yt=1.7, ys=1.15, rb=0.3, tum=0.25, drop=0.18)),
                (-12.2, dict(cx=5.4, w=1.28, yb=-1.05, yt=1.95, ys=1.35)),
                (-10.5, dict(w=1.32, yt=2.25)), (-8.0, dict(w=1.32, yt=2.4)),
                (POD_FZ, SIDE_F)], **SIDE_F)
    pod.build("skin", "primary", mirror=True, caps=(True, False),
              regions=f_pod_regions(-12.7, POD_FZ))
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.5, depth=0.6, mirror=True)
    for i, x in enumerate((4.9, 5.86)):
        halo(f"halo{i}", x, 0.82, -13.0, 0.42)
    flange(-11.2, -6.4, -0.3, 1.9)
    lift_glow(pod, [(-10.4, -7.4)])


def f_rpod():
    """Rear engine fender: a haunch no taller than the deck, with one round barrel behind."""
    K.begin("F", "RPOD")
    pod = Hull([(POD_RZ, SIDE_R), (5.4, dict(w=1.32, yb=-1.35, yt=2.85, ys=2.0)),
                (8.6, dict(w=1.32, yb=-1.35, yt=3.05, ys=2.15)), (10.2, dict(w=1.3, yb=-1.25, yt=2.95, ys=2.1)),
                (11.3, dict(cx=5.4, w=1.2, yb=-0.9, yt=2.65, ys=1.9))], **SIDE_R)
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=f_pod_regions(POD_RZ, 11.3))
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    barrel("barrel", 10.4, 12.3, 5.42, 0.85, 0.9, depth=0.7, collar=False)
    flange(4.4, 10.6, -0.3, 2.1)
    lift_glow(pod, [(5.8, 9.6)])


def f_stab():
    """Sill unit with two fat bazookas that fire sideways, swept back and down."""
    K.begin("F", "STAB")
    sill = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.95, w=0.85, yb=-1.2, yt=1.0, ys=0.6, rb=0.3, tum=0.2,
                drop=0.12, wcf=0.6, d2=0.0, crown=0.04)
    sill.build("skin", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 1.0, 2.0, "secondary", 0.02)])
    for i, z in enumerate((-3.0, 0.4)):
        bazooka(f"bazooka{i}", 5.3, 6.7, z, 0.05, 0.5)
    lift_glow(sill, [(-5.0, -3.6), (1.6, 3.0)])


def f_tail():
    """Short deck that climbs to a high square tail. As on the real car the tail face is a recessed black
    panel under the deck lip, holding two ring lamps, above a body-colour bumper."""
    K.begin("F", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.35)), (9.8, dict(yt=3.55, ys=2.7)), (10.6, dict(yb=-0.3)),
                 (11.3, dict(yb=1.4, rb=0.25)),
                 (12.0, dict(w=3.72, yb=1.5, yt=3.6, ys=2.85, rb=0.25, tum=0.28, drop=0.2))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.0, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 11.6, LINE[0], LINE[1], "primary", 0.025),
        R(6.2, 12.0, 5.15, 6.0, "secondary", 0.02)])
    tail.cap("panel", "max", "detail")
    # deck lip above and bumper below stand behind the panel, with a post at each end: the lamps sit in a recess
    Hull([(12.0, dict(w=3.72, yb=3.12, yt=3.6, ys=3.3)), (12.45, dict(w=3.66, yb=3.2, yt=3.56, ys=3.34))], rb=0.04,
         tum=0.28, drop=0.18, wcf=0.72, d2=0.05, crown=0.05).build("decklip", "primary", regions=[
             R(12.0, 12.45, 5.15, 6.0, "secondary", 0.0)])
    Hull([(12.0, dict(w=3.72, yb=1.5, yt=2.32, ys=2.1)), (12.55, dict(w=3.62, yb=1.62, yt=2.26, ys=2.05))], rb=0.25,
         tum=0.12, drop=0.08, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    box("post", (3.5, 2.72, 12.2), (0.34, 0.86, 0.42), "primary", mirror=True)
    # two ring lamps: a red rounded rectangle with a dark centre
    Loft([(12.05, {}), (12.3, {})], cx=1.72, w=1.32, yb=2.42, yt=3.02, nt=5, nb=5, yw=0.5).build(
        "lamp", "lights_red", mirror=True)
    Loft([(12.28, {}), (12.33, {})], cx=1.72, w=1.13, yb=2.58, yt=2.86, nt=5, nb=5, yw=0.5).build(
        "lampcore", "detail", mirror=True)


def f_boost():
    """Two huge barrels close together under the bumper."""
    K.begin("F", "BOOST")
    Hull([(10.8, {}), (12.1, {})], w=2.6, yb=-0.45, yt=1.25, rb=0.3, ys=0.9, tum=0.2, drop=0.0, wcf=0.5, d2=0.0,
         crown=0.0).build("housing", "secondary")
    box("trim", (0, 1.29, 11.6), (4.8, 0.08, 0.8), "primary")
    barrel("barrel", 11.5, 13.2, 0.86, 0.38, 0.74, depth=0.55, collar=False)


def f_wing():
    """One-piece ducktail lip."""
    K.begin("F", "WING")
    Hull([(11.0, dict(yt=3.62, ys=3.5)), (12.6, dict(w=3.6, yt=4.3, ys=3.85))], w=3.7, yb=3.42, rb=0.02, tum=0.1,
         drop=0.04, wcf=0.7, d2=0.01, crown=0.03).build("lip", "primary")
    box("gurney", (0, 4.32, 12.56), (7.1, 0.09, 0.09), "secondary")


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
