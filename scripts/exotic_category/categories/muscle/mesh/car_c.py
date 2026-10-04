"""Car C: Slingshot (muscle_03), after the Chevrolet Camaro SS (2022, sixth generation). STD, GT and EVO.

Design language of C: the sharp, low, angular one. Wedge nose with a thin upper grille slot over a huge open
lower mouth, a flat black heat extractor sunk in the bonnet, the lowest
roof of the family over a narrow band of side glass and very high shoulders, black roof, a short chopped
Kamm tail with four small red lamps on a dark panel, a thin blade wing on two short uprights, and square
nozzles everywhere: one flat wide slot per rear pod, three small squares per sill, four in the overdrive.

Pods and sill (round 3): blades. Three surfaces and one chine: a taut crowned top, one crisp chine that
runs in a straight line from the swept prow of the front pod, through the slim sill, to the square Kamm end
of the rear pod, and a clean undercut below it. Yellow above the chine, black below. The chine face opens up
at the prow to carry two thin level slit lamps.

Kits (round 4): "track attack". Time-attack aero in thin, flat, angular black plates and knife edges, no
round shapes: splitter, dive planes, fences, skirt blades, strakes, fins and a blade wing on swan necks.
"""
import exokit as K
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, SIDE_F, SIDE_R, Z_F, Z_R
from muscle_cars import LINE, LVL, POD_LINE, TRIMS, bazooka, barrel, build_car, flange, lift_glow, pick, tub


def plate(name, pts, th, ch, mirror=False):
    """Flat plate: a polygon of points pushed through by the vector th. Every kit blade is one of these."""
    n = len(pts)
    verts = [tuple(p) for p in pts] + [(p[0] + th[0], p[1] + th[1], p[2] + th[2]) for p in pts]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return K._add(name, verts, faces, ch, mirror)


def side(name, x, prof, th, ch, mirror=True):
    """Upright plate along the car: profile of (z, y) points at x, th thick."""
    return plate(name, [(x, y, z) for z, y in prof], (th, 0, 0), ch, mirror)


def flat(name, y, plan, th, ch, mirror=False):
    """Level plate: plan of (x, z) points at height y, th thick."""
    return plate(name, [(x, y, z) for x, z in plan], (0, th, 0), ch, mirror)


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


def c_nose(trim):
    """Wedge nose: the bonnet falls to a low sharp edge. A thin grille slot under the brow, then one bumper
    frame round a huge open mouth. Flat heat extractor sunk in the bonnet centre. GT: louvres in the
    extractor, a low cowl slot intake behind them and a flat splitter. EVO: a low wide wedge turbine with a
    twin slot mouth, a long splitter with end plates and a centre strake."""
    K.begin("C", "NOSE", trim)
    lv = LVL[trim]
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
    if not lv:
        return

    def top(z):
        return nose.params(z)["yt"]

    if lv == 1:
        # louvres: body-colour slats over the open extractor, rising to the rear
        for i, z in enumerate((-9.7, -9.15, -8.6, -8.05)):
            f = top(z) - 0.1
            side(f"louvre{i}", -1.04, [(z, f - 0.03), (z + 0.3, f + 0.15), (z + 0.3, f + 0.21), (z, f + 0.03)],
                 2.08, "primary", mirror=False)
        # cowl slot intake: a low wedge that faces forward and fades into the bonnet at the screen
        za, zb = -7.45, -5.4
        cowl = Hull([(za, dict(w=1.3, yb=top(za) - 0.14, yt=top(za) + 0.36, ys=top(za) + 0.2)),
                     (zb, dict(w=1.1, yb=top(zb) - 0.14, yt=top(zb) + 0.07, ys=top(zb) - 0.02))],
                    rb=0.02, tum=0.22, drop=0.03, wcf=0.8, d2=0.0, crown=0.0, cs=0.0)
        cowl.build("cowl", "primary", caps=(False, True))
        cowl.throat("cowlin", "min", lip="primary", wall="detail", back="detail", scale=0.82, depth=0.5)
        flat("splitter", -0.58, [(3.85, -11.0), (3.85, -12.75), (3.1, -13.75), (-3.1, -13.75), (-3.85, -12.75),
                                 (-3.85, -11.0)], 0.1, "secondary")
        return
    # EVO: wedge turbine housing over the extractor, slot mouth with two rotor bays
    zs, hs, ws = (-10.0, -8.6, -5.5), (0.74, 0.7, 0.14), (1.78, 1.7, 1.3)
    tur = Hull([(z, dict(w=w, yb=top(z) - 0.14, yt=top(z) + h, ys=top(z) + h * 0.55)) for z, h, w in zip(zs, hs, ws)],
               rb=0.02, tum=0.3, drop=0.04, wcf=0.82, d2=0.0, crown=0.0, cs=0.0)
    tur.build("turbine", "secondary", caps=(False, True), regions=[
        R(-9.7, -6.2, 5.0, 6.0, "primary", 0.0)])
    tur.throat("turin", "min", lip="secondary", wall="detail", back="detail", scale=0.86, depth=0.75)
    ym = top(-10.0) + 0.3
    box("turmid", (0, ym, -9.75), (0.2, 0.84, 0.6), "secondary")
    for i, x in enumerate((0.34, 0.58, 0.82, 1.06)):
        box(f"vane{i}", (x, ym + 0.02, -9.55), (0.06, 0.6, 0.34), "metal", mirror=True)
    # centre strake down the bonnet to the brow
    side("strake", -0.04, [(-12.4, top(-12.4) - 0.1), (-10.2, top(-10.2) - 0.05), (-10.2, top(-10.2) + 0.15),
                           (-11.9, top(-11.9) + 0.13)], 0.08, "secondary", mirror=False)
    flat("splitter", -0.58, [(3.9, -10.7), (3.9, -13.0), (3.2, -13.95), (-3.2, -13.95), (-3.9, -13.0),
                             (-3.9, -10.7)], 0.1, "secondary")
    flat("splitlip", -0.48, [(3.6, -12.2), (3.6, -13.0), (3.0, -13.75), (-3.0, -13.75), (-3.6, -13.0),
                             (-3.6, -12.2)], 0.08, "primary")
    side("endplate", 3.8, [(-13.4, -0.58), (-11.0, -0.58), (-11.0, 0.55), (-11.9, 0.55)], 0.1, "secondary")


class Blade(Hull):
    """Blade pod section for C: three surfaces and one chine. A taut crowned top falls from the inboard edge
    (level there) to the chine; a clean undercut runs from the chine in to the floor edge; flat floor.
    Absolute x per station: xi inboard wall, xo chine. uc is how far the floor edge sits inboard of the
    chine, yc the chine height, hb the height of the chine face (a hair line along the pod, opened up at
    the prow to carry the lamp), n the fullness of the top (higher is flatter with a firmer shoulder).
    Ring u: 0 to 1 floor, 1 to 2 undercut, 2 to 3 chine face, 3 to 6 top."""
    KEYS = ("xi", "xo", "uc", "yb", "yt", "yc", "hb", "n")
    BASE = dict(xi=4.1, xo=6.0, uc=0.5, yb=-1.0, yt=1.0, yc=0.0, hb=0.04, n=3.0)

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
        cx, xi, xo = p["cx"], p["xi"], p["xo"]
        lo, hi = p["yc"] - p["hb"] / 2, p["yc"] + p["hb"] / 2
        yt = max(p["yt"], hi + 0.01)
        u = min(max(u, 0.0), 6.0)
        if u >= 3.0:
            # one curve across the whole top, so the two halves meet without a ridge
            q = (u - 3.0) / 3.0
            x = (xo if side > 0 else xi) + (cx - (xo if side > 0 else xi)) * q
            s = min(max((xo - x) / (xo - xi), 0.0), 1.0)
            return abs(x - cx), hi + (yt - hi) * (1.0 - (1.0 - s) ** p["n"])
        if side > 0:
            k = ((0.0, p["yb"]), (max(xo - p["uc"] - cx, 0.01), p["yb"]), (xo - cx, lo), (xo - cx, hi))
        else:
            k = ((0.0, p["yb"]), (cx - xi, p["yb"]), (cx - xi, p["yc"]), (cx - xi, yt))
        i = min(int(u), 2)
        s = u - i
        (x0, y0), (x1, y1) = k[i], k[i + 1]
        return x0 + (x1 - x0) * s, y0 + (y1 - y0) * s


def chine(z):
    """One straight chine line from the prow to the Kamm tail, parallel to the body line and rising a
    little toward the back."""
    return 1.0 + 0.012 * z


def bs(z, xo, uc, yb, yt, hb=0.04, n=1.3):
    """Station on the chine. The top edge of the chine face stays on the chine line; a taller face (the
    lamp face at the prow) hangs below it."""
    return (z, dict(xo=xo, uc=uc, yb=yb, yt=yt, yc=chine(z) + 0.02 - hb / 2, hb=hb, n=n))


def c_fpod(trim):
    """Blade: a slim leading edge at the body side sweeps back in plan to the widest point, then draws in
    to the sill. The crowned top rises with the bonnet, the keel falls away from the prow, and the chine
    runs straight through. The chine face opens up at the prow to carry two level slit lamps. GT: one dive
    plane above the chine and a full second slit. EVO: stacked dive planes and a fence on the outer edge."""
    K.begin("C", "FPOD", trim)
    lv = LVL[trim]
    pod = Blade([bs(-13.0, 4.32, 0.05, 0.3, 0.92, hb=0.46),
                 bs(-12.4, 4.85, 0.25, 0.08, 1.03, hb=0.46),
                 bs(-11.8, 5.35, 0.45, -0.14, 1.14, hb=0.46),
                 bs(-11.2, 5.8, 0.62, -0.36, 1.25, hb=0.46),
                 bs(-10.4, 6.18, 0.8, -0.62, 1.39, hb=0.3),
                 bs(-9.6, 6.36, 0.9, -0.85, 1.52, hb=0.14),
                 bs(-8.8, 6.42, 0.92, -1.02, 1.63),
                 bs(-7.8, 6.4, 0.82, -1.15, 1.73),
                 bs(-6.8, 6.3, 0.55, -1.22, 1.8),
                 bs(POD_FZ, 6.2, 0.28, -1.25, 1.84)])
    pod.build("skin", "primary", mirror=True, caps=(True, False), step=0.3, regions=[
        R(-13.0, POD_FZ, 0.0, 2.0, "secondary", 0.0),
        R(-12.92, -11.2, 2.06, 2.94, "detail", 0.015, side=1),   # lamp surround in the chine face
        R(-12.82, -11.3, 2.5, 2.86, "lights", 0.04, side=1),     # slit lamp
        R(-12.82, pick(trim, -12.1, -11.3), 2.14, 2.34, "lights", 0.03, side=1)])   # slit under it
    pod.cap("end", "max", "secondary", mirror=True)
    barrel("noz", -7.0, pick(trim, -5.94, -5.9, -5.86), pick(trim, 4.85, 4.8, 4.86), pick(trim, 1.3, 1.2, 1.18),
           pick(trim, 0.38, 0.46, 0.54), depth=0.4, collar=False, ry=pick(trim, 0.13, 0.15, 0.17), n=7)
    flange(-10.4, -6.4, -0.3, 1.0)
    lift_glow(pod, [(-9.6, -7.2)])

    def canard(name, z0, z1, u, tip, lift0, lift1):
        # root edge sunk in the pod top, tip outboard of the chine and kicked up at the back
        a, b = pod._pt(z0, (1, u)), pod._pt(z1, (1, u))
        plate(name, [(a[0], a[1] - 0.07, z0), (b[0], b[1] - 0.07, z1), (tip, b[1] + lift1, z1 + 0.12),
                     (tip - 0.25, a[1] + lift0, z0 + 0.6)], (0, 0.055, 0), "secondary", mirror=True)

    if lv >= 1:
        canard("dive0", -10.7, -9.0, 3.9, 6.9, 0.03, 0.22)
    if lv >= 2:
        canard("dive1", -10.2, -8.6, 4.7, 6.9, 0.3, 0.5)
        # fence along the outer top edge, from the dive planes to the sill
        za, zb, xa, xb = -8.7, POD_FZ - 0.02, 6.28, 6.08
        zc = -7.0
        xc = xa + (xb - xa) * (zc - za) / (zb - za)
        plate("fence", [(xa, chine(za) - 0.1, za), (xb, chine(zb) - 0.1, zb), (xb, chine(zb) + 0.46, zb),
                        (xc, chine(zc) + 0.46, zc)], (0.08, 0, 0), "secondary", mirror=True)


def c_rpod(trim):
    """The same blade section, low and flat, cut off square as a Kamm tail: a slim black end frame with
    one flat wide slot nozzle set flush in it. GT: a wider slot and a thin fin on the outer edge. EVO: two
    stacked slots, a taller fin and strakes under the cut-off."""
    K.begin("C", "RPOD", trim)
    lv = LVL[trim]
    pod = Blade([bs(POD_RZ, 6.2, 0.28, -1.25, 1.9),
                 bs(4.8, 6.3, 0.55, -1.23, 1.93),
                 bs(5.8, 6.4, 0.82, -1.17, 1.96),
                 bs(7.2, 6.48, 0.9, -1.05, 2.0),
                 bs(9.4, 6.5, 0.86, -0.85, 2.03),
                 bs(11.2, 6.46, 0.76, -0.62, 2.03),
                 bs(12.3, 6.4, 0.68, -0.48, 2.02)])
    pod.build("skin", "primary", mirror=True, caps=(False, False), step=0.3, regions=[
        R(POD_RZ, 12.3, 0.0, 2.0, "secondary", 0.0)])
    pod.throat("intake", "min", lip="secondary", wall="detail", back="detail", scale=0.8, depth=0.4, mirror=True)
    pod.throat("frame", "max", lip="secondary", wall="detail", back="detail", scale=0.87, depth=0.3, mirror=True)
    if lv == 0:
        barrel("slot", 11.5, 12.29, 5.22, 0.72, 0.68, depth=0.2, collar=False, ry=0.3, n=7)
    elif lv == 1:
        barrel("slot", 11.5, 12.4, 5.2, 0.72, 0.88, depth=0.25, collar=False, ry=0.32, n=7)
    else:
        barrel("slot0", 11.5, 12.55, 4.98, 1.14, 0.66, depth=0.25, collar=False, ry=0.25, n=7)
        barrel("slot1", 11.5, 12.55, 5.1, 0.42, 0.8, depth=0.25, collar=False, ry=0.25, n=7)
    flange(4.4, 10.6, -0.3, 1.6)
    lift_glow(pod, [(5.6, 9.2)])
    if lv:
        # knife fin standing on the chine edge, rising to the cut-off
        z0, h = pick(trim, 7.4, 7.4, 5.4), pick(trim, 0.0, 0.85, 1.45)
        side("fin", 6.26, [(z0, chine(z0) - 0.1), (12.3, chine(12.3) - 0.1), (12.62, chine(12.3) + h),
                           (11.7, chine(12.3) + h)], 0.08, "secondary")
    if lv >= 2:
        for i, x in enumerate((4.6, 5.4)):
            side(f"strake{i}", x, [(10.0, -0.72), (12.7, -0.3), (12.7, -1.2), (11.2, -1.2)], 0.07, "secondary")


def c_stab(trim):
    """Slim blade sill that carries the chine between the pods; three small square thrusters set in its
    undercut, swept back and down. GT: a flat skirt blade under the chine and four thrusters. EVO: a
    stepped skirt with a ledge and an end blade ahead of the rear pod, five thrusters."""
    K.begin("C", "STAB", trim)
    lv = LVL[trim]
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    sill = Blade([bs(z0, 5.9, 0.9, -0.85, 1.1), bs(z1, 5.9, 0.9, -0.85, 1.1)])
    sill.build("skin", "primary", mirror=True, regions=[R(z0, z1, 0.0, 2.0, "secondary", 0.0)])
    zs = pick(trim, (-2.9, -1.8, -0.7), (-3.5, -2.4, -1.3, -0.2), (-4.1, -3.0, -1.9, -0.8, 0.3))
    r = pick(trim, 0.3, 0.32, 0.34)
    for i, z in enumerate(zs):
        bazooka(f"jet{i}", 5.15, 6.15 + 0.1 * lv, z, -0.05, r, back=0.6, down=0.42, wide=1.0, flat=1.0, n=7)
    lift_glow(sill, [(-5.0, -3.8), (1.8, 3.0)])
    if not lv:
        return
    # skirt blade: a flat plate hanging from just under the chine, raked at both ends, with a fine
    # body-colour edge along its foot
    foot = -1.22
    side("skirt", 5.82, [(z0 + 0.2, chine(z0) - 0.1), (z1 - 0.2, chine(z1) - 0.1), (z1 - 1.0, foot),
                         (z0 + 1.0, foot)], 0.08, "secondary")
    side("skirtedge", 5.83, [(z0 + 0.93, foot + 0.09), (z1 - 0.93, foot + 0.09), (z1 - 1.0, foot),
                             (z0 + 1.0, foot)], 0.085, "primary")
    if lv >= 2:
        # step: a ledge at the foot of the skirt, and a blade standing on its rear end
        flat("ledge", foot - 0.03, [(5.7, z0 + 0.9), (6.42, z0 + 1.9), (6.42, z1 - 0.25), (5.7, z1 - 0.25)], 0.08,
             "secondary", mirror=True)
        side("endblade", 6.34, [(0.9, foot), (z1 - 0.25, foot), (z1 - 0.25, 0.62), (2.6, 0.62)], 0.08, "secondary")
        side("endedge", 6.345, [(2.6, 0.62), (z1 - 0.25, 0.62), (z1 - 0.25, 0.53), (2.52, 0.53)], 0.085, "primary")


def c_tail(trim):
    """Short deck to a chopped Kamm tail. The tail face is a recessed dark panel with four small red lamps.
    GT: a flat diffuser floor with strakes beside the overdrive. EVO: a longer floor, tall strakes and a
    thin fin on the centre line."""
    K.begin("C", "TAIL", trim)
    lv = LVL[trim]
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
    if not lv:
        return
    # diffuser: a floor under the overdrive and strakes either side of it (the overdrive zone stays clear)
    ze = pick(trim, 0, 13.15, 13.45)
    flat("floor", -1.0, [(3.9, 9.6), (3.9, ze - 0.7), (3.2, ze), (-3.2, ze), (-3.9, ze - 0.7), (-3.9, 9.6)], 0.1,
         "secondary")
    hy = pick(trim, 0, 0.25, 0.95)
    for i, x in enumerate(pick(trim, (), (2.98, 3.72), (2.98, 3.78))):
        e = ze - 0.1 - 0.25 * i
        side(f"strake{i}", x, [(10.2, -0.95), (e, -0.95), (e, hy - 0.5), (e - 0.8, hy), (10.2, hy)], 0.08,
             "secondary")
    if lv >= 2:
        side("floorlip", -3.2, [(ze - 0.02, -1.0), (ze + 0.03, -1.0), (ze + 0.03, -0.9), (ze - 0.02, -0.9)], 6.4,
             "primary", mirror=False)
        # tail fin: a tall blade behind the rear window, stepping down to a low spine along the deck
        side("fin", -0.04, [(6.5, 3.2), (8.5, 4.55), (8.98, 4.55), (9.25, 3.74), (12.2, 3.74), (12.2, 3.3)], 0.08,
             "secondary", mirror=False)


def c_boost(trim):
    """Four small square tips in a row in a black valance. GT: six. EVO: two rows of six in a finned
    black frame."""
    K.begin("C", "BOOST", trim)
    lv = LVL[trim]
    Hull([(10.8, dict(w=2.85)), (12.1, dict(w=pick(trim, 2.6, 2.7, 2.8), yb=pick(trim, -0.2, -0.2, -0.45)))],
         yb=pick(trim, -0.45, -0.45, -0.6), yt=1.3, rb=0.4, ys=0.95, tum=0.22,
         drop=0.05, wcf=0.7, d2=0.0, crown=0.0).build("housing", "secondary", regions=[
             R(10.8, 12.1, 4.0, 6.0, "primary", 0.0)])
    if lv == 0:
        for i, x in enumerate((0.5, 1.5)):
            barrel(f"tip{i}", 11.5, 12.9, x, 0.42, 0.4, depth=0.45, collar=False, ry=0.4, n=7)
    elif lv == 1:
        for i, x in enumerate((0.42, 1.26, 2.1)):
            barrel(f"tip{i}", 11.5, 13.0, x, 0.44, 0.35, depth=0.45, collar=False, ry=0.38, n=7)
    else:
        for j, y in enumerate((0.84, 0.12)):
            for i, x in enumerate((0.42, 1.26, 2.1)):
                barrel(f"tip{j}{i}", 11.5, 13.0, x, y, 0.33, depth=0.45, collar=False, ry=0.27, n=7)
        # finned frame: a blade between every pair of tips, tied by a top, a middle and a bottom plate
        for i, x in enumerate((0.0, 0.84, 1.68, 2.52)):
            side(f"fin{i}", x - 0.035, [(11.9, -0.3), (13.25, -0.24), (13.05, 1.3), (11.9, 1.3)], 0.07, "secondary",
                 mirror=x != 0)
        for i, y in enumerate((1.24, 0.45, -0.3)):
            e = 13.08 + 0.07 * i
            flat(f"bar{i}", y, [(2.56, 11.9), (2.56, e), (-2.56, e), (-2.56, 11.9)], 0.06, "secondary")


def c_wing(trim):
    """Thin blade on two short uprights. GT: taller and wider on swan necks. EVO: two elements wider than
    the body between large angular end plates."""
    K.begin("C", "WING", trim)
    lv = LVL[trim]
    if lv == 0:
        Loft([(-3.7, dict(cx=11.95, w=0.5)), (0.0, dict(cx=11.75, w=0.62)), (3.7, dict(cx=11.95, w=0.5))],
             axis="x", yb=4.08, yt=4.21, nt=2.2, nb=2.2, yw=0.6).build("blade", "primary")
        box("upright", (2.2, 3.76, 11.5), (0.14, 0.72, 0.5), "secondary", mirror=True)   # foot on the deck skin
        return
    span, yb = pick(trim, 0, 4.9, 6.25), pick(trim, 0, 4.8, 5.3)
    w0, w1 = pick(trim, 0, 0.72, 0.85), pick(trim, 0, 0.58, 0.8)
    Loft([(-span, dict(cx=12.25, w=w1)), (0.0, dict(cx=12.05, w=w0)), (span, dict(cx=12.25, w=w1))], axis="x",
         yb=yb, yt=yb + 0.14, nt=2.6, nb=2.6, yw=0.6).build("blade", "primary")
    # swan necks: they rise ahead of the blade, hook over it and hold it from above
    t = yb + 0.12
    side("neck", 2.8, [(10.4, 2.9), (10.45, t - 0.5), (10.9, t + 0.24), (12.5, t + 0.24), (12.6, t - 0.04),
                       (11.25, t + 0.04), (10.95, t - 0.45), (11.0, 2.9)], 0.1, "secondary")
    if lv >= 2:
        plate("flap", [(-span, yb + 0.42, 12.75), (span, yb + 0.42, 12.75), (span, yb + 0.88, 13.35),
                       (-span, yb + 0.88, 13.35)], (0, 0.06, -0.03), "secondary")
        side("endplate", span, [(10.9, yb - 0.5), (13.4, yb - 0.85), (13.4, yb + 1.2), (12.3, yb + 1.2),
                                (10.9, yb + 0.35)], 0.1, "secondary")
        side("endedge", span + 0.005, [(12.3, yb + 1.2), (13.4, yb + 1.2), (13.4, yb + 1.1), (12.14, yb + 1.1)],
             0.105, "primary")


def car_c():
    c_cockpit()
    for trim in TRIMS:
        c_nose(trim)
        c_tail(trim)
        c_fpod(trim)
        c_rpod(trim)
        c_stab(trim)
        c_boost(trim)
        c_wing(trim)


def build(out=None):
    return build_car("slingshot", "C", car_c, out=out)
