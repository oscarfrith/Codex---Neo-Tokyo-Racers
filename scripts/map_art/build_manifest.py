"""Write manifest.json from detected_pois.json, the icon set and the cleaned tiles."""
import json
import pathlib

import common
import make_icons

HERE = pathlib.Path(__file__).parent

ROLES = {
    "Customisation": "place", "Garage": "place", "Dealership": "place",
    "Race": "activity", "TimeTrial": "activity", "Duel": "activity",
    "Job": "job", "TaxiFare": "job", "CourierPickup": "job",
    "TaxiDrop": "jobDrop", "CourierDrop": "jobDrop",
    "Waypoint": "waypoint", "Player": "player", "OtherPlayer": "player",
}
KINDS = {"Customisation": "Place", "Garage": "Place", "Race": "Race"}
LABELS = {"Customisation": "CUSTOMISATION", "Garage": "MY GARAGE", "Race": "RACE"}


def main():
    full = common.load_full()
    clean = common.load_full(HERE / "clean")
    pois = json.loads((HERE / "detected_pois.json").read_text(encoding="utf-8"))
    tiles = {}
    for name in common.TILES:
        src = json.loads((HERE / "tiles" / ("MapTile%s.json" % name)).read_text(encoding="utf-8"))
        changed = common.split_tile(full, name) != common.split_tile(clean, name)
        tiles["MapTile" + name] = {
            "file": "clean/MapTile%s.png" % name,
            "replacesAsset": src["asset"],
            "configPath": "ReplicatedStorage.Config.UI.DesktopFreeRoamHud.Assets.MapTile%s" % name,
            "pixelsChanged": changed,
            "needsUpload": changed,
        }
    icons = {}
    for key in make_icons.icons():
        icons[key] = {
            "file": "icons/%s.png" % key,
            "size": [128, 128],
            "role": ROLES[key],
            "anchorPoint": make_icons.ANCHORS.get(key, [0.5, 0.5]),
        }
    detected = []
    for p in pois:
        detected.append({
            "icon": p["key"],
            "meaning": p["meaning"],
            "suggestedKind": KINDS.get(p["key"], "Place"),
            "suggestedLabel": LABELS.get(p["key"], p["key"].upper()),
            "world": {"X": p["world"]["X"], "Y": 0, "Z": p["world"]["Z"]},
            "worldAccuracyStuds": round(common.STUDS_PER_PIXEL * 3, 1),
            "pixelCentre": p["pixelCentre"],
            "pixelBBox": p["pixelBBox"],
            "tile": p["tile"],
            "note": "Position is the centre of the baked glyph; prefer the world part (Dealership / My Garage / Customisation / race start) when Agent F's installer resolves one.",
        })
    manifest = {
        "generatedBy": "scripts/map_art (clean_tiles.py, make_icons.py, build_manifest.py)",
        "mapping": {
            "imageSize": [2048, 2048],
            "studsPerPixel": common.STUDS_PER_PIXEL,
            "formula": "X = (py + 0.5 - 1024) * spp ; Z = -(px + 0.5 - 1024) * spp  (scripts/route_guide/build_road_graph.py to_world)",
        },
        "configIconsPath": "ReplicatedStorage.Config.UI.MapIcons (attribute per key -> rbxassetid string after upload)",
        "icons": icons,
        "contactSheet": "icons/contact_sheet.png",
        "cleanedTiles": tiles,
        "detectedPois": detected,
        "notBakedIn": ["Dealership", "TimeTrial", "Duel", "jobs", "Waypoint", "players"],
    }
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(tiles, indent=1))


if __name__ == "__main__":
    main()
