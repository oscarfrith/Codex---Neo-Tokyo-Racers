"""Generator for the Rift blockout spec, round 2 after the critic's review (design exploration only).

Run from the repo root:
  py -3 scripts/vehicle_blockouts/gen/rift.py            writes specs/rift.json
  py -3 scripts/vehicle_blockouts/gen/rift.py --report   also prints pairwise distinctness per slot

Rift is a classic coupe cut into floating sections. A centre spine (nose, cabin, tail) carries
floating bodies on each side: a front fender nacelle and a rear-quarter pod.

What holds the swaps together:
  - One shared seam section. Every cabin tub and every clip ends on the same painted section
    (6.8 wide, sill to deck) at the two seam planes, so no cabin end face is ever left bare.
  - Front engines run through the fender: intake under the tip, an intake stack on a pad on the
    fender top, and the nozzle in a bay under the fender's tail where the chase camera sees it.
  - Rear engines sit behind the rear-quarter pods, stabilisers in the open bay amidships and the
    afterburner in the centre tail.
  - One shared pod end collar. Every rear-quarter pod ends on the same painted section (2.8 square)
    ahead of the engine bulkhead, so any rear engine meets a face of its own size.
  - One centre bumper pad on every nose, so a full-width bumper is backed on pointed and short noses too.
  - An exhaust lane behind each front engine nozzle. Rockers and stabilisers keep out of it.

Root space: +X right, +Y up, forward is -Z. Units are studs.
Every helper takes bounds (x0, x1, y0, y1, z0, z1) so a shape can be read straight off the frame table.
For mirrored parts give the +X copy and pass m=True.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SPEC_PATH = os.path.join(ROOT, "specs", "rift.json")

# ----------------------------------------------------------------------------- datums
HOVER = -2.0      # ground
LOW = -1.7        # nothing goes below this
SILL = 0.4        # bottom edge of painted body on the centre spine
POD_FLOOR = 0.8   # underside of every fender nacelle = ceiling of the front engine bodies
STRIPE = 1.9      # centre of the belt stripe on every outboard body
BELT = 2.8        # window sill and default shoulder
DECK = 3.4        # bonnet and boot surface; top of the shared seam section
BODY_TOP = 3.6    # top of the body envelopes; pad tops
POD_TOP = 4.6     # rear-quarter pods may rise to here (sail panels, fins); wide spoilers start above it
POD_LOW = -0.8    # rear-quarter pods may hang down to here (deep tubs)
EAVE = 2.5        # underside of the fender tail over the front engine nozzle bay

XC = 3.8          # cockpit half width = mid-section seam
SX = 3.4          # half width of the shared seam section (every tub and every clip collar)
XM = 6.4          # mid-section outer limit = stabiliser riser inner limit
XO = 8.5          # outer limit of nacelles, pods and engines
XS = 9.0          # outer limit of the stabilisers
XN = 4.0          # centre spine envelope half width ahead of and behind the cabin

ZB = -18.0        # front bumper limit
ZN = -16.5        # nacelle tips
ZX = -7.6         # front of the nozzle bay under each fender tail
ZF = -5.5         # front seam plane (front clip to cabin)
ZR = 6.5          # rear seam plane (cabin to rear clip)
ZP = 11.5         # rear-quarter pod bulkhead = rear engine seam
ZT = 14.0         # tail panel = afterburner seam
ZE = 17.5         # rear limit
G = 0.3           # painted bodywork stops this far short of a seam plane
COLLAR = 0.7      # length of the full seam section on each side of a seam

# Pod end collar: every rear-quarter pod ends on this painted section, so every rear engine meets the same face.
PCX0, PCX1, PCY0, PCY1 = 4.9, 7.7, 0.5, 3.3
PCZ = ZP - G - 0.8   # 10.4: the collar runs from here to the bulkhead pad
# Exhaust lane: the front engine jets fire back from Z -5.8 inside this box. Nothing else may enter it.
# Rockers stay inboard of LANE_X ahead of LANE_Z. Stabilisers start behind LANE_Z.
LANE_X, LANE_Z = 5.5, -2.7

# ----------------------------------------------------------------------------- part helpers


def _r(v):
    return [round(float(a), 3) for a in v]


def _part(shape, size, pos, ch, m, note, rot):
    p = {"shape": shape, "size": _r(size), "pos": _r(pos), "ch": ch}
    if rot and any(abs(a) > 1e-6 for a in rot):
        p["rot"] = _r(rot)
    if m:
        p["mirror"] = True
    if note:
        p["note"] = note
    return p


def blk(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None, rot=None):
    """Box from bounds."""
    return _part("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, m, note, rot)


def slab(size, pos, rot, ch="primary", m=False, note=None):
    """Rotated box given by centre and size (for slats lying on a slope)."""
    return _part("block", size, pos, ch, m, note, rot)


def cz(x, y, z0, z1, d, ch="primary", m=False, note=None, rot=None):
    """Tube along Z (the usual jet barrel)."""
    return _part("cyl_z", [d, d, z1 - z0], [x, y, (z0 + z1) / 2], ch, m, note, rot)


def cyv(x, y0, y1, z, d, ch="primary", m=False, note=None):
    """Tube along Y (an intake stack)."""
    return _part("cyl_y", [d, y1 - y0, d], [x, (y0 + y1) / 2, z], ch, m, note, None)


def cxx(x0, x1, y, z, d, ch="detail", m=False, note=None):
    """Tube along X (struts and cross tubes)."""
    return _part("cyl_x", [x1 - x0, d, d], [(x0 + x1) / 2, y, z], ch, m, note, None)


def ball(x, y, z, d, ch="primary", m=False, note=None):
    return _part("ball", [d, d, d], [x, y, z], ch, m, note, None)


def sweep(x, y0, z0, tilt, segs, m=True):
    """A chain of tubes that starts at (x, y0, z0) and sweeps up and back at `tilt` degrees.
    segs: (length, diameter, channel, note)."""
    ay, az = math.sin(math.radians(tilt)), math.cos(math.radians(tilt))
    out, t = [], 0.0
    for length, d, ch, note in segs:
        c = t + length / 2
        out.append(_part("cyl_z", [d, d, length], [x, y0 + ay * c, z0 + az * c], ch, m, note, [-tilt, 0, 0]))
        t += length
    return out


def cant_jet(x, y, z, out, back, segs, m=True):
    """A lift nozzle: a chain of tubes that starts at (x, y, z) and points down, canted `out` degrees
    outboard and `back` degrees rearward, so the glow shows from the side and from above.
    segs: (length, diameter, channel, note)."""
    a, b = math.radians(out), math.radians(back)
    d = (math.sin(a), -math.cos(a) * math.cos(b), math.cos(a) * math.sin(b))
    parts, t = [], 0.0
    for length, dia, ch, note in segs:
        c = t + length / 2
        parts.append(_part("cyl_y", [dia, length, dia], [x + d[0] * c, y + d[1] * c, z + d[2] * c], ch, m, note,
                           [-back, 0, out]))
        t += length
    return parts


# Wedge orientations. A wedge is a right triangle extruded along one axis.
# Key: (plane of the triangle, where the right angle sits). Value: (rot, local size order).
_WEDGE = {
    ("yz", "bottom", "back"): ([0, 0, 0], "xyz"),      # rises toward the rear: windscreen, bonnet
    ("yz", "bottom", "front"): ([0, 180, 0], "xyz"),   # falls toward the rear: fastback, tail slope
    ("yz", "top", "front"): ([180, 0, 0], "xyz"),      # underside rises toward the rear: diffuser
    ("yz", "top", "back"): ([0, 0, 180], "xyz"),       # underside rises toward the front: chin
    ("xy", "bottom", "right"): ([0, 90, 0], "zyx"),    # tall on +X, slopes down toward -X
    ("xy", "bottom", "left"): ([0, -90, 0], "zyx"),    # tall on -X, slopes down toward +X
    ("xy", "top", "right"): ([0, 90, 180], "zyx"),
    ("xy", "top", "left"): ([0, -90, 180], "zyx"),
    ("xz", "right", "back"): ([0, 0, 90], "yxz"),      # plan taper: straight side on +X, wide at the rear
    ("xz", "left", "back"): ([0, 0, -90], "yxz"),      # plan taper: straight side on -X, wide at the rear
    ("xz", "left", "front"): ([0, 180, 90], "yxz"),    # plan taper: straight side on -X, wide at the front
    ("xz", "right", "front"): ([0, 180, -90], "yxz"),  # plan taper: straight side on +X, wide at the front
}
RISE = ("yz", "bottom", "back")
FALL = ("yz", "bottom", "front")
UNDER_R = ("yz", "top", "front")
UNDER_F = ("yz", "top", "back")
OUTB = ("xy", "bottom", "left")      # for a +X part: tall inboard, slopes down outboard
INB = ("xy", "bottom", "right")      # for a +X part: tall outboard, slopes down inboard
PLAN_IN_BACK = ("xz", "left", "back")     # +X part: straight inner edge, widens outboard toward the rear
PLAN_IN_FRONT = ("xz", "left", "front")   # +X part: straight inner edge, widens outboard toward the front
PLAN_OUT_BACK = ("xz", "right", "back")   # +X part: straight outer edge, widens inboard toward the rear
PLAN_OUT_FRONT = ("xz", "right", "front")


def wdg(x0, x1, y0, y1, z0, z1, kind=RISE, ch="primary", m=False, note=None):
    rot, order = _WEDGE[kind]
    world = {"x": x1 - x0, "y": y1 - y0, "z": z1 - z0}
    size = [world[order[0]], world[order[1]], world[order[2]]]
    return _part("wedge", size, [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, m, note, rot)


def slats(x0, x1, ya, za, yb, zb, n, depth=0.7, thick=0.14, ch="detail", m=False, lift=0.1):
    """n slats lying on a straight slope that runs from (ya, za) to (yb, zb)."""
    ang = math.degrees(math.atan2(ya - yb, zb - za))
    out = []
    for i in range(n):
        t = (i + 0.7) / (n + 0.4)
        out.append(slab([x1 - x0, thick, depth], [(x0 + x1) / 2, ya + t * (yb - ya) + lift, za + t * (zb - za)],
                        [ang, 0, 0], ch, m))
    return out


# ----------------------------------------------------------------------------- frame standard

STANDARD = {
    "cockpitEnvelope": {"min": [-XC, 0, ZF], "max": [XC, 6.6, ZR]},
    "datums": {"hoverPlane": HOVER, "sill": SILL, "podFloor": POD_FLOOR, "stripe": STRIPE,
               "beltline": BELT, "deck": DECK, "bodyTop": BODY_TOP, "seamHalfWidth": SX,
               "frontSeamZ": ZF, "rearSeamZ": ZR, "nozzleBayZ": ZX, "podBulkheadZ": ZP, "tailPanelZ": ZT,
               "podCollarZ": PCZ, "exhaustLaneInnerX": LANE_X, "exhaustLaneEndZ": LANE_Z},
    "slots": {
        "FrontBody": {"label": "Front Clip",
                      "envelope": [{"min": [-XN, 0, ZN], "max": [XN, 4.6, ZF]},
                                   {"min": [XN, POD_FLOOR, ZN], "max": [XO, BODY_TOP, ZX], "mirror": True},
                                   {"min": [XN, EAVE, ZX], "max": [XO, BODY_TOP, ZF], "mirror": True}],
                      "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -7]},
        "RearBody": {"label": "Rear Clip",
                     "envelope": [{"min": [-XN, 0, ZR], "max": [XN, BODY_TOP, ZT]},
                                  {"min": [XN, POD_LOW, ZR], "max": [XO, POD_TOP, ZP], "mirror": True}],
                     "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 0, 7]},
        "SidePods": {"label": "Rockers",
                     "envelope": {"min": [XC, 0, ZF], "max": [XM, 2.6, ZR], "mirror": True},
                     "anchor": {"to": "cockpit", "face": "-x"}, "explode": [3, 3, 0]},
        "Engine1": {"label": "Front Engines",
                    "envelope": [{"min": [XN, LOW, ZB], "max": [XO, POD_FLOOR, ZF], "mirror": True},
                                 {"min": [XN, POD_FLOOR, ZX], "max": [XO, EAVE, ZF], "mirror": True},
                                 {"min": [XN, BODY_TOP, -14.0], "max": [XO, 4.6, -8.0], "mirror": True}],
                    "anchor": [{"to": "FrontBody", "face": "+y"}, {"to": "FrontBody", "face": "-y"}],
                    "explode": [0, -5, -9]},
        "Engine2": {"label": "Rear Engines",
                    "envelope": {"min": [XN, -0.8, ZP], "max": [XO, BODY_TOP, ZE], "mirror": True},
                    "anchor": {"to": "RearBody", "face": "-z"}, "explode": [3, 0, 14]},
        "Stabilisers": {"label": "Stabilisers",
                        "envelope": [{"min": [-XS, LOW, ZF], "max": [XS, 0, ZR]},
                                     {"min": [XM, 0, ZF], "max": [XS, BODY_TOP, ZR], "mirror": True}],
                        "anchor": {"to": "cockpit", "face": "+y"}, "explode": [5, -6, 0]},
        "Boost": {"label": "Afterburner",
                  "envelope": {"min": [-XN, 0.8, ZT], "max": [XN, 4.6, ZE]},
                  "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, 2, 16]},
        "FrontBumper": {"label": "Front Bumper",
                        "envelope": [{"min": [-XO, POD_FLOOR, ZB], "max": [XO, BODY_TOP, ZN]},
                                     {"min": [-XN, -1.2, ZB], "max": [XN, POD_FLOOR, ZN]}],
                        "anchor": {"to": "FrontBody", "face": "+z"}, "explode": [0, 0, -12]},
        "RearBumper": {"label": "Rear Bumper",
                       "envelope": {"min": [-XN, -1.2, ZT], "max": [XN, 0.8, 17.0]},
                       "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, -4, 12]},
        "RearSpoiler": {"label": "Spoiler",
                        "envelope": [{"min": [-XN, BODY_TOP, ZR], "max": [XN, POD_TOP, ZT]},
                                     {"min": [-XO, POD_TOP, ZR], "max": [XO, 7.6, ZE]}],
                        "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 6, 9]},
    },
}

# ----------------------------------------------------------------------------- cockpits
# Every cockpit = the same chassis (pads and couplers) + the same tub section + its own cabin.


def chassis():
    return [
        blk(-1.4, 1.4, 0, SILL, -4.2, 5.2, "detail", note="floor pan: stabiliser pad at Y 0"),
        blk(-2.2, 2.2, 0.5, 2.6, ZF, ZF + 0.3, "detail", note="front coupler flange on the seam plane"),
        blk(-2.2, 2.2, 0.5, 2.6, ZR - 0.3, ZR, "detail", note="rear coupler flange on the seam plane"),
        blk(2.0, XC, 0.9, 1.7, -3.2, -2.2, "detail", m=True, note="side hardpoint, front"),
        blk(2.0, XC, 0.9, 1.7, 2.6, 3.6, "detail", m=True, note="side hardpoint, rear"),
    ]


def tub(top=DECK):
    """The shared tub: the seam section (X +-3.4, sill to deck) carried from seam to seam.
    A cabin with a lower shoulder passes top and still ends on the full section at both seams."""
    p = [blk(-SX, SX, SILL, top, ZF + G, ZR - G, note="tub: the shared seam section, seam to seam")]
    if top < DECK:
        p += [blk(-SX, SX, top, DECK, ZF + G, ZF + G + COLLAR, note="front tub end: full seam section"),
              blk(-SX, SX, top, DECK, ZR - G - COLLAR, ZR - G, note="rear tub end: full seam section")]
    return p


def driver(x, z, head_y):
    return [blk(x - 0.7, x + 0.7, 1.8, head_y - 0.5, z - 0.4, z + 0.5, "driver"),
            ball(x, head_y, z, 1.2, "driver")]


def cockpit_brawler():
    """70s fastback: a wide roof and one unbroken painted slope from roof to tail. Narrow rear glass between
    wide sail panels, flared rear haunches."""
    w, roof = 3.74, 5.7
    p = chassis() + tub()
    p += [
        wdg(SX, w, SILL, BELT, -1.2, 0.8, PLAN_IN_BACK, m=True, note="haunch flare lead-in"),
        blk(SX, w, SILL, BELT, 0.8, 5.6, m=True, note="haunch flare"),
        wdg(-3.0, 3.0, DECK, roof, -3.0, -0.6, RISE, "glass", note="windscreen"),
        wdg(3.0, 3.4, DECK, roof, -3.0, -0.6, RISE, m=True, note="A-pillar"),
        blk(-3.4, 3.4, roof - 0.3, roof, -0.6, 1.4, note="roof"),
        blk(-3.25, 3.25, DECK, roof - 0.3, -0.6, 1.4, "glass", note="side glass"),
        wdg(-1.7, 1.7, DECK, roof, 1.4, 6.2, FALL, "glass", note="narrow fastback glass"),
        wdg(1.7, 3.4, DECK, roof, 1.4, 6.2, FALL, m=True, note="wide sail panel"),
        blk(3.4, 3.46, 3.7, 4.4, 1.7, 2.9, "detail", m=True, note="quarter vent on the sail panel"),
        blk(0.35, 1.35, roof, roof + 0.06, -0.6, 1.4, "secondary", m=True, note="roof stripes"),
        blk(0.35, 1.35, DECK, DECK + 0.06, -5.2, -3.0, "secondary", m=True, note="cowl stripes"),
        blk(w, w + 0.05, STRIPE - 0.15, STRIPE + 0.15, 0.8, 5.6, "secondary", m=True, note="belt stripe on the haunch"),
    ]
    p += driver(-1.6, 0.3, 4.4)
    return p


def cockpit_outlaw():
    """60s notchback: three boxes and the tallest roof. Upright screen, squared contrast roof with a visor,
    a thick formal pillar with a vertical rear screen, then a long flat boot deck."""
    roof = 6.3
    p = chassis() + tub()
    p += [
        wdg(-2.6, 2.6, DECK, roof - 0.4, -3.0, -1.9, RISE, "glass", note="upright windscreen"),
        wdg(2.6, 3.0, DECK, roof - 0.4, -3.0, -1.9, RISE, m=True, note="A-pillar"),
        blk(-3.0, 3.0, roof - 0.4, roof, -2.4, 1.8, "secondary", note="squared contrast roof with a visor peak"),
        blk(-2.85, 2.85, DECK, roof - 0.4, -1.9, 0.6, "glass", note="side glass"),
        blk(-3.0, 3.0, DECK, roof - 0.4, 0.6, 1.8, note="thick formal C-pillar"),
        blk(-2.1, 2.1, 4.0, roof - 0.7, 1.8, 1.88, "glass", note="vertical rear screen"),
        blk(-2.4, 2.4, DECK, DECK + 0.08, -4.6, -3.5, "detail", note="cowl vent grille"),
        blk(-1.6, 1.6, DECK, DECK + 0.06, 2.6, 6.0, "secondary", note="boot lid panel on the flat deck (Z 1.9 to 6.2)"),
        blk(SX, 3.7, 1.0, 2.4, 2.8, 5.4, m=True, note="quarter scoop"),
        blk(3.45, 3.65, 1.2, 2.2, 2.68, 2.8, "detail", m=True, note="scoop mouth"),
        blk(SX, SX + 0.05, STRIPE - 0.15, STRIPE + 0.15, -5.2, 2.6, "secondary", m=True, note="belt stripe"),
    ]
    p += driver(-1.3, -0.5, 4.8)
    return p


def cockpit_stiletto():
    """70s wedge: low shoulders, a narrow cab-forward canopy, short roof, high louvred engine deck, tail fins."""
    low = 2.4
    p = chassis() + tub(low)
    p += [
        wdg(1.6, SX, low, DECK, -4.5, -1.5, FALL, m=True, note="shoulder falls away behind the seam section"),
        blk(-1.6, 1.6, low, DECK, -4.5, 0.8, note="centre fuselage, cowl at the deck datum"),
        wdg(-1.4, 1.4, DECK, 4.7, -4.4, -0.8, RISE, "glass", note="long flat windscreen"),
        wdg(1.4, 1.6, DECK, 4.7, -4.4, -0.8, RISE, m=True, note="canopy rail"),
        blk(-1.6, 1.6, 4.4, 4.7, -0.8, 0.8, note="roof"),
        blk(-1.5, 1.5, DECK, 4.4, -0.8, 0.8, "glass", note="side glass"),
        blk(-SX, SX, low, BELT, 0.8, 5.5, note="rear shoulder"),
        blk(-2.4, 2.4, BELT, 4.1, 0.8, 6.2, note="high engine deck"),
        wdg(2.4, 2.75, 4.1, 5.6, 1.6, 6.2, RISE, m=True, note="tail fin"),
        blk(-0.6, 0.6, 4.7, 5.0, -0.4, 1.4, "detail", note="periscope scoop"),
        blk(SX, 3.7, 1.2, low, 1.4, 3.6, m=True, note="side intake box"),
        blk(SX, SX + 0.05, 0.6, 0.9, -5.2, 1.2, "secondary", m=True, note="sill stripe"),
    ]
    for z in (2.0, 4.0):
        p.append(blk(-1.9, 1.9, 4.1, 4.22, z, z + 1.0, "detail", note="deck louvre"))
    p += driver(-0.6, -1.0, 3.8)
    return p


def cockpit_mamba():
    """Roadster: open cockpit, cut-down doors, twin aero screens, twin headrest fairings. The boat tail belongs to the Rear Clip."""
    low = 2.5
    p = chassis() + tub(low)
    p += [
        blk(-2.8, 2.8, low, DECK, -4.5, -2.2, note="scuttle at the deck datum"),
        wdg(2.8, SX, low, DECK, -4.5, -3.0, PLAN_IN_FRONT, m=True, note="scuttle hip widens to the seam section"),
        blk(-2.8, 2.8, low, DECK, 1.2, 5.5, note="rear deck at the deck datum"),
        wdg(2.8, SX, low, DECK, 4.0, 5.5, PLAN_IN_BACK, m=True, note="rear hip widens to the seam section"),
        wdg(0.4, 2.4, DECK, 4.3, -2.7, -1.9, RISE, "glass", m=True, note="aero screen"),
        blk(0.3, 2.5, 4.25, 4.37, -1.97, -1.83, "secondary", m=True, note="screen header"),
        blk(-2.6, 2.6, low, low + 0.12, -2.2, 1.2, "detail", note="open cockpit well"),
        blk(0.4, 2.0, low, 3.7, 0.8, 1.2, "detail", m=True, note="seat back"),
        wdg(0.4, 2.0, DECK, 4.3, 1.2, 4.8, FALL, m=True, note="headrest fairing"),
        blk(-0.4, 0.4, DECK, DECK + 0.06, 1.2, 6.2, "secondary", note="centre stripe, rear"),
        blk(-0.4, 0.4, DECK, DECK + 0.06, -5.2, -2.2, "secondary", note="centre stripe, scuttle"),
        blk(SX, SX + 0.05, STRIPE - 0.15, STRIPE + 0.15, -5.2, 6.2, "secondary", m=True, note="belt stripe"),
    ]
    p += driver(-1.2, 0.2, 4.2)
    return p


def cockpit_nightshift():
    """80s T-top: the lowest closed roof. Glass roof panels either side of a T-bar, a raised basket-handle targa hoop,
    a louvred glass hatch, box sills."""
    w, roof, hoop = 3.74, 4.5, 5.2
    p = chassis() + tub()
    p += [
        blk(SX, w, 0.5, 1.3, -3.7, 3.9, "detail", m=True, note="box sill"),
        blk(w, w + 0.05, 0.8, 1.0, -3.6, 3.8, "neon", m=True, note="sill light"),
        blk(-3.2, 3.2, DECK, DECK + 0.08, -3.7, -3.0, "detail", note="wiper cowl strip"),
        wdg(-3.0, 3.0, DECK, roof, -3.0, -1.4, RISE, "glass", note="windscreen"),
        wdg(3.0, 3.4, DECK, roof, -3.0, -1.4, RISE, m=True, note="A-pillar"),
        blk(-0.35, 0.35, roof - 0.2, roof, -1.4, 0.6, note="T-bar"),
        blk(0.35, 3.25, roof - 0.2, roof - 0.04, -1.4, 0.6, "glass", m=True, note="glass roof panel"),
        blk(-3.15, 3.15, DECK, roof - 0.2, -1.4, 0.6, "glass", note="side glass"),
        blk(-3.4, 3.4, DECK, hoop, 0.6, 1.5, note="raised targa hoop"),
        wdg(-2.9, 2.9, DECK, roof, 1.5, 4.6, FALL, "glass", note="glass hatch"),
        wdg(2.9, 3.4, DECK, roof, 1.5, 4.6, FALL, m=True, note="hatch frame"),
        blk(-3.0, 3.0, DECK, DECK + 0.1, 5.1, 5.5, "detail", note="rear shelf vent"),
    ]
    p += slats(-2.7, 2.7, roof, 1.5, DECK, 4.6, 3, depth=0.6)
    p += driver(-1.5, -0.3, 3.6)
    return p


def cockpit_regent():
    """Grand tourer: a slim teardrop greenhouse. Screen set well forward, short low roof, a roof band,
    then one long glass fastback that runs to the rear seam. Wing vents."""
    roof = 5.0
    p = chassis() + tub()
    p += [
        wdg(-2.3, 2.3, DECK, roof, -4.3, -1.7, RISE, "glass", note="long raked windscreen"),
        wdg(2.3, 2.6, DECK, roof, -4.3, -1.7, RISE, m=True, note="A-pillar"),
        blk(-2.6, 2.6, roof - 0.25, roof, -1.7, 0.2, note="low roof"),
        blk(-2.45, 2.45, DECK, roof - 0.25, -1.7, -0.3, "glass", note="side glass"),
        blk(-2.66, 2.66, DECK, roof + 0.06, -0.3, 0.2, "secondary", note="roof band"),
        wdg(-2.3, 2.3, DECK, roof, 0.2, 6.2, FALL, "glass", note="long glass fastback to the rear seam"),
        wdg(2.3, 2.6, DECK, roof, 0.2, 6.2, FALL, m=True, note="fastback frame"),
        blk(SX, 3.62, 1.2, 2.4, -4.5, -2.5, m=True, note="wing vent box"),
        blk(SX, SX + 0.05, 0.6, 0.85, -2.5, 6.2, "secondary", m=True, note="chrome sill strip"),
        blk(-0.25, 0.25, DECK, DECK + 0.06, -5.2, -4.3, "secondary", note="bonnet centre line"),
    ]
    for i in range(2):
        p.append(blk(3.62, 3.67, 1.4, 2.2, -4.2 + 0.9 * i, -3.7 + 0.9 * i, "detail", m=True, note="vent gill"))
    p += driver(-1.2, -0.6, 4.1)
    return p


# ----------------------------------------------------------------------------- pads shared by parents


def fb_pads(nose_x=2.9, nac_x=4.4, strut_y=1.9, strut_z=(-8.6, -11.0)):
    """Pads every Front Clip must carry, at fixed places."""
    p = [
        blk(-2.2, 2.2, 0.5, 2.6, ZF - G, ZF, "detail", note="rear coupler: mates with the cabin coupler flange"),
        blk(-SX, SX, SILL, DECK, ZF - G - COLLAR, ZF - G, note="shoulder collar: the shared seam section"),
        blk(5.2, 7.2, POD_FLOOR, 1.0, -13.5, -9.5, "detail", m=True, note="engine pad under the fender"),
        blk(5.4, 7.0, 3.2, BODY_TOP, -11.8, -9.4, "detail", m=True, note="intake pad on the fender top"),
        blk(4.9, 7.7, 1.0, 2.45, ZX - 0.3, ZX, "detail", m=True, note="nozzle bay bulkhead under the fender tail"),
        blk(5.6, 6.8, 1.05, 1.5, ZN, ZN + 0.3, "detail", m=True, note="front bumper hardpoint on the fender tip"),
        blk(-1.3, 1.3, SILL, 1.4, ZN + 0.2, ZN + 0.5, "detail", note="centre bumper pad: backs any full-width bumper"),
    ]
    for z in strut_z:
        p.append(cxx(nose_x - 0.2, nac_x + 0.2, strut_y, z, 0.5, "detail", m=True, note="rift strut"))
    return p


def fb_taper(nose_x, z0=-9.0, y1=DECK):
    """Painted collar taper: from the seam section down to the clip's own nose width over 2.5 studs."""
    return [wdg(nose_x, SX, SILL, y1, z0, ZF - G - COLLAR, PLAN_IN_BACK, m=True, note="collar taper to the nose width")]


def rb_pads(tail_x=2.9, pod_x=4.4, strut_y=1.9, strut_z=(8.2, 10.3), collar_z=PCZ):
    """Pads every Rear Clip must carry, at fixed places.
    collar_z: a pod that already has the collar section further forward may start its collar there."""
    p = [
        blk(-2.2, 2.2, 0.5, 2.6, ZR, ZR + G, "detail", note="front coupler: mates with the cabin coupler flange"),
        blk(-SX, SX, SILL, DECK, ZR + G, ZR + G + COLLAR, note="shoulder collar: the shared seam section"),
        blk(-2.4, 2.4, SILL, 3.2, ZT - G, ZT, "detail", note="tail panel: afterburner pad above Y 1.0, rear bumper pad below"),
        blk(-2.0, 2.0, DECK, BODY_TOP, 11.0, 13.5, "detail", note="spoiler pad"),
        blk(PCX0, PCX1, PCY0, PCY1, collar_z, ZP - G, m=True, note="pod end collar: the shared rear engine section"),
        blk(5.3, 7.1, 1.0, 2.6, ZP - G, ZP, "detail", m=True, note="rear engine bulkhead"),
    ]
    for z in strut_z:
        p.append(cxx(tail_x - 0.2, pod_x + 0.2, strut_y, z, 0.5, "detail", m=True, note="rift strut"))
    return p


def rb_taper(tail_x, z1=10.0, y0=SILL, y1=DECK):
    return [wdg(tail_x, SX, y0, y1, ZR + G + COLLAR, z1, PLAN_IN_FRONT, m=True, note="collar taper to the tail width")]


Z_FC = ZF - G - COLLAR   # -6.5: where each clip's own nose shape meets its collar
Z_RC = ZR + G + COLLAR   # 7.5: where each clip's own tail shape meets its collar


def sp_brackets(x1=4.1):
    return [blk(XC + 0.05, x1, 0.9, 1.7, -3.2, -2.2, "detail", m=True, note="bracket on the front side hardpoint"),
            blk(XC + 0.05, x1, 0.9, 1.7, 2.6, 3.6, "detail", m=True, note="bracket on the rear side hardpoint")]


def stab_mount():
    return [blk(-1.9, 1.9, -0.35, -0.05, -4.0, 5.0, "detail", note="mount plate under the cabin floor pan")]


def e1_pylon(x0=5.6, x1=6.8, z0=-13.2, z1=-9.8, y0=0.3):
    return [blk(x0, x1, y0, POD_FLOOR - 0.05, z0, z1, "detail", m=True, note="pylon up to the fender engine pad")]


def e1_base(x0=5.5, x1=6.9, z0=-12.2, z1=-9.2):
    return [blk(x0, x1, BODY_TOP + 0.05, BODY_TOP + 0.2, z0, z1, "detail", m=True, note="base plate on the fender intake pad")]


def e2_flange(x0=5.0, x1=7.4, y0=0.8, y1=2.8):
    return [blk(x0, x1, y0, y1, ZP + 0.05, ZP + 0.4, "detail", m=True, note="flange on the pod bulkhead")]


def fbumper_brackets():
    return [blk(5.6, 6.8, 1.05, 1.45, ZN - 0.4, ZN - 0.05, "detail", m=True, note="bracket on the fender hardpoint")]


def rbumper_brackets():
    return [blk(1.2, 2.0, 0.3, 0.75, ZT + 0.05, ZT + 0.5, "detail", m=True, note="bracket on the tail panel")]


# ----------------------------------------------------------------------------- FrontBody (Front Clip)
# Every fender nacelle is at least 3.0 wide and 2.2 tall, and runs the full 10.4 from tip to seam in paint.
# Its tail is an eave (Y 2.6 up) over the front engine's nozzle bay.


def fb_longhorn():
    """Muscle. The biggest clip: tall square fenders, twin round lamps, wide nose, egg-crate grille, shaker scoop."""
    p = fb_pads(nose_x=3.0, nac_x=4.4) + fb_taper(3.0)
    p += [
        blk(-3.0, 3.0, 0.5, BELT, -15.7, Z_FC, note="centre nose, out to the centre bumper pad"),
        blk(-3.0, 3.0, BELT, DECK, -12.8, Z_FC, note="bonnet"),
        wdg(-3.0, 3.0, BELT, DECK, -15.7, -12.8, RISE, note="bonnet leading slope"),
        blk(-2.7, 2.7, 0.9, 2.5, -16.0, -15.7, "detail", note="egg-crate grille"),
        blk(1.6, 2.4, 1.4, 2.0, -16.1, -16.0, "neon", m=True, note="grille lamp"),
        blk(0.35, 1.35, DECK, DECK + 0.06, -12.8, ZF - G, "secondary", m=True, note="bonnet stripe"),
        blk(-1.0, 1.0, DECK, 4.2, -10.4, -7.0, note="shaker scoop"),
        blk(-0.8, 0.8, 3.6, 4.1, -10.55, -10.4, "detail", note="scoop mouth"),
        blk(4.4, 8.3, 1.0, 2.8, -15.8, ZX, m=True, note="fender shell"),
        blk(4.4, 8.3, 2.8, 3.5, -13.3, ZF - G, m=True, note="fender top and tail eave"),
        wdg(4.4, 8.3, 2.8, 3.5, -15.8, -13.3, RISE, m=True, note="fender leading slope"),
        blk(4.5, 8.2, 1.1, 2.7, -16.2, -15.8, "detail", m=True, note="lamp bezel"),
        cz(5.45, 1.9, -16.4, -16.2, 1.0, "neon", m=True, note="headlamp"),
        cz(7.25, 1.9, -16.4, -16.2, 1.0, "neon", m=True, note="headlamp"),
    ]
    return p


def fb_blower_rail():
    """Pro Street. Slab-sided fenders with a chrome rail as trim, a short nose behind a tall grille shell, bare frame ahead, tall blower."""
    p = fb_pads(nose_x=2.3, nac_x=4.8) + fb_taper(2.3)
    p += [
        blk(4.8, 7.8, 1.0, 3.2, -15.8, ZX, m=True, note="slab fender"),
        blk(4.8, 7.8, 2.6, 3.2, ZX, ZF - G, m=True, note="fender tail eave"),
        cz(6.3, 2.1, -16.2, -15.8, 1.7, "detail", m=True, note="lamp bucket"),
        cz(6.3, 2.1, -16.45, -16.2, 1.2, "neon", m=True, note="single headlamp"),
        cz(8.15, 1.75, -16.2, ZX - 0.05, 0.6, "secondary", m=True, note="chrome rail trim"),
        blk(-2.3, 2.3, 0.5, 3.0, -10.6, Z_FC, note="short nose"),
        blk(-2.3, 2.3, 3.0, DECK, -9.4, Z_FC, note="bonnet"),
        wdg(-2.3, 2.3, 3.0, DECK, -10.6, -9.4, RISE, note="bonnet leading slope"),
        blk(-2.0, 2.0, 0.7, 3.7, -11.2, -10.6, "secondary", note="tall grille shell"),
        blk(-1.6, 1.6, 1.0, 3.4, -11.32, -11.2, "detail", note="grille"),
        blk(0.8, 1.3, 0.6, 1.1, ZN + 0.5, -10.6, "detail", m=True, note="bare frame rail, out to the centre bumper pad"),
        cxx(-1.2, 1.2, 1.75, -13.6, 1.3, "secondary", note="fuel tank"),
        blk(-1.1, 1.1, DECK, 4.0, -9.0, -6.6, "detail", note="blower case"),
        blk(-0.9, 0.9, 4.0, 4.55, -8.8, -7.0, "secondary", note="blower scoop"),
        blk(-0.7, 0.7, 4.1, 4.45, -8.95, -8.8, "detail", note="scoop mouth"),
    ]
    return p


def fb_popup_prongs():
    """Wedge Exotic. Arrow prongs: knife-edge wedge fenders, barbed in plan, with pop-up lamps. An arrowhead nose that flares into the collar."""
    p = fb_pads(nose_x=2.6, nac_x=4.4, strut_y=1.4, strut_z=(-8.4, -9.6))
    p += [
        blk(4.8, 7.8, 1.0, 1.5, -16.2, -12.0, m=True, note="prong blade: a blunt 0.5 edge behind the bumper hardpoint"),
        wdg(4.8, 7.8, 1.5, 3.2, -16.2, -12.0, RISE, m=True, note="prong wedge"),
        blk(4.8, 7.8, 1.0, 3.2, -12.0, ZX, m=True, note="prong root"),
        blk(4.8, 7.8, 2.6, 3.2, ZX, ZF - G, m=True, note="prong tail eave"),
        wdg(7.8, 8.4, 1.0, 1.7, -14.2, ZX, PLAN_IN_BACK, m=True, note="outer barb"),
        wdg(4.4, 4.8, 1.0, 1.7, -14.2, ZX, PLAN_OUT_BACK, m=True, note="inner barb"),
        blk(5.7, 6.9, 1.9, 2.75, -14.4, -13.6, "detail", m=True, note="pop-up lamp pod"),
        blk(5.85, 6.75, 2.2, 2.65, -14.5, -14.4, "neon", m=True, note="lamp"),
        wdg(-0.9, 0.9, 0.5, DECK, ZN + 0.5, -8.0, RISE, note="dart spine: its point reaches the centre bumper pad"),
        blk(-0.9, 0.9, 0.5, DECK, -8.0, Z_FC, note="spine root"),
        wdg(0.9, SX, 0.5, 1.9, -15.0, Z_FC, PLAN_IN_BACK, m=True, note="arrowhead flank"),
        wdg(0.9, SX, 1.9, DECK, -9.0, Z_FC, PLAN_IN_BACK, m=True, note="collar taper to the spine"),
    ]
    p += slats(-0.7, 0.7, 1.88, -12.2, 3.25, -8.4, 3, depth=0.7)
    return p


def fb_grand_quad():
    """Roadster. Full-length round-topped pontoon fenders with bullet noses, and a long oval cigar nose."""
    p = fb_pads(nose_x=2.2, nac_x=4.7, strut_z=(-9.6, -12.0)) + fb_taper(2.2)
    p += [
        blk(4.7, 7.7, 1.0, 2.2, -14.8, ZX, m=True, note="pontoon skirt"),
        cz(6.2, 2.2, -15.1, ZX, 2.7, m=True, note="pontoon crown"),
        ball(6.2, 2.2, -15.1, 2.7, m=True, note="bullet nose"),
        blk(4.9, 7.5, 2.6, 3.5, ZX, ZF - G, m=True, note="pontoon tail eave"),
        ball(6.2, 2.2, -15.95, 1.0, "neon", m=True, note="headlamp"),
        blk(7.7, 7.76, 1.45, 1.75, -14.8, ZX, "secondary", m=True, note="chrome side spear"),
        cz(0.9, 1.9, -15.0, -9.0, 2.6, m=True, note="oval cigar nose, one lobe"),
        blk(-0.9, 0.9, 0.6, 3.2, -15.0, -9.0, note="cigar nose, centre"),
        ball(0.9, 1.9, -15.0, 2.6, m=True, note="nose cap"),
        cxx(-0.9, 0.9, 1.9, -15.0, 2.6, "primary", note="nose cap, centre"),
        blk(-2.2, 2.2, 0.5, DECK, -9.0, Z_FC, note="nose root"),
        cz(0, 1.9, -16.45, -15.8, 1.5, "detail", note="oval mouth"),
        blk(-0.4, 0.4, 3.2, 3.27, -14.4, -9.0, "secondary", note="centre stripe"),
        blk(-0.4, 0.4, DECK, DECK + 0.06, -9.0, ZF - G, "secondary", note="centre stripe, root"),
    ]
    return p


def fb_flip_nose():
    """Turbo Pony. Stepped slab fenders with flip-up lamp pods, and a very wide flat nose that ramps up to the cowl late."""
    p = fb_pads(nose_x=3.6, nac_x=4.8, strut_y=1.45, strut_z=(-9.6, -12.2))
    p += [
        blk(4.8, 8.5, 1.0, 2.1, -16.0, ZX, m=True, note="slab fender"),
        wdg(4.8, 8.5, 2.1, 3.2, -13.6, -11.8, RISE, m=True, note="fender ramp"),
        blk(4.8, 8.5, 2.1, 3.2, -11.8, ZX, m=True, note="raised fender deck"),
        blk(4.8, 8.5, 2.6, 3.2, ZX, ZF - G, m=True, note="fender tail eave"),
        blk(5.9, 7.4, 2.1, 2.6, -15.4, -14.4, m=True, note="flip-up lamp pod"),
        blk(6.0, 7.3, 2.2, 2.5, -15.5, -15.4, "neon", m=True, note="lamp"),
        blk(5.0, 8.3, 1.15, 1.95, -16.2, -16.0, "detail", m=True, note="fender face"),
        blk(-3.6, 3.6, 0.5, 2.0, -16.0, Z_FC, note="wide flat nose"),
        wdg(-SX, SX, 2.0, DECK, -9.6, -7.2, RISE, note="cowl ramp"),
        blk(-SX, SX, 2.0, DECK, -7.2, Z_FC, note="cowl block"),
        blk(-3.3, 3.3, 0.9, 1.6, -16.2, -16.0, "detail", note="grille slot"),
        blk(1.4, 2.8, 2.0, 2.08, -14.6, -11.6, "detail", m=True, note="bonnet vent"),
        blk(-3.2, 3.2, 0.2, 0.5, -15.0, -6.0, "detail", note="under-tray"),
    ]
    for i in range(2):
        p.append(blk(8.5, 8.55, 1.15 + 0.35 * i, 1.3 + 0.35 * i, -15.0, -9.8, "detail", m=True, note="side strake"))
    return p


def fb_long_nose():
    """Euro GT. A long low bonnet with a power bulge and a small oval grille, and crowned fenders with faired lamps."""
    p = fb_pads(nose_x=2.8, nac_x=4.6, strut_z=(-8.6, -11.4)) + fb_taper(2.8)
    p += [
        blk(-2.8, 2.8, 0.5, 2.6, -14.2, Z_FC, note="long nose"),
        wdg(-2.8, 2.8, 2.6, DECK, -14.2, -10.0, RISE, note="bonnet slope"),
        blk(-2.8, 2.8, 2.6, DECK, -10.0, Z_FC, note="bonnet"),
        blk(-2.2, 2.2, 0.6, 2.4, -15.85, -14.2, note="nose tip, out to the centre bumper pad"),
        blk(-1.7, 1.7, 0.9, 2.1, -16.0, -15.85, "detail", note="oval grille"),
        blk(0.5, 1.3, 1.2, 1.8, -16.1, -16.0, "neon", m=True, note="driving lamp"),
        blk(-0.8, 0.8, DECK, 3.8, -12.0, -7.4, note="power bulge"),
        blk(4.6, 7.8, 1.0, 2.4, -15.2, ZX, m=True, note="fender"),
        wdg(4.6, 7.8, 1.0, 2.4, -16.3, -15.2, RISE, m=True, note="pointed fender tip"),
        wdg(4.6, 7.8, 2.4, 3.4, -15.2, -12.2, RISE, m=True, note="fender crown"),
        blk(4.6, 7.8, 2.4, 3.4, -12.2, ZX, m=True, note="fender top"),
        blk(4.6, 7.8, 2.6, 3.4, ZX, ZF - G, m=True, note="fender tail eave"),
        blk(5.5, 6.9, 2.4, 2.78, -15.1, -14.5, "neon", m=True, note="faired lamp"),
        blk(7.8, 7.86, 1.75, 2.05, -15.2, ZX, "secondary", m=True, note="chrome side strip"),
    ]
    return p


# ----------------------------------------------------------------------------- Engine1 (Front Engines)
# Three places on each side: the body under the fender, an intake stack on the fender-top pad (each option
# has its own outline), and the nozzle in the bay under the fender tail (Y 1 or higher, facing the chase camera).


def e1_ram():
    """Muscle. One big turbine behind a square chin scoop. Top: a square ram scoop. One big round nozzle."""
    x, y = 6.2, -0.6
    p = e1_pylon() + e1_base()
    p += [
        cz(x, y, -14.6, -8.2, 2.1, "primary", m=True, note="turbine body"),
        blk(4.9, 7.5, -1.65, 0.6, -16.4, -14.6, "primary", m=True, note="square chin scoop"),
        wdg(4.9, 7.5, 0.1, 0.6, -17.2, -16.4, RISE, "primary", m=True, note="scoop upper lip"),
        blk(5.1, 7.3, -1.45, 0.1, -16.55, -16.4, "detail", m=True, note="scoop mouth"),
        blk(4.9, 7.5, -1.65, -1.45, -17.0, -16.4, "secondary", m=True, note="scoop lower lip"),
        cz(x, y, -12.4, -11.0, 2.2, "detail", m=True, note="compressor band"),
        blk(5.3, 7.1, -1.3, 2.25, -8.2 + 0.65, -6.9, "detail", m=True, note="jet pipe riser"),
        blk(5.3, 7.1, -1.3, 0.7, -8.2, -7.55, "detail", m=True, note="jet pipe elbow"),
        cz(x, 1.3, -6.9, -6.1, 1.75, "secondary", m=True, note="nozzle"),
        cz(x, 1.3, -6.1, -5.8, 1.3, "thrust", m=True, note="jet"),
        blk(5.6, 6.8, 3.8, 4.55, -12.9, -10.2, "primary", m=True, note="ram scoop on the fender top"),
        wdg(5.6, 6.8, 3.8, 4.55, -10.2, -8.4, FALL, "primary", m=True, note="scoop tail"),
        blk(5.75, 6.65, 3.9, 4.45, -13.05, -12.9, "detail", m=True, note="scoop mouth"),
    ]
    return p


def e1_zoomie_rails():
    """Pro Street. Two slim wide-set tubes with velocity stacks. Top: twin upright stacks. Two zoomie pipes sweep up behind the fender."""
    p = e1_pylon(5.6, 6.8, -13.2, -9.8, 0.1) + e1_base()
    p.append(blk(4.6, 7.8, -0.35, 0.1, -12.3, -10.7, "detail", m=True, note="clamp bar"))
    for x, z0 in ((4.9, -16.6), (7.5, -15.0)):
        p += [
            cz(x, -0.9, z0, -7.9, 1.1, "secondary", m=True, note="rail tube"),
            cz(x, -0.9, z0 - 1.0, z0, 1.45, "detail", m=True, note="velocity stack"),
        ]
        p += sweep(x, -0.8, -7.75, 50.0, ((2.4, 0.95, "secondary", "zoomie pipe"), (0.3, 0.7, "thrust", "jet")))
    for z in (-11.5, -10.0):
        p += [
            cyv(6.2, 3.8, 4.5, z, 0.95, "secondary", m=True, note="upright stack"),
            cyv(6.2, 4.5, 4.58, z, 0.65, "neon", m=True, note="stack throat"),
        ]
    return p


def e1_slot_ram():
    """Wedge Exotic. One flat wide ramjet with a lip intake. Top: a long low slot intake. A flat slot nozzle."""
    p = e1_pylon(5.4, 7.0, -13.2, -9.8, 0.3) + e1_base(5.2, 7.2, -12.4, -9.0)
    p += [
        blk(4.4, 8.0, -1.1, 0.3, -14.2, -7.6, m=True, note="ramjet slab"),
        wdg(4.4, 8.0, -0.4, 0.3, -16.0, -14.2, UNDER_F, m=True, note="intake lip"),
        blk(4.6, 7.8, -1.05, -0.4, -14.35, -14.2, "detail", m=True, note="intake mouth"),
        blk(5.55, 5.75, -1.1, -0.4, -15.2, -14.2, "detail", m=True, note="intake splitter"),
        blk(6.65, 6.85, -1.1, -0.4, -15.2, -14.2, "detail", m=True, note="intake splitter"),
        blk(5.3, 8.1, -1.1, 0.3, -7.55, -6.6, m=True, note="up-ramp base"),
        wdg(5.3, 8.1, 0.3, 2.3, -7.55, -6.6, RISE, m=True, note="up-ramp"),
        blk(5.3, 8.1, 0.9, 2.3, -6.6, -6.05, "detail", m=True, note="slot nozzle housing"),
        blk(5.5, 7.9, 1.3, 1.9, -6.05, -5.8, "thrust", m=True, note="slot jet"),
        wdg(5.0, 7.4, 3.8, 4.15, -13.8, -12.0, RISE, m=True, note="slot intake ramp on the fender top"),
        blk(5.0, 7.4, 3.8, 4.15, -12.0, -8.4, m=True, note="slot intake"),
        blk(5.2, 7.2, 4.15, 4.21, -11.6, -9.0, "neon", m=True, note="intake slot"),
    ]
    return p


def e1_quad_cluster():
    """Roadster. Four slim jets in a wide square under the fender tip. Top: four small trumpets. Four small nozzles."""
    p = e1_pylon(5.6, 6.8, -13.4, -11.2, 0.3) + e1_base(5.4, 7.0, -12.0, -9.8)
    p += [
        blk(4.7, 7.7, -1.7, 0.3, -11.0, -10.4, "detail", m=True, note="collector"),
        blk(4.7, 7.7, -1.3, -0.2, -15.75, -15.6, "detail", m=True, note="intake bar"),
        cz(6.2, -0.9, -10.4, -7.55, 0.9, "secondary", m=True, note="tail pipe"),
        blk(5.4, 7.0, -1.4, 2.35, -7.55, -6.7, "detail", m=True, note="pipe riser"),
    ]
    for x in (5.1, 7.3):
        for y in (-0.25, -1.2):
            p.append(cz(x, y, -15.6, -11.0, 0.9, "secondary", m=True, note="small jet"))
    for x in (5.8, 6.6):
        for y in (0.95, 1.85):
            p.append(cz(x, y, -6.7, -5.85, 0.6, "thrust", m=True, note="jet"))
        for z in (-11.4, -10.4):
            p.append(cyv(x, 3.8, 4.5, z, 0.6, "secondary", m=True, note="intake trumpet"))
    return p


def e1_cassette():
    """Turbo Pony. A boxy turbo cassette with a grille intake and twin barrels. Top: an intercooler box. Twin square outlets and a side dump."""
    p = e1_pylon(5.6, 6.8, -11.8, -9.7, 0.4)
    p += [
        blk(4.7, 7.7, -1.5, 0.4, -11.6, -9.4, m=True, note="cassette box"),
        blk(4.9, 7.5, -1.3, 0.2, -11.8, -11.6, "detail", m=True, note="intercooler grille"),
        blk(5.1, 7.3, -0.75, -0.4, -11.9, -11.8, "neon", m=True, note="grille light"),
        cxx(7.7, 8.25, -0.9, -10.5, 0.7, "detail", m=True, note="side dump pipe"),
        cxx(8.25, 8.45, -0.9, -10.5, 0.5, "thrust", m=True, note="side dump jet"),
        blk(5.2, 7.8, -1.3, 2.3, -7.55, -6.5, m=True, note="outlet box"),
        blk(5.2, 7.8, 0.9, 2.3, -6.5, -6.1, "detail", m=True, note="outlet face"),
        blk(5.5, 6.35, 1.25, 1.95, -6.1, -5.85, "thrust", m=True, note="square jet"),
        blk(6.7, 7.55, 1.25, 1.95, -6.1, -5.85, "thrust", m=True, note="square jet"),
        blk(4.9, 7.5, 3.65, 4.55, -12.4, -10.0, m=True, note="intercooler box on the fender top"),
        blk(5.1, 7.3, 3.9, 4.3, -12.5, -12.4, "neon", m=True, note="intercooler light"),
    ]
    for x in (5.45, 6.95):
        p.append(cz(x, -0.6, -9.4, -7.55, 1.3, "secondary", m=True, note="barrel"))
    return p


def e1_straight_six():
    """Euro GT. One long slim engine with a bullet intake. Top: a cam cover with four side trumpets. Over-under megaphones."""
    x, y = 6.2, -0.55
    p = e1_pylon(5.7, 6.7, -13.2, -9.8, 0.2)
    p += [
        cz(x, y, -15.6, -8.2, 1.5, "primary", m=True, note="long slim engine"),
        ball(x, y, -15.6, 1.5, "secondary", m=True, note="bullet intake"),
        ball(x, y, -16.3, 0.6, "neon", m=True, note="intake tip"),
        blk(5.6, 6.8, -1.3, 0.7, -8.2, -7.55, "detail", m=True, note="pipe elbow"),
        blk(5.6, 6.8, -1.3, 2.35, -7.55, -6.8, "detail", m=True, note="pipe riser"),
        blk(5.85, 6.5, 3.65, 4.2, -13.6, -8.6, "secondary", m=True, note="cam cover on the fender top"),
    ]
    for yy in (0.95, 1.95):
        p += [
            cz(x, yy, -6.8, -6.1, 1.0, "secondary", m=True, note="megaphone"),
            cz(x, yy, -6.1, -5.85, 0.7, "thrust", m=True, note="jet"),
        ]
    for i in range(4):
        z = -13.0 + 1.25 * i
        p.append(cxx(6.5, 7.3, 3.95, z, 0.45, "detail", m=True, note="side trumpet"))
    return p


# ----------------------------------------------------------------------------- Engine2 (Rear Engines)


def e2_thunder_twins():
    """Muscle. A close pair of long slim cans behind each rear-quarter pod, inside the collar section."""
    p = e2_flange(4.7, 7.9, 0.9, 2.9)
    for x in (5.4, 7.2):
        p += [
            cz(x, 1.9, ZP + 0.4, 16.4, 1.4, "primary", m=True, note="can"),
            cz(x, 1.9, 16.4, 17.2, 1.15, "detail", m=True, note="nozzle"),
            cz(x, 1.9, 17.2, 17.45, 0.85, "thrust", m=True, note="jet"),
        ]
    p += [
        blk(5.0, 7.6, 2.6, 2.85, 12.3, 14.4, "detail", m=True, note="top intake grille"),
        blk(6.1, 6.5, 1.4, 2.4, 12.0, 15.6, "detail", m=True, note="web between the cans"),
    ]
    return p


def e2_big_bertha():
    """Pro Street. One long heavy turbine behind each pod: 2.8 across, 5.8 long, a tall ram scoop, a small petalled nozzle."""
    x, y = 6.3, 1.75
    p = [blk(5.0, 7.6, 0.6, 3.0, ZP + 0.05, ZP + 0.3, "detail", m=True, note="flange on the pod bulkhead")]
    p += [
        cz(x, y, ZP + 0.3, 15.0, 2.8, "primary", m=True, note="turbine body"),
        cz(x, y, 15.0, 16.2, 2.3, "primary", m=True, note="tail cone"),
        cz(x, y, 16.2, 17.1, 1.9, "detail", m=True, note="nozzle"),
        cz(x, y, 17.1, 17.4, 1.5, "thrust", m=True, note="jet"),
        blk(x - 0.45, x + 0.45, y + 0.8, y + 1.0, 16.0, 17.45, "detail", m=True, note="nozzle petal, top"),
        blk(x - 0.45, x + 0.45, y - 1.0, y - 0.8, 16.0, 17.45, "detail", m=True, note="nozzle petal, bottom"),
        blk(5.6, 7.0, 2.9, 3.52, 11.9, 14.4, "primary", m=True, note="ram scoop"),
        wdg(5.6, 7.0, 2.9, 3.52, 14.4, 15.6, FALL, "primary", m=True, note="scoop tail"),
        blk(5.75, 6.85, 3.52, 3.6, 12.2, 14.0, "neon", m=True, note="scoop intake"),
    ]
    return p


def e2_vector_slab():
    """Wedge Exotic. A flat two-dimensional vectoring nozzle. A wedge fairing with an intake slot on top,
    then an open slot on the trailing edge between two side plates, split by a vane. The upper ramp is cut back,
    so the jet shows from behind and from above."""
    p = e2_flange(PCX0, PCX1, 0.7, 2.9)
    p += [
        blk(4.8, 7.8, 0.6, 2.2, ZP + 0.4, 15.0, m=True, note="slab body"),
        blk(4.8, 7.8, 2.2, 3.2, ZP + 0.4, 13.0, m=True, note="intake fairing"),
        wdg(4.8, 7.8, 2.2, 3.2, 13.0, 15.0, FALL, m=True, note="sloping fairing"),
        blk(5.2, 7.4, 3.2, 3.26, 12.0, 12.7, "detail", m=True, note="intake mouth on the fairing top"),
        blk(5.2, 7.4, 3.2, 3.34, 12.7, 12.88, "neon", m=True, note="intake lip"),
        wdg(4.8, 7.8, 1.9, 2.2, 15.0, 16.4, FALL, m=True, note="upper ramp, cut back 0.8"),
        wdg(4.8, 7.8, 0.6, 1.1, 15.0, 17.2, UNDER_R, m=True, note="lower ramp"),
        blk(4.98, 7.62, 1.1, 1.9, 14.9, 17.2, "thrust", m=True, note="slot jet, 2.6 by 0.8"),
        blk(4.8, 4.98, 0.6, 2.2, 15.0, 17.35, "detail", m=True, note="inner side plate"),
        blk(7.62, 7.8, 0.6, 2.2, 15.0, 17.35, "detail", m=True, note="outer side plate"),
        blk(6.22, 6.38, 1.1, 2.0, 15.6, 17.3, "detail", m=True, note="centre vane"),
    ]
    return p


def e2_bullet():
    """Roadster. One slim tapered bullet behind each rear-quarter pod, on a chrome shoulder as wide as the collar."""
    x, y = 6.3, 1.9
    p = e2_flange(5.1, 7.5, 0.8, 3.0)
    p += [
        cz(x, y, ZP + 0.4, 13.3, 2.6, "secondary", m=True, note="chrome shoulder: as wide as the pod collar"),
        cz(x, y, 13.3, 14.6, 1.9, "primary", m=True, note="bullet body"),
        cz(x, y, 14.6, 15.8, 1.4, "secondary", m=True, note="taper"),
        cz(x, y, 15.8, 16.5, 1.0, "detail", m=True, note="nozzle"),
        cz(x, y, 16.5, 16.75, 0.75, "thrust", m=True, note="jet"),
        wdg(5.9, 6.7, 2.85, 3.5, 13.3, 14.9, FALL, m=True, note="top scoop"),
        blk(6.0, 6.6, 2.95, 3.4, 13.2, 13.3, "detail", m=True, note="scoop mouth"),
    ]
    return p


def e2_over_under():
    """Turbo Pony. Two cans stacked on the outer half of each pod, intake box inboard."""
    p = e2_flange(PCX0, PCX1, 0.5, 3.2)
    for y, z1 in ((2.5, 16.4), (0.9, 15.0)):
        p += [
            cz(7.0, y, ZP + 0.4, z1, 1.6, "primary", m=True, note="can"),
            cz(7.0, y, z1, z1 + 0.8, 1.3, "detail", m=True, note="nozzle"),
            cz(7.0, y, z1 + 0.8, z1 + 1.05, 0.95, "thrust", m=True, note="jet"),
        ]
    p += [
        blk(4.9, 6.2, 0.8, 2.6, 11.9, 13.6, "secondary", m=True, note="intake box"),
        blk(5.05, 6.05, 2.6, 2.75, 12.1, 13.4, "detail", m=True, note="intake grille"),
    ]
    return p


def e2_trident():
    """Euro GT. Three slim pipes in a triangle behind a short painted cowl: one long on top, two short below."""
    p = e2_flange(PCX0, PCX1, 0.6, 3.2)
    p += [
        blk(4.8, 7.8, 0.5, 3.5, ZP + 0.4, 13.2, m=True, note="cowl"),
    ]
    for x, y, z1 in ((6.3, 2.8, 16.3), (5.55, 1.25, 14.9), (7.05, 1.25, 14.9)):
        p += [
            cz(x, y, 13.2, z1, 1.2, "secondary", m=True, note="pipe"),
            cz(x, y, z1, z1 + 0.7, 1.0, "detail", m=True, note="nozzle"),
            cz(x, y, z1 + 0.7, z1 + 0.95, 0.7, "thrust", m=True, note="jet"),
        ]
    return p


# ----------------------------------------------------------------------------- Stabilisers
# Lift nozzles are canted outboard and back so the glow shows from the side and from above.
# Every unit carries a neon intake on its top or nose.

LIFT = ((0.4, 0.95, "detail", "vectoring lift nozzle"), (0.55, 0.72, "thrust", "lift jet"))
LIFT_S = ((0.4, 0.8, "detail", "vectoring lift nozzle"), (0.5, 0.65, "thrust", "lift jet"))


def st_outrigger_nacelles():
    """Muscle. Two chunky lift nacelles each side, level with the sill and well apart, each on its own painted pylon.
    1.7 wide, 1.8 tall, 2.9 long, joined by a slim contrast boom."""
    p = stab_mount()
    p.append(blk(7.1, 7.6, 1.0, 1.35, 0.3, 2.9, "secondary", m=True, note="slim boom between the nacelles"))
    for z0, z1 in ((-2.6, 0.3), (2.9, 5.8)):
        zc = (z0 + z1) / 2 + 0.3
        p += [
            blk(1.9, 7.2, -0.8, 0.0, zc - 0.6, zc + 0.6, "primary", m=True, note="painted pylon, 0.8 thick, under the rocker"),
            blk(6.5, 8.2, 0.0, 1.8, z0 + 0.9, z1, "primary", m=True, note="lift nacelle, level with the sill"),
            wdg(6.5, 8.2, 0.0, 1.8, z0, z0 + 0.9, RISE, "primary", m=True, note="nacelle nose"),
            blk(6.8, 7.9, 1.8, 1.88, z0 + 1.1, z0 + 2.3, "neon", m=True, note="top intake"),
        ]
        p += cant_jet(8.0, 0.3, z1 - 0.8, 45, 20, LIFT)
    return p


def st_strake_rails():
    """Pro Street. One long rail each side with three vectoring nozzles along its flank. It starts behind the exhaust lane."""
    p = stab_mount()
    p += [
        blk(1.9, 6.9, -0.65, -0.25, -1.2, -0.4, "detail", m=True, note="outrigger beam"),
        blk(1.9, 6.9, -0.65, -0.25, 3.6, 4.4, "detail", m=True, note="outrigger beam"),
        cz(7.3, 0.45, -1.9, 5.6, 1.5, "primary", m=True, note="strake rail"),
        ball(7.3, 0.45, -1.9, 1.5, "secondary", m=True, note="nose cap"),
        ball(7.3, 0.45, 5.6, 1.5, "secondary", m=True, note="tail cap"),
        blk(7.0, 7.6, 1.17, 1.26, -0.6, 4.2, "neon", m=True, note="top intake slot"),
    ]
    for z in (-0.9, 2.0, 4.9):
        p += cant_jet(7.8, 0.15, z, 60, 0, LIFT)
    return p


def st_canard_vanes():
    """Wedge Exotic. Swept vanes ahead of the doors with a tip pod behind the exhaust lane, a winglet and vectoring flank jets."""
    p = stab_mount()
    p += [
        wdg(1.9, 8.2, -0.65, -0.35, -5.3, -0.8, PLAN_IN_BACK, m=True, note="swept front vane"),
        cz(7.6, 0.05, -2.2, 1.8, 1.4, "primary", m=True, note="tip pod, 1.4 by 4.0"),
        ball(7.6, 0.05, -2.25, 0.9, "neon", m=True, note="pod intake"),
        cz(7.6, 0.05, 1.8, 2.1, 1.0, "thrust", m=True, note="tip jet"),
        wdg(7.45, 7.7, 0.7, 2.4, -1.6, 1.2, RISE, m=True, note="winglet"),
        wdg(1.9, 7.4, -0.65, -0.35, 3.4, 6.3, PLAN_IN_FRONT, m=True, note="swept rear vane"),
    ]
    p += cant_jet(7.95, -0.05, -0.6, 60, 20, LIFT)
    p += cant_jet(7.0, -0.45, 3.9, 60, 20, LIFT)
    return p


def st_float_pods():
    """Roadster. One short round float pod each side on a single arm, plus a keel fin."""
    p = stab_mount()
    p += [
        blk(1.9, 6.8, -0.6, -0.25, 0.1, 0.9, "detail", m=True, note="single arm"),
        cz(7.35, 0.55, -1.6, 2.6, 1.8, "primary", m=True, note="float pod"),
        ball(7.35, 0.55, -1.6, 1.8, "primary", m=True, note="pod nose"),
        ball(7.35, 0.55, -2.25, 0.8, "neon", m=True, note="pod intake"),
        ball(7.35, 0.55, 2.6, 1.8, "secondary", m=True, note="pod tail"),
        blk(7.05, 7.65, 1.42, 1.5, -0.8, 1.6, "neon", m=True, note="top intake"),
        blk(-0.3, 0.3, -1.4, -0.35, -3.4, 4.4, "primary", note="keel fin"),
        blk(-0.2, 0.2, -1.55, -1.4, -2.6, 3.6, "thrust", note="keel jet strip"),
    ]
    for z in (-0.6, 1.6):
        p += cant_jet(7.8, 0.25, z, 55, 15, LIFT)
    return p


def st_fin_stacks():
    """Turbo Pony. A tall fin each side at the rear of the doors, a jet pod at its foot with two vectoring nozzles."""
    p = stab_mount()
    p += [
        blk(1.9, 7.2, -0.7, -0.3, 3.4, 4.2, "detail", m=True, note="outrigger beam"),
        blk(7.5, 7.9, -0.3, 3.4, 2.4, 6.2, "primary", m=True, note="fin"),
        wdg(7.5, 7.9, 0.4, 3.4, -0.2, 2.4, RISE, m=True, note="fin leading edge"),
        blk(7.9, 7.96, 2.9, 3.15, 2.4, 6.2, "neon", m=True, note="fin light"),
        cz(7.7, -0.95, 0.2, 6.0, 1.3, "detail", m=True, note="jet pod"),
        cz(7.7, -0.95, 6.0, 6.25, 0.9, "thrust", m=True, note="jet"),
        ball(7.7, -0.95, 0.2, 1.3, "secondary", m=True, note="pod nose"),
        ball(7.7, -0.95, -0.3, 0.6, "neon", m=True, note="pod intake"),
    ]
    for z in (1.4, 4.6):
        p += cant_jet(7.95, -0.8, z, 60, 0, LIFT_S)
    return p


def st_gull_pods():
    """Euro GT. A slim pod held high at the beltline on a gull arm each side, two vectoring nozzles under its flank."""
    p = stab_mount()
    p += [
        blk(1.9, 7.0, -0.6, -0.25, 0.1, 0.9, "detail", m=True, note="single arm"),
        blk(6.6, 7.1, -0.25, 2.3, 0.2, 0.8, "detail", m=True, note="gull upright"),
        cz(7.5, 2.6, -1.7, 2.7, 1.5, "primary", m=True, note="shoulder pod, behind the exhaust lane"),
        ball(7.5, 2.6, -1.7, 1.5, "primary", m=True, note="pod nose"),
        ball(7.5, 2.6, -2.25, 0.7, "neon", m=True, note="pod intake"),
        ball(7.5, 2.6, 2.7, 1.5, "secondary", m=True, note="pod tail"),
        blk(7.2, 7.8, 3.32, 3.4, -0.7, 1.7, "neon", m=True, note="top intake"),
    ]
    for z in (-0.5, 1.7):
        p += cant_jet(7.85, 2.3, z, 55, 15, LIFT)
    return p


# ----------------------------------------------------------------------------- Boost (Afterburner)


def bo_quad_cannon():
    """Muscle. A two-by-two block of fat nozzles in a contrast shroud, raised above the tail deck."""
    p = [blk(-2.2, 2.2, 1.3, 2.9, ZT + 0.05, ZT + 0.4, "detail", note="flange on the tail panel"),
         blk(-1.75, 1.75, 1.9, 4.55, ZT + 0.4, 16.3, "secondary", note="shroud"),
         blk(-1.3, 1.3, 4.55, 4.6, 14.7, 16.0, "detail", note="top intake grille")]
    for y in (2.6, 3.85):
        p += [
            cz(0.85, y, 16.3, 17.1, 1.3, "detail", m=True, note="nozzle"),
            cz(0.85, y, 17.1, 17.35, 0.95, "thrust", m=True, note="jet"),
        ]
    return p


def bo_big_bell():
    """Pro Street. One bell nozzle on a long throat on the centre line."""
    y = 2.65
    return [
        blk(-2.0, 2.0, 1.2, 3.0, ZT + 0.05, ZT + 0.3, "detail", note="flange on the tail panel"),
        cz(0, y, ZT + 0.3, 16.8, 1.8, "secondary", note="throat, 2.5 long"),
        cz(0, y, 16.2, 17.25, 2.2, "detail", note="bell"),
        cz(0, y, 17.25, 17.45, 1.5, "thrust", note="jet"),
        blk(-0.2, 0.2, 3.55, 4.5, 14.5, 16.2, "secondary", note="top fin"),
    ]


def bo_slot_burner():
    """Wedge Exotic. One thin full-width slot."""
    p = [
        blk(-2.0, 2.0, 1.2, 3.0, ZT + 0.05, ZT + 0.3, "detail", note="flange on the tail panel"),
        blk(-3.8, 3.8, 2.0, 3.2, ZT + 0.3, 15.2, note="burner housing"),
        wdg(-3.8, 3.8, 2.9, 3.2, 15.2, 16.0, FALL, note="upper lip"),
        wdg(-3.8, 3.8, 2.0, 2.3, 15.2, 16.0, UNDER_R, note="lower lip"),
        blk(-3.6, 3.6, 2.3, 2.9, 15.2, 15.7, "thrust", note="slot jet"),
    ]
    for x in (-1.8, 0.0, 1.8):
        p.append(blk(x - 0.1, x + 0.1, 2.1, 3.1, 15.0, 15.9, "detail", note="vane"))
    return p


def bo_megaphones():
    """Roadster. Two close-set megaphones that sweep steeply up and flare toward the rear."""
    p = [blk(-2.0, 2.0, 1.2, 2.4, ZT + 0.05, ZT + 0.35, "detail", note="flange on the tail panel")]
    p += sweep(1.3, 1.9, ZT + 0.35, 24.0, ((1.1, 1.0, "secondary", "megaphone, first stage"),
                                           (1.0, 1.4, "secondary", "megaphone, second stage"),
                                           (0.75, 1.7, "secondary", "megaphone mouth"), (0.15, 1.25, "thrust", "jet")))
    return p


def bo_tri_stack():
    """Turbo Pony. Three cans stacked on the centre line between two fences."""
    p = [
        blk(-0.8, 0.8, 1.0, 4.4, ZT + 0.05, ZT + 0.5, "detail", note="spine on the tail panel"),
        blk(0.6, 0.8, 0.9, 4.5, ZT + 0.5, 16.2, "secondary", m=True, note="fence"),
    ]
    for y in (1.5, 2.7, 3.9):
        p += [
            cz(0, y, ZT + 0.5, 16.6, 1.1, "primary", note="can"),
            cz(0, y, 16.6, 17.1, 0.9, "detail", note="nozzle"),
            cz(0, y, 17.1, 17.3, 0.65, "thrust", note="jet"),
        ]
    return p


def bo_wide_pair():
    """Euro GT. Two flat letterbox tailpipes set wide apart in painted tail pods, joined by a slim bridge.
    Flat outlets, so the boost never reads as two more of the round rear-engine pipes beside it."""
    p = [
        blk(-3.4, 3.4, 1.0, 2.2, ZT + 0.05, ZT + 0.4, "detail", note="flange on the tail panel"),
        blk(-2.0, 2.0, 1.25, 1.95, ZT + 0.4, 15.4, note="bridge"),
        blk(-0.6, 0.6, 1.4, 1.8, 15.4, 15.5, "neon", note="reversing lamp"),
        blk(2.0, 3.8, 1.0, 2.3, ZT + 0.4, 16.0, m=True, note="tail pod"),
        wdg(2.0, 3.8, 2.3, 2.9, ZT + 0.4, 16.0, FALL, m=True, note="pod fairing"),
        blk(2.15, 3.65, 1.1, 2.2, 16.0, 17.0, "detail", m=True, note="letterbox tailpipe"),
        blk(2.35, 3.45, 1.3, 2.0, 17.0, 17.3, "thrust", m=True, note="flat jet"),
    ]
    return p


# ----------------------------------------------------------------------------- RearBody (Rear Clip)


def rb_fastback_quarters():
    """Muscle. Rear-quarter pods with a tall sail panel that falls to the tail, a full-height square tail and a lamp bar."""
    p = rb_pads(tail_x=2.6, pod_x=4.9, strut_z=(8.6, 10.3)) + rb_taper(2.6)
    p += [
        blk(-2.2, 2.2, 0.2, 0.5, 7.0, 13.6, "detail", note="under-tray"),
        blk(-2.6, 2.6, 0.5, DECK, Z_RC, ZT - G, note="centre tail"),
        blk(0.35, 1.35, DECK, DECK + 0.06, ZR + G, 11.0, "secondary", m=True, note="deck stripe"),
        blk(-2.4, 2.4, 3.2, DECK, ZT - G, ZT, "neon", note="tail lamp bar"),
        blk(PCX0, 7.8, 0.6, PCY1, 7.8, PCZ, m=True, note="quarter pod, on the collar section"),
        blk(PCX0, 7.8, PCY1, 4.5, 7.8, 8.8, m=True, note="sail panel shoulder"),
        wdg(PCX0, 7.8, PCY1, 4.5, 8.8, ZP - G, FALL, m=True, note="sail panel"),
        blk(7.8, 7.86, STRIPE - 0.15, STRIPE + 0.15, 7.8, PCZ, "secondary", m=True, note="belt stripe"),
    ]
    p += slats(5.4, 7.4, 4.5, 8.8, PCY1, ZP - G, 2, depth=0.6, m=True)
    return p


def rb_tubbed():
    """Pro Street. A narrowed painted boot, then bare rails, a fuel cell and the spoiler pad on a hoop.
    Deep tubs with a chamfered shoulder and a blanked arch vent, tapered on all four sides into the pod collar."""
    p = rb_pads(tail_x=2.2, pod_x=4.9, strut_y=0.95, collar_z=9.0) + rb_taper(2.2)
    p += [
        blk(-2.2, 2.2, 0.6, DECK, Z_RC, 10.6, note="narrowed boot"),
        blk(-1.2, 1.2, DECK, DECK + 0.06, ZR + G, 10.4, "secondary", note="boot panel"),
        blk(1.5, 2.1, 0.6, 1.2, 10.6, ZT - G, "detail", m=True, note="bare frame rail"),
        blk(-1.5, 1.5, 0.6, 0.9, 10.8, 13.5, "detail", note="cell tray"),
        blk(-1.3, 1.3, 0.9, 2.6, 11.0, 13.3, "secondary", note="fuel cell"),
        blk(1.6, 1.9, 1.2, DECK, 11.9, 12.6, "detail", m=True, note="hoop post"),
        blk(-2.4, 2.4, 3.2, DECK, ZT - G, ZT, "neon", note="tail lamp bar"),
        blk(PCX0, 8.3, -0.2, 2.6, ZR + G, 9.0, m=True, note="deep tub"),
        blk(PCX0, 7.4, 2.6, PCY1, ZR + G, 9.0, m=True, note="tub top"),
        wdg(7.4, 8.3, 2.6, PCY1, ZR + G, 9.0, OUTB, m=True, note="chamfered outer shoulder"),
        wdg(PCX1, 8.3, -0.2, 2.6, 9.0, PCZ, PLAN_IN_FRONT, m=True, note="outer taper to the collar"),
        wdg(PCX0, PCX1, -0.2, PCY0, 9.0, PCZ, UNDER_R, m=True, note="floor taper up to the collar"),
        blk(8.3, 8.36, 0.0, 1.5, 7.2, 8.8, "detail", m=True, note="blanked arch vent"),
    ]
    return p


def rb_kamm_tail():
    """Wedge Exotic. A low full-width deck with a louvred spine, rising to a chopped, undercut tail. Blade fins outboard that rise to the rear."""
    p = rb_pads(tail_x=3.4, pod_x=4.9, strut_y=1.1, strut_z=(9.0, 10.6))
    p += [
        blk(-SX, SX, 0.5, 2.2, Z_RC, 10.5, note="low deck"),
        blk(-1.2, 1.2, 2.2, DECK, Z_RC, 10.5, note="louvred spine"),
        wdg(1.2, SX, 2.2, DECK, Z_RC, 9.6, PLAN_IN_FRONT, m=True, note="collar taper to the spine"),
        blk(-SX, SX, 1.3, DECK, 10.5, ZT - G, note="kamm block, undercut"),
        blk(2.4, 3.4, 2.2, 3.0, ZT - G, ZT - 0.1, "neon", m=True, note="tail lamp"),
        wdg(7.0, 8.5, 0.8, 4.4, 8.4, ZP - G, RISE, m=True, note="blade fin"),
        blk(PCX0, 7.0, PCY0, 1.6, 8.4, PCZ, m=True, note="low pod shelf"),
        wdg(PCX0, 7.0, 1.6, PCY1, 8.4, PCZ, RISE, m=True, note="shelf ramp up to the collar"),
        blk(8.5, 8.55, 1.0, 1.3, 9.6, ZP - G, "secondary", m=True, note="low stripe"),
    ]
    for z in (7.9, 8.7, 9.5):
        p.append(blk(-1.0, 1.0, DECK, DECK + 0.1, z, z + 0.45, "detail", note="spine louvre"))
    return p


def rb_boat_tail():
    """Roadster. The boat tail: 4.4 wide at the root, tapering in plan to a slim stern. Round pontoon pods with bullet noses."""
    p = rb_pads(tail_x=2.2, pod_x=5.1, strut_y=1.5, strut_z=(8.8, 9.9)) + rb_taper(2.2)
    p += [
        blk(-2.2, 2.2, 0.5, DECK, Z_RC, 10.0, note="tail root"),
        blk(-1.0, 1.0, 0.5, 3.0, 10.0, ZT - G, note="boat tail spine"),
        wdg(1.0, 2.2, 0.5, 3.0, 10.0, ZT - G, PLAN_IN_FRONT, m=True, note="boat tail taper"),
        blk(-0.4, 0.4, DECK, DECK + 0.06, ZR + G, 10.0, "secondary", note="centre stripe"),
        blk(-0.4, 0.4, 3.0, 3.06, 10.0, 11.0, "secondary", note="centre stripe, tail"),
        blk(0.5, 0.8, 3.0, DECK, 11.2, 11.6, "detail", m=True, note="pad post, front"),
        blk(0.5, 0.8, 3.0, DECK, 12.8, 13.2, "detail", m=True, note="pad post, rear"),
        cz(1.7, 3.3, ZT - 0.5, ZT, 0.5, "neon", m=True, note="bullet tail lamp"),
        cz(6.3, 1.9, 8.2, PCZ, 2.7, m=True, note="round pontoon pod"),
        ball(6.3, 1.9, 8.2, 2.7, m=True, note="pod nose"),
        blk(6.1, 6.5, 3.2, 3.38, 8.4, ZP - G, "secondary", m=True, note="chrome spine"),
    ]
    return p


def rb_slab_hatch():
    """Turbo Pony. A low full-width slab at the beltline with a deep valance, louvres and a raised plinth. Long low shelf pods."""
    p = rb_pads(tail_x=3.9, pod_x=4.4, strut_y=1.0)
    p += [
        blk(-3.9, 3.9, 0.0, BELT, Z_RC, ZT - G, note="slab tail with deep valance"),
        wdg(-SX, SX, BELT, DECK, Z_RC, 9.2, FALL, note="hatch slope down from the collar"),
        blk(-2.0, 2.0, BELT, DECK, 11.4, 13.4, "detail", note="spoiler plinth"),
        blk(-2.4, 2.4, 3.2, DECK, ZT - G, ZT, "neon", note="tail lamp bar"),
        blk(2.4, 3.9, 1.9, BELT, ZT - G, ZT, "neon", m=True, note="lamp end"),
        blk(4.4, 8.4, 0.0, 1.5, 6.8, ZP - G, m=True, note="long low shelf pod"),
        wdg(PCX0, PCX1, 1.5, PCY1, 8.0, PCZ, RISE, m=True, note="fairing ramp up to the collar"),
        blk(8.4, 8.46, 1.0, 1.25, 6.8, ZP - G, "neon", m=True, note="shelf light"),
    ]
    for i in range(2):
        p.append(blk(-3.2, 3.2, BELT, BELT + 0.12, 9.5 + i * 0.8, 10.0 + i * 0.8, "detail", note="deck louvre"))
    return p


def rb_grand_tail():
    """Euro GT. A long flat boot that tapers in plan to a rounded stern. Hip pods that rise toward the rear."""
    p = rb_pads(tail_x=2.9, pod_x=4.6, strut_z=(8.4, 10.4)) + rb_taper(2.9, z1=9.0)
    p += [
        blk(-2.9, 2.9, 0.5, DECK, Z_RC, 11.5, note="boot"),
        blk(-1.8, 1.8, 0.5, DECK, 11.5, ZT - G, note="stern"),
        wdg(1.8, 2.9, 0.5, DECK, 11.5, ZT - G, PLAN_IN_FRONT, m=True, note="stern taper"),
        blk(-0.25, 0.25, DECK, DECK + 0.06, ZR + G, 11.0, "secondary", note="boot centre line"),
        blk(0.6, 2.2, 3.2, DECK, ZT - G, ZT, "neon", m=True, note="tail lamp"),
        blk(4.6, 7.9, PCY0, 2.4, 7.0, ZP - G, m=True, note="hip pod"),
        wdg(4.6, 7.9, 2.4, 3.5, 7.0, 9.8, RISE, m=True, note="hip rise"),
        blk(4.6, 7.9, 2.4, 3.5, 9.8, ZP - G, m=True, note="hip top"),
        blk(7.9, 7.96, 1.75, 2.05, 7.0, ZP - G, "secondary", m=True, note="chrome side strip"),
    ]
    return p


# ----------------------------------------------------------------------------- SidePods (Rockers)
# Inner faces sit at X 4.0, so the gap to the shared tub (X 3.4) is the house 0.6 for every cabin.


def sp_door_pods():
    """Muscle. Low wide pontoons under the doors with a chrome side pipe."""
    p = sp_brackets()
    p += [
        blk(4.0, 5.3, 0.3, 1.6, -5.2, -1.5, m=True, note="pontoon nose, inboard of the exhaust lane"),
        wdg(5.3, 5.9, 0.3, 1.6, LANE_Z, -1.5, PLAN_IN_BACK, m=True, note="pontoon flare"),
        blk(4.0, 5.9, 0.3, 1.6, -1.5, 6.2, m=True, note="pontoon"),
        cz(5.9, 0.7, -1.3, 5.2, 0.7, "secondary", m=True, note="side pipe"),
        cz(5.9, 0.7, 5.2, 6.0, 0.8, "detail", m=True, note="pipe tip"),
    ]
    return p


def sp_fuel_tanks():
    """Pro Street. A short fat round tank each side on a cradle."""
    p = sp_brackets()
    p += [
        cz(5.1, 1.4, -1.6, 4.4, 2.1, "secondary", m=True, note="tank, behind the exhaust lane"),
        ball(5.1, 1.4, -1.6, 2.1, "secondary", m=True, note="tank nose"),
        ball(5.1, 1.4, 4.4, 2.1, "secondary", m=True, note="tank tail"),
        blk(4.4, 5.8, 0.15, 0.45, -1.4, 4.2, "detail", m=True, note="cradle"),
        cyv(5.1, 2.4, 2.58, 1.4, 0.6, "detail", m=True, note="filler cap"),
    ]
    return p


def sp_intake_scoops():
    """Wedge Exotic. A slim blade that ramps up and flares out to a side intake at the rear."""
    p = sp_brackets()
    p += [
        wdg(4.0, 4.8, 0.5, 2.5, -5.2, 4.4, RISE, m=True, note="ramp blade"),
        wdg(4.8, 6.3, 0.5, 1.4, -1.0, 4.4, PLAN_IN_BACK, m=True, note="flare"),
        blk(4.0, 6.3, 0.5, 2.5, 4.4, 6.2, m=True, note="intake block"),
        blk(5.0, 6.2, 1.5, 2.4, 4.3, 4.4, "detail", m=True, note="intake mouth"),
        blk(6.3, 6.36, 0.5, 0.75, 4.4, 6.2, "secondary", m=True, note="sill stripe"),
    ]
    return p


def sp_rocker_blades():
    """Roadster. A thin blade along the sill with a slim megaphone pipe."""
    p = sp_brackets()
    p += [
        blk(4.0, 4.6, 0.5, 1.2, -5.2, 6.2, m=True, note="rocker blade"),
        cz(5.1, 0.9, -4.6, 4.4, 0.7, "secondary", m=True, note="slim pipe"),
        cz(5.1, 0.9, 4.4, 5.8, 1.05, "secondary", m=True, note="megaphone"),
        blk(4.6, 5.2, 0.8, 1.0, -3.0, -2.4, "detail", m=True, note="pipe stay"),
        blk(4.6, 5.2, 0.8, 1.0, 2.8, 3.4, "detail", m=True, note="pipe stay"),
    ]
    return p


def sp_strake_box():
    """Turbo Pony. A tall thin fence along the whole door with three strakes."""
    p = sp_brackets()
    p += [
        blk(4.0, 4.8, 0.5, 2.6, -3.6, 6.2, m=True, note="strake fence"),
        wdg(4.0, 4.8, 0.5, 2.6, -5.2, -3.6, RISE, m=True, note="leading ramp"),
        blk(4.8, 4.86, 0.55, 0.75, -3.6, 6.2, "neon", m=True, note="sill light"),
    ]
    for i in range(3):
        p.append(blk(4.8, 5.1, 1.0 + 0.5 * i, 1.2 + 0.5 * i, -2.8, 5.4, "detail", m=True, note="strake"))
    return p


def sp_gill_sills():
    """Euro GT. A tall gilled vent box behind the front fender, then a slim sill with a side pipe."""
    p = sp_brackets()
    p += [
        blk(4.0, 5.4, 0.4, 2.5, -5.2, -1.8, m=True, note="vent box, inboard of the exhaust lane"),
        blk(4.0, 4.9, 0.4, 1.3, -1.8, 6.2, m=True, note="slim sill"),
        cz(5.25, 0.8, -1.8, 5.0, 0.6, "secondary", m=True, note="side pipe"),
        cz(5.25, 0.8, 5.0, 5.9, 0.8, "detail", m=True, note="pipe tip"),
    ]
    for i in range(2):
        p.append(blk(5.4, 5.46, 0.9 + 0.7 * i, 1.3 + 0.7 * i, -4.8, -2.2, "detail", m=True, note="gill"))
    return p


# ----------------------------------------------------------------------------- bumpers


def fbm_chin_bar():
    """Muscle. One chrome bar across both fender tips, with over-riders."""
    p = fbumper_brackets()
    p += [
        blk(-8.2, 8.2, 0.9, 1.4, -17.3, -16.9, "secondary", note="bar"),
        blk(-1.0, 1.0, 0.95, 1.35, -16.9, -16.55, "detail", note="centre bracket to the nose pad"),
        blk(5.0, 5.4, 0.9, 2.0, -17.45, -17.3, "detail", m=True, note="over-rider"),
        blk(7.0, 7.4, 0.9, 2.0, -17.45, -17.3, "detail", m=True, note="over-rider"),
    ]
    return p


def fbm_push_bars():
    """Pro Street. A low braced push-bar frame held ahead of each fender tip. A raked stay plate runs from the top bar
    back down to the hardpoint, so the frame is tied to any nose, pointed or blunt. Nothing across the middle."""
    p = fbumper_brackets()
    p += [
        blk(5.5, 6.9, 1.0, 1.4, -17.3, -16.9, "detail", m=True, note="standoff and low cross-member"),
        blk(5.2, 5.5, 0.9, 2.4, -17.55, -17.25, "detail", m=True, note="upright"),
        blk(6.9, 7.2, 0.9, 2.4, -17.55, -17.25, "detail", m=True, note="upright"),
        blk(5.2, 7.2, 2.15, 2.4, -17.6, -17.2, "secondary", m=True, note="top bar"),
    ]
    ya, za, yb, zb = 2.2, -17.25, 1.4, -16.72
    ang = math.degrees(math.atan2(ya - yb, zb - za))
    p.append(slab([0.9, 0.2, math.hypot(ya - yb, zb - za)], [6.2, (ya + yb) / 2, (za + zb) / 2], [ang, 0, 0],
                  "secondary", m=True, note="raked stay plate from the top bar to the hardpoint"))
    return p


def fbm_wedge_lip():
    """Wedge Exotic. A painted wedge lip on each prong tip and a deep centre chin, joined by a slim tie blade. No end plates."""
    p = fbumper_brackets()
    p += [
        wdg(4.6, 8.0, 0.82, 1.7, -17.8, -16.55, RISE, m=True, note="wedge lip on the fender tip"),
        blk(-4.6, 4.6, 0.82, 1.0, -16.95, -16.6, "detail", note="tie blade"),
        wdg(-3.8, 3.8, -0.4, 0.78, -17.9, -16.6, UNDER_F, note="centre chin"),
    ]
    return p


def fbm_chrome_blades():
    """Roadster. A separate chrome blade on each fender tip with an upright over-rider."""
    p = fbumper_brackets()
    p += [
        blk(4.8, 7.6, 1.1, 1.5, -17.2, -16.9, "secondary", m=True, note="blade"),
        cyv(5.4, 0.9, 2.2, -17.35, 0.4, "secondary", m=True, note="over-rider"),
        cyv(7.0, 0.9, 2.2, -17.35, 0.4, "secondary", m=True, note="over-rider"),
    ]
    return p


def fbm_air_dam():
    """Turbo Pony. A deep centre air dam under a full-width light bar. The dam is a solid box that runs back
    to the bumper plane, so it closes onto any centre nose."""
    p = fbumper_brackets()
    p += [
        blk(-8.3, 8.3, 0.9, 1.5, -17.1, -16.9, "detail", note="light bar housing"),
        blk(-8.1, 8.1, 1.1, 1.3, -17.2, -17.1, "neon", note="light bar"),
        blk(-3.8, 3.8, -0.9, 0.78, -17.8, -16.55, note="air dam box, back to the bumper plane"),
        blk(-3.2, 3.2, -0.4, 0.3, -17.9, -17.8, "detail", note="dam slot"),
    ]
    return p


def fbm_quarter_bumpers():
    """Euro GT. A chrome quarter bumper wrapped round each outer corner and a rally lamp inboard. Nothing across the middle."""
    p = fbumper_brackets()
    p += [
        blk(6.6, 8.4, 1.0, 1.6, -17.2, -16.9, "secondary", m=True, note="quarter bumper"),
        blk(4.9, 5.6, 1.1, 1.4, -17.0, -16.7, "detail", m=True, note="lamp stay"),
        cz(4.9, 1.9, -17.4, -16.8, 1.2, "detail", m=True, note="rally lamp shell"),
        cz(4.9, 1.9, -17.5, -17.4, 0.95, "neon", m=True, note="rally lamp"),
    ]
    return p


def rbm_chrome_bar():
    """Muscle. Plain polished bar under the afterburner."""
    p = rbumper_brackets()
    p += [
        blk(-3.8, 3.8, 0.05, 0.6, 14.5, 15.0, "secondary", note="bar"),
        blk(2.6, 3.0, -0.2, 0.75, 15.0, 15.15, "detail", m=True, note="over-rider"),
    ]
    return p


def rbm_drag_skids():
    """Pro Street. Two long skid bars with a skid plate at the far end."""
    p = rbumper_brackets()
    p += [
        blk(1.3, 1.7, -0.2, 0.3, 14.5, 16.8, "detail", m=True, note="skid bar"),
        blk(-2.0, 2.0, -0.55, -0.2, 16.1, 16.9, "secondary", note="skid plate"),
        cxx(-1.7, 1.7, 0.05, 15.4, 0.3, "detail", note="brace"),
    ]
    return p


def rbm_diffuser():
    """Wedge Exotic. Black finned undertray."""
    p = rbumper_brackets()
    p += [wdg(-3.8, 3.8, -0.9, 0.3, 14.5, 16.8, UNDER_R, "detail", note="diffuser tray")]
    for x in (-2.7, -0.9, 0.9, 2.7):
        p.append(blk(x - 0.1, x + 0.1, -0.9, 0.0, 14.5, 16.6, "primary", note="fin"))
    return p


def rbm_nerf_pair():
    """Roadster. Two short separate chrome bumperettes."""
    p = rbumper_brackets()
    p += [
        blk(1.9, 3.5, 0.0, 0.7, 14.5, 14.9, "secondary", m=True, note="bumperette"),
        cyv(2.7, -0.4, 0.75, 15.05, 0.35, "secondary", m=True, note="over-rider"),
    ]
    return p


def rbm_light_strip():
    """Turbo Pony. A deep valance with a full-width light strip."""
    p = rbumper_brackets()
    p += [
        blk(-3.9, 3.9, -0.8, 0.75, 14.5, 15.0, note="valance"),
        blk(-3.6, 3.6, 0.2, 0.55, 15.0, 15.1, "neon", note="light strip"),
        blk(-2.4, 2.4, -0.6, -0.1, 15.0, 15.1, "detail", note="valance slot"),
    ]
    return p


def rbm_keel():
    """Euro GT. A slim chrome cross bar and a long centre keel fin with a fog lamp."""
    p = rbumper_brackets()
    p += [
        blk(-2.0, 2.0, 0.25, 0.65, 14.5, 14.85, "secondary", note="cross bar"),
        blk(-0.25, 0.25, -1.1, 0.7, 14.85, 16.8, note="keel fin"),
        blk(-0.3, 0.3, -0.3, 0.3, 16.8, 16.9, "neon", note="fog lamp"),
    ]
    return p


# ----------------------------------------------------------------------------- spoilers
Y_SP = BODY_TOP + 0.05   # underside of every spoiler: just clear of the spoiler pad


def rs_ducktail():
    """Muscle. Small upturned lip."""
    return [
        blk(-2.6, 2.6, Y_SP, 3.8, 10.6, 13.9, note="base"),
        wdg(-2.9, 2.9, 3.8, 4.5, 11.4, 13.95, RISE, note="lip"),
        blk(-2.9, 2.9, 4.5, 4.56, 13.5, 13.95, "secondary", note="lip edge"),
    ]


def rs_pedestal_wing():
    """Pro Street. A tall wing on two uprights."""
    return [
        blk(1.4, 1.75, Y_SP, 6.4, 11.4, 12.8, "detail", m=True, note="upright"),
        blk(-4.6, 4.6, 6.4, 6.7, 11.0, 13.4, note="blade"),
        blk(4.6, 4.8, 6.0, 7.1, 10.8, 13.6, "secondary", m=True, note="end plate"),
    ]


def rs_delta_wing():
    """Wedge Exotic. A deck-width delta blade on two uprights, swept back from a point, with small tip fins."""
    return [
        blk(1.4, 1.8, Y_SP, 4.7, 11.8, 13.2, "detail", m=True, note="upright"),
        wdg(0.0, 3.9, 4.7, 4.95, 9.6, 13.6, PLAN_IN_BACK, m=True, note="delta blade"),
        blk(-3.9, 3.9, 4.7, 4.95, 13.6, 14.6, note="trailing edge"),
        blk(3.7, 3.9, 4.95, 5.6, 12.6, 14.6, m=True, note="tip fin"),
        blk(-3.9, 3.9, 4.95, 5.01, 14.3, 14.6, "secondary", note="trailing stripe"),
    ]


def rs_twin_fins():
    """Roadster. Two small fins."""
    return [
        blk(-2.0, 2.0, Y_SP, 3.75, 10.6, 13.5, "detail", note="fin plinth"),
        blk(1.5, 1.8, 3.75, 4.3, 10.8, 13.8, m=True, note="fin root"),
        wdg(1.5, 1.8, 4.3, 5.4, 10.8, 13.8, RISE, m=True, note="fin"),
    ]


def rs_biplane():
    """Turbo Pony. Two stacked blades between end plates."""
    return [
        blk(1.6, 2.0, Y_SP, 4.2, 11.4, 13.0, "detail", m=True, note="foot"),
        blk(-3.3, 3.3, 4.2, 4.42, 11.2, 13.7, note="lower blade"),
        blk(-3.3, 3.3, 5.3, 5.5, 10.8, 13.0, "secondary", note="upper blade"),
        blk(3.3, 3.55, 4.0, 5.7, 10.6, 13.9, m=True, note="end plate"),
    ]


def rs_dorsal_fin():
    """Euro GT. One long tall dorsal fin on the centre line."""
    return [
        blk(-1.2, 1.2, Y_SP, 3.8, 11.0, 13.5, "detail", note="fin plinth"),
        wdg(-0.2, 0.2, 3.8, 6.2, 7.2, 12.6, RISE, note="dorsal fin"),
        blk(-0.2, 0.2, 3.8, 6.2, 12.6, 13.9, note="fin tail"),
        blk(-0.26, 0.26, 5.6, 5.9, 12.6, 13.9, "secondary", note="fin flash"),
    ]


# ----------------------------------------------------------------------------- assemble

COCKPITS = {
    "brawler": {"name": "Brawler", "culture": "Muscle", "kit": "muscle", "parts": cockpit_brawler()},
    "outlaw": {"name": "Outlaw", "culture": "Pro Street", "kit": "prostreet", "parts": cockpit_outlaw()},
    "stiletto": {"name": "Stiletto", "culture": "Wedge Exotic", "kit": "wedge", "parts": cockpit_stiletto()},
    "regent": {"name": "Regent", "culture": "Euro GT", "kit": "eurogt", "parts": cockpit_regent()},
    "mamba": {"name": "Mamba", "culture": "Roadster", "kit": "roadster", "parts": cockpit_mamba()},
    "nightshift": {"name": "Nightshift", "culture": "Turbo Pony", "kit": "turbo", "parts": cockpit_nightshift()},
}


def mod(name, culture, parts):
    return {"name": name, "culture": culture, "parts": parts}


M, PS, WE, GT, RO, TP = "Muscle", "Pro Street", "Wedge Exotic", "Euro GT", "Roadster", "Turbo Pony"
MODULES = {
    "Engine1": {
        "ram": mod("Ram Turbine", M, e1_ram()),
        "zoomie_rails": mod("Zoomie Rails", PS, e1_zoomie_rails()),
        "slot_ram": mod("Slot Ramjet", WE, e1_slot_ram()),
        "straight_six": mod("Straight Six", GT, e1_straight_six()),
        "quad_cluster": mod("Quad Cluster", RO, e1_quad_cluster()),
        "cassette": mod("Turbo Cassette", TP, e1_cassette()),
    },
    "Engine2": {
        "thunder_twins": mod("Thunder Twins", M, e2_thunder_twins()),
        "big_bertha": mod("Big Bertha", PS, e2_big_bertha()),
        "vector_slab": mod("Vector Slab", WE, e2_vector_slab()),
        "trident": mod("Trident", GT, e2_trident()),
        "bullet": mod("Bullet", RO, e2_bullet()),
        "over_under": mod("Over-Under", TP, e2_over_under()),
    },
    "Stabilisers": {
        "outrigger_nacelles": mod("Outrigger Nacelles", M, st_outrigger_nacelles()),
        "strake_rails": mod("Strake Rails", PS, st_strake_rails()),
        "canard_vanes": mod("Canard Vanes", WE, st_canard_vanes()),
        "gull_pods": mod("Gull Pods", GT, st_gull_pods()),
        "float_pods": mod("Float Pods", RO, st_float_pods()),
        "fin_stacks": mod("Fin Stacks", TP, st_fin_stacks()),
    },
    "Boost": {
        "quad_cannon": mod("Quad Cannon", M, bo_quad_cannon()),
        "big_bell": mod("Big Bell", PS, bo_big_bell()),
        "slot_burner": mod("Slot Burner", WE, bo_slot_burner()),
        "wide_pair": mod("Wide Pair", GT, bo_wide_pair()),
        "megaphones": mod("Megaphones", RO, bo_megaphones()),
        "tri_stack": mod("Tri-Stack", TP, bo_tri_stack()),
    },
    "FrontBody": {
        "longhorn": mod("Twin Longhorn", M, fb_longhorn()),
        "blower_rail": mod("Blower Rail", PS, fb_blower_rail()),
        "popup_prongs": mod("Pop-Up Prongs", WE, fb_popup_prongs()),
        "long_nose": mod("Long Nose", GT, fb_long_nose()),
        "grand_quad": mod("Grand Quad", RO, fb_grand_quad()),
        "flip_nose": mod("Flip Nose", TP, fb_flip_nose()),
    },
    "RearBody": {
        "fastback_quarters": mod("Fastback Quarters", M, rb_fastback_quarters()),
        "tubbed": mod("Tubbed", PS, rb_tubbed()),
        "kamm_tail": mod("Kamm Tail", WE, rb_kamm_tail()),
        "grand_tail": mod("Grand Tail", GT, rb_grand_tail()),
        "boat_tail": mod("Boat Tail", RO, rb_boat_tail()),
        "slab_hatch": mod("Slab Hatch", TP, rb_slab_hatch()),
    },
    "SidePods": {
        "door_pods": mod("Door Pods", M, sp_door_pods()),
        "fuel_tanks": mod("Fuel Tanks", PS, sp_fuel_tanks()),
        "intake_scoops": mod("Intake Scoops", WE, sp_intake_scoops()),
        "gill_sills": mod("Gill Sills", GT, sp_gill_sills()),
        "rocker_blades": mod("Rocker Blades", RO, sp_rocker_blades()),
        "strake_box": mod("Strake Box", TP, sp_strake_box()),
    },
    "FrontBumper": {
        "chin_bar": mod("Chin Bar", M, fbm_chin_bar()),
        "push_bars": mod("Push Bars", PS, fbm_push_bars()),
        "wedge_lip": mod("Wedge Lip", WE, fbm_wedge_lip()),
        "quarter_bumpers": mod("Quarter Bumpers", GT, fbm_quarter_bumpers()),
        "chrome_blades": mod("Chrome Blades", RO, fbm_chrome_blades()),
        "air_dam": mod("Air Dam", TP, fbm_air_dam()),
    },
    "RearBumper": {
        "chrome_bar": mod("Chrome Bar", M, rbm_chrome_bar()),
        "drag_skids": mod("Drag Skids", PS, rbm_drag_skids()),
        "diffuser": mod("Diffuser", WE, rbm_diffuser()),
        "keel": mod("Keel", GT, rbm_keel()),
        "nerf_pair": mod("Nerf Pair", RO, rbm_nerf_pair()),
        "light_strip": mod("Light Strip", TP, rbm_light_strip()),
    },
    "RearSpoiler": {
        "ducktail": mod("Ducktail", M, rs_ducktail()),
        "pedestal_wing": mod("Pedestal Wing", PS, rs_pedestal_wing()),
        "delta_wing": mod("Delta Wing", WE, rs_delta_wing()),
        "dorsal_fin": mod("Dorsal Fin", GT, rs_dorsal_fin()),
        "twin_fins": mod("Twin Fins", RO, rs_twin_fins()),
        "biplane": mod("Biplane", TP, rs_biplane()),
    },
}

SLOT_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost", "FrontBody", "RearBody", "SidePods",
              "FrontBumper", "RearBumper", "RearSpoiler"]


def kit(name, culture, *ids):
    return {"name": name, "culture": culture, "modules": dict(zip(SLOT_ORDER, ids))}


KITS = {
    "muscle": kit("Boulevard", M, "ram", "thunder_twins", "outrigger_nacelles", "quad_cannon",
                  "longhorn", "fastback_quarters", "door_pods", "chin_bar", "chrome_bar", "ducktail"),
    "prostreet": kit("Quarter Mile", PS, "zoomie_rails", "big_bertha", "strake_rails", "big_bell",
                     "blower_rail", "tubbed", "fuel_tanks", "push_bars", "drag_skids", "pedestal_wing"),
    "wedge": kit("Folded Edge", WE, "slot_ram", "vector_slab", "canard_vanes", "slot_burner",
                 "popup_prongs", "kamm_tail", "intake_scoops", "wedge_lip", "diffuser", "delta_wing"),
    "eurogt": kit("Autostrada", GT, "straight_six", "trident", "gull_pods", "wide_pair",
                  "long_nose", "grand_tail", "gill_sills", "quarter_bumpers", "keel", "dorsal_fin"),
    "roadster": kit("Riviera", RO, "quad_cluster", "bullet", "float_pods", "megaphones",
                    "grand_quad", "boat_tail", "rocker_blades", "chrome_blades", "nerf_pair", "twin_fins"),
    "turbo": kit("Night Shift", TP, "cassette", "over_under", "fin_stacks", "tri_stack",
                 "flip_nose", "slab_hatch", "strake_box", "air_dam", "light_strip", "biplane"),
}

PAINT = {
    "brawler": {"primary": "#e0601a", "secondary": "#1b1b1e", "neon": "#ffe9a8"},
    "outlaw": {"primary": "#5b22a8", "secondary": "#e2b233", "neon": "#ff4df2"},
    "stiletto": {"primary": "#e3c21c", "secondary": "#18191c", "neon": "#ff5a36"},
    "regent": {"primary": "#2a4f8f", "secondary": "#d8d2c2", "neon": "#ffd9a0"},
    "mamba": {"primary": "#0f6a45", "secondary": "#efe6cf", "neon": "#fff2c0"},
    "nightshift": {"primary": "#c21a2c", "secondary": "#101114", "neon": "#3df2ff"},
}
# The swap builds are the cells the critic called out: wide cabins in the slim kits, slim cabins in the wide kits.
SWAP = {"brawler": "roadster", "outlaw": "turbo", "stiletto": "eurogt", "regent": "wedge", "mamba": "muscle",
        "nightshift": "prostreet"}

BUILDS = []
for cid, c in COCKPITS.items():
    BUILDS.append({"name": "%s, own kit (%s)" % (c["name"], KITS[c["kit"]]["name"]), "cockpit": cid, "kit": c["kit"],
                   "paint": PAINT[cid]})
for cid, c in COCKPITS.items():
    BUILDS.append({"name": "%s in %s kit" % (c["name"], KITS[SWAP[cid]]["name"]), "cockpit": cid, "kit": SWAP[cid],
                   "paint": PAINT[cid]})
BUILDS += [
    {"name": "Mixed: Brawler street brawler", "cockpit": "brawler", "kit": "muscle",
     "modules": {"Engine2": "big_bertha", "Boost": "big_bell", "RearSpoiler": "pedestal_wing", "Stabilisers": "fin_stacks"},
     "paint": {"primary": "#1c7d8c", "secondary": "#f0f0f0", "neon": "#ffd27a"}},
    {"name": "Mixed: Stiletto grand tourer", "cockpit": "stiletto", "kit": "eurogt",
     "modules": {"Engine1": "slot_ram", "Boost": "slot_burner", "FrontBody": "popup_prongs", "RearSpoiler": "delta_wing",
                 "Stabilisers": "canard_vanes"},
     "paint": {"primary": "#d8d8dc", "secondary": "#b0182a", "neon": "#ff8a3d"}},
    {"name": "Mixed: Mamba night runner", "cockpit": "mamba", "kit": "turbo",
     "modules": {"Engine1": "quad_cluster", "Engine2": "thunder_twins", "Boost": "megaphones", "FrontBody": "longhorn"},
     "paint": {"primary": "#23264f", "secondary": "#d9dbe6", "neon": "#ff2bd6"}},
]

# Full-width bumpers on the two noses that stop short of the bumper plane (the second review asked to see them).
BUILDS += [
    {"name": "Mixed: Stiletto with air dam", "cockpit": "stiletto", "kit": "wedge",
     "modules": {"FrontBumper": "air_dam"}, "paint": PAINT["stiletto"]},
    {"name": "Mixed: Outlaw with air dam", "cockpit": "outlaw", "kit": "prostreet",
     "modules": {"FrontBumper": "air_dam"}, "paint": PAINT["outlaw"]},
    {"name": "Mixed: Regent with chin bar", "cockpit": "regent", "kit": "wedge",
     "modules": {"FrontBumper": "chin_bar"}, "paint": PAINT["regent"]},
    {"name": "Mixed: Nightshift with chin bar", "cockpit": "nightshift", "kit": "prostreet",
     "modules": {"FrontBumper": "chin_bar"}, "paint": PAINT["nightshift"]},
]

SPEC = {
    "id": "rift", "displayName": "Rift",
    "tagline": "A classic coupe cut into floating sections, slung with jets.",
    "standard": STANDARD, "cockpits": COCKPITS, "kits": KITS, "modules": MODULES, "builds": BUILDS,
}


def _selfcheck():
    """Every wedge orientation must fill its bounds and lean toward the named right-angle corner.
    A canted lift jet must point down, outboard and back."""
    sys.path.insert(0, ROOT)
    import numpy as np
    import vbspec
    want = {"bottom": (1, -1), "top": (1, 1), "back": (2, 1), "front": (2, -1), "right": (0, 1), "left": (0, -1)}
    for kind in _WEDGE:
        p = wdg(1, 3, 10, 13, 20, 24, kind)
        w, _ = vbspec.world_mesh(p)
        lo, hi = w.min(axis=0), w.max(axis=0)
        assert np.allclose(lo, [1, 10, 20], atol=1e-6) and np.allclose(hi, [3, 13, 24], atol=1e-6), (kind, lo, hi)
        lean = w.mean(axis=0) - (lo + hi) / 2
        for word in kind[1:]:
            axis, sign = want[word]
            assert lean[axis] * sign > 1e-6, (kind, word, lean)
    a, b = cant_jet(5, 0, 0, 40, 20, ((1.0, 0.4, "detail", ""), (1.0, 0.4, "thrust", "")), m=False)
    step = vbspec.world_mesh(b)[0].mean(axis=0) - vbspec.world_mesh(a)[0].mean(axis=0)
    assert step[0] > 0.3 and step[1] < -0.3 and step[2] > 0.1, step
    axis = vbspec.rot_matrix(a["rot"]) @ np.array([0.0, -1.0, 0.0])
    assert np.allclose(axis, step / np.linalg.norm(step), atol=1e-3), (axis, step)


def _report():
    """Pairwise distinctness per slot: free outline (shared area removed) and whole outline."""
    sys.path.insert(0, ROOT)
    import vbspec

    groups = {"Cockpit": {k: vbspec.expand_parts(v["parts"]) for k, v in COCKPITS.items()}}
    for s, mods in MODULES.items():
        groups[s] = {k: vbspec.expand_parts(v["parts"]) for k, v in mods.items()}
    for g, items in groups.items():
        want = 0.35 if g in vbspec.BIG_SLOTS else 0.25
        print("%s  (%s)" % (g, ", ".join("%s=%d" % (i, len(items[i])) for i in items)))
        for (a, b), (free, raw) in sorted(vbspec.distinct_table(items).items(), key=lambda kv: kv[1][0]):
            print("   %s %-20s %-20s free %.2f   whole %.2f" % ("  " if free >= want else "!!", a, b, free, raw))


if __name__ == "__main__":
    _selfcheck()
    with open(SPEC_PATH, "w", encoding="utf-8") as f:
        json.dump(SPEC, f, indent=1)
    print("wrote %s: %d cockpits, %d kits, %d modules, %d builds" % (
        SPEC_PATH, len(COCKPITS), len(KITS), sum(len(m) for m in MODULES.values()), len(BUILDS)))
    if "--report" in sys.argv:
        _report()
