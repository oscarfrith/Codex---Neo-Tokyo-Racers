"""Icon sheet (1024, 128 px cells) and white map icon sheet (512, 128 px cells)."""
from common import *
import icon_source as src

CELL = 128
CSS = """
svg{position:absolute;left:0;top:0}
svg svg{position:static}
.f{fill:#fff;stroke:none}
.s{fill:none;stroke:#fff;stroke-width:%d;stroke-linejoin:miter;stroke-linecap:butt}
.b{fill:none;stroke:#fff;stroke-width:%d;stroke-linejoin:miter;stroke-linecap:butt}
.t{fill:#fff;font-family:'Barlow',sans-serif;font-weight:800;font-style:normal}
.ko .f{fill:#000}.ko .s{stroke:#000}.ko .b{stroke:#000}.ko .t{fill:#000}
""" % (src.STROKE, src.BOLD)

INK = (16, 16, 112, 112)


def legibility(im, index, name):
    """Every glyph at 24, 32 and 48 px on Slate (the check the brief asks for), plus the same strip
    enlarged 3x with nearest-neighbour so the real pixels can be inspected. Build artefact only."""
    names = list(index)
    per = 16
    rows = (len(names) + per - 1) // per
    blocks = []
    for px in (24, 32, 48):
        blk = Image.new("RGBA", (per * (px + 8) + 8, rows * (px + 8) + 8), ROLES["Slate"] + (255,))
        for i, n in enumerate(names):
            x, y = index[n]["ImageRectOffset"]
            g = im.crop((x, y, x + CELL, y + CELL)).resize((px, px), Image.LANCZOS)
            blk.alpha_composite(g, (8 + (i % per) * (px + 8), 8 + (i // per) * (px + 8)))
        blocks.append(blk)
    w = max(b.width for b in blocks); h = sum(b.height for b in blocks)
    strip = Image.new("RGBA", (w, h), ROLES["Slate"] + (255,))
    y = 0
    for b in blocks:
        strip.alpha_composite(b, (0, y)); y += b.height
    strip.convert("RGB").save(os.path.join(BUILD, name + "_legibility.png"))
    strip.resize((w * 3, h * 3), Image.NEAREST).convert("RGB").save(os.path.join(BUILD, name + "_legibility_x3.png"))


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
        if name == "icons" and bb and (bb[0] < INK[0] - 2 or bb[1] < INK[1] - 2 or bb[2] > INK[2] + 2 or bb[3] > INK[3] + 2):
            print("  note: %s ink %s is outside the 96 px ink box" % (gname, list(bb)))
    legibility(im, index, name)
    return im, index


def main():
    im, index = sheet(src.GLYPHS, 1024, "icons")
    save(im, "icons.png")
    write_json({"image": "icons.png", "size": [1024, 1024], "cell": CELL, "ink_box": [16, 16, 112, 112],
                "stroke": src.STROKE, "bold_stroke": src.BOLD,
                "corner": "mitred joins, butt caps, chamfered boxes", "slant_deg": 8,
                "glyphs": index}, "icons.json")
    im, index = sheet(src.MAP_ICONS, 512, "map_icons")
    save(im, "map_icons.png")
    write_json({"image": "map_icons.png", "size": [512, 512], "cell": CELL, "pin_tip_y": 118 / 128,
                "pin_icons": ["Waypoint", "TaxiDrop", "CourierDrop"],
                "families": {"circle": "activity", "rounded square": "place", "hexagon": "job", "pin": "destination"},
                "glyphs": index}, "map_icons.json")
    print("icons: %d glyphs, map icons: %d" % (len(src.GLYPHS), len(src.MAP_ICONS)))


if __name__ == "__main__":
    main()
