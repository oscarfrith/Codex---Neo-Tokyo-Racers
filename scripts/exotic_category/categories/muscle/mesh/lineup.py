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
    n = len(letters)
    have = [tr for tr in MC.TRIMS if all(f"{l}_NOSE_{tr}" in K.MODS for l in letters)]
    paths = []

    def stage_builds(prefix, builds):
        coll = K.bpy.data.collections[K.PREFIX + "BUILDS"]
        for ob in list(coll.objects):
            K.bpy.data.objects.remove(ob)
        for i, build_keys in enumerate(builds):
            x, z = _grid(i)
            K.place(f"{prefix}{i}", build_keys, x, z)
        _shots(prefix, out, paths)

    nxt = lambda i, k=1: letters[(i + k) % n]  # noqa: E731
    # 1. the six cars as built, once per trim
    for tr in have:
        stage_builds("lineup" if tr == "STD" else "lineup_" + tr.lower(), [MC.keys(l, tr) for l in letters])
    top = have[-1]
    mid = have[len(have) // 2]
    # 2. every standard body wearing the next car's engine pods and drift thrusters in the top trim
    stage_builds("swap_pods", [MC.keys(letters[i], "STD", FPOD=(nxt(i), top), RPOD=(nxt(i), top),
                                       STAB=(nxt(i), top)) for i in range(n)])
    # 3. every car wearing the next car's nose (top trim) and the car after that's tail, overdrive and wing
    stage_builds("swap_body", [MC.keys(letters[i], mid, NOSE=(nxt(i), top), TAIL=(nxt(i, 2), top),
                                       BOOST=(nxt(i, 2), top), WING=(nxt(i, 2), top)) for i in range(n)])
    tris = {}
    for key, rec in K.MODS.items():
        tris[key[0]] = tris.get(key[0], 0) + rec["tris"]
    return {"problems": problems, "trims": have, "tris": tris, "shots": paths}
