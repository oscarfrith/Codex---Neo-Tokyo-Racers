"""BigNumber sprite sheets: Barlow Condensed ExtraBold Italic, measured from rendered pixels.

Method: every glyph is laid out alone in its own large box at a known integer origin, followed by a
4 px inline-block marker that sits on the baseline. Two Chrome renders of the same page: one with the
marker red (advance = marker x - origin x, baseline = marker bottom) and one with it hidden (clean ink).
Ink bounds are PIL bboxes of the clean render. Nothing comes from font tables or guessed metrics.
"""
from common import *

FAMILY = "'Barlow Condensed'"
DIGITS = list("0123456789")
PUNCT = [":", ".", ",", "$", "%", "+", "-", "/", "x", "K", "M"]
WORDS = ["MPH", "KM/H", "XP"]
REF = "H"                       # measured for cap height only, not emitted
SIZES = {"256": {"cell_h": 256, "font_px": 264}, "128": {"cell_h": 128, "font_px": 132}}
ALPHA_MIN = 8                   # alpha threshold for ink bounds
GUARD = 4                       # transparent px kept between ink and a cell edge


def _measure(font_px, tag):
    glyphs = DIGITS + PUNCT + WORDS + [REF]
    cols = 4
    bw, bh, ox = font_px * 5, font_px * 2, font_px          # box, origin x inside the box
    rows = (len(glyphs) + 1 + cols - 1) // cols
    w, h = bw * cols, bh * rows

    def build(show):
        css = (".c{position:absolute;box-sizing:border-box;width:%dpx;height:%dpx;padding-left:%dpx;line-height:%dpx;"
               "white-space:nowrap;color:#fff;font-size:%dpx;font-style:italic;font-weight:800;font-family:%s,monospace;"
               "font-kerning:normal}"
               ".m{display:inline-block;width:4px;height:4px;vertical-align:baseline;background:#f00;visibility:%s}"
               % (bw, bh, ox, bh, font_px, FAMILY, "visible" if show else "hidden"))
        cells = []
        for i, g in enumerate(glyphs + ["\x00fallback"]):
            x, y = (i % cols) * bw, (i // cols) * bh
            if g == "\x00fallback":      # same string in the fallback face: proves the web font really loaded
                cells.append('<div class="c" style="left:%dpx;top:%dpx;font-family:monospace"><span>0</span>'
                             '<span class="m"></span></div>' % (x, y))
            else:
                cells.append('<div class="c" style="left:%dpx;top:%dpx"><span>%s</span><span class="m"></span></div>'
                             % (x, y, g.replace("&", "&amp;")))
        return page("".join(cells), w, h, css)

    marked = render_html(build(True), w, h, "digits_measure_%s_marked" % tag)
    clean = render_html(build(False), w, h, "digits_measure_%s_clean" % tag)

    out = {}
    for i, g in enumerate(glyphs + ["\x00fallback"]):
        x, y = (i % cols) * bw, (i // cols) * bh
        box = (x, y, x + bw, y + bh)
        mk = marked.crop(box)
        r, gch, b, a = mk.split()
        red = Image.eval(r, lambda v: 255 if v > 200 else 0)
        notg = Image.eval(gch, lambda v: 255 if v < 60 else 0)
        from PIL import ImageChops
        mbb = ImageChops.multiply(red, notg).getbbox()
        assert mbb, "marker not found for %r" % g
        ink = clean.crop(box).getchannel("A").point(lambda v: 255 if v > ALPHA_MIN else 0).getbbox()
        assert ink, "no ink for %r" % g
        out[g] = {"advance": mbb[0] - ox, "baseline": mbb[3],
                  "ink": [ink[0] - ox, ink[1] - mbb[3], ink[2] - ox, ink[3] - mbb[3]],   # relative to origin, baseline
                  "_box": box, "_ox": ox}
    fb = out.pop("\x00fallback")
    assert abs(fb["advance"] - out["0"]["advance"]) > 2 or fb["ink"] != out["0"]["ink"], \
        "Barlow Condensed did not load (glyphs match the fallback face)"
    return clean, out


def _baseline(m, ch):
    """One baseline per size, shared by the digit and punctuation sheets: the tallest ascent and the
    deepest descent of every emitted glyph are centred in the cell."""
    asc = max(-m[g]["ink"][1] for g in DIGITS + PUNCT + WORDS)
    desc = max(m[g]["ink"][3] for g in DIGITS + PUNCT + WORDS)
    assert asc + desc + 2 * GUARD <= ch, "font_px too large for cell: ascent %d descent %d cell %d" % (asc, desc, ch)
    return int(round((ch + asc - desc) / 2.0))


def _paste(sheet, clean, m, cell_x, cell_y, origin_x, baseline_y):
    bx0, by0 = m["_box"][0], m["_box"][1]
    l, t, r, b = m["ink"]
    src = (bx0 + m["_ox"] + l - 1, by0 + m["baseline"] + t - 1, bx0 + m["_ox"] + r + 1, by0 + m["baseline"] + b + 1)
    sheet.alpha_composite(clean.crop(src), (cell_x + origin_x + l - 1, cell_y + baseline_y + t - 1))


def _digit_sheet(tag, spec, clean, m):
    ch = spec["cell_h"]
    cap = -m[REF]["ink"][1]
    pitch = max(m[d]["advance"] for d in DIGITS)                      # tabular advance = widest digit
    # overhang of the ink outside its own centred advance box
    left = max(-(m[d]["ink"][0] + (pitch - m[d]["advance"]) / 2.0) for d in DIGITS)
    right = max((m[d]["ink"][2] + (pitch - m[d]["advance"]) / 2.0) - pitch for d in DIGITS)
    over = int(max(0, left, right) + 0.999)
    cw = pitch + 2 * (over + GUARD)
    cw += cw % 2
    per_row = 1024 // cw
    rows = (10 + per_row - 1) // per_row
    sh = 1
    while sh < rows * ch:
        sh *= 2
    sheet = Image.new("RGBA", (1024, sh), (0, 0, 0, 0))
    digit_h = max(-m[d]["ink"][1] for d in DIGITS)
    baseline_y = _baseline(m, ch)
    glyphs = {}
    for i, d in enumerate(DIGITS):
        cx, cy = (i % per_row) * cw, (i // per_row) * ch
        ox = int(round((cw - m[d]["advance"]) / 2.0))
        _paste(sheet, clean, m[d], cx, cy, ox, baseline_y)
        l, t, r, b = m[d]["ink"]
        glyphs[d] = {"ImageRectOffset": [cx, cy], "ImageRectSize": [cw, ch], "advance": m[d]["advance"],
                     "origin_x": ox, "ink_in_cell": [ox + l, baseline_y + t, ox + r, baseline_y + b]}
        assert ox + l >= GUARD - 1 and ox + r <= cw - GUARD + 1 and baseline_y + t >= 2 and baseline_y + b <= ch - 2, d
    def worst_gap(p):
        # smallest clear space between any two neighbouring digits when each is centred on a pitch of p
        lefts = [m[d]["ink"][0] + (p - m[d]["advance"]) / 2.0 for d in DIGITS]
        rights = [m[d]["ink"][2] + (p - m[d]["advance"]) / 2.0 for d in DIGITS]
        return round(p + min(lefts) - max(rights), 1)
    tight = sorted(m[d]["advance"] for d in DIGITS)[-2]              # second widest: every digit but "4" fits its own advance
    name = "digits_%s.png" % tag
    save(bleed_white(sheet), name)
    return {"image": name, "size": [1024, sh], "cell": [cw, ch], "per_row": per_row, "font_px": spec["font_px"],
            "cap_height": cap, "digit_height": digit_h, "baseline_y": baseline_y,
            "pitch": pitch, "pitch_worst_bbox_gap": worst_gap(pitch),
            "pitch_tight": tight, "pitch_tight_worst_bbox_gap": worst_gap(tight), "italic_overhang": over,
            "pitch_note": "The *_bbox_gap values compare upright bounding boxes; a negative value is normal for an italic "
                          "(slanted boxes overlap while the ink stays clear; see the contact sheet). Barlow Condensed digits are proportional (1 is narrow, 4 is wide). pitch is the widest "
                          "advance (safe, slightly loose); pitch_tight is the second widest and looks closer to set text.",
            "layout": "place each digit cell at x = n * pitch - (cell_w - pitch) / 2; cells overlap by "
                      "cell_w - pitch, which is the italic overhang plus guard. Draw size = cell * (target cap / cap_height).",
            "em": {"cap_height": round(cap / spec["font_px"], 4), "pitch": round(pitch / spec["font_px"], 4),
                   "overhang": round(over / spec["font_px"], 4)},
            "glyphs": glyphs}


def _punct_sheet(measured):
    """Variable-width cells, packed in rows. Big size first, then small; words only where they fit."""
    plan = []
    for tag in ("256", "128"):
        m = measured[tag][1]; ch = SIZES[tag]["cell_h"]
        cap = -m[REF]["ink"][1]
        baseline_y = _baseline(m, ch)
        for g in PUNCT + WORDS:
            l, t, r, b = m[g]["ink"]
            pad = max(0, -l, r - m[g]["advance"]) + GUARD
            cw = m[g]["advance"] + 2 * pad
            cw += cw % 2
            plan.append((tag, g, cw, ch, pad, baseline_y))
    x = y = 0; row_h = 0; placed = []
    for tag, g, cw, ch, pad, by in plan:
        if x + cw > 1024 or (row_h and ch != row_h):
            x = 0; y += row_h
        row_h = ch
        placed.append((tag, g, x, y, cw, ch, pad, by))
        x += cw
    total = y + row_h
    sh = 1
    while sh < total:
        sh *= 2
    assert sh <= 1024, "punctuation sheet too tall: %d" % total
    sheet = Image.new("RGBA", (1024, sh), (0, 0, 0, 0))
    out = {"256": {}, "128": {}}
    for tag, g, cx, cy, cw, ch, pad, by in placed:
        clean, m = measured[tag]
        _paste(sheet, clean, m[g], cx, cy, pad, by)
        l, t, r, b = m[g]["ink"]
        assert by + t >= 1 and by + b <= ch - 1, "glyph %r taller than its cell" % g
        out[tag][g] = {"ImageRectOffset": [cx, cy], "ImageRectSize": [cw, ch], "advance": m[g]["advance"],
                       "origin_x": pad, "ink_in_cell": [pad + l, by + t, pad + r, by + b]}
    save(bleed_white(sheet), "digits_punct.png")
    return {"image": "digits_punct.png", "size": [1024, sh], "used_height": total,
            "layout": "advance the pen by `advance`; draw the cell at pen - origin_x. Baseline and cap height match "
                      "the digit sheet of the same size.",
            "sizes": out}


def main():
    measured = {tag: _measure(spec["font_px"], tag) for tag, spec in SIZES.items()}
    doc = {"face": "Barlow Condensed ExtraBold Italic (800 italic), Google Fonts web face, rendered by Chrome",
           "measured_from": "rendered pixels (PIL bbox per glyph, alpha > %d); advance from a baseline marker" % ALPHA_MIN,
           "sheets": {}}
    for tag, spec in SIZES.items():
        doc["sheets"][tag] = _digit_sheet(tag, spec, *measured[tag])
    doc["punctuation"] = _punct_sheet(measured)
    doc["raw_metrics"] = {tag: {g: {"advance": v["advance"], "ink": v["ink"]} for g, v in measured[tag][1].items()}
                          for tag in SIZES}
    write_json(doc, "digits.json")
    for tag in SIZES:
        s = doc["sheets"][tag]
        print("digits_%s: cell %s pitch %d overhang %d cap %d baseline %d" %
              (tag, s["cell"], s["pitch"], s["italic_overhang"], s["cap_height"], s["baseline_y"]))
    print("punct sheet", doc["punctuation"]["size"], "used", doc["punctuation"]["used_height"])


if __name__ == "__main__":
    main()
