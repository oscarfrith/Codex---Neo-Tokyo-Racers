"""Exotic pilot cars, refined: car A (sharp, Hyper) and car B (round, Curve).

Run inside Blender:  import cars; cars.build_all()
Slots: COCKPIT, NOSE, TAIL, FPOD (Front Engines), RPOD (Rear Engines), STAB, BOOST, WING.
Every module slot has three versions on the same mounting, each a clear step up:
  STD  the road car: clean surfaces, small nozzles, modest wing.
  GT   a race bodykit on the road car: flared fenders with cut vents, long splitter with endplates
       and a dive plane, skirt blades, extended diffuser, tall swan-neck wing.
  EVO  the full time-attack kit: widest flares with fences, stacked dive planes, giant splitter,
       tail fin, tunnel diffuser, two-element wing wider than the body.
In the game these map to the STANDARD, LIGHTWEIGHT and POWER variant ids. The cockpit has one version.

Layout, round 6 (wider and lower):
  - Front engines are free-standing front fenders with the headlights; their jet exits over the sill.
  - Rear engines are the rear fenders, nozzle at the tail.
  - Each engine is a body-colour fender over a dark arch with a vented shell. No actual wheels.
  - Stabilisers are sill units between the fenders.
  - Body seams have a shadow gap: skins stop GAP short and a dark liner shows through.
  - The diffuser is the lower rear of the tail. The splitter is the chin of the nose.
  - Boost is the centre insert of the tail fascia, from diffuser height to the light line.

Car A is a wedge: prow leads, tall rear haunches, squared tail with strakes, burners in the diffuser.
Car B is a teardrop: fenders lead, nose recessed, round arches, drooping tail, ring burners high.
"""
import os

import exokit as K
from exokit import GAP, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Hull, Loft, R, box

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
SLOTS = ("COCKPIT", "NOSE", "TAIL", "FPOD", "RPOD", "STAB", "BOOST", "WING")
TRIMS = ("STD", "GT", "EVO")
LVL = {"STD": 0, "GT": 1, "EVO": 2}


def pick(trim, std, gt=None, evo=None):
    gt = std if gt is None else gt
    return {"STD": std, "GT": gt, "EVO": gt if evo is None else evo}[trim]


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
    """Thin swept vertical blade (pylon, fence or endplate). za and zb are (front, back) at y0 and y1."""
    Loft([(y0, dict(yb=za[0], yt=za[1])), (y1, dict(yb=zb[0], yt=zb[1]))], axis="y", cx=x, w=t,
         nt=2.2, nb=2.2, yw=0.4).build(name, ch, mirror=x != 0)


def plane(name, span, z, chord, y0, y1, ch, tip=None):
    """Wing plane across the car. chord is the half chord. tip: (z, half chord) at the ends."""
    tz, tc = tip or (z, chord)
    Loft([(-span, dict(cx=tz, w=tc)), (0, {}), (span, dict(cx=tz, w=tc))], axis="x", cx=z, w=chord, yb=y0, yt=y1,
         yw=0.6, nt=2.2, nb=2.6).build(name, ch)


def slab(name, pts, y0, y1, ch, cx=0.0, nt=5.0, mirror=False):
    """Flat plate with a shaped plan: pts are (z, half width). Splitters, diffuser floors, skirts."""
    Loft([(z, dict(w=w)) for z, w in pts], cx=cx, yb=y0, yt=y1, nt=nt, nb=nt).build(name, ch, mirror=mirror)


def canard(name, x0, x1, z0, z1, y0, y1, ch="secondary"):
    """Dive plane: a thin plate that rises toward the back."""
    Loft([(z0, dict(yb=y0, yt=y0 + 0.07)), (z1, dict(yb=y1, yt=y1 + 0.07))], cx=(x0 + x1) / 2, w=(x1 - x0) / 2,
         nt=6, nb=6, yw=0.5).build(name, ch, mirror=True)


def race_wing(span, z, chord, y, pylon_x, elements=1, plate=(3.8, 5.2), beam=False):
    """Swan-neck race wing: the pylons rise ahead of the plane and hook down onto its top."""
    plane("plane", span, z, chord, y, y + 0.2, "primary", tip=(z + 0.15, chord * 0.82))
    if elements > 1:
        plane("flap", span, z + chord + 0.12, chord * 0.42, y + 0.4, y + 0.52, "primary")
    blade("pylon", pylon_x, 1.25, y + 0.5, (z - 1.25, z - 0.25), (z - 0.6, z - 0.15), "secondary", t=0.07)
    box("hook", (pylon_x, y + 0.36, z + 0.05), (0.14, 0.3, 0.5), "secondary", mirror=True)
    blade("plate", span + 0.02, plate[0], plate[1], (z - 0.9, z + chord + 0.45), (z - 0.5, z + chord + 0.7),
          "secondary", t=0.06)
    box("gurney", (0, y + 0.25, z + chord - 0.04), (span * 2, 0.1, 0.05), "secondary")
    if beam:
        plane("beam", pylon_x, z - 0.2, 0.3, 3.25, 3.36, "secondary")


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


def flared(stations, peak, flare, up, reach=2.2):
    """Widen and raise a fender around its arch for a bodykit flare. The inboard face stays put."""
    out = []
    for z, d in stations:
        k = max(0.0, 1.0 - abs(z - peak) / reach)
        if k and "w" in d and "cx" in d:
            d = dict(d, w=d["w"] + flare * k / 2, cx=d["cx"] + flare * k / 2, yt=d["yt"] + up * k)
        out.append((z, d))
    return out


def fender_kit(pod, peak, lvl, front):
    """Bodykit hardware on a fender: a fence along the flare, and vent slats behind (or ahead of) the arch."""
    if not lvl:
        return
    p = pod.params(peak)
    x = p["cx"] + p["w"]
    s = 1 if front else -1
    for i in range(3):
        t = peak + s * (2.0 + i * 0.2)
        pod.patch(f"exit{i}", t - 0.05, t + 0.05, 1.7, 2.85, "secondary", off=-0.14, mirror=True)
    if lvl > 1:
        blade("fence", x - 0.3, p["ys"] + 0.5, p["yt"] + 0.28, (peak - 1.3, peak + 1.5), (peak - 0.7, peak + 1.6),
              "secondary", t=0.04)


def fender_regions(peak, lvl, front):
    """Extra cut-outs a bodykit adds to a fender skin: an exit vent behind (front) or a feed ahead (rear)."""
    if not lvl:
        return []
    s = 1 if front else -1
    a, b = sorted((peak + s * 1.88, peak + s * 2.55))
    return [R(a, b, 1.6, 2.92, "detail", 0.26, side=1)]


# ---------------------------------------------------------------- car A: sharp

A_POD = dict(rb=0.35, tum=0.42, drop=0.28, tumi=0.03, dropi=0.12, wcf=0.45, d2=0.04, crown=0.06, cs=0.03)


def a_pod(pod, z0, z1, peak, trim, front, extra=(), caps=(False, False)):
    """Flowing fender over a dark arch, carbon rocker, louvred vent on top, vented shell in the arch."""
    lvl = LVL[trim]
    vent = ((peak - 1.2, peak + 0.8, 4.18, 4.92, 4), (peak - 1.5, peak + 1.1, 4.12, 5.2, 6),
            (peak - 1.6, peak + 1.3, 4.1, 5.45, 7))[lvl]
    pod.build("skin", "primary", mirror=True, caps=caps, regions=[
        R(z0 + 0.25, z1 - 0.2, 1.0, (2.05, 2.3, 2.6)[lvl], "secondary", 0.02),
        R(peak - 1.7, peak + 1.7, 1.25, 2.92, "detail", 0.35, side=1),
        R(vent[0], vent[1], vent[2], vent[3], "detail", 0.14, side=1),
        *fender_regions(peak, lvl, front), *extra])
    louvres(pod, "top", vent[0] + 0.1, vent[1] - 0.1, vent[2] + 0.06, vent[3] - 0.06, vent[4], off=-0.05)
    if not front or lvl:
        for i in range(4):
            t = peak - (1.58 - i * 0.13)
            pod.patch(f"arch{i}", t - 0.03, t + 0.03, 1.4, 2.85, "secondary", off=-0.18, mirror=True)
    shell(pod, peak, 1.3, -0.8, 0.95, 3.2, bars=(1, 2, 2)[lvl])
    fender_kit(pod, peak, lvl, front)
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
    """Rounded prow over a recessed grille and a splitter; the hood sinks between the fenders."""
    K.begin("A", "NOSE", trim)
    lvl = LVL[trim]
    nose = Hull([(-12.6, dict(w=1.5, yb=0.2, yt=0.45, rb=0.08, ys=0.3, tum=0.15, drop=0.06)),
                 (-12.2, dict(w=2.5, yb=0.15, yt=0.6, rb=0.1, ys=0.34, tum=0.2, drop=0.12)),
                 (-11.4, dict(w=3.3, yb=0.1, yt=0.82, rb=0.15, ys=0.45, tum=0.22, drop=0.2)),
                 (-10.4, dict(w=3.7, yt=1.02, ys=0.5, tum=0.25, drop=0.25)),
                 (-8.5, dict(w=3.8, yt=1.35, ys=0.8, tum=0.3, drop=0.3)),
                 (-6.6, dict(w=3.8, yt=1.85, ys=1.1, tum=0.35, drop=0.3, crown=0.05)), (-5.2, SEAM_F)],
                yb=-0.4, rb=0.45, wcf=0.62, d2=0.06, crown=0.04)
    vent = ((-9.9, -7.4, 4.15, 4.85, 6), (-10.6, -7.0, 4.1, 4.95, 9), (-10.8, -6.8, 4.1, 4.95, 10))[lvl]
    regs = [R(-12.5, -10.5, 2.86, 3.0, "lights", -0.01), R(vent[0], vent[1], vent[2], vent[3], "detail", 0.2)]
    if lvl == 0:
        regs.append(R(-11.2, -7.0, 5.0, 6.0, "secondary", 0.03))
    else:  # the hood centre is cut open into a big extractor duct
        regs.append(R(-11.3, -7.0, 5.0, 6.0, "detail", 0.2))
    nose.build("skin", "primary", t1=-5.2 - GAP, regions=regs)
    louvres(nose, "hood", vent[0] + 0.1, vent[1] - 0.1, vent[2] + 0.05, vent[3] - 0.05, vent[4], off=-0.1)
    if lvl:
        louvres(nose, "duct", -11.1, -7.2, 5.06, 5.97, 8, off=-0.1)
    jaw = Loft([(-12.3, dict(w=1.9)), (-11.9, dict(w=2.9)), (-11.2, dict(w=3.4)), (-10.5, dict(w=3.5))],
               yb=-0.4, yt=(0.3, 0.36, 0.42)[lvl], nt=5, nb=5)
    jaw.build("jaw", "secondary", caps=(False, True))
    jaw.throat("grille", "min", lip="secondary", scale=0.88, depth=0.5)
    reach = (-12.7, -13.2, -13.45)[lvl]
    slab("splitter", [(reach, 1.6 + lvl * 0.5), (reach + 0.35, 2.8 + lvl * 0.3), (-11.7, 3.5 + lvl * 0.14),
                      (-10.8, 3.8)], -0.54, -0.42, "secondary")
    if lvl:  # stays from the grille to the splitter, and keel fins under it
        for i, x in enumerate((1.0, 2.2)[:lvl + 0]):
            box(f"stay{i}", (x, -0.1, reach + 0.55), (0.05, 0.7, 0.05), "detail", mirror=True)
        for i, x in enumerate((0.8, 1.9, 3.0)[:lvl + 1]):
            box(f"keel{i}", (x, -0.66, -11.9), (0.05, 0.24, 1.6), "detail", mirror=True)
    if lvl > 1:  # centre strake down the hood duct
        blade("strake", 0, 0.95, 1.7, (-10.9, -9.6), (-9.2, -8.4), "primary", t=0.05)


def a_fpod(trim):
    """Free-standing front fender: rounded prow, slim headlight under a lid, strake recess, splitter corner."""
    K.begin("A", "FPOD", trim)
    lvl = LVL[trim]
    st = [(-11.9, dict(cx=5.0, w=0.35, wi=0.35, yb=0.35, yt=0.75, ys=0.5, rb=0.1, tum=0.1, drop=0.08, dropi=0.08)),
          (-11.5, dict(cx=5.02, w=0.8, wi=0.75, yb=-0.1, yt=1.15, ys=0.55, rb=0.2)),
          (-10.8, dict(cx=5.08, w=1.12, wi=0.95, yb=-0.6, yt=1.6, ys=0.75)),
          (-9.8, dict(cx=5.15, w=1.28, wi=1.05, yb=-1.0, yt=2.05, ys=1.0)),
          (-8.3, dict(cx=5.18, w=1.3, wi=1.12, yb=-1.1, yt=2.25, ys=1.15)),
          (-6.8, dict(cx=5.12, w=1.2, wi=1.15, yb=-0.9, yt=1.95, ys=1.0)),
          (-5.4, dict(SIDE_F, yb=-0.1, yt=1.45, ys=0.7, rb=0.2))]
    pod = Hull(flared(st, -8.3, (0, 0.3, 0.5)[lvl], (0, 0.1, 0.2)[lvl]), **A_POD)
    extra = [R(-11.65, -10.45, 3.3, 4.2, "glass", 0.1, side=1),
             R(-11.05, -10.15, 1.25, 2.72, "detail", 0.22, side=1),
             R(-11.8, -10.0, 2.82, 2.96, "lights", -0.01, side=1)]
    a_pod(pod, -11.9, -5.4, -8.3, trim, True, extra=extra, caps=(True, False))
    pod.patch("lamp", -11.5, -10.6, 3.5, 3.9, "lights", off=-0.05, mirror=True)
    if lvl > 1:
        pod.patch("lamp2", -11.45, -10.65, 4.0, 4.12, "lights", off=-0.05, mirror=True)
    for i, u in enumerate((1.5, 1.95, 2.4)):
        pod.patch(f"strake{i}", -10.98, -10.22, u, u + 0.14, "primary", off=-0.06, mirror=True)
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.78, 0.84, 0.88)[lvl], depth=0.5, mirror=True)
    reach = (-12.05, -12.7, -13.1)[lvl]
    slab("splitter", [(reach, 0.5 + lvl * 0.4), (reach + 0.35, 1.1 + lvl * 0.25), (-10.9, 1.35 + lvl * 0.2)],
         -0.54, -0.42, "secondary", cx=5.12 + lvl * 0.1, mirror=True)
    if lvl:  # splitter endplate and dive planes on the fender flank
        blade("endplate", 6.5 + lvl * 0.12, -0.5, (0.25, 0.3, 0.5)[lvl], (reach + 0.3, -10.9), (reach + 0.8, -11.0),
              "secondary", t=0.04)
        canard("canard0", 6.1, 6.9, -11.5, -10.2, 0.35, 0.8)
    if lvl > 1:
        canard("canard1", 6.2, 6.95, -11.1, -9.9, 0.95, 1.45)
    box("channel", (4.02, -0.05, -8.2), (0.42, 0.5, 5.2), "detail", mirror=True)


def a_tail(trim):
    K.begin("A", "TAIL", trim)
    lvl = LVL[trim]
    tail = Hull([(2.8, SEAM_R), (5.5, dict(yt=2.6)), (8.6, dict(yt=2.6, ys=1.5, tum=0.28, drop=0.3)),
                 (10.0, dict(yb=0.0, yt=2.6, ys=1.6, tum=0.25, drop=0.28)),
                 (11.2, dict(w=3.75, yb=0.45, yt=(2.65, 2.85, 3.0)[lvl], ys=1.7, tum=0.22, drop=0.25, rb=0.3))],
                **{**SEAM_R, "crown": 0.03})
    cover = R(7.7, 10.4, 5.1, 6.0, "detail", 0.16) if lvl else R(7.7, 10.4, 5.1, 6.0, "secondary", 0.03)
    tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
        R(8.6, 11.2, 0.0, 2.3, "secondary", 0.02), cover,
        R((6.4, 5.4, 4.6)[lvl], 10.2, 4.2, 4.85, "detail", 0.15)])
    louvres(tail, "deck", (6.5, 5.5, 4.7)[lvl], 10.1, 4.25, 4.8, (8, 10, 12)[lvl], off=-0.08)
    if lvl:
        louvres(tail, "cover", 7.85, 10.25, 5.16, 5.97, 6, off=-0.08)
    tail.throat("fascia", "max", lip="primary", scale=0.93, depth=0.3)
    box("blade", (0, 2.36, 11.02), (6.6, 0.1, 0.16), "lights_red")
    for i, y in enumerate(((2.1, 1.85, 1.6, 1.35, 1.1, 0.85), (1.95, 1.45, 0.95), (1.95, 1.45, 0.95))[lvl]):
        box(f"strake{i}", (3.0, y, 11.04), (0.78, 0.09, 0.2), "primary", mirror=True)
    if lvl == 0:
        for i, x in enumerate((2.8, 3.25)):
            dfin(f"fin{i}", x, ((9.4, -0.32), (10.4, 0.0), (11.3, 0.3)))
    else:  # extended diffuser: a floor that runs out past the tail, with tall strakes
        back = (0, 12.3, 12.75)[lvl]
        slab("floor", [(9.0, 3.7), (back - 0.4, 3.8), (back, 3.6)], -0.5, -0.42, "secondary")
        for i, x in enumerate(((), (2.75, 3.25, 3.7), (2.7, 3.05, 3.4, 3.75))[lvl]):
            dfin(f"fin{i}", x, ((9.2, -0.3), (10.6, 0.25), (back, 0.55 + lvl * 0.12)))
        blade("sideplate", 3.8, -0.45, 0.6 + lvl * 0.1, (10.2, back), (11.0, back), "secondary", t=0.04)
    if lvl > 1:  # tail fin from the cabin to the wing
        blade("fin", 0, 2.5, 3.85, (6.6, 10.2), (9.0, 10.25), "primary", t=0.06)


def a_rpod(trim):
    K.begin("A", "RPOD", trim)
    lvl = LVL[trim]
    st = [(3.6, dict(SIDE_R, yb=-0.5, yt=1.6)),
          (4.8, dict(cx=5.12, w=1.22, wi=1.18, yb=-1.0, yt=2.15, ys=1.15)),
          (6.4, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.65, ys=1.5)),
          (7.8, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.8, ys=1.6)),
          (9.4, dict(cx=5.16, w=1.25, wi=1.2, yb=-1.0, yt=2.6, ys=1.55)),
          (10.6, dict(cx=5.12, w=1.12, wi=1.15, yb=-0.6, yt=2.2, ys=1.4))]
    pod = Hull(flared(st, 7.3, (0, 0.3, 0.5)[lvl], (0, 0.15, 0.3)[lvl], reach=3.0), **A_POD)
    a_pod(pod, 3.6, 10.6, 7.3, trim, False)
    pod.throat("intake", "min", lip="primary", scale=0.8, depth=0.5, mirror=True)
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.82, 0.86, 0.9)[lvl], depth=0.6, mirror=True)
    p = pod.params(10.6)
    mid = (p["yb"] + p["yt"]) / 2
    for i, dy in enumerate(((-0.5, 0.0, 0.5), (-0.66, -0.22, 0.22, 0.66), (-0.66, -0.22, 0.22, 0.66))[lvl]):
        box(f"slat{i}", (p["cx"], mid + dy, 10.42), (1.7, 0.07, 0.3), "detail", mirror=True)
    if lvl:  # corner diffuser strakes under the nozzle
        for i, x in enumerate((4.6, 5.3, 6.0)[:lvl + 1]):
            dfin(f"corner{i}", x, ((9.6, -0.5), (10.6, -0.1), (11.7 + lvl * 0.2, 0.3)))
    if lvl > 1:  # ram scoop on the haunch
        s = Loft([(5.4, dict(w=0.42, yt=3.05)), (6.6, dict(w=0.5, yt=3.32)), (8.2, dict(w=0.3, yt=3.1))],
                 cx=5.3, yb=2.6, nt=3, nb=3, yw=0.3)
        s.build("scoop", "primary", mirror=True, caps=(False, True))
        s.throat("scoopin", "min", lip="primary", scale=0.78, depth=0.4, mirror=True)
    flange(3.8, 10.3, 1.0)


def a_stab(trim):
    K.begin("A", "STAB", trim)
    lvl = LVL[trim]
    sill = Hull([(-5.2, dict(yb=-0.8, yt=0.4, ys=0.0)), (-2.0, dict(yt=0.65, ys=0.15)),
                 (1.5, dict(yt=1.3, ys=0.7)), (3.4, dict(yb=-0.7, yt=(1.55, 1.65, 1.75)[lvl], ys=0.9))],
                cx=4.9, w=1.0, yb=-0.9, rb=0.25, tum=0.3, drop=0.12, wcf=0.5, d2=0.03, crown=0.04)
    start = (0.5, -0.6, -1.6)[lvl]
    regs = [R(-5.2, 3.4, 1.0, (2.25, 2.6, 2.95)[lvl], "secondary", 0.02),
            R(-5.0, 3.2, 2.3, 2.38, "neon", -0.01, side=1),
            R(start, 3.15, 3.1, 3.9, "detail", 0.15, side=1)]
    sill.build("skin", "primary", mirror=True, regions=regs)
    louvres(sill, "intake", start + 0.1, 3.05, 3.15, 3.85, (6, 9, 11)[lvl], off=-0.08)
    out = (6.1, 6.55, 6.85)[lvl]
    slab("skirt", [(-5.1, (out - 4.6) / 2 - 0.15), (-3.6, (out - 4.6) / 2), (3.3, (out - 4.6) / 2)], -1.0, -0.92,
         "secondary", cx=(out + 4.6) / 2, mirror=True)
    if lvl:  # upright blade at the back of the skirt, ahead of the rear fender
        blade("kick", out - 0.05, -0.95, 0.5 + lvl * 0.35, (1.6, 3.35), (2.5, 3.4), "secondary", t=0.04)
    if lvl > 1:  # bargeboards behind the front fender
        for i, x in enumerate((6.1, 6.6)):
            blade(f"barge{i}", x, -0.95, 0.55 - i * 0.2, (-5.0, -3.4), (-4.7, -3.9), "secondary", t=0.04)
    lift_glow(sill, [(-4.2, -2.4), (-0.6, 1.4)])


def a_boost(trim):
    """Centre insert of the tail fascia: strake panel above, burners low in a carbon housing."""
    K.begin("A", "BOOST", trim)
    lvl = LVL[trim]
    box("panel", (0, 1.4, 10.98), (5.1, 1.1, 0.1), "detail")
    for i, y in enumerate(((1.85, 1.6, 1.35, 1.1), (1.8, 1.5), (1.85,))[lvl]):
        box(f"strake{i}", (0, y, 11.06), (5.0, 0.09, 0.2), "primary")
    top = (0.85, 1.0, 1.15)[lvl]
    Hull([(10.7, dict(w=2.5, yb=-0.42, yt=top)), (11.5, dict(w=2.3, yb=-0.3, yt=top - 0.05))], rb=0.3, ys=0.5,
         tum=0.3, drop=0.0, wcf=0.5, d2=0.0, crown=0.0).build("housing", "secondary")
    t = Loft([(11.2, {}), ((12.0, 12.3, 12.45)[lvl], {})], cx=1.1, w=(0.8, 0.9, 0.95)[lvl], yb=-0.22,
             yt=(0.62, 0.78, 0.9)[lvl], nt=5, nb=5, yw=0.5)
    t.build("burner", "secondary", mirror=True, caps=(True, False))
    t.throat("noz", "max", lip="secondary", back="thrust", scale=0.84, depth=0.35, mirror=True)
    box("divider", (0, 0.2, 11.75), (0.06, 0.9, 0.7), "detail")
    if lvl:  # rain light, and upper burners on the full kit
        box("rain", (0, 1.22 + lvl * 0.14, 11.1), (0.5, 0.14, 0.12), "lights_red")
    if lvl > 1:
        for i, x in enumerate((0.75, 1.75)):
            burner(f"mini{i}", 11.0, 11.9, x, 1.5, 0.24, depth=0.2)


def a_wing(trim):
    K.begin("A", "WING", trim)
    lvl = LVL[trim]
    if lvl == 0:
        plane("plane", 3.9, 11.05, 0.8, 3.9, 4.08, "primary", tip=(11.2, 0.6))
        blade("pylon", 2.9, 1.8, 3.94, (10.0, 11.1), (10.6, 11.5), "secondary")
        blade("plate", 3.92, 3.6, 4.35, (10.5, 11.9), (10.9, 12.1), "secondary", t=0.06)
    elif lvl == 1:
        race_wing(4.9, 11.3, 0.9, 4.7, 2.9, plate=(3.9, 5.25))
    else:
        race_wing(6.5, 11.3, 1.0, 5.1, 2.9, elements=2, plate=(3.3, 6.0), beam=True)


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


def b_pod(pod, z0, z1, peak, caps, trim, front):
    """Round fender over a dark arch: carbon rocker, raised crest, louvred vent, round vented shell."""
    lvl = LVL[trim]
    vent = ((peak - 1.0, peak + 0.6, 4.2, 4.95, 3), (peak - 1.4, peak + 0.9, 4.12, 5.15, 5),
            (peak - 1.5, peak + 1.1, 4.1, 5.3, 6))[lvl]
    pod.build("skin", "primary", mirror=True, caps=caps, regions=[
        R(z0 + 0.4, z1 - 0.3, 1.0, (2.15, 2.4, 2.7)[lvl], "secondary", 0.02),
        R(peak - 1.5, peak + 1.5, 1.3, 2.9, "detail", 0.3, side=1),
        R(vent[0], vent[1], vent[2], vent[3], "detail", 0.13, side=1),
        R(z0 + 0.9, z1 - 0.7, 5.62, 6.0, "secondary", (-0.04, -0.07, -0.1)[lvl]),
        R(z1 - 0.2, z1 - 0.07, 0.0, 6.0, "neon", -0.01), *fender_regions(peak, lvl, front)])
    louvres(pod, "top", vent[0] + 0.1, vent[1] - 0.1, vent[2] + 0.06, vent[3] - 0.06, vent[4], off=-0.05)
    shell(pod, peak, 1.15, -0.72, 1.0, 2.0, rim="neon", bars=(1, 2, 2)[lvl])
    x = pod.params(peak)["cx"] + pod.params(peak)["w"]
    r = (0.3, 0.34, 0.38)[lvl]
    Loft([(x - 0.1, {}), (x + 0.1, {})], axis="x", cx=peak, w=r, yb=0.14 - r, yt=0.14 + r, nt=2, nb=2,
         yw=0.5).build("hub", "secondary", mirror=True)
    fender_kit(pod, peak, lvl, front)
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=(0.8, 0.85, 0.9)[lvl], depth=0.4, mirror=True)


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
    lvl = LVL[trim]
    nose = Hull([(-11.2, dict(w=1.7, yb=0.0, yt=0.7, rb=0.25, ys=0.35, tum=0.3, drop=0.2, wcf=0.55, d2=0.03)),
                 (-10.3, dict(w=2.8, yb=-0.3, yt=1.15, ys=0.55, tum=0.45, drop=0.35)),
                 (-8.9, dict(w=3.6, yt=1.7, ys=0.9, tum=0.5, drop=0.42)),
                 (-7.0, dict(w=3.8, yt=2.1, ys=1.25, tum=0.38, drop=0.3, wcf=0.4, crown=0.07)),
                 (-5.2, SEAM_F)], creases=(1, 2, 3), yb=-0.4, rb=0.5, wcf=0.2, d2=0.12, crown=0.12)
    vent = ((-8.6, -7.0, 4.25, 4.85, 4), (-9.4, -6.6, 4.15, 5.0, 7), (-9.8, -6.4, 4.1, 5.1, 9))[lvl]
    nose.build("skin", "primary", t1=-5.2 - GAP, caps=(False, True), regions=[
        R(-10.9, -5.6, 5.3, 6.0, "secondary", (-0.03, -0.06, -0.09)[lvl]),
        R(vent[0], vent[1], vent[2], vent[3], "detail", 0.16)])
    louvres(nose, "hood", vent[0] + 0.1, vent[1] - 0.1, vent[2] + 0.05, vent[3] - 0.05, vent[4], off=-0.08)
    nose.throat("mouth", "min", lip="primary", scale=(0.78, 0.84, 0.88)[lvl], depth=0.5)
    Loft([(-11.75, dict(w=2.2)), (-11.2, dict(w=3.2)), (-10.3, dict(w=3.6)), (-8.8, dict(w=3.75))],
         yb=-0.42, yt=0.1, nt=4, nb=5).build("tray", "secondary")
    Loft([(-11.65, dict(w=2.0)), (-11.2, dict(w=3.0)), (-10.3, dict(w=3.45)), (-8.9, dict(w=3.6))],
         yb=0.0, yt=0.14, nt=4, nb=5).build("floor", "detail")
    reach = (-11.95, -12.7, -13.2)[lvl]
    slab("splitter", [(reach, 2.3 + lvl * 0.3), (reach + 0.5, 3.3 + lvl * 0.15), (-10.5, 3.8)], -0.54, -0.44,
         "secondary", nt=4)
    if lvl:  # nostril intakes on the tray, and keel fins under the splitter
        t = tube(-11.2, -10.3, 2.35, 0.38, 0.22 + lvl * 0.04)
        t.build("nostril", "secondary", mirror=True, caps=(False, True))
        t.throat("nostriln", "min", lip="secondary", scale=0.8, depth=0.3, mirror=True)
        for i, x in enumerate((0.9, 2.2)[:lvl]):
            box(f"keel{i}", (x, -0.66, -11.6), (0.05, 0.24, 1.5), "detail", mirror=True)
    if lvl > 1:  # the spine grows into a fin
        blade("strake", 0, 1.0, 2.0, (-10.0, -8.6), (-8.2, -7.6), "secondary", t=0.05)


def b_fpod(trim):
    """Round fender that leads the car, with round lamps set into its front face."""
    K.begin("B", "FPOD", trim)
    lvl = LVL[trim]
    st = [(-12.3, dict(cx=5.0, w=0.85, wi=0.9, yb=-0.2, yt=0.95, ys=0.4, **B_END)),
          (-11.3, dict(cx=5.06, w=1.1, wi=1.08, yb=-0.7, yt=1.6, ys=0.7)),
          (-9.9, dict(cx=5.12, w=1.22, wi=1.15, yb=-1.0, yt=2.15, ys=1.0)),
          (-8.4, dict(cx=5.15, w=1.25, wi=1.18, yb=-1.05, yt=2.3, ys=1.1)),
          (-6.6, dict(cx=5.08, w=1.08, wi=1.1, yb=-0.6, yt=1.7, ys=0.8)),
          (-5.4, dict(cx=4.95, w=0.78, wi=0.92, yb=0.1, yt=1.2, ys=0.65, **B_END))]
    pod = Hull(flared(st, -8.6, (0, 0.3, 0.5)[lvl], (0, 0.1, 0.2)[lvl]), creases=(1, 2), **B_POD)
    b_pod(pod, -12.3, -5.4, -8.6, (False, False), trim, True)
    pod.throat("housing", "min", lip="primary", scale=0.9, depth=0.3, mirror=True)
    lamps = (((4.7, 0.42, 0.3), (5.36, 0.36, 0.22)), ((4.62, 0.44, 0.27), (5.2, 0.4, 0.22), (5.62, 0.36, 0.14)),
             ((4.6, 0.56, 0.22), (5.14, 0.56, 0.22), (4.6, 0.12, 0.17), (5.14, 0.12, 0.17)))[lvl]
    for i, (x, y, r) in enumerate(lamps):
        lamp = tube(-12.26, -12.02, x, y, r)
        lamp.build(f"lamp{i}", "secondary", mirror=True, caps=(False, True))
        lamp.throat(f"lens{i}", "min", lip="secondary", back="lights", scale=0.78, depth=0.06, mirror=True)
    reach = (-12.4, -12.9, -13.2)[lvl]
    slab("splitter", [(reach, 0.7 + lvl * 0.3), (reach + 0.4, 1.2 + lvl * 0.25), (-11.2, 1.38 + lvl * 0.2)],
         -0.54, -0.44, "secondary", cx=5.08 + lvl * 0.1, nt=4, mirror=True)
    if lvl:
        blade("endplate", 6.45 + lvl * 0.12, -0.5, (0.25, 0.3, 0.5)[lvl], (reach + 0.3, -11.0), (reach + 0.8, -11.1),
              "secondary", t=0.04)
        canard("canard0", 6.05, 6.9, -11.6, -10.3, 0.4, 0.85)
    if lvl > 1:
        canard("canard1", 6.15, 6.95, -11.2, -10.0, 1.0, 1.5)
    flange(-8.8, -5.6, 0.5)


def b_tail(trim):
    """Drooping round tail with a dorsal fin, round lamps and a louvred deck."""
    K.begin("B", "TAIL", trim)
    lvl = LVL[trim]
    tail = Hull([(2.8, SEAM_R), (5.5, dict(w=3.75, yt=2.55, tum=0.5, drop=0.42, crown=0.1)),
                 (8.5, dict(w=3.6, yb=-0.2, yt=2.3, ys=1.25, tum=0.7, drop=0.5, rb=0.7)),
                 (11.2, dict(w=3.4, yb=0.3, yt=(2.0, 2.1, 2.2)[lvl], ys=1.15, tum=0.8, drop=0.55, rb=0.85))],
                creases=(1, 2, 3), **{**SEAM_R, "rb": 0.5, "wcf": 0.3, "d2": 0.1, "crown": 0.14})
    vent = ((6.2, 9.8, 4.25, 4.85, 7), (5.2, 10.0, 4.15, 5.0, 10), (4.4, 10.2, 4.1, 5.1, 12))[lvl]
    tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
        R(8.8, 11.2, 0.0, 2.2, "secondary", 0.02), R(3.0, 7.4, 5.3, 6.0, "secondary", -0.03),
        R(vent[0], vent[1], vent[2], vent[3], "detail", 0.15)])
    louvres(tail, "deck", vent[0] + 0.1, vent[1] - 0.1, vent[2] + 0.05, vent[3] - 0.05, vent[4], off=-0.07)
    tail.throat("fascia", "max", lip="primary", scale=0.9, depth=0.25)
    for i, (x, y, r) in enumerate((((2.82, 1.2, 0.24),), ((2.84, 1.38, 0.2), (2.84, 0.9, 0.15)),
                                   ((2.84, 1.4, 0.2), (2.84, 0.95, 0.17), (2.84, 0.55, 0.12)))[lvl]):
        lamp = tube(10.96, 11.2, x, y, r)
        lamp.build(f"lamp{i}", "secondary", mirror=True, caps=(True, False))
        lamp.throat(f"lens{i}", "max", lip="secondary", back="lights_red", scale=0.78, depth=0.06, mirror=True)
    if lvl < 2:
        fin = Loft([(7.4, dict(yt=2.6)), (10.2, dict(yt=2.98 + lvl * 0.1)), (11.15, dict(yt=2.2))], w=0.09, yb=1.85,
                   nt=2, nb=2)
        fin.build("fin", "secondary")
    else:  # tall fin from the cabin to the wing
        blade("fin", 0, 2.3, 3.85, (6.5, 10.25), (9.0, 10.28), "primary", t=0.06)
    box("rain", (0, 2.3, 11.2), (0.16, 0.45, 0.08), "lights_red")
    if lvl == 0:
        dfin("vane", 2.75, ((9.4, -0.2), (10.4, 0.1), (11.3, 0.35)))
    else:  # extended diffuser floor with tall vanes
        back = (0, 12.2, 12.7)[lvl]
        slab("floor", [(9.0, 3.5), (back - 0.5, 3.7), (back, 3.2)], -0.5, -0.42, "secondary", nt=4)
        for i, x in enumerate(((), (2.7, 3.15), (2.7, 3.05, 3.4))[lvl]):
            dfin(f"vane{i}", x, ((9.2, -0.3), (10.6, 0.3), (back - 0.1, 0.6 + lvl * 0.12)))


def b_rpod(trim):
    K.begin("B", "RPOD", trim)
    lvl = LVL[trim]
    st = [(3.6, dict(cx=4.98, w=0.85, wi=0.95, yb=-0.3, yt=1.35, ys=0.7, rb=0.3)),
          (5.2, dict(cx=5.1, w=1.18, wi=1.14, yb=-0.95, yt=2.05, ys=1.0)),
          (7.0, dict(cx=5.15, w=1.25, wi=1.18, yb=-1.05, yt=2.25, ys=1.1)),
          (9.2, dict(cx=5.06, w=1.02, wi=1.06, yb=-0.5, yt=1.9, ys=1.0)),
          (10.6, dict(cx=4.88, w=0.68, wi=0.8, yb=0.2, yt=1.45, ys=0.85, **B_END))]
    pod = Hull(flared(st, 6.9, (0, 0.3, 0.5)[lvl], (0, 0.18, 0.36)[lvl], reach=3.0), creases=(1, 2), **B_POD)
    b_pod(pod, 3.6, 10.6, 6.9, (False, False), trim, False)
    pod.throat("intake", "min", lip="primary", scale=0.78, depth=0.4, mirror=True)
    if lvl:
        for i, x in enumerate((4.5, 5.2, 5.9)[:lvl + 1]):
            dfin(f"corner{i}", x, ((9.4, -0.5), (10.5, 0.0), (11.5 + lvl * 0.2, 0.4)))
    if lvl > 1:
        s = Loft([(5.0, dict(w=0.4, yt=2.75)), (6.2, dict(w=0.5, yt=3.05)), (7.8, dict(w=0.3, yt=2.8))],
                 cx=5.25, yb=2.3, nt=2.4, nb=2.4, yw=0.3)
        s.build("scoop", "primary", mirror=True, caps=(False, True))
        s.throat("scoopin", "min", lip="primary", scale=0.78, depth=0.4, mirror=True)
    flange(3.8, 10.0, 0.9)


def b_stab(trim):
    K.begin("B", "STAB", trim)
    lvl = LVL[trim]
    sill = Hull([(-5.2, dict(w=0.6, yb=-0.6, yt=0.25, ys=-0.1)), (-2.5, dict(w=0.9, yt=0.7, ys=0.15)),
                 (1.0, dict(w=1.0, yt=1.3, ys=0.6)), (3.4, dict(w=0.75, yb=-0.5, yt=(1.1, 1.25, 1.4)[lvl], ys=0.5))],
                creases=(1, 2), cx=4.8, yb=-0.9, rb=0.35, tum=0.4, drop=0.25, wcf=0.4, d2=0.03, crown=0.12)
    start = (0.7, -0.4, -1.4)[lvl]
    regs = [R(-4.9, 3.1, 1.0, (2.3, 2.6, 2.95)[lvl], "secondary", 0.02),
            R(start, 2.7, 3.15, 3.85, "detail", 0.13, side=1)]
    if lvl:
        regs.append(R(-4.6, 2.9, 2.5, 2.6, "neon", -0.01, side=1))
    sill.build("skin", "primary", mirror=True, regions=regs)
    louvres(sill, "intake", start + 0.1, 2.6, 3.2, 3.8, (4, 7, 9)[lvl], off=-0.07)
    if lvl:
        out = (0, 6.5, 6.85)[lvl]
        slab("skirt", [(-5.1, (out - 4.6) / 2 - 0.2), (-3.4, (out - 4.6) / 2), (3.3, (out - 4.6) / 2)], -1.0, -0.92,
             "secondary", cx=(out + 4.6) / 2, nt=4, mirror=True)
        blade("kick", out - 0.05, -0.95, 0.4 + lvl * 0.35, (1.6, 3.35), (2.5, 3.4), "secondary", t=0.04)
    if lvl > 1:
        for i, x in enumerate((6.05, 6.55)):
            blade(f"barge{i}", x, -0.95, 0.5 - i * 0.2, (-5.0, -3.4), (-4.7, -3.9), "secondary", t=0.04)
    lift_glow(sill, [(-4.0, -2.4), (-0.6, 1.2)])


def b_boost(trim):
    """Ring burners high in the tail, with a keel below."""
    K.begin("B", "BOOST", trim)
    lvl = LVL[trim]
    w = (0.98, 1.1, 1.25)[lvl]
    Loft([(10.8, dict(w=w)), (11.6, dict(w=w - 0.08, yb=0.22, yt=1.93))],
         yb=0.15, yt=2.0, nt=2, nb=2, yw=0.5).build("shroud", "primary")
    if lvl == 0:
        for i, dy in enumerate((0.38, -0.38)):
            burner(f"burner{i}", 11.2, 12.15, 0.38, 1.08 + dy, 0.31)
    elif lvl == 1:  # four larger, longer rings
        for i, dy in enumerate((0.42, -0.42)):
            burner(f"burner{i}", 11.2, 12.45, 0.45, 1.08 + dy, 0.38)
    else:           # one large core with four rings around it
        burner("core", 11.2, 12.55, 0, 1.08, 0.5)
        for i, dy in enumerate((0.56, -0.56)):
            burner(f"burner{i}", 11.2, 12.3, 0.78, 1.08 + dy, 0.24)
    box("keel", (0, -0.05, 11.2 + lvl * 0.2), (0.1, 0.6, 0.9 + lvl * 0.4), "secondary")


def b_wing(trim):
    K.begin("B", "WING", trim)
    lvl = LVL[trim]
    if lvl == 0:    # one low gull blade
        Loft([(-3.9, dict(cx=11.05, w=0.45, yb=2.75, yt=2.87)), (0, {}), (3.9, dict(cx=11.05, w=0.45, yb=2.75, yt=2.87))],
             axis="x", cx=10.75, w=0.7, yb=2.85, yt=3.0, yw=0.6, nt=2.2, nb=2.6).build("blade", "primary")
        blade("pylon", 2.6, 1.25, 2.84, (9.9, 11.15), (10.35, 11.25), "secondary", t=0.11)
    elif lvl == 1:
        race_wing(4.8, 11.2, 0.85, 4.35, 2.6, plate=(3.6, 4.9))
    else:
        race_wing(6.3, 11.4, 0.95, 4.8, 2.6, elements=2, plate=(3.1, 5.7), beam=True)


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
    "new4": (-140, [kit(x) for x in "CDEF"]),
    "trims_c": (-185, [kit("C", trim=t) for t in TRIMS]),
    "trims_d": (-230, [kit("D", trim=t) for t in TRIMS]),
    "trims_e": (-275, [kit("E", trim=t) for t in TRIMS]),
    "trims_f": (-320, [kit("F", trim=t) for t in TRIMS]),
    "lineup": (140, [kit(x) for x in "CBDEAF"]),
    "mix6": (185, [kit("C", {"NOSE": "E", "FPOD": "F", "WING": "D"}), kit("D", {"FPOD": "A", "RPOD": "C", "TAIL": "E"}),
                   kit("E", {"NOSE": "B", "RPOD": "F", "BOOST": "D", "WING": "A"}),
                   kit("F", {"FPOD": "D", "TAIL": "C", "STAB": "E", "BOOST": "B"})]),
    "swaps_on_a": (45, [kit("A", {"NOSE": "B"}), kit("A", {s: "B" for s in PODS}),
                        kit("A", {s: "B" for s in REAR}), kit("A", {s: "B" for s in SLOTS if s != "COCKPIT"})]),
    "swaps_on_b": (90, [kit("B", {"NOSE": "A"}), kit("B", {s: "A" for s in PODS}),
                        kit("B", {s: "A" for s in REAR}), kit("B", {s: "A" for s in SLOTS if s != "COCKPIT"})]),
}
SPACING = 19.0
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
    import cars2
    cars2.build()
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
            d = 32 + 17 * len(builds)
            only = [f"{row}{i}" for i in range(len(builds))]
            files.append(K.shot(j(OUT, f"{row}_front.jpg"), (0, 0.8, oz), 150, 12, d, only=only))
            files.append(K.shot(j(OUT, f"{row}_rear.jpg"), (0, 0.8, oz), 30, 12, d, only=only))
        for car, x, az in (("a", -SPACING / 2, 270), ("b", SPACING / 2, 90)):
            only = ["pure0" if car == "a" else "pure1"]
            files.append(K.shot(j(OUT, f"{car}_side.jpg"), (x, 1.0, 0), az, 4, 60, only=only))
            files.append(K.shot(j(OUT, f"{car}_rear_close.jpg"), (x, 1.0, 3), 24, 14, 38, only=only))
            files.append(K.shot(j(OUT, f"{car}_front_close.jpg"), (x, 1.0, -3), 152, 14, 38, only=only))
            files.append(K.shot(j(OUT, f"{car}_front_low.jpg"), (x, 0.6, -6), 158, 3, 30, only=only))
        for car, oz in (("a", -45), ("b", -90)):  # the full kit on its own, close
            only = [f"trims_{car}2"]
            files.append(K.shot(j(OUT, f"{car}_evo_front.jpg"), (SPACING, 1.2, oz - 2), 152, 12, 42, only=only))
            files.append(K.shot(j(OUT, f"{car}_evo_rear.jpg"), (SPACING, 1.4, oz + 3), 26, 13, 44, only=only))
        files.append(K.shot(j(OUT, "pure_top.jpg"), (0, 0, 0), 180, 89, 80, only=["pure0", "pure1"]))
        if paints:  # mixed builds again, every part in the same paint
            for name, prim, sec in PAINTS:
                K.repaint(prim, sec)
                for row, tag, az in (("swaps_on_a", "a_front", 150), ("swaps_on_b", "b_rear", 30)):
                    oz, builds = ROWS[row]
                    only = [f"{row}{i}" for i in range(len(builds))]
                    files.append(K.shot(j(OUT, f"paint_{name}_{tag}.jpg"), (0, 0.8, oz), az, 12,
                                        32 + 17 * len(builds), only=only))
            K.repaint()
    totals = {}
    for key, rec in K.MODS.items():
        car, slot, trim = key.split("_")
        for t in (TRIMS if slot == "COCKPIT" else (trim,)):
            totals[f"{car}_{t}"] = totals.get(f"{car}_{t}", 0) + rec["tris"]
    return {"problems": problems, "files": files, "totals": totals}
