"""Car F: Brawler (muscle_06), after the Dodge Challenger SRT Demon. The hero car and the reference standard.
Standard trim only. Runs inside Blender; build with run_headless.py -- car_f.

Design language: blunt nose that tapers in plan, deep full-width slot grille, halo lamp pairs on the front
pods, twin shaker turbine through a raised bonnet bulge, long bonnet, low arched glasshouse with a fast rear
window and a short deck, recessed tail panel with two ring lamps, ducktail lip.
Pods and sill (round 2): drag-car nacelles. Round-section turbine pods with a metal intake ring and a stepped
turbine exit with a centre cone, joined by a slim round rail. Round lamps, round shaker, round nacelles.
Clean and minimal: shape, lamps, glass, stripe and jets only.
"""
import exokit as K
import musclekit as M  # noqa: F401
from exokit import Hull, Loft, R, box
from muscle_cars import LINE, barrel, bazooka, build_car, halo, tub, tube
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, Z_F, Z_R


def f_cockpit():
    """Wide, long glasshouse nearly the full width of the body: raked windscreen, long roof, a fast rear
    window down to a short deck."""
    K.begin("F", "COCKPIT")
    tub()
    # Half way between the squarer cabin of pass 9 and the arched one of pass 10 (Oscar, 2026-10-04): one
    # continuous arc from cowl to deck with a moderate crown and roof-edge radius, slightly narrower at the back.
    gh = Hull([(-6.0, dict(w=3.52, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.6, dict(w=3.62, yt=4.45, tum=0.5, drop=0.16)),
               (-3.3, dict(w=3.64, yt=5.43, tum=0.7)),
               (-1.6, dict(w=3.64, yt=5.71, tum=0.73)),
               (1.4, dict(w=3.62, yt=5.68, tum=0.75)),
               (2.9, dict(w=3.58, yt=5.42, tum=0.79)),
               (4.6, dict(w=3.46, yt=4.4, tum=0.6, drop=0.17)),
               (6.3, dict(w=3.4, yb=3.15, yt=3.3, ys=3.2, tum=0.2, drop=0.03, crown=0.02))],
              w=3.64, yb=3.1, ys=3.3, rb=0.04, tum=0.72, drop=0.21, wcf=0.75, d2=0.045, crown=0.065)
    # Body-colour pillars of medium width, a black centre pillar, each glass in a thin black surround.
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.5, 4.13, 6.0, "detail", 0.015),     # windscreen surround
        R(-5.75, -3.61, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.85, 4.62, 3.04, 3.88, "detail", 0.015),    # side glass surround, one opening
        R(-4.74, -0.28, 3.085, 3.835, "glass", 0.04),   # door glass
        R(0.04, 4.5, 3.085, 3.835, "glass", 0.04),      # quarter glass
        R(3.21, 6.06, 4.14, 6.0, "detail", 0.015),      # rear window surround
        R(3.31, 5.96, 4.195, 6.0, "glass", 0.04),       # rear window
        R(-3.1, 2.75, 5.22, 6.0, "secondary", 0.02)])   # roof stripe


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
    """Nacelle paint, standard trim: body colour over a black belly. Loft ring angles."""
    return [R(z0, z1, 198, 342, "secondary", 0.02)]


def f_turbine(name, z1, x, y, r, step, tip):
    """Turbine exit firing backwards: a metal ring, a second ring stepped inside it, a recessed glowing
    core and a centre cone. z1 is the end of the outer ring; the inner ring ends step behind it and the
    cone tip sits tip behind it."""
    o = tube(z1 - 0.9 * r, z1, x, y, r)
    o.build(name, "metal", mirror=True, caps=(True, False))
    o.throat(name + "s", "max", lip="metal", wall="detail", back="detail", scale=0.9, depth=0.4 * r, mirror=True)
    i = tube(z1 - 0.5 * r, z1 + step, x, y, 0.8 * r)
    i.build(name + "i", "metal", mirror=True, caps=(False, False))
    i.throat(name + "n", "max", lip="metal", wall="detail", back="thrust", scale=0.9, depth=0.32 * r, mirror=True)
    z0 = z1 + step - 0.32 * r
    Loft([(z0, dict(w=0.24 * r, yb=y - 0.24 * r, yt=y + 0.24 * r)), (z1 + tip, dict(w=0.03, yb=y - 0.03, yt=y + 0.03))],
         cx=x, nt=2, nb=2, yw=0.5).build(name + "cone", "metal", mirror=True)


def f_pylon(z0, z1, y0, y1):
    """Dark pylon between a nacelle and the body side."""
    box("pylon", (4.2, (y0 + y1) / 2, (z0 + z1) / 2), (0.6, y1 - y0, z1 - z0), "detail", mirror=True)


def f_fpod():
    """Front nacelle: the squared lamp face with a halo pair grows back into a round turbine pod. Its jet
    leaves through a shrouded turbine exit in the rear face."""
    K.begin("F", "FPOD")
    pod = Loft([(-12.7, dict(cx=5.38, w=1.2, yb=-0.75, yt=1.7, nt=5, nb=5)),
                (-12.1, dict(cx=5.39, w=1.25, yb=-0.95, yt=1.8, nt=3.8, nb=3.8)),
                (-11.0, dict(w=1.3, yb=-1.17, yt=1.93, nt=2.5, nb=2.8)),
                (-8.4, dict(w=1.3, yb=-1.22, yt=1.97)),
                (POD_FZ, dict(w=1.24, yb=-1.2, yt=1.82))], cx=5.4, w=1.3, yb=-1.2, yt=1.95, nt=2.2, nb=2.7, yw=0.5)
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=f_pod_regions(-12.7, POD_FZ))
    pod.throat("aft", "max", lip="primary", wall="detail", back="detail", scale=0.9, depth=0.65, mirror=True)
    f_turbine("noz", -5.97, 5.45, 0.5, 0.68, 0.06, 0.1)
    for i, x in enumerate((4.9, 5.86)):
        halo(f"halo{i}", x, 0.82, -13.0, 0.42)
    f_pylon(-11.2, -6.8, -0.2, 0.9)
    pod.patch("lift", -10.4, -7.4, 258, 282, "thrust", mirror=True)


def f_rpod():
    """Rear turbine nacelle, no taller than the deck: a barrel-shaped round pod with a plain dark intake
    at the front and one large turbine exit behind."""
    K.begin("F", "RPOD")
    pod = Loft([(POD_RZ, dict(cx=5.4, w=1.3, yb=-1.2, yt=2.1)),
                (5.6, dict(w=1.4, yb=-1.25, yt=2.25)),
                (8.4, dict(w=1.4, yb=-1.25, yt=2.25)),
                (10.4, dict(w=1.22, yb=-0.95, yt=1.95, nb=2.2)),
                (11.4, dict(w=1.04, yb=-0.62, yt=1.62, nb=2.0))], cx=5.5, nt=2.2, nb=2.7, yw=0.5)
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=f_pod_regions(POD_RZ, 11.4))
    # A plain body-colour lip and a dark tunnel. No bright ring and no centre spinner: a ring round a hub
    # read as a wheel from the front three-quarter view.
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.82, depth=1.3, mirror=True)
    f_turbine("noz", 12.05, 5.5, 0.5, 1.0, 0.25, 0.38)
    f_pylon(4.8, 10.4, -0.2, 1.0)
    pod.patch("lift", 5.8, 9.6, 258, 282, "thrust", mirror=True)


def f_stab():
    """Sill unit: a slim round rail between the nacelles with a metal collar at each end and two
    bazookas that fire sideways, swept back and down."""
    K.begin("F", "STAB")
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    rail = Loft([(z0, {}), (z1, {})], cx=4.7, w=0.6, yb=-1.15, yt=-0.05, nt=2, nb=2, yw=0.5)
    rail.build("skin", "primary", mirror=True, regions=[
        R(z0, z0 + 0.3, 0, 360, "metal", 0.0), R(z1 - 0.3, z1, 0, 360, "metal", 0.0),
        R(z0 + 0.3, z1 - 0.3, 198, 342, "secondary", 0.02)])
    for i, z in enumerate((-3.0, 0.4)):
        bazooka(f"bazooka{i}", 4.9, 6.3, z, -0.55, 0.5, down=0.5)
    for i, (a, b) in enumerate(((-5.0, -3.6), (1.6, 3.0))):
        rail.patch(f"lift{i}", a, b, 255, 285, "thrust", mirror=True)


def f_tail():
    """Short deck that climbs to a high square tail. As on the real car the tail face is a recessed black
    panel under the deck lip, holding two ring lamps, above a body-colour bumper."""
    K.begin("F", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.35)), (9.8, dict(yt=3.55, ys=2.7)), (10.6, dict(yb=-0.3, yt=3.57, ys=2.75)),
                 (11.3, dict(yb=1.4, rb=0.25, yt=3.59, ys=2.8)),
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
    Loft([(12.05, {}), (12.3, {})], cx=1.78, w=1.5, yb=2.4, yt=3.06, nt=5, nb=5, yw=0.5).build(
        "lamp", "lights_red", mirror=True)
    Loft([(12.28, {}), (12.33, {})], cx=1.78, w=1.3, yb=2.58, yt=2.88, nt=5, nb=5, yw=0.5).build(
        "lampcore", "detail", mirror=True)


def f_boost():
    """Two barrels close together in a black valance under the bumper."""
    K.begin("F", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.55, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "secondary", regions=[
             R(10.8, 12.2, 3.0, 3.6, "primary", 0.0)])
    barrel("barrel", 11.6, 13.2, 0.98, 0.4, 0.86, depth=0.55, collar=False, ry=0.56, n=4.5)


def f_wing():
    """One-piece ducktail lip, low on the deck edge."""
    K.begin("F", "WING")
    Hull([(11.2, dict(yt=3.66, ys=3.6)), (12.5, dict(w=3.6, yt=3.98, ys=3.78))], w=3.68, yb=3.5, rb=0.02, tum=0.14,
         drop=0.04, wcf=0.72, d2=0.01, crown=0.03).build("lip", "primary", regions=[
             R(11.2, 12.5, 5.15, 6.0, "secondary", 0.0)])


def car_f():
    f_cockpit()
    f_nose()
    f_tail()
    f_fpod()
    f_rpod()
    f_stab()
    f_boost()
    f_wing()


def build(out=None):
    return build_car("brawler", "F", car_f, out=out)
