"""South Grid kit builder (Blender 4.5, headless).

Run:
  "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup -P scripts/south_grid/kit/build_kit.py

Models every PIECE in common/kit_catalog.json as one single-material mesh.
Geometry is authored directly in ROBLOX local coordinates (X right, Y up, -Z = front/street face),
centred on the bounding-box centre and fitted to the catalog `size` exactly.

Outputs (all under scripts/south_grid/kit/out/):
  obj/<piece>.obj      Roblox local coords, triangulated, UVs + normals (read by common/preview.py)
  SouthGridKit.fbx     every piece as its own object (named exactly the piece), row layout with 20-stud gaps,
                       exported -Z forward / Y up with the axis conversion baked into the mesh data
  kit_sheet.png        labelled contact sheet (Workbench), one tile per catalog item (pieces assembled)
  tiles/<item>.png     the individual sheet tiles
  kit_report.json      measured tri counts / sizes / fit scale per piece
and writes kit/NOTES.md (generated per-piece table + design notes).

Style rules (docs/architecture/south-grid-build-contract.md): big clean forms, nothing thinner than 1 stud
except glass/fabric sheets, no greebles, windows come from MaterialVariants not modelled frames.
UVs: box projection, 1 UV unit = StudsPerTile of the piece's MaterialVariant (16 studs when none).
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
SG = os.path.dirname(HERE)
CAT = json.load(open(os.path.join(SG, "common", "kit_catalog.json")))["items"]
OUT = os.path.join(HERE, "out")
OBJDIR = os.path.join(OUT, "obj")
TILEDIR = os.path.join(OUT, "tiles")
for d in (OUT, OBJDIR, TILEDIR):
    os.makedirs(d, exist_ok=True)

STUDS_PER_TILE = {"Concrete Wood Formed": 8.0, "Concrete Square Panels": 5.0, "Metal Shutters": 2.0, "": 16.0}
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
BASIS = {"x": (X, Y, Z), "y": (Y, Z, X), "z": (Z, X, Y)}  # axis -> (axis, u, v)
TAU = 2 * math.pi


# ----------------------------------------------------------------------------------------------
# mesh builder (Roblox coordinates). Every face is given a rough desired normal direction `d`;
# the winding is flipped when needed, so normals are outward by construction.
# ----------------------------------------------------------------------------------------------
def newell(pts):
    n = Vector((0, 0, 0))
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


class MB:
    def __init__(self):
        self.v, self.f = [], []

    def add(self, p):
        self.v.append(Vector(p))
        return len(self.v) - 1

    def face(self, idx, d):
        idx = list(idx)
        if d is not None and newell([self.v[i] for i in idx]).dot(Vector(d)) < 0:
            idx.reverse()
        self.f.append(idx)

    def poly(self, pts, d):
        self.face([self.add(p) for p in pts], d)

    def xform(self, start, M, t=(0, 0, 0)):
        t = Vector(t)
        for i in range(start, len(self.v)):
            self.v[i] = M @ self.v[i] + t


def box(m, lo, hi, skip=()):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    F = {
        "-x": ([(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], (-1, 0, 0)),
        "+x": ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (1, 0, 0)),
        "-y": ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
        "+y": ([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, 1, 0)),
        "-z": ([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], (0, 0, -1)),
        "+z": ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)),
    }
    for k, (pts, d) in F.items():
        if k not in skip:
            m.poly(pts, d)


def beam(m, p0, p1, w, h, up=(0, 1, 0), ends=False):
    """Rectangular bar from p0 to p1; w across (side), h across (up-ish)."""
    p0, p1 = Vector(p0), Vector(p1)
    a = (p1 - p0).normalized()
    s = a.cross(Vector(up))
    if s.length < 1e-6:
        s = a.cross(X)
    s.normalize()
    u = s.cross(a).normalized()
    c = lambda p, i, j: p + s * (i * w / 2) + u * (j * h / 2)
    for d, (i0, j0), (i1, j1) in ((s, (1, -1), (1, 1)), (-s, (-1, -1), (-1, 1)), (u, (-1, 1), (1, 1)), (-u, (-1, -1), (1, -1))):
        m.poly([c(p0, i0, j0), c(p1, i0, j0), c(p1, i1, j1), c(p0, i1, j1)], d)
    if ends:
        m.poly([c(p0, -1, -1), c(p0, 1, -1), c(p0, 1, 1), c(p0, -1, 1)], -a)
        m.poly([c(p1, -1, -1), c(p1, 1, -1), c(p1, 1, 1), c(p1, -1, 1)], a)


def tribeam(m, p0, p1, r, up=(0, 1, 0)):
    """Triangular-section bar (3 sides, open ends) - cheap lattice member."""
    p0, p1 = Vector(p0), Vector(p1)
    a = (p1 - p0).normalized()
    s = a.cross(Vector(up))
    if s.length < 1e-6:
        s = a.cross(X)
    s.normalize()
    u = s.cross(a).normalized()
    off = [s * (r * math.cos(t)) + u * (r * math.sin(t)) for t in (math.pi / 2, math.pi / 2 + TAU / 3, math.pi / 2 + 2 * TAU / 3)]
    for i in range(3):
        o0, o1 = off[i], off[(i + 1) % 3]
        m.poly([p0 + o0, p1 + o0, p1 + o1, p0 + o1], (o0 + o1))


def ring_pts(c, axis, r, n, phase=0.0):
    a, u, v = BASIS[axis]
    c = Vector(c)
    return [c + u * (r * math.cos(phase + TAU * i / n)) + v * (r * math.sin(phase + TAU * i / n)) for i in range(n)]


def cyl(m, c, axis, r, h, n, phase=0.0, caps=(True, True)):
    a = BASIS[axis][0]
    c = Vector(c)
    B = [m.add(p) for p in ring_pts(c - a * (h / 2), axis, r, n, phase)]
    T = [m.add(p) for p in ring_pts(c + a * (h / 2), axis, r, n, phase)]
    for i in range(n):
        j = (i + 1) % n
        mid = (m.v[B[i]] + m.v[B[j]]) / 2 - (c - a * (h / 2))
        m.face([B[i], B[j], T[j], T[i]], mid)
    if caps[0]:
        m.face(B, -a)
    if caps[1]:
        m.face(T, a)
    return B, T


def zip_ring(m, outer, inner, centre, axis, d):
    """Triangulate the planar band between two loops around `centre` (outer may be a rectangle)."""
    _, u, v = BASIS[axis]
    centre = Vector(centre)

    def ang(i):
        q = m.v[i] - centre
        return math.atan2(q.dot(v), q.dot(u)) % TAU
    O = sorted(outer, key=ang)
    I = sorted(inner, key=ang)
    oa = [ang(i) for i in O] + [ang(O[0]) + TAU]
    ia = [ang(i) for i in I] + [ang(I[0]) + TAU]
    O2, I2 = O + [O[0]], I + [I[0]]
    i = j = 0
    while i < len(O) or j < len(I):
        if j >= len(I) or (i < len(O) and oa[i + 1] <= ia[j + 1]):
            m.face([O2[i], O2[i + 1], I2[j]], d)
            i += 1
        else:
            m.face([O2[i], I2[j + 1], I2[j]], d)
            j += 1


def pocket(m, front, depth, bottom=True):
    """Recess behind a loop of vertex indices; walls face the pocket axis, bottom faces out."""
    depth = Vector(depth)
    dn = depth.normalized()
    ctr = sum((m.v[i] for i in front), Vector()) / len(front)
    back = [m.add(m.v[i] + depth) for i in front]
    n = len(front)
    for i in range(n):
        j = (i + 1) % n
        mid = (m.v[front[i]] + m.v[front[j]]) / 2
        d = ctr - mid
        d -= dn * d.dot(dn)
        m.face([front[i], front[j], back[j], back[i]], d)
    if bottom:
        m.face(back, -depth)
    return back


def extrude(m, prof, mapf, a0, a1, skip=(), caps=(True, True)):
    """Extrude a 2D profile. mapf(p2, t) -> 3D point (linear). skip = edge indices (i -> i+1) to omit."""
    area = sum(prof[i][0] * prof[(i + 1) % len(prof)][1] - prof[(i + 1) % len(prof)][0] * prof[i][1] for i in range(len(prof)))
    sgn = 1 if area > 0 else -1
    o = Vector(mapf((0, 0), 0))
    vec = lambda p2: Vector(mapf(p2, 0)) - o
    axis = Vector(mapf((0, 0), 1)) - o
    A = [m.add(mapf(p, a0)) for p in prof]
    B = [m.add(mapf(p, a1)) for p in prof]
    n = len(prof)
    for i in range(n):
        if i in skip:
            continue
        j = (i + 1) % n
        dx, dy = prof[j][0] - prof[i][0], prof[j][1] - prof[i][1]
        m.face([A[i], A[j], B[j], B[i]], vec((sgn * dy, -sgn * dx)))
    s = 1 if a1 > a0 else -1
    if caps[0]:
        m.face(A, -axis * s)
    if caps[1]:
        m.face(B, axis * s)
    return A, B


# ----------------------------------------------------------------------------------------------
# pieces
# ----------------------------------------------------------------------------------------------
def capsule_shell():
    m = MB()
    R, seg = 3.0, 4
    prof = []
    for (cx, cz), a0 in (((10, -5), -90), ((10, 5), 0), ((-10, 5), 90), ((-10, -5), 180)):
        for k in range(seg + 1):
            a = math.radians(a0 + 90 * k / seg)
            prof.append((cx + R * math.cos(a), cz + R * math.sin(a)))
    B = [m.add((x, -6.5, z)) for x, z in prof]
    T = [m.add((x, 6.5, z)) for x, z in prof]
    n = len(prof)
    for i in range(n - 1):  # edge n-1 -> 0 is the flat front, built below with the porthole
        mid = Vector(((prof[i][0] + prof[i + 1][0]) / 2, 0, (prof[i][1] + prof[i + 1][1]) / 2))
        m.face([B[i], B[i + 1], T[i + 1], T[i]], mid)
    m.face(T, Y)
    m.face(B, -Y)
    outer = [B[n - 1], B[0], T[0], T[n - 1]]
    circ = [m.add(p) for p in ring_pts((0, 0, -8), "z", 4.5, 16)]
    zip_ring(m, outer, circ, (0, 0, -8), "z", -Z)
    pocket(m, circ, (0, 0, 1.5))
    return m


def capsule_porthole():
    m = MB()
    apex = m.add((0, 0, -0.5))
    F = [m.add(p) for p in ring_pts((0, 0, -0.25), "z", 4.5, 16)]
    Bk = [m.add(p) for p in ring_pts((0, 0, 0.5), "z", 4.5, 16)]
    for i in range(16):
        j = (i + 1) % 16
        m.face([apex, F[i], F[j]], -Z)
        m.face([F[i], F[j], Bk[j], Bk[i]], (m.v[F[i]] + m.v[F[j]]) / 2 - Vector((0, 0, -0.25)))
    m.face(Bk, Z)
    return m


def porthole_panel():
    m = MB()
    G = {(x, y): m.add((x, y, -1.5)) for x in (-20, 0, 20) for y in (-20, 0, 20)}
    for cx in (-10, 10):
        for cy in (-10, 10):
            x0, x1, y0, y1 = cx - 10, cx + 10, cy - 10, cy + 10
            outer = [G[(x0, y0)], G[(x1, y0)], G[(x1, y1)], G[(x0, y1)]]
            circ = [m.add(p) for p in ring_pts((cx, cy, -1.5), "z", 5.0, 12)]
            zip_ring(m, outer, circ, (cx, cy, -1.5), "z", -Z)
            pocket(m, circ, (0, 0, 2.0))
    K = {(x, y): m.add((x, y, 1.5)) for x in (-20, 20) for y in (-20, 20)}
    m.face([K[(-20, -20)], K[(20, -20)], K[(20, 20)], K[(-20, 20)]], Z)
    m.face([G[(-20, -20)], G[(-20, 0)], G[(-20, 20)], K[(-20, 20)], K[(-20, -20)]], -X)
    m.face([G[(20, -20)], G[(20, 0)], G[(20, 20)], K[(20, 20)], K[(20, -20)]], X)
    m.face([G[(-20, -20)], G[(0, -20)], G[(20, -20)], K[(20, -20)], K[(-20, -20)]], -Y)
    m.face([G[(-20, 20)], G[(0, 20)], G[(20, 20)], K[(20, 20)], K[(-20, 20)]], Y)
    return m


def porthole_glass_4():
    m = MB()
    for cx in (-10, 10):
        for cy in (-10, 10):
            apex = m.add((cx, cy, -0.3))
            R = [m.add(p) for p in ring_pts((cx, cy, 0.3), "z", 5.0, 12)]
            for i in range(12):
                m.face([apex, R[i], R[(i + 1) % 12]], -Z)
            m.face(R, Z)
    return m


def balcony_slab():
    m = MB()
    box(m, (-20, -6.5, -4), (20, -5, 4))                                   # floor slab
    for x0, x1 in ((-20, -18.8), (-0.6, 0.6), (18.8, 20)):                  # bay walls, full storey
        box(m, (x0, -5, -4), (x1, 6.5, 4), skip=("-y",))
    for x0, x1 in ((-18.8, -0.6), (0.6, 18.8)):
        box(m, (x0, -5, -4), (x1, 1, -3), skip=("-y", "-x", "+x"))         # solid parapet
        box(m, (x0, 1, -4), (x1, 2, -2.2), skip=("-x", "+x"))              # coping
    return m


def balcony_infill():
    m = MB()
    box(m, (-18, -3, -0.4), (-1.2, 3, 0.4))
    box(m, (1.2, -3, -0.3), (18, 1.6, 0.4))  # shorter, shallower patch
    return m


def laundry():
    m = MB()
    cloths = [(-18, -13.6, 5.2), (-13.0, -9.6, 3.4), (-9.0, -3.8, 7.0), (-3.0, 0.6, 4.4), (1.4, 6.8, 5.8), (7.6, 11.6, 3.8), (12.4, 18, 6.2)]
    for k, (x0, x1, h) in enumerate(cloths):
        xm = (x0 + x1) / 2
        zb = 0.5 if k % 2 == 0 else -0.5
        top, bot = 3.5, 3.5 - h
        cols = [(x0, -zb), (xm, zb), (x1, -zb)]
        for side in (-1, 1):  # two-sided sheet: separate verts, opposite winding
            idx = [(m.add((x, top, z)), m.add((x, bot, z))) for x, z in cols]
            for a, b in ((0, 1), (1, 2)):
                pa, pb = cols[a], cols[b]
                nrm = Vector((-(pb[1] - pa[1]), 0, pb[0] - pa[0])) * side  # horizontal normal of this strip
                m.face([idx[a][0], idx[b][0], idx[b][1], idx[a][1]], nrm)
    return m


def ac_cluster():
    m = MB()

    def unit(lo, hi, fc, fr):
        box(m, lo, hi, skip=("-z",))
        x0, y0, z0 = lo
        x1, y1, _ = hi
        outer = [m.add((x0, y0, z0)), m.add((x1, y0, z0)), m.add((x1, y1, z0)), m.add((x0, y1, z0))]
        c = (fc[0], fc[1], z0)
        circ = [m.add(p) for p in ring_pts(c, "z", fr, 8, math.pi / 8)]
        zip_ring(m, outer, circ, c, "z", -Z)
        pocket(m, circ, (0, 0, 0.6))
    unit((-5, -3.5, -2), (0.6, 0, 2), (-2.4, -1.75), 1.45)
    unit((1.0, -3.5, -1.6), (5, -0.4, 2), (3.0, -1.95), 1.3)
    unit((-4.2, 0.3, -2), (3.6, 3.5, 2), (-1.2, 1.9), 1.45)
    return m


def water_tank():
    m = MB()
    cyl(m, (0, 2.5, 0), "y", 8, 11, 16, caps=(True, False))         # tank y -3..8
    top = [m.add(p) for p in ring_pts((0, 8, 0), "y", 8, 16)]
    apex = m.add((0, 11, 0))
    for i in range(16):
        m.face([top[i], top[(i + 1) % 16], apex], (m.v[top[i]] + m.v[top[(i + 1) % 16]]) / 2 - Vector((0, 8, 0)) + Y * 6)
    box(m, (-7, -4, -7), (7, -3, 7), skip=("+y",))                   # deck (top hidden by tank... mostly)
    L = 5.5
    for sx in (-1, 1):
        for sz in (-1, 1):
            box(m, (sx * L - 0.6, -11, sz * L - 0.6), (sx * L + 0.6, -4, sz * L + 0.6), skip=("-y", "+y"))
    for (a, b) in (((-L, -L), (L, -L)), ((L, -L), (L, L)), ((L, L), (-L, L)), ((-L, L), (-L, -L))):
        beam(m, (a[0], -10.4, a[1]), (b[0], -4.6, b[1]), 1, 1)
        beam(m, (a[0], -4.6, a[1]), (b[0], -10.4, b[1]), 1, 1)
    return m


def dish_cluster():
    m = MB()
    box(m, (-7, -6, 2.6), (7, -4.6, 5))                                # base rail
    for (cx, cy, cz), r, tilt, yaw in (((-3.3, 1.1, -1.9), 3.4, 30, 18), ((3.7, 3.97, -1.2), 2.6, 35, -22), ((3.9, -2.2, -2.8), 2.4, 18, -8)):
        s = len(m.v)
        d = 0.3 * r
        n = 10
        rim = [m.add(p) for p in ring_pts((0, 0, 0), "z", r, n)]
        mid = [m.add(p) for p in ring_pts((0, 0, d * (1 - 0.55 ** 2)), "z", 0.55 * r, n)]
        ctr = m.add((0, 0, d))
        back = m.add((0, 0, d + 0.35 * r))
        for i in range(n):
            j = (i + 1) % n
            m.face([rim[i], rim[j], mid[j], mid[i]], -Z)
            m.face([mid[i], mid[j], ctr], -Z)
            m.face([rim[i], rim[j], back], Z + (m.v[rim[i]] + m.v[rim[j]]) * 0.2)
        beam(m, (0, -r * 0.95, -0.1), (0, 0, -0.55 * r), 0.9, 0.9)        # feed arm
        box(m, (-0.7, -0.7, -0.55 * r - 0.7), (0.7, 0.7, -0.55 * r + 0.7))  # LNB head
        M = Matrix.Rotation(math.radians(yaw), 3, "Y") @ Matrix.Rotation(math.radians(tilt), 3, "X")
        m.xform(s, M, (cx, cy, cz))
        bp = M @ Vector((0, 0, d + 0.35 * r)) + Vector((cx, cy, cz))
        beam(m, bp, (cx, -4.6, 3.8), 1, 1)                                   # support post to rail
    return m


def antenna_mast():
    m = MB()
    top = 26.0
    for sx in (-1, 1):
        for sz in (-1, 1):
            box(m, (sx * 1.5 - 0.5, -30, sz * 1.5 - 0.5), (sx * 1.5 + 0.5, top, sz * 1.5 + 0.5), skip=("-y", "+y"))
    box(m, (-2, top, -2), (2, top + 1, 2))                               # cap plate
    box(m, (-1.2, top + 1, -1.2), (1.2, 30, 1.2), skip=("-y",))          # beacon
    box(m, (-3, 11, -0.5), (3, 12, 0.5))                                 # cross arm 1 (X)
    box(m, (-0.5, 19, -3), (0.5, 20, 3))                                 # cross arm 2 (Z)
    lv = [-30 + k * (top + 30) / 5 for k in range(6)]
    faces = [lambda t: (t, -1.5), lambda t: (1.5, t), lambda t: (-t, 1.5), lambda t: (-1.5, -t)]
    for fi, fn in enumerate(faces):
        for k in range(5):
            t0 = -1.5 if (k + fi) % 2 == 0 else 1.5
            x0, z0 = fn(t0)
            x1, z1 = fn(-t0)
            tribeam(m, (x0, lv[k], z0), (x1, lv[k + 1], z1), 0.6)
    return m


def rooftop_shack():
    m = MB()
    yf, yb = 1.0, 3.5                         # wall tops front/back (lean-to)
    m.poly([(-9, yf, -7), (9, yf, -7), (9, yb, 7), (-9, yb, 7)], Y)                      # top (under roof)
    m.poly([(-9, -6, 7), (9, -6, 7), (9, yb, 7), (-9, yb, 7)], Z)                        # back
    for sx in (-9, 9):
        m.poly([(sx, -6, -7), (sx, -6, 7), (sx, yb, 7), (sx, yf, -7)], (sx, 0, 0))
    # front wall with door (x -6..-2, y -6..0) and window (x 2..6, y -3..-0.5)
    for x0, x1, y0, y1 in ((-9, -6, -6, yf), (-6, -2, 0, yf), (-2, 2, -6, yf), (2, 6, -6, -3), (2, 6, -0.5, yf), (6, 9, -6, yf)):
        m.poly([(x0, y0, -7), (x1, y0, -7), (x1, y1, -7), (x0, y1, -7)], -Z)
    door = [m.add(p) for p in ((-6, -6, -7), (-6, 0, -7), (-2, 0, -7), (-2, -6, -7))]
    back = [m.add(m.v[i] + Vector((0, 0, 0.8))) for i in door]
    for a, b, d in ((0, 1, X), (1, 2, -Y), (2, 3, -X)):
        m.face([door[a], door[b], back[b], back[a]], d)
    m.face(back, -Z)
    win = [m.add(p) for p in ((2, -3, -7), (6, -3, -7), (6, -0.5, -7), (2, -0.5, -7))]
    pocket(m, win, (0, 0, 0.6))
    # lean-to roof slab, 1 stud thick, overhanging to the full 20 x 16 footprint
    slope = (yb - yf) / 14.0
    yat = lambda z: yf + (z + 7) * slope
    cth = math.cos(math.atan(slope))
    ze = 8 - 0.5 * math.sin(math.atan(slope))
    beam(m, (0, yat(-ze) + 0.5 / cth, -ze), (0, yat(ze) + 0.5 / cth, ze), 20, 1, ends=True)
    cyl(m, (6, 4.2, 4), "y", 0.8, 3.6, 8, caps=(False, True))           # stove pipe, y 2.4..6
    return m


def ext_stair():
    m = MB()
    lv = [-20 + k * 40 / 6 for k in range(7)]
    L, steps, th = 10.0, 4, 1.0
    for k in range(1, 7):
        y0 = lv[k - 1]
        rise = lv[k] - y0
        h, r = rise / steps, L / steps
        prof = [(0, 0)]
        for s in range(steps):
            prof += [(s * r, (s + 1) * h), ((s + 1) * r, (s + 1) * h)]
        prof += [(L, rise - th)]
        skip = (len(prof) - 2,)                          # end face against the landing
        if k > 1:
            prof += [(0, -th)]
            skip = (len(prof) - 3, len(prof) - 1)        # both ends against landings
        front = k % 2 == 1
        sgn = -1 if front else 1
        xs = 5 if front else -5
        mapf = lambda p, t, xs=xs, sgn=sgn, y0=y0: (xs + sgn * p[0], y0 + p[1], t)
        z0, z1 = (-5, -0.25) if front else (0.25, 5)
        extrude(m, prof, mapf, z0, z1, skip=skip, caps=(True, front))
        if front:  # solid guard along the street side of the flight
            beam(m, (5, y0 + 2.4, -4.5), (-5, lv[k] + 2.4, -4.5), 1, 3, ends=True)
    for k in range(1, 7):
        x0, x1 = (-8, -5) if k % 2 == 1 else (5, 8)
        box(m, (x0, lv[k] - 1, -5), (x1, lv[k], 5))
        if k < 6:
            gx = (-8, -7) if k % 2 == 1 else (7, 8)
            box(m, (gx[0], lv[k], -4), (gx[1], lv[k] + 3.5, 4), skip=("-y", "-z", "+z"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            box(m, (sx * 7.5 - 0.5, -20, sz * 4.5 - 0.5), (sx * 7.5 + 0.5, 20, sz * 4.5 + 0.5), skip=("-y",))
    return m


def pipe_bundle():
    m = MB()
    for x in (-1.4, 0, 1.4):
        cyl(m, (x, 0, -0.9), "y", 0.6, 40, 8, caps=(False, False))
    for y in (-12.5, 13.5):
        box(m, (-2, y - 0.5, -0.4), (2, y + 0.5, 1.5))
    return m


def bridge_truss():
    m = MB()
    box(m, (-20, -8, -10), (20, -5, 10), skip=("-x", "+x"))              # deck
    box(m, (-20, 5, -9), (20, 6.5, 9), skip=("-x", "+x", "-z", "+z"))   # roof
    for z0, z1 in ((-10, -9), (9, 10)):
        box(m, (-20, 5, z0), (20, 8, z1), skip=("-x", "+x"))            # top chords
        zc = (z0 + z1) / 2
        for k in range(4):
            xa, xb = -20 + 10 * k, -10 + 10 * k
            ya, yb = (-5, 5) if k % 2 == 0 else (5, -5)
            beam(m, (xa + 0.5, ya, zc), (xb - 0.5, yb, zc), 1, 1.4)
    return m


def bridge_truss_glass():
    m = MB()
    box(m, (-19, -5, -9), (19, 5, 9))
    return m


def bridge_tube_ribs():
    m = MB()
    ro = 9 / math.cos(math.pi / 8)
    ri = 7.2 / math.cos(math.pi / 8)
    for xc in (-15, -5, 5, 15):
        s = []
        for x in (xc - 1, xc + 1):
            s.append(([m.add(p) for p in ring_pts((x, 0, 0), "x", ro, 8, math.pi / 8)],
                      [m.add(p) for p in ring_pts((x, 0, 0), "x", ri, 8, math.pi / 8)]))
        (oa, ia), (ob, ib) = s
        for i in range(8):
            j = (i + 1) % 8
            m.face([oa[i], oa[j], ia[j], ia[i]], -X)
            m.face([ob[i], ob[j], ib[j], ib[i]], X)
            mo = (m.v[oa[i]] + m.v[oa[j]]) / 2 - Vector((xc - 1, 0, 0))
            m.face([oa[i], oa[j], ob[j], ob[i]], mo)
            m.face([ia[i], ia[j], ib[j], ib[i]], -mo)
    box(m, (-20, -6.2, -4.5), (20, -5.2, 4.5), skip=("-x", "+x"))          # walkway inside the glass
    box(m, (-20, -9, -2), (20, -7.6, 2), skip=("-x", "+x"))                # keel tying the ribs
    return m


def bridge_tube_glass():
    m = MB()
    cyl(m, (0, 0, 0), "x", 7.5, 40, 24, caps=(False, False))
    return m


def louvre_fins():
    m = MB()
    box(m, (-20, 18.5, -2.5), (20, 20, 2.5), skip=("-x", "+x"))
    box(m, (-20, -20, -2.5), (20, -18.5, 2.5), skip=("-x", "+x"))
    for i in range(8):
        x = -17.5 + 5 * i
        box(m, (x - 0.6, -18.5, -2.5), (x + 0.6, 18.5, 2.0), skip=("-y", "+y"))
    return m


def tray_edge():
    m = MB()
    prof = [(7, 4), (-5, 4), (-7, 2), (-7, -4), (-5.5, -4), (-5.5, -2.8), (-4, -2.8), (-4, -4), (-2, -4), (7, -1)]
    extrude(m, prof, lambda p, t: (t, p[1], p[0]), -20, 20, skip=(9,))    # back face sits on the building
    return m


def stall_frame():
    m = MB()
    for sx in (-1, 1):
        box(m, (sx * 9.5 - 0.5, -7, -7), (sx * 9.5 + 0.5, 4.5, -6), skip=("-y",))   # front posts
        box(m, (sx * 9.5 - 0.5, -7, 6), (sx * 9.5 + 0.5, 7, 7), skip=("-y",))       # back posts
        beam(m, (sx * 9.5, 3.9, -6), (sx * 9.5, 6.3, 6), 1, 1)                        # side rafters
    box(m, (-9, 3.5, -7), (9, 4.5, -6), skip=("-x", "+x"))                            # front beam
    box(m, (-9, 5.5, 6), (9, 6.5, 7), skip=("-x", "+x"))                              # back beam
    box(m, (-9, -7, -6.8), (9, -3.5, -3), skip=("-y",))                               # counter
    box(m, (-9, -3.5, -7), (9, -2.5, -2.5))                                           # counter top
    box(m, (-9, -1, 4), (9, 0, 6), skip=("-x", "+x"))                                 # back shelf
    for lo, hi in (((-7.5, -2.5, -6), (-4.5, 0, -3.2)), ((-3.8, -2.5, -5.6), (-1.4, -0.5, -3.4)),
                   ((5, -7, -2.5), (8, -4, 0.5)), ((5.2, -4, -2.2), (7.8, -1.6, 0.2)), ((-6, 0, 4.2), (-3, 2.4, 5.8))):
        box(m, lo, hi, skip=("-y",))                                                  # crates
    return m


def stall_awning():
    m = MB()
    yf, yb, dip = -0.3, 1.5, 0.35
    xs = [-10 + 2.5 * i for i in range(9)]
    F = [m.add((x, yf - (dip if i % 2 else 0), -7)) for i, x in enumerate(xs)]
    Bk = [m.add((x, yb - (dip if i % 2 else 0), 7)) for i, x in enumerate(xs)]
    for i in range(8):
        m.face([F[i], F[i + 1], Bk[i + 1], Bk[i]], Y)
    fb = [m.add((-10, -1.5, -7)), m.add((10, -1.5, -7))]
    bb = [m.add((-10, 1.0, 7)), m.add((10, 1.0, 7))]
    m.face([fb[0], fb[1], bb[1], bb[0]], -Y)
    m.face([fb[0], fb[1]] + F[::-1], -Z)
    m.face([bb[0], bb[1]] + Bk[::-1], Z)
    m.face([fb[0], bb[0], Bk[0], F[0]], -X)
    m.face([fb[1], bb[1], Bk[8], F[8]], X)
    return m


def vending_body():
    m = MB()
    box(m, (-2.5, -4, -2), (2.5, 4.5, 2), skip=("-z", "-y"))
    outer = [m.add(p) for p in ((-2.5, -4, -2), (2.5, -4, -2), (2.5, 4.5, -2), (-2.5, 4.5, -2))]
    slot = [m.add(p) for p in ((-1.5, -3.6, -2), (1.5, -3.6, -2), (1.5, -2.3, -2), (-1.5, -2.3, -2))]
    zip_ring(m, outer, slot, (0, -2.95, -2), "z", -Z)
    pocket(m, slot, (0, 0, 0.9))
    box(m, (-2.3, -4.5, -1.8), (2.3, -4, 1.8), skip=("+y",))
    return m


def vending_front():
    m = MB()
    m.poly([(-2, -2.5, -0.2), (2, -2.5, -0.2), (2, 2.5, 0.2), (-2, 2.5, 0.2)], -Z)  # 2-tri budget: one quad, leaned back to span the 0.4 depth
    return m


def bench():
    m = MB()
    for x0, x1 in ((-6.5, -4), (4, 6.5)):
        box(m, (x0, -1.5, -1.6), (x1, 0.5, 1.6), skip=("+y",))
    box(m, (-7, 0.5, -2), (7, 1.5, 2))
    return m


def chainlink():
    m = MB()
    box(m, (-10, -6, -0.5), (-9, 6, 0.5), skip=("-y",))              # post (one per tile)
    box(m, (-9, 5, -0.5), (10, 6, 0.5), skip=("-x", "+x"))           # top rail
    for side in (-1, 1):                                              # two-sided mesh sheet
        m.poly([(-9, -6, 0), (10, -6, 0), (10, 5, 0), (-9, 5, 0)], (0, 0, side))
    return m


BUILDERS = {
    "capsule_shell": capsule_shell, "capsule_porthole": capsule_porthole,
    "porthole_panel": porthole_panel, "porthole_glass_4": porthole_glass_4,
    "balcony_slab": balcony_slab, "balcony_infill": balcony_infill, "laundry": laundry,
    "ac_cluster": ac_cluster, "water_tank": water_tank, "dish_cluster": dish_cluster,
    "antenna_mast": antenna_mast, "rooftop_shack": rooftop_shack, "ext_stair": ext_stair,
    "pipe_bundle": pipe_bundle, "bridge_truss": bridge_truss, "bridge_truss_glass": bridge_truss_glass,
    "bridge_tube_ribs": bridge_tube_ribs, "bridge_tube_glass": bridge_tube_glass,
    "louvre_fins": louvre_fins, "tray_edge": tray_edge, "stall_frame": stall_frame,
    "stall_awning": stall_awning, "vending_body": vending_body, "vending_front": vending_front,
    "bench": bench, "chainlink": chainlink,
}
TWO_SIDED = {"laundry", "chainlink"}

NOTES = {
    "capsule_shell": "Rounded vertical edges (r3, 4 segs, smooth-shaded). -Z face has a 1.5-deep round recess (r4.5) that seats capsule_porthole.",
    "capsule_porthole": "Glass lens, r4.5, domed front; sits 0.7 proud of the shell face, back 0.8 inside the recess.",
    "porthole_panel": "2x2 round recesses (r5, 12 sides, 2 deep) on a 20-stud cell grid; front rim = the concrete between. Tiles on 40.",
    "porthole_glass_4": "4 shallow glass domes (r5, 12 sides) matching the panel holes; dome centre flush with the panel front.",
    "balcony_slab": "Floor slab 1.5, bay walls at x=-20/0/+20 full storey, solid parapet to +1 with a coping lip; 2 bays.",
    "balcony_infill": "Two patch panels (one full, one shorter/shallower) on the parapet fronts.",
    "laundry": "7 two-sided folded cloth sheets hanging from y=+3.5 (no modelled line: <1 stud). Tint per instance.",
    "ac_cluster": "3 boxy units, each with an octagonal fan recess on the front.",
    "water_tank": "r8 tank (16 sides, smooth) with cone lid, deck, 4 legs and X-braced sides.",
    "dish_cluster": "3 dishes (r3.4/2.6/2.4) tilted up toward -Z, feed arm + LNB each, posts to a base rail.",
    "antenna_mast": "4-leg lattice (tri-section diagonals, 5 per face), cross arms along X and Z, cap plate + beacon block.",
    "rooftop_shack": "Lean-to box with recessed door and window on the front, 1-stud roof slab overhanging to full size, stove pipe.",
    "ext_stair": "6 flights of 4 chunky steps (switchback, front lane runs -X, back lane +X), 6 landings, 4 columns, solid guards.",
    "pipe_bundle": "3 downpipes d1.2 (8 sides, open ends for vertical tiling) + 2 wall brackets.",
    "bridge_truss": "Deck, roof, top chords and a Warren diagonal pattern per side; ends open for tiling along X.",
    "bridge_truss_glass": "Plain glazing box between deck and roof.",
    "bridge_tube_ribs": "4 octagonal ribs (every 10 studs, flat top/bottom), inner walkway and keel; ends open for tiling.",
    "bridge_tube_glass": "Open 24-sided glass tube r7.5, smooth-shaded.",
    "louvre_fins": "8 fins 1.2 x 4.5 every 5 studs between top/bottom rails (rails read as floor bands when stacked).",
    "tray_edge": "Extruded profile: top, 2-stud chamfer, deep fascia, 1.5 x 1.2 drip groove, sloped soffit back to the wall; back face omitted.",
    "stall_frame": "Posts, sloped rafters, counter with top, back shelf, 5 crates.",
    "stall_awning": "Sloped canopy with 8 ridge/valley stripes and a 1.2 front valance.",
    "vending_body": "Box with recessed dispense slot and inset plinth; neon front sits on the upper face.",
    "vending_front": "Single quad (2-tri budget) leaned back 0.4 so the bbox has the catalog depth.",
    "bench": "Two concrete blocks and a slab top.",
    "chainlink": "One post per tile at -X, top rail, two-sided mesh sheet (DiamondPlate carries the pattern).",
}


CATALOG_NOTES = """
## Catalog issues / notes for the integrator

- **vending_front (2 tris)**: a 2-tri budget allows one quad, which has no thickness. The quad is leaned back
  (bottom z -0.2, top z +0.2) so its bbox is exactly 4 x 5 x 0.4 and the MeshPart can be resized to catalog size.
  Its normal points -Z and ~5 deg up. If a flat face is preferred, raise the budget to 12 and use a box.
- **chainlink**: modelled as an opaque two-sided sheet (DiamondPlate supplies the texture). For a see-through fence set
  Transparency (~0.3-0.5) on that MeshPart in the assembler; no geometry change needed.
- **laundry**: no modelled line (a line would be thinner than 1 stud); cloths hang from y=+3.5 and should sit just under a
  balcony slab / between two fins. Colour it per instance (kit(color=...) tints the first piece).
- **stall_frame** back posts reach y=+7 so the piece bbox matches the item (14 tall); they poke through the awning
  at the back corners by design.
- **dish_cluster / antenna_mast / bridge_truss** are authored within 0.2% of the catalog size; the fit column shows the
  tiny scale applied. Every other piece is authored exactly (fit 1).
- Glass pieces (capsule_porthole, porthole_glass_4) are shallow domes: the dome centre is flush with (or just proud of)
  the host face and the rim sits inside the recess, so they read as lenses and never z-fight the concrete.
- Pieces that tile (bridge_truss, bridge_tube_*, louvre_fins, pipe_bundle) omit the faces buried at the joint;
  at the very end of a run the open end abuts a building face.
- FBX: -Z forward / Y up baked into the mesh data (nodes have no rotation), raw vertex values are studs
  (UnitScaleFactor 1). Verified by parsing the exported file: capsule_shell 26 x 13 x 16, vending_front normal (0, 0.08, -1).
"""


# ----------------------------------------------------------------------------------------------
# finalise: fit, triangulate, UV, normals, OBJ, Blender object
# ----------------------------------------------------------------------------------------------
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # roblox vector -> blender vector


def finalise(name, m, size, tile):
    lo = Vector([min(v[i] for v in m.v) for i in range(3)])
    hi = Vector([max(v[i] for v in m.v) for i in range(3)])
    ext = hi - lo
    ctr = (lo + hi) / 2
    fit = [size[i] / ext[i] if ext[i] > 1e-6 else 1.0 for i in range(3)]
    for v in m.v:
        for i in range(3):
            v[i] = (v[i] - ctr[i]) * fit[i]
    bm = bmesh.new()
    bv = [bm.verts.new(p) for p in m.v]
    bm.verts.ensure_lookup_table()
    for f in m.f:
        bm.faces.new([bv[i] for i in f])
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.normal_update()
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        sg = 1 if n[ax] >= 0 else -1
        for lp in f.loops:
            c = lp.vert.co
            if ax == 0:
                uv = (-c.z * sg, c.y)
            elif ax == 1:
                uv = (c.x, c.z * sg)
            else:
                uv = (c.x * sg, c.y)
            lp[uvl].uv = (uv[0] / tile, uv[1] / tile)
    vol = sum(f.verts[0].co.dot(f.verts[1].co.cross(f.verts[2].co)) for f in bm.faces) / 6
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(35))
    # OBJ in Roblox coordinates
    lines = [f"# South Grid kit piece {name} - Roblox local studs (X right, Y up, -Z front), centred\n", f"o {name}\n"]
    lines += [f"v {v.co.x:.5f} {v.co.y:.5f} {v.co.z:.5f}\n" for v in me.vertices]
    uvd = me.uv_layers.active.data
    lines += [f"vt {uvd[i].uv[0]:.5f} {uvd[i].uv[1]:.5f}\n" for i in range(len(me.loops))]
    cn = me.corner_normals
    lines += [f"vn {cn[i].vector.x:.5f} {cn[i].vector.y:.5f} {cn[i].vector.z:.5f}\n" for i in range(len(me.loops))]
    for p in me.polygons:
        lines.append("f " + " ".join(f"{me.loops[li].vertex_index + 1}/{li + 1}/{li + 1}" for li in p.loop_indices) + "\n")
    with open(os.path.join(OBJDIR, name + ".obj"), "w") as fh:
        fh.writelines(lines)
    me.transform(P.to_4x4())  # to Blender Z-up for the scene / FBX
    me.update()
    return me, {"tris": len(me.polygons), "verts": len(me.vertices), "fit": [round(f, 4) for f in fit],
                "raw_size": [round(e, 3) for e in ext], "volume": round(vol, 2)}


def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    lin = [srgb_to_lin(c) for c in color]
    mat.diffuse_color = (lin[0], lin[1], lin[2], 1)
    return mat


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    pieces = {}
    for item, it in CAT.items():
        for pc in it["pieces"]:
            pieces[pc["name"]] = (item, pc)
    missing = [p for p in pieces if p not in BUILDERS]
    assert not missing, f"no builder for {missing}"

    kitcol = bpy.data.collections.new("SouthGridKit")
    sc.collection.children.link(kitcol)
    report, meshes = {}, {}
    x = 0.0
    for name, (item, pc) in pieces.items():
        tile = STUDS_PER_TILE.get(pc["var"], 16.0)
        me, st = finalise(name, BUILDERS[name](), pc["size"], tile)
        st.update({"item": item, "size": pc["size"], "budget": pc["tris"], "mat": pc["mat"], "var": pc["var"],
                   "studs_per_uv": tile, "ok": st["tris"] <= pc["tris"]})
        report[name] = st
        meshes[name] = me
        me.materials.append(material(f"{pc['mat']}_{name}", pc["color"]))
        ob = bpy.data.objects.new(name, me)
        x += pc["size"][0] / 2
        ob.location = (x, 0, 0)
        x += pc["size"][0] / 2 + 20
        kitcol.objects.link(ob)
        print(f"PIECE {name:20s} tris {st['tris']:4d}/{pc['tris']:4d}  fit {st['fit']}  vol {st['volume']}")

    # ---- FBX ----
    # 1 Blender unit = 1 stud; scale_length 0.01 makes the exporter write raw mesh values in studs (UnitScaleFactor 1)
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 0.01
    bpy.ops.object.select_all(action="DESELECT")
    for ob in kitcol.objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = kitcol.objects[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "SouthGridKit.fbx"), use_selection=True, object_types={"MESH"},
                             axis_forward="-Z", axis_up="Y", bake_space_transform=True, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_NONE", global_scale=1.0, mesh_smooth_type="OFF",
                             use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False, use_custom_props=False)
    json.dump(report, open(os.path.join(OUT, "kit_report.json"), "w"), indent=1)

    # ---- contact sheet ----
    render_sheet(sc, meshes, report)
    write_notes(report)
    print("KIT_DONE", sum(r["tris"] for r in report.values()), "tris")


def render_sheet(sc, meshes, report):
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = False
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_object_outline = True
    sh.object_outline_color = (0.1, 0.1, 0.12)
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.62, 0.66, 0.72)
    sh.background_type = "WORLD"
    r = sc.render
    r.use_stamp = True
    for a in ("date", "time", "render_time", "frame", "frame_range", "memory", "hostname", "camera", "lens", "scene",
              "marker", "filename", "sequencer_strip"):
        setattr(r, "use_stamp_" + a, False)
    r.use_stamp_note = True
    r.stamp_font_size = 15
    r.stamp_background = (0, 0, 0, 0.75)
    prev = bpy.data.collections.new("sheet")
    sc.collection.children.link(prev)
    for ob in bpy.data.collections["SouthGridKit"].objects:
        ob.hide_render = True
    view = P @ Vector((-0.55, 0.42, -1.0)).normalized()
    tiles = []
    for n, (item, it) in enumerate(CAT.items()):
        base = Vector((5000 + n * 1000, 0, 0))
        for pc in it["pieces"]:
            ob = bpy.data.objects.new("S_" + pc["name"], meshes[pc["name"]])
            ob.location = base + P @ Vector(pc["offset"])
            prev.objects.link(ob)
        sx, sy, sz = it["size"]
        corners = [P @ Vector((a * sx / 2, b * sy / 2, c * sz / 2)) for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)]
        cam = bpy.data.cameras.new("c")
        cam.type = "ORTHO"
        co = bpy.data.objects.new("cam_" + item, cam)
        prev.objects.link(co)
        co.location = base + view * 400
        co.rotation_euler = (-view).to_track_quat("-Z", "Y").to_euler()
        Rm = co.rotation_euler.to_matrix()
        right, up = Rm.col[0], Rm.col[1]
        w = max(c.dot(right) for c in corners) - min(c.dot(right) for c in corners)
        h = max(c.dot(up) for c in corners) - min(c.dot(up) for c in corners)
        cam.ortho_scale = max(w, h * 1.12) * 1.18
        cam.shift_y = -0.03
        cam.clip_end = 2000
        sc.camera = co
        label = f"{item}  {sx:g}x{sy:g}x{sz:g}  |  " + "  ".join(f"{pc['name']} {report[pc['name']]['tris']}/{pc['tris']}" for pc in it["pieces"])
        r.stamp_note_text = label
        path = os.path.join(TILEDIR, item + ".png")
        r.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.append(path)
    # composite
    import numpy as np
    T, cols = 512, 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = np.ones((rows * T, cols * T, 4), dtype=np.float32)
    for k, p in enumerate(tiles):
        img = bpy.data.images.load(p)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(T, T, 4)
        rr, cc = divmod(k, cols)
        y0 = (rows - 1 - rr) * T
        sheet[y0:y0 + T, cc * T:(cc + 1) * T] = a
        sheet[y0:y0 + T, cc * T:cc * T + 2] = (0.2, 0.2, 0.2, 1)
        sheet[y0:y0 + 2, cc * T:(cc + 1) * T] = (0.2, 0.2, 0.2, 1)
    out = bpy.data.images.new("kit_sheet", cols * T, rows * T, alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = os.path.join(OUT, "kit_sheet.png")
    out.file_format = "PNG"
    out.save()


def write_notes(report):
    tot = sum(r["tris"] for r in report.values())
    bud = sum(r["budget"] for r in report.values())
    L = ["# South Grid kit - notes\n\n",
         "Generated by `kit/build_kit.py` (re-run to refresh; the table is rewritten each run).\n\n",
         "- Units: 1 unit = 1 stud. Geometry authored in Roblox local axes (X right, Y up, -Z = front/street face), centred on the bbox centre, fitted to the catalog size (fit = scale applied to the authored mesh; 1.0 = authored exactly).\n",
         "- Tris are counted after triangulation (what Roblox receives). UVs: box projection, 1 UV = StudsPerTile of the variant (Concrete Wood Formed 8, Concrete Square Panels 5, Metal Shutters 2, none 16).\n",
         "- Normals: outward by construction (winding checked per face); smooth-shaded with sharp edges above 35 deg, so cylinders/rounded corners are smooth and boxes stay crisp. Exported in the OBJ and FBX.\n",
         "- Two-sided sheets (laundry cloths, chain-link mesh) are duplicated faces with opposite winding, so they render from both sides without DoubleSided.\n",
         "- Open ends by design: pieces that tile along X (bridge_truss, bridge_tube_*, tray_edge keeps its end caps, louvre rails) or Y (pipe_bundle) omit the faces that would be buried in the neighbour.\n\n",
         f"Total: **{tot} tris** across {len(report)} pieces (catalog budget {bud}).\n\n",
         "| piece | item | size (studs) | tris / budget | material / variant | studs per UV | fit | notes |\n",
         "|---|---|---|---|---|---|---|---|\n"]
    for name, r in report.items():
        L.append(f"| {name} | {r['item']} | {' x '.join(f'{s:g}' for s in r['size'])} | {r['tris']} / {r['budget']}{'' if r['ok'] else ' **OVER**'} | "
                 f"{r['mat']} / {r['var'] or '-'} | {r['studs_per_uv']:g} | {' '.join(f'{f:g}' for f in r['fit'])} | {NOTES.get(name, '')} |\n")
    L.append(CATALOG_NOTES)
    open(os.path.join(HERE, "NOTES.md"), "w").writelines(L)


main()
