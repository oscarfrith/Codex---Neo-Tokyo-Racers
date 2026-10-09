"""Chrome-rendered marks: chequered corner (white, plus a two-tone alternative), the
PULSE RACERS wordmark placeholder, and the four touch-control images on one 1024 sheet."""
from common import *
import icon_source as src

CSS = """
svg{position:absolute;left:0;top:0}
.f{fill:#fff;stroke:none}.k{fill:rgb(7,6,13);stroke:none}
.s{fill:none;stroke:#fff;stroke-linejoin:round;stroke-linecap:round}
"""


def chequer(two_tone):
    sq, cols, rows = 40, 5, 4
    cells = []
    for r in range(rows):
        for c in range(cols):
            white = (r + c) % 2 == 0
            if white or two_tone:
                cells.append('<rect class="%s" x="%d" y="%d" width="%d" height="%d"/>'
                             % ("f" if white else "k", c * sq, r * sq, sq, sq))
    body = ('<svg width="256" height="256" viewBox="0 0 256 256"><g transform="translate(128 128) rotate(-10) '
            'skewX(-10) translate(%d %d)">%s</g></svg>' % (-cols * sq / 2, -rows * sq / 2, "".join(cells)))
    im = render_html(page(body, 256, 256, CSS), 256, 256, "chequer_two_tone" if two_tone else "chequer")
    if two_tone:
        # bleed with the ink colour under transparent texels so the dark squares do not fringe white
        a = im.getchannel("A")
        base = Image.new("RGBA", im.size, (7, 6, 13, 0))
        base.alpha_composite(im)
        r, g, b, _ = base.split()
        # where alpha is 0 keep ink RGB; elsewhere Chrome's own colour
        return Image.merge("RGBA", (r, g, b, a))
    return bleed_white(im)


WORDMARK = {"size": [1024, 256], "text": "PULSE RACERS", "face": "Barlow ExtraBold Italic (800)", "font_px": 112,
            "status": "PLACEHOLDER lockup, not a logo; Oscar to replace or approve"}


def wordmark():
    w, h = WORDMARK["size"]; fs = WORDMARK["font_px"]
    slashes = ('<svg style="position:static;flex:none" width="%d" height="%d" viewBox="16 14 100 100">%s</svg>'
               % (int(fs * 0.86), int(fs * 0.86), src.F(dict(src.GLYPHS)["title_mark"].split('d="')[1].split('"')[0])))
    body = ('<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;gap:%dpx">'
            '%s<span style="font:italic 800 %dpx/1 \'Barlow\',monospace;color:#fff;letter-spacing:0.01em;'
            'white-space:nowrap;padding-right:%dpx">%s</span></div>' % (int(fs * 0.16), slashes, fs, int(fs * 0.1), WORDMARK["text"]))
    im = bleed_white(render_html(page(body, w, h, CSS), w, h, "wordmark"))
    bb = im.getchannel("A").getbbox()
    assert bb and bb[0] >= 12 and bb[2] <= w - 12, "wordmark does not fit: %s" % (bb,)
    WORDMARK["ink"] = list(bb)
    return im


TOUCH = {
    "size": [1024, 1024], "cell": 512,
    "images": {"accelerate": [0, 0], "brake": [512, 0], "drift": [0, 512], "boost": [512, 512]},
    "note": "drift points left; rotate 180 for the right-hand control as Classic does. "
            "Turn arrows use icons.png chevron_left.",
}


def _bars(x0, x1, ys, hgt):
    return "".join('<rect class="f" x="%d" y="%d" width="%d" height="%d" rx="%d"/>' % (x0, y, x1 - x0, hgt, hgt / 2) for y in ys)


def touch_markup():
    accel = ('<path class="s" style="stroke-width:20" d="M184 44 H328 Q360 44 358 76 L342 440 Q340 468 312 468 '
             'H200 Q172 468 170 440 L154 76 Q152 44 184 44 Z"/>' + _bars(204, 308, [100, 160, 220, 280, 340, 400], 24))
    brake = ('<path class="s" style="stroke-width:20" d="M96 148 H416 Q448 148 448 180 V332 Q448 364 416 364 '
             'H96 Q64 364 64 332 V180 Q64 148 96 148 Z"/>' + _bars(128, 384, [196, 244, 292], 24))
    drift = ('<path class="s" style="stroke-width:48;stroke-linecap:butt" d="M420 440 C420 290 336 200 200 200"/>'
             '<path class="f" d="M64 200 L210 92 V308 Z"/>'
             '<path class="s" style="stroke-width:18;stroke-linecap:butt" d="M336 440 C336 344 290 292 222 286"/>')
    boost = ('<circle class="s" style="stroke-width:16" cx="256" cy="256" r="232"/>'
             '<g transform="translate(256 256) scale(3.5) translate(-64 -64)"><path class="f" d="%s"/></g>' % src.BOLT)
    return {"accelerate": accel, "brake": brake, "drift": drift, "boost": boost}


def touch_sheet():
    mk = touch_markup()
    parts = ['<svg width="1024" height="1024" viewBox="0 0 1024 1024">']
    for name, (x, y) in TOUCH["images"].items():
        parts.append('<svg x="%d" y="%d" width="512" height="512" viewBox="0 0 512 512" overflow="hidden">%s</svg>' % (x, y, mk[name]))
    parts.append("</svg>")
    css = CSS + "svg svg{position:static}"
    return bleed_white(render_html(page("".join(parts), 1024, 1024, css), 1024, 1024, "touch_controls"))


def main():
    save(chequer(False), "chequer_corner.png")
    save(chequer(True), "chequer_corner_two_tone.png")
    save(wordmark(), "wordmark_placeholder.png")
    save(touch_sheet(), "touch_controls.png")
    recs = {n: {"ImageRectOffset": xy, "ImageRectSize": [512, 512]} for n, xy in TOUCH["images"].items()}
    write_json({"wordmark": WORDMARK, "touch": dict(TOUCH, images=recs),
                "chequer": {"size": [256, 256], "grid": [5, 4], "square": 40, "rotate_deg": -10, "skew_deg": -10}},
               "marks.json")
    print("marks: 4 files")


if __name__ == "__main__":
    main()
