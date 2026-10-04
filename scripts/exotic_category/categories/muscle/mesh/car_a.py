"""Car A: Outrider (muscle_01, tier E), after the Chevrolet El Camino SS (1970). STD trim.

Design language of A: a coupe utility. Short two-seat cab with a near vertical rear window, a long open
load bed with a flat tailgate, a long flat bonnet with twin black stripes over a cowl-induction bulge, a
wide blunt nose with a thin full-width grille split by one body-colour bar, slim quad rectangular lamps
on small plain pods, one slim full-width tail light strip, plain round nozzles everywhere.
"""
import exokit as K
from exokit import Hull, Loft, R
from exokit import box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, POD_LINE, barrel, bazooka, build_car, flange, lift_glow, tub

# Twin stripes: ring range on a body-width top panel (about x 0.33 to 1.56 each side of the centre line).
STRIPE = (5.2, 5.82)


def a_cockpit():
    """Short two-seat cab: raked windscreen, a short roof in one arc, then a near vertical rear window
    just behind the seats. One door glass per side, so there is no centre pillar; the sail panel behind
    the glass is body colour."""
    K.begin("A", "COCKPIT")
    tub()
    gh = Hull([(-6.0, dict(w=3.52, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.6, dict(w=3.62, yt=4.45, tum=0.5, drop=0.16)),
               (-3.3, dict(w=3.64, yt=5.34, tum=0.7)),
               (-1.6, dict(w=3.64, yt=5.58, tum=0.73)),
               (0.3, dict(w=3.63, yt=5.55, tum=0.75)),
               (1.6, dict(w=3.6, yt=5.34, tum=0.78)),
               (2.45, dict(w=3.5, yb=2.95, yt=3.24, ys=3.0, tum=0.68, drop=0.2, crown=0.02))],
              w=3.64, yb=3.1, ys=3.3, rb=0.04, tum=0.72, drop=0.21, wcf=0.75, d2=0.045, crown=0.065)
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.5, 4.13, 6.0, "detail", 0.015),     # windscreen surround
        R(-5.75, -3.61, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.85, 1.3, 3.04, 3.88, "detail", 0.015),     # door glass surround
        R(-4.74, 1.19, 3.085, 3.835, "glass", 0.04),    # door glass
        R(1.68, 2.37, 4.13, 6.0, "detail", 0.0),        # rear window surround
        R(1.72, 2.34, 4.185, 6.0, "glass", 0.04)])      # rear window


def a_nose():
    """Wide, flat, blunt nose: thin full-width grille between a brow and a bumper, split by one body
    colour bar. Long flat bonnet with twin stripes and a cowl-induction bulge near the screen."""
    K.begin("A", "NOSE")
    nose = Hull([(-12.5, dict(w=3.78, yb=0.0, yt=2.9, ys=2.25, rb=0.3)),
                 (-11.4, dict(w=3.86, yb=-0.25, yt=2.98, ys=2.3, rb=0.4)),
                 (-9.0, dict(w=3.9, yt=3.1, ys=2.38)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.5, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.9, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-12.5, Z_F - GAP, STRIPE[0], STRIPE[1], "secondary", 0.0)])
    nose.cap("grilleback", "min", "detail")
    kw = dict(tum=0.25, wcf=0.72)
    Hull([(-13.0, dict(w=3.72, yb=2.5, yt=2.86, ys=2.62)), (-12.5, dict(w=3.78, yb=2.45, yt=2.9, ys=2.6))], rb=0.04,
         drop=0.2, d2=0.06, crown=0.05, **kw).build("brow", "primary", regions=[
             R(-13.0, -12.5, STRIPE[0], STRIPE[1], "secondary", 0.0)])
    Hull([(-13.2, dict(w=3.7, yb=1.1, yt=1.68, ys=1.5)), (-12.5, dict(w=3.78, yb=1.0, yt=1.72, ys=1.52))], rb=0.2,
         drop=0.08, d2=0.0, crown=0.02, **kw).build("bumper", "primary")
    Hull([(-12.95, dict(w=3.6, yb=0.2, yt=1.1, ys=0.9)), (-12.5, dict(w=3.74, yb=0.0, yt=1.1, ys=0.9))], rb=0.3,
         drop=0.05, d2=0.0, crown=0.02, **kw).build("valance", "secondary")
    box("bar", (0, 2.09, -12.8), (6.9, 0.13, 0.2), "primary")
    box("post", (3.52, 2.1, -12.72), (0.36, 0.9, 0.5), "primary", mirror=True)
    # cowl-induction bulge: rises from the bonnet toward the screen, open at the back
    bulge = Hull([(-10.2, dict(w=1.7, yt=2.98, ys=2.8)), (-8.6, dict(yt=3.3, ys=2.95)),
                  (-6.2, dict(w=1.82, yt=3.52, ys=3.08))], w=1.8, yb=2.75, rb=0.02, tum=0.25, drop=0.06, wcf=0.75,
                 d2=0.02, crown=0.04)
    bulge.build("bulge", "primary", caps=(False, False), regions=[
        R(-10.2, -6.2, 4.0, 5.6, "secondary", 0.0)])
    bulge.throat("cowl", "max", lip="primary", wall="detail", back="detail", scale=0.82, depth=0.35)


def a_pod_regions(z0, z1):
    return [R(z0 + 0.15, z1 - 0.15, 1.0, 2.0, "secondary", 0.02),
            R(z0 + 0.45, z1 - 0.25, POD_LINE[0], POD_LINE[1], "primary", 0.05, side=1)]


def a_fpod():
    """Small plain front fender with a flat lamp face: two slim rectangular lamps side by side."""
    K.begin("A", "FPOD")
    pod = Hull([(-12.5, dict(cx=5.38, w=1.16, yb=-0.7, yt=1.75, ys=1.2, rb=0.3, tum=0.25, drop=0.18)),
                (-12.0, dict(cx=5.4, w=1.24, yb=-0.95, yt=1.92, ys=1.32)),
                (-10.2, dict(w=1.28, yt=2.12, ys=1.48)), (-8.0, dict(w=1.3, yt=2.24, ys=1.56)),
                (POD_FZ, SIDE_F)], **SIDE_F)
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=a_pod_regions(-12.5, POD_FZ))
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.5, depth=0.6, mirror=True)
    Loft([(-12.56, {}), (-12.4, {})], cx=5.38, w=0.96, yb=0.52, yt=1.06, nt=5, nb=5, yw=0.5).build(
        "bezel", "detail", mirror=True)
    for i, x in enumerate((4.93, 5.83)):
        Loft([(-12.62, {}), (-12.4, {})], cx=x, w=0.36, yb=0.63, yt=0.95, nt=5, nb=5, yw=0.5).build(
            f"lamp{i}", "lights", mirror=True)
    flange(-11.0, -6.4, -0.3, 1.8)
    lift_glow(pod, [(-10.2, -7.4)])


def a_rpod():
    """Small plain rear fender, lower than the bed rail, with one plain round nozzle."""
    K.begin("A", "RPOD")
    pod = Hull([(POD_RZ, SIDE_R), (5.4, dict(w=1.32, yb=-1.3, yt=2.62, ys=1.85)),
                (8.4, dict(w=1.32, yb=-1.3, yt=2.7, ys=1.9)), (9.9, dict(w=1.28, yb=-1.2, yt=2.6, ys=1.85)),
                (10.9, dict(cx=5.4, w=1.18, yb=-0.85, yt=2.35, ys=1.7))], **SIDE_R)
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=a_pod_regions(POD_RZ, 10.9))
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    barrel("barrel", 10.0, 11.8, 5.42, 0.75, 0.74, depth=0.6, collar=False)
    flange(4.4, 10.2, -0.3, 2.0)
    lift_glow(pod, [(5.8, 9.4)])


def a_stab():
    """Sill unit with a close pair of plain round pipes, swept back and down."""
    K.begin("A", "STAB")
    sill = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.95, w=0.85, yb=-1.2, yt=0.9, ys=0.5, rb=0.3, tum=0.2,
                drop=0.12, wcf=0.6, d2=0.0, crown=0.04)
    sill.build("skin", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 1.0, 2.0, "secondary", 0.02)])
    for i, z in enumerate((0.3, 1.4)):
        bazooka(f"pipe{i}", 5.3, 6.6, z, 0.0, 0.38, back=0.9, down=0.55, wide=1.0, flat=1.0, n=2)
    lift_glow(sill, [(-5.0, -3.6), (-2.4, -1.0)])


def a_tail():
    """Long open load bed: walls at body height, a lower black bed, a flat tailgate with one slim
    full-width light strip over a black bumper."""
    K.begin("A", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (10.6, dict(yb=-0.3)), (11.3, dict(yb=1.4, rb=0.25)),
                 (12.1, dict(w=3.82, yb=1.5, yt=3.24, rb=0.25))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.1, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 11.7, LINE[0], LINE[1], "primary", 0.025),
        R(4.0, 11.55, 4.3, 6.0, "secondary", 0.95)])       # the bed
    tail.cap("gate", "max", "primary")
    box("strip", (0, 2.82, 12.12), (6.9, 0.13, 0.1), "lights_red")
    box("gatestripe", (0.945, 2.58, 12.11), (1.23, 1.08, 0.04), "secondary", mirror=True)
    Hull([(12.1, dict(w=3.82, yb=1.5, yt=2.02, ys=1.86)), (12.5, dict(w=3.74, yb=1.58, yt=1.98, ys=1.84))], rb=0.2,
         tum=0.1, drop=0.06, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "secondary")


def a_boost():
    """Two small round tips in a black valance under the bumper."""
    K.begin("A", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.55, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "secondary", regions=[
             R(10.8, 12.2, 3.0, 3.6, "primary", 0.0)])
    barrel("tip", 11.7, 12.9, 0.72, 0.42, 0.46, depth=0.45, collar=False)


def a_wing():
    """Small lip on the top edge of the tailgate, carrying the twin stripes."""
    K.begin("A", "WING")
    Hull([(11.62, dict(yt=3.24, ys=2.98, drop=0.2)), (12.36, dict(w=3.54, yt=3.46, ys=3.18, drop=0.12))], w=3.6,
         yb=2.9, rb=0.02, tum=0.1, wcf=0.72, d2=0.05, crown=0.04).build("lip", "primary", regions=[
             R(11.62, 12.36, STRIPE[0], STRIPE[1], "secondary", 0.0)])


def car_a():
    a_cockpit()
    a_nose()
    a_tail()
    a_fpod()
    a_rpod()
    a_stab()
    a_boost()
    a_wing()


def build(out=None):
    return build_car("outrider", "A", car_a, out=out)
