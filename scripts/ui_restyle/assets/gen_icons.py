"""Icon sheet (1024, 128 px cells) and white map icon sheet (512, 128 px cells)."""
from common import *
import icon_source as src

CELL = 128
CSS = """
svg{position:absolute;left:0;top:0}
svg svg{position:static}
.f{fill:#fff;stroke:none}
.s{fill:none;stroke:#fff;stroke-width:10;stroke-linejoin:miter;stroke-linecap:butt}
.b{fill:none;stroke:#fff;stroke-width:14;stroke-linejoin:miter;stroke-linecap:butt}
.t{fill:#fff;font-family:'Barlow',sans-serif;font-weight:800;font-style:normal}
.ko .f{fill:#000}.ko .s{stroke:#000}.ko .b{stroke:#000}.ko .t{fill:#000}
"""


def sheet(glyphs, size, name):
    cols = size // CELL
    assert len(glyphs) <= cols * cols, "sheet full"
    body = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (size, size, size, size)]
    index = {}
    for i, (gname, markup) in enumerate(glyphs):
        x, y = (i % cols) * CELL, (i // cols) * CELL
        # each cell is its own clipped viewport, so no glyph can leak into a neighbour
        body.append('<svg x="%d" y="%d" width="%d" height="%d" viewBox="0 0 128 128" overflow="hidden">%s</svg>'
                    % (x, y, CELL, CELL, markup))
        index[gname] = {"cell": [i % cols, i // cols], "ImageRectOffset": [x, y], "ImageRectSize": [CELL, CELL]}
    body.append("</svg>")
    im = bleed_white(render_html(page("".join(body), size, size, CSS), size, size, name))
    # measured ink box per glyph, so the common box can be checked
    for gname, rec in index.items():
        x, y = rec["ImageRectOffset"]
        bb = im.crop((x, y, x + CELL, y + CELL)).getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        rec["ink"] = list(bb) if bb else None
        if gname in src.PURPOSE:
            rec["note"] = src.PURPOSE[gname]
    return im, index


def main():
    im, index = sheet(src.GLYPHS, 1024, "icons")
    save(im, "icons.png")
    write_json({"image": "icons.png", "size": [1024, 1024], "cell": CELL, "ink_box": [16, 16, 112, 112],
                "stroke": 10, "glyphs": index}, "icons.json")
    im, index = sheet(src.MAP_ICONS, 512, "map_icons")
    save(im, "map_icons.png")
    write_json({"image": "map_icons.png", "size": [512, 512], "cell": CELL, "pin_tip_y": 118 / 128,
                "pin_icons": ["Waypoint", "TaxiDrop", "CourierDrop"],
                "families": {"circle": "activity", "rounded square": "place", "hexagon": "job", "pin": "destination"},
                "glyphs": index}, "map_icons.json")
    print("icons: %d glyphs, map icons: %d" % (len(src.GLYPHS), len(src.MAP_ICONS)))


if __name__ == "__main__":
    main()
