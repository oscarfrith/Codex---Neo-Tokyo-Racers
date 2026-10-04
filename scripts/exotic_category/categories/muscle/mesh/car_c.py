"""Car C: Slingshot (muscle_03), after the Chevrolet Camaro SS (2022, sixth generation). STD trim only.

Design language of C: the sharp, low, angular one. Wedge nose with a thin upper grille slot over a huge open
lower mouth, a flat black heat extractor sunk in the bonnet, the lowest
roof of the family over a narrow band of side glass and very high shoulders, black roof, a short chopped
Kamm tail with four small red lamps on a dark panel, a thin blade wing on two short uprights, and square
nozzles everywhere: one flat wide slot per rear pod, three small squares per sill, four in the overdrive.

Pods and sill (round 2): arrowheads. A hexagonal section with one knife-edge chine at mid height that runs
in a straight line from the pointed prow of the front pod, along the wedge sill, to the square Kamm end of
the rear pod. Yellow above the chine, black below. Slit lamps are sunk in the upper facet at the prow.
"""
import exokit as K
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, POD_LINE, bazooka, barrel, build_car, flange, lift_glow, tub

def c_cockpit():
    """Chopped coupe cabin: steep screen, the lowest roof of the six, a slit of side glass over a tall
    body-colour shoulder, and a short fast rear window. Black roof."""
    K.begin("C", "COCKPIT")
    tub()
    gh = Hull([(-6.0, dict(w=3.5, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.7, dict(w=3.6, yt=4.2, ys=3.42, tum=0.45, drop=0.15)),
               (-3.3, dict(yt=4.98, tum=0.62)),
               (-1.6, dict(yt=5.2, tum=0.66)),
               (1.0, dict(yt=5.17, tum=0.68)),
               (2.8, dict(yt=4.9, tum=0.7)),
               (4.6, dict(w=3.46, yt=4.1, ys=3.42, tum=0.55, drop=0.16)),
               (6.3, dict(w=3.4, yb=3.15, yt=3.3, ys=3.2, tum=0.2, drop=0.03, crown=0.02))],
              w=3.62, yb=3.1, ys=3.6, rb=0.04, tum=0.66, drop=0.2, wcf=0.76, d2=0.04, crown=0.04)
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.38, 4.13, 6.0, "detail", 0.015),    # windscreen surround
        R(-5.75, -3.49, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.75, 4.4, 3.06, 3.86, "detail", 0.015),     # side glass surround, one opening
        R(-4.64, 0.7, 3.11, 3.81, "glass", 0.04),       # door glass
        R(1.0, 4.28, 3.11, 3.81, "glass", 0.04),        # quarter glass
        R(3.02, 6.06, 4.14, 6.0, "detail", 0.015),      # rear window surround
        R(3.12, 5.96, 4.195, 6.0, "glass", 0.04),       # rear window
        R(-3.2, 2.84, 4.14, 6.0, "secondary", 0.02)])   # black roof


def c_nose():
    """Wedge nose: the bonnet falls to a low sharp edge. A thin grille slot under the brow, then one bumper
    frame round a huge open mouth. Flat heat extractor sunk in the bonnet centre."""
    K.begin("C", "NOSE")
    nose = Hull([(-12.4, dict(w=3.5, yb=-0.2, yt=2.2, ys=1.8, rb=0.3, tum=0.22, drop=0.15)),
                 (-11.0, dict(w=3.78, yb=-0.35, yt=2.52, ys=2.0, rb=0.4)),
                 (-8.5, dict(w=3.9, yt=2.96, ys=2.3)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.4, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.8, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-10.2, -6.6, 5.3, 6.0, "secondary", 0.02),    # extractor frame
        R(-9.9, -6.9, 5.42, 6.0, "detail", 0.1)])       # heat extractor
    nose.cap("grilleback", "min", "detail")
    # brow: the sharp leading edge of the bonnet; the thin grille slot is the gap under it
    Hull([(-13.1, dict(w=3.3, yb=1.9, yt=2.06, ys=1.96)), (-12.4, dict(w=3.5, yb=1.84, yt=2.2, ys=2.0))], rb=0.03,
         tum=0.2, drop=0.1, wcf=0.72, d2=0.02, crown=0.02).build("brow", "primary")
    # bumper frame with the open mouth
    bump = Hull([(-13.25, dict(w=3.32, yb=-0.08, yt=1.5, ys=1.2)), (-12.4, dict(w=3.5, yb=-0.2, yt=1.56, ys=1.25))],
                rb=0.5, tum=0.12, drop=0.06, wcf=0.8, d2=0.0, crown=0.0, cs=0.0)
    bump.build("bumper", "primary", caps=(False, False))
    bump.throat("mouth", "min", lip="primary", wall="detail", back="detail", scale=0.84, depth=0.7)
    Loft([(-13.6, dict(w=2.9)), (-12.9, dict(w=3.5)), (-11.2, dict(w=3.8))], yb=-0.46, yt=-0.34, nt=6,
         nb=6).build("chin", "secondary")


class Facet(Hull):
    """Faceted pod section for C: a hexagon with a knife-edge chine. Absolute x per station: xi inboard wall,
    xo chine, xf floor edge, xt top edge. yc is the chine height; the top falls by drop from the inboard
    edge to the outboard one. Ring u: 0 to 1 floor, 1 to 2 lower facet, 2 chine, 2 to 3 upper facet, 3 to 6 top."""
    KEYS = ("xi", "xo", "xf", "xt", "yb", "yt", "yc", "drop")
    BASE = dict(xi=4.1, xo=6.0, xf=5.5, xt=5.5, yb=-1.0, yt=1.0, yc=0.0, drop=0.12)

    def __init__(self, stations, **defaults):
        Hull.__init__(self, stations, "z", (1, 2, 3), **defaults)

    def _fill(self, row):
        pass

    def params(self, t):
        p = Hull.params(self, t)
        if "cx" not in p:
            p["cx"] = (p["xi"] + p["xo"]) / 2
        return p

    def _half(self, p, side, u):
        cx, xi = p["cx"], p["xi"]
        xt = max(p["xt"], cx + 0.01)
        top = (0.0, p["yt"] - p["drop"] * (cx - xi) / (xt - xi))
        if side > 0:
            k = ((0.0, p["yb"]), (max(p["xf"] - cx, 0.01), p["yb"]), (p["xo"] - cx, p["yc"]),
                 (xt - cx, p["yt"] - p["drop"]), top)
        else:
            k = ((0.0, p["yb"]), (cx - xi, p["yb"]), (cx - xi, p["yc"]), (cx - xi, p["yt"]), top)
        u = min(max(u, 0.0), 6.0)
        if u >= 3.0:
            i, s = 3, (u - 3.0) / 3.0
        else:
            i = int(u)
            s = u - i
        (x0, y0), (x1, y1) = k[i], k[i + 1]
        return x0 + (x1 - x0) * s, y0 + (y1 - y0) * s


def chine(z):
    """One straight chine line from the prow to the Kamm tail, rising a little toward the back."""
    return 0.3 + 0.024 * z


def fs(z, xi, xo, xf, xt, yb, yt, drop=0.12):
    return (z, dict(xi=xi, xo=xo, xf=xf, xt=xt, yb=yb, yt=yt, yc=chine(z), drop=drop))


def flat(keys, e=0.12):
    """Stations for straight-edged facets: every value runs in a straight line between the key stations
    (an extra station just each side of a key and one mid span keep the spline from rounding the breaks)."""
    out = []
    for (z0, a), (z1, b) in zip(keys, keys[1:]):
        for z in (z0, z0 + e, (z0 + z1) / 2, z1 - e):
            s = (z - z0) / (z1 - z0)
            out.append((z, {k: a[k] + (b[k] - a[k]) * s for k in a}))
    return out + [keys[-1]]


def c_fpod():
    """Arrowhead: flat facets run from a pointed prow at chine height to the widest point two thirds back,
    then draw in again to the sill. Yellow above the chine, black below. Slit lamps are sunk in the upper
    facet at the prow."""
    K.begin("C", "FPOD")
    c = chine(-13.0)
    pod = Facet(flat([fs(-13.0, 4.46, 4.56, 4.53, 4.53, c - 0.04, c + 0.04, drop=0.01),
                      fs(-11.0, 4.1, 5.72, 5.2, 5.05, -0.78, 0.95, drop=0.06),
                      fs(-8.8, 4.1, 6.8, 5.95, 5.72, -1.4, 1.85),
                      fs(POD_FZ, 4.1, 6.2, 5.92, 5.75, -1.4, 2.02)]))
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=[
        R(-13.0, POD_FZ, 0.0, 2.0, "secondary", 0.0),
        R(-12.5, -10.5, 2.1, 2.5, "detail", 0.015, side=1),     # lamp surround in the facet
        R(-12.4, -10.6, 2.16, 2.44, "lights", 0.04, side=1),    # slit lamp
        R(-11.5, -10.6, 2.6, 2.74, "lights", 0.03, side=1)])    # short slit above it
    pod.cap("end", "max", "secondary", mirror=True)
    barrel("noz", -7.0, -5.94, 5.0, 1.42, 0.6, depth=0.5, collar=False, ry=0.27, n=7)
    flange(-10.6, -6.4, -0.3, 1.0)
    lift_glow(pod, [(-10.0, -7.4)])


def c_rpod():
    """The same diamond section, low and flat, cut off square as a Kamm tail: a black faceted end frame
    round one flat wide slot nozzle."""
    K.begin("C", "RPOD")
    pod = Facet(flat([fs(POD_RZ, 4.1, 6.2, 5.92, 5.75, -1.4, 2.08),
                      fs(6.4, 4.1, 6.8, 6.0, 5.85, -1.4, 2.18),
                      fs(12.2, 4.1, 6.85, 6.05, 5.9, -1.1, 2.1)]))
    pod.build("skin", "primary", mirror=True, caps=(False, False), regions=[
        R(POD_RZ, 12.2, 0.0, 2.0, "secondary", 0.0)])
    pod.throat("intake", "min", lip="primary", wall="detail", back="detail", scale=0.76, depth=0.5, mirror=True)
    pod.throat("frame", "max", lip="secondary", wall="detail", back="detail", scale=0.74, depth=0.3, mirror=True)
    barrel("slot", 11.4, 12.4, 5.475, 0.5, 0.92, depth=0.3, collar=False, ry=0.36, n=7)
    flange(4.4, 10.6, -0.3, 1.9)
    lift_glow(pod, [(5.8, 9.6)])


def c_stab():
    """Faceted wedge sill that carries the chine between the pods; three small square thrusters set in
    its lower facet, swept back and down."""
    K.begin("C", "STAB")
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    sill = Facet([fs(z0, 4.1, 5.9, 5.25, 5.06, -1.2, 1.0), fs(z1, 4.1, 5.9, 5.25, 5.06, -1.2, 1.0)], drop=0.1)
    sill.build("skin", "primary", mirror=True, regions=[R(z0, z1, 0.0, 2.0, "secondary", 0.0)])
    for i, z in enumerate((-2.9, -1.7, -0.5)):
        bazooka(f"jet{i}", 5.2, 6.3, z, -0.3, 0.34, back=0.7, down=0.5, wide=1.0, flat=1.0, n=7)
    lift_glow(sill, [(-5.0, -3.8), (1.8, 3.0)])


def c_tail():
    """Short deck to a chopped Kamm tail. The tail face is a recessed dark panel with four small red lamps."""
    K.begin("C", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.3)), (9.8, dict(yt=3.46, ys=2.65)), (10.6, dict(yb=-0.3)),
                 (11.2, dict(yb=1.4, rb=0.25)),
                 (11.8, dict(w=3.74, yb=1.5, yt=3.5, ys=2.8, rb=0.25, tum=0.26, drop=0.18))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 11.8, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 11.4, LINE[0], LINE[1], "primary", 0.025)])
    tail.cap("panel", "max", "detail")
    Hull([(11.8, dict(w=3.74, yb=3.1, yt=3.5, ys=3.24)), (12.25, dict(w=3.7, yb=3.16, yt=3.48, ys=3.28))], rb=0.03,
         tum=0.26, drop=0.16, wcf=0.74, d2=0.05, crown=0.03).build("decklip", "primary")
    Hull([(11.8, dict(w=3.74, yb=1.5, yt=2.3, ys=2.1)), (12.35, dict(w=3.66, yb=1.6, yt=2.26, ys=2.06))], rb=0.25,
         tum=0.1, drop=0.06, wcf=0.8, d2=0.0, crown=0.0).build("bumper", "primary")
    box("post", (3.5, 2.7, 12.0), (0.34, 0.86, 0.42), "primary", mirror=True)
    for i, x in enumerate((1.12, 2.46)):
        Loft([(11.85, {}), (12.08, {})], cx=x, w=0.52, yb=2.48, yt=2.94, nt=6, nb=6, yw=0.5).build(
            f"lamp{i}", "lights_red", mirror=True)


def c_boost():
    """Four small square tips in a row in a black valance."""
    K.begin("C", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.1, dict(w=2.6, yb=-0.2))], yb=-0.45, yt=1.3, rb=0.4, ys=0.95, tum=0.22,
         drop=0.05, wcf=0.7, d2=0.0, crown=0.0).build("housing", "secondary", regions=[
             R(10.8, 12.1, 4.0, 6.0, "primary", 0.0)])
    for i, x in enumerate((0.5, 1.5)):
        barrel(f"tip{i}", 11.5, 12.9, x, 0.42, 0.4, depth=0.45, collar=False, ry=0.4, n=7)


def c_wing():
    """Thin blade on two short uprights."""
    K.begin("C", "WING")
    Loft([(-3.7, dict(cx=11.95, w=0.5)), (0.0, dict(cx=11.75, w=0.62)), (3.7, dict(cx=11.95, w=0.5))], axis="x",
         yb=4.08, yt=4.21, nt=2.2, nb=2.2, yw=0.6).build("blade", "primary")
    box("upright", (2.2, 3.76, 11.5), (0.14, 0.72, 0.5), "secondary", mirror=True)   # foot on the deck skin


def car_c():
    c_cockpit()
    c_nose()
    c_tail()
    c_fpod()
    c_rpod()
    c_stab()
    c_boost()
    c_wing()


def build(out=None):
    return build_car("slingshot", "C", car_c, out=out)
