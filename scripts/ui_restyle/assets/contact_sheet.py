"""Contact sheet for the upload batch: out/contact_sheet.html and out/contact_sheet.png.

Top board: the art in use (small icon sizes, sprite-set numbers, gauge, minimap, glows, key caps).
Then one card per file: 1:1 in White on Slate, then tinted in each colour role, with file name,
pixel size, purpose, planned config key and slice data.
"""
import json, os, math, html
from PIL import Image
from common import *
import manifest_source as ms

PAGE_W = 3240
M, GAP, PAD, HEAD = 24, 20, 16, 100
TINTS = ["Pink", "Cyan", "Yellow", "TextMuted", "Ink"]


def rgb(role):
    return "rgb(%d,%d,%d)" % ROLES[role]


def filters():
    out = ['<svg width="0" height="0" style="position:absolute"><defs>']
    for role in ROLES:
        out.append('<filter id="t%s" color-interpolation-filters="sRGB" x="0" y="0" width="1" height="1">'
                   '<feFlood flood-color="%s"/><feComposite in2="SourceAlpha" operator="in"/></filter>' % (role, rgb(role)))
    out.append("</defs></svg>")
    return "".join(out)


def load(name):
    with open(os.path.join(OUT, name), encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------- sprites ----
def sprite(sheet, sheet_size, rect_off, rect_size, x, y, scale=1.0, role="White", extra=""):
    return ('<div style="position:absolute;left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;background:url(%s) '
            '-%.1fpx -%.1fpx / %.1fpx %.1fpx no-repeat;filter:url(#t%s);%s"></div>'
            % (x, y, rect_size[0] * scale, rect_size[1] * scale, sheet, rect_off[0] * scale, rect_off[1] * scale,
               sheet_size[0] * scale, sheet_size[1] * scale, role, extra))


def number(digits, text, tag, x, y, scale=1.0, role="White", tight=True):
    """Lay a string out from digits.json exactly as BigNumber would. Returns (html, width)."""
    sh = digits["sheets"][tag]; pu = digits["punctuation"]
    pitch = sh["pitch_tight"] if tight else sh["pitch"]
    cw = sh["cell"][0]
    pen = 0.0; out = []
    i = 0
    words = sorted((w for w in pu["sizes"][tag] if len(w) > 1), key=len, reverse=True)
    while i < len(text):
        ch = text[i]
        if ch == " ":
            pen += pitch * 0.45; i += 1; continue
        if ch.isdigit():
            g = sh["glyphs"][ch]
            out.append(sprite(sh["image"], sh["size"], g["ImageRectOffset"], g["ImageRectSize"],
                              x + (pen - (cw - pitch) / 2.0) * scale, y, scale, role))
            pen += pitch; i += 1; continue
        tok = next((w for w in words if text.startswith(w, i)), ch)
        g = pu["sizes"][tag][tok]
        out.append(sprite(pu["image"], pu["size"], g["ImageRectOffset"], g["ImageRectSize"],
                          x + (pen - g["origin_x"]) * scale, y, scale, role))
        pen += g["advance"]; i += len(tok)
    return "".join(out), pen * scale


def label(x, y, text, size=14, role="TextMuted", w=None):
    return ('<div class="lb" style="left:%dpx;top:%dpx;font-size:%dpx;color:%s;%s">%s</div>'
            % (x, y, size, rgb(role), ("width:%dpx;" % w) if w else "white-space:nowrap;", html.escape(text)))


def nine(img, slice_css, width_css, x, y, w, h, role):
    return ('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;box-sizing:border-box;'
            'border:1px solid transparent;border-image:url(%s) %s fill / %s;filter:url(#t%s)"></div>'
            % (x, y, w, h, img, slice_css, width_css, role))


# ------------------------------------------------------------------ board ----
def board(width):
    icons = load("icons.json"); mapi = load("map_icons.json"); digits = load("digits.json")
    geo = load("static_geometry.json")
    H = 800
    o = ['<div class="card" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx">' % (M, M, width, H)]
    o.append(label(16, 10, "IN USE  (browser preview of the sprites and slices; the kit will reproduce this in Roblox)", 18, "White"))

    # A. icons at small sizes
    x = 16
    for px in (24, 32, 48):
        s = px * 8
        o.append(label(x, 44, "icons.png at %d px cells" % px))
        o.append('<img src="icons.png" style="position:absolute;left:%dpx;top:66px;width:%dpx;height:%dpx">' % (x, s, s))
        x += s + 24
    o.append(label(16, 66 + 180, "24 px, Ink on White (selected tile)"))
    o.append('<div style="position:absolute;left:16px;top:270px;width:192px;height:172px;background:%s"></div>' % rgb("White"))
    o.append('<img src="icons.png" style="position:absolute;left:16px;top:270px;width:192px;height:192px;filter:url(#tInk)">')
    o.append(label(232, 346, "24 px, Cyan / Yellow / Pink"))
    for k, role in enumerate(("Cyan", "Yellow", "Pink")):
        o.append('<img src="icons.png" style="position:absolute;left:232px;top:%dpx;width:192px;height:192px;filter:url(#t%s);'
                 'clip-path:inset(0 0 %dpx 0)">' % (368 + k * 30, role, 168))
    # map icons
    mx = 16
    o.append(label(16, 470, "map_icons.png at 24 / 32 / 48 px, tinted by family"))
    fam = {"Race": "Pink", "TimeTrial": "Pink", "Duel": "Pink", "Job": "Yellow", "TaxiFare": "Yellow",
           "CourierPickup": "Yellow", "TaxiDrop": "Yellow", "CourierDrop": "Yellow", "Customisation": "Cyan",
           "Dealership": "Cyan", "Garage": "Cyan", "Waypoint": "White", "Player": "White", "OtherPlayer": "TextMuted"}
    yy = 496
    for px in (24, 32, 48):
        sc = px / 128.0
        for i, (name, g) in enumerate(mapi["glyphs"].items()):
            o.append(sprite("map_icons.png", [512, 512], g["ImageRectOffset"], g["ImageRectSize"],
                            mx + i * (px + 8), yy, sc, fam[name]))
        yy += px + 12
    o.append(label(16, yy + 2, "(family colours here are only an example; the roles are Oscar's call)", 12))

    # B. numbers set from digits.json
    bx = 960
    o.append(label(bx, 44, "BigNumber set from digits.json (sprites, tight pitch)   |   same string as live Barlow Condensed text"))
    rows = [("187 MPH", "128", 1.0, "White", True), ("187", "128", 1.0, "White", False),
            ("$3,613,709", "128", 0.5, "Yellow", True), ("1:23.45", "128", 0.75, "White", True),
            ("+12%  x3  2/3  40K", "128", 0.5, "Cyan", True)]
    y = 70
    for text, tag, sc, role, tight in rows:
        hh, wd = number(digits, text, tag, bx, y, sc, role, tight)
        o.append(hh)
        fpx = digits["sheets"][tag]["font_px"] * sc
        base = digits["sheets"][tag]["baseline_y"] * sc
        o.append('<div style="position:absolute;left:%dpx;top:%.1fpx;font:italic 800 %.1fpx/1 \'Barlow Condensed\';color:%s;'
                 'white-space:pre;opacity:.55">%s</div>'
                 % (bx + 560, y + base - fpx * 0.8, fpx, rgb(role), html.escape(text)))
        o.append(label(bx + 400, y + 4, "tight" if tight else "safe pitch", 12))
        y += int(128 * sc) + 6
    hh, wd = number(digits, "3", "256", bx, y - 10, 1.0, "White")
    o.append(hh)
    hh, wd = number(digits, "12", "256", bx + 150, y - 10, 1.0, "Pink")
    o.append(hh)
    o.append(label(bx + 430, y + 100, "digits_256 at 1:1 (countdown, position)"))

    # C. gauge
    gx, gy, gs = 1820, 60, 400
    o.append(label(gx, 44, "gauge: ticks (TextMuted), track, ring (Cyan) at 62%, digits_128"))
    o.append('<img src="gauge_ticks.png" style="position:absolute;left:%dpx;top:%dpx;width:%dpx;filter:url(#tTextMuted);opacity:.7">' % (gx, gy, gs))
    o.append('<img src="gauge_ring.png" style="position:absolute;left:%dpx;top:%dpx;width:%dpx;opacity:.16">' % (gx, gy, gs))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;'
             '-webkit-mask-image:conic-gradient(from 225deg,#000 0 167deg,transparent 167deg);'
             'mask-image:conic-gradient(from 225deg,#000 0 167deg,transparent 167deg)">'
             '<img src="gauge_ring.png" style="width:100%%;filter:url(#tCyan)"></div>' % (gx, gy, gs, gs))
    hh, wd = number(digits, "187", "128", 0, 0, 1.0, "White")
    o.append('<div style="position:absolute;left:%.1fpx;top:%dpx">%s</div>' % (gx + gs / 2 - wd / 2, gy + 120, hh))
    hh, wd = number(digits, "MPH", "128", 0, 0, 0.25, "TextMuted")
    o.append('<div style="position:absolute;left:%.1fpx;top:%dpx">%s</div>' % (gx + gs / 2 - wd / 2, gy + 250, hh))

    # D. minimap
    mx, my, msz = 2260, 60, 256
    o.append(label(mx, 44, "minimap: vignette (Ink), ring, arrow, north"))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;border-radius:50%%;overflow:hidden;'
             'background:repeating-linear-gradient(60deg,#2a2846 0 26px,#8f8bb5 26px 38px,#2a2846 38px 90px)">'
             '<img src="minimap_vignette.png" style="width:100%%;filter:url(#tInk)"></div>' % (mx, my, msz, msz))
    o.append('<img src="minimap_ring.png" style="position:absolute;left:%dpx;top:%dpx;width:%dpx;filter:url(#tPink)">' % (mx, my, msz))
    o.append('<img src="map_player_arrow.png" style="position:absolute;left:%dpx;top:%dpx;width:36px;transform:rotate(25deg)">'
             % (mx + msz / 2 - 18, my + msz / 2 - 18))
    g = icons["glyphs"]["north"]
    o.append(sprite("icons.png", [1024, 1024], g["ImageRectOffset"], g["ImageRectSize"], mx + msz / 2 - 14, my + msz - 20, 28 / 128.0))

    # E. glows
    ex, ey = 1820, 480
    o.append(label(ex, ey - 22, "glow_soft on a selected tile, glow_line under the Pink base line, glow_tight on a main button"))
    tw, th = 150, 130
    o.append(nine("glow_soft.png", "62", "62px", ex + 30 - 44, ey + 20 - 44, tw + 88, th + 88, "White"))
    o.append(nine("glow_line.png", "0 30", "0 30px", ex + 30 - 20, ey + 20 + th - 2 - 32, tw + 40, 64, "Pink"))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;background:%s"></div>' % (ex + 30, ey + 20, tw, th, rgb("White")))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:4px;background:%s"></div>' % (ex + 30, ey + 20 + th - 4, tw, rgb("Pink")))
    g = icons["glyphs"]["boost"]
    o.append(sprite("icons.png", [1024, 1024], g["ImageRectOffset"], g["ImageRectSize"], ex + 30 + tw / 2 - 32, ey + 44, 0.5, "Ink"))
    bx2, by2, bw, bh = ex + 270, ey + 60, 230, 62
    o.append(nine("glow_tight.png", "30", "30px", bx2 - 20, by2 - 20, bw + 40, bh + 40, "Pink"))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;background:linear-gradient(90deg,%s,%s)"></div>'
             % (bx2, by2, bw, bh, rgb("Pink"), rgb("Violet")))
    g = icons["glyphs"]["steering_wheel"]
    o.append(sprite("icons.png", [1024, 1024], g["ImageRectOffset"], g["ImageRectSize"], bx2 + 28, by2 + 15, 0.25))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;font:italic 800 34px/1 Barlow;color:%s">DRIVE</div>' % (bx2 + 74, by2 + 14, rgb("White")))

    # F. key caps, segmented bar, chequer, touch
    kx, ky = 2760, 100
    o.append(label(kx, ky - 22, "keycap_9slice, segment_strip, pad glyphs"))
    for i, (txt, w) in enumerate((("E", 32), ("SHIFT", 78), ("SPACE", 84))):
        xx = kx + (0, 44, 134)[i]
        o.append(nine("keycap_9slice.png", "20", "10px", xx, ky, w, 32, "White"))
        o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;text-align:center;font:italic 800 17px/32px Barlow;color:%s">%s</div>'
                 % (xx, ky, w, rgb("Ink"), txt))
    for i, n in enumerate(("pad_a", "pad_b", "pad_x", "pad_y", "pad_lb", "pad_rt", "dpad")):
        g = icons["glyphs"][n]
        o.append(sprite("icons.png", [1024, 1024], g["ImageRectOffset"], g["ImageRectSize"], kx + i * 38, ky + 44, 32 / 128.0))
    for row, lit in enumerate((16, 11, 13)):
        yy = ky + 96 + row * 22
        for part, n, op in ((0, lit, 1.0), (lit, 20 - lit, 0.25)):
            o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:10px;background:url(segment_strip.png) 0 0 / 9px 10px repeat-x;'
                     'opacity:%s"></div>' % (kx + part * 9, yy, n * 9, op))
    tx, ty = 2760, 330
    o.append(label(tx, ty - 22, "touch controls at 84 px, 0.92 opacity, over a bright scene"))
    o.append(label(tx, ty + 130, "chequer_corner on a panel corner; wordmark placeholder at 35%"))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:200px;height:110px;background:#1b1a2e;outline:1px solid rgba(255,255,255,.2)"></div>' % (tx, ty + 180))
    o.append('<img src="chequer_corner.png" style="position:absolute;left:%dpx;top:%dpx;width:80px">' % (tx + 150, ty + 140))
    o.append('<img src="wordmark_placeholder.png" style="position:absolute;left:%dpx;top:%dpx;width:358px">' % (tx + 10, ty + 290))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:340px;height:100px;background:linear-gradient(90deg,#6c6f7a,#b9a58a)"></div>' % (tx, ty))
    marks = load("marks.json")
    for i, (name, g) in enumerate(marks["touch"]["images"].items()):
        o.append(sprite("touch_controls.png", [1024, 1024], g["ImageRectOffset"], g["ImageRectSize"], tx + 4 + i * 84, ty + 8, 84 / 512.0,
                        "White", "opacity:.92"))
    o.append("</div>")
    return "".join(o), H


# ------------------------------------------------------------------ cards ----
def card(entry, alt=False):
    f, key, purpose, data, tint = entry
    im = Image.open(os.path.join(OUT, f)); w, h = im.size
    big = max(w, h) > 256
    sc = 240.0 / max(w, h) if big else 1.0
    tw, th = int(w * sc), int(h * sc)
    cols = 2 if big else (5 if w <= 128 else 3)
    tints = TINTS if tint else []
    rows = int(math.ceil(len(tints) / float(cols))) if tints else 0
    block_w = cols * tw + (cols - 1) * 10 if tints else 0
    block_h = rows * (th + 26)
    cw = 2 * PAD + max(w + (16 + block_w if tints else 0), 640)
    ch = 2 * PAD + HEAD + max(h, block_h)
    kb = os.path.getsize(os.path.join(OUT, f)) / 1024.0
    o = []
    o.append('<div class="hd"><b>%s</b> &nbsp; %d x %d &nbsp; %.1f KB%s<br>%s<br><span class="k">%s%s</span> &nbsp; %s</div>'
             % (f, w, h, kb, " &nbsp; <b style='color:%s'>ALTERNATIVE, not in the count</b>" % rgb("Yellow") if alt else "",
                html.escape(purpose), ms.KEY, key, html.escape(json.dumps(data)) if data else ""))
    o.append('<img class="ol" src="%s" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx">' % (f, PAD, PAD + HEAD, w, h))
    for i, role in enumerate(tints):
        x = PAD + w + 16 + (i % cols) * (tw + 10); y = PAD + HEAD + (i // cols) * (th + 26)
        bg = rgb("White") if role == "Ink" else "transparent"
        o.append('<div class="ol" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx;background:%s">'
                 '<img src="%s" style="width:%dpx;height:%dpx;filter:url(#t%s)"></div>' % (x, y, tw, th, bg, f, tw, th, role))
        o.append(label(x, y + th + 3, role + (" on White" if role == "Ink" else "") + (" (%d%%)" % round(sc * 100) if sc != 1 else ""), 12))
    return "".join(o), cw, ch


def main():
    entries = [(e, False) for e in ms.BATCH] + [(e, True) for e in ms.ALTERNATIVES]
    cards = [card(e, alt) for e, alt in entries]
    bhtml, bh = board(PAGE_W - 2 * M)
    # shelf packing, tallest first so rows stay dense
    order = sorted(range(len(cards)), key=lambda i: (-cards[i][2], -cards[i][1]))
    x, y, row_h = M, M + bh + GAP, 0
    placed = []
    for i in order:
        c, cw, ch = cards[i]
        if x + cw > PAGE_W - M and x > M:
            x = M; y += row_h + GAP; row_h = 0
        placed.append('<div class="card" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx">%s</div>' % (x, y, cw, ch, c))
        x += cw + GAP; row_h = max(row_h, ch)
    page_h = y + row_h + M
    css = ("html,body{margin:0;background:#232136}body{position:relative;width:%dpx;height:%dpx;font-family:Barlow,Arial,sans-serif}"
           ".card{position:absolute;background:%s;overflow:hidden}"
           ".card>img,.card>div{position:absolute}"
           ".hd{left:%dpx;top:%dpx;right:%dpx;height:%dpx;overflow:hidden;color:%s;font-size:15px;line-height:21px;font-weight:600}"
           ".hd b{color:%s;font-size:17px}.k{color:%s}"
           ".ol{outline:1px solid rgba(255,255,255,.14)}.ol img{display:block}"
           ".lb{position:absolute;font-weight:600;font-style:italic;letter-spacing:.03em}"
           % (PAGE_W, page_h, rgb("Slate"), PAD, PAD - 4, PAD, HEAD, rgb("TextMuted"), rgb("White"), rgb("Cyan")))
    doc = ("<!doctype html><html><head><meta charset='utf-8'><title>Pulse UI upload batch: contact sheet</title>" + FONT_LINK +
           "<style>" + css + "</style></head><body>" + filters() + bhtml + "".join(placed) + "</body></html>")
    src = os.path.join(OUT, "contact_sheet.html")
    with open(src, "w", encoding="utf-8") as f:
        f.write(doc)
    im = render_file(src, PAGE_W, page_h, os.path.join(BUILD, "contact_sheet.raw.png"), background="ff232136")
    im.convert("RGB").save(os.path.join(OUT, "contact_sheet.png"), optimize=True)
    print("contact sheet: %d x %d, %d cards" % (PAGE_W, page_h, len(cards)))


if __name__ == "__main__":
    main()
