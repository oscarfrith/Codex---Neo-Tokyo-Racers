"""Agent C helper: road-clearance check + top-down plan PNG for C's specs.
python _plan.py P05.json P12.json X6.json [--png out.png] [--box x0,z0,x1,z1]
Flags any element whose footprint overlaps a blockout road unless its underside is >= road top + 60.
"""
import json, sys, pathlib, math
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "common"))
from sgspec import rot_matrix, CATALOG, PARCELS

CTX = json.load(open(HERE.parents[1] / "common" / "context.json"))


def rect(x, z, w, l, yaw):
    R = rot_matrix(0, yaw, 0)
    pts = []
    for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = a * w / 2, b * l / 2
        pts.append((x + R[0][0] * lx + R[0][2] * lz, z + R[2][0] * lx + R[2][2] * lz))
    return pts


def elem_poly(e):
    if e["t"] == "part":
        size = e["size"]
    elif e["t"] == "kit":
        size = [s * e.get("scale", 1) for s in CATALOG[e["item"]]["size"]]
    else:
        return None, None, None
    R = rot_matrix(*e["rot"])
    hx, hy, hz = [s / 2 for s in size]
    pts3 = []
    for a in (-1, 1):
        for b in (-1, 1):
            for c in (-1, 1):
                l = (a * hx, b * hy, c * hz)
                pts3.append([e["pos"][i] + sum(R[i][k] * l[k] for k in range(3)) for i in range(3)])
    ys = [p[1] for p in pts3]
    # 2D hull of projected points (convex)
    pts = sorted(set((round(p[0], 3), round(p[2], 3)) for p in pts3))
    return hull(pts), min(ys), max(ys)


def hull(pts):
    if len(pts) < 3:
        return pts
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def sat(A, B):
    for P in (A, B):
        n = len(P)
        for i in range(n):
            x1, z1 = P[i]; x2, z2 = P[(i + 1) % n]
            ax, az = z2 - z1, x1 - x2
            pa = [ax * x + az * z for x, z in A]; pb = [ax * x + az * z for x, z in B]
            if max(pa) <= min(pb) + 0.01 or max(pb) <= min(pa) + 0.01:
                return False
    return True


def main():
    args = sys.argv[1:]
    png = None; box = None
    if "--png" in args:
        i = args.index("--png"); png = args[i + 1]; del args[i:i + 2]
    if "--box" in args:
        i = args.index("--box"); box = list(map(float, args[i + 1].split(","))); del args[i:i + 2]
    roads = [(r, rect(r[1], r[2], r[3], r[4], r[5])) for r in CTX["blockout_roads"]]
    specs = [json.load(open(a)) for a in args]
    bad = 0
    polys = []
    for s in specs:
        for e in s["elements"]:
            poly, y0, y1 = elem_poly(e)
            if not poly: continue
            polys.append((s["id"], e, poly, y0, y1))
            for r, rp in roads:
                if sat(poly, rp):
                    top = r[6]
                    if y0 < top + 60:
                        bad += 1
                        print(f"ROAD CLASH {s['id']} {e.get('group')} {e.get('name')} pos={e['pos']} y={y0:.0f}..{y1:.0f} road={r[1:8]}")
    print("road clashes:", bad)
    if png:
        from PIL import Image, ImageDraw
        x0, z0, x1, z1 = box or (1050, 4000, 1900, 5320)
        S = 1400 / max(x1 - x0, z1 - z0)
        W, H = int((x1 - x0) * S), int((z1 - z0) * S)
        im = Image.new("RGB", (W, H), (235, 235, 230)); d = ImageDraw.Draw(im)
        T = lambda p: ((p[0] - x0) * S, (p[1] - z0) * S)
        for r, rp in roads:
            d.polygon([T(p) for p in rp], fill=(90, 90, 95) if r[6] < 150 else (60, 60, 120))
        for pid, p in PARCELS.items():
            q = p["parcel"]; d.rectangle([T((q["x0"], q["z0"])), T((q["x1"], q["z1"]))], outline=(200, 40, 40))
            d.text(T((q["x0"] + 5, q["z0"] + 5)), pid, fill=(200, 40, 40))
        polys.sort(key=lambda t: t[4])
        for sid, e, poly, y0, y1 in polys:
            g = int(max(0, min(255, 255 - (y1 - 100) / 4)))
            col = (255, 80, 200) if e.get("mat") == "Neon" else ((g, 160, 90) if e["t"] == "kit" else (g, g, 255 - g // 3))
            d.polygon([T(p) for p in poly], fill=col, outline=(20, 20, 20))
        for gx in range(int(x0 // 100 * 100), int(x1), 100):
            d.line([T((gx, z0)), T((gx, z0 + 15 / S))], fill=(0, 0, 0)); d.text(T((gx + 2, z0)), str(gx), fill=(0, 0, 0))
        for gz in range(int(z0 // 100 * 100), int(z1), 100):
            d.line([T((x0, gz)), T((x0 + 15 / S, gz))], fill=(0, 0, 0)); d.text(T((x0 + 2, gz)), str(gz), fill=(0, 0, 0))
        im.save(png); print("plan ->", png)


if __name__ == "__main__":
    main()
