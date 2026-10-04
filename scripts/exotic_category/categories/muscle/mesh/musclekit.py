"""Modern Muscle frame standard (runs inside Blender). Reuses the Exotic modelling kit (mesh/exokit.py)
with its own prefix, paints, seams and envelopes. exokit.py itself is not edited.

    import sys
    sys.path[:0] = [r"<repo>/scripts/exotic_category/mesh", r"<repo>/scripts/exotic_category/categories/muscle/mesh"]
    import musclekit, muscle_cars

Game root space as Exotic: +X right, +Y up, forward is -Z, studs.

The frame. Every car is built from eight parts that meet on fixed faces, so any part fits any car:
  COCKPIT  tub between the two body seams (z -4.6 to 3.4) with the greenhouse on top.
  NOSE     nose clip and bonnet, from the front seam forward. The bonnet turbine lives here.
  TAIL     deck, boot or load bed, from the rear seam back. Its lower rear centre is left open for BOOST.
  FPOD     front engine pods, outboard of the nose. They carry the headlights; the jet exits at the back face.
  RPOD     rear engine pods, outboard of the tail, bigger than the front pods; nozzle at the tail.
  STAB     drift thrusters: sill units between the pods, firing sideways.
  BOOST    overdrive: centre of the tail under the bumper.
  WING     on the deck.
Against Exotic the body is taller and slab-sided (beltline 2.4, bonnet 3.0, roof about 5.5), the cabin is a
real greenhouse, and the pods are square boxes that stand 0.2 clear of the body side.
"""
import exokit as K

K.PREFIX = "MSC_"

# Extra paint channel for bare metal jet hardware (barrels, pipes, bolts, grille bars). It is not one of the
# paint channels of the game yet: the content installer must map it before these cars are installed.
_exo_material = K._material


def _material(car, ch):
    if ch != "metal":
        return _exo_material(car, ch)
    import bpy
    name = f"{K.PREFIX}{car}_metal"
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.62, 0.63, 0.66, 1.0)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.22
    m.diffuse_color = (0.62, 0.63, 0.66, 1.0)
    return m


K._material = _material

# Preview paint per car letter. Players repaint primary, secondary and detail in game.
K.PAINT = {
    "A": {"primary": (0.80, 0.78, 0.70), "secondary": (0.02, 0.02, 0.024)},   # 01 El Camino: cream, black
    "B": {"primary": (0.75, 0.22, 0.02), "secondary": (0.02, 0.02, 0.024)},   # 02 orange, black
    "C": {"primary": (0.85, 0.62, 0.02), "secondary": (0.02, 0.02, 0.024)},   # 03 Camaro: yellow, black
    "D": {"primary": (0.02, 0.10, 0.55), "secondary": (0.80, 0.80, 0.78)},    # 04 Mustang: blue, white
    "E": {"primary": (0.01, 0.12, 0.07), "secondary": (0.30, 0.19, 0.08)},    # 05 CT5: emerald, bronze
    "F": {"primary": (0.16, 0.02, 0.22), "secondary": (0.02, 0.02, 0.024)},   # 06 Challenger: plum, black
}

Z_F, Z_R = -4.6, 3.4          # the two body seams
BODY_W = 3.9                  # half width of the body side
POD_IN = 4.1                  # inboard face of every pod and sill unit
GAP = K.GAP

# Body seams: fixed Hull sections shared by every cockpit, nose and tail. Round 2 of the frame (2026-10-04):
# taller, with real tumblehome and crown, so the body reads as a car and not a slab.
SEAM_F = dict(cx=0.0, w=BODY_W, yb=-0.4, yt=3.2, rb=0.5, ys=2.45, tum=0.42, drop=0.3, wcf=0.72, d2=0.06,
              crown=0.05, cs=0.035)
SEAM_R = dict(SEAM_F)
# Pod end faces: the back of a front pod and the front of a rear pod start from these, so a sill unit
# always meets the same two faces.
SIDE_F = dict(cx=5.4, w=1.3, yb=-1.2, yt=2.3, rb=0.45, ys=1.6, tum=0.4, drop=0.28, wcf=0.6, d2=0.03, crown=0.08,
              cs=0.04)
SIDE_R = dict(SIDE_F, cx=5.45, w=1.35, yb=-1.4, yt=2.8, ys=2.0)
POD_FZ, POD_RZ = -6.0, 4.0    # where those faces sit

# Boxes are (|x| min, |x| max, y min, y max, z min, z max).
K.ENV = {
    # tub, then the greenhouse (it laps onto the cowl and the deck)
    "COCKPIT": [(0, 4.0, -0.6, 3.3, -4.7, 3.5), (0, 3.8, 2.9, 6.1, -6.1, 6.6)],
    # body, chin and splitter zone, bonnet turbine zone
    "NOSE": [(0, 3.95, -0.6, 3.4, -13.4, -4.5), (0, 3.95, -1.0, 0.6, -13.9, -10.5), (0, 2.2, 3.0, 5.2, -11.0, -5.2)],
    # body, bed and buttress zone above the deck, diffuser zone
    "TAIL": [(0, 3.95, -0.6, 3.7, 3.3, 12.7), (0, 3.95, 3.0, 5.9, 3.3, 9.0), (0, 3.95, -1.0, 1.0, 9.5, 13.4)],
    "FPOD": [(3.95, 6.95, -1.7, 3.2, -13.1, -5.9)],
    "RPOD": [(3.95, 6.95, -1.8, 4.3, 3.9, 12.8)],
    "STAB": [(3.95, 6.95, -1.6, 1.9, -5.95, 3.95)],
    "BOOST": [(0, 2.9, -0.8, 1.5, 10.6, 13.4)],
    "WING": [(0, 6.9, 2.8, 6.9, 8.5, 13.4)],
    "FREE": [(0, 99, -99, 99, -99, 99)],
}
