"""Build per-combination "parts sheets" for the Exotic concept-art batch.

Usage: py -3 scripts/vehicle_blockouts/make_art_sheets.py

For each combination in docs/design/vehicle-categories/exotic-art/combos.json it tiles the finished concept
images of the cabin and the ten modules that combination uses into one captioned sheet. The sheet is passed
to Codex as a reference so the assembled vehicle is drawn from the same part designs.
Writes output/vehicle-categories-2026-10-01/exotic-art/sheets/<combo id>.png and a 1400 px JPEG copy in
docs/design/vehicle-categories/exotic-art/sheets/.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
DOC = os.path.join(REPO, "docs", "design", "vehicle-categories", "exotic-art")
ART = os.path.join(REPO, "output", "vehicle-categories-2026-10-01", "exotic-art")
ORDER = ["Cockpit", "FrontBody", "RearBody", "SidePods", "Engine1", "Engine2", "Stabilisers", "Boost", "FrontBumper", "RearBumper", "RearSpoiler"]
TW, TH, CAP, PAD, COLS = 600, 400, 40, 10, 4


def main():
    cfg = json.load(open(os.path.join(DOC, "combos.json"), encoding="utf-8"))
    os.makedirs(os.path.join(ART, "sheets"), exist_ok=True)
    os.makedirs(os.path.join(DOC, "sheets"), exist_ok=True)
    font = ImageFont.load_default(size=22)
    ok = True
    for c in cfg["combos"]:
        ids = ["cockpit_" + c["cockpit"]] + ["%s_%s" % (c["parts"][s], s) for s in ORDER[1:]]
        rows = (len(ids) + COLS - 1) // COLS
        sheet = Image.new("RGB", (COLS * (TW + PAD) + PAD, rows * (TH + CAP + PAD) + PAD), "#ffffff")
        draw = ImageDraw.Draw(sheet)
        for i, (slot, pid) in enumerate(zip(ORDER, ids)):
            src = os.path.join(ART, "parts", pid + ".png")
            x, y = PAD + (i % COLS) * (TW + PAD), PAD + (i // COLS) * (TH + CAP + PAD)
            if not os.path.exists(src):
                print("MISSING part image: " + src)
                ok = False
                continue
            im = Image.open(src).convert("RGB").resize((TW, TH), Image.LANCZOS)
            sheet.paste(im, (x, y))
            draw.text((x + 6, y + TH + 6), "%s: %s" % (cfg["slots"][slot].upper(), cfg["names"][pid]), fill="#111111", font=font)
        out = os.path.join(ART, "sheets", c["id"] + ".png")
        sheet.save(out)
        small = sheet.copy()
        small.thumbnail((1400, 1400), Image.LANCZOS)
        small.save(os.path.join(DOC, "sheets", c["id"] + ".jpg"), "JPEG", quality=84, optimize=True)
        print("sheet " + out)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
