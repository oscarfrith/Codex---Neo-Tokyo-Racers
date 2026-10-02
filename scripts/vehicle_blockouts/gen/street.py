"""Generator for the Street frame-class blockout spec (round 2). Design exploration only.

Run from the repo root:
  py -3 scripts/vehicle_blockouts/gen/street.py
  py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/street.json

Root space: +X right, +Y up, forward is -Z. Units are studs.

Layout of the class (see docs/design/vehicle-categories/street-frame.md):
  cockpit     = door section (Z -3.0..3.4) plus the greenhouse above the beltline. The solid roof and all
                centre glass stop at Z 4.9 (the tail bay). Behind that the roofline is carried by side
                buttresses (X 2.5..4.0) or an open frame above Y 4.4, so the tail engine is never roofed over
  FrontBody   = front clip: collar, cowl, arches, bonnet with a dark engine pad, nose
  RearBody    = rear clip: collar, two rear quarters, floor. The centre of the tail is an open engine bay
  Engine1     = bonnet engine, stands on the bonnet pad
  Engine2     = tail engine, lies in the open bay, nozzles through the rear panel
  Stabilisers = four arch jets hung from the arch inner walls
  Boost       = exhaust burners on the tail face, below the lamps
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "specs", "street.json"))

# ---------------------------------------------------------------- datums
Y_HOVER = -2.0     # hover plane
Y_SILL = 0.2       # sill line and body floor: bumpers, skirts and jets hang below it
Y_ARCH = 1.6       # arch top
Y_STRIPE0, Y_STRIPE1 = 2.35, 2.6   # belt stripe band
Y_BONNET = 2.6     # bonnet and bonnet engine pad
Y_BELT = 3.0       # beltline, cowl pad, deck pad
Y_BAY = 0.8        # tail engine pad (floor of the open bay)

ZF = -3.0          # front seam (cockpit to front clip)
ZR = 3.4           # rear seam (cockpit to rear clip)
FA0, FA1 = -8.2, -4.8   # front arch
RA0, RA1 = 4.9, 8.3     # rear arch
ZFA = (FA0 + FA1) / 2   # front arch centre
ZRA = (RA0 + RA1) / 2   # rear arch centre
Z_CHIN = -10.4     # chin datum: every nose puts a face here below Y 1.2
Z_TAIL = 10.4      # tail datum: every rear clip puts a face here

XC = 3.95          # half width of the cockpit door section and of every clip collar
XI = 2.7           # arch inner wall (stabiliser pad)
XBAY = 2.4         # half width of the tail engine bay and of the bonnet pad
XS = 4.4           # stock fender half width
GAP = 0.1          # each skin stops this far short of a seam


def r3(v):
    return round(float(v), 3)


# ---------------------------------------------------------------- part helpers
def P(shape, size, pos, ch="primary", rot=None, mirror=False, note=None):
    d = {"shape": shape, "size": [r3(v) for v in size], "pos": [r3(v) for v in pos]}
    if rot:
        d["rot"] = [r3(v) for v in rot]
    d["ch"] = ch
    if mirror:
        d["mirror"] = True
    if note:
        d["note"] = note
    return d


def box(x0, x1, y0, y1, z0, z1, ch="primary", mirror=False, note=None):
    """Block from its bounds."""
    return P("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, None, mirror, note)


def ramp(x0, x1, y0, y1, z0, z1, ch="primary", hi="back", mirror=False, note=None):
    """Wedge that fills the given bounds.
    hi='back'  floor at y0, thin edge at z0, tall face at z1 (a screen or a bonnet slope)
    hi='front' floor at y0, tall face at z0, thin edge at z1 (a tail slope)
    hi='under_back'  flat top at y1, deepest at z1 (a chin undercut)
    hi='under_front' flat top at y1, deepest at z0 (a tail undercut, a diffuser)
    """
    rot = {"back": None, "front": [0, 180, 0], "under_back": [0, 0, 180], "under_front": [180, 0, 0]}[hi]
    return P("wedge", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, mirror, note)


def ramp_x(x0, x1, y0, y1, z0, z1, ch="primary", thin="out", mirror=False, note=None):
    """Wedge sloping across the car, written for the +X side. thin='out': thin edge at x1. thin='in': thin edge at x0."""
    rot = [0, -90, 0] if thin == "out" else [0, 90, 0]
    return P("wedge", [z1 - z0, y1 - y0, x1 - x0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, mirror, note)


def taper(x0, x1, y0, y1, z0, z1, ch="primary", wide="back", mirror=False, note=None):
    """Plan-view triangle for the +X side: upright inboard face at x0, full width at the wide end, a point at the other."""
    rot = [0, 0, -90] if wide == "back" else [0, 180, 90]
    return P("wedge", [y1 - y0, x1 - x0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, mirror, note)


def cz(d, length, pos, ch="secondary", rot=None, mirror=False, note=None):
    return P("cyl_z", [d, d, length], pos, ch, rot, mirror, note)


def cy(d, height, pos, ch="secondary", rot=None, mirror=False, note=None):
    return P("cyl_y", [d, height, d], pos, ch, rot, mirror, note)


def cx(d, length, pos, ch="secondary", rot=None, mirror=False, note=None):
    return P("cyl_x", [length, d, d], pos, ch, rot, mirror, note)


def ball(d, pos, ch="secondary", mirror=False, note=None):
    return P("ball", [d, d, d], pos, ch, None, mirror, note)


# ---------------------------------------------------------------- frame standard
def mbox(x0, x1, y0, y1, z0, z1, mirror=False):
    b = {"min": [x0, y0, z0], "max": [x1, y1, z1]}
    if mirror:
        b["mirror"] = True
    return b


STANDARD = {
    "cockpitEnvelope": [
        mbox(-4.0, 4.0, Y_SILL, Y_BELT, ZF, ZR),           # door section
        mbox(-4.0, 4.0, Y_BELT, 6.4, -5.6, RA0),           # greenhouse: solid roof and centre glass stop at the tail bay
        mbox(2.5, 4.0, Y_BELT, 6.4, RA0, 9.0, True),       # buttress zones either side of the tail bay
        mbox(-2.5, 2.5, 4.4, 6.4, RA0, 9.0),               # open-frame zone high over the bay (bars only)
    ],
    "datums": {
        "hoverPlane": Y_HOVER, "sill": Y_SILL, "archTop": Y_ARCH,
        "stripeLow": Y_STRIPE0, "stripeHigh": Y_STRIPE1, "bonnetPad": Y_BONNET, "beltline": Y_BELT,
        "deckPad": Y_BELT, "tailBayPad": Y_BAY,
        "frontSeamZ": ZF, "rearSeamZ": ZR, "frontArchZ": [FA0, FA1], "rearArchZ": [RA0, RA1],
        "chinZ": Z_CHIN, "tailZ": Z_TAIL,
        "collarHalfWidth": XC, "archInnerWallX": XI, "tailBayHalfWidth": XBAY, "stockFenderX": XS,
        "roofEndZ": RA0, "buttressX": [2.5, 4.0], "openFrameMinY": 4.4, "bonnetEngineEndZ": -6.4, "archJetPlanX": [5.6, 6.1],
        "wingPadX": [2.9, 3.6], "wingPadZ": [9.3, 10.3], "boostHangerX": [2.7, 3.9], "boostHangerY": [0.3, 0.8],
    },
    "slots": {
        "FrontBody": {
            "label": "Front Clip",
            "envelope": [
                mbox(-4.0, 4.0, Y_SILL, Y_BELT, FA1, ZF),              # collar: cockpit section
                mbox(-5.6, 5.6, Y_BONNET, Y_BELT, -5.8, FA1),          # cowl
                mbox(-XI, XI, Y_SILL, Y_BONNET, FA0, FA1),             # subframe between the arches
                mbox(-5.6, 5.6, Y_ARCH, Y_BONNET, FA0, FA1),           # fenders over the arches
                mbox(-5.6, 5.6, Y_SILL, Y_BONNET, Z_CHIN, FA0),        # nose
                mbox(-5.6, 5.6, 1.2, Y_BONNET, -11.8, Z_CHIN),         # nose overhang above the bumper face
                mbox(2.6, 5.6, Y_BONNET, 3.9, -11.8, -5.8, True),      # fender crowns, lamp pods
                mbox(-2.6, 2.6, Y_BONNET, 3.9, -11.8, -9.6),           # nose top ahead of the bonnet engine
            ],
            "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -7],
        },
        "RearBody": {
            "label": "Rear Clip",
            "envelope": [
                mbox(-4.0, 4.0, Y_SILL, Y_BELT, ZR, RA0),              # collar
                mbox(-XI, XI, Y_SILL, 0.85, RA0, 8.6),                 # bay floor
                mbox(XBAY, 5.6, Y_ARCH, Y_BELT, RA0, RA1, True),       # quarters over the arches
                mbox(XBAY, XI, Y_SILL, Y_ARCH, RA0, RA1, True),        # bay wall = arch inner wall
                mbox(XBAY, 5.6, Y_SILL, Y_BELT, RA1, Z_TAIL, True),    # tail corners
                mbox(-5.6, 5.6, Y_SILL, 0.85, RA1, Z_TAIL),            # valance under the tail engine
                mbox(4.0, 5.6, Y_BELT, 3.9, ZR, 9.1, True),            # haunch tops outboard of the greenhouse
            ],
            "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 0, 7],
        },
        "Engine1": {
            "label": "Bonnet Engine",
            "envelope": mbox(-2.5, 2.5, Y_BONNET, 4.4, -9.6, -6.4),
            "anchor": {"to": "FrontBody", "face": "-y"}, "explode": [0, 5.5, -7],
        },
        "Engine2": {
            "label": "Tail Engine",
            "envelope": [
                mbox(-XBAY, XBAY, 0.85, Y_BELT, RA0, 11.2),            # in the bay and through the rear panel
                mbox(-XBAY, XBAY, Y_BELT, 4.3, RA0, 9.15),             # proud of the deck, ahead of the wing
            ],
            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 6.5, 7],
        },
        "Stabilisers": {
            "label": "Arch Jets",
            "envelope": [mbox(XI, 6.1, -1.7, Y_ARCH, FA0, FA1, True), mbox(XI, 6.1, -1.7, Y_ARCH, RA0, RA1, True)],
            "anchor": [{"to": "FrontBody", "face": "-x"}, {"to": "RearBody", "face": "-x"}], "explode": [5, -3.5, 0],
        },
        "Boost": {
            "label": "Exhaust Burner",
            "envelope": [
                mbox(-5.6, 5.6, Y_SILL, 0.85, 10.5, 12.8),             # low band under the tail engine nozzle
                mbox(2.6, 5.6, 0.85, Y_BELT, 10.5, 12.8, True),        # tail corners
                mbox(2.6, 5.6, Y_BELT, 6.0, 11.7, 12.8, True),         # tall stacks behind the wing
            ],
            "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, 0, 15],
        },
        "SidePods": {
            "label": "Side Kit",
            "envelope": [
                mbox(4.0, 5.8, -1.3, Y_BELT, FA1, RA0, True),          # flank, arch to arch
                mbox(XI, 5.8, -1.3, Y_SILL, RA1, 8.6, True),           # rear mud-flap pocket
            ],
            "anchor": {"to": "cockpit", "face": "-x"}, "explode": [6, 0, 0],
        },
        "FrontBumper": {
            "label": "Front Lip",
            "envelope": [
                mbox(-5.8, 5.8, -1.3, Y_SILL, -12.2, FA0),             # under the nose
                mbox(-5.8, 5.8, Y_SILL, 1.2, -12.2, Z_CHIN),           # face layer ahead of the chin
            ],
            "anchor": {"to": "FrontBody", "face": "+y"}, "explode": [0, -3, -11],
        },
        "RearBumper": {
            "label": "Diffuser",
            "envelope": mbox(-5.6, 5.6, -1.3, Y_SILL, 8.6, 12.0),
            "anchor": {"to": "RearBody", "face": "+y"}, "explode": [0, -4, 9],
        },
        "RearSpoiler": {
            "label": "Wing",
            "envelope": mbox(-5.8, 5.8, Y_BELT, 7.4, 9.2, 11.6),
            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 4.5, 13],
        },
    },
}


# ---------------------------------------------------------------- cockpits
def chassis():
    """The part of every cockpit that never changes: door section, seam plates, seats, driver."""
    return [
        box(-3.6, 3.6, 0.3, 2.9, ZF, ZF + GAP, "detail", note="front seam plate: dark linkage in the shadow gap"),
        box(-3.6, 3.6, 0.3, 2.9, ZR - GAP, ZR, "detail", note="rear seam plate"),
        box(-XC, XC, Y_SILL, Y_STRIPE0, ZF + GAP, ZR - GAP, "primary", note="doors; side kit butts this face at X 4.0"),
        box(-XC, XC, Y_STRIPE0, Y_STRIPE1, ZF + GAP, ZR - GAP, "secondary", note="belt stripe datum"),
        box(-XC, XC, Y_STRIPE1, Y_BELT, ZF + GAP, ZR - GAP, "primary", note="shoulder up to the beltline"),
        box(0.9, 2.3, Y_BELT, 3.8, 1.0, 1.25, "detail", mirror=True, note="seat backs"),
        box(1.05, 2.25, Y_BELT, 3.3, 0.2, 0.9, "driver", note="seated avatar: shoulders"),
        ball(1.05, [1.65, 3.55, 0.5], "driver", note="avatar head"),
    ]


def cab_touge():
    """90s coupe: low bubble, raked screen, short roof, rear glass that ends at the boot deck."""
    hw, top = 3.0, 4.6
    return chassis() + [
        ramp(-hw, hw, Y_BELT, top, -4.6, -1.5, "glass", "back", note="raked screen, base on the cowl pad"),
        ramp(hw, hw + 0.25, Y_BELT, top, -4.6, -1.5, "primary", "back", mirror=True, note="A-pillars"),
        box(-hw - 0.1, hw + 0.1, Y_BELT, top - 0.3, -1.5, 1.6, "glass", note="door glass"),
        box(-hw - 0.25, hw + 0.25, top - 0.3, top, -1.5, 1.6, "primary", note="short roof"),
        box(-hw + 0.8, hw - 0.8, top, top + 0.2, -1.0, 1.2, "primary", note="roof crown: the bubble"),
        box(hw + 0.1, hw + 0.25, Y_BELT, top - 0.3, 1.2, 1.6, "primary", mirror=True, note="B-pillar"),
        ramp(-hw + 0.3, hw - 0.3, Y_BELT, top, 1.6, RA0 - 0.05, "glass", "front", note="rear glass: stops at the tail bay"),
        ramp(hw - 0.3, hw + 0.25, Y_BELT, top, 1.6, RA0 - 0.05, "primary", "front", mirror=True, note="C-pillars"),
        ramp(2.6, 3.25, Y_BELT, 3.5, RA0, 7.6, "primary", "front", mirror=True, note="low sail fairings along the boot deck; the bay stays open between them"),
        box(3.3, 3.9, Y_BELT, 3.35, -2.4, -1.9, "primary", mirror=True, note="door mirrors"),
    ]


def cab_pocket():
    """Hot hatch: tall, short, cab-forward two-box. Roof stops at Z 3.0; the hatch line runs down two buttresses."""
    hw, top = 3.6, 5.9
    zr = 3.0   # solid roof ends here
    return chassis() + [
        ramp(-hw, hw, Y_BELT, top, -4.8, -3.2, "glass", "back", note="steep cab-forward screen on the cowl pad; 1.6 clear of the bonnet engine"),
        ramp(hw, hw + 0.25, Y_BELT, top, -4.8, -3.2, "primary", "back", mirror=True, note="A-pillars"),
        box(-hw - 0.1, hw + 0.1, Y_BELT, top - 0.35, -3.2, zr - 1.2, "glass", note="tall side glass"),
        box(hw + 0.1, hw + 0.25, Y_BELT, top - 0.35, 0.0, 0.4, "detail", mirror=True, note="B-pillar"),
        box(-hw - 0.25, hw + 0.25, Y_BELT, top - 0.35, zr - 1.2, zr, "primary", note="thick C-pillar: the hot-hatch signature"),
        box(-hw - 0.25, hw + 0.25, top - 0.35, top, -3.2, zr, "primary", note="short tall roof"),
        ramp(-2.6, 2.6, Y_BELT, top - 0.35, zr, RA0 - 0.05, "glass", "front", note="steep hatch glass, ends at the tail bay"),
        ramp(2.6, hw + 0.25, Y_BELT, top - 0.35, zr, 6.0, "primary", "front", mirror=True, note="buttress: carries the hatch line back beside the open bay"),
        box(-hw, hw, top - 0.3, top, zr, zr + 0.9, "secondary", note="roof visor spoiler (cockpit owns the roofline)"),
    ]


def cab_syndicate():
    """Sports saloon: three-box, four doors, formal C-pillar and a notch rear screen. The boot is the open bay."""
    hw, top = 3.3, 5.25
    return chassis() + [
        ramp(-hw, hw, Y_BELT, top, -4.2, -2.0, "glass", "back", note="screen"),
        ramp(hw, hw + 0.25, Y_BELT, top, -4.2, -2.0, "primary", "back", mirror=True, note="A-pillars"),
        box(-hw - 0.1, hw + 0.1, Y_BELT, top - 0.3, -2.0, 2.4, "glass", note="front and rear door glass"),
        box(hw + 0.1, hw + 0.25, Y_BELT, top - 0.3, 0.0, 0.4, "detail", mirror=True, note="B-pillar"),
        box(-hw - 0.25, hw + 0.25, Y_BELT, top - 0.3, 2.4, 3.4, "primary", note="formal C-pillar"),
        box(-hw - 0.25, hw + 0.25, top - 0.3, top, -2.0, 3.4, "primary", note="flat roof"),
        ramp(-hw, hw, Y_BELT, top, 3.4, 4.7, "glass", "front", note="notch rear screen: three-box outline"),
        ramp(hw, hw + 0.25, Y_BELT, top, 3.4, 4.7, "primary", "front", mirror=True),
        box(3.4, 3.9, Y_BELT, 3.4, -2.4, -1.9, "primary", mirror=True, note="door mirrors"),
    ]


def cab_kei():
    """Roadster (id kept as kei): full-width framed screen, open cabin, targa hoop, two long buttresses."""
    hw = 3.6
    return chassis() + [
        ramp(-hw, hw, Y_BELT, 4.6, -3.6, -1.8, "glass", "back", note="full-width screen, 7.2 wide"),
        ramp(hw, hw + 0.25, Y_BELT, 4.6, -3.6, -1.8, "primary", "back", mirror=True, note="screen posts"),
        box(-hw - 0.25, hw + 0.25, 4.45, 4.7, -2.0, -1.7, "primary", note="screen header"),
        ramp(hw - 0.05, hw + 0.1, Y_BELT, 4.4, -1.7, 0.3, "glass", "front", mirror=True, note="short side glass"),
        box(2.7, hw + 0.25, Y_BELT, 4.75, 1.4, 2.3, "primary", mirror=True, note="targa hoop posts"),
        box(-2.7, 2.7, 4.35, 4.75, 1.4, 2.3, "primary", note="targa hoop bar, full width"),
        box(-2.7, 2.7, Y_BELT, 4.35, 1.75, 1.95, "glass", note="wind blocker in the hoop"),
        ramp(2.7, hw + 0.25, Y_BELT, 4.75, 2.3, 8.9, "primary", "front", mirror=True, note="buttress fairings: the tail bay stays open between them"),
        box(-2.7, 2.7, Y_BELT, 3.3, 2.3, RA0 - 0.05, "detail", note="tonneau ahead of the bay"),
        box(3.4, 3.9, Y_BELT, 3.35, -2.9, -2.4, "primary", mirror=True, note="door mirrors"),
    ]


def cab_estate():
    """Estate: set-back screen and a long roofline to the tail. Over the tail bay the roof is an open frame."""
    hw, top = 3.15, 5.05
    return chassis() + [
        ramp(-hw, hw, Y_BELT, top, -3.0, -0.5, "glass", "back", note="set-back screen: long bonnet look"),
        ramp(hw, hw + 0.25, Y_BELT, top, -3.0, -0.5, "primary", "back", mirror=True, note="A-pillars"),
        box(-hw - 0.1, hw + 0.1, Y_BELT, top - 0.3, -0.5, 4.45, "glass", note="door glass"),
        box(hw + 0.1, hw + 0.25, Y_BELT, top - 0.3, 1.6, 1.9, "detail", mirror=True, note="B-pillar"),
        box(2.6, hw + 0.25, Y_BELT, top - 0.3, 4.45, RA0 - 0.05, "primary", mirror=True, note="C-pillar"),
        box(-2.6, 2.6, Y_BELT, top - 0.3, 4.6, 4.8, "glass", note="cabin rear glass: the engine sits behind it"),
        box(-hw - 0.25, hw + 0.25, top - 0.3, top, -0.5, RA0 - 0.05, "primary", note="solid roof, stops at the tail bay"),
        box(2.6, hw + 0.25, top - 0.3, top, RA0 - 0.05, 8.9, "primary", mirror=True, note="roof side rails: carry the long roofline to the tail"),
        box(2.95, hw + 0.1, Y_BELT, top - 0.3, RA0, 8.3, "glass", mirror=True, note="load-bay side glass"),
        box(2.6, hw + 0.25, Y_BELT, top - 0.3, 8.3, 8.9, "primary", mirror=True, note="D-pillars"),
        box(-2.6, 2.6, top - 0.3, top, 8.5, 8.9, "primary", note="rear hoop: open tailgate under it"),
        box(2.45, 2.7, top, top + 0.3, 0.2, 8.2, "secondary", mirror=True, note="roof rails"),
        box(-2.45, 2.45, top + 0.15, top + 0.3, 2.4, 2.7, "detail", note="rail cross bar"),
        box(-2.45, 2.45, top + 0.15, top + 0.3, 6.4, 6.7, "detail", note="rail cross bar over the open bay"),
    ]


COCKPITS = {
    "touge": {"name": "Touge", "culture": "Touge", "kit": "touge", "note": "90s coupe", "parts": cab_touge()},
    "pocket": {"name": "Pocket", "culture": "Kanjo", "kit": "kanjo", "note": "hot hatch", "parts": cab_pocket()},
    "syndicate": {"name": "Syndicate", "culture": "Drift", "kit": "drift", "note": "sports saloon", "parts": cab_syndicate()},
    "kei": {"name": "Roadster", "culture": "Time Attack", "kit": "attack", "note": "open targa roadster (was Kei; the shared body cannot read as tiny)", "parts": cab_kei()},
    "estate": {"name": "Estate", "culture": "Rally", "kit": "rally", "note": "wagon with an open-frame load bay", "parts": cab_estate()},
}


# ---------------------------------------------------------------- FrontBody
def front_core(xf):
    """Hardpoints every front clip must carry. xf is the fender half width over the arch."""
    return [
        box(-3.6, 3.6, 0.3, 2.9, ZF - GAP, ZF, "detail", note="seam plate: dark linkage in the shadow gap"),
        box(-XC, XC, Y_SILL, Y_STRIPE0, FA1 + 0.05, ZF - GAP, "primary", note="collar: same section as the cockpit doors"),
        box(-XC, XC, Y_STRIPE0, Y_STRIPE1, FA1 + 0.05, ZF - GAP, "secondary", note="belt stripe carried across the seam"),
        box(-XC, XC, Y_BONNET, Y_BELT, FA1, ZF - GAP, "primary", note="cowl pad, flat at Y 3.0: cab-forward screens land here"),
        ramp(-XC, XC, Y_BONNET, Y_BELT, -5.8, FA1, "primary", "back", note="cowl ramp from bonnet to beltline"),
        box(-XI, XI, Y_SILL, Y_ARCH, FA0, FA1, "detail", note="subframe: arch inner wall at X 2.7 is the stabiliser pad"),
        box(-XBAY, XBAY, Y_ARCH, Y_BONNET, -9.55, -5.8, "detail", note="bonnet engine pad, flat at Y 2.6"),
        box(-XBAY, XBAY, Y_ARCH, Y_BONNET, -5.8, FA1, "primary", note="scuttle"),
        box(XBAY, xf, Y_ARCH, Y_BONNET, FA0, FA1, "primary", mirror=True, note="fender over the arch"),
    ]


def fb_popup():
    """Touge: low wedge nose at stock width, narrow beak over the bumper, pop-up lamps."""
    xb = 3.4   # beak half width
    return front_core(XS) + [
        box(-XS, XS, Y_SILL, 1.3, Z_CHIN + 0.05, FA0, "primary", note="lower nose; chin at the datum"),
        box(-XS, XS, 1.3, Y_ARCH, -9.6, FA0, "primary"),
        box(XBAY, XS, Y_ARCH, Y_BONNET, -9.6, FA0, "primary", mirror=True, note="bonnet beside the pad"),
        ramp(-xb, xb, 1.3, Y_BONNET, -11.75, -9.6, "primary", "back", note="long wedge beak over the bumper face"),
        ramp(xb, XS, 1.3, Y_BONNET, -10.35, -9.6, "primary", "back", mirror=True, note="short corner slope beside the beak"),
        box(-2.8, 2.8, 1.3, 1.46, -11.77, -11.5, "detail", note="nose slot"),
        box(2.75, 4.25, Y_BONNET, 3.35, -9.5, -8.3, "primary", mirror=True, note="pop-up lamp pods, raised"),
        box(2.9, 4.1, 2.7, 3.25, -9.58, -9.5, "neon", mirror=True, note="lamp faces"),
        box(XS, XS + 0.05, Y_STRIPE0, Y_STRIPE1, -9.6, FA1, "secondary", mirror=True, note="belt stripe on the fender"),
    ]


def fb_shorty():
    """Kanjo: narrow bobbed nose flush with the doors, bumper skin removed, crash beam and intercooler on show."""
    xn = XC
    return front_core(xn) + [
        box(-xn, xn, 1.25, Y_ARCH, -9.85, FA0, "primary", note="upper nose"),
        box(XBAY, xn, Y_ARCH, Y_BONNET, -9.55, FA0, "primary", mirror=True, note="bonnet beside the pad"),
        box(-xn, xn, Y_ARCH, Y_BONNET, -9.85, -9.55, "primary", note="bonnet leading edge"),
        box(-2.2, 2.2, 1.45, 2.3, -9.9, -9.85, "detail", note="open grille"),
        box(2.4, 3.8, 1.6, 2.3, -9.92, -9.85, "neon", mirror=True, note="square lamps"),
        box(-3.6, 3.6, Y_SILL, 1.25, -9.5, FA0, "detail", note="radiator support, bare"),
        box(-2.8, 2.8, 0.35, 1.1, -9.8, -9.5, "secondary", note="intercooler core"),
        box(2.0, 2.5, 0.35, 0.95, Z_CHIN + 0.05, -9.5, "detail", mirror=True, note="crash rails"),
        box(-3.9, 3.9, 0.35, 0.95, Z_CHIN + 0.05, -10.0, "detail", note="crash beam at the chin datum"),
        box(xn, 4.6, Y_ARCH, 2.0, FA0, FA1, "primary", mirror=True, note="bolt-on arch lip out to X 4.6: narrows the step to wide side kits"),
        ramp_x(xn, 4.6, 2.0, 2.3, FA0, FA1, "primary", "out", mirror=True, note="arch lip shoulder"),
    ]


def fb_wide():
    """Drift: widest nose. Tall box flares over the arches, long square overhang, big mouth."""
    xw = 5.6
    return front_core(xw) + [
        box(4.05, xw, Y_BONNET, 3.3, -9.6, -5.85, "primary", mirror=True, note="tall box flare"),
        ramp(4.05, xw, Y_BONNET, 3.3, -10.35, -9.6, "primary", "back", mirror=True, note="flare lead-in"),
        box(4.05, xw, Y_BONNET, 2.95, -5.85, FA1, "primary", mirror=True, note="flare tail on the cowl"),
        box(4.4, 5.4, 3.3, 3.36, -7.3, -6.9, "detail", mirror=True, note="flare vent"),
        box(4.4, 5.4, 3.3, 3.36, -6.6, -6.2, "detail", mirror=True, note="flare vent"),
        box(-xw, xw, Y_SILL, 1.3, Z_CHIN + 0.05, FA0, "primary", note="lower nose"),
        box(XBAY, xw, Y_ARCH, Y_BONNET, -9.6, FA0, "primary", mirror=True),
        box(-xw, xw, 1.3, Y_ARCH, -9.6, FA0, "primary"),
        box(-5.4, 5.4, 1.3, 2.0, -11.6, -9.6, "primary", note="long square overhang"),
        ramp(-5.4, 5.4, 2.0, Y_BONNET, -11.6, -9.6, "primary", "back"),
        box(-2.8, 2.8, 1.4, 1.9, -11.66, -11.6, "detail", note="mouth"),
        box(3.1, 5.2, 1.45, 1.9, -11.67, -11.6, "neon", mirror=True, note="quad lamps"),
    ]


def fb_arrow():
    """Time Attack: needle nose between two pontoon fenders. Cut-away corners, louvred fender towers, bug-eye lamps."""
    xw = 5.4
    slats = [box(3.2, 5.2, 3.6, 3.68, z, z + 0.4, "detail", mirror=True, note="tower louvre") for z in (-7.6, -6.7)]
    return front_core(xw) + slats + [
        box(2.9, xw, Y_BONNET, 3.6, -8.2, -5.85, "primary", mirror=True, note="fender tower over the arch"),
        ramp(2.9, xw, Y_BONNET, 3.6, -9.4, -8.2, "primary", "back", mirror=True, note="tower lead-in"),
        box(4.0, xw, Y_BONNET, 2.95, -5.85, FA1, "primary", mirror=True, note="tower tail on the cowl"),
        box(-XBAY, XBAY, Y_SILL, Y_ARCH, Z_CHIN + 0.05, FA0, "primary", note="nose spine; chin at the datum"),
        box(-XBAY, XBAY, 1.2, Y_ARCH, -11.75, Z_CHIN + 0.05, "primary", note="needle tip"),
        ramp(-XBAY, XBAY, Y_ARCH, Y_BONNET, -11.75, -9.6, "primary", "back", note="needle slope"),
        taper(XBAY, xw, Y_SILL, 1.2, Z_CHIN + 0.05, FA0, "primary", "back", mirror=True, note="low shoulder, tapered in plan"),
        taper(XBAY, xw, 1.2, Y_BONNET, -9.7, FA0, "primary", "back", mirror=True, note="pontoon front, cut back hard"),
        box(-1.6, 1.6, 1.25, 1.55, -11.8, -11.75, "detail", note="nose intake"),
        cz(0.95, 1.1, [1.75, 3.1, -10.6], "primary", mirror=True, note="bug-eye lamp pods on the needle"),
        cz(0.7, 0.2, [1.75, 3.1, -11.2], "neon", mirror=True, note="lamp faces"),
    ]


def fb_stage():
    """Rally: tall square nose, raised box fenders, lamp pod, bull bar."""
    xw = 4.8
    lamps = []
    for x in (0.65, 1.85):
        lamps.append(cz(0.95, 0.7, [x, 3.35, -10.15], "detail", mirror=True, note="spot lamp"))
        lamps.append(cz(0.75, 0.15, [x, 3.35, -10.55], "neon", mirror=True, note="spot lamp face"))
    return front_core(xw) + lamps + [
        box(2.8, xw, Y_BONNET, 3.25, Z_CHIN + 0.05, -5.9, "primary", mirror=True, note="raised box fender, full length"),
        box(2.8, xw, Y_BONNET, 2.95, -5.9, FA1, "primary", mirror=True, note="fender tail on the cowl"),
        box(xw, xw + 0.15, Y_ARCH, 2.0, FA0, FA1, "detail", mirror=True, note="arch trim"),
        box(-xw, xw, Y_SILL, Y_ARCH, Z_CHIN + 0.05, FA0, "primary", note="tall square nose"),
        box(XBAY, xw, Y_ARCH, Y_BONNET, Z_CHIN + 0.05, FA0, "primary", mirror=True),
        box(-XBAY, XBAY, Y_ARCH, Y_BONNET, Z_CHIN + 0.05, -9.55, "primary"),
        box(-2.3, 2.3, 1.5, 2.3, Z_CHIN, Z_CHIN + 0.05, "detail", note="grille"),
        box(2.7, 4.5, 1.6, 2.3, Z_CHIN - 0.02, Z_CHIN + 0.05, "neon", mirror=True, note="lamps"),
        box(-2.5, 2.5, Y_BONNET, 2.9, -10.3, -9.75, "detail", note="lamp bar on the nose top"),
        cx(0.3, 7.6, [0, 1.9, -11.3], "detail", note="bull bar tube"),
        box(3.3, 3.6, 1.3, 2.05, -11.45, -11.15, "detail", mirror=True, note="bull bar upright"),
        box(3.3, 3.6, 1.5, 1.9, -11.15, Z_CHIN, "detail", mirror=True, note="bull bar stay"),
    ]


# ---------------------------------------------------------------- RearBody
def rear_core(xq):
    """Hardpoints every rear clip must carry. xq is the quarter half width over the arch."""
    return [
        box(-3.6, 3.6, 0.3, 2.9, ZR, ZR + GAP, "detail", note="seam plate: dark linkage in the shadow gap"),
        box(-XC, XC, Y_SILL, Y_STRIPE0, ZR + GAP, RA0 - 0.05, "primary", note="collar: same section as the cockpit doors"),
        box(-XC, XC, Y_STRIPE0, Y_STRIPE1, ZR + GAP, RA0 - 0.05, "secondary", note="belt stripe carried across the seam"),
        box(-XC, XC, Y_STRIPE1, Y_BELT, ZR + GAP, RA0 - 0.05, "primary", note="deck pad at the beltline: the greenhouse lands here"),
        box(-XI, XI, Y_SILL, Y_BAY, RA0, 8.6, "detail", note="bay floor: tail engine pad, flat at Y 0.8"),
        box(XBAY, XI, Y_BAY, Y_ARCH, RA0, RA1, "detail", mirror=True, note="bay wall; its outer face is the stabiliser pad"),
        box(XBAY, xq, Y_ARCH, Y_BELT, RA0, RA1, "primary", mirror=True, note="rear quarter over the arch, deck at Y 3.0"),
    ]


def rb_clean():
    """Touge: plain coupe tail at stock width, drawn in towards the back, long lamp bars."""
    xt = 3.8   # half width at the tail face
    return rear_core(XS) + [
        box(XBAY, xt, Y_SILL, Y_BELT, RA1, Z_TAIL - 0.05, "primary", mirror=True, note="tail corner; wing pad on top"),
        taper(xt, XS, Y_SILL, Y_BELT, RA1, Z_TAIL - 0.05, "primary", "front", mirror=True, note="boat-tail flank, tapered in plan"),
        box(-XBAY, XBAY, Y_SILL, Y_BAY, 8.6, Z_TAIL - 0.05, "primary", note="valance under the tail engine"),
        box(2.6, 3.7, 2.05, 2.6, Z_TAIL - 0.05, Z_TAIL, "neon", mirror=True, note="lamp bars"),
        box(XS, XS + 0.05, Y_STRIPE0, Y_STRIPE1, RA0, RA1, "secondary", mirror=True, note="belt stripe"),
    ]


def rb_bob():
    """Kanjo: narrow bobbed tail flush with the doors, undercut corners, bare crash beam."""
    xn = XC
    return rear_core(xn) + [
        box(XBAY, xn, 1.3, Y_BELT, RA1, 9.0, "primary", mirror=True, note="short tail corner"),
        ramp(XBAY, xn, 1.3, Y_BELT, 9.0, Z_TAIL - 0.05, "primary", "under_front", mirror=True, note="undercut: deck stays flat for the wing"),
        box(2.6, 3.8, 2.6, 2.95, Z_TAIL - 0.05, Z_TAIL, "neon", mirror=True, note="slim lamps under the deck edge"),
        box(2.8, 3.4, 0.3, 0.9, RA1, Z_TAIL - 0.45, "detail", mirror=True, note="crash rails"),
        box(-3.9, 3.9, 0.3, 0.9, Z_TAIL - 0.45, Z_TAIL - 0.05, "detail", note="bare crash beam at the tail datum"),
        box(xn, 4.6, Y_ARCH, 2.0, RA0, RA1, "primary", mirror=True, note="bolt-on arch lip out to X 4.6"),
        ramp_x(xn, 4.6, 2.0, 2.3, RA0, RA1, "primary", "out", mirror=True, note="arch lip shoulder"),
    ]


def rb_wide():
    """Drift: widest tail. Tall box haunches, square corners, block lamps."""
    xw = 5.6
    return rear_core(xw) + [
        box(4.05, xw, Y_BELT, 3.6, 4.4, 9.05, "primary", mirror=True, note="tall box haunch"),
        ramp(4.05, xw, Y_BELT, 3.6, 3.5, 4.4, "primary", "back", mirror=True, note="haunch lead-in"),
        box(4.4, 5.4, 3.6, 3.66, 6.0, 6.4, "detail", mirror=True, note="haunch vent"),
        box(4.4, 5.4, 3.6, 3.66, 6.8, 7.2, "detail", mirror=True, note="haunch vent"),
        box(XBAY, xw, Y_SILL, Y_BELT, RA1, Z_TAIL - 0.05, "primary", mirror=True, note="wide tail corner; wing pad on top"),
        box(-XBAY, XBAY, Y_SILL, Y_BAY, 8.6, Z_TAIL - 0.05, "primary", note="valance under the tail engine"),
        box(2.7, 5.3, 1.75, 2.7, Z_TAIL - 0.05, Z_TAIL, "neon", mirror=True, note="block lamps"),
        box(2.7, 5.3, 0.4, 1.3, Z_TAIL - 0.05, Z_TAIL, "detail", mirror=True, note="corner vent"),
    ]


def rb_tunnel():
    """Time Attack: tunnel tail. Inner corner, outer end plate with a fin, and an open channel right through between them."""
    xw = 5.4
    return rear_core(xw) + [
        box(XBAY, 3.65, Y_SILL, Y_BELT, RA1, Z_TAIL - 0.05, "primary", mirror=True, note="inner tail corner; wing pad on top"),
        box(5.1, xw, Y_SILL, Y_BELT, RA1, Z_TAIL - 0.05, "primary", mirror=True, note="end plate"),
        ramp(5.1, xw, Y_BELT, 3.88, 5.2, 9.05, "primary", "back", mirror=True, note="tall end plate fin"),
        box(3.65, 5.1, 2.3, 2.6, 9.5, 10.0, "detail", mirror=True, note="tie bar across the open channel"),
        box(5.15, 5.35, 0.6, 2.6, Z_TAIL - 0.05, Z_TAIL, "neon", mirror=True, note="upright strip lamps"),
        box(2.6, 3.5, 2.0, 2.6, Z_TAIL - 0.05, Z_TAIL, "neon", mirror=True, note="inner lamps"),
        box(-XBAY, XBAY, Y_SILL, Y_BAY, 8.6, Z_TAIL - 0.05, "detail", note="valance under the tail engine"),
    ]


def rb_stage():
    """Rally: square tail, stacked lamps, dark lower corners and arch trims."""
    xw = 4.8
    return rear_core(xw) + [
        box(4.05, xw, Y_BELT, 3.25, 3.5, 9.05, "primary", mirror=True, note="raised box quarter, matches the front fenders"),
        box(xw, xw + 0.15, Y_ARCH, 2.0, RA0, RA1, "detail", mirror=True, note="arch trim"),
        box(XBAY, xw, 1.1, Y_BELT, RA1, Z_TAIL - 0.05, "primary", mirror=True, note="tail corner; wing pad on top"),
        box(XBAY, xw + 0.1, Y_SILL, 1.1, RA1, Z_TAIL - 0.05, "detail", mirror=True, note="dark lower corner"),
        box(-XBAY, XBAY, Y_SILL, Y_BAY, 8.6, Z_TAIL - 0.05, "detail", note="valance under the tail engine"),
        box(3.6, 4.6, 2.2, 2.8, Z_TAIL - 0.05, Z_TAIL, "neon", mirror=True, note="upper lamp"),
        box(3.6, 4.6, 1.4, 2.0, Z_TAIL - 0.05, Z_TAIL, "neon", mirror=True, note="lower lamp"),
        box(xw, xw + 0.05, Y_STRIPE0, Y_STRIPE1, RA1, Z_TAIL - 0.05, "secondary", mirror=True, note="belt stripe"),
    ]


# ---------------------------------------------------------------- Engine1 (bonnet engine)
PAD1 = Y_BONNET + 0.03   # lowest face of a bonnet engine
Z_E1 = -6.45             # no bonnet engine part comes behind this: leaves the cab-forward screen clear


def stack(x, y, z, dia, length, lean, tip, ch="detail", tip_len=0.22, mirror=False, note=None):
    """Upright pipe leaning outboard by `lean` degrees (written for +X), with a glowing tip on top.
    The tip faces up and out, so it shows from the front three-quarter, the side and above."""
    a = math.radians(lean)
    ax, ay = math.sin(a), math.cos(a)
    k = length / 2 + tip_len / 2
    return [
        cy(dia, length, [x, y, z], ch, rot=[0, 0, -lean], mirror=mirror, note=note),
        cy(tip, tip_len, [x + k * ax, y + k * ay, z], "thrust", rot=[0, 0, -lean], mirror=mirror, note="jet, up and out over the fender"),
    ]


def e1_twin_cam():
    """Touge: two slim turbines side by side, each with a side exit over the fender."""
    return [
        box(0.45, 1.45, PAD1, 2.95, -9.0, -7.0, "detail", mirror=True, note="saddle on the bonnet pad"),
        cz(1.1, 2.4, [0.95, 3.4, -8.1], "secondary", mirror=True, note="turbine bodies"),
        cz(0.9, 0.3, [0.95, 3.4, -9.43], "detail", mirror=True, note="intakes"),
        box(-0.4, 0.4, 3.0, 3.7, -8.8, -7.2, "primary", note="cam cover between the turbines"),
        cx(0.9, 0.95, [1.78, 3.4, -6.92], "detail", mirror=True, note="side exit elbow"),
        cx(0.8, 0.2, [2.36, 3.4, -6.92], "thrust", mirror=True, note="side jet"),
    ]


def e1_itb_four():
    """Kanjo: transverse block with four upright intake trumpets and a side dump at each end."""
    out = [
        box(-2.2, 2.2, PAD1, 3.3, -9.0, -7.5, "secondary", note="transverse block on the bonnet pad"),
        box(-2.0, 2.0, 3.3, 3.45, -8.9, -7.6, "detail", note="plenum plate"),
        box(-1.9, 1.9, 2.75, 3.2, -7.5, -7.1, "detail", note="header"),
        cx(0.9, 0.5, [2.1, 3.05, -6.95], "detail", mirror=True, note="side dump"),
        cx(0.8, 0.14, [2.42, 3.05, -6.95], "thrust", mirror=True, note="side jet"),
    ]
    for x in (-1.5, -0.5, 0.5, 1.5):
        out.append(cy(0.7, 0.95, [x, 3.9, -8.25], "secondary", note="intake trumpet"))
        out.append(cy(0.5, 0.1, [x, 4.35, -8.25], "detail", note="trumpet mouth"))
    return out


def e1_big_single():
    """Drift: one big turbine through the bonnet, twin dump stacks leaning out."""
    return [
        box(-0.9, 0.9, PAD1, 3.0, -9.0, -6.9, "detail", note="saddle on the bonnet pad"),
        cz(1.75, 2.5, [0, 3.5, -7.95], "secondary", note="turbine body"),
        cz(1.4, 0.4, [0, 3.5, -9.38], "detail", note="intake"),
        ball(0.6, [0, 3.5, -9.25], "secondary", note="spinner"),
        box(-0.95, 0.95, 3.2, 3.8, -8.4, -8.0, "primary", note="clamp band"),
    ] + stack(1.45, 3.4, -7.0, 0.9, 1.0, 40, 0.8, mirror=True, note="dump stack")


def e1_slot():
    """Time Attack: letterbox turbine. Open ram mouth, 1.4 tall body, a slot jet along each side."""
    return [
        box(-2.1, 2.1, PAD1, 3.3, -9.0, Z_E1, "secondary", note="lower body on the bonnet pad"),
        box(-2.1, 2.1, 3.3, 4.0, -9.0, -7.6, "secondary", note="upper body: 1.4 tall in all"),
        ramp(-2.1, 2.1, 3.3, 4.0, -7.6, Z_E1, "secondary", "front", note="taper to the tail"),
        box(-2.25, 2.25, 2.85, 4.12, -9.35, -9.0, "primary", note="ram mouth frame"),
        box(-1.8, 1.8, 3.05, 3.9, -9.43, -9.35, "detail", note="open ram mouth, 3.6 x 0.85"),
        box(2.1, 2.3, 3.2, 4.1, -8.6, -6.9, "detail", mirror=True, note="side nozzle housing"),
        box(2.3, 2.48, 3.3, 4.0, -8.5, -7.0, "thrust", mirror=True, note="side slot jet, 0.7 high, above the fender line"),
    ]


def e1_snorkel():
    """Rally: one turbine offset to the left with a leaning dump stack, a cross pipe and a tall snorkel on the right."""
    return [
        box(-1.9, -0.6, PAD1, 3.0, -9.0, -7.0, "detail", note="saddle on the bonnet pad"),
        cz(1.35, 2.4, [-1.25, 3.5, -8.1], "secondary", note="offset turbine"),
        cz(1.05, 0.3, [-1.25, 3.5, -9.43], "detail", note="intake"),
        box(-0.6, 1.3, 2.9, 3.3, -7.4, -6.9, "detail", note="cross pipe to the snorkel"),
        cy(0.7, 1.5, [1.55, 3.4, -7.15], "primary", note="snorkel"),
        box(1.1, 2.0, 3.9, 4.38, -8.0, -6.7, "detail", note="snorkel head, mouth forward"),
    ] + stack(-1.45, 3.55, -6.95, 0.9, 0.9, -20, 0.8, note="dump stack")


# ---------------------------------------------------------------- Engine2 (tail engine)
PAD2 = 0.87   # lowest face of a tail engine (bay pad is Y 0.8)


def e2_twin():
    """Touge: twin turbines along the bay under twin deck scoops, round nozzles in the rear panel."""
    return [
        box(0.55, 2.05, PAD2, 1.5, 6.4, 7.0, "detail", mirror=True, note="saddle on the bay pad"),
        box(0.55, 2.05, PAD2, 1.5, 9.2, 9.8, "detail", mirror=True, note="saddle on the bay pad"),
        cz(1.6, 4.6, [1.3, 2.15, 8.1], "secondary", mirror=True, note="turbine bodies"),
        cz(1.3, 0.6, [1.3, 2.15, 5.5], "detail", mirror=True, note="intakes"),
        ramp(0.55, 2.05, 2.95, 3.7, 5.0, 7.2, "secondary", "front", mirror=True, note="ram scoop standing on the turbine, above the deck"),
        box(0.75, 1.85, 3.05, 3.6, 4.93, 5.0, "detail", mirror=True, note="scoop mouth"),
        cz(1.4, 0.5, [1.3, 2.15, 10.6], "detail", mirror=True, note="round nozzles in the rear panel"),
        cz(1.1, 0.15, [1.3, 2.15, 10.92], "thrust", mirror=True, note="jets"),
    ]


def e2_quad():
    """Kanjo: four small jets in a row across the tail, fed by a tall airbox."""
    out = [
        box(-2.2, 2.2, PAD2, 2.3, 7.4, 8.5, "detail", note="plenum on the bay pad"),
        box(-1.5, 1.5, 2.3, 3.9, 6.3, 7.9, "secondary", note="airbox, proud of the deck"),
        box(-1.2, 1.2, 3.9, 3.98, 6.5, 7.7, "detail", note="airbox top grille"),
        box(-1.2, 1.2, 2.6, 3.7, 6.22, 6.3, "detail", note="airbox mouth, facing forward"),
    ]
    for x in (-1.65, -0.55, 0.55, 1.65):
        out.append(cz(0.95, 2.4, [x, 1.75, 9.7], "secondary", note="jet tube"))
        out.append(cz(0.75, 0.15, [x, 1.75, 10.97], "thrust", note="jet"))
    return out


def e2_big_single():
    """Drift: one fat turbine filling the bay and standing above the deck."""
    return [
        box(1.0, 2.3, 1.8, 2.3, 6.4, 6.9, "detail", mirror=True, note="engine mount to the bay wall"),
        box(0.9, 2.3, 1.7, 2.2, 9.3, 9.8, "detail", mirror=True, note="engine mount to the bay wall"),
        cz(2.3, 3.5, [0, 2.2, 7.3], "secondary", note="turbine body, 0.35 proud of the deck"),
        cz(1.75, 0.6, [0, 2.2, 5.28], "detail", note="intake bell"),
        ball(0.8, [0, 2.2, 5.45], "secondary", note="spinner"),
        box(-1.22, 1.22, 1.3, 3.1, 7.1, 7.5, "primary", note="clamp band"),
        cz(1.9, 1.5, [0, 2.0, 9.75], "secondary", note="jet pipe under the wing"),
        cz(1.75, 0.5, [0, 2.0, 10.7], "detail", note="round nozzle in the rear panel"),
        cz(1.4, 0.15, [0, 2.0, 11.02], "thrust", note="jet"),
    ]


def e2_slot():
    """Time Attack: letterbox turbine. Ram hood above the deck, 1.4 tall body, slot nozzle 0.6 proud of the tail."""
    return [
        box(-2.2, 2.2, PAD2, 2.3, 6.0, 10.4, "secondary", note="letterbox body on the bay pad, 1.4 tall"),
        box(-2.0, 2.0, 2.3, 3.6, 5.2, 7.2, "primary", note="ram hood, proud of the deck"),
        box(-1.75, 1.75, 2.65, 3.45, 5.12, 5.2, "detail", note="open ram mouth, 3.5 x 0.8"),
        ramp(-2.0, 2.0, 2.3, 3.6, 7.2, 9.1, "primary", "front", note="taper to the slot"),
        box(-2.1, 2.1, 1.0, 2.2, 10.4, 11.0, "detail", note="slot nozzle, 0.6 proud of the tail face"),
        box(-1.85, 1.85, 1.25, 1.95, 11.0, 11.15, "thrust", note="slot jet, 0.7 high"),
        box(2.2, 2.35, PAD2, 2.6, 8.4, 10.9, "primary", mirror=True, note="side strake"),
    ]


def e2_over_under():
    """Rally: two turbines stacked on the centre line behind a tall intake tower."""
    out = [
        box(-0.75, 0.75, PAD2, 2.97, 7.0, 7.4, "detail", note="engine frame on the bay pad"),
        box(-0.75, 0.75, PAD2, 2.97, 9.4, 9.8, "detail", note="engine frame on the bay pad"),
        box(-0.8, 0.8, 0.95, 4.1, 5.1, 6.1, "primary", note="intake tower, proud of the deck"),
        box(-0.6, 0.6, 3.2, 3.95, 5.02, 5.1, "detail", note="tower mouth"),
    ]
    for y in (1.45, 2.47):
        out.append(cz(1.0, 4.3, [0, y, 8.25], "secondary", note="turbine body"))
        out.append(cz(0.95, 0.5, [0, y, 10.6], "detail", note="round nozzle in the rear panel"))
        out.append(cz(0.75, 0.15, [0, y, 10.92], "thrust", note="jet"))
    return out


# ---------------------------------------------------------------- Stabilisers (arch jets)
def four_corners(corner):
    """corner(zc) returns the +X parts for one arch centred on zc. Every part is mirrored."""
    return corner(ZFA) + corner(ZRA)


WALL = XI + 0.05   # first face of an arch jet (arch inner wall is X 2.7)


def st_vector_pods():
    """Touge: one slim round pod in each arch, vectoring nozzle down and back, and a control vane with a tip jet."""
    def corner(zc):
        return [
            box(WALL, 3.9, 0.4, 0.9, zc - 0.5, zc + 0.5, "detail", mirror=True, note="arm from the arch inner wall"),
            cz(1.3, 1.9, [4.5, 0.6, zc - 0.3], "secondary", mirror=True, note="pod, longer than wide"),
            cz(1.3, 0.25, [4.5, 0.6, zc - 1.38], "detail", mirror=True, note="intake lip"),
            cz(0.9, 0.1, [4.5, 0.6, zc - 1.55], "detail", mirror=True, note="intake mouth"),
            cz(1.1, 0.9, [4.5, 0.25, zc + 0.8], "detail", rot=[38, 0, 0], mirror=True, note="vectoring nozzle, down and back"),
            cz(0.9, 0.25, [4.5, -0.1, zc + 1.25], "thrust", rot=[38, 0, 0], mirror=True, note="jet, 0.9 across"),
            box(5.1, 5.8, 0.52, 0.68, zc - 0.8, zc + 0.5, "secondary", mirror=True, note="control vane"),
            box(5.75, 6.08, 0.38, 0.82, zc - 0.9, zc + 0.6, "thrust", mirror=True, note="tip jet: shows in plan and from the side"),
        ]
    return four_corners(corner)


def st_downjets():
    """Kanjo: two upright lift nozzles across each arch, one inboard and one outboard, under a beam with a ram scoop."""
    def corner(zc):
        out = [
            box(WALL, 5.9, 0.95, 1.45, zc - 0.45, zc + 0.45, "detail", mirror=True, note="beam from the arch inner wall"),
            box(4.9, 6.0, 0.95, 1.45, zc - 1.3, zc - 0.45, "secondary", mirror=True, note="ram scoop, outboard of every fender"),
            box(5.0, 5.9, 1.05, 1.35, zc - 1.37, zc - 1.3, "detail", mirror=True, note="scoop mouth"),
        ]
        for x in (3.7, 5.45):
            out.append(cy(1.1, 1.7, [x, 0.1, zc], "secondary", mirror=True, note="lift nozzle, taller than wide"))
            out.append(cy(0.85, 0.45, [x, -0.97, zc], "thrust", mirror=True, note="jet"))
        return out
    return four_corners(corner)


def st_vanes():
    """Drift: blanked arch with a slanted vane cascade over a wide slot jet on an outboard rail."""
    def corner(zc):
        out = [
            box(WALL, 4.2, 0.2, 0.6, zc - 1.5, zc + 1.5, "detail", mirror=True, note="duct from the arch inner wall"),
            box(4.2, 4.4, 0.0, Y_ARCH - 0.05, zc - 1.65, zc + 1.65, "primary", mirror=True, note="arch blanking plate"),
            box(4.4, 5.2, 0.0, 0.45, zc - 1.5, zc + 1.5, "secondary", mirror=True, note="slot nozzle rail"),
            box(4.5, 5.1, 0.08, 0.38, zc - 1.57, zc - 1.5, "detail", mirror=True, note="rail intake mouth"),
            box(2.9, 6.05, -0.35, 0.0, zc - 1.4, zc + 1.4, "thrust", mirror=True, note="slot jet: glows in plan outboard of the rail, 0.45 past the widest fender"),
        ]
        for dz in (-1.0, -0.2, 0.6):
            out.append(P("block", [0.12, 1.2, 0.3], [4.46, 0.95, zc + dz + 0.2], "detail", rot=[-35, 0, 0], mirror=True, note="vane"))
        return out
    return four_corners(corner)


def st_blades():
    """Time Attack: a slim canted slot duct in each arch. Mouth at the front, slot nozzle at the back, end fence with a glowing rail."""
    cant = [0, 0, -14]

    def corner(zc):
        return [
            box(WALL, 3.6, -0.1, 0.7, zc - 0.35, zc + 0.35, "detail", mirror=True, note="strut from the arch inner wall"),
            P("block", [2.3, 0.7, 2.6], [4.6, 0.0, zc - 0.1], "secondary", rot=cant, mirror=True, note="canted duct, longer than wide"),
            P("block", [2.0, 0.45, 0.14], [4.6, 0.0, zc - 1.45], "detail", rot=cant, mirror=True, note="intake mouth"),
            P("block", [2.1, 0.55, 0.3], [4.6, 0.0, zc + 1.35], "detail", rot=cant, mirror=True, note="slot nozzle"),
            P("block", [1.9, 0.42, 0.14], [4.6, 0.0, zc + 1.57], "thrust", rot=cant, mirror=True, note="slot jet, 1.9 across"),
            box(5.8, 5.95, -1.0, 0.3, zc - 1.5, zc + 1.5, "primary", mirror=True, note="end fence"),
            box(5.75, 6.08, 0.3, 0.6, zc - 1.2, zc + 1.2, "thrust", mirror=True, note="fence rail jet: shows in plan and from the side"),
        ]
    return four_corners(corner)


def st_outriggers():
    """Rally: a square jet pod hung low and outboard on a drop strut. The big flared nozzle is the main shape."""
    def corner(zc):
        return [
            box(WALL, 5.4, 0.3, 0.7, zc - 0.4, zc + 0.4, "detail", mirror=True, note="arm from the arch inner wall"),
            box(4.9, 5.4, -0.5, 0.3, zc - 0.3, zc + 0.3, "primary", mirror=True, note="drop strut"),
            box(4.6, 6.0, -1.5, -0.5, zc - 1.1, zc + 0.5, "secondary", mirror=True, note="pod, longer than wide"),
            box(4.75, 5.85, -1.35, -0.65, zc - 1.18, zc - 1.1, "detail", mirror=True, note="intake mouth"),
            box(4.5, 6.1, -1.6, -0.4, zc + 0.5, zc + 1.3, "detail", mirror=True, note="flared nozzle"),
            box(4.65, 5.95, -1.45, -0.55, zc + 1.3, zc + 1.45, "thrust", mirror=True, note="jet, 1.3 x 0.9"),
            box(5.65, 6.0, -0.5, -0.36, zc - 0.9, zc + 0.3, "thrust", mirror=True, note="top trim jet: shows in plan"),
        ]
    return four_corners(corner)


# ---------------------------------------------------------------- Boost (exhaust burners)
# Boost has its own shape language: square cans with a flared square petal, standing about 2 studs
# behind the tail face. Tail engine nozzles are round and sit in the rear panel.
ZB = 10.55   # first face of a boost module (tail datum is Z 10.4)


def bo_twin_tips():
    """Touge: one square burner each side."""
    return [
        box(2.7, 3.9, 0.3, 0.8, ZB, 10.9, "detail", mirror=True, note="hanger on the tail face"),
        box(2.75, 3.85, 0.45, 1.55, 10.75, 12.2, "secondary", mirror=True, note="square burner can"),
        ramp(2.9, 3.7, 1.55, 1.9, 10.7, 11.8, "detail", "front", mirror=True, note="intake scoop"),
        box(2.65, 3.95, 0.35, 1.65, 12.2, 12.55, "detail", mirror=True, note="flared petal"),
        box(2.8, 3.8, 0.5, 1.5, 12.55, 12.72, "thrust", mirror=True, note="jet, 1.0 square"),
    ]


def bo_cannon():
    """Kanjo: one big square cannon, offset to the right."""
    return [
        box(2.9, 3.9, 0.3, 0.8, ZB, 11.0, "detail", note="hanger on the tail face"),
        box(2.9, 4.3, 0.5, 1.7, 10.6, 10.8, "detail", note="intake collar"),
        box(2.75, 4.45, 0.3, 1.9, 10.8, 12.0, "secondary", note="cannon can, 1.7 x 1.6"),
        box(2.65, 4.6, 0.25, 2.0, 12.0, 12.5, "detail", note="flared petal"),
        box(2.8, 4.45, 0.4, 1.85, 12.5, 12.7, "thrust", note="jet, 1.65 x 1.45"),
        box(-3.8, -2.9, 0.3, 0.75, ZB, 10.8, "detail", note="blanking plate on the empty side"),
    ]


def bo_bamboo():
    """Drift: bamboo stacks. Two tall pipes each side, leaning back, 0.7 across with 0.62 glowing tips."""
    tilt = 15.0
    sn, cs = math.sin(math.radians(tilt)), math.cos(math.radians(tilt))
    out = [
        box(2.7, 4.2, 0.3, 0.8, ZB, 11.0, "detail", mirror=True, note="hanger on the tail face"),
        cz(0.8, 1.2, [3.0, 0.85, 11.4], "secondary", mirror=True, note="base can"),
        cz(0.8, 1.2, [3.8, 0.85, 11.4], "secondary", mirror=True, note="base can"),
    ]
    for x, length, yc in ((3.0, 3.0, 2.4), (3.8, 4.0, 2.9)):
        k = length / 2 + 0.15
        out.append(cy(0.7, length, [x, yc, 11.9], "secondary", rot=[tilt, 0, 0], mirror=True, note="bamboo pipe, 0.7 across"))
        out.append(cy(0.62, 0.3, [x, yc + k * cs, 11.9 + k * sn], "thrust", rot=[tilt, 0, 0], mirror=True, note="jet"))
    return out


def bo_slot_bar():
    """Time Attack: one full-width slot burner, 1.9 behind the tail."""
    return [
        box(-3.8, 3.8, 0.27, 0.83, ZB, 12.3, "secondary", note="slot burner bar on the tail face"),
        box(-3.6, 3.6, 0.32, 0.8, 12.3, 12.48, "thrust", note="slot jet, 7.2 x 0.5"),
        box(3.8, 3.95, 0.27, 1.6, ZB, 12.7, "primary", mirror=True, note="end fence"),
        ramp(2.7, 3.7, 0.83, 1.25, 10.6, 11.9, "detail", "front", mirror=True, note="intake scoop"),
    ]


def bo_quad_stack():
    """Rally: four square burners in one upright bank on the left."""
    out = [
        box(-3.9, -2.8, 0.3, 2.4, ZB, 10.8, "detail", note="bracket on the tail face"),
        box(-3.95, -2.75, 0.3, 2.45, 10.8, 12.1, "secondary", note="bank housing, 1.2 wide and 2.15 tall"),
        ramp(-3.8, -2.9, 2.45, 2.85, 10.7, 11.9, "detail", "front", note="intake scoop"),
        box(2.9, 3.8, 0.3, 0.75, ZB, 10.8, "detail", note="blanking plate on the empty side"),
    ]
    for y in (0.62, 1.12, 1.62, 2.12):
        out.append(box(-3.87, -2.83, y - 0.22, y + 0.22, 12.1, 12.45, "detail", note="flared petal"))
        out.append(box(-3.78, -2.92, y - 0.16, y + 0.16, 12.45, 12.6, "thrust", note="jet"))
    return out


# ---------------------------------------------------------------- SidePods (side kit)
# Wide side kits return to X 4.6 over their last stud at both ends (the narrowest clips carry arch lips out to 4.6).
Z_S0, Z_S1 = FA1 + 0.1, RA0 - 0.1     # side kit ends
Z_C0, Z_C1 = Z_S0 + 1.0, Z_S1 - 1.0   # full width between these
X_END = 4.6


def end_caps(x1, y0, y1, ch="primary"):
    """The two tapered ends of a side kit that is x1 wide in the middle. Written for +X, mirrored."""
    return [
        box(4.0, X_END, y0, y1, Z_S0, Z_C0, ch, mirror=True, note="front end, at arch-lip width"),
        taper(X_END, x1, y0, y1, Z_S0, Z_C0, ch, "back", mirror=True, note="front end cap, tapered in plan"),
        box(4.0, X_END, y0, y1, Z_C1, Z_S1, ch, mirror=True, note="rear end, at arch-lip width"),
        taper(X_END, x1, y0, y1, Z_C1, Z_S1, ch, "front", mirror=True, note="rear end cap, tapered in plan"),
    ]


def sp_skirts():
    """Touge: slim skirts."""
    return [
        box(4.0, 4.4, -0.3, 0.55, Z_S0, Z_S1, "primary", mirror=True, note="slim skirt, arch to arch"),
        box(4.4, 4.46, 0.25, 0.45, Z_S0, Z_S1, "secondary", mirror=True, note="pinstripe"),
    ]


def sp_boards():
    """Kanjo: door boards, side vent pods, bare sill rail."""
    return [
        box(4.0, 4.12, 0.85, 2.2, -1.7, 1.1, "secondary", mirror=True, note="door board"),
        box(4.0, 4.6, 0.3, 1.4, Z_S0, -3.2, "detail", mirror=True, note="side vent pod behind the front arch"),
        box(4.0, 4.25, 0.2, 0.45, -3.2, Z_S1, "detail", mirror=True, note="sill rail"),
    ]


def sp_deep():
    """Drift: deep box skirts with tapered ends, a lead-in to the rear arch and underglow."""
    return end_caps(5.1, -0.55, 0.6) + [
        box(4.0, 5.1, -0.55, 0.6, Z_C0, Z_C1, "primary", mirror=True, note="deep box skirt"),
        ramp(4.0, X_END, 0.6, 1.55, 1.8, Z_S1, "primary", "back", mirror=True, note="lead-in to the rear arch"),
        box(4.1, 4.5, 0.75, 1.4, Z_S1, Z_S1 + 0.05, "detail", mirror=True, note="lead-in vent"),
        box(4.1, 5.0, -0.7, -0.55, Z_C0 + 0.1, Z_C1 - 0.1, "neon", mirror=True, note="underglow"),
    ]


def sp_splitters():
    """Time Attack: a solid sill fairing that fills the step between the wide clips, on a splitter blade, with a fence."""
    return end_caps(5.3, -0.3, 0.7) + end_caps(5.6, -0.95, -0.75, "detail") + [
        box(4.0, 5.3, -0.3, 0.7, Z_C0, Z_C1, "primary", mirror=True, note="sill fairing, butts the door face"),
        ramp_x(4.0, 5.3, 0.7, 2.2, Z_C0, Z_C1, "primary", "out", mirror=True, note="fairing shoulder: a blister up the door to Y 2.2, under the belt stripe"),
        box(4.0, 5.0, -0.75, -0.3, Z_S0 + 0.3, Z_S1 - 0.3, "detail", mirror=True, note="web down to the blade"),
        box(4.0, 5.6, -0.95, -0.75, Z_C0, Z_C1, "detail", mirror=True, note="side splitter blade"),
        box(5.3, 5.45, -0.75, 1.3, 1.4, Z_C1, "primary", mirror=True, note="fence, mounted on the fairing"),
    ]


def sp_steps():
    """Rally: tube side step on a rock-slider plate, and four mud flaps."""
    return [
        box(4.0, 4.75, -0.2, 0.2, -4.3, 4.4, "detail", mirror=True, note="rock-slider plate, butts the door face along its whole length"),
        cz(0.5, 8.7, [4.75, 0.0, 0.05], "secondary", mirror=True, note="tube side step on the plate edge"),
        box(4.0, 4.9, -1.2, 1.0, FA1 + 0.02, FA1 + 0.2, "secondary", mirror=True, note="front mud flap"),
        box(2.9, 4.9, -1.25, 0.15, RA1 + 0.05, RA1 + 0.25, "secondary", mirror=True, note="rear mud flap"),
    ]


# ---------------------------------------------------------------- FrontBumper (front lip)
# No lip is wider than X 5.2 (the narrowest clip is 4.6 at the arch lips, plus 0.6), and none is wider than 4.6 at the chin.
ZC = Z_CHIN - 0.05   # first face of a bumper ahead of the chin


def fl_lip():
    """Touge: smooth bumper face with a thin chin lip."""
    return [
        box(-4.4, 4.4, Y_SILL, 1.15, -11.0, ZC, "primary", note="bumper face on the chin"),
        box(-2.6, 2.6, 0.4, 0.95, -11.06, -11.0, "detail", note="air slot"),
        box(3.1, 4.1, 0.5, 0.85, -11.06, -11.0, "neon", mirror=True, note="fog lamps"),
        box(-4.5, 4.5, -0.25, Y_SILL - 0.03, -11.25, -8.4, "primary", note="chin lip under the nose"),
    ]


def fl_tow_bar():
    """Kanjo: no bumper. Jack bar, tow hook, short under tray."""
    return [
        box(-3.6, 3.6, -0.1, Y_SILL - 0.03, -10.3, -8.4, "detail", note="flat under tray"),
        cx(0.35, 7.8, [0, 0.45, -10.75], "detail", note="jack bar ahead of the chin"),
        box(2.9, 3.2, 0.3, 0.6, -10.75, ZC, "detail", mirror=True, note="bar stay"),
        box(2.1, 2.5, 0.65, 1.05, -11.5, ZC, "neon", note="tow hook"),
    ]


def fl_intercooler():
    """Drift: tall bumper face with cut corners, big mouth, intercooler on show, brake ducts."""
    return [
        box(-4.0, 4.0, -0.5, 1.15, -11.3, ZC, "primary", note="deep bumper face on the chin"),
        taper(4.0, 4.6, -0.5, 1.15, -11.3, ZC, "primary", "back", mirror=True, note="cut corner: 4.6 wide at the chin, 4.0 at the front"),
        box(-3.0, 3.0, -0.2, 1.0, -11.36, -11.3, "detail", note="mouth"),
        box(-2.6, 2.6, 0.0, 0.85, -11.42, -11.36, "secondary", note="intercooler core"),
        box(3.2, 3.9, -0.1, 0.9, -11.36, -11.3, "detail", mirror=True, note="brake duct"),
    ]


def fl_splitter():
    """Time Attack: arrowhead splitter blade, air dam, rods and one canard each side."""
    return [
        box(-4.4, 4.4, -0.75, -0.55, -12.1, -8.4, "detail", note="splitter blade"),
        taper(4.4, 5.2, -0.75, -0.55, -12.1, -8.4, "detail", "back", mirror=True, note="blade edge: 4.4 at the tip, 5.2 at the arch"),
        box(-4.4, 4.4, -0.55, Y_SILL - 0.03, -10.3, -8.6, "detail", note="air dam under the nose"),
        box(-4.4, 4.4, Y_SILL, 1.1, -10.85, ZC, "secondary", note="air dam face on the chin"),
        P("block", [0.14, 0.14, 1.7], [2.2, 0.15, -11.15], "secondary", rot=[-42, 0, 0], mirror=True, note="splitter rod"),
        P("block", [0.8, 0.1, 0.95], [4.8, 0.65, -10.95], "primary", rot=[-18, 0, 0], mirror=True, note="canard on the air dam end"),
    ]


def fl_skid():
    """Rally: black bumper, skid plate, fog lamps."""
    return [
        box(-4.5, 4.5, Y_SILL, 1.15, -10.9, ZC, "detail", note="black bumper on the chin"),
        ramp(-3.4, 3.4, -0.75, Y_SILL - 0.03, -10.9, -8.4, "secondary", "under_back", note="skid plate"),
        cz(0.7, 0.45, [3.7, 0.7, -11.05], "detail", mirror=True, note="fog lamp"),
        cz(0.52, 0.15, [3.7, 0.7, -11.3], "neon", mirror=True, note="fog lamp face"),
        box(-0.5, 0.5, 0.35, 0.95, -11.0, -10.9, "secondary", note="plate mount"),
    ]


# ---------------------------------------------------------------- RearBumper (diffuser)
def rd_valance():
    """Touge: shallow valance."""
    return [
        box(-4.4, 4.4, -0.3, Y_SILL - 0.03, 8.7, Z_TAIL, "primary", note="shallow valance under the tail"),
        box(-2.0, 2.0, -0.36, -0.3, 9.3, Z_TAIL, "detail", note="centre cut"),
    ]


def rd_beam():
    """Kanjo: bare tube and a tow hook."""
    return [
        cx(0.35, 7.6, [0, -0.05, 10.2], "detail", note="bare lower tube"),
        box(2.9, 3.2, -0.05, Y_SILL - 0.03, 9.0, 10.2, "detail", mirror=True, note="tube stay"),
        box(-2.5, -2.1, -0.3, 0.1, 10.2, 11.3, "neon", note="tow hook"),
    ]


def rd_bash():
    """Drift: tube bash bar standing off the tail."""
    return [
        box(2.8, 3.15, -0.3, Y_SILL - 0.03, 8.7, 11.6, "detail", mirror=True, note="bash bar rail"),
        cx(0.42, 7.4, [0, -0.08, 11.6], "secondary", note="bash bar cross tube"),
        cx(0.3, 5.6, [0, -0.7, 10.6], "detail", note="lower tube"),
        box(2.6, 2.9, -0.75, -0.1, 10.45, 10.75, "detail", mirror=True, note="drop link"),
    ]


def rd_finned():
    """Time Attack: long finned diffuser, no wider than X 4.6."""
    fins = [box(x - 0.07, x + 0.07, -1.25, 0.05, 9.0, 11.95, "primary", note="diffuser fin") for x in (-3.8, -1.9, 0.0, 1.9, 3.8)]
    return [ramp(-4.6, 4.6, -1.15, Y_SILL - 0.03, 8.7, 11.9, "detail", "under_front", note="diffuser tray, rising to the rear")] + fins


def rd_guard():
    """Rally: rear skid guard and tow eyes."""
    return [
        ramp(-3.2, 3.2, -0.8, Y_SILL - 0.03, 8.7, Z_TAIL, "secondary", "under_front", note="rear skid guard"),
        box(3.5, 3.9, -0.35, Y_SILL - 0.03, 9.9, 10.7, "neon", mirror=True, note="tow eyes"),
    ]


# ---------------------------------------------------------------- RearSpoiler (wing)
PADW = Y_BELT + 0.03   # lowest face of a wing (deck pad is Y 3.0)


def wg_ducktail():
    """Touge: full-width ducktail that bridges the tail engine bay."""
    return [
        ramp(-3.9, 3.9, PADW, 3.8, 9.3, Z_TAIL, "primary", "back", note="ducktail on the deck pad; no wider than the narrowest tail"),
        box(-3.9, 3.9, 3.8, 3.9, 10.2, 10.45, "secondary", note="lip edge"),
    ]


def wg_fins():
    """Kanjo: two shark fins, no blade."""
    return [
        ramp(3.3, 3.55, PADW, 4.7, 9.3, 11.3, "primary", "back", mirror=True, note="shark fin on the deck pad"),
        box(3.25, 3.6, PADW, 3.25, 9.3, 10.3, "detail", mirror=True, note="fin foot"),
    ]


def wg_gt():
    """Drift: GT wing on two uprights."""
    return [
        box(3.2, 3.4, PADW, 5.3, 9.8, 10.3, "detail", mirror=True, note="upright on the deck pad"),
        box(-5.2, 5.2, 5.3, 5.55, 9.7, 11.3, "secondary", note="blade"),
        box(-5.2, 5.2, 5.55, 5.75, 11.15, 11.3, "detail", note="gurney"),
        box(5.2, 5.38, 4.8, 5.95, 9.5, 11.5, "primary", mirror=True, note="end plate"),
    ]


def wg_swan():
    """Time Attack: tall swan-neck wing with big end plates."""
    return [
        box(2.9, 3.08, PADW, 7.0, 9.4, 9.9, "detail", mirror=True, note="swan-neck pylon on the deck pad"),
        box(2.9, 3.08, 6.75, 7.0, 9.9, 10.9, "detail", mirror=True, note="neck"),
        box(2.9, 3.08, 6.45, 6.75, 10.5, 10.9, "detail", mirror=True, note="hanger"),
        box(-5.6, 5.6, 6.2, 6.45, 9.9, 11.4, "secondary", note="blade hung from above"),
        box(5.6, 5.78, 5.4, 7.3, 9.6, 11.58, "primary", mirror=True, note="end plate"),
    ]


def wg_box():
    """Rally: box wing. Two blades on two plates that stand on the wing pads, tip plates outboard."""
    return [
        box(3.4, 3.6, PADW, 5.2, 9.4, 11.0, "primary", mirror=True, note="plate on the wing pad (X 2.9 to 3.6 on every tail)"),
        box(-4.2, 4.2, 3.95, 4.13, 9.6, 10.8, "secondary", note="lower blade"),
        box(-4.2, 4.2, 4.95, 5.15, 9.8, 11.0, "secondary", note="upper blade"),
        box(4.2, 4.35, 3.8, 5.3, 9.5, 11.1, "primary", mirror=True, note="tip plate, carried by the blades"),
    ]


# ---------------------------------------------------------------- modules, kits, builds
def mod(name, culture, parts):
    return {"name": name, "culture": culture, "parts": parts}


MODULES = {
    "Engine1": {
        "twin_cam": mod("Twin Cam", "Touge", e1_twin_cam()),
        "itb_four": mod("ITB Four", "Kanjo", e1_itb_four()),
        "big_single": mod("Big Single", "Drift", e1_big_single()),
        "slot_burner": mod("Bonnet Letterbox", "Time Attack", e1_slot()),
        "snorkel": mod("Snorkel", "Rally", e1_snorkel()),
    },
    "Engine2": {
        "twin_turbine": mod("Twin Turbine", "Touge", e2_twin()),
        "quad_cluster": mod("Quad Row", "Kanjo", e2_quad()),
        "missile_can": mod("Missile Can", "Drift", e2_big_single()),
        "tail_slot": mod("Tail Letterbox", "Time Attack", e2_slot()),
        "over_under": mod("Over-Under", "Rally", e2_over_under()),
    },
    "Stabilisers": {
        "vector_pods": mod("Vector Pods", "Touge", st_vector_pods()),
        "downjets": mod("Twin Downjets", "Kanjo", st_downjets()),
        "vane_cascade": mod("Vane Cascade", "Drift", st_vanes()),
        "blade_skids": mod("Blade Ducts", "Time Attack", st_blades()),
        "outriggers": mod("Outrigger Pods", "Rally", st_outriggers()),
    },
    "Boost": {
        "twin_tips": mod("Twin Tips", "Touge", bo_twin_tips()),
        "cannon": mod("Cannon", "Kanjo", bo_cannon()),
        "bamboo": mod("Bamboo Stacks", "Drift", bo_bamboo()),
        "slot_bar": mod("Slot Bar", "Time Attack", bo_slot_bar()),
        "quad_stack": mod("Quad Bank", "Rally", bo_quad_stack()),
    },
    "FrontBody": {
        "popup_wedge": mod("Pop-Up Wedge", "Touge", fb_popup()),
        "shorty": mod("Shorty", "Kanjo", fb_shorty()),
        "wide_nose": mod("Wide Nose", "Drift", fb_wide()),
        "arrow_nose": mod("Arrow Nose", "Time Attack", fb_arrow()),
        "stage_nose": mod("Stage Nose", "Rally", fb_stage()),
    },
    "RearBody": {
        "clean_tail": mod("Clean Tail", "Touge", rb_clean()),
        "bob_tail": mod("Bob Tail", "Kanjo", rb_bob()),
        "wide_tail": mod("Wide Tail", "Drift", rb_wide()),
        "tunnel_tail": mod("Tunnel Tail", "Time Attack", rb_tunnel()),
        "stage_tail": mod("Stage Tail", "Rally", rb_stage()),
    },
    "SidePods": {
        "slim_skirts": mod("Slim Skirts", "Touge", sp_skirts()),
        "door_boards": mod("Door Boards", "Kanjo", sp_boards()),
        "deep_skirts": mod("Deep Skirts", "Drift", sp_deep()),
        "side_splitters": mod("Sill Fairings", "Time Attack", sp_splitters()),
        "steps_flaps": mod("Steps and Flaps", "Rally", sp_steps()),
    },
    "FrontBumper": {
        "chin_lip": mod("Chin Lip", "Touge", fl_lip()),
        "tow_bar": mod("Tow Bar", "Kanjo", fl_tow_bar()),
        "intercooler": mod("Intercooler Bumper", "Drift", fl_intercooler()),
        "splitter": mod("Splitter and Canards", "Time Attack", fl_splitter()),
        "skid_plate": mod("Skid Plate", "Rally", fl_skid()),
    },
    "RearBumper": {
        "valance": mod("Valance", "Touge", rd_valance()),
        "bare_beam": mod("Bare Beam", "Kanjo", rd_beam()),
        "bash_bar": mod("Bash Bar", "Drift", rd_bash()),
        "finned": mod("Finned Diffuser", "Time Attack", rd_finned()),
        "rear_guard": mod("Rear Guard", "Rally", rd_guard()),
    },
    "RearSpoiler": {
        "ducktail": mod("Ducktail", "Touge", wg_ducktail()),
        "twin_fins": mod("Twin Fins", "Kanjo", wg_fins()),
        "gt_wing": mod("GT Wing", "Drift", wg_gt()),
        "swan_neck": mod("Swan Neck", "Time Attack", wg_swan()),
        "box_wing": mod("Box Wing", "Rally", wg_box()),
    },
}

SLOT_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost", "FrontBody", "RearBody", "SidePods", "FrontBumper", "RearBumper", "RearSpoiler"]


def kit(name, culture, *ids):
    return {"name": name, "culture": culture, "modules": dict(zip(SLOT_ORDER, ids))}


KITS = {
    "touge": kit("Touge", "Touge", "twin_cam", "twin_turbine", "vector_pods", "twin_tips", "popup_wedge", "clean_tail", "slim_skirts", "chin_lip", "valance", "ducktail"),
    "kanjo": kit("Kanjo", "Kanjo", "itb_four", "quad_cluster", "downjets", "cannon", "shorty", "bob_tail", "door_boards", "tow_bar", "bare_beam", "twin_fins"),
    "drift": kit("Drift", "Drift", "big_single", "missile_can", "vane_cascade", "bamboo", "wide_nose", "wide_tail", "deep_skirts", "intercooler", "bash_bar", "gt_wing"),
    "attack": kit("Time Attack", "Time Attack", "slot_burner", "tail_slot", "blade_skids", "slot_bar", "arrow_nose", "tunnel_tail", "side_splitters", "splitter", "finned", "swan_neck"),
    "rally": kit("Rally", "Rally", "snorkel", "over_under", "outriggers", "quad_stack", "stage_nose", "stage_tail", "steps_flaps", "skid_plate", "rear_guard", "box_wing"),
}

PAINT = {
    "touge": {"primary": "#f1f1ec", "secondary": "#d3222a", "neon": "#ffd060"},
    "pocket": {"primary": "#f4c20d", "secondary": "#19a34a", "neon": "#ff5a1f"},
    "syndicate": {"primary": "#6a35c9", "secondary": "#cfd3da", "neon": "#b6ff3a"},
    "kei": {"primary": "#ea3f8f", "secondary": "#f5f5f5", "neon": "#7df9ff"},
    "estate": {"primary": "#1d4fc0", "secondary": "#e3b23c", "neon": "#fff6cf"},
}

BUILDS = [
    {"name": "Touge, own Touge kit", "cockpit": "touge", "kit": "touge", "paint": PAINT["touge"]},
    {"name": "Touge, Time Attack kit", "cockpit": "touge", "kit": "attack", "paint": PAINT["touge"]},
    {"name": "Pocket, own Kanjo kit", "cockpit": "pocket", "kit": "kanjo", "paint": PAINT["pocket"]},
    {"name": "Pocket, Rally kit", "cockpit": "pocket", "kit": "rally", "paint": PAINT["pocket"]},
    {"name": "Syndicate, own Drift kit", "cockpit": "syndicate", "kit": "drift", "paint": PAINT["syndicate"]},
    {"name": "Syndicate, Touge kit", "cockpit": "syndicate", "kit": "touge", "paint": PAINT["syndicate"]},
    {"name": "Roadster, own Time Attack kit", "cockpit": "kei", "kit": "attack", "paint": PAINT["kei"]},
    {"name": "Roadster, Kanjo kit", "cockpit": "kei", "kit": "kanjo", "paint": PAINT["kei"]},
    {"name": "Estate, own Rally kit", "cockpit": "estate", "kit": "rally", "paint": PAINT["estate"]},
    {"name": "Estate, Drift kit", "cockpit": "estate", "kit": "drift", "paint": PAINT["estate"]},
    {"name": "Mixed: Roadster sleeper", "cockpit": "kei", "kit": "touge",
     "modules": {"Engine1": "big_single", "Boost": "bamboo", "RearSpoiler": "gt_wing", "FrontBumper": "intercooler"},
     "paint": {"primary": "#19b38a", "secondary": "#20242c", "neon": "#ffe14a"},
     "note": "Clean Touge body with Drift engine, exhaust, wing and bumper."},
    {"name": "Mixed: Estate time attack", "cockpit": "estate", "kit": "attack",
     "modules": {"FrontBody": "wide_nose", "Stabilisers": "outriggers", "Engine2": "missile_can", "SidePods": "steps_flaps"},
     "paint": {"primary": "#20242c", "secondary": "#ff6a1a", "neon": "#ff6a1a"},
     "note": "Wide Drift nose with a Time Attack tail: unequal clip widths on one car."},
    {"name": "Mixed: Pocket street sweeper", "cockpit": "pocket", "kit": "drift",
     "modules": {"FrontBody": "shorty", "FrontBumper": "splitter", "Engine1": "itb_four", "Stabilisers": "downjets", "Boost": "quad_stack", "RearSpoiler": "twin_fins"},
     "paint": {"primary": "#d92b2b", "secondary": "#f5f5f5", "neon": "#7df9ff"},
     "note": "Narrow Kanjo nose with a wide Drift tail and deep skirts."},
    {"name": "Mixed: narrow clips, sill fairings", "cockpit": "touge", "kit": "kanjo",
     "modules": {"SidePods": "side_splitters", "FrontBumper": "splitter", "RearBumper": "finned", "Stabilisers": "blade_skids"},
     "paint": {"primary": "#2f6fe0", "secondary": "#f5f5f5", "neon": "#ffd060"},
     "note": "Shorty and Bob Tail (the narrowest clips) with the widest side kit, lip and diffuser."},
    {"name": "Mixed: narrow clips, deep skirts", "cockpit": "syndicate", "kit": "kanjo",
     "modules": {"SidePods": "deep_skirts", "FrontBumper": "intercooler", "Stabilisers": "vane_cascade", "Boost": "twin_tips"},
     "paint": {"primary": "#e8e2d0", "secondary": "#b5121b", "neon": "#ff9d2e"},
     "note": "Shorty and Bob Tail with the Drift skirts and bumper."},
]

SPEC = {
    "id": "street",
    "displayName": "Street",
    "tagline": "Tuner and import cars on jets: a bonnet engine, a tail engine in an open bay, arch jets and exhaust burners.",
    "standard": STANDARD,
    "cockpits": COCKPITS,
    "kits": KITS,
    "modules": MODULES,
    "builds": BUILDS,
}


def main():
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(SPEC, f, indent=1)
        f.write("\n")
    n = sum(len(m) for m in MODULES.values())
    print("wrote %s: %d cockpits, %d kits, %d modules, %d builds" % (OUT, len(COCKPITS), len(KITS), n, len(BUILDS)))


if __name__ == "__main__":
    main()
