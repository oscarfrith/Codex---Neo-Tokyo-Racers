"""Apex frame class (circuit racers), round 2 blockout generator. Design exploration only.

Writes scripts/vehicle_blockouts/specs/apex.json. Run from the repo root:

    py -3 scripts/vehicle_blockouts/gen/apex.py            write the spec
    py -3 scripts/vehicle_blockouts/gen/apex.py --report   also print part counts and distinctness pairs

Root space: +X right, +Y up, forward is -Z. Units are studs.
Layout: a central tub (cockpit) with a full-size bulkhead at each end, a nose and front wing
ahead of it, sidepods beside it with a shoulder jet on each, an engine deck behind it carrying
the power unit, afterburner, diffuser and rear wing, and four corner thrusters.
Every nose and deck starts at the full bulkhead section and tapers to its own shape.
No round part is wider than it is long: the generator refuses to write the spec otherwise.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "specs", "apex.json"))

# ----------------------------------------------------------------------------- datums
HOVER = -2.0        # hover plane (ground)
SILL = 0.0          # tub underside, deck underside
BELT = 1.4          # beltline: tub waist, sidepod top, engine deck top
RIM = 2.2           # cockpit rim
TUB_X = 1.75        # tub half width: every side pad sits on this plane
BH_F = -8.0         # front bulkhead plane (nose seam)
BH_R = 3.0          # rear bulkhead plane (engine deck seam)
DECK_END = 12.0     # rear face of every engine deck (afterburner seam)
ST_F = -6.5         # front wishbone station on the tub side
ST_R = 8.0          # rear wishbone station on the engine deck
HARD_X = 4.0        # rear hardpoint plane on the engine deck
NAC_X = 5.9         # default thruster axis
NAC_Y = 0.5
PAD_X0, PAD_X1 = 2.6, 4.2     # shoulder pad (top of every sidepod, at BELT)
PAD_Z0, PAD_Z1 = -1.5, 1.5
KEEL_Z0, KEEL_Z1 = -11.4, -10.4   # keel pad under every nose (front wing seam), underside at Y -0.5
WPAD_X0, WPAD_X1 = 2.0, 2.8       # wing pads on every deck top
WPAD_Z0, WPAD_Z1 = 10.1, 11.5
PYLON_X = 2.4                     # rear wing pylon centre line
ENG_TOP = 3.9                     # top of the power unit envelope
WING_Y = 4.0                      # underside of the rear wing zone
SH_Z = 4.6                        # rear end of the deck shoulder (the deck falls from the rim to the beltline by here)
EM_F0, EM_F1 = 4.8, 5.9           # front engine mount on every deck top
EM_R0, EM_R1 = 9.7, 10.8          # rear engine mount on every deck top
CAB_Z0 = -7.5                     # front of the cabin box
NS = -8.25                        # every nose starts here at the full bulkhead section
DS = 3.25                         # every deck starts here at the full bulkhead section


# ----------------------------------------------------------------------------- part helpers
def r3(v):
    return [round(float(x), 3) for x in v]


def P(shape, size, pos, rot=None, ch="primary", m=False, note=None):
    d = {"shape": shape, "size": r3(size), "pos": r3(pos)}
    if rot is not None and any(abs(a) > 1e-6 for a in rot):
        d["rot"] = r3(rot)
    d["ch"] = ch
    if m:
        d["mirror"] = True
    if note:
        d["note"] = note
    return d


def box(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None):
    """Block from its extents."""
    return P("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], None, ch, m, note)


def cbox(w, y0, y1, z0, z1, ch="primary", note=None):
    """Block centred on X with width w."""
    return box(-w / 2, w / 2, y0, y1, z0, z1, ch, False, note)


_WEDGE = {("front", "bottom"): [0, 0, 0], ("rear", "bottom"): [0, 180, 0],
          ("rear", "top"): [180, 0, 0], ("front", "top"): [0, 0, 180]}


def wedge(x0, x1, y0, y1, z0, z1, thin="front", base="bottom", ch="primary", m=False, note=None):
    """Wedge sloping along Z. thin = which end is the thin edge; base = which face is flat."""
    return P("wedge", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2],
             _WEDGE[(thin, base)], ch, m, note)


_PWEDGE = {("front", "in"): [0, 0, -90], ("rear", "in"): [0, 180, 90],
           ("front", "out"): [0, 0, 90], ("rear", "out"): [0, 180, -90]}


def pwedge(x0, x1, y0, y1, z0, z1, thin="front", base="in", ch="primary", m=True):
    """Plan-view taper for a +X side piece. base 'in' = flat face at x0, 'out' = flat face at x1."""
    return P("wedge", [y1 - y0, x1 - x0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2],
             _PWEDGE[(thin, base)], ch, m)


def tz(d, x, y, z0, z1, ch="primary", m=False):
    """Tube along the car."""
    return P("cyl_z", [d, d, z1 - z0], [x, y, (z0 + z1) / 2], None, ch, m)


def ty(d, x, y0, y1, z, ch="primary", m=False):
    """Upright tube."""
    return P("cyl_y", [d, y1 - y0, d], [x, (y0 + y1) / 2, z], None, ch, m)


def tx(d, x0, x1, y, z, ch="primary"):
    """Cross tube (thin only: nothing that could read as a wheel)."""
    return P("cyl_x", [x1 - x0, d, d], [(x0 + x1) / 2, y, z], None, ch)


def axis_dir(pitch, yaw=0.0):
    p, w = math.radians(pitch), math.radians(yaw)
    return (math.sin(w) * math.cos(p), -math.sin(p), math.cos(w) * math.cos(p))


def along(start, pitch, dist, yaw=0.0):
    d = axis_dir(pitch, yaw)
    return tuple(start[i] + d[i] * dist for i in range(3))


def ttz(d, length, start, pitch, ch="primary", m=False, yaw=0.0):
    """Tilted tube. start = centre of its front end. Positive pitch points the rear end down, positive yaw points it outboard."""
    return P("cyl_z", [d, d, length], along(start, pitch, length / 2, yaw), [pitch, yaw, 0], ch, m)


def tty(d, length, top, lean, ch="primary", m=False):
    """Upright tube hanging from 'top', its lower end leaning back by 'lean' degrees."""
    a = math.radians(lean)
    c = (top[0], top[1] - math.cos(a) * length / 2, top[2] + math.sin(a) * length / 2)
    return P("cyl_y", [d, length, d], c, [-lean, 0, 0], ch, m)


def tblock(size, pos, pitch, ch="primary", m=False):
    """Flat block pitched about X. Negative pitch lifts the rear edge."""
    return P("block", size, pos, [pitch, 0, 0], ch, m)


def rod(a, b, t, w, ch="detail", m=False):
    """Thin block from point a to point b. t = thickness (up), w = width (across)."""
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    rz = math.degrees(math.asin(dy / length))
    ry = math.degrees(math.atan2(-dz, dx))
    return P("block", [length, t, w], [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2], [0, ry, rz], ch, m)


def ball(d, x, y, z, ch="driver"):
    return P("ball", [d, d, d], [x, y, z], None, ch)


def face_z(d, x, y, z_front, m=False):
    """Dark recessed intake face: a dark core that shows 0.06 at the mouth of a tube."""
    return tz(d, x, y, z_front - 0.06, z_front - 0.06 + d * 1.1, "detail", m)


def glow_z(d, x, y, z_exit, flame, m=False):
    """Thrust glow that starts inside its nozzle (so the tube is longer than wide) and stands 'flame' proud of z_exit."""
    return tz(d, x, y, z_exit + flame - max(flame, d * 1.1), z_exit + flame, "thrust", m)


def turbine(x, y, z0, z1, d, body="primary", m=True, nozzle=1.2, nozzle_d=None, flame=0.7):
    """Straight jet: body-colour lip, dark recessed face, splitter blade, dark nozzle, glow. No collar, no hub."""
    nd = nozzle_d or d * 0.75
    nl = max(nozzle, nd * 1.1)
    return [tz(d, x, y, z0, z1, body, m), face_z(d - 0.25, x, y, z0, m),
            tz(nd, x, y, z1, z1 + nl, "detail", m), glow_z(nd * 0.72, x, y, z1 + nl, flame, m),
            box(x - d * 0.46, x + d * 0.46, y - 0.05, y + 0.05, z0 - 0.35, z0 + 0.3, "secondary", m)]


# ----------------------------------------------------------------------------- frame standard
def standard():
    return {
        "cockpitEnvelope": [
            {"min": [-TUB_X, -1.0, BH_F], "max": [TUB_X, RIM, BH_R], "note": "tub and keel"},
            {"min": [-2.4, RIM, CAB_Z0], "max": [2.4, 4.6, BH_R], "note": "cabin: screen, halo, canopy, cage, airbox, roof"},
        ],
        "datums": {"beltline": BELT, "sill": SILL, "hoverPlane": HOVER, "rim": RIM,
                   "frontBulkheadZ": BH_F, "rearBulkheadZ": BH_R, "deckEndZ": DECK_END,
                   "tubHalfWidth": TUB_X, "frontStationZ": ST_F, "rearStationZ": ST_R, "rearHardpointX": HARD_X,
                   "bulkheadSection": "X +-1.75, Y 0..2.2 at Z -8 and Z 3"},
        "pads": {
            "cockpit": ["front bulkhead Z -8, full section X +-1.75, Y 0..2.2", "rear bulkhead Z 3, full section X +-1.75, Y 0..2.2",
                        "wishbone plates X +-1.75, Y 0.35..1.75, Z -7.5..-5.5", "sidepod rails X +-1.75, Y 0.2..1.25, Z -3.3..2.7"],
            "FrontBody": ["shoulder at Z -8.25, full section, behind a dark collar", "keel underside Y -0.5, X +-0.6, Z -11.4..-10.4 (front wing)"],
            "SidePods": ["shoulder pad top Y 1.4, X 2.6..4.2, Z -1.5..1.5 (shoulder jet)"],
            "RearBody": ["shoulder at Z 3.25, full section, falling to the beltline by Z 4.6",
                         "engine mounts top Y 1.4, X +-1.1, Z 4.8..5.9 and 9.7..10.8", "wing pads top Y 1.4, X 2.0..2.8, Z 10.1..11.5",
                         "frame pads top Y 1.4, X 2.0..2.4, Z 4.8..5.4 (front posts of a top wing)",
                         "rear face Z 12, X +-1.5, Y 0.3..1.3 (afterburner)", "underside Y 0.1, Z 7..11.8 (diffuser)",
                         "rear hardpoints X +-4.0, Y 0.3..1.3, Z 7.2..8.8, on a shelf Z 6.4..9.6 (rear thrusters)"],
        },
        "slots": {
            "Engine1": {"label": "Power Unit",
                        "envelope": [{"min": [-2.0, RIM, BH_R], "max": [2.0, ENG_TOP, SH_Z]},
                                     {"min": [-2.0, BELT, SH_Z], "max": [2.0, ENG_TOP, 13.2]}],
                        "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 5, 6]},
            "Engine2": {"label": "Shoulder Jets",
                        "envelope": {"min": [2.4, BELT, -3.6], "max": [4.6, 3.0, 4.5], "mirror": True},
                        "anchor": {"to": "SidePods", "face": "-y"}, "explode": [3.5, 4, 0]},
            "Stabilisers": {"label": "Corner Thrusters",
                            "envelope": [{"min": [4.0, -1.6, -10.0], "max": [7.5, 2.6, -3.6], "mirror": True},
                                         {"min": [TUB_X, 0.2, -7.7], "max": [4.0, 1.9, -3.6], "mirror": True},
                                         {"min": [4.0, -1.6, 4.6], "max": [7.5, 2.6, 11.5], "mirror": True}],
                            "anchor": [{"to": "cockpit", "face": "-x"}, {"to": "RearBody", "face": "-x"}],
                            "explode": [5, -1, 0]},
            "Boost": {"label": "Afterburner",
                      "envelope": [{"min": [-3.4, 0.2, DECK_END], "max": [3.4, BELT, 14.6]},
                                   {"min": [2.0, BELT, DECK_END], "max": [3.4, 3.4, 14.6], "mirror": True},
                                   {"min": [2.0, 0.2, 14.6], "max": [3.4, 1.5, 16.0], "mirror": True}],
                      "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, 0, 11]},
            "FrontBody": {"label": "Nose",
                          "envelope": {"min": [-3.8, -0.5, -13.6], "max": [3.8, RIM, BH_F]},
                          "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -5]},
            "RearBody": {"label": "Engine Deck",
                         "envelope": [{"min": [-4.0, SILL, BH_R], "max": [4.0, BELT, DECK_END]},
                                      {"min": [-2.0, BELT, BH_R], "max": [2.0, RIM, SH_Z]},
                                      {"min": [2.0, BELT, 5.4], "max": [4.0, 2.6, 9.6], "mirror": True},
                                      {"min": [2.8, BELT, 9.6], "max": [4.0, 2.6, DECK_END], "mirror": True},
                                      {"min": [3.4, SILL, DECK_END], "max": [5.0, 2.2, 14.6], "mirror": True}],
                         "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, -1, 5]},
            "SidePods": {"label": "Sidepods",
                         "envelope": [{"min": [TUB_X, -1.0, -3.6], "max": [4.6, BELT, 3.0], "mirror": True},
                                      {"min": [4.6, -1.3, -3.6], "max": [6.4, RIM, 3.0], "mirror": True},
                                      {"min": [TUB_X, BELT, -3.6], "max": [2.4, RIM, 3.0], "mirror": True}],
                         "anchor": {"to": "cockpit", "face": "-x"}, "explode": [3.5, -3.5, 0]},
            "FrontBumper": {"label": "Front Wing",
                            "envelope": [{"min": [-7.3, -1.5, -14.0], "max": [7.3, -0.5, -10.2]},
                                         {"min": [3.9, -0.5, -14.0], "max": [7.3, 1.8, -10.2], "mirror": True}],
                            "anchor": {"to": "FrontBody", "face": "+y"}, "explode": [0, -3, -9]},
            "RearBumper": {"label": "Diffuser",
                           "envelope": [{"min": [-4.0, -1.3, 6.5], "max": [4.0, SILL, DECK_END]},
                                        {"min": [-3.4, -1.3, DECK_END], "max": [3.4, 0.2, 14.6]},
                                        {"min": [3.4, -1.3, DECK_END], "max": [5.0, SILL, 14.6], "mirror": True}],
                           "anchor": {"to": "RearBody", "face": "+y"}, "explode": [0, -5, 8]},
            "RearSpoiler": {"label": "Rear Wing",
                            "envelope": [{"min": [-6.6, WING_Y, 9.6], "max": [6.6, 6.8, 14.6]},
                                         {"min": [WPAD_X0, BELT, 9.6], "max": [WPAD_X1, WING_Y, DECK_END], "mirror": True},
                                         {"min": [-5.2, 4.8, -3.5], "max": [5.2, 7.6, 9.6]},
                                         {"min": [2.0, BELT, 4.6], "max": [2.4, 4.8, 5.4], "mirror": True},
                                         {"min": [2.0, 2.6, 5.4], "max": [2.4, 4.8, 9.6], "mirror": True},
                                         {"min": [5.0, -1.0, 11.6], "max": [6.6, WING_Y, 14.6], "mirror": True}],
                            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 8, 10]},
        },
    }


# ----------------------------------------------------------------------------- cockpits
def tub(open_from=None, open_to=None, open_w=0.95, hull=True):
    """The chassis every cockpit shares: a full-section bulkhead frame at each end (X +-1.75, Y 0..2.2) and the
    four side pads. The body between the frames is 3.4 wide; pass open_from/open_to to cut a cockpit opening."""
    out = [
        cbox(3.5, 0.0, RIM, BH_F, BH_F + 0.3, "primary", "pad: front bulkhead, full section"),
        cbox(3.5, 0.0, RIM, BH_R - 0.3, BH_R, "primary", "pad: rear bulkhead, full section"),
        box(1.7, TUB_X, 0.35, 1.75, -7.5, -5.5, "detail", True, "pad: wishbone plate"),
        box(1.7, TUB_X, 0.2, 1.25, -3.3, 2.7, "detail", True, "pad: sidepod rail"),
    ]
    if not hull:
        return out
    if open_from is None:
        out.append(cbox(3.4, 0.0, RIM, -7.7, 2.7))
    else:
        out += [cbox(3.4, 0.0, BELT, -7.7, 2.7), cbox(3.4, BELT, RIM, -7.7, open_from), cbox(3.4, BELT, RIM, open_to, 2.7),
                box(open_w, 1.7, BELT, RIM, open_from, open_to, m=True),
                cbox(2 * open_w, BELT, 1.48, open_from, open_to, "detail")]
    return out


def cockpit_formula():
    """Open cockpit under a wide halo, tall airbox on an engine-cover shoulder at the back."""
    return tub(-4.0, 0.6) + [
        cbox(1.8, -0.3, 0.0, -7.6, 2.6, "detail"),                      # plank
        wedge(-0.25, 0.25, -1.0, -0.3, -7.6, -6.2, "front", "top", "detail"),   # bib keel
        cbox(0.5, -1.0, -0.3, -6.2, -2.0, "detail"),
        cbox(1.2, RIM, 2.26, -7.4, -5.2, "secondary"),                  # scuttle stripe
        wedge(-0.9, 0.9, RIM, 2.75, -5.0, -4.0, ch="glass"),            # aero screen
        rod((0, 2.2, -4.3), (0, 3.12, -3.2), 0.25, 0.25, "secondary"),  # halo centre pillar
        cbox(2.7, 3.0, 3.25, -3.3, -3.0, "secondary"),                  # halo front arc
        box(1.1, 1.35, 3.0, 3.25, -3.1, 0.75, "secondary", True),       # halo arms
        box(1.1, 1.35, RIM, 3.05, 0.5, 0.75, "secondary", True),        # halo feet
        cbox(1.3, 1.5, 2.4, -1.4, 0.0, "driver"), ball(1.1, 0, 2.9, -0.6),
        cbox(1.6, RIM, 3.0, 0.6, 1.5, "secondary"),                     # headrest
        cbox(2.6, RIM, 3.0, 1.5, 2.95),                                 # engine-cover shoulder
        cbox(1.5, 3.0, 4.6, 0.9, 2.1),                                  # tall airbox
        cbox(1.2, 3.25, 4.4, 0.82, 0.9, "detail"),                      # airbox mouth
        wedge(-0.75, 0.75, 3.0, 4.6, 2.1, 2.95, thin="rear"),           # airbox tail
        box(0.75, 0.95, 3.6, 3.8, 1.2, 1.9, "secondary", True),         # camera pods
        cbox(0.3, 2.35, 2.9, 2.95, 3.0, "neon"),                        # rain light
        box(1.0, 1.9, 2.3, 2.42, -3.9, -3.75, "detail", True),          # mirror stalks
        box(1.7, 2.35, 2.25, 2.7, -4.0, -3.75, "secondary", True),      # mirrors
    ]


def cockpit_cigar():
    """Round hull with a round coaming hump, wraparound screen, exposed driver and a long tapered headrest."""
    return tub(hull=False) + [
        tz(2.2, 0.6, 1.1, -7.7, 2.7, m=True), cbox(1.2, 0.0, RIM, -7.7, 2.7),     # round-shouldered hull, 3.4 wide
        cbox(0.6, -0.25, 0.0, -6.0, 2.0, "detail"),                     # skid
        wedge(-1.1, 1.1, RIM, 2.85, -7.3, -5.4),                        # fairing up to the hump
        tz(2.6, 0, 1.6, -5.4, 0.9),                                     # round coaming hump, top at Y 2.9
        cbox(1.5, 2.8, 2.93, -2.0, 0.4, "detail"),                      # cockpit opening
        tblock([2.3, 0.75, 0.12], [0, 3.2, -2.3], 25, "glass"),         # wraparound screen
        box(1.1, 1.22, 2.75, 3.45, -2.2, -0.9, "glass", True),
        cbox(1.3, 2.4, 3.2, -1.1, -0.1, "driver"), ball(1.1, 0, 3.65, -0.5),
        cbox(1.6, RIM, 2.9, 0.9, 2.9),                                  # headrest base
        wedge(-0.8, 0.8, 2.9, 3.95, 0.3, 2.9, thin="rear"),             # long tapered headrest
        cbox(0.6, 2.86, 2.95, -5.3, -2.5, "secondary"),                 # stripe
        box(1.2, 1.9, 2.95, 3.25, -2.45, -2.3, "secondary", True),      # mirrors
    ]


def cockpit_prototype():
    """Closed bubble set far forward, long fastback, small dorsal fin, deep flat-floor hull."""
    return tub() + [
        cbox(3.4, -1.0, 0.0, -6.0, 1.2),                                # deep hull
        wedge(-1.7, 1.7, -1.0, 0.0, -7.8, -6.0, "front", "top"),        # rising chin
        wedge(-1.7, 1.7, -1.0, 0.0, 1.2, 2.9, "rear", "top"),           # rising tail: the belly ends at the sill
        wedge(-1.8, 1.8, RIM, 3.7, -7.2, -4.2, ch="glass"),             # long raked windscreen
        cbox(3.6, RIM, 3.7, -4.2, -1.6, "glass"),                       # bubble side glass
        cbox(3.0, 3.7, 3.88, -4.4, -1.4),                               # roof
        box(1.7, 1.85, RIM, 3.7, -1.6, -1.3, m=True),                   # B pillars
        wedge(-1.8, 1.8, RIM, 3.88, -1.4, 2.95, thin="rear"),           # long fastback
        cbox(1.0, 3.88, 4.25, -3.4, -1.6, "secondary"),                 # roof scoop
        cbox(0.8, 3.92, 4.2, -3.48, -3.4, "detail"),
        wedge(-0.09, 0.09, 2.6, 4.1, -0.2, 1.4, ch="secondary"),        # dorsal fin
        cbox(0.18, 2.3, 4.1, 1.4, 2.98, "secondary"),
        cbox(2.4, RIM, 2.32, 2.6, 2.98, "neon"),                        # tail light bar
    ]


def cockpit_wingcar():
    """Driver far forward, tall periscope airbox right behind the head, wide flat engine cover to the rear."""
    return tub(-6.3, -4.0) + [
        cbox(2.4, -0.3, 0.0, -7.6, 2.6, "detail"),                      # plank
        tblock([2.5, 0.6, 0.12], [0, 2.5, -6.5], 35, "glass"),          # wrap screen
        box(0.95, 1.7, RIM, 2.55, -6.3, -4.0, m=True),                  # coaming
        cbox(1.3, 1.5, 2.5, -5.6, -4.5, "driver"), ball(1.1, 0, 2.95, -5.0),
        cbox(1.3, RIM, 4.55, -3.9, -2.6),                               # periscope airbox
        cbox(1.0, 3.5, 4.4, -3.98, -3.9, "detail"),
        wedge(-0.65, 0.65, 2.9, 4.55, -2.6, 0.4, thin="rear"),          # airbox fairing
        cbox(4.6, RIM, 2.9, -3.2, 2.95),                                # wide flat engine cover
        wedge(0.65, 2.3, RIM, 2.9, -4.2, -3.2, m=True),                 # cover leading edge
        box(0.9, 2.0, 2.9, 2.96, -2.2, 1.6, "secondary", True),         # flush intakes
        box(1.0, 1.9, 2.96, 3.02, -1.6, -1.3, "detail", True), box(1.0, 1.9, 2.96, 3.02, -0.2, 0.1, "detail", True),
        box(2.3, 2.36, 2.35, 2.75, -3.0, 2.8, "secondary", True),       # cover stripe
    ]


def cockpit_sprint():
    """Upright open cage to the top of the cabin box, big arm-guard boards, tall tail tank."""
    return tub(-1.6, 1.4, 1.0) + [
        cbox(2.6, -0.5, 0.0, -6.6, 2.6, "detail"),                      # belly pan
        cbox(1.6, RIM, 2.26, -7.0, -4.4, "detail"),                     # hood louvres
        wedge(-1.3, 1.3, RIM, 2.9, -3.6, -2.4),                         # cowl
        box(1.45, 1.67, RIM, 4.6, -2.4, -2.18, "detail", True),         # cage front posts
        box(1.45, 1.67, RIM, 4.6, 2.3, 2.52, "detail", True),           # cage rear posts
        box(1.45, 1.67, 4.38, 4.6, -2.4, 2.52, "detail", True),         # cage top rails
        cbox(2.9, 4.38, 4.6, -2.4, -2.18, "detail"), cbox(2.9, 4.38, 4.6, 2.3, 2.52, "detail"),
        rod((1.56, 2.3, 2.3), (1.56, 4.4, 0.0), 0.18, 0.18, "detail", True),    # cage braces
        box(1.7, 1.85, RIM, 3.9, -1.2, 2.6, "secondary", True),         # arm-guard boards
        cbox(3.2, RIM, 3.6, 1.5, 2.9),                                  # tall tail tank
        wedge(-1.6, 1.6, 3.6, 4.3, 1.5, 2.9, thin="rear"),
        cbox(3.3, 4.46, 4.6, -1.4, 2.3, "secondary"),                   # cage roof plate
        cbox(1.4, 2.0, 3.2, 0.2, 1.1, "driver"), ball(1.1, 0, 3.7, 0.5),
    ]


def cockpit_oval():
    """Stock-oval greenhouse: tall, boxy, full width, set back, solid roof with a number panel."""
    return tub() + [
        cbox(3.0, -0.4, 0.0, -7.0, 2.6, "detail"),                      # skid plate
        cbox(1.4, RIM, 2.3, -7.4, -4.8, "detail"),                      # cowl vent
        cbox(4.7, RIM, 2.5, -4.6, 2.95),                                # window sill, wider than the tub
        wedge(-2.2, 2.2, 2.5, 3.95, -4.6, -1.8, ch="glass"),            # raked windscreen
        cbox(4.5, 2.5, 3.95, -1.8, 1.4, "glass"),                       # side windows
        box(2.2, 2.35, 2.5, 3.95, -1.95, -1.65, m=True),                # A posts
        box(2.2, 2.35, 2.5, 3.95, 1.25, 1.6, m=True),                   # B posts
        box(2.25, 2.32, 2.6, 3.85, -1.5, -0.2, "detail", True),         # window nets
        cbox(4.7, 3.95, 4.15, -2.0, 1.6),                               # flat roof
        cbox(2.0, 4.15, 4.21, -1.4, 0.8, "secondary"),                  # roof number panel
        box(0.9, 1.0, 4.15, 4.25, -1.8, 1.4, "detail", True),           # roof rails
        wedge(-2.35, 2.35, 2.5, 4.15, 1.6, 2.95, thin="rear"),          # rear window slope
    ]


# ----------------------------------------------------------------------------- FrontBody: noses
def nose_base(keel_top):
    return [cbox(3.2, 0.2, 2.0, NS, BH_F, "detail", "collar on the front bulkhead (shadow gap)"),
            cbox(1.2, -0.5, keel_top, KEEL_Z0, KEEL_Z1, "detail", "pad: keel for the front wing")]


def nose_needle():
    return nose_base(0.2) + [
        cbox(3.5, 0.1, 1.5, -9.6, NS),                                  # shoulder, full section
        wedge(-1.75, 1.75, 1.5, RIM, -9.6, NS),                         # falls from the rim
        cbox(1.4, 0.1, 1.5, -11.0, -9.6),                               # core
        pwedge(0.7, 1.75, 0.1, 1.5, -11.6, -9.6, thin="front", base="in"),  # cheeks taper in plan
        wedge(-0.7, 0.7, 0.2, 1.5, -13.5, -11.0),                       # long point
        cbox(0.6, 0.15, 0.45, -13.6, -13.25, "secondary"),              # tip
        cbox(0.8, 1.5, 1.56, -11.0, -9.6, "secondary"),                 # stripe
    ]


def nose_radiator():
    return nose_base(0.15) + [
        cbox(3.5, 0.1, RIM, -8.9, NS),                                  # shoulder, full section
        tz(2.1, 0.7, 1.15, -11.6, -8.9, m=True), cbox(1.4, 0.1, RIM, -11.6, -8.9),     # fat round body
        tz(1.7, 0.6, 1.15, -12.5, -10.6, "secondary", True), cbox(1.2, 0.3, 2.0, -12.5, -11.6, "secondary"),
        cbox(2.2, 0.55, 1.75, -12.58, -12.44, "detail"),                # open mouth
        cbox(0.6, RIM - 0.06, RIM, -11.6, -8.9, "secondary"),
    ]


def nose_shovel():
    return nose_base(0.0) + [
        wedge(-3.7, 3.7, 0.0, 1.3, -13.4, -9.4),                        # full-width shovel
        cbox(7.4, 0.0, 1.3, -9.4, NS),
        box(TUB_X, 3.7, 0.0, 1.3, NS, -8.06, m=True),                   # fender ends run back beside the collar
        box(2.0, 3.5, 0.2, 1.1, -8.06, BH_F, "detail", True),           # dark outlet in each fender end
        wedge(-1.75, 1.75, 1.3, RIM, -10.6, NS),                        # centre rises to the full section
        box(2.2, 3.4, 0.3, 0.6, -12.4, -12.0, "neon", True),            # light pods
        cbox(2.0, 0.6, 0.9, -11.3, -10.9, "detail"),                    # intake slot
        box(3.5, 3.7, 1.3, 1.7, -10.5, -8.3, "secondary", True),        # fender edges
    ]


def nose_chisel():
    return nose_base(0.2) + [
        cbox(5.4, 0.2, 0.95, -10.4, NS),                                # broad flat body
        wedge(-2.7, 2.7, 0.2, 0.95, -12.3, -10.4),                      # flat chisel edge
        wedge(-1.75, 1.75, 0.95, RIM, -10.4, NS),                       # centre rises to the full section
        cbox(5.44, 0.4, 0.7, -10.0, -9.0, "secondary"),                 # band
        box(1.9, 2.6, 0.3, 0.85, -8.3, -8.2, "detail", True),           # outlets in the rear corners
    ]


def nose_grille():
    rake = math.degrees(math.atan2(1.9, 0.9))
    return nose_base(0.3) + [
        cbox(2.6, 0.3, RIM, -10.6, NS),                                 # short tall hood
        pwedge(1.3, 1.75, 0.3, RIM, -9.9, NS, thin="front", base="in"), # widens to the full section
        wedge(-1.3, 1.3, 0.3, RIM, -11.5, -10.6),                       # steep upright prow
        tblock([2.0, 0.1, 1.8], [0, 1.3, -11.07], -rake, "detail"),     # grille mesh on the prow
        cbox(1.6, RIM - 0.06, RIM, -10.3, -8.8, "detail"),              # hood louvres
        tx(0.3, -2.6, 2.6, 0.5, -10.9, "secondary"),                    # wide torsion tube
    ]


def nose_bluff():
    return nose_base(0.1) + [
        cbox(5.0, 0.1, 1.7, -10.8, NS),                                 # wide slab body
        wedge(-1.75, 1.75, 1.7, RIM, -10.2, NS),                        # hood bulge up to the full section
        wedge(-2.5, 2.5, 0.1, 1.7, -11.5, -10.8),                       # bluff slanted face
        tblock([3.0, 0.08, 0.9], [0, 0.85, -11.2], -67.6, "detail"),    # grille opening
        box(1.7, 2.3, 0.9, 1.3, -11.36, -11.2, "neon", True),           # lamp panels
        box(1.9, 2.4, 0.3, 1.5, -8.3, -8.2, "detail", True),            # outlets in the rear corners
        cbox(5.04, 0.5, 0.75, -10.6, -8.8, "secondary"),                # side band
    ]


# ----------------------------------------------------------------------------- FrontBumper: front wings
def wing_mount():
    return [cbox(0.9, -0.75, -0.5, -11.3, -10.5, "detail", "pylon under the keel pad")]


def fw_cascade():
    """Sits back under the nose tip, with a painted centre section, so it tucks under short noses too."""
    return wing_mount() + [
        cbox(14.2, -1.35, -1.15, -12.9, -11.3, "secondary"),            # main plane
        cbox(2.4, -1.15, -0.75, -12.5, -10.6, "primary"),               # painted centre section under the keel
        tblock([5.0, 0.15, 1.0], [4.6, -0.85, -11.5], -18, "primary", True),    # flaps
        box(7.0, 7.2, -1.5, 0.3, -13.1, -10.3, "primary", True),        # endplates
        box(5.6, 7.0, 0.0, 0.12, -12.3, -11.1, "secondary", True),      # cascade winglets
    ]


def fw_chin():
    return wing_mount() + [
        cbox(6.4, -1.0, -0.82, -12.4, -11.0, "secondary"),              # small chin blade
        cbox(0.6, -0.82, -0.75, -11.4, -11.0, "detail"),
        box(3.1, 3.25, -1.2, -0.55, -12.5, -10.9, "primary", True),     # end fences
    ]


def fw_splitter():
    return wing_mount() + [
        cbox(13.6, -1.4, -1.2, -13.9, -10.4, "secondary"),              # deep splitter plate
        cbox(1.2, -1.2, -0.75, -11.6, -10.6, "detail"),
        tblock([1.8, 0.12, 1.6], [5.6, 0.3, -12.0], -20, "secondary", True),    # dive planes
        box(6.6, 6.8, -1.4, 0.9, -13.6, -10.4, "primary", True),        # end fences
        cbox(12.0, -1.2, -1.1, -13.9, -13.75, "neon"),                  # leading-edge light
    ]


def fw_plank():
    return wing_mount() + [
        cbox(12.0, -1.0, -0.75, -12.8, -10.8, "primary"),               # one-piece plank
        box(6.0, 6.2, -1.45, 0.8, -13.4, -10.4, "secondary", True),     # big square endplates
        cbox(12.0, -0.75, -0.6, -10.95, -10.8, "secondary"),            # gurney
    ]


def fw_nerf():
    """Two-bar bumper hoop that stands ahead of and wider than a slim nose, over a painted bash plate."""
    return wing_mount() + [
        box(0.6, 0.85, -0.95, -0.7, -13.6, -10.6, "detail", True),      # prongs
        tx(0.35, -3.4, 3.4, -0.85, -13.7, "secondary"),                 # upper bumper bar, ahead of every nose
        tx(0.3, -3.0, 3.0, -1.3, -13.6, "secondary"),                   # lower bar
        box(3.1, 3.4, -1.45, -0.7, -13.85, -13.5, "secondary", True),   # hoop ends
        box(1.5, 1.7, -1.3, -0.85, -13.75, -13.55, "secondary", True),  # uprights
        box(3.15, 3.4, -0.95, -0.7, -13.5, -11.6, "secondary", True),   # returns back to the stub planes
        box(0.85, 3.4, -0.95, -0.8, -12.4, -11.6, "secondary", True),   # stub planes
        cbox(4.0, -1.4, -1.25, -13.3, -10.8, "primary"),                # painted bash plate
        cbox(1.2, -1.25, -0.75, -11.6, -10.8, "detail"),                # plate hanger
    ]


def fw_airdam():
    return wing_mount() + [
        cbox(1.2, -1.0, -0.75, -11.9, -10.6, "detail"),                 # spar
        cbox(8.4, -1.5, -0.6, -12.2, -11.8, "primary"),                 # upright valance, full depth
        cbox(8.8, -1.5, -1.38, -12.9, -11.8, "detail"),                 # short splitter lip
        box(4.0, 4.2, -1.5, -0.6, -11.8, -10.4, "primary", True),       # side returns
        box(1.6, 3.0, -1.25, -0.8, -12.26, -12.2, "detail", True),      # duct openings
    ]


# ----------------------------------------------------------------------------- Stabilisers: corner thrusters
def arms(x_in, st, pod_x, pod_z, y_up=1.1, y_lo=0.45):
    """Wishbone pair from a hardpoint (tub plate or deck hardpoint) to a pod."""
    x_in += 0.12   # the rods are angled, so start them just clear of the hardpoint plane
    return [rod((x_in, y_up, st - 0.6), (pod_x, y_up - 0.2, pod_z - 0.2), 0.12, 0.3, "detail", True),
            rod((x_in, y_lo, st + 0.6), (pod_x, y_lo - 0.1, pod_z + 0.2), 0.12, 0.3, "detail", True)]


def st_vector():
    """One slender round nacelle per corner on wishbones, splitter blade in the mouth, nozzle down and back."""
    out = []
    for zc, x_in, st in ((-7.1, TUB_X, ST_F), (7.9, HARD_X, ST_R)):
        nz = (NAC_X, NAC_Y, zc + 1.1)
        out += [
            tz(1.3, NAC_X, NAC_Y, zc - 2.4, zc + 1.2, "primary", True),         # slender body, lip in body colour
            face_z(1.05, NAC_X, NAC_Y, zc - 2.4, True),                         # dark recessed intake
            box(NAC_X - 0.05, NAC_X + 0.05, NAC_Y - 0.6, NAC_Y + 0.6, zc - 2.85, zc - 2.2, "secondary", True),  # splitter blade
            ttz(1.0, 1.7, nz, 30, "detail", True),                              # vectoring nozzle, down and back
            ttz(0.7, 1.0, along(nz, 30, 1.5), 30, "thrust", True),
            box(NAC_X - 0.06, NAC_X + 0.06, 1.1, 1.8, zc - 0.8, zc + 0.8, "secondary", True),   # fin
        ] + arms(x_in, st, 5.3, zc)
    return out


def st_bullet():
    """Chrome bullets carried high on outrigger beams, each with a lift nozzle hanging under it."""
    out = []
    a = math.radians(20)
    for zc, x_in, st in ((-6.6, TUB_X, ST_F), (8.0, HARD_X, ST_R)):
        x, y = 5.0, 1.3
        top = (x, 1.0, zc + 0.9)
        out += [
            tz(0.95, x, y, zc - 1.6, zc + 1.6, "secondary", True),              # chrome bullet
            tz(0.6, x, y, zc - 2.3, zc - 1.5, "secondary", True),               # stepped nose
            tz(0.3, x, y, zc - 2.9, zc - 2.2, "detail", True),                  # probe
            box(x - 0.3, x + 0.3, y - 0.8, y - 0.4, zc - 1.2, zc - 0.3, "detail", True),    # chin scoop
            tty(0.7, 1.5, top, 20, "detail", True),                             # lift nozzle, down and back
            tty(0.5, 0.7, (x, 1.0 - math.cos(a) * 1.4, zc + 0.9 + math.sin(a) * 1.4), 20, "thrust", True),
            rod((x_in + 0.1, 1.0, st), (4.6, 1.25, zc), 0.2, 0.2, "detail", True),    # outrigger beam
            rod((x_in + 0.1, 0.45, st + 0.6), (4.7, 0.95, zc + 0.5), 0.12, 0.12, "detail", True),     # stay
        ]
    return out


def st_arch():
    """Blanked arch fairings. A solid bridge panel joins the front pair to the tub. The lift jet is a dark
    rectangular duct between the spats: square scoop under the fairing front, canted nozzle out of the back."""
    out = [
        box(1.95, 4.0, 0.3, 1.84, -7.7, -3.7, "primary", True),                 # bridge panel across the front link
        box(TUB_X, 1.95, 0.5, 1.6, -7.5, -3.9, "detail", True),                 # shadow gap at the tub
    ]
    for zc, front in ((-6.9, True), (8.0, False)):
        nz = (5.7, -0.35, zc + 0.9)
        out += [
            box(4.0, 7.2, 0.2, 1.9, zc - 1.6, zc + 1.6, "primary", True),       # arch fairing
            wedge(4.0, 7.2, 0.2, 1.9, zc - 3.0, zc - 1.6, "front", "bottom", "primary", True),
            box(7.0, 7.2, -0.9, 0.2, zc - 1.6, zc + 1.6, "primary", True),      # outer spat
            box(4.0, 4.2, -0.9, 0.2, zc - 1.6, zc + 1.6, "primary", True),      # inner spat
            box(4.9, 6.5, -1.0, 0.2, zc - 2.6, zc + 1.0, "detail", True),       # dark square scoop and duct under the fairing
            ttz(0.9, 1.4, nz, 25, "detail", True),                              # canted nozzle
            ttz(0.65, 0.9, along(nz, 25, 1.2), 25, "thrust", True),
            box(4.6, 6.6, 1.3, 1.5, zc - 2.05, zc - 1.95, "neon", True),        # light strip
            box(4.7, 6.7, 1.9, 2.08, zc - 1.2, zc + 1.2, "detail", True),       # lift vent frame cut into the arch top
            box(5.0, 6.4, 2.08, 2.14, zc - 0.95, zc + 0.95, "thrust", True),    # lift jet glow in the vent
        ]
        if front:
            out += [box(4.0, 7.2, 0.2, 1.1, zc + 1.6, -3.7, "primary", True),   # runs back to the sidepod front
                    wedge(4.0, 7.2, 1.1, 1.9, zc + 1.6, -3.7, "rear", "bottom", "primary", True),
                    box(5.25, 6.15, -0.7, -0.1, zc - 2.66, zc - 2.6, "thrust", True)]   # glow in the front scoop mouth
        else:
            out.append(wedge(4.0, 7.2, 0.2, 1.9, zc + 1.6, zc + 2.8, "rear", "bottom", "primary", True))
    return out


def st_vane():
    """A slim nacelle with a square scoop and a canted nozzle, over an open cascade of three vanes between low rails."""
    out = []
    for zc, x_in, st in ((-6.6, TUB_X, ST_F), (8.0, HARD_X, ST_R)):
        nz = (5.7, 0.5, zc + 0.9)
        out += [
            tz(1.0, 5.7, 0.5, zc - 1.6, zc + 1.0, "primary", True),             # slim nacelle
            box(5.1, 6.3, 0.0, 1.05, zc - 2.3, zc - 1.4, "secondary", True),    # square scoop
            box(5.25, 6.15, 0.15, 0.9, zc - 2.36, zc - 2.3, "detail", True),    # scoop mouth
            ttz(0.9, 1.4, nz, 28, "detail", True),                              # canted nozzle, down and back
            ttz(0.7, 0.9, along(nz, 28, 1.1), 28, "thrust", True),
            box(4.35, 4.55, -1.3, -0.8, zc - 2.0, zc + 2.0, "secondary", True), # low inner rail
            box(6.85, 7.05, -1.3, -0.8, zc - 2.0, zc + 2.0, "secondary", True), # low outer rail
            box(4.55, 6.85, -1.2, -1.0, zc - 1.7, zc + 1.7, "thrust", True),    # glowing burner sheet under the vanes
            box(4.35, 4.55, -0.8, 0.65, st - 0.3, st + 0.3, "detail", True),    # inner hanger
            box(6.85, 7.05, -0.8, 0.5, zc - 0.2, zc + 0.2, "detail", True),     # outer hanger
            box(6.2, 6.85, 0.3, 0.5, zc - 0.2, zc + 0.2, "detail", True),
            box(x_in, 5.2, 0.3, 0.65, st - 0.5, st + 0.5, "detail", True),      # beam to the hardpoint
        ]
        for k in range(3):
            out.append(tblock([2.3, 0.12, 0.9], [5.7, -0.5, zc - 1.1 + k * 1.1], 35, "primary", True))   # open vanes
    return out


def st_stagger():
    """Staggered: a short twin stack behind a shared box intake at the front, a big over-and-under unit at the rear
    (ram scoop on top, jet below)."""
    r = (5.9, -0.2, 9.3)
    out = [
        box(4.45, 6.2, 0.05, 0.95, -9.1, -8.2, "secondary", True),              # shared box intake
        box(4.6, 6.05, 0.2, 0.8, -9.16, -9.1, "detail", True),
        rod((TUB_X + 0.1, 1.1, ST_F), (4.5, 0.7, -7.6), 0.15, 0.3, "detail", True),
        rod((TUB_X + 0.1, 0.45, ST_F), (4.6, 0.4, -6.8), 0.15, 0.3, "detail", True),
        # big over-and-under rear unit
        tz(1.3, 5.9, -0.2, 5.2, 9.4, "primary", True), face_z(1.05, 5.9, -0.2, 5.2, True),
        ttz(0.9, 1.2, r, 28, "detail", True), ttz(0.65, 0.8, along(r, 28, 1.0), 28, "thrust", True),
        box(5.25, 6.55, 0.6, 1.9, 5.4, 6.4, "secondary", True),                 # ram scoop on top
        box(5.4, 6.4, 0.75, 1.75, 5.34, 5.4, "detail", True),
        tz(1.2, 5.9, 1.25, 6.4, 9.8, "secondary", True),                        # ram duct, closed at the back
        tz(0.8, 5.9, 1.25, 9.8, 10.8, "detail", True),
        box(HARD_X, 5.3, 0.3, 0.8, 7.5, 8.5, "detail", True),                   # clamp to the deck hardpoint
    ]
    for x in (4.9, 5.75):
        f = (x, 0.5, -6.1)
        out += [tz(0.7, x, 0.5, -8.3, -6.0, "primary", True),                   # short twin stack
                ttz(0.55, 1.0, f, 30, "detail", True), ttz(0.4, 0.6, along(f, 30, 0.8), 30, "thrust", True)]
    return out


def st_triple():
    """Three small tubes strapped in a pack at each corner, close in on a stub beam."""
    out = []
    for zc, x_in, st in ((-6.6, TUB_X, ST_F), (8.0, HARD_X, ST_R)):
        out += [box(4.5, 6.3, -0.25, 1.3, zc - 0.5, zc + 0.2, "detail", True),         # strap
                box(x_in, 4.6, 0.3, 0.9, st - 0.5, st + 0.5, "detail", True)]           # stub beam to the hardpoint
        for x, y, ch in ((5.0, 0.2, "primary"), (5.8, 0.2, "primary"), (5.4, 0.88, "secondary")):
            n = (x, y, zc + 1.1)
            out += [tz(0.7, x, y, zc - 1.9, zc + 1.2, ch, True), face_z(0.5, x, y, zc - 1.9, True),
                    ttz(0.52, 0.9, n, 28, "detail", True), ttz(0.38, 0.6, along(n, 28, 0.7), 28, "thrust", True)]
    return out


# ----------------------------------------------------------------------------- Engine1: power units
def e1_feet():
    return [cbox(2.2, BELT, 1.6, EM_F0, EM_F1, "detail", "foot on the front engine mount"),
            cbox(2.2, BELT, 1.6, EM_R0, EM_R1, "detail", "foot on the rear engine mount")]


def e1_works():
    """One big stepped turbine, front-set, with a long slim nozzle."""
    return e1_feet() + [
        cbox(2.0, 2.3, 3.65, 3.1, 5.2, "primary"),                      # square intake plenum over the deck shoulder
        cbox(1.6, 2.5, 3.5, 3.02, 3.1, "detail"),                       # intake mouth
        cbox(1.2, 1.6, 2.3, 4.8, 5.2, "detail"),
        tz(2.3, 0, 2.65, 5.2, 8.4, "secondary"),                        # compressor barrel
        tz(1.7, 0, 2.65, 8.4, 10.4, "primary"),                         # combustor
        tz(1.3, 0, 2.6, 10.4, 12.3, "detail"),                          # long nozzle
        glow_z(0.95, 0, 2.6, 12.3, 0.8),
        box(1.1, 1.3, 2.4, 2.9, 5.4, 8.2, "primary", True),             # side strakes
        cbox(0.8, 1.6, 2.0, 9.9, 10.6, "detail"),                       # nozzle saddle on the rear foot
    ]


def e1_stack8():
    """Bare block with eight intake trumpets; two slim pipes run into one centre megaphone."""
    p = (0.75, 2.1, 8.9)
    out = e1_feet() + [
        cbox(2.2, 1.6, 2.5, 4.8, 9.0, "detail"),                        # block
        box(0.4, 1.25, 2.5, 2.9, 5.0, 8.8, "secondary", True),          # heads
        cbox(2.4, 1.6, 1.95, 9.9, 10.4, "detail"),                      # pipe cradle on the rear foot
        ttz(0.45, 2.0, p, 0, "secondary", True, -20),                   # two pipes converge
        tz(1.1, 0, 2.15, 10.6, 12.4, "secondary"),                      # one centre megaphone
        glow_z(0.8, 0, 2.15, 12.4, 0.6),
    ]
    for k in range(4):
        out.append(ty(0.5, 0.8, 2.9, 3.75, 5.4 + k * 1.0, "secondary", True))       # eight intake trumpets
    return out


def e1_twin():
    """Two slim turbines set wide apart, carried high on a spine, with a tall fin between them."""
    return e1_feet() + [
        cbox(0.8, 1.6, 2.5, 5.0, 10.6, "detail"),                       # spine
        box(0.4, 1.3, 1.6, 1.9, 4.9, 5.8, "detail", True),              # saddles on the feet
        box(0.4, 1.3, 1.6, 1.9, 9.8, 10.7, "detail", True),
        tz(1.5, 1.15, 2.55, 5.2, 9.4, "primary", True),                 # lip in body colour
        face_z(1.2, 1.15, 2.55, 5.2, True),                             # dark recessed intake
        box(1.1, 1.2, 1.85, 3.25, 4.7, 5.5, "secondary", True),         # upright splitter blade
        tz(1.15, 1.15, 2.55, 9.4, 10.8, "detail", True),
        glow_z(0.8, 1.15, 2.55, 10.8, 0.9, True),
        wedge(-0.1, 0.1, 2.5, 3.85, 5.2, 9.0, ch="secondary"),          # tall fin between them
    ]


def e1_turbo():
    """Tall turbo box at the front, then a long flat duct to a full-width slot nozzle."""
    out = e1_feet() + [
        cbox(2.6, 1.6, 3.0, 4.8, 7.6),                                  # turbo box
        cbox(0.9, 3.0, 3.6, 5.0, 5.9, "detail"),                        # periscope
        cbox(1.2, 3.4, 3.88, 4.4, 6.0, "secondary"),
        cbox(0.9, 3.5, 3.8, 4.32, 4.4, "detail"),                       # periscope mouth
        wedge(-1.3, 1.3, 2.1, 3.0, 7.6, 8.8, thin="rear"),
        cbox(3.6, 1.6, 2.1, 7.6, 12.0, "secondary"),                    # flat duct
        cbox(3.7, 1.55, 2.15, 11.8, 12.3, "detail"),                    # slot nozzle
        cbox(3.3, 1.7, 2.0, 12.3, 13.0, "thrust"),
    ]
    for k in range(3):
        out.append(cbox(2.0, 3.0, 3.06, 6.2 + k * 0.45, 6.45 + k * 0.45, "detail"))    # louvres
    return out


def e1_quad():
    """Four small jets spread wide, two over two, rear-set around a tall injector scoop."""
    return e1_feet() + [
        cbox(1.2, 1.6, 2.1, 4.8, 7.6, "detail"),                        # low manifold spine
        cbox(1.4, 2.1, 3.85, 6.2, 8.4, "secondary"),                    # tall injector scoop
        cbox(1.0, 2.9, 3.7, 6.1, 6.22, "detail"),
        cbox(1.6, 1.6, 3.6, 8.4, 11.4, "detail"),                       # core between the jets
        tz(1.1, 1.3, 2.05, 7.6, 12.2, "primary", True),
        tz(1.1, 1.3, 3.25, 7.6, 12.2, "primary", True),
        glow_z(0.75, 1.3, 2.05, 12.2, 0.7, True),
        glow_z(0.75, 1.3, 3.25, 12.2, 0.7, True),
    ]


def e1_bigbore():
    """Low flat cowl with a square air box, then one very fat rear-set nozzle."""
    return e1_feet() + [
        cbox(3.4, 1.6, 2.3, 4.8, 9.4),                                  # low flat cowl
        cbox(2.0, 2.3, 2.9, 5.2, 7.2, "secondary"),                     # square air box
        cbox(1.7, 2.4, 2.8, 5.12, 5.2, "detail"),
        box(1.2, 1.6, 2.3, 2.36, 7.6, 9.0, "detail", True),             # cowl louvres
        tz(2.2, 0, 2.55, 9.4, 11.9, "secondary"),                       # fat burner can
        tz(1.9, 0, 2.55, 10.4, 12.5, "detail"),                         # nozzle
        glow_z(1.5, 0, 2.55, 12.5, 0.6),
    ]


# ----------------------------------------------------------------------------- Engine2: shoulder jets
def e2_turbines():
    """One long round turbine a side, outboard, full length of the sidepod."""
    return [box(3.2, 4.2, BELT, 1.62, -1.2, 1.2, "detail", True)] + turbine(3.85, 2.25, -3.1, 2.6, 1.4, "primary", True, 1.2, 1.0, 0.6)


def e2_bullets():
    """Chrome bullet on a pylon, inboard and high: bell intake, fat body, megaphone tail."""
    x, y = 3.2, 2.2
    return [
        box(2.8, 3.6, BELT, 1.6, -0.6, 0.8, "detail", True),            # pylon
        tz(1.5, x, y, -2.6, -1.0, "secondary", True),                   # bell intake
        face_z(1.2, x, y, -2.6, True),
        tz(0.3, x, y, -3.3, -2.5, "detail", True),                      # probe
        tz(1.3, x, y, -1.0, 1.4, "secondary", True),                    # fat chrome body
        tz(0.8, x, y, 1.4, 2.6, "detail", True),                        # waist
        tz(1.1, x, y, 2.4, 3.7, "secondary", True),                     # megaphone
        glow_z(0.8, x, y, 3.7, 0.5, True),
    ]


def e2_slots():
    """Flat wide duct with an open raised scoop at the front and a kicked-up slot nozzle at the back."""
    return [
        box(2.8, 4.2, BELT, 1.5, -1.4, 1.4, "detail", True),
        box(2.5, 4.5, 1.5, 2.2, -3.4, 2.6, "primary", True),            # flat duct floor and body
        box(2.5, 2.7, 2.2, 2.75, -3.4, -1.6, "primary", True),          # scoop cheeks
        box(4.3, 4.5, 2.2, 2.75, -3.4, -1.6, "primary", True),
        box(2.5, 4.5, 2.75, 2.95, -3.4, -1.6, "primary", True),         # scoop hood
        box(2.7, 4.3, 2.2, 2.75, -2.4, -1.6, "detail", True),           # dark throat
        wedge(2.5, 4.5, 2.2, 2.95, -1.6, 0.6, "rear", "bottom", "primary", True),   # hood fairing
        wedge(2.5, 4.5, 2.2, 2.9, 1.5, 2.6, "front", "bottom", "primary", True),    # kick-up
        box(2.6, 4.4, 2.0, 2.9, 2.6, 3.6, "detail", True),              # slot nozzle
        box(2.8, 4.2, 2.15, 2.75, 3.6, 4.3, "thrust", True),            # tall slot glow, above the deck haunch
    ]


def e2_stacks():
    """Short fat compressor drum, rear-set, with a horn in front, an intercooler on the side and a long nozzle."""
    x, y = 3.4, 2.25
    return [
        box(2.9, 4.1, BELT, 1.56, -0.4, 1.4, "detail", True),
        tz(1.4, x, y, -0.2, 2.2, "primary", True),                      # compressor body, longer than wide
        tz(1.0, x, y, -1.8, -0.2, "secondary", True),                   # intake horn
        face_z(0.75, x, y, -1.8, True),
        box(4.1, 4.55, 1.6, 2.7, -0.4, 1.8, "secondary", True),         # intercooler
        box(4.55, 4.6, 1.7, 2.6, -0.2, 1.6, "detail", True),
        tz(0.95, x, y, 2.2, 3.7, "detail", True),                       # long nozzle
        glow_z(0.7, x, y, 3.7, 0.6, True),
    ]


def e2_shorties():
    """Two short barrels a side, forward-set, each with an upright ram tube."""
    out = [box(2.6, 4.4, BELT, 1.58, -1.4, 0.4, "detail", True)]
    for x in (2.95, 4.05):
        out += [
            tz(0.85, x, 2.0, -3.3, 0.2, "primary", True),
            ty(0.45, x, 2.3, 2.95, -2.7, "secondary", True),            # ram tube
            tz(0.6, x, 2.0, 0.2, 0.9, "detail", True),
            tz(0.42, x, 2.0, 0.9, 1.4, "thrust", True),
        ]
    return out


def e2_sidedump():
    """Side dump, rear-set: a tall square scoop, a short body, and a big nozzle turned fully sideways so it fires
    out over the sidepod edge."""
    return [
        box(2.8, 4.0, BELT, 1.65, -0.2, 1.4, "detail", True),           # foot on the rear half of the pad
        box(2.5, 3.7, 1.65, 3.0, 0.0, 0.9, "secondary", True),          # tall square scoop
        box(2.65, 3.55, 2.1, 2.85, -0.06, 0.0, "detail", True),
        tz(1.2, 3.1, 2.2, 0.9, 3.2, "primary", True),                   # short body
        box(2.5, 3.7, 1.65, 2.75, 3.2, 4.3, "detail", True),            # elbow box
        ttz(1.0, 1.1, (3.4, 2.2, 3.75), 0, "detail", True, 90),         # big nozzle, fully sideways
        ttz(0.72, 0.8, (3.8, 2.2, 3.75), 0, "thrust", True, 90),
    ]


# ----------------------------------------------------------------------------- Boost: afterburners
def boost_plate(w=3.0):
    return [cbox(w, 0.3, 1.3, DECK_END, DECK_END + 0.2, "detail", "plate on the deck rear face")]


def b_twin_cans():
    return boost_plate() + [
        box(1.5, 2.3, 0.9, 1.3, 12.2, 12.8, "detail", True),            # beams out from the plate
        box(2.2, 3.2, 0.9, 1.7, 12.2, 12.8, "detail", True),            # brackets up to the cans
        tz(1.35, 2.7, 2.25, 12.2, 14.0, "secondary", True),             # two big cans high beside the main nozzle
        tz(1.15, 2.7, 2.25, 13.0, 14.3, "detail", True),
        glow_z(0.9, 2.7, 2.25, 14.3, 0.3, True),
    ]


def b_megaphones():
    """One long megaphone a side, low: a thin pipe that flares in steps to a fat bell well past the tail."""
    x, y = 2.7, 0.8
    return [
        cbox(4.2, 0.5, 1.0, DECK_END, DECK_END + 0.2, "detail", "bar on the deck rear face"),
        box(2.1, 2.9, 0.55, 1.05, 12.2, 12.6, "detail", True),          # clamps out from the bar
        tz(0.5, x, y, 12.2, 13.7, "secondary", True),                   # thin pipe
        tz(0.8, x, y, 13.6, 14.6, "secondary", True),                   # first flare
        tz(1.15, x, y, 14.5, 15.7, "secondary", True),                  # fat bell
        glow_z(0.9, x, y, 15.7, 0.25, True),
    ]


def b_slot():
    out = boost_plate() + [
        cbox(6.2, 0.45, 1.05, 12.2, 13.6, "detail"),                    # flat full-width burner
        cbox(6.4, 1.05, 1.17, 12.2, 13.9, "secondary"),                 # top lip
        cbox(5.6, 0.55, 0.95, 13.6, 14.3, "thrust"),
    ]
    for x in (-1.4, 0.0, 1.4):
        out.append(box(x - 0.06, x + 0.06, 0.45, 1.05, 13.5, 14.35, "detail"))      # dividers
    return out


def b_staged():
    return boost_plate() + [
        cbox(3.2, 0.3, 1.3, 12.2, 12.5, "secondary"),                   # collar
        tz(1.1, 0, 0.8, 12.5, 14.1, "detail"), glow_z(0.8, 0, 0.8, 14.1, 0.5),         # long centre can
        tz(0.9, 1.05, 0.75, 12.5, 13.5, "detail", True), glow_z(0.6, 1.05, 0.75, 13.5, 0.4, True),  # short outer cans
    ]


def b_zoomies():
    out = boost_plate() + [box(1.0, 3.3, 0.4, 1.3, 12.2, 14.2, "primary", True)]        # shared collector box each side
    for k in range(3):
        s = (2.7, 1.2, 12.35 + k * 0.55)
        out += [ttz(0.6, 1.9, s, -70, "secondary", True),               # fat upswept stacks
                ttz(0.42, 0.55, along(s, -70, 1.5), -70, "thrust", True)]
    return out


def b_lakepipes():
    """Side exits: a flat pipe runs outboard along the deck edge each side, then turns and fires out at 35 degrees."""
    n = (1.9, 0.8, 12.65)
    return boost_plate() + [
        box(1.2, 2.0, 0.6, 1.0, 12.2, 12.6, "secondary", True),         # flat pipe run along the deck edge
        ttz(1.1, 1.1, n, 0, "secondary", True, 35),                     # chrome elbow, turned outboard
        ttz(1.0, 1.0, along(n, 0, 0.8, 35), 0, "detail", True, 35),     # nozzle
        ttz(0.72, 0.8, along(n, 0, 1.25, 35), 0, "thrust", True, 35),
    ]


# ----------------------------------------------------------------------------- RearBody: engine decks
def deck_common():
    return [cbox(3.2, 0.2, 2.0, BH_R, DS, "detail", "collar on the rear bulkhead (shadow gap)"),
            wedge(-TUB_X, TUB_X, BELT, RIM, DS, SH_Z, thin="rear", note="shoulder: falls from the rim to the beltline"),
            cbox(3.0, 0.3, 1.3, 11.8, DECK_END, "detail", "pad: afterburner face")]


def neck(w, z_to, top=BELT):
    """Plan taper from the full section at the bulkhead to the deck's own half width w."""
    return [pwedge(w, TUB_X, 0.1, top, DS, z_to, thin="rear", base="in")]


def wing_pads(x_from):
    return [box(x_from, WPAD_X1, 1.2, BELT, WPAD_Z0, WPAD_Z1, "detail", True, "pad: rear wing")]


def hardpoints(x_from):
    return [box(x_from, 3.85, 0.45, 1.15, 6.4, 9.6, "detail", True),    # shelf out to the hardpoint, as long as a thruster box
            box(3.85, HARD_X, 0.3, 1.3, 7.2, 8.8, "detail", True, "pad: rear thruster hardpoint")]


def frame_pads(x_from):
    return [box(x_from, 2.4, 1.2, BELT, 4.8, 5.4, "detail", True, "pad: top wing front post")]


def rb_coke():
    return deck_common() + neck(0.9, 5.6) + hardpoints(0.9) + frame_pads(1.0) + [
        cbox(1.8, 0.1, 1.0, DS, 9.0),                                   # compact gearbox case
        wedge(-0.9, 0.9, 1.0, BELT, DS, 9.0, thin="rear"),              # top line falls away under the engine
        cbox(2.2, 1.15, BELT, EM_F0, EM_F1, "detail"),                  # front engine mount
        tz(0.9, 0, 0.8, 9.0, 11.8, "detail"),                           # slim crash tube out to the afterburner face
        cbox(0.5, 1.2, 1.3, EM_R0, EM_R1, "detail"),                    # post up to the rear engine mount
        cbox(2.2, 1.3, BELT, EM_R0, EM_R1, "detail"),                   # rear engine mount
        box(1.1, 2.8, 1.25, BELT, 10.5, 10.8, "detail", True),          # stay out to the wing pad
        box(WPAD_X0, WPAD_X1, 1.2, BELT, WPAD_Z0, WPAD_Z1, "detail", True, "pad: rear wing"),
        box(0.9, 0.96, 0.3, 0.7, 5.8, 8.6, "secondary", True),          # stripe
    ]


def rb_cradle():
    out = deck_common() + wing_pads(1.65) + hardpoints(3.1) + frame_pads(1.3) + [
        cbox(3.5, 0.1, BELT, DS, 4.0),                                  # shoulder bulkhead, full section
        cbox(2.0, 0.05, 0.35, 4.0, 11.8, "detail"),                     # belly
        box(1.35, 1.65, 1.2, BELT, 4.0, 11.8, "secondary", True),       # top rails; daylight shows under them
        cbox(2.7, 1.2, BELT, EM_F0, EM_F1, "detail"), cbox(2.7, 1.2, BELT, EM_R0, EM_R1, "detail"),  # engine mounts
        tz(1.2, 0, 0.75, 10.2, 11.8, "secondary"),                      # gearbox end
        box(1.7, 3.1, 0.25, 1.15, 5.0, 9.2, "secondary", True),         # flat saddle tanks, below the beltline
        box(2.2, 2.6, 1.15, 1.25, 5.4, 5.8, "detail", True),            # filler caps
    ]
    for z in (4.3, 9.3):
        out.append(box(1.4, 1.6, 0.1, 1.2, z, z + 0.25, "secondary", True))     # uprights
    out.append(rod((1.5, 0.3, 9.5), (1.5, 1.2, 11.6), 0.15, 0.15, "secondary", True))   # tail diagonal
    return out


def rb_longtail():
    return deck_common() + [
        cbox(3.5, 0.1, BELT, DS, 5.2),                                  # shoulder
        pwedge(TUB_X, 4.0, 0.1, BELT, DS, 5.2, thin="front", base="in"),    # swept leading edges out to full width
        cbox(8.0, 0.1, BELT, 5.2, DECK_END),                            # full-width deck
        wedge(2.9, 4.0, BELT, 1.9, 5.4, 7.0, "front", "bottom", "primary", True),   # low fender line beside the engine
        box(2.9, 4.0, BELT, 1.9, 7.0, DECK_END, "primary", True),       # runs on past the wing pylons
        box(3.4, 5.0, 0.1, 1.9, DECK_END, 13.4, "primary", True),       # flared tail horns either side of the burner
        wedge(3.4, 5.0, 0.1, 1.9, 13.4, 14.6, "rear", "bottom", "primary", True),
        box(3.7, 4.7, 1.3, 1.6, 13.38, 13.5, "neon", True),             # tail lights
        box(2.9, 2.96, 1.5, 1.8, 7.4, 11.6, "secondary", True),         # fender stripe
    ]


def rb_tunnel():
    return deck_common() + neck(1.2, 5.0) + wing_pads(1.0) + hardpoints(3.4) + frame_pads(1.1) + [
        cbox(2.4, 0.1, BELT, DS, 6.0),                                  # spine at full height under the front mount
        wedge(-1.2, 1.2, 0.9, BELT, 6.0, 7.4, thin="rear"),             # then it steps down
        cbox(2.4, 0.1, 0.9, 6.0, 11.8),                                 # low spine: the engine stands clear
        cbox(2.2, 0.9, BELT, EM_R0, EM_R1, "detail"),                   # rear engine pedestal
        pwedge(TUB_X, 4.0, 0.1, 0.5, DS, 5.0, thin="front", base="in"), # swept leading edge of the tunnel roof
        box(1.2, 4.0, 0.1, 0.5, 5.0, 10.0, "primary", True),            # wide low tunnel roof
        wedge(1.2, 4.0, 0.1, 0.5, 10.0, DECK_END, "rear", "top", "primary", True),  # upswept tunnel exits
        box(2.0, 2.8, 0.5, 1.2, 10.1, 11.5, "detail", True),            # posts under the wing pads
        box(1.5, 3.8, 0.5, 0.56, 5.4, 6.2, "secondary", True),          # roof stripe
    ]


def rb_tank():
    return deck_common() + neck(1.3, 5.0) + wing_pads(1.3) + hardpoints(1.3) + frame_pads(1.2) + [
        cbox(2.6, 0.1, BELT, DS, 11.8),                                 # narrow frame body
        box(2.9, 4.0, 0.8, 2.6, 9.6, DECK_END, "secondary", True),      # tail tanks carried high at the rear corners
        box(1.3, 2.9, 0.9, 1.25, 9.7, 10.0, "detail", True),            # tank brackets
        box(1.3, 2.9, 0.9, 1.25, 11.3, 11.6, "detail", True),
        box(3.1, 3.8, 2.54, 2.6, 10.4, 11.2, "detail", True),           # filler caps
        box(1.3, 1.36, 0.5, 1.0, 5.4, 7.2, "secondary", True),          # number panel
    ]


def rb_trunk():
    return deck_common() + hardpoints(3.3) + [
        cbox(3.5, 0.1, BELT, DS, 5.0),                                  # shoulder
        pwedge(TUB_X, 3.3, 0.1, BELT, DS, 5.0, thin="front", base="in"),    # swept out to the trunk width
        cbox(6.6, 0.1, BELT, 5.0, DECK_END),                            # square trunk deck
        wedge(2.0, 2.4, BELT, 2.6, 5.4, 9.4, "rear", "bottom", "primary", True),    # thin sail fins, inboard of the shoulder jets
        box(2.8, 3.3, BELT, 1.75, 9.6, DECK_END, "primary", True),      # square quarter tops
        box(3.3, 3.36, 0.3, 1.1, 9.4, 11.6, "secondary", True),         # number panels
    ]


# ----------------------------------------------------------------------------- SidePods
def shoulder_pad():
    return [box(PAD_X0, PAD_X1, 1.25, BELT, PAD_Z0, PAD_Z1, "detail", True, "pad: shoulder jet")]


def sp_undercut():
    return shoulder_pad() + [
        box(TUB_X, 1.95, 0.25, 1.2, -3.2, 2.6, "detail", True),         # link to the tub rail
        box(1.95, 4.5, 0.15, 1.3, -3.4, -0.6, "primary", True),         # inlet body
        box(2.3, 4.2, 0.5, 1.1, -3.5, -3.38, "detail", True),           # inlet mouth
        pwedge(1.95, 4.5, 0.15, 1.3, -0.6, 2.9, thin="rear", base="in"),    # tapers to the tub
        box(3.3, 3.5, 0.4, 1.25, -0.6, 1.5, "detail", True),            # pad web
        box(1.95, 5.6, -0.12, 0.05, -3.5, 2.9, "detail", True),         # floor edge
        box(2.2, 4.3, 1.3, 1.36, -3.2, -1.7, "secondary", True),
    ]


def sp_pannier():
    return shoulder_pad() + [
        tz(1.3, 2.55, 0.75, -3.0, 2.6, "primary", True),                # pannier tank
        tz(0.8, 2.55, 0.75, -3.5, -2.6, "secondary", True),             # tank nose
        box(TUB_X, 2.0, 0.5, 1.0, -0.4, 0.4, "detail", True),           # strap to the tub rail
        box(2.9, 4.2, 1.05, 1.25, -1.2, -0.8, "detail", True),          # pad arms
        box(2.9, 4.2, 1.05, 1.25, 0.8, 1.2, "detail", True),
    ]


def sp_sponson():
    """Deep sponson with a chamfered front corner and a tail that tapers in plan and in height, so it closes
    cleanly against a narrow engine deck."""
    return shoulder_pad() + [
        box(TUB_X, 1.95, 0.25, 1.2, -3.2, 2.6, "detail", True),
        box(1.95, 4.2, -0.9, 1.3, -3.5, 2.9, "primary", True),          # deep core, full length
        box(4.2, 6.2, -0.9, 1.3, -2.5, 0.9, "primary", True),           # outer sponson
        pwedge(4.2, 6.2, -0.9, 1.3, -3.5, -2.5, thin="front", base="in"),   # chamfered front corner
        pwedge(4.2, 6.2, -0.9, 1.3, 0.9, 2.9, thin="rear", base="in"),      # tail tapers in plan to the core
        box(4.7, 6.2, 1.3, 2.2, -2.5, 0.9, "primary", True),            # fender ridge
        pwedge(4.7, 6.2, 1.3, 2.2, -3.25, -2.5, thin="front", base="in"),   # ridge follows the front chamfer
        pwedge(4.7, 6.2, 1.3, 2.2, 0.9, 2.4, thin="rear", base="in"),       # and the tail taper
        box(2.2, 4.0, -0.6, 1.0, 2.9, 2.96, "detail", True),            # dark vent panel in the rear face
        box(6.2, 6.26, 0.1, 1.9, -1.6, 0.4, "secondary", True),         # door panel
    ]


def sp_skirted():
    return shoulder_pad() + [
        box(TUB_X, 1.95, 0.25, 1.2, -3.2, 2.6, "detail", True),
        box(1.95, 5.5, 0.75, 1.3, -2.2, 2.9, "primary", True),          # thin wing-section slab
        pwedge(1.95, 5.5, 0.75, 1.3, -3.5, -2.2, thin="front", base="in"),  # swept leading edge
        box(2.2, 5.2, 0.85, 1.2, 2.9, 2.98, "detail", True),            # tunnel exit
        box(5.3, 5.7, -1.3, 0.75, -2.2, 2.9, "secondary", True),        # sliding skirt, hung under the slab edge
    ]


def sp_nerf():
    return shoulder_pad() + [
        tz(0.3, 4.45, 0.9, -3.3, 2.7, "secondary", True),               # nerf bar
        tz(0.3, 3.6, 0.2, -3.0, 2.4, "secondary", True),                # lower bar
        box(TUB_X, 4.45, 0.8, 1.0, -2.9, -2.6, "detail", True),         # standoffs
        box(TUB_X, 4.45, 0.8, 1.0, 2.2, 2.5, "detail", True),
        box(3.2, 3.6, 0.35, 1.25, -0.2, 0.2, "detail", True),           # pad post
        box(TUB_X, 2.6, 1.1, 1.3, -0.6, 0.6, "detail", True),           # pad tie
        box(4.6, 4.7, 0.2, 1.3, -1.6, 1.2, "primary", True),            # number board
    ]


def sp_slab():
    return shoulder_pad() + [
        box(TUB_X, 1.95, 0.25, 1.2, -3.2, 2.6, "detail", True),
        box(1.95, 4.5, -0.8, 1.3, -3.5, 2.9, "primary", True),          # tall flat door slab
        box(4.5, 4.56, -0.2, 1.0, -1.8, 0.4, "secondary", True),        # square number panel
        box(4.5, 4.75, 0.2, 0.42, -3.3, 2.7, "detail", True),           # rub rail
        box(4.5, 4.56, -0.7, -0.3, 1.2, 2.6, "detail", True),           # side vent
    ]


# ----------------------------------------------------------------------------- RearBumper: diffusers
def df_strake():
    out = [cbox(6.4, -0.2, 0.0, 6.8, DECK_END, "detail"),
           wedge(-3.2, 3.2, -0.9, 0.1, DECK_END, 14.4, "rear", "top", "detail"),        # upswept ramp
           cbox(0.4, -0.3, 0.1, 14.4, 14.55, "neon")]
    for x in (0.9, 2.2):
        out.append(box(x - 0.06, x + 0.06, -1.2, -0.1, 11.9, 14.5, "secondary", True))
    out.append(cbox(0.12, -1.2, -0.1, 11.9, 14.5, "secondary"))
    return out


def df_pan():
    return [cbox(3.0, -0.25, 0.0, 6.8, DECK_END, "detail"),
            wedge(-2.0, 2.0, -0.45, 0.15, DECK_END, 14.0, "rear", "top", "primary"),    # painted pan kicks up to the tail
            cbox(6.0, -0.25, 0.1, 13.9, 14.2, "secondary"),              # wide chrome bumper bar
            box(1.3, 1.6, -0.7, 0.2, 14.0, 14.45, "secondary", True)]    # overriders


def df_extractor():
    out = [cbox(8.0, -0.2, 0.0, 6.6, DECK_END, "detail"),
           wedge(-3.4, 3.4, -1.0, 0.1, DECK_END, 14.6, "rear", "top", "detail"),
           wedge(3.4, 5.0, -1.0, 0.0, DECK_END, 14.6, "rear", "top", "detail", True),
           cbox(6.0, -0.15, 0.1, 14.45, 14.6, "neon")]
    for x, z0 in ((1.2, 11.6), (2.6, 11.6), (4.9, DECK_END)):
        out.append(box(x - 0.08, x + 0.08, -1.25, -0.1, z0, 14.6, "secondary", True))
    return out


def df_venturi():
    return [box(0.8, 3.8, -1.2, 0.0, 7.0, 11.4, "detail", True),         # twin tunnels
            wedge(0.8, 3.8, -1.2, 0.0, 11.4, 13.8, "rear", "top", "detail", True),
            cbox(1.0, -1.3, 0.0, 7.0, 14.4, "secondary"),                # keel
            box(3.8, 4.0, -1.3, 0.0, 6.6, DECK_END, "primary", True)]    # skirts


def df_pushbar():
    return [cbox(3.2, -0.2, 0.0, 7.0, DECK_END, "detail"),
            box(1.3, 1.55, -0.35, -0.2, 11.0, 11.8, "detail", True),     # rail hangers
            box(1.3, 1.55, -0.6, -0.35, 11.0, 14.4, "secondary", True),  # rails
            cbox(3.4, -1.15, -0.9, 14.3, 14.6, "primary"),               # painted push hoop: bottom bar
            cbox(3.4, -0.05, 0.2, 14.3, 14.6, "primary"),                # top bar
            box(1.45, 1.7, -1.15, 0.2, 14.3, 14.6, "primary", True),     # hoop ends
            cbox(1.4, -0.9, -0.05, 14.35, 14.55, "secondary")]           # push pad


def df_valance():
    return [cbox(6.0, -0.2, 0.0, 7.0, DECK_END, "detail"),
            box(3.1, 3.3, -1.0, 0.1, DECK_END, 13.0, "primary", True),   # returns
            cbox(6.6, -1.0, 0.15, 13.0, 13.5, "primary"),                # full-width upright valance
            box(0.8, 2.4, -0.8, -0.3, 13.5, 13.56, "detail", True),      # cutouts
            cbox(6.7, -0.25, -0.05, 13.5, 13.66, "secondary")]           # bumper strip


# ----------------------------------------------------------------------------- RearSpoiler: rear wings
def wing_feet():
    return [box(PYLON_X - 0.3, PYLON_X + 0.3, BELT, 1.55, 10.2, 11.4, "detail", True, "foot on the wing pad")]


def rw_downforce():
    return wing_feet() + [
        rod((PYLON_X, 1.5, 10.8), (PYLON_X, 4.15, 12.2), 0.5, 0.25, "detail", True),    # swan-neck pylons
        cbox(10.0, 4.1, 4.35, 11.8, 13.8, "secondary"),                 # main plane
        tblock([10.0, 0.18, 1.0], [0, 4.85, 14.0], -25, "primary"),     # flap
        box(5.0, 5.2, 3.0, 5.25, 11.7, 14.5, "primary", True),          # endplates
    ]


def rw_strut():
    return wing_feet() + [
        box(PYLON_X - 0.1, PYLON_X + 0.1, 1.55, 5.2, 10.7, 10.9, "secondary", True),    # tall thin struts
        rod((PYLON_X, 4.1, 10.9), (PYLON_X, 5.15, 11.7), 0.12, 0.12, "detail", True),
        cbox(4.8, 4.2, 4.32, 10.74, 10.86, "detail"),
        cbox(6.4, 5.2, 5.4, 10.0, 11.8, "primary"),                     # small high plane
        box(3.1, 3.2, 5.0, 5.6, 9.9, 11.9, "secondary", True),
    ]


def rw_blade():
    return wing_feet() + [
        box(PYLON_X - 0.15, PYLON_X + 0.15, 1.55, 4.2, 10.9, 11.5, "detail", True),
        box(PYLON_X - 0.15, PYLON_X + 0.15, 4.0, 4.2, 11.5, 12.6, "detail", True),
        cbox(13.0, 4.2, 4.4, 12.2, 14.2, "primary"),                    # full-width low blade
        cbox(13.0, 4.4, 4.55, 14.05, 14.2, "secondary"),
        box(6.3, 6.5, 1.8, 4.9, 12.0, 14.5, "secondary", True),         # end fins
    ]


def rw_twin():
    return wing_feet() + [
        box(PYLON_X - 0.15, PYLON_X + 0.15, 1.55, 4.3, 10.6, 11.2, "detail", True),
        cbox(7.2, 4.2, 4.4, 10.4, 12.4, "secondary"),                   # lower plane
        tblock([7.2, 0.2, 1.8], [0, 5.15, 11.6], -12, "primary"),       # upper plane
        box(3.6, 3.8, 4.0, 5.6, 9.9, 13.0, "primary", True),            # box endplates
    ]


def rw_topwing():
    """Big slab over the roll hoop and engine intake. It stands on four posts: a front pair on the deck frame pads
    and a rear pair on the wing pads, with a diagonal brace each side."""
    x0, x1, xc = 2.05, 2.35, 2.2
    return wing_feet() + [
        box(x0, x1, 1.55, 3.2, 10.3, 10.7, "detail", True),             # rear posts on the wing pads
        rod((xc, 3.0, 10.5), (xc, 5.6, 5.6), 0.25, 0.25, "detail", True),       # diagonal braces up to the slab
        box(x0, x1, BELT, 5.6, 4.85, 5.15, "detail", True),             # front posts on the deck frame pads
        tblock([0.3, 0.3, 4.8], [xc, 5.25, 3.2], -6, "detail", True),   # rails under the slab
        tblock([7.0, 0.3, 5.4], [0, 5.5, 3.1], -6, "primary"),          # slab
        box(3.5, 3.7, 4.9, 6.2, 0.3, 5.9, "secondary", True),           # side boards
    ]


def rw_standup():
    return wing_feet() + [
        box(PYLON_X - 0.15, PYLON_X + 0.15, 1.55, 4.2, 10.9, 11.5, "detail", True),     # pylons
        cbox(5.4, 4.02, 4.2, 11.0, 11.6, "detail"),                     # cross bar
        tblock([8.4, 0.2, 1.5], [0, 4.72, 12.0], -55, "primary"),       # steep stand-up blade
        box(4.2, 4.36, 4.02, 5.4, 11.3, 12.7, "secondary", True),       # end gussets
    ]


# ----------------------------------------------------------------------------- catalogue
COCKPITS = {
    "formula": ("Formula", "Formula", "works", cockpit_formula),
    "cigar": ("Cigar", "Vintage Grand Prix", "vintage", cockpit_cigar),
    "prototype": ("Prototype", "Prototype", "endurance", cockpit_prototype),
    "wingcar": ("Wingcar", "Wing Car", "ground_effect", cockpit_wingcar),
    "sprint": ("Sprint", "Speedway Sprint", "outlaw", cockpit_sprint),
    "oval": ("Oval", "Stock Oval", "stocker", cockpit_oval),
}

F, V, PR, W, S, O = "Formula", "Vintage Grand Prix", "Prototype", "Wing Car", "Speedway Sprint", "Stock Oval"
MODULES = {
    "Engine1": {"works_turbine": ("Works Turbine", F, e1_works), "stack_eight": ("Stack Eight", V, e1_stack8),
                "twin_spool": ("Twin Spool", PR, e1_twin), "turbo_slot": ("Turbo Slot", W, e1_turbo),
                "quad_cluster": ("Quad Cluster", S, e1_quad), "big_bore": ("Big Bore", O, e1_bigbore)},
    "Engine2": {"shoulder_turbines": ("Shoulder Turbines", F, e2_turbines), "ram_bullets": ("Ram Bullets", V, e2_bullets),
                "slot_ducts": ("Slot Ducts", PR, e2_slots), "turbo_stacks": ("Turbo Stacks", W, e2_stacks),
                "twin_shorties": ("Twin Shorties", S, e2_shorties), "side_dumps": ("Side Dumps", O, e2_sidedump)},
    "Stabilisers": {"vector_pods": ("Vector Pods", F, st_vector), "bullet_outriggers": ("Bullet Outriggers", V, st_bullet),
                    "arch_fairings": ("Arch Fairings", PR, st_arch), "vane_cascades": ("Vane Cascades", W, st_vane),
                    "stagger_stacks": ("Stagger Stacks", S, st_stagger), "triple_packs": ("Triple Packs", O, st_triple)},
    "Boost": {"twin_cans": ("Twin Cans", F, b_twin_cans), "twin_megaphones": ("Twin Megaphones", V, b_megaphones),
              "slot_burner": ("Slot Burner", PR, b_slot), "staged_triple": ("Staged Triple", W, b_staged),
              "zoomies": ("Zoomie Stacks", S, b_zoomies), "lake_pipes": ("Lake Pipes", O, b_lakepipes)},
    "FrontBody": {"needle": ("Needle Nose", F, nose_needle), "radiator": ("Radiator Mouth", V, nose_radiator),
                  "shovel": ("Shovel Nose", PR, nose_shovel), "chisel": ("Chisel Nose", W, nose_chisel),
                  "grille": ("Grille Hood", S, nose_grille), "bluff": ("Bluff Nose", O, nose_bluff)},
    "RearBody": {"coke_bottle": ("Coke Bottle", F, rb_coke), "tube_cradle": ("Tube Cradle", V, rb_cradle),
                 "long_tail": ("Long Tail", PR, rb_longtail), "tunnel_deck": ("Tunnel Deck", W, rb_tunnel),
                 "tank_tail": ("Tank Tail", S, rb_tank), "trunk_deck": ("Trunk Deck", O, rb_trunk)},
    "SidePods": {"undercut": ("Undercut", F, sp_undercut), "pannier": ("Pannier Tanks", V, sp_pannier),
                 "sponson": ("Sponsons", PR, sp_sponson), "skirted": ("Skirted", W, sp_skirted),
                 "nerf_bars": ("Nerf Bars", S, sp_nerf), "door_slabs": ("Door Slabs", O, sp_slab)},
    "FrontBumper": {"cascade": ("Cascade Wing", F, fw_cascade), "chin_blade": ("Chin Blade", V, fw_chin),
                    "splitter": ("Splitter", PR, fw_splitter), "plank_wing": ("Plank Wing", W, fw_plank),
                    "nerf_bumper": ("Nerf Bumper", S, fw_nerf), "air_dam": ("Air Dam", O, fw_airdam)},
    "RearBumper": {"strake": ("Strake Diffuser", F, df_strake), "belly_pan": ("Belly Pan", V, df_pan),
                   "extractor": ("Long Extractor", PR, df_extractor), "venturi": ("Venturi Tunnels", W, df_venturi),
                   "push_bar": ("Push Bar", S, df_pushbar), "valance": ("Valance", O, df_valance)},
    "RearSpoiler": {"high_downforce": ("High Downforce", F, rw_downforce), "high_strut": ("High Strut", V, rw_strut),
                    "low_blade": ("Low Drag Blade", PR, rw_blade), "twin_plane": ("Twin Plane Box", W, rw_twin),
                    "top_wing": ("Sprint Top Wing", S, rw_topwing), "stand_up": ("Stand-Up Spoiler", O, rw_standup)},
}

SLOT_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost", "FrontBody", "RearBody", "SidePods",
              "FrontBumper", "RearBumper", "RearSpoiler"]
KITS = {
    "works": ("Works", F, ["works_turbine", "shoulder_turbines", "vector_pods", "twin_cans", "needle",
                           "coke_bottle", "undercut", "cascade", "strake", "high_downforce"]),
    "vintage": ("Garagiste", V, ["stack_eight", "ram_bullets", "bullet_outriggers", "twin_megaphones", "radiator",
                                 "tube_cradle", "pannier", "chin_blade", "belly_pan", "high_strut"]),
    "endurance": ("All-Nighter", PR, ["twin_spool", "slot_ducts", "arch_fairings", "slot_burner", "shovel",
                                      "long_tail", "sponson", "splitter", "extractor", "low_blade"]),
    "ground_effect": ("Ground Effect", W, ["turbo_slot", "turbo_stacks", "vane_cascades", "staged_triple", "chisel",
                                           "tunnel_deck", "skirted", "plank_wing", "venturi", "twin_plane"]),
    "outlaw": ("Dirt Outlaw", S, ["quad_cluster", "twin_shorties", "stagger_stacks", "zoomies", "grille",
                                  "tank_tail", "nerf_bars", "nerf_bumper", "push_bar", "top_wing"]),
    "stocker": ("Stocker", O, ["big_bore", "side_dumps", "triple_packs", "lake_pipes", "bluff",
                               "trunk_deck", "door_slabs", "air_dam", "valance", "stand_up"]),
}

PAINT = {
    "formula": {"primary": "#d92b2b", "secondary": "#f2f2ee", "neon": "#7df9ff"},
    "cigar": {"primary": "#1f6b45", "secondary": "#d9d4c4", "neon": "#ffd27a"},
    "prototype": {"primary": "#2a6fd6", "secondary": "#f39a1e", "neon": "#fff1a8"},
    "wingcar": {"primary": "#f2c21a", "secondary": "#22346e", "neon": "#ffffff"},
    "sprint": {"primary": "#f26a1b", "secondary": "#fff3c4", "neon": "#ffe04a"},
    "oval": {"primary": "#0f8f9c", "secondary": "#f4f4f0", "neon": "#ff6a3c"},
}
SWAP = {"formula": "endurance", "cigar": "works", "prototype": "ground_effect", "wingcar": "stocker", "sprint": "vintage",
        "oval": "outlaw"}


def build_spec():
    spec = {
        "id": "apex", "displayName": "Apex",
        "tagline": "Circuit racers as hover jets: a central tub, wings at both ends, a turbine on the deck, jets on the shoulders and four corner thrusters.",
        "standard": standard(),
        "cockpits": {cid: {"name": n, "culture": c, "kit": k, "parts": fn()} for cid, (n, c, k, fn) in COCKPITS.items()},
        "kits": {kid: {"name": n, "culture": c, "modules": dict(zip(SLOT_ORDER, mods))} for kid, (n, c, mods) in KITS.items()},
        "modules": {s: {mid: {"name": n, "culture": c, "parts": fn()} for mid, (n, c, fn) in mods.items()} for s, mods in MODULES.items()},
        "builds": [],
    }
    for cid, (n, _c, k, _fn) in COCKPITS.items():
        spec["builds"].append({"name": "%s, own %s kit" % (n, KITS[k][0]), "cockpit": cid, "kit": k, "paint": PAINT[cid]})
        spec["builds"].append({"name": "%s, %s kit" % (n, KITS[SWAP[cid]][0]), "cockpit": cid, "kit": SWAP[cid], "paint": PAINT[cid]})
    spec["builds"] += [
        {"name": "Mixed: Privateer Formula", "cockpit": "formula", "kit": "works",
         "modules": {"Engine1": "quad_cluster", "Boost": "zoomies", "Stabilisers": "arch_fairings", "RearSpoiler": "twin_plane", "FrontBody": "chisel"},
         "paint": {"primary": "#17a374", "secondary": "#f4f4f0", "neon": "#ff5ad1"}},
        {"name": "Mixed: Prototype sprint special", "cockpit": "prototype", "kit": "endurance",
         "modules": {"Engine1": "works_turbine", "Engine2": "shoulder_turbines", "Boost": "staged_triple", "RearSpoiler": "top_wing", "FrontBumper": "cascade"},
         "paint": {"primary": "#8a2be2", "secondary": "#ffd21a", "neon": "#9dff6a"}},
        {"name": "Mixed: Cigar wing car", "cockpit": "cigar", "kit": "vintage",
         "modules": {"Stabilisers": "vane_cascades", "SidePods": "skirted", "RearBody": "tunnel_deck", "Engine2": "turbo_stacks", "Boost": "slot_burner", "RearSpoiler": "low_blade"},
         "paint": {"primary": "#c7ccd4", "secondary": "#b3202a", "neon": "#7df9ff"}},
    ]
    return spec


def round_parts(spec):
    """Every cylinder in the spec as (where, diameter, length). Used to refuse discs."""
    out = []
    groups = [("cockpit " + cid, c["parts"]) for cid, c in spec["cockpits"].items()]
    groups += [("%s/%s" % (s, mid), m["parts"]) for s, mods in spec["modules"].items() for mid, m in mods.items()]
    for where, parts in groups:
        for p in parts:
            if p["shape"].startswith("cyl_"):
                axis = "xyz".index(p["shape"][-1])
                out.append((where, max(p["size"][a] for a in (0, 1, 2) if a != axis), p["size"][axis]))
    return out


def report(spec):
    sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
    import vbspec
    exp = vbspec.expand_parts
    print("part counts:")
    for cid, c in spec["cockpits"].items():
        print("  cockpit %-12s %3d" % (cid, len(exp(c["parts"]))))
    for s, mods in spec["modules"].items():
        print("  %-12s %s" % (s, ", ".join("%s %d" % (m, len(exp(v["parts"]))) for m, v in mods.items())))
    rows = []
    for s, mods in spec["modules"].items():
        for (a, b), (free, raw) in vbspec.distinct_table({m: exp(v["parts"]) for m, v in mods.items()}).items():
            rows.append((free, raw, s, a, b))
    for (a, b), (free, raw) in vbspec.distinct_table({c: exp(v["parts"]) for c, v in spec["cockpits"].items()}).items():
        rows.append((free, raw, "Cockpit", a, b))
    print("distinctness pairs, free outline then whole outline (low first):")
    for free, raw, s, a, b in sorted(rows)[:30]:
        print("  %.2f %.2f  %-12s %s" % (free, raw, s, a + " / " + b))
    print("cockpit pairs, free then whole outline:")
    for free, raw, s, a, b in sorted((r for r in rows if r[2] == "Cockpit"), key=lambda r: r[1]):
        print("  %.2f %.2f  %s" % (free, raw, a + " / " + b))
    cyl = round_parts(spec)
    print("cylinders: %d, least length/diameter %.2f" % (len(cyl), min(l / d for _w, d, l in cyl)))


def main():
    spec = build_spec()
    bad = [(w, d, l) for w, d, l in round_parts(spec) if l < d]
    for w, d, l in bad:
        print("DISC  %s: cylinder %.2f across, %.2f long" % (w, d, l))
    if bad:
        print("refusing to write: every round part must be at least as long as it is wide")
        return 1
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=1)
        f.write("\n")
    print("wrote %s: %d cockpits, %d kits, %d modules, %d builds" % (
        OUT, len(spec["cockpits"]), len(spec["kits"]), sum(len(m) for m in spec["modules"].values()), len(spec["builds"])))
    if "--report" in sys.argv:
        report(spec)
    return 0


if __name__ == "__main__":
    sys.exit(main())
