"""Shared helpers for the South Grid tileable texture generator (numpy + Pillow).
All shapes and filters are periodic, so every map tiles seamlessly."""
import pathlib
import numpy as np
from PIL import Image

N = 1024
OUT = pathlib.Path(__file__).parent / "out"
Y, X = np.mgrid[0:N, 0:N].astype(np.float32) + 0.5


def pd(a, c):
    """Periodic signed distance from coordinate c."""
    return (a - c + N / 2) % N - N / 2


def box_sdf(cx, cy, w, h, r=0.0):
    dx = np.abs(pd(X, cx)) - w / 2 + r
    dy = np.abs(pd(Y, cy)) - h / 2 + r
    return np.hypot(np.maximum(dx, 0), np.maximum(dy, 0)) + np.minimum(np.maximum(dx, dy), 0) - r


def rect_sdf(x0, y0, x1, y1, r=0.0):
    return box_sdf((x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0, r)


def circ_sdf(cx, cy, rad):
    return np.hypot(pd(X, cx), pd(Y, cy)) - rad


def cov(sdf, soft=1.0):
    """Antialiased coverage from a signed distance."""
    return np.clip(0.5 - sdf / soft, 0, 1).astype(np.float32)


def bevel(sdf, width):
    """0 outside, ramps to 1 over `width` pixels inside."""
    return np.clip(-sdf / width, 0, 1).astype(np.float32)


def rect(x0, y0, x1, y1, r=0.0, soft=1.0):
    return cov(rect_sdf(x0, y0, x1, y1, r), soft)


def lerp(a, b, t):
    t = np.asarray(t, dtype=np.float32)
    if t.ndim == 2 and (np.ndim(a) in (1, 3) or np.ndim(b) in (1, 3)):
        t = t[..., None]
    return a + (b - a) * t


def col(*rgb):
    return np.array(rgb, dtype=np.float32) / 255.0


_K = None


def _kgrid(ax=1.0, ay=1.0):
    f = np.fft.fftfreq(N) * N
    return np.hypot(f[None, :] * ax, f[:, None] * ay)


def fbm(seed, beta=2.0, ax=1.0, ay=1.0, kmin=1.0, kmax=None):
    """Periodic 1/f^beta noise normalised to 0..1. ax/ay stretch (ay>1 => vertical streaks... use ax>1)."""
    rng = np.random.default_rng(seed)
    w = rng.standard_normal((N, N))
    k = _kgrid(ax, ay)
    amp = np.zeros_like(k)
    m = k >= kmin
    amp[m] = k[m] ** (-beta / 2)
    if kmax:
        amp[k > kmax] = 0
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * amp))
    out -= out.min()
    out /= out.max() + 1e-9
    return out.astype(np.float32)


def blur(img, sigma):
    """Periodic gaussian blur (2D or HxWxC)."""
    f = np.fft.fftfreq(N)
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (f[None, :] ** 2 + f[:, None] ** 2))
    if img.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(img) * g)).astype(np.float32)
    return np.stack([blur(img[..., i], sigma) for i in range(img.shape[2])], -1)


def normal_from_height(H, strength):
    """OpenGL / Roblox convention: +G = up (towards smaller image row)."""
    dx = (np.roll(H, -1, 1) - np.roll(H, 1, 1)) * 0.5
    dr = (np.roll(H, -1, 0) - np.roll(H, 1, 0)) * 0.5
    nx, ny, nz = -dx * strength, dr * strength, np.ones_like(H)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln, ny / ln, nz / ln], -1)


def bake_light(C, nrm, H, amt=0.18, ao=0.35, ao_sigma=6):
    """Painterly baked shading: soft top-left key light + cavity AO."""
    L = np.array([-0.35, 0.6, 0.72], dtype=np.float32)
    L /= np.linalg.norm(L)
    d = (nrm @ L) - L[2]  # 0 on flat
    cav = H - blur(H, ao_sigma)
    shade = 1 + amt * d * 3 + ao * np.clip(cav, -1, 0.2)
    return np.clip(C * shade[..., None], 0, 1)


def save(name, arr):
    OUT.mkdir(parents=True, exist_ok=True)
    a = np.clip(arr, 0, 1)
    a = (a * 255 + 0.5).astype(np.uint8)
    Image.fromarray(a, "L" if a.ndim == 2 else "RGB").save(OUT / name, optimize=True)


def save_set(slug, C, H, strength, R, M=None):
    nrm = normal_from_height(H, strength)
    save(f"{slug}_color.png", C)
    save(f"{slug}_normal.png", nrm * 0.5 + 0.5)
    save(f"{slug}_roughness.png", R)
    if M is not None:
        save(f"{slug}_metalness.png", M)
    return nrm
