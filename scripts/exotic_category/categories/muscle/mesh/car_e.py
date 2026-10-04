"""Modern Muscle car E: Blackjack (muscle_05), after the Cadillac CT5-V Blackwing. STD trim only.

Design language of E: the formal, upright one. Three-box saloon (bonnet, cabin, long flat boot) with an
upright rear window, a tall shield grille that is wider at the top, a power dome with twin slim slots,
vertical blade lamps front and rear, and every nozzle stacked or grouped vertically. Pods and sill are
"vertical blades": tall, narrow, slab-sided, flat-topped fins standing clear of the body with a bronze spine,
joined at the base by a thin dark plank.
"""
import exokit as K
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, barrel, bazooka, build_car, flange, lift_glow, tub

BX, BW = 5.47, 0.47   # blade pods: centre and half width (x 5.0 to 5.94, clear of the body side)
BAND = (-0.86, -0.62)  # bronze band: the outer edge of the sill plank, carried along both blades


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
    # slim bronze surround, so the recess reads as the shield
    sh = Hull([(-13.07, {}), (-12.97, {})], w=1.04, yb=0.58, yt=2.34, ys=0.66, rb=0.02, tum=-0.86, drop=0.0,
              wcf=0.7, d2=0.0, crown=0.0, cs=0.0)
    sh.build("shield", "secondary", caps=(False, False))
    sh.throat("shieldn", "min", lip="secondary", wall="detail", back="detail", scale=0.9, depth=0.35)
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


def port(name, z0, z1, x, y, r, ry, end, back):
    """Upright slot in a bronze frame on a blade end face: a jet (back thrust) or an intake (back detail)."""
    t = Loft([(z0, {}), (z1, {})], cx=x, w=r, yb=y - ry, yt=y + ry, nt=4.5, nb=4.5, yw=0.5)
    t.build(name, "secondary", mirror=True, caps=(False, False))
    t.throat(name + "n", end, lip="secondary", back=back, scale=0.78, depth=0.05, mirror=True)


def slab(z0, y0, z1, y1, yb):
    """Blade pod: a slab-sided, flat-topped upright fin standing clear of the body, with a bronze spine
    along its top and a bronze band low on the flank at the height of the sill edge, so one line runs from
    the front lamp to the rear nozzles. Top runs straight from y0 at z0 to y1 at z1."""
    d = dict(cx=BX, w=BW, yb=yb, rb=0.06, tum=0.0, drop=0.0, wcf=0.7, d2=0.0, crown=0.0, cs=0.0)
    pod = Hull([(z0, dict(yt=y0)), (z1, dict(yt=y1))], ys=BAND[1], **d)
    u = 2.0 + (BAND[0] - yb - 0.06) / (BAND[1] - yb - 0.06)
    pod.build("skin", "primary", mirror=True, regions=[R(z0, z1, 5.0, 6.0, "secondary", -0.05),
                                                        R(z0, z1, u, 3.0, "secondary", 0.0, side=1)])
    return pod


def plinth(stations, yb):
    """Dark buttress that carries a blade off the body: full sill height at the sill end, falling away
    towards the far end so the blade stands free above it."""
    Hull(stations, cx=4.56, w=0.46, yb=yb, ys=-0.9, rb=0.03, tum=0.0, drop=0.0, wcf=0.7, d2=0.0, crown=0.0,
         cs=0.0).build("plinth", "detail", mirror=True)


def e_fpod():
    """Front blade: lower than the bonnet, its whole leading edge a vertical lamp, the jet an upright slot
    high on its rear face (set shallow: the blade is solid behind it). A dark plinth at the base carries it off the body and covers the sill end."""
    K.begin("E", "FPOD")
    pod = slab(-12.85, 2.3, POD_FZ, 2.5, -1.25)
    blade("lamp", BX, -0.95, 2.0, -12.85, -1, "lights", w=0.2)
    port("jet", POD_FZ - 0.3, POD_FZ + 0.08, BX, 1.8, 0.3, 0.5, "max", "thrust")
    plinth([(-10.6, dict(yt=-0.5)), (-7.6, dict(yt=1.1)), (POD_FZ, dict(yt=1.1))], -1.25)
    flange(-10.0, -6.2, -0.3, 1.0)
    lift_glow(pod, [(-11.6, -7.4)])


def e_rpod():
    """Rear blade: the same fin, a little taller but below the deck, ending in an upright bronze frame that
    holds two rounded-rectangle nozzles one above the other. An intake slot on its front face."""
    K.begin("E", "RPOD")
    pod = slab(POD_RZ, 2.85, 11.3, 3.0, -1.3)
    port("intake", POD_RZ - 0.08, POD_RZ + 0.3, BX, 2.0, 0.3, 0.55, "min", "detail")
    Loft([(11.3, {}), (11.6, {})], cx=BX, w=BW + 0.12, yb=-1.4, yt=3.12, nt=6, nb=6, yw=0.5).build(
        "frame", "secondary", mirror=True)
    for i, y in enumerate((1.81, -0.09)):
        barrel(f"barrel{i}", 10.9, 12.15, BX, y, 0.37, depth=0.25, collar=False, ry=0.8, n=4.5)
    plinth([(POD_RZ, dict(yt=1.1)), (5.6, dict(yt=1.1)), (9.4, dict(yt=-0.5))], -1.3)
    flange(4.2, 9.0, -0.3, 1.0)
    lift_glow(pod, [(5.2, 10.0)])


def e_stab():
    """Sill: a low, thin, flat dark plank between the blade bases with a bronze outer edge, and three slim
    pipes grouped on a body-colour root block, swept back and down."""
    K.begin("E", "STAB")
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    sill = Hull([(z0, {}), (z1, {})], cx=5.0, w=0.9, yb=-1.2, yt=BAND[1], ys=BAND[0], rb=0.08, tum=0.0, drop=0.0,
                wcf=0.7, d2=0.0, crown=0.0, cs=0.0)
    sill.build("skin", "detail", mirror=True, regions=[R(z0, z1, 3.0, 4.0, "secondary", 0.0, side=1)])
    Hull([(-2.5, {}), (0.1, {})], cx=4.6, w=0.5, yb=-0.62, yt=0.0, ys=-0.35, rb=0.03, tum=0.2, drop=0.0, tumi=0.0,
         wcf=0.7, d2=0.0, crown=0.0, cs=0.0).build("root", "primary", mirror=True)
    for i, z in enumerate((-2.1, -1.3, -0.5)):
        bazooka(f"pipe{i}", 4.9, 6.5, z, -0.22, 0.24, back=0.9, down=0.6, wide=0.9, flat=1.25, n=3.5)
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
    """Boot lip that kicks up into a thin ducktail edge, in the secondary colour."""
    K.begin("E", "WING")
    Hull([(10.6, dict(yt=3.3)), (11.5, dict(yt=3.4)), (12.0, dict(yt=3.62, yb=3.2, ys=3.3)),
          (12.45, dict(w=3.4, yb=3.82, ys=3.88, yt=4.02))], w=3.46, yb=3.05, ys=3.1, rb=0.02, tum=0.1, drop=0.12,
         wcf=0.72, d2=0.03, crown=0.03).build(
             "lip", "secondary", regions=[R(10.6, 11.1, 1.0, 6.0, "primary", 0.0)])


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
