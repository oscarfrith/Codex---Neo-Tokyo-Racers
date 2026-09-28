"""P02 Twin Core Yard (lean: hybrid Blocks x Metabolist). Waterfront row, ground Y100. Run: python P02.py -> P02.json"""
import math, random
from abuild import Spec, Mass, box, win, cyl_v, CON, CON_D, CON_L, CAP_W, STEEL, HERE, FACE_RY

rng = random.Random(202)
s = Spec("P02", kind="building", title="P02 Twin Core Yard", lean="hybrid")

# 1. Canal slab: Blocks balcony slab on the P01/P02 road (receives the XA1 slab bridge at Y300-340 on its west face).
w = Mass(s, "Canal Slab", -720, -664, 4140, 4500, 120, 400, rng, grid="W", gallery="E", gables="NS", graffiti=("A", "B"),
         fin_step=20, graffiti_h=100)
w.balconies("W", [1, 2, 6, 7], [133.3, 146.7], laundry=0.7)
w.laundry_under_plates("W", 3)
w.ac("W", 4)
w.roof_kit("water_tank", -692, 4170, dy=0)
w.roof_kit("rooftop_shack", -692, 4330, ry=90)
w.roof_kit("water_tank", -692, 4460)

w.roof_box(-714, -670, 4220, 4250, 14, name="RoofRoom")
w.roof_box(-710, -680, 4380, 4400, 10, name="RoofRoom", color=(226, 206, 150), patched=True)

# 2. Metabolist twin cores with a Fuji-TV frame of trays and a sphere, facing the water.
AX, BX, CZ, D = -600, -480, 4200, 48
s.group("Core A")
cyl_v(s, AX, CZ, D, 100, 630, name="CoreA")
cyl_v(s, AX, CZ, D + 6, 628, 636, color=CON_L, var="SG Weathered Concrete", name="CoreCap")
s.kit("antenna_mast", (AX, 636 + 30, CZ))
s.group("Core B")
cyl_v(s, BX, CZ, D, 100, 580, name="CoreB")
cyl_v(s, BX, CZ, D + 6, 578, 586, color=CON_L, var="SG Weathered Concrete", name="CoreCap")
s.kit("water_tank", (BX, 586 + 11 * 1.4, CZ), scale=1.4)
s.group("Core Rings")
for x, top in ((AX, 630), (BX, 580)):
    for y in range(180, top - 40, 80):
        cyl_v(s, x, CZ, D + 8, y - 1.5, y + 1.5, color=CON_L, var="SG Weathered Concrete", name="CoreRing")
s.group("Frame Trays")
for y0 in (280, 400, 520):
    win(s, AX, BX, y0, y0 + 40, CZ - 20, CZ + 20, name="TrayWindows")
    box(s, AX + 10, BX - 10, y0 - 6, y0, CZ - 28, CZ + 28, color=CAP_W, var="SG Capsule Panels", name="TrayFloor")
    box(s, AX + 10, BX - 10, y0 + 40, y0 + 44, CZ - 24, CZ + 24, color=CAP_W, var="SG Capsule Panels", name="TrayRoof")
s.part("Ball", (52, 52, 52), ((AX + BX) / 2, 444 + 26, CZ), mat="Metal", var="", color=(196, 200, 206), name="Sphere")

# capsules plugged into the cores (kit capsule_unit, back embedded 5 studs so the corners bury in the cylinder)
s.group("Capsules")
def capsule(cx, cz, face_deg, y):
    a = math.radians(face_deg)            # direction the porthole faces, measured like FACE_RY (0 = -Z)
    d = D / 2 + 8 - 5
    x, z = cx - math.sin(a) * d, cz - math.cos(a) * d
    s.kit("capsule_unit", (x, y, z), rot=(0, face_deg, 0), color=CAP_W)
for i, y in enumerate(range(150, 236, 14)):         # core A, north-west, low stack
    capsule(AX, CZ, 45 + (8 if i % 2 else -8), y + 6.5)
for i, y in enumerate(range(330, 428, 14)):         # core A, west, mid stack
    capsule(AX, CZ, 90, y + 6.5)
for i, y in enumerate(range(452, 508, 14)):         # core B, east, under the NE tower crown
    capsule(BX, CZ, -90, y + 6.5)

# 3. North-east tower on the boulevard side: Blocks shaft with a Metabolist capsule-window crown.
ne = Mass(s, "NE Tower", -420, -320, 4130, 4290, 120, 440, rng, grid="EN", gallery="W", gables="S", graffiti=("B",))
ne.balconies("E", [0, 3], [133.3, 146.7, 173.3], laundry=0.6)
ne.ac("E", 3)
ne.ac("N", 1)
crown = Mass(s, "NE Crown", -410, -330, 4140, 4280, 440, 560, rng, grid="EW", gables="", podium=False, graffiti=(),
             capsule=True, proj=6, patch=0.0)
crown.roof_kit("water_tank", -390, 4160)
crown.roof_kit("dish_cluster", -350, 4260, ry=180)
crown.roof_kit("rooftop_shack", -370, 4210, ry=-90)
ne.roof_kit("water_tank", -330, 4284, dy=0)

# 4. South tower on the step road; carries the X4 bridge head (landing face at z=4576, deck top Y330, x=-400).
st = Mass(s, "South Tower", -460, -330, 4420, 4540, 120, 480, rng, grid="SE", gallery="N", gables="W", graffiti=("A",))
st.balconies("S", [0, 2], [133.3, 146.7, 173.3], laundry=0.6)
st.laundry_under_plates("S", 3)
st.ac("E", 3)
st.stair("E", 4450, 100, 2)
st.roof_kit("water_tank", -440, 4440)
st.roof_kit("water_tank", -414, 4440)
st.roof_kit("antenna_mast", -345, 4525)
s.group("X4 Bridge Head")
box(s, -426, -374, 296, 356, 4536, 4576, color=CON, name="BridgeHead")            # solid landing face at z=4576
box(s, -420, -380, 356, 360, 4540, 4572, color=CON_L, name="BridgeHeadCap")
box(s, -418, -382, 331, 351, 4575, 4576.8, mat="SmoothPlastic", var="", color=(40, 44, 52), name="BridgeDoor")

st.roof_box(-400, -360, 4470, 4500, 16, name="RoofRoom")

# 5. South bar: low Blocks slab closing the yard to the step road.
sb = Mass(s, "South Bar", -652, -464, 4460, 4530, 120, 320, rng, grid="S", gallery="N", gables="", graffiti=("B",),
          fin_step=0, patch=0.6)
sb.balconies("S", [1, 3], [133.3, 146.7], laundry=0.8)
sb.ac("S", 2)
sb.roof_kit("rooftop_shack", -620, 4495, ry=180)
sb.roof_kit("dish_cluster", -520, 4490, ry=180)
sb.roof_box(-590, -560, 4475, 4500, 10, name="RoofRoom", color=(160, 204, 186), patched=True)

# 6. Yard: two market stalls under the cores.
s.group("Yard")
s.kit("market_stall", (-560, 107, 4300), rot=(0, 0, 0), layer="LOD2")
s.kit("market_stall", (-520, 107, 4330), rot=(0, 180, 0), layer="LOD2")

if __name__ == "__main__":
    s.save(str(HERE / "P02.json"))
