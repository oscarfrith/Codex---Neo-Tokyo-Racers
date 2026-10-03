"""Write the exported pilot modules into one FBX. Runs in a headless Blender, not the open session:

    blender --background --factory-startup --python scripts/exotic_category/mesh/fbx_export.py

Input: export/<car>/<SLOT>.json (see export.py). Output: export/ExoticPilot.fbx with one object per
module and paint channel, named like A_NOSE_STD__primary. Coordinates are game root space (studs,
+Y up, forward -Z); the round car is offset 20 studs in X.
"""
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "export")
SLOTS = ("COCKPIT", "NOSE", "TAIL", "FPOD", "RPOD", "STAB", "BOOST", "WING")

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

made = 0
for car, ox in (("A", 0.0), ("B", 20.0)):
    for slot in SLOTS:
        with open(os.path.join(ROOT, car, slot + ".json")) as f:
            data = json.load(f)
        for ch, c in data["channels"].items():
            v, n, t = c["v"], c["n"], c["t"]
            verts = [(v[i] + ox, -v[i + 2], v[i + 1]) for i in range(0, len(v), 3)]
            faces = [(t[i], t[i + 1], t[i + 2]) for i in range(0, len(t), 6)]
            name = f"{data['module']}__{ch}"
            me = bpy.data.meshes.new(name)
            me.from_pydata(verts, [], faces)
            me.update()
            me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
            # Hard edges: an edge is sharp when the two triangles on it disagree about the normal at
            # either end. (Setting custom normals directly crashed Blender 4.5 on these meshes.)
            seen, sharp = {}, set()
            for i in range(0, len(t), 6):
                for k in range(3):
                    a, b = t[i + k], t[i + (k + 1) % 3]
                    na, nb = t[i + 3 + k], t[i + 3 + (k + 1) % 3]
                    key, val = ((a, b), (na, nb)) if a < b else ((b, a), (nb, na))
                    if seen.setdefault(key, val) != val:
                        sharp.add(key)
            for e in me.edges:
                a, b = e.vertices
                if ((a, b) if a < b else (b, a)) in sharp:
                    e.use_edge_sharp = True
            ob = bpy.data.objects.new(name, me)
            bpy.context.scene.collection.objects.link(ob)
            ob.select_set(True)
            made += 1

out = os.path.join(ROOT, "ExoticPilot.fbx")
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, global_scale=0.01, axis_forward="-Z", axis_up="Y",
                         object_types={"MESH"}, mesh_smooth_type="OFF", bake_anim=False, add_leaf_bones=False)
print("FBX_DONE", made, os.path.getsize(out) // 1024, "KB")
sys.stdout.flush()
