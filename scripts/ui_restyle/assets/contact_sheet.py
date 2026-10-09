"""Contact sheet for the upload batch: out/contact_sheet.html and out/contact_sheet.png.

Top board: the art in use (icon legibility strips at 24 / 32 / 48 px, sprite-set numbers, gauge, minimap
with the rank arc, glows, key caps, and the touch controls at phone size, idle and pressed).
Also writes two small sheets that can be shown on their own: out/contact_sheet_icons.png and
out/contact_sheet_rings_touch.png (each under 2000 px on the long side). Review 3 (2026-10-09): the rings,
gauge and touch controls are baked-colour images, shown as they are (never tinted).
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


# ------------------------------------------------------------ touch controls ----
SCENE = ("background:radial-gradient(60% 90% at 22% 30%,rgba(255,45,149,.30),transparent 70%),"
         "radial-gradient(50% 80% at 78% 22%,rgba(34,228,255,.22),transparent 70%),"
         "radial-gradient(70% 60% at 55% 100%,rgba(255,170,60,.20),transparent 70%),"
         "linear-gradient(180deg,#2b2740,#17141f 55%,#221d2a)")


def reveal(start, sweep):
    """Stand-in for the rotating UIGradient mask. Angles as in rings.json (clockwise from +X); CSS starts at 12 o'clock."""
    m = "conic-gradient(from %sdeg,#000 0 %.2fdeg,transparent %.2fdeg)" % (start + 90, sweep, sweep)
    return "-webkit-mask-image:%s;mask-image:%s;" % (m, m)


def layer(f, x, y, size, extra=""):
    return '<img src="%s" style="position:absolute;left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;%s">' % (f, x, y, size, size, extra)


def gauge(x, y, size, f, boost, digits=None, speed=""):
    """The five gauge layers, the bright tip (glow_soft in Roblox) and, optionally, the speed in sprite digits."""
    o = [layer("gauge_track.png", x, y, size), layer("gauge_ticks.png", x, y, size),
         layer("gauge_glow.png", x, y, size, reveal(135, 270 * f)), layer("gauge_arc_gradient.png", x, y, size, reveal(135, 270 * f)),
         layer("boost_arc_gradient.png", x, y, size, reveal(135, 270 * boost))]
    if f > 0.01:
        a = math.radians(135 + 270 * f); r = size * 210 / 512.0; d = size * 0.09
        o.append('<div style="position:absolute;left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;border-radius:50%%;'
                 'background:radial-gradient(circle,#fff 0,rgba(255,255,255,.85) 22%%,rgba(255,255,255,0) 70%%)"></div>'
                 % (x + size / 2 + r * math.cos(a) - d / 2, y + size / 2 + r * math.sin(a) - d / 2, d, d))
    if digits and speed:
        sc = size / 400.0
        hh, wd = number(digits, speed, "128", 0, 0, sc, "White")
        o.append('<div style="position:absolute;left:%.1fpx;top:%.1fpx">%s</div>' % (x + size / 2 - wd / 2, y + size * 0.30, hh))
        hh, wd = number(digits, "MPH", "128", 0, 0, 0.25 * sc, "TextMuted")
        o.append('<div style="position:absolute;left:%.1fpx;top:%.1fpx">%s</div>' % (x + size / 2 - wd / 2, y + size * 0.64, hh))
    return "".join(o)


def minimap(x, y, msz, xp=0.42):
    """Map stand-in with the vignette, the gradient ring, the arrow and the rank arc (track + fill)."""
    ring = msz * 512 / 480.0; arc = ring * 1.099; cx, cy = x + msz / 2.0, y + msz / 2.0
    return ('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;border-radius:50%%;overflow:hidden;'
            'background:repeating-linear-gradient(60deg,#2a2846 0 26px,#8f8bb5 26px 38px,#2a2846 38px 90px)">'
            '<img src="minimap_vignette.png" style="width:100%%;filter:url(#tInk)"></div>' % (x, y, msz, msz) +
            layer("minimap_ring_gradient.png", cx - ring / 2, cy - ring / 2, ring) +
            '<img src="map_player_arrow.png" style="position:absolute;left:%dpx;top:%dpx;width:36px;transform:rotate(25deg)">' % (cx - 18, cy - 18) +
            layer("rank_arc_gradient.png", cx - arc / 2, cy - arc / 2, arc, "opacity:.25;" + reveal(180, 90)) +
            layer("rank_arc_gradient.png", cx - arc / 2, cy - arc / 2, arc, reveal(180, 90 * xp)))


def tc(touch, name, x, y, k=1.0, pressed=False, mirror=False, opacity=1.0):
    """One touch control with its plate's top-left corner at (x, y) dp, k px per dp."""
    g = touch["images"]["touch_" + name]
    w, h = g["plate_dp"]; v = g["frame_dp"][0]
    f = "touch_%s%s.png" % (name, "_pressed" if pressed else "")
    return layer(f, (x - (v - w) / 2.0) * k, (y - (v - h) / 2.0) * k, v * k,
                 ("transform:scaleX(-1);" if mirror else "") + ("opacity:%s;" % opacity if opacity != 1 else ""))


def phone(touch, x, y, mode, k=1.0, title="", digits=None):
    """The drive controls laid out as on a phone (844 x 390 dp, k px per dp, 47 dp side insets, 21 dp home bar).
    mode: idle | pressed | play | off."""
    W, H = 844, 390
    o = ['<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;overflow:hidden;%s">'
         % (x, y, W * k, H * k, SCENE)]
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;'
             'background:linear-gradient(180deg,rgba(14,13,26,0),rgba(14,13,26,.45))"></div>' % (0, H * k * 0.5, W * k, H * k * 0.5))
    on = {"idle": set(), "off": set(), "pressed": {"accel", "brake", "tl", "tr", "dl", "dr", "boost"}, "play": {"accel", "tr", "dr"}}[mode]
    items = [("tl", "turn", 55, 305, False), ("tr", "turn", 115, 305, True), ("dl", "drift", 55, 241, False), ("dr", "drift", 115, 241, True),
             ("boost", "boost", 87, 181, False), ("brake", "brake", 607, 297, False), ("accel", "accelerate", 717, 261, False)]
    for key, name, px, py, mir in items:
        o.append(tc(touch, name, px, py, k, key in on, mir, 0.4 if mode == "off" else 1.0))
    charge = {"idle": 1.0, "pressed": 0.4, "play": 0.64, "off": 0.0}[mode]
    o.append(layer("rank_arc_gradient.png", 81 * k, 175 * k, 60 * k, "opacity:.25;"))
    if charge:
        o.append(layer("rank_arc_gradient.png", 81 * k, 175 * k, 60 * k, reveal(270, 360 * charge)))
    speed = {"idle": ("0", 0.0), "pressed": ("96", 0.4), "play": ("142", 142 / 240.0), "off": ("0", 0.0)}[mode]
    o.append(gauge(376 * k, 271 * k, 92 * k, speed[1], charge, digits, speed[0]))
    if title:
        o.append(label(int(16 * k), int(12 * k), title, 15, "White"))
    o.append("</div>")
    return "".join(o)


def icon_strip(icons, x, y, px, per, role="White", sheet="icons.png", size=(1024, 1024), gap=8):
    o = []
    for i, (name, g) in enumerate(icons["glyphs"].items()):
        o.append(sprite(sheet, list(size), g["ImageRectOffset"], g["ImageRectSize"],
                        x + (i % per) * (px + gap), y + (i // per) * (px + gap), px / 128.0, role))
    rows = (len(icons["glyphs"]) + per - 1) // per
    return "".join(o), rows * (px + gap)


# ------------------------------------------------------------------ board ----
def board(width):
    icons = load("icons.json"); mapi = load("map_icons.json"); digits = load("digits.json")
    geo = load("static_geometry.json")
    H = 1250
    o = ['<div class="card" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx">' % (M, M, width, H)]
    o.append(label(16, 10, "IN USE  (browser preview of the sprites and slices; the kit will reproduce this in Roblox)", 18, "White"))

    # A. icons at small sizes
    x = 16
    for px in (24, 32, 48):
        s = px * 8
        o.append(label(x, 44, "legibility: icons.png at %d px cells" % px))
        o.append('<img src="icons.png" style="position:absolute;left:%dpx;top:66px;width:%dpx;height:%dpx">' % (x, s, s))
        x += s + 24
    o.append(label(232, 332, "24 px, Ink on White (selected tile)"))
    o.append('<div style="position:absolute;left:232px;top:354px;width:192px;height:54px;background:%s"></div>' % rgb("White"))
    o.append('<img src="icons.png" style="position:absolute;left:232px;top:354px;width:192px;height:192px;filter:url(#tInk);clip-path:inset(0 0 144px 0)">')
    o.append(label(232, 416, "24 px, Cyan / Yellow / Pink"))
    for k, role in enumerate(("Cyan", "Yellow", "Pink")):
        o.append('<img src="icons.png" style="position:absolute;left:232px;top:%dpx;width:192px;height:192px;filter:url(#t%s);'
                 'clip-path:inset(0 0 %dpx 0)">' % (438 + k * 30, role, 168))
    # map icons
    mx = 16
    o.append(label(16, 546, "map_icons.png at 24 / 32 / 48 px, tinted by family"))
    fam = {"Race": "Pink", "TimeTrial": "Pink", "Duel": "Pink", "Job": "Yellow", "TaxiFare": "Yellow",
           "CourierPickup": "Yellow", "TaxiDrop": "Yellow", "CourierDrop": "Yellow", "Customisation": "Cyan",
           "Dealership": "Cyan", "Garage": "Cyan", "Waypoint": "White", "Player": "White", "OtherPlayer": "TextMuted"}
    yy = 572
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

    # C. gauge (review 3: five baked-colour layers, revealed by a mask; nothing is tinted)
    gx, gy, gs = 1820, 60, 400
    o.append(label(gx, 44, "gauge: track + ticks + glow + speed arc at 78% + boost arc at 30%, digits_128"))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;%s"></div>' % (gx - 10, gy - 6, gs + 20, gs + 12, SCENE))
    o.append(gauge(gx, gy, gs, 187 / 240.0, 0.30, digits, "187"))

    # D. minimap
    mx, my, msz = 2290, 86, 256
    o.append(label(mx - 30, 44, "minimap: vignette (Ink), gradient ring, arrow, rank arc"))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;%s"></div>' % (mx - 34, my - 32, msz + 68, msz + 64, SCENE))
    o.append(minimap(mx, my, msz))
    g = icons["glyphs"]["north"]
    o.append(sprite("icons.png", [1024, 1024], g["ImageRectOffset"], g["ImageRectSize"], mx + msz / 2 - 14, my + msz - 20, 28 / 128.0))
    o.append(label(mx - 30, my + msz + 36, "rank arc: rank_arc_gradient.png, track at 25%, fill at 42% XP", 12))

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
    o.append(label(tx, ty + 130, "chequer_corner on a panel corner; wordmark placeholder at 35%"))
    ty -= 110
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:200px;height:110px;background:#1b1a2e;outline:1px solid rgba(255,255,255,.2)"></div>' % (tx, ty + 180))
    o.append('<img src="chequer_corner.png" style="position:absolute;left:%dpx;top:%dpx;width:80px">' % (tx + 150, ty + 140))
    o.append('<img src="wordmark_placeholder.png" style="position:absolute;left:%dpx;top:%dpx;width:358px">' % (tx + 10, ty + 290))
    touch = load("touch.json")
    o.append(label(16, 806, "touch controls at phone size (844 x 390 dp, 1 px per dp): idle, every control pressed, and in play "
                            "(accelerate, turn right and drift right held, boost charge at 64%). Baked colour, as uploaded.", 16, "White"))
    for n, (mode, ttl) in enumerate((("idle", "IDLE"), ("pressed", "PRESSED"), ("play", "IN PLAY"))):
        o.append(phone(touch, 16 + n * 860, 836, mode, 1.0, ttl, digits))
    o.append(label(2610, 836, "the same controls at 1.5x, idle then pressed", 14))
    o.append('<div style="position:absolute;left:2600px;top:856px;width:600px;height:372px;%s"></div>' % SCENE)
    lx = 2618.0
    for name in ("turn", "drift", "boost", "brake"):
        w = touch["images"]["touch_" + name]["plate_dp"][0]
        o.append(tc(touch, name, lx / 1.5, 876 / 1.5, 1.5)); o.append(tc(touch, name, lx / 1.5, 1020 / 1.5, 1.5, True)); lx += w * 1.5 + 14
    o.append(tc(touch, "accelerate", lx / 1.5 + 8, 870 / 1.5, 1.5)); o.append(tc(touch, "accelerate", lx / 1.5 + 8, 1040 / 1.5, 1.5, True))
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


def _page(body, w, h, name, title):
    css = ("html,body{margin:0;background:%s}body{position:relative;width:%dpx;height:%dpx;font-family:Barlow,Arial,sans-serif;overflow:hidden}"
           ".lb{position:absolute;font-weight:600;font-style:italic;letter-spacing:.03em}"
           % (rgb("Slate"), w, h))
    doc = ("<!doctype html><html><head><meta charset='utf-8'><title>%s</title>" % title + FONT_LINK +
           "<style>" + css + "</style></head><body>" + filters() + body + "</body></html>")
    src = os.path.join(OUT, name + ".html")
    with open(src, "w", encoding="utf-8") as f:
        f.write(doc)
    im = render_file(src, w, h, os.path.join(BUILD, name + ".raw.png"), background="ff0e0d1a")
    im.convert("RGB").save(os.path.join(OUT, name + ".png"), optimize=True)
    print("%s: %d x %d" % (name, w, h))


def small_icons():
    icons = load("icons.json"); mapi = load("map_icons.json")
    W, H = 1960, 1010
    o = [label(24, 16, "PULSE ICON SHEET, SECOND PASS  -  58 glyphs, white on transparent, 128 px cells, 96 px ink box, %d px line weight"
               % icons["stroke"], 20, "White")]
    o.append(label(24, 52, "icons.png at 75% (drift and gauge are new, appended in the last row)"))
    o.append('<img src="icons.png" style="position:absolute;left:24px;top:78px;width:768px;height:768px">')
    x = 830; y = 52
    for px in (24, 32, 48):
        o.append(label(x, y, "legibility strip: every glyph at %d px" % px))
        h, used = icon_strip(icons, x, y + 24, px, 20)
        o.append(h); y += 24 + used + 14
    o.append(label(x, y, "24 px, Ink on White (selected tile)"))
    o.append('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;background:%s"></div>' % (x - 6, y + 20, 20 * 32 + 4, 3 * 32 + 4, rgb("White")))
    h, used = icon_strip(icons, x, y + 24, 24, 20, "Ink"); o.append(h)
    o.append(label(x + 680, y, "24 px, Cyan / Yellow / Pink / Muted"))
    for k, role in enumerate(("Cyan", "Yellow", "Pink", "TextMuted")):
        g = list(icons["glyphs"].items())[k * 8: k * 8 + 13]
        for i, (name, gg) in enumerate(g):
            o.append(sprite("icons.png", [1024, 1024], gg["ImageRectOffset"], gg["ImageRectSize"], x + 680 + i * 32, y + 24 + k * 30, 24 / 128.0, role))
    y += 24 + used + 16
    o.append(label(x, y, "1:1: the glyphs called out in review (checkpoints, duel, set_route, car, garage, drift, LB, LT)"))
    for i, n in enumerate(("checkpoints", "duel", "set_route", "car", "garage", "drift", "pad_lb", "pad_lt")):
        gg = icons["glyphs"][n]
        o.append(sprite("icons.png", [1024, 1024], gg["ImageRectOffset"], gg["ImageRectSize"], x + i * 136, y + 26, 1.0))
    y += 26 + 128 + 16
    o.append(label(x, y, "map_icons.png at 24 / 32 / 48 px"))
    xx = x
    for px in (24, 32, 48):
        h, used = icon_strip(mapi, xx, y + 26, px, 7, "White", "map_icons.png", (512, 512)); o.append(h)
        xx += 7 * (px + 8) + 20
    o.append(label(24, 866, "gamepad glyphs at 24 px and 48 px:"))
    for i, n in enumerate(("pad_a", "pad_b", "pad_x", "pad_y", "pad_lb", "pad_rb", "pad_lt", "pad_rt", "pad_select", "pad_start", "dpad", "keycap_blank")):
        gg = icons["glyphs"][n]
        o.append(sprite("icons.png", [1024, 1024], gg["ImageRectOffset"], gg["ImageRectSize"], 24 + i * 64, 896, 24 / 128.0))
        o.append(sprite("icons.png", [1024, 1024], gg["ImageRectOffset"], gg["ImageRectSize"], 24 + i * 64, 930, 48 / 128.0))
    _page("".join(o), W, H, "contact_sheet_icons", "Pulse icons, second pass")


def small_rings_touch():
    """Review 3 sheet: the gradient rings, the gauge and the restyled touch controls on a dark scene. 1900 x 1190."""
    touch = load("touch.json"); digits = load("digits.json")
    W, H = 1900, 1190
    o = ['<div style="position:absolute;left:0;top:0;width:%dpx;height:%dpx;%s"></div>' % (W, H, SCENE),
         '<div style="position:absolute;left:0;top:0;width:%dpx;height:%dpx;background:rgba(14,13,26,.35)"></div>' % (W, H)]
    o.append(label(24, 14, "PULSE RINGS, GAUGE AND TOUCH CONTROLS  -  review 3: baked-colour images (not tinted), shown as uploaded", 20, "White"))
    o.append(label(24, 50, "speed gauge = gauge_track + gauge_ticks + gauge_glow + gauge_arc_gradient + boost_arc_gradient; the arcs are revealed by a rotating mask", 14, "White"))
    o.append(gauge(24, 78, 400, 187 / 240.0, 0.30, digits, "187"))
    for i, (f, b, sp) in enumerate(((0.0, 1.0, "0"), (0.42, 0.64, "101"), (1.0, 0.1, "240"))):
        o.append(gauge(450 + i * 196, 78, 184, f, b, digits, sp))
    o.append(label(450, 272, "empty, 42%, full: a part-filled arc always ends in its own colour; the white tip is glow_soft", 12, "White"))
    for i, f in enumerate(("gauge_track.png", "gauge_ticks.png", "gauge_glow.png", "gauge_arc_gradient.png", "boost_arc_gradient.png")):
        o.append(layer(f, 450 + i * 118, 306, 112)); o.append(label(450 + i * 118, 422, f[:-4].replace("_gradient", ""), 11, "White"))
    o.append(label(1070, 50, "minimap_ring_gradient + rank_arc_gradient (track 25%, fill 42%)", 14, "White"))
    o.append(minimap(1100, 110, 300))
    o.append(layer("minimap_ring_gradient.png", 1460, 86, 190)); o.append(layer("rank_arc_gradient.png", 1680, 86, 190))
    o.append(label(1460, 280, "the two ring images, whole", 12, "White"))
    o.append(layer("title_slash_gradient.png", 1470, 320, 80, "height:96px")); o.append(label(1560, 356, "title_slash_gradient", 12, "White"))
    o.append(label(24, 486, "touch controls: the current (Classic) pictograms and positions on Pulse plates. 844 x 390 dp at 1.5 px per dp; "
                            "accelerate, turn right and drift right held; boost charge 64%", 14, "White"))
    o.append(phone(touch, 24, 514, "play", 1.5, "", digits))
    x0 = 1320
    o.append(label(x0, 514, "idle / pressed / disabled, 2 px per dp", 14, "White"))
    lx = x0
    for name in ("turn", "drift", "boost"):
        for r, (pr, op) in enumerate(((False, 1), (True, 1), (False, 0.4))):
            o.append(tc(touch, name, lx / 2.0 + 6, (548 + r * 124) / 2.0, 2.0, pr, False, op))
        lx += 124
    for r, (pr, op) in enumerate(((False, 1), (True, 1))):
        o.append(tc(touch, "brake", (x0 + r * 172) / 2.0 + 6, 926 / 2.0, 2.0, pr, False, op))
    for r, (pr, op) in enumerate(((False, 1), (True, 1))):
        o.append(tc(touch, "accelerate", (x0 + 376) / 2.0 + 6, (548 + r * 218) / 2.0, 2.0, pr, False, op))
    o.append(label(x0, 1066, "right-hand turn and drift = the same images mirrored;", 12, "White"))
    o.append(label(x0, 1084, "disabled = idle at 40%; boost charge ring = rank_arc_gradient", 12, "White"))
    _page("".join(o), W, H, "contact_sheet_rings_touch", "Pulse rings, gauge and touch controls (review 3)")


def main(icons=True):
    if icons:
        small_icons()
    small_rings_touch()
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
