"""Read-only: published font metrics (capsize) for the candidate faces. Prints vertical metrics only.

Roblox TextSize is the font's line height (hhea ascent - descent + lineGap), confirmed against the
shipped font files, so cap height at a TextSize = TextSize * capHeight / lineHeight.
"""
import re
import urllib.request

BASE = "https://cdn.jsdelivr.net/npm/@capsizecss/metrics@4.3.0/entireMetricsCollection/"
FACES = [
    "barlowCondensed/800italic", "barlowCondensed/600italic", "barlow/800italic", "barlow/600italic",
    "kanit/800italic", "kanit/700italic", "kanit/600italic", "kanit/500italic",
    "titilliumWeb/700italic", "titilliumWeb/600italic", "titilliumWeb/900",
    "robotoCondensed/700italic", "sourceSansPro/900italic", "sourceSans3/900italic",
    "firaSans/800italic", "prompt/800italic", "rubik/800italic", "workSans/800italic",
    "montserrat/800italic", "antonio/700", "teko/700", "oswald/700", "rajdhani/700", "goldman/700",
    "michroma/regular",
]
KEYS = ["capHeight", "ascent", "descent", "lineGap", "unitsPerEm", "xHeight", "xWidthAvg"]

print("face | upm | ascent | descent | lineGap | capHeight | lineHeight em | cap/line | cap px at TextSize 40 | "
      "TextSize for 1 px cap | xWidthAvg em")
for face in FACES:
    try:
        with urllib.request.urlopen(BASE + face + "/index.mjs", timeout=25) as r:
            text = r.read().decode("utf-8", "replace")
    except Exception as e:  # noqa: BLE001
        print(f"{face} | not found ({e})")
        continue
    vals = {}
    for k in KEYS:
        m = re.search(r"\b" + k + r"\s*[:=]\s*(-?[0-9.]+)", text)
        vals[k] = float(m.group(1)) if m else float("nan")
    upm = vals["unitsPerEm"]
    line = (vals["ascent"] - vals["descent"] + vals["lineGap"]) / upm
    cap = vals["capHeight"] / upm
    print(f"{face} | {upm:.0f} | {vals['ascent']:.0f} | {vals['descent']:.0f} | {vals['lineGap']:.0f} | "
          f"{vals['capHeight']:.0f} | {line:.3f} | {cap / line:.3f} | {40 * cap / line:.1f} | {line / cap:.3f} | "
          f"{vals['xWidthAvg'] / upm:.3f}")
