"""South Grid spec builder: write buildings/streetscape as JSON specs the Studio assembler and the Blender preview both read.

Coordinates are Roblox world studs (Y up). Rotations are degrees for CFrame.fromOrientation(rx, ry, rz) (applied Z, X, then Y).
Usage:
    from sgspec import Spec
    s = Spec("P01", kind="building")             # or Spec("streetscape", kind="streetscape")
    s.group("Tower A")                           # later elements go into this sub-model
    s.part("Block", (40, 200, 60), (x, y, z), rot=(0, 15, 0), mat="Concrete", var="Concrete Wood Formed", color=(150,150,146))
    s.kit("capsule_unit", (x, y, z), rot=(0, 90, 0))       # catalog item, optional scale=1.0, color=(..) tints the first piece
    s.clone("Street Lamp Tall A", (x, y, z), rot=(0, 0, 0))  # existing city prop by catalog key (streetscape only)
    s.save("scripts/south_grid/buildings/A/P01.json")      # validates budgets and prints a report
Layers: building masses/facades/bridges -> "LOD4" (default for buildings); small facade clutter visible only near -> "LOD2";
street surfaces/curbs/foliage -> "LOD3"; street props -> "LOD2"; tiny close-up detail -> "LOD1".
"""
import json, math, pathlib

ROOT = pathlib.Path(__file__).resolve().parent
CATALOG = json.load(open(ROOT / "kit_catalog.json"))["items"]
PARCELS = {p["id"]: p for p in json.load(open(ROOT / "parcels.json"))}
PROPS = json.load(open(ROOT / "props_catalog.json")) if (ROOT / "props_catalog.json").exists() else {}
PART_TRIS = {"Block": 12, "Wedge": 8, "CornerWedge": 6, "Cylinder": 64, "Ball": 300}
BUDGET = {"building": {"tris": 20000, "parts": 320, "kit": 160}, "streetscape": {"tris": 60000, "parts": 1500, "kit": 400}}
MATERIALS = {"Plastic", "SmoothPlastic", "Concrete", "Glass", "Metal", "Neon", "Asphalt", "CeramicTiles", "Fabric", "Wood",
             "Brick", "Slate", "Granite", "Marble", "DiamondPlate", "CorrodedMetal", "Foil", "Pavement", "Plaster", "Ground", "Grass", "Cobblestone", "Rock", "Sand", "WoodPlanks"}
VARIANTS = {"", "Concrete Wood Formed", "Concrete Rectangular Panels", "Concrete Square Panels", "Concrete Stylised", "Concrete Square Tiles",
            "Windows Night", "Windows Day", "Tiles Square Small", "Tiles Square Large", "Tiles Rectangular Small", "Bush Grassy", "Metal Shutters",
            "Paving Slab", "Textile Paving", "Asphalt New", "Tiles Rectangular Vertical (Small)", "Tiles Rectangular Horizontal (Small)",
            "Tiles Offset Large", "Glass Shiny", "Vehicle Shiny", "Plywood"}
EXTRA_VARIANTS_FILE = ROOT.parent / "textures" / "variants.json"


def _extra_variants():
    try:
        return {v["name"] for v in json.load(open(EXTRA_VARIANTS_FILE))}
    except Exception:
        return set()


def rot_matrix(rx, ry, rz):
    """Roblox CFrame.fromOrientation: R = Ry * Rx * Rz (degrees). Returns 3x3 rows."""
    a, b, c = map(math.radians, (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    mul = lambda A, B: [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(Ry, Rx), Rz)


def aabb(size, pos, rot):
    """World axis-aligned bounds of an oriented box."""
    R = rot_matrix(*rot)
    half = [abs(R[i][0]) * size[0] / 2 + abs(R[i][1]) * size[1] / 2 + abs(R[i][2]) * size[2] / 2 for i in range(3)]
    return [pos[i] - half[i] for i in range(3)], [pos[i] + half[i] for i in range(3)]


class Spec:
    def __init__(self, sid, kind="building", title="", lean=""):
        self.sid, self.kind, self.title, self.lean = sid, kind, title, lean
        self.elements, self._group = [], ""

    def group(self, name):
        self._group = name
        return self

    def _base(self, t, pos, rot, layer, extra):
        e = {"t": t, "pos": [round(v, 3) for v in pos], "rot": [round(v, 3) for v in rot], "group": self._group,
             "layer": layer or ("LOD4" if self.kind == "building" else "LOD3")}
        e.update(extra)
        self.elements.append(e)
        return e

    def part(self, shape, size, pos, rot=(0, 0, 0), mat="Concrete", var="", color=(160, 160, 160), layer=None,
             collide=True, shadow=True, transparency=0.0, name=None):
        assert shape in PART_TRIS, shape
        assert mat in MATERIALS, f"unknown material {mat}"
        assert var in VARIANTS or var in _extra_variants(), f"unknown MaterialVariant {var!r}"
        return self._base("part", pos, rot, layer, {"shape": shape, "size": [round(v, 3) for v in size], "mat": mat, "var": var,
                                                    "color": list(map(int, color)), "collide": collide, "shadow": shadow,
                                                    "transparency": transparency, "name": name or shape})

    def kit(self, item, pos, rot=(0, 0, 0), scale=1.0, color=None, layer=None, collide=False, name=None):
        assert item in CATALOG, f"unknown kit item {item}"
        extra = {"item": item, "scale": scale, "collide": collide, "name": name or item}
        if color is not None:
            extra["color"] = list(map(int, color))
        return self._base("kit", pos, rot, layer, extra)

    def clone(self, key, pos, rot=(0, 0, 0), layer="LOD2", name=None):
        if PROPS:
            assert key in PROPS, f"unknown prop {key}"
        return self._base("clone", pos, rot, layer, {"key": key, "name": name or key})

    # ---- reporting ----
    def stats(self):
        tris = parts = kits = 0
        lo, hi = [1e9] * 3, [-1e9] * 3
        for e in self.elements:
            if e["t"] == "part":
                parts += 1
                tris += PART_TRIS[e["shape"]]
                a, b = aabb(e["size"], e["pos"], e["rot"])
            elif e["t"] == "kit":
                kits += 1
                it = CATALOG[e["item"]]
                tris += sum(p["tris"] for p in it["pieces"])
                a, b = aabb([s * e["scale"] for s in it["size"]], e["pos"], e["rot"])
            else:
                continue
            lo = [min(lo[i], a[i]) for i in range(3)]
            hi = [max(hi[i], b[i]) for i in range(3)]
        return {"tris": tris, "parts": parts, "kit": kits, "min": [round(v) for v in lo], "max": [round(v) for v in hi]}

    def save(self, path):
        st = self.stats()
        warn = []
        bud = BUDGET[self.kind]
        for k in ("tris", "parts", "kit"):
            if st[k] > bud[k]:
                warn.append(f"OVER BUDGET {k}: {st[k]} > {bud[k]}")
        if self.kind == "building" and self.sid in PARCELS:
            p = PARCELS[self.sid]["parcel"]
            if st["min"][0] < p["x0"] - 1 or st["max"][0] > p["x1"] + 1 or st["min"][2] < p["z0"] - 1 or st["max"][2] > p["z1"] + 1:
                warn.append(f"outside parcel {p} (bounds {st['min']}..{st['max']}); only bridges declared in contract may leave it")
        doc = {"id": self.sid, "kind": self.kind, "title": self.title, "lean": self.lean, "stats": st, "elements": self.elements}
        pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
        json.dump(doc, open(path, "w"), indent=0)
        print(f"{self.sid}: {st}")
        for w in warn:
            print("  WARNING", w)
        return st
