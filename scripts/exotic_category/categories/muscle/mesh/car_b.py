"""Car B: Outlaw (muscle_02, tier D), after the Holden HSV Maloo ute (2017). STD trim.
Runs inside Blender; build with run_headless.py -- car_b.

Design language of B: a modern coupe utility. Raked two-seat cab; two tall body-colour sail-plane
buttresses sweep from the roof's rear edge down onto the bed sides, with a low hoop bar between them and a
hard black tonneau closing the bed. Wide low one-piece grille with a centre bar over a deep chin, a nose that
tapers in plan, twin low snorkel intakes on a black bonnet insert, a flat tailgate with tall vertical lamps.
Pods and sill are "wedge and saddle": angular wedge front pods with slanted lamps on a raked face, long
flat-topped saddle pods beside the bed, a thin blade skirt with one wide slot thruster, one wide burner.
"""
import exokit as K
import musclekit as M  # noqa: F401  (sets the frame up)
from exokit import Hull, Loft, R, box
from musclekit import GAP, POD_FZ, POD_RZ, SEAM_F, SEAM_R, Z_F, Z_R
from muscle_cars import LINE, barrel, bazooka, build_car, flange, lift_glow, tub

# Tonneau and bonnet insert: ring ranges on a body-width top panel.
TONNEAU = (4.3, 6.0)
INSERT = (5.3, 6.0)
# Angular pod section: flat planes, a chamfered shoulder, crisp edges, no crown.
FLAT = dict(wcf=0.7, d2=0.0, crown=0.0, cs=0.0)
WEDGE = dict(rb=0.25, tum=0.4, drop=0.02, **FLAT)
SADDLE = dict(cx=5.35, w=1.25, rb=0.2, tum=0.16, drop=0.02, **FLAT)


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
    # Sail-plane buttress: a thin plate lofted upward, leaning in with the cab side; its rear edge sweeps
    # from the roof edge down to the bed side.
    Loft([(2.95, dict(cx=3.27, yt=6.6)), (3.3, dict(cx=3.27, yt=5.8)), (4.2, dict(cx=2.92, yt=3.85)),
          (5.2, dict(cx=2.54, yt=1.55))], axis="y", w=0.25, yb=1.0, nt=6, nb=6, yw=0.5).build(
        "buttress", "primary", mirror=True)
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
    """Wedge: flat planes with a chamfered shoulder, thin at the front and rising to the back, tapering in
    plan. The sharply raked front face carries one slanted trapezoid lamp."""
    K.begin("B", "FPOD")
    front = dict(cx=5.2, w=1.1, yb=-0.35, yt=1.35, ys=0.93)
    pod = Hull([(-12.1, front), (POD_FZ, dict(cx=5.4, w=1.3, yb=-1.25, yt=2.2, ys=1.78))], **WEDGE)
    pod.build("skin", "primary", mirror=True, caps=(False, False), regions=[
        R(-11.95, POD_FZ - 0.15, 1.0, 2.0, "secondary", 0.02)])
    pod.throat("noz", "max", lip="secondary", back="thrust", scale=0.5, depth=0.6, mirror=True)
    face = Hull([(-13.0, dict(cx=5.1, w=0.86, yb=0.0, yt=0.3, ys=0.2, rb=0.08, tum=0.1)), (-12.1, front)], **WEDGE)
    face.build("face", "primary", mirror=True, caps=(True, False), regions=[
        R(-12.78, -12.34, 4.3, 6.0, "detail", 0.015),
        R(-12.7, -12.42, 4.5, 6.0, "lights", 0.04)])
    flange(-11.0, -6.4, -0.2, 1.5)
    lift_glow(pod, [(-10.4, -7.4)])


def b_rpod():
    """Saddle: a long, low, level-topped rectangular pod beside the bed, lower than the bed rail, with a
    raked leading face, a slight boat-tail and one wide rectangular slot nozzle."""
    K.begin("B", "RPOD")
    top = dict(yb=-1.3, yt=1.95, ys=1.77)
    lead = Hull([(POD_RZ, dict(yb=-1.3, yt=1.15, ys=0.97)), (5.0, top)], **SADDLE)
    lead.build("lead", "primary", mirror=True, caps=(True, False), regions=[
        R(POD_RZ + 0.15, 4.85, 1.0, 2.0, "secondary", 0.02),
        R(4.2, 4.8, 4.3, 6.0, "detail", 0.05)])
    pod = Hull([(5.0, top), (9.2, top), (11.8, dict(cx=5.25, w=1.02, yb=-0.75, yt=1.8, ys=1.62))], **SADDLE)
    pod.build("skin", "primary", mirror=True, caps=(False, True), regions=[
        R(5.0, 11.65, 1.0, 2.0, "secondary", 0.02)])
    barrel("slot", 10.8, 12.5, 5.25, 0.52, 0.86, depth=0.6, collar=False, ry=0.4, n=5)
    flange(4.6, 10.6, -0.3, 1.7)
    lift_glow(pod, [(5.8, 9.6)])


def b_stab():
    """Flat blade skirt: a thin vertical blade along the sill, with one wide slot thruster swept back and
    down."""
    K.begin("B", "STAB")
    blade = Hull([(POD_FZ + 0.1, {}), (POD_RZ - 0.1, {})], cx=4.4, w=0.3, yb=-1.2, yt=1.0, ys=0.88, rb=0.08,
                 tum=0.1, drop=0.02, **FLAT)
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
