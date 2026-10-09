"""PIL-only art: three 9-slice glows, gauge ring + tick ring, minimap ring + vignette + driver-rank ring,
player arrow, segmented bar strip, key cap 9-slice. Deterministic, no Chrome."""
import math
from PIL import Image, ImageDraw
from common import *

SS = 4  # supersample factor for geometric art

# ---- geometry that the kit needs at run time (also written to the manifest) ----
GAUGE = {"size": 512, "centre": [256, 256], "start_deg": 135, "sweep_deg": 270,
         "angle_convention": "degrees clockwise from +X (screen space); gap is centred at the bottom",
         "ring_radius": 204, "ring_thickness": 14,
         "tick_outer_radius": 250, "tick_major": {"count": 11, "length": 26, "width": 5},
         "tick_minor": {"per_gap": 4, "length": 13, "width": 3}}
MINIMAP = {"size": 512, "ring_outer_radius": 254, "ring_thickness": 8,
           "vignette_start_radius": 140, "vignette_end_radius": 250, "vignette_peak_alpha": 0.9}
# Driver-rank arc: a full ring that sits just outside minimap_ring.png. Derived from the preview
# (map 307 px across, 8 px gap, 10 px wide arc): frame = minimap frame * frame_scale, same centre.
RANK = {"size": 512, "ring_outer_radius": 248, "ring_thickness": 14.5, "frame_scale_vs_minimap": 1.1453,
        "gap_fraction_of_minimap_frame": 0.0261, "width_fraction_of_minimap_frame": 0.0326,
        "start_deg": 180, "sweep_deg": 90,
        "angle_convention": "degrees clockwise from +X (screen space): 180 is 9 o'clock, 270 is 12 o'clock",
        "use": "full white ring; the track is the same image at low opacity and the fill is revealed clockwise "
               "from 9 o'clock to 12 o'clock by a rotating UIGradient (XP fraction of the 90 degree sweep). "
               "Frame: centred on the minimap, size = minimap frame * frame_scale_vs_minimap"}
GLOWS = {
    "glow_soft.png": {"size": [128, 128], "edge_inset": 44, "sigma": 13, "SliceCenter": [62, 62, 66, 66],
                      "use": "selected tile outer glow; frame = tile grown by edge_inset * SliceScale on every side"},
    "glow_tight.png": {"size": [64, 64], "edge_inset": 20, "sigma": 5.5, "SliceCenter": [30, 30, 34, 34],
                       "use": "main button glow; frame = button grown by edge_inset * SliceScale on every side"},
    "glow_line.png": {"size": [64, 64], "end_inset": 20, "sigma": 7, "SliceCenter": [30, 0, 34, 64],
                      "use": "hairline base-line glow; frame height = 64 * SliceScale centred on the line, "
                             "width = line + 2 * end_inset * SliceScale; stretches horizontally only"},
}
KEYCAP = {"size": [64, 64], "radius": 12, "margin": 2, "SliceCenter": [20, 20, 44, 44]}
SEGMENT = {"size": [64, 64], "fill": [9, 55], "note": "ScaleType.Tile, TileSize = UDim2.new(0, pitch, 1, 0); "
           "fill is 46/64 of the pitch, gap split evenly left and right so a row starts and ends on half a gap"}


def phi(z):
    return 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))


def glow_box(size, inset, sigma):
    """Gaussian-blurred box as an exact 9-slice: alpha is a product of two 1D edge profiles,
    so every edge strip is constant along its edge and the corners are true blurred corners."""
    prof = [phi((min(i + 0.5, size - (i + 0.5)) - inset) / sigma) for i in range(size)]
    im = Image.new("L", (size, size))
    im.putdata([int(round(255 * prof[x] * prof[y])) for y in range(size) for x in range(size)])
    return white_from_alpha(im)


def glow_line(size, inset, sigma):
    px = [phi((min(i + 0.5, size - (i + 0.5)) - inset) / (sigma * 0.8)) for i in range(size)]
    py = [math.exp(-((j + 0.5 - size / 2) ** 2) / (2 * sigma * sigma)) for j in range(size)]
    im = Image.new("L", (size, size))
    im.putdata([int(round(255 * px[x] * py[y])) for y in range(size) for x in range(size)])
    return white_from_alpha(im)


def _down(mask, size):
    return mask.resize((size, size), Image.LANCZOS)


def _arc_poly(cx, cy, r0, r1, a0, a1, steps=360):
    pts = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((cx + r1 * math.cos(a), cy + r1 * math.sin(a)))
    for i in range(steps, -1, -1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((cx + r0 * math.cos(a), cy + r0 * math.sin(a)))
    return pts


def gauge_ring():
    g = GAUGE; n = g["size"] * SS; c = n / 2
    m = Image.new("L", (n, n), 0); d = ImageDraw.Draw(m)
    r = g["ring_radius"] * SS; t = g["ring_thickness"] * SS / 2
    d.polygon(_arc_poly(c, c, r - t, r + t, g["start_deg"], g["start_deg"] + g["sweep_deg"], 720), fill=255)
    return white_from_alpha(_down(m, g["size"]))


def gauge_ticks():
    g = GAUGE; n = g["size"] * SS; c = n / 2
    m = Image.new("L", (n, n), 0); d = ImageDraw.Draw(m)
    majors = g["tick_major"]["count"]; per = g["tick_minor"]["per_gap"]
    total = (majors - 1) * (per + 1)
    ro = g["tick_outer_radius"] * SS
    for i in range(total + 1):
        major = i % (per + 1) == 0
        spec = g["tick_major"] if major else g["tick_minor"]
        a = math.radians(g["start_deg"] + g["sweep_deg"] * i / total)
        ca, sa = math.cos(a), math.sin(a)
        hw = spec["width"] * SS / 2; ri = ro - spec["length"] * SS
        pts = [(c + ro * ca - hw * sa, c + ro * sa + hw * ca), (c + ro * ca + hw * sa, c + ro * sa - hw * ca),
               (c + ri * ca + hw * sa, c + ri * sa - hw * ca), (c + ri * ca - hw * sa, c + ri * sa + hw * ca)]
        d.polygon(pts, fill=255)
    return white_from_alpha(_down(m, g["size"]))


def minimap_ring():
    k = MINIMAP; n = k["size"] * SS; c = n / 2
    m = Image.new("L", (n, n), 0); d = ImageDraw.Draw(m)
    ro = k["ring_outer_radius"] * SS; ri = ro - k["ring_thickness"] * SS
    d.ellipse((c - ro, c - ro, c + ro, c + ro), fill=255)
    d.ellipse((c - ri, c - ri, c + ri, c + ri), fill=0)
    return white_from_alpha(_down(m, k["size"]))


def rank_ring():
    k = RANK; n = k["size"] * SS; c = n / 2
    m = Image.new("L", (n, n), 0); d = ImageDraw.Draw(m)
    ro = k["ring_outer_radius"] * SS; ri = ro - k["ring_thickness"] * SS
    d.ellipse((c - ro, c - ro, c + ro, c + ro), fill=255)
    d.ellipse((c - ri, c - ri, c + ri, c + ri), fill=0)
    return white_from_alpha(_down(m, k["size"]))


def minimap_vignette():
    k = MINIMAP; n = k["size"]; c = n / 2
    r0, r1, peak = k["vignette_start_radius"], k["vignette_end_radius"], k["vignette_peak_alpha"]
    data = []
    for y in range(n):
        for x in range(n):
            r = math.hypot(x + 0.5 - c, y + 0.5 - c)
            t = min(1.0, max(0.0, (r - r0) / (r1 - r0)))
            a = peak * t * t * (3 - 2 * t)
            a *= min(1.0, max(0.0, (r1 + 2.5) - r))        # anti-aliased cut just outside the ring's inner edge
            data.append(int(round(255 * a)))
    im = Image.new("L", (n, n)); im.putdata(data)
    return white_from_alpha(im)


def player_arrow():
    n = 128 * SS
    m = Image.new("L", (n, n), 0)
    pts = [(64, 12), (104, 110), (64, 88), (24, 110)]       # points up; rotation pivot is the image centre
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return white_from_alpha(_down(m, 128))


def keycap():
    k = KEYCAP; n = 64 * SS; mg = k["margin"] * SS
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).rounded_rectangle((mg, mg, n - mg - 1, n - mg - 1), radius=k["radius"] * SS, fill=255)
    return white_from_alpha(_down(m, 64))


def segment_strip():
    m = Image.new("L", (64, 64), 0)
    ImageDraw.Draw(m).rectangle((SEGMENT["fill"][0], 0, SEGMENT["fill"][1] - 1, 63), fill=255)
    return white_from_alpha(m)


def main():
    save(glow_box(128, 44, 13), "glow_soft.png")
    save(glow_box(64, 20, 5.5), "glow_tight.png")
    save(glow_line(64, 20, 7), "glow_line.png")
    # review 3 (2026-10-09): the gauge ring and ticks, the minimap ring and the rank ring are now the baked
    # gradient images made by gen_rings.py (geometry in rings.json); the white versions are no longer written.
    save(minimap_vignette(), "minimap_vignette.png")
    save(player_arrow(), "map_player_arrow.png")
    save(keycap(), "keycap_9slice.png")
    save(segment_strip(), "segment_strip.png")
    write_json({"minimap": {k: v for k, v in MINIMAP.items() if k.startswith(("size", "vignette"))},
                "rings": "see rings.json (gauge, minimap ring, rank arc; review 3)",
                "glow": GLOWS, "keycap": KEYCAP, "segment": SEGMENT}, "static_geometry.json")
    print("static art: 7 files")


if __name__ == "__main__":
    main()
