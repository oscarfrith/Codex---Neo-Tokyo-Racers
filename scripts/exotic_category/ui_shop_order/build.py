"""Shop list order and rail order for body parts: builds the after-source and the guarded installer.

    py -3 scripts/exotic_category/ui_shop_order/build.py

Independent of the GarageUI chain (ui_artwork, ui_dealership, ui_underglow): it changes another script.

What changes:
  GarageModuleCardViewModel  the shop list breaks a tie by Price before id, so the standard, GT and EVO
                             versions of a body part read cheapest first (mesh/INTEGRATION.md, "Body parts
                             behave like core parts"). Core modules are unaffected: their variants already
                             differ by VariantOrder, which is compared first.
  Config                     ModuleArtwork.FrontBody SortOrder 32 and RearBody SortOrder 34, so the Build and
                             Customise rails list Front Body and Rear Body before the engines. Only Exotic has
                             those slots. ROLLBACK removes the two attributes, which returns the code defaults
                             (72 and 74), the values they had before.
"""
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BEFORE = os.path.join(HERE, "..", "stage_a", "client", "after", "GarageModuleCardViewModel.lua")
PLACE_ID = 93959280828322
OLD = ("\t\tif variantOrder[a.Variant]~=variantOrder[b.Variant] then return variantOrder[a.Variant]<variantOrder[b.Variant] end\n"
       "\t\treturn a.Id<b.Id\n\tend)\n\treturn rows\nend\n\nreturn ViewModel")
NEW = ("\t\tif variantOrder[a.Variant]~=variantOrder[b.Variant] then return variantOrder[a.Variant]<variantOrder[b.Variant] end\n"
       "\t\tif a.Price~=b.Price then return a.Price<b.Price end\n"
       "\t\treturn a.Id<b.Id\n\tend)\n\treturn rows\nend\n\nreturn ViewModel")


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
    for folder, text in (("before", before), ("after", after)):
        os.makedirs(os.path.join(HERE, folder), exist_ok=True)
        io.open(os.path.join(HERE, folder, "GarageModuleCardViewModel.lua"), "w", encoding="utf-8", newline="").write(text)
    data = json.dumps({"placeId": PLACE_ID, "base": "scripts/exotic_category/ui_shop_order/",
                       "scripts": {"GarageModuleCardViewModel": {"path": ["ReplicatedStorage", "Modules", "Game", "UI", "GarageModuleCardViewModel"],
                                                                 "before": djb2(before), "after": djb2(after)}},
                       "attributes": [["ModuleArtwork/FrontBody", "SortOrder", 32], ["ModuleArtwork/RearBody", "SortOrder", 34]]}, sort_keys=True)
    engine = io.open(os.path.join(HERE, "..", "ui_artwork", "installer_engine.lua"), encoding="utf-8").read()
    for mode in ("AUDIT", "APPLY", "ROLLBACK"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])\n%s' % (mode, data, engine)
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print(json.dumps({"before": "%08x" % djb2(before), "after": "%08x" % djb2(after)}))


if __name__ == "__main__":
    main()
