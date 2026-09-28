"""Agent A building helpers for the South Grid (P01, P02, X4, XA1).

Everything is expressed as world-space boxes (x0,x1, y0,y1, z0,z1) on the 20/40-stud facade grid.
Rules baked in (contract: detail scale of the dealership):
- big window masses carry the SG Windows variants; concrete floor plates, fins and gables are chunky layers;
- no two visible faces are coplanar: plates project >= 1.5 past the window core, fins project 0.5 past plates,
  gables wrap the plate ends, parapets sit 0.5 behind plate edges;
- nothing thinner than 1.5 or narrower than 3 studs.
Faces: N = -Z (waterfront side), S = +Z, W = -X, E = +X. Kit fronts are -Z; FACE_RY rotates a kit to face outward.
"""
import sys, pathlib, random

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "common"))
from sgspec import Spec, CATALOG  # noqa: E402

GROUND = 100
WIN = (178, 186, 200)        # tint for SG Windows Blocks (near white so the texture reads true)
WIN_CAP = (214, 214, 206)    # SG Windows Capsule
CON = (150, 148, 142)        # weathered concrete
CON_D = (116, 114, 108)
CON_L = (182, 180, 172)      # slab edges / plates
CAP_W = (212, 210, 202)      # metabolist white precast
STEEL = (86, 90, 98)
SHUTTER = (120, 124, 128)
PASTEL = [(160, 206, 184), (228, 160, 146), (232, 214, 146), (156, 194, 224), (206, 176, 214), (236, 186, 120), (190, 190, 180)]
NEON = [(255, 70, 180), (60, 230, 255), (255, 170, 40), (150, 255, 90)]
FACE_RY = {"N": 0, "S": 180, "E": -90, "W": 90}


def box(s, x0, x1, y0, y1, z0, z1, mat="Concrete", var="SG Weathered Concrete", color=CON, name="Block", layer=None,
        shape="Block", rot=(0, 0, 0), **kw):
    assert x1 - x0 >= 1 and y1 - y0 >= 1 and z1 - z0 >= 1, (name, x0, x1, y0, y1, z0, z1)
    return s.part(shape, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot=rot, mat=mat,
                  var=var, color=color, layer=layer, name=name, **kw)


def win(s, x0, x1, y0, y1, z0, z1, var="SG Windows Blocks", name="Windows", color=None):
    return box(s, x0, x1, y0, y1, z0, z1, mat="SmoothPlastic", var=var, color=color or (WIN if "Blocks" in var else WIN_CAP),
               name=name)


def kit_h(item):
    return CATALOG[item]["size"]


def face_point(face, x0, x1, z0, z1, t, out):
    """Point on a face of the footprint: t = coordinate along the face, out = distance outward from the face."""
    if face == "N": return t, z0 - out
    if face == "S": return t, z1 + out
    if face == "W": return x0 - out, t
    return x1 + out, t


def face_span(face, x0, x1, z0, z1):
    return (x0, x1) if face in "NS" else (z0, z1)


def at_face(face, x0, x1, z0, z1, a, b, out0, out1):
    """Box extents (x0,x1,z0,z1) of a slab lying on `face` spanning a..b along it, from out0 to out1 outward."""
    if face == "N": return a, b, z0 - out1, z0 - out0
    if face == "S": return a, b, z1 + out0, z1 + out1
    if face == "W": return x0 - out1, x0 - out0, a, b
    return x1 + out0, x1 + out1, a, b


class Mass:
    """A Blocks-style residential mass: window core + 40-stud floor plates + fins + gables + patched parapets."""

    def __init__(self, s, name, x0, x1, z0, z1, yb, yt, rng, grid="N", gallery="", gables="", proj=8, podium=True,
                 graffiti=("A",), patch=0.45, capsule=False, plate_every=40, roof_lip=2, podium_faces=None, gable_base=None, fin_step=40, graffiti_h=60):
        self.s, self.name, self.rng = s, name, rng
        self.x0, self.x1, self.z0, self.z1, self.yb, self.yt = x0, x1, z0, z1, yb, yt
        self.grid, self.gallery, self.gables = grid, gallery, gables
        self.p = {f: (proj if f in grid + gallery else 1.5) for f in "NSEW"}
        for f in gables:
            self.p[f] = 0  # plates stop inside the gable wall
        s.group(name)
        var = "SG Windows Capsule" if capsule else "SG Windows Blocks"
        win(s, x0, x1, yb, yt, z0, z1, var=var, name="Windows")
        # floor plates every 40 (the first one is the canopy over the ground storey)
        levels = list(range(int(yb), int(yt), plate_every))
        self.levels = levels
        for k, y in enumerate(levels):
            ext = 4 if k == 0 else 0
            px0 = x0 - (self.p["W"] + (ext if "W" in grid else 0) if "W" not in gables else 0)
            px1 = x1 + (self.p["E"] + (ext if "E" in grid else 0) if "E" not in gables else 0)
            pz0 = z0 - (self.p["N"] + (ext if "N" in grid else 0) if "N" not in gables else 0)
            pz1 = z1 + (self.p["S"] + (ext if "S" in grid else 0) if "S" not in gables else 0)
            box(s, px0, px1, y - 1.5, y + 1.5, pz0, pz1, color=CON_L, name="Plate")
        # roof slab with a thin cornice lip
        rl = roof_lip
        rx0 = x0 - (0 if "W" in gables else rl); rx1 = x1 + (0 if "E" in gables else rl)
        rz0 = z0 - (0 if "N" in gables else rl); rz1 = z1 + (0 if "S" in gables else rl)
        box(s, rx0, rx1, yt - 2, yt + 3, rz0, rz1, color=CON, name="Roof")
        self.roof = yt + 3
        # fins on grid faces every 40 (interior bays), plus corner fins where there is no gable
        for f in grid:
            a, b = face_span(f, x0, x1, z0, z1)
            n = max(1, int(round((b - a) / fin_step))) if fin_step else 1
            step = (b - a) / n
            for i in range(0, n + 1):
                t = a + i * step
                corner = i in (0, n)
                if corner:
                    side = ("W" if f in "NS" else "N") if i == 0 else ("E" if f in "NS" else "S")
                    if side in gables:
                        continue
                    ta, tb = t - 2.5, t + 2.5
                else:
                    ta, tb = t - 1.5, t + 1.5
                bx = at_face(f, x0, x1, z0, z1, ta, tb, -1, self.p[f] + 0.5)
                dy = 0.5 * grid.index(f) if corner else 0.0      # corner fins of two faces must not share top faces
                box(s, bx[0], bx[1], yb + (0 if podium else 4) + dy, yt + 4 + dy, bx[2], bx[3], color=CON, name="Fin")
        # gable walls (solid concrete ends, graffiti at the bottom)
        for f in gables:
            if f in "WE":
                gx0, gx1 = (x0 - 3, x0 + 4) if f == "W" else (x1 - 4, x1 + 3)
                gz0, gz1 = z0 - self.p["N"] - 1, z1 + self.p["S"] + 1
            else:
                gz0, gz1 = (z0 - 3, z0 + 4) if f == "N" else (z1 - 4, z1 + 3)
                gx0, gx1 = x0 - self.p["W"] - 1, x1 + self.p["E"] + 1
            ysplit = min(yt, yb + graffiti_h) if podium else (gable_base if gable_base is not None else yb)
            gb = gable_base if gable_base is not None else (GROUND if podium else yb)
            if graffiti and ysplit > gb:
                g = graffiti[len(s.elements) % len(graffiti)]
                box(s, gx0, gx1, gb, ysplit, gz0, gz1, var=f"SG Graffiti {g}", color=(196, 194, 188), name="GableGraffiti")
            box(s, gx0, gx1, ysplit, yt + 6, gz0, gz1, color=CON, name="Gable")
            if yt - ysplit > 60:                     # slot of stair windows up the middle of the blank gable
                if f in "WE":
                    sx0, sx1 = (gx0 - 0.6, gx0 + 1) if f == "W" else (gx1 - 1, gx1 + 0.6)
                    zc = (z0 + z1) / 2
                    win(s, sx0, sx1, ysplit + 12, yt - 8, zc - 4, zc + 4, name="GableSlot")
                else:
                    sz0, sz1 = (gz0 - 0.6, gz0 + 1) if f == "N" else (gz1 - 1, gz1 + 0.6)
                    xc = (x0 + x1) / 2
                    win(s, xc - 4, xc + 4, ysplit + 12, yt - 8, sz0, sz1, name="GableSlot")
        # ground storey (podium) inset under the canopy plate
        if podium and yb > GROUND:
            pf = podium_faces if podium_faces is not None else grid
            ix0 = x0 + (4 if "W" not in gables else 3.5); ix1 = x1 - (4 if "E" not in gables else 3.5)
            iz0 = z0 + (4 if "N" not in gables else 3.5); iz1 = z1 - (4 if "S" not in gables else 3.5)
            box(s, ix0, ix1, GROUND, yb - 1.5, iz0, iz1, color=CON_D, name="GroundStorey")
            self.ground = (ix0, ix1, iz0, iz1)
            for f in pf:
                self.shopfront(f)
        # patched parapets on grid faces
        for f in grid:
            self.parapets(f, patch)

    # ---- details ----
    def bays(self, f):
        a, b = face_span(f, self.x0, self.x1, self.z0, self.z1)
        n = int(round((b - a) / 40))
        step = (b - a) / n
        return [(a + i * step, a + (i + 1) * step) for i in range(n)]

    def parapets(self, f, frac):
        s, rng = self.s, self.rng
        p = self.p[f]
        bays = self.bays(f)
        for y in self.levels[1:]:
            i = 0
            while i < len(bays):
                run = rng.choice((1, 1, 2, 3))
                j = min(len(bays), i + run)
                if rng.random() < frac:
                    a, b = bays[i][0] + 1.5, bays[j - 1][1] - 1.5
                    bx = at_face(f, self.x0, self.x1, self.z0, self.z1, a, b, p - 2.0, p - 0.5)
                    col = rng.choice(PASTEL)
                    box(s, bx[0], bx[1], y + 1.5, y + 8, bx[2], bx[3], mat="SmoothPlastic", var="SG Patched Panels",
                        color=col, name="PatchedParapet")
                i = j

    def shopfront(self, f):
        """Garage shutters + a small neon sign on the ground storey of face f."""
        s, rng = self.s, self.rng
        ix0, ix1, iz0, iz1 = self.ground
        a, b = face_span(f, ix0, ix1, iz0, iz1)
        n = max(1, int((b - a) // 40))
        step = (b - a) / n
        for i in range(n):
            if rng.random() < 0.25:
                continue
            c = a + (i + 0.5) * step
            w = min(28, step - 8)
            bx = at_face(f, ix0, ix1, iz0, iz1, c - w / 2, c + w / 2, -0.5, 0.8)
            box(s, bx[0], bx[1], GROUND, GROUND + 14, bx[2], bx[3], mat="Metal", var="Metal Shutters", color=SHUTTER,
                name="Shutter", layer="LOD3")
            if rng.random() < 0.4:
                bx = at_face(f, ix0, ix1, iz0, iz1, c - w / 2 + 2, c + w / 2 - 2, 0.3, 1.3)
                box(s, bx[0], bx[1], GROUND + 15.5, GROUND + 16.5, bx[2], bx[3], mat="Neon", var="",
                    color=rng.choice(NEON), name="NeonSign", layer="LOD2", collide=False, shadow=False)

    def balconies(self, f, bay_idx, storeys, laundry=0.5):
        """Kit balcony runs in chosen bays on intermediate storeys (between plates)."""
        s, rng = self.s, self.rng
        bays = self.bays(f)
        p = self.p[f]
        for bi in bay_idx:
            a, b = bays[bi]
            c = (a + b) / 2
            for y in storeys:
                x, z = face_point(f, self.x0, self.x1, self.z0, self.z1, c, 4)
                s.kit("balcony_run_40", (x, y + 6.5, z), rot=(0, FACE_RY[f], 0), layer="LOD3")
                if rng.random() < laundry:
                    x2, z2 = face_point(f, self.x0, self.x1, self.z0, self.z1, c, 8.5)
                    s.kit("laundry_line_36", (x2, y + 9.5, z2), rot=(0, FACE_RY[f], 0), layer="LOD2")

    def laundry_under_plates(self, f, n):
        s, rng = self.s, self.rng
        bays = self.bays(f)
        p = self.p[f]
        picks = rng.sample([(bi, y) for bi in range(len(bays)) for y in self.levels[1:4]], k=min(n, len(bays) * 3))
        for bi, y in picks:
            c = (bays[bi][0] + bays[bi][1]) / 2
            x, z = face_point(f, self.x0, self.x1, self.z0, self.z1, c, p - 1.5)
            s.kit("laundry_line_36", (x, y - 5, z), rot=(0, FACE_RY[f], 0), layer="LOD2")

    def ac(self, f, n, ymax=None):
        s, rng = self.s, self.rng
        a, b = face_span(f, self.x0, self.x1, self.z0, self.z1)
        ymax = ymax or min(self.yt - 10, self.yb + 160)
        for _ in range(n):
            t = rng.uniform(a + 8, b - 8)
            y = rng.choice(range(int(self.yb) + 10, int(ymax), 13))
            x, z = face_point(f, self.x0, self.x1, self.z0, self.z1, t, 2)
            s.kit("ac_cluster", (x, y, z), rot=(0, FACE_RY[f], 0), layer="LOD2")

    def stair(self, f, t, y0, n):
        """Stack of exterior steel stairs on face f at position t, from y0, n kits (40 tall each), outside the plates."""
        p = self.p[f]
        for i in range(n):
            x, z = face_point(f, self.x0, self.x1, self.z0, self.z1, t, p + 4.5)
            self.s.kit("ext_stair_40", (x, y0 + 20 + 40 * i, z), rot=(0, FACE_RY[f], 0))

    def roof_kit(self, item, x, z, ry=0, layer=None, dy=0.0, scale=None):
        if scale is None:
            scale = 1.4 if item == "water_tank" else 1.0
        h = kit_h(item)[1] * scale
        self.s.kit(item, (x, self.roof + h / 2 + dy, z), rot=(0, ry, 0), layer=layer, scale=scale)

    def roof_box(self, x0, x1, z0, z1, h, name="RoofRoom", color=CON_D, var="SG Weathered Concrete", patched=False):
        mat = "SmoothPlastic" if patched else "Concrete"
        var = "SG Patched Panels" if patched else var
        box(self.s, x0, x1, self.roof - 0.5, self.roof + h, z0, z1, mat=mat, color=color, var=var, name=name)


def cyl_v(s, x, z, d, y0, y1, color=CAP_W, var="SG Capsule Panels", name="Core", mat="Concrete", layer=None):
    """Vertical cylinder (Roblox cylinders run along X, so roll 90 degrees)."""
    return s.part("Cylinder", (y1 - y0, d, d), (x, (y0 + y1) / 2, z), rot=(0, 0, 90), mat=mat, var=var, color=color,
                  name=name, layer=layer)


def lift_tower(s, name, x0, x1, z0, z1, ytop, glass="N", graffiti="B", base=GROUND):
    """Blocks lift/stair shaft: blank concrete with a graffiti foot, a slot of glass and a machine room on top."""
    s.group(name)
    box(s, x0, x1, base, base + 80, z0, z1, var=f"SG Graffiti {graffiti}", color=(196, 194, 188), name="ShaftGraffiti")
    box(s, x0, x1, base + 80, ytop, z0, z1, color=CON, name="Shaft")
    box(s, x0 - 2, x1 + 2, ytop, ytop + 16, z0 - 2, z1 + 2, color=CON_D, name="MachineRoom")
    for f in glass:
        a, b = face_span(f, x0, x1, z0, z1)
        c = (a + b) / 2
        bx = at_face(f, x0, x1, z0, z1, c - 3, c + 3, -0.5, 0.6)
        win(s, bx[0], bx[1], base + 30, ytop - 8, bx[2], bx[3], name="ShaftGlass")


def walkway(s, x0, x1, z0, z1, y, rails=True):
    """Access deck between two masses (top at y); rails along the long sides."""
    box(s, x0, x1, y - 3, y, z0, z1, color=CON_L, name="Walkway")
    if rails:
        if (x1 - x0) >= (z1 - z0):
            for za in (z0, z1 - 1.5):
                box(s, x0, x1, y, y + 4.5, za, za + 1.5, mat="Metal", var="", color=STEEL, name="WalkRail")
        else:
            for xa in (x0, x1 - 1.5):
                box(s, xa, xa + 1.5, y, y + 4.5, z0, z1, mat="Metal", var="", color=STEEL, name="WalkRail")
