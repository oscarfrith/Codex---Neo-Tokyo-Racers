"""Touch drive controls, review 3 (2026-10-09): the CURRENT (Classic) controls restyled for Pulse.

Oscar rejected the slanted pedal redesign and asked for the current controls brought into the theme. So the
pictograms, proportions and positions are Classic's (assets/ui/icons/mobile_controls/):
  accelerate  upright pedal: cyan capsule, triangle at the top, five horizontal ribs
  brake       wide pedal: pink capsule, four vertical ribs, a bar beneath
  turn        one thick chevron, white with a cyan inner stripe
  drift       two chevrons, white with cyan and white with pink
  boost       round button with the bolt
and the dressing is Pulse: a square Slate plate at the house opacity (0.86) with a thin pink - violet - cyan
gradient outline (the minimap ring's colours), crisp white pictograms with cyan and pink accents and a small
neon glow. Pressed is the selected-tile language: White plate, Ink pictogram, Pink base line, Pink glow.

These are baked full-colour images (not tintable). Each is one SVG drawn in dp units and rasterised by Chrome
to 512 x 512. The same SVG files (touch_svg/*.svg) are what the phone previews show.
Right-hand turn and drift are the left images mirrored at run time. Disabled = the idle image dimmed.
"""
import numpy as np
from PIL import Image, ImageFilter
from common import *
import icon_source as src

SVG_DIR = os.path.join(HERE, "touch_svg")
os.makedirs(SVG_DIR, exist_ok=True)

W_, P_, V_, C_, I_ = "#F3F0FF", "#FF2D95", "#9A3DFF", "#22E4FF", "#07060D"
SLATE = "rgba(14,13,26,.86)"
PRESSED_FILL = "rgba(243,240,255,.95)"
OUTLINE = 1.25          # dp, plate outline
MARGIN = 5.0            # dp of transparent room round the plate for the glow
BASE = 2.5              # dp, pressed base line

# name: plate size in dp (at Compact scale 1), hit box in dp, anchor of the plate inside the hit box
CONTROLS = {
    "accelerate": {"plate": [72, 100], "hit": [96, 112], "anchor": "bottom right"},
    "brake": {"plate": [76, 64], "hit": [80, 64], "anchor": "bottom centre"},
    "turn": {"plate": [52, 52], "hit": [52, 60], "anchor": "centre"},
    "drift": {"plate": [52, 52], "hit": [52, 52], "anchor": "centre"},
    "boost": {"plate": [48, 48], "hit": [52, 52], "anchor": "centre", "round": True},
}


def view(name):
    w, h = CONTROLS[name]["plate"]
    return max(w, h) + 2 * MARGIN


DEFS = ('<defs>'
        '<linearGradient id="ol" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%s"/><stop offset=".5" stop-color="%s"/>'
        '<stop offset="1" stop-color="%s"/></linearGradient>'
        '<linearGradient id="bl" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
        '<filter id="g" x="-60%%" y="-60%%" width="220%%" height="220%%"><feGaussianBlur stdDeviation="1.5"/></filter>'
        '<filter id="pg" x="-40%%" y="-40%%" width="180%%" height="180%%"><feGaussianBlur stdDeviation="2.1"/></filter>'
        '</defs>' % (P_, V_, C_, P_, V_))


def plate(w, h, pressed, rnd=False):
    """Plate with its outline; origin is the plate's top-left corner."""
    o = OUTLINE
    if rnd:
        r = w / 2.0
        if pressed:
            return ('<circle cx="%s" cy="%s" r="%s" fill="%s" filter="url(#pg)" opacity=".75"/>'
                    '<circle cx="%s" cy="%s" r="%s" fill="%s"/>'
                    '<circle cx="%s" cy="%s" r="%s" fill="none" stroke="url(#ol)" stroke-width="%s"/>'
                    % (r, r, r, P_, r, r, r, PRESSED_FILL, r, r, r - 1.0, 2.0))
        return ('<circle cx="%s" cy="%s" r="%s" fill="%s"/>'
                '<circle cx="%s" cy="%s" r="%s" fill="none" stroke="url(#ol)" stroke-width="%s"/>'
                % (r, r, r, SLATE, r, r, r - 0.8, 1.6))
    if pressed:
        return ('<rect x="0" y="0" width="%s" height="%s" fill="%s" filter="url(#pg)" opacity=".7"/>'
                '<rect x="0" y="0" width="%s" height="%s" fill="%s"/>'
                '<rect x="0" y="%s" width="%s" height="%s" fill="url(#bl)"/>'
                % (w, h, P_, w, h, PRESSED_FILL, h - BASE, w, BASE))
    return ('<rect x="0" y="0" width="%s" height="%s" fill="%s"/>'
            '<rect x="%s" y="%s" width="%s" height="%s" fill="none" stroke="url(#ol)" stroke-width="%s"/>'
            % (w, h, SLATE, o / 2, o / 2, w - o, h - o, o))


def glow(shapes, opacity=0.8):
    return '<g filter="url(#g)" opacity="%s">%s</g>' % (opacity, shapes)


def accelerate(pressed):
    cx, top, cw, ch = 36.0, 14.0, 37.0, 72.0
    cap = '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s" stroke="%s" stroke-width="2.6"/>' % (
        cx - cw / 2, top, cw, ch, cw / 2, I_, C_)
    ribs = "".join('<path d="M%s %.1f H%s" stroke="%s" stroke-width="2.8" stroke-linecap="round"/>' % (cx - 10.5, top + ch * f, cx + 10.5, W_)
                   for f in (0.215, 0.39, 0.565, 0.74, 0.90))
    tri = '<path d="M%s %.1f L%s %.1f H%s Z" fill="%s"/>' % (cx, top + ch * 0.065, cx + 9.6, top + ch * 0.255, cx - 9.6, C_)
    return glow(cap + tri, 0.55 if pressed else 0.8) + cap + ribs + tri


def brake(pressed):
    cx, cy, cw, ch = 38.0, 27.5, 55.0, 30.0
    cap = '<rect x="%s" y="%s" width="%s" height="%s" rx="9.5" fill="%s" stroke="%s" stroke-width="2.6"/>' % (
        cx - cw / 2, cy - ch / 2, cw, ch, I_, P_)
    ribs = "".join('<path d="M%s %s V%s" stroke="%s" stroke-width="2.8" stroke-linecap="round"/>' % (cx + dx, cy - 7.5, cy + 7.5, W_)
                   for dx in (-16.5, -5.5, 5.5, 16.5))
    bar = '<rect x="%s" y="50.5" width="44" height="2.2" fill="%s" opacity="%s"/>' % (cx - 22, I_ if pressed else W_, 0.55)
    return glow(cap, 0.55 if pressed else 0.8) + cap + ribs + bar


_m = [0]


def _chev(ax, cy, arm, width, colour, pressed):
    """A chevron pointing left with a coloured stripe along its inner edge (the stripe is masked to the body)."""
    def d(x):
        return "M%.2f %.2f L%.2f %.2f L%.2f %.2f" % (x + arm, cy - arm, x, cy, x + arm, cy + arm)
    _m[0] += 1
    mid = "cm%d" % _m[0]
    sw = width * 0.40
    shift = (width / 2.0 - sw / 2.0) * 1.41421
    body = '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="miter"/>' % (d(ax), I_ if pressed else W_, width)
    acc = ('<mask id="%s" maskUnits="userSpaceOnUse" x="-10" y="-10" width="140" height="140">'
           '<path d="%s" fill="none" stroke="#fff" stroke-width="%s" stroke-linejoin="miter"/></mask>'
           '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="miter" mask="url(#%s)"/>'
           % (mid, d(ax), width, d(ax + shift), colour, sw + 0.6, mid))
    return body, acc


def turn(pressed):
    body, acc = _chev(17.0, 26.0, 16.5, 8.0, C_, pressed)
    return glow(body.replace(I_, C_).replace(W_, C_), 0.45 if pressed else 0.7) + body + acc


def drift(pressed):
    b1, a1 = _chev(11.8, 26.0, 14.5, 6.2, C_, pressed)
    b2, a2 = _chev(25.8, 26.0, 14.5, 6.2, P_, pressed)
    g = b1.replace(I_, C_).replace(W_, C_) + b2.replace(I_, P_).replace(W_, P_)
    return glow(g, 0.45 if pressed else 0.7) + b1 + a1 + b2 + a2


def boost(pressed):
    bolt = '<g transform="translate(24 24.3) scale(0.265) translate(-64 -64)"><path d="%s" fill="%%s"/></g>' % src.BOLT
    return glow(bolt % C_, 0.5 if pressed else 0.95) + bolt % (I_ if pressed else W_)


DRAW = {"accelerate": accelerate, "brake": brake, "turn": turn, "drift": drift, "boost": boost}


def svg(name, pressed, px=512):
    w, h = CONTROLS[name]["plate"]
    v = view(name)
    x0, y0 = (v - w) / 2.0, (v - h) / 2.0
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %s %s">%s'
            '<g transform="translate(%s %s)">%s%s</g></svg>'
            % (px, px, v, v, DEFS, x0, y0, plate(w, h, pressed, CONTROLS[name].get("round")), DRAW[name](pressed)))


def bleed_colour(im):
    """Fill the RGB of fully transparent pixels from their nearest drawn neighbours (alpha untouched),
    so bilinear filtering in Roblox never pulls a black fringe into a baked-colour image."""
    a = np.asarray(im, np.float64)
    rgb, al = a[..., :3].copy(), a[..., 3:] / 255.0
    acc_rgb, acc_a = rgb * al, al.copy()
    pm = Image.fromarray(np.rint(np.dstack([acc_rgb, acc_a * 255.0])).astype(np.uint8), "RGBA")
    for radius in (2, 6, 18, 60):
        b = np.asarray(pm.filter(ImageFilter.GaussianBlur(radius)), np.float64)
        ba = b[..., 3:] / 255.0
        fill = np.where(ba > 1e-4, b[..., :3] / np.maximum(ba, 1e-4), 0)
        empty = (acc_a <= 1e-4) & (ba > 1e-4)
        acc_rgb = np.where(empty, fill, acc_rgb); acc_a = np.where(empty, 1.0, acc_a)
    out = np.where(al > 0, rgb, np.where(acc_a > 0, acc_rgb, 0))
    return Image.fromarray(np.rint(np.dstack([np.clip(out, 0, 255), a[..., 3:]])).astype(np.uint8), "RGBA")


def main():
    images = {}
    _m[0] = 0
    for name in CONTROLS:
        for pressed in (False, True):
            stem = "touch_%s%s" % (name, "_pressed" if pressed else "")
            s = svg(name, pressed)
            with open(os.path.join(SVG_DIR, stem + ".svg"), "w", encoding="utf-8") as f:
                f.write(s)
            im = render_html(page('<div style="position:absolute;left:0;top:0;line-height:0">%s</div>' % s, 512, 512), 512, 512, stem)
            save(bleed_colour(im), stem + ".png")
            w, h = CONTROLS[name]["plate"]; v = view(name); k = 512.0 / v
            rec = {"file": stem + ".png", "svg": "touch_svg/%s.svg" % stem, "size": [512, 512],
                   "plate_rect_px": [round((v - w) / 2 * k, 1), round((v - h) / 2 * k, 1), round(w * k, 1), round(h * k, 1)]}
            if pressed:
                rec["pressed_state_of"] = "touch_%s" % name
            else:
                rec.update({"pressed": stem + "_pressed.png", "plate_dp": [w, h], "frame_dp": [v, v],
                            "hit_box_dp": CONTROLS[name]["hit"], "anchor": CONTROLS[name]["anchor"]})
            images[stem] = rec
    write_json({
        "note": "Review 3 (2026-10-09). Baked full-colour images: leave ImageColor3 white. Sizes are dp at Compact scale 1 "
                "(844 x 390). frame_dp is the ImageLabel size that draws the plate at plate_dp (the image carries %s dp of "
                "glow room on each side of the longer plate edge). Swap to the _pressed image while held; do not layer it." % MARGIN,
        "style": {"plate": "Slate at 0.86, square corners", "outline_dp": OUTLINE, "outline": "Pink, Violet, Cyan from top-left to bottom-right",
                  "pressed": "White plate at 0.95, Ink pictogram, %s dp Pink to Violet base line, Pink glow" % BASE,
                  "disabled": "idle image at ImageTransparency 0.6"},
        "images": images,
        "derived": {
            "turn_right": "touch_turn.png mirrored: ImageRectOffset (512, 0), ImageRectSize (-512, 512)",
            "drift_right": "touch_drift.png mirrored the same way",
            "boost_charge": "rank_arc_gradient.png in a frame the size of the boost frame * 1.02, same centre, revealed "
                            "clockwise from 12 o'clock by the charge fraction; the same image at 25% opacity is its track",
        },
        "layout_dp": "Classic positions: turn pair bottom-left with the drift pair above it and boost above that; brake then "
                     "accelerate bottom-right; speed bottom-centre. See previews/compact/compact.css (.tc-left, .tc-right).",
    }, "touch.json")
    print("touch controls (review 3): %d images" % len(images))


if __name__ == "__main__":
    main()
