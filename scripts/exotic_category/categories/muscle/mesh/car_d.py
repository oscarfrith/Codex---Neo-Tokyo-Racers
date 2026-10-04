"""Car D: Stallion (muscle_04), after the Ford Mustang GT fastback (2024, S650). STD, GT and EVO trims.

Design language of D: long bonnet and a fastback roof that falls in one line down the longest rear glass of
the six, small triangular quarter window over an upswept beltline, forward-leaning shark nose with a wide
hexagonal grille, twin racing stripes over bonnet, roof and deck, tri-bar lamps front and rear, low pedestal
spoiler. Pods are "exposed barrels": short round cowls from which bare round metal barrels run on (one along
each front flank, two stacked behind each rear cowl), a slim sill rail with one big megaphone under it, and
two wide-set overdrive tips. The round metal tube is the theme.

Kits, "road-race thoroughbred": the round tube is multiplied and enlarged. Every barrel gains a megaphone
bell in GT; EVO adds barrels (two per front flank, three per rear pod, three sill megaphones on a collector,
four overdrive tips). The bonnet gains a striped ram-air scoop (GT), then a polished trumpet barrel (EVO).
Stripes spread to the cowls, the tail panel and a ducktail; the wing grows to a racing wing on round struts.
"""
import exokit as K
import musclekit as M
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, Z_F, Z_R
from muscle_cars import LINE, LVL, TRIMS, build_car, flange, pick, tub, tube, xtube

# Twin stripes: one band each side of the centre line (ring range on the top panels). The roof is narrower
# than the body, so its band starts further out along the ring to stay in line with bonnet and deck.
STRIPE = (5.4, 5.8)
ROOF_STRIPE = (5.3, 5.78)


def slant_bar(name, x, y0, y1, z0, z1, w, lean, ch):
    """Short upright light bar that leans outboard toward its top."""
    Loft([(y0, dict(cx=x)), (y1, dict(cx=x + lean))], axis="y", w=w, yb=z0, yt=z1, nt=5, nb=5,
         yw=0.5).build(name, ch, mirror=True)


def pipe(name, z0, z1, x, y, r, depth=0.6):
    """The round bare-metal barrel of this car: a tube firing backwards that ends in a rolled lip with a
    glowing throat. Front pod, rear pod and overdrive all use it."""
    lip = dict(w=r * 1.1, yb=y - r * 1.1, yt=y + r * 1.1)
    t = Loft([(z0, {}), (z1 - 0.6, {}), (z1 - 0.32, lip), (z1, lip)], cx=x, w=r, yb=y - r, yt=y + r, nt=2, nb=2,
             yw=0.5)
    t.build(name, "metal", mirror=True, caps=(True, False))
    t.throat(name + "n", "max", lip="metal", back="thrust", scale=0.84, depth=depth, mirror=True)


def horn(name, za, zb, x, y, r0, r1, flare=1.0, depth=0.45, back="thrust", bore="detail"):
    """Kit version of the barrel: a round metal tube from za to zb that opens into a megaphone bell at zb.
    The glow is a plate set inside the bell, as on the sill megaphone."""
    d = 1 if zb > za else -1
    ln = min(flare, abs(zb - za) - 0.05)

    def at(z, k=1.0):
        s = max(0.0, 1.0 - abs(zb - z) / ln)
        r = (r0 + (r1 - r0) * s ** 2.2) * k
        return (z, dict(w=r, yb=y - r, yt=y + r))
    kw = dict(cx=x, nt=2, nb=2, yw=0.5)
    m = x != 0
    zs = [za] + [zb - d * ln * (1 - i / 6) for i in range(7)]
    Loft([at(z) for z in zs], **kw).build(name, "metal", mirror=m, caps=(d > 0, d < 0), step=0.3)
    zi = zb - d * depth
    Loft([at(zi - d * 0.04, 0.86), at(zi, 0.86)], **kw).build(name + "glow", back, mirror=m)
    Loft([at(zi, 0.86), at(zb, 1.0)], **kw).build(name + "bore", bore, mirror=m, caps=(False, False))


def megaphone(name, x0, x1, z, y, r0, r1, back=0.9, down=0.5):
    """Drift thruster: a round tube with a bold bell mouth, swept back and down."""
    def at(x, k):
        s = (x - x0) / (x1 - x0)
        r = (r0 + (r1 - r0) * s ** 2.2) * k
        yc = y - down * s
        return (x, dict(cx=z + back * s, w=r, yb=yc - r, yt=yc + r))
    kw = dict(axis="x", nt=2, nb=2, yw=0.5)
    xs = [x0 + (x1 - x0) * i / 8 for i in range(9)]
    Loft([at(x, 1.0) for x in xs], **kw).build(name, "metal", mirror=True, caps=(True, False), step=0.2)
    Loft([at(x1 - 0.42, 0.84), at(x1 - 0.38, 0.84)], **kw).build(name + "glow", "thrust", mirror=True)
    Loft([at(x1 - 0.38, 0.84), at(x1, 0.92)], **kw).build(name + "bore", "detail", mirror=True, caps=(False, False))


def top_u(hull, t, x):
    """Ring value on the top panel of a Hull (4 to 6) that lies at half width x."""
    lo, hi = 4.0, 6.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if hull._pt(t, (1, mid))[0] > x:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


# Where the twin stripes lie across the car, so kit parts of another width carry them in line.
_REF = Hull([(0.0, SEAM_F), (1.0, SEAM_F)])
SX = (_REF._pt(0.0, (1, STRIPE[0]))[0], _REF._pt(0.0, (1, STRIPE[1]))[0])


def stripe_on(hull, t):
    return (top_u(hull, t, SX[0]), top_u(hull, t, SX[1]))


# Cowl paint: body colour over a dark belly, with one white pinstripe along the outboard edge of the belly.
COWL = dict(nt=2.6, nb=5, yw=0.45)


def cowl_regions(z0, z1):
    return [R(z0, z1, 198.0, 338.0, "detail", 0.0),
            R(z0 + 0.3, z1 - 0.3, 338.0, 343.0, "secondary", 0.0)]


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


def d_nose(trim):
    """Shark nose: the bonnet edge leads, the hexagonal grille sits under it and the bumper is set back.
    Twin stripes and two heat-extractor vents. GT: ram-air scoop with a round mouth, chin splitter.
    EVO: polished trumpet barrel through the bonnet, deeper splitter on stays, bonnet pins."""
    K.begin("D", "NOSE", trim)
    lv = LVL[trim]
    nose = Hull([(-12.3, dict(w=3.4, yb=0.2, yt=2.5, ys=2.0, rb=0.25, tum=0.3, drop=0.2)),
                 (-11.4, dict(w=3.75, yb=-0.15, yt=2.66, ys=2.1, rb=0.35)),
                 (-9.2, dict(w=3.9, yt=2.95, ys=2.28)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(True, False), regions=[
        R(-12.3, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.6, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-12.3, Z_F - GAP, STRIPE[0], STRIPE[1], "secondary", 0.02),
        R(-8.9, -7.2, 4.72, 5.12, "detail", 0.05)])       # heat-extractor vent, one each side
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
    if lv == 0:
        Loft([(-13.0, dict(w=2.9)), (-12.5, dict(w=3.5)), (-11.2, dict(w=3.8))], yb=-0.5, yt=-0.38, nt=5,
             nb=5).build("chin", "detail")
        return
    # chin splitter: a wide flat blade ahead of the bumper; deeper in EVO, on round stays, with end fences
    zf = pick(trim, 0, -13.65, -13.95)
    Loft([(zf, dict(w=pick(trim, 0, 3.3, 3.55))), (zf + 0.7, dict(w=3.85)), (-11.0, dict(w=3.9))], yb=-0.64,
         yt=-0.5, nt=5, nb=5).build("splitter", "detail")
    if lv == 2:
        box("fence", (3.82, -0.3, -12.6), (0.1, 0.7, 1.9), "detail", mirror=True)
        for i, x in enumerate((1.3, 2.6)):
            Loft([(-0.55, dict(yb=-13.62, yt=-13.48)), (0.5, dict(yb=-12.72, yt=-12.58))], axis="y", cx=x, w=0.07,
                 nt=2, nb=2, yw=0.5).build(f"stay{i}", "metal", mirror=True)
        # bonnet pins
        Loft([(2.2, {}), (2.62, {})], axis="y", cx=2.55, w=0.1, yb=-11.9, yt=-11.7, nt=2, nb=2,
             yw=0.5).build("pin", "metal", mirror=True)
    if lv == 1:
        # ram-air scoop in body colour: the stripes run over it, a round polished mouth in its face
        sc = Hull([(-9.6, dict(yt=3.84, ys=3.5)), (-8.6, dict(yt=4.0, ys=3.58)), (-5.5, dict(yt=3.3, ys=3.1))],
                  w=1.5, yb=2.75, rb=0.05, tum=0.22, drop=0.14, wcf=0.72, d2=0.04, crown=0.05)
        u0, u1 = stripe_on(sc, -8.0)
        sc.build("scoop", "primary", regions=[R(-9.6, -5.5, u0, u1, "secondary", 0.0)])
        m = tube(-10.0, -9.5, 0.0, 3.42, 0.46)
        m.build("scoopring", "metal", caps=(False, True))
        m.throat("scoopmouth", "min", lip="metal", wall="detail", back="detail", scale=0.86, depth=0.4)
    else:
        # the ram-air turbine: a polished barrel standing through the bonnet, flared trumpet mouth
        y = 3.86
        box("turbinebase", (0, 3.0, -8.0), (1.25, 0.6, 3.2), "detail")
        horn("turbine", -6.1, -10.75, 0.0, y, 0.8, 1.1, flare=1.2, depth=1.1, back="detail", bore="metal")
        tube(-8.5, -8.2, 0.0, y, 0.87).build("turbineband", "detail")
        Loft([(-10.3, dict(w=0.05, yb=y - 0.05, yt=y + 0.05)), (-9.6, dict(w=0.36, yb=y - 0.36, yt=y + 0.36))],
             cx=0.0, nt=2, nb=2, yw=0.5).build("turbinehub", "metal")


def d_fpod(trim):
    """Exposed barrel: a short round cowl carries the tri-bar lamp; behind it one bare barrel runs back
    along the flank, half sunk in a slim fender, and exits at the pod's rear face. GT: megaphone tip and a
    white stripe over the cowl. EVO: two megaphone barrels on a heat shield and a second lamp row."""
    K.begin("D", "FPOD", trim)
    lv = LVL[trim]
    regs = cowl_regions(-12.7, -9.3)
    if lv:
        regs.append(R(-12.35, -9.5, 81.0, 99.0, "secondary", 0.0))
    cowl = Loft([(-12.7, dict(cx=5.38, w=1.2, yb=-0.75, yt=1.7)), (-12.2, dict(yb=-1.05, yt=1.98)),
                 (-10.8, dict(w=1.32, yb=-1.18, yt=2.3)), (-9.3, dict(yb=-1.2, yt=2.22))], cx=5.4, w=1.3, **COWL)
    cowl.build("cowl", "primary", mirror=True, caps=(True, False), step=0.3, regions=regs)
    cowl.throat("cowlend", "max", lip="primary", wall="detail", back="detail", scale=0.93, depth=0.5, mirror=True)
    # slim fender behind the cowl: it closes the sill end and holds the barrel in its outboard side
    core = Hull([(-9.75, {}), (POD_FZ, {})], creases=(), cx=5.0, w=0.9, yb=-1.25, yt=1.62, ys=1.0, rb=0.35,
                tum=0.3, drop=0.22, wcf=0.7, d2=0.03, crown=0.06, cs=0.03)
    core.build("core", "primary", mirror=True, caps=(True, True), regions=[
        R(-9.75, POD_FZ, 0.0, 2.0, "detail", 0.0)])
    if lv == 0:
        pipe("barrel", -9.75, POD_FZ + 0.08, 5.82, 0.5, 0.76)
    elif lv == 1:
        horn("barrel", -9.75, POD_FZ + 0.08, 5.9, 0.5, 0.74, 1.0, flare=1.3)
    else:
        box("shield", (5.95, 0.42, -7.75), (0.12, 2.9, 3.1), "detail", mirror=True)
        for i, y in enumerate((1.1, -0.26)):
            horn(f"barrel{i}", -9.7, POD_FZ + 0.08, 6.12, y, 0.54, 0.67, flare=1.0, depth=0.4)
    Loft([(-12.8, {}), (-12.6, {})], cx=5.38, w=0.84, yb=0.28, yt=1.36, nt=5, nb=5, yw=0.5).build(
        "lamppanel", "detail", mirror=True)
    for i, x in enumerate((4.82, 5.3, 5.78)):
        slant_bar(f"bar{i}", x, 0.42, 1.22, -12.9, -12.7, 0.11, 0.16, "lights")
    if lv == 2:
        Loft([(-12.8, {}), (-12.6, {})], cx=5.38, w=0.84, yb=-0.56, yt=0.16, nt=5, nb=5, yw=0.5).build(
            "lamppanel2", "detail", mirror=True)
        for i, x in enumerate((4.82, 5.3, 5.78)):
            slant_bar(f"lowbar{i}", x, -0.44, 0.04, -12.9, -12.7, 0.11, 0.1, "lights")
    flange(-11.2, -6.4, -0.3, 1.5)
    cowl.patch("lift", -11.9, -10.0, 258.0, 282.0, "thrust", mirror=True)


def d_rpod(trim):
    """Exposed barrels: a short muscular cowl, widest over its middle, stops with a clean trailing edge;
    two large bare barrels, one above the other, run on from it to the tail. GT: megaphone ends and a metal
    brace. EVO: three megaphone barrels in a triangle and a small scoop on the cowl."""
    K.begin("D", "RPOD", trim)
    lv = LVL[trim]
    g = pick(trim, 0.0, 0.0, 0.1)
    cowl = Loft([(POD_RZ, dict(cx=5.2, w=1.1, yb=-1.35, yt=2.0)), (5.4, dict(cx=5.4, w=1.3, yt=2.82)),
                 (7.0, dict(cx=5.5, w=1.4 + g / 2, yb=-1.42, yt=3.1)), (8.6, dict(cx=5.42, w=1.32 + g, yt=3.02)),
                 (9.5, dict(cx=5.34, w=1.24 + g, yb=-1.34, yt=2.88))], cx=5.42, w=1.32, yb=-1.4, yt=3.0, **COWL)
    cowl.build("cowl", "primary", mirror=True, caps=(False, False), step=0.3, regions=cowl_regions(POD_RZ, 9.5))
    cowl.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.72, depth=0.5, mirror=True)
    cowl.throat("cowlend", "max", lip="primary", wall="detail", back="detail", scale=0.94, depth=0.6, mirror=True)
    px = pick(trim, 5.3, 5.3, 5.0)
    if lv == 0:
        for i, y in enumerate((-0.24, 1.74)):
            pipe(f"barrel{i}", 8.8, 12.6, 5.3, y, 0.94, depth=0.7)
    else:
        ys = pick(trim, 0, (-0.34, 1.84), (-0.32, 1.8))
        r0, r1 = pick(trim, 0, (0.78, 1.02), (0.76, 1.0))
        for i, y in enumerate(ys):
            horn(f"barrel{i}", 8.8, 12.75, px, y, r0, r1, flare=1.3, depth=0.55)
        if lv == 2:
            horn("barrel2", 8.9, 11.5, 6.07, 0.74, 0.58, 0.74, flare=1.0, depth=0.45)
        # metal brace: a clamp band round the stacked pair and a round stay to the body
        zb = 11.0
        Loft([(zb, {}), (zb + 0.3, {})], cx=px, w=r0 + 0.1, yb=ys[0] - r0 - 0.1, yt=ys[1] + r0 + 0.1, nt=4, nb=4,
             yw=0.5).build("brace", "metal", mirror=True)
        xtube(3.95, px, 11.15, ys[1] + 0.1, 0.13).build("stay", "metal", mirror=True)
    if lv == 2:
        sc = Loft([(5.9, dict(yt=3.6)), (6.8, dict(yt=3.62)), (8.6, dict(yt=3.1, w=0.4))], cx=5.5, w=0.5, yb=2.7,
                  nt=2.4, nb=2.4, yw=0.5)
        sc.build("scoop", "primary", mirror=True, caps=(False, True))
        sc.throat("scoopin", "min", lip="primary", wall="detail", back="detail", scale=0.8, depth=0.5, mirror=True)
    # dark web between the barrels and a pylon to the body side
    box("web", (px, 0.75, pick(trim, 10.5, 10.2, 10.1)), (0.7, 0.5, pick(trim, 2.6, 2.0, 1.8)), "detail", mirror=True)
    box("pylon", (4.25, 0.75, 10.3), (0.6, 1.5, 2.2), "detail", mirror=True)
    flange(4.6, 9.3, -0.3, 2.0)
    cowl.patch("lift", 5.6, 8.6, 258.0, 282.0, "thrust", mirror=True)


def d_stab(trim):
    """Slim body-colour rail tucked up high against the body, with one big megaphone hanging below it,
    swept back and down. GT: two megaphones. EVO: three on a metal collector pipe along the rail."""
    K.begin("D", "STAB", trim)
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    rail = Hull([(z0, {}), (z1, {})], creases=(), cx=4.56, w=0.46, yb=0.3, yt=1.08, ys=0.8, rb=0.2, tum=0.16,
                drop=0.1, wcf=0.6, d2=0.0, crown=0.05, cs=0.04)
    rail.build("rail", "primary", mirror=True, regions=[
        R(z0, z1, 0.0, 2.0, "detail", 0.0),
        R(z0 + 0.3, z1 - 0.3, 2.0, 2.2, "secondary", 0.0, side=1)])
    if trim == "STD":
        megaphone("megaphone", 4.5, 6.85, -2.2, -0.02, 0.36, 0.95, back=1.3, down=0.52)
        return
    r0, r1 = pick(trim, 0, (0.34, 0.9), (0.32, 0.82))
    for i, z in enumerate(pick(trim, 0, (-3.7, 0.3), (-4.5, -1.7, 1.1))):
        megaphone(f"megaphone{i}", 4.5, 6.85, z, -0.02, r0, r1, back=1.3, down=0.52)
    if trim == "EVO":
        tube(z0 + 0.4, z1 - 0.4, 4.6, 0.0, 0.3).build("collector", "metal", mirror=True)


def d_tail(trim):
    """Deck with twin stripes to a concave dark tail panel under the deck lip, holding three upright red
    bars each side, over a body-colour bumper. GT: white band across the panel, diffuser strakes at the
    corners. EVO: a light bar joins the tri-bars, deeper diffuser with a floor."""
    K.begin("D", "TAIL", trim)
    lv = LVL[trim]
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
    if lv == 0:
        return
    box("band", (0, 2.73, 12.06), (3.1, pick(trim, 0, 0.3, 0.46), 0.1), "secondary")
    if lv == 2:
        box("lightbar", (0, 2.73, 12.14), (3.5, 0.13, 0.14), "lights_red")
    # diffuser: round-edged strakes under the tail corners, clear of the overdrive in the centre
    yb = pick(trim, 0, -0.6, -0.9)
    for i, x in enumerate(pick(trim, 0, (3.1, 3.62), (3.02, 3.42, 3.82))):
        Loft([(9.9, dict(yb=-0.5, yt=-0.2)), (11.0, dict(yb=yb, yt=0.9)), (11.6, dict(yt=1.5)),
              (12.75, dict(yt=1.56))], cx=x, w=0.075, yb=yb, yt=1.5, nt=2, nb=2, yw=0.5).build(
                  f"strake{i}", "primary", mirror=True)
    if lv == 2:
        Loft([(9.6, dict(w=3.9)), (12.6, dict(w=3.9)), (13.3, dict(w=3.7))], yb=-1.0, yt=-0.86, nt=5,
             nb=5).build("floor", "detail")


def d_boost(trim):
    """Two large round tips set wide apart in a valance under the bumper. GT: megaphone tips. EVO: four
    megaphone tips in two pairs."""
    K.begin("D", "BOOST", trim)
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.6, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "detail", regions=[
             R(10.8, 12.2, 1.7, 2.0, "secondary", 0.0), R(10.8, 12.2, 3.0, 4.0, "primary", 0.0)])
    if trim == "STD":
        pipe("barrel", 11.6, 13.2, 1.78, 0.42, 0.66, depth=0.55)
    elif trim == "GT":
        horn("barrel", 11.6, 13.3, 1.85, 0.42, 0.6, 0.9, flare=1.0)
    else:
        for i, x in enumerate((0.92, 2.24)):
            horn(f"barrel{i}", 11.6, 13.38, x, 0.42, 0.5, 0.66, flare=0.9, depth=0.4)


def d_wing(trim):
    """Low pedestal spoiler: a body-colour blade on two short feet, close to the boot lid. GT: a ducktail
    with a taller pedestal blade over it. EVO: the ducktail and a tall racing wing on two round struts."""
    K.begin("D", "WING", trim)
    lv = LVL[trim]
    if lv == 0:
        Hull([(11.3, dict(yb=3.76, yt=3.86, ys=3.81)), (12.5, dict(w=3.5, yb=3.84, yt=4.02, ys=3.92))], w=3.56,
             rb=0.02, tum=0.1, drop=0.03, wcf=0.72, d2=0.01, crown=0.03).build("blade", "primary", regions=[
                 R(11.3, 12.5, STRIPE[0], STRIPE[1], "secondary", 0.0)])
        box("foot", (2.5, 3.62, 11.9), (0.3, 0.42, 0.8), "primary", mirror=True)
        return
    duck = Hull([(10.2, dict(yb=2.95, yt=3.48, ys=3.2)), (11.4, dict(yb=2.95, yt=3.74, ys=3.36)),
                 (12.62, dict(w=3.5, yb=3.22, yt=4.12, ys=3.7))], w=3.56, rb=0.04, tum=0.22, drop=0.1, wcf=0.72,
                d2=0.04, crown=0.04)
    u0, u1 = stripe_on(duck, 11.4)
    duck.build("ducktail", "primary", regions=[R(10.2, 12.62, u0, u1, "secondary", 0.0)])
    if lv == 1:
        blade = Hull([(11.7, dict(yb=4.5, yt=4.6, ys=4.55)), (13.0, dict(w=3.6, yb=4.62, yt=4.82, ys=4.72))],
                     w=3.66, rb=0.02, tum=0.1, drop=0.03, wcf=0.72, d2=0.01, crown=0.03)
        u0, u1 = stripe_on(blade, 12.3)
        blade.build("blade", "primary", regions=[R(11.7, 13.0, u0, u1, "secondary", 0.0)])
        box("foot", (2.7, 3.9, 12.3), (0.3, 1.3, 0.8), "primary", mirror=True)
        return
    blade = Hull([(11.5, dict(yb=5.5, yt=5.64, ys=5.57)), (13.2, dict(w=4.5, yb=5.74, yt=6.0, ys=5.87))], w=4.6,
                 rb=0.03, tum=0.1, drop=0.04, wcf=0.72, d2=0.01, crown=0.04)
    u0, u1 = stripe_on(blade, 12.3)
    blade.build("blade", "primary", regions=[R(11.5, 13.2, u0, u1, "secondary", 0.0)])
    box("endplate", (4.6, 5.74, 12.4), (0.12, 0.8, 1.9), "primary", mirror=True)
    Loft([(2.9, dict(yb=11.45, yt=11.75)), (5.7, dict(yb=12.15, yt=12.45))], axis="y", cx=2.9, w=0.15, nt=2, nb=2,
         yw=0.5).build("strut", "metal", mirror=True)


def car_d():
    d_cockpit()
    for trim in TRIMS:
        d_nose(trim)
        d_tail(trim)
        d_fpod(trim)
        d_rpod(trim)
        d_stab(trim)
        d_boost(trim)
        d_wing(trim)


def build(out=None):
    return build_car("stallion", "D", car_d, out=out)
