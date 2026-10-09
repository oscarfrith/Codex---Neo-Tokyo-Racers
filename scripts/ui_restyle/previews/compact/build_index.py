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
REVIEW2 = {"c02-free-roam-HUD-driving": 14.1, "c08-in-race-HUD": 13.7}   # after review 2, before review 3 (c08 as measured then)
REVIEW1 = {"c02-free-roam-HUD-driving": 13.2, "c08-in-race-HUD": 12.7, "c11-dealership": 20.3, "c12-customise-parts": 20.3, "c13-module-shop": 27.0}   # after review 1, before review 2
CLASSIC = {"free roam driving": "about 29% drawn (35% counting hit boxes)", "garage": "about 35%, at 4 to 6 px text"}

FRAMES = [
    ("c01-free-roam-HUD-on-foot", "Free-roam HUD, on foot", "Minimap 92 dp top-right with the driver-rank arc on its upper-left edge (review 3: both are the baked gradient ring images, pink to violet to cyan). Cash only, under the map. Review 2: the five 32 dp icon buttons (48 dp hit boxes, 8 dp gaps) are one row at the top centre, clear of the Roblox buttons and of the map. Bottom corners left to the Roblox thumbstick and jump."),
    ("c02-free-roam-HUD-driving", "Free-roam HUD, driving", "Review 3: the touch controls are the current (Classic) ones restyled: the same pedal, chevron and bolt pictograms on square Slate plates with a pink-violet-cyan outline (accelerate and boost shown pressed: white plate, pink base line, glow). The speed readout is the desktop gauge at 92 dp with gradient arcs. Positions are Classic's: turn bottom-left with drift above and boost above that, pedals bottom-right, speed bottom-centre with Exit beside it."),
    ("c03-car-panel", "Vehicles list", "Review 3: no class or sort drop-downs; a title, the count and Close, and the list is always sorted by rating, highest first. Side panel on the right; the minimap and rank are hidden while it is open, the cash chip moves beside it and the action row centres in the space left of it. Tier badges carry the tier colour, also on the selected (white) tile."),
    ("c04a-settings-modal", "Settings modal", "Narrower (400 dp). Options are 36 dp tall with 48 dp hit boxes."),
    ("c04b-get-cash-modal", "Get Cash modal", "Packs shown locked because cash products are not enabled."),
    ("c05-race-menu-list", "Race menu, list", "Tabs take the title's place so five 48 dp rows fit (three before). One line per event."),
    ("c06-race-menu-detail", "Race menu, detail", "Same parts, smaller type; the three buttons are one row on the bottom edge."),
    ("c07-race-entry-setup", "Race entry", "Three panels and one button row. Tier buttons are 36 dp with 48 dp hit boxes, filled with the tier colour (white underline = done, white outline = chosen, dimmed = locked). There is no phone vehicle-choice frame, so there was no eligible count or drop-down to remove."),
    ("c08-in-race-HUD", "In-race HUD", "Position and lap under the Roblox buttons, timer top-centre, three-row board, Reset and Quit as icons. Review 3: the restyled Classic controls and the gradient gauge (accelerate and turn right pressed, boost charge ring at 30%). The top of the brake plate reaches 15 dp into the centre 60% x 60% box; nothing else does."),
    ("c09-countdown", "Countdown", "The count is the only thing in the centre; controls are in their disabled state until GO."),
    ("c10-results", "Results", "Cash and XP as image digits, results list on the right, buttons bottom-right. The car's tier badge is in the tier colour."),
    ("c11-dealership", "Dealership", "Review 2: the stats are always visible. A 176 dp column on the right, between the status line and the Buy row: tier and PI badge in the tier colour, name, price, then six rows of label, slim bar and value. The car keeps the middle; rail tiles carry tier-colour badges."),
    ("c12-customise-parts", "Customise, parts", "All seven slots fit the rail at 844 dp. Review 2: the same always-visible stat block as the dealership replaces the collapsible chip (it fits without touching the car; Paint keeps the chip because paint does not change stats)."),
    ("c13-module-shop", "Module shop", "The stat block widens to 208 dp to show the preview gains in cyan. Tiles carry the price or OWNED in the corner."),
    ("c14-paint", "Paint", "Swatches are the rail, with the channel switch at its left end. Sliders and buttons share the row above. Area stepper sits beside the tabs."),
    ("c15-purchase-confirm", "Purchase confirm", "316 dp wide, four fact rows, two buttons."),
    ("c16-full-map", "Full map", "Controls are a column of icon buttons on the right; the key is a small card; the hint is a line of text."),
    ("c17-world-prompt-and-event-card", "World prompt and event card", "The event card moved under the Roblox buttons because the top centre now holds the action row. START sits above the pedals under the right thumb."),
    ("c18-toast-and-onboarding-callout", "Toast and onboarding callout", "Objective is one line under the Roblox buttons, toast under the action row. The callout is a tutorial step with the dimmer, so it is allowed into the centre."),
    ("c19a-loading", "Loading", "Unchanged apart from type sizes."),
    ("c19b-start-screen", "Start screen", "Play keeps a full 48 dp height."),
    ("c20-touch-controls-sheet", "Touch controls sheet (redrawn, review 3)", "The current controls restyled: turn, drift, boost, brake and accelerate at 2x in idle, pressed and disabled states, each inside its dashed hit box, then the whole set in place at 1x. A sheet, not a device frame, so it has no coverage figure."),
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
    if stem in REVIEW2:
        s += f", {REVIEW2[stem]}% after review 2"
    if stem in REVIEW1:
        s += f", {REVIEW1[stem]}% after review 1"
    if stem in PREVIOUS:
        s += f", {PREVIOUS[stem]}% before review 1"
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
    c11, c08, c02s = COV["c11-dealership"]["ui"], COV["c08-in-race-HUD"]["ui"], COV["c02-free-roam-HUD-driving_568x320"]["ui"]
    h = ['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pulse Compact previews</title>',
         '<style>:root{--bg:#0E0D1A;--fg:#F3F0FF;--mut:#B9B3D6;--pink:#FF2D95;--yel:#FFE433;--line:rgba(243,240,255,.18)}',
         'body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,Segoe UI,sans-serif}',
         'main{max-width:1500px;margin:0 auto;padding:24px 16px 60px}h1{margin:0 0 6px;font-size:26px}h2{font-size:18px;margin:36px 0 10px;border-top:1px solid var(--line);padding-top:16px}',
         'p,li{color:var(--mut);max-width:100ch}p{margin:4px 0}ul{margin:6px 0;padding-left:20px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:18px}',
         'figure{margin:0}img{width:100%;height:auto;display:block;border:1px solid var(--line)}figcaption{padding:8px 2px;color:var(--mut)}b{color:var(--fg)}.n{color:var(--yel)}.n b{color:var(--yel)}',
         '.sizes{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:12px;align-items:start}.wide img{margin-bottom:6px}</style></head><body><main>',
         '<h1>Pulse Racers: Compact (phone) previews, Phase 0</h1>',
         '<h2>Changes after review 3 (2026-10-09)</h2>',
         '<p>Oscar: "ok looking good, other than mobile driving controls, can you take inspo from the current ones, and get those to fit the new theme, colours etc, ensure it all looks consistent. then for the map outer rings, speedo etc can these be more dynamic with colour gradients etc. like we had in previous previews, these can be images". He also asked for the class and sort drop-downs to go from the phone My Vehicles panel.</p><ul>',
         '<li><b>Touch controls are the current ones, restyled</b> (c02, c08, c09, c17, <a href="c20-touch-controls-sheet.jpg" style="color:var(--yel)">c20 sheet</a>). The slanted pedal redesign is withdrawn. The pictograms are Classic\'s: the upright accelerate pedal (cyan capsule, triangle, five ribs), the wide brake pedal (pink capsule, four ribs, bar beneath), one chevron for turn, two for drift (white with cyan, white with pink), a round boost button with the bolt. Each sits on a square Slate plate with a thin pink-violet-cyan outline, the same colours as the minimap ring. Pressed is the selected-tile look: white plate, dark pictogram, pink base line, pink glow. Disabled is the idle image dimmed. Positions are Classic\'s. Each control is one baked image (ten uploads: five controls, idle and pressed; right-hand turn and drift are mirrored).</li>',
         '<li><b>Gradient rings and gauge, as images.</b> The minimap ring blends pink, violet and cyan round the circle with a soft glow, as in the accepted free-roam mockup; the rank arc is the matching ring in violet to cyan. The speed readout is now the desktop gauge at 92 dp: a speed arc that runs cyan, violet, pink along its sweep with a glow and a bright tip, ticks in three weights, boost as the inner arc. Desktop and phone use the same image files.</li>',
         '<li><b>Vehicles list</b> (c03): no class or sort drop-downs; always sorted by rating, highest first.</li>',
         '<li>Small gradients elsewhere: the selected tile base line and the title mark run pink to violet, the cash chip yellow to a warmer yellow.</li>',
         f'<li>Free roam, driving: UI covers <b>{c02}%</b> at 844x390 (was {REVIEW2["c02-free-roam-HUD-driving"]}% after review 2, budget 18%); in race {c08}%. The plates are filled where the review 2 shapes were outlines, and the brake is back to a Classic-sized pedal, so its top edge reaches 15 dp into the centre 60% x 60% box ({COV["c02-free-roam-HUD-driving"]["centre"]}%). At 640x360 it is {COV["c02-free-roam-HUD-driving_640x360"]["ui"]}% and at 568x320 {c02s}%, over the budget, because controls stay at 48 dp while the screen shrinks.</li></ul>',
         '<h2>Changes after review 2 (2026-10-09)</h2>',
         '<p>Oscar: "the mobile ui is looking better, for free roam i think it might be better to have the car, garage buttons etc. in the centre top ... i still want the stats visible in the mobile dealership. can we have colours for the different tiers of cars too. the mobile pedals, arrows etc. also need to look a lot more dynamic".</p><ul>',
         '<li><b>Free-roam action buttons are one row at the top centre</b>, on foot and driving (c01, c02): five 32 dp glyph buttons in 48 dp hit boxes with 8 dp gaps, clear of the Roblox buttons on the left and of the minimap and cash on the right at every size down to 568x320. The event card and the onboarding objective moved under the Roblox buttons to make room (c17, c18).</li>',
         f'<li><b>The dealership keeps its stats on screen</b> (c11): a 176 dp column on the right between the status line and the Buy row, with the tier and PI badge, name, price and six rows of label, slim bar and value. Dealership UI covers {c11}% of the screen (was {REVIEW1["c11-dealership"]}%). Customise uses the same block in place of the collapsible chip (c12, c13: {c12}%); Paint keeps the chip.</li>',
         '<li><b>Tier colours</b> on every tier badge: rail and vehicle-list tiles (also when selected), stat block, race status line, race-entry tier buttons, results, purchase confirm. They are the game\'s existing tier colours: E grey, D green, C teal, B blue, A amber, S pink.</li>',
         f'<li><b>Touch controls redrawn as racing controls</b> (rejected in review 3 and replaced; see above): shapes slanted about 12 degrees, steering as two chevron pads with a pink leading edge, a tall accelerate pedal with three chevrons, tread lines and a fill that fades from clear to pink at its base, a smaller, lower brake in red, drift plates with a double chevron and skid marks, boost as a bolt inside a twelve-segment cyan charge ring. Pressed = filled, white base line, glow; disabled = grey outline. Still no panels or labels, hit boxes 48 dp or more, 8 dp gaps, Classic positions. These are image assets in Roblox, not frames.</li>',
         f'<li>Free roam, driving: UI covered {REVIEW2["c02-free-roam-HUD-driving"]}% at 844x390 after review 2 (was {REVIEW1["c02-free-roam-HUD-driving"]}%, budget 18%), centre 60% x 60% empty.</li>',
         '<li>Race entry: there is no phone vehicle-choice frame yet, so there was no "N of M vehicles eligible" text or class/sort drop-down to remove. The free-roam vehicles list (c03) kept its two drop-downs until review 3.</li></ul>',
         '<h2>Changes after review 1 (2026-10-09)</h2>',
         '<p>Oscar: "the mobile ui needs a lot of refinement, a lot of the ui looks too big and takes up too much of the screen ... take some inspiration from the current ui".</p><ul>',
         f'<li><b>Free roam, driving: UI covered {REVIEW1["c02-free-roam-HUD-driving"]}% of the screen after review 1, was {PREVIOUS["c02-free-roam-HUD-driving"]}%.</b> Budget 18%. The centre 60% x 60% holds nothing. The current (Classic) phone HUD draws {CLASSIC["free roam driving"]}.</li>',
         f'<li><b>Customise: UI covered {REVIEW1["c12-customise-parts"]}% of the screen after review 1, was {PREVIOUS["c12-customise-parts"]}%.</b> Budget 45% (55% clear). The current garage on a phone covers {CLASSIC["garage"]}.</li>',
         '<li>Touch controls keep Classic\'s positions with no panel and no labels (redrawn in review 2). Every target is still 48 dp or more; the dashed boxes show the hit areas, which are larger than what is drawn.</li>',
         '<li>Minimap 92 dp (was 104) with the driver-rank arc on its upper-left edge. Status is cash only in free roam. Gauge is a number under a thin arc.</li>',
         '<li>Garage screens: one status line top-right (review 2 puts the stat block back under it), buttons above the rail, rail of 60 dp tiles on the bottom edge.</li>',
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
