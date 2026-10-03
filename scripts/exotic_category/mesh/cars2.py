"""Exotic cars C, D, E and F: the remaining four cockpits, on the same frame standard as cars A and B.

Each car has its own module architecture, not just its own details:

  C  exotic_01  clean concept coupe. Engines: a large vented drum under a thin arc fender, with slim
                fore and aft bodies. Sill: a round tube. Kit wing: one centre swan pylon.
  D  exotic_03  wraparound-visor supercar. Engines: long humpback blocks cut off square at the back,
                with a slot window showing a turbine barrel; the rear pair rise to the tail. Sill: a
                tall scoop. Kit wing: downturned tips.
  E  exotic_04  faceted endurance car. Engines: flat-topped box pontoons with upright slots and round
                turbines. Sill: a flat box. Kit wing: a bridge between two tall fins.
  F  exotic_06  aero hypercar. Engines: a dark core with floating panels, an outer shield and a top
                cap, with daylight between them. Sill: a low tray with turning vanes. Kit wing: wide
                twin-pylon race wing.

Cars A and B (cars.py) are a flowing fender over an arch with a shell, in sharp and round forms.
Each car has three versions per slot (STD road car, GT race kit, EVO full kit).
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


def fender(st, peak, trim, front, style, creases=(1, 2, 3, 4), caps=(False, False), vent=None, extra=(),
           arch_regs=None, shell_kw=None, reach=2.2, ups=(0, 0.1, 0.2), kit=True):
    """Hull fender: rocker, an arch or other side opening, optional louvred top vent, kit hardware."""
    lvl = LVL[trim]
    pod = Hull(flared(st, peak, (0, 0.3, 0.5)[lvl], ups[lvl], reach), creases=creases, **style)
    z0, z1 = st[0][0], st[-1][0]
    regs = [R(z0 + 0.3, z1 - 0.2, 1.0, (2.05, 2.3, 2.6)[lvl], "secondary", 0.02)]
    regs += arch_regs if arch_regs is not None else [R(peak - 1.7, peak + 1.7, 1.25, 2.92, "detail", 0.33, side=1)]
    v = vent[lvl] if vent else None
    if v:
        regs.append(R(peak + v[0], peak + v[1], v[2], v[3], "detail", 0.13, side=1))
    if kit:
        regs += fender_regions(peak, lvl, front)
    regs += list(extra)
    pod.build("skin", "primary", mirror=True, caps=caps, regions=regs)
    if v:
        louvres(pod, "top", peak + v[0] + 0.1, peak + v[1] - 0.1, v[2] + 0.06, v[3] - 0.06, v[4], off=-0.05)
    if shell_kw:
        shell(pod, peak, bars=(1, 2, 2)[lvl], **shell_kw)
    if kit:
        fender_kit(pod, peak, lvl, front)
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])
    return pod, lvl


def front_aero(lvl, tip, cx=5.12, nt=5.0, y=0.35):
    """Splitter corner under a front engine, with an endplate and dive planes on the kits."""
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


def rear_corner(lvl):
    """Corner diffuser strakes under a rear nozzle on the kits."""
    for i, x in enumerate((4.6, 5.3, 6.0)[:lvl + 1] if lvl else ()):
        dfin(f"corner{i}", x, ((9.6, -0.5), (10.6, -0.1), (11.7 + lvl * 0.2, 0.3)))


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


def skirt(lvl, always=True):
    """Floor skirt outboard of a sill, with an upright kick and bargeboards on the kits."""
    if not lvl and not always:
        return
    out = (6.1, 6.55, 6.85)[lvl]
    slab("skirt", [(-5.1, (out - 4.6) / 2 - 0.15), (-3.6, (out - 4.6) / 2), (3.3, (out - 4.6) / 2)], -1.0, -0.92,
         "secondary", cx=(out + 4.6) / 2, mirror=True)
    if lvl:
        blade("kick", out - 0.05, -0.95, 0.5 + lvl * 0.35, (1.6, 3.35), (2.5, 3.4), "secondary", t=0.04)
    if lvl > 1:
        for i, x in enumerate((6.1, 6.6)):
            blade(f"barge{i}", x, -0.95, 0.55 - i * 0.2, (-5.0, -3.4), (-4.7, -3.9), "secondary", t=0.04)


def hull_sill(trim, st, style, creases=(1, 2, 3, 4), intake=(0.5, -0.6, -1.6), intake_u=(3.1, 3.9), neon=True,
              extra=(), cx=4.9, w=1.0):
    lvl = LVL[trim]
    hull = Hull(st, creases=creases, cx=cx, w=w, yb=-0.9, **style)
    start = intake[lvl]
    regs = [R(-5.2, 3.4, 1.0, (2.25, 2.6, 2.95)[lvl], "secondary", 0.02),
            R(start, 3.15, intake_u[0], intake_u[1], "detail", 0.15, side=1), *extra]
    if neon:
        regs.append(R(-5.0, 3.2, 2.3, 2.38, "neon", -0.01, side=1))
    hull.build("skin", "primary", mirror=True, regions=regs)
    louvres(hull, "intake", start + 0.1, 3.05, intake_u[0] + 0.05, intake_u[1] - 0.05,
            max(3, int((3.05 - start) / 0.42)), off=-0.08)
    skirt(lvl)
    lift_glow(hull, [(-4.2, -2.4), (-0.6, 1.4)])
    return hull


def ring_lamp(name, x, y, z0, z1, r, ch="lights_red"):
    """Round lamp that reads as a ring: lit lens with a dark centre."""
    t = tube(z0, z1, x, y, r)
    t.build(name, "secondary", mirror=True, caps=(True, False))
    t.throat(name + "l", "max", lip="secondary", back=ch, scale=0.82, depth=0.06, mirror=True)
    t.cap(name + "c", "max", "detail", scale=0.42, push=-0.04, mirror=True)


# ---------------------------------------------------------------- car C: clean concept coupe

def c_engine(front, lvl):
    """A large vented drum under a thin arc fender, between a slim fore body and aft body."""
    peak, r, yc = (-8.5, 1.6, 0.38) if front else (7.2, 1.75, 0.52)
    r += lvl * 0.07
    face = 6.25 + lvl * 0.18
    drum = Loft([(4.3, {}), (face, {})], axis="x", cx=peak, w=r, yb=yc - r, yt=yc + r, nt=2.2, nb=2.2, yw=0.5)
    drum.build("drum", "secondary", mirror=True)
    drum.cap("ring", "max", "detail", scale=0.9, push=0.02, mirror=True)
    for i in range(-2, 3):   # louvre bars across the open face, so it reads as a vent and not a wheel
        dy = i * r * 0.3
        box(f"bar{i + 2}", (face + 0.05, yc + dy, peak), (0.08, 0.13, 2 * ((0.86 * r) ** 2 - dy * dy) ** 0.5),
            "neon" if i == 0 else "primary", mirror=True)
    drum.patch("lift", 4.7, face - 0.3, 262, 278, "thrust", off=0.03, mirror=True)
    arc = Loft([(3.98, {}), (face + 0.2, {})], axis="x", cx=peak, w=r + 0.42, yb=yc - r - 0.42, yt=yc + r + 0.42,
               nt=2.2, nb=2.2, yw=0.5)
    arc.patch("fender", 3.98, face + 0.2, 20, 160, "primary", off=0.0, mirror=True)
    arc.patch("lining", 3.98, face + 0.2, 20, 160, "detail", off=-0.09, mirror=True)
    if lvl:   # louvre slots across the top of the arc, and a fence on the full kit
        for i in range(4):
            arc.patch(f"louvre{i}", 4.5, face - 0.1, 70 + i * 11, 75 + i * 11, "secondary", off=0.05, mirror=True)
    if lvl > 1:
        blade("fence", face + 0.1, yc + r + 0.2, min(yc + r + 0.85, 2.68 if front else 9), (peak - 1.1, peak + 1.3), (peak - 0.5, peak + 1.4),
              "secondary", t=0.04)
    if front:
        fore = Loft([(-12.0, dict(w=0.3, yb=0.45, yt=0.9)), (-11.0, dict(w=0.7, yb=0.0, yt=1.2)),
                     (-9.6, dict(w=0.8, yb=-0.2, yt=1.3))], cx=5.15, nt=2.6, nb=2.6, yw=0.5)
        fore.build("fore", "primary", mirror=True, regions=[R(-11.7, -10.2, 20, 40, "lights", -0.01),
                                                            R(-11.7, -10.2, 140, 160, "lights", -0.01)])
        box("blade", (4.35, 0.5, -11.3), (0.1, 0.8, 0.12), "lights", mirror=True)
        aft = Loft([(-7.4, dict(w=0.8, yb=-0.2, yt=1.3)), (-5.4, dict(w=0.62, yb=0.1, yt=1.2))], cx=5.1, nt=2.6,
                   nb=2.6, yw=0.5)
        aft.build("aft", "primary", mirror=True, caps=(True, False))
        aft.throat("noz", "max", lip="secondary", back="thrust", scale=0.8 + lvl * 0.04, depth=0.4, mirror=True)
    else:
        fore = Loft([(3.6, dict(w=0.6, yb=0.0, yt=1.2)), (5.6, dict(w=0.85, yb=-0.3, yt=1.5))], cx=5.1, nt=2.6,
                    nb=2.6, yw=0.5)
        fore.build("fore", "primary", mirror=True, caps=(False, True))
        fore.throat("intake", "min", lip="primary", scale=0.8, depth=0.4, mirror=True)
        aft = Loft([(8.8, dict(w=0.95, yb=-0.3, yt=1.7)), (10.6, dict(w=0.8, yb=0.0, yt=1.6))], cx=5.1, nt=2.6,
                   nb=2.6, yw=0.5)
        aft.build("aft", "primary", mirror=True, caps=(True, False))
        aft.throat("noz", "max", lip="secondary", back="thrust", scale=0.82 + lvl * 0.04, depth=0.5, mirror=True)


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
        c_engine(True, lvl)
        front_aero(lvl, -12.05, nt=4.0)
        flange(-10.4, -6.6, 0.5)

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
        c_engine(False, lvl)
        rear_corner(lvl)
        flange(4.6, 9.8, 0.9)

        # Stabiliser: a round tube with a light line, on short struts.
        K.begin(c, "STAB", trim)
        r = 0.55 + lvl * 0.06
        pipe = Loft([(-5.2, dict(w=r * 0.6, yb=-0.25 - r * 0.6, yt=-0.25 + r * 0.6)), (-4.2, {}), (2.4, {}),
                     (3.4, dict(w=r * 0.7, yb=-0.25 - r * 0.7, yt=-0.25 + r * 0.7))], cx=4.75, w=r, yb=-0.25 - r,
                    yt=-0.25 + r, nt=2.0, nb=2.0, yw=0.5)
        pipe.build("pipe", "primary", mirror=True, regions=[R(-4.4, 2.6, 2, 12, "neon", -0.01),
                                                            R(-4.6, 2.8, 300, 345, "secondary", 0.02)])
        pipe.patch("lift0", -4.0, -2.4, 262, 278, "thrust", off=0.03, mirror=True)
        pipe.patch("lift1", -0.6, 1.2, 262, 278, "thrust", off=0.03, mirror=True)
        for i, z in enumerate((-3.6, 0.0, 2.2)):
            box(f"strut{i}", (4.05, -0.25, z), (0.5, 0.16, 0.5), "detail", mirror=True)
        skirt(lvl, always=False)

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
        else:          # one centre swan pylon carrying a tapered plane
            span, y, chord = ((0, 0, 0), (4.4, 4.2, 0.9), (5.8, 4.8, 1.05))[lvl]
            plane("plane", span, 11.2, chord, y, y + 0.2, "primary", tip=(11.5, chord * 0.45))
            blade("pylon", 0, 1.25, y + 0.5, (9.6, 11.0), (10.6, 11.1), "secondary", t=0.09)
            box("hook", (0, y + 0.36, 11.15), (0.18, 0.3, 0.6), "secondary")
            blade("plate", span, y - 0.25, y + 0.5, (11.0, 12.1), (11.3, 12.25), "secondary", t=0.05)
            if lvl > 1:
                plane("flap", span * 0.8, 12.2, 0.34, y + 0.4, y + 0.52, "primary", tip=(12.3, 0.2))


# ---------------------------------------------------------------- car D: wraparound-visor supercar

D_POD = dict(rb=0.4, tum=0.48, drop=0.3, tumi=0.03, dropi=0.12, wcf=0.5, d2=0.04, crown=0.09)
D_VENT = ((-0.9, 0.5, 4.2, 4.9, 3), (-1.3, 0.9, 4.15, 5.15, 5), (-1.5, 1.1, 4.1, 5.35, 6))


def d_barrel(pod, z0, z1, y, r=0.42):
    """Turbine barrel seen through the slot window in the side of an engine block."""
    p = pod.params((z0 + z1) / 2)
    t = tube(z0, z1, p["cx"] + p["w"] - 0.5, y, r)
    t.build("barrel", "secondary", mirror=True)
    for i in range(4):
        z = z0 + (z1 - z0) * (i + 0.5) / 4
        tube(z - 0.06, z + 0.06, p["cx"] + p["w"] - 0.5, y, r + 0.06).build(f"band{i}", "detail", mirror=True)


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

        # Front engines: a long block that peaks early and is cut off square over the sill.
        K.begin(c, "FPOD", trim)
        st = [(-12.1, dict(cx=4.95, w=0.6, wi=0.6, yb=0.1, yt=0.9, ys=0.45, rb=0.15, tum=0.2, drop=0.12, dropi=0.1)),
              (-11.2, dict(cx=5.05, w=1.1, wi=0.95, yb=-0.6, yt=1.9, ys=0.9)),
              (-10.0, dict(cx=5.14, w=1.28, wi=1.08, yb=-1.0, yt=2.25, ys=1.15)),
              (-7.0, dict(cx=5.15, w=1.28, wi=1.12, yb=-1.05, yt=2.05, ys=1.1)),
              (-5.4, dict(cx=5.12, w=1.2, wi=1.12, yb=-0.7, yt=1.9, ys=1.0))]
        pod, _ = fender(st, -8.2, trim, True, D_POD, creases=(1, 2, 3), caps=(True, False), vent=D_VENT,
                        arch_regs=[R(-10.0, -6.2, 2.2, 2.9, "detail", 0.35, side=1)],
                        extra=[R(-11.75, -10.6, 3.4, 4.6, "glass", 0.1, side=1)], kit=False)
        d_barrel(pod, -9.8, -6.4, 0.5)
        for i, t in enumerate((-11.62, -11.25, -10.9)):
            pod.patch(f"lamp{i}", t, t + 0.24, 3.75, 4.3, "lights", off=-0.05, mirror=True)
        pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.82, 0.86, 0.9)[lvl], depth=0.5, mirror=True)
        if lvl > 1:
            p = pod.params(-8.2)
            blade("fence", p["cx"] + p["w"] - 0.3, p["ys"] + 0.5, p["yt"] + 0.3, (-10.2, -6.6), (-9.6, -6.4),
                  "secondary", t=0.04)
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

        # Rear engines: a wedge that rises to the tail and ends in a tall face with two stacked nozzles.
        K.begin(c, "RPOD", trim)
        st = [(3.6, dict(SIDE_R, yb=-0.5, yt=1.5)),
              (5.0, dict(cx=5.12, w=1.2, wi=1.15, yb=-1.0, yt=2.0, ys=1.1)),
              (7.5, dict(cx=5.18, w=1.3, wi=1.2, yb=-1.1, yt=2.55, ys=1.45)),
              (9.6, dict(cx=5.18, w=1.3, wi=1.2, yb=-1.05, yt=2.95, ys=1.7)),
              (10.6, dict(cx=5.16, w=1.25, wi=1.18, yb=-0.8, yt=2.95, ys=1.7))]
        pod, _ = fender(st, 8.2, trim, False, D_POD, creases=(1, 2, 3), vent=D_VENT, reach=3.0, ups=(0, 0.15, 0.3),
                        arch_regs=[R(5.6, 9.6, 2.2, 2.9, "detail", 0.35, side=1)], kit=False)
        d_barrel(pod, 5.8, 9.4, 0.5, r=0.46)
        pod.throat("intake", "min", lip="primary", scale=0.8, depth=0.5, mirror=True)
        pod.throat("face", "max", lip="primary", back="detail", scale=0.9, depth=0.35, mirror=True)
        p = pod.params(10.6)
        mid, half = (p["yb"] + p["yt"]) / 2, (p["yt"] - p["yb"]) / 2
        for i, dy in enumerate((0.42, -0.42)):
            burner(f"stack{i}", 9.9, 10.62, p["cx"], mid + dy * half * 1.1, 0.5 * half * 0.92 + lvl * 0.03, depth=0.3)
        if lvl > 1:
            pp = pod.params(8.2)
            blade("fence", pp["cx"] + pp["w"] - 0.3, pp["ys"] + 0.5, pp["yt"] + 0.3, (6.2, 10.2), (7.0, 10.4),
                  "secondary", t=0.04)
        rear_corner(lvl)
        flange(3.8, 10.3, 1.0)

        # Stabiliser: a tall scoop that climbs to the rear engine.
        K.begin(c, "STAB", trim)
        dst = [(-5.2, dict(yb=-0.8, yt=0.3, ys=-0.1)), (-2.0, dict(yt=0.95, ys=0.3)), (1.5, dict(yt=1.6, ys=0.85)),
               (3.4, dict(yb=-0.7, yt=1.85, ys=1.05))]
        hull_sill(trim, dst, dict(rb=0.3, tum=0.45, drop=0.2, wcf=0.45, d2=0.03, crown=0.09), creases=(1, 2, 3),
                  intake=(-1.6, -2.4, -3.2), neon=False)

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
        else:          # high wing with tips that turn down toward the rear engines
            span, y, chord = ((0, 0, 0), (4.7, 4.5, 0.9), (6.2, 5.0, 1.0))[lvl]
            plane("plane", span, 11.2, chord, y, y + 0.2, "primary", tip=(11.45, chord * 0.7))
            blade("pylon", 2.6, 1.25, y + 0.05, (10.0, 11.0), (10.7, 11.5), "secondary", t=0.08)
            blade("tip", span, y - 1.3 - lvl * 0.3, y + 0.15, (11.2, 12.0), (10.9, 12.2), "secondary", t=0.06)
            box("gurney", (0, y + 0.25, 11.2 + chord - 0.04), (span * 2, 0.1, 0.05), "secondary")
            if lvl > 1:
                plane("flap", span, 11.2 + chord + 0.12, 0.4, y + 0.4, y + 0.52, "primary")


# ---------------------------------------------------------------- car E: faceted endurance car

def e_engine(front, lvl):
    """Flat-topped box pontoon with upright slots in its side."""
    z0, z1, top, cx = (-12.3, -5.4, 1.9, 5.1) if front else (3.6, 10.6, 2.55, 5.12)
    top += lvl * 0.12
    lead = dict(yb=-0.7, yt=top - 0.6, ys=top - 1.0) if front else dict(yt=top - 0.7, ys=top - 1.1)
    pod = Hull([(z0, lead), (z0 + 2.0, {}), (z1, {})], cx=cx + lvl * 0.12, w=1.15 + lvl * 0.12, wi=1.12, yb=-1.0, yt=top, rb=0.5,
               ys=top - 0.45, tum=0.14, drop=0.1, tumi=0.03, dropi=0.08, wcf=0.7, d2=0.02, crown=0.01, cs=0.0)
    mid = (z0 + z1) / 2
    regs = [R(z0 + 0.2, z1 - 0.2, 1.0, 2.0, "secondary", 0.02), R(z0 + 0.7, z1 - 0.7, 4.3, 5.7, "secondary", 0.03)]
    for i in range(3 + (lvl > 0)):
        a = mid - 2.1 + i * (1.2 if lvl == 0 else 1.05)
        regs.append(R(a, a + 0.6, 2.15, 2.92, "detail", 0.3, side=1))
    if lvl:
        regs.append(R(mid - 1.6, mid + 1.6, 4.5, 5.5, "detail", 0.13, side=1))
    pod.build("skin", "primary", mirror=True, caps=(False, False), regions=regs)
    if lvl:
        louvres(pod, "top", mid - 1.5, mid + 1.5, 4.55, 5.45, 6, off=-0.05)
    pod.patch("line", z0 + 0.4, z1 - 0.4, 2.96, 3.02, "neon", off=0.02, mirror=True)
    lift_glow(pod, [(mid - 1.4, mid - 0.2), (mid + 0.4, mid + 1.6)])
    if lvl > 1:
        p = pod.params(mid)
        blade("fence", p["cx"] + p["w"] - 0.25, top - 0.1, top + 0.55, (mid - 2.4, mid + 2.2), (mid - 1.9, mid + 2.4),
              "secondary", t=0.04)
    return pod


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
        box("strut", (1.1, 0.2, -12.2), (0.08, 0.5, 0.4), "secondary", mirror=True)
        nose_splitter(lvl, -12.4, 3.3, 3.6, nt=7.0)

        K.begin(c, "FPOD", trim)
        pod = e_engine(True, lvl)
        pod.throat("housing", "min", lip="primary", scale=0.84, depth=0.35, mirror=True)
        cx = pod.params(-12.3)["cx"]
        for i, (dx, y) in enumerate(((-0.32, 0.72), (0.32, 0.72), (-0.32, -0.12), (0.32, -0.12))):
            box(f"point{i}", (cx + dx, y, -12.02), (0.1, 0.55, 0.1), "lights", mirror=True)
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
        tail_kit(lvl, (2.8, 3.25), nt=7.0, fin=False)

        K.begin(c, "RPOD", trim)
        pod = e_engine(False, lvl)
        pod.throat("intake", "min", lip="primary", scale=0.84, depth=0.5, mirror=True)
        pod.throat("face", "max", lip="secondary", back="detail", scale=0.9, depth=0.5, mirror=True)
        p = pod.params(10.6)
        y = (p["yb"] + p["yt"]) / 2
        t = tube(9.9, 10.55, p["cx"], y, 0.82 + lvl * 0.05)
        t.build("turbine", "secondary", mirror=True, caps=(True, False))
        t.throat("turbinen", "max", lip="secondary", back="thrust", scale=0.84, depth=0.3, mirror=True)
        box("vane", (p["cx"], y, 10.5), (0.07, 1.5, 0.2), "detail", mirror=True)
        rear_corner(lvl)
        flange(3.8, 10.3, 1.0)

        # Stabiliser: a flat box with upright vent slots.
        K.begin(c, "STAB", trim)
        top = 0.95 + lvl * 0.12
        sbox = Hull([(-5.2, {}), (3.4, {})], cx=4.9, w=1.0, yb=-0.9, yt=top, rb=0.35, ys=top - 0.3, tum=0.12,
                    drop=0.08, wcf=0.6, d2=0.02, crown=0.01, cs=0.0)
        regs = [R(-5.2, 3.4, 1.0, 2.0, "secondary", 0.02), R(-5.0, 3.2, 2.94, 3.0, "neon", -0.01, side=1)]
        for i in range(4 + lvl):
            a = -4.4 + i * (1.9 - lvl * 0.3)
            regs.append(R(a, a + 0.5, 2.15, 2.9, "detail", 0.25, side=1))
        sbox.build("skin", "primary", mirror=True, regions=regs)
        skirt(lvl)
        lift_glow(sbox, [(-4.2, -2.4), (-0.6, 1.4)])

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
        else:          # bridge wing: the plane spans two tall fins that stand on the tail
            span, y, chord = ((0, 0, 0), (3.7, 4.3, 0.8), (3.75, 5.0, 0.95))[lvl]
            plane("plane", span, 11.3, chord, y, y + 0.2, "primary")
            blade("fin", span, 1.25, y + 0.75, (9.4, 11.9), (10.7, 12.3), "secondary", t=0.07)
            box("gurney", (0, y + 0.25, 11.3 + chord - 0.04), (span * 2, 0.1, 0.05), "secondary")
            if lvl > 1:
                plane("flap", span, 11.3 + chord + 0.1, 0.36, y + 0.4, y + 0.52, "primary")
                plane("beam", span, 10.9, 0.3, 3.3, 3.42, "secondary")


# ---------------------------------------------------------------- car F: aero hypercar

def f_engine(front, lvl):
    """A dark core with floating body panels: an outer shield and a top cap, with daylight between."""
    z0, z1, peak, h = (-11.8, -5.4, -8.4, 0.0) if front else (3.6, 10.6, 7.2, 0.42)
    core = Hull([(z0, dict(w=0.35, yb=0.1, yt=0.9 + h * 0.5, ys=0.5)),
                 (peak - 1.6, dict(w=0.75, yb=-0.9, yt=1.5 + h, ys=0.8)),
                 (peak + 1.2, dict(w=0.8, yb=-1.0, yt=1.6 + h, ys=0.9)),
                 (z1, dict(w=0.72, yb=-0.5, yt=1.4 + h, ys=0.8))], cx=4.82, rb=0.25, tum=0.25, drop=0.15, wcf=0.5,
                d2=0.03, crown=0.03)
    core.build("core", "detail", mirror=True, caps=(not front, False),
               regions=[R(z0 + 0.6, z1 - 0.3, 3.0, 3.9, "secondary", 0.02, side=1)])
    core.throat("noz", "max", lip="secondary", back="thrust", scale=0.84 + lvl * 0.02, depth=0.5, mirror=True)
    if front:
        core.cap("tip", "min", "detail", mirror=True)
    else:
        core.throat("intake", "min", lip="secondary", scale=0.8, depth=0.3, mirror=True)
    lift_glow(core, [(peak - 1.0, peak + 0.8)])
    x = 6.0 + lvl * 0.22
    sst = [(peak - 2.3, dict(yb=0.2, yt=0.6 + h * 0.3, ys=0.4)), (peak - 1.2, dict(yb=-0.85, yt=1.75 + h, ys=0.9 + h / 2)),
           (peak + 1.0, dict(yb=-0.9, yt=1.85 + h, ys=1.0 + h / 2)), (peak + 1.9, dict(yb=-0.4, yt=1.3 + h, ys=0.7))]
    Hull(sst, cx=x, w=0.12, rb=0.04, tum=0.03, drop=0.03, crown=0.0).build("shield", "primary", mirror=True)
    edge = [(z, dict(yb=d["yb"] - 0.08, yt=d["yt"] + 0.08, ys=d["ys"])) for z, d in sst]
    Hull(edge, cx=x - 0.06, w=0.06, rb=0.04, tum=0.02, drop=0.02, crown=0.0).build("edge", "secondary", mirror=True)
    box("shieldbar", (x + 0.14, 0.45 + h / 2, peak), (0.06, 0.08, 1.7), "neon", mirror=True)
    cst = [(peak - 2.6, dict(w=0.3, yb=1.2 + h, yt=1.4 + h)), (peak - 1.0, dict(w=1.0, yb=1.95 + h, yt=2.2 + h)),
           (peak + 1.0, dict(w=1.05, yb=2.05 + h, yt=2.3 + h)), (peak + 2.2, dict(w=0.6, yb=1.7 + h, yt=1.9 + h))]
    cst = [(z, dict(d, ys=d["yb"] + 0.1)) for z, d in cst]
    cap = Hull(cst, cx=5.25 + lvl * 0.08, rb=0.06, tum=0.25, drop=0.08, wcf=0.5, d2=0.02, crown=0.04)
    cap.build("cap", "primary", mirror=True, regions=[R(peak - 2.2, peak + 1.9, 2.9, 3.1, "secondary", -0.02, side=1)])
    if front:
        cap.patch("lamp", peak - 2.45, peak - 1.5, 4.2, 5.0, "lights", off=0.03, mirror=True)
    for i, dz in enumerate((-0.7, 0.9)):
        box(f"strut{i}", ((4.82 + x) / 2 + 0.3, 0.3 + h / 2, peak + dz), (x - 5.4, 0.1, 0.14), "detail", mirror=True)
        box(f"post{i}", (5.2, 1.85 + h, peak + dz), (0.12, 0.5, 0.14), "detail", mirror=True)
    if lvl:   # a second, outer vane on the kits; a fence on the cap for the full kit
        vst = [(z, dict(yb=d["yb"] + 0.5, yt=d["yt"] - 0.35, ys=d["ys"])) for z, d in sst[1:3]]
        Hull(vst, cx=x + 0.45, w=0.05, rb=0.03, tum=0.02, drop=0.02, crown=0.0).build("vane", "secondary", mirror=True)
    if lvl > 1:
        blade("fence", 5.9, 2.2 + h, (2.68 if front else 2.85 + h), (peak - 1.0, peak + 1.3), (peak - 0.4, peak + 1.4), "secondary", t=0.04)


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
        slab("floor", [(-12.0, 2.0), (-11.0, 3.6), (-5.5, 3.75)], -0.44, -0.34, "detail", nt=6.0)
        for i, x in enumerate((1.3, 2.6)[:1 + (lvl > 0)]):
            blade(f"strut{i}", x, -0.36, 0.5, (-11.9 + i * 0.8, -10.6 + i * 0.8), (-11.3 + i * 0.8, -10.4 + i * 0.8),
                  "secondary", t=0.04)
        nose_splitter(lvl, -12.3, 2.4, 3.5, nt=7.0)
        if lvl:  # front wing flap above the splitter
            plane("flap", 3.7, -12.2 - lvl * 0.3, 0.3, -0.2, -0.1, "primary")

        K.begin(c, "FPOD", trim)
        f_engine(True, lvl)
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
        slab("floor", [(7.6, 3.6), (back - 0.4, 3.75), (back, 3.5)], -0.5, -0.42, "detail", nt=7.0)
        for i, x in enumerate(((1.0, 2.9), (1.0, 2.2, 3.1), (0.9, 1.7, 2.5, 3.2))[lvl]):
            dfin(f"fin{i}", x, ((8.6, -0.3), (10.4, 0.2), (back, 0.4 + lvl * 0.12)))
        blade("endplate", 3.55, -0.45, 1.7 + lvl * 0.15, (9.9, 11.5), (10.7, 11.5), "secondary", t=0.05)
        box("lamp", (3.55, 1.05, 11.53), (0.1, 0.9, 0.06), "lights_red", mirror=True)
        if lvl > 1:
            blade("fin", 0, 2.3, 3.85, (6.6, 10.2), (9.0, 10.25), "primary", t=0.06)

        K.begin(c, "RPOD", trim)
        f_engine(False, lvl)
        rear_corner(lvl)
        flange(3.8, 10.3, 1.0)

        # Stabiliser: a low floor tray with upright turning vanes.
        K.begin(c, "STAB", trim)
        slab("tray", [(-5.2, 0.85), (-4.4, 1.0), (3.4, 1.0)], -0.95, -0.55, "primary", cx=4.9, nt=6.0, mirror=True)
        slab("edge", [(-5.1, 0.95), (-4.4, 1.1), (3.4, 1.1)], -0.6, -0.5, "secondary", cx=4.9, nt=6.0, mirror=True)
        for i in range(3 + lvl):
            z = -4.2 + i * (2.4 - lvl * 0.45)
            blade(f"vane{i}", 5.2 + (i % 2) * 0.45, -0.55, 0.5 + lvl * 0.2 + (i % 2) * 0.2, (z, z + 1.3),
                  (z + 0.5, z + 1.2), "secondary" if i % 2 else "primary", t=0.04)
        box("lift0", (4.9, -0.97, -3.2), (1.4, 0.04, 1.4), "thrust", mirror=True)
        box("lift1", (4.9, -0.97, 0.6), (1.4, 0.04, 1.4), "thrust", mirror=True)
        box("line", (5.96, -0.72, -0.9), (0.06, 0.08, 7.6), "neon", mirror=True)

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
