"""Exotic mesh blockout kit (runs inside Blender).

Everything is authored in game root space: +X right, +Y up, forward is -Z, units are studs.
P() maps that to Blender (x, -z, y), a proper rotation, so the car faces +Y in Blender.

Two section types, both lofted along an axis through stations:
  Hull  creased car-body section (rocker chamfer, shoulder line, tumblehome, top break). Crisp lines.
  Loft  superellipse section. Use for round things: nozzles, tubes, bubbles, aerofoils.
Patches and caps are taken from the same surface, so stripes, lamps, glass and intakes follow the skin.
Every object carries a paint channel: primary, secondary, detail, glass, lights, lights_red,
neon, thrust.
"""
import math

import bmesh
import bpy

PREFIX = "EXO_"
STATE = {"car": None, "coll": None, "key": None}
MODS = {}
SHARP = math.radians(22)

# Paint shown in previews. Players repaint primary, secondary and detail in game.
PAINT = {
    "A": {"primary": (0.55, 0.015, 0.02), "secondary": (0.02, 0.02, 0.024)},
    "B": {"primary": (0.85, 0.55, 0.02), "secondary": (0.07, 0.075, 0.09)},
}

# Frame standard, round 3. The two body seams are fixed Hull sections shared by every part.
SEAM_F = dict(cx=0.0, w=3.5, yb=-0.4, yt=2.5, rb=0.45, ys=1.55, tum=0.3, drop=0.3, wcf=0.62, d2=0.06,
              crown=0.05)
SEAM_R = dict(SEAM_F, yt=2.9, drop=0.35)
# Pod end sections: the rear face of a front pod and the front face of a rear pod start from these.
SIDE_F = dict(cx=4.62, w=1.0, wi=1.0, yb=-0.9, yt=1.3, rb=0.3, ys=0.6, tum=0.25, drop=0.15, tumi=0.03,
              dropi=0.08, wcf=0.5, d2=0.03, crown=0.04)
SIDE_R = dict(SIDE_F, yt=1.7, ys=0.9)
GAP = 0.06  # every skin stops this far short of a body seam; a dark liner shows in the shadow gap
# Boxes are (|x| min, |x| max, y min, y max, z min, z max).
ENV = {
    "COCKPIT": [(0, 3.6, -0.5, 2.75, -5.2, 2.8), (0, 3.2, 2.0, 5.3, -6.9, 7.4)],
    "NOSE": [(0, 3.55, -0.9, 2.55, -12.6, -5.2)],
    "TAIL": [(0, 3.55, -0.9, 3.0, 2.8, 7.4), (0, 3.55, -0.9, 3.3, 7.4, 11.6), (0, 3.55, -0.9, 0.6, 8.0, 11.8)],
    "FPOD": [(3.2, 6.0, -1.6, 2.6, -12.4, -5.35)],
    "RPOD": [(3.2, 6.0, -1.6, 3.2, 3.55, 10.7)],
    "STAB": [(3.2, 5.6, -1.6, 2.0, -5.25, 3.45)],
    "BOOST": [(0, 2.35, -0.5, 2.15, 10.6, 12.2)],
    "WING": [(0, 5.8, 1.9, 6.0, 9.4, 12.4)],
    "FREE": [(0, 99, -99, 99, -99, 99)],
}


def P(x, y, z):
    return (x, -z, y)


def _pchip(xs, ys, x):
    n = len(xs)
    if n == 1 or x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        return ys[-1]
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, n - 1):
        if d[i - 1] * d[i] > 0:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
    i = 0
    while x > xs[i + 1]:
        i += 1
    t = (x - xs[i]) / h[i]
    t2, t3 = t * t, t * t * t
    return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h[i] * m[i]
            + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h[i] * m[i + 1])


def _steps(t0, t1, step):
    n = max(1, int(math.ceil(abs(t1 - t0) / step)))
    return [t0 + (t1 - t0) * i / n for i in range(n + 1)]


class _Surface:
    KEYS = ()
    BASE = {}

    def __init__(self, stations, axis="z", **defaults):
        base = dict(self.BASE)
        base.update(defaults)
        rows = []
        for t, d in sorted(stations, key=lambda r: r[0]):
            row = {**base, **d}
            self._fill(row)
            rows.append((t, row))
        self.ts = [r[0] for r in rows]
        self.cols = {k: [r[1][k] for r in rows] for k in self.KEYS}
        self.axis = axis
        self._cache = {}

    def _fill(self, row):
        pass

    def params(self, t):
        key = round(t, 5)
        if key not in self._cache:
            self._cache[key] = {k: _pchip(self.ts, self.cols[k], t) for k in self.KEYS}
        return self._cache[key]

    def _out(self, t, u, v, p, scale):
        if scale != 1.0:
            cu, cv = p["cx"], (p["yb"] + p["yt"]) / 2
            u, v = cu + (u - cu) * scale, cv + (v - cv) * scale
        if self.axis == "z":
            return (u, v, t)
        if self.axis == "x":
            return (t, v, u)
        return (u, t, v)

    def build(self, name, ch, mirror=False, caps=(True, True), step=0.25, t0=None, t1=None, scale=1.0):
        lo = self.ts[0] if t0 is None else t0
        hi = self.ts[-1] if t1 is None else t1
        marks = [lo] + [m for m in self.ts if lo < m < hi] + [hi]
        ts = []
        for i in range(len(marks) - 1):
            seg = _steps(marks[i], marks[i + 1], step)
            ts.extend(seg if i == 0 else seg[1:])
        ring = self._ring()
        n = len(ring)
        verts = [self._pt(t, r, scale=scale) for t in ts for r in ring]
        faces = []
        for i in range(len(ts) - 1):
            for j in range(n):
                j2 = (j + 1) % n
                faces.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
        if caps[0]:
            faces.append(tuple(range(n)))
        if caps[1]:
            faces.append(tuple((len(ts) - 1) * n + j for j in range(n)))
        return _add(name, verts, faces, ch, mirror)

    def cap(self, name, end, ch, scale=1.0, push=0.0, mirror=False):
        t = self.ts[-1] if end == "max" else self.ts[0]
        verts = []
        for r in self._ring():
            g = list(self._pt(t, r, scale=scale))
            g[{"z": 2, "x": 0, "y": 1}[self.axis]] += push
            verts.append(tuple(g))
        return _add(name, verts, [tuple(range(len(verts)))], ch, mirror, closed=False)

    def _grid(self, name, ts, rs, ch, off, mirror):
        m = len(rs)
        verts = [self._pt(t, r, off) for t in ts for r in rs]
        faces = [(i * m + j, i * m + j + 1, (i + 1) * m + j + 1, (i + 1) * m + j)
                 for i in range(len(ts) - 1) for j in range(m - 1)]
        return _add(name, verts, faces, ch, mirror, closed=False)


class Loft(_Surface):
    """Superellipse section. Ring parameter is an angle in degrees: 0 side, 90 top, 270 bottom."""
    KEYS = ("cx", "w", "yb", "yt", "yw", "nt", "nb")
    BASE = dict(cx=0.0, w=1.0, yb=0.0, yt=1.0, yw=0.45, nt=2.5, nb=2.5)

    def _uv(self, p, a):
        c, s = math.cos(a), math.sin(a)
        e = p["nt"] if s >= 0 else p["nb"]
        ywa = p["yb"] + p["yw"] * (p["yt"] - p["yb"])
        h = (p["yt"] - ywa) if s >= 0 else (ywa - p["yb"])
        return (p["cx"] + p["w"] * math.copysign(abs(c) ** (2 / e), c),
                ywa + h * math.copysign(abs(s) ** (2 / e), s))

    def _ring(self, n=40):
        return [360.0 * j / n for j in range(n)]

    def _pt(self, t, a_deg, off=0.0, scale=1.0):
        p = self.params(t)
        a = math.radians(a_deg)
        u, v = self._uv(p, a)
        if off:
            u1, v1 = self._uv(p, a + 2e-3)
            u0, v0 = self._uv(p, a - 2e-3)
            du, dv = u1 - u0, v1 - v0
            ln = math.hypot(du, dv) or 1.0
            u, v = u + off * dv / ln, v - off * du / ln
        return self._out(t, u, v, p, scale)

    def patch(self, name, t0, t1, a0, a1, ch, off=0.05, mirror=False, step=0.25, astep=3.0):
        return self._grid(name, _steps(t0, t1, step), _steps(a0, a1, astep), ch, off, mirror)


class Hull(_Surface):
    """Creased body section. Half profile, bottom centre to top centre, parameter u in 0..6:
    0 bottom centre, 1 floor edge, 2 top of rocker chamfer, 3 shoulder line, 4 top edge,
    5 inner top break, 6 top centre. side +1 is the outboard half, -1 the inboard half.
    w outboard half width, wi inboard half width (defaults to w; tumi and dropi likewise), rb rocker chamfer,
    ys shoulder height, tum tumblehome, drop top edge below yt, wcf inner break as a fraction of
    the top edge, d2 inner break below yt, crown bulge of the upper panels."""
    KEYS = ("cx", "w", "wi", "yb", "yt", "rb", "ys", "tum", "drop", "tumi", "dropi", "wcf", "d2", "crown")
    BASE = dict(cx=0.0, w=1.0, yb=0.0, yt=1.0, rb=0.3, ys=0.5, tum=0.3, drop=0.2, wcf=0.6, d2=0.05,
                crown=0.04)
    M = 4

    def _fill(self, row):
        row.setdefault("wi", row["w"])
        row.setdefault("tumi", row["tum"])
        row.setdefault("dropi", row["drop"])

    def _half(self, p, side, u):
        w, tum, drop = (p["w"], p["tum"], p["drop"]) if side > 0 else (p["wi"], p["tumi"], p["dropi"])
        e = max(w - tum, 0.02)
        k = ((0.0, p["yb"]), (max(w - p["rb"], 0.02), p["yb"]), (w, p["yb"] + p["rb"]), (w, p["ys"]),
             (e, p["yt"] - drop), (e * p["wcf"], p["yt"] - p["d2"]), (0.0, p["yt"]))
        u = min(max(u, 0.0), 6.0)
        i = min(int(u), 5)
        s = u - i
        (x0, y0), (x1, y1) = k[i], k[i + 1]
        x, y = x0 + (x1 - x0) * s, y0 + (y1 - y0) * s
        if i >= 2 and p["crown"]:
            ln = math.hypot(x1 - x0, y1 - y0) or 1.0
            b = p["crown"] * ln * 4 * s * (1 - s)
            x, y = x + (y1 - y0) / ln * b, y - (x1 - x0) / ln * b
        return x, y

    def _ring(self):
        m = self.M
        return [(1, j / m) for j in range(6 * m + 1)] + [(-1, j / m) for j in range(6 * m - 1, 0, -1)]

    def _pt(self, t, r, off=0.0, scale=1.0):
        p = self.params(t)
        side, u = r
        x, y = self._half(p, side, u)
        if off:
            x1, y1 = self._half(p, side, min(u + 0.01, 6.0))
            x0, y0 = self._half(p, side, max(u - 0.01, 0.0))
            du, dv = x1 - x0, y1 - y0
            ln = math.hypot(du, dv) or 1.0
            x, y = x + off * dv / ln, y - off * du / ln
        return self._out(t, p["cx"] + side * x, y, p, scale)

    def patch(self, name, t0, t1, u0, u1, ch, side=1, off=0.05, mirror=False, step=0.25):
        rs = [(side, u) for u in _steps(u0, u1, 0.125)]
        return self._grid(name, _steps(t0, t1, step), rs, ch, off, mirror)


def box(name, c, size, ch, mirror=False):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    verts = [(c[0] + sx * hx, c[1] + sy * hy, c[2] + sz * hz)
             for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return _add(name, verts, faces, ch, mirror)


def _material(car, ch):
    name = f"{PREFIX}{car}_{ch}"
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")

    def put(key, val):
        s = bsdf.inputs.get(key)
        if s is not None:
            s.default_value = val

    look = {
        "primary": (PAINT.get(car, PAINT["A"])["primary"], 0.45, 0.2, 0),
        "secondary": (PAINT.get(car, PAINT["A"])["secondary"], 0.4, 0.3, 0),
        "detail": ((0.012, 0.012, 0.014), 0.2, 0.6, 0),
        "glass": ((0.01, 0.014, 0.02), 0.9, 0.06, 0),
        "lights": ((1.0, 0.97, 0.9), 0, 0.3, 2.2),
        "lights_red": ((1.0, 0.03, 0.02), 0, 0.3, 2.5),
        "neon": ((0.3, 0.8, 1.0), 0, 0.3, 1.6),
        "thrust": ((1.0, 0.3, 0.04), 0, 0.3, 1.5),
    }[ch]
    col = (*look[0], 1.0)
    put("Base Color", (0.0, 0.0, 0.0, 1.0) if look[3] else col)  # emitters show their emission only
    put("Metallic", look[1])
    put("Roughness", look[2])
    if ch in ("primary", "secondary"):
        put("Coat Weight", 0.4)
        put("Coat Roughness", 0.05)
    if look[3]:
        put("Emission Color", col)
        put("Emission Strength", float(look[3]))
    m.diffuse_color = col
    return m


def _add(name, verts, faces, ch, mirror=False, closed=True):
    if mirror:
        n = len(verts)
        verts = list(verts) + [(-x, y, z) for x, y, z in verts]
        faces = list(faces) + [tuple(reversed([i + n for i in f])) for f in faces]
    full = f"{PREFIX}{STATE['key']}_{name}_{ch}"
    mesh = bpy.data.meshes.new(full)
    mesh.from_pydata([P(*v) for v in verts], [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    if closed:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(_material(STATE["car"], ch))
    ob = bpy.data.objects.new(full, mesh)
    ob["PaintChannel"] = ch
    STATE["coll"].objects.link(ob)
    rec = MODS[STATE["key"]]
    rec["verts"].extend(verts)
    rec["channels"].add(ch)
    rec["tris"] += sum(len(f) - 2 for f in faces)
    return ob


def reset():
    for group in (bpy.data.objects, bpy.data.collections, bpy.data.meshes, bpy.data.cameras,
                  bpy.data.lights, bpy.data.materials):
        for item in [i for i in group if i.name.startswith(PREFIX)]:
            group.remove(item)
    MODS.clear()
    scene = bpy.context.scene
    for nm in ("LIB", "BUILDS", "STAGE"):
        c = bpy.data.collections.new(PREFIX + nm)
        scene.collection.children.link(c)


def begin(car, slot, trim="STD"):
    key = f"{car}_{slot}_{trim}"
    coll = bpy.data.collections.new(PREFIX + key)
    bpy.data.collections[PREFIX + "LIB"].children.link(coll)
    STATE.update(car=car, coll=coll, key=key)
    MODS[key] = {"slot": slot, "verts": [], "channels": set(), "tris": 0}
    return key


def finish_library():
    bpy.context.view_layer.layer_collection.children[PREFIX + "LIB"].exclude = True


def check():
    """Envelope and paint-channel check for every module. Returns a list of problems."""
    out = []
    for key, rec in sorted(MODS.items()):
        worst = 0.0
        for x, y, z in rec["verts"]:
            ax = abs(x)
            best = 1e9
            for b in ENV[rec["slot"]]:
                over = max(b[0] - ax, ax - b[1], b[2] - y, y - b[3], b[4] - z, z - b[5], 0.0)
                best = min(best, over)
            worst = max(worst, best)
        if worst > 0.1:  # surface patches sit up to 0.08 proud of the skin
            out.append(f"{key}: outside envelope by {worst:.2f}")
        for need in ("primary", "secondary"):
            if need not in rec["channels"]:
                out.append(f"{key}: no {need} channel")
    return out


def place(name, keys, ox, oz):
    builds = bpy.data.collections[PREFIX + "BUILDS"]
    for key in keys:
        e = bpy.data.objects.new(f"{PREFIX}{name}_{key}", None)
        e.instance_type = "COLLECTION"
        e.instance_collection = bpy.data.collections[PREFIX + key]
        e.location = P(ox, 0, oz)
        e.empty_display_size = 0.01
        builds.objects.link(e)


def stage():
    scene = bpy.context.scene
    coll = bpy.data.collections[PREFIX + "STAGE"]
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            pass
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg:
        bg.inputs[0].default_value = (0.62, 0.66, 0.72, 1.0)
        bg.inputs[1].default_value = 0.75
    sun = bpy.data.lights.new(PREFIX + "sun", "SUN")
    sun.energy = 4.0
    sun.angle = 0.3
    so = bpy.data.objects.new(PREFIX + "sun", sun)
    so.rotation_euler = (math.radians(52), 0, math.radians(35))
    coll.objects.link(so)
    mesh = bpy.data.meshes.new(PREFIX + "ground")
    s = 400
    mesh.from_pydata([(-s, -s, -2), (s, -s, -2), (s, s, -2), (-s, s, -2)], [], [(0, 1, 2, 3)])
    mat = bpy.data.materials.new(PREFIX + "ground")
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.16, 0.17, 0.19, 1)
    b.inputs["Roughness"].default_value = 0.45
    mesh.materials.append(mat)
    coll.objects.link(bpy.data.objects.new(PREFIX + "ground", mesh))


def shot(path, target, az, el, dist, lens=50, res=(1920, 900), only=None):
    """az 0 looks from behind the car (+Z), az 180 from the front. Angles in degrees.
    only: build names to render; every other build is hidden."""
    from mathutils import Vector
    scene = bpy.context.scene
    for e in bpy.data.collections[PREFIX + "BUILDS"].objects:
        e.hide_render = bool(only) and not any(e.name.startswith(PREFIX + o + "_") for o in only)
    a, e = math.radians(az), math.radians(el)
    g = (target[0] + dist * math.cos(e) * math.sin(a), target[1] + dist * math.sin(e),
         target[2] + dist * math.cos(e) * math.cos(a))
    cam = bpy.data.cameras.new(PREFIX + "cam")
    cam.lens = lens
    cam.clip_end = 2000
    ob = bpy.data.objects.new(PREFIX + "cam", cam)
    ob.location = P(*g)
    ob.rotation_euler = (Vector(P(*target)) - Vector(P(*g))).to_track_quat("-Z", "Y").to_euler()
    bpy.data.collections[PREFIX + "STAGE"].objects.link(ob)
    scene.camera = ob
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path
