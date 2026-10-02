"""Build the frame-class gallery page from the class sheets, concept images and blockout previews.

Usage: py -3 scripts/vehicle_blockouts/make_gallery.py
Writes output/vehicle-categories-2026-10-01/gallery/index.html plus gallery/files.json, a map of
published path -> repo-relative source used when publishing the page as an Artifact.
"""
import html
import json
import os
import re
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import vbspec  # noqa: E402

OUT = os.path.join(REPO, "output", "vehicle-categories-2026-10-01", "gallery")
IMG = os.path.join(REPO, "docs", "design", "vehicle-categories", "img")
SHEETS = os.path.join(REPO, "docs", "design", "vehicle-categories")
PREV = os.path.join(HERE, "previews")
SHOTS = os.path.join(REPO, "output", "vehicle-categories-2026-10-01", "studio")

CLASSES = [
    ("rift", "Rift", "Classic coupé bodies sliced into floating sections.",
     ["Muscle", "Pony", "Pro Street", "Euro GT", "Wedge Exotic", "Roadster"],
     "Top speed, boost, long drifts", "Weight, tight turns"),
    ("muscle", "Muscle", "American muscle and pony cars as one-piece hover jets.",
     ["Classic Muscle", "Pony", "Modern Muscle", "Pro Street", "Restomod", "Trans-Am"],
     "Acceleration, boost, straight-line speed", "Braking, tight turns"),
    ("exotic", "Exotic", "Mid-engined supercars and hypercars as hover jets.",
     ["Wedge", "Analogue", "Hypercar", "Track Special", "Longtail"],
     "Top speed, grip, braking", "Contact, rough streets"),
    ("gt", "GT", "Front-engined sports cars and grand tourers as hover jets.",
     ["Classic GT", "Rear-Engine Sports", "Modern GT", "GT3 Racer", "Roadster", "Shooting Brake"],
     "Balance, stability at speed, steering", "No single standout stat"),
    ("street", "Street", "Tuner bodies with clip-on aero.",
     ["Drift", "Time Attack", "Underground", "Touge", "Rally", "Kanjo"],
     "Drift control, steering, agility", "Top speed, contact"),
    ("rodder", "Rodder", "Chopped cabs, exposed engines and long jet barrels. Hot rods and drag rails in one class.",
     ["Highboy", "Rat Rod", "T-Bucket", "Gasser", "Slingshot Drag", "Salt Flat"],
     "Acceleration, boost force", "Sideways grip, braking"),
    ("rider", "Rider", "Jet hoverbikes. The rider sits astride and is always visible.",
     ["Supersport", "Café Racer", "Chopper", "Motocross", "Streetfighter", "Speeder"],
     "Steering, squeezing through gaps", "Contact, stability"),
    ("apex", "Apex", "Circuit racers: a central tub, outboard thruster pods and serious aero.",
     ["Formula", "Vintage Grand Prix", "Prototype", "Wing Car", "Speedway Sprint"],
     "Grip, braking, downforce", "Drift, contact"),
    ("cruiser", "Cruiser", "Long, low land yachts: lowriders, lead sleds, fin-era chrome and VIP saloons.",
     ["Lowrider", "Lead Sled", "Fin Era", "VIP", "Kaido Racer"],
     "Stability, straight-line speed", "Steering, acceleration"),
    ("hauler", "Hauler", "Trucks and vans: prerunners, minitrucks, show trucks and hover-cabs.",
     ["Prerunner", "Lifted", "Minitruck", "Show Truck", "Courier", "Cab"],
     "Contact, stability, boost torque", "Steering, top speed"),
    ("dart", "Dart", "Anti-grav darts: one slender fuselage, forward prongs and airbrakes.",
     ["Works Team", "Privateer", "Prototype", "Salvage"],
     "Top speed, airbrake turns", "Low-speed handling"),
    ("tether", "Tether", "Pod racers: a small pod towed by two huge engines.",
     ["Scrapyard", "Works", "Desert", "Showboat"],
     "Extreme speed and boost", "Width, stability, tight streets"),
]

RULES = [
    ("Jets, not wheels", "Lift and thrust come from turbines, lift jets and afterburners. No wheels, rings, discs or rotors."),
    ("Engines, stabilisers, boost", "Every vehicle carries all four fundamental modules as visible jet hardware, each with several clearly different options."),
    ("Envelopes", "Every cockpit stays inside one box and every part inside its slot's box. Boxes never overlap, so nothing can clip."),
    ("Pads and contact", "Parts land on fixed flat pads that every cockpit carries, and must sit within 0.6 studs of every possible parent. No floating parts."),
    ("Signature kits", "Each cockpit has its own kit. Any cockpit can wear any other cockpit's kit, and kits must look clearly different."),
    ("Paint unifies", "Your paint recolours every part, so a mixed build still reads as one vehicle."),
]


def esc(s):
    return html.escape(str(s), quote=True)


def to_jpg(src, dst, width):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im = Image.open(src).convert("RGB")
    if im.width > width:
        im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    im.save(dst, "JPEG", quality=84, optimize=True)


def captions_from_sheet(cid):
    path = os.path.join(SHEETS, cid + ".md")
    caps = {}
    if not os.path.exists(path):
        return caps
    text = open(path, encoding="utf-8").read()
    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = re.search(r"!\[(.*?)\]\((?:\./)?img/%s/([^)]+)\)" % cid, line)
        if not m:
            continue
        cap = m.group(1).strip()
        after = line[m.end():].strip(" -:|")
        if len(after) > len(cap):
            cap = after
        if len(cap) < 25:
            for nxt in lines[i + 1:i + 3]:
                n = nxt.strip().strip("*_")
                if n and not n.startswith("!") and not n.startswith("#") and not n.startswith("|"):
                    cap = n
                    break
        caps[m.group(2)] = re.sub(r"[*_`]", "", cap)
    return caps


def main():
    os.makedirs(OUT, exist_ok=True)
    shutil.rmtree(os.path.join(OUT, "blockout"), ignore_errors=True)
    files = {}
    sections, nav = [], []
    for cid, name, pitch, cultures, strong, weak in CLASSES:
        spec_path = os.path.join(HERE, "specs", cid + ".json")
        spec = vbspec.load(spec_path) if os.path.exists(spec_path) else None
        imgs = sorted(f for f in os.listdir(os.path.join(IMG, cid)) if f.endswith(".jpg")) if os.path.isdir(os.path.join(IMG, cid)) else []
        caps = captions_from_sheet(cid)
        for f in imgs:
            files["img/%s/%s" % (cid, f)] = os.path.relpath(os.path.join(IMG, cid, f), REPO).replace("\\", "/")
        nav.append('<a href="#%s">%s</a>' % (cid, esc(name)))

        slot_rows = ""
        counts = ""
        if spec:
            slots = spec["standard"]["slots"]
            for sid in vbspec.ALL_SLOTS:
                if sid not in slots:
                    continue
                mods = ", ".join(esc(m["name"]) for m in spec["modules"].get(sid, {}).values())
                slot_rows += '<tr class="%s"><td><span class="sw" style="background:%s"></span>%s</td><td class="mono">%s</td><td>%s</td></tr>' % (
                    "fund" if sid in vbspec.FUNDAMENTAL else "", vbspec.SLOT_COLOURS.get(sid, "#888"), esc(slots[sid]["label"]), sid, mods)
            cockpits = ", ".join(esc(c["name"]) for c in spec["cockpits"].values())
            kit_txt = "; ".join("%s (%s) on %s" % (esc(k["name"]), esc(k.get("culture", "")), esc(spec["cockpits"][c]["name"]))
                                for c in spec["cockpits"] for kid, k in spec.get("kits", {}).items() if spec["cockpits"][c].get("kit") == kid)
            counts = '<p class="meta">Blockout: %d cockpits, %d signature kits, %d parts across %d slots. Kits: %s.</p>' % (
                len(spec["cockpits"]), len(spec.get("kits", {})), sum(len(m) for m in spec["modules"].values()), len(slots), kit_txt)

        figs = ""
        for i, f in enumerate(imgs):
            cap = caps.get(f, f[3:-4].replace("-", " ").capitalize())
            figs += '<figure class="%s"><button class="zoom" data-src="img/%s/%s" aria-label="Enlarge image"><img loading="%s" src="img/%s/%s" alt="%s"></button><figcaption>%s</figcaption></figure>' % (
                "hero" if i == 0 else "", cid, f, "eager" if i == 0 else "lazy", cid, f, esc(cap), esc(cap))

        blocks = ""
        for stem, title, width in (("matrix", "Interchange matrix: every cockpit (rows) wearing every signature kit (columns)", 1700),
                                   ("fundamentals", "Engine, stabiliser and boost options, each highlighted on one cockpit", 1700),
                                   ("exploded", "Exploded build, one colour per slot", 1500),
                                   ("sheet", "Native, swapped and mixed builds", 1600),
                                   ("standard", "Frame standard: the slot envelopes", 1300)):
            src = os.path.join(PREV, cid, stem + ".png")
            if os.path.exists(src):
                rel = "blockout/%s/%s.jpg" % (cid, stem)
                to_jpg(src, os.path.join(OUT, rel), width)
                files[rel] = os.path.relpath(os.path.join(OUT, rel), REPO).replace("\\", "/")
                blocks += '<figure class="wide"><button class="zoom" data-src="%s" aria-label="Enlarge image"><img loading="lazy" src="%s" alt="%s"></button><figcaption>%s</figcaption></figure>' % (rel, rel, esc(title), esc(title))

        sections.append("""
<section class="class" id="{cid}">
  <header class="class-head">
    <p class="eyebrow mono">CategoryId {cid}</p>
    <h2>{name}</h2>
    <p class="pitch">{pitch}</p>
    <ul class="tags">{tags}</ul>
    <dl class="feel"><div><dt>Strong</dt><dd>{strong}</dd></div><div><dt>Weak</dt><dd>{weak}</dd></div></dl>
  </header>
  <div class="gallery">{figs}</div>
  {slots}
  {counts}
  <div class="blockout">{blocks}</div>
</section>""".format(cid=cid, name=esc(name), pitch=esc(pitch), tags="".join("<li>%s</li>" % esc(c) for c in cultures),
                     strong=esc(strong), weak=esc(weak), figs=figs,
                     slots=('<div class="scroll"><table><thead><tr><th>Player label</th><th>Slot ID</th><th>Options in the blockout</th></tr></thead><tbody>%s</tbody></table></div>' % slot_rows) if slot_rows else "",
                     counts=counts, blocks=blocks))

    overview = ""
    ov = os.path.join(SHOTS, "_overview.jpg")
    if os.path.exists(ov):
        to_jpg(ov, os.path.join(OUT, "blockout", "overview.jpg"), 1600)
        files["blockout/overview.jpg"] = os.path.relpath(os.path.join(OUT, "blockout", "overview.jpg"), REPO).replace("\\", "/")
        overview = ('<figure class="wide"><button class="zoom" data-src="blockout/overview.jpg" aria-label="Enlarge image"><img src="blockout/overview.jpg" alt="Blockout showroom in Roblox Studio"></button>'
                    '<figcaption>The blockout showroom in the backup place: one interchange matrix per class, with the existing Piercer in the foreground for scale. This Studio copy predates the review fixes; the grey-box images below are current. Workspace.VehicleCategoryBlockouts.</figcaption></figure>')
    overview = ""
    ov = os.path.join(SHOTS, "_overview.jpg")
    if os.path.exists(ov):
        to_jpg(ov, os.path.join(OUT, "blockout", "overview.jpg"), 1600)
        files["blockout/overview.jpg"] = os.path.relpath(os.path.join(OUT, "blockout", "overview.jpg"), REPO).replace(os.sep, "/")
        overview = ('<figure class="wide"><button class="zoom" data-src="blockout/overview.jpg" aria-label="Enlarge image"><img src="blockout/overview.jpg" alt="Blockout showroom in Roblox Studio"></button>'
                    '<figcaption>The blockout showroom in the backup place: one interchange matrix per class, with the existing Piercer in the foreground for scale. This Studio copy predates the review fixes; the grey-box images below are current. Workspace.VehicleCategoryBlockouts.</figcaption></figure>')
    rules = "".join("<li><strong>%s.</strong> %s</li>" % (esc(a), esc(b)) for a, b in RULES)
    page = TEMPLATE.replace("{{NAV}}", "".join(nav)).replace("{{RULES}}", rules).replace("{{SECTIONS}}", "\n".join(sections)).replace("{{OVERVIEW}}", overview)
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
        f.write(page)
    with open(os.path.join(OUT, "files.json"), "w", encoding="utf-8") as f:
        json.dump(files, f, indent=1)
    total = sum(os.path.getsize(os.path.join(REPO, p)) for p in files.values())
    print("gallery: %d classes, %d files, %.1f MB -> %s" % (len(CLASSES), len(files), total / 1e6, OUT))


TEMPLATE = """<title>Space Racers Frame Classes</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Saira+Condensed:wght@600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: one long garage wall. Each class is a bay: a spec plate, a hero shot, a contact strip, then the blockout evidence. */
:root {
  color-scheme: dark;
  --bg: #090C10; --panel: #0F1318; --soft: #181D24; --line: #2A313B;
  --pink: #F42E97; --cyan: #2BE1DA; --text: #F6F8FC; --muted: #A3ABB8;
  --display: "Saira Condensed", "Arial Narrow", "Helvetica Neue", sans-serif;
  --body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Consolas, monospace;
}
body { background: var(--bg); color: var(--text); font-family: var(--body); font-size: 16px; line-height: 1.55; }
.wrap { max-width: 1180px; margin: 0 auto; padding-inline: 20px; padding-block: 28px 80px; display: flex; flex-direction: column; gap: 56px; }
.mono { font-family: var(--mono); font-size: 0.82em; }
h1, h2, h3 { font-family: var(--display); font-weight: 700; text-transform: uppercase; letter-spacing: 0.02em; line-height: 1; margin: 0; text-wrap: balance; }
h1 { font-size: clamp(2.6rem, 7vw, 4.6rem); }
h2 { font-size: clamp(2.4rem, 6vw, 4rem); }
h3 { font-size: 1.5rem; color: var(--muted); }
p { margin: 0; max-width: 68ch; }
a { color: var(--cyan); }
a:focus-visible, button:focus-visible { outline: 2px solid var(--cyan); outline-offset: 3px; }
.top { display: flex; flex-direction: column; gap: 18px; border-bottom: 2px solid var(--pink); padding-bottom: 28px; }
.status { font-family: var(--mono); font-size: 0.8rem; color: var(--pink); letter-spacing: 0.08em; text-transform: uppercase; }
.lede { font-size: 1.15rem; color: var(--text); }
.muted { color: var(--muted); }
nav.classes { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--bg); border-bottom: 1px solid var(--line); margin-inline: -20px; padding: 10px 20px; display: flex; gap: 8px; overflow-x: auto; }
nav.classes a { font-family: var(--display); font-weight: 600; font-size: 1.1rem; text-transform: uppercase; letter-spacing: 0.04em; color: var(--muted); text-decoration: none; padding: 4px 12px; border: 1px solid var(--line); white-space: nowrap; }
nav.classes a:hover { color: var(--bg); background: var(--cyan); border-color: var(--cyan); }
.how { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 28px 40px; }
.how > div { display: flex; flex-direction: column; gap: 12px; min-width: 0; }
.how ol { margin: 0; padding-left: 1.2em; display: flex; flex-direction: column; gap: 8px; color: var(--muted); }
.how ol strong { color: var(--text); font-weight: 600; }
.class { display: flex; flex-direction: column; gap: 22px; scroll-margin-top: 70px; }
.class-head { display: flex; flex-direction: column; gap: 10px; border-left: 4px solid var(--pink); padding-left: 16px; }
.eyebrow { color: var(--cyan); letter-spacing: 0.06em; margin: 0; }
.pitch { font-size: 1.15rem; }
.tags { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: 6px; }
.tags li { font-family: var(--mono); font-size: 0.76rem; color: var(--muted); border: 1px solid var(--line); padding: 2px 8px; }
.feel { display: flex; flex-wrap: wrap; gap: 6px 28px; margin: 0; font-size: 0.95rem; }
.feel div { display: flex; gap: 8px; }
.feel dt { font-family: var(--mono); font-size: 0.76rem; text-transform: uppercase; letter-spacing: 0.08em; color: var(--cyan); padding-top: 3px; }
.feel dd { margin: 0; color: var(--muted); }
.gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 14px; }
figure { margin: 0; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
figure.hero { grid-column: 1 / -1; }
figure img { display: block; width: 100%; height: auto; background: var(--soft); }
figcaption { font-size: 0.85rem; color: var(--muted); }
.zoom { all: unset; cursor: zoom-in; display: block; }
.blockout { display: grid; grid-template-columns: 1fr; gap: 18px; }
.meta { font-family: var(--mono); font-size: 0.8rem; color: var(--muted); max-width: none; }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; font-size: 0.9rem; min-width: 560px; }
th { text-align: left; font-family: var(--mono); font-weight: 500; font-size: 0.74rem; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); border-bottom: 1px solid var(--line); padding: 6px 12px 6px 0; }
td { border-bottom: 1px solid var(--line); padding: 7px 12px 7px 0; vertical-align: top; color: var(--muted); }
td:first-child { color: var(--text); white-space: nowrap; font-weight: 500; }
tr.fund td:first-child { color: var(--cyan); }
.sw { display: inline-block; width: 10px; height: 10px; margin-right: 8px; }
#lightbox { position: fixed; inset: 0; background: rgba(9, 12, 16, 0.94); display: flex; align-items: center; justify-content: center; padding: 16px; z-index: 20; cursor: zoom-out; }
#lightbox img { max-width: 100%; max-height: 100%; }
.end { border-top: 1px solid var(--line); padding-top: 24px; display: flex; flex-direction: column; gap: 12px; color: var(--muted); }
.end ol { margin: 0; padding-left: 1.2em; display: flex; flex-direction: column; gap: 8px; max-width: 72ch; }
.end strong { color: var(--text); }
</style>
<div class="wrap">
  <header class="top">
    <p class="status">Design proposal, round 2, not approved · 2 October 2026</p>
    <h1>Frame classes</h1>
    <p class="lede">Twelve new vehicle categories for Space Racers, round 2: 70 cockpits, 70 signature kits and 700 modules. No wheels: every vehicle flies on jets. Every vehicle carries real engine, stabiliser and boost modules. Every cockpit has its own kit, and any cockpit can wear any other cockpit's kit.</p>
    <p class="muted">Concept images are generated mood pieces, not final models. The grey-box images come from the same specs that built the blockouts in the backup place.</p>
    {{OVERVIEW}}
  </header>
  <nav class="classes" aria-label="Classes">{{NAV}}</nav>
  <section class="how">
    <div>
      <h3>Why parts always fit</h3>
      <ol>{{RULES}}</ol>
    </div>
    <div>
      <h3>Fundamentals first, body second</h3>
      <p class="muted">Engine1, Engine2, Stabilisers and Boost are jet hardware in every class, placed wherever suits it. They are shown in cyan in each slot table. The body sections get their own slots: front body, rear body and the mid section, then bumpers, spoiler, hood, roof and extras.</p>
      <p class="muted">The matrix under each class is the test that matters: each row is one cockpit, each column one kit. Every cell has to fit cleanly and look like a different vehicle from its neighbours.</p>
    </div>
  </section>
  {{SECTIONS}}
  <footer class="end">
    <h3>Open questions</h3>
    <ol>
      <li><strong>Which classes first, and are the names right?</strong> Suggested pilot: Muscle or Rift, then Street, Exotic and Rider.</li>
      <li><strong>Where should the fundamentals sit on the realistic cars?</strong> The blockouts make a first proposal per class. They can move.</li>
      <li><strong>Do Rider and Tether belong in the first wave?</strong> Both need new technical work: a rider pose, and a very wide, long hull.</li>
    </ol>
    <p>Full contract: docs/design/vehicle-frame-classes.md. Class sheets: docs/design/vehicle-categories/.</p>
  </footer>
</div>
<div id="lightbox" hidden><img alt=""></div>
<script>
  const box = document.getElementById('lightbox');
  const big = box.querySelector('img');
  document.addEventListener('click', (e) => {
    const b = e.target.closest('.zoom');
    if (b) { big.src = b.dataset.src; big.alt = b.querySelector('img').alt; box.hidden = false; return; }
    if (!box.hidden) box.hidden = true;
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') box.hidden = true; });
</script>
"""

if __name__ == "__main__":
    main()
