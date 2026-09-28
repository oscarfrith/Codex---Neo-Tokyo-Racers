"""X6: shared bridge (owner C), P05 south (W1 south end wall, z~4558) -> P12 north (podium face, z~4796).
The Blocks enclosed slab bridge: 30-deep concrete box girder, walking deck top Y360, patched-panel parapets,
continuous glazing band, roof slab, chunky mullion fins on the 40-stud grid, sodium strip lights, landing collars.
Centre line x=1450, width 24. Clears the Y101 and Y201 step roads by >120 studs.
Run: python X6.py -> X6.json
"""
import pathlib
from _cb import *  # noqa: F401,F403

OUT = pathlib.Path(__file__).resolve().parent / "X6.json"
s = Spec("X6", kind="building", title="X6 Blocks slab bridge (P05 - P12)", lean="blocks")
X, W = 1450, 24
Z0, Z1 = 4558, 4796          # landing faces: P05 W1 south mural face, P12 podium deck edge
DECK = 360
x0, x1 = X - W / 2, X + W / 2
s.group("X6 bridge")
box(s, x0, x1, DECK - 30, DECK - 1, Z0, Z1, CONC, name="Box girder")
box(s, x0 - 2, x1 + 2, DECK - 1, DECK, Z0, Z1, CONC_D, name="Deck edge")
box(s, x0 - 2, x0, DECK, DECK + 6, Z0, Z1, PATCH, name="Parapet W")
box(s, x1, x1 + 2, DECK, DECK + 6, Z0, Z1, PATCH, name="Parapet E")
box(s, x0 - 1, x1 + 1, DECK + 6, DECK + 16, Z0, Z1, GLASS, name="Glazing band")
box(s, x0 - 3, x1 + 3, DECK + 16, DECK + 20, Z0, Z1, CONC, name="Roof slab")
for z in grid(Z0, Z1, 40):
    box(s, x0 - 3, x0 - 1, DECK - 30, DECK + 16, z - 1.5, z + 1.5, CONC_D, name="Mullion fin")
    box(s, x1 + 1, x1 + 3, DECK - 30, DECK + 16, z - 1.5, z + 1.5, CONC_D, name="Mullion fin")
neon(s, x0 - 3.5, x0 - 3, DECK + 14, DECK + 15, Z0 + 4, Z1 - 4, (255, 170, 60), name="Sodium strip")
neon(s, x1 + 3, x1 + 3.5, DECK + 14, DECK + 15, Z0 + 4, Z1 - 4, (255, 170, 60), name="Sodium strip")
# landing collars on both buildings
for za, zb in ((Z0, Z0 + 8), (Z1 - 8, Z1)):
    box(s, x0 - 6, x1 + 6, DECK - 34, DECK + 24, za, zb, BOARD_D, name="Landing collar")
s.save(OUT)
