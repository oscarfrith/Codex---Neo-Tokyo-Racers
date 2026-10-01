"""Validate a frame-class blockout spec and render offline previews (no Studio needed).

Usage: py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/<id>.json
Writes scripts/vehicle_blockouts/previews/<id>/{standard,exploded,sheet,build_NN_*}.png
Exit code 1 when the spec has errors (previews are still attempted where possible).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vbspec  # noqa: E402

SS = 2  # supersample
FIXED = {"detail": "#22252b", "glass": "#3f6f8f", "thrust": "#8ff6ff", "driver": "#d9b38c"}
LIGHT = np.array([0.35, 0.8, 0.45]) / np.linalg.norm([0.35, 0.8, 0.45])


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def view_basis(name):
    """Returns (right, up, toward_camera) unit vectors for an orthographic view."""
    dirs = {
        "front34": np.array([-0.62, 0.42, -0.66]),  # camera sits front-left-above (front is -Z)
        "rear34": np.array([0.62, 0.42, 0.66]),
        "side": np.array([-1.0, 0.0, 0.0]),
        "top": np.array([0.0, 1.0, 0.0001]),
        "front": np.array([0.0, 0.0, -1.0]),
    }
    d = dirs[name] / np.linalg.norm(dirs[name])
    world_up = np.array([0.0, 1.0, 0.0]) if name != "top" else np.array([0.0, 0.0, -1.0])
    right = np.cross(world_up, d)
    right /= np.linalg.norm(right)
    up = np.cross(d, right)
    return right, up, d


def colour_for(slot, part, paint, by_slot):
    ch = part.get("ch", "primary")
    if by_slot:
        if ch in ("glass", "driver"):
            return hex_rgb(FIXED[ch])
        return hex_rgb(vbspec.SLOT_COLOURS.get(slot, "#cccccc"))
    if ch in FIXED:
        return hex_rgb(FIXED[ch])
    return hex_rgb(paint.get(ch, {"primary": "#c9302c", "secondary": "#f2f2f2", "neon": "#00e5ff"}[ch]))


def render(items, view, size, paint=None, by_slot=False, wire_boxes=None, scale=None, title=None):
    """items: list of (slot, part, offset). wire_boxes: list of (slot, lo, hi)."""
    paint = paint or {}
    W, H = size[0] * SS, size[1] * SS
    img = Image.new("RGB", (W, H), "#eef0f3")
    draw = ImageDraw.Draw(img, "RGBA")
    right, up, d = view_basis(view)
    polys, pts_all = [], []
    for slot, part, off in items:
        w, faces = vbspec.world_mesh(part, off)
        rgb = colour_for(slot, part, paint, by_slot)
        centre = w.mean(axis=0)
        for f in faces:
            v = w[f]
            n = np.cross(v[1] - v[0], v[2] - v[0])
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n = n / ln
            if np.dot(n, v.mean(axis=0) - centre) < 0:
                n = -n
            if np.dot(n, d) <= 0.02:
                continue  # back face
            shade = 0.45 + 0.55 * max(0.0, float(np.dot(n, LIGHT)))
            if part.get("ch") in ("neon", "thrust") and not by_slot:
                shade = 1.0
            col = tuple(int(c * shade) for c in rgb)
            polys.append((float(np.dot(v.mean(axis=0), d)), v, col, part.get("ch") == "glass"))
            pts_all.append(v)
    boxes = wire_boxes or []
    for _, lo, hi in boxes:
        pts_all.append(np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]))
    if not pts_all:
        return img.resize(size)
    allp = np.vstack(pts_all)
    px, py = allp @ right, allp @ up
    if scale is None:
        scale = min((W * 0.86) / max(px.max() - px.min(), 1e-3), (H * 0.80) / max(py.max() - py.min(), 1e-3))
    else:
        scale = scale * SS
    cx, cy = (px.max() + px.min()) / 2, (py.max() + py.min()) / 2

    def proj(p):
        return (W / 2 + (float(np.dot(p, right)) - cx) * scale, H / 2 - (float(np.dot(p, up)) - cy) * scale + 10 * SS)

    polys.sort(key=lambda t: t[0])
    for _, v, col, glass in polys:
        pts = [proj(p) for p in v]
        draw.polygon(pts, fill=col + ((170,) if glass else (255,)), outline=(20, 22, 26, 150))
    edges = [(0, 1), (0, 2), (0, 4), (1, 3), (1, 5), (2, 3), (2, 6), (3, 7), (4, 5), (4, 6), (5, 7), (6, 7)]
    font = ImageFont.load_default(size=13 * SS)
    for slot, lo, hi in boxes:
        c = hex_rgb(vbspec.SLOT_COLOURS.get(slot, "#888888"))
        corners = [np.array([x, y, z]) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
        for a, b in edges:
            draw.line([proj(corners[a]), proj(corners[b])], fill=c + (255,), width=2 * SS)
        tx, ty = proj((lo + hi) / 2)
        draw.text((tx, ty), slot, fill=tuple(int(x * 0.55) for x in c) + (255,), font=font, anchor="mm")
    if title:
        draw.text((12 * SS, 8 * SS), title, fill=(20, 22, 26, 255), font=ImageFont.load_default(size=16 * SS))
    return img.resize(size, Image.LANCZOS)


def grid(images, cols, pad=6, bg="#ffffff"):
    if not images:
        return Image.new("RGB", (10, 10), bg)
    w, h = images[0].size
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad), bg)
    for i, im in enumerate(images):
        sheet.paste(im, (pad + (i % cols) * (w + pad), pad + (i // cols) * (h + pad)))
    return sheet


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    spec = vbspec.load(path)
    errors, warnings, stats = vbspec.validate(spec)
    print("SPEC %s: %d error(s), %d warning(s) %s" % (spec.get("id"), len(errors), len(warnings), stats))
    for e in errors:
        print("  ERROR  " + e)
    for w in warnings:
        print("  warn   " + w)
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews", str(spec.get("id", "unknown")))
    os.makedirs(out_dir, exist_ok=True)
    try:
        std = spec["standard"]
        boxes = [("Cockpit", lo, hi) for lo, hi in vbspec.boxes_of(std["cockpitEnvelope"])]
        for s, dslot in std["slots"].items():
            boxes += [(s, lo, hi) for lo, hi in vbspec.boxes_of(dslot["envelope"])]
        views = [render([], v, (640, 440), wire_boxes=boxes, title="%s frame standard: %s" % (spec["displayName"], v))
                 for v in ("front34", "top", "side", "front")]
        grid(views, 2).save(os.path.join(out_dir, "standard.png"))

        thumbs = []
        for i, b in enumerate(spec["builds"]):
            if b.get("cockpit") not in spec["cockpits"]:
                continue
            try:
                items = vbspec.build_parts(spec, b)
            except KeyError:
                continue
            paint = b.get("paint", {})
            name = b.get("name", "build %d" % i)
            ims = [render(items, v, (640, 440), paint=paint, title="%s / %s: %s" % (spec["displayName"], name, v))
                   for v in ("front34", "rear34", "side", "top")]
            safe = "".join(ch if ch.isalnum() else "_" for ch in name.lower())[:40]
            grid(ims, 2).save(os.path.join(out_dir, "build_%02d_%s.png" % (i, safe)))
            thumbs.append(render(items, "front34", (480, 330), paint=paint, title=name))
            if i == 0:
                ex = vbspec.build_parts(spec, b, exploded=True)
                exs = [render(ex, v, (760, 520), by_slot=True, title="%s exploded (slot colours): %s" % (spec["displayName"], v))
                       for v in ("front34", "top")]
                grid(exs, 2).save(os.path.join(out_dir, "exploded.png"))
        grid(thumbs, 3).save(os.path.join(out_dir, "sheet.png"))
        print("previews written to " + out_dir)
    except Exception as exc:  # keep validation output useful even if rendering fails
        print("  preview failed: %r" % (exc,))
        return 1
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
