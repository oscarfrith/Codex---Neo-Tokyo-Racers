"""Generator for the Rodder frame-class blockout spec (round 2).

Run from the repo root:
  py -3 scripts/vehicle_blockouts/gen/rodder.py
It writes scripts/vehicle_blockouts/specs/rodder.json. Design exploration only, not game content.

Root space: +X right, +Y up, forward is -Z. Units are studs.
Every part is written for the +X side and mirrored where it has a twin.

How the class is put together:
  cab (cockpit)   level rails, firewall plate, barrel pads, tail collar, bulkhead, rig bar, rear horns: the same under every cab
  FrontBody       the front frame rails, raked nose-down from the firewall, plus the grille shell
  Engine1         sits level on four pedestals the frame provides
  Boost           headers, bolted to the port rail every engine carries
  Stabilisers     beam axle under the raked rails at the perch station, lift-jet pods outboard
  Engine2         long jet barrels on the two barrel pads each side of the cab
  RearBody, RearSpoiler, RearBumper  land on the bulkhead, the rig bar and the rear horns
  Every cab ends in the same 4.0 by 2.4 tail collar and every Tail starts with a first ring of that section.
  Engine glow is a burner band on the engine body; Boost carries the tip glows (Flat Trio keeps three fat upswept nozzles).
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "specs", "rodder.json"))

# ---------------------------------------------------------------- datums
HOVER = -2.0          # hover plane
SILL = 0.6            # cab rail top, engine bed plane, tail floor
BELT = 3.6            # cowl and tub top
Z_NOSE = -16.5        # front limit
Z_HORN_F = -14.5      # front frame horns: Nose Gear mounts here
Z_GRILLE = -11.5      # back of the shell zone, front of the engine bay
Z_FIRE = 1.0          # firewall plane: cab starts here
Z_BACK = 10.0         # cab back: Tail and Rear Rig start here
Z_HORN_R = 13.5       # rear frame horns: Launch Gear mounts here
Z_TAIL = 16.5         # rear limit
RAIL = (2.3, 2.9, -0.3, 0.6)                 # rail section X0, X1, Y0, Y1 (cab and frame share it)
RAKE_DROP, RAKE_LEN = 0.9, 15.4              # the front rails fall 0.9 over 15.4: nose-down rake
RAKE_DEG = math.degrees(math.atan(RAKE_DROP / RAKE_LEN))
RAKE_PIVOT = (0.15, Z_FIRE)                  # Y, Z the front frame pivots about (rail centre at the firewall)
SHELL_DROP = 0.75                            # grille shells sit this much lower than level, on the raked rails
NOSE_DROP = 0.9                              # nose gear sits this much lower than level, on the front horns
BED_Z = (-9.5, -2.5)                         # engine pedestal stations
PORT = (2.2, 2.65, 1.4, 2.0, -7.0, -4.0)     # port rail on every engine: headers bolt here
PERCH_Z = -12.0                              # axle perch station under the rails
PERCH_TOP = -1.27                            # top of every axle perch (rail underside there is -1.06)
PAD_Z = (3.8, 8.2)                           # barrel pad stations on the cab flanks
PAD_Y = 1.4                                  # barrel pad height
RIG_Y, RIG_Z, RIG_X = 4.4, 9.78, 1.6         # rig bar height, station and foot spacing
PLATE = (1.7, 0.8, 3.0)                      # firewall plate: half width, Y0, Y1
COLLAR = (2.0, 0.8, 3.2)                     # tail collar section on every cab and every Tail: half width, Y0, Y1
Z_COLLAR = (9.4, 9.75)                       # the collar ring; the dark bulkhead plate sits behind it to Z 9.95


def rail_y(z, y=0.15):
    """Height of a point on the raked front frame that would sit at height y on a level frame."""
    return y - RAKE_DROP / RAKE_LEN * (Z_FIRE - z)


# ---------------------------------------------------------------- part helpers
def _r(v):
    return round(float(v), 3)


def part(shape, size, pos, ch="primary", rot=None, m=False, note=None):
    p = {"shape": shape, "size": [_r(a) for a in size], "pos": [_r(a) for a in pos], "ch": ch}
    if rot and any(abs(a) > 1e-6 for a in rot):
        p["rot"] = [_r(a) for a in rot]
    if m:
        p["mirror"] = True
    if note:
        p["note"] = note
    return p


def box(x0, x1, y0, y1, z0, z1, ch="primary", m=False, note=None, rot=None):
    return part("block", [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], ch, rot, m, note)


def cz(x, y, z0, z1, d, ch="detail", m=False, note=None):
    return part("cyl_z", [d, d, z1 - z0], [x, y, (z0 + z1) / 2], ch, None, m, note)


def cy(x, z, y0, y1, d, ch="detail", m=False, note=None):
    return part("cyl_y", [d, y1 - y0, d], [x, (y0 + y1) / 2, z], ch, None, m, note)


def cx(y, z, x0, x1, d, ch="detail", m=False, note=None):
    return part("cyl_x", [x1 - x0, d, d], [(x0 + x1) / 2, y, z], ch, None, m, note)


def ball(x, y, z, d, ch="primary", m=False, note=None):
    return part("ball", [d, d, d], [x, y, z], ch, None, m, note)


def _aim(p0, p1):
    dx, dy, dz = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    rx = -math.degrees(math.asin(dy / length))
    ry = math.degrees(math.atan2(dx, dz))
    mid = [(a + b) / 2 for a, b in zip(p0, p1)]
    return length, mid, [rx, ry, 0.0]


def tube(p0, p1, d, ch="detail", m=False, note=None):
    """Round tube between two points."""
    length, mid, rot = _aim(p0, p1)
    return part("cyl_z", [d, d, length], mid, ch, rot, m, note)


def bar(p0, p1, w, h, ch="detail", m=False, note=None):
    """Rectangular bar between two points: w across, h tall."""
    length, mid, rot = _aim(p0, p1)
    return part("block", [w, h, length], mid, ch, rot, m, note)


def extend(p0, p1, extra):
    """Point `extra` studs past p1 on the line p0 -> p1."""
    d = [b - a for a, b in zip(p0, p1)]
    n = math.sqrt(sum(c * c for c in d))
    return [b + c / n * extra for b, c in zip(p1, d)]


def ramp(x0, x1, y0, y1, z_thin, z_tall, ch="primary", m=False, under=False, note=None):
    """Wedge. Flat base at y0, rising from nothing at z_thin to full height at z_tall.
    under=True flips it: flat face on top at y1, deepest at z_tall."""
    size = [x1 - x0, y1 - y0, abs(z_tall - z_thin)]
    pos = [(x0 + x1) / 2, (y0 + y1) / 2, (z_thin + z_tall) / 2]
    back = z_tall > z_thin
    if under:
        rot = [180, 180, 0] if back else [180, 0, 0]
    else:
        rot = [0, 0, 0] if back else [0, 180, 0]
    return part("wedge", size, pos, ch, rot, m, note)


def xramp(x_thin, x_tall, y0, y1, z0, z1, ch="primary", m=False, note=None):
    """Wedge sloping across X: nothing at x_thin, full height at x_tall."""
    size = [z1 - z0, y1 - y0, abs(x_tall - x_thin)]
    pos = [(x_thin + x_tall) / 2, (y0 + y1) / 2, (z0 + z1) / 2]
    return part("wedge", size, pos, ch, [0, 90 if x_tall > x_thin else -90, 0], m, note)


def taper(x_flat, x_tip, y0, y1, z_wide, z_tip, ch="primary", m=False, note=None):
    """Plan-view taper. Straight side at x_flat, full width (to x_tip) at z_wide, a point at z_tip."""
    size = [y1 - y0, abs(x_tip - x_flat), abs(z_wide - z_tip)]
    pos = [(x_flat + x_tip) / 2, (y0 + y1) / 2, (z_wide + z_tip) / 2]
    flat_pos = x_flat > x_tip
    if z_tip < z_wide:
        rot = [0, 0, 90 if flat_pos else -90]
    else:
        rot = [0, 180, -90 if flat_pos else 90]
    return part("wedge", size, pos, ch, rot, m, note)


def nozzle(p0, p1, d, glow_len=0.35, ch="detail", m=False, note=None, glow=0.78):
    """A pipe from p0 to p1 with a glowing tip past p1. Returns two parts."""
    tip = extend(p0, p1, glow_len)
    return [tube(p0, p1, d, ch, m, note), tube(p1, tip, d * glow, "thrust", m)]


def along(p0, p1, t):
    """Point a fraction t of the way from p0 to p1."""
    return [a + (b - a) * t for a, b in zip(p0, p1)]


def lift_nozzle(x, y, z, d, tilt=25.0, length=0.4, glow_len=0.3, note="lift nozzle, tilted outward so the glow shows from the front and side"):
    """A down nozzle starting at (x, y, z), tilted outward (+X) by `tilt` degrees. Mirrored. Returns two parts."""
    s, c = math.sin(math.radians(tilt)), math.cos(math.radians(tilt))
    p0 = (x, y, z)
    p1 = (x + length * s, y - length * c, z)
    p2 = (x + (length + glow_len) * s, y - (length + glow_len) * c, z)
    return [tube(p0, p1, d, "detail", True, note), tube(p1, p2, d * 0.85, "thrust", True)]


def oval(z0, z1, w, h, y, ch="primary", core=None, note=None):
    """Flattened oval section along Z: a centre block with a cylinder each side. w across, h high, centred on y."""
    r = (w - h) / 2.0
    return [box(-r, r, y - h / 2.0, y + h / 2.0, z0, z1, core or ch, note=note), cz(r, y, z0, z1, h, ch, m=True)]


def shift(parts, dy=0.0, dz=0.0):
    """Move parts without turning them."""
    for p in parts:
        p["pos"] = [p["pos"][0], _r(p["pos"][1] + dy), _r(p["pos"][2] + dz)]
    return parts


def _mat(rot):
    rx, ry, rz = [math.radians(a) for a in rot]
    cx_, sx, cy_, sy, cz_, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    mx = [[1, 0, 0], [0, cx_, -sx], [0, sx, cx_]]
    my = [[cy_, 0, sy], [0, 1, 0], [-sy, 0, cy_]]
    mz = [[cz_, -sz, 0], [sz, cz_, 0], [0, 0, 1]]
    return _mul(my, _mul(mx, mz))


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def _euler(mat):
    """Rotation matrix -> Roblox Orientation (Y-X-Z order), degrees."""
    rx = math.asin(max(-1.0, min(1.0, -mat[1][2])))
    if abs(math.cos(rx)) > 1e-6:
        ry = math.atan2(mat[0][2], mat[2][2])
        rz = math.atan2(mat[1][0], mat[1][1])
    else:
        ry = math.atan2(-mat[2][0], mat[0][0])
        rz = 0.0
    return [math.degrees(rx), math.degrees(ry), math.degrees(rz)]


def rake(parts):
    """Pitch level-authored parts nose-down with the front frame, about the rail centre at the firewall."""
    phi = -RAKE_DEG
    turn = _mat([phi, 0, 0])
    s, c = math.sin(math.radians(phi)), math.cos(math.radians(phi))
    for p in parts:
        dy, dz = p["pos"][1] - RAKE_PIVOT[0], p["pos"][2] - RAKE_PIVOT[1]
        p["pos"] = [p["pos"][0], _r(RAKE_PIVOT[0] + dy * c - dz * s), _r(RAKE_PIVOT[1] + dy * s + dz * c)]
        rot = _euler(_mul(turn, _mat(p.get("rot", [0, 0, 0]))))
        if any(abs(a) > 1e-6 for a in rot):
            p["rot"] = [_r(a) for a in rot]
    return parts


# ---------------------------------------------------------------- the shared chassis (every cab)
def chassis():
    """Rails, firewall plate, barrel pads, tail collar, bulkhead, rig bar and rear horns. Identical under every cab."""
    x0, x1, y0, y1 = RAIL
    hw, py0, py1 = PLATE
    kw, ky0, ky1 = COLLAR
    ps = [
        box(x0, x1, y0, y1, 1.2, 13.4, "secondary", m=True, note="cab rail and rear horn: same section as the frame rails, 0.3 shadow gap at the firewall"),
        box(-hw, hw, py0, py1, 1.1, 1.35, "detail", note="firewall plate: every engine's transfer duct lands here"),
        box(-kw, kw, ky0, ky1, Z_COLLAR[0], Z_COLLAR[1], "primary", note="tail collar: the same 4.0 by 2.4 section on every cab; each cab blends its body into it"),
        box(-kw + 0.1, kw - 0.1, ky0 + 0.1, ky1 - 0.1, Z_COLLAR[1], 9.95, "detail", note="rear bulkhead: shadow gap; every Tail starts 0.15 behind it at the collar section"),
        cy(RIG_X - 0.1, 9.82, ky1 - 0.1, RIG_Y - 0.15, 0.3, "detail", m=True, note="rig post"),
        cx(RIG_Y, RIG_Z, -2.0, 2.0, 0.4, "detail", note="rig bar: every Rear Rig lands here"),
        cx(0.1, 13.2, -2.3, 2.3, 0.4, "detail", note="rear crossmember: Launch Gear mounts on the horn ends"),
    ]
    for z in PAD_Z:
        ps.append(cx(PAD_Y, z, -3.1, 3.1, 0.5, "detail", note="outrigger tube"))
        ps.append(box(3.0, 3.25, PAD_Y - 0.6, PAD_Y + 0.6, z - 0.6, z + 0.6, "detail", m=True, note="barrel pad: Side Jets land here"))
    return ps


# ---------------------------------------------------------------- cockpits
def cab_deuce():
    """Chopped three-window coupe: wide, long, very low roof, sloping back."""
    ps = chassis()
    ps += [
        box(-2.95, 2.95, 0.7, 3.5, 1.45, 3.3, "primary", note="cowl"),
        box(-3.15, 3.15, 0.7, BELT, 3.3, 8.0, "primary", note="body tub to the beltline"),
        box(-2.0, 2.0, 0.7, BELT, 8.0, 9.6, "primary", note="tub tucks in to the tail collar"),
        taper(2.0, 3.15, 0.7, BELT, 8.0, 9.6, "primary", m=True, note="tuck-in: full width at the roof's end, collar width at the back"),
        box(3.15, 3.23, 3.4, 3.62, 1.6, 8.0, "secondary", m=True, note="beltline moulding"),
        part("block", [5.3, 1.2, 0.2], [0, 4.15, 3.7], "glass", [14, 0, 0], note="chopped windscreen"),
        part("block", [0.4, 1.25, 0.4], [2.8, 4.15, 3.7], "primary", [14, 0, 0], m=True, note="A pillar"),
        box(-2.8, 2.8, 4.58, 4.75, 3.1, 4.0, "secondary", note="visor"),
        box(-2.95, 2.95, 4.7, 5.3, 3.85, 8.0, "primary", note="chopped roof"),
        box(2.8, 2.98, 3.7, 4.65, 4.2, 6.4, "glass", m=True, note="door glass"),
        box(2.55, 2.98, 3.6, 4.7, 6.4, 8.0, "primary", m=True, note="blind rear quarter"),
        ramp(-2.3, 2.3, BELT, 5.3, 9.6, 8.0, "primary", note="sloping back, narrowed over the tuck-in"),
        part("block", [2.4, 0.1, 0.9], [0, 4.5, 8.85], "glass", [46.7, 0, 0], note="mail-slot rear window"),
        box(3.15, 3.21, 0.9, 3.3, 4.0, 4.08, "detail", m=True, note="door shut line"),
        box(3.15, 3.21, 0.9, 3.3, 6.5, 6.58, "detail", m=True),
        box(-0.8, 0.8, 2.6, 3.9, 5.6, 6.6, "driver"),
        ball(0, 4.25, 6.0, 1.0, "driver"),
    ]
    return ps


def cab_bucket():
    """Low, narrow open tub set right forward behind a short cowl, tall upright screen, bare rails and a fuel cell behind."""
    ps = chassis()
    ps += [
        box(-1.7, 1.7, 0.7, 2.2, 1.45, 3.0, "primary", note="short cowl"),
        ramp(-1.7, 1.7, 2.2, 2.6, 1.45, 3.0, "primary", note="cowl top rises to the screen"),
        box(-2.2, 2.2, 0.7, 2.0, 3.0, 7.0, "primary", note="low, narrow open tub, set between the rails"),
        box(1.85, 2.2, 2.0, 2.4, 3.0, 7.0, "primary", m=True, note="tub side"),
        ramp(1.85, 2.2, 2.4, 3.2, 4.0, 7.0, "primary", m=True, note="bucket edge rises to the back"),
        box(-1.85, 1.85, 2.0, 3.2, 6.6, 7.0, "primary", note="tub back"),
        box(-1.75, 1.75, 2.0, 3.0, 6.0, 6.6, "secondary", note="seat back"),
        box(-1.75, 1.75, 2.0, 2.3, 4.5, 6.0, "secondary", note="seat cushion"),
        box(-1.25, 1.25, 2.6, 5.6, 3.1, 3.22, "glass", note="tall upright windscreen"),
        box(1.25, 1.5, 2.2, 5.75, 3.05, 3.3, "secondary", m=True, note="brass screen post"),
        box(-1.5, 1.5, 5.6, 5.8, 3.05, 3.3, "secondary"),
        box(2.2, 2.28, 1.6, 1.85, 3.0, 7.0, "secondary", m=True, note="pinstripe"),
        box(-0.8, 0.8, 2.3, 3.9, 5.2, 6.1, "driver"),
        ball(0, 4.45, 5.6, 1.2, "driver"),
        tube((0.7, 3.6, 5.2), (0.5, 3.2, 4.3), 0.4, "driver", m=True, note="arms"),
        box(-0.7, 0.7, 3.1, 3.25, 4.1, 4.25, "detail", note="tiller yoke"),
        tube((0, 3.15, 4.2), (0, 2.5, 3.1), 0.25, "detail"),
        box(-2.2, 2.2, 0.7, 3.0, 7.0, 9.4, "primary", note="fuel tank box fills the bay from the tub back to the tail collar"),
        box(-2.0, 2.0, 3.0, 3.2, 7.2, 9.4, "secondary", note="tank lid, level with the tub back and the collar top"),
        box(1.0, 1.3, 0.68, 3.24, 7.5, 7.8, "detail", m=True, note="tank strap"),
        box(1.0, 1.3, 0.68, 3.24, 8.6, 8.9, "detail", m=True),
        cy(0, 8.2, 3.2, 3.4, 0.6, "detail", note="filler cap"),
    ]
    return ps


def cab_rat():
    """Pickup cab: narrow, tall, pushed right back, flat roof with a visor, long low cowl."""
    ps = chassis()
    ps += [
        box(-1.3, 1.3, 0.7, 1.9, 1.45, 5.6, "primary", note="long, low, narrow cowl"),
        box(-1.75, 1.75, 0.7, 3.05, 1.45, 1.8, "primary", note="firewall hoop: covers the firewall plate"),
        ramp(-1.3, 1.3, 1.9, 3.05, 4.0, 1.8, "primary", note="cowl top falls from the hoop to the low cowl"),
        taper(1.3, 1.75, 0.7, 1.9, 1.8, 3.2, "primary", m=True, note="hoop blends into the cowl sides"),
        box(1.3, 1.36, 0.9, 1.7, 2.6, 2.8, "detail", m=True, note="cowl louvre"),
        box(1.3, 1.36, 0.9, 1.7, 3.5, 3.7, "detail", m=True),
        box(-2.1, 2.1, 0.7, BELT, 5.6, 9.6, "primary", note="narrow cab pushed back"),
        box(1.7, 2.1, BELT, 5.9, 5.6, 6.0, "primary", m=True, note="front post"),
        box(1.7, 2.1, BELT, 5.9, 9.2, 9.6, "primary", m=True, note="rear post"),
        box(-1.7, 1.7, 3.7, 5.8, 5.7, 5.82, "glass", note="tall upright windscreen"),
        box(1.92, 2.05, 3.7, 5.8, 6.0, 9.2, "glass", m=True, note="door glass"),
        box(-1.7, 1.7, BELT, 5.9, 9.3, 9.6, "primary", note="back panel"),
        box(-1.0, 1.0, 4.2, 5.4, 9.6, 9.66, "glass", note="rear window"),
        box(-2.9, 2.9, 5.9, 6.34, 4.4, 9.9, "primary", note="wide flat roof with a long visor overhang"),
        box(-1.6, 1.6, 6.34, 6.4, 6.4, 9.0, "secondary", note="roof insert"),
        box(-2.9, 2.9, 5.6, 5.9, 4.4, 4.65, "secondary", note="visor lip"),
        box(2.1, 2.16, 0.9, 3.5, 7.6, 7.68, "detail", m=True, note="door shut line"),
        box(-0.8, 0.8, 2.9, 4.2, 7.4, 8.4, "driver"),
        ball(0, 4.7, 7.8, 1.1, "driver"),
    ]
    return ps


def cab_slingshot():
    """Open roll cage standing on the rails at the very back, bare torque tube and a short leg fairing ahead of it."""
    ps = chassis()
    ps += [
        cz(0, 1.25, 1.4, 4.7, 0.7, "detail", note="bare torque tube from the firewall: no cowl"),
        ramp(-0.95, 0.95, 0.8, 2.2, 4.4, 6.6, "primary", note="short leg fairing"),
        box(-1.1, 1.1, 0.8, 2.3, 6.6, 9.6, "primary", note="slim, low seat tub at the very back"),
        ramp(-0.8, 0.8, 2.1, 2.9, 6.2, 6.9, "glass", note="deflector screen"),
        taper(1.1, 2.0, 0.8, 2.3, 9.4, 6.9, "primary", m=True, note="shoulder fairing: the slim tub widens to the tail collar"),
        ramp(1.1, 2.0, 2.3, 3.2, 7.6, 9.0, "primary", m=True, note="coaming rises to the collar top"),
        box(1.1, 2.0, 2.3, 3.2, 9.0, 9.4, "primary", m=True),
        box(-1.1, 1.1, 2.3, 3.2, 9.05, 9.4, "secondary", note="seat back, at the collar section"),
        box(-0.85, 0.85, 2.3, 3.8, 7.8, 8.8, "driver"),
        ball(0, 4.4, 8.3, 1.3, "driver", note="helmet"),
        tube((0.7, 3.5, 7.9), (0.45, 3.0, 7.0), 0.4, "driver", m=True, note="arms"),
        box(-0.6, 0.6, 2.9, 3.05, 6.85, 7.0, "detail", note="butterfly yoke"),
        tube((2.6, 0.6, 9.3), (2.3, 5.4, 9.3), 0.35, "detail", m=True, note="main hoop leg: stands on the rail"),
        cx(5.4, 9.3, -2.45, 2.45, 0.35, "detail"),
        tube((2.6, 0.6, 7.0), (2.3, 5.4, 7.0), 0.35, "detail", m=True, note="front hoop leg"),
        cx(5.4, 7.0, -2.45, 2.45, 0.35, "detail"),
        cz(2.3, 5.4, 7.0, 9.3, 0.3, "detail", m=True),
        tube((2.3, 5.2, 7.0), (1.6, 2.9, 1.6), 0.3, "detail", m=True, note="forward brace to the firewall plate"),
        tube((2.45, 2.9, 7.0), (2.6, 0.7, 1.6), 0.3, "detail", m=True, note="lower longeron to the rail"),
    ]
    return ps


def cab_lakester():
    """Fat belly tank: a flattened oval 4.6 wide by 3.4 high, far bigger than any Side Jet, with a wide stripe, a big bubble and a headrest fairing."""
    ps = chassis()
    ps += oval(1.45, 2.9, 3.7, 2.7, 2.15, "primary", "secondary", note="blunt tank nose: covers the firewall plate")
    ps += oval(2.9, 8.0, 4.6, 3.4, 2.3, "primary", "secondary", note="belly tank, flattened oval; the centre strip is the wide stripe")
    ps += oval(8.0, Z_COLLAR[0], 4.3, 2.9, 2.15, "primary", note="tank tail flares down to the tail collar")
    ps += [
        ball(0, 4.7, 6.0, 3.0, "glass", note="big bubble canopy, 3.0 across, standing clear of the tank top"),
        ball(0, 4.9, 6.0, 1.1, "driver"),
        ramp(-0.9, 0.9, 4.0, 5.6, 9.3, 7.2, "primary", note="headrest fairing behind the bubble"),
        box(-1.2, 1.2, 4.0, 4.5, 4.7, 7.2, "secondary", note="canopy coaming"),
        box(2.24, 2.36, 1.6, 3.0, 3.9, 5.5, "secondary", m=True, note="number panel"),
        box(-2.9, 2.9, 0.62, 0.9, 3.5, 3.9, "detail", note="tank cradle on the rails"),
        box(-2.9, 2.9, 0.62, 0.9, 8.0, 8.4, "detail"),
    ]
    return ps


# ---------------------------------------------------------------- FrontBody: raked frame rails and grille shell
def frame(rail="box", extra=None):
    """Front frame, authored level and then raked. Pedestals bring the engine bed back up to the sill datum."""
    x0, x1, y0, y1 = RAIL
    ps = []
    if rail == "box":
        ps.append(box(x0, x1, y0, y1, -14.4, 0.9, "secondary", m=True, note="frame rail on the rail section datum, raked nose-down"))
    elif rail == "tube":
        ps.append(cz(2.6, 0.15, -14.4, 0.9, 0.6, "secondary", m=True, note="tube frame rail, raked nose-down"))
    else:
        ps.append(cz(2.6, 0.32, -14.4, 0.9, 0.5, "secondary", m=True, note="upper rail tube, raked nose-down"))
    for z in (-14.2, -6.0, 0.5):
        ps.append(cx(0.15, z, -2.3, 2.3, 0.35, "detail", note="crossmember" if z > -14 else "front crossmember: Nose Gear pad"))
    ps += extra or []
    rake(ps)
    for z in BED_Z:
        ps.append(box(x0, x1, rail_y(z, y1) - 0.05, SILL, z - 0.3, z + 0.3, "detail", m=True, note="engine pedestal: top on the sill datum"))
    return ps


def fb_deuce_shell():
    shell = [
        box(-1.6, 1.6, 0.7, 4.3, -13.0, -11.7, "primary", note="tall upright grille shell: the engine's intake"),
        xramp(1.6, 0, 4.3, 4.8, -13.0, -11.7, "primary", m=True, note="peaked top"),
        box(-1.3, 1.3, 1.0, 4.0, -13.12, -13.0, "detail", note="grille insert"),
        box(-0.1, 0.1, 1.0, 4.2, -13.2, -13.1, "neon"),
        cz(2.6, 3.2, -13.6, -12.2, 1.1, "secondary", m=True, note="bullet headlamp"),
        cz(2.6, 3.2, -13.75, -13.6, 0.85, "neon", m=True),
        cy(2.6, -12.9, 0.55, 2.65, 0.25, "detail", m=True, note="lamp stalk"),
    ]
    return frame("box") + shift(shell, -SHELL_DROP)


def fb_track_nose():
    shell = [
        ball(0, 2.15, -13.0, 2.9, "primary", note="rounded track nose"),
        cz(0, 2.15, -13.0, -11.65, 2.9, "primary"),
        cz(0, 2.15, -14.5, -14.2, 1.4, "detail", note="intake mouth"),
        box(-2.9, 2.9, 0.7, 1.5, -13.4, -11.7, "primary", note="apron over the rails"),
        taper(1.4, 2.9, 0.7, 1.5, -13.4, -14.4, "primary", m=True, note="apron corner"),
        box(-2.9, 2.9, 1.5, 1.58, -13.3, -11.8, "secondary", note="apron stripe"),
    ]
    pan = [box(-2.3, 2.3, -0.35, -0.1, -14.4, -6.0, "primary", note="nose pan: runs back under the front of the engine")]
    return frame("tube", pan) + shift(shell, -SHELL_DROP)


def fb_rat_frame():
    extra = [
        bar((-2.3, 0.1, -9.3), (2.3, 0.1, -3.2), 0.35, 0.3, "detail", note="X member"),
        bar((2.3, 0.1, -9.3), (-2.3, 0.1, -3.2), 0.35, 0.3, "detail"),
        ramp(2.3, 2.9, -1.5, -0.3, -9.2, -4.2, "secondary", m=True, under=True, note="deep fish-belly boxing plate: deepest mid-bay, flush again at the firewall"),
        ramp(2.3, 2.9, -1.5, -0.3, 0.7, -4.2, "secondary", m=True, under=True),
        box(-2.3, 2.3, -0.4, -0.15, -3.0, 0.9, "secondary", note="skid pan under the back of the engine"),
    ]
    shell = [
        taper(0, 1.1, 0.8, 3.5, -11.7, -14.2, "primary", m=True, note="pointed prow grille: narrow, low, long"),
        bar((0.14, 2.0, -13.8), (0.98, 2.0, -12.1), 0.1, 1.3, "detail", m=True, note="bare core slats"),
        cz(0, 3.6, -13.4, -11.7, 0.6, "secondary", note="header tank on the prow"),
        cz(-3.0, 2.2, -13.5, -12.2, 1.2, "secondary", note="big lamp, one side only, hung wide"),
        cz(-3.0, 2.2, -13.65, -13.5, 0.9, "neon"),
        tube((-2.6, 0.6, -12.8), (-3.0, 1.6, -12.8), 0.25, "detail", note="lamp stalk"),
        cz(2.2, 1.3, -13.2, -12.4, 0.6, "secondary", note="small lamp, tucked in"),
        cz(2.2, 1.3, -13.32, -13.2, 0.45, "neon"),
        tube((2.6, 0.6, -12.8), (2.2, 1.0, -12.8), 0.2, "detail", note="lamp stalk"),
    ]
    return frame("box", extra) + shift(shell, -SHELL_DROP)


def fb_sling_rails():
    lower0, lower1 = (2.6, -1.15, 0.7), (2.6, -0.15, -9.3)
    extra = [tube(lower0, lower1, 0.4, "secondary", m=True, note="lower chord: deep at the firewall, shallow at the front")]
    for z in (-0.4, -2.9, -5.4, -7.9):
        t = (lower0[2] - (z - 0.9)) / (lower0[2] - lower1[2])
        ylow = lower0[1] + (lower1[1] - lower0[1]) * t
        extra.append(tube((2.6, 0.3, z), (2.6, ylow, z - 0.9), 0.25, "detail", m=True, note="truss web"))
    shell = [
        taper(0, 2.0, 0.7, 1.6, -11.7, -14.3, "primary", m=True, note="arrowhead nose fairing: no shell, bare intake"),
        box(-0.1, 0.1, 1.6, 2.2, -13.0, -11.7, "secondary", note="spine"),
        ramp(-0.1, 0.1, 1.6, 2.2, -14.1, -13.0, "secondary"),
    ]
    return frame("twin", extra) + shift(shell, -SHELL_DROP)


def fb_salt_nose():
    extra = [
        box(-2.3, 2.3, -0.35, -0.1, -14.4, -7.4, "primary", note="floor between the rails"),
        box(-2.3, 2.3, -0.9, -0.1, -7.4, 0.9, "primary", note="belly pan"),
        ramp(-2.3, 2.3, -0.9, -0.35, -9.3, -7.4, "primary", under=True, note="belly pan nose"),
    ]
    shell = [
        ramp(-3.0, 3.0, 0.7, 3.9, -14.4, -11.8, "primary", note="full-width streamliner nose ramp"),
        part("block", [3.4, 0.08, 1.2], [0, 2.3, -13.15], "detail", [-51, 0, 0], note="intake slit"),
        box(3.0, 3.15, 0.7, 1.2, -14.3, -11.8, "secondary", m=True, note="nose strake"),
    ]
    return frame("box", extra) + shift(shell, -SHELL_DROP)


# ---------------------------------------------------------------- Engine1: the exposed front engine
def engine_pads(body_x, duct_from, duct_y=1.9, duct_d=1.2, duct_ch="detail", web=True):
    """Bearers on the frame pedestals, port rails for the headers, transfer duct to the firewall."""
    px0, px1, py0, py1, pz0, pz1 = PORT
    ps = [box(-2.65, 2.65, 0.65, 0.9, z - 0.2, z + 0.2, "detail", note="engine bearer on the frame pedestals") for z in BED_Z]
    ps.append(box(px0, px1, py0, py1, pz0, pz1, "detail", m=True, note="port rail: headers bolt here"))
    if body_x > px0 - 0.1:
        pass                                    # the engine body already reaches the port rail
    elif web:
        ps.append(box(body_x, px0, 1.5, 1.9, pz0 + 0.3, pz1 - 0.3, "detail", m=True, note="port web"))
    else:
        for z in (pz0 + 0.3, pz1 - 0.6):
            ps.append(box(body_x, px0, 1.5, 1.9, z, z + 0.3, "detail", m=True, note="port strut"))
    ps.append(cz(0, duct_y, duct_from, 0.8, duct_d, duct_ch, note="transfer duct to the firewall"))
    return ps


def e1_blown_turbine():
    """Fat turbine with a blower and bug-catcher scoop on top and twin turbine stacks."""
    ps = engine_pads(1.3, -2.7, 2.0, 1.3)
    y = 2.25
    body = [
        cz(0, y, -10.6, -9.1, 3.1, "secondary", note="intake bell"),
        cz(0, y, -10.7, -10.6, 1.75, "detail", note="intake throat"),
        ball(0, y, -10.55, 1.4, "primary", note="intake spike"),
        cz(0, y, -9.1, -6.0, 3.0, "secondary", note="compressor barrel"),
        cz(0, y, -6.0, -5.0, 2.5, "thrust", note="burner glow"),
        cz(0, y, -5.0, -3.2, 3.0, "detail", note="turbine case"),
        box(-1.1, 1.1, 3.7, 4.5, -9.0, -5.4, "primary", note="blower case"),
        cz(0, 4.1, -9.8, -9.0, 0.9, "detail", note="blower drive"),
        box(-1.25, 1.25, 4.5, 5.8, -8.6, -6.6, "secondary", note="bug-catcher scoop"),
        ramp(-1.25, 1.25, 4.5, 5.8, -5.2, -6.6, "secondary"),
    ]
    for x in (-0.78, 0.0, 0.78):
        body.append(cz(x, 5.15, -8.75, -8.6, 0.65, "detail", note="scoop throat"))
    a, b = (0.7, 3.6, -4.4), (1.6, 4.9, -3.5)
    body.append(tube(a, b, 0.9, "detail", m=True, note="bleed stack: no glow, the engine glows at the burner band only"))
    body.append(tube(b, extend(a, b, 0.35), 1.1, "secondary", m=True, note="stack bell"))
    return ps + shift(body, dz=0.5)   # set back from the shell so the intake spike stands in clear air


def e1_tunnel_ram():
    """Short V block, wide canted heads, tall tunnel-ram tower with two intake bells. A fat burner can glows between the block and the firewall."""
    ps = engine_pads(1.5, -1.5, 1.7, 1.4)
    ps += [
        box(-1.5, 1.5, 0.95, 2.3, -6.8, -2.8, "secondary", note="short block"),
        cz(0, 1.7, -2.8, -1.5, 2.3, "thrust", note="burner can: the engine's only glow, 2.3 across"),
        part("block", [1.7, 0.6, 3.8], [1.7, 2.75, -4.8], "primary", [0, 0, -35], m=True, note="wide canted head"),
        box(-0.6, 0.6, 2.3, 4.8, -6.0, -3.4, "detail", note="tunnel ram tower"),
        box(-1.0, 1.0, 4.8, 5.4, -6.4, -3.0, "primary", note="plenum"),
        cz(0, 1.75, -7.9, -6.8, 1.9, "secondary", note="ram intake bell on the front of the block"),
        cz(0, 1.75, -8.0, -7.9, 1.3, "detail", note="intake throat"),
        cz(1.15, 1.25, -11.3, -6.8, 0.4, "detail", m=True, note="coolant line from the shell"),
    ]
    for z in (-5.6, -3.8):
        ps.append(cy(0, z, 5.4, 5.9, 0.9, "secondary", note="ram stack: an intake, no glow"))
        ps.append(cy(0, z, 5.9, 6.3, 1.4, "secondary", note="bell mouth"))
        ps.append(cy(0, z, 6.3, 6.38, 1.0, "detail", note="intake throat"))
    return ps


def e1_flat_trio():
    """Three slim turbines lying side by side: three intake bells in a row at the front, three fat upswept nozzles ahead of the firewall."""
    ps = engine_pads(2.2, -2.4, 1.6, 1.2)
    y = 1.95
    ps.append(box(-2.3, 2.3, 0.9, 1.3, -9.9, -2.3, "detail", note="flat sump plate ties the three turbines together"))
    for x in (-1.75, 0.0, 1.75):
        p0, p1 = (x, y, -3.6), (x * 1.08, 3.6, -2.0)
        ps += [
            cz(x, y, -10.9, -10.1, 1.7, "primary", note="intake bell"),
            cz(x, y, -11.0, -10.9, 1.2, "detail", note="intake throat"),
            ball(x, y, -10.95, 0.8, "secondary", note="intake spike"),
            cz(x, y, -10.1, -3.0, 1.5, "secondary", note="turbine barrel, one of three abreast"),
            cz(x, y, -6.6, -5.6, 1.58, "primary", note="band"),
            tube(p0, p1, 1.35, "detail", note="upswept nozzle"),
            tube(p1, extend(p0, p1, 0.35), 1.2, "thrust"),
        ]
    return ps


def e1_twin_mill():
    """Two slim turbines nose to tail, each with a glowing burner band. Forward-leaning bull-horn ram intakes: intakes only, no glow."""
    ps = engine_pads(0.9, -1.2, 1.85, 1.2)
    y = 1.85
    for z0, z1 in ((-11.0, -6.8), (-6.1, -1.8)):
        ps += [
            cz(0, y, z0, z0 + 1.0, 2.1, "primary", note="intake lip"),
            cz(0, y, z0 + 1.0, z1 - 0.9, 1.8, "secondary", note="slim turbine, one of two in tandem"),
            cz(0, y, z1 - 0.9, z1, 1.95, "thrust", note="burner band: the engine's glow, 1.95 across"),
        ]
    ps.append(cz(0, y, -11.1, -11.0, 1.4, "detail", note="intake throat"))
    ps.append(cz(0, y, -6.8, -6.1, 1.2, "detail", note="coupler"))
    ps.append(cz(0, y, -1.8, -1.2, 1.5, "detail", note="tail cone"))
    for z in (-9.4, -8.0, -4.4):
        a, b = (0.5, 2.4, z), (1.75, 4.1, z - 0.7)
        ps.append(tube(a, b, 0.75, "secondary", m=True, note="bull-horn ram intake, leaning forward"))
        ps.append(tube(b, extend(a, b, 0.5), 1.1, "secondary", m=True, note="ram bell"))
        ps.append(tube(extend(a, b, 0.5), extend(a, b, 0.58), 0.75, "detail", m=True, note="intake throat"))
    return ps


def e1_turbine_swap():
    """One long smooth turbine on a solid keel fairing: spike intake, 5.8-long body, tail cone, burner band, jet pipe down to the firewall."""
    ps = engine_pads(0.8, -0.6, 2.2, 1.0, "secondary", web=False)
    y, d = 3.2, 2.8
    ps += [
        box(-0.8, 0.8, 0.9, 2.0, -9.8, -2.2, "primary", note="solid pylon fairing: one keel from bearer to bearer, carries the port rails"),
        ramp(-0.8, 0.8, 0.9, 2.0, -11.4, -9.8, "primary", note="pylon nose: runs down to meet the nose shell"),
        cz(0, y, -10.0, -8.6, d, "secondary", note="intake lip"),
        cz(0, y, -8.6, -4.2, d, "primary", note="one long smooth turbine, 2.8 across"),
        cz(0, y, -10.5, -10.0, 1.7, "detail", note="spike cone base"),
        cz(0, y, -11.0, -10.5, 1.1, "secondary", note="spike cone"),
        ball(0, y, -11.0, 0.8, "secondary", note="spike tip"),
        cz(0, y, -4.2, -3.1, 2.3, "detail", note="tail cone"),
        cz(0, y, -3.1, -2.3, 1.9, "thrust", note="burner band"),
        tube((0, y, -2.4), (0, 2.2, -0.5), 1.1, "secondary", note="jet pipe slopes down to the firewall"),
        box(1.36, 1.5, 3.05, 3.35, -8.8, -4.8, "secondary", m=True, note="strake"),
        ramp(-0.1, 0.1, 4.55, 5.3, -6.6, -4.4, "secondary", note="dorsal fin"),
    ]
    return ps


# ---------------------------------------------------------------- Boost: the headers
def flange():
    return [box(2.8, 3.0, 1.3, 2.1, PORT[4], PORT[5], "detail", m=True, note="header flange on the port rail")]


def bo_zoomies():
    ps = flange()
    for z in (-6.9, -5.95, -5.0, -4.05):
        ps += nozzle((3.0, 1.7, z), (4.6, 3.3, z + 2.4), 0.8, 0.4, "primary", m=True, note="zoomie: swept out and back, clear of the engine in the front view", glow=0.9)
    return ps


def bo_lake_pipes():
    ps = flange()
    for z in (-6.9, -5.95, -5.0, -4.05):
        ps.append(tube((3.0, 1.7, z), (3.9, 1.25, z + 0.5), 0.45, "detail", m=True, note="primary"))
    ps.append(cz(3.95, 1.2, -8.4, -1.4, 1.0, "secondary", m=True, note="long lake pipe"))
    ps += nozzle((3.95, 1.2, -1.5), (4.85, 1.2, -0.2), 1.3, 0.35, "detail", m=True, note="megaphone, turned out clear of the side jet", glow=0.9)
    return ps


def bo_side_dumps():
    """Two swept pipes a side, low and side by side, angled 32 degrees out and back. Megaphones twice as long as wide."""
    ps = flange()
    ps.append(box(3.0, 3.7, 0.9, 2.1, -7.0, -4.0, "detail", m=True, note="collector"))
    s, c = math.sin(math.radians(32)), math.cos(math.radians(32))
    for y, z in ((1.4, -6.7), (1.4, -4.3)):
        a = (3.5, y, z)
        b = (a[0] + 1.3 * s, y, z + 1.3 * c)
        e = (a[0] + 3.9 * s, y, z + 3.9 * c)
        ps.append(tube(a, b, 0.8, "detail", m=True, note="swept pipe"))
        ps.append(tube(b, e, 1.25, "primary", m=True, note="megaphone: 2.6 long, 1.25 across"))
        ps.append(tube(e, extend(b, e, 0.3), 1.15, "thrust", m=True))
    return ps


def bo_slot_burners():
    ps = flange()
    ps += [
        box(3.0, 4.1, 1.0, 2.3, -7.6, -1.8, "primary", m=True, note="flat faired burner pod"),
        taper(3.0, 4.1, 1.0, 2.3, -7.6, -8.9, "primary", m=True, note="nose"),
        taper(3.0, 4.1, 1.0, 2.3, -1.8, -0.3, "detail", m=True, note="tail"),
        box(4.1, 4.22, 1.3, 2.0, -4.6, -2.0, "thrust", m=True, note="side slot burner"),
        box(3.0, 4.1, 2.3, 2.38, -7.4, -2.0, "secondary", m=True, note="stripe"),
    ]
    return ps


def bo_staged_stacks():
    """Three stacks a side in rising steps, leaning 30 degrees outward. Painted primary; they carry the tip glows."""
    ps = flange()
    ps.append(box(3.0, 4.4, 1.2, 2.0, -7.4, -3.4, "detail", m=True, note="collector log"))
    s, c = math.sin(math.radians(30)), math.cos(math.radians(30))
    for z, length in ((-6.8, 1.6), (-5.4, 2.5), (-4.0, 3.4)):
        a = (3.8, 1.9, z)
        b = (a[0] + length * s, a[1] + length * c, z)
        ps += nozzle(a, b, 1.2, 0.3, "primary", m=True, note="staged stack, leaning out", glow=0.85)
    return ps


# ---------------------------------------------------------------- SidePods: rail dress (raked with the frame)
def sp_nerf_rails():
    ps = [cz(4.5, 0.1, -8.6, 0.6, 0.55, "secondary", m=True, note="nerf rail")]
    for z in (-8.0, -4.0, 0.0):
        ps.append(cx(0.1, z, 3.15, 4.4, 0.3, "detail", m=True, note="stand-off"))
    return rake(ps)


def sp_running_boards():
    ps = [
        box(3.2, 5.4, -0.45, -0.2, -8.8, 0.8, "primary", m=True, note="running board"),
        box(5.4, 5.55, -0.5, -0.15, -8.8, 0.8, "secondary", m=True, note="edge trim"),
        box(3.8, 4.0, -0.2, -0.14, -8.2, 0.2, "detail", m=True, note="tread strip"),
        box(4.6, 4.8, -0.2, -0.14, -8.2, 0.2, "detail", m=True),
    ]
    for z in (-7.5, -4.0, -0.5):
        ps.append(box(3.15, 3.5, -0.2, 0.25, z - 0.25, z + 0.25, "detail", m=True, note="bracket"))
    return rake(ps)


def sp_saddle_tanks():
    ps = [
        cz(4.2, -0.3, -7.0, -1.5, 1.6, "secondary", m=True, note="saddle tank"),
        ball(4.2, -0.3, -7.0, 1.5, "secondary", m=True),
        ball(4.2, -0.3, -1.5, 1.5, "secondary", m=True),
        box(3.15, 5.05, -1.15, 0.55, -6.0, -5.7, "detail", m=True, note="strap and bracket"),
        box(3.15, 5.05, -1.15, 0.55, -2.8, -2.5, "detail", m=True),
        cy(4.2, -4.2, 0.5, 0.6, 0.4, "detail", m=True, note="filler"),
    ]
    return rake(ps)


def sp_delta_strakes():
    ps = [
        taper(3.2, 5.8, -0.1, 0.08, 0.7, -5.0, "primary", m=True, note="delta strake"),
        box(5.7, 5.85, -0.5, 0.5, -0.9, 0.8, "secondary", m=True, note="tip plate"),
        box(3.15, 3.4, -0.2, 0.2, -1.0, 0.6, "detail", m=True, note="root bracket"),
    ]
    return rake(ps)


def sp_belly_skirts():
    ps = [
        box(3.25, 3.5, -1.3, 0.5, -7.4, 0.8, "primary", m=True, note="belly skirt"),
        ramp(3.25, 3.5, -1.3, 0.5, -9.0, -7.4, "primary", m=True, under=True, note="skirt nose"),
        box(3.5, 3.56, -0.5, -0.2, -7.2, 0.6, "secondary", m=True, note="stripe"),
    ]
    return rake(ps)


# ---------------------------------------------------------------- Engine2: long jet barrels beside the cab
def pylons(x_in, y0=PAD_Y - 0.4, y1=PAD_Y + 0.4):
    return [box(3.5, x_in, y0, y1, z - 0.5, z + 0.5, "detail", m=True, note="pylon on the barrel pad") for z in PAD_Z]


def spike(x, y, z_face, d_body, ch="secondary", length=0.9):
    """Shock-cone intake on the flat front face of a barrel: dark throat, coloured centre-body."""
    d = d_body * 0.44
    return [
        cz(x, y, z_face - 0.1, z_face, min(1.75, d_body * 0.7), "detail", m=True, note="intake throat"),
        cz(x, y, z_face - length, z_face, d, ch, m=True, note="intake spike"),
        ball(x, y, z_face - length, d, ch, m=True),
    ]


def e2_long_barrels():
    """Round, slim and as long as the envelope allows: 2.4 across, 11.9 long, carried low."""
    x, y, d = 5.0, 1.4, 2.4
    ps = pylons(3.9) + spike(x, y, 2.9, d, length=0.8)
    ps += [
        cz(x, y, 2.9, 6.6, d, "primary", m=True, note="long round barrel"),
        cz(x, y, 6.6, 8.2, d, "secondary", m=True, note="accent band"),
        cz(x, y, 8.2, 11.6, d, "primary", m=True),
        cz(x, y, 11.6, 12.7, 1.9, "detail", m=True, note="nozzle"),
        cz(x, y, 12.7, 13.4, 1.5, "thrust", m=True),
        box(x - 0.1, x + 0.1, 2.5, 3.0, 8.6, 11.4, "secondary", m=True, note="spine fin"),
    ]
    return ps


def e2_stub_ramjets():
    """Square-section box ramjets, 2.4 by 2.4 by 7 long, carried at beltline height on tall pylons. Wedge ramp intake, square slot nozzle."""
    x0, x1, y0, y1 = 3.8, 6.2, 2.1, 4.5
    ps = [box(3.5, 4.9, 0.9, y0, z - 0.5, z + 0.5, "detail", m=True, note="tall pylon on the barrel pad") for z in PAD_Z]
    ps += [
        ramp(x0 + 0.15, x1 - 0.15, y0, y1 - 0.2, 3.3, 5.1, "detail", m=True, note="wedge ramp inside the intake"),
        box(x0, x0 + 0.15, y0, y1, 3.5, 5.1, "primary", m=True, note="intake cheek"),
        box(x1 - 0.15, x1, y0, y1, 3.5, 5.1, "primary", m=True, note="intake cheek"),
        box(x0, x1, y1 - 0.2, y1, 3.5, 5.1, "secondary", m=True, note="intake lip"),
        box(x0, x1, y0, y1, 5.1, 9.0, "primary", m=True, note="square box ramjet, carried high"),
        box(x0 - 0.05, x1 + 0.05, y0 - 0.05, y1 + 0.05, 6.3, 7.3, "secondary", m=True, note="band"),
        box(x0 + 0.2, x1 - 0.2, y0 + 0.2, y1 - 0.2, 9.0, 9.9, "detail", m=True, note="square nozzle"),
        box(x0 + 0.4, x1 - 0.4, y0 + 0.4, y1 - 0.4, 9.9, 10.3, "thrust", m=True, note="square glow, 1.6 by 1.6"),
    ]
    return ps


def e2_over_unders():
    x = 4.5
    ps = [box(3.5, 5.4, PAD_Y - 0.3, PAD_Y + 0.3, z - 0.5, z + 0.5, "detail", m=True, note="clamp on the barrel pad") for z in PAD_Z]
    for y, z0, z1, ch in ((0.3, 3.0, 11.6, "secondary"), (2.5, 2.4, 9.8, "primary")):
        ps += [
            cz(x, y, z0, z1, 1.6, ch, m=True, note="stacked barrel"),
            cz(x, y, z0 - 0.1, z0, 1.15, "detail", m=True, note="intake throat"),
            ball(x, y, z0 - 0.15, 0.75, "primary" if ch == "secondary" else "secondary", m=True, note="intake spike"),
            cz(x, y, z1, z1 + 0.9, 1.3, "detail", m=True, note="nozzle"),
            cz(x, y, z1 + 0.9, z1 + 1.4, 1.0, "thrust", m=True),
        ]
    return ps


def e2_lances():
    x, y = 4.6, 1.4
    ps = pylons(3.8)
    ps += [
        cz(x, y, 2.6, 11.4, 1.7, "primary", m=True, note="slim lance"),
        cz(x, y, 1.6, 2.6, 0.9, "secondary", m=True, note="needle intake"),
        cz(x, y, 5.6, 7.0, 1.76, "secondary", m=True, note="band"),
        cz(x, y, 11.4, 12.6, 2.0, "detail", m=True, note="flared nozzle"),
        cz(x, y, 12.6, 13.3, 1.5, "thrust", m=True),
        box(x - 0.1, x + 0.1, 2.25, 3.9, 10.2, 12.4, "secondary", m=True, note="tail fin"),
        ramp(x - 0.1, x + 0.1, 2.25, 3.9, 8.6, 10.2, "secondary", m=True),
    ]
    return ps


def e2_slab_pods():
    """Flat slab pods carried low: open intake mouth, raised dorsal scoop, wide slot nozzle."""
    ps = pylons(3.75, 0.9, 1.5)
    ps += [
        box(3.7, 6.6, 0.4, 1.8, 3.6, 11.6, "primary", m=True, note="flat slab pod, carried low"),
        box(3.7, 6.6, 0.4, 0.65, 2.4, 3.6, "primary", m=True, note="lower intake lip, run forward"),
        box(3.7, 6.6, 1.55, 1.8, 3.0, 3.6, "secondary", m=True, note="upper intake lip"),
        box(3.7, 3.9, 0.65, 1.55, 3.0, 3.6, "primary", m=True, note="intake wall"),
        box(6.4, 6.6, 0.65, 1.55, 3.0, 3.6, "primary", m=True, note="intake wall"),
        box(3.9, 6.4, 0.65, 1.55, 3.4, 3.6, "detail", m=True, note="intake mouth"),
        box(4.4, 5.9, 1.8, 2.5, 5.2, 7.0, "secondary", m=True, note="dorsal scoop"),
        box(4.55, 5.75, 1.9, 2.4, 5.1, 5.2, "detail", m=True, note="scoop mouth"),
        ramp(4.4, 5.9, 1.8, 2.5, 8.6, 7.0, "secondary", m=True),
        box(3.8, 6.5, 0.5, 1.7, 11.6, 12.4, "detail", m=True, note="nozzle shroud"),
        box(4.0, 6.3, 0.65, 1.55, 12.4, 12.8, "thrust", m=True, note="slot nozzle, 2.3 by 0.9"),
        box(3.9, 6.4, 1.8, 1.86, 8.8, 11.4, "secondary", m=True, note="stripe"),
    ]
    return ps


# ---------------------------------------------------------------- Stabilisers: lift-jet pods on the front beam axle
AX_Y = -1.65


def perch():
    return [box(RAIL[0], RAIL[1], PERCH_TOP - 0.28, PERCH_TOP, PERCH_Z - 0.4, PERCH_Z + 0.4, "detail", m=True, note="axle perch under the rail")]


def st_beam_lifters():
    """One tall upright lift can a side on a tube axle."""
    ps = perch()
    ps += [
        cx(AX_Y, -12.0, -4.6, 4.6, 0.5, "secondary", note="tube beam axle"),
        tube((3.4, AX_Y, -11.9), (3.3, -1.5, -9.7), 0.25, "detail", m=True, note="hairpin"),
        cy(5.3, -12.0, -1.3, 0.9, 1.4, "primary", m=True, note="tall upright lift can"),
        cy(5.3, -12.0, 0.9, 1.5, 1.5, "thrust", m=True, note="burner band under the intake cap: glows from above and from the front"),
        cy(5.3, -12.0, 1.5, 2.3, 1.7, "secondary", m=True, note="intake cap"),
        cy(5.3, -12.0, 2.3, 2.4, 1.2, "detail", m=True, note="intake throat"),
        box(6.05, 6.65, -0.7, 0.8, -12.1, -11.9, "secondary", m=True, note="steering vane"),
    ]
    ps += lift_nozzle(5.3, -1.3, -12.0, 1.3, 20, 0.4, 0.3)
    return ps


def st_torpedoes():
    """One long horizontal pod a side with two tilted down nozzles and a burner band between them."""
    y = -0.9
    ps = perch()
    ps += [
        box(-4.4, 4.4, -1.85, -1.5, -12.25, -11.75, "detail", note="I-beam axle"),
        box(-2.2, 2.2, -1.5, -1.3, -12.2, -11.8, "secondary", note="transverse leaf spring"),
        cz(5.0, y, -15.2, -13.0, 1.5, "primary", m=True, note="long torpedo pod"),
        cz(5.0, y, -13.0, -12.2, 1.6, "thrust", m=True, note="burner band: glows from above and from the front"),
        cz(5.0, y, -12.2, -10.4, 1.5, "primary", m=True),
        ball(5.0, y, -15.25, 1.2, "secondary", m=True, note="nose"),
        cz(5.0, y, -10.4, -9.7, 1.1, "secondary", m=True),
    ]
    for z in (-14.0, -11.2):
        ps += lift_nozzle(5.3, -1.35, z, 1.0, 25, 0.45, 0.3)
    return ps


def st_quad_cans():
    """Two cans a side splayed in a V, leaning 36 degrees out from a shared manifold on the axle end."""
    ps = perch()
    zc = -12.4
    ps += [
        cx(AX_Y, zc, -4.7, 4.7, 0.5, "detail", note="dropped tube axle"),
        box(4.4, 5.6, -1.7, -0.9, zc - 0.9, zc + 0.9, "detail", m=True, note="shared manifold on the axle end"),
    ]
    for sgn in (-1.0, 1.0):
        a, b = (5.0, -1.1, zc + sgn * 0.45), (5.5, 1.3, zc + sgn * 2.1)
        ps += [
            tube(a, b, 1.1, "secondary", m=True, note="splayed lift can, two a side in a V"),
            tube(along(a, b, 0.66), along(a, b, 0.84), 1.25, "thrust", m=True, note="burner band"),
            tube(b, extend(a, b, 0.4), 1.4, "primary", m=True, note="intake cap"),
            tube(extend(a, b, 0.4), extend(a, b, 0.48), 0.95, "detail", m=True, note="intake throat"),
        ]
        ps += lift_nozzle(5.15, -1.6, zc + sgn * 0.45, 0.9, 25, 0.25, 0.25)
    return ps


def st_canard_vanes():
    """A canard vane a side with a 1.4 by 5.5 tip jet and a tilted down nozzle under the vane root."""
    y = -1.3
    ps = perch()
    ps += [
        cx(AX_Y, -12.0, -4.0, 4.0, 0.4, "detail", note="thin tube axle"),
        part("block", [2.3, 0.3, 2.6], [4.75, y, -12.2], "primary", [-6, 0, 0], m=True, note="canard vane"),
        cz(6.25, y, -14.4, -12.6, 1.4, "secondary", m=True, note="tip jet, 1.4 across"),
        cz(6.25, y, -12.6, -11.9, 1.5, "thrust", m=True, note="burner band: glows from above and from the front"),
        cz(6.25, y, -11.9, -10.8, 1.4, "secondary", m=True),
        cz(6.25, y, -14.9, -14.4, 0.9, "primary", m=True, note="intake cone"),
        ball(6.25, y, -14.9, 0.9, "primary", m=True),
        cz(6.25, y, -10.8, -10.2, 1.25, "detail", m=True, note="nozzle"),
        cz(6.25, y, -10.2, -9.8, 1.1, "thrust", m=True),
    ]
    ps += lift_nozzle(4.2, -1.4, -12.2, 1.15, 25, 0.35, 0.3, note="root lift nozzle, tilted out")
    return ps


def st_faired_spats():
    """A long low spat blade a side with a raked lift-jet can run through it: the can shows above, below and on both faces."""
    ps = perch()
    a, b = (5.35, -1.45, -12.4), (5.35, 1.6, -11.6)
    ps += [
        box(-4.9, 4.9, -1.75, -1.45, -12.6, -11.4, "primary", note="blade axle"),
        box(4.9, 5.8, -1.7, 0.5, -13.2, -10.9, "primary", m=True, note="spat blade: lower than the can"),
        taper(4.9, 5.8, -1.7, 0.5, -13.2, -15.4, "primary", m=True, note="spat nose"),
        taper(4.9, 5.8, -1.7, 0.5, -10.9, -9.6, "primary", m=True, note="spat tail"),
        tube(a, along(a, b, 0.72), 1.5, "secondary", m=True, note="lift-jet can through the spat, raked back"),
        tube(along(a, b, 0.72), along(a, b, 0.88), 1.6, "thrust", m=True, note="burner band above the blade"),
        tube(along(a, b, 0.88), b, 1.5, "secondary", m=True),
        tube(b, extend(a, b, 0.45), 1.75, "secondary", m=True, note="intake cap"),
        tube(extend(a, b, 0.45), extend(a, b, 0.53), 1.2, "detail", m=True, note="intake throat"),
        tube(a, extend(b, a, 0.3), 1.4, "detail", m=True, note="nozzle under the blade"),
        tube(extend(b, a, 0.3), extend(b, a, 0.6), 1.2, "thrust", m=True),
        box(5.8, 5.86, -0.9, -0.5, -13.0, -11.0, "secondary", m=True, note="stripe"),
    ]
    return ps


# ---------------------------------------------------------------- RearBody: the tail behind the cab
def ring(z1=10.4):
    """The first ring of every Tail: exactly the cab's tail collar section, 0.15 behind the bulkhead."""
    kw, ky0, ky1 = COLLAR
    return [box(-kw, kw, ky0, ky1, 10.1, z1, "primary", note="first ring: the common 4.0 by 2.4 collar section")]


def rb_turtle_deck():
    """Long deck at the collar width, falling all the way to the tail, with low aprons over the horns."""
    ps = ring(10.5)
    ps += [
        box(-2.0, 2.0, 0.7, 1.7, 10.5, 13.4, "primary", note="turtle deck"),
        ramp(-2.0, 2.0, 1.7, 3.2, 13.4, 10.5, "primary", note="deck falls from the collar top to the tail"),
        box(2.0, 3.1, 0.65, 1.3, 11.6, 13.4, "primary", m=True, note="low apron over the horn"),
        taper(2.0, 3.1, 0.65, 1.3, 11.6, 10.3, "primary", m=True, note="apron grows out of the collar"),
        box(2.2, 2.9, 0.75, 1.2, 13.4, 13.5, "neon", m=True, note="tail lamp"),
        box(-0.8, 0.8, 0.9, 1.5, 13.4, 13.48, "secondary", note="plate"),
        box(-0.12, 0.12, 1.75, 3.25, 10.6, 10.9, "secondary", note="deck spine"),
    ]
    return ps


def rb_trunk():
    """Tall upright trunk, as wide as the collar, on a luggage rack."""
    ps = ring(10.4)
    ps += [
        box(-1.6, 1.6, 1.0, 3.0, 10.4, 10.6, "detail", note="shadow gap bracket"),
        box(2.3, 2.9, 0.62, 0.85, 10.1, 13.3, "detail", m=True, note="luggage rack rail on the horn"),
        box(-2.3, 2.3, 0.62, 0.85, 11.0, 11.3, "detail", note="rack bar"),
        box(-2.3, 2.3, 0.62, 0.85, 12.6, 12.9, "detail"),
        box(-1.9, 1.9, 0.85, 3.7, 10.6, 13.0, "primary", note="tall upright trunk"),
        box(-1.95, 1.95, 3.7, 4.0, 10.55, 13.05, "secondary", note="lid"),
        box(0.9, 1.2, 0.83, 4.04, 10.52, 13.08, "secondary", m=True, note="strap"),
        box(-0.3, 0.3, 2.2, 2.6, 13.0, 13.1, "neon", note="latch lamp"),
    ]
    return ps


def rb_bobber_bed():
    """Short open bed: the collar section is its front panel."""
    ps = ring(10.4)
    ps += [
        box(-2.3, 2.3, 0.7, 0.9, 10.4, 12.3, "detail", note="bed floor"),
        box(2.0, 2.3, 0.9, 2.7, 10.4, 12.3, "primary", m=True, note="bed side"),
        box(-2.0, 2.0, 0.9, 2.1, 12.1, 12.3, "primary", note="tailgate"),
        box(2.0, 2.3, 2.7, 4.3, 10.4, 10.7, "secondary", m=True, note="stake post"),
        box(2.0, 2.3, 2.7, 3.5, 12.0, 12.3, "secondary", m=True),
        box(-1.6, -0.4, 0.9, 2.9, 10.7, 11.5, "secondary", note="fuel cans"),
        box(0.2, 1.8, 0.9, 1.9, 10.7, 11.8, "detail", note="toolbox"),
    ]
    return ps


def rb_chute_tail():
    """Tapers in plan from the collar to a narrow point, chute tube on top."""
    ps = ring(10.4)
    ps += [
        box(-0.9, 0.9, 0.8, 2.6, 10.4, 12.0, "primary", note="narrow tank"),
        taper(0.9, 2.0, 0.8, 2.6, 10.4, 12.8, "primary", m=True, note="plan taper from the collar width to the tank"),
        ramp(-0.9, 0.9, 0.8, 2.6, 13.3, 12.0, "primary"),
        cz(0, 3.1, 10.4, 12.8, 1.0, "secondary", note="chute tube"),
        cz(0, 3.1, 12.8, 13.0, 0.7, "detail", note="chute cap"),
        tube((2.6, 0.7, 13.1), (0.9, 1.5, 12.2), 0.25, "detail", m=True, note="strut to the horns"),
    ]
    return ps


def rb_boat_tail():
    """The collar section, then an oval that tapers to a point. Saddle fairings run down to the horns."""
    ps = ring(10.4)
    ps += oval(10.4, 11.6, 3.8, 2.4, 2.0, "primary", note="boat tail: finishes the teardrop")
    ps += oval(11.6, 12.5, 2.9, 1.9, 2.0, "primary")
    ps += [
        cz(0, 2.0, 12.5, 13.0, 1.4, "primary"),
        cz(0, 2.0, 13.0, 13.3, 0.9, "secondary"),
        cz(0, 2.0, 13.3, 13.45, 0.6, "neon", note="tail lamp"),
        xramp(3.0, 2.0, 0.62, 1.9, 10.2, 11.6, "primary", m=True, note="saddle fairing down to the horn"),
        box(-2.9, 2.9, 0.62, 0.85, 11.6, 11.9, "detail", note="cradle on the horns"),
    ]
    return ps


# ---------------------------------------------------------------- RearSpoiler: the rear rig on the rig bar
def rs_roll_bar():
    x = RIG_X
    ps = [
        tube((x, 4.65, 10.3), (x, 6.6, 10.6), 0.4, "secondary", m=True, note="roll bar post on the rig bar"),
        cx(6.6, 10.6, -x - 0.2, x + 0.2, 0.4, "secondary"),
        box(-0.6, 0.6, 5.5, 6.4, 10.75, 10.95, "detail", note="head pad"),
        cz(1.1, 7.05, 10.2, 11.0, 0.5, "secondary", m=True, note="marker lamp"),
        cz(1.1, 7.05, 11.0, 11.1, 0.4, "neon", m=True),
    ]
    return ps


def rs_twin_fins():
    x = RIG_X
    ps = [
        box(x - 0.2, x + 0.2, 4.65, 4.9, 10.05, 12.0, "detail", m=True, note="fin foot on the rig bar"),
        ramp(x - 0.1, x + 0.1, 4.9, 7.4, 10.2, 11.8, "primary", m=True, note="fin leading edge"),
        box(x - 0.1, x + 0.1, 4.9, 7.4, 11.8, 13.4, "primary", m=True, note="fin"),
        box(x - 0.15, x + 0.15, 7.4, 7.6, 11.8, 13.5, "secondary", m=True, note="fin cap"),
    ]
    return ps


def rs_headache_rack():
    ps = [
        box(2.1, 2.4, 4.65, 6.6, 10.1, 10.4, "detail", m=True, note="rack post"),
        box(-2.4, 2.4, 6.6, 6.9, 10.1, 10.4, "detail"),
        box(-2.2, 2.2, 4.65, 4.8, 10.05, 12.6, "secondary", note="shelf on the rig bar"),
        box(-1.9, -0.7, 4.8, 6.0, 11.0, 12.2, "primary", note="strapped can"),
        cz(1.6, 7.25, 10.05, 10.9, 0.6, "secondary", m=True, note="lamp"),
        cz(1.6, 7.25, 10.9, 11.0, 0.45, "neon", m=True),
    ]
    for x in (-1.2, 0.0, 1.2):
        ps.append(box(x - 0.1, x + 0.1, 4.8, 6.6, 10.15, 10.35, "secondary", note="slat"))
    return ps


def rs_dragster_wing():
    x = RIG_X
    ps = [
        tube((x, 4.7, 10.25), (x, 8.3, 12.7), 0.3, "detail", m=True, note="front strut on the rig bar"),
        tube((x, 4.7, 10.25), (x, 8.2, 14.4), 0.3, "detail", m=True, note="rear strut"),
        cx(6.4, 11.4, -x, x, 0.25, "detail"),
        part("block", [9.0, 0.25, 2.6], [0, 8.5, 13.6], "primary", [-6, 0, 0], note="high wing"),
        box(4.5, 4.7, 7.7, 9.3, 12.2, 15.0, "secondary", m=True, note="end plate"),
        box(-4.5, 4.5, 8.75, 9.0, 14.6, 14.8, "secondary", note="gurney"),
    ]
    return ps


def rs_tail_fin():
    ps = [
        box(-1.8, 1.8, 4.65, 4.85, 10.05, 10.5, "detail", note="fin foot on the rig bar"),
        box(-0.3, 0.3, 4.85, 5.2, 10.2, 14.8, "secondary", note="spine"),
        ramp(-0.15, 0.15, 5.2, 7.8, 10.3, 12.2, "primary", note="fin leading edge"),
        box(-0.15, 0.15, 5.2, 7.8, 12.2, 13.6, "primary", note="tall centre fin"),
        box(-0.2, 0.2, 7.8, 8.0, 12.0, 13.8, "secondary", note="fin cap"),
    ]
    return ps


# ---------------------------------------------------------------- bumpers
def rear_brackets(z1=14.2):
    return [box(2.4, 2.8, -0.2, 0.4, 13.55, z1, "detail", m=True, note="bracket on the rear horn")]


def rbu_nerf_bar():
    ps = rear_brackets(14.3)
    ps += [
        cx(0.1, 14.5, -3.0, 3.0, 0.5, "secondary", note="nerf bar"),
        cy(1.6, 14.5, -0.4, 1.0, 0.4, "secondary", m=True, note="overrider"),
        cz(2.4, 0.75, 14.2, 15.0, 0.6, "detail", m=True, note="tail lamp"),
        cz(2.4, 0.75, 15.0, 15.1, 0.5, "neon", m=True),
    ]
    return ps


def rbu_lantern():
    ps = rear_brackets(14.1)
    ps += [
        box(-2.9, 2.9, -0.1, 0.3, 14.1, 14.4, "secondary", note="flat bar"),
        box(-0.2, 0.2, 0.0, 0.3, 14.4, 15.1, "detail"),
        cy(0, 14.9, 0.3, 1.5, 0.7, "secondary", note="centre lantern"),
        cy(0, 14.9, 0.7, 1.1, 0.8, "neon"),
    ]
    return ps


def rbu_hitch():
    ps = rear_brackets(14.2)
    ps += [
        box(-2.9, 2.9, -0.2, 0.3, 13.9, 14.2, "detail"),
        box(-0.4, 0.4, -0.3, 0.2, 13.55, 15.6, "detail", note="drawbar"),
        ball(0, 0.55, 15.3, 0.7, "secondary", note="hitch ball"),
        part("block", [4.4, 0.15, 1.6], [0, -0.9, 14.7], "primary", [20, 0, 0], note="skid plate"),
        box(1.2, 1.5, -0.6, 0.2, 14.2, 14.5, "secondary", m=True, note="chain hook"),
    ]
    return ps


def rbu_skid_bars():
    ps = rear_brackets(14.0)
    ps += [
        tube((2.2, 0.0, 13.8), (2.2, -1.5, 16.1), 0.3, "secondary", m=True, note="long skid bar"),
        cx(-1.5, 16.1, -2.4, 2.4, 0.3, "secondary"),
        cx(-0.7, 14.9, -2.2, 2.2, 0.25, "detail"),
        ramp(2.0, 2.4, -1.95, -1.6, 16.45, 15.7, "detail", m=True, under=True, note="skid shoe"),
    ]
    return ps


def rbu_chute_pack():
    ps = rear_brackets(14.0)
    ps += [
        box(-2.4, 2.4, -0.2, 0.2, 13.6, 13.8, "detail", note="mount bar"),
        box(-1.6, 1.6, 0.2, 1.3, 13.6, 13.8, "detail", note="mount plate"),
        cz(0.75, 0.6, 13.8, 15.8, 1.2, "primary", m=True, note="chute tube"),
        cz(0.75, 0.6, 15.8, 16.0, 0.9, "secondary", m=True),
        box(0.65, 0.85, 1.2, 1.3, 14.6, 15.4, "neon", m=True, note="pull ribbon"),
    ]
    return ps


def front_brackets(z0=-15.2):
    return [box(2.4, 2.8, -0.2, 0.4, z0, -14.55, "detail", m=True, note="bracket on the front horn")]


def fbu_spreader():
    ps = front_brackets()
    ps += [
        cx(0.1, -15.4, -3.3, 3.3, 0.5, "secondary", note="spreader bar"),
        cy(1.2, -15.4, -0.5, 1.1, 0.4, "secondary", m=True, note="overrider"),
    ]
    return shift(ps, -NOSE_DROP)


def fbu_lantern_bar():
    ps = front_brackets()
    ps += [
        cx(0.1, -15.3, -3.2, 3.2, 0.4, "secondary", note="lamp bar"),
        cy(2.3, -15.3, 0.3, 1.9, 0.25, "detail", m=True),
        cz(2.3, 2.4, -15.9, -14.7, 1.0, "secondary", m=True, note="brass lantern"),
        cz(2.3, 2.4, -16.05, -15.9, 0.8, "neon", m=True),
    ]
    return shift(ps, -NOSE_DROP)


def fbu_cow_catcher():
    ps = front_brackets(-15.0)
    ps += [
        bar((0.1, -0.3, -16.25), (3.2, -0.3, -14.85), 0.2, 1.4, "primary", m=True, note="plough plate"),
        bar((0.1, 0.1, -16.36), (3.2, 0.1, -14.96), 0.12, 0.2, "secondary", m=True, note="rib"),
        box(-0.2, 0.2, -1.0, 0.7, -16.45, -16.1, "secondary", note="prow post"),
    ]
    return shift(ps, -NOSE_DROP)


def fbu_stage_prong():
    ps = front_brackets(-14.9)
    ps += [
        box(-2.8, 2.8, -0.1, 0.3, -14.9, -14.6, "detail"),
        cz(0, 0.1, -16.45, -14.9, 0.45, "secondary", note="staging prong"),
        taper(0.2, 1.8, 0.0, 0.15, -14.9, -16.2, "primary", m=True, note="canard plate"),
    ]
    return shift(ps, -NOSE_DROP)


def fbu_needle_nose():
    ps = front_brackets(-14.9)
    ps += [
        taper(0, 2.8, 0.4, 0.7, -14.6, -16.4, "primary", m=True, note="arrowhead nose plate: carries the nose ramp to a point"),
        ramp(-0.35, 0.35, 0.7, 1.25, -16.2, -14.6, "secondary", note="centre ridge"),
    ]
    return shift(ps, -NOSE_DROP)


# ---------------------------------------------------------------- the frame standard
def mbox(x0, x1, y0, y1, z0, z1, mirror=False):
    b = {"min": [x0, y0, z0], "max": [x1, y1, z1]}
    if mirror:
        b["mirror"] = True
    return b


STANDARD = {
    "cockpitEnvelope": [mbox(-3.25, 3.25, -0.9, 6.4, Z_FIRE, Z_BACK), mbox(-3.25, 3.25, -0.9, SILL, Z_BACK, Z_HORN_R)],
    "datums": {"beltline": BELT, "sill": SILL, "hoverPlane": HOVER, "firewall": Z_FIRE, "grillePlane": Z_GRILLE,
               "cabBack": Z_BACK, "frontHorn": Z_HORN_F, "rearHorn": Z_HORN_R, "rakeDegrees": round(RAKE_DEG, 2)},
    "slots": {
        "FrontBody": {"label": "Frame and Shell",
                      "envelope": [mbox(-3.1, 3.1, -1.25, SILL, Z_HORN_F, -9.5),
                                   mbox(-3.1, 3.1, -1.9, SILL, -9.5, Z_FIRE),
                                   mbox(-3.6, 3.6, SILL, 4.4, Z_HORN_F, Z_GRILLE)],
                      "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, -3, -5]},
        "Engine1": {"label": "Front Engine", "envelope": mbox(-2.7, 2.7, SILL, 6.4, Z_GRILLE, Z_FIRE),
                    "anchor": [{"to": "cockpit", "face": "+z"}, {"to": "FrontBody", "face": "-y"}], "explode": [0, 5, -5]},
        "Engine2": {"label": "Side Jets", "envelope": mbox(3.5, 6.6, -1.8, 4.6, 1.5, Z_HORN_R, True),
                    "anchor": {"to": "cockpit", "face": "-x"}, "explode": [5, 0, 2]},
        "Stabilisers": {"label": "Axle Jets",
                        "envelope": [mbox(-3.6, 3.6, -2.1, -1.25, -13.5, -9.5), mbox(3.6, 7.0, -2.3, 3.2, -16.0, -9.5, True)],
                        "anchor": {"to": "FrontBody", "face": "+y"}, "explode": [0, -6, -7]},
        "Boost": {"label": "Headers", "envelope": mbox(2.7, 6.4, SILL, 5.8, -9.0, Z_FIRE, True),
                  "anchor": {"to": "Engine1", "face": "-x"}, "explode": [5, 5, -5]},
        "SidePods": {"label": "Rail Dress", "envelope": mbox(3.1, 6.5, -2.0, SILL, -9.0, Z_FIRE, True),
                     "anchor": {"to": "FrontBody", "face": "-x"}, "explode": [5, -4, -5]},
        "RearBody": {"label": "Tail", "envelope": mbox(-3.25, 3.25, SILL, 4.6, Z_BACK, Z_HORN_R),
                     "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 1, 6]},
        "FrontBumper": {"label": "Nose Gear", "envelope": mbox(-3.6, 3.6, -2.2, 3.6, Z_NOSE, Z_HORN_F),
                        "anchor": {"to": "FrontBody", "face": "+z"}, "explode": [0, -3, -10]},
        "RearBumper": {"label": "Launch Gear", "envelope": mbox(-4.5, 4.5, -2.0, 3.0, Z_HORN_R, Z_TAIL),
                       "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, -3, 9]},
        "RearSpoiler": {"label": "Rear Rig", "envelope": mbox(-5.5, 5.5, 4.6, 9.6, Z_BACK, 15.5),
                        "anchor": {"to": "cockpit", "face": "-z"}, "explode": [0, 5, 7]},
    },
}

COCKPITS = {
    "deuce": {"name": "Deuce", "culture": "Highboy", "kit": "highboy", "parts": cab_deuce()},
    "bucket": {"name": "Bucket", "culture": "T-Bucket", "kit": "tbucket", "parts": cab_bucket()},
    "rat_cab": {"name": "Rat Cab", "culture": "Rat Rod", "kit": "ratrod", "parts": cab_rat()},
    "slingshot": {"name": "Slingshot", "culture": "Slingshot Drag", "kit": "drag", "parts": cab_slingshot()},
    "lakester": {"name": "Lakester", "culture": "Salt Flat", "kit": "salt", "parts": cab_lakester()},
}


def mod(name, culture, parts):
    return {"name": name, "culture": culture, "parts": parts}


# In every slot the options are listed in kit order: Highboy, T-Bucket, Rat Rod, Slingshot Drag, Salt Flat.
MODULES = {
    "Engine1": {
        "blown_turbine": mod("Blown Turbine", "Highboy", e1_blown_turbine()),
        "tunnel_ram": mod("Tunnel Ram", "T-Bucket", e1_tunnel_ram()),
        "flat_trio": mod("Flat Trio", "Rat Rod", e1_flat_trio()),
        "twin_mill": mod("Twin Mill", "Slingshot Drag", e1_twin_mill()),
        "turbine_swap": mod("Turbine Swap", "Salt Flat", e1_turbine_swap()),
    },
    "Engine2": {
        "long_barrels": mod("Long Barrels", "Highboy", e2_long_barrels()),
        "stub_ramjets": mod("Stub Ramjets", "T-Bucket", e2_stub_ramjets()),
        "over_unders": mod("Over-Unders", "Rat Rod", e2_over_unders()),
        "lances": mod("Lances", "Slingshot Drag", e2_lances()),
        "slab_pods": mod("Slab Pods", "Salt Flat", e2_slab_pods()),
    },
    "Stabilisers": {
        "beam_lifters": mod("Beam Lifters", "Highboy", st_beam_lifters()),
        "torpedoes": mod("Torpedoes", "T-Bucket", st_torpedoes()),
        "quad_cans": mod("Quad Cans", "Rat Rod", st_quad_cans()),
        "canard_vanes": mod("Canard Vanes", "Slingshot Drag", st_canard_vanes()),
        "faired_spats": mod("Faired Spats", "Salt Flat", st_faired_spats()),
    },
    "Boost": {
        "lake_pipes": mod("Lake Pipes", "Highboy", bo_lake_pipes()),
        "staged_stacks": mod("Staged Stacks", "T-Bucket", bo_staged_stacks()),
        "side_dumps": mod("Side Dumps", "Rat Rod", bo_side_dumps()),
        "zoomies": mod("Zoomies", "Slingshot Drag", bo_zoomies()),
        "slot_burners": mod("Slot Burners", "Salt Flat", bo_slot_burners()),
    },
    "FrontBody": {
        "deuce_shell": mod("Deuce Shell", "Highboy", fb_deuce_shell()),
        "track_nose": mod("Track Nose", "T-Bucket", fb_track_nose()),
        "rat_frame": mod("Rat Frame", "Rat Rod", fb_rat_frame()),
        "sling_rails": mod("Sling Rails", "Slingshot Drag", fb_sling_rails()),
        "salt_nose": mod("Salt Nose", "Salt Flat", fb_salt_nose()),
    },
    "RearBody": {
        "turtle_deck": mod("Turtle Deck", "Highboy", rb_turtle_deck()),
        "trunk": mod("Strapped Trunk", "T-Bucket", rb_trunk()),
        "bobber_bed": mod("Bobber Bed", "Rat Rod", rb_bobber_bed()),
        "chute_tail": mod("Chute Tail", "Slingshot Drag", rb_chute_tail()),
        "boat_tail": mod("Boat Tail", "Salt Flat", rb_boat_tail()),
    },
    "SidePods": {
        "nerf_rails": mod("Nerf Rails", "Highboy", sp_nerf_rails()),
        "running_boards": mod("Running Boards", "T-Bucket", sp_running_boards()),
        "saddle_tanks": mod("Saddle Tanks", "Rat Rod", sp_saddle_tanks()),
        "delta_strakes": mod("Delta Strakes", "Slingshot Drag", sp_delta_strakes()),
        "belly_skirts": mod("Belly Skirts", "Salt Flat", sp_belly_skirts()),
    },
    "FrontBumper": {
        "spreader": mod("Spreader Bar", "Highboy", fbu_spreader()),
        "lantern_bar": mod("Lantern Bar", "T-Bucket", fbu_lantern_bar()),
        "cow_catcher": mod("Cow Catcher", "Rat Rod", fbu_cow_catcher()),
        "stage_prong": mod("Stage Prong", "Slingshot Drag", fbu_stage_prong()),
        "needle_nose": mod("Needle Nose", "Salt Flat", fbu_needle_nose()),
    },
    "RearBumper": {
        "nerf_bar": mod("Nerf Bar", "Highboy", rbu_nerf_bar()),
        "lantern": mod("Tail Lantern", "T-Bucket", rbu_lantern()),
        "hitch": mod("Hitch", "Rat Rod", rbu_hitch()),
        "skid_bars": mod("Skid Bars", "Slingshot Drag", rbu_skid_bars()),
        "chute_pack": mod("Chute Pack", "Salt Flat", rbu_chute_pack()),
    },
    "RearSpoiler": {
        "roll_bar": mod("Roll Bar", "Highboy", rs_roll_bar()),
        "twin_fins": mod("Twin Fins", "T-Bucket", rs_twin_fins()),
        "headache_rack": mod("Headache Rack", "Rat Rod", rs_headache_rack()),
        "dragster_wing": mod("Dragster Wing", "Slingshot Drag", rs_dragster_wing()),
        "tail_fin": mod("Tail Fin", "Salt Flat", rs_tail_fin()),
    },
}

SLOT_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost", "FrontBody", "RearBody", "SidePods", "FrontBumper", "RearBumper", "RearSpoiler"]
KIT_ROW = {"highboy": 0, "tbucket": 1, "ratrod": 2, "drag": 3, "salt": 4}
KIT_META = {
    "highboy": ("Highboy", "Highboy"),
    "tbucket": ("T-Bucket", "T-Bucket"),
    "ratrod": ("Rat Rod", "Rat Rod"),
    "drag": ("Slingshot Drag", "Slingshot Drag"),
    "salt": ("Salt Flat", "Salt Flat"),
}
KITS = {}
for kid, row in KIT_ROW.items():
    KITS[kid] = {"name": KIT_META[kid][0], "culture": KIT_META[kid][1],
                 "modules": {s: list(MODULES[s].keys())[row] for s in SLOT_ORDER}}

PAINT = {
    "deuce": {"primary": "#b3122a", "secondary": "#e8dcc0", "neon": "#ffc247"},
    "bucket": {"primary": "#f08a1c", "secondary": "#d9b24a", "neon": "#fff2c0"},
    "rat_cab": {"primary": "#7a4a2b", "secondary": "#3f8f8a", "neon": "#ff7a1a"},
    "slingshot": {"primary": "#1e56d6", "secondary": "#e6e9ee", "neon": "#ff3df0"},
    "lakester": {"primary": "#cfd6da", "secondary": "#1d6fff", "neon": "#7fd0ff"},
}
SWAP = {"deuce": "salt", "bucket": "drag", "rat_cab": "highboy", "slingshot": "ratrod", "lakester": "tbucket"}

BUILDS = []
for cid, c in COCKPITS.items():
    BUILDS.append({"name": "%s, own %s kit" % (c["name"], KITS[c["kit"]]["name"]), "cockpit": cid, "kit": c["kit"], "paint": PAINT[cid]})
for cid, c in COCKPITS.items():
    BUILDS.append({"name": "%s, %s kit" % (c["name"], KITS[SWAP[cid]]["name"]), "cockpit": cid, "kit": SWAP[cid], "paint": PAINT[cid]})
BUILDS += [
    {"name": "Mixed: Deuce jet gasser", "cockpit": "deuce", "kit": "highboy",
     "modules": {"Engine1": "tunnel_ram", "Engine2": "over_unders", "Boost": "zoomies", "RearSpoiler": "dragster_wing", "RearBumper": "skid_bars"},
     "paint": {"primary": "#2f7d4f", "secondary": "#f0e6c8", "neon": "#eaff7a"},
     "note": "Highboy body with drag hardware."},
    {"name": "Mixed: Lakester twin-mill", "cockpit": "lakester", "kit": "salt",
     "modules": {"Engine1": "twin_mill", "Engine2": "lances", "Stabilisers": "canard_vanes", "Boost": "lake_pipes", "FrontBody": "sling_rails", "FrontBumper": "stage_prong"},
     "paint": {"primary": "#5b2a86", "secondary": "#f2c200", "neon": "#00e5ff"},
     "note": "Salt tank on drag rails."},
    {"name": "Mixed: Rat Cab show truck", "cockpit": "rat_cab", "kit": "ratrod",
     "modules": {"Engine1": "blown_turbine", "Engine2": "stub_ramjets", "Stabilisers": "faired_spats", "Boost": "staged_stacks", "SidePods": "running_boards", "FrontBody": "deuce_shell"},
     "paint": {"primary": "#101418", "secondary": "#d42a2a", "neon": "#ff5a36"},
     "note": "Every fundamental from a different kit."},
]

SPEC = {
    "id": "rodder",
    "displayName": "Rodder",
    "tagline": "Hot rods and drag rails on jet thrust: narrow cab at the back, exposed turbine on raked bare rails, long jet barrels beside the cab.",
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

    def count(parts):
        return sum(2 if p.get("mirror") else 1 for p in parts)

    print("wrote " + OUT)
    for cid, c in COCKPITS.items():
        print("  cockpit %-10s %3d parts" % (cid, count(c["parts"])))
    for s in SLOT_ORDER:
        print("  %-12s %s" % (s, ", ".join("%s %d" % (m, count(d["parts"])) for m, d in MODULES[s].items())))


if __name__ == "__main__":
    main()
