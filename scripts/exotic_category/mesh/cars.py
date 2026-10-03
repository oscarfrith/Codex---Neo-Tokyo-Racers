"""Exotic pilot cars for the mesh blockout: car A (sharp, Hyper) and car B (round, Curve).

Run inside Blender:  import cars; cars.build_all()
Slots: COCKPIT, NOSE, TAIL, FPOD (Front Engines), RPOD (Rear Engines), STAB, BOOST, WING.

Layout, round 5:
  - Front engines are the front fenders and carry the headlights. Their jet exits at the back of
    the fender, over the sill. The nose is the centre section.
  - Rear engines are the rear fenders, tight to the body, nozzle at the tail.
  - Stabilisers are free-standing sill units between the fenders (as in round 2).
  - Body seams have a shadow gap: skins stop GAP short and a dark liner shows through.
  - The diffuser is the dark lower rear of the tail. The splitter is the chin of the nose.
  - Boost is the centre insert of the tail fascia, from diffuser height to the light line. Each boost
    chooses where its burners sit in that insert.

Car A is a wedge: nose leads, low front fenders, tall boxy rear haunches, squared tail with strakes,
burners low in the diffuser, tall wing. Detail language: bars, slots, strakes.
Car B is a teardrop: fenders lead and the nose is recessed between them, tall round front arches,
low tapering rear pods, drooping round tail with a dorsal fin, four-ring burners high in the tail.
Detail language: circles, rings, portholes.
"""
import os

import exokit as K
from exokit import GAP, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Hull, Loft, box

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


def nozzle(surf, name, end="max", mirror=True, rim=0.88, glow=0.66, ring=False):
    d = 1 if end == "max" else -1
    if ring:
        surf.cap(name + "_ring", end, "neon", scale=1.0, push=0.01 * d, mirror=mirror)
    surf.cap(name + "_rim", end, "detail", scale=rim, push=0.02 * d, mirror=mirror)
    surf.cap(name + "_liner", end, "secondary", scale=(rim + glow) / 2, push=0.03 * d, mirror=mirror)
    surf.cap(name + "_glow", end, "thrust", scale=glow, push=0.04 * d, mirror=mirror)


def blade(name, x, y0, y1, za, zb, ch, t=0.09):
    """Thin swept vertical blade (pylon or endplate). za and zb are (front, back) at y0 and y1."""
    Loft([(y0, dict(yb=za[0], yt=za[1])), (y1, dict(yb=zb[0], yt=zb[1]))], axis="y", cx=x, w=t,
         nt=2.2, nb=2.2, yw=0.4).build(name, ch, mirror=True)


def flange(z0, z1, y1):
    """Dark mounting flange between a pod and the body. It closes the gap from above."""
    box("flange", (3.56, (y1 - 0.3) / 2, (z0 + z1) / 2), (0.16, y1 + 0.3, z1 - z0), "detail", mirror=True)


def tub():
    Hull([(-5.2, SEAM_F), (-1.0, dict(SEAM_F, yt=2.6)), (2.8, SEAM_R)]).build(
        "tub", "primary", t0=-5.2 + GAP, t1=2.8 - GAP)
    Hull([(-5.28, SEAM_F), (-1.0, dict(SEAM_F, yt=2.6)), (2.88, SEAM_R)]).build("liner", "detail", scale=0.96)


# ---------------------------------------------------------------- car A: sharp

A_POD = dict(rb=0.3, tum=0.3, drop=0.2, tumi=0.03, dropi=0.1, wcf=0.5, d2=0.04, crown=0.025)


def a_pod_features(pod, z0, z1, peak):
    pod.patch("rocker", z0 + 0.3, z1 - 0.2, 1.0, 2.1, "secondary", mirror=True)
    pod.patch("core", peak - 1.6, peak + 1.5, 2.2, 2.86, "detail", mirror=True)
    for i, u in enumerate((2.34, 2.5, 2.66)):
        pod.patch(f"strake{i}", peak - 1.4, peak + 1.3, u, u + 0.05, "secondary", off=0.08, mirror=True)
    pod.patch("bar", peak - 1.6, peak + 1.5, 2.91, 2.97, "neon", off=0.07, mirror=True)
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])


def a_burners(y0, y1, z1):
    t = rect([(11.0, {}), (z1, {})], 1.0, 0.72, y0, y1, c=0.14)
    t.build("burner", "secondary", mirror=True)
    nozzle(t, "noz", rim=0.86, glow=0.62)


def car_a():
    c = "A"
    K.begin(c, "COCKPIT")
    tub()
    can = Hull([(-6.7, dict(w=2.4, yt=2.5, tum=0.3, drop=0.02)), (-4.6, dict(w=3.0, yt=3.45, tum=0.75)),
                (-2.4, dict(yt=4.4)), (-0.4, dict(yt=4.6)), (1.6, dict(w=3.05, yt=4.5)),
                (4.2, dict(w=2.9, yb=2.4, yt=3.8, ys=2.6)),
                (7.2, dict(w=2.6, yb=2.6, yt=3.05, ys=2.8, tum=0.7, drop=0.1))],
               w=3.1, yb=2.1, ys=2.45, rb=0.1, tum=1.05, drop=0.16, wcf=0.72, d2=0.03, crown=0.03)
    can.build("canopy", "primary")
    can.patch("screen", -6.45, -2.6, 3.06, 6.0, "glass", mirror=True)
    can.patch("side", -2.3, 1.7, 3.08, 3.9, "glass", mirror=True)
    can.patch("roof", -2.6, 1.9, 4.08, 6.0, "secondary", off=0.06, mirror=True)
    for i in range(5):
        can.patch(f"louvre{i}", 2.4 + i * 0.9, 2.95 + i * 0.9, 4.15, 6.0, "secondary", off=0.1, mirror=True)
    can.patch("quarter", 2.2, 6.4, 3.15, 3.8, "detail", mirror=True)

    K.begin(c, "NOSE")
    nose = Hull([(-12.5, dict(w=3.4, yb=-0.3, yt=0.6, rb=0.2, ys=0.25, tum=0.12, drop=0.1)),
                 (-11.0, dict(w=3.45, yt=1.15, ys=0.6, tum=0.2, drop=0.2)),
                 (-8.5, dict(w=3.5, yt=1.9, ys=1.1, tum=0.28, drop=0.3)),
                 (-6.4, dict(w=3.5, yt=2.35, ys=1.45, tum=0.3, drop=0.3, crown=0.04)), (-5.2, SEAM_F)],
                yb=-0.4, rb=0.45, wcf=0.62, d2=0.06, crown=0.015)
    nose.build("skin", "primary", t1=-5.2 - GAP)
    nose.cap("mouth", "min", "detail", scale=0.78, push=-0.02)
    nose.patch("bar", -12.42, -12.25, 3.1, 6.0, "lights", off=0.06, mirror=True)
    nose.patch("hood", -10.9, -7.2, 5.08, 6.0, "secondary", mirror=True)
    nose.patch("vent", -8.2, -7.0, 4.25, 4.8, "detail", mirror=True)
    nose.patch("chin", -12.4, -10.4, 0.2, 2.3, "secondary", mirror=True)

    K.begin(c, "FPOD")
    pod = Hull([(-12.1, dict(cx=4.62, w=0.95, wi=0.98, yb=-0.3, yt=0.72, ys=0.25, drop=0.1)),
                (-11.0, dict(cx=4.64, w=1.05, wi=1.0, yb=-0.7, yt=1.25, ys=0.6)),
                (-9.4, dict(cx=4.67, w=1.16, wi=1.05, yb=-1.0, yt=1.85, ys=1.0)),
                (-7.6, dict(cx=4.7, w=1.15, wi=1.08, yb=-1.1, yt=2.15, ys=1.2)),
                (-6.3, dict(cx=4.66, w=1.08, wi=1.04, yb=-0.8, yt=1.85, ys=1.0)),
                (-5.4, dict(SIDE_F, yb=-0.1, yt=1.45, ys=0.75, rb=0.2))], **A_POD)
    pod.build("skin", "primary", mirror=True)
    pod.cap("intake", "min", "detail", scale=0.78, push=-0.02, mirror=True)
    nozzle(pod, "noz", rim=0.82, glow=0.56)
    for side in (1, -1):
        pod.patch(f"lamp{side}", -12.02, -11.84, 3.1, 6.0, "lights", side=side, off=0.06, mirror=True)
    pod.patch("brow", -11.8, -10.0, 3.02, 3.25, "lights", off=0.06, mirror=True)
    a_pod_features(pod, -12.1, -5.4, -7.9)
    flange(-11.8, -5.6, 0.6)

    K.begin(c, "TAIL")
    tail = Hull([(2.8, SEAM_R), (5.5, dict(yt=2.9)), (8.6, dict(yt=2.9, ys=1.7, tum=0.25, drop=0.3)),
                 (10.0, dict(yb=0.0, yt=2.9, ys=1.8, tum=0.22, drop=0.28)),
                 (11.2, dict(w=3.45, yb=0.45, yt=2.95, ys=1.9, tum=0.2, drop=0.25, rb=0.3))],
                w=3.5, yb=-0.4, rb=0.45, ys=1.55, tum=0.3, drop=0.35, wcf=0.62, d2=0.06, crown=0.03)
    tail.build("skin", "primary", t0=2.8 + GAP)
    tail.cap("fascia", "max", "detail", scale=0.95, push=0.02)
    box("blade", (0, 2.62, 11.27), (6.3, 0.12, 0.1), "lights_red")
    for i, y in enumerate((2.3, 2.0, 1.7, 1.4, 1.1, 0.8)):
        box(f"strake{i}", (2.88, y, 11.3), (0.9, 0.1, 0.14), "primary", mirror=True)
    tail.patch("cover", 7.7, 10.4, 5.08, 6.0, "secondary", mirror=True)
    tail.patch("vent", 6.4, 10.2, 4.2, 4.85, "detail", mirror=True)
    tail.patch("diffuser", 8.6, 11.2, 0.0, 2.3, "secondary", mirror=True)
    for i, x in enumerate((2.6, 3.15)):
        box(f"fin{i}", (x, 0.05, 10.95), (0.1, 0.8, 1.1), "detail", mirror=True)

    K.begin(c, "RPOD")
    pod = Hull([(3.6, dict(SIDE_R, yb=-0.5, yt=1.75)), (5.0, dict(cx=4.68, w=1.15, wi=1.06, yb=-1.0, yt=2.5, ys=1.3)),
                (7.3, dict(cx=4.7, w=1.18, wi=1.08, yb=-1.1, yt=3.05, ys=1.75)),
                (9.4, dict(cx=4.7, w=1.16, wi=1.08, yb=-1.0, yt=2.9, ys=1.75)),
                (10.6, dict(cx=4.68, w=1.05, wi=1.04, yb=-0.6, yt=2.5, ys=1.55))], **A_POD)
    pod.build("skin", "primary", mirror=True)
    pod.cap("intake", "min", "detail", scale=0.8, push=-0.02, mirror=True)
    nozzle(pod, "noz", rim=0.86, glow=0.6)
    a_pod_features(pod, 3.6, 10.6, 7.3)
    flange(3.8, 10.3, 1.2)

    K.begin(c, "STAB")
    sill = Hull([(-5.2, dict(yb=-0.8, yt=0.45, ys=0.0)), (-2.0, dict(yt=0.75, ys=0.2)),
                 (1.5, dict(yt=1.5, ys=0.8)), (3.4, dict(yb=-0.7, yt=1.75, ys=1.0))],
                cx=4.45, w=0.98, yb=-0.9, rb=0.25, tum=0.3, drop=0.12, wcf=0.5, d2=0.03, crown=0.02)
    sill.build("skin", "primary", mirror=True)
    sill.patch("intake", 0.5, 3.15, 3.1, 3.9, "detail", mirror=True)
    sill.patch("band", -5.0, 3.2, 1.0, 2.35, "secondary", mirror=True)
    lift_glow(sill, [(-4.2, -2.4), (-0.6, 1.4)])

    # Boost, standard: burners low, in the diffuser. Strake panel above.
    K.begin(c, "BOOST")
    box("panel", (0, 1.5, 11.28), (4.5, 1.2, 0.1), "detail")
    for i, y in enumerate((2.0, 1.7, 1.4, 1.1)):
        box(f"strake{i}", (0, y, 11.34), (4.4, 0.1, 0.14), "primary")
    rect([(10.7, {}), (11.6, {})], 0, 2.25, -0.4, 0.82, c=0.15).build("housing", "secondary")
    a_burners(-0.24, 0.66, 12.0)

    # Boost option: burners high, where the exhausts were in round 2.
    K.begin(c, "FREE", "BOOSTHI")
    rect([(10.9, {}), (11.7, {})], 0, 2.0, 0.5, 1.9, c=0.2).build("shroud", "primary")
    a_burners(0.62, 1.78, 12.15)
    for i, x in enumerate((0.6, 1.7)):
        box(f"fin{i}", (x, 0.05, 11.0), (0.1, 0.8, 1.1), "secondary", mirror=True)

    K.begin(c, "WING")
    Loft([(-3.5, dict(w=0.6, cx=11.2)), (0, {}), (3.5, dict(w=0.6, cx=11.2))], axis="x", cx=11.05, w=0.8,
         yb=4.18, yt=4.36, yw=0.6, nt=2.2, nb=2.6).build("plane", "primary")
    blade("pylon", 2.6, 2.0, 4.22, (10.0, 11.1), (10.6, 11.5), "secondary")
    blade("plate", 3.52, 3.85, 4.62, (10.5, 11.9), (10.9, 12.1), "secondary", t=0.06)


# ---------------------------------------------------------------- car B: round

B_POD = dict(rb=0.5, tum=0.55, drop=0.35, tumi=0.03, dropi=0.14, wcf=0.35, d2=0.03, crown=0.14)


def b_pod_features(pod, z0, z1, peak, y):
    pod.patch("rocker", z0 + 0.4, z1 - 0.3, 1.0, 2.15, "secondary", mirror=True)
    pod.patch("crest", z0 + 0.8, z1 - 0.6, 5.4, 6.0, "secondary", mirror=True)
    x = pod.params(peak)["cx"] + pod.params(peak)["w"]
    for i, (dz, r) in enumerate(((-1.1, 0.42), (-0.1, 0.35), (0.72, 0.28))):
        port = Loft([(x - 0.3, {}), (x + 0.24, {})], axis="x", cx=peak + dz, w=r, yb=y - r, yt=y + r,
                    nt=2, nb=2, yw=0.5)
        port.build(f"port{i}", "secondary", mirror=True)
        port.cap(f"hole{i}", "max", "detail", scale=0.72, push=0.02, mirror=True)
    lift_glow(pod, [(peak - 1.0, peak + 1.0)])


def b_burners(y, z1):
    for i, dy in enumerate((0.4, -0.4)):
        t = tube(11.2, z1, 0.4, y + dy, 0.33)
        t.build(f"burner{i}", "secondary", mirror=True)
        nozzle(t, f"noz{i}", rim=0.84, glow=0.6)


def car_b():
    c = "B"
    K.begin(c, "COCKPIT")
    tub()
    can = Loft([(-6.7, dict(w=1.8, yt=2.45)), (-4.8, dict(w=2.6, yt=3.5)), (-2.4, dict(w=2.85, yt=4.75)),
                (-0.4, dict(w=2.8, yt=5.05)), (2.0, dict(w=2.5, yt=4.7)),
                (4.6, dict(w=1.9, yb=2.4, yt=3.9)), (7.3, dict(w=0.9, yb=2.6, yt=3.0))],
               yb=2.2, yw=0.1, nt=2.3, nb=3.0)
    can.build("canopy", "primary")
    can.patch("glass", -6.3, 6.8, 8, 172, "glass")
    can.patch("spine", -2.0, 7.2, 85, 95, "secondary", off=0.1)
    can.patch("hoop", 1.1, 1.6, 8, 172, "secondary", off=0.1)
    can.patch("header", -2.4, -2.0, 8, 172, "secondary", off=0.1)

    K.begin(c, "NOSE")
    nose = Hull([(-11.2, dict(w=1.6, yb=0.0, yt=0.8, rb=0.25, ys=0.4, tum=0.3, drop=0.2, wcf=0.55, d2=0.03)),
                 (-10.3, dict(w=2.6, yb=-0.3, yt=1.3, ys=0.6, tum=0.45, drop=0.35)),
                 (-8.9, dict(w=3.35, yt=1.9, ys=1.0, tum=0.5, drop=0.45)),
                 (-7.0, dict(w=3.5, yt=2.35, ys=1.45, tum=0.35, drop=0.32, wcf=0.4, crown=0.07)),
                 (-5.2, SEAM_F)], yb=-0.4, rb=0.5, wcf=0.2, d2=0.12, crown=0.12)
    nose.build("skin", "primary", t1=-5.2 - GAP)
    nose.cap("mouth", "min", "detail", scale=0.72, push=-0.02)
    nose.patch("spine", -10.9, -5.6, 5.0, 6.0, "secondary", mirror=True)
    nose.patch("vent", -8.4, -7.1, 4.3, 4.75, "detail", mirror=True)
    Loft([(-11.9, dict(w=2.3)), (-11.0, dict(w=3.3)), (-8.6, dict(w=3.45))], yb=-0.42, yt=0.1, nt=5, nb=5).build(
        "duct", "secondary")
    Loft([(-11.85, dict(w=2.1)), (-11.0, dict(w=3.1)), (-8.7, dict(w=3.3))], yb=0.0, yt=0.14, nt=5, nb=5).build(
        "floor", "detail")

    K.begin(c, "FPOD")
    pod = Hull([(-12.3, dict(cx=4.58, w=0.8, wi=0.85, yb=-0.2, yt=1.05, ys=0.45, rb=0.3)),
                (-11.3, dict(cx=4.62, w=1.02, wi=1.0, yb=-0.7, yt=1.8, ys=0.8)),
                (-9.9, dict(cx=4.66, w=1.12, wi=1.04, yb=-1.0, yt=2.4, ys=1.1)),
                (-8.4, dict(cx=4.68, w=1.14, wi=1.06, yb=-1.05, yt=2.55, ys=1.2)),
                (-6.6, dict(cx=4.62, w=0.98, wi=1.0, yb=-0.6, yt=1.9, ys=0.9)),
                (-5.4, dict(cx=4.5, w=0.72, wi=0.86, yb=0.1, yt=1.35, ys=0.75, rb=0.3, wcf=0.6, d2=0.02, drop=0.2,
                            tum=0.25, crown=0.03))], **B_POD)
    pod.build("skin", "primary", mirror=True)
    pod.cap("face", "min", "detail", scale=0.94, push=-0.02, mirror=True)
    for i, (x, y, r) in enumerate(((4.32, 0.52, 0.27), (4.95, 0.38, 0.2))):
        lamp = tube(-12.46, -12.2, x, y, r)
        lamp.build(f"lamp{i}", "secondary", mirror=True)
        lamp.cap(f"lens{i}", "min", "lights", scale=0.8, push=-0.02, mirror=True)
    nozzle(pod, "noz", rim=0.86, glow=0.6, ring=True)
    b_pod_features(pod, -12.3, -5.4, -8.6, 0.35)
    flange(-11.9, -5.6, 0.6)

    K.begin(c, "TAIL")
    tail = Hull([(2.8, SEAM_R), (5.5, dict(w=3.45, yt=2.85, tum=0.5, drop=0.45, crown=0.1)),
                 (8.5, dict(w=3.35, yb=-0.2, yt=2.55, ys=1.4, tum=0.7, drop=0.55, rb=0.7)),
                 (11.2, dict(w=3.15, yb=0.3, yt=2.2, ys=1.3, tum=0.8, drop=0.6, rb=0.85))],
                w=3.5, yb=-0.4, rb=0.5, ys=1.55, tum=0.3, drop=0.35, wcf=0.3, d2=0.1, crown=0.14)
    tail.build("skin", "primary", t0=2.8 + GAP)
    tail.cap("fascia", "max", "detail", scale=0.92, push=0.02)
    lamp = tube(11.1, 11.36, 2.58, 1.3, 0.25)
    lamp.build("lamp", "secondary", mirror=True)
    lamp.cap("lens", "max", "lights_red", scale=0.78, push=0.02, mirror=True)
    fin = Loft([(7.4, dict(yt=2.9)), (10.2, dict(yt=3.28)), (11.15, dict(yt=2.5))], w=0.09, yb=2.1, nt=2, nb=2)
    fin.build("fin", "secondary")
    box("rain", (0, 2.6, 11.2), (0.16, 0.5, 0.08), "lights_red")
    tail.patch("vent", 6.2, 9.6, 4.25, 4.8, "detail", mirror=True)
    tail.patch("spine", 3.0, 7.4, 5.0, 6.0, "secondary", mirror=True)
    tail.patch("diffuser", 8.8, 11.2, 0.0, 2.2, "secondary", mirror=True)

    K.begin(c, "RPOD")
    pod = Hull([(3.6, dict(cx=4.55, w=0.8, wi=0.9, yb=-0.3, yt=1.5, ys=0.8, rb=0.3)),
                (5.2, dict(cx=4.66, w=1.08, wi=1.04, yb=-0.95, yt=2.25, ys=1.1)),
                (7.0, dict(cx=4.68, w=1.12, wi=1.06, yb=-1.05, yt=2.45, ys=1.2)),
                (9.2, dict(cx=4.62, w=0.95, wi=0.98, yb=-0.5, yt=2.1, ys=1.1)),
                (10.6, dict(cx=4.45, w=0.62, wi=0.75, yb=0.2, yt=1.6, ys=0.9, rb=0.3, wcf=0.6, d2=0.02, drop=0.2,
                            tum=0.25, crown=0.03))], **B_POD)
    pod.build("skin", "primary", mirror=True)
    pod.cap("intake", "min", "detail", scale=0.78, push=-0.02, mirror=True)
    nozzle(pod, "noz", rim=0.86, glow=0.6, ring=True)
    b_pod_features(pod, 3.6, 10.6, 6.9, 0.35)
    flange(3.8, 10.0, 1.0)

    K.begin(c, "STAB")
    sill = Hull([(-5.2, dict(w=0.55, yb=-0.6, yt=0.3, ys=-0.1)), (-2.5, dict(w=0.85, yt=0.8, ys=0.2)),
                 (1.0, dict(w=0.98, yt=1.45, ys=0.7)), (3.4, dict(w=0.7, yb=-0.5, yt=1.25, ys=0.6))],
                cx=4.35, yb=-0.9, rb=0.35, tum=0.4, drop=0.25, wcf=0.4, d2=0.03, crown=0.12)
    sill.build("skin", "primary", mirror=True)
    sill.patch("intake", 0.9, 2.5, 3.2, 3.8, "detail", mirror=True)
    sill.patch("band", -4.9, 3.1, 1.0, 2.3, "secondary", mirror=True)
    lift_glow(sill, [(-4.0, -2.4), (-0.6, 1.2)])

    # Boost, standard: four rings high in the tail. Small keel below.
    K.begin(c, "BOOST")
    Loft([(10.8, dict(w=1.0)), (11.6, dict(w=0.93, yb=0.32, yt=2.08))],
         yb=0.25, yt=2.15, nt=2, nb=2, yw=0.5).build("shroud", "primary")
    b_burners(1.2, 12.15)
    box("keel", (0, -0.05, 11.2), (0.14, 0.6, 0.9), "secondary")

    # Boost option: the same cluster low, in the diffuser.
    K.begin(c, "FREE", "BOOSTLO")
    Loft([(10.7, dict(w=1.0)), (11.6, dict(w=0.93, yb=-0.38, yt=1.38))],
         yb=-0.45, yt=1.45, nt=2, nb=2, yw=0.5).build("shroud", "secondary")
    b_burners(0.5, 12.1)
    tube(11.1, 11.36, 0, 1.8, 0.2).build("badge", "primary")

    K.begin(c, "WING")
    Loft([(1.9, dict(w=0.5, cx=10.8)), (3.5, dict(w=0.66, cx=11.0))], axis="x", yb=3.02, yt=3.17, yw=0.6,
         nt=2.2, nb=2.6).build("flap", "primary", mirror=True)
    blade("pylon", 2.7, 1.95, 3.06, (10.3, 11.1), (10.6, 11.3), "secondary")


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
    "boost_options": (-45, [kit("A"), kit("A", BOOST="A_FREE_BOOSTHI"), kit("B"), kit("B", BOOST="B_FREE_BOOSTLO")]),
    "swaps_on_a": (45, [kit("A", {"NOSE": "B"}), kit("A", {s: "B" for s in PODS}),
                        kit("A", {s: "B" for s in REAR}), kit("A", {s: "B" for s in SLOTS if s != "COCKPIT"})]),
    "swaps_on_b": (90, [kit("B", {"NOSE": "A"}), kit("B", {s: "A" for s in PODS}),
                        kit("B", {s: "A" for s in REAR}), kit("B", {s: "A" for s in SLOTS if s != "COCKPIT"})]),
}
SPACING = 16.0


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
            d = 30 + 15 * len(builds)
            only = [f"{row}{i}" for i in range(len(builds))]
            if row == "boost_options":
                files.append(K.shot(j(OUT, f"{row}_rear.png"), (0, 0.8, oz + 6), 12, 9, d, only=only))
                continue
            files.append(K.shot(j(OUT, f"{row}_front.png"), (0, 0.8, oz), 150, 12, d, only=only))
            files.append(K.shot(j(OUT, f"{row}_rear.png"), (0, 0.8, oz), 30, 12, d, only=only))
        for car, x, az in (("a", -SPACING / 2, 270), ("b", SPACING / 2, 90)):
            only = ["pure0" if car == "a" else "pure1"]
            files.append(K.shot(j(OUT, f"{car}_side.png"), (x, 1.0, 0), az, 4, 60, only=only))
            files.append(K.shot(j(OUT, f"{car}_rear_close.png"), (x, 1.0, 3), 24, 14, 38, only=only))
            files.append(K.shot(j(OUT, f"{car}_front_close.png"), (x, 1.0, -3), 152, 14, 38, only=only))
        files.append(K.shot(j(OUT, "pure_top.png"), (0, 0, 0), 180, 89, 80, only=["pure0", "pure1"]))
    stats = {k: (v["tris"], sorted(v["channels"])) for k, v in K.MODS.items()}
    return {"problems": problems, "files": files, "stats": stats}
