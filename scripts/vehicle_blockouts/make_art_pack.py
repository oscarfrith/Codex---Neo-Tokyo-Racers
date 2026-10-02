"""Assemble the Exotic concept-art pack: an artist README and a review gallery page.

Usage: py -3 scripts/vehicle_blockouts/make_art_pack.py

Reads docs/design/vehicle-categories/exotic-art/combos.json, the part notes in
output/vehicle-categories-2026-10-01/exotic-art/parts_result.json and the generated images.
Writes docs/design/vehicle-categories/exotic-art/README.md (for the 3D artist) and
output/vehicle-categories-2026-10-01/exotic-art/gallery/ (index.html plus images, for review as an Artifact).
"""
import html
import json
import os
import shutil

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
DOC = os.path.join(REPO, "docs", "design", "vehicle-categories", "exotic-art")
ART = os.path.join(REPO, "output", "vehicle-categories-2026-10-01", "exotic-art")
GAL = os.path.join(ART, "gallery")
SLOTS = ["FrontBody", "RearBody", "SidePods", "Engine1", "Engine2", "Stabilisers", "Boost", "FrontBumper", "RearBumper", "RearSpoiler"]
UNIT = {"Engine2": "Mirrored pair. One unit shown.", "Stabilisers": "Four units, one per arch. One unit shown.", "SidePods": "Mirrored pair. One unit shown."}
FUND = {"Engine1", "Engine2", "Stabilisers", "Boost"}


def esc(s):
    return html.escape(str(s), quote=True)


def src_for(pid):
    if pid.startswith("cockpit_"):
        return pid + "__front.png"
    kit, slot = pid.split("_", 1)
    return "module_%s_%s%s.png" % (kit, slot, "__unit" if slot in UNIT else "")


def jpg(src, dst, width):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im = Image.open(src).convert("RGB")
    if im.width > width:
        im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    im.save(dst, "JPEG", quality=84, optimize=True)


def main():
    cfg = json.load(open(os.path.join(DOC, "combos.json"), encoding="utf-8"))
    notes = {r["id"]: r for r in json.load(open(os.path.join(ART, "parts_result.json"), encoding="utf-8"))}
    # Empty the folder rather than removing it: a shell or the app may be holding it open.
    os.makedirs(GAL, exist_ok=True)
    for name in os.listdir(GAL):
        p = os.path.join(GAL, name)
        shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    files = []

    def add(rel, src, width):
        jpg(src, os.path.join(GAL, rel), width)
        files.append(rel)
        return rel

    def part_card(pid, label):
        concept = add("parts/%s.jpg" % pid, os.path.join(ART, "parts", pid + ".png"), 1100)
        block = add("src/%s.jpg" % pid, os.path.join(ART, "src", src_for(pid)), 700)
        slot = pid.split("_", 1)[1] if not pid.startswith("cockpit_") else "Cockpit"
        unit = UNIT.get(slot, "")
        tag = '<span class="tag fund">fundamental</span>' if slot in FUND else ""
        return ('<article class="part"><header><p class="slot mono">%s %s</p><h3>%s</h3></header>'
                '<button class="zoom" data-src="%s" aria-label="Enlarge"><img loading="lazy" src="%s" alt="%s concept art"></button>'
                '<div class="pair"><button class="zoom" data-src="%s" aria-label="Enlarge blockout"><img loading="lazy" src="%s" alt="%s blockout screenshot"></button>'
                '<p class="note">%s%s</p></div></article>') % (
            esc(label), tag, esc(cfg["names"][pid]), concept, concept, esc(cfg["names"][pid]), block, block, esc(cfg["names"][pid]),
            ("<strong>%s</strong> " % esc(unit)) if unit else "", esc(notes[pid]["artist_note"]))

    md = ["# Exotic concept art pack: Wedge and Hyper (batch 1)", "",
          "Status: design exploration, 2026-10-02. Not approved, not game content. For review, then for a 3D artist.", "",
          "How it was made, the colour code and the rules are in [BRIEF.md](BRIEF.md). Every image was generated from a blockout screenshot taken in Roblox Studio, so the camera, proportions and layout are the blockout's; only the surface design is new.", "",
          "## How to read these", "",
          "- **One view per part:** a near-orthographic three-quarter view. Front parts are seen from the front, rear parts and jets from the rear.",
          "- **Colours are paint channels:** red is Primary (body), silver is Secondary (accent), graphite is Detail, dark glass is Glass, cyan-white glow is Neon and Thrust. In game the player recolours them.",
          "- **Take sizes and mounting faces from the blockout,** not from the art. The art shows the surface design. Each part's blockout screenshot is shown under its art.",
          "- **Flat faces matter.** Where a note says a face must stay flat, another part bolts on there.", ""]

    sections = []
    cards = "".join(part_card("cockpit_" + c, "Cabin") for c in ("wedge", "hyper"))
    sections.append('<section id="cockpits"><h2>Cockpits</h2><p class="lede">The cabin owns all the glass and the roofline. Its front, rear and side faces are flat so any nose, engine deck and side pod can bolt on.</p><div class="parts two">%s</div></section>' % cards)
    md += ["## Cockpits", ""]
    for c in ("wedge", "hyper"):
        pid = "cockpit_" + c
        md += ["### %s" % cfg["names"][pid], "", "![%s](parts/%s.jpg)" % (cfg["names"][pid], pid), "",
               "Blockout: ![%s blockout](blockouts/%s.jpg)" % (cfg["names"][pid], pid), "", notes[pid]["artist_note"], ""]
    for kit, title in (("wedge", "Wedge kit"), ("hyper", "Hyper kit")):
        cards = "".join(part_card("%s_%s" % (kit, s), cfg["slots"][s]) for s in SLOTS)
        sections.append('<section id="%s"><h2>%s modules</h2><p class="lede">Each module on its own, with its Studio blockout and a note for the modeller.</p><div class="parts">%s</div></section>' % (kit, esc(title), cards))
        md += ["## %s modules" % title, ""]
        for s in SLOTS:
            pid = "%s_%s" % (kit, s)
            md += ["### %s: %s" % (cfg["slots"][s], cfg["names"][pid]), "", "![%s](parts/%s.jpg)" % (cfg["names"][pid], pid), "",
                   "Blockout: ![%s blockout](blockouts/%s.jpg)" % (cfg["names"][pid], pid), "",
                   (UNIT[s] + " " if s in UNIT else "") + notes[pid]["artist_note"], ""]

    combo_html = []
    md += ["## Combinations", "", "The same parts assembled. Each vehicle was drawn from its blockout screenshot plus a sheet of the part images above.", ""]
    for c in cfg["combos"]:
        cid = c["id"]
        front = os.path.join(ART, "combos", cid + "__front.png")
        rear = os.path.join(ART, "combos", cid + "__rear.png")
        if not (os.path.exists(front) and os.path.exists(rear)):
            print("skipping %s: images missing" % cid)
            continue
        f = add("combos/%s__front.jpg" % cid, front, 1400)
        r = add("combos/%s__rear.jpg" % cid, rear, 1400)
        bf = add("src/%s__front.jpg" % cid, os.path.join(ART, "src", cid + "__front.png"), 800)
        br = add("src/%s__rear.jpg" % cid, os.path.join(ART, "src", cid + "__rear.png"), 800)
        sh = add("sheets/%s.jpg" % cid, os.path.join(ART, "sheets", cid + ".png"), 1600)
        parts = ", ".join("%s: %s" % (cfg["slots"][s], cfg["names"]["%s_%s" % (c["parts"][s], s)]) for s in SLOTS)
        combo_html.append(
            '<article class="combo" id="%s"><header><p class="slot mono">%s</p><h3>%s</h3><p class="note">%s</p></header>'
            '<div class="views"><figure><button class="zoom" data-src="%s"><img loading="lazy" src="%s" alt="%s, front concept"></button><figcaption>Front three-quarter</figcaption></figure>'
            '<figure><button class="zoom" data-src="%s"><img loading="lazy" src="%s" alt="%s, rear concept"></button><figcaption>Rear three-quarter</figcaption></figure></div>'
            '<div class="refs"><figure><button class="zoom" data-src="%s"><img loading="lazy" src="%s" alt="front blockout"></button><figcaption>Studio blockout, front</figcaption></figure>'
            '<figure><button class="zoom" data-src="%s"><img loading="lazy" src="%s" alt="rear blockout"></button><figcaption>Studio blockout, rear</figcaption></figure>'
            '<figure><button class="zoom" data-src="%s"><img loading="lazy" src="%s" alt="parts sheet"></button><figcaption>Parts sheet used as reference</figcaption></figure></div></article>' % (
                cid, esc(c["kind"]), esc(c["title"]), esc(parts), f, f, esc(c["title"]), r, r, esc(c["title"]), bf, bf, br, br, sh, sh))
        md += ["### %s (%s)" % (c["title"], c["kind"]), "", parts + ".", "",
               "![%s, front](combos/%s__front.jpg)" % (c["title"], cid), "", "![%s, rear](combos/%s__rear.jpg)" % (c["title"], cid), "",
               "Blockouts: ![front blockout](blockouts/%s__front.jpg) ![rear blockout](blockouts/%s__rear.jpg)" % (cid, cid), ""]
    sections.append('<section id="combos"><h2>Combinations</h2><p class="lede">The same parts assembled: each cockpit in its own kit, each cockpit in the other kit, and four mixes. Compare each vehicle with its parts sheet.</p>%s</section>' % "".join(combo_html))

    # The pack in docs carries its own copy of the blockout screenshots, so it stands alone.
    os.makedirs(os.path.join(DOC, "blockouts"), exist_ok=True)
    for rel in files:
        if rel.startswith("src/"):
            shutil.copyfile(os.path.join(GAL, rel), os.path.join(DOC, "blockouts", rel[4:]))
    open(os.path.join(DOC, "README.md"), "w", encoding="utf-8", newline="\n").write("\n".join(md))
    open(os.path.join(GAL, "index.html"), "w", encoding="utf-8").write(TEMPLATE.replace("{{SECTIONS}}", "\n".join(sections)))
    json.dump([{"path": p} for p in files], open(os.path.join(GAL, "files.json"), "w"))
    total = sum(os.path.getsize(os.path.join(GAL, p)) for p in files)
    print("pack: %d images, %.1f MB, %d combinations -> %s" % (len(files), total / 1e6, len(combo_html), GAL))


TEMPLATE = """<title>Exotic Art Pack</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Saira+Condensed:wght@600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: a parts catalogue. Each part is a card: big concept image, then its blockout beside the modeller's note. Then the assembled vehicles. */
:root {
  color-scheme: dark;
  --bg: #090C10; --panel: #0F1318; --soft: #181D24; --line: #2A313B;
  --pink: #F42E97; --cyan: #2BE1DA; --text: #F6F8FC; --muted: #A3ABB8;
  --display: "Saira Condensed", "Arial Narrow", "Helvetica Neue", sans-serif;
  --body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Consolas, monospace;
}
body { background: var(--bg); color: var(--text); font-family: var(--body); font-size: 16px; line-height: 1.55; }
.wrap { max-width: 1240px; margin: 0 auto; padding-inline: 20px; padding-block: 28px 80px; display: flex; flex-direction: column; gap: 52px; }
.mono { font-family: var(--mono); font-size: 0.78rem; letter-spacing: 0.06em; text-transform: uppercase; }
h1, h2, h3 { font-family: var(--display); font-weight: 700; text-transform: uppercase; letter-spacing: 0.02em; line-height: 1.05; margin: 0; text-wrap: balance; }
h1 { font-size: clamp(2.6rem, 7vw, 4.4rem); }
h2 { font-size: clamp(2rem, 5vw, 3rem); border-left: 4px solid var(--pink); padding-left: 14px; }
h3 { font-size: 1.5rem; }
p { margin: 0; max-width: 70ch; }
a { color: var(--cyan); }
button:focus-visible, a:focus-visible { outline: 2px solid var(--cyan); outline-offset: 3px; }
.top { display: flex; flex-direction: column; gap: 16px; border-bottom: 2px solid var(--pink); padding-bottom: 26px; }
.status { color: var(--pink); }
.lede { color: var(--muted); font-size: 1.05rem; }
.key { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: 8px 18px; font-size: 0.9rem; color: var(--muted); }
.key li { display: flex; align-items: center; gap: 8px; }
.sw { width: 14px; height: 14px; display: inline-block; border: 1px solid var(--line); }
nav { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--bg); border-bottom: 1px solid var(--line); margin-inline: -20px; padding: 10px 20px; display: flex; gap: 8px; overflow-x: auto; }
nav a { font-family: var(--display); font-weight: 600; font-size: 1.05rem; text-transform: uppercase; color: var(--muted); text-decoration: none; padding: 4px 12px; border: 1px solid var(--line); white-space: nowrap; }
nav a:hover { color: var(--bg); background: var(--cyan); border-color: var(--cyan); }
section { display: flex; flex-direction: column; gap: 18px; scroll-margin-top: 64px; }
.parts { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 22px; }
.parts.two { grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); }
.part { background: var(--panel); border: 1px solid var(--line); padding: 14px; display: flex; flex-direction: column; gap: 10px; min-width: 0; }
.slot { color: var(--cyan); display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.tag { border: 1px solid var(--line); padding: 1px 6px; color: var(--muted); }
.tag.fund { border-color: var(--cyan); color: var(--cyan); }
.zoom { all: unset; cursor: zoom-in; display: block; }
img { display: block; width: 100%; height: auto; background: var(--soft); }
.pair { display: grid; grid-template-columns: 120px 1fr; gap: 12px; align-items: start; }
.note { font-size: 0.86rem; color: var(--muted); max-width: none; }
.note strong { color: var(--text); font-weight: 600; }
.combo { background: var(--panel); border: 1px solid var(--line); padding: 16px; display: flex; flex-direction: column; gap: 14px; scroll-margin-top: 64px; }
.combo header { display: flex; flex-direction: column; gap: 6px; }
.views { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 14px; }
.refs { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; }
figure { margin: 0; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
figcaption { font-size: 0.8rem; color: var(--muted); }
#lightbox { position: fixed; inset: 0; background: rgba(9, 12, 16, 0.95); display: flex; align-items: center; justify-content: center; padding: 16px; z-index: 20; cursor: zoom-out; }
#lightbox[hidden] { display: none; }
#lightbox img { max-width: 100%; max-height: 100%; width: auto; background: none; }
.end { border-top: 1px solid var(--line); padding-top: 22px; display: flex; flex-direction: column; gap: 10px; color: var(--muted); }
.end ul { margin: 0; padding-left: 1.2em; display: flex; flex-direction: column; gap: 6px; max-width: 72ch; }
.end strong { color: var(--text); }
</style>
<div class="wrap">
  <header class="top">
    <p class="status mono">Concept art for review · batch 1 · 2 October 2026</p>
    <h1>Exotic art pack</h1>
    <p class="lede">Two cockpits (Wedge and Hyper), their twenty modules, and eight assembled vehicles. Every image was generated from a screenshot of the Studio blockout, so the camera, proportions and layout are fixed and only the surface design is new. Assembled vehicles were drawn from the part images, so a part should look the same wherever it appears.</p>
    <ul class="key" aria-label="Colour code">
      <li><span class="sw" style="background:#c8102e"></span>Body paint (Primary)</li>
      <li><span class="sw" style="background:#c9ced6"></span>Accent (Secondary)</li>
      <li><span class="sw" style="background:#23262b"></span>Mechanical detail</li>
      <li><span class="sw" style="background:#1f2630"></span>Glass</li>
      <li><span class="sw" style="background:#7fe9ff"></span>Lamps and jet thrust</li>
    </ul>
  </header>
  <nav aria-label="Sections"><a href="#cockpits">Cockpits</a><a href="#wedge">Wedge kit</a><a href="#hyper">Hyper kit</a><a href="#combos">Combinations</a></nav>
  {{SECTIONS}}
  <footer class="end">
    <h3>What to check</h3>
    <ul>
      <li><strong>Consistency:</strong> does each part in an assembled vehicle match its own image?</li>
      <li><strong>Style:</strong> is this the right level of detail and finish for the game?</li>
      <li><strong>Swaps:</strong> do the kit swaps and mixes still look like one deliberate car?</li>
    </ul>
    <p>Artist pack and brief: docs/design/vehicle-categories/exotic-art/ in the repo.</p>
  </footer>
</div>
<div id="lightbox" hidden><img alt=""></div>
<script>
  const box = document.getElementById('lightbox');
  const big = box.querySelector('img');
  document.addEventListener('click', (e) => {
    const b = e.target.closest('.zoom');
    if (b) { big.src = b.dataset.src; box.hidden = false; return; }
    if (!box.hidden) box.hidden = true;
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') box.hidden = true; });
</script>
"""

if __name__ == "__main__":
    main()
