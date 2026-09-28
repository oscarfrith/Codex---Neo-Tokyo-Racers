"""P05: HARBOUR STACK - hybrid (The Blocks x Metabolist), waterfront east end of Row 1. Ground Y100.
N1: 21-storey waterfront balcony slab along the harbour edge (north).
W1: 34-storey north-south balcony slab on the west road; its south end wall takes bridge X6 to The Beacon.
M1: Metabolist capsule stack in the east courtyard: one board-marked core, woven porthole trays (alternating
    axes, two void levels with plug-in capsules), sphere crown in a ring frame. Tube bridge to W1.
Run: python P05.py  -> P05.json
"""
import pathlib
from _cb import *  # noqa: F401,F403

OUT = pathlib.Path(__file__).resolve().parent / "P05.json"
s = Spec("P05", kind="building", title="Harbour Stack", lean="hybrid")
G = 100.0

# ------------------------------------------------------------------ N1 waterfront slab
NX0, NX1, NZ0, NZ1 = 1360, 1740, 4106, 4180
NT = G + 21 * ST  # 380
s.group("N1 waterfront slab")
box(s, NX0 + 12, NX1 - 12, G, G + 2 * ST, NZ0 + 8, NZ1 - 6, SHUT, name="Garage shutters")
for x in grid(NX0, NX1, 76):
    box(s, x - 4, x + 4, G, G + 2 * ST, NZ0, NZ0 + 8, BOARD_D, name="Garage pier")
box(s, NX0 + 12, NX1 - 12, G + 2 * ST, G + 5 * ST, NZ0, NZ1, GRAF_A, name="Mural band")
SX = 1560                 # N1 steps down east of the stair tower
NT2 = G + 15 * ST          # 300: lower east half with a rooftop cage court
box(s, NX0 + 12, SX, G + 5 * ST, NT, NZ0 + 4, NZ1 - 4, WIN, name="Waterfront flats")
box(s, SX, NX1 - 12, G + 5 * ST, NT2, NZ0 + 4, NZ1 - 4, WIN, name="Waterfront flats low")
plates(s, NX0 + 12, NX1 - 12, NZ0 - 5, NZ1 + 5, levels(G + 5 * ST, NT2 - 2))
plates(s, NX0 + 12, SX, NZ0 - 5, NZ1 + 5, levels(G + 5 * ST, NT - 2)[len(levels(G + 5 * ST, NT2 - 2)):])
fins_x(s, [x for x in grid(NX0 + 12, NX1 - 12, 44) if x < SX - 10], G + 5 * ST, NT, NZ0 - 5, NZ0 + 4)
fins_x(s, [x for x in grid(NX0 + 12, NX1 - 12, 44) if x > SX + 10], G + 5 * ST, NT2, NZ0 - 5, NZ0 + 4)
box(s, SX - 4, SX + 6, NT2, NT + 6, NZ0 - 6, NZ1 + 6, BOARD, name="Step wall")
box(s, NX0, NX0 + 12, G, NT + 6, NZ0 - 6, NZ1 + 6, BOARD, name="West end wall")
box(s, NX1 - 12, NX1, G, NT2 + 6, NZ0 - 6, NZ1 + 6, BOARD, name="East end wall")
box(s, NX1, NX1 + 2, G, G + 12 * ST, NZ0 - 6, NZ1 + 6, GRAF_B, name="East end mural")
box(s, NX0 - 2, SX + 6, NT, NT + 5, NZ0 - 7, NZ1 + 7, CONC, name="Roof edge")
box(s, SX, NX1 + 2, NT2, NT2 + 5, NZ0 - 7, NZ1 + 7, CONC, name="Roof edge low")
# exterior stair tower on the harbour face at the step
box(s, SX - 16, SX + 16, G, NT + 14, NZ0 - 18, NZ0 - 4, BOARD_D, name="Harbour stair tower")
box(s, SX - 18, SX + 18, G, G + 6 * ST, NZ0 - 20, NZ0 - 4, GRAF_A, name="Stair tower mural")
box(s, SX - 5, SX + 5, G + 7 * ST, NT + 4, NZ0 - 19, NZ0 - 18, GLASS, name="Stair slot")
# rooftop cage court on the low roof
box(s, SX + 20, NX1 - 20, NT2 + 5, NT2 + 6, NZ0 + 6, NZ1 - 6, ("Concrete", "", (78, 128, 92)), name="Rooftop court")
for i in range(7):
    s.kit("chainlink_fence_20", (SX + 30 + i * 20, NT2 + 11, NZ0 + 5), layer="LOD3")
    s.kit("chainlink_fence_20", (SX + 30 + i * 20, NT2 + 11, NZ1 - 5), layer="LOD3")
for x, c in ((1420, (255, 60, 200)), (1560, (80, 255, 120)), (1650, (60, 220, 255))):
    neon(s, x - 10, x + 10, G + 2 * ST - 6, G + 2 * ST - 2, NZ0 - 1, NZ0, c, name="Shop sign")
s.group("N1 life")
for x in (1400, 1450, 1520):
    s.kit("water_tank", (x, NT + 16, 4150), layer="LOD3")
s.kit("rooftop_shack", (1460, NT + 11, 4130), layer="LOD3")
s.kit("dish_cluster", (1490, NT + 11, 4130), layer="LOD2")
s.kit("dish_cluster", (1712, NT2 + 11, 4125), layer="LOD2")
nl = levels(G + 5 * ST, NT - 2)
nb = [NX0 + 12 + 22 + 44 * i for i in range(8)]
for bi, li in ((0, 1), (2, 3), (5, 2), (7, 5), (3, 7), (1, 9), (6, 8), (3, 4), (2, 14), (0, 12)):
    s.kit("laundry_line_36", (nb[bi], nl[li] + ST - 3.5, NZ0 - 5.5), layer="LOD2")
for bi, li in ((1, 2), (4, 4), (6, 7), (0, 10), (3, 12), (7, 8)):
    s.kit("ac_cluster", (nb[bi], nl[li] + 6, NZ1 + 7), rot=(0, 180, 0), layer="LOD2")
for z in (4125, 4160):
    s.kit("pipe_bundle_40", (NX1 + 3.5, G + 150, z), rot=(0, -90, 0), layer="LOD2")

# ------------------------------------------------------------------ W1 north-south slab (X6 lands on its south end)
WX0, WX1, WZ0, WZ1 = 1386, 1466, 4226, 4556
WT = G + 34 * ST  # ~553
s.group("W1 west slab")
box(s, WX0 + 6, WX1 - 6, G, G + 2 * ST, WZ0 + 12, WZ1 - 12, SHUT, name="Garage shutters")
box(s, WX0, WX1, G + 2 * ST, G + 5 * ST, WZ0 + 12, WZ1 - 12, GRAF_A, name="Mural band")
box(s, WX0 + 4, WX1 - 4, G + 5 * ST, WT, WZ0 + 12, WZ1 - 12, WIN, name="West flats")
plates(s, WX0 - 9, WX1 + 9, WZ0 + 12, WZ1 - 12, levels(G + 5 * ST, WT - 2))
fins_z(s, grid(WZ0 + 12, WZ1 - 12), G + 5 * ST, WT, WX0 - 9, WX0 + 4)
fins_z(s, grid(WZ0 + 12, WZ1 - 12, 80), G + 5 * ST, WT, WX1 - 4, WX1 + 9)
box(s, WX0 - 10, WX1 + 10, G, WT + 6, WZ0, WZ0 + 12, BOARD, name="North end wall")
box(s, WX0 - 10, WX1 + 10, G, WT + 6, WZ1 - 12, WZ1, BOARD, name="South end wall")
box(s, WX0 - 10, WX1 + 10, G, G + 10 * ST, WZ1, WZ1 + 2, GRAF_B, name="South end mural")
box(s, WX0 - 12, WX1 + 12, WT, WT + 6, WZ0 - 2, WZ1 + 2, CONC, name="Roof edge")
box(s, 1400, 1452, WT + 6, WT + 26, 4330, 4450, BOARD_D, name="Lift motor room")
# deck-access links N1 <-> W1 across the passage (every six storeys)
for y in (G + 8 * ST, G + 14 * ST, G + 20 * ST - 12):
    box(s, 1398, 1454, y, y + 11, NZ1 + 5, WZ0, CONC, name="Deck link")
    box(s, 1400, 1452, y + 4, y + 8, NZ1 + 4, WZ0 + 1, GLASS, name="Deck link glazing")
s.group("W1 life")
for x, z in ((1426, 4290), (1426, 4500)):
    s.kit("water_tank", (x, WT + 17, z), layer="LOD3")
s.kit("antenna_mast", (1440, WT + 36, 4270), layer="LOD3")
s.kit("dish_cluster", (1410, WT + 12, 4480), layer="LOD2")
s.kit("rooftop_shack", (1426, WT + 12, 4525), rot=(0, 90, 0), layer="LOD3")
wl = levels(G + 5 * ST, WT - 2)
wb = [WZ0 + 12 + 20 + 40 * i for i in range(7)]
for bi, li in ((0, 2), (2, 4), (4, 1), (6, 6), (1, 9), (3, 12), (5, 15), (0, 18), (2, 21), (4, 24), (6, 27), (1, 28)):
    s.kit("laundry_line_36", (WX0 - 9.5, wl[li] + ST - 3.5, wb[bi]), rot=(0, 90, 0), layer="LOD2")
for bi, li in ((1, 3), (3, 6), (5, 9), (0, 13), (2, 17), (4, 14), (6, 23), (3, 26)):
    s.kit("ac_cluster", (WX1 + 11, wl[li] + 6, wb[bi]), rot=(0, -90, 0), layer="LOD2")
s.kit("ext_stair_40", (WX0 - 17, G + 20, 4250), rot=(0, 90, 0), layer="LOD3")
s.kit("ext_stair_40", (WX0 - 17, G + 60, 4250), rot=(0, 90, 0), layer="LOD3")

# ------------------------------------------------------------------ S1 low south slab (closes the courtyard, faces the step)
SX0, SX1, SZ0, SZ1 = 1484, 1744, 4506, 4556
STP = G + 15 * ST  # 300
s.group("S1 south slab")
box(s, SX0 + 12, SX1 - 12, G, G + 2 * ST, SZ0 + 6, SZ1 - 8, SHUT, name="Lock-up shutters")
box(s, SX0 + 12, SX1 - 12, G + 2 * ST, G + 5 * ST, SZ0, SZ1, GRAF_A, name="Mural band")
box(s, SX0 + 12, SX1 - 12, G + 5 * ST, STP, SZ0 + 4, SZ1 - 4, WIN, name="South flats")
plates(s, SX0 + 12, SX1 - 12, SZ0 - 5, SZ1 + 5, levels(G + 5 * ST, STP - 2))
fins_x(s, grid(SX0 + 12, SX1 - 12), G + 5 * ST, STP, SZ1 - 4, SZ1 + 5)
box(s, SX0, SX0 + 12, G, STP + 6, SZ0 - 6, SZ1 + 6, BOARD, name="West end wall")
box(s, SX1 - 12, SX1, G, STP + 6, SZ0 - 6, SZ1 + 6, BOARD, name="East end wall")
box(s, SX0 - 2, SX1 + 2, STP, STP + 5, SZ0 - 7, SZ1 + 7, CONC, name="Roof edge")
sl = levels(G + 5 * ST, STP - 2)
for x, li in ((1516, 1), (1596, 4), (1676, 2), (1556, 7), (1636, 8)):
    s.kit("laundry_line_36", (x, sl[li] + ST - 3.5, SZ1 + 5.5), rot=(0, 180, 0), layer="LOD2")
for x, li in ((1536, 3), (1656, 6)):
    s.kit("ac_cluster", (x, sl[li] + 6, SZ0 - 7), layer="LOD2")
for x in (1540, 1690):
    s.kit("water_tank", (x, STP + 16, 4531), layer="LOD3")

# ------------------------------------------------------------------ M1 Metabolist capsule stack
MX, MZ = 1640, 4430
MR = 22                  # core radius
s.group("M1 capsule stack")
box(s, 1580, 1700, G, G + 2 * ST, 4376, 4484, SHUT, name="Market hall shutters")
box(s, 1576, 1704, G + 2 * ST, G + 5 * ST, 4372, 4488, GRAF_B, name="Market hall mural")
box(s, 1570, 1710, G + 5 * ST, G + 5 * ST + 6, 4366, 4494, CAPS, name="Market hall tray")
s.part("Cylinder", (590, 2 * MR, 2 * MR), (MX, G + 295, MZ), rot=(0, 0, 90), mat=BOARD[0], var=BOARD[1],
       color=BOARD[2], name="Core")
TR0 = G + 5 * ST + 6     # first tray level ~172.7
trays = []
for k in range(12):
    y = TR0 + 40 * k
    if k in (4, 8):
        trays.append(None)
        continue
    f = 1.0 - 0.3 * k / 11.0   # trays taper towards the crown
    tw, td = round(120 * f / 4) * 4, round(66 * f / 2) * 2
    rot = (0, 0 if k % 2 == 0 else 90, 0)
    s.part("Block", (tw + 10, 5, td + 10), (MX, y + 2.5, MZ), rot=rot, mat=CAPS[0], var=CAPS[1], color=CAPS[2], name="Tray slab")
    s.part("Block", (tw, 30, td), (MX, y + 20, MZ), rot=rot, mat=WINC[0], var=WINC[1], color=WINC[2], name="Porthole tray")
    trays.append((y, tw, td))
yv = [TR0 + 40 * k for k in (4, 8)]
# plug-in capsules on the core at the void levels + one at each tray end on alternate levels
for y in yv:
    for ang, (dx, dz) in ((0, (0, -1)), (180, (0, 1)), (90, (-1, 0)), (-90, (1, 0))):
        for dy in (8, 26):
            s.kit("capsule_unit", (MX + dx * (MR + 7), y + dy, MZ + dz * (MR + 7)), rot=(0, ang, 0))
for k, tr in enumerate(trays):
    if tr is None or k % 3 != 1:
        continue
    y, tw, td = tr
    half = (td if k % 2 == 0 else tw) / 2   # extent along z
    for sgn, ang in ((-1, 0), (1, 180)):
        s.kit("capsule_unit", (MX, y + 20, MZ + sgn * (half + 8)), rot=(0, ang, 0))

# sphere crown held in a ring frame (Fuji TV nod), top <= 700
yc = TR0 + 40 * 12        # ~652.7
s.part("Block", (70, 4, 70), (MX, yc + 2, MZ), mat=CAPS[0], var=CAPS[1], color=CAPS[2], name="Crown deck")
s.part("Ball", (40, 40, 40), (MX, yc + 24, MZ), mat="Metal", color=(196, 200, 204), name="Crown sphere")
box(s, MX - 34, MX - 28, yc, yc + 44, MZ - 3, MZ + 3, CAPS, name="Sphere frame")
box(s, MX + 28, MX + 34, yc, yc + 44, MZ - 3, MZ + 3, CAPS, name="Sphere frame")
box(s, MX - 34, MX + 34, yc + 40, yc + 44, MZ - 3, MZ + 3, CAPS, name="Sphere frame")
neon(s, MX - 35, MX + 35, yc + 4, yc + 5, MZ - 35, MZ + 35, (60, 220, 255), name="Crown neon")
# tube bridge to W1 at a tray level
yt = TR0 + 40 * 6 + 20
for x in (1495, 1535, 1575):
    s.kit("bridge_tube_40", (x, yt, MZ))
s.group("Courtyard")
for x, z in ((1520, 4260), (1545, 4260)):
    s.kit("market_stall", (x, G + 7, z), layer="LOD2")
s.kit("market_stall", (1640, G + 7, 4360), layer="LOD2")
for x in (1600, 1606, 1612):
    s.kit("vending_machine", (x, G + 4.5, 4372), layer="LOD2")

s.save(OUT)
