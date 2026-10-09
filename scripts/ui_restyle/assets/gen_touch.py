"""SUPERSEDED (review 3, 2026-10-09): Oscar rejected this slanted redesign. make_all.py no longer calls this file;
the touch controls are made by gen_touch_pulse.py (the Classic controls restyled). Kept only as a record.

Touch drive controls, second pass (2026-10-09): a racing-style family on two 1024 sheets.

House rules for the family (the phone preview draws the same shapes from the same brief):
  * white, tinted at run time; the alpha is authored here (no opaque slabs)
  * idle  = outline + 14% fill + solid motif
  * pressed = 92% fill with the motif cut out, a solid base line under the shape and a small glow
  * pedals and drift pads are parallelograms leaning 12 degrees; steer pads are chevron-shaped plates
  * steer is drawn once (left) and is symmetric top to bottom, so Rotation = 180 gives the right pad
    (the same trick Classic uses); drift is drawn both ways because its lean is mirrored
  * the boost charge meter is its own full ring, revealed by a rotating UIGradient
Cell sizes follow the size each control is drawn at on a phone (about 5 px per dp): pedals and drift
pads do not need a 512 square, which is what lets the set fit on two sheets.
"""
import math
from common import *
import icon_source as src

T12 = math.tan(math.radians(12))
FILL_IDLE, FILL_PRESSED, GLOW = 0.14, 0.92, 0.42

CSS = """
svg{position:absolute;left:0;top:0}
svg svg{position:static}
.f{fill:#fff;stroke:none}
.o{fill:none;stroke:#fff;stroke-linejoin:miter;stroke-miterlimit:8;stroke-linecap:butt}
.k{fill:#000;stroke:none}.ks{fill:none;stroke:#000;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:8}
"""
_n = [0]


def _id(p):
    _n[0] += 1
    return "%s%d" % (p, _n[0])


def poly(pts):
    return "M" + " L".join("%.1f %.1f" % p for p in pts) + " Z"


def lean(inner, base_y, sign=1):
    """12 degree lean about the row y = base_y. sign 1 leans the top to the right (forward)."""
    t = T12 * sign
    return '<g transform="matrix(1 0 %.5f 1 %.3f 0)">%s</g>' % (-t, t * base_y, inner)


def chamfer_box(x0, y0, x1, y1, c):
    """Box with the top-right and bottom-left corners cut (the family's corner)."""
    return poly([(x0, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1), (x0 + c, y1), (x0, y1 - c)])


def idle(shape_d, motif, stroke):
    return ('<path class="f" d="%s" opacity="%s"/><path class="o" d="%s" style="stroke-width:%s"/>%s'
            % (shape_d, FILL_IDLE, shape_d, stroke, motif))


def pressed(shape_d, cut, base, sigma, w, h, stroke):
    """Filled plate with the motif knocked out, base line, glow behind. `cut` uses classes k / ks."""
    m, g = _id("m"), _id("g")
    outline = '<path class="o" d="%s" style="stroke-width:%s"/>' % (shape_d, stroke) if stroke else ""
    return ('<filter id="%s" x="-30%%" y="-30%%" width="160%%" height="160%%"><feGaussianBlur stdDeviation="%s"/></filter>'
            '<mask id="%s" maskUnits="userSpaceOnUse" x="-200" y="-200" width="%d" height="%d">'
            '<rect x="-200" y="-200" width="%d" height="%d" fill="#fff"/>%s</mask>'
            '<g filter="url(#%s)" opacity="%s"><path class="f" d="%s"/>%s</g>'
            '<g mask="url(#%s)"><path class="f" d="%s" opacity="%s"/></g>%s%s'
            % (g, sigma, m, w + 400, h + 400, w + 400, h + 400, cut, g, GLOW, shape_d, base,
               m, shape_d, FILL_PRESSED, outline, base))


def chevron_up(cx, apex_y, half, rise, thick):
    return poly([(cx, apex_y), (cx + half, apex_y + rise), (cx + half, apex_y + rise + thick), (cx, apex_y + thick),
                 (cx - half, apex_y + rise + thick), (cx - half, apex_y + rise)])


def box(x0, y0, x1, y1):
    return poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


# ---------------------------------------------------------------- accelerate (360 x 512) ----
def accelerate(is_pressed):
    x0, x1, y0, y1 = 22, 242, 20, 462
    shape = chamfer_box(x0, y0, x1, y1, 30)
    cx = (x0 + x1) / 2.0
    chev = [(chevron_up(cx, a, 62, 44, 30), al) for a, al in ((96, 1.0), (186, 0.72), (276, 0.44))]
    bars = [(box(cx - 62, y, cx + 62, y + 12), 0.44) for y in (392, 418)]
    if is_pressed:
        cut = "".join('<path class="k" d="%s"/>' % d for d, _ in chev + bars)
        base = '<path class="f" d="%s"/>' % box(x0, 476, x1, 490)
        inner = pressed(shape, cut, base, 9, 360, 512, 10)
    else:
        motif = "".join('<path class="f" d="%s" opacity="%s"/>' % (d, al) for d, al in chev + bars)
        inner = idle(shape, motif, 10)
    return lean(inner, 490)


# --------------------------------------------------------------------- brake (256 x 256) ----
def brake(is_pressed):
    x0, x1, y0, y1 = 20, 186, 18, 214
    shape = chamfer_box(x0, y0, x1, y1, 22)
    cx = (x0 + x1) / 2.0
    bars = [(box(cx - 46, y, cx + 46, y + 22), al) for y, al in ((58, 0.44), (105, 0.72), (152, 1.0))]
    if is_pressed:
        cut = "".join('<path class="k" d="%s"/>' % d for d, _ in bars)
        base = '<path class="f" d="%s"/>' % box(x0, 226, x1, 238)
        inner = pressed(shape, cut, base, 7, 256, 256, 10)
    else:
        inner = idle(shape, "".join('<path class="f" d="%s" opacity="%s"/>' % (d, al) for d, al in bars), 10)
    return lean(inner, 238)


# ---------------------------------------------------------------- steer left (512 x 512) ----
STEER = {"tip": [30, 256], "top": 58, "bottom": 454, "outer_x": 214, "right_x": 452, "notch_x": 300,
         "trail_gap": 14, "trail_width": 14}


def steer_left(is_pressed):
    s = STEER
    tx, ty = s["tip"]
    shape = poly([(tx, ty), (s["outer_x"], s["top"]), (s["right_x"], s["top"]), (s["notch_x"], ty),
                  (s["right_x"], s["bottom"]), (s["outer_x"], s["bottom"])])
    run = (s["outer_x"] - tx) / float(ty - s["top"])        # x per y along the leading edge

    def chev(apex_x, half_h):
        return "M%.1f %.1f L%.1f %.1f L%.1f %.1f" % (apex_x + run * half_h, ty - half_h, apex_x, ty,
                                                     apex_x + run * half_h, ty + half_h)
    a, b = chev(112, 122), chev(204, 122)
    if is_pressed:
        cut = ('<path class="ks" d="%s" style="stroke-width:38"/><path class="ks" d="%s" style="stroke-width:38"/>' % (a, b))
        # the pressed "base line" of the steer pad follows its trailing edge, so it survives Rotation 180
        g0 = s["trail_gap"]; g1 = g0 + s["trail_width"]
        base = '<path class="f" d="%s"/>' % poly([(s["right_x"] + g0, s["top"]), (s["right_x"] + g1, s["top"]), (s["notch_x"] + g1, ty),
                                                    (s["right_x"] + g1, s["bottom"]), (s["right_x"] + g0, s["bottom"]), (s["notch_x"] + g0, ty)])
        return pressed(shape, cut, base, 12, 512, 512, 18)
    motif = ('<path class="o" d="%s" style="stroke-width:38"/>'
             '<path class="o" d="%s" style="stroke-width:38" opacity="0.44"/>' % (a, b))
    return idle(shape, motif, 18)


# -------------------------------------------------------------------- drift (256 x 256) ----
def drift_left(is_pressed):
    """Drawn pointing left and leaning back to the left; drift_right is the mirror image."""
    x0, x1, y0, y1 = 40, 216, 50, 190
    shape = poly([(x0 + 20, y0), (x1, y0), (x1, y1 - 20), (x1 - 20, y1), (x0, y1), (x0, y0 + 20)])
    cy = (y0 + y1) // 2

    def chev(ax):
        return "M%d %d L%d %d L%d %d" % (ax + 36, cy - 42, ax, cy, ax + 36, cy + 42)
    a, b = chev(68), chev(112)
    skid = [box(166, y, 198, y + 12) for y in (cy - 30, cy + 18)]
    if is_pressed:
        cut = ('<path class="ks" d="%s" style="stroke-width:20"/><path class="ks" d="%s" style="stroke-width:20"/>' % (a, b) +
               "".join('<path class="k" d="%s"/>' % d for d in skid))
        base = '<path class="f" d="%s"/>' % box(x0, 202, x1, 213)
        inner = pressed(shape, cut, base, 7, 256, 256, 10)
    else:
        motif = ('<path class="o" d="%s" style="stroke-width:20"/>'
                 '<path class="o" d="%s" style="stroke-width:20" opacity="0.72"/>' % (a, b) +
                 "".join('<path class="f" d="%s" opacity="0.44"/>' % d for d in skid))
        inner = idle(shape, motif, 10)
    return lean(inner, 213, -1)


def drift_right(is_pressed):
    return '<g transform="translate(256 0) scale(-1 1)">%s</g>' % drift_left(is_pressed)


# --------------------------------------------------------------------- boost (512 x 512) ----
BOOST = {"centre": [256, 256], "button_outer_radius": 204, "button_ring_width": 20,
         "charge_ring_outer_radius": 250, "charge_ring_width": 28,
         "charge_note": "boost_ring is a full ring; reveal it with a rotating UIGradient. Draw the three boost "
                        "cells in the same frame so the charge ring sits 18 px (image) outside the button."}


def _bolt(cls):
    return ('<g transform="translate(256 258) scale(2.55) translate(-64 -64)"><path class="%s" d="%s"/></g>' % (cls, src.BOLT))


def boost(is_pressed):
    r = BOOST["button_outer_radius"]; w = BOOST["button_ring_width"]
    if is_pressed:
        d = "M256 %d a%d %d 0 1 0 0.01 0 Z" % (256 - r, r, r)
        return pressed(d, _bolt("k"), "", 13, 512, 512, 0)
    ri = r - w / 2.0
    d = "M256 %.1f a%.1f %.1f 0 1 0 0.01 0 Z" % (256 - ri, ri, ri)
    return idle(d, _bolt("f"), w)


def boost_ring(_=False):
    ro = BOOST["charge_ring_outer_radius"]; w = BOOST["charge_ring_width"]
    return '<circle class="o" cx="256" cy="256" r="%.1f" style="stroke-width:%s"/>' % (ro - w / 2.0, w)


# -------------------------------------------------------------------------- sheets ----
# name, sheet index, x, y, w, h, builder, pressed?
LAYOUT = [
    ("accelerate", 0, 0, 0, 360, 512, accelerate, False),
    ("accelerate_pressed", 0, 360, 0, 360, 512, accelerate, True),
    ("brake", 0, 744, 0, 256, 256, brake, False),
    ("brake_pressed", 0, 744, 256, 256, 256, brake, True),
    ("steer_left", 0, 0, 512, 512, 512, steer_left, False),
    ("steer_left_pressed", 0, 512, 512, 512, 512, steer_left, True),
    ("boost", 1, 0, 0, 512, 512, boost, False),
    ("boost_pressed", 1, 512, 0, 512, 512, boost, True),
    ("boost_ring", 1, 0, 512, 512, 512, boost_ring, False),
    ("drift_left", 1, 512, 512, 256, 256, drift_left, False),
    ("drift_left_pressed", 1, 768, 512, 256, 256, drift_left, True),
    ("drift_right", 1, 512, 768, 256, 256, drift_right, False),
    ("drift_right_pressed", 1, 768, 768, 256, 256, drift_right, True),
]
SHEETS = ["touch_controls.png", "touch_controls_2.png"]

# Recommended sizes in dp at Compact scale 1 (844 x 390). draw = size of the whole cell on screen,
# hit = the invisible button that takes the touch (never under 48 dp). Same numbers as the phone preview.
DP = {
    "accelerate": {"draw": [70, 100], "hit": [96, 112], "anchor": "bottom right of the hit box"},
    "brake": {"draw": [54, 54], "hit": [80, 64], "anchor": "bottom of the hit box"},
    "steer_left": {"draw": [52, 52], "hit": [52, 60], "anchor": "centre"},
    "steer_right": {"draw": [52, 52], "hit": [52, 60], "anchor": "centre"},
    "drift_left": {"draw": [50, 50], "hit": [52, 48], "anchor": "centre; the art is 36 dp tall inside the cell"},
    "drift_right": {"draw": [50, 50], "hit": [52, 48], "anchor": "centre; the art is 36 dp tall inside the cell"},
    "boost": {"draw": [60, 60], "hit": [60, 60], "anchor": "centre; the button itself is 48 dp, the charge ring 59 dp"},
}


def build():
    ims = []
    for si, fname in enumerate(SHEETS):
        parts = ['<svg width="1024" height="1024" viewBox="0 0 1024 1024">']
        for name, s, x, y, w, h, fn, pr in LAYOUT:
            if s == si:
                parts.append('<svg x="%d" y="%d" width="%d" height="%d" viewBox="0 0 %d %d" overflow="hidden">%s</svg>'
                             % (x, y, w, h, w, h, fn(pr)))
        parts.append("</svg>")
        ims.append(bleed_white(render_html(page("".join(parts), 1024, 1024, CSS), 1024, 1024, fname[:-4])))
    return ims


def main():
    _n[0] = 0
    ims = build()
    images = {}
    for name, s, x, y, w, h, fn, pr in LAYOUT:
        bb = ims[s].crop((x, y, x + w, y + h)).getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        base = name.replace("_pressed", "")
        rec = {"sheet": SHEETS[s], "ImageRectOffset": [x, y], "ImageRectSize": [w, h], "ink_in_cell": list(bb) if bb else None}
        if pr:
            rec["pressed_state_of"] = base
        elif name != "boost_ring":
            rec["pressed"] = name + "_pressed"
        if base in DP and not pr:
            rec["draw_dp"] = DP[base]["draw"]; rec["hit_box_dp"] = DP[base]["hit"]; rec["anchor"] = DP[base]["anchor"]
        if name == "boost_ring":
            rec["draw_dp"] = DP["boost"]["draw"]; rec["note"] = "charge meter; same frame as boost"
        images[name] = rec
        if not (bb and bb[0] > 0 and bb[1] > 0 and bb[2] < w and bb[3] < h):
            print("  note: %s reaches its cell edge: %s" % (name, bb))
    for im, f in zip(ims, SHEETS):
        save(im, f)
    derived = {
        "steer_right": {"use": "steer_left", "Rotation": 180, "pressed": "steer_left_pressed with Rotation 180",
                        "draw_dp": DP["steer_right"]["draw"], "hit_box_dp": DP["steer_right"]["hit"],
                        "note": "steer_left and steer_left_pressed are symmetric top to bottom and centred in the cell, "
                                "so a half turn is the exact mirror image. The pressed base line is a chevron that follows "
                                "the trailing edge, so it stays on the trailing side after the turn."},
    }
    write_json({
        "sheets": SHEETS, "sheet_size": [1024, 1024],
        "style": {"lean_deg": 12, "idle_fill_alpha": FILL_IDLE, "pressed_fill_alpha": FILL_PRESSED, "glow_alpha": GLOW,
                  "idle": "outline, 14% fill, solid motif (echo steps at 72% and 44%)",
                  "pressed": "92% fill with the motif cut out, solid base line under the shape, small glow; "
                             "swap the image rect, do not layer it over the idle image",
                  "tint": "authored white; tint with ImageColor3. The colours are Oscar's call in the previews"},
        "dp_basis": "dp at Compact scale 1 (844 x 390), from previews/compact/compact.css",
        "images": images, "derived": derived, "boost": BOOST, "steer_shape": STEER,
    }, "touch_controls.json")
    print("touch controls: %d images on %d sheets" % (len(images), len(SHEETS)))


if __name__ == "__main__":
    main()
