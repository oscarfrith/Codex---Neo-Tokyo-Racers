"""Regenerate every Pulse UI asset into assets/out/ and rebuild the contact sheet and manifest.

    py -3 scripts/ui_restyle/assets/make_all.py

Offline except for the Google Fonts web faces Chrome loads to draw text. Uploads nothing, never touches Studio.
"""
import os, sys, hashlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common
import gen_icons, gen_static, gen_marks, gen_rings, gen_touch_pulse, gen_digits, contact_sheet, manifest_source


def main():
    gen_icons.main()
    gen_static.main()
    gen_marks.main()
    gen_rings.main()          # review 3: baked gradient rings and gauge
    gen_touch_pulse.main()    # review 3: Classic touch controls restyled (replaces gen_touch)
    gen_digits.main()
    man = manifest_source.manifest()
    from PIL import Image
    for row in man["files"]:
        p = os.path.join(common.HERE, row["file"])
        im = Image.open(p)
        row["size"] = list(im.size)
        row["bytes"] = os.path.getsize(p)
        # hash of the decoded pixels: stable proof that a rebuild reproduced the same art
        row["pixel_sha1"] = hashlib.sha1(im.convert("RGBA").tobytes()).hexdigest()
    common.write_json(man, "upload_manifest.json", folder=common.HERE)
    contact_sheet.main()
    print("upload batch: %d files (+%d alternative)" % (man["count"], len(man["files"]) - man["count"]))


if __name__ == "__main__":
    main()
