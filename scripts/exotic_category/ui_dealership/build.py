"""Hide chosen vehicle categories from the dealership: builds the after-source and the guarded installer.

    py -3 scripts/exotic_category/ui_dealership/build.py

Runs after ui_artwork: its before-source is ui_artwork/after/GarageUI.lua. Roll this back before ui_artwork.

What changes:
  GarageUI   categoryListed() also treats a category as not on sale when its CategoryId is in the
             comma-separated attribute DealershipHiddenCategories on Config.UI.GarageReplacement. The
             dealership then leaves the category and its cars out; Customisation still shows it to a player
             who owns one of its vehicles (the existing rule for a category that is not on sale).
  Config     DealershipHiddenCategories = "bruiser" (the Piercer category) on Config.UI.GarageReplacement.
This is a display rule in the client only: the server catalogue, saved profiles, the starter car and the
buy actions are unchanged. To show the Piercers again, clear the attribute (no code change needed).
"""
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BEFORE = os.path.join(HERE, "..", "ui_artwork", "after", "GarageUI.lua")
PLACE_ID = 93959280828322
HIDDEN = "bruiser"
OLD = "local function categoryListed(c) if c.PurchaseDisabled~=true then return true end;"
NEW = ('local function categoryListed(c) if c.PurchaseDisabled~=true and not string.find(","..tostring(replacementConfig:GetAttribute("DealershipHiddenCategories") or "")..",",'
       '","..tostring(c.CategoryId)..",",1,true) then return true end;')


def djb2(text):
    x = 5381
    for b in text.encode("utf-8"):
        x = (x * 33 + b) % 4294967296
    return x


def main():
    before = io.open(BEFORE, encoding="utf-8", newline="").read()
    if before.count(OLD) != 1:
        raise SystemExit("anchor found %d times" % before.count(OLD))
    after = before.replace(OLD, NEW)
    os.makedirs(os.path.join(HERE, "after"), exist_ok=True)
    io.open(os.path.join(HERE, "after", "GarageUI.lua"), "w", encoding="utf-8", newline="").write(after)
    data = json.dumps({"placeId": PLACE_ID, "base": "scripts/exotic_category/ui_dealership/",
                       "scripts": {"GarageUI": {"path": ["ReplicatedStorage", "Modules", "Game", "Garage", "GarageUI"],
                                                "before": djb2(before), "after": djb2(after)}},
                       "attributes": [["", "DealershipHiddenCategories", HIDDEN]]}, sort_keys=True)
    engine = io.open(os.path.join(HERE, "..", "ui_artwork", "installer_engine.lua"), encoding="utf-8").read()
    for mode in ("AUDIT", "APPLY", "ROLLBACK"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])\n%s' % (mode, data, engine)
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print(json.dumps({"before": "%08x" % djb2(before), "after": "%08x" % djb2(after)}))


if __name__ == "__main__":
    main()
