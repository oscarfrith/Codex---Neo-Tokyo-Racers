"""P12 + P06: THE BEACON - South Grid landmark (The Blocks, Trellick / Western City Gate type).
Podium (P12 blockout) + 36-storey balcony slab (where P06 stood) + detached lift/stair core linked by
enclosed skybridges every third floor, cantilevered boiler-house crown with lattice mast and red beacon.
East wing: 13-storey deck-access slab over lock-up garages. Ground Y200.
Run: python P12.py  -> P12.json
"""
import pathlib
from _cb import *  # noqa: F401,F403

OUT = pathlib.Path(__file__).resolve().parent / "P12.json"
s = Spec("P12", kind="building", title="The Beacon (P12 podium + P06 tower)", lean="blocks")
G = 200.0

# ------------------------------------------------------------------ podium
PX0, PX1, PZ0, PZ1 = 1170, 1510, 4800, 5200
PTOP = G + 15 * ST  # 400
s.group("Podium")
# ground floor: pit garages / lock-ups behind a 8-stud colonnade line
box(s, PX0 + 8, PX1 - 8, G, G + 2 * ST, PZ0 + 8, PZ1 - 8, SHUT, name="Garage shutters")
for x, z in ((PX0, PZ0), (PX1, PZ0), (PX0, PZ1), (PX1, PZ1)):
    box(s, x - 8, x + 8, G, G + 2 * ST, z - 8, z + 8, BOARD_D, name="Corner pier")
for x in grid(PX0, PX1, 80):
    box(s, x - 4, x + 4, G, G + 2 * ST, PZ0 - 2, PZ0 + 8, BOARD_D, name="Garage pier")
    box(s, x - 4, x + 4, G, G + 2 * ST, PZ1 - 8, PZ1 + 2, BOARD_D, name="Garage pier")
# colour-bombed deck storeys (3) wrapping all four faces
box(s, PX0, PX1, G + 2 * ST, G + 5 * ST, PZ0, PZ1, GRAF_A, name="Mural band")
box(s, PX0 - 2, PX1 + 2, G + 5 * ST, G + 5 * ST + 3, PZ0 - 2, PZ1 + 2, CONC_D, name="Deck edge")
# flats: window wall + wrap-around balcony trays + fins
box(s, PX0 + 4, PX1 - 4, G + 5 * ST, PTOP, PZ0 + 4, PZ1 - 4, WIN, name="Podium flats")
plates(s, PX0 - 5, PX1 + 5, PZ0 - 5, PZ1 + 5, levels(G + 6 * ST, PTOP - 2))
fins_x(s, [x for x in grid(PX0 + 4, PX1 - 4) if abs(x - 1450) > 20], G + 5 * ST + 3, PTOP, PZ0 - 5, PZ0 + 4)  # X6 lands at x=1450
fins_x(s, grid(PX0 + 4, PX1 - 4), G + 5 * ST + 3, PTOP, PZ1 - 4, PZ1 + 5)
fins_z(s, grid(PZ0 + 4, PZ1 - 4), G + 5 * ST + 3, PTOP, PX0 - 5, PX0 + 4)
box(s, PX0 - 6, PX1 + 6, PTOP, PTOP + 5, PZ0 - 6, PZ1 + 6, CONC, name="Podium roof edge")
# neon garage signs (small)
for x, c in ((1230, (255, 60, 200)), (1330, (80, 255, 120)), (1410, (60, 220, 255))):
    neon(s, x - 10, x + 10, G + 2 * ST - 6, G + 2 * ST - 2, PZ0 - 3, PZ0 - 2, c, name="Garage sign")
neon(s, PX0 - 3, PX0 - 2, G + 2 * ST - 6, G + 2 * ST - 2, 4990, 5010, (255, 150, 40), name="Garage sign")
s.group("Podium roof")
# rooftop football cage on the north terrace
box(s, 1200, 1320, PTOP + 5, PTOP + 6, 4815, 4870, ("Concrete", "", (78, 128, 92)), name="Rooftop court")
for i in range(6):
    s.kit("chainlink_fence_20", (1210 + i * 20, PTOP + 11, 4813), layer="LOD3")
    s.kit("chainlink_fence_20", (1210 + i * 20, PTOP + 11, 4872), layer="LOD3")
for x, z in ((1360, 4830), (1390, 4830), (1210, 5170), (1240, 5170), (1470, 5160)):
    s.kit("water_tank", (x, PTOP + 16, z), layer="LOD3")
for x, z, r in ((1300, 5010, 0), (1420, 5040, 90), (1210, 5060, 0)):
    s.kit("rooftop_shack", (x, PTOP + 11, z), rot=(0, r, 0), layer="LOD3")
for x, z in ((1350, 5150), (1440, 4840), (1260, 5120)):
    s.kit("dish_cluster", (x, PTOP + 11, z), layer="LOD2")
for x, z in ((1330, 5090), (1380, 5100)):
    s.kit("laundry_line_36", (x, PTOP + 12, z), layer="LOD2")

s.group("Podium life")
PL = levels(G + 6 * ST, PTOP - 2)          # podium balcony levels (10)
for x, li in ((1234, 1), (1314, 3), (1394, 0), (1274, 5), (1354, 7), (1194, 8), (1474, 2), (1414, 6)):
    s.kit("laundry_line_36", (x, PL[li] + ST - 3.5, PZ0 - 5.5), layer="LOD2")
for z, li in ((4864, 2), (5024, 4), (5104, 1), (4904, 7), (5144, 6), (5064, 8)):
    s.kit("laundry_line_36", (PX0 - 5.5, PL[li] + ST - 3.5, z), rot=(0, 90, 0), layer="LOD2")
for x, li in ((1214, 2), (1294, 5), (1374, 1), (1454, 7), (1254, 8), (1334, 3), (1414, 4), (1494, 6)):
    s.kit("ac_cluster", (x, PL[li] + 6, PZ1 + 7), rot=(0, 180, 0), layer="LOD2")
for y in (G + 5 * ST + 20, G + 5 * ST + 60, G + 5 * ST + 100):
    s.kit("pipe_bundle_40", (PX1 + 5.5, y, 5180), rot=(0, -90, 0), layer="LOD2")

# ------------------------------------------------------------------ tower slab (where P06 stood)
TX0, TX1, TZ0, TZ1 = 1250, 1490, 4880, 4970
TB = PTOP + 5               # slab starts on the podium roof
TT = TB + 1 * ST + 34 * ST  # 34 storeys over an open pilotis floor -> ~858
s.group("Tower slab")
for x in (1290, 1370, 1450):
    box(s, x - 4, x + 4, TB, TB + ST, TZ0 + 8, TZ1 - 8, BOARD_D, name="Pilotis wall")
box(s, TX0, TX0 + 12, TB, TT + 6, TZ0 - 10, TZ1 + 10, BOARD, name="West end wall")
box(s, TX1 - 12, TX1, TB, TT + 6, TZ0 - 10, TZ1 + 10, BOARD, name="East end wall")
box(s, TX0 - 2, TX0, TB, TB + 12 * ST, TZ0 - 10, TZ1 + 10, GRAF_B, name="End wall mural")
N_LEV = levels(TB + ST, TT - 2)
V0, V1 = N_LEV[22], N_LEV[22] + 2 * ST   # two-storey sky-street void (communal deck) two thirds up
box(s, TX0 + 12, TX1 - 12, TB + ST, V0, TZ0, TZ1, WIN, name="Slab flats")
box(s, TX0 + 12, TX1 - 12, V1, TT, TZ0, TZ1, WIN, name="Slab flats upper")
box(s, TX0 + 12, TX1 - 12, V0, V1, TZ0 + 12, TZ1 - 12, GLASS, name="Sky street glazing")
box(s, TX0 + 12, TX1 - 12, V0, V0 + 4, TZ0 - 10, TZ1 + 9, CONC_D, name="Sky street deck")
box(s, TX0 + 12, TX1 - 12, V1 - 4, V1, TZ0 - 10, TZ1 + 9, CONC_D, name="Sky street soffit")
neon(s, TX0 + 12, TX1 - 12, V1 - 5, V1 - 4, TZ0 - 10, TZ0 - 9, (255, 170, 60), name="Sky street light")
plates(s, TX0 + 12, TX1 - 12, TZ0 - 9, TZ0 + 3, [y for y in N_LEV if not (V0 - 1 < y < V1 + 1)])
fins_x(s, grid(TX0 + 12, TX1 - 12), TB + ST, TT, TZ0 - 9, TZ0)
# south face: skip-floor access decks every third storey (Trellick corridor rhythm)
S_LEV = levels(TB + ST, TT - 2, every=3, start=1)
plates(s, TX0 + 12, TX1 - 12, TZ1 - 3, TZ1 + 8, [y for y in S_LEV if not (V0 - 1 < y < V1 + 1)], h=3.5, m=CONC, name="Access deck")
box(s, TX0 - 2, TX1 + 2, TT, TT + 6, TZ0 - 11, TZ1 + 11, CONC, name="Slab roof edge")
box(s, 1300, 1440, TT + 6, TT + 26, 4900, 4950, BOARD_D, name="Plant room")
s.group("Tower life")
for x, z in ((1330, 4925), (1410, 4925)):
    s.kit("water_tank", (x, TT + 37, z), layer="LOD3")
s.kit("dish_cluster", (1275, TT + 12, 4925), layer="LOD2")
s.kit("antenna_mast", (1270, TT + 36, 4955), layer="LOD3")
bays = [TX0 + 12 + 20 + 40 * i for i in range(6)]
pick = [(0, 2), (3, 4), (5, 7), (1, 9), (4, 12), (2, 15), (5, 18), (0, 21), (3, 24), (1, 27), (4, 30), (2, 32)]
for bi, li in pick:
    s.kit("laundry_line_36", (bays[bi], N_LEV[li] + ST - 3.5, TZ0 - 9.5), layer="LOD2")
for bi, li in ((0, 4), (2, 7), (4, 10), (5, 13), (1, 16), (3, 19), (5, 20), (0, 25), (2, 28), (4, 31)):
    s.kit("ac_cluster", (bays[bi], N_LEV[li] + 6, TZ1 + 2), rot=(0, 180, 0), layer="LOD2")
for z in (4900, 4950):
    s.kit("pipe_bundle_40", (TX0 - 3.5, TB + 200, z), rot=(0, 90, 0), layer="LOD2")

# ------------------------------------------------------------------ west stair tower: receives X3 (from P11, owner F)
WX0, WX1, WZ0, WZ1 = 1150, 1194, 4936, 4984
WT = G + 25 * ST  # ~533
s.group("West stair tower")
box(s, WX0, WX1, G, WT, WZ0, WZ1, BOARD, name="Stair tower")
box(s, WX0 - 2, WX1 + 2, G, G + 8 * ST, WZ0 - 2, WZ1 + 2, GRAF_A, name="Stair tower mural")
box(s, WX0 - 1, WX0, G + 9 * ST, WT - 14, 4954, 4966, GLASS, name="Stair slot")
# X3 landing: deck lip at x=1146 (deck top 470) + dark opening in the west face
box(s, 1146, WX0, 462, 470, 4946, 4974, CONC_D, name="X3 landing lip")
box(s, WX0 - 0.5, WX0 + 1, 470, 490, 4950, 4970, DARK, name="X3 landing opening")
neon(s, 1146, 1147, 492, 493, 4948, 4972, (255, 150, 40), name="X3 landing light")
box(s, WX0 - 3, WX1 + 3, WT, WT + 4, WZ0 - 3, WZ1 + 3, CONC_D, name="Stair tower cap")
# deck-access bridge from the stair tower to the slab west end
box(s, WX1, TX0, G + 21 * ST, G + 21 * ST + 11, 4948, 4972, CONC, name="West link")
box(s, WX1 + 2, TX0 - 2, G + 21 * ST + 4, G + 21 * ST + 8, 4947, 4973, GLASS, name="West link glazing")
s.kit("water_tank", (1172, WT + 15, 4960), layer="LOD3")

# ------------------------------------------------------------------ detached service core + skybridges
CX0, CX1, CZ0, CZ1 = 1530, 1580, 4900, 4950
CT = 876
s.group("Service core")
box(s, CX0, CX1, G, CT, CZ0, CZ1, BOARD, name="Core shaft")
box(s, CX0 - 2, CX1 + 2, G, G + 5 * ST, CZ0 - 2, CZ1 + 2, GRAF_B, name="Core mural")
box(s, 1549, 1561, G + 6 * ST, CT - 20, CZ0 - 1, CZ0, GLASS, name="Stair slot")
box(s, 1549, 1561, G + 6 * ST, CT - 20, CZ1, CZ1 + 1, GLASS, name="Stair slot")
box(s, CX1, CX1 + 1, G + 6 * ST, CT - 20, 4919, 4931, GLASS, name="Lift slot")
neon(s, CX0 - 1, CX0, G + 5 * ST, CT - 12, CZ0 - 1, CZ0, (255, 120, 40), name="Core edge neon")
neon(s, CX1, CX1 + 1, G + 5 * ST, CT - 12, CZ0 - 1, CZ0, (255, 120, 40), name="Core edge neon")
box(s, CX0 - 10, CX1 + 10, G + 2 * ST, G + 2 * ST + 3, CZ0 - 14, CZ0, CONC_D, name="Core entrance canopy")
for y in range(260, 820, 80):
    s.kit("pipe_bundle_40", (CX1 + 1.5, y + 20, 4940), rot=(0, -90, 0), layer="LOD2")
# skybridges at the access-deck levels (every third storey) + a two-storey top link
for y in S_LEV[:-1]:
    box(s, TX1, CX0, y, y + 11, 4912, 4938, CONC, name="Skybridge")
    box(s, TX1 + 2, CX0 - 2, y + 4, y + 8, 4911, 4939, GLASS, name="Skybridge glazing")
yl = S_LEV[-1]
box(s, TX1, CX0, yl - 2, TT, 4904, 4946, BOARD, name="Top link")
box(s, TX1 + 2, CX0 - 2, yl + 6, TT - 6, 4903, 4947, GLASS, name="Top link glazing")
# boiler-house crown: cantilevered box on corbels, fins, neon ring, lattice mast + beacon
s.group("Crown")
KX0, KX1, KZ0, KZ1 = 1505, 1605, 4875, 4975
KB, KT = 872, 918
box(s, KX0, KX1, KB, KT, KZ0, KZ1, BOARD, name="Boiler house")
def corbel(x0, x1, z0, z1, ry, name):
    sx, sz = (x1 - x0, z1 - z0) if ry in (0, 180) else (z1 - z0, x1 - x0)
    s.part("Wedge", (sx, 26, sz), ((x0 + x1) / 2, KB - 13, (z0 + z1) / 2), rot=(180, ry, 0),
           mat=BOARD_D[0], var=BOARD_D[1], color=BOARD_D[2], name=name)
corbel(CX0, CX1, KZ0, CZ0, 180, "Crown corbel N")
corbel(CX0, CX1, CZ1, KZ1, 0, "Crown corbel S")
corbel(KX0, CX0, CZ0, CZ1, -90, "Crown corbel W")
corbel(CX1, KX1, CZ0, CZ1, 90, "Crown corbel E")
neon(s, KX0 - 1, KX1 + 1, KB + 3, KB + 4, KZ0 - 1, KZ1 + 1, (255, 60, 40), name="Crown neon ring")
for (x, z, r) in ((1535, KZ0 - 2.5, 0), (1575, KZ0 - 2.5, 0), (1535, KZ1 + 2.5, 180), (1575, KZ1 + 2.5, 180),
                  (KX0 - 2.5, 4905, 90), (KX0 - 2.5, 4945, 90), (KX1 + 2.5, 4905, -90), (KX1 + 2.5, 4945, -90)):
    s.kit("louvre_fins_40", (x, KB + 24, z), rot=(0, r, 0))
box(s, KX0 - 3, KX1 + 3, KT, KT + 4, KZ0 - 3, KZ1 + 3, CONC_D, name="Crown roof")
box(s, 1545, 1565, KT + 4, KT + 12, 4915, 4935, CONC_D, name="Mast plinth")
MS = 1.15
s.kit("antenna_mast", (1555, KT + 12 + 30 * MS, 4925), scale=MS)
neon(s, 1553, 1557, 995, 998.5, 4923, 4927, (255, 30, 30), name="Beacon")

# ------------------------------------------------------------------ east wing: deck-access slab over lock-ups
EX0, EX1, EZ0, EZ1 = 1620, 1744, 4806, 5046
ET = G + 14 * ST  # ~387
s.group("East wing")
box(s, EX0 + 6, EX1 - 6, G, G + 2 * ST, EZ0 + 6, EZ1 - 6, SHUT, name="Lock-up shutters")
box(s, EX0, EX1, G + 2 * ST, G + 4 * ST, EZ0, EZ1, GRAF_A, name="Mural band")
box(s, EX0 + 4, EX1 - 4, G + 4 * ST, ET, EZ0 + 4, EZ1 - 4, WIN, name="Wing flats")
plates(s, EX0 - 5, EX1 + 5, EZ0 + 4, EZ1 - 4, levels(G + 4 * ST, ET - 2))
fins_z(s, grid(EZ0 + 4, EZ1 - 4), G + 4 * ST, ET, EX1 - 4, EX1 + 5)
fins_z(s, grid(EZ0 + 4, EZ1 - 4), G + 4 * ST, ET, EX0 - 5, EX0 + 4)
box(s, EX0 - 2, EX1 + 2, G + 4 * ST, ET + 4, EZ0 - 2, EZ0 + 8, BOARD, name="North end wall")
box(s, EX0 - 2, EX1 + 2, ET, ET + 4, EZ0, EZ1 + 2, CONC, name="Wing roof edge")
# deck-access bridge to the core
box(s, CX1, EX0 - 5, G + 13 * ST, G + 13 * ST + 10, 4914, 4936, CONC, name="Wing link")
EL = levels(G + 4 * ST, ET - 2)
for z, li in ((4830, 1), (4910, 3), (4990, 0), (4870, 5), (4950, 7), (5030, 8)):
    s.kit("laundry_line_36", (EX0 - 5.5, EL[li] + ST - 3.5, z), rot=(0, 90, 0), layer="LOD2")
for z, li in ((4830, 4), (4990, 6), (5030, 2)):
    s.kit("ac_cluster", (EX1 + 7, EL[li] + 6, z), rot=(0, -90, 0), layer="LOD2")
for z in (4870, 4950):
    s.kit("ext_stair_40", (EX1 + 11, G + 4 * ST + 20, z), rot=(0, -90, 0), layer="LOD3")
    s.kit("ext_stair_40", (EX1 + 11, G + 4 * ST + 60, z), rot=(0, -90, 0), layer="LOD3")
for x, z in ((1650, 4990), (1712, 4880)):
    s.kit("water_tank", (x, ET + 15, z), layer="LOD3")
s.kit("rooftop_shack", (1690, ET + 10, 5010), layer="LOD3")
s.kit("dish_cluster", (1660, ET + 10, 4850), layer="LOD2")
for x in (1650, 1700):
    s.kit("market_stall", (x, G + 7, EZ0 - 12), layer="LOD2")
for x in (1600, 1606):
    s.kit("vending_machine", (x, G + 4.5, EZ0 - 6), layer="LOD2")

s.save(OUT)
