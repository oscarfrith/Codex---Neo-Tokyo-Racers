"""Car A: Outrider (muscle_01, tier E), after the Chevrolet El Camino SS (1970). STD, GT and EVO kits.

Design language of A: a coupe utility. Short two-seat cab with a near vertical rear window, a long open
load bed with a flat tailgate, a long flat bonnet with twin black stripes over a cowl-induction bulge, a
wide blunt nose with a thin full-width grille split by one body-colour bar, slim quad rectangular lamps
in dark recessed panels, one slim full-width tail light strip, plain round nozzles everywhere.
Pods and sill (round 3): "slab pontoons". Classic, simple and chrome, the plainest pods of the six: long
low slab-sided fenders of soft-square section with one flank crease and a black lower band at the body's
rocker height, each ended by a slim chrome bumper blade over a dark recessed panel; one straight chrome
side pipe along each sill.
Kits: "street machine". What a 1970s owner would bolt on, all chrome and black. GT: raised cowl-induction
scoop, chin spoiler, chrome crease strips and trumpet nozzles, stacked side pipes, chrome bumper blades,
a ducktail. EVO: a chrome tunnel ram with four velocity stacks through the bonnet, polished heat shields,
lake pipes with three outlets, twin trumpets per rear pod, four overdrive tips, a roll hoop over the bed
and a drag wing on two chrome struts.
"""
import math

import exokit as K
from exokit import Hull, Loft, R
from exokit import box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, Z_F, Z_R
from muscle_cars import LINE, LVL, TRIMS, barrel, bazooka, build_car, lift_glow, pick, tub, tube, xtube

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


def a_bell(name, z0, z1, x, y, r, bell, depth=0.45):
    """Chrome trumpet: a round pipe that flares to a bell at its mouth, with a glowing throat."""
    rows = [(z0, r), (z1 - 0.42, r), (z1 - 0.16, r + (bell - r) * 0.4), (z1, bell)]
    t = Loft([(z, dict(w=k, yb=y - k, yt=y + k)) for z, k in rows], cx=x, nt=2, nb=2, yw=0.5)
    t.build(name, "metal", mirror=x != 0, caps=(True, False), step=0.14)
    t.throat(name + "n", "max", lip="metal", back="thrust", scale=r * 0.86 / bell, depth=depth, mirror=x != 0)


def a_stack(name, x, z, y0, y1, r, bell):
    """Velocity stack: a chrome trumpet standing upright, open and dark at the top."""
    rows = [(y0, r), (y1 - 0.5, r), (y1 - 0.18, r + (bell - r) * 0.4), (y1, bell)]
    t = Loft([(y, dict(w=k, yb=z - k, yt=z + k)) for y, k in rows], axis="y", cx=x, nt=2, nb=2, yw=0.5)
    t.build(name, "metal", mirror=True, caps=(True, False), step=0.14)
    t.throat(name + "n", "max", lip="metal", wall="detail", back="detail", scale=r * 0.84 / bell, depth=0.5,
             mirror=True)


def a_nose(trim):
    """Wide, flat, blunt nose: thin full-width grille between a brow and a bumper, split by one body
    colour bar. Long flat bonnet with twin stripes. STD: a low cowl-induction bulge. GT: a raised cowl
    scoop with a chrome-framed open mouth facing the screen, a chin spoiler and a chrome bumper strip.
    EVO: a chrome tunnel ram with four velocity stacks standing through the bonnet, and a deeper chin."""
    K.begin("A", "NOSE", trim)
    lv = LVL[trim]
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
    if lv < 2:
        # cowl-induction bulge: rises from the bonnet toward the screen, open at the back. GT stands it
        # up into a proper scoop with a chrome-framed mouth.
        top = pick(trim, (3.3, 3.52), (3.5, 4.0))
        bulge = Hull([(-10.2, dict(w=1.7, yt=2.98, ys=2.8)), (-8.6, dict(yt=top[0], ys=2.95)),
                      (-6.2, dict(w=1.82, yt=top[1], ys=pick(trim, 3.08, 3.3)))], w=1.8, yb=2.75, rb=0.02,
                     tum=0.25, drop=0.06, wcf=0.75, d2=0.02, crown=0.04)
        bulge.build("bulge", "primary", caps=(False, False), regions=[
            R(-10.2, -6.2, 4.0, 5.6, "secondary", 0.0)])
        bulge.throat("cowl", "max", lip=pick(trim, "primary", "metal"), wall="detail", back="detail",
                     scale=pick(trim, 0.82, 0.86), depth=pick(trim, 0.35, 0.6))
    else:
        # tunnel ram: a black gasket on the bonnet, a polished plenum and four velocity stacks
        Loft([(3.0, {}), (3.27, {})], axis="y", w=1.3, yb=-9.95, yt=-6.85, nt=6, nb=6, yw=0.5).build(
            "gasket", "detail")
        Loft([(3.1, dict(w=0.94, yb=-9.56, yt=-7.24)), (3.95, dict(w=1.02, yb=-9.66, yt=-7.14)),
              (4.06, dict(w=1.02, yb=-9.66, yt=-7.14))], axis="y", nt=5, nb=5, yw=0.5).build("ram", "metal")
        box("ramband", (0, 3.5, -8.4), (2.0, 0.16, 2.48), "detail")
        for i, z in enumerate((-8.97, -7.83)):
            a_stack(f"stack{i}", 0.49, z, 4.0, 4.92, 0.3, 0.47)
    if lv:
        box("bumperstrip", (0, 1.42, -13.23), (7.1, 0.14, 0.08), "metal")
        zc, yc = pick(trim, -13.28, -13.62), pick(trim, -0.22, -0.55)
        Loft([(zc, dict(w=3.6, yb=yc, yt=yc + 0.16)), (-12.55, dict(w=3.74, yb=-0.02, yt=0.3))], nt=6, nb=6,
             yw=0.5).build("chin", "secondary")
        if lv == 2:
            Loft([(zc - 0.07, {}), (zc + 0.03, {})], w=3.6, yb=yc - 0.02, yt=yc + 0.18, nt=6, nb=6, yw=0.5).build(
                "chinedge", "metal")


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


def a_skin(pod, z0, z1, sec, c0, c1, trim="STD", shield=None):
    """Two-tone skin with one crisp crease along the outboard flank, from c0 to c1. GT and EVO lay a chrome
    trim strip in the crease; EVO adds a polished heat shield panel on the flank below it (shield: z0, z1, slots)."""
    a = math.degrees(math.asin(((CREASE_Y - BAND_Y) / (sec[3] - BAND_Y)) ** (PON_N[0] / 2)))
    regs = [R(z0, z1, 180.0, 360.0, "secondary", 0.0),
            pick(trim, R(c0, c1, a - 3.2, a + 3.2, "primary", 0.03), R(c0, c1, a - 3.2, a + 3.2, "metal", -0.035))]
    if shield and LVL[trim] == 2:
        s0, s1, n = shield
        regs.append(R(s0, s1, 2.0, a - 8.0, "metal", -0.03))
        regs += [R(s0 + 0.32 + i * 0.4, s0 + 0.46 + i * 0.4, 5.5, a - 11.5, "detail", -0.03) for i in range(n)]
    return regs


def a_grille(x, ys, z, w):
    """Chrome intake grille: slim horizontal bars across a dark recessed panel."""
    for i, y in enumerate(ys):
        box(f"grille{i}", (x, y, z), (w, 0.09, 0.14), "metal", mirror=True)


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


def a_fpod(trim):
    """Front pontoon: a low slab fender. Squared front face with a dark recessed panel holding two slim
    rectangular lamps, and a chrome bumper blade wrapping the face below them. GT: chrome crease strip and
    a chrome trumpet in the rear face. EVO: a polished heat shield on the flank with a second, side-exit
    nozzle through it, and a chrome intake grille under the bumper blade."""
    K.begin("A", "FPOD", trim)
    lv = LVL[trim]
    zf = -12.72
    pod = a_pontoon([(zf, 0.95), (zf + 0.12, 0.985), (zf + 0.34, 1.0), (POD_FZ, 1.0)], PON_F)
    pod.build("skin", "primary", mirror=True, caps=(False, False), step=0.3,
              regions=a_skin(pod, zf, POD_FZ, PON_F, -11.4, -6.5, trim, shield=(-9.0, -6.45, 3)))
    a_face(pod, "face", "min", 0.86, 0.24)
    if lv:
        a_face(pod, "noz", "max", 0.84, 0.4)
        a_bell("bell", -6.75, POD_FZ - 0.02, PON_F[0], 0.3, 0.52, 0.78, depth=0.35)
    else:
        a_face(pod, "noz", "max", 0.52, 0.6, back="thrust")
    pod.patch("lift", -10.4, -7.4, 258.0, 282.0, "thrust", off=0.05, mirror=True)
    for i, x in enumerate((PON_F[0] - 0.45, PON_F[0] + 0.45)):
        Loft([(zf + 0.05, {}), (zf + 0.26, {})], cx=x, w=0.33, yb=0.88, yt=1.2, nt=6, nb=6, yw=0.5).build(
            f"lamp{i}", "lights", mirror=True)
    a_blade(PON_F, zf - 0.2, -11.3)
    a_mount(-11.0, -6.6, POD_FZ - 0.14)
    if lv == 2:
        bazooka("side", 5.9, 6.78, -7.15, 0.6, 0.3, back=0.7, down=0.12, wide=1.3, flat=1.0, n=2)
        a_grille(PON_F[0], (-0.18, -0.46, -0.74), zf + 0.2, 1.56)


def a_rpod(trim):
    """Rear pontoon: the same slab fender, a little bigger. Squared tail face with a dark recessed panel
    holding one plain round nozzle with a slim metal ring, above the chrome bumper blade. GT: chrome crease
    strip and one long chrome trumpet. EVO: twin trumpets side by side (the quad lamps of the nose, again
    at the tail), a polished heat shield on the flank and a chrome grille in the intake."""
    K.begin("A", "RPOD", trim)
    lv = LVL[trim]
    zr = 11.9
    pod = a_pontoon([(POD_RZ, 1.0), (zr - 0.34, 1.0), (zr - 0.12, 0.985), (zr, 0.95)], PON_R)
    pod.build("skin", "primary", mirror=True, caps=(False, False), step=0.3,
              regions=a_skin(pod, POD_RZ, zr, PON_R, 4.5, 10.6, trim, shield=(7.6, 10.3, 5)))
    a_face(pod, "intake", "min", 0.74, 0.5)
    a_face(pod, "face", "max", 0.86, 0.24)
    pod.patch("lift", 5.8, 9.4, 258.0, 282.0, "thrust", off=0.05, mirror=True)
    if lv == 0:
        barrel("barrel", zr - 0.3, zr + 0.14, PON_R[0], 1.14, 0.58, depth=0.28, collar=False)
    elif lv == 1:
        a_bell("barrel", zr - 0.3, zr + 0.6, PON_R[0], 1.14, 0.55, 0.74)
    else:
        for i, dx in enumerate((-0.5, 0.5)):
            a_bell(f"barrel{i}", zr - 0.3, zr + 0.8, PON_R[0] + dx, 1.14, 0.4, 0.5)
        a_grille(PON_R[0], (-0.5, -0.02, 0.46, 0.94, 1.3), POD_RZ + 0.3, 1.72)
    a_blade(PON_R, 10.5, zr + 0.2)
    a_mount(4.6, 10.4, POD_RZ + 0.14)


def a_stab(trim):
    """One clean straight chrome side pipe on a slim black rail whose top is level with the body's rocker
    line; two pipe ends near the rear leave it swept back and down: the drift thrusters. GT: two pipes
    stacked, one outlet each. EVO: three lake pipes behind a polished, slotted heat shield, three outlets
    stepped down the side."""
    K.begin("A", "STAB", trim)
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    rail = Hull([(z0, {}), (z1, {})], cx=4.6, w=0.5, yb=-1.15, yt=BAND_Y, ys=-0.2, rb=0.15, tum=0.06, drop=0.04,
                wcf=0.6, d2=0.0, crown=0.02)
    rail.build("rail", "secondary", mirror=True, regions=[R(z0, z1, 4.0, 6.0, "primary", 0.0)])
    if trim == "STD":
        tube(z0, z1, 5.48, -0.5, 0.33).build("pipe", "metal", mirror=True)
        for i, z in enumerate((1.1, 2.4)):
            bazooka(f"tip{i}", 5.4, 6.35, z, -0.5, 0.31, back=0.8, down=0.28, wide=1.35, flat=1.0, n=2)
    elif trim == "GT":
        for i, (y, z) in enumerate(((-0.18, 2.5), (-0.84, 1.25))):
            tube(z0, z1, 5.48, y, 0.31).build(f"pipe{i}", "metal", mirror=True)
            bazooka(f"tip{i}", 5.4, 6.4, z, y, 0.3, back=0.8, down=0.1, wide=1.35, flat=1.0, n=2)
    else:
        for i, (y, z) in enumerate(((0.0, 0.3), (-0.48, 1.55), (-0.96, 2.8))):
            tube(z0, z1, 5.42, y, 0.235).build(f"pipe{i}", "metal", mirror=True)
            bazooka(f"tip{i}", 5.4, 6.42, z, y, 0.3, back=0.8, down=0.06, wide=1.35, flat=1.0, n=2)
        Loft([(5.72, {}), (5.8, {})], axis="x", cx=-3.6, w=1.95, yb=-1.2, yt=0.24, nt=6, nb=6, yw=0.5).build(
            "shield", "metal", mirror=True)
        for i in range(6):
            box(f"slot{i}", (5.8, -0.48, -5.0 + i * 0.56), (0.03, 0.86, 0.14), "detail", mirror=True)
    lift_glow(rail, [(-5.0, -3.6), (-2.4, -1.0)])


def a_tail(trim):
    """Long open load bed: walls at body height, a lower black bed, a flat tailgate with one slim
    full-width light strip over a black bumper. GT: a chrome bumper blade and a second light strip.
    EVO: a chrome roll hoop with a light bar over the bed, and a finned under-tray each side of the
    overdrive."""
    K.begin("A", "TAIL", trim)
    lv = LVL[trim]
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
    if lv:
        box("strip2", (0, 2.3, 12.12), (6.9, 0.13, 0.1), "lights_red")
        Loft([(1.62, dict(w=3.8)), (1.69, {}), (1.87, {}), (1.94, dict(w=3.8))], axis="y", w=3.86, yb=12.3,
             yt=12.68, nt=6, nb=6, yw=0.5).build("chrome", "metal", step=0.2)
    if lv == 2:
        # roll hoop on the bed walls, braced back to the rails, with a slim light bar on its rear face
        hx, hz, hy, r = 3.44, 7.6, 4.5, 0.13
        Loft([(2.85, {}), (hy + r, {})], axis="y", cx=hx, w=r, yb=hz - r, yt=hz + r, nt=2, nb=2, yw=0.5).build(
            "hoopleg", "metal", mirror=True)
        xtube(-hx - r, hx + r, hz, hy, r).build("hoopbar", "metal")
        Loft([(hz, dict(yb=hy - 0.3, yt=hy - 0.06)), (8.95, dict(yb=2.85, yt=3.09))], cx=hx, w=0.11, nt=2, nb=2,
             yw=0.5).build("hoopstay", "metal", mirror=True)
        box("lightbar", (0, hy, hz + r + 0.01), (5.4, 0.11, 0.06), "lights_red")
        # finned under-tray: two chrome strakes each side of the overdrive, under the rear overhang,
        # tied by a black tray
        for i, x in enumerate((3.08, 3.62)):
            Loft([(10.5, {}), (12.5, {})], cx=x, w=0.05, yb=-0.5, yt=1.5, nt=6, nb=6, yw=0.5).build(
                f"fin{i}", "metal", mirror=True)
        box("tray", (3.35, -0.47, 11.5), (0.8, 0.1, 2.0), "secondary", mirror=True)


def a_boost(trim):
    """Two small round tips in a black valance under the bumper. GT: two larger tips with chrome trumpets.
    EVO: four chrome trumpets in a row."""
    K.begin("A", "BOOST", trim)
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.55, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "secondary", regions=[
             R(10.8, 12.2, 3.0, 3.6, "primary", 0.0)])
    if trim == "STD":
        barrel("tip", 11.7, 12.9, 0.72, 0.42, 0.46, depth=0.45, collar=False)
    elif trim == "GT":
        a_bell("tip", 11.7, 13.15, 0.88, 0.42, 0.56, 0.76)
    else:
        for i, x in enumerate((0.6, 1.8)):
            a_bell(f"tip{i}", 11.7, 13.3, x, 0.42, 0.46, 0.59)


def a_wing(trim):
    """Small lip on the top edge of the tailgate, carrying the twin stripes. GT: a classic ducktail on
    the tailgate. EVO: the ducktail, and over it a period drag wing on two chrome struts standing on the
    bed walls."""
    K.begin("A", "WING", trim)
    if trim == "STD":
        Hull([(11.62, dict(yt=3.24, ys=2.98, drop=0.2)), (12.36, dict(w=3.54, yt=3.46, ys=3.18, drop=0.12))],
             w=3.6, yb=2.9, rb=0.02, tum=0.1, wcf=0.72, d2=0.05, crown=0.04).build("lip", "primary", regions=[
                 R(11.62, 12.36, STRIPE[0], STRIPE[1], "secondary", 0.0)])
        return
    Hull([(11.6, dict(yt=3.24, ys=2.98, drop=0.2)), (12.15, dict(yt=3.56, ys=3.2, drop=0.14)),
          (12.7, dict(w=3.5, yb=3.5, yt=4.05, ys=3.8, drop=0.08))], w=3.6, yb=2.9, rb=0.02, tum=0.1, wcf=0.72,
         d2=0.04, crown=0.04).build("duck", "primary", regions=[
             R(11.6, 12.7, STRIPE[0], STRIPE[1], "secondary", 0.0)])
    if trim == "EVO":
        Loft([(2.85, dict(yb=10.9, yt=11.5)), (5.0, dict(yb=11.3, yt=11.75))], axis="y", cx=3.44, w=0.07, nt=3,
             nb=3, yw=0.5).build("strut", "metal", mirror=True)
        Loft([(-3.8, {}), (3.8, {})], axis="x", cx=11.75, w=0.9, yb=4.96, yt=5.18, nt=2, nb=2.6, yw=0.4).build(
            "blade", "primary", regions=[R(0.33, 1.56, 8.0, 172.0, "secondary", 0.0),
                                         R(-1.56, -0.33, 8.0, 172.0, "secondary", 0.0)])
        box("plate", (3.83, 5.02, 11.75), (0.08, 0.7, 2.0), "secondary", mirror=True)


def car_a():
    a_cockpit()
    for trim in TRIMS:
        a_nose(trim)
        a_tail(trim)
        a_fpod(trim)
        a_rpod(trim)
        a_stab(trim)
        a_boost(trim)
        a_wing(trim)


def build(out=None):
    return build_car("outrider", "A", car_a, out=out)
