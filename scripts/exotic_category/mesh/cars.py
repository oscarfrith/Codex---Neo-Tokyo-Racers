"""Exotic pilot cars, refined: car A (sharp, Hyper) and car B (round, Curve).

Run inside Blender:  import cars; cars.build_all()
Slots: COCKPIT, NOSE, TAIL, FPOD (Front Engines), RPOD (Rear Engines), STAB, BOOST, WING.

Layout, round 6 (wider and lower):
  - Front engines are the front fenders and carry the headlights. Their jet exits at the back of
    the fender, over the sill. The nose is the centre section.
  - Rear engines are the rear fenders, tight to the body, nozzle at the tail.
  - Each engine is a body-colour fender over a dark arch. A vented shell stands in the arch.
    No actual wheels.
  - Stabilisers are free-standing sill units between the fenders.
  - Body seams have a shadow gap: skins stop GAP short and a dark liner shows through.
  - The diffuser is the dark lower rear of the tail. The splitter is the chin of the nose.
  - Boost is the centre insert of the tail fascia, from diffuser height to the light line.

Car A is a wedge: nose leads, low front fenders, tall rear haunches, squared tail with strakes,
burners low in the diffuser, tall wing. Detail language: bars, slots, strakes.
Car B is a teardrop: fenders lead and the nose is recessed between them, tall round front arches,
low tapering rear pods, drooping round tail with a dorsal fin, four-ring burners high in the tail.
Detail language: circles and rings.
"""
import os

import exokit as K
from exokit import GAP, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Hull, Loft, R, box

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
SLOTS = ("COCKPIT", "NOSE", "TAIL", "FPOD", "RPOD", "STAB", "BOOST", "WING")


def rect(stations, cx, w, yb, yt, c=0.12, axis="z"):
    """Chamfered rectangular tube."""
    return Hull(stations, axis=axis, cx=cx, w=w, yb=yb, yt=yt, rb=c, ys=yt - c, tum=c, drop=0.0,
                wcf=0.5, d2=0.0, crown=0.0)


def tube(z0, z1, x, y, r):
    return Loft([(z0, {}), (z1, {})], cx=x, w=r, yb=y - r, yt=y + r, nt=2, nb=2, yw=0.5)


def lift_glow(hull, spans):
    for i, (t0, t1) in enumerate(spans):
        for side in (1, -1):
            hull.patch(f"lift{i}{side}", t0, t1, 0.2, 0.85, "thrust", side=side, mirror=True)


def blade(name, x, y0, y1, za, zb, ch, t=0.09):
    """Thin swept vertical blade (pylon or endplate). za and zb are (front, back) at y0 and y1."""
    Loft([(y0, dict(yb=za[0], yt=za[1])), (y1, dict(yb=zb[0], yt=zb[1]))], axis="y", cx=x, w=t,
         nt=2.2, nb=2.2, yw=0.4).build(name, ch, mirror=True)


def flange(z0, z1, y1):
    """Dark mounting flange between a pod and the body. It closes the gap from above."""
    box("flange", (3.92, (y1 - 0.3) / 2, (z0 + z1) / 2), (0.16, y1 + 0.3, z1 - z0), "detail", mirror=True)


def tub(scallop=True):
    regs = [R(-5.2 + GAP, 2.8 - GAP, 0.0, 1.9, "secondary", 0.02)]
    if scallop:
        regs.append(R(-4.3, 2.0, 2.2, 2.88, "primary", 0.1))
    Hull([(-5.2, SEAM_F), (-1.0, dict(SEAM_F, yt=2.35)), (2.8, SEAM_R)]).build(
        "tub", "primary", t0=-5.2 + GAP, t1=2.8 - GAP, regions=regs)
    Hull([(-5.28, SEAM_F), (-1.0, dict(SEAM_F, yt=2.35)), (2.88, SEAM_R)]).build("liner", "detail", scale=0.96)


def shell(pod, peak, half, y0, y1, nt, rim="secondary"):
    """Vented shell standing in an engine arch: a rim, a body-colour cover and a light bar."""
    x = pod.params(peak)["cx"] + pod.params(peak)["w"]
    Loft([(x - 0.36, {}), (x - 0.12, {})], axis="x", cx=peak, w=half + 0.13, yb=y0 - 0.12, yt=y1 + 0.12,
         nt=nt, nb=nt, yw=0.5).build("rim", rim, mirror=True)
    Loft([(x - 0.3, {}), (x + 0.03, {})], axis="x", cx=peak, w=half, yb=y0, yt=y1, nt=nt, nb=nt,
         yw=0.5).build("cover", "primary", mirror=True)
    box("coverbar", (x + 0.04, (y0 + y1) / 2 + 0.12, peak), (0.06, 0.08, half * 1.2), "neon", mirror=True)


# ---------------------------------------------------------------- car A: sharp

A_POD = dict(rb=0.35, tum=0.42, drop=0.28, tumi=0.03, dropi=0.12, wcf=0.45, d2=0.04, crown=0.06, cs=0.03)


def louvres(surf, name, t0, t1, u0, u1, n, ch="secondary", off=-0.06, side=1, w=0.5):
    """n slats across a vent, standing between the vent floor and the skin."""
    step = (t1 - t0) / n
    for i in range(n):
        a = t0 + i * step + step * (1 - w) / 2
        surf.patch(f"{name}{i}", a, a + step * w, u0, u1, ch, side=side, off=off, mirror=True)


def a_pod(pod, z0, z1, peak, extra=(), arch_slats=0, caps=(False, False)):
    """Flowing fender over a dark arch, carbon rocker, louvred vent on top, vented shell in the arch."""
    pod.build("skin", "primary", mirror=True, caps=caps, regions=[
        R(z0 + 0.25, z1 - 0.2, 1.0, 2.05, "secondary", 0.02),
        R(peak - 1.7, peak + 1.7, 1.25, 2.92, "detail", 0.35, side=1),
        R(peak - 1.2, peak + 0.8, 4.18, 4.92, "detail", 0.12, side=1), *extra])
    louvres(pod, "top", peak - 1.1, peak + 0.7, 4.24, 4.86, 4, off=-0.05)
    for i in range(4 if arch_slats else 0):
        t = peak + arch_slats * (1.58 - i * 0.13)
        pod.patch(f"arch{i}", t - 0.03, t + 0.03, 1.4, 2.85, "secondary", off=-0.18, mirror=True)
    shell(pod, peak, 1.3, -0.8, 0.95, 3.2)
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])


def car_a():
    c = "A"
    K.begin(c, "COCKPIT")
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

    # Nose: a rounded prow that leads the car, over a recessed lower grille and a curved splitter.
    # The hood sinks between the fenders and climbs to the cowl.
    K.begin(c, "NOSE")
    nose = Hull([(-12.6, dict(w=1.5, yb=0.2, yt=0.45, rb=0.08, ys=0.3, tum=0.15, drop=0.06)),
                 (-12.2, dict(w=2.5, yb=0.15, yt=0.6, rb=0.1, ys=0.34, tum=0.2, drop=0.12)),
                 (-11.4, dict(w=3.3, yb=0.1, yt=0.82, rb=0.15, ys=0.45, tum=0.22, drop=0.2)),
                 (-10.4, dict(w=3.7, yt=1.02, ys=0.5, tum=0.25, drop=0.25)),
                 (-8.5, dict(w=3.8, yt=1.35, ys=0.8, tum=0.3, drop=0.3)),
                 (-6.6, dict(w=3.8, yt=1.85, ys=1.1, tum=0.35, drop=0.3, crown=0.05)), (-5.2, SEAM_F)],
                yb=-0.4, rb=0.45, wcf=0.62, d2=0.06, crown=0.04)
    nose.build("skin", "primary", t1=-5.2 - GAP, regions=[
        R(-12.5, -10.5, 2.86, 3.0, "lights", -0.01),
        R(-11.2, -7.0, 5.0, 6.0, "secondary", 0.03), R(-9.9, -7.4, 4.15, 4.85, "detail", 0.18)])
    louvres(nose, "hood", -9.8, -7.5, 4.2, 4.8, 6, off=-0.1)
    # The grille block and the splitter follow the curve of the prow.
    jaw = Loft([(-12.3, dict(w=1.9)), (-11.9, dict(w=2.9)), (-11.2, dict(w=3.4)), (-10.5, dict(w=3.5))],
               yb=-0.4, yt=0.3, nt=5, nb=5)
    jaw.build("jaw", "secondary", caps=(False, True))
    jaw.throat("grille", "min", lip="secondary", scale=0.88, depth=0.5)
    Loft([(-12.7, dict(w=1.6)), (-12.4, dict(w=2.7)), (-11.7, dict(w=3.45)), (-10.8, dict(w=3.78))],
         yb=-0.52, yt=-0.42, nt=5, nb=5).build("splitter", "secondary")

    # Front engines: free-standing fenders with a channel to the body. Rounded prow set back from the
    # nose, slim headlight on its front face under a lid, light blade below, strake intake underneath.
    K.begin(c, "FPOD")
    pod = Hull([(-11.9, dict(cx=5.0, w=0.35, wi=0.35, yb=0.35, yt=0.75, ys=0.5, rb=0.1, tum=0.1, drop=0.08,
                             dropi=0.08)),
                (-11.5, dict(cx=5.02, w=0.8, wi=0.75, yb=-0.1, yt=1.15, ys=0.55, rb=0.2)),
                (-10.8, dict(cx=5.08, w=1.12, wi=0.95, yb=-0.6, yt=1.6, ys=0.75)),
                (-9.8, dict(cx=5.15, w=1.28, wi=1.05, yb=-1.0, yt=2.05, ys=1.0)),
                (-8.3, dict(cx=5.18, w=1.3, wi=1.12, yb=-1.1, yt=2.25, ys=1.15)),
                (-6.8, dict(cx=5.12, w=1.2, wi=1.15, yb=-0.9, yt=1.95, ys=1.0)),
                (-5.4, dict(SIDE_F, yb=-0.1, yt=1.35, ys=0.7, rb=0.2))], **A_POD)
    a_pod(pod, -11.9, -5.4, -8.3, caps=(True, False), extra=[
        R(-11.65, -10.45, 3.3, 4.2, "glass", 0.1, side=1),
        R(-11.6, -10.6, 1.25, 2.72, "detail", 0.22, side=1),
        R(-11.8, -10.0, 2.82, 2.96, "lights", -0.01, side=1)])
    pod.patch("lamp", -11.5, -10.6, 3.5, 3.9, "lights", off=-0.05, mirror=True)
    for i, u in enumerate((1.5, 1.95, 2.4)):
        pod.patch(f"strake{i}", -11.52, -10.68, u, u + 0.14, "primary", off=-0.06, mirror=True)
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.78, depth=0.5, mirror=True)
    Loft([(-12.05, dict(w=0.5)), (-11.7, dict(w=1.1)), (-10.9, dict(w=1.35))], cx=5.12, yb=-0.52, yt=-0.42,
         nt=5, nb=5).build("splitter", "secondary", mirror=True)
    box("channel", (4.02, -0.05, -8.2), (0.42, 0.5, 5.2), "detail", mirror=True)

    K.begin(c, "TAIL")
    tail = Hull([(2.8, SEAM_R), (5.5, dict(yt=2.6)), (8.6, dict(yt=2.6, ys=1.5, tum=0.28, drop=0.3)),
                 (10.0, dict(yb=0.0, yt=2.6, ys=1.6, tum=0.25, drop=0.28)),
                 (11.2, dict(w=3.75, yb=0.45, yt=2.65, ys=1.7, tum=0.22, drop=0.25, rb=0.3))],
                **{**SEAM_R, "crown": 0.03})
    tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
        R(8.6, 11.2, 0.0, 2.3, "secondary", 0.02), R(7.7, 10.4, 5.1, 6.0, "secondary", 0.03),
        R(6.4, 10.2, 4.2, 4.85, "detail", 0.15)])
    louvres(tail, "deck", 6.5, 10.1, 4.25, 4.8, 8, off=-0.08)
    tail.throat("fascia", "max", lip="primary", scale=0.93, depth=0.3)
    box("blade", (0, 2.36, 11.02), (6.6, 0.1, 0.16), "lights_red")
    for i, y in enumerate((2.1, 1.85, 1.6, 1.35, 1.1, 0.85)):
        box(f"strake{i}", (3.0, y, 11.04), (0.78, 0.09, 0.2), "primary", mirror=True)
    for i, x in enumerate((2.75, 3.1, 3.45)):
        box(f"fin{i}", (x, 0.0, 10.95), (0.06, 0.7, 1.0), "detail", mirror=True)

    K.begin(c, "RPOD")
    pod = Hull([(3.6, dict(SIDE_R, yb=-0.5, yt=1.6)),
                (4.8, dict(cx=5.12, w=1.22, wi=1.18, yb=-1.0, yt=2.15, ys=1.15)),
                (6.4, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.65, ys=1.5)),
                (7.8, dict(cx=5.18, w=1.3, wi=1.22, yb=-1.1, yt=2.8, ys=1.6)),
                (9.4, dict(cx=5.16, w=1.25, wi=1.2, yb=-1.0, yt=2.6, ys=1.55)),
                (10.6, dict(cx=5.12, w=1.12, wi=1.15, yb=-0.6, yt=2.2, ys=1.4))], **A_POD)
    a_pod(pod, 3.6, 10.6, 7.3, arch_slats=-1)
    pod.throat("intake", "min", lip="primary", scale=0.8, depth=0.5, mirror=True)
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.82, depth=0.6, mirror=True)
    for i, y in enumerate((0.3, 0.8, 1.3)):
        box(f"slat{i}", (5.12, y, 10.42), (1.7, 0.07, 0.3), "detail", mirror=True)
    flange(3.8, 10.3, 1.0)

    K.begin(c, "STAB")
    sill = Hull([(-5.2, dict(yb=-0.8, yt=0.4, ys=0.0)), (-2.0, dict(yt=0.65, ys=0.15)),
                 (1.5, dict(yt=1.3, ys=0.7)), (3.4, dict(yb=-0.7, yt=1.55, ys=0.9))],
                cx=4.9, w=1.0, yb=-0.9, rb=0.25, tum=0.3, drop=0.12, wcf=0.5, d2=0.03, crown=0.04)
    sill.build("skin", "primary", mirror=True, regions=[
        R(-5.2, 3.4, 1.0, 2.25, "secondary", 0.02), R(-5.0, 3.2, 2.3, 2.38, "neon", -0.01, side=1),
        R(0.5, 3.15, 3.1, 3.9, "detail", 0.15, side=1)])
    louvres(sill, "intake", 0.6, 3.05, 3.15, 3.85, 6, off=-0.08)
    box("skirt", (5.8, -0.95, -0.9), (0.5, 0.06, 8.2), "secondary", mirror=True)
    lift_glow(sill, [(-4.2, -2.4), (-0.6, 1.4)])

    # Boost: centre insert of the tail fascia. Strake panel above, burners low in the diffuser.
    K.begin(c, "BOOST")
    box("panel", (0, 1.4, 10.98), (5.1, 1.1, 0.1), "detail")
    for i, y in enumerate((1.85, 1.6, 1.35, 1.1)):
        box(f"strake{i}", (0, y, 11.06), (5.0, 0.09, 0.2), "primary")
    Hull([(10.7, dict(w=2.5, yb=-0.42, yt=0.85)), (11.5, dict(w=2.3, yb=-0.3, yt=0.8))], rb=0.3, ys=0.5,
         tum=0.3, drop=0.0, wcf=0.5, d2=0.0, crown=0.0).build("housing", "secondary")
    t = Loft([(11.2, {}), (12.0, {})], cx=1.1, w=0.8, yb=-0.2, yt=0.62, nt=5, nb=5, yw=0.5)
    t.build("burner", "secondary", mirror=True, caps=(True, False))
    t.throat("noz", "max", lip="secondary", back="thrust", scale=0.84, depth=0.35, mirror=True)
    box("divider", (0, 0.2, 11.75), (0.06, 0.9, 0.7), "detail")

    K.begin(c, "WING")
    Loft([(-3.9, dict(w=0.6, cx=11.2)), (0, {}), (3.9, dict(w=0.6, cx=11.2))], axis="x", cx=11.05, w=0.8,
         yb=3.9, yt=4.08, yw=0.6, nt=2.2, nb=2.6).build("plane", "primary")
    blade("pylon", 2.9, 1.8, 3.94, (10.0, 11.1), (10.6, 11.5), "secondary")
    blade("plate", 3.92, 3.6, 4.35, (10.5, 11.9), (10.9, 12.1), "secondary", t=0.06)


# ---------------------------------------------------------------- car B: round

B_POD = dict(rb=0.5, tum=0.55, drop=0.35, tumi=0.03, dropi=0.14, wcf=0.35, d2=0.03, crown=0.14)
B_END = dict(rb=0.3, wcf=0.6, d2=0.02, drop=0.2, tum=0.25, crown=0.03)


def b_pod(pod, z0, z1, peak, caps):
    """Round fender over a dark arch, carbon rocker, dark crest, round vented shell in the arch."""
    pod.build("skin", "primary", mirror=True, caps=caps, regions=[
        R(z0 + 0.4, z1 - 0.3, 1.0, 2.15, "secondary", 0.02),
        R(peak - 1.5, peak + 1.5, 1.3, 2.9, "detail", 0.3, side=1),
        R(z0 + 0.8, z1 - 0.6, 5.4, 6.0, "secondary", 0.0),
        R(z1 - 0.2, z1 - 0.07, 0.0, 6.0, "neon", -0.01)])
    shell(pod, peak, 1.15, -0.72, 1.0, 2.0, rim="neon")
    x = pod.params(peak)["cx"] + pod.params(peak)["w"]
    hub = Loft([(x - 0.1, {}), (x + 0.1, {})], axis="x", cx=peak, w=0.3, yb=-0.16, yt=0.44, nt=2, nb=2, yw=0.5)
    hub.build("hub", "secondary", mirror=True)
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.8, depth=0.4, mirror=True)


def car_b():
    c = "B"
    K.begin(c, "COCKPIT")
    tub(scallop=False)
    can = Loft([(-6.7, dict(w=2.0, yb=1.8, yt=2.08)), (-4.8, dict(w=2.8, yt=3.2)), (-2.4, dict(w=3.05, yt=4.35)),
                (-0.4, dict(w=3.0, yt=4.6)), (2.0, dict(w=2.7, yt=4.3)),
                (4.6, dict(w=2.0, yb=2.15, yt=3.55)), (7.3, dict(w=0.9, yb=2.3, yt=2.7))],
               yb=1.95, yw=0.1, nt=2.3, nb=3.0)
    can.build("canopy", "primary", regions=[
        R(-6.3, 6.8, 8, 172, "glass", 0.03), R(-2.0, 7.2, 85, 95, "secondary", -0.04),
        R(1.1, 1.6, 8, 172, "secondary", -0.04), R(-2.4, -2.0, 8, 172, "secondary", -0.04)])

    K.begin(c, "NOSE")
    nose = Hull([(-11.2, dict(w=1.7, yb=0.0, yt=0.7, rb=0.25, ys=0.35, tum=0.3, drop=0.2, wcf=0.55, d2=0.03)),
                 (-10.3, dict(w=2.8, yb=-0.3, yt=1.15, ys=0.55, tum=0.45, drop=0.35)),
                 (-8.9, dict(w=3.6, yt=1.7, ys=0.9, tum=0.5, drop=0.42)),
                 (-7.0, dict(w=3.8, yt=2.1, ys=1.25, tum=0.38, drop=0.3, wcf=0.4, crown=0.07)),
                 (-5.2, SEAM_F)], yb=-0.4, rb=0.5, wcf=0.2, d2=0.12, crown=0.12)
    nose.build("skin", "primary", t1=-5.2 - GAP, caps=(False, True), regions=[
        R(-10.9, -5.6, 5.0, 6.0, "secondary", 0.0), R(-8.4, -7.1, 4.3, 4.75, "detail", 0.12)])
    nose.throat("mouth", "min", lip="primary", scale=0.78, depth=0.5)
    Loft([(-11.9, dict(w=2.5)), (-11.0, dict(w=3.6)), (-8.6, dict(w=3.75))], yb=-0.42, yt=0.1, nt=5, nb=5).build(
        "duct", "secondary")
    Loft([(-11.85, dict(w=2.3)), (-11.0, dict(w=3.4)), (-8.7, dict(w=3.6))], yb=0.0, yt=0.14, nt=5, nb=5).build(
        "floor", "detail")

    K.begin(c, "FPOD")
    pod = Hull([(-12.3, dict(cx=5.0, w=0.85, wi=0.9, yb=-0.2, yt=0.95, ys=0.4, rb=0.3)),
                (-11.3, dict(cx=5.06, w=1.1, wi=1.08, yb=-0.7, yt=1.6, ys=0.7)),
                (-9.9, dict(cx=5.12, w=1.22, wi=1.15, yb=-1.0, yt=2.15, ys=1.0)),
                (-8.4, dict(cx=5.15, w=1.25, wi=1.18, yb=-1.05, yt=2.3, ys=1.1)),
                (-6.6, dict(cx=5.08, w=1.08, wi=1.1, yb=-0.6, yt=1.7, ys=0.8)),
                (-5.4, dict(cx=4.95, w=0.78, wi=0.92, yb=0.1, yt=1.2, ys=0.65, **B_END))], **B_POD)
    b_pod(pod, -12.3, -5.4, -8.6, (True, False))
    pod.cap("face", "min", "detail", scale=0.94, push=-0.02, mirror=True)
    for i, (x, y, r) in enumerate(((4.74, 0.48, 0.27), (5.37, 0.34, 0.2))):
        lamp = tube(-12.46, -12.2, x, y, r)
        lamp.build(f"lamp{i}", "secondary", mirror=True)
        lamp.cap(f"lens{i}", "min", "lights", scale=0.8, push=-0.02, mirror=True)
    flange(-11.9, -5.6, 0.5)

    K.begin(c, "TAIL")
    tail = Hull([(2.8, SEAM_R), (5.5, dict(w=3.75, yt=2.55, tum=0.5, drop=0.42, crown=0.1)),
                 (8.5, dict(w=3.6, yb=-0.2, yt=2.3, ys=1.25, tum=0.7, drop=0.5, rb=0.7)),
                 (11.2, dict(w=3.4, yb=0.3, yt=2.0, ys=1.15, tum=0.8, drop=0.55, rb=0.85))],
                **{**SEAM_R, "rb": 0.5, "wcf": 0.3, "d2": 0.1, "crown": 0.14})
    tail.build("skin", "primary", t0=2.8 + GAP, caps=(True, False), regions=[
        R(8.8, 11.2, 0.0, 2.2, "secondary", 0.02), R(3.0, 7.4, 5.0, 6.0, "secondary", 0.0),
        R(6.2, 9.6, 4.25, 4.8, "detail", 0.12)])
    tail.throat("fascia", "max", lip="primary", scale=0.9, depth=0.25)
    lamp = tube(10.96, 11.2, 2.82, 1.2, 0.22)
    lamp.build("lamp", "secondary", mirror=True)
    lamp.cap("lens", "max", "lights_red", scale=0.78, push=0.02, mirror=True)
    fin = Loft([(7.4, dict(yt=2.6)), (10.2, dict(yt=2.98)), (11.15, dict(yt=2.2))], w=0.09, yb=1.85, nt=2, nb=2)
    fin.build("fin", "secondary")
    box("rain", (0, 2.3, 11.2), (0.16, 0.45, 0.08), "lights_red")

    K.begin(c, "RPOD")
    pod = Hull([(3.6, dict(cx=4.98, w=0.85, wi=0.95, yb=-0.3, yt=1.35, ys=0.7, rb=0.3)),
                (5.2, dict(cx=5.1, w=1.18, wi=1.14, yb=-0.95, yt=2.05, ys=1.0)),
                (7.0, dict(cx=5.15, w=1.25, wi=1.18, yb=-1.05, yt=2.25, ys=1.1)),
                (9.2, dict(cx=5.06, w=1.02, wi=1.06, yb=-0.5, yt=1.9, ys=1.0)),
                (10.6, dict(cx=4.88, w=0.68, wi=0.8, yb=0.2, yt=1.45, ys=0.85, **B_END))], **B_POD)
    b_pod(pod, 3.6, 10.6, 6.9, (False, False))
    pod.throat("intake", "min", lip="primary", scale=0.78, depth=0.4, mirror=True)
    flange(3.8, 10.0, 0.9)

    K.begin(c, "STAB")
    sill = Hull([(-5.2, dict(w=0.6, yb=-0.6, yt=0.25, ys=-0.1)), (-2.5, dict(w=0.9, yt=0.7, ys=0.15)),
                 (1.0, dict(w=1.0, yt=1.3, ys=0.6)), (3.4, dict(w=0.75, yb=-0.5, yt=1.1, ys=0.5))],
                cx=4.8, yb=-0.9, rb=0.35, tum=0.4, drop=0.25, wcf=0.4, d2=0.03, crown=0.12)
    sill.build("skin", "primary", mirror=True, regions=[
        R(-4.9, 3.1, 1.0, 2.3, "secondary", 0.02), R(0.9, 2.5, 3.2, 3.8, "detail", 0.12, side=1)])
    lift_glow(sill, [(-4.0, -2.4), (-0.6, 1.2)])

    # Boost: four rings high in the tail. Small keel below.
    K.begin(c, "BOOST")
    Loft([(10.8, dict(w=0.98)), (11.6, dict(w=0.9, yb=0.22, yt=1.93))],
         yb=0.15, yt=2.0, nt=2, nb=2, yw=0.5).build("shroud", "primary")
    for i, dy in enumerate((0.38, -0.38)):
        t = tube(11.2, 12.15, 0.38, 1.08 + dy, 0.31)
        t.build(f"burner{i}", "secondary", mirror=True, caps=(True, False))
        t.throat(f"noz{i}", "max", lip="secondary", back="thrust", scale=0.8, depth=0.3, mirror=True)
    box("keel", (0, -0.05, 11.2), (0.14, 0.6, 0.9), "secondary")

    K.begin(c, "WING")
    Loft([(2.2, dict(w=0.5, cx=10.8)), (3.9, dict(w=0.66, cx=11.0))], axis="x", yb=2.75, yt=2.9, yw=0.6,
         nt=2.2, nb=2.6).build("flap", "primary", mirror=True)
    blade("pylon", 3.0, 1.25, 2.79, (10.3, 11.1), (10.6, 11.3), "secondary")


# ---------------------------------------------------------------- builds and sheets

def kit(base, swaps=None, trim="STD", **override):
    swaps = swaps or {}
    keys = {s: f"{swaps.get(s, base)}_{s}_{trim}" for s in SLOTS}
    keys.update(override)
    return list(keys.values())


PODS = ("FPOD", "RPOD", "STAB")
REAR = ("TAIL", "BOOST", "WING")
ROWS = {
    "pure": (0, [kit("A"), kit("B")]),
    "swaps_on_a": (45, [kit("A", {"NOSE": "B"}), kit("A", {s: "B" for s in PODS}),
                        kit("A", {s: "B" for s in REAR}), kit("A", {s: "B" for s in SLOTS if s != "COCKPIT"})]),
    "swaps_on_b": (90, [kit("B", {"NOSE": "A"}), kit("B", {s: "A" for s in PODS}),
                        kit("B", {s: "A" for s in REAR}), kit("B", {s: "A" for s in SLOTS if s != "COCKPIT"})]),
}
SPACING = 17.0


def build_all(render=True):
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
        files.append(K.shot(j(OUT, "pure_top.jpg"), (0, 0, 0), 180, 89, 80, only=["pure0", "pure1"]))
    stats = {k: v["tris"] for k, v in K.MODS.items()}
    return {"problems": problems, "files": files, "stats": stats}
