"""Dim moon disc for the night sky template. The night is shown day-for-night, so this is drawn by the engine's sun,
which is far brighter than its moon: the texture is kept dark so the disc reads as a moon instead of blowing out.
Usage: make_moon.py [peak brightness 0-1]"""
import sys
import numpy as np
from PIL import Image
from pathlib import Path
SIZE = 256
peak = float(sys.argv[1]) if len(sys.argv) > 1 else 0.3
rng = np.random.default_rng(7)
t = (np.arange(SIZE) + 0.5) / SIZE * 2 - 1
x, y = np.meshgrid(t, t)
r = np.sqrt(x * x + y * y) / 0.62
disc = np.clip((1 - r) / 0.04, 0, 1)
# soft maria: a few dark blotches
shade = np.ones_like(r)
for _ in range(9):
    cx, cy, rad = rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), rng.uniform(0.08, 0.2)
    shade -= 0.16 * np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (rad * rad))
limb = np.clip(1 - 0.35 * r ** 3, 0, 1)
halo = 0.10 * np.exp(-np.clip(r - 1, 0, None) / 0.18) * (r >= 1)
lum = disc * np.clip(shade, 0.45, 1) * limb + halo
img = lum[..., None] * np.array([1.0, 0.93, 0.82]) * peak
out = Path(__file__).resolve().parent / 'out'; out.mkdir(exist_ok=True)
name = out / ('moon_%03d.png' % round(peak * 100))
Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).save(name)
print(name.name)
