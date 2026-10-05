#!/usr/bin/env python3
"""Procedural VFX textures for the Space Racers Exotic hover cars.

    py -3 scripts/hover_feel/vfx_textures/make_textures.py            # everything
    py -3 scripts/hover_feel/vfx_textures/make_textures.py fire_loop  # named ones only (+ sheet/verify)

Needs numpy only. Output goes to output/vfx_textures/exotic/ (PNG files, manifest.json,
verification.json, contact_sheet.png). Everything is seeded, so reruns are identical.

Authoring convention (Roblox ParticleEmitter / Beam / Trail):
  RGB   = white/grey luminance (the emitter Color tints it)
  alpha = coverage / shape
  every flipbook frame has a fully transparent 4 px margin
  beam textures run along U (image width) and tile in U
"""
import json
import os
import struct
import sys
import time
import zlib

import numpy as np

F32 = np.float32
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "output", "vfx_textures", "exotic")


# ----------------------------------------------------------------------------- PNG io
def write_png(path, rgba):
    """RGBA uint8 (h, w, 4) -> PNG. Tries filter None/Sub/Up for the whole image, keeps the smallest."""
    rgba = np.ascontiguousarray(rgba, dtype=np.uint8)
    h, w, c = rgba.shape
    assert c == 4

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    best = None
    for ft in (0, 1, 2):
        body = rgba.copy()
        if ft == 1:
            body[:, 1:] -= rgba[:, :-1]          # uint8 arithmetic wraps mod 256, as PNG wants
        elif ft == 2:
            body[1:] -= rgba[:-1]
        raw = np.concatenate([np.full((h, 1), ft, np.uint8), body.reshape(h, w * 4)], axis=1).tobytes()
        comp = zlib.compress(raw, 9)
        if best is None or len(comp) < len(best):
            best = comp
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        fh.write(chunk(b"IDAT", best))
        fh.write(chunk(b"IEND", b""))


def read_png(path):
    """Reads back PNGs written by write_png (8-bit RGBA, one filter type for all rows)."""
    with open(path, "rb") as fh:
        data = fh.read()
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        n, tag = struct.unpack(">I4s", data[pos:pos + 8])
        if tag == b"IHDR":
            w, h = struct.unpack(">II", data[pos + 8:pos + 16])
        elif tag == b"IDAT":
            idat += data[pos + 8:pos + 8 + n]
        pos += 12 + n
    raw = np.frombuffer(zlib.decompress(idat), np.uint8).reshape(h, 1 + w * 4)
    ft = int(raw[0, 0])
    assert (raw[:, 0] == ft).all()
    body = raw[:, 1:].reshape(h, w, 4)
    if ft == 1:
        body = np.cumsum(body, axis=1, dtype=np.uint8)
    elif ft == 2:
        body = np.cumsum(body, axis=0, dtype=np.uint8)
    return np.array(body)


# ----------------------------------------------------------------------------- maths helpers
def sstep(a, b, x):
    """smoothstep; works with a > b (falling edge) too."""
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def grid(w, h=None):
    """Pixel-centre coordinates in 0..1 (X across, Y down)."""
    h = w if h is None else h
    x = (np.arange(w, dtype=F32) + 0.5) / w
    y = (np.arange(h, dtype=F32) + 0.5) / h
    return np.meshgrid(x, y)


def gblur(a, sigma):
    """Gaussian blur by FFT with reflect padding (so nothing wraps round the edges)."""
    pad = int(sigma * 3) + 2
    p = np.pad(a, pad, mode="reflect")
    fy = np.fft.fftfreq(p.shape[0])[:, None]
    fx = np.fft.rfftfreq(p.shape[1])[None, :]
    tf = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    out = np.fft.irfft2(np.fft.rfft2(p) * tf, s=p.shape)
    return out[pad:-pad, pad:-pad].astype(F32)


def down(a, k):
    """Box downsample by integer factor k (supersampling resolve)."""
    h, w = a.shape
    return a.reshape(h // k, k, w // k, k).mean(axis=(1, 3))


def window(w, h=None, margin=4, soft=9.0, axes="xy"):
    """Alpha window: exactly 0 for the outer `margin` pixels, then a smooth rise over `soft` px."""
    h = w if h is None else h
    dx = np.minimum(np.arange(w), w - 1 - np.arange(w)).astype(F32)[None, :]
    dy = np.minimum(np.arange(h), h - 1 - np.arange(h)).astype(F32)[:, None]
    big = F32(1e6)
    d = np.minimum(dx if "x" in axes else big, dy if "y" in axes else big) * np.ones((h, w), F32)
    return sstep(margin - 1.0, margin - 1.0 + soft, d)


# ----------------------------------------------------------------------------- noise
_TABLES = {}


def _tables(seed):
    if seed not in _TABLES:
        rng = np.random.default_rng(seed)
        p = rng.permutation(256).astype(np.int32)
        g = rng.normal(size=(256, 3))
        g /= np.linalg.norm(g, axis=1, keepdims=True)
        g = g.astype(F32)
        _TABLES[seed] = (np.concatenate([p, p]), g[:, 0].copy(), g[:, 1].copy(), g[:, 2].copy())
    return _TABLES[seed]


def pnoise3(x, y, z, per, seed):
    """Periodic 3D gradient (Perlin) noise, roughly -1..1.

    `per` = integer lattice period per axis (<= 256). Periodicity is what makes the
    flipbook loops and the U-tiling exact rather than cross-faded.
    """
    P, GX, GY, GZ = _tables(seed)
    x, y, z = np.broadcast_arrays(np.asarray(x, F32), np.asarray(y, F32), np.asarray(z, F32))
    px, py, pz = per
    assert max(per) <= 256
    xi, yi, zi = np.floor(x), np.floor(y), np.floor(z)
    fx, fy, fz = x - xi, y - yi, z - zi
    X0 = xi.astype(np.int64) % px
    Y0 = yi.astype(np.int64) % py
    Z0 = zi.astype(np.int64) % pz
    X1, Y1, Z1 = (X0 + 1) % px, (Y0 + 1) % py, (Z0 + 1) % pz
    u = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
    v = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
    w = fz * fz * fz * (fz * (fz * 6 - 15) + 10)
    PX0, PX1 = P[X0], P[X1]

    def corner(PX, Y, Z, dx, dy, dz):
        hsh = P[P[PX + Y] + Z]
        return GX[hsh] * dx + GY[hsh] * dy + GZ[hsh] * dz

    def zlerp(PX, Y, dx, dy):
        a = corner(PX, Y, Z0, dx, dy, fz)
        b = corner(PX, Y, Z1, dx, dy, fz - 1)
        return a + w * (b - a)

    a = zlerp(PX0, Y0, fx, fy)
    b = zlerp(PX1, Y0, fx - 1, fy)
    c = zlerp(PX0, Y1, fx, fy - 1)
    d = zlerp(PX1, Y1, fx - 1, fy - 1)
    ab = a + u * (b - a)
    cd = c + u * (d - c)
    return (ab + v * (cd - ab)) * F32(1.55)


def fbm(x, y, z, per, octaves=5, seed=0, gain=0.5, mode=None, zmul=None):
    """Fractal sum of periodic noise. mode None -> about -1..1; 'billow' (|n|, puffy lobes with
    creases) and 'ridged' ((1-|n|)^2, thin filaments) -> 0..1. zmul = per-octave frequency
    multiplier on z (time), so fine detail does not flicker faster than the flipbook can show."""
    tot, norm, amp = 0.0, 0.0, 1.0
    for o in range(octaves):
        f = 2 ** o
        fz = f if zmul is None else zmul[o]
        # Axes that must tile keep per * frequency <= 256; anything larger is a "don't care"
        # axis (period 64 by convention here) and is simply capped at the table size.
        pp = tuple(min(q, 256) for q in (per[0] * f, per[1] * f, per[2] * fz))
        n = pnoise3(x * f, y * f, z * fz, pp, seed + o * 101)
        if mode == "billow":
            n = np.abs(n)
        elif mode == "ridged":
            n = 1.0 - np.abs(n)
            n = n * n
        tot = tot + amp * n
        norm += amp
        amp *= gain
    return tot / norm


# ----------------------------------------------------------------------------- packing
def bleed(lum, alpha):
    """Fill RGB under fully transparent pixels with nearby visible luminance, so bilinear
    filtering and mipmaps never pull a dark or bright fringe in from alpha-0 texels."""
    if lum.size > 300000:
        sig = 6.0
    else:
        sig = 3.0
    wa = gblur(alpha, sig)
    wl = gblur(lum * alpha, sig)
    mean = float((lum * alpha).sum() / max(alpha.sum(), 1e-6))
    fill = np.where(wa > 1e-4, wl / np.maximum(wa, 1e-4), mean)
    return np.where(alpha > 0.5 / 255.0, lum, np.clip(fill, 0, 1)).astype(F32)


def to_rgba(lum, alpha, dither_seed=None):
    """float lum/alpha (0..1) -> uint8 RGBA. Optional dither hides 8-bit banding in wide soft
    gradients; it can never lift a zero-alpha pixel above zero."""
    lum = np.clip(lum, 0, 1).astype(F32)
    alpha = np.clip(alpha, 0, 1).astype(F32)
    lum = bleed(lum, alpha)
    if dither_seed is None:
        a8 = np.round(alpha * 255.0)
        l8 = np.round(lum * 255.0)
    else:
        rng = np.random.default_rng(dither_seed)
        a8 = np.floor(alpha * 255.0 + rng.random(alpha.shape, dtype=F32) * 0.999)
        l8 = np.floor(lum * 255.0 + rng.random(alpha.shape, dtype=F32) * 0.999)
        a8 = np.where(alpha <= 0, 0, a8)
    l8 = np.clip(l8, 0, 255).astype(np.uint8)
    a8 = np.clip(a8, 0, 255).astype(np.uint8)
    return np.dstack([l8, l8, l8, a8])


def pack_grid(frames_l, frames_a, cols):
    """Lay frames out left to right, top to bottom."""
    fs = frames_l[0].shape[0]
    rows = len(frames_l) // cols
    L = np.zeros((rows * fs, cols * fs), F32)
    A = np.zeros_like(L)
    for i, (l, a) in enumerate(zip(frames_l, frames_a)):
        r, c = divmod(i, cols)
        L[r * fs:(r + 1) * fs, c * fs:(c + 1) * fs] = l
        A[r * fs:(r + 1) * fs, c * fs:(c + 1) * fs] = a
    return L, A


# ============================================================================= 1. fire_loop
def make_fire_loop():
    """Side-on flame tongue. A teardrop envelope is bent by a low-frequency warp field and eaten
    by fbm 'erosion'; both fields scroll upward by a whole number of noise periods over the 64
    frames and are periodic in time, so the loop is exact. Erosion strength grows with height,
    which is what tears the tip into detached wisps."""
    N, fs, ss = 64, 128, 2
    n = fs * ss
    X, Y = grid(n)
    u = (X - 0.5) * 2.0
    h = 1.0 - Y                              # height above the bottom of the frame
    v = (h - 0.07) / 0.88                   # 0 at the flame base, 1 near the top
    vc = np.clip(v, 0, 1)
    win = window(fs)
    Ls, As = [], []
    for f in range(N):
        tau = f / N
        # --- warp (sway + curl-ish sideways shove), rises 2 frame-heights per loop
        wy = h * 1.5 - tau * 3.0
        wx = fbm(X * 2.0 + 3.1, wy, tau * 2.0, (8, 3, 2), 3, seed=11, zmul=[1, 2, 2])
        wv = fbm(X * 2.0 + 9.4, wy + 1.7, tau * 2.0, (8, 3, 2), 3, seed=12, zmul=[1, 2, 2])
        uu = u + (0.05 + 0.42 * vc) * wx
        vv = v + 0.16 * vc * wv
        # --- envelope: round-bottomed base (sqrt width) narrowing to a tongue
        width = 0.66 * (1.0 - 0.58 * np.clip(vv, 0, 1)) * np.sqrt(np.clip(v / 0.30, 0.01, 1.0))
        shape = 1.0 - (uu / width) ** 2 - 0.66 * np.clip(vv, 0, 1.3) ** 2.2
        # --- erosion: taller-than-wide cells (licks), rises faster than the warp
        ex = X * 4.5 + 0.60 * wx
        ey = h * 2.5 - tau * 5.0 + 0.35 * wv
        e = fbm(ex, ey, tau * 3.0, (16, 5, 3), 5, seed=23, zmul=[1, 1, 2, 2, 4])
        d = shape + e * (0.42 + 1.85 * vc) - 0.26 * vc
        # keep everything inside the frame without a visible clip
        d = d - 2.5 * sstep(0.86, 1.02, v) - 2.5 * sstep(0.76, 0.95, np.abs(u))
        alpha = sstep(0.0, 0.30, d) * sstep(0.0, 0.06, v)
        core = sstep(0.12, 0.95, d)
        # fine filaments inside the body so the core is not a flat blob
        fil = fbm(ex * 2.0, ey * 1.5, tau * 3.0, (32, 15, 3), 3, seed=41, mode="ridged", zmul=[1, 2, 2])
        lum = (0.36 + 0.64 * core) * (0.80 + 0.20 * fil) * (1.0 - 0.30 * vc * (1.0 - core))
        Ls.append(down(lum * alpha, ss))     # premultiplied resolve, un-premultiply below
        As.append(down(alpha, ss))
    for i in range(N):
        a = As[i]
        Ls[i] = np.where(a > 1e-4, Ls[i] / np.maximum(a, 1e-4), 0.0)
        As[i] = a * win
    return pack_grid(Ls, As, 8)


# ============================================================================= 2/3. clouds
def _cloud(N, fs, seed, fire):
    """Shared billowing-cloud flipbook for the fireball and the smoke puff.

    Density = radial ball + 'billow' fbm (|noise| gives cauliflower lobes with dark creases).
    The noise domain is divided by the growing radius, so lobes are carried outward with the
    expansion instead of sliding through a fixed pattern, and a swirl warp that strengthens
    with time rolls them. Late on, the radial term is faded out and an erosion threshold rises,
    so the ball breaks into separate thinning wisps rather than shrinking as a disc. Luminance
    mixes a heat term (emissive, centre-weighted, decaying) with fake top-left lighting taken
    from the density gradient, which is what gives the lumpy self-shadowed look."""
    ss = 2
    n = fs * ss
    X, Y = grid(n)
    u = (X - 0.5) * 2.0
    w = (Y - 0.5) * 2.0
    rf = np.hypot(u, w)
    win = window(fs)
    rng = np.random.default_rng(seed)
    ox, oy = rng.random(2) * 40.0 + 5.0
    Ls, As = [], []
    for f in range(N):
        t = f / (N - 1)
        if fire:
            R = 0.10 + 0.46 * (1.0 - np.exp(-8.5 * t)) + 0.10 * t
            rise = -0.08 * t ** 1.3
            amp = 0.30 + 0.75 * t
            radial = 1.0 - 0.72 * sstep(0.45, 0.95, t)
            erode = 0.52 * sstep(0.55, 1.0, t) ** 1.5
            edge = 0.20
            swirl = 0.10 + 0.55 * t
        else:
            R = 0.20 + 0.42 * (1.0 - np.exp(-4.5 * t)) + 0.05 * t
            rise = -0.06 * t
            amp = 0.34 + 0.50 * t
            radial = 1.0 - 0.60 * sstep(0.40, 0.95, t)
            erode = 0.70 * sstep(0.45, 1.0, t) ** 1.4
            edge = 0.42
            swirl = 0.12 + 0.45 * t
        px, py = u, w - rise
        r = np.hypot(px, py)
        k = 0.40 + 0.60 * (R / 0.6)                      # noise domain expands with the ball
        qx = px / k * 2.1 + ox
        qy = py / k * 2.1 + oy
        z = t * 2.2
        sx = fbm(qx * 0.6 + 11.0, qy * 0.6, z * 0.7, (64, 64, 64), 3, seed=seed + 1, zmul=[1, 1, 2])
        sy = fbm(qx * 0.6, qy * 0.6 + 23.0, z * 0.7, (64, 64, 64), 3, seed=seed + 2, zmul=[1, 1, 2])
        qx = qx + swirl * sx
        qy = qy + swirl * sy
        b = fbm(qx, qy, z, (64, 64, 64), 5, seed=seed + 3, gain=0.52, mode="billow", zmul=[1, 1, 2, 2, 3])
        bn = (b - 0.30) * 2.4                             # about -0.7..1.2
        d = radial * (1.0 - r / R) + (1.0 - radial) * 0.30 * sstep(R * 1.35, R * 0.4, r) + amp * bn - erode
        d = d - 3.0 * sstep(0.78, 0.94, rf)               # frame guard
        d = d - 2.0 * sstep(R * 1.25, R * 1.75, r)        # nothing far outside the ball
        alpha = sstep(0.0, edge, d)
        # --- fake lighting from the density height field (light from the upper left)
        hgt = gblur(np.clip(d, -0.2, 1.2), 1.6)
        gy, gx = np.gradient(hgt)
        shade = np.clip(0.5 + (0.6 * gx + 0.8 * gy) * 9.0, 0.0, 1.0)
        crease = sstep(0.02, 0.22, b)                      # dark seams between lobes
        if fire:
            heat = np.exp(-2.1 * t) * (1.0 - 0.6 * sstep(0.5, 0.8, t))
            hot = np.clip(heat * (0.62 + 0.75 * sstep(0.0, 0.9, d)) * (0.72 + 0.28 * crease), 0, 1)
            smoke = (0.13 + 0.22 * shade) * (0.75 + 0.25 * crease)
            lum = smoke + (1.0 - smoke) * hot
            alpha = alpha * (1.0 - 0.50 * sstep(0.50, 1.0, t)) * (1.0 - sstep(0.84, 0.99, t))
            # initial flash: a soft bloom around the core for the first few frames
            flash = np.exp(-(r / (R * 1.3 + 0.06)) ** 2) * np.exp(-t * 26.0) * (1.0 - sstep(0.45, 0.85, rf))
            alpha = np.maximum(alpha, 0.85 * flash)
            lum = np.maximum(lum, np.clip(flash * 1.6, 0, 1))
        else:
            lum = (0.34 + 0.66 * shade) * (0.78 + 0.22 * crease)
            alpha = alpha * 0.92 * (0.75 + 0.25 * sstep(0.0, 0.06, t)) * (1.0 - sstep(0.45, 0.99, t) ** 1.3)
        Ls.append(down(lum * alpha, ss))
        As.append(down(alpha, ss))
    for i in range(N):
        a = As[i]
        Ls[i] = np.where(a > 1e-4, Ls[i] / np.maximum(a, 1e-4), 0.0)
        As[i] = a * win
    As[-1][:] = 0.0                                        # one-shots end on an empty frame
    return Ls, As


def make_fireball_burst():
    Ls, As = _cloud(64, 128, seed=700, fire=True)
    # Force the alpha-weighted mean luminance to fall strictly after its peak, so one emitter
    # ColorSequence can run white-hot -> orange -> grey without the texture fighting it.
    # Measured on the 8-bit values that are actually written, so rounding cannot undo it.
    def mean_lum(l, a8):
        return float((np.round(np.clip(l, 0, 1) * 255.0) * a8).sum() / a8.sum() / 255.0)

    prev = None
    for i in range(len(Ls)):
        a8 = np.round(np.clip(As[i], 0, 1) * 255.0)
        if a8.sum() <= 0:
            continue
        m = mean_lum(Ls[i], a8)
        while prev is not None and m > prev - 5e-4 and m > 0.02:
            Ls[i] = Ls[i] * 0.992
            m = mean_lum(Ls[i], a8)
        prev = m
    return pack_grid(Ls, As, 8)


def make_smoke_puff():
    Ls, As = _cloud(64, 128, seed=900, fire=False)
    return pack_grid(Ls, As, 8)


# ============================================================================= 4. dust_wisp
def make_dust_wisp():
    """Ground-hugging dust: strongly anisotropic ridged fbm (long in X, thin in Y), domain-warped,
    scrolled sideways by exactly one noise period over the 16 frames, inside a flat lens-shaped
    envelope."""
    N, fs, ss = 16, 128, 2
    n = fs * ss
    X, Y = grid(n)
    u = (X - 0.5) * 2.0
    w = (Y - 0.5) * 2.0
    env_r = np.sqrt((u / 0.88) ** 2 + (w / 0.50) ** 2)
    env = 1.0 - sstep(0.25, 1.0, env_r)
    win = window(fs)
    Ls, As = [], []
    for f in range(N):
        tau = f / N
        sx = X * 1.5 - tau * 2.0
        wx = fbm(sx + 5.0, Y * 2.0, tau * 2.0, (2, 8, 2), 3, seed=301, zmul=[1, 1, 2])
        wy = fbm(sx, Y * 2.0 + 9.0, tau * 2.0, (2, 8, 2), 3, seed=302, zmul=[1, 1, 2])
        qx = sx + 0.10 * wx
        qy = Y * 6.0 + 0.55 * wy
        rid = fbm(qx, qy, tau * 2.0, (2, 32, 2), 5, seed=310, gain=0.55, mode="ridged", zmul=[1, 1, 2, 2, 2])
        soft = fbm(qx * 1.0 + 3.0, qy * 0.5, tau * 2.0, (2, 32, 2), 4, seed=320, zmul=[1, 1, 2, 2])
        dens = (rid - 0.42) * 2.2 + 0.45 * soft
        alpha = sstep(0.0, 0.75, dens) * env * 0.85
        lum = 0.62 + 0.38 * sstep(0.1, 1.0, dens)
        Ls.append(down(lum * alpha, ss))
        As.append(down(alpha, ss))
    for i in range(N):
        a = As[i]
        Ls[i] = np.where(a > 1e-4, Ls[i] / np.maximum(a, 1e-4), 0.0)
        As[i] = a * win
    return pack_grid(Ls, As, 4)


# ============================================================================= 5. arc_flipbook
def _bolt(rng, a, b, levels, rough):
    """Midpoint-displacement polyline from a to b."""
    pts = np.array([a, b], dtype=np.float64)
    disp = rough * np.linalg.norm(pts[1] - pts[0])
    for _ in range(levels):
        seg = pts[1:] - pts[:-1]
        nrm = np.stack([-seg[:, 1], seg[:, 0]], axis=1)
        nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
        mid = (pts[:-1] + pts[1:]) * 0.5 + nrm * rng.normal(size=(len(seg), 1)) * disp
        out = np.empty((len(pts) + len(mid), 2))
        out[0::2] = pts
        out[1::2] = mid
        pts = out
        disp *= 0.55
    return pts


def _arc_segments(rng):
    """One bolt: main channel through the frame centre plus tapering forks. Returns segment
    endpoints and per-endpoint intensity (frame units 0..1)."""
    a = np.array([0.10, 0.5 + rng.uniform(-0.14, 0.14)])
    b = np.array([0.90, 0.5 + rng.uniform(-0.14, 0.14)])
    c = np.array([0.5 + rng.uniform(-0.05, 0.05), 0.5 + rng.uniform(-0.06, 0.06)])
    left = _bolt(rng, a, c, 5, 0.20)
    right = _bolt(rng, c, b, 5, 0.20)
    main = np.vstack([left, right[1:]])
    s = np.linspace(0, 1, len(main))
    inten = 0.30 + 0.70 * sstep(0.0, 0.10, s) * sstep(1.0, 0.90, s)
    A, B, IA, IB = [main[:-1]], [main[1:]], [inten[:-1]], [inten[1:]]

    def fork(origin, ang, length, i0, levels):
        end = origin + length * np.array([np.cos(ang), np.sin(ang)])
        end = np.clip(end, 0.11, 0.89)
        pts = _bolt(rng, origin, end, levels, 0.24)
        ii = i0 * (1.0 - np.linspace(0, 1, len(pts))) ** 0.8
        A.append(pts[:-1]); B.append(pts[1:]); IA.append(ii[:-1]); IB.append(ii[1:])
        return pts

    for _ in range(int(rng.integers(2, 5))):
        i = int(rng.integers(int(len(main) * 0.12), int(len(main) * 0.85)))
        j = min(i + 4, len(main) - 1)
        base = np.arctan2(*(main[j] - main[i])[::-1])
        if rng.random() < 0.25:
            base += np.pi                                   # the odd fork runs backwards
        ang = base + rng.choice([-1, 1]) * rng.uniform(0.35, 1.05)
        pts = fork(main[i], ang, rng.uniform(0.14, 0.34), rng.uniform(0.45, 0.70), 4)
        if rng.random() < 0.5:
            k = len(pts) // 2
            fork(pts[k], ang + rng.choice([-1, 1]) * rng.uniform(0.4, 0.9), rng.uniform(0.08, 0.18), 0.30, 3)
    return np.vstack(A), np.vstack(B), np.concatenate(IA), np.concatenate(IB)


def make_arc_flipbook():
    """Sixteen unrelated bolts. Each is rendered from the exact distance to its line segments:
    a narrow gaussian core (crisp, antialiased by 3x supersampling) plus a wide 1/(1+d^2) glow."""
    N, fs, ss = 16, 128, 3
    n = fs * ss
    X, Y = grid(n)
    P = np.stack([X.ravel(), Y.ravel()], axis=1).astype(F32)       # (n*n, 2)
    win = window(fs, soft=12.0)
    rng = np.random.default_rng(5150)
    Ls, As = [], []
    for f in range(N):
        A, B, IA, IB = _arc_segments(rng)
        A = A.astype(F32); B = B.astype(F32)
        AB = B - A
        ab2 = np.maximum((AB * AB).sum(1), 1e-12)
        core = np.zeros(n * n, F32)
        glow = np.zeros(n * n, F32)
        wc = (0.0080 * rng.uniform(0.85, 1.25))                      # core sigma, frame units (~1 px)
        wg = 0.040
        for s0 in range(0, len(A), 32):                              # chunked to bound memory
            a, ab, l2 = A[s0:s0 + 32], AB[s0:s0 + 32], ab2[s0:s0 + 32]
            ia, ib = IA[s0:s0 + 32].astype(F32), IB[s0:s0 + 32].astype(F32)
            px = P[:, None, 0] - a[None, :, 0]
            py = P[:, None, 1] - a[None, :, 1]
            tt = np.clip((px * ab[None, :, 0] + py * ab[None, :, 1]) / l2[None, :], 0, 1)
            dx = px - tt * ab[None, :, 0]
            dy = py - tt * ab[None, :, 1]
            d2 = dx * dx + dy * dy
            ii = ia[None, :] + (ib - ia)[None, :] * tt
            wcs = wc * (0.45 + 0.55 * ii)                             # forks are thinner as well as dimmer
            core = np.maximum(core, (ii * np.exp(-d2 / (wcs * wcs))).max(1))
            glow = np.maximum(glow, (ii / (1.0 + d2 / (wg * wg)) ** 1.25).max(1))
        core = core.reshape(n, n)
        glow = glow.reshape(n, n)
        gain = rng.uniform(0.85, 1.0)
        alpha = np.clip(core * 1.15 + 0.42 * glow, 0, 1) * gain
        lum = np.clip(0.62 + 0.55 * core, 0, 1)
        a = down(alpha, ss)
        l = down(lum * alpha, ss)
        Ls.append(np.where(a > 1e-4, l / np.maximum(a, 1e-4), 0.0))
        As.append(a * win)
    return pack_grid(Ls, As, 4)


# ============================================================================= 6. shock_ring
def make_shock_ring():
    """Thin shockwave front: hard outer edge, crisp line, exponential inner falloff. fbm sampled
    on a circle (cos, sin of the angle, so it closes without a seam) wobbles the radius slightly
    and breaks the inner haze into radial streaks."""
    fs, ss = 512, 2
    n = fs * ss
    X, Y = grid(n)
    x = (X - 0.5) * 2.0
    y = (Y - 0.5) * 2.0
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    cx, cy = np.cos(th), np.sin(th)
    wob = fbm(cx * 2.5 + 10.0, cy * 2.5 + 10.0, 0.3, (64, 64, 64), 4, seed=601)
    R = 0.845 + 0.010 * wob
    inside = R - r
    brk = fbm(cx * 7.0 + 30.0, cy * 7.0 + 30.0, r * 3.0, (64, 64, 64), 4, seed=611)   # radial streaks
    brk2 = fbm(x * 9.0 + 50.0, y * 9.0 + 50.0, 0.7, (64, 64, 64), 4, seed=621)        # isotropic mottling
    mod = np.clip(0.62 + 0.55 * brk + 0.30 * brk2, 0.12, 1.0)
    line = np.where(inside >= 0, np.exp(-(inside / 0.011) ** 2), np.exp(-(inside / 0.0055) ** 2))
    line = line * np.clip(0.80 + 0.35 * brk, 0.45, 1.0)
    haze = np.where(inside >= 0, 0.62 * np.exp(-inside / 0.085) + 0.14 * np.exp(-inside / 0.30), 0.0) * mod
    second = 0.22 * np.exp(-((inside - 0.075) / 0.010) ** 2) * np.clip(0.4 + 1.2 * brk2, 0, 1)  # faint trailing ripple
    alpha = np.clip(line + haze + second, 0, 1)
    lum = np.clip(0.62 + 0.40 * line, 0, 1)
    a = down(alpha, ss)
    l = down(lum * alpha, ss)
    return np.where(a > 1e-4, l / np.maximum(a, 1e-4), 0.0), a * window(fs)


# ============================================================================= 7. glow_soft
def make_glow_soft():
    """Gaussian core plus a wide halo, multiplied by (1-r^2)^2 so it reaches exactly zero at the
    inscribed circle. Dithered, because a wide 8-bit gradient bands otherwise."""
    fs = 256
    X, Y = grid(fs)
    r = np.hypot((X - 0.5) * 2.0, (Y - 0.5) * 2.0) * (fs / (fs - 10.0))    # r = 1 just inside the margin
    g = 0.78 * np.exp(-(r / 0.17) ** 2) + 0.34 * np.exp(-(r / 0.45) ** 2)
    alpha = np.clip(g * (1.0 - np.clip(r, 0, 1) ** 2) ** 2, 0, 1)
    return np.ones_like(alpha), alpha * window(fs, soft=2.0)


# ============================================================================= 8. hover_pad
def make_hover_pad():
    """Top-down repulsor graphic, all analytic distance fields in polar coordinates (rings, tick
    marks, dashed and segmented arcs) plus a hexagon grid masked to the middle band, then a small
    bloom. Line weights are kept at 2 px or more so it survives being squashed in perspective."""
    fs, ss = 512, 2
    n = fs * ss
    X, Y = grid(n)
    x = (X - 0.5) * 2.0
    y = (Y - 0.5) * 2.0
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    aa = 1.5 / n                                  # antialias half-width in r units

    def ring(r0, wd):
        return 1.0 - sstep(wd / 2 - aa, wd / 2 + aa, np.abs(r - r0))

    def band(r0, r1):
        return sstep(r0 - aa, r0 + aa, r) * (1.0 - sstep(r1 - aa, r1 + aa, r))

    def ticks(count, wd, phase=0.0):
        """Radial lines of constant on-screen width `wd`."""
        fr = (th / (2 * np.pi) * count + phase) % 1.0 - 0.5
        dist = np.abs(fr) / count * 2 * np.pi * r
        return 1.0 - sstep(wd / 2 - aa, wd / 2 + aa, dist)

    def arcs(count, fill, phase=0.0):
        """`count` arc segments, each covering `fill` of its sector."""
        fr = np.abs((th / (2 * np.pi) * count + phase) % 1.0 - 0.5) * 2.0   # 0 centre .. 1 gap
        e = aa * count / (np.pi * np.maximum(r, 0.05))
        return 1.0 - sstep(fill - e, fill + e, fr)

    g = np.zeros((n, n), F32)
    # outer rim, tick scale and soft outer falloff
    g += 0.95 * ring(0.860, 0.014)
    g += 0.40 * np.exp(-((r - 0.860) / 0.045) ** 2)
    g += 0.70 * band(0.790, 0.846) * ticks(72, 0.0085)
    g += 0.95 * band(0.752, 0.846) * ticks(12, 0.016)
    # segmented power ring
    g += 0.85 * ring(0.705, 0.034) * arcs(6, 0.80, 0.5)
    g += 0.45 * ring(0.668, 0.007)
    # hex field in the middle band
    s = 0.092
    hx, hy = x / s, y / s
    s3 = 1.7320508
    ax_, ay_ = (hx % 1.0) - 0.5, (hy % s3) - s3 / 2
    bx_, by_ = ((hx - 0.5) % 1.0) - 0.5, ((hy - s3 / 2) % s3) - s3 / 2
    pick = (ax_ * ax_ + ay_ * ay_) < (bx_ * bx_ + by_ * by_)
    gx_, gy_ = np.where(pick, ax_, bx_), np.where(pick, ay_, by_)
    hd = np.maximum(np.abs(gx_), np.abs(gx_) * 0.5 + np.abs(gy_) * 0.8660254)   # 0 centre .. 0.5 edge
    ha = aa / s
    lines = sstep(0.5 - 0.075 - ha, 0.5 - 0.075 + ha, hd)
    ccx, ccy = hx - gx_, hy - gy_                                            # cell centre -> stable cell id
    cid = (np.round(ccx * 2).astype(np.int64) * 73856093) ^ (np.round(ccy / s3 * 2).astype(np.int64) * 19349663)
    hashv = ((cid * 2654435761) % 1000) / 1000.0
    cr = np.hypot(ccx, ccy) * s                                             # radius of the cell centre
    lit = (hashv < 0.30) & (cr > 0.40) & (cr < 0.60)
    fill = np.where(lit, 0.34 + 0.3 * hashv, 0.0) * (1.0 - sstep(0.30, 0.42, hd))
    hexmask = sstep(0.345, 0.395, r) * (1.0 - sstep(0.600, 0.650, r))
    g += (0.58 * lines + fill) * hexmask
    # bright inner ring and core details
    g += 1.00 * ring(0.300, 0.032)
    g += 0.55 * np.exp(-((r - 0.300) / 0.050) ** 2)
    g += 0.75 * ring(0.225, 0.013) * arcs(24, 0.55)
    g += 0.65 * ring(0.120, 0.010)
    g += 0.80 * band(0.045, 0.105) * ticks(4, 0.012, 0.5)
    g += 0.30 * np.exp(-(r / 0.10) ** 2)
    g += 0.10 * np.exp(-(r / 0.62) ** 2)                                     # faint disc so the pad reads as one shape
    g = np.clip(g, 0, 1)
    bloom = gblur(g, 7.0)
    alpha = np.clip(np.maximum(g, 0.0) + 0.45 * bloom * (1.0 - g), 0, 1)
    alpha = alpha * (1.0 - sstep(0.90, 0.975, r))
    lum = 0.70 + 0.30 * g
    a = down(alpha, ss)
    l = down(lum * alpha, ss)
    return np.where(a > 1e-4, l / np.maximum(a, 1e-4), 0.0), a * window(fs)


# ============================================================================= 9. spark_streak
def make_spark_streak():
    """Vertical streak: gaussian cross-section whose width and brightness taper from the head
    (top) to the tail, a round head cap, and a small two-scale glow at the head."""
    fs, ss = 256, 2
    n = fs * ss
    X, Y = grid(n)
    x = (X - 0.5) * 2.0
    y0, y1 = 0.13, 0.90
    s = (Y - y0) / (y1 - y0)
    sc = np.clip(s, 0, 1)
    wdt = 0.040 * (1.0 - sc) ** 0.75 + 0.0045
    body = (1.0 - sc) ** 1.35 * np.exp(-(x / wdt) ** 2) * sstep(1.0, 0.93, s)
    hy = (Y - y0) * 2.0
    hr = np.hypot(x, hy)
    body = np.where(s < 0, np.exp(-(hr / 0.040) ** 2), body)
    glow = 0.55 * np.exp(-(np.hypot(x, hy - 0.03) / 0.085) ** 2) + 0.20 * np.exp(-(np.hypot(x / 0.9, (hy - 0.10) / 1.6) / 0.16) ** 2)
    sheath = 0.22 * (1.0 - sc) ** 1.6 * np.exp(-(x / (wdt * 3.2)) ** 2) * (s > 0)
    alpha = np.clip(body + glow * (1 - body) + sheath * (1 - body), 0, 1)
    lum = np.clip(0.60 + 0.45 * body, 0, 1)
    a = down(alpha, ss)
    l = down(lum * alpha, ss)
    return np.where(a > 1e-4, l / np.maximum(a, 1e-4), 0.0), a * window(fs, soft=6.0)


# ============================================================================= 10. ember
def make_ember():
    """Glowing dot whose edge radius is perturbed by fbm (a chipped, irregular outline), with a
    hot centre and a faint halo."""
    fs, ss = 128, 4
    n = fs * ss
    X, Y = grid(n)
    x = (X - 0.5) * 2.0
    y = (Y - 0.5) * 2.0
    r = np.hypot(x, y)
    nz = fbm(x * 2.2 + 4.0, y * 2.2 + 8.0, 0.5, (64, 64, 64), 4, seed=1001)
    nz2 = fbm(x * 6.0 + 14.0, y * 6.0 + 2.0, 0.5, (64, 64, 64), 3, seed=1002)
    d = 1.0 - r / (0.50 * (1.0 + 0.42 * nz)) + 0.16 * nz2
    alpha = sstep(0.0, 0.45, d)
    core = sstep(0.25, 0.95, d)
    halo = 0.42 * np.exp(-(r / 0.40) ** 2) * (1.0 - sstep(0.55, 0.90, r))
    alpha = np.clip(np.maximum(alpha, halo), 0, 1)
    lum = np.clip(0.50 + 0.50 * core + 0.06 * nz2, 0, 1)
    a = down(alpha, ss)
    l = down(lum * alpha, ss)
    return np.where(a > 1e-4, l / np.maximum(a, 1e-4), 0.0), a * window(fs, soft=6.0)


# ============================================================================= 11-14. beam strips
def _strip(w, h):
    X, Y = grid(w, h)
    c = np.abs(Y - 0.5) * 2.0 * (h / (h - 4.0))      # 0 on the centre line, 1 two px inside the V edge
    return X, Y, np.clip(c, 0, 1.2)


def make_jet_core():
    """Beam core: two-gaussian V profile, with U-periodic stretched fbm modulating brightness and
    slightly breathing the width (cells ~10x longer in U than in V, so they read as flow lines)."""
    w, h = 512, 128
    X, Y, c = _strip(w, h)
    st = fbm(X * 4.0, Y * 9.0, 0.4, (4, 64, 8), 5, seed=1101, gain=0.55)
    st2 = fbm(X * 8.0, Y * 22.0, 0.9, (8, 64, 8), 3, seed=1102)
    br = fbm(X * 3.0, 0.37, 0.2, (3, 8, 8), 3, seed=1103)
    cc = c * (1.0 + 0.10 * br + 0.10 * st)
    prof = 0.80 * np.exp(-(cc / 0.20) ** 2) + 0.36 * np.exp(-(cc / 0.50) ** 2)
    prof = prof * (1.0 + 0.20 * st + 0.10 * st2)
    alpha = np.clip(prof, 0, 1) * (1.0 - np.clip(c, 0, 1) ** 2) ** 2
    lum = np.clip(0.66 + 0.34 * np.exp(-(cc / 0.22) ** 2) + 0.06 * st2, 0, 1)
    return lum, alpha * window(w, h, margin=2, soft=3.0, axes="y")


def make_shock_diamonds():
    """Mach diamonds: 4 identical cells of 128 px. Each has a bright soft diamond on the centre
    line, the crossing oblique-shock lines that join one diamond to the next, a thin core and a
    plume boundary that pinches between nodes."""
    w, h = 512, 128
    X, Y, c = _strip(w, h)
    fx = (X * 4.0) % 1.0 - 0.5                       # -0.5..0.5 inside each cell, node at 0
    afx = np.abs(fx)
    nz = fbm(X * 8.0, Y * 6.0, 0.3, (8, 64, 8), 4, seed=1201)
    dd = afx / 0.27 + c / 0.46
    node = np.clip(1.0 - dd, 0, 1) ** 0.75
    hot = np.exp(-((afx / 0.085) ** 2 + (c / 0.16) ** 2))               # mach disk at the node centre
    xl = np.abs(afx / 0.5 + c / 0.62 - 1.0)                              # the X of oblique shocks
    cross = 0.34 * np.exp(-(xl / 0.055) ** 2) * (c < 0.70)
    core = 0.50 * np.exp(-(c / 0.11) ** 2)
    bound = 0.60 * (0.72 + 0.28 * np.cos(fx * 2 * np.pi))                # plume edge bulges at the nodes
    sheath = 0.26 * np.exp(-(c / bound) ** 4)
    alpha = np.clip(0.92 * node + 0.5 * hot + cross + core + sheath, 0, 1) * (1.0 + 0.10 * nz)
    alpha = np.clip(alpha, 0, 1) * (1.0 - np.clip(c, 0, 1) ** 2) ** 1.5
    lum = np.clip(0.58 + 0.30 * node + 0.30 * hot + 0.05 * nz, 0, 1)
    return lum, alpha * window(w, h, margin=2, soft=3.0, axes="y")


def make_heat_streak():
    """Afterburner sheath: domain-warped ridged fbm, very long in U, under a wide soft V profile.
    Deliberately low alpha and broken up so it layers over jet_core without hiding it."""
    w, h = 512, 128
    X, Y, c = _strip(w, h)
    wx = fbm(X * 3.0 + 2.0, Y * 3.0, 0.2, (3, 64, 8), 3, seed=1301)
    wy = fbm(X * 3.0, Y * 3.0 + 7.0, 0.6, (3, 64, 8), 3, seed=1302)
    qy = Y * 7.0 + 0.9 * wy
    rid = fbm(X * 3.0 + 0.0 * wx, qy, 0.5, (3, 64, 8), 5, seed=1310, gain=0.58, mode="ridged")
    soft = fbm(X * 4.0, Y * 4.0 + 0.5 * wy, 0.8, (4, 64, 8), 4, seed=1320)
    lowf = fbm(X * 2.0, Y * 1.5, 0.1, (2, 64, 8), 2, seed=1330)
    dens = sstep(0.30, 0.85, rid + 0.30 * soft + 0.20 * lowf)
    prof = np.exp(-(c / 0.62) ** 2.4)
    alpha = np.clip((0.12 + 0.62 * dens) * prof, 0, 1) * (1.0 - np.clip(c, 0, 1) ** 2) ** 1.5
    lum = np.clip(0.60 + 0.40 * dens, 0, 1)
    return lum, alpha * window(w, h, margin=2, soft=3.0, axes="y")


def make_energy_ribbon():
    """Trail ribbon: hairline core + soft body, 4 comet-shaped pulses (sharp leading edge,
    exponential tail) and dashed rails near the edges; everything has period 128 or 32 px."""
    w, h = 512, 64
    X, Y, c = _strip(w, h)
    f = (X * 4.0) % 1.0
    pulse = np.exp(-f * 4.5) * sstep(0.0, 0.05, f) + np.exp(-(1.0 - f) * 60.0) * 0.0
    core = np.exp(-(c / 0.085) ** 2)
    body = 0.46 * np.exp(-(c / 0.36) ** 2)
    d = (X * 16.0) % 1.0
    dash = sstep(0.10, 0.16, d) * sstep(0.70, 0.64, d)
    rails = 0.42 * np.exp(-((c - 0.60) / 0.045) ** 2) * dash
    alpha = core * (0.80 + 0.20 * pulse) + body * (0.62 + 0.75 * pulse) + rails * (0.55 + 0.45 * pulse)
    alpha = np.clip(alpha, 0, 1) * (1.0 - np.clip(c, 0, 1) ** 2) ** 1.5
    lum = np.clip(0.68 + 0.32 * core + 0.10 * pulse, 0, 1)
    return lum, alpha * window(w, h, margin=2, soft=2.0, axes="y")


# ----------------------------------------------------------------------------- catalogue
# name -> (function, width, height, layout, frames, looping, tileable_u, dither, note)
SPEC = [
    ("fire_loop", make_fire_loop, 1024, 1024, "Grid8x8", 64, True, False, False,
     "Looping flame tongue. FlipbookMode Loop, ~30 fps, LightEmission 0.8-1, no rotation (base is at the bottom of the frame), size 3-8 studs, orange/yellow ColorSequence."),
    ("fireball_burst", make_fireball_burst, 1024, 1024, "Grid8x8", 64, False, False, False,
     "One-shot explosion. FlipbookMode OneShot, FlipbookFramerate so it spans Lifetime, random Rotation, size 8-20 studs, Color white-hot -> orange -> grey, LightEmission ~0.6 (it cannot be animated, so a middle value serves both the fire and the smoke end)."),
    ("smoke_puff", make_smoke_puff, 1024, 1024, "Grid8x8", 64, False, False, False,
     "One-shot smoke/dust puff. FlipbookMode OneShot, LightEmission 0, LightInfluence 1, random Rotation and slow RotSpeed, size 4-12 studs growing over lifetime."),
    ("dust_wisp", make_dust_wisp, 512, 512, "Grid4x4", 16, True, False, False,
     "Looping ground dust streaks. FlipbookMode Loop ~12 fps, Orientation VelocityParallel or flat-facing, LightEmission 0-0.3, size 4-10 studs, low Transparency ramp for the downwash ring."),
    ("arc_flipbook", make_arc_flipbook, 512, 512, "Grid4x4", 16, False, False, False,
     "16 different lightning bolts. FlipbookMode Random with FlipbookStartRandom, short Lifetime (0.05-0.12 s), LightEmission 1, cyan/violet tint, random Rotation, size 2-6 studs."),
    ("shock_ring", make_shock_ring, 512, 512, "None", 1, False, False, False,
     "Shockwave ring. One particle, Size 0 -> large over Lifetime 0.3-0.6 s, Transparency 0 -> 1, LightEmission 1; Orientation VelocityPerpendicular or a flat decal for ground rings."),
    ("glow_soft", make_glow_soft, 256, 256, "None", 1, False, False, True,
     "Generic radial glow / light bloom. LightEmission 1, any size; use for muzzle flashes, nozzle bloom and under-glow."),
    ("hover_pad", make_hover_pad, 512, 512, "None", 1, False, False, False,
     "Repulsor pad graphic. Flat under the car (SurfaceGui/Decal on a transparent part or a flat-oriented particle), LightEmission 1, slow rotation, cyan tint, size about the car width."),
    ("spark_streak", make_spark_streak, 256, 256, "None", 1, False, False, False,
     "Hot spark. Orientation VelocityParallel (head is at the top of the texture), LightEmission 1, size 0.3-1 stud, Squash for extra stretch at speed."),
    ("ember", make_ember, 128, 128, "None", 1, False, False, False,
     "Glowing ember dot. LightEmission 1, random Rotation, size 0.1-0.4 stud, orange -> dark red over lifetime."),
    ("jet_core", make_jet_core, 512, 128, "None", 1, False, True, True,
     "Beam: inner exhaust core. TextureMode Wrap, TextureLength ~4x Width, TextureSpeed 2-6, LightEmission 1, Width0 > Width1 for a tapering plume."),
    ("shock_diamonds", make_shock_diamonds, 512, 128, "None", 1, False, True, True,
     "Beam: mach diamonds (4 per tile). TextureMode Stretch or Wrap with TextureLength = beam length, TextureSpeed 0 or very low, LightEmission 1, layered over jet_core during boost."),
    ("heat_streak", make_heat_streak, 512, 128, "None", 1, False, True, True,
     "Beam: outer afterburner sheath. TextureMode Wrap, wider than jet_core, TextureSpeed a little slower than the core, LightEmission 0.6-1, Transparency 0.3+."),
    ("energy_ribbon", make_energy_ribbon, 512, 64, "None", 1, False, True, True,
     "Trail: sci-fi light ribbon. TextureMode Wrap, TextureLength 8-16 studs, LightEmission 1, FaceCamera on, tint with the car's accent colour."),
]


# ----------------------------------------------------------------------------- verification
def _frames(rgba, layout):
    g = {"Grid8x8": 8, "Grid4x4": 4}.get(layout)
    if g is None:
        return [rgba]
    fs = rgba.shape[0] // g
    return [rgba[r * fs:(r + 1) * fs, c * fs:(c + 1) * fs] for r in range(g) for c in range(g)]


def verify():
    rep = {}
    for name, _fn, w, h, layout, nfr, looping, tile, _d, _note in SPEC:
        path = os.path.join(OUT, name + ".png")
        if not os.path.exists(path):
            continue
        img = read_png(path)
        assert img.shape == (h, w, 4), (name, img.shape)
        A = img[..., 3].astype(np.float64)
        Lm = img[..., 0].astype(np.float64)
        fr = _frames(img, layout)
        e = {"size_bytes": os.path.getsize(path),
             "mean_alpha": round(float(A.mean()) / 255, 4),
             "frac_alpha_gt_half": round(float((A > 127.5).mean()), 4),
             "max_alpha": int(A.max())}
        b1, b4 = 0, 0
        for f in fr:
            a = f[..., 3]
            if tile:                                   # U edges are meant to tile; only V edges must be clear
                b1 = max(b1, int(a[0].max()), int(a[-1].max()))
                b4 = max(b4, int(a[:2].max()), int(a[-2:].max()))
            else:
                b1 = max(b1, int(a[0].max()), int(a[-1].max()), int(a[:, 0].max()), int(a[:, -1].max()))
                b4 = max(b4, int(a[:4].max()), int(a[-4:].max()), int(a[:, :4].max()), int(a[:, -4:].max()))
        e["max_border_alpha"] = b1
        e["max_margin_alpha"] = b4                      # 4 px margin (2 px V margin on beam strips)
        if len(fr) > 1:
            al = [f[..., 3].astype(np.float64) / 255 for f in fr]
            diffs = [float(np.abs(al[i + 1] - al[i]).mean()) for i in range(len(al) - 1)]
            e["consecutive_frame_mad"] = {"min": round(min(diffs), 5), "mean": round(float(np.mean(diffs)), 5), "max": round(max(diffs), 5)}
            if looping:
                e["last_to_first_mad"] = round(float(np.abs(al[-1] - al[0]).mean()), 5)
            else:
                e["last_frame_alpha_sum"] = float(al[-1].sum())
            e["frame_mean_alpha_min_max"] = [round(min(a.mean() for a in al), 4), round(max(a.mean() for a in al), 4)]
        if name == "fireball_burst":
            curve = []
            for f in fr:
                a = f[..., 3].astype(np.float64)
                curve.append(float((f[..., 0] * a).sum() / a.sum() / 255) if a.sum() > 0 else None)
            vals = [c for c in curve if c is not None]
            pk = int(np.argmax(vals))
            e["lum_peak_frame"] = pk + 1
            e["lum_monotonic_after_peak"] = bool(all(vals[i + 1] <= vals[i] + 1e-9 for i in range(pk, len(vals) - 1)))
            e["lum_curve"] = {str(i): (None if curve[i - 1] is None else round(curve[i - 1], 3)) for i in (1, 4, 8, 12, 20, 32, 44, 56)}
            e["alpha_sum_curve"] = {str(i): round(float(fr[i - 1][..., 3].sum()) / 255, 1) for i in (1, 4, 8, 12, 20, 32, 44, 56, 64)}
        if tile:
            # Column 0 and column w-1 are neighbours once tiled, so they should differ by no more
            # than ordinary neighbouring columns do. RGB is compared only where it is visible.
            i16 = img.astype(np.int16)
            a16 = i16[..., 3]
            vis = (a16[:, 0] > 8) & (a16[:, -1] > 8)
            visi = (a16[:, 1:] > 8) & (a16[:, :-1] > 8)
            e["tile_edge_max_diff_alpha"] = int(np.abs(a16[:, 0] - a16[:, -1]).max())
            e["tile_edge_max_diff_rgb"] = int((np.abs(i16[:, 0, 0] - i16[:, -1, 0]) * vis).max())
            e["interior_adjacent_col_max_diff_alpha"] = int(np.abs(a16[:, 1:] - a16[:, :-1]).max())
            e["interior_adjacent_col_max_diff_rgb"] = int((np.abs(i16[:, 1:, 0] - i16[:, :-1, 0]) * visi).max())
        rep[name] = e
    with open(os.path.join(OUT, "verification.json"), "w") as fh:
        json.dump(rep, fh, indent=1)
    return rep


# ----------------------------------------------------------------------------- contact sheet
_FONT = {
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
    "E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
    "I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
    "M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
    "Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
    "Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
    "2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
    "6": "011100111101111", "7": "111001010010010", "8": "111101111101111", "9": "111101111001110",
    "_": "000000000000111", ".": "000000000000010", "-": "000000111000000", "+": "000010111010000",
    "/": "001001010100100", ":": "000010000010000",
}


def _text(s, scale=3):
    s = s.upper()
    out = np.zeros((5, 4 * len(s)), F32)
    for i, ch in enumerate(s):
        bits = _FONT.get(ch)
        if bits:
            out[:, i * 4:i * 4 + 3] = np.array([int(b) for b in bits], F32).reshape(5, 3)
    return np.repeat(np.repeat(out, scale, 0), scale, 1)


BG = np.array([0.16, 0.16, 0.175], F32)


def _comp(img, tint=(1, 1, 1), add=0.0, bg=BG):
    """Composite an RGBA uint8 block over the background. add=1 -> additive, 0 -> alpha blend."""
    l = img[..., :3].astype(F32) / 255
    a = img[..., 3:4].astype(F32) / 255
    col = l * np.array(tint, F32)
    return np.clip(bg * (1.0 - a * (1.0 - add)) + col * a, 0, 1)


def _ramp(t, stops):
    ts = [s[0] for s in stops]
    return tuple(float(np.interp(t, ts, [s[1][k] for s in stops])) for k in range(3))


def contact_sheet():
    imgs = {}
    for name, *_ in SPEC:
        p = os.path.join(OUT, name + ".png")
        if os.path.exists(p):
            imgs[name] = read_png(p)
    spec = {s[0]: s for s in SPEC}
    rows = []                                              # (label, rgb float array)

    def strip(name, tint=(1, 1, 1), add=0.0, tint_fn=None, scale=1):
        fr = _frames(imgs[name], spec[name][4])[::4]
        parts = []
        for i, f in enumerate(fr):
            t = (i * 4) / (spec[name][5] - 1)
            if tint_fn:
                tn, ad = tint_fn(t)
            else:
                tn, ad = tint, add
            c = _comp(f, tn, ad)
            if scale > 1:
                c = np.repeat(np.repeat(c, scale, 0), scale, 1)
            parts.append(c)
        return np.concatenate(parts, axis=1)

    def hcat(parts, gap=16):
        hh = max(p.shape[0] for p in parts)
        out = []
        for p in parts:
            pad = np.ones((hh, p.shape[1], 3), F32) * BG
            pad[:p.shape[0]] = p
            out += [pad, np.ones((hh, gap, 3), F32) * BG]
        return np.concatenate(out[:-1], axis=1)

    def half(c):
        h, w, _ = c.shape
        return c.reshape(h // 2, 2, w // 2, 2, 3).mean(axis=(1, 3))

    fire_orange = (1.0, 0.48, 0.12)
    if "fire_loop" in imgs:
        rows.append(("fire_loop  every 4th frame  alpha over grey", strip("fire_loop")))
        rows.append(("fire_loop  tinted orange  additive", strip("fire_loop", fire_orange, 1.0)))
        # a second additive pass in yellow-white approximates two overlapping particles
        fr = _frames(imgs["fire_loop"], "Grid8x8")[::4]
        dbl = [np.clip(_comp(f, fire_orange, 1.0) + (f[..., :3].astype(F32) / 255) ** 3 * (f[..., 3:4].astype(F32) / 255) * np.array([0.9, 0.7, 0.3], F32), 0, 1) for f in fr]
        rows.append(("fire_loop  orange + hot core pass", np.concatenate(dbl, axis=1)))
    if "fireball_burst" in imgs:
        rows.append(("fireball_burst  every 4th frame  alpha over grey", strip("fireball_burst")))
        stops = [(0.0, (1.0, 0.95, 0.80)), (0.12, (1.0, 0.70, 0.25)), (0.35, (1.0, 0.42, 0.10)), (0.60, (0.55, 0.40, 0.34)), (1.0, (0.45, 0.45, 0.47))]
        rows.append(("fireball_burst  colour sequence white-hot to orange to grey",
                     strip("fireball_burst", tint_fn=lambda t: (_ramp(t, stops), float(1.0 - sstep(0.25, 0.60, t))))))
    if "smoke_puff" in imgs:
        rows.append(("smoke_puff  every 4th frame", strip("smoke_puff", (0.85, 0.83, 0.80))))
    two = []
    if "dust_wisp" in imgs:
        two.append(strip("dust_wisp", (0.80, 0.74, 0.66), 0.0, scale=2))
    if "arc_flipbook" in imgs:
        two.append(strip("arc_flipbook", (0.55, 0.85, 1.0), 1.0, scale=2))
    if two:
        rows.append(("dust_wisp frames 1 5 9 13 x2      arc_flipbook frames 1 5 9 13 x2 cyan additive", hcat(two, 0)))
    if "arc_flipbook" in imgs:
        allarc = [_comp(f, (0.60, 0.80, 1.0), 1.0) for f in _frames(imgs["arc_flipbook"], "Grid4x4")]
        rows.append(("arc_flipbook  all 16 frames", np.concatenate(allarc, axis=1)))
    singles = []
    if "shock_ring" in imgs:
        singles.append(half(_comp(imgs["shock_ring"], (1, 0.85, 0.6), 1.0)))
    if "hover_pad" in imgs:
        pad = _comp(imgs["hover_pad"], (0.35, 0.85, 1.0), 1.0)
        singles.append(half(pad))
        sq = pad.reshape(128, 4, 512, 3).mean(axis=1)                 # squashed 4:1 as if seen in perspective
        singles.append(np.concatenate([sq, np.ones((128, 512, 3), F32) * BG], axis=0))
    if "glow_soft" in imgs:
        singles.append(_comp(imgs["glow_soft"], (1, 0.8, 0.5), 1.0))
    if "spark_streak" in imgs:
        singles.append(_comp(imgs["spark_streak"], (1, 0.75, 0.35), 1.0))
    if "ember" in imgs:
        em = _comp(imgs["ember"], (1, 0.55, 0.15), 1.0)
        singles.append(np.repeat(np.repeat(em, 2, 0), 2, 1))
    if singles:
        rows.append(("shock_ring   hover_pad   hover_pad squashed 4:1   glow_soft   spark_streak   ember x2", hcat(singles)))
    for nm, tint in (("jet_core", (0.55, 0.80, 1.0)), ("shock_diamonds", (1.0, 0.62, 0.25)), ("heat_streak", (1.0, 0.45, 0.15)), ("energy_ribbon", (0.40, 0.95, 1.0))):
        if nm in imgs:
            im = imgs[nm]
            tiled = np.concatenate([im, im], axis=1)                 # shown twice end to end: seam is at the middle
            rows.append((nm + "  tiled x2  left: alpha over grey   right: tinted additive",
                         hcat([_comp(tiled), _comp(tiled, tint, 1.0)])))
    pad_px = 24
    W = max(r[1].shape[1] for r in rows) + pad_px * 2
    H = sum(r[1].shape[0] + 15 + 10 + 14 for r in rows) + pad_px
    sheet = np.ones((H, W, 3), F32) * BG
    y = pad_px
    for label, im in rows:
        tx = _text(label)[:, :W - 2 * pad_px]
        sheet[y:y + tx.shape[0], pad_px:pad_px + tx.shape[1]] = BG + tx[..., None] * (0.80 - BG)
        y += 15 + 10
        sheet[y:y + im.shape[0], pad_px:pad_px + im.shape[1]] = im
        y += im.shape[0] + 14
    out = np.dstack([np.round(sheet * 255).astype(np.uint8), np.full((H, W), 255, np.uint8)])
    write_png(os.path.join(OUT, "contact_sheet.png"), out)


def write_manifest():
    man = {"generator": "scripts/hover_feel/vfx_textures/make_textures.py",
           "convention": "RGB = white/grey luminance, alpha = coverage. Tint with the emitter Color. Flipbook frames read left to right, top to bottom.",
           "textures": []}
    for name, _fn, w, h, layout, nfr, looping, tile, _d, note in SPEC:
        man["textures"].append({"name": name + ".png", "width": w, "height": h, "layout": layout, "frames": nfr,
                                "looping": looping, "tileable_u": tile, "note": note})
    with open(os.path.join(OUT, "manifest.json"), "w") as fh:
        json.dump(man, fh, indent=1)


def main(argv):
    os.makedirs(OUT, exist_ok=True)
    only = set(a for a in argv if not a.startswith("-"))
    t00 = time.time()
    for i, (name, fn, w, h, _layout, _n, _loop, _tile, dither, _note) in enumerate(SPEC):
        if only and name not in only:
            continue
        t0 = time.time()
        lum, alpha = fn()
        assert lum.shape == (h, w) and alpha.shape == (h, w), (name, lum.shape)
        write_png(os.path.join(OUT, name + ".png"), to_rgba(lum, alpha, dither_seed=(4000 + i) if dither else None))
        print("%-16s %4dx%-4d %6.1fs" % (name, w, h, time.time() - t0), flush=True)
    write_manifest()
    rep = verify()
    contact_sheet()
    print(json.dumps(rep, indent=1))
    print("total %.1fs -> %s" % (time.time() - t00, OUT))


if __name__ == "__main__":
    main(sys.argv[1:])
