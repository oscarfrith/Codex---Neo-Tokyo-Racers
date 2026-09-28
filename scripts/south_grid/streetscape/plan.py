"""Top-down 2D plan (PIL) of the South Grid context + streetscape specs, for checking road clearance.
python plan.py [--spec a.json ...] [--out plan.png] [--box x0 x1 z0 z1] [--scale px_per_stud]
Roads dark grey, Y200 base tan, Y100 base light, water blue, parcels red outlines, spec parts coloured by their color.
"""
import json, math, sys, pathlib
from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).resolve().parent
COMMON = HERE.parent / "common"
sys.path.insert(0, str(COMMON))
from sgspec import rot_matrix, CATALOG, PROPS  # noqa

argv = sys.argv[1:]
def opt(flag, n=1, default=None):
    if flag not in argv: return default
    i = argv.index(flag); return argv[i + 1:i + 1 + n] if n > 1 else argv[i + 1]
specs = []
if "--spec" in argv:
    i = argv.index("--spec") + 1
    while i < len(argv) and not argv[i].startswith("--"): specs.append(argv[i]); i += 1
box = list(map(float, opt("--box", 4, ["-1950", "2950", "3950", "5350"])))
S = float(opt("--scale", 1, "0.4"))
out = opt("--out", 1, str(HERE / "preview" / "plan.png"))
X0, X1, Z0, Z1 = box
W, H = int((X1 - X0) * S), int((Z1 - Z0) * S)
img = Image.new("RGB", (W, H), (120, 170, 210)); d = ImageDraw.Draw(img)
def px(x, z): return ((x - X0) * S, (z - Z0) * S)  # +z down the image (south down)

def poly(x, z, w, l, yaw):
    a = math.radians(yaw); c, s = math.cos(a), math.sin(a)
    pts = []
    for dx, dz in ((-w / 2, -l / 2), (w / 2, -l / 2), (w / 2, l / 2), (-w / 2, l / 2)):
        # Roblox yaw about +Y: x' = c*dx + s*dz, z' = -s*dx + c*dz
        pts.append(px(x + c * dx + s * dz, z - s * dx + c * dz))
    return pts

CTX = json.load(open(COMMON / "context.json"))
for r in sorted(CTX["blockout_base"], key=lambda r: r[6]):
    _, x, z, w, l, yaw, top, cy, name = r[:9]
    col = (120, 170, 210) if name == "Water" else ((214, 196, 160) if top >= 150 else (225, 225, 222))
    if top > 300: col = (190, 170, 140)
    d.polygon(poly(x, z, w, l, yaw), fill=col)
for r in CTX["blockout_roads"]:
    _, x, z, w, l, yaw, top, cy, name = r[:9]
    d.polygon(poly(x, z, w, l, yaw), fill=(70, 70, 76) if top < 150 else (40, 40, 60))
for p in json.load(open(COMMON / "parcels.json")):
    q = p["parcel"]; d.rectangle([px(q["x0"], q["z0"]), px(q["x1"], q["z1"])], outline=(200, 30, 30), width=2)
    d.text(px(q["x0"] + 10, q["z0"] + 10), p["id"], fill=(160, 0, 0))

for sp in specs:
    doc = json.load(open(sp))
    for e in doc["elements"]:
        if e["t"] == "part": size, col = e["size"], tuple(e["color"])
        elif e["t"] == "kit": size, col = [v * e["scale"] for v in CATALOG[e["item"]]["size"]], (255, 140, 0)
        else:
            size = PROPS.get(e["key"], {"size": [4, 4, 4]})["size"]; col = (40, 150, 60) if "Tree" in e["key"] or "ush" in e["key"] else (20, 20, 20)
        R = rot_matrix(*e["rot"])
        half = [v / 2 for v in size]
        a, b = sorted(range(3), key=lambda i: -(R[0][i] ** 2 + R[2][i] ** 2) * max(half[i], 0.01))[:2]
        pts = []
        for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            la, lb = dx * half[a], dz * half[b]
            pts.append(px(e["pos"][0] + R[0][a] * la + R[0][b] * lb, e["pos"][2] + R[2][a] * la + R[2][b] * lb))
        d.polygon(pts, fill=col, outline=(0, 0, 0) if e["t"] != "part" else None)

for gx in range(int(X0 // 100 * 100), int(X1) + 1, 100):
    d.line([px(gx, Z0), px(gx, Z1)], fill=(255, 255, 255) if gx % 500 else (255, 255, 0), width=1)
    d.text(px(gx + 2, Z0 + 2), str(gx), fill=(0, 0, 0))
for gz in range(int(Z0 // 100 * 100), int(Z1) + 1, 100):
    d.line([px(X0, gz), px(X1, gz)], fill=(255, 255, 255) if gz % 500 else (255, 255, 0), width=1)
    d.text(px(X0 + 2, gz + 2), str(gz), fill=(0, 0, 0))
pathlib.Path(out).parent.mkdir(parents=True, exist_ok=True)
img.save(out); print("PLAN", out, W, H)
