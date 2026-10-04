"""Layer the raw diagram passes from images.diagrams() into the final slot diagrams.

    py -3 scripts/exotic_category/mesh/compose_diagrams.py

Input: output/exotic-images/diagrams/raw/base.png (whole car, grey) and one pink pass per slot.
Output: output/exotic-images/diagrams/<slot>.png (1024 px, transparent): the grey car, a soft pink glow and
the pink slot on top, so a slot the body would hide still shows. Also writes sheet.jpg for review.
"""
import os

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "output", "exotic-images", "diagrams"))
ORDER = ["All", "Cockpit", "FrontBody", "FrontEngine", "Stabilisers", "RearEngine", "RearBody", "Boost", "Spoiler"]
PINK = (233, 42, 148)
GREY = (226, 228, 234)


def flat(img, colour, keep=0.8):
    """Flatten a pass toward one colour, keeping a little of its shading, with its own alpha."""
    r, g, b, a = img.split()
    lum = Image.merge("RGB", (r, g, b)).convert("L")
    solid = Image.new("RGB", img.size, colour)
    lum = Image.eval(lum, lambda v: v)
    lo, hi = lum.getextrema()
    span = max(hi - lo, 1)
    shade = Image.merge("RGB", [lum.point(lambda v, c=c: int(c * (0.58 + 0.42 * (min(max(v, lo), hi) - lo) / span))) for c in colour])
    out = Image.blend(solid, shade, keep)
    out.putalpha(a)
    return out


def main():
    base = flat(Image.open(os.path.join(ROOT, "raw", "base.png")).convert("RGBA"), GREY)
    tiles = []
    for slot in ORDER:
        part = flat(Image.open(os.path.join(ROOT, "raw", slot + ".png")).convert("RGBA"), PINK, keep=0.6)
        glow = Image.new("RGBA", part.size, PINK + (0,))
        glow.putalpha(part.split()[3].filter(ImageFilter.GaussianBlur(9)).point(lambda v: int(v * 0.75)))
        out = Image.new("RGBA", base.size, (0, 0, 0, 0))
        for layer in (base, glow, part):
            out.alpha_composite(layer)
        out.save(os.path.join(ROOT, slot + ".png"))
        tiles.append(out)
    sheet = Image.new("RGB", (5 * 340, 2 * 340), (34, 36, 44))
    for i, im in enumerate(tiles):
        small = im.resize((340, 340), Image.LANCZOS)
        sheet.paste(small, ((i % 5) * 340, (i // 5) * 340), small)
    sheet.save(os.path.join(ROOT, "sheet.jpg"), quality=90)
    print("wrote %d diagrams and sheet.jpg" % len(tiles))


if __name__ == "__main__":
    main()
