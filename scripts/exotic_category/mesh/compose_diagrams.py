"""Layer the raw diagram passes from images.diagrams() into the final slot diagrams.

    py -3 scripts/exotic_category/mesh/compose_diagrams.py

Input: output/exotic-images/diagrams/raw/base.png (whole car, grey) and one pink pass per slot.
Output: output/exotic-images/diagrams/<slot>.png (512 px, transparent): the grey car, a soft pink glow and
the pink slot on top, so a slot the body would hide still shows. Also writes sheet.jpg for review.
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "output", "exotic-images", "diagrams"))
ORDER = ["All", "Cockpit", "ThrustColour", "Underglow", "FrontBody", "FrontEngine", "Stabilisers", "RearEngine", "RearBody",
         "Boost", "Spoiler"]
DRAWN = ("ThrustColour", "Underglow")   # drawn here from the camera of images.diagrams(), not rendered
# The orthographic camera of images.diagrams(): azimuth, elevation, width of the view in studs, look-at point
# (car space: +X right, +Y up, forward -Z). Keep in step with images.py.
AZ, EL, VIEW, LOOK, RAW = 142.0, 36.0, 25.0, (0.0, 1.0, 0.3), 1024
# Main engine nozzles of the diagram car (Stinger): (x, y, z); the flame points back along +Z.
NOZZLES = [(5.1, 0.52, -5.4), (-5.1, 0.52, -5.4), (5.05, 0.62, 10.6), (-5.05, 0.62, 10.6)]
FLAME = [(0.0, -0.62), (1.3, -0.86), (3.2, -0.8), (2.1, -0.42), (4.9, 0.0), (2.1, 0.42), (3.2, 0.8), (1.3, 0.86), (0.0, 0.62)]
PINK = (233, 42, 148)
GREY = (226, 228, 234)
SIZE = 512   # final size; the raw passes are 1024


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


def solid(img, colour, close=13):
    """Fill the shadow gaps and pinholes of a pass: close its alpha, fill every enclosed hole, and paint the
    new pixels in a mid shade of the colour."""
    a = img.split()[3]
    closed = a.filter(ImageFilter.MaxFilter(close)).filter(ImageFilter.MinFilter(close))
    binary = closed.point(lambda v: 255 if v > 40 else 0)
    pad = Image.new("L", (binary.width + 2, binary.height + 2), 0)
    pad.paste(binary, (1, 1))
    ImageDraw.floodfill(pad, (0, 0), 128)          # 128 = outside; what stays 0 is an enclosed hole
    holes = pad.crop((1, 1, binary.width + 1, binary.height + 1)).point(lambda v: 255 if v == 0 else 0)
    full = ImageChops.lighter(ImageChops.lighter(a, closed), holes)
    under = Image.new("RGBA", img.size, tuple(int(c * 0.86) for c in colour) + (0,))
    under.putalpha(full)
    under.alpha_composite(img)
    return under


def project(p):
    """Car-space point to raw-pass pixel, for the orthographic diagram camera."""
    a, e = math.radians(AZ), math.radians(EL)
    f = (-math.cos(e) * math.sin(a), -math.sin(e), -math.cos(e) * math.cos(a))      # view direction
    n = math.hypot(f[2], f[0])
    r = (-f[2] / n, 0.0, f[0] / n)                                                   # screen right
    u = (r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0])   # screen up
    d = [p[i] - LOOK[i] for i in range(3)]
    k = RAW / VIEW
    return (RAW / 2 + k * sum(d[i] * r[i] for i in range(3)), RAW / 2 - k * sum(d[i] * u[i] for i in range(3)))


def drawn(slot):
    """Pink layer for the two diagrams that are drawn: flames behind the four main engines, or a pool of
    light under the car. Returns (layer, behind): behind=True goes under the car."""
    layer = Image.new("L", (RAW, RAW), 0)
    pen = ImageDraw.Draw(layer)
    if slot == "ThrustColour":
        for x, y, z in NOZZLES:
            base, tip = project((x, y, z)), project((x, y, z + 1.0))
            ax, ay = tip[0] - base[0], tip[1] - base[1]            # one stud along the flame, in pixels
            scale = (RAW / VIEW) / math.hypot(ax, ay)
            ax, ay = ax * scale, ay * scale                         # flame drawn at true stud size, not foreshortened
            px, py = -ay, ax
            pen.polygon([(base[0] + a * ax + c * px, base[1] + a * ay + c * py) for a, c in FLAME], fill=255)
            rad = 0.8 * RAW / VIEW
            pen.ellipse([base[0] - rad, base[1] - rad, base[0] + rad, base[1] + rad], fill=255)
        layer = layer.filter(ImageFilter.GaussianBlur(5)).point(lambda v: 255 if v > 110 else 0).filter(ImageFilter.GaussianBlur(1.5))
        return layer, False
    corners = [(-5.4, -1.9, -11.6), (5.4, -1.9, -11.6), (5.4, -1.9, 11.0), (-5.4, -1.9, 11.0)]
    pen.polygon([project(c) for c in corners], fill=255)
    return layer.filter(ImageFilter.GaussianBlur(20)), True


def main():
    base = solid(flat(Image.open(os.path.join(ROOT, "raw", "base.png")).convert("RGBA"), GREY), GREY)
    tiles = []
    for slot in ORDER:
        behind = False
        if slot in DRAWN:
            mask, behind = drawn(slot)
            part = Image.new("RGBA", base.size, PINK + (0,))
            part.putalpha(mask)
        else:
            part = flat(Image.open(os.path.join(ROOT, "raw", slot + ".png")).convert("RGBA"), PINK, keep=0.6)
        glow = Image.new("RGBA", part.size, PINK + (0,))
        glow.putalpha(part.split()[3].filter(ImageFilter.GaussianBlur(9)).point(lambda v: int(v * 0.75)))
        out = Image.new("RGBA", base.size, (0, 0, 0, 0))
        for layer in ((glow, part, base) if behind else (base, glow, part)):
            out.alpha_composite(layer)
        out = out.resize((SIZE, SIZE), Image.LANCZOS)
        out.save(os.path.join(ROOT, slot + ".png"), optimize=True)
        tiles.append(out)
    sheet = Image.new("RGB", (6 * 340, 2 * 340), (34, 36, 44))
    for i, im in enumerate(tiles):
        small = im.resize((340, 340), Image.LANCZOS)
        sheet.paste(small, ((i % 6) * 340, (i // 6) * 340), small)
    sheet.save(os.path.join(ROOT, "sheet.jpg"), quality=90)
    print("wrote %d diagrams and sheet.jpg" % len(tiles))


if __name__ == "__main__":
    main()
