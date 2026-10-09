"""Build the Compact gallery (index.html) and the two before/after comparison images.

  py -3 build_index.py      run after render_compact.py (reads coverage.json written by it)

PREVIOUS holds the coverage of the pre-review frames, measured once with the same C.measure code
against the pre-review sources (commit d52fe63). The pre-review JPGs are kept in <out>/previous/.
"""
import html, json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
OUT = os.path.join(REPO, "assets", "ui", "mockups", "pulse_restyle", "phase0", "compact")
COV = json.load(open(os.path.join(HERE, "coverage.json"), encoding="utf-8"))
PREVIOUS = {"c01-free-roam-HUD-on-foot": 10.0, "c02-free-roam-HUD-driving": 31.4, "c08-in-race-HUD": 31.7, "c11-dealership": 40.7,
            "c12-customise-parts": 40.6, "c13-module-shop": 40.1, "c14-paint": 27.7, "c17-world-prompt-and-event-card": 42.1}
CLASSIC = {"free roam driving": "about 29% drawn (35% counting hit boxes)", "garage": "about 35%, at 4 to 6 px text"}

FRAMES = [
    ("c01-free-roam-HUD-on-foot", "Free-roam HUD, on foot", "Minimap 92 dp top-right with the driver-rank arc on its upper-left edge and the rank number at the arc's start. Cash only, under the map. Five 32 dp icon buttons (48 dp hit boxes) on the top edge. Bottom corners left to the Roblox thumbstick and jump."),
    ("c02-free-roam-HUD-driving", "Free-roam HUD, driving", "Classic's positions: steering bottom-left with drift above and boost above that, pedals bottom-right, speed bottom-centre with Exit beside it. Controls are outlines with no panel and no labels; pedal hit boxes are larger than their rings."),
    ("c03-car-panel", "Vehicles list", "Side panel on the right; the minimap and rank are hidden while it is open and the cash chip moves beside it. Two columns, three rows visible, Buy more first."),
    ("c04a-settings-modal", "Settings modal", "Narrower (400 dp). Options are 36 dp tall with 48 dp hit boxes."),
    ("c04b-get-cash-modal", "Get Cash modal", "Packs shown locked because cash products are not enabled."),
    ("c05-race-menu-list", "Race menu, list", "Tabs take the title's place so five 48 dp rows fit (three before). One line per event."),
    ("c06-race-menu-detail", "Race menu, detail", "Same parts, smaller type; the three buttons are one row on the bottom edge."),
    ("c07-race-entry-setup", "Race entry", "Three panels and one button row. Tier buttons are 36 dp with 48 dp hit boxes."),
    ("c08-in-race-HUD", "In-race HUD", "Position and lap under the Roblox buttons, timer top-centre, three-row board (car ahead, you, car behind), Reset and Quit as icons. Centre 60% x 60% is empty."),
    ("c09-countdown", "Countdown", "The count is the only thing in the centre; controls are dimmed until GO."),
    ("c10-results", "Results", "Cash and XP as image digits, results list on the right, buttons bottom-right."),
    ("c11-dealership", "Dealership", "Car is the hero. Title beside the Roblox buttons, class tabs under it, one status line top-right (selected car with tier and PI, spaces, cash), buttons above the rail, slim rail on the bottom edge."),
    ("c12-customise-parts", "Customise, parts", "All seven slots fit the rail at 844 dp: image plus one line, a cyan tick for fitted. The selected slot's detail is the line above the rail. Stat card is collapsed into the top-right strip."),
    ("c13-module-shop", "Module shop", "Stat card expanded (tap the car segment): six rows with the preview gains. Tiles carry the price or OWNED in the corner."),
    ("c14-paint", "Paint", "Swatches are the rail, with the channel switch at its left end. Sliders and buttons share the row above. Area stepper sits beside the tabs."),
    ("c15-purchase-confirm", "Purchase confirm", "316 dp wide, four fact rows, two buttons."),
    ("c16-full-map", "Full map", "Controls are a column of icon buttons on the right; the key is a small card; the hint is a line of text."),
    ("c17-world-prompt-and-event-card", "World prompt and event card", "Event card is two lines beside the Roblox buttons. START sits above the pedals under the right thumb, outside the centre."),
    ("c18-toast-and-onboarding-callout", "Toast and onboarding callout", "Objective is one line in the top band, toast under it. The callout is a tutorial step with the dimmer, so it is allowed into the centre."),
    ("c19a-loading", "Loading", "Unchanged apart from type sizes."),
    ("c19b-start-screen", "Start screen", "Play keeps a full 48 dp height."),
]
SIZES = [("932x430", "932x430, scale 1.10"), ("640x360", "640x360, scale 0.92"), ("568x320", "568x320, scale 0.85 (floor)")]


def font(size):
    for f in ("arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def compare(stem, out, label):
    a = Image.open(os.path.join(OUT, "previous", stem + ".jpg")).convert("RGB")
    b = Image.open(os.path.join(OUT, stem + ".jpg")).convert("RGB").resize(a.size)
    gap, cap = 24, 120
    im = Image.new("RGB", (a.width * 2 + gap, a.height + cap), (14, 13, 26))
    im.paste(a, (0, cap)); im.paste(b, (a.width + gap, cap))
    d = ImageDraw.Draw(im)
    old, new = PREVIOUS[stem], COV[stem]["ui"]
    d.text((30, 30), f"BEFORE review 1: {label}. UI covers {old}% of the screen ({100 - old:.1f}% clear)", fill=(185, 179, 214), font=font(46))
    d.text((a.width + gap + 30, 30), f"AFTER (2026-10-09): UI covers {new}% of the screen ({100 - new:.1f}% clear)", fill=(255, 228, 51), font=font(46))
    im.save(os.path.join(OUT, out), quality=90)


def cap(stem):
    c = COV.get(stem)
    if not c:
        return ""
    s = f"UI covers <b>{c['ui']}%</b> of the screen ({100 - c['ui']:.1f}% clear)"
    if stem in PREVIOUS:
        s += f", was {PREVIOUS[stem]}%"
    if stem[:3] in ("c01", "c02", "c08", "c17"):
        s += f"; centre 60% x 60%: {c['centre']}%"
    return s + f". Smallest TextSize {c['minTextSize']:.0f}."


def fig(stem, title, text):
    return (f'<figure><a href="{stem}.jpg"><img src="{stem}.jpg" alt="{html.escape(title)}" loading="lazy"></a>'
            f'<figcaption><b>{html.escape(title)}</b><br>{html.escape(text)}<br><span class="n">{cap(stem)}</span></figcaption></figure>')


def main():
    compare("c02-free-roam-HUD-driving", "cmp-free-roam.jpg", "free roam, driving")
    compare("c12-customise-parts", "cmp-customise.jpg", "customise")
    c02, c12 = COV["c02-free-roam-HUD-driving"]["ui"], COV["c12-customise-parts"]["ui"]
    h = ['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pulse Compact previews</title>',
         '<style>:root{--bg:#0E0D1A;--fg:#F3F0FF;--mut:#B9B3D6;--pink:#FF2D95;--yel:#FFE433;--line:rgba(243,240,255,.18)}',
         'body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,Segoe UI,sans-serif}',
         'main{max-width:1500px;margin:0 auto;padding:24px 16px 60px}h1{margin:0 0 6px;font-size:26px}h2{font-size:18px;margin:36px 0 10px;border-top:1px solid var(--line);padding-top:16px}',
         'p,li{color:var(--mut);max-width:100ch}p{margin:4px 0}ul{margin:6px 0;padding-left:20px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:18px}',
         'figure{margin:0}img{width:100%;height:auto;display:block;border:1px solid var(--line)}figcaption{padding:8px 2px;color:var(--mut)}b{color:var(--fg)}.n{color:var(--yel)}.n b{color:var(--yel)}',
         '.sizes{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:12px;align-items:start}.wide img{margin-bottom:6px}</style></head><body><main>',
         '<h1>Pulse Racers: Compact (phone) previews, Phase 0</h1>',
         '<h2>Changes after review 1 (2026-10-09)</h2>',
         '<p>Oscar: "the mobile ui needs a lot of refinement, a lot of the ui looks too big and takes up too much of the screen ... take some inspiration from the current ui".</p><ul>',
         f'<li><b>Free roam, driving: UI covers {c02}% of the screen, was {PREVIOUS["c02-free-roam-HUD-driving"]}%.</b> Budget 18%. The centre 60% x 60% holds nothing. The current (Classic) phone HUD draws {CLASSIC["free roam driving"]}.</li>',
         f'<li><b>Customise: UI covers {c12}% of the screen, was {PREVIOUS["c12-customise-parts"]}%.</b> Budget 45% (55% clear). The current garage on a phone covers {CLASSIC["garage"]}.</li>',
         '<li>Touch controls keep Classic\'s positions but are outlines with no panel and no labels. Every target is still 48 dp or more; the dashed boxes show the hit areas, which are larger than what is drawn.</li>',
         '<li>Minimap 92 dp (was 104) with the driver-rank arc on its upper-left edge. Status is cash only in free roam. Gauge is a number under a thin arc.</li>',
         '<li>Garage screens: one status line top-right with the stat card folded into it, buttons above the rail, rail of 60 dp tiles on the bottom edge.</li>',
         '<li>Type is smaller: five text sizes from TextSize 26 down to 17 at 844x390 (was 38 down to 17). Nothing is under TextSize 14 at the 0.85 floor.</li>',
         '<li>Vehicles list is a side panel that hides the minimap and rank.</li></ul>',
         '<figure class="wide"><a href="cmp-free-roam.jpg"><img src="cmp-free-roam.jpg" alt="Free roam before and after"></a><a href="cmp-customise.jpg"><img src="cmp-customise.jpg" alt="Customise before and after"></a></figure>',
         '<p>Drawn at 844x390 dp, landscape only. Cyan dashed lines: device safe area (47 / 47 / 21). Dashed box top-left: Roblox top bar buttons. Faint dashed boxes: 48 dp hit areas. The yellow figure in each frame is measured by the page from its own painted rectangles (fills, outlines, images, text). Backgrounds are blurred stand-ins. Not installed, not approved.</p>',
         '<p>Sources: scripts/ui_restyle/previews/compact (frames.js, compact.css, compact.js, TYPE_ROLES.md, CURRENT_PHONE_UI.md). Re-render with render_compact.py, then build_index.py. Pre-review frames: previous/.</p>',
         '<h2>Frames at 844x390</h2><div class="grid">']
    h += [fig(*f) for f in FRAMES]
    h.append('</div>')
    for pre, title in (("c02-free-roam-HUD-driving", "Free-roam HUD, driving"), ("c05-race-menu-list", "Race menu, list"), ("c12-customise-parts", "Customise, parts")):
        h.append(f'<h2>{title}: other phone sizes</h2><div class="sizes">')
        h += [fig(f"{pre}_{s}", t, "") for s, t in SIZES]
        h.append('</div>')
    h.append('</main></body></html>')
    open(os.path.join(OUT, "index.html"), "w", encoding="utf-8", newline="\n").write("\n".join(h))
    print("index.html, cmp-free-roam.jpg, cmp-customise.jpg written")


if __name__ == "__main__":
    main()
