"""Build the 4096x4096 (4x4 tiles of 1024) map from the 2048 live minimap.

Input : tiles/MapTile{TopLeft,TopRight,BottomLeft}.png + clean/MapTileBottomRight.png
Output: hires/work/*.png (candidate full images + comparison crops),
        hires/R{row}C{col}.png (chosen candidate, 16 tiles), hires/manifest.json

Candidates (see HIRES_OPTIONS.md; compared ones in COMPARE):
  A  premultiplied Lanczos 2x (baseline)
  B  A + unsharp mask
  C/D class re-render: per-class coverage masks (from decompose), bicubic 2x, re-threshold
  E..N level-set re-render (LEVELSET table): bicubic 2x of the cleaned grey, optional Gaussian
       smoothing, then a piecewise re-threshold between adjacent palette levels; alpha from the
       class solid mask with its own smoothing
  M  CHOSEN: grey level-set unsmoothed (slope 2), alpha smoothed (sigma 2.6 at 4096, slope 4.5)

Class model: the map is pure grey. Classes are background (transparent), block (51) and three
road tiers (128 streets, 153 secondary/coast roads, 179 highways). Each pixel is decomposed
into coverages (solid S, road tier R_k) using its grey level and the pure classes nearby;
partial-alpha pixels (whose rgb is contaminated by the light matte of the transparent area)
take their class split from their opaque neighbours. Masks are upscaled with bicubic (centre-
aligned, so 2048 pixel x maps exactly to 4096 pixels 2x..2x+1), re-thresholded with an
anti-aliasing ramp, and recoloured with the palette. Fully transparent pixels get the colour
of the nearest drawn class (no light fringes under bilinear sampling).

Requires Pillow (py -3). Run: py -3 hires_map.py [--only D]
"""
import json
import pathlib
import sys

from PIL import Image, ImageFilter, ImageMath

HERE = pathlib.Path(__file__).parent
OUT = HERE / "hires"
WORK = OUT / "work"
SRC_SIZE = 2048
DST_SIZE = 4096
TILE = 1024
BLOCK = 51
ROADS = (128, 153, 179)
PURE_TOL = 2

CROPS = {  # name: (centre x, centre y in 2048 px, half-size in src px, zoom vs 2048)
    "roundabout": (1150, 1085, 36, 4),
    "diagonal": (1120, 960, 36, 4),
    "coast": (1470, 1203, 16, 8),
    "hub": (1024, 1024, 24, 6),
    "islands": (330, 110, 48, 4),
    "junction": (1189, 1030, 12, 8),
}
CHOSEN = "M"
COMPARE = ["A", "B", "C", "E", "J", "M"]
LABELS = {"A": "A lanczos", "B": "B lanczos+unsharp", "C": "C class masks", "D": "D class masks smoothed",
          "E": "E level-set", "F": "F level-set smoothed", "G": "G level-set smoother",
          "H": "H level-set flat", "J": "J level-set flat, steep", "K": "K level-set flat",
          "M": "M level-set + smooth coast (CHOSEN)", "N": "N level-set light smooth"}


def load_source():
    offs = {"TopLeft": (0, 0), "TopRight": (1024, 0), "BottomLeft": (0, 1024), "BottomRight": (1024, 1024)}
    full = Image.new("RGBA", (SRC_SIZE, SRC_SIZE))
    for name, o in offs.items():
        folder = "clean" if name == "BottomRight" else "tiles"
        full.paste(Image.open(HERE / folder / ("MapTile%s.png" % name)).convert("RGBA"), o)
    return full


# ---------------------------------------------------------------- class decomposition


def decompose(src):
    """Return F-mode images S (solid coverage) and R[k] (road tier coverages), values 0..1."""
    n = SRC_SIZE
    px = src.load()
    grey = bytearray(n * n)
    alpha = bytearray(n * n)
    for y in range(n):
        for x in range(n):
            r, g, b, a = px[x, y]
            grey[y * n + x] = r
            alpha[y * n + x] = a
    pure = {}
    for cls in (BLOCK,) + ROADS:
        m = bytearray(n * n)
        for i in range(n * n):
            if alpha[i] == 255 and abs(grey[i] - cls) <= PURE_TOL:
                m[i] = 255
        pure[cls] = Image.frombytes("L", (n, n), bytes(m))
    near = {cls: [pure[cls].filter(ImageFilter.MaxFilter(s)).tobytes() for s in (3, 5, 7, 11)] for cls in pure}

    S = [0.0] * (n * n)
    R = {k: [0.0] * (n * n) for k in ROADS}
    for i in range(n * n):
        a = alpha[i]
        if a == 0:
            continue
        S[i] = a / 255.0
        g = grey[i]
        if a == 255 and abs(g - BLOCK) <= PURE_TOL:
            continue
        # classes present at the smallest radius
        cands = []
        for level in range(4):
            cands = [k for k in ROADS if near[k][level][i]]
            if cands:
                break
        if not cands:
            continue
        if a == 255:
            if len(cands) == 1 or g <= min(cands):
                k = cands[0] if len(cands) == 1 else min(cands)
                if g < min(cands) and len(cands) > 1:
                    k = min(cands)
                c = (g - BLOCK) / float(k - BLOCK)
                R[k][i] = max(0.0, min(1.0, c))
            elif g >= max(cands):
                R[max(cands)][i] = 1.0
            else:
                lo = max(k for k in cands if k <= g)
                hi = min(k for k in cands if k > g)
                t = (g - lo) / float(hi - lo)
                R[hi][i] = t
                R[lo][i] = 1.0 - t
        else:
            # partial alpha: rgb unreliable; split by opaque pure neighbours in a 5x5 window
            x, y = i % n, i // n
            counts = {}
            for rad in (2, 3, 5):
                counts = {}
                for yy in range(max(0, y - rad), min(n, y + rad + 1)):
                    for xx in range(max(0, x - rad), min(n, x + rad + 1)):
                        j = yy * n + xx
                        if alpha[j] == 255:
                            for cls in (BLOCK,) + ROADS:
                                if abs(grey[j] - cls) <= PURE_TOL:
                                    counts[cls] = counts.get(cls, 0) + 1
                if counts:
                    break
            tot = sum(counts.values())
            if not tot:
                # isolated faint pixel: guess by rgb (road if light)
                k = cands[0]
                R[k][i] = S[i] if g > (BLOCK + k) / 2 else 0.0
                continue
            for k in ROADS:
                if counts.get(k):
                    R[k][i] = S[i] * counts[k] / tot
    def to_img(vals):
        im = Image.new("F", (n, n))
        im.putdata(vals)
        return im
    return to_img(S), {k: to_img(v) for k, v in R.items()}


# ---------------------------------------------------------------- mask upscaling and render


def upscale_mask(m, sigma=0.0, slope=2.0):
    """Bicubic 2x (centre-aligned), optional Gaussian smoothing, then an AA ramp around 0.5."""
    up = m.resize((DST_SIZE, DST_SIZE), Image.BICUBIC)
    if sigma > 0:
        l8 = up.point(lambda v: v * 255.0).convert("L")
        l8 = l8.filter(ImageFilter.GaussianBlur(sigma))
        up = l8.convert("F").point(lambda v: v / 255.0)
    # ramp: clamp((v - 0.5) * slope + 0.5); convert("L") clamps to 0..255
    ramp = up.point(lambda v: v * (255.0 * slope) + (0.5 - 0.5 * slope) * 255.0).convert("L")
    return ramp


def compose(S8, R8):
    """S8, R8[k]: L-mode 0..255 masks at 4096. Returns RGBA image."""
    S = S8.convert("F")
    col = Image.new("F", (DST_SIZE, DST_SIZE), float(BLOCK))
    for k in ROADS:  # painter order: streets, secondary, highways on top
        Rk = R8[k].convert("F")
        col = ImageMath.lambda_eval(
            lambda a: a["col"] + (a["k"] - a["col"]) * a["min"](a["Rk"] / a["max"](a["S"], 1.0), 1.0),
            col=col, Rk=Rk, S=S, k=float(k))
    c8 = col.convert("L")
    return Image.merge("RGBA", (c8, c8, c8, S8))


def fill_transparent_colour(img, iters=3):
    """Give alpha-0 pixels the colour of nearby drawn pixels (no light fringe when bilinear-sampled)."""
    r, g, b, a = img.split()
    solid = a.point(lambda v: 255 if v > 0 else 0)
    grown = r
    for _ in range(iters):
        # spread colour outward: weighted 3x3 mean of drawn neighbours (the colour right at the edge)
        pre = ImageMath.lambda_eval(lambda d: d["c"] * d["s"] / 255.0, c=grown.convert("F"), s=solid.convert("F")).convert("L")
        num = pre.filter(ImageFilter.BoxBlur(1))
        den = solid.filter(ImageFilter.BoxBlur(1))
        spread = ImageMath.lambda_eval(lambda d: d["n"] * 255.0 / d["max"](d["w"], 1.0),
                                       n=num.convert("F"), w=den.convert("F")).convert("L")
        grown = Image.composite(grown, spread, solid)
        solid = solid.filter(ImageFilter.MaxFilter(3))
    rest = Image.new("L", img.size, BLOCK)
    grown = Image.composite(grown, rest, solid)
    return Image.merge("RGBA", (grown, grown, grown, a))


def premul_resize(src, filt):
    r, g, b, a = src.split()
    af = a.convert("F")
    pre = [ImageMath.lambda_eval(lambda d: d["c"] * d["a"] / 255.0, c=ch.convert("F"), a=af) for ch in (r, g, b)]
    pre = [p.resize((DST_SIZE, DST_SIZE), filt) for p in pre]
    a2 = af.resize((DST_SIZE, DST_SIZE), filt)
    chans = [ImageMath.lambda_eval(lambda d: d["p"] * 255.0 / d["max"](d["a"], 1.0), p=p, a=a2).convert("L") for p in pre]
    return Image.merge("RGBA", chans + [a2.convert("L")])


LEVELS = (BLOCK,) + ROADS


def level_lut(slope, levels=LEVELS):
    """Piecewise re-threshold: each step between adjacent (present) levels becomes an AA ramp."""
    lut = []
    for v in range(256):
        out = float(levels[0])
        for lo, hi in zip(levels, levels[1:]):
            mid = (lo + hi) / 2.0
            c = (v - mid) / float(hi - lo) * slope + 0.5
            out += (hi - lo) * max(0.0, min(1.0, c))
        lut.append(int(round(out)))
    return lut


def present_levels_map(g2):
    """4096 L image whose value is a bitmask of the palette levels present within 3 src px."""
    idx = None
    for bit, lev in enumerate(LEVELS):
        pure = g2.point(lambda v, lev=lev: 255 if abs(v - lev) <= PURE_TOL else 0)
        pres = pure.filter(ImageFilter.MaxFilter(7)).resize((DST_SIZE, DST_SIZE), Image.NEAREST)
        part = pres.point(lambda v, b=bit: (1 << b) if v else 0)
        idx = part if idx is None else ImageMath.lambda_eval(lambda d: d["a"] | d["b"], a=idx, b=part).convert("L")
    return idx


def clean_grey(src, masks):
    """2048 grey with partial-alpha pixels recoloured from the class split and transparent
    pixels given the colour of the nearest drawn pixels (so bicubic sees no light matte)."""
    S, R = masks
    n = SRC_SIZE
    Sd = list(S.get_flattened_data())
    Rd = {k: list(R[k].get_flattened_data()) for k in ROADS}
    r, g, b, a = src.split()
    gd = bytearray(g.tobytes())
    ad = a.tobytes()
    for i in range(n * n):
        if 0 < ad[i] < 255:
            s = Sd[i]
            tot = sum(Rd[k][i] for k in ROADS)
            col = BLOCK * max(0.0, s - tot) + sum(k * Rd[k][i] for k in ROADS)
            gd[i] = int(round(col / s))
        elif ad[i] == 255 and gd[i] > ROADS[-1]:
            gd[i] = ROADS[-1]
    grey = Image.frombytes("L", (n, n), bytes(gd))
    img = Image.merge("RGBA", (grey, grey, grey, a))
    return fill_transparent_colour(img, 8)


def levelset(src, masks, sigma, slope, a_sigma=None, a_slope=None, present_only=False):
    """Level-set upscale: bicubic 2x of the cleaned grey, optional smoothing, then a piecewise
    re-threshold between adjacent palette levels (51/128/153/179). Alpha from the class S mask."""
    g2 = clean_grey(src, masks).split()[0]
    up = g2.convert("F").resize((DST_SIZE, DST_SIZE), Image.BICUBIC)
    l8 = up.convert("L")
    if sigma > 0:
        l8 = l8.filter(ImageFilter.GaussianBlur(sigma))
    if not present_only:
        grey = l8.point(level_lut(slope))
    else:
        # threshold only between levels actually present nearby: a block->secondary edge ramps
        # 51->153 directly instead of passing through a 128 band (no false outline)
        idx = present_levels_map(g2)
        grey = l8.point(level_lut(slope))
        for mask_bits in range(1, 16):
            levels = [lev for b, lev in enumerate(LEVELS) if mask_bits & (1 << b)]
            if len(levels) == 4:
                continue
            sel = idx.point(lambda v, m=mask_bits: 255 if v == m else 0)
            if not sel.getbbox():
                continue
            layer = l8.point(level_lut(slope, levels)) if len(levels) > 1 else Image.new("L", l8.size, levels[0])
            grey = Image.composite(layer, grey, sel)
    S8 = upscale_mask(masks[0], sigma if a_sigma is None else a_sigma, slope if a_slope is None else a_slope)
    return fill_transparent_colour(Image.merge("RGBA", (grey, grey, grey, S8)))


# name: (grey sigma, grey slope, alpha sigma, alpha slope), sigma in 4096 px
LEVELSET = {"E": (0.0, 2.0, 0.0, 2.0), "F": (1.1, 3.2, 1.1, 3.2), "G": (1.5, 3.6, 2.6, 4.5), "H": (2.0, 4.2, 3.2, 5.0), "J": (1.5, 6.0, 2.6, 4.5), "M": (0.0, 2.0, 2.6, 4.5), "N": (0.8, 2.6, 2.6, 4.5), "K": (1.2, 5.0, 2.6, 4.5),
            "P": (1.5, 3.6, 2.6, 4.5, True), "Q": (2.0, 4.2, 3.2, 5.0, True)}


def candidate(name, src, masks=None):
    if name in LEVELSET:
        return levelset(src, masks, *LEVELSET[name])
    if name == "A":
        return premul_resize(src, Image.LANCZOS)
    if name == "B":
        a = premul_resize(src, Image.LANCZOS)
        r, g, b, al = a.split()
        rgb = Image.merge("RGB", (r, g, b)).filter(ImageFilter.UnsharpMask(radius=1.6, percent=140, threshold=2))
        return Image.merge("RGBA", rgb.split() + (al,))
    S, R = masks
    sigma, slope = {"C": (0.0, 2.0), "D": (1.1, 3.2)}[name]
    S8 = upscale_mask(S, sigma, slope)
    R8 = {k: upscale_mask(R[k], sigma, slope) for k in ROADS}
    return fill_transparent_colour(compose(S8, R8))


# ---------------------------------------------------------------- crops


def display_crop(img, cx, cy, scale_to_src, zoom=4, half=64, bg=(20, 20, 24, 255), resample=Image.BILINEAR):
    """Crop around 2048-space (cx,cy), shown at `zoom` x the 2048 scale, bilinear like Roblox."""
    f = scale_to_src
    box = ((cx - half) * f, (cy - half) * f, (cx + half) * f, (cy + half) * f)
    out = img.resize((half * 2 * zoom, half * 2 * zoom), resample, box=box)
    base = Image.new("RGBA", out.size, bg)
    base.alpha_composite(out)
    return base


def label(img, text):
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, int(d.textlength(text)) + 8, 16), fill=(0, 0, 0, 255))
    d.text((4, 3), text, fill=(255, 255, 255, 255))
    return img


def main():
    """py -3 hires_map.py [--only X] [--work DIR]. Candidate 4096 images go to --work (default
    hires/work, not committed); comparison sheets to hires/compare; chosen tiles to hires/."""
    global WORK
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    if "--work" in sys.argv:
        WORK = pathlib.Path(sys.argv[sys.argv.index("--work") + 1])
    WORK.mkdir(parents=True, exist_ok=True)
    cmp_dir = OUT / "compare"
    cmp_dir.mkdir(parents=True, exist_ok=True)
    src = load_source()
    names = [only] if only else COMPARE
    masks = None
    if any(n not in ("A", "B") for n in names):
        print("decomposing ...")
        masks = decompose(src)
    results = {}
    for name in names:
        print("candidate", name)
        img = candidate(name, src, masks)
        img.save(WORK / ("cand_%s.png" % name))
        results[name] = img
    if only:
        return
    for crop, (cx, cy, half, zoom) in CROPS.items():
        tiles = [label(display_crop(src, cx, cy, 1, zoom, half), "live 2048 (as shown now)")]
        tiles += [label(display_crop(results[n], cx, cy, 2, zoom, half), LABELS[n]) for n in names]
        w = tiles[0].width
        cols = 4 if len(tiles) > 4 else len(tiles)
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * (w + 6) - 6, rows * (w + 6) - 6), (0, 0, 0, 255))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % cols) * (w + 6), (i // cols) * (w + 6)))
        sheet.save(cmp_dir / ("compare_%s_%dx.png" % (crop, zoom)))
    write_tiles(results[CHOSEN], CHOSEN)


def write_tiles(img, chosen):
    files = []
    for row in range(4):
        for col in range(4):
            fn = "R%dC%d.png" % (row + 1, col + 1)
            tile = img.crop((col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE))
            tile.save(OUT / fn, optimize=True)
            files.append({"file": "hires/" + fn, "row": row + 1, "col": col + 1,
                          "fullyTransparent": tile.split()[3].getbbox() is None,
                          "pixelRect4096": [col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE],
                          "pixelRect2048": [col * 512, row * 512, (col + 1) * 512, (row + 1) * 512]})
    manifest = {
        "generatedBy": "scripts/map_art/hires_map.py",
        "candidate": chosen,
        "grid": [4, 4],
        "tileSize": [TILE, TILE],
        "imageSize": [DST_SIZE, DST_SIZE],
        "naming": "R{row}C{col}.png, rows 1..4 top->bottom, cols 1..4 left->right",
        "extent": "Stitched 4096x4096 covers exactly the same world extent as the 2048 minimap (2x2 MapTile*). "
                  "2048 pixel x maps to 4096 pixels 2x..2x+1 (centre-aligned). Studs per 4096 px = "
                  "(2850/207)/2 = 6.884. If the UI keeps working in 2048-space and only swaps the 2x2 "
                  "tile grid for this 4x4 grid inside the same frame, calibration is unchanged.",
        "tiles": files,
        "note": "Row 4 is fully transparent (the source's bottom quarter is empty water). It can be "
                "uploaded as-is or left without an image; either way keep the 4x4 frame so the "
                "extent stays the same.",
        "choiceDoc": "HIRES_OPTIONS.md",
        "source": "tiles/MapTile{TopLeft,TopRight,BottomLeft}.png + clean/MapTileBottomRight.png (no baked icons)",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
