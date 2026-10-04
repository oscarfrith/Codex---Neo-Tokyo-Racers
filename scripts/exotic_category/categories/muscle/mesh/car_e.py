"""Modern Muscle car E: Blackjack (muscle_05), after the Cadillac CT5-V Blackwing. STD trim only.

Design language of E: the formal, upright one. Three-box saloon (bonnet, cabin, long flat boot) with an
upright rear window, a tall shield grille that is wider at the top, a power dome with twin slim slots,
vertical blade lamps front and rear, tall upright-sided fenders with a bronze pinstripe, and every nozzle
stacked or grouped vertically.
"""
import exokit as K
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, POD_LINE, barrel, bazooka, build_car, flange, lift_glow, tub

PIN = (POD_LINE[0] + 0.11, POD_LINE[1] - 0.03)   # bronze shoulder pinstripe on the pods


def blade(name, x, y0, y1, z, face, ch, w=0.13):
    """Vertical blade lamp: a slim upright strip in a dark bezel. face is -1 (front) or +1 (rear)."""
    Loft([(z, {}), (z + face * 0.06, {})], cx=x, w=w + 0.08, yb=y0 - 0.09, yt=y1 + 0.09, nt=5, nb=5,
         yw=0.5).build(name + "bezel", "detail", mirror=True)
    Loft([(z, {}), (z + face * 0.12, {})], cx=x, w=w, yb=y0, yt=y1, nt=5, nb=5, yw=0.5).build(
        name, ch, mirror=True)


def e_cockpit():
    """Formal four-door glasshouse: raked windscreen, long level roof, an upright rear window and a thick
    rear pillar. Against the Brawler the roof is a little higher and flatter and the cabin ends 1.2 sooner,
    which leaves the long boot."""
    K.begin("E", "COCKPIT")
    tub()
    gh = Hull([(-5.9, dict(w=3.52, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.6, dict(w=3.62, yt=4.42, tum=0.5, drop=0.16)),
               (-3.3, dict(w=3.64, yt=5.5, tum=0.68)),
               (-1.8, dict(w=3.64, yt=5.84, tum=0.7)),
               (1.2, dict(w=3.64, yt=5.88, tum=0.7)),
               (2.7, dict(w=3.62, yt=5.72, tum=0.72)),
               (3.7, dict(w=3.56, yt=4.98, tum=0.62, drop=0.18)),
               (4.5, dict(w=3.5, yt=4.02, tum=0.42, drop=0.12)),
               (5.1, dict(w=3.46, yb=3.15, yt=3.3, ys=3.2, tum=0.2, drop=0.03, crown=0.02))],
              w=3.64, yb=3.1, ys=3.3, rb=0.04, tum=0.7, drop=0.21, wcf=0.75, d2=0.045, crown=0.065)
    gh.build("cabin", "primary", regions=[
        R(-5.74, -3.45, 4.13, 6.0, "detail", 0.015),    # windscreen surround
        R(-5.65, -3.56, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.85, 3.32, 3.04, 3.88, "detail", 0.015),    # side glass surround, one opening
        R(-4.74, -0.62, 3.085, 3.835, "glass", 0.04),   # front door glass
        R(-0.3, 3.21, 3.085, 3.835, "glass", 0.04),     # rear door glass
        R(2.86, 4.84, 4.14, 6.0, "detail", 0.015),      # rear window surround
        R(2.96, 4.74, 4.195, 6.0, "glass", 0.04)])      # rear window


def e_nose():
    """Tall upright nose: a shield grille (wider at the top) between two body-colour cheeks, a lower intake
    in the bumper, and a long power dome with twin slim slots down the bonnet."""
    K.begin("E", "NOSE")
    nose = Hull([(-12.3, dict(w=3.6, yb=-0.05, yt=2.62, ys=2.0, rb=0.25, tum=0.2, drop=0.16)),
                 (-11.4, dict(w=3.8, yb=-0.15, yt=2.76, ys=2.12, rb=0.35)),
                 (-9.2, dict(w=3.9, yt=2.98, ys=2.3)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.3, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.7, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025)])
    nose.cap("grilleback", "min", "detail")
    # fascia: brow, two cheeks with slanted inner edges and a bumper leave a shield-shaped recess
    Hull([(-13.0, dict(w=3.38, yb=2.3, yt=2.5, ys=2.38)), (-12.3, dict(w=3.54, yb=2.3, yt=2.62, ys=2.42))], rb=0.03,
         tum=0.2, drop=0.1, wcf=0.7, d2=0.02, crown=0.03).build("brow", "primary")
    Hull([(-13.0, dict(w=0.7)), (-12.3, dict(w=0.8))], cx=2.78, wi=1.78, tumi=0.85, tum=0.12, yb=0.6, yt=2.3,
         ys=0.68, rb=0.03, drop=0.0, dropi=0.0, wcf=0.7, d2=0.0, crown=0.0, cs=0.0).build(
             "cheek", "primary", mirror=True)
    Hull([(-13.15, dict(w=3.42, yb=0.0, yt=0.6, ys=0.46)), (-12.3, dict(w=3.6, yb=-0.05, yt=0.63, ys=0.48))],
         rb=0.2, tum=0.12, drop=0.08, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    box("intake", (0, 0.3, -13.17), (3.4, 0.26, 0.08), "detail")
    Loft([(-13.5, dict(w=3.0)), (-12.9, dict(w=3.55)), (-11.2, dict(w=3.85))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "secondary")
    # power dome: follows the bonnet, grows out of it at the front and fades into the cowl
    def st(z, w, h):
        y = nose.params(z)["yt"]
        return (z, dict(w=w, yb=y - 0.2, ys=y - 0.06, yt=y + h))
    Hull([st(-11.8, 0.7, 0.0), st(-10.8, 0.92, 0.13), st(-8.4, 1.2, 0.2), st(-6.8, 1.36, 0.19),
          st(-5.9, 1.44, -0.02)], rb=0.02, tum=0.2, drop=0.09, wcf=0.72, d2=0.015, crown=0.03).build(
              "dome", "primary", regions=[R(-9.6, -7.2, 4.55, 5.05, "detail", 0.05)])


def e_pod_regions(z0, z1):
    """Tall fender: body colour over a bronze rocker, with a bronze shoulder pinstripe."""
    return [R(z0 + 0.15, z1 - 0.15, 1.0, 2.0, "secondary", 0.02),
            R(z0 + 0.45, z1 - 0.25, PIN[0], PIN[1], "secondary", 0.02, side=1)]


def e_fpod():
    """Front engine fender: tall and upright-sided, with a vertical blade lamp on the outer front edge."""
    K.begin("E", "FPOD")
    pod = Hull([(-12.7, dict(cx=5.38, w=1.2, yb=-0.85, yt=2.05, ys=1.5, rb=0.3, tum=0.16, drop=0.16)),
                (-12.2, dict(cx=5.4, w=1.28, yb=-1.05, yt=2.22, ys=1.6, tum=0.18)),
                (-10.5, dict(w=1.32, yt=2.5, ys=1.75, tum=0.2)), (-8.0, dict(w=1.32, yt=2.5, ys=1.75, tum=0.24)),
                (POD_FZ, SIDE_F)], **SIDE_F)
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=e_pod_regions(-12.7, POD_FZ))
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.5, depth=0.6, mirror=True)
    blade("lamp", 6.16, -0.2, 1.62, -12.7, -1, "lights")
    flange(-11.2, -6.4, -0.3, 1.9)
    lift_glow(pod, [(-10.4, -7.4)])


def e_rpod():
    """Rear engine fender: upright haunch no taller than the deck, two rounded-rectangle nozzles stacked."""
    K.begin("E", "RPOD")
    pod = Hull([(POD_RZ, SIDE_R), (5.4, dict(w=1.32, yb=-1.35, yt=2.85, ys=2.1, tum=0.24)),
                (8.6, dict(w=1.32, yb=-1.35, yt=3.05, ys=2.3, tum=0.2)),
                (10.2, dict(w=1.3, yb=-1.25, yt=3.02, ys=2.28, tum=0.18)),
                (11.3, dict(cx=5.4, w=1.22, yb=-1.0, yt=2.88, ys=2.18, tum=0.18))], **SIDE_R)
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=e_pod_regions(POD_RZ, 11.3))
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    for i, y in enumerate((1.62, 0.22)):
        barrel(f"barrel{i}", 10.6, 12.2, 5.42, y, 0.8, depth=0.6, collar=False, ry=0.56, n=4.5)
    flange(4.4, 10.6, -0.3, 2.1)
    lift_glow(pod, [(5.8, 9.6)])


def e_stab():
    """Sill unit with three slim pipes grouped together, swept back and down."""
    K.begin("E", "STAB")
    sill = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.95, w=0.85, yb=-1.2, yt=1.0, ys=0.6, rb=0.3, tum=0.2,
                drop=0.12, wcf=0.6, d2=0.0, crown=0.04)
    sill.build("skin", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 1.0, 2.0, "secondary", 0.02)])
    for i, z in enumerate((-2.1, -1.3, -0.5)):
        bazooka(f"pipe{i}", 5.3, 6.6, z, 0.1, 0.27, back=0.9, down=0.65, wide=0.9, flat=1.25, n=3.5)
    lift_glow(sill, [(-5.0, -3.6), (1.6, 3.0)])


def e_tail():
    """Long flat boot to an upright tail: a tall red blade lamp at each outer edge, a clean body-colour
    panel between them and a dark lower valance."""
    K.begin("E", "TAIL")
    d = dict(SEAM_R, yt=3.3, ys=2.55)
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.27, ys=2.5)), (9.8, {}), (10.6, dict(yb=-0.3)),
                 (11.3, dict(yb=1.4, rb=0.25)),
                 (12.1, dict(w=3.74, yb=1.5, rb=0.25, tum=0.26, drop=0.2))], **d)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.1, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 11.7, LINE[0], LINE[1], "primary", 0.025)])
    tail.cap("panel", "max", "primary")
    # a post under each corner carries the blade lamp down past the panel, either side of the overdrive
    box("post", (3.28, 1.15, 11.7), (0.62, 0.9, 0.8), "primary", mirror=True)
    blade("lamp", 3.28, 0.86, 3.0, 12.1, 1, "lights_red", w=0.14)
    # dark lower valance between the lamps, standing a little behind the panel
    Hull([(12.1, dict(w=2.95, yb=1.5, yt=1.86, ys=1.74)), (12.4, dict(w=2.9, yb=1.56, yt=1.82, ys=1.72))], rb=0.12,
         tum=0.06, drop=0.04, wcf=0.7, d2=0.0, crown=0.02).build("valance", "detail")


def e_boost():
    """Four tips in two stacked pairs, each pair in a bronze bezel, in a dark valance."""
    K.begin("E", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.55, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "detail", regions=[
             R(10.8, 12.2, 3.0, 3.6, "primary", 0.0)])
    Loft([(12.2, {}), (12.32, {})], cx=0.86, w=0.72, yb=-0.14, yt=1.2, nt=5, nb=5, yw=0.5).build(
        "bezel", "secondary", mirror=True)
    for i, y in enumerate((0.86, 0.2)):
        barrel(f"tip{i}", 11.6, 13.0, 0.86, y, 0.52, depth=0.5, collar=False, ry=0.27, n=4.5)


def e_wing():
    """Low boot lip with a small upturned trailing edge, in the secondary colour."""
    K.begin("E", "WING")
    Hull([(10.9, dict(yt=3.3)), (11.8, dict(yt=3.4)), (12.25, dict(w=3.4, yb=3.14, ys=3.2, yt=3.62))], w=3.46,
         yb=3.05, ys=3.1, rb=0.02, tum=0.1, drop=0.2, wcf=0.72, d2=0.04, crown=0.04).build(
             "lip", "secondary", regions=[R(10.9, 11.4, 1.0, 6.0, "primary", 0.0)])


def car_e():
    e_cockpit()
    e_nose()
    e_tail()
    e_fpod()
    e_rpod()
    e_stab()
    e_boost()
    e_wing()


def build(out=None):
    return build_car("blackjack", "E", car_e, out=out)
