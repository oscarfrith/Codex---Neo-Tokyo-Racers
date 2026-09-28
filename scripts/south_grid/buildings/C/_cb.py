"""Agent C shared building helpers (bounds-based parts on the 20/40 facade grid).
All helpers take world bounds; a storey is 40/3 studs (3 storeys per 40-stud window tile).
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "common"))
from sgspec import Spec  # noqa: E402

ST = 40.0 / 3.0  # storey height

# palette / material presets: (mat, var, color)
CONC = ("Concrete", "SG Weathered Concrete", (156, 153, 146))
CONC_D = ("Concrete", "SG Weathered Concrete", (128, 126, 121))
BOARD = ("Concrete", "Concrete Wood Formed", (164, 160, 152))
BOARD_D = ("Concrete", "Concrete Wood Formed", (122, 120, 116))
CAPS = ("Concrete", "SG Capsule Panels", (226, 224, 216))
WIN = ("SmoothPlastic", "SG Windows Blocks", (214, 212, 206))
WINC = ("SmoothPlastic", "SG Windows Capsule", (226, 226, 220))
PATCH = ("SmoothPlastic", "SG Patched Panels", (232, 230, 224))
GRAF_A = ("Concrete", "SG Graffiti A", (200, 200, 196))
GRAF_B = ("Concrete", "SG Graffiti B", (200, 200, 196))
SHUT = ("Metal", "Metal Shutters", (118, 122, 128))
GLASS = ("Glass", "", (96, 128, 150))
DARK = ("SmoothPlastic", "", (54, 56, 60))
METAL = ("Metal", "", (92, 96, 100))
TILE = ("CeramicTiles", "Tiles Square Large", (170, 166, 156))


def box(s, x0, x1, y0, y1, z0, z1, m=CONC, name="Block", shape="Block", rot=(0, 0, 0), layer=None, **kw):
    mat, var, col = m
    size = (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0))
    pos = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    return s.part(shape, size, pos, rot=rot, mat=mat, var=var, color=kw.pop("color", col), name=name, layer=layer, **kw)


def neon(s, x0, x1, y0, y1, z0, z1, color, name="Neon strip", layer=None):
    return s.part("Block", (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                  mat="Neon", color=color, name=name, layer=layer, shadow=False, collide=False)


def levels(y0, y1, every=1, start=0):
    """Floor levels from y0 (inclusive) stepping every*ST while < y1 - 1."""
    out, k = [], start
    while True:
        y = y0 + k * ST
        if y > y1 - 1:
            break
        out.append(y)
        k += every
    return out


def plates(s, x0, x1, z0, z1, ys, h=4.5, m=PATCH, name="Balcony band"):
    """One slab+parapet plate per level spanning the given bounds (bounds include the protrusion)."""
    for y in ys:
        box(s, x0, x1, y, y + h, z0, z1, m, name=name)


def fins_x(s, xs, y0, y1, z0, z1, t=1.6, m=CONC, name="Balcony fin"):
    for x in xs:
        box(s, x - t / 2, x + t / 2, y0, y1, z0, z1, m, name=name)


def fins_z(s, zs, y0, y1, x0, x1, t=1.6, m=CONC, name="Balcony fin"):
    for z in zs:
        box(s, x0, x1, y0, y1, z - t / 2, z + t / 2, m, name=name)


def grid(a0, a1, step=40.0, inset=False):
    """Interior grid lines strictly between a0 and a1 at `step` spacing from a0."""
    out, v = [], a0 + step
    while v < a1 - 1:
        out.append(v)
        v += step
    return out
