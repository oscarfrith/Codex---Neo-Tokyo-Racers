from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


OUT = Path(__file__).resolve().parents[1] / "assets" / "ui" / "icons" / "mobile_controls"
SIZE = 512

PANEL = (15, 19, 24, 218)
PANEL_SOFT = (24, 29, 36, 236)
PINK = (244, 46, 151, 255)
CYAN = (43, 225, 218, 255)
BLUE = (25, 116, 255, 255)
WHITE = (246, 248, 252, 255)
MUTED = (163, 171, 184, 255)


def rounded_panel(draw: ImageDraw.ImageDraw, box, radius=72):
    draw.rounded_rectangle(box, radius=radius, fill=PANEL, outline=PINK, width=10)
    inset = tuple(v + 18 if i < 2 else v - 18 for i, v in enumerate(box))
    draw.rounded_rectangle(inset, radius=max(16, radius - 18), outline=(43, 225, 218, 70), width=3)


def glow_layer() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def composite_glow(base: Image.Image, shape: Image.Image, radius=20, opacity=170):
    alpha = shape.getchannel("A").filter(ImageFilter.GaussianBlur(radius))
    alpha = alpha.point(lambda p: p * opacity // 255)
    glow = Image.new("RGBA", base.size, CYAN)
    glow.putalpha(alpha)
    base.alpha_composite(glow)
    base.alpha_composite(shape)


def chevron(points, double=False):
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rounded_panel(draw, (36, 36, 476, 476))
    shape = glow_layer()
    sd = ImageDraw.Draw(shape)
    sd.line(points, fill=WHITE, width=54, joint="curve")
    sd.line(points, fill=CYAN, width=22, joint="curve")
    if double:
        shifted = [(x + 105, y) for x, y in points]
        sd.line(shifted, fill=WHITE, width=46, joint="curve")
        sd.line(shifted, fill=PINK, width=18, joint="curve")
    composite_glow(image, shape, 18, 150)
    return image


def accelerator():
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rounded_panel(draw, (76, 28, 436, 484), 92)
    pedal = glow_layer()
    pd = ImageDraw.Draw(pedal)
    pd.rounded_rectangle((164, 92, 348, 414), radius=66, fill=PANEL_SOFT, outline=CYAN, width=16)
    for y in range(150, 368, 54):
        pd.rounded_rectangle((202, y, 310, y + 18), radius=9, fill=WHITE)
    pd.polygon([(256, 112), (213, 172), (299, 172)], fill=CYAN)
    composite_glow(image, pedal, 18, 135)
    return image


def brake():
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rounded_panel(draw, (42, 76, 470, 436), 92)
    pedal = glow_layer()
    pd = ImageDraw.Draw(pedal)
    pd.rounded_rectangle((92, 160, 420, 352), radius=58, fill=PANEL_SOFT, outline=PINK, width=16)
    for x in range(142, 372, 58):
        pd.rounded_rectangle((x, 206, x + 22, 306), radius=11, fill=WHITE)
    pd.line((132, 378, 380, 378), fill=MUTED, width=14)
    composite_glow(image, pedal, 16, 105)
    return image


def save(image: Image.Image, name: str):
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / name, optimize=True)


def main():
    save(chevron([(334, 132), (192, 256), (334, 380)]), "mobile_turn_left.png")
    save(chevron([(275, 132), (133, 256), (275, 380)], double=True), "mobile_drift_left.png")
    save(accelerator(), "mobile_accelerator.png")
    save(brake(), "mobile_brake.png")


if __name__ == "__main__":
    main()
