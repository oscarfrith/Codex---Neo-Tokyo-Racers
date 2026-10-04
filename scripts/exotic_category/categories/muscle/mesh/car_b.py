"""Car B: Outlaw (muscle_02, tier D), after the Holden HSV Maloo ute (2017). STD trim.
Runs inside Blender; build with run_headless.py -- car_b.

Design language of B: a modern coupe utility. Raked two-seat cab; two tall body-colour sail-plane
buttresses sweep from the roof's rear edge down onto the bed sides, with a low hoop bar between them and a
hard black tonneau closing the bed. Wide low one-piece grille with a centre bar over a deep chin, a nose that
tapers in plan, twin low snorkel intakes on a black bonnet insert, a flat tailgate with tall vertical lamps.
Pods and sill are "wedge and saddle", surfaced like the body: slim forward-leaning wedge front pods with a
swept light blade, long saddle pods beside the bed that rise slightly to the tail, a thin blade skirt with one
wide slot thruster, one wide burner. One shoulder line runs front pod, sill top, rear pod.
"""
import exokit as K
import musclekit as M  # noqa: F401  (sets the frame up)
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, Z_F, Z_R
from muscle_cars import LINE, barrel, bazooka, build_car, flange, lift_glow, tub

# Tonneau and bonnet insert: ring ranges on a body-width top panel.
TONNEAU = (4.3, 6.0)
INSERT = (5.3, 6.0)
# Pod section, in the body's own language: a crowned flank under one shoulder crease, a taut upper panel
# leaning in to a small-radius top edge, a flat inboard face at x 4.1.
POD = dict(rb=0.3, tum=0.42, drop=0.3, tumi=0.03, dropi=0.05, wcf=0.72, d2=0.03, crown=0.04, cs=0.025)
# Fine groove under the pod shoulder, the same cut as the body's character line.
SHOULDER = (2.84, 2.96)


def b_sec(xo, yb, yt, ys, **kw):
    """Pod station: inboard face at x 4.1, outboard face at xo."""
    return dict(cx=(4.1 + xo) / 2, w=(xo - 4.1) / 2, yb=yb, yt=yt, ys=ys, **kw)


def b_cockpit():
    """Raked two-seat cab in one roof arc, with a raked rear window. Behind it two sail-plane buttresses
    (part of this module, so they sit on any tail's deck) and a low hoop bar between their tops."""
    K.begin("B", "COCKPIT")
    tub()
    gh = Hull([(-6.0, dict(w=3.52, yb=3.1, yt=3.2, ys=3.14, tum=0.12, drop=0.02, crown=0.02)),
               (-4.6, dict(w=3.62, yt=4.45, tum=0.5, drop=0.16)),
               (-3.3, dict(w=3.64, yt=5.4, tum=0.7)),
               (-1.6, dict(w=3.64, yt=5.64, tum=0.73)),
               (0.2, dict(w=3.63, yt=5.58, tum=0.75)),
               (1.3, dict(w=3.6, yt=5.4, tum=0.78)),
               (2.7, dict(w=3.5, yb=2.95, yt=3.24, ys=3.0, tum=0.68, drop=0.2, crown=0.02))],
              w=3.64, yb=3.1, ys=3.3, rb=0.04, tum=0.72, drop=0.21, wcf=0.75, d2=0.045, crown=0.065)
    gh.build("cabin", "primary", regions=[
        R(-5.84, -3.5, 4.13, 6.0, "detail", 0.015),     # windscreen surround
        R(-5.75, -3.61, 4.185, 6.0, "glass", 0.04),     # windscreen
        R(-4.85, 1.0, 3.04, 3.88, "detail", 0.015),     # door glass surround
        R(-4.74, 0.89, 3.085, 3.835, "glass", 0.04),    # door glass
        R(1.5, 2.5, 4.55, 6.0, "detail", 0.0),          # rear window surround
        R(1.56, 2.44, 4.63, 6.0, "glass", 0.04)])       # rear window
    # Sail-plane buttress: a thin plate lofted upward; its rear edge sweeps from the roof edge down to the
    # bed side. Its outer face follows the cab side's own curve, a hair proud of it, and starts at the rear
    # edge of the door glass surround, so the plate is the rear pillar surface and no crease shows where it
    # leaves the cab.
    Loft([(2.95, dict(cx=3.32, yt=6.6)), (3.3, dict(cx=3.365, yt=5.8)), (3.82, dict(cx=3.27, yt=4.67)),
          (4.31, dict(cx=3.105, yt=3.58)), (4.78, dict(cx=2.885, yt=2.4)), (5.2, dict(cx=2.6, yt=1.35))],
         axis="y", w=0.25, yb=1.02, nt=6, nb=6, yw=0.5).build("buttress", "primary", mirror=True)
    box("hoop", (0, 4.3, 3.0), (5.4, 0.3, 0.42), "secondary")


def b_nose():
    """Nose that tapers in plan: one wide, low grille opening with a body-colour centre bar, over a deep
    chin. Black bonnet insert with two low forward-facing snorkel intakes side by side."""
    K.begin("B", "NOSE")
    nose = Hull([(-12.3, dict(w=3.5, yb=0.1, yt=2.36, ys=1.88, rb=0.25, tum=0.25, drop=0.18)),
                 (-11.4, dict(w=3.78, yb=-0.15, yt=2.6, ys=2.04, rb=0.35)),
                 (-9.2, dict(w=3.9, yt=2.9, ys=2.25)),
                 (Z_F, SEAM_F)], **SEAM_F)
    nose.build("skin", "primary", t1=Z_F - GAP, caps=(False, False), regions=[
        R(-12.3, Z_F - GAP, 0.0, 2.0, "secondary", 0.02),
        R(-11.7, Z_F - GAP, LINE[0], LINE[1], "primary", 0.025),
        R(-11.5, Z_F - GAP, INSERT[0], INSERT[1], "secondary", 0.02)])
    nose.cap("grilleback", "min", "detail")
    kw = dict(tum=0.2, wcf=0.7)
    Hull([(-13.0, dict(w=3.32, yb=1.98, yt=2.2, ys=2.07)), (-12.3, dict(w=3.5, yb=1.93, yt=2.36, ys=2.1))], rb=0.04,
         drop=0.1, d2=0.02, crown=0.03, **kw).build("brow", "primary")
    Hull([(-13.25, dict(w=3.28, yb=0.3, yt=0.86, ys=0.68)), (-12.3, dict(w=3.5, yb=0.1, yt=0.92, ys=0.72))], rb=0.2,
         drop=0.08, d2=0.0, crown=0.02, **kw).build("bumper", "primary")
    box("bar", (0, 1.43, -12.82), (6.5, 0.16, 0.24), "primary")
    box("post", (3.2, 1.43, -12.66), (0.3, 1.12, 0.6), "primary", mirror=True)
    box("intake", (0, 0.57, -13.24), (3.8, 0.24, 0.08), "detail")
    Loft([(-13.6, dict(w=2.95)), (-12.9, dict(w=3.5)), (-11.2, dict(w=3.85))], yb=-0.5, yt=-0.38, nt=5,
         nb=5).build("chin", "secondary")
    # twin snorkels: low rectangular ram intakes on the insert
    sn = Hull([(-9.6, dict(yt=3.32, ys=3.16)), (-7.0, dict(yt=3.46, ys=3.28))], cx=0.66, w=0.5, yb=2.9, rb=0.02,
              tum=0.08, drop=0.06, wcf=0.75, d2=0.01, crown=0.02)
    sn.build("snorkel", "primary", mirror=True, caps=(False, True))
    sn.throat("snorkelin", "min", lip="primary", wall="detail", back="detail", scale=0.8, depth=0.5, mirror=True)


def b_fpod():
    """Wedge: a slim forward-leaning pod. Its top line falls with the bonnet, its belly rakes up to a narrow
    tip, and its flank sweeps back in plan from that tip. The shoulder crease runs on into the sill top. A slim
    light blade lies along the swept flank above the shoulder, in a thin dark surround."""
    K.begin("B", "FPOD")
    pod = Hull([(-13.0, b_sec(4.9, 0.15, 0.74, 0.5, rb=0.1, tum=0.12, drop=0.08)),
                (-12.2, b_sec(5.7, -0.35, 1.2, 0.7, rb=0.2, tum=0.25, drop=0.16)),
                (-10.6, b_sec(6.15, -0.95, 1.5, 0.85)),
                (-8.4, b_sec(6.25, -1.2, 1.7, 0.94)),
                (POD_FZ, b_sec(6.2, -1.25, 1.85, 1.0))], **POD)
    pod.build("skin", "primary", mirror=True, caps=(True, False), regions=[
        R(-12.6, POD_FZ - 0.15, 0.0, 2.0, "secondary", 0.02),
        R(-12.3, POD_FZ - 0.3, SHOULDER[0], SHOULDER[1], "primary", 0.025, side=1),
        R(-12.85, -11.48, 3.08, 3.92, "detail", 0.015, side=1),
        R(-12.76, -11.57, 3.24, 3.76, "lights", 0.04, side=1)])
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.55, depth=0.6, mirror=True)
    flange(-10.6, -6.4, -0.2, 1.3)
    lift_glow(pod, [(-10.4, -7.4)])


def b_slot(name, z0, z1, x, y, r, ry):
    """Slot nozzle: a slim dark frame round a metal tunnel with a glowing back."""
    t = Loft([(z0, {}), (z1, {})], cx=x, w=r, yb=y - ry, yt=y + ry, nt=5, nb=5, yw=0.5)
    t.build(name, "detail", mirror=True, caps=(True, False))
    t.throat(name + "n", "max", lip="detail", wall="metal", back="thrust", scale=0.88, depth=0.2, mirror=True)


def b_rpod():
    """Saddle: a long, sleek pod beside the bed. A raked leading face lifts the sill line up to a top that
    runs with the bed rail and rises slightly to the tail; the belly kicks up into a slight boat-tail that
    carries one wide slot nozzle. Lower than the bed rail."""
    K.begin("B", "RPOD")
    pod = Hull([(POD_RZ, b_sec(6.2, -1.3, 1.3, 1.1, tum=0.15, drop=0.06)),
                (5.0, b_sec(6.3, -1.3, 1.95, 1.16)),
                (9.0, b_sec(6.3, -1.3, 2.1, 1.34)),
                (10.6, b_sec(6.24, -1.0, 2.16, 1.42)),
                (12.2, b_sec(5.86, -0.1, 2.2, 1.5, rb=0.2, tum=0.34, drop=0.24))], **POD)
    pod.build("skin", "primary", mirror=True, regions=[
        R(POD_RZ + 0.15, 12.05, 0.0, 2.0, "secondary", 0.02),
        R(POD_RZ + 0.5, 11.9, SHOULDER[0], SHOULDER[1], "primary", 0.025, side=1)])
    b_slot("slot", 11.6, 12.5, 4.98, 0.92, 0.74, 0.42)
    flange(5.2, 10.6, -0.3, 1.5)
    lift_glow(pod, [(5.8, 9.4)])


def b_stab():
    """Blade skirt: a thin vertical blade along the sill whose top edge carries the pod shoulder line from
    the front pod to the rear pod, with one wide slot thruster swept back and down."""
    K.begin("B", "STAB")
    blade = Hull([(POD_FZ + 0.1, dict(yt=1.0, ys=0.88)), (POD_RZ - 0.1, dict(yt=1.1, ys=0.98))], cx=4.4, w=0.3,
                 yb=-1.2, rb=0.08, tum=0.1, drop=0.02, wcf=0.7, d2=0.0, crown=0.0, cs=0.02)
    blade.build("blade", "primary", mirror=True, regions=[
        R(POD_FZ + 0.1, POD_RZ - 0.1, 0.0, 2.4, "secondary", 0.0)])
    bazooka("slot", 4.5, 6.3, -0.6, 0.1, 0.5, back=1.0, down=0.55, wide=2.0, flat=0.4, n=5)
    lift_glow(blade, [(-5.0, -3.6), (1.6, 3.0)])


def b_tail():
    """Covered deck: bed sides in body colour with a hard black tonneau sunk between them, a flat tailgate
    with a tall vertical lamp at each outer edge, over a plain bumper."""
    K.begin("B", "TAIL")
    tail = Hull([(Z_R, SEAM_R), (6.5, dict(yt=3.38)), (9.8, dict(yt=3.52, ys=2.7)),
                 (10.6, dict(yb=-0.3, yt=3.54, ys=2.75)), (11.3, dict(yb=1.4, rb=0.25, yt=3.56, ys=2.8)),
                 (12.1, dict(w=3.8, yb=1.5, yt=3.58, ys=2.82, rb=0.25))], **SEAM_R)
    tail.build("skin", "primary", t0=Z_R + GAP, caps=(False, False), regions=[
        R(Z_R + GAP, 12.1, 0.0, 2.0, "secondary", 0.02),
        R(Z_R + GAP, 10.4, LINE[0], LINE[1], "primary", 0.025),
        R(3.9, 11.7, TONNEAU[0], TONNEAU[1], "secondary", 0.07)])
    tail.cap("gate", "max", "primary")
    box("lamp", (3.33, 2.62, 12.13), (0.4, 1.3, 0.12), "lights_red", mirror=True)
    Hull([(12.1, dict(w=3.8, yb=1.5, yt=1.94, ys=1.8)), (12.5, dict(w=3.72, yb=1.58, yt=1.9, ys=1.78))], rb=0.2,
         tum=0.1, drop=0.06, wcf=0.7, d2=0.0, crown=0.02).build("bumper", "primary")


def b_boost():
    """One single wide flat burner in the centre of a black valance."""
    K.begin("B", "BOOST")
    Hull([(10.8, dict(w=2.85)), (12.2, dict(w=2.6, yb=-0.25))], yb=-0.45, yt=1.3, rb=0.35, ys=0.95, tum=0.25,
         drop=0.05, wcf=0.6, d2=0.0, crown=0.02).build("housing", "secondary", regions=[
             R(10.8, 12.2, 3.0, 3.6, "primary", 0.0)])
    barrel("burner", 11.6, 13.1, 0.0, 0.42, 1.9, depth=0.5, collar=False, ry=0.42, n=5)


def b_wing():
    """Slim lip on the top edge of the tailgate; the tonneau black runs over its centre."""
    K.begin("B", "WING")
    Hull([(11.5, dict(yt=3.6, ys=3.5, drop=0.1)), (12.4, dict(w=3.56, yt=3.76, ys=3.6, drop=0.08))], w=3.62,
         yb=3.36, rb=0.02, tum=0.12, wcf=0.72, d2=0.03, crown=0.03).build("lip", "primary", regions=[
             R(11.5, 12.4, TONNEAU[0], TONNEAU[1], "secondary", 0.0)])


def car_b():
    b_cockpit()
    b_nose()
    b_tail()
    b_fpod()
    b_rpod()
    b_stab()
    b_boost()
    b_wing()


def build(out=None):
    return build_car("outlaw", "B", car_b, out=out)
