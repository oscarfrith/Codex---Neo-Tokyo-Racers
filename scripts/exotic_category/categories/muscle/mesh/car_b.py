"""Modern Muscle car B: Enforcer (muscle_02, tier D), after the Dodge Charger R/T four-door saloon (2019).
Runs inside Blender through run_headless.py (module car_b). STD trim only.

Design language of B: a plain, purposeful pursuit saloon. Wide low nose with a thin full-width grille and
a subtle cross bar, shallow bonnet bulge with one small intake slot, slim squinting light strips on the
front pods, a long four-door cabin with a fast rear window into a short high boot, one continuous red
racetrack loop round the tail panel, flat slot nozzles everywhere, one long scallop on each pod flank and a
small body-colour lip spoiler.
"""
import exokit as K
import musclekit as M  # noqa: F401  (sets the frame up)
from exokit import Hull, Loft, R
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, barrel, bazooka, build_car, flange, lift_glow, tub
from exokit import box

# One long scallop on each pod flank, in place of the plain character line.
SCALLOP = (2.56, 2.8)


def b_cockpit():
    """Four-door saloon cabin: the Brawler windscreen, a longer roof, and a long fast rear window that
    runs down to the boot. Two side glasses of similar length each side of a black centre pillar."""
    K.begin("B", "COCKPIT")
    tub()
    gh = Hull([(-6.0, dict(w=3.52, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.6, dict(w=3.62, yt=4.45, tum=0.5, drop=0.16)),
               (-3.3, dict(w=3.64, yt=5.43, tum=0.7)),
               (-1.6, dict(w=3.64, yt=5.72, tum=0.73)),
               (1.6, dict(w=3.63, yt=5.7, tum=0.75)),
               (3.2, dict(w=3.6, yt=5.5, tum=0.78)),
               (5.0, dict(w=3.5, yt=4.52, tum=0.62, drop=0.17)),
               (6.6, dict(w=3.42, yb=3.15, yt=3.3, ys=3.2, tum=0.2, drop=0.03, crown=0.02))],
              w=3.64, yb=3.1, ys=3.3, rb=0.04, tum=0.72, drop=0.21, wcf=0.75, d2=0.045, crown=0.065)
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.5, 4.13, 6.0, "detail", 0.015),     # windscreen surround
        R(-5.75, -3.61, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.85, 5.32, 3.04, 3.88, "detail", 0.015),    # side glass surround, one opening
        R(-4.74, 0.1, 3.085, 3.835, "glass", 0.04),   # front door glass
        R(0.42, 5.2, 3.085, 3.835, "glass", 0.04),       # rear door glass
        R(3.4, 6.06, 4.14, 6.0, "detail", 0.015),       # rear window surround
        R(3.5, 5.96, 4.195, 6.0, "glass", 0.04)])       # rear window


def b_nose():
    """Wide, low, plain nose: a thin full-width grille slot with a cross bar over a plain bumper, and a
    shallow bonnet bulge with one small intake slot."""
    K.begin("B", "NOSE")
    nose = Hull([(-12.5, dict(w=3.72, yb=0.2, yt=2.3, ys=1.85, rb=0.25, tum=0.22, drop=0.16)),
                 (-11.6, dict(w=3.85, yb=-0.15, yt=2.55, ys=2.0, rb=0.35)),
                 (-9.2, dict(w=3.9, yt=2.88, ys=2.25)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.5, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.8, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-11.2, Z_F - GAP, 5.3, 6.0, "primary", -0.05),      # shallow bonnet bulge
        R(-8.9, -8.35, 5.55, 6.0, "detail", 0.08)])           # one small intake slot
    nose.cap("grilleback", "min", "detail")
    # brow and bumper stand ahead of the grille back: the thin slot between them is the grille
    Hull([(-13.1, dict(w=3.58, yb=1.78, yt=2.14, ys=1.94)), (-12.5, dict(w=3.72, yb=1.74, yt=2.3, ys=2.0))], rb=0.04,
         tum=0.2, drop=0.1, wcf=0.7, d2=0.02, crown=0.03).build("brow", "primary")
    Hull([(-13.25, dict(w=3.56, yb=0.42, yt=1.2, ys=0.98)), (-12.5, dict(w=3.72, yb=0.2, yt=1.24, ys=1.02))], rb=0.28,
         tum=0.12, drop=0.08, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    box("bar", (0, 1.49, -12.85), (7.0, 0.07, 0.1), "metal")
    box("post", (0, 1.49, -12.9), (0.09, 0.5, 0.1), "metal")
    Loft([(-13.6, dict(w=3.2)), (-12.9, dict(w=3.65)), (-11.2, dict(w=3.85))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "secondary")


def b_pod_regions(z0, z1):
    """Engine fender, standard trim: body colour over a black rocker, with one long scallop."""
    return [R(z0 + 0.15, z1 - 0.15, 1.0, 2.0, "secondary", 0.02),
            R(z0 + 0.9, z1 - 0.5, SCALLOP[0], SCALLOP[1], "primary", 0.05, side=1)]


def b_fpod():
    """Front engine fender with one slim squinting light strip across its face."""
    K.begin("B", "FPOD")
    pod = Hull([(-12.7, dict(cx=5.38, w=1.2, yb=-0.75, yt=1.6, ys=1.1, rb=0.3, tum=0.25, drop=0.18)),
                (-12.2, dict(cx=5.4, w=1.28, yb=-1.05, yt=1.85, ys=1.3)),
                (-10.5, dict(w=1.32, yt=2.15, cs=-0.05)), (-8.0, dict(w=1.32, yt=2.34, cs=-0.05)),
                (POD_FZ, SIDE_F)], **SIDE_F)
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=b_pod_regions(-12.7, POD_FZ))
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.5, depth=0.6, mirror=True)
    # dark lamp housing with a thin strip of light along its top edge, lower at the inboard end
    kw = dict(axis="x", cx=-12.72, nt=5, nb=5, yw=0.5)
    Loft([(4.4, dict(yb=0.4, yt=0.78)), (6.12, dict(yb=0.7, yt=1.08))], w=0.04, **kw).build(
        "lamp", "detail", mirror=True)
    Loft([(4.48, dict(yb=0.64, yt=0.75)), (6.04, dict(yb=0.93, yt=1.04))], w=0.07, **kw).build(
        "strip", "lights", mirror=True)
    flange(-11.2, -6.4, -0.3, 1.9)
    lift_glow(pod, [(-10.4, -7.4)])


def b_rpod():
    """Rear engine fender, no taller than the boot, with one wide flat slot nozzle."""
    K.begin("B", "RPOD")
    pod = Hull([(POD_RZ, SIDE_R), (5.4, dict(w=1.32, yb=-1.35, yt=2.8, ys=1.98, cs=-0.05)),
                (8.6, dict(w=1.32, yb=-1.35, yt=2.98, ys=2.1, cs=-0.05)), (10.2, dict(w=1.3, yb=-1.2, yt=2.86, ys=2.02)),
                (11.3, dict(cx=5.4, w=1.22, yb=-0.7, yt=2.5, ys=1.8))], **SIDE_R)
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=b_pod_regions(POD_RZ, 11.3))
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    barrel("slot", 10.4, 12.2, 5.4, 0.85, 1.05, depth=0.6, collar=False, ry=0.36, n=4.5)
    flange(4.4, 10.6, -0.3, 2.1)
    lift_glow(pod, [(5.8, 9.6)])


def b_stab():
    """Sill unit with two flat slot thrusters that fire sideways, swept back and down."""
    K.begin("B", "STAB")
    sill = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.95, w=0.85, yb=-1.2, yt=1.0, ys=0.6, rb=0.3, tum=0.2,
                drop=0.12, wcf=0.6, d2=0.0, crown=0.04)
    sill.build("skin", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 1.0, 2.0, "secondary", 0.02)])
    for i, z in enumerate((-2.6, 0.2)):
        bazooka(f"slot{i}", 5.3, 6.6, z, 0.0, 0.5, back=0.9, down=0.5, wide=1.6, flat=0.42)
    lift_glow(sill, [(-5.0, -3.6), (1.6, 3.0)])


def b_tail():
    """Short high boot. The tail face is a black panel filled by one continuous red racetrack loop with a
    dark centre, under the boot lip and above a plain bumper."""
    K.begin("B", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.45)), (9.8, dict(yt=3.62, ys=2.75)), (10.6, dict(yb=-0.3)),
                 (11.3, dict(yb=1.4, rb=0.25)),
                 (12.0, dict(w=3.74, yb=1.5, yt=3.62, ys=2.85, rb=0.25, tum=0.26, drop=0.2))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.0, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 11.6, LINE[0], LINE[1], "primary", 0.025)])
    tail.cap("panel", "max", "detail")
    Hull([(12.0, dict(w=3.74, yb=3.14, yt=3.62, ys=3.3)), (12.45, dict(w=3.68, yb=3.2, yt=3.58, ys=3.34))], rb=0.04,
         tum=0.26, drop=0.18, wcf=0.72, d2=0.05, crown=0.05).build("decklip", "primary")
    Hull([(12.0, dict(w=3.74, yb=1.5, yt=2.24, ys=2.04)), (12.55, dict(w=3.64, yb=1.62, yt=2.18, ys=2.0))], rb=0.25,
         tum=0.12, drop=0.08, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    # racetrack: one red rounded rectangle across the whole tail, with a dark centre
    Loft([(12.02, {}), (12.3, {})], w=3.46, yb=2.3, yt=3.1, nt=6, nb=6, yw=0.5).build("loop", "lights_red")
    Loft([(12.28, {}), (12.34, {})], w=3.27, yb=2.49, yt=2.91, nt=6, nb=6, yw=0.5).build("loopcore", "detail")


def b_boost():
    """Two wide flat slots side by side in a black valance under the bumper."""
    K.begin("B", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.6, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "secondary", regions=[
             R(10.8, 12.2, 3.0, 3.6, "primary", 0.0)])
    barrel("slot", 11.6, 13.0, 1.22, 0.45, 1.0, depth=0.5, collar=False, ry=0.34, n=4.5)


def b_wing():
    """Small body-colour lip spoiler on the trailing edge of the boot."""
    K.begin("B", "WING")
    Hull([(11.45, dict(yt=3.66, ys=3.6)), (12.5, dict(w=3.24, yt=3.84, ys=3.7))], w=3.3, yb=3.36, rb=0.02, tum=0.14,
         drop=0.04, wcf=0.72, d2=0.01, crown=0.03).build("lip", "primary", regions=[
             R(11.45, 12.5, 0.0, 2.0, "secondary", 0.0)])


def car_b():
    b_cockpit()
    b_nose()
    b_tail()
    b_fpod()
    b_rpod()
    b_stab()
    b_boost()
    b_wing()


def build(out=None):
    return build_car("enforcer", "B", car_b, out=out)
