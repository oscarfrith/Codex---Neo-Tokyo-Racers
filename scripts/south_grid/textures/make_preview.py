"""Build out/preview_sheet.png (each colour map tiled 2x2) and print a seam check."""
import json, pathlib
import numpy as np
from PIL import Image, ImageDraw
D = pathlib.Path(__file__).parent
V = json.loads((D / "variants.json").read_text())
cell, pad = 400, 36
cols = 4
rows = (len(V) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (cell + 16) + 16, rows * (cell + pad + 16) + 16), (30, 30, 34))
dr = ImageDraw.Draw(sheet)
for k, v in enumerate(V):
    slug = v["name"].lower().replace(" ", "_")
    im = Image.open(D / "out" / f"{slug}_color.png").convert("RGB")
    a = np.asarray(im, np.float32)
    seam = (np.abs(a[0] - a[-1]).mean() + np.abs(a[:, 0] - a[:, -1]).mean()) / 2
    inner = (np.abs(a[1:] - a[:-1]).mean() + np.abs(a[:, 1:] - a[:, :-1]).mean()) / 2
    print(f"{slug:24s} seam {seam:5.2f}  interior {inner:5.2f}")
    t = Image.new("RGB", (2048, 2048))
    for i in range(2):
        for j in range(2):
            t.paste(im, (i * 1024, j * 1024))
    x, y = 16 + (k % cols) * (cell + 16), 16 + (k // cols) * (cell + pad + 16)
    sheet.paste(t.resize((cell, cell), Image.LANCZOS), (x, y + pad))
    dr.text((x, y + 8), f"{v['name']}  ({v['studsPerTile']} studs/tile, 2x2)", fill=(230, 230, 230))
sheet.save(D / "out" / "preview_sheet.png")
