"""Validate a frame-class blockout spec and render offline previews (no Studio needed).

Usage:
  py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/<id>.json [--check] [--only a,b]

  --check        validate only, write nothing
  --only a,b     render only the named outputs: standard, exploded, matrix, rows, fundamentals, sheet, builds

Writes scripts/vehicle_blockouts/previews/<id>/:
  standard.png      the slot envelopes
  exploded.png      first build pulled apart, one colour per slot
  matrix.png        every cockpit (rows) wearing every signature kit (columns): the interchange proof
  row_<cockpit>.png the same, one cockpit per file at larger size, front and rear views
  fundamentals.png  first cockpit with each engine, stabiliser and boost option highlighted in turn
  sheet.png         the builds list
  build_NN_*.png    four views of each build
Exit code 1 when the spec has errors.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vbspec  # noqa: E402

SS = 2  # supersample
FIXED = {"detail": "#22252b", "glass": "#5f8fb0", "thrust": "#8ff6ff", "driver": "#d9b38c"}
DEFAULT_PAINT = {"primary": "#c9302c", "secondary": "#f2f2f2", "neon": "#00e5ff"}
LIGHT = np.array([0.35, 0.8, 0.45]) / np.linalg.norm([0.35, 0.8, 0.45])
BG = (238, 240, 243)
GREY = (150, 154, 162)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def view_basis(name):
    """(right, up, toward_camera) unit vectors for an orthographic view."""
    dirs = {
        "front34": np.array([-0.62, 0.42, -0.66]),  # camera front-left-above (front is -Z)
        "rear34": np.array([0.62, 0.42, 0.66]),
        "side": np.array([-1.0, 0.0, 0.0]),
        "top": np.array([0.0, 1.0, 0.0001]),
        "front": np.array([0.0, 0.0, -1.0]),
        "rear": np.array([0.0, 0.0, 1.0]),
    }
    d = dirs[name] / np.linalg.norm(dirs[name])
    world_up = np.array([0.0, 1.0, 0.0]) if name != "top" else np.array([0.0, 0.0, -1.0])
    right = np.cross(world_up, d)
    right /= np.linalg.norm(right)
    up = np.cross(d, right)
    return right, up, d


def colour_for(slot, part, paint, mode, highlight=None):
    ch = part.get("ch", "primary")
    if mode == "slot":
        if ch in ("glass", "driver"):
            return hex_rgb(FIXED[ch])
        return hex_rgb(vbspec.SLOT_COLOURS.get(slot, "#cccccc"))
    if mode == "highlight":
        if slot == highlight:
            return hex_rgb(FIXED["thrust"]) if ch == "thrust" else hex_rgb(vbspec.SLOT_COLOURS.get(slot, "#cccccc"))
        return hex_rgb(FIXED["glass"]) if ch == "glass" else GREY
    if ch in FIXED:
        return hex_rgb(FIXED[ch])
    return hex_rgb((paint or {}).get(ch, DEFAULT_PAINT[ch]))


def render(items, view, size, paint=None, mode="paint", highlight=None, wire_boxes=None, title=None, sub=None):
    """Z-buffered orthographic render. items: list of (slot, part, offset). wire_boxes: list of (slot, lo, hi)."""
    W, H = size[0] * SS, size[1] * SS
    right, up, d = view_basis(view)
    tris = []
    pts_all = []
    fid = 0
    for slot, part, off in items:
        w, faces = vbspec.world_mesh(part, off)
        rgb = colour_for(slot, part, paint, mode, highlight)
        centre = w.mean(axis=0)
        glass = part.get("ch") == "glass"
        glow = part.get("ch") in ("neon", "thrust") and mode != "slot"
        pts_all.append(w)
        for f in faces:
            v = w[f]
            n = np.cross(v[1] - v[0], v[2] - v[0])
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n = n / ln
            if np.dot(n, v.mean(axis=0) - centre) < 0:
                n = -n
            if np.dot(n, d) <= 0.0:
                continue
            shade = 1.0 if glow else 0.42 + 0.58 * max(0.0, float(np.dot(n, LIGHT)))
            col = tuple(int(c * shade) for c in rgb)
            fid += 1
            for k in range(1, len(f) - 1):
                tris.append((v[0], v[k], v[k + 1], col, fid, glass))
    boxes = wire_boxes or []
    for _, lo, hi in boxes:
        pts_all.append(np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]))
    img = np.empty((H, W, 3), dtype=np.uint8)
    img[:] = BG
    if not pts_all:
        return Image.fromarray(img).resize(size)
    allp = np.vstack(pts_all)
    px, py = allp @ right, allp @ up
    scale = min((W * 0.88) / max(px.max() - px.min(), 1e-3), (H * 0.78) / max(py.max() - py.min(), 1e-3))
    cx, cy = (px.max() + px.min()) / 2, (py.max() + py.min()) / 2

    def proj(p):
        return (W / 2 + (float(np.dot(p, right)) - cx) * scale, H / 2 - (float(np.dot(p, up)) - cy) * scale + 12 * SS)

    zbuf = np.full((H, W), -1e18)
    idb = np.zeros((H, W), dtype=np.int32)
    for a, b, c, col, face_id, glass in tris:
        (x0, y0), (x1, y1), (x2, y2) = proj(a), proj(b), proj(c)
        z0, z1, z2 = float(np.dot(a, d)), float(np.dot(b, d)), float(np.dot(c, d))
        minx, maxx = max(int(min(x0, x1, x2)), 0), min(int(max(x0, x1, x2)) + 1, W - 1)
        miny, maxy = max(int(min(y0, y1, y2)), 0), min(int(max(y0, y1, y2)) + 1, H - 1)
        if minx > maxx or miny > maxy:
            continue
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9:
            continue
        xi = np.arange(minx, maxx + 1)
        yi = np.arange(miny, maxy + 1)
        X, Y = np.meshgrid(xi + 0.5, yi + 0.5)
        w0 = ((y1 - y2) * (X - x2) + (x2 - x1) * (Y - y2)) / den
        w1 = ((y2 - y0) * (X - x2) + (x0 - x2) * (Y - y2)) / den
        w2 = 1.0 - w0 - w1
        mask = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if glass:  # stipple so whatever sits behind shows through after downsampling
            mask &= ((xi[None, :] + yi[:, None]) % 2 == 0)
        z = w0 * z0 + w1 * z1 + w2 * z2
        sub_z = zbuf[miny:maxy + 1, minx:maxx + 1]
        upd = mask & (z > sub_z)
        if not upd.any():
            continue
        sub_z[upd] = z[upd]
        img[miny:maxy + 1, minx:maxx + 1][upd] = col
        idb[miny:maxy + 1, minx:maxx + 1][upd] = face_id
    edge = np.zeros((H, W), dtype=bool)
    edge[:, 1:] |= idb[:, 1:] != idb[:, :-1]
    edge[1:, :] |= idb[1:, :] != idb[:-1, :]
    img[edge] = (img[edge] * 0.35).astype(np.uint8)
    out = Image.fromarray(img)
    draw = ImageDraw.Draw(out, "RGBA")
    edges = [(0, 1), (0, 2), (0, 4), (1, 3), (1, 5), (2, 3), (2, 6), (3, 7), (4, 5), (4, 6), (5, 7), (6, 7)]
    font = ImageFont.load_default(size=13 * SS)
    for slot, lo, hi in boxes:
        c = hex_rgb(vbspec.SLOT_COLOURS.get(slot, "#888888"))
        corners = [np.array([x, y, z]) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
        for a, b in edges:
            draw.line([proj(corners[a]), proj(corners[b])], fill=c + (255,), width=2 * SS)
        draw.text(proj((lo + hi) / 2), slot, fill=tuple(int(x * 0.55) for x in c) + (255,), font=font, anchor="mm")
    if title:
        draw.text((10 * SS, 6 * SS), title, fill=(20, 22, 26, 255), font=ImageFont.load_default(size=15 * SS))
    if sub:
        draw.text((10 * SS, 25 * SS), sub, fill=(90, 96, 108, 255), font=ImageFont.load_default(size=11 * SS))
    return out.resize(size, Image.LANCZOS)


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
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
        args = [a for a in args if a != sys.argv[sys.argv.index("--only") + 1]]
    spec = vbspec.load(args[0])
    errors, warnings, stats = vbspec.validate(spec)
    print("SPEC %s: %d error(s), %d warning(s) %s" % (spec.get("id"), len(errors), len(warnings), stats))
    for e in errors:
        print("  ERROR  " + e)
    for w in warnings:
        print("  warn   " + w)
    if "--check" in sys.argv:
        return 1 if errors else 0

    def want(name):
        return only is None or name in only

    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews", str(spec.get("id", "unknown")))
    os.makedirs(out_dir, exist_ok=True)
    try:
        std = spec["standard"]
        if want("standard"):
            boxes = [("Cockpit", lo, hi) for lo, hi in vbspec.boxes_of(std["cockpitEnvelope"])]
            for s, dslot in std["slots"].items():
                boxes += [(s, lo, hi) for lo, hi in vbspec.boxes_of(dslot["envelope"])]
            views = [render([], v, (640, 440), wire_boxes=boxes, title="%s frame standard: %s" % (spec["displayName"], v))
                     for v in ("front34", "top", "side", "front")]
            grid(views, 2).save(os.path.join(out_dir, "standard.png"))

        valid = []
        for b in spec["builds"]:
            try:
                vbspec.build_parts(spec, b)
                valid.append(b)
            except KeyError:
                pass

        if want("exploded") and valid:
            ex = vbspec.build_parts(spec, valid[0], exploded=True)
            exs = [render(ex, v, (760, 520), mode="slot", title="%s exploded (slot colours): %s" % (spec["displayName"], v))
                   for v in ("front34", "rear34")]
            grid(exs, 2).save(os.path.join(out_dir, "exploded.png"))

        cockpits = list(spec["cockpits"].keys())
        kits = list(spec.get("kits", {}).keys())
        native = {}
        for b in valid:
            if vbspec.build_kind(spec, b) == "native":
                native[b["cockpit"]] = b.get("paint", {})

        if want("matrix") and cockpits and kits:
            cells = []
            for cid in cockpits:
                for kid in kits:
                    fake = {"cockpit": cid, "kit": kid}
                    try:
                        items = vbspec.build_parts(spec, fake)
                    except KeyError:
                        items = []
                    own = spec["cockpits"][cid].get("kit") == kid
                    cells.append(render(items, "front34", (420, 290), paint=native.get(cid, {}),
                                        title="%s + %s kit" % (spec["cockpits"][cid]["name"], spec["kits"][kid]["name"]),
                                        sub="native" if own else "swapped"))
            grid(cells, len(kits)).save(os.path.join(out_dir, "matrix.png"))

        if want("rows") and cockpits and kits:
            # One large image per cockpit: every kit from the front (top row) and the rear (bottom row).
            for old in glob.glob(os.path.join(out_dir, "row_*.png")):
                os.remove(old)
            for cid in cockpits:
                cells = []
                for view in ("front34", "rear34"):
                    for kid in kits:
                        try:
                            items = vbspec.build_parts(spec, {"cockpit": cid, "kit": kid})
                        except KeyError:
                            items = []
                        own = spec["cockpits"][cid].get("kit") == kid
                        cells.append(render(items, view, (560, 390), paint=native.get(cid, {}),
                                            title="%s + %s kit" % (spec["cockpits"][cid]["name"], spec["kits"][kid]["name"]),
                                            sub=("native" if own else "swapped") + ", " + ("front" if view == "front34" else "rear")))
                grid(cells, len(kits)).save(os.path.join(out_dir, "row_%s.png" % cid))

        if want("fundamentals") and cockpits:
            cid = cockpits[0]
            base = {"cockpit": cid, "kit": spec["cockpits"][cid].get("kit")}
            rows = []
            width = max(len(spec["modules"].get(s, {})) for s in vbspec.FUNDAMENTAL) or 1
            for s in vbspec.FUNDAMENTAL:
                label = std["slots"].get(s, {}).get("label", s)
                mids = list(spec["modules"].get(s, {}).keys())
                for i in range(width):
                    if i >= len(mids):
                        rows.append(Image.new("RGB", (420, 290), BG))
                        continue
                    b = dict(base)
                    b["modules"] = {s: mids[i]}
                    try:
                        items = vbspec.build_parts(spec, b)
                    except KeyError:
                        items = []
                    rows.append(render(items, "rear34" if s != "Stabilisers" else "front34", (420, 290), mode="highlight", highlight=s,
                                       title="%s: %s" % (label, spec["modules"][s][mids[i]]["name"]), sub=s))
            grid(rows, width).save(os.path.join(out_dir, "fundamentals.png"))

        if want("builds"):
            for old in glob.glob(os.path.join(out_dir, "build_*.png")):
                os.remove(old)
        thumbs = []
        for i, b in enumerate(valid):
            items = vbspec.build_parts(spec, b)
            paint = b.get("paint", {})
            name = b.get("name", "build %d" % i)
            if want("builds"):
                ims = [render(items, v, (640, 440), paint=paint, title="%s / %s: %s" % (spec["displayName"], name, v))
                       for v in ("front34", "rear34", "side", "top")]
                safe = "".join(ch if ch.isalnum() else "_" for ch in name.lower())[:40]
                grid(ims, 2).save(os.path.join(out_dir, "build_%02d_%s.png" % (i, safe)))
            if want("sheet"):
                thumbs.append(render(items, "front34", (480, 330), paint=paint, title=name, sub=vbspec.build_kind(spec, b)))
        if want("sheet"):
            grid(thumbs, 4).save(os.path.join(out_dir, "sheet.png"))
        print("previews written to " + out_dir)
    except Exception as exc:  # keep validation output useful even if rendering fails
        import traceback
        traceback.print_exc()
        print("  preview failed: %r" % (exc,))
        return 1
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
