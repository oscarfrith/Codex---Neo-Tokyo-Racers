"""Render the Compact (phone) previews to PNG with headless Chrome at device scale 3.

  py -3 render_compact.py                  every frame at 844x390, plus c02, c05 and c12 at 640x360, 568x320, 932x430
  py -3 render_compact.py --only c07 c13   frames whose file name starts with one of these
  py -3 render_compact.py --all-sizes --out <dir>   every frame at all four sizes (layout check)

Output: assets/ui/mockups/pulse_restyle/phase0/compact/<frame>.png (844x390) and <frame>_<W>x<H>.png.
"""
import argparse, os, shutil, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
OUT = os.path.join(REPO, "assets", "ui", "mockups", "pulse_restyle", "phase0", "compact")
CHROME = os.environ.get("CHROME") or r"C:/Program Files/Google/Chrome/Application/chrome.exe"
REF = (844, 390)
EXTRA = [(640, 360), (568, 320), (932, 430)]
EXTRA_FRAMES = ("c02", "c05", "c12")


def render(job):
    html, out, w, h, dsf = job
    prof = tempfile.mkdtemp(prefix="pulse_compact_")
    try:
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={prof}",
                        f"--window-size={w + 160},{h + 260}", f"--force-device-scale-factor={dsf}", "--virtual-time-budget=4000",
                        f"--screenshot={out}", "file:///" + html.replace("\\", "/") + f"?w={w}&h={h}"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=180)
    finally:
        shutil.rmtree(prof, ignore_errors=True)
    if not os.path.exists(out):
        return False
    # headless Chrome's viewport is smaller than --window-size, so the window is oversized, the page
    # pins the device size from the query string, and the device rectangle is cropped out here.
    im = Image.open(out)
    im.crop((0, 0, round(w * dsf), round(h * dsf))).save(out)
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--all-sizes", action="store_true")
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--dsf", type=float, default=3)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    jobs = []
    for f in sorted(os.listdir(HERE)):
        if not f.endswith(".html") or (a.only and not any(f.startswith(p) for p in a.only)):
            continue
        path, stem = os.path.join(HERE, f), f[:-5]
        jobs.append((path, os.path.join(a.out, stem + ".png"), REF[0], REF[1], a.dsf))
        if a.all_sizes or stem.startswith(EXTRA_FRAMES):
            for w, h in EXTRA:
                jobs.append((path, os.path.join(a.out, f"{stem}_{w}x{h}.png"), w, h, a.dsf))
    with ThreadPoolExecutor(max_workers=4) as ex:
        for ok, job in zip(ex.map(render, jobs), jobs):
            print("ok  " if ok else "FAIL", os.path.basename(job[1]))


if __name__ == "__main__":
    main()
