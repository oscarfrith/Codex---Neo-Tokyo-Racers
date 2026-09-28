"""Make the Codex-painted graffiti murals (src/*_raw.png) seamless and derive normal/roughness.
Vertical: crop + linear cross-fade of the plain concrete strips.
Horizontal: self-overlap quilting with a minimum-error vertical seam (pieces overlap like real graffiti).
usage: py -3 gen_graffiti.py"""
import pathlib
import numpy as np
from PIL import Image
from sglib import N, blur, save_set

SRC = pathlib.Path(__file__).parent / "src"


def vfade(a, k):
    h = a.shape[0]
    out = a[: h - k].copy()
    w = (np.arange(k) / (k - 1))[:, None, None]
    out[:k] = a[h - k:] * (1 - w) + a[:k] * w
    return out


def hquilt(a, k, feather=3):
    h, w = a.shape[:2]
    A, B = a[:, w - k:], a[:, :k]
    cost = np.sqrt(((A - B) ** 2).sum(-1))
    # discourage seams near the overlap borders
    cost = cost + 0.02 * np.abs(np.linspace(-1, 1, k))[None, :] ** 4 * 50
    E = cost.copy()
    back = np.zeros((h, k), np.int64)
    for y in range(1, h):
        prev = E[y - 1]
        l = np.r_[np.inf, prev[:-1]]
        r = np.r_[prev[1:], np.inf]
        stack = np.stack([l, prev, r])
        idx = stack.argmin(0)
        E[y] += stack.min(0)
        back[y] = np.arange(k) + idx - 1
    seam = np.zeros(h, np.int64)
    seam[-1] = E[-1].argmin()
    for y in range(h - 1, 0, -1):
        seam[y - 1] = back[y, seam[y]]
    xs = np.arange(k)[None, :]
    m = np.clip((xs - seam[:, None]) / feather + 0.5, 0, 1)[..., None]  # 0 = A, 1 = B
    out = a[:, : w - k].copy()
    out[:, :k] = A * (1 - m) + B * m
    return out, seam


def process(slug, kv=90, kh=120, strength=4.0):
    raw = np.asarray(Image.open(SRC / f"{slug}_raw.png").convert("RGB"), np.float32) / 255
    t = vfade(raw, kv)
    t, seam = hquilt(t, kh)
    img = Image.fromarray((np.clip(t, 0, 1) * 255 + 0.5).astype(np.uint8)).resize((N, N), Image.LANCZOS)
    C = np.asarray(img, np.float32) / 255
    # paint mask from saturation / dark outlines; concrete is low-saturation mid grey
    mx, mn = C.max(-1), C.min(-1)
    sat = (mx - mn) / (mx + 1e-4)
    lum = C @ np.array([0.3, 0.59, 0.11], np.float32)
    paint = np.clip((sat - 0.18) * 4, 0, 1)
    paint = np.maximum(paint, np.clip((0.22 - lum) * 6, 0, 1))
    paint = blur(paint, 1.0)
    detail = lum - blur(lum, 3)
    H = 0.5 + detail * 1.5 * (1 - 0.7 * paint) + 0.04 * paint
    R = 0.9 - 0.25 * paint
    save_set(slug, C, H, strength, R)
    return seam


if __name__ == "__main__":
    for s in ("sg_graffiti_a", "sg_graffiti_b"):
        process(s)
        print("wrote", s)
