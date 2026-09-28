"""P10 - east gate tower (hybrid, leaning Metabolist). Parcel x 125..530, z 4780..5236, ground Y200.
Massing: colonnaded podium -> twin round cores on the boulevard edge joined by a Fuji-TV style frame (F1 takes X1,
open bay, F2 above, top beam) -> stacked-tray tower T1 behind -> Nakagin capsule tower T2 on the north-east
(X5 lands at its foot) -> Blocks balcony wing T3 on the east road (X2 lands on it) -> low Blocks blocks NW/SW.
Landings: X1 west face of F1 (x=125, z=5000, deck Y440); X5 north face (x=400, z=4780, deck Y350);
X2 east face (x=530, z=5060, deck Y400).
"""
from elib import *  # noqa: F401,F403

s, rng = new_spec("P10", "Gate East (Metabolist tower)", "hybrid")
OUT = HERE / "P10.json"
C1, C2, CX, CD = 4945, 5055, 170, 40  # twin core centres (z), x, diameter

# ------------------------------------------------------------------ podium with colonnade
s.group("Podium")
box(s, 174, 494, G, Y(2), 4814, 5202, mat="Glass", var="", color=GLASS, name="Shopfront")
box(s, 150, 506, Y(2), Y(3), 4800, 5216, color=CONC_L, name="Podium")
box(s, 150, 506, Y(3), Y(3) + 2, 4800, 5216, color=CONC_D, name="PodiumRoof")
for z in (4822, 4870, 4905, 5095, 5140, 5190):
    cyl(s, 160, z, 10, G, Y(2), color=WHITE, name="Piloti")
box(s, 148.8, 150, Y(2) + 1, Y(3) - 1, 4805, 4910, var="SG Graffiti B", color=(200, 200, 200), name="GraffitiWest")
box(s, 148.8, 150, Y(2) + 1, Y(3) - 1, 5090, 5210, var="SG Graffiti A", color=(200, 200, 200), name="GraffitiWest")
box(s, 148.2, 148.8, Y(2) + 0.5, Y(2) + 1.1, 4805, 4910, mat="Neon", var="", color=NEON_CYAN, name="ShopNeon")
box(s, 148.2, 148.8, Y(2) + 0.5, Y(2) + 1.1, 5090, 5210, mat="Neon", var="", color=NEON_PINK, name="ShopNeon")

# ------------------------------------------------------------------ twin round cores + Fuji frame + sphere
s.group("Gate Frame")
for zc in (C1, C2):
    cyl(s, CX, zc, CD, G, Y(45), name="GateCore")
    cyl(s, CX, zc, CD + 6, Y(45), Y(45) + 6, color=CONC_L, name="CoreCap")
    for k in (12, 24, 36):
        cyl(s, CX, zc, CD + 4, Y(k), Y(k) + 3, color=CONC_L, name="CoreRing")
    s.kit("antenna_mast", (CX, Y(45) + 6 + 30, zc))
# F1: the X1 landing frame (solid west face at x=125, Y386.7-520; X1 slab Y426-523 and tubes Y391-409 land on it)
win_box(s, 130, 238, Y(14) + 5, Y(24) - 5, 4925, 5075, var="SG Windows Capsule", name="F1Glazing")
box(s, 125, 240, Y(14), Y(14) + 5, 4921, 5079, var="SG Capsule Panels", color=WHITE, name="F1Tray")
box(s, 125, 240, Y(24) - 5, Y(24) + 3, 4921, 5079, var="SG Capsule Panels", color=WHITE, name="F1Tray")
box(s, 125, 130, Y(14) + 5, Y(24) - 5, 4921, 5079, var="SG Capsule Panels", color=WHITE, name="F1Portal")
# F2 upper frame and the top beam
win_box(s, 152, 238, Y(28) + 5, Y(33) - 5, 4925, 5075, var="SG Windows Capsule", name="F2Glazing")
box(s, 146, 240, Y(28), Y(28) + 5, 4921, 5079, var="SG Capsule Panels", color=WHITE, name="F2Tray")
box(s, 146, 240, Y(33) - 5, Y(33), 4921, 5079, var="SG Capsule Panels", color=WHITE, name="F2Tray")
box(s, 152, 188, Y(42), Y(42) + 12, 4935, 5065, var="SG Capsule Panels", color=WHITE, name="TopBeam")
box(s, 153.5, 154.1, Y(42) + 4, Y(42) + 5, 4966, 5034, mat="Neon", var="", color=NEON_CYAN, name="BeamNeon")
# glazed tube links cores -> T1
s.kit("bridge_tube_40", (212.5, Y(27), C1), scale=1.125)
s.kit("bridge_tube_40", (212.5, Y(37), C2), scale=1.125)

# ------------------------------------------------------------------ T1 stacked-tray tower (Y240-720)
s.group("T1 Tray Tower")
TX0, TX1, TZ0, TZ1 = 245, 410, 4895, 5155
for t in range(12):
    k = 3 + 3 * t
    y0 = Y(k)
    shift = (-20, 0, 12, -8)[t % 4]
    win_box(s, TX0, TX1, y0 + 5, y0 + 40, TZ0 + max(0, shift), TZ1 + min(0, shift), name="T1Body")
    box(s, TX0 - 10, TX1 + 10, y0, y0 + 5, TZ0 - 15 + shift, TZ1 + 15, var="SG Capsule Panels", color=WHITE, name="T1Tray")
    if shift == -20:   # deep north terrace: planter strip along the tray edge
        box(s, TX0 + 5, TX1 - 5, y0 + 5, y0 + 9, 4862, 4870, mat="Concrete", var="SG Weathered Concrete", color=CONC_L, name="Planter")
        box(s, TX0 + 7, TX1 - 7, y0 + 9, y0 + 10.5, 4863, 4869, mat="Grass", var="", color=(88, 140, 72), name="PlanterGreen")
box(s, TX0 - 10, TX1 + 10, Y(39), Y(39) + 5, TZ0 - 15, TZ1 + 15, var="SG Capsule Panels", color=WHITE, name="T1Roof")
box(s, 280, 380, Y(39) + 5, Y(41) + 5, 4960, 5090, var="SG Capsule Panels", color=WHITE, name="RoofPavilion")
win_box(s, 282, 378, Y(39) + 9, Y(41), 4958, 5092, var="SG Windows Capsule", name="PavilionGlazing")
roof_clutter(s, TX0 - 5, TX1 + 5, TZ0 - 10, 4955, Y(39) + 5, rng, tanks=2, shacks=1, dishes=1, overrun=False)
roof_clutter(s, TX0 - 5, TX1 + 5, 5095, TZ1 + 10, Y(39) + 5, rng, tanks=1, shacks=1, dishes=1, masts=1, overrun=False)
for k in (8, 17, 26, 32):
    fkit(s, "ac_cluster", "N", TZ0 - 20 if (k // 3) % 4 == 0 else TZ0, 2, rng.choice([270, 330, 390]), Y(k) + 8, layer="LOD2")

# ------------------------------------------------------------------ T2 Nakagin capsule tower (north-east), X5 landing
s.group("T2 Capsule Tower")
box(s, 380, 430, Y(3), Y(36), 4800, 4850, var="SG Capsule Panels", color=WHITE, name="CapsuleCore")
box(s, 377, 433, Y(36), Y(38), 4797, 4853, color=CONC_L, name="CapsuleCoreCap")
box(s, 410, 432, Y(3), Y(36), 4850, 4880, var="SG Capsule Panels", color=WHITE, name="CapsuleLink")
s.kit("water_tank", (395, Y(38) + 11, 4825))
s.kit("antenna_mast", (420, Y(38) + 30, 4840))
for k in range(13, 36):
    x = 393 if k % 2 else 417
    s.kit("capsule_unit", (x, Y(k) + 6.5, 4792), rot=(0, 0, 0), color=WHITE)
for k in range(14, 36, 3):
    s.kit("capsule_unit", (372, Y(k) + 6.5, 4815 if k % 2 else 4835), rot=(0, 90, 0), color=WHITE)
# X5 landing: solid face at z=4780, x 385..415, deck top Y350
box(s, 384, 416, Y(11) - 3, Y(13), 4780, 4800, var="SG Capsule Panels", color=CONC_L, name="X5Lobby")
box(s, 392, 408, 350, 366, 4779.2, 4780.4, mat="Metal", var="Metal Shutters", color=DARK, name="X5Door")

# ------------------------------------------------------------------ T3 Blocks balcony wing on the east road, X2 landing
s.group("T3 East Wing")
win_box(s, 432, 506, Y(3), Y(18), 4820, 5200, name="T3Windows")
balcony_grid(s, "E", 506, 4840, 5200, 4, 18, rng, skip=[(5040, 5080, 13, 17)])
box(s, 506, 516, Y(3), Y(18), 4820, 4840, name="T3EndWall")
box(s, 506, 514, Y(3), Y(4) + 4.8, 4840, 5200, var="SG Graffiti B", color=(200, 200, 200), name="T3Graffiti")
box(s, 430, 518, Y(18), Y(18) + 3, 4818, 5202, color=CONC_D, name="T3Roof")
parapet(s, 430, 518, 4818, 5202, Y(18) + 3)
roof_clutter(s, 435, 505, 4885, 5195, Y(18) + 3, rng, tanks=2, shacks=2, dishes=1)
box(s, 438, 504, Y(3), Y(18), 4818.8, 4820, mat="SmoothPlastic", var="SG Patched Panels", color=(235, 222, 170), name="T3NorthPatch")
# X2 landing: solid face at x=530, z 5045..5075, deck top Y400
box(s, 506, 530, 390, 424, 5044, 5076, color=CONC_L, name="X2Lobby")

# ------------------------------------------------------------------ low Blocks blocks on the boulevard, north and south of the cores
s.group("NW Block")
win_box(s, 152, 235, Y(3), Y(12), 4822, 4905, name="NWWindows")
balcony_grid(s, "N", 4822, 158, 235, 3, 12, rng, bay=38.5, laundry=0.3)
box(s, 150, 237, Y(12), Y(12) + 3, 4812, 4907, color=CONC_D, name="NWRoof")
parapet(s, 150, 237, 4812, 4907, Y(12) + 3)
roof_clutter(s, 152, 235, 4822, 4905, Y(12) + 3, rng, tanks=1, shacks=1, dishes=1, overrun=False)
for k in (5, 8, 10):
    fkit(s, "ac_cluster", "W", 152, 2, rng.choice([4840, 4870, 4890]), Y(k) + 5, layer="LOD2")

s.group("SW Block")
win_box(s, 152, 235, Y(3), Y(10), 5095, 5205, name="SWWindows")
balcony_grid(s, "S", 5205, 158, 235, 3, 10, rng, bay=38.5, laundry=0.3)
box(s, 150, 237, Y(10), Y(10) + 3, 5093, 5215, color=CONC_D, name="SWRoof")
roof_clutter(s, 152, 235, 5095, 5205, Y(10) + 3, rng, tanks=1, shacks=2, dishes=0, overrun=False)
box(s, 150.8, 152, Y(3), Y(6), 5100, 5200, var="SG Graffiti A", color=(200, 200, 200), name="SWGraffiti")

if __name__ == "__main__":
    s.save(OUT)
