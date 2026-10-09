"""Cuts a loading artwork into the Grid3x2 tile set the loading catalogue reads (3072x1728 composite, six
1024x864 tiles named R<row>C<column>) plus a 1024x576 single fallback. Usage: py -3 make_tiles.py <source> <id>"""
import sys
from pathlib import Path
from PIL import Image

src, art_id = Path(sys.argv[1]), sys.argv[2]
out = Path(__file__).parent / "out"
out.mkdir(exist_ok=True)
im = Image.open(src).convert("RGB")
W, H = 3072, 1728
# crop to 16:9 about the centre, then resample
w, h = im.size
target = W / H
if w / h > target:
    nw = round(h * target); im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
else:
    nh = round(w / target); im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
big = im.resize((W, H), Image.LANCZOS)
big.save(out / f"{art_id}_composite.png")
im.resize((1024, 576), Image.LANCZOS).save(out / f"{art_id}_single.png")
for r in range(2):
    for c in range(3):
        big.crop((c * 1024, r * 864, (c + 1) * 1024, (r + 1) * 864)).save(out / f"{art_id}_R{r+1}C{c+1}.png")
print("source", (w, h), "->", big.size)
