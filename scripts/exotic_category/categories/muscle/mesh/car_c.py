"""Car C: Slingshot (muscle_03), after the Chevrolet Camaro SS (2022, sixth generation). STD trim only.

Design language of C: the sharp, low, angular one. Wedge nose with a thin upper grille slot over a huge open
lower mouth, a flat black heat extractor sunk in the bonnet, slit lamps on faceted front pods, the lowest
roof of the family over a narrow band of side glass and very high shoulders, black roof, a short chopped
Kamm tail with four small red lamps on a dark panel, a thin blade wing on two short uprights, and square
nozzles everywhere: one flat wide slot per rear pod, three small squares per sill, four in the overdrive.
"""
import exokit as K
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, POD_LINE, bazooka, barrel, build_car, flange, lift_glow, tub

# Faceted pod section: flat panels, a wide planar shoulder bevel and crisp creases.
FACET = dict(tum=0.46, drop=0.1, wcf=0.86, d2=0.015, crown=0.0, cs=0.0)


def c_cockpit():
    """Chopped coupe cabin: steep screen, the lowest roof of the six, a slit of side glass over a tall
    body-colour shoulder, and a short fast rear window. Black roof."""
    K.begin("C", "COCKPIT")
    tub()
    gh = Hull([(-6.0, dict(w=3.5, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.7, dict(w=3.6, yt=4.2, ys=3.42, tum=0.45, drop=0.15)),
               (-3.3, dict(yt=4.98, tum=0.62)),
               (-1.6, dict(yt=5.2, tum=0.66)),
               (1.0, dict(yt=5.17, tum=0.68)),
               (2.8, dict(yt=4.9, tum=0.7)),
               (4.6, dict(w=3.46, yt=4.1, ys=3.42, tum=0.55, drop=0.16)),
               (6.3, dict(w=3.4, yb=3.15, yt=3.3, ys=3.2, tum=0.2, drop=0.03, crown=0.02))],
              w=3.62, yb=3.1, ys=3.6, rb=0.04, tum=0.66, drop=0.2, wcf=0.76, d2=0.04, crown=0.04)
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.38, 4.13, 6.0, "detail", 0.015),    # windscreen surround
        R(-5.75, -3.49, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.75, 4.4, 3.06, 3.86, "detail", 0.015),     # side glass surround, one opening
        R(-4.64, 0.7, 3.11, 3.81, "glass", 0.04),       # door glass
        R(1.0, 4.28, 3.11, 3.81, "glass", 0.04),        # quarter glass
        R(3.02, 6.06, 4.14, 6.0, "detail", 0.015),      # rear window surround
        R(3.12, 5.96, 4.195, 6.0, "glass", 0.04),       # rear window
        R(-3.2, 2.84, 4.14, 6.0, "secondary", 0.02)])   # black roof


def c_nose():
    """Wedge nose: the bonnet falls to a low sharp edge. A thin grille slot under the brow, then one bumper
    frame round a huge open mouth. Flat heat extractor sunk in the bonnet centre."""
    K.begin("C", "NOSE")
    nose = Hull([(-12.4, dict(w=3.5, yb=-0.2, yt=2.2, ys=1.8, rb=0.3, tum=0.22, drop=0.15)),
                 (-11.0, dict(w=3.78, yb=-0.35, yt=2.52, ys=2.0, rb=0.4)),
                 (-8.5, dict(w=3.9, yt=2.96, ys=2.3)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.4, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.8, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-10.2, -6.6, 5.3, 6.0, "secondary", 0.02),    # extractor frame
        R(-9.9, -6.9, 5.42, 6.0, "detail", 0.1)])       # heat extractor
    nose.cap("grilleback", "min", "detail")
    # brow: the sharp leading edge of the bonnet; the thin grille slot is the gap under it
    Hull([(-13.1, dict(w=3.3, yb=1.9, yt=2.06, ys=1.96)), (-12.4, dict(w=3.5, yb=1.84, yt=2.2, ys=2.0))], rb=0.03,
         tum=0.2, drop=0.1, wcf=0.72, d2=0.02, crown=0.02).build("brow", "primary")
    # bumper frame with the open mouth
    bump = Hull([(-13.25, dict(w=3.32, yb=-0.08, yt=1.5, ys=1.2)), (-12.4, dict(w=3.5, yb=-0.2, yt=1.56, ys=1.25))],
                rb=0.5, tum=0.12, drop=0.06, wcf=0.8, d2=0.0, crown=0.0, cs=0.0)
    bump.build("bumper", "primary", caps=(False, False))
    bump.throat("mouth", "min", lip="primary", wall="detail", back="detail", scale=0.84, depth=0.7)
    Loft([(-13.6, dict(w=2.9)), (-12.9, dict(w=3.5)), (-11.2, dict(w=3.8))], yb=-0.46, yt=-0.34, nt=6,
         nb=6).build("chin", "secondary")


def c_pod_regions(z0, z1):
    return [R(z0 + 0.15, z1 - 0.15, 1.0, 2.0, "secondary", 0.02),
            R(z0 + 0.45, z1 - 0.25, POD_LINE[0], POD_LINE[1], "primary", 0.05, side=1)]


def c_fpod():
    """Faceted front fender, low at the front. Lamp face: one thin light slit with a short one under it."""
    K.begin("C", "FPOD")
    pod = Hull([(-12.6, dict(cx=5.38, w=1.18, yb=-0.6, yt=1.9, ys=1.3, rb=0.34, **FACET)),
                (-11.9, dict(cx=5.4, w=1.3, yb=-1.05, yt=2.06, ys=1.4, **FACET)),
                (-9.5, dict(w=1.32, yt=2.24, ys=1.5, **FACET)),
                (POD_FZ, SIDE_F)], **SIDE_F)
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=c_pod_regions(-12.6, POD_FZ))
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.5, depth=0.6, mirror=True)
    Loft([(-12.68, {}), (-12.58, {})], cx=5.38, w=0.92, yb=0.72, yt=1.4, nt=7, nb=7, yw=0.5).build(
        "bezel", "detail", mirror=True)
    box("slit", (5.38, 1.18, -12.7), (1.56, 0.13, 0.06), "lights", mirror=True)
    box("slit2", (5.62, 0.9, -12.7), (0.9, 0.08, 0.06), "lights", mirror=True)
    flange(-11.2, -6.4, -0.3, 1.9)
    lift_glow(pod, [(-10.4, -7.4)])


def c_rpod():
    """Faceted rear fender, lower than the deck, with one flat wide slot nozzle."""
    K.begin("C", "RPOD")
    pod = Hull([(POD_RZ, SIDE_R), (5.6, dict(w=1.32, yb=-1.35, yt=2.76, ys=1.85, **FACET)),
                (8.6, dict(w=1.32, yb=-1.35, yt=2.92, ys=1.95, **FACET)),
                (10.2, dict(w=1.3, yb=-1.25, yt=2.84, ys=1.9, **FACET)),
                (11.2, dict(cx=5.4, w=1.2, yb=-0.9, yt=2.6, ys=1.75, **FACET))], **SIDE_R)
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=c_pod_regions(POD_RZ, 11.2))
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    barrel("slot", 10.4, 12.1, 5.42, 0.75, 1.06, depth=0.6, collar=False, ry=0.36, n=7)
    flange(4.4, 10.6, -0.3, 2.1)
    lift_glow(pod, [(5.8, 9.6)])


def c_stab():
    """Faceted sill unit with three small square thrusters in a row, swept back and down."""
    K.begin("C", "STAB")
    sill = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.95, w=0.85, yb=-1.2, yt=1.0, ys=0.5, rb=0.34, tum=0.3,
                drop=0.08, wcf=0.8, d2=0.0, crown=0.0, cs=0.0)
    sill.build("skin", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 1.0, 2.0, "secondary", 0.02)])
    for i, z in enumerate((-2.9, -1.7, -0.5)):
        bazooka(f"jet{i}", 5.3, 6.45, z, 0.0, 0.36, back=0.7, down=0.5, wide=1.0, flat=1.0, n=7)
    lift_glow(sill, [(-5.0, -3.8), (1.8, 3.0)])


def c_tail():
    """Short deck to a chopped Kamm tail. The tail face is a recessed dark panel with four small red lamps."""
    K.begin("C", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.3)), (9.8, dict(yt=3.46, ys=2.65)), (10.6, dict(yb=-0.3)),
                 (11.2, dict(yb=1.4, rb=0.25)),
                 (11.8, dict(w=3.74, yb=1.5, yt=3.5, ys=2.8, rb=0.25, tum=0.26, drop=0.18))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 11.8, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 11.4, LINE[0], LINE[1], "primary", 0.025)])
    tail.cap("panel", "max", "detail")
    Hull([(11.8, dict(w=3.74, yb=3.1, yt=3.5, ys=3.24)), (12.25, dict(w=3.7, yb=3.16, yt=3.48, ys=3.28))], rb=0.03,
         tum=0.26, drop=0.16, wcf=0.74, d2=0.05, crown=0.03).build("decklip", "primary")
    Hull([(11.8, dict(w=3.74, yb=1.5, yt=2.3, ys=2.1)), (12.35, dict(w=3.66, yb=1.6, yt=2.26, ys=2.06))], rb=0.25,
         tum=0.1, drop=0.06, wcf=0.8, d2=0.0, crown=0.0).build("bumper", "primary")
    box("post", (3.5, 2.7, 12.0), (0.34, 0.86, 0.42), "primary", mirror=True)
    for i, x in enumerate((1.12, 2.46)):
        Loft([(11.85, {}), (12.08, {})], cx=x, w=0.52, yb=2.48, yt=2.94, nt=6, nb=6, yw=0.5).build(
            f"lamp{i}", "lights_red", mirror=True)


def c_boost():
    """Four small square tips in a row in a black valance."""
    K.begin("C", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.1, dict(w=2.6, yb=-0.2))], yb=-0.45, yt=1.3, rb=0.4, ys=0.95, tum=0.22,
         drop=0.05, wcf=0.7, d2=0.0, crown=0.0).build("housing", "secondary", regions=[
             R(10.8, 12.1, 4.0, 6.0, "primary", 0.0)])
    for i, x in enumerate((0.5, 1.5)):
        barrel(f"tip{i}", 11.5, 12.9, x, 0.42, 0.4, depth=0.45, collar=False, ry=0.4, n=7)


def c_wing():
    """Thin blade on two short uprights."""
    K.begin("C", "WING")
    Loft([(-3.7, dict(cx=11.95, w=0.5)), (0.0, dict(cx=11.75, w=0.62)), (3.7, dict(cx=11.95, w=0.5))], axis="x",
         yb=4.08, yt=4.21, nt=2.2, nb=2.2, yw=0.6).build("blade", "primary")
    box("upright", (2.2, 3.74, 11.7), (0.14, 0.78, 0.62), "secondary", mirror=True)


def car_c():
    c_cockpit()
    c_nose()
    c_tail()
    c_fpod()
    c_rpod()
    c_stab()
    c_boost()
    c_wing()


def build(out=None):
    return build_car("slingshot", "C", car_c, out=out)
