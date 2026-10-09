"""Render the Compact (phone) previews with headless Chrome at device scale 3.

  py -3 render_compact.py                  every frame at 844x390, plus c02, c05 and c12 at 932x430, 640x360, 568x320
  py -3 render_compact.py --only c07 c13   frames whose file name starts with one of these
  py -3 render_compact.py --all-sizes --out <dir>   every frame at all four sizes (layout check)
  py -3 render_compact.py --debug --out <dir>       paint the measured UI rectangles over each frame

Each frame is captured as PNG, saved as JPG quality 90 and the PNG is deleted.
Output: assets/ui/mockups/pulse_restyle/phase0/compact/<frame>.jpg (844x390) and <frame>_<W>x<H>.jpg.
The page measures its own UI coverage (compact.js, C.measure); the numbers are read back with
--dump-dom and written to coverage.json next to this file. build_index.py turns them into captions.
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
OUT = os.path.join(REPO, "assets", "ui", "mockups", "pulse_restyle", "phase0", "compact")
CHROME = os.environ.get("CHROME") or r"C:/Program Files/Google/Chrome/Application/chrome.exe"
REF = (844, 390)
EXTRA = [(932, 430), (640, 360), (568, 320)]
EXTRA_FRAMES = ("c02", "c05", "c12")
SHEETS = {"c20": (844, 1010)}   # annotated sheets, not device frames: own canvas size, no coverage figure


def chrome(args, prof):
    return subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={prof}",
                           "--virtual-time-budget=5000"] + args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=180)


def render(job):
    html, out, w, h, dsf, debug, src = job
    url = "file:///" + html.replace("\\", "/") + f"?w={w}&h={h}" + ("&debug=1" if debug else "")
    png = out[:-4] + ".png"
    prof = tempfile.mkdtemp(prefix="pulse_compact_")
    cov = None
    try:
        # headless Chrome's viewport is smaller than --window-size, so the window is oversized, the page
        # pins the device size from the query string, and the device rectangle is cropped out below.
        size = f"--window-size={w + 160},{h + 260}"
        chrome([size, f"--force-device-scale-factor={dsf}", f"--screenshot={png}", url], prof)
        dom = chrome([size, "--dump-dom", url], prof).stdout.decode("utf-8", "replace")
        m = re.search(r'data-cov="([^"]+)"', dom)
        if m:
            cov = json.loads(m.group(1).replace("&quot;", '"'))
    finally:
        shutil.rmtree(prof, ignore_errors=True)
    if not os.path.exists(png):
        return False, cov
    im = Image.open(png).convert("RGB")
    im.crop((0, 0, round(w * dsf), round(h * dsf))).save(out, quality=90)
    os.remove(png)
    return True, cov


def main():
    sys.stdout.reconfigure(errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--all-sizes", action="store_true")
    ap.add_argument("--debug", action="store_true")
    ap.add_argument("--src", default=HERE, help="folder holding the frame .html files")
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--dsf", type=float, default=3)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    jobs = []
    for f in sorted(os.listdir(a.src)):
        if not f.endswith(".html") or (a.only and not any(f.startswith(p) for p in a.only)):
            continue
        path, stem = os.path.join(a.src, f), f[:-5]
        w0, h0 = SHEETS.get(stem[:3], REF)
        jobs.append((path, os.path.join(a.out, stem + ".jpg"), w0, h0, a.dsf, a.debug, a.src))
        if stem[:3] in SHEETS:
            continue
        if a.all_sizes or stem.startswith(EXTRA_FRAMES):
            for w, h in EXTRA:
                jobs.append((path, os.path.join(a.out, f"{stem}_{w}x{h}.jpg"), w, h, a.dsf, a.debug, a.src))
    covfile = os.path.join(a.src if a.src != HERE else HERE, "coverage.json")
    allcov = json.load(open(covfile, encoding="utf-8")) if os.path.exists(covfile) else {}
    with ThreadPoolExecutor(max_workers=4) as ex:
        for (ok, cov), job in zip(ex.map(render, jobs), jobs):
            name = os.path.basename(job[1])[:-4]
            if cov:
                allcov[name] = cov
            print("ok  " if ok else "FAIL", name, (f"UI {cov['ui']}%  centre {cov['centre']}%  min TextSize {cov['minTextSize']} ({cov['minText']})" if cov else "no coverage"))
    if not a.debug:
        json.dump(dict(sorted(allcov.items())), open(covfile, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
