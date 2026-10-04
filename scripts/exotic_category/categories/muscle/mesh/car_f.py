"""Car F: Brawler (muscle_06), after the Dodge Challenger SRT Demon. The hero car and the reference standard.
STD, GT and EVO kits. Runs inside Blender; build with run_headless.py -- car_f.

Design language: blunt nose that tapers in plan, deep full-width slot grille, halo lamp pairs on the front
pods, a raised bonnet bulge, long bonnet, low arched glasshouse with a fast rear window and a short deck,
recessed tail panel with two ring lamps, ducktail lip.
Pods and sill (round 2): drag-car nacelles. Round-section turbine pods with a stepped turbine exit with a
centre cone, joined by a slim round rail. Round lamps, round shaker, round nacelles.
Standard trim is clean and minimal: shape, lamps, glass, stripe and jets only, with a plain bonnet.
Kits (round 4), motif "quarter-mile monster": GT a single shaker scoop, splitter, intake rings, bigger
turbine exits, a third drift thruster, side diffusers and a tall ducktail with end fins. EVO the twin shaker
turbine, deep splitter, third halo lamp, heat shield bands, flame-holder exits, a polished rail with four
thrusters, three overdrive turbines, a full-width ring lamp, wheelie bars and a tall drag wing.
"""
import math

import exokit as K
import musclekit as M  # noqa: F401
from exokit import Hull, Loft, R, box
from muscle_cars import LINE, LVL, TRIMS, barrel, bazooka, build_car, halo, pick, tub, tube, xtube
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, Z_F, Z_R


def f_cockpit():
    """Wide, long glasshouse nearly the full width of the body: raked windscreen, long roof, a fast rear
    window down to a short deck."""
    K.begin("F", "COCKPIT")
    tub()
    # Half way between the squarer cabin of pass 9 and the arched one of pass 10 (Oscar, 2026-10-04): one
    # continuous arc from cowl to deck with a moderate crown and roof-edge radius, slightly narrower at the back.
    gh = Hull([(-6.0, dict(w=3.52, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.6, dict(w=3.62, yt=4.45, tum=0.5, drop=0.16)),
               (-3.3, dict(w=3.64, yt=5.43, tum=0.7)),
               (-1.6, dict(w=3.64, yt=5.71, tum=0.73)),
               (1.4, dict(w=3.62, yt=5.68, tum=0.75)),
               (2.9, dict(w=3.58, yt=5.42, tum=0.79)),
               (4.6, dict(w=3.46, yt=4.4, tum=0.6, drop=0.17)),
               (6.3, dict(w=3.4, yb=3.15, yt=3.3, ys=3.2, tum=0.2, drop=0.03, crown=0.02))],
              w=3.64, yb=3.1, ys=3.3, rb=0.04, tum=0.72, drop=0.21, wcf=0.75, d2=0.045, crown=0.065)
    # Body-colour pillars of medium width, a black centre pillar, each glass in a thin black surround.
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.5, 4.13, 6.0, "detail", 0.015),     # windscreen surround
        R(-5.75, -3.61, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.85, 4.62, 3.04, 3.88, "detail", 0.015),    # side glass surround, one opening
        R(-4.74, -0.28, 3.085, 3.835, "glass", 0.04),   # door glass
        R(0.04, 4.5, 3.085, 3.835, "glass", 0.04),      # quarter glass
        R(3.21, 6.06, 4.14, 6.0, "detail", 0.015),      # rear window surround
        R(3.31, 5.96, 4.195, 6.0, "glass", 0.04),       # rear window
        R(-3.1, 2.75, 5.22, 6.0, "secondary", 0.02)])   # roof stripe


# ---------------------------------------------------------------- shared by this car

def f_fine(loft, n=10):
    """Small hardware needs fewer points round its section."""
    loft.N = n
    return loft


def f_blade(z_rows, x, half=0.06):
    """Thin upright plate along the car. z_rows: (z, bottom, top)."""
    return Loft([(z, dict(yb=a, yt=b)) for z, a, b in z_rows], cx=x, w=half, nt=6, nb=6, yw=0.5)


def f_band(pod, name, z0, z1, off, ch="metal"):
    """Band wrapped round a nacelle: the pod section between two stations, standing off proud of the skin."""
    rows = []
    for z in (z0, (z0 + z1) / 2, z1):
        p = dict(pod.params(z))
        p.update(w=p["w"] + off, yb=p["yb"] - off, yt=p["yt"] + off)
        rows.append((z, p))
    Loft(rows).build(name, ch, mirror=True)


def f_pod_regions(z0, z1):
    """Nacelle paint: body colour over a black belly. Loft ring angles."""
    return [R(z0, z1, 198, 342, "secondary", 0.02)]


def f_turbine(name, z1, x, y, r, step, tip, rings=1, z0=None, petals=0):
    """Turbine exit firing backwards: a metal ring, a second ring stepped inside it, a recessed glowing
    core and a centre cone. z1 is the end of the outer ring; the inner ring ends step behind it and the
    cone tip sits tip behind it. rings=2 adds a third, smaller ring a further step back. z0 starts the
    outer ring further forward. petals: a flame-holder crown of small petals round the outer ring."""
    mir = x != 0
    o = tube(z1 - 0.9 * r if z0 is None else z0, z1, x, y, r)
    o.build(name, "metal", mirror=mir, caps=(True, False))
    o.throat(name + "s", "max", lip="metal", wall="detail", back="detail", scale=0.9, depth=0.4 * r, mirror=mir)
    i = tube(z1 - 0.5 * r, z1 + step, x, y, 0.8 * r)
    i.build(name + "i", "metal", mirror=mir, caps=(False, False))
    i.throat(name + "n", "max", lip="metal", wall="detail", back="thrust", scale=0.9, depth=0.32 * r, mirror=mir)
    end = z1 + step
    if rings > 1:
        j = tube(end - 0.4 * r, end + step, x, y, 0.6 * r)
        j.build(name + "j", "metal", mirror=mir, caps=(False, False))
        j.throat(name + "m", "max", lip="metal", wall="detail", back="thrust", scale=0.88, depth=0.26 * r,
                 mirror=mir)
        end += step
    zc = end - 0.32 * r
    Loft([(zc, dict(w=0.24 * r, yb=y - 0.24 * r, yt=y + 0.24 * r)), (z1 + tip, dict(w=0.03, yb=y - 0.03, yt=y + 0.03))],
         cx=x, nt=2, nb=2, yw=0.5).build(name + "cone", "metal", mirror=mir)
    for k in range(petals):
        a = 2 * math.pi * (k + 0.5) / petals
        px, py = x + (r - 0.04) * math.cos(a), y + (r - 0.04) * math.sin(a)
        f_fine(Loft([(z1 - 0.6 * r, dict(w=0.09, yb=py - 0.09, yt=py + 0.09)),
                     (z1 + 0.05, dict(w=0.09, yb=py - 0.09, yt=py + 0.09)),
                     (z1 + 0.24, dict(w=0.04, yb=py - 0.04, yt=py + 0.04))], cx=px, nt=2, nb=2, yw=0.5), 8).build(
                         f"{name}p{k}", "metal", mirror=mir)


def f_pylon(z0, z1, y0, y1):
    """Dark pylon between a nacelle and the body side."""
    box("pylon", (4.2, (y0 + y1) / 2, (z0 + z1) / 2), (0.6, y1 - y0, z1 - z0), "detail", mirror=True)


# ---------------------------------------------------------------- modules

def f_nose(trim):
    """Nose that tapers in plan and drops toward the front, deep slot grille over a sculpted bumper, long
    bonnet with a raised bulge. STD: a plain bulge. GT: a single shaker scoop and a chin splitter. EVO: the
    twin shaker turbine, a deep splitter with end plates and twin grille bars."""
    K.begin("F", "NOSE", trim)
    lvl = LVL[trim]
    nose = Hull([(-12.2, dict(w=3.55, yb=0.15, yt=2.4, ys=1.9, rb=0.25, tum=0.25, drop=0.18)),
                 (-11.4, dict(w=3.8, yb=-0.15, yt=2.62, ys=2.05, rb=0.35)),
                 (-9.2, dict(w=3.9, yt=2.9, ys=2.25)),
                 (Z_F, SEAM_F)], **SEAM_F)
    regs = [R(-12.2, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
            R(-11.6, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
            R(-12.0, Z_F - GAP, 5.15, 6.0, "secondary", -0.07)]   # raised bonnet bulge, in the stripe colour
    if lvl:
        regs.append(R(-9.6, -5.9, 5.5, 6.0, "detail", 0.1))       # the well the shaker rises through
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=regs)
    nose.cap("grilleback", "min", "detail")
    # brow and bumper stand well ahead of the grille back, so the slot between them is a deep recess
    Hull([(-13.05, dict(w=3.4, yb=1.95, yt=2.22, ys=2.06)), (-12.2, dict(w=3.55, yb=1.9, yt=2.4, ys=2.12))], rb=0.04,
         tum=0.2, drop=0.1, wcf=0.7, d2=0.02, crown=0.03).build("brow", "primary")
    Hull([(-13.25, dict(w=3.36, yb=0.45, yt=1.3, ys=1.05)), (-12.2, dict(w=3.55, yb=0.15, yt=1.42, ys=1.15))], rb=0.3,
         tum=0.15, drop=0.1, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    box("bar", (0, 1.66, -12.7), (6.9, 0.07, 0.12), "metal")
    box("intake", (0, 0.86, -13.27), (4.4, 0.44, 0.08), "detail")
    Loft([(-13.6, dict(w=3.0)), (-12.9, dict(w=3.6)), (-11.2, dict(w=3.85))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "secondary")
    if trim == "GT":
        # splitter: a blade under the chin, on two metal stays
        Loft([(-13.88, dict(w=3.2, yt=-0.64)), (-13.0, dict(w=3.75, yt=-0.5)), (-11.0, dict(w=3.9, yt=-0.5))],
             yb=-0.72, yt=-0.5, nt=5, nb=5).build("splitter", "secondary")
        f_fine(Loft([(-0.66, {}), (0.7, {})], axis="y", cx=2.3, w=0.05, yb=-13.36, yt=-13.26, nt=2, nb=2,
                    yw=0.5)).build("stay", "metal", mirror=True)
        # single shaker scoop: low and wide, one forward mouth
        s = Loft([(-10.0, dict(w=1.16, yb=2.78, yt=3.9)), (-9.2, dict(w=1.22, yb=2.8, yt=3.96)),
                  (-7.6, dict(w=1.18, yb=2.9, yt=3.86)), (-6.3, dict(w=0.98, yb=2.95, yt=3.42))], nt=3.0, nb=5,
                 yw=0.35)
        s.build("scoop", "primary", caps=(False, True), regions=[R(-9.4, -6.3, 62, 118, "secondary", 0.0)])
        s.throat("scoopin", "min", lip="metal", wall="detail", back="detail", scale=0.9, depth=0.8)
    if trim == "EVO":
        box("bar2", (0, 1.5, -12.95), (6.8, 0.07, 0.12), "metal")
        box("bar3", (0, 1.82, -12.95), (6.8, 0.07, 0.12), "metal")
        # deep splitter: a wedge down from the chin with an end plate each side
        Loft([(-13.95, dict(w=3.25, yt=-0.86)), (-12.9, dict(w=3.8, yt=-0.5)), (-10.8, dict(w=3.9, yt=-0.5))],
             yb=-0.98, yt=-0.5, nt=5, nb=5).build("splitter", "secondary")
        f_blade([(-13.3, -1.0, -0.6), (-12.4, -1.0, -0.1), (-10.9, -1.0, -0.1)], 3.86, 0.05).build(
            "endplate", "primary", mirror=True)
        # twin shaker turbine through the bonnet
        y = 4.12
        box("shakerbase", (0, 3.32, -7.75), (2.9, 0.52, 3.3), "detail")
        t = Loft([(-10.2, dict(w=0.76, yb=y - 0.76, yt=y + 0.76)), (-9.5, {}), (-6.3, {})], cx=0.74, w=0.64,
                 yb=y - 0.64, yt=y + 0.64, nt=2, nb=2, yw=0.5)
        t.build("shaker", "metal", mirror=True, caps=(False, True))
        t.throat("shakerin", "min", lip="metal", wall="detail", back="detail", scale=0.86, depth=0.7, mirror=True)
        tube(-10.0, -9.5, 0.74, y, 0.2).build("shakerhub", "metal", mirror=True)


def f_fpod(trim):
    """Front nacelle: the squared lamp face with a halo pair grows back into a round turbine pod. Its jet
    leaves through a shrouded turbine exit in the rear face. GT: a metal intake ring behind the lamp face
    and a larger exit. EVO: a third halo lamp and a polished heat shield band."""
    K.begin("F", "FPOD", trim)
    lvl = LVL[trim]
    pod = Loft([(-12.7, dict(cx=5.38, w=1.2, yb=-0.75, yt=1.7, nt=5, nb=5)),
                (-12.1, dict(cx=5.39, w=1.25, yb=-0.95, yt=1.8, nt=3.8, nb=3.8)),
                (-11.0, dict(w=1.3, yb=-1.17, yt=1.93, nt=2.5, nb=2.8)),
                (-8.4, dict(w=1.3, yb=-1.22, yt=1.97)),
                (POD_FZ, dict(w=1.24, yb=-1.2, yt=1.82))], cx=5.4, w=1.3, yb=-1.2, yt=1.95, nt=2.2, nb=2.7, yw=0.5)
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=f_pod_regions(-12.7, POD_FZ))
    pod.throat("aft", "max", lip=pick(trim, "primary", "metal"), wall="detail", back="detail",
               scale=pick(trim, 0.9, 0.93), depth=0.65, mirror=True)
    f_turbine("noz", -5.97, 5.45, pick(trim, 0.5, 0.4), pick(trim, 0.68, 0.84, 0.92), 0.06, 0.1)
    for i, x in enumerate((4.9, 5.86)):
        halo(f"halo{i}", x, 0.82, -13.0, 0.42)
    if lvl >= 1:
        f_band(pod, "ring", -11.75, -11.3, 0.06)
    if lvl >= 2:
        halo("halo2", 5.38, -0.08, -13.0, 0.36)
        f_band(pod, "shield", -8.0, -6.6, 0.05)
    f_pylon(-11.2, -6.8, -0.2, 0.9)
    pod.patch("lift", -10.4, -7.4, 258, 282, "thrust", mirror=True)


def f_rpod(trim):
    """Rear turbine nacelle, no taller than the deck: a barrel-shaped round pod with a plain dark intake
    at the front and one large turbine exit behind. GT: a metal intake lip and a larger exit with a second
    stepped ring. EVO: a slightly larger nacelle, a metal band and a flame-holder exit."""
    K.begin("F", "RPOD", trim)
    lvl = LVL[trim]
    w, yb, yt = pick(trim, (1.4, -1.25, 2.25), None, (1.45, -1.3, 2.4))
    pod = Loft([(POD_RZ, dict(cx=5.4, w=1.3, yb=-1.2, yt=2.1)),
                (5.6, dict(w=w, yb=yb, yt=yt)),
                (8.4, dict(w=w, yb=yb, yt=yt)),
                (10.4, dict(w=pick(trim, 1.22, None, 1.27), yb=-0.95, yt=pick(trim, 1.95, None, 2.02), nb=2.2)),
                (11.4, dict(w=1.04, yb=-0.62, yt=1.62, nb=2.0))], cx=5.5, nt=2.2, nb=2.7, yw=0.5)
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=f_pod_regions(POD_RZ, 11.4))
    # A plain lip and a dark tunnel. No centre spinner: a ring round a hub read as a wheel from the front
    # three-quarter view. The kits get a thin metal lip, still on an empty tunnel.
    pod.throat("intake", "min", lip=pick(trim, "primary", "metal"), wall="detail", back="detail",
               scale=pick(trim, 0.82, 0.86), depth=1.3, mirror=True)
    if lvl == 0:
        f_turbine("noz", 12.05, 5.5, 0.5, 1.0, 0.25, 0.38)
    else:
        f_turbine("noz", 12.05, 5.5, 0.5, pick(trim, 1.0, 1.1, 1.14), 0.25, 0.72, rings=2,
                  petals=0)  # the petal crown read as a cog from behind (wheel-like); the stepped rings stay
    if lvl >= 2:
        f_band(pod, "band", 8.9, 9.7, 0.05)
    f_pylon(4.8, 10.4, -0.2, 1.0)
    pod.patch("lift", 5.8, 9.6, 258, 282, "thrust", mirror=True)


def f_stab(trim):
    """Sill unit: a slim round rail between the nacelles with a metal collar at each end and two
    bazookas that fire sideways, swept back and down. GT: three bazookas. EVO: a fatter polished rail
    with body-colour collars and four bazookas."""
    K.begin("F", "STAB", trim)
    z0, z1 = POD_FZ + 0.1, POD_RZ - 0.1
    if trim == "EVO":
        rail = Loft([(z0, {}), (z1, {})], cx=4.84, w=0.74, yb=-1.25, yt=0.23, nt=2, nb=2, yw=0.5)
        rail.build("skin", "metal", mirror=True, regions=[
            R(z0, z0 + 0.45, 0, 360, "primary", 0.0), R(z1 - 0.45, z1, 0, 360, "primary", 0.0),
            R(z0 + 0.45, z1 - 0.45, 215, 325, "secondary", 0.02)])
    else:
        rail = Loft([(z0, {}), (z1, {})], cx=4.7, w=0.6, yb=-1.15, yt=-0.05, nt=2, nb=2, yw=0.5)
        rail.build("skin", "primary", mirror=True, regions=[
            R(z0, z0 + 0.3, 0, 360, "metal", 0.0), R(z1 - 0.3, z1, 0, 360, "metal", 0.0),
            R(z0 + 0.3, z1 - 0.3, 198, 342, "secondary", 0.02)])
    for i, z in enumerate(pick(trim, (-3.0, 0.4), (-3.9, -1.5, 0.9), (-4.5, -2.4, -0.3, 1.8))):
        bazooka(f"bazooka{i}", pick(trim, 4.9, 4.9, 5.0), 6.3, z, pick(trim, -0.55, -0.55, -0.5),
                pick(trim, 0.5, 0.5, 0.48), down=0.5)
    for i, (a, b) in enumerate(((-5.0, -3.6), (1.6, 3.0))):
        rail.patch(f"lift{i}", a, b, 255, 285, "thrust", mirror=True)


def f_tail(trim):
    """Short deck that climbs to a high square tail. As on the real car the tail face is a recessed black
    panel under the deck lip, holding two ring lamps, above a body-colour bumper. GT: bolder ring lamps, a
    centre fin and a black diffuser under each rear corner. EVO: one full-width ring lamp, a deeper
    diffuser and a pair of wheelie bars."""
    K.begin("F", "TAIL", trim)
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.35)), (9.8, dict(yt=3.55, ys=2.7)), (10.6, dict(yb=-0.3, yt=3.57, ys=2.75)),
                 (11.3, dict(yb=1.4, rb=0.25, yt=3.59, ys=2.8)),
                 (12.0, dict(w=3.72, yb=1.5, yt=3.6, ys=2.85, rb=0.25, tum=0.28, drop=0.2))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.0, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 11.6, LINE[0], LINE[1], "primary", 0.025),
        R(6.2, 12.0, 5.15, 6.0, "secondary", 0.02)])
    tail.cap("panel", "max", "detail")
    # deck lip above and bumper below stand behind the panel, with a post at each end: the lamps sit in a recess
    Hull([(12.0, dict(w=3.72, yb=3.12, yt=3.6, ys=3.3)), (12.45, dict(w=3.66, yb=3.2, yt=3.56, ys=3.34))], rb=0.04,
         tum=0.28, drop=0.18, wcf=0.72, d2=0.05, crown=0.05).build("decklip", "primary", regions=[
             R(12.0, 12.45, 5.15, 6.0, "secondary", 0.0)])
    Hull([(12.0, dict(w=3.72, yb=1.5, yt=2.32, ys=2.1)), (12.55, dict(w=3.62, yb=1.62, yt=2.26, ys=2.05))], rb=0.25,
         tum=0.12, drop=0.08, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")
    box("post", (3.5, 2.72, 12.2), (0.34, 0.86, 0.42), "primary", mirror=True)
    if trim == "STD":
        # two ring lamps: a red rounded rectangle with a dark centre
        Loft([(12.05, {}), (12.3, {})], cx=1.78, w=1.5, yb=2.4, yt=3.06, nt=5, nb=5, yw=0.5).build(
            "lamp", "lights_red", mirror=True)
        Loft([(12.28, {}), (12.33, {})], cx=1.78, w=1.3, yb=2.58, yt=2.88, nt=5, nb=5, yw=0.5).build(
            "lampcore", "detail", mirror=True)
        return
    if trim == "GT":
        # bolder rings, standing further out, either side of a centre fin
        Loft([(12.05, {}), (12.42, {})], cx=1.8, w=1.5, yb=2.36, yt=3.1, nt=5, nb=5, yw=0.5).build(
            "lamp", "lights_red", mirror=True)
        Loft([(12.4, {}), (12.45, {})], cx=1.8, w=1.2, yb=2.62, yt=2.84, nt=5, nb=5, yw=0.5).build(
            "lampcore", "detail", mirror=True)
        f_blade([(11.9, 1.6, 3.3), (12.4, 1.6, 3.3), (12.72, 1.75, 3.05)], 0.0, 0.11).build("fin", "primary")
    else:
        # one ring the full width of the panel, with a second ring inside it
        Loft([(12.05, {}), (12.42, {})], w=3.3, yb=2.36, yt=3.1, nt=6, nb=6, yw=0.5).build("lamp", "lights_red")
        Loft([(12.4, {}), (12.45, {})], w=3.06, yb=2.56, yt=2.9, nt=6, nb=6, yw=0.5).build("lampcore", "detail")
        Loft([(12.42, {}), (12.5, {})], w=2.7, yb=2.68, yt=2.78, nt=6, nb=6, yw=0.5).build("lampbar", "lights_red")
    # diffuser: an upswept black ramp under each rear corner, outboard of the overdrive, between strakes
    evo = trim == "EVO"
    x0, x1 = pick(trim, 2.96, 2.96, 3.14), 3.88
    Loft([(10.1, dict(yb=-0.5, yt=-0.3)), (11.2, dict(yb=-0.3, yt=-0.14)), (13.3, dict(yb=0.5, yt=0.62))],
         cx=(x0 + x1) / 2, w=(x1 - x0) / 2, nt=7, nb=7, yw=0.5).build("ramp", "secondary", mirror=True)
    back = 13.38 if evo else 13.3
    for i, x in enumerate(pick(trim, (), (x0 + 0.02, x1 - 0.02), (x0 + 0.02, (x0 + x1) / 2, x1 - 0.02))):
        f_blade([(10.1, -0.8, -0.3), (12.6, -0.8, 0.38), (back, -0.3, 0.64)], x, 0.045).build(
            f"strake{i}", "detail" if i % 2 else "secondary", mirror=True)
    if evo:
        # wheelie bars: two thin rails from the floor down to a low cross bar behind the car
        f_fine(Loft([(10.5, dict(yb=0.72, yt=0.86)), (13.3, dict(yb=-0.97, yt=-0.83))], cx=3.0, w=0.07, nt=2,
                    nb=2, yw=0.5)).build("rail", "metal", mirror=True)
        f_fine(xtube(-3.07, 3.07, 13.3, -0.9, 0.07)).build("crossbar", "metal")


def f_boost(trim):
    """Two barrels close together in a black valance under the bumper. GT: two round turbine exits with
    stepped rings. EVO: three turbine exits in a finned housing."""
    K.begin("F", "BOOST", trim)
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.55, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "secondary", regions=[
             R(10.8, 12.2, 3.0, 3.6, "primary", 0.0)])
    if trim == "STD":
        barrel("barrel", 11.6, 13.2, 0.98, 0.4, 0.86, depth=0.55, collar=False, ry=0.56, n=4.5)
    elif trim == "GT":
        f_turbine("noz", 13.0, 1.05, 0.42, 0.86, 0.14, 0.34, z0=11.6)
    else:
        f_turbine("nozc", 13.1, 0.0, 0.42, 0.76, 0.14, 0.3, z0=11.6)
        f_turbine("noz", 12.95, 1.68, 0.42, 0.74, 0.14, 0.3, z0=11.6)
        for i, x in enumerate((0.84, 2.52)):
            f_blade([(11.3, -0.44, 1.32), (12.5, -0.44, 1.4), (13.1, -0.1, 1.0)], x, 0.04).build(
                f"fin{i}", "secondary", mirror=True)


def f_wing(trim):
    """One-piece ducktail lip, low on the deck edge. GT: a taller ducktail between end fins. EVO: the lip
    under a tall, flat and wide drag wing on two struts."""
    K.begin("F", "WING", trim)
    if trim == "GT":
        Hull([(10.5, dict(yb=3.2, yt=3.62, ys=3.56)), (11.8, dict(yb=3.2, yt=4.02, ys=3.86)),
              (12.75, dict(w=3.56, yb=3.8, yt=4.52, ys=4.3))], w=3.62, rb=0.02, tum=0.14, drop=0.04, wcf=0.72,
             d2=0.01, crown=0.03).build("lip", "primary", regions=[R(10.5, 12.75, 5.15, 6.0, "secondary", 0.0)])
        f_blade([(10.2, 2.9, 3.45), (12.1, 2.9, 4.55), (12.95, 3.5, 4.75)], 3.5, 0.07).build(
            "fin", "primary", mirror=True)
        return
    Hull([(11.2, dict(yt=3.66, ys=3.6)), (12.5, dict(w=3.6, yt=3.98, ys=3.78))], w=3.68, yb=3.5, rb=0.02, tum=0.14,
         drop=0.04, wcf=0.72, d2=0.01, crown=0.03).build("lip", "primary", regions=[
             R(11.2, 12.5, 5.15, 6.0, "secondary", 0.0)])
    if trim == "EVO":
        blade = Loft([(-4.7, {}), (4.7, {})], axis="x", cx=12.1, w=1.15, yb=5.52, yt=5.72, nt=4, nb=4, yw=0.5)
        blade.build("blade", "primary", regions=[R(-1.3, 1.3, 0, 360, "secondary", 0.0)])
        box("gurney", (0, 5.76, 13.2), (9.3, 0.22, 0.08), "detail")
        f_blade([(10.7, 5.25, 5.85), (12.6, 5.05, 6.1), (13.36, 5.05, 6.2)], 4.72, 0.06).build(
            "endplate", "secondary", mirror=True)
        f_blade([(11.35, 2.9, 4.6), (11.65, 2.9, 5.6), (12.3, 2.9, 5.6), (12.5, 3.5, 5.6)], 3.0, 0.06).build(
            "strut", "metal", mirror=True)


def car_f():
    f_cockpit()
    for trim in TRIMS:
        f_nose(trim)
        f_tail(trim)
        f_fpod(trim)
        f_rpod(trim)
        f_stab(trim)
        f_boost(trim)
        f_wing(trim)


def build(out=None):
    return build_car("brawler", "F", car_f, out=out)
