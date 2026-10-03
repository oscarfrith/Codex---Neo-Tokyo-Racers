"""Export the Exotic pilot modules from Blender, one file per module, split by paint channel.

Inside Blender (after cars.build_all):   import export; export.to_json()
Outside Blender (plain Python):          py -3 scripts/exotic_category/mesh/export.py
    converts every export/<car>/<SLOT>_<TRIM>.json to an .obj next to it, one object per paint channel.

Coordinates are game root space (+X right, +Y up, forward -Z), in studs, relative to the cockpit root.
JSON layout: {"module": key, "channels": {channel: {"v": [x,y,z,...], "n": [x,y,z,...],
"t": [v1,v2,v3,n1,n2,n3,...]}}} with zero-based indices.
fbx_export.py turns these into one FBX in a headless Blender.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "export")
SLOTS = ("COCKPIT", "NOSE", "TAIL", "FPOD", "RPOD", "STAB", "BOOST", "WING")
TRIMS = ("STD", "GT", "EVO")


def to_json(cars=("A", "B")):
    import bpy
    report = {}
    for car in cars:
        folder = os.path.join(OUT, car)
        os.makedirs(folder, exist_ok=True)
        for old in os.listdir(folder):
            os.remove(os.path.join(folder, old))
        for slot in SLOTS:
            for trim in (("STD",) if slot == "COCKPIT" else TRIMS):
                key = f"{car}_{slot}_{trim}"
                coll = bpy.data.collections[f"EXO_{key}"]
                chans = {}
                for ob in coll.objects:
                    me = ob.data
                    me.calc_loop_triangles()
                    normals = me.corner_normals
                    slots = [m.name.split("_", 2)[2] for m in me.materials]
                    for tri in me.loop_triangles:
                        c = chans.setdefault(slots[tri.material_index], {"v": [], "n": [], "t": [], "vi": {}, "ni": {}})
                        ids = []
                        for li, vi in zip(tri.loops, tri.vertices):
                            co = me.vertices[vi].co
                            pk = (round(co.x, 4), round(co.z, 4), round(-co.y, 4))
                            a = c["vi"].setdefault(pk, len(c["vi"]))
                            if a * 3 == len(c["v"]):
                                c["v"].extend(pk)
                            nv = normals[li].vector
                            nk = (round(nv.x, 3), round(nv.z, 3), round(-nv.y, 3))
                            b = c["ni"].setdefault(nk, len(c["ni"]))
                            if b * 3 == len(c["n"]):
                                c["n"].extend(nk)
                            ids.append((a, b))
                        c["t"].extend([ids[0][0], ids[1][0], ids[2][0], ids[0][1], ids[1][1], ids[2][1]])
                data = {ch: {"v": c["v"], "n": c["n"], "t": c["t"]} for ch, c in chans.items()}
                with open(os.path.join(folder, f"{slot}_{trim}.json"), "w") as f:
                    json.dump({"module": key, "channels": data}, f, separators=(",", ":"))
                report[key] = sum(len(c["t"]) // 6 for c in chans.values())
    return report


def to_obj():
    count = 0
    for car in sorted(os.listdir(OUT)):
        folder = os.path.join(OUT, car)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".json"):
                continue
            with open(os.path.join(folder, name)) as f:
                data = json.load(f)
            lines = [f"# {data['module']}  studs, +Y up, forward -Z, one object per paint channel"]
            vo = no = 0
            for ch, c in data["channels"].items():
                v, n, t = c["v"], c["n"], c["t"]
                lines.append(f"o {data['module']}__{ch}")
                lines += [f"v {v[i]} {v[i + 1]} {v[i + 2]}" for i in range(0, len(v), 3)]
                lines += [f"vn {n[i]} {n[i + 1]} {n[i + 2]}" for i in range(0, len(n), 3)]
                for i in range(0, len(t), 6):
                    lines.append("f " + " ".join(f"{t[i + k] + 1 + vo}//{t[i + 3 + k] + 1 + no}" for k in range(3)))
                vo += len(v) // 3
                no += len(n) // 3
            with open(os.path.join(folder, name[:-5] + ".obj"), "w") as f:
                f.write("\n".join(lines) + "\n")
            count += 1
    return count


if __name__ == "__main__":
    print(to_obj(), "obj files written under", OUT)
