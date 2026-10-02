"""Generator for the Cruiser frame-class blockout spec (round 2, after the critic's review). Design exploration only.

Run from the repo root:
  py -3 scripts/vehicle_blockouts/gen/cruiser.py
  py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/cruiser.json

Root space: +X right, +Y up, forward is -Z. Units are studs.

Layout in one paragraph: two body halves (FrontBody, RearBody) meet at a shadow gap under the cabin. Between
PAD_F and PAD_R their tops are one flat deck at the beltline, and every pad lies in that run. The cockpit is the
cabin: everything above the beltline between CAB_Z0 and CAB_Z1, up to Y 6.5. It owns the cowl, the glass, the roof
and the rear shelf, so each cabin has its own length, height and position on the deck. Engine1 sits on the bonnet
pad, Engine2 on the boot pad, fins on the rear fender tops, the boost unit hangs under the tail and the stabilisers
hang under the sills. Outside the pad run (the nose and the tail) each half has its own length, height, width and
plan, but it always ends in a solid seam face from the sill to the bar line, so a bumper never hangs in front of a hole.
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "specs", "cruiser.json"))

# ---------------------------------------------------------------- datums
HOVER = -2.0      # hover plane (the road)
SILL = 0.2        # bottom of every painted body half (belly pad)
BAR = 1.4         # bumper bars stay below this in front of lamps; the seam face is solid up to here
BELT = 3.0        # beltline: flat top of both body halves in the pad run, base of every cabin
ROOF = 6.5        # top of the cockpit envelope
BODY_X = 4.7      # half width of the painted body side (flank pad)
FLANK_X = 4.8     # flank trim starts here
NOSE = -16.4      # Front Chrome seam
MID = 0.0         # seam between the two body halves
TAIL = 15.5       # Rear Chrome seam
FACE_F = NOSE + 0.1   # every front half is solid to here between SILL and BAR
FACE_R = TAIL - 0.1   # every rear half is solid to here between SILL and BAR
CAB_Z0, CAB_Z1 = -6.5, 9.0     # cabin deck: any cabin may sit anywhere in this run
PAD_F, PAD_R = -12.6, 12.6     # the pad run. Between these every body half is the same slab: flat deck, flank and belly.
BONNET_PAD = (PAD_F, -7.0)     # Engine1 lands here, X within 3.4. Nozzles turn out or up: nothing fires at the screen.
BOOT_PAD = (10.2, PAD_R)       # Engine2 lands here, X within 3.6. Intakes start at Z 10.2: clear air behind any cabin.
FIN_PAD = (9.2, PAD_R)         # fins land here, X 3.6 to 4.6. Anything behind the pad must carry itself.
BELLY_PAD = (PAD_F, PAD_R)     # stabilisers and the boost hanger hang from the flat belly in this run
FLANK_PAD = (PAD_F, PAD_R)     # flank trim lands on the flat body side in this run


# ---------------------------------------------------------------- part helpers
def part(shape, size, pos, ch="primary", rot=None, mirror=False, note=""):
    d = {"shape": shape, "size": [round(float(v), 3) for v in size], "pos": [round(float(v), 3) for v in pos]}
    if rot and any(abs(r) > 1e-6 for r in rot):
        d["rot"] = [round(float(r), 2) for r in rot]
    d["ch"] = ch
    if mirror:
        d["mirror"] = True
    if note:
        d["note"] = note
    return d


def box(x0, x1, y0, y1, z0, z1, ch="primary", mirror=False, note="", rot=None):
    return part("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, mirror, note)


_WEDGE = {
    "up_back": None,             # thin edge at the front, tall face at the back (windscreen, nose droop)
    "up_front": [0, 180, 0],     # tall face at the front, falls to the back (rear screen, tail droop)
    "under_back": [180, 0, 0],   # flat top, underside sweeps up to the back (tail cut-up)
    "under_front": [0, 0, 180],  # flat top, underside sweeps up to the front (shark prow)
}


def wedge(x0, x1, y0, y1, z0, z1, kind="up_back", ch="primary", mirror=False, note=""):
    return part("wedge", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, _WEDGE[kind], mirror, note)


def chamfer(x_in, x_out, y0, y1, z0, z1, ch="primary", note=""):
    """A shoulder chamfer along Z on the +X side (mirrored): full width at the bottom, leans in to x_in at the top."""
    return part("wedge", [z1 - z0, y1 - y0, x_out - x_in], [(x_in + x_out) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, [0, -90, 0], True, note)


def flare(x0, x1, y0, y1, z0, z1, ch="primary", wide="back", note=""):
    """A plan-view wedge on the +X side (mirrored): flush with x0 at one end, out to x1 at the wide end."""
    rot = [0, 0, -90] if wide == "back" else [0, 180, 90]
    return part("wedge", [y1 - y0, x1 - x0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, True, note)


def cylz(x, y, dia, z0, z1, ch="primary", mirror=False, note=""):
    return part("cyl_z", [dia, dia, z1 - z0], [x, y, (z0 + z1) / 2], ch, None, mirror, note)


def cyly(x, z, dia, y0, y1, ch="primary", mirror=False, note=""):
    return part("cyl_y", [dia, y1 - y0, dia], [x, (y0 + y1) / 2, z], ch, None, mirror, note)


def cylx(y, z, dia, x0, x1, ch="primary", mirror=False, note=""):
    return part("cyl_x", [x1 - x0, dia, dia], [(x0 + x1) / 2, y, z], ch, None, mirror, note)


def ball(x, y, z, dia, ch="primary", mirror=False, note=""):
    return part("ball", [dia, dia, dia], [x, y, z], ch, None, mirror, note)


def tube(p0, p1, dia, ch="primary", mirror=False, note=""):
    """A cylinder from p0 to p1 (any direction)."""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    rx = -math.degrees(math.asin(dy / length))
    ry = math.degrees(math.atan2(dx, dz))
    mid = [(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2]
    return part("cyl_z", [dia, dia, length], mid, ch, [rx, ry, 0], mirror, note)


def along(p0, p1, length):
    """The point `length` past p1 on the line p0 -> p1."""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    n = math.sqrt(dx * dx + dy * dy + dz * dz)
    return (p1[0] + dx / n * length, p1[1] + dy / n * length, p1[2] + dz / n * length)


def tip(p0, p1, dia, length=0.25, mirror=False, note="thrust glow"):
    """The glowing end of a tube that runs p0 -> p1."""
    return tube(p1, along(p0, p1, length), dia, "thrust", mirror, note)


def plate(x0, x1, yc, zc, thick, length, fall_deg, ch="glass", mirror=False, note=""):
    """A thin panel lying on a slope. fall_deg > 0 falls toward the back, < 0 rises toward the back."""
    return part("block", [x1 - x0, thick, length], [(x0 + x1) / 2, yc, zc], ch, [fall_deg, 0, 0], mirror, note)


def profile(x, pts, y0, ch="glass", note=""):
    """A solid with a faceted top along Z. pts is [(z, y), ...]; the base is flat at y0."""
    ps = []
    for (za, ya), (zb, yb) in zip(pts, pts[1:]):
        lo, hi = min(ya, yb), max(ya, yb)
        if lo - y0 > 0.06:
            ps.append(box(-x, x, y0, lo, za, zb, ch, note=note))
        if hi - lo > 0.06:
            ps.append(wedge(-x, x, max(lo, y0), hi, za, zb, "up_back" if yb > ya else "up_front", ch, note=note))
    return ps


def height_at(pts, z):
    for (za, ya), (zb, yb) in zip(pts, pts[1:]):
        if za <= z <= zb:
            return ya + (yb - ya) * (z - za) / (zb - za)
    raise ValueError(z)


# ---------------------------------------------------------------- cockpits (cabins above the beltline)
# Each cabin has its own length, height, width and place on the deck: that is what makes two cockpits look different.
def driver(z=-0.3, head_y=4.3, head_d=1.2, shoulders=True, yoke_y=3.6):
    ps = []
    if shoulders:
        ps.append(box(-3.0, -1.4, BELT, head_y - 0.5, z - 0.5, z + 0.5, "driver", note="driver shoulders; the rest sits inside the body halves"))
    ps.append(ball(-2.2, head_y, z, head_d, "driver", note="head"))
    ps.append(part("block", [1.0, 0.3, 0.12], [-2.2, yoke_y, z - 1.2], "detail", [-25, 0, 0], note="steering yoke"))
    return ps


def cab_hardtop():
    """60s pillarless hardtop: the widest and flattest cabin, centred. A thin roof with a visor floats on long raked glass."""
    top = 5.05
    ps = [
        box(-4.6, 4.6, BELT, 3.14, -5.6, 7.2, "secondary", note="chrome belt frame: sits on the cabin deck"),
        box(-4.3, 4.3, 3.14, 3.34, -5.6, -5.1, "detail", note="cowl vent"),
        wedge(-4.4, 4.4, 3.14, top, -5.2, -2.2, "up_back", "glass", note="raked windscreen"),
        box(-4.4, 4.4, 3.14, top, -2.2, 2.8, "glass", note="pillarless side glass"),
        wedge(-4.4, 4.4, 3.14, top, 2.8, 6.8, "up_front", "glass", note="long fast rear screen"),
        box(-4.65, 4.65, top, top + 0.25, -3.2, 3.6, "primary", note="thin flat roof; the front edge is a visor"),
        wedge(4.2, 4.5, 3.14, top, -5.2, -2.2, "up_back", "primary", mirror=True, note="slim A pillar"),
        wedge(3.5, 4.5, 3.14, top, 2.8, 6.8, "up_front", "primary", mirror=True, note="sail pillar"),
        box(4.4, 4.5, 3.14, top, -1.2, -1.05, "secondary", mirror=True, note="vent window post"),
        box(-4.4, 4.4, 3.14, 3.3, 6.8, 7.2, "primary", note="rear shelf"),
        box(-3.9, 3.9, 3.14, 3.5, -2.5, -1.9, "detail", note="dash"),
        box(-3.7, 3.7, 3.14, 4.0, 0.35, 0.85, "detail", note="bench seat back"),
    ]
    return ps + driver(head_y=4.2)


def cab_sled():
    """Chopped lead sled: narrow, low and set back. High shoulder, slit glass in a chrome frame, one humped turtle back to the boot."""
    x = 3.9
    sh, glass_top, roof = 4.0, 4.55, 4.9
    z_front, z_back = -3.4, 2.2
    back = [(z_back, roof), (5.4, 4.4), (CAB_Z1, BELT)]  # the turtle back: a gentle fall, then a steeper one, no step
    fall = math.degrees(math.atan2(back[1][1] - back[2][1], back[2][0] - back[1][0]))
    win_z = 6.7
    win_y = height_at(back, win_z)
    ps = [
        box(-x, x, BELT, sh, z_front, z_back, "primary", note="raised shoulder: high sill for the chopped look; sits on the cabin deck"),
        cylx(3.5, z_front, 1.0, -x, x, "primary", note="rolled cowl"),
        cylz(x - 0.35, 3.6, 0.8, z_front, z_back, "primary", mirror=True, note="rounded shoulder roll"),
        part("wedge", [x - 0.1, glass_top - sh, 1.5], [(x - 0.1) / 2, (sh + glass_top) / 2, z_front + 1.0], "glass", [0, -12, 0], mirror=True, note="split V windscreen pane"),
        box(-x + 0.05, x - 0.05, sh, sh + 0.12, z_front + 0.1, z_front + 0.5, "secondary", note="chrome windscreen sill"),
        part("block", [0.22, 1.4, 0.18], [0.0, (sh + glass_top) / 2 + 0.05, z_front + 0.9], "secondary", [66, 0, 0], note="chrome screen divider"),
        box(-x + 0.1, x - 0.1, sh, glass_top, z_front + 1.7, 1.6, "glass", note="slit side glass"),
        box(-x, x, glass_top, roof, z_front + 1.6, z_back, "primary", note="chopped roof"),
        cylx(glass_top + 0.05, z_front + 1.6, 0.5, -x - 0.02, x + 0.02, "secondary", note="chrome header: the top of the windscreen frame"),
        cylz(x - 0.3, glass_top + 0.1, 0.6, z_front + 1.6, z_back, "primary", mirror=True, note="rolled roof rail"),
        box(x - 0.25, x, sh, glass_top, z_front + 1.5, z_front + 2.0, "secondary", mirror=True, note="chrome A post"),
        box(x - 0.25, x, sh, glass_top, 1.2, 1.7, "primary", mirror=True, note="B post"),
        plate(-2.3, 2.3, win_y + 0.04, win_z, 0.08, 1.8, fall, "secondary", note="chrome rear window frame"),
        plate(-2.0, 2.0, win_y + 0.1, win_z, 0.08, 1.3, fall, "glass", note="rear window"),
    ]
    ps += profile(x, back, BELT, "primary", "turtle back: one humped line from the roof to the boot pad")
    return ps + driver(z=0.2, head_y=4.25, head_d=0.9, shoulders=False, yoke_y=4.2)


FIN_UPPER = [(-6.0, 3.15), (-4.8, 4.9), (-3.0, 5.8), (-0.8, 6.1), (1.4, 5.75), (3.2, 4.7), (4.6, 3.15)]
FIN_LOWER = [(-6.0, 3.15), (-4.8, 4.3), (-2.6, 5.0), (1.0, 5.0), (3.0, 4.2), (4.6, 3.15)]


def cab_finliner():
    """Fin-era bubble top: one glass arc from the cowl to the rear deck, set forward, held by three chrome hoops and a spine."""
    ps = [
        box(-4.1, 4.1, BELT, 3.15, -6.4, 7.6, "secondary", note="cream belt frame: sits on the cabin deck"),
        box(-3.9, 3.9, 3.15, 3.3, -6.4, -6.0, "detail", note="cowl vent"),
    ]
    ps += profile(3.9, FIN_LOWER, 3.15, "glass", "bubble canopy, lower tier")
    ps += profile(2.9, FIN_UPPER, 3.15, "glass", "bubble canopy, crown: one arc, peak at Y 6.1")
    for z in (-3.0, -0.8, 3.2):  # chrome hoops: the outline reads even with dark glass
        yu, yl = height_at(FIN_UPPER, z), height_at(FIN_LOWER, z)
        ps += [
            box(-2.98, 2.98, yu, yu + 0.14, z - 0.1, z + 0.1, "secondary", note="canopy hoop, crown bar"),
            box(2.88, 3.02, yl, yu + 0.14, z - 0.1, z + 0.1, "secondary", mirror=True, note="canopy hoop, upper leg"),
            box(2.88, 3.98, yl, yl + 0.14, z - 0.1, z + 0.1, "secondary", mirror=True, note="canopy hoop, shoulder"),
            box(3.88, 4.02, 3.15, yl + 0.14, z - 0.1, z + 0.1, "secondary", mirror=True, note="canopy hoop, lower leg"),
        ]
    for (za, ya), (zb, yb) in list(zip(FIN_UPPER, FIN_UPPER[1:]))[1:-1]:  # centre spine along the arc
        length = math.hypot(zb - za, yb - ya)
        ps.append(plate(-0.13, 0.13, (ya + yb) / 2 + 0.07, (za + zb) / 2, 0.1, length, math.degrees(math.atan2(ya - yb, zb - za)),
                        "secondary", note="canopy spine"))
    ps += [
        box(-3.9, 3.9, 3.15, 3.4, 4.6, 7.4, "primary", note="rear deck"),
        cylz(2.0, 3.9, 1.5, 4.0, 6.6, "primary", mirror=True, note="jet-age headrest fairing"),
        ball(2.0, 3.9, 6.6, 1.5, "primary", mirror=True, note="fairing tail cone"),
    ]
    return ps + driver(z=-0.6, head_y=4.3)


def cab_vip():
    """Boxy 90s saloon: the tallest cabin, upright at both ends, set back on the deck behind a long bonnet. Thick C pillar."""
    top = 6.1
    ps = [
        box(-4.6, 4.6, BELT, 3.14, -3.4, 8.2, "secondary", note="chrome belt frame: sits on the cabin deck"),
        box(-4.3, 4.3, 3.14, 3.34, -3.4, -2.9, "detail", note="cowl vent"),
        wedge(-4.4, 4.4, 3.14, top, -3.0, -1.4, "up_back", "glass", note="upright windscreen"),
        box(-4.4, 4.4, 3.14, top, -1.4, 6.2, "glass", note="six-light side glass"),
        wedge(-4.4, 4.4, 3.14, top, 6.2, 7.3, "up_front", "glass", note="formal rear screen"),
        box(-4.5, 4.5, top, top + 0.28, -1.6, 6.4, "primary", note="long boxy roof"),
        box(-1.8, 1.8, top + 0.28, top + 0.34, -0.6, 1.8, "glass", note="sunroof"),
        wedge(4.2, 4.5, 3.14, top, -3.0, -1.4, "up_back", "primary", mirror=True, note="A pillar"),
        box(4.25, 4.5, 3.14, top, 1.9, 2.4, "primary", mirror=True, note="B pillar"),
        box(4.2, 4.5, 3.14, top, 4.4, 6.2, "primary", mirror=True, note="thick C pillar"),
        wedge(4.2, 4.5, 3.14, top, 6.2, 7.3, "up_front", "primary", mirror=True, note="C pillar run-out"),
        box(4.08, 4.2, 3.4, top - 0.3, 2.8, 4.4, "secondary", mirror=True, note="privacy curtain"),
        box(-4.4, 4.4, 3.14, 3.4, 7.3, 8.2, "primary", note="rear shelf: the three-box notch"),
        box(-3.9, 3.9, 3.14, 3.5, -1.2, -0.6, "detail", note="dash"),
        box(-3.7, 3.7, 3.14, 4.2, 1.6, 2.1, "detail", note="front seat backs"),
        box(-3.7, 3.7, 3.14, 4.2, 4.6, 5.1, "detail", note="rear seat back"),
    ]
    return ps + driver(z=1.0, head_y=4.5)


def cab_kaido():
    """70s works fastback: narrow. A long fast screen, a short roof set forward, a long louvred fastback and a ducktail."""
    x = 3.7
    glass_top, roof = 5.25, 5.5
    z_roof, z_end = 0.0, 7.9
    slope = (roof - BELT) / (z_end - z_roof)
    fall = math.degrees(math.atan(slope))
    ps = [
        wedge(-x + 0.1, x - 0.1, BELT, glass_top, -6.3, -2.3, "up_back", "glass", note="long fast windscreen; sits on the cabin deck"),
        box(-x + 0.1, x - 0.1, BELT, glass_top, -2.3, z_roof, "glass", note="short side glass"),
        box(-x, x, glass_top, roof, -2.6, z_roof, "primary", note="short roof"),
        wedge(-x, x, BELT, roof, z_roof, z_end, "up_front", "primary", note="long fastback; sits on the cabin deck"),
        wedge(-x, x, BELT, 3.85, 7.2, 8.9, "up_back", "primary", note="ducktail kick-up at the foot of the fastback"),
        box(-x, x, 3.85, 3.97, 8.5, 8.94, "secondary", note="ducktail lip"),
        wedge(x - 0.3, x, BELT, glass_top, -6.3, -2.3, "up_back", "primary", mirror=True, note="A pillar"),
        box(x - 0.25, x, BELT, glass_top, -0.5, z_roof, "primary", mirror=True, note="B post"),
        box(x, x + 0.06, 3.3, 4.3, 0.4, 1.9, "glass", mirror=True, note="quarter window"),
        box(-0.7, 0.7, roof, roof + 0.06, -2.6, z_roof, "secondary", note="roof stripe"),
        cylx(4.7, -0.6, 0.25, -3.4, 3.4, "detail", note="roll bar"),
        box(1.3, 3.1, BELT, 4.2, -0.9, -0.45, "detail", mirror=True, note="bucket seat"),
        box(-3.1, 3.1, BELT, 3.3, -4.0, -3.5, "detail", note="dash"),
    ]
    for i in range(4):  # louvres over the fastback
        z = 1.5 + i * 1.4
        y = roof - (z - z_roof) * slope + 0.1
        ps.append(plate(-2.8, 2.8, y, z, 0.12, 0.75, fall - 14, "detail", note="fastback louvre slat"))
    return ps + driver(z=-1.4, head_y=4.2, head_d=1.1)


def cab_longroof():
    """Station wagon: the longest cabin. A roof runs to the tailgate, with a raised vista deck and skylight behind the driver."""
    top = 5.2
    ps = [
        box(-4.6, 4.6, BELT, 3.14, -5.6, CAB_Z1, "secondary", note="chrome belt frame: sits on the cabin deck"),
        box(-4.3, 4.3, 3.14, 3.34, -5.6, -5.2, "detail", note="cowl vent"),
        wedge(-4.4, 4.4, 3.14, top, -5.3, -2.8, "up_back", "glass", note="windscreen"),
        box(-4.4, 4.4, 3.14, top, -2.8, 8.5, "glass", note="long side glass, four lights a side"),
        box(-4.5, 4.5, top, top + 0.22, -3.0, 8.7, "primary", note="long roof, runs to the tailgate"),
        wedge(-3.1, 3.1, top + 0.22, 5.85, -0.3, 0.9, "up_back", "glass", note="vista skylight"),
        box(-3.3, 3.3, top + 0.22, 5.85, 0.9, 8.6, "primary", note="raised vista deck"),
        box(3.3, 3.38, top + 0.32, 5.75, 1.4, 8.0, "glass", mirror=True, note="vista side light"),
        box(4.05, 4.25, top + 0.22, top + 0.42, -2.2, 8.4, "secondary", mirror=True, note="chrome roof rail"),
        wedge(4.2, 4.5, 3.14, top, -5.3, -2.8, "up_back", "primary", mirror=True, note="A pillar"),
        box(4.25, 4.5, 3.14, top, 0.6, 1.0, "primary", mirror=True, note="B pillar"),
        box(4.25, 4.5, 3.14, top, 4.2, 4.6, "primary", mirror=True, note="C pillar"),
        box(4.2, 4.5, 3.14, top, 7.7, 8.5, "primary", mirror=True, note="D pillar"),
        box(-4.4, 4.4, 3.14, 4.0, 8.5, 8.94, "primary", note="tailgate"),
        box(-4.2, 4.2, 4.0, top, 8.6, 8.8, "glass", note="tailgate glass"),
        box(-0.8, 0.8, 3.5, 3.66, 8.94, 9.0, "secondary", note="tailgate handle"),
        box(-3.9, 3.9, 3.14, 3.5, -2.8, -2.2, "detail", note="dash"),
        box(-3.7, 3.7, 3.14, 4.1, 0.4, 0.9, "detail", note="front bench"),
        box(-3.7, 3.7, 3.14, 4.1, 4.2, 4.7, "detail", note="second bench"),
    ]
    return ps + driver(head_y=4.25)


# ---------------------------------------------------------------- shared body-half pieces
def slab(z0, z1, style):
    """The body side section of one culture, between z0 and z1. Top is always the flat deck at the beltline."""
    if style == "round":      # Lead Sled, Surf Wagon: rolled shoulders
        return [
            box(-BODY_X, BODY_X, SILL, 2.6, z0, z1, "primary", note="body slab: flat flank, flat belly"),
            box(-4.3, 4.3, 2.6, BELT, z0, z1, "primary", note="flat deck at the beltline"),
            cylz(4.3, 2.6, 0.8, z0, z1, "primary", mirror=True, note="rolled shoulder"),
        ]
    if style == "chamfer":    # VIP: crisp chamfered shoulders
        return [
            box(-BODY_X, BODY_X, SILL, 2.65, z0, z1, "primary", note="body slab: flat flank, flat belly"),
            box(-4.45, 4.45, 2.65, BELT, z0, z1, "primary", note="flat deck at the beltline"),
            chamfer(4.45, BODY_X, 2.65, BELT, z0, z1, "primary", note="chamfered shoulder"),
        ]
    ps = [box(-BODY_X, BODY_X, SILL, BELT, z0, z1, "primary", note="body slab: flat deck at the beltline, flat flank, flat belly")]
    if style == "crease":     # Lowrider: one crisp crease
        ps.append(box(BODY_X, 4.78, 1.95, 2.1, z0, z1, "primary", mirror=True, note="body crease"))
    if style == "stripe":     # Kaido: works stripe along the sill
        ps.append(box(BODY_X, 4.77, 0.55, 0.95, z0, z1, "secondary", mirror=True, note="works stripe"))
    return ps


def front_core(style):
    """The part of every front half that never changes: the mid-seam collar and the slab under the pads."""
    return [box(-4.4, 4.4, 0.3, 2.9, -0.2, MID, "detail", note="mid-seam collar: fills the shadow gap to the rear half")] + slab(PAD_F, -0.2, style)


def rear_core(style):
    """The part of every rear half that never changes: the mid-seam collar and the slab under the pads."""
    return [box(-4.4, 4.4, 0.3, 2.9, MID, 0.2, "detail", note="mid-seam collar: fills the shadow gap to the front half")] + slab(0.2, PAD_R, style)


def nose_face(z_back, x=4.5):
    """Seam face: every front half is solid from the sill to the bar line right up to the Front Chrome seam."""
    return [
        box(-x, x, SILL, BAR, FACE_F, z_back, "primary", note="seam face: solid from sill to bar line, the front chrome sits against it"),
        box(2.5, 3.5, 0.4, 1.0, NOSE + 0.04, FACE_F, "detail", mirror=True, note="bumper pad: Front Chrome brackets land here"),
    ]


def tail_face(z_front, x=4.5):
    """Seam face: every rear half is solid from the sill to the bar line right up to the Rear Chrome seam."""
    return [
        box(-x, x, SILL, BAR, z_front, FACE_R, "primary", note="seam face: solid from sill to bar line, the rear chrome sits against it"),
        box(2.5, 3.5, 0.4, 1.0, FACE_R, TAIL - 0.04, "detail", mirror=True, note="bumper pad: Rear Chrome brackets land here"),
    ]


def arch_blank(z0, z1, y1=1.9, slats=2, slat_ch="secondary"):
    """A blanked, vented arch: where the wheel arch would be on a road car."""
    ps = [box(4.6, 4.76, 0.3, y1, z0, z1, "detail", mirror=True, note="blanked arch: vent panel where a wheel arch would be")]
    for i in range(slats):
        y = 0.3 + (y1 - 0.3) * (i + 1) / (slats + 1)
        ps.append(box(4.6, 4.8, y - 0.07, y + 0.07, z0 + 0.3, z1 - 0.3, slat_ch, mirror=True, note="arch vent slat"))
    return ps


# ---------------------------------------------------------------- FrontBody: front halves
def fb_boulevard():
    """Lowrider: the longest, squarest nose. Flat bonnet, full-width grille, quad lamps under a leading brow."""
    ps = front_core("crease") + slab(-16.0, PAD_F, "crease") + nose_face(-16.0)
    ps += [
        box(3.5, 4.7, BELT, 3.35, -16.36, -6.6, "primary", mirror=True, note="fender blade, leads over the lamps"),
        box(3.95, 4.25, 3.35, 3.6, -15.8, -14.2, "secondary", mirror=True, note="fender wind-split"),
        box(-4.5, 4.5, BAR, 2.7, -16.2, -16.0, "detail", note="full-width grille"),
        box(-1.9, 1.9, 1.62, 1.8, -16.32, -16.2, "secondary", note="grille bar"),
        box(-1.9, 1.9, 2.2, 2.38, -16.32, -16.2, "secondary", note="grille bar"),
        cylz(2.75, 2.05, 1.0, -16.38, -16.2, "neon", mirror=True, note="inner headlamp"),
        cylz(3.9, 2.05, 1.0, -16.38, -16.2, "neon", mirror=True, note="outer headlamp"),
        box(-4.7, 4.7, 2.72, BELT, -16.36, -16.0, "primary", note="brow over the grille"),
    ]
    return ps + arch_blank(-12.4, -8.4, 1.8, 2)


def fb_pontoon():
    """Lead Sled: a low drooping centre nose between two fat round pontoon fenders that fall to frenched lamps."""
    ps = front_core("round")
    ps += [
        box(-2.6, 2.6, SILL, 1.6, -16.0, PAD_F, "primary", note="low centre nose"),
        wedge(-2.6, 2.6, 1.6, BELT, -16.0, PAD_F, "up_back", "primary", note="long drooping bonnet tip, ahead of the bonnet pad"),
        cylz(3.55, 1.6, 2.8, -14.3, PAD_F, "primary", mirror=True, note="fat pontoon fender, bulges past the flank"),
        ball(3.55, 1.6, -14.3, 2.8, "primary", mirror=True, note="pontoon shoulder, falls away"),
        ball(3.55, 1.25, -15.2, 2.1, "primary", mirror=True, note="drooping pontoon nose"),
        cylz(3.55, 1.25, 1.3, -16.3, -15.6, "detail", mirror=True, note="frenched lamp tunnel"),
        cylz(3.55, 1.25, 0.9, -16.39, -16.3, "neon", mirror=True, note="sunken headlamp"),
        tube((4.05, 3.02, -13.6), (4.05, 2.45, -7.2), 1.0, "primary", mirror=True, note="fade-away fender crown: highest at the nose, sinks into the deck"),
        ball(4.05, 3.02, -13.6, 1.0, "primary", mirror=True, note="crown nose"),
        cylx(0.8, -15.7, 1.2, -4.5, 4.5, "primary", note="seam face: a rolled pan from sill to bar line, the front chrome sits against it"),
        box(2.5, 3.5, 0.4, 1.0, NOSE + 0.04, FACE_F, "detail", mirror=True, note="bumper pad: Front Chrome brackets land here"),
        box(-2.0, 2.0, 1.45, 2.0, -16.15, -16.0, "detail", note="low mouth grille"),
        cyly(0.0, -16.2, 0.3, 1.45, 2.0, "secondary", note="grille tooth"),
        cyly(1.0, -16.2, 0.3, 1.45, 2.0, "secondary", mirror=True, note="grille tooth"),
        box(4.6, 4.78, 1.05, 1.3, -11.8, -8.8, "detail", mirror=True, note="blanked arch: one shaved vent slit"),
    ]
    return ps


def fb_jetliner():
    """Fin Era: twin jet-nacelle fenders lead, a V grille sits back between them, tall gunsight blades on top."""
    ps = front_core("slab") + nose_face(PAD_F)
    ps += [
        box(-2.9, 2.9, BAR, BELT, -14.9, PAD_F, "primary", note="centre nose, set back between the nacelles"),
        part("block", [2.9, 1.3, 0.3], [1.47, 2.05, -15.12], "detail", [0, -9, 0], mirror=True, note="V grille half"),
        box(-0.25, 0.25, BAR, 2.95, -15.8, -14.9, "secondary", note="centre prow bar"),
        box(-2.9, 2.9, 2.7, BELT, -15.45, -14.9, "primary", note="brow"),
        box(2.9, 4.7, SILL, 1.75, -15.9, PAD_F, "primary", mirror=True, note="nacelle keel: lower fender"),
        cylz(3.95, 1.75, 2.5, -16.1, PAD_F, "primary", mirror=True, note="jet-nacelle fender, bulges past the flank"),
        box(3.25, 4.65, 0.85, 2.65, -16.22, -16.1, "detail", mirror=True, note="lamp bezel in the nacelle mouth"),
        cylz(3.95, 2.2, 0.8, -16.34, -16.22, "neon", mirror=True, note="stacked headlamp"),
        cylz(3.95, 1.3, 0.8, -16.34, -16.22, "neon", mirror=True, note="stacked headlamp"),
        wedge(3.75, 4.25, BELT, 3.95, -15.5, -7.0, "up_front", "primary", mirror=True, note="gunsight fender blade, tall at the front"),
        cylz(4.0, 3.7, 0.5, -15.5, -13.8, "secondary", mirror=True, note="fender jet ornament"),
        ball(4.0, 3.7, -15.5, 0.5, "secondary", mirror=True, note="ornament nose"),
        box(BODY_X, 4.8, 1.85, 2.1, -12.5, -0.3, "secondary", mirror=True, note="side spear in the accent colour, feeds the rear cove"),
    ]
    return ps + arch_blank(-12.4, -8.8, 1.6, 1)


def fb_formal():
    """VIP: short, square and upright. A tall chrome grille shell stands proud; square blisters and marker towers at the corners."""
    ps = front_core("chamfer") + slab(-15.6, PAD_F, "chamfer") + nose_face(-15.6)
    ps += [
        box(-1.9, 1.9, BAR, 3.8, -16.3, -15.6, "secondary", note="upright chrome grille shell, stands proud of the bonnet"),
        box(-1.6, 1.6, 1.55, 3.55, -16.38, -16.3, "detail", note="grille mesh"),
        box(-0.1, 0.1, 3.8, 4.0, -16.0, -15.8, "secondary", note="mascot"),
        box(2.1, 3.1, 1.85, 2.5, -15.8, -15.6, "neon", mirror=True, note="inner square lamp"),
        box(3.3, 4.4, 1.85, 2.5, -15.8, -15.6, "neon", mirror=True, note="outer square lamp"),
        box(1.9, 4.6, 1.7, 2.62, -15.72, -15.6, "detail", mirror=True, note="lamp surround"),
        box(3.95, 4.3, BELT, 3.12, -14.2, -6.6, "secondary", mirror=True, note="fender-top chrome strip"),
        box(3.8, 4.45, BELT, 3.55, -15.55, -14.2, "primary", mirror=True, note="fender-top marker tower"),
        box(3.95, 4.3, 3.15, 3.42, -15.62, -15.55, "neon", mirror=True, note="marker lamp"),
        box(BODY_X, 5.15, 0.3, 2.2, -15.4, -12.7, "primary", mirror=True, note="square blistered corner"),
        chamfer(BODY_X, 5.15, 2.2, 2.6, -15.4, -12.7, "primary", note="blister shoulder"),
        box(5.15, 5.2, 1.2, 1.34, -15.4, -12.7, "secondary", mirror=True, note="blister chrome"),
    ]
    return ps + arch_blank(-12.4, -9.2, 2.2, 3, "detail")


def fb_shark():
    """Kaido: an undercut shark prow over a solid lower jaw. The top edge leads and the face rakes back to the bar line."""
    z_cut = -14.6
    ps = front_core("stripe") + slab(z_cut, PAD_F, "stripe") + nose_face(z_cut)
    run, drop = z_cut - (-16.3), BELT - BAR
    slope = math.degrees(math.atan2(run, drop))  # undercut face, from vertical
    ps += [
        wedge(-4.7, 4.7, BAR, BELT, -16.3, z_cut, "under_front", "primary", note="undercut shark prow: top edge leads"),
        box(4.1, 4.25, BELT, 3.5, -11.2, -11.05, "detail", mirror=True, note="fender mirror stalk"),
        box(3.9, 4.45, 3.5, 3.8, -11.3, -10.95, "primary", mirror=True, note="fender mirror"),
        box(3.6, 4.2, BELT, 3.06, -14.2, -6.7, "secondary", mirror=True, note="works stripe along the fender top"),
        box(-3.4, 3.4, 0.55, 1.05, -16.36, FACE_F, "detail", note="jaw intake slot"),
    ]
    for x0, x1, ch, mir, note in ((1.9, 4.1, "neon", True, "slit headlamp on the raked face"), (-1.5, 1.5, "detail", False, "grille slot")):
        yc = 2.3
        zc = -16.3 + (BELT - yc) * (run / drop)
        ps.append(part("block", [x1 - x0, 0.5, 0.12], [(x0 + x1) / 2, yc - 0.03, zc - 0.04], ch, [-slope, 0, 0], mirror=mir, note=note))
    return ps + arch_blank(-12.4, -8.7, 1.6, 0)


def fb_bullnose():
    """Surf Wagon: a tall narrow centre prow with a waterfall grille leads; low round fenders sit back either side."""
    ps = front_core("round") + nose_face(PAD_F)
    ps += [
        box(-1.9, 1.9, BAR, BELT, -16.2, PAD_F, "primary", note="tall centre prow, leads the fenders"),
        box(-1.5, 1.5, 1.5, 2.85, -16.34, -16.2, "secondary", note="waterfall grille"),
        box(-0.12, 0.12, BELT, 3.5, -16.2, -15.7, "secondary", note="bonnet mascot"),
        box(1.9, 4.7, BAR, 2.0, -15.0, PAD_F, "primary", mirror=True, note="low fender, set back from the prow"),
        cylz(3.7, 2.0, 2.0, -15.0, PAD_F, "primary", mirror=True, note="round fender crown: touches the deck line, falls away either side"),
        ball(3.7, 2.0, -15.0, 2.0, "primary", mirror=True, note="fender nose"),
        cylz(3.7, 2.0, 1.2, -16.05, -15.5, "detail", mirror=True, note="lamp bucket"),
        cylz(3.7, 2.0, 0.85, -16.18, -16.05, "neon", mirror=True, note="single round headlamp"),
        cylz(4.05, 3.0, 0.8, -12.4, -6.8, "primary", mirror=True, note="fender crown runs back along the bonnet"),
    ]
    for x in (-0.9, -0.3, 0.3, 0.9):
        ps.append(box(x - 0.08, x + 0.08, 1.6, 2.75, -16.4, -16.34, "detail", note="grille slot"))
    return ps + arch_blank(-12.2, -8.6, 1.5, 1)


# ---------------------------------------------------------------- RearBody: rear halves
def rb_long_deck():
    """Lowrider: the longest, flattest tail. A square deck lip overhangs a recessed cove with three round lamps a side."""
    ps = rear_core("crease") + slab(PAD_R, 15.0, "crease") + tail_face(15.0)
    ps += [
        box(-4.7, 4.7, 2.6, BELT, 15.0, 15.45, "primary", note="overhanging deck lip"),
        box(-4.5, 4.5, BAR, 2.6, 15.0, 15.08, "secondary", note="recessed tail cove in the accent colour"),
        box(-1.0, 1.0, 1.7, 2.3, 15.08, 15.14, "detail", note="plate recess"),
    ]
    for x in (2.2, 3.1, 4.0):
        ps.append(cylz(x, 2.0, 0.64, 15.08, 15.3, "neon", mirror=True, note="round tail lamp, three a side"))
    return ps + arch_blank(8.4, 12.4, 1.8, 2)


def rb_turtle():
    """Lead Sled: the whole tail droops. A turtle deck falls between two fat fenders that end in low bullet lamps."""
    ps = rear_core("round")
    ps += [
        box(-3.3, 3.3, SILL, 1.5, PAD_R, 15.2, "primary", note="low centre tail"),
        wedge(-3.3, 3.3, 1.5, BELT, PAD_R, 14.9, "up_front", "primary", note="drooping turtle deck, behind the boot pad"),
        ball(3.6, 1.6, 12.9, 2.8, "primary", mirror=True, note="fat rear fender shoulder: bulges past the flank, then falls away"),
        ball(3.6, 1.35, 13.9, 2.3, "primary", mirror=True, note="fender droop"),
        ball(3.6, 1.15, 14.55, 1.8, "primary", mirror=True, note="drooping bullet fender end"),
        cylz(3.6, 1.2, 0.8, 15.3, 15.48, "neon", mirror=True, note="frenched bullet tail lamp"),
        cylx(0.8, 14.8, 1.2, -4.5, 4.5, "primary", note="seam face: a rolled pan from sill to bar line, the rear chrome sits against it"),
        box(2.5, 3.5, 0.4, 1.0, FACE_R, TAIL - 0.04, "detail", mirror=True, note="bumper pad: Rear Chrome brackets land here"),
        box(4.6, 4.78, 1.05, 1.3, 8.6, 12.2, "detail", mirror=True, note="blanked arch: one shaved vent slit"),
    ]
    return ps


def rb_jet_tail():
    """Fin Era: two short jet-tube fenders with afterburner lamps, the centre tail set well back between them over a solid shelf."""
    ps = rear_core("slab") + tail_face(PAD_R)
    ps += [
        box(-3.0, 3.0, BAR, BELT, PAD_R, 13.7, "primary", note="centre tail, set back between the jet tubes"),
        box(-2.9, 2.9, 1.55, 2.4, 13.7, 13.85, "detail", note="tail grille"),
        box(-2.9, 2.9, 1.92, 2.04, 13.85, 13.95, "secondary", note="tail chrome strip"),
        box(-3.0, 3.0, 2.7, BELT, 13.7, 14.1, "primary", note="brow"),
        box(2.9, 4.7, BAR, 1.75, PAD_R, 14.0, "primary", mirror=True, note="tube keel: lower fender"),
        cylz(4.0, 1.75, 2.5, PAD_R, 14.2, "primary", mirror=True, note="jet-tube rear fender, bulges past the flank"),
        cylz(4.0, 1.75, 1.7, 14.2, 14.62, "detail", mirror=True, note="tube nozzle"),
        cylz(4.0, 1.75, 1.1, 14.62, 14.76, "neon", mirror=True, note="afterburner tail lamp"),
        box(BODY_X, 4.8, 0.9, 2.1, 0.3, 12.5, "secondary", mirror=True, note="side cove panel in the accent colour"),
    ]
    return ps + arch_blank(8.4, 12.4, 0.8, 0)


def rb_formal_trunk():
    """VIP: a short formal boot. A centre hump stays at the beltline, the shoulders step down, the tail face slopes to a bumper shelf."""
    sh = 2.4
    z_top, z_low = 13.9, 15.2
    fall = math.degrees(math.atan2(sh - BAR, z_low - z_top))
    ps = rear_core("chamfer") + tail_face(PAD_R, BODY_X)
    ps += [
        box(-BODY_X, BODY_X, BAR, sh, PAD_R, z_top, "primary", note="boot shoulders, stepped down from the deck"),
        box(-3.3, 3.3, sh, BELT, PAD_R, z_top, "primary", note="boot hump: stays at the beltline"),
        wedge(-BODY_X, BODY_X, BAR, sh, z_top, z_low, "up_front", "primary", note="sloped tail face"),
        wedge(-3.3, 3.3, sh, BELT, z_top, z_top + 0.75, "up_front", "primary", note="hump run-out"),
        plate(-4.4, 4.4, (sh + BAR) / 2 + 0.1, (z_top + z_low) / 2 + 0.06, 0.1, 0.6, fall, "neon", note="full-width light bar on the sloped face"),
        box(-4.6, 4.6, BAR, BAR + 0.12, z_low, FACE_R, "secondary", note="chrome strip on the bumper shelf"),
        box(-1.2, 1.2, 0.5, 1.1, FACE_R, FACE_R + 0.06, "detail", note="plate recess"),
        box(BODY_X, 5.15, 0.3, 2.0, 12.7, 15.2, "primary", mirror=True, note="square blistered corner"),
        chamfer(BODY_X, 5.15, 2.0, 2.4, 12.7, 15.2, "primary", note="blister shoulder"),
        box(5.15, 5.2, 1.2, 1.34, 12.7, 15.2, "secondary", mirror=True, note="blister chrome"),
    ]
    return ps + arch_blank(8.6, 12.2, 2.2, 3, "detail")


def rb_works_tail():
    """Kaido: a bobbed kamm tail. The deck dips then kicks up in a ducktail; a diffuser tunnel is cut up between two solid keels."""
    z_end = 14.6
    ps = rear_core("stripe")
    ps += [
        box(-BODY_X, BODY_X, BAR, 2.4, PAD_R, z_end, "primary", note="bobbed tail upper"),
        wedge(-BODY_X, BODY_X, 2.4, BELT, PAD_R, 13.5, "up_front", "primary", note="deck dip behind the boot pad"),
        wedge(-BODY_X, BODY_X, 2.4, BELT, 13.5, z_end, "up_back", "primary", note="ducktail kick-up"),
        box(-BODY_X, BODY_X, BELT - 0.14, BELT, z_end - 0.1, z_end + 0.16, "secondary", note="ducktail lip"),
        box(2.2, BODY_X, SILL, BAR, PAD_R, FACE_R, "primary", mirror=True, note="seam face: solid keel from sill to bar line, the rear chrome sits against it"),
        box(2.5, 3.5, 0.4, 1.0, FACE_R, TAIL - 0.04, "detail", mirror=True, note="bumper pad: Rear Chrome brackets land here"),
        wedge(-2.2, 2.2, SILL, BAR, PAD_R, z_end, "under_back", "detail", note="diffuser tunnel: cut up between the keels"),
        box(-0.08, 0.08, 0.3, BAR, 13.4, FACE_R, "detail", note="tunnel strake"),
        box(1.0, 1.16, 0.3, BAR, 13.4, FACE_R, "detail", mirror=True, note="tunnel strake"),
        box(BODY_X, 4.77, 0.55, 0.95, PAD_R, 14.4, "secondary", mirror=True, note="works stripe run-out"),
        box(-4.4, 4.4, 1.5, 2.3, z_end, z_end + 0.12, "detail", note="recessed tail panel"),
        cylz(2.2, 1.9, 0.8, z_end + 0.12, z_end + 0.35, "neon", mirror=True, note="inner round lamp"),
        cylz(3.5, 1.9, 0.8, z_end + 0.12, z_end + 0.35, "neon", mirror=True, note="outer round lamp"),
    ]
    return ps + arch_blank(8.4, 12.4, 1.6, 0)


def rb_barrel_back():
    """Surf Wagon: a barrel back. The tail tucks in on plan and rolls over in one curve from the deck to the bar line."""
    xt = 4.1
    ps = rear_core("round") + tail_face(PAD_R, xt)
    ps += [
        box(-xt, xt, BAR, BELT, PAD_R, 14.2, "primary", note="tail upper, tucked in"),
        flare(xt, BODY_X, SILL, BELT, PAD_R, 14.2, "primary", "front", note="plan taper: the flank tucks in behind the boot pad"),
        cylx(1.8, 14.2, 2.4, -xt, xt, "primary", note="barrel roll: one curve from the deck to the tail face"),
        box(-xt, xt, SILL, 1.8, 14.2, FACE_R, "primary", note="lower tail"),
        box(3.2, 3.9, 0.9, 2.3, 15.3, 15.46, "neon", mirror=True, note="tall tail lamp"),
        box(3.1, 4.0, 0.8, 2.4, 15.24, 15.3, "detail", mirror=True, note="lamp surround"),
        box(-2.6, 2.6, 1.55, 1.67, FACE_R, 15.46, "secondary", note="tailgate strip"),
        box(4.6, 4.78, 1.0, 1.3, 8.6, 12.2, "detail", mirror=True, note="blanked arch: vent slit"),
    ]
    return ps


# ---------------------------------------------------------------- Engine1: bonnet turbines (nozzles turn out or up)
def e1_quad_stacks():
    ps = [
        box(-1.9, 1.9, BELT, 3.2, -12.4, -7.6, "detail", note="plinth on the bonnet pad"),
        box(-1.6, 1.6, 3.2, 3.75, -12.1, -7.9, "secondary", note="plenum body"),
    ]
    for z in (-11.1, -8.9):
        ps += [
            cyly(0.75, z, 0.9, 3.75, 4.7, "secondary", mirror=True, note="intake stack"),
            cyly(0.75, z, 1.15, 4.7, 4.95, "detail", mirror=True, note="intake mouth"),
            cylx(3.5, z, 0.7, 1.6, 2.6, "detail", mirror=True, note="side nozzle"),
            cylx(3.5, z, 0.55, 2.6, 2.85, "thrust", mirror=True, note="thrust glow"),
        ]
    return ps


def e1_torpedo():
    n0, n1 = (0.3, 4.05, -9.4), (2.1, 4.3, -8.0)
    return [
        box(-0.7, 0.7, BELT, 3.3, -12.4, -9.4, "detail", note="saddle on the bonnet pad"),
        cylz(0.0, 4.05, 1.7, -13.6, -9.8, "primary", note="single long turbine body, nose overhangs the pad"),
        cylz(0.0, 4.05, 1.75, -14.5, -13.6, "secondary", note="chrome intake lip"),
        cylz(0.0, 4.05, 1.35, -14.62, -14.5, "detail", note="intake"),
        ball(0.0, 4.05, -14.6, 0.9, "secondary", note="intake spike"),
        box(-0.12, 0.12, 4.86, 4.96, -13.4, -10.0, "secondary", note="spine strip"),
        cylz(0.0, 4.05, 1.3, -9.8, -9.1, "detail", note="tail cone"),
        tube(n0, n1, 0.9, "detail", mirror=True, note="split nozzle, swept out and up: clears the windscreen"),
        tip(n0, n1, 0.75, 0.25, mirror=True),
    ]


def e1_twin_bullets():
    n0, n1 = (1.65, 3.95, -9.9), (2.5, 4.2, -8.7)
    return [
        box(1.3, 2.0, BELT, 3.3, -12.4, -9.4, "detail", mirror=True, note="pylon on the bonnet pad"),
        cylz(1.65, 3.95, 1.3, -13.2, -9.7, "primary", mirror=True, note="slim nacelle"),
        cylz(1.65, 3.95, 1.35, -13.9, -13.2, "detail", mirror=True, note="intake band"),
        ball(1.65, 3.95, -13.9, 1.2, "secondary", mirror=True, note="bullet nose"),
        tube(n0, n1, 1.0, "detail", mirror=True, note="nozzle, turned out past the screen pillar"),
        tip(n0, n1, 0.8, 0.25, mirror=True),
        box(1.55, 1.75, 4.6, 4.68, -13.0, -10.0, "secondary", mirror=True, note="chrome spear"),
        box(-1.3, 1.3, 3.05, 3.2, -11.2, -10.6, "detail", note="cross brace"),
    ]


def e1_slot_plenum():
    ps = [
        box(-2.4, 2.4, BELT, 3.1, -12.2, -8.0, "detail", note="shadow base on the bonnet pad"),
        box(-2.5, 2.5, 3.1, 4.6, -12.2, -8.0, "secondary", note="tall plenum box"),
        box(-2.5, 2.5, 3.5, 4.4, -12.42, -12.2, "detail", note="intake mouth, 5 wide"),
        box(-2.65, 2.65, 4.4, 4.56, -12.56, -12.2, "secondary", note="intake lip"),
        box(-2.65, 2.65, 3.34, 3.5, -12.56, -12.2, "secondary", note="intake sill"),
        box(2.5, 3.0, 3.45, 4.2, -11.5, -8.5, "detail", mirror=True, note="side-exit slot nozzle: fires out, not at the screen"),
        box(3.0, 3.2, 3.6, 4.05, -11.3, -8.7, "thrust", mirror=True, note="thrust glow"),
        box(-2.0, 2.0, 4.6, 4.74, -11.6, -8.6, "detail", note="lid"),
    ]
    for x in (-1.5, -0.5, 0.5, 1.5):
        ps.append(box(x - 0.09, x + 0.09, 3.5, 4.4, -12.52, -12.42, "secondary", note="intake vane"))
    return ps


def e1_works_turbo():
    m0, m1 = (1.5, 4.0, -9.8), (2.55, 4.4, -8.6)
    return [
        box(-2.6, -0.4, 3.4, 4.3, -12.4, -11.9, "detail", note="external cooler core"),
        box(-2.75, -0.25, 3.3, 3.4, -12.45, -11.85, "secondary", note="cooler frame"),
        box(-2.75, -0.25, 4.3, 4.4, -12.45, -11.85, "secondary", note="cooler frame"),
        box(-2.4, -2.2, BELT, 3.3, -12.3, -12.0, "detail", note="cooler stay on the bonnet pad"),
        box(-0.8, -0.6, BELT, 3.3, -12.3, -12.0, "detail", note="cooler stay on the bonnet pad"),
        box(0.6, 2.4, BELT, 3.25, -12.0, -9.2, "detail", note="turbine plinth on the bonnet pad"),
        cylz(1.5, 4.0, 1.5, -11.8, -9.6, "secondary", note="offset turbine"),
        cylz(1.5, 4.0, 1.7, -12.7, -11.8, "detail", note="intake trumpet"),
        tube(m0, m1, 0.9, "secondary", note="megaphone, swept out over the fender"),
        tip(m0, m1, 0.75, 0.22),
        tube((-0.4, 3.85, -12.15), (0.85, 3.9, -11.2), 0.3, "secondary", note="braided hose"),
        tube((-1.5, 3.55, -11.9), (0.8, 3.5, -10.0), 0.3, "secondary", note="braided hose"),
    ]


def e1_scoop_zoomies():
    ps = [
        box(-1.5, 1.5, BELT, 3.2, -12.2, -8.4, "detail", note="plinth on the bonnet pad"),
        cylz(0.0, 3.95, 1.5, -11.8, -8.6, "secondary", note="short fat turbine"),
        box(-0.95, 0.95, 4.1, 4.95, -12.6, -9.8, "primary", note="tall ram scoop"),
        box(-0.8, 0.8, 4.2, 4.85, -12.7, -12.6, "detail", note="scoop mouth"),
        box(-1.0, 1.0, 4.85, 4.98, -12.74, -12.3, "secondary", note="scoop lip"),
    ]
    for z in (-11.0, -10.0, -9.0):
        p0, p1 = (0.6, 3.85, z), (2.5, 4.55, z + 0.5)
        ps.append(tube(p0, p1, 0.5, "secondary", mirror=True, note="zoomie pipe, fires up and out"))
        ps.append(tip(p0, p1, 0.4, 0.2, mirror=True))
    return ps


# ---------------------------------------------------------------- Engine2: boot turbines (intakes start at Z 10.2)
def e2_tri_power():
    return [
        box(-2.9, 2.9, BELT, 3.25, 10.4, PAD_R, "detail", note="cradle on the boot pad"),
        cylz(0.0, 3.95, 1.4, 10.6, 15.6, "secondary", note="centre can, longest"),
        cylz(1.8, 3.9, 1.3, 11.3, 15.0, "secondary", mirror=True, note="side can"),
        cylz(0.0, 3.95, 1.1, 10.3, 10.6, "detail", note="intake"),
        cylz(1.8, 3.9, 1.0, 11.0, 11.3, "detail", mirror=True, note="intake"),
        cylz(0.0, 3.95, 1.1, 15.6, 16.5, "detail", note="nozzle"),
        cylz(0.0, 3.95, 0.9, 16.5, 16.75, "thrust", note="thrust glow"),
        cylz(1.8, 3.9, 1.0, 15.0, 15.8, "detail", mirror=True, note="nozzle"),
        cylz(1.8, 3.9, 0.8, 15.8, 16.05, "thrust", mirror=True, note="thrust glow"),
    ]


def e2_deck_ramp():
    """A ramp that climbs to the tail: twin ram scoops stand on it, a tall nozzle box ends it. Chrome and dark, not paint."""
    return [
        box(-2.6, 2.6, BELT, 3.1, 10.3, PAD_R, "detail", note="shadow base on the boot pad"),
        wedge(-2.8, 2.8, 3.1, 4.5, 10.3, 14.6, "up_back", "secondary", note="ramp body: climbs to the tail"),
        box(0.5, 2.3, 3.2, 4.5, 11.5, 14.0, "secondary", mirror=True, note="ram scoop standing on the ramp"),
        box(0.62, 2.18, 3.62, 4.38, 11.38, 11.5, "detail", mirror=True, note="scoop mouth"),
        box(-3.0, 3.0, 3.3, 4.9, 14.6, 16.0, "detail", note="tall rear nozzle box"),
        box(-3.05, 3.05, 4.9, 5.02, 14.5, 16.06, "secondary", note="nozzle hood"),
        box(0.35, 2.6, 3.7, 4.5, 16.0, 16.25, "thrust", mirror=True, note="thrust glow"),
    ]


def e2_fin_rockets():
    return [
        box(2.2, 3.0, BELT, 3.25, 10.8, PAD_R, "detail", mirror=True, note="pylon on the boot pad"),
        cylz(2.6, 4.0, 1.5, 11.4, 14.8, "primary", mirror=True, note="long rocket nacelle"),
        cylz(2.6, 4.0, 1.55, 10.9, 11.5, "detail", mirror=True, note="intake band"),
        ball(2.6, 4.0, 10.9, 1.35, "secondary", mirror=True, note="bullet nose"),
        cylz(2.6, 4.0, 1.2, 14.8, 16.0, "detail", mirror=True, note="nozzle"),
        cylz(2.6, 4.0, 1.0, 16.0, 16.3, "thrust", mirror=True, note="thrust glow"),
        ball(2.6, 4.0, 16.35, 0.6, "neon", mirror=True, note="bullet lamp in the nozzle"),
        box(2.5, 2.7, 4.75, 4.83, 11.6, 14.6, "secondary", mirror=True, note="chrome spear"),
    ]


def e2_boot_turbine():
    return [
        box(-1.6, 1.6, BELT, 3.5, 10.6, PAD_R, "primary", note="saddle fairing on the boot pad"),
        cylz(0.0, 4.2, 2.2, 10.6, 15.2, "primary", note="single big turbine"),
        cylz(0.0, 4.2, 2.3, 10.6, 11.9, "secondary", note="shroud collar"),
        cylz(0.0, 4.2, 1.75, 10.3, 10.6, "detail", note="intake face"),
        ball(0.0, 4.2, 10.3, 0.9, "secondary", note="spinner"),
        box(1.25, 2.0, 3.7, 4.5, 10.9, 13.2, "secondary", mirror=True, note="side scoop: breathes clear of the cabin"),
        box(1.33, 1.92, 3.78, 4.42, 10.8, 10.9, "detail", mirror=True, note="scoop mouth"),
        cylz(0.0, 4.2, 1.7, 15.2, 16.4, "detail", note="nozzle"),
        cylz(0.0, 4.2, 1.4, 16.4, 16.7, "thrust", note="thrust glow"),
    ]


def e2_quad_megaphones():
    ps = [
        box(-2.8, 2.8, BELT, 3.7, 10.3, 11.5, "detail", note="manifold on the boot pad"),
        tube((1.2, 3.7, 11.0), (1.2, 4.45, 10.65), 0.8, "secondary", mirror=True, note="intake trumpet"),
        box(-2.9, 2.9, BELT, 3.3, 12.1, 12.5, "detail", note="megaphone brace on the boot pad"),
    ]
    for x0, x1 in ((0.7, 0.9), (2.0, 2.55)):
        p0, p1 = (x0, 3.5, 11.5), (x1, 4.5, 15.3)
        q = along(p0, p1, 0.9)
        ps.append(tube(p0, p1, 0.7, "secondary", mirror=True, note="megaphone pipe, raked up"))
        ps.append(tube(p1, q, 1.05, "secondary", mirror=True, note="megaphone flare"))
        ps.append(tip(p1, q, 0.85, 0.25, mirror=True))
    return ps


def e2_fishtail():
    return [
        box(-1.6, 1.6, BELT, 3.2, 10.4, PAD_R, "detail", note="plinth on the boot pad"),
        box(-0.7, 0.7, 3.2, 5.1, 10.4, 11.6, "secondary", note="snorkel intake: stands up into clear air"),
        box(-0.55, 0.55, 4.25, 5.0, 10.3, 10.4, "detail", note="snorkel mouth"),
        box(-0.85, 0.85, 5.1, 5.25, 10.26, 11.7, "primary", note="snorkel cap"),
        cylz(0.0, 4.0, 1.5, 11.6, 13.6, "secondary", note="turbine body"),
        box(-1.0, 1.0, 3.5, 4.4, 13.6, 15.6, "detail", note="fishtail duct, centre"),
        flare(1.0, 3.2, 3.5, 4.4, 13.6, 15.6, "detail", "back", note="fishtail duct: fans out to the tail"),
        box(-3.3, 3.3, 3.42, 4.48, 15.6, 16.0, "secondary", note="nozzle lip"),
        box(-3.1, 3.1, 3.65, 4.25, 16.0, 16.25, "thrust", note="thrust glow"),
    ]


# ---------------------------------------------------------------- Stabilisers: sill jets
def st_hop_jets():
    """One long chrome lift nozzle per corner: a trough with a forward scoop and a glowing thrust skirt."""
    ps = []
    for z in (-10.4, 9.5):
        ps += [
            box(4.2, 5.4, -0.2, 0.0, z - 1.4, z + 1.4, "detail", mirror=True, note="yoke hung from the belly pad"),
            box(4.3, 5.5, -1.15, -0.2, z - 1.6, z + 1.6, "secondary", mirror=True, note="lift nozzle trough: 3.2 long, 1.2 wide"),
            box(4.45, 5.35, -0.95, -0.4, z - 1.85, z - 1.6, "detail", mirror=True, note="forward intake scoop"),
            box(4.35, 5.45, -0.4, -0.25, z - 2.0, z - 1.6, "secondary", mirror=True, note="scoop hood"),
            box(4.45, 5.35, -1.6, -1.15, z - 1.4, z + 1.4, "thrust", mirror=True, note="thrust skirt: lift jet glow, shows from the side"),
            box(5.5, 5.56, -0.8, -0.55, z - 1.0, z + 1.0, "detail", mirror=True, note="trough louvre"),
        ]
    return ps


def st_sill_cascade():
    ps = [
        box(4.3, 5.5, -0.3, 0.0, PAD_F, 9.6, "detail", mirror=True, note="cascade rail hung from the belly pad"),
        box(4.4, 5.4, -1.0, -0.3, PAD_F, -12.1, "secondary", mirror=True, note="intake scoop at the head of the rail"),
        box(4.5, 5.3, -0.9, -0.4, -12.66, PAD_F, "detail", mirror=True, note="intake mouth"),
        box(4.5, 5.3, -1.4, -1.25, -12.0, 9.0, "thrust", mirror=True, note="lift curtain glow"),
    ]
    for i in range(8):
        z = -11.4 + i * 2.85
        ps.append(part("block", [1.1, 0.85, 0.12], [4.9, -0.75, z], "secondary", [35, 0, 0], mirror=True, note="cascade vane"))
    return ps


def st_rocket_sponsons():
    return [
        box(4.6, 5.3, -0.3, 0.0, -4.0, -2.6, "detail", mirror=True, note="front pylon from the belly pad"),
        box(4.6, 5.3, -0.3, 0.0, 2.0, 3.4, "detail", mirror=True, note="rear pylon from the belly pad"),
        cylz(5.1, -0.95, 1.4, -5.2, 4.4, "primary", mirror=True, note="long sponson pod"),
        cylz(5.1, -0.95, 1.46, -5.2, -4.6, "detail", mirror=True, note="intake band"),
        ball(5.1, -0.95, -5.2, 1.4, "secondary", mirror=True, note="intake spike"),
        cylz(5.1, -0.95, 1.1, 4.4, 5.4, "detail", mirror=True, note="nozzle"),
        cylz(5.1, -0.95, 0.9, 5.4, 5.65, "thrust", mirror=True, note="thrust glow"),
        box(4.8, 5.4, -1.78, -1.66, -4.4, 3.6, "thrust", mirror=True, note="lift slot glow"),
    ]


def st_curtain_skirt():
    """An air-cushion skirt: a dark plenum tray under the whole belly, deep walls in three segments, a thick glow curtain."""
    ps = [
        box(-4.2, 4.2, -0.1, 0.0, -12.2, 10.0, "detail", note="skirt hanger: reaches the belly pad"),
        box(-4.6, 4.6, -0.35, -0.1, -12.4, 10.8, "detail", note="plenum tray under the belly"),
        box(-4.6, 4.6, -1.15, -0.35, -12.6, -12.0, "detail", note="front wall"),
        box(-3.8, 3.8, -1.0, -0.4, -12.68, -12.6, "secondary", note="intake frame"),
        box(-3.6, 3.6, -0.9, -0.5, -12.74, -12.68, "detail", note="intake mouth"),
        box(-4.4, 4.4, -1.6, -1.15, -12.5, -12.1, "thrust", note="front curtain glow"),
    ]
    for z0, z1 in ((-12.4, -5.8), (-4.4, 2.4), (3.8, 10.8)):  # 1.4 gaps: three clear segments, not one strip
        ps += [
            box(4.6, 5.5, -1.15, -0.1, z0, z1, "detail", mirror=True, note="deep skirt wall, one of three"),
            box(5.5, 5.58, -0.55, -0.3, z0, z1, "secondary", mirror=True, note="skirt band"),
            box(4.75, 5.35, -1.6, -1.15, z0 + 0.2, z1 - 0.2, "thrust", mirror=True, note="curtain glow, 0.45 tall"),
        ]
    return ps


def st_splay_jets():
    """Four long vectoring pods on cross arms, toed out on plan like a cambered stance, nozzles splayed out and down."""
    ps = [box(-0.9, 0.9, -0.3, 0.0, -12.4, 10.8, "detail", note="backbone hung from the belly pad")]
    for z in (-9.2, 7.6):
        p0, p1 = (4.5, -0.8, z - 2.3), (5.25, -0.8, z + 2.0)
        q = (5.5, -1.25, z + 3.0)
        ps += [
            cylx(-0.4, z - 0.6, 0.4, -4.7, 4.7, "detail", note="cross arm"),
            cylx(-0.4, z + 0.9, 0.4, -4.9, 4.9, "detail", note="cross arm"),
            tube(p0, p1, 1.3, "secondary", mirror=True, note="vectoring pod, 4.4 long, toed out"),
            ball(p0[0], p0[1], p0[2], 1.3, "detail", mirror=True, note="pod intake nose"),
            tube(p1, q, 0.9, "detail", mirror=True, note="nozzle, splayed out and down"),
            tip(p1, q, 0.75, 0.2, mirror=True),
        ]
    return ps


def st_tri_foil():
    """Three foils: one span foil under the nose and two anhedral foils under the rear sills, each with tip jets."""
    z = 8.2
    return [
        box(2.4, 3.0, -0.85, 0.0, -12.5, -11.8, "detail", mirror=True, note="nose foil strut from the belly pad"),
        box(-5.3, 5.3, -1.05, -0.85, -14.4, -11.8, "primary", note="span foil under the nose"),
        cylz(5.55, -0.95, 0.75, -14.8, -11.6, "secondary", mirror=True, note="nose foil tip jet"),
        ball(5.55, -0.95, -14.8, 0.75, "detail", mirror=True, note="tip jet nose"),
        cylz(5.55, -0.95, 0.6, -11.6, -11.35, "thrust", mirror=True, note="thrust glow"),
        box(-4.2, 4.2, -1.22, -1.05, -13.8, -12.4, "thrust", note="lift slot glow under the span foil"),
        box(4.0, 4.8, -0.3, 0.0, z - 1.4, z + 1.4, "detail", mirror=True, note="foil pylon from the belly pad"),
        part("block", [2.0, 0.22, 3.4], [5.0, -0.8, z], "primary", [0, 0, -28], mirror=True, note="anhedral foil, tips down and out"),
        cylz(5.58, -1.2, 0.7, z - 2.1, z + 1.9, "secondary", mirror=True, note="tip jet"),
        ball(5.58, -1.2, z - 2.1, 0.7, "detail", mirror=True, note="tip jet nose"),
        cylz(5.58, -1.2, 0.55, z + 1.9, z + 2.15, "thrust", mirror=True, note="thrust glow"),
    ]


# ---------------------------------------------------------------- Boost: tail burners
def bo_twin_cans():
    return [
        box(-3.6, 3.6, -0.3, 0.0, 11.7, 12.5, "detail", note="hanger bar under the belly pad"),
        cylz(2.6, -0.95, 1.3, 12.2, 17.6, "secondary", mirror=True, note="afterburner can"),
        cylz(2.6, -0.95, 1.0, 11.6, 12.2, "detail", mirror=True, note="intake"),
        cylz(2.6, -0.95, 1.5, 17.6, 18.5, "detail", mirror=True, note="flared nozzle"),
        cylz(2.6, -0.95, 1.15, 18.5, 18.8, "thrust", mirror=True, note="boost glow"),
    ]


def bo_lake_burners():
    p0, p1 = (2.4, -0.8, 13.1), (4.55, -0.8, 17.0)
    q1 = along(p0, p1, 0.7)
    return [
        box(-2.0, 2.0, -0.45, 0.0, 11.8, 12.6, "detail", note="hanger under the belly pad"),
        box(-2.8, 2.8, -1.15, -0.45, 11.9, 13.5, "detail", note="cross plenum"),
        box(-1.6, 1.6, -1.0, -0.5, 11.55, 11.9, "secondary", note="intake scoop"),
        tube(p0, p1, 0.9, "secondary", mirror=True, note="long side-swept burner pipe"),
        tube(p1, q1, 1.25, "detail", mirror=True, note="megaphone"),
        tip(p1, q1, 1.0, 0.2, mirror=True, note="boost glow"),
    ]


def bo_atomic():
    return [
        box(-0.5, 0.5, -0.3, 0.0, 11.8, 12.6, "detail", note="pylon under the belly pad"),
        box(-0.3, 0.3, -0.5, -0.25, 12.2, 13.8, "detail", note="pylon strut along the rocket"),
        cylz(0.0, -1.05, 1.5, 12.3, 17.4, "primary", note="single rocket body"),
        cylz(0.0, -1.05, 1.56, 12.3, 12.9, "detail", note="intake band"),
        ball(0.0, -1.05, 12.3, 1.5, "secondary", note="intake spike"),
        cylz(0.0, -1.05, 1.75, 17.4, 18.4, "detail", note="bell nozzle"),
        cylz(0.0, -1.05, 1.4, 18.4, 18.75, "thrust", note="boost glow"),
        box(0.7, 1.9, -1.12, -0.98, 15.8, 17.4, "primary", mirror=True, note="rocket fin"),
    ]


def bo_slot_burner():
    ps = [
        box(2.5, 3.3, -0.35, 0.0, 11.8, 12.6, "detail", mirror=True, note="hanger under the belly pad"),
        box(-4.2, 4.2, -1.3, -0.35, 11.9, 17.4, "secondary", note="flat wide burner"),
        box(-3.8, 3.8, -1.15, -0.5, 11.6, 11.9, "detail", note="intake slot"),
        box(-4.3, 4.3, -1.42, -0.28, 17.4, 18.1, "detail", note="nozzle lip"),
        box(-4.0, 4.0, -1.15, -0.55, 18.1, 18.4, "thrust", note="boost glow, 0.6 tall"),
    ]
    for x in (-2.0, 0.0, 2.0):
        ps.append(box(x - 0.09, x + 0.09, -1.3, -0.4, 18.1, 18.5, "secondary", note="nozzle vane"))
    return ps


def bo_bamboo():
    """Two fat stacks grow straight out of two fat burner cans, hard against the bumper zone."""
    s0, s1 = (1.9, -0.85, 17.6), (2.5, 8.2, 18.15)
    return [
        box(-2.5, 2.5, -0.35, 0.0, 11.8, 12.6, "detail", note="hanger under the belly pad"),
        cylz(1.9, -0.85, 1.3, 12.0, 17.6, "secondary", mirror=True, note="burner can, runs in view under the tail"),
        cylz(1.9, -0.85, 1.0, 11.6, 12.0, "detail", mirror=True, note="intake"),
        ball(s0[0], s0[1], s0[2], 1.3, "secondary", mirror=True, note="elbow: the stack grows out of the can"),
        tube(s0, s1, 1.0, "secondary", mirror=True, note="bamboo stack, raked back and splayed"),
        tip(s0, s1, 0.9, 0.3, mirror=True, note="boost glow"),
        cylx(3.6, 17.82, 0.35, -2.1, 2.1, "detail", note="stack tie bar"),
    ]


def bo_outboards():
    """Twin jet outboards on the transom: a cowl up top, a leg, and a jet-drive torpedo below."""
    return [
        box(1.6, 2.6, -0.3, 0.0, 11.8, 17.3, "detail", mirror=True, note="transom arm hung from the belly pad"),
        box(1.5, 2.7, 0.25, 1.9, 17.1, 18.5, "primary", mirror=True, note="outboard cowl"),
        wedge(1.5, 2.7, 1.9, 2.5, 17.1, 18.5, "up_front", "primary", mirror=True, note="cowl top, falls to the back"),
        box(1.44, 2.76, 1.4, 1.58, 17.05, 18.55, "secondary", mirror=True, note="cowl band"),
        box(1.7, 2.5, 1.7, 2.3, 17.04, 17.1, "detail", mirror=True, note="cowl intake grille, faces forward over the bumper"),
        box(1.8, 2.4, -1.0, 0.25, 17.3, 18.1, "detail", mirror=True, note="leg"),
        cylz(2.1, -1.25, 1.1, 15.4, 18.3, "secondary", mirror=True, note="jet-drive torpedo"),
        ball(2.1, -1.25, 15.4, 1.1, "detail", mirror=True, note="torpedo intake nose"),
        cylz(2.1, -1.25, 0.9, 18.3, 18.65, "detail", mirror=True, note="nozzle"),
        cylz(2.1, -1.25, 0.75, 18.65, 18.9, "thrust", mirror=True, note="boost glow"),
    ]


# ---------------------------------------------------------------- SidePods: flank trim
def sp_fender_skirts():
    ps = [box(4.8, 5.0, 0.2, 0.42, -8.0, 8.0, "secondary", mirror=True, note="sill chrome between the spats")]
    for z0, z1 in ((PAD_F, -8.0), (8.0, PAD_R)):
        zm = (z0 + z1) / 2
        ps += [
            box(4.8, 5.15, 0.05, 1.5, z0, z1, "primary", mirror=True, note="fender skirt over the blanked arch"),
            wedge(4.8, 5.15, 1.5, 2.2, z0, zm, "up_back", "primary", mirror=True, note="skirt crown, rising"),
            wedge(4.8, 5.15, 1.5, 2.2, zm, z1, "up_front", "primary", mirror=True, note="skirt crown, falling"),
            box(4.8, 5.22, 0.0, 0.16, z0, z1, "secondary", mirror=True, note="skirt edge chrome"),
        ]
    return ps


def sp_lake_pipes():
    return [
        cylz(5.2, 0.5, 0.6, -9.0, 6.5, "secondary", mirror=True, note="long lake pipe along the sill"),
        cylz(5.2, 0.5, 0.78, 6.5, 7.8, "secondary", mirror=True, note="flared tip"),
        cylz(5.2, 0.5, 0.5, 7.8, 7.92, "neon", mirror=True, note="tip glow"),
        ball(5.2, 0.5, -9.0, 0.78, "secondary", mirror=True, note="front elbow"),
        cylz(5.2, 0.5, 0.78, -4.6, -4.3, "detail", mirror=True, note="clamp"),
        cylz(5.2, 0.5, 0.78, 2.6, 2.9, "detail", mirror=True, note="clamp"),
    ]


def sp_side_spears():
    ps = [
        box(4.8, 5.0, 2.3, 2.55, PAD_F, PAD_R, "secondary", mirror=True, note="full-length spear on the beltline crease"),
        part("block", [0.2, 0.25, 6.4], [4.9, 1.6, 9.2], "secondary", [12, 0, 0], mirror=True, note="sweep spear, dips to the tail"),
        box(4.8, 5.0, 0.2, 0.45, -8.0, 8.0, "secondary", mirror=True, note="rocker chrome"),
    ]
    for z in (-11.2, -10.2, -9.2):
        ps.append(cylx(1.3, z, 0.5, 4.8, 5.05, "detail", mirror=True, note="fender ventiport"))
    return ps


def sp_long_vents():
    ps = [
        box(4.8, 5.3, 0.0, 0.62, -12.0, 11.4, "primary", mirror=True, note="deep side skirt"),
        box(4.8, 5.36, 0.62, 0.74, -12.0, 11.4, "secondary", mirror=True, note="skirt chrome"),
        box(4.8, 5.05, 1.0, 2.0, -8.6, 5.4, "detail", mirror=True, note="long side vent"),
    ]
    for y in (1.2, 1.5, 1.8):
        ps.append(box(4.8, 5.14, y - 0.05, y + 0.05, -8.6, 5.4, "secondary", mirror=True, note="vent slat"))
    return ps


def sp_overfenders():
    ps = []
    for z0, z1 in ((PAD_F, -7.8), (7.8, PAD_R)):
        ps += [
            box(4.8, 5.55, 2.0, 2.75, z0 + 0.8, z1 - 0.8, "primary", mirror=True, note="bolt-on works flare: brow"),
            part("block", [0.75, 1.9, 0.8], [5.175, 1.2, z0 + 0.75], "primary", [-18, 0, 0], mirror=True, note="flare front leg"),
            part("block", [0.75, 1.9, 0.8], [5.175, 1.2, z1 - 0.75], "primary", [18, 0, 0], mirror=True, note="flare rear leg"),
            box(4.8, 5.6, 2.3, 2.42, z0 + 1.1, z1 - 1.1, "detail", mirror=True, note="rivet line"),
        ]
    return ps


def sp_wood_panels():
    ps = [
        box(4.8, 4.95, 0.95, 2.55, -8.4, 12.2, "detail", mirror=True, note="dark wood panel along the flank"),
        box(4.8, 5.1, 2.5, 2.72, -8.6, 12.4, "secondary", mirror=True, note="pale frame rail, top"),
        box(4.8, 5.1, 0.78, 1.0, -8.6, 12.4, "secondary", mirror=True, note="pale frame rail, bottom"),
    ]
    for z in (-8.48, -3.3, 1.9, 7.1, 12.28):
        ps.append(box(4.8, 5.1, 1.0, 2.5, z - 0.12, z + 0.12, "secondary", mirror=True, note="frame post"))
    return ps


# ---------------------------------------------------------------- FrontBumper: front chrome
def fbu_blade_guards():
    return [
        box(2.6, 3.4, 0.45, 0.95, -16.7, NOSE, "detail", mirror=True, note="bracket on the bumper pad"),
        box(-5.3, 5.3, 0.4, 1.0, -17.4, -16.7, "secondary", note="slim chrome blade"),
        box(1.5, 2.0, 0.3, 1.38, -17.75, -17.3, "secondary", mirror=True, note="over-rider"),
        box(3.9, 4.9, 0.55, 0.85, -17.48, -17.4, "neon", mirror=True, note="parking lamp"),
    ]


def fbu_ripple_bar():
    return [
        box(2.6, 3.4, 0.45, 0.95, -16.7, NOSE, "detail", mirror=True, note="bracket on the bumper pad"),
        cylx(0.75, -17.2, 1.1, -4.7, 4.7, "secondary", note="heavy rounded bar"),
        ball(4.7, 0.75, -17.2, 1.1, "secondary", mirror=True, note="rounded end"),
        cylx(0.2, -16.85, 0.8, -4.4, 4.4, "primary", note="smooth painted roll pan, tucked under the bar"),
    ]


def fbu_bullet_bumper():
    return [
        box(2.6, 3.4, 0.45, 0.95, -16.7, NOSE, "detail", mirror=True, note="bracket on the bumper pad"),
        box(-5.2, 5.2, 0.5, 1.1, -17.3, -16.7, "secondary", note="chrome blade"),
        cyly(5.2, -17.0, 0.6, 0.5, 1.1, "secondary", mirror=True, note="rounded end"),
        cylz(1.5, 1.1, 1.3, -17.7, -16.9, "secondary", mirror=True, note="bullet guard body"),
        ball(1.5, 1.1, -17.7, 1.3, "secondary", mirror=True, note="bullet tip"),
        box(3.6, 4.6, 0.65, 0.95, -17.38, -17.3, "neon", mirror=True, note="parking lamp"),
    ]


def fbu_lip_kit():
    return [
        box(2.6, 3.4, 0.45, 0.95, -16.55, NOSE, "detail", mirror=True, note="bracket on the bumper pad"),
        box(-5.0, 5.0, -0.9, 1.05, -17.0, -16.55, "primary", note="deep air dam"),
        box(-5.2, 5.2, -1.1, -0.9, -17.5, -16.55, "detail", note="lip splitter"),
        box(-3.0, 3.0, -0.5, 0.2, -17.06, -17.0, "detail", note="centre intake"),
        box(3.5, 4.6, -0.3, 0.1, -17.1, -17.0, "neon", mirror=True, note="fog lamp"),
        box(-5.0, 5.0, 1.05, 1.17, -17.05, -16.55, "secondary", note="chrome strip"),
    ]


def fbu_chin_spoiler():
    return [
        box(2.6, 3.4, 0.45, 0.95, -16.6, NOSE, "detail", mirror=True, note="bracket on the bumper pad"),
        wedge(-5.2, 5.2, -1.2, 0.6, -18.3, -16.6, "up_back", "primary", note="plough ramp"),
        box(-5.0, 5.0, 0.6, 1.3, -17.0, -16.6, "primary", note="air dam below the lamp line: closes onto the seam face"),
        box(-5.5, 5.5, -1.35, -1.2, -18.4, -16.5, "detail", note="splitter plate"),
        wedge(5.2, 5.4, -1.2, 0.8, -18.3, -16.6, "up_back", "secondary", mirror=True, note="ramp end plate"),
        box(1.2, 3.8, 0.8, 1.15, -17.08, -17.0, "detail", mirror=True, note="intake slot"),
    ]


def fbu_push_bar():
    return [
        box(2.6, 3.4, 0.45, 0.95, -16.8, NOSE, "detail", mirror=True, note="bracket on the bumper pad"),
        cylx(0.7, -17.1, 0.7, -5.0, 5.0, "secondary", note="tube bumper"),
        box(1.9, 2.3, 0.4, 2.7, -17.3, -16.9, "secondary", mirror=True, note="push bar upright"),
        cylx(2.6, -17.1, 0.45, -2.3, 2.3, "secondary", note="push bar top rail"),
        cylx(1.65, -17.1, 0.35, -1.9, 1.9, "secondary", note="push bar mid rail"),
        cylz(1.0, 2.12, 0.7, -17.55, -17.1, "neon", mirror=True, note="spot lamp"),
    ]


# ---------------------------------------------------------------- RearBumper: rear chrome
def rbu_chrome_blade():
    return [
        box(2.6, 3.4, 0.45, 0.95, TAIL, 16.0, "detail", mirror=True, note="bracket on the bumper pad"),
        box(-5.2, 5.2, 0.45, 1.05, 16.0, 16.7, "secondary", note="chrome blade"),
        box(1.2, 1.7, 0.35, 1.38, 16.55, 16.95, "secondary", mirror=True, note="over-rider"),
        box(3.8, 4.7, 0.6, 0.9, 16.7, 16.78, "neon", mirror=True, note="reverse lamp"),
    ]


def rbu_roll_pan():
    return [
        box(2.6, 3.4, 0.45, 0.95, TAIL, 15.8, "detail", mirror=True, note="bracket on the bumper pad"),
        cylx(0.7, 16.1, 1.0, -4.5, 4.5, "primary", note="smooth painted roll pan"),
        ball(4.5, 0.7, 16.1, 1.0, "primary", mirror=True, note="rounded corner"),
        box(-2.5, 2.5, 0.72, 0.9, 16.5, 16.62, "neon", note="slit lamp"),
    ]


def rbu_jet_pods():
    return [
        box(2.6, 3.4, 0.45, 0.95, TAIL, 15.9, "detail", mirror=True, note="bracket on the bumper pad"),
        box(-4.0, 4.0, 0.5, 1.1, 15.9, 16.5, "secondary", note="chrome blade between the pods"),
        cylz(4.6, 0.95, 1.1, 15.55, 16.55, "secondary", mirror=True, note="jet pod at the bumper end: 1.4 long with its mouth, 1.1 across"),
        cylz(4.6, 0.95, 0.85, 16.55, 16.95, "detail", mirror=True, note="pod mouth, stepped down"),
        ball(4.6, 0.95, 16.74, 0.5, "neon", mirror=True, note="pod lamp"),
    ]


def rbu_diffuser():
    ps = [
        box(2.6, 3.4, 0.45, 0.95, TAIL, 15.65, "detail", mirror=True, note="bracket on the bumper pad"),
        box(-4.9, 4.9, 0.08, 1.3, 15.65, 16.3, "primary", note="deep painted valance"),
        box(-4.9, 4.9, 1.3, 1.42, 15.65, 16.36, "secondary", note="chrome strip"),
        box(3.4, 4.6, 0.7, 1.0, 16.3, 16.38, "neon", mirror=True, note="reflector"),
    ]
    for x in (0.6, 1.8):
        ps.append(box(x - 0.08, x + 0.08, 0.08, 0.9, 16.3, 16.9, "detail", mirror=True, note="diffuser strake"))
    return ps


def rbu_tube_bar():
    return [
        box(2.6, 3.4, 0.45, 0.95, TAIL, 15.9, "detail", mirror=True, note="bracket on the bumper pad"),
        box(2.9, 3.1, 0.6, 1.9, 15.9, 16.5, "detail", mirror=True, note="stay"),
        cylx(1.9, 16.5, 0.4, -4.6, 4.6, "secondary", note="bare tube bar"),
        box(-0.3, 0.3, 0.45, 0.75, 15.6, 16.8, "secondary", note="tow hook"),
    ]


def rbu_step_bumper():
    return [
        box(2.6, 3.4, 0.45, 0.95, TAIL, 15.8, "detail", mirror=True, note="bracket on the bumper pad"),
        box(1.3, 4.7, 0.3, 1.2, 15.8, 16.5, "secondary", mirror=True, note="deep bumper half"),
        box(4.7, 5.4, 0.3, 1.5, 15.55, 16.5, "secondary", mirror=True, note="wrap-around corner guard"),
        box(-1.3, 1.3, 0.3, 0.7, 15.8, 16.95, "detail", note="centre step plate"),
        box(-0.25, 0.25, 0.7, 1.0, 16.4, 16.95, "secondary", note="tow hitch"),
        box(3.4, 4.4, 0.6, 0.95, 16.5, 16.58, "neon", mirror=True, note="reverse lamp"),
    ]


# ---------------------------------------------------------------- RearSpoiler: fins
def fin_antenna_rails():
    p0, p1 = (4.25, 3.25, 11.4), (4.25, 7.4, 12.7)
    return [
        box(4.05, 4.45, BELT, 3.2, 9.6, PAD_R, "secondary", mirror=True, note="chrome deck rail on the fin pad"),
        cyly(4.25, 11.4, 0.5, 3.2, 3.45, "secondary", mirror=True, note="aerial base"),
        tube(p0, p1, 0.16, "secondary", mirror=True, note="raked aerial"),
        ball(4.25, 7.45, 12.72, 0.32, "neon", mirror=True, note="tip lamp"),
    ]


def fin_hump_fins():
    return [
        box(3.7, 4.5, BELT, 3.5, 9.8, PAD_R, "primary", mirror=True, note="hump base on the fin pad"),
        cylz(4.1, 3.5, 0.9, 9.8, PAD_R, "primary", mirror=True, note="low rounded hump fin"),
        ball(4.1, 3.5, 9.8, 0.9, "primary", mirror=True, note="hump nose"),
        ball(4.1, 3.5, PAD_R, 0.9, "primary", mirror=True, note="hump tail"),
        cylz(4.1, 3.5, 0.45, 12.95, 13.15, "neon", mirror=True, note="frenched hump lamp"),
    ]


def fin_tall_fins():
    """Root on the fin pad; the blade sweeps back past the pad with a rising underside, so it clears any tail."""
    rise = math.degrees(math.atan2(3.1, 6.2))
    return [
        wedge(4.1, 4.6, BELT, 4.7, 9.2, PAD_R, "up_back", "primary", mirror=True, note="fin root on the fin pad"),
        wedge(4.1, 4.6, BELT, 3.8, PAD_R, 15.4, "under_back", "primary", mirror=True, note="swept underside: clears the tail"),
        box(4.1, 4.6, 3.8, 4.7, PAD_R, 15.4, "primary", mirror=True, note="fin blade"),
        wedge(4.1, 4.6, 4.7, 6.1, PAD_R, 15.4, "up_back", "primary", mirror=True, note="fin tip"),
        plate(4.05, 4.65, 4.62, 12.3, 0.14, 6.7, -rise, "secondary", mirror=True, note="fin chrome cap"),
        cylz(4.35, 4.35, 0.6, 15.0, 15.5, "neon", mirror=True, note="lower fin lamp"),
        cylz(4.35, 5.25, 0.6, 15.0, 15.5, "neon", mirror=True, note="upper fin lamp"),
    ]


def fin_trunk_wing():
    return [
        wedge(4.2, 4.5, BELT, 4.6, 10.2, 11.4, "up_back", "primary", mirror=True, note="upright lead-in on the fin pad"),
        box(4.2, 4.5, BELT, 5.5, 11.4, PAD_R, "primary", mirror=True, note="wing upright on the fin pad"),
        box(-4.7, 4.7, 5.5, 5.72, 11.6, 14.4, "primary", note="low trunk wing: clears every boot turbine"),
        box(-4.4, 4.4, 5.55, 5.67, 14.4, 14.5, "neon", note="wing light strip"),
    ]


def fin_works_wing():
    return [
        box(3.9, 4.2, BELT, 7.0, 11.4, PAD_R, "detail", mirror=True, note="tall upright on the fin pad: no stays, the stacks are the only lattice"),
        box(-5.4, 5.4, 7.0, 7.3, 11.6, 14.6, "secondary", note="giant wing plane"),
        box(5.25, 5.5, 6.4, 7.9, 11.4, 14.8, "primary", mirror=True, note="end plate"),
        box(-5.2, 5.2, 7.3, 7.6, 14.46, 14.6, "detail", note="gurney"),
    ]


def fin_board_rack():
    return [
        box(3.8, 4.1, BELT, 5.7, 9.6, 9.9, "secondary", mirror=True, note="rack post on the fin pad"),
        box(3.8, 4.1, BELT, 5.7, 12.2, 12.5, "secondary", mirror=True, note="rack post on the fin pad"),
        cylx(5.8, 9.75, 0.3, -4.1, 4.1, "secondary", note="rack cross bar"),
        cylx(5.8, 12.35, 0.3, -4.1, 4.1, "secondary", note="rack cross bar"),
        box(-2.7, -0.5, 5.95, 6.2, 9.3, 15.3, "primary", note="long board, overhangs the tail"),
        wedge(-1.7, -1.5, 6.2, 6.9, 13.9, 15.0, "up_back", "secondary", note="board skeg"),
        box(0.5, 2.7, 5.95, 6.2, 9.6, 14.2, "secondary", note="short board"),
        wedge(1.5, 1.7, 6.2, 6.8, 13.0, 13.9, "up_back", "primary", note="board skeg"),
    ]


# ---------------------------------------------------------------- assemble
def mod(name, culture, parts):
    return {"name": name, "culture": culture, "parts": parts}


def build_spec():
    standard = {
        "cockpitEnvelope": {"min": [-4.8, BELT, CAB_Z0], "max": [4.8, ROOF, CAB_Z1]},
        "datums": {"beltline": BELT, "sill": SILL, "hoverPlane": HOVER, "barLine": BAR, "midSeam": MID,
                   "noseSeam": NOSE, "tailSeam": TAIL, "flank": BODY_X},
        "slots": {
            "FrontBody": {"label": "Front Half",
                          "envelope": [{"min": [-4.8, 0, NOSE], "max": [4.8, BELT, MID]},
                                       {"min": [-4.8, BELT, NOSE], "max": [4.8, 4.0, -15.6]},
                                       {"min": [3.4, BELT, -15.6], "max": [4.8, 4.0, CAB_Z0], "mirror": True},
                                       {"min": [FLANK_X, 0, NOSE], "max": [5.6, BELT, PAD_F], "mirror": True}],
                          "anchor": {"to": "cockpit", "face": "+y"}, "explode": [0, 0, -7]},
            "RearBody": {"label": "Rear Half",
                         "envelope": [{"min": [-4.8, 0, MID], "max": [4.8, BELT, TAIL]},
                                      {"min": [FLANK_X, 0, PAD_R], "max": [5.6, BELT, TAIL], "mirror": True}],
                         "anchor": [{"to": "cockpit", "face": "+y"}, {"to": "FrontBody", "face": "-z"}], "explode": [0, 0, 7]},
            "Engine1": {"label": "Bonnet Turbine",
                        "envelope": {"min": [-3.4, BELT, -15.6], "max": [3.4, 5.0, CAB_Z0]},
                        "anchor": {"to": "FrontBody", "face": "-y"}, "explode": [0, 5, -7]},
            "Engine2": {"label": "Boot Turbine",
                        "envelope": {"min": [-3.6, BELT, CAB_Z1], "max": [3.6, 5.4, 17.0]},
                        "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 5, 7]},
            "Stabilisers": {"label": "Sill Jets",
                            "envelope": {"min": [-6.0, HOVER, NOSE], "max": [6.0, 0, 11.5]},
                            "anchor": [{"to": "FrontBody", "face": "+y"}, {"to": "RearBody", "face": "+y"}], "explode": [0, -6, 0]},
            "Boost": {"label": "Tail Burner",
                      "envelope": [{"min": [-5.6, HOVER, 11.5], "max": [5.6, 0, 19.0]},
                                   {"min": [-5.6, 0, 17.0], "max": [5.6, 9.8, 19.0]}],
                      "anchor": {"to": "RearBody", "face": "+y"}, "explode": [0, -5, 13]},
            "SidePods": {"label": "Flanks",
                         "envelope": {"min": [FLANK_X, 0, PAD_F], "max": [5.6, BELT, PAD_R], "mirror": True},
                         "anchor": [{"to": "FrontBody", "face": "-x"}, {"to": "RearBody", "face": "-x"}], "explode": [5, 0, 0]},
            "FrontBumper": {"label": "Front Chrome",
                            "envelope": {"min": [-5.6, -1.6, -18.4], "max": [5.6, BELT, NOSE]},
                            "anchor": {"to": "FrontBody", "face": "+z"}, "explode": [0, 0, -12]},
            "RearBumper": {"label": "Rear Chrome",
                           "envelope": {"min": [-5.6, 0, TAIL], "max": [5.6, BELT, 17.0]},
                           "anchor": {"to": "RearBody", "face": "-z"}, "explode": [0, 0, 12]},
            "RearSpoiler": {"label": "Fins",
                            "envelope": [{"min": [3.6, BELT, CAB_Z1], "max": [5.6, 8.4, TAIL], "mirror": True},
                                         {"min": [-3.6, 5.4, CAB_Z1], "max": [3.6, 8.4, TAIL]}],
                            "anchor": {"to": "RearBody", "face": "-y"}, "explode": [0, 7, 9]},
        },
    }

    L, S, F, V, K, W = "Lowrider", "Lead Sled", "Fin Era", "VIP", "Kaido Racer", "Surf Wagon"
    cockpits = {
        "hardtop": {"name": "Hardtop", "culture": L, "kit": "lowrider", "parts": cab_hardtop()},
        "sled": {"name": "Sled", "culture": S, "kit": "leadsled", "parts": cab_sled()},
        "finliner": {"name": "Finliner", "culture": F, "kit": "finera", "parts": cab_finliner()},
        "vip": {"name": "VIP", "culture": V, "kit": "vip", "parts": cab_vip()},
        "kaido": {"name": "Kaido", "culture": K, "kit": "kaido", "parts": cab_kaido()},
        "longroof": {"name": "Longroof", "culture": W, "kit": "surfwagon", "parts": cab_longroof()},
    }

    modules = {
        "FrontBody": {
            "boulevard": mod("Boulevard", L, fb_boulevard()),
            "pontoon": mod("Pontoon", S, fb_pontoon()),
            "jetliner": mod("Jetliner", F, fb_jetliner()),
            "formal": mod("Formal", V, fb_formal()),
            "shark_nose": mod("Shark Nose", K, fb_shark()),
            "bullnose": mod("Bullnose", W, fb_bullnose()),
        },
        "RearBody": {
            "long_deck": mod("Long Deck", L, rb_long_deck()),
            "turtle_tail": mod("Turtle Tail", S, rb_turtle()),
            "jet_tail": mod("Jet Tail", F, rb_jet_tail()),
            "formal_trunk": mod("Formal Trunk", V, rb_formal_trunk()),
            "works_tail": mod("Works Tail", K, rb_works_tail()),
            "barrel_back": mod("Barrel Back", W, rb_barrel_back()),
        },
        "Engine1": {
            "quad_stacks": mod("Quad Stacks", L, e1_quad_stacks()),
            "torpedo": mod("Torpedo", S, e1_torpedo()),
            "twin_bullets": mod("Twin Bullets", F, e1_twin_bullets()),
            "slot_plenum": mod("Slot Plenum", V, e1_slot_plenum()),
            "works_turbo": mod("Works Turbo", K, e1_works_turbo()),
            "scoop_zoomies": mod("Scoop and Zoomies", W, e1_scoop_zoomies()),
        },
        "Engine2": {
            "tri_power": mod("Tri-Power", L, e2_tri_power()),
            "deck_ramp": mod("Deck Ramp", S, e2_deck_ramp()),
            "fin_rockets": mod("Fin Rockets", F, e2_fin_rockets()),
            "boot_turbine": mod("Boot Turbine", V, e2_boot_turbine()),
            "quad_megaphones": mod("Quad Megaphones", K, e2_quad_megaphones()),
            "fishtail": mod("Fishtail", W, e2_fishtail()),
        },
        "Stabilisers": {
            "hop_jets": mod("Hop Jets", L, st_hop_jets()),
            "sill_cascade": mod("Sill Cascade", S, st_sill_cascade()),
            "rocket_sponsons": mod("Rocket Sponsons", F, st_rocket_sponsons()),
            "curtain_skirt": mod("Curtain Skirt", V, st_curtain_skirt()),
            "splay_jets": mod("Splay Jets", K, st_splay_jets()),
            "tri_foil": mod("Tri-Foil", W, st_tri_foil()),
        },
        "Boost": {
            "twin_cans": mod("Twin Cans", L, bo_twin_cans()),
            "lake_burners": mod("Lake Burners", S, bo_lake_burners()),
            "atomic": mod("Atomic", F, bo_atomic()),
            "slot_burner": mod("Slot Burner", V, bo_slot_burner()),
            "bamboo_stacks": mod("Bamboo Stacks", K, bo_bamboo()),
            "outboards": mod("Outboards", W, bo_outboards()),
        },
        "SidePods": {
            "fender_skirts": mod("Fender Skirts", L, sp_fender_skirts()),
            "lake_pipes": mod("Lake Pipes", S, sp_lake_pipes()),
            "side_spears": mod("Side Spears", F, sp_side_spears()),
            "long_vents": mod("Long Vents", V, sp_long_vents()),
            "overfenders": mod("Overfenders", K, sp_overfenders()),
            "wood_panels": mod("Wood Panels", W, sp_wood_panels()),
        },
        "FrontBumper": {
            "blade_guards": mod("Blade and Guards", L, fbu_blade_guards()),
            "ripple_bar": mod("Ripple Bar", S, fbu_ripple_bar()),
            "bullet_bumper": mod("Bullet Bumper", F, fbu_bullet_bumper()),
            "lip_kit": mod("Lip Kit", V, fbu_lip_kit()),
            "chin_spoiler": mod("Chin Spoiler", K, fbu_chin_spoiler()),
            "push_bar": mod("Push Bar", W, fbu_push_bar()),
        },
        "RearBumper": {
            "chrome_blade": mod("Chrome Blade", L, rbu_chrome_blade()),
            "roll_pan": mod("Roll Pan", S, rbu_roll_pan()),
            "jet_pods": mod("Jet Pods", F, rbu_jet_pods()),
            "diffuser": mod("Diffuser Valance", V, rbu_diffuser()),
            "tube_bar": mod("Tube Bar", K, rbu_tube_bar()),
            "step_bumper": mod("Step Bumper", W, rbu_step_bumper()),
        },
        "RearSpoiler": {
            "antenna_rails": mod("Antenna Rails", L, fin_antenna_rails()),
            "hump_fins": mod("Hump Fins", S, fin_hump_fins()),
            "tall_fins": mod("Tall Fins", F, fin_tall_fins()),
            "trunk_wing": mod("Trunk Wing", V, fin_trunk_wing()),
            "works_wing": mod("Works Wing", K, fin_works_wing()),
            "board_rack": mod("Board Rack", W, fin_board_rack()),
        },
    }

    def kit(name, culture, fb, rb, e1, e2, st, bo, sp, fbu, rbu, fin):
        return {"name": name, "culture": culture, "modules": {
            "FrontBody": fb, "RearBody": rb, "Engine1": e1, "Engine2": e2, "Stabilisers": st, "Boost": bo,
            "SidePods": sp, "FrontBumper": fbu, "RearBumper": rbu, "RearSpoiler": fin}}

    kits = {
        "lowrider": kit("Lowrider", L, "boulevard", "long_deck", "quad_stacks", "tri_power", "hop_jets", "twin_cans",
                        "fender_skirts", "blade_guards", "chrome_blade", "antenna_rails"),
        "leadsled": kit("Lead Sled", S, "pontoon", "turtle_tail", "torpedo", "deck_ramp", "sill_cascade", "lake_burners",
                        "lake_pipes", "ripple_bar", "roll_pan", "hump_fins"),
        "finera": kit("Fin Era", F, "jetliner", "jet_tail", "twin_bullets", "fin_rockets", "rocket_sponsons", "atomic",
                      "side_spears", "bullet_bumper", "jet_pods", "tall_fins"),
        "vip": kit("VIP", V, "formal", "formal_trunk", "slot_plenum", "boot_turbine", "curtain_skirt", "slot_burner",
                   "long_vents", "lip_kit", "diffuser", "trunk_wing"),
        "kaido": kit("Kaido", K, "shark_nose", "works_tail", "works_turbo", "quad_megaphones", "splay_jets", "bamboo_stacks",
                     "overfenders", "chin_spoiler", "tube_bar", "works_wing"),
        "surfwagon": kit("Surf Wagon", W, "bullnose", "barrel_back", "scoop_zoomies", "fishtail", "tri_foil", "outboards",
                         "wood_panels", "push_bar", "step_bumper", "board_rack"),
    }

    paint = {
        "hardtop": {"primary": "#b3122b", "secondary": "#ead9a6", "neon": "#ffc65c"},
        "sled": {"primary": "#5a2f8f", "secondary": "#d5d8dd", "neon": "#ff6a3c"},
        "finliner": {"primary": "#2bb8ad", "secondary": "#f4f1e8", "neon": "#ff3b3b"},
        "vip": {"primary": "#27407a", "secondary": "#dcc680", "neon": "#bfe4ff"},
        "kaido": {"primary": "#f0efe9", "secondary": "#d7263d", "neon": "#ffe600"},
        "longroof": {"primary": "#e2a73a", "secondary": "#f3ead2", "neon": "#ff7a45"},
    }
    builds = [
        {"name": "01 Hardtop, own Lowrider kit", "cockpit": "hardtop", "kit": "lowrider", "paint": paint["hardtop"]},
        {"name": "02 Hardtop in the Kaido kit", "cockpit": "hardtop", "kit": "kaido", "paint": paint["hardtop"]},
        {"name": "03 Sled, own Lead Sled kit", "cockpit": "sled", "kit": "leadsled", "paint": paint["sled"]},
        {"name": "04 Sled in the Fin Era kit", "cockpit": "sled", "kit": "finera", "paint": paint["sled"]},
        {"name": "05 Finliner, own Fin Era kit", "cockpit": "finliner", "kit": "finera", "paint": paint["finliner"]},
        {"name": "06 Finliner in the VIP kit", "cockpit": "finliner", "kit": "vip", "paint": paint["finliner"]},
        {"name": "07 VIP, own VIP kit", "cockpit": "vip", "kit": "vip", "paint": paint["vip"]},
        {"name": "08 VIP in the Surf Wagon kit", "cockpit": "vip", "kit": "surfwagon", "paint": paint["vip"]},
        {"name": "09 Kaido, own Kaido kit", "cockpit": "kaido", "kit": "kaido", "paint": paint["kaido"]},
        {"name": "10 Kaido in the Lead Sled kit", "cockpit": "kaido", "kit": "leadsled", "paint": paint["kaido"]},
        {"name": "11 Longroof, own Surf Wagon kit", "cockpit": "longroof", "kit": "surfwagon", "paint": paint["longroof"]},
        {"name": "12 Longroof in the Lowrider kit", "cockpit": "longroof", "kit": "lowrider", "paint": paint["longroof"]},
        {"name": "13 Mixed: jet-age sled", "cockpit": "sled", "kit": "leadsled",
         "modules": {"Engine2": "fin_rockets", "RearSpoiler": "tall_fins", "Boost": "atomic", "FrontBumper": "bullet_bumper"},
         "paint": {"primary": "#14756b", "secondary": "#e9e2cf", "neon": "#ff5a36"}},
        {"name": "14 Mixed: VIP street racer", "cockpit": "vip", "kit": "vip",
         "modules": {"FrontBody": "shark_nose", "FrontBumper": "chin_spoiler", "Engine1": "works_turbo", "Boost": "bamboo_stacks",
                     "RearSpoiler": "works_wing", "Stabilisers": "splay_jets"},
         "paint": {"primary": "#2a2d36", "secondary": "#c9a44c", "neon": "#ff3df0"}},
        {"name": "15 Mixed: boulevard bubble", "cockpit": "finliner", "kit": "lowrider",
         "modules": {"RearBody": "jet_tail", "RearSpoiler": "tall_fins", "Engine1": "twin_bullets", "Stabilisers": "sill_cascade",
                     "SidePods": "side_spears"},
         "paint": {"primary": "#e07b1a", "secondary": "#fff4dc", "neon": "#7dfcff"}},
    ]

    return {
        "id": "cruiser",
        "displayName": "Cruiser",
        "tagline": "Long, low land yachts on jet thrust: lowriders, lead sleds, fin-era chrome, VIP saloons, kaido racers and surf wagons.",
        "standard": standard,
        "cockpits": cockpits,
        "kits": kits,
        "modules": modules,
        "builds": builds,
    }


# ---------------------------------------------------------------- writer (one part per line)
def _inline(o):
    return json.dumps(o, separators=(", ", ": "))


def _dump(o, ind=0):
    pad = "  " * ind
    if isinstance(o, dict):
        if "shape" in o or set(o.keys()) <= {"min", "max", "mirror"} or set(o.keys()) <= {"to", "face"} or \
                all(not isinstance(v, (dict, list)) for v in o.values()):
            return _inline(o)
        items = ["%s  %s: %s" % (pad, json.dumps(k), _dump(v, ind + 1)) for k, v in o.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(o, list):
        if all(not isinstance(v, (dict, list)) for v in o):
            return _inline(o)
        items = ["%s  %s" % (pad, _dump(v, ind + 1)) for v in o]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    return json.dumps(o)


def main():
    spec = build_spec()
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(_dump(spec) + "\n")
    n_mod = sum(len(m) for m in spec["modules"].values())
    print("wrote %s: %d cockpits, %d kits, %d modules, %d builds" % (OUT, len(spec["cockpits"]), len(spec["kits"]), n_mod, len(spec["builds"])))


if __name__ == "__main__":
    main()
