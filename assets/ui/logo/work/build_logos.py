"""Pulse Racers logo candidates: writes one HTML/SVG source per candidate, rasterises it with
headless Chrome (transparent background), crops to the art with 4% padding, resizes to 2000 px
wide, then builds candidates/contact_sheet.png.

Run:  py -3 assets/ui/logo/work/build_logos.py [name ...]
Fonts come from the Google Fonts web faces (all SIL OFL 1.1); no font file is stored.
"""
import math, os, sys, subprocess, tempfile, shutil
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
LOGO = os.path.dirname(HERE)
CAND = os.path.join(LOGO, "candidates")
CHROME = os.environ.get("PULSE_CHROME", "C:/Program Files/Google/Chrome/Application/chrome.exe")
SUNSET_SRC = os.environ.get("PULSE_SUNSET", r"C:\Users\Oscar\AppData\Local\Temp\claude\C--Users-Oscar-Documents-LUCIDITY-Codex---Neo-Tokyo-Racers\8feff7e3-e41d-49a9-8101-dc724d32a100\images\6.webp")
SUNSET = os.path.join(HERE, "sunset.png")

W, H, OX, OY = 2400, 1140, 200, 120          # canvas; art is drawn in a 2000x900 space at (OX,OY)
PINK, VIOLET, CYAN, WHITE, INK, SLATE = "#FF2D95", "#9A3DFF", "#22E4FF", "#F3F0FF", "#07060D", "#0E0D1A"
REGION = 'filterUnits="userSpaceOnUse" x="-200" y="-120" width="2400" height="1140"'
PULSE_PATH = "M120 800 H1010 L1052 738 L1098 856 L1150 690 L1204 842 L1240 800 H1880"

COMMON = f"""
<linearGradient id="g" gradientUnits="userSpaceOnUse" x1="150" x2="1850" y1="0" y2="0">
 <stop offset="0" stop-color="{PINK}"/><stop offset=".55" stop-color="{VIOLET}"/><stop offset="1" stop-color="{CYAN}"/></linearGradient>
<linearGradient id="gl" gradientUnits="userSpaceOnUse" x1="150" x2="1850" y1="0" y2="0">
 <stop offset="0" stop-color="#FF7DBE"/><stop offset=".55" stop-color="#C79BFF"/><stop offset="1" stop-color="#9AF3FF"/></linearGradient>
<filter id="b3" {REGION}><feGaussianBlur stdDeviation="3"/></filter>
<filter id="b8" {REGION}><feGaussianBlur stdDeviation="8"/></filter>
<filter id="b16" {REGION}><feGaussianBlur stdDeviation="16"/></filter>
<filter id="b34" {REGION}><feGaussianBlur stdDeviation="34"/></filter>
<pattern id="haz" patternUnits="userSpaceOnUse" width="52" height="52" patternTransform="rotate(45)">
 <rect width="26" height="52" fill="{PINK}"/></pattern>
"""


def page(fonts, defs, body):
    return f"""<!doctype html>
<html><head><meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?{fonts}&display=block">
<style>html,body{{margin:0;background:transparent;overflow:hidden}}svg{{display:block}}</style></head>
<body><svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>{COMMON}{defs}</defs>
<g transform="translate({OX},{OY})">{body}</g>
</svg></body></html>
"""


def _text(s, font, size, weight, italic, x, y, ls, skew):
    # skewX shifts x by tan(skew)*y, so compensate to keep the stated x at the baseline
    dx = -math.tan(math.radians(skew)) * y if skew else 0
    return (f'<text x="{x + dx:.1f}" y="{y}" font-family="&quot;{font}&quot;" font-size="{size}" font-weight="{weight}" '
            f'font-style="{"italic" if italic else "normal"}" letter-spacing="{ls}">{s}</text>')


def words(font, size, weight, italic, p, r, ls=0, skew=0):
    """<g id=wm> holding the two word lines. p / r = (x, baseline)."""
    tf = f' transform="skewX({skew})"' if skew else ""
    return (f'<g id="wm"{tf}>{_text("PULSE", font, size, weight, italic, p[0], p[1], ls, skew)}'
            f'{_text("RACERS", font, size, weight, italic, r[0], r[1], ls, skew)}</g>')


def year(font, size, weight, italic, x, y, ls=6, skew=0):
    tf = f' transform="skewX({skew})"' if skew else ""
    return f'<g id="yr"{tf}>{_text("2098", font, size, weight, italic, x, y, ls, skew)}</g>'


def haz(x=150, y=92, w=120, h=296):
    """The pink hazard-stripe block of the current logo."""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#haz)" transform="translate({(y + h) * 0.2126:.0f},0) skewX(-12)"/>'


def tube(href, col="url(#g)", w=14, core=5, glow=1.0):
    """Neon tube: wide soft glow, tight glow, coloured tube, white-hot core."""
    s = 'fill="none" stroke-linejoin="round" stroke-linecap="round"'
    return (f'<use href="#{href}" {s} stroke="{col}" stroke-width="{w + 14}" filter="url(#b34)" opacity="{.55 * glow}"/>'
            f'<use href="#{href}" {s} stroke="{col}" stroke-width="{w + 6}" filter="url(#b8)" opacity="{.9 * glow}"/>'
            f'<use href="#{href}" {s} stroke="{col}" stroke-width="{w}"/>'
            f'<use href="#{href}" {s} stroke="#FFFFFF" stroke-width="{core}" opacity=".95"/>')


def c1_neon_tube():
    f = "Barlow Condensed"
    defs = words(f, 400, 800, True, (330, 400), (250, 732), ls=4) + year(f, 210, 800, True, 1400, 668) + f'<path id="pl" d="{PULSE_PATH}"/>'
    body = (
        # dark backing so the tubes read on a bright sky
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="30" stroke-linejoin="round" filter="url(#b8)" opacity=".5"/>'
        f'<use href="#yr" fill="{INK}" stroke="{INK}" stroke-width="22" stroke-linejoin="round" filter="url(#b8)" opacity=".5"/>'
        f'<use href="#pl" fill="none" stroke="{INK}" stroke-width="34" filter="url(#b8)" opacity=".45"/>'
        f'<use href="#wm" fill="{INK}" opacity=".78"/><use href="#wm" fill="url(#g)" opacity=".22"/>'
        f'<use href="#yr" fill="{INK}" opacity=".78"/>'
        + tube("wm", w=15, core=5) + tube("yr", col=CYAN, w=9, core=3, glow=.9) + tube("pl", w=12, core=4)
    )
    return page("family=Barlow+Condensed:ital,wght@1,800", defs, body)


def c2_chrome():
    f = "Exo 2"
    defs = (words(f, 340, 900, True, (300, 392), (210, 716), ls=-2) + year(f, 150, 900, True, 1500, 716, ls=4)
            + f'<path id="pl" d="{PULSE_PATH}"/>'
            + f"""<linearGradient id="chr" gradientUnits="userSpaceOnUse" x1="0" x2="0" y1="150" y2="392">
 <stop offset="0" stop-color="#FFFFFF"/><stop offset=".42" stop-color="#B9F5FF"/><stop offset=".56" stop-color="{CYAN}"/>
 <stop offset=".57" stop-color="#3B1173"/><stop offset=".78" stop-color="{VIOLET}"/><stop offset="1" stop-color="#FF6FB8"/></linearGradient>
<linearGradient id="chr2" href="#chr" y1="474" y2="716"/>
<clipPath id="top"><rect x="-200" y="-120" width="2400" height="550"/></clipPath>
<clipPath id="bot"><rect x="-200" y="430" width="2400" height="600"/></clipPath>""")
    body = (
        f'<use href="#wm" fill="{PINK}" stroke="{PINK}" stroke-width="30" stroke-linejoin="round" filter="url(#b34)" opacity=".5"/>'
        # hard offset shadow
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="26" stroke-linejoin="round" transform="translate(14,16)"/>'
        f'<use href="#wm" fill="{PINK}" stroke="{PINK}" stroke-width="26" stroke-linejoin="round"/>'
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="16" stroke-linejoin="round"/>'
        # white rim sits under the face so the font's overlapping contours never show
        f'<use href="#wm" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="6" stroke-linejoin="round"/>'
        f'<g clip-path="url(#top)"><use href="#wm" fill="url(#chr)"/></g><g clip-path="url(#bot)"><use href="#wm" fill="url(#chr2)"/></g>'
        f'<use href="#yr" fill="{INK}" stroke="{INK}" stroke-width="16" stroke-linejoin="round" transform="translate(8,9)"/>'
        f'<use href="#yr" fill="{INK}" stroke="{INK}" stroke-width="14" stroke-linejoin="round"/>'
        f'<use href="#yr" fill="{CYAN}" filter="url(#b8)" opacity=".8"/><use href="#yr" fill="#DFFBFF"/>'
        f'<use href="#pl" fill="none" stroke="{INK}" stroke-width="30" stroke-linejoin="round" transform="translate(6,8)"/>'
        + tube("pl", w=12, core=4)
    )
    return page("family=Exo+2:ital,wght@1,900", defs, body)


def c3_speed_slice():
    f = "Saira Condensed"
    slits = ""
    for base in (400, 732):                       # scanline cuts through the lower half of each line
        for dy, th in ((-150, 5), (-118, 8), (-84, 11), (-48, 14)):
            slits += f'<rect x="-200" y="{base + dy}" width="2400" height="{th}" fill="#000"/>'
    defs = (words(f, 410, 900, False, (300, 400), (232, 732), ls=2, skew=-12) + year(f, 165, 900, False, 1450, 700, skew=-12)
            + f'<path id="pl" d="{PULSE_PATH}"/><mask id="cut" maskUnits="userSpaceOnUse" x="-200" y="-120" width="2400" height="1140">'
              f'<rect x="-200" y="-120" width="2400" height="1140" fill="#fff"/>{slits}</mask>'
            + f'<linearGradient id="strk" x1="0" x2="1"><stop offset="0" stop-color="{PINK}" stop-opacity="0"/><stop offset="1" stop-color="{PINK}"/></linearGradient>')
    streaks = "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#strk)"/>' for x, y, w, h in
                      ((40, 262, 250, 8), (-40, 300, 300, 11), (60, 340, 190, 14), (-60, 594, 270, 8), (-140, 632, 320, 11), (-20, 672, 200, 14)))
    body = (
        f'<use href="#wm" fill="{VIOLET}" stroke="{VIOLET}" stroke-width="20" filter="url(#b34)" opacity=".55"/>'
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="22" stroke-linejoin="round" transform="translate(8,10)" opacity=".9"/>'
        + streaks +
        f'<g mask="url(#cut)"><use href="#wm" fill="{PINK}" transform="translate(-13,0)"/><use href="#wm" fill="{CYAN}" transform="translate(13,0)"/>'
        f'<use href="#wm" fill="#FFFFFF"/></g>'
        f'<use href="#yr" fill="{INK}" stroke="{INK}" stroke-width="16" stroke-linejoin="round" transform="translate(6,8)" opacity=".9"/>'
        f'<use href="#yr" fill="url(#g)" filter="url(#b8)" opacity=".7"/><use href="#yr" fill="url(#gl)"/>'
        f'<use href="#pl" fill="none" stroke="{INK}" stroke-width="28" transform="translate(5,7)" opacity=".9"/>'
        + tube("pl", w=12, core=4)
    )
    return page("family=Saira+Condensed:wght@900", defs, body)


def c4_pulse_trace():
    f = "Orbitron"
    trace = "M40 452 H1356 L1386 404 L1424 500 L1478 236 L1532 506 L1562 452 H1960"
    defs = (words(f, 286, 900, False, (250, 396), (90, 724), ls=4, skew=-12) + year(f, 92, 900, False, 1590, 392, ls=8, skew=-12)
            + f'<path id="pl" d="{trace}"/>'
            + '<linearGradient id="fade" gradientUnits="userSpaceOnUse" x1="40" x2="1960" y1="0" y2="0"><stop offset="0" stop-color="#fff" stop-opacity="0"/>'
              '<stop offset=".12" stop-color="#fff"/><stop offset=".9" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
              '<mask id="ends" maskUnits="userSpaceOnUse" x="-200" y="-120" width="2400" height="1140"><rect x="-200" y="-120" width="2400" height="1140" fill="url(#fade)"/></mask>')
    body = (
        f'<use href="#wm" fill="url(#g)" stroke="url(#g)" stroke-width="22" filter="url(#b34)" opacity=".55"/>'
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="30" stroke-linejoin="round" transform="translate(8,10)"/>'
        f'<use href="#wm" fill="url(#g)" stroke="url(#g)" stroke-width="20" stroke-linejoin="round"/>'
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
        f'<use href="#wm" fill="#FFFFFF"/>'
        # the trace cuts through the wordmark: ink gap, then the tube
        f'<g mask="url(#ends)"><use href="#pl" fill="none" stroke="{INK}" stroke-width="40" stroke-linejoin="round"/>'
        + tube("pl", w=14, core=5) + '</g>'
        f'<use href="#yr" fill="{INK}" stroke="{INK}" stroke-width="14" stroke-linejoin="round" transform="translate(5,6)"/>'
        f'<use href="#yr" fill="{CYAN}" filter="url(#b8)" opacity=".8"/><use href="#yr" fill="#DFFBFF"/>'
    )
    return page("family=Orbitron:wght@900", defs, body)


def c5_techno_extrude():
    f = "Chakra Petch"
    defs = (words(f, 350, 700, True, (310, 396), (226, 722), ls=0) + year(f, 128, 700, True, 1600, 722, ls=4)
            + f'<path id="pl" d="{PULSE_PATH}"/>'
            + '<linearGradient id="face" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E3D6FF"/></linearGradient>')
    ext = ""
    n = 14
    for i in range(n, 0, -1):                     # stacked hard extrusion, pink near the face to violet at the back
        t = i / n
        r = round(255 + (90 - 255) * t); g_ = round(45 + (30 - 45) * t); b = round(149 + (200 - 149) * t)
        ext += (f'<use href="#wm" fill="rgb({r},{g_},{b})" stroke="rgb({r},{g_},{b})" stroke-width="14" stroke-linejoin="miter" '
                f'transform="translate({i * 2.2:.1f},{i * 2.6:.1f})"/>')
    body = (
        haz() +
        f'<use href="#wm" fill="{PINK}" stroke="{PINK}" stroke-width="24" filter="url(#b34)" opacity=".5"/>'
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="30" stroke-linejoin="miter" transform="translate(34,40)"/>'
        + ext +
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="14" stroke-linejoin="miter"/>'
        f'<use href="#wm" fill="url(#face)" stroke="url(#face)" stroke-width="5" stroke-linejoin="miter"/>'
        f'<use href="#yr" fill="{INK}" stroke="{INK}" stroke-width="18" stroke-linejoin="miter" transform="translate(8,10)"/>'
        f'<use href="#yr" fill="{INK}" stroke="{INK}" stroke-width="14"/>'
        f'<use href="#yr" fill="{CYAN}" filter="url(#b8)" opacity=".8"/><use href="#yr" fill="{CYAN}" stroke="{CYAN}" stroke-width="3"/>'
        f'<use href="#pl" fill="none" stroke="{INK}" stroke-width="30" transform="translate(6,8)"/>'
        + tube("pl", w=12, core=4)
    )
    return page("family=Chakra+Petch:ital,wght@1,700", defs, body)


def c6_neon_rim():
    f = "Barlow Condensed"
    defs = (words(f, 400, 800, True, (330, 400), (250, 732), ls=2) + year(f, 215, 800, True, 1405, 672) + f'<path id="pl" d="{PULSE_PATH}"/>'
            + '<linearGradient id="face" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E9DDFF"/></linearGradient>')
    body = (
        haz() +
        f'<use href="#wm" fill="url(#g)" stroke="url(#g)" stroke-width="44" stroke-linejoin="round" filter="url(#b34)" opacity=".6"/>'
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="52" stroke-linejoin="round" transform="translate(8,12)" opacity=".85"/>'
        # gradient neon ring held off the letters by an ink gap
        f'<use href="#wm" fill="url(#g)" stroke="url(#g)" stroke-width="46" stroke-linejoin="round" filter="url(#b8)" opacity=".9"/>'
        f'<use href="#wm" fill="url(#g)" stroke="url(#g)" stroke-width="42" stroke-linejoin="round"/>'
        f'<use href="#wm" fill="url(#gl)" stroke="url(#gl)" stroke-width="35" stroke-linejoin="round"/>'
        f'<use href="#wm" fill="{INK}" stroke="{INK}" stroke-width="28" stroke-linejoin="round"/>'
        f'<use href="#wm" fill="url(#face)"/>'
        f'<use href="#yr" fill="{INK}" stroke="{INK}" stroke-width="22" stroke-linejoin="round"/>'
        f'<use href="#yr" fill="url(#g)" filter="url(#b8)" opacity=".8"/><use href="#yr" fill="url(#gl)"/>'
        f'<use href="#pl" fill="none" stroke="{INK}" stroke-width="32" stroke-linejoin="round"/>'
        + tube("pl", w=13, core=4)
    )
    return page("family=Barlow+Condensed:ital,wght@1,800", defs, body)


CANDIDATES = [
    ("1-neon-tube", c1_neon_tube), ("2-chrome-horizon", c2_chrome), ("3-speed-slice", c3_speed_slice),
    ("4-pulse-trace", c4_pulse_trace), ("5-techno-extrude", c5_techno_extrude), ("6-neon-rim", c6_neon_rim),
]


def render(src, png):
    prof = tempfile.mkdtemp(prefix="pulse_chrome_")
    try:
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                        "--default-background-color=00000000", "--user-data-dir=" + prof, f"--window-size={W},{H}",
                        "--virtual-time-budget=6000", "--screenshot=" + png, "file:///" + src.replace("\\", "/")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=240)
    finally:
        shutil.rmtree(prof, ignore_errors=True)
    return Image.open(png).convert("RGBA")


def finish(im):
    a = im.getchannel("A").point(lambda v: 255 if v > 3 else 0)
    x0, y0, x1, y1 = a.getbbox()
    edge = min(x0, y0, im.width - x1, im.height - y1)
    pad = round((x1 - x0) * 0.04)
    box = (max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad))
    im = im.crop(box)
    im = im.resize((2000, round(im.height * 2000 / im.width)), Image.LANCZOS)
    return im, edge


def over(bg, logo, width):
    lg = logo.resize((width, round(logo.height * width / logo.width)), Image.LANCZOS)
    out = bg.copy()
    out.alpha_composite(lg, ((out.width - lg.width) // 2, (out.height - lg.height) // 2))
    return out


def sheet(names):
    if not os.path.exists(SUNSET):
        Image.open(SUNSET_SRC).convert("RGB").save(SUNSET)
    sun = Image.open(SUNSET).convert("RGBA")
    cw, ch, sw, gap, lab = 900, 440, 380, 16, 34
    sh = (ch - gap) // 2
    big_sun = sun.crop((500, 0, 1672, 573)).resize((cw, ch), Image.LANCZOS)     # the bright orange/pink sky
    small_sun = sun.crop((900, 60, 1672, 507)).resize((sw, sh), Image.LANCZOS)
    dark = Image.new("RGBA", (cw, ch), "#0B0B12")
    small_dark = Image.new("RGBA", (sw, sh), "#0B0B12")
    out = Image.new("RGBA", (gap * 4 + cw * 2 + sw, gap + (ch + lab + gap) * len(names)), "#1B1A26")
    d = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", 24)
    except OSError:
        font = ImageFont.load_default()
    for i, n in enumerate(names):
        logo = Image.open(os.path.join(CAND, f"pulse-racers-logo-{n}.png")).convert("RGBA")
        y = gap + i * (ch + lab + gap)
        d.text((gap, y + 2), f"{n}   (sunset / #0B0B12 / 300 px wide on both)", fill="#F3F0FF", font=font)
        y += lab
        out.alpha_composite(over(big_sun, logo, 800), (gap, y))
        out.alpha_composite(over(dark, logo, 800), (gap * 2 + cw, y))
        out.alpha_composite(over(small_sun, logo, 300), (gap * 3 + cw * 2, y))
        out.alpha_composite(over(small_dark, logo, 300), (gap * 3 + cw * 2, y + sh + gap))
    out.convert("RGB").save(os.path.join(CAND, "contact_sheet.png"))


def main():
    want = sys.argv[1:]
    os.makedirs(CAND, exist_ok=True)
    for name, fn in CANDIDATES:
        if want and not any(w in name for w in want):
            continue
        src = os.path.join(CAND, f"pulse-racers-logo-{name}.html")
        with open(src, "w", encoding="utf-8") as fh:
            fh.write(fn())
        raw = render(src, os.path.join(HERE, name + ".raw.png"))
        im, edge = finish(raw)
        im.save(os.path.join(CAND, f"pulse-racers-logo-{name}.png"))
        print(name, im.size, "min margin to canvas edge:", edge, "px", "(CLIPPED?)" if edge < 4 else "")
    sheet([n for n, _ in CANDIDATES if os.path.exists(os.path.join(CAND, f"pulse-racers-logo-{n}.png"))])


if __name__ == "__main__":
    main()
