"""X2 - truss skybridge P10 east face (x=530) -> P11 west face (x=630 recess), deck top Y400, centre line z=5060. Agent F.
Two bridge_truss_40 segments over the x=568 road (underside Y399, road top Y201 -> ~198 clearance) between two solid
concrete bridge heads. The west head pushes 6 studs into P10 (x524) so it enters E's landing recess; the east head sits
inside the portal collar P11.py builds on the W tower west face.
Run: py -3 X2.py
"""
import sys, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "common"))
from sgspec import Spec

s = Spec("X2", kind="building", title="X2 truss bridge P10-P11", lean="blocks")
Z, DECK = 5060, 400
YC = DECK - 1 + 8          # truss kit: 16 tall, deck surface ~1 stud above its underside
s.group("X2 Bridge")
for x in (560, 600):
    s.kit("bridge_truss_40", (x, YC, Z))
# solid heads (chunky concrete collars that plug into both facades)
C = (196, 193, 184)
s.part("Block", (16, 26, 28), (532, DECK + 5, Z), mat="Concrete", var="SG Weathered Concrete", color=C, name="HeadWest")
s.part("Block", (12, 26, 28), (626, DECK + 5, Z), mat="Concrete", var="SG Weathered Concrete", color=C, name="HeadEast")
# walkway deck slab + under-beam carries the span visually (chunky, 40-grid)
s.part("Block", (80, 3, 22), (580, DECK - 2.5, Z), mat="Concrete", color=(150, 148, 141), name="DeckSlab")
s.part("Block", (104, 4, 6), (578, DECK - 6, Z), mat="Metal", color=(96, 100, 104), name="UnderBeam")
# a drooping cable of laundry some resident strung along the truss (lived-in)
s.kit("laundry_line_36", (580, DECK - 12, Z - 11), layer="LOD2", color=(235, 210, 120))
s.part("Block", (30, 3, 0.6), (580, DECK + 13, Z - 10.4), mat="Neon", color=(60, 230, 255), layer="LOD2", name="NeonStrip")
s.save(str(HERE / "X2.json"))
