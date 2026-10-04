"""Base renders for the Exotic car card images and the module location diagrams.

Inside Blender, after cars.build_all(render=False):
    import images; images.cards(); images.diagrams()

cards(): one 3:2 front three-quarter render per car (standard version, default colours) under
output/exotic-images/base/. These are the shape reference for the painted card images.
diagrams(): orthographic renders of one car with a transparent background, the whole car in white and one
slot in pink, in the convention of the Piercer slot artwork (Config.UI.GarageReplacement.ModuleArtwork).
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


def diagrams(car="C", views=(("rear", 38, 36),), scale=25.0, res=(1024, 1024)):
    """One image per slot and view: the car in light grey, the slot in pink, thin outlines, transparent
    background. The high rear three-quarter view is the one angle that shows all seven slots."""
    os.makedirs(os.path.join(OUT, "diagrams"), exist_ok=True)
    name, x, oz, _ = BUILDS[car]
    white, pink = _flat(K.PREFIX + "diagram_white", (0.62, 0.63, 0.66), 0.0), _flat(K.PREFIX + "diagram_pink", PINK, 0.9)
    scene = bpy.context.scene
    freestyle = scene.render.use_freestyle
    scene.render.use_freestyle = True
    scene.render.line_thickness = 1.4
    ground = bpy.data.objects.get(K.PREFIX + "ground")
    for e in bpy.data.collections[K.PREFIX + "BUILDS"].objects:
        e.hide_render = not e.name.startswith(K.PREFIX + name + "_")
    colls = {slot: bpy.data.collections[f"{K.PREFIX}{car}_{code}_STD"] for slot, code in SLOTS.items()}
    saved = {ob.name: list(ob.data.materials) for c in colls.values() for ob in c.objects}

    def paint(target):
        for slot, c in colls.items():
            mat = pink if target in (slot, "All") else white
            for ob in c.objects:
                for i in range(len(ob.data.materials)):
                    ob.data.materials[i] = mat

    out = []
    try:
        if ground:
            ground.hide_render = True
        _png(True)
        for slot in ["All"] + list(SLOTS):
            paint(slot)
            for tag, az, el in views:
                out.append(_ortho((x, 1.0, oz + 0.3), az, el, scale, os.path.join(OUT, "diagrams", f"{slot}.png" if len(views) == 1 else f"{slot}_{tag}.png"), res))
    finally:
        for c in colls.values():
            for ob in c.objects:
                for i, m in enumerate(saved[ob.name]):
                    ob.data.materials[i] = m
        if ground:
            ground.hide_render = False
        scene.render.use_freestyle = freestyle
        _jpeg()
    return out
