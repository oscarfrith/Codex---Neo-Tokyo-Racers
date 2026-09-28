"""Blender headless preview of South Grid specs in context.
blender -b --factory-startup -P preview.py -- --specs A.json [B.json ...] --out out_dir [--cams drone parcel:P01 street:x,y,z,tx,ty,tz top:P01] [--all-specs]
--all-specs also loads every other spec under scripts/south_grid (buildings/*/*.json, streetscape/*.json) as neighbours.
Coordinates in specs are Roblox studs (Y up); converted to Blender (Z up) as (x, -z, y). Renders 1600x900 Workbench PNGs.
Kit pieces use scripts/south_grid/kit/out/obj/<piece>.obj when present (Roblox local coords, centred, exact size), else boxes.
"""
import bpy, json, math, os, sys, glob
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SG = os.path.dirname(HERE)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg_list(flag):
    if flag not in argv: return []
    i = argv.index(flag) + 1; out = []
    while i < len(argv) and not argv[i].startswith("--"): out.append(argv[i]); i += 1
    return out
specs = [os.path.abspath(s) for s in arg_list("--specs")]; out_dir = os.path.abspath((arg_list("--out") or [os.path.join(SG, "preview_out")])[0])
cams = arg_list("--cams") or ["drone"]
if "--all-specs" in argv:
    extra = glob.glob(os.path.join(SG, "buildings", "*", "*.json")) + glob.glob(os.path.join(SG, "streetscape", "*.json"))
    specs = specs + [p for p in extra if os.path.abspath(p) not in map(os.path.abspath, specs)]
os.makedirs(out_dir, exist_ok=True)
CAT = json.load(open(os.path.join(HERE, "kit_catalog.json")))["items"]
PROPS = json.load(open(os.path.join(HERE, "props_catalog.json")))
PARCELS = {p["id"]: p for p in json.load(open(os.path.join(HERE, "parcels.json")))}
CTX = json.load(open(os.path.join(HERE, "context.json")))
OBJDIR = os.path.join(SG, "kit", "out", "obj")

def rot_rbx(rx, ry, rz):
    a, b, c = map(math.radians, (rx, ry, rz))
    return Matrix.Rotation(b, 3, 'Y') @ Matrix.Rotation(a, 3, 'X') @ Matrix.Rotation(c, 3, 'Z')
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # rbx vector -> blender vector
def to_b(v): return P @ Vector(v)

buckets = {}  # key -> (verts, faces, color)
def bucket(color, kind):
    key = (tuple(int(c) for c in color), kind)
    if key not in buckets: buckets[key] = ([], [])
    return buckets[key]
def add(local_verts, faces, R, pos, color, kind="solid"):
    vs, fs = bucket(color, kind); base = len(vs)
    for v in local_verts: vs.append(to_b(R @ Vector(v) + Vector(pos)))
    for f in faces: fs.append([base + i for i in f])

def box(sx, sy, sz, off=(0, 0, 0)):
    x, y, z = sx / 2, sy / 2, sz / 2; ox, oy, oz = off
    v = [(ox + a * x, oy + b * y, oz + c * z) for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return v, f
def wedge(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    v = [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z), (-x, y, z), (x, y, z)]
    return v, [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]
def cylinder(sx, sy, sz, n=16):
    r = min(sy, sz) / 2; h = sx / 2; v = []
    for s in (-h, h):
        for i in range(n): a = 2 * math.pi * i / n; v.append((s, r * math.cos(a), r * math.sin(a)))
    f = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return v, f
def ball(sx, sy, sz, n=12, m=8):
    r = min(sx, sy, sz) / 2; v = [(0, -r, 0)]
    for j in range(1, m):
        t = math.pi * j / m - math.pi / 2
        for i in range(n): a = 2 * math.pi * i / n; v.append((r * math.cos(t) * math.cos(a), r * math.sin(t), r * math.cos(t) * math.sin(a)))
    v.append((0, r, 0)); top = len(v) - 1; f = []
    for i in range(n): f.append((0, 1 + (i + 1) % n, 1 + i))
    for j in range(m - 2):
        for i in range(n):
            a = 1 + j * n + i; b = 1 + j * n + (i + 1) % n; f.append((a, b, b + n, a + n))
    for i in range(n): a = 1 + (m - 2) * n + i; b = 1 + (m - 2) * n + (i + 1) % n; f.append((a, b, top))
    return v, f
SHAPES = {"Block": box, "Wedge": wedge, "CornerWedge": wedge, "Cylinder": cylinder, "Ball": ball}

_objcache = {}
def load_obj(piece):
    if piece in _objcache: return _objcache[piece]
    p = os.path.join(OBJDIR, piece + ".obj"); res = None
    if os.path.exists(p):
        vs, fs = [], []
        for line in open(p):
            if line.startswith("v "): vs.append(tuple(map(float, line.split()[1:4])))
            elif line.startswith("f "): fs.append(tuple(int(t.split("/")[0]) - 1 for t in line.split()[1:]))
        res = (vs, fs)
    _objcache[piece] = res; return res

def color_for(mat, var, color):
    if var.startswith("Windows"): return (58, 74, 98)
    if mat == "Glass": return (90, 130, 160)
    if mat == "Neon": return color
    return color

def draw_spec(doc):
    for e in doc["elements"]:
        R = rot_rbx(*e["rot"]); pos = e["pos"]
        if e["t"] == "part":
            v, f = SHAPES[e["shape"]](*e["size"])
            add(v, f, R, pos, color_for(e["mat"], e["var"], e["color"]), "neon" if e["mat"] == "Neon" else "solid")
        elif e["t"] == "kit":
            it = CAT[e["item"]]; s = e.get("scale", 1.0)
            for k, pc in enumerate(it["pieces"]):
                col = e.get("color") if (k == 0 and e.get("color")) else pc["color"]
                col = color_for(pc["mat"], pc["var"], col)
                off = [o * s for o in pc["offset"]]
                mesh = load_obj(pc["name"])
                if mesh:
                    v = [(a * s + off[0], b * s + off[1], c * s + off[2]) for a, b, c in mesh[0]]; f = mesh[1]
                else:
                    v, f = box(*[d * s for d in pc["size"]], off=off)
                add(v, f, R, pos, col, "neon" if pc["mat"] == "Neon" else "solid")
        elif e["t"] == "clone":
            sz = PROPS.get(e["key"], {"size": [4, 4, 4]})["size"]
            green = any(w in e["key"].lower() for w in ("tree", "bush", "bamboo"))
            v, f = box(*[max(1, s) for s in sz], off=(0, sz[1] / 2 if green else 0, 0))
            add(v, f, R, pos, (70, 150, 80) if green else (80, 80, 90))

def draw_context():
    for row in CTX["blockout_base"]:
        _, x, z, w, l, yaw, top, cy = row[:8]
        h = max(1, (top - cy) * 2)
        add(*box(w, h, l), rot_rbx(0, yaw, 0), (x, cy, z), (150, 200, 220) if top < 95 else (205, 208, 212))
    for row in CTX["blockout_roads"]:
        _, x, z, w, l, yaw, top, cy = row[:8]
        h = max(1, (top - cy) * 2)
        add(*box(w, h, l), rot_rbx(0, yaw, 0), (x, cy, z), (72, 74, 80) if row[8].lower().find("path") < 0 else (170, 172, 176))
    for row in CTX["blockout_buildings"]:
        _, x, z, w, l, yaw, top, cy = row[:8]
        add(*box(w, (top - cy) * 2, l), rot_rbx(0, yaw, 0), (x, cy, z), (182, 192, 208))

def build_objects():
    for (col, kind), (vs, fs) in buckets.items():
        me = bpy.data.meshes.new("m"); me.from_pydata([tuple(v) for v in vs], [], fs); me.update()
        ob = bpy.data.objects.new("o", me); bpy.context.scene.collection.objects.link(ob)
        mat = bpy.data.materials.new("c"); c = [x / 255 for x in col]
        mat.diffuse_color = (c[0], c[1], c[2], 1); ob.data.materials.append(mat)

def camera(pos, target, name):
    cam = bpy.data.cameras.new(name); cam.sensor_fit = 'VERTICAL'; cam.angle_y = math.radians(70); cam.clip_end = 20000
    ob = bpy.data.objects.new(name, cam); bpy.context.scene.collection.objects.link(ob)
    p, t = to_b(pos), to_b(target); ob.location = p
    ob.rotation_euler = (t - p).to_track_quat('-Z', 'Y').to_euler(); return ob

def cam_for(spec):
    if spec == "drone": return (300, 1100, 3300), (0, 150, 4700)
    if spec.startswith("street:") and "," in spec:
        n = list(map(float, spec[7:].split(","))); return tuple(n[:3]), tuple(n[3:])
    kind, pid = spec.split(":")
    p = PARCELS[pid]["parcel"]; cx, cz = (p["x0"] + p["x1"]) / 2, (p["z0"] + p["z1"]) / 2; gy = PARCELS[pid]["groundY"]
    if kind == "top": return (cx, gy + 1600, cz + 1), (cx, gy, cz)
    if kind == "parcel": return (cx + 420, gy + 260, cz - 620), (cx, gy + 220, cz)
    if kind == "street": return (cx + 260, gy + 8, cz - 330), (cx, gy + 160, cz)
    raise ValueError(spec)

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_shadows = True; sc.display.shading.show_cavity = True; sc.display.shading.cavity_type = 'BOTH'
    sc.display.shading.show_object_outline = False; sc.display.shadow_shift = 0.1
    sc.display.light_direction = (0.45, -0.35, 0.82)
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.render.film_transparent = False; sc.view_settings.view_transform = 'Standard'
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.35, 0.62, 0.92)
    sc.display.shading.background_type = 'WORLD'
    draw_context()
    for s in specs: draw_spec(json.load(open(s)))
    build_objects()
    for i, c in enumerate(cams):
        pos, tgt = cam_for(c); ob = camera(pos, tgt, f"cam{i}"); sc.camera = ob
        sc.render.filepath = os.path.join(out_dir, c.replace(":", "_").replace(",", "_") + ".png")
        bpy.ops.render.render(write_still=True)
    print("PREVIEW_DONE", out_dir)
main()
