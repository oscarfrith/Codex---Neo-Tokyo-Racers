"""XA1 extra bridge (A, inside the P01<->P02 pair): inhabited Blocks slab bridge from the P01 East Tower (east face x=-860)
to the P02 Canal Slab (west face x=-720), over the x=-790 road. Floor Y283, top Y322, centre line z=4276.
Underside Y274 clears the road (top Y101) by 173. Run: python XA1.py -> XA1.json"""
import random
from abuild import Spec, box, win, CON, CON_L, PASTEL, HERE

rng = random.Random(7)
s = Spec("XA1", kind="building", title="XA1 Slab Bridge", lean="blocks")
X0, X1 = -860, -720
s.group("Slab Bridge")
box(s, X0, X1, 274, 283, 4256, 4296, color=CON, name="BridgeFloor")
win(s, X0, X1, 283, 317, 4260, 4292, name="BridgeWindows")
box(s, X0, X1, 317, 322, 4257, 4295, color=CON_L, name="BridgeRoof")
for xa in (-822, -758):                                             # two deep fins split the span into thirds
    box(s, xa - 2, xa + 2, 272, 324, 4254, 4298, color=CON, name="BridgeFin")
for za, zb in ((4254.5, 4256), (4296, 4297.5)):                     # patched balcony fronts on both sides
    for xa, xb in ((-856, -826), (-818, -762), (-754, -724)):
        box(s, xa, xb, 283, 291, za, zb, mat="SmoothPlastic", var="SG Patched Panels", color=rng.choice(PASTEL),
            name="PatchedParapet")
s.kit("laundry_line_36", (-790, 270.5, 4259), layer="LOD2")
s.kit("laundry_line_36", (-790, 270.5, 4293), rot=(0, 180, 0), layer="LOD2")

if __name__ == "__main__":
    s.save(str(HERE / "XA1.json"))
