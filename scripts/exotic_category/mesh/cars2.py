"""Exotic cars C, D, E and F: the remaining four cockpits, on the same frame standard as cars A and B.

  C  exotic_01  clean concept coupe: long smooth prow, wide flat glasshouse, disc shells, slot burner.
                Fenders: low, peak far forward at the front; a late muscular haunch and low tail at the rear.
  D  exotic_03  rounded wraparound-visor supercar: roof scoop, triple lamps, stacked ring tail lamps,
                one large central burner. Fenders: low soft front; tall early rear haunch with a long
                teardrop taper to a small nozzle.
  E  exotic_04  faceted endurance car: braced glass dome, blunt wide nose, four-point lamps,
                full-width tail light bar, twin round turbines. Fenders: flat-topped prototype boxes
                that hold their height to a tall square end.
  F  exotic_06  aero hypercar: narrow fuselage with side tunnels, roof snorkel, pontoon fenders with
                outline accents, open tail, twin hexagonal burners. Fenders: tall narrow peaks that
                fall away sharply behind the front arch; the tallest rear pontoons.

All four keep the flowing fender-over-arch construction of cars A and B; they differ in profile.

Each has three versions per slot (STD road car, GT race kit, EVO full kit), built by cars.py helpers.
"""
import exokit as K
from exokit import GAP, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Hull, Loft, R, box
from cars import (LVL, TRIMS, blade, burner, canard, dfin, fender_kit, fender_regions, flange, flared, lift_glow,
                  louvres, plane, race_wing, rect, shell, slab, tube)


# ---------------------------------------------------------------- shared builders

def tub(extra=()):
    Hull([(-5.2, SEAM_F), (-1.0, dict(SEAM_F, yt=2.35)), (2.8, SEAM_R)]).build(
        "tub", "primary", t0=-5.2 + GAP, t1=2.8 - GAP,
        regions=[R(-5.2 + GAP, 2.8 - GAP, 0.0, 1.9, "secondary", 0.02), *extra])
    Hull([(-5.28, SEAM_F), (-1.0, dict(SEAM_F, yt=2.35)), (2.88, SEAM_R)]).build("liner", "detail", scale=0.96)


def fender(st, peak, trim, front, style, creases=(1, 2, 3, 4), caps=(False, False), archw=1.7, vent=None,
           extra=(), shell_kw=None, slats=False, reach=2.2, ups=(0, 0.1, 0.2)):
    """Engine fender over a dark arch: rocker, arch, optional louvred top vent, shell, kit hardware."""
    lvl = LVL[trim]
    pod = Hull(flared(st, peak, (0, 0.3, 0.5)[lvl], ups[lvl], reach), creases=creases, **style)
    z0, z1 = st[0][0], st[-1][0]
    regs = [R(z0 + 0.3, z1 - 0.2, 1.0, (2.05, 2.3, 2.6)[lvl], "secondary", 0.02),
            R(peak - archw, peak + archw, 1.25, 2.92, "detail", 0.33, side=1)]
    v = vent[lvl] if vent else None
    if v:
        regs.append(R(peak + v[0], peak + v[1], v[2], v[3], "detail", 0.13, side=1))
    regs += fender_regions(peak, lvl, front) + list(extra)
    pod.build("skin", "primary", mirror=True, caps=caps, regions=regs)
    if v:
        louvres(pod, "top", peak + v[0] + 0.1, peak + v[1] - 0.1, v[2] + 0.06, v[3] - 0.06, v[4], off=-0.05)
    if slats:
        for i in range(4):
            t = peak - (archw - 0.12 - i * 0.13)
            pod.patch(f"arch{i}", t - 0.03, t + 0.03, 1.4, 2.85, "secondary", off=-0.18, mirror=True)
    if shell_kw:
        shell(pod, peak, bars=(1, 2, 2)[lvl], **shell_kw)
    fender_kit(pod, peak, lvl, front)
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])
    return pod, lvl


def front_aero(lvl, tip, cx=5.12, nt=5.0, y=0.35):
    """Splitter corner under a front fender, with an endplate and dive planes on the kits."""
    reach = tip - (0.0, 0.6, 1.0)[lvl]
    slab("splitter", [(reach, 0.5 + lvl * 0.4), (reach + 0.35, 1.1 + lvl * 0.25), (-10.9, 1.35 + lvl * 0.2)],
         -0.54, -0.42, "secondary", cx=cx + lvl * 0.1, nt=nt, mirror=True)
    if lvl:
        blade("endplate", 6.5 + lvl * 0.12, -0.5, (0.25, 0.3, 0.5)[lvl], (reach + 0.3, -10.9), (reach + 0.8, -11.0),
              "secondary", t=0.04)
        canard("canard0", 6.1, 6.9, -11.5, -10.2, y, y + 0.45)
    if lvl > 1:
        canard("canard1", 6.2, 6.95, -11.1, -9.9, y + 0.6, y + 1.1)


def nose_splitter(lvl, tip, w0, w1, nt=5.0):
    reach = tip - (0.1, 0.6, 0.85)[lvl]
    slab("splitter", [(reach, min(w0 + lvl * 0.4, 3.8)), (reach + 0.4, min(w1 + lvl * 0.25, 3.82)),
                      (-11.6, 3.5 + lvl * 0.14), (-10.8, 3.8)],
         -0.54, -0.42, "secondary", nt=nt)
    for i, x in enumerate((0.8, 1.9, 3.0)[:lvl + 1] if lvl else ()):
        box(f"keel{i}", (x, -0.66, -11.8), (0.05, 0.24, 1.5), "detail", mirror=True)


def rear_kit(pod, lvl, scoop=None):
    """Corner diffuser strakes under a rear nozzle, and a ram scoop on the haunch for the full kit."""
    if lvl:
        for i, x in enumerate((4.6, 5.3, 6.0)[:lvl + 1]):
            dfin(f"corner{i}", x, ((9.6, -0.5), (10.6, -0.1), (11.7 + lvl * 0.2, 0.3)))
    if lvl > 1 and scoop:
        y, nt = scoop
        s = Loft([(5.4, dict(w=0.42, yt=y + 0.45)), (6.6, dict(w=0.5, yt=y + 0.72)), (8.2, dict(w=0.3, yt=y + 0.5))],
                 cx=5.3, yb=y, nt=nt, nb=nt, yw=0.3)
        s.build("scoop", "primary", mirror=True, caps=(False, True))
        s.throat("scoopin", "min", lip="primary", scale=0.78, depth=0.4, mirror=True)


def tail_kit(lvl, std_fins, floor_w=3.7, nt=5.0, fin_ch="primary", fin=True):
    """Diffuser: short strakes on the road car; a floor that runs out past the tail on the kits."""
    if lvl == 0:
        for i, x in enumerate(std_fins):
            dfin(f"fin{i}", x, ((9.4, -0.32), (10.4, 0.0), (11.3, 0.3)))
        return
    back = (0, 12.3, 12.75)[lvl]
    slab("floor", [(9.0, floor_w), (back - 0.4, floor_w + 0.1), (back, floor_w - 0.2)], -0.5, -0.42, "secondary", nt=nt)
    for i, x in enumerate(((), (2.75, 3.25, 3.7), (2.7, 3.05, 3.4, 3.75))[lvl]):
        dfin(f"fin{i}", x, ((9.2, -0.3), (10.6, 0.25), (back, 0.55 + lvl * 0.12)))
    blade("sideplate", 3.8, -0.45, 0.6 + lvl * 0.1, (10.2, back), (11.0, back), "secondary", t=0.04)
    if lvl > 1 and fin:
        blade("fin", 0, 2.4, 3.85, (6.6, 10.2), (9.0, 10.25), fin_ch, t=0.06)


def sill(trim, st, style, creases=(1, 2, 3, 4), intake=(0.5, -0.6, -1.6), neon=True, extra=(), cx=4.9, w=1.0):
    lvl = LVL[trim]
    hull = Hull(st, creases=creases, cx=cx, w=w, yb=-0.9, **style)
    start = intake[lvl]
    regs = [R(-5.2, 3.4, 1.0, (2.25, 2.6, 2.95)[lvl], "secondary", 0.02),
            R(start, 3.15, 3.1, 3.9, "detail", 0.15, side=1), *extra]
    if neon:
        regs.append(R(-5.0, 3.2, 2.3, 2.38, "neon", -0.01, side=1))
    hull.build("skin", "primary", mirror=True, regions=regs)
    louvres(hull, "intake", start + 0.1, 3.05, 3.15, 3.85, max(3, int((3.05 - start) / 0.42)), off=-0.08)
    out = (6.1, 6.55, 6.85)[lvl]
    slab("skirt", [(-5.1, (out - 4.6) / 2 - 0.15), (-3.6, (out - 4.6) / 2), (3.3, (out - 4.6) / 2)], -1.0, -0.92,
         "secondary", cx=(out + 4.6) / 2, mirror=True)
    if lvl:
        blade("kick", out - 0.05, -0.95, 0.5 + lvl * 0.35, (1.6, 3.35), (2.5, 3.4), "secondary", t=0.04)
    if lvl > 1:
        for i, x in enumerate((6.1, 6.6)):
            blade(f"barge{i}", x, -0.95, 0.55 - i * 0.2, (-5.0, -3.4), (-4.7, -3.9), "secondary", t=0.04)
    lift_glow(hull, [(-4.2, -2.4), (-0.6, 1.4)])
    return hull


SILL_ST = [(-5.2, dict(yb=-0.8, yt=0.4, ys=0.0)), (-2.0, dict(yt=0.65, ys=0.15)), (1.5, dict(yt=1.3, ys=0.7)),
           (3.4, dict(yb=-0.7, yt=1.55, ys=0.9))]


def ring_lamp(name, x, y, z0, z1, r, ch="lights_red"):
    """Round lamp that reads as a ring: lit lens with a dark centre."""
    t = tube(z0, z1, x, y, r)
    t.build(name, "secondary", mirror=True, caps=(True, False))
    t.throat(name + "l", "max", lip="secondary", back=ch, scale=0.82, depth=0.06, mirror=True)
    t.cap(name + "c", "max", "detail", scale=0.42, push=-0.04, mirror=True)


# ---------------------------------------------------------------- car C: clean concept coupe

C_POD = dict(rb=0.45, tum=0.5, drop=0.3, tumi=0.03, dropi=0.12, wcf=0.4, d2=0.03, crown=0.11)
C_VENT = (None, (-1.3, 0.9, 4.15, 5.1, 5), (-1.5, 1.1, 4.1, 5.3, 6))


def car_c():
    c = "C"
    K.begin(c, "COCKPIT")
    tub()
    can = Loft([(-6.7, dict(w=2.2, yb=1.8, yt=2.08)), (-4.6, dict(w=3.0, yt=3.2)), (-2.2, dict(w=3.25, yt=4.1)),
                (0.0, dict(w=3.25, yt=4.25)), (2.2, dict(w=3.1, yt=4.05)), (5.0, dict(w=2.6, yb=2.15, yt=3.3)),
                (7.3, dict(w=1.6, yb=2.3, yt=2.7))], yb=1.95, yw=0.1, nt=3.2, nb=3.0)
    can.build("canopy", "primary", regions=[R(-6.3, 2.5, 8, 172, "glass", 0.03),
                                            R(2.9, 6.9, 62, 118, "secondary", 0.02)])
    for trim in TRIMS:
        lvl = LVL[trim]
        K.begin(c, "NOSE", trim)
        nose = Hull([(-12.6, dict(w=1.2, yb=0.15, yt=0.5, rb=0.1, ys=0.3, tum=0.15, drop=0.08)),
                     (-12.0, dict(w=2.6, yb=0.0, yt=0.72, rb=0.2, ys=0.38, tum=0.25, drop=0.15)),
                     (-11.0, dict(w=3.5, yb=-0.3, yt=0.98, rb=0.35, ys=0.5, tum=0.35, drop=0.25)),
                     (-8.5, dict(w=3.8, yt=1.4, ys=0.8, tum=0.4, drop=0.32)),
                     (-6.6, dict(w=3.8, yt=1.9, ys=1.15, tum=0.36, drop=0.3, crown=0.06)), (-5.2, SEAM_F)],
                    creases=(1, 2, 3), yb=-0.4, rb=0.5, wcf=0.15, d2=0.1, crown=0.1)
        regs = [R(-12.5, -10.4, 2.84, 2.98, "lights", -0.01), R(-12.3, -10.6, 0.3, 2.2, "secondary", 0.02)]
        if lvl:
            regs.append(R(-9.8, -7.3, 4.2, 4.95, "detail", 0.16))
        nose.build("skin", "primary", t1=-5.2 - GAP, regions=regs)
        if lvl:
            louvres(nose, "hood", -9.7, -7.4, 4.25, 4.9, 5 + lvl, off=-0.08)
        jaw = Loft([(-12.1, dict(w=1.9)), (-11.6, dict(w=2.9)), (-10.5, dict(w=3.5))], yb=-0.4, yt=0.3, nt=5, nb=5)
        jaw.build("jaw", "secondary", caps=(False, True))
        jaw.throat("grille", "min", lip="secondary", scale=0.88, depth=0.5)
        nose_splitter(lvl, -12.6, 1.4, 2.6)

        K.begin(c, "FPOD", trim)
        st = [(-12.0, dict(cx=5.0, w=0.5, wi=0.5, yb=0.2, yt=0.9, ys=0.5, rb=0.15, tum=0.15, drop=0.1, dropi=0.1)),
              (-11.4, dict(cx=5.02, w=0.95, wi=0.85, yb=-0.3, yt=1.4, ys=0.65)),
              (-10.3, dict(cx=5.12, w=1.24, wi=1.04, yb=-0.9, yt=1.92, ys=0.92)),
              (-9.1, dict(cx=5.17, w=1.3, wi=1.12, yb=-1.1, yt=2.08, ys=1.02)),
              (-7.2, dict(cx=5.12, w=1.2, wi=1.12, yb=-0.95, yt=1.6, ys=0.85)),
              (-5.4, dict(SIDE_F, yb=-0.1, yt=1.15, ys=0.6, rb=0.2))]
        pod, _ = fender(st, -8.9, trim, True, C_POD, creases=(1, 2), caps=(True, False), vent=C_VENT,
                        extra=[R(-11.7, -9.8, 2.84, 2.96, "lights", -0.01, side=1)],
                        shell_kw=dict(half=1.3, y0=-0.85, y1=0.95, nt=2.0))
        box("blade", (4.35, 0.35, -11.5), (0.1, 0.8, 0.12), "lights", mirror=True)
        pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.78, 0.84, 0.88)[lvl], depth=0.5, mirror=True)
        front_aero(lvl, -12.05, nt=4.0)
        flange(-10.6, -5.6, 0.5)

        K.begin(c, "TAIL", trim)
        tail = Hull([(2.8, SEAM_R), (5.5, dict(yt=2.58, crown=0.1)),
                     (8.6, dict(yt=2.5, ys=1.45, tum=0.4, drop=0.35)), (10.0, dict(yb=0.0, yt=2.45, ys=1.5)),
                     (11.2, dict(w=3.7, yb=0.4, yt=(2.4, 2.55, 2.7)[lvl], ys=1.55, tum=0.45, drop=0.35, rb=0.5))],
                    creases=(1, 2, 3), **{**SEAM_R, "crown": 0.1})
        regs = [R(8.6, 11.2, 0.0, 2.3, "secondary", 0.02)]
        if lvl:
            regs.append(R(6.0, 10.2, 4.2, 4.9, "detail", 0.14))
        tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=regs)
        if lvl:
            louvres(tail, "deck", 6.1, 10.1, 4.25, 4.85, 8, off=-0.07)
        tail.throat("fascia", "max", lip="primary", scale=0.92, depth=0.25)
        box("strip", (0, 2.08, 11.0), (6.5, 0.07, 0.14), "lights_red")
        tail_kit(lvl, (2.9,), nt=4.0)

        K.begin(c, "RPOD", trim)
        st = [(3.6, dict(SIDE_R, yb=-0.5, yt=1.4)),
              (5.0, dict(cx=5.12, w=1.2, wi=1.18, yb=-1.0, yt=1.7, ys=1.0)),
              (6.8, dict(cx=5.19, w=1.3, wi=1.22, yb=-1.1, yt=2.35, ys=1.4)),
              (8.2, dict(cx=5.19, w=1.3, wi=1.22, yb=-1.1, yt=2.62, ys=1.55)),
              (9.6, dict(cx=5.14, w=1.22, wi=1.2, yb=-1.0, yt=2.3, ys=1.4)),
              (10.6, dict(cx=5.05, w=1.0, wi=1.03, yb=-0.6, yt=1.85, ys=1.1))]
        pod, _ = fender(st, 8.0, trim, False, C_POD, creases=(1, 2), vent=C_VENT,
                        shell_kw=dict(half=1.3, y0=-0.85, y1=0.95, nt=2.0), reach=3.0, ups=(0, 0.15, 0.3))
        pod.throat("intake", "min", lip="primary", scale=0.8, depth=0.5, mirror=True)
        pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.8, 0.85, 0.9)[lvl], depth=0.5, mirror=True)
        rear_kit(pod, lvl)
        flange(3.8, 10.3, 1.0)

        K.begin(c, "STAB", trim)
        sill(trim, SILL_ST, dict(rb=0.35, tum=0.4, drop=0.2, wcf=0.4, d2=0.03, crown=0.1), creases=(1, 2),
             intake=(1.4, 0.2, -1.0))

        K.begin(c, "BOOST", trim)
        rect([(10.8, {}), (11.5, {})], 0, 2.1, 0.4, 1.3 + lvl * 0.12, c=0.2).build("shroud", "primary")
        box("panel", (0, 0.85, 10.98), (4.6, 1.5, 0.1), "detail")
        for i in range(1 + (lvl > 1)):
            y = 0.85 + (0.0 if lvl < 2 else (0.3 if i == 0 else -0.5))
            t = Loft([(11.2, {}), (12.0 + lvl * 0.15, {})], cx=0, w=1.55 + lvl * 0.12, yb=y - 0.28, yt=y + 0.28, nt=5,
                     nb=5, yw=0.5)
            t.build(f"burner{i}", "secondary", caps=(True, False))
            t.throat(f"noz{i}", "max", lip="secondary", back="thrust", scale=0.86, depth=0.3)

        K.begin(c, "WING", trim)
        if lvl == 0:   # clean lip on two stubs
            plane("lip", 3.6, 10.95, 0.35, 2.74, 2.86, "primary", tip=(11.05, 0.28))
            blade("stub", 2.6, 1.25, 2.78, (10.5, 11.1), (10.7, 11.2), "secondary")
        elif lvl == 1:
            race_wing(4.6, 11.2, 0.85, 4.3, 2.8, plate=(3.6, 4.8))
        else:
            race_wing(6.2, 11.3, 0.95, 4.9, 2.8, elements=2, plate=(3.1, 5.75), beam=True)


# ---------------------------------------------------------------- car D: wraparound-visor supercar

D_POD = dict(rb=0.4, tum=0.48, drop=0.3, tumi=0.03, dropi=0.12, wcf=0.5, d2=0.04, crown=0.09)
D_VENT = ((-0.9, 0.5, 4.2, 4.9, 3), (-1.3, 0.9, 4.15, 5.15, 5), (-1.5, 1.1, 4.1, 5.35, 6))


def car_d():
    c = "D"
    K.begin(c, "COCKPIT")
    tub([R(-4.2, 2.2, 2.15, 2.9, "primary", 0.16)])
    can = Hull([(-6.7, dict(w=2.7, yb=1.8, yt=2.1, ys=2.0, tum=0.3, drop=0.02)),
                (-4.6, dict(w=3.25, yt=3.2, tum=0.8)), (-2.4, dict(yt=4.1)), (-0.4, dict(yt=4.3)),
                (1.6, dict(w=3.2, yt=4.2)), (4.2, dict(w=2.8, yb=2.2, yt=3.5, ys=2.35)),
                (7.2, dict(w=2.0, yb=2.35, yt=2.7, ys=2.5, tum=0.6, drop=0.1))],
               creases=(3,), w=3.3, yb=1.9, ys=2.2, rb=0.1, tum=1.2, drop=0.3, wcf=0.6, d2=0.03, crown=0.12)
    can.build("canopy", "primary", regions=[R(-6.45, 0.8, 3.06, 6.0, "glass", 0.03),
                                            R(2.0, 5.6, 3.15, 3.8, "glass", 0.03),
                                            R(3.4, 6.6, 4.6, 6.0, "glass", 0.03)])
    s = Loft([(-0.2, dict(w=0.5, yt=4.6)), (1.2, dict(w=0.6, yt=4.8)), (3.2, dict(w=0.35, yt=4.25))], yb=4.0,
             nt=2.6, nb=2.6, yw=0.3)
    s.build("scoop", "primary", caps=(False, True))
    s.throat("scoopin", "min", lip="primary", scale=0.8, depth=0.4)
    for trim in TRIMS:
        lvl = LVL[trim]
        K.begin(c, "NOSE", trim)
        nose = Hull([(-12.3, dict(w=2.2, yb=0.0, yt=0.62, rb=0.2, ys=0.32, tum=0.3, drop=0.15)),
                     (-11.6, dict(w=3.2, yb=-0.2, yt=0.9, rb=0.35, ys=0.45, tum=0.4, drop=0.25)),
                     (-10.4, dict(w=3.7, yt=1.15, ys=0.58, tum=0.42, drop=0.3)),
                     (-8.5, dict(w=3.8, yt=1.5, ys=0.85, tum=0.42, drop=0.32)),
                     (-6.6, dict(w=3.8, yt=1.92, ys=1.15, tum=0.36, drop=0.3)), (-5.2, SEAM_F)],
                    creases=(1, 2, 3), yb=-0.4, rb=0.5, wcf=0.5, d2=0.05, crown=0.1)
        vent = ((-9.3, -8.3, 5.0, 5.6, 3), (-10.0, -7.6, 4.3, 5.6, 6), (-10.3, -7.2, 4.2, 5.65, 8))[lvl]
        nose.build("skin", "primary", t1=-5.2 - GAP, caps=(False, True), regions=[
            R(vent[0], vent[1], vent[2], vent[3], "detail", 0.15), R(-12.2, -10.6, 0.3, 2.2, "secondary", 0.02)])
        louvres(nose, "hood", vent[0] + 0.08, vent[1] - 0.08, vent[2] + 0.05, vent[3] - 0.05, vent[4], off=-0.08)
        nose.throat("mouth", "min", lip="primary", scale=0.8, depth=0.5)
        duct = Loft([(-12.0, dict(w=0.9)), (-10.6, dict(w=1.2))], cx=2.2, yb=-0.38, yt=0.22, nt=2.6, nb=2.6, yw=0.5)
        duct.build("duct", "secondary", mirror=True, caps=(False, True))
        duct.throat("ductin", "min", lip="secondary", scale=0.84, depth=0.5, mirror=True)
        nose_splitter(lvl, -12.3, 2.4, 3.3, nt=4.0)

        K.begin(c, "FPOD", trim)
        st = [(-12.1, dict(cx=4.95, w=0.6, wi=0.6, yb=0.1, yt=0.85, ys=0.45, rb=0.15, tum=0.2, drop=0.12, dropi=0.1)),
              (-11.4, dict(cx=5.02, w=1.0, wi=0.9, yb=-0.4, yt=1.4, ys=0.65)),
              (-10.2, dict(cx=5.1, w=1.22, wi=1.05, yb=-0.9, yt=1.85, ys=0.9)),
              (-8.2, dict(cx=5.17, w=1.3, wi=1.12, yb=-1.1, yt=2.1, ys=1.05)),
              (-6.8, dict(cx=5.12, w=1.22, wi=1.12, yb=-0.95, yt=1.95, ys=1.0)),
              (-5.4, dict(SIDE_F, yb=-0.1, yt=1.5, ys=0.75, rb=0.2))]
        pod, _ = fender(st, -8.2, trim, True, D_POD, creases=(1, 2, 3), caps=(True, False), vent=D_VENT,
                        archw=1.8, extra=[R(-11.75, -10.45, 3.4, 4.6, "glass", 0.1, side=1)],
                        shell_kw=dict(half=1.45, y0=-0.75, y1=0.8, nt=3.0))
        for i, t in enumerate((-11.62, -11.22, -10.84)):
            pod.patch(f"lamp{i}", t, t + 0.26, 3.75, 4.3, "lights", off=-0.05, mirror=True)
        pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.78, 0.84, 0.88)[lvl], depth=0.5, mirror=True)
        front_aero(lvl, -12.1, nt=4.0)
        flange(-10.4, -5.6, 0.5)

        K.begin(c, "TAIL", trim)
        tail = Hull([(2.8, SEAM_R), (5.5, dict(yt=2.6, crown=0.1)),
                     (8.6, dict(w=3.78, yt=2.5, ys=1.45, tum=0.5, drop=0.4)),
                     (10.2, dict(yb=0.0, yt=2.4, ys=1.45, tum=0.55, drop=0.45, rb=0.6)),
                     (11.2, dict(w=3.65, yb=0.4, yt=(2.3, 2.45, 2.6)[lvl], ys=1.4, tum=0.6, drop=0.45, rb=0.7))],
                    creases=(1, 2, 3), **{**SEAM_R, "crown": 0.1})
        deck = (6.6, 5.6, 4.8)[lvl]
        tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
            R(8.6, 11.2, 0.0, 2.3, "secondary", 0.02), R(deck, 10.2, 4.2, 4.9, "detail", 0.14)])
        louvres(tail, "deck", deck + 0.1, 10.1, 4.25, 4.85, 7 + lvl * 2, off=-0.07)
        tail.throat("fascia", "max", lip="primary", scale=0.9, depth=0.25)
        for i, y in enumerate((0.85, 1.3, 1.75)):
            ring_lamp(f"ring{i}", 3.0, y, 10.96, 11.2, 0.19)
        tail_kit(lvl, (2.8, 3.2), nt=4.0)

        K.begin(c, "RPOD", trim)
        st = [(3.6, dict(SIDE_R, yb=-0.5, yt=1.7)),
              (4.8, dict(cx=5.12, w=1.25, wi=1.18, yb=-1.0, yt=2.5, ys=1.3)),
              (6.2, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.95, ys=1.6)),
              (7.8, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.8, ys=1.55)),
              (9.4, dict(cx=5.12, w=1.15, wi=1.15, yb=-0.9, yt=2.3, ys=1.3)),
              (10.6, dict(cx=5.05, w=0.92, wi=0.95, yb=-0.4, yt=1.8, ys=1.05))]
        pod, _ = fender(st, 6.8, trim, False, D_POD, creases=(1, 2, 3), vent=D_VENT, archw=1.8,
                        shell_kw=dict(half=1.45, y0=-0.75, y1=0.8, nt=3.0), slats=True, reach=3.0, ups=(0, 0.15, 0.3))
        pod.throat("intake", "min", lip="primary", scale=0.8, depth=0.5, mirror=True)
        pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.82, 0.86, 0.9)[lvl], depth=0.6, mirror=True)
        rear_kit(pod, lvl)
        flange(3.8, 10.3, 1.0)

        K.begin(c, "STAB", trim)
        sill(trim, SILL_ST, dict(rb=0.3, tum=0.4, drop=0.2, wcf=0.45, d2=0.03, crown=0.09), creases=(1, 2, 3),
             intake=(-1.0, -1.8, -2.6), neon=False)

        K.begin(c, "BOOST", trim)
        Loft([(10.8, dict(w=1.05)), (11.55, dict(w=0.95, yb=0.12, yt=1.92))], yb=0.05, yt=2.0, nt=2, nb=2,
             yw=0.5).build("shroud", "primary")
        burner("core", 11.2, 12.1 + lvl * 0.15, 0, 1.0, (0.6, 0.68, 0.72)[lvl])
        if lvl == 1:
            burner("side", 11.1, 11.9, 1.5, 1.0, 0.24)
        elif lvl == 2:
            burner("side", 11.1, 12.1, 1.6, 1.0, 0.4)
        box("keel", (0, -0.15, 11.2 + lvl * 0.2), (0.1, 0.5, 0.9 + lvl * 0.4), "secondary")

        K.begin(c, "WING", trim)
        if lvl == 0:   # modest wing on two pylons
            plane("plane", 3.5, 11.0, 0.6, 3.3, 3.45, "primary", tip=(11.1, 0.48))
            blade("pylon", 2.6, 1.25, 3.34, (10.3, 11.1), (10.7, 11.3), "secondary")
            blade("plate", 3.52, 3.1, 3.7, (10.6, 11.6), (10.8, 11.75), "secondary", t=0.05)
        elif lvl == 1:
            race_wing(4.8, 11.2, 0.9, 4.6, 2.6, plate=(3.8, 5.1))
        else:
            race_wing(6.4, 11.3, 1.0, 5.05, 2.6, elements=2, plate=(3.2, 5.9), beam=True)


# ---------------------------------------------------------------- car E: faceted endurance car

E_POD = dict(rb=0.6, tum=0.2, drop=0.12, tumi=0.03, dropi=0.08, wcf=0.7, d2=0.02, crown=0.01, cs=0.0)
E_VENT = (None, (-1.2, 0.8, 4.15, 5.2, 4), (-1.4, 1.0, 4.1, 5.4, 5))


def car_e():
    c = "E"
    K.begin(c, "COCKPIT")
    tub([R(-4.3, 2.0, 2.2, 2.88, "secondary", 0.08)])
    can = Loft([(-6.7, dict(w=2.1, yb=1.8, yt=2.08)), (-4.8, dict(w=2.9, yt=3.15)), (-2.6, dict(w=3.15, yt=4.0)),
                (-0.6, dict(w=3.15, yt=4.2)), (1.6, dict(w=2.9, yt=4.0)), (4.0, dict(w=2.3, yb=2.15, yt=3.3)),
                (6.2, dict(w=1.4, yb=2.3, yt=2.7))], yb=1.95, yw=0.1, nt=2.6, nb=3.0)
    can.build("canopy", "primary", regions=[
        R(-6.3, 5.7, 8, 172, "glass", 0.03),
        R(-5.6, 5.5, 52, 58, "secondary", -0.05), R(-5.6, 5.5, 122, 128, "secondary", -0.05),
        R(-5.8, 5.7, 87, 93, "secondary", -0.05), R(-2.9, -2.6, 8, 172, "secondary", -0.05),
        R(1.3, 1.6, 8, 172, "secondary", -0.05)])
    for trim in TRIMS:
        lvl = LVL[trim]
        K.begin(c, "NOSE", trim)
        nose = Hull([(-12.4, dict(w=3.5, yb=-0.1, yt=0.5, rb=0.2, ys=0.2, tum=0.1, drop=0.1)),
                     (-11.2, dict(w=3.7, yb=-0.3, yt=0.85, rb=0.35, ys=0.45, tum=0.15, drop=0.15)),
                     (-8.5, dict(w=3.8, yt=1.4, ys=0.85, tum=0.25, drop=0.25)),
                     (-6.6, dict(w=3.8, yt=1.9, ys=1.15, tum=0.33, drop=0.28)), (-5.2, SEAM_F)],
                    yb=-0.4, rb=0.5, wcf=0.3, d2=0.14, crown=0.01)
        regs = [R(-11.8, -6.9, 5.0, 6.0, "secondary", 0.03), R(-12.3, -10.6, 2.9, 3.02, "lights", -0.01)]
        if lvl:
            regs.append(R(-10.2, -7.2, 4.15, 4.8, "detail", 0.18))
        nose.build("skin", "primary", t1=-5.2 - GAP, caps=(False, True), regions=regs)
        if lvl:
            louvres(nose, "hood", -10.1, -7.3, 4.2, 4.75, 5 + lvl, off=-0.1)
        nose.throat("mouth", "min", lip="primary", scale=0.86, depth=0.7)
        for i, x in enumerate((1.1,)):
            box(f"strut{i}", (x, 0.2, -12.2), (0.08, 0.5, 0.4), "secondary", mirror=True)
        nose_splitter(lvl, -12.4, 3.3, 3.6, nt=7.0)

        K.begin(c, "FPOD", trim)
        st = [(-12.3, dict(cx=5.05, w=1.0, wi=1.0, yb=-0.5, yt=1.3, ys=0.75)),
              (-11.4, dict(cx=5.1, w=1.18, wi=1.1, yb=-0.95, yt=2.0, ys=1.1)),
              (-10.3, dict(cx=5.15, w=1.27, wi=1.17, yb=-1.1, yt=2.22, ys=1.2)),
              (-7.4, dict(cx=5.17, w=1.27, wi=1.18, yb=-1.1, yt=2.22, ys=1.2)),
              (-6.4, dict(cx=5.12, w=1.2, wi=1.15, yb=-0.9, yt=1.95, ys=1.05)),
              (-5.4, dict(SIDE_F, yb=-0.1, yt=1.45, ys=0.7, rb=0.3))]
        pod, _ = fender(st, -8.4, trim, True, E_POD, archw=1.35, vent=E_VENT,
                        shell_kw=dict(half=1.05, y0=-0.85, y1=1.05, nt=6.0))
        pod.throat("housing", "min", lip="primary", scale=0.82, depth=0.35, mirror=True)
        for i, (dx, y) in enumerate(((-0.3, 0.72), (0.3, 0.72), (-0.3, 0.0), (0.3, 0.0))):
            box(f"point{i}", (5.05 + dx, y, -12.02), (0.1, 0.52, 0.1), "lights", mirror=True)
        pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.78, 0.84, 0.88)[lvl], depth=0.5, mirror=True)
        front_aero(lvl, -12.3, nt=7.0)
        flange(-12.0, -5.6, 0.5)

        K.begin(c, "TAIL", trim)
        tail = Hull([(2.8, SEAM_R), (5.5, dict(yt=2.55)), (8.6, dict(yt=2.5, ys=1.5, tum=0.2, drop=0.2)),
                     (10.0, dict(yb=0.0, yt=2.45, ys=1.55, tum=0.18, drop=0.18)),
                     (11.2, dict(w=3.75, yb=0.45, yt=(2.45, 2.6, 2.75)[lvl], ys=1.6, tum=0.15, drop=0.15, rb=0.4))],
                    **{**SEAM_R, "crown": 0.01})
        tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
            R(8.6, 11.2, 0.0, 2.3, "secondary", 0.02), R(4.2, 10.3, 4.9, 6.0, "detail", 0.1),
            R((7.0, 6.0, 5.0)[lvl], 10.2, 4.15, 4.75, "detail", 0.15)])
        louvres(tail, "deck", (7.1, 6.1, 5.1)[lvl], 10.1, 4.2, 4.7, 6 + lvl * 2, off=-0.08)
        tail.throat("fascia", "max", lip="primary", scale=0.93, depth=0.3)
        box("bar", (0, 2.12, 11.02), (6.9, 0.16, 0.16), "lights_red")
        box("plate", (0, 2.12, 11.06), (2.0, 0.22, 0.12), "secondary")
        tail_kit(lvl, (2.8, 3.25), nt=7.0)

        K.begin(c, "RPOD", trim)
        st = [(3.6, dict(SIDE_R, yb=-0.5, yt=1.6)),
              (4.6, dict(cx=5.12, w=1.22, wi=1.18, yb=-1.0, yt=2.45, ys=1.35)),
              (5.6, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.75, ys=1.55)),
              (9.6, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.75, ys=1.55)),
              (10.6, dict(cx=5.14, w=1.2, wi=1.2, yb=-0.8, yt=2.55, ys=1.5))]
        pod, _ = fender(st, 7.5, trim, False, E_POD, archw=1.35, vent=E_VENT,
                        shell_kw=dict(half=1.05, y0=-0.85, y1=1.05, nt=6.0), slats=True, reach=3.0, ups=(0, 0.15, 0.3))
        pod.throat("intake", "min", lip="primary", scale=0.8, depth=0.5, mirror=True)
        pod.throat("noz", "max", lip="secondary", back="detail", scale=0.9, depth=0.5, mirror=True)
        p = pod.params(10.6)
        y = (p["yb"] + p["yt"]) / 2
        t = tube(9.9, 10.55, p["cx"], y, 0.78 + lvl * 0.04)
        t.build("turbine", "secondary", mirror=True, caps=(True, False))
        t.throat("turbinen", "max", lip="secondary", back="thrust", scale=0.84, depth=0.3, mirror=True)
        box("vane", (p["cx"], y, 10.5), (0.07, 1.4, 0.2), "detail", mirror=True)
        rear_kit(pod, lvl, scoop=(2.6, 5.0))
        flange(3.8, 10.3, 1.0)

        K.begin(c, "STAB", trim)
        sill(trim, SILL_ST, dict(rb=0.4, tum=0.15, drop=0.08, wcf=0.6, d2=0.02, crown=0.01, cs=0.0),
             intake=(0.8, -0.4, -1.4))

        K.begin(c, "BOOST", trim)
        rect([(10.8, {}), (11.45, {})], 0, 2.3, 0.6, 1.95, c=0.25).build("shroud", "primary")
        box("panel", (0, 0.5, 10.98), (4.8, 1.6, 0.1), "detail")
        r = (0.45, 0.5, 0.5)[lvl]
        burner("turbine", 11.1, 12.0 + lvl * 0.15, 1.0, 1.28, r)
        box("vane", (1.0, 1.28, 11.9 + lvl * 0.15), (0.06, r * 1.7, 0.2), "detail", mirror=True)
        if lvl > 1:
            burner("lower", 11.1, 12.0, 1.0, 0.3, 0.3)

        K.begin(c, "WING", trim)
        if lvl == 0:   # full-width low blade with end fences
            plane("plane", 3.85, 11.0, 0.5, 2.95, 3.08, "primary")
            blade("fence", 3.86, 2.3, 3.35, (10.4, 11.6), (10.55, 11.75), "secondary", t=0.05)
            blade("stub", 2.7, 1.25, 2.98, (10.6, 11.2), (10.75, 11.3), "secondary")
        elif lvl == 1:
            race_wing(4.7, 11.2, 0.85, 4.4, 2.7, plate=(3.6, 4.95))
        else:
            race_wing(6.3, 11.3, 0.95, 4.9, 2.7, elements=2, plate=(3.1, 5.8), beam=True)


# ---------------------------------------------------------------- car F: aero hypercar

F_POD = dict(rb=0.4, tum=0.35, drop=0.22, tumi=0.03, dropi=0.1, wcf=0.5, d2=0.04, crown=0.04)
F_VENT = ((-0.9, 0.5, 4.2, 4.9, 3), (-1.3, 0.9, 4.15, 5.15, 5), (-1.5, 1.1, 4.1, 5.35, 6))


def f_accents(z0, z1):
    """Outline accents in the secondary colour along the shoulder and top edge of a fender."""
    return [R(z0 + 0.4, z1 - 0.15, 2.94, 3.06, "secondary", -0.02, side=1),
            R(z0 + 0.4, z1 - 0.15, 3.94, 4.06, "secondary", -0.02, side=1)]


def car_f():
    c = "F"
    K.begin(c, "COCKPIT")
    tub([R(-4.6, 2.4, 2.1, 2.92, "detail", 0.3), R(-5.0, 2.6, 2.96, 3.06, "secondary", -0.02)])
    can = Loft([(-6.7, dict(w=1.4, yb=1.8, yt=2.08)), (-4.8, dict(w=2.1, yt=3.2)), (-2.6, dict(w=2.35, yt=4.2)),
                (-0.6, dict(w=2.35, yt=4.45)), (1.6, dict(w=2.1, yt=4.2)), (4.2, dict(w=1.5, yb=2.15, yt=3.4)),
                (7.2, dict(w=0.7, yb=2.3, yt=2.75))], yb=1.95, yw=0.1, nt=2.2, nb=3.0)
    can.build("canopy", "primary", regions=[R(-6.3, 2.2, 8, 172, "glass", 0.03),
                                            R(2.2, 7.0, 82, 98, "secondary", -0.04)])
    s = Loft([(-0.4, dict(w=0.42, yt=4.62)), (1.0, dict(w=0.5, yt=4.86)), (2.8, dict(w=0.3, yt=4.4))], yb=4.1,
             nt=3.0, nb=3.0, yw=0.3)
    s.build("snorkel", "primary", caps=(False, True))
    s.throat("snorkelin", "min", lip="secondary", scale=0.8, depth=0.4)
    for trim in TRIMS:
        lvl = LVL[trim]
        K.begin(c, "NOSE", trim)
        nose = Hull([(-12.3, dict(w=0.9, yb=0.35, yt=0.8, rb=0.1, ys=0.55, tum=0.15, drop=0.08)),
                     (-11.0, dict(w=1.6, yb=0.1, yt=1.1, rb=0.2, ys=0.6, tum=0.25, drop=0.15)),
                     (-8.5, dict(w=2.6, yb=-0.2, yt=1.5, rb=0.35, ys=0.85, tum=0.35, drop=0.25)),
                     (-6.6, dict(w=3.5, yb=-0.4, yt=1.9, ys=1.15, tum=0.36, drop=0.28)), (-5.2, SEAM_F)],
                    yb=-0.4, rb=0.45, wcf=0.5, d2=0.05, crown=0.04)
        nose.build("skin", "primary", t1=-5.2 - GAP, regions=[
            R(-12.2, -5.6, 5.55, 6.0, "secondary", -0.02), R(-11.8, -10.4, 2.86, 2.98, "lights", -0.01)])
        slab("floor", [(-12.0, 2.0), (-11.0, 3.6), (-5.5, 3.75)], -0.44, -0.34, "secondary", nt=6.0)
        for i, x in enumerate((1.3, 2.6)[:1 + (lvl > 0)]):
            blade(f"strut{i}", x, -0.36, 0.5, (-11.9 + i * 0.8, -10.6 + i * 0.8), (-11.3 + i * 0.8, -10.4 + i * 0.8),
                  "secondary", t=0.04)
        nose_splitter(lvl, -12.3, 2.4, 3.5, nt=7.0)
        if lvl:  # front wing flap above the splitter
            plane("flap", 3.7, -12.2 - lvl * 0.3, 0.3, -0.2, -0.1, "primary")

        K.begin(c, "FPOD", trim)
        st = [(-11.8, dict(cx=5.1, w=0.5, wi=0.5, yb=0.0, yt=1.0, ys=0.5, rb=0.15, tum=0.15, drop=0.1, dropi=0.1)),
              (-11.0, dict(cx=5.12, w=0.95, wi=0.88, yb=-0.6, yt=1.7, ys=0.8)),
              (-9.7, dict(cx=5.17, w=1.2, wi=1.08, yb=-1.0, yt=2.12, ys=1.05)),
              (-8.5, dict(cx=5.18, w=1.27, wi=1.12, yb=-1.1, yt=2.25, ys=1.15)),
              (-7.0, dict(cx=5.15, w=1.15, wi=1.1, yb=-1.0, yt=1.8, ys=0.95)),
              (-5.4, dict(cx=5.1, w=1.0, wi=1.05, yb=-0.5, yt=1.3, ys=0.7))]
        pod, _ = fender(st, -8.6, trim, True, F_POD, caps=(True, False), vent=F_VENT, archw=1.5,
                        extra=[R(-11.55, -10.1, 3.2, 3.9, "glass", 0.08, side=1), *f_accents(-11.8, -5.4)],
                        shell_kw=dict(half=1.05, y0=-0.9, y1=1.15, nt=3.0))
        pod.patch("lamp", -11.45, -10.2, 3.36, 3.56, "lights", off=-0.04, mirror=True)
        pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.84, 0.87, 0.9)[lvl], depth=0.6, mirror=True)
        front_aero(lvl, -11.9, nt=7.0, y=0.45)
        flange(-10.4, -5.6, 0.5)

        K.begin(c, "TAIL", trim)
        tail = Hull([(2.8, SEAM_R), (5.0, dict(w=3.4, yt=2.5, tum=0.5, drop=0.4)),
                     (8.0, dict(w=2.9, yb=-0.1, yt=2.25, ys=1.3, tum=0.5, drop=0.4)),
                     (11.2, dict(w=2.65, yb=0.35, yt=(2.0, 2.1, 2.2)[lvl], ys=1.2, tum=0.35, drop=0.3, rb=0.4))],
                    **{**SEAM_R, "crown": 0.03})
        tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
            R(3.0, 10.8, 5.55, 6.0, "secondary", -0.02), R(5.6, 10.0, 4.2, 4.9, "detail", 0.14)])
        louvres(tail, "deck", 5.7, 9.9, 4.25, 4.85, 7 + lvl, off=-0.07)
        tail.throat("fascia", "max", lip="primary", scale=0.9, depth=0.25)
        back = (11.7, 12.3, 12.75)[lvl]
        slab("floor", [(7.6, 3.6), (back - 0.4, 3.75), (back, 3.5)], -0.5, -0.42, "secondary", nt=7.0)
        for i, x in enumerate(((1.0, 2.9), (1.0, 2.2, 3.1), (0.9, 1.7, 2.5, 3.2))[lvl]):
            dfin(f"fin{i}", x, ((8.6, -0.3), (10.4, 0.2), (back, 0.4 + lvl * 0.12)))
        blade("endplate", 3.55, -0.45, 1.7 + lvl * 0.15, (9.9, 11.5), (10.7, 11.5), "secondary", t=0.05)
        box("lamp", (3.55, 1.05, 11.53), (0.1, 0.9, 0.06), "lights_red", mirror=True)
        if lvl > 1:
            blade("fin", 0, 2.3, 3.85, (6.6, 10.2), (9.0, 10.25), "primary", t=0.06)

        K.begin(c, "RPOD", trim)
        rst = [(3.6, dict(SIDE_R, yb=-0.5, yt=1.3)),
               (5.0, dict(cx=5.12, w=1.15, wi=1.15, yb=-1.0, yt=1.8, ys=1.0)),
               (6.6, dict(cx=5.18, w=1.28, wi=1.2, yb=-1.1, yt=2.62, ys=1.45)),
               (7.8, dict(cx=5.18, w=1.3, wi=1.2, yb=-1.1, yt=2.85, ys=1.55)),
               (9.4, dict(cx=5.16, w=1.25, wi=1.2, yb=-1.0, yt=2.68, ys=1.5)),
               (10.6, dict(cx=5.14, w=1.16, wi=1.19, yb=-0.6, yt=2.45, ys=1.6))]
        pod, _ = fender(rst, 7.6, trim, False, F_POD, vent=F_VENT, extra=f_accents(3.6, 10.6), archw=1.5,
                        shell_kw=dict(half=1.05, y0=-0.9, y1=1.15, nt=3.0), slats=True, reach=3.0, ups=(0, 0.15, 0.3))
        pod.throat("intake", "min", lip="primary", scale=0.8, depth=0.5, mirror=True)
        pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.84, 0.87, 0.9)[lvl], depth=0.6, mirror=True)
        p = pod.params(10.6)
        for i, dy in enumerate((-0.45, 0.0, 0.45)):
            box(f"slat{i}", (p["cx"], (p["yb"] + p["yt"]) / 2 + dy, 10.42), (1.8, 0.07, 0.3), "detail", mirror=True)
        rear_kit(pod, lvl)
        flange(3.8, 10.3, 1.0)

        K.begin(c, "STAB", trim)
        fst = [(-5.2, dict(yb=-0.8, yt=0.3, ys=-0.1)), (-2.0, dict(yt=0.45, ys=0.05)), (1.5, dict(yt=0.9, ys=0.4)),
               (3.4, dict(yb=-0.7, yt=1.25, ys=0.7))]
        sill(trim, fst, dict(rb=0.25, tum=0.3, drop=0.12, wcf=0.5, d2=0.03, crown=0.03), intake=(1.2, 0.0, -1.2),
             extra=[R(-5.0, 3.2, 2.94, 3.06, "secondary", -0.02, side=1)], w=1.05)
        blade("vane", 5.5, -0.9, 0.35, (-4.8, -3.6), (-4.5, -4.0), "secondary", t=0.04)

        K.begin(c, "BOOST", trim)
        Hull([(10.7, dict(w=2.35, yb=-0.42, yt=0.95)), (11.5, dict(w=2.2, yb=-0.3, yt=0.9))], rb=0.35, ys=0.55,
             tum=0.35, drop=0.0, wcf=0.5, d2=0.0, crown=0.0).build("housing", "secondary")
        box("band", (0, 1.5, 11.04), (4.6, 0.5, 0.16), "primary")
        box("panel", (0, 1.4, 10.98), (4.8, 1.1, 0.1), "detail")
        t = rect([(11.1, {}), (12.0 + lvl * 0.15, {})], 1.08, 0.78 + lvl * 0.05, -0.2, 0.7 + lvl * 0.08, c=0.3)
        t.build("burner", "secondary", mirror=True, caps=(True, False))
        t.throat("noz", "max", lip="secondary", back="thrust", scale=0.84, depth=0.35, mirror=True)
        for i, x in enumerate((0.0, 2.05)[:1 + (lvl > 0)]):
            box(f"fin{i}", (x, 0.25, 11.75), (0.06, 1.0, 0.8), "detail", mirror=x != 0)
        if lvl > 1:
            box("rain", (0, 1.5, 11.14), (0.5, 0.14, 0.08), "lights_red")

        K.begin(c, "WING", trim)
        if lvl == 0:   # low wing on two pylons
            plane("plane", 3.9, 11.0, 0.65, 3.4, 3.55, "primary", tip=(11.15, 0.5))
            blade("pylon", 2.4, 1.25, 3.44, (10.2, 11.1), (10.7, 11.3), "secondary")
            blade("plate", 3.92, 3.1, 3.85, (10.5, 11.7), (10.8, 11.85), "secondary", t=0.05)
        elif lvl == 1:
            race_wing(5.0, 11.2, 0.9, 4.7, 2.4, plate=(3.7, 5.2))
        else:
            race_wing(6.6, 11.3, 1.0, 5.2, 2.4, elements=2, plate=(3.0, 6.0), beam=True)


def build():
    car_c()
    car_d()
    car_e()
    car_f()
