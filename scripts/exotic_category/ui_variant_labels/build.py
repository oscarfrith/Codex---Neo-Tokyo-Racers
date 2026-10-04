"""Version names shown per category, and no hidden car preselected in the dealership: builds the after-source
and the guarded installer.

    py -3 scripts/exotic_category/ui_variant_labels/build.py

Fourth in the GarageUI chain: its before-source is ui_underglow/after/GarageUI.lua. Roll back in reverse
order: ui_variant_labels, ui_underglow, ui_dealership, ui_artwork.

What changes:
  GarageUI   1. Module cards show the version through a display map: the attribute
                VariantLabels_<CategoryId> on Config.UI.GarageReplacement ("Lightweight=GT;Power=EVO").
                A version with no entry, or a category with no attribute, shows as before. The card's
                second line now uses the same text as its tag, so a body part with VariantName "GT" reads GT.
             2. Opening the dealership no longer keeps the profile's current car selected when that car's
                category is hidden from the dealership (a new profile points at the first Piercer).
  Config     VariantLabels_exotic = "Lightweight=GT;Power=EVO".
Display only: the VariantName values in the catalogue and in saved data are unchanged.
"""
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BEFORE = os.path.join(HERE, "..", "ui_underglow", "after", "GarageUI.lua")
PLACE_ID = 93959280828322
NAV = "local function navIcon(name) return imageValue(navigationIcons:GetAttribute(name)) end"
HELPER = ('\nlocal function variantLabel(tag) local map=tostring(replacementConfig:GetAttribute("VariantLabels_"..tostring(currentCategory() and currentCategory().CategoryId)) or ""); '
          'for from,to in string.gmatch(map,"([^=;]+)=([^;]+)") do if from==tostring(tag) then return to end end; return tag end')
OPEN = "State.SelectedCockpit=State.Profile.CurrentCockpit; State.SelectedVehicleId=nil; State.BrowseAll=true;"
GUARD = ('State.SelectedCockpit=State.Profile.CurrentCockpit; if State.ShopMode=="Dealership" and currentCategory() and not categoryListed(currentCategory()) then State.SelectedCockpit=nil end; '
         "State.SelectedVehicleId=nil; State.BrowseAll=true;")
EDITS = [
    (NAV, NAV + HELPER, 1),
    ("Variant=row.Tag,", "Variant=variantLabel(row.Tag),", 2),
    ("DisplayName=row.Variant,", "DisplayName=variantLabel(row.Tag),", 2),
    (OPEN, GUARD, 1),
]


def djb2(text):
    x = 5381
    for b in text.encode("utf-8"):
        x = (x * 33 + b) % 4294967296
    return x


def main():
    before = io.open(BEFORE, encoding="utf-8", newline="").read()
    after = before
    for old, new, count in EDITS:
        if after.count(old) != count:
            raise SystemExit("anchor found %d times, expected %d: %s" % (after.count(old), count, old[:60]))
        after = after.replace(old, new)
    os.makedirs(os.path.join(HERE, "after"), exist_ok=True)
    io.open(os.path.join(HERE, "after", "GarageUI.lua"), "w", encoding="utf-8", newline="").write(after)
    data = json.dumps({"placeId": PLACE_ID, "base": "scripts/exotic_category/ui_variant_labels/",
                       "scripts": {"GarageUI": {"path": ["ReplicatedStorage", "Modules", "Game", "Garage", "GarageUI"],
                                                "before": djb2(before), "after": djb2(after)}},
                       "attributes": [["", "VariantLabels_exotic", "Lightweight=GT;Power=EVO"]]}, sort_keys=True)
    engine = io.open(os.path.join(HERE, "..", "ui_artwork", "installer_engine.lua"), encoding="utf-8").read()
    for mode in ("AUDIT", "APPLY", "ROLLBACK"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])\n%s' % (mode, data, engine)
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print(json.dumps({"before": "%08x" % djb2(before), "after": "%08x" % djb2(after)}))


if __name__ == "__main__":
    main()
