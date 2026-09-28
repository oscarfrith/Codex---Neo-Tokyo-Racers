"""P01 Kaigan Blocks (lean: blocks). Waterfront row, ground Y100. Run: python P01.py -> P01.json

A perimeter block of mass housing around a courtyard: harbour slab on the water, stepped south slab on the step road,
a tall west tower with a cantilevered crown, an east tower on the P01/P02 road with a sky block reaching over the
courtyard, and a free-standing lift shaft tied to everything by access decks.
"""
import random
from abuild import Spec, Mass, box, lift_tower, walkway, CON_L, HERE

rng = random.Random(101)
s = Spec("P01", kind="building", title="P01 Kaigan Blocks", lean="blocks")

# 1. Harbour slab: 40-grid balcony wall to the water, access decks to the courtyard, big mural on the west gable.
n = Mass(s, "Harbour Slab", -1180, -900, 4120, 4160, 120, 360, rng, grid="N", gallery="S", gables="WE",
         graffiti=("A",), graffiti_h=140)
n.balconies("N", [1, 2, 5], [133.3, 146.7], laundry=0.7)
n.laundry_under_plates("N", 4)
n.ac("N", 3)
n.stair("S", -960, 100, 3)
for x, it, ry in ((-1152, "water_tank", 0), (-1122, "water_tank", 0), (-1000, "rooftop_shack", 180),
                  (-978, "rooftop_shack", 180), (-930, "dish_cluster", 0)):
    n.roof_kit(it, x, 4140, ry=ry)

n.roof_box(-1100, -1060, 4126, 4154, 14, name="RoofRoom")
lift_tower(s, "Harbour Lift", -1052, -1028, 4106, 4126, 396, glass="N", graffiti="A")

# 2. West tower: 120x120 block to 460, then a slimmer crown to 660 that cantilevers 40 south over the yard.
w = Mass(s, "West Tower", -1200, -1080, 4200, 4320, 120, 460, rng, grid="WS", gallery="E", gables="N",
         graffiti=("B",), graffiti_h=100)
w.balconies("W", [0, 2], [133.3, 146.7, 173.3, 186.7], laundry=0.6)
w.ac("W", 3)
w.ac("S", 2)
w.stair("E", 4300, 100, 2)
wu = Mass(s, "West Tower Crown", -1200, -1120, 4200, 4360, 460, 660, rng, grid="WSE", gables="N", podium=False,
          graffiti=(), gable_base=466, fin_step=20, patch=0.3)
w.roof_kit("water_tank", -1100, 4225)
w.roof_kit("water_tank", -1100, 4255)
w.roof_kit("rooftop_shack", -1100, 4292, ry=-90)
wu.roof_kit("water_tank", -1160, 4225)
wu.roof_kit("dish_cluster", -1140, 4300, ry=90)
wu.roof_kit("rooftop_shack", -1170, 4336, ry=180)

wu.roof_box(-1196, -1176, 4250, 4290, 12, name="RoofRoom", color=(214, 190, 150), patched=True)
w.roof_box(-1116, -1086, 4304, 4318, 10, name="RoofRoom", color=(160, 200, 190), patched=True)

# 3. East tower on the P01/P02 road: deep horizontal balcony plates (no fins), sky block cantilevered over the yard.
e = Mass(s, "East Tower", -980, -860, 4220, 4380, 120, 520, rng, grid="EN", gables="S", graffiti=("A",),
         fin_step=0, proj=10, patch=0.6, graffiti_h=100)
e.balconies("E", [1, 2], [133.3, 146.7, 173.3], laundry=0.6)
e.laundry_under_plates("E", 3)
e.ac("E", 3)
c = Mass(s, "Sky Block", -1060, -980, 4260, 4340, 420, 500, rng, grid="NS", gables="W", podium=False, graffiti=(),
         gable_base=410)
e.roof_kit("water_tank", -890, 4250)
e.roof_kit("water_tank", -890, 4282)
e.roof_kit("rooftop_shack", -940, 4360, ry=180)
e.roof_kit("antenna_mast", -870, 4370)
c.roof_kit("dish_cluster", -1040, 4300)

e.roof_box(-970, -930, 4290, 4330, 16, name="RoofRoom")
e.roof_box(-926, -906, 4230, 4250, 10, name="RoofRoom", color=(226, 170, 150), patched=True)

# 4. South slab on the step road, stepped: full length to 360, west end rises to 440; wide 80-stud cells.
so = Mass(s, "South Slab", -1180, -900, 4470, 4540, 120, 360, rng, grid="S", gallery="N", gables="WE",
          graffiti=("B",), fin_step=80, graffiti_h=100)
so.balconies("S", [0, 3, 4], [133.3, 146.7], laundry=0.7)
so.laundry_under_plates("S", 4)
so.ac("S", 3)
su = Mass(s, "South Slab Upper", -1180, -1060, 4470, 4540, 360, 440, rng, grid="SN", gables="W", podium=False,
          graffiti=(), gable_base=366)
so.roof_kit("water_tank", -1000, 4490)
so.roof_kit("dish_cluster", -940, 4500, ry=180)
su.roof_kit("rooftop_shack", -1120, 4505, ry=180)
su.roof_kit("water_tank", -1160, 4495)
so.roof_box(-1060, -1030, 4480, 4520, 12, name="RoofRoom", color=(170, 196, 220), patched=True)

# 5. Free-standing lift shaft in the yard, tied to the slabs and towers by access decks.
lift_tower(s, "Lift Shaft", -1044, -1020, 4176, 4200, 560, glass="NS", graffiti="B")
s.group("Access Decks")
walkway(s, -1040, -1024, 4168, 4176, 241.5, rails=False)            # to harbour slab gallery plates
walkway(s, -1040, -1024, 4168, 4176, 321.5, rails=False)
walkway(s, -1072, -1044, 4180, 4196, 401.5)                       # to west tower gallery
walkway(s, -1040, -1024, 4200, 4252, 461.5)                       # to sky block
for y in (241.5, 361.5):                                          # west tower <-> east tower across the yard
    walkway(s, -1072, -981.5, 4252, 4268, y)

if __name__ == "__main__":
    s.save(str(HERE / "P01.json"))
