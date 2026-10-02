"""Generator for the Muscle frame class blockout spec (round 2, design exploration only).

Run from the repo root:
    py -3 scripts/vehicle_blockouts/gen/muscle.py            write the spec, print a self-check
    py -3 scripts/vehicle_blockouts/gen/muscle.py --table    also print pairwise distinctness per slot
Writes scripts/vehicle_blockouts/specs/muscle.json. The JSON is never edited by hand.

Root space: +X right, +Y up, forward is -Z, studs.
The car is a one-piece American muscle body with the wheels removed. The cabin sits well back:
an 11.3 stud bonnet, an 8.2 stud cabin and a tail of 6 to 7 studs.
  Engine1      a turbine standing on the bonnet pad (the blower became a jet)
  Engine2      a turbine pack in an open bay between the haunch tails
  Stabilisers  a lift jet in each blanked or filled wheel arch
  Boost        side-pipe afterburners under the sills
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import vbspec  # noqa: E402  (read-only use: rotation maths and a final self-check)

OUT = os.path.join(os.path.dirname(HERE), "specs", "muscle.json")

# ----------------------------------------------------------------------------- datums
HOVER = -2.0        # hover plane
FLOOR = -0.4        # underside of the chassis
SILL = 0.3          # bottom edge of every painted body skin
ARCH = 1.7          # arch roof: stabiliser pad
STRIPE_LO, STRIPE_HI = 2.35, 2.65   # belt stripe band, runs nose to tail
BELT = 3.3          # beltline, bonnet pad and deck pad are all at this height
ROOF = 6.0

Z_NOSE = -12.3      # lower nose face (bumper shelf)
Z_COWL = -2.0       # nose clip to cabin seam: the cabin sits well back, so the bonnet is 11.3 long
Z_BACK = 6.2        # cabin to rear body seam
Z_BULK = 10.2       # Engine2 bulkhead; the rear arch ends here too
Z_TAIL = 12.1       # standard tail face (the envelope allows 12.2: lamps stand 0.08 proud)
FRONT_ARCH = -7.6   # arch centres
REAR_ARCH = 8.3
ARCH_HALF = 1.9
RA0 = REAR_ARCH - ARCH_HALF     # rear arch front edge, 6.4
Z_FLARE = Z_BACK + 1.2          # the haunch reaches full width here
E1_SHIFT = 1.0      # hood engines are drawn around Z -7 and slid back to sit nearer the cowl

X_DOOR = 4.75       # door skin
X_TUB = 3.3         # arch back wall
PAD_HOOD_X = 2.2    # bonnet pad half width (Engine1)
BAY_X = 3.3         # Engine2 bay half width


def R(v):
    return round(float(v), 3)


# ----------------------------------------------------------------------------- part helpers
def _finish(p, ch, mirror, note):
    p["ch"] = ch
    if mirror:
        p["mirror"] = True
    if note:
        p["note"] = note
    return p


def box(x0, x1, y0, y1, z0, z1, ch="primary", note=None, mirror=False):
    """Axis-aligned block from its extents."""
    return _finish({"shape": "block", "size": [R(x1 - x0), R(y1 - y0), R(z1 - z0)],
                    "pos": [R((x0 + x1) / 2), R((y0 + y1) / 2), R((z0 + z1) / 2)]}, ch, mirror, note)


def mbox(x0, x1, y0, y1, z0, z1, ch="primary", note=None):
    """Block on the +X side, mirrored to -X."""
    return box(x0, x1, y0, y1, z0, z1, ch, note, mirror=True)


_AX = {"+x": (1, 0, 0), "-x": (-1, 0, 0), "+y": (0, 1, 0), "-y": (0, -1, 0), "+z": (0, 0, 1), "-z": (0, 0, -1)}
_WEDGE_CACHE = {}


def _wedge_rot(thin, base):
    key = (thin, base)
    if key not in _WEDGE_CACHE:
        for rx in (0, 90, 180, -90):
            for ry in (0, 90, 180, -90):
                for rz in (0, 90, 180, -90):
                    m = vbspec.rot_matrix([rx, ry, rz])
                    if np.allclose(m @ np.array([0, 0, -1.0]), _AX[thin]) and np.allclose(m @ np.array([0, -1.0, 0]), _AX[base]):
                        _WEDGE_CACHE.setdefault(key, ([rx, ry, rz], m))
        if key not in _WEDGE_CACHE:
            raise ValueError("no wedge rotation for %r" % (key,))
    return _WEDGE_CACHE[key]


def wedge(x0, x1, y0, y1, z0, z1, thin="-z", base="-y", ch="primary", note=None, mirror=False):
    """Wedge filling the given box. `thin` is the direction of the knife edge, `base` the direction the
    full flat base faces. thin='-z', base='-y' is a windscreen; thin='+z' is a fastback slope."""
    rot, m = _wedge_rot(thin, base)
    size = np.abs(m.T @ np.array([x1 - x0, y1 - y0, z1 - z0], dtype=float))
    p = {"shape": "wedge", "size": [R(v) for v in size],
         "pos": [R((x0 + x1) / 2), R((y0 + y1) / 2), R((z0 + z1) / 2)]}
    if any(rot):
        p["rot"] = rot
    return _finish(p, ch, mirror, note)


def mwedge(x0, x1, y0, y1, z0, z1, thin="-z", base="-y", ch="primary", note=None):
    return wedge(x0, x1, y0, y1, z0, z1, thin, base, ch, note, mirror=True)


def cylz(x, y, z0, z1, d, ch="detail", note=None, mirror=False):
    return _finish({"shape": "cyl_z", "size": [R(d), R(d), R(z1 - z0)], "pos": [R(x), R(y), R((z0 + z1) / 2)]}, ch, mirror, note)


def cyly(x, z, y0, y1, d, ch="detail", note=None, mirror=False):
    return _finish({"shape": "cyl_y", "size": [R(d), R(y1 - y0), R(d)], "pos": [R(x), R((y0 + y1) / 2), R(z)]}, ch, mirror, note)


def cylx(y, z, x0, x1, d, ch="detail", note=None, mirror=False):
    return _finish({"shape": "cyl_x", "size": [R(x1 - x0), R(d), R(d)], "pos": [R((x0 + x1) / 2), R(y), R(z)]}, ch, mirror, note)


def ball(x, y, z, d, ch="detail", note=None, mirror=False):
    return _finish({"shape": "ball", "size": [R(d), R(d), R(d)], "pos": [R(x), R(y), R(z)]}, ch, mirror, note)


def _aim(p0, p1):
    p0, p1 = np.array(p0, dtype=float), np.array(p1, dtype=float)
    v = p1 - p0
    length = float(np.linalg.norm(v))
    u = v / length
    rx = -math.degrees(math.asin(max(-1.0, min(1.0, u[1]))))
    ry = math.degrees(math.atan2(u[0], u[2]))
    return (p0 + p1) / 2, length, [R(rx), R(ry), 0], u


def tube(p0, p1, d, ch="detail", note=None, mirror=False):
    """Cylinder of diameter d from point p0 to point p1 (any direction)."""
    mid, length, rot, _ = _aim(p0, p1)
    p = {"shape": "cyl_z", "size": [R(d), R(d), R(length)], "pos": [R(c) for c in mid]}
    if any(rot):
        p["rot"] = rot
    return _finish(p, ch, mirror, note)


def plank(p0, p1, width, thick, ch="detail", note=None, mirror=False):
    """Flat board from p0 to p1: `width` across (horizontal), `thick` through."""
    mid, length, rot, _ = _aim(p0, p1)
    p = {"shape": "block", "size": [R(width), R(thick), R(length)], "pos": [R(c) for c in mid]}
    if any(rot):
        p["rot"] = rot
    return _finish(p, ch, mirror, note)


def shift(parts, dz):
    """Slide a finished part list along Z."""
    for p in parts:
        p["pos"][2] = R(p["pos"][2] + dz)
    return parts


def jet(p0, p1, d, body="detail", lip=None, plume=0.4, mirror=False, note=None, glow=None):
    """Small jet from intake p0 to nozzle p1. The glowing plume pokes out past p1.
    `glow` is the diameter of the thrust face (default: the bore of the tube)."""
    p0, p1 = np.array(p0, dtype=float), np.array(p1, dtype=float)
    u = (p1 - p0) / np.linalg.norm(p1 - p0)
    out = [tube(p0, p1, d, body, note, mirror)]
    if lip:
        out.append(tube(p0 - 0.05 * u, p0 + 0.45 * u, d + 0.2, lip, None, mirror))
    out.append(tube(p1 - 0.1 * u, p1 + plume * u, glow or max(0.25, d - 0.28), "thrust", None, mirror))
    return out


def turbine(x, y, z0, z1, d, casing="detail", collar="secondary", plume=0.45, mirror=False, note=None):
    """Fore-aft turbine: intake collar at z0, casing, nozzle bell at z1, glowing plume.
    Every section is longer than half its width, so nothing reads as a ring or a disc."""
    length = z1 - z0
    cl = max(0.52 * (d + 0.2), 0.3 * length)
    bl = max(0.52 * (d + 0.15), 0.3 * length)
    out = [cylz(x, y, z0, z0 + cl, d + 0.2, collar, note or "intake collar", mirror)]
    if length - cl - bl > 0.5 * d:
        out.append(cylz(x, y, z0 + cl, z1 - bl, d, casing, "casing", mirror))
        out.append(cylz(x, y, z1 - bl, z1, d + 0.15, casing, "nozzle bell", mirror))
    else:
        out.append(cylz(x, y, z0 + cl, z1, d + 0.05, casing, "nozzle bell", mirror))
    out.append(cylz(x, y, z1 - 0.15, z1 + plume, d - 0.5, "thrust", "jet", mirror))
    return out


# ----------------------------------------------------------------------------- frame standard
STANDARD = {
    "cockpitEnvelope": [
        {"min": [-4.8, FLOOR, Z_COWL], "max": [4.8, 6.2, Z_BACK]},
        {"min": [-4.4, BELT, Z_BACK], "max": [4.4, 6.2, Z_BULK - 0.1]},
    ],
    "datums": {
        "hoverPlane": HOVER, "floor": FLOOR, "sill": SILL, "archRoof": ARCH,
        "stripeLow": STRIPE_LO, "stripeHigh": STRIPE_HI, "beltline": BELT, "hoodPad": BELT, "deckPad": BELT,
        "roof": ROOF, "noseShelfZ": Z_NOSE, "cowlSeamZ": Z_COWL, "cabinBackSeamZ": Z_BACK,
        "engineBulkheadZ": Z_BULK, "tailFaceZ": Z_TAIL, "frontArchZ": FRONT_ARCH, "rearArchZ": REAR_ARCH,
        "archHalfLength": ARCH_HALF, "doorSkinX": X_DOOR, "archBackWallX": X_TUB,
        "hoodPadHalfWidth": PAD_HOOD_X, "engineBayHalfWidth": BAY_X,
    },
    "slots": {
        "FrontBody": {
            "label": "Nose Clip",
            "envelope": [
                {"min": [-5.5, SILL, -12.4], "max": [5.5, BELT, -9.5]},      # nose block above the bumper shelf
                {"min": [-5.5, 1.5, -13.4], "max": [5.5, BELT, -12.4]},      # beak: upper nose may overhang the bumper
                {"min": [-5.5, ARCH, -9.5], "max": [5.5, BELT, -5.7]},       # bonnet and wings over the arches
                {"min": [-3.4, FLOOR, -9.5], "max": [3.4, ARCH, -5.7]},      # inner tub between the arches
                {"min": [-5.5, FLOOR, -5.7], "max": [5.5, BELT, Z_COWL]},    # long wing behind the arch, up to the cowl seam
                {"min": [2.3, BELT, -13.4], "max": [5.5, 3.9, Z_COWL], "mirror": True},  # wing crowns beside the bonnet pad
                {"min": [-2.3, BELT, -13.4], "max": [2.3, 3.9, -9.1]},       # bonnet peak ahead of the engine
            ],
            "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -7],
        },
        "RearBody": {
            "label": "Tail and Haunches",
            "envelope": [
                {"min": [-5.5, SILL, Z_BACK], "max": [5.5, BELT, RA0]},      # arch leading edge
                {"min": [-3.4, FLOOR, Z_BACK], "max": [3.4, ARCH, Z_BULK]},  # inner tub between the arches
                {"min": [-5.5, ARCH, RA0], "max": [5.5, BELT, Z_BULK]},      # deck and haunches over the arches
                {"min": [3.3, SILL, Z_BULK], "max": [5.5, BELT, 12.2], "mirror": True},   # haunch tails beside the engine bay
                {"min": [3.3, 1.6, 12.2], "max": [5.5, BELT, 13.2], "mirror": True},   # tail overhang above the bumper
                {"min": [4.5, BELT, Z_BACK], "max": [5.5, 3.8, 13.2], "mirror": True},   # hips: haunch crowns outside the glass
            ],
            "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 0, 7],
        },
        "Engine1": {
            "label": "Hood Engine",
            "envelope": {"min": [-PAD_HOOD_X, BELT, -9.0], "max": [PAD_HOOD_X, 5.3, -2.6]},
            "anchor": {"to": "FrontBody", "face": "-y"}, "explode": [0, 4.5, -7],
        },
        "Engine2": {
            "label": "Tail Engine",
            "envelope": {"min": [-BAY_X, SILL, Z_BULK], "max": [BAY_X, 4.2, 13.6]},
            "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, 1.5, 13],
        },
        "Stabilisers": {
            "label": "Lift Jets",
            "envelope": [
                {"min": [3.4, -1.5, FRONT_ARCH - ARCH_HALF], "max": [6.0, ARCH, FRONT_ARCH + ARCH_HALF], "mirror": True},
                {"min": [3.4, -1.5, REAR_ARCH - ARCH_HALF], "max": [6.0, ARCH, REAR_ARCH + ARCH_HALF], "mirror": True},
            ],
            "anchor": [{"to": "FrontBody", "face": "+y"}, {"to": "RearBody", "face": "+y"}], "explode": [4.5, -3.5, 0],
        },
        "Boost": {
            "label": "Side Burners",
            "envelope": {"min": [4.8, -1.4, Z_COWL], "max": [6.3, SILL, RA0 - 0.1], "mirror": True},
            "anchor": {"to": "cockpit", "face": "-x"}, "explode": [5.5, -2.5, 0],
        },
        "SidePods": {
            "label": "Rockers",
            "envelope": {"min": [4.8, SILL, Z_COWL], "max": [5.6, 2.3, Z_BACK], "mirror": True},
            "anchor": {"to": "cockpit", "face": "-x"}, "explode": [9.5, 1.5, 0],
        },
        "FrontBumper": {
            "label": "Front Bumper",
            "envelope": [
                {"min": [-5.6, -1.2, -13.4], "max": [5.6, SILL, -9.6]},      # chin, under the nose
                {"min": [-5.6, SILL, -13.4], "max": [5.6, 1.5, -12.4]},      # bumper bar layer ahead of the nose shelf
            ],
            "anchor": {"to": "FrontBody", "face": "+y"}, "explode": [0, -2.5, -12],
        },
        "RearBumper": {
            "label": "Rear Bumper",
            "envelope": [
                {"min": [-5.6, -1.2, Z_BULK], "max": [5.6, SILL, 13.6]},     # valance under the tail and the engine
                {"min": [3.3, SILL, 12.2], "max": [5.6, 1.6, 13.6], "mirror": True},  # corner bars behind the haunch tails
            ],
            "anchor": {"to": "RearBody", "face": "+y"}, "explode": [0, -4.5, 9],
        },
        "RearSpoiler": {
            "label": "Spoiler",
            "envelope": [
                {"min": [3.3, BELT, Z_BULK], "max": [4.5, 4.3, 13.2], "mirror": True},  # feet on the haunch pads
                {"min": [-5.6, 4.3, Z_BULK], "max": [5.6, 7.0, 13.6]},       # blade zone above the tail engine
            ],
            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 6.5, 6],
        },
    },
}


# ----------------------------------------------------------------------------- cockpits
def chassis(open_top=False):
    """Shared by every cockpit: sill rails, seam plates, door body, stripe. Identical pads on all six."""
    top = 2.5 if open_top else BELT
    z0, z1 = Z_COWL + 0.1, Z_BACK - 0.1
    return [
        box(-X_DOOR, X_DOOR, FLOOR, SILL, Z_COWL, Z_BACK, "detail", "sill rail: Boost and Rockers land on its outer face"),
        box(-4.72, 4.72, SILL, 3.28, Z_COWL, z0, "detail", "seam plate: the shadow gap to the nose clip"),
        box(-4.72, 4.72, SILL, 3.28, z1, Z_BACK, "detail", "seam plate: the shadow gap to the rear body"),
        box(-X_DOOR, X_DOOR, SILL, top, z0, z1, "primary", "door body"),
        mbox(4.74, 4.8, STRIPE_LO, STRIPE_HI, z0, z1, "secondary", "belt stripe datum"),
        mbox(4.74, 4.8, 0.6, 3.1, 4.05, 4.15, "detail", "door shut line"),
    ]


def occupants(y, z=2.85):
    """Seats and driver. z is the front face of the seat backs."""
    return [
        box(-2.9, -1.1, y, y + 1.35, z, z + 0.5, "detail", "driver seat back"),
        box(1.1, 2.9, y, y + 1.35, z, z + 0.5, "detail", "passenger seat back"),
        box(-2.7, -1.3, y, y + 1.0, z - 0.8, z, "driver", "driver torso"),
        ball(-2.0, y + 1.5, z - 0.4, 1.1, "driver", "driver head"),
    ]


def screen(half, top, z0, z1, pillar=0.3):
    """Raked windscreen wedge with A-pillars and a cowl vent. z0 is the base, z1 the header."""
    return [
        box(-4.2, 4.2, BELT, BELT + 0.08, Z_COWL + 0.1, z0 + 0.1, "detail", "cowl vent"),
        wedge(-half, half, BELT, top, z0, z1, "-z", "-y", "glass", "windscreen"),
        mwedge(half, half + pillar, BELT, top, z0, z1, "-z", "-y", "primary", "A-pillar"),
    ]


def cockpit_fastback():
    """Late-60s fastback: the roof peaks over the B-pillar, then one unbroken louvred slope runs to the tail."""
    zr, ze, top = 2.3, Z_BULK - 0.15, 5.95   # roof peak (B-pillar), end of the slope, roof height
    p = chassis() + screen(3.6, 5.85, -1.6, 0.9) + [
        box(-3.8, 3.8, BELT, 5.6, 0.9, zr, "glass", "door glass"),
        box(-3.9, 3.9, 5.6, top, 0.7, zr + 0.1, "primary", "short, low roof: the peak sits over the B-pillar"),
        wedge(-2.8, 2.8, BELT, top - 0.05, zr, ze, "+z", "-y", "glass", "fastback glass, from the B-pillar to the end of the deck pad"),
        mwedge(2.8, 3.9, BELT, top, zr, ze, "+z", "-y", "primary", "long sail panel"),
        mwedge(3.9, 3.96, 3.55, 4.9, zr + 0.3, 5.4, "+z", "-y", "glass", "triangular quarter glass in the sail panel"),
        mbox(3.9, 3.98, 3.6, 4.0, 6.4, 7.5, "detail", "sail panel vent"),
    ]
    for i in range(5):  # louvres: the fastback signature
        z = zr + 1.5 + i * 1.2
        y = BELT + (top - 0.05 - BELT) * (ze - z) / (ze - zr)
        p.append(box(-2.6, 2.6, y + 0.04, y + 0.18, z - 0.1, z + 0.7, "detail", "rear window louvre"))
    return p + occupants(BELT)


def cockpit_hardtop():
    """Coke-bottle coupe: the widest, tallest, squarest roof. An upright screen, a long thick C-pillar,
    an upright tunnel-back window and two flying buttresses with open deck between them."""
    return chassis() + screen(4.1, 6.05, -1.2, 0.2) + [
        box(-4.35, 4.35, BELT, 5.7, 0.2, 3.4, "glass", "pillarless side glass"),
        box(-4.5, 4.5, 5.7, 6.2, 0.0, 6.1, "secondary", "long, tall, wide formal roof (vinyl top)"),
        mbox(3.4, 4.5, BELT, 5.7, 3.4, 6.1, "secondary", "thick, long C-pillar"),
        box(-3.4, 3.4, BELT, 5.7, 5.8, 6.0, "glass", "upright tunnel-back window"),
        mwedge(3.7, 4.4, BELT, 6.2, 6.1, 8.8, "+z", "-y", "secondary", "flying buttress on the deck pad"),
    ] + occupants(BELT)


def cockpit_notch():
    """60s pony notchback: a small, low, narrow greenhouse set well back, then the longest flat deck."""
    return chassis() + screen(2.8, 5.55, 0.0, 2.0) + [
        box(-3.0, 3.0, BELT, 5.3, 2.0, 4.5, "glass", "side glass"),
        box(-3.1, 3.1, 5.3, 5.6, 1.8, 4.7, "primary", "short, low, narrow roof"),
        wedge(-2.3, 2.3, BELT, 5.56, 4.5, 6.7, "+z", "-y", "glass", "steep notch rear window"),
        mwedge(2.3, 3.1, BELT, 5.6, 4.5, 6.7, "+z", "-y", "primary", "C-pillar"),
        mbox(0.35, 1.25, 5.6, 5.66, 1.8, 4.7, "secondary", "racing stripes over the roof"),
        box(-2.7, 2.7, 3.5, 5.2, 3.9, 4.1, "detail", "roll hoop behind the seats"),
    ] + occupants(BELT, 3.3)


def cockpit_modern():
    """Retro-modern coupe: a high shoulder, slit side glass, a chopped black roof and the longest, flattest screen."""
    sh = 4.25                               # shoulder top: the high modern beltline
    return chassis() + screen(3.7, 4.95, -1.9, 2.6, pillar=0.35) + [
        mbox(4.0, X_DOOR, BELT, sh, -1.0, 5.0, "primary", "high shoulder: the modern beltline"),
        mwedge(4.0, X_DOOR, BELT, sh, -1.9, -1.0, "-z", "-y", "primary", "shoulder rises from the cowl seam"),
        mwedge(4.4, X_DOOR, BELT, sh, 5.0, Z_BACK, "+z", "-y", "primary", "shoulder falls to the belt at the rear seam"),
        mbox(3.8, 4.4, BELT, sh, 5.0, 8.6, "primary", "shoulder runs on over the deck pad"),
        mwedge(3.8, 4.4, BELT, sh, 8.6, Z_BULK - 0.15, "+z", "-y", "primary", "shoulder fades out at the end of the deck pad"),
        box(-3.9, 3.9, BELT, 4.75, 2.6, 5.4, "glass", "slit side glass above the shoulder"),
        box(-4.05, 4.05, 4.75, 5.05, 2.4, 5.6, "detail", "chopped black roof panel"),
        wedge(-3.1, 3.1, BELT, 5.0, 5.5, 7.8, "+z", "-y", "glass", "fast rear glass"),
        mwedge(3.1, 4.05, BELT, 5.05, 5.5, 7.8, "+z", "-y", "primary", "thick C-pillar"),
        box(-0.25, 0.25, 5.05, 5.3, 4.3, 5.5, "detail", "roof fin"),
    ] + occupants(2.7, 3.5)


def cockpit_ragtop():
    """Convertible: no roof at all. A frameless screen, an open tub and a folded top under its cover."""
    y = 2.62
    z0, z1 = Z_COWL + 0.1, Z_BACK - 0.1
    return chassis(open_top=True) + [
        mbox(3.9, X_DOOR, 2.5, BELT, z0, z1, "primary", "door tops"),
        box(-3.9, 3.9, 2.5, BELT, z0, -0.3, "primary", "cowl and dash"),
        box(-3.9, 3.9, 2.5, BELT, 4.0, z1, "primary", "rear shelf"),
        box(-3.9, 3.9, 2.5, y, -0.3, 4.0, "detail", "cabin floor"),
        box(-4.2, 4.2, BELT, BELT + 0.08, z0, -1.5, "detail", "cowl vent"),
        plank((0, BELT, -1.5), (0, 5.45, 0.4), 7.3, 0.14, "glass", "frameless windscreen pane"),
        tube((3.75, BELT, -1.5), (3.75, 5.5, 0.43), 0.26, "secondary", "screen pillar", mirror=True),
        box(-3.88, 3.88, 5.38, 5.62, 0.28, 0.54, "secondary", "screen header bar"),
        box(-3.9, 3.9, BELT, 3.75, 4.5, 7.2, "secondary", "folded roof under its boot cover"),
        wedge(-2.9, -1.1, 3.75, 4.5, 3.35, 7.2, "+z", "-y", "primary", "headrest fairing"),
        wedge(1.1, 2.9, 3.75, 4.5, 3.35, 7.2, "+z", "-y", "primary", "headrest fairing"),
    ] + occupants(y)


def cockpit_ute():
    """Coupe utility: a short upright cab with a peaked visor, a sheer cab back and a long, low, open bed."""
    zc, ze = 3.1, Z_BULK - 0.15            # cab back, bed end
    p = chassis() + screen(3.9, 5.75, -1.3, -0.1) + [
        box(-4.1, 4.1, BELT, 5.7, -0.1, 2.3, "glass", "side glass"),
        box(-4.2, 4.2, 5.7, 6.15, -1.0, zc, "primary", "short, tall cab roof, pulled forward over the screen"),
        box(-4.2, 4.2, 5.45, 5.7, -1.2, -0.7, "detail", "peaked visor"),
        mbox(3.2, 4.2, BELT, 5.7, 2.3, zc, "primary", "thick B-pillar"),
        box(-3.2, 3.2, 3.9, 5.7, zc - 0.25, zc - 0.05, "glass", "upright cab window"),
        box(-3.2, 3.2, BELT, 3.9, zc - 0.4, zc, "primary", "sheer cab back"),
        mbox(3.6, 4.4, BELT, 3.8, zc, ze, "primary", "low bed side on the deck pad"),
        mbox(3.55, 4.4, 3.8, 3.9, zc, ze, "secondary", "bed rail cap"),
        box(-3.6, 3.6, BELT, 3.8, ze - 0.4, ze, "primary", "tailgate"),
        box(-3.2, 3.2, 3.45, 3.7, ze, ze + 0.06, "secondary", "tailgate stripe"),
        box(-3.6, 3.6, BELT, 3.42, zc, ze - 0.4, "detail", "dark bed liner: the open bed"),
    ]
    for x in (0.7, 2.1):
        p.append(mbox(x - 0.14, x + 0.14, 3.42, 3.5, zc + 0.3, ze - 0.6, "secondary", "bed rib"))
    return p + occupants(BELT, 2.1)


COCKPITS = {
    "fastback": {"name": "Fastback", "culture": "Classic Muscle", "kit": "classic", "parts": cockpit_fastback()},
    "hardtop": {"name": "Hardtop", "culture": "Pro Street", "kit": "prostreet", "parts": cockpit_hardtop()},
    "notch": {"name": "Notch", "culture": "Trans-Am racer", "kit": "transam", "parts": cockpit_notch()},
    "modern": {"name": "Modern", "culture": "Modern Muscle", "kit": "modern", "parts": cockpit_modern()},
    "ragtop": {"name": "Ragtop", "culture": "Pony", "kit": "pony", "parts": cockpit_ragtop()},
    "ute": {"name": "Ute", "culture": "Restomod", "kit": "restomod", "parts": cockpit_ute()},
}


# ----------------------------------------------------------------------------- FrontBody: nose clips
BASE_IDS = set()


def _base(parts):
    BASE_IDS.update(id(p) for p in parts)
    return parts


def front_base(W, hood="primary", stripe_z=-9.5):
    """Everything behind the nose that all clips share: tub, bonnet pad, wings, cowl seam face.
    W is the wing half width. Wide clips taper back to the door skin so no step shows at the cowl."""
    wr = min(W, 4.9)
    zc = Z_COWL
    p = [
        box(-X_TUB, X_TUB, FLOOR, ARCH, -9.5, -5.7, "detail", "inner tub: arch back wall at X 3.3"),
        box(-X_DOOR, X_DOOR, FLOOR, SILL, -5.7, zc, "detail", "sill rail"),
        box(-2.3, 2.3, ARCH, BELT, -9.5, zc, hood, "bonnet pad, flat at Y 3.3: Engine1 lands here"),
        mbox(2.3, W, ARCH, BELT, -9.5, -5.2, "primary", "wing over the arch: arch roof pad at Y 1.7"),
        mbox(X_TUB, W, SILL, ARCH, -5.7, -5.2, "primary", "wing behind the arch"),
        box(-wr, wr, SILL, ARCH, -5.2, zc, "primary", "lower wing up to the cowl seam"),
        mbox(2.3, wr, ARCH, BELT, -5.2, zc, "primary", "upper wing up to the cowl seam"),
        mbox(W, W + 0.06, STRIPE_LO, STRIPE_HI, stripe_z, -5.2, "secondary", "belt stripe"),
    ]
    if W > wr + 0.05:
        p.append(mwedge(wr, W, SILL, BELT, -5.2, zc, "+z", "-x", "primary", "wing tapers in to the door skin: the Coke-bottle waist"))
        p.append(plank((W + 0.03, 2.5, -5.2), (wr + 0.03, 2.5, zc), 0.06, 0.3, "secondary", "belt stripe on the taper", mirror=True))
    else:
        p.append(mbox(wr, wr + 0.06, STRIPE_LO, STRIPE_HI, -5.2, zc, "secondary", "belt stripe"))
    return _base(p)


def flank_panel(a, b, s0, s1, y, height, proud, ch, note):
    """Thin panel lying on a slanted plan face that runs from a=(x, z) to b=(x, z) on the +X side (mirrored)."""
    (ax, az), (bx, bz) = a, b
    length = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / length, (bz - az) / length
    nx, nz = dz, -dx                       # outward: forward and outboard
    off = proud / 2 + 0.01
    p0 = (ax + dx * s0 + nx * off, y, az + dz * s0 + nz * off)
    p1 = (ax + dx * s1 + nx * off, y, az + dz * s1 + nz * off)
    return plank(p0, p1, proud, height, ch, note, mirror=True)


def front_shark():
    """Classic: long and square. The wing tips run out ahead of a full-width grille set back under a deep brow."""
    W = 5.2
    return front_base(W, stripe_z=-13.3) + [
        box(-W, W, SILL, BELT, Z_NOSE, -9.5, "primary", "nose block; bumper pad under it at Y 0.3"),
        mbox(4.1, W, 2.4, BELT, -13.35, Z_NOSE, "primary", "wing tip runs out ahead of the grille"),
        mwedge(4.1, W, 1.5, 2.4, -13.35, Z_NOSE, "-z", "+y", "primary", "shark-nose undercut"),
        box(-4.1, 4.1, 2.75, BELT, -13.1, Z_NOSE, "primary", "deep brow over the grille"),
        box(-4.1, 4.1, 1.5, 2.75, -12.38, Z_NOSE, "detail", "full-width grille, set back under the brow"),
        mbox(2.5, 3.9, 1.9, 2.3, -12.44, -12.38, "neon", "lamp slit in the grille door"),
        box(-0.22, 0.22, 1.5, 2.75, -13.1, -12.38, "primary", "grille divider"),
        mbox(2.5, 3.2, BELT, BELT + 0.06, -13.1, Z_COWL, "secondary", "bonnet stripe beside the engine pad"),
    ]


def front_tilt():
    """Pro Street: narrow one-piece tilt nose. The whole bonnet droops in one long wedge to a low snout."""
    W = 4.9
    return front_base(W, stripe_z=-11.1) + [
        box(-W, W, SILL, 1.5, Z_NOSE, -9.5, "primary", "bumper shelf"),
        box(-W, W, 1.5, 1.9, -13.3, -9.5, "primary", "long snout lip"),
        wedge(-W, W, 1.9, BELT, -13.3, -9.5, "-z", "-y", "primary", "one-piece tilt nose: a long droop to the lip"),
        box(-2.4, 2.4, 0.7, 1.4, -12.38, Z_NOSE, "detail", "blanked mouth"),
        mbox(3.0, 4.3, 1.58, 1.84, -13.37, -13.3, "neon", "taped lamp"),
        mbox(3.9, 4.15, BELT, BELT + 0.12, -4.9, -4.65, "detail", "bonnet pin"),
        box(-4.6, 4.6, BELT, BELT + 0.05, Z_COWL - 0.45, Z_COWL - 0.3, "detail", "tilt-front hinge line"),
    ]


def front_airdam():
    """Trans-Am: flat bonnet to a hard edge, then a flat grille panel raked back hard. Box flares on the wings."""
    W = 5.2
    ztop, ylow = -10.9, 1.3
    return front_base(W, stripe_z=-11.3) + [
        box(-W, W, SILL, ylow, Z_NOSE, -9.5, "primary", "bumper shelf"),
        box(-W, W, ylow, BELT, ztop, -9.5, "primary", "upper nose, set back"),
        wedge(-W, W, ylow, BELT, Z_NOSE, ztop, "+y", "+z", "primary", "flat grille panel raked back"),
        plank((0, 1.575, -12.169), (0, 3.09, -11.109), 7.2, 0.08, "detail", "flat grille"),
        plank((4.3, 2.335, -11.686), (4.3, 2.908, -11.285), 1.1, 0.1, "neon", "lamp on the raked panel", mirror=True),
        box(-3.6, 3.6, 0.5, 1.15, -12.37, Z_NOSE, "detail", "low grille"),
        mbox(W, 5.44, ARCH, 2.3, -9.5, -5.7, "primary", "box flare over the arch"),
        mwedge(W, 5.44, ARCH, 2.3, -10.3, -9.5, "-z", "-x", "primary", "flare leading edge"),
        mbox(2.6, 4.4, BELT, 3.5, -8.6, -6.4, "detail", "wing-top louvres"),
        mbox(2.6, 4.4, BELT + 0.2, 3.56, -8.2, -8.0, "secondary", "louvre slat"),
        mbox(2.6, 4.4, BELT + 0.2, 3.56, -7.1, -6.9, "secondary", "louvre slat"),
    ]


def front_bluff():
    """Modern: short, tall, blunt and wide, with high wing crowns and a power dome ahead of the engine pad."""
    W = 5.44
    zn = -11.6
    return front_base(W, stripe_z=zn) + [
        box(-W, W, SILL, BELT, zn, -9.5, "primary", "short, tall, blunt nose"),
        mbox(2.5, W, BELT, 3.85, -10.7, -5.4, "primary", "high wing crown"),
        mwedge(2.5, W, BELT, 3.85, zn, -10.7, "-z", "-y", "primary", "crown leading edge"),
        mwedge(2.5, 4.85, BELT, 3.85, -5.4, Z_COWL, "+z", "-y", "primary", "crown fades into the cowl"),
        box(-2.2, 2.2, BELT, 3.55, -10.9, -9.95, "primary", "power dome ahead of the engine pad"),
        wedge(-2.2, 2.2, BELT, 3.55, zn, -10.9, "-z", "-y", "primary", "dome leading edge"),
        box(-4.9, 4.9, 2.2, 2.9, zn - 0.1, zn, "detail", "slot grille"),
        mbox(3.7, 4.7, 2.32, 2.78, zn - 0.17, zn - 0.1, "neon", "halo lamp"),
        box(-3.4, 3.4, 0.6, 1.7, zn - 0.1, zn, "detail", "lower intake"),
        mbox(W, 5.5, 0.9, 1.5, -5.65, -5.25, "detail", "wing gill"),
    ]


def front_beak():
    """Pony: a V in plan. The wings sweep back from a pointed centre prow, and a bonnet peak runs out to the tip."""
    W = 4.95
    zs, zt = -11.5, -12.9        # shoulder (outer corner) and inner end of the swept flank
    a, b = (1.4, zt), (W, zs)
    return front_base(W, stripe_z=zs) + [
        box(-W, W, SILL, 2.6, zs, -9.5, "primary", "nose block"),
        box(-W, W, 2.6, BELT, -10.4, -9.5, "primary"),
        wedge(-W, W, 2.6, BELT, zs, -10.4, "-z", "-y", "primary", "bonnet leading edge rolls down"),
        box(-1.4, 1.4, SILL, 1.5, -12.4, zs, "primary", "prow keel; bumper pad under it"),
        box(-1.4, 1.4, 1.5, 2.6, -13.3, zs, "primary", "pointed centre prow"),
        wedge(-1.4, 1.4, 2.6, BELT, -13.3, -10.4, "-z", "-y", "primary", "bonnet peak runs out to the prow tip"),
        mwedge(1.4, W, 1.5, 2.6, zt, zs, "-z", "-x", "primary", "wing swept back from the prow"),
        mwedge(1.4, W, SILL, 1.5, -12.4, zs, "-z", "-x", "primary", "lower wing, swept back"),
        box(-1.1, 1.1, 1.7, 2.4, -13.38, -13.3, "detail", "prow mouth"),
        flank_panel(a, b, 0.25, 2.1, 2.0, 0.8, 0.08, "detail", "swept side grille"),
        flank_panel(a, b, 2.35, 3.45, 2.0, 0.75, 0.12, "neon", "single lamp on the swept wing"),
    ]


def front_blades():
    """Restomod: a W in plan. Two wing blades carry stacked lamp towers that stand above the bonnet,
    either side of two deep-set grilles and an arrow-head centre prow under a raised power bulge."""
    W = 5.3
    zc = -11.5
    return front_base(W, stripe_z=-13.3) + [
        box(-4.2, 4.2, SILL, BELT, zc, -9.5, "primary", "recessed centre nose"),
        mbox(4.2, W, SILL, BELT, Z_NOSE, -9.5, "primary", "wing blade"),
        mbox(4.2, W, 1.5, BELT, -13.3, Z_NOSE, "primary", "blade tip runs forward over the bumper"),
        mbox(4.2, W, BELT, 3.8, -13.3, -11.9, "primary", "lamp tower stands above the bonnet"),
        mwedge(4.2, W, BELT, 3.8, -11.9, -9.7, "+z", "-y", "primary", "tower fades into the wing"),
        box(-1.3, 1.3, SILL, BELT, Z_NOSE, zc, "primary", "centre prow root; bumper pad under it"),
        mwedge(0.0, 1.3, 1.5, 3.7, -13.3, Z_NOSE, "-z", "-x", "primary", "arrow-head centre prow"),
        box(-1.3, 1.3, BELT, 3.7, Z_NOSE, -9.2, "primary", "raised centre power bulge"),
        mbox(1.3, 4.2, 1.2, 2.9, zc - 0.1, zc, "detail", "deep-set grille"),
        mbox(4.4, 5.1, 2.95, 3.65, -13.38, -13.3, "neon", "upper stacked lamp"),
        mbox(4.4, 5.1, 1.95, 2.65, -13.38, -13.3, "neon", "lower stacked lamp"),
        mbox(1.5, 4.0, 0.55, 0.95, zc - 0.08, zc, "neon", "light bar"),
    ]


# ----------------------------------------------------------------------------- RearBody: tail and haunches
def rear_base(W, tail=Z_TAIL, lower=SILL):
    """Shared by every tail: tub, flat deck pad, flaring haunch, engine bulkhead, haunch tails.
    The arch runs from the back seam to the bulkhead, so the tail behind it is short.
    `lower` lifts the bottom edge of the haunch tails (a dark frame horn keeps the bumper pad)."""
    wf = 4.9
    zb, zf, zk = Z_BACK, Z_FLARE, Z_BULK
    p = [
        box(-X_TUB, X_TUB, FLOOR, ARCH, zb, zk - 0.1, "detail", "inner tub: arch back wall at X 3.3"),
        box(-wf, wf, SILL, ARCH, zb, RA0, "primary", "arch leading edge"),
        box(-4.4, 4.4, ARCH, BELT, zb, zk - 0.1, "primary", "deck pad, flat at Y 3.3 under every roofline"),
        mbox(BAY_X, 4.4, ARCH, BELT, zk - 0.1, zk, "primary"),
        mbox(4.4, wf, ARCH, BELT, zb, zf, "primary"),
        mbox(4.4, W, ARCH, BELT, zf, zk, "primary", "haunch over the arch: arch roof pad at Y 1.7"),
        box(-BAY_X, BAY_X, SILL, BELT, zk - 0.1, zk, "detail", "bulkhead: Engine2 pad at Z 10.2"),
        mbox(3.35, W, lower, BELT, zk, tail, "primary", "haunch tail: spoiler pad on top, bumper pad under"),
        mbox(W, W + 0.06, STRIPE_LO, STRIPE_HI, zf, tail, "secondary", "belt stripe"),
    ]
    if W > wf + 0.05:
        p.append(mwedge(wf, W, ARCH, BELT, zb, zf, "-z", "-x", "primary", "haunch kicks out from the door skin"))
        p.append(plank((wf + 0.03, 2.5, zb), (W + 0.03, 2.5, zf), 0.06, 0.3, "secondary", "belt stripe on the flare", mirror=True))
    else:
        p.append(mbox(W, W + 0.06, STRIPE_LO, STRIPE_HI, zb, zf, "secondary", "belt stripe"))
    if lower > SILL:
        p.append(mbox(3.4, 4.4, SILL, lower, zk, tail - 0.2, "detail", "frame horn: bumper pad at Y 0.3"))
    return _base(p)


def hip(W, top, z_flat1, z_fall1=None, z_rise0=Z_BACK + 0.1):
    """A haunch crown above the belt, outside the glass: it rises with the flare, runs flat, then may fall."""
    p = [
        mwedge(4.5, 4.9, BELT, top, z_rise0, Z_FLARE, "-z", "-y", "primary", "hip rises from the door"),
        mbox(4.5, W, BELT, top, Z_FLARE, z_flat1, "primary", "hip crown over the arch"),
    ]
    if W > 4.95:
        p.append(mwedge(4.9, W, BELT, top, z_rise0, Z_FLARE, "-z", "-x", "primary", "hip kicks out with the haunch"))
    if z_fall1:
        p.append(mwedge(4.5, W, BELT, top, z_flat1, z_fall1, "+z", "-y", "primary", "hip falls to the tail"))
    return p


def rear_coke():
    """Classic: Coke-bottle hip that swells over the arch and falls to a flat tail panel."""
    W = 5.3
    p = rear_base(W) + hip(W, 3.78, 9.6, 11.8)
    for i in range(3):
        p.append(mbox(3.65 + i * 0.55, 4.0 + i * 0.55, 1.5, 2.9, Z_TAIL, Z_TAIL + 0.08, "neon", "sequential tail lamp"))
    return p


def rear_tubbed():
    """Pro Street: the widest tail, flat on top, with the lower edge cut high to show the frame horns."""
    W = 5.44
    return rear_base(W, lower=1.35) + [
        mbox(3.6, 5.1, 2.0, 2.8, Z_TAIL, Z_TAIL + 0.08, "neon", "wide tail lamp"),
        mbox(W, 5.5, ARCH, 2.2, Z_FLARE, Z_TAIL, "primary", "tub flare, flat to the tail"),
    ]


def rear_kamm():
    """Trans-Am: Kamm tail, chopped off short and square, with box flares over the arches."""
    W = 5.2
    tail = 11.6
    return rear_base(W, tail=tail) + [
        mbox(W, 5.44, ARCH, 2.3, Z_FLARE, Z_BULK, "primary", "box flare over the arch"),
        mwedge(4.9, 5.44, ARCH, 2.3, RA0, Z_FLARE, "-z", "-x", "primary", "flare leading edge"),
        mwedge(W, 5.44, ARCH, 2.3, Z_BULK, 11.0, "+z", "-x", "primary", "flare trailing edge"),
        mbox(3.6, 4.3, 1.9, 2.8, tail, tail + 0.08, "neon", "tail lamp"),
        mbox(4.45, 5.0, 1.9, 2.8, tail, tail + 0.08, "neon", "tail lamp"),
        mbox(4.6, 5.0, BELT, 3.42, 8.6, 9.4, "secondary", "dry-break fuel filler"),
    ]


def rear_highdeck():
    """Modern: a high hip the full length of the tail and a long overhang above the bumper."""
    W = 5.44
    return rear_base(W) + hip(W, 3.8, 12.9) + [
        mbox(3.35, W, 2.0, BELT, Z_TAIL, 12.9, "primary", "tail overhang above the bumper"),
        mbox(3.5, 5.3, 2.35, 2.75, 12.9, 12.98, "neon", "slim tail lamp"),
        mbox(W, 5.5, 0.9, 1.5, 10.5, 11.5, "detail", "quarter gill"),
    ]


def rear_short():
    """Pony: narrow slant tail. The deck is flat to the spoiler pad, then falls away to a low tail panel."""
    W = 5.0
    zk = 11.4
    p = rear_base(W, tail=zk) + [
        mbox(3.35, W, SILL, 1.6, zk, Z_TAIL, "primary", "lower tail"),
        mbox(3.35, W, 1.6, 2.3, zk, 12.9, "primary", "low tail panel"),
        mwedge(3.35, W, 2.3, BELT, zk, 12.9, "+z", "-y", "primary", "deck falls away behind the spoiler pad"),
    ]
    for i in range(3):
        p.append(mbox(3.6 + i * 0.45, 3.9 + i * 0.45, 1.7, 2.2, 12.9, 12.98, "neon", "triple tail lamp"))
    return p


def rear_square():
    """Restomod: square tail. The longest, squarest tail, with tall rail caps running back from the arch."""
    W = 5.2
    return rear_base(W) + [
        mbox(3.35, W, 1.6, BELT, Z_TAIL, 13.1, "primary", "long tail overhang"),
        mbox(4.5, W, BELT, 3.7, 9.0, 13.1, "primary", "tall tail-rail cap"),
        mwedge(4.5, W, BELT, 3.7, 8.0, 9.0, "-z", "-y", "primary", "cap leading edge"),
        mbox(4.7, 5.1, 1.8, 3.1, 13.1, 13.18, "neon", "tall corner lamp"),
        mbox(3.5, 4.5, 2.2, 2.6, 13.1, 13.18, "secondary", "tail trim"),
    ]


# ----------------------------------------------------------------------------- Engine1: hood engines
# Drawn around Z -7, then slid back by E1_SHIFT in the catalogue. Every thrust face is 0.7 across or more
# and points up and back, so the glow shows from the chase camera.
def e1_shaker():
    """One big turbine lying on the bonnet behind a square twin-mouth shaker scoop, split dump nozzles."""
    y = 4.3
    p = [box(-1.1, 1.1, 3.4, 4.8, -9.2, -8.2, "secondary", "shaker scoop: the turbine intake"),
         wedge(-1.1, 1.1, 3.4, 4.8, -9.6, -9.2, "+y", "+z", "secondary", "scoop face leans back"),
         mbox(0.14, 0.95, 3.75, 4.3, -9.52, -9.3, "detail", "scoop mouth"),
         box(-1.16, 1.16, 4.8, 4.92, -9.25, -8.1, "detail", "scoop lid"),
         cylz(0, y, -8.3, -5.7, 1.75, "detail", "casing"),
         cylz(0, y, -5.7, -4.7, 1.95, "detail", "turbine housing"),
         ball(0, y, -4.8, 1.15, "detail", "tail cone: no flat end face"),
         box(-0.5, 0.5, BELT, 3.6, -8.2, -5.0, "detail", "cradle on the bonnet pad")]
    p += jet((0.8, y + 0.05, -5.6), (1.68, y + 0.38, -4.8), 0.95, "detail", None, 0.3, mirror=True,
             note="split dump nozzle, up and back", glow=0.7)
    return p


def e1_blower():
    """Low, wide blower case under a scoop, with two fat zoomie nozzles swept up and back each side."""
    p = [
        box(-1.25, 1.25, BELT, 3.75, -8.5, -5.1, "detail", "manifold on the bonnet pad"),
        box(-1.2, 1.2, 3.75, 4.45, -8.3, -5.3, "secondary", "low, wide blower case"),
        box(-1.24, 1.24, 3.93, 4.03, -8.34, -5.26, "detail", "case rib"),
        box(-1.24, 1.24, 4.18, 4.28, -8.34, -5.26, "detail", "case rib"),
        box(-0.55, 0.55, 3.8, 4.4, -9.0, -8.3, "detail", "drive snout"),
        box(-1.0, 1.0, 4.45, 5.28, -7.6, -6.0, "primary", "tall scoop"),
        wedge(-1.0, 1.0, 4.45, 5.28, -6.0, -5.2, "+z", "-y", "primary", "scoop tail"),
        box(-0.85, 0.85, 4.58, 5.16, -7.72, -7.6, "detail", "scoop intake"),
    ]
    for z in (-7.5, -6.0):
        p += jet((1.2, 3.7, z), (1.7, 4.48, z + 0.7), 0.9, "detail", None, 0.3, mirror=True,
                 note="fat zoomie nozzle", glow=0.7)
    return p


def e1_crossram():
    """Two slim turbines wide apart on a low cross-ram plenum."""
    x, y = 1.5, 3.98
    p = [
        box(-1.0, 1.0, BELT, 3.72, -8.4, -5.4, "secondary", "cross-ram plenum"),
        box(-1.5, 1.5, BELT, 3.5, -7.4, -6.4, "detail", "runner"),
        box(-0.6, 0.6, 3.72, 3.84, -8.0, -5.8, "detail", "plenum lid"),
        cylz(x, y, -9.7, -8.9, 1.3, "secondary", "intake collar", mirror=True),
        ball(x, y, -9.45, 0.65, "detail", "intake spinner", mirror=True),
        cylz(x, y, -8.9, -5.6, 1.1, "detail", "slim turbine", mirror=True),
    ]
    p += jet((x, y, -5.7), (x, y + 0.55, -4.8), 1.0, "detail", None, 0.32, mirror=True, note="upswept nozzle", glow=0.75)
    return p


def e1_cowlslot():
    """A flattened turbine: a wide, low intake mouth, a flat twin-rotor body and a slot nozzle that fires up and back."""
    return [
        box(-1.9, 1.9, BELT, 3.5, -8.9, -4.6, "detail", "cradle on the bonnet pad"),
        box(-1.95, 1.95, 3.4, 4.5, -9.3, -8.5, "secondary", "wide, low intake mouth"),
        box(-1.7, 1.7, 3.55, 4.35, -9.38, -9.3, "detail", "intake throat"),
        cylz(1.0, 4.0, -8.5, -5.9, 1.4, "detail", "flattened turbine body: one rotor each side", mirror=True),
        box(-1.0, 1.0, 3.5, 4.7, -8.5, -5.9, "primary", "flat casing between the rotors"),
        box(-0.12, 0.12, 4.7, 4.85, -8.5, -5.6, "secondary", "spine"),
        box(-1.9, 1.9, 3.5, 4.3, -5.9, -4.6, "secondary", "slot nozzle housing"),
        wedge(-1.9, 1.9, 4.3, 5.0, -5.9, -5.0, "-z", "-y", "secondary", "nozzle hood rises to the slot"),
        box(-1.6, 1.6, 4.3, 4.9, -5.02, -4.7, "thrust", "slot jet, 0.6 tall, fires up and back"),
    ]


def e1_quadrow():
    """Cluster of four small jets in a row, pitched up at the back."""
    p = [
        box(-2.1, 2.1, BELT, 3.5, -8.7, -7.5, "detail", "plinth on the bonnet pad"),
        box(-2.0, 2.0, BELT, 4.05, -6.9, -6.5, "detail", "rear cradle"),
    ]
    for x in (0.52, 1.56):
        p += jet((x, 3.95, -8.5), (x, 4.62, -6.2), 1.0, "secondary", "detail", 0.34, mirror=True, note="small jet", glow=0.72)
    return p


def e1_tunnelram():
    """One tall ram stack with a big square bellmouth on a slim plenum, and a dump nozzle each side."""
    p = [
        box(-0.8, 0.8, BELT, 4.1, -8.6, -5.8, "secondary", "slim plenum on the bonnet pad"),
        box(-0.85, 0.85, 3.7, 3.82, -8.65, -5.75, "detail", "plenum rib"),
        box(-0.6, 0.6, 4.1, 4.9, -7.9, -6.5, "detail", "single tall ram stack"),
        box(-0.9, 0.9, 4.9, 5.28, -8.25, -6.15, "secondary", "square bellmouth"),
        box(-0.68, 0.68, 5.2, 5.3, -8.03, -6.37, "detail", "open mouth"),
    ]
    p += jet((0.75, 3.8, -6.6), (1.68, 4.15, -5.3), 0.95, "detail", None, 0.3, mirror=True,
             note="side dump nozzle, up and back", glow=0.7)
    return p


# ----------------------------------------------------------------------------- Engine2: tail engines
ZE = Z_BULK + 0.1      # every tail engine starts just off the bulkhead


def e2_twin():
    """Twin barrels side by side with ram scoops on the deck."""
    p = turbine(1.6, 1.8, ZE, 13.1, 2.4, mirror=True)
    p += [
        box(-0.2, 0.2, 0.5, 3.25, ZE - 0.05, 12.6, "detail", "spine"),
        mwedge(0.6, 2.6, 3.1, 3.95, ZE, 12.0, "+z", "-y", "primary", "ram scoop"),
        mbox(0.8, 2.4, 3.3, 3.85, ZE - 0.08, ZE, "detail", "scoop mouth"),
    ]
    return p


def e2_mono():
    """One huge turbine on the centreline."""
    y = 2.05
    return [
        cylz(0, y, ZE, 11.8, 3.1, "secondary", "intake collar"),
        cylz(0, y, 11.8, 13.15, 2.9, "detail", "nozzle bell"),
        cylz(0, y, 13.0, 13.6, 2.4, "thrust", "jet"),
        box(-1.0, 1.0, 3.55, 4.15, ZE, 11.6, "primary", "deck scoop"),
        box(-0.85, 0.85, 3.65, 4.08, ZE - 0.08, ZE, "detail", "scoop mouth"),
        wedge(-1.0, 1.0, 3.55, 4.15, 11.6, 12.5, "+z", "-y", "primary", "scoop tail"),
        tube((1.4, 1.2, 10.9), (3.2, 0.7, 10.9), 0.3, "detail", "engine mount", mirror=True),
    ]


def e2_overunder():
    """Two turbines stacked on the centreline, the upper one set further back. A body-colour tail panel
    frames the stack, so the two nozzles poke through a finished tail instead of sitting in a dark bay."""
    return [
        cylz(0, 1.35, ZE, 11.3, 2.1, "secondary", "lower intake collar"),
        cylz(0, 1.35, 11.3, 12.75, 1.9, "detail", "lower turbine"),
        cylz(0, 1.35, 12.6, 13.2, 1.6, "thrust", "lower jet"),
        cylz(0, 3.15, 10.8, 11.8, 2.1, "secondary", "upper intake collar"),
        ball(0, 3.15, 10.95, 1.1, "detail", "upper intake spinner"),
        cylz(0, 3.15, 11.8, 13.1, 1.9, "detail", "upper turbine"),
        cylz(0, 3.15, 12.95, 13.6, 1.6, "thrust", "upper jet"),
        box(-0.3, 0.3, 2.0, 2.5, ZE, 12.6, "detail", "stack pylon"),
        mbox(1.0, 3.25, 0.5, BELT, 11.4, 11.6, "primary", "tail panel either side of the stack"),
        mbox(1.45, 2.85, 1.3, 2.6, 11.6, 11.68, "detail", "cheek duct in the tail panel"),
    ]


def e2_slot():
    """Flat full-width slot burner under a louvred lid."""
    return [
        box(-3.1, 3.1, 1.9, 2.7, ZE - 0.05, 12.6, "detail", "burner box"),
        box(-3.2, 3.2, 1.95, 2.65, 12.6, 13.1, "secondary", "slot nozzle frame"),
        box(-2.9, 2.9, 2.05, 2.55, 12.95, 13.4, "thrust", "slot jet"),
        box(-3.2, 3.2, 2.7, BELT, ZE - 0.05, 12.4, "primary", "boot lid"),
        box(-2.6, 2.6, BELT, 3.38, 10.5, 10.85, "detail", "intake louvre"),
        box(-2.6, 2.6, BELT, 3.38, 11.15, 11.5, "detail", "intake louvre"),
        box(-2.6, 2.6, BELT, 3.38, 11.8, 12.15, "detail", "intake louvre"),
        mbox(0.9, 1.0, 2.0, 2.6, 12.6, 13.2, "secondary", "nozzle vane"),
    ]


def e2_quad():
    """Four small jets, a stacked pair in each corner of the bay."""
    p = [box(-0.3, 0.3, 0.6, 3.0, ZE - 0.05, 12.0, "secondary", "centre spine")]
    for y in (1.05, 2.75):
        p += [cylz(2.45, y, ZE, 12.3, 1.3, "detail", "jet body", mirror=True),
              cylz(2.45, y, 12.3, 12.95, 1.45, "secondary", "nozzle", mirror=True),
              cylz(2.45, y, 12.8, 13.35, 0.95, "thrust", "jet", mirror=True)]
    p += [
        mwedge(1.8, 3.1, 3.4, 4.0, ZE, 11.7, "+z", "-y", "primary", "corner ram scoop"),
        mbox(1.95, 2.95, 3.48, 3.9, ZE - 0.08, ZE, "detail", "scoop mouth"),
    ]
    return p


def e2_inline():
    """Four small jets in a low row under a flat plenum with open trumpets."""
    p = [box(-3.15, 3.15, 1.65, 2.1, ZE - 0.05, 12.2, "secondary", "flat plenum")]
    for x in (0.8, 2.4):
        p += [cylz(x, 1.0, ZE, 12.4, 1.25, "detail", "jet body", mirror=True),
              cylz(x, 1.0, 12.4, 13.05, 1.4, "secondary", "nozzle", mirror=True),
              cylz(x, 1.0, 12.9, 13.45, 0.9, "thrust", "jet", mirror=True),
              cyly(x, 11.3, 2.1, 2.75, 0.8, "detail", "intake trumpet", mirror=True)]
    return p


# ----------------------------------------------------------------------------- Stabilisers: lift jets in the arches
# Each option fills, blanks or vents its arch and shows an intake, a body and a glowing nozzle.
# Every pod and can is longer than it is wide (1.4 to 3.3 times): nothing reads as a drum.
# Every option stands partly outside the body skin, and jet bodies are secondary, so the lift jets show from above.
def corners(fn):
    """fn(zc, rear) -> parts for the +X corner; mirrored copies give the other side."""
    return fn(FRONT_ARCH, False) + fn(REAR_ARCH, True)


def _unit(v):
    v = np.array(v, dtype=float)
    return v / np.linalg.norm(v)


def st_corner_turbines():
    """Classic: a twin pair in each arch. Two lift turbines hang from a log plenum, splayed fore and aft and
    canted outboard, so both nozzles and both plumes stand outside the body skin."""
    def one(zc, rear):
        p = [mbox(3.5, 5.0, 1.3, 1.66, zc - 1.1, zc + 1.1, "detail", "pylon to the arch roof pad"),
             cylz(4.2, 1.05, zc - 1.3, zc + 1.4, 0.85, "detail", "log plenum under the arch roof", mirror=True),
             cylz(4.2, 1.05, zc - 1.85, zc - 1.3, 1.05, "secondary", "plenum intake lip", mirror=True)]
        for s in (-1, 1):
            u = _unit((0.45, -0.75, 0.3 * s))
            a = np.array([4.2, 1.0, zc + 0.5 * s])
            b = a + 2.1 * u
            p += [tube(a, b, 1.1, "secondary", "lift turbine, 1.1 across and 2.1 long, canted out", mirror=True),
                  tube(b - 0.55 * u, b, 1.3, "detail", "nozzle", mirror=True),
                  tube(b - 0.1 * u, b + 0.45 * u, 1.0, "thrust", "jet, outboard of the skin", mirror=True)]
        return p
    return corners(one)


def st_big_little():
    """Pro Street: one long fat nacelle standing proud of each rear arch, one thin canted jet in each front arch."""
    def one(zc, rear):
        if rear:
            x, y = 5.1, 0.4
            p = [mbox(3.6, 5.3, 1.2, 1.66, zc - 0.9, zc + 0.6, "detail", "pylon"),
                 cylz(x, y, zc - 1.85, zc - 1.25, 1.3, "detail", "tapered intake lip", mirror=True),
                 cylz(x, y, zc - 1.25, zc + 0.9, 1.7, "secondary", "long fat nacelle, 1.7 across, proud of the skin", mirror=True)]
            p += jet((x, y - 0.1, zc + 0.55), (x + 0.2, y - 1.05, zc + 1.2), 1.35, "detail", None, 0.38, mirror=True,
                     note="big lift nozzle: down, back and out", glow=1.1)
            return p
        u = _unit((0.9, -1.85, 1.0))
        a = np.array([4.4, 1.3, zc - 0.55])
        b = a + 2.29 * u
        return [
            mbox(3.45, 3.62, SILL, 1.66, zc - 1.85, zc + 1.85, "primary", "body-colour liner blanks the front arch"),
            mbox(3.62, 4.6, 1.25, 1.66, zc - 0.8, zc + 0.2, "detail", "slim pylon"),
            tube(a - 0.05 * u, a + 0.45 * u, 0.95, "detail", "intake lip", mirror=True),
            tube(a, b, 0.7, "secondary", "thin front lift jet, 0.7 across: down, back and out", mirror=True),
            tube(b - 0.6 * u, b, 1.15, "detail", "flared nozzle", mirror=True),
            tube(b - 0.1 * u, b + 0.4 * u, 1.0, "thrust", "jet", mirror=True),
        ]
    return corners(one)


def st_outriggers():
    """Trans-Am: the arch is closed by a louvred panel and a slim pod stands outboard of it on an arm."""
    def one(zc, rear):
        x, y = 5.45, 0.15
        p = [mbox(4.72, 4.88, SILL, 1.66, zc - 1.85, zc + 1.85, "primary", "louvred blanking panel closes the arch"),
             mbox(3.45, 5.2, -0.05, 0.3, zc - 0.45, zc + 0.45, "detail", "outrigger arm from the arch back wall"),
             plank((4.7, 1.62, zc), (5.3, 0.5, zc), 0.5, 0.2, "detail", "brace up to the arch roof pad", mirror=True),
             cylz(x, y, zc - 1.85, zc - 1.4, 1.05, "detail", "intake lip", mirror=True),
             cylz(x, y, zc - 1.4, zc + 1.0, 0.9, "secondary", "slim outboard pod", mirror=True)]
        for dz in (-1.35, -0.75, 0.75, 1.35):
            p.append(mbox(4.88, 4.94, 0.8, 1.5, zc + dz - 0.13, zc + dz + 0.13, "detail", "louvre"))
        p += jet((x, y, zc + 0.9), (x, y - 0.35, zc + 1.45), 0.8, "detail", None, 0.3, mirror=True,
                 note="vectoring nozzle", glow=0.62)
        return p
    return corners(one)


def st_vector_cans():
    """Modern: one large can per arch, swung outboard in a yoke whose outer arm stands outside the body skin."""
    def one(zc, rear):
        u = _unit((0.2, -0.62, 0.76))
        a = np.array([4.8, 0.95, zc - 0.95])
        m, b = a + 1.6 * u, a + 2.5 * u
        return [
            mbox(3.5, 5.98, 1.3, 1.66, zc - 1.5, zc + 0.3, "detail", "yoke crosshead under the arch roof pad"),
            mbox(5.74, 5.98, 0.0, 1.3, zc - 1.0, zc - 0.2, "secondary", "outer yoke arm, outboard of the body skin"),
            mbox(3.8, 4.04, 0.0, 1.3, zc - 1.0, zc - 0.2, "secondary", "inner yoke arm"),
            tube(a - 0.1 * u, a + 0.4 * u, 1.6, "detail", "intake lip", mirror=True),
            tube(a, m, 1.4, "secondary", "one large vectoring can, 1.4 across and 2.5 long", mirror=True),
            tube(m, b, 1.25, "detail", "nozzle", mirror=True),
            tube(b - 0.1 * u, b + 0.4 * u, 1.1, "thrust", "jet", mirror=True),
        ]
    return corners(one)


def st_glide_paddles():
    """Pony: a slim lift nacelle hung in each arch on a fin, with a swept glide paddle on its outer side."""
    def one(zc, rear):
        x, y = 4.5, 0.2
        p = [mbox(4.38, 4.62, 0.6, 1.66, zc - 0.7, zc + 0.8, "secondary", "fin up to the arch roof pad"),
             mwedge(4.38, 4.62, 0.6, 1.66, zc - 1.5, zc - 0.7, "-z", "+y", "secondary", "fin leading edge"),
             cylz(x, y, zc - 1.85, zc - 1.35, 1.2, "detail", "intake lip", mirror=True),
             cylz(x, y, zc - 1.35, zc + 0.9, 1.05, "secondary", "slim lift nacelle", mirror=True),
             mwedge(5.0, 5.95, 0.1, 0.3, zc - 1.0, zc + 1.0, "-z", "-x", "secondary", "glide paddle: a swept blade")]
        p += jet((x, y, zc + 0.8), (x, y - 0.62, zc + 1.42), 0.95, "detail", None, 0.25, mirror=True,
                 note="nozzle, down and back", glow=0.72)
        return p
    return corners(one)


def st_skirted_triples():
    """Restomod: a skirt blanks the top half of the arch. Under it three canted lift cans stand proud,
    fed by an intake scoop on the front of the skirt."""
    def one(zc, rear):
        p = [
            mbox(5.0, 5.25, 0.7, 1.66, zc - 1.85, zc + 1.85, "primary", "arch skirt: the top half of the arch is blanked"),
            mbox(5.0, 5.36, 0.55, 0.7, zc - 1.85, zc + 1.85, "secondary", "nozzle rail under the skirt"),
            mbox(3.5, 5.0, 0.9, 1.66, zc - 1.7, zc + 1.7, "detail", "plenum against the arch roof pad"),
            mbox(5.25, 5.7, 0.95, 1.5, zc - 1.85, zc - 0.9, "secondary", "intake scoop on the skirt"),
            mbox(5.3, 5.65, 1.02, 1.43, zc - 1.9, zc - 1.85, "detail", "scoop mouth"),
            mwedge(5.25, 5.7, 0.95, 1.5, zc - 0.9, zc + 0.2, "+z", "-x", "secondary", "scoop fairing"),
        ]
        for dz in (-0.95, 0.05, 1.05):
            p += jet((5.32, 0.7, zc + dz - 0.4), (5.32, -0.2, zc + dz + 0.3), 0.8, "detail", None, 0.3, mirror=True,
                     note="lift can, proud of the skirt", glow=0.62)
        return p
    return corners(one)


# ----------------------------------------------------------------------------- Boost: side burners under the sills
BZ0, BZ1 = Z_COWL + 0.1, RA0 - 0.15      # usable sill length: -1.9 to 6.25


def bo_side_pipes():
    """Classic: one long pipe the full length of the sill with a fat afterburner can at the back."""
    x, y = 5.55, -0.74
    return [
        cylz(x, y, BZ0, -1.0, 1.15, "detail", "intake bell", mirror=True),
        cylz(x, y, -1.0, 4.5, 0.95, "secondary", "long side pipe", mirror=True),
        cylz(x, y, 4.5, 5.75, 1.2, "detail", "afterburner can", mirror=True),
        cylz(x, y, 5.6, BZ1, 0.85, "thrust", "jet", mirror=True),
        mbox(4.82, 5.4, -0.5, 0.2, -0.2, 0.2, "detail", "hanger on the sill rail"),
        mbox(4.82, 5.4, -0.5, 0.2, 3.4, 3.8, "detail", "hanger on the sill rail"),
    ]


def bo_bazookas():
    """Pro Street: one short fat burner under the back of each door."""
    x, y = 5.55, -0.62
    return [
        cylz(x, y, 2.2, 3.2, 1.45, "secondary", "intake collar", mirror=True),
        ball(x, y, 2.4, 0.8, "detail", "intake spinner", mirror=True),
        cylz(x, y, 3.2, 4.6, 1.25, "detail", "short fat burner", mirror=True),
        cylz(x, y, 4.6, 5.7, 1.45, "detail", "nozzle bell", mirror=True),
        cylz(x, y, 5.55, BZ1, 1.05, "thrust", "jet", mirror=True),
        mbox(4.82, 5.2, -0.5, 0.2, 3.3, 4.5, "detail", "hanger on the sill rail"),
    ]


def bo_megaphones():
    """Trans-Am: a megaphone under the front of each door. A thin throat flares in four steps to a wide mouth."""
    x, y = 5.55, -0.58
    return [
        cylz(x, y, BZ0, -1.0, 0.6, "detail", "megaphone throat", mirror=True),
        cylz(x, y, -1.0, -0.1, 0.85, "secondary", "megaphone, second step", mirror=True),
        cylz(x, y, -0.1, 0.8, 1.15, "secondary", "megaphone, third step", mirror=True),
        cylz(x, y, 0.8, 1.7, 1.45, "secondary", "megaphone mouth", mirror=True),
        cylz(x, y, 1.55, 2.2, 1.15, "thrust", "jet", mirror=True),
        mbox(4.82, 5.2, -0.45, 0.2, -0.8, -0.3, "detail", "hanger on the sill rail"),
    ]


def bo_sill_slots():
    """Modern: a flat burner blade along the sill between a boxed intake at the front and a boxed nozzle at the back.
    Only the rear nozzle is a jet. The strip along the blade edge is lighting."""
    return [
        mbox(4.85, 6.2, -0.6, 0.22, BZ0, -0.8, "secondary", "boxed intake at the front of the sill"),
        mbox(4.98, 6.07, -0.48, 0.1, BZ0 - 0.06, BZ0, "detail", "intake mouth"),
        mbox(4.85, 6.15, -0.3, 0.05, -0.8, 5.0, "detail", "flat sill burner blade"),
        mbox(4.82, 5.4, 0.05, 0.22, -0.8, 5.0, "secondary", "blade root on the sill rail"),
        mbox(6.15, 6.25, -0.28, 0.0, -0.4, 4.8, "neon", "edge light strip: lighting, not a jet"),
        mbox(4.85, 6.3, -0.8, 0.25, 5.0, 5.8, "secondary", "boxed nozzle"),
        mbox(4.95, 6.2, -0.67, 0.08, 5.7, BZ1, "thrust", "nozzle jet, 1.25 by 0.75"),
    ]


def bo_lake_trios():
    """Pony: three fat lake-pipe stubs on a log manifold, kicked out and down."""
    p = [
        cylz(5.2, -0.3, -1.0, 3.9, 0.6, "detail", "log manifold", mirror=True),
        mbox(4.82, 5.1, -0.4, 0.2, -0.7, -0.3, "detail", "hanger on the sill rail"),
        mbox(4.82, 5.1, -0.4, 0.2, 3.3, 3.7, "detail", "hanger on the sill rail"),
        cylz(5.2, -0.3, -1.6, -1.0, 0.85, "secondary", "intake bell", mirror=True),
    ]
    for z in (-0.3, 1.3, 2.9):
        p += jet((5.3, -0.35, z), (5.72, -0.78, z + 1.0), 0.95, "secondary", None, 0.3, mirror=True,
                 note="lake-pipe stub, kicked out and down", glow=0.7)
    return p


def bo_underslung():
    """Restomod: two thin pipes slung low under the sill, the full length of the door."""
    p = [mbox(4.82, 5.0, -0.8, 0.2, -0.4, 0.0, "detail", "hanger on the sill rail"),
         mbox(4.82, 5.0, -0.8, 0.2, 4.0, 4.4, "detail", "hanger on the sill rail"),
         mbox(5.0, 6.2, -0.8, -0.62, -0.4, 0.0, "detail", "hanger strap"),
         mbox(5.0, 6.2, -0.8, -0.62, 4.0, 4.4, "detail", "hanger strap")]
    for x in (5.22, 5.88):
        p += [cylz(x, -0.98, BZ0, -1.5, 0.72, "secondary", "intake lip", mirror=True),
              cylz(x, -0.98, -1.5, 5.1, 0.6, "detail", "underslung pipe", mirror=True),
              cylz(x, -0.98, 5.1, 5.8, 0.8, "secondary", "nozzle tip", mirror=True),
              cylz(x, -0.98, 5.65, BZ1, 0.6, "thrust", "jet", mirror=True)]
    return p


# ----------------------------------------------------------------------------- SidePods: rockers
SZ0, SZ1 = Z_COWL + 0.1, Z_BACK - 0.1    # -1.9 to 6.1


def sp_rocker_scoop():
    return [
        mbox(4.82, 5.05, SILL, 0.72, SZ0, SZ1, "secondary", "bright rocker moulding"),
        mbox(4.82, 5.3, 1.1, 2.15, 4.6, SZ1, "primary", "quarter scoop"),
        mbox(4.9, 5.24, 1.2, 2.05, 4.5, 4.6, "detail", "scoop mouth"),
    ]


def sp_heat_shield():
    p = [mbox(4.82, 5.0, SILL, 1.6, SZ0, SZ1, "detail", "full-length heat shield")]
    for z in (-0.8, 0.8, 2.4, 4.0):
        p.append(mbox(5.0, 5.08, 0.55, 1.4, z, z + 0.7, "secondary", "shield louvre"))
    return p


def sp_exit_vent():
    p = [mbox(4.82, 5.2, 0.5, 2.25, SZ0, -0.1, "primary", "wing exit vent box"),
         mbox(4.82, 4.92, 0.8, 2.2, 0.9, 2.9, "secondary", "door number panel")]
    for z in (-1.6, -1.1, -0.6):
        p.append(mbox(5.2, 5.27, 0.7, 2.05, z, z + 0.25, "detail", "vent slat"))
    return p


def sp_blade_skirt():
    return [
        mbox(4.82, 5.5, SILL, 0.62, SZ0, SZ1, "detail", "deep side skirt blade"),
        mwedge(5.3, 5.5, 0.62, 1.6, 4.2, SZ1, "-z", "-y", "detail", "skirt kick-up"),
        mbox(4.82, 4.9, 0.9, 1.3, -1.6, 0.4, "secondary", "wing badge strip"),
    ]


def sp_cove():
    return [
        mbox(4.82, 4.94, 1.0, 2.1, -1.2, 5.0, "secondary", "two-tone side cove"),
        mwedge(4.82, 4.94, 1.0, 2.1, 5.0, SZ1, "+z", "-y", "secondary", "cove tail"),
        mbox(4.94, 5.04, 0.92, 1.02, -1.3, SZ1, "detail", "cove spear"),
        mbox(4.94, 5.1, 1.2, 1.9, 4.2, 4.4, "detail", "cove vent"),
        mbox(4.94, 5.1, 1.2, 1.9, 3.7, 3.9, "detail", "cove vent"),
    ]


def sp_rocker_tube():
    p = [cylz(5.3, 0.62, -1.7, 5.9, 0.5, "secondary", "brushed rocker tube", mirror=True)]
    for z in (-1.0, 1.9, 4.8):
        p.append(mbox(4.82, 5.2, 0.5, 0.75, z, z + 0.3, "detail", "standoff"))
    return p


# ----------------------------------------------------------------------------- FrontBumper
def fb_chrome_blade():
    return [
        box(-4.6, 4.6, 0.0, SILL, -12.5, -9.8, "detail", "mount pan on the bumper pad"),
        box(-5.4, 5.4, 0.45, 1.15, -13.0, -12.5, "secondary", "full-width bumper blade"),
        mbox(1.6, 2.0, 0.32, 1.45, -13.2, -12.5, "secondary", "over-rider"),
        mbox(3.2, 3.6, 0.0, 0.45, -12.9, -12.5, "detail", "bumper iron"),
    ]


def fb_chin_scoop():
    return [
        box(-2.6, 2.6, -0.7, SILL, -12.3, -10.6, "primary", "chin scoop"),
        box(-2.3, 2.3, -0.55, 0.15, -12.42, -12.3, "detail", "scoop mouth"),
        mwedge(2.6, 3.6, -0.7, SILL, -12.3, -10.6, "+x", "+y", "primary", "scoop cheek"),
        wedge(-2.6, 2.6, -0.7, SILL, -10.6, -9.8, "+z", "+y", "primary", "scoop tail"),
    ]


def fb_air_dam():
    return [
        box(-5.3, 5.3, -1.1, SILL, -12.4, -12.0, "primary", "full-width air dam"),
        mbox(4.9, 5.3, -1.1, SILL, -12.0, -9.8, "primary", "dam return"),
        mbox(3.1, 4.5, -0.7, 0.0, -12.47, -12.4, "detail", "brake duct"),
        box(-2.4, 2.4, -0.8, -0.1, -12.47, -12.4, "detail", "cooler slot"),
        box(-4.9, 4.9, 0.1, SILL, -12.0, -9.8, "detail", "mount pan"),
    ]


def fb_splitter():
    return [
        box(-5.5, 5.5, 0.08, SILL, -13.3, -9.8, "detail", "flat splitter blade"),
        mbox(5.3, 5.5, SILL, 0.95, -13.3, -12.5, "detail", "end fence"),
        tube((3.2, SILL, -13.1), (3.2, 1.4, -12.5), 0.14, "secondary", "splitter stay", mirror=True),
        mbox(3.6, 5.2, SILL, 0.42, -13.2, -12.5, "secondary", "canard"),
    ]


def fb_bumperettes():
    return [
        box(-4.4, 4.4, 0.1, SILL, -12.5, -10.2, "detail", "mount pan"),
        mbox(2.4, 5.1, 0.5, 1.1, -12.95, -12.5, "secondary", "split bumperette"),
        mbox(3.2, 4.0, 0.1, 0.5, -12.9, -12.5, "detail", "bumper iron"),
        mbox(1.1, 1.9, 0.45, 1.05, -12.75, -12.5, "neon", "fog lamp"),
    ]


def fb_roll_pan():
    return [
        wedge(-5.1, 5.1, -0.55, SILL, -12.3, -10.0, "+z", "+y", "primary", "smooth rolled pan"),
        box(-3.0, 3.0, -0.3, -0.1, -12.38, -12.3, "neon", "pan light strip"),
    ]


# ----------------------------------------------------------------------------- RearBumper
ZV = Z_BULK + 0.2      # valances start just behind the rear arch


def rb_chrome_quarters():
    return [
        box(-5.0, 5.0, 0.0, SILL, ZV, 12.4, "detail", "valance pan on the bumper pad"),
        mbox(3.4, 5.4, 0.5, 1.2, 12.3, 12.8, "secondary", "quarter bumper"),
        mbox(4.0, 4.4, 0.0, 0.5, 12.3, 12.7, "detail", "bumper iron"),
    ]


def rb_skid_bars():
    return [
        box(-4.6, 4.6, 0.05, SILL, ZV, 12.0, "detail", "valance pan"),
        tube((1.6, 0.1, 10.6), (1.6, -0.95, 13.3), 0.3, "secondary", "skid bar", mirror=True),
        mbox(1.25, 1.95, -1.2, -1.0, 12.8, 13.6, "detail", "skid shoe"),
        box(-1.6, 1.6, -0.55, -0.35, 11.7, 12.0, "secondary", "cross brace"),
        mbox(3.6, 5.0, 0.4, 1.4, 12.3, 13.1, "secondary", "drag chute pack"),
    ]


def rb_jack_valance():
    return [
        box(-5.2, 5.2, -0.5, SILL, 11.6, 12.2, "primary", "flat valance"),
        mbox(4.8, 5.2, -0.5, SILL, ZV, 11.6, "primary", "valance return"),
        cylz(2.0, -0.1, 12.2, 12.9, 0.5, "detail", "quick-jack tube", mirror=True),
        box(-4.8, 4.8, 0.1, SILL, ZV, 11.6, "detail", "mount pan"),
    ]


def rb_diffuser():
    p = [box(-5.2, 5.2, 0.1, SILL, ZV, 13.2, "detail", "diffuser plate"),
         box(-0.08, 0.08, -1.0, 0.1, 10.8, 13.3, "detail", "centre strake")]
    for x in (1.5, 3.0, 4.5):
        p.append(mwedge(x - 0.08, x + 0.08, -1.0, 0.1, 10.6, 13.3, "-z", "+y", "detail", "diffuser strake"))
    p.append(mbox(3.6, 5.2, 0.4, 0.7, 12.3, 12.6, "neon", "reflector strip"))
    return p


def rb_rolled_valance():
    return [
        wedge(-5.0, 5.0, -0.5, SILL, ZV, 12.2, "-z", "+y", "primary", "rolled valance"),
        mbox(3.7, 4.5, 0.4, 0.9, 12.3, 12.45, "neon", "reversing lamp"),
        mbox(3.9, 4.3, 0.32, 0.42, 12.22, 12.4, "detail", "lamp bracket"),
    ]


def rb_tucked_pan():
    """Restomod: a smooth body-colour pan tucked under the tail, with one small centre outlet."""
    return [
        box(-5.2, 5.2, -0.4, SILL, ZV, 12.4, "primary", "tucked roll pan, body colour"),
        wedge(-5.2, 5.2, -0.4, SILL, 12.4, 12.9, "+z", "+y", "primary", "pan rolls up under the tail"),
        mbox(3.4, 5.2, SILL, 1.5, 12.25, 12.75, "primary", "corner tuck under the tail overhang"),
        box(-1.1, 1.1, -0.75, -0.4, 11.4, 12.6, "detail", "small centre outlet"),
        box(-0.85, 0.85, -0.68, -0.47, 12.6, 12.66, "neon", "outlet lamp"),
    ]


# ----------------------------------------------------------------------------- RearSpoiler
ZS = Z_BULK + 0.2      # spoiler feet start just behind the bulkhead line


def rs_winged_warrior():
    return [
        mbox(3.75, 4.05, BELT, 6.4, ZS, 11.4, "primary", "tall upright, wholly on the haunch pad"),
        mwedge(3.75, 4.05, 4.3, 6.4, 11.4, 12.4, "+z", "+y", "primary", "raked brace under the blade"),
        box(-4.4, 4.4, 6.4, 6.66, ZS, 12.4, "secondary", "high blade"),
    ]


def rs_drag_wing():
    return [
        mbox(3.7, 4.0, BELT, 5.3, ZS, 11.0, "detail", "strut on the haunch pad"),
        tube((3.85, 4.4, 11.0), (3.85, 5.3, 12.6), 0.2, "detail", "stay", mirror=True),
        box(-4.5, 4.5, 5.3, 5.55, ZS - 0.1, 13.2, "primary", "long-chord drag wing"),
        box(-4.5, 4.5, 5.55, 5.85, 13.0, 13.2, "secondary", "wicker"),
        mbox(4.5, 4.7, 4.6, 6.3, ZS - 0.15, 13.5, "secondary", "big end plate"),
    ]


def rs_ducktail():
    """Trans-Am: a ramp across the tail on two full-length buttresses, so its ends are closed.
    The open slot under the middle shows the tail engine."""
    return [
        mbox(3.35, 4.5, BELT, 4.3, ZS - 0.15, 11.4, "primary", "buttress fills the haunch pad"),
        mwedge(3.35, 4.5, BELT, 4.3, 11.4, 12.5, "+z", "+y", "primary", "buttress rakes back under the ramp"),
        wedge(-4.5, 4.5, 4.3, 5.2, ZS - 0.15, 12.5, "-z", "-y", "primary", "ducktail ramp, 9.0 wide"),
        box(-4.5, 4.5, 5.2, 5.34, 12.2, 12.5, "secondary", "ducktail lip"),
    ]


def rs_blade_wing():
    return [
        mbox(3.6, 4.2, BELT, 4.3, ZS, 11.2, "detail", "foot on the haunch pad"),
        box(-5.3, 5.3, 4.3, 4.52, 11.2, 13.0, "detail", "low wide blade"),
        mbox(3.6, 4.2, 4.3, 4.4, ZS, 11.3, "detail", "swan neck"),
        mbox(5.3, 5.46, 4.3, 5.0, 11.0, 13.2, "secondary", "end plate"),
    ]


def rs_deck_rack():
    p = [
        mbox(3.6, 3.9, BELT, 4.36, ZS - 0.1, ZS + 0.2, "secondary", "rack post on the haunch pad"),
        mbox(3.6, 3.9, BELT, 4.36, 11.0, 11.3, "secondary", "rack post on the haunch pad"),
        cylz(3.75, 4.46, ZS - 0.15, 12.3, 0.26, "secondary", "rack side rail", mirror=True),
    ]
    for z in (10.45, 11.05, 11.65, 12.2):
        p.append(cylx(4.46, z, -3.75, 3.75, 0.22, "secondary", "rack slat"))
    return p


def rs_fin_bar():
    """Restomod: a low swept fin on each haunch, joined by a thin light bar across the tail."""
    return [
        mbox(3.6, 4.2, BELT, 4.3, ZS, 11.4, "primary", "fin root, wholly on the haunch pad"),
        mwedge(3.6, 4.2, 4.3, 5.3, ZS, 12.2, "-z", "-y", "primary", "low fin, swept back past its root"),
        box(-3.6, 3.6, 4.35, 4.62, 11.75, 12.2, "detail", "thin bar across the tail"),
        box(-3.4, 3.4, 4.4, 4.57, 12.2, 12.27, "neon", "light bar"),
    ]


# ----------------------------------------------------------------------------- catalogue
def mod(name, culture, parts):
    return {"name": name, "culture": culture, "parts": parts}


C = {"classic": "Classic Muscle", "prostreet": "Pro Street", "transam": "Trans-Am racer",
     "modern": "Modern Muscle", "pony": "Pony", "restomod": "Restomod"}

# Every slot lists its modules in kit order: classic, prostreet, transam, modern, pony, restomod.
MODULES = {
    "Engine1": {
        "shaker_turbine": mod("Shaker Turbine", C["classic"], shift(e1_shaker(), E1_SHIFT)),
        "blower_stack": mod("Blower Stack", C["prostreet"], shift(e1_blower(), E1_SHIFT)),
        "crossram_twins": mod("Cross-Ram Twins", C["transam"], shift(e1_crossram(), E1_SHIFT)),
        "cowl_slot": mod("Cowl Slot Turbine", C["modern"], shift(e1_cowlslot(), E1_SHIFT + 0.9)),   # hard against the cowl
        "quad_pack": mod("Quad Pack", C["pony"], shift(e1_quadrow(), E1_SHIFT)),
        "tunnel_ram": mod("Tunnel Ram", C["restomod"], shift(e1_tunnelram(), E1_SHIFT)),
    },
    "Engine2": {
        "twin_barrel": mod("Twin Barrel", C["classic"], e2_twin()),
        "mono_turbine": mod("Mono Turbine", C["prostreet"], e2_mono()),
        "over_under": mod("Over-Under", C["transam"], e2_overunder()),
        "slot_burner": mod("Slot Burner", C["modern"], e2_slot()),
        "quad_corners": mod("Quad Corners", C["pony"], e2_quad()),
        "inline_four": mod("Inline Four", C["restomod"], e2_inline()),
    },
    "Stabilisers": {
        "corner_turbines": mod("Corner Turbines", C["classic"], st_corner_turbines()),
        "big_n_little": mod("Big 'n' Little", C["prostreet"], st_big_little()),
        "outriggers": mod("Outriggers", C["transam"], st_outriggers()),
        "vector_cans": mod("Vector Cans", C["modern"], st_vector_cans()),
        "glide_paddles": mod("Glide Paddles", C["pony"], st_glide_paddles()),
        "skirted_triples": mod("Skirted Triples", C["restomod"], st_skirted_triples()),
    },
    "Boost": {
        "side_pipes": mod("Side Pipes", C["classic"], bo_side_pipes()),
        "bazookas": mod("Bazookas", C["prostreet"], bo_bazookas()),
        "megaphones": mod("Megaphones", C["transam"], bo_megaphones()),
        "sill_slots": mod("Sill Slots", C["modern"], bo_sill_slots()),
        "lake_trios": mod("Lake Trios", C["pony"], bo_lake_trios()),
        "underslung_twins": mod("Underslung Twins", C["restomod"], bo_underslung()),
    },
    "FrontBody": {
        "shark_nose": mod("Shark Nose", C["classic"], front_shark()),
        "tilt_nose": mod("Tilt Nose", C["prostreet"], front_tilt()),
        "raked_nose": mod("Raked Nose", C["transam"], front_airdam()),
        "bluff_nose": mod("Bluff Nose", C["modern"], front_bluff()),
        "pony_beak": mod("Pony Beak", C["pony"], front_beak()),
        "stacked_blades": mod("Stacked Blades", C["restomod"], front_blades()),
    },
    "RearBody": {
        "coke_hips": mod("Coke Hips", C["classic"], rear_coke()),
        "tubbed_tail": mod("Tubbed Tail", C["prostreet"], rear_tubbed()),
        "flared_kamm": mod("Flared Kamm", C["transam"], rear_kamm()),
        "high_deck": mod("High Deck", C["modern"], rear_highdeck()),
        "short_deck": mod("Slant Deck", C["pony"], rear_short()),
        "square_tail": mod("Square Tail", C["restomod"], rear_square()),
    },
    "SidePods": {
        "rocker_scoop": mod("Rocker and Scoop", C["classic"], sp_rocker_scoop()),
        "heat_shield": mod("Heat Shield", C["prostreet"], sp_heat_shield()),
        "exit_vent": mod("Exit Vent", C["transam"], sp_exit_vent()),
        "blade_skirt": mod("Blade Skirt", C["modern"], sp_blade_skirt()),
        "cove": mod("Side Cove", C["pony"], sp_cove()),
        "rocker_tube": mod("Rocker Tube", C["restomod"], sp_rocker_tube()),
    },
    "FrontBumper": {
        "chrome_blade": mod("Chrome Blade", C["classic"], fb_chrome_blade()),
        "chin_scoop": mod("Chin Scoop", C["prostreet"], fb_chin_scoop()),
        "air_dam": mod("Air Dam", C["transam"], fb_air_dam()),
        "splitter": mod("Splitter", C["modern"], fb_splitter()),
        "bumperettes": mod("Bumperettes", C["pony"], fb_bumperettes()),
        "roll_pan": mod("Roll Pan", C["restomod"], fb_roll_pan()),
    },
    "RearBumper": {
        "chrome_quarters": mod("Chrome Quarters", C["classic"], rb_chrome_quarters()),
        "skid_bars": mod("Skid Bars and Chutes", C["prostreet"], rb_skid_bars()),
        "jack_valance": mod("Jack Valance", C["transam"], rb_jack_valance()),
        "diffuser": mod("Diffuser", C["modern"], rb_diffuser()),
        "rolled_valance": mod("Rolled Valance", C["pony"], rb_rolled_valance()),
        "tucked_pan": mod("Tucked Pan", C["restomod"], rb_tucked_pan()),
    },
    "RearSpoiler": {
        "winged_warrior": mod("Winged Warrior", C["classic"], rs_winged_warrior()),
        "drag_wing": mod("Drag Wing", C["prostreet"], rs_drag_wing()),
        "ducktail": mod("Ducktail", C["transam"], rs_ducktail()),
        "blade_wing": mod("Blade Wing", C["modern"], rs_blade_wing()),
        "deck_rack": mod("Deck Rack", C["pony"], rs_deck_rack()),
        "fin_bar": mod("Fin Bar", C["restomod"], rs_fin_bar()),
    },
}

SLOT_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost", "FrontBody", "RearBody", "SidePods",
              "FrontBumper", "RearBumper", "RearSpoiler"]
KIT_ORDER = ["classic", "prostreet", "transam", "modern", "pony", "restomod"]
KIT_NAMES = {"classic": "Classic", "prostreet": "Pro Street", "transam": "Trans-Am", "modern": "Modern",
             "pony": "Pony", "restomod": "Restomod"}


def kit(idx):
    return {s: list(MODULES[s].keys())[idx] for s in SLOT_ORDER}


KITS = {k: {"name": KIT_NAMES[k], "culture": C[k], "modules": kit(i)} for i, k in enumerate(KIT_ORDER)}

PAINT = {
    "fastback": {"primary": "#1f5a3d", "secondary": "#ece4c8", "neon": "#ffb347"},
    "hardtop": {"primary": "#6a2c91", "secondary": "#f1f1f1", "neon": "#ff5a4d"},
    "notch": {"primary": "#eeeeee", "secondary": "#1d4fa8", "neon": "#ffd34d"},
    "modern": {"primary": "#d6451b", "secondary": "#18191d", "neon": "#eaf6ff"},
    "ragtop": {"primary": "#f0c020", "secondary": "#f4efe2", "neon": "#ff6a3d"},
    "ute": {"primary": "#46565f", "secondary": "#e08a1e", "neon": "#ffe9a8"},
}
NAMES = {c: COCKPITS[c]["name"] for c in COCKPITS}
SWAPS = {"fastback": "prostreet", "hardtop": "modern", "notch": "classic", "modern": "transam",
         "ragtop": "restomod", "ute": "pony"}

BUILDS = []
for cid in COCKPITS:
    own = COCKPITS[cid]["kit"]
    BUILDS.append({"name": "%s, own %s kit" % (NAMES[cid], KIT_NAMES[own]), "cockpit": cid, "kit": own, "paint": PAINT[cid]})
for cid in COCKPITS:
    BUILDS.append({"name": "%s, %s kit" % (NAMES[cid], KIT_NAMES[SWAPS[cid]]), "cockpit": cid, "kit": SWAPS[cid], "paint": PAINT[cid]})
BUILDS += [
    {"name": "Mixed: street brawler", "cockpit": "fastback", "kit": "classic",
     "modules": {"Engine1": "blower_stack", "Boost": "lake_trios", "RearSpoiler": "ducktail", "Stabilisers": "big_n_little",
                 "FrontBumper": "air_dam"},
     "paint": {"primary": "#15171c", "secondary": "#c9302c", "neon": "#ff4a3d"}},
    {"name": "Mixed: track day", "cockpit": "modern", "kit": "modern",
     "modules": {"Engine1": "crossram_twins", "Engine2": "over_under", "Stabilisers": "outriggers", "RearSpoiler": "drag_wing",
                 "FrontBody": "raked_nose"},
     "paint": {"primary": "#2b6fd6", "secondary": "#f4f4f4", "neon": "#bfe6ff"}},
    {"name": "Mixed: boulevard", "cockpit": "ragtop", "kit": "pony",
     "modules": {"FrontBody": "shark_nose", "Engine1": "shaker_turbine", "Engine2": "slot_burner", "Stabilisers": "skirted_triples",
                 "Boost": "side_pipes", "RearBody": "coke_hips"},
     "paint": {"primary": "#b3122a", "secondary": "#f3ead2", "neon": "#ffd9a0"}},
]

SPEC = {
    "id": "muscle",
    "displayName": "Muscle",
    "tagline": "American muscle and pony cars as one-piece hover jets: long bonnet, short deck, a turbine through the bonnet, "
               "a turbine pack in the tail, lift jets in the arches and side-pipe afterburners.",
    "standard": STANDARD,
    "cockpits": COCKPITS,
    "kits": KITS,
    "modules": MODULES,
    "builds": BUILDS,
}


def table():
    """Pairwise distinctness for every slot and for the cockpits, as the validator scores it: free outline / whole."""
    groups = {s: {m: vbspec.expand_parts(d["parts"]) for m, d in mods.items()} for s, mods in MODULES.items()}
    groups["Cockpit"] = {c: vbspec.expand_parts(d["parts"]) for c, d in COCKPITS.items()}
    for s, mods in groups.items():
        ids = list(mods)
        scores = vbspec.distinct_table(mods)
        print("\n%s (free/whole)" % s)
        for i, a in enumerate(ids):
            row = ["%.2f/%.2f" % scores[(a, b)] if j > i else "         " for j, b in enumerate(ids)]
            print("  %-18s %s" % (a, " ".join(row)))


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(SPEC, f, indent=1)
    errors, warnings, stats = vbspec.validate(SPEC)
    print("wrote %s" % OUT)
    print("self-check: %d error(s), %d warning(s)" % (len(errors), len(warnings)))
    for e in errors:
        print("  ERROR " + e)
    for w in warnings:
        print("  warn  " + w)
    print("distinctness (free): %s" % stats.get("min_distinctness"))
    print("distinctness (whole): %s  worst gap: %s" % (stats.get("min_distinctness_whole"), stats.get("worst_gap")))
    if "--table" in sys.argv:
        table()


if __name__ == "__main__":
    main()
