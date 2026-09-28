"""Site model for the South Grid streetscape: roads, ground tops and parcels from common/context.json + parcels.json.
ground(x,z) -> top Y of the highest non-water base under the point (None if water/void).
on_road(x,z,margin) -> top Y of a road containing the point (or within margin studs of it), else None.
in_parcel(x,z,inset) -> parcel id if the point is inside a parcel deeper than `inset` studs from its edge.
"""
import json, math, pathlib
COMMON = pathlib.Path(__file__).resolve().parent.parent / "common"
CTX = json.load(open(COMMON / "context.json"))
PARCELS = json.load(open(COMMON / "parcels.json"))


class OBox:
    def __init__(self, row):
        _, self.x, self.z, self.w, self.l, self.yaw, self.top, self.cy, self.name = row[:9]
        a = math.radians(self.yaw); self.c, self.s = math.cos(a), math.sin(a)
        self.bot = 2 * self.cy - self.top
        r = math.hypot(self.w, self.l) / 2
        self.bb = (self.x - r, self.x + r, self.z - r, self.z + r)

    def local(self, x, z):
        dx, dz = x - self.x, z - self.z
        # inverse of x' = c*lx + s*lz ; z' = -s*lx + c*lz
        return self.c * dx - self.s * dz, self.s * dx + self.c * dz

    def dist_out(self, x, z):
        """<=0 inside (negative depth), >0 distance outside (chebyshev-ish in local frame)."""
        lx, lz = self.local(x, z)
        return max(abs(lx) - self.w / 2, abs(lz) - self.l / 2)


ROADS = [OBox(r) for r in CTX["blockout_roads"]]
BASES = [OBox(r) for r in CTX["blockout_base"] if r[8] != "Water"]


def _near(b, x, z, m):
    return b.bb[0] - m <= x <= b.bb[1] + m and b.bb[2] - m <= z <= b.bb[3] + m


def on_road(x, z, margin=0.0, ymin=-1e9, ymax=1e9):
    best = None
    for r in ROADS:
        if _near(r, x, z, margin) and r.dist_out(x, z) <= margin and ymin <= r.top <= ymax:
            best = r.top if best is None else max(best, r.top)
    return best


def ground(x, z, ymax=400):
    best = None
    for b in BASES:
        if b.top <= ymax and _near(b, x, z, 0) and b.dist_out(x, z) <= 0:
            best = b.top if best is None else max(best, b.top)
    return best


def in_parcel(x, z, inset=0.0):
    for p in PARCELS:
        q = p["parcel"]
        if q["x0"] + inset < x < q["x1"] - inset and q["z0"] + inset < z < q["z1"] - inset:
            return p["id"]
    return None


if __name__ == "__main__":
    import sys
    x0, x1, z0, z1, step = map(float, sys.argv[1:6])
    print("     " + "".join(str(int(x0 + i * step) // 100 % 10) if int(x0 + i * step) % 100 == 0 else " " for i in range(int((x1 - x0) / step) + 1)))
    z = z0
    while z <= z1:
        row = ""
        x = x0
        while x <= x1:
            r = on_road(x, z)
            g = ground(x, z)
            if in_parcel(x, z): ch = "P"
            elif r is not None: ch = "=" if r < 150 else "#"
            elif g is None: ch = "~"
            elif g <= 110: ch = "."
            elif g <= 210: ch = "o"
            else: ch = "^"
            row += ch; x += step
        print("%5d " % z + row); z += step


def road_hit(x, z, margin=0.0, y0=-1e9, y1=1e9):
    """Top Y of a road whose footprint (grown by margin) contains the point AND whose solid/clearance envelope
    [bottom-8, top+60] overlaps the vertical span [y0, y1]. Things well below a viaduct deck do not hit it."""
    best = None
    for r in ROADS:
        if _near(r, x, z, margin) and r.dist_out(x, z) <= margin and y1 > r.bot - 8 and y0 < r.top + 60:
            best = r.top if best is None else max(best, r.top)
    return best


def street_road(x, z, margin=0.0):
    """Top of a street-level road (top ~101 or ~201) containing the point, else None."""
    best = None
    for r in ROADS:
        if (99 <= r.top <= 103 or 199 <= r.top <= 203) and _near(r, x, z, margin) and r.dist_out(x, z) <= margin:
            best = r.top if best is None else max(best, r.top)
    return best
