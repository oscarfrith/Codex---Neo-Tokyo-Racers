"""Agent B helpers on top of sgspec: box-by-extents, face-mounted kits/panels, cores. Roblox studs, Y up.

Faces are named by their outward normal: 'n' (-Z, waterfront side), 's' (+Z), 'w' (-X, boulevard side), 'e' (+X).
A kit's street front is its -Z face; FACE_RY turns it to look out of the given face.
Variant base materials: SG Windows * / SG Patched Panels -> SmoothPlastic; SG Weathered Concrete, SG Capsule Panels,
SG Graffiti * -> Concrete (a MaterialVariant only applies when Part.Material matches its BaseMaterial).
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "common"))
from sgspec import Spec  # noqa: E402

FACE_RY = {"n": 0, "s": 180, "w": 90, "e": -90}
# palette
WHITE = (226, 226, 222)
OFFWHITE = (205, 205, 198)
CONC = (150, 150, 146)
CONC_D = (118, 118, 114)
CONC_L = (176, 174, 168)
GLASS = (60, 90, 115)
STEEL = (70, 74, 80)
PASTEL = [(170, 214, 196), (226, 160, 140), (232, 214, 140), (150, 190, 226), (214, 170, 120), (200, 170, 210)]

VARBASE = {"SG Windows Blocks": "SmoothPlastic", "SG Windows Capsule": "SmoothPlastic", "SG Patched Panels": "SmoothPlastic",
           "SG Weathered Concrete": "Concrete", "SG Capsule Panels": "Concrete", "SG Graffiti A": "Concrete",
           "SG Graffiti B": "Concrete", "Concrete Wood Formed": "Concrete", "Concrete Square Panels": "Concrete",
           "Concrete Rectangular Panels": "Concrete", "Metal Shutters": "Metal", "Windows Day": "SmoothPlastic"}


def box(s, x0, x1, y0, y1, z0, z1, var="", color=CONC, mat=None, layer=None, name=None, rot=(0, 0, 0), **kw):
    """Block from world extents. Material follows the variant's base unless given."""
    if mat is None:
        mat = VARBASE.get(var, "Concrete")
    size = (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0))
    pos = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    return s.part("Block", size, pos, rot=rot, mat=mat, var=var, color=color, layer=layer, name=name, **kw)


def cyl(s, x, z, y0, y1, d, var="SG Capsule Panels", color=WHITE, mat=None, layer=None, name="Core"):
    """Vertical cylinder (Roblox cylinder axis is X, so roll 90)."""
    if mat is None:
        mat = VARBASE.get(var, "Concrete")
    return s.part("Cylinder", (y1 - y0, d, d), (x, (y0 + y1) / 2, z), rot=(0, 0, 90), mat=mat, var=var, color=color,
                  layer=layer, name=name)


def face_pos(face, plane, u, y, depth, embed=0.5):
    """Centre for an item of given depth mounted on a face (plane = face coordinate, u = along-face coordinate)."""
    off = depth / 2 - embed
    if face == "n":
        return (u, y, plane - off)
    if face == "s":
        return (u, y, plane + off)
    if face == "w":
        return (plane - off, y, u)
    return (plane + off, y, u)


def fkit(s, item, face, plane, u, y, depth, embed=0.5, layer=None, color=None, scale=1.0, name=None):
    return s.kit(item, face_pos(face, plane, u, y, depth * scale, embed), rot=(0, FACE_RY[face], 0), layer=layer,
                 color=color, scale=scale, name=name)


def fpanel(s, face, plane, u0, u1, y0, y1, depth, var="", color=CONC, mat=None, embed=0.5, layer=None, name=None):
    """Slab laid on a face: spans u0..u1 along the face, y0..y1, projecting depth (embedded by embed)."""
    d0 = -embed
    d1 = depth - embed
    if face == "n":
        return box(s, u0, u1, y0, y1, plane - d1, plane - d0, var, color, mat, layer, name)
    if face == "s":
        return box(s, u0, u1, y0, y1, plane + d0, plane + d1, var, color, mat, layer, name)
    if face == "w":
        return box(s, plane - d1, plane - d0, y0, y1, u0, u1, var, color, mat, layer, name)
    return box(s, plane + d0, plane + d1, y0, y1, u0, u1, var, color, mat, layer, name)


def roof_cap(s, x0, x1, z0, z1, ytop, over=2, thick=3, color=CONC_D, var="SG Weathered Concrete"):
    """Parapet slab over a mass top (overhang avoids coplanar faces)."""
    return box(s, x0 - over, x1 + over, ytop - 1, ytop - 1 + thick, z0 - over, z1 + over, var, color, name="Roof")


def shopfront(s, face, plane, u0, u1, y0=100, h=26, depth_in=4, cols=40, col_w=4, graffiti=None, gh=14, awning=True,
              shutters=()):
    """Ground-floor strip on a face: recessed glass, chunky concrete columns every `cols`, awning band, optional
    graffiti band above, optional roll-shutter bays (list of (u0, u1)). The glass sits depth_in behind the face plane,
    so the ground-floor mass behind it must be inset by depth_in on this face."""
    sgn0 = {"n": -1, "s": 1, "w": -1, "e": 1}[face]
    for a, b in shutters:
        fpanel(s, face, plane - sgn0 * depth_in, a, b, y0, y0 + h - 5, 2.0, var="Metal Shutters", color=(150, 154, 158),
               layer="LOD2", name="Shutter")
    sgn = {"n": -1, "s": 1, "w": -1, "e": 1}[face]
    gplane = plane - sgn * depth_in
    fpanel(s, face, gplane, u0, u1, y0, y0 + h - 4, 1.0, mat="Glass", color=GLASS, layer="LOD2", name="Shopfront")
    u = u0
    while u <= u1 + 0.1:
        a, b = max(u0, u - col_w / 2), min(u1, u + col_w / 2)
        fpanel(s, face, gplane, a, b, y0, y0 + h, depth_in + 1.5, var="SG Weathered Concrete", color=CONC, name="Pier")
        u += cols
    if awning:
        fpanel(s, face, plane, u0 - 1, u1 + 1, y0 + h - 4, y0 + h, 7.0, color=CONC_L, name="Awning")
    if graffiti:
        fpanel(s, face, plane, u0, u1, y0 + h, y0 + h + gh, 1.0, var=graffiti, color=(170, 170, 165), name="Graffiti")
