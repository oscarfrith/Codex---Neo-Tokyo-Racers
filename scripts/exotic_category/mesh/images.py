"""Base renders for the Exotic car card images and the module location diagrams.

Inside Blender, after cars.build_all(render=False):
    import images; images.cards(); images.diagrams()

cards(): one 3:2 front three-quarter render per car (standard version, default colours) under
output/exotic-images/base/. These are the shape reference for the painted card images.
diagrams(): orthographic raw passes of one car for the slot diagrams (whole car in grey; each slot alone in
pink). compose_diagrams.py layers them into the final images, in the convention of the Piercer slot artwork
(Config.UI.GarageReplacement.ModuleArtwork).
"""
import math
import os

import bpy
from mathutils import Vector

import cars
import exokit as K

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(REPO, "output", "exotic-images")
# car letter: (build name, X offset of that build in its row, row Z, cockpit id)
BUILDS = {"A": ("pure0", -cars.SPACING / 2, 0, "exotic_05"), "B": ("pure1", cars.SPACING / 2, 0, "exotic_02"),
          "C": ("new40", -1.5 * cars.SPACING, -140, "exotic_01"), "D": ("new41", -0.5 * cars.SPACING, -140, "exotic_03"),
          "E": ("new42", 0.5 * cars.SPACING, -140, "exotic_04"), "F": ("new43", 1.5 * cars.SPACING, -140, "exotic_06")}
SLOTS = {"Cockpit": "COCKPIT", "FrontBody": "NOSE", "RearBody": "TAIL", "FrontEngine": "FPOD", "RearEngine": "RPOD",
         "Stabilisers": "STAB", "Boost": "BOOST", "Spoiler": "WING"}
PINK = (0.83, 0.02, 0.33)


def _png(rgba):
    s = bpy.context.scene.render
    s.image_settings.file_format = "PNG"
    s.image_settings.color_mode = "RGBA" if rgba else "RGB"
    s.film_transparent = rgba


def _jpeg():
    s = bpy.context.scene.render
    s.film_transparent = False
    s.image_settings.file_format = "JPEG"
    s.image_settings.color_mode = "RGB"


def cards(letters="ABCDEF", az=150, el=11, dist=40):
    os.makedirs(os.path.join(OUT, "base"), exist_ok=True)
    _png(False)
    out = []
    for car in letters:
        name, x, oz, cid = BUILDS[car]
        out.append(K.shot(os.path.join(OUT, "base", f"{cid}.png"), (x, 0.9, oz - 0.5), az, el, dist, lens=50,
                          res=(1536, 1024), only=[name]))
    _jpeg()
    return out


def _flat(name, colour, strength):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Emission Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


def _ortho(target, az, el, scale, path, res):
    scene = bpy.context.scene
    a, e = math.radians(az), math.radians(el)
    d = 200.0
    g = (target[0] + d * math.cos(e) * math.sin(a), target[1] + d * math.sin(e), target[2] + d * math.cos(e) * math.cos(a))
    cam = bpy.data.cameras.new(K.PREFIX + "ortho")
    cam.type = "ORTHO"
    cam.ortho_scale = scale
    cam.clip_end = 2000
    ob = bpy.data.objects.new(K.PREFIX + "ortho", cam)
    ob.location = K.P(*g)
    ob.rotation_euler = (Vector(K.P(*target)) - Vector(K.P(*g))).to_track_quat("-Z", "Y").to_euler()
    bpy.data.collections[K.PREFIX + "STAGE"].objects.link(ob)
    scene.camera = ob
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def diagrams(car="C", az=142, el=36, scale=25.0, res=(1024, 1024), oversize=(("Boost", 1.35), ("Spoiler", 1.35)),
             alt=(("Spoiler", "trims_c1", "GT"),)):
    """Raw passes for the slot diagrams, front three-quarter orthographic view, transparent background:
    raw/base.png is the whole car in flat light grey; raw/<slot>.png is that slot alone in pink, drawn
    without the rest of the car so it shows even where the body would hide it. Slots in `oversize` are
    scaled up about their own centre so a small part still reads; a slot in `alt` is drawn from another build
    (the GT wing, which is easier to recognise than the standard lip). compose_diagrams.py layers the passes."""
    raw = os.path.join(OUT, "diagrams", "raw")
    os.makedirs(raw, exist_ok=True)
    name, x, oz, _ = BUILDS[car]
    white, pink = _flat(K.PREFIX + "diagram_white", (0.7, 0.71, 0.74), 0.12), _flat(K.PREFIX + "diagram_pink", PINK, 0.35)
    ground = bpy.data.objects.get(K.PREFIX + "ground")
    scene = bpy.context.scene
    freestyle = scene.render.use_freestyle
    builds = bpy.data.collections[K.PREFIX + "BUILDS"].objects
    colls = {slot: bpy.data.collections[f"{K.PREFIX}{car}_{code}_STD"] for slot, code in SLOTS.items()}
    empties = {slot: builds[f"{K.PREFIX}{name}_{car}_{code}_STD"] for slot, code in SLOTS.items()}
    saved = {ob.name: list(ob.data.materials) for c in colls.values() for ob in c.objects}
    hidden = {e.name: e.hide_render for e in builds}
    grow = dict(oversize)
    for slot, row, trim in alt:   # the highlight pass of this slot uses another version, moved onto this car
        code = SLOTS[slot]
        other = builds[f"{K.PREFIX}{row}_{car}_{code}_{trim}"]
        hidden_home = other.location.copy()
        other.location = empties[slot].location.copy()
        colls[slot + "#alt"] = bpy.data.collections[f"{K.PREFIX}{car}_{code}_{trim}"]
        empties[slot + "#alt"] = other
        saved.update({ob.name: list(ob.data.materials) for ob in colls[slot + "#alt"].objects})
        hidden[other.name + "#home"] = hidden_home

    def paint(mat):
        for c in colls.values():
            for ob in c.objects:
                for i in range(len(ob.data.materials)):
                    ob.data.materials[i] = mat

    def show(slots):
        for e in builds:
            e.hide_render = True
        for slot in slots:
            empties[slot].hide_render = False

    def centre(coll):
        pts = [ob.matrix_world @ v.co for ob in coll.objects for v in ob.data.vertices]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        return (lo + hi) / 2

    out = []
    try:
        scene.render.use_freestyle = False
        if ground:
            ground.hide_render = True
        _png(True)
        target = (x, 1.0, oz + 0.3)
        paint(white)
        show(list(SLOTS))
        out.append(_ortho(target, az, el, scale, os.path.join(raw, "base.png"), res))
        paint(pink)
        out.append(_ortho(target, az, el, scale, os.path.join(raw, "All.png"), res))
        for slot in SLOTS:
            key = slot + "#alt" if slot + "#alt" in empties else slot
            show([key])
            e, k = empties[key], grow.get(slot, 1.0)
            home = e.location.copy()
            if k != 1.0:
                e.scale = (k, k, k)
                e.location = home + (1.0 - k) * centre(colls[key])
            try:
                out.append(_ortho(target, az, el, scale, os.path.join(raw, f"{slot}.png"), res))
            finally:
                e.scale = (1.0, 1.0, 1.0)
                e.location = home
        # Thrust colour: only the glowing thrust faces (nozzle backs and lift pads), everything else see-through.
        clear = bpy.data.materials.get(K.PREFIX + "diagram_clear") or bpy.data.materials.new(K.PREFIX + "diagram_clear")
        clear.use_nodes = True
        clear.node_tree.nodes.clear()
        node_out = clear.node_tree.nodes.new("ShaderNodeOutputMaterial")
        node_bsdf = clear.node_tree.nodes.new("ShaderNodeBsdfTransparent")
        clear.node_tree.links.new(node_bsdf.outputs[0], node_out.inputs[0])
        for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(clear, attr, value)
            except (AttributeError, TypeError):
                pass
        show(list(SLOTS))
        for slot in SLOTS:
            for ob in colls[slot].objects:
                for i, m in enumerate(saved[ob.name]):
                    ob.data.materials[i] = pink if m.name.endswith("_thrust") else clear
        out.append(_ortho(target, az, el, scale, os.path.join(raw, "ThrustColour.png"), res))
    finally:
        for c in colls.values():
            for ob in c.objects:
                for i, m in enumerate(saved[ob.name]):
                    ob.data.materials[i] = m
        for e in builds:
            e.hide_render = hidden[e.name]
            if e.name + "#home" in hidden:
                e.location = hidden[e.name + "#home"]
        if ground:
            ground.hide_render = False
        scene.render.use_freestyle = freestyle
        _jpeg()
    return out
