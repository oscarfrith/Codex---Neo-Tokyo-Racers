"""Offline checks on the Stage B content (no Studio needed).

Usage:  py -3 scripts/exotic_category/stage_b/test_content.py [--category ID] [--balance PATH] [--catalogue-gen PATH] [--fill-from-donor]

With no arguments it uses the real balance.json and catalogue_gen.lua when both exist, else the stand-ins in
tests/fixtures (run tests/make_fixture.py first). Exit code 0 means every check passed.

--category muscle checks the Modern Muscle content (scripts/exotic_category/categories/muscle) against the Muscle
tables below. The Exotic tables and checks are unchanged; the mesh sections run only for a category with data/mesh.json.
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
    "exotic_01": ("COCKPIT_EXOTIC_01", "Stinger", "spider", "track", "E", 50000, 220),
    "exotic_02": ("COCKPIT_EXOTIC_02", "Zephyr", "curve", "analogue", "D", 150000, 390),
    "exotic_03": ("COCKPIT_EXOTIC_03", "Aurora", "wedge", "wedge", "C", 440000, 540),
    "exotic_04": ("COCKPIT_EXOTIC_04", "Endura", "longtail", "longtail", "B", 1400000, 675),
    "exotic_05": ("COCKPIT_EXOTIC_05", "Rosso", "hyper", "hyper", "A", 4400000, 800),
    "exotic_06": ("COCKPIT_EXOTIC_06", "Seraph", "gull", "concept", "S", 12500000, 938),
}
# SlotId: (label, ModuleType, folder, order, CountLabel, EnginePosition, id prefix, core?)
# Labels and Order: mesh/INTEGRATION.md E3 and E4; CountLabel of the two body slots: F5 (2026-10-04).
SLOTS = {
    "FrontBody": ("Front Body", "FrontBody", "FrontBodies", 1, "Front Bodies", None, "MODULE_FRONTBODY_EXOTIC_", False),
    "RearBody": ("Rear Body", "RearBody", "RearBodies", 2, "Rear Bodies", None, "MODULE_REARBODY_EXOTIC_", False),
    "Engine1": ("Front Engine", "Engine", "Engines", 3, "Engines", "Front", "MODULE_ENGINE_EXOTIC_", True),
    "Engine2": ("Rear Engine", "Engine", "Engines_B", 4, "Engines", "Rear", "MODULE_ENGINE_B_EXOTIC_", True),
    "Stabilisers": ("Drift Thrusters", "Stabilisers", "Stabilisers", 5, "Stabilisers", None, "MODULE_STABILISER_EXOTIC_", True),
    "Boost": ("Overdrive", "Boost", "Boost", 6, "Boost", None, "MODULE_BOOST_EXOTIC_", True),
    "RearSpoiler": ("Wing", "RearSpoiler", "RearSpoilers", 7, "Wings", None, "MODULE_REARSPOILER_EXOTIC_", False),
    "FrontBumper": ("Splitter", "FrontBumper", "FrontBumpers", 8, "Splitters", None, "MODULE_FRONTBUMPER_EXOTIC_", False),
    "RearBumper": ("Diffuser", "RearBumper", "RearBumpers", 9, "Diffusers", None, "MODULE_REARBUMPER_EXOTIC_", False),
    "SidePods": ("Side Pods", "SidePods", "SidePods", 10, "Side Pods", None, "MODULE_SIDEPODS_EXOTIC_", False),
}
# mesh/INTEGRATION.md E2: Price as a fraction of the kit's core variant price V; the base part is V / 4.
BODY_TRIM_FRACTION = {"GT": (1, 2), "EVO": (1, 1)}
BODY_BASE_FRACTION = (1, 4)
# mesh/INTEGRATION.md F1 and F4: the version of a body module, and the stats a trim may change (with the direction
# that is better). A trim keeps every other attribute of its base part.
BODY_VARIANT = {None: ("Standard", 10), "GT": ("GT", 20), "EVO": ("EVO", 30)}
BODY_TRIM_STATS = {"FrontBody": {"Downforce": 1, "SteeringResponse": 1}, "RearBody": {"Weight": -1, "EngineOutput": 1},
                   "RearSpoiler": {"Downforce": 1, "LateralGrip": 1}}
LEGACY_HEADLINES = {"Acceleration", "Braking", "Handling", "Drift"}  # derived from the raw stats by the balance builder
HIDDEN_BODY_PRICE = (8000, 11000, 14000, 18000, 23000, 30000)  # SidePods, FrontBumper, RearBumper by kit: unchanged by E2
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

VFX_TEMPLATES = ["EngineJet_Exotic", "BoostJet_Exotic", "StabiliserJet_ExoticLeft", "StabiliserJet_ExoticRight"]

# What else differs per category. The values here are Exotic's; use_category() swaps them (and the tables above)
# for another category's, which are written out below in the same way.
CATEGORY = "exotic"  # CategoryId; a cockpit id is <CategoryId>_<n>
FOLDER = "EXOTIC"  # category folder, and the word in every ModuleId and cockpit model name
CATEGORY_DISPLAY = "Exotic"
CORE_FOLDER_PREFIX = "Exotic_"
PILOT = "03"
RATING_REFERENCE = "exotic_03"
FULL_SHAPES = 150  # cockpit + module shape groups in the full scope
TRIM_KITS = set(MESH_CARS)  # kits whose FrontBody, RearBody and RearSpoiler carry GT and EVO
EMPTY_KITS = set(MESH_CARS)  # kits whose cockpit starts with MESH_EMPTY_SLOTS empty
CORE_PRIMITIVE_CODES = set("PSDT")  # channels a primitive engine, stabiliser or boost shape may hold
SEAT_OVERRIDES = {"exotic_" + n: MESH_SEATS_BY_COCKPIT.get("exotic_" + n, MESH_SEATS) for n in MESH_CARS}
DUMMY_TORSO_Y = {cid: 1.4 for cid in COCKPITS}  # centre of the spec driver dummy torso
SEAT_RULE = 1.437  # data/seats.json rule.rootPartCentreAboveSeatTop
SEAT_RULE_FALLBACK = {}  # seats.json changes a build without overrides needs (none: the Exotic rule is measured)
SPLAYED_JETS = None  # None: every engine and boost socket fires straight back or up (exotic.md 7.7). Else: the shapes that may lean sideways

# Modern Muscle (category contract 2026-10-04), written out again here on purpose. Primitive placeholder geometry
# from specs/muscle.json: no mesh kits. The slot table is Exotic's with MUSCLE in the id prefixes.
MUSCLE = {
    "CATEGORY": "muscle", "FOLDER": "MUSCLE", "CATEGORY_DISPLAY": "Modern Muscle", "CORE_FOLDER_PREFIX": "Muscle_", "PILOT": "04",
    "RATING_REFERENCE": "muscle_04", "FULL_SHAPES": 66,
    "COCKPITS": {
        "muscle_01": ("COCKPIT_MUSCLE_01", "Notch", "notch", "transam", "E", 32000, 230),
        "muscle_02": ("COCKPIT_MUSCLE_02", "Ute", "ute", "restomod", "D", 85000, 330),
        "muscle_03": ("COCKPIT_MUSCLE_03", "Ragtop", "ragtop", "pony", "D", 110000, 410),
        "muscle_04": ("COCKPIT_MUSCLE_04", "Hardtop", "hardtop", "prostreet", "C", 240000, 480),
        "muscle_05": ("COCKPIT_MUSCLE_05", "Fastback", "fastback", "classic", "C", 310000, 565),
        "muscle_06": ("COCKPIT_MUSCLE_06", "Modern", "modern", "modern", "B", 850000, 630),
    },
    "SLOTS": {k: v[:6] + (v[6].replace("_EXOTIC_", "_MUSCLE_"),) + v[7:] for k, v in SLOTS.items()},
    "MESH_CARS": {},
    "HIDDEN_BODY_PRICE": (5000, 7000, 8000, 10000, 12000, 16000),  # SidePods, FrontBumper, RearBumper by kit
    "TRIM_KITS": {"01", "02", "03", "04", "05", "06"},
    "EMPTY_KITS": {"01", "02", "03", "04", "05", "06"},
    # Sill Slots (the Modern boost) has a neon strip; the core template has NEON_OptionalLights for it.
    "CORE_PRIMITIVE_CODES": set("PSDNT"),
    # Stock builds over the 16-socket guard. muscle_02 (Ute, Restomod kit): 5 hover dust + 2 + 4 engine + 4 stabiliser + 2 boost.
    "SOCKET_GUARD_EXCEPTIONS": {"muscle_02": 17},
    # The Muscle spec angles its pipes: zoomies, side pipes and lake pipes point out and back. These engine and boost
    # shapes have sockets with a sideways component; every other one fires in the centre plane.
    "SPLAYED_JETS": {"Boost/bazookas", "Boost/lake_trios", "Boost/side_pipes", "Boost/sill_slots", "Boost/underslung_twins",
                     "Engine1/blower_stack", "Engine1/shaker_turbine", "Engine1/tunnel_ram"},
    "SOCKET_RULES": {"Engine1": ("VFX_EngineJet_", {"EngineJet_Muscle"}), "Engine2": ("VFX_EngineJet_", {"EngineJet_Muscle"}),
                     "Boost": ("VFX_BoostJet_", {"BoostJet_Muscle"}),
                     "Stabilisers": ("VFX_StabiliserJet_", {"StabiliserJet_MuscleLeft", "StabiliserJet_MuscleRight"})},
    "VFX_TEMPLATES": ["EngineJet_Muscle", "BoostJet_Muscle", "StabiliserJet_MuscleLeft", "StabiliserJet_MuscleRight"],
    # Generated from the spec, not measured (data/seats.json pilotAcceptance.note).
    "SEAT_OVERRIDES": {
        "muscle_01": {"driver": [-2.0, 1.175, 2.9], "passenger": [2.0, 1.175, 2.9]},
        "muscle_02": {"driver": [-2.0, 1.575, 1.7], "passenger": [2.0, 1.575, 1.7]},
        "muscle_03": {"driver": [-2.0, 1.395, 2.45], "passenger": [2.0, 1.395, 2.45]},
        "muscle_04": {"driver": [-2.0, 1.575, 2.45], "passenger": [2.0, 1.575, 2.45]},
        "muscle_05": {"driver": [-2.0, 1.475, 2.45], "passenger": [2.0, 1.475, 2.45]},
        "muscle_06": {"driver": [-2.0, 0.625, 3.1], "passenger": [2.0, 0.625, 3.1]},
    },
    "DUMMY_TORSO_Y": {"muscle_01": 3.8, "muscle_02": 3.8, "muscle_03": 3.12, "muscle_04": 3.8, "muscle_05": 3.8, "muscle_06": 3.2},
    "SEAT_RULE": 1.5,
    # Muscle seats are accepted by overrides, so a build without them needs a measured rule.
    "SEAT_RULE_FALLBACK": {"decision": "measured", "measuredRootPartCentreAboveSeatTop": 1.5, "measuredOn": "test"},
}
# Muscle only. Roof underside above the driver (None: open cockpit), from the spec roof panels.
MUSCLE_ROOF_UNDERSIDE = {"muscle_01": 5.3, "muscle_02": 5.7, "muscle_03": None, "muscle_04": 5.7, "muscle_05": 5.6, "muscle_06": 4.75}
MUSCLE_FEET_BELOW_FLOOR = {"muscle_06"}  # the low Modern roof: the head under the roof wins over the feet on the floor
MUSCLE_CATEGORY_ATTRIBUTES = {
    "CategoryId": "muscle", "DisplayName": "Modern Muscle",
    "Description": "American muscle as hover jets: long bonnet, short deck, a turbine through the bonnet and afterburners along the sills.",
    "ModuleCompatibility": "Modern Muscle category modules fit every Modern Muscle cockpit.", "FeatureFlag": "VehicleClass_muscle",
}
CATEGORIES = {"exotic": None, "muscle": MUSCLE}


def use_category(name):
    """Point the checks (and build_content) at one category. Exotic keeps the tables as written above."""
    if name not in CATEGORIES:
        raise SystemExit("test_content.py has no expectations for category %r (known: %s)" % (name, ", ".join(sorted(CATEGORIES))))
    bc.set_category(name)
    if CATEGORIES[name]:
        globals().update(CATEGORIES[name])


def numbers_of(scope):
    return ["01", "02", "03", "04", "05", "06"] if scope == "full" else [PILOT]


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
            if n in TRIM_KITS and slot in MESH_BODY_TRIM_SLOTS:  # D6: two new ids per body slot per mesh kit (Exotic: every mesh kit)
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
    fixture = bc.load_json(args.balance).get("fixture") is True  # the stand-in copies Piercer donor prices for the hidden slots
    numbers = numbers_of(scope)
    mesh_data = bc.load_mesh()  # data/mesh.json, or empty tables for a category without mesh kits
    mesh_numbers = [n for n in numbers if n in MESH_CARS]
    trim_numbers = [n for n in numbers if n in TRIM_KITS]
    want_cockpits = {CATEGORY + "_" + n for n in numbers}
    want_modules = expected_module_ids(numbers)

    # Counts and ids.
    check(len(content["cockpits"]) == len(numbers), tag + "cockpit count %d" % len(content["cockpits"]))
    # A kit has 18 modules; a kit with body trims has 6 more (GT and EVO of three body slots; Exotic: every mesh kit).
    # Groups: a kit has a cockpit and ten module shapes; a mesh kit has a cockpit, 21 mesh module shapes (one per
    # ModuleId) and its three primitive body shapes. A primitive trim shares the shape of its base part.
    check(len(content["modules"]) == 18 * len(numbers) + 6 * len(trim_numbers), tag + "module count %d" % len(content["modules"]))
    check(len(content["shapes"]) == 11 * (len(numbers) - len(mesh_numbers)) + 25 * len(mesh_numbers), tag + "cockpit+shape group count %d" % len(content["shapes"]))
    if scope == "full":
        check(len(content["modules"]) == 144 and len(content["shapes"]) == FULL_SHAPES, tag + "full scope must hold 144 modules and %d groups" % FULL_SHAPES)
        check(sum(1 for m in content["modules"] if SLOTS[m["slot"]][7]) == 72, tag + "72 core modules")
        check(sum(1 for m in content["modules"] if not SLOTS[m["slot"]][7]) == 72, tag + "72 body modules (36 plus the 36 trims)")
        check(sorted(m["id"] for m in content["modules"] if m["id"].endswith(("_GT", "_EVO"))) == sorted(
            "MODULE_%s_%s_%s_%s" % (stem, FOLDER, n, trim) for stem in ("FRONTBODY", "REARBODY", "REARSPOILER") for n in numbers for trim in ("GT", "EVO")),
            tag + "the 36 new ModuleIds of D6")
    else:
        check(sum(1 for m in content["modules"] if SLOTS[m["slot"]][7]) == 12, tag + "pilot has 12 core modules")
        check(sum(1 for m in content["modules"] if not SLOTS[m["slot"]][7]) == 12, tag + "pilot has 12 body modules (6 plus the 6 mesh trims)")
    check({c["id"] for c in content["cockpits"]} == want_cockpits, tag + "cockpit ids")
    check({m["id"] for m in content["modules"]} == set(want_modules), tag + "module ids match INTERFACE.md")
    check(len({m["id"] for m in content["modules"]}) == len(content["modules"]), tag + "module ids unique")

    # Category and slots.
    cat = content["category"]
    check(cat["folder"] == FOLDER and cat["afterFolder"] == "PIERCER", tag + "category folder")
    check(cat["attributes"]["CategoryId"] == CATEGORY and cat["attributes"]["DisplayName"] == CATEGORY_DISPLAY and cat["attributes"]["FeatureFlag"] == "VehicleClass_" + CATEGORY, tag + "category attributes")
    check([s["slotId"] for s in content["slots"]] == sorted(SLOTS, key=lambda k: SLOTS[k][3]), tag + "slot order")
    for s in content["slots"]:
        row, a = SLOTS[s["slotId"]], s["attributes"]
        want = {"SlotId": s["slotId"], "DisplayName": row[0], "RailLabel": row[0], "ModuleType": row[1], "AllowedModuleFolder": row[2],
                "Order": row[3], "CountLabel": row[4], "FixedSlot": True}
        if row[5]:
            want["EnginePosition"] = row[5]
        check(a == want, tag + "slot %s attributes %r" % (s["slotId"], a))
    check([f["name"] for f in content["moduleTypeFolders"]] == [SLOTS[k][2] for k in sorted(SLOTS, key=lambda k: SLOTS[k][3])], tag + "module type folders")
    for f, k in zip(content["moduleTypeFolders"], sorted(SLOTS, key=lambda k: SLOTS[k][3])):
        check(f["attributes"] == {"DisplayName": SLOTS[k][0], "InterchangeableWithinCategory": True, "ModuleType": SLOTS[k][1]}, tag + "module type folder %s attributes %r" % (f["name"], f["attributes"]))

    # Modules.
    kit_of = {n: COCKPITS[CATEGORY + "_" + n][3] for n in numbers}
    shape_parts_spec = {}
    mesh_shapes = {}  # shape key -> (slot, entry of data/mesh.json, is core)
    for m in content["modules"]:
        slot, n, variant = want_modules[m["id"]]
        row, a = SLOTS[slot], m["attributes"]
        mid = m["id"]
        check(m["slot"] == slot, tag + mid + " slot")
        check(a["ModuleId"] == mid and a["CategoryId"] == CATEGORY and a["TemplateType"] == "Module", tag + mid + " identity")
        check(a["ModuleType"] == row[1] and a["ModuleFolder"] == row[2], tag + mid + " ModuleType/ModuleFolder match its slot")
        check(m["folderPath"] == [row[2]] + ([CORE_FOLDER_PREFIX + n] if row[7] else []), tag + mid + " folder path %r" % m["folderPath"])
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
        # F4: CardTitle is the base part name on a GT or EVO body part (the card shows the version as its tag).
        check(a["DisplayName"] == display and a["CardTitle"] == spec["modules"][slot][spec_id]["name"] and a["ModuleName"] == display, tag + mid + " DisplayName/CardTitle/ModuleName")
        if not row[7] and variant:
            base = next(x for x in content["modules"] if x["id"] == mid[:-len(variant) - 1])
            differing = {k for k in set(a) | set(base["attributes"]) if a.get(k) != base["attributes"].get(k)}
            fixed = {"ModuleId", "DisplayName", "ModuleName", "Price", "VariantName", "VariantOrder"}
            stats = BODY_TRIM_STATS[slot]
            allowed = fixed | set(stats) | {"PerformanceDelta_" + k for k in stats} | LEGACY_HEADLINES
            check(fixed <= differing <= allowed, tag + mid + " differs from its base part in %s" % sorted(differing))
            lower = base["attributes"] if variant == "GT" else next(x for x in content["modules"] if x["id"] == mid[:-len(variant)] + "GT")["attributes"]
            moved = [k for k in stats if a[k] != lower[k]]
            check(moved and all((a[k] - lower[k]) * stats[k] > 0 for k in moved), tag + mid + " is better than the version below it in %s and worse in nothing" % moved)
            check(all(a.get("PerformanceDelta_" + k) == a[k] for k in stats), tag + mid + " PerformanceDelta_ twins follow the raw stats")
            if variant == "EVO":
                check(all(abs((a[k] - base["attributes"][k]) - 2 * (lower[k] - base["attributes"][k])) < 1e-9 for k in stats), tag + mid + " EVO adds twice the GT step")
            core_prices = {x["attributes"]["Price"] for x in content["modules"] if SLOTS[x["slot"]][7] and x["id"].endswith(("_" + n + "_LIGHTWEIGHT", "_" + n + "_POWER"))}
            numerator, denominator = BODY_TRIM_FRACTION[variant]
            check(len(core_prices) == 1 and min(core_prices) > 0 and a["Price"] * denominator == min(core_prices) * numerator and a["NeonPrice"] == base["attributes"]["NeonPrice"],
                  tag + mid + " Price is exactly half (GT) or the whole (EVO) of the kit's core variant price %r, got %r" % (sorted(core_prices), a["Price"]))
            check(len(core_prices) == 1 and base["attributes"]["Price"] * BODY_BASE_FRACTION[1] == min(core_prices) * BODY_BASE_FRACTION[0] and 0 < base["attributes"]["Price"] < a["Price"],
                  tag + mid + " its base part is exactly a quarter of the core variant price and cheaper than the trim, got %r" % base["attributes"]["Price"])
            check(m.get("upgradePathDonor") == base.get("upgradePathDonor") and m.get("upgradePaths") == base.get("upgradePaths"), tag + mid + " upgrade paths as its base part")
        check(a["RatingReferenceCockpitId"] == RATING_REFERENCE, tag + mid + " RatingReferenceCockpitId")
        check(a.get("V2Materialised") is True and a.get("RetiredFromCatalog") is False, tag + mid + " V2Materialised/RetiredFromCatalog")
        check(isinstance(a.get("Price"), (int, float)) and isinstance(a.get("NeonPrice"), (int, float)), tag + mid + " Price/NeonPrice")
        if row[7]:
            check(a["ModuleSlot"] == {"Engine": "Engine", "Stabilisers": "Stabilisers", "Boost": "Boost"}[row[1]], tag + mid + " ModuleSlot")
            check(a["SourceCockpitId"] == CATEGORY + "_" + n and a["V2PublishedModuleId"] == mid, tag + mid + " SourceCockpitId/V2PublishedModuleId")
            check(a["EnginePosition"] == (row[5] or "") and a["RearEngine"] is (slot == "Engine2"), tag + mid + " EnginePosition/RearEngine")
            check("PurchasePrice" in a and "VariantName" in a and "VariantOrder" in a, tag + mid + " PurchasePrice/Variant attributes")
            donor = reference["modules"]["MODULE_%s_BRUISER_03_%s" % ({"Engine1": "ENGINE", "Engine2": "ENGINE_B", "Stabilisers": "STABILISER", "Boost": "BOOST"}[slot], variant)]
        else:
            check(a["ModuleSlot"] == slot, tag + mid + " ModuleSlot")
            check(a.get("SourceCockpitId") == CATEGORY + "_" + n and a.get("SourceCockpitDisplayName") == COCKPITS[CATEGORY + "_" + n][1],
                  tag + mid + " a body module is locked to the cockpit of its kit (SourceCockpitId/SourceCockpitDisplayName)")
            check("PurchasePrice" not in a, tag + mid + " body modules carry no PurchasePrice")
            check((a.get("VariantName"), a.get("VariantOrder")) == BODY_VARIANT[variant], tag + mid + " VariantName/VariantOrder %r %r" % (a.get("VariantName"), a.get("VariantOrder")))
            check(not isinstance(a.get("Price"), bool) and isinstance(a.get("Price"), (int, float)) and a["Price"] > 0,
                  tag + mid + " a body module with a source cockpit never has Price 0 (the server would charge 12% of the cockpit price)")
            if slot in MESH_BODY_TRIM_SLOTS and not variant:
                trims = [x["attributes"]["Price"] for t in MESH_BODY_TRIMS for x in content["modules"] if x["id"] == mid + "_" + t]
                check(len(trims) == 2 and a["Price"] < trims[0] < trims[1] and a["Price"] * 4 == trims[1], tag + mid + " base < GT < EVO and base is a quarter of EVO: %r %r" % (a["Price"], trims))
            if not fixture and slot in MESH_EMPTY_SLOTS:
                check(a["Price"] == HIDDEN_BODY_PRICE[int(n) - 1], tag + mid + " a hidden-slot part keeps its price by kit, got %r" % a["Price"])
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
        allowed = CORE_PRIMITIVE_CODES if core else (set("PSDL") if slot in ("FrontBody", "RearBody") else set("PSDN"))
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
            check(c.get("emptySlots") == (list(MESH_EMPTY_SLOTS) if n in EMPTY_KITS else None) and "mesh" not in content["shapes"][c["shape"]],
                  tag + c["id"] + " a primitive cockpit is planned as before (its slots start empty only where the category says so)")
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
        if MESH_CARS:
            check(len(mesh_data["modules"]) == 126 and len(mesh_shapes) == 126 and len(mesh_records) == 560, tag + "126 mesh modules, 560 mesh parts")
        else:
            check(not mesh_data["modules"] and not mesh_data["cockpits"] and not mesh_shapes, tag + "a category without mesh kits has no mesh data")

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
                    check(s["template"] == (VFX_TEMPLATES[2] if left else VFX_TEMPLATES[3]), tag + key + " socket %s template side" % s["name"])
                    check(d[1] < -0.2 or d[2] > 0.9, tag + key + " stabiliser socket %s fires down or back (%s)" % (s["name"], np.round(d, 2)))
                elif SPLAYED_JETS is None:
                    check(d[2] > 0.9 or d[1] > 0.9, tag + key + " socket %s fires back or up (%s)" % (s["name"], np.round(d, 2)))
                    check(abs(d[0]) < 1e-6, tag + key + " socket %s has no sideways component" % s["name"])
                else:
                    # A category whose spec angles its pipes: every engine and boost jet still fires mainly backwards, and
                    # only the recorded shapes lean sideways, away from the car.
                    check(d[2] > 0.55, tag + key + " socket %s fires mainly backwards (%s)" % (s["name"], np.round(d, 2)))
                    check((abs(d[0]) > 1e-6) == (key in SPLAYED_JETS) and d[0] * s["position"][0] >= 0, tag + key + " socket %s leans sideways only outwards, and only on a shape recorded as splayed (%s)" % (s["name"], np.round(d, 2)))
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
        check(a["CockpitId"] == cid and a["V2PublishedCockpitId"] == cid and a["CategoryId"] == CATEGORY and a["TemplateType"] == "Cockpit", tag + cid + " identity")
        check(a["MenuImage"] == a["PreviewImage"] and (a["MenuImage"] == "" or re.fullmatch(r"rbxassetid://\d+", a["MenuImage"])), tag + cid + " card image is empty or one content id on both attributes")
        check(a.get("V2Materialised") is True, tag + cid + " V2Materialised")
        check(a["TargetTier"] == row[4] and a["Price"] == row[5] and a["TargetStockPI"] == row[6], tag + cid + " tier, price and target")
        check(a["StandardAudioProfileId"] == "GENERIC_STANDARD_AUDIO", tag + cid + " audio profile")
        empty = MESH_EMPTY_SLOTS if n in EMPTY_KITS else ()
        for name, slot in list(LEGACY_DEFAULTS.items()) + list(NEW_DEFAULTS.items()):
            want = SLOTS[slot][6] + n + ("_STANDARD" if SLOTS[slot][7] else "")
            if slot in empty:
                # D8: the slot starts empty. The module still exists (primitive); the cockpit just does not default to it.
                check(name not in a and module_slot.get(want) == slot, tag + cid + " declares no %s" % name)
            else:
                check(a.get(name) == want and module_slot.get(want) == slot, tag + cid + " %s" % name)
        check(len([k for k in a if k.startswith("Default") and k.endswith("ModuleId")]) == 13 - len(empty), tag + cid + " has %d default module attributes" % (13 - len(empty)))
        if cid in SEAT_OVERRIDES:
            check(seats.get("overrides", {}).get(cid) == SEAT_OVERRIDES[cid], tag + cid + " data/seats.json holds the D13 starting override")
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
    check(content["meta"]["mode"] == "AUDIT" and content["meta"]["scope"] == scope and content["meta"]["placeId"] == 93959280828322, tag + "meta")
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
    refused("an override of an interface attribute", ids_override({"CockpitId": CATEGORY + "_99"}), "may not change CockpitId")
    refused("an override of a default module", ids_override({"DefaultBoostModuleId": "MODULE_BOOST_%s_%s_POWER" % (FOLDER, PILOT)}), "may not change DefaultBoostModuleId")
    refused("an override of an unknown attribute", ids_override({"NotACockpitAttribute": 1}), "not an attribute of this cockpit")
    result, error = with_data(ids_override({}), build("AUDIT", "pilot"))
    check(error is None and result[0]["cockpits"][0]["attributes"].get("OwnedByDefault") is True, "without the override OwnedByDefault is the balance.json value (true): %r" % (error and error[:200]))

    # Seat acceptance.
    pilot_id = CATEGORY + "_" + PILOT
    six = {"%s_0%d" % (CATEGORY, n): {"driver": [-1.8, 0.25, 0.45], "passenger": [1.8, 0.25, 0.45]} for n in range(1, 7)}
    refused("pending seats", seats_change(decision="pending"), "seat offsets are not accepted, so the full scope cannot be applied", "APPLY", "full")
    for mode, scope in (("AUDIT", "pilot"), ("APPLY", "pilot"), ("AUDIT", "full"), ("ROLLBACK", "full")):
        result, error = with_data(seats_change(decision="pending"), build(mode, scope))
        check(error is None and result[0]["meta"]["seats"]["accepted"] is False, "pending seats still build %s %s: %r" % (mode, scope, error and error[:200]))
    result, error = with_data(seats_change(decision="measured", measuredRootPartCentreAboveSeatTop=1.5, measuredOn="test", rule=1.5, overrides={}), build("APPLY", "full"))
    check(error is None and result[0]["meta"]["seats"] == {"accepted": True, "decision": "measured", "summary": "measured rootPartCentreAboveSeatTop=1.5 (test)"}, "measured seats let APPLY full build: %r" % (error and error[:200]))
    result, error = with_data(seats_change(decision="measured", measuredRootPartCentreAboveSeatTop=1.2, measuredOn="test", rule=1.2, overrides={}), build("APPLY", "full"))
    check(error is None and all(abs(c["attributes"]["DriverSeatOffsetY"] - (DUMMY_TORSO_Y[c["id"]] - 1.2 - 0.225)) < 1e-9 for c in result[0]["cockpits"]), "a measured rule value moves every seat: %r" % (error and error[:200]))
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
    result, error = with_data(seats_change(decision="overrides", overrides={pilot_id: six[pilot_id]}), build("APPLY", "pilot"))
    check(error is None and result[0]["meta"]["seats"]["accepted"] is True, "an override for the pilot cockpit accepts the pilot scope: %r" % (error and error[:200]))
    refused("overrides that miss cockpits", seats_change(decision="overrides", overrides={pilot_id: six[pilot_id]}), "there is no override for %s_01" % CATEGORY, "AUDIT", "full")
    refused("an override for an unknown cockpit", seats_change(overrides={CATEGORY + "_" + PILOT[1:]: six[pilot_id]}), "unknown cockpit")
    refused("an override without a passenger", seats_change(overrides={pilot_id: {"driver": [-1.8, 0.25, 0.45]}}), "overrides.%s.passenger must be three numbers" % pilot_id)
    refused("an override outside the clamp", seats_change(overrides={pilot_id: {"driver": [-1.8, 41, 0.45], "passenger": [1.8, 0.25, 0.45]}}), "overrides.%s.driver must be three numbers" % pilot_id)

    # Mesh kits (mesh/INTEGRATION.md).
    def ids_cockpit(n, **fields):
        return {"ids.json": lambda d: [c.update(fields) for c in d["cockpits"] if c["n"] == n]}

    def mesh_change(change):
        return {"mesh.json": change}

    real_full, error = with_data({}, build("AUDIT", "full"))
    check(error is None, "the full scope builds: %r" % (error and error[:200]))
    refused("an empty core slot", ids_cockpit("02", emptySlots=["Boost"]), "emptySlots may only name", "AUDIT", "full")
    refused("an empty Nose slot", ids_cockpit("02", emptySlots=["FrontBody"]), "emptySlots may only name", "AUDIT", "full")
    if "DefaultRearSpoilerModuleId" in bc.load_json(args.balance)["cockpits"][CATEGORY + "_01"]["attributes"]:  # the stand-in fixture sets no defaults
        # Every cockpit already starts with SidePods, FrontBumper and RearBumper empty; the Wing is the one slot left that may be emptied.
        refused("an empty slot that balance.json still defaults", ids_cockpit("01", emptySlots=list(MESH_EMPTY_SLOTS) + ["RearSpoiler"]), "balance.json sets DefaultRearSpoilerModuleId", "AUDIT", "full")
    if MESH_CARS:
        check_mesh_data_rules(build, refused, mesh_change, real_full)
    else:
        check_trim_slot_rules(build, refused, real_full)
    # A mesh cockpit without a seat override falls back to the spec driver dummy rule (D13: a data-only change either way).
    # SEAT_RULE_FALLBACK: a category whose seats are accepted by overrides needs a measured rule to build without them.
    result, error = with_data(seats_change(overrides={}, **SEAT_RULE_FALLBACK), build("AUDIT", "full"))
    check(error is None and all(abs(c["attributes"]["DriverSeatOffsetY"] - (DUMMY_TORSO_Y[c["id"]] - SEAT_RULE - 0.225)) < 1e-9 for c in result[0]["cockpits"]), "without overrides every cockpit, mesh or not, follows the driver dummy: %r" % (error and error[:200]))
    # Every shipped cockpit has an override now, so the seat X and Z of the dummy rule are checked here.
    spec = vbspec.load(bc.SPEC_PATH)
    for c in (result[0]["cockpits"] if result else []):
        torso = [p for p in bc.flatten(spec["cockpits"][COCKPITS[c["id"]][2]]["parts"]) if p["ch"] == "driver" and p["shape"] == "block"][0]
        a = c["attributes"]
        check(a["DriverSeatOffsetX"] == torso["pos"][0] and a["PassengerSeatOffsetX"] == -torso["pos"][0], c["id"] + " without an override: seat X")
        check(a["DriverSeatOffsetZ"] == torso["pos"][2] == a["PassengerSeatOffsetZ"] and a["PassengerSeatOffsetY"] == a["DriverSeatOffsetY"], c["id"] + " without an override: seat Z, and the passenger at the driver's height")
    fifth = CATEGORY + "_05"
    result, error = with_data(seats_change(overrides={fifth: {"driver": [-1.6, 0.05, 0.5], "passenger": [1.6, 0.05, 0.5]}}, **SEAT_RULE_FALLBACK), build("AUDIT", "full"))
    check(error is None and [[c["attributes"]["DriverSeatOffset" + axis] for axis in "XYZ"] for c in result[0]["cockpits"] if c["id"] == fifth] == [[-1.6, 0.05, 0.5]], "a corrected mesh seat override reaches the cockpit attributes: %r" % (error and error[:200]))


def check_mesh_data_rules(build, refused, mesh_change, real_full):
    """Rules of data/mesh.json (mesh/INTEGRATION.md), on the Exotic mesh kits. build, refused: from check_data_rules."""
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


def check_trim_slot_rules(build, refused, real_full):
    """Rules of data/ids.json bodyTrimSlots, on a category whose body trims are primitive (no data/mesh.json)."""
    def ids_set(key, value):
        return {"ids.json": lambda d: d.__setitem__(key, value)}

    refused("a body trim that balance.json does not hold", ids_set("bodyTrims", ["GT", "EVO", "RS"]), "balance.json has no module MODULE_FRONTBODY_%s_01_RS" % FOLDER, "AUDIT", "full")
    refused("a core slot in bodyTrimSlots", ids_set("bodyTrimSlots", ["FrontBody", "Boost"]), "bodyTrimSlots may only name body slots", "AUDIT", "full")
    refused("an unknown slot in bodyTrimSlots", ids_set("bodyTrimSlots", ["Bonnet"]), "bodyTrimSlots may only name body slots", "AUDIT", "full")
    # The trim slots are data: one slot fewer drops exactly its twelve trims and changes the content hash.
    result, error = with_data(ids_set("bodyTrimSlots", ["FrontBody", "RearBody"]), build("AUDIT", "full"))
    check(error is None and real_full and len(result[0]["modules"]) == 132 and not any(m["slot"] == "RearSpoiler" and m["id"].endswith(("_GT", "_EVO")) for m in result[0]["modules"])
          and result[0]["meta"]["contentHash"] != real_full[0]["meta"]["contentHash"], "bodyTrimSlots decides which slots carry trims: %r" % (error and error[:200]))
    # Without bodyTrimSlots a trim exists only where data/mesh.json holds it (the Exotic rule): none here.
    result, error = with_data({"ids.json": lambda d: d.pop("bodyTrimSlots")}, build("AUDIT", "full"))
    check(error is None and len(result[0]["modules"]) == 108 and not any(m["id"].endswith(("_GT", "_EVO")) for m in result[0]["modules"]), "without bodyTrimSlots and without meshes there are no trims: %r" % (error and error[:200]))
    result, error = with_data(ids_set("coreFolderPrefix", "Other_"), build("AUDIT", "full"))
    check(error is None and real_full and all(m["folderPath"][1:] in ([], ["Other_" + m["id"].split("_")[-2]]) for m in result[0]["modules"])
          and result[0]["meta"]["contentHash"] != real_full[0]["meta"]["contentHash"], "coreFolderPrefix names the core family folders and is inside the content hash: %r" % (error and error[:200]))
    result, error = with_data({"ids.json": lambda d: d.pop("coreFolderPrefix")}, build("AUDIT", "full"))
    check(error is None and all(m["folderPath"][1:] in ([], ["Exotic_" + m["id"].split("_")[-2]]) for m in result[0]["modules"]), "without coreFolderPrefix the folders keep the Exotic default: %r" % (error and error[:200]))


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


def check_muscle(full, pilot, spec, args):
    """Modern Muscle only: what the category contract fixes and the shared checks do not cover."""
    # Pilot against full, as for Exotic.
    by_id = {m["id"]: m for m in full["modules"]}
    check(all(by_id[m["id"]]["attributes"] == m["attributes"] and by_id[m["id"]]["shape"] == m["shape"] for m in pilot["modules"]), "pilot modules equal the same modules in the full scope")
    check(set(pilot["shapes"]) <= set(full["shapes"]) and all(full["shapes"][k] == v for k, v in pilot["shapes"].items()), "pilot geometry and sockets equal the full scope")
    check(sorted(pilot["shapes"]) == sorted(["Cockpit/hardtop"] + ["%s/%s" % (slot, spec["kits"]["prostreet"]["modules"][slot]) for slot in SLOTS]), "the pilot is the Hardtop with the Pro Street kit: %r" % sorted(pilot["shapes"]))
    check(full["meta"]["contentHash"] != pilot["meta"]["contentHash"], "pilot and full have different content hashes")

    # Identity of the category and of this installer.
    check(full["category"] == {"folder": "MUSCLE", "afterFolder": "PIERCER", "attributes": MUSCLE_CATEGORY_ATTRIBUTES}, "category folder and attributes: %r" % full["category"])
    check(full["meta"]["marker"] == "muscle_category/stage_b" and full["meta"]["placeId"] == 93959280828322 and full["meta"]["blockoutCheck"] == "warn", "marker, place id and blockout check: %r" % full["meta"])
    check("mesh" not in full and all(len(r) == 11 and r[0] != "mesh" for v in full["shapes"].values() for r in v["parts"]), "no mesh parts: every part is a primitive record")
    check(all(c["attributes"]["MenuImage"] == "" and c["attributes"]["PreviewImage"] == "" for c in full["cockpits"]), "no card images yet")
    check(all(c.get("emptySlots") == ["SidePods", "FrontBumper", "RearBumper"] for c in full["cockpits"]), "SidePods, FrontBumper and RearBumper start empty on all six")
    check(all(m["palette"] == next(c for c in full["cockpits"] if c["id"] == m["attributes"]["SourceCockpitId"])["palette"] for m in full["modules"]), "every module wears the paint of the cockpit of its kit")

    # Body trims: no mesh, so a trim is its base part's shape with other attributes.
    trims = [m for m in full["modules"] if m["id"].endswith(("_GT", "_EVO"))]
    check(len(trims) == 36 and all(m["shape"] == by_id[m["id"].rsplit("_", 1)[0]]["shape"] and m["partCount"] == by_id[m["id"].rsplit("_", 1)[0]]["partCount"] for m in trims), "the 36 trims share the primitive shape of their base part")
    check(len({m["shape"] for m in full["modules"]}) == 60 and sum(1 for k in full["shapes"] if k.startswith("Cockpit/")) == 6, "60 module shapes and 6 cockpit shapes")
    core_neon = sorted(k for k, v in full["shapes"].items() if k.split("/")[0] in SOCKET_RULES and any(r[10] == "N" for r in v["parts"]))
    check(core_neon == ["Boost/sill_slots"], "the one core shape with optional neon is Sill Slots: %r" % core_neon)

    # Sockets: worked examples from the spec geometry, and the stock totals (5 hover dust + the four Standard core modules).
    shapes = full["shapes"]
    check(shapes["Engine2/mono_turbine"]["sockets"] == [{"name": "VFX_EngineJet_Back", "template": "EngineJet_Muscle", "position": [0.0, 2.05, 13.6], "orientation": [0.0, 0.0, 0.0]}], "Mono Turbine fires straight back from one socket: %r" % shapes["Engine2/mono_turbine"]["sockets"])
    check(shapes["Engine1/cowl_slot"]["sockets"] == [{"name": "VFX_EngineJet_Back", "template": "EngineJet_Muscle", "position": [0.0, 4.6, -2.8], "orientation": [0.0, 0.0, 0.0]}], "Cowl Slot Turbine: %r" % shapes["Engine1/cowl_slot"]["sockets"])
    check(shapes["Boost/megaphones"]["sockets"] == [{"name": "VFX_BoostJet_Left", "template": "BoostJet_Muscle", "position": [-5.55, -0.58, 2.2], "orientation": [0.0, 0.0, 0.0]},
                                                     {"name": "VFX_BoostJet_Right", "template": "BoostJet_Muscle", "position": [5.55, -0.58, 2.2], "orientation": [0.0, 0.0, 0.0]}], "Megaphones: %r" % shapes["Boost/megaphones"]["sockets"])
    paddles = {s["name"]: s for s in shapes["Stabilisers/glide_paddles"]["sockets"]}
    check(sorted(paddles) == ["VFX_StabiliserJet_Left_Front", "VFX_StabiliserJet_Left_Rear", "VFX_StabiliserJet_Right_Front", "VFX_StabiliserJet_Right_Rear"]
          and paddles["VFX_StabiliserJet_Left_Front"] == {"name": "VFX_StabiliserJet_Left_Front", "template": "StabiliserJet_MuscleLeft", "position": [-4.5, -0.5967, -6.0033], "orientation": [45.0, 0.0, 0.0]}
          and paddles["VFX_StabiliserJet_Right_Rear"]["template"] == "StabiliserJet_MuscleRight", "Glide Paddles fire 45 degrees down and back: %r" % paddles)
    names = {key: [s["name"] for s in shapes[key]["sockets"]] for key in ("Engine2/over_under", "Engine2/inline_four", "Engine1/blower_stack")}
    check(names == {"Engine2/over_under": ["VFX_EngineJet_Back", "VFX_EngineJet_Back2"], "Engine2/inline_four": ["VFX_EngineJet_Left", "VFX_EngineJet_Left2", "VFX_EngineJet_Right", "VFX_EngineJet_Right2"],
                    "Engine1/blower_stack": ["VFX_EngineJet_Left", "VFX_EngineJet_Left2", "VFX_EngineJet_Right", "VFX_EngineJet_Right2"]}, "a second jet on one side gets the suffix 2: %r" % names)
    stock = {}
    for c in full["cockpits"]:
        defaults = {v for k, v in c["attributes"].items() if k.startswith("Default") and k.endswith("ModuleId")}
        stock[c["id"]] = 5 + sum(len(shapes[m["shape"]].get("sockets", [])) for m in full["modules"] if m["id"] in defaults)
    check(stock == {"muscle_01": 15, "muscle_02": 17, "muscle_03": 16, "muscle_04": 16, "muscle_05": 15, "muscle_06": 13}, "sockets per stock car: %r" % stock)

    # The paths this run used: nothing of Exotic's is read or written.
    here = os.path.join(bc.REPO, "scripts", "exotic_category", "categories", "muscle")
    check(os.path.abspath(bc.DATA_DIR) == os.path.join(here, "data") and os.path.abspath(bc.OUT_DIR) == os.path.join(here, "out")
          and os.path.abspath(bc.FINGERPRINTS_PATH) == os.path.join(here, "fingerprints.json") and not os.path.isfile(bc.MESH_PATH), "data, outputs and fingerprints are Muscle's own, and there is no mesh.json")
    check(os.path.abspath(bc.SPEC_PATH) == os.path.join(bc.REPO, "scripts", "vehicle_blockouts", "specs", "muscle.json")
          and os.path.abspath(bc.BALANCE_PATH) == os.path.join(bc.REPO, "scripts", "exotic_category", "balance", "muscle", "balance.json"), "spec and balance paths")
    ids = bc.load_json(os.path.join(bc.DATA_DIR, "ids.json"))
    check(ids["coreFolderPrefix"] == "Muscle_" and ids["bodyTrims"] == ["GT", "EVO"] and ids["bodyTrimSlots"] == ["FrontBody", "RearBody", "RearSpoiler"]
          and ids["pilotCockpit"] == "04" and ids["cockpitAttributeOverrides"] == {"OwnedByDefault": False} and ids["variants"] == list(VARIANTS), "data/ids.json category keys")
    check(all("cardImage" not in c and c["kitName"] == c["displayName"] for c in ids["cockpits"]), "no card image; the kit is named after the car")
    exotic_slots = bc.load_json(os.path.join(os.path.dirname(os.path.abspath(bc.__file__)), "data", "ids.json"))["slots"]
    check(json.loads(json.dumps(ids["slots"]).replace("_MUSCLE_", "_EXOTIC_")) == exotic_slots, "the slot table is Exotic's with MUSCLE in the id prefixes (labels, order, donors)")
    text = bc.render_installer(full, "return function() end")
    check(text.split("\n")[1].startswith("-- Modern Muscle category, Stage B content installer. mode=AUDIT scope=full contentHash=" + full["meta"]["contentHash"]), "installer header: %r" % text.split("\n")[1][:120])

    # The category's own copy of the read-only report: the Exotic file with one line changed.
    with open(bc.POST_CHECKS_PATH, "r", encoding="utf-8") as f:
        source_lines = f.read().replace("\r\n", "\n").split("\n")
    copy_lines = bc.render_post_install_checks("MUSCLE").split("\n")
    changed = [(a, b) for a, b in zip(source_lines, copy_lines[1:]) if a != b]
    check(copy_lines[0].startswith("-- GENERATED by ") and len(copy_lines) == len(source_lines) + 1 and changed == [('local CATEGORY = "EXOTIC"', 'local CATEGORY = "MUSCLE"')],
          "post_install_checks.lua for Muscle is the Exotic report with only the CATEGORY line changed: %r" % changed)
    for bad in ("muscle", "MUSCLE\"", ""):
        try:
            bc.render_post_install_checks(bad)
            check(False, "a category folder %r must be refused" % bad)
        except bc.BuildError:
            check(True, "")

    # Seats: explicit overrides for all six, from the spec. Seated R15 figure of the contract: root part centre 1.5
    # above the seat top, head top 2.2 above the root part centre; feet about 2.25 below it (Exotic seat notes).
    seats = bc.load_json(os.path.join(bc.DATA_DIR, "seats.json"))
    check(seats["pilotAcceptance"]["decision"] == "overrides" and "not measured" in seats["pilotAcceptance"]["note"] and sorted(seats["overrides"]) == sorted(COCKPITS), "seats: overrides for all six, recorded as not measured")
    check(full["meta"]["seats"] == {"accepted": True, "decision": "overrides", "summary": "explicit overrides for every cockpit in scope"}, "seat acceptance: %r" % full["meta"]["seats"])
    for c in full["cockpits"]:
        cid, a = c["id"], c["attributes"]
        flat = bc.flatten(spec["cockpits"][COCKPITS[cid][2]]["parts"])
        torso = [p for p in flat if p["ch"] == "driver" and p["shape"] == "block"][0]
        check(torso["pos"][1] == DUMMY_TORSO_Y[cid], cid + " dummy torso height %r" % torso["pos"][1])
        check(a["DriverSeatOffsetX"] == torso["pos"][0] and -2.0 <= a["DriverSeatOffsetX"] <= -1.8 and a["PassengerSeatOffsetX"] == -torso["pos"][0], cid + " seat X is the dummy torso X, mirrored for the passenger")
        check(a["DriverSeatOffsetZ"] == torso["pos"][2] == a["PassengerSeatOffsetZ"] and a["PassengerSeatOffsetY"] == a["DriverSeatOffsetY"], cid + " seat Z is the dummy torso Z; the passenger sits at the driver's height")
        seat_y = a["DriverSeatOffsetY"]
        root_y = seat_y + 0.225 + 1.5
        head_top, feet = root_y + 2.2, root_y - 2.25
        roof = MUSCLE_ROOF_UNDERSIDE[cid]
        if roof is None:
            check(abs(root_y - torso["pos"][1]) < 1e-9, cid + " open cockpit: the root part sits on the dummy torso")
        else:
            # The roof panel: the lowest non-glass block over any part of the head (a 1.2 cube above the seat) whose
            # underside is above the dummy head centre.
            over = [p["pos"][1] - p["size"][1] / 2 for p in flat if p["shape"] == "block" and p["ch"] not in ("glass", "driver") and p["rot"] == [0.0, 0.0, 0.0]
                    and abs(p["pos"][0] - torso["pos"][0]) < p["size"][0] / 2 + 0.6 and abs(p["pos"][2] - torso["pos"][2]) < p["size"][2] / 2 + 0.6
                    and p["pos"][1] - p["size"][1] / 2 > torso["pos"][1] + 0.9]
            check(over and abs(min(over) - roof) < 1e-9, cid + " roof underside %r in the spec, %r here" % (over, roof))
            check(abs(head_top - (roof - 0.2)) < 1e-9 and root_y < torso["pos"][1], cid + " head top %.3f is 0.2 under the roof underside %.2f (the dummy rule would be higher)" % (head_top, roof))
        check((feet >= 0.3 - 1e-9) == (cid not in MUSCLE_FEET_BELOW_FLOOR) and feet > -0.4, cid + " feet at %.3f against the tub floor (top 0.3, underside -0.4)" % feet)

    # Cockpit fixtures follow the Muscle frame datums, not Exotic's.
    datums = spec["standard"]["datums"]
    fixtures = bc.load_json(os.path.join(bc.DATA_DIR, "cockpit_fixtures.json"))
    dust = {d["name"]: d["position"] for d in fixtures["hoverDust"]}
    check((datums["frontArchZ"], datums["rearArchZ"], datums["noseShelfZ"], datums["tailFaceZ"], datums["floor"]) == (-7.6, 8.3, -12.3, 12.1, -0.4), "Muscle frame datums: %r" % datums)
    check(dust == {"VFX_HoverDust_FrontLeft": [-4.7, -1.375, -7.6], "VFX_HoverDust_FrontRight": [4.7, -1.375, -7.6], "VFX_HoverDust_RearLeft": [-4.7, -1.375, 8.3],
                   "VFX_HoverDust_RearRight": [4.7, -1.375, 8.3], "VFX_HoverDust_Center": [0, -1.375, 0]}, "hover dust under the four arches and the centre: %r" % dust)
    check(fixtures["lenses"] == {"cockpit front spotlight lens ": {"position": [0, 2.0, -12.3]}, "cockpit rear spotlight lens ": {"position": [0, 2.2, 12.1]}}, "lenses at the nose shelf and the tail face")
    emitter = fixtures["underglow"]["emitters"]
    check(len(emitter) == 1 and emitter[0]["size"] == [9.0, 0.5, 24.0] and emitter[0]["position"] == [0, -0.2, -0.1] and emitter[0]["face"] == "Bottom"
          and abs(emitter[0]["position"][1] - emitter[0]["size"][1] / 2 - (datums["floor"] - 0.05)) < 1e-9, "one underglow slab just under the Muscle floor: %r" % emitter)
    exotic_fixtures = bc.load_json(os.path.join(os.path.dirname(os.path.abspath(bc.__file__)), "data", "cockpit_fixtures.json"))
    check(all(fixtures[k] == exotic_fixtures[k] for k in ("rootDonorCockpitId", "rootDonorChildren", "rootSize")), "the cockpit root donor is the one Exotic uses")
    colours, exotic_colours = bc.load_json(os.path.join(bc.DATA_DIR, "colours.json")), bc.load_json(os.path.join(os.path.dirname(os.path.abspath(bc.__file__)), "data", "colours.json"))
    check({k: v for k, v in colours.items() if not k.startswith("_")} == {k: v for k, v in exotic_colours.items() if not k.startswith("_")}, "colour rules and finish as Exotic (ExoticFlakePaint reused)")
    vfx, exotic_vfx = bc.load_json(os.path.join(bc.DATA_DIR, "vfx.json")), bc.load_json(os.path.join(os.path.dirname(os.path.abspath(bc.__file__)), "data", "vfx.json"))
    strip = lambda t: {k: v for k, v in t.items() if not k.startswith("_") and k != "name"}  # noqa: E731
    check([strip(t) for t in vfx["templates"]] == [strip(t) for t in exotic_vfx["templates"]] and vfx["requiredStock"] == exotic_vfx["requiredStock"], "VFX scales as Exotic")
    rules, exotic_rules = bc.load_json(os.path.join(bc.DATA_DIR, "sockets.json")), bc.load_json(os.path.join(os.path.dirname(os.path.abspath(bc.__file__)), "data", "sockets.json"))
    same = lambda d: json.loads(json.dumps({k: v for k, v in d.items() if not k.startswith("_")}).replace("Muscle", "Exotic"))  # noqa: E731
    check({k: ({a: b for a, b in v.items() if not a.startswith("_")} if isinstance(v, dict) else v) for k, v in same(rules).items() if k != "overrides"}
          == {k: ({a: b for a, b in v.items() if not a.startswith("_")} if isinstance(v, dict) else v) for k, v in same(exotic_rules).items() if k != "overrides"}, "socket rules as Exotic, with the Muscle template names")
    # One recorded override: the computed tunnel ram sockets (yaw 35.58) do not survive Instance:Clone() bit for bit,
    # which fails the installer's exact preview comparison. The override keeps the computed position and moves yaw 0.02.
    check(exotic_rules["overrides"] == {} and rules["overrides"] == {"Engine1/tunnel_ram": [
        {"name": "VFX_EngineJet_Left", "template": "EngineJet_Muscle", "position": [-1.8507, 4.2138, -4.0621], "orientation": [-12.35, -35.6, 0.0]},
        {"name": "VFX_EngineJet_Right", "template": "EngineJet_Muscle", "position": [1.8507, 4.2138, -4.0621], "orientation": [-12.35, 35.6, 0.0]}]},
        "the only socket override is the tunnel ram pair, at the computed position")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--category", default=bc.DEFAULT_CATEGORY, help="exotic (default) or muscle")
    parser.add_argument("--balance")
    parser.add_argument("--catalogue-gen")
    parser.add_argument("--fill-from-donor", action="store_true")
    args = parser.parse_args()
    use_category(args.category)
    exotic = CATEGORY == bc.DEFAULT_CATEGORY
    real = os.path.isfile(bc.BALANCE_PATH) and os.path.isfile(bc.CATALOGUE_GEN_PATH)
    if not args.balance:
        args.balance = bc.BALANCE_PATH if real else os.path.join(FIXTURES, "balance.json" if exotic else "balance-%s.json" % CATEGORY)
    if not args.catalogue_gen:
        args.catalogue_gen = bc.CATALOGUE_GEN_PATH if os.path.isfile(bc.CATALOGUE_GEN_PATH) else os.path.join(FIXTURES, "catalogue_gen.lua")
    print("balance: %s\ncatalogue_gen: %s" % (os.path.relpath(args.balance, bc.REPO), os.path.relpath(args.catalogue_gen, bc.REPO)))

    spec = vbspec.load(bc.SPEC_PATH)
    reference = bc.capture_reference(bc.load_json(bc.CAPTURE_PATH))
    live = {}
    if exotic:
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
    else:
        # Muscle: 155 cockpit parts (the driver dummies dropped) and 978 parts over the 60 module shapes, all primitive.
        # There is no live blockout measurement: the place has no Muscle showroom block (data/ids.json blockoutCheck warn).
        EXPECTED_PARTS["cockpit"] = (155, 0)
        EXPECTED_PARTS["module"] = (978, 0)
    check(len(bc.all_fingerprints(spec)) == 66, "66 cockpit+shape groups in the spec")

    # A missing input must fail clearly.
    try:
        bc.build_content("AUDIT", "pilot", os.path.join(FIXTURES, "does-not-exist.json"), args.catalogue_gen)
        check(False, "a missing balance.json must stop the build")
    except bc.BuildError as error:
        check("balance.json is missing" in str(error), "missing balance.json message: %s" % error)

    full = check_scope("full", args, spec, reference, live)
    pilot = check_scope("pilot", args, spec, reference, live)
    if full and pilot and not exotic:
        check_muscle(full, pilot, spec, args)
    if full and pilot and exotic:
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
    check([t["name"] for t in vfx["templates"]] == VFX_TEMPLATES, "the four %s VFX template names" % CATEGORY_DISPLAY)
    check({t["name"]: t.get("group") for t in vfx["templates"]} == dict(zip(VFX_TEMPLATES, (None, None, "DriftLeft", "DriftRight"))), "stabiliser templates carry DriftLeft / DriftRight")
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
    check("93959280828322" not in engine and "META.placeId" in engine, "the place id comes from the data, and the engine asserts it")
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
