"""P08 - "West Gate Estate" (The Blocks lean): Western City Gate / Genex style twin slabs joined by a two-tile
bridge block at the top, over a garage-and-market court. The west slab rises higher and wears the round
lookout drum on its detached service tower; the east slab steps out as a 3-tile cantilever over the north street. A 5-tile deck-access
walk-up (L-shaped) wraps the east street and the south corner. Facades are one deep 40x40 coffer grid per
face (fins + bands) over the SG Windows Blocks tile, with patched infill, balconies, laundry and graffiti
on the lower storeys. Bridges to P07 are in XD1.py and land on the west slab's west face.
Run: py -3 P08.py
"""
import random
from dlib import Spec, box, vcyl, check, load_elements, HERE, CONC, CONC_D, CONC_L, PATCH, STEEL, WHITE_D

R = random.Random(8)
s = Spec("P08", kind="building", title="West Gate Estate", lean="blocks")
G = 200
WIN = dict(mat="SmoothPlastic", var="SG Windows Blocks", color=(214, 212, 206))
WEATH = dict(var="SG Weathered Concrete", color=CONC)
SIGN = [(255, 70, 160), (60, 230, 255), (255, 190, 60), (140, 255, 120)]


def fbox(face, u0, u1, y0, y1, d0, d1, **kw):
    """Box on a facade: face=(axis, coord, sign). u runs along the face, d outwards from the face plane."""
    ax, c, sg = face
    if d0 == 0:
        d0 = -0.5  # embed the back face in the wall so hidden faces never share a plane
    a, b = c + sg * d0, c + sg * d1
    if ax == "x":
        return box(s, a, b, y0, y1, u0, u1, **kw)
    return box(s, u0, u1, y0, y1, a, b, **kw)


def grid(face, u0, u1, y0, y1, band_d=8, fin_d=7, patches=0, balconies=0, laundry=0, ac=0, name="grid"):
    """Deep coffer grid on the 40-stud tile: fins every 40 along u, bands every 40 in y (interior lines)."""
    ax, c, sg = face
    for u in range(int(u0) + 40, int(u1), 40):  # end fins omitted: the gables frame the grid
        fbox(face, u - 1, u + 1, y0, y1, 0, fin_d, color=CONC_L, name=f"{name} fin")
    ys = list(range(int(y0) + 40, int(y1), 40))
    for y in ys:
        fbox(face, u0, u1, y - 1.5, y + 1.5, 0, band_d, color=CONC, name=f"{name} band")
    cells = [(u, y) for u in range(int(u0), int(u1) - 39, 40) for y in range(int(y0), int(y1) - 39, 40)]
    R.shuffle(cells)
    allcells = list(cells)
    used = set()
    for k in range(min(patches, len(cells))):  # closed-in balconies, pastel patchwork
        u, y = cells.pop()
        used.add((u, y))
        fbox(face, u + 2, u + 38, y + 1.5 if y > y0 else y + 1, y + 38.5, 3, 4, mat="SmoothPlastic", var="SG Patched Panels",
             color=PATCH[R.randrange(len(PATCH))], name=f"{name} patch")
    ry = {("x", 1): -90, ("x", -1): 90, ("z", 1): 180, ("z", -1): 0}[(ax, sg)]
    low = sorted([cc for cc in cells if cc not in used], key=lambda cc: cc[1])
    placed = []
    for k in range(min(balconies, len(low))):  # open balconies with parapets, one storey each
        u, y = low[k] if k < len(low) // 2 else R.choice(low)
        st = R.randrange(3)
        yy = y + 6.5 + 13.333 * st
        pos = (c + sg * 4.2, yy, u + 20) if ax == "x" else (u + 20, yy, c + sg * 4.2)
        if (u, y, st) in placed:
            continue
        placed.append((u, y, st))
        s.kit("balcony_run_40", pos, rot=(0, ry, 0), scale=0.95, layer="LOD2")
        if laundry > 0:
            laundry -= 1
            lp = (c + sg * 8.7, yy - 5, u + 20) if ax == "x" else (u + 20, yy - 5, c + sg * 8.7)
            s.kit("laundry_line_36", lp, rot=(0, ry, 0), color=PATCH[R.randrange(len(PATCH))], layer="LOD2")
    for k in range(ac):
        u, y = R.choice(allcells)
        yy = y + 6 + 13.333 * R.randrange(3)
        pos = (c + sg * 2, yy, u + 8) if ax == "x" else (u + 8, yy, c + sg * 2)
        s.kit("ac_cluster", pos, rot=(0, ry, 0), layer="LOD2")


def mass(name, x0, x1, z0, z1, y0, y1, faces, gables=("N", "S"), cap=True, **gk):
    """Window body + deep grids on the listed faces + blank weathered gables framing the grid."""
    s.group(name)
    box(s, x0, x1, y0, y1, z0, z1, name=f"{name} body", **WIN)
    for f, opts in faces.items():
        face = {"E": ("x", x1, 1), "W": ("x", x0, -1), "N": ("z", z0, -1), "S": ("z", z1, 1)}[f]
        u0, u1 = opts.pop("span", None) or ((z0, z1) if f in "EW" else (x0, x1))
        grid(face, u0, u1, y0, y1, name=f"{name} {f}", **opts)
    ex = 9 if any(f in faces for f in "EW") else 0
    ez = 9 if any(f in faces for f in "NS") else 0
    for g in gables:
        if g == "N":
            box(s, x0 - ex, x1 + ex, y0, y1, z0 - 2, z0, name=f"{name} gable N", **WEATH)
        if g == "S":
            box(s, x0 - ex, x1 + ex, y0, y1, z1, z1 + 2, name=f"{name} gable S", **WEATH)
        if g == "W":
            box(s, x0 - 2, x0, y0, y1, z0 - ez, z1 + ez, name=f"{name} gable W", **WEATH)
        if g == "E":
            box(s, x1, x1 + 2, y0, y1, z0 - ez, z1 + ez, name=f"{name} gable E", **WEATH)
    if cap:
        box(s, x0 - 10, x1 + 10, y1, y1 + 4, z0 - 3, z1 + 3, color=CONC_D, name=f"{name} roof cap")


def ground(name, x0, x1, z0, z1, streets, y1=240):
    """Garage / shop storey: weathered base with shutters, lit shops, neon strips and graffiti bays."""
    s.group(name)
    box(s, x0, x1, G, y1, z0, z1, name=f"{name} base", **WEATH)
    for f in streets:
        face = {"E": ("x", x1, 1), "W": ("x", x0, -1), "N": ("z", z0, -1), "S": ("z", z1, 1)}[f]
        u0, u1 = (z0, z1) if f in "EW" else (x0, x1)
        pat = ["garage", "shop", "graffiti", "garage", "garage", "shop", "graffiti", "shop"]
        k = R.randrange(8)
        for u in range(int(u0) + 20, int(u1) - 19, 40):
            kind = pat[k % 8]; k += 1
            if kind == "garage":
                fbox(face, u - 16, u + 16, G + 1, G + 24, 0, 0.8, mat="Metal", var="Metal Shutters", color=(150, 158, 160), name="Garage shutter")
            elif kind == "shop":
                fbox(face, u - 16, u + 16, G + 1, G + 22, 0, 0.6, mat="Glass", color=(90, 120, 140), name="Shopfront")
                fbox(face, u - 14, u + 14, G + 23, G + 26, 0, 0.6, mat="Neon", color=SIGN[R.randrange(4)], name="Shop sign")
            else:
                fbox(face, u - 19, u + 19, G + 1, y1 - 13, 0, 0.4, var="SG Graffiti " + R.choice("AB"), color=(200, 200, 200), name="Graffiti bay")
        fbox(face, u0 + 1, u1 - 1, y1 - 12, y1 - 2, 0, 0.3, var="SG Graffiti " + R.choice("AB"), color=(200, 200, 200), name="Graffiti band")


# ============================================================ west slab (tall, Genex residential tower)
WX0, WX1 = -1176, -1096
ground("Slab W ground", WX0, WX1, 4820, 5180, "WNS")
mass("Slab W lower", WX0, WX1, 4820, 5180, 240, 680,
     {"W": dict(patches=7, balconies=10, laundry=6, ac=3), "E": dict(patches=4, balconies=5, laundry=3, ac=1)})
mass("Slab W upper", WX0, WX1, 4820, 5060, 684, 760,
     {"W": dict(patches=1, balconies=1), "E": dict(patches=1)})
# Genex-style detached service tower in the gate gap, tied to the tall slab by link bridges, wearing the lookout drum
s.group("Service tower")
TX, TZ = -1056, 4850
box(s, TX - 20, TX + 20, G, 780, TZ - 20, TZ + 20, name="Service tower", **WEATH)
box(s, TX - 4, TX + 4, 240, 760, TZ - 20.6, TZ - 20, name="Tower slit N", **WIN)
box(s, TX - 4, TX + 4, 240, 760, TZ + 20, TZ + 20.6, name="Tower slit S", **WIN)
box(s, TX + 20, TX + 20.6, 240, 760, TZ - 4, TZ + 4, name="Tower slit E", **WIN)
for y in (360, 480, 600, 720):
    box(s, WX1, TX - 20, y - 6, y + 6, TZ - 12, TZ + 12, color=CONC_D, name="Tower link")
box(s, TX - 23, TX + 23, 780, 784, TZ - 23, TZ + 23, color=CONC_D, name="Tower cap")
s.group("Drum")
vcyl(s, TX, TZ, 784, 788, 30, color=CONC_D, name="Drum plinth")
vcyl(s, TX, TZ, 788, 808, 64, mat="Glass", color=(90, 120, 140), name="Drum glazing")
vcyl(s, TX, TZ, 808, 814, 72, var="SG Weathered Concrete", color=CONC_L, name="Drum roof")
s.kit("antenna_mast", (TX, 826.5, TZ), scale=0.55)   # 33 tall, sits 4 into the drum roof, top 843

# ============================================================ east slab (cantilevers north over the street)
EX0, EX1 = -936, -856
ground("Slab E ground", EX0, EX1, 4840, 5160, "NS")
mass("Slab E lower", EX0, EX1, 4840, 5160, 240, 556,
     {"W": dict(patches=4, balconies=4, laundry=3, ac=1), "E": dict(patches=4, balconies=4, laundry=3, ac=1)})
mass("Slab E cantilever", EX0, EX1, 4800, 5160, 560, 680,
     {"W": dict(patches=2, balconies=2, laundry=1), "E": dict(patches=2, balconies=1)})

# two chunky corbels carry the cantilever's 40-stud overhang back into the north gable
for x in (EX0 + 14, EX1 - 14):
    s.part("Wedge", (6, 40, 40), (x, 540, 4820), rot=(0, 0, 180), var="SG Weathered Concrete", color=CONC, name="Cantilever corbel")

# ============================================================ gate bridge block
s.group("Gate bridge")
BX0, BX1, BZ0, BZ1 = WX1, EX0, 4970, 5050
box(s, BX0, BX1, 600, 680, BZ0, BZ1, name="Gate body", **WIN)
box(s, BX0, BX1, 594, 600, BZ0 - 3, BZ1 + 3, color=CONC_D, name="Gate soffit")
box(s, BX0 + 9, BX1 - 9, 680, 686, BZ0 - 3, BZ1 + 3, color=CONC_D, name="Gate roof")
for face in (("z", BZ0, -1), ("z", BZ1, 1)):
    for u in (-1056, -1016, -976):
        fbox(face, u - 1.5, u + 1.5, 600, 680, 0, 7, color=CONC_L, name="Gate fin")
    fbox(face, BX0 + 9, BX1 - 9, 638.5, 641.5, 0, 8, color=CONC, name="Gate band")
# estate sign on the gate's north face (small, lit)
fbox(("z", BZ0, -1), -1036, -996, 652, 668, 7, 8, mat="SmoothPlastic", color=(30, 34, 44), name="Gate sign")
fbox(("z", BZ0, -1), -1034, -998, 658, 662, 8, 8.6, mat="Neon", color=(255, 70, 160), name="Gate sign neon")

# ============================================================ east walk-up (deck access, L-shape)
AX0, AX1 = -760, -680
ground("Wing A ground", AX0, AX1, 4820, 5180, "ENS")
mass("Wing A north", AX0, AX1, 4820, 4940, 240, 360,
     {"E": dict(patches=2, balconies=3, laundry=2, ac=1), "W": dict(band_d=12, patches=1)}, gables=("N",))
mass("Wing A south", AX0, AX1, 4940, 5180, 240, 440,
     {"E": dict(patches=4, balconies=5, laundry=3, ac=1), "W": dict(band_d=12, patches=1, ac=1, span=(4940, 5100))})
ground("Wing B ground", -836, AX0, 5100, 5180, "S")
mass("Wing B", -836, AX0, 5100, 5180, 240, 400,
     {"S": dict(patches=2, balconies=3, laundry=2, ac=1), "N": dict(band_d=12, patches=1, span=(-836, -772))}, gables=("W",))

# ============================================================ court under the gate: garages + market
s.group("Gate court")
box(s, -1088, -944, G, 227, 5120, 5170, name="Court garages", **WEATH)
box(s, -1090, -942, 227, 231, 5118, 5172, color=CONC_D, name="Court garages roof")
for u in (-1068, -1036, -1004, -972):
    box(s, u - 14, u + 14, G + 1, G + 22, 5119.2, 5120, mat="Metal", var="Metal Shutters", color=(150, 158, 160), name="Court shutter")
for (x, z) in ((-1060, 4900), (-1020, 4900), (-980, 4900), (-1040, 4960)):
    s.kit("market_stall", (x, 207, z), rot=(0, 0, 0))
s.kit("vending_machine", (-1086, 204.5, 5000), rot=(0, -90, 0))
s.kit("vending_machine", (-1086, 204.5, 5006), rot=(0, -90, 0))
s.kit("bench_concrete", (-1010, 201.5, 5040))
# courtyard of the walk-up: chain-link car pound
s.group("Courtyard")
for k in range(3):
    s.kit("chainlink_fence_20", (-830 + 20 * k + 10, 206, 4850), rot=(0, 0, 0))
for k in range(3):
    s.kit("chainlink_fence_20", (-840, 206, 4860 + 20 * k), rot=(0, 90, 0))
box(s, -830, -770, G, 216, 5040, 5094, name="Courtyard sheds", color=(120, 128, 120), mat="Metal", var="Metal Shutters")

# ============================================================ exterior stair stacks and pipes
s.group("Stairs")
for k in range(5):   # south gable of the east slab, street side
    s.kit("ext_stair_40", (-896, 220 + 40 * k, 5167), rot=(0, 180, 0))
for k in range(4):   # courtyard side of wing A
    s.kit("ext_stair_40", (-760 - 12 - 5, 220 + 40 * k, 4990), rot=(0, 90, 0))
for (x, z, y0, n) in ((-1176 - 1.5, 4830, 240, 12), (-856 + 1.5, 5150, 240, 8), (-680 + 1.5, 4830, 240, 3)):
    # one chunky downpipe per stack (a kit pipe bundle per tile would cost 90 tris x 25)
    box(s, x - 1.5, x + 1.5, y0, y0 + 40 * n - 6, z - 2, z + 2, mat="Metal", color=(90, 95, 98), name="Downpipe")

# ============================================================ gable signs + lower-storey murals
s.group("Gables")
box(s, WX0 + 4, WX1 - 4, 242, 318, 4817.6, 4818, var="SG Graffiti B", color=(200, 200, 200), name="Mural W north gable")
box(s, EX0 + 4, EX1 - 4, 242, 318, 4837.6, 4838, var="SG Graffiti A", color=(200, 200, 200), name="Mural E north gable")
box(s, AX0 + 4, AX1 - 4, 242, 318, 4817.6, 4818, var="SG Graffiti B", color=(200, 200, 200), name="Mural A north gable")
box(s, EX0 + 25, EX1 - 25, 380, 500, 4836, 4837.6, mat="SmoothPlastic", color=(200, 40, 70), name="Vertical sign")
box(s, EX0 + 23, EX0 + 25, 380, 500, 4836.4, 4837.6, mat="Neon", color=(255, 220, 120), name="Sign neon L")
box(s, EX1 - 25, EX1 - 23, 380, 500, 4836.4, 4837.6, mat="Neon", color=(255, 220, 120), name="Sign neon R")

# ============================================================ rooftops
s.group("Roofs")
s.kit("water_tank", (-1150, 775, 5030))
s.kit("rooftop_shack", (-1136, 770, 4850), rot=(0, 90, 0), color=(160, 120, 100))
s.kit("dish_cluster", (-1125, 770, 4960))
# east slab roof village: add-on rooms
for (x, z, ry, c) in ((-920, 4960, 0, (120, 150, 160)), (-900, 4990, 180, (170, 160, 120)), (-918, 5030, 0, (160, 120, 100))):
    s.kit("rooftop_shack", (x, 690, z), rot=(0, ry, 0), color=c)

s.kit("dish_cluster", (-1120, 690, 5120))
s.kit("rooftop_shack", (-1140, 690, 5150), rot=(0, 90, 0))
s.kit("water_tank", (-910, 695, 4860))
s.kit("water_tank", (-880, 695, 4890))
s.kit("rooftop_shack", (-896, 690, 5100), rot=(0, -90, 0), color=(160, 120, 100))
s.kit("antenna_mast", (-880, 714, 5140))
s.kit("dish_cluster", (-1016, 692, 5010))
s.kit("rooftop_shack", (-720, 370, 4870), rot=(0, 90, 0), color=(130, 140, 110))
s.kit("rooftop_shack", (-720, 450, 5000), rot=(0, 90, 0), color=(120, 150, 160))
s.kit("water_tank", (-715, 455, 5140))
s.kit("dish_cluster", (-800, 410, 5140))

st = s.save(HERE / "P08.json")
others = load_elements(HERE / "P07.json") + load_elements(HERE / "XD1.json")
check(s.elements, "P08", others)
