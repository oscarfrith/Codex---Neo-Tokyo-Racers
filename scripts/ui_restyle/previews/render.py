"""Render every HTML preview in a folder with headless Chrome.

  py -3 render.py regular                         all frames in previews/regular at 1920x1080
  py -3 render.py regular --only r01 r20          frames whose file name starts with r01 or r20
  py -3 render.py regular --sizes 1280x720 1920x1080 2560x1440
  py -3 render.py compact --sizes 844x390 --out <folder>
  py -3 render.py regular --png                   keep the PNGs (no JPG conversion)

Output: assets/ui/mockups/pulse_restyle/phase0/<folder>/<name>.jpg, with a _<W>x<H> suffix when
more than one size is asked for (or when --suffix is given). Chrome writes a PNG; the script
converts it to JPG quality 90 and deletes the PNG, because the gallery (index.html) links .jpg.
JPG is the default for the regular folder; other folders keep PNG unless --jpg is given.
A frame can pin its own sizes with
  <meta name="render-sizes" content="1280x720 1920x1080 2560x1440">
"""
import argparse, os, re, subprocess, sys, tempfile, shutil
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
JPG_QUALITY = 90
CHROME_CANDIDATES = [
    os.environ.get("CHROME", ""),
    r"C:/Program Files/Google/Chrome/Application/chrome.exe",
    r"C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
]


def chrome():
    for c in CHROME_CANDIDATES:
        if c and os.path.exists(c):
            return c
    sys.exit("Chrome not found; set the CHROME environment variable")


def to_jpg(png):
    from PIL import Image
    jpg = png[:-4] + ".jpg"
    with Image.open(png) as im:
        im.convert("RGB").save(jpg, "JPEG", quality=JPG_QUALITY, optimize=True)
    os.remove(png)
    return jpg


def render(html, out, w, h, jpg):
    prof = tempfile.mkdtemp(prefix="pulse_render_")
    try:
        if os.path.exists(out):
            os.remove(out)
        url = "file:///" + html.replace("\\", "/")
        cmd = [chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
               f"--user-data-dir={prof}", f"--window-size={w},{h}", "--virtual-time-budget=5000",
               f"--screenshot={out}", url]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    finally:
        shutil.rmtree(prof, ignore_errors=True)
    if not os.path.exists(out):
        return None
    return to_jpg(out) if jpg else out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--sizes", nargs="*", default=["1920x1080"])
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--out", default=None)
    ap.add_argument("--suffix", action="store_true")
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--jpg", action="store_true", help="convert to JPG quality 90 and delete the PNG (default for regular)")
    ap.add_argument("--png", action="store_true", help="keep PNG output")
    a = ap.parse_args()
    jpg = (a.jpg or a.folder == "regular") and not a.png
    src = os.path.join(HERE, a.folder)
    out_dir = a.out or os.path.join(REPO, "assets", "ui", "mockups", "pulse_restyle", "phase0", a.folder)
    os.makedirs(out_dir, exist_ok=True)
    jobs = []
    for f in sorted(os.listdir(src)):
        if not f.endswith(".html"):
            continue
        if a.only and not any(f.startswith(p) for p in a.only):
            continue
        path = os.path.join(src, f)
        with open(path, encoding="utf-8") as fh:
            m = re.search(r'<meta name="render-sizes" content="([^"]+)"', fh.read(4000))
        sizes = m.group(1).split() if m else a.sizes
        for s in sizes:
            w, h = (int(x) for x in s.lower().split("x"))
            name = f[:-5] + (f"_{w}x{h}" if (len(sizes) > 1 or a.suffix) else "") + ".png"
            jobs.append((path, os.path.join(out_dir, name), w, h, jpg))
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for res, job in zip(ex.map(lambda j: render(*j), jobs), jobs):
            shown = res or job[1]
            print("ok  " if res else "FAIL", os.path.relpath(shown, REPO))


if __name__ == "__main__":
    main()
