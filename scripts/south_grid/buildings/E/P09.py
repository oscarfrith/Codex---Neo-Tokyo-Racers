"""P09 - west gate tower (hybrid, leaning The Blocks). Parcel x -574..-125, z 4780..5236, ground Y200.
Massing: podium (Y200-240) -> U of Blocks slabs round a light well (S2 north, S3 south, S1 on the boulevard)
-> S1 upper setback tower to Y760 -> square concrete gate core on the boulevard corner to Y813 + mast.
Landings: X1 on the core's east face (x=-125, z=5000, deck Y440); X4 lobby on S2's north face (x=-400, z=4780, deck Y330).
"""
import pathlib
from elib import *  # noqa: F401,F403

s, rng = new_spec("P09", "Gate West (Blocks tower)", "hybrid")
OUT = HERE / "P09.json"

# ------------------------------------------------------------------ podium
s.group("Podium")
box(s, -545, -160, G, Y(1), 4812, 5204, mat="Metal", var="Metal Shutters", color=SHUT, name="GarageShutters")
box(s, -556, -150, Y(1), Y(3), 4800, 5216, name="Podium")
box(s, -150, -148.8, Y(1), Y(3), 4805, 4950, var="SG Graffiti A", color=(200, 200, 200), name="GraffitiEast")
box(s, -150, -148.8, Y(1), Y(3), 5050, 5210, var="SG Graffiti B", color=(200, 200, 200), name="GraffitiEast")
box(s, -550, -340, Y(1), Y(3), 4798.8, 4800, var="SG Graffiti B", color=(200, 200, 200), name="GraffitiNorth")
box(s, -540, -345, Y(1), Y(3), 5216, 5217.2, var="SG Graffiti A", color=(200, 200, 200), name="GraffitiSouth")
box(s, -148.8, -148.2, Y(1) + 0.4, Y(1) + 1.0, 4810, 4945, mat="Neon", var="", color=NEON_PINK, name="ShopNeon")
box(s, -148.8, -148.2, Y(1) + 0.4, Y(1) + 1.0, 5055, 5200, mat="Neon", var="", color=NEON_CYAN, name="ShopNeon")
for z in (4868, 4874, 5102):
    s.kit("vending_machine", (-163, G + 4.5, z), rot=(0, -90, 0), layer="LOD2")

# ------------------------------------------------------------------ gate core (boulevard corner, X1 lands on its east face)
s.group("Gate Core")
box(s, -176, -127, Y(3), Y(46), 4955, 5045, name="Core")
box(s, -127, -125, Y(3), Y(46), 4955, 4990, name="CoreFlank")
box(s, -127, -125, Y(3), Y(46), 5010, 5045, name="CoreFlank")
box(s, -127.5, -126, Y(3) + 10, Y(46) - 10, 4990, 5010, mat="Glass", var="", color=GLASS, name="CoreSlot")
box(s, -179, -124.5, Y(46), Y(46) + 7, 4952, 5048, color=CONC_D, name="CoreCrown")
box(s, -176, -125, Y(3), Y(7), 4953.8, 4955, var="SG Graffiti B", color=(200, 200, 200), name="CoreGraffiti")
for k in range(9, 45, 6):   # stair-landing vents up the north face, every 80 studs
    box(s, -168, -133, Y(k), Y(k) + 5, 4953.6, 4955, mat="Metal", var="Metal Shutters", color=DARK, name="CoreVent")
# blade sign on the north face
box(s, -131, -129, Y(4), Y(8), 4937, 4955, color=DARK, mat="SmoothPlastic", var="", name="BladeSign")
box(s, -131.3, -128.7, Y(4) + 2, Y(8) - 2, 4936.2, 4937, mat="Neon", var="", color=NEON_AMBER, name="BladeNeon")
s.kit("antenna_mast", (-160, Y(46) + 7 + 30, 5020))
s.kit("water_tank", (-150, Y(46) + 7 + 11, 4975))

# ------------------------------------------------------------------ S1 boulevard slab (Y240-640) + upper tower (to Y760)
s.group("S1 Boulevard Slab")
win_box(s, -330, -184, Y(3), Y(33), 4812, 5180, name="S1Windows")
# end walls of the boulevard balcony grid
box(s, -184, -174, Y(3), Y(33), 4812, 4835, name="S1EndWall")
box(s, -184, -174, Y(3), Y(33), 5165, 5180, name="S1EndWall")
# grid split at the X1 deck level by a solid "sky street" band (Y440-453) that lines up with the gate deck
for z0, z1 in ((4835, 4955), (5045, 5165)):
    balcony_grid(s, "E", -184, z0, z1, 3, 18, rng)
    balcony_grid(s, "E", -184, z0, z1, 19, 33, rng)
    box(s, -184, -172, Y(18), Y(19) - 1.2, z0 - 2, z1 + 2, color=CONC_L, name="SkyStreetBand")
# north gable: concrete skin, mural on the lower storeys, window strip, pipes and AC
box(s, -330, -174, Y(3), Y(33), 4809, 4812, color=CONC, name="S1Gable")
box(s, -328, -176, Y(3), Y(10), 4807.8, 4809, var="SG Graffiti A", color=(200, 200, 200), name="GableMural")
win_box(s, -292, -212, Y(10), Y(32), 4808, 4809, name="GableWindows")
# a stacked column of kit balconies up the gable (the Blocks "stack" motif seen from the step)
for k in range(11, 32, 2):
    s.kit("balcony_run_40", (-252, Y(k) + 6.5, 4804), color=CONC)
    if k % 4 == 1:
        s.kit("laundry_line_36", (-252, Y(k) - 4.2, 4799.4), layer="LOD2", color=(230, 120, 150) if k % 8 == 1 else (120, 170, 230))
for k in range(11, 32, 3):
    s.kit("pipe_bundle_40", (-300, Y(k) + 20, 4807.5), layer="LOD2")
for k in (14, 22, 28):
    fkit(s, "ac_cluster", "N", 4808, 2, rng.choice([-318, -190]), Y(k) + 5, layer="LOD2")
# south gable
box(s, -330, -174, Y(3), Y(33), 5180, 5183, color=CONC, name="S1Gable")
win_box(s, -292, -220, Y(5), Y(32), 5183, 5184, name="GableWindows")
box(s, -332, -172, Y(33), Y(33) + 3, 4808, 5184, color=CONC_D, name="S1Roof")
roof_clutter(s, -330, -190, 4812, 4895, Y(33) + 3, rng, tanks=1, shacks=1, dishes=1, overrun=False)
roof_clutter(s, -330, -190, 5135, 5180, Y(33) + 3, rng, tanks=1, shacks=0, dishes=0, overrun=False)

s.group("S1 Upper Tower")
win_box(s, -322, -192, Y(33) + 3, Y(42), 4900, 5130, name="S1UWindows")
balcony_grid(s, "E", -192, 4905, 5125, 34, 42, rng, bay=44, laundry=0.18)
# cantilevered patched sky-room on the north face
box(s, -300, -228, Y(36), Y(39), 4868, 4900, mat="SmoothPlastic", var="SG Patched Panels", color=(200, 225, 205), name="SkyRoom")
box(s, -302, -226, Y(36) - 2, Y(36), 4866, 4900, color=CONC_D, name="SkyRoomSlab")
box(s, -302, -226, Y(39), Y(39) + 2, 4866, 4900, color=CONC_D, name="SkyRoomSlab")
box(s, -325, -189, Y(42), Y(42) + 3, 4897, 5133, color=CONC_D, name="S1URoof")
parapet(s, -325, -189, 4897, 5133, Y(42) + 3)
roof_clutter(s, -320, -194, 4900, 5130, Y(42) + 3, rng, tanks=2, shacks=1, dishes=1, masts=1)
for k in (35, 38, 40):
    fkit(s, "ac_cluster", "N", 4900, 2, rng.choice([-316, -210]), Y(k) + 5, layer="LOD2")

# ------------------------------------------------------------------ S2 north slab (Y240-480), X4 landing, ext stairs
s.group("S2 North Slab")
win_box(s, -556, -330, Y(3), Y(21), 4822, 4960, name="S2Windows")
box(s, -556, -330, Y(3), Y(5), 4820.8, 4822, var="SG Graffiti B", color=(200, 200, 200), name="S2Graffiti")
balcony_grid(s, "N", 4822, -550, -350, 5, 21, rng, skip=[(-420, -380, 9, 13)])
box(s, -350, -330, Y(5), Y(21), 4812, 4822, name="S2EndWall")
box(s, -558, -330, Y(21), Y(21) + 3, 4812, 4962, color=CONC_D, name="S2Roof")
parapet(s, -558, -330, 4812, 4962, Y(21) + 3)
roof_clutter(s, -556, -480, 4822, 4960, Y(21) + 3, rng, tanks=1, shacks=2, dishes=1)
# X4 landing lobby: solid face at z=4780, x -416..-384, deck top Y330
box(s, -418, -382, Y(9) + 2, Y(12) + 2, 4780, 4822, color=CONC_L, name="X4Lobby")
box(s, -408, -392, 330, 346, 4779.2, 4780.4, mat="Metal", var="Metal Shutters", color=DARK, name="X4Door")
box(s, -420, -380, Y(12) + 2, Y(12) + 5, 4778.8, 4822, color=CONC_D, name="X4LobbyRoof")
# external steel stair stack up the west face
for k in range(3, 15, 3):
    fkit(s, "ext_stair_40", "W", -556, 5, 4905, Y(k) + 20)
for k in (7, 11, 15, 18):
    fkit(s, "ac_cluster", "W", -556, 2, rng.choice([4845, 4870, 4940]), Y(k) + 5, layer="LOD2")
box(s, -557.2, -556, Y(8), Y(11), 4836, 4876, mat="SmoothPlastic", var="SG Patched Panels", color=(235, 190, 175), name="PatchPanel")
box(s, -557.2, -556, Y(15), Y(17), 4930, 4958, mat="SmoothPlastic", var="SG Patched Panels", color=(190, 214, 232), name="PatchPanel")

# ------------------------------------------------------------------ cantilever arm from S1 over S2 (Y520-600) + support
s.group("Cantilever Arm")
win_box(s, -470, -330, Y(24), Y(30), 4845, 4935, name="ArmWindows")
box(s, -472, -330, Y(24) - 3, Y(24), 4843, 4937, color=CONC_D, name="ArmSoffit")
balcony_grid(s, "N", 4845, -466, -334, 24, 30, rng, bay=44, laundry=0.2)
box(s, -472, -330, Y(30), Y(30) + 3, 4835, 4937, color=CONC_D, name="ArmRoof")
roof_clutter(s, -470, -335, 4845, 4935, Y(30) + 3, rng, tanks=1, shacks=1, dishes=0, overrun=False)
box(s, -468, -448, Y(21) + 3, Y(24) - 3, 4895, 4915, color=CONC_D, name="ArmLeg")
s.kit("ext_stair_40", (-436, Y(21) + 3 + 20, 4905), rot=(0, 90, 0))

# ------------------------------------------------------------------ S3 south slab (Y240-520)
s.group("S3 South Slab")
win_box(s, -556, -330, Y(3), Y(24), 5010, 5204, name="S3Windows")
balcony_grid(s, "S", 5204, -550, -350, 4, 24, rng)
box(s, -350, -330, Y(4), Y(24), 5204, 5214, name="S3EndWall")
box(s, -556, -330, Y(3), Y(4) + 4.8, 5204, 5212, var="SG Graffiti A", color=(200, 200, 200), name="S3Graffiti")
box(s, -558, -330, Y(24), Y(24) + 3, 5008, 5214, color=CONC_D, name="S3Roof")
parapet(s, -558, -330, 5008, 5214, Y(24) + 3)
roof_clutter(s, -556, -335, 5010, 5204, Y(24) + 3, rng, tanks=1, shacks=2, dishes=1, masts=1)
for k in (6, 10, 14, 19, 22):
    fkit(s, "ac_cluster", "W", -556, 2, rng.choice([5030, 5080, 5130, 5170]), Y(k) + 5, layer="LOD2")
for k in range(4, 22, 3):
    s.kit("pipe_bundle_40", (-558, Y(k) + 20, 5190), rot=(0, 90, 0), layer="LOD2")

# light-well access decks between S2 and S3
s.group("Light Well")
for k, x in ((12, -520), (18, -470), (15, -400)):
    box(s, x - 10, x + 10, Y(k) - 2, Y(k), 4960, 5010, color=CONC_D, name="WellDeck")
    box(s, x - 10, x + 10, Y(k), Y(k) + 4, 4960, 5010, mat="SmoothPlastic", var="SG Patched Panels", color=PATCH, name="WellDeckRail")

if __name__ == "__main__":
    s.save(OUT)
