"""Category-aware slot artwork for the garage UI: builds the after-sources and the guarded installer.

    py -3 scripts/exotic_category/ui_artwork/build.py

before/ holds the exact live sources of the two scripts as read from Space Racers v3 on 2026-10-04.
This script applies the anchored edits below, writes after/, and writes out_audit.lua, out_apply.lua and
out_rollback.lua, which check the place and the exact source of each script before they write.

What changes:
  GarageWorkspaceUI  Artwork lookups take a category id. A ModuleArtwork folder may carry
                     Image_<CategoryId> (a diagram for that category only) and Hidden_<CategoryId>=true
                     (leave that slot out of the Build and Customise rails for that category).
  GarageUI           passes the current category id to those lookups; slot cards use the same image.
  Config             Image_exotic on nine ModuleArtwork folders; Hidden_exotic on SidePods, FrontBumper
                     and RearBumper. Piercer is untouched: with no attribute the lookup behaves as before.
"""
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PLACE_ID = 93959280828322
CATEGORY = "exotic"
IMAGES = {"All": "128118074135601", "Cockpit": "81262312162264", "FrontBody": "83836476075409",
          "FrontEngine": "131895203472955", "Stabilisers": "105948755652652", "RearEngine": "87580925930089",
          "RearBody": "94927048868347", "Boost": "125156887089093", "Spoiler": "99681362447707"}
HIDDEN = ["SidePods", "FrontBumper", "RearBumper"]
CAT = "(currentCategory() and currentCategory().CategoryId)"
OVERRIDE = 'folder:GetAttribute("Image_"..tostring(categoryId))'
EDITS = {
    "GarageWorkspaceUI": [
        ("local function artworkRow(definition)", "local function artworkRow(definition,categoryId)"),
        ('Image=tostring(folder and folder:GetAttribute("Image") or ""),Folder=folder}',
         'Image=tostring((folder and categoryId and %s~=nil and %s~="" and %s) or (folder and folder:GetAttribute("Image")) or ""),'
         'Hidden=(folder~=nil and categoryId~=nil and folder:GetAttribute("Hidden_"..tostring(categoryId))==true),Folder=folder}'
         % (OVERRIDE, OVERRIDE, OVERRIDE)),
        ('function Artwork.ForPage(page) local result={}; for _,definition in ipairs(artworkDefinitions) do local item=artworkRow(definition); '
         'if (page=="Build" and item.ShowInBuild) or (page=="Customise" and item.ShowInCustomise) then',
         'function Artwork.ForPage(page,categoryId) local result={}; for _,definition in ipairs(artworkDefinitions) do local item=artworkRow(definition,categoryId); '
         'if not item.Hidden and ((page=="Build" and item.ShowInBuild) or (page=="Customise" and item.ShowInCustomise)) then'),
        ("function Artwork.ResolveImage(key) for _,definition in ipairs(artworkDefinitions) do local item=artworkRow(definition);",
         "function Artwork.ResolveImage(key,categoryId) for _,definition in ipairs(artworkDefinitions) do local item=artworkRow(definition,categoryId);"),
        ("function WorkspaceUI:ResolveImage(key,explicit)", "function WorkspaceUI:ResolveImage(key,explicit,categoryId)"),
        ('if explicit and explicit~="" then return explicit end; return Artwork.ResolveImage(key)',
         'if explicit and explicit~="" then return explicit end; return Artwork.ResolveImage(key,categoryId)'),
        ("function WorkspaceUI:ArtworkDefinitions(page) return Artwork.ForPage(page) end",
         "function WorkspaceUI:ArtworkDefinitions(page,categoryId) return Artwork.ForPage(page,categoryId) end"),
    ],
    "GarageUI": [
        ('workspaceUI:ArtworkDefinitions("Build")', 'workspaceUI:ArtworkDefinitions("Build",%s)' % CAT, 2),
        ('workspaceUI:ArtworkDefinitions("Customise")', 'workspaceUI:ArtworkDefinitions("Customise",%s)' % CAT, 1),
        ("table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=slotLabel(s,art),",
         "table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,Image=art.Image,DisplayName=slotLabel(s,art),"),
    ],
}
PATHS = {"GarageWorkspaceUI": ["ReplicatedStorage", "Modules", "Game", "UI", "GarageWorkspaceUI"],
         "GarageUI": ["ReplicatedStorage", "Modules", "Game", "Garage", "GarageUI"]}


def djb2(text):
    x = 5381
    for b in text.encode("utf-8"):
        x = (x * 33 + b) % 4294967296
    return x


def main():
    scripts = {}
    for name, edits in EDITS.items():
        before = io.open(os.path.join(HERE, "before", name + ".lua"), encoding="utf-8", newline="").read()
        after = before
        for edit in edits:
            old, new, count = edit if len(edit) == 3 else (edit[0], edit[1], 1)
            if after.count(old) != count:
                raise SystemExit("%s: anchor found %d times, expected %d: %s" % (name, after.count(old), count, old[:70]))
            after = after.replace(old, new)
        io.open(os.path.join(HERE, "after", name + ".lua"), "w", encoding="utf-8", newline="").write(after)
        scripts[name] = {"path": PATHS[name], "before": djb2(before), "after": djb2(after)}
    attrs = [[n, "Image_" + CATEGORY, "rbxassetid://" + i] for n, i in IMAGES.items()] + [[n, "Hidden_" + CATEGORY, True] for n in HIDDEN]
    data = json.dumps({"placeId": PLACE_ID, "scripts": scripts, "attributes": attrs}, sort_keys=True)
    engine = io.open(os.path.join(HERE, "installer_engine.lua"), encoding="utf-8").read()
    for mode in ("AUDIT", "APPLY", "ROLLBACK"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])\n%s' % (mode, data, engine)
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print(json.dumps({k: {"before": "%08x" % v["before"], "after": "%08x" % v["after"]} for k, v in scripts.items()}))


if __name__ == "__main__":
    main()
