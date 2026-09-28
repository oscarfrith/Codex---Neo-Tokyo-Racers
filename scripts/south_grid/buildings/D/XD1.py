"""XD1 - agent D's own bridges over the x=-1242 street between P07 and P08 (contract: owners may add bridges
inside their parcel pair). Saved as its own spec (like X1-X6) because it leaves both parcels.
  a) Metabolist glazed tube, 3 x bridge_tube_40, centre Y480 on z=4880: P07 tray N2 east end (x=-1290)
     -> P08 west slab west face (grid front x=-1184). Underside Y471 (road top 201 -> 270 clear).
  b) Steel truss, 3 x bridge_truss_40, centre Y320 on z=5120: P07 tray S1 east end -> P08 west slab.
     Underside Y312 (111 clear).
Run: py -3 XD1.py (after P07.py / P08.py so the floating check sees both landings)
"""
from dlib import Spec, box, check, load_elements, HERE, WHITE, CONC_D

s = Spec("XD1", kind="building", title="P07-P08 bridges", lean="mixed")

s.group("Tube bridge")
for x in (-1270, -1230, -1190):
    s.kit("bridge_tube_40", (x, 480, 4880))
box(s, -1292, -1284, 466, 494, 4866, 4894, var="SG Capsule Panels", color=WHITE, name="Tube collar P07")
box(s, -1192, -1184, 466, 494, 4866, 4894, var="SG Capsule Panels", color=WHITE, name="Tube collar P08")

s.group("Truss bridge")
for x in (-1270, -1230, -1190):
    s.kit("bridge_truss_40", (x, 320, 5120))
box(s, -1292, -1284, 308, 332, 5108, 5132, color=CONC_D, name="Truss portal P07")
box(s, -1192, -1184, 308, 332, 5108, 5132, color=CONC_D, name="Truss portal P08")

s.save(HERE / "XD1.json")
check(s.elements, "XD1", load_elements(HERE / "P07.json") + load_elements(HERE / "P08.json"), ymin_top=0)
