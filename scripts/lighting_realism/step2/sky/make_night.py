"""Space Racers night sky: indigo zenith, neon-violet horizon glow, a faint galaxy band and baked stars.
Deterministic. Writes six 1024 px faces to out/night_<Face>.png."""
import numpy as np
from PIL import Image
from pathlib import Path
from cube import FACES, directions
SIZE = 1024
rng = np.random.default_rng(2098)
LATTICE = rng.random((64, 64, 64))
def value_noise(p):
    i = np.floor(p).astype(np.int64); f = p - i; f = f * f * (3 - 2 * f)
    def at(dx, dy, dz): return LATTICE[(i[..., 0] + dx) % 64, (i[..., 1] + dy) % 64, (i[..., 2] + dz) % 64]
    x0 = at(0, 0, 0) * (1 - f[..., 0]) + at(1, 0, 0) * f[..., 0]; x1 = at(0, 1, 0) * (1 - f[..., 0]) + at(1, 1, 0) * f[..., 0]
    x2 = at(0, 0, 1) * (1 - f[..., 0]) + at(1, 0, 1) * f[..., 0]; x3 = at(0, 1, 1) * (1 - f[..., 0]) + at(1, 1, 1) * f[..., 0]
    y0 = x0 * (1 - f[..., 1]) + x1 * f[..., 1]; y1 = x2 * (1 - f[..., 1]) + x3 * f[..., 1]
    return y0 * (1 - f[..., 2]) + y1 * f[..., 2]
def fbm(d, scale, octaves=5):
    total = 0; amp = 0.5; norm = 0
    for o in range(octaves):
        total = total + amp * value_noise(d * scale * (2 ** o) + 17.3 * o); norm += amp; amp *= 0.5
    return total / norm
BAND_N = np.array([0.55, 0.45, -0.70]); BAND_N /= np.linalg.norm(BAND_N)  # galaxy band: a tilted great circle
def band_weight(d, width): return np.exp(-((d @ BAND_N) / width) ** 2)
# stars: uniform on the sphere, plus extra dust inside the band
def sphere(n):
    v = rng.normal(size=(n, 3)); return v / np.linalg.norm(v, axis=1, keepdims=True)
stars = sphere(5200); mag = rng.pareto(2.2, len(stars)) * 0.28 + 0.13
dust = sphere(60000); dust = dust[rng.random(len(dust)) < band_weight(dust, 0.16)]; dust_mag = rng.random(len(dust)) * 0.10 + 0.03
star_dir = np.vstack([stars, dust]); star_mag = np.concatenate([np.clip(mag, 0, 1.6), dust_mag])
temp = rng.random(len(star_dir))
star_col = np.stack([0.80 + 0.20 * temp, 0.84 + 0.10 * np.abs(temp - 0.5), 1.0 - 0.25 * temp], axis=1)  # blue-white to warm
keep = star_dir[:, 1] > -0.05; star_dir, star_mag, star_col = star_dir[keep], star_mag[keep], star_col[keep]
def render(face):
    d = directions(face, SIZE); y = d[..., 1]; elev = np.degrees(np.arcsin(np.clip(y, -1, 1))); az = np.arctan2(d[..., 0], -d[..., 2])
    t = np.clip(elev / 90, 0, 1)
    zenith = np.array([0.006, 0.008, 0.028]); upper = np.array([0.016, 0.019, 0.066])
    img = upper + (zenith - upper) * (t[..., None] ** 0.7)
    # horizon glow in the city's neon colours, varying slowly round the compass
    glow = np.exp(-np.clip(elev, 0, None) / 13.0)
    magenta = np.array([0.30, 0.07, 0.34]); blue = np.array([0.06, 0.14, 0.42]); rose = np.array([0.36, 0.10, 0.22])
    w1 = 0.5 + 0.5 * np.cos(az - 0.6); w2 = 0.5 + 0.5 * np.cos(az - 2.9); w3 = 0.5 + 0.5 * np.cos(2 * az + 1.1)
    tint = (magenta * w1[..., None] + blue * w2[..., None] + rose * (0.35 * w3[..., None])) / (w1 + w2 + 0.35 * w3 + 1e-6)[..., None]
    img = img + tint * (glow * (0.55 + 0.25 * fbm(d, 2.0, 3)))[..., None]
    # galaxy band: soft violet-teal cloud with dark lanes
    cloud = fbm(d, 3.0); lanes = fbm(d, 7.0, 4)
    bw = band_weight(d, 0.20) * np.clip(t * 3, 0, 1)
    galaxy = bw * np.clip(cloud * 1.7 - 0.45, 0, 1) * (0.45 + 0.55 * np.clip(lanes * 2 - 0.5, 0, 1))
    gcol = np.array([0.20, 0.13, 0.36]) * (1 - cloud[..., None]) + np.array([0.10, 0.22, 0.34]) * cloud[..., None]
    img = img + gcol * galaxy[..., None] * 0.9
    # wide faint nebula wash so the upper sky is not flat
    img = img + np.array([0.03, 0.012, 0.055]) * (np.clip(fbm(d, 1.3, 4) - 0.45, 0, 1) * np.clip(t * 2, 0, 1))[..., None]
    # below the horizon: fade to near black (hidden by the world; also keeps Dn featureless)
    below = np.clip(-elev / 6.0, 0, 1)[..., None]
    img = img * (1 - below) + np.array([0.010, 0.010, 0.022]) * below
    # stars
    look, right, top = (np.array(v, dtype=np.float64) for v in FACES[face])
    proj = star_dir @ look; vis = proj > 1e-3
    u = (star_dir[vis] @ right) / proj[vis]; v = -(star_dir[vis] @ top) / proj[vis]
    inside = (np.abs(u) < 1) & (np.abs(v) < 1)
    px = (u[inside] + 1) / 2 * SIZE - 0.5; py = (v[inside] + 1) / 2 * SIZE - 0.5
    m = star_mag[vis][inside]; c = star_col[vis][inside]
    fade = np.clip((star_dir[vis][inside][:, 1] * 90 - 2) / 14, 0, 1)  # stars sink into the horizon glow
    for x, yy, mm, cc, ff in zip(px, py, m, c, fade):
        if ff <= 0: continue
        r = 1 if mm < 0.5 else 2
        x0, y0 = int(round(x)), int(round(yy))
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                xi, yi = x0 + dx, y0 + dy
                if 0 <= xi < SIZE and 0 <= yi < SIZE:
                    w = np.exp(-((xi - x) ** 2 + (yi - yy) ** 2) / (0.45 if mm < 0.5 else 0.8))
                    img[yi, xi] += cc * (mm * ff * w)
    return (np.clip(img, 0, 1) ** (1 / 2.2) * 255 + 0.5).astype(np.uint8)
out = Path(__file__).resolve().parent / 'out'; out.mkdir(exist_ok=True)
faces = {}
for face in FACES:
    faces[face] = render(face); Image.fromarray(faces[face]).save(out / f'night_{face}.png', optimize=True)
# contact sheet for review: Rt(-X) Ft(-Z) Lf(+X) Bk(+Z) in compass order, with Up above Ft
sheet = np.zeros((SIZE * 2, SIZE * 4, 3), np.uint8)
for i, f in enumerate(['Rt', 'Ft', 'Lf', 'Bk']): sheet[SIZE:, i * SIZE:(i + 1) * SIZE] = faces[f]
sheet[:SIZE, SIZE:2 * SIZE] = faces['Up']
Image.fromarray(sheet).resize((SIZE * 4 // 3, SIZE * 2 // 3), Image.LANCZOS).save(out / 'night_sheet.jpg', quality=88)
print({f: (out / f'night_{f}.png').stat().st_size for f in FACES})
