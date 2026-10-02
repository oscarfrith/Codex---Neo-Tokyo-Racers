"""Generator for the Hauler frame-class blockout spec (round 2, after critic review). Design exploration only.

Run from the repo root:
  py -3 scripts/vehicle_blockouts/gen/hauler.py
Writes scripts/vehicle_blockouts/specs/hauler.json. Then run preview.py on that file.

Root space: +X right, +Y up, forward is -Z. Units are studs.
Every module is built for the +X side and mirrored, so `m=True` means "and the same on the left".
"""
import json
import math
import os

# ----------------------------------------------------------------------------- datums
SILL = 0.4      # frame top; body undersides start at 0.5
DECK = 2.0      # bed floor top (Engine2 pad), arch underside, Side Gear top
BELT = 3.6      # hood top (Engine1 pad), cowl deck, cab belt, floor of a forward cab pod
STRIPE = (2.9, 3.3)   # accent stripe band shared by cabs, clips and beds
ROOF = 7.4      # roof pad top on every cab
FLOOR = -0.8    # nothing but Lift Jets goes below this
FZ, RZ = -10.5, 9.5   # front and rear axle beams (Lift Jet centres)
NOSE, TAIL = -14.0, 14.0
CAB_F, CAB_R = -6.0, 3.0   # cab seams
TUN_X, TUN_TOP = 2.0, 6.2  # engine trench half-width and top (Engine1 envelope). Nothing may roof it
POD_Z = -10.4              # front face of a forward cab pod; the cowl deck runs from here to the cab seam
COWL_X = 4.1               # half-width of the cowl deck every Front Clip presents at the belt
ROOF_PAD = (-2.4, 2.4, -4.4, -2.6)   # x0, x1, z0, z1 at Y 7.4
ACC_PAD_Z = (-5.0, -4.2)             # accessory stand-off on every cab at belt height


# ----------------------------------------------------------------------------- part helpers
def _r(v):
    return [round(float(a), 3) for a in v]


def part(shape, size, pos, ch="primary", rot=None, m=False, note=None):
    d = {"shape": shape, "size": _r(size), "pos": _r(pos), "ch": ch}
    if rot and any(abs(a) > 1e-6 for a in rot):
        d["rot"] = _r(rot)
    if m:
        d["mirror"] = True
    if note:
        d["note"] = note
    return d


def box(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None):
    """Axis-aligned block from its extents."""
    return part("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, None, m, note)


def wedge(x0, x1, y0, y1, z0, z1, ch="primary", thin="front", flip=False, m=False, note=None):
    """Wedge filling the given extents. `thin` is where the sharp edge points:
    front (-Z), back (+Z), out (+X) or in (-X). flip=True puts the slope underneath."""
    dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
    if thin in ("front", "back"):
        size, ry = [dx, dy, dz], (0 if thin == "front" else 180)
    else:
        size, ry = [dz, dy, dx], (-90 if thin == "out" else 90)
    return part("wedge", size, [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, [0, ry, 180 if flip else 0], m, note)


def cylz(d, x, y, z0, z1, ch="detail", m=False, note=None):
    return part("cyl_z", [d, d, z1 - z0], [x, y, (z0 + z1) / 2], ch, None, m, note)


def cyly(d, x, y0, y1, z, ch="detail", m=False, note=None):
    return part("cyl_y", [d, y1 - y0, d], [x, (y0 + y1) / 2, z], ch, None, m, note)


def cylx(d, x0, x1, y, z, ch="detail", m=False, note=None):
    return part("cyl_x", [x1 - x0, d, d], [(x0 + x1) / 2, y, z], ch, None, m, note)


def ball(d, x, y, z, ch="detail", m=False, note=None):
    return part("ball", [d, d, d], [x, y, z], ch, None, m, note)


def strut(p0, p1, t, ch="detail", m=False, round_=False, note=None):
    """A bar of thickness t from p0 to p1 (any direction)."""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    rx = -math.degrees(math.asin(dy / length))
    ry = math.degrees(math.atan2(dx, dz))
    pos = [(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2]
    return part("cyl_z" if round_ else "block", [t, t, length], pos, ch, [rx, ry, 0], m, note)


def up_stack(d, x, y0, y1, z, m=False, jet=None, glow=0.35):
    """An up-turned nozzle ending in a glowing jet. It fires upward, clear of the cab and the screen."""
    jet = jet if jet is not None else d - 0.25
    return [cyly(d, x, y0, y1 - glow, z, "detail", m=m, note="up-turned nozzle"),
            cyly(jet, x, y1 - glow, y1, z, "thrust", m=m, note="jet: fires up, clear of the cab")]


# ----------------------------------------------------------------------------- frame standard
def standard():
    return {
        "cockpitEnvelope": [
            {"min": [-4.2, SILL, CAB_F], "max": [4.2, 7.6, CAB_R]},                       # cab
            {"min": [2.2, BELT, POD_Z - 0.2], "max": [4.2, 7.6, CAB_F], "mirror": True},   # forward pods, standing on the cowl deck
            {"min": [-2.2, BELT, -6.8], "max": [2.2, 7.6, CAB_F]},                         # trench back wall (no roof over the trench)
            {"min": [-3.4, FLOOR, NOSE], "max": [3.4, SILL, TAIL]},                        # ladder frame
        ],
        "datums": {"beltline": BELT, "sill": SILL, "hoverPlane": -2.5, "deck": DECK, "roof": ROOF,
                   "bodyFloor": FLOOR, "frontAxleZ": FZ, "rearAxleZ": RZ, "stripe": list(STRIPE)},
        "slots": {
            "FrontBody": {"label": "Front Clip",
                          "envelope": [{"min": [-4.4, SILL, NOSE], "max": [4.4, BELT, CAB_F]},
                                       {"min": [4.4, DECK, NOSE], "max": [6.8, BELT, CAB_F], "mirror": True}],
                          "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -7]},
            "RearBody": {"label": "Bed",
                         "envelope": [{"min": [-4.4, SILL, CAB_R], "max": [4.4, DECK, TAIL]},              # floor
                                      {"min": [-4.4, DECK, CAB_R], "max": [4.4, 7.0, 4.0]},               # headboard
                                      {"min": [3.2, DECK, 4.0], "max": [4.4, 7.0, TAIL], "mirror": True},  # side walls
                                      {"min": [-3.2, 6.0, 4.0], "max": [3.2, 7.0, TAIL]},                 # canopy
                                      {"min": [4.4, DECK, 4.8], "max": [6.8, 3.0, TAIL], "mirror": True}],  # shoulders
                         "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 0, 8]},
            "Engine1": {"label": "Hood Engine",
                        "envelope": {"min": [-TUN_X, BELT, -13.8], "max": [TUN_X, TUN_TOP, -6.8]},
                        "anchor": {"to": "FrontBody", "face": "-y"}, "explode": [0, 6, -9]},
            "Engine2": {"label": "Bed Engine",
                        "envelope": {"min": [-3.2, DECK, 4.0], "max": [3.2, 6.0, TAIL]},
                        "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 7, 11]},
            "Stabilisers": {"label": "Lift Jets",
                            "envelope": [{"min": [3.4, -2.4, -13.6], "max": [7.0, SILL, -7.4], "mirror": True},
                                         {"min": [4.4, SILL, -13.6], "max": [7.0, DECK, -7.4], "mirror": True},
                                         {"min": [3.4, -2.4, 6.4], "max": [7.0, SILL, 12.6], "mirror": True},
                                         {"min": [4.4, SILL, 6.4], "max": [7.0, DECK, 12.6], "mirror": True}],
                            "anchor": {"to": "cockpit", "face": "-x"}, "explode": [5, -4, 0]},
            "Boost": {"label": "Stacks",
                      "envelope": [{"min": [4.4, FLOOR, CAB_R], "max": [6.6, 9.8, 4.8], "mirror": True},   # stack bay
                                   {"min": [4.4, FLOOR, 4.8], "max": [6.6, DECK, 6.2], "mirror": True},    # dump bay
                                   {"min": [3.3, DECK, TAIL], "max": [5.6, 3.4, 16.2], "mirror": True}],   # flank ports, clear of the Bed Engine column
                      "anchor": {"to": "RearBody", "face": "-z"}, "explode": [4, 3, 13]},
            "SidePods": {"label": "Side Gear",
                         "envelope": {"min": [4.2, FLOOR, -5.8], "max": [6.6, DECK, 2.8], "mirror": True},
                         "anchor": {"to": "cockpit", "face": "-x"}, "explode": [5, -1, 0]},
            "FrontBumper": {"label": "Front Bar",
                            "envelope": {"min": [-6.8, FLOOR, -16.0], "max": [6.8, 4.6, NOSE]},
                            "anchor": {"to": "FrontBody", "face": "+z"}, "explode": [0, 0, -13]},
            "RearBumper": {"label": "Rear Bar",
                           "envelope": {"min": [-6.8, FLOOR, TAIL], "max": [6.8, 1.8, 16.0]},
                           "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, -4, 13]},
            "RearSpoiler": {"label": "Bed Rig",
                            "envelope": [{"min": [4.4, 3.0, 4.8], "max": [5.4, 9.2, TAIL], "mirror": True},   # legs
                                         {"min": [-4.4, 7.2, 4.8], "max": [4.4, 9.2, TAIL]}],                # overhead
                            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 9, 9]},
            "Roof": {"label": "Roof Rig",
                     "envelope": {"min": [-4.2, 7.6, CAB_F], "max": [4.2, 9.6, CAB_R]},
                     "anchor": {"to": "cockpit", "face": "-y"}, "explode": [0, 5, 0]},
            "Accessory": {"label": "Extras",
                          "envelope": {"min": [4.2, DECK, -5.8], "max": [5.8, 9.8, 2.8], "mirror": True},
                          "anchor": {"to": "cockpit", "face": "-x"}, "explode": [6, 3, 0]},
        },
    }


# ----------------------------------------------------------------------------- shared chassis (every cab)
def chassis():
    return [
        box(1.95, 2.65, -0.15, 0.35, -11.4, 10.4, "detail", m=True, note="ladder frame rail: the same in every cab, reaches both axles"),
        cylx(0.7, -3.35, 3.35, -0.2, FZ, "detail", note="front axle beam: Lift Jets hang on its ends"),
        cylx(0.7, -3.35, 3.35, -0.2, RZ, "detail", note="rear axle beam"),
        box(-3.35, 3.35, 0.05, 0.35, -4.95, -4.25, "detail", note="cab mount crossmember"),
        box(-3.35, 3.35, 0.05, 0.35, 2.05, 2.75, "detail", note="cab mount crossmember"),
    ]


def seam_plates(w=3.0):
    return [
        box(-w, w, 0.9, 3.3, -5.98, -5.8, "detail", note="front linkage plate in the shadow gap"),
        box(-w, w, 0.9, 3.0, 2.8, 2.98, "detail", note="rear linkage plate in the shadow gap"),
    ]


def driver(x, z, seat_y=3.6, hide_torso=False):
    """Seated driver. Torso 1.9 tall, head on top."""
    out = [box(x - 0.8, x + 0.8, seat_y, seat_y + 1.9, z - 0.45, z + 0.45, "driver", note="seated torso"),
           ball(1.15, x, seat_y + 2.45, z, "driver", note="head")]
    if not hide_torso:
        out.append(box(x - 0.5, x + 0.5, seat_y + 0.95, seat_y + 1.15, z - 1.5, z - 1.3, "detail", note="steering yoke"))
    return out


# ----------------------------------------------------------------------------- cockpits
def cab_single():
    """Prerunner. Short two-seat cab pushed to the front with a chopped roof. Behind it an open pack: fuel cell, cans, roll hoop."""
    p = chassis() + seam_plates()
    p += [
        box(-3.8, 3.8, 0.5, BELT, -5.8, -1.6, "primary", note="doors and lower cab"),
        box(-3.86, 3.86, STRIPE[0], STRIPE[1], -5.78, -1.62, "secondary", note="stripe on the shared stripe datum"),
        box(-3.8, 3.8, BELT, 4.1, -5.8, -1.6, "primary", note="window sill"),
        wedge(-3.4, 3.4, 4.1, 6.3, -5.6, -4.4, "glass", "front", note="upright, chopped windscreen"),
        box(-3.4, 3.4, 4.1, 6.3, -4.4, -2.2, "glass"),
        box(-3.7, 3.7, 4.1, 6.3, -2.2, -1.6, "primary", note="cab back panel"),
        box(-3.7, 3.7, 6.3, 6.8, -4.8, -1.6, "primary", note="chopped roof"),
        box(ROOF_PAD[0], ROOF_PAD[1], 6.8, ROOF, ROOF_PAD[2], ROOF_PAD[3], "detail", note="roof pad riser to Y 7.4"),
        strut((3.55, 4.1, -5.6), (3.55, 6.3, -4.4), 0.35, "primary", m=True, note="A-pillar"),
        # behind the cab: open pack with a fuel cell and a roll hoop
        box(-3.8, 3.8, 0.5, 1.0, -1.6, 2.8, "detail", note="pack tray: keeps the Side Gear seam closed behind the short cab"),
        box(-2.4, 2.4, 1.0, 2.6, -1.1, 2.8, "detail", note="fuel cell: reaches the Bed seam"),
        box(-1.9, 1.9, 2.6, 3.4, -0.6, 1.2, "secondary", note="jerry cans"),
        box(2.9, 3.4, 1.0, 7.2, 1.9, 2.4, "detail", m=True, note="roll hoop"),
        box(-3.4, 3.4, 6.75, 7.2, 1.9, 2.4, "detail"),
        strut((3.15, 6.9, 1.9), (3.15, 3.9, -1.4), 0.35, "detail", m=True, note="hoop brace"),
        box(0.9, 2.9, 3.1, 5.6, -2.6, -2.25, "detail", m=True, note="seat backs"),
        box(3.8, 4.12, 3.2, BELT, ACC_PAD_Z[0], ACC_PAD_Z[1], "detail", m=True, note="Extras pad"),
        box(3.8, 4.05, 0.5, 0.9, -5.8, 2.8, "detail", m=True, note="sill step: reaches the Side Gear seam"),
    ]
    return p + driver(-1.9, -3.2, seat_y=3.3)


def cab_crew():
    """Lifted. Long four-door. Raked screen, then a flat roof all the way back to an upright rear panel. Three side windows."""
    p = chassis() + seam_plates()
    p += [
        box(-4.1, 4.1, 0.5, BELT, -5.8, 2.8, "primary", note="four doors"),
        box(-4.16, 4.16, STRIPE[0], STRIPE[1], -5.78, 2.78, "secondary", note="stripe"),
        box(-4.1, 4.1, BELT, 4.1, -5.8, 2.8, "primary", note="window sill"),
        wedge(-3.7, 3.7, 4.1, 6.9, -5.7, -3.2, "glass", "front", note="raked windscreen"),
        box(-3.7, 3.7, 4.1, 6.9, -3.2, 2.3, "glass", note="long glasshouse"),
        box(-4.0, 4.0, 4.1, 6.9, 2.3, 2.8, "primary", note="upright rear panel"),
        box(-2.8, 2.8, 4.7, 6.4, 2.8, 2.86, "glass", note="rear screen"),
        box(-4.0, 4.0, 6.9, ROOF, -4.4, 2.8, "primary", note="flat roof to the back of the cab"),
        wedge(-4.0, 4.0, 6.9, ROOF, -5.3, -4.4, "secondary", "front", note="visor"),
        strut((3.85, 4.1, -5.7), (3.85, 6.9, -3.2), 0.35, "primary", m=True, note="A-pillar"),
        box(3.7, 4.0, 4.1, 6.9, -1.6, -1.1, "primary", m=True, note="B-pillar"),
        box(3.7, 4.0, 4.1, 6.9, 0.5, 1.0, "primary", m=True, note="C-pillar: three side windows"),
        box(3.3, 3.8, ROOF, 7.58, -3.6, 2.6, "detail", m=True, note="roof rails"),
        box(0.9, 2.9, 3.1, 5.9, -1.9, -1.5, "detail", m=True, note="front seats"),
        box(-2.9, 2.9, 3.1, 5.7, 1.2, 1.6, "detail", note="rear bench"),
        box(4.1, 4.16, 0.8, BELT, -1.4, -1.25, "detail", m=True, note="door gap"),
        box(4.1, 4.16, 0.8, BELT, 0.7, 0.85, "detail", m=True, note="door gap"),
    ]
    return p + driver(-1.9, -2.6)


def cab_kei():
    """Minitruck. A tiny upright bubble cab, narrow above the belt, tipped forward to the trench wall. Behind it a long drop-side tray with a load."""
    p = chassis() + seam_plates()
    p += [
        box(-3.8, 3.8, 0.5, BELT, -5.8, -2.6, "primary", note="lower cab: the same width as the tray"),
        box(-3.86, 3.86, STRIPE[0], STRIPE[1], -5.78, -2.62, "secondary", note="stripe"),
        box(-3.8, 3.8, 0.5, 2.3, -2.6, 2.8, "primary", note="tray: reaches the Bed seam"),
        box(-3.3, 3.3, 2.3, 2.5, -2.6, 2.8, "secondary", note="tray deck"),
        box(3.3, 3.8, 2.3, 3.0, -2.6, 2.8, "primary", m=True, note="drop-side"),
        box(-3.3, 3.3, 2.5, 3.0, 2.5, 2.8, "primary", note="tail board"),
        box(3.8, 4.05, 0.5, 0.9, -5.8, 2.8, "detail", m=True, note="sill step: reaches the Side Gear seam"),
        box(3.8, 4.12, 3.2, BELT, ACC_PAD_Z[0], ACC_PAD_Z[1], "detail", m=True, note="Extras pad"),
        # narrow cab above the belt
        box(-3.2, 3.2, BELT, 4.3, -6.75, -2.6, "primary", note="cab shoulder: narrower than the lower body"),
        box(-3.0, 3.0, 4.3, 6.6, -6.7, -3.2, "glass", note="bubble glasshouse"),
        box(-3.2, 3.2, 4.3, 6.6, -3.2, -2.6, "primary", note="back panel"),
        box(-3.2, 3.2, 6.6, 7.0, -6.75, -2.6, "primary", note="roof"),
        box(-3.26, 3.26, 6.6, 6.9, -6.8, -6.3, "secondary", note="brow band over the screen"),
        box(ROOF_PAD[0], ROOF_PAD[1], 7.0, ROOF, ROOF_PAD[2], ROOF_PAD[3], "detail", note="roof pad riser to Y 7.4"),
        box(3.0, 3.2, 4.3, 6.6, -6.75, -6.45, "primary", m=True, note="corner post"),
        box(3.0, 3.2, 4.3, 6.6, -4.7, -4.4, "primary", m=True, note="door post"),
        # load on the tray
        box(-2.7, -0.5, 2.5, 3.9, -2.2, 0.0, "detail", note="crate on the tray"),
        box(0.1, 2.7, 2.5, 3.4, -1.9, 1.5, "secondary", note="parcels on the tray"),
        box(-2.4, -0.8, 2.5, 3.2, 0.6, 2.0, "secondary", note="small box"),
    ]
    return p + driver(-1.3, -4.9, seat_y=3.75, hide_torso=True)


def cab_over():
    """Show Truck. Twin pods. A driver pod and a passenger pod stand forward on the cowl, either side of an open engine trench. They join at a sleeper box behind it."""
    p = chassis() + seam_plates()
    p += [
        box(-4.1, 4.1, 0.5, BELT, -5.8, 2.8, "primary", note="lower cab and pack"),
        box(-4.16, 4.16, STRIPE[0], STRIPE[1], -5.78, 2.78, "secondary", note="stripe"),
        # twin pods, X 2.2..4.1 each side: nothing between them, nothing over the trench
        box(2.2, 4.1, BELT, 5.4, POD_Z, CAB_F, "primary", m=True, note="pod body: stands on the cowl deck beside the open engine trench"),
        box(2.6, 3.7, 4.0, 4.8, POD_Z - 0.1, POD_Z, "neon", m=True, note="headlamp"),
        box(2.2, 4.14, 5.15, 5.4, POD_Z - 0.06, -5.9, "secondary", m=True, note="chrome waist rail"),
        box(2.4, 3.9, 5.4, 7.0, POD_Z + 0.1, -7.4, "glass", m=True, note="pod glass: screen, door and a window on the trench"),
        box(2.2, 4.1, 5.4, 7.0, -7.4, CAB_F, "primary", m=True, note="pod back"),
        box(3.9, 4.1, 5.4, 7.0, POD_Z, POD_Z + 0.3, "primary", m=True, note="outer corner post"),
        box(2.2, 2.4, 5.4, 7.0, POD_Z, POD_Z + 0.3, "primary", m=True, note="inner corner post"),
        box(2.2, 4.1, 7.0, ROOF, POD_Z, CAB_F, "primary", m=True, note="pod roof"),
        box(2.2, 4.14, 7.0, 7.3, POD_Z - 0.1, POD_Z + 0.5, "secondary", m=True, note="chrome visor"),
        # sleeper: the only part that spans the trench line, and it starts behind the trench
        box(-4.1, 4.1, BELT, 7.0, CAB_F, -2.4, "primary", note="sleeper box: joins the two pods behind the trench"),
        box(-2.15, 2.15, BELT, 6.2, -6.75, CAB_F, "detail", note="trench back wall: heat shield"),
        box(-1.8, 1.8, 6.2, 6.9, -6.1, CAB_F, "glass", note="sleeper window, looking down the trench"),
        box(4.1, 4.16, 5.8, 6.6, -5.2, -3.2, "glass", m=True, note="sleeper side window"),
        box(-4.1, 4.1, 7.0, ROOF, CAB_F, -2.4, "primary", note="sleeper roof: roof pad at Y 7.4"),
        wedge(-4.1, 4.1, 5.6, ROOF, -2.4, -1.4, "secondary", "back", note="chrome roof fairing"),
        cylz(1.5, 2.2, 4.4, -1.2, 2.3, "secondary", m=True, note="chrome air tank on the deck behind the sleeper"),
        box(-1.2, 1.2, BELT, 4.6, -2.0, 2.3, "detail", note="battery box"),
        box(-3.9, 3.9, BELT, 5.6, 2.45, 2.8, "detail", note="headache plate"),
    ]
    return p + driver(-3.15, -8.9, seat_y=3.75, hide_torso=True)


def cab_checker():
    """Cab. Three-box saloon set back behind a long cowl: upright screen, tall hat roof with a crown, then a low boot deck. The checker band is built into the belt."""
    p = chassis() + seam_plates()
    p += [
        box(-3.8, 3.8, 0.5, BELT, -5.8, 2.8, "primary", note="lower body"),
        box(-3.86, 3.86, 2.6, 3.4, -5.78, 2.78, "secondary", note="checker band, built into the belt"),
    ]
    for i in range(5):
        z = -5.6 + 1.6 * i
        y0 = 3.0 if i % 2 == 0 else 2.6
        p.append(box(3.86, 3.93, y0, y0 + 0.4, z, z + 1.6, "detail", m=True, note="checker"))
    p += [
        box(-3.4, 3.4, BELT, 4.1, -4.4, 0.6, "primary", note="window sill (the cowl ahead stays at the belt)"),
        box(-3.0, 3.0, 4.1, 6.9, -4.3, -0.4, "glass", note="upright glasshouse"),
        box(3.0, 3.25, 4.1, 6.9, -4.4, -4.1, "primary", m=True, note="upright A-pillar"),
        box(3.0, 3.25, 4.1, 6.9, -2.4, -2.0, "primary", m=True, note="B-pillar"),
        box(-3.1, 3.1, 4.1, 6.9, -0.4, 0.6, "primary", note="formal C-pillar"),
        box(3.1, 3.16, 4.9, 6.2, -0.2, 0.4, "glass", m=True, note="opera window"),
        box(-3.3, 3.3, 6.9, ROOF, -4.6, 0.7, "primary", note="hat roof: pad at Y 7.4"),
        box(-2.3, 2.3, ROOF, 7.6, -2.5, 0.3, "primary", note="roof crown"),
        box(-3.5, 3.5, BELT, 4.6, 0.6, 2.75, "primary", note="boot deck: the third box"),
        box(-3.3, 3.3, 4.6, 4.85, 2.5, 2.75, "secondary", note="boot lip"),
        box(0.7, 2.6, 3.1, 5.8, -2.3, -1.9, "detail", m=True, note="front seats"),
        box(-2.7, 2.7, 4.1, 5.3, -1.6, -1.4, "detail", note="fare partition"),
        box(-2.6, 2.6, 3.1, 5.6, -0.9, -0.5, "detail", note="fare bench"),
        box(3.8, 4.12, 3.2, BELT, ACC_PAD_Z[0], ACC_PAD_Z[1], "detail", m=True, note="Extras pad"),
        box(3.8, 4.05, 0.5, 0.9, -5.8, 2.8, "detail", m=True, note="sill step: reaches the Side Gear seam"),
    ]
    return p + driver(-1.7, -2.9)


def cab_van():
    """Courier. One-box van. Two nose sails carry the screen line down to the cowl, either side of the trench. Big raked screen under a roof brow, high roof, blank panel sides with one door window."""
    p = chassis() + seam_plates()
    p += [
        box(-4.1, 4.1, 0.5, BELT, -5.8, 2.8, "primary", note="lower body"),
        box(-4.16, 4.16, STRIPE[0], STRIPE[1], -5.78, 2.78, "secondary", note="stripe"),
        wedge(3.4, 4.1, BELT, 4.6, -9.6, -6.7, "primary", "front", m=True, note="nose sail: a slim buttress that runs the screen line down to the cowl"),
        box(3.4, 4.1, BELT, 4.6, -6.7, CAB_F, "primary", m=True, note="sail root"),
        box(-4.1, 4.1, BELT, 4.6, CAB_F, 2.8, "primary", note="body side below the glass line"),
        box(-2.15, 2.15, BELT, 4.6, -6.75, CAB_F, "detail", note="trench back wall: heat shield"),
        wedge(-3.5, 3.5, 4.6, 7.2, -6.7, -3.8, "glass", "front", note="big raked windscreen"),
        strut((3.6, 4.6, -6.7), (3.6, 7.2, -3.8), 0.3, "primary", m=True, note="A-pillar"),
        box(-3.7, 3.7, 4.6, 7.2, -3.8, 2.8, "primary", note="high body: blank panel sides, a little narrower than the belt"),
        box(3.7, 3.76, 5.0, 6.8, -3.6, -1.7, "glass", m=True, note="door window"),
        box(-3.7, 3.7, 7.2, ROOF, -4.4, 2.8, "primary", note="high roof with a brow over the screen: roof pad at Y 7.4"),
        box(4.1, 4.16, 0.8, 4.5, -1.5, -1.38, "detail", m=True, note="sliding door gap"),
        box(3.7, 3.82, 4.7, 4.85, -1.4, 2.6, "detail", m=True, note="sliding door rail"),
        box(0.9, 2.9, 3.1, 5.9, -3.3, -2.9, "detail", m=True, note="seat backs"),
    ]
    return p + driver(-1.9, -4.3, seat_y=3.6)


# ----------------------------------------------------------------------------- FrontBody (Front Clip)
def clip_back(y0=0.8, w=3.6):
    return [box(-w, w, y0, 3.2, -6.2, -6.02, "detail", note="rear linkage plate in the shadow gap")]


def horns(y1=1.25):
    """The Front Bar pad: two horns at the same place on every clip."""
    return [box(1.9, 2.7, 0.55, y1, -13.9, -13.1, "detail", m=True, note="bumper horn: the Front Bar pad, the same on every clip")]


def fb_flare_nose():
    """Prerunner: a thin shell held high over the bare frame. Fenders slope from the cowl deck to a beak, a skid plate rises under it, wide flares cover the lift jets."""
    return clip_back(2.6) + horns(2.6) + [
        box(-2.1, 2.1, 2.6, BELT, -13.4, -6.25, "primary", note="hood spine: Engine1 pad at Y 3.6"),
        box(2.1, 4.3, 2.6, BELT, POD_Z, -6.25, "primary", m=True, note="cowl deck: flat at the belt, a forward cab pod stands here"),
        wedge(2.1, 4.3, 2.6, BELT, -13.6, POD_Z, "primary", "front", m=True, note="fender slopes to a point at the nose"),
        part("block", [5.2, 0.16, 5.0], [0, 1.45, -10.6], "secondary", [17.5, 0, 0], note="skid plate rising from the frame to the nose"),
        strut((2.3, 0.7, -7.6), (2.3, 2.5, -12.6), 0.3, "detail", m=True, round_=True, note="tube brace under the shell"),
        box(1.9, 2.7, 0.5, 2.6, -7.4, -6.6, "detail", m=True, note="shell mount on the frame rail"),
        box(-2.0, 2.0, 2.75, 3.45, -13.56, -13.4, "detail", note="mesh grille"),
        box(0.8, 1.8, 2.85, 3.3, -13.66, -13.56, "neon", m=True, note="lamp in the grille"),
        box(4.4, 6.75, 2.6, 3.2, -12.4, -7.6, "primary", m=True, note="wide flare over the lift jet"),
        wedge(4.4, 6.75, 2.6, 3.2, -13.6, -12.4, "primary", "front", m=True),
        wedge(4.4, 6.75, 2.6, 3.2, -7.6, -6.3, "primary", "back", m=True),
        box(6.35, 6.75, 2.1, 2.6, -12.4, -7.6, "detail", m=True, note="flare lip"),
        box(4.3, 4.38, STRIPE[0], STRIPE[1], POD_Z, -6.25, "secondary", m=True, note="stripe"),
    ]


def fb_square_body():
    """Lifted: tall square box carried high on body-lift blocks, daylight underneath, squared arch brows."""
    return clip_back(1.7) + horns(1.7) + [
        box(-4.3, 4.3, 1.7, BELT, -13.2, -6.25, "primary", note="square nose carried high: Engine1 pad and cowl deck at Y 3.6"),
        box(1.9, 2.7, 0.5, 1.7, -8.0, -6.9, "detail", m=True, note="body-lift block on the frame rail"),
        box(-4.36, 4.36, 1.75, 3.45, -13.6, -13.2, "secondary", note="grille shell"),
        box(-2.6, 2.6, 2.0, 3.2, -13.7, -13.6, "detail", note="grille"),
        box(3.0, 4.1, 2.4, 3.2, -13.7, -13.6, "neon", m=True, note="square lamp"),
        box(4.4, 5.9, 3.0, 3.55, -13.2, -7.8, "primary", m=True, note="square arch brow"),
        box(4.4, 5.9, 2.05, 3.0, -13.6, -13.2, "primary", m=True),
        box(4.4, 5.9, 2.05, 3.0, -7.8, -7.4, "primary", m=True),
        box(4.3, 4.38, STRIPE[0], STRIPE[1], -13.2, -6.25, "secondary", m=True, note="stripe"),
    ]


def fb_smoothie():
    """Minitruck: low droop-snoot. A narrow body and a long thin prow that stands well forward of the corners. The hood falls away from a wide cowl deck. No arches."""
    return clip_back(0.8, 3.0) + horns() + [
        box(-3.2, 3.2, 0.5, 1.8, -12.6, -6.25, "primary", note="smooth lower body, narrower than the other clips"),
        box(-2.4, 2.4, 0.5, 1.8, -13.7, -12.6, "primary", note="prow: stands forward of the corners"),
        box(-3.2, 3.2, 1.8, BELT, POD_Z, -6.25, "primary", note="cowl deck: flat at the belt"),
        wedge(-3.2, 3.2, 1.8, BELT, -12.6, POD_Z, "primary", "front", note="hood falls away to the nose"),
        box(3.2, COWL_X, 2.8, BELT, POD_Z, -6.25, "primary", m=True, note="cowl wing: a thin shelf that flares out to the cab width, daylight under it"),
        box(-2.0, 2.0, 1.8, 3.05, -13.5, POD_Z, "primary", note="hood spine"),
        box(-2.0, 2.0, 3.05, BELT, -12.2, POD_Z, "primary", note="hood spine: Engine1 pad at Y 3.6"),
        wedge(-2.0, 2.0, 3.05, BELT, -13.5, -12.2, "primary", "front"),
        box(-2.2, 2.2, 1.3, 1.5, -13.78, -13.7, "neon", note="slim lamp strip on the prow"),
        box(2.5, 3.1, 0.9, 1.5, -12.72, -12.6, "neon", m=True, note="corner lamp, set back"),
        box(3.2, 3.28, 0.6, 1.5, -12.6, -6.25, "secondary", m=True, note="two-tone lower"),
    ]


def fb_flat_face():
    """Show Truck: true flat slab face, full width and full depth, chrome grille bars, lamp columns."""
    p = clip_back() + horns() + [
        box(-4.4, 4.4, 0.5, BELT, -13.7, -6.25, "primary", note="slab nose: flat face, Engine1 pad and cowl deck at Y 3.6"),
        box(-3.0, 3.0, 1.4, 3.3, -13.86, -13.7, "secondary", note="chrome grille"),
        box(3.3, 4.2, 1.0, 3.2, -13.86, -13.7, "neon", m=True, note="lamp column"),
        box(4.4, 4.5, STRIPE[0], STRIPE[1], -13.2, -6.6, "neon", m=True, note="marker lamp strip on the stripe datum"),
        box(-0.12, 0.12, 1.5, 3.2, -13.95, -13.86, "detail", note="grille bar"),
    ]
    for x in (1.0, 2.0):
        p.append(box(x - 0.12, x + 0.12, 1.5, 3.2, -13.95, -13.86, "detail", m=True, note="grille bar"))
    return p


def fb_round_nose():
    """Cab: tall narrow hood and radiator shell widening to a cowl, separate pontoon fenders on stays. Open between hood and fender ahead of the cowl."""
    return clip_back(0.8, 2.4) + horns() + [
        box(-2.4, 2.4, 0.6, BELT, -13.2, -6.25, "primary", note="tall narrow hood: Engine1 pad at Y 3.6"),
        box(-2.2, 2.2, 0.6, 3.5, -13.7, -13.2, "secondary", note="radiator shell"),
        box(-1.8, 1.8, 1.4, 3.2, -13.8, -13.7, "detail", note="grille"),
        box(-0.15, 0.15, 1.4, 3.2, -13.88, -13.8, "secondary", note="grille split"),
        box(2.4, COWL_X, 2.0, BELT, POD_Z, -6.25, "primary", m=True, note="cowl: the hood widens to the cab, flat at the belt"),
        wedge(2.4, COWL_X, 2.0, BELT, -11.8, POD_Z, "primary", "front", m=True, note="cowl sweeps down to the hood side"),
        cylz(1.5, 5.25, 2.8, -13.2, -6.8, "primary", m=True, note="pontoon fender"),
        ball(1.3, 5.25, 2.8, -13.3, "neon", m=True, note="round lamp"),
        box(2.4, 4.6, 2.55, 2.95, -12.9, -12.3, "detail", m=True, note="front fender stay"),
        box(COWL_X, 4.6, 2.55, 2.95, -8.6, -7.8, "detail", m=True, note="fender stay from the cowl"),
        box(COWL_X, COWL_X + 0.08, 2.7, STRIPE[1], POD_Z, -6.25, "secondary", m=True, note="checker band on the cowl side"),
    ]


def fb_stub_nose():
    """Courier: a short, blunt van nose. The body stops 1.4 short of the other clips and its face leans back to the cowl deck. The frame prongs and the Hood Engine stand out ahead of it."""
    return clip_back(0.9) + [
        box(1.9, 2.7, 0.55, 1.25, -13.9, -12.3, "detail", m=True, note="bumper horn on a frame prong: the Front Bar pad, the same place as every clip"),
        box(-4.2, 4.2, 0.9, BELT, POD_Z, -6.25, "primary", note="cowl block: cowl deck at Y 3.6"),
        box(-4.2, 4.2, 0.9, 2.3, -12.3, POD_Z, "primary", note="short nose"),
        wedge(-4.2, 4.2, 2.3, BELT, -12.3, POD_Z, "primary", "front", note="face leans back to the cowl"),
        box(-2.0, 2.0, 2.3, BELT, -12.3, POD_Z, "primary", note="hood spine: Engine1 pad at Y 3.6"),
        box(-2.8, 2.8, 1.2, 2.1, -12.42, -12.3, "detail", note="grille"),
        box(3.0, 4.0, 1.2, 2.1, -12.42, -12.3, "neon", m=True, note="square lamp"),
        box(-4.26, 4.26, 0.95, 1.15, -12.36, -12.0, "secondary", note="nose band"),
        box(4.2, 4.28, STRIPE[0], STRIPE[1], POD_Z, -6.25, "secondary", m=True, note="stripe"),
        box(4.4, 5.7, 2.05, 2.5, -12.2, -8.6, "primary", m=True, note="flat step fender over the lift jet"),
        box(4.4, 5.7, 2.05, 2.5, -8.6, -8.2, "detail", m=True, note="fender bracket"),
    ]


# ----------------------------------------------------------------------------- RearBody (Bed)
# Every bed gives the same pads: deck at Y 2.0, shoulder pads at Y 3.0, horns, a tail face at Z 13.9,
# and a tail corner (X 3.3..5.4, Y 2.0..3.0) for the flank ports. Tail lamps sit above Y 3.5 or below Y 1.8.
def bed_base(y0=0.5, liner="detail"):
    return [
        box(-4.3, 4.3, y0, 1.7, 3.3, 13.9, "primary", note="bed floor"),
        box(-4.2, 4.2, 1.7, DECK, 3.35, 13.85, liner, note="deck: Engine2 pad at Y 2.0"),
        box(-3.6, 3.6, 0.8, 2.6, 3.05, 3.3, "detail", note="front linkage plate in the shadow gap"),
        box(4.4, 5.4, 2.6, 3.0, 4.9, 13.9, "primary", m=True, note="shoulder: Bed Rig feet land here at Y 3.0"),
    ]


def rear_horns(y1=1.25):
    """The Rear Bar pad: two horns at the same place on every bed."""
    return [box(1.9, 2.7, 0.55, y1, 13.1, 13.9, "detail", m=True, note="bumper horn: the Rear Bar pad, the same on every bed")]


def rb_chase_tub():
    """Prerunner: deep tub whose walls climb to a high kicked tail, underside cut up for departure, flared shoulders, no tailgate."""
    return rear_horns(1.7) + [
        box(-4.3, 4.3, 0.5, 1.7, 3.3, 9.4, "primary", note="bed floor"),
        wedge(-4.3, 4.3, 0.5, 1.7, 9.4, 13.9, "primary", "back", flip=True, note="underside kicks up to the tail: departure angle"),
        box(-4.2, 4.2, 1.7, DECK, 3.35, 13.85, "detail", note="deck: Engine2 pad at Y 2.0"),
        box(-3.6, 3.6, 0.8, 2.6, 3.05, 3.3, "detail", note="front linkage plate in the shadow gap"),
        box(4.4, 5.4, 2.6, 3.0, 4.9, 13.9, "primary", m=True, note="shoulder: Bed Rig feet land here at Y 3.0"),
        box(3.3, 4.3, DECK, 3.4, 3.3, 13.9, "primary", m=True, note="tub wall"),
        wedge(3.3, 4.3, 3.4, 5.3, 7.0, 13.9, "primary", "front", m=True, note="wall climbs to a high kicked tail"),
        box(-3.3, 3.3, DECK, 3.4, 3.3, 3.9, "primary", note="front wall"),
        box(4.3, 4.38, STRIPE[0], STRIPE[1], 3.3, 13.9, "secondary", m=True, note="stripe"),
        box(5.4, 6.7, 2.5, 3.0, 6.8, 12.2, "primary", m=True, note="flare over the lift jet"),
        wedge(5.4, 6.7, 2.5, 3.0, 5.6, 6.8, "primary", "front", m=True),
        wedge(5.4, 6.7, 2.5, 3.0, 12.2, 13.4, "primary", "back", m=True),
        box(3.4, 4.2, 3.6, 5.1, 13.9, 13.98, "neon", m=True, note="tall tail lamp, above the flank port"),
    ]


def rb_flatbed():
    """Lifted: thin flat deck carried high and wider than the cab, open headboard frame, stake rails. Only crossmembers under it."""
    return rear_horns(1.2) + [
        box(-4.3, 4.3, 1.2, 1.7, 3.3, 13.9, "primary", note="deck frame, carried high"),
        box(-4.2, 4.2, 1.7, DECK, 3.35, 13.85, "secondary", note="deck boards: Engine2 pad at Y 2.0"),
        box(4.4, 6.5, DECK, 2.35, 4.9, 13.9, "secondary", m=True, note="deck wing: the flatbed is wider than the cab"),
        box(-3.0, 3.0, 0.5, 1.2, 6.6, 7.4, "detail", note="crossmember"),
        box(-3.0, 3.0, 0.5, 1.2, 11.6, 12.4, "detail", note="crossmember"),
        box(-3.6, 3.6, 1.2, 2.6, 3.05, 3.3, "detail", note="front linkage plate"),
        box(4.4, 5.4, 2.6, 3.0, 4.9, 13.9, "detail", m=True, note="stake rail: Bed Rig feet land here at Y 3.0"),
        box(3.5, 4.1, DECK, 6.4, 3.3, 3.8, "detail", m=True, note="headboard post"),
        box(-4.1, 4.1, 5.9, 6.4, 3.3, 3.8, "detail"),
        box(-3.5, 3.5, 3.2, 3.6, 3.4, 3.7, "detail", note="headboard bar"),
        box(-3.5, 3.5, 4.5, 4.9, 3.4, 3.7, "detail"),
        box(3.0, 4.3, 0.5, 1.2, 3.6, 5.6, "secondary", m=True, note="under-deck toolbox"),
        box(3.5, 4.3, DECK, 3.0, 13.3, 13.9, "detail", m=True, note="tail post: the flank port pad"),
        box(3.0, 4.2, 1.25, 1.65, 13.9, 13.98, "neon", m=True, note="tail lamp"),
    ] + [box(4.5, 4.9, 2.35, 2.6, z, z + 0.4, "detail", m=True, note="stake") for z in (5.2, 9.2, 13.2)]


def rb_laid_bed():
    """Minitruck: very low smooth walls and wide smooth shoulders, square to the tail."""
    return bed_base()[:3] + rear_horns() + [
        box(4.4, 5.4, DECK, 3.0, 4.9, 6.2, "primary", m=True, note="shoulder pad: Bed Rig feet land here at Y 3.0"),
        box(4.4, 6.2, DECK, 2.6, 6.2, 11.4, "primary", m=True, note="wide smooth shoulder"),
        box(4.4, 5.4, DECK, 3.0, 11.4, 13.9, "primary", m=True, note="shoulder pad, square to the tail: the flank port pad"),
        box(3.3, 4.3, DECK, 2.6, 3.3, 13.9, "primary", m=True, note="very low wall"),
        box(-3.3, 3.3, DECK, 2.6, 3.3, 3.9, "primary", note="front wall"),
        box(4.3, 4.38, 0.6, 1.6, 3.3, 13.9, "secondary", m=True, note="two-tone lower"),
        box(-4.0, 4.0, 1.3, 1.6, 13.9, 13.98, "neon", note="tail lamp strip"),
    ]


def rb_show_deck():
    """Show Truck: chrome deck, full-height lamp headboard, wing walls sweeping down from it, dually fenders, tall lamp posts at the tail."""
    return bed_base(liner="secondary") + rear_horns() + [
        box(-4.2, 4.2, DECK, 6.9, 3.3, 3.8, "secondary", note="tall chrome headboard"),
        box(-3.6, 3.6, 6.1, 6.5, 3.8, 3.9, "neon", note="headboard lamp row"),
        wedge(3.45, 4.25, 2.6, 6.9, 3.7, 10.0, "primary", "back", m=True, note="wing wall sweeping down from the headboard"),
        box(4.4, 6.7, DECK, 2.9, 6.2, 12.8, "secondary", m=True, note="dually fender, just under the shoulder pad"),
        wedge(4.4, 6.7, DECK, 2.9, 5.0, 6.2, "secondary", "front", m=True),
        wedge(4.4, 6.7, DECK, 2.9, 12.8, 13.9, "secondary", "back", m=True),
        box(3.4, 4.3, DECK, 2.7, 3.8, 13.2, "primary", m=True, note="low side rail"),
        box(3.4, 4.3, DECK, 5.4, 13.2, 13.9, "secondary", m=True, note="tall tail lamp post"),
        box(3.5, 4.2, 3.6, 5.2, 13.9, 13.98, "neon", m=True, note="stacked tail lamps, above the flank port"),
        box(4.3, 4.38, 0.6, 0.9, 3.3, 13.9, "neon", m=True, note="marker lamp strip"),
    ]


def rb_canopy():
    """Cab: luggage bed under a canopy roof on corner posts; the engine shows through the open sides."""
    return bed_base() + rear_horns() + [
        box(3.3, 4.3, DECK, 3.3, 3.3, 13.9, "primary", m=True, note="low wall"),
        box(-3.3, 3.3, DECK, 3.3, 3.3, 3.9, "primary", note="front wall"),
        box(4.3, 4.38, 2.7, STRIPE[1], 3.3, 13.9, "secondary", m=True, note="checker band"),
        box(3.5, 4.2, 3.3, 6.2, 3.4, 4.0, "primary", m=True, note="canopy post"),
        box(3.5, 4.2, 3.3, 6.2, 13.2, 13.8, "primary", m=True, note="canopy post"),
        box(-4.3, 4.3, 6.2, 6.6, 3.4, 13.8, "primary", note="canopy roof"),
        box(-3.8, 3.8, 6.6, 6.9, 4.0, 13.2, "secondary", note="canopy cap"),
        box(3.55, 4.15, 3.7, 5.2, 13.8, 13.88, "neon", m=True, note="tail lamp on the canopy post, above the flank port"),
    ]


def rb_parcel_box():
    """Courier: a closed box that carries the cab roofline back, then stops at a roll-up door. Behind it an open tail deck, so the Bed Engine pokes out of the box and shows."""
    box_r = 9.6
    return bed_base() + rear_horns() + [
        box(3.3, 4.3, DECK, 6.2, 3.3, box_r, "primary", m=True, note="box side: blank panel"),
        box(-3.3, 3.3, DECK, 6.2, 3.3, 3.9, "primary", note="bulkhead"),
        box(-4.3, 4.3, 6.2, 6.95, 3.3, box_r, "primary", note="box roof: carries the cab roofline at Y 7.0"),
        box(-3.2, 3.2, 6.0, 6.2, box_r - 0.5, box_r, "detail", note="rolled-up door"),
        box(4.3, 4.38, 4.2, 5.4, 3.6, box_r - 0.3, "secondary", m=True, note="livery band"),
        box(4.3, 4.38, STRIPE[0], STRIPE[1], box_r, 13.9, "secondary", m=True, note="stripe"),
        box(3.3, 4.3, DECK, 3.4, box_r, 13.9, "primary", m=True, note="low wall of the open tail deck"),
        box(3.4, 4.2, 3.4, 5.0, 13.3, 13.9, "detail", m=True, note="tail post"),
        box(3.5, 4.1, 3.6, 4.8, 13.9, 13.98, "neon", m=True, note="tail lamp, above the flank port"),
        box(4.4, 6.3, DECK, 2.95, 4.9, 6.3, "secondary", m=True, note="side locker under the box"),
        box(6.3, 6.38, 2.3, 2.6, 5.2, 6.0, "detail", m=True, note="locker latch"),
    ]


# ----------------------------------------------------------------------------- Engine1 (Hood Engine)
# Every Hood Engine starts within 0.3 of Z -13.8, stands up to Y 6.2 and ends in jets that fire up or outboard.
E1Y = BELT + 0.02


def e1_ram_single():
    """Prerunner: one fat ram turbine down the hood, ending in a single big up-turned nozzle."""
    y = 4.9
    return [
        box(-0.9, 0.9, E1Y, 3.95, -12.4, -9.6, "detail", note="cradle on the hood pad"),
        cylz(2.5, 0, y, -13.7, -12.5, "secondary", note="intake bell"),
        cylz(1.7, 0, y, -13.78, -13.7, "detail", note="intake mouth"),
        cylz(2.2, 0, y, -12.5, -9.6, "secondary", note="turbine body"),
        cylz(2.4, 0, y, -11.7, -10.5, "detail", note="compressor band"),
        box(-0.85, 0.85, 3.9, 5.4, -9.6, -8.0, "detail", note="exhaust elbow"),
        box(0.85, 1.6, 4.2, 4.8, -9.4, -8.2, "detail", m=True, note="bleed duct"),
        box(1.6, 1.72, 4.25, 4.75, -9.3, -8.3, "thrust", m=True, note="bleed jet: fires outboard"),
    ] + up_stack(1.7, 0, 5.4, 6.15, -8.8, jet=1.4)


def e1_twin_ram():
    """Lifted: two long turbines wide apart and low on the hood, a tall bug-catcher scoop standing between them, two up-turned nozzles at the back."""
    y = 4.35
    return [
        box(-1.9, 1.9, E1Y, 3.8, -12.2, -11.4, "detail", note="cradle on the hood pad"),
        box(-1.9, 1.9, E1Y, 3.8, -10.2, -9.4, "detail", note="cradle"),
        cylz(1.4, 1.25, y, -12.9, -9.6, "secondary", m=True, note="turbine body"),
        cylz(1.45, 1.25, y, -13.75, -12.9, "detail", m=True, note="intake"),
        box(0.6, 1.9, 3.9, 5.0, -9.6, -8.4, "detail", m=True, note="exhaust elbow"),
        box(-0.5, 0.5, E1Y, 6.1, -12.0, -10.4, "secondary", note="bug-catcher scoop"),
        wedge(-0.5, 0.5, 4.9, 6.1, -12.8, -12.0, "detail", "front", note="scoop mouth"),
    ] + up_stack(1.3, 1.25, 5.0, 6.15, -9.0, m=True, jet=1.05)


def e1_slot_scoop():
    """Minitruck: a flat slot burner lying on the hood under a tall intake scoop. Slot jets down both flanks and one wide slot firing up at the back."""
    return [
        box(-1.9, 1.9, E1Y, 4.4, -13.0, -9.5, "secondary", note="flat burner body"),
        wedge(-1.9, 1.9, E1Y, 4.4, -13.7, -13.0, "detail", "front", note="intake lip"),
        box(-1.6, 1.6, 4.4, 5.6, -13.6, -12.2, "secondary", note="intake scoop, 1.2 tall"),
        box(-1.35, 1.35, 4.55, 5.45, -13.76, -13.6, "detail", note="scoop mouth"),
        wedge(-1.6, 1.6, 4.4, 5.6, -12.2, -10.6, "secondary", "back", note="scoop fairing"),
        box(1.9, 1.97, 3.8, 4.3, -12.6, -9.9, "thrust", m=True, note="flank slot jet: fires outboard"),
        box(-1.8, 1.8, E1Y, 5.1, -9.5, -8.6, "detail", note="slot nozzle, turned up"),
        wedge(-1.8, 1.8, 4.4, 5.1, -10.5, -9.5, "detail", "front", note="ramp up to the nozzle"),
        box(-1.5, 1.5, 5.1, 5.4, -9.4, -8.7, "thrust", note="slot jet: fires up, 3 wide"),
    ]


def e1_six_pack():
    """Show Truck: a long chrome block with six barrels, three a side, leaning up and out. Six separate jets."""
    p = [
        box(-1.0, 1.0, E1Y, 5.0, -13.3, -8.4, "secondary", note="chrome block, 5 long"),
        box(-0.8, 0.8, 3.9, 4.8, -13.72, -13.3, "detail", note="intake mouth"),
        box(-0.45, 0.45, 5.0, 5.3, -13.0, -8.8, "detail", note="top rail"),
    ]
    tilt = 28.0
    ax = (math.sin(math.radians(tilt)), math.cos(math.radians(tilt)))
    for z in (-12.3, -10.7, -9.1):
        p.append(part("cyl_y", [1.1, 1.4, 1.1], [1.05, 4.9, z], "detail", [0, 0, -tilt], True, "barrel, leaning up and out"))
        p.append(part("cyl_y", [1.0, 0.35, 1.0], [1.05 + ax[0] * 0.875, 4.9 + ax[1] * 0.875, z], "thrust", [0, 0, -tilt], True,
                      "jet: fires up and outboard"))
    return p


def e1_cab_trio():
    """Cab: a short pack of three at the very nose. One turbine leads, two sit back beside it, and three up-turned nozzles stand in a row behind them. The hood behind is bare."""
    return [
        box(-1.9, 1.9, E1Y, 3.8, -12.9, -11.5, "detail", note="cradle on the hood pad"),
        cylz(1.5, 0, 4.4, -13.2, -11.4, "secondary", note="centre turbine, leading"),
        cylz(1.6, 0, 4.4, -13.78, -13.2, "detail", note="centre intake"),
        cylz(1.15, 1.4, 4.3, -12.7, -11.4, "secondary", m=True, note="side turbine, set back"),
        cylz(1.2, 1.4, 4.3, -13.2, -12.7, "detail", m=True, note="side intake"),
        box(-1.95, 1.95, E1Y, 5.0, -11.4, -10.5, "detail", note="exhaust manifold"),
    ] + up_stack(1.3, 0, 5.0, 6.15, -10.95, jet=1.05) + up_stack(1.2, 1.35, 5.0, 5.75, -10.95, m=True, jet=1.0)


def e1_doghouse():
    """Courier: a tall engine cover hard against the cab, fed by a low intake trunk from the nose. Two vents in its lid fire up."""
    return [
        box(-1.7, 1.7, E1Y, 6.0, -10.2, -7.0, "secondary", note="doghouse: engine cover against the cab"),
        box(-1.7, 1.7, E1Y, 4.6, -11.2, -10.2, "secondary", note="doghouse nose"),
        wedge(-1.7, 1.7, 4.6, 6.0, -11.2, -10.2, "secondary", "front", note="sloped front"),
        box(-0.7, 0.7, E1Y, 4.5, -13.4, -11.2, "detail", note="intake trunk"),
        box(-1.0, 1.0, E1Y, 4.9, -13.75, -13.3, "detail", note="intake mouth"),
        box(1.7, 1.78, 4.2, 5.4, -9.8, -7.4, "detail", m=True, note="side louvre"),
        box(0.45, 1.5, 6.0, 6.17, -9.7, -7.5, "thrust", m=True, note="lid vent jet: fires up"),
        box(-0.25, 0.25, 6.0, 6.12, -10.0, -7.2, "detail", note="lid spine"),
    ]


# ----------------------------------------------------------------------------- Engine2 (Bed Engine)
E2Y = DECK + 0.03


def e2_bed_turbine():
    """Prerunner: one huge turbine lying in the bed."""
    y = 4.0
    return [
        box(-1.6, 1.6, E2Y, 2.6, 6.2, 11.4, "detail", note="cradle on the bed deck"),
        cylz(3.6, 0, y, 4.2, 5.9, "secondary", note="intake bell"),
        cylz(2.9, 0, y, 4.08, 5.5, "detail", note="intake mouth"),
        cylz(3.0, 0, y, 5.9, 11.6, "secondary", note="turbine body"),
        cylz(3.2, 0, y, 7.8, 9.4, "detail", note="compressor band"),
        cylz(2.6, 0, y, 11.6, 13.2, "detail", note="nozzle"),
        cylz(2.1, 0, y, 13.2, 13.75, "thrust", note="jet"),
        box(-0.8, 0.8, 5.45, 5.95, 6.4, 8.6, "detail", note="top scoop"),
        cylz(0.45, 1.9, 2.6, 6.0, 11.4, "detail", m=True, note="fuel line"),
    ]


def e2_twin_barrels():
    """Lifted: two long, low turbines set wide apart against the bed sides, ram scoops on top."""
    y = 3.15
    return [
        box(1.2, 3.0, E2Y, 2.5, 5.8, 6.8, "detail", m=True, note="cradle on the bed deck"),
        box(1.2, 3.0, E2Y, 2.5, 10.6, 11.6, "detail", m=True, note="cradle"),
        cylz(2.0, 2.1, y, 5.4, 12.0, "secondary", m=True, note="turbine body"),
        cylz(2.15, 2.1, y, 4.2, 5.4, "detail", m=True, note="intake"),
        box(1.5, 2.7, 4.05, 4.75, 6.2, 7.8, "secondary", m=True, note="ram scoop"),
        wedge(1.5, 2.7, 4.05, 4.75, 7.8, 9.4, "secondary", "back", m=True),
        cylz(1.7, 2.1, y, 12.0, 13.2, "detail", m=True, note="nozzle"),
        cylz(1.3, 2.1, y, 13.2, 13.75, "thrust", m=True, note="jet"),
        box(-1.2, 1.2, 2.7, 3.5, 8.0, 9.6, "detail", note="crossover"),
    ]


def e2_deck_burner():
    """Minitruck: a low, wide slot burner on the deck with a turbine hump down its middle. The slot nozzle is raised at the tail and glows full width."""
    p = [
        box(-3.0, 3.0, E2Y, 2.8, 5.2, 12.2, "secondary", note="flat burner body"),
        wedge(-3.0, 3.0, E2Y, 2.8, 4.2, 5.2, "detail", "front", note="intake ramp"),
        cylz(2.0, 0, 3.05, 6.4, 11.4, "secondary", note="turbine hump, standing out of the burner"),
        cylz(2.1, 0, 3.1, 5.3, 6.4, "detail", note="hump intake"),
        wedge(-2.9, 2.9, 2.8, 3.6, 11.2, 12.2, "detail", "front", note="ramp up to the nozzle"),
        box(-2.9, 2.9, 2.6, 3.6, 12.2, 13.5, "detail", note="raised slot nozzle"),
        box(-2.7, 2.7, 2.85, 3.35, 13.5, 13.85, "thrust", note="slot jet, 0.5 tall"),
    ]
    for z in (6.8, 8.4, 10.0):
        p.append(box(1.3, 2.7, 2.8, 2.92, z, z + 0.8, "detail", m=True, note="louvre"))
    return p


def e2_quad_chrome():
    """Show Truck: four short chrome turbines in a 2 x 2 block at the tail, fed by a tall plenum."""
    p = [
        box(-2.6, 2.6, E2Y, 5.7, 7.6, 9.4, "secondary", note="chrome plenum"),
        box(-2.2, 2.2, 2.6, 5.2, 7.4, 7.6, "detail", note="intake grille"),
        box(-0.5, 0.5, E2Y, 2.6, 4.4, 7.6, "detail", note="feed pipe along the deck"),
    ]
    for y in (3.0, 5.0):
        p.append(cylz(1.8, 1.15, y, 9.4, 12.8, "secondary", m=True, note="turbine"))
        p.append(cylz(1.4, 1.15, y, 12.8, 13.5, "detail", m=True, note="nozzle"))
        p.append(cylz(1.1, 1.15, y, 13.5, 13.85, "thrust", m=True, note="jet"))
    return p


def e2_over_under():
    """Cab: two turbines stacked. The lower runs the length of the bed, the upper is a short one set right back."""
    return [
        cylz(1.9, 0, 3.0, 5.2, 12.6, "secondary", note="lower turbine"),
        cylz(1.94, 0, 3.02, 4.2, 5.2, "detail", note="lower intake"),
        cylz(1.5, 0, 3.0, 12.6, 13.3, "detail", note="lower nozzle"),
        cylz(1.1, 0, 3.0, 13.3, 13.7, "thrust", note="lower jet"),
        cylz(1.9, 0, 5.0, 9.4, 13.0, "secondary", note="upper turbine"),
        cylz(1.94, 0, 5.02, 8.4, 9.4, "detail", note="upper intake"),
        cylz(1.5, 0, 5.0, 13.0, 13.6, "detail", note="upper nozzle"),
        cylz(1.1, 0, 5.0, 13.6, 13.95, "thrust", note="upper jet"),
        box(0.95, 1.25, E2Y, 5.6, 9.8, 10.4, "detail", m=True, note="frame"),
        box(0.95, 1.25, E2Y, 5.6, 11.6, 12.2, "detail", m=True, note="frame"),
    ]


def e2_tail_three():
    """Courier: three short turbines side by side on the tail deck, fed by one intake trunk that runs forward into the box."""
    p = [
        box(-3.0, 3.0, E2Y, 2.5, 10.2, 12.6, "detail", note="cradle on the bed deck"),
        box(-1.6, 1.6, E2Y, 4.4, 4.3, 5.6, "detail", note="intake box at the front of the bed"),
        box(-1.0, 1.0, E2Y, 3.3, 5.6, 8.6, "secondary", note="intake trunk along the deck"),
        box(-3.0, 3.0, 2.5, 4.1, 8.6, 9.2, "secondary", note="manifold"),
    ]
    for x, m in ((0.0, False), (2.1, True)):
        p.append(cylz(1.9, x, 3.3, 9.2, 12.8, "secondary", m=m, note="turbine"))
        p.append(cylz(1.6, x, 3.3, 12.8, 13.4, "detail", m=m, note="nozzle"))
        p.append(cylz(1.3, x, 3.3, 13.4, 13.8, "thrust", m=m, note="jet"))
    return p


# ----------------------------------------------------------------------------- Stabilisers (Lift Jets)
def corners(fn):
    out = []
    for zc in (FZ, RZ):
        out += fn(zc)
    return out


def st_long_travel():
    """Prerunner: long nacelle pods far out on A-arms and coil-overs, two down-jets each."""
    def c(zc):
        p = [
            strut((3.6, -0.25, zc), (5.6, -0.85, zc), 0.34, "detail", m=True, note="A-arm from the axle beam"),
            strut((5.35, -0.7, zc), (4.95, 1.7, zc), 0.5, "secondary", m=True, round_=True, note="coil-over"),
            cylz(1.4, 6.05, -1.0, zc - 2.2, zc + 2.2, "primary", m=True, note="pod nacelle, longer than wide"),
            cylz(1.0, 6.05, -1.0, zc - 2.9, zc - 2.2, "secondary", m=True, note="pod nose"),
            cylz(1.0, 6.05, -1.0, zc + 2.2, zc + 2.9, "detail", m=True, note="pod tail"),
        ]
        for dz in (-1.2, 1.2):
            p.append(cyly(0.85, 6.05, -2.2, -1.4, zc + dz, "detail", m=True, note="down nozzle"))
            p.append(cyly(0.6, 6.05, -2.4, -2.2, zc + dz, "thrust", m=True, note="lift jet"))
        return p
    return corners(c)


def st_stilts():
    """Lifted: tall thruster legs on outrigger beams. The longest reach: the highest ride."""
    def c(zc):
        return [
            box(3.45, 5.1, -0.5, 0.1, zc - 0.35, zc + 0.35, "detail", m=True, note="outrigger beam from the axle"),
            box(5.0, 6.6, -1.2, 1.9, zc - 0.9, zc + 0.9, "primary", m=True, note="thruster leg, taller than wide"),
            box(4.9, 6.7, 0.8, 1.3, zc - 1.0, zc + 1.0, "secondary", m=True, note="collar"),
            box(6.6, 6.72, -0.8, 0.5, zc - 0.6, zc + 0.6, "detail", m=True, note="intake grille"),
            cyly(1.5, 5.8, -2.2, -1.2, zc, "detail", m=True, note="down nozzle"),
            cyly(1.1, 5.8, -2.4, -2.2, zc, "thrust", m=True, note="lift jet"),
        ]
    return corners(c)


def st_tucked_slots():
    """Minitruck: flat slot-jet pods tucked in under the body. The shortest reach: the lowest ride."""
    def c(zc):
        return [
            box(3.45, 3.9, -0.5, 0.1, zc - 0.4, zc + 0.4, "detail", m=True, note="short mount on the axle"),
            box(3.8, 5.3, -1.15, -0.25, zc - 2.4, zc + 2.4, "primary", m=True, note="slot pod, long and flat"),
            wedge(3.8, 5.3, -1.15, -0.25, zc - 3.1, zc - 2.4, "detail", "front", m=True, note="intake lip"),
            wedge(3.8, 5.3, -1.15, -0.25, zc + 2.4, zc + 3.1, "primary", "back", m=True),
            box(4.0, 5.1, -1.42, -1.15, zc - 2.1, zc + 2.1, "thrust", m=True, note="slot lift jet"),
            box(5.3, 5.38, -1.1, -0.85, zc - 2.1, zc + 2.1, "thrust", m=True, note="side slot jet"),
            box(5.3, 5.4, -0.7, -0.4, zc - 2.3, zc + 2.3, "neon", m=True, note="underglow edge"),
        ]
    return corners(c)


def st_dually_vectors():
    """Show Truck: two chrome vectoring nozzles side by side at each corner."""
    def c(zc):
        p = [box(3.45, 6.6, -0.55, -0.05, zc - 0.3, zc + 0.3, "secondary", m=True, note="chrome beam from the axle")]
        tilt = 14.0
        ax = (0.0, math.cos(math.radians(tilt)), math.sin(math.radians(tilt)))
        for x in (4.6, 6.0):
            cy_, cz_ = -1.2, zc - 0.15
            p.append(part("cyl_y", [1.15, 1.6, 1.15], [x, cy_, cz_], "secondary", [tilt, 0, 0], True, "vectoring nozzle, tilted back"))
            p.append(part("cyl_y", [0.8, 0.3, 0.8], [x, cy_ - 0.93 * ax[1], cz_ - 0.93 * ax[2]], "thrust", [tilt, 0, 0], True, "lift jet"))
        p.append(box(4.0, 6.6, -0.05, 0.3, zc - 0.5, zc + 0.5, "detail", m=True, note="swivel yoke"))
        return p
    return corners(c)


def st_spats():
    """Cab: a jet rack. Three down nozzles in a row stand below a short vented skirt, with an intake grille and a glow slot on its outer face."""
    def c(zc):
        p = [
            box(3.45, 4.6, -0.45, 0.05, zc - 0.35, zc + 0.35, "detail", m=True, note="arm from the axle"),
            box(4.5, 5.5, -0.3, 1.9, zc - 2.1, zc + 2.1, "secondary", m=True, note="jet rack housing: jet hardware, not an arch"),
            wedge(4.5, 5.5, -0.3, 1.9, zc - 3.0, zc - 2.1, "secondary", "front", m=True),
            wedge(4.5, 5.5, -0.3, 1.9, zc + 2.1, zc + 3.0, "secondary", "back", m=True),
            box(5.5, 5.62, 0.6, 1.6, zc - 1.9, zc + 1.9, "detail", m=True, note="intake grille on the outer face"),
            box(5.5, 5.6, -0.2, 0.25, zc - 1.9, zc + 1.9, "thrust", m=True, note="side glow slot"),
        ]
        for dz in (-1.35, 0.0, 1.35):
            p.append(cyly(1.0, 5.0, -1.5, -0.3, zc + dz, "detail", m=True, note="down nozzle, 1.2 below the housing"))
            p.append(cyly(0.8, 5.0, -1.9, -1.5, zc + dz, "thrust", m=True, note="lift jet"))
        return p
    return corners(c)


def st_box_lifts():
    """Courier: one square lift duct at each corner, flat and boxy, with a grille on top and a square jet underneath."""
    def c(zc):
        return [
            box(3.45, 4.7, -0.5, 0.1, zc - 0.4, zc + 0.4, "detail", m=True, note="arm from the axle"),
            box(4.6, 6.8, -1.3, 0.3, zc - 1.5, zc + 1.5, "primary", m=True, note="square lift duct, longer than wide"),
            box(4.8, 6.6, 0.3, 0.5, zc - 1.3, zc + 1.3, "detail", m=True, note="intake grille on top"),
            box(4.8, 6.6, -1.7, -1.3, zc - 1.3, zc + 1.3, "detail", m=True, note="nozzle skirt"),
            box(5.0, 6.4, -2.1, -1.7, zc - 1.1, zc + 1.1, "thrust", m=True, note="square lift jet"),
            box(6.8, 6.9, -0.9, -0.1, zc - 1.1, zc + 1.1, "secondary", m=True, note="side band"),
        ]
    return corners(c)


# ----------------------------------------------------------------------------- Boost (Stacks)
def bo_side_dumps():
    """Prerunner: two fat afterburner cans a side, stacked low behind the cab, filling the dump bay and kicked outboard."""
    yaw = 15.0
    ax = (math.sin(math.radians(yaw)), 0.0, math.cos(math.radians(yaw)))
    out = [box(4.5, 5.2, -0.4, 1.9, 3.05, 3.45, "detail", m=True, note="feed manifold from the bed")]
    for cy in (-0.1, 1.3):
        c = (5.5, cy, 4.6)

        def along(s0, s1, d, ch, note, c=c):
            s = (s0 + s1) / 2
            return part("cyl_z", [d, d, s1 - s0], [c[0] + ax[0] * s, c[1], c[2] + ax[2] * s], ch, [0, yaw, 0], True, note)
        out += [
            along(-1.4, -1.0, 1.3, "detail", "intake collar"),
            along(-1.0, 0.55, 1.3, "secondary", "afterburner can"),
            along(0.55, 1.05, 1.2, "detail", "nozzle"),
            along(1.05, 1.4, 1.0, "thrust", "boost jet: fires back and outboard"),
        ]
    return out


def bo_shorty_stacks():
    """Lifted: four fat shorty stacks, two each side, stepped."""
    return [
        box(4.5, 6.5, -0.3, 0.6, 3.3, 4.5, "detail", m=True, note="manifold"),
        cyly(0.9, 5.0, 0.6, 5.6, 3.9, "secondary", m=True, note="inner stack"),
        cyly(0.9, 6.05, 0.6, 4.6, 3.9, "secondary", m=True, note="outer stack"),
        cyly(1.05, 5.0, 2.2, 3.2, 3.9, "detail", m=True, note="intake collar"),
        cyly(1.05, 6.05, 2.2, 3.2, 3.9, "detail", m=True, note="intake collar"),
        cyly(0.65, 5.0, 5.6, 5.9, 3.9, "thrust", m=True, note="boost jet"),
        cyly(0.65, 6.05, 4.6, 4.9, 3.9, "thrust", m=True, note="boost jet"),
    ]


def bo_tail_slot():
    """Minitruck: two tall slot burners on the bed tail corners, one each side of the Bed Engine. Their slots stand upright."""
    return [
        box(3.4, 4.5, 2.05, 3.35, 14.05, 15.5, "secondary", m=True, note="slot burner body on the flank port"),
        box(3.5, 4.4, 2.15, 3.25, 15.5, 15.9, "detail", m=True, note="slot nozzle"),
        box(3.65, 4.25, 2.3, 3.1, 15.9, 16.15, "thrust", m=True, note="boost jet: an upright slot"),
        box(4.5, 4.62, 2.4, 3.0, 14.3, 14.7, "detail", m=True, note="intake louvre"),
        box(4.5, 4.62, 2.4, 3.0, 14.9, 15.3, "detail", m=True, note="intake louvre"),
    ]


def bo_chrome_stacks():
    """Show Truck: two tall chrome stacks behind the cab with heat shields."""
    return [
        cylx(0.7, 4.45, 5.3, 0.9, 3.9, "detail", m=True, note="elbow from under the bed"),
        cyly(1.0, 5.3, 0.6, 9.2, 3.9, "secondary", m=True, note="tall chrome stack"),
        cyly(1.25, 5.3, 3.4, 6.4, 3.9, "detail", m=True, note="heat shield and intake collar"),
        cyly(0.72, 5.3, 9.2, 9.6, 3.9, "thrust", m=True, note="boost jet"),
        box(4.45, 4.85, 4.6, 5.0, 3.6, 4.2, "detail", m=True, note="bracket"),
    ]


def bo_tail_cans():
    """Cab: two afterburner cans in square shrouds, set wide on the bed tail corners, well clear of the Bed Engine."""
    return [
        box(3.9, 5.5, 2.05, 3.35, 14.05, 15.3, "secondary", m=True, note="square shroud on the flank port"),
        box(4.0, 5.4, 2.15, 3.25, 15.3, 15.45, "detail", m=True, note="shroud lip"),
        cylz(1.2, 4.7, 2.7, 15.3, 15.8, "detail", m=True, note="can nozzle"),
        cylz(1.1, 4.7, 2.7, 15.8, 16.15, "thrust", m=True, note="boost jet"),
        box(5.5, 5.58, 2.4, 3.0, 14.3, 15.0, "detail", m=True, note="side vent"),
    ]


def bo_fishtails():
    """Courier: one pipe a side rising behind the cab into a wide flat fishtail. A slot jet across the top of each blade."""
    return [
        cylx(0.6, 4.45, 5.6, 2.4, 3.9, "detail", m=True, note="elbow out of the bed side at deck height"),
        cyly(0.9, 5.6, 2.1, 5.3, 3.9, "secondary", m=True, note="riser pipe: nothing below the deck line"),
        box(5.1, 6.1, 5.3, 5.9, 3.5, 4.3, "detail", m=True, note="collar"),
        box(4.7, 6.5, 5.9, 7.7, 3.6, 4.2, "secondary", m=True, note="fishtail blade: wide and flat"),
        box(4.8, 6.4, 7.7, 8.1, 3.65, 4.15, "thrust", m=True, note="boost jet: a slot across the fishtail"),
    ]


# ----------------------------------------------------------------------------- SidePods (Side Gear)
def sp_rock_sliders():
    return [
        cylz(0.55, 5.5, 0.2, -5.6, 2.6, "detail", m=True, note="slider tube"),
        box(4.3, 5.3, 0.45, 0.6, -5.0, 2.0, "secondary", m=True, note="tread plate"),
    ] + [box(4.25, 5.5, 0.05, 0.4, z - 0.2, z + 0.2, "detail", m=True, note="stand-off") for z in (-4.6, -1.5, 1.6)]


def sp_toolboxes():
    return [
        box(4.25, 5.7, 0.3, 1.9, -5.2, -1.4, "secondary", m=True, note="toolbox"),
        box(4.25, 5.7, 0.3, 1.9, -0.8, 2.6, "secondary", m=True, note="toolbox"),
        box(5.7, 5.78, 1.3, 1.5, -3.8, -2.8, "detail", m=True, note="latch"),
        box(5.7, 5.78, 1.3, 1.5, 0.4, 1.4, "detail", m=True, note="latch"),
        box(4.4, 6.1, -0.6, -0.4, -4.6, -2.0, "detail", m=True, note="drop step"),
        box(5.9, 6.1, -0.4, 0.3, -4.6, -4.3, "detail", m=True, note="hanger"),
        box(5.9, 6.1, -0.4, 0.3, -2.3, -2.0, "detail", m=True, note="hanger"),
    ]


def sp_ground_skirts():
    return [
        box(4.25, 4.8, -0.72, 1.7, -4.8, 2.6, "primary", m=True, note="ground skirt"),
        wedge(4.25, 4.8, -0.72, 1.7, -5.7, -4.8, "primary", "front", m=True),
        box(4.3, 4.75, -0.8, -0.72, -4.6, 2.4, "neon", m=True, note="underglow"),
        box(4.8, 4.86, 0.6, 1.6, -4.8, 2.6, "secondary", m=True, note="two-tone lower"),
    ]


def sp_saddle_tanks():
    return [
        cylz(1.7, 5.2, 0.95, -4.6, 1.6, "secondary", m=True, note="chrome saddle tank"),
        box(4.3, 6.1, 0.05, 1.85, -3.5, -3.2, "detail", m=True, note="strap"),
        box(4.3, 6.1, 0.05, 1.85, 0.2, 0.5, "detail", m=True, note="strap"),
        box(4.3, 6.3, -0.4, -0.2, -5.0, 2.0, "detail", m=True, note="step"),
        box(6.3, 6.38, -0.4, -0.2, -5.0, 2.0, "neon", m=True, note="marker lamp strip"),
    ]


def sp_running_boards():
    return [
        box(4.25, 6.3, 0.3, 0.6, -4.6, 1.6, "secondary", m=True, note="running board"),
        wedge(4.25, 6.3, 0.3, 1.6, -5.7, -4.6, "primary", "back", m=True, note="front fender sweep"),
        wedge(4.25, 6.3, 0.3, 1.6, 1.6, 2.7, "primary", "front", m=True, note="rear fender sweep"),
        box(4.25, 6.0, 0.0, 0.3, -3.2, -2.8, "detail", m=True, note="bracket"),
        box(4.25, 6.0, 0.0, 0.3, 0.0, 0.4, "detail", m=True, note="bracket"),
    ]


def sp_kerb_steps():
    """Courier: a low kerb step hung well out on two hangers, under a sliding-door rail."""
    return [
        box(4.25, 4.5, 1.5, 1.9, -5.6, 2.6, "detail", m=True, note="sliding-door rail"),
        box(4.9, 6.3, -0.75, -0.5, -4.8, 1.8, "secondary", m=True, note="low kerb step"),
        box(4.25, 5.3, -0.5, 1.5, -4.6, -4.2, "detail", m=True, note="hanger"),
        box(4.25, 5.3, -0.5, 1.5, 1.2, 1.6, "detail", m=True, note="hanger"),
        box(6.3, 6.38, -0.75, -0.5, -4.4, 1.4, "neon", m=True, note="kerb lamp"),
    ]


# ----------------------------------------------------------------------------- FrontBumper (Front Bar)
def fbu_bull_bar():
    return [
        box(-5.6, 5.6, 0.6, 1.5, -14.9, -14.1, "detail", note="main bar"),
        wedge(-3.4, 3.4, -0.4, 0.6, -15.4, -14.1, "secondary", "front", flip=True, note="skid plate"),
        box(1.6, 2.0, 1.5, 4.0, -15.2, -14.8, "detail", m=True, note="hoop upright"),
        box(-2.0, 2.0, 3.6, 4.0, -15.2, -14.8, "detail", note="hoop top"),
        ball(1.0, 0.8, 2.6, -15.1, "neon", m=True, note="lamp"),
        box(5.6, 6.6, 0.6, 1.2, -14.7, -14.1, "detail", m=True, note="corner wing"),
    ]


def fbu_winch_bumper():
    return [
        box(-6.4, 6.4, 0.4, 1.9, -15.2, -14.1, "detail", note="heavy plate bumper"),
        box(-2.2, 2.2, 0.7, 1.7, -15.7, -15.2, "secondary", note="winch housing"),
        box(-0.9, 0.9, 1.0, 1.4, -15.85, -15.7, "detail", note="fairlead"),
        box(2.6, 3.0, 1.9, 3.2, -15.0, -14.4, "detail", m=True, note="stinger"),
        box(4.4, 5.8, 0.9, 1.5, -15.3, -15.2, "neon", m=True, note="lamp"),
        box(3.4, 3.8, 0.0, 0.7, -15.6, -15.2, "secondary", m=True, note="shackle"),
    ]


def fbu_air_dam():
    return [
        box(-4.6, 4.6, -0.7, 1.2, -14.6, -14.05, "primary", note="smooth valance, down to the body floor"),
        wedge(-4.6, 4.6, -0.7, 1.2, -15.3, -14.6, "primary", "front", note="chin"),
        box(-5.0, 5.0, -0.8, -0.62, -15.6, -14.05, "detail", note="splitter"),
        box(-3.8, 3.8, 1.2, 1.36, -14.5, -14.1, "neon", note="lamp strip"),
    ]


def fbu_chrome_blade():
    return [
        box(-6.6, 6.6, 0.5, 1.7, -15.0, -14.1, "secondary", note="wide chrome bumper"),
        box(-6.2, 6.2, 1.7, 1.86, -14.9, -14.3, "neon", note="lamp edge"),
        box(-5.0, 5.0, -0.5, 0.5, -14.7, -14.1, "detail", note="valance"),
        box(2.2, 2.8, 0.3, 2.4, -15.3, -15.0, "secondary", m=True, note="over-rider"),
    ]


def fbu_push_bar():
    return [
        box(-5.0, 5.0, 0.6, 1.3, -14.8, -14.1, "secondary", note="bumper bar"),
        box(1.0, 1.6, 0.2, 3.2, -15.4, -14.8, "detail", m=True, note="push upright"),
        box(-1.6, 1.6, 2.6, 3.0, -15.4, -15.0, "detail", note="push bar"),
        box(-1.6, 1.6, 1.2, 1.7, -15.55, -15.4, "detail", note="push pad"),
        box(5.0, 5.6, 0.6, 1.3, -14.6, -14.1, "detail", m=True, note="corner guard"),
    ]


def fbu_front_rack():
    """Courier: a slim bumper with a parcel rack standing out ahead of the nose."""
    return [
        box(-4.6, 4.6, 0.5, 1.1, -14.6, -14.1, "detail", note="slim bumper"),
        box(1.9, 2.5, 1.1, 2.0, -14.6, -14.2, "detail", m=True, note="rack bracket"),
        box(-3.0, 3.0, 2.0, 2.2, -15.8, -14.1, "detail", note="rack tray"),
        box(-3.0, 3.0, 2.2, 2.6, -15.8, -15.65, "detail", note="rack lip"),
        box(-2.4, 0.4, 2.2, 3.4, -15.5, -14.3, "secondary", note="parcel"),
        box(0.8, 2.6, 2.2, 2.9, -15.4, -14.4, "primary", note="small parcel"),
        box(3.4, 4.4, 0.6, 1.0, -14.68, -14.6, "neon", m=True, note="lamp"),
    ]


# ----------------------------------------------------------------------------- RearBumper (Rear Bar)
def rbu_hitch():
    return [
        box(-5.2, 5.2, 0.5, 1.3, 14.1, 14.9, "detail", note="step bar"),
        box(-0.4, 0.4, 0.0, 0.5, 14.9, 15.7, "detail", note="hitch tongue"),
        ball(0.6, 0, 0.75, 15.45, "secondary", note="tow ball"),
        box(5.2, 6.4, 0.5, 0.9, 14.1, 14.7, "detail", m=True, note="corner step"),
    ]


def rbu_step_bar():
    return [
        box(-6.4, 6.4, 0.3, 0.8, 14.1, 15.5, "detail", note="wide plate step"),
        box(-5.8, 5.8, 0.8, 0.92, 14.3, 15.3, "secondary", note="tread"),
        box(3.0, 3.5, -0.3, 0.3, 15.0, 15.5, "secondary", m=True, note="recovery point"),
        box(4.6, 6.0, 0.9, 1.5, 14.1, 14.3, "neon", m=True, note="lamp"),
    ]


def rbu_roll_pan():
    return [
        box(-4.4, 4.4, 0.2, 1.6, 14.05, 14.45, "primary", note="smooth roll pan"),
        wedge(-4.4, 4.4, -0.7, 0.2, 14.05, 14.9, "primary", "back", flip=True, note="tuck-under"),
        box(-3.4, 3.4, 0.7, 0.9, 14.45, 14.52, "neon", note="lamp strip"),
    ]


def rbu_lamp_board():
    return [
        box(-6.6, 6.6, 0.6, 1.6, 14.1, 14.7, "secondary", note="chrome bar"),
        box(-1.6, 1.6, 0.9, 1.3, 14.7, 14.8, "neon", note="lamp row"),
        box(2.4, 6.0, 0.9, 1.3, 14.7, 14.8, "neon", m=True, note="lamp row"),
        box(4.6, 6.4, -0.7, 0.6, 14.2, 14.36, "detail", m=True, note="flap"),
    ]


def rbu_taxi_rail():
    return [
        box(-5.0, 5.0, 0.5, 1.2, 14.1, 14.8, "secondary", note="bumper rail"),
        box(2.4, 3.0, 0.1, 1.7, 14.8, 15.1, "detail", m=True, note="over-rider"),
        box(-1.0, 1.0, 0.6, 1.1, 14.8, 14.88, "neon", note="plate lamp"),
    ]


def rbu_dock_step():
    """Courier: a deep loading step across the tail with two dock buffers."""
    return [
        box(-4.4, 4.4, 0.1, 0.5, 14.1, 15.9, "detail", note="deep loading step"),
        box(-4.0, 4.0, 0.5, 0.62, 14.3, 15.7, "secondary", note="tread"),
        box(2.9, 4.1, 0.62, 1.7, 14.1, 14.7, "detail", m=True, note="dock buffer"),
        box(-1.2, 1.2, 0.7, 1.1, 14.1, 14.2, "neon", note="lamp"),
    ]


# ----------------------------------------------------------------------------- RearSpoiler (Bed Rig)
def rs_chase_rack():
    """Prerunner: tall front hoop, stays sloping down to the tail, lamps, fuel cans."""
    return [
        box(4.55, 5.05, 3.0, 7.7, 5.0, 5.5, "detail", m=True, note="hoop leg on the shoulder pad"),
        box(-5.05, 5.05, 7.3, 7.7, 5.0, 5.5, "detail", note="hoop top"),
        strut((4.8, 7.4, 5.5), (4.8, 3.3, 13.4), 0.4, "detail", m=True, note="sloping stay"),
        box(4.55, 5.05, 3.0, 3.5, 13.0, 13.8, "detail", m=True, note="stay foot"),
        ball(0.75, 1.2, 8.1, 5.25, "neon", m=True, note="lamp"),
        ball(0.75, 3.2, 8.1, 5.25, "neon", m=True, note="lamp"),
        box(-4.55, 4.55, 7.3, 7.6, 7.4, 7.8, "detail", note="cross bar"),
        box(-1.5, -0.3, 7.7, 8.9, 5.6, 7.6, "secondary", note="fuel can"),
        box(0.3, 1.5, 7.7, 8.9, 5.6, 7.6, "secondary", note="fuel can"),
    ]


def rs_roll_bar():
    """Lifted: one fat hoop behind the cab with braces and lamp pods."""
    return [
        box(4.5, 5.2, 3.0, 7.9, 5.0, 5.8, "detail", m=True, note="hoop leg on the shoulder pad"),
        box(-5.2, 5.2, 7.3, 7.9, 5.0, 5.8, "detail", note="hoop top"),
        strut((4.85, 7.2, 5.8), (4.85, 3.3, 9.4), 0.45, "detail", m=True, note="brace"),
        box(1.2, 2.6, 7.9, 8.5, 5.1, 5.7, "neon", m=True, note="lamp pod"),
    ]


def rs_whale_tail():
    """Minitruck: swept fins at the tail carrying a wide wing."""
    return [
        box(4.5, 4.9, 3.0, 7.5, 12.0, 13.6, "primary", m=True, note="fin on the shoulder pad"),
        wedge(4.5, 4.9, 3.0, 7.5, 9.6, 12.0, "primary", "front", m=True, note="swept leading edge"),
        box(-4.9, 4.9, 7.3, 7.6, 11.4, 13.8, "primary", note="wing"),
        box(-4.9, 4.9, 7.6, 7.9, 13.5, 13.8, "secondary", note="gurney lip"),
        box(4.9, 5.3, 7.2, 8.3, 11.2, 13.9, "secondary", m=True, note="end plate"),
    ]


def rs_marker_arch():
    """Show Truck: chrome arch at the tail with a lamp row, tall lamp towers behind the cab."""
    return [
        box(4.5, 5.1, 3.0, 7.8, 12.6, 13.3, "secondary", m=True, note="arch leg on the shoulder pad"),
        box(-5.14, 5.14, 7.8, 8.4, 12.56, 13.34, "secondary", note="arch top"),
        box(-4.2, 4.2, 8.4, 8.6, 12.8, 13.1, "neon", note="marker lamp row"),
        box(4.5, 5.1, 3.0, 8.9, 5.0, 5.6, "secondary", m=True, note="lamp tower"),
        box(4.5, 5.1, 8.9, 9.15, 5.0, 5.6, "neon", m=True, note="tower lamp"),
    ]


def rs_ladder_rack():
    """Cab: flat luggage rack on four posts over the whole bed."""
    p = [
        box(4.55, 5.0, 3.0, 7.6, 5.0, 5.45, "detail", m=True, note="post on the shoulder pad"),
        box(4.55, 5.0, 3.0, 7.6, 12.9, 13.35, "detail", m=True, note="post"),
        box(4.55, 5.0, 7.3, 7.6, 5.45, 12.9, "detail", m=True, note="side rail"),
        box(-2.6, -0.2, 7.5, 8.6, 6.2, 8.6, "secondary", note="trunk"),
        box(0.4, 2.8, 7.5, 8.3, 9.6, 12.2, "primary", note="suitcase"),
    ]
    for z in (5.0, 7.6, 10.2, 13.0):
        p.append(box(-4.55, 4.55, 7.3, 7.5, z, z + 0.35, "detail", note="rung"))
    return p


def rs_top_box():
    """Courier: one long cargo pod carried over the bed on two cross bars."""
    return [
        box(4.5, 5.0, 3.0, 7.6, 5.0, 5.5, "detail", m=True, note="leg on the shoulder pad"),
        box(4.5, 5.0, 3.0, 7.6, 12.2, 12.7, "detail", m=True, note="leg on the shoulder pad"),
        box(-5.0, 5.0, 7.3, 7.6, 5.0, 5.5, "detail", note="cross bar"),
        box(-5.0, 5.0, 7.3, 7.6, 12.2, 12.7, "detail", note="cross bar"),
        box(-1.9, 1.9, 7.6, 8.9, 6.6, 13.2, "secondary", note="roof cargo pod"),
        wedge(-1.9, 1.9, 7.6, 8.9, 4.9, 6.6, "secondary", "front", note="pod nose"),
        box(-1.96, 1.96, 8.1, 8.3, 6.6, 13.2, "primary", note="pod band"),
    ]


# ----------------------------------------------------------------------------- Roof (Roof Rig)
def ro_light_bar():
    return [
        box(1.6, 2.2, 7.6, 7.9, -4.0, -3.2, "detail", m=True, note="foot on the roof pad"),
        box(-3.6, 3.6, 7.9, 8.5, -4.2, -3.3, "detail", note="light bar"),
        box(-3.4, 3.4, 8.0, 8.4, -4.32, -4.2, "neon", note="lamps"),
    ]


def ro_roof_rack():
    return [
        box(-2.4, 2.4, 7.6, 7.8, -4.4, -2.6, "detail", note="rack base on the roof pad"),
        box(-3.4, 3.4, 7.8, 8.0, -4.6, -1.4, "detail", note="basket floor"),
        box(3.2, 3.4, 8.0, 8.6, -4.6, -1.4, "detail", m=True, note="basket rail"),
        box(-3.4, 3.4, 8.0, 8.6, -1.6, -1.4, "detail"),
        box(-3.0, 3.0, 8.0, 8.5, -4.75, -4.6, "neon", note="lamps"),
        box(-2.2, 1.0, 8.0, 8.9, -3.8, -2.0, "secondary", note="cargo"),
    ]


def ro_visor():
    return [
        box(-3.0, 3.0, 7.6, 7.75, -4.4, -2.8, "primary", note="base on the roof pad"),
        wedge(-3.0, 3.0, 7.75, 8.3, -4.4, -2.8, "primary", "front", note="low roof spoiler"),
        box(-3.0, 3.0, 8.3, 8.42, -3.0, -2.8, "secondary", note="lip"),
    ]


def ro_crown():
    return [
        box(-3.8, 3.8, 7.6, 8.0, -4.3, -3.5, "secondary", note="chrome crown bar on the roof pad"),
        ball(0.55, 0, 8.25, -3.9, "neon", note="marker lamp"),
        ball(0.55, 1.5, 8.25, -3.9, "neon", m=True, note="marker lamp"),
        ball(0.55, 3.0, 8.25, -3.9, "neon", m=True, note="marker lamp"),
        cylz(0.55, 2.2, 7.9, -3.4, -1.4, "secondary", m=True, note="air horn"),
    ]


def ro_taxi_sign():
    return [
        box(1.0, 1.5, 7.6, 7.9, -3.9, -3.1, "detail", m=True, note="foot on the roof pad"),
        box(-1.9, 1.9, 7.9, 8.8, -4.0, -3.0, "neon", note="blank glowing sign"),
        box(-2.0, 2.0, 8.8, 8.95, -4.1, -2.9, "detail", note="cap"),
    ]


def ro_aerials():
    """Courier: a radio mast with two cross aerials and a beacon at its foot."""
    return [
        box(-1.2, 1.2, 7.6, 7.8, -4.2, -2.8, "detail", note="base on the roof pad"),
        box(-0.12, 0.12, 7.8, 9.5, -3.62, -3.38, "detail", note="mast"),
        box(-1.7, 1.7, 9.0, 9.15, -3.6, -3.4, "detail", note="cross aerial"),
        box(-1.0, 1.0, 8.4, 8.55, -3.6, -3.4, "detail", note="cross aerial"),
        box(-0.6, 0.6, 7.8, 8.2, -4.15, -3.75, "neon", note="beacon"),
    ]


# ----------------------------------------------------------------------------- Accessory (Extras)
def acc_base():
    return [box(4.25, 4.7, 3.25, 3.7, ACC_PAD_Z[0] + 0.1, ACC_PAD_Z[1] - 0.1, "detail", m=True, note="base on the Extras pad")]


def ac_whips():
    return acc_base() + [
        box(4.4, 4.55, 3.7, 9.3, -4.7, -4.55, "detail", m=True, note="whip aerial"),
        box(4.38, 4.57, 9.3, 9.7, -4.72, -4.53, "neon", m=True, note="whip tip"),
        box(4.45, 4.51, 8.3, 9.1, -4.55, -3.5, "secondary", m=True, note="flag"),
    ]


def ac_tow_mirrors():
    return acc_base() + [
        box(4.4, 5.5, 4.3, 4.5, -4.8, -4.6, "detail", m=True, note="mirror arm"),
        box(4.45, 4.65, 3.7, 4.5, -4.8, -4.6, "detail", m=True),
        box(5.0, 5.7, 3.9, 5.5, -5.0, -4.6, "detail", m=True, note="tow mirror"),
        box(5.05, 5.65, 4.0, 5.4, -4.6, -4.55, "glass", m=True),
    ]


def ac_slim_mirrors():
    return acc_base() + [
        wedge(4.3, 5.2, 3.7, 4.3, -5.0, -4.3, "primary", "front", m=True, note="slim aero mirror"),
    ]


def ac_air_cans():
    return acc_base() + [
        cyly(1.0, 5.05, 3.7, 6.0, -4.6, "secondary", m=True, note="chrome air canister"),
        cyly(0.7, 5.05, 6.0, 6.5, -4.6, "detail", m=True, note="cap"),
        box(4.4, 4.7, 4.6, 5.0, -4.8, -4.4, "detail", m=True, note="bracket"),
    ]


def ac_fare_lamps():
    return acc_base() + [
        box(4.4, 4.6, 3.7, 4.6, -4.75, -4.55, "detail", m=True, note="stalk"),
        box(4.3, 5.1, 4.6, 5.3, -4.9, -4.5, "secondary", m=True, note="mirror"),
        box(4.5, 5.0, 5.3, 5.7, -4.85, -4.55, "neon", m=True, note="for-hire lamp"),
    ]


def ac_grab_rails():
    """Courier: a tall grab rail beside each door with a side beacon on top."""
    return acc_base() + [
        box(4.4, 4.62, 3.7, 7.2, -4.75, -4.5, "secondary", m=True, note="tall grab rail"),
        box(4.3, 4.9, 7.2, 7.6, -4.9, -4.35, "neon", m=True, note="side beacon"),
        box(4.3, 4.62, 5.3, 5.5, -4.75, -4.5, "detail", m=True, note="stand-off"),
    ]


# ----------------------------------------------------------------------------- assembly
def mod(name, culture, fn):
    return {"name": name, "culture": culture, "note": (fn.__doc__ or "").strip() or None, "parts": fn()}


def build_spec():
    P, L, M, S, C, V = "Prerunner", "Lifted", "Minitruck", "Show Truck", "Cab", "Courier"
    modules = {
        "Engine1": {
            "ram_single": mod("Ram Single", P, e1_ram_single),
            "twin_ram": mod("Twin Ram", L, e1_twin_ram),
            "slot_scoop": mod("Slot Scoop", M, e1_slot_scoop),
            "six_pack": mod("Six Pack", S, e1_six_pack),
            "cab_trio": mod("Trio", C, e1_cab_trio),
            "doghouse": mod("Doghouse", V, e1_doghouse),
        },
        "Engine2": {
            "bed_turbine": mod("Bed Turbine", P, e2_bed_turbine),
            "twin_barrels": mod("Twin Barrels", L, e2_twin_barrels),
            "deck_burner": mod("Deck Burner", M, e2_deck_burner),
            "quad_chrome": mod("Quad Chrome", S, e2_quad_chrome),
            "over_under": mod("Over-Under", C, e2_over_under),
            "tail_three": mod("Tail Three", V, e2_tail_three),
        },
        "Stabilisers": {
            "long_travel": mod("Long Travel", P, st_long_travel),
            "stilts": mod("Stilts", L, st_stilts),
            "tucked_slots": mod("Tucked Slots", M, st_tucked_slots),
            "dually_vectors": mod("Dually Vectors", S, st_dually_vectors),
            "spats": mod("Jet Racks", C, st_spats),
            "box_lifts": mod("Box Lifts", V, st_box_lifts),
        },
        "Boost": {
            "side_dumps": mod("Side Dumps", P, bo_side_dumps),
            "shorty_stacks": mod("Shorty Stacks", L, bo_shorty_stacks),
            "tail_slot": mod("Tail Slots", M, bo_tail_slot),
            "chrome_stacks": mod("Chrome Stacks", S, bo_chrome_stacks),
            "tail_cans": mod("Tail Cans", C, bo_tail_cans),
            "fishtails": mod("Fishtails", V, bo_fishtails),
        },
        "FrontBody": {
            "flare_nose": mod("Flare Nose", P, fb_flare_nose),
            "square_body": mod("Square Body", L, fb_square_body),
            "smoothie": mod("Smoothie", M, fb_smoothie),
            "flat_face": mod("Flat Face", S, fb_flat_face),
            "round_nose": mod("Round Nose", C, fb_round_nose),
            "stub_nose": mod("Stub Nose", V, fb_stub_nose),
        },
        "RearBody": {
            "chase_tub": mod("Chase Tub", P, rb_chase_tub),
            "flatbed": mod("Flatbed", L, rb_flatbed),
            "laid_bed": mod("Laid Bed", M, rb_laid_bed),
            "show_deck": mod("Show Deck", S, rb_show_deck),
            "canopy": mod("Fare Canopy", C, rb_canopy),
            "parcel_box": mod("Parcel Box", V, rb_parcel_box),
        },
        "SidePods": {
            "rock_sliders": mod("Rock Sliders", P, sp_rock_sliders),
            "toolboxes": mod("Toolboxes", L, sp_toolboxes),
            "ground_skirts": mod("Ground Skirts", M, sp_ground_skirts),
            "saddle_tanks": mod("Saddle Tanks", S, sp_saddle_tanks),
            "running_boards": mod("Running Boards", C, sp_running_boards),
            "kerb_steps": mod("Kerb Steps", V, sp_kerb_steps),
        },
        "FrontBumper": {
            "bull_bar": mod("Bull Bar", P, fbu_bull_bar),
            "winch_bumper": mod("Winch Bumper", L, fbu_winch_bumper),
            "air_dam": mod("Air Dam", M, fbu_air_dam),
            "chrome_blade": mod("Chrome Blade", S, fbu_chrome_blade),
            "push_bar": mod("Push Bar", C, fbu_push_bar),
            "front_rack": mod("Front Rack", V, fbu_front_rack),
        },
        "RearBumper": {
            "hitch": mod("Hitch", P, rbu_hitch),
            "step_bar": mod("Step Bar", L, rbu_step_bar),
            "roll_pan": mod("Roll Pan", M, rbu_roll_pan),
            "lamp_board": mod("Lamp Board", S, rbu_lamp_board),
            "taxi_rail": mod("Taxi Rail", C, rbu_taxi_rail),
            "dock_step": mod("Dock Step", V, rbu_dock_step),
        },
        "RearSpoiler": {
            "chase_rack": mod("Chase Rack", P, rs_chase_rack),
            "roll_bar": mod("Roll Bar", L, rs_roll_bar),
            "whale_tail": mod("Whale Tail", M, rs_whale_tail),
            "marker_arch": mod("Marker Arch", S, rs_marker_arch),
            "ladder_rack": mod("Luggage Rack", C, rs_ladder_rack),
            "top_box": mod("Top Box", V, rs_top_box),
        },
        "Roof": {
            "light_bar": mod("Light Bar", P, ro_light_bar),
            "roof_rack": mod("Roof Rack", L, ro_roof_rack),
            "visor": mod("Roof Spoiler", M, ro_visor),
            "crown": mod("Crown", S, ro_crown),
            "taxi_sign": mod("Taxi Sign", C, ro_taxi_sign),
            "aerials": mod("Aerials", V, ro_aerials),
        },
        "Accessory": {
            "whips": mod("Whip Flags", P, ac_whips),
            "tow_mirrors": mod("Tow Mirrors", L, ac_tow_mirrors),
            "slim_mirrors": mod("Slim Mirrors", M, ac_slim_mirrors),
            "air_cans": mod("Air Canisters", S, ac_air_cans),
            "fare_lamps": mod("Fare Lamps", C, ac_fare_lamps),
            "grab_rails": mod("Grab Rails", V, ac_grab_rails),
        },
    }
    for slot in modules.values():
        for m_ in slot.values():
            if m_.get("note") is None:
                m_.pop("note", None)

    def kit(name, culture, e1, e2, st, bo, fb, rb, sp, fbu, rbu, rs, ro, ac):
        return {"name": name, "culture": culture, "modules": {
            "Engine1": e1, "Engine2": e2, "Stabilisers": st, "Boost": bo, "FrontBody": fb, "RearBody": rb,
            "SidePods": sp, "FrontBumper": fbu, "RearBumper": rbu, "RearSpoiler": rs, "Roof": ro, "Accessory": ac}}

    kits = {
        "dune": kit("Dune Runner", P, "ram_single", "bed_turbine", "long_travel", "side_dumps", "flare_nose", "chase_tub",
                    "rock_sliders", "bull_bar", "hitch", "chase_rack", "light_bar", "whips"),
        "skyhigh": kit("Sky High", L, "twin_ram", "twin_barrels", "stilts", "shorty_stacks", "square_body", "flatbed",
                       "toolboxes", "winch_bumper", "step_bar", "roll_bar", "roof_rack", "tow_mirrors"),
        "laidout": kit("Laid Out", M, "slot_scoop", "deck_burner", "tucked_slots", "tail_slot", "smoothie", "laid_bed",
                       "ground_skirts", "air_dam", "roll_pan", "whale_tail", "visor", "slim_mirrors"),
        "palace": kit("Chrome Palace", S, "six_pack", "quad_chrome", "dually_vectors", "chrome_stacks", "flat_face", "show_deck",
                      "saddle_tanks", "chrome_blade", "lamp_board", "marker_arch", "crown", "air_cans"),
        "checker": kit("Checker Line", C, "cab_trio", "over_under", "spats", "tail_cans", "round_nose", "canopy",
                       "running_boards", "push_bar", "taxi_rail", "ladder_rack", "taxi_sign", "fare_lamps"),
        "courier": kit("Last Mile", V, "doghouse", "tail_three", "box_lifts", "fishtails", "stub_nose", "parcel_box",
                       "kerb_steps", "front_rack", "dock_step", "top_box", "aerials", "grab_rails"),
    }

    cockpits = {
        "single_cab": {"name": "Single Cab", "culture": P, "kit": "dune", "parts": cab_single()},
        "crew_cab": {"name": "Crew Cab", "culture": L, "kit": "skyhigh", "parts": cab_crew()},
        "kei_cab": {"name": "Kei Cab", "culture": M, "kit": "laidout", "parts": cab_kei()},
        "cab_over": {"name": "Cab-Over", "culture": S, "kit": "palace", "parts": cab_over()},
        "checker_cab": {"name": "Checker Cab", "culture": C, "kit": "checker", "parts": cab_checker()},
        "van_nose": {"name": "Van Nose", "culture": V, "kit": "courier", "parts": cab_van()},
    }

    paint = {
        "dune": {"primary": "#e2742b", "secondary": "#efe6d2", "neon": "#ffd24a"},
        "skyhigh": {"primary": "#2f7d3a", "secondary": "#d6d2c4", "neon": "#c8ff5a"},
        "laidout": {"primary": "#19b8a6", "secondary": "#ff4fa3", "neon": "#ff9ad8"},
        "palace": {"primary": "#7a1230", "secondary": "#dfe5ec", "neon": "#ffb347"},
        "checker": {"primary": "#ffc915", "secondary": "#1c1d22", "neon": "#fff7c0"},
        "courier": {"primary": "#ece8dc", "secondary": "#2a5fc4", "neon": "#ffb020"},
    }
    own = {cid: c["kit"] for cid, c in cockpits.items()}
    swap = {"single_cab": "palace", "crew_cab": "courier", "kei_cab": "dune", "cab_over": "checker", "checker_cab": "skyhigh",
            "van_nose": "laidout"}
    builds = []
    for cid, c in cockpits.items():
        builds.append({"name": "%s, own %s kit" % (c["name"], kits[own[cid]]["name"]), "cockpit": cid, "kit": own[cid],
                       "paint": paint[own[cid]]})
    for cid, c in cockpits.items():
        builds.append({"name": "%s in %s kit" % (c["name"], kits[swap[cid]]["name"]), "cockpit": cid, "kit": swap[cid],
                       "paint": paint[own[cid]]})
    builds += [
        {"name": "Mixed: Kei on stilts", "cockpit": "kei_cab", "kit": "skyhigh",
         "modules": {"Engine2": "bed_turbine", "FrontBody": "smoothie", "Engine1": "slot_scoop", "RearSpoiler": "chase_rack", "Boost": "chrome_stacks"},
         "paint": {"primary": "#7b4fd6", "secondary": "#f2f2f2", "neon": "#9dffb0"}},
        {"name": "Mixed: hot-rod taxi", "cockpit": "checker_cab", "kit": "checker",
         "modules": {"Engine1": "ram_single", "Engine2": "quad_chrome", "Stabilisers": "tucked_slots", "Boost": "chrome_stacks",
                     "RearBody": "chase_tub", "RearSpoiler": "whale_tail", "FrontBumper": "air_dam"},
         "paint": {"primary": "#15171c", "secondary": "#ffc915", "neon": "#ffe98a"}},
        {"name": "Mixed: cab-over prerunner", "cockpit": "cab_over", "kit": "dune",
         "modules": {"FrontBody": "flat_face", "Engine1": "twin_ram", "Engine2": "twin_barrels", "Boost": "tail_cans", "Roof": "crown"},
         "paint": {"primary": "#d8dde3", "secondary": "#c9302c", "neon": "#ff6a4a"}},
    ]

    return {
        "id": "hauler", "displayName": "Hauler",
        "tagline": "Trucks and vans on jets: a tall cab, a nose with a turbine standing on the hood, a bed or box with a big engine in it, and four lift jets on arms.",
        "standard": standard(), "cockpits": cockpits, "kits": kits, "modules": modules, "builds": builds,
    }


def main():
    spec = build_spec()
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.normpath(os.path.join(here, "..", "specs", "hauler.json"))
    with open(out, "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=1)
        f.write("\n")
    n_mod = sum(len(v) for v in spec["modules"].values())
    print("wrote %s: %d cockpits, %d kits, %d modules, %d builds" % (out, len(spec["cockpits"]), len(spec["kits"]), n_mod, len(spec["builds"])))


if __name__ == "__main__":
    main()
