"""All six Modern Muscle cars together, and the swap sheets. Runs inside Blender (live or headless):

    blender --background --factory-startup --python run_headless.py -- lineup

Writes to previews/: lineup_front.jpg, lineup_rear.jpg, lineup_side.jpg (the six cars as built), and
swap_pods_*.jpg, swap_body_*.jpg (every car wearing another car's parts), which is the check that any module
fits any car. Car order is the game order muscle_01 to muscle_06.
"""
import os

import exokit as K
import muscle_cars as MC

CARS = [("outrider", "A", "car_a"), ("outlaw", "B", "car_b"), ("slingshot", "C", "car_c"),
        ("stallion", "D", "car_d"), ("blackjack", "E", "car_e"), ("brawler", "F", "car_f")]
DX, DZ = 21.0, 36.0


def _fn(module, letter):
    mod = __import__(module)
    return getattr(mod, "car_" + letter.lower())


def _keys(parts):
    """parts: slot -> letter. Returns the module keys of a build."""
    return [f"{parts[s]}_{s}_STD" for s in MC.SLOTS]


def _grid(i):
    return ((i % 3) - 1) * DX, (i // 3) * DZ - DZ / 2


def _shots(prefix, out, paths):
    for view, az, el, dist in (("front", 150, 16, 150), ("rear", 30, 16, 150), ("top", 180, 86, 135)):
        paths.append(K.shot(os.path.join(out, f"{prefix}_{view}.jpg"), (0, 1.5, 0), az, el, dist, lens=60,
                            res=(2400, 1350)))


def build(out=None):
    out = out or MC.OUT
    os.makedirs(out, exist_ok=True)
    K.reset()
    K.stage()
    for name, letter, module in CARS:
        _fn(module, letter)()
    K.finish_library()
    problems = K.check()
    letters = [c[1] for c in CARS]
    paths = []

    def stage_builds(prefix, mapping):
        builds = K.bpy.data.collections[K.PREFIX + "BUILDS"]
        for ob in list(builds.objects):
            K.bpy.data.objects.remove(ob)
        for i, parts in enumerate(mapping):
            x, z = _grid(i)
            K.place(f"{prefix}{i}", _keys(parts), x, z)
        _shots(prefix, out, paths)

    # 1. the six cars as built
    stage_builds("lineup", [{s: letter for s in MC.SLOTS} for letter in letters])
    # 2. every body wearing the next car's engine pods and drift thrusters
    nxt = lambda i, k=1: letters[(i + k) % len(letters)]  # noqa: E731
    stage_builds("swap_pods", [{**{s: letters[i] for s in MC.SLOTS}, "FPOD": nxt(i), "RPOD": nxt(i), "STAB": nxt(i)}
                               for i in range(len(letters))])
    # 3. every cockpit and pod set wearing the next car's nose and the car after that's tail, overdrive and wing
    stage_builds("swap_body", [{**{s: letters[i] for s in MC.SLOTS}, "NOSE": nxt(i), "TAIL": nxt(i, 2),
                                "BOOST": nxt(i, 2), "WING": nxt(i, 2)} for i in range(len(letters))])
    tris = {}
    for key, rec in K.MODS.items():
        tris[key[0]] = tris.get(key[0], 0) + rec["tris"]
    return {"problems": problems, "tris": tris, "total": sum(tris.values()), "shots": paths}
