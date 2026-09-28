"""P04 'Terrace Stack' (The Blocks, waterfront). Agent B.

Poor high-density megablock on the 40-stud balcony grid (floor plates every 3 storeys + fins every 40 = deep coffers):
  S1 waterfront terrace block: two wings stepping back from the water (tops 460 / 540), split by a sky slot with an
     exterior-stair tower and two slab skybridges.
  S2 west slab on the P03 street (top 560, set back at 420); lands the P03<->P04 truss bridge XB34 on its west face.
  S3 SE point tower (top 660) with a detached lift/stair core (top ~693) tied by six short bridges (D8 hero idea).
  Garage podium in the courtyard with a caged ball court on its roof; a low graffiti-mural workshop block on the south
  street. Laundry, patched balcony infill, AC units, tanks, dishes, shacks.
Run: py -3 scripts/south_grid/buildings/B/P04.py
"""
import pathlib
import random
from bkit import (Spec, box, fpanel, fkit, roof_cap, shopfront, CONC, CONC_D, CONC_L, PASTEL)

s = Spec("P04", kind="building", title="P04 Terrace Stack", lean="blocks")
G = 100
BODY = (156, 154, 148)
BODY2 = (138, 136, 130)
PLATE = (178, 176, 170)
GRAF = (175, 175, 170)
kit_n = {"bal": 0}


def plates(x0, x1, z0, z1, ys, over=5, color=PLATE):
    for y in ys:
        box(s, x0 - over, x1 + over, y, y + 3, z0 - over, z1 + over, "SG Weathered Concrete", color, name="Plate")


def fins(face, plane, us, y0, y1, w=4, proj=6):
    for u in us:
        fpanel(s, face, plane, u - w / 2, u + w / 2, y0, y1, proj, var="SG Weathered Concrete", color=PLATE, name="Fin")


def balcony(face, plane, u, band_y, storey=1, infill=0, laundry=None):
    """Balcony run in a 40-bay: storey 0..2 above the plate at band_y; optional laundry in front."""
    yb = band_y + 3 + 6.5 + 13.3 * storey
    fkit(s, "balcony_run_40", face, plane, u, yb, 8, color=None)
    if laundry is not None:
        fkit(s, "laundry_line_36", face, plane, u, yb + 1, 1, embed=-7.6, layer="LOD2", color=PASTEL[laundry % 6])


rng = random.Random(21)


def field(face, plane, bays, bands, ylo, yhi, p_bal, p_patch=0.12, p_laundry=0.45, skip=None):
    """Scatter balconies (with laundry) and patched infill over a coffer grid: 2 balcony storeys fit per 40-stud band."""
    for band in bands:
        for st in (0, 1):
            yb = band + 3 + 6.5 + 13.3 * st
            if yb - 6.5 < ylo or yb + 6.5 > yhi:
                continue
            for u in bays:
                if skip and skip(u, yb):
                    continue
                r = rng.random()
                if r < p_bal:
                    balcony(face, plane, u, band, storey=st,
                            laundry=rng.randrange(6) if rng.random() < p_laundry else None)
                elif r < p_bal + p_patch:
                    fpanel(s, face, plane, u - 17, u + 17, yb - 5.5, yb + 5.5, 1.5, var="SG Patched Panels",
                           color=PASTEL[rng.randrange(6)], layer="LOD2", name="Patch")


# ---------------------------------------------------------------- S1: waterfront terrace block (two wings + sky slot)
for wing, (x0, x1, top_tiers) in {"West": (836, 1000, 3), "East": (1060, 1226, 4)}.items():
    s.group(f"S1 Terrace {wing}")
    tiers = [(100, 260, 4112), (260, 380, 4140), (380, 460, 4168), (460, 540, 4182)][:top_tiers]
    for i, (y0, y1, z0) in enumerate(tiers):
        z1 = 4222
        if i == 0:
            box(s, x0, x1, G, 126, z0 + 4, z1, "SG Weathered Concrete", CONC)
            box(s, x0, x1, 126, y1, z0, z1, "SG Windows Blocks", BODY)
            fpanel(s, "n", z0, x0, x1, 126, 152, 1.0, var="SG Graffiti A" if wing == "West" else "SG Graffiti B",
                   color=GRAF, name="Graffiti")
            shopfront(s, "n", z0, x0, x1, cols=41 if wing == "West" else 41.5,
                      shutters=[(x0 + 44, x0 + 80), (x1 - 80, x1 - 44)])
            plates(x0, x1, z0, z1, (180, 220), over=4)
        else:
            box(s, x0, x1, y0, y1, z0, z1, "SG Windows Blocks", BODY if i % 2 else BODY2)
            plates(x0, x1, z0, z1, range(y0 + 40, y1, 40), over=4)
        roof_cap(s, x0, x1, z0, z1, y1, over=3, color=CONC_D)
        inner = [u for u in range(x0 + 40, x1 - 10, 40)]
        fins("n", z0, inner, max(y0, 152) if i == 0 else y0 + 2, y1 - 1)
    # balconies, laundry and patched infill on the waterfront faces of every tier
    for i, (y0, y1, z0) in enumerate(tiers):
        bays = [u + 20 for u in range(x0, x1 - 30, 40)]
        bands = list(range(y0, y1, 40)) if i else [140, 180, 220]
        field("n", z0, bays, bands, 152 if i == 0 else y0 + 2, y1 - 1, 0.13, p_patch=0.15)
    # terrace clutter
    s.kit("rooftop_shack", (x0 + 30, 262 + 6, 4128), layer="LOD2")
    box(s, x0 + 70, x0 + 110, 261, 265, 4118, 4134, "", (96, 140, 70), mat="Grass", layer="LOD2", name="Planter")
    s.kit("water_tank", (x1 - 30, tiers[-1][1] + 2 + 11, 4204))
    s.kit("dish_cluster", (x0 + 40, tiers[-1][1] + 2 + 6, 4206), layer="LOD2")
    s.kit("ac_cluster", (x1 - 60, 382 + 3.5, 4152), layer="LOD2")
    # end walls: graffiti on the street ends
    end_face, end_plane = ("w", x0) if wing == "West" else ("e", x1)
    fpanel(s, end_face, end_plane, 4116, 4222, 126, 166, 1.0, var="SG Graffiti B", color=GRAF, name="Graffiti")
    fkit(s, "pipe_bundle_40", end_face, end_plane, 4200, 186, 3, layer="LOD2")
    fkit(s, "pipe_bundle_40", end_face, end_plane, 4200, 226, 3, layer="LOD2")
s.kit("antenna_mast", (1180, 542 + 30, 4200))

s.group("S1 Sky Slot")
box(s, 1016, 1044, G, 482, 4190, 4222, "SG Weathered Concrete", CONC_L, name="StairTower")
roof_cap(s, 1016, 1044, 4190, 4222, 482)
for k in range(3):
    fkit(s, "ext_stair_40", "n", 4190, 1030, 120 + 40 * k, 10)
fkit(s, "pipe_bundle_40", "n", 4190, 1020, 240, 3, layer="LOD2")
for y0, y1, z0, z1 in ((306, 326, 4172, 4212), (426, 446, 4176, 4214)):
    box(s, 996, 1064, y0, y1, z0, z1, "SG Windows Blocks", BODY2, name="SlabBridge")
    box(s, 994, 1066, y0 - 2, y0 + 1, z0 - 3, z1 + 3, "SG Weathered Concrete", PLATE, name="BridgeSlab")
    box(s, 994, 1066, y1 - 1, y1 + 2, z0 - 3, z1 + 3, "SG Weathered Concrete", PLATE, name="BridgeSlab")

# ---------------------------------------------------------------- S2: west slab (XB34 landing on the west face)
s.group("S2 West Slab")
x0, x1, z0, z1 = 836, 900, 4262, 4540
box(s, x0 + 4, x1, G, 126, z0, z1 - 4, "SG Weathered Concrete", CONC)
box(s, x0, x1, 126, 420, z0, z1, "SG Windows Blocks", BODY)
box(s, x0 + 20, x1, 420, 560, z0, z1, "SG Windows Blocks", BODY2)
shopfront(s, "w", x0, z0, z1, cols=39.5, graffiti="SG Graffiti A", gh=26, shutters=[(4302, 4340), (4460, 4498)])
shopfront(s, "s", z1, x0, x1, cols=32)
plates(x0, x1, z0, z1, (180, 220, 260, 300, 340, 380), over=4)
roof_cap(s, x0, x1, z0, z1, 420, over=4, color=CONC_D)
plates(x0 + 20, x1, z0, z1, (460, 500), over=4)
roof_cap(s, x0 + 20, x1, z0, z1, 560, over=3, color=CONC_D)
wfins = [z0 + 40 * k for k in range(1, 7)]
fins("w", x0, wfins, 152, 419)
fins("w", x0 + 20, wfins[::2], 422, 559)
bays2 = [z0 + 20 + 40 * j for j in range(7)]
field("w", x0, bays2, range(140, 420, 40), 152, 419, 0.15, skip=lambda u, y: u == 4442 and 290 < y < 350)
field("w", x0 + 20, [4342, 4422, 4502], (420, 460, 500), 423, 559, 0.2)
for u, y in ((4302, 272), (4402, 192), (4482, 352), (4522, 232)):
    fkit(s, "ac_cluster", "w", x0, u, y, 4, layer="LOD2")
for k in range(2):
    fkit(s, "ext_stair_40", "s", z1, 880, 146 + 40 * k, 10)
s.kit("water_tank", (870, 562 + 11, 4300))
s.kit("water_tank", (880, 562 + 11, 4500))
s.kit("rooftop_shack", (872, 562 + 6, 4400), rot=(0, 90, 0), layer="LOD2")
s.kit("dish_cluster", (848, 422 + 6, 4380), rot=(0, 90, 0), layer="LOD2")
box(s, 842, 852, 421, 424, 4280, 4520, "", (96, 140, 70), mat="Grass", layer="LOD2", name="Planter")

# ---------------------------------------------------------------- S3: SE point tower + detached core
s.group("S3 Point Tower")
x0, x1, z0, z1 = 1110, 1226, 4424, 4540
box(s, x0, x1 - 4, G, 126, z0, z1 - 4, "SG Weathered Concrete", CONC)
box(s, x0, x1, 126, 660, z0, z1, "SG Windows Blocks", BODY)
shopfront(s, "s", z1, x0, x1, cols=38.6, graffiti="SG Graffiti B", gh=26, shutters=[(1150, 1186)])
shopfront(s, "e", x1, z0, z1, cols=38.6, awning=False)
plates(x0, x1, z0, z1, range(180, 660, 40), over=4)
roof_cap(s, x0, x1, z0, z1, 660, over=4, color=CONC_D)
for cx, cz in ((x0, z0), (x1, z0), (x0, z1), (x1, z1)):
    box(s, cx - 4, cx + 4, 152, 659, cz - 4, cz + 4, "SG Weathered Concrete", PLATE, name="CornerFin")
fins("s", z1, (1149, 1188), 152, 659)
fins("n", z0, (1149, 1188), 152, 659)
fins("e", x1, (4482,), 152, 659)
bays3 = [1129.5, 1168.5, 1207]
field("s", z1, bays3, range(140, 660, 40), 152, 659, 0.15, p_patch=0.2)
field("n", z0, bays3, range(140, 660, 40), 152, 659, 0.05, p_patch=0.15)
field("e", x1, [4453, 4511], range(140, 660, 40), 152, 659, 0.08)
for u, y in ((4450, 200), (4510, 320), (4450, 440), (4510, 560)):
    fkit(s, "ac_cluster", "e", x1, u, y, 4, layer="LOD2")
s.kit("water_tank", (1140, 662 + 11, 4450))
s.kit("water_tank", (1164, 662 + 11, 4450))
s.kit("dish_cluster", (1200, 662 + 6, 4510), layer="LOD2")
s.kit("rooftop_shack", (1140, 662 + 6, 4512), layer="LOD2")
# core + bridges
box(s, 1062, 1098, G, 690, 4462, 4498, "SG Weathered Concrete", CONC_L, name="LiftCore")
roof_cap(s, 1062, 1098, 4462, 4498, 690, over=3, color=CONC_D)
box(s, 1076, 1084, 692, 696, 4476, 4484, "", (255, 40, 40), mat="Neon", name="Beacon")
for y in range(200, 680, 80):
    box(s, 1096, 1112, y, y + 9, 4470, 4490, "SG Weathered Concrete", PLATE, name="CoreBridge")
fpanel(s, "w", 1062, 4468, 4492, 180, 300, 1.0, mat="SmoothPlastic", color=(40, 60, 150), name="Banner")
fpanel(s, "w", 1062, 4470, 4490, 176, 178, 1.0, mat="Neon", color=(255, 90, 170), name="BannerNeon")

# ---------------------------------------------------------------- courtyard garage podium + roof ball court
s.group("Garage Podium")
box(s, 900, 1222, G, 126, 4222, 4424, "SG Weathered Concrete", BODY2, name="Podium")
box(s, 900, 1226, 126, 140, 4222, 4424, "SG Graffiti A", GRAF, name="PodiumBand")
roof_cap(s, 900, 1226, 4222, 4424, 140, over=0.5, color=CONC_D)
shopfront(s, "e", 1226, 4222, 4424, cols=39, awning=True,
          shutters=[(4236, 4270), (4276, 4310), (4330, 4364), (4370, 4404)])
box(s, 960, 1060, 142, 143.5, 4270, 4390, "", (70, 110, 150), mat="SmoothPlastic", name="Court")
for k in range(5):
    s.kit("chainlink_fence_20", (970 + 20 * k, 142 + 6, 4270), layer="LOD2")
    s.kit("chainlink_fence_20", (970 + 20 * k, 142 + 6, 4390), rot=(0, 180, 0), layer="LOD2")
s.kit("rooftop_shack", (1120, 142 + 6, 4300), layer="LOD2")
s.kit("rooftop_shack", (1150, 142 + 6, 4380), rot=(0, 180, 0), layer="LOD2")

# ---------------------------------------------------------------- low mural workshop block on the south street
s.group("Mural Workshops")
box(s, 920, 1050, G, 126, 4424, 4536, "SG Weathered Concrete", CONC)
box(s, 920, 1050, 126, 180, 4424, 4540, "SG Graffiti A", GRAF, name="MuralMass")
roof_cap(s, 920, 1050, 4424, 4540, 180, over=2, color=CONC_D)
shopfront(s, "s", 4540, 920, 1050, cols=43.3, shutters=[(926, 958), (970, 1000), (1012, 1044)])
s.kit("water_tank", (940, 182 + 11, 4460))
s.kit("ac_cluster", (1000, 182 + 3.5, 4470), layer="LOD2")
for x in (1060, 1068):
    s.kit("vending_machine", (x, G + 4.5, 4550), rot=(0, 180, 0), layer="LOD2")

out = pathlib.Path(__file__).with_suffix(".json")
s.save(out)
