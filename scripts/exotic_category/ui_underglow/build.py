"""Per-category underglow diagram on the paint screen: builds the after-source and the guarded installer.

    py -3 scripts/exotic_category/ui_underglow/build.py

Runs after ui_dealership: its before-source is ui_dealership/after/GarageUI.lua. Roll this back first, then
ui_dealership, then ui_artwork.

What changes:
  GarageUI   the Underglow entry of the paint rail uses NavigationIcons.UnderglowSidebarIcon_<CategoryId>
             when that attribute exists, else UnderglowSidebarIcon as before.
  Config     NavigationIcons.UnderglowSidebarIcon_exotic (the Exotic underglow diagram), and the redrawn
             Exotic thrust colour diagram on ModuleArtwork.ThrustColour (Image_exotic). ROLLBACK removes both
             attributes; re-run ui_artwork APPLY afterwards if the thrust diagram should stay.
"""
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BEFORE = os.path.join(HERE, "..", "ui_dealership", "after", "GarageUI.lua")
PLACE_ID = 93959280828322
CATEGORY = "exotic"
UNDERGLOW = "rbxassetid://137313031963928"
THRUST = "rbxassetid://127812752445338"
OLD = 'Image=navIcon("UnderglowSidebarIcon")'
KEY = '"UnderglowSidebarIcon_"..tostring(currentCategory() and currentCategory().CategoryId)'
NEW = 'Image=navIcon((navigationIcons:GetAttribute(%s)~=nil and %s) or "UnderglowSidebarIcon")' % (KEY, KEY)


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
    data = json.dumps({"placeId": PLACE_ID, "base": "scripts/exotic_category/ui_underglow/",
                       "scripts": {"GarageUI": {"path": ["ReplicatedStorage", "Modules", "Game", "Garage", "GarageUI"],
                                                "before": djb2(before), "after": djb2(after)}},
                       "attributes": [["NavigationIcons", "UnderglowSidebarIcon_" + CATEGORY, UNDERGLOW],
                                      ["ModuleArtwork/ThrustColour", "Image_" + CATEGORY, THRUST]]}, sort_keys=True)
    engine = io.open(os.path.join(HERE, "..", "ui_artwork", "installer_engine.lua"), encoding="utf-8").read()
    for mode in ("AUDIT", "APPLY", "ROLLBACK"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])\n%s' % (mode, data, engine)
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print(json.dumps({"before": "%08x" % djb2(before), "after": "%08x" % djb2(after)}))


if __name__ == "__main__":
    main()
