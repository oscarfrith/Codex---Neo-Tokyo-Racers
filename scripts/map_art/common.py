"""Shared helpers: stitched 2048x2048 minimap and pixel->world mapping."""
import pathlib
from png_rgba import read_png, write_png

HERE = pathlib.Path(__file__).parent
TILES = ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]
OFFSETS = {"TopLeft": (0, 0), "TopRight": (1024, 0), "BottomLeft": (0, 1024), "BottomRight": (1024, 1024)}
SIZE = 2048
STUDS_PER_PIXEL = 2850.0 / 207.0  # MapCalibrationStuds / MapCalibrationPixels


def to_world(px, py, size=SIZE):
    """Same as scripts/route_guide/build_road_graph.py to_world: pixel -> (world X, world Z)."""
    half = size / 2.0
    mx = (px + 0.5 - half) * STUDS_PER_PIXEL
    mz = (py + 0.5 - half) * STUDS_PER_PIXEL
    return mz, -mx


def load_full(tile_dir=HERE / "tiles"):
    full = bytearray(SIZE * SIZE * 4)
    for name in TILES:
        w, h, d = read_png(str(tile_dir / ("MapTile%s.png" % name)))
        ox, oy = OFFSETS[name]
        for y in range(h):
            start = ((oy + y) * SIZE + ox) * 4
            full[start:start + w * 4] = d[y * w * 4:(y + 1) * w * 4]
    return full


def split_tile(full, name):
    ox, oy = OFFSETS[name]
    out = bytearray(1024 * 1024 * 4)
    for y in range(1024):
        s = ((oy + y) * SIZE + ox) * 4
        out[y * 4096:(y + 1) * 4096] = full[s:s + 4096]
    return out


def crop(full, x0, y0, x1, y1, zoom=1, bg=(20, 20, 24)):
    """Crop [x0,x1)x[y0,y1) composited over bg, nearest-neighbour zoom. Returns (w,h,rgba)."""
    w, h = (x1 - x0) * zoom, (y1 - y0) * zoom
    out = bytearray(w * h * 4)
    for y in range(h):
        sy = y0 + y // zoom
        for x in range(w):
            sx = x0 + x // zoom
            o = (y * w + x) * 4
            if 0 <= sx < SIZE and 0 <= sy < SIZE:
                i = (sy * SIZE + sx) * 4
                r, g, b, a = full[i:i + 4]
            else:
                r = g = b = a = 0
            out[o] = (r * a + bg[0] * (255 - a)) // 255
            out[o + 1] = (g * a + bg[1] * (255 - a)) // 255
            out[o + 2] = (b * a + bg[2] * (255 - a)) // 255
            out[o + 3] = 255
    return w, h, out
