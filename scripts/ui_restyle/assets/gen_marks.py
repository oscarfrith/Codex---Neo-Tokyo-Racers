"""Chrome-rendered marks: chequered corner (white, plus a two-tone alternative), the
PULSE RACERS wordmark placeholder. (The touch controls are in gen_touch.py.)"""
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


def main():
    save(chequer(False), "chequer_corner.png")
    save(chequer(True), "chequer_corner_two_tone.png")
    save(wordmark(), "wordmark_placeholder.png")
    write_json({"wordmark": WORDMARK, "touch": "moved to touch_controls.json",
                "chequer": {"size": [256, 256], "grid": [5, 4], "square": 40, "rotate_deg": -10, "skew_deg": -10}},
               "marks.json")
    print("marks: 3 files")


if __name__ == "__main__":
    main()
