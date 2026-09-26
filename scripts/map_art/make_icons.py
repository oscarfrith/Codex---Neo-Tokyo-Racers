"""Draw the Space Racers map icon set (128x128 RGBA) and a contact sheet.

Pure-stdlib vector rasterizer: shapes are signed-distance functions in a
128-unit canvas, composited as layers and supersampled (SS x SS per pixel) for
anti-aliased edges. Output: icons/<Key>.png and icons/contact_sheet.png.

Style (matches the glyphs baked into the old minimap): flat glyph, crisp dark
outline where the glyph sits directly on the map, otherwise a round PanelDeep
badge with a thin role-coloured ring.
Colour roles:
  places (Dealership, Garage, Customisation)  cyan glyph on cyan ring
  activities (Race, TimeTrial, Duel)          white glyph on HighSpeed ring
  jobs (Job, TaxiFare, CourierPickup)         white glyph on ElectricBlue ring
  job drops (TaxiDrop, CourierDrop)           ElectricBlue pin, white glyph
  Waypoint                                    Outline-pink pin, white dot
  Player / OtherPlayer                        white arrow on cyan / blue dot
"""
import math
import pathlib

from png_rgba import write_png

HERE = pathlib.Path(__file__).parent
OUT = HERE / "icons"
N = 128
SS = 4


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


PANEL_DEEP = hexc("#090C10")
OUTLINE_DARK = hexc("#06080B")
CYAN = hexc("#2BE1DA")
CYAN_GLYPH = hexc("#66F2EE")  # the old baked glyph cyan (core ~#60F0F0)
PINK = hexc("#F42E97")
HIGHSPEED = hexc("#F6539F")
BLUE = hexc("#1974FF")
TEXT = hexc("#F6F8FC")
MAP_BLOCK = (51, 51, 51, 255)
MAP_ROAD = (128, 128, 128, 255)

# ---------------------------------------------------------------- SDF primitives


def circle(cx, cy, r):
    return lambda x, y: math.hypot(x - cx, y - cy) - r


def box(cx, cy, hw, hh, angle=0.0, radius=0.0):
    c, s = math.cos(angle), math.sin(angle)

    def f(x, y):
        dx, dy = x - cx, y - cy
        lx, ly = dx * c + dy * s, -dx * s + dy * c
        qx, qy = abs(lx) - hw + radius, abs(ly) - hh + radius
        return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - radius
    return f


def segment(ax, ay, bx, by, r):
    def f(x, y):
        px, py, vx, vy = x - ax, y - ay, bx - ax, by - ay
        h = max(0.0, min(1.0, (px * vx + py * vy) / (vx * vx + vy * vy)))
        return math.hypot(px - vx * h, py - vy * h) - r
    return f


def polygon(pts):
    n = len(pts)

    def f(x, y):
        d = (x - pts[0][0]) ** 2 + (y - pts[0][1]) ** 2
        sign = 1.0
        j = n - 1
        for i in range(n):
            ex, ey = pts[j][0] - pts[i][0], pts[j][1] - pts[i][1]
            wx, wy = x - pts[i][0], y - pts[i][1]
            h = max(0.0, min(1.0, (wx * ex + wy * ey) / (ex * ex + ey * ey)))
            d = min(d, (wx - ex * h) ** 2 + (wy - ey * h) ** 2)
            c1 = y >= pts[i][1]
            c2 = y < pts[j][1]
            c3 = ex * wy > ey * wx
            if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
                sign = -sign
            j = i
        return sign * math.sqrt(d)
    return f


def union(*fs):
    return lambda x, y: min(f(x, y) for f in fs)


def subtract(a, *bs):
    return lambda x, y: max(a(x, y), max(-b(x, y) for b in bs))


def intersect(a, b):
    return lambda x, y: max(a(x, y), b(x, y))


def grow(f, w):
    return lambda x, y: f(x, y) - w


def translate(f, dx, dy):
    return lambda x, y: f(x - dx, y - dy)


def scale(f, k, cx=64, cy=64):
    return lambda x, y: f(cx + (x - cx) / k, cy + (y - cy) / k) * k


# ---------------------------------------------------------------- rasterizer


def render(layers, size=N):
    """layers: list of (sdf, rgba) bottom to top. Returns RGBA bytearray (straight alpha)."""
    out = bytearray(size * size * 4)
    k = N / size
    offs = [(i + 0.5) / SS for i in range(SS)]
    for py in range(size):
        for px in range(size):
            ar = ag = ab = aa = 0.0
            for oy in offs:
                for ox in offs:
                    x, y = (px + ox) * k, (py + oy) * k
                    # composite top-down: first opaque cover wins, translucent layers blend
                    r = g = b = a = 0.0
                    for f, col in layers:
                        if f(x, y) <= 0:
                            ca = col[3] / 255.0
                            r = col[0] * ca + r * (1 - ca)
                            g = col[1] * ca + g * (1 - ca)
                            b = col[2] * ca + b * (1 - ca)
                            a = ca + a * (1 - ca)
                    ar += r
                    ag += g
                    ab += b
                    aa += a
            n = SS * SS
            o = (py * size + px) * 4
            if aa > 0:
                out[o] = min(255, int(round(ar / aa)))
                out[o + 1] = min(255, int(round(ag / aa)))
                out[o + 2] = min(255, int(round(ab / aa)))
            out[o + 3] = int(round(aa / n * 255))
    return out


# ---------------------------------------------------------------- glyphs (128-unit canvas, centre 64,64)


def glyph_brush():
    a = math.radians(-45)
    ux, uy = math.cos(a), math.sin(a)  # up-right along the brush

    def along(t):
        return 64 + ux * t, 64 + uy * t
    hx, hy = along(-30)
    head = box(*along(17), 12, 12, a, 3)
    ferrule = box(*along(0), 7, 8.5, a, 1.5)
    handle = segment(*along(-4), hx, hy, 5.2)
    hole = circle(hx, hy, 2.3)
    cut_tip = box(*along(30), 3.5, 5.0, a)  # bristle split
    gap = box(*along(7.5), 1.6, 14, a)       # dark line between ferrule and head
    body = union(subtract(head, translate(cut_tip, uy * 5, -ux * 5)), ferrule, handle)
    return subtract(body, hole, gap)


def glyph_house():
    roof = polygon([(64, 24), (100, 58), (92, 58), (92, 100), (36, 100), (36, 58), (28, 58)])
    door = box(64, 82, 16, 16)
    slats = union(box(64, 75, 14, 2.4), box(64, 83, 14, 2.4), box(64, 91, 14, 2.4))
    return union(subtract(roof, door), slats)


def glyph_car():
    body = box(64, 74, 36, 14, 0, 7)
    cabin = polygon([(40, 62), (48, 40), (80, 40), (88, 62)])
    glass = polygon([(47, 60), (53, 45), (75, 45), (81, 60)])
    lamps = union(circle(44, 73, 5.5), circle(84, 73, 5.5))
    grille = box(64, 78, 11, 2.5)
    wheels = union(box(42, 91, 7, 7, 0, 2), box(86, 91, 7, 7, 0, 2))
    return union(subtract(union(body, cabin), glass, lamps, grille), wheels)


def glyph_flag():
    pole = box(33, 66, 3.5, 36, 0, 1.5)
    # waving flag: 4 x 3 checks between two sine edges
    x0, x1, top, h = 38, 98, 30, 36

    def wave(x):
        return 4.5 * math.sin((x - x0) / (x1 - x0) * 2 * math.pi)

    def f(x, y):
        if x < x0 or x > x1:
            return 1.0
        t = y - top - wave(x)
        return max(-t, t - h, x0 - x, x - x1) if 0 <= t <= h else max(-t, t - h)
    frame = f

    def checks(x, y):
        if frame(x, y) > 0:
            return 1.0
        cx = int((x - x0) / ((x1 - x0) / 5.0))
        cy = int((y - top - wave(x)) / (h / 3.0))
        return -1.0 if (cx + cy) % 2 == 0 else 1.0
    return union(pole, frame), checks


def glyph_stopwatch():
    ring = subtract(circle(64, 70, 32), circle(64, 70, 23))
    crown = box(64, 30, 8, 4.5, 0, 1.5)
    stem = box(64, 36, 3.5, 4)
    button = box(90, 42, 4, 4.5, math.radians(45), 1)
    hand = segment(64, 70, 76, 55, 3.6)
    hub = circle(64, 70, 5)
    ticks = union(box(64, 53, 2, 3.5), box(81, 70, 3.5, 2), box(47, 70, 3.5, 2), box(64, 87, 2, 3.5))
    return union(ring, crown, stem, button, hand, hub, ticks)


def glyph_versus():
    """Two chevrons meeting head-on (> <): a clash / duel."""
    left = union(segment(32, 42, 52, 64, 6.5), segment(52, 64, 32, 86, 6.5))
    right = union(segment(96, 42, 76, 64, 6.5), segment(76, 64, 96, 86, 6.5))
    spark = polygon([(64, 52), (67, 61), (74, 64), (67, 67), (64, 76), (61, 67), (54, 64), (61, 61)])
    return union(left, right, spark)


def glyph_person_hail():
    head = circle(56, 38, 10)
    torso = box(56, 72, 13, 20, 0, 7)
    arm = segment(66, 58, 84, 30, 5.2)
    hand = circle(85, 27, 6.2)
    legs = union(box(50, 94, 5, 10, 0, 2.5), box(62, 94, 5, 10, 0, 2.5))
    return union(head, torso, arm, hand, legs)


def glyph_parcel():
    """Isometric parcel: a hexagon cube with a Y of dark edges and a tape stripe on the lid."""
    cx, cy, r = 64, 66, 38
    pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in (-90, -30, 30, 90, 150, 210)]
    cube = polygon(pts)
    top, ur, lr, bottom, ll, ul = pts
    edges = union(segment(cx, cy, ul[0], ul[1], 2.4), segment(cx, cy, ur[0], ur[1], 2.4), segment(cx, cy, bottom[0], bottom[1], 2.4))
    # tape across the lid, parallel to the upper-left edge, through the lid centre
    lid_c = ((top[0] + cx) / 2.0, (top[1] + cy) / 2.0)
    dx, dy = (ur[0] - top[0]) / 2.0, (ur[1] - top[1]) / 2.0
    tape = segment(lid_c[0] - dx * 0.95, lid_c[1] - dy * 0.95, lid_c[0] + dx * 0.95, lid_c[1] + dy * 0.95, 2.2)
    return subtract(cube, edges, tape)


def glyph_briefcase():
    case = box(64, 72, 34, 22, 0, 5)
    handle = subtract(box(64, 45, 14, 10, 0, 4), box(64, 47, 8, 6, 0, 2))
    band = box(64, 70, 34, 2.2)
    clasp = box(64, 70, 6, 5, 0, 1.5)
    return union(subtract(union(case, handle), band), clasp)


def glyph_arrow():
    return polygon([(64, 12), (104, 110), (64, 88), (24, 110)])


def pin_shape(cx=64, top=8, r=36, tip=122):
    cy = top + r
    head = circle(cx, cy, r)
    # tangent lines from the tip to the circle
    d = tip - cy
    ang = math.asin(r / d)
    tx = r * math.cos(ang)
    ty = r * math.sin(ang)
    cone = polygon([(cx - tx, cy + ty), (cx, tip), (cx + tx, cy + ty)])
    return union(head, cone), (cx, cy)


# ---------------------------------------------------------------- icon compositions


def badge(ring_col, glyph, glyph_col, glyph_scale=1.0, extra=None):
    g = scale(glyph, glyph_scale) if glyph_scale != 1.0 else glyph
    layers = [
        (circle(64, 64, 62), OUTLINE_DARK),
        (circle(64, 64, 59), ring_col),
        (circle(64, 64, 52), PANEL_DEEP),
        (g, glyph_col),
    ]
    if extra:
        layers += extra
    return layers


def pin(col, inner_layers):
    shape, (cx, cy) = pin_shape()
    return [(grow(shape, 3.5), OUTLINE_DARK), (shape, col)] + [(f, c) for f, c in inner_layers]


def icons():
    flag, checks = glyph_flag()
    flag_s = scale(flag, 0.88)
    checks_s = scale(checks, 0.88)
    parcel_small = translate(scale(glyph_parcel(), 0.56), 0, -21)
    head = circle(64, 33, 9.5)
    shoulders = intersect(circle(64, 68, 20), box(64, 57, 22, 11))
    person_small = union(head, shoulders)
    shape, (pcx, pcy) = pin_shape()
    return {
        "Customisation": badge(CYAN, glyph_brush(), CYAN_GLYPH, 1.12),
        "Garage": badge(CYAN, glyph_house(), CYAN_GLYPH, 1.0),
        "Dealership": badge(CYAN, glyph_car(), CYAN_GLYPH, 1.04),
        "Race": badge(HIGHSPEED, flag_s, TEXT, 1.0, [(intersect(flag_s, checks_s), PANEL_DEEP)]),
        "TimeTrial": badge(HIGHSPEED, glyph_stopwatch(), TEXT, 0.98),
        "Duel": badge(HIGHSPEED, glyph_versus(), TEXT, 1.0),
        "Job": badge(BLUE, glyph_briefcase(), TEXT, 1.0),
        "TaxiFare": badge(BLUE, glyph_person_hail(), TEXT, 0.98),
        "CourierPickup": badge(BLUE, glyph_parcel(), TEXT, 1.0),
        "CourierDrop": pin(BLUE, [(circle(pcx, pcy, 28), PANEL_DEEP), (parcel_small, TEXT)]),
        "TaxiDrop": pin(BLUE, [(circle(pcx, pcy, 28), PANEL_DEEP), (person_small, TEXT)]),
        "Waypoint": pin(PINK, [(circle(pcx, pcy, 14), TEXT)]),
        "Player": [(grow(glyph_arrow(), 7), OUTLINE_DARK), (grow(glyph_arrow(), 3.5), CYAN), (glyph_arrow(), TEXT)],
        "OtherPlayer": [(circle(64, 64, 34), OUTLINE_DARK), (circle(64, 64, 30), TEXT), (circle(64, 64, 23), BLUE)],
    }


ANCHORS = {"CourierDrop": [0.5, 0.953], "TaxiDrop": [0.5, 0.953], "Waypoint": [0.5, 0.953]}

# ---------------------------------------------------------------- contact sheet helpers

FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    " ": ["00000"] * 7,
}


def downsample(src, sw, dw):
    """Area-average (premultiplied) square resample sw -> dw."""
    k = sw / dw
    out = bytearray(dw * dw * 4)
    for dy in range(dw):
        y0, y1 = dy * k, (dy + 1) * k
        for dx in range(dw):
            x0, x1 = dx * k, (dx + 1) * k
            acc = [0.0, 0.0, 0.0, 0.0]
            wsum = 0.0
            for sy in range(int(y0), min(sw, int(math.ceil(y1)))):
                wy = min(y1, sy + 1) - max(y0, sy)
                for sx in range(int(x0), min(sw, int(math.ceil(x1)))):
                    w = wy * (min(x1, sx + 1) - max(x0, sx))
                    i = (sy * sw + sx) * 4
                    a = src[i + 3] / 255.0
                    acc[0] += src[i] * a * w
                    acc[1] += src[i + 1] * a * w
                    acc[2] += src[i + 2] * a * w
                    acc[3] += a * w
                    wsum += w
            o = (dy * dw + dx) * 4
            if acc[3] > 0:
                out[o] = int(round(acc[0] / acc[3]))
                out[o + 1] = int(round(acc[1] / acc[3]))
                out[o + 2] = int(round(acc[2] / acc[3]))
            out[o + 3] = int(round(acc[3] / wsum * 255))
    return out


class Canvas:
    def __init__(self, w, h, bg):
        self.w, self.h = w, h
        self.d = bytearray(bytes(bg[:3]) + b"\xff") * (w * h)

    def fill(self, x0, y0, x1, y1, col):
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                self.d[(y * self.w + x) * 4:(y * self.w + x) * 4 + 4] = bytes(col[:3]) + b"\xff"

    def blit(self, img, iw, x0, y0):
        for y in range(iw):
            for x in range(iw):
                i = (y * iw + x) * 4
                a = img[i + 3] / 255.0
                if a == 0:
                    continue
                o = ((y0 + y) * self.w + x0 + x) * 4
                for c in range(3):
                    self.d[o + c] = int(round(img[i + c] * a + self.d[o + c] * (1 - a)))

    def text(self, s, x, y, col, px=2):
        for ch in s.upper():
            rows = FONT.get(ch) or FONT[" "]
            for ry, row in enumerate(rows):
                for rx, bit in enumerate(row):
                    if bit == "1":
                        self.fill(x + rx * px, y + ry * px, x + (rx + 1) * px, y + (ry + 1) * px, col)
            x += 6 * px


def main():
    OUT.mkdir(exist_ok=True)
    rendered = {}
    for key, layers in icons().items():
        img = render(layers)
        write_png(str(OUT / ("%s.png" % key)), N, N, img)
        rendered[key] = img
        print("icon", key)
    keys = list(rendered)
    cell = 150
    cols = 7
    rows = (len(keys) + cols - 1) // cols
    sheet = Canvas(cols * cell, rows * cell + 40, MAP_BLOCK)
    sheet.text("MAP ICONS  24PX AND 64PX ON MAP BLOCK AND ROAD", 10, 12, TEXT)
    for idx, key in enumerate(keys):
        cx, cy = (idx % cols) * cell, (idx // cols) * cell + 40
        sheet.fill(cx + 100, cy + 10, cx + 140, cy + 80, MAP_ROAD)  # road strip behind a 24 px copy
        small = downsample(rendered[key], N, 24)
        big = downsample(rendered[key], N, 64)
        sheet.blit(big, 64, cx + 10, cy + 12)
        sheet.blit(small, 24, cx + 80, cy + 32)
        sheet.blit(small, 24, cx + 108, cy + 32)
        small20 = downsample(rendered[key], N, 20)
        sheet.blit(small20, 20, cx + 110, cy + 58)
        sheet.text(key, cx + 8, cy + 100, TEXT, 1 if len(key) > 11 else 2)
    write_png(str(OUT / "contact_sheet.png"), sheet.w, sheet.h, sheet.d)
    # 4x nearest preview of the 24 px versions for pixel-level review
    z = 4
    prev = Canvas(len(keys) * (24 * z + 8) + 8, 24 * z + 16, MAP_BLOCK)
    for idx, key in enumerate(keys):
        small = downsample(rendered[key], N, 24)
        big = bytearray(24 * z * 24 * z * 4)
        for y in range(24 * z):
            for x in range(24 * z):
                i = ((y // z) * 24 + x // z) * 4
                o = (y * 24 * z + x) * 4
                big[o:o + 4] = small[i:i + 4]
        prev.blit(big, 24 * z, 8 + idx * (24 * z + 8), 8)
    write_png(str(OUT / "preview_24px_x4.png"), prev.w, prev.h, prev.d)


if __name__ == "__main__":
    main()
