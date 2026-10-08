"""Read-only: measure white title text in a mockup frame (ink bounding box of bright pixels)."""
import sys

from PIL import Image

path = sys.argv[1]
boxes = [tuple(int(v) for v in a.split(",")) for a in sys.argv[2:]]
im = Image.open(path).convert("RGB")
print(path, im.size)
for box in boxes:
    crop = im.crop(box)
    w, h = crop.size
    px = crop.load()
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 215 and g > 210 and b > 215:
                xs.append(x)
                ys.append(y)
    if not xs:
        print(box, "no bright pixels")
        continue
    # row histogram to find the cap band (rows with many bright pixels)
    rows = {}
    for y in ys:
        rows[y] = rows.get(y, 0) + 1
    peak = max(rows.values())
    band = [y for y, n in rows.items() if n >= peak * 0.25]
    print(box, "ink x", box[0] + min(xs), box[0] + max(xs), "width", max(xs) - min(xs) + 1,
          "| ink y", box[1] + min(ys), box[1] + max(ys), "height", max(ys) - min(ys) + 1,
          "| dense band", box[1] + min(band), box[1] + max(band), "height", max(band) - min(band) + 1)
