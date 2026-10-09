"""Render every HTML preview in a folder to PNG with headless Chrome.

  py -3 render.py regular                         all frames in previews/regular at 1920x1080
  py -3 render.py regular --only r01 r20          frames whose file name starts with r01 or r20
  py -3 render.py regular --sizes 1280x720 1920x1080 2560x1440
  py -3 render.py compact --sizes 844x390 --out <folder>

Output: assets/ui/mockups/pulse_restyle/phase0/<folder>/<name>.png, with a _<W>x<H> suffix when
more than one size is asked for (or when --suffix is given). A frame can pin its own sizes with
  <meta name="render-sizes" content="1280x720 1920x1080 2560x1440">
"""
import argparse, os, re, subprocess, sys, tempfile, shutil
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
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


def render(html, out, w, h):
    prof = tempfile.mkdtemp(prefix="pulse_render_")
    try:
        url = "file:///" + html.replace("\\", "/")
        cmd = [chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
               f"--user-data-dir={prof}", f"--window-size={w},{h}", "--virtual-time-budget=5000",
               f"--screenshot={out}", url]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    finally:
        shutil.rmtree(prof, ignore_errors=True)
    return out if os.path.exists(out) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--sizes", nargs="*", default=["1920x1080"])
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--out", default=None)
    ap.add_argument("--suffix", action="store_true")
    ap.add_argument("--jobs", type=int, default=4)
    a = ap.parse_args()
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
            jobs.append((path, os.path.join(out_dir, name), w, h))
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for res, job in zip(ex.map(lambda j: render(*j), jobs), jobs):
            print("ok  " if res else "FAIL", os.path.relpath(job[1], REPO))


if __name__ == "__main__":
    main()
