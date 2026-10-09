"""Baked-colour gradient rings (review 3, 2026-10-09): minimap ring, driver-rank ring, speed gauge
(plate + tracks, ticks, speed arc, glow, boost arc) and the title slash mark.

Oscar asked for the rings and the speedo to be "more dynamic with colour gradients", as in the accepted
mockup 01-free-roam.jpg, and allowed images for it. These are full-colour images: ImageColor3 stays white.
Every pixel is computed (numpy), so the art is deterministic and needs no Chrome. RGB is defined on every
pixel, including fully transparent ones, so bilinear filtering never pulls a dark fringe.

Angles are degrees clockwise from +X in screen space (0 = 3 o'clock, 90 = 6, 180 = 9, 270 = 12).
All ring images are 512 x 512 and centred, and every gauge layer shares one frame.
"""
import numpy as np
from PIL import Image, ImageDraw
from common import *

N = 512
C = N / 2.0
PINK, VIOLET, CYAN, WHITE, SLATE, INK = (ROLES[k] for k in ("Pink", "Violet", "Cyan", "White", "Slate", "Ink"))

SWEEP = {"start_deg": 135, "sweep_deg": 270}          # gauge: gap centred at the bottom
RINGS = {
    "angle_convention": "degrees clockwise from +X (screen space): 0 = 3 o'clock, 90 = 6, 180 = 9, 270 = 12",
    "size": N, "centre": [256, 256],
    "minimap_ring_gradient.png": {
        "ring_outer_radius": 240, "ring_thickness": 9, "glow_sigma": 6, "glow_peak_alpha": 0.55,
        "conic_stops": [[225, "Pink"], [315, "Violet"], [45, "Cyan"], [135, "Violet"]],
        "frame": "minimap diameter * 512 / 480, same centre (the ring's outer edge is the map edge; 16 px of glow outside)",
    },
    "rank_arc_gradient.png": {
        "ring_outer_radius": 244, "ring_thickness": 13, "glow_sigma": 5, "glow_peak_alpha": 0.45,
        "conic_stops": [[150, "Violet"], [290, "Cyan"], [40, "Pink"]],
        "frame_scale_vs_minimap_ring_frame": 1.099,
        "use": "full ring, revealed at run time. Rank: track = the same image at 25% opacity, fill revealed clockwise "
               "from 9 o'clock (180) by the XP fraction of the sweep (90 degrees on desktop, 165 to 285 on phones); "
               "the gradient runs violet to cyan along that sweep. Also the touch boost charge ring "
               "(frame = the boost button frame, revealed clockwise from 12 o'clock).",
    },
    "gauge": dict(SWEEP, **{
        "plate_radius": 232, "plate_alpha": 0.80, "rim_width": 2,
        "arc_radius": 210, "arc_thickness": 15, "arc_stops": [[0, "Cyan"], [0.5, "Violet"], [1, "Pink"]],
        "boost_radius": 184, "boost_thickness": 8,
        "glow_sigma": 9, "glow_peak_alpha": 0.6,
        "tick_outer_radius": 254, "tick_count": 61,
        "ticks": {"major": {"every": 6, "length": 18, "width": 4.5, "alpha": 1.0},
                  "medium": {"every": 3, "length": 12, "width": 3, "alpha": 0.8},
                  "minor": {"length": 7, "width": 2, "alpha": 0.5}},
        "tick_hot_from": 0.78,
        "layers": ["gauge_track.png (plate, rim, both tracks)", "gauge_ticks.png", "gauge_glow.png (revealed with the arc)",
                   "gauge_arc_gradient.png (revealed)", "boost_arc_gradient.png (revealed)"],
        "reveal": "gauge_arc_gradient, gauge_glow and boost_arc_gradient are full 270 degree sweeps; each is revealed by a "
                  "rotating UIGradient transparency mask from start_deg. The colour runs along the sweep (speed: cyan, "
                  "violet, pink; boost: blue to pale cyan), so a part-filled arc always ends in its own colour.",
        "leading_edge": "the bright tip of the speed arc is not a new image: glow_soft.png (white) as a small dot, "
                        "about 0.09 of the gauge frame across, placed on arc_radius at the current angle.",
    }),
    "title_slash_gradient.png": {"size": [160, 192], "design_box": [34, 60], "px_per_design_px": 3,
                                 "use": "screen-title slash mark, pink to violet; frame = 53.3 x 64 design px centred on the mark"},
}


def grid():
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    dx, dy = x + 0.5 - C, y + 0.5 - C
    r = np.hypot(dx, dy)
    a = np.degrees(np.arctan2(dy, dx)) % 360.0
    return r, a


R, A = grid()


def lerp_stops(t, stops):
    """t in 0..1 (array); stops [(pos, rgb)], ascending. Returns an (..., 3) float array."""
    pos = [p for p, _ in stops]
    return np.stack([np.interp(t, pos, [c[i] for _, c in stops]) for i in range(3)], axis=-1)


def conic(stops_deg):
    """Closed conic gradient through [(deg, rgb)] in clockwise order."""
    first = stops_deg[0][0]
    pts, prev = [], None
    for d, c in stops_deg:
        p = (d - first) % 360.0
        pts.append((p / 360.0, c)); prev = p
    pts.append((1.0, stops_deg[0][1]))
    return lerp_stops(((A - first) % 360.0) / 360.0, pts)


def band(r0, r1):
    return np.clip(R - r0 + 0.5, 0, 1) * np.clip(r1 - R + 0.5, 0, 1)


def band_dist(r0, r1):
    return np.maximum(np.maximum(r0 - R, R - r1), 0)


def sweep_t(start, sweep):
    """Signed angle (degrees) past the start of an arc; negative before it, > sweep after it."""
    t = (A - start) % 360.0
    return np.where(t > sweep + (360.0 - sweep) / 2.0, t - 360.0, t)


def sweep_cover(start, sweep):
    t = sweep_t(start, sweep)
    k = R * np.pi / 180.0
    return np.clip(t * k + 0.5, 0, 1) * np.clip((sweep - t) * k + 0.5, 0, 1), np.maximum(np.maximum(-t, t - sweep), 0) * k


def rgba(rgb, alpha):
    arr = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 1)[..., None] * 255.0])
    return Image.fromarray(np.rint(arr).astype(np.uint8), "RGBA")


def neon(col, core, lift=0.22):
    """Lift the core towards white a little so it reads as a lit tube; the glow keeps the pure colour."""
    return col + (255.0 - col) * (lift * core)[..., None]


def roles(stops):
    return [(p, ROLES[c]) for p, c in stops]


def minimap_ring():
    k = RINGS["minimap_ring_gradient.png"]
    r1 = k["ring_outer_radius"]; r0 = r1 - k["ring_thickness"]
    core = band(r0, r1)
    glow = k["glow_peak_alpha"] * np.exp(-band_dist(r0, r1) ** 2 / (2.0 * k["glow_sigma"] ** 2))
    return rgba(neon(conic(roles(k["conic_stops"])), core), core + (1 - core) * glow)


def rank_ring():
    k = RINGS["rank_arc_gradient.png"]
    r1 = k["ring_outer_radius"]; r0 = r1 - k["ring_thickness"]
    core = band(r0, r1)
    glow = k["glow_peak_alpha"] * np.exp(-band_dist(r0, r1) ** 2 / (2.0 * k["glow_sigma"] ** 2))
    return rgba(neon(conic(roles(k["conic_stops"])), core), core + (1 - core) * glow)


def _arc(radius, thick):
    g = RINGS["gauge"]
    cov, ang_d = sweep_cover(g["start_deg"], g["sweep_deg"])
    r0, r1 = radius - thick / 2.0, radius + thick / 2.0
    t = np.clip(sweep_t(g["start_deg"], g["sweep_deg"]) / g["sweep_deg"], 0, 1)
    return band(r0, r1) * cov, np.hypot(band_dist(r0, r1), ang_d), t


def gauge_arc():
    g = RINGS["gauge"]
    core, _, t = _arc(g["arc_radius"], g["arc_thickness"])
    return rgba(neon(lerp_stops(t, roles(g["arc_stops"])), core, 0.18), core)


def gauge_glow():
    g = RINGS["gauge"]
    _, dist, t = _arc(g["arc_radius"], g["arc_thickness"])
    return rgba(lerp_stops(t, roles(g["arc_stops"])), g["glow_peak_alpha"] * np.exp(-dist ** 2 / (2.0 * g["glow_sigma"] ** 2)))


BOOST_STOPS = [(0, (58, 112, 255)), (0.6, CYAN), (1, (200, 250, 255))]


def boost_arc():
    g = RINGS["gauge"]
    core, dist, t = _arc(g["boost_radius"], g["boost_thickness"])
    glow = 0.4 * np.exp(-dist ** 2 / (2.0 * 4.0 ** 2))
    return rgba(neon(lerp_stops(t, BOOST_STOPS), core, 0.15), core + (1 - core) * glow)


def gauge_track():
    g = RINGS["gauge"]
    pr = g["plate_radius"]
    plate = np.clip(pr - R + 0.5, 0, 1)
    # plate: Slate, a touch lighter and violet in the middle, Ink towards the rim
    k = np.clip(R / pr, 0, 1)[..., None] ** 2
    rgb = np.array([30, 25, 54.0]) * (1 - k) + np.array(INK, float) * k
    alpha = plate * (g["plate_alpha"] + 0.08 * k[..., 0])
    # rim: thin conic line on the plate edge, same colours as the minimap ring
    rim = band(pr - g["rim_width"], pr) * 0.55
    rgb = rgb * (1 - rim[..., None]) + conic(roles(RINGS["minimap_ring_gradient.png"]["conic_stops"])) * rim[..., None]
    alpha = np.maximum(alpha, rim)
    for rad, th, a in ((g["arc_radius"], g["arc_thickness"], 0.15), (g["boost_radius"], g["boost_thickness"], 0.12)):
        tr = _arc(rad, th)[0] * a
        rgb = rgb * (1 - tr[..., None]) + np.array(WHITE, float) * tr[..., None]
    return rgba(rgb, alpha)


def gauge_ticks():
    g = RINGS["gauge"]; ss = 4; n = N * ss; c = n / 2.0
    m = Image.new("L", (n, n), 0); d = ImageDraw.Draw(m)
    ro = g["tick_outer_radius"] * ss; cnt = g["tick_count"]
    for i in range(cnt):
        spec = g["ticks"]["major"] if i % g["ticks"]["major"]["every"] == 0 else \
            g["ticks"]["medium"] if i % g["ticks"]["medium"]["every"] == 0 else g["ticks"]["minor"]
        a = np.radians(g["start_deg"] + g["sweep_deg"] * i / (cnt - 1.0))
        ca, sa = np.cos(a), np.sin(a)
        hw = spec["width"] * ss / 2.0; ri = ro - spec["length"] * ss
        d.polygon([(c + ro * ca - hw * sa, c + ro * sa + hw * ca), (c + ro * ca + hw * sa, c + ro * sa - hw * ca),
                   (c + ri * ca + hw * sa, c + ri * sa - hw * ca), (c + ri * ca - hw * sa, c + ri * sa + hw * ca)],
                  fill=int(round(255 * spec["alpha"])))
    alpha = np.asarray(m.resize((N, N), Image.LANCZOS), float) / 255.0
    t = np.clip(sweep_t(g["start_deg"], g["sweep_deg"]) / g["sweep_deg"], 0, 1)
    hot = g["tick_hot_from"]
    return rgba(lerp_stops(t, [(0, WHITE), (hot, WHITE), (hot + 0.06, PINK), (1, PINK)]), alpha)


def title_slash():
    """The screen-title slash mark exactly as the previews draw it: a 34 x 60 box of 8 px stripes on a 15 px pitch
    at 45 degrees, sheared 14 degrees, pink at the top to violet at the bottom. 160 x 192 px (3 px per design px)."""
    w, h, k, ss = 160, 192, 3.0, 4
    yy, xx = np.mgrid[0:h * ss, 0:w * ss].astype(np.float64)
    x = (xx + 0.5) / ss / k - (w / k - 34) / 2.0          # design px, box at 0..34 x 0..60 before the shear
    y = (yy + 0.5) / ss / k - (h / k - 60) / 2.0
    xl = x + np.tan(np.radians(14)) * (y - 30)
    on = (xl >= 0) & (xl <= 34) & (y >= 0) & (y <= 60) & ((((xl + y) * 0.70711) % 15.0) < 8.0)
    alpha = on.reshape(h, ss, w, ss).mean(axis=(1, 3))
    t = np.clip((np.mgrid[0:h, 0:w][0] + 0.5) / k - (h / k - 60) / 2.0, 0, 60) / 60.0
    return Image.fromarray(np.rint(np.dstack([lerp_stops(t, [(0, PINK), (1, VIOLET)]), alpha[..., None] * 255.0])).astype(np.uint8), "RGBA")


FILES = [("minimap_ring_gradient.png", minimap_ring), ("rank_arc_gradient.png", rank_ring),
         ("gauge_track.png", gauge_track), ("gauge_ticks.png", gauge_ticks), ("gauge_glow.png", gauge_glow),
         ("gauge_arc_gradient.png", gauge_arc), ("boost_arc_gradient.png", boost_arc),
         ("title_slash_gradient.png", title_slash)]


def main():
    for name, fn in FILES:
        save(fn(), name)
    out = dict(RINGS)
    out["colours"] = {k: list(ROLES[k]) for k in ("Pink", "Violet", "Cyan", "White", "Slate", "Ink")}
    out["boost_arc_gradient.png"] = {"stops_along_sweep": [[p, list(c)] for p, c in BOOST_STOPS], "glow_sigma": 4, "glow_peak_alpha": 0.4}
    write_json(out, "rings.json")
    print("gradient rings: %d files" % len(FILES))


if __name__ == "__main__":
    main()
