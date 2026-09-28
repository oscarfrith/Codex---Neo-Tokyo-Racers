"""P11 'Kasei Frame' - Metabolist Row, upper terrace (ground Y200), agent F.

A poor, lived-in Fuji-TV-style open frame: two slab towers (W top 680, E top 760) tied by three
sky trays (Y360-400, Y480-520, top beam Y640-680) with a steel sphere caught in the top cell.
Round service cores on the outer faces carry Nakagin-style capsule clusters. Street level is a
shuttered podium with graffiti, a market on the podium deck under the frame, exterior stairs,
laundry, AC units and patched/boarded window cells. 20/40-stud grid throughout.
Bridge landings: X2 portal on the W tower west face (z5060, deck Y400), X3 portal on the
E tower east face (z4960, deck Y470). The bridges themselves are X2.py / X3.py.
Run: py -3 P11.py  (writes P11.json next to this file)
"""
import sys, pathlib, random
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "common"))
from sgspec import Spec

s = Spec("P11", kind="building", title="Kasei Frame", lean="metabolist")
rnd = random.Random(1111)

G = 200
# ---- palette ----
C_LIGHT = (206, 203, 194)     # metabolist precast, grimy
C_WEATH = (170, 167, 158)     # weathered concrete
C_BAND = (150, 148, 141)      # tray bands
C_DARK = (34, 36, 40)         # openings
C_WIN = (196, 192, 184)       # window variant tint
C_ROOF = (120, 118, 112)


def box(name, x0, x1, y0, y1, z0, z1, mat="Concrete", var="", color=C_LIGHT, layer=None, shape="Block", **kw):
    return s.part(shape, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                  mat=mat, var=var, color=color, layer=layer, name=name, **kw)


def vcyl(name, x, z, y0, y1, dia, mat="Concrete", var="", color=C_LIGHT, layer=None):
    return s.part("Cylinder", (y1 - y0, dia, dia), (x, (y0 + y1) / 2, z), rot=(0, 0, 90), mat=mat, var=var,
                  color=color, layer=layer, name=name)


# footprint
PX0, PX1, PZ0, PZ1 = 630, 1030, 4800, 5200            # podium
WX0, WX1 = 630, 750                                   # west tower
EX0, EX1 = 910, 1030                                  # east tower
TZ0, TZ1 = 4820, 5180                                 # towers depth
W_TOP, E_TOP = 680, 760
PODIUM_TOP = 240

# =====================================================================  PODIUM
s.group("Podium")
box("PodiumMass", PX0, PX1, G, PODIUM_TOP, PZ0, PZ1, var="SG Weathered Concrete", color=C_WEATH)
box("PodiumParapetN", PX0, PX1, PODIUM_TOP, PODIUM_TOP + 4, PZ0, PZ0 + 2, color=C_WEATH)
box("PodiumParapetS", PX0, PX1, PODIUM_TOP, PODIUM_TOP + 4, PZ1 - 2, PZ1, color=C_WEATH)


def street_face(face, graffiti, shop_bays):
    """Shutter / shop bays (40 wide) with piers and a graffiti band on one podium face."""
    if face in ("N", "S"):
        z = PZ0 if face == "N" else PZ1
        sgn = -1 if face == "N" else 1
        box(f"Graffiti{face}", PX0, PX1, G + 20, PODIUM_TOP, z + sgn * 0.5 - 0.5, z + sgn * 0.5 + 0.5,
            var=graffiti, color=(200, 198, 192))
        for i in range(10):
            x0 = PX0 + 40 * i
            if i in shop_bays:
                box(f"Shop{face}{i}", x0 + 2, x0 + 38, G, G + 18, z + sgn * 0.4 - 0.4, z + sgn * 0.4 + 0.4,
                    mat="Glass", color=(40, 58, 70), layer="LOD3")
                s.part("Block", (16, 4, 1), (x0 + 20, G + 16, z + sgn * 1.5), mat="Neon",
                       color=[(255, 70, 160), (60, 230, 255), (255, 190, 60)][i % 3], layer="LOD2", name="ShopSign")
            else:
                box(f"Shutter{face}{i}", x0 + 2, x0 + 38, G, G + 18, z + sgn * 0.4 - 0.4, z + sgn * 0.4 + 0.4,
                    mat="Metal", var="Metal Shutters", color=(150, 150, 146), layer="LOD3")
        for i in range(11):
            x = PX0 + 40 * i
            box(f"Pier{face}{i}", x - 2, x + 2, G, G + 20, z + sgn * 1.5 - 1.5, z + sgn * 1.5 + 1.5, color=C_WEATH)
    else:
        x = PX0 if face == "W" else PX1
        sgn = -1 if face == "W" else 1
        box(f"Graffiti{face}", x + sgn * 0.5 - 0.5, x + sgn * 0.5 + 0.5, G + 20, PODIUM_TOP, PZ0, PZ1,
            var=graffiti, color=(200, 198, 192))
        box(f"Shutters{face}", x + sgn * 0.4 - 0.4, x + sgn * 0.4 + 0.4, G, G + 18, PZ0, PZ1,
            mat="Metal", var="Metal Shutters", color=(140, 142, 140), layer="LOD3")
        for i in range(0, 11, 2):
            z = PZ0 + 40 * i
            box(f"Pier{face}{i}", x + sgn * 1.5 - 1.5, x + sgn * 1.5 + 1.5, G, G + 20, z - 2, z + 2, color=C_WEATH)


street_face("N", "SG Graffiti A", {1, 4, 5, 8})
street_face("S", "SG Graffiti B", {2, 6})
street_face("W", "SG Graffiti B", set())
street_face("E", "SG Graffiti A", set())

# =====================================================================  TOWERS
BANDS = {}


def tower(tag, x0, x1, top, pier_x):
    s.group(f"{tag} Tower")
    box(f"{tag}Mass", x0, x1, PODIUM_TOP, top, TZ0, TZ1, mat="SmoothPlastic", var="SG Windows Blocks", color=C_WIN)
    # north (street) face: porthole grid + a solid service pier on the frame side
    box(f"{tag}NorthPorthole", x0 + 2, x1 - 2, PODIUM_TOP, top, TZ0 - 1, TZ0, mat="SmoothPlastic",
        var="SG Windows Capsule", color=(214, 211, 203))
    px0, px1 = pier_x
    box(f"{tag}ServicePier", px0, px1, PODIUM_TOP, top + 20, TZ0 - 14, TZ1 + 4, var="SG Capsule Panels", color=C_LIGHT)
    # south face: capsule windows only in the upper half, blocks grid below (reads older / patched)
    box(f"{tag}SouthPorthole", x0 + 2, x1 - 2, 440, top, TZ1, TZ1 + 1, mat="SmoothPlastic",
        var="SG Windows Capsule", color=(205, 202, 194))
    # tray bands every 40 studs (3 storeys) wrap the whole tower
    ys = list(range(PODIUM_TOP + 40, top, 40))
    for y in ys:
        box(f"{tag}Band{y}", x0 - 3, x1 + 3, y - 2.5, y + 2.5, TZ0 - 4, TZ1 + 4, color=C_BAND)
    BANDS[tag] = ys
    # roof cap + parapet ring
    box(f"{tag}RoofCap", x0 - 3, x1 + 3, top, top + 2, TZ0 - 4, TZ1 + 4, color=C_ROOF)
    box(f"{tag}ParapetN", x0 - 3, x1 + 3, top + 2, top + 8, TZ0 - 4, TZ0, color=C_BAND)
    box(f"{tag}ParapetS", x0 - 3, x1 + 3, top + 2, top + 8, TZ1, TZ1 + 4, color=C_BAND)


tower("W", WX0, WX1, W_TOP, (WX1 - 20, WX1))
tower("E", EX0, EX1, E_TOP, (EX0, EX0 + 20))

# round service cores on the outer faces (capsules plug into these)
s.group("Cores")
CORES = [("W", 632, 4880, W_TOP + 40), ("W", 632, 5140, W_TOP + 20), ("E", 1028, 4880, E_TOP + 40), ("E", 1028, 5120, E_TOP + 20)]
for tag, x, z, top in CORES:
    vcyl(f"Core{tag}{z}", x, z, PODIUM_TOP, top, 40, var="SG Capsule Panels", color=(214, 212, 204))
    vcyl(f"CoreCap{tag}{z}", x, z, top, top + 4, 46, color=C_BAND)

# =====================================================================  FRAME (sky trays + sphere)
s.group("Frame")
FX0, FX1 = WX1, EX0
for name, y0, y1 in (("TrayA", 360, 400), ("TrayB", 480, 520)):
    box(f"{name}Floor", FX0, FX1, y0, y0 + 7, TZ0, TZ1 + 6, color=C_LIGHT)   # south lip replaces the tray-edge kit there
    box(f"{name}Roof", FX0, FX1, y1 - 7, y1, TZ0, TZ1, color=C_LIGHT)
    box(f"{name}Glass", FX0, FX1, y0 + 7, y1 - 7, TZ0 + 5, TZ1 - 5, mat="Glass", color=(58, 84, 102))
    # chunky mullion fins every 40
    for x in (FX0 + 40, FX0 + 80, FX0 + 120):
        box(f"{name}Fin{x}", x - 2, x + 2, y0 + 7, y1 - 7, TZ0 + 1, TZ1 - 1, color=C_LIGHT)
    # frame lips: the tray floor and roof run across both towers' street faces as deep beams
    box(f"{name}LipLo", WX0 - 3, EX1 + 3, y0 - 3, y0 + 3, TZ0 - 14, TZ0, color=C_LIGHT)
    box(f"{name}LipHi", WX0 - 3, EX1 + 3, y1 - 3, y1 + 3, TZ0 - 14, TZ0, color=C_LIGHT)
    for i in range(4):
        s.kit("tray_edge_40", (FX0 + 20 + 40 * i, y0 + 4, TZ0 - 3))
# top beam at W roof level, plus the filled cell behind the sphere
box("TopBeam", FX0, FX1, 640, 680, TZ0, TZ1, mat="SmoothPlastic", var="SG Windows Capsule", color=(214, 211, 203))
box("TopBeamLipLo", WX0 - 3, EX1 + 3, 637, 643, TZ0 - 14, TZ0, color=C_LIGHT)
box("TopBeamLipHi", WX0 - 3, EX1 + 3, 677, 683, TZ0 - 14, TZ0, color=C_LIGHT)
box("TopBeamCap", FX0, FX1, 680, 682, TZ0 - 4, TZ1 + 4, color=C_ROOF)
box("BackCell", FX0, FX1, 520, 640, 5000, TZ1, mat="SmoothPlastic", var="SG Windows Blocks", color=C_WIN)
for x in (FX0 + 40, FX0 + 80, FX0 + 120):
    box(f"BackCellFin{x}", x - 2, x + 2, 520, 640, 4997, 5000, color=C_LIGHT)

s.group("Sphere")
SPH = (830, 581, 4848)
s.part("Ball", (110, 110, 110), SPH, mat="Metal", color=(176, 180, 186), name="Sphere")
s.part("Cylinder", (6, 118, 118), SPH, rot=(0, 0, 90), mat="Metal", color=(120, 124, 130), name="SphereBelt")
box("SphereCradle", 805, 855, 520, 530, 4825, 4870, color=C_BAND)
box("SphereHanger", 815, 845, 632, 640, 4835, 4860, color=C_BAND)
# rust patch plates stuck on the belt (poor repairs) and a neon sign under the sphere
box("SphereNeon", 790, 870, 500, 507, 4805, 4806, mat="Neon", color=(255, 80, 150), layer="LOD2")

# =====================================================================  CAPSULES
s.group("Capsules")
CAP_TINTS = [None, None, None, (214, 202, 176), (196, 206, 202), (222, 196, 186)]


def capsule(pos, ry):
    t = rnd.choice(CAP_TINTS)
    s.kit("capsule_unit", pos, rot=(0, ry, 0), scale=1.5, color=t)


# W core z4880: capsules face west (-X) either side of the core, irregular stack
for side, zc in ((0, 4840.5), (1, 4919.5)):
    for k, y in enumerate(range(290, 660, 20)):
        if (k + side) % 2 == 0 and rnd.random() < 0.72:
            capsule((618, y, zc), 90)
# E core z4880: capsules face east (+X); keep clear of the X3 portal (z4940-4980, Y450-506)
for side, zc in ((0, 4840.5), (1, 4919.5)):
    for k, y in enumerate(range(290, 740, 20)):
        if (k + side) % 2 == 1 and rnd.random() < 0.6 and not (side == 1 and 440 <= y <= 510):
            capsule((1042, y, zc), -90)
# pods hung in the open frame cell under tray B (like the paint-over's plugged-in rooms)
for x, y in ((786, 470), (830, 458), (874, 470)):
    capsule((x, y, TZ0 + 6), 0)
# E north face above the top beam: capsule pods facing the street
for i, (x, y) in enumerate(((950, 700), (990, 720), (950, 740), (1003, 700))):
    capsule((x, y, TZ0 - 12), 0)

# =====================================================================  BRIDGE LANDINGS
s.group("Bridge Landings")


def portal(tag, face_x, sgn, zc, deck):
    """U-shaped concrete collar projecting from a facade with a dark recess; the bridge head sits inside."""
    xa, xb = sorted((face_x, face_x + sgn * 12))
    box(f"{tag}JambL", xa, xb, deck - 10, deck + 32, zc - 22, zc - 14, color=C_LIGHT)
    box(f"{tag}JambR", xa, xb, deck - 10, deck + 32, zc + 14, zc + 22, color=C_LIGHT)
    box(f"{tag}Lintel", xa, xb, deck + 24, deck + 34, zc - 22, zc + 22, color=C_LIGHT)
    box(f"{tag}Sill", xa, xb, deck - 12, deck - 2, zc - 22, zc + 22, color=C_LIGHT)
    xr = face_x + sgn * 0.5
    box(f"{tag}Recess", xr - 0.5, xr + 0.5, deck - 2, deck + 24, zc - 14, zc + 14, color=C_DARK)


portal("X2Landing", WX0, -1, 5060, 400)
portal("X3Landing", EX1, 1, 4960, 470)

# =====================================================================  LIVED-IN LAYER
s.group("Patches")
# patched / boarded 40x40 cells on the side and south faces (1 stud proud)
patch_cells = [("Wf", WX0, -1, z, y) for z, y in ((4980, 300), (5020, 340), (4940, 460), (5100, 540), (5020, 620))] + \
              [("Ef", EX1, 1, z, y) for z, y in ((5040, 300), (5000, 380), (5160 - 20, 420), (5040, 580), (4980, 660), (5080, 700))]
for i, (tag, fx, sgn, z, y) in enumerate(patch_cells):
    board = i % 4 == 3
    xr = fx + sgn * 0.5
    box(f"Patch{tag}{i}", xr - 0.5, xr + 0.5, y - 17.5, y + 17.5, z - 20, z + 20,
        mat="Wood" if board else "SmoothPlastic", var="Plywood" if board else "SG Patched Panels",
        color=(170, 140, 100) if board else (215, 205, 190), layer="LOD3")
for i, (x, y) in enumerate(((650, 300), (690, 380), (730, 300), (930, 340), (950, 460), (990, 300), (950, 620), (690, 540))):
    board = i % 3 == 2
    box(f"PatchS{i}", x - 20, x + 20, y - 17.5, y + 17.5, TZ1 + 1, TZ1 + 2, mat="Wood" if board else "SmoothPlastic",
        var="Plywood" if board else "SG Patched Panels", color=(170, 140, 100) if board else (215, 205, 190), layer="LOD3")

s.group("Services")
# downpipes (chunky single parts) on the south faces and frame-side faces
for x, top in ((660, W_TOP), (726, W_TOP), (934, E_TOP), (1004, E_TOP)):
    box(f"Downpipe{x}", x - 1.5, x + 1.5, PODIUM_TOP, top, TZ1 + 4, TZ1 + 7, mat="Metal", color=(84, 88, 92), layer="LOD3")
for z, top in ((4840, 640), (5160, 640)):
    box(f"DownpipeFrameW{z}", WX1, WX1 + 3, PODIUM_TOP, top, z - 1.5, z + 1.5, mat="Metal", color=(84, 88, 92), layer="LOD3")
    box(f"DownpipeFrameE{z}", EX0 - 3, EX0, PODIUM_TOP, top, z - 1.5, z + 1.5, mat="Metal", color=(84, 88, 92), layer="LOD3")
# exterior fire stair up the W tower south face (podium to the X2 level)
for i in range(4):
    s.kit("ext_stair_40", (700, 260 + 40 * i, TZ1 + 9), rot=(0, 180, 0))
# fire stair from street to podium deck under the frame
s.kit("ext_stair_40", (812, 220, PZ0 - 5))
# AC clusters (scale 1.5) on south + side faces, hanging on the band lines
ac_spots = [((680, 356, TZ1 + 6), 180), ((720, 476, TZ1 + 6), 180), ((940, 396, TZ1 + 6), 180), 
            ((WX0 - 5, 436, 5000), 90), ((EX1 + 5, 356, 5060), -90),
            ((EX1 + 5, 556, 5010), -90), ((690, 316, TZ0 - 18), 0), ((980, 556, TZ0 - 18), 0)]
for pos, ry in ac_spots:
    s.kit("ac_cluster", pos, rot=(0, ry, 0), scale=1.5, layer="LOD2")
# laundry lines under bands: south faces, the podium ledge and across the frame void
laundry = [((690, 314, TZ1 + 8), 180), ((690, 434, TZ1 + 8), 180), ((960, 314, TZ1 + 8), 180), ((960, 474, TZ1 + 8), 180),
           ((960, 594, TZ1 + 8), 180), ((700, 594, TZ1 + 8), 180), ((690, 274, TZ0 - 8), 0), ((960, 274, TZ0 - 8), 0),
           ((WX0 - 8, 354, 4990), 90), ((EX1 + 8, 394, 5100), -90), ((1003, 634, TZ0 - 8), 0), ((706, 434, TZ0 - 18), 0),
           ((690, 594, TZ0 - 18), 0), ((952, 434, TZ0 - 18), 0), ((952, 314, TZ0 - 18), 0)]
for pos, ry in laundry:
    s.kit("laundry_line_36", pos, rot=(0, ry, 0), layer="LOD2", color=rnd.choice([(230, 120, 150), (120, 170, 220), (235, 210, 120), (240, 240, 235)]))
# small vertical neon signs on the podium corners and frame piers
for i, (x, y, z, h) in enumerate(((WX1 - 10, 290, TZ0 - 5, 36), (EX0 + 10, 300, TZ0 - 5, 44), (PX0 + 60, 228, PZ0 - 2, 20))):
    s.part("Block", (6, h, 1), (x, y, z), mat="Neon", color=[(60, 230, 255), (255, 70, 160), (255, 190, 60)][i], layer="LOD2", name="NeonSign")

for i, (x, y0, y1, col) in enumerate(((655, 420, 560, (38, 62, 150)), (1005, 300, 460, (200, 60, 60)))):
    box(f"Banner{i}", x - 10, x + 10, y0, y1, TZ0 - 17, TZ0 - 15, mat="SmoothPlastic", color=col, layer="LOD3")
    box(f"BannerPanel{i}", x - 7, x + 7, y0 + 20, y0 + 60, TZ0 - 18, TZ0 - 17, mat="SmoothPlastic", color=(236, 234, 228), layer="LOD3")

# =====================================================================  PODIUM DECK MARKET (under the frame)
s.group("Deck Market")
Y = PODIUM_TOP
for x, z in ((800, 4840), (860, 4840), (800, 4890)):
    s.kit("market_stall", (x, Y + 7, z), layer="LOD2")
for x, z in ((782, 4930), (788, 4930)):
    s.kit("vending_machine", (x, Y + 4.5, z), rot=(0, 90, 0), layer="LOD2")
s.kit("vending_machine", (PX0 + 110, G + 4.5, PZ0 - 3), layer="LOD2")
s.kit("vending_machine", (PX0 + 116, G + 4.5, PZ0 - 3), layer="LOD2")
s.kit("bench_concrete", (860, Y + 1.5, 4900), layer="LOD2")
s.kit("rooftop_shack", (870, Y + 6, 5150), rot=(0, 180, 0))
s.kit("rooftop_shack", (790, Y + 6, 5110), rot=(0, 90, 0))
for i in range(3):
    s.kit("chainlink_fence_20", (790 + 20 * i, Y + 6, PZ1 - 4), rot=(0, 180, 0), layer="LOD2")

# =====================================================================  ROOFTOPS
s.group("Roof")
box("WLiftOverrun", 660, 720, W_TOP + 2, W_TOP + 22, 5040, 5100, color=C_WEATH)
s.kit("water_tank", (690, W_TOP + 2 + 14.3, 4880), scale=1.3)
s.kit("water_tank", (730, W_TOP + 2 + 14.3, 4900), scale=1.3)
s.kit("dish_cluster", (690, W_TOP + 22 + 6, 5070))
s.kit("rooftop_shack", (700, W_TOP + 8, 4980))
s.kit("rooftop_shack", (740, W_TOP + 8, 5150), rot=(0, 90, 0))
s.kit("antenna_mast", (735, W_TOP + 2 + 36, 5120), scale=1.2)
box("ELiftOverrun", 930, 990, E_TOP + 2, E_TOP + 26, 5000, 5080, color=C_WEATH)
s.kit("water_tank", (960, E_TOP + 26 + 14.3, 5040), scale=1.3)
s.kit("dish_cluster", (1000, E_TOP + 8, 4900), rot=(0, 30, 0))
s.kit("rooftop_shack", (930, E_TOP + 8, 5150))
s.kit("antenna_mast", (1000, E_TOP + 2 + 45, 5140), scale=1.5)
s.kit("rooftop_shack", (820, 682 + 6, 5100), rot=(0, 90, 0))
s.kit("water_tank", (850, 682 + 14.3, 5150), scale=1.3)

s.save(str(HERE / "P11.json"))
