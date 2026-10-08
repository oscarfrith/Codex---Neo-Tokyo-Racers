"""Read-only: metrics of the font files Roblox Studio ships on disk.

Predicts the Roblox width of the probe text at TextSize 40, assuming TextSize is the line height
(hhea ascender - descender + lineGap), and reports cap height in pixels at TextSize 40.
"""
import os
import struct
import sys

from PIL import ImageFont

TEXT = "CUSTOMISE 0123456789"
EM = 1000


def tables(path):
    with open(path, "rb") as f:
        data = f.read()
    num = struct.unpack(">H", data[4:6])[0]
    out = {}
    for i in range(num):
        tag, _chk, off, length = struct.unpack(">4sIII", data[12 + i * 16:28 + i * 16])
        out[tag.decode("latin1")] = data[off:off + length]
    return out


def metrics(path):
    t = tables(path)
    upm = struct.unpack(">H", t["head"][18:20])[0]
    asc, desc, gap = struct.unpack(">hhh", t["hhea"][4:10])
    os2 = t.get("OS/2", b"")
    version = struct.unpack(">H", os2[0:2])[0] if os2 else 0
    cap = struct.unpack(">h", os2[88:90])[0] if version >= 2 and len(os2) >= 90 else 0
    typo = struct.unpack(">hhh", os2[68:74]) if len(os2) >= 74 else (0, 0, 0)
    win = struct.unpack(">HH", os2[74:78]) if len(os2) >= 78 else (0, 0)
    return upm, asc, desc, gap, cap, typo, win


folder = sys.argv[1]
names = sys.argv[2:]
print("file | upm | hhea asc/desc/gap | typo asc/desc/gap | win asc/desc | capH | lineH em (hhea) | text adv em | "
      "pred width @40 (hhea) | pred width @40 (win) | cap px @40 (hhea)")
for name in names:
    path = os.path.join(folder, name)
    upm, asc, desc, gap, cap, typo, win = metrics(path)
    font = ImageFont.truetype(path, EM)
    adv = font.getlength(TEXT) / EM
    line = (asc - desc + gap) / upm
    line_win = (win[0] + win[1]) / upm if win[0] else 0
    if not cap:
        box = font.getbbox("H")
        cap = (box[3] - box[1]) * upm / EM
    print(f"{name} | {upm} | {asc}/{desc}/{gap} | {typo[0]}/{typo[1]}/{typo[2]} | {win[0]}/{win[1]} | {cap} | "
          f"{line:.3f} | {adv:.3f} | {adv * 40 / line:.0f} | {(adv * 40 / line_win) if line_win else 0:.0f} | "
          f"{cap / upm * 40 / line:.1f}")
