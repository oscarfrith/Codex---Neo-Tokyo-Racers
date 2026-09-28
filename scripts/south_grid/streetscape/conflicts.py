"""Report where streetscape elements intersect the building agents' current specs (buildings/*/*.json).
python conflicts.py            -> summary per building spec + first offenders
Test: 3D oriented-box overlap (streetscape sample points inside a building part's box, with a 0.3 stud tolerance).
"""
import glob, json, math, pathlib, sys
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "common"))
from sgspec import rot_matrix, CATALOG, PROPS  # noqa

def boxes(doc):
    out = []
    for e in doc["elements"]:
        if e["t"] == "part": size = e["size"]
        elif e["t"] == "kit": size = [v * e.get("scale", 1) for v in CATALOG[e["item"]]["size"]]
        else: continue
        if e["t"] == "part" and e.get("transparency", 0) >= 0.99: continue
        R = rot_matrix(*e["rot"])
        out.append((e, size, R))
    return out

def inside(p, e, size, R, tol=0.3):
    d = [p[i] - e["pos"][i] for i in range(3)]
    for k in range(3):   # local coords = R^T d
        l = R[0][k] * d[0] + R[1][k] * d[1] + R[2][k] * d[2]
        if abs(l) > size[k] / 2 - tol: return False
    return True

def samples(e):
    if e["t"] == "clone":
        h = PROPS.get(e["key"], {"size": [1, 4, 1]})["size"][1]
        x, y, z = e["pos"]; return [(x, y + 1, z), (x, y + h * 0.3, z)]
    size = e["size"] if e["t"] == "part" else [v * e.get("scale", 1) for v in CATALOG[e["item"]]["size"]]
    R = rot_matrix(*e["rot"]); pts = []
    n = [max(1, int(size[k] / 6)) for k in range(3)]
    for i in range(n[0] + 1):
        for j in range(n[1] + 1):
            for k in range(n[2] + 1):
                l = [(-0.5 + i / n[0]) * size[0] * 0.9, (-0.5 + j / n[1]) * size[1] * 0.9, (-0.5 + k / n[2]) * size[2] * 0.9]
                pts.append(tuple(e["pos"][r] + sum(R[r][c] * l[c] for c in range(3)) for r in range(3)))
    return pts

bld = {}
for f in glob.glob(str(HERE.parent / "buildings" / "*" / "*.json")):
    try: bld[pathlib.Path(f).stem] = boxes(json.load(open(f)))
    except Exception as ex: print("skip", f, ex)
total = 0
for f in sorted(glob.glob(str(HERE / "streetscape_*.json"))):
    doc = json.load(open(f))
    for e in doc["elements"]:
        pts = samples(e)
        lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
        for bid, bx in bld.items():
            for (be, size, R) in bx:
                r = math.sqrt(sum(v * v for v in size)) / 2
                if any(lo[i] > be["pos"][i] + r or hi[i] < be["pos"][i] - r for i in range(3)): continue
                if any(inside(p, be, size, R) for p in pts):
                    total += 1
                    print(f"{pathlib.Path(f).stem:24s} {e.get('name', e.get('key')):22s} {[round(v) for v in e['pos']]} x {bid}:{be.get('name')} {[round(v) for v in be['pos']]}")
                    break
print("CONFLICTS", total)
