"""Car D: Stallion (muscle_04), after the Ford Mustang GT fastback (2024, S650). STD trim.

Design language of D: long bonnet and a fastback roof that falls in one line down the longest rear glass of
the six, small triangular quarter window over an upswept beltline, forward-leaning shark nose with a wide
hexagonal grille, twin racing stripes over bonnet, roof and deck, one round turbine through the bonnet,
tri-bar lamps front and rear, low pedestal spoiler, smooth fenders with broad rear hips, and round nozzles
everywhere: two stacked on each rear pod, one flared megaphone in each sill, two wide-set overdrive tips.
"""
import exokit as K
import musclekit as M
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, POD_LINE, barrel, build_car, flange, lift_glow, tub, tube

# Twin stripes: one band each side of the centre line (ring range on the top panels). The roof is narrower
# than the body, so its band starts further out along the ring to stay in line with bonnet and deck.
STRIPE = (5.4, 5.8)
ROOF_STRIPE = (5.3, 5.78)


def slant_bar(name, x, y0, y1, z0, z1, w, lean, ch):
    """Short upright light bar that leans outboard toward its top."""
    Loft([(y0, dict(cx=x)), (y1, dict(cx=x + lean))], axis="y", w=w, yb=z0, yt=z1, nt=5, nb=5,
         yw=0.5).build(name, ch, mirror=True)


def megaphone(name, x0, x1, z, y, r0, r1, back=0.9, down=0.5):
    """Drift thruster: a round tube that widens toward its mouth, swept back and down."""
    def at(x, k):
        s = (x - x0) / (x1 - x0)
        r = (r0 + (r1 - r0) * s ** 1.6) * k
        yc = y - down * s
        return (x, dict(cx=z + back * s, w=r, yb=yc - r, yt=yc + r))
    kw = dict(axis="x", nt=2, nb=2, yw=0.5)
    xs = [x0 + (x1 - x0) * i / 5 for i in range(6)]
    Loft([at(x, 1.0) for x in xs], **kw).build(name, "metal", mirror=True, caps=(True, False))
    Loft([at(x1 - 0.42, 0.86), at(x1 - 0.38, 0.86)], **kw).build(name + "glow", "thrust", mirror=True)
    Loft([at(x1 - 0.38, 0.86), at(x1, 0.9)], **kw).build(name + "bore", "detail", mirror=True, caps=(False, False))


def d_pod_regions(z0, z1):
    return [R(z0 + 0.15, z1 - 0.15, 1.0, 2.0, "secondary", 0.02),
            R(z0 + 0.45, z1 - 0.25, POD_LINE[0], POD_LINE[1], "primary", 0.05, side=1)]


def d_cockpit():
    """Fastback: the roof peaks over the screen header and falls in one line to the deck. Against the
    Brawler the peak is further forward, the rear glass is twice as long and the beltline kicks up behind
    the door, so the quarter window is a small triangle."""
    K.begin("D", "COCKPIT")
    tub()
    gh = Hull([(-6.0, dict(w=3.52, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.6, dict(w=3.62, yt=4.42, tum=0.5, drop=0.16)),
               (-3.3, dict(w=3.64, yt=5.38, tum=0.7)),
               (-1.9, dict(w=3.64, yt=5.66, tum=0.74)),
               (0.0, dict(w=3.62, yt=5.6, tum=0.76)),
               (2.0, dict(w=3.56, yt=5.18, tum=0.8, ys=3.42)),
               (4.0, dict(w=3.48, yt=4.46, tum=0.78, ys=3.8)),
               (5.6, dict(w=3.4, yt=3.74, tum=0.55, drop=0.14, ys=3.42)),
               (6.6, dict(w=3.34, yb=3.15, yt=3.3, ys=3.2, tum=0.2, drop=0.03, crown=0.02))],
              w=3.64, yb=3.1, ys=3.3, rb=0.04, tum=0.72, drop=0.21, wcf=0.75, d2=0.045, crown=0.065)
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.5, 4.13, 6.0, "detail", 0.015),     # windscreen surround
        R(-5.75, -3.61, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.85, 4.0, 3.04, 3.88, "detail", 0.015),     # side glass surround, one opening
        R(-4.74, -0.28, 3.085, 3.835, "glass", 0.04),   # door glass
        R(0.04, 3.88, 3.085, 3.835, "glass", 0.04),     # quarter glass, tapers to a point
        R(0.9, 6.2, 4.14, 6.0, "detail", 0.015),        # rear window surround
        R(1.0, 6.1, 4.195, 6.0, "glass", 0.04),         # rear window
        R(-3.1, 0.6, ROOF_STRIPE[0], ROOF_STRIPE[1], "secondary", 0.02)])


def d_nose():
    """Shark nose: the bonnet edge leads, the hexagonal grille sits under it and the bumper is set back.
    Twin stripes, one round turbine through the bonnet."""
    K.begin("D", "NOSE")
    nose = Hull([(-12.3, dict(w=3.4, yb=0.2, yt=2.5, ys=2.0, rb=0.25, tum=0.3, drop=0.2)),
                 (-11.4, dict(w=3.75, yb=-0.15, yt=2.66, ys=2.1, rb=0.35)),
                 (-9.2, dict(w=3.9, yt=2.95, ys=2.28)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(True, False), regions=[
        R(-12.3, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.6, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-12.3, Z_F - GAP, STRIPE[0], STRIPE[1], "secondary", 0.02)])
    # leading bonnet edge, well ahead of the grille
    Hull([(-13.3, dict(w=3.15, yb=2.14, yt=2.36, ys=2.22)), (-12.3, dict(w=3.4, yb=2.02, yt=2.5, ys=2.2))], rb=0.04,
         tum=0.28, drop=0.12, wcf=0.72, d2=0.03, crown=0.03).build("brow", "primary", regions=[
             R(-13.3, -12.3, STRIPE[0], STRIPE[1], "secondary", 0.0)])
    # hexagonal grille: a six-sided frame with a deep dark mouth
    hexa = Hull([(-12.95, dict(w=2.95)), (-12.2, dict(w=3.05))], yb=0.72, yt=2.06, rb=0.6, ys=1.44, tum=0.42,
                drop=0.0, wcf=0.7, d2=0.0, crown=0.0, cs=0.0)
    hexa.build("grille", "primary", caps=(False, True))
    hexa.throat("mouth", "min", lip="primary", wall="detail", back="detail", scale=0.9, depth=0.6)
    Hull([(-12.75, dict(w=3.1, yb=0.3, yt=0.74, ys=0.6)), (-12.3, dict(w=3.4, yb=0.2, yt=0.8, ys=0.62))], rb=0.2,
         tum=0.12, drop=0.08, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    Loft([(-13.0, dict(w=2.9)), (-12.5, dict(w=3.5)), (-11.2, dict(w=3.8))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "detail")
    # one round turbine through the bonnet
    y = 3.74
    box("turbinebase", (0, y - 0.66, -8.0), (1.3, 0.3, 2.4), "detail")
    t = Loft([(-9.8, dict(w=0.72, yb=y - 0.72, yt=y + 0.72)), (-9.2, {}), (-6.6, {})], cx=0.0, w=0.6, yb=y - 0.6,
             yt=y + 0.6, nt=2, nb=2, yw=0.5)
    t.build("turbine", "metal", caps=(False, True))
    t.throat("turbinein", "min", lip="metal", wall="detail", back="detail", scale=0.86, depth=0.7)
    tube(-9.6, -9.1, 0.0, y, 0.2).build("turbinehub", "metal")


def d_fpod():
    """Front fender, smooth on top, with the tri-bar lamp on its face."""
    K.begin("D", "FPOD")
    pod = Hull([(-12.7, dict(cx=5.38, w=1.2, yb=-0.75, yt=1.7, ys=1.15, rb=0.3, tum=0.25, drop=0.18)),
                (-12.2, dict(cx=5.4, w=1.28, yb=-1.05, yt=1.95, ys=1.35)),
                (-10.5, dict(w=1.32, yt=2.25)), (-8.0, dict(w=1.32, yt=2.4)),
                (POD_FZ, SIDE_F)], **SIDE_F)
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=d_pod_regions(-12.7, POD_FZ))
    pod.throat("noz", "max", lip="primary", back="thrust", scale=0.5, depth=0.6, mirror=True)
    Loft([(-12.8, {}), (-12.6, {})], cx=5.38, w=0.84, yb=0.28, yt=1.36, nt=5, nb=5, yw=0.5).build(
        "lamppanel", "detail", mirror=True)
    for i, x in enumerate((4.82, 5.3, 5.78)):
        slant_bar(f"bar{i}", x, 0.42, 1.22, -12.9, -12.7, 0.11, 0.16, "lights")
    flange(-11.2, -6.4, -0.3, 1.9)
    lift_glow(pod, [(-10.4, -7.4)])


def d_rpod():
    """Rear fender with broad hips, no taller than the deck, and two round nozzles one above the other."""
    K.begin("D", "RPOD")
    pod = Hull([(POD_RZ, SIDE_R), (5.6, dict(w=1.4, yb=-1.35, yt=2.88, ys=2.0)),
                (8.4, dict(w=1.5, yb=-1.35, yt=3.08, ys=2.15)), (10.2, dict(w=1.42, yb=-1.25, yt=2.95, ys=2.1)),
                (11.3, dict(cx=5.4, w=1.25, wi=1.25, yb=-0.9, yt=2.65, ys=1.9))], **dict(SIDE_R, wi=1.32))
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=d_pod_regions(POD_RZ, 11.3))
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    for i, y in enumerate((0.08, 1.6)):
        barrel(f"barrel{i}", 10.6, 12.4, 5.42, y, 0.68, depth=0.7, collar=False)
    flange(4.4, 10.6, -0.3, 2.1)
    lift_glow(pod, [(5.8, 9.6)])


def d_stab():
    """Sill unit with one flared megaphone that fires sideways, swept back and down."""
    K.begin("D", "STAB")
    sill = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.95, w=0.85, yb=-1.2, yt=1.0, ys=0.6, rb=0.3, tum=0.2,
                drop=0.12, wcf=0.6, d2=0.0, crown=0.04)
    sill.build("skin", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 1.0, 2.0, "secondary", 0.02)])
    megaphone("megaphone", 5.3, 6.82, -1.5, 0.15, 0.36, 0.84, back=1.0, down=0.55)
    lift_glow(sill, [(-5.0, -3.6), (1.6, 3.0)])


def d_tail():
    """Deck with twin stripes to a concave dark tail panel under the deck lip, holding three upright red
    bars each side, over a body-colour bumper."""
    K.begin("D", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.35)), (9.8, dict(yt=3.55, ys=2.7)), (10.6, dict(yb=-0.3)),
                 (11.3, dict(yb=1.4, rb=0.25)),
                 (12.0, dict(w=3.72, yb=1.5, yt=3.6, ys=2.85, rb=0.25, tum=0.28, drop=0.2))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 10.6, 0.0, 2.0, "secondary", 0.02),   # rocker stops where the floor kicks up
        R(Z_R + GAP, 11.6, LINE[0], LINE[1], "primary", 0.025),
        R(6.2, 12.0, STRIPE[0], STRIPE[1], "secondary", 0.02)])
    tail.cap("panel", "max", "detail")
    Hull([(12.0, dict(w=3.72, yb=3.12, yt=3.6, ys=3.3)), (12.45, dict(w=3.66, yb=3.2, yt=3.56, ys=3.34))], rb=0.04,
         tum=0.28, drop=0.18, wcf=0.72, d2=0.05, crown=0.05).build("decklip", "primary", regions=[
             R(12.0, 12.45, STRIPE[0], STRIPE[1], "secondary", 0.0)])
    Hull([(12.0, dict(w=3.72, yb=1.5, yt=2.32, ys=2.1)), (12.55, dict(w=3.62, yb=1.62, yt=2.26, ys=2.05))], rb=0.25,
         tum=0.12, drop=0.08, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    box("post", (3.52, 2.72, 12.2), (0.3, 0.86, 0.42), "primary", mirror=True)
    for i, x in enumerate((1.9, 2.4, 2.9)):
        slant_bar(f"lamp{i}", x, 2.42, 3.04, 12.05, 12.3, 0.17, 0.1, "lights_red")


def d_boost():
    """Two large round tips set wide apart in a valance under the bumper."""
    K.begin("D", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.6, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "detail", regions=[
             R(10.8, 12.2, 0.0, 2.0, "secondary", 0.0), R(10.8, 12.2, 3.0, 4.0, "primary", 0.0)])
    barrel("barrel", 11.6, 13.2, 1.78, 0.42, 0.7, depth=0.55, collar=False)


def d_wing():
    """Low pedestal spoiler: a body-colour blade on two short feet, close to the boot lid."""
    K.begin("D", "WING")
    Hull([(11.3, dict(yb=3.76, yt=3.86, ys=3.81)), (12.5, dict(w=3.5, yb=3.84, yt=4.02, ys=3.92))], w=3.56, rb=0.02,
         tum=0.1, drop=0.03, wcf=0.72, d2=0.01, crown=0.03).build("blade", "primary", regions=[
             R(11.3, 12.5, STRIPE[0], STRIPE[1], "secondary", 0.0)])
    box("foot", (2.5, 3.62, 11.9), (0.3, 0.42, 0.8), "primary", mirror=True)


def car_d():
    d_cockpit()
    d_nose()
    d_tail()
    d_fpod()
    d_rpod()
    d_stab()
    d_boost()
    d_wing()


def build(out=None):
    return build_car("stallion", "D", car_d, out=out)
