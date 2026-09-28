"""Kit smoke-test spec (not a building): one block on P01 dressed with most kit items, for common/preview.py.
python scripts/south_grid/kit/test/kit_test.py  -> kit/test/kit_test.json
"""
import sys, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "common"))
from sgspec import Spec

s = Spec("KITTEST", kind="building", title="kit smoke test")
X0, G, ZF = -1300, 100, 4280            # block centre x, ground, front face z
s.part("Block", (120, 120, 40), (X0, G + 60, ZF + 20), mat="Concrete", var="Concrete Wood Formed", color=(160, 160, 156))
for row in range(3):                    # balcony grid + infill, laundry under the middle row
    y = G + 13.3 * (row + 3) + 6.5
    for col in range(3):
        x = X0 - 40 + 40 * col
        s.kit("balcony_run_40", (x, y, ZF - 4))
        if row == 1:
            s.kit("laundry_line_36", (x, y - 3, ZF - 8.6))
s.kit("tray_edge_40", (X0 - 40, G + 40, ZF - 7)); s.kit("tray_edge_40", (X0, G + 40, ZF - 7)); s.kit("tray_edge_40", (X0 + 40, G + 40, ZF - 7))
for col in range(3):
    s.kit("porthole_panel_40", (X0 - 40 + 40 * col, G + 100, ZF - 1.5))
s.kit("louvre_fins_40", (X0 - 40, G + 20, ZF - 2.5))
s.kit("pipe_bundle_40", (X0 + 62, G + 20, ZF - 1.5)); s.kit("pipe_bundle_40", (X0 + 62, G + 60, ZF - 1.5))
s.kit("ac_cluster", (X0 + 30, G + 20, ZF - 2)); s.kit("ac_cluster", (X0 + 45, G + 28, ZF - 2))
s.kit("ext_stair_40", (X0 - 68, G + 20, ZF + 8), rot=(0, 90, 0))
for k in range(3):                      # capsules hanging off the east face
    s.kit("capsule_unit", (X0 + 60 + 8, G + 30 + 14 * k, ZF + 14), rot=(0, 90, 0))
s.kit("water_tank", (X0 - 30, G + 131, ZF + 20)); s.kit("dish_cluster", (X0 + 5, G + 126, ZF + 10))
s.kit("antenna_mast", (X0 + 45, G + 150, ZF + 30)); s.kit("rooftop_shack", (X0 + 25, G + 126, ZF + 28))
s.kit("bridge_truss_40", (X0 - 80, G + 90, ZF + 20)); s.kit("bridge_tube_40", (X0 - 120, G + 90, ZF + 20))
s.kit("market_stall", (X0 - 20, G + 7, ZF - 30)); s.kit("vending_machine", (X0 + 10, G + 4.5, ZF - 6))
s.kit("bench_concrete", (X0 + 30, G + 1.5, ZF - 25))
for k in range(3):
    s.kit("chainlink_fence_20", (X0 + 40 + 20 * k, G + 6, ZF - 45))
s.save(HERE / "kit_test.json")
