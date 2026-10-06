"""Cube-face directions for Roblox skyboxes. face -> (look, right, top) as viewed from inside."""
import numpy as np
FACES = {
    'Ft': ((0, 0, -1), (1, 0, 0), (0, 1, 0)),
    'Bk': ((0, 0, 1), (-1, 0, 0), (0, 1, 0)),
    # Measured in Studio with make_debug.py (2026-10-06): SkyboxLf is drawn at +X and SkyboxRt at -X,
    # and SkyboxUp is turned a quarter turn from the naive layout. Dn was not measured (keep it featureless).
    'Lf': ((1, 0, 0), (0, 0, 1), (0, 1, 0)),
    'Rt': ((-1, 0, 0), (0, 0, -1), (0, 1, 0)),
    'Up': ((0, 1, 0), (0, 0, -1), (1, 0, 0)),
    'Dn': ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
}
def directions(face, size):
    look, right, top = (np.array(v, dtype=np.float64) for v in FACES[face])
    t = (np.arange(size) + 0.5) / size * 2 - 1
    u, v = np.meshgrid(t, t)
    d = look[None, None, :] + u[..., None] * right[None, None, :] - v[..., None] * top[None, None, :]
    return d / np.linalg.norm(d, axis=2, keepdims=True)
