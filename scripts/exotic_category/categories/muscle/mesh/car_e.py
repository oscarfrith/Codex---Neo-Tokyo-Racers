"""Modern Muscle car E: Blackjack (muscle_05), after the Cadillac CT5-V Blackwing. STD, GT and EVO.

Design language of E: the formal, upright one. Three-box saloon (bonnet, cabin, long flat boot) with an
upright rear window, a tall shield grille that is wider at the top, a power dome, vertical blade lamps
front and rear, and every nozzle stacked or grouped vertically. Pods and sill are "vertical blades": tall,
narrow, slab-sided, flat-topped fins standing clear of the body with a bronze spine, joined at the base by a
thin dark plank.

Kit motif: carbon and bronze. Vertical fins, vertical vanes and stacked elements in dark carbon (detail)
with bronze edges; understated and precise.
"""
import exokit as K
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, LVL, TRIMS, barrel, bazooka, build_car, flange, lift_glow, pick, tub

BX, BW = 5.47, 0.47   # blade pods: centre and half width (x 5.0 to 5.94, clear of the body side)
BAND = (-0.86, -0.62)  # bronze band: the outer edge of the sill plank, carried along both blades


def blade(name, x, y0, y1, z, face, ch, w=0.13, mirror=True):
    """Vertical blade lamp: a slim upright strip in a dark bezel. face is -1 (front) or +1 (rear)."""
    Loft([(z, {}), (z + face * 0.06, {})], cx=x, w=w + 0.08, yb=y0 - 0.09, yt=y1 + 0.09, nt=5, nb=5,
         yw=0.5).build(name + "bezel", "detail", mirror=mirror)
    Loft([(z, {}), (z + face * 0.12, {})], cx=x, w=w, yb=y0, yt=y1, nt=5, nb=5, yw=0.5).build(
        name, ch, mirror=mirror)


def vfin(name, x, pts, t=0.1, edge=0.09, ch="detail", mirror=True):
    """Vertical carbon fin with a bronze edge all round: a thin bronze plate with a thicker, smaller dark
    plate over it. pts are (z, y bottom, y top). edge 0 gives a plain fin in ch."""
    kw = dict(cx=x, nt=6, nb=6, yw=0.5)
    if not edge:
        Loft([(z, dict(yb=a, yt=b)) for z, a, b in pts], w=t / 2, **kw).build(name, ch, mirror=mirror)
        return
    Loft([(z, dict(yb=a, yt=b)) for z, a, b in pts], w=t * 0.3, **kw).build(name + "e", "secondary", mirror=mirror)
    Loft([(z, dict(yb=a + edge, yt=b - edge)) for z, a, b in pts], w=t / 2, **kw).build(
        name, ch, mirror=mirror, t0=pts[0][0] + edge, t1=pts[-1][0] - edge)


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


def e_nose(trim):
    """Tall upright nose: a shield grille (wider at the top) between two body-colour cheeks, a lower intake
    in the bumper and a long power dome. STD: the plain dome. GT: twin bronze-edged slots in the dome and a
    carbon splitter on two vertical vanes. EVO: a low flat-topped turbine between the slots, a wider
    splitter with vertical end fins and bronze-edged vanes in the lower intake."""
    K.begin("E", "NOSE", trim)
    lv = LVL[trim]
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
    box("intake", (0, 0.3, -13.17), (3.4, pick(trim, 0.26, 0.26, 0.36), 0.08), "detail")
    Loft([(-13.5, dict(w=3.0)), (-12.9, dict(w=3.55)), (-11.2, dict(w=3.85))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "secondary")

    # power dome: follows the bonnet, grows out of it at the front and fades into the cowl
    def st(z, w, h):
        y = nose.params(z)["yt"]
        return (z, dict(w=w, yb=y - 0.2, ys=y - 0.06, yt=y + h))
    slots = [R(-9.78, -7.02, 4.4, 5.2, "secondary", 0.0), R(-9.6, -7.2, 4.55, 5.05, "detail", 0.05)] if lv else []
    Hull([st(-11.8, 0.7, 0.0), st(-10.8, 0.92, 0.13), st(-8.4, 1.2, 0.2), st(-6.8, 1.36, 0.19),
          st(-5.9, 1.44, -0.02)], rb=0.02, tum=0.2, drop=0.09, wcf=0.72, d2=0.015, crown=0.03).build(
              "dome", "primary", regions=slots)
    if lv:
        # carbon splitter under the chin; GT stands it on two short vertical vanes, EVO adds end fins
        Loft([(-13.82, dict(w=pick(trim, 0, 3.2, 3.45))), (-13.0, dict(w=pick(trim, 0, 3.75, 3.9))),
              (-11.0, dict(w=3.92))], yb=pick(trim, 0, -0.68, -0.74), yt=-0.52, nt=5, nb=5).build(
                  "splitter", "detail")
        for i, x in enumerate(pick(trim, (), (2.3,), (1.2, 2.5))):
            box(f"vane{i}", (x, -0.26, -13.36), (0.09, 0.56, 0.72), "detail", mirror=True)
            box(f"vaneedge{i}", (x, -0.26, -13.74), (0.09, 0.56, 0.05), "secondary", mirror=True)
    if lv == 2:
        vfin("endfin", 3.82, [(-13.8, -0.74, -0.1), (-13.0, -0.74, 0.52), (-11.5, -0.74, 0.52)], t=0.12, edge=0.08)
        for i, x in enumerate((0.3, 0.9, 1.5)):
            box(f"slat{i}", (x, 0.3, -13.27), (0.08, 0.36, 0.14), "detail", mirror=True)
            box(f"slatedge{i}", (x, 0.3, -13.36), (0.08, 0.36, 0.05), "secondary", mirror=True)
        # turbine: a slim, long, flat-topped housing set low into the dome between the slots
        tb = Hull([(-10.0, dict(w=0.42, yt=3.6, ys=3.44)), (-9.2, dict(w=0.42, yt=3.7, ys=3.52)),
                   (-7.3, dict(w=0.42, yt=3.74, ys=3.56)), (-6.2, dict(w=0.3, yt=3.48, ys=3.36))], yb=2.95,
                  rb=0.02, tum=0.05, drop=0.04, wcf=0.8, d2=0.0, crown=0.0, cs=0.0)
        tb.build("turbine", "primary", caps=(False, True), regions=[R(-9.3, -6.9, 4.5, 6.0, "detail", 0.02)])
        tb.throat("turbinen", "min", lip="secondary", wall="detail", back="metal", scale=0.78, depth=0.45)


def port(name, z0, z1, x, y, r, ry, end, back):
    """Upright slot in a bronze frame on a blade end face: a jet (back thrust) or an intake (back detail)."""
    t = Loft([(z0, {}), (z1, {})], cx=x, w=r, yb=y - ry, yt=y + ry, nt=4.5, nb=4.5, yw=0.5)
    t.build(name, "secondary", mirror=True, caps=(False, False))
    t.throat(name + "n", end, lip="secondary", back=back, scale=0.78, depth=0.05, mirror=True)


def slab(z0, y0, z1, y1, yb, flank=()):
    """Blade pod: a slab-sided, flat-topped upright fin standing clear of the body, with a bronze spine
    along its top and a bronze band low on the flank at the height of the sill edge, so one line runs from
    the front lamp to the rear nozzles. Top runs straight from y0 at z0 to y1 at z1.
    flank: (z a, z b, y a, y b, channel, depth) panels cut into the outboard face."""
    d = dict(cx=BX, w=BW, yb=yb, rb=0.06, tum=0.0, drop=0.0, wcf=0.7, d2=0.0, crown=0.0, cs=0.0)
    pod = Hull([(z0, dict(yt=y0)), (z1, dict(yt=y1))], ys=BAND[1], **d)
    u = 2.0 + (BAND[0] - yb - 0.06) / (BAND[1] - yb - 0.06)
    regs = [R(z0, z1, 5.0, 6.0, "secondary", -0.05), R(z0, z1, u, 3.0, "secondary", 0.0, side=1)]
    for za, zb, ya, yc, ch, depth in flank:
        top = y0 + (y1 - y0) * ((za + zb) / 2 - z0) / (z1 - z0)
        regs.append(R(za, zb, 3.0 + (ya - BAND[1]) / (top - BAND[1]), 3.0 + (yc - BAND[1]) / (top - BAND[1]), ch,
                      depth, side=1))
    pod.build("skin", "primary", mirror=True, regions=regs)
    return pod


def plinth(stations, yb):
    """Dark buttress that carries a blade off the body: full sill height at the sill end, falling away
    towards the far end so the blade stands free above it."""
    Hull(stations, cx=4.56, w=0.46, yb=yb, ys=-0.9, rb=0.03, tum=0.0, drop=0.0, wcf=0.7, d2=0.0, crown=0.0,
         cs=0.0).build("plinth", "detail", mirror=True)


def e_fpod(trim):
    """Front blade: lower than the bonnet, its whole leading edge a vertical lamp, the jet an upright slot
    high on its rear face (set shallow: the blade is solid behind it). A dark plinth at the base carries it
    off the body and covers the sill end. GT: a second vertical light blade on the flank behind the first
    and a carbon vertical vane standing off the flank. EVO: a tall bronze spine fin and a column of three
    short vertical vents."""
    K.begin("E", "FPOD", trim)
    lv = LVL[trim]
    flank = []
    if lv:
        flank += [(-12.42, -12.0, -0.42, 2.0, "detail", 0.03), (-12.3, -12.12, -0.3, 1.88, "lights", 0.03)]
    if lv == 2:
        flank += [(-8.3, -7.95, y, y + 0.55, "detail", 0.06) for y in (1.5, 0.75, 0.0)]
    pod = slab(-12.85, 2.3, POD_FZ, 2.5, -1.25, flank)
    blade("lamp", BX, -0.95, 2.0, -12.85, -1, "lights", w=0.2)
    port("jet", POD_FZ - 0.3, POD_FZ + 0.08, BX, 1.8, 0.3, 0.5, "max", "thrust")
    plinth([(-10.6, dict(yt=-0.5)), (-7.6, dict(yt=1.1)), (POD_FZ, dict(yt=1.1))], -1.25)
    flange(-10.0, -6.2, -0.3, 1.0)
    lift_glow(pod, [(-11.6, -7.4)])
    if lv:
        vfin("vane", 6.3, [(-11.6, 0.3, 1.5), (-11.3, -0.35, 1.95), (-10.9, -0.35, 1.95)], t=0.1,
             edge=pick(trim, 0, 0, 0.08))
        for i, y in enumerate((1.55, 0.05)):
            box(f"strut{i}", (6.1, y, -11.15), (0.4, 0.07, 0.4), "detail", mirror=True)
    if lv == 2:
        Loft([(-12.4, dict(yt=2.42)), (-9.4, dict(yt=2.95)), (-6.1, dict(yt=3.2))], cx=BX, w=0.07, yb=2.25, nt=6,
             nb=6, yw=0.5).build("fin", "secondary", mirror=True)


def e_rpod(trim):
    """Rear blade: the same fin, a little taller but below the deck, ending in an upright bronze frame that
    holds rounded-rectangle nozzles one above the other (two, three in GT, four in EVO). An intake slot on
    its front face. GT adds two tall vertical vents ahead of the frame; EVO a vertical tail fin on the
    spine."""
    K.begin("E", "RPOD", trim)
    lv = LVL[trim]
    flank = [(z, z + 0.3, 0.0, 2.3, "detail", 0.06) for z in ((9.5, 10.2) if lv else ())]
    pod = slab(POD_RZ, 2.85, 11.3, 3.0, -1.3, flank)
    port("intake", POD_RZ - 0.08, POD_RZ + 0.3, BX, 2.0, 0.3, 0.55, "min", "detail")
    Loft([(11.3, {}), (pick(trim, 11.6, 11.6, 11.75), {})], cx=BX, w=BW + 0.12, yb=-1.4, yt=3.12, nt=6, nb=6,
         yw=0.5).build("frame", "secondary", mirror=True)
    ys, ry = pick(trim, ((1.81, -0.09), 0.8), ((2.16, 0.86, -0.44), 0.52), ((2.39, 1.37, 0.35, -0.67), 0.4))
    for i, y in enumerate(ys):
        barrel(f"barrel{i}", 10.9, pick(trim, 12.15, 12.15, 12.45), BX, y, 0.37, depth=0.25, collar=False, ry=ry,
               n=4.5)
    plinth([(POD_RZ, dict(yt=1.1)), (5.6, dict(yt=1.1)), (9.4, dict(yt=-0.5))], -1.3)
    flange(4.2, 9.0, -0.3, 1.0)
    lift_glow(pod, [(5.2, 10.0)])
    if lv == 2:
        vfin("fin", BX, [(8.0, 2.8, 3.2), (10.2, 2.8, 3.85), (11.7, 2.8, 3.95)], t=0.12, edge=0.09)


def e_stab(trim):
    """Sill: a low, thin, flat dark plank between the blade bases with a bronze outer edge, and slim pipes
    grouped on a body-colour root block, swept back and down (three, four in GT, five in EVO). GT stands a
    carbon skirt with a bronze edge on the plank either side of the pipes; EVO makes it deeper and ribs it
    with vertical bronze vanes."""
    K.begin("E", "STAB", trim)
    lv = LVL[trim]
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    sill = Hull([(z0, {}), (z1, {})], cx=5.0, w=0.9, yb=-1.2, yt=BAND[1], ys=BAND[0], rb=0.08, tum=0.0, drop=0.0,
                wcf=0.7, d2=0.0, crown=0.0, cs=0.0)
    sill.build("skin", "detail", mirror=True, regions=[R(z0, z1, 3.0, 4.0, "secondary", 0.0, side=1)])
    zs = pick(trim, (-2.1, -1.3, -0.5), (-2.5, -1.8, -1.1, -0.4), (-2.8, -2.1, -1.4, -0.7, 0.0))
    Hull([(zs[0] - 0.4, {}), (zs[-1] + 0.6, {})], cx=4.6, w=0.5, yb=-0.62, yt=0.0, ys=-0.35, rb=0.03, tum=0.2,
         drop=0.0, tumi=0.0, wcf=0.7, d2=0.0, crown=0.0, cs=0.0).build("root", "primary", mirror=True)
    for i, z in enumerate(zs):
        bazooka(f"pipe{i}", 4.9, 6.5, z, -0.22, pick(trim, 0.24, 0.21, 0.19), back=0.9, down=0.6, wide=0.9,
                flat=1.25, n=3.5)
    lift_glow(sill, [(-5.0, -3.6), (1.6, 3.0)])
    if lv:
        top = pick(trim, 0, 0.1, 0.72)
        for k, (a, b) in enumerate(((z0, zs[0] - 0.55), (zs[-1] + 1.45, z1))):
            m = (a + b) / 2
            box(f"skirt{k}", (5.72, (top + BAND[1]) / 2, m), (0.3, top - BAND[1], b - a), "detail", mirror=True)
            box(f"skirtcap{k}", (5.72, top + 0.035, m), (0.34, 0.07, b - a), "secondary", mirror=True)
            if lv == 2:
                n = int((b - a - 0.4) / 0.42)
                for j in range(n + 1):
                    box(f"rib{k}{j}", (5.88, (top + BAND[1]) / 2, a + 0.2 + (b - a - 0.4) * j / n),
                        (0.06, top - BAND[1], 0.07), "secondary", mirror=True)


def e_tail(trim):
    """Long flat boot to an upright tail: a tall red blade lamp at each outer edge, a clean body-colour
    panel between them and a dark lower valance. GT: a carbon diffuser floor with tall vertical strakes
    under each corner. EVO: a deeper diffuser, three bronze-edged strakes a side and a third, centre
    vertical brake light."""
    K.begin("E", "TAIL", trim)
    lv = LVL[trim]
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
    if lv:
        # diffuser: a carbon floor that leaves the body floor and runs under the overdrive, with vertical
        # strakes in the corners outboard of it
        ze = pick(trim, 0, 13.1, 13.35)
        yb = pick(trim, 0, -0.98, -1.05)
        Loft([(9.9, dict(w=3.5, yb=-0.62, yt=-0.5)), (10.7, dict(w=3.7, yb=yb, yt=-0.86)),
              (ze, dict(w=3.9, yb=yb, yt=-0.86))], nt=6, nb=6, yw=0.5).build("diffuser", "detail")
        top = pick(trim, 0, 0.9, 1.02)
        for i, x in enumerate(pick(trim, (), (3.08, 3.8), (3.0, 3.42, 3.84))):
            vfin(f"strake{i}", x, [(10.5, -0.95, -0.2), (11.5, -0.95, top), (ze, -0.95, top)], t=0.1,
                 edge=pick(trim, 0, 0, 0.07))
    if lv == 2:
        blade("lamp3", 0.0, 2.0, 3.0, 12.1, 1, "lights_red", w=0.14, mirror=False)


def e_boost(trim):
    """Stacked tips in a dark valance: four in two stacked pairs, each pair in a bronze bezel; GT six in two
    stacked rows of three in one bronze bezel; EVO eight slim tips in a longer, bronze-framed carbon
    housing."""
    K.begin("E", "BOOST", trim)
    lv = LVL[trim]
    ze = pick(trim, 12.2, 12.2, 12.55)
    Hull([(10.8, dict(w=2.85)), (ze, dict(w=pick(trim, 2.55, 2.55, 2.6), yb=pick(trim, -0.25, -0.25, -0.45)))],
         yb=pick(trim, -0.45, -0.45, -0.6), yt=pick(trim, 1.3, 1.3, 1.38), rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "detail", regions=[
             R(10.8, ze, 3.0, 3.6, "primary", 0.0)])
    if lv == 0:
        Loft([(12.2, {}), (12.32, {})], cx=0.86, w=0.72, yb=-0.14, yt=1.2, nt=5, nb=5, yw=0.5).build(
            "bezel", "secondary", mirror=True)
        xs, r = (0.86,), 0.52
    elif lv == 1:
        Loft([(12.2, {}), (12.32, {})], w=1.9, yb=-0.14, yt=1.2, nt=6, nb=6, yw=0.5).build("bezel", "secondary")
        xs, r = (0.0, 1.22), 0.5
    else:
        fr = Loft([(ze - 0.1, {}), (ze + 0.22, {})], w=2.3, yb=-0.36, yt=1.3, nt=6, nb=6, yw=0.5)
        fr.build("frame", "secondary", caps=(False, False))
        fr.throat("framen", "max", lip="secondary", wall="detail", back="detail", scale=0.92, depth=0.25)
        xs, r = (0.5, 1.5), 0.4
    for j, x in enumerate(xs):
        for i, y in enumerate((0.86, 0.2) if lv < 2 else (0.82, 0.14)):
            barrel(f"tip{j}{i}", 11.6, pick(trim, 13.0, 13.0, 13.3), x, y, r, depth=0.5, collar=False, ry=0.27,
                   n=4.5)


def e_wing(trim):
    """Boot lip that kicks up into a thin ducktail edge, in the secondary colour. GT: a taller carbon lip
    with bronze end caps. EVO: a tall blade wing on two vertical carbon uprights with large vertical
    bronze-edged end plates, over the carbon lip."""
    K.begin("E", "WING", trim)
    lv = LVL[trim]
    Hull([(10.6, dict(yt=3.3)), (11.5, dict(yt=3.4)), (12.0, dict(yt=pick(trim, 3.62, 3.72, 3.62), yb=3.2, ys=3.3)),
          pick(trim, (12.45, dict(w=3.4, yb=3.82, ys=3.88, yt=4.02)), (12.65, dict(w=3.4, yb=4.32, ys=4.4, yt=4.58)),
               (12.45, dict(w=3.4, yb=3.82, ys=3.88, yt=4.02)))], w=3.46, yb=3.05, ys=3.1, rb=0.02, tum=0.1,
         drop=0.12, wcf=0.72, d2=0.03, crown=0.03).build(
             "lip", pick(trim, "secondary", "detail"), regions=[R(10.6, 11.1, 1.0, 6.0, "primary", 0.0)])
    if lv == 1:
        Loft([(11.4, dict(yb=2.9, yt=4.0)), (12.1, dict(yb=2.9, yt=4.72)), (12.85, dict(yb=3.9, yt=4.72))], cx=3.44,
             w=0.07, nt=6, nb=6, yw=0.5).build("cap", "secondary", mirror=True)
    if lv == 2:
        box("upright", (2.95, 4.1, 11.95), (0.14, 2.5, 0.75), "detail", mirror=True)
        Loft([(-3.75, {}), (3.75, {})], axis="x", cx=12.0, w=0.8, yb=5.14, yt=5.46, nt=2.2, nb=2.2, yw=0.6).build(
            "blade", "primary")
        vfin("plate", 3.8, [(10.8, 4.75, 5.6), (11.6, 4.25, 6.0), (13.2, 4.25, 6.0)], t=0.14, edge=0.1)


def car_e():
    e_cockpit()
    for trim in TRIMS:
        e_nose(trim)
        e_tail(trim)
        e_fpod(trim)
        e_rpod(trim)
        e_stab(trim)
        e_boost(trim)
        e_wing(trim)


def build(out=None):
    return build_car("blackjack", "E", car_e, out=out)
