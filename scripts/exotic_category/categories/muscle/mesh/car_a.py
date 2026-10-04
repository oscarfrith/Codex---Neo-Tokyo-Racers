"""Car A: Outrider (muscle_01, tier E), after the Chevrolet El Camino SS (1970). STD trim.

Design language of A: a coupe utility. Short two-seat cab with a near vertical rear window, a long open
load bed with a flat tailgate, a long flat bonnet with twin black stripes over a cowl-induction bulge, a
wide blunt nose with a thin full-width grille split by one body-colour bar, slim quad rectangular lamps
in dark recessed panels, one slim full-width tail light strip, plain round nozzles everywhere.
Pods and sill (round 3): "slab pontoons". Classic, simple and chrome, the plainest pods of the six: long
low slab-sided fenders of soft-square section with one flank crease and a black lower band at the body's
rocker height, each ended by a slim chrome bumper blade over a dark recessed panel; one straight chrome
side pipe along each sill.
"""
import math

import exokit as K
from exokit import Hull, Loft, R
from exokit import box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, Z_F, Z_R
from muscle_cars import LINE, barrel, bazooka, build_car, lift_glow, tub, tube

# Twin stripes: ring range on a body-width top panel (about x 0.33 to 1.56 each side of the centre line).
STRIPE = (5.2, 5.82)


def a_cockpit():
    """Short two-seat cab: raked windscreen, a short roof in one arc, then a near vertical rear window
    just behind the seats. One door glass per side, so there is no centre pillar; the sail panel behind
    the glass is body colour."""
    K.begin("A", "COCKPIT")
    tub()
    gh = Hull([(-6.0, dict(w=3.52, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.6, dict(w=3.62, yt=4.45, tum=0.5, drop=0.16)),
               (-3.3, dict(w=3.64, yt=5.34, tum=0.7)),
               (-1.6, dict(w=3.64, yt=5.58, tum=0.73)),
               (0.3, dict(w=3.63, yt=5.55, tum=0.75)),
               (1.6, dict(w=3.6, yt=5.34, tum=0.78)),
               (2.45, dict(w=3.5, yb=2.95, yt=3.24, ys=3.0, tum=0.68, drop=0.2, crown=0.02))],
              w=3.64, yb=3.1, ys=3.3, rb=0.04, tum=0.72, drop=0.21, wcf=0.75, d2=0.045, crown=0.065)
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.5, 4.13, 6.0, "detail", 0.015),     # windscreen surround
        R(-5.75, -3.61, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.85, 1.3, 3.04, 3.88, "detail", 0.015),     # door glass surround
        R(-4.74, 1.19, 3.085, 3.835, "glass", 0.04),    # door glass
        R(1.68, 2.37, 4.13, 6.0, "detail", 0.0),        # rear window surround
        R(1.72, 2.34, 4.185, 6.0, "glass", 0.04)])      # rear window
    # Sail panels: a body-colour buttress each side, from the rear edge of the roof down and back onto the
    # bed rail, with the rear window between them. Lofted across the car, so the section is the side view;
    # the stations get taller toward the centre line to follow the lean of the cab side.
    cz = 1.75
    rows = [(2.66, 5.1, 3.8), (2.84, 5.13, 3.9), (3.0, 4.9, 4.6), (3.22, 4.56, 6.3), (3.45, 4.0, 6.5),
            (3.6, 3.4, 6.5)]
    Hull([(x, dict(yt=yt, w=ze - cz, tum=ze - cz - 0.15)) for x, yt, ze in rows], axis="x", cx=cz, wi=0.35,
         tumi=0.04, dropi=0.03, yb=2.95, ys=3.06, rb=0.02, drop=0.03, wcf=0.6, d2=0.0, crown=-0.04).build(
             "sail", "primary", mirror=True, step=0.12)


def a_nose():
    """Wide, flat, blunt nose: thin full-width grille between a brow and a bumper, split by one body
    colour bar. Long flat bonnet with twin stripes and a cowl-induction bulge near the screen."""
    K.begin("A", "NOSE")
    nose = Hull([(-12.5, dict(w=3.78, yb=0.0, yt=2.9, ys=2.25, rb=0.3)),
                 (-11.4, dict(w=3.86, yb=-0.25, yt=2.98, ys=2.3, rb=0.4)),
                 (-9.0, dict(w=3.9, yt=3.1, ys=2.38)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.5, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.9, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-12.5, Z_F - GAP, STRIPE[0], STRIPE[1], "secondary", 0.0)])
    nose.cap("grilleback", "min", "detail")
    kw = dict(tum=0.25, wcf=0.72)
    Hull([(-13.0, dict(w=3.72, yb=2.5, yt=2.86, ys=2.62)), (-12.5, dict(w=3.78, yb=2.45, yt=2.9, ys=2.6))], rb=0.04,
         drop=0.2, d2=0.06, crown=0.05, **kw).build("brow", "primary", regions=[
             R(-13.0, -12.5, STRIPE[0], STRIPE[1], "secondary", 0.0)])
    Hull([(-13.2, dict(w=3.7, yb=1.1, yt=1.68, ys=1.5)), (-12.5, dict(w=3.78, yb=1.0, yt=1.72, ys=1.52))], rb=0.2,
         drop=0.08, d2=0.0, crown=0.02, **kw).build("bumper", "primary")
    Hull([(-12.95, dict(w=3.6, yb=0.2, yt=1.1, ys=0.9)), (-12.5, dict(w=3.74, yb=0.0, yt=1.1, ys=0.9))], rb=0.3,
         drop=0.05, d2=0.0, crown=0.02, **kw).build("valance", "secondary")
    box("bar", (0, 2.09, -12.8), (6.9, 0.13, 0.2), "primary")
    box("post", (3.52, 2.1, -12.72), (0.36, 0.9, 0.5), "primary", mirror=True)
    # cowl-induction bulge: rises from the bonnet toward the screen, open at the back
    bulge = Hull([(-10.2, dict(w=1.7, yt=2.98, ys=2.8)), (-8.6, dict(yt=3.3, ys=2.95)),
                  (-6.2, dict(w=1.82, yt=3.52, ys=3.08))], w=1.8, yb=2.75, rb=0.02, tum=0.25, drop=0.06, wcf=0.75,
                 d2=0.02, crown=0.04)
    bulge.build("bulge", "primary", caps=(False, False), regions=[
        R(-10.2, -6.2, 4.0, 5.6, "secondary", 0.0)])
    bulge.throat("cowl", "max", lip="primary", wall="detail", back="detail", scale=0.82, depth=0.35)


# Slab pontoons: each pod is a long, low fender of soft-square section (flat sides, a flat top with a
# slight crown), constant along its length. Its widest line sits at the top of the body's black rocker
# (y 0.1), so the black lower band runs through pod, sill and body. (centre x, half width, bottom, top)
BAND_Y = 0.1
CREASE_Y = 1.36
BLADE = (0.16, 0.48)
PON_F = (5.2, 1.1, -1.3, 1.85)
PON_R = (5.28, 1.18, -1.32, 2.0)
PON_N = (4.0, 5.0)


def a_sec(sec, k=1.0):
    """Section scaled about its band line, so the band stays level."""
    cx, w, yb, yt = sec
    return dict(w=w * k, yb=BAND_Y - (BAND_Y - yb) * k, yt=BAND_Y + (yt - BAND_Y) * k)


def a_pontoon(rows, sec):
    """rows: (z, scale)."""
    cx, w, yb, yt = sec
    return Loft([(z, a_sec(sec, k)) for z, k in rows], cx=cx, nt=PON_N[0], nb=PON_N[1],
                yw=(BAND_Y - yb) / (yt - yb))


def a_skin(pod, z0, z1, sec, c0, c1):
    """Two-tone skin with one crisp crease along the outboard flank, from c0 to c1."""
    a = math.degrees(math.asin(((CREASE_Y - BAND_Y) / (sec[3] - BAND_Y)) ** (PON_N[0] / 2)))
    return [R(z0, z1, 180.0, 360.0, "secondary", 0.0), R(c0, c1, a - 3.2, a + 3.2, "primary", 0.03)]


def a_face(pod, name, end, scale, depth, back="detail", wall="detail"):
    """Recessed end panel: a lip in the two colours of the skin, a short wall and a back face."""
    t = pod.ts[-1] if end == "max" else pod.ts[0]
    d = -depth if end == "max" else depth
    ring = pod._ring(())
    n = len(ring)
    a = [pod._pt(t, r) for r in ring]
    b = [pod._pt(t, r, scale=scale) for r in ring]
    c = [(x, y, z + d) for x, y, z in b]
    faces, fch = [], []
    for j in range(n):
        j2 = (j + 1) % n
        faces.append((j, j2, n + j2, n + j))
        fch.append("secondary" if ring[j] >= 180.0 else "primary")
        faces.append((n + j, n + j2, 2 * n + j2, 2 * n + j))
        fch.append(wall)
    faces.append(tuple(2 * n + j for j in range(n)))
    fch.append(back)
    K._add(name, a + b + c, faces, "primary", True, closed=False, fch=fch)


def a_blade(sec, z0, z1):
    """Slim chrome bumper blade: a thin bar that wraps the end of a pod and runs a little way back along
    both flanks."""
    cx, w = sec[0], sec[1] + 0.07
    y0, y1 = BLADE
    Loft([(y0, dict(w=w - 0.05)), (y0 + 0.07, {}), (y1 - 0.07, {}), (y1, dict(w=w - 0.05))], axis="y", cx=cx, w=w,
         yb=z0, yt=z1, nt=6, nb=6, yw=0.5).build("blade", "metal", mirror=True, step=0.2)


def a_mount(z0, z1, zend):
    """Dark mount between the body side and the pod, and a dark end block that closes the inboard corners
    of the sill face."""
    box("pylon", (4.1, 0.45, (z0 + z1) / 2), (0.4, 1.1, z1 - z0), "detail", mirror=True)
    box("endblock", (4.3, -0.08, zend), (0.4, 2.36, 0.24), "detail", mirror=True)


def a_fpod():
    """Front pontoon: a low slab fender. Squared front face with a dark recessed panel holding two slim
    rectangular lamps, and a chrome bumper blade wrapping the face below them."""
    K.begin("A", "FPOD")
    zf = -12.72
    pod = a_pontoon([(zf, 0.95), (zf + 0.12, 0.985), (zf + 0.34, 1.0), (POD_FZ, 1.0)], PON_F)
    pod.build("skin", "primary", mirror=True, caps=(False, False), step=0.3,
              regions=a_skin(pod, zf, POD_FZ, PON_F, -11.4, -6.5))
    a_face(pod, "face", "min", 0.86, 0.24)
    a_face(pod, "noz", "max", 0.52, 0.6, back="thrust")
    pod.patch("lift", -10.4, -7.4, 258.0, 282.0, "thrust", off=0.05, mirror=True)
    for i, x in enumerate((PON_F[0] - 0.45, PON_F[0] + 0.45)):
        Loft([(zf + 0.05, {}), (zf + 0.26, {})], cx=x, w=0.33, yb=0.88, yt=1.2, nt=6, nb=6, yw=0.5).build(
            f"lamp{i}", "lights", mirror=True)
    a_blade(PON_F, zf - 0.2, -11.3)
    a_mount(-11.0, -6.6, POD_FZ - 0.14)


def a_rpod():
    """Rear pontoon: the same slab fender, a little bigger. Squared tail face with a dark recessed panel
    holding one plain round nozzle with a slim metal ring, above the chrome bumper blade."""
    K.begin("A", "RPOD")
    zr = 11.9
    pod = a_pontoon([(POD_RZ, 1.0), (zr - 0.34, 1.0), (zr - 0.12, 0.985), (zr, 0.95)], PON_R)
    pod.build("skin", "primary", mirror=True, caps=(False, False), step=0.3,
              regions=a_skin(pod, POD_RZ, zr, PON_R, 4.5, 10.6))
    a_face(pod, "intake", "min", 0.74, 0.5)
    a_face(pod, "face", "max", 0.86, 0.24)
    pod.patch("lift", 5.8, 9.4, 258.0, 282.0, "thrust", off=0.05, mirror=True)
    barrel("barrel", zr - 0.3, zr + 0.14, PON_R[0], 1.14, 0.58, depth=0.28, collar=False)
    a_blade(PON_R, 10.5, zr + 0.2)
    a_mount(4.6, 10.4, POD_RZ + 0.14)


def a_stab():
    """One clean straight chrome side pipe on a slim black rail whose top is level with the body's rocker
    line; two pipe ends near the rear leave it swept back and down: the drift thrusters."""
    K.begin("A", "STAB")
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    rail = Hull([(z0, {}), (z1, {})], cx=4.6, w=0.5, yb=-1.15, yt=BAND_Y, ys=-0.2, rb=0.15, tum=0.06, drop=0.04,
                wcf=0.6, d2=0.0, crown=0.02)
    rail.build("rail", "secondary", mirror=True, regions=[R(z0, z1, 4.0, 6.0, "primary", 0.0)])
    tube(z0, z1, 5.48, -0.5, 0.33).build("pipe", "metal", mirror=True)
    for i, z in enumerate((1.1, 2.4)):
        bazooka(f"tip{i}", 5.4, 6.35, z, -0.5, 0.31, back=0.8, down=0.28, wide=1.35, flat=1.0, n=2)
    lift_glow(rail, [(-5.0, -3.6), (-2.4, -1.0)])


def a_tail():
    """Long open load bed: walls at body height, a lower black bed, a flat tailgate with one slim
    full-width light strip over a black bumper."""
    K.begin("A", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (10.6, dict(yb=-0.3)), (11.3, dict(yb=1.4, rb=0.25)),
                 (12.1, dict(w=3.82, yb=1.5, yt=3.24, rb=0.25))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.1, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 11.7, LINE[0], LINE[1], "primary", 0.025),
        R(4.0, 11.55, 4.3, 6.0, "secondary", 0.95)])       # the bed
    tail.cap("gate", "max", "primary")
    box("strip", (0, 2.82, 12.12), (6.9, 0.13, 0.1), "lights_red")
    box("gatestripe", (0.945, 2.58, 12.11), (1.23, 1.08, 0.04), "secondary", mirror=True)
    Hull([(12.1, dict(w=3.82, yb=1.5, yt=2.02, ys=1.86)), (12.5, dict(w=3.74, yb=1.58, yt=1.98, ys=1.84))], rb=0.2,
         tum=0.1, drop=0.06, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "secondary")


def a_boost():
    """Two small round tips in a black valance under the bumper."""
    K.begin("A", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.55, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "secondary", regions=[
             R(10.8, 12.2, 3.0, 3.6, "primary", 0.0)])
    barrel("tip", 11.7, 12.9, 0.72, 0.42, 0.46, depth=0.45, collar=False)


def a_wing():
    """Small lip on the top edge of the tailgate, carrying the twin stripes."""
    K.begin("A", "WING")
    Hull([(11.62, dict(yt=3.24, ys=2.98, drop=0.2)), (12.36, dict(w=3.54, yt=3.46, ys=3.18, drop=0.12))], w=3.6,
         yb=2.9, rb=0.02, tum=0.1, wcf=0.72, d2=0.05, crown=0.04).build("lip", "primary", regions=[
             R(11.62, 12.36, STRIPE[0], STRIPE[1], "secondary", 0.0)])


def car_a():
    a_cockpit()
    a_nose()
    a_tail()
    a_fpod()
    a_rpod()
    a_stab()
    a_boost()
    a_wing()


def build(out=None):
    return build_car("outrider", "A", car_a, out=out)
