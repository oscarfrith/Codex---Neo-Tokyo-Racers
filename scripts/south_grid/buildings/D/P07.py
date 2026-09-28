"""P07 - "Kōfu Stack" (Metabolist Row lean): six cylindrical service cores on a 160x240 grid carry Tange-style
floor trays that span between them at staggered levels, leaving sky gaps through the lattice. Nakagin capsule
clusters plug into the cores' free lengths. A two-storey market podium with shutters, graffiti and a rooftop
court sits under the lattice. Bridges to P08 are in XD1.py (tube at Y480 from tray N2, truss at Y320 from S1).
Run: py -3 P07.py  (writes P07.json and prints budget + checks)
"""
import random
from dlib import Spec, box, vcyl, check, load_elements, HERE, WHITE, WHITE_D, CONC, CONC_D, CONC_L, PATCH, STEEL

R = random.Random(7)
s = Spec("P07", kind="building", title="Kofu Stack", lean="metabolist")
G = 200

# ---------------------------------------------------------------- cores
CORES = {  # name: (x, z, d, top)
    "C1": (-1700, 4880, 48, 710), "C2": (-1540, 4880, 52, 800), "C3": (-1380, 4880, 40, 600),
    "C4": (-1700, 5120, 40, 556), "C5": (-1540, 5120, 48, 780), "C6": (-1380, 5120, 48, 740),
}
s.group("Cores")
for n, (x, z, d, top) in CORES.items():
    vcyl(s, x, z, G + 10, top, d, var="SG Capsule Panels", color=WHITE, name=f"Core {n}")
    vcyl(s, x, z, top, top + 4, d + 6, color=CONC_D, name=f"Core {n} cap")
    # dark service ring every 160 studs (reads as floor-line of the lift core)
    for y in range(G + 180, top - 40, 160):
        vcyl(s, x, z, y, y + 4, d + 3, color=WHITE_D, name=f"Core {n} ring")

# ---------------------------------------------------------------- trays
def tray(name, x0, x1, z0, z1, y0, y1, var="SG Windows Capsule", mid=True, patches=0):
    s.group(f"Tray {name}")
    box(s, x0 + 4, x1 - 4, y0 + 1, y1 - 1, z0 + 4, z1 - 4, mat="SmoothPlastic", var=var, color=(222, 222, 216), name=f"{name} glazing")
    box(s, x0, x1, y0, y0 + 5, z0, z1, var="SG Capsule Panels", color=WHITE, name=f"{name} tray base")
    box(s, x0, x1, y1 - 5, y1, z0, z1, var="SG Capsule Panels", color=WHITE, name=f"{name} tray roof")
    if mid and y1 - y0 >= 80:
        box(s, x0 + 2, x1 - 2, y0 + 38, y0 + 42, z0 + 2, z1 - 2, var="SG Capsule Panels", color=WHITE_D, name=f"{name} tray mid")
    # patched infill: residents boarded parts of the glazing
    long_x = (x1 - x0) >= (z1 - z0)
    for _ in range(patches):
        c = PATCH[R.randrange(len(PATCH))]
        yb = y0 + 5 if R.random() < 0.5 or y1 - y0 < 80 else y0 + 42
        yt = min(yb + 33, y1 - 5) if y1 - y0 >= 80 else y1 - 5
        if long_x:
            px = x0 + 20 + 40 * R.randrange(int((x1 - x0 - 40) // 40) + 1)
            face = z0 + 4 if R.random() < 0.5 else z1 - 4
            dz = -0.6 if face == z0 + 4 else 0.6
            box(s, px - 16, px + 16, yb, yt, face, face + dz, mat="SmoothPlastic", var="SG Patched Panels", color=c, name=f"{name} patch")
        else:
            pz = z0 + 20 + 40 * R.randrange(int((z1 - z0 - 40) // 40) + 1)
            face = x0 + 4 if R.random() < 0.5 else x1 - 4
            dx = -0.6 if face == x0 + 4 else 0.6
            box(s, face, face + dx, yb, yt, pz - 16, pz + 16, mat="SmoothPlastic", var="SG Patched Panels", color=c, name=f"{name} patch")


NZ, SZ = (4840, 4920), (5080, 5160)
TRAYS = {
    "N1": (-1750, -1500, *NZ, 280, 360),
    "N2": (-1580, -1290, *NZ, 440, 560),     # east end lands bridge tube XD1-a (Y480, z4880)
    "N4": (-1600, -1420, *NZ, 600, 680),     # cantilevers 120 off C2 towards P08
    "N3": (-1760, -1560, *NZ, 560, 600),
    "S1": (-1580, -1290, *SZ, 280, 360),     # east end lands truss XD1-b (Y320, z5120)
    "S2": (-1750, -1500, *SZ, 400, 440),
    "S3": (-1580, -1340, *SZ, 520, 600),
    "S4": (-1720, -1500, 5072, 5168, 560, 640),     # rides on C4's cap, tied to C5
    "W1": (-1740, -1660, 4840, 5160, 440, 520),
    "M1": (-1580, -1500, 4840, 5160, 680, 760),  # high spine carrying the sphere
    "E1": (-1420, -1340, 4840, 5160, 360, 440),
    "E2": (-1420, -1340, 4840, 5160, 680, 720),  # crown spine off C6
}
for n, (x0, x1, z0, z1, y0, y1) in TRAYS.items():
    tray(n, x0, x1, z0, z1, y0, y1, var="SG Windows Blocks" if n in ("S2", "E1", "S4") else "SG Windows Capsule",
         patches={"N1": 3, "S1": 3, "S2": 2, "E1": 2, "N2": 3, "W1": 1, "S4": 2, "N4": 1}.get(n, 0))

# Fuji-TV sphere on the high spine, held in a cradle
s.group("Sphere")
box(s, -1560, -1520, 760, 766, 4980, 5020, var="SG Capsule Panels", color=CONC_L, name="Sphere cradle")
s.part("Ball", (44, 44, 44), (-1540, 788, 5000), mat="Metal", color=(176, 180, 186), name="Sphere")
for dx in (-1, 1):  # two frame posts gripping the ball
    box(s, -1540 + dx * 26 - 3, -1540 + dx * 26 + 3, 766, 810, 4994, 5006, var="SG Capsule Panels", color=WHITE, name="Sphere frame post")
box(s, -1572, -1508, 810, 816, 4994, 5006, var="SG Capsule Panels", color=WHITE, name="Sphere frame lintel")

# ---------------------------------------------------------------- capsule clusters (Nakagin)
DIRS = {"N": ((0, -1), 0), "S": ((0, 1), 180), "W": ((-1, 0), 90), "E": ((1, 0), -90)}
CAPCOL = [(226, 226, 222), (226, 226, 222), (214, 206, 190), (196, 204, 208)]


def cluster(core, y0, n, seq):
    x, z, d, _ = CORES[core]
    r = d / 2
    s.group(f"Capsules {core}")
    for k in range(n):
        (ux, uz), ry = DIRS[seq[k % len(seq)]]
        off = r + 8 - 2
        s.kit("capsule_unit", (x + ux * off, y0 + 6.5 + 13 * k, z + uz * off), rot=(0, ry, 0), color=CAPCOL[R.randrange(4)])


cluster("C1", 617, 6, "WNWWN")        # west face over the open lot / ring road
cluster("C4", 306, 5, "WSWWS")        # below S2, facing the open lot
cluster("C3", 561, 3, "ENEEN")        # towards P08
cluster("C2", 366, 5, "NENN")         # above N2
cluster("C6", 459, 4, "ESEES")        # below S3

# ---------------------------------------------------------------- podium (market hall)
s.group("Podium")
PX0, PX1, PZ0, PZ1 = -1740, -1320, 4810, 5190
box(s, PX0, PX1, G, 240, PZ0, PZ1, var="SG Weathered Concrete", color=CONC, name="Podium")
box(s, PX0 - 2, PX1 + 2, 240, 244, PZ0 - 2, PZ1 + 2, color=CONC_D, name="Podium parapet slab")
# canopies on the street sides
box(s, PX0 + 20, PX1 - 20, 226, 230, PZ0 - 10, PZ0, color=WHITE_D, name="Canopy N")
box(s, PX0 + 20, PX1 - 20, 226, 230, PZ1, PZ1 + 10, color=WHITE_D, name="Canopy S")
box(s, PX1, PX1 + 10, 226, 230, PZ0 + 20, PZ1 - 20, color=WHITE_D, name="Canopy E")
# graffiti on the lower storeys (proud 0.4 so it never z-fights the wall)
box(s, PX0 - 0.4, PX0, 202, 238, PZ0 + 20, PZ1 - 60, var="SG Graffiti A", color=(200, 200, 200), name="Graffiti W")
box(s, PX0 + 20, PX0 + 180, 231, 239, PZ0 - 0.4, PZ0, var="SG Graffiti B", color=(200, 200, 200), name="Graffiti N band")
box(s, PX1 - 180, PX1 - 20, 231, 239, PZ1, PZ1 + 0.4, var="SG Graffiti A", color=(200, 200, 200), name="Graffiti S band")
box(s, PX1, PX1 + 0.4, 231, 239, PZ0 + 20, PZ0 + 140, var="SG Graffiti B", color=(200, 200, 200), name="Graffiti E band")

SIGN = [(255, 70, 160), (60, 230, 255), (255, 190, 60), (140, 255, 120)]


def shopfronts(face, a0, a1):
    """Bays every 40 studs along a podium face: shutter / lit shop / shutter / mural."""
    pattern = ["shop", "shutter", "shop", "shutter", "shutter", "shop", "mural"]
    k = R.randrange(7)
    for a in range(int(a0) + 20, int(a1) - 19, 40):
        kind = pattern[k % 7]; k += 1
        c = a
        if kind == "shop":
            if face == "N":
                box(s, c - 16, c + 16, 202, 222, PZ0 - 0.6, PZ0, mat="Glass", color=(90, 120, 140), name="Shopfront glass")
                box(s, c - 12, c + 12, 223, 226, PZ0 - 0.6, PZ0, mat="Neon", color=SIGN[R.randrange(4)], name="Shop sign strip")
            elif face == "S":
                box(s, c - 16, c + 16, 202, 222, PZ1, PZ1 + 0.6, mat="Glass", color=(90, 120, 140), name="Shopfront glass")
                box(s, c - 12, c + 12, 223, 226, PZ1, PZ1 + 0.6, mat="Neon", color=SIGN[R.randrange(4)], name="Shop sign strip")
            elif face == "E":
                box(s, PX1, PX1 + 0.6, 202, 222, c - 16, c + 16, mat="Glass", color=(90, 120, 140), name="Shopfront glass")
                box(s, PX1, PX1 + 0.6, 223, 226, c - 12, c + 12, mat="Neon", color=SIGN[R.randrange(4)], name="Shop sign strip")
            else:
                box(s, PX0 - 0.6, PX0, 202, 222, c - 16, c + 16, mat="Glass", color=(90, 120, 140), name="Shopfront glass")
        elif kind == "shutter":
            if face == "N":
                box(s, c - 15, c + 15, 202, 222, PZ0 - 0.8, PZ0, mat="Metal", var="Metal Shutters", color=(150, 158, 160), name="Shutter")
            elif face == "S":
                box(s, c - 15, c + 15, 202, 222, PZ1, PZ1 + 0.8, mat="Metal", var="Metal Shutters", color=(150, 158, 160), name="Shutter")
            elif face == "E":
                box(s, PX1, PX1 + 0.8, 202, 222, c - 15, c + 15, mat="Metal", var="Metal Shutters", color=(150, 158, 160), name="Shutter")
        else:  # mural bay
            if face == "N":
                box(s, c - 20, c + 20, 201, 225, PZ0 - 0.4, PZ0, var="SG Graffiti A", color=(200, 200, 200), name="Graffiti bay")
            elif face == "S":
                box(s, c - 20, c + 20, 201, 225, PZ1, PZ1 + 0.4, var="SG Graffiti B", color=(200, 200, 200), name="Graffiti bay")
            elif face == "E":
                box(s, PX1, PX1 + 0.4, 201, 225, c - 20, c + 20, var="SG Graffiti A", color=(200, 200, 200), name="Graffiti bay")


shopfronts("N", PX0 + 20, PX1 - 20)
shopfronts("S", PX0 + 20, PX1 - 20)
shopfronts("E", PZ0 + 20, PZ1 - 20)

# west plaza: street market facing the open lot
s.group("West market")
for z in (4930, 4970, 5010, 5050):
    s.kit("market_stall", (PX0 - 8, 207, z), rot=(0, 90, 0))
for z in (5100, 5108):
    s.kit("vending_machine", (PX0 - 2, 204.5, z), rot=(0, 90, 0))
s.kit("vending_machine", (-1600, 204.5, PZ0 - 2), rot=(0, 0, 0))
s.kit("vending_machine", (-1592, 204.5, PZ0 - 2), rot=(0, 0, 0))

# ---------------------------------------------------------------- podium roof: court, shacks, tanks
s.group("Podium roof")
for i in range(4):  # rooftop ball court cage 80x40 in the lattice's shade
    s.kit("chainlink_fence_20", (-1640 + 20 * i, 250, 4960), rot=(0, 0, 0))
    s.kit("chainlink_fence_20", (-1640 + 20 * i, 250, 5000), rot=(0, 180, 0))
for z in (4970, 4990):
    s.kit("chainlink_fence_20", (-1650.5, 250, z), rot=(0, 90, 0))
    s.kit("chainlink_fence_20", (-1569.5, 250, z), rot=(0, -90, 0))
box(s, -1650, -1570, 244, 244.6, 4960.5, 4999.5, mat="Concrete", color=(96, 128, 140), name="Court surface")
for (x, z, ry) in ((-1720, 4990, 90), (-1460, 5010, -90), (-1470, 4960, -90), (-1360, 5000, -90)):
    s.kit("rooftop_shack", (x, 250, z), rot=(0, ry, 0), color=[(120, 150, 160), (160, 120, 100), (130, 140, 110)][R.randrange(3)])
s.kit("water_tank", (-1440, 255, 5040))
for (x, z, ry) in ((-1720, 4840, 0), (-1700, 5170, 180), (-1640, 5150, 180), (-1480, 4840, 0), (-1420, 4840, 0),
                   (-1340, 5160, -90), (-1600, 4840, 0), (-1560, 5160, 180)):
    s.kit("rooftop_shack", (x, 250, z), rot=(0, ry, 0), color=[(120, 150, 160), (160, 120, 100), (130, 140, 110), (170, 160, 120)][R.randrange(4)])
s.kit("water_tank", (-1690, 255, 5030))
for k in range(3):  # steel stair from the podium roof up to the E1 spine
    s.kit("ext_stair_40", (-1335, 264 + 40 * k, 4990), rot=(0, -90, 0))

# ---------------------------------------------------------------- tray-top clutter
s.group("Roof clutter")
s.kit("water_tank", (-1330, 571, 4880))          # N2 roof, east end
s.kit("dish_cluster", (-1480, 566, 4900))
s.kit("rooftop_shack", (-1740, 366, 4880), rot=(0, 90, 0))   # N1 roof
s.kit("rooftop_shack", (-1320, 366, 5125), rot=(0, -90, 0))  # S1 roof
s.kit("water_tank", (-1440, 371, 5130))
s.kit("dish_cluster", (-1735, 446, 5120))                      # S2 roof
s.kit("rooftop_shack", (-1380, 446, 4990), rot=(0, -90, 0))  # E1 roof
s.kit("water_tank", (-1700, 531, 4990))                        # W1 roof
s.kit("rooftop_shack", (-1745, 606, 4905), rot=(0, 90, 0))    # N3 roof (tucked behind capsules)
# masts and tanks on the core tops
s.kit("dish_cluster", (-1540, 810, 4880))    # C2 (cap 804)
s.kit("antenna_mast", (-1700, 744, 4880))   # C1 (cap 714)
s.kit("water_tank", (-1380, 615, 4880))     # C3
s.kit("water_tank", (-1540, 795, 5120))     # C5 (cap 784)
s.kit("antenna_mast", (-1380, 774, 5120))   # C6 (cap 744)

# ---------------------------------------------------------------- laundry + AC on the residential trays
s.group("Laundry")
def laundry_x(x, y, zface, front):
    s.kit("laundry_line_36", (x, y, zface + (-0.6 if front < 0 else 0.6)), rot=(0, 0 if front < 0 else 180, 0),
          color=PATCH[R.randrange(len(PATCH))])
for x in (-1710, -1630, -1550):
    laundry_x(x, 352 - 5, 4844, -1)         # N1 north face
for x in (-1540, -1460, -1380):
    laundry_x(x, 352 - 5, 5156, 1)          # S1 south face
for x in (-1700, -1620, -1540):
    laundry_x(x, 432 - 5, 5156, 1)          # S2 south face
laundry_x(-1520, 552 - 5, 4844, -1)
laundry_x(-1400, 552 - 5, 4844, -1)
laundry_x(-1660, 632 - 5, 5156, 1)
laundry_x(-1500, 672 - 5, 4844, -1)
s.group("AC")
for (x, y, z) in ((-1680, 330, 4844), (-1600, 300, 4844), (-1500, 310, 5156), (-1420, 420, 5156), (-1480, 490, 4844),
                  (-1330, 470, 4844), (-1560, 560, 5156)):
    s.kit("ac_cluster", (x, y, z + (-2 if z < 5000 else 2)), rot=(0, 0 if z < 5000 else 180, 0))
for (x, y, z) in ((-1416, 400, 4960), (-1416, 380, 5040)):
    s.kit("ac_cluster", (x - 2, y, z), rot=(0, 90, 0))

st = s.save(HERE / "P07.json")
others = load_elements(HERE / "P08.json") + load_elements(HERE / "XD1.json")
check(s.elements, "P07", others)
