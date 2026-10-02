"""Generator for the Dart frame-class blockout spec (round 2, after the second review). Design exploration only.

Run from the repo root:
  py -3 scripts/vehicle_blockouts/gen/dart.py
  py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/dart.json

Root space: +X right, +Y up, forward is -Z. Units are studs.
Everything is written from bounds (x0, x1, y0, y1, z0, z1) so the numbers below read like a drawing.
Parts whose note starts with PAD are the fixed hardpoints. Keep them where they are.
The generator ends with a self check of the class rules the shared validator does not know (see self_check).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "specs", "dart.json"))

# ---------------------------------------------------------------- datums
HOVER = -2.0      # ground
SILL = 0.0        # underside of the painted hull
AXIS = 1.3        # thrust axis and beltline: prow, ring frames and wings line up on it
DECK = 3.0        # top of the hull proper; canopy, roofline and dorsal features go above it
ROOF = 5.6        # top of the fuselage envelope
BELLY = -1.4      # bottom of the fuselage envelope: keels and ducts may hang this low
Z_TIP, Z_PROW, Z_FRONT, Z_REAR, Z_DRIVE = -17.0, -15.0, -8.0, 8.0, 14.5
HULL_X = 3.0      # hull half width, and the X of every flank hardpoint
PAD_X = 2.7       # inner face of the flank hardpoint plates
RING_X, RING_Y0, RING_Y1 = 1.5, 0.1, 2.5      # the ring frame: 3.0 x 2.4 at both seams
NECK_X, NECK_Y0, NECK_Y1 = 1.1, 0.35, 2.25    # smallest section allowed next to a seam: 2.2 x 1.9
ROOT = 1.5        # length of the painted root fairing on every prow and every drive
BOOST_Y = 3.2     # top of every drive: burner deck and fin pads
FIN_X0 = 2.4      # fin pads run X 2.4..3.0 on top of the hardpoint posts
BR_Z0, BR_Z1 = 10.8, 12.4   # burner deck station


# ---------------------------------------------------------------- part helpers
def _r(v):
    return round(float(v), 3)


def part(shape, size, pos, ch="primary", rot=None, m=False, note=None):
    p = {"shape": shape, "size": [_r(s) for s in size], "pos": [_r(v) for v in pos]}
    if rot and any(abs(a) > 1e-9 for a in rot):
        p["rot"] = [_r(a) for a in rot]
    p["ch"] = ch
    if m:
        p["mirror"] = True
    if note:
        p["note"] = note
    return p


def B(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None):
    """Block from bounds."""
    return part("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, None, m, note)


def RB(size, pos, rot, ch="primary", m=False, note=None):
    """Rotated block: size, centre, Roblox orientation."""
    return part("block", size, pos, ch, rot, m, note)


# Wedge kinds. Bounds are world bounds; the helper works out size and rotation.
#   up_back    ramp rising towards the tail (nose slope, windscreen)
#   up_front   ramp rising towards the nose (tail slope, fastback)
#   dn_back    underside, deep at the tail, thin at the nose (chin)
#   dn_front   underside, deep at the nose, thin at the tail (boat tail)
#   out_back   plan taper on the +X side: flat inboard edge, widest at the tail (swept leading edge)
#   out_front  plan taper on the +X side: flat inboard edge, widest at the nose
#   in_back    plan taper: flat outboard edge, widest at the tail
#   in_front   plan taper: flat outboard edge, widest at the nose (a barb)
#   slope_out  roof slope: tall inboard, thin outboard
#   under_out  V hull: deep inboard, thin outboard, flat on top
_WEDGE = {
    "up_back": ((0, 0, 0), "xyz"), "up_front": ((0, 180, 0), "xyz"),
    "dn_back": ((0, 0, 180), "xyz"), "dn_front": ((180, 0, 0), "xyz"),
    "out_back": ((0, 0, -90), "yxz"), "out_front": ((0, 180, 90), "yxz"),
    "in_back": ((0, 0, 90), "yxz"), "in_front": ((0, 180, -90), "yxz"),
    "slope_out": ((0, -90, 0), "zyx"), "under_out": ((0, -90, 180), "zyx"),
}


def W(kind, x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None):
    rot, order = _WEDGE[kind]
    d = {"x": x1 - x0, "y": y1 - y0, "z": z1 - z0}
    return part("wedge", [d[order[0]], d[order[1]], d[order[2]]],
                [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def RW(size, pos, rot, ch="primary", m=False, note=None):
    """Rotated wedge (fins): thin edge forward, tall edge aft, base down, then rotated."""
    return part("wedge", size, pos, ch, rot, m, note)


def CZ(d, x, y, z0, z1, ch="primary", m=False, note=None):
    return part("cyl_z", [d, d, z1 - z0], [x, y, (z0 + z1) / 2], ch, None, m, note)


def CY(d, x, z, y0, y1, ch="primary", m=False, note=None):
    return part("cyl_y", [d, y1 - y0, d], [x, (y0 + y1) / 2, z], ch, None, m, note)


def BALL(d, x, y, z, ch="primary", m=False, note=None):
    return part("ball", [d, d, d], [x, y, z], ch, None, m, note)


def jet(x, y, z0, z1, d, body="primary", lip="secondary", m=False, intake="mouth", tf=0.58, tag="jet"):
    """A jet along Z: dark intake mouth, lip, body, dark nozzle, glowing thrust. Always longer than wide.

    intake="spike" adds a stepped shock cone that sticks out 1.3 studs, so the face never reads as a flat disc.
    tf is the thrust diameter as a fraction of the body.
    """
    L = z1 - z0
    ll = max(0.5 * d, 0.22 * L)
    out = max(0.3 * d, 0.5)
    ps = [
        CZ(0.78 * d, x, y, z0, z0 + max(0.45 * d, 0.5), "detail", m, tag + " intake mouth"),
        CZ(d, x, y, z0 + 0.12, z0 + 0.12 + ll, lip, m, tag + " intake lip"),
        CZ(d, x, y, z0 + 0.12 + ll, z1 - out, body, m, tag + " body"),
        CZ(max(0.8 * d, tf * d + 0.2), x, y, z1 - out - max(0.2 * d, 0.2), z1 - 0.12, "detail", m, tag + " nozzle"),
        CZ(tf * d, x, y, z1 - 0.4, z1, "thrust", m, tag + " thrust"),
    ]
    if intake == "spike":
        ps += [
            CZ(0.46 * d, x, y, z0 - 0.5, z0 + 0.5, lip, m, tag + " shock cone"),
            CZ(0.22 * d, x, y, z0 - 1.3, z0 - 0.5, "detail", m, tag + " shock cone tip"),
        ]
    return ps


def lift_jet(x, z, y_top, y_bot, d, body="secondary", m=False, tag="lift jet", both=False):
    """A jet pointing down: forward intake slot, body, dark nozzle, glowing thrust underneath.

    both=True adds an upper nozzle, so the jet pushes up or down and its glow shows from above.
    """
    mid = (y_top + y_bot) / 2
    ps = [
        CY(d, x, z, y_bot + 0.5, y_top - (0.3 if both else 0.0), body, m, tag + " body"),
        B(x - 0.3, x + 0.3, mid - 0.2, mid + 0.6, z - d / 2 - 0.08, z - d / 2 + 0.25, "detail", m, tag + " intake slot"),
        CY(0.82 * d, x, z, y_bot + 0.12, y_bot + 0.5 + max(0.2 * d, 0.2), "detail", m, tag + " nozzle"),
        CY(0.66 * d, x, z, y_bot, y_bot + 0.35, "thrust", m, tag + " thrust"),
    ]
    if both:
        ps += [
            CY(0.82 * d, x, z, y_top - 0.5, y_top - 0.08, "detail", m, tag + " upper nozzle"),
            CY(0.64 * d, x, z, y_top - 0.2, y_top, "thrust", m, tag + " upper vent: glows upward"),
        ]
    return ps


def control_jet(x, y, z0, z1, d=1.0, m=True, top=True, side=True):
    """A small control jet along Z for the airbrakes: body 1.0 across, thrust 0.6. The bottom rung of the nozzle ladder.

    top and side add vents that glow upward and outboard.
    """
    ps = [
        CZ(d, x, y, z0, z1 - 0.4, "secondary", m, "control jet body"),
        CZ(0.7 * d, x, y, z0 - 0.25, z0 + 0.4, "detail", m, "control jet intake"),
        CZ(0.8 * d, x, y, z1 - 0.6, z1 - 0.1, "detail", m, "control jet nozzle"),
        CZ(0.6 * d, x, y, z1 - 0.3, z1, "thrust", m, "control jet thrust"),
    ]
    if top:
        ps.append(B(x - 0.22, x + 0.22, y + d / 2 - 0.12, y + d / 2 + 0.08, z0 + 0.4, z0 + 1.8, "thrust", m, "top vent: glows upward"))
    if side:
        ps.append(B(x + d / 2 - 0.12, x + d / 2 + 0.08, y - 0.18, y + 0.18, z0 + 0.4, z0 + 1.8, "thrust", m, "outboard vent"))
    return ps


def pilot(z, y, lean=50, arm_x=0.78):
    """Reclined pilot. z is the hip station, y lifts the whole seat. Head top is y + 2.55 at lean 50."""
    return [
        B(-0.65, 0.65, y + 0.5, y + 1.05, z - 3.5, z - 1.1, "driver", note="legs"),
        RB([1.3, 1.9, 0.8], [0, y + 1.3, z - 0.35], [lean, 0, 0], "driver", note="torso"),
        BALL(1.1, 0, y + 2.0, z + 0.8, "driver", note="head"),
        RB([0.3, 0.3, 1.6], [arm_x, y + 1.4, z - 1.3], [-20, 0, 0], "driver", m=True, note="arm"),
    ]


# ---------------------------------------------------------------- cockpits (fuselages)
def chassis():
    """The pads every fuselage carries in the same place. Modules land on these and nowhere else.

    Both seams are the same ring frame, 3.0 x 2.4. Every fuselage meets it at full section, and every prow
    and drive starts with a painted root fairing of the same section, so no build has a wasp waist.
    """
    return [
        B(-RING_X, RING_X, RING_Y0, RING_Y1, Z_FRONT, Z_FRONT + 0.4, "detail", note="PAD prow ring frame"),
        B(-RING_X, RING_X, RING_Y0, RING_Y1, Z_REAR - 0.4, Z_REAR, "detail", note="PAD drive ring frame"),
        B(PAD_X, HULL_X, 0.65, 1.35, -2.8, -1.2, "detail", m=True, note="PAD front wing hardpoint"),
        B(PAD_X, HULL_X, 0.65, 2.7, 3.6, 6.4, "detail", m=True, note="PAD rear hardpoint plate: wing spar below, wing-engine lug above"),
    ]


def cockpit_needle():
    """Round tube over a slim belly tank. Long bare nose, small canopy far aft, razorback to the tail."""
    p = chassis()
    p += [
        CZ(2.8, 0, AXIS, -7.6, -6.0, "secondary", note="nose bulkhead: steps the tube up to the ring frame"),
        CZ(2.4, 0, AXIS, -6.0, 6.0, "primary", note="main tube: long bare nose"),
        CZ(2.5, 0, AXIS, -4.8, -3.6, "secondary", note="accent band"),
        CZ(2.8, 0, AXIS, 6.0, 7.6, "secondary", note="tail bulkhead: steps the tube up to the ring frame"),
        B(-0.9, 0.9, 2.3, 2.5, -0.4, 3.0, "detail", note="canopy sill"),
        W("up_back", -0.8, 0.8, 2.5, 3.5, -0.4, 1.2, "glass", note="windscreen"),
        B(-0.8, 0.8, 2.5, 3.5, 1.2, 2.8, "glass", note="canopy, far aft"),
        W("up_front", -0.8, 0.8, 2.5, 3.5, 2.8, 7.4, "primary", note="razorback"),
        W("out_back", 1.0, PAD_X, 0.65, 1.35, -4.4, -2.8, "primary", m=True, note="wing-root shelf, leading edge"),
        B(1.0, PAD_X, 0.65, 1.35, -2.8, 6.4, "primary", m=True, note="wing-root shelf: wings meet body colour"),
        B(1.0, PAD_X, 1.35, 1.9, 3.8, 6.2, "secondary", m=True, note="engine pylon"),
        CZ(1.2, 0, -0.5, -4.4, 4.4, "secondary", note="belly tank: the record breaker's long ventral fuel tank"),
        CZ(0.75, 0, -0.5, -5.4, -4.4, "primary", note="belly tank nose"),
        CZ(0.75, 0, -0.5, 4.4, 5.4, "primary", note="belly tank tail"),
        B(-0.12, 0.12, 2.5, 2.58, -5.8, -1.0, "neon", note="nose spine light"),
        B(-0.25, 0.25, -1.16, -1.04, -3.4, 3.4, "thrust", note="lift strip under the tank"),
        B(1.3, 2.4, 0.49, 0.65, 0.0, 5.6, "thrust", m=True, note="lift strip"),
    ]
    p += pilot(1.4, 0.45)
    return p


def cockpit_delta():
    """Faceted wedge. One long windscreen up to a peak at Y 5.5, then a full-length dorsal spine fin."""
    p = chassis()
    p += [
        B(-1.5, 1.5, 0.1, 2.5, -7.6, -6.0, "primary", note="nose block, ring section"),
        B(-1.5, 1.5, 0.2, 0.5, -6.0, 0.4, "primary", note="tub floor"),
        B(1.25, 1.5, 0.5, 2.2, -6.0, 0.4, "primary", m=True, note="tub wall"),
        B(-1.5, 1.5, 0.2, 2.5, 0.4, 7.6, "primary", note="rear spine block, ring section"),
        W("out_back", 1.5, PAD_X, 0.3, 2.2, -7.4, -0.6, "primary", m=True, note="delta flank: full width by mid length"),
        B(1.5, PAD_X, 0.3, 2.2, -0.6, 5.6, "primary", m=True, note="flank at full width"),
        W("out_front", 1.5, PAD_X, 0.3, 2.2, 5.6, 7.6, "primary", m=True, note="flank tapers to the ring frame over two studs"),
        W("slope_out", 1.2, PAD_X, 2.2, 2.9, -0.6, 5.6, "secondary", m=True, note="faceted shoulder"),
        W("up_back", -1.2, 1.2, 2.2, 5.5, -6.0, -0.8, "glass", note="one long wedge windscreen"),
        B(-1.2, 1.2, 2.2, 5.5, -0.8, 0.4, "glass", note="canopy peak"),
        W("up_front", -1.2, 1.2, 2.5, 5.5, 0.4, 4.8, "primary", note="fastback"),
        B(-0.15, 0.15, 2.5, 4.2, 0.4, 7.9, "secondary", note="dorsal spine fin, full length"),
        W("up_front", -0.15, 0.15, 4.2, 5.5, 0.4, 7.9, "secondary", note="spine fin top edge"),
        B(-1.25, 1.25, 2.1, 2.25, -6.0, 0.4, "detail", note="canopy sill"),
        B(1.7, 2.5, 0.8, 1.4, 7.05, 7.15, "neon", m=True, note="tail light"),
        B(-0.1, 0.1, 2.5, 2.58, -7.5, -6.3, "neon", note="nose light"),
        B(-0.9, 0.9, -0.5, 0.2, -2.0, 5.0, "secondary", note="belly intake duct"),
        B(-0.7, 0.7, -0.4, 0.1, -2.2, -1.9, "detail", note="belly intake mouth"),
        W("dn_front", -0.9, 0.9, -0.5, 0.2, 5.0, 7.2, "secondary", note="duct tail"),
        B(1.7, 2.5, 0.14, 0.3, -0.2, 5.0, "thrust", m=True, note="lift strip"),
    ]
    p += pilot(-1.6, 0.6)
    return p


def cockpit_manta():
    """Flat ray. A wafer hull 1.3 thick, wide low blister, two horns that stand above the deck and reach forward."""
    p = chassis()
    p += [
        B(-1.5, 1.5, 0.3, 2.25, -7.6, -6.6, "primary", note="nose block: steps the flat deck up to the ring frame"),
        W("up_front", -1.5, 1.5, 1.8, 2.25, -6.6, -5.4, "primary", note="nose ramp down to the deck"),
        B(-1.5, 1.5, 0.5, 1.8, -6.6, -2.6, "primary", note="keel nose, ring width, deck at Y 1.8"),
        B(-1.5, 1.5, 0.5, 0.7, -2.6, 3.6, "primary", note="tub floor"),
        B(1.25, 1.5, 0.7, 1.8, -2.6, 3.6, "primary", m=True, note="tub wall"),
        B(-1.5, 1.5, 0.5, 1.8, 3.6, 6.6, "primary", note="keel tail, ring width"),
        B(-1.5, 1.5, 0.3, 2.25, 6.6, 7.6, "primary", note="tail block: steps the deck up to the ring frame"),
        W("out_back", 1.5, PAD_X, 0.65, 1.35, -7.6, -5.8, "primary", m=True, note="lobe leading edge: grows from the ring frame over two studs"),
        B(1.5, PAD_X, 0.65, 1.35, -5.8, 0.4, "primary", m=True, note="flat lobe: widest at the head"),
        W("out_front", 1.5, PAD_X, 0.65, 1.35, 0.4, 7.4, "primary", m=True, note="lobe tapers to the tail"),
        W("slope_out", 1.5, PAD_X, 1.35, 1.8, -5.8, 0.4, "secondary", m=True, note="blended top"),
        B(1.5, 2.3, 1.35, 1.8, 0.4, 3.4, "primary", m=True, note="shoulder under the blister"),
        B(1.5, PAD_X, 0.7, 1.3, 3.8, 6.2, "primary", m=True, note="tail pylon to the rear hardpoint plate"),
        B(2.3, 2.9, 1.35, 3.2, -6.4, -4.4, "secondary", m=True, note="cephalic horn: stands 1.4 above the deck"),
        W("up_back", 2.3, 2.9, 1.35, 3.2, -7.9, -6.4, "secondary", m=True, note="horn tip: reaches forward past the lobe"),
        W("up_front", 2.3, 2.9, 1.35, 3.2, -4.4, -2.4, "secondary", m=True, note="horn heel"),
        W("up_back", -2.2, 2.2, 1.8, 2.9, -2.6, 0.6, "glass", note="low wide windscreen"),
        B(-2.2, 2.2, 1.8, 2.9, 0.6, 3.2, "glass", note="blister canopy, 4.4 wide"),
        W("up_front", -1.5, 1.5, 1.8, 2.9, 3.2, 7.4, "primary", note="tail fairing"),
        B(-2.25, 2.25, 1.7, 1.85, -2.6, 3.3, "detail", note="canopy sill"),
        B(-0.5, 0.5, 1.8, 1.88, -5.2, -3.0, "secondary", note="nose stripe"),
        B(2.9, 2.98, 2.2, 2.8, -6.2, -4.6, "neon", m=True, note="horn light"),
        B(1.7, 2.5, 0.49, 0.65, -5.0, -0.4, "thrust", m=True, note="lift strip"),
        B(-0.4, 0.4, 0.34, 0.5, 3.8, 6.4, "thrust", note="lift strip"),
    ]
    p += pilot(1.0, 0.3)
    return p


def cockpit_twinboom():
    """Slim pod with a raked wedge canopy far forward, between two booms that run on alone to a tail yoke.

    The pod is 1.8 wide and stops at Z 2. The booms sit a full stud clear of it on two thin webs, so daylight
    shows between pod and boom and across the whole gap behind the pod.
    """
    p = chassis()
    p += [
        B(-1.5, 1.5, 0.1, 2.5, -7.6, -6.6, "primary", note="nose stub, ring section"),
        W("out_front", 0.9, 1.5, 0.2, 2.2, -6.6, -5.0, "primary", m=True, note="cheek: the nose stub tapers to the pod"),
        B(-0.9, 0.9, 0.2, 2.2, -6.6, -5.8, "primary", note="pod nose"),
        B(-0.9, 0.9, 0.2, 0.5, -5.8, -0.9, "primary", note="tub floor"),
        B(0.75, 0.9, 0.5, 2.2, -5.8, -0.9, "primary", m=True, note="tub wall"),
        B(-0.9, 0.9, 0.2, 3.8, -0.9, -0.3, "primary", note="pod bulkhead"),
        W("up_front", -0.9, 0.9, 0.2, 3.8, -0.3, 2.0, "primary", note="pod tail: the pod stops at Z 2"),
        W("up_back", -0.8, 0.8, 2.2, 3.8, -6.2, -3.0, "glass", note="raked wedge windscreen"),
        B(-0.8, 0.8, 2.2, 3.8, -3.0, -0.9, "glass", note="canopy"),
        B(-0.85, 0.85, 3.8, 3.95, -3.0, -0.3, "secondary", note="low roof, no wider than the glass"),
        B(-0.92, 0.92, 2.1, 2.25, -6.2, -0.9, "detail", note="canopy sill"),
        W("in_back", 1.9, PAD_X, 0.1, 1.4, -7.6, -5.6, "secondary", m=True, note="boom nose: pointed, tip outboard"),
        B(1.9, PAD_X, 0.1, 1.4, -5.6, 6.6, "primary", m=True, note="boom, 0.8 x 1.3, a full stud clear of the pod"),
        W("up_front", 1.9, PAD_X, 0.1, 1.4, 6.6, 7.8, "primary", m=True, note="boom tail"),
        W("up_back", 1.9, PAD_X, 1.4, 2.7, 1.4, 3.6, "primary", m=True, note="boom shoulder ramp"),
        B(1.9, PAD_X, 1.4, 2.7, 3.6, 6.4, "primary", m=True, note="boom shoulder: backs the rear hardpoint plate"),
        W("up_front", 1.9, PAD_X, 1.4, 2.7, 6.4, 7.4, "secondary", m=True, note="shoulder tail"),
        B(1.95, 2.65, 1.4, 1.48, -5.0, 1.2, "secondary", m=True, note="boom top stripe"),
        B(0.9, 1.9, 0.6, 0.9, -4.4, -3.6, "primary", m=True, note="front web: thin"),
        B(0.9, 1.9, 0.6, 0.9, 0.2, 1.0, "primary", m=True, note="rear web: thin"),
        B(-1.5, 1.5, 0.1, 2.5, 5.4, 7.6, "primary", note="tail yoke hub: wraps the drive ring frame"),
        B(-0.5, 0.5, 2.5, 2.58, 5.6, 7.4, "secondary", note="hub stripe"),
        B(-1.9, 1.9, 0.3, 1.3, 4.6, 5.8, "primary", note="tail yoke beam: joins the booms"),
        B(2.05, 2.55, 1.8, 2.3, 7.0, 7.12, "neon", m=True, note="boom tail light"),
        B(2.05, 2.55, -0.06, 0.1, -4.0, 4.0, "thrust", m=True, note="lift strip"),
    ]
    p += pilot(-2.4, 0.55, arm_x=0.55)
    return p


def cockpit_bubble():
    """Big glass dome far forward on a keel beam, a painted pressure tank behind it, side tanks on a flat wing-root shelf."""
    p = chassis()
    p += [
        B(-1.5, 1.5, 0.1, 2.5, -7.6, -7.0, "primary", note="nose stub, ring section"),
        B(-1.9, 1.9, 0.1, 2.0, -7.0, -2.2, "primary", note="cab tub"),
        W("dn_back", -1.9, 1.9, -0.4, 0.1, -7.0, -4.4, "secondary", note="chin"),
        B(-2.05, 2.05, 2.0, 2.25, -6.9, -2.1, "secondary", note="dome sill"),
        BALL(4.4, 0, 2.7, -4.5, "glass", note="bubble dome"),
        B(-0.65, 0.65, 1.3, 1.8, -6.4, -4.6, "driver", note="legs"),
        RB([1.3, 1.9, 0.8], [0, 2.5, -4.0], [18, 0, 0], "driver", note="torso, upright"),
        BALL(1.1, 0, 3.75, -3.7, "driver", note="head"),
        RB([0.3, 0.3, 1.5], [0.78, 2.6, -4.8], [-15, 0, 0], "driver", m=True, note="arm"),
        B(-0.7, 0.7, 0.5, 1.7, -2.2, 6.0, "secondary", note="keel beam"),
        W("out_back", 0.7, 1.5, 0.5, 1.7, 4.0, 6.0, "secondary", m=True, note="beam flares to the ring frame"),
        B(-1.5, 1.5, 0.1, 2.5, 6.0, 7.6, "primary", note="tail bulkhead, ring section"),
        B(0.7, PAD_X, 0.75, 1.25, -2.8, 6.4, "primary", m=True, note="wing-root shelf: wings meet body colour"),
        CZ(1.3, 1.5, 1.6, -1.8, 3.4, "secondary", m=True, note="exposed tank"),
        CZ(1.36, 1.5, 1.6, 0.2, 1.4, "detail", m=True, note="tank strap"),
        B(0.7, PAD_X, 2.0, 2.4, 4.4, 5.6, "secondary", m=True, note="upper outrigger to the wing-engine lug"),
        B(-0.7, 0.7, 1.7, 2.5, 4.2, 5.8, "primary", note="outrigger hub"),
        BALL(2.6, 0, 2.9, 2.2, "secondary", note="pressure tank: a second, painted bubble behind the dome"),
        B(-0.5, 0.5, 1.7, 2.0, 1.6, 2.8, "detail", note="tank cradle"),
        B(0.3, 1.5, 2.25, 2.32, -6.6, -5.6, "primary", note="patch plate (one side only)"),
        B(1.5, 1.6, 2.1, 4.6, -2.5, -2.4, "detail", note="whip aerial"),
        B(-1.2, 1.2, -0.08, 0.1, -4.2, -2.6, "thrust", note="lift strip"),
        B(1.2, 2.4, 0.59, 0.75, -1.0, 5.6, "thrust", m=True, note="lift strip"),
    ]
    return p


def cockpit_arrowhead():
    """Arrow-shaped hull: point forward, full width at mid length, swept barbs. Triangular canopy, two low deck strakes, a short ventral fletch."""
    p = chassis()
    p += [
        B(-1.5, 1.5, 0.1, 2.5, -7.6, -4.6, "primary", note="shaft nose, ring section"),
        B(-1.5, 1.5, 0.1, 0.5, -4.6, 0.8, "primary", note="tub floor"),
        B(1.25, 1.5, 0.5, 2.5, -4.6, 0.8, "primary", m=True, note="tub wall"),
        B(-1.5, 1.5, 0.1, 2.5, 0.8, 7.6, "primary", note="shaft tail, ring section"),
        W("out_back", 1.5, PAD_X, 0.65, 2.5, -7.4, -2.8, "primary", m=True, note="arrow flank: grows from the ring frame"),
        B(1.5, PAD_X, 0.65, 2.5, -2.8, 0.8, "primary", m=True, note="flank at full width"),
        W("in_front", 1.5, PAD_X, 0.65, 2.5, 0.8, 3.8, "primary", m=True, note="swept barb: notch between barb and shaft"),
        B(1.5, PAD_X, 0.7, 1.3, 3.8, 6.2, "primary", m=True, note="tail pylon to the rear hardpoint plate"),
        W("out_back", 0.0, 2.9, 2.5, 2.7, -7.4, -2.8, "secondary", m=True, note="arrowhead deck plate: point forward"),
        B(-2.9, 2.9, 2.5, 2.7, -2.8, 0.8, "secondary", note="deck plate at full width"),
        W("in_front", 1.5, 2.9, 2.5, 2.7, 0.8, 3.8, "secondary", m=True, note="barb plate"),
        W("out_back", 0.0, 1.9, 2.7, 3.6, -5.6, 0.2, "glass", m=True, note="arrow-shaped canopy"),
        B(-1.9, 1.9, 2.7, 3.6, 0.2, 0.8, "primary", note="canopy rear bulkhead"),
        W("up_front", -0.7, 0.7, 2.5, 3.6, 0.8, 4.6, "primary", note="spine fairing"),
        RW([0.24, 1.5, 3.0], [1.52, 3.18, 3.5], [0, 0, -25], "secondary", m=True, note="low canted deck strake: top at Y 3.9, ends at Z 5 (tall fins belong to the Tail Fins slot)"),
        B(-0.1, 0.1, 2.7, 2.78, -7.0, -5.8, "neon", note="point light"),
        B(2.7, 2.78, 1.4, 1.9, -2.4, 0.4, "neon", m=True, note="flank light"),
        W("dn_back", -0.12, 0.12, -1.3, 0.1, 2.4, 6.0, "secondary", note="ventral fletch: stops at Z 6"),
        B(1.7, 2.5, 0.49, 0.65, -2.6, 0.6, "thrust", m=True, note="lift strip"),
        B(-0.4, 0.4, -0.08, 0.1, -6.6, -3.6, "thrust", note="lift strip"),
    ]
    p += pilot(-1.0, 0.9)
    return p


# ---------------------------------------------------------------- FrontBody: the prow
def prow_pads():
    return [
        B(-RING_X, RING_X, RING_Y0, RING_Y1, Z_FRONT - 0.4, Z_FRONT, "detail", note="PAD root ring: lands on the prow ring frame"),
        B(-RING_X, RING_X, RING_Y0, RING_Y1, Z_FRONT - 0.4 - ROOT, Z_FRONT - 0.4, "primary", note="root fairing: ring section for 1.5 studs"),
        B(-0.45, 0.45, 0.85, 1.75, Z_PROW, Z_PROW + 0.4, "detail", note="PAD nose collar"),
    ]


def prow_twin_prong():
    return prow_pads() + [
        B(-2.9, 2.9, 0.6, 2.0, -10.9, -9.9, "primary", note="yoke"),
        B(2.1, 2.9, 0.0, 2.6, -13.6, -10.9, "primary", m=True, note="tall blade"),
        W("up_back", 2.1, 2.9, 0.0, 2.6, -15.0, -13.6, "primary", m=True, note="chisel tip"),
        B(2.1, 2.9, 2.6, 2.72, -13.4, -11.1, "secondary", m=True, note="top stripe"),
        B(2.0, 2.1, 1.05, 1.45, -13.2, -11.2, "neon", m=True, note="inner light"),
        B(2.25, 2.75, -0.18, 0.0, -13.2, -11.2, "thrust", m=True, note="lift strip"),
        CZ(0.6, 0, AXIS, -14.6, -10.9, "detail", note="centre sensor boom carries the nose collar"),
    ]


def prow_spear():
    return prow_pads() + [
        CZ(2.4, 0, AXIS, -11.4, -9.9, "primary", note="lance root"),
        CZ(1.8, 0, AXIS, -13.2, -11.4, "secondary", note="lance mid"),
        CZ(1.2, 0, AXIS, -14.6, -13.2, "primary", note="lance tip"),
        W("out_back", 1.0, 2.4, 1.15, 1.45, -12.6, -9.0, "primary", m=True, note="strake"),
        B(-0.1, 0.1, 2.5, 2.58, -9.8, -8.6, "neon", note="spine light"),
        B(-0.3, 0.3, -0.08, 0.1, -9.8, -8.6, "thrust", note="lift strip"),
    ]


def prow_trident():
    return prow_pads() + [
        B(-0.6, 0.6, 0.7, 1.9, -13.4, -9.9, "primary", note="centre prong"),
        B(-0.45, 0.45, 0.85, 1.75, -14.6, -13.4, "secondary", note="centre tip"),
        RB([2.9, 0.6, 1.2], [2.0, 0.85, -10.5], [0, 0, -18], "primary", m=True, note="drooped crossbar"),
        B(3.0, 3.8, -0.3, 0.9, -13.0, -9.8, "primary", m=True, note="low outer prong"),
        W("up_back", 3.0, 3.8, -0.3, 0.9, -14.2, -13.0, "secondary", m=True, note="outer tip"),
        B(-0.3, 0.3, 1.9, 1.97, -12.6, -12.0, "secondary", note="tracking target"),
        B(3.1, 3.7, 0.9, 0.97, -11.4, -10.8, "secondary", m=True, note="tracking target"),
        B(3.15, 3.65, -0.48, -0.3, -12.6, -10.6, "thrust", m=True, note="lift strip"),
        B(3.78, 3.88, 0.1, 0.5, -12.6, -11.0, "neon", m=True, note="side light"),
    ]


def prow_hammerhead():
    return prow_pads() + [
        B(-NECK_X, NECK_X, NECK_Y0, NECK_Y1, -12.8, -9.9, "primary", note="neck boom, 2.2 x 1.9"),
        B(-3.2, 3.2, 0.8, 1.8, -14.0, -12.6, "primary", note="crossbar"),
        W("out_front", 1.1, 2.8, 0.9, 1.7, -12.6, -10.6, "primary", m=True, note="gusset"),
        CZ(1.4, 4.0, AXIS, -13.6, -9.4, "secondary", m=True, note="end pod: slender, longer than wide"),
        CZ(0.9, 4.0, AXIS, -14.6, -13.6, "primary", m=True, note="pod nose"),
        CZ(0.35, 4.0, AXIS, -15.0, -14.6, "neon", m=True, note="pod probe light"),
        CZ(0.9, 4.0, AXIS, -9.4, -8.8, "detail", m=True, note="pod tail"),
        B(3.7, 4.3, 0.22, 0.42, -14.2, -12.0, "thrust", m=True, note="lift strip"),
        B(-0.45, 0.45, 0.85, 1.75, -14.6, -14.0, "detail", note="centre nose block"),
    ]


def prow_spade():
    return prow_pads() + [
        B(-1.5, 1.5, 0.4, 1.5, -10.8, -9.9, "primary", note="neck root"),
        W("out_front", 1.5, 3.4, 0.4, 1.5, -10.8, -8.8, "primary", m=True, note="cheek"),
        W("up_back", -3.4, 3.4, 0.4, 1.5, -14.4, -10.8, "primary", note="wide flat shovel ramp"),
        B(3.2, 3.5, 0.4, 1.1, -14.0, -10.8, "secondary", m=True, note="side rail"),
        B(-0.45, 0.45, 0.4, 1.75, -14.6, -9.9, "secondary", note="centre rail carries the nose collar"),
        RB([1.4, 0.1, 1.4], [1.7, 1.02, -12.5], [-17, 0, 0], "secondary", note="patch plate"),
        B(0.9, 1.3, 0.4, 0.7, -15.0, -14.3, "detail", m=True, note="tooth"),
        B(1.9, 2.3, 0.4, 0.7, -15.0, -14.3, "detail", m=True, note="tooth"),
        B(2.9, 3.3, 0.4, 0.7, -15.0, -14.3, "detail", m=True, note="tooth"),
        B(-2.4, 2.4, 0.22, 0.4, -12.8, -11.0, "thrust", note="lift strip"),
    ]


def prow_broadhead():
    """Interceptor: one flat arrowhead blade with swept barbs and a dorsal ridge."""
    return prow_pads() + [
        B(-NECK_X, NECK_X, NECK_Y0, NECK_Y1, -11.4, -9.9, "primary", note="shaft, 2.2 x 1.9"),
        W("out_back", 0.0, 4.4, 0.9, 1.7, -14.8, -11.0, "primary", m=True, note="broadhead blade"),
        W("in_front", 2.6, 4.4, 0.9, 1.7, -11.0, -9.4, "secondary", m=True, note="swept barb"),
        B(-0.45, 0.45, 0.85, 1.75, -14.6, -11.0, "secondary", note="centre spine carries the nose collar"),
        W("up_back", -0.3, 0.3, 1.7, 2.7, -14.2, -11.4, "secondary", note="dorsal ridge"),
        B(-0.3, 0.3, 2.25, 2.7, -11.4, -9.9, "secondary", note="ridge root"),
        B(4.4, 4.48, 1.1, 1.5, -10.8, -9.8, "neon", m=True, note="barb light"),
        B(1.2, 3.0, 0.72, 0.9, -12.0, -11.0, "thrust", m=True, note="lift strip"),
    ]


# ---------------------------------------------------------------- FrontBumper: the nose tip
def tip_base():
    return [B(-0.45, 0.45, 0.85, 1.75, -15.3, Z_PROW, "detail", note="PAD lands on the nose collar")]


def tip_pitot():
    return tip_base() + [
        CZ(0.5, 0, AXIS, -15.9, -15.3, "secondary", note="boss"),
        CZ(0.25, 0, AXIS, -16.8, -15.9, "detail", note="pitot spike"),
        CZ(0.3, 0, AXIS, -17.0, -16.8, "neon", note="tip light"),
    ]


def tip_canards():
    return tip_base() + [
        B(-0.45, 0.45, 0.9, 1.7, -16.2, -15.3, "primary", note="body"),
        W("up_back", -0.45, 0.45, 0.9, 1.7, -17.0, -16.2, "primary", note="point"),
        W("out_back", 0.45, 2.8, 1.2, 1.4, -16.8, -15.2, "secondary", m=True, note="canard vane"),
    ]


def tip_sensor_blade():
    return tip_base() + [
        W("up_back", -0.15, 0.15, 0.3, 2.6, -16.9, -15.3, "secondary", note="vertical sensor blade"),
        B(-0.18, 0.18, 2.0, 2.5, -15.5, -15.3, "neon", note="sensor light"),
    ]


def tip_ram_scoop():
    return tip_base() + [
        B(-0.65, 0.65, 0.7, 1.9, -15.7, -15.3, "secondary", note="tapered throat: steps the 0.9 collar out to the scoop"),
        B(-0.9, 0.9, 0.55, 2.05, -16.5, -15.7, "primary", note="scoop, 1.8 x 1.5"),
        B(-0.72, 0.72, 0.73, 1.87, -16.7, -16.4, "detail", note="mouth"),
        B(-0.72, 0.72, 0.57, 0.67, -16.72, -16.5, "neon", note="lip light"),
    ]


def tip_bash_bar():
    return tip_base() + [
        B(0.25, 0.45, 0.9, 1.2, -16.5, -15.3, "detail", m=True, note="strut"),
        B(-2.6, 2.6, 0.85, 1.25, -16.7, -16.3, "secondary", note="square bash bar"),
        W("up_back", 2.0, 2.7, 0.75, 1.35, -17.0, -16.2, "primary", m=True, note="bar end tooth"),
    ]


def tip_chisel():
    """Interceptor: a double-wedge chisel point with two small barbs."""
    return tip_base() + [
        W("up_back", -0.9, 0.9, 1.3, 2.0, -17.0, -15.3, "primary", note="upper chisel face"),
        W("dn_back", -0.9, 0.9, 0.6, 1.3, -17.0, -15.3, "primary", note="lower chisel face"),
        W("in_front", 0.9, 1.7, 1.15, 1.45, -16.0, -15.1, "secondary", m=True, note="barb"),
    ]


# ---------------------------------------------------------------- SidePods: the wings
def wing_rib():
    return [B(HULL_X, 3.35, 0.65, 1.35, -3.0, 6.6, "detail", m=True, note="PAD root rib: lands on both wing hardpoints")]


def wing_delta():
    return wing_rib() + [
        B(3.35, 4.1, 0.75, 1.3, -3.0, 6.6, "primary", m=True, note="root fairing"),
        W("out_back", 3.35, 7.5, 0.85, 1.15, -4.6, 6.6, "primary", m=True, note="delta plane"),
        B(3.7, 7.3, 0.9, 1.1, 6.6, 7.4, "secondary", m=True, note="elevon"),
        B(7.4, 7.66, -0.2, 1.15, 4.2, 6.6, "secondary", m=True, note="downturned tip"),
        B(7.4, 7.68, 0.9, 1.1, 3.9, 4.2, "neon", m=True, note="tip light"),
        B(4.4, 5.6, 0.68, 0.85, 2.6, 5.6, "thrust", m=True, note="lift strip"),
    ]


def wing_stub():
    return wing_rib() + [
        B(3.35, 4.0, 0.75, 1.3, -1.0, 6.6, "primary", m=True, note="root fairing"),
        W("out_back", 3.35, 5.4, 0.85, 1.15, 0.0, 6.6, "primary", m=True, note="stub winglet"),
        B(5.3, 5.5, 0.6, 1.6, 4.6, 7.0, "secondary", m=True, note="tip fence"),
        B(3.6, 4.4, 0.58, 0.75, 3.0, 6.0, "thrust", m=True, note="lift strip"),
    ]


def wing_forward_swept():
    return wing_rib() + [
        B(3.35, 4.2, 0.75, 1.3, 0.2, 6.6, "primary", m=True, note="root fairing"),
        RB([4.2, 0.3, 2.4], [5.5, 1.0, 3.2], [0, 35, 0], "primary", m=True, note="forward-swept blade"),
        W("out_back", 3.35, 4.7, 0.9, 1.1, -2.8, 0.2, "secondary", m=True, note="root strake"),
        CZ(0.55, 7.4, 1.0, 0.7, 3.3, "secondary", m=True, note="tip sensor pod"),
        CZ(0.35, 7.4, 1.0, 0.5, 0.7, "neon", m=True, note="tip light"),
        W("up_back", 7.25, 7.5, 1.15, 1.7, 0.9, 3.3, "secondary", m=True, note="upturned tip fin"),
        B(3.6, 4.1, 0.58, 0.75, 1.0, 5.6, "thrust", m=True, note="lift strip"),
    ]


def wing_pontoons():
    return wing_rib() + [
        B(3.35, 6.4, 0.85, 1.15, -2.3, -1.1, "primary", m=True, note="front strut"),
        B(3.35, 6.4, 0.85, 1.15, 4.2, 5.4, "primary", m=True, note="rear strut"),
        CZ(1.5, 7.0, 0.75, -6.0, 6.4, "secondary", m=True, note="pontoon"),
        BALL(1.5, 7.0, 0.75, -6.0, "primary", m=True, note="pontoon nose"),
        CZ(1.0, 7.0, 0.75, 6.4, 7.6, "primary", m=True, note="pontoon tail"),
        B(6.7, 7.3, 1.44, 1.56, -4.0, 4.0, "primary", m=True, note="top stripe"),
        B(6.75, 7.25, -0.18, 0.04, -4.5, 4.5, "thrust", m=True, note="lift strip"),
    ]


def wing_plank():
    return wing_rib() + [
        B(3.35, 7.3, 0.9, 1.2, 0.6, 4.6, "primary", m=True, note="plank wing"),
        B(3.35, 6.0, 0.95, 1.12, 5.0, 6.6, "secondary", m=True, note="flap plank"),
        B(7.3, 7.6, 0.1, 1.65, 0.0, 5.2, "secondary", m=True, note="end plate"),
        CZ(0.8, 5.3, 0.45, 0.8, 4.0, "secondary", m=True, note="drop tank, painted"),
        B(4.0, 5.0, 1.2, 1.27, 1.2, 2.4, "secondary", note="patch plate (one side only)"),
        B(7.3, 7.6, -0.08, 0.1, 0.6, 4.6, "thrust", m=True, note="lift strip"),
    ]


def wing_tandem():
    """Interceptor: two swept-back blades each side, a short one forward and a long one aft."""
    return wing_rib() + [
        B(3.35, 4.0, 0.75, 1.3, -2.9, -0.4, "primary", m=True, note="front root fairing"),
        RB([3.4, 0.3, 1.5], [4.95, 1.0, -1.1], [0, -30, 0], "secondary", m=True, note="front blade, swept back"),
        B(3.35, 4.1, 0.75, 1.3, 2.4, 6.5, "primary", m=True, note="rear root fairing"),
        RB([4.4, 0.3, 2.0], [5.45, 1.0, 4.6], [0, -30, 0], "primary", m=True, note="rear blade, swept back"),
        B(7.2, 7.45, 0.6, 1.65, 4.9, 7.0, "secondary", m=True, note="tip fence"),
        B(3.6, 4.4, 0.58, 0.75, 3.0, 6.0, "thrust", m=True, note="lift strip"),
    ]


# ---------------------------------------------------------------- Engine2: wing-root engines
def lug2():
    return [B(HULL_X, 3.3, 1.9, 2.6, 3.7, 6.3, "detail", m=True, note="PAD lug: lands on the rear hardpoint plate")]


def e2_twin_turbine():
    return lug2() + [B(3.3, 3.8, 2.0, 2.8, 3.9, 6.1, "primary", m=True, note="pylon")] + \
        jet(4.55, 2.85, 0.9, 7.9, 1.8, m=True, intake="spike", tag="turbine")


def e2_lance():
    return lug2() + [
        B(3.3, 3.6, 2.0, 2.6, 3.9, 6.1, "primary", m=True, note="pylon"),
        CZ(0.3, 3.95, 2.45, -1.0, -0.2, "detail", m=True, note="shock probe"),
        B(4.5, 5.0, 2.35, 2.55, 4.0, 7.0, "secondary", m=True, note="lance fin"),
    ] + jet(3.95, 2.45, -0.4, 7.9, 1.3, m=True, tf=0.72, tag="lance ramjet")


def e2_slot():
    return lug2() + [
        B(3.3, 5.75, 1.85, 2.75, 3.4, 7.0, "primary", m=True, note="flat ramjet body"),
        B(3.3, 5.75, 2.75, 2.85, 3.8, 6.6, "secondary", m=True, note="top panel"),
        B(3.45, 5.6, 1.95, 2.65, 3.1, 3.7, "detail", m=True, note="slot intake"),
        B(3.45, 5.6, 1.97, 2.63, 6.8, 7.6, "detail", m=True, note="slot nozzle"),
        B(3.6, 5.45, 2.08, 2.52, 7.5, 7.9, "thrust", m=True, note="slot thrust"),
    ]


def e2_stacked():
    """Privateer: two slim jets, over and under, the full length of the slot."""
    return lug2() + [B(3.3, 3.5, 1.95, 3.9, 4.2, 6.1, "primary", m=True, note="web plate")] + \
        jet(3.95, 2.35, -0.6, 7.9, 1.25, m=True, tf=0.75, tag="lower jet") + \
        jet(3.95, 3.55, 0.6, 7.4, 1.25, body="secondary", lip="primary", m=True, tf=0.75, tag="upper jet")


def e2_stub_radial():
    """Salvage: a big square scoop set forward, a short fat burner, then a long thin tailpipe."""
    return lug2() + [
        B(3.3, 3.7, 2.0, 2.6, 3.8, 6.1, "primary", m=True, note="pylon"),
        B(3.4, 5.7, 1.8, 4.1, 2.4, 4.0, "secondary", m=True, note="square intake scoop, 2.3 across"),
        B(3.55, 5.55, 1.95, 3.95, 2.2, 2.6, "detail", m=True, note="scoop mouth"),
        B(4.45, 4.65, 1.95, 3.95, 2.12, 2.4, "primary", m=True, note="scoop splitter"),
        CZ(1.7, 4.55, 2.95, 4.0, 5.3, "primary", m=True, note="fat burner body"),
        CZ(1.2, 4.55, 2.95, 5.3, 5.9, "secondary", m=True, note="neck"),
        CZ(1.1, 4.55, 2.95, 5.8, 7.75, "detail", m=True, note="long thin tailpipe"),
        CZ(0.9, 4.55, 2.95, 7.5, 7.9, "thrust", m=True, note="thrust"),
        CZ(0.3, 5.5, 2.1, 4.0, 7.2, "detail", m=True, note="exposed fuel pipe"),
        B(3.9, 4.9, 4.1, 4.18, 2.8, 3.6, "primary", m=True, note="patch plate"),
    ]


def e2_chine():
    """Interceptor: a faceted ramjet with a sloped outer face, a swept ramp lip and a square nozzle."""
    return lug2() + [
        B(3.3, 5.3, 1.9, 2.25, 1.6, 7.0, "primary", m=True, note="flat base"),
        W("slope_out", 3.3, 5.3, 2.25, 3.5, 1.6, 7.0, "primary", m=True, note="chined top: tall inboard, thin outboard"),
        W("out_back", 3.3, 5.3, 1.9, 2.25, -0.2, 1.6, "secondary", m=True, note="swept ramp lip"),
        B(3.4, 4.2, 2.3, 3.0, 1.35, 1.75, "detail", m=True, note="ramp intake mouth"),
        B(3.3, 3.55, 3.5, 3.6, 2.2, 6.4, "secondary", m=True, note="spine stripe"),
        B(3.4, 4.5, 2.0, 3.1, 6.9, 7.6, "detail", m=True, note="square nozzle"),
        B(3.5, 4.4, 2.1, 3.0, 7.5, 7.9, "thrust", m=True, note="thrust"),
    ]


# ---------------------------------------------------------------- Engine1: the main drive
def drive_frame():
    """Pads every drive carries: ring spigot, painted root fairing, burner deck, two posts with fin pads, belly pad.

    The belly pad is 3.6 x 4.1, so any keel lands on a full-width pad. Each drive sits its body or a skirt on it.
    """
    return [
        B(-RING_X, RING_X, RING_Y0, RING_Y1, Z_REAR, Z_REAR + 0.4, "detail", note="PAD ring spigot: lands on the drive ring frame"),
        B(-RING_X, RING_X, RING_Y0, RING_Y1, Z_REAR + 0.4, Z_REAR + 0.4 + ROOT, "primary", note="root fairing: ring section for 1.5 studs"),
        B(-1.2, 1.2, 3.0, BOOST_Y, BR_Z0, BR_Z1, "detail", note="PAD burner deck"),
        B(2.75, HULL_X, 1.3, BOOST_Y, 11.0, 12.2, "detail", m=True, note="PAD hardpoint post: airbrake lug on its flank"),
        B(FIN_X0, HULL_X, 3.0, BOOST_Y, 11.0, 12.2, "detail", m=True, note="PAD fin pad on top of the post"),
        B(-1.8, 1.8, -0.4, -0.15, 9.5, 13.6, "detail", note="PAD belly pad: full keel width"),
    ]


def e1_mono_turbine():
    """Record: one big turbine. A raked dorsal scoop feeds it from above the ring frame."""
    return drive_frame() + [
        CZ(3.3, 0, 1.4, 9.6, 11.2, "secondary", note="intake cowl"),
        CZ(3.3, 0, 1.4, 11.2, 13.0, "primary", note="turbine body"),
        CZ(2.8, 0, 1.4, 12.8, 14.2, "detail", note="nozzle"),
        CZ(2.4, 0, 1.4, 14.1, 14.5, "thrust", note="thrust"),
        B(-0.9, 0.9, 2.5, 4.0, 8.3, 9.1, "secondary", note="dorsal scoop"),
        B(-0.75, 0.75, 2.8, 3.85, 8.05, 8.45, "detail", note="scoop mouth"),
        W("up_front", -0.9, 0.9, 3.0, 4.0, 9.1, 10.2, "secondary", note="scoop fairing, raked back to the turbine"),
        B(1.6, 2.75, 1.4, 2.0, 11.0, 12.2, "primary", m=True, note="stub pylon to the post"),
    ]


def e1_twin_drive():
    """Works: two big barrels wide apart, each behind a square box intake either side of the root fairing."""
    return drive_frame() + [
        B(-1.5, 1.5, 0.5, 2.4, 9.9, 11.4, "primary", note="yoke: joins the barrels"),
        B(-0.4, 0.4, 2.4, 3.0, BR_Z0, BR_Z1, "primary", note="saddle under the burner deck"),
        B(-1.7, 1.7, -0.15, 0.5, 9.9, 13.4, "primary", note="belly skirt down to the belly pad"),
        B(1.5, 2.95, 0.45, 2.75, 9.2, 10.4, "secondary", m=True, note="box intake"),
        B(1.65, 2.8, 0.6, 2.6, 9.0, 9.35, "detail", m=True, note="box intake mouth"),
        CZ(2.6, 1.7, 1.6, 10.2, 13.6, "primary", m=True, note="drive barrel"),
        CZ(2.1, 1.7, 1.6, 13.3, 14.3, "detail", m=True, note="barrel nozzle"),
        CZ(1.55, 1.7, 1.6, 14.05, 14.45, "thrust", m=True, note="barrel thrust"),
        B(-0.25, 0.25, 1.3, 2.1, 11.4, 11.55, "neon", note="tail light"),
    ]


def e1_slot_burner():
    """Prototype: a flat fishtail under a dorsal spine, with intake boxes on top and one wide slot nozzle."""
    return drive_frame() + [
        B(-0.6, 0.6, 1.2, 3.0, 9.9, BR_Z1, "secondary", note="dorsal spine under the burner deck"),
        W("up_front", -1.5, 1.5, 1.2, 2.5, 9.9, 11.4, "primary", note="shoulder: root fairing slopes down to the fishtail"),
        B(-1.5, 1.5, 0.2, 1.2, 9.9, 11.4, "primary", note="flat body"),
        W("out_back", 1.5, 2.9, 0.2, 1.2, 9.9, 11.4, "primary", m=True, note="fishtail flare"),
        B(-2.9, 2.9, 0.2, 1.2, 11.4, 13.4, "primary", note="wide tail block"),
        B(-2.8, 2.8, 0.28, 1.12, 13.2, 14.2, "detail", note="slot nozzle"),
        B(-2.6, 2.6, 0.4, 1.0, 14.1, 14.45, "thrust", note="slot thrust"),
        B(0.9, 2.5, 1.2, 1.75, 11.5, 13.2, "secondary", m=True, note="intake box on the tail block"),
        B(1.0, 2.4, 1.28, 1.68, 11.25, 11.6, "detail", m=True, note="intake mouth"),
        B(2.7, HULL_X, 1.2, 1.3, 11.0, 12.2, "detail", m=True, note="post foot"),
        B(-1.7, 1.7, -0.15, 0.2, 9.6, 13.5, "primary", note="belly skirt down to the belly pad"),
        B(-0.5, 0.5, 1.2, 1.28, 12.6, 13.3, "neon", note="heat strip"),
    ]


def e1_quad_cluster():
    """Privateer: four jets in a 2 x 2 block, fed by a scoop either side of the root fairing."""
    return drive_frame() + [
        B(1.5, 2.35, 0.9, 1.8, 9.0, 10.3, "primary", m=True, note="side intake scoop"),
        B(1.55, 2.3, 0.98, 1.72, 8.8, 9.15, "detail", m=True, note="scoop mouth"),
        B(1.9, 2.75, 1.4, 2.0, 11.0, 12.2, "primary", m=True, note="stub to the post"),
        B(-0.3, 0.3, -0.15, 0.2, 9.6, 12.4, "detail", note="keel strut down to the belly pad"),
        B(-0.12, 0.12, 0.3, 2.4, 13.5, 13.65, "neon", note="tail light between the jets"),
    ] + jet(1.15, 2.1, 9.9, 14.4, 1.7, body="secondary", lip="primary", m=True, tf=0.85, tag="upper jet") + \
        jet(1.15, 0.5, 9.9, 14.4, 1.7, m=True, tf=0.85, tag="lower jet")


def e1_rack_triple():
    """Salvage: three big scavenged jets in a shallow V. One long jet low on the centreline, a shorter one high each side."""
    return drive_frame() + [
        B(-0.5, 0.5, 1.7, 3.0, BR_Z0, BR_Z1, "primary", note="saddle under the burner deck"),
        B(-2.75, 2.75, 1.3, 1.6, 11.0, 11.4, "secondary", note="painted ladder rung: joins the posts"),
        B(-2.75, 2.75, 1.3, 1.6, 11.8, 12.2, "secondary", note="painted ladder rung: joins the posts"),
        CZ(0.6, 1.3, 0.2, 10.2, 12.6, "detail", note="header tank (one side only)"),
    ] + jet(0, 0.75, 9.9, 14.45, 1.9, body="secondary", lip="primary", tf=0.76, tag="centre jet, low") + \
        jet(1.95, 1.85, 10.2, 13.7, 1.9, m=True, tf=0.76, tag="outer jet, high")


def e1_vector_blade():
    """Interceptor: one tall thin vectoring nozzle, a vertical slot, with a ramp intake box each side."""
    return drive_frame() + [
        B(-0.9, 0.9, -0.3, 3.0, 9.9, 13.4, "primary", note="blade body: tall and thin"),
        B(-0.8, 0.8, -0.2, 2.9, 13.2, 14.2, "detail", note="vertical slot nozzle"),
        B(-0.6, 0.6, 0.0, 2.7, 14.1, 14.45, "thrust", note="slot thrust"),
        B(-0.85, 0.85, 1.25, 1.45, 13.4, 14.48, "secondary", note="vectoring vane"),
        B(0.9, 2.4, 0.5, 2.5, 10.4, 12.6, "secondary", m=True, note="ramp intake box"),
        B(1.6, 2.3, 0.65, 2.35, 10.15, 10.5, "detail", m=True, note="ramp intake mouth"),
        W("out_front", 0.9, 2.4, 0.5, 2.5, 12.6, 13.8, "secondary", m=True, note="boat tail"),
        B(2.4, 2.75, 1.4, 2.0, 11.0, 12.2, "primary", m=True, note="stub to the post"),
        B(-1.7, 1.7, -0.15, 0.5, 10.4, 13.2, "primary", note="belly skirt down to the belly pad"),
        B(0.9, 0.98, 0.4, 2.6, 13.0, 13.3, "neon", m=True, note="heat strip"),
    ]


# ---------------------------------------------------------------- Boost: the afterburner
def saddle():
    return [B(-1.2, 1.2, BOOST_Y, 3.45, BR_Z0, BR_Z1, "detail", note="PAD saddle: lands on the burner deck")]


def b_stinger():
    """Record: the one long thin tube, 0.8 across, ending in a small flared bell at the back of the slot."""
    return saddle() + [
        B(-0.3, 0.3, 3.45, 3.75, 11.0, 12.4, "primary", note="pedestal"),
        CZ(0.6, 0, 4.1, 10.3, 10.9, "detail", note="intake mouth"),
        CZ(0.8, 0, 4.1, 10.45, 14.0, "secondary", note="stinger body, 0.8 across"),
        CZ(0.55, 0, 4.1, 14.0, 15.5, "detail", note="long nozzle"),
        CZ(1.0, 0, 4.1, 15.3, 16.25, "detail", note="flared bell"),
        CZ(0.7, 0, 4.1, 16.1, 16.5, "thrust", note="thrust"),
        B(0.38, 0.48, 3.95, 4.25, 11.0, 13.6, "neon", m=True, note="heat strip"),
    ]


def b_twin_cans():
    """Works: two fat cans, 1.8 across, touching."""
    return saddle() + [B(-0.3, 0.3, 3.45, 4.6, 11.0, 13.2, "primary", note="yoke")] + \
        jet(0.92, 4.2, 10.5, 15.0, 1.8, body="secondary", lip="primary", m=True, tag="burner can")


def b_slot():
    """Prototype: a flat fishtail burner, narrow at the throat."""
    return saddle() + [
        B(-0.9, 0.9, 3.45, 3.7, 10.9, 12.4, "primary", note="pedestal"),
        B(-1.0, 1.0, 3.7, 4.35, 10.8, 13.4, "secondary", note="throat"),
        W("out_back", 1.0, 2.0, 3.7, 4.35, 11.4, 13.4, "secondary", m=True, note="fishtail flare"),
        B(-2.0, 2.0, 3.7, 4.35, 13.4, 15.2, "secondary", note="flat burner tail"),
        B(-0.85, 0.85, 3.78, 4.27, 10.5, 11.0, "detail", note="slot intake"),
        B(-1.9, 1.9, 3.76, 4.29, 15.0, 15.9, "detail", note="slot nozzle"),
        B(-1.7, 1.7, 3.85, 4.2, 15.8, 16.2, "thrust", note="slot thrust"),
    ]


def b_staged():
    """Privateer: a short, fat stepped cone. Three stages grow to a bell that fills the 2.0 stud slot height."""
    return saddle() + [
        B(-0.5, 0.5, 3.45, 3.8, 11.0, 12.4, "primary", note="pedestal"),
        CZ(0.8, 0, 4.24, 10.3, 10.9, "detail", note="intake mouth"),
        CZ(1.0, 0, 4.24, 10.5, 11.6, "primary", note="stage one"),
        CZ(1.45, 0, 4.24, 11.6, 12.8, "secondary", note="stage two"),
        CZ(1.9, 0, 4.24, 12.8, 14.5, "primary", note="stage three bell: full slot height"),
        CZ(1.6, 0, 4.24, 14.3, 14.8, "detail", note="bell rim"),
        CZ(1.1, 0, 4.24, 14.6, 15.0, "thrust", note="thrust: small glow inside a thick dark rim, so it never matches a main-drive nozzle"),
    ]


def b_bottles():
    """Salvage: four thin painted rocket bottles in an arch. Pointed noses, no intake, tiny nozzles well aft of the drive."""
    ps = saddle() + [
        B(-2.2, 2.2, 3.45, 3.55, 11.0, 12.4, "detail", note="rack plate"),
        B(1.13, 1.25, 3.55, 4.9, 11.9, 12.1, "detail", m=True, note="thin strap"),
        B(-0.25, 0.25, 3.55, 4.4, 11.8, 12.2, "detail", note="cradle under the inner pair"),
    ]
    for x, y, z0, z1, ch, cap in ((1.75, 4.0, 11.0, 15.0, "secondary", "primary"), (0.62, 4.6, 11.6, 15.7, "primary", "secondary")):
        ps += [
            CZ(0.28, x, y, z0 - 0.8, z0 - 0.35, cap, True, "bottle nose point"),
            CZ(0.58, x, y, z0 - 0.4, z0, cap, True, "bottle nose cap"),
            CZ(0.9, x, y, z0, z1, ch, True, "rocket bottle, 0.9 across"),
            CZ(0.95, x, y, z0 + 1.0, z0 + 1.35, "detail", True, "bottle band"),
            CZ(0.55, x, y, z1, z1 + 0.4, "detail", True, "bottle neck"),
            CZ(0.45, x, y, z1 + 0.3, z1 + 0.6, "thrust", True, "thrust"),
        ]
    return ps


def b_aerospike():
    """Interceptor: a square plug body with four vanes and a square rim. Its thrust is a glowing stepped spike."""
    return saddle() + [
        B(-0.5, 0.5, 3.45, 3.55, 11.0, 12.4, "primary", note="pedestal"),
        B(-0.5, 0.5, 3.6, 4.6, 10.3, 10.8, "detail", note="square intake mouth"),
        B(-0.7, 0.7, 3.45, 4.75, 10.6, 13.0, "secondary", note="square plug body"),
        B(-0.76, 0.76, 3.4, 4.8, 11.4, 12.0, "primary", note="band"),
        W("out_back", 0.7, 2.0, 4.0, 4.2, 10.9, 13.4, "primary", m=True, note="side vane: swept delta"),
        RB([0.16, 0.9, 2.2], [0.95, 4.8, 12.1], [0, 0, -45], "primary", m=True, note="upper vane, canted 45 degrees"),
        B(-0.62, 0.62, 3.48, 4.72, 13.0, 13.5, "detail", note="square nozzle rim"),
        CZ(1.0, 0, 4.1, 13.4, 14.4, "thrust", note="spike stage one"),
        CZ(0.65, 0, 4.1, 14.4, 15.4, "thrust", note="spike stage two"),
        CZ(0.32, 0, 4.1, 15.4, 16.3, "thrust", note="spike tip"),
    ]


# ---------------------------------------------------------------- Stabilisers: airbrakes with control jets
def brake_lug():
    return [B(HULL_X, 3.4, 1.3, 2.1, 10.9, 12.3, "detail", m=True, note="PAD lug: lands on the drive hardpoint post")]


# Every airbrake keeps clear of the wing-engine exhaust lane (X 3.4..5.2, Y 1.9..3.3): arms run under it at Y 1.85 or
# lower, and slabs, flaps, louvres and paddles start at X 5.3. Each option has its own jet layout, not only its own plate.
def s_clamshell():
    """Works: a jaw. Two flaps open 30 degrees each, with the control jet between them at the hinge."""
    return brake_lug() + [
        B(3.4, 5.3, 1.3, 1.85, 10.0, 12.2, "primary", m=True, note="hinge arm: under the exhaust lane"),
        B(5.2, 7.8, 1.2, 1.6, 9.8, 10.3, "detail", m=True, note="hinge bar"),
        RB([2.4, 0.3, 3.3], [6.5, 2.3, 11.43], [-30, 0, 0], "primary", m=True, note="upper flap, open 30 degrees"),
        RB([2.4, 0.3, 3.3], [6.5, 0.5, 11.43], [30, 0, 0], "secondary", m=True, note="lower flap, open 30 degrees"),
        B(7.8, 7.9, 1.2, 1.6, 9.8, 10.9, "thrust", m=True, note="outboard vent on the hinge bar"),
    ] + control_jet(6.5, 1.4, 9.3, 13.6, top=False, side=False)


def s_petal():
    """Record: one tall slab each side, swung out, with two small jets on its trailing edge, top and bottom. No tip pod."""
    return brake_lug() + [
        B(3.4, 5.9, 1.3, 1.85, 11.0, 12.2, "primary", m=True, note="hinge arm: under the exhaust lane"),
        RB([0.25, 2.7, 4.0], [6.2, 1.5, 12.2], [0, 22, 0], "primary", m=True, note="petal slab, swung out"),
        RB([0.32, 0.3, 4.0], [6.2, 3.0, 12.2], [0, 22, 0], "secondary", m=True, note="slab cap"),
    ] + control_jet(7.05, 2.4, 12.6, 15.3, d=0.9, top=True, side=False) + \
        control_jet(7.05, 0.6, 12.6, 15.3, d=0.9, top=False, side=True)


def s_vane_cascade():
    """Prototype: three louvres behind a boom, and a tip jet that fires up or down."""
    ps = brake_lug() + [
        B(3.4, 6.8, 1.3, 1.85, 11.0, 12.2, "primary", m=True, note="boom: under the exhaust lane"),
        B(5.4, 6.9, 1.4, 1.8, 12.1, 12.5, "detail", m=True, note="louvre rail"),
    ]
    for x in (5.95, 6.6, 7.25):
        ps.append(RB([0.2, 2.6, 2.8], [x, 1.6, 13.6], [0, 20, 0], "secondary", m=True, note="louvre vane"))
    ps.append(B(7.82, 7.92, 0.6, 2.2, 11.3, 11.9, "thrust", m=True, note="outboard vent"))
    return ps + lift_jet(7.25, 11.6, 3.1, -0.4, 1.2, body="primary", m=True, tag="tip control jet", both=True)


def s_outrigger():
    """Privateer: long boom, a boxed vectoring lift jet, a weather vane. Vents glow on top and outboard."""
    return brake_lug() + [
        B(3.4, 6.6, 1.3, 1.85, 11.0, 12.2, "primary", m=True, note="outrigger boom: under the exhaust lane"),
        B(7.2, 7.4, 0.5, 2.3, 12.5, 14.6, "primary", m=True, note="weather vane"),
        B(7.15, 7.45, 2.0, 2.3, 12.6, 14.6, "neon", m=True, note="vane light"),
        B(6.4, 7.9, 2.3, 3.1, 10.7, 12.5, "primary", m=True, note="vectoring cowl"),
        B(6.7, 7.6, 3.1, 3.2, 11.0, 12.2, "thrust", m=True, note="upper vent: glows upward"),
        B(7.86, 7.96, 2.5, 2.9, 11.0, 12.2, "thrust", m=True, note="outboard vent"),
    ] + lift_jet(7.2, 11.6, 2.4, -0.5, 1.5, m=True, tag="vectoring lift jet")


def s_paddle():
    """Salvage: a square paddle face on to the air, with the control jet behind its centre."""
    return brake_lug() + [
        B(3.4, 5.4, 1.3, 1.85, 11.0, 12.0, "primary", m=True, note="arm: under the exhaust lane"),
        B(5.3, 7.7, 0.3, 2.9, 12.0, 12.25, "primary", m=True, note="drag paddle, face on to the air"),
        B(6.15, 6.85, 1.25, 1.95, 11.9, 12.05, "detail", m=True, note="jet intake through the paddle"),
        B(5.5, 6.0, 0.5, 1.0, 11.95, 12.3, "detail", m=True, note="vent hole"),
        B(7.0, 7.5, 2.2, 2.7, 11.95, 12.3, "detail", m=True, note="vent hole"),
        B(5.5, 6.4, 2.0, 2.7, 12.25, 12.32, "secondary", note="patch plate (one side only)"),
        B(7.7, 7.8, 1.0, 2.2, 11.9, 12.35, "thrust", m=True, note="outboard vent on the paddle edge"),
    ] + control_jet(6.5, 1.6, 12.25, 14.9, top=True, side=False)


def s_droop():
    """Interceptor: tailerons drooped 40 degrees, so the control jet pod on each tip hangs at sill height."""
    return brake_lug() + [
        B(3.4, 4.0, 1.3, 1.85, 10.6, 12.6, "primary", m=True, note="root block"),
        RB([2.9, 0.25, 3.4], [4.97, 0.85, 11.9], [0, 0, -40], "primary", m=True, note="taileron, drooped 40 degrees"),
        RB([2.9, 0.27, 0.9], [4.97, 0.85, 13.9], [0, 0, -40], "secondary", m=True, note="elevon"),
    ] + control_jet(6.5, -0.05, 10.4, 14.8)


# ---------------------------------------------------------------- RearSpoiler: tail fins
def fin_shoe():
    return [B(FIN_X0, HULL_X, 3.3, 3.6, 11.0, 12.2, "detail", m=True, note="PAD fin shoe: lands on the fin pad")]


def f_twin_canted():
    return fin_shoe() + [
        RW([0.3, 3.4, 4.4], [3.275, 5.217, 12.5], [0, 0, -18], "primary", m=True, note="canted fin"),
        RB([0.34, 0.6, 1.4], [3.71, 6.55, 14.0], [0, 0, -18], "secondary", m=True, note="fin tip"),
    ]


def f_strakes():
    return fin_shoe() + [
        W("up_back", 2.55, 2.85, 3.6, 5.1, 8.6, 13.4, "primary", m=True, note="long low strake"),
        B(2.55, 2.85, 3.6, 5.1, 13.4, 16.0, "primary", m=True, note="strake tail"),
        B(2.53, 2.87, 4.7, 5.1, 14.6, 16.2, "secondary", m=True, note="strake tip"),
    ]


def f_box_wing():
    """Prototype: two swept fins under a slim top plane. Narrow chord, so daylight shows through the box."""
    return fin_shoe() + [
        RW([0.3, 3.0, 3.6], [2.7, 5.1, 12.4], [0, 0, 0], "primary", m=True, note="end fin"),
        B(-3.0, 3.0, 6.5, 6.7, 13.0, 14.6, "secondary", note="slim top plane"),
        B(-0.1, 0.1, 6.7, 6.8, 13.2, 14.4, "neon", note="plane light"),
    ]


def f_v_tail():
    return fin_shoe() + [
        RW([0.3, 3.4, 3.6], [4.063, 4.787, 12.6], [0, 0, -48], "primary", m=True, note="V fin"),
        RB([0.34, 0.6, 1.2], [5.03, 5.66, 13.7], [0, 0, -48], "secondary", m=True, note="fin tip"),
    ]


def f_t_plank():
    return fin_shoe() + [
        RW([0.3, 1.8, 2.2], [2.7, 4.5, 12.1], [0, 0, 0], "primary", m=True, note="swept strut"),
        B(-5.0, 5.0, 5.4, 5.62, 11.6, 14.0, "primary", note="plank"),
        B(5.0, 5.3, 5.0, 6.1, 11.2, 14.4, "secondary", m=True, note="end plate"),
        B(-1.4, 0.2, 5.62, 5.69, 12.0, 13.4, "secondary", note="patch plate"),
    ]


def f_a_tail():
    """Interceptor: two fins lean inward and meet over the afterburner."""
    return fin_shoe() + [
        B(2.45, 2.85, 3.6, 5.3, 11.0, 13.2, "primary", m=True, note="upright"),
        RW([0.3, 3.2, 3.2], [1.45, 6.25, 12.6], [0, 0, 50.8], "primary", m=True, note="inward-canted fin"),
        B(-0.35, 0.35, 7.0, 7.3, 12.8, 14.4, "secondary", note="apex cap"),
    ]


# ---------------------------------------------------------------- RearBumper: the keel
def keel_pad():
    return [B(-0.7, 0.7, -0.65, -0.4, 9.6, 12.4, "detail", note="PAD lands on the drive belly pad")]


def k_keel_fin():
    return keel_pad() + [
        W("dn_back", -0.15, 0.15, -1.7, -0.65, 9.6, 13.0, "primary", note="ventral fin"),
        B(-0.15, 0.15, -1.7, -0.65, 13.0, 14.6, "secondary", note="fin heel"),
    ]


def k_stinger():
    return keel_pad() + [
        CZ(0.9, 0, -1.15, 9.6, 14.0, "primary", note="tail cone"),
        CZ(0.6, 0, -1.15, 14.0, 16.2, "secondary", note="tail cone"),
        CZ(0.3, 0, -1.15, 16.2, 17.0, "neon", note="tail light"),
    ]


def k_diffuser():
    return keel_pad() + [
        B(-1.9, 1.9, -0.9, -0.65, 9.6, 14.6, "primary", note="diffuser plate"),
        W("dn_back", -0.1, 0.1, -1.7, -0.9, 10.0, 14.6, "secondary", note="strake"),
        W("dn_back", 1.3, 1.5, -1.7, -0.9, 10.0, 14.6, "secondary", m=True, note="strake"),
    ]


def k_drogue():
    """Two short drogue tubes side by side on a cross bracket."""
    return keel_pad() + [
        B(-1.3, 1.3, -0.95, -0.65, 10.2, 11.8, "detail", note="cross bracket"),
        CZ(0.85, 1.0, -1.3, 9.8, 13.4, "secondary", m=True, note="drogue tube"),
        CZ(0.95, 1.0, -1.3, 13.2, 14.4, "primary", m=True, note="cap"),
        B(0.9, 1.1, -1.4, -1.2, 14.4, 15.0, "neon", m=True, note="pull tag"),
    ]


def k_skid():
    """Two long skis on short painted legs."""
    return keel_pad() + [
        B(-1.75, 1.75, -0.9, -0.65, 10.0, 10.6, "secondary", note="painted cross strut"),
        B(-1.75, 1.75, -0.9, -0.65, 11.6, 12.2, "secondary", note="painted cross strut"),
        B(1.45, 1.75, -1.3, -0.9, 10.0, 10.6, "primary", m=True, note="leg"),
        B(1.45, 1.75, -1.3, -0.9, 11.6, 12.2, "primary", m=True, note="leg"),
        B(1.3, 1.9, -1.5, -1.3, 9.0, 15.2, "secondary", m=True, note="ski"),
        W("dn_front", 1.3, 1.9, -1.5, -1.0, 15.2, 16.4, "secondary", m=True, note="upturned heel"),
    ]


def k_ventral_v():
    """Interceptor: two ventral fins splayed outward under a small fairing."""
    return keel_pad() + [
        B(-0.5, 0.5, -0.95, -0.65, 9.8, 12.2, "primary", note="fairing"),
        RB([0.2, 1.1, 4.2], [0.95, -1.2, 12.2], [0, 0, 40], "secondary", m=True, note="canted ventral fin"),
    ]


# ---------------------------------------------------------------- frame standard
STANDARD = {
    "cockpitEnvelope": {"min": [-HULL_X, BELLY, Z_FRONT], "max": [HULL_X, ROOF, Z_REAR]},
    "datums": {"beltline": AXIS, "sill": SILL, "hoverPlane": HOVER, "deck": DECK, "roof": ROOF, "belly": BELLY, "driveTop": BOOST_Y,
               "ringFrame": [2 * RING_X, RING_Y1 - RING_Y0]},
    "slots": {
        "FrontBody": {"label": "Prow", "envelope": {"min": [-5, -0.6, Z_PROW], "max": [5, 2.8, Z_FRONT]},
                      "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -5]},
        "FrontBumper": {"label": "Nose Tip", "envelope": {"min": [-5, -0.6, Z_TIP], "max": [5, 2.8, Z_PROW]},
                        "anchor": {"to": "FrontBody", "face": "+z"}, "explode": [0, 0, -9]},
        "SidePods": {"label": "Wings", "envelope": {"min": [HULL_X, -1.6, Z_FRONT], "max": [8, 1.7, Z_REAR], "mirror": True},
                     "anchor": {"to": "cockpit", "face": "-x"}, "explode": [5, -2, 0]},
        "Engine2": {"label": "Wing Engines", "envelope": {"min": [HULL_X, 1.7, -1], "max": [5.8, 4.2, Z_REAR], "mirror": True},
                    "anchor": {"to": "cockpit", "face": "-x"}, "explode": [3, 4, 0]},
        "Engine1": {"label": "Main Drive", "envelope": [{"min": [-HULL_X, -0.4, Z_REAR], "max": [HULL_X, BOOST_Y, Z_DRIVE]},
                                                        {"min": [-2.4, BOOST_Y, Z_REAR], "max": [2.4, 4.6, 10.2]}],
                    "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 0, 5]},
        "Boost": {"label": "Afterburner", "envelope": {"min": [-2.4, BOOST_Y, 10.2], "max": [2.4, 5.2, 16.5]},
                  "anchor": {"to": "Engine1", "face": "-y"}, "explode": [0, 4, 9]},
        "Stabilisers": {"label": "Airbrakes", "envelope": {"min": [HULL_X, -0.6, Z_REAR], "max": [8, 3.3, 15.5], "mirror": True},
                        "anchor": {"to": "Engine1", "face": "-x"}, "explode": [5, 0, 7]},
        "RearSpoiler": {"label": "Tail Fins", "envelope": [{"min": [FIN_X0, 3.3, Z_REAR], "max": [6, 7.4, 16.5], "mirror": True},
                                                            {"min": [-FIN_X0, 5.2, Z_REAR], "max": [FIN_X0, 7.4, 16.5]}],
                        "anchor": {"to": "Engine1", "face": "-y"}, "explode": [0, 9, 5]},
        "RearBumper": {"label": "Keel", "envelope": {"min": [-2, -1.8, Z_REAR], "max": [2, -0.4, 17]},
                       "anchor": {"to": "Engine1", "face": "+y"}, "explode": [0, -4, 6]},
    },
}

COCKPITS = {
    "needle": {"name": "Needle", "culture": "Record Breaker", "kit": "record", "parts": cockpit_needle(),
               "note": "Round tube over a slim belly tank. Long bare nose, small canopy far aft, razorback."},
    "delta": {"name": "Delta", "culture": "Works Team", "kit": "works", "parts": cockpit_delta(),
              "note": "Faceted wedge. One long windscreen to a peak at Y 5.5, full-length dorsal spine fin."},
    "manta": {"name": "Manta", "culture": "Prototype", "kit": "proto", "parts": cockpit_manta(),
              "note": "Flat ray. Wafer hull 1.3 thick, wide low blister, two horns above the deck reaching forward."},
    "twinboom": {"name": "Twinboom", "culture": "Privateer", "kit": "privateer", "parts": cockpit_twinboom(),
                 "note": "Slim pod with a raked wedge canopy far forward, between two booms that run on alone to a tail yoke."},
    "bubble": {"name": "Bubble", "culture": "Salvage", "kit": "salvage", "parts": cockpit_bubble(),
               "note": "Big glass dome far forward on a keel beam, a round pressure tank behind it, side tanks on a flat shelf."},
    "arrowhead": {"name": "Arrowhead", "culture": "Interceptor", "kit": "interceptor", "parts": cockpit_arrowhead(),
                  "note": "Arrow-shaped hull with swept barbs. Triangular canopy, two low canted deck strakes and a short ventral fletch."},
}


def mod(name, culture, parts, note=None):
    m = {"name": name, "culture": culture, "parts": parts}
    if note:
        m["note"] = note
    return m


REC, WRK, PRO, PRI, SAL, INT = "Record Breaker", "Works Team", "Prototype", "Privateer", "Salvage", "Interceptor"

MODULES = {
    "Engine1": {
        "mono_turbine": mod("Mono Turbine", REC, e1_mono_turbine(), "One big turbine with a raked dorsal scoop."),
        "twin_drive": mod("Twin Drive", WRK, e1_twin_drive(), "Two big barrels wide apart behind square box intakes."),
        "slot_burner": mod("Slot Burner", PRO, e1_slot_burner(), "One flat wide fishtail burner under a dorsal spine."),
        "quad_cluster": mod("Quad Cluster", PRI, e1_quad_cluster(), "Four jets in a 2 x 2 block."),
        "rack_triple": mod("Rack Triple", SAL, e1_rack_triple(), "Three big scavenged jets in a shallow V: one low on the centreline, one high each side."),
        "vector_blade": mod("Vector Blade", INT, e1_vector_blade(), "One tall thin vertical slot nozzle with ramp intakes."),
    },
    "Engine2": {
        "lance": mod("Lance Ramjets", REC, e2_lance(), "Thin, full length, shock probe."),
        "twin_turbine": mod("Shoulder Turbines", WRK, e2_twin_turbine(), "One round nacelle each side with a shock cone."),
        "slot": mod("Slot Ramjets", PRO, e2_slot(), "Flat boxes with slot intakes."),
        "stacked": mod("Stacked Pair", PRI, e2_stacked(), "Two slim jets, over and under, full length."),
        "stub_radial": mod("Scoop Burners", SAL, e2_stub_radial(), "Big square scoop forward, fat burner, long thin tailpipe."),
        "chine": mod("Chine Ramjets", INT, e2_chine(), "Faceted, sloped outer face, swept ramp lip, square nozzle."),
    },
    "Stabilisers": {
        "petal": mod("Petal Slabs", REC, s_petal(), "One tall slab each side, swung out, two small jets on its trailing edge."),
        "clamshell": mod("Clamshell", WRK, s_clamshell(), "Two flaps open 30 degrees like a jaw, jet between them at the hinge."),
        "vane_cascade": mod("Vane Cascade", PRO, s_vane_cascade(), "Three louvres behind a boom, tip jet that fires up or down."),
        "outrigger": mod("Outrigger Jets", PRI, s_outrigger(), "Long boom, boxed vectoring lift jet, weather vane."),
        "paddle": mod("Drag Paddles", SAL, s_paddle(), "Square paddle face on to the air, jet behind its centre."),
        "droop": mod("Droop Tailerons", INT, s_droop(), "Tailerons drooped 40 degrees, a jet pod at sill height on each tip."),
    },
    "Boost": {
        "stinger": mod("Stinger", REC, b_stinger(), "One long thin tube, 0.8 across, with a small flared bell."),
        "twin_cans": mod("Twin Cans", WRK, b_twin_cans(), "Two fat cans, touching."),
        "slot": mod("Slot Afterburner", PRO, b_slot(), "Flat fishtail burner."),
        "staged": mod("Staged Bell", PRI, b_staged(), "Short fat stepped cone, three stages up to a full-height bell."),
        "bottles": mod("Rocket Bottles", SAL, b_bottles(), "Four thin pointed bottles in an arch, firing well aft."),
        "aerospike": mod("Aerospike", INT, b_aerospike(), "Square plug body, four vanes, glowing stepped spike."),
    },
    "FrontBody": {
        "spear": mod("Spear", REC, prow_spear(), "One stepped lance."),
        "twin_prong": mod("Twin Prong", WRK, prow_twin_prong(), "Two tall blades, open slot between."),
        "trident": mod("Trident", PRO, prow_trident(), "Three prongs, the outer two drooped low."),
        "hammerhead": mod("Hammerhead", PRI, prow_hammerhead(), "Crossbar with long pointed end pods."),
        "spade": mod("Spade", SAL, prow_spade(), "Wide flat shovel ramp with teeth."),
        "broadhead": mod("Broadhead", INT, prow_broadhead(), "One flat arrowhead blade with swept barbs."),
    },
    "SidePods": {
        "stub": mod("Stub Winglets", REC, wing_stub(), "The narrowest build."),
        "delta": mod("Delta Wings", WRK, wing_delta(), "Swept delta, downturned tips."),
        "forward_swept": mod("Forward Swept", PRO, wing_forward_swept(), "Blades angled forward."),
        "pontoons": mod("Pontoons", PRI, wing_pontoons(), "Long floats on two struts."),
        "plank": mod("Plank Wings", SAL, wing_plank(), "Straight planks, end plates, drop tanks."),
        "tandem": mod("Tandem Blades", INT, wing_tandem(), "Two swept-back blades each side."),
    },
    "FrontBumper": {
        "pitot": mod("Pitot Spike", REC, tip_pitot()),
        "canards": mod("Canards", WRK, tip_canards()),
        "sensor_blade": mod("Sensor Blade", PRO, tip_sensor_blade()),
        "ram_scoop": mod("Ram Scoop", PRI, tip_ram_scoop()),
        "bash_bar": mod("Bash Bar", SAL, tip_bash_bar()),
        "chisel": mod("Chisel Point", INT, tip_chisel()),
    },
    "RearBumper": {
        "stinger": mod("Tail Stinger", REC, k_stinger()),
        "keel_fin": mod("Keel Fin", WRK, k_keel_fin()),
        "diffuser": mod("Diffuser", PRO, k_diffuser()),
        "drogue": mod("Drogue Pod", PRI, k_drogue()),
        "skid": mod("Skid", SAL, k_skid()),
        "ventral_v": mod("Ventral V", INT, k_ventral_v()),
    },
    "RearSpoiler": {
        "strakes": mod("Strake Fins", REC, f_strakes(), "Long and low."),
        "twin_canted": mod("Twin Fins", WRK, f_twin_canted(), "Two tall canted fins."),
        "box_wing": mod("Box Wing", PRO, f_box_wing(), "Two swept fins under a slim top plane."),
        "v_tail": mod("V-Tail", PRI, f_v_tail(), "Wide V."),
        "t_plank": mod("Plank Spoiler", SAL, f_t_plank(), "Wide plank on two swept struts."),
        "a_tail": mod("A-Tail", INT, f_a_tail(), "Two fins lean inward and meet."),
    },
}

KIT_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost", "FrontBody", "SidePods", "FrontBumper", "RearBumper", "RearSpoiler"]


def kit(name, culture, *mods):
    return {"name": name, "culture": culture, "modules": dict(zip(KIT_ORDER, mods))}


KITS = {
    "record": kit("Record", REC, "mono_turbine", "lance", "petal", "stinger", "spear", "stub", "pitot", "stinger", "strakes"),
    "works": kit("Works", WRK, "twin_drive", "twin_turbine", "clamshell", "twin_cans", "twin_prong", "delta", "canards", "keel_fin", "twin_canted"),
    "proto": kit("Prototype", PRO, "slot_burner", "slot", "vane_cascade", "slot", "trident", "forward_swept", "sensor_blade", "diffuser", "box_wing"),
    "privateer": kit("Privateer", PRI, "quad_cluster", "stacked", "outrigger", "staged", "hammerhead", "pontoons", "ram_scoop", "drogue", "v_tail"),
    "salvage": kit("Salvage", SAL, "rack_triple", "stub_radial", "paddle", "bottles", "spade", "plank", "bash_bar", "skid", "t_plank"),
    "interceptor": kit("Interceptor", INT, "vector_blade", "chine", "droop", "aerospike", "broadhead", "tandem", "chisel", "ventral_v", "a_tail"),
}

PAINT = {
    "record": {"primary": "#c9ced6", "secondary": "#d0312d", "neon": "#ff6a3c"},
    "works": {"primary": "#1f5fd0", "secondary": "#f2f2f2", "neon": "#ffe14a"},
    "proto": {"primary": "#f08a1a", "secondary": "#2b2f38", "neon": "#7ff0ff"},
    "privateer": {"primary": "#1f8a5a", "secondary": "#ece4cc", "neon": "#ff4fd8"},
    "salvage": {"primary": "#9a4a2a", "secondary": "#b9ad94", "neon": "#9dff5a"},
    "interceptor": {"primary": "#6f47c7", "secondary": "#f2c230", "neon": "#ff5a5a"},
}

BUILDS = [
    {"name": "Needle, own Record kit", "cockpit": "needle", "kit": "record", "paint": PAINT["record"]},
    {"name": "Needle, Works kit", "cockpit": "needle", "kit": "works", "paint": PAINT["record"]},
    {"name": "Delta, own Works kit", "cockpit": "delta", "kit": "works", "paint": PAINT["works"]},
    {"name": "Delta, Prototype kit", "cockpit": "delta", "kit": "proto", "paint": PAINT["works"]},
    {"name": "Manta, own Prototype kit", "cockpit": "manta", "kit": "proto", "paint": PAINT["proto"]},
    {"name": "Manta, Privateer kit", "cockpit": "manta", "kit": "privateer", "paint": PAINT["proto"]},
    {"name": "Twinboom, own Privateer kit", "cockpit": "twinboom", "kit": "privateer", "paint": PAINT["privateer"]},
    {"name": "Twinboom, Salvage kit", "cockpit": "twinboom", "kit": "salvage", "paint": PAINT["privateer"]},
    {"name": "Bubble, own Salvage kit", "cockpit": "bubble", "kit": "salvage", "paint": PAINT["salvage"]},
    {"name": "Bubble, Interceptor kit", "cockpit": "bubble", "kit": "interceptor", "paint": PAINT["salvage"]},
    {"name": "Arrowhead, own Interceptor kit", "cockpit": "arrowhead", "kit": "interceptor", "paint": PAINT["interceptor"]},
    {"name": "Arrowhead, Record kit", "cockpit": "arrowhead", "kit": "record", "paint": PAINT["interceptor"]},
    {"name": "Mixed: Delta sprint special", "cockpit": "delta", "kit": "works",
     "modules": {"Engine1": "mono_turbine", "Boost": "stinger", "FrontBody": "spear", "SidePods": "forward_swept", "RearSpoiler": "v_tail"},
     "paint": {"primary": "#b0182a", "secondary": "#f4d35e", "neon": "#ffd27a"}},
    {"name": "Mixed: Manta scrap hauler", "cockpit": "manta", "kit": "salvage",
     "modules": {"Engine1": "quad_cluster", "Engine2": "slot", "Stabilisers": "outrigger", "FrontBody": "hammerhead", "Boost": "aerospike"},
     "paint": {"primary": "#16818c", "secondary": "#e2c53a", "neon": "#7dffb0"}},
]

SPEC = {
    "id": "dart",
    "displayName": "Dart",
    "tagline": "Anti-grav racing darts: a slender fuselage, a pronged prow, stub wings and a tail full of jets.",
    "standard": STANDARD,
    "cockpits": COCKPITS,
    "kits": KITS,
    "modules": MODULES,
    "builds": BUILDS,
}


# ---------------------------------------------------------------- class rules the shared validator does not know
COCKPIT_FREE_TARGET = 0.35    # free-outline score between any two fuselages (the validator's own measure; its floor is 0.25)
COCKPIT_WHOLE_TARGET = 0.35   # whole-outline score: pairs under it are listed as notes, not failures.
#                               Every fuselage shares the ring frames, the four pads and the wing-root width,
#                               so the plan views overlap by design (see dart-frame.md, open risks).
MIN_CONTROL_JET = 0.5         # smallest allowed control-jet thrust, across
# Nozzle size ladder: allowed diameter of every round aft-facing glow, per slot. Main-drive glows are 1.4 or more,
# boost and wing-engine glows 1.15 or less, control jets 0.65 or less, so the tail never reads as a bundle of equal pipes.
LADDER = {"Engine1": (1.4, 9.0), "Boost": (0.3, 1.15), "Engine2": (0.85, 1.15), "Stabilisers": (0.5, 0.65)}
BOOST_AFT = 15.0              # every afterburner glow ends at Z 15 or further aft, behind the main-drive nozzles (Z 14.5)
LANE = (3.4, 5.2, 1.9, 3.3)   # wing-engine exhaust lane (X0, X1, Y0, Y1): no airbrake part may stand in it


def _aabb(p):
    """Bounds of an unrotated part (rotated parts are skipped by the callers)."""
    hx, hy, hz = [s / 2 for s in p["size"]]
    x, y, z = p["pos"]
    return (x - hx, x + hx, y - hy, y + hy, z - hz, z + hz)


def _thrust_area(parts):
    """Aft-facing glow area of a module: thrust parts seen along Z. Concentric stages count once."""
    best = {}
    for p in parts:
        if p["ch"] != "thrust" or p["shape"] not in ("cyl_z", "block"):
            continue
        sx, sy, _ = p["size"]
        area = math.pi * (min(sx, sy) / 2) ** 2 if p["shape"] == "cyl_z" else sx * sy
        if p.get("mirror"):
            area *= 2
        key = (round(p["pos"][0], 2), round(p["pos"][1], 2))
        best[key] = max(best.get(key, 0.0), area)
    return sum(best.values())


def _has_section(parts, z, painted):
    """True if one part at station z is at least the 2.2 x 1.9 neck section on the thrust axis."""
    for p in parts:
        if p.get("rot") and p["shape"] != "wedge":
            continue
        if painted and p["ch"] in ("detail", "glass", "driver", "neon", "thrust"):
            continue
        if p["shape"] == "wedge":
            continue
        x0, x1, y0, y1, z0, z1 = _aabb(p)
        if z0 - 1e-6 <= z <= z1 + 1e-6 and x0 <= -NECK_X + 1e-6 and x1 >= NECK_X - 1e-6 and y0 <= NECK_Y0 + 1e-6 and y1 >= NECK_Y1 - 1e-6:
            return True
    return False


def self_check(spec):
    """Returns (problems, notes, info). No problems means every Dart class rule holds."""
    problems, notes = [], []
    mods = spec["modules"]
    # 1. The main drive has more thrust area than any afterburner or wing-engine pair.
    area = {s: {m: _thrust_area(e["parts"]) for m, e in mods[s].items()} for s in ("Engine1", "Engine2", "Boost")}
    low_id = min(area["Engine1"], key=area["Engine1"].get)
    for s in ("Engine2", "Boost"):
        for m, a in area[s].items():
            if a >= area["Engine1"][low_id]:
                problems.append("thrust: %s/%s (%.2f) is not smaller than Engine1/%s (%.2f)" % (s, m, a, low_id, area["Engine1"][low_id]))
    # 2. No wasp waist: ring-section or neck-section body next to both seams.
    for m, e in mods["FrontBody"].items():
        for z in (Z_FRONT - 0.6, Z_FRONT - 1.2, Z_FRONT - 1.8):
            if not _has_section(e["parts"], z, True):
                problems.append("neck: FrontBody/%s is thinner than 2.2 x 1.9 at Z %.1f" % (m, z))
    for m, e in mods["Engine1"].items():
        for z in (Z_REAR + 0.6, Z_REAR + 1.2, Z_REAR + 1.8):
            if not _has_section(e["parts"], z, True):
                problems.append("neck: Engine1/%s is thinner than 2.2 x 1.9 at Z %.1f" % (m, z))
    for c, e in spec["cockpits"].items():
        for z in (Z_FRONT + 0.5, Z_FRONT + 1.0, Z_REAR - 1.0, Z_REAR - 0.5):
            if not _has_section(e["parts"], z, True):
                problems.append("neck: cockpit %s is thinner than 2.2 x 1.9 at Z %.1f" % (c, z))
    sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
    import vbspec
    # 3. Airbrakes are jet hardware: a real control jet, and a glow that faces up or outboard.
    #    They also keep out of the wing-engine exhaust lane, so the wing-engine glow shows from a low chase camera.
    for m, e in mods["Stabilisers"].items():
        glow = [p for p in e["parts"] if p["ch"] == "thrust"]
        widest = max([min(p["size"][0], p["size"][1]) if p["shape"] == "cyl_z" else min(p["size"][0], p["size"][2])
                      for p in glow if p["shape"] in ("cyl_z", "cyl_y")] or [0])
        if widest < MIN_CONTROL_JET:
            problems.append("stabiliser: %s control-jet thrust is %.2f across, want %.1f or more" % (m, widest, MIN_CONTROL_JET))
        if not any("vent" in (p.get("note") or "") for p in glow):
            problems.append("stabiliser: %s has no glow facing up or outboard" % m)
        for p in vbspec.expand_parts(e["parts"]):
            w, _ = vbspec.world_mesh(p)
            lo, hi = w.min(axis=0), w.max(axis=0)
            if hi[0] > LANE[0] + 0.02 and lo[0] < LANE[1] - 0.02 and hi[1] > LANE[2] + 0.02 and lo[1] < LANE[3] - 0.02:
                problems.append("stabiliser: %s part '%s' stands in the wing-engine exhaust lane" % (m, p.get("note")))
                break
    # 4. Nozzle size ladder: round aft-facing glows. Main drive biggest, then boost, wing engines, control jets.
    round_glow = {s: {m: [min(p["size"][0], p["size"][1]) for p in e["parts"] if p["ch"] == "thrust" and p["shape"] == "cyl_z"]
                      for m, e in mods[s].items()} for s in LADDER}
    for s, (lo, hi) in LADDER.items():
        for m, ds in round_glow[s].items():
            for d in ds:
                if d < lo - 1e-6 or d > hi + 1e-6:
                    problems.append("ladder: %s/%s has a round glow %.2f across, want %.2f to %.2f" % (s, m, d, lo, hi))
    for m, e in mods["Boost"].items():
        aft = max(_aabb(p)[5] for p in e["parts"] if p["ch"] == "thrust")
        if aft < BOOST_AFT - 1e-6:
            problems.append("ladder: Boost/%s ends at Z %.1f, want %.1f or more so the boost fires behind the main drive" % (m, aft, BOOST_AFT))
    # 5. Fuselages differ: 0.35 or more on the free outline. Whole-outline pairs under 0.35 are reported as notes.
    table = vbspec.distinct_table({c: vbspec.expand_parts(e["parts"]) for c, e in spec["cockpits"].items()})
    for (a, b), (free, raw) in sorted(table.items(), key=lambda kv: kv[1][1]):
        if free < COCKPIT_FREE_TARGET:
            problems.append("cockpits %s and %s: free-outline score %.2f, want %.2f or more" % (a, b, free, COCKPIT_FREE_TARGET))
        if raw < COCKPIT_WHOLE_TARGET:
            notes.append("cockpits %s and %s: whole-outline score %.2f (target %.2f)" % (a, b, raw, COCKPIT_WHOLE_TARGET))
    info = {"thrust_area": {s: {m: round(a, 2) for m, a in v.items()} for s, v in area.items()},
            "cockpit_whole_min": round(float(min(v[1] for v in table.values())), 2),
            "cockpit_free_min": round(float(min(v[0] for v in table.values())), 2)}
    return problems, notes, info


# ---------------------------------------------------------------- writer (one part per line)
def dump(spec):
    def parts_block(parts, ind):
        return "[\n" + ",\n".join(ind + "  " + json.dumps(p) for p in parts) + "\n" + ind + "]"

    def entry(e, ind):
        keys = [k for k in e if k != "parts"]
        body = [ind + "  " + json.dumps(k) + ": " + json.dumps(e[k]) for k in keys]
        body.append(ind + "  \"parts\": " + parts_block(e["parts"], ind + "  "))
        return "{\n" + ",\n".join(body) + "\n" + ind + "}"

    out = ["{"]
    for k in ("id", "displayName", "tagline"):
        out.append("  %s: %s," % (json.dumps(k), json.dumps(spec[k])))
    std = spec["standard"]
    out.append("  \"standard\": {")
    out.append("    \"cockpitEnvelope\": %s," % json.dumps(std["cockpitEnvelope"]))
    out.append("    \"datums\": %s," % json.dumps(std["datums"]))
    out.append("    \"slots\": {")
    out.append(",\n".join("      %s: %s" % (json.dumps(s), json.dumps(d)) for s, d in std["slots"].items()))
    out.append("    }")
    out.append("  },")
    out.append("  \"cockpits\": {")
    out.append(",\n".join("    %s: %s" % (json.dumps(c), entry(e, "    ")) for c, e in spec["cockpits"].items()))
    out.append("  },")
    out.append("  \"kits\": {")
    out.append(",\n".join("    %s: %s" % (json.dumps(k), json.dumps(v)) for k, v in spec["kits"].items()))
    out.append("  },")
    out.append("  \"modules\": {")
    slots = []
    for s, mods in spec["modules"].items():
        slots.append("    %s: {\n" % json.dumps(s) + ",\n".join("      %s: %s" % (json.dumps(m), entry(e, "      ")) for m, e in mods.items()) + "\n    }")
    out.append(",\n".join(slots))
    out.append("  },")
    out.append("  \"builds\": [")
    out.append(",\n".join("    " + json.dumps(b) for b in spec["builds"]))
    out.append("  ]")
    out.append("}")
    return "\n".join(out) + "\n"


def main():
    text = dump(SPEC)
    json.loads(text)  # must round-trip
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    n_mod = sum(len(m) for m in MODULES.values())
    print("wrote %s: %d cockpits, %d kits, %d modules, %d builds" % (OUT, len(COCKPITS), len(KITS), n_mod, len(BUILDS)))
    problems, notes, info = self_check(SPEC)
    print("class rules: %d problem(s), %d note(s) %s" % (len(problems), len(notes), info))
    for p in problems:
        print("  RULE  " + p)
    for n in notes:
        print("  note  " + n)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
