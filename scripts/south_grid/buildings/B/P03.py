"""P03 'Capsule Gate' (Metabolist Row, waterfront, flanks the x=0 boulevard). Agent B.

Two gate towers on the boulevard (west) face carry a Fuji-TV style sky frame with a steel sphere between them:
  T1 (NW) Nakagin capsule tower: round core with 40-stud porthole capsules staggered around it (top ~694 with mast).
  T2 (SW) Yamanashi tray tower: twin square cores, glazed floor trays with gaps; lands bridge X5 on its south face.
Behind them: capsule wall (1-storey kit capsules over shops), T3 press tower (round core, pinwheel office arms),
T5 spiral capsule hotel on a market podium, T4 stacked-tray slab on the east street (lands bridge XB34).
Run: py -3 scripts/south_grid/buildings/B/P03.py
"""
import pathlib
from bkit import (Spec, box, cyl, fpanel, fkit, roof_cap, shopfront, WHITE, OFFWHITE, CONC, CONC_D, CONC_L, GLASS, PASTEL)

s = Spec("P03", kind="building", title="P03 Capsule Gate", lean="metabolist")
G = 100  # ground

# ---------------------------------------------------------------- T1: capsule core tower (NW gate)
s.group("T1 Capsule Core")
T1 = (344, 4156)
cyl(s, T1[0], T1[1], G, 630, 44, color=WHITE)
cyl(s, T1[0], T1[1], 626, 636, 52, var="SG Weathered Concrete", color=CONC_L, name="CoreHat")
s.kit("antenna_mast", (T1[0], 666, T1[1]))
# pavilion lobby around the core foot: shopfronts on N and W (inset 4)
box(s, 314, 380, G, 126, 4124, 4190, "SG Weathered Concrete", CONC)
box(s, 308, 382, 126, 131, 4118, 4192, "SG Weathered Concrete", CONC_D, name="LobbyRoof")
shopfront(s, "n", 4120, 312, 380, cols=34)
shopfront(s, "w", 310, 4122, 4190, cols=34, awning=False)
# capsules: 40-stud porthole boxes, 3 per level, staggered left/right like Nakagin
D = 39  # core centre -> capsule centre
for L in range(12):
    y0 = 140 + 40 * L
    sh = 8 if L % 2 == 0 else -8
    col = WHITE if L % 3 else OFFWHITE
    dirs = [("n", sh)]
    if L != 9:
        dirs.append(("w", -sh if L < 8 or L > 10 else -8))
    if L in (1, 3, 4, 6, 7, 11) or L < 1:
        dirs.append(("e", sh))
    if L in (3, 5):
        dirs.append(("s", -sh))
    if L == 11:
        dirs = [("n", sh), ("e", sh)]
    for d, off in dirs:
        cx, cz = T1
        if d == "n":
            cz -= D; cx += off
        elif d == "s":
            cz += D; cx += off
        elif d == "w":
            cx -= D; cz += off
        else:
            cx += D; cz += off
        box(s, cx - 20, cx + 20, y0 + 1, y0 + 39, cz - 20, cz + 20, "SG Windows Capsule", col, name="Capsule")

# ---------------------------------------------------------------- T2: tray tower on twin cores (SW gate, X5 landing)
s.group("T2 Tray Tower")
# podium: 2 shop storeys + graffiti band storey
box(s, 304, 476, G, 126, 4444, 4542, "SG Weathered Concrete", CONC)
box(s, 300, 480, 126, 140, 4440, 4546, "SG Graffiti A", (175, 175, 170), name="GraffitiBand")
shopfront(s, "w", 300, 4444, 4546, cols=34, awning=False, shutters=[(4480, 4510)])
shopfront(s, "s", 4546, 300, 480, cols=36, shutters=[(376, 412)])
for cx, top in ((324, 590), (456, 610)):
    box(s, cx - 18, cx + 18, G, top, 4486, 4522, "SG Weathered Concrete", CONC_L, name="Core")
    roof_cap(s, cx - 18, cx + 18, 4486, 4522, top)
s.kit("water_tank", (324, 592 + 11, 4504))
s.kit("antenna_mast", (456, 612 + 30, 4504))
trays = [(180, 260, 296, 488, 4452, 4540), (320, 400, 300, 500, 4446, 4574), (460, 560, 296, 484, 4440, 4540)]
for y0, y1, x0, x1, z0, z1 in trays:
    box(s, x0 + 4, x1 - 4, y0 + 1, y1 - 1, z0 + 4, z1 - 4, "Windows Day", OFFWHITE, name="GlazedFloor")
    # Tange tray fascias top and bottom (kit), along S and W faces
    for u in range(int(x0) + 20, int(x1) - 19, 40):
        fkit(s, "tray_edge_40", "s", z1 - 4, u, y0 + 4, 14, embed=10)
        fkit(s, "tray_edge_40", "s", z1 - 4, u, y1 - 4, 14, embed=10)
    for u in range(int(z0) + 17, int(z1) - 36, 40):
        fkit(s, "tray_edge_40", "w", x0 + 4, u, y0 + 4, 14, embed=10)
        fkit(s, "tray_edge_40", "w", x0 + 4, u, y1 - 4, 14, embed=10)
    box(s, x0 + 2, x1 - 2, y1 - 1, y1 + 2, z0 + 2, z1 - 2, "SG Weathered Concrete", CONC_D, name="TrayRoof")
# X5 landing portal on the cantilevered tray (deck top Y350 at x=400, z=4576)
fpanel(s, "s", 4570, 382, 418, 344, 376, 5, var="SG Capsule Panels", color=WHITE, name="X5Portal")
# vertical banners on the core faces between trays (boulevard + east)
for face, plane, u in (("w", 306, 4504), ("e", 474, 4504)):
    fpanel(s, face, plane, u - 8, u + 8, 266, 316, 1.5, mat="SmoothPlastic", color=(36, 58, 150), name="Banner")
    fpanel(s, face, plane, u - 8, u + 8, 263, 265, 1.5, mat="Neon", color=(90, 220, 255), name="BannerNeon")
s.kit("rooftop_shack", (360, 562 + 6, 4470))
s.kit("dish_cluster", (420, 562 + 6, 4466))

# ---------------------------------------------------------------- gate frame between T1 and T2 (boulevard face)
s.group("Gate Frame")
fz0, fz1 = 4168, 4448
box(s, 299, 343, 536, 556, fz0, fz1, "SG Capsule Panels", WHITE, name="FrameTop")
box(s, 299, 343, 476, 496, fz0, fz1, "SG Capsule Panels", WHITE, name="FrameBottom")
for z0, z1 in ((4248, 4264), (4350, 4366)):
    box(s, 302, 342, 495, 537, z0, z1, "SG Capsule Panels", OFFWHITE, name="FramePost")
for z0, z1 in ((4180, 4248), (4366, 4436)):
    box(s, 306, 340, 495, 537, z0, z1, "Windows Day", OFFWHITE, name="FrameGlazing")
s.part("Ball", (66, 66, 66), (322, 516, 4307), mat="Metal", color=(196, 202, 210), name="Sphere")
fpanel(s, "w", 299, 4180, 4436, 478, 480, 1.0, mat="Neon", color=(90, 220, 255), name="NeonStrip")
fpanel(s, "w", 299, 4180, 4436, 552, 554, 1.0, mat="Neon", color=(90, 220, 255), name="NeonStrip")

# ---------------------------------------------------------------- capsule wall (1-storey kit capsules over shops)
s.group("Capsule Wall")
box(s, 310, 356, G, 126, 4216, 4408, "SG Weathered Concrete", CONC)
box(s, 306, 356, 126, 206, 4214, 4410, "SG Windows Blocks", CONC_L, name="WallLower")
box(s, 304, 358, 205, 209, 4212, 4412, "SG Capsule Panels", WHITE, name="WallTray")
box(s, 310, 356, 208, 300, 4218, 4406, "SG Capsule Panels", OFFWHITE, name="WallUpper")
roof_cap(s, 310, 356, 4218, 4406, 300)
shopfront(s, "w", 306, 4214, 4410, cols=39, shutters=[(4292, 4330)])
fpanel(s, "n", 4214, 306, 356, 126, 166, 1.0, var="SG Graffiti B", color=(175, 175, 170), name="Graffiti")
fpanel(s, "s", 4410, 306, 356, 126, 166, 1.0, var="SG Graffiti A", color=(175, 175, 170), name="Graffiti")
fpanel(s, "w", 306, 4214, 4410, 126, 140, 1.0, var="SG Graffiti A", color=(175, 175, 170), name="Graffiti")
for r, yc in enumerate((220, 238, 256, 274, 292)):
    start = 4234 if r % 2 == 0 else 4251
    for k in range(5 if r % 2 == 0 else 4):
        u = start + 34 * k
        fkit(s, "capsule_unit", "w", 310, u, yc, 16, embed=1.0)
for y in (234, 274):  # porthole panels on the waterfront end of the capsule wall
    fkit(s, "porthole_panel_40", "n", 4218, 333, y, 3)
    fkit(s, "porthole_panel_40", "s", 4406, 333, y, 3)
s.kit("water_tank", (340, 301 + 11, 4380))
s.kit("rooftop_shack", (334, 301 + 6, 4250), rot=(0, 90, 0))

# ---------------------------------------------------------------- T3: press tower (round core + pinwheel office arms)
s.group("T3 Press Tower")
T3 = (606, 4180)
cyl(s, T3[0], T3[1], G, 560, 52, color=WHITE)
cyl(s, T3[0], T3[1], 556, 566, 60, var="SG Weathered Concrete", color=CONC_L, name="CoreHat")
box(s, 566, 686, G, 126, 4120, 4236, "SG Weathered Concrete", CONC)
box(s, 562, 692, 126, 132, 4114, 4240, "SG Weathered Concrete", CONC_D, name="LobbyRoof")
shopfront(s, "n", 4116, 564, 690, cols=42, shutters=[(606, 646)])
shopfront(s, "e", 690, 4118, 4238, cols=40, awning=False)
arms = [("e", 180), ("n", 240), ("w", 300), ("e", 360), ("s", 400), ("n", 440), ("w", 480)]
for d, y0 in arms:
    cx, cz = T3
    if d == "e":
        x0, x1, z0, z1 = cx + 12, cx + 96, cz - 24, cz + 24
    elif d == "w":
        x0, x1, z0, z1 = cx - 96, cx - 12, cz - 24, cz + 24
    elif d == "n":
        x0, x1, z0, z1 = cx - 24, cx + 24, cz - 96, cz - 12
    else:
        x0, x1, z0, z1 = cx - 24, cx + 24, cz + 12, cz + 96
    box(s, x0, x1, y0 + 4, y0 + 36, z0, z1, "Windows Day", OFFWHITE, name="OfficeArm")
    box(s, x0 - 2, x1 + 2, y0, y0 + 5, z0 - 2, z1 + 2, "SG Capsule Panels", WHITE, name="ArmTray")
    box(s, x0 - 2, x1 + 2, y0 + 35, y0 + 40, z0 - 2, z1 + 2, "SG Capsule Panels", WHITE, name="ArmTray")
s.kit("dish_cluster", (T3[0] - 6, 566 + 6, T3[1] + 6))
s.kit("antenna_mast", (T3[0] + 14, 566 + 30, T3[1] - 10))

# ---------------------------------------------------------------- T5: spiral capsule hotel on the market podium
s.group("T5 Capsule Hotel")
box(s, 404, 576, G, 126, 4264, 4420, "SG Weathered Concrete", CONC)
box(s, 400, 580, 126, 140, 4260, 4424, "SG Graffiti B", (175, 175, 170), name="GraffitiBand")
box(s, 398, 582, 139, 143, 4258, 4426, "SG Weathered Concrete", CONC_D, name="PodiumRoof")
shopfront(s, "n", 4260, 400, 580, cols=36, shutters=[(470, 506)])
shopfront(s, "e", 580, 4260, 4424, cols=41, awning=False, shutters=[(4300, 4340)])
T5 = (490, 4342)
cyl(s, T5[0], T5[1], 142, 540, 36, color=WHITE)
cyl(s, T5[0], T5[1], 536, 546, 44, var="SG Weathered Concrete", color=CONC_L, name="CoreHat")
order = ["n", "e", "s", "w"]
for L in range(10):
    y0 = 142 + 40 * L
    for d in (order[L % 4], order[(L + 2) % 4]):
        cx, cz = T5
        dd = 35
        if d == "n":
            cz -= dd
        elif d == "s":
            cz += dd
        elif d == "w":
            cx -= dd
        else:
            cx += dd
        box(s, cx - 20, cx + 20, y0 + 1, y0 + 39, cz - 20, cz + 20, "SG Windows Capsule", WHITE if L % 2 else OFFWHITE,
            name="Capsule")
for (cx, cz, face, plane, y) in ((490, 4307, "n", 4287, 170), (525, 4342, "e", 545, 200), (490, 4377, "s", 4397, 330),
                                 (455, 4342, "w", 435, 290), (490, 4307, "n", 4287, 490)):
    fkit(s, "ac_cluster", face, plane, cx if face in "ns" else cz, y, 4, layer="LOD2")
s.kit("water_tank", (T5[0], 546 + 11, T5[1]))
# market stalls on the plaza north of the podium
for x, z in ((420, 4222), (452, 4222), (500, 4230), (532, 4230)):
    s.kit("market_stall", (x, G + 7, z), layer="LOD2")
for x, z, ry in ((398, 4200, 90), (560, 4250, 0)):
    s.kit("vending_machine", (x, G + 4.5, z), rot=(0, ry, 0), layer="LOD2")

# ---------------------------------------------------------------- T4: stacked-tray slab on the east street (XB34 landing)
s.group("T4 Tray Slab")
box(s, 620, 696, G, 126, 4330, 4542, "SG Weathered Concrete", CONC)
box(s, 620, 700, 126, 140, 4330, 4546, "SG Graffiti B", (175, 175, 170), name="GraffitiBand")
shopfront(s, "e", 700, 4330, 4546, cols=36, shutters=[(4370, 4400), (4470, 4500)])
shopfront(s, "s", 4546, 620, 700, cols=40)
for k in range(8):
    y0 = 140 + 40 * k
    x0 = 620 + (8 if k % 2 else 0)
    x1 = x0 + 76
    box(s, x0 - 8, x1 + 6, y0 - 1, y0 + 3, 4326, 4550, "SG Capsule Panels", WHITE, name="Tray")
    box(s, x0, x1, y0 + 3, y0 + 39, 4334, 4542, "SG Windows Capsule" if k % 3 else "SG Windows Blocks",
        OFFWHITE if k % 2 else WHITE, name="TrayFloor")
    if k in (1, 3, 5):
        fkit(s, "laundry_line_36", "w", x0, 4380 + 30 * (k % 3), y0 + 35.5, 1, embed=-5, layer="LOD2",
             color=PASTEL[k % len(PASTEL)])
    if k in (0, 2, 5, 7):
        fkit(s, "ac_cluster", "e", x1, 4360 + 24 * k, y0 + 12, 4, layer="LOD2")
roof_cap(s, 628, 704, 4334, 4542, 460)
s.kit("water_tank", (650, 462 + 11, 4380))
s.kit("rooftop_shack", (680, 462 + 6, 4480), rot=(0, -90, 0))
s.kit("ac_cluster", (650, 462 + 3.5, 4460))

out = pathlib.Path(__file__).with_suffix(".json")
s.save(out)
