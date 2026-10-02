"""Generator for the GT frame class blockout spec (round 2, design exploration only).

Run from the repo root:
    py -3 scripts/vehicle_blockouts/gen/gt.py
    py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/gt.json

Root space: +X right, +Y up, forward is -Z, studs.
A GT is a real front-engined sports car with the wheels removed. Two open engine bays
(a bonnet bay and a framed hatch in the tail deck) hold the turbines, each blanked arch holds a lift jet, and the
afterburners sit outboard under the tail lamps, where the exhaust tips were.
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "specs", "gt.json"))

# --------------------------------------------------------------------------------------
# Datums (the frame standard in numbers). Change these and every part follows.
# --------------------------------------------------------------------------------------
FLOOR = 0.0          # underside of every body section; chins and valances hang below it
ARCH_TOP = 2.4       # top of every blanked arch
COVE_TOP = 1.8       # top of the side-exit cove behind each front arch
COVE_Y0 = 0.3
SHOULDER = 2.6       # the shoulder chamfer starts here and ends at the beltline
CHAM = 0.45          # shoulder chamfer width
BELT = 3.0           # beltline, scuttle top and deck pad
HOVER = -2.0
Z_COWL = -2.6        # front seam: cockpit to FrontBody
Z_BACK = 5.0         # rear seam: cockpit to RearBody
Z_EXT = 10.0         # the greenhouse may run back this far over the deck
SEAM_GAP = 0.2       # dark seam plate the cockpit carries at each seam
DOOR_X = 4.7         # cockpit half width
SEAM_X = 4.8         # every body section is this wide where it meets the cockpit
WIDE_X = 5.9         # widest any part may go
ARCH_X = 3.3         # blanked arch wall: the lift-jet pad
GLASS_X = 3.7        # widest greenhouse behind the cabin
BAY1_X, BAY1_Y, BAY1_TOP, BAY1_Z0 = 2.0, 1.0, 3.8, -9.6     # bonnet engine bay
BAY2_X, BAY2_Y, BAY2_Z0, BAY2_Z1 = 1.7, 1.0, 7.0, 12.6      # tail engine hatch: a framed opening in the deck
E2_TOP = 3.5         # the rear engine stands through the deck to here, ahead of the spoiler pads
FA0, FA1 = -9.1, -5.7     # front arch, Z
RA0, RA1 = 5.5, 8.9       # rear arch, Z
FZC, RZC = -7.4, 7.2      # arch centres
COVE0 = -5.2              # the side-exit cove runs from here back to the cowl
TRANSOM = 10.4            # lower tail face: afterburner and valance pad
PAD1 = 10.6               # spoiler pads end here; every deck reaches it
NOSE_MAX, TAIL_MAX = -12.8, 12.4
STAB_Y0 = -1.6
BOOST_Y0 = -0.25     # every afterburner sits on the transom, above this line; the valance owns the space below
CHIN_X = 4.4         # the dark chin shelf under every nose reaches out this far

# --------------------------------------------------------------------------------------
# Part helpers
# --------------------------------------------------------------------------------------
def _r(v):
    return [round(float(a), 3) for a in v]


def part(shape, size, pos, ch="primary", rot=None, mirror=False, note=None):
    d = {"shape": shape, "size": _r(size), "pos": _r(pos), "ch": ch}
    if rot:
        d["rot"] = _r(rot)
    if mirror:
        d["mirror"] = True
    if note:
        d["note"] = note
    return d


def box(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None, rot=None):
    return part("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def bx(xh, y0, y1, z0, z1, ch="primary", note=None):
    """Centred box, half width xh."""
    return box(-xh, xh, y0, y1, z0, z1, ch, False, note)


def _wedge(x0, x1, y0, y1, z0, z1, rot, ch, m, note):
    return part("wedge", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def wf(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None):
    """Slope rising towards the back: thin edge at z0 (front), full height at z1."""
    return _wedge(x0, x1, y0, y1, z0, z1, None, ch, m, note)


def wr(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None):
    """Slope falling towards the back: full height at z0, thin edge at z1."""
    return _wedge(x0, x1, y0, y1, z0, z1, [0, 180, 0], ch, m, note)


def wuf(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None):
    """Flat top, underside rising towards the front: thin edge at z0."""
    return _wedge(x0, x1, y0, y1, z0, z1, [0, 0, 180], ch, m, note)


def wur(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None):
    """Flat top, underside rising towards the back: thin edge at z1."""
    return _wedge(x0, x1, y0, y1, z0, z1, [180, 0, 0], ch, m, note)


def tp(x0, x1, y0, y1, z0, z1, thin="front", straight="inner", ch="primary", m=True, note=None):
    """Plan taper for a +X side piece (mirrored by default). The straight side stays at
    x0 (inner) or x1 (outer); the other side runs to a point at the thin end."""
    rot = {("front", "inner"): [0, 0, -90], ("front", "outer"): [0, 0, 90],
           ("rear", "inner"): [0, 180, 90], ("rear", "outer"): [0, 180, -90]}[(thin, straight)]
    return part("wedge", [y1 - y0, x1 - x0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def ts(x0, x1, y0, y1, z0, z1, high="inner", ch="primary", m=True, note=None):
    """Cross slope for a +X side piece: full height at the inner (x0) or outer (x1) side."""
    rot = [0, -90, 0] if high == "inner" else [0, 90, 0]
    return part("wedge", [z1 - z0, y1 - y0, x1 - x0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def cz(x, y, z0, z1, d, ch="detail", m=False, note=None):
    return part("cyl_z", [d, d, z1 - z0], [x, y, (z0 + z1) / 2], ch, None, m, note)


def cy(x, z, y0, y1, d, ch="detail", m=False, note=None):
    return part("cyl_y", [d, y1 - y0, d], [x, (y0 + y1) / 2, z], ch, None, m, note)


def cx(y, z, x0, x1, d, ch="detail", m=False, note=None):
    return part("cyl_x", [x1 - x0, d, d], [(x0 + x1) / 2, y, z], ch, None, m, note)


def _rot(rot):
    rx, ry, rz = [math.radians(a) for a in rot]
    cxx, sx, cyy, sy, czz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = [[1, 0, 0], [0, cxx, -sx], [0, sx, cxx]]
    Ry = [[cyy, 0, sy], [0, 1, 0], [-sy, 0, cyy]]
    Rz = [[czz, -sz, 0], [sz, czz, 0], [0, 0, 1]]

    def mm(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mm(mm(Ry, Rx), Rz)


def jet(start, rot, d, length, ch="detail", tip=0.3, tip_d=None, m=False, note=None):
    """A nozzle tube that starts at `start` and points along its rotated +Z axis, with a
    glowing thrust plug at the open end. rot [45,0,0] points down and back; rot [0,35,0]
    points back and outwards (+X)."""
    R = _rot(rot)
    ax = [R[0][2], R[1][2], R[2][2]]
    c1 = [start[i] + ax[i] * length / 2 for i in range(3)]
    c2 = [start[i] + ax[i] * (length + tip / 2 - 0.02) for i in range(3)]
    td = tip_d or d * 0.78
    return [part("cyl_z", [d, d, length], c1, ch, rot, m, note),
            part("cyl_z", [td, td, tip], c2, "thrust", rot, m, "jet")]


def on_slope(z_hi, y_hi, z_lo, y_lo, x0, x1, za, zb, ch="glass", lift=0.06, m=False, note=None):
    """A panel lying on a slope that runs from (z_hi, y_hi) to (z_lo, y_lo), covering za..zb."""
    def line(z):
        return y_hi + (y_lo - y_hi) * (z - z_hi) / (z_lo - z_hi) + lift
    ya, yb = line(za), line(zb)
    if ya >= yb:      # falls towards the back
        return wr(x0, x1, yb, ya, za, zb, ch, m, note)
    return wf(x0, x1, ya, yb, za, zb, ch, m, note)



def wing(x0, w, z0, z1, top=BELT, base=ARCH_TOP, cham=CHAM, ch="primary", note="wing"):
    """A wing or haunch slab over an arch, with the house shoulder chamfer on its outer edge."""
    if cham <= 0:
        return [box(x0, w, base, top, z0, z1, ch, True, note)]
    yc = top - (BELT - SHOULDER)
    return [box(x0, w, base, yc, z0, z1, ch, True, note),
            box(x0, w - cham, yc, top, z0, z1, ch, True, note + " top"),
            ts(w - cham, w, yc, top, z0, z1, "inner", ch, True, "shoulder chamfer")]


def flare(w, f, z0, z1, top=2.85, run=1.0, ch="primary", base=ARCH_TOP):
    """An arch flare: a lip over the arch from width w out to f, faired in front and behind."""
    return [box(w, f, base, top, z0, z1, ch, True, "arch flare"),
            tp(w, f, base, top, z0 - run, z0, "front", "inner", ch, note="flare fairing"),
            tp(w, f, base, top, z1, z1 + run, "rear", "inner", ch, note="flare fairing")]


# --------------------------------------------------------------------------------------
# Frame standard: envelopes
# --------------------------------------------------------------------------------------
def env(x0, x1, y0, y1, z0, z1, mirror=False):
    e = {"min": [x0, y0, z0], "max": [x1, y1, z1]}
    if mirror:
        e["mirror"] = True
    return e


STANDARD = {
    "cockpitEnvelope": [
        env(-DOOR_X, DOOR_X, FLOOR, 5.6, Z_COWL, Z_BACK),
        env(-GLASS_X, GLASS_X, BELT, 5.6, Z_BACK, BAY2_Z0),
        env(BAY2_X, GLASS_X, BELT, 5.6, BAY2_Z0, Z_EXT, True),
        env(-BAY2_X, BAY2_X, E2_TOP, 5.6, BAY2_Z0, Z_EXT),
    ],
    "datums": {
        "hoverPlane": HOVER, "sill": FLOOR, "archTop": ARCH_TOP, "shoulder": SHOULDER, "beltline": BELT,
        "deckPad": BELT, "cowlZ": Z_COWL, "backZ": Z_BACK, "greenhouseEndZ": Z_EXT, "doorX": DOOR_X,
        "seamX": SEAM_X, "archWallX": ARCH_X, "frontArchZ": [FA0, FA1], "rearArchZ": [RA0, RA1],
        "bonnetBay": {"halfWidth": BAY1_X, "floorY": BAY1_Y, "z": [BAY1_Z0, Z_COWL]},
        "tailBay": {"halfWidth": BAY2_X, "floorY": BAY2_Y, "topY": E2_TOP, "z": [BAY2_Z0, Z_EXT], "nozzleEndZ": BAY2_Z1},
        "sideCove": {"y": [COVE_Y0, COVE_TOP], "z": [COVE0, Z_COWL]},
        "transomZ": TRANSOM, "spoilerPad": {"x": [BAY2_X, GLASS_X], "y": BELT, "z": [Z_EXT, PAD1]},
        "chinPad": {"halfWidth": 2.0, "y": FLOOR, "z": [-10.8, BAY1_Z0], "shelfHalfWidth": CHIN_X},
        "boostFloorY": BOOST_Y0,
    },
    "slots": {
        "FrontBody": {
            "label": "Nose and Bonnet",
            "envelope": [
                env(-WIDE_X, WIDE_X, FLOOR, 3.8, NOSE_MAX, BAY1_Z0),
                env(BAY1_X, WIDE_X, ARCH_TOP, 3.8, BAY1_Z0, Z_COWL, True),
                env(-BAY1_X, BAY1_X, FLOOR, BAY1_Y, BAY1_Z0, Z_COWL),
                env(BAY1_X, ARCH_X, FLOOR, ARCH_TOP, BAY1_Z0, Z_COWL, True),
                env(ARCH_X, WIDE_X, FLOOR, ARCH_TOP, BAY1_Z0, FA0, True),
                env(ARCH_X, WIDE_X, FLOOR, ARCH_TOP, FA1, COVE0, True),
                env(ARCH_X, WIDE_X, COVE_TOP, ARCH_TOP, COVE0, Z_COWL, True),
                env(ARCH_X, WIDE_X, FLOOR, COVE_Y0, COVE0, Z_COWL, True),
            ],
            "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -6.5]},
        "RearBody": {
            "label": "Tail",
            "envelope": [
                env(BAY2_X, WIDE_X, ARCH_TOP, BELT, Z_BACK, TAIL_MAX, True),
                env(GLASS_X, WIDE_X, BELT, 3.7, Z_BACK, TAIL_MAX, True),
                env(-BAY2_X, BAY2_X, FLOOR, BAY2_Y, Z_BACK, TRANSOM),
                env(-BAY2_X, BAY2_X, BAY2_Y, BELT, Z_BACK, BAY2_Z0),
                env(BAY2_X, ARCH_X, FLOOR, ARCH_TOP, Z_BACK, TRANSOM, True),
                env(ARCH_X, WIDE_X, FLOOR, ARCH_TOP, Z_BACK, RA0, True),
                env(ARCH_X, WIDE_X, FLOOR, ARCH_TOP, RA1, TRANSOM, True),
                env(BAY2_X, WIDE_X, 1.0, ARCH_TOP, TRANSOM, TAIL_MAX, True),
            ],
            "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 0, 6.5]},
        "Engine1": {
            "label": "Front Engine",
            "envelope": [
                env(-BAY1_X, BAY1_X, BAY1_Y, BAY1_TOP, BAY1_Z0, Z_COWL),
                env(ARCH_X, WIDE_X, COVE_Y0, COVE_TOP, COVE0, Z_COWL, True),
            ],
            "anchor": {"to": "FrontBody", "face": "-y"}, "explode": [0, 6.5, -6.5]},
        "Engine2": {
            "label": "Rear Engine",
            "envelope": [
                env(-BAY2_X, BAY2_X, BAY2_Y, E2_TOP, BAY2_Z0, Z_EXT),
                env(-BAY2_X, BAY2_X, BAY2_Y, BELT, Z_EXT, BAY2_Z1),
            ],
            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 6.5, 7.5]},
        "Stabilisers": {
            "label": "Lift Jets",
            "envelope": [
                env(ARCH_X, WIDE_X, STAB_Y0, ARCH_TOP, FA0, FA1, True),
                env(ARCH_X, WIDE_X, STAB_Y0, ARCH_TOP, RA0, RA1, True),
            ],
            "anchor": [{"to": "FrontBody", "face": "-x"}, {"to": "RearBody", "face": "-x"}],
            "explode": [5.5, -3.5, 0]},
        "Boost": {
            "label": "Afterburner",
            "envelope": env(-3.4, 3.4, BOOST_Y0, 1.0, TRANSOM, 13.6),
            "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, -1.5, 13]},
        "SidePods": {
            "label": "Sills",
            "envelope": env(DOOR_X, WIDE_X, -1.2, 1.5, Z_COWL, Z_BACK, True),
            "anchor": {"to": "cockpit", "face": "-x"}, "explode": [5.5, -1, 0]},
        "FrontBumper": {
            "label": "Chin",
            "envelope": env(-WIDE_X, WIDE_X, -1.3, FLOOR, -13.6, -9.3),
            "anchor": {"to": "FrontBody", "face": "+y"}, "explode": [0, -3.5, -9.5]},
        "RearBumper": {
            "label": "Rear Valance",
            "envelope": [
                env(-WIDE_X, WIDE_X, -1.5, FLOOR, RA1, TRANSOM),
                env(-3.4, 3.4, -1.5, BOOST_Y0, TRANSOM, 13.6),
                env(3.4, WIDE_X, -1.5, 1.0, TRANSOM, 12.9, True),
            ],
            "anchor": {"to": "RearBody", "face": "+y"}, "explode": [0, -5, 8]},
        "RearSpoiler": {
            "label": "Spoiler",
            "envelope": [
                env(-GLASS_X, GLASS_X, BELT, 3.7, Z_EXT, 12.9),
                env(-WIDE_X, WIDE_X, 3.7, 6.9, Z_EXT, 12.9),
            ],
            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 7, 12]},
    },
}


# --------------------------------------------------------------------------------------
# Cockpits: one shared tub (chassis and pads), six different cabins
# --------------------------------------------------------------------------------------
DRIVER_X = -1.8
ZC0, ZC1 = Z_COWL + SEAM_GAP, Z_BACK - SEAM_GAP     # where the cockpit's painted skin starts and stops


def tub():
    """The shared chassis. Identical in every cockpit, so every pad is in the same place."""
    p = [
        bx(4.5, 0.0, 0.5, ZC0, ZC1, "detail", "undertray"),
        bx(4.6, 0.1, 2.9, Z_COWL, ZC0, "detail", "front seam plate: dark linkage in the shadow gap"),
        bx(4.6, 0.1, 2.9, ZC1, Z_BACK, "detail", "rear seam plate"),
        box(3.7, DOOR_X, 0.3, SHOULDER, ZC0, ZC1, "primary", True, "door skin; sill pad at X 4.7"),
        box(3.7, DOOR_X - CHAM, SHOULDER, BELT, ZC0, ZC1, "primary", True, "door top"),
        ts(DOOR_X - CHAM, DOOR_X, SHOULDER, BELT, ZC0, ZC1, "inner", "primary", True, "shoulder chamfer"),
        bx(3.7, 0.5, BELT, ZC0, -1.2, "primary", "scuttle, flat at the beltline"),
        bx(3.7, 0.5, BELT, 3.4, ZC1, "primary", "rear bulkhead and parcel deck"),
        bx(3.7, 0.5, 0.8, -1.2, 3.4, "detail", "cabin floor"),
        bx(3.5, 2.0, 2.85, -1.2, -0.7, "detail", "dashboard"),
        box(4.69, 4.75, 0.5, SHOULDER, -1.95, -1.85, "detail", True, "door shut line"),
        box(4.69, 4.75, 0.5, SHOULDER, 2.75, 2.85, "detail", True, "door shut line"),
    ]
    for sx in (-1.8, 1.8):
        p.append(box(sx - 0.95, sx + 0.95, 0.8, 3.25, 2.2, 2.75, "detail", note="seat back"))
        p.append(box(sx - 0.9, sx + 0.9, 0.8, 1.2, 0.7, 2.2, "detail", note="seat cushion"))
    p += [
        box(DRIVER_X - 0.75, DRIVER_X + 0.75, 1.2, 3.0, 1.2, 2.1, "driver", note="seated avatar: torso"),
        box(DRIVER_X - 0.7, DRIVER_X + 0.7, 1.2, 1.8, -0.4, 1.2, "driver", note="legs"),
        part("ball", [1.1, 1.1, 1.1], [DRIVER_X, 3.55, 1.65], "driver", note="head, top at Y 4.1"),
        box(DRIVER_X - 0.55, DRIVER_X + 0.55, 2.5, 2.8, -0.45, -0.25, "detail", note="yoke"),
        box(DRIVER_X - 0.15, DRIVER_X + 0.15, 2.5, 2.8, -0.7, -0.45, "detail", note="yoke column, from the dashboard"),
    ]
    return p


def mirrors(z=-1.3, y=BELT, ch="primary", x0=3.9):
    """Door mirrors. They sit on the door top or the shoulder: y and x0 must land them on a body part."""
    return [box(x0, 4.65, y, y + 0.4, z, z + 0.45, ch, True, "door mirror")]


def cockpit_longnose():
    """60s long-bonnet GT: a small, tall, upright box cabin set far back behind a long scuttle. Thin pillars, tall glass, a bright roof lip over a deep notch, then a short fastback."""
    p = tub() + mirrors(-0.7, 3.25, "secondary", x0=3.4)
    p += [
        bx(3.7, BELT, 3.25, ZC0, 0.0, "primary", "long scuttle: the bonnet line runs on into the cabin"),
        box(3.0, 3.7, 2.8, BELT, 0.0, 3.4, "primary", True, "cabin shoulder"),
        wf(-2.75, 2.75, 3.25, 4.9, 0.0, 1.0, "glass", note="tall upright windscreen, set far back"),
        wf(2.75, 2.97, 3.25, 4.9, 0.0, 1.0, "primary", True, "thin A-pillar"),
        bx(2.95, 3.0, 4.9, 1.0, 3.5, "glass", "tall side glass"),
        box(2.94, 3.0, 3.0, 4.9, 2.25, 2.45, "primary", True, "thin B-pillar"),
        bx(2.7, 4.9, 5.2, 1.0, 4.0, "primary", "short flat roof, tall and narrow"),
        ts(2.7, 3.1, 4.9, 5.2, 1.0, 4.0, "inner", "primary", True, "roof edge"),
        bx(3.1, 3.0, 4.9, 3.5, 4.0, "primary", "thin rear pillar"),
        bx(2.9, 5.02, 5.2, 4.0, 4.35, "secondary", "bright roof lip over the notch"),
        wr(-3.1, 3.1, 3.0, 4.25, 4.0, BAY2_Z0, "primary", note="short fastback below the notch"),
        on_slope(4.0, 4.25, BAY2_Z0, 3.0, -2.3, 2.3, 4.25, 5.8, "glass", note="rear window"),
        box(3.09, 3.15, 3.3, 4.6, 3.6, 3.7, "detail", True, "quarter gill"),
        box(3.09, 3.15, 3.3, 4.6, 3.8, 3.9, "detail", True, "quarter gill"),
        bx(3.05, 3.0, 3.1, 6.8, BAY2_Z0, "secondary", "bright tail trim"),
    ]
    return p


def cockpit_teardrop():
    """Rear-engined coupe: screen right at the cowl, a tall round dome, then one curve down. The tail is open between two buttresses so the rear engine shows."""
    p = tub() + mirrors(-1.6)
    zs, ys, ze = 3.2, 5.1, 9.8                       # the tail curve runs from (zs, ys) down to the deck at ze
    y7 = ys - (BAY2_Z0 - zs) * (ys - BELT) / (ze - zs)   # its height where the engine hatch starts
    p += [
        wf(-3.3, 3.3, 3.0, 5.0, -2.4, 0.0, "glass", note="fast windscreen from the cowl"),
        wf(3.3, 3.7, 3.0, 5.0, -2.4, 0.0, "primary", True, "A-pillar"),
        bx(3.6, 3.0, 4.7, 0.0, 1.6, "glass", "door glass"),
        bx(3.7, 3.0, 4.7, 1.6, zs, "primary", "cabin shell"),
        box(3.7, 3.76, 3.15, 4.5, 1.75, 2.4, "glass", True, "quarter window"),
        wr(3.7, 3.76, 3.15, 4.5, 2.4, 3.15, "glass", True, "rounded quarter window tail"),
        bx(3.2, 4.7, ys, 0.0, zs, "primary", "roof"),
        ts(3.2, 3.7, 4.7, ys, 0.0, zs, "inner", "primary", True, "rounded roof edge"),
        wf(-2.3, 2.3, ys, 5.6, 0.1, 1.2, "primary", note="dome rising"),
        bx(2.3, ys, 5.6, 1.2, 2.0, "primary", "dome crown"),
        wr(-2.3, 2.3, ys, 5.6, 2.0, zs, "primary", note="dome falling"),
        ts(2.3, 3.2, ys, 5.6, 1.2, 2.0, "inner", "primary", True, "dome side"),
        bx(3.0, BELT, y7, zs, BAY2_Z0 - 0.06, "primary", "tail base"),
        wr(-3.0, 3.0, y7, ys, zs, BAY2_Z0, "primary", note="tail curve, cut off square at the engine hatch"),
        bx(1.5, BELT + 0.1, y7 - 0.1, BAY2_Z0 - 0.06, BAY2_Z0, "detail", "engine hatch grille"),
        wr(BAY2_X, 3.0, BELT, y7, BAY2_Z0, ze, "primary", True, "buttress carrying the curve on beside the engine"),
        tp(3.0, 3.7, BELT, 3.9, zs, 6.6, "rear", "inner", note="shoulder fairing"),
        on_slope(zs, ys, ze, BELT, -2.0, 2.0, 3.6, 6.4, "glass", note="rear window"),
    ]
    return p


def cockpit_bruiser():
    """Modern muscular GT: the lowest roof, chopped to 4.3 and as wide as the shoulders. Slit glass, a wrap-round screen, double bubble, and two flying buttresses that carry the roof line back beside the engine."""
    p = tub() + mirrors(-0.7, 3.5, "detail")
    p += [
        box(3.3, 4.6, BELT, 3.5, -0.8, 3.6, "primary", True, "high wide shoulder"),
        wf(3.3, 4.6, BELT, 3.5, -2.4, -0.8, "primary", True, "shoulder rising from the cowl"),
        wr(3.3, 4.6, BELT, 3.5, 3.6, 4.8, "primary", True, "shoulder falling to the back seam"),
        wf(-3.3, 3.3, 3.0, 3.95, -2.3, 0.9, "glass", note="long raked windscreen"),
        wf(3.3, 4.1, 3.5, 3.95, -0.62, 0.9, "glass", True, "screen wraps round the corner"),
        bx(4.1, 3.5, 3.95, 0.9, 3.4, "glass", "slit side glass"),
        bx(3.9, 3.95, 4.3, 0.9, 3.8, "primary", "chopped roof, out to the shoulders"),
        ts(3.9, 4.3, 3.95, 4.3, 0.9, 3.8, "inner", "primary", True, "roof edge"),
        box(0.5, 2.9, 4.3, 4.55, 1.3, 3.2, "primary", True, "double bubble"),
        wf(0.5, 2.9, 4.3, 4.55, 0.9, 1.3, "primary", True, "bubble nose"),
        wr(0.5, 2.9, 4.3, 4.55, 3.2, 3.8, "primary", True, "bubble tail"),
        bx(4.1, 3.5, 3.95, 3.4, 3.8, "primary", "thick C-pillar"),
        tp(GLASS_X, 4.3, 3.5, 4.3, 3.8, 4.9, "rear", "inner", note="C-pillar closing in to the buttress"),
        box(BAY2_X, GLASS_X, BELT, 4.3, 3.8, 6.6, "primary", True, "flying buttress at roof height"),
        wr(BAY2_X, GLASS_X, BELT, 4.3, 6.6, Z_EXT, "primary", True, "buttress falling to the deck beside the engine hatch"),
        wr(-BAY2_X, BAY2_X, 3.0, 4.3, 3.8, 6.4, "glass", note="sunk rear window between the buttresses"),
    ]
    return p


def cockpit_roadster():
    """Open two-seater: low framed screen, driver in the open, twin head fairings."""
    p = tub() + mirrors(-1.5, 3.05, "secondary")
    p += [
        wf(-3.3, 3.3, 3.0, 4.35, -2.2, -0.6, "glass", note="low windscreen"),
        wf(3.3, 3.6, 3.0, 4.35, -2.2, -0.6, "secondary", True, "bright screen frame"),
        bx(3.6, 4.3, 4.45, -0.72, -0.52, "secondary", "screen header rail"),
        wr(0.9, 2.7, 3.0, 4.15, 2.75, BAY2_Z0, "primary", True, "head fairing"),
        box(1.0, 2.6, 3.3, 4.05, 2.69, 2.75, "detail", True, "headrest pad"),
        box(3.7, DOOR_X - CHAM, BELT, 3.1, -1.6, 3.4, "secondary", True, "bright door capping"),
    ]
    return p


def cockpit_brake():
    """Shooting brake: the longest roofline. One flat line to an upright tailgate frame. Roof and tailgate are open over the rear engine."""
    p = tub() + mirrors(-1.4)
    p += [
        wf(-3.2, 3.2, 3.0, 5.1, -2.2, 0.4, "glass", note="windscreen"),
        wf(3.2, 3.6, 3.0, 5.1, -2.2, 0.4, "primary", True, "A-pillar"),
        bx(3.55, 3.0, 5.1, 0.4, 3.2, "glass", "door glass"),
        bx(3.6, 3.0, 5.1, 3.2, 3.6, "primary", "B-pillar"),
        bx(3.55, 3.0, 5.1, 3.6, BAY2_Z0, "glass", "load-bay glass, closed off ahead of the engine"),
        box(3.1, 3.55, 3.0, 5.1, BAY2_Z0, 9.3, "glass", True, "load-bay side glass beside the engine"),
        box(3.0, 3.6, 3.0, 5.1, 9.3, Z_EXT, "primary", True, "D-pillar"),
        bx(3.2, 5.1, 5.4, 0.4, 7.4, "primary", "flat roof, ending over the engine"),
        box(2.0, 3.2, 5.1, 5.4, 7.4, Z_EXT, "primary", True, "roof rail over the open load bay"),
        ts(3.2, 3.6, 5.1, 5.4, 0.4, Z_EXT, "inner", "primary", True, "roof edge"),
        bx(2.0, 5.1, 5.4, 9.5, Z_EXT, "primary", "tailgate header: an open frame, no glass"),
        bx(3.6, 5.4, 5.58, 9.2, Z_EXT, "secondary", "roof-height spoiler blade"),
        box(2.6, 2.9, 5.4, 5.58, 0.9, 8.9, "secondary", True, "bright roof rail"),
    ]
    return p


def cockpit_gullwing():
    """Gullwing: a narrow canopy leaning in hard over deep sills. A raised roof spine carries the door hinges and runs on down the back as a fin."""
    p = tub() + mirrors(-1.3, 3.4, "detail")
    p += [
        box(3.5, DOOR_X - CHAM, BELT, 3.5, -1.6, 4.0, "primary", True, "deep gullwing sill"),
        box(2.8, 3.5, BELT, 3.5, -1.6, 0.3, "primary", True, "canopy shoulder"),
        box(2.8, 3.5, BELT, 3.5, 3.2, 4.0, "primary", True, "canopy shoulder"),
        wf(2.8, DOOR_X - CHAM, BELT, 3.5, -2.4, -1.6, "primary", True, "sill rising from the cowl"),
        wr(2.8, DOOR_X - CHAM, BELT, 3.5, 4.0, 4.8, "primary", True, "sill falling to the back seam"),
        wf(-2.4, 2.4, 3.0, 5.0, -2.0, 0.3, "glass", note="windscreen"),
        wf(2.4, 2.8, 3.0, 5.0, -2.0, 0.3, "primary", True, "A-pillar"),
        bx(2.2, 3.0, 5.0, 0.3, 3.2, "glass", "canopy core"),
        box(2.2, 3.5, 3.0, 3.5, 0.3, 3.2, "glass", True, "door glass foot"),
        ts(2.2, 3.5, 3.5, 5.0, 0.3, 3.2, "inner", "glass", True, "gullwing door glass, leaning in"),
        ts(2.3, 3.75, 3.5, 5.3, 0.3, 0.62, "inner", "primary", True, "door frame, standing proud of the glass"),
        ts(2.3, 3.75, 3.5, 5.3, 2.88, 3.2, "inner", "primary", True, "door frame"),
        bx(0.9, 5.0, 5.5, 0.3, 3.2, "primary", "raised roof spine"),
        box(0.9, 2.3, 5.0, 5.3, 0.3, 3.2, "primary", True, "door top, hinged on the spine"),
        box(0.9, 2.3, 5.3, 5.36, 0.62, 0.74, "detail", True, "door cut"),
        box(0.9, 2.3, 5.3, 5.36, 2.76, 2.88, "detail", True, "door cut"),
        wr(-2.4, 2.4, 3.0, 5.0, 3.2, 5.4, "glass", note="short rear window"),
        wr(2.4, 2.8, 3.0, 5.0, 3.2, 5.4, "primary", True, "C-pillar"),
        wr(-0.45, 0.45, 3.0, 5.5, 3.2, BAY2_Z0, "primary", note="spine fin running down to the deck"),
    ]
    return p


# --------------------------------------------------------------------------------------
# FrontBody: nose, bonnet wings, blanked front arches, the bonnet bay and the side coves
# --------------------------------------------------------------------------------------
def front_core(w=SEAM_X, chin=0.2, w_arch=None):
    """Pads every nose must carry: bay floor, blanked arch walls, cove frame, arch pillars."""
    wa = w_arch or w
    return [
        bx(BAY1_X, FLOOR, BAY1_Y, BAY1_Z0, Z_COWL, "detail", "bonnet bay floor: Engine1 pad at Y 1.0"),
        box(BAY1_X, ARCH_X, FLOOR, ARCH_TOP, BAY1_Z0, Z_COWL, "detail", True, "blanked arch wall and cove back: lift-jet pad at X 3.3"),
        box(ARCH_X, w, FLOOR, COVE_Y0, COVE0, Z_COWL, "primary", True, "sill under the side-exit cove"),
        box(ARCH_X, w, COVE_TOP, ARCH_TOP, COVE0, Z_COWL, "primary", True, "panel over the cove"),
        box(ARCH_X, wa, COVE_Y0, ARCH_TOP, FA1, COVE0, "primary", True, "arch rear pillar"),
        box(ARCH_X, wa, chin, ARCH_TOP, BAY1_Z0, FA0, "primary", True, "arch front pillar"),
    ]


def chin_pad(y1=0.2, xh=CHIN_X):
    """The chin pad, widened into a dark shelf so a wide chin always has bodywork right above it."""
    return [bx(xh, FLOOR, y1, -10.8, BAY1_Z0, "detail", "chin shelf at Y 0: chin pad in the middle, backing for wide chins outboard")]


def nose_torpedo():
    """Classic GT: the longest and lowest nose. The wing line falls from the cowl to a pointed tip. Oval mouth, lamps under glass."""
    w, y9 = SEAM_X, 2.5
    p = front_core(w, 0.6)
    p += [
        box(BAY1_X, w, ARCH_TOP, y9, BAY1_Z0, Z_COWL, "primary", True, "low wing over the arch"),
        wf(BAY1_X, w - CHAM, y9, BELT, BAY1_Z0, Z_COWL, "primary", True, "wing top falling from the cowl"),
        bx(2.2, 0.6, 1.5, -12.2, BAY1_Z0, "primary", "nose core"),
        tp(2.2, w, 0.6, 1.5, -12.2, BAY1_Z0, "front", "inner", note="nose tapers to a blunt point in plan"),
        wf(-2.2, 2.2, 1.5, y9, -12.1, BAY1_Z0, "primary", note="bonnet centre slope"),
        tp(2.2, w, 1.5, 2.1, -11.5, BAY1_Z0, "front", "inner", note="wing shoulder"),
        wf(2.5, 4.3, 2.1, y9, -10.9, BAY1_Z0, "glass", True, "faired headlamp cover"),
        box(2.8, 4.0, 2.12, 2.36, -10.0, -9.8, "neon", True, "headlamp under the cover"),
        bx(1.4, 0.75, 1.35, -12.27, -12.2, "detail", "small oval mouth"),
        bx(1.6, 1.35, 1.47, -12.3, -12.2, "secondary", "bright mouth trim"),
        bx(1.6, 0.63, 0.75, -12.3, -12.2, "secondary", "bright mouth trim"),
        bx(2.2, FLOOR, 0.6, -11.6, BAY1_Z0, "detail", "keel: chin pad at Y 0"),
        tp(2.2, 4.6, FLOOR, 0.6, -11.6, BAY1_Z0, "front", "inner", "detail", note="dark underbody following the nose taper: backing for wide chins"),
    ]
    return p


def nose_frogeye():
    """Rear-engine sports: the shortest nose. A low lid between two wings that peak over the arch, each with a round lamp pod low at the front, over a wrap-round bumper."""
    w = SEAM_X
    p = front_core(w, 0.2) + wing(BAY1_X, w, BAY1_Z0, Z_COWL)
    p += [
        bx(3.6, FLOOR, 0.2, -11.0, -10.2, "detail", "chin shelf at Y 0, under the bumper"),
        tp(3.6, 4.7, FLOOR, 0.2, -11.0, -10.2, "front", "inner", "detail", note="chin shelf corner: backing for wide chins"),
        bx(4.7, FLOOR, 0.2, -10.2, BAY1_Z0, "detail", "chin shelf, back"),
        bx(3.6, 0.2, 0.8, -11.0, -10.5, "primary", "wrap-round bumper under the lamps: it carries the short nose forward at chin height"),
        tp(3.6, 4.7, 0.2, 0.8, -11.0, -10.2, "front", "inner", note="bumper corner, swept round to the wing"),
        box(2.9, 3.9, 0.2, 2.5, -10.5, BAY1_Z0, "primary", True, "low wing front"),
        tp(3.9, w, 0.2, 2.5, -10.5, BAY1_Z0, "front", "inner", note="front corner, rounded off in plan"),
        wf(2.9, 3.9, 2.5, BELT, -10.5, BAY1_Z0, "primary", True, "wing front rising from the lamp"),
        wf(2.9, w - CHAM, BELT, 3.6, BAY1_Z0, FZC, "primary", True, "wing crest rising to its peak over the arch"),
        wr(2.9, w - CHAM, BELT, 3.6, FZC, -3.4, "primary", True, "wing crest falling to the cowl"),
        cz(3.4, 2.4, -10.75, -9.9, 1.2, "primary", True, "lamp pod, low at the front"),
        cz(3.4, 2.4, -10.87, -10.75, 0.95, "neon", True, "round lamp"),
        bx(2.9, 0.2, 1.6, -10.8, BAY1_Z0, "primary", "short nose"),
        wf(-2.9, 2.9, 1.6, 2.7, -10.8, BAY1_Z0, "primary", note="front lid slope"),
        box(3.0, 3.8, 0.8, 1.1, -10.56, -10.5, "neon", True, "indicator"),
        bx(2.4, 0.35, 0.65, -11.06, -11.0, "detail", "low intake slot in the bumper"),
    ]
    return p


def nose_shark():
    """Modern GT: long, wide and tall. The wings hump high over the arches, with wide flares and a blunt nose with a big mouth."""
    w = SEAM_X
    p = front_core(w, 0.2) + wing(BAY1_X, w, BAY1_Z0, Z_COWL) + chin_pad() + flare(w, 5.4, FA0, FA1)
    p += [
        wf(BAY1_X, w - CHAM, BELT, 3.75, BAY1_Z0, -7.2, "primary", True, "wing hump rising over the arch"),
        wr(BAY1_X, w - CHAM, BELT, 3.75, -7.2, Z_COWL, "primary", True, "wing hump falling to the cowl"),
        bx(3.2, 0.2, 2.0, -12.2, BAY1_Z0, "primary", "blunt nose"),
        box(3.2, w, 0.2, 2.0, -10.6, BAY1_Z0, "primary", True, "nose corner"),
        tp(3.2, w, 0.2, 2.0, -12.2, -10.6, "front", "inner", note="long corner cut: the nose comes to a blunt point in plan"),
        wf(-3.2, 3.2, 2.0, BELT, -12.3, BAY1_Z0, "primary", note="bonnet leading edge, drooping to the mouth"),
        wf(3.2, w, 2.0, BELT, -10.7, BAY1_Z0, "primary", True, "wing leading edge"),
        bx(2.9, 0.45, 1.7, -12.27, -12.2, "detail", "wide mouth"),
        bx(2.9, 1.0, 1.15, -12.32, -12.2, "secondary", "grille bar"),
        box(2.0, 3.1, 1.75, 1.93, -12.28, -12.2, "neon", True, "slit lamp"),
    ]
    return p


def nose_clubman():
    """Roadster: a narrow, low nose cone with open front corners over a swept dark apron. The lift jets stand in the open air and the lamps ride on posts."""
    w, y9 = SEAM_X, 2.0
    p = chin_pad(0.3, 3.4) + [
        tp(3.4, CHIN_X, FLOOR, 0.3, -10.8, -10.0, "front", "inner", "detail", note="chin shelf corner, swept back beside the cone: backing for wide chins"),
        box(3.4, CHIN_X, FLOOR, 0.3, -10.0, BAY1_Z0, "detail", True, "chin shelf, back"),
        bx(BAY1_X, FLOOR, BAY1_Y, BAY1_Z0, Z_COWL, "detail", "bonnet bay floor: Engine1 pad at Y 1.0"),
        box(BAY1_X, ARCH_X, FLOOR, y9, BAY1_Z0, Z_COWL, "primary", True, "bonnet side: lift-jet pad at X 3.3"),
        wf(BAY1_X, ARCH_X, y9, BELT, BAY1_Z0, Z_COWL, "primary", True, "bonnet side rising to the beltline"),
        box(ARCH_X, w, FLOOR, COVE_Y0, COVE0, Z_COWL, "primary", True, "sill under the side-exit cove"),
        box(ARCH_X, 3.9, COVE_Y0, ARCH_TOP, FA1, COVE0, "primary", True, "scuttle flare root"),
        tp(ARCH_X, w, COVE_TOP, BELT, COVE0, Z_COWL, "front", "inner", note="scuttle flare out to the seam width"),
        bx(1.9, 0.3, 1.6, -12.0, BAY1_Z0, "primary", "nose cone"),
        tp(1.9, ARCH_X, 0.3, 1.6, -12.0, BAY1_Z0, "front", "inner", note="cone taper"),
        wf(-2.7, 2.7, 1.6, y9, -11.2, BAY1_Z0, "primary", note="cone top"),
        bx(1.5, 0.5, 1.45, -12.07, -12.0, "detail", "upright grille"),
        bx(1.7, 1.45, 1.58, -12.1, -12.0, "secondary", "bright grille top"),
        box(ARCH_X, 3.6, 1.7, 3.0, -9.55, -9.25, "detail", True, "lamp post"),
        cz(4.0, 2.95, -10.0, -8.8, 0.9, "secondary", True, "bullet lamp"),
        cz(4.0, 2.95, -10.08, -10.0, 0.7, "neon", True, "lamp"),
    ]
    return p


def nose_estate():
    """Shooting brake: a square upright nose at full bonnet height. Bright grille, four round lamps, wing-top mirrors."""
    w = SEAM_X
    p = front_core(w, 0.3) + wing(BAY1_X, w, BAY1_Z0, Z_COWL, cham=0.2) + chin_pad(0.3)
    p += [
        box(3.9, 4.2, BELT, 3.1, -11.0, Z_COWL, "secondary", True, "bright wing-top spear"),
        bx(w, 0.3, BELT, -11.3, BAY1_Z0, "primary", "square nose"),
        bx(4.5, 0.6, 2.8, -11.5, -11.3, "primary", "nose face"),
        bx(2.3, 1.0, 2.5, -11.6, -11.5, "secondary", "bright grille frame"),
        bx(2.1, 1.15, 2.35, -11.65, -11.6, "detail", "grille mesh"),
        cz(3.0, 2.0, -11.68, -11.5, 0.8, "neon", True, "inner lamp"),
        cz(3.95, 2.0, -11.68, -11.5, 0.8, "neon", True, "outer lamp"),
        box(3.95, 4.15, 3.1, 3.5, -7.0, -6.8, "detail", True, "wing mirror stalk"),
        box(3.7, 4.4, 3.5, 3.8, -7.2, -6.7, "secondary", True, "wing-top mirror"),
    ]
    return p


def nose_works():
    """GT3: box arches out to the limit with louvres, low short nose, bonnet duct. Behind the arch the box closes in to the door in a long taper."""
    w = WIDE_X - 0.05
    p = front_core(SEAM_X, 0.2, w_arch=w) + chin_pad()
    p += wing(BAY1_X, SEAM_X, FA1, Z_COWL)
    p += [
        box(BAY1_X, w, ARCH_TOP, 3.45, -10.3, FA1, "primary", True, "box arch"),
        wr(BAY1_X, SEAM_X - CHAM, BELT, 3.45, FA1, -4.0, "primary", True, "arch top falling to the beltline"),
        tp(SEAM_X, w, COVE_TOP, BELT, FA1, -3.0, "rear", "inner", note="arch closing in to the door over the cove"),
        wf(ARCH_X, w, ARCH_TOP, 3.45, -11.4, -10.3, "primary", True, "arch leading edge"),
        box(ARCH_X, w, 0.2, ARCH_TOP, -11.4, BAY1_Z0, "primary", True, "arch front corner"),
        bx(ARCH_X, 0.2, 1.6, -11.6, BAY1_Z0, "primary", "low nose"),
        wf(-ARCH_X, ARCH_X, 1.6, 2.8, -11.6, BAY1_Z0, "primary", note="nose slope"),
        on_slope(BAY1_Z0, 2.8, -11.6, 1.6, -1.8, 1.8, -11.0, -10.0, "detail", note="bonnet duct"),
        bx(2.6, 0.45, 1.3, -11.67, -11.6, "detail", "radiator mouth"),
        box(4.0, 5.5, 1.0, 1.5, -11.47, -11.4, "neon", True, "lamp bar"),
        box(5.5, w, COVE_Y0, ARCH_TOP, FA1 + 0.02, COVE0 - 0.02, "secondary", True, "arch end plate"),
    ]
    for i in range(3):
        z = -8.8 + i * 1.0
        p.append(box(3.7, 5.6, 3.45, 3.8, z, z + 0.3, "secondary", True, "arch louvre"))
    return p


# --------------------------------------------------------------------------------------
# RearBody: haunches, blanked rear arches, the tail bay and the transom
# --------------------------------------------------------------------------------------
def rear_core(w=SEAM_X, tail=11.4, cham=CHAM, haunch=True):
    """Pads every tail must carry: bay floor, deck bulkhead, arch walls, transom, spoiler pads."""
    p = [
        bx(BAY2_X, FLOOR, BAY2_Y, Z_BACK, TRANSOM, "detail", "tail bay floor: Engine2 pad at Y 1.0"),
        bx(BAY2_X, BAY2_Y, BELT, Z_BACK, BAY2_Z0, "primary", "deck bulkhead, flat at Y 3.0"),
        box(BAY2_X, ARCH_X, FLOOR, ARCH_TOP, Z_BACK, TRANSOM, "detail", True, "blanked arch wall: lift-jet pad at X 3.3"),
        box(ARCH_X, w, 0.3, ARCH_TOP, Z_BACK, RA0, "primary", True, "arch front pillar"),
        box(ARCH_X, w, 0.3, ARCH_TOP, RA1, TRANSOM, "primary", True, "rear quarter"),
        box(BAY2_X, w, 1.0, ARCH_TOP, TRANSOM, tail, "primary", True, "tail band above the valance"),
    ]
    if haunch:
        p += wing(BAY2_X, w, Z_BACK, tail, cham=cham, note="haunch; deck and spoiler pad at Y 3.0")
    return p


def tail_kamm():
    """Classic GT: the shortest tail. The hips rise to a high edge and the tail is cut off square. Twin round lamps."""
    w, t = SEAM_X, 10.7
    p = rear_core(w, t)
    p += [
        wf(GLASS_X, w - CHAM, BELT, 3.6, 5.6, t, "primary", True, "hip line rising to the high cut-off"),
        box(BAY2_X, 4.6, 1.2, 2.55, t, t + 0.08, "detail", True, "recessed Kamm panel"),
        cz(2.95, 1.9, t, t + 0.2, 0.8, "neon", True, "inner round lamp"),
        cz(3.95, 1.9, t, t + 0.2, 0.8, "neon", True, "outer round lamp"),
        box(BAY2_X, w - CHAM, 2.85, BELT, t, t + 0.14, "secondary", True, "bright tail lip"),
    ]
    return p


def tail_hips():
    """Rear-engine sports: the widest road tail. Round hips swell over the arches, then the tail slopes away to a low edge."""
    w, f, t, e = SEAM_X, 5.6, 10.6, 12.4
    p = rear_core(w, t, cham=0)
    p += [
        box(w, f, ARCH_TOP, BELT, RA0, RA1, "primary", True, "wide hip over the arch"),
        tp(w, f, ARCH_TOP, BELT, Z_BACK, RA0, "front", "inner", note="hip swells from the seam"),
        box(w, f, 0.3, BELT, RA1, 9.9, "primary", True, "wide rear quarter"),
        tp(w, f, 1.0, BELT, 9.9, 10.8, "rear", "inner", note="hip tapers into the tail"),
        box(w, f, 0.3, 1.0, 9.9, TRANSOM, "primary", True, "quarter foot"),
        wf(GLASS_X, f, BELT, 3.3, Z_BACK, 6.6, "primary", True, "hip crown rise"),
        box(GLASS_X, f, BELT, 3.3, 6.6, 8.4, "primary", True, "hip crown"),
        wr(GLASS_X, f, BELT, 3.3, 8.4, t, "primary", True, "hip crown fall"),
        wr(BAY2_X, w, 1.0, BELT, t, e, "primary", True, "tail slopes away to a low edge"),
        on_slope(t, BELT, e, 1.0, BAY2_X + 0.15, w - 0.15, 11.0, 11.35, "neon", m=True, note="lamp strip"),
    ]
    return p


def tail_muscle():
    """Modern GT: a tall haunch peaking over the arch, arch flares, and a long undercut tail edge over slit lamps."""
    w, t = SEAM_X, 11.3
    p = rear_core(w, t, cham=0.25) + flare(w, 5.4, RA0, RA1, run=0.45)
    p += [
        wf(GLASS_X, w - 0.25, BELT, 3.7, Z_BACK, 7.6, "primary", True, "haunch rising to its peak"),
        wr(GLASS_X, w - 0.25, BELT, 3.7, 7.6, t, "primary", True, "haunch falling to the tail"),
        box(BAY2_X, 4.6, 1.2, 1.9, t, t + 0.07, "detail", True, "tail vent"),
        box(BAY2_X + 0.1, 4.6, 2.05, 2.25, t, t + 0.12, "neon", True, "slit lamp"),
        wur(BAY2_X, w - 0.25, 2.35, BELT, t, 12.3, "primary", True, "undercut tail edge"),
    ]
    return p


def tail_boat():
    """Roadster: open rear corners and the longest tail. The lift jets stand in the open air, then the tail closes in to a pointed stern."""
    w, t, e = SEAM_X, 10.8, 12.3
    p = rear_core(w, t, haunch=False)
    p += [
        box(BAY2_X, ARCH_X, ARCH_TOP, BELT, Z_BACK, t, "primary", True, "narrow deck beside the bay; spoiler pad at Y 3.0"),
        tp(ARCH_X, w, ARCH_TOP, BELT, Z_BACK, 7.0, "rear", "inner", note="seam flare closing in behind the door"),
        tp(ARCH_X, w, ARCH_TOP, BELT, 7.9, RA1, "front", "inner", note="rear quarter swelling out again"),
        box(ARCH_X, w, ARCH_TOP, BELT, RA1, t, "primary", True, "rear quarter top; spoiler pad at Y 3.0"),
        box(BAY2_X, ARCH_X, 1.6, 2.1, t, e, "primary", True, "stern spine"),
        wr(BAY2_X, ARCH_X, 2.1, BELT, t, e, "primary", True, "stern top falling"),
        wur(BAY2_X, ARCH_X, 1.0, 1.6, t, e, "primary", True, "stern underside rising"),
        tp(ARCH_X, w, ARCH_TOP, BELT, t, 11.5, "rear", "inner", note="boat tail taper"),
        tp(ARCH_X, w, 1.0, ARCH_TOP, t, 11.9, "rear", "inner", note="lower boat tail"),
        box(2.45, 3.15, 1.68, 2.02, e, e + 0.08, "neon", True, "small tail lamp"),
    ]
    return p


def tail_estate():
    """Shooting brake: a square tail with tall side rails and tall lamp columns. Its deck ends at Z 11.0, close behind the Brake tailgate."""
    w, t = SEAM_X, 11.0
    p = rear_core(w, t, cham=0.2)
    p += [
        wf(GLASS_X, w - 0.2, BELT, 3.7, Z_BACK, 6.2, "primary", True, "side rail rising from the door"),
        box(GLASS_X, w - 0.2, BELT, 3.7, 6.2, t, "primary", True, "tall side rail"),
        box(3.75, 4.55, 1.5, 3.6, t, t + 0.1, "neon", True, "lamp column"),
        box(BAY2_X, 3.6, 1.2, 2.8, t, t + 0.07, "detail", True, "tail panel"),
        box(BAY2_X, 3.6, 2.85, BELT, t, t + 0.14, "secondary", True, "bright tailgate sill"),
        box(w - 0.2, w - 0.14, 3.2, 3.4, 6.4, t - 0.3, "secondary", True, "bright rail strip"),
    ]
    return p


def tail_works():
    """GT3: box arches out to the limit, louvres, then a narrow stripped tail. The box swells from the door seam and closes in again behind the arch."""
    w, t = WIDE_X - 0.05, 10.7
    p = rear_core(SEAM_X, t, cham=0)
    p += [
        tp(SEAM_X, w, ARCH_TOP, BELT, Z_BACK, 6.0, "front", "inner", note="box arch swelling from the seam"),
        box(SEAM_X, w, ARCH_TOP, BELT, 6.0, 9.4, "primary", True, "box arch"),
        box(GLASS_X, w, BELT, 3.25, 6.0, 9.4, "primary", True, "box arch top"),
        tp(SEAM_X, w, 0.3, ARCH_TOP, Z_BACK, RA0, "front", "inner", note="arch front corner"),
        box(5.5, w, 0.3, ARCH_TOP, RA1, 9.4, "secondary", True, "arch end plate"),
        tp(SEAM_X, w, 0.3, BELT, 9.4, TRANSOM, "rear", "inner", note="box arch closing in to the tail"),
        box(BAY2_X, SEAM_X, 1.1, 2.9, t, t + 0.07, "detail", True, "mesh tail panel"),
        box(2.6, 4.4, 2.3, 2.6, t, t + 0.14, "neon", True, "lamp bar"),
    ]
    for i in range(3):
        z = 6.4 + i * 1.0
        p.append(box(3.9, 5.6, 3.25, 3.6, z, z + 0.3, "secondary", True, "arch louvre"))
    return p


# --------------------------------------------------------------------------------------
# Engine1: the front engine in the bonnet bay, with side exits in the coves
# --------------------------------------------------------------------------------------
def cove_pipe(d, length, yaw, y=1.05, x=4.25, z=-5.0, ch="secondary", tip=0.3):
    """A side-exit pipe in the cove behind the front arch, pointing back and outwards."""
    return jet([x, y, z], [0, yaw, 0], d, length, ch, tip=tip, m=True, note="side-exit nozzle")


def tray1():
    """A bright tray plate over the bonnet bay floor, out to the bay edge, so no dark floor shows."""
    return [bx(BAY1_X - 0.05, BAY1_Y, BAY1_Y + 0.12, BAY1_Z0 + 0.05, Z_COWL - 0.05, "secondary", "tray plate out to the bay edge")]


def engine1_inline():
    """Classic GT: one long slim turbine under six intake stacks, with a log manifold each side. Slim side pipes."""
    p = tray1() + [
        cz(0, 1.95, -9.5, -8.6, 1.9, "detail", note="intake bell behind the grille"),
        cz(0, 1.95, -8.6, -3.0, 1.7, "secondary", note="long slim turbine"),
        bx(1.3, 1.12, 2.4, -3.0, -2.65, "detail", "collector"),
        cz(1.45, 1.7, -8.4, -3.0, 0.8, "detail", True, "log manifold"),
    ]
    for z in (-7.8, -6.5, -5.2):
        p.append(box(0.6, 1.3, 1.55, 1.85, z - 0.15, z + 0.15, "detail", True, "manifold branch"))
        for x in (-0.42, 0.42):
            p.append(cy(x, z, 2.5, 3.42, 0.6, "secondary", note="intake stack"))
            p.append(cy(x, z, 3.42, 3.49, 0.42, "detail", note="stack mouth"))
    p += cove_pipe(0.8, 1.7, 22)
    return p


def engine1_twin_ram():
    """Rear-engine sports: two low turbines in the front half of the bay, tops flush with the wing line, then a flush lid with two inlet slots. Small side exits."""
    p = tray1() + [
        cz(0.95, 2.1, -9.3, -6.2, 1.7, "secondary", True, "low ram turbine, flush with the wing line"),
        cz(0.95, 2.1, -9.5, -9.3, 1.3, "detail", True, "intake"),
        cz(0.95, 2.1, -9.56, -9.5, 0.9, "neon", True, "intake glow"),
        bx(1.9, 1.12, 2.45, -6.2, -2.7, "detail", "plenum under the lid"),
        bx(1.9, 2.45, 2.85, -6.2, -2.7, "secondary", "flush lid"),
        box(0.45, 1.45, 2.85, 2.93, -5.7, -3.3, "detail", True, "flush inlet slot"),
    ]
    p += cove_pipe(1.0, 1.0, 35, y=1.05, x=4.2, z=-4.85, ch="detail")
    return p


def engine1_big_single():
    """Modern GT: one big turbine set back against the cowl under a power dome. Twin slot exits each side."""
    p = tray1() + [
        cz(0, 2.3, -8.2, -7.2, 2.1, "detail", note="intake bell"),
        cz(0, 2.4, -7.2, -3.4, 2.7, "secondary", note="big turbine"),
        bx(1.5, 1.12, 3.0, -3.4, Z_COWL, "primary", "power dome base"),
        wr(-1.5, 1.5, 3.0, 3.75, -3.4, Z_COWL, "primary", note="power dome"),
        box(ARCH_X + 0.05, 4.95, 0.45, 1.7, -5.1, -3.9, "detail", True, "exit housing in the cove"),
        box(4.95, 5.05, 1.2, 1.55, -5.0, -4.0, "thrust", True, "upper slot jet"),
        box(4.95, 5.05, 0.6, 0.95, -5.0, -4.0, "thrust", True, "lower slot jet"),
    ]
    return p


def engine1_quad():
    """Roadster: four small jets stacked two by two in the middle of the bay. Twin pipes each side."""
    p = tray1()
    for x in (-0.68, 0.68):
        for y in (1.7, 2.82):
            p.append(cz(x, y, -8.0, -5.0, 1.1, "secondary", note="throttle jet"))
            p.append(cz(x, y, -8.7, -8.0, 1.25, "detail", note="bell mouth"))
    p.append(bx(1.35, 1.12, 3.4, -5.0, -4.3, "detail", "collector box"))
    p += jet([4.0, 1.4, -5.0], [0, 30, 0], 0.6, 1.5, "secondary", tip=0.25, m=True, note="upper side pipe")
    p += jet([4.0, 0.7, -5.0], [0, 30, 0], 0.6, 1.5, "secondary", tip=0.25, m=True, note="lower side pipe")
    return p


def engine1_scoop():
    """Shooting brake: a wide turbine case under a tall ram scoop. One fat side dump each side."""
    p = tray1() + [
        bx(1.6, 1.12, 2.3, -8.2, -3.2, "detail", "wide turbine case"),
        cz(0, 1.9, -8.9, -8.2, 1.7, "detail", note="intake"),
        bx(1.05, 2.3, 3.78, -7.6, -5.6, "secondary", "ram scoop"),
        wr(-1.05, 1.05, 2.3, 3.78, -5.6, -3.2, "secondary", note="scoop fairing"),
        bx(0.85, 2.75, 3.62, -7.67, -7.6, "detail", "scoop mouth"),
    ]
    p += cove_pipe(1.2, 1.3, 28, y=1.05, x=4.2, z=-4.9, ch="detail")
    return p


def engine1_ram_slot():
    """GT3: a flat duct the full width of the bay at bonnet height, with a slot jet and vanes standing above it. Box vents each side."""
    p = [
        bx(1.9, 1.05, 3.0, -9.5, -2.7, "detail", "flat duct at bonnet height"),
        bx(1.6, 3.0, 3.14, -6.0, -3.4, "thrust", "flat slot jet in the bonnet"),
        box(ARCH_X + 0.05, 5.55, 0.45, 1.7, -5.1, -3.0, "detail", True, "box vent in the cove"),
        box(5.55, 5.65, 0.65, 1.5, -4.8, -3.3, "thrust", True, "side slot jet"),
    ]
    for z in (-5.3, -4.3):
        p.append(bx(1.75, 3.0, 3.5, z, z + 0.14, "secondary", "slot vane"))
    for z in (-8.9, -7.8):
        p.append(bx(1.7, 3.0, 3.22, z, z + 0.4, "secondary", "intake louvre"))
    return p


# --------------------------------------------------------------------------------------
# Engine2: the rear engine standing through the framed hatch in the tail deck, nozzles out through the tail
# --------------------------------------------------------------------------------------
def tray2():
    """A bright tray plate over the hatch floor, out to the hatch edge, so no dark floor shows."""
    return [bx(BAY2_X - 0.05, BAY2_Y, BAY2_Y + 0.12, BAY2_Z0 + 0.05, TRANSOM, "secondary", "tray plate out to the hatch edge")]


def engine2_tail_twin():
    """Classic GT: two slim turbines side by side, the full length of the hatch, each under two intake trumpets."""
    p = tray2() + [
        cz(0.85, 2.0, 7.6, 11.6, 1.5, "secondary", True, "slim turbine"),
        cz(0.85, 2.0, 7.3, 7.6, 1.15, "detail", True, "intake"),
        box(0.55, 1.15, 1.12, 1.4, 8.0, 8.4, "detail", True, "saddle"),
        box(0.55, 1.15, 1.12, 1.4, 9.8, 10.2, "detail", True, "saddle"),
    ]
    for z in (8.1, 9.2):
        p.append(cy(0.85, z, 2.6, 3.4, 0.8, "secondary", True, "intake trumpet standing through the deck"))
        p.append(cy(0.85, z, 3.4, 3.47, 0.56, "detail", True, "trumpet mouth"))
    p += jet([0.85, 2.0, 11.6], [0, 0, 0], 1.4, 0.6, "detail", tip=0.3, tip_d=1.1, m=True, note="nozzle")
    return p


def engine2_boxer():
    """Rear-engine sports: one fat turbine three studs wide with a tall fan turret at the front and one big nozzle."""
    p = tray2() + [
        bx(1.5, 1.12, 2.5, 7.4, 10.0, "secondary", "wide turbine housing"),
        bx(0.95, 2.5, 3.3, 7.5, 9.0, "secondary", "fan turret standing through the deck"),
        wr(-0.95, 0.95, 2.5, 3.3, 9.0, Z_EXT, "secondary", note="turret fairing"),
        cz(0, 2.0, 10.0, 11.2, 1.9, "detail", note="fat turbine"),
    ]
    for z in (7.65, 8.1, 8.55):
        p.append(bx(0.8, 3.3, 3.48, z, z + 0.28, "detail", "intake louvre"))
    p += jet([0, 2.0, 11.2], [0, 0, 0], 2.0, 0.95, "secondary", tip=0.35, tip_d=1.6, note="big nozzle")
    return p


def engine2_quad():
    """Modern GT: two intake ducts feeding a square housing at the back of the hatch, with four nozzles in a square."""
    p = tray2() + [
        cz(0.75, 1.75, 7.3, 8.8, 1.2, "secondary", True, "intake duct"),
        cz(0.75, 1.75, 7.2, 7.3, 0.85, "detail", True, "duct mouth"),
        bx(1.45, 1.12, 3.0, 8.8, 11.0, "detail", "square housing"),
        bx(1.45, 3.0, 3.3, 8.8, 9.95, "detail", "housing top standing through the deck"),
    ]
    p.append(bx(1.2, 3.3, 3.42, 9.1, 9.7, "secondary", "intake slot"))
    for x in (-0.72, 0.72):
        for y in (1.62, 2.4):
            p += jet([x, y, 11.0], [0, 0, 0], 1.1, 1.15, "secondary", tip=0.3, tip_d=0.9, note="quad nozzle")
    return p


def engine2_triple():
    """Roadster: three tubes in a row, fed by an intake log that lies across them above the deck."""
    p = tray2() + [
        bx(1.6, 1.12, 1.95, 9.2, 9.8, "detail", "cradle bar"),
        cx(3.0, 7.8, -1.62, 1.62, 0.95, "detail", note="intake log standing through the deck"),
    ]
    for x in (-1.12, 0.0, 1.12):
        p.append(cz(x, 2.45, 8.2, 12.2, 1.05, "secondary", note="tube"))
        p.append(cz(x, 2.45, 12.2, 12.5, 0.88, "thrust", note="jet"))
        p.append(cy(x, 7.8, 3.3, 3.5, 0.5, "secondary", note="log cap"))
    return p


def engine2_vee():
    """Shooting brake: a tall block at the front of the hatch with two tall, narrow, square-cut nozzles splayed apart in a vee."""
    p = tray2() + [
        bx(1.3, 1.12, 3.0, 7.4, 9.2, "detail", "engine block"),
        bx(1.4, 3.0, 3.45, 7.5, 9.1, "secondary", "bright top plate standing through the deck"),
        bx(1.0, 3.45, 3.5, 7.8, 8.8, "detail", "intake mesh"),
    ]
    yaw, start, length = 15.0, [0.4, 2.0, 9.0], 3.2
    ax = [math.sin(math.radians(yaw)), 0.0, math.cos(math.radians(yaw))]
    mid = [start[i] + ax[i] * length / 2 for i in range(3)]
    end = [start[i] + ax[i] * (length + 0.13) for i in range(3)]
    p += [
        part("block", [0.7, 1.5, length], mid, "secondary", [0, yaw, 0], True, "tall square-cut nozzle, splayed outwards"),
        part("block", [0.48, 1.28, 0.3], end, "thrust", [0, yaw, 0], True, "jet"),
    ]
    return p


def engine2_slot():
    """GT3: a ram scoop on a low plenum, then one thin flat nozzle the full width of the hatch, held high over open air and pitched down at the tail between two side plates."""
    pitch, length = 14.0, 2.6
    c, s = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    mid = [0.0, 2.42, 11.0]
    tip = [0.0, mid[1] - s * (length / 2 + 0.1), mid[2] + c * (length / 2 + 0.1)]
    p = tray2() + [
        bx(1.45, 1.12, 2.2, 7.5, 10.2, "detail", "low plenum"),
        bx(1.3, 2.2, 2.9, 7.5, 9.9, "detail", "scoop neck"),
        wr(-1.3, 1.3, 2.9, 3.5, 7.5, 9.9, "secondary", note="ram scoop standing through the deck"),
        bx(1.1, 2.95, 3.4, 7.43, 7.5, "detail", "scoop mouth"),
        part("block", [3.0, 0.5, length], mid, "detail", [pitch, 0, 0], note="thin flat nozzle, pitched down at the tail"),
        part("block", [2.8, 0.34, 0.22], tip, "thrust", [pitch, 0, 0], note="slot jet, the full width of the nozzle"),
        part("block", [0.17, 0.74, length], [1.585, mid[1], mid[2]], "secondary", [pitch, 0, 0], True, "side plate"),
    ]
    return p


# --------------------------------------------------------------------------------------
# Stabilisers: a lift jet in each blanked arch
# --------------------------------------------------------------------------------------
def corners(fn):
    out = []
    for zc in (FZC, RZC):
        out += fn(zc)
    return out


def stab_torpedo():
    """Classic GT: one slim torpedo per corner, nozzle canted down and back."""
    def one(zc):
        p = [
            box(ARCH_X, 4.0, 0.9, 1.3, zc - 0.6, zc + 0.2, "detail", True, "strut"),
            cz(4.55, 1.1, zc - 1.6, zc + 0.5, 1.3, "secondary", True, "torpedo pod"),
            cz(4.55, 1.1, zc - 1.66, zc - 1.6, 0.85, "detail", True, "intake"),
        ]
        p += jet([4.55, 0.95, zc + 0.25], [48, 0, 0], 1.05, 1.3, "detail", tip=0.3, m=True, note="lift nozzle")
        return p
    return corners(one)


def stab_columns():
    """Rear-engine sports: two upright lift tubes per corner."""
    def one(zc):
        p = [box(ARCH_X, 5.0, 1.55, 1.85, zc - 1.4, zc + 1.4, "detail", True, "carrier plate")]
        for dz in (-0.8, 0.8):
            p.append(cy(4.4, zc + dz, -0.8, 1.55, 1.1, "secondary", True, "lift tube"))
            p.append(cy(4.4, zc + dz, -1.25, -0.8, 0.85, "thrust", True, "jet"))
        return p
    return corners(one)


def stab_vane():
    """Modern GT: a flat louvred box low in the arch, one wide sheet of thrust."""
    def one(zc):
        p = [
            box(ARCH_X, 3.9, 0.4, 1.6, zc - 1.1, zc - 0.7, "detail", True, "hanger"),
            box(ARCH_X, 3.9, 0.4, 1.6, zc + 0.7, zc + 1.1, "detail", True, "hanger"),
            box(3.5, 5.35, -0.3, 0.6, zc - 1.6, zc + 1.6, "secondary", True, "vane box"),
            box(3.65, 5.2, -0.65, -0.3, zc - 1.4, zc + 1.4, "thrust", True, "sheet jet"),
        ]
        for dz in (-0.9, 0.0, 0.9):
            p.append(box(3.55, 5.3, -0.75, -0.25, zc + dz - 0.07, zc + dz + 0.07, "detail", True, "vane"))
        return p
    return corners(one)


def stab_slant():
    """Roadster: one vee-nozzle unit per corner. A pod high in the arch with two short fat dark nozzles splayed fore and aft. The tips stop just under the sill, tucked in the arch."""
    def one(zc):
        p = [box(ARCH_X, 5.1, 1.5, 2.25, zc - 0.7, zc + 0.7, "secondary", True, "pod body on the arch wall")]
        p += jet([4.5, 1.45, zc + 0.05], [50, 0, 0], 1.1, 1.6, "detail", tip=0.3, tip_d=0.9, m=True, note="slant nozzle, down and back")
        p += jet([4.5, 1.45, zc - 0.05], [130, 0, 0], 1.1, 1.6, "detail", tip=0.3, tip_d=0.9, m=True, note="slant nozzle, down and forward")
        return p
    return corners(one)


def stab_comb():
    """Shooting brake: a slim rail high in the arch with a row of five thin down-pipes."""
    def one(zc):
        p = [box(ARCH_X, 4.7, 1.95, 2.3, zc - 1.6, zc + 1.6, "secondary", True, "comb rail")]
        for dz in (-1.3, -0.65, 0.0, 0.65, 1.3):
            p.append(cy(4.3, zc + dz, -0.2, 1.95, 0.5, "detail", True, "down pipe"))
            p.append(cy(4.3, zc + dz, -0.5, -0.2, 0.38, "thrust", True, "jet"))
        return p
    return corners(one)


def stab_outrigger():
    """GT3: one big lift nacelle per corner, hung under its own body-colour stub winglet from the arch wall and firing straight down."""
    def one(zc):
        return [
            box(ARCH_X, 5.4, 1.9, 2.3, zc - 1.0, zc + 1.0, "primary", True, "stub winglet from the arch wall, over the nacelle"),
            box(5.0, 5.45, 1.98, 2.22, zc - 0.8, zc + 0.8, "detail", True, "intake slot in the winglet tip"),
            cy(4.6, zc, -0.5, 1.9, 1.5, "secondary", True, "lift nacelle"),
            cy(4.6, zc, -0.85, -0.5, 1.15, "thrust", True, "jet"),
        ]
    return corners(one)


# --------------------------------------------------------------------------------------
# Boost: afterburners on the transom, outboard under the lamps, where the exhaust tips were
# --------------------------------------------------------------------------------------
def burner(x, y, z0, z1, d, core, m=True, ch="secondary", collar=0.4, grow=0.25):
    """An afterburner can: a body, a dark petal collar wider than the can, and a small glowing core set inside it.
    Engine nozzles are a bright tube with a wide glow, so the two never read alike."""
    return [
        cz(x, y, z0, z1 - collar, d, ch, m, "afterburner can"),
        cz(x, y, z1 - collar, z1, d + grow, "detail", m, "dark petal collar"),
        cz(x, y, z1, z1 + 0.15, core, "thrust", m, "burner core"),
    ]


# Every afterburner sits on the transom between Y -0.25 and 1.0, so it never hangs below a short bumper.
BY = 0.4     # centre height of a full-size burner (1.2 across fills the transom band)


def boost_megaphones():
    """Classic GT: one long megaphone each side, far apart. A slim pipe that flares in two steps to a wide mouth, the longest burner in the class."""
    return [
        box(2.2, 3.35, 0.0, 0.8, TRANSOM, 10.6, "detail", True, "bracket"),
        cz(2.8, BY, 10.5, 11.6, 0.6, "secondary", True, "slim pipe"),
        cz(2.8, BY, 11.6, 12.7, 0.9, "secondary", True, "megaphone"),
        cz(2.8, BY, 12.7, 13.3, 1.2, "detail", True, "dark petal collar: the megaphone mouth"),
        cz(2.8, BY, 13.3, 13.45, 0.75, "thrust", True, "burner core"),
    ]


def boost_stacked():
    """Rear-engine sports: two short fat cans each side, one high and inboard, one low and outboard, on one surround plate."""
    p = [box(1.7, 3.4, -0.24, 0.99, TRANSOM, 10.65, "detail", True, "surround plate")]
    for x, y in ((2.1, 0.55), (2.94, 0.2)):
        p += burner(x, y, 10.6, 12.2, 0.8, 0.5, grow=0.08)
    return p


def boost_quad_tips():
    """Modern GT: four squared tips in one row across the centre, low under the rear engine nozzles."""
    p = [bx(1.85, 0.6, 0.95, TRANSOM, 10.7, "detail", "hanger bar across the transom")]
    for xc in (-1.41, -0.47, 0.47, 1.41):
        x0, x1 = xc - 0.4, xc + 0.4
        p.append(box(x0, x1, -0.12, 0.6, TRANSOM, 11.8, "secondary", note="squared tip"))
        p.append(box(x0 - 0.04, x1 + 0.04, -0.2, 0.68, 11.8, 12.2, "detail", note="dark square collar"))
        p.append(box(x0 + 0.17, x1 - 0.17, 0.0, 0.48, 12.2, 12.35, "thrust", note="burner core"))
    return p


def boost_cannon():
    """Roadster: one long dark cannon, on the right side only."""
    return [
        box(1.7, 3.35, -0.2, 0.98, TRANSOM, 10.7, "detail", note="mount"),
        cz(2.5, BY, 10.6, 11.2, 1.0, "secondary", note="cannon breech"),
        cz(2.5, BY, 11.2, 12.9, 1.2, "detail", note="long dark barrel, longer than it is wide"),
        cz(2.5, BY, 12.9, 13.05, 0.65, "thrust", note="burner core"),
    ]


def boost_staged():
    """Shooting brake: a long fat pipe close in, with a short slim pipe outboard of it, each side."""
    p = [box(1.8, 3.38, 0.0, 0.9, TRANSOM, 10.6, "detail", True, "manifold")]
    p += burner(2.3, BY, 10.5, 12.9, 1.0, 0.6, grow=0.2)
    p += [
        cz(3.08, 0.5, 10.5, 11.3, 0.5, "secondary", True, "second stage"),
        cz(3.08, 0.5, 11.3, 11.55, 0.62, "detail", True, "dark petal collar"),
        cz(3.08, 0.5, 11.55, 11.7, 0.34, "thrust", True, "burner core"),
    ]
    return p


def boost_blades():
    """GT3: one upright slot burner at each tail corner. A long square-cut can as tall as the transom band, an intake scoop on its outboard face, a dark collar and an upright slot jet."""
    return [
        box(2.45, 3.1, -0.15, 0.95, TRANSOM, 12.0, "secondary", True, "long upright can, as tall as the transom band"),
        box(2.4, 3.15, -0.24, 1.0, 12.0, 12.45, "detail", True, "dark upright collar"),
        box(2.58, 2.98, -0.06, 0.82, 12.45, 12.62, "thrust", True, "upright slot jet, standing proud of the collar"),
        tp(3.1, 3.4, 0.0, 0.8, 10.6, 11.9, "rear", "inner", "detail", note="intake scoop on the outboard face, mouth forward"),
    ]


# --------------------------------------------------------------------------------------
# SidePods: sills under the doors
# --------------------------------------------------------------------------------------
ZS0, ZS1 = Z_COWL + 0.1, Z_BACK - 0.1


def sill_chrome():
    return [box(DOOR_X, 4.98, 0.0, 0.45, ZS0, ZS1, "secondary", True, "slim bright sill")]


def sill_scoop():
    return [
        box(DOOR_X, 5.05, 0.0, 0.5, ZS0, ZS1, "detail", True, "black rocker"),
        tp(DOOR_X, 5.7, 0.3, 1.5, 1.0, ZS1, "front", "inner", note="intake scoop ahead of the rear arch"),
        box(4.85, 5.6, 0.45, 1.4, ZS1, ZS1 + 0.06, "detail", True, "scoop mouth"),
    ]


def sill_blade():
    return [
        box(DOOR_X, 5.25, -0.5, 0.55, ZS0, ZS1, "primary", True, "deep skirt"),
        box(5.0, 5.5, -0.75, -0.5, -1.6, ZS1, "detail", True, "skirt blade"),
        wf(5.25, 5.5, -0.5, 0.3, -1.6, 0.6, "detail", True, "vent wedge"),
    ]


def sill_nerf():
    p = [cz(5.25, 0.3, ZS0, ZS1, 0.55, "secondary", True, "nerf rail")]
    for z in (-1.8, 1.2, 4.0):
        p.append(box(DOOR_X, 5.2, 0.2, 0.4, z, z + 0.3, "detail", True, "rail bracket"))
    return p


def sill_gills():
    p = [box(DOOR_X, 5.0, 0.0, 1.4, ZS0, ZS1, "secondary", True, "tall two-tone cladding")]
    for z in (-2.0, -1.5, -1.0):
        p.append(box(5.0, 5.05, 0.5, 1.1, z, z + 0.2, "detail", True, "gill"))
    return p


def sill_floor():
    """GT3: a flat floor standing 0.6 out from the door, tapered to a point at both ends, with a fence ramping up towards the rear arch."""
    return [
        box(DOOR_X, 5.3, -0.3, 0.0, -1.6, 4.1, "detail", True, "flat floor"),
        tp(DOOR_X, 5.3, -0.3, 0.0, ZS0, -1.6, "front", "inner", "detail", note="floor tapering in to the door at the front"),
        tp(DOOR_X, 5.3, -0.3, 0.0, 4.1, ZS1, "rear", "inner", "detail", note="floor tapering in to the door at the back"),
        wf(5.05, 5.3, 0.0, 0.9, -0.6, 4.1, "secondary", True, "floor fence, ramping up towards the rear arch"),
    ]


# --------------------------------------------------------------------------------------
# FrontBumper: the chin, hung from the chin pad under the nose
# --------------------------------------------------------------------------------------
def chin_nerf():
    return [
        bx(2.6, -0.28, 0.0, -11.5, -10.4, "secondary", "bright under-blade"),
        box(1.4, 1.9, -0.75, -0.28, -11.5, -11.1, "secondary", True, "overrider"),
    ]


def chin_valance():
    """Rear-engine sports: a body-colour valance with cut-back corners, so it follows a pointed nose as well as a square one."""
    return [
        bx(3.4, -0.65, 0.0, -11.0, -9.6, "primary", "body-colour valance"),
        tp(3.4, 4.6, -0.65, 0.0, -11.0, -9.6, "front", "inner", note="valance corner, cut back in plan"),
        bx(3.4, -0.4, -0.25, -11.07, -11.0, "detail", "rubber strip"),
        box(2.0, 3.0, -0.6, -0.42, -11.07, -11.0, "neon", True, "fog lamp"),
    ]


def chin_lip():
    """Modern GT: a thin dark lip with swept corners. It shows a quarter of a stud round a blunt nose and hides under a long one."""
    return [
        bx(4.05, -0.22, 0.0, -11.6, -10.75, "detail", "thin lip, front"),
        tp(4.05, 4.9, -0.22, 0.0, -11.6, -10.75, "front", "inner", "detail", note="swept lip corner"),
        bx(4.9, -0.22, 0.0, -10.75, -9.6, "detail", "thin lip, back"),
    ]


def chin_skid():
    return [
        box(0.9, 2.3, -0.5, 0.0, -10.8, -9.6, "secondary", True, "skid nub"),
        wuf(0.9, 2.3, -0.5, 0.0, -11.6, -10.8, "secondary", True, "skid toe"),
    ]


def chin_dam():
    """Shooting brake: a deep upright air dam, set back and kept inside the narrowest nose."""
    return [
        bx(4.2, -0.9, 0.0, -10.6, -10.1, "primary", "air dam"),
        bx(4.2, -0.2, 0.0, -10.7, -10.6, "secondary", "bright dam strip"),
        bx(2.8, -0.75, -0.35, -10.66, -10.6, "detail", "dam slot"),
    ]


def chin_splitter():
    """GT3: a dark splitter plate with swept corners and a short bright leading edge, the widest and longest chin. End fences hang under the body side, strakes under the plate."""
    p = [
        bx(3.95, -0.22, 0.0, -11.9, -10.75, "detail", "splitter plate, front"),
        tp(3.95, 5.1, -0.22, 0.0, -11.9, -10.75, "front", "inner", "detail", note="swept splitter corner"),
        bx(5.1, -0.22, 0.0, -10.75, -9.4, "detail", "splitter plate, back"),
        bx(2.4, -0.3, -0.06, -12.05, -11.9, "secondary", "bright leading edge, centre only"),
        box(4.6, 4.85, -0.8, -0.22, -10.5, -9.5, "secondary", True, "end fence, under the body side"),
    ]
    for x in (-1.6, 1.6):
        p.append(box(x - 0.08, x + 0.08, -0.6, -0.22, -11.7, -9.8, "detail", note="strake"))
    return p


# --------------------------------------------------------------------------------------
# RearBumper: valance corners beside the afterburner, diffuser under it
# --------------------------------------------------------------------------------------
def rb_bumperettes():
    return [
        box(3.45, SEAM_X, 0.0, 1.0, TRANSOM, 10.85, "primary", True, "valance corner"),
        box(3.45, 4.95, 0.35, 0.75, 10.85, 11.15, "secondary", True, "bright quarter bumper"),
    ]


def rb_rounded():
    return [
        box(3.45, 5.0, 0.0, 1.0, TRANSOM, 11.5, "primary", True, "body-colour bumper corner"),
        tp(3.45, 5.0, 0.0, 1.0, 11.5, 12.3, "rear", "inner", note="rounded corner"),
        box(3.45, 5.06, 0.4, 0.6, TRANSOM, 11.5, "detail", True, "rubber strip"),
    ]


def kick_up(xh=3.3):
    """Joins a diffuser blade to the valance floor: a ramp down from the floor and a block at the transom."""
    return [
        wuf(-xh, xh, -1.1, -0.3, RA1 + 0.05, 9.8, "detail", note="ramp down from the floor"),
        bx(xh, -1.1, -0.3, 9.8, TRANSOM, "detail", "kick-up block: the blade hangs from this"),
    ]


def rb_diffuser():
    p = [
        bx(4.8, -0.3, 0.0, RA1 + 0.05, TRANSOM, "detail", "diffuser floor, flush with the body side"),
        box(3.45, 5.0, 0.0, 1.0, TRANSOM, 11.5, "primary", True, "valance corner"),
        bx(3.3, -1.1, -0.92, TRANSOM, 12.0, "detail", "short diffuser blade"),
    ] + kick_up()
    for x in (-1.6, 1.6):
        p.append(box(x - 0.08, x + 0.08, -1.45, -1.1, 9.8, 12.0, "detail", note="strake"))
    return p


def rb_overriders():
    return [
        box(3.6, 4.1, 0.0, 1.0, TRANSOM, 10.95, "secondary", True, "bright overrider"),
        box(4.1, SEAM_X, 0.3, 1.0, TRANSOM, 10.7, "primary", True, "quarter filler"),
    ]


def rb_blade():
    """Shooting brake: a bright blade bumper on each corner and a bright step plate tucked straight under the tail, a quarter of a stud below the afterburners."""
    return [
        box(3.45, 4.8, 0.0, 1.0, TRANSOM, 10.9, "primary", True, "valance corner"),
        box(3.45, 5.0, 0.3, 0.7, 10.9, 11.3, "secondary", True, "bright blade bumper"),
        box(3.45, 4.6, BOOST_Y0, 0.0, TRANSOM, 11.3, "secondary", True, "step block, full depth, straight under the valance corner"),
        bx(4.6, -0.47, BOOST_Y0, TRANSOM, 11.5, "secondary", "bright step plate, tucked under the tail"),
    ]


def rb_race():
    """GT3: a flat floor no wider than the body, deep end fences flush with the body side, and a long diffuser blade."""
    p = [
        bx(4.9, -0.3, 0.0, RA1 + 0.05, TRANSOM, "detail", "flat floor, no wider than the body"),
        box(3.45, 4.8, 0.0, 1.0, TRANSOM, 11.4, "detail", True, "deep mesh corner, flush with the body side"),
        box(4.45, 4.8, -1.45, 0.0, TRANSOM, 11.8, "secondary", True, "diffuser end fence, hung from the mesh corner"),
        bx(4.45, -1.1, -0.92, TRANSOM, 12.8, "detail", "long diffuser blade between the fences"),
    ] + kick_up()
    for x in (-2.4, 0.0, 2.4):
        p.append(box(x - 0.08, x + 0.08, -1.48, -1.1, 9.8, 12.8, "secondary", note="long strake"))
    return p


# --------------------------------------------------------------------------------------
# RearSpoiler: stands on the deck pads at Y 3.0, Z 10.0 to 10.6
# --------------------------------------------------------------------------------------
def sp_kamm_lip():
    return [
        wf(-3.65, 3.65, BELT, 3.55, Z_EXT, 10.9, "primary", note="small upturned lip"),
        bx(3.65, 3.55, 3.66, 10.75, 10.9, "secondary", "bright lip edge"),
    ]


def sp_ducktail():
    return [
        wf(-3.65, 3.65, BELT, 4.3, Z_EXT, 12.2, "primary", note="solid ducktail"),
        bx(3.65, 4.3, 4.45, 12.0, 12.2, "detail", "gurney"),
    ]


def sp_blade():
    return [
        box(2.6, 3.4, BELT, 3.95, 10.05, 10.6, "detail", True, "stub pylon"),
        bx(4.9, 3.95, 4.15, Z_EXT, 11.5, "primary", "low wide blade"),
        box(4.7, 4.9, 3.75, 4.35, Z_EXT, 11.7, "detail", True, "blade tip"),
    ]


def sp_fins():
    return [
        wf(2.7, 3.2, BELT, 4.6, Z_EXT, 12.4, "primary", True, "tail fin"),
        box(2.7, 3.2, 4.6, 4.7, 12.1, 12.4, "secondary", True, "fin cap"),
    ]


def sp_rack():
    """Shooting brake: a bright boot rack on four posts with a low lip at its back edge. Needs no roof behind it."""
    return [
        box(3.0, 3.5, BELT, 3.7, 10.05, 10.6, "primary", True, "end post"),
        box(3.0, 3.4, 3.7, 3.95, Z_EXT, 11.5, "secondary", True, "rack side rail"),
        bx(3.0, 3.74, 3.9, 10.35, 10.6, "secondary", "rack slat"),
        wf(-3.6, 3.6, 3.7, 4.3, 11.0, 11.6, "primary", note="low tailgate lip"),
    ]


def sp_swan():
    lean = 27.0
    length = 3.5
    dz, dy = math.sin(math.radians(lean)) * length, math.cos(math.radians(lean)) * length
    return [
        part("block", [0.35, length, 0.6], [3.0, BELT + 0.1 + dy / 2, 10.32 + dz / 2], "detail", [lean, 0, 0], True, "swan-neck upright"),
        box(2.82, 3.18, 6.28, 6.55, 11.4, 12.7, "detail", True, "swan-neck hook over the blade"),
        bx(5.6, 6.0, 6.25, 11.5, 12.8, "secondary", "wing blade"),
        box(5.6, 5.85, 5.25, 6.75, 11.2, 12.88, "primary", True, "end plate"),
        bx(5.6, 6.25, 6.42, 12.62, 12.8, "detail", "gurney"),
    ]


# --------------------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------------------
def mod(name, culture, fn):
    return {"name": name, "culture": culture, "parts": fn(), "note": (fn.__doc__ or "").strip()}


C_CLASSIC, C_SPORTS, C_MODERN, C_ROAD, C_BRAKE, C_GT3 = (
    "Classic GT", "Rear-Engine Sports", "Modern GT", "Roadster", "Shooting Brake", "GT3 Racer")

MODULES = {
    "Engine1": {
        "inline_stack": mod("Inline Stack", C_CLASSIC, engine1_inline),
        "twin_ram": mod("Twin Ram", C_SPORTS, engine1_twin_ram),
        "big_single": mod("Big Single", C_MODERN, engine1_big_single),
        "quad_throttle": mod("Quad Throttle", C_ROAD, engine1_quad),
        "ram_scoop": mod("Ram Scoop", C_BRAKE, engine1_scoop),
        "bonnet_slot": mod("Bonnet Slot", C_GT3, engine1_ram_slot),
    },
    "Engine2": {
        "tail_twin": mod("Tail Twin", C_CLASSIC, engine2_tail_twin),
        "fat_single": mod("Fat Single", C_SPORTS, engine2_boxer),
        "quad_square": mod("Quad Square", C_MODERN, engine2_quad),
        "triple_tube": mod("Triple Tube", C_ROAD, engine2_triple),
        "splay_vee": mod("Splay Vee", C_BRAKE, engine2_vee),
        "slot_vector": mod("Slot Vector", C_GT3, engine2_slot),
    },
    "Stabilisers": {
        "torpedo_lifts": mod("Torpedo Lifts", C_CLASSIC, stab_torpedo),
        "twin_columns": mod("Twin Columns", C_SPORTS, stab_columns),
        "vane_boxes": mod("Vane Boxes", C_MODERN, stab_vane),
        "slant_jets": mod("Slant Jets", C_ROAD, stab_slant),
        "comb_jets": mod("Comb Jets", C_BRAKE, stab_comb),
        "outriggers": mod("Outriggers", C_GT3, stab_outrigger),
    },
    "Boost": {
        "megaphones": mod("Twin Megaphones", C_CLASSIC, boost_megaphones),
        "stacked_twins": mod("Stacked Twins", C_SPORTS, boost_stacked),
        "quad_tips": mod("Quad Tips", C_MODERN, boost_quad_tips),
        "cannon": mod("Single Cannon", C_ROAD, boost_cannon),
        "staged_pairs": mod("Staged Pairs", C_BRAKE, boost_staged),
        "blade_burners": mod("Blade Burners", C_GT3, boost_blades),
    },
    "FrontBody": {
        "torpedo_nose": mod("Torpedo Nose", C_CLASSIC, nose_torpedo),
        "frogeye_nose": mod("Frogeye Nose", C_SPORTS, nose_frogeye),
        "shark_nose": mod("Shark Nose", C_MODERN, nose_shark),
        "clubman_nose": mod("Clubman Nose", C_ROAD, nose_clubman),
        "estate_nose": mod("Square Nose", C_BRAKE, nose_estate),
        "works_nose": mod("Works Nose", C_GT3, nose_works),
    },
    "RearBody": {
        "kamm_tail": mod("Kamm Tail", C_CLASSIC, tail_kamm),
        "wide_hips": mod("Wide Hips", C_SPORTS, tail_hips),
        "muscle_haunch": mod("Muscle Haunch", C_MODERN, tail_muscle),
        "boat_tail": mod("Boat Tail", C_ROAD, tail_boat),
        "estate_tail": mod("Square Tail", C_BRAKE, tail_estate),
        "works_tail": mod("Works Tail", C_GT3, tail_works),
    },
    "SidePods": {
        "chrome_sill": mod("Bright Sill", C_CLASSIC, sill_chrome),
        "scoop_rocker": mod("Scoop Rocker", C_SPORTS, sill_scoop),
        "blade_skirt": mod("Blade Skirt", C_MODERN, sill_blade),
        "nerf_rail": mod("Nerf Rail", C_ROAD, sill_nerf),
        "gill_cladding": mod("Gill Cladding", C_BRAKE, sill_gills),
        "flat_floor": mod("Flat Floor", C_GT3, sill_floor),
    },
    "FrontBumper": {
        "nerf_bar": mod("Nerf Bar", C_CLASSIC, chin_nerf),
        "valance": mod("Valance", C_SPORTS, chin_valance),
        "lip": mod("Lip", C_MODERN, chin_lip),
        "skid_nubs": mod("Skid Nubs", C_ROAD, chin_skid),
        "air_dam": mod("Air Dam", C_BRAKE, chin_dam),
        "splitter": mod("Splitter", C_GT3, chin_splitter),
    },
    "RearBumper": {
        "bumperettes": mod("Quarter Bumpers", C_CLASSIC, rb_bumperettes),
        "rounded": mod("Rounded Corners", C_SPORTS, rb_rounded),
        "diffuser": mod("Diffuser", C_MODERN, rb_diffuser),
        "overriders": mod("Overriders", C_ROAD, rb_overriders),
        "blade_bumper": mod("Blade Bumper", C_BRAKE, rb_blade),
        "race_diffuser": mod("Race Diffuser", C_GT3, rb_race),
    },
    "RearSpoiler": {
        "kamm_lip": mod("Kamm Lip", C_CLASSIC, sp_kamm_lip),
        "ducktail": mod("Ducktail", C_SPORTS, sp_ducktail),
        "active_blade": mod("Active Blade", C_MODERN, sp_blade),
        "twin_fins": mod("Twin Fins", C_ROAD, sp_fins),
        "boot_rack": mod("Boot Rack", C_BRAKE, sp_rack),
        "swan_neck": mod("Swan-Neck Wing", C_GT3, sp_swan),
    },
}

SLOT_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost", "FrontBody", "RearBody", "SidePods",
              "FrontBumper", "RearBumper", "RearSpoiler"]


def kit(name, culture, ids):
    return {"name": name, "culture": culture, "modules": dict(zip(SLOT_ORDER, ids))}


KITS = {
    "classic": kit("Classic", C_CLASSIC, ["inline_stack", "tail_twin", "torpedo_lifts", "megaphones", "torpedo_nose",
                                          "kamm_tail", "chrome_sill", "nerf_bar", "bumperettes", "kamm_lip"]),
    "sports": kit("Sports", C_SPORTS, ["twin_ram", "fat_single", "twin_columns", "stacked_twins", "frogeye_nose",
                                       "wide_hips", "scoop_rocker", "valance", "rounded", "ducktail"]),
    "modern": kit("Modern", C_MODERN, ["big_single", "quad_square", "vane_boxes", "quad_tips", "shark_nose",
                                       "muscle_haunch", "blade_skirt", "lip", "diffuser", "active_blade"]),
    "club": kit("Clubman", C_ROAD, ["quad_throttle", "triple_tube", "slant_jets", "cannon", "clubman_nose",
                                    "boat_tail", "nerf_rail", "skid_nubs", "overriders", "twin_fins"]),
    "estate": kit("Estate", C_BRAKE, ["ram_scoop", "splay_vee", "comb_jets", "staged_pairs", "estate_nose",
                                      "estate_tail", "gill_cladding", "air_dam", "blade_bumper", "boot_rack"]),
    "gt3": kit("GT3", C_GT3, ["bonnet_slot", "slot_vector", "outriggers", "blade_burners", "works_nose",
                              "works_tail", "flat_floor", "splitter", "race_diffuser", "swan_neck"]),
}

COCKPITS = {
    "longnose": {"name": "Longnose", "culture": C_CLASSIC, "kit": "classic", "parts": cockpit_longnose(),
                 "note": cockpit_longnose.__doc__},
    "teardrop": {"name": "Teardrop", "culture": C_SPORTS, "kit": "sports", "parts": cockpit_teardrop(),
                 "note": cockpit_teardrop.__doc__},
    "bruiser": {"name": "Bruiser", "culture": C_MODERN, "kit": "modern", "parts": cockpit_bruiser(),
                "note": cockpit_bruiser.__doc__},
    "roadster": {"name": "Roadster", "culture": C_ROAD, "kit": "club", "parts": cockpit_roadster(),
                 "note": cockpit_roadster.__doc__},
    "brake": {"name": "Brake", "culture": C_BRAKE, "kit": "estate", "parts": cockpit_brake(),
              "note": cockpit_brake.__doc__},
    "gullwing": {"name": "Gullwing", "culture": C_GT3, "kit": "gt3", "parts": cockpit_gullwing(),
                 "note": cockpit_gullwing.__doc__},
}

PAINT = {
    "longnose": {"primary": "#0d5c3a", "secondary": "#dcd6c6", "neon": "#ffe9a8"},
    "teardrop": {"primary": "#e8b21e", "secondary": "#2a2c31", "neon": "#fff6d8"},
    "bruiser": {"primary": "#2c4a86", "secondary": "#c7ccd3", "neon": "#8fe6ff"},
    "roadster": {"primary": "#b8231c", "secondary": "#e7e1d2", "neon": "#fff0bd"},
    "brake": {"primary": "#6b2233", "secondary": "#d9d2c0", "neon": "#ffd27a"},
    "gullwing": {"primary": "#9aa2ab", "secondary": "#d2202f", "neon": "#a8f4ff"},
}

SWAP = {"longnose": "gt3", "teardrop": "modern", "bruiser": "estate", "roadster": "sports",
        "brake": "classic", "gullwing": "club"}

BUILDS = []
for cid, c in COCKPITS.items():
    BUILDS.append({"name": "%s, own %s kit" % (c["name"], KITS[c["kit"]]["name"]), "cockpit": cid, "kit": c["kit"],
                   "paint": PAINT[cid]})
for cid, c in COCKPITS.items():
    BUILDS.append({"name": "%s in the %s kit" % (c["name"], KITS[SWAP[cid]]["name"]), "cockpit": cid, "kit": SWAP[cid],
                   "paint": PAINT[cid]})
BUILDS += [
    {"name": "Mixed: Longnose club racer", "cockpit": "longnose", "kit": "classic",
     "modules": {"Engine1": "big_single", "Stabilisers": "outriggers", "FrontBumper": "splitter",
                 "RearSpoiler": "swan_neck", "Boost": "blade_burners", "SidePods": "flat_floor"},
     "paint": {"primary": "#1f2a44", "secondary": "#f0b323", "neon": "#ffe9a8"}},
    {"name": "Mixed: Teardrop outlaw", "cockpit": "teardrop", "kit": "sports",
     "modules": {"FrontBody": "works_nose", "RearBody": "works_tail", "Engine2": "triple_tube",
                 "Boost": "cannon", "RearSpoiler": "active_blade", "FrontBumper": "lip"},
     "paint": {"primary": "#d8dadd", "secondary": "#e2571c", "neon": "#ffffff"}},
    {"name": "Mixed: Brake street sleeper", "cockpit": "brake", "kit": "modern",
     "modules": {"Engine1": "ram_scoop", "Stabilisers": "comb_jets", "RearSpoiler": "boot_rack",
                 "Boost": "megaphones", "RearBody": "estate_tail"},
     "paint": {"primary": "#23262b", "secondary": "#b8964a", "neon": "#ff5a3c"}},
]

SPEC = {
    "id": "gt",
    "displayName": "GT",
    "tagline": "Front-engined sports cars and grand tourers as hover jets: a turbine in the bonnet, a turbine standing through the tail deck, a lift jet in every arch.",
    "standard": STANDARD,
    "cockpits": COCKPITS,
    "kits": KITS,
    "modules": MODULES,
    "builds": BUILDS,
}


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(SPEC, f, indent=1)
    n_mod = sum(len(v) for v in MODULES.values())
    print("wrote %s: %d cockpits, %d kits, %d modules, %d builds" % (OUT, len(COCKPITS), len(KITS), n_mod, len(BUILDS)))


if __name__ == "__main__":
    main()
