"""Glyph-only map icons (no badge circle, ring or square): icons_glyph/<Key>.png, 128x128 RGBA.

Oscar (2026-09-27): "we don't need the circle and block squares around the icons, just the icons".
Reuses the SDF glyphs and rasterizer from make_icons.py. Each icon is the glyph in its role
colour, a crisp dark outline (OUTLINE units, ~1.5 px at 28 px) and a soft dark shadow halo so it
reads on road grey (128-179) and block dark (51). Glyphs are scaled to fill the canvas now that
there is no badge. Pins keep the pin shape and anchor at the tip (see ANCHORS / manifest).

Roles: places cyan (Customisation), activities HighSpeed pink (Race, TimeTrial, Duel),
jobs ElectricBlue (Job, TaxiFare, CourierPickup, TaxiDrop, CourierDrop), Waypoint Outline pink,
Player white arrow with cyan edge, OtherPlayer blue dot with white ring.
Dealership and Garage are not drawn: the map uses the HUD's own icons for those.

Run: py -3 make_icons_glyph.py   (Pillow is used only for the contact sheet)
"""
import json
import math
import pathlib

from make_icons import (N, OUTLINE_DARK, CYAN, CYAN_GLYPH, PINK, HIGHSPEED, BLUE, TEXT,
                        circle, box, segment, polygon, union, subtract, intersect, grow,
                        translate, scale, render, glyph_brush, glyph_stopwatch,
                        glyph_versus, glyph_person_hail, glyph_parcel, glyph_briefcase, glyph_arrow)
from png_rgba import write_png

HERE = pathlib.Path(__file__).parent
OUT = HERE / "icons_glyph"
OUTLINE = 6.5          # dark outline width in 128-units
SHADOW = 11.0          # soft halo reach
SHADOW_COL = (6, 8, 11, 110)
BLUE_GLYPH = (47, 136, 255, 255)   # ElectricBlue #1974FF lifted slightly (#2F88FF) for contrast on block dark
PIN_TIP = 118.0


def styled(glyph, col, detail=None):
    """glyph SDF -> layers: soft halo, dark outline, glyph; detail = extra (sdf, colour) on top."""
    layers = [(grow(glyph, SHADOW), SHADOW_COL), (grow(glyph, OUTLINE), OUTLINE_DARK), (glyph, col)]
    return layers + (detail or [])


def pin_shape(cx=64.0, top=12.0, r=33.0, tip=PIN_TIP):
    cy = top + r
    d = tip - cy
    ang = math.asin(r / d)
    tx, ty = r * math.cos(ang), r * math.sin(ang)
    return union(circle(cx, cy, r), polygon([(cx - tx, cy + ty), (cx, tip), (cx + tx, cy + ty)])), (cx, cy)


def pin(col, inner):
    shape, _ = pin_shape()
    # outline narrower at the tip is fine; the shadow is skipped below the tip so the anchor stays exact
    return [(grow(shape, SHADOW - 3), SHADOW_COL), (grow(shape, OUTLINE - 1.5), OUTLINE_DARK), (shape, col)] + inner


def glyph_flag_true_sdf():
    """The make_icons flag with a true-distance cloth (polygon), so outline/halo grow correctly."""
    x0, x1, top, h = 38, 98, 30, 36

    def wave(x):
        return 4.5 * math.sin((x - x0) / (x1 - x0) * 2 * math.pi)
    xs = [x0 + (x1 - x0) * i / 24.0 for i in range(25)]
    cloth = polygon([(x, top + wave(x)) for x in xs] + [(x, top + h + wave(x)) for x in reversed(xs)])
    pole = box(33, 66, 3.5, 36, 0, 1.5)

    def checks(x, y):
        if cloth(x, y) > 0:
            return 1.0
        cx = int((x - x0) / ((x1 - x0) / 5.0))
        cy = int((y - top - wave(x)) / (h / 3.0))
        return -1.0 if (cx + cy) % 2 == 0 else 1.0
    return union(pole, cloth), checks


def icons():
    flag, checks = glyph_flag_true_sdf()
    k = 1.3
    flag_s, checks_s = scale(flag, 1.18), scale(checks, 1.18)
    watch = scale(glyph_stopwatch(), 1.22)
    watch_face = scale(circle(64, 70, 23), 1.22)
    _, (pcx, pcy) = pin_shape()
    person = union(circle(64, 33, 10), intersect(circle(64, 70, 21), box(64, 58, 23, 11.5)))
    person_small = translate(scale(person, 0.95, 64, 50), pcx - 64, pcy - 46)
    parcel_small = translate(scale(glyph_parcel(), 0.62), pcx - 64, pcy - 66)
    player = glyph_arrow()
    return {
        "Customisation": styled(scale(glyph_brush(), 1.4), CYAN_GLYPH),
        "Race": styled(flag_s, HIGHSPEED, [(intersect(flag_s, checks_s), OUTLINE_DARK)]),
        "TimeTrial": styled(watch, HIGHSPEED, [(watch_face, OUTLINE_DARK), (intersect(watch, watch_face), HIGHSPEED)]),
        "Duel": styled(scale(glyph_versus(), 1.3), HIGHSPEED),
        "Job": styled(scale(glyph_briefcase(), k), BLUE_GLYPH),
        "TaxiFare": styled(scale(glyph_person_hail(), 1.12), BLUE_GLYPH),
        "CourierPickup": styled(scale(glyph_parcel(), 1.3), BLUE_GLYPH),
        "CourierDrop": pin(BLUE, [(grow(parcel_small, 3), OUTLINE_DARK), (parcel_small, TEXT)]),
        "TaxiDrop": pin(BLUE, [(person_small, TEXT)]),
        "Waypoint": pin(PINK, [(circle(pcx, pcy, 13), TEXT)]),
        "Player": [(grow(player, SHADOW), SHADOW_COL), (grow(player, 7), OUTLINE_DARK),
                   (grow(player, 3.5), CYAN), (player, TEXT)],
        "OtherPlayer": [(circle(64, 64, 30 + SHADOW - 4), SHADOW_COL), (circle(64, 64, 34), OUTLINE_DARK),
                        (circle(64, 64, 30), TEXT), (circle(64, 64, 23), BLUE_GLYPH)],
    }


ROLES = {"Customisation": "place", "Race": "activity", "TimeTrial": "activity", "Duel": "activity",
         "Job": "job", "TaxiFare": "job", "CourierPickup": "job", "CourierDrop": "jobDrop",
         "TaxiDrop": "jobDrop", "Waypoint": "waypoint", "Player": "player", "OtherPlayer": "player"}
ANCHORS = {k: [0.5, round(PIN_TIP / N, 4)] for k in ("CourierDrop", "TaxiDrop", "Waypoint")}


def contact_sheet(files):
    from PIL import Image, ImageDraw
    sizes = (28, 40, 56)
    bgs = (("block", (51, 51, 51)), ("road", (128, 128, 128)), ("highway", (179, 179, 179)))
    keys = list(files)
    cell_w = sum(s + 10 for s in sizes) + 10
    row_h = max(sizes) + 16
    lab_w = 110
    W = lab_w + cell_w * len(bgs)
    H = 30 + row_h * len(keys)
    sheet = Image.new("RGB", (W, H), (20, 20, 24))
    d = ImageDraw.Draw(sheet)
    d.text((8, 8), "icons_glyph at 28 / 40 / 56 px on block 51, road 128, highway 179", fill=(240, 240, 240))
    for bi, (name, col) in enumerate(bgs):
        d.text((lab_w + bi * cell_w + 8, 20), name, fill=(200, 200, 200))
    for ri, key in enumerate(keys):
        y = 30 + ri * row_h
        d.text((8, y + row_h // 2 - 6), key, fill=(240, 240, 240))
        src = Image.open(files[key]).convert("RGBA")
        for bi, (name, col) in enumerate(bgs):
            x0 = lab_w + bi * cell_w
            d.rectangle((x0, y, x0 + cell_w - 6, y + row_h - 4), fill=col)
            x = x0 + 8
            for s in sizes:
                ic = src.resize((s, s), Image.LANCZOS)
                sheet.paste(ic, (x, y + (row_h - 4 - s) // 2), ic)
                x += s + 10
    sheet.save(OUT / "contact_sheet.png")


def main():
    OUT.mkdir(exist_ok=True)
    files = {}
    for key, layers in icons().items():
        img = render(layers)
        path = OUT / ("%s.png" % key)
        write_png(str(path), N, N, img)
        files[key] = path
        print("icon", key)
    contact_sheet(files)
    # manifest section
    mpath = HERE / "manifest.json"
    manifest = json.loads(mpath.read_text(encoding="utf-8"))
    manifest["icons_glyph"] = {
        "generatedBy": "scripts/map_art/make_icons_glyph.py",
        "style": "glyph only (no badge circle, ring or square); role colour glyph, dark outline "
                 "#06080B ~6.5/128, soft dark halo; pins keep the pin shape",
        "displaySizePx": [28, 56],
        "configIconsPath": "ReplicatedStorage.Config.UI.MapIcons.<Key> (replace the badge icons after upload)",
        "notDrawn": {"Dealership": "use the HUD's own dealership icon", "Garage": "use the HUD's own garage icon"},
        "contactSheet": "icons_glyph/contact_sheet.png",
        "icons": {k: {"file": "icons_glyph/%s.png" % k, "size": [N, N], "role": ROLES[k],
                      "anchorPoint": ANCHORS.get(k, [0.5, 0.5])} for k in files},
    }
    manifest["hiresMap"] = {"manifest": "hires/manifest.json", "choice": "HIRES_OPTIONS.md",
                            "tiles": "hires/R{row}C{col}.png (4x4 of 1024, 4096x4096 total)"}
    mpath.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
