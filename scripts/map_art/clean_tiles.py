"""Detect the POI icons baked into the minimap tiles and write cleaned tiles.

Input : tiles/MapTile*.png (1024x1024 RGBA; together the 2048x2048 minimap)
Output: detected_pois.json, crops/<poi>_4x.png, crops/<poi>_before_after_4x.png,
        clean/MapTile*.png (icons removed, map reconstructed; every pixel outside
        an icon mask is byte-identical to the source).

Detection: the map itself is pure grey (r == g == b) roads/blocks plus a light
coast stroke, so an icon is a cluster of saturated pixels (cyan / lime glyphs)
of at least MIN_CLUSTER pixels. The icon mask is the glyph plus its dark
outline, any holes it encloses (garage door slats, flag checks), dilated 1 px.

Reconstruction (directional inpainting): for each masked pixel, rays are cast
in 72 orientations to the first known pixel on both sides. An orientation is
usable when both ends agree in colour. Road-to-road spans whose road continues
along the ray beyond both ends, and whose local road direction (structure
tensor of the known grey pixels) matches the ray within TANGENT_DEG, win
("roads run through"; curve chords do not qualify); otherwise the
shortest consistent span wins. The value is the distance-weighted blend of the
two ends, so road anti-aliasing carries through the hole.
"""
import json
import math
import pathlib

import common
from png_rgba import write_png

HERE = pathlib.Path(__file__).parent
S = common.SIZE
MIN_CLUSTER = 60
ANGLES = 72
MAX_RAY = 60
CONSISTENT = 20
ROAD_MATCH = 10  # road ends must be the same road class (minor ~128 vs arterial ~152)
ALONG = 20
TANGENT_DEG = 14
SHORT_ROAD_GAP = 6

MEANINGS = {
    "cyan_ring": ("Customisation", "Paint-brush glyph (cyan) centred in a small roundabout"),
    "cyan": ("Garage", "House / garage-door glyph (cyan)"),
    "lime": ("Race", "Checkered race flag (lime) on the boulevard"),
}


def px(full, x, y):
    i = (y * S + x) * 4
    return full[i], full[i + 1], full[i + 2], full[i + 3]


def saturated(full, x, y):
    r, g, b, a = px(full, x, y)
    return a > 40 and max(r, g, b) - min(r, g, b) > 12


def clusters(full):
    sat = set()
    for y in range(S):
        row = y * S * 4
        for x in range(S):
            i = row + x * 4
            r, g, b, a = full[i], full[i + 1], full[i + 2], full[i + 3]
            if a > 40 and max(r, g, b) - min(r, g, b) > 12:
                sat.add((x, y))
    seen, out = set(), []
    for p in sat:
        if p in seen:
            continue
        stack, comp = [p], []
        seen.add(p)
        while stack:
            q = stack.pop()
            comp.append(q)
            for dx in range(-3, 4):
                for dy in range(-3, 4):
                    n = (q[0] + dx, q[1] + dy)
                    if n in sat and n not in seen:
                        seen.add(n)
                        stack.append(n)
        if len(comp) >= MIN_CLUSTER:
            out.append(comp)
    return out


def icon_mask(full, comp):
    xs = [p[0] for p in comp]
    ys = [p[1] for p in comp]
    x0, y0, x1, y1 = min(xs) - 4, min(ys) - 4, max(xs) + 4, max(ys) + 4
    core = set(comp)
    # dark outline pixels (below the block grey) adjacent to the glyph
    grow = set(core)
    for _ in range(3):
        added = set()
        for x, y in grow:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in grow or not (x0 <= n[0] <= x1 and y0 <= n[1] <= y1):
                        continue
                    r, g, b, a = px(full, *n)
                    if saturated(full, *n) or (a > 40 and max(r, g, b) < 46):
                        added.add(n)
        if not added:
            break
        grow |= added
    # fill enclosed holes: flood non-mask pixels from the ROI border
    outside = set()
    stack = [(x, y) for x in range(x0, x1 + 1) for y in (y0, y1)] + [(x, y) for y in range(y0, y1 + 1) for x in (x0, x1)]
    stack = [p for p in stack if p not in grow]
    outside.update(stack)
    while stack:
        x, y = stack.pop()
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if x0 <= n[0] <= x1 and y0 <= n[1] <= y1 and n not in grow and n not in outside:
                outside.add(n)
                stack.append(n)
    mask = {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1) if (x, y) not in outside}
    # 1 px dilation for anti-aliased fringe
    return {(x + dx, y + dy) for x, y in mask for dx in (-1, 0, 1) for dy in (-1, 0, 1)}


def classify(full, comp):
    r = sum(px(full, *p)[0] for p in comp) / len(comp)
    g = sum(px(full, *p)[1] for p in comp) / len(comp)
    b = sum(px(full, *p)[2] for p in comp) / len(comp)
    colour = "lime" if r > 90 and b < 60 else "cyan"
    return colour, (round(r), round(g), round(b))


def in_ring(full, cx, cy, radius_min=10, radius_max=24):
    """True if a road ring surrounds (cx, cy): every ray meets road grey within the radius band."""
    hits = 0
    for k in range(16):
        a = 2 * math.pi * k / 16
        for rad in range(radius_min, radius_max):
            x, y = int(round(cx + rad * math.cos(a))), int(round(cy + rad * math.sin(a)))
            if px(full, x, y)[0] >= 110 and not saturated(full, x, y):
                hits += 1
                break
    return hits >= 15


def inpaint(full, mask):
    out = bytearray(full)
    dirs = [(math.cos(math.pi * k / ANGLES), math.sin(math.pi * k / ANGLES)) for k in range(ANGLES)]

    def march(x, y, dx, dy):
        t = 0.5
        while t <= MAX_RAY:
            qx, qy = int(round(x + dx * t)), int(round(y + dy * t))
            if (qx, qy) not in mask:
                return (qx, qy), t
            t += 0.5
        return None, None

    tangent_cache = {}

    def road_tangent(q):
        """Unit road direction at known pixel q from the grey structure tensor (known pixels only)."""
        if q in tangent_cache:
            return tangent_cache[q]
        jxx = jxy = jyy = 0.0
        for yy in range(q[1] - 4, q[1] + 5):
            for xx in range(q[0] - 4, q[0] + 5):
                nbrs = ((xx - 1, yy), (xx + 1, yy), (xx, yy - 1), (xx, yy + 1))
                if (xx, yy) in mask or any(n in mask for n in nbrs):
                    continue
                gx = (px(full, xx + 1, yy)[0] - px(full, xx - 1, yy)[0]) / 2.0
                gy = (px(full, xx, yy + 1)[0] - px(full, xx, yy - 1)[0]) / 2.0
                jxx += gx * gx
                jxy += gx * gy
                jyy += gy * gy
        # dominant gradient angle; the road runs perpendicular to it
        theta = 0.5 * math.atan2(2 * jxy, jxx - jyy)
        tangent_cache[q] = (-math.sin(theta), math.cos(theta), jxx + jyy)
        return tangent_cache[q]

    def runs_along(q, dx, dy, value):
        good = 0
        for s in range(1, ALONG + 1):
            v = px(full, int(round(q[0] + dx * s)), int(round(q[1] + dy * s)))[0]
            if v >= 100 and abs(v - value) <= 40:
                good += 1
        if good < ALONG - 1:
            return False
        tx, ty, energy = road_tangent(q)
        # a road straddling the ray with no edge in view (wide road) keeps the run test only
        return energy < 1.0 or abs(tx * dx + ty * dy) >= math.cos(math.radians(TANGENT_DEG))

    for (x, y) in mask:
        best = None
        for dx, dy in dirs:
            qa, ta = march(x, y, dx, dy)
            qb, tb = march(x, y, -dx, -dy)
            if qa is None or qb is None:
                continue
            va, vb = px(full, *qa), px(full, *qb)
            diff = max(abs(va[i] - vb[i]) for i in range(4))
            span = ta + tb
            if diff <= CONSISTENT:
                road = diff <= ROAD_MATCH and va[0] >= 100 and vb[0] >= 100 and runs_along(qa, dx, dy, va[0]) and runs_along(qb, -dx, -dy, vb[0])
                if road:
                    key = (0, span)
                elif max(va[0], vb[0]) < 70:
                    key = (1, span)  # plain block / background on both sides
                elif max(va[0], vb[0]) < 100 or span <= SHORT_ROAD_GAP:
                    key = (1.5, span)  # anti-aliased road edge, or a tiny gap inside one road
                else:
                    key = (2, 200 + span)  # road chord that is not a straight continuation
            else:
                key = (2, diff * 4 + span)
            if best is None or key < best[0]:
                wa = tb / span
                best = (key, [int(round(va[i] * wa + vb[i] * (1 - wa))) for i in range(4)])
        i = (y * S + x) * 4
        out[i:i + 4] = bytes(best[1])
    return out


def save_crop(full, box, zoom, path, bg=(20, 20, 24)):
    w, h, d = common.crop(full, *box, zoom=zoom, bg=bg)
    write_png(str(path), w, h, d)


def side_by_side(a, b, box, zoom, path):
    wa, ha, da = common.crop(a, *box, zoom=zoom)
    _, _, db = common.crop(b, *box, zoom=zoom)
    gap = 8
    w = wa * 2 + gap
    out = bytearray(w * ha * 4)
    for y in range(ha):
        for x in range(w):
            o = (y * w + x) * 4
            if x < wa:
                out[o:o + 4] = da[(y * wa + x) * 4:(y * wa + x) * 4 + 4]
            elif x >= wa + gap:
                xx = x - wa - gap
                out[o:o + 4] = db[(y * wa + xx) * 4:(y * wa + xx) * 4 + 4]
            else:
                out[o:o + 4] = bytes((244, 46, 151, 255))
    write_png(str(path), w, ha, out)


def main():
    full = common.load_full()
    comps = clusters(full)
    (HERE / "crops").mkdir(exist_ok=True)
    (HERE / "clean").mkdir(exist_ok=True)
    pois, all_mask = [], set()
    for comp in sorted(comps, key=lambda c: (min(p[1] for p in c), min(p[0] for p in c))):
        mask = icon_mask(full, comp)
        all_mask |= mask
        xs = [p[0] for p in mask]
        ys = [p[1] for p in mask]
        bbox = [min(xs), min(ys), max(xs), max(ys)]
        cx, cy = (bbox[0] + bbox[2]) / 2.0, (bbox[1] + bbox[3]) / 2.0
        colour, mean = classify(full, comp)
        ring = colour == "cyan" and in_ring(full, cx, cy)
        key, meaning = MEANINGS["cyan_ring" if ring else colour]
        wx, wz = common.to_world(cx, cy)
        tile = ("Top" if cy < 1024 else "Bottom") + ("Left" if cx < 1024 else "Right")
        pois.append({
            "key": key, "meaning": meaning, "glyphColour": "#%02X%02X%02X" % mean,
            "pixelBBox": bbox, "pixelCentre": [cx, cy], "tile": "MapTile" + tile,
            "world": {"X": round(wx, 1), "Z": round(wz, 1)},
            "glyphPixels": len(comp), "maskPixels": len(mask),
            "sitsInRoundabout": ring,
        })
    cleaned = inpaint(full, all_mask)
    # byte-identity guard outside the masks
    for y in range(S):
        for x in range(S):
            if (x, y) not in all_mask:
                i = (y * S + x) * 4
                assert cleaned[i:i + 4] == full[i:i + 4]
    for poi in pois:
        x0, y0, x1, y1 = poi["pixelBBox"]
        pad = 6
        save_crop(full, (x0 - pad, y0 - pad, x1 + pad + 1, y1 + pad + 1), 4, HERE / "crops" / ("%s_4x.png" % poi["key"]))
        pad = 18
        side_by_side(full, cleaned, (x0 - pad, y0 - pad, x1 + pad + 1, y1 + pad + 1), 4,
                     HERE / "crops" / ("%s_before_after_4x.png" % poi["key"]))
    side_by_side(full, cleaned, (1085, 1050, 1200, 1210), 3, HERE / "crops" / "city_before_after_3x.png")
    for name in common.TILES:
        write_png(str(HERE / "clean" / ("MapTile%s.png" % name)), 1024, 1024, common.split_tile(cleaned, name))
    (HERE / "detected_pois.json").write_text(json.dumps(pois, indent=2) + "\n", encoding="utf-8")
    for poi in pois:
        print(poi["key"], poi["pixelBBox"], poi["pixelCentre"], poi["world"], poi["maskPixels"])


if __name__ == "__main__":
    main()
