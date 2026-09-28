"""X4 shared bridge (owner A): P02 south face (z=4576) -> P09 north face (z=4780) over the step, deck top Y330, x=-400,
width 24. Truss deck on a pier + an exterior stair tower standing on the Y200 terrace strip (z 4661-4705).
Run: python X4.py -> X4.json"""
from abuild import Spec, box, CON, CON_L, CON_D, STEEL, HERE

s = Spec("X4", kind="building", title="X4 Step Truss Bridge", lean="blocks")
X0, X1, Z0, Z1, DECK = -412, -388, 4576, 4780, 330

s.group("Deck")
box(s, X0, X1, DECK - 4, DECK, Z0 + 6, Z1 - 6, color=CON_L, name="Deck")
for zc in (Z0 + 30, Z0 + 78, Z0 + 126, Z0 + 174):                  # 4 x 48-stud truss segments (kit at scale 1.2)
    s.kit("bridge_truss_40", ((X0 + X1) / 2, DECK + 9.6, zc), rot=(0, 90, 0), scale=1.2, color=STEEL)
for za, zb in ((Z0, Z0 + 6), (Z1 - 6, Z1)):                          # concrete portal collars at both landings
    box(s, X0 - 2, X1 + 2, DECK - 6, DECK + 22, za, zb, color=CON, name="Portal")

s.group("Pier")
box(s, X0 + 4, X1 - 4, 200, DECK - 4, 4672, 4694, color=CON, name="Pier")
box(s, X0 + 1, X1 - 1, 200, 212, 4669, 4697, var="SG Graffiti A", color=(196, 194, 188), name="PierFoot")

s.group("Stair Tower")
TX0, TX1, TZ0, TZ1 = -380, -352, 4668, 4698
box(s, TX0, TX1, 200, 280, TZ0, TZ1, var="SG Graffiti B", color=(196, 194, 188), name="TowerGraffiti")
box(s, TX0, TX1, 280, 352, TZ0, TZ1, color=CON, name="TowerCore")
box(s, TX0 - 2, TX1 + 2, 352, 362, TZ0 - 2, TZ1 + 2, color=CON_D, name="TowerCap")
for i in range(3):                                                  # steel switchback stairs on the east face
    s.kit("ext_stair_40", (TX1 + 5, 220 + 40 * i, (TZ0 + TZ1) / 2), rot=(0, -90, 0))
box(s, X1, TX0, DECK - 4, DECK, TZ0 + 3, TZ1 - 3, color=CON_L, name="Landing")    # deck -> tower landing
box(s, X1, TX0, DECK, DECK + 4.5, TZ1 - 4.5, TZ1 - 3, mat="Metal", var="", color=STEEL, name="LandingRail")
box(s, TX1, TX1 + 10, 320, 324, TZ0 + 7, TZ1 - 7, color=CON_L, name="StairTopLanding")

if __name__ == "__main__":
    s.save(str(HERE / "X4.json"))
