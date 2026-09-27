"""Restyle the free-roam HUD dealership/garage icons (white on transparent, exported by export_icons.lua)
as map glyphs in the icons_glyph style: cyan glyph, dark outline, soft dark halo, 128x128."""
import pathlib
from PIL import Image, ImageFilter, ImageChops
from make_icons import CYAN_GLYPH, OUTLINE_DARK
from make_icons_glyph import OUTLINE, SHADOW, SHADOW_COL

HERE = pathlib.Path(__file__).parent
SS = 4                      # work at 512 = 4x the 128 output
GLYPH_SPAN = 92 * SS        # longest glyph side (matches the drawn glyphs' footprint)


def dilate(mask, radius):
    size = int(radius) * 2 + 1
    out = mask
    while size > 1:          # MaxFilter needs odd sizes; chain for large radii
        step = min(size, 31) if min(size, 31) % 2 else min(size, 31) - 1
        out = out.filter(ImageFilter.MaxFilter(step))
        size -= step - 1
    return out


def restyle(src, dst):
    alpha = Image.open(src).convert("RGBA").getchannel("A")
    alpha = alpha.crop(alpha.getbbox())
    scale = GLYPH_SPAN / max(alpha.size)
    alpha = alpha.resize((round(alpha.width * scale), round(alpha.height * scale)), Image.LANCZOS)
    canvas = 128 * SS
    glyph = Image.new("L", (canvas, canvas), 0)
    glyph.paste(alpha, ((canvas - alpha.width) // 2, (canvas - alpha.height) // 2))
    outline = dilate(glyph, OUTLINE * SS)
    halo = dilate(glyph, SHADOW * SS * 0.6).filter(ImageFilter.GaussianBlur(SHADOW * SS * 0.4))
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    def layer(mask, rgba):
        a = mask.point(lambda v: v * rgba[3] // 255)
        solid = Image.new("RGBA", (canvas, canvas), rgba[:3] + (255,))
        solid.putalpha(a)
        return solid
    out = Image.alpha_composite(out, layer(halo, SHADOW_COL))
    out = Image.alpha_composite(out, layer(outline, tuple(OUTLINE_DARK)))
    out = Image.alpha_composite(out, layer(glyph, tuple(CYAN_GLYPH)))
    out.resize((128, 128), Image.LANCZOS).save(dst)


for name, key in (("HudDealershipIcon", "Dealership"), ("HudGarageIcon", "Garage")):
    restyle(HERE / "hud_icons" / (name + ".png"), HERE / "icons_glyph" / (key + ".png"))
    print("wrote icons_glyph/" + key + ".png")
