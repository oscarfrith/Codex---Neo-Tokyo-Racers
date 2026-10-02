"""Generator for the Tether frame-class blockout spec (round 2, after the critic's review). Design exploration only.

Run from the repo root:
    py -3 scripts/vehicle_blockouts/gen/tether.py            write the spec
    py -3 scripts/vehicle_blockouts/gen/tether.py --report   print the closest look-alike pairs
Writes scripts/vehicle_blockouts/specs/tether.json. Then render with preview.py.

Tether is the pod-racer class: a pilot pod towed by two big jet engines.
Root space: +X right, +Y up, forward is -Z. Units are studs.

Layout of the four fundamentals:
  Engine1     tow engine pair, far ahead of the pod (a mirrored pair is one module)
  Engine2     pod thruster on the pod transom
  Stabilisers vanes and lift jets on the outer flank of each tow engine
  Boost       afterburner units riding piggyback on the top pad of each tow engine

Everything interchanges because every parent carries the same small flat pads (see the pad
tables below) and every module lands on a pad, never on a body shape.

No wheels and nothing wheel-like: every round part is longer than it is wide and lies along the
direction of travel, or stands upright as a lift-jet barrel. No ring bands, no disc faces.
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "specs", "tether.json"))

# --------------------------------------------------------------------------- datums
BELT = 2.4            # beltline: engine axis, binder, cables, hitch bar
SILL = -0.4           # pod belly
HOVER = -2.0          # hover plane (datum)
LOW = -1.6            # lowest any part goes
TOP = 6.8             # highest any module goes
EX, EY = 4.9, BELT    # tow engine axis (the mirrored engine sits at -EX)
E_X0, E_X1 = 2.6, 7.2     # engine envelope, +X side: 4.6 across at most
E_Y0, E_Y1 = -0.2, 4.8
E_Z0, E_Z1 = -16.0, -2.0
NOSE_Z = -18.5        # front of the nose-piece envelope
OUT_X = 9.6           # outer limit (stabilisers): the class is 19.2 wide
BOOST_Z0, BOOST_Z1 = -14.0, -1.5
HITCH_Z = 5.0         # pod front plane: cables end here
CAB_Z1 = 12.6         # cabin ends, tail deck starts
POD_Z1 = 14.5         # pod transom plane
DECK_Y = 3.0          # top of the tail deck (fin seam)
CAB_Y1 = 6.6
POD_X = 4.0           # pod half-width limit
TAIL_Z = 18.5

M = True              # shorthand for mirror=True


# --------------------------------------------------------------------------- part helpers
def _r(v):
    return round(float(v), 3)


def P(shape, size, pos, ch="primary", rot=None, m=False, note=None):
    d = {"shape": shape, "size": [_r(v) for v in size], "pos": [_r(v) for v in pos]}
    if rot and any(abs(a) > 1e-6 for a in rot):
        d["rot"] = [_r(a) for a in rot]
    d["ch"] = ch
    if m:
        d["mirror"] = True
    if note:
        d["note"] = note
    return d


def box(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None, rot=None):
    """Block from its extents (rot, if given, spins it about its centre)."""
    return P("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def _no_disc(d, length, ch):
    # Stricter than the validator: nothing fatter than 1.5 may be shorter than 0.6 of its width.
    assert d < 1.5 or length >= 0.6 * d, "disc-like cylinder %.2f x %.2f (%s)" % (d, length, ch)


def tube(d, z0, z1, x, y, ch="primary", m=False, note=None):
    """Cylinder along Z (the direction of travel): barrels, nozzles, pods."""
    _no_disc(d, z1 - z0, ch)
    return P("cyl_z", [d, d, z1 - z0], [x, y, (z0 + z1) / 2], ch, None, m, note)


def post(d, y0, y1, x, z, ch="detail", m=False, note=None):
    """Upright cylinder: lift-jet barrels and hinge posts."""
    _no_disc(d, y1 - y0, ch)
    return P("cyl_y", [d, y1 - y0, d], [x, (y0 + y1) / 2, z], ch, None, m, note)


def xbar(d, x0, x1, y, z, ch="detail", m=False, note=None):
    """Thin cylinder across the vehicle: bars and energy beams. Never use this for anything fat."""
    assert d < 1.0, "no fat cylinders across the vehicle: they read as wheels"
    return P("cyl_x", [x1 - x0, d, d], [(x0 + x1) / 2, y, z], ch, None, m, note)


def ball(d, x, y, z, ch="neon", m=False, note=None):
    return P("ball", [d, d, d], [x, y, z], ch, None, m, note)


def _aim(p0, p1):
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    rx = -math.degrees(math.asin(dy / length))
    ry = math.degrees(math.atan2(dx, dz))
    mid = [(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2]
    return length, mid, [rx, ry, 0]


def rod(p0, p1, d, ch="detail", m=False, note=None):
    """Round rod between two points: cables, stays, tilted jets."""
    length, mid, rot = _aim(p0, p1)
    _no_disc(d, length, ch)
    return P("cyl_z", [d, d, length], mid, ch, rot, m, note)


def beam(p0, p1, w, h, ch="secondary", m=False, note=None):
    """Rectangular beam between two points (w across, h tall)."""
    length, mid, rot = _aim(p0, p1)
    return P("block", [w, h, length], mid, ch, rot, m, note)


RAMPS = {"up": None,             # thin edge front-bottom, rises to the rear
         "down": [0, 180, 0],    # tall at the front, falls to the rear
         "chin": [0, 0, 180],    # flat top, underside rises to the front (upturned prow)
         "tuck": [180, 0, 0]}    # flat top, underside rises to the rear (boat tail)


def ramp(x0, x1, y0, y1, z0, z1, ch="primary", kind="up", m=False, note=None, roll=0.0):
    rot = list(RAMPS[kind] or [0, 0, 0])
    rot[2] += roll
    return P("wedge", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def fin(xs, xa, y0, y1, z0, z1, ch="primary", apex="front", m=False, note=None):
    """Triangle in plan with a vertical knife edge. Straight side at xs; the wide end reaches xa."""
    size = [y1 - y0, abs(xa - xs), z1 - z0]
    pos = [(xs + xa) / 2, (y0 + y1) / 2, (z0 + z1) / 2]
    if apex == "front":
        rot = [0, 0, -90] if xa > xs else [0, 0, 90]
    else:
        rot = [0, 180, 90] if xa > xs else [0, 180, -90]
    return P("wedge", size, pos, ch, rot, m, note)


def along(p0, p1, t):
    return [p0[i] + (p1[i] - p0[i]) * t for i in range(3)]


# --------------------------------------------------------------------------- hardpoint pads
# Every tow engine carries these pads at the same numbers. Modules land on them.
# They are small on purpose: the engine is free to be any shape around them.
RAIL_IN = (2.65, 3.1, 1.95, 2.85, -12.8, -8.2)       # cables and binder (stations Z -12 and Z -9)
RAIL_OUT = (6.7, 7.15, 1.95, 2.85, -12.5, -8.5)      # stabilisers
PAD_TOP = (4.1, 5.7, 4.4, 4.75, -11.2, -9.2)         # boost
COLLAR = 1.1                                         # half-size of the square nose collar
COLLAR_Z = (-15.95, -15.6)                           # nose piece
BINDER_Z, CABLE_Z = -12.0, -9.0


def engine_pads():
    return [
        box(*RAIL_IN, ch="detail", m=M, note="inner rail pad: binder station Z -12, cable station Z -9"),
        box(*RAIL_OUT, ch="detail", m=M, note="outer rail pad: stabiliser seam at X 7.2"),
        box(*PAD_TOP, ch="detail", m=M, note="top pad: boost seam at Y 4.8"),
        box(EX - COLLAR, EX + COLLAR, EY - COLLAR, EY + COLLAR, COLLAR_Z[0], COLLAR_Z[1], "detail", M,
            "nose collar, 2.2 square: nose piece seam at Z -16"),
        tube(1.2, -15.7, -14.4, EX, EY, "detail", M, "hub behind the nose collar"),
    ]


# Every pod carries these four pads at the same numbers.
HITCH = (-1.6, 1.6, BELT, HITCH_Z + 0.3)             # bar X range, Y, Z centre (0.5 thick)
TRANSOM = (-1.8, 1.8, 0.4, 2.6, 14.05, 14.45)        # pod thruster
DECK = (-1.7, 1.7, 2.7, DECK_Y, 12.65, 14.4)         # fins
BELLY = (-1.4, 1.4, SILL, -0.1, 9.4, 13.4)           # pod tail


def pod_pads(lugs=True):
    p = [
        xbar(0.5, HITCH[0], HITCH[1], HITCH[2], HITCH[3], "detail", note="hitch bar pad: cable seam at Z 5"),
        box(*TRANSOM, ch="detail", note="transom pad: pod thruster seam at Z 14.5"),
        box(*DECK, ch="secondary", note="tail deck pad: fin seam at Y 3"),
        box(*BELLY, ch="detail", note="belly pad: pod tail seam at Y -0.4"),
    ]
    if lugs:
        p.append(box(1.0, 1.4, 2.05, 2.75, 5.45, 6.3, "detail", M, "hitch lug"))
    return p


def pilot(z, seat_y, arms=True):
    """Seated pilot. z is the hip position, seat_y the seat top."""
    p = [
        box(-0.85, 0.85, seat_y, seat_y + 1.6, z - 0.45, z + 0.45, "driver"),
        ball(1.2, 0, seat_y + 2.1, z, "driver"),
    ]
    if arms:
        p.append(P("block", [0.42, 0.42, 1.6], [1.0, seat_y + 1.0, z - 0.9], "driver", [-12, 0, 0], M))
    return p


# --------------------------------------------------------------------------- cockpits (pods)
# Six pods, each a different length, height and outline:
#   Bucket  short wide square tub at the back of an open drawbar, full-height roll cage
#   Sled    the lowest: a long enclosed dart with a pointed prow and delta sponsons
#   Capsule a slim round hull, clearly longer than wide, with a half-barrel canopy on top
#   Chariot a tall wide shield at the front and a narrow open platform behind
#   Skiff   the narrowest: a boat with a tall stem post, a stepped screen and a raised stern
#   Bubble  a big clear dome at the nose and a short tapering tail
def pod_bucket():
    """Scrapyard. A wide square tub at the back of a long open drawbar, under a full-height roll cage."""
    return pod_pads() + [
        box(-3.2, 3.2, -0.1, 1.4, 9.4, 14.05, "primary", note="square tub floor"),
        ramp(-3.2, 3.2, -0.1, 1.4, 8.5, 9.4, "primary", "chin", note="scoop lip"),
        box(2.8, 3.2, 1.4, 3.0, 9.4, 14.05, "primary", M, "tub side wall"),
        box(-2.8, 2.8, 1.4, 3.0, 9.4, 9.8, "primary", note="tub front wall"),
        box(-2.8, 2.8, 1.4, 2.6, 13.65, 14.05, "primary", note="tub back wall"),
        box(2.75, 3.3, 2.7, 3.0, 9.3, 14.05, "secondary", M, "rim rail"),
        box(-2.8, 2.8, 2.7, 3.0, 9.3, 9.8, "secondary", note="front rim"),
        box(-2.8, 2.8, 1.4, 1.5, 9.8, 12.65, "detail", note="dark floor of the well"),
        box(-1.7, 1.7, 1.4, 2.7, 12.65, 13.65, "primary", note="tank block under the deck"),
        beam((1.2, 2.4, 6.2), (2.6, 2.1, 9.5), 0.4, 0.4, "detail", M, "open drawbar to the hitch lugs"),
        box(-0.2, 0.2, 2.15, 2.65, 5.5, 9.5, "detail", note="centre drawbar"),
        box(2.85, 3.15, 3.0, 5.6, 9.4, 9.7, "detail", M, "cage post, front"),
        box(2.85, 3.15, 3.0, 5.6, 12.2, 12.5, "detail", M, "cage post, rear"),
        box(2.85, 3.15, 5.6, 5.9, 9.4, 12.5, "detail", M, "cage top rail"),
        box(-2.85, 2.85, 5.6, 5.9, 9.4, 9.7, "detail", note="cage front bar"),
        box(-2.85, 2.85, 5.6, 5.9, 12.2, 12.5, "detail", note="cage rear bar"),
        rod((3.0, 5.6, 12.3), (3.0, 3.1, 9.8), 0.25, "detail", M, "cage diagonal"),
        box(-1.7, 1.7, 5.9, 6.6, 10.0, 12.4, "secondary", note="salvaged roof tank on the cage"),
        P("block", [4.6, 1.3, 0.15], [0, 3.6, 9.95], "glass", [28, 0, 0], note="flat aero screen"),
        box(-0.7, 0.7, 1.5, 3.4, 12.35, 12.65, "detail", note="seat back"),
    ] + pilot(11.7, 1.5)


def pod_sled():
    """Desert. The lowest pod: a long enclosed dart with a pointed prow, a low canopy and delta sponsons."""
    return pod_pads(lugs=False) + [
        box(-1.5, 1.5, -0.1, 1.9, 8.0, 14.05, "primary", note="hull"),
        fin(0, 1.5, -0.1, 1.9, 5.6, 8.0, "primary", "front", M, "pointed prow"),
        box(-0.25, 0.25, 1.4, 2.75, 5.45, 6.6, "detail", note="tow head carries the hitch bar"),
        box(-0.5, 0.5, 1.9, 2.0, 6.4, 7.6, "secondary", note="deck stripe"),
        ramp(-1.1, 1.1, 1.9, 3.2, 7.6, 10.2, "glass", "up", note="long raked canopy"),
        box(-1.1, 1.1, 1.9, 3.2, 10.2, 11.0, "glass", note="canopy"),
        ramp(-1.1, 1.1, 1.9, 3.2, 11.0, 12.6, "primary", "down", note="fairing behind the canopy"),
        box(-0.3, 0.3, 3.2, 3.35, 10.2, 11.2, "secondary", note="canopy spine"),
        fin(1.5, 3.9, -0.1, 0.9, 8.0, 12.2, "secondary", "front", M, "delta sponson"),
        box(1.5, 3.9, -0.1, 0.9, 12.2, 14.05, "secondary", M, "sponson"),
        box(3.7, 3.9, 0.9, 2.2, 12.6, 14.05, "primary", M, "tip fin"),
        ramp(3.7, 3.9, 0.9, 2.2, 11.2, 12.6, "primary", "up", M),
        box(3.9, 3.98, 0.2, 0.5, 12.4, 14.0, "neon", M, "sponson light"),
        box(-0.75, 0.75, 1.9, 2.3, 8.5, 9.8, "driver", note="legs stretched forward"),
        P("block", [1.6, 0.8, 1.6], [0, 2.4, 10.0], "driver", [-30, 0, 0], note="reclined torso"),
        ball(1.1, 0, 2.6, 10.5, "driver"),
    ]


def pod_capsule():
    """Works. A slim round pressure hull, clearly longer than wide: half-barrel canopy, tall fin, two side tanks."""
    cy = 1.9
    return pod_pads(lugs=False) + [
        box(-0.25, 0.25, 1.9, 2.75, 5.45, 6.3, "detail", note="tow eye on the nose"),
        ball(2.6, 0, cy, 6.8, "secondary", note="rounded nose"),
        tube(3.0, 6.8, 8.6, 0, cy, "primary", note="nose section"),
        tube(3.6, 8.2, 12.6, 0, cy, "primary", note="pressure hull, 3.6 across and 4.4 long"),
        tube(2.4, 8.6, 11.2, 0, 3.4, "glass", note="half-barrel canopy: only the top half shows above the hull"),
        box(-0.2, 0.2, 4.55, 4.7, 8.6, 11.2, "secondary", note="canopy spine"),
        ramp(-1.0, 1.0, 3.4, 4.5, 11.2, 12.6, "primary", "down", note="fairing behind the canopy"),
        ramp(-0.15, 0.15, 3.6, 6.4, 10.2, 12.6, "secondary", "up", note="tall dorsal fin"),
        box(-1.2, 1.2, -0.1, 1.0, 7.4, 13.6, "primary", note="keel fairing"),
        tube(2.6, 12.4, 14.05, 0, 1.6, "primary", note="tail cone under the deck"),
        tube(1.2, 7.6, 13.4, 2.9, cy, "secondary", M, "strap-on side tank"),
        tube(0.7, 6.9, 7.8, 2.9, cy, "primary", M, "tank nose"),
        box(1.7, 2.4, cy - 0.2, cy + 0.2, 9.0, 9.6, "detail", M, "tank strut"),
        box(1.7, 2.4, cy - 0.2, cy + 0.2, 11.6, 12.2, "detail", M, "tank strut"),
        box(-0.8, 0.8, 2.7, 3.5, 9.5, 10.3, "driver", note="shoulders"),
        ball(1.2, 0, 3.9, 9.9, "driver"),
    ]


def pod_chariot():
    """Showboat. A tall wide shield with a glass visor, cheeks that taper back to a narrow open platform."""
    return pod_pads() + [
        box(-1.5, 1.5, -0.1, 0.6, 6.4, 14.05, "primary", note="narrow floor"),
        box(-1.5, 1.5, 0.6, 2.9, 5.9, 7.0, "primary", note="tow head"),
        ramp(-3.5, 3.5, 2.9, 4.6, 5.9, 7.0, "primary", "up", note="raked shield face"),
        box(-3.5, 3.5, 0.6, 4.6, 7.0, 7.6, "primary", note="tall wide breastwork shield"),
        box(-3.3, 3.3, 4.6, 5.8, 7.2, 7.4, "glass", note="visor band"),
        box(-3.5, 3.5, 5.8, 6.2, 7.0, 7.6, "secondary", note="crest rail"),
        box(3.3, 3.5, 4.6, 5.8, 7.0, 7.6, "secondary", M, "visor post"),
        box(-0.3, 0.3, 6.2, 6.6, 7.0, 7.6, "neon", note="crest jewel"),
        fin(1.5, 3.5, 0.6, 3.2, 7.6, 10.4, "primary", "rear", M, "cheek tapers back to the platform"),
        rod((3.4, 3.3, 7.7), (1.6, 3.3, 10.3), 0.25, "neon", M, "trim along the cheek edge"),
        box(1.5, 1.65, 0.05, 0.35, 6.6, 13.8, "neon", M, "sill light"),
        box(-0.8, 0.8, 0.6, 1.9, 10.9, 12.2, "detail", note="perch"),
        xbar(0.25, -1.3, 1.3, 3.6, 8.6, "detail", note="rein bar"),
        box(-1.7, 1.7, 0.6, 2.7, 12.6, 14.05, "primary", note="tail step under the deck"),
    ] + pilot(11.3, 1.9)


def pod_skiff():
    """Harbour. The narrowest pod: a slim boat, tall stem post, tall stepped screen under a hard top, raised stern."""
    return pod_pads(lugs=False) + [
        box(-1.3, 1.3, -0.1, 1.6, 8.6, 12.6, "primary", note="hull"),
        fin(0, 1.3, -0.1, 1.6, 5.7, 8.6, "primary", "front", M, "long pointed bow"),
        fin(0, 1.1, 1.6, 1.7, 6.3, 8.6, "secondary", "front", M, "fore deck"),
        box(-0.15, 0.15, 1.2, 4.4, 5.6, 6.2, "primary", note="tall stem post"),
        ramp(-0.15, 0.15, 1.6, 4.4, 6.2, 8.4, "primary", "down", note="stem falls back to the fore deck"),
        box(-0.2, 0.2, 4.4, 4.7, 5.6, 6.2, "neon", note="stem lantern"),
        box(-0.3, 0.3, 2.05, 2.75, 5.45, 6.3, "detail", note="stem carries the hitch bar"),
        box(1.3, 1.4, 0.9, 1.15, 8.6, 12.6, "neon", M, "gunwale light"),
        P("block", [2.4, 2.4, 0.15], [0, 2.9, 9.0], "glass", [30, 0, 0], note="screen, lower pane"),
        P("block", [2.4, 2.5, 0.15], [0, 5.0, 10.1], "glass", [18, 0, 0], note="screen, upper step"),
        box(-1.2, 1.2, 3.8, 3.95, 9.3, 10.0, "detail", note="screen step shelf"),
        box(-1.3, 1.3, 6.2, 6.45, 10.2, 12.5, "secondary", note="hard top"),
        box(1.1, 1.3, 3.0, 6.2, 12.2, 12.4, "detail", M, "hard top post"),
        box(-1.3, 1.3, 1.6, 3.0, 11.7, 12.6, "primary", note="raised stern"),
        ramp(-1.3, 1.3, 1.6, 3.0, 11.3, 11.7, "primary", "up"),
        box(-1.5, 1.5, 0.2, 2.7, 12.6, 14.05, "primary", note="stern under the deck"),
    ] + pilot(10.6, 1.6)


def pod_bubble():
    """Atomic. A big clear dome at the nose over an open tub with the pilot in view, and a short tapering tail."""
    return pod_pads() + [
        box(-1.6, 1.6, -0.1, 1.2, 5.9, 12.6, "primary", note="floor pan"),
        box(1.0, 1.4, 1.2, 2.1, 5.9, 6.3, "detail", M, "tow post under the hitch lug"),
        box(1.6, 2.1, 0.3, 1.7, 6.6, 10.6, "secondary", M, "tub side"),
        ball(5.4, 0, 3.0, 8.4, "glass", note="clear bubble dome"),
        box(-0.9, 0.9, 1.2, 1.6, 7.9, 9.4, "detail", note="seat"),
        box(-0.7, 0.7, 1.6, 3.4, 9.2, 9.45, "detail", note="seat back"),
        box(-2.0, 2.0, -0.1, 2.6, 10.6, 12.6, "primary", note="engine bay behind the dome"),
        ramp(-1.2, 1.2, 2.6, 3.8, 10.6, 12.6, "secondary", "down", note="dorsal hump falls to the deck"),
        fin(2.0, 2.6, 0.9, 1.5, 9.0, 12.6, "secondary", "front", M, "side spear"),
        box(-1.7, 1.7, 0.2, 2.7, 12.6, 14.05, "primary", note="tail under the deck"),
        tube(0.6, 12.5, 14.3, 2.1, 1.9, "neon", M, "bullet tail light"),
    ] + pilot(8.6, 1.6)


# --------------------------------------------------------------------------- Engine1: tow engines
# Every engine is at least 2.2 times longer than it is wide. No ring bands and no flat round tail face.
def e1_long_barrels():
    """Works. The slimmest engine, front-heavy: intake bell, turbine, then a long thin tailpipe to a small nozzle."""
    return engine_pads() + [
        tube(3.4, -15.6, -12.2, EX, EY, "primary", M, "intake bell"),
        tube(2.8, -15.72, -13.8, EX, EY, "detail", M, "intake throat"),
        tube(2.8, -12.4, -9.0, EX, EY, "secondary", M, "turbine"),
        tube(1.8, -9.2, -4.0, EX, EY, "primary", M, "long slim tailpipe"),
        box(EX + 0.85, EX + 1.0, EY - 0.15, EY + 0.15, -8.2, -4.6, "neon", M, "tailpipe light"),
        tube(2.2, -4.4, -2.7, EX, EY, "detail", M, "nozzle"),
        tube(1.7, -3.2, -2.1, EX, EY, "thrust", M, "jet"),
        box(EX - 0.3, EX + 0.3, 3.7, 4.4, -11.0, -9.4, "primary", M, "pylon to the top pad"),
        ramp(EX - 0.3, EX + 0.3, 3.7, 4.4, -12.0, -11.0, "primary", "up", M),
        box(3.1, 3.6, 2.15, 2.65, -12.3, -11.7, "detail", M, "inner strut"),
        box(3.1, 4.05, 2.15, 2.65, -9.0, -8.4, "detail", M, "inner strut"),
        box(6.2, 6.7, 2.15, 2.65, -12.1, -11.5, "detail", M, "outer strut"),
        box(5.75, 6.7, 2.15, 2.65, -9.2, -8.6, "detail", M, "outer strut"),
    ]


def e1_fat_turbines():
    """Desert. The fattest engine, but a long nacelle: 4.4 across and 12 long, flat flanks, a boxy top scoop."""
    return engine_pads() + [
        tube(3.8, -15.6, -13.0, EX, EY, "secondary", M, "intake lip"),
        tube(3.2, -15.7, -13.6, EX, EY, "detail", M, "intake throat"),
        tube(4.4, -13.6, -7.4, EX, EY, "primary", M, "nacelle body"),
        tube(3.6, -7.8, -5.6, EX, EY, "secondary", M, "tail taper"),
        tube(2.8, -6.0, -4.3, EX, EY, "detail", M, "nozzle"),
        tube(1.8, -4.7, -3.6, EX, EY, "thrust", M, "jet"),
        box(6.75, 7.1, 1.2, 3.6, -13.2, -8.2, "secondary", M, "flat flank fairing, outer"),
        box(2.7, 3.05, 1.2, 3.6, -13.2, -8.2, "secondary", M, "flat flank fairing, inner"),
        box(7.1, 7.16, 3.2, 3.45, -13.0, -8.4, "neon", M),
        box(EX - 1.0, EX + 1.0, 4.1, 4.7, -13.4, -9.0, "secondary", M, "boxy top scoop"),
        box(EX - 0.85, EX + 0.85, 4.25, 4.62, -13.52, -13.36, "detail", M, "scoop intake face"),
        ramp(EX - 1.0, EX + 1.0, 4.1, 4.7, -9.0, -7.4, "secondary", "down", M),
        box(EX - 0.5, EX + 0.5, -0.05, 0.5, -12.6, -8.6, "detail", M, "belly keel"),
    ]


def e1_quad_cluster():
    """Scrapyard. Four slim jets each side, spread two over two with clear daylight between, and staggered."""
    ox, oy = 1.5, 1.5
    parts = engine_pads() + [
        box(EX - 0.35, EX + 0.35, EY - 0.35, EY + 0.35, -15.6, -4.6, "detail", M, "centre spine"),
        box(3.1, 6.7, 2.15, 2.65, -10.8, -10.2, "detail", M, "cross beam carries both rails"),
        box(EX - 0.35, EX + 0.35, EY + 0.35, 4.4, -11.0, -9.4, "detail", M, "saddle post under the top pad"),
    ]
    for z in (-12.4, -6.4):
        parts += [P("block", [0.3, 4.0, 0.4], [EX, EY, z], "detail", [0, 0, 45], M, "cross brace"),
                  P("block", [0.3, 4.0, 0.4], [EX, EY, z], "detail", [0, 0, -45], M, "cross brace")]
    layout = [(-ox, oy, -15.4, -5.0), (ox, oy, -13.8, -3.0), (-ox, -oy, -13.8, -3.0), (ox, -oy, -15.4, -5.0)]
    for dx, dy, z0, z1 in layout:
        x, y = EX + dx, EY + dy
        parts += [
            tube(1.5, z0, z1 - 1.6, x, y, "primary", M, "jet tube"),
            tube(1.2, z0 - 0.1, z0 + 0.7, x, y, "detail", M, "intake throat"),
            tube(1.2, z1 - 1.8, z1 - 0.4, x, y, "detail", M, "necked nozzle"),
            tube(1.0, z1 - 0.8, z1 + 0.3, x, y, "thrust", M, "jet"),
        ]
    return parts


def e1_bells():
    """Showboat. A slim snout that opens over seven studs into a square four-petal horn. The jet sits inside it."""
    z0, z1 = -9.6, -2.5
    r0, r1 = 1.15, 1.95
    return engine_pads() + [
        tube(2.0, -15.2, -10.6, EX, EY, "primary", M, "intake snout"),
        tube(2.8, -15.6, -13.2, EX, EY, "secondary", M, "intake lip"),
        tube(2.2, -15.7, -14.2, EX, EY, "detail", M, "intake throat"),
        tube(2.6, -11.0, -8.2, EX, EY, "secondary", M, "chrome body"),
        tube(2.0, -8.6, -4.4, EX, EY, "detail", M, "inner duct, seen between the petals"),
        tube(1.5, -5.0, -3.0, EX, EY, "thrust", M, "jet, recessed inside the horn"),
        box(EX - 1.0, EX + 1.0, EY - 0.12, EY + 0.12, -3.2, -2.9, "detail", M, "cross vane"),
        box(EX - 0.12, EX + 0.12, EY - 1.0, EY + 1.0, -3.2, -2.9, "detail", M, "cross vane"),
        beam((EX, EY + r0, z0), (EX, EY + r1, z1), 2.3, 0.3, "primary", M, "horn petal, top"),
        beam((EX, EY - r0, z0), (EX, EY - r1, z1), 2.3, 0.3, "primary", M, "horn petal, bottom"),
        beam((EX + r0, EY, z0), (EX + r1, EY, z1), 0.3, 2.3, "secondary", M, "horn petal, outer"),
        beam((EX - r0, EY, z0), (EX - r1, EY, z1), 0.3, 2.3, "secondary", M, "horn petal, inner"),
        box(EX - 0.3, EX + 0.3, 3.6, 4.4, -11.0, -9.6, "primary", M, "pylon to the top pad"),
        box(3.1, 3.95, 2.15, 2.65, -12.3, -11.7, "detail", M, "inner strut"),
        box(3.1, 3.7, 2.15, 2.65, -9.5, -8.9, "detail", M, "inner strut"),
        box(5.85, 6.7, 2.15, 2.65, -12.0, -11.4, "detail", M, "outer strut"),
        box(6.1, 6.7, 2.15, 2.65, -9.5, -8.9, "detail", M, "outer strut"),
    ]


def e1_slabs():
    """Harbour. A twin pair each side: two torpedo jets side by side under a flat deck, like a catamaran."""
    parts = engine_pads() + [
        box(4.0, 5.8, 2.1, 2.7, -14.2, -6.8, "secondary", M, "bridge deck between the hulls"),
        fin(EX, EX + 0.9, 2.1, 2.7, -15.6, -14.2, "secondary", "front", M, "deck bow carries the nose collar"),
        fin(EX, EX - 0.9, 2.1, 2.7, -15.6, -14.2, "secondary", "front", M),
        box(EX - 0.3, EX + 0.3, 2.7, 4.4, -10.8, -9.4, "primary", M, "tower to the top pad"),
        ramp(EX - 0.3, EX + 0.3, 2.7, 4.4, -13.2, -10.8, "primary", "up", M),
    ]
    # The hulls hang under the deck, and the outer hull sits further back than the inner one,
    # so the pair reads as a swept chevron from above.
    hy = 1.5
    for x, z0, z1 in ((3.7, -15.2, -7.4), (6.1, -13.0, -3.6)):
        parts += [
            tube(2.0, z0, z1, x, hy, "primary", M, "torpedo hull"),
            tube(1.6, z0 - 0.15, z0 + 1.2, x, hy, "detail", M, "intake"),
            tube(1.6, z1 - 0.4, z1 + 1.0, x, hy, "detail", M, "nozzle"),
            tube(1.3, z1 + 0.4, z1 + 1.3, x, hy, "thrust", M, "jet"),
            box(x - 0.15, x + 0.15, -0.15, 0.6, z1 - 1.6, z1 - 0.4, "secondary", M, "skeg"),
            ramp(x - 0.15, x + 0.15, -0.15, 0.6, z1 - 3.8, z1 - 1.6, "secondary", "chin", M),
        ]
    return parts


def e1_stack():
    """Atomic. An over-and-under pair each side: a short upper jet and a long lower jet on a tall narrow web."""
    parts = engine_pads() + [
        box(EX - 0.4, EX + 0.4, EY - 0.4, EY + 0.4, -15.6, -14.2, "detail", M, "web bow carries the nose collar"),
        box(EX - 0.25, EX + 0.25, 1.15, 3.45, -14.6, -5.0, "secondary", M, "tall narrow web"),
        box(3.1, 6.7, 2.2, 2.6, -12.4, -8.6, "secondary", M, "stub wing carries both rails"),
        fin(EX + 0.3, 6.7, 2.2, 2.6, -14.0, -12.4, "secondary", "front", M, "swept wing root"),
        fin(EX - 0.3, 3.1, 2.2, 2.6, -14.0, -12.4, "secondary", "front", M),
        ramp(EX - 0.15, EX + 0.15, 2.15, 4.3, -7.2, -4.2, "primary", "down", M, "tail fin falls to the lower jet"),
    ]
    for y, z0, z1 in ((3.45, -15.4, -8.2), (1.15, -12.6, -3.6)):
        parts += [
            tube(2.0, z0, z1, EX, y, "primary", M, "jet barrel"),
            tube(1.6, z0 - 0.15, z0 + 1.2, EX, y, "detail", M, "intake"),
            tube(0.6, z0 - 0.55, z0 + 0.4, EX, y, "neon", M, "intake spike"),
            tube(1.6, z1 - 0.4, z1 + 0.9, EX, y, "detail", M, "nozzle"),
            tube(1.3, z1 + 0.3, z1 + 1.2, EX, y, "thrust", M, "jet"),
        ]
    return parts


# --------------------------------------------------------------------------- Boost: afterburners on the top pad
BX = EX
SADDLE = (4.2, 5.6, E_Y1 + 0.05, -11.1, -9.3)   # x0, x1, y0, z0, z1 of every saddle foot


def _saddle(y1, note="saddle on the top pad"):
    return box(SADDLE[0], SADDLE[1], SADDLE[2], y1, SADDLE[3], SADDLE[4], "detail", M, note)


def b_staged():
    """Works. One long slim burner that telescopes down in three stages."""
    by = 5.95
    return [
        _saddle(5.3),
        tube(1.6, -13.2, -9.2, BX, by, "primary", M, "first stage"),
        tube(1.2, -13.4, -12.6, BX, by, "detail", M, "ram intake"),
        box(BX - 0.1, BX + 0.1, 6.72, 6.79, -12.4, -9.6, "neon", M),
        tube(1.2, -9.6, -6.6, BX, by, "secondary", M, "second stage"),
        tube(0.9, -7.0, -4.6, BX, by, "detail", M, "third stage"),
        tube(0.7, -5.0, -4.1, BX, by, "thrust", M, "jet"),
    ]


def b_can():
    """Desert. One fat burner can, more than twice as long as it is wide, with saddle tanks."""
    by = 5.85
    return [
        _saddle(5.2),
        tube(1.8, -12.4, -8.2, BX, by, "primary", M, "burner can"),
        tube(1.4, -12.6, -11.6, BX, by, "detail", M, "intake"),
        tube(0.7, -11.8, -8.6, BX - 1.3, 5.3, "secondary", M, "saddle tank"),
        tube(0.7, -11.8, -8.6, BX + 1.3, 5.3, "secondary", M, "saddle tank"),
        tube(1.5, -8.6, -7.0, BX, by, "detail", M, "nozzle"),
        tube(1.2, -7.4, -6.5, BX, by, "thrust", M, "jet"),
    ]


def b_bottles():
    """Scrapyard. Three short fat pointed rocket bottles, tilted nose-up on a rack frame. One paint channel."""
    parts = [
        _saddle(5.15, "rack base on the top pad"),
        box(2.9, 6.9, 5.0, 5.2, -9.0, -8.5, "detail", M, "rack rail, rear"),
        box(2.9, 6.9, 5.3, 5.5, -11.4, -10.9, "detail", M, "rack rail, front, set higher"),
        box(4.3, 4.6, 5.0, 5.4, -11.2, -8.6, "detail", M, "rack side"),
        box(5.2, 5.5, 5.0, 5.4, -11.2, -8.6, "detail", M, "rack side"),
    ]
    for x in (3.45, 4.9, 6.35):
        tail, nose = (x, 5.65, -8.0), (x, 6.15, -11.3)
        parts += [
            rod(tail, nose, 1.25, "secondary", M, "rocket bottle"),
            rod(along(tail, nose, 0.98), along(tail, nose, 1.2), 0.8, "secondary", M, "nose cone"),
            rod(along(tail, nose, 1.18), along(tail, nose, 1.34), 0.4, "neon", M, "nose tip"),
            rod(along(tail, nose, -0.14), along(tail, nose, 0.06), 0.85, "thrust", M, "jet"),
            box(x - 0.08, x + 0.08, 6.2, 6.75, -9.2, -8.2, "detail", M, "tail fin"),
        ]
    return parts


def b_trumpets():
    """Showboat. Two long chrome pipes side by side, each ending in a long flared bell."""
    by = 5.75
    parts = [_saddle(5.25)]
    for dx in (-0.9, 0.9):
        parts += [
            tube(1.0, -12.8, -5.6, BX + dx, by, "secondary", M, "pipe"),
            tube(1.4, -13.8, -12.6, BX + dx, by, "primary", M, "intake bell"),
            tube(1.0, -13.9, -13.5, BX + dx, by, "detail", M, "intake throat"),
            tube(1.6, -6.0, -3.8, BX + dx, by, "primary", M, "flared bell"),
            tube(1.2, -4.2, -3.4, BX + dx, by, "thrust", M, "jet"),
        ]
    return parts


def b_slot():
    """Harbour. A flat full-width slot burner with tall end plates."""
    return [
        _saddle(5.1),
        box(3.0, 6.8, 5.1, 5.9, -11.4, -7.6, "primary", M, "flat burner body"),
        ramp(3.0, 6.8, 5.1, 5.9, -13.0, -11.4, "primary", "up", M, "intake ramp"),
        box(3.4, 6.4, 5.9, 6.02, -11.0, -9.8, "detail", M, "top intake louvre"),
        box(3.2, 6.6, 5.2, 5.8, -7.6, -6.9, "detail", M, "slot nozzle"),
        box(3.4, 6.4, 5.3, 5.7, -7.1, -6.5, "thrust", M, "jet"),
        box(2.7, 3.0, 4.9, 6.7, -9.6, -6.4, "secondary", M, "end plate"),
        ramp(2.7, 3.0, 4.9, 6.7, -11.6, -9.6, "secondary", "up", M),
        box(6.8, 7.1, 4.9, 6.7, -9.6, -6.4, "secondary", M, "end plate"),
        ramp(6.8, 7.1, 4.9, 6.7, -11.6, -9.6, "secondary", "up", M),
    ]


def b_finrocket():
    """Atomic. One pointed rocket with swept delta fins."""
    by = 5.8
    return [
        _saddle(5.2),
        tube(1.5, -12.0, -6.6, BX, by, "primary", M, "rocket body"),
        tube(1.0, -13.0, -11.8, BX, by, "secondary", M, "nose cone"),
        tube(0.5, -13.7, -12.8, BX, by, "neon", M, "nose tip"),
        fin(BX + 0.6, BX + 2.1, by - 0.15, by + 0.15, -9.8, -6.2, "secondary", "front", M, "delta fin"),
        fin(BX - 0.6, BX - 2.1, by - 0.15, by + 0.15, -9.8, -6.2, "secondary", "front", M, "delta fin"),
        box(BX + 1.95, BX + 2.15, by - 0.45, by + 0.45, -7.4, -5.8, "primary", M, "fin tip plate"),
        box(BX - 2.15, BX - 1.95, by - 0.45, by + 0.45, -7.4, -5.8, "primary", M, "fin tip plate"),
        tube(1.2, -6.9, -5.4, BX, by, "detail", M, "nozzle"),
        tube(0.9, -5.8, -4.8, BX, by, "thrust", M, "jet"),
    ]


# --------------------------------------------------------------------------- Stabilisers: on the outer rail
# Every option has jets at least 1.0 across, and at least one that points down.
SI = E_X1 + 0.05   # inner face of every vane mount


def s_blades():
    """Works. A tall swept plate with a fat control jet on top and a vectoring jet below that points down and back."""
    a, b = (8.6, 0.0, -11.2), (8.6, -0.75, -8.8)
    return [
        box(SI, 8.3, 2.15, 2.65, -12.0, -11.4, "detail", M, "mount on the outer rail"),
        box(SI, 8.3, 2.15, 2.65, -9.6, -9.0, "detail", M, "mount on the outer rail"),
        box(8.3, 8.6, -0.2, 5.4, -11.0, -8.2, "secondary", M, "tall plate"),
        ramp(8.3, 8.6, BELT, 5.4, -13.4, -11.0, "secondary", "up", M, "swept leading edge, upper"),
        ramp(8.3, 8.6, -0.2, BELT, -13.4, -11.0, "secondary", "chin", M, "swept leading edge, lower"),
        box(8.6, 8.7, 3.4, 3.8, -10.8, -8.4, "neon", M),
        tube(1.4, -12.4, -7.4, 8.6, 6.05, "primary", M, "top control jet"),
        tube(1.1, -12.7, -12.0, 8.6, 6.05, "detail", M, "intake lip"),
        tube(1.1, -7.8, -6.8, 8.6, 6.05, "thrust", M, "jet"),
        rod(a, b, 1.4, "primary", M, "vectoring jet, points down and back"),
        rod(along(a, b, -0.1), along(a, b, 0.12), 1.1, "detail", M, "intake lip"),
        rod(along(a, b, 0.86), along(a, b, 1.14), 1.1, "thrust", M, "jet"),
    ]


def s_petals():
    """Desert. Air-brake petals that splay open at the rear, plus a forward lift jet."""
    return [
        post(0.5, 0.2, 4.6, 7.55, -10.4, "detail", M, "hinge post on the outer rail"),
        P("block", [0.25, 2.8, 4.0], [8.4, 4.3, -8.3], "primary", [0, 14, 20], M, "upper petal"),
        P("block", [0.25, 2.8, 4.0], [8.4, 0.5, -8.3], "primary", [0, 14, -20], M, "lower petal"),
        rod((7.7, 3.6, -10.2), (8.35, 4.2, -8.6), 0.2, "detail", M, "actuator"),
        rod((7.7, 1.2, -10.2), (8.35, 0.6, -8.6), 0.2, "detail", M, "actuator"),
        box(SI, 8.0, 2.15, 2.65, -12.8, -12.2, "detail", M, "lift jet arm"),
        post(1.4, 0.7, 3.8, 8.6, -12.5, "secondary", M, "lift jet barrel"),
        post(1.0, 3.7, 4.2, 8.6, -12.5, "detail", M, "intake"),
        post(1.1, 0.0, 0.8, 8.6, -12.5, "thrust", M, "jet"),
    ]


def s_outriggers():
    """Scrapyard. Two upright lift-jet barrels each side on a stub beam: one at each corner."""
    return [
        box(SI, 7.75, 2.1, 2.7, -13.6, -7.4, "detail", M, "outrigger beam on the outer rail"),
        box(7.75, 8.2, 2.2, 2.6, -13.5, -12.9, "detail", M, "fore arm"),
        post(1.4, 0.0, 3.8, 8.8, -13.2, "primary", M, "fore lift jet"),
        post(1.0, 3.7, 4.2, 8.8, -13.2, "detail", M, "intake"),
        post(1.1, -0.7, 0.1, 8.8, -13.2, "thrust", M, "jet"),
        box(7.75, 8.1, 2.2, 2.6, -8.1, -7.5, "detail", M, "aft arm"),
        post(1.3, 0.6, 3.7, 8.7, -7.8, "secondary", M, "aft lift jet"),
        post(0.9, 3.6, 4.0, 8.7, -7.8, "detail", M, "intake"),
        post(1.0, -0.1, 0.7, 8.7, -7.8, "thrust", M, "jet"),
        rod((8.7, 3.2, -8.2), (8.8, 3.3, -12.6), 0.2, "detail", M, "stay"),
    ]


def s_canards():
    """Showboat. Thick swept canards fore and aft: a lift jet under the fore tip, a fat jet pod on the aft tip."""
    return [
        tube(0.4, -14.6, -6.6, 7.5, BELT, "detail", M, "rail on the outer rail pad"),
        fin(7.6, 9.5, 2.1, 2.7, -15.6, -11.6, "secondary", "front", M, "fore canard, 0.6 thick"),
        post(1.3, 0.9, 2.2, 8.75, -12.4, "primary", M, "lift jet barrel under the canard tip"),
        post(1.0, 2.7, 3.1, 8.75, -12.4, "detail", M, "intake"),
        post(1.1, 0.2, 1.0, 8.75, -12.4, "thrust", M, "jet, points down"),
        fin(7.6, 9.4, 2.1, 2.7, -11.2, -6.8, "secondary", "front", M, "aft canard, 0.6 thick"),
        tube(1.7, -9.4, -4.6, 8.7, BELT, "primary", M, "aft tip jet pod"),
        tube(1.3, -9.8, -9.0, 8.7, BELT, "detail", M, "intake lip"),
        tube(1.3, -5.0, -3.9, 8.7, BELT, "thrust", M, "jet"),
        box(8.6, 8.8, 3.2, 4.5, -6.8, -4.8, "primary", M, "tip finlet"),
        ramp(8.6, 8.8, 3.2, 4.5, -8.4, -6.8, "primary", "up", M),
    ]


def s_strakes():
    """Harbour. A drooping winglet down to a long float jet with a lift slot under it."""
    return [
        box(SI, 7.7, 2.1, 2.7, -12.2, -8.8, "detail", M, "mount on the outer rail"),
        P("block", [0.25, 3.6, 4.6], [8.3, 0.75, -10.5], "secondary", [0, 0, 25], M, "drooping strake"),
        tube(1.2, -13.6, -7.4, 8.95, -0.9, "primary", M, "float jet"),
        tube(0.9, -14.1, -13.4, 8.95, -0.9, "detail", M, "intake"),
        tube(1.0, -7.7, -6.7, 8.95, -0.9, "thrust", M, "jet"),
        box(8.5, 9.4, -1.6, -1.48, -12.6, -8.6, "thrust", M, "lift slot, points down"),
    ]


def s_skyfins():
    """Atomic. An upswept canted fin with a pointed rocket pod on its tip, and a lift jet under the root."""
    return [
        box(SI, 7.7, 2.1, 2.7, -12.2, -8.8, "detail", M, "mount on the outer rail"),
        P("block", [0.3, 3.4, 4.0], [8.15, 4.0, -10.0], "secondary", [0, 0, -22], M, "upswept fin"),
        tube(1.5, -13.0, -7.2, 8.8, 5.95, "primary", M, "tip rocket pod"),
        tube(1.0, -14.0, -12.8, 8.8, 5.95, "secondary", M, "nose cone"),
        tube(0.5, -14.7, -13.8, 8.8, 5.95, "neon", M, "nose tip"),
        tube(1.1, -7.5, -6.4, 8.8, 5.95, "thrust", M, "jet"),
        post(1.3, 0.4, 2.1, 8.2, -10.5, "primary", M, "lift jet barrel under the fin root"),
        post(1.1, -0.4, 0.5, 8.2, -10.5, "thrust", M, "jet, points down"),
    ]


# --------------------------------------------------------------------------- FrontBumper: nose pieces on the nose collar
# Every engine ends in the same 2.2 square collar, and every nose piece is sized to it.
NZ = E_Z0 - 0.05   # rear face of every nose piece


def f_spike():
    """Works. A long shock cone."""
    return [
        tube(1.6, -17.1, NZ, EX, EY, "detail", M, "base on the nose collar"),
        tube(1.1, -17.7, -17.0, EX, EY, "primary", M),
        tube(0.7, -18.2, -17.6, EX, EY, "secondary", M),
        tube(0.35, -18.45, -18.1, EX, EY, "neon", M, "tip"),
    ]


def f_filter():
    """Desert. A square louvred filter box with a chisel prow. No round parts."""
    parts = [
        box(EX - 0.9, EX + 0.9, EY - 0.9, EY + 0.9, -16.4, NZ, "detail", M, "base on the nose collar"),
        box(EX - 1.1, EX + 1.1, EY - 1.1, EY + 1.1, -17.7, -16.4, "secondary", M, "filter box"),
        ramp(EX - 1.1, EX + 1.1, EY, EY + 1.1, -18.4, -17.7, "primary", "up", M, "chisel prow, upper"),
        ramp(EX - 1.1, EX + 1.1, EY - 1.1, EY, -18.4, -17.7, "primary", "chin", M, "chisel prow, lower"),
    ]
    for dy in (-0.75, -0.15, 0.45):
        parts += [box(EX + 1.1, EX + 1.2, EY + dy, EY + dy + 0.3, -17.5, -16.6, "detail", M, "louvre"),
                  box(EX - 1.2, EX - 1.1, EY + dy, EY + dy + 0.3, -17.5, -16.6, "detail", M, "louvre")]
    return parts


def f_cage():
    """Scrapyard. A welded ram cage, the size of the collar."""
    return [
        tube(1.4, -16.8, NZ, EX, EY, "detail", M, "boss on the nose collar"),
        P("block", [0.25, 3.2, 0.25], [EX, EY, -16.95], "detail", [0, 0, 45], M, "cross brace"),
        P("block", [0.25, 3.2, 0.25], [EX, EY, -16.95], "detail", [0, 0, -45], M, "cross brace"),
        box(EX - 1.3, EX + 1.3, EY + 1.05, EY + 1.3, -17.7, -16.8, "secondary", M, "cage top"),
        box(EX - 1.3, EX + 1.3, EY - 1.3, EY - 1.05, -17.7, -16.8, "secondary", M, "cage bottom"),
        box(EX - 1.3, EX - 1.05, EY - 1.05, EY + 1.05, -17.7, -16.8, "secondary", M, "cage side"),
        box(EX + 1.05, EX + 1.3, EY - 1.05, EY + 1.05, -17.7, -16.8, "secondary", M, "cage side"),
        box(EX - 1.6, EX + 1.6, EY - 0.25, EY + 0.25, -18.3, -17.7, "primary", M, "ram bar"),
    ]


def f_lances():
    """Showboat. Two long chrome lances on a fork."""
    return [
        tube(1.4, -16.7, NZ, EX, EY, "detail", M, "boss on the nose collar"),
        box(EX - 0.2, EX + 0.2, EY - 1.2, EY + 1.2, -16.7, -16.3, "detail", M, "fork"),
        tube(0.5, -18.2, -16.2, EX, EY + 1.0, "secondary", M, "upper lance"),
        tube(0.5, -18.2, -16.2, EX, EY - 1.0, "secondary", M, "lower lance"),
        ball(0.6, EX, EY + 1.0, -18.15, "neon", M),
        ball(0.6, EX, EY - 1.0, -18.15, "neon", M),
    ]


def f_cutwater():
    """Harbour. A knife-edged bow blade with a flat arrowhead across it."""
    return [
        tube(1.4, -16.6, NZ, EX, EY, "detail", M, "boss on the nose collar"),
        fin(EX, EX + 0.45, 1.1, 3.7, -18.4, -16.5, "primary", "front", M, "bow blade"),
        fin(EX, EX - 0.45, 1.1, 3.7, -18.4, -16.5, "primary", "front", M, "bow blade"),
        fin(EX, EX + 1.3, 2.28, 2.52, -18.0, -16.4, "secondary", "front", M, "arrowhead"),
        fin(EX, EX - 1.3, 2.28, 2.52, -18.0, -16.4, "secondary", "front", M, "arrowhead"),
        box(EX - 0.07, EX + 0.07, 1.3, 3.5, -18.45, -18.3, "neon", M, "edge light"),
    ]


def f_bullets():
    """Atomic. A chrome bumper bar with two pointed bullets."""
    parts = [
        box(EX - 0.8, EX + 0.8, EY - 0.6, EY + 0.6, -16.5, NZ, "detail", M, "bracket on the nose collar"),
        box(EX - 1.6, EX + 1.6, EY - 0.3, EY + 0.3, -16.9, -16.4, "secondary", M, "chrome bumper bar"),
    ]
    for dx in (-0.95, 0.95):
        parts += [
            tube(0.9, -17.8, -16.8, EX + dx, EY, "secondary", M, "bullet"),
            tube(0.55, -18.2, -17.7, EX + dx, EY, "primary", M, "bullet point"),
            ball(0.5, EX + dx, EY, -18.2, "neon", M),
        ]
    return parts


# --------------------------------------------------------------------------- Engine2: pod thruster on the transom
TZ = POD_Z1 + 0.05   # front face of every pod thruster


def t_mono():
    """Works. One big round turbine with a chin scoop."""
    return [
        box(-1.1, 1.1, 0.4, 2.6, TZ, 14.9, "detail", note="collar on the transom"),
        tube(2.6, 14.8, 17.2, 0, 1.5, "secondary", note="turbine body"),
        box(-0.7, 0.7, -0.35, 0.5, 15.0, 16.6, "primary", note="chin scoop"),
        box(-0.55, 0.55, -0.25, 0.2, 14.86, 15.04, "detail", note="scoop intake face"),
        ramp(-0.7, 0.7, -0.35, 0.5, 16.6, 17.6, "primary", "tuck"),
        tube(2.1, 16.8, 18.1, 0, 1.5, "detail", note="nozzle"),
        tube(1.6, 17.4, 18.45, 0, 1.5, "thrust", note="jet"),
    ]


def t_twin():
    """Desert. Two nacelles on a solid stub wing."""
    return [
        box(-1.2, 1.2, 1.0, 2.0, TZ, 14.9, "detail", note="collar on the transom"),
        box(-2.0, 2.0, 1.25, 1.75, 14.8, 16.4, "secondary", note="solid stub wing"),
        fin(0.6, 2.0, 1.25, 1.75, 16.4, 17.4, "secondary", "rear", M, "wing trailing edge"),
        tube(1.7, 14.9, 17.8, 2.7, 1.5, "primary", M, "nacelle"),
        tube(1.3, 14.7, 15.5, 2.7, 1.5, "detail", M, "intake"),
        tube(1.3, 17.4, 18.2, 2.7, 1.5, "detail", M, "nozzle"),
        tube(1.1, 17.8, 18.45, 2.7, 1.5, "thrust", M, "jet"),
        box(3.55, 3.7, 1.5, 2.9, 16.4, 17.8, "secondary", M, "tip fin"),
        ramp(3.55, 3.7, 1.5, 2.9, 15.2, 16.4, "secondary", "up", M),
    ]


def t_skid():
    """Scrapyard. A box-section duct jet with a top scoop, side fences and a tall glowing slot."""
    return [
        box(-1.2, 1.2, 0.5, 1.6, TZ, 14.8, "detail", note="collar on the transom"),
        box(-1.95, 1.95, 0.0, 1.7, 14.8, 17.4, "secondary", note="box-section duct, 1.7 high"),
        ramp(-1.3, 1.3, 1.7, 2.8, 15.0, 17.2, "primary", "down", note="top scoop"),
        box(-1.1, 1.1, 1.85, 2.65, 14.86, 15.06, "detail", note="scoop intake face, looks forward"),
        box(-1.8, 1.8, 0.15, 1.55, 17.4, 17.9, "detail", note="slot nozzle"),
        box(-1.6, 1.6, 0.35, 1.35, 17.7, 18.2, "thrust", note="jet, 1 stud tall"),
        box(1.95, 2.2, -0.3, 2.1, 15.6, 18.4, "primary", M, "side fence"),
        ramp(1.95, 2.2, -0.3, 2.1, 14.7, 15.6, "primary", "up", M),
    ]


def t_pipes():
    """Showboat. Four organ pipes in a high row, the inner pair longer."""
    parts = [box(-3.0, 3.0, 1.9, 2.7, TZ, 15.1, "detail", note="manifold on the transom"),
             box(0.3, 1.3, 2.7, 2.95, 14.62, 15.4, "secondary", M, "ram scoop"),
             box(0.35, 1.25, 2.72, 2.93, 14.55, 14.64, "detail", M, "intake face")]
    for x, z1 in ((0.75, 17.8), (2.25, 16.9)):
        parts += [
            tube(1.0, 14.8, z1, x, 2.3, "secondary", M, "pipe"),
            tube(1.3, z1 - 0.8, z1 + 0.3, x, 2.3, "primary", M, "flared tip"),
            tube(1.0, z1, z1 + 0.65, x, 2.3, "thrust", M, "jet"),
        ]
    return parts


def t_outboard():
    """Harbour. A boat outboard: powerhead on top, slim leg, long torpedo jet down low."""
    return [
        box(-0.7, 0.7, 0.6, 2.4, TZ, 14.9, "detail", note="bracket on the transom"),
        box(-0.8, 0.8, 1.7, 2.9, 14.9, 16.6, "primary", note="powerhead"),
        ramp(-0.8, 0.8, 1.7, 2.9, 16.6, 17.4, "primary", "down"),
        box(-0.6, 0.6, 2.9, 3.0, 15.1, 16.3, "detail", note="intake grille"),
        box(-0.25, 0.25, 0.6, 1.7, 15.3, 16.3, "secondary", note="leg"),
        tube(1.3, 14.9, 18.0, 0, 0.4, "secondary", note="torpedo jet"),
        box(-1.2, 1.2, 1.05, 1.2, 15.8, 17.8, "detail", note="plate"),
        tube(1.0, 17.7, 18.45, 0, 0.4, "thrust", note="jet"),
    ]


def t_swallow():
    """Atomic. Two rocket pipes that splay out and up from a pointed centre body, like a swallow tail."""
    a, b = (0.8, 1.2, 15.1), (2.3, 2.0, 17.6)
    return [
        box(-1.1, 1.1, 0.5, 2.5, TZ, 15.0, "detail", note="collar on the transom"),
        tube(1.9, 14.9, 16.4, 0, 1.5, "secondary", note="centre body"),
        tube(1.2, 16.2, 17.3, 0, 1.5, "primary", note="tail cone"),
        tube(0.6, 17.1, 18.0, 0, 1.5, "neon", note="tail spike"),
        box(-0.5, 0.5, 2.3, 2.9, 14.9, 16.0, "primary", note="dorsal scoop"),
        box(-0.4, 0.4, 2.4, 2.8, 14.78, 14.95, "detail", note="intake face"),
        rod(a, b, 1.3, "primary", M, "splayed rocket pipe"),
        rod(along(a, b, 0.62), along(a, b, 1.0), 1.5, "detail", M, "nozzle"),
        rod(along(a, b, 0.9), along(a, b, 1.14), 1.1, "thrust", M, "jet"),
    ]


# --------------------------------------------------------------------------- SidePods: binder and cables
SX = E_X0 - 0.05      # outer face of every shackle (the inner rail starts at 2.65)
CZ = HITCH_Z - 0.05   # rear face of every clevis (the hitch bar starts at 5.05)


def _shackle(z=CABLE_Z):
    return box(2.0, SX, 2.05, 2.75, z - 0.45, z + 0.45, "detail", M, "shackle meets the inner rail")


def _emitter(z=BINDER_Z, y0=1.8, y1=3.0):
    return box(2.0, SX, y0, y1, z - 0.6, z + 0.6, "detail", M, "binder emitter meets the inner rail")


def c_twin_cable():
    """Desert. Two tow cables, one to each engine, and a single straight binder beam."""
    a, b = (1.2, BELT, 4.5), (2.25, BELT, CABLE_Z)
    return [
        box(0.9, 1.5, 2.1, 2.7, 4.45, CZ, "detail", M, "clevis on the hitch bar"),
        rod(a, b, 0.3, "detail", M, "tow cable"),
        rod(along(a, b, 0.30), along(a, b, 0.36), 0.6, "secondary", M, "coupler"),
        rod(along(a, b, 0.66), along(a, b, 0.72), 0.6, "secondary", M, "coupler"),
        _shackle(),
        rod((0.7, 2.05, 4.5), (2.1, 2.05, BINDER_Z + 0.3), 0.16, "detail", M, "control line"),
        _emitter(),
        xbar(0.6, -2.0, 2.0, BELT, BINDER_Z, "neon", note="energy binder"),
        ball(1.1, 0, BELT, BINDER_Z, "neon"),
        ball(0.9, 1.2, BELT, BINDER_Z, "neon", M),
    ]


def c_rigid_boom():
    """Scrapyard. A welded spine and wishbone with the binder inside a truss."""
    return [
        box(-1.0, 1.0, 1.8, 3.0, 4.35, CZ, "detail", note="socket on the hitch bar"),
        box(-0.45, 0.45, 1.95, 2.85, -1.4, 4.35, "secondary", note="spine"),
        P("block", [1.6, 1.0, 1.6], [0, BELT, -1.6], "detail", [0, 45, 0], note="fork node"),
        ball(0.9, 0, 3.0, -1.6, "neon"),
        beam((0.3, BELT, -1.8), (2.0, BELT, -8.7), 0.7, 0.7, "secondary", M, "wishbone arm"),
        box(2.0, SX, 1.95, 2.85, -9.6, -8.4, "detail", M, "arm pad meets the inner rail"),
        box(-0.25, 0.25, 2.15, 2.65, -11.7, -2.2, "detail", note="centre strut"),
        rod((0.2, BELT, -7.6), (2.1, BELT, -11.5), 0.3, "detail", M, "diagonal brace"),
        xbar(0.3, -2.2, 2.2, 3.0, BINDER_Z, "detail", note="truss rail"),
        xbar(0.3, -2.2, 2.2, 1.8, BINDER_Z, "detail", note="truss rail"),
        box(0.9, 1.15, 1.8, 3.0, -12.12, -11.88, "detail", M),
        box(2.2, SX, 1.5, 3.3, -12.4, -11.6, "detail", M, "end plate meets the inner rail"),
        xbar(0.6, -2.2, 2.2, BELT, BINDER_Z, "neon", note="energy binder inside the truss"),
    ]


def c_arc():
    """Works. One tether to a bridle, and a binder that arcs high between the engines."""
    pts = [(2.1, 2.7, BINDER_Z), (1.8, 3.9, BINDER_Z), (1.1, 4.7, BINDER_Z), (0.0, 5.0, BINDER_Z)]
    parts = [
        box(-0.6, 0.6, 2.0, 2.8, 4.45, CZ, "detail", note="swivel on the hitch bar"),
        tube(0.45, -1.2, 4.45, 0, BELT, "detail", note="single tether"),
        P("block", [1.3, 0.5, 1.3], [0, BELT, -1.4], "detail", [0, 45, 0], note="bridle node"),
        ball(0.9, 0, BELT + 0.3, -1.4, "neon"),
        rod((0.2, BELT, -1.6), (2.25, BELT, CABLE_Z), 0.3, "detail", M, "bridle cable"),
        _shackle(),
        _emitter(),
        rod((0, 2.7, -1.5), (0, 4.9, BINDER_Z), 0.16, "detail", note="stay wire to the arc crown"),
        ball(0.7, 0, 5.0, BINDER_Z, "detail", note="arc crown node"),
    ]
    for i in range(3):
        parts.append(rod(pts[i], pts[i + 1], 0.45, "neon", M, "energy arc segment"))
    parts += [ball(0.7, pts[1][0], pts[1][1], BINDER_Z, "neon", M), ball(0.7, pts[2][0], pts[2][1], BINDER_Z, "neon", M)]
    return parts


def c_cross():
    """Showboat. Crossed reins with a jewel at the crossing, and a double binder."""
    a, b = (1.2, BELT, 4.5), (-2.25, BELT, CABLE_Z)
    mid = along(a, b, 1.2 / 3.45)
    return [
        box(0.9, 1.5, 2.1, 2.7, 4.45, CZ, "detail", M, "clevis on the hitch bar"),
        rod(a, b, 0.3, "detail", M, "crossed rein"),
        ball(1.3, 0, BELT, mid[2], "secondary", note="jewel at the crossing"),
        ball(0.7, 0, BELT + 0.6, mid[2], "neon"),
        _shackle(),
        box(2.0, SX, 1.1, 3.7, BINDER_Z - 0.4, BINDER_Z + 0.4, "detail", M, "emitter post meets the inner rail"),
        xbar(0.45, -2.0, 2.0, 3.3, BINDER_Z, "neon", note="upper binder"),
        xbar(0.45, -2.0, 2.0, 1.5, BINDER_Z, "neon", note="lower binder"),
        ball(0.8, 1.0, 3.3, BINDER_Z, "neon", M),
        ball(0.8, 0, 1.5, BINDER_Z, "neon"),
    ]


def c_wing():
    """Harbour. A centre boom to a delta cross-deck, like a catamaran. Short binder at the front."""
    return [
        box(-0.5, 0.5, 2.0, 2.8, 4.35, CZ, "detail", note="socket on the hitch bar"),
        box(-0.3, 0.3, 2.15, 2.65, -9.0, 4.35, "secondary", note="centre boom"),
        box(-2.0, 2.0, 2.25, 2.55, -10.2, -8.4, "primary", note="cross-deck"),
        fin(0, 2.0, 2.25, 2.55, -11.8, -10.2, "primary", "front", M, "swept leading edge"),
        box(2.0, SX, 2.0, 2.8, -10.2, -8.4, "detail", M, "deck pad meets the inner rail"),
        box(-0.5, 0.5, 2.55, 2.75, -10.0, -8.6, "secondary", note="deck stripe"),
        box(2.0, SX, 1.9, 2.9, -12.7, -11.9, "detail", M, "binder emitter meets the inner rail"),
        xbar(0.5, -2.0, 2.0, BELT, -12.3, "neon", note="energy binder"),
    ]


def c_spreader():
    """Atomic. One tether to a wide spreader bar, two straight tow lines, and a chevron binder that points forward."""
    return [
        box(-0.6, 0.6, 2.0, 2.8, 4.45, CZ, "detail", note="swivel on the hitch bar"),
        tube(0.45, 0.1, 4.45, 0, BELT, "detail", note="single tether"),
        box(-2.1, 2.1, 2.2, 2.6, -0.6, 0.2, "secondary", note="spreader bar"),
        box(2.1, 2.5, 2.05, 2.75, -0.8, 0.4, "detail", M, "bar end"),
        rod((0.2, BELT, 4.3), (2.1, BELT, 0.3), 0.2, "detail", M, "bridle stay"),
        ball(0.8, 0, BELT + 0.3, -0.2, "neon"),
        rod((2.25, BELT, -0.6), (2.25, BELT, -8.6), 0.3, "detail", M, "straight tow line"),
        _shackle(),
        _emitter(),
        rod((2.0, BELT, BINDER_Z), (0, BELT, -15.0), 0.5, "neon", M, "chevron binder"),
        ball(1.0, 0, BELT, -15.0, "neon", note="binder apex"),
    ]


# --------------------------------------------------------------------------- RearBumper: pod tail under the belly pad
RY = SILL - 0.05   # top face of every pod tail


def r_skid():
    """Desert. Twin landing runners."""
    return [
        box(1.0, 1.5, -1.55, -1.25, 7.4, 15.6, "secondary", M, "runner"),
        ramp(1.0, 1.5, -1.55, -0.85, 6.0, 7.4, "secondary", "chin", M, "upturned tip"),
        box(1.1, 1.4, -1.25, RY, 9.6, 10.0, "detail", M, "strut to the belly pad"),
        box(1.1, 1.4, -1.25, RY, 12.6, 13.0, "detail", M, "strut to the belly pad"),
    ]


def r_rudder():
    """Works. One ventral rudder blade at the back."""
    return [
        box(-0.4, 0.4, -0.75, RY, 11.4, 13.4, "detail", note="pivot on the belly pad"),
        ramp(-0.15, 0.15, -1.55, -0.75, 11.0, 13.2, "secondary", "chin", note="swept leading edge"),
        box(-0.15, 0.15, -1.55, -0.75, 13.2, 17.4, "secondary", note="rudder blade"),
        box(-0.2, 0.2, -1.6, -1.5, 13.4, 17.2, "neon"),
    ]


def r_chute():
    """Scrapyard. A strapped brake-chute pack and a drag hook."""
    return [
        box(-1.3, 1.3, -1.45, RY, 10.8, 13.2, "secondary", note="chute pack on the belly pad"),
        box(0.6, 0.9, -1.55, RY, 10.7, 13.3, "detail", M, "strap"),
        rod((0, -0.9, 13.2), (0, -1.2, 17.4), 0.3, "detail", note="drag hook arm"),
        box(-0.5, 0.5, -1.55, -1.05, 17.2, 18.0, "primary", note="hook"),
    ]


def r_glowkeel():
    """Showboat. A long centre keel with a glow tube along each side."""
    return [
        box(-0.35, 0.35, -1.3, RY, 9.4, 15.0, "primary", note="keel on the belly pad"),
        ramp(-0.35, 0.35, -1.3, RY, 7.6, 9.4, "primary", "chin"),
        ramp(-0.35, 0.35, -1.3, RY, 15.0, 16.8, "primary", "tuck"),
        box(0.5, 0.8, -1.1, -0.8, 8.6, 15.6, "neon", M, "glow tube"),
        box(0.35, 0.5, -1.05, -0.85, 9.8, 10.2, "detail", M),
        box(0.35, 0.5, -1.05, -0.85, 13.0, 13.4, "detail", M),
    ]


def r_foil():
    """Harbour. A swept V foil on thin raked struts, with drooped tips and a small aft foil."""
    return [
        box(1.0, 1.3, -0.75, RY, 9.6, 10.4, "detail", M, "strut root on the belly pad"),
        beam((1.15, -0.75, 10.0), (1.15, -1.35, 11.6), 0.12, 0.45, "detail", M, "thin strut, raked back"),
        fin(0, 2.3, -1.45, -1.3, 10.6, 12.6, "primary", "front", M, "swept V foil"),
        P("block", [0.7, 0.12, 1.0], [2.55, -1.42, 12.1], "secondary", [0, 0, -16], M, "drooped tip"),
        box(-0.2, 0.2, -0.75, RY, 12.6, 13.2, "detail", note="aft strut root"),
        beam((0, -0.75, 13.0), (0, -1.35, 14.4), 0.12, 0.4, "detail", note="aft strut, raked back"),
        box(-1.2, 1.2, -1.5, -1.38, 14.0, 14.9, "secondary", note="aft foil"),
    ]


def r_tanks():
    """Atomic. Two pointed drop tanks on short pylons."""
    return [
        box(1.0, 1.4, -1.0, RY, 10.4, 12.4, "detail", M, "pylon on the belly pad"),
        box(1.3, 1.7, -1.15, -0.85, 10.6, 12.2, "detail", M, "stub"),
        tube(0.9, 9.0, 13.6, 2.1, -1.0, "secondary", M, "drop tank"),
        tube(0.5, 8.3, 9.2, 2.1, -1.0, "primary", M, "tank nose"),
        tube(0.5, 13.4, 14.3, 2.1, -1.0, "neon", M, "tank tail light"),
    ]


# --------------------------------------------------------------------------- RearSpoiler: pod fins on the tail deck
WY = DECK_Y + 0.05   # bottom face of every fin set


def w_twin():
    """Desert. Two short canted fins."""
    return [
        box(1.0, 1.6, WY, 3.3, 12.8, 14.3, "detail", M, "foot on the tail deck"),
        ramp(1.55, 1.85, 3.3, 6.0, 12.9, 14.6, "primary", "up", M, "canted fin", roll=-18),
        box(1.55, 1.85, 3.3, 6.0, 14.6, 16.6, "primary", M, rot=[0, 0, -18]),
        P("block", [0.36, 0.3, 2.0], [2.15, 5.95, 15.6], "neon", [0, 0, -18], M),
    ]


def w_tall():
    """Works. One tall swept fin with a T-plane."""
    return [
        box(-0.6, 0.6, WY, 3.4, 12.8, 14.4, "detail", note="plinth on the tail deck"),
        ramp(-0.2, 0.2, 3.4, 6.4, 13.0, 15.6, "primary", "up", note="swept fin"),
        box(-0.2, 0.2, 3.4, 6.4, 15.6, 17.2, "primary"),
        box(-1.7, 1.7, 6.4, 6.6, 15.4, 17.4, "secondary", note="T-plane"),
        box(-0.25, 0.25, 6.6, 6.8, 15.8, 17.2, "neon"),
    ]


def w_plank():
    """Scrapyard. A wide flat plank wing on two posts."""
    return [
        box(1.1, 1.4, WY, 5.0, 13.4, 13.8, "detail", M, "post on the tail deck"),
        rod((1.25, 3.3, 12.9), (1.25, 4.9, 14.6), 0.2, "detail", M, "brace"),
        box(-4.2, 4.2, 5.0, 5.3, 13.4, 15.6, "secondary", note="plank wing"),
        box(-4.0, 4.0, 5.3, 5.6, 15.3, 15.6, "detail", note="lip"),
        box(4.1, 4.45, 4.3, 6.0, 13.0, 16.2, "primary", M, "end plate"),
    ]


def w_horns():
    """Showboat. Two long raked horns that sweep up, out and back."""
    a, b = (1.3, 3.5, 13.4), (3.6, 6.0, 17.8)
    return [
        box(0.9, 1.6, WY, 3.35, 12.9, 14.3, "detail", M, "foot on the tail deck"),
        beam(a, b, 0.3, 1.1, "primary", M, "raked horn"),
        ball(0.6, b[0], b[1] + 0.3, b[2] + 0.1, "neon", M, "tip light"),
        beam((1.3, 3.5, 14.2), (2.3, 4.8, 16.4), 0.25, 0.6, "secondary", M, "under-blade"),
    ]


def w_sail():
    """Harbour. A long low dorsal sail that falls to the rear."""
    return [
        box(-0.5, 0.5, WY, 3.3, 12.8, 14.4, "detail", note="foot on the tail deck"),
        ramp(-0.2, 0.2, 3.3, 6.0, 12.9, 18.3, "primary", "down", note="dorsal sail"),
        box(-0.3, 0.3, 3.3, 3.6, 14.4, 18.45, "secondary", note="boom"),
        rod((0, 6.0, 12.95), (0, 3.7, 18.2), 0.22, "neon", note="edge light"),
    ]


def w_boom():
    """Atomic. A slim tail boom with a small tailplane and three fins at its far end."""
    return [
        box(-0.5, 0.5, WY, 3.35, 12.8, 14.3, "detail", note="foot on the tail deck"),
        box(-0.25, 0.25, 3.35, 3.8, 13.0, 18.2, "secondary", note="tail boom"),
        box(-1.8, 1.8, 3.8, 3.95, 17.0, 18.3, "primary", note="tailplane"),
        fin(0.25, 1.8, 3.8, 3.95, 15.8, 17.0, "primary", "front", M, "swept tailplane root"),
        box(1.7, 1.85, 3.3, 5.0, 17.2, 18.3, "primary", M, "end fin"),
        ramp(1.7, 1.85, 3.95, 5.0, 16.2, 17.2, "primary", "up", M),
        ramp(-0.12, 0.12, 3.8, 5.6, 15.6, 17.4, "primary", "up", note="centre fin"),
        box(-0.12, 0.12, 3.8, 5.6, 17.4, 18.3, "primary"),
        box(-0.18, 0.18, 5.6, 5.85, 17.4, 18.3, "neon"),
    ]


# --------------------------------------------------------------------------- assembly
def mod(name, culture, parts):
    return {"name": name, "culture": culture, "parts": parts}


STANDARD = {
    "cockpitEnvelope": [
        {"min": [-POD_X, SILL, HITCH_Z], "max": [POD_X, CAB_Y1, CAB_Z1]},
        {"min": [-POD_X, SILL, CAB_Z1], "max": [POD_X, DECK_Y, POD_Z1]},
    ],
    "datums": {"beltline": BELT, "sill": SILL, "hoverPlane": HOVER, "engineAxisX": EX, "engineAxisY": EY,
               "hitchPlaneZ": HITCH_Z, "transomPlaneZ": POD_Z1, "tailDeckY": DECK_Y,
               "binderStationZ": BINDER_Z, "cableStationZ": CABLE_Z},
    "slots": {
        "SidePods": {"label": "Binder and Cables",
                     "envelope": {"min": [-E_X0, -0.6, E_Z0], "max": [E_X0, 5.4, HITCH_Z]},
                     "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 4, 0]},
        "Engine1": {"label": "Tow Engines",
                    "envelope": {"min": [E_X0, E_Y0, E_Z0], "max": [E_X1, E_Y1, E_Z1], "mirror": True},
                    "anchor": {"to": "SidePods", "face": "-x"}, "explode": [4, 0, -3]},
        "FrontBumper": {"label": "Nose Pieces",
                        "envelope": {"min": [E_X0, E_Y0, NOSE_Z], "max": [E_X1, E_Y1, E_Z0], "mirror": True},
                        "anchor": {"to": "Engine1", "face": "+z"}, "explode": [4, 0, -8]},
        "Boost": {"label": "Afterburners",
                  "envelope": {"min": [E_X0, E_Y1, BOOST_Z0], "max": [E_X1, TOP, BOOST_Z1], "mirror": True},
                  "anchor": {"to": "Engine1", "face": "-y"}, "explode": [4, 5, -1]},
        "Stabilisers": {"label": "Engine Vanes",
                        "envelope": {"min": [E_X1, LOW, E_Z0], "max": [OUT_X, TOP, E_Z1], "mirror": True},
                        "anchor": {"to": "Engine1", "face": "-x"}, "explode": [9, -2, -3]},
        "Engine2": {"label": "Pod Thruster",
                    "envelope": {"min": [-4.5, SILL, POD_Z1], "max": [4.5, DECK_Y, TAIL_Z]},
                    "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 0, 6]},
        "RearBumper": {"label": "Pod Tail",
                       "envelope": {"min": [-3, LOW, HITCH_Z], "max": [3, SILL, TAIL_Z]},
                       "anchor": {"to": "cockpit", "face": "+y"}, "explode": [0, -4, 0]},
        "RearSpoiler": {"label": "Pod Fins",
                        "envelope": {"min": [-4.5, DECK_Y, CAB_Z1], "max": [4.5, TOP, TAIL_Z]},
                        "anchor": {"to": "cockpit", "face": "-y"}, "explode": [0, 5, 3]},
    },
}

COCKPITS = {
    "bucket": {"name": "Bucket", "culture": "Scrapyard", "kit": "scrapyard", "parts": pod_bucket()},
    "sled": {"name": "Sled", "culture": "Desert", "kit": "desert", "parts": pod_sled()},
    "capsule": {"name": "Capsule", "culture": "Works", "kit": "works", "parts": pod_capsule()},
    "chariot": {"name": "Chariot", "culture": "Showboat", "kit": "showboat", "parts": pod_chariot()},
    "skiff": {"name": "Skiff", "culture": "Harbour", "kit": "harbour", "parts": pod_skiff()},
    "bubble": {"name": "Bubble", "culture": "Atomic", "kit": "atomic", "parts": pod_bubble()},
}

# In every slot the options are listed in kit order: Scrapyard, Desert, Works, Showboat, Harbour, Atomic.
MODULES = {
    "Engine1": {
        "quad_cluster": mod("Quad Cluster", "Scrapyard", e1_quad_cluster()),
        "fat_turbines": mod("Fat Turbines", "Desert", e1_fat_turbines()),
        "long_barrels": mod("Long Barrels", "Works", e1_long_barrels()),
        "bell_jets": mod("Bell Jets", "Showboat", e1_bells()),
        "twin_hulls": mod("Twin Hulls", "Harbour", e1_slabs()),
        "stack_jets": mod("Stack Jets", "Atomic", e1_stack()),
    },
    "Engine2": {
        "skid_jet": mod("Skid Jet", "Scrapyard", t_skid()),
        "twin": mod("Twin Nacelles", "Desert", t_twin()),
        "mono": mod("Mono Turbine", "Works", t_mono()),
        "organ_pipes": mod("Organ Pipes", "Showboat", t_pipes()),
        "outboard": mod("Outboard", "Harbour", t_outboard()),
        "swallow_tail": mod("Swallow Tail", "Atomic", t_swallow()),
    },
    "Stabilisers": {
        "outriggers": mod("Outrigger Jets", "Scrapyard", s_outriggers()),
        "petal_brakes": mod("Petal Brakes", "Desert", s_petals()),
        "blade_vanes": mod("Blade Vanes", "Works", s_blades()),
        "canard_jets": mod("Canard Jets", "Showboat", s_canards()),
        "hydro_strakes": mod("Hydro Strakes", "Harbour", s_strakes()),
        "sky_fins": mod("Sky Fins", "Atomic", s_skyfins()),
    },
    "Boost": {
        "bottle_rack": mod("Bottle Rack", "Scrapyard", b_bottles()),
        "can_burner": mod("Can Burner", "Desert", b_can()),
        "staged": mod("Staged Burner", "Works", b_staged()),
        "twin_trumpets": mod("Twin Trumpets", "Showboat", b_trumpets()),
        "slot_burner": mod("Slot Burner", "Harbour", b_slot()),
        "fin_rocket": mod("Fin Rocket", "Atomic", b_finrocket()),
    },
    "SidePods": {
        "rigid_boom": mod("Rigid Boom", "Scrapyard", c_rigid_boom()),
        "twin_cable": mod("Twin Cable", "Desert", c_twin_cable()),
        "arc_binder": mod("Arc Binder", "Works", c_arc()),
        "cross_reins": mod("Cross Reins", "Showboat", c_cross()),
        "tow_wing": mod("Tow Wing", "Harbour", c_wing()),
        "spreader_rig": mod("Spreader Rig", "Atomic", c_spreader()),
    },
    "FrontBumper": {
        "ram_cage": mod("Ram Cage", "Scrapyard", f_cage()),
        "sand_filter": mod("Sand Filter", "Desert", f_filter()),
        "shock_spike": mod("Shock Spike", "Works", f_spike()),
        "lances": mod("Lances", "Showboat", f_lances()),
        "cutwater": mod("Cutwater", "Harbour", f_cutwater()),
        "twin_bullets": mod("Twin Bullets", "Atomic", f_bullets()),
    },
    "RearBumper": {
        "chute_pack": mod("Chute Pack", "Scrapyard", r_chute()),
        "skid": mod("Skid", "Desert", r_skid()),
        "rudder": mod("Rudder", "Works", r_rudder()),
        "glow_keel": mod("Glow Keel", "Showboat", r_glowkeel()),
        "hydrofoil": mod("Hydrofoil", "Harbour", r_foil()),
        "drop_tanks": mod("Drop Tanks", "Atomic", r_tanks()),
    },
    "RearSpoiler": {
        "plank_wing": mod("Plank Wing", "Scrapyard", w_plank()),
        "twin_fins": mod("Twin Fins", "Desert", w_twin()),
        "tall_fin": mod("Tall Fin", "Works", w_tall()),
        "swept_horns": mod("Swept Horns", "Showboat", w_horns()),
        "dorsal_sail": mod("Dorsal Sail", "Harbour", w_sail()),
        "tail_boom": mod("Tail Boom", "Atomic", w_boom()),
    },
}

SLOT_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost", "SidePods", "FrontBumper", "RearBumper", "RearSpoiler"]


def kit(name, culture, index):
    """A signature kit takes the module at the same index in every slot."""
    return {"name": name, "culture": culture,
            "modules": {s: list(MODULES[s].keys())[index] for s in SLOT_ORDER}}


KITS = {
    "scrapyard": kit("Scrapyard", "Scrapyard", 0),
    "desert": kit("Desert", "Desert", 1),
    "works": kit("Works", "Works", 2),
    "showboat": kit("Showboat", "Showboat", 3),
    "harbour": kit("Harbour", "Harbour", 4),
    "atomic": kit("Atomic", "Atomic", 5),
}

PAINT = {
    "bucket": {"primary": "#6f7a55", "secondary": "#c2532a", "neon": "#ffd23d"},
    "sled": {"primary": "#d9772b", "secondary": "#efe3c2", "neon": "#c46bff"},
    "capsule": {"primary": "#1f5fd6", "secondary": "#f2f2f2", "neon": "#6ff2ff"},
    "chariot": {"primary": "#c9132f", "secondary": "#e9c84a", "neon": "#ff4df0"},
    "skiff": {"primary": "#0f8f8a", "secondary": "#f4f1e6", "neon": "#ffb347"},
    "bubble": {"primary": "#58c7b0", "secondary": "#f3efe2", "neon": "#ff5a4d"},
}

SWAPS = {"bucket": "works", "sled": "showboat", "capsule": "scrapyard", "chariot": "harbour", "skiff": "atomic",
         "bubble": "desert"}

BUILDS = []
for n, cid in enumerate(COCKPITS):
    own = COCKPITS[cid]["kit"]
    BUILDS.append({"name": "%02d %s native %s kit" % (2 * n + 1, COCKPITS[cid]["name"], KITS[own]["name"]),
                   "cockpit": cid, "kit": own, "paint": PAINT[cid]})
    BUILDS.append({"name": "%02d %s swap %s kit" % (2 * n + 2, COCKPITS[cid]["name"], KITS[SWAPS[cid]]["name"]),
                   "cockpit": cid, "kit": SWAPS[cid], "paint": PAINT[cid]})
# Mixed builds. With the native builds they put every nose piece and every boost on both a slim and a fat engine.
BUILDS += [
    {"name": "13 Mixed Sled slim cage bottles", "cockpit": "sled", "kit": "desert",
     "modules": {"Engine1": "long_barrels", "FrontBumper": "ram_cage", "Boost": "bottle_rack", "Stabilisers": "canard_jets"},
     "paint": {"primary": "#2fa36b", "secondary": "#e9ecef", "neon": "#b6ff3d"},
     "note": "Slim Long Barrels with the Scrapyard cage and bottle rack"},
    {"name": "14 Mixed Bubble slim filter can", "cockpit": "bubble", "kit": "atomic",
     "modules": {"Engine1": "long_barrels", "FrontBumper": "sand_filter", "Boost": "can_burner", "Engine2": "mono"},
     "paint": {"primary": "#f0f0f2", "secondary": "#ff6a1f", "neon": "#7a5cff"},
     "note": "Slim Long Barrels with the Desert filter and can burner"},
    {"name": "15 Mixed Capsule fat spike staged", "cockpit": "capsule", "kit": "works",
     "modules": {"Engine1": "fat_turbines", "SidePods": "rigid_boom", "Engine2": "organ_pipes"},
     "paint": {"primary": "#3a2d6b", "secondary": "#d8d2c0", "neon": "#59ffa0"},
     "note": "Fat Turbines with the Works spike and staged burner"},
    {"name": "16 Mixed Chariot fat lances trumpets", "cockpit": "chariot", "kit": "showboat",
     "modules": {"Engine1": "fat_turbines", "Stabilisers": "outriggers", "SidePods": "arc_binder"},
     "paint": {"primary": "#222831", "secondary": "#d9a521", "neon": "#ff3b3b"},
     "note": "Fat Turbines with the Showboat lances and twin trumpets"},
    {"name": "17 Mixed Skiff bell cutwater slot", "cockpit": "skiff", "kit": "harbour",
     "modules": {"Engine1": "bell_jets", "Engine2": "twin", "RearSpoiler": "tall_fin"},
     "paint": {"primary": "#7a1f8a", "secondary": "#f1e9d2", "neon": "#3df2c9"},
     "note": "Slim Bell Jets with the Harbour cutwater and slot burner"},
    {"name": "18 Mixed Bucket fat bullets rocket", "cockpit": "bucket", "kit": "scrapyard",
     "modules": {"Engine1": "fat_turbines", "FrontBumper": "twin_bullets", "Boost": "fin_rocket", "Stabilisers": "sky_fins"},
     "paint": {"primary": "#b8442c", "secondary": "#d7d2c4", "neon": "#57d0ff"},
     "note": "Fat Turbines with the Atomic bullets, fin rocket and sky fins"},
]

SPEC = {
    "id": "tether",
    "displayName": "Tether",
    "tagline": "Pod racers: a pilot pod towed by two big jet engines on cables, joined by a glowing energy binder.",
    "standard": STANDARD,
    "cockpits": COCKPITS,
    "kits": KITS,
    "modules": MODULES,
    "builds": BUILDS,
}


# --------------------------------------------------------------------------- writer
def _flat(v):
    return not isinstance(v, (dict, list))


def _dump(obj, indent=0):
    """JSON with one part per line, so diffs stay readable."""
    pad = "  " * indent
    if isinstance(obj, dict):
        if "shape" in obj or "min" in obj or "to" in obj or all(_flat(v) for v in obj.values()):
            return json.dumps(obj)
        items = ["%s  %s: %s" % (pad, json.dumps(k), _dump(v, indent + 1)) for k, v in obj.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(obj, list):
        if not obj or all(_flat(v) for v in obj):
            return json.dumps(obj)
        items = ["%s  %s" % (pad, _dump(v, indent + 1)) for v in obj]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    return json.dumps(obj)


def _count(parts):
    return sum(2 if p.get("mirror") else 1 for p in parts)


def report(show_all=False):
    """Free-outline and whole-outline distinctness for every pair, closest first (uses the shared library)."""
    import sys
    sys.path.insert(0, os.path.join(HERE, ".."))
    import vbspec

    groups = [("Cockpit", {k: vbspec.expand_parts(v["parts"]) for k, v in COCKPITS.items()}, vbspec.DISTINCT_COCKPIT)]
    for s, mods in MODULES.items():
        groups.append((s, {k: vbspec.expand_parts(v["parts"]) for k, v in mods.items()},
                       vbspec.DISTINCT_BIG if s in vbspec.BIG_SLOTS else vbspec.DISTINCT_SMALL))
    for name, items, want in groups:
        table = sorted(vbspec.distinct_table(items).items(), key=lambda kv: kv[1][1])
        shown = table if show_all else table[:4]
        for (a, b), (free, raw) in shown:
            print("%-12s %-14s %-14s free %.2f (want %.2f)  whole %.2f" % (name, a, b, free, want, raw))


def main():
    import sys
    if "--report" in sys.argv:
        return report("--all" in sys.argv)
    text = _dump(SPEC) + "\n"
    json.loads(text)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote %s" % OUT)
    for b in BUILDS:
        mods = dict(KITS[b["kit"]]["modules"])
        mods.update(b.get("modules", {}))
        n = _count(COCKPITS[b["cockpit"]]["parts"]) + sum(_count(MODULES[s][m]["parts"]) for s, m in mods.items())
        print("  %-40s %3d parts" % (b["name"], n))


if __name__ == "__main__":
    main()
