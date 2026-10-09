"""Shared helpers for the Pulse UI asset generators.

Everything here is offline: Chrome (headless) rasterises HTML/SVG, PIL does the
alpha bleed and measuring. Nothing is uploaded and Studio is never touched.
"""
import os, subprocess, tempfile, shutil, json
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
BUILD = os.path.join(HERE, "build")          # intermediate HTML (kept so sources are inspectable)
CHROME = os.environ.get("PULSE_CHROME", "C:/Program Files/Google/Chrome/Application/chrome.exe")

FONT_LINK = ('<link href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:ital,wght@1,600;1,800'
             '&family=Barlow:ital,wght@0,800;1,600;1,800;1,900&display=block" rel="stylesheet">')

# Style sheet colour roles (docs/design/pulse-racers-ui-style-sheet.md)
ROLES = {
    "Slate": (14, 13, 26), "White": (243, 240, 255), "Ink": (7, 6, 13), "Pink": (255, 45, 149),
    "Violet": (154, 61, 255), "Cyan": (34, 228, 255), "Yellow": (255, 228, 51),
    "TextMuted": (185, 179, 214),
}

os.makedirs(OUT, exist_ok=True)
os.makedirs(BUILD, exist_ok=True)


def page(body, w, h, css=""):
    return ("<!doctype html><html><head><meta charset='utf-8'>" + FONT_LINK +
            "<style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}"
            "body{width:%dpx;height:%dpx;position:relative}%s</style></head><body>%s</body></html>"
            % (w, h, css, body))


def render_file(src, w, h, png, background="00000000"):
    """Rasterise an HTML file with headless Chrome into `png`. Returns an RGBA PIL image."""
    if os.path.exists(png):
        os.remove(png)
    prof = tempfile.mkdtemp(prefix="pulse_chrome_")
    try:
        cmd = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
               "--force-device-scale-factor=1", "--default-background-color=" + background,
               "--user-data-dir=" + prof, "--window-size=%d,%d" % (w, h),
               "--virtual-time-budget=4000", "--screenshot=" + png,
               "file:///" + src.replace("\\", "/")]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=240)
    finally:
        shutil.rmtree(prof, ignore_errors=True)
    im = Image.open(png).convert("RGBA")
    im.load()
    if im.size != (w, h):
        im = im.crop((0, 0, w, h))
    return im


def render_html(html, w, h, name, background="00000000"):
    """Rasterise an HTML string (kept in build/ so the source stays inspectable)."""
    src = os.path.join(BUILD, name + ".html")
    with open(src, "w", encoding="utf-8") as f:
        f.write(html)
    return render_file(src, w, h, os.path.join(BUILD, name + ".raw.png"), background)


def bleed_white(im):
    """Alpha bleed for pure-white art: every pixel's RGB becomes white, alpha is kept.
    Bilinear filtering then never pulls a dark fringe from transparent texels."""
    a = im.getchannel("A")
    out = Image.new("RGBA", im.size, (255, 255, 255, 0))
    out.putalpha(a)
    return out


def white_from_alpha(alpha):
    out = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def save(im, name):
    p = os.path.join(OUT, name)
    im.save(p, optimize=True)
    return p


def write_json(obj, name, folder=OUT):
    p = os.path.join(folder, name)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")
    return p
