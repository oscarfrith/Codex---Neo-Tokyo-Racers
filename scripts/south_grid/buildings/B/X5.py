"""X5 shared bridge (owner B): P03 south face (z=4576) -> P10 north face (z=4780) over the step, centre line x=400,
deck top Y350, 24 wide, Metabolist tube. Four glazed tube segments on a capsule-panel spine, a porthole pod at mid-span
and square collars at both landings. Underside ~Y339 (road at Y200 below: clearance 139).
Also builds XB34, the optional P03<->P04 truss bridge over the x=765 street (T4 east face x=696 -> S2 west face x=836,
centre z=4440, deck top Y311), saved as XB34.json.
Run: py -3 scripts/south_grid/buildings/B/X5.py
"""
import pathlib
from bkit import Spec, box, WHITE, OFFWHITE, CONC_L, CONC_D

HERE = pathlib.Path(__file__).resolve().parent

# ---------------------------------------------------------------- X5
s = Spec("X5", kind="building", title="X5 Tube Bridge", lean="metabolist")
s.group("X5 Tube")
X, Z0, Z1, DECK = 400, 4576, 4780, 350
TY = DECK + 6  # tube axis: glass floor sits just under the deck top
box(s, X - 6, X + 6, DECK - 2, DECK, Z0, Z1, "", (190, 190, 186), mat="Concrete", name="Deck")
box(s, X - 5, X + 5, DECK - 10, DECK - 2, Z0, Z1, "SG Capsule Panels", WHITE, name="Spine")
box(s, X - 1, X + 1, DECK - 11, DECK - 10, Z0 + 8, Z1 - 8, "", (90, 220, 255), mat="Neon", name="NeonStrip")
# collars (landings) and mid-span pod
for z0, z1 in ((Z0 - 2, Z0 + 6), (Z1 - 6, Z1)):
    box(s, X - 14, X + 14, TY - 15, TY + 15, z0, z1, "SG Capsule Panels", OFFWHITE, name="Collar")
pod = (4662, 4694)
box(s, X - 16, X + 16, TY - 15, TY + 15, pod[0], pod[1], "SG Windows Capsule", WHITE, name="Pod")
box(s, X - 18, X + 18, TY + 14, TY + 17, pod[0] - 2, pod[1] + 2, "SG Capsule Panels", CONC_L, name="PodRoof")
box(s, X - 18, X + 18, TY - 17, TY - 14, pod[0] - 2, pod[1] + 2, "SG Capsule Panels", CONC_L, name="PodFloor")
for zc in (Z0 + 6 + 20, Z0 + 6 + 60, pod[1] + 20, pod[1] + 60):
    s.kit("bridge_tube_40", (X, TY, zc), rot=(0, 90, 0))
s.save(HERE / "X5.json")

# ---------------------------------------------------------------- XB34 (P03 T4 -> P04 S2)
b = Spec("XB34", kind="building", title="XB34 Truss Bridge", lean="blocks")
b.group("XB34 Truss")
XA, XB, ZC, DK = 696, 836, 4440, 311
TYb = DK + 7  # truss 16 tall, deck near its bottom
box(b, XA, XA + 10, TYb - 11, TYb + 11, ZC - 14, ZC + 14, "SG Weathered Concrete", CONC_D, name="Collar")
box(b, XB - 10, XB, TYb - 11, TYb + 11, ZC - 14, ZC + 14, "SG Weathered Concrete", CONC_D, name="Collar")
for xc in (XA + 10 + 20, XA + 10 + 60, XA + 10 + 100):
    b.kit("bridge_truss_40", (xc, TYb, ZC))
box(b, XA + 10, XB - 10, TYb - 10, TYb - 8, ZC - 11, ZC + 11, "SG Weathered Concrete", (160, 158, 152), name="Deck")
box(b, XA + 12, XB - 12, TYb - 11, TYb - 10, ZC - 1, ZC + 1, "", (255, 170, 60), mat="Neon", name="NeonStrip")
b.save(HERE / "XB34.json")
