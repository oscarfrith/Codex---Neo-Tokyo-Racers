"""Exotic pilot cars, refined: car A (sharp, Hyper) and car B (round, Curve).

Run inside Blender:  import cars; cars.build_all()
Slots: COCKPIT, NOSE, TAIL, FPOD (Front Engines), RPOD (Rear Engines), STAB, BOOST, WING.
Every module slot has three trims that share mounting and base surfaces:
  STD  the launch car: clean surfaces, small nozzles.
  LW   the track pack: more carbon, open arches, bigger vents, slimmer parts, a low wing.
  PWR  the ultimate edition: taller haunches, bigger nozzles and intakes, more light, a big wing.
The cockpit has one version.

Layout, round 6 (wider and lower):
  - Front engines are free-standing front fenders with the headlights; their jet exits over the sill.
  - Rear engines are the rear fenders, nozzle at the tail.
  - Each engine is a body-colour fender over a dark arch with a vented shell. No actual wheels.
  - Stabilisers are sill units between the fenders.
  - Body seams have a shadow gap: skins stop GAP short and a dark liner shows through.
  - The diffuser is the lower rear of the tail. The splitter is the chin of the nose.
  - Boost is the centre insert of the tail fascia, from diffuser height to the light line.

Car A is a wedge: prow leads, tall rear haunches, squared tail with strakes, burners in the diffuser.
Detail language: bars, slots, strakes, louvres.
Car B is a teardrop: fenders lead, nose recessed, round arches, drooping tail with a dorsal fin,
ring burners high in the tail. Detail language: circles and rings.
"""
import os

import exokit as K
from exokit import GAP, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Hull, Loft, R, box

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
SLOTS = ("COCKPIT", "NOSE", "TAIL", "FPOD", "RPOD", "STAB", "BOOST", "WING")
TRIMS = ("STD", "LW", "PWR")


def pick(trim, std, lw=None, pwr=None):
    return {"STD": std, "LW": std if lw is None else lw, "PWR": std if pwr is None else pwr}[trim]


def rect(stations, cx, w, yb, yt, c=0.12, axis="z"):
    """Chamfered rectangular tube."""
    return Hull(stations, axis=axis, cx=cx, w=w, yb=yb, yt=yt, rb=c, ys=yt - c, tum=c, drop=0.0,
                wcf=0.5, d2=0.0, crown=0.0)


def tube(z0, z1, x, y, r):
    return Loft([(z0, {}), (z1, {})], cx=x, w=r, yb=y - r, yt=y + r, nt=2, nb=2, yw=0.5)


def burner(name, z0, z1, x, y, r, depth=0.3):
    """Round nozzle tube with a recessed glowing back."""
    t = tube(z0, z1, x, y, r)
    t.build(name, "secondary", mirror=x != 0, caps=(True, False))
    t.throat(name + "n", "max", lip="secondary", back="thrust", scale=0.8, depth=depth, mirror=x != 0)


def lift_glow(hull, spans):
    for i, (t0, t1) in enumerate(spans):
        for side in (1, -1):
            hull.patch(f"lift{i}{side}", t0, t1, 0.2, 0.85, "thrust", side=side, mirror=True)


def blade(name, x, y0, y1, za, zb, ch, t=0.09):
    """Thin swept vertical blade (pylon or endplate). za and zb are (front, back) at y0 and y1."""
    Loft([(y0, dict(yb=za[0], yt=za[1])), (y1, dict(yb=zb[0], yt=zb[1]))], axis="y", cx=x, w=t,
         nt=2.2, nb=2.2, yw=0.4).build(name, ch, mirror=True)


def plane(name, span, z, chord, y0, y1, ch, tip=None):
    """Wing plane across the car. tip: (z, chord) at the ends for a swept or tapered plan."""
    tz, tc = tip or (z, chord)
    Loft([(-span, dict(cx=tz, w=tc)), (0, {}), (span, dict(cx=tz, w=tc))], axis="x", cx=z, w=chord, yb=y0, yt=y1,
         yw=0.6, nt=2.2, nb=2.6).build(name, ch)


def flange(z0, z1, y1):
    """Dark mounting flange between a pod and the body. It closes the gap from above."""
    box("flange", (3.92, (y1 - 0.3) / 2, (z0 + z1) / 2), (0.16, y1 + 0.3, z1 - z0), "detail", mirror=True)


def dfin(name, x, profile, ch="detail"):
    """Thin diffuser strake that fills the wedge under the tail kick-up. profile: (z, top y) points."""
    Loft([(z, dict(yt=y)) for z, y in profile], cx=x, w=0.035, yb=-0.42, nt=6, nb=6, yw=0.5).build(
        name, ch, mirror=True)


def louvres(surf, name, t0, t1, u0, u1, n, ch="secondary", off=-0.06, side=1, w=0.5):
    """n slats across a vent, standing between the vent floor and the skin."""
    step = (t1 - t0) / n
    for i in range(n):
        a = t0 + i * step + step * (1 - w) / 2
        surf.patch(f"{name}{i}", a, a + step * w, u0, u1, ch, side=side, off=off, mirror=True)


def tub(scallop=True):
    regs = [R(-5.2 + GAP, 2.8 - GAP, 0.0, 1.9, "secondary", 0.02)]
    if scallop:
        regs.append(R(-4.3, 2.0, 2.2, 2.88, "primary", 0.1))
    Hull([(-5.2, SEAM_F), (-1.0, dict(SEAM_F, yt=2.35)), (2.8, SEAM_R)]).build(
        "tub", "primary", t0=-5.2 + GAP, t1=2.8 - GAP, regions=regs)
    Hull([(-5.28, SEAM_F), (-1.0, dict(SEAM_F, yt=2.35)), (2.88, SEAM_R)]).build("liner", "detail", scale=0.96)


def shell(pod, peak, half, y0, y1, nt, rim="secondary", cover=True, bars=1):
    """Vented shell standing in an engine arch: a rim, a body-colour cover and light bars."""
    x = pod.params(peak)["cx"] + pod.params(peak)["w"]
    Loft([(x - 0.36, {}), (x - 0.12, {})], axis="x", cx=peak, w=half + 0.13, yb=y0 - 0.12, yt=y1 + 0.12,
         nt=nt, nb=nt, yw=0.5).build("rim", rim, mirror=True)
    if not cover:
        return
    Loft([(x - 0.3, {}), (x + 0.03, {})], axis="x", cx=peak, w=half, yb=y0, yt=y1, nt=nt, nb=nt,
         yw=0.5).build("cover", "primary", mirror=True)
    mid = (y0 + y1) / 2
    for i in range(bars):
        box(f"coverbar{i}", (x + 0.04, mid + 0.12 - i * 0.32, peak), (0.06, 0.08, half * 1.2), "neon", mirror=True)


# ---------------------------------------------------------------- car A: sharp

A_POD = dict(rb=0.35, tum=0.42, drop=0.28, tumi=0.03, dropi=0.12, wcf=0.45, d2=0.04, crown=0.06, cs=0.03)


def a_pod(pod, z0, z1, peak, trim, extra=(), arch_slats=0, caps=(False, False)):
    """Flowing fender over a dark arch, carbon rocker, louvred vent on top, vented shell in the arch."""
    vent = pick(trim, (peak - 1.2, peak + 0.8, 4), (peak - 1.5, peak + 1.0, 6))
    pod.build("skin", "primary", mirror=True, caps=caps, regions=[
        R(z0 + 0.25, z1 - 0.2, 1.0, pick(trim, 2.05, 2.7), "secondary", 0.02),
        R(peak - 1.7, peak + 1.7, 1.25, 2.92, "detail", 0.35, side=1),
        R(vent[0], vent[1], 4.18, 4.92, "detail", 0.12, side=1), *extra])
    louvres(pod, "top", vent[0] + 0.1, vent[1] - 0.1, 4.24, 4.86, vent[2], off=-0.05)
    slats = [arch_slats] if arch_slats else []
    if trim == "PWR":
        slats = [1, -1]
    for s in slats:
        for i in range(4):
            t = peak + s * (1.58 - i * 0.13)
            pod.patch(f"arch{s}{i}", t - 0.03, t + 0.03, 1.4, 2.85, "secondary", off=-0.18, mirror=True)
    if trim == "LW":  # open arch: no cover, upright vanes instead
        shell(pod, peak, 1.3, -0.8, 0.95, 3.2, cover=False)
        for i in range(7):
            t = peak - 0.9 + i * 0.3
            pod.patch(f"vane{i}", t - 0.04, t + 0.04, 1.4, 2.85, "secondary", off=-0.12, mirror=True)
    else:
        shell(pod, peak, 1.3, -0.8, 0.95, 3.2, bars=pick(trim, 1, 1, 2))
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])


def a_cockpit():
    K.begin("A", "COCKPIT")
    tub()
    can = Hull([(-6.7, dict(w=2.6, yb=1.8, yt=2.1, ys=2.0, tum=0.3, drop=0.02)),
                (-4.6, dict(w=3.2, yt=3.15, tum=0.85)),
                (-2.4, dict(yt=4.05)), (-0.4, dict(yt=4.25)), (1.6, dict(w=3.2, yt=4.15)),
                (4.2, dict(w=2.9, yb=2.2, yt=3.45, ys=2.35)),
                (7.2, dict(w=2.3, yb=2.35, yt=2.75, ys=2.5, tum=0.7, drop=0.1))],
               w=3.3, yb=1.9, ys=2.2, rb=0.1, tum=1.25, drop=0.16, wcf=0.7, d2=0.03, crown=0.05)
    can.build("canopy", "primary", regions=[
        R(-6.45, -2.6, 3.06, 6.0, "glass", 0.03), R(-2.35, 1.7, 3.08, 3.9, "glass", 0.03),
        R(-2.35, 1.9, 4.12, 6.0, "secondary", 0.02), R(2.2, 5.8, 3.15, 3.8, "glass", 0.03),
        *[R(2.4 + i * 0.9, 2.9 + i * 0.9, 4.2, 6.0, "detail", 0.1) for i in range(5)]])


def a_nose(trim):
    """Rounded prow over a recessed grille and a curved splitter; the hood sinks between the fenders."""
    K.begin("A", "NOSE", trim)
    nose = Hull([(-12.6, dict(w=1.5, yb=0.2, yt=0.45, rb=0.08, ys=0.3, tum=0.15, drop=0.06)),
                 (-12.2, dict(w=2.5, yb=0.15, yt=0.6, rb=0.1, ys=0.34, tum=0.2, drop=0.12)),
                 (-11.4, dict(w=3.3, yb=0.1, yt=0.82, rb=0.15, ys=0.45, tum=0.22, drop=0.2)),
                 (-10.4, dict(w=3.7, yt=1.02, ys=0.5, tum=0.25, drop=0.25)),
                 (-8.5, dict(w=3.8, yt=1.35, ys=0.8, tum=0.3, drop=0.3)),
                 (-6.6, dict(w=3.8, yt=1.85, ys=1.1, tum=0.35, drop=0.3, crown=0.05)), (-5.2, SEAM_F)],
                yb=-0.4, rb=0.45, wcf=0.62, d2=0.06, crown=0.04)
    vent = pick(trim, (-9.9, -7.4, 6), (-9.9, -7.4, 6), (-10.5, -7.2, 8))
    regs = [R(-12.5, -10.5, 2.86, 3.0, "lights", -0.01),
            R(vent[0], vent[1], 4.15, 4.85, "detail", 0.18)]
    if trim == "LW":    # the hood centre opens into a louvred duct
        regs.append(R(-11.0, -7.2, 5.0, 6.0, "detail", 0.14))
    elif trim == "PWR":  # raised power bulge and a second light line
        regs.append(R(-11.2, -7.0, 5.0, 6.0, "secondary", -0.05))
        regs.append(R(-12.2, -10.7, 3.25, 3.36, "lights", -0.01))
    else:
        regs.append(R(-11.2, -7.0, 5.0, 6.0, "secondary", 0.03))
    nose.build("skin", "primary", t1=-5.2 - GAP, regions=regs)
    louvres(nose, "hood", vent[0] + 0.1, vent[1] - 0.1, 4.2, 4.8, vent[2], off=-0.1)
    if trim == "LW":
        louvres(nose, "duct", -10.8, -7.4, 5.06, 5.97, 7, off=-0.07)
    top = pick(trim, 0.3, 0.3, 0.42)
    jaw = Loft([(-12.3, dict(w=1.9)), (-11.9, dict(w=2.9)), (-11.2, dict(w=3.4)), (-10.5, dict(w=3.5))],
               yb=-0.4, yt=top, nt=5, nb=5)
    jaw.build("jaw", "secondary", caps=(False, True))
    jaw.throat("grille", "min", lip="secondary", scale=0.88, depth=0.5)
    Loft([(-12.7, dict(w=pick(trim, 1.6, 1.6, 1.9))), (-12.4, dict(w=2.7)), (-11.7, dict(w=3.45)),
          (-10.8, dict(w=3.78))], yb=-0.52, yt=-0.42, nt=5, nb=5).build("splitter", "secondary")
    if trim == "PWR":
        for i, x in enumerate((1.2, 2.4)):
            box(f"keel{i}", (x, -0.62, -11.9), (0.06, 0.2, 1.1), "detail", mirror=True)


def a_fpod(trim):
    """Free-standing front fender: rounded prow, slim headlight under a lid, strake recess, splitter corner."""
    K.begin("A", "FPOD", trim)
    up = pick(trim, 0.0, 0.0, 0.1)
    pod = Hull([(-11.9, dict(cx=5.0, w=0.35, wi=0.35, yb=0.35, yt=0.75, ys=0.5, rb=0.1, tum=0.1, drop=0.08,
                             dropi=0.08)),
                (-11.5, dict(cx=5.02, w=0.8, wi=0.75, yb=-0.1, yt=1.15, ys=0.55, rb=0.2)),
                (-10.8, dict(cx=5.08, w=1.12, wi=0.95, yb=-0.6, yt=1.6 + up / 2, ys=0.75)),
                (-9.8, dict(cx=5.15, w=1.28, wi=1.05, yb=-1.0, yt=2.05 + up, ys=1.0)),
                (-8.3, dict(cx=5.18, w=1.3, wi=1.12, yb=-1.1, yt=2.25 + up, ys=1.15)),
                (-6.8, dict(cx=5.12, w=1.2, wi=1.15, yb=-0.9, yt=1.95 + up, ys=1.0)),
                (-5.4, dict(SIDE_F, yb=-0.1, yt=1.45, ys=0.7, rb=0.2))], **A_POD)
    extra = [R(-11.65, -10.45, 3.3, 4.2, "glass", 0.1, side=1),
             R(-11.05, -10.15, 1.25, 2.72, "detail", 0.22, side=1),
             R(-11.8, -10.0, 2.82, 2.96, "lights", -0.01, side=1)]
    a_pod(pod, -11.9, -5.4, -8.3, trim, extra=extra, caps=(True, False))
    pod.patch("lamp", -11.5, -10.6, 3.5, 3.9, "lights", off=-0.05, mirror=True)
    if trim == "PWR":
        pod.patch("lamp2", -11.45, -10.65, 4.0, 4.12, "lights", off=-0.05, mirror=True)
    for i, u in enumerate(pick(trim, (1.5, 1.95, 2.4), (1.65, 2.25))):
        pod.patch(f"strake{i}", -10.98, -10.22, u, u + 0.14, "primary", off=-0.06, mirror=True)
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=pick(trim, 0.78, 0.78, 0.86), depth=0.5,
               mirror=True)
    Loft([(-12.05, dict(w=0.5)), (-11.7, dict(w=1.1)), (-10.9, dict(w=1.35))], cx=5.12, yb=-0.52, yt=-0.42,
         nt=5, nb=5).build("splitter", "secondary", mirror=True)
    if trim == "PWR":  # dive plane on the fender flank
        box("canard", (6.28, 0.55, -10.7), (0.5, 0.06, 1.1), "secondary", mirror=True)
    box("channel", (4.02, -0.05, -8.2), (0.42, 0.5, 5.2), "detail", mirror=True)


def a_tail(trim):
    K.begin("A", "TAIL", trim)
    end = pick(trim, 2.65, 2.65, 2.85)
    tail = Hull([(2.8, SEAM_R), (5.5, dict(yt=2.6)), (8.6, dict(yt=2.6, ys=1.5, tum=0.28, drop=0.3)),
                 (10.0, dict(yb=0.0, yt=2.6, ys=1.6, tum=0.25, drop=0.28)),
                 (11.2, dict(w=3.75, yb=0.45, yt=end, ys=1.7, tum=0.22, drop=0.25, rb=0.3))],
                **{**SEAM_R, "crown": 0.03})
    cover = R(7.7, 10.4, 5.1, 6.0, "detail", 0.14) if trim == "LW" else R(7.7, 10.4, 5.1, 6.0, "secondary", 0.03)
    tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
        R(8.6, 11.2, 0.0, 2.3, "secondary", 0.02), cover, R(6.4, 10.2, 4.2, 4.85, "detail", 0.15)])
    louvres(tail, "deck", 6.5, 10.1, 4.25, 4.8, 8, off=-0.08)
    if trim == "LW":
        louvres(tail, "cover", 7.85, 10.25, 5.16, 5.97, 6, off=-0.07)
    tail.throat("fascia", "max", lip="primary", scale=0.93, depth=0.3)
    box("blade", (0, 2.36, 11.02), (6.6, 0.1, 0.16), "lights_red")
    if trim == "PWR":
        box("blade2", (3.0, 2.14, 11.02), (0.78, 0.06, 0.16), "lights_red", mirror=True)
    for i, y in enumerate(pick(trim, (2.1, 1.85, 1.6, 1.35, 1.1, 0.85), (1.95, 1.45, 0.95),
                               (1.9, 1.65, 1.4, 1.15, 0.9))):
        box(f"strake{i}", (3.0, y, 11.04), (0.78, 0.09, 0.2), "primary", mirror=True)
    for i, x in enumerate(pick(trim, (2.8, 3.25), (3.0,), (2.75, 3.1, 3.45))):
        dfin(f"fin{i}", x, ((9.4, -0.32), (10.4, 0.0), (11.3, 0.3)))


def a_rpod(trim):
    K.begin("A", "RPOD", trim)
    up = pick(trim, 0.0, 0.0, 0.14)
    pod = Hull([(3.6, dict(SIDE_R, yb=-0.5, yt=1.6)),
                (4.8, dict(cx=5.12, w=1.22, wi=1.18, yb=-1.0, yt=2.15 + up / 2, ys=1.15)),
                (6.4, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.65 + up, ys=1.5)),
                (7.8, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.8 + up, ys=1.6)),
                (9.4, dict(cx=5.16, w=1.25, wi=1.2, yb=-1.0, yt=2.6 + up, ys=1.55)),
                (10.6, dict(cx=5.12, w=1.12, wi=1.15, yb=-0.6, yt=2.2 + up, ys=1.4))], **A_POD)
    a_pod(pod, 3.6, 10.6, 7.3, trim, arch_slats=-1)
    pod.throat("intake", "min", lip="primary", scale=0.8, depth=0.5, mirror=True)
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=pick(trim, 0.82, 0.82, 0.88), depth=0.6,
               mirror=True)
    mid = 0.8 + up / 2
    for i, y in enumerate(pick(trim, (mid - 0.5, mid, mid + 0.5), (), (mid - 0.66, mid - 0.22, mid + 0.22, mid + 0.66))):
        box(f"slat{i}", (5.12, y, 10.42), (1.7, 0.07, 0.3), "detail", mirror=True)
    flange(3.8, 10.3, 1.0)


def a_stab(trim):
    K.begin("A", "STAB", trim)
    w, cx = pick(trim, (1.0, 4.9), (0.86, 4.78))
    rear = pick(trim, 1.55, 1.55, 1.72)
    sill = Hull([(-5.2, dict(yb=-0.8, yt=0.4, ys=0.0)), (-2.0, dict(yt=0.65, ys=0.15)),
                 (1.5, dict(yt=1.3, ys=0.7)), (3.4, dict(yb=-0.7, yt=rear, ys=0.9))],
                cx=cx, w=w, yb=-0.9, rb=0.25, tum=0.3, drop=0.12, wcf=0.5, d2=0.03, crown=0.04)
    regs = [R(-5.2, 3.4, 1.0, pick(trim, 2.25, 2.95), "secondary", 0.02),
            R(-5.0, 3.2, 2.3, 2.38, "neon", -0.01, side=1),
            R(pick(trim, 0.5, -0.4), 3.15, 3.1, 3.9, "detail", 0.15, side=1)]
    if trim == "PWR":
        regs.append(R(-5.0, 3.2, 2.52, 2.6, "neon", -0.01, side=1))
    sill.build("skin", "primary", mirror=True, regions=regs)
    louvres(sill, "intake", pick(trim, 0.6, -0.3), 3.05, 3.15, 3.85, pick(trim, 6, 8), off=-0.08)
    box("skirt", (cx + w - 0.1, -0.95, -0.9), (0.5, 0.06, 8.2), "secondary", mirror=True)
    if trim == "PWR":
        blade("winglet", cx + w - 0.05, 1.0, 1.85, (2.2, 3.35), (2.7, 3.4), "secondary", t=0.05)
    lift_glow(sill, [(-4.2, -2.4), (-0.6, 1.4)])


def a_boost(trim):
    """Centre insert of the tail fascia: strake panel above, burners low in a carbon housing."""
    K.begin("A", "BOOST", trim)
    box("panel", (0, 1.4, 10.98), (5.1, 1.1, 0.1), "detail")
    for i, y in enumerate(pick(trim, (1.85, 1.6, 1.35, 1.1), (1.75, 1.25), (1.85, 1.6))):
        box(f"strake{i}", (0, y, 11.06), (5.0, 0.09, 0.2), "primary")
    top = pick(trim, 0.85, 0.85, 1.0)
    Hull([(10.7, dict(w=2.5, yb=-0.42, yt=top)), (11.5, dict(w=2.3, yb=-0.3, yt=top - 0.05))], rb=0.3, ys=0.5,
         tum=0.3, drop=0.0, wcf=0.5, d2=0.0, crown=0.0).build("housing", "secondary")
    if trim == "LW":   # one wide burner
        t = Loft([(11.2, {}), (12.0, {})], cx=0, w=1.7, yb=-0.2, yt=0.62, nt=5, nb=5, yw=0.5)
        t.build("burner", "secondary", caps=(True, False))
        t.throat("noz", "max", lip="secondary", back="thrust", scale=0.86, depth=0.35)
        return
    hi = pick(trim, 0.62, 0.62, 0.78)
    t = Loft([(11.2, {}), (12.0, {})], cx=1.1, w=pick(trim, 0.8, 0.8, 0.9), yb=-0.22, yt=hi, nt=5, nb=5, yw=0.5)
    t.build("burner", "secondary", mirror=True, caps=(True, False))
    t.throat("noz", "max", lip="secondary", back="thrust", scale=0.84, depth=0.35, mirror=True)
    box("divider", (0, 0.2, 11.75), (0.06, 0.9, 0.7), "detail")
    if trim == "PWR":  # two small upper burners between the strakes
        for i, x in enumerate((0.55, 1.65)):
            burner(f"mini{i}", 11.0, 11.7, x, 1.3, 0.2, depth=0.2)


def a_wing(trim):
    K.begin("A", "WING", trim)
    if trim == "LW":    # low carbon blade, no endplates
        plane("plane", 3.7, 11.0, 0.5, 3.3, 3.42, "secondary", tip=(11.15, 0.4))
        blade("pylon", 2.9, 1.8, 3.34, (10.4, 11.1), (10.75, 11.25), "secondary")
        box("tip", (3.72, 3.36, 11.15), (0.08, 0.24, 0.9), "primary", mirror=True)
    elif trim == "PWR":  # two-element wing with tall endplates
        plane("plane", 3.9, 10.95, 0.9, 4.2, 4.4, "primary", tip=(11.1, 0.7))
        plane("flap", 3.9, 11.75, 0.38, 4.62, 4.74, "primary", tip=(11.8, 0.32))
        blade("pylon", 2.9, 1.8, 4.24, (10.0, 11.1), (10.5, 11.5), "secondary")
        blade("plate", 3.94, 3.5, 4.95, (10.2, 12.0), (10.6, 12.25), "secondary", t=0.06)
    else:
        plane("plane", 3.9, 11.05, 0.8, 3.9, 4.08, "primary", tip=(11.2, 0.6))
        blade("pylon", 2.9, 1.8, 3.94, (10.0, 11.1), (10.6, 11.5), "secondary")
        blade("plate", 3.92, 3.6, 4.35, (10.5, 11.9), (10.9, 12.1), "secondary", t=0.06)


def car_a():
    a_cockpit()
    for trim in TRIMS:
        a_nose(trim)
        a_fpod(trim)
        a_tail(trim)
        a_rpod(trim)
        a_stab(trim)
        a_boost(trim)
        a_wing(trim)


# ---------------------------------------------------------------- car B: round

B_POD = dict(rb=0.5, tum=0.55, drop=0.35, tumi=0.03, dropi=0.14, wcf=0.35, d2=0.03, crown=0.14)
B_END = dict(rb=0.3, wcf=0.6, d2=0.02, drop=0.2, tum=0.25, crown=0.03)


def b_pod(pod, z0, z1, peak, caps, trim):
    """Round fender over a dark arch: carbon rocker, raised crest, louvred vent, round vented shell."""
    vent = pick(trim, (peak - 1.0, peak + 0.6, 3), (peak - 1.4, peak + 0.9, 5))
    pod.build("skin", "primary", mirror=True, caps=caps, regions=[
        R(z0 + 0.4, z1 - 0.3, 1.0, pick(trim, 2.15, 2.7), "secondary", 0.02),
        R(peak - 1.5, peak + 1.5, 1.3, 2.9, "detail", 0.3, side=1),
        R(vent[0], vent[1], 4.2, 4.95, "detail", 0.12, side=1),
        R(z0 + 0.9, z1 - 0.7, 5.62, 6.0, "secondary", pick(trim, -0.04, -0.04, -0.1)),
        R(z1 - 0.2, z1 - 0.07, 0.0, 6.0, "neon", -0.01)])
    louvres(pod, "top", vent[0] + 0.1, vent[1] - 0.1, 4.26, 4.89, vent[2], off=-0.05)
    shell(pod, peak, 1.15, -0.72, 1.0, 2.0, rim="neon", cover=trim != "LW", bars=pick(trim, 1, 1, 2))
    x = pod.params(peak)["cx"] + pod.params(peak)["w"]
    r = pick(trim, 0.3, 0.42, 0.36)
    Loft([(x - 0.3 if trim == "LW" else x - 0.1, {}), (x + 0.1, {})], axis="x", cx=peak, w=r, yb=0.14 - r,
         yt=0.14 + r, nt=2, nb=2, yw=0.5).build("hub", "secondary", mirror=True)
    if trim == "LW":   # open arch: spokes of light instead of a cover
        for i, (dz, dy) in enumerate(((0.75, 0.0), (-0.75, 0.0), (0.0, 0.62), (0.0, -0.62))):
            box(f"spoke{i}", (x - 0.15, 0.14 + dy, peak + dz), (0.08, 0.1 if dy == 0 else 0.5, 0.6 if dy == 0 else 0.1),
                "secondary", mirror=True)
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=pick(trim, 0.8, 0.8, 0.88), depth=0.4, mirror=True)


def b_cockpit():
    K.begin("B", "COCKPIT")
    tub(scallop=False)
    can = Loft([(-6.7, dict(w=2.0, yb=1.8, yt=2.08)), (-4.8, dict(w=2.8, yt=3.2)), (-2.4, dict(w=3.05, yt=4.35)),
                (-0.4, dict(w=3.0, yt=4.6)), (2.0, dict(w=2.7, yt=4.3)),
                (4.6, dict(w=2.0, yb=2.15, yt=3.55)), (7.3, dict(w=0.9, yb=2.3, yt=2.7))],
               yb=1.95, yw=0.1, nt=2.3, nb=3.0)
    can.build("canopy", "primary", regions=[
        R(-6.3, 6.8, 8, 172, "glass", 0.03), R(-2.0, 7.2, 85, 95, "secondary", -0.04),
        R(1.1, 1.6, 8, 172, "secondary", -0.04), R(-2.4, -2.0, 8, 172, "secondary", -0.04)])


def b_nose(trim):
    """Pointed prow recessed between the fenders, round centre intake, raised spine, carbon tray."""
    K.begin("B", "NOSE", trim)
    nose = Hull([(-11.2, dict(w=1.7, yb=0.0, yt=0.7, rb=0.25, ys=0.35, tum=0.3, drop=0.2, wcf=0.55, d2=0.03)),
                 (-10.3, dict(w=2.8, yb=-0.3, yt=1.15, ys=0.55, tum=0.45, drop=0.35)),
                 (-8.9, dict(w=3.6, yt=1.7, ys=0.9, tum=0.5, drop=0.42)),
                 (-7.0, dict(w=3.8, yt=2.1, ys=1.25, tum=0.38, drop=0.3, wcf=0.4, crown=0.07)),
                 (-5.2, SEAM_F)], creases=(1, 2, 3), yb=-0.4, rb=0.5, wcf=0.2, d2=0.12, crown=0.12)
    vent = pick(trim, (-8.6, -7.0, 4), (-9.2, -6.8, 6))
    spine = (R(-10.6, -5.8, 5.4, 6.0, "detail", 0.12) if trim == "LW"
             else R(-10.9, -5.6, 5.3, 6.0, "secondary", pick(trim, -0.03, -0.03, -0.07)))
    nose.build("skin", "primary", t1=-5.2 - GAP, caps=(False, True), regions=[
        spine, R(vent[0], vent[1], 4.25, 4.85, "detail", 0.14)])
    louvres(nose, "hood", vent[0] + 0.1, vent[1] - 0.1, 4.3, 4.8, vent[2], off=-0.07)
    if trim == "LW":
        louvres(nose, "spine", -10.4, -6.0, 5.45, 5.97, 9, off=-0.06)
    nose.throat("mouth", "min", lip="primary", scale=pick(trim, 0.78, 0.78, 0.88), depth=0.5)
    Loft([(-11.75, dict(w=2.2)), (-11.2, dict(w=3.2)), (-10.3, dict(w=3.6)), (-8.8, dict(w=3.75))],
         yb=-0.42, yt=0.1, nt=4, nb=5).build("tray", "secondary")
    Loft([(-11.65, dict(w=2.0)), (-11.2, dict(w=3.0)), (-10.3, dict(w=3.45)), (-8.9, dict(w=3.6))],
         yb=0.0, yt=0.14, nt=4, nb=5).build("floor", "detail")
    Loft([(-11.95, dict(w=pick(trim, 2.3, 2.3, 2.7))), (-11.4, dict(w=3.3)), (-10.5, dict(w=3.78))],
         yb=-0.52, yt=-0.44, nt=4, nb=5).build("splitter", "secondary")
    if trim == "PWR":  # twin nostril intakes on the tray
        for side in (1,):
            t = tube(-11.2, -10.3, 2.35, 0.38, 0.26)
            t.build("nostril", "secondary", mirror=True, caps=(False, True))
            t.throat("nostriln", "min", lip="secondary", scale=0.8, depth=0.3, mirror=True)


def b_fpod(trim):
    """Round fender that leads the car, with round lamps set into its front face."""
    K.begin("B", "FPOD", trim)
    up = pick(trim, 0.0, 0.0, 0.08)
    pod = Hull([(-12.3, dict(cx=5.0, w=0.85, wi=0.9, yb=-0.2, yt=0.95, ys=0.4, **B_END)),
                (-11.3, dict(cx=5.06, w=1.1, wi=1.08, yb=-0.7, yt=1.6 + up / 2, ys=0.7)),
                (-9.9, dict(cx=5.12, w=1.22, wi=1.15, yb=-1.0, yt=2.15 + up, ys=1.0)),
                (-8.4, dict(cx=5.15, w=1.25, wi=1.18, yb=-1.05, yt=2.3 + up, ys=1.1)),
                (-6.6, dict(cx=5.08, w=1.08, wi=1.1, yb=-0.6, yt=1.7 + up, ys=0.8)),
                (-5.4, dict(cx=4.95, w=0.78, wi=0.92, yb=0.1, yt=1.2, ys=0.65, **B_END))],
               creases=(1, 2), **B_POD)
    b_pod(pod, -12.3, -5.4, -8.6, (False, False), trim)
    pod.throat("housing", "min", lip="primary", scale=0.9, depth=0.3, mirror=True)
    lamps = pick(trim, ((4.7, 0.42, 0.3), (5.36, 0.36, 0.22)), ((5.0, 0.4, 0.36),),
                 ((4.62, 0.44, 0.27), (5.2, 0.4, 0.22), (5.62, 0.36, 0.14)))
    for i, (x, y, r) in enumerate(lamps):
        lamp = tube(-12.26, -12.02, x, y, r)
        lamp.build(f"lamp{i}", "secondary", mirror=True, caps=(False, True))
        lamp.throat(f"lens{i}", "min", lip="secondary", back="lights", scale=0.78, depth=0.06, mirror=True)
    Loft([(-12.4, dict(w=0.7)), (-12.0, dict(w=1.2)), (-11.2, dict(w=1.38))], cx=5.08, yb=-0.52, yt=-0.44,
         nt=4, nb=5).build("splitter", "secondary", mirror=True)
    flange(-8.8, -5.6, 0.5)


def b_tail(trim):
    """Drooping round tail with a dorsal fin, round lamps and a louvred deck."""
    K.begin("B", "TAIL", trim)
    tail = Hull([(2.8, SEAM_R), (5.5, dict(w=3.75, yt=2.55, tum=0.5, drop=0.42, crown=0.1)),
                 (8.5, dict(w=3.6, yb=-0.2, yt=2.3, ys=1.25, tum=0.7, drop=0.5, rb=0.7)),
                 (11.2, dict(w=3.4, yb=0.3, yt=2.0, ys=1.15, tum=0.8, drop=0.55, rb=0.85))],
                creases=(1, 2, 3), **{**SEAM_R, "rb": 0.5, "wcf": 0.3, "d2": 0.1, "crown": 0.14})
    vent = pick(trim, (6.2, 9.8, 4.25, 4.85, 7), (5.6, 10.0, 4.15, 5.0, 9))
    tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
        R(8.8, 11.2, 0.0, 2.2, "secondary", 0.02), R(3.0, 7.4, 5.3, 6.0, "secondary", -0.03),
        R(vent[0], vent[1], vent[2], vent[3], "detail", 0.14)])
    louvres(tail, "deck", vent[0] + 0.1, vent[1] - 0.1, vent[2] + 0.05, vent[3] - 0.05, vent[4], off=-0.07)
    tail.throat("fascia", "max", lip="primary", scale=0.9, depth=0.25)
    for i, (x, y, r) in enumerate(pick(trim, ((2.82, 1.2, 0.24),), None, ((2.84, 1.38, 0.2), (2.84, 0.9, 0.15)))):
        lamp = tube(10.96, 11.2, x, y, r)
        lamp.build(f"lamp{i}", "secondary", mirror=True, caps=(True, False))
        lamp.throat(f"lens{i}", "max", lip="secondary", back="lights_red", scale=0.78, depth=0.06, mirror=True)
    if trim != "LW":
        top = pick(trim, 2.98, 2.98, 3.08)
        fin = Loft([(7.4, dict(yt=2.6)), (10.2, dict(yt=top)), (11.15, dict(yt=2.2))], w=0.09, yb=1.85, nt=2, nb=2)
        fin.build("fin", "secondary")
    box("rain", (0, 2.3, 11.2), (0.16, 0.45, 0.08), "lights_red")
    for i, x in enumerate(pick(trim, (2.75,), (2.75,), (2.7, 3.0))):
        dfin(f"vane{i}", x, ((9.4, -0.2), (10.4, 0.1), (11.3, 0.35 + (x - 2.7) * 0.6)))


def b_rpod(trim):
    K.begin("B", "RPOD", trim)
    up = pick(trim, 0.0, 0.0, 0.15)
    pod = Hull([(3.6, dict(cx=4.98, w=0.85, wi=0.95, yb=-0.3, yt=1.35, ys=0.7, rb=0.3)),
                (5.2, dict(cx=5.1, w=1.18, wi=1.14, yb=-0.95, yt=2.05 + up, ys=1.0)),
                (7.0, dict(cx=5.15, w=1.25, wi=1.18, yb=-1.05, yt=2.25 + up, ys=1.1)),
                (9.2, dict(cx=5.06, w=1.02, wi=1.06, yb=-0.5, yt=1.9 + up, ys=1.0)),
                (10.6, dict(cx=4.88, w=0.68, wi=0.8, yb=0.2, yt=1.45 + up / 2, ys=0.85, **B_END))],
               creases=(1, 2), **B_POD)
    b_pod(pod, 3.6, 10.6, 6.9, (False, False), trim)
    pod.throat("intake", "min", lip="primary", scale=0.78, depth=0.4, mirror=True)
    flange(3.8, 10.0, 0.9)


def b_stab(trim):
    K.begin("B", "STAB", trim)
    k = pick(trim, 1.0, 0.86)
    rear = pick(trim, 1.1, 1.1, 1.35)
    sill = Hull([(-5.2, dict(w=0.6 * k, yb=-0.6, yt=0.25, ys=-0.1)), (-2.5, dict(w=0.9 * k, yt=0.7, ys=0.15)),
                 (1.0, dict(w=1.0 * k, yt=1.3, ys=0.6)), (3.4, dict(w=0.75 * k, yb=-0.5, yt=rear, ys=0.5))],
                creases=(1, 2), cx=4.8 - (1 - k) * 0.9, yb=-0.9, rb=0.35, tum=0.4, drop=0.25, wcf=0.4, d2=0.03,
                crown=0.12)
    regs = [R(-4.9, 3.1, 1.0, pick(trim, 2.3, 2.95), "secondary", 0.02),
            R(pick(trim, 0.7, -0.2), 2.7, 3.15, 3.85, "detail", 0.13, side=1)]
    if trim == "PWR":
        regs.append(R(-4.6, 2.9, 2.5, 2.6, "neon", -0.01, side=1))
    sill.build("skin", "primary", mirror=True, regions=regs)
    louvres(sill, "intake", pick(trim, 0.8, -0.1), 2.6, 3.2, 3.8, pick(trim, 4, 6), off=-0.07)
    lift_glow(sill, [(-4.0, -2.4), (-0.6, 1.2)])


def b_boost(trim):
    """Ring burners high in the tail, with a small keel below."""
    K.begin("B", "BOOST", trim)
    w = pick(trim, 0.98, 0.98, 1.1)
    Loft([(10.8, dict(w=w)), (11.6, dict(w=w - 0.08, yb=0.22, yt=1.93))],
         yb=0.15, yt=2.0, nt=2, nb=2, yw=0.5).build("shroud", "primary")
    if trim == "LW":     # two large rings, stacked
        for i, dy in enumerate((0.44, -0.44)):
            burner(f"burner{i}", 11.2, 12.15, 0, 1.08 + dy, 0.4)
    elif trim == "PWR":  # one large ring with four small ones around it
        burner("core", 11.2, 12.2, 0, 1.08, 0.46)
        for i, dy in enumerate((0.5, -0.5)):
            burner(f"burner{i}", 11.2, 12.0, 0.64, 1.08 + dy, 0.2)
    else:
        for i, dy in enumerate((0.38, -0.38)):
            burner(f"burner{i}", 11.2, 12.15, 0.38, 1.08 + dy, 0.31)
    box("keel", (0, -0.05, 11.2), (0.1, 0.6, 0.9), "secondary")


def b_wing(trim):
    K.begin("B", "WING", trim)
    if trim == "LW":    # two short flicks over the rear engines
        Loft([(2.5, dict(w=0.38, cx=10.85)), (3.9, dict(w=0.5, cx=11.0))], axis="x", yb=2.5, yt=2.62, yw=0.6,
             nt=2.2, nb=2.6).build("flick", "primary", mirror=True)
        blade("pylon", 3.0, 1.25, 2.54, (10.5, 11.0), (10.65, 11.15), "secondary")
    elif trim == "PWR":  # biplane: the gull blade with a straight upper blade between endplates
        Loft([(-3.9, dict(cx=11.05, w=0.45, yb=2.75, yt=2.87)), (0, {}), (3.9, dict(cx=11.05, w=0.45, yb=2.75, yt=2.87))],
             axis="x", cx=10.75, w=0.7, yb=2.85, yt=3.0, yw=0.6, nt=2.2, nb=2.6).build("blade", "primary")
        plane("upper", 3.9, 11.3, 0.45, 3.5, 3.62, "primary")
        blade("pylon", 2.6, 1.25, 2.84, (9.9, 11.15), (10.35, 11.25), "secondary", t=0.11)
        blade("plate", 3.92, 2.6, 3.8, (10.5, 11.6), (10.8, 11.85), "secondary", t=0.06)
    else:               # one low gull blade
        Loft([(-3.9, dict(cx=11.05, w=0.45, yb=2.75, yt=2.87)), (0, {}), (3.9, dict(cx=11.05, w=0.45, yb=2.75, yt=2.87))],
             axis="x", cx=10.75, w=0.7, yb=2.85, yt=3.0, yw=0.6, nt=2.2, nb=2.6).build("blade", "primary")
        blade("pylon", 2.6, 1.25, 2.84, (9.9, 11.15), (10.35, 11.25), "secondary", t=0.11)


def car_b():
    b_cockpit()
    for trim in TRIMS:
        b_nose(trim)
        b_fpod(trim)
        b_tail(trim)
        b_rpod(trim)
        b_stab(trim)
        b_boost(trim)
        b_wing(trim)


# ---------------------------------------------------------------- builds and sheets

def kit(base, swaps=None, trim="STD", **override):
    swaps = swaps or {}
    keys = {s: f"{swaps.get(s, base)}_{s}_{'STD' if s == 'COCKPIT' else trim}" for s in SLOTS}
    keys.update(override)
    return list(keys.values())


PODS = ("FPOD", "RPOD", "STAB")
REAR = ("TAIL", "BOOST", "WING")
ROWS = {
    "pure": (0, [kit("A"), kit("B")]),
    "trims_a": (-45, [kit("A", trim=t) for t in TRIMS]),
    "trims_b": (-90, [kit("B", trim=t) for t in TRIMS]),
    "swaps_on_a": (45, [kit("A", {"NOSE": "B"}), kit("A", {s: "B" for s in PODS}),
                        kit("A", {s: "B" for s in REAR}), kit("A", {s: "B" for s in SLOTS if s != "COCKPIT"})]),
    "swaps_on_b": (90, [kit("B", {"NOSE": "A"}), kit("B", {s: "A" for s in PODS}),
                        kit("B", {s: "A" for s in REAR}), kit("B", {s: "A" for s in SLOTS if s != "COCKPIT"})]),
}
SPACING = 17.0
# Preview paints for the mixed builds: name, primary, secondary.
PAINTS = (
    ("white", (0.82, 0.82, 0.8), (0.02, 0.02, 0.024)),
    ("blue", (0.02, 0.07, 0.42), (0.55, 0.57, 0.6)),
    ("orange", (0.9, 0.23, 0.02), (0.02, 0.02, 0.024)),
    ("green", (0.02, 0.2, 0.09), (0.55, 0.45, 0.25)),
    ("black", (0.015, 0.015, 0.018), (0.55, 0.03, 0.03)),
)


def build_all(render=True, paints=False):
    K.reset()
    car_a()
    car_b()
    problems = K.check()
    for row, (oz, builds) in ROWS.items():
        for i, keys in enumerate(builds):
            K.place(f"{row}{i}", keys, (i - (len(builds) - 1) / 2) * SPACING, oz)
    K.finish_library()
    K.stage()
    files = []
    if render:
        os.makedirs(OUT, exist_ok=True)
        j = os.path.join
        for row, (oz, builds) in ROWS.items():
            d = 30 + 16 * len(builds)
            only = [f"{row}{i}" for i in range(len(builds))]
            files.append(K.shot(j(OUT, f"{row}_front.jpg"), (0, 0.8, oz), 150, 12, d, only=only))
            files.append(K.shot(j(OUT, f"{row}_rear.jpg"), (0, 0.8, oz), 30, 12, d, only=only))
        for car, x, az in (("a", -SPACING / 2, 270), ("b", SPACING / 2, 90)):
            only = ["pure0" if car == "a" else "pure1"]
            files.append(K.shot(j(OUT, f"{car}_side.jpg"), (x, 1.0, 0), az, 4, 60, only=only))
            files.append(K.shot(j(OUT, f"{car}_rear_close.jpg"), (x, 1.0, 3), 24, 14, 38, only=only))
            files.append(K.shot(j(OUT, f"{car}_front_close.jpg"), (x, 1.0, -3), 152, 14, 38, only=only))
            files.append(K.shot(j(OUT, f"{car}_front_low.jpg"), (x, 0.6, -6), 158, 3, 30, only=only))
        files.append(K.shot(j(OUT, "pure_top.jpg"), (0, 0, 0), 180, 89, 80, only=["pure0", "pure1"]))
        if paints:  # mixed builds again, every part in the same paint
            for name, prim, sec in PAINTS:
                K.repaint(prim, sec)
                for row, tag, az in (("swaps_on_a", "a_front", 150), ("swaps_on_b", "b_rear", 30)):
                    oz, builds = ROWS[row]
                    only = [f"{row}{i}" for i in range(len(builds))]
                    files.append(K.shot(j(OUT, f"paint_{name}_{tag}.jpg"), (0, 0.8, oz), az, 12,
                                        30 + 16 * len(builds), only=only))
            K.repaint()
    totals = {}
    for key, rec in K.MODS.items():
        car, slot, trim = key.split("_")
        for t in (TRIMS if slot == "COCKPIT" else (trim,)):
            totals[f"{car}_{t}"] = totals.get(f"{car}_{t}", 0) + rec["tris"]
    return {"problems": problems, "files": files, "totals": totals}
