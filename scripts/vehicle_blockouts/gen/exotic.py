"""Generator for the Exotic frame class blockout (round 2). Design exploration only.

Run from the repo root:
  py -3 scripts/vehicle_blockouts/gen/exotic.py            writes specs/exotic.json
  py -3 scripts/vehicle_blockouts/gen/exotic.py --report   also prints part counts and distinctness tables

Exotic = mid-engined supercars and hypercars as hover jets. Root space: +X right, +Y up, forward is -Z.
Layout, front to back: nose (FrontBody) / cabin (cockpit) with a side pod each side (SidePods) / engine deck (RearBody).
  Engine1     main turbine on the deck pad behind the cabin, between the cockpit's buttresses
  Engine2     side engines: nacelles that sit on the rear haunches, fed by the side pods
  Stabilisers four corner units in the blanked arches, with optional outboard fins
  Boost       afterburner cluster in the tail notch, under the main turbine nozzle
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "specs", "exotic.json")

# ---------------------------------------------------------------- datums (studs)
HOVER = -2.0      # hover plane
FLOOR = -0.4      # underside of every body section
SILL = 0.2        # sill line
ARCH = 1.8        # arch top: stabiliser boxes stop here, fenders and side engines start here
BELT = 2.6        # beltline: tub top, cowl top, base of all cabin glass
DECK = 2.8        # engine deck pad and wing pad
SHELF = 1.2       # afterburner shelf in the tail notch
ZF = -5.2         # front seam: nose to cabin
ZR = 2.8          # rear seam: cabin to engine deck
ZNOSE = -11.6     # furthest forward a nose may reach
ZTAIL = 11.0      # furthest back the engine deck may reach
ZBOOM = 13.0      # furthest back the tail posts may run (twin tail booms)
ZBAY = 9.4        # rear end of the engine bay, front of the afterburner notch
FA0, FA1 = -9.0, -5.8   # front arch (centre -7.4)
RA0, RA1 = 5.2, 8.4     # rear arch (centre 6.8)
FAC, RAC = -7.4, 6.8
XBAY = 2.0        # half width of the engine bay
XBOOST = 2.6      # half width of the afterburner notch
XCORE = 3.6       # half width of tub and centre body: arch inner wall, side engine inner face, side pod inner face
XGLASS = 4.5      # widest the cabin glass may be: it may overhang the side pods above the beltline
XBODY = 5.5       # half width of nose and deck
XPOD = 5.6        # outer limit of side pods and side engines
XSTAB = 6.0       # outer limit of stabilisers
GAP = 0.1         # every skin stops this far short of its seam

D, P, S, G, N, T, DR = "detail", "primary", "secondary", "glass", "neon", "thrust", "driver"


# ---------------------------------------------------------------- part helpers
def r(v):
    return round(float(v), 3)


def part(shape, size, pos, ch=P, rot=None, m=False, note=None):
    p = {"shape": shape, "size": [r(v) for v in size], "pos": [r(v) for v in pos], "ch": ch}
    if rot:
        p["rot"] = [r(v) for v in rot]
    if m:
        p["mirror"] = True
    if note:
        p["note"] = note
    return p


def box(x0, x1, y0, y1, z0, z1, ch=P, m=False, note=None):
    return part("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, None, m, note)


# Wedge kinds. The name says where the full base is (rise = base down, hang = base up, plan = upright sides)
# and which way the tall face points.
_WEDGE = {
    "rise_back": ([0, 0, 0], "xyz"),       # low at the front, high at the back (bonnet, windscreen)
    "rise_front": ([0, 180, 0], "xyz"),    # high at the front, low at the back (fastback, tail)
    "hang_back": ([0, 0, 180], "xyz"),     # flat top, underside drops toward the back
    "hang_front": ([180, 0, 0], "xyz"),    # flat top, underside rises toward the back (diffuser)
    "rise_xneg": ([0, -90, 0], "zyx"),     # tall face toward -X, thin edge at +X (right-hand tumblehome)
    "rise_xpos": ([0, 90, 0], "zyx"),      # tall face toward +X
    "hang_xneg": ([0, -90, 180], "zyx"),
    "hang_xpos": ([0, 90, 180], "zyx"),
    "plan_xneg_back": ([0, 0, -90], "yxz"),    # plan taper: straight edge on -X, full width at back, point at front
    "plan_xpos_back": ([0, 0, 90], "yxz"),
    "plan_xneg_front": ([0, 180, 90], "yxz"),  # plan taper: straight edge on -X, full width at front, point at back
    "plan_xpos_front": ([0, 180, -90], "yxz"),
}


def wedge(kind, x0, x1, y0, y1, z0, z1, ch=P, m=False, note=None):
    rot, order = _WEDGE[kind]
    d = {"x": x1 - x0, "y": y1 - y0, "z": z1 - z0}
    return part("wedge", [d[order[0]], d[order[1]], d[order[2]]],
                [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def cz(x, y, z0, z1, dia, ch=P, m=False, note=None):
    return part("cyl_z", [dia, dia, z1 - z0], [x, y, (z0 + z1) / 2], ch, None, m, note)


def cy(x, z, y0, y1, dia, ch=P, m=False, note=None):
    return part("cyl_y", [dia, y1 - y0, dia], [x, (y0 + y1) / 2, z], ch, None, m, note)


def cx(y, z, x0, x1, dia, ch=P, m=False, note=None):
    return part("cyl_x", [x1 - x0, dia, dia], [(x0 + x1) / 2, y, z], ch, None, m, note)


def ball(x, y, z, dia, ch=P, m=False, note=None):
    return part("ball", [dia, dia, dia], [x, y, z], ch, None, m, note)


def tube(x, y, z, dia, length, pitch, ch=P, m=False, note=None):
    """A cyl_z pitched about X. pitch > 0 points the rear end down. (x, y, z) is the FRONT end of the axis."""
    a = math.radians(pitch)
    c = [x, y - math.sin(a) * length / 2, z + math.cos(a) * length / 2]
    return part("cyl_z", [dia, dia, length], c, ch, [pitch, 0, 0], m, note)


def slab(x0, x1, y, z, thick, length, pitch, ch=P, m=False, note=None):
    """A flat block pitched about X. pitch > 0 points the rear end down. (y, z) is the FRONT end of its centre line."""
    a = math.radians(pitch)
    c = [(x0 + x1) / 2, y - math.sin(a) * length / 2, z + math.cos(a) * length / 2]
    return part("block", [x1 - x0, thick, length], c, ch, [pitch, 0, 0], m, note)


def tube_end(x, y, z, length, pitch):
    a = math.radians(pitch)
    return x, y - math.sin(a) * length, z + math.cos(a) * length


# ---------------------------------------------------------------- frame standard
def standard():
    slots = {
        "FrontBody": {
            "label": "Nose",
            "envelope": [
                {"min": [-XCORE, FLOOR, ZNOSE], "max": [XCORE, BELT, ZF]},
                {"min": [XCORE, FLOOR, ZNOSE], "max": [XBODY, 3.0, FA0], "mirror": True},
                {"min": [XCORE, ARCH, FA0], "max": [XBODY, 3.0, FA1], "mirror": True},
                {"min": [XCORE, FLOOR, FA1], "max": [XBODY, 3.0, ZF], "mirror": True},
            ],
            "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -7]},
        "RearBody": {
            "label": "Engine Deck",
            "envelope": [
                {"min": [-XCORE, FLOOR, ZR], "max": [XCORE, DECK, ZBAY]},
                {"min": [-XCORE, FLOOR, ZBAY], "max": [XCORE, SHELF, ZTAIL]},
                {"min": [XBOOST, SHELF, ZBAY], "max": [XCORE, DECK, ZBOOM], "mirror": True},
                {"min": [XCORE, FLOOR, ZR], "max": [XBODY, ARCH, RA0], "mirror": True},
                {"min": [XCORE, FLOOR, RA1], "max": [XBODY, ARCH, ZTAIL], "mirror": True},
            ],
            "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, -1.5, 7]},
        "SidePods": {
            "label": "Side Pods",
            "envelope": [
                {"min": [XCORE, -0.6, ZF], "max": [XPOD, BELT, ZR], "mirror": True},
                {"min": [XGLASS, BELT, ZF], "max": [XPOD, 3.2, ZR], "mirror": True},
            ],
            "anchor": {"to": "cockpit", "face": "-x"}, "explode": [5, 0, 0]},
        "Engine1": {
            "label": "Main Turbine",
            "envelope": {"min": [-XBAY, DECK, ZR], "max": [XBAY, 4.6, ZBAY]},
            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 6.5, 5]},
        "Engine2": {
            "label": "Side Engines",
            "envelope": {"min": [XCORE, ARCH, ZR], "max": [XPOD, 3.6, 11.4], "mirror": True},
            "anchor": {"to": "RearBody", "face": "-x"}, "explode": [6, 3, 7]},
        "Stabilisers": {
            "label": "Stabilisers",
            "envelope": [
                {"min": [XCORE, -1.6, FA0], "max": [XSTAB, ARCH, FA1], "mirror": True},
                {"min": [XCORE, -1.6, RA0], "max": [XSTAB, ARCH, RA1], "mirror": True},
                {"min": [XPOD, ARCH, FA0], "max": [XSTAB, 3.2, FA1], "mirror": True},
                {"min": [XPOD, ARCH, RA0], "max": [XSTAB, 3.6, RA1], "mirror": True},
            ],
            "anchor": [{"to": "FrontBody", "face": "-x"}, {"to": "RearBody", "face": "-x"}], "explode": [4.5, -4.5, 0]},
        "Boost": {
            "label": "Afterburner",
            "envelope": {"min": [-XBOOST, SHELF, ZBAY], "max": [XBOOST, 3.2, 12.6]},
            "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, 1, 13]},
        "FrontBumper": {
            "label": "Splitter",
            "envelope": [
                {"min": [-5.8, -1.4, -12.6], "max": [5.8, FLOOR, FA0]},
                {"min": [-5.8, FLOOR, -12.6], "max": [5.8, 1.0, ZNOSE]},
            ],
            "anchor": {"to": "FrontBody", "face": "+y"}, "explode": [0, -4, -9]},
        "RearBumper": {
            "label": "Diffuser",
            "envelope": [
                {"min": [-5.8, -1.4, RA1], "max": [5.8, FLOOR, 12.4]},
                {"min": [-5.8, FLOOR, ZTAIL], "max": [5.8, SHELF, 12.4]},
            ],
            "anchor": {"to": "RearBody", "face": "+y"}, "explode": [0, -6, 9]},
        "RearSpoiler": {
            "label": "Wing",
            "envelope": [
                {"min": [XBOOST, DECK, ZBAY], "max": [XCORE, 3.8, ZTAIL], "mirror": True},
                {"min": [-5.8, 3.8, ZBAY], "max": [5.8, 6.6, 12.6]},
            ],
            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 9, 11]},
    }
    return {
        "cockpitEnvelope": [
            {"min": [-XCORE, FLOOR, ZF], "max": [XCORE, BELT, ZR]},
            {"min": [-XGLASS, BELT, ZF], "max": [XGLASS, 5.2, ZR]},
            {"min": [-XCORE, BELT, -6.8], "max": [XCORE, 3.8, ZF]},
            {"min": [XBAY, DECK, ZR], "max": [XCORE, 5.2, 8.6], "mirror": True},
            {"min": [-XBAY, 4.6, ZR], "max": [XBAY, 5.2, 8.6]},
        ],
        "datums": {"hoverPlane": HOVER, "floor": FLOOR, "sill": SILL, "archTop": ARCH, "beltline": BELT,
                   "deckPad": DECK, "boostShelf": SHELF, "frontSeamZ": ZF, "rearSeamZ": ZR,
                   "frontArchZ": [FA0, FA1], "rearArchZ": [RA0, RA1], "bayHalfWidth": XBAY,
                   "coreHalfWidth": XCORE, "glassHalfWidth": XGLASS},
        "slots": slots,
    }


# ---------------------------------------------------------------- cockpits
def chassis(cowl_z, shelf_z, x_belt, seat_x=1.8, driver_x=None):
    """The narrow tub every cockpit shares: floor, seam plates, flat tub sides, cowl, rear shelf, seats, driver."""
    dx = -seat_x if driver_x is None else driver_x
    p = [
        box(-3.5, 3.5, FLOOR, 0.0, ZF + 0.12, ZR - 0.12, D, note="tub floor"),
        box(-3.4, 3.4, 0.0, 2.45, ZF, ZF + 0.12, D, note="front seam plate: dark linkage in the shadow gap to the nose"),
        box(-3.4, 3.4, 0.0, 2.7, ZR - 0.12, ZR, D, note="rear seam plate: dark linkage to the engine deck"),
        box(3.15, 3.5, 0.0, BELT, ZF + 0.12, ZR - 0.12, P, m=True, note="tub side: the flat pad every side pod lands on"),
        box(3.5, 3.57, 2.05, 2.35, ZF + 0.12, ZR - 0.12, S, m=True, note="belt stripe: accent runs through every kit"),
        box(-3.15, 3.15, 1.9, BELT, ZF + 0.12, cowl_z, P, note="cowl"),
        box(-3.15, 3.15, 1.9, BELT, shelf_z, ZR - 0.12, P, note="rear shelf over the firewall"),
        box(-2.9, 2.9, 1.2, 2.3, cowl_z, cowl_z + 0.7, D, note="dash"),
        box(seat_x - 0.7, seat_x + 0.7, 0.0, 2.5, 0.9, 1.4, D, m=True, note="seat backs"),
        box(dx - 0.65, dx + 0.65, 0.3, 2.5, 0.0, 0.9, DR, note="driver torso"),
        ball(dx, 3.05, 0.4, 1.2, DR, note="driver head: top at Y 3.65"),
    ]
    if x_belt < 3.1:
        p.append(box(x_belt, 3.15, 2.3, BELT, cowl_z, shelf_z, P, m=True, note="shoulder between glass and tub side"))
    return p


def canopy(zb, zt, zre, yr, xb, xt, facet=0.6):
    """Closed cabin glass: sloped windscreen with faceted corners, glass cell and roof slab."""
    return [
        wedge("rise_back", -xt, xt, BELT, yr, zb, zt, G, note="windscreen"),
        wedge("rise_back", xt, xb, BELT, BELT + (yr - BELT) * facet, zb, zt, G, m=True, note="windscreen corner facet"),
        box(-xt, xt, BELT, yr - 0.22, zt, zre, G, note="cabin glass"),
        box(-xt, xt, yr - 0.22, yr, zt, zre, P, note="roof"),
    ]


def cockpit_wedge():
    """70s-80s poster wedge: one flat line from nose to roof, low flat roof, upright tail glass and a hard notch down to low shoulder air boxes."""
    p = chassis(cowl_z=-4.3, shelf_z=1.9, x_belt=3.5)
    p += canopy(zb=-6.7, zt=-1.6, zre=2.6, yr=4.05, xb=3.5, xt=2.6)
    p += [
        wedge("rise_xneg", 2.6, 3.5, BELT, 4.05, -1.6, 1.0, G, m=True, note="side glass, heavy tumblehome"),
        wedge("rise_xneg", 2.6, 3.5, BELT, 4.05, 1.0, ZR - 0.12, P, m=True, note="sail panel"),
        box(-0.5, 0.5, 4.05, 4.12, -1.2, 2.4, D, note="periscope trench"),
        box(2.1, 3.5, 2.85, 3.4, 2.9, 6.2, P, m=True, note="low shoulder air box: the roof drops to it in a hard notch"),
        wedge("rise_front", 2.1, 3.5, 2.85, 3.4, 6.2, 7.6, P, m=True, note="air box tail"),
        box(2.3, 3.3, 3.4, 3.47, 3.1, 5.8, D, m=True, note="air box grille"),
    ]
    return p


def cockpit_curve():
    """90s teardrop: long raked screen from far forward, a short thin roof at the peak, glass fastback that tapers in plan, flying buttresses that carry the roofline down the deck."""
    p = chassis(cowl_z=-4.6, shelf_z=1.9, x_belt=3.3, seat_x=1.5)
    p += [
        wedge("rise_back", -2.1, 2.1, BELT, 4.95, -6.6, -2.2, G, note="windscreen"),
        wedge("rise_back", 2.1, 3.3, BELT, 3.8, -6.6, -2.2, G, m=True, note="windscreen corner"),
        box(-2.1, 2.1, BELT, 4.7, -2.2, -0.6, G, note="cabin glass"),
        box(-2.1, 2.1, 4.7, 4.95, -2.2, -0.6, P, note="thin roof: the peak of the teardrop"),
        wedge("rise_xneg", 2.1, 3.3, BELT, 4.5, -2.2, 0.4, G, m=True, note="side glass"),
        wedge("rise_xneg", 2.1, 3.3, BELT, 4.5, 0.4, ZR - 0.12, P, m=True, note="rear quarter"),
        box(-2.1, 2.1, BELT, 4.5, -0.6, 1.0, G, note="fastback glass"),
        box(-1.2, 1.2, BELT, 4.5, 1.0, ZR - 0.12, G, note="fastback glass, narrow tail"),
        wedge("plan_xneg_front", 1.2, 2.1, BELT, 4.5, 1.0, ZR - 0.12, G, m=True, note="glass tapers in plan"),
        wedge("plan_xpos_back", 1.2, 2.1, BELT, 4.5, 1.0, ZR - 0.12, P, m=True, note="pillar widens to the buttress"),
        wedge("rise_front", -2.1, 2.1, 4.5, 4.95, -0.6, ZR - 0.12, G, note="falling roof glass"),
        wedge("rise_front", -0.4, 0.4, 4.5, 5.05, -0.6, ZR - 0.12, P, note="fastback spine"),
        wedge("rise_front", 2.1, 2.9, 2.85, 4.5, 2.85, 8.0, P, m=True, note="flying buttress: the roofline runs down the deck"),
        wedge("rise_front", 2.9, 3.4, 2.85, 3.45, 2.85, 6.2, P, m=True, note="buttress shoulder"),
        box(-0.4, 0.4, 4.95, 5.1, -1.9, -0.6, P, note="roof scoop"),
        box(-0.3, 0.3, 4.97, 5.07, -1.98, -1.9, D, note="roof scoop mouth"),
    ]
    return p


def cockpit_hyper():
    """Modern hypercar: very narrow fighter canopy on wide flat shoulder wings, roof snorkel, dorsal fin over the turbine."""
    yr = 4.6
    p = chassis(cowl_z=-4.4, shelf_z=0.6, x_belt=2.6)
    p += canopy(zb=-6.6, zt=-2.6, zre=0.6, yr=yr, xb=2.6, xt=1.5)
    p += [
        wedge("rise_xneg", 1.5, 2.6, BELT, yr, -2.6, 0.6, G, m=True, note="side glass"),
        wedge("rise_front", -1.5, 1.5, BELT, yr, 0.6, ZR - 0.12, P, note="canopy tail"),
        wedge("rise_front", 1.5, 2.6, BELT, 3.8, 0.6, ZR - 0.12, P, m=True, note="canopy tail flank"),
        box(-0.7, 0.7, yr, 5.1, -0.8, ZR - 0.12, P, note="roof snorkel"),
        box(-0.3, 0.3, 4.62, 5.1, ZR - 0.12, 4.4, P, note="snorkel spine: slim, so the turbine stays in view"),
        wedge("rise_front", -0.3, 0.3, 4.62, 5.1, 4.4, 6.0, P, note="snorkel tail"),
        box(-0.55, 0.55, yr + 0.08, 5.02, -0.88, -0.8, D, note="snorkel mouth"),
        box(-0.45, 0.45, 3.0, yr, 1.7, ZR - 0.12, P, note="snorkel pylon"),
        box(-0.12, 0.12, 4.62, 5.18, 4.4, 8.5, S, note="dorsal fin"),
        box(2.7, 4.4, BELT, 2.74, -3.6, ZR - 0.12, S, m=True, note="shoulder wing: overhangs the side pod"),
        wedge("rise_front", 3.3, 3.5, 2.85, 3.75, 2.85, 8.3, S, m=True, note="fin rail"),
    ]
    return p


def cockpit_spider():
    """Open spider: low wrap screen, no roof, driver in the open, two slim roll humps with short tails behind the seats."""
    p = chassis(cowl_z=-4.2, shelf_z=1.4, x_belt=3.5, seat_x=2.0)
    p += [
        wedge("rise_back", -2.6, 2.6, BELT, 3.4, -5.0, -3.6, G, note="low screen"),
        wedge("rise_back", 2.6, 3.5, BELT, 3.0, -5.0, -3.6, G, m=True, note="screen corner"),
        box(-2.6, 2.6, 3.3, 3.42, -3.7, -3.5, D, note="screen header rail"),
        box(1.4, 2.6, BELT, 3.8, 1.4, ZR - 0.12, P, m=True, note="roll hump"),
        box(1.5, 2.5, 2.9, 3.65, 1.3, 1.4, D, m=True, note="headrest pad"),
        wedge("rise_front", 2.05, 2.6, 2.85, 3.8, 2.85, 5.4, P, m=True, note="hump tail"),
        box(1.9, 2.1, 3.8, 3.87, 1.6, 2.6, S, m=True, note="hump stripe"),
    ]
    return p


def cockpit_longtail():
    """Endurance longtail: low bubble, small side glass, long roof scoop, thick twin tail fins that rise from the deck to the rear."""
    yr = 4.3
    p = chassis(cowl_z=-4.6, shelf_z=1.2, x_belt=3.0)
    p += canopy(zb=-5.1, zt=-2.6, zre=1.2, yr=yr, xb=3.0, xt=1.9)
    p += [
        wedge("rise_xneg", 1.9, 3.0, BELT, yr, -2.6, -0.4, G, m=True, note="small side glass"),
        wedge("rise_xneg", 1.9, 3.0, BELT, yr, -0.4, ZR - 0.12, P, m=True, note="blanked rear quarter"),
        box(-1.9, 1.9, BELT, yr, 1.2, ZR - 0.12, P, note="cabin back"),
        box(-0.8, 0.8, yr, 5.0, -1.4, ZR - 0.12, P, note="roof scoop"),
        box(-0.65, 0.65, yr + 0.1, 4.9, -1.48, -1.4, D, note="scoop mouth"),
        wedge("rise_front", -0.3, 0.3, 4.62, 5.0, ZR - 0.12, 7.6, P, note="long scoop tail: a slim spine over the turbine"),
        box(2.9, 3.5, 2.85, 3.1, 2.85, 8.5, S, m=True, note="fin base rail"),
        wedge("rise_back", 2.9, 3.5, 3.1, 5.15, 3.6, 8.5, S, m=True, note="tail fin, rising to the rear"),
    ]
    return p


def cockpit_gull():
    """Gullwing: short steep screen, a double-bubble glass roof either side of a raised hinge spine, bulged doors that overhang the side pods, a falling glass cover over the turbine."""
    yb = 4.0      # top of the door glass: the bubbles stand on this line
    p = chassis(cowl_z=-4.4, shelf_z=1.8, x_belt=3.5)
    p += [
        wedge("rise_back", -2.0, 2.0, BELT, 4.3, -5.1, -2.6, G, note="windscreen: short and steep"),
        wedge("rise_back", 2.0, 3.5, BELT, 3.7, -5.1, -2.6, G, m=True, note="windscreen corner facet"),
        box(-2.0, 2.0, BELT, yb, -2.6, 1.6, G, note="cabin glass"),
        cz(1.1, 3.85, -2.6, 1.2, 2.0, G, m=True, note="roof bubble over each seat: top at Y 4.85"),
        ball(1.1, 3.85, -2.6, 2.0, G, m=True, note="bubble nose: stands proud of the screen"),
        ball(1.1, 3.85, 1.2, 2.0, G, m=True, note="bubble tail: a round end to the cabin"),
        box(-0.35, 0.35, yb, 5.0, -2.9, 1.6, S, note="raised roof spine: the door hinge line"),
        wedge("rise_back", -0.35, 0.35, 4.3, 5.0, -3.7, -2.9, S, note="spine nose"),
        box(0.35, 0.85, 4.62, 5.0, -1.8, -1.1, D, m=True, note="hinge hump"),
        box(0.35, 0.85, 4.62, 5.0, 0.1, 0.8, D, m=True, note="hinge hump"),
        box(1.95, 2.2, 3.85, 4.12, -2.6, 1.6, P, m=True, note="door cant rail: the door cut runs up to it"),
        box(2.0, 2.2, BELT, 4.12, -2.72, -2.6, D, m=True, note="door cut, front: rises into the roof"),
        box(2.0, 2.2, BELT, 4.12, 1.6, 1.72, D, m=True, note="door cut, rear"),
        wedge("rise_xneg", 2.0, 4.4, BELT, yb, -2.6, 1.6, G, m=True, note="gullwing door glass: overhangs the side pod"),
        box(3.5, 4.4, BELT, 3.25, -2.2, 1.4, P, m=True, note="door bulge"),
        box(-2.0, 2.0, BELT, 4.6, 1.72, ZR - 0.12, P, note="roof hoop"),
        wedge("rise_xneg", 2.0, 3.5, BELT, 4.3, 1.72, ZR - 0.12, P, m=True, note="sail panel"),
        wedge("rise_front", -2.0, 2.0, 4.6, 4.95, ZR - 0.12, 6.6, G, note="glass engine cover: falls to the rear"),
        wedge("rise_front", -0.25, 0.25, 4.62, 5.08, ZR - 0.12, 5.0, S, note="spine tail on the cover"),
        box(2.0, 2.2, 4.55, 4.75, ZR - 0.12, 6.6, P, m=True, note="cover rail"),
        box(2.0, 2.2, 2.85, 4.55, 6.3, 6.6, D, m=True, note="cover strut to the deck"),
    ]
    return p


# ---------------------------------------------------------------- FrontBody (Nose)
def _fender_vent(y1=2.2):
    return box(3.75, 5.3, 0.4, y1, ZF - GAP, ZF - 0.02, D, m=True, note="fender vent: finished face at the cabin seam")


def nose_shovel():
    """Wedge: one flat plane from a long chisel lip to the scuttle. Nothing ahead of the arches, box flares that hang over them."""
    z0 = -11.5
    return [
        box(-3.3, 3.3, FLOOR, 0.0, z0, ZF - GAP, D, note="undertray: splitter hardpoint"),
        box(-3.55, 3.55, 0.0, 0.4, z0, -6.6, P, note="lip"),
        wedge("rise_back", -3.55, 3.55, 0.4, 2.5, z0, -6.6, P, note="bonnet plane"),
        box(-3.55, 3.55, 0.0, 2.5, -6.6, ZF - GAP, P, note="scuttle pad"),
        wedge("rise_back", 3.6, 5.4, 1.85, 2.5, FA0, -7.8, P, m=True, note="box flare front"),
        box(3.6, 5.4, 1.85, 2.5, -7.8, ZF - GAP, P, m=True, note="box flare over the arch"),
        box(-1.6, 1.6, 0.05, 0.35, z0 - 0.1, z0, D, note="grille slot"),
        box(1.9, 3.4, 0.05, 0.35, z0 - 0.1, z0, N, m=True, note="strip lamp"),
        part("block", [1.3, 0.08, 1.0], [2.3, 1.1, -10.0], D, [-23.2, 0, 0], True, "pop-up lamp lid"),
        box(-3.55, 3.55, 2.5, 2.56, -6.2, -5.7, S, note="scuttle stripe"),
    ]


def nose_droplet():
    """Analogue: short rounded bonnet, tall peaked fenders over the arches with round lamps in their fronts. Nothing ahead of the arches."""
    return [
        box(-3.3, 3.3, FLOOR, 0.0, -10.5, ZF - GAP, D, note="undertray: splitter hardpoint"),
        box(-2.6, 2.6, 0.0, 0.9, -10.6, -9.9, P, note="nose block"),
        wedge("rise_back", -2.6, 2.6, 0.9, 1.6, -10.6, -9.9, P, note="chamfered nose edge"),
        box(-2.6, 2.6, 0.0, 1.6, -9.9, -6.6, P),
        wedge("rise_back", -2.6, 2.6, 1.6, 2.5, -9.9, -6.6, P, note="bonnet"),
        box(-3.55, 3.55, 0.0, 2.5, -6.6, ZF - GAP, P, note="scuttle pad"),
        box(2.6, 3.55, 0.0, 1.75, -9.4, -6.6, P, m=True, note="arch inner wall"),
        wedge("rise_xpos", 3.6, 4.5, 1.85, 2.95, FA0, ZF - GAP, P, m=True, note="fender ridge, inner"),
        wedge("rise_xneg", 4.5, 5.4, 1.85, 2.95, FA0, ZF - GAP, P, m=True, note="fender ridge, outer"),
        cz(4.5, 2.35, FA0 - 0.5, FA0, 0.9, D, m=True, note="lamp bezel"),
        cz(4.5, 2.35, FA0 - 0.62, FA0 - 0.5, 0.7, N, m=True, note="round lamp"),
        box(3.6, 5.4, 0.0, 1.85, FA1, ZF - GAP, P, m=True, note="fender behind the arch"),
        _fender_vent(1.7),
    ]


def nose_keel():
    """Hypercar: raised needle keel that widens to the scuttle through faceted shoulders, open air channels under them, fender blades with prows and light bars."""
    return [
        box(-1.2, 1.2, FLOOR, 0.0, -11.2, -7.2, D, note="keel undertray: splitter hardpoint"),
        box(-1.3, 1.3, 0.0, 0.5, -11.5, -7.2, P),
        wedge("rise_back", -1.3, 1.3, 0.5, 2.5, -11.5, -7.2, P, note="needle keel"),
        box(-0.35, 0.35, 0.0, 0.5, -11.57, -11.5, S, note="keel tip"),
        wedge("rise_back", 1.3, 2.45, 1.38, 2.5, -9.6, -7.2, P, m=True, note="inner shoulder: the keel widens toward the scuttle"),
        wedge("rise_back", 2.45, 3.55, 1.94, 2.5, -8.4, -7.2, P, m=True, note="outer shoulder: joins the fender blade"),
        box(-3.55, 3.55, 0.8, 2.5, -7.2, ZF - GAP, P, note="scuttle pad"),
        box(-3.3, 3.3, FLOOR, 0.8, -7.1, ZF - GAP, D, note="radiator pack"),
        box(1.4, 3.4, 0.9, 1.35, -7.28, -7.2, D, m=True, note="radiator face under the shoulder"),
        box(3.3, 3.5, FLOOR, 1.75, FA0 + 0.05, -7.2, D, m=True, note="channel wall: stabiliser hardpoint"),
        box(3.6, 5.4, 1.85, 2.2, FA0, FA1 - 0.05, P, m=True, note="fender blade over the arch"),
        box(4.0, 5.0, 2.2, 2.26, -8.6, -6.4, D, m=True, note="fender vent over the stabiliser"),
        box(4.7, 5.4, 0.2, 0.6, -10.8, FA0 - 0.05, P, m=True, note="blade prow"),
        wedge("rise_back", 4.7, 5.4, 0.6, 2.2, -10.8, FA0 - 0.05, P, m=True, note="blade prow"),
        box(4.7, 5.4, 0.25, 0.55, -10.88, -10.8, N, m=True, note="light bar"),
    ]


def nose_blunt():
    """Track special: short blunt face with a big intake and lamps in it, bonnet extractor, half fenders over the arches, twin dive planes."""
    return [
        box(-3.3, 3.3, FLOOR, 0.0, -10.2, ZF - GAP, D, note="undertray: splitter hardpoint"),
        box(-3.55, 3.55, 0.0, 2.1, -10.2, -7.4, P, note="blunt nose"),
        box(-2.6, 2.6, 0.3, 1.7, -10.3, -10.2, D, note="intake"),
        box(2.75, 3.4, 0.5, 1.5, -10.3, -10.2, N, m=True, note="lamp"),
        wedge("rise_back", -3.55, 3.55, 2.1, 2.5, -8.4, -7.4, P, note="extractor ramp"),
        box(-2.2, 2.2, 2.1, 2.17, -9.8, -8.6, D, note="bonnet extractor"),
        box(-3.55, 3.55, 0.0, 2.5, -7.4, ZF - GAP, P, note="scuttle pad"),
        box(3.55, 5.4, 0.45, 0.55, -10.2, -9.1, S, m=True, note="lower dive plane"),
        box(3.55, 4.9, 1.35, 1.45, -10.2, -9.3, S, m=True, note="upper dive plane"),
        wedge("rise_back", 3.6, 4.5, 1.85, 2.5, FA0, -7.8, P, m=True, note="half fender: the outer half of the arch stays open so the jet shows"),
        box(3.6, 4.5, 1.85, 2.5, -7.8, FA1, P, m=True, note="half fender"),
        box(3.6, 5.4, 0.2, 1.3, FA1, ZF - GAP, P, m=True, note="low fender wall behind the arch"),
    ]


def nose_lowline():
    """Longtail: two long tall lamp towers ahead of the arches, a recessed valley between them, fenders that fall to the belt."""
    return [
        box(-3.3, 3.3, FLOOR, 0.0, -9.6, ZF - GAP, D, note="undertray: splitter hardpoint"),
        box(3.55, 5.3, FLOOR, 0.0, -11.5, FA0 - 0.05, D, m=True, note="tower undertray"),
        wedge("rise_back", -2.2, 2.2, 0.0, 2.5, -9.6, -6.6, P, note="centre valley"),
        box(-3.55, 3.55, 0.0, 2.5, -6.6, ZF - GAP, P, note="scuttle pad"),
        box(2.2, 3.55, 0.0, 1.75, -10.6, -6.6, P, m=True, note="valley wall and arch inner"),
        box(3.55, 5.4, 0.0, 2.2, -11.5, FA0 - 0.05, P, m=True, note="lamp tower"),
        wedge("rise_back", 3.6, 5.4, 2.2, 2.95, -11.5, FA0 - 0.05, P, m=True, note="tower crown"),
        wedge("rise_front", 3.6, 5.4, 1.85, 2.95, FA0, FA1 - 0.05, P, m=True, note="fender falls to the beltline"),
        box(3.9, 5.1, 0.5, 1.9, -11.58, -11.5, N, m=True, note="lamp stack"),
        box(-0.6, 0.6, 2.5, 2.56, -6.6, -5.5, S, note="centre stripe"),
    ]


def nose_visor():
    """Concept: flat low platform the full width ahead of bare arches, full-width light visor, steep ramp to the scuttle."""
    return [
        box(-3.3, 3.3, FLOOR, 0.0, -11.3, ZF - GAP, D, note="undertray: splitter hardpoint"),
        box(-5.4, 5.4, 0.0, 0.7, -11.4, FA0 - 0.05, P, note="platform"),
        wedge("rise_back", -5.4, 5.4, 0.7, 1.2, -11.4, -10.4, P, note="platform lip"),
        box(-5.4, 5.4, 0.7, 1.2, -10.4, FA0 - 0.05, P),
        box(-5.2, 5.2, 0.15, 0.5, -11.48, -11.4, N, note="full-width light visor"),
        box(-3.55, 3.55, 0.0, 1.2, FA0 - 0.05, -6.6, P, note="centre deck: stabiliser hardpoint on its side"),
        wedge("rise_back", -3.55, 3.55, 1.2, 2.5, -8.2, -6.6, P, note="steep ramp"),
        box(-3.55, 3.55, 0.0, 2.5, -6.6, ZF - GAP, P, note="scuttle pad"),
        box(-2.6, 2.6, 1.2, 1.27, -10.2, -8.6, D, note="louvre panel"),
        box(3.9, 5.1, 1.2, 1.6, -10.3, -9.2, P, m=True, note="pop-up lamp pod"),
        box(3.95, 5.05, 1.25, 1.55, -10.38, -10.3, N, m=True, note="lamp"),
    ]


# ---------------------------------------------------------------- RearBody (Engine Deck)
def _bay_pad():
    return box(-1.9, 1.9, 2.55, 2.75, ZR + 0.15, ZBAY - 0.1, D, note="engine bay pad: every main turbine lands here")


def _hull():
    return [
        box(-3.3, 3.3, 0.0, 2.55, ZR + GAP, ZBAY - 0.05, P, note="hull"),
        box(3.3, 3.55, 0.0, 2.75, ZR + GAP, ZBAY - 0.05, D, m=True, note="rail: side engine and stabiliser hardpoint"),
        box(2.0, 3.3, 2.55, 2.75, ZR + GAP, ZBAY - 0.05, P, m=True, note="deck shoulder"),
        _bay_pad(),
    ]


def _wing_post(z1, y0=1.15, ch=P):
    return box(2.65, 3.55, y0, 2.75, ZBAY, z1, ch, m=True, note="tail post: wing pad on top")


def deck_slab():
    """Wedge: boxy full-width deck, square haunches, tall square corners, tail chopped square just behind the wing pads."""
    zt = 10.0
    return _hull() + [
        box(-3.5, 3.5, FLOOR, 0.0, ZR + GAP, zt, D, note="undertray: diffuser hardpoint"),
        box(2.2, 3.1, 2.75, 2.8, 4.6, 9.0, D, m=True, note="shoulder louvres"),
        box(3.6, 5.4, SILL, 1.75, 3.1, RA0 - 0.05, P, m=True, note="haunch ahead of the arch"),
        box(3.75, 5.25, 0.4, 1.55, ZR + 0.15, 3.1, D, m=True, note="side intake mouth"),
        box(3.6, 5.4, FLOOR, SILL, ZR + 0.15, RA0 - 0.05, D, m=True, note="sill"),
        box(3.6, 5.4, FLOOR, 1.75, RA1 + 0.05, zt, P, m=True, note="tall square tail corner"),
        box(-3.55, 3.55, 0.0, 1.15, ZBAY - 0.05, zt, P, note="afterburner shelf"),
        _wing_post(zt),
        box(-2.5, 2.5, 0.2, 1.0, zt, zt + 0.08, D, note="tail panel"),
        box(3.7, 5.3, 0.9, 1.5, zt, zt + 0.08, N, m=True, note="tail lamp bar"),
        box(2.75, 3.45, 1.4, 2.5, zt, zt + 0.08, N, m=True, note="tail lamp"),
    ]


def deck_boat():
    """Analogue: smooth belly with no undertray step, round haunches, no tail corners, a boat tail that narrows in plan and droops, four round lamps."""
    lamps = [cz(3.1, y, 10.0, 10.1, 0.55, N, m=True, note="round lamp") for y in (1.6, 2.3)]
    return _hull() + [
        cz(4.5, 0.95, 3.05, RA0 - 0.05, 1.6, P, m=True, note="rounded haunch"),
        cz(4.5, 0.95, ZR + 0.12, 3.05, 1.3, D, m=True, note="intake mouth"),
        box(-3.55, 3.55, 0.0, 1.15, ZBAY - 0.05, 10.0, P, note="afterburner shelf: its flat belly is the diffuser hardpoint"),
        box(-1.5, 1.5, 0.0, 1.15, 10.0, 10.45, P, note="boat tail"),
        wedge("plan_xneg_front", 1.5, 3.55, 0.0, 1.15, 10.0, 10.95, P, m=True, note="tail narrows in plan"),
        wedge("rise_front", -1.5, 1.5, 0.0, 1.15, 10.45, 10.95, P, note="drooping tail edge"),
        _wing_post(10.0),
    ] + lamps


def deck_tunnel():
    """Hypercar: a centre spine, open channels either side, slim longerons on arms, swept intake fins and wake fins."""
    return [
        box(-2.0, 2.0, FLOOR, 0.0, ZR + GAP, 10.6, D, note="spine undertray: diffuser hardpoint"),
        box(-2.0, 2.0, 0.0, 2.55, ZR + GAP, ZBAY - 0.05, P, note="spine"),
        _bay_pad(),
        box(3.3, 3.55, 1.6, 2.75, ZR + GAP, ZBAY - 0.05, P, m=True, note="longeron: side engine hardpoint"),
        box(2.0, 3.3, 1.9, 2.5, 3.2, 3.9, D, m=True, note="arm"),
        box(2.0, 3.3, 1.9, 2.5, 8.4, 9.1, D, m=True, note="arm"),
        box(3.3, 3.55, 0.0, 1.6, RA0 + 0.3, RA1 - 0.3, D, m=True, note="arch plate: stabiliser hardpoint"),
        box(2.0, 3.3, 0.2, 0.7, 6.5, 7.1, D, m=True, note="lower arm"),
        box(5.1, 5.4, 0.0, 0.6, ZR + 0.15, RA0 - 0.05, P, m=True, note="intake fin root"),
        wedge("rise_back", 5.1, 5.4, 0.6, 1.75, ZR + 0.15, RA0 - 0.05, P, m=True, note="intake fin, swept up to the arch"),
        box(3.55, 5.1, 0.2, 0.4, 3.6, 4.0, D, m=True, note="fin strut"),
        box(5.2, 5.4, -0.2, 0.5, RA1 + 0.05, 10.9, S, m=True, note="wake fin root"),
        wedge("rise_front", 5.2, 5.4, 0.5, 1.75, RA1 + 0.05, 10.9, S, m=True, note="wake fin, swept down to the tail"),
        box(3.55, 5.2, 0.1, 0.3, RA1 + 0.3, RA1 + 0.7, D, m=True, note="wake fin strut"),
        box(-2.0, 2.0, 0.0, 1.15, ZBAY - 0.05, 10.6, P, note="afterburner shelf"),
        box(-3.55, 3.55, 0.75, 1.15, ZBAY - 0.05, 10.0, P, note="tail beam"),
        _wing_post(10.0),
        box(-3.5, 3.5, 0.85, 1.1, 10.0, 10.08, N, note="light blade"),
    ]


def deck_frame():
    """Track special: a painted engine cradle inside a bare tube frame, vented haunches that fall to the arch, short low corners, crash structure and rain light."""
    posts = [box(2.6, 3.0, 0.0, 2.3, z, z + 0.35, D, m=True, note="frame upright") for z in (2.95, 5.6, 8.95)]
    cross = [box(-2.6, 2.6, 2.3, 2.55, z, z + 0.35, D, note="frame cross member") for z in (2.95, 5.6, 8.95)]
    return [
        box(2.6, 3.0, 2.3, 2.55, ZR + GAP, ZBAY - 0.05, D, m=True, note="frame top rail"),
        box(3.0, 3.55, 1.9, 2.75, ZR + GAP, ZBAY - 0.05, P, m=True, note="shoulder rail: side engine hardpoint"),
        box(3.2, 3.55, 0.0, 0.9, RA0 + 0.4, RA1 - 0.4, D, m=True, note="arch hardpoint for the stabiliser arm"),
        box(3.2, 3.5, 0.9, 1.9, 6.6, 6.95, D, m=True, note="hanger"),
        box(-2.4, 2.4, 0.0, 2.3, 3.3, 8.95, P, note="painted engine cradle: nothing is see-through"),
        box(2.4, 2.47, 0.5, 1.7, 3.6, 5.3, D, m=True, note="cradle vent"),
        box(2.4, 2.47, 0.5, 1.7, 6.2, 8.7, D, m=True, note="cradle vent"),
        box(3.6, 5.4, SILL, 0.9, 2.95, RA0 - 0.05, P, m=True, note="haunch"),
        wedge("rise_front", 3.6, 5.4, 0.9, 1.75, 2.95, RA0 - 0.05, P, m=True, note="haunch falls to the arch"),
        box(5.4, 5.46, 0.35, 0.75, 3.3, 4.8, D, m=True, note="haunch vent"),
        box(3.6, 5.4, SILL, 1.3, RA1 + 0.05, 9.9, P, m=True, note="short low tail corner"),
        box(3.9, 5.1, 0.5, 1.0, 9.9, 9.98, N, m=True, note="corner lamp"),
        _bay_pad(),
        box(-3.0, 3.0, 0.0, 1.15, ZBAY - 0.05, 9.9, P, note="painted crash structure: afterburner shelf"),
        box(-2.4, 2.4, 0.2, 0.95, 9.9, 9.96, D, note="crash structure grille"),
        _wing_post(9.95, 1.15, D),
        box(2.8, 3.4, 2.0, 2.5, 9.95, 10.03, N, m=True, note="tail lamp"),
        box(-0.3, 0.3, 0.3, 0.9, 9.9, 9.98, N, note="rain light"),
    ] + posts + cross


def deck_streamer():
    """Longtail: smooth belly with a tray under the tail only, haunches that swell in plan, drooping tail corners, twin tail booms that run far past the afterburner."""
    zb = ZBOOM - 0.1
    return _hull() + [
        box(-3.5, 3.5, FLOOR, 0.0, 8.2, 10.95, D, note="tail tray: diffuser hardpoint"),
        wedge("plan_xneg_back", 3.6, 5.4, 0.0, 1.75, ZR + 0.15, RA0 - 0.05, P, m=True, note="haunch swells toward the arch"),
        box(3.6, 5.4, 0.7, 1.75, RA1 + 0.05, 9.6, P, m=True, note="tail corner, raised over the diffuser"),
        wedge("rise_front", 3.6, 5.4, 0.7, 1.75, 9.6, 10.95, P, m=True, note="drooping tail corner"),
        box(-3.55, 3.55, 0.0, 1.15, ZBAY - 0.05, 10.95, P, note="afterburner shelf"),
        _wing_post(10.95),
        box(2.65, 3.55, 1.25, 2.75, 10.95, zb, P, m=True, note="tail boom: the long tail"),
        box(3.55, 3.6, 1.8, 2.2, 9.6, zb - 0.3, S, m=True, note="boom stripe"),
        box(2.9, 3.3, 1.45, 2.55, zb, zb + 0.07, N, m=True, note="upright lamp strip"),
        box(-2.5, 2.5, 0.45, 0.7, 10.95, 11.02, S, note="tail stripe"),
    ]


def deck_kamm():
    """Concept: twin hulls with an open venturi tunnel under the turbine, no haunch and no corners, sheer cut-off tail with a light band."""
    zt = 10.3
    return [
        box(2.0, 3.3, FLOOR, 2.55, ZR + GAP, ZBAY - 0.05, P, m=True, note="side hull"),
        box(-2.0, 2.0, 2.2, 2.55, ZR + GAP, ZBAY - 0.05, P, note="tunnel roof"),
        box(3.3, 3.55, 0.0, 2.75, ZR + GAP, ZBAY - 0.05, P, m=True, note="hull side: side engine and stabiliser hardpoint"),
        box(3.55, 3.6, 0.9, 1.3, 3.2, RA0 - 0.3, S, m=True, note="flank stripe"),
        box(2.0, 3.3, 2.55, 2.75, ZR + GAP, ZBAY - 0.05, P, m=True, note="deck shoulder"),
        _bay_pad(),
        box(2.2, 3.1, 2.75, 2.8, 3.4, 8.8, D, m=True, note="deck louvres"),
        box(2.0, 3.55, FLOOR, 0.75, ZBAY - 0.05, zt, P, m=True, note="hull tail"),
        box(-3.55, 3.55, 0.75, 1.15, ZBAY - 0.05, zt, P, note="afterburner shelf over the tunnel exit"),
        _wing_post(zt),
        box(-3.5, 3.5, 0.8, 1.1, zt, zt + 0.08, N, note="full-width light band"),
        box(2.75, 3.45, 1.3, 2.6, zt, zt + 0.08, D, m=True, note="tail vent"),
    ]


# ---------------------------------------------------------------- Engine1 (Main Turbine)
def e1_mono():
    """Wedge: one fat round turbine the full length of the bay, bellmouth forward, bleed ducts down both flanks, one big nozzle straight out the back."""
    return [
        box(-0.9, 0.9, 2.85, 3.1, 3.4, 8.4, D, note="cradle on the bay pad"),
        cz(0, 3.72, 2.95, 3.7, 1.75, D, note="intake bellmouth"),
        cz(0, 3.72, 3.7, 7.7, 1.7, S, note="turbine casing"),
        box(0.75, 1.3, 3.2, 3.9, 4.2, 7.2, D, m=True, note="bleed duct"),
        cz(0, 3.72, 7.7, 9.1, 1.55, D, note="nozzle"),
        cz(0, 3.72, 9.1, 9.32, 1.3, T, note="thrust"),
    ]


def e1_twin():
    """Analogue: two turbines side by side the full length of the bay, a shared plenum, dark heat-shield rails, twin nozzles. No glass: the cockpit owns all glass."""
    return [
        box(-1.8, 1.8, 2.85, 3.9, 3.0, 3.7, D, note="shared intake plenum"),
        box(-1.5, 1.5, 3.9, 3.98, 3.1, 3.6, S, note="plenum intake grille"),
        cz(0.85, 3.5, 3.7, 7.6, 1.3, S, m=True, note="turbine"),
        box(0.7, 1.0, 4.13, 4.28, 3.9, 7.4, D, m=True, note="heat-shield rail"),
        cz(0.85, 3.5, 7.6, 9.0, 1.1, D, m=True, note="nozzle"),
        cz(0.85, 3.5, 9.0, 9.2, 0.95, T, m=True, note="thrust"),
    ]


def e1_top():
    """Hypercar: a round core set back in the bay behind a flat ram scoop, two fat stacks beside it that fire straight up."""
    return [
        box(-0.8, 0.8, 2.85, 3.05, 4.2, 8.8, D, note="cradle on the bay pad"),
        cz(0, 3.7, 4.0, 8.9, 1.6, S, note="round core"),
        cz(0, 3.7, 8.9, 9.3, 1.1, D, note="core tail cap"),
        box(-1.4, 1.4, 3.3, 4.3, 3.0, 4.0, D, note="ram scoop"),
        box(-1.4, 1.4, 4.3, 4.4, 3.0, 4.3, S, note="scoop lip"),
        cy(1.35, 8.6, 3.0, 4.3, 1.2, D, m=True, note="top-exit stack"),
        cy(1.35, 8.6, 4.3, 4.5, 1.0, T, m=True, note="thrust, upward"),
        box(-1.95, 1.95, 2.85, 3.0, 7.9, 9.3, D, note="heat shield"),
    ]


def e1_stacks():
    """Track special: low block under eight open intake trumpets, twin fat megaphone nozzles."""
    trumpets = [cy(0.85, z, 3.7, 4.5, 0.55, S, m=True, note="intake trumpet") for z in (3.8, 4.8, 5.8, 6.8)]
    return [
        box(-1.5, 1.5, 2.85, 3.5, 3.2, 7.7, D, note="block"),
        box(0.3, 1.4, 3.5, 3.7, 3.3, 7.6, P, m=True, note="cam cover"),
        cz(0.9, 3.4, 7.7, 9.05, 1.1, D, m=True, note="megaphone nozzle"),
        cz(0.9, 3.4, 9.05, 9.25, 0.95, T, m=True, note="thrust"),
    ] + trumpets


def e1_long():
    """Longtail: one slim tube down the bay under a snorkel scoop with an open mouth, flaring in plan to a tall wide fishtail nozzle with three glowing cells."""
    return [
        box(-0.5, 0.5, 2.85, 3.0, 3.4, 8.0, D, note="cradle on the bay pad"),
        cz(0, 3.6, 2.95, 3.4, 1.55, D, note="bellmouth"),
        cz(0, 3.6, 3.4, 8.0, 1.4, S, note="lance casing"),
        box(-0.5, 0.5, 4.0, 4.58, 3.5, 4.6, S, note="slim snorkel scoop"),
        wedge("rise_front", -0.5, 0.5, 4.0, 4.58, 4.6, 5.8, S, note="scoop tail"),
        box(-0.4, 0.4, 4.08, 4.5, 3.4, 3.5, D, note="snorkel intake mouth"),
        wedge("plan_xneg_back", 0.6, 1.6, 3.05, 4.15, 6.8, 8.0, D, m=True, note="fishtail flare: widens in plan"),
        box(-1.6, 1.6, 3.05, 4.15, 8.0, 9.1, D, note="fishtail nozzle: 3.2 wide, 1.1 tall"),
        box(-1.45, 1.45, 3.2, 4.0, 9.1, 9.32, T, note="thrust slot: 2.9 wide, 0.8 tall"),
        box(0.43, 0.55, 3.12, 4.08, 9.0, 9.36, D, m=True, note="nozzle vane"),
    ]


def e1_cross():
    """Concept: a chamfered box plenum set across the bay with a periscope intake and square side intakes, two slim pipes down the bay edges to twin nozzles."""
    return [
        box(-1.6, 1.6, 2.85, 3.05, 3.2, 5.0, D, note="cradle on the bay pad"),
        box(-1.9, 1.9, 3.05, 4.0, 3.3, 4.9, S, note="cross plenum"),
        wedge("rise_back", -1.9, 1.9, 4.0, 4.5, 3.3, 4.1, S, note="plenum chamfer, front"),
        wedge("rise_front", -1.9, 1.9, 4.0, 4.5, 4.1, 4.9, S, note="plenum chamfer, rear"),
        box(1.9, 1.98, 3.2, 3.85, 3.5, 4.7, D, m=True, note="square side intake"),
        box(-0.6, 0.6, 4.3, 4.58, 3.6, 4.6, D, note="periscope intake"),
        cz(1.4, 3.45, 4.9, 8.2, 0.8, D, m=True, note="jet pipe"),
        box(1.2, 1.6, 2.85, 3.05, 6.3, 6.7, D, m=True, note="pipe stand"),
        cz(1.4, 3.45, 8.2, 9.0, 1.1, D, m=True, note="nozzle"),
        cz(1.4, 3.45, 9.0, 9.2, 0.95, T, m=True, note="thrust"),
    ]


# ---------------------------------------------------------------- Engine2 (Side Engines)
def e2_box():
    """Wedge: one tall square ram box per side, hard against the cabin, big square nozzle over the arch."""
    return [
        box(3.85, 5.35, 2.05, 3.35, 2.87, 2.95, D, m=True, note="intake mouth"),
        box(3.7, 5.5, 1.9, 3.5, 2.95, 7.4, P, m=True, note="ram box"),
        box(4.0, 5.2, 3.5, 3.56, 3.4, 6.8, D, m=True, note="top louvres"),
        box(5.5, 5.57, 2.5, 2.8, 2.95, 7.4, S, m=True, note="stripe"),
        box(3.9, 5.3, 2.0, 3.3, 7.4, 8.6, D, m=True, note="square nozzle"),
        box(4.05, 5.15, 2.15, 3.15, 8.6, 8.75, T, m=True, note="thrust"),
    ]


def e2_round():
    """Analogue: one short round pod per side, set back over the arch on a pylon."""
    return [
        box(3.65, 4.2, 1.9, 2.6, 5.6, 8.6, D, m=True, note="pylon to the rail"),
        cz(4.65, 2.75, 5.0, 5.5, 1.7, D, m=True, note="intake lip"),
        cz(4.65, 2.75, 5.5, 9.2, 1.6, P, m=True, note="round pod"),
        cz(4.65, 2.75, 6.8, 7.4, 1.68, S, m=True, note="band"),
        cz(4.65, 2.75, 9.2, 10.3, 1.25, D, m=True, note="nozzle"),
        cz(4.65, 2.75, 10.3, 10.5, 0.95, T, m=True, note="thrust"),
    ]


def e2_twin():
    """Hypercar: two tubes per side stacked one above the other, held outboard on a thin pylon. Four nozzles."""
    return [
        box(3.65, 4.7, 2.55, 2.85, 5.0, 8.0, D, m=True, note="pylon to the rail"),
        cz(5.1, 2.3, 3.4, 9.8, 0.95, P, m=True, note="lower tube"),
        cz(5.1, 2.3, 3.2, 3.4, 0.75, D, m=True, note="lower intake"),
        cz(5.1, 2.3, 9.8, 10.7, 0.8, D, m=True, note="lower nozzle"),
        cz(5.1, 2.3, 10.7, 10.85, 0.65, T, m=True, note="thrust"),
        cz(5.1, 3.1, 4.4, 8.8, 0.95, S, m=True, note="upper tube"),
        cz(5.1, 3.1, 4.2, 4.4, 0.75, D, m=True, note="upper intake"),
        cz(5.1, 3.1, 8.8, 9.6, 0.8, D, m=True, note="upper nozzle"),
        cz(5.1, 3.1, 9.6, 9.75, 0.65, T, m=True, note="thrust"),
    ]


def e2_stub():
    """Track special: fat short burner at the very tail, fed by a painted box duct from a big trumpet behind the cabin."""
    return [
        box(3.65, 4.4, 1.9, 2.5, 3.0, 3.4, D, m=True, note="trumpet bracket"),
        cz(4.6, 2.8, 2.9, 3.5, 1.5, D, m=True, note="intake trumpet"),
        box(3.8, 5.0, 1.95, 2.65, 3.5, 8.4, P, m=True, note="feed duct: low, flat and painted"),
        box(4.0, 4.8, 2.65, 2.71, 4.0, 7.8, D, m=True, note="duct louvres"),
        box(3.65, 4.2, 1.9, 2.6, 8.3, 9.3, D, m=True, note="pod bracket"),
        cz(4.6, 2.75, 8.4, 10.3, 1.7, S, m=True, note="stub burner"),
        cz(4.6, 2.75, 10.3, 11.1, 1.3, D, m=True, note="nozzle"),
        cz(4.6, 2.75, 11.1, 11.3, 1.0, T, m=True, note="thrust"),
    ]


def e2_lance():
    """Longtail: one long exposed tube per side on a low narrow fairing, bellmouth behind the cabin, nozzle past the tail."""
    return [
        box(3.7, 4.7, 1.9, 2.5, 4.2, 9.0, P, m=True, note="narrow fairing"),
        wedge("rise_back", 3.7, 4.7, 1.9, 2.5, 2.95, 4.2, P, m=True, note="fairing nose"),
        wedge("rise_front", 3.7, 4.7, 1.9, 2.5, 9.0, 10.4, P, m=True, note="fairing tail"),
        cz(5.0, 2.95, 3.0, 3.5, 1.2, D, m=True, note="bellmouth intake"),
        cz(5.0, 2.95, 3.5, 10.4, 1.0, S, m=True, note="lance tube, outboard and high"),
        cz(5.0, 2.95, 10.4, 11.2, 0.9, D, m=True, note="nozzle"),
        cz(5.0, 2.95, 11.2, 11.35, 0.8, T, m=True, note="thrust"),
    ]


def e2_ear():
    """Concept: tall narrow ear scoop tight against the cabin, a duct that falls into a long pipe to the tail."""
    return [
        box(3.7, 4.5, 1.9, 3.55, 2.95, 4.6, P, m=True, note="ear scoop"),
        box(3.8, 4.4, 2.1, 3.4, 2.87, 2.95, D, m=True, note="scoop mouth"),
        wedge("rise_front", 3.7, 4.5, 1.9, 3.55, 4.6, 7.8, P, m=True, note="falling duct"),
        box(4.5, 4.58, 2.2, 2.5, 3.0, 6.0, S, m=True, note="stripe"),
        cz(4.2, 2.45, 7.0, 10.6, 1.1, D, m=True, note="jet pipe and nozzle"),
        cz(4.2, 2.45, 10.6, 10.8, 1.0, T, m=True, note="thrust"),
    ]


# ---------------------------------------------------------------- Stabilisers
def _corners(fn):
    return fn(FAC, False) + fn(RAC, True)


def st_vector():
    """Wedge: one long slim pod per corner with a nozzle vectored down and back, small fin on top."""
    def corner(zc, rear):
        ex, ey, ez = tube_end(4.85, 0.3, zc + 0.6, 0.9, 50)
        return [
            box(3.65, 4.3, 0.0, 0.6, zc - 0.5, zc + 0.5, D, m=True, note="arm to the arch wall"),
            cz(4.85, 0.3, zc - 1.5, zc + 0.6, 1.2, S, m=True, note="pod"),
            cz(4.85, 0.3, zc - 1.58, zc - 1.5, 0.95, D, m=True, note="intake"),
            tube(4.85, 0.3, zc + 0.6, 0.9, 0.9, 50, D, m=True, note="vectoring nozzle"),
            tube(ex, ey, ez, 0.7, 0.2, 50, T, m=True, note="thrust"),
            wedge("rise_back", 4.75, 4.95, 0.9, 1.75, zc - 1.2, zc + 0.4, P, m=True, note="trim fin"),
        ]
    return _corners(corner)


def st_lift():
    """Analogue: two short upright lift cans per corner, tucked up into the arch. The only upright-can option."""
    def corner(zc, rear):
        p = [box(3.65, 4.2, 0.3, 0.9, zc - 0.9, zc + 0.9, D, m=True, note="bracket to the arch wall")]
        for dz in (-0.8, 0.8):
            p.append(cy(4.6, zc + dz, 0.5, 1.6, 1.3, P, m=True, note="lift can shroud, up in the arch"))
            p.append(cy(4.6, zc + dz, -0.45, 0.5, 1.1, D, m=True, note="short lift nozzle"))
            p.append(cy(4.6, zc + dz, 1.6, 1.75, 1.0, D, m=True, note="intake"))
            p.append(cy(4.6, zc + dz, -0.7, -0.45, 1.0, T, m=True, note="thrust: ends level with the splitters"))
        return p
    return _corners(corner)


def st_blade():
    """Hypercar: an exposed nacelle in the arch with its nozzle angled down and back, a swept active blade standing on its outer edge."""
    def corner(zc, rear):
        top = 3.4 if rear else 3.0
        x, y = 5.2, -0.1
        ex, ey, ez = tube_end(x, y, zc + 0.3, 1.0, 35)
        return [
            box(3.65, 4.7, -0.3, 0.3, zc - 0.4, zc + 0.4, D, m=True, note="arm to the arch wall"),
            cz(x, y, zc - 1.58, zc - 1.4, 1.0, D, m=True, note="intake"),
            cz(x, y, zc - 1.4, zc + 0.3, 1.2, P, m=True, note="nacelle"),
            tube(x, y, zc + 0.3, 0.95, 1.0, 35, D, m=True, note="nozzle, down and back"),
            tube(ex, ey, ez, 0.75, 0.2, 35, T, m=True, note="thrust"),
            box(5.5, 5.9, 0.3, 0.6, zc - 0.9, zc + 0.3, D, m=True, note="blade pylon on the nacelle"),
            box(5.65, 5.9, 0.6, 1.1, zc - 1.3, zc + 1.3, S, m=True, note="blade root: starts above the nacelle"),
            wedge("rise_back", 5.65, 5.9, 1.1, top, zc - 1.3, zc + 1.3, S, m=True, note="swept active blade, outboard of the body"),
        ]
    return _corners(corner)


def st_out():
    """Track special: slender nacelle held out on two wishbone arms, pitched nose-up, tail fin."""
    def corner(zc, rear):
        ex, ey, ez = tube_end(5.3, 0.62, zc - 1.2, 2.4, 15)
        return [
            box(3.65, 5.0, 0.4, 0.6, zc - 1.0, zc - 0.7, D, m=True, note="wishbone arm"),
            box(3.65, 5.0, 0.1, 0.3, zc + 0.5, zc + 0.8, D, m=True, note="wishbone arm"),
            tube(5.3, 0.62, zc - 1.2, 1.0, 2.4, 15, P, m=True, note="nacelle"),
            tube(ex, ey, ez, 0.7, 0.2, 15, T, m=True, note="thrust"),
            box(5.2, 5.4, 0.8, 1.7, zc - 0.5, zc + 0.5, S, m=True, note="fin"),
        ]
    return _corners(corner)


def st_trio():
    """Longtail: a louvred skirt along the arch over a cascade of three flat slot nozzles raked down and back. No cans."""
    def corner(zc, rear):
        p = [box(3.65, 5.3, 0.6, 1.0, zc - 1.4, zc + 1.4, D, m=True, note="manifold to the arch wall"),
             box(5.3, 5.6, 0.7, 1.7, zc - 1.55, zc + 1.55, P, m=True, note="skirt along the arch"),
             box(5.6, 5.68, 0.85, 1.0, zc - 1.3, zc + 1.3, D, m=True, note="skirt louvre"),
             box(5.6, 5.68, 1.15, 1.3, zc - 1.3, zc + 1.3, D, m=True, note="skirt louvre"),
             box(5.6, 5.68, 1.45, 1.6, zc - 1.3, zc + 1.3, S, m=True, note="skirt stripe")]
        for dz in (-1.4, -0.5, 0.4):
            _, ey, ez = tube_end(0, 0.6, zc + dz, 1.35, 55)
            p.append(slab(4.0, 5.5, 0.6, zc + dz, 0.3, 1.35, 55, S, m=True, note="slot nozzle, raked back"))
            p.append(slab(4.1, 5.4, ey, ez, 0.26, 0.3, 55, T, m=True, note="thrust: ends near Y -0.8"))
        return p
    return _corners(corner)


def st_tip():
    """Concept: a flat canard plane out of each arch, a long slim jet on its tip, one lift jet under it."""
    def corner(zc, rear):
        return [
            box(3.65, 5.4, 0.55, 0.75, zc - 1.2, zc + 0.9, S, m=True, note="canard plane"),
            cz(5.6, 0.65, zc - 1.5, zc + 1.1, 0.7, P, m=True, note="tip jet"),
            cz(5.6, 0.65, zc - 1.58, zc - 1.5, 0.5, D, m=True, note="intake"),
            cz(5.6, 0.65, zc + 1.1, zc + 1.45, 0.5, D, m=True, note="nozzle"),
            cz(5.6, 0.65, zc + 1.45, zc + 1.58, 0.4, T, m=True, note="thrust"),
            cy(4.5, zc - 0.1, -0.5, 0.55, 0.8, D, m=True, note="lift jet under the plane"),
            cy(4.5, zc - 0.1, -0.65, -0.5, 0.6, T, m=True, note="thrust"),
        ]
    return _corners(corner)


# ---------------------------------------------------------------- Boost (Afterburner)
def b_quad():
    """Wedge: four long slim cans spread in a row."""
    p = [box(-2.4, 2.4, 1.5, 2.5, 9.5, 9.9, D, note="manifold on the tail wall")]
    for x in (0.7, 2.05):
        p.append(cz(x, 2.0, 9.9, 12.2, 0.8, S, m=True, note="can"))
        p.append(cz(x, 2.0, 12.2, 12.35, 0.6, T, m=True, note="thrust"))
    return p


def b_twin():
    """Analogue: two big long cannons."""
    return [
        box(-2.3, 2.3, 1.3, 3.1, 9.5, 9.8, D, note="back plate on the tail wall"),
        cz(1.25, 2.2, 9.8, 12.4, 1.8, S, m=True, note="cannon: 2.6 long"),
        cz(1.25, 2.2, 10.2, 11.2, 1.88, D, m=True, note="cannon collar"),
        cz(1.25, 2.2, 12.4, 12.58, 1.4, T, m=True, note="thrust"),
    ]


def b_tri():
    """Hypercar: three cans in a wide triangle, one fat short can high over two slim long ones set wide apart. All three glows show from behind."""
    return [
        box(-1.9, 1.9, 1.3, 2.2, 9.5, 9.8, D, note="manifold on the tail wall"),
        box(-0.6, 0.6, 2.2, 3.1, 9.5, 9.8, D, note="manifold riser"),
        cz(1.45, 1.72, 9.8, 12.0, 0.9, D, m=True, note="lower can: slim, and runs past the tail"),
        cz(0, 2.52, 9.8, 11.2, 1.3, S, note="upper can: fat and short"),
        cz(1.45, 1.72, 12.0, 12.15, 0.7, T, m=True, note="thrust"),
        cz(0, 2.52, 11.2, 11.38, 1.05, T, note="thrust"),
    ]


def b_slot():
    """Track special: one wide flat slot burner with vanes, very short."""
    vanes = [box(x - 0.06, x + 0.06, 1.45, 2.05, 10.4, 10.75, D, note="vane") for x in (-1.2, 0.0, 1.2)]
    return [
        box(-2.5, 2.5, 1.35, 2.15, 9.5, 10.5, D, note="burner box"),
        box(-2.55, 2.55, 2.15, 2.3, 9.5, 10.7, S, note="lip"),
        box(-2.3, 2.3, 1.5, 2.0, 10.5, 10.62, T, note="thrust slot"),
    ] + vanes


def b_bore():
    """Longtail: one long big-bore afterburner."""
    return [
        cz(0, 2.2, 9.5, 12.2, 1.95, D, note="big bore"),
        cz(0, 2.2, 10.0, 11.0, 1.98, S, note="collar"),
        cz(0, 2.2, 12.2, 12.4, 1.6, T, note="thrust"),
    ]


def b_split():
    """Concept: two tall narrow slot burners set wide apart, nothing in the middle."""
    return [
        box(-1.7, 1.7, 2.0, 2.4, 9.5, 9.8, D, note="cross manifold on the tail wall"),
        box(1.7, 2.5, 1.3, 3.1, 9.5, 11.0, S, m=True, note="upright slot burner"),
        box(1.82, 2.38, 1.42, 2.98, 11.0, 11.1, D, m=True, note="nozzle lip"),
        box(1.9, 2.3, 1.5, 2.9, 11.1, 11.22, T, m=True, note="thrust slot"),
    ]


# ---------------------------------------------------------------- SidePods (Side Pods)
def sd_strake():
    """Wedge: nothing at the front. A straked intake wedge rises from the door to the side engine."""
    strakes = [box(5.5, 5.58, y, y + 0.2, z, 2.7, S, m=True, note="strake") for y, z in ((0.4, -0.9), (0.9, 0.0), (1.4, 0.9))]
    return [
        box(3.65, 5.5, FLOOR, 0.1, -1.6, 2.7, D, m=True, note="pod floor"),
        wedge("rise_back", 3.65, 5.5, 0.1, 2.5, -1.6, 2.7, P, m=True, note="intake wedge rises to the side engine"),
        wedge("rise_back", 4.55, 5.5, 2.5, 3.1, 0.6, 2.7, P, m=True, note="shoulder kick"),
        box(3.8, 5.35, 0.3, 2.3, 2.7, 2.78, D, m=True, note="outlet face toward the side engine"),
    ] + strakes


def sd_round():
    """Analogue: a round torpedo pod hung off the tub on two pylons, bullet nose, open outlet."""
    return [
        box(3.65, 4.1, 0.6, 1.4, -3.0, -2.2, D, m=True, note="pylon"),
        box(3.65, 4.1, 0.6, 1.4, 0.0, 0.8, D, m=True, note="pylon"),
        cz(4.75, 1.0, -3.6, 1.6, 1.6, P, m=True, note="round pod"),
        ball(4.75, 1.0, -3.6, 1.6, P, m=True, note="bullet nose"),
        cz(4.75, 1.0, -1.4, -0.8, 1.68, S, m=True, note="band"),
        cz(4.75, 1.0, 1.6, 2.6, 1.3, D, m=True, note="outlet toward the side engine"),
    ]


def sd_blade():
    """Hypercar: no pod at all. A low thin blade stands off the tub on two struts and air runs behind it."""
    return [
        box(3.65, 5.3, 0.6, 0.8, -3.7, -3.3, D, m=True, note="strut"),
        box(3.65, 5.3, 0.6, 0.8, 1.3, 1.7, D, m=True, note="strut"),
        box(5.3, 5.5, 0.2, 1.4, -4.8, 2.7, S, m=True, note="floating blade: low, so the tub side shows"),
        wedge("rise_back", 5.3, 5.5, 1.4, 2.2, 0.6, 2.7, S, m=True, note="blade tip rises to the side engine"),
    ]


def sd_tray():
    """Track special: wide floor tray under the door, upright barge board behind the front arch, small low radiator pod."""
    return [
        box(3.65, 5.55, -0.55, -0.25, -5.1, -0.2, S, m=True, note="floor tray"),
        box(5.3, 5.5, -0.25, 1.9, -5.1, -3.2, P, m=True, note="barge board"),
        wedge("rise_front", 5.3, 5.5, -0.25, 1.9, -3.2, -1.4, P, m=True, note="barge board tail"),
        box(3.65, 4.7, -0.4, 1.1, 0.6, 2.7, P, m=True, note="radiator pod"),
        box(3.8, 4.55, -0.25, 0.95, 0.48, 0.6, D, m=True, note="radiator mesh"),
    ]


def sd_slab():
    """Longtail: smooth full-height fairing flush with the fenders, flush duct, long stripe."""
    return [
        box(3.65, 5.3, FLOOR, SILL, -5.1, 2.7, D, m=True, note="sill"),
        box(3.65, 5.4, SILL, 2.5, -5.1, 2.7, P, m=True, note="full fairing"),
        box(5.4, 5.47, 1.1, 1.5, -5.1, 2.7, S, m=True, note="stripe"),
        box(5.4, 5.47, 1.8, 2.3, 0.6, 2.4, D, m=True, note="flush duct"),
    ]


def sd_waist():
    """Concept: a low cheek intake behind the front arch that tapers in plan to nothing at the rear: a pinched waist."""
    return [
        wedge("plan_xneg_front", 3.65, 5.5, -0.2, 1.6, -5.1, 2.7, P, m=True, note="cheek tapers to the tub"),
        box(3.9, 5.3, 0.1, 1.3, -5.18, -5.1, D, m=True, note="cheek intake"),
        box(3.65, 4.3, 1.6, 1.67, -4.6, -1.0, D, m=True, note="cheek louvres"),
    ]


# ---------------------------------------------------------------- FrontBumper (Splitter)
def fb_chin():
    return [
        box(-5.2, 5.2, -0.7, -0.45, -11.9, -9.1, S, note="chin blade"),
        box(2.4, 2.6, -1.1, -0.7, -11.6, -9.4, D, m=True, note="strake"),
    ]


def fb_soft():
    return [
        box(-3.0, 3.0, -0.7, -0.45, -11.0, -9.1, D, note="mount plate"),
        box(-4.4, 4.4, -0.95, -0.6, -11.3, -10.9, P, note="soft lip"),
        wedge("rise_back", -4.4, 4.4, -0.95, -0.6, -11.7, -11.3, P, note="lip chamfer"),
        box(3.2, 4.2, -1.0, -0.45, -11.2, -10.4, P, m=True, note="corner pad"),
    ]


def fb_keel():
    return [
        box(-1.2, 1.2, -0.7, -0.45, -12.3, -9.2, S, note="keel plane"),
        box(3.2, 5.7, -0.9, -0.75, -11.4, -9.6, S, m=True, note="winglet"),
        box(1.2, 4.5, -0.75, -0.6, -10.6, -10.2, D, m=True, note="winglet spar"),
    ]


def fb_plough():
    return [
        box(-2.0, 2.0, -0.6, -0.45, -10.5, -9.1, D, note="mount plate"),
        box(-5.0, 5.0, -0.95, -0.45, -11.0, -10.4, D, note="air dam"),
        box(-5.4, 5.4, -1.1, -0.95, -11.9, -9.4, S, note="deep tray"),
        box(5.4, 5.7, -1.1, 0.7, -11.9, -11.65, P, m=True, note="end fence"),
        box(5.4, 5.7, -1.1, -0.45, -11.65, -10.4, P, m=True, note="end fence foot"),
    ]


def fb_long():
    return [
        box(-3.4, 3.4, -0.65, -0.45, -12.5, -9.1, P, note="long tongue"),
        box(1.5, 2.3, -1.0, -0.65, -12.0, -10.0, D, m=True, note="skid"),
    ]


def fb_bib():
    return [
        box(-2.0, 2.0, -1.3, -0.45, -11.0, -9.2, P, note="scoop bib"),
        box(-1.7, 1.7, -1.15, -0.6, -11.08, -11.0, D, note="scoop mouth"),
        box(2.0, 2.2, -1.36, -0.45, -11.4, -9.4, S, m=True, note="side skid"),
    ]


# ---------------------------------------------------------------- RearBumper (Diffuser)
def rb_strake():
    p = [wedge("hang_front", -3.2, 3.2, -1.1, -0.45, 8.6, 10.8, D, note="short diffuser ramp")]
    for x in (0.8, 2.4):
        p.append(box(x - 0.08, x + 0.08, -1.35, -0.45, 8.8, 11.2, S, m=True, note="strake"))
    return p


def rb_smooth():
    return [
        box(-4.4, 4.4, -0.7, -0.45, 8.8, 11.4, D, note="plate"),
        box(-4.6, 4.6, 0.1, 0.75, 11.05, 11.9, P, note="smooth valance"),
        wedge("hang_front", -4.6, 4.6, -0.4, 0.1, 11.05, 11.9, P, note="valance tucks under"),
        box(-0.6, 0.6, 0.25, 0.55, 11.9, 11.98, N, note="reverse lamp"),
    ]


def rb_venturi():
    return [
        wedge("hang_front", 0.6, 4.6, -1.3, -0.45, 8.6, 11.2, D, m=True, note="venturi tunnel: ends just past the tail"),
        box(-0.15, 0.15, -1.35, -0.45, 9.0, 11.3, S, note="centre fin"),
        box(4.6, 4.8, -1.35, -0.45, 8.8, 11.3, S, m=True, note="fence"),
        box(-0.15, 0.15, -1.0, -0.6, 11.3, 11.38, N, note="rain light on the fin end"),
    ]


def rb_bar():
    return [
        box(-3.0, 3.0, -0.6, -0.45, 8.8, 10.2, D, note="plate"),
        box(-4.4, 4.4, -0.8, -0.45, 9.6, 11.4, P, note="lower valance: closes the space between the tail and the bar"),
        box(3.6, 4.4, -1.0, -0.8, 9.0, 11.4, D, m=True, note="corner return skid"),
        box(-4.4, 4.4, -0.4, 0.45, 11.0, 11.4, P, note="crash bar: a square beam standing on the valance, tight behind the tail"),
        box(-3.4, 3.4, -0.1, 0.2, 11.4, 11.47, S, note="bar stripe"),
        box(3.6, 4.2, -0.15, 0.25, 11.4, 11.47, N, m=True, note="bar lamp"),
    ]


def rb_tray():
    return [
        box(-5.4, 5.4, -0.7, -0.45, 8.6, 12.4, P, note="long tail tray"),
        box(5.2, 5.4, -0.45, 1.1, 11.05, 12.4, S, m=True, note="end fence"),
        box(1.6, 1.75, -1.2, -0.7, 9.0, 12.2, D, m=True, note="strake"),
    ]


def rb_fin():
    return [
        box(-2.6, 2.6, -0.6, -0.45, 8.7, 10.2, D, note="plate"),
        box(-0.5, 0.5, -0.6, -0.45, 10.2, 12.2, S, note="keel top"),
        wedge("hang_front", -0.5, 0.5, -1.35, -0.6, 8.8, 12.2, S, note="keel fin"),
        box(2.3, 2.5, -1.2, -0.6, 8.9, 10.2, D, m=True, note="strake"),
    ]


# ---------------------------------------------------------------- RearSpoiler (Wing)
def sp_poster():
    return [
        box(2.9, 3.3, 2.85, 4.8, 9.5, 10.1, D, m=True, note="upright on the wing pad"),
        box(-5.2, 5.2, 4.8, 5.05, 9.5, 10.7, S, note="slab wing: short chord, above the turbine exhaust line"),
        box(5.2, 5.45, 4.4, 5.5, 9.45, 10.9, P, m=True, note="end plate"),
    ]


def sp_bridge():
    return [
        box(2.9, 3.4, 2.85, 4.85, 9.5, 10.4, P, m=True, note="broad support on the wing pad"),
        box(-3.8, 3.8, 4.85, 5.1, 9.5, 10.4, P, note="bridge wing: high enough to clear the turbine exhaust"),
        wedge("rise_back", -3.8, 3.8, 5.1, 5.3, 9.9, 10.4, P, note="lip"),
    ]


def sp_active():
    return [
        box(3.0, 3.2, 2.85, 5.7, 9.55, 10.05, D, m=True, note="swan neck on the wing pad"),
        part("block", [11.4, 0.2, 1.6], [0, 5.82, 10.4], S, [-8, 0, 0], False, "active blade"),
    ]


def sp_gt():
    return [
        box(2.95, 3.25, 2.85, 6.0, 9.5, 10.1, D, m=True, note="upright on the wing pad"),
        box(-5.4, 5.4, 6.0, 6.2, 9.7, 11.3, S, note="main plane"),
        part("block", [10.8, 0.15, 0.7], [0, 6.38, 11.35], S, [-25, 0, 0], False, "flap"),
        box(5.4, 5.6, 5.2, 6.55, 9.45, 11.8, P, m=True, note="end plate"),
    ]


def sp_fins():
    """Two outboard tail planes with a rising fin on each. The centre is open so the main turbine exhaust shows."""
    return [
        box(2.9, 3.2, 2.85, 3.85, 9.5, 10.9, S, m=True, note="fin root on the wing pad"),
        box(2.6, 5.4, 3.85, 4.05, 9.6, 12.5, P, m=True, note="outboard tail plane: nothing inboard of X 2.6"),
        wedge("rise_back", 2.9, 3.2, 4.05, 5.3, 10.0, 12.5, S, m=True, note="tail fin, rising to the rear"),
        box(5.4, 5.47, 3.85, 4.05, 10.0, 12.3, S, m=True, note="plane edge stripe"),
    ]


def sp_split():
    return [
        box(2.9, 3.3, 2.85, 3.9, 9.5, 10.1, D, m=True, note="upright on the wing pad"),
        box(2.4, 5.5, 3.9, 4.1, 9.5, 11.3, S, m=True, note="half wing: the centre is open over the turbine exhaust"),
        box(5.5, 5.75, 3.85, 5.0, 9.45, 11.5, P, m=True, note="upturned tip"),
        box(2.4, 2.6, 3.85, 4.4, 9.5, 11.3, P, m=True, note="inner fence"),
    ]


# ---------------------------------------------------------------- assembly
def mod(name, culture, fn):
    return {"name": name, "culture": culture, "note": (fn.__doc__ or "").strip(), "parts": fn()}


def build_spec():
    W, A, H, K, L, C = "Wedge", "Analogue", "Hypercar", "Track Special", "Longtail", "Concept"
    modules = {
        "Engine1": {
            "mono": mod("Gill Fenders", W, e1_mono), "twin": mod("Teardrop Fenders", A, e1_twin),
            "top": mod("Blade Fenders", H, e1_top), "stacks": mod("Arrow Fenders", K, e1_stacks),
            "long": mod("Box Fenders", L, e1_long), "cross": mod("Turbine Fenders", C, e1_cross)},
        "Engine2": {
            "box": mod("Gill Haunches", W, e2_box), "round": mod("Teardrop Haunches", A, e2_round),
            "twin": mod("Blade Haunches", H, e2_twin), "stub": mod("Arrow Haunches", K, e2_stub),
            "lance": mod("Box Haunches", L, e2_lance), "ear": mod("Turbine Pontoons", C, e2_ear)},
        "Stabilisers": {
            "vector": mod("Scoop Sills", W, st_vector), "lift": mod("Round Sills", A, st_lift),
            "blade": mod("Edge Sills", H, st_blade), "out": mod("Slim Sills", K, st_out),
            "trio": mod("Square Sills", L, st_trio), "tip": mod("Channel Sills", C, st_tip)},
        "Boost": {
            "quad": mod("Fishtail", W, b_quad), "twin": mod("Quad Cluster", A, b_twin),
            "tri": mod("Twin Outlets", H, b_tri), "slot": mod("Slot Burner", K, b_slot),
            "bore": mod("Twin Turbines", L, b_bore), "split": mod("Hex Burners", C, b_split)},
        "FrontBody": {
            "shovel": mod("Bull Nose", W, nose_shovel), "droplet": mod("Droplet Nose", A, nose_droplet),
            "keel": mod("Vented Nose", H, nose_keel), "blunt": mod("Spine Nose", K, nose_blunt),
            "lowline": mod("Valley Nose", L, nose_lowline), "visor": mod("Raised Nose", C, nose_visor)},
        "RearBody": {
            "slab": mod("Sloped Tail", W, deck_slab), "boat": mod("Boat Tail", A, deck_boat),
            "tunnel": mod("Louvred Tail", H, deck_tunnel), "frame": mod("Chopped Tail", K, deck_frame),
            "streamer": mod("Bar Tail", L, deck_streamer), "kamm": mod("Open Tail", C, deck_kamm)},
        "SidePods": {
            "strake": mod("Strake Intakes", W, sd_strake), "round": mod("Torpedo Pods", A, sd_round),
            "blade": mod("Floating Blades", H, sd_blade), "tray": mod("Barge Trays", K, sd_tray),
            "slab": mod("Full Fairings", L, sd_slab), "waist": mod("Waisted Cheeks", C, sd_waist)},
        "FrontBumper": {
            "chin": mod("Chin Blade", W, fb_chin), "soft": mod("Soft Lip", A, fb_soft),
            "keel": mod("Keel Planes", H, fb_keel), "plough": mod("Plough", K, fb_plough),
            "long": mod("Long Tongue", L, fb_long), "bib": mod("Scoop Bib", C, fb_bib)},
        "RearBumper": {
            "strake": mod("Strake Diffuser", W, rb_strake), "smooth": mod("Smooth Valance", A, rb_smooth),
            "venturi": mod("Venturi", H, rb_venturi), "bar": mod("Crash Bar", K, rb_bar),
            "tray": mod("Tail Tray", L, rb_tray), "fin": mod("Keel Fin", C, rb_fin)},
        "RearSpoiler": {
            "poster": mod("Drop-Tip Wing", W, sp_poster), "bridge": mod("Twin-Post Wing", A, sp_bridge),
            "active": mod("Race Wing", H, sp_active), "gt": mod("Spine Wing", K, sp_gt),
            "fins": mod("Bridge Wing", L, sp_fins), "split": mod("Pylon Wing", C, sp_split)},
    }
    order = ["Engine1", "Engine2", "Stabilisers", "Boost", "FrontBody", "RearBody", "SidePods",
             "FrontBumper", "RearBumper", "RearSpoiler"]

    def kit(name, culture, ids):
        return {"name": name, "culture": culture, "modules": dict(zip(order, ids))}

    kits = {
        "wedge": kit("Aurora", W, ["mono", "box", "vector", "quad", "shovel", "slab", "strake", "chin", "strake", "poster"]),
        "analogue": kit("Zephyr", A, ["twin", "round", "lift", "twin", "droplet", "boat", "round", "soft", "smooth", "bridge"]),
        "hyper": kit("Rosso", H, ["top", "twin", "blade", "tri", "keel", "tunnel", "blade", "keel", "venturi", "active"]),
        "track": kit("Stinger", K, ["stacks", "stub", "out", "slot", "blunt", "frame", "tray", "plough", "bar", "gt"]),
        "longtail": kit("Endura", L, ["long", "lance", "trio", "bore", "lowline", "streamer", "slab", "long", "tray", "fins"]),
        "concept": kit("Seraph", C, ["cross", "ear", "tip", "split", "visor", "kamm", "waist", "bib", "fin", "split"]),
    }

    def cockpit(name, culture, kit_id, fn):
        return {"name": name, "culture": culture, "kit": kit_id, "note": (fn.__doc__ or "").strip(), "parts": fn()}

    cockpits = {
        "wedge": cockpit("Aurora", W, "wedge", cockpit_wedge),
        "curve": cockpit("Zephyr", A, "analogue", cockpit_curve),
        "hyper": cockpit("Rosso", H, "hyper", cockpit_hyper),
        "spider": cockpit("Stinger", K, "track", cockpit_spider),
        "longtail": cockpit("Endura", L, "longtail", cockpit_longtail),
        "gull": cockpit("Seraph", C, "concept", cockpit_gull),
    }

    paint = {
        "wedge": {"primary": "#f26a12", "secondary": "#101114", "neon": "#fff2c0"},      # Aurora: orange over carbon
        "curve": {"primary": "#f2b705", "secondary": "#17181c", "neon": "#fff2c0"},      # Zephyr: yellow over black
        "hyper": {"primary": "#b3121a", "secondary": "#101114", "neon": "#ffe9b0"},      # Rosso: deep red over black
        "spider": {"primary": "#eeeeea", "secondary": "#2a2d33", "neon": "#ffffff"},     # Stinger: white over dark grey
        "longtail": {"primary": "#6b6253", "secondary": "#15161a", "neon": "#fff2c0"},   # Endura: bronze grey over black
        "gull": {"primary": "#0f6b5a", "secondary": "#cfe01e", "neon": "#ffe9b0"},       # Seraph: racing green with lime
    }
    swaps = {"wedge": "hyper", "curve": "track", "hyper": "longtail", "spider": "concept", "longtail": "wedge",
             "gull": "analogue"}
    builds = []
    for cid, c in cockpits.items():
        builds.append({"name": "%s, own kit" % c["name"], "cockpit": cid, "kit": c["kit"], "paint": paint[cid]})
    for cid, c in cockpits.items():
        builds.append({"name": "%s, %s kit" % (c["name"], kits[swaps[cid]]["name"]), "cockpit": cid,
                       "kit": swaps[cid], "paint": paint[cid]})
    builds += [
        {"name": "Mixed: Wedge street racer", "cockpit": "wedge", "kit": "wedge",
         "modules": {"Engine1": "stacks", "Stabilisers": "blade", "Boost": "bore", "RearSpoiler": "gt", "FrontBumper": "plough"},
         "paint": {"primary": "#f4f4f2", "secondary": "#d3222a", "neon": "#ff5a3c"}},
        {"name": "Mixed: Curve time attack", "cockpit": "curve", "kit": "analogue",
         "modules": {"Engine2": "twin", "Stabilisers": "out", "Boost": "slot", "FrontBody": "keel", "RearSpoiler": "active",
                     "SidePods": "blade", "FrontBumper": "keel"},
         "paint": {"primary": "#0f5a3c", "secondary": "#e2c76a", "neon": "#fff2c0"}},
        {"name": "Mixed: Gull grand tourer", "cockpit": "gull", "kit": "longtail",
         "modules": {"Engine1": "twin", "Engine2": "ear", "Stabilisers": "lift", "RearSpoiler": "bridge", "FrontBody": "droplet",
                     "FrontBumper": "soft", "Boost": "split"},
         "paint": {"primary": "#6d1f2c", "secondary": "#d9d2c0", "neon": "#ffd84a"}},
        {"name": "Mixed: Hyper club racer", "cockpit": "hyper", "kit": "wedge",
         "modules": {"Engine1": "cross", "Engine2": "lance", "Stabilisers": "trio", "Boost": "tri", "RearBody": "streamer",
                     "SidePods": "tray", "RearBumper": "venturi"},
         "paint": {"primary": "#2b2d33", "secondary": "#ff7a1a", "neon": "#7df9ff"}},
        {"name": "Mixed: Spider boulevard", "cockpit": "spider", "kit": "analogue",
         "modules": {"Engine1": "long", "Engine2": "stub", "Stabilisers": "vector", "FrontBody": "visor", "RearBody": "frame",
                     "SidePods": "waist", "RearSpoiler": "split", "RearBumper": "strake"},
         "paint": {"primary": "#e8c21a", "secondary": "#1c1d22", "neon": "#fff2c0"}},
    ]

    return {
        "id": "exotic",
        "displayName": "Exotic",
        "tagline": "Mid-engined supercars and hypercars as hover jets: cab forward, turbine behind the cabin, jets at every corner.",
        "standard": standard(),
        "cockpits": cockpits,
        "kits": kits,
        "modules": modules,
        "builds": builds,
    }


def report(spec):
    sys.path.insert(0, os.path.join(HERE, ".."))
    import vbspec  # noqa: E402  (read-only use of the shared validator)

    def n(parts):
        return len(vbspec.expand_parts(parts))

    print("part counts (mirrors expanded)")
    for cid, c in spec["cockpits"].items():
        print("  cockpit %-10s %3d" % (cid, n(c["parts"])))
    for s, mods in spec["modules"].items():
        print("  %-12s %s" % (s, "  ".join("%s=%d" % (k, n(v["parts"])) for k, v in mods.items())))
    for b in spec["builds"]:
        mods = vbspec.resolve_modules(spec, b)
        total = n(spec["cockpits"][b["cockpit"]]["parts"]) + sum(n(spec["modules"][s][m]["parts"]) for s, m in mods.items())
        print("  build %-28s %3d" % (b["name"], total))

    def table(label, items):
        ids = list(items.keys())
        ex = {k: vbspec.expand_parts(v["parts"]) for k, v in items.items()}
        tab = vbspec.distinct_table(ex)
        print("distinctness, free outline / whole: " + label)
        print("  %-10s" % "" + "".join("%11s" % i[:8] for i in ids))
        for a in ids:
            row = "  %-10s" % a[:10]
            for b in ids:
                if a == b:
                    row += "%11s" % "-"
                else:
                    free, raw = tab[(a, b)] if (a, b) in tab else tab[(b, a)]
                    row += "%11s" % ("%.2f/%.2f" % (free, raw))
            print(row)

    table("Cockpit", spec["cockpits"])
    for s, mods in spec["modules"].items():
        table(s, mods)


def main():
    spec = build_spec()
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=1)
        f.write("\n")
    print("wrote " + os.path.normpath(OUT))
    if "--report" in sys.argv:
        report(spec)


if __name__ == "__main__":
    main()
