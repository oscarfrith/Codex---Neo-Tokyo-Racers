"""X3 - glazed Metabolist tube bridge P11 east face (x=1030 portal) -> P12 west face (x=1146), deck top Y470, centre z=4960. Agent F.
Two bridge_tube_40 segments over the x=1108 road (underside ~Y469, road top Y201) between two round concrete collar heads.
The east head ends at x1148, butting the landing deck + head C built at x1146-1170; the west head sits inside the portal collar
P11.py builds on the E tower east face.
Run: py -3 X3.py
"""
import sys, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "common"))
from sgspec import Spec

s = Spec("X3", kind="building", title="X3 tube bridge P11-P12", lean="metabolist")
Z, DECK = 4960, 470
YC = DECK - 1.5 + 9        # tube kit: 18 across, floor ~1.5 above the underside
s.group("X3 Bridge")
for x in (1066, 1106):
    s.kit("bridge_tube_40", (x, YC, Z))
C = (212, 209, 200)
# round collar heads (cylinder axis along X)
s.part("Cylinder", (16, 26, 26), (1038, YC, Z), mat="Concrete", var="SG Capsule Panels", color=C, name="HeadWest")
s.part("Cylinder", (22, 26, 26), (1137, YC, Z), mat="Concrete", var="SG Capsule Panels", color=C, name="HeadEast")
# mid-span ring stiffener + thin cyan neon floor strip
s.part("Cylinder", (4, 24, 24), (1086, YC, Z), mat="Concrete", color=(180, 178, 170), name="MidRing")
s.part("Block", (80, 0.6, 1), (1086, YC - 8.3, Z - 7.2), mat="Neon", color=(60, 230, 255), layer="LOD2", name="NeonStrip")
s.save(str(HERE / "X3.json"))
