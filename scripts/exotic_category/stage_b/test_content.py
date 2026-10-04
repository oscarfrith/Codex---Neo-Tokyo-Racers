"""Offline checks on the Stage B content (no Studio needed).

Usage:  py -3 scripts/exotic_category/stage_b/test_content.py [--balance PATH] [--catalogue-gen PATH] [--fill-from-donor]

With no arguments it uses the real balance.json and catalogue_gen.lua when both exist, else the stand-ins in
tests/fixtures (run tests/make_fixture.py first). Exit code 0 means every check passed.
"""
import argparse
import copy
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_content as bc  # noqa: E402
import numpy as np  # noqa: E402
import vbspec  # noqa: E402

FIXTURES = os.path.join(HERE, "tests", "fixtures")

# INTERFACE.md, written out again here on purpose: the test must not read the same data file as the builder.
COCKPITS = {
    "exotic_01": ("COCKPIT_EXOTIC_01", "Spider", "spider", "track", "E", 50000, 220),
    "exotic_02": ("COCKPIT_EXOTIC_02", "Curve", "curve", "analogue", "D", 150000, 390),
    "exotic_03": ("COCKPIT_EXOTIC_03", "Wedge", "wedge", "wedge", "C", 440000, 540),
    "exotic_04": ("COCKPIT_EXOTIC_04", "Longtail", "longtail", "longtail", "B", 1400000, 675),
    "exotic_05": ("COCKPIT_EXOTIC_05", "Hyper", "hyper", "hyper", "A", 4400000, 800),
    "exotic_06": ("COCKPIT_EXOTIC_06", "Gull", "gull", "concept", "S", 12500000, 938),
}
# SlotId: (label, ModuleType, folder, order, CountLabel, EnginePosition, id prefix, core?)
SLOTS = {
    "Engine1": ("Main Turbine", "Engine", "Engines", 1, "Engines", "Front", "MODULE_ENGINE_EXOTIC_", True),
    "Engine2": ("Side Engines", "Engine", "Engines_B", 2, "Engines", "Rear", "MODULE_ENGINE_B_EXOTIC_", True),
    "Stabilisers": ("Stabilisers", "Stabilisers", "Stabilisers", 3, "Stabilisers", None, "MODULE_STABILISER_EXOTIC_", True),
    "Boost": ("Afterburner", "Boost", "Boost", 4, "Boost", None, "MODULE_BOOST_EXOTIC_", True),
    "FrontBumper": ("Splitter", "FrontBumper", "FrontBumpers", 5, "Splitters", None, "MODULE_FRONTBUMPER_EXOTIC_", False),
    "RearBumper": ("Diffuser", "RearBumper", "RearBumpers", 6, "Diffusers", None, "MODULE_REARBUMPER_EXOTIC_", False),
    "RearSpoiler": ("Wing", "RearSpoiler", "RearSpoilers", 7, "Wings", None, "MODULE_REARSPOILER_EXOTIC_", False),
    "SidePods": ("Side Pods", "SidePods", "SidePods", 8, "Side Pods", None, "MODULE_SIDEPODS_EXOTIC_", False),
    "FrontBody": ("Nose", "FrontBody", "FrontBodies", 9, "Noses", None, "MODULE_FRONTBODY_EXOTIC_", False),
    "RearBody": ("Engine Deck", "RearBody", "RearBodies", 10, "Engine Decks", None, "MODULE_REARBODY_EXOTIC_", False),
}
VARIANTS = ("STANDARD", "LIGHTWEIGHT", "POWER")
LEGACY_DEFAULTS = {
    "DefaultEngineModuleId": "Engine1", "DefaultFrontEngineModuleId": "Engine1", "DefaultEngineBModuleId": "Engine2",
    "DefaultRearEngineModuleId": "Engine2", "DefaultStabiliserModuleId": "Stabilisers", "DefaultStabilisersModuleId": "Stabilisers",
    "DefaultBoostModuleId": "Boost",
}
NEW_DEFAULTS = {"Default%sModuleId" % s: s for s in ("FrontBody", "RearBody", "SidePods", "FrontBumper", "RearBumper", "RearSpoiler")}
# scripts/exotic_category/mesh/INTEGRATION.md, written out again here on purpose (D1 to D13).
MESH_ASSET_ID = "121164261170819"
MESH_CARS = {"01": ("C", 40.0), "02": ("B", 20.0), "03": ("D", 60.0), "04": ("E", 80.0), "05": ("A", 0.0), "06": ("F", 100.0)}  # kit number: (car letter in the asset, file offset X)
MESH_SLOT_TAGS = {"FrontBody": "NOSE", "RearBody": "TAIL", "Engine1": "FPOD", "Engine2": "RPOD", "Stabilisers": "STAB", "Boost": "BOOST", "RearSpoiler": "WING"}
MESH_TRIM_OF_VARIANT = {"STANDARD": "STD", "LIGHTWEIGHT": "GT", "POWER": "EVO", None: "STD", "GT": "GT", "EVO": "EVO"}
MESH_BODY_TRIM_SLOTS = ("FrontBody", "RearBody", "RearSpoiler")
MESH_BODY_TRIMS = ("GT", "EVO")
MESH_EMPTY_SLOTS = ("SidePods", "FrontBumper", "RearBumper")
MESH_MODULE_CODES = {"primary": "P", "secondary": "S", "detail": "D", "glass": "D", "thrust": "T", "neon": "N", "lights": "L", "lights_red": "R"}
MESH_COCKPIT_CODES = {"primary": "P", "secondary": "S", "detail": "D", "glass": "G"}
MESH_SEATS = {"driver": [-1.5, -0.1, 0.45], "passenger": [1.5, -0.1, 0.45]}  # D13 starting values, not yet measured
MESH_SEATS_BY_COCKPIT = {"exotic_06": {"driver": [-1.1, -0.1, 0.45], "passenger": [1.1, -0.1, 0.45]}}  # Gull: seats 0.4 further in
# Stock builds over the 16-socket guard. exotic_02: 5 hover dust + 2 + 2 engine + 4 stabiliser + 4 boost (B_BOOST_STD).
SOCKET_GUARD_EXCEPTIONS = {"exotic_02": 17}
SOCKET_RULES = {"Engine1": ("VFX_EngineJet_", {"EngineJet_Exotic"}), "Engine2": ("VFX_EngineJet_", {"EngineJet_Exotic"}),
                "Boost": ("VFX_BoostJet_", {"BoostJet_Exotic"}),
                "Stabilisers": ("VFX_StabiliserJet_", {"StabiliserJet_ExoticLeft", "StabiliserJet_ExoticRight"})}

EXPECTED_PARTS = {}  # filled in main(): (primitive, mesh) part counts for the full scope

failures = []
passed = 0


def check(condition, message):
    global passed
    if condition:
        passed += 1
    else:
        failures.append(message)


def expected_module_ids(numbers):
    out = {}
    for n in numbers:
        for slot, row in SLOTS.items():
            for variant in (VARIANTS if row[7] else (None,)):
                out[row[6] + n + ("_" + variant if variant else "")] = (slot, n, variant)
            if n in MESH_CARS and slot in MESH_BODY_TRIM_SLOTS:  # D6: two new ids per body slot per mesh kit
                for trim in MESH_BODY_TRIMS:
                    out[row[6] + n + "_" + trim] = (slot, n, trim)
    return out


def mesh_source(slot, n, variant):
    """The source group name in the asset for a module of a mesh kit, or None (D1, D4, D5, D8)."""
    if n not in MESH_CARS or slot not in MESH_SLOT_TAGS:
        return None
    return "%s_%s_%s" % (MESH_CARS[n][0], MESH_SLOT_TAGS[slot], MESH_TRIM_OF_VARIANT[variant])


def instance_names(content):
    """(owner id, is body module, name) for every named instance the installer creates inside a module."""
    slot_set = {s["slotId"]: s["folderSet"] for s in content["slots"]}
    for m in content["modules"]:
        body = not SLOTS[m["slot"]][7]
        yield m["id"], body, m["id"]
        for name in m["folderPath"][1:]:
            yield m["id"], body, name
        for folder in content["moduleFolders"][slot_set[m["slot"]]]:
            yield m["id"], body, folder["name"]
        shape = content["shapes"][m["shape"]]
        for r in shape["parts"]:
            yield m["id"], body, r[0] + "_" + content["channels"][r[10]]["suffix"]
        for s in shape.get("sockets", []):
            yield m["id"], body, s["name"]
        for p in m.get("upgradePaths", []):
            yield m["id"], body, "path:" + p["name"]
        for fixed in ("VehiclePerformanceV2UpgradePaths", "ModuleRoot_DoNotRename", "MountAttachment"):
            yield m["id"], body, fixed


def with_data(changes, run):
    """Run a build with data files changed in memory. changes = {"seats.json": function(data)}. Returns (result, error text)."""
    real = bc.load_json

    def fake(path):
        data = real(path)
        change = changes.get(os.path.basename(path)) if os.path.dirname(os.path.abspath(path)) == os.path.abspath(bc.DATA_DIR) else None
        if change:
            data = copy.deepcopy(data)
            change(data)
        return data

    bc.load_json = fake
    try:
        return run(), None
    except bc.BuildError as error:
        return None, str(error)
    finally:
        bc.load_json = real


def check_scope(scope, args, spec, reference, live):
    try:
        content, report = bc.build_content("AUDIT", scope, args.balance, args.catalogue_gen, bc.CAPTURE_PATH, args.fill_from_donor)
    except bc.BuildError as error:
        failures.append("[%s] build failed: %s" % (scope, error))
        return
    catalogue_gen = report.pop("catalogueGen")
    tag = "[%s] " % scope
    numbers = ["01", "02", "03", "04", "05", "06"] if scope == "full" else ["03"]
    mesh_data = bc.load_json(bc.MESH_PATH)
    mesh_numbers = [n for n in numbers if n in MESH_CARS]
    want_cockpits = {"exotic_" + n for n in numbers}
    want_modules = expected_module_ids(numbers)

    # Counts and ids.
    check(len(content["cockpits"]) == len(numbers), tag + "cockpit count %d" % len(content["cockpits"]))
    # A kit has 18 modules; a mesh kit has 6 more (GT and EVO of three body slots). Groups: a kit has a cockpit and ten
    # module shapes; a mesh kit has a cockpit, 21 mesh module shapes (one per ModuleId) and its three primitive body shapes.
    check(len(content["modules"]) == 18 * len(numbers) + 6 * len(mesh_numbers), tag + "module count %d" % len(content["modules"]))
    check(len(content["shapes"]) == 11 * (len(numbers) - len(mesh_numbers)) + 25 * len(mesh_numbers), tag + "cockpit+shape group count %d" % len(content["shapes"]))
    if scope == "full":
        check(len(content["modules"]) == 144 and len(content["shapes"]) == 150, tag + "full scope must hold 144 modules and 150 groups")
        check(sum(1 for m in content["modules"] if SLOTS[m["slot"]][7]) == 72, tag + "72 core modules")
        check(sum(1 for m in content["modules"] if not SLOTS[m["slot"]][7]) == 72, tag + "72 body modules (36 plus the 36 mesh trims)")
        check(sorted(m["id"] for m in content["modules"] if m["id"].endswith(("_GT", "_EVO"))) == sorted(
            "MODULE_%s_EXOTIC_%s_%s" % (stem, n, trim) for stem in ("FRONTBODY", "REARBODY", "REARSPOILER") for n in numbers for trim in ("GT", "EVO")),
            tag + "the 36 new ModuleIds of D6")
    else:
        check(sum(1 for m in content["modules"] if SLOTS[m["slot"]][7]) == 12, tag + "pilot has 12 core modules")
        check(sum(1 for m in content["modules"] if not SLOTS[m["slot"]][7]) == 12, tag + "pilot has 12 body modules (6 plus the 6 mesh trims)")
    check({c["id"] for c in content["cockpits"]} == want_cockpits, tag + "cockpit ids")
    check({m["id"] for m in content["modules"]} == set(want_modules), tag + "module ids match INTERFACE.md")
    check(len({m["id"] for m in content["modules"]}) == len(content["modules"]), tag + "module ids unique")

    # Category and slots.
    cat = content["category"]
    check(cat["folder"] == "EXOTIC" and cat["afterFolder"] == "PIERCER", tag + "category folder")
    check(cat["attributes"]["CategoryId"] == "exotic" and cat["attributes"]["DisplayName"] == "Exotic" and cat["attributes"]["FeatureFlag"] == "VehicleClass_exotic", tag + "category attributes")
    check([s["slotId"] for s in content["slots"]] == sorted(SLOTS, key=lambda k: SLOTS[k][3]), tag + "slot order")
    for s in content["slots"]:
        row, a = SLOTS[s["slotId"]], s["attributes"]
        want = {"SlotId": s["slotId"], "DisplayName": row[0], "RailLabel": row[0], "ModuleType": row[1], "AllowedModuleFolder": row[2],
                "Order": row[3], "CountLabel": row[4], "FixedSlot": True}
        if row[5]:
            want["EnginePosition"] = row[5]
        check(a == want, tag + "slot %s attributes %r" % (s["slotId"], a))
    check([f["name"] for f in content["moduleTypeFolders"]] == [SLOTS[k][2] for k in sorted(SLOTS, key=lambda k: SLOTS[k][3])], tag + "module type folders")

    # Modules.
    kit_of = {n: COCKPITS["exotic_" + n][3] for n in numbers}
    shape_parts_spec = {}
    mesh_shapes = {}  # shape key -> (slot, entry of data/mesh.json, is core)
    for m in content["modules"]:
        slot, n, variant = want_modules[m["id"]]
        row, a = SLOTS[slot], m["attributes"]
        mid = m["id"]
        check(m["slot"] == slot, tag + mid + " slot")
        check(a["ModuleId"] == mid and a["CategoryId"] == "exotic" and a["TemplateType"] == "Module", tag + mid + " identity")
        check(a["ModuleType"] == row[1] and a["ModuleFolder"] == row[2], tag + mid + " ModuleType/ModuleFolder match its slot")
        check(m["folderPath"] == [row[2]] + (["Exotic_" + n] if row[7] else []), tag + mid + " folder path %r" % m["folderPath"])
        spec_id = spec["kits"][kit_of[n]]["modules"][slot]
        source = mesh_source(slot, n, variant)
        check((source is not None) == (mid in mesh_data["modules"]), tag + mid + " is a mesh module exactly when the contract says so")
        if source is None:
            check(m["shape"] == "%s/%s" % (slot, spec_id), tag + mid + " shape %s" % m["shape"])
            check("folderSet" not in m and set(m["palette"]) == set("PSDGNLT"), tag + mid + " a primitive module is planned as before")
        else:
            check(m["shape"] == "%s/%s" % (slot, source) and mesh_data["modules"][mid]["source"] == source, tag + mid + " mesh shape %s" % m["shape"])
            check(m["shape"] not in mesh_shapes, tag + mid + " has its own mesh shape")
            mesh_shapes[m["shape"]] = (slot, mesh_data["modules"][mid], row[7])
            check(m["palette"]["L"] == [255, 255, 255] and m["palette"]["R"] == [255, 30, 20], tag + mid + " mesh lamps are fixed white and red (D10)")
        display = spec["modules"][slot][spec_id]["name"]
        if not row[7] and variant:
            display += " " + variant  # D7: a body trim is the base name plus the trim
        check(a["DisplayName"] == display and a["CardTitle"] == display and a["ModuleName"] == display, tag + mid + " DisplayName/CardTitle/ModuleName")
        if not row[7] and variant:
            base = next(x for x in content["modules"] if x["id"] == mid[:-len(variant) - 1])
            differing = {k for k in set(a) | set(base["attributes"]) if a.get(k) != base["attributes"].get(k)}
            check(differing == {"ModuleId", "DisplayName", "ModuleName", "CardTitle", "Price"} and "VariantName" not in a, tag + mid + " differs from its base part in %s" % sorted(differing))
            check(a["Price"] == int(math.floor({"GT": 2, "EVO": 3.5}[variant] * base["attributes"]["Price"] / 100 + 0.5)) * 100 and a["NeonPrice"] == base["attributes"]["NeonPrice"],
                  tag + mid + " Price is base x 2 (GT) or x 3.5 (EVO), rounded to 100")
            check(m.get("upgradePathDonor") == base.get("upgradePathDonor") and m.get("upgradePaths") == base.get("upgradePaths"), tag + mid + " upgrade paths as its base part")
        check(a["RatingReferenceCockpitId"] == "exotic_03", tag + mid + " RatingReferenceCockpitId")
        check(a.get("V2Materialised") is True and a.get("RetiredFromCatalog") is False, tag + mid + " V2Materialised/RetiredFromCatalog")
        check(isinstance(a.get("Price"), (int, float)) and isinstance(a.get("NeonPrice"), (int, float)), tag + mid + " Price/NeonPrice")
        if row[7]:
            check(a["ModuleSlot"] == {"Engine": "Engine", "Stabilisers": "Stabilisers", "Boost": "Boost"}[row[1]], tag + mid + " ModuleSlot")
            check(a["SourceCockpitId"] == "exotic_" + n and a["V2PublishedModuleId"] == mid, tag + mid + " SourceCockpitId/V2PublishedModuleId")
            check(a["EnginePosition"] == (row[5] or "") and a["RearEngine"] is (slot == "Engine2"), tag + mid + " EnginePosition/RearEngine")
            check("PurchasePrice" in a and "VariantName" in a and "VariantOrder" in a, tag + mid + " PurchasePrice/Variant attributes")
            donor = reference["modules"]["MODULE_%s_BRUISER_03_%s" % ({"Engine1": "ENGINE", "Engine2": "ENGINE_B", "Stabilisers": "STABILISER", "Boost": "BOOST"}[slot], variant)]
        else:
            check(a["ModuleSlot"] == slot, tag + mid + " ModuleSlot")
            check("SourceCockpitId" not in a and "PurchasePrice" not in a, tag + mid + " body modules carry no SourceCockpitId/PurchasePrice")
            donor = reference["modules"]["MODULE_%s_LVL1" % {"FrontBody": "FRONTBUMPER", "RearBody": "REARBUMPER"}.get(slot, slot.upper())]
        missing = sorted(set(donor) - set(a))
        check(not missing, tag + mid + " lacks donor attributes %s" % missing)
        check(("upgradePathDonor" in m) != bool(m.get("upgradePaths")), tag + mid + " needs exactly one upgrade path source")
        if slot in ("FrontBody", "RearBody"):
            check(bool(m.get("upgradePaths")), tag + mid + " needs explicit upgrade paths (new PathIds)")
        shape = content["shapes"].get(m["shape"], {"parts": []})
        check(m["partCount"] == len(shape["parts"]) and m["partCount"] >= 1, tag + mid + " has at least one part")
        if source is None:
            shape_parts_spec[m["shape"]] = (slot, spec["modules"][slot][spec_id]["parts"])
        else:
            codes = {r[10] for r in shape["parts"]}
            lamps = bool(codes & {"L", "R"})
            want_set = ("coreLamps" if lamps else None) if row[7] else ("bodyLamps" if lamps and slot not in ("FrontBody", "RearBody") else None)
            check(m.get("folderSet") == want_set, tag + mid + " folder set %r (lamps go in LIGHTS_AlwaysOn on any mesh module that has them)" % m.get("folderSet"))

    # Geometry: part counts equal the spec (driver dummy dropped), channels land in the right folders.
    for key, (slot, parts) in shape_parts_spec.items():
        flat = bc.flatten(parts)
        recs = content["shapes"][key]["parts"]
        check(len(recs) == len([p for p in flat if p["ch"] != "driver"]) == len(flat), tag + key + " part count equals the spec")
        codes = {r[10] for r in recs}
        core = SLOTS[slot][7]
        allowed = set("PSDT") if core else (set("PSDL") if slot in ("FrontBody", "RearBody") else set("PSDN"))
        check(codes <= allowed, tag + key + " channels %s" % sorted(codes))
        check(("T" in codes) == core, tag + key + " thrust parts only on engines, stabilisers and boost")
        for p, r in zip(flat, recs):
            check(r[0] == p["shape"] and r[1:4] == p["size"] and r[4:7] == p["pos"] and r[7:10] == p["rot"], tag + key + " part data equals the flattened spec")
        check(len(recs[0]) == 11, tag + key + " record width")
        check("mesh" not in content["shapes"][key], tag + key + " a primitive shape carries no mesh data")

    # Mesh geometry (D1 to D3, D10): one record per source part of data/mesh.json, in root space, with the mapped channel.
    def check_mesh_shape(key, entry, codes_map, n):
        shape = content["shapes"][key]
        recs = shape["parts"]
        check(shape.get("mesh") == {"fileOffsetX": MESH_CARS[n][1]} and entry["car"] == MESH_CARS[n][0], tag + key + " file offset of car %s" % MESH_CARS[n][0])
        check([r[11] for r in recs] == sorted(entry["parts"]) and len(recs) >= 1, tag + key + " one record per source part, in name order")
        for r in recs:
            part = entry["parts"][r[11]]
            check(len(r) == 12 and r[0] == "mesh" and r[7:10] == [0.0, 0.0, 0.0], tag + key + " mesh record form %r" % r)
            check(r[11].startswith(key.split("/")[1] + "__") and r[11].endswith("__" + part["channel"]), tag + key + " part name %s" % r[11])
            check(r[10] == codes_map.get(part["channel"]), tag + key + " %s channel %s maps to code %s" % (r[11], part["channel"], r[10]))
            check(all(abs(x - y) <= 5e-5 for x, y in zip(r[1:4], part["size"])) and all(abs(x - y) <= 5e-5 for x, y in zip(r[4:7], part["centre"])),
                  tag + key + " %s size and centre equal data/mesh.json" % r[11])
        return recs

    for key, (slot, entry, core) in mesh_shapes.items():
        recs = check_mesh_shape(key, entry, MESH_MODULE_CODES, "%02d" % entry["kit"])
        codes = {r[10] for r in recs}
        check("G" not in codes and codes <= (set("PSDNLRT") if core else set("PSDNLR")), tag + key + " channels %s (modules carry no glass)" % sorted(codes))
        check(("T" in codes) == core, tag + key + " thrust parts only on engines, stabilisers and boost")
        check(entry["slot"] == slot, tag + key + " slot in data/mesh.json")
    for c in content["cockpits"]:
        row = COCKPITS[c["id"]]
        flat = bc.flatten(spec["cockpits"][row[2]]["parts"])
        recs = content["shapes"][c["shape"]]["parts"]
        n = c["id"][-2:]
        if n in MESH_CARS:
            check(c["shape"] == "Cockpit/%s_COCKPIT_STD" % MESH_CARS[n][0], tag + c["id"] + " mesh shape")
            check_mesh_shape(c["shape"], mesh_data["cockpits"][c["id"]], MESH_COCKPIT_CODES, n)
            check(len(recs) == c["partCount"] and {r[10] for r in recs} == set("PSDG"), tag + c["id"] + " mesh cockpit has primary, secondary, detail and glass")
            check(c.get("emptySlots") == list(MESH_EMPTY_SLOTS), tag + c["id"] + " slots that start empty (D8)")
        else:
            check(c["shape"] == "Cockpit/" + row[2], tag + c["id"] + " shape")
            check(len(recs) == len(flat) - 2 == c["partCount"], tag + c["id"] + " part count equals the spec minus the two driver dummy parts")
            check("emptySlots" not in c and "mesh" not in content["shapes"][c["shape"]], tag + c["id"] + " a primitive cockpit is planned as before")
        check({r[10] for r in recs} <= set("PSDG"), tag + c["id"] + " cockpit channels")
        check(not content["shapes"][c["shape"]].get("sockets"), tag + c["id"] + " cockpit shape has no module sockets")
    mesh_records = [r for v in content["shapes"].values() for r in v["parts"] if r[0] == "mesh"]
    check(len({r[11] for r in mesh_records}) == len(mesh_records), tag + "no source mesh part is used twice")
    if mesh_numbers:
        check(content.get("mesh") == {"assetId": MESH_ASSET_ID, "turnYDegrees": 180, "centreTolerance": 0.05, "partCount": len(mesh_records)}, tag + "mesh asset in the content: %r" % content.get("mesh"))
        check(str(mesh_data["assetId"]) == MESH_ASSET_ID and mesh_data["turnYDegrees"] == 180, tag + "data/mesh.json asset id")
        check(report["meshAssetId"] == MESH_ASSET_ID and report["meshParts"] == len(mesh_records), tag + "the summary names the mesh asset")
    else:
        check("mesh" not in content and not mesh_records and report["meshAssetId"] is None, tag + "no mesh asset in a scope without mesh kits")
    if scope == "full":
        # Before the mesh kits: 199 cockpit parts and 793 module parts, all primitive. All six cockpits (199) and the
        # 42 mesh-replaced module shapes (675 parts) left; 24 cockpit and 536 module mesh parts came. The 18 shapes of
        # the three slots that start empty (118 parts) stay primitive.
        cockpit_parts = [r for c in content["cockpits"] for r in content["shapes"][c["shape"]]["parts"]]
        module_parts = [r for k, v in content["shapes"].items() if not k.startswith("Cockpit/") for r in v["parts"]]
        check((sum(1 for r in cockpit_parts if r[0] != "mesh"), sum(1 for r in cockpit_parts if r[0] == "mesh")) == EXPECTED_PARTS["cockpit"], tag + "cockpit parts %d primitive + %d mesh" % (
            sum(1 for r in cockpit_parts if r[0] != "mesh"), sum(1 for r in cockpit_parts if r[0] == "mesh")))
        check((sum(1 for r in module_parts if r[0] != "mesh"), sum(1 for r in module_parts if r[0] == "mesh")) == EXPECTED_PARTS["module"], tag + "unique module parts %d primitive + %d mesh" % (
            sum(1 for r in module_parts if r[0] != "mesh"), sum(1 for r in module_parts if r[0] == "mesh")))
        check(len(mesh_data["modules"]) == 126 and len(mesh_shapes) == 126 and len(mesh_records) == 560, tag + "126 mesh modules, 560 mesh parts")

    # Sockets.
    for key, shape in content["shapes"].items():
        slot = key.split("/")[0]
        sockets = shape.get("sockets", [])
        if slot in SOCKET_RULES:
            prefix, templates = SOCKET_RULES[slot]
            check(len(sockets) >= 1, tag + key + " has at least one socket")
            check(len(sockets) <= 4, tag + key + " has at most four sockets")
            if key in mesh_shapes:
                # A mesh module has one thrust MeshPart for all its nozzles: measure to its bounding box (D12).
                wanted = {w["name"]: w for w in mesh_shapes[key][1]["sockets"]}
                check(sorted(wanted) == [s["name"] for s in sockets], tag + key + " sockets are the ones data/mesh.json lists")
                thrust = [(np.array(r[4:7]) - np.array(r[1:4]) / 2, np.array(r[4:7]) + np.array(r[1:4]) / 2) for r in shape["parts"] if r[10] == "T"]
            else:
                thrust = [p for p in bc.flatten(shape_parts_spec[key][1]) if p["ch"] == "thrust"]
            for s in sockets:
                check(s["name"].startswith(prefix) and s["template"] in templates, tag + key + " socket %s naming" % s["name"])
                d = vbspec.rot_matrix(s["orientation"]) @ np.array([0.0, 0.0, 1.0])
                if key in mesh_shapes:
                    want = wanted.get(s["name"], {"position": [9e9] * 3, "dir": [0, 0, 0]})
                    check(all(abs(x - y) <= 5e-5 for x, y in zip(s["position"], want["position"])), tag + key + " socket %s position equals data/mesh.json" % s["name"])
                    check(float(np.linalg.norm(d - np.array(want["dir"], dtype=float))) < 1e-6, tag + key + " socket %s local +Z is the flame direction of data/mesh.json (%s)" % (s["name"], np.round(d, 3)))
                    point = np.array(s["position"])
                    near = min(float(np.linalg.norm(np.maximum(np.maximum(lo - point, point - hi), 0.0))) for lo, hi in thrust)
                else:
                    near = min(float(np.linalg.norm(np.array(s["position"]) - np.array(p["pos"]))) for p in thrust)
                check(near < 1.6, tag + key + " socket %s is %.2f studs from the nearest thrust part" % (s["name"], near))
                if slot == "Stabilisers":
                    left = s["position"][0] < 0
                    check(("_Left" in s["name"]) == left and ("_Right" in s["name"]) == (not left), tag + key + " socket %s side" % s["name"])
                    check(s["template"] == ("StabiliserJet_ExoticLeft" if left else "StabiliserJet_ExoticRight"), tag + key + " socket %s template side" % s["name"])
                    check(d[1] < -0.2 or d[2] > 0.9, tag + key + " stabiliser socket %s fires down or back (%s)" % (s["name"], np.round(d, 2)))
                else:
                    check(d[2] > 0.9 or d[1] > 0.9, tag + key + " socket %s fires back or up (%s)" % (s["name"], np.round(d, 2)))
                    check(abs(d[0]) < 1e-6, tag + key + " socket %s has no sideways component" % s["name"])
            if slot == "Stabilisers":
                check(len(sockets) == 4 and sum(1 for s in sockets if "_Left" in s["name"]) == 2, tag + key + " one socket per corner unit")
            xs = sorted(round(s["position"][0], 3) for s in sockets)
            check(all(abs(a + b) < 1e-6 for a, b in zip(xs, reversed(xs))), tag + key + " sockets are mirror-symmetric")
        else:
            check(not sockets, tag + key + " body modules and cockpits have no jet sockets")
    for cid, count in report["socketsPerStockVehicle"].items():
        # The guard is 16 (VFX cost is per socket; there is no limit in code). One known exception, kept exact so that it
        # cannot grow unseen: the stock Curve has 17, because data/mesh.json gives its Standard boost four jets (D12).
        check(10 <= count <= SOCKET_GUARD_EXCEPTIONS.get(cid, 16), tag + cid + " stock build has %d sockets (Piercer has 12)" % count)
        if cid in SOCKET_GUARD_EXCEPTIONS:
            check(count == SOCKET_GUARD_EXCEPTIONS[cid], tag + cid + " stock build has %d sockets; the recorded exception is %d" % (count, SOCKET_GUARD_EXCEPTIONS[cid]))

    # Cockpits.
    paints = bc.native_paints(spec)
    module_slot = {m["id"]: m["slot"] for m in content["modules"]}
    constants = bc.piercer_cockpit_constants(reference)
    seats = bc.load_json(os.path.join(bc.DATA_DIR, "seats.json"))
    for c in content["cockpits"]:
        row, a = COCKPITS[c["id"]], c["attributes"]
        cid, n = c["id"], c["id"][-2:]
        check(c["model"] == row[0] and a["DisplayName"] == row[1], tag + cid + " names")
        check(a["CockpitId"] == cid and a["V2PublishedCockpitId"] == cid and a["CategoryId"] == "exotic" and a["TemplateType"] == "Cockpit", tag + cid + " identity")
        check(a["MenuImage"] == "" and a["PreviewImage"] == "", tag + cid + " images are empty")
        check(a.get("V2Materialised") is True, tag + cid + " V2Materialised")
        check(a["TargetTier"] == row[4] and a["Price"] == row[5] and a["TargetStockPI"] == row[6], tag + cid + " tier, price and target")
        check(a["StandardAudioProfileId"] == "GENERIC_STANDARD_AUDIO", tag + cid + " audio profile")
        empty = MESH_EMPTY_SLOTS if n in MESH_CARS else ()
        for name, slot in list(LEGACY_DEFAULTS.items()) + list(NEW_DEFAULTS.items()):
            want = SLOTS[slot][6] + n + ("_STANDARD" if SLOTS[slot][7] else "")
            if slot in empty:
                # D8: the slot starts empty. The module still exists (primitive); the cockpit just does not default to it.
                check(name not in a and module_slot.get(want) == slot, tag + cid + " declares no %s" % name)
            else:
                check(a.get(name) == want and module_slot.get(want) == slot, tag + cid + " %s" % name)
        check(len([k for k in a if k.startswith("Default") and k.endswith("ModuleId")]) == 13 - len(empty), tag + cid + " has %d default module attributes" % (13 - len(empty)))
        if n in MESH_CARS:
            check(seats.get("overrides", {}).get(cid) == MESH_SEATS_BY_COCKPIT.get(cid, MESH_SEATS), tag + cid + " data/seats.json holds the D13 starting override")
        paint = paints[row[2]]
        check(a["DefaultPrimaryColor"] == {"__c3": bc.hex_rgb(paint["primary"])} and a["DefaultSecondaryColor"] == {"__c3": bc.hex_rgb(paint["secondary"])}
              and a["DefaultNeonColor"] == {"__c3": bc.hex_rgb(paint["neon"])}, tag + cid + " default colours come from the native paint")
        check(a["DefaultDetailColor"] == {"__c3": [34, 37, 43]} and a["DefaultFrontLightsColor"] == {"__c3": [252, 250, 255]} and a["DefaultRearLightsColor"] == {"__c3": [255, 116, 116]}, tag + cid + " fixed default colours")
        torso = [p for p in bc.flatten(spec["cockpits"][row[2]]["parts"]) if p["ch"] == "driver" and p["shape"] == "block"][0]
        driver = [a["DriverSeatOffset" + axis] for axis in "XYZ"]
        passenger = [a["PassengerSeatOffset" + axis] for axis in "XYZ"]
        override = seats.get("overrides", {}).get(cid)
        if override:
            check(driver == [bc.clean(v, 3) for v in override["driver"]] and passenger == [bc.clean(v, 3) for v in override["passenger"]], tag + cid + " seat offsets equal the override in data/seats.json")
        else:
            rule = seats["rule"]
            check(a["DriverSeatOffsetX"] == torso["pos"][0] and a["PassengerSeatOffsetX"] == -torso["pos"][0], tag + cid + " seat X")
            check(a["DriverSeatOffsetZ"] == torso["pos"][2] == a["PassengerSeatOffsetZ"], tag + cid + " seat Z")
            check(abs(a["DriverSeatOffsetY"] + rule["rootPartCentreAboveSeatTop"] + 0.225 - torso["pos"][1]) < 1e-9 and a["PassengerSeatOffsetY"] == a["DriverSeatOffsetY"], tag + cid + " seat Y puts the root part on the dummy torso")
            check(rule["seatSize"] == [2.2, 0.45, 2.2], tag + cid + " seat size as DriverSeatServer.prepSeat and addPassengerSeat set it")
        check(a["DriverSeatOffsetX"] < 0 < a["PassengerSeatOffsetX"], tag + cid + " driver on the left, passenger on the right")
        check(all(isinstance(v, (int, float)) and not isinstance(v, bool) and abs(v) <= 40 for v in driver + passenger), tag + cid + " seat offsets are numbers inside the +-40 clamp")
        check(a.get("OwnedByDefault") is False, tag + cid + " OwnedByDefault is false (a paid cockpit)")
        for name, value in constants.items():
            if name not in ("CategoryId", "TemplateType") and not name.startswith("Default"):
                check(name in a, tag + cid + " carries the Piercer constant %s" % name)
        check(all(isinstance(a.get(name), (int, float)) for name in bc.RAW), tag + cid + " has the 17 raw stats")
        check(c["tierDonorCockpitId"] in reference["cockpits"] and reference["cockpits"][c["tierDonorCockpitId"]]["TargetTier"] == row[4], tag + cid + " tier donor")

    # Names the game matches on.
    for owner, body, name in instance_names(content):
        lower = name.lower()
        if name.startswith("path:"):
            continue  # upgrade path folders are reported by the builder as warnings; they are not ancestors of parts
        check(not any(w in lower for w in bc.FORBIDDEN_ANY_MODULE), tag + owner + " instance name %r has a forbidden word" % name)
        if body:
            check(not any(w in lower for w in bc.FORBIDDEN_BODY_MODULE), tag + owner + " body instance name %r has engine/boost/stabiliser" % name)
    for key, shape in content["shapes"].items():
        for r in shape["parts"]:
            if r[10] in ("L", "R"):
                check("neon" not in (r[0] + "_" + content["channels"][r[10]]["suffix"]).lower(), tag + key + " lamp part name has no 'neon'")
    check(content["channels"]["T"]["paintChannel"] == "ThrustColor" and content["channels"]["L"]["paintChannel"] == "Lights", tag + "channel names")
    check(content["channels"]["R"] == {"material": "Neon", "transparency": 0, "suffix": "lampred", "paintChannel": "Lights", "folder": "L"}, tag + "the red lamp channel (D10)")
    lights = [f for f in content["moduleFolders"]["coreLamps"] if f["name"] == "LIGHTS_AlwaysOn"]
    check(len(lights) == 1 and lights[0]["channel"] == "L" and lights[0]["attributes"]["PaintChannel"] == "Lights"
          and [f for f in content["moduleFolders"]["coreLamps"] if f["name"] != "LIGHTS_AlwaysOn"] == content["moduleFolders"]["core"], tag + "coreLamps is the core folder set plus LIGHTS_AlwaysOn")

    # Fingerprints against the spec and against the live blockout measurement.
    all_fp = bc.all_fingerprints(spec)
    mesh_keys = set(mesh_shapes) | {c["shape"] for c in content["cockpits"] if c["id"][-2:] in MESH_CARS}
    check(set(content["fingerprints"]) == set(content["shapes"]) - mesh_keys, tag + "one spec fingerprint per primitive group in scope")
    mesh_fp = bc.mesh_fingerprints(mesh_data)
    for key in sorted(mesh_keys):
        recs = content["shapes"][key]["parts"]
        check(key in mesh_fp and mesh_fp[key]["parts"] == [r[11] for r in recs] and mesh_fp[key]["fingerprint"][0] == len(recs), tag + key + " mesh fingerprint names its source parts")
    for key, fp in content["fingerprints"].items():
        check(fp == all_fp[key], tag + key + " fingerprint")
        if content["meta"].get("blockoutCheck") == "warn":
            continue  # refinement: the spec has moved on from the 2026-10-02 showroom measurement
        if key in live:
            check(fp[0] == live[key][0] and all(abs(x - y) <= 0.01 for x, y in zip(fp[1:], live[key][1:])), tag + key + " fingerprint equals the Studio blockout measurement %r vs %r" % (fp, live[key]))
        else:
            check(False, tag + key + " has no live blockout measurement")

    # Every attribute value and string.
    problems = []
    for owner in content["cockpits"] + content["modules"]:
        for name, value in owner["attributes"].items():
            bc.check_value(owner["id"], name, value, problems)
    check(not problems, tag + "attribute values: %s" % problems[:5])

    # The rendered installer.
    try:
        text = bc.render_installer(content, catalogue_gen)
    except bc.BuildError as error:
        failures.append(tag + "render failed: %s" % error)
        return
    check(all(ord(ch) < 127 for ch in text), tag + "installer is ASCII")
    check(len(text) < 10 * 1024 * 1024, tag + "installer is under 10 MB (%d bytes)" % len(text))
    match = re.search(r"local STAGE_B_DATA_JSON = \[=====\[\n(.*?)\]=====\]\n", text, re.S)
    check(bool(match) and json.loads(match.group(1)) == json.loads(json.dumps(content)), tag + "embedded data parses back to the content")
    check("local STAGE_B_CATALOGUE_GEN = (function()" in text and text.rstrip().endswith('return finish(true, { stateAfter = "installed-" .. SCOPE, changed = #journal.created + 1 })'), tag + "installer holds the generator and the engine")
    check(content["meta"]["mode"] == "AUDIT" and content["meta"]["scope"] == scope and content["meta"]["placeId"] == 133417340424236, tag + "meta")
    other, _ = bc.build_content("ROLLBACK", scope, args.balance, args.catalogue_gen, bc.CAPTURE_PATH, args.fill_from_donor)
    check(other["meta"]["contentHash"] == content["meta"]["contentHash"] and other["meta"]["mode"] == "ROLLBACK", tag + "content hash does not depend on the mode")
    # Seat acceptance (data/seats.json pilotAcceptance): the pilot may be applied unmeasured, the full scope may not.
    state = content["meta"]["seats"]
    check(set(state) == {"accepted", "decision", "summary"} and isinstance(state["accepted"], bool) and state["decision"] in bc.SEAT_DECISIONS, tag + "meta.seats %r" % state)
    check(state == report["seatAcceptance"], tag + "the summary carries the seat acceptance")
    check(state["accepted"] == (not any("seat offsets are not accepted yet" in w for w in report["warnings"])), tag + "an unaccepted seat rule is a build warning")

    def apply_build():
        return bc.build_content("APPLY", scope, args.balance, args.catalogue_gen, bc.CAPTURE_PATH, args.fill_from_donor)

    if scope == "full" and not state["accepted"]:
        _, error = with_data({}, apply_build)
        check(error is not None and "seat offsets are not accepted, so the full scope cannot be applied" in error, tag + "APPLY full must be refused while the seats are not accepted: %r" % (error and error[:200]))
    else:
        applied, error = with_data({}, apply_build)
        check(error is None and applied[0]["meta"]["contentHash"] == content["meta"]["contentHash"] and applied[0]["meta"]["mode"] == "APPLY", tag + "APPLY builds with the same content hash: %r" % (error and error[:200]))
    return content


def check_data_rules(args):
    """Data-file rules that the shipped data does not exercise: built with the files changed in memory."""
    def build(mode, scope):
        return lambda: bc.build_content(mode, scope, args.balance, args.catalogue_gen, bc.CAPTURE_PATH, args.fill_from_donor)

    def refused(label, changes, needle, mode="AUDIT", scope="pilot"):
        result, error = with_data(changes, build(mode, scope))
        check(result is None and error is not None and needle in error, "%s must stop the build with %r: %r" % (label, needle, error and error[:300]))

    def ids_override(value):
        return {"ids.json": lambda d: d.__setitem__("cockpitAttributeOverrides", value)}

    def seats_change(**fields):
        def change(d):
            for key, value in fields.items():
                if key == "rule":
                    d["rule"]["rootPartCentreAboveSeatTop"] = value
                elif key == "overrides":
                    d["overrides"] = value
                else:
                    d.setdefault("pilotAcceptance", {})[key] = value
        return {"seats.json": change}

    # Cockpit attribute overrides get the same value checks as everything else, and cannot change identity.
    refused("a non-ASCII override", ids_override({"OwnedByDefault": "caf\u00e9"}), "not printable ASCII")
    refused("an override number the generator rejects", ids_override({"TopSpeed": 1e-7}), "not safe for the catalogue generator")
    refused("an override of an unsupported type", ids_override({"OwnedByDefault": [1]}), "unsupported attribute type")
    refused("an override of an interface attribute", ids_override({"CockpitId": "exotic_99"}), "may not change CockpitId")
    refused("an override of a default module", ids_override({"DefaultBoostModuleId": "MODULE_BOOST_EXOTIC_03_POWER"}), "may not change DefaultBoostModuleId")
    refused("an override of an unknown attribute", ids_override({"NotACockpitAttribute": 1}), "not an attribute of this cockpit")
    result, error = with_data(ids_override({}), build("AUDIT", "pilot"))
    check(error is None and result[0]["cockpits"][0]["attributes"].get("OwnedByDefault") is True, "without the override OwnedByDefault is the balance.json value (true): %r" % (error and error[:200]))

    # Seat acceptance.
    six = {"exotic_0%d" % n: {"driver": [-1.8, 0.25, 0.45], "passenger": [1.8, 0.25, 0.45]} for n in range(1, 7)}
    refused("pending seats", seats_change(decision="pending"), "seat offsets are not accepted, so the full scope cannot be applied", "APPLY", "full")
    for mode, scope in (("AUDIT", "pilot"), ("APPLY", "pilot"), ("AUDIT", "full"), ("ROLLBACK", "full")):
        result, error = with_data(seats_change(decision="pending"), build(mode, scope))
        check(error is None and result[0]["meta"]["seats"]["accepted"] is False, "pending seats still build %s %s: %r" % (mode, scope, error and error[:200]))
    result, error = with_data(seats_change(decision="measured", measuredRootPartCentreAboveSeatTop=1.5, measuredOn="test", rule=1.5, overrides={}), build("APPLY", "full"))
    check(error is None and result[0]["meta"]["seats"] == {"accepted": True, "decision": "measured", "summary": "measured rootPartCentreAboveSeatTop=1.5 (test)"}, "measured seats let APPLY full build: %r" % (error and error[:200]))
    result, error = with_data(seats_change(decision="measured", measuredRootPartCentreAboveSeatTop=1.2, measuredOn="test", rule=1.2, overrides={}), build("APPLY", "full"))
    check(error is None and all(abs(c["attributes"]["DriverSeatOffsetY"] - (1.4 - 1.2 - 0.225)) < 1e-9 for c in result[0]["cockpits"]), "a measured rule value moves every seat: %r" % (error and error[:200]))
    refused("a measurement that the rule does not hold", seats_change(decision="measured", measuredRootPartCentreAboveSeatTop=1.2, measuredOn="test", rule=1.5, overrides={}), "but the rule still says", "APPLY", "full")
    refused("a measurement without a number", seats_change(decision="measured", measuredRootPartCentreAboveSeatTop=None, measuredOn="test"), "is not a number")
    refused("a measurement without a date", seats_change(decision="measured", measuredRootPartCentreAboveSeatTop=1.5, measuredOn=" "), "does not say when")
    refused("an unknown decision", seats_change(decision="done"), "must be one of")
    result, error = with_data(seats_change(decision="overrides", overrides=six), build("APPLY", "full"))
    check(error is None and result[0]["meta"]["seats"]["accepted"] is True
          and all([c["attributes"]["DriverSeatOffset" + a] for a in "XYZ"] == [-1.8, 0.25, 0.45] and [c["attributes"]["PassengerSeatOffset" + a] for a in "XYZ"] == [1.8, 0.25, 0.45] for c in result[0]["cockpits"]),
          "explicit overrides for all six let APPLY full build with those values: %r" % (error and error[:200]))
    result, error = with_data(seats_change(decision="measured", measuredRootPartCentreAboveSeatTop=1.2, measuredOn="test", rule=1.5, overrides=six), build("APPLY", "full"))
    check(error is None, "a measurement plus overrides for every cockpit builds: %r" % (error and error[:200]))
    result, error = with_data(seats_change(decision="overrides", overrides={"exotic_03": six["exotic_03"]}), build("APPLY", "pilot"))
    check(error is None and result[0]["meta"]["seats"]["accepted"] is True, "an override for the pilot cockpit accepts the pilot scope: %r" % (error and error[:200]))
    refused("overrides that miss cockpits", seats_change(decision="overrides", overrides={"exotic_03": six["exotic_03"]}), "there is no override for exotic_01", "AUDIT", "full")
    refused("an override for an unknown cockpit", seats_change(overrides={"exotic_3": six["exotic_03"]}), "unknown cockpit")
    refused("an override without a passenger", seats_change(overrides={"exotic_03": {"driver": [-1.8, 0.25, 0.45]}}), "overrides.exotic_03.passenger must be three numbers")
    refused("an override outside the clamp", seats_change(overrides={"exotic_03": {"driver": [-1.8, 41, 0.45], "passenger": [1.8, 0.25, 0.45]}}), "overrides.exotic_03.driver must be three numbers")

    # Mesh kits (mesh/INTEGRATION.md).
    def ids_cockpit(n, **fields):
        return {"ids.json": lambda d: [c.update(fields) for c in d["cockpits"] if c["n"] == n]}

    def mesh_change(change):
        return {"mesh.json": change}

    real_full, error = with_data({}, build("AUDIT", "full"))
    check(error is None, "the full scope builds: %r" % (error and error[:200]))
    refused("an empty core slot", ids_cockpit("02", emptySlots=["Boost"]), "emptySlots may only name", "AUDIT", "full")
    refused("an empty Nose slot", ids_cockpit("02", emptySlots=["FrontBody"]), "emptySlots may only name", "AUDIT", "full")
    if "DefaultRearSpoilerModuleId" in bc.load_json(args.balance)["cockpits"]["exotic_01"]["attributes"]:  # the stand-in fixture sets no defaults
        # Every cockpit already starts with SidePods, FrontBumper and RearBumper empty; the Wing is the one slot left that may be emptied.
        refused("an empty slot that balance.json still defaults", ids_cockpit("01", emptySlots=list(MESH_EMPTY_SLOTS) + ["RearSpoiler"]), "balance.json sets DefaultRearSpoilerModuleId", "AUDIT", "full")
    result, error = with_data(mesh_change(lambda d: d.__setitem__("assetId", d["assetId"] + 1)), build("AUDIT", "full"))
    check(error is None and real_full and result[0]["meta"]["contentHash"] != real_full[0]["meta"]["contentHash"], "the content hash covers the mesh asset id (D15): %r" % (error and error[:200]))

    def rename_part(d):
        parts = d["modules"]["MODULE_BOOST_EXOTIC_02_STANDARD"]["parts"]
        parts["B_BOOST_STD__primaryX"] = parts.pop("B_BOOST_STD__primary")
    result, error = with_data(mesh_change(rename_part), build("AUDIT", "full"))
    check(error is None and real_full and result[0]["meta"]["contentHash"] != real_full[0]["meta"]["contentHash"], "the content hash covers the mesh part names (D15): %r" % (error and error[:200]))
    refused("a mesh module with an unknown channel", mesh_change(lambda d: d["modules"]["MODULE_BOOST_EXOTIC_02_STANDARD"]["parts"]["B_BOOST_STD__primary"].__setitem__("channel", "driver")), "cannot go on this template", "AUDIT", "full")
    refused("glass that is not on a mesh cockpit's list", mesh_change(lambda d: d["cockpits"]["exotic_02"]["parts"]["B_COCKPIT_STD__glass"].__setitem__("channel", "lights")), "cannot go on this template", "AUDIT", "full")
    refused("a thrust part on a mesh body module", mesh_change(lambda d: d["modules"]["MODULE_REARSPOILER_EXOTIC_02"]["parts"]["B_WING_STD__primary"].__setitem__("channel", "thrust")), "thrust parts belong on engines", "AUDIT", "full")
    refused("a mesh engine without sockets", mesh_change(lambda d: d["modules"]["MODULE_ENGINE_EXOTIC_05_POWER"].__setitem__("sockets", [])), "has no socket", "AUDIT", "full")
    refused("a mesh id outside the id rules", mesh_change(lambda d: d["modules"].__setitem__("MODULE_SIDEPODS_EXOTIC_02_GTX", d["modules"]["MODULE_REARSPOILER_EXOTIC_02_GT"])), "is not a ModuleId of this scope", "AUDIT", "full")
    refused("a mesh part without a size", mesh_change(lambda d: d["modules"]["MODULE_BOOST_EXOTIC_02_STANDARD"]["parts"]["B_BOOST_STD__primary"].__setitem__("size", [1, 0, 1])), "needs a centre and a positive size", "AUDIT", "full")
    refused("a body trim that balance.json does not hold", {"ids.json": lambda d: d.__setitem__("bodyTrims", ["GT"])}, "is not a ModuleId of this scope", "AUDIT", "full")
    # A mesh cockpit without a seat override falls back to the spec driver dummy rule (D13: a data-only change either way).
    result, error = with_data(seats_change(overrides={}), build("AUDIT", "full"))
    check(error is None and all(abs(c["attributes"]["DriverSeatOffsetY"] - (1.4 - 1.437 - 0.225)) < 1e-9 for c in result[0]["cockpits"]), "without overrides every cockpit, mesh or not, follows the driver dummy: %r" % (error and error[:200]))
    # Every shipped cockpit has an override now, so the seat X and Z of the dummy rule are checked here.
    spec = vbspec.load(bc.SPEC_PATH)
    for c in (result[0]["cockpits"] if result else []):
        torso = [p for p in bc.flatten(spec["cockpits"][COCKPITS[c["id"]][2]]["parts"]) if p["ch"] == "driver" and p["shape"] == "block"][0]
        a = c["attributes"]
        check(a["DriverSeatOffsetX"] == torso["pos"][0] and a["PassengerSeatOffsetX"] == -torso["pos"][0], c["id"] + " without an override: seat X")
        check(a["DriverSeatOffsetZ"] == torso["pos"][2] == a["PassengerSeatOffsetZ"] and a["PassengerSeatOffsetY"] == a["DriverSeatOffsetY"], c["id"] + " without an override: seat Z, and the passenger at the driver's height")
    result, error = with_data(seats_change(overrides={"exotic_05": {"driver": [-1.6, 0.05, 0.5], "passenger": [1.6, 0.05, 0.5]}}), build("AUDIT", "full"))
    check(error is None and [[c["attributes"]["DriverSeatOffset" + axis] for axis in "XYZ"] for c in result[0]["cockpits"] if c["id"] == "exotic_05"] == [[-1.6, 0.05, 0.5]], "a corrected mesh seat override reaches the cockpit attributes: %r" % (error and error[:200]))


def lua_balance(source):
    """Crude Luau structure check: block openers against 'end'/'until', and bracket balance, outside strings and comments."""
    stripped, i, n = [], 0, len(source)
    while i < n:
        ch = source[i]
        if source.startswith("--", i):
            m = re.match(r"--\[(=*)\[", source[i:])
            if m:
                close = source.find("]" + m.group(1) + "]", i)
                i = n if close < 0 else close + len(m.group(1)) + 2
            else:
                j = source.find("\n", i)
                i = n if j < 0 else j
        elif ch in "\"'":
            j = i + 1
            while j < n and source[j] != ch:
                j += 2 if source[j] == "\\" else 1
            stripped.append('""')
            i = j + 1
        elif ch == "[" and re.match(r"\[(=*)\[", source[i:]):
            m = re.match(r"\[(=*)\[", source[i:])
            close = source.find("]" + m.group(1) + "]", i)
            stripped.append('""')
            i = n if close < 0 else close + len(m.group(1)) + 2
        else:
            stripped.append(ch)
            i += 1
    code = "".join(stripped)
    words = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", code)
    depth = sum(1 for w in words if w in ("function", "do", "if", "repeat")) - sum(1 for w in words if w in ("end", "until"))
    brackets = {c: code.count(c) for c in "(){}[]"}
    return depth, brackets


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--balance")
    parser.add_argument("--catalogue-gen")
    parser.add_argument("--fill-from-donor", action="store_true")
    args = parser.parse_args()
    real = os.path.isfile(bc.BALANCE_PATH) and os.path.isfile(bc.CATALOGUE_GEN_PATH)
    if not args.balance:
        args.balance = bc.BALANCE_PATH if real else os.path.join(FIXTURES, "balance.json")
    if not args.catalogue_gen:
        args.catalogue_gen = bc.CATALOGUE_GEN_PATH if os.path.isfile(bc.CATALOGUE_GEN_PATH) else os.path.join(FIXTURES, "catalogue_gen.lua")
    print("balance: %s\ncatalogue_gen: %s" % (os.path.relpath(args.balance, bc.REPO), os.path.relpath(args.catalogue_gen, bc.REPO)))

    spec = vbspec.load(bc.SPEC_PATH)
    reference = bc.capture_reference(bc.load_json(bc.CAPTURE_PATH))
    live = {}
    with open(os.path.join(FIXTURES, "blockout_live_2026-10-02.txt"), "r", encoding="ascii") as f:
        for line in f:
            if line.strip() and not line.startswith("#"):
                cells = line.strip().split("|")
                live[cells[0].split("@")[0]] = [int(cells[1])] + [float(v) for v in cells[2:]]
    # Module parts before the mesh kits: 793 primitive. The 42 shapes the mesh kits replace are counted from the spec here.
    replaced = sum(len(bc.flatten(spec["modules"][slot][spec["kits"][COCKPITS["exotic_" + n][3]]["modules"][slot]]["parts"])) for n in MESH_CARS for slot in MESH_SLOT_TAGS)
    replaced_cockpits = sum(len(bc.flatten(spec["cockpits"][COCKPITS["exotic_" + n][2]]["parts"])) - 2 for n in MESH_CARS)
    EXPECTED_PARTS["cockpit"] = (199 - replaced_cockpits, 24)
    EXPECTED_PARTS["module"] = (793 - replaced, 536)
    check(replaced_cockpits == 199 and 793 - replaced == 118, "every cockpit is a mesh cockpit; 118 primitive module parts stay (the three slots that start empty)")
    check(len(live) == 66, "66 live blockout groups in the fixture")
    check(len(bc.all_fingerprints(spec)) == 66, "66 cockpit+shape groups in the spec")

    # A missing input must fail clearly.
    try:
        bc.build_content("AUDIT", "pilot", os.path.join(FIXTURES, "does-not-exist.json"), args.catalogue_gen)
        check(False, "a missing balance.json must stop the build")
    except bc.BuildError as error:
        check("balance.json is missing" in str(error), "missing balance.json message: %s" % error)

    full = check_scope("full", args, spec, reference, live)
    pilot = check_scope("pilot", args, spec, reference, live)
    if full and pilot:
        by_id = {m["id"]: m for m in full["modules"]}
        check(all(by_id[m["id"]]["attributes"] == m["attributes"] and by_id[m["id"]]["shape"] == m["shape"] for m in pilot["modules"]), "pilot modules equal the same modules in the full scope")
        check("Cockpit/wedge" not in full["shapes"] and full["shapes"]["Cockpit/D_COCKPIT_STD"] == pilot["shapes"]["Cockpit/D_COCKPIT_STD"], "pilot cockpit geometry equals the full scope")
        check(set(pilot["shapes"]) <= set(full["shapes"]) and all(full["shapes"][k] == v for k, v in pilot["shapes"].items()), "pilot module geometry and sockets equal the full scope")
        check(sorted(k for k, v in pilot["shapes"].items() if "mesh" not in v) == ["FrontBumper/chin", "RearBumper/strake", "SidePods/strake"], "the pilot keeps its three primitive shapes (the slots that start empty)")
        check(full["meta"]["contentHash"] != pilot["meta"]["contentHash"], "pilot and full have different content hashes")
        # Socket orientations really point where the nozzles point (worked examples from exotic.md 7.7).
        # None of these spec shapes is installed any more: every kit is a mesh kit now.
        # The socket rule is still checked on their spec geometry, straight from the rule.
        socket_rules = bc.load_json(os.path.join(bc.DATA_DIR, "sockets.json"))
        check(not any(k in full["shapes"] for k in ("Engine1/top", "Stabilisers/lift", "Engine1/mono", "Stabilisers/vector", "Boost/quad")), "the spec shapes the mesh kits replace are not in the content")
        top = {s["name"]: s for s in bc.compute_sockets("Engine1/top", bc.flatten(spec["modules"]["Engine1"]["top"]["parts"]), "engine", socket_rules)}
        check(set(top) == {"VFX_EngineJet_Left", "VFX_EngineJet_Right"} and top["VFX_EngineJet_Left"]["orientation"] == [-90.0, 0.0, 0.0], "Top-Exit Core fires up from two sockets: %r" % top)
        mono = bc.compute_sockets("Engine1/mono", bc.flatten(spec["modules"]["Engine1"]["mono"]["parts"]), "engine", socket_rules)
        check(len(mono) == 1 and mono[0]["name"] == "VFX_EngineJet_Back" and mono[0]["position"] == [0.0, 3.72, 9.32] and mono[0]["orientation"] == [0.0, 0.0, 0.0], "Mono Turbine socket %r" % mono)
        vector = {s["name"]: s for s in bc.compute_sockets("Stabilisers/vector", bc.flatten(spec["modules"]["Stabilisers"]["vector"]["parts"]), "stabiliser", socket_rules)}
        check(set(vector) == {"VFX_StabiliserJet_Left_Front", "VFX_StabiliserJet_Left_Rear", "VFX_StabiliserJet_Right_Front", "VFX_StabiliserJet_Right_Rear"}, "Vector Pods socket names %r" % sorted(vector))
        check(vector["VFX_StabiliserJet_Left_Front"]["orientation"] == [50.0, 0.0, 0.0], "Vector Pods fire 50 degrees down and back: %r" % vector["VFX_StabiliserJet_Left_Front"])
        lift = bc.compute_sockets("Stabilisers/lift", bc.flatten(spec["modules"]["Stabilisers"]["lift"]["parts"]), "stabiliser", socket_rules)
        check(len(lift) == 4 and all(s["orientation"][0] == 90.0 and abs(s["orientation"][1]) == 90.0 for s in lift), "Twin Lift Cans fire straight down: %r" % lift)
        # Mesh sockets (D12): flame along local +Z, in the orientation convention of the computed sockets.
        stab = {s["name"]: s for s in full["shapes"]["Stabilisers/B_STAB_STD"]["sockets"]}
        check(set(stab) == set(vector) and stab["VFX_StabiliserJet_Left_Front"] == {"name": "VFX_StabiliserJet_Left_Front", "template": "StabiliserJet_ExoticLeft", "position": [-4.8, -0.9, -3.2], "orientation": [90.0, -90.0, 0.0]}
              and stab["VFX_StabiliserJet_Right_Rear"]["orientation"] == [90.0, 90.0, 0.0] and stab["VFX_StabiliserJet_Right_Rear"]["template"] == "StabiliserJet_ExoticRight", "mesh stabiliser sockets fire straight down, yawed as Piercer: %r" % stab)
        pod = full["shapes"]["Engine1/A_FPOD_EVO"]["sockets"]
        check(pod == [{"name": "VFX_EngineJet_Left", "template": "EngineJet_Exotic", "position": [-5.1, 0.68, -5.4], "orientation": [0.0, 0.0, 0.0]},
                      {"name": "VFX_EngineJet_Right", "template": "EngineJet_Exotic", "position": [5.1, 0.68, -5.4], "orientation": [0.0, 0.0, 0.0]}], "mesh front pod sockets fire back: %r" % pod)
        boost = full["shapes"]["Boost/A_BOOST_EVO"]["sockets"]
        check([s["name"] for s in boost] == ["VFX_BoostJet_Back", "VFX_BoostJet_Left", "VFX_BoostJet_Right", "VFX_BoostJet_Top"] and all(s["template"] == "BoostJet_Exotic" and s["orientation"] == [0.0, 0.0, 0.0] for s in boost),
              "mesh boost sockets: %r" % boost)
        # The pilot car (D, kit 03) and every other car: the same socket names per slot on each Standard core module.
        stab = {s["name"]: s for s in full["shapes"]["Stabilisers/D_STAB_STD"]["sockets"]}
        check(set(stab) == set(vector) and stab["VFX_StabiliserJet_Left_Front"] == {"name": "VFX_StabiliserJet_Left_Front", "template": "StabiliserJet_ExoticLeft", "position": [-4.9, -0.9, -3.3], "orientation": [90.0, -90.0, 0.0]}
              and stab["VFX_StabiliserJet_Right_Rear"]["orientation"] == [90.0, 90.0, 0.0] and stab["VFX_StabiliserJet_Right_Rear"]["template"] == "StabiliserJet_ExoticRight", "pilot mesh stabiliser sockets fire straight down, yawed as Piercer: %r" % stab)
        pod = full["shapes"]["Engine1/D_FPOD_STD"]["sockets"]
        check(pod == [{"name": "VFX_EngineJet_Left", "template": "EngineJet_Exotic", "position": [-5.1, 0.7, -5.4], "orientation": [0.0, 0.0, 0.0]},
                      {"name": "VFX_EngineJet_Right", "template": "EngineJet_Exotic", "position": [5.1, 0.7, -5.4], "orientation": [0.0, 0.0, 0.0]}], "pilot mesh front pod sockets fire back: %r" % pod)
        for n, (car, _) in sorted(MESH_CARS.items()):
            names = {slot: [s["name"] for s in full["shapes"]["%s/%s_%s_STD" % (slot, car, MESH_SLOT_TAGS[slot])]["sockets"]] for slot in SOCKET_RULES}
            check(names["Engine1"] == ["VFX_EngineJet_Left", "VFX_EngineJet_Right"] and names["Engine2"] == ["VFX_EngineJet_Left", "VFX_EngineJet_Right"] and names["Stabilisers"] == sorted(vector)
                  and names["Boost"] == (["VFX_BoostJet_Back", "VFX_BoostJet_Left", "VFX_BoostJet_Right", "VFX_BoostJet_Top"] if n == "02" else ["VFX_BoostJet_Left", "VFX_BoostJet_Right"]),
                  "car %s Standard core sockets: %r" % (car, names))
        quad = bc.compute_sockets("Boost/quad", bc.flatten(spec["modules"]["Boost"]["quad"]["parts"]), "boost", socket_rules)
        check(len(quad) == 1 and quad[0]["name"] == "VFX_BoostJet_Back" and quad[0]["position"][0] == 0.0, "Quad Cans share one centred boost socket: %r" % quad)

    check_data_rules(args)

    # Data files and engine.
    vfx = bc.load_json(os.path.join(bc.DATA_DIR, "vfx.json"))
    check([t["name"] for t in vfx["templates"]] == ["EngineJet_Exotic", "BoostJet_Exotic", "StabiliserJet_ExoticLeft", "StabiliserJet_ExoticRight"], "the four Exotic VFX template names")
    check({t["name"]: t.get("group") for t in vfx["templates"]} == {"EngineJet_Exotic": None, "BoostJet_Exotic": None, "StabiliserJet_ExoticLeft": "DriftLeft", "StabiliserJet_ExoticRight": "DriftRight"}, "stabiliser templates carry DriftLeft / DriftRight")
    for t in vfx["templates"]:
        stock_beam = {"EngineJet": 11, "BoostJet": 20, "StabiliserJet": 8}[t["source"]]
        lo, hi = {"EngineJet": (1.0, 1.5), "BoostJet": (1.5, 2.0), "StabiliserJet": (0.9, 1.1)}[t["source"]]
        check(lo <= stock_beam * t["beamWidthScale"] <= hi, "%s jet width %.2f studs" % (t["name"], stock_beam * t["beamWidthScale"]))
    fixtures = bc.load_json(os.path.join(bc.DATA_DIR, "cockpit_fixtures.json"))
    check(len(fixtures["hoverDust"]) == 5 and len(fixtures["underglow"]["emitters"]) >= 1, "five hover dust sockets and an underglow emitter")
    with open(bc.ENGINE_PATH, "r", encoding="utf-8") as f:
        engine = f.read()
    check(all(ord(ch) < 127 for ch in engine), "engine is ASCII")
    depth, brackets = lua_balance(engine)
    check(depth == 0, "engine block structure is balanced (function/do/if/repeat against end/until): %d" % depth)
    check(brackets["("] == brackets[")"] and brackets["{"] == brackets["}"] and brackets["["] == brackets["]"], "engine brackets are balanced: %r" % brackets)
    check("133417340424236" not in engine and "META.placeId" in engine, "the place id comes from the data, and the engine asserts it")
    # Mesh kits: the asset is loaded once (a read), checked against the data (D16), and the checks see the MeshId (D15).
    check(engine.count("game:GetObjects(") == 1 and 'BLOCKER("mesh"' in engine and "MESH.centreTolerance" in engine, "the engine loads the mesh asset once and blocks on a missing or misplaced part")
    check("CFrame.Angles(0, math.pi, 0) * source.CFrame" in engine and "Vector3.new(shape.mesh.fileOffsetX, 0, 0)" in engine, "file space to root space as D3")
    check("part.DoubleSided = true" in engine and 'part:SetAttribute("MeshSource", record[12])' in engine, "a mesh clone is double sided and names its source part")
    check(engine.count("instance.MeshId") == 1 and 'root:SetAttribute("InstalledMeshSignature", meshMark)' in engine and 'root:GetAttribute("InstalledMeshSignature")' in engine,
          "preview parity and the installed-state check cover the MeshId")
    check("InsertService" not in engine and "LoadAsset" not in engine and "HttpService:GetAsync" not in engine and "PostAsync" not in engine, "the engine uses no other asset or network call")
    for needle in ("workspace:FindFirstChild", "IsRunning()", "InstalledBy"):
        check(needle in engine, "engine contains %s" % needle)
    writes = re.findall(r"workspace[\.:][A-Za-z]+", engine)
    check(set(writes) == {"workspace:FindFirstChild"}, "the engine only reads Workspace: %r" % sorted(set(writes)))
    # Stage A: the four server sources are required (BLOCKER), the client sources are reported (WARN).
    probes = re.findall(r'\{ (ServerStorage|ReplicatedStorage), \{ ([^}]*) \}, "([A-Za-z]+)", "[^"]*", (true|false) \}', engine)
    required = {(names.split(", ")[-1].strip('"'), needle) for service, names, needle, flag in probes if service == "ServerStorage" and flag == "true"}
    check(required == {("GarageCatalogService", "FeatureFlag"), ("GarageServer", "FeatureFlag"), ("DriverSeatServer", "DriverSeatOffsetX"), ("VehicleBuildService", "PassengerSeatOffsetX")},
          "the four Stage A server probes are required: %r" % sorted(required))
    check(all(flag == "false" for service, names, needle, flag in probes if service == "ReplicatedStorage") and len(probes) == 9, "Stage A client probes are warnings: %r" % probes)
    check("local report = required and BLOCKER or WARN" in engine and 'report("stage-a"' in engine, "a missing required Stage A source is a BLOCKER")
    for service, names, needle, flag in probes:
        name = names.split(", ")[-1].strip('"')
        folder = "server" if service == "ServerStorage" else "client"
        after_path = os.path.join(bc.REPO, "scripts", "exotic_category", "stage_a", folder, "after", name + ".lua")
        if os.path.isfile(after_path):
            with open(after_path, "r", encoding="utf-8") as f:
                check(needle in f.read(), "Stage A after-source %s/%s holds the probe text %s" % (folder, name, needle))
    # Catalogue chunks are own content only with the marker.
    check('chunkScript:SetAttribute("InstalledBy", MARKER)' in engine and engine.index('chunkScript:SetAttribute("InstalledBy", MARKER)') < engine.index("place(chunkScript, catalogueIndex)"), "EXOTIC chunks get the installer marker before they are parented")
    check("elseif not own(chunk) then" in engine, "an EXOTIC chunk without the marker makes the state foreign")
    check(engine.count('assert(own(instance), "refuse to remove ') == 2, "APPLY and ROLLBACK refuse to remove anything without the marker")
    check("preflightSeats()" in engine and 'BLOCKER("seats"' in engine and 'WARN("seats"' in engine, "the engine reports unaccepted seats")
    for name in ("post_install_checks.lua", "measure_seat.lua"):
        with open(os.path.join(HERE, name), "r", encoding="utf-8") as f:
            text = f.read()
        depth, brackets = lua_balance(text)
        check(all(ord(ch) < 127 for ch in text) and depth == 0 and brackets["("] == brackets[")"] and brackets["{"] == brackets["}"] and brackets["["] == brackets["]"], "%s is ASCII and balanced" % name)
        check(not re.search(r"\.Parent\s*=[^=]|:Destroy\(|:SetAttribute\(|Instance\.new|\.Source\s*=[^=]", text), "%s writes nothing" % name)

    print("%d checks passed, %d failed" % (passed, len(failures)))
    for failure in failures[:60]:
        print("FAIL " + failure)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
