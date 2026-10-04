"""Metallic flake car paint: a tileable greyscale PBR texture set for a Roblox MaterialVariant.

    py -3 scripts/exotic_category/mesh/paint/make_flake_paint.py

Writes four 1024 x 1024 PNGs next to this file: flake_color.png, flake_normal.png, flake_roughness.png and
flake_metalness.png. The colour map is near-white grey, so the part Color tints it to any paint colour.
The look is a smooth clear coat over small flakes: each flake is a cell a few pixels wide with its own
tilt (normal map), a little extra brightness and more metalness than the base coat between flakes.
Everything is built on a wrapping cell grid, so the maps tile without seams.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024
CELLS = 256             # flakes per side: one cell is 4 pixels
COVER = 0.4             # share of cells that hold a flake
TILT = 0.12             # largest flake tilt, as a slope (about 7 degrees)
BASE_COLOR, FLAKE_COLOR = 0.84, 0.06        # base coat brightness; the most a flake adds
BASE_ROUGH, FLAKE_ROUGH = 0.07, 0.03       # mirror-like coat; flakes a touch glossier
BASE_METAL, FLAKE_METAL = 0.65, 0.9
SEED = 2098


def up(cells):
    """Cell grid to pixels (nearest), softened slightly with a wrapping blur so flake edges do not alias."""
    k = SIZE // CELLS
    img = np.kron(cells, np.ones((k, k)))
    soft = img * 0.5
    for dx, dy, w in ((1, 0, 0.1), (-1, 0, 0.1), (0, 1, 0.1), (0, -1, 0.1), (1, 1, 0.025), (1, -1, 0.025), (-1, 1, 0.025), (-1, -1, 0.025)):
        soft = soft + w * np.roll(np.roll(img, dx, axis=1), dy, axis=0)
    return soft


def save(name, arr):
    data = (np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(data, "RGB" if data.ndim == 3 else "L").convert("RGB").save(os.path.join(HERE, name), optimize=True)


def main():
    rng = np.random.default_rng(SEED)
    flake = (rng.random((CELLS, CELLS)) < COVER).astype(np.float64)
    strength = flake * rng.random((CELLS, CELLS))            # how strongly each flake shows
    angle = rng.random((CELLS, CELLS)) * 2 * np.pi
    slope = flake * rng.random((CELLS, CELLS)) * TILT
    f, s = up(flake), up(strength)
    nx, ny = up(0.5 + slope * np.cos(angle) / 2) * 2 - 1, up(0.5 + slope * np.sin(angle) / 2) * 2 - 1
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    save("flake_color.png", BASE_COLOR + s * FLAKE_COLOR)
    save("flake_normal.png", np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1))
    save("flake_roughness.png", BASE_ROUGH + f * (FLAKE_ROUGH - BASE_ROUGH))
    save("flake_metalness.png", BASE_METAL + f * (FLAKE_METAL - BASE_METAL))
    print("wrote flake_color, flake_normal, flake_roughness, flake_metalness (%d px, %d flakes per side)" % (SIZE, CELLS))


if __name__ == "__main__":
    main()
