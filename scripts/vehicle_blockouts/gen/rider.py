"""Generator for the Rider (hoverbike) frame-class blockout spec, round 2.

Run from the repo root:
  py -3 scripts/vehicle_blockouts/gen/rider.py
  py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/rider.json

Design exploration only. Root space: +X right, +Y up, forward is -Z. Units are studs.

Layout in one paragraph: the cockpit is a spine, a neck, a rear plate, the seat, its own bodywork
(hump, frame, boards, tub) and the rider. Everything else bolts to pads. The four fundamentals are the
bike's stance: Stabilisers = the front end (fork plus lift jets), Engine1 = the main turbine under the
tank with its exhaust run out under the swingarm, Engine2 = the rear end (swingarm plus thruster),
Boost = the afterburner pipes on the flanks.
No rings, discs or hoops anywhere: every jet is longer than it is wide.
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "specs", "rider.json"))

# ----------------------------------------------------------------------------- datums
HOVER = -2.0          # hover plane (ground)
FLOOR = -1.6          # nothing goes below this
SILL = 0.3            # leg channel floor: below it the engine may be wide
BELT = 2.2            # spine top: tank and seat sit on it
SPINE_Y = (1.75, 2.2)
NECK_Z = (-3.1, -2.6)  # steering head block, front face is the fork pad
NECK_Y = (1.6, 3.3)    # top face is the bar clamp pad
PLATE_Z = (2.7, 3.3)   # rear plate, rear face is the swingarm pad
SEAT_TAIL = (3.3, 3.4)  # (z, top y): every cockpit ends here, every seat unit starts here, so no hump ends in a cliff
HAND = (1.15, 4.0, -1.3)  # hand datum: every rider's hands, every bar's grips
FORK_PAD_Y = (1.7, 2.9)   # fork yokes land on the neck front between these heights
FAIRING_PAD_Y = (2.97, 3.27)  # fairing bracket lands on the neck front above the fork
DECK_X, DECK_Y, DECK_Z = (-0.7, 0.7), 4.35, (-4.8, -3.6)  # screen deck: flat top on every fairing; a screen never leaves this footprint
TUNNEL_Y = -1.07  # centre line of the exhaust tunnel under the swingarm: Main Turbine exhausts exit here
RAIL = ((-0.3, 0.3), (1.9, 2.15), (3.4, 6.7))       # tail rail on every seat unit: tail kits bolt to its end
HANGER = ((0.75, 1.45), (0.45, 0.85), (2.8, 3.25))  # exhaust hanger on every cockpit: boost brackets land on it
STAY_FRONT_Z = (-2.0, -1.8)  # panel stay stations on every cockpit
STAY_REAR_Z = (2.9, 3.1)
LEG_X = 1.38  # leg centre line: legs run outside the frame spars, inside the side panels


# ----------------------------------------------------------------------------- part helpers
def r3(v):
    return [round(float(x), 3) for x in v]


def P(shape, size, pos, ch="primary", rot=None, mirror=False, note=""):
    d = {"shape": shape, "size": r3(size), "pos": r3(pos), "ch": ch}
    if rot is not None and any(abs(a) > 1e-6 for a in rot):
        d["rot"] = r3(rot)
    if mirror:
        d["mirror"] = True
    if note:
        d["note"] = note
    return d


def box(x, y, z, ch="primary", mirror=False, note=""):
    """Axis-aligned block from bounds: x=(lo,hi), y=(lo,hi), z=(lo,hi)."""
    return P("block", [x[1] - x[0], y[1] - y[0], z[1] - z[0]],
             [(x[0] + x[1]) / 2, (y[0] + y[1]) / 2, (z[0] + z[1]) / 2], ch, None, mirror, note)


WEDGE_ROT = {
    "nose": None,            # flat bottom, thin edge at the front, tall at the back
    "tail": [0, 180, 0],     # flat bottom, tall at the front, thin edge at the back
    "chin": [0, 0, 180],     # flat top, thin edge at the front, underside drops toward the back
    "kick": [180, 0, 0],     # flat top, tall at the front, underside rises toward the back
}


def wedge(x, y, z, kind="nose", ch="primary", mirror=False, note=""):
    return P("wedge", [x[1] - x[0], y[1] - y[0], z[1] - z[0]],
             [(x[0] + x[1]) / 2, (y[0] + y[1]) / 2, (z[0] + z[1]) / 2], ch, WEDGE_ROT[kind], mirror, note)


def delta(x0, x1, y, z, ch="primary", note=""):
    """A flat delta strake on the +X side (mirrored): a point at the front, full span x0..x1 at the back."""
    return P("wedge", [y[1] - y[0], x1 - x0, z[1] - z[0]],
             [(x0 + x1) / 2, (y[0] + y[1]) / 2, (z[0] + z[1]) / 2], ch, [0, 0, -90], True, note)


def cz(x, y, z0, z1, dia, ch="primary", mirror=False, note=""):
    return P("cyl_z", [dia, dia, z1 - z0], [x, y, (z0 + z1) / 2], ch, None, mirror, note)


def cy(x, z, y0, y1, dia, ch="primary", mirror=False, note=""):
    return P("cyl_y", [dia, y1 - y0, dia], [x, (y0 + y1) / 2, z], ch, None, mirror, note)


def cx(y, z, x0, x1, dia, ch="primary", mirror=False, note=""):
    return P("cyl_x", [x1 - x0, dia, dia], [(x0 + x1) / 2, y, z], ch, None, mirror, note)


def ball(dia, pos, ch="primary", mirror=False, note=""):
    return P("ball", [dia, dia, dia], pos, ch, None, mirror, note)


def _aim(p0, p1):
    """Orientation that points local +Z from p0 to p1, plus the length."""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    rx = -math.degrees(math.asin(dy / length))
    ry = math.degrees(math.atan2(dx, dz))
    mid = [(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2]
    return [rx, ry, 0], length, mid


def tube(p0, p1, dia, ch="detail", mirror=False, note=""):
    rot, length, mid = _aim(p0, p1)
    return P("cyl_z", [dia, dia, length], mid, ch, rot, mirror, note)


def beam(p0, p1, w, h, ch="detail", mirror=False, note=""):
    rot, length, mid = _aim(p0, p1)
    return P("block", [w, h, length], mid, ch, rot, mirror, note)


def lerp(p0, p1, t):
    return [p0[i] + (p1[i] - p0[i]) * t for i in range(3)]


def jet(p0, p1, dia, ch="secondary", mirror=False, cowl=0.26, noz=0.24, glow=0.2, spinner=True, name="jet", cowl_ch="detail"):
    """A jet along p0 -> p1: intake cowl, coloured body, dark nozzle, glowing thrust plug.
    Every stage is longer than 0.45 x its width, so nothing reads as a disc."""
    length = math.dist(p0, p1)
    a, b = lerp(p0, p1, cowl), lerp(p0, p1, 1 - noz)
    end = lerp(p0, p1, 1 + glow / length)
    out = [tube(p0, a, dia, cowl_ch, mirror, name + " intake cowl"),
           tube(a, b, dia * 0.9, ch, mirror, name + " body"),
           tube(b, p1, dia * 0.74, "detail", mirror, name + " nozzle"),
           tube(p1, end, dia * 0.54, "thrust", mirror, name + " thrust")]
    if spinner:
        out.append(ball(dia * 0.46, lerp(p0, p1, 0.1 * dia / length), "secondary", mirror, name + " intake spinner"))
    return out


def jet_z(x, y, z0, z1, dia, ch="secondary", mirror=False, **kw):
    return jet([x, y, z0], [x, y, z1], dia, ch, mirror, **kw)


def lift_jet(x, z, y_top, y_bot, dia, ch="secondary", mirror=False, name="lift jet", cowl_ch="detail"):
    """A downward lift jet: intake on top, nozzle and thrust plug underneath."""
    return jet([x, y_top, z], [x, y_bot, z], dia, ch, mirror, cowl=0.28, noz=0.22, glow=0.22, spinner=False, name=name, cowl_ch=cowl_ch)


def pod(x, y, z0, z1, dia, ch="primary", mirror=False, name="lift pod", nose_ch=None):
    """A lift pod along Z: bullet nose, body, top intake scoop, belly lift slot with thrust, tail nozzle with thrust.
    Bullet nose and painted body, so it never reads as a wheel on the end of a fork."""
    r = dia / 2
    length = z1 - z0
    zb = z1 - 0.2 * length
    return [
        ball(dia, [x, y, z0 + r], nose_ch or ch, mirror, name + " bullet nose"),
        cz(x, y, z0 + r, zb, dia, ch, mirror, name + " body"),
        cz(x, y, zb, z1, dia * 0.72, "detail", mirror, name + " tail nozzle"),
        cz(x, y, z1, z1 + 0.18, dia * 0.5, "thrust", mirror, name + " tail thrust"),
        box((x - 0.3 * dia, x + 0.3 * dia), (y + r - 0.08, y + r + 0.2), (z0 + r + 0.15, z0 + r + 0.15 + 0.3 * length),
            "detail", mirror, name + " top intake scoop"),
        box((x - 0.28 * dia, x + 0.28 * dia), (y - r - 0.16, y - r + 0.08), (z0 + 0.3 * length, z0 + 0.75 * length),
            "detail", mirror, name + " belly lift slot"),
        box((x - 0.2 * dia, x + 0.2 * dia), (y - r - 0.3, y - r - 0.16), (z0 + 0.34 * length, z0 + 0.71 * length),
            "thrust", mirror, name + " lift thrust"),
    ]


def nacelle(x, y, z, ch="primary", mirror=False, name="lift pod", nose=0.3, tail=0.16):
    """A boxy lift pod from bounds: pointed wedge nose, body, top intake scoop, glowing lift plate, slot nozzle.
    Square in section with a sharp nose, so it can never read as a wheel or a ball on the end of a fork."""
    (x0, x1), (y0, y1), (z0, z1) = x, y, z
    w, h, length = x1 - x0, y1 - y0, z1 - z0
    zn, zt, ym = z0 + nose * length, z1 - tail * length, (y0 + y1) / 2
    return [
        wedge((x0, x1), (ym, y1), (z0, zn), "nose", ch, mirror, name + " nose top"),
        wedge((x0, x1), (y0, ym), (z0, zn), "chin", ch, mirror, name + " nose keel"),
        box((x0, x1), (y0, y1), (zn, zt), ch, mirror, name + " body"),
        box((x0 + 0.12 * w, x1 - 0.12 * w), (y0 + 0.15 * h, y1 - 0.15 * h), (zt, z1), "detail", mirror, name + " slot nozzle"),
        box((x0 + 0.22 * w, x1 - 0.22 * w), (y0 + 0.28 * h, y1 - 0.28 * h), (z1, z1 + 0.16), "thrust", mirror, name + " tail thrust"),
        box((x0 + 0.2 * w, x1 - 0.2 * w), (y1, y1 + 0.14), (zn + 0.1, zn + 0.1 + 0.3 * length), "detail", mirror, name + " top intake scoop"),
        box((x0 - 0.14, x1 + 0.14), (y0 - 0.14, y0 + 0.1), (zn + 0.1 * length, zt - 0.05 * length), "thrust", mirror, name + " lift thrust plate"),
    ]


def stub(p0, p1, dia, mirror=True, name="vector nozzle"):
    """A short vectoring nozzle with its thrust plug."""
    length = math.dist(p0, p1)
    return [tube(p0, p1, dia, "detail", mirror, name),
            tube(p1, lerp(p0, p1, 1 + 0.22 / length), dia * 0.7, "thrust", mirror, name + " thrust")]


# ----------------------------------------------------------------------------- frame standard
def env(x, y, z, mirror=False, note=""):
    d = {"min": r3([x[0], y[0], z[0]]), "max": r3([x[1], y[1], z[1]])}
    if mirror:
        d["mirror"] = True
    if note:
        d["note"] = note
    return d


STANDARD = {
    "cockpitEnvelope": [
        env((-0.9, 0.9), (1.6, 2.2), (-3.1, 3.3), note="spine"),
        env((-0.9, 0.9), (2.2, 3.4), (-3.1, -2.6), note="neck: fork pad on the front, bar pad on top"),
        env((-0.9, 0.9), (2.2, 3.4), (0.15, 3.3), note="seat"),
        env((-0.9, 0.9), (0.3, 1.6), (2.6, 3.3), note="rear plate: swingarm pad"),
        env((0.9, 1.7), (0.4, 3.4), (-1.2, 3.3), mirror=True, note="leg channel: legs and the cockpit's own frame, boards or tub"),
        env((0.9, 1.7), (0.4, 2.2), (-2.2, -1.2), mirror=True, note="forward-control leg channel"),
        env((1.7, 2.4), (0.4, 1.3), (-2.2, 0.6), mirror=True, note="running-board shelf, under the side panels"),
        env((-2.2, 2.2), (3.4, 6.6), (-1.6, 3.3), note="rider upper body, seat hump, backrest, gunwales"),
    ],
    "datums": {"beltline": BELT, "sill": SILL, "hoverPlane": HOVER},
    "riderDatums": {
        "note": "Informational. Not read by the validator. See docs/design/vehicle-categories/rider-frame.md.",
        "handDatum": list(HAND), "seatTail": {"z": SEAT_TAIL[0], "topY": SEAT_TAIL[1]},
        "neckFrontZ": NECK_Z[0], "neckTopY": NECK_Y[1], "rearPlateZ": PLATE_Z[1],
        "exhaustHanger": {"x": HANGER[0], "y": HANGER[1], "z": HANGER[2]},
        "screenDeck": {"x": DECK_X, "topY": DECK_Y, "z": DECK_Z},
        "exhaustTunnelY": TUNNEL_Y,
        "tailRail": {"x": RAIL[0], "y": RAIL[1], "z": RAIL[2]},
        "panelStayStationsZ": [STAY_FRONT_Z, STAY_REAR_Z],
    },
    "slots": {
        "Engine1": {
            "label": "Main Turbine",
            "envelope": [env((-0.9, 0.9), (0.3, 1.55), (-2.55, 2.5), note="between the legs, under the spine"),
                         env((-1.5, 1.5), (-1.6, 0.3), (-2.55, 2.5), note="below the feet: may be wide"),
                         env((-1.5, 1.5), (-1.6, -0.55), (2.5, 6.0), note="exhaust tunnel under the swingarm: the rear-facing glow")],
            "anchor": {"to": "cockpit", "face": "+y"}, "explode": [0, -4.5, 0]},
        "Engine2": {
            "label": "Rear Thruster",
            "envelope": env((-1.5, 1.5), (-0.5, 1.8), (3.35, 7.4), note="floor at Y -0.5: the main turbine exhaust shows underneath"),
            "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 1.5, 6.5]},
        "Stabilisers": {
            "label": "Lift Fork",
            "envelope": [env((-2.4, 2.4), (-1.6, 1.0), (-7.7, -2.8), note="lift jets and vanes"),
                         env((-1.6, 1.6), (1.0, 2.0), (-6.6, -3.15), note="fork, under the rake line"),
                         env((-1.6, 1.6), (2.0, 2.9), (-5.0, -3.15), note="yokes")],
            "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, -2.0, -5.0]},
        "Boost": {
            "label": "Afterburner",
            "envelope": [env((1.5, 2.9), (-1.6, 0.3), (0.6, 3.3), mirror=True, note="header run beside the engine"),
                         env((1.5, 2.9), (-1.6, 3.2), (3.3, 7.5), mirror=True, note="pipes beside the rear thruster")],
            "anchor": {"to": "cockpit", "face": "-x"}, "explode": [3.5, -1.0, 4.5]},
        "FrontBumper": {
            "label": "Fairing",
            "envelope": [env((-1.6, 1.6), (2.9, 4.4), (-7.2, -3.3), note="nose, lamp and screen deck, above the fork"),
                         env((-1.6, 1.6), (2.0, 2.9), (-7.3, -5.0), note="chin, ahead of the rake line"),
                         env((-1.6, 1.6), (1.0, 2.0), (-7.3, -6.6), note="beak tip")],
            "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 2.5, -6.5]},
        "RearBumper": {
            "label": "Tail Kit",
            "envelope": env((-1.4, 1.4), (1.85, 5.0), (6.8, 7.7)),
            "anchor": {"to": "RearSpoiler", "face": "-z"}, "explode": [0, 5.5, 9.0]},
        "RearSpoiler": {
            "label": "Seat Unit",
            "envelope": env((-1.4, 1.4), (1.85, 4.6), (3.35, 6.8)),
            "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 4.0, 4.5]},
        "SidePods": {
            "label": "Side Panels",
            "envelope": env((1.7, 2.6), (1.3, 3.4), (-3.2, 3.3), mirror=True),
            "anchor": {"to": "cockpit", "face": "-x"}, "explode": [4.5, 1.0, 0]},
        "Hood": {
            "label": "Tank",
            "envelope": [env((-0.9, 0.9), (2.2, 3.4), (-2.55, 0.1), note="between the knees"),
                         env((0.9, 1.6), (2.2, 3.4), (-2.55, -1.2), mirror=True, note="shoulders, ahead of the knees")],
            "anchor": {"to": "cockpit", "face": "-y"}, "explode": [0, 7.5, -1.0]},
        "Roof": {
            "label": "Screen",
            "envelope": env((-1.4, 1.4), (4.4, 6.0), (-5.0, -3.3)),
            "anchor": {"to": "FrontBumper", "face": "-y"}, "explode": [0, 7.0, -8.0]},
        "Accessory": {
            "label": "Bars",
            "envelope": env((-2.3, 2.3), (3.4, 5.6), (-3.25, -1.65)),
            "anchor": {"to": "cockpit", "face": "-y"}, "explode": [0, 5.5, -3.5]},
    },
}


# ----------------------------------------------------------------------------- cockpits
def chassis(frame="secondary"):
    """The shared chassis. Identical in every cockpit: these parts are the hardpoint pads."""
    return [
        box((-0.6, 0.6), NECK_Y, NECK_Z, "detail", note="neck: fork pad (front), fairing pad (front top), bar pad (top)"),
        box((-0.25, 0.25), SPINE_Y, (-2.6, 3.25), frame, note="spine: engine hangs under it, tank and seat sit on it"),
        box((-0.5, 0.5), (0.35, 1.75), PLATE_Z, frame, note="rear plate: swingarm pad"),
        box(*HANGER, ch="detail", mirror=True, note="exhaust hanger: boost pad"),
        box((0.25, 1.65), (1.95, 2.15), STAY_FRONT_Z, "detail", mirror=True, note="front panel stay"),
        box((0.25, 1.65), (1.95, 2.15), STAY_REAR_Z, "detail", mirror=True, note="rear panel stay"),
        box((-0.75, 0.75), (2.2, SEAT_TAIL[1]), (2.75, SEAT_TAIL[0]), "detail", note="seat tail pad: seat unit datum"),
    ]


def rider(hip, sho, head, knee, ankle, elbow, elbow_x=1.2, peg=True):
    """Rider from pose points given as (y, z). Hands always land on the hand datum."""
    lx = LEG_X
    out = [
        beam([0, hip[0], hip[1]], [0, sho[0], sho[1]], 1.5, 0.8, "driver", note="rider torso"),
        ball(1.2, [0, head[0], head[1]], "driver", note="helmet"),
        P("block", [0.9, 0.36, 0.3], [0, head[0] + 0.05, head[1] - 0.5], "glass", [-12, 0, 0], note="visor"),
        beam([lx, hip[0] - 0.1, hip[1]], [lx, knee[0], knee[1]], 0.6, 0.62, "driver", mirror=True, note="thigh"),
        beam([lx, knee[0], knee[1]], [lx, ankle[0], ankle[1]], 0.56, 0.56, "driver", mirror=True, note="shin"),
        box((1.08, 1.68), (ankle[0] - 0.4, ankle[0] - 0.05), (ankle[1] - 0.65, ankle[1] + 0.35), "driver", mirror=True, note="boot"),
        beam([1.12, sho[0] - 0.15, sho[1]], [elbow_x, elbow[0], elbow[1]], 0.48, 0.48, "driver", mirror=True, note="upper arm"),
        beam([elbow_x, elbow[0], elbow[1]], list(HAND), 0.44, 0.44, "driver", mirror=True, note="forearm"),
        box((HAND[0] - 0.25, HAND[0] + 0.25), (HAND[1] - 0.25, HAND[1] + 0.25), (HAND[2] - 0.25, HAND[2] + 0.25),
            "driver", mirror=True, note="hand on the hand datum"),
    ]
    if peg:
        out.append(box((0.9, 1.68), (ankle[0] - 0.55, ankle[0] - 0.4), (ankle[1] - 0.35, ankle[1] + 0.1), "detail", mirror=True, note="foot peg"))
    return out


def cockpits():
    """Each cockpit owns two or three bold shapes of its own, so it can be named under any kit."""
    c = {}
    c["supersport"] = {
        "name": "Supersport", "culture": "Supersport", "kit": "paddock",
        "parts": chassis("secondary") + [
            beam([1.2, 1.8, -2.0], [1.2, 0.95, 2.9], 0.6, 0.62, "primary", mirror=True, note="twin-spar frame: 0.6 thick, in body colour"),
            box((-0.7, 0.7), (2.2, 2.7), (0.2, 2.1), "detail", note="race seat pad"),
            wedge((-0.8, 0.8), (2.7, 4.3), (2.05, 2.6), "nose", "primary", note="race hump: bum stop face"),
            box((-0.8, 0.8), (2.7, 3.4), (2.6, 3.3), "primary", note="race hump base"),
            wedge((-0.8, 0.8), (3.4, 4.3), (2.6, 3.3), "tail", "primary", note="race hump: falls to the seat tail datum"),
        ] + rider(hip=(3.1, 1.75), sho=(4.15, -0.3), head=(4.65, -0.88), knee=(2.9, 0.4), ankle=(1.95, 1.8), elbow=(3.7, -0.6), elbow_x=1.14),
    }
    c["cafe"] = {
        "name": "Cafe", "culture": "Cafe Racer", "kit": "tonup",
        "parts": chassis("secondary") + [
            box((-0.7, 0.7), (2.2, 2.7), (0.2, 1.5), "detail", note="solo seat pad"),
            cz(0, 3.2, 1.45, 2.3, 1.7, "primary", note="long round cafe hump: bum stop"),
            ball(2.0, [0, 3.3, 2.3], "primary", note="round cafe hump: a dome that rolls down to the seat tail datum"),
            box((-0.85, 0.85), (2.2, 2.45), (0.2, 1.5), "primary", note="painted seat pan: slim, nothing outside the spine line"),
        ] + rider(hip=(3.1, 0.95), sho=(4.65, -0.1), head=(5.25, -0.55), knee=(2.8, -0.35), ankle=(1.6, 1.25), elbow=(4.0, -0.6), elbow_x=1.3),
    }
    c["chopper"] = {
        "name": "Chopper", "culture": "Chopper", "kit": "longhaul",
        "parts": chassis("secondary") + [
            box((-1.3, 1.3), (2.2, 2.55), (0.2, 1.85), "detail", note="wide tractor saddle"),
            box((-0.8, 0.8), (2.2, 2.55), (1.85, 2.75), "detail", note="saddle tail"),
            box((0.9, 2.35), (0.74, 0.94), (-2.15, 0.4), "secondary", mirror=True, note="wide full-length running board"),
            box((2.2, 2.35), (0.94, 1.25), (-2.15, 0.4), "detail", mirror=True, note="running-board rail"),
            box((-1.1, 1.1), (2.55, 4.6), (2.1, 2.5), "detail", note="tall king backrest"),
            box((-1.7, 1.7), (4.6, 5.3), (2.05, 2.55), "secondary", note="wide backrest top roll"),
            box((-0.75, 0.75), (2.55, 3.4), (2.5, 2.75), "detail", note="pillion step"),
        ] + rider(hip=(2.9, 0.75), sho=(4.9, 1.5), head=(5.55, 1.6), knee=(2.45, -0.45), ankle=(1.35, -1.4), elbow=(4.3, 0.2)),
    }
    c["scrambler"] = {
        "name": "Scrambler", "culture": "Motocross", "kit": "holeshot",
        "parts": chassis("secondary") + [
            box((-0.6, 0.6), (2.2, 3.4), (0.2, 2.75), "detail", note="tall flat bench: level with the seat tail datum"),
            box((-0.68, 0.68), (2.2, 2.8), (0.2, 3.25), "primary", note="bench side cover"),
            wedge((1.45, 1.7), (1.4, 3.4), (1.4, 2.0), "nose", "primary", mirror=True, note="side number board: swept leading edge"),
            box((1.45, 1.7), (1.4, 3.4), (2.0, 3.28), "primary", mirror=True, note="side number board: 2 studs high"),
            box((0.75, 1.45), (3.0, 3.2), (2.4, 3.2), "detail", mirror=True, note="board bridge to the bench"),
        ] + rider(hip=(4.0, 1.5), sho=(5.3, 0.1), head=(5.8, -0.45), knee=(2.95, 0.7), ankle=(1.45, 1.0), elbow=(4.95, -0.8), elbow_x=1.95),
    }
    c["streetfighter"] = {
        "name": "Streetfighter", "culture": "Streetfighter", "kit": "bareknuckle",
        "parts": chassis("secondary") + [
            box((-0.75, 0.75), (2.2, 2.7), (0.2, 2.0), "detail", note="rider pad"),
            wedge((-0.85, 0.85), (2.7, 3.4), (1.9, 2.75), "nose", "primary", note="short kicked tail pad"),
            wedge((0.9, 1.5), (0.6, 2.15), (-2.1, -0.5), "chin", "primary", mirror=True, note="frame panel: solid front triangle"),
            wedge((0.9, 1.08), (0.6, 2.15), (-0.5, 2.6), "kick", "primary", mirror=True, note="frame panel: rear triangle, inside the leg"),
            cx(0.9, -1.2, 1.5, 2.25, 0.45, "detail", mirror=True, note="frame slider"),
        ] + rider(hip=(3.05, 1.3), sho=(5.0, 0.65), head=(5.65, 0.4), knee=(2.7, 0.0), ankle=(1.45, 0.9), elbow=(4.45, -0.3), elbow_x=1.95),
    }
    c["speeder"] = {
        "name": "Speeder", "culture": "Speeder", "kit": "outrider",
        "parts": chassis("secondary") + [
            box((-0.8, 0.8), (2.2, 2.7), (0.2, 2.75), "detail", note="prone pad"),
            box((0.9, 1.7), (1.5, 3.2), (-0.2, 2.2), "primary", mirror=True, note="sled tub wall: the legs ride inside"),
            wedge((0.9, 1.7), (1.5, 3.2), (2.2, 3.28), "tail", "primary", mirror=True, note="tub wall tail: tapers to the seat unit"),
            wedge((0.9, 1.7), (1.5, 3.2), (-1.2, -0.2), "nose", "primary", mirror=True, note="tub wall nose"),
            wedge((0.9, 1.7), (1.5, 2.15), (-2.2, -1.2), "nose", "secondary", mirror=True, note="tub prow blade"),
            box((1.5, 2.15), (3.4, 3.72), (0.4, 2.6), "secondary", mirror=True, note="flared gunwale: the sled rim"),
            wedge((1.5, 2.15), (3.4, 3.72), (-1.2, 0.4), "nose", "secondary", mirror=True, note="gunwale nose"),
            wedge((1.5, 2.15), (3.4, 3.72), (2.6, 3.28), "tail", "secondary", mirror=True, note="gunwale tail: runs out at the seat tail datum"),
            box((1.5, 1.7), (3.2, 3.4), (-0.2, 3.25), "primary", mirror=True, note="tub wall cap: carries the gunwale"),
            wedge((1.5, 2.15), (3.72, 4.4), (0.6, 1.5), "nose", "primary", mirror=True, note="haunch: rises beside the hips, peaks at Z 1.5"),
            wedge((1.5, 2.15), (3.72, 4.4), (1.5, 2.6), "tail", "primary", mirror=True, note="haunch: falls back to the gunwale"),
        ] + rider(hip=(3.1, 2.55), sho=(3.85, 0.55), head=(4.35, -0.2), knee=(2.75, 1.5), ankle=(2.75, 2.9), elbow=(3.68, -0.45), peg=False),
    }
    return c


# ----------------------------------------------------------------------------- Engine1: main turbine
def tailpipe(x, z0, z1, dia, glow, ch="secondary", mirror=False, name="tailpipe"):
    """Main Turbine exhaust in the tunnel under the swingarm: pipe, dark flared nozzle, rear-facing glow."""
    zn = z1 - 0.6
    return [cz(x, TUNNEL_Y, z0, zn, dia, ch, mirror, name),
            cz(x, TUNNEL_Y, zn, z1, min(1.0, glow + 0.22), "detail", mirror, name + " nozzle"),
            cz(x, TUNNEL_Y, z1, z1 + 0.18, glow, "thrust", mirror, name + " thrust")]


def engine1():
    m = {}
    m["inline"] = {"name": "Inline Turbine", "culture": "Supersport", "parts": [
            cz(0, -0.3, -2.45, -1.6, 1.5, "detail", note="main turbine intake cowl"),
            ball(0.7, [0, -0.3, -2.15], "secondary", note="intake spinner"),
            cz(0, -0.3, -1.6, 0.9, 1.36, "secondary", note="main turbine body"),
            tube([0, -0.3, 0.8], [0, TUNNEL_Y, 2.1], 1.0, "detail", note="jet pipe: drops into the exhaust tunnel"),
            box((-0.3, 0.3), (0.3, 1.55), (-0.6, 0.0), "detail", note="top mount"),
        ] + tailpipe(0, 2.0, 5.75, 0.9, 0.78, name="long centre tailpipe")}
    m["flattwin"] = {"name": "Flat Twin", "culture": "Cafe Racer", "parts": [
            box((-0.6, 0.6), (-1.2, 0.3), (-1.1, 0.7), "detail", note="crankcase"),
            box((-0.3, 0.3), (0.3, 1.55), (-0.6, 0.0), "detail", note="top mount"),
            cx(-0.6, -0.2, 0.6, 1.3, 0.95, "secondary", mirror=True, note="flat-twin can: sticks out below the foot"),
            box((1.3, 1.5), (-1.15, -0.05), (-0.75, 0.35), "detail", mirror=True, note="finned can head"),
            cz(1.02, -0.6, -1.5, -0.6, 0.55, "detail", mirror=True, note="intake trumpet"),
            cz(1.02, -0.6, -2.0, -1.5, 0.82, "secondary", mirror=True, note="intake bellmouth"),
            cz(1.02, TUNNEL_Y, 0.2, 1.5, 0.55, "secondary", mirror=True, note="megaphone stage 1"),
            cz(1.02, TUNNEL_Y, 1.5, 2.4, 0.76, "secondary", mirror=True, note="megaphone stage 2"),
            cz(1.02, TUNNEL_Y, 2.4, 3.2, 0.95, "detail", mirror=True, note="megaphone mouth"),
            cz(1.02, TUNNEL_Y, 3.2, 3.38, 0.76, "thrust", mirror=True, note="megaphone thrust"),
        ]}
    m["vtwin"] = {"name": "V-Twin Jets", "culture": "Chopper", "parts": [
            box((-0.75, 0.75), (-1.25, -0.25), (-0.8, 0.8), "detail", note="small crankcase"),
            box((0.75, 0.87), (-1.05, -0.45), (-0.5, 0.5), "secondary", mirror=True, note="chrome case cover"),
            tube([0, -0.3, -0.3], [0, 0.8, -1.22], 0.8, "secondary", note="front can: slim, leans forward"),
            tube([0, 0.8, -1.22], [0, 1.2, -1.56], 0.92, "detail", note="front can intake"),
            tube([0, -0.3, 0.3], [0, 0.8, 1.22], 0.8, "secondary", note="rear can: slim, leans back"),
            tube([0, 0.8, 1.22], [0, 1.2, 1.56], 0.92, "detail", note="rear can intake"),
            box((-0.3, 0.3), (-0.25, 1.5), (-0.25, 0.25), "detail", note="top mount: stands in the V"),
            tube([0.55, -0.85, 0.6], [0.9, TUNNEL_Y, 2.0], 0.7, "secondary", mirror=True, note="header"),
        ] + tailpipe(0.9, 1.9, 4.9, 0.75, 0.76, mirror=True, name="twin tailpipe")}
    m["thumper"] = {"name": "Big Single", "culture": "Motocross", "parts": [
            box((-0.7, 0.7), (-1.25, -0.45), (-1.0, 0.9), "detail", note="crankcase"),
            tube([0, -0.6, -0.3], [0, 0.75, -1.05], 1.2, "secondary", note="single tall can: canted forward, ahead of the legs"),
            tube([0, 0.75, -1.05], [0, 1.05, -1.22], 0.95, "detail", note="intake cone stage 1"),
            tube([0, 1.05, -1.22], [0, 1.3, -1.36], 0.6, "detail", note="intake cone stage 2"),
            box((-0.3, 0.3), (0.3, 1.55), (-0.4, 0.2), "detail", note="top mount"),
            box((-1.2, 1.2), (-1.45, -1.25), (-2.2, 1.0), "primary", note="wide bash plate"),
            box((1.05, 1.2), (-1.25, -0.7), (-2.2, 0.2), "primary", mirror=True, note="bash plate side wing"),
            tube([0.5, -0.85, 0.6], [0.95, TUNNEL_Y, 2.2], 0.8, "detail", note="header: right side only, under the megaphone"),
        ] + tailpipe(0.95, 2.1, 3.9, 0.9, 0.78, name="single stinger")}
    m["fourposter"] = {"name": "Four-Poster", "culture": "Streetfighter", "parts": [
            box((-0.6, 0.6), (-0.3, 1.1), (-1.9, 1.5), "detail", note="long plenum"),
            box((-0.3, 0.3), (1.1, 1.5), (-0.6, 0.0), "detail", note="top mount"),
            box((-1.05, 1.05), (-0.1, 0.2), (-2.0, -1.4), "detail", note="front post yoke"),
            box((-1.05, 1.05), (-0.1, 0.2), (1.2, 1.8), "detail", note="rear post yoke"),
            box((-0.5, 0.5), (-1.2, -0.3), (0.9, 2.4), "detail", note="collector duct"),
            box((-0.8, 0.8), (-1.55, -0.6), (2.3, 3.7), "secondary", note="rear collector nozzle: between the back posts"),
            box((-0.9, 0.9), (-1.6, -0.55), (3.7, 4.0), "detail", note="collector lip"),
            box((-0.7, 0.7), (-1.47, -0.68), (4.0, 4.16), "thrust", note="collector thrust: rear-facing"),
        ] + lift_jet(1.05, -1.7, 0.28, -1.3, 0.85, "secondary", True, "front lift post")
          + lift_jet(1.05, 1.5, 0.28, -1.3, 0.85, "secondary", True, "rear lift post")}
    m["slotburner"] = {"name": "Slot Burner", "culture": "Speeder", "parts": [
            box((-0.85, 0.85), (-0.6, 1.45), (-2.0, 1.6), "detail", note="plenum: hugs the spine"),
            wedge((-0.85, 0.85), (-0.6, 1.45), (-2.5, -2.0), "nose", "detail", note="plenum intake ramp"),
            box((-1.45, 1.45), (-1.25, -0.6), (-2.3, 4.4), "secondary", note="burner slab: runs out under the swingarm"),
            box((-1.2, 1.2), (-1.13, -0.72), (-2.5, -2.3), "detail", note="intake mouth"),
            box((-1.45, 1.45), (-1.25, -0.6), (4.4, 4.7), "detail", note="slot nozzle"),
            box((-1.25, 1.25), (-1.15, -0.7), (4.7, 4.88), "thrust", note="slot thrust: rear-facing"),
            box((1.45, 1.5), (-1.05, -0.8), (-1.6, 1.6), "thrust", mirror=True, note="side slot thrust"),
        ]}
    return m


# ----------------------------------------------------------------------------- Engine2: rear thruster on its swingarm
def engine2():
    m = {}
    m["mono"] = {"name": "Mono Thruster", "culture": "Supersport", "parts": [
            box((-0.7, 0.7), (0.6, 1.4), (3.4, 3.9), "detail", note="pivot"),
            beam([1.0, 1.0, 3.6], [1.0, 0.55, 5.4], 0.3, 0.6, "secondary", note="single-sided swingarm"),
            box((0.0, 1.15), (0.25, 0.65), (5.1, 5.6), "detail", note="thruster carrier"),
        ] + jet_z(0, 0.38, 4.0, 7.0, 1.6, "primary", spinner=False, name="mono thruster")}
    m["trident"] = {"name": "Trident", "culture": "Cafe Racer", "parts": [
            box((-0.6, 0.6), (0.5, 1.4), (3.4, 3.9), "detail", note="pivot"),
            box((-1.3, 1.3), (0.35, 0.75), (3.9, 4.4), "secondary", note="swingarm yoke: carries three barrels"),
            tube([1.2, 0.6, 5.2], [1.05, 1.6, 3.7], 0.22, "secondary", mirror=True, note="twin shock"),
        ] + jet_z(0, 0.55, 3.9, 7.0, 1.0, "primary", spinner=False, name="centre barrel")
          + jet_z(0.95, 0.55, 4.2, 5.9, 0.72, "primary", True, spinner=False, name="side barrel")}
    m["fatbob"] = {"name": "Fat Block", "culture": "Chopper", "parts": [
            box((-0.6, 0.6), (0.4, 1.3), (3.4, 3.8), "detail", note="hardtail pivot"),
            wedge((-1.0, 1.0), (0.65, 1.72), (3.75, 4.6), "nose", "secondary", note="block shoulder"),
            wedge((-1.0, 1.0), (-0.45, 0.65), (3.75, 4.6), "chin", "secondary", note="block keel"),
            box((-1.0, 1.0), (-0.45, 1.72), (4.6, 6.1), "secondary", note="block body: 2.0 wide, 2.2 high"),
            box((1.0, 1.42), (0.1, 1.3), (4.45, 5.7), "primary", mirror=True, note="side scoop intake"),
            box((1.06, 1.36), (0.2, 1.2), (4.3, 4.45), "detail", mirror=True, note="scoop mouth"),
            box((1.0, 1.22), (0.3, 1.1), (5.7, 6.1), "detail", mirror=True, note="scoop fade"),
            box((-0.9, 0.9), (-0.3, 1.57), (6.1, 6.55), "detail", note="nozzle step 1"),
            box((-0.75, 0.75), (1.2, 1.4), (6.55, 7.05), "detail", note="nozzle step 2: top wall"),
            box((-0.75, 0.75), (-0.12, 0.08), (6.55, 7.05), "detail", note="nozzle step 2: bottom wall"),
            box((0.6, 0.75), (0.08, 1.2), (6.55, 7.05), "detail", mirror=True, note="nozzle step 2: side wall"),
            box((-0.6, 0.6), (0.08, 1.2), (6.55, 6.85), "detail", note="nozzle core"),
            box((-0.6, 0.6), (0.08, 1.2), (6.85, 6.93), "thrust", note="recessed block thrust"),
            tube([0.5, 1.5, 3.45], [0.9, 1.6, 4.7], 0.24, "secondary", mirror=True, note="hardtail upper stay"),
        ]}
    m["overunder"] = {"name": "Over-Under", "culture": "Motocross", "parts": [
            beam([0.65, 1.2, 3.5], [0.65, 0.6, 5.2], 0.2, 0.5, "secondary", mirror=True, note="long-travel swingarm"),
            box((-0.55, 0.55), (0.6, 1.4), (3.4, 3.8), "detail", note="pivot"),
            box((-0.75, 0.75), (0.45, 0.85), (4.9, 5.4), "detail", note="thruster carrier"),
        ] + jet_z(0, 1.25, 4.0, 7.0, 0.95, "primary", spinner=False, name="upper thruster")
          + jet_z(0, 0.05, 4.2, 5.9, 0.95, "primary", spinner=False, name="lower thruster")}
    m["twin"] = {"name": "Twin Barrels", "culture": "Streetfighter", "parts": [
            box((-0.3, 0.3), (0.2, 1.3), (3.4, 4.5), "detail", note="centre arm"),
            box((-0.9, 0.9), (0.72, 0.98), (3.9, 4.5), "secondary", note="cross brace"),
        ] + jet_z(0.82, 0.3, 3.9, 6.2, 1.25, "primary", True, spinner=False, name="barrel")}
    m["fantail"] = {"name": "Fan Tail", "culture": "Speeder", "parts": [
            box((-0.6, 0.6), (0.5, 1.5), (3.4, 3.9), "detail", note="pivot"),
            box((-1.2, 1.2), (0.85, 1.3), (3.7, 3.95), "detail", note="intake lip"),
            box((-1.4, 1.4), (0.7, 1.45), (3.95, 6.4), "primary", note="fan tail body"),
            box((-1.4, 1.4), (0.75, 1.4), (6.4, 6.8), "detail", note="slot nozzle"),
            box((-1.2, 1.2), (0.9, 1.25), (6.8, 7.0), "thrust", note="slot thrust"),
            wedge((-0.12, 0.12), (-0.45, 0.7), (4.1, 6.4), "kick", "secondary", note="keel fin"),
        ]}
    return m


# ----------------------------------------------------------------------------- Boost: afterburner pipes on the flanks
def boost_bracket(mirror=True, top=0.9):
    return box((1.52, 1.8), (0.4, top), (3.35, 3.85), "detail", mirror=mirror, note="bracket: lands on the exhaust hanger")


def boost():
    m = {}
    m["twincans"] = {"name": "Twin Cans", "culture": "Supersport", "parts": [
            boost_bracket(),
            tube([1.7, 0.7, 3.7], [2.1, 1.0, 4.1], 0.3, "detail", mirror=True, note="link pipe"),
        ] + jet([2.1, 1.0, 3.95], [2.2, 1.95, 6.5], 0.95, "secondary", True, cowl=0.16, noz=0.2, spinner=False, name="afterburner can")}
    m["reversecones"] = {"name": "Reverse Cones", "culture": "Cafe Racer", "parts": [
            boost_bracket(),
            tube([1.7, 0.6, 3.6], [2.1, -0.25, 3.7], 0.3, "detail", mirror=True, note="hanger strap"),
            tube([1.82, -0.95, 0.9], [2.1, -0.45, 3.3], 0.42, "secondary", mirror=True, note="swept header"),
            tube([2.1, -0.45, 3.3], [2.2, 0.15, 4.9], 0.66, "secondary", mirror=True, note="megaphone stage 1"),
            tube([2.2, 0.15, 4.9], [2.26, 0.55, 5.95], 1.0, "secondary", mirror=True, note="megaphone stage 2"),
            tube([2.26, 0.55, 5.95], [2.3, 0.75, 6.5], 0.78, "detail", mirror=True, note="reverse cone"),
            tube([2.3, 0.75, 6.5], [2.31, 0.82, 6.7], 0.56, "thrust", mirror=True, note="reverse cone thrust"),
        ]}
    m["shotgun"] = {"name": "Shotgun Pipes", "culture": "Chopper", "parts": [
            boost_bracket(),
            box((1.6, 1.85), (-0.7, 0.4), (3.4, 3.75), "detail", mirror=True, note="pipe strap"),
            cz(2.05, -0.95, 0.8, 6.5, 0.55, "secondary", True, "lower pipe"),
            cz(2.05, -0.95, 6.5, 7.1, 0.72, "detail", True, "lower fishtail"),
            cz(2.05, -0.95, 7.1, 7.32, 0.5, "thrust", True, "lower pipe thrust"),
            cz(2.05, -0.25, 0.8, 5.7, 0.55, "secondary", True, "upper pipe"),
            cz(2.05, -0.25, 5.7, 6.3, 0.72, "detail", True, "upper fishtail"),
            cz(2.05, -0.25, 6.3, 6.52, 0.5, "thrust", True, "upper pipe thrust"),
        ]}
    m["megaphone"] = {"name": "High Megaphone", "culture": "Motocross", "parts": [
            boost_bracket(mirror=False),
            tube([1.75, 0.6, 3.6], [2.1, 1.3, 4.2], 0.42, "detail", note="header"),
            tube([2.1, 1.3, 4.2], [2.17, 1.75, 5.2], 0.62, "secondary", note="megaphone stage 1"),
            tube([2.17, 1.75, 5.2], [2.24, 2.2, 6.2], 0.9, "secondary", note="megaphone stage 2"),
            tube([2.24, 2.2, 6.2], [2.3, 2.55, 7.0], 1.15, "detail", note="megaphone mouth"),
            tube([2.3, 2.55, 7.0], [2.31, 2.63, 7.2], 0.85, "thrust", note="megaphone thrust"),
        ]}
    m["quadstubs"] = {"name": "Quad Stubs", "culture": "Streetfighter", "parts": [
            boost_bracket(),
            box((1.6, 1.9), (0.2, 1.6), (3.9, 4.3), "detail", mirror=True, note="stub stack plate"),
        ] + jet_z(2.2, 1.4, 3.5, 5.3, 0.82, "secondary", True, cowl=0.2, noz=0.25, spinner=False, name="upper stub")
          + jet_z(2.2, 0.4, 3.5, 5.3, 0.82, "secondary", True, cowl=0.2, noz=0.25, spinner=False, name="lower stub")}
    m["slotblades"] = {"name": "Slot Blades", "culture": "Speeder", "parts": [
            boost_bracket(top=1.5),
            box((1.6, 2.85), (1.42, 1.8), (3.9, 6.6), "primary", mirror=True, note="burner blade"),
            box((1.7, 2.75), (1.47, 1.75), (3.6, 3.9), "detail", mirror=True, note="blade intake"),
            box((1.6, 2.85), (1.42, 1.8), (6.6, 6.9), "detail", mirror=True, note="blade nozzle"),
            box((1.75, 2.7), (1.5, 1.72), (6.9, 7.1), "thrust", mirror=True, note="blade thrust"),
        ]}
    return m


# ----------------------------------------------------------------------------- Stabilisers: the front end (fork + lift jets)
def yokes(w):
    return [box((-w, w), (1.72, 1.97), (-3.7, -3.2), "detail", note="lower yoke: lands on the fork pad"),
            box((-w, w), (2.6, 2.85), (-3.7, -3.2), "detail", note="upper yoke")]


def stabilisers():
    m = {}
    m["sportfork"] = {"name": "Sport Fork", "culture": "Supersport", "parts": yokes(1.2) + [
            tube([0.98, 2.7, -3.5], [0.98, 1.0, -4.55], 0.5, "secondary", mirror=True, note="fork stanchion"),
            tube([0.98, 1.0, -4.55], [0.98, -0.35, -5.4], 0.36, "detail", mirror=True, note="fork slider"),
        ] + nacelle((-0.8, 0.8), (-1.2, 0.0), (-6.7, -3.8), "primary", name="lift pod")
          + stub([0.9, -0.4, -5.3], [1.55, -0.95, -5.2], 0.68, name="fork-leg side jet")}
    m["torpedo"] = {"name": "Torpedo Fork", "culture": "Cafe Racer", "parts": yokes(1.1) + [
            tube([0.9, 2.7, -3.5], [0.9, 0.2, -5.0], 0.42, "secondary", mirror=True, note="classic fork leg"),
            tube([0.9, 2.4, -3.68], [0.9, 1.5, -4.22], 0.58, "detail", mirror=True, note="fork gaiter"),
            box((-2.0, 2.0), (0.02, 0.3), (-5.15, -4.85), "detail", note="straight axle bar: carries three torpedoes"),
        ] + pod(0, -0.45, -6.9, -3.9, 0.95, "primary", name="centre torpedo", nose_ch="secondary")
          + pod(1.75, -0.28, -6.1, -4.1, 0.6, "secondary", True, name="outboard torpedo")}
    m["longrake"] = {"name": "Long Rake", "culture": "Chopper", "parts": yokes(0.95) + [
            tube([0.75, 2.72, -3.5], [0.75, -0.3, -6.5], 0.36, "secondary", mirror=True, note="raked fork leg"),
            box((-1.15, 1.15), (-0.45, -0.15), (-6.65, -6.35), "detail", note="axle"),
            box((-0.8, 0.8), (-1.05, -0.05), (-7.1, -5.5), "primary", note="lift pod body: 1.6 wide, out at the end of the rake"),
            box((-0.8, 0.8), (-1.05, -0.05), (-7.4, -7.1), "secondary", note="intake lip"),
            box((-0.62, 0.62), (-0.9, -0.2), (-7.52, -7.4), "detail", note="intake mouth: open on the nose"),
            box((-0.65, 0.65), (-0.9, -0.2), (-5.5, -5.1), "detail", note="slot nozzle"),
            box((-0.5, 0.5), (-0.78, -0.32), (-5.1, -4.94), "thrust", note="tail thrust"),
            box((-0.3, 0.3), (-0.05, 0.1), (-6.2, -5.7), "detail", note="top intake scoop"),
            box((-1.0, 1.0), (-1.25, -1.03), (-6.9, -5.6), "thrust", note="lift thrust plate: its rim glows past the pod sides"),
            tube([1.15, -0.3, -6.5], [1.85, -0.72, -6.5], 0.7, "detail", mirror=True, note="axle side jet: canted out and down"),
            tube([1.85, -0.72, -6.5], [2.04, -0.83, -6.5], 0.55, "thrust", mirror=True, note="axle side jet thrust"),
        ]}
    m["liftcans"] = {"name": "Lift Cans", "culture": "Motocross", "parts": yokes(1.2) + [
            tube([0.95, 2.7, -3.5], [0.95, 0.4, -4.75], 0.5, "secondary", mirror=True, note="long-travel fork leg"),
            box((-0.45, 0.45), (-0.2, 0.1), (-5.2, -4.8), "detail", note="can brace"),
        ] + lift_jet(0.95, -5.0, 0.7, -1.3, 1.05, "primary", True, "lift can")}
    m["girder"] = {"name": "Girder Twin", "culture": "Streetfighter", "parts": yokes(1.35) + [
            beam([1.2, 2.62, -3.6], [1.2, 0.0, -5.3], 0.22, 0.55, "secondary", mirror=True, note="girder blade"),
            box((-1.2, 1.2), (1.2, 1.45), (-4.55, -4.25), "detail", note="girder link"),
            box((-2.3, 2.3), (0.05, 0.19), (-6.0, -5.0), "primary", note="canard vane"),
            box((2.3, 2.4), (-0.05, 0.29), (-6.0, -5.0), "thrust", mirror=True, note="vane tip jet"),
        ] + nacelle((0.7, 1.7), (-1.2, -0.25), (-6.9, -4.1), "primary", True, name="twin pod")}
    m["twinboom"] = {"name": "Twin Boom", "culture": "Speeder", "parts": yokes(1.3) + [
            beam([1.1, 2.6, -3.55], [1.15, 0.6, -4.3], 0.3, 0.5, "detail", mirror=True, note="boom strut"),
            cz(1.15, 0.3, -6.9, -3.7, 0.6, "primary", True, "boom"),
            ball(0.6, [1.15, 0.3, -6.9], "secondary", True, "boom tip"),
            wedge((1.08, 1.22), (-1.45, 0.0), (-6.8, -5.4), "chin", "secondary", mirror=True, note="steering vane"),
            box((-0.85, 0.85), (0.2, 0.4), (-4.3, -3.9), "detail", note="boom brace"),
        ] + lift_jet(1.15, -4.7, 0.0, -1.15, 0.7, "secondary", True, "boom lift jet")}
    return m


# ----------------------------------------------------------------------------- body: fairing, screen, bars, tank, panels, seat unit, tail kit
def fairing_bracket():
    return [box((-0.3, 0.3), FAIRING_PAD_Y, (-4.1, -3.35), "detail", note="bracket: lands on the fairing pad")]


def deck(y0, ch="primary", z0=DECK_Z[0]):
    """The screen deck every fairing carries: flat top at DECK_Y, as wide as the widest screen base."""
    return box(DECK_X, (y0, DECK_Y), (z0, DECK_Z[1]), ch, note="screen deck: flat top, screens sit flush on it")


def fairings():
    m = {}
    m["racenose"] = {"name": "Race Nose", "culture": "Supersport", "parts": fairing_bracket() + [
            wedge((-1.4, 1.4), (2.95, 3.9), (-6.9, -4.8), "nose", "primary", note="nose"),
            box((-1.4, 1.4), (2.95, 3.9), (-4.8, -3.4), "primary", note="nose shoulders"),
            wedge(DECK_X, (3.9, DECK_Y), (-5.6, -4.8), "nose", "primary", note="cowl ramp"),
            deck(3.9),
            wedge((-1.4, 1.4), (2.05, 2.95), (-6.9, -5.05), "chin", "primary", note="chin"),
            P("block", [0.8, 0.1, 0.7], [0.65, 3.4, -6.0], "neon", [-24.3, 0, 0], mirror=True, note="slit lamp"),
        ]}
    m["dolphin"] = {"name": "Dolphin Nose", "culture": "Cafe Racer", "parts": fairing_bracket() + [
            ball(2.0, [0, 3.3, -6.1], "primary", note="round dolphin nose"),
            cz(0, 3.3, -6.1, -5.0, 2.0, "primary", note="dolphin barrel"),
            box((-1.0, 1.0), (2.95, 4.0), (-5.0, -3.5), "primary", note="dolphin back"),
            deck(4.0),
            box((-0.45, 0.45), (3.15, 3.45), (-7.15, -6.9), "neon", note="slit lamp"),
        ]}
    m["roundlamp"] = {"name": "Round Lamp", "culture": "Chopper", "parts": fairing_bracket() + [
            cz(0, 3.65, -5.6, -4.4, 1.15, "secondary", note="bullet lamp shell"),
            ball(1.15, [0, 3.65, -4.4], "secondary", note="bullet lamp tail"),
            box((-0.4, 0.4), (3.3, 4.0), (-5.72, -5.6), "neon", note="lamp lens"),
            deck(4.12, "secondary", z0=-5.6),
            box((-0.25, 0.25), (3.27, 4.12), (-4.0, -3.6), "detail", note="deck post"),
        ]}
    m["mxplate"] = {"name": "Number Plate", "culture": "Motocross", "parts": fairing_bracket() + [
            P("block", [1.7, 1.4, 0.3], [0, 3.62, -5.0], "primary", [12, 0, 0], note="number plate"),
            box((-0.5, 0.5), (2.95, 3.3), (-5.0, -4.0), "detail", note="plate mount and lamp"),
            deck(4.0, "detail"),
            box((-0.3, 0.3), (3.27, 4.0), (-4.3, -3.7), "detail", note="deck post"),
            beam([0, 2.72, -5.05], [0, 2.3, -7.1], 1.4, 0.3, "primary", note="high beak fender"),
        ]}
    m["mask"] = {"name": "Fighter Mask", "culture": "Streetfighter", "parts": fairing_bracket() + [
            wedge((-1.2, 1.2), (3.3, 4.0), (-5.5, -4.8), "nose", "primary", note="mask brow"),
            box((-1.2, 1.2), (3.3, 4.0), (-4.8, -3.6), "primary", note="mask block"),
            wedge(DECK_X, (4.0, DECK_Y), (-5.15, -4.8), "nose", "primary", note="cowl ramp"),
            deck(4.0),
            wedge((-1.2, 1.2), (2.95, 3.3), (-5.5, -4.2), "chin", "detail", note="mask jaw"),
            P("block", [0.7, 0.08, 0.5], [0.55, 3.68, -5.17], "neon", [-45, 0, 0], mirror=True, note="eye"),
        ]}
    m["prow"] = {"name": "Spear Prow", "culture": "Speeder", "parts": fairing_bracket() + [
            wedge(DECK_X, (2.95, DECK_Y), (-7.1, -4.8), "nose", "primary", note="spear top: rises to the screen deck"),
            deck(2.95),
            wedge(DECK_X, (2.3, 2.95), (-7.1, -5.05), "chin", "secondary", note="spear keel"),
            box((0.7, 0.82), (2.95, 3.25), (-5.6, -3.6), "neon", mirror=True, note="light strip"),
        ]}
    return m


def screen_base(x, z):
    return box((-x, x), (4.4, 4.5), z, "detail", note="screen base: flush on the screen deck")


def screens():
    """Every screen stands on the deck footprint. No glass overhangs the nose, so none can hover."""
    m = {}
    m["bubble"] = {"name": "Bubble", "culture": "Supersport", "parts": [
            screen_base(0.7, (-4.8, -3.6)),
            wedge((-0.65, 0.65), (4.5, 5.4), (-4.8, -3.7), "nose", "glass", note="bubble screen"),
        ]}
    m["aero"] = {"name": "Aero Screen", "culture": "Cafe Racer", "parts": [
            screen_base(0.65, (-4.3, -3.8)),
            P("block", [1.3, 0.9, 0.12], [0, 4.94, -4.0], "glass", [8, 0, 0], note="upright aero screen"),
            cx(5.42, -3.93, -0.7, 0.7, 0.16, "detail", note="top rim"),
        ]}
    m["tourer"] = {"name": "Tourer", "culture": "Chopper", "parts": [
            screen_base(0.7, (-4.4, -3.6)),
            P("block", [1.36, 0.6, 0.12], [0, 4.78, -4.05], "glass", [12, 0, 0], note="windshield lower pane: as wide as the deck"),
            P("block", [2.0, 0.9, 0.12], [0, 5.5, -3.9], "glass", [12, 0, 0], note="windshield upper pane"),
            tube([0.62, 4.5, -4.0], [0.92, 5.2, -3.86], 0.14, "detail", mirror=True, note="side stay"),
        ]}
    m["rally"] = {"name": "Rally Tower", "culture": "Motocross", "parts": [
            screen_base(0.45, (-4.7, -3.7)),
            wedge((-0.45, 0.45), (4.5, 5.8), (-4.6, -3.8), "nose", "glass", note="narrow rally tower"),
        ]}
    m["flyscreen"] = {"name": "Flyscreen", "culture": "Streetfighter", "parts": [
            screen_base(0.6, (-4.6, -3.8)),
            P("block", [1.3, 0.75, 0.12], [0, 4.82, -4.25], "glass", [38, 0, 0], note="raked flyscreen"),
        ]}
    m["canopy"] = {"name": "Canopy", "culture": "Speeder", "parts": [
            screen_base(0.7, (-4.8, -3.6)),
            wedge((-0.7, 0.7), (4.5, 4.95), (-4.8, -3.6), "nose", "glass", note="low canopy"),
            wedge((-0.06, 0.06), (4.5, 5.45), (-4.6, -3.6), "nose", "detail", note="canopy spine blade"),
        ]}
    return m


def bar_pads():
    return [box((-0.45, 0.45), (3.42, 3.75), (-3.1, -2.6), "detail", note="clamp: lands on the bar pad"),
            cx(HAND[1], -1.86, 0.9, 1.7, 0.36, "detail", mirror=True, note="grip: ends at the hand datum")]


def bars():
    m = {}
    m["clipons"] = {"name": "Clip-ons", "culture": "Supersport", "parts": bar_pads() + [
            tube([0.35, 3.6, -2.85], [0.95, 3.98, -1.9], 0.3, "detail", mirror=True, note="clip-on"),
        ]}
    m["clubmans"] = {"name": "Clubmans", "culture": "Cafe Racer", "parts": bar_pads() + [
            tube([0.3, 3.6, -2.85], [1.3, 3.56, -3.05], 0.26, "secondary", mirror=True, note="clubman: out and forward, low"),
            tube([1.3, 3.56, -3.05], [1.3, 3.98, -1.95], 0.26, "secondary", mirror=True, note="clubman: back up to the grip"),
        ]}
    m["pullbacks"] = {"name": "Pullbacks", "culture": "Chopper", "parts": bar_pads() + [
            tube([0.3, 3.6, -2.85], [0.55, 4.3, -3.0], 0.24, "secondary", mirror=True, note="short riser"),
            tube([0.55, 4.3, -3.0], [2.1, 4.3, -2.95], 0.24, "secondary", mirror=True, note="wide sweep: stays under Y 4.5"),
            tube([2.1, 4.3, -2.95], [1.6, 4.0, -1.9], 0.24, "secondary", mirror=True, note="pull-back to the grip"),
        ]}
    m["mxbars"] = {"name": "MX Bars", "culture": "Motocross", "parts": bar_pads() + [
            tube([0.35, 3.6, -2.85], [0.55, 4.1, -2.45], 0.28, "detail", mirror=True, note="riser"),
            tube([0.55, 4.1, -2.45], [1.9, 4.05, -1.9], 0.28, "secondary", mirror=True, note="wide bar"),
            cx(4.45, -2.45, -0.8, 0.8, 0.22, "secondary", note="crossbrace"),
            box((1.25, 2.25), (3.7, 4.35), (-2.45, -2.25), "primary", mirror=True, note="hand guard"),
        ]}
    m["dragbars"] = {"name": "Drag Bars", "culture": "Streetfighter", "parts": bar_pads() + [
            box((-0.4, 0.4), (3.75, 4.12), (-2.9, -1.75), "detail", note="pullback riser"),
            cx(HAND[1], -1.86, -2.2, 2.2, 0.26, "secondary", note="straight bar"),
            box((2.0, 2.3), (3.85, 4.15), (-2.02, -1.7), "neon", mirror=True, note="bar-end light"),
        ]}
    m["yoke"] = {"name": "Flight Yoke", "culture": "Speeder", "parts": bar_pads() + [
            box((-0.2, 0.2), (3.75, 4.0), (-2.9, -1.75), "detail", note="yoke stem"),
            cx(3.88, -1.86, -1.0, 1.0, 0.26, "detail", note="yoke cross tube"),
            cy(1.3, -1.86, 3.6, 4.7, 0.34, "secondary", mirror=True, note="upright stick"),
        ]}
    return m


def tanks():
    m = {}
    m["sculpted"] = {"name": "Sculpted", "culture": "Supersport", "parts": [
            box((-0.85, 0.85), (2.25, 3.0), (-2.5, 0.05), "primary", note="tank body"),
            box((-0.85, 0.85), (3.0, 3.38), (-2.5, -1.2), "primary", note="tank crown"),
            wedge((-0.85, 0.85), (3.0, 3.38), (-1.2, 0.05), "tail", "primary", note="slope to the seat"),
            box((0.9, 1.5), (2.3, 3.2), (-2.5, -1.3), "primary", mirror=True, note="knee shoulder"),
        ]}
    m["teardrop"] = {"name": "Long Alloy", "culture": "Cafe Racer", "parts": [
            box((-0.58, 0.58), (2.25, 3.3), (-2.5, -0.1), "primary", note="long narrow alloy tank: tall, flat top"),
            box((-0.62, 0.62), (2.25, 3.34), (-1.5, -1.3), "detail", note="tank strap"),
            box((0.58, 0.72), (2.5, 3.1), (-1.0, -0.2), "detail", mirror=True, note="knee pad"),
        ]}
    m["peanut"] = {"name": "Peanut", "culture": "Chopper", "parts": [
            cz(0, 2.82, -1.95, -1.05, 1.1, "primary", note="peanut tank"),
            ball(1.1, [0, 2.82, -1.95], "primary", note="tank nose"),
            ball(1.1, [0, 2.82, -1.05], "primary", note="tank tail"),
        ]}
    m["slab"] = {"name": "Slab", "culture": "Motocross", "parts": [
            box((-0.5, 0.5), (2.25, 2.85), (-2.5, 0.05), "primary", note="slim flat tank: the seat line runs straight over it"),
            box((-0.3, 0.3), (2.85, 3.05), (-2.2, -1.6), "detail", note="filler cap"),
        ]}
    m["muscle"] = {"name": "Muscle", "culture": "Streetfighter", "parts": [
            box((-0.88, 0.88), (2.25, 3.38), (-2.5, -1.2), "primary", note="short tall tank"),
            wedge((-0.88, 0.88), (2.25, 3.38), (-1.2, -0.7), "tail", "primary", note="chopped tank back"),
            box((-0.4, 0.4), (2.25, 2.6), (-0.7, 0.05), "detail", note="seat link"),
        ]}
    m["deck"] = {"name": "Sled Deck", "culture": "Speeder", "parts": [
            box((-0.85, 0.85), (2.25, 2.6), (-2.5, 0.05), "primary", note="flat deck"),
            wedge((-0.6, 0.6), (2.6, 3.3), (-1.6, 0.05), "nose", "detail", note="chest ramp"),
        ]}
    return m


def panels():
    m = {}
    m["raceflanks"] = {"name": "Race Flanks", "culture": "Supersport", "parts": [
            box((1.72, 2.0), (1.5, 3.2), (-3.1, -0.9), "primary", mirror=True, note="flank panel"),
            wedge((1.72, 2.0), (1.5, 3.2), (-0.9, 0.9), "tail", "primary", mirror=True, note="flank trailing edge"),
            box((2.0, 2.06), (1.8, 2.9), (-2.5, -2.3), "detail", mirror=True, note="gill"),
            box((2.0, 2.06), (1.8, 2.9), (-1.9, -1.7), "detail", mirror=True, note="gill"),
        ]}
    m["sidecovers"] = {"name": "Side Covers", "culture": "Cafe Racer", "parts": [
            wedge((1.72, 2.0), (1.4, 2.5), (0.0, 2.6), "kick", "primary", mirror=True, note="triangular side cover under the seat"),
            box((2.0, 2.08), (2.0, 2.3), (0.3, 1.5), "detail", mirror=True, note="cover strap"),
        ]}
    m["saddlebags"] = {"name": "Saddlebags", "culture": "Chopper", "parts": [
            box((1.72, 2.5), (1.4, 3.0), (1.3, 3.25), "primary", mirror=True, note="pannier: hangs to the tub wall cap line"),
            box((1.72, 2.55), (3.0, 3.2), (1.25, 3.3), "detail", mirror=True, note="pannier lid: top at Y 3.2"),
        ]}
    m["shrouds"] = {"name": "Shrouds", "culture": "Motocross", "parts": [
            wedge((1.72, 2.05), (2.3, 3.4), (-3.1, -0.9), "nose", "primary", mirror=True, note="radiator shroud"),
            box((1.72, 1.95), (1.7, 2.3), (-2.3, -1.2), "secondary", mirror=True, note="shroud fork"),
        ]}
    m["scoops"] = {"name": "Ram Scoops", "culture": "Streetfighter", "parts": [
            box((1.72, 2.5), (1.35, 2.35), (-2.9, -1.3), "primary", mirror=True, note="ram scoop"),
            box((1.82, 2.4), (1.45, 2.25), (-3.02, -2.9), "detail", mirror=True, note="scoop mouth"),
            wedge((1.72, 2.5), (1.35, 2.35), (-1.3, -0.3), "tail", "primary", mirror=True, note="scoop tail"),
        ]}
    m["strakes"] = {"name": "Delta Strakes", "culture": "Speeder", "parts": [
            delta(1.72, 2.6, (1.6, 1.8), (-3.1, 3.2), "primary", "delta strake"),
            box((1.72, 1.9), (1.8, 2.15), (-2.1, -1.7), "detail", mirror=True, note="front tab"),
        ]}
    return m


def rail():
    return [box(*RAIL, ch="detail", note="tail rail: lands on the cockpit rear, carries the tail kit")]


def seat_units():
    """Every seat unit starts at the seat tail datum (top at Y 3.4), so no cockpit hump ends in a step."""
    top = SEAT_TAIL[1]
    m = {}
    m["racecowl"] = {"name": "Race Cowl", "culture": "Supersport", "parts": rail() + [
            wedge((-1.05, 1.05), (2.3, top), (3.45, 6.7), "kick", "primary", note="tail underside"),
            wedge((-1.05, 1.05), (top, 4.0), (3.45, 6.7), "nose", "primary", note="tail hump"),
            box((-0.6, 0.6), (3.5, 3.85), (6.7, 6.78), "neon", note="tail light"),
        ]}
    m["bullettail"] = {"name": "Bullet Tail", "culture": "Cafe Racer", "parts": rail() + [
            cz(0, 2.75, 3.45, 4.5, 1.3, "primary", note="short round tail"),
            ball(1.3, [0, 2.75, 4.5], "primary", note="bullet end"),
            beam([0, 2.6, 4.9], [0, 2.3, 6.65], 1.0, 0.14, "primary", note="slim fender blade: runs to the tail so the tail kit never floats"),
        ]}
    m["bobber"] = {"name": "Bobber Fender", "culture": "Chopper", "parts": rail() + [
            box((-0.75, 0.75), (2.3, top), (3.45, 4.2), "detail", note="saddle tail"),
            beam([0, 3.3, 4.1], [0, 2.4, 6.6], 1.5, 0.2, "primary", note="long fender: runs to the tail so the tail kit rises from it"),
            beam([0, 3.46, 4.35], [0, 2.7, 6.45], 1.0, 0.3, "detail", note="pillion pad: the sissy bar backs it on every cockpit"),
            box((-0.3, 0.3), (2.2, 2.45), (6.45, 6.75), "neon", note="fender lamp"),
        ]}
    m["mxfender"] = {"name": "MX Fender", "culture": "Motocross", "parts": rail() + [
            wedge((-0.7, 0.7), (2.3, top), (3.45, 5.4), "kick", "primary", note="airbox side: flat top at the seat tail datum"),
            beam([0, 3.42, 4.4], [0, 4.25, 6.6], 0.9, 0.3, "primary", note="kicked-up fender"),
        ]}
    m["stubtail"] = {"name": "Stub Tail", "culture": "Streetfighter", "parts": rail() + [
            wedge((-1.35, 1.35), (2.3, top), (3.45, 5.1), "kick", "primary", note="stub underside"),
            wedge((-1.35, 1.35), (top, 4.5), (3.45, 5.1), "nose", "primary", note="stub kick"),
            box((-0.8, 0.8), (3.95, 4.2), (5.1, 5.18), "neon", note="slit tail lamp: 1.6 x 0.25"),
            wedge((-0.5, 0.5), (2.15, 2.75), (5.1, 6.7), "tail", "primary", note="tail boom: carries the tail kit"),
        ]}
    m["fintail"] = {"name": "Boat Tail", "culture": "Speeder", "parts": rail() + [
            box((-1.2, 1.2), (2.3, 3.0), (3.45, 6.0), "primary", note="tail deck"),
            wedge((-1.2, 1.2), (2.3, 3.0), (6.0, 6.75), "tail", "primary", note="deck tip"),
            wedge((-0.75, 0.75), (3.0, top), (3.45, 5.2), "tail", "primary", note="deck fairing: runs the seat tail down to the deck"),
            wedge((-0.1, 0.1), (3.0, 3.9), (4.2, 6.0), "nose", "secondary", note="low dorsal fin"),
        ]}
    return m


def tail_bracket():
    return [box((-0.3, 0.3), (1.9, 2.3), (6.85, 7.2), "detail", note="bracket: lands on the tail rail end")]


def tail_kits():
    m = {}
    m["tailtidy"] = {"name": "Tail Tidy", "culture": "Supersport", "parts": tail_bracket() + [
            box((-0.8, 0.8), (2.3, 2.55), (6.9, 7.2), "neon", note="light bar"),
        ]}
    m["bulletlamp"] = {"name": "Bullet Lamp", "culture": "Cafe Racer", "parts": tail_bracket() + [
            cz(0, 2.6, 6.9, 7.4, 0.5, "secondary", note="bullet lamp shell"),
            cz(0, 2.6, 7.4, 7.52, 0.36, "neon", note="lamp lens"),
        ]}
    m["shortsissy"] = {"name": "Short Sissy", "culture": "Chopper", "parts": tail_bracket() + [
            tube([0.55, 2.0, 7.0], [0.55, 4.2, 7.35], 0.22, "secondary", mirror=True, note="short upright: top under Y 4.4"),
            cx(4.2, 7.35, -0.66, 0.66, 0.22, "secondary", note="top bar"),
            P("block", [0.9, 1.0, 0.25], [0, 3.45, 7.1], "detail", [9, 0, 0], note="back pad: backs the pillion pad"),
        ]}
    m["rack"] = {"name": "Rack and Roll", "culture": "Motocross", "parts": tail_bracket() + [
            box((-0.9, 0.9), (2.3, 2.45), (6.85, 7.65), "detail", note="rack plate"),
            box((-0.8, 0.8), (2.45, 3.05), (6.95, 7.6), "primary", note="tool bag"),
        ]}
    m["winglet"] = {"name": "Tail Wing", "culture": "Streetfighter", "parts": tail_bracket() + [
            box((0.45, 0.6), (2.0, 3.3), (6.9, 7.2), "detail", mirror=True, note="wing post"),
            box((-1.35, 1.35), (3.3, 3.42), (6.85, 7.6), "primary", note="wing"),
            box((1.25, 1.38), (3.0, 3.8), (6.85, 7.65), "secondary", mirror=True, note="end plate"),
        ]}
    m["vtail"] = {"name": "V-Tail", "culture": "Speeder", "parts": tail_bracket() + [
            P("block", [0.15, 2.3, 0.8], [0.72, 3.15, 7.28], "primary", [0, 0, -24], mirror=True, note="canted fin"),
            box((-0.4, 0.4), (2.3, 2.5), (6.9, 7.6), "detail", note="fin root"),
        ]}
    return m


# ----------------------------------------------------------------------------- kits and builds
KITS = {
    "paddock": {"name": "Paddock", "culture": "Supersport", "modules": {
        "Engine1": "inline", "Engine2": "mono", "Stabilisers": "sportfork", "Boost": "twincans",
        "FrontBumper": "racenose", "RearBumper": "tailtidy", "RearSpoiler": "racecowl", "SidePods": "raceflanks",
        "Hood": "sculpted", "Roof": "bubble", "Accessory": "clipons"}},
    "tonup": {"name": "Ton-Up", "culture": "Cafe Racer", "modules": {
        "Engine1": "flattwin", "Engine2": "trident", "Stabilisers": "torpedo", "Boost": "reversecones",
        "FrontBumper": "dolphin", "RearBumper": "bulletlamp", "RearSpoiler": "bullettail", "SidePods": "sidecovers",
        "Hood": "teardrop", "Roof": "aero", "Accessory": "clubmans"}},
    "longhaul": {"name": "Long Haul", "culture": "Chopper", "modules": {
        "Engine1": "vtwin", "Engine2": "fatbob", "Stabilisers": "longrake", "Boost": "shotgun",
        "FrontBumper": "roundlamp", "RearBumper": "shortsissy", "RearSpoiler": "bobber", "SidePods": "saddlebags",
        "Hood": "peanut", "Roof": "tourer", "Accessory": "pullbacks"}},
    "holeshot": {"name": "Holeshot", "culture": "Motocross", "modules": {
        "Engine1": "thumper", "Engine2": "overunder", "Stabilisers": "liftcans", "Boost": "megaphone",
        "FrontBumper": "mxplate", "RearBumper": "rack", "RearSpoiler": "mxfender", "SidePods": "shrouds",
        "Hood": "slab", "Roof": "rally", "Accessory": "mxbars"}},
    "bareknuckle": {"name": "Bare Knuckle", "culture": "Streetfighter", "modules": {
        "Engine1": "fourposter", "Engine2": "twin", "Stabilisers": "girder", "Boost": "quadstubs",
        "FrontBumper": "mask", "RearBumper": "winglet", "RearSpoiler": "stubtail", "SidePods": "scoops",
        "Hood": "muscle", "Roof": "flyscreen", "Accessory": "dragbars"}},
    "outrider": {"name": "Outrider", "culture": "Speeder", "modules": {
        "Engine1": "slotburner", "Engine2": "fantail", "Stabilisers": "twinboom", "Boost": "slotblades",
        "FrontBumper": "prow", "RearBumper": "vtail", "RearSpoiler": "fintail", "SidePods": "strakes",
        "Hood": "deck", "Roof": "canopy", "Accessory": "yoke"}},
}

PAINT = {
    "supersport": {"primary": "#d81e2c", "secondary": "#f1f1f3", "neon": "#3ee6ff"},
    "cafe": {"primary": "#1f6f43", "secondary": "#d9d4c4", "neon": "#fff2c0"},
    "chopper": {"primary": "#5b2a86", "secondary": "#cfd3d8", "neon": "#ffb347"},
    "scrambler": {"primary": "#f2c40f", "secondary": "#f5f5f5", "neon": "#7dff6a"},
    "streetfighter": {"primary": "#ff6a13", "secondary": "#8d939c", "neon": "#ff3df0"},
    "speeder": {"primary": "#0f8f8f", "secondary": "#f0a030", "neon": "#fff2a0"},
}

BUILDS = [
    {"name": "01 Supersport, Paddock kit", "cockpit": "supersport", "kit": "paddock", "paint": PAINT["supersport"]},
    {"name": "02 Supersport, Long Haul kit", "cockpit": "supersport", "kit": "longhaul", "paint": PAINT["supersport"]},
    {"name": "03 Cafe, Ton-Up kit", "cockpit": "cafe", "kit": "tonup", "paint": PAINT["cafe"]},
    {"name": "04 Cafe, Bare Knuckle kit", "cockpit": "cafe", "kit": "bareknuckle", "paint": PAINT["cafe"]},
    {"name": "05 Chopper, Long Haul kit", "cockpit": "chopper", "kit": "longhaul", "paint": PAINT["chopper"]},
    {"name": "06 Chopper, Outrider kit", "cockpit": "chopper", "kit": "outrider", "paint": PAINT["chopper"]},
    {"name": "07 Scrambler, Holeshot kit", "cockpit": "scrambler", "kit": "holeshot", "paint": PAINT["scrambler"]},
    {"name": "08 Scrambler, Ton-Up kit", "cockpit": "scrambler", "kit": "tonup", "paint": PAINT["scrambler"]},
    {"name": "09 Streetfighter, Bare Knuckle kit", "cockpit": "streetfighter", "kit": "bareknuckle", "paint": PAINT["streetfighter"]},
    {"name": "10 Streetfighter, Holeshot kit", "cockpit": "streetfighter", "kit": "holeshot", "paint": PAINT["streetfighter"]},
    {"name": "11 Speeder, Outrider kit", "cockpit": "speeder", "kit": "outrider", "paint": PAINT["speeder"]},
    {"name": "12 Speeder, Bare Knuckle kit", "cockpit": "speeder", "kit": "bareknuckle", "paint": PAINT["speeder"]},
    {"name": "13 Mixed: street brawler", "cockpit": "streetfighter", "kit": "paddock",
     "modules": {"Engine1": "vtwin", "Engine2": "twin", "Boost": "megaphone", "FrontBumper": "roundlamp", "Roof": "flyscreen",
                 "RearSpoiler": "stubtail", "SidePods": "scoops", "Accessory": "dragbars"},
     "paint": {"primary": "#2a2d34", "secondary": "#c9a227", "neon": "#fff2c0"}},
    {"name": "14 Mixed: drag sled", "cockpit": "speeder", "kit": "longhaul",
     "modules": {"Engine1": "inline", "Engine2": "fantail", "Stabilisers": "girder", "Boost": "slotblades", "FrontBumper": "racenose",
                 "Roof": "canopy", "RearSpoiler": "fintail", "RearBumper": "winglet", "SidePods": "strakes", "Accessory": "clipons"},
     "paint": {"primary": "#20242c", "secondary": "#d22b2b", "neon": "#ff5555"}},
    {"name": "15 Mixed: rally chopper", "cockpit": "chopper", "kit": "holeshot",
     "modules": {"Engine1": "fourposter", "Engine2": "fatbob", "Stabilisers": "longrake", "Boost": "quadstubs", "Hood": "peanut",
                 "RearBumper": "shortsissy", "Accessory": "pullbacks"},
     "paint": {"primary": "#2b5fd9", "secondary": "#e9e9ee", "neon": "#ffd23d"}},
]


def build_spec():
    return {
        "id": "rider", "displayName": "Rider",
        "tagline": "Hoverbikes. The rider is always on show. Fork, turbine, swingarm and pipes are the jets.",
        "standard": STANDARD,
        "cockpits": cockpits(),
        "kits": KITS,
        "modules": {
            "Engine1": engine1(), "Engine2": engine2(), "Stabilisers": stabilisers(), "Boost": boost(),
            "FrontBumper": fairings(), "RearBumper": tail_kits(), "RearSpoiler": seat_units(), "SidePods": panels(),
            "Hood": tanks(), "Roof": screens(), "Accessory": bars(),
        },
        "builds": BUILDS,
    }


# ----------------------------------------------------------------------------- writer (one part per line)
def _dump(o, ind=0):
    pad = " " * ind
    if isinstance(o, dict):
        if "shape" in o or ("min" in o and "max" in o) or all(not isinstance(v, (dict, list)) for v in o.values()):
            return json.dumps(o)
        items = ["%s  %s: %s" % (pad, json.dumps(k), _dump(v, ind + 2)) for k, v in o.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(o, list):
        if all(not isinstance(v, (dict, list)) for v in o):
            return json.dumps(o)
        items = ["%s  %s" % (pad, _dump(v, ind + 2)) for v in o]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    return json.dumps(o)


def main():
    spec = build_spec()
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(_dump(spec) + "\n")
    n_mod = sum(len(v) for v in spec["modules"].values())
    print("wrote %s: %d cockpits, %d kits, %d modules, %d builds" % (OUT, len(spec["cockpits"]), len(spec["kits"]), n_mod, len(spec["builds"])))


if __name__ == "__main__":
    main()
