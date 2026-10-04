"""Checks for the Exotic balance data. Read-only.

    py -3 scripts/exotic_category/balance/test_balance.py

Every rule is checked from balance.json itself (the file the content builder reads), against
INTERFACE.md, the baseline capture and the blockout spec.

The tests are plain test_* functions with no fixtures. They were run with the command above
only: pytest is not installed on this machine, so a pytest run is not verified.
"""
from __future__ import annotations

import json
import math
import random
import re
import sys
import traceback
from pathlib import Path

import build_balance as B
import rating as R

HERE = Path(__file__).resolve().parent
INTERFACE_PATH = HERE.parent / "INTERFACE.md"
MESH_DATA_PATH = HERE.parent / "stage_b" / "data" / "mesh.json"

# scripts/exotic_category/mesh/INTEGRATION.md, written out again here on purpose (D6 to D9).
MESH_KITS = (1, 2, 3, 4, 5, 6)
MESH_STOCK_BODY_STEMS = ("MODULE_FRONTBODY_EXOTIC", "MODULE_REARBODY_EXOTIC", "MODULE_REARSPOILER_EXOTIC")
MESH_EMPTY_DEFAULTS = {"DefaultSidePodsModuleId", "DefaultFrontBumperModuleId", "DefaultRearBumperModuleId"}
BODY_TRIM_FACTOR = {"GT": 2.0, "EVO": 3.5}

_CACHE = {}


def ctx():
    """Build once: the generated data, the file on disk and the analysis."""
    if not _CACHE:
        balance, design, reductions, live = B.build()
        _CACHE.update({
            "balance": balance, "design": design, "reductions": reductions, "live": live,
            "disk_text": B.BALANCE_PATH.read_bytes(),
        })
        _CACHE["disk"] = json.loads(_CACHE["disk_text"].decode("ascii"))
        _CACHE["analysis"] = B.analyse(_CACHE["disk"], design, live)
    return _CACHE


def interface_rows():
    """The cockpit table of INTERFACE.md."""
    rows = []
    for line in INTERFACE_PATH.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\| (0[1-6]) \| `(exotic_0[1-6])` \| `(COCKPIT_EXOTIC_0[1-6])` \| (\w+) \| `(\w+)` \| `(\w+)` \| (\w+) \| ([EDCBAS]) \| (\d+) \| (\d+) \|$", line)
        if match:
            rows.append({"n": int(match.group(1)), "id": match.group(2), "model": match.group(3), "name": match.group(4),
                         "spec_cockpit": match.group(5), "spec_kit": match.group(6), "kit_name": match.group(7),
                         "tier": match.group(8), "price": int(match.group(9)), "target": int(match.group(10))})
    return rows


def expected_module_ids():
    core, body = [], []
    for n in range(1, 7):
        for stem in ("MODULE_ENGINE_EXOTIC", "MODULE_ENGINE_B_EXOTIC", "MODULE_STABILISER_EXOTIC", "MODULE_BOOST_EXOTIC"):
            for variant in ("STANDARD", "LIGHTWEIGHT", "POWER"):
                core.append("%s_%02d_%s" % (stem, n, variant))
        for stem in ("MODULE_FRONTBODY_EXOTIC", "MODULE_REARBODY_EXOTIC", "MODULE_SIDEPODS_EXOTIC",
                     "MODULE_FRONTBUMPER_EXOTIC", "MODULE_REARBUMPER_EXOTIC", "MODULE_REARSPOILER_EXOTIC"):
            body.append("%s_%02d" % (stem, n))
    return core, body


def trim_module_ids():
    """The twelve new body ids of the mesh kits (D6): {new id: (base id, trim)}."""
    return {"%s_%02d_%s" % (stem, n, trim): ("%s_%02d" % (stem, n), trim)
            for n in MESH_KITS for stem in MESH_STOCK_BODY_STEMS for trim in BODY_TRIM_FACTOR}


def kind(value):
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, str):
        return "string"
    return type(value).__name__


def stock_components(c, cockpit_id):
    attributes = c["disk"]["cockpits"][cockpit_id]["attributes"]
    names = ["DefaultEngineModuleId", "DefaultEngineBModuleId", "DefaultStabilisersModuleId", "DefaultBoostModuleId",
             "DefaultFrontBodyModuleId", "DefaultRearBodyModuleId", "DefaultSidePodsModuleId",
             "DefaultFrontBumperModuleId", "DefaultRearBumperModuleId", "DefaultRearSpoilerModuleId"]
    # A mesh cockpit declares no default for three body slots (D8): its stock build is seven modules, not ten.
    empty = MESH_EMPTY_DEFAULTS if int(cockpit_id[-2:]) in MESH_KITS else set()
    assert {name for name in names if name not in attributes} == empty, cockpit_id
    return [B.as_component(c["live"], c["disk"]["modules"][attributes[name]]) for name in names if name not in empty]


# ---------------------------------------------------------------------------


def test_rating_port_reproduces_the_six_piercer_stock_builds():
    c = ctx()
    for path, sha in R.PORTED_SOURCES.items():
        assert c["live"].capture.manifest_sha(path) == sha, "live source changed since the port: " + path
    rows = R.piercer_stock_builds(c["live"].capture, c["live"].calculator)
    computed = [row["Result"]["Overall"]["PerformanceIndex"] for row in rows]
    assert computed == [202, 374, 525, 662, 787, 925], computed
    assert [row["Result"]["Overall"]["Tier"] for row in rows] == list("EDCBAS")
    for row in rows:
        assert row["Result"]["Overall"]["Tier"] == row["TargetTier"]
        assert abs(row["Result"]["Overall"]["PerformanceIndex"] - row["TargetStockPI"]) <= 2
        assert row["ProfileMaxAbsDiff"] < 1e-9
    assert [row["TargetStockPI"] for row in rows][2:] == computed[2:]


def test_rating_port_keeps_luau_semantics():
    """Luau `or` falls through on nil and false only; tonumber follows C strtod.
    The tonumber table is the output of live Studio (read-only, 2026-10-02, place 133417340424236)."""
    assert R.lua_or(0, 3) == 0 and R.lua_or("", "x") == "" and R.lua_or(False, 3) == 3 and R.lua_or(None, None, 7) == 7
    inf, nan = math.inf, "nan"
    studio = {
        "inf": inf, "-inf": -inf, "infinity": inf, "nan": nan, "-nan": nan, "NaN": nan, "INF": inf, "1_0": None,
        "0x10": 16, "-0x10": -16, "0x1p4": 16, "0X1F": 31, " 5 ": 5, "5.": 5, ".5": 0.5, "1e3": 1000, "1E-2": 0.01,
        "": None, " ": None, "5x": None, "0x": None, "1e": None, "+5": 5, "--5": None, "0b11": None,
        "\u096b": None, "1,5": None, "nan(1)": nan, "\t7\n": 7, "0x1.8": 1.5, "1e400": inf,
    }
    for text, expected in studio.items():
        value = R._tonumber(text)
        if expected == "nan":
            assert value is not None and value != value, text
        else:
            assert value == expected, (text, value)
    assert R._tonumber(True) is None and R._tonumber(None) is None and R._tonumber(2.5) == 2.5
    assert R._clamp(math.nan, 0, 3) != R._clamp(math.nan, 0, 3)  # NaN stays NaN
    assert R._floor(math.inf) == math.inf and R._floor(2.7) == 2

    def module(capacity=6, per_path=None, **path):
        attributes = {"UpgradePointCapacity": capacity, "Point1CostGuide": 100, "Point2CostGuide": 200, "Point3CostGuide": 300}
        if per_path is not None:
            attributes["MaxPointsPerPath"] = per_path
        return attributes, [{"Name": "Folder", "attributes": dict(path)}]

    # MaxPointsPerPath = 0 is kept (Python truthiness would turn it into 3).
    attributes, paths = module(per_path=0, PathId="Folder", DeltaFlat_TopSpeed=1)
    assert R.normalize_allocation(attributes, paths, {"Folder": 2}) == ({"Folder": 0}, 0, 6)
    # MaxPoints = 0 on the path is kept, in both places it is read.
    attributes, paths = module(PathId="Folder", MaxPoints=0, DeltaFlat_TopSpeed=1)
    assert R.normalize_allocation(attributes, paths, {"Folder": 2}) == ({"Folder": 0}, 0, 6)
    assert R.next_point_cost(attributes, paths, {}, "Folder") is None
    # Neither set: 3 points per path.
    attributes, paths = module(PathId="Folder", DeltaFlat_TopSpeed=1)
    assert R.normalize_allocation(attributes, paths, {"Folder": 9}) == ({"Folder": 3}, 3, 6)
    assert R.apply_to_module_raw(attributes, paths, {"Folder": 9})["TopSpeed"] == 3
    assert [R.next_point_cost(attributes, paths, {"Folder": n}, "Folder") for n in range(4)] == [100, 200, 300, None]
    # An empty-string PathId is kept as the id (it does not fall back to the folder name).
    attributes, paths = module(PathId="", DeltaFlat_TopSpeed=1)
    assert R.path_id(paths[0]) == "" and R.normalize_allocation(attributes, paths, {"": 1})[0] == {"": 1}
    # A missing or false PathId falls back to the folder name.
    assert R.path_id({"Name": "Folder", "attributes": {}}) == "Folder"
    assert R.path_id({"Name": "Folder", "attributes": {"PathId": False}}) == "Folder"
    # Every live path and every Exotic path is named by its PathId, so each one can be bought.
    c = ctx()
    for module_id, live_module in c["live"].modules.items():
        for path in live_module["paths"]:
            assert R.path_id(path) == path["Name"], module_id
    for module_id, entry in c["disk"]["modules"].items():
        for path in B.paths_for(c["live"], entry):
            assert R.path_id(path) == path["Name"], module_id


def test_fast_index_matches_the_port():
    """The search helper in build_balance.py must agree with the ported calculator."""
    c = ctx()
    index = B.fast_index(c["live"])
    calculator = c["live"].calculator
    samples = [c["design"][cockpit["id"]]["result"]["Raw"] for cockpit in B.COCKPITS]
    samples += [row["Raw"] for row in R.piercer_stock_builds(c["live"].capture, calculator)]
    generator = random.Random(20261002)
    for _ in range(300):
        base = samples[generator.randrange(12)]
        samples.append({name: base[name] * generator.uniform(-0.2, 2.5) for name in R.RAW_ORDER})
    samples.append({name: 0 for name in R.RAW_ORDER})
    for raw in samples:
        exact = calculator.calculate(raw)["Overall"]["UnroundedPerformanceIndex"]
        assert abs(index(B.raw_list(raw)) - exact) < 1e-9, raw


def test_file_is_the_deterministic_build():
    c = ctx()
    again, _, _, _ = B.build(c["live"])
    assert B.dump_balance(again) == B.dump_balance(c["balance"])
    assert B.dump_balance(c["balance"]).encode("ascii") == c["disk_text"], "balance.json is stale: run build_balance.py"


def test_keys_are_exactly_the_interface_schema():
    c = ctx()
    disk = c["disk"]
    assert list(disk.keys()) == ["cockpits", "modules"]
    for entry in disk["cockpits"].values():
        assert sorted(entry.keys()) == ["attributes", "headlines", "stockPI", "stockTier"]
        assert sorted(entry["headlines"].keys()) == sorted(R.HEADLINE_ORDER)
    for module_id, entry in disk["modules"].items():
        keys = set(entry.keys())
        assert "attributes" in keys
        rest = keys - {"attributes"}
        assert rest in ({"upgradePathDonor"}, {"upgradePaths"}), (module_id, rest)


def test_ids_counts_and_interface_table():
    c = ctx()
    disk = c["disk"]
    rows = interface_rows()
    assert len(rows) == 6, "INTERFACE.md cockpit table not found"
    assert sorted(disk["cockpits"]) == [row["id"] for row in rows]
    assert len(disk["cockpits"]) == 6 and len(disk["modules"]) == 144
    core, body = expected_module_ids()
    trims = trim_module_ids()
    assert len(core) == 72 and len(body) == 36 and len(trims) == 36
    assert sorted(disk["modules"]) == sorted(core + body + list(trims))
    # The new ids are exactly the body trims stage_b/data/mesh.json holds, and every mesh id has balance data.
    mesh = json.loads(MESH_DATA_PATH.read_text(encoding="utf-8"))
    assert {module_id for module_id in mesh["modules"] if module_id.endswith(("_GT", "_EVO"))} == set(trims)
    assert set(mesh["modules"]) <= set(disk["modules"]) and len(mesh["modules"]) == 126
    assert {entry["kit"] for entry in mesh["modules"].values()} == set(MESH_KITS)
    assert sorted(mesh["cockpits"]) == ["exotic_%02d" % n for n in MESH_KITS]
    spec = c["live"].spec
    for row, built in zip(rows, B.COCKPITS):
        for key in ("n", "id", "model", "name", "spec_cockpit", "spec_kit", "kit_name", "tier", "price", "target"):
            assert row[key] == built[key], (row["id"], key)
        attributes = disk["cockpits"][row["id"]]["attributes"]
        assert attributes["CockpitId"] == row["id"] and attributes["V2PublishedCockpitId"] == row["id"]
        assert attributes["DisplayName"] == row["name"] == spec["cockpits"][row["spec_cockpit"]]["name"]
        assert spec["cockpits"][row["spec_cockpit"]]["kit"] == row["spec_kit"]
        assert spec["kits"][row["spec_kit"]]["name"] == row["kit_name"]
        assert attributes["CategoryId"] == "exotic"
        assert attributes["Price"] == row["price"]
        assert attributes["TargetStockPI"] == row["target"] and attributes["TargetTier"] == row["tier"]
        assert attributes["MenuImage"] == ""
    for module_id, entry in disk["modules"].items():
        assert entry["attributes"]["ModuleId"] == module_id
        assert entry["attributes"]["CategoryId"] == "exotic"


def test_prices():
    c = ctx()
    disk = c["disk"]
    text = INTERFACE_PATH.read_text(encoding="utf-8")
    body_prices = [int(x) for x in re.search(r"Body part prices by kit number 01\.\.06: ([\d, ]+)\.", text).group(1).split(", ")]
    body_neon = [int(x) for x in re.search(r"Body `NeonPrice` by kit: ([\d, ]+)\.", text).group(1).split(", ")]
    assert body_prices == [8000, 11000, 14000, 18000, 23000, 30000] and body_neon == [6500, 7000, 7500, 8000, 8500, 9500]
    piercer = c["live"].cockpits
    for cockpit in B.COCKPITS:
        n = cockpit["n"]
        ratio = cockpit["price"] / piercer[cockpit["piercer"]]["attributes"]["Price"]
        assert 1.24 <= ratio <= 1.28, (cockpit["id"], ratio)  # about 25% over the matching Piercer
        variant_price = cockpit["price"] * 12 // 100
        for slot in B.CORE_ORDER:
            stem, donor_stem = B.CORE_SLOTS[slot][0], B.CORE_SLOTS[slot][1]
            standard = disk["modules"]["%s_%02d_STANDARD" % (stem, n)]["attributes"]
            donor = c["live"].modules["%s_03_STANDARD" % donor_stem]["attributes"]
            assert standard["Price"] == 0 and standard["PurchasePrice"] == 0
            assert standard["UpgradePointCapacity"] == 2 and standard["MaxPointsPerPath"] == 3
            assert standard["Point1CostGuide"] == donor["Point1CostGuide"] and standard["Point2CostGuide"] == donor["Point2CostGuide"]
            assert "Point3CostGuide" not in standard
            assert standard["VariantOrder"] == 10 and standard["NeonPrice"] == 5000 and standard["VariantName"] == "Standard"
            for variant, order, neon in (("LIGHTWEIGHT", 20, 6500), ("POWER", 30, 8000)):
                attributes = disk["modules"]["%s_%02d_%s" % (stem, n, variant)]["attributes"]
                assert attributes["Price"] == variant_price and attributes["PurchasePrice"] == variant_price
                assert attributes["Price"] * 100 == cockpit["price"] * 12
                assert attributes["UpgradePointCapacity"] == 6 and "MaxPointsPerPath" not in attributes
                expected = [int(math.floor(variant_price * pct / 100 / 100 + 0.5)) * 100 for pct in (8, 10, 12, 15, 18, 22)]
                assert [attributes["Point%dCostGuide" % i] for i in range(1, 7)] == expected
                assert attributes["VariantOrder"] == order and attributes["NeonPrice"] == neon
                assert attributes["VariantName"] == attributes["Tier"] == variant.capitalize()
        for slot in B.BODY_ORDER:
            attributes = disk["modules"]["%s_%02d" % (B.BODY_SLOTS[slot][0], n)]["attributes"]
            donor = c["live"].modules[B.BODY_SLOTS[slot][1]]["attributes"]
            assert attributes["Price"] == body_prices[n - 1] and attributes["NeonPrice"] == body_neon[n - 1]
            assert "PurchasePrice" not in attributes and "SourceCockpitId" not in attributes
            assert attributes["UpgradePointCapacity"] == 6 and attributes["MaxPointsPerPath"] == 3
            for i in range(1, 7):
                assert attributes["Point%dCostGuide" % i] == donor["Point%dCostGuide" % i]
    # Mesh body trims (D7): base price x 2 (GT) and x 3.5 (EVO), rounded to 100. NeonPrice as the base part.
    expected_trim_prices = {1: {"GT": 16000, "EVO": 28000}, 2: {"GT": 22000, "EVO": 38500}, 3: {"GT": 28000, "EVO": 49000},
                            4: {"GT": 36000, "EVO": 63000}, 5: {"GT": 46000, "EVO": 80500}, 6: {"GT": 60000, "EVO": 105000}}
    for module_id, (base_id, trim) in trim_module_ids().items():
        attributes, base_attributes = disk["modules"][module_id]["attributes"], disk["modules"][base_id]["attributes"]
        assert attributes["Price"] == int(math.floor(base_attributes["Price"] * BODY_TRIM_FACTOR[trim] / 100 + 0.5)) * 100
        assert attributes["Price"] == expected_trim_prices[int(base_id[-2:])][trim], module_id
        assert attributes["NeonPrice"] == base_attributes["NeonPrice"]
        assert "PurchasePrice" not in attributes and "SourceCockpitId" not in attributes and "VariantName" not in attributes
    # The 8/10/12/15/18/22 rule reproduces every live Piercer variant module.
    for module_id, module in c["live"].modules.items():
        attributes = module["attributes"]
        if attributes.get("VariantName") in ("Lightweight", "Power"):
            expected = [int(math.floor(attributes["Price"] * pct / 100 / 100 + 0.5)) * 100 for pct in (8, 10, 12, 15, 18, 22)]
            assert [attributes["Point%dCostGuide" % i] for i in range(1, 7)] == expected, module_id


def test_stock_pi_hits_target_inside_tier_band():
    c = ctx()
    bands = c["live"].config.tier_bands
    order = "EDCBAS"
    for cockpit in B.COCKPITS:
        entry = c["disk"]["cockpits"][cockpit["id"]]
        result = c["live"].calculator.calculate(R.sum_components(entry["attributes"], stock_components(c, cockpit["id"])))
        assert result["Overall"]["PerformanceIndex"] == entry["stockPI"]
        assert result["Overall"]["Tier"] == entry["stockTier"] == cockpit["tier"]
        assert abs(entry["stockPI"] - cockpit["target"]) <= 3, (cockpit["id"], entry["stockPI"])
        low = bands[cockpit["tier"]]
        index = order.index(cockpit["tier"])
        high = bands[order[index + 1]] if index < 5 else 1000
        assert low <= entry["stockPI"] < high
        for name in R.HEADLINE_ORDER:
            assert abs(entry["headlines"][name] - result["Headline"][name]) < 0.006


def test_stock_build_sums_to_the_target_total_and_follows_the_live_shares():
    c = ctx()
    for cockpit in B.COCKPITS:
        totals = c["design"][cockpit["id"]]["totals"]
        raw = R.sum_components(c["disk"]["cockpits"][cockpit["id"]]["attributes"], stock_components(c, cockpit["id"]))
        for name in R.RAW_ORDER:
            assert abs(raw[name] - totals[name]) < 1e-6, (cockpit["id"], name, raw[name], totals[name])
        for slot in B.CORE_ORDER:
            attributes = c["disk"]["modules"]["%s_%02d_STANDARD" % (B.CORE_SLOTS[slot][0], cockpit["n"])]["attributes"]
            for name in R.RAW_ORDER:
                assert abs(attributes[name] - totals[name] * c["live"].shares[name][slot]) <= 0.5 * 10 ** -B.MODULE_DECIMALS + 1e-9
    shares = c["live"].shares
    assert shares["TopSpeed"] == {"Cockpit": 0.35, "Engine1": 0.325, "Engine2": 0.325, "Stabilisers": 0.0, "Boost": 0.0}
    assert shares["Weight"] == {"Cockpit": 0.7, "Engine1": 0.1, "Engine2": 0.1, "Stabilisers": 0.05, "Boost": 0.05}
    assert shares["Drag"] == {"Cockpit": 0.7, "Engine1": 0.0, "Engine2": 0.0, "Stabilisers": 0.15, "Boost": 0.15}
    assert shares["LateralGrip"]["Stabilisers"] == 0.65 and shares["BoostForce"]["Boost"] == 0.65


def test_no_negative_cockpit_value_and_technical_minimums():
    c = ctx()
    assert c["reductions"] == [], "the floor rule lowered a designed body stat: " + repr(c["reductions"])
    curves = c["live"].config.curves
    for cockpit in B.COCKPITS:
        attributes = c["disk"]["cockpits"][cockpit["id"]]["attributes"]
        totals = c["design"][cockpit["id"]]["totals"]
        for name in R.RAW_ORDER:
            assert attributes[name] > 0, (cockpit["id"], name, attributes[name])
            assert totals[name] >= curves[name]["TechnicalMinimum"], (cockpit["id"], name)
            if name not in R.LOWER_IS_BETTER:
                assert attributes[name] >= curves[name]["TechnicalMinimum"], (cockpit["id"], name)
    # The same floor reading holds on live Piercer: the lower-is-better minimum applies to the total.
    assert c["live"].cockpits["bruiser_06"]["attributes"]["Weight"] < curves["Weight"]["TechnicalMinimum"]


def test_character_against_the_piercer_of_the_same_tier():
    c = ctx()
    for cockpit in B.COCKPITS:
        totals = c["design"][cockpit["id"]]["totals"]
        piercer = c["live"].profiles[cockpit["piercer"]]
        assert totals["TopSpeed"] > piercer["TopSpeed"] and totals["SteeringResponse"] > piercer["SteeringResponse"]
        for name in ("HoverStability", "DriftControl", "BoostDuration"):
            assert totals[name] < piercer[name], (cockpit["id"], name)
        if piercer["Weight"] > 60:
            assert totals["Weight"] < piercer["Weight"]
        else:
            assert totals["Weight"] == piercer["Weight"] == 60  # technical minimum
    # A ladder: no stat is worse on a higher tier. Higher-is-better stats rise strictly;
    # lower-is-better stats fall or hold (no allowance).
    for lower, upper in zip(B.COCKPITS, B.COCKPITS[1:]):
        a, b = c["design"][lower["id"]]["totals"], c["design"][upper["id"]]["totals"]
        for name in R.RAW_ORDER:
            if name in R.LOWER_IS_BETTER:
                assert b[name] <= a[name], (upper["id"], name, b[name], a[name])
            else:
                assert b[name] > a[name], (upper["id"], name)


def test_variants_use_the_live_multipliers():
    c = ctx()
    policy = c["live"].config.variant_policy
    assert (policy["LightweightEngineHigherMultiplier"], policy["LightweightStabilisersHigherMultiplier"],
            policy["LightweightBoostHigherMultiplier"], policy["LightweightLowerBetterMultiplier"],
            policy["PowerHigherMultiplier"], policy["PowerLowerBetterMultiplier"]) == (1.08, 1.08, 1.03, 0.88, 1.1, 1.04)
    for cockpit in B.COCKPITS:
        for slot in B.CORE_ORDER:
            stem = B.CORE_SLOTS[slot][0]
            standard = c["disk"]["modules"]["%s_%02d_STANDARD" % (stem, cockpit["n"])]["attributes"]
            for variant in ("LIGHTWEIGHT", "POWER"):
                attributes = c["disk"]["modules"]["%s_%02d_%s" % (stem, cockpit["n"], variant)]["attributes"]
                for name in R.RAW_ORDER:
                    expected = standard[name] * c["live"].variant_multipliers[(slot, variant)][name]
                    assert abs(attributes[name] - expected) <= 5e-7 + 1e-12, (attributes["ModuleId"], name)
    # Engine1 and Engine2 Standard carry the same numbers, as on Piercer.
    for cockpit in B.COCKPITS:
        one = c["disk"]["modules"]["MODULE_ENGINE_EXOTIC_%02d_STANDARD" % cockpit["n"]]["attributes"]
        two = c["disk"]["modules"]["MODULE_ENGINE_B_EXOTIC_%02d_STANDARD" % cockpit["n"]]["attributes"]
        assert all(one[name] == two[name] for name in R.RAW_ORDER)


def test_every_module_has_its_donor_attribute_set():
    c = ctx()
    extra = {"CardTitle", "RatingReferenceCockpitId"}
    for cockpit in B.COCKPITS:
        for slot in B.CORE_ORDER:
            stem, donor_stem, folder, module_type, module_slot, position, rear = B.CORE_SLOTS[slot]
            for variant in B.VARIANTS:
                attributes = c["disk"]["modules"]["%s_%02d_%s" % (stem, cockpit["n"], variant)]["attributes"]
                donor = c["live"].modules["%s_03_%s" % (donor_stem, variant)]["attributes"]
                assert set(attributes) == set(donor) | extra, (attributes["ModuleId"], set(attributes) ^ set(donor))
                for name, value in donor.items():
                    assert kind(attributes[name]) == kind(value), (attributes["ModuleId"], name)
                assert attributes["SourceCockpitId"] == cockpit["id"]
                assert attributes["ModuleFolder"] == folder and attributes["ModuleType"] == module_type
                assert attributes["ModuleSlot"] == module_slot
                if slot == "Engine1":
                    assert attributes["EnginePosition"] == "Front" and attributes["RearEngine"] is False
                if slot == "Engine2":
                    assert attributes["EnginePosition"] == "Rear" and attributes["RearEngine"] is True
                assert attributes["V2PublishedModuleId"] == attributes["ModuleId"] and attributes["V2Materialised"] is True
                for name in ("Acceleration", "Boost", "Braking", "Drift", "Handling", "Power"):
                    assert attributes[name] == donor[name], (attributes["ModuleId"], name)
        for slot in B.BODY_ORDER:
            stem, donor_id, folder = B.BODY_SLOTS[slot]
            attributes = c["disk"]["modules"]["%s_%02d" % (stem, cockpit["n"])]["attributes"]
            donor = c["live"].modules[donor_id]["attributes"]
            assert set(attributes) == set(donor) | extra, (attributes["ModuleId"], set(attributes) ^ set(donor))
            for name, value in donor.items():
                assert kind(attributes[name]) == kind(value), (attributes["ModuleId"], name)
            assert attributes["ModuleFolder"] == folder and attributes["ModuleType"] == slot and attributes["ModuleSlot"] == slot
            for name in R.RAW_ORDER:
                assert attributes["PerformanceDelta_" + name] == attributes[name], (attributes["ModuleId"], name)
            assert attributes["V2Materialised"] is True and attributes["Boost"] == 0 and attributes["Power"] == 0
    # The legacy headline rule reproduces the four live LVL1 donors.
    for donor_id in ("MODULE_FRONTBUMPER_LVL1", "MODULE_REARBUMPER_LVL1", "MODULE_REARSPOILER_LVL1", "MODULE_SIDEPODS_LVL1"):
        donor = c["live"].modules[donor_id]["attributes"]
        for name, value in B.legacy_body_headlines(donor).items():
            assert donor[name] == value, (donor_id, name)
    # Mesh body trims (D7): every attribute of the base part and the same upgrade path source, except the id,
    # the names and the Price. So the attribute set is the donor set too, and no VariantName is added.
    for module_id, (base_id, trim) in trim_module_ids().items():
        entry, base_entry = c["disk"]["modules"][module_id], c["disk"]["modules"][base_id]
        attributes, base_attributes = entry["attributes"], base_entry["attributes"]
        assert set(attributes) == set(base_attributes), module_id
        differing = {name for name in attributes if attributes[name] != base_attributes[name]}
        assert differing == {"ModuleId", "DisplayName", "ModuleName", "CardTitle", "Price"}, (module_id, differing)
        assert attributes["DisplayName"] == base_attributes["DisplayName"] + " " + trim
        assert {key: value for key, value in entry.items() if key != "attributes"} == {key: value for key, value in base_entry.items() if key != "attributes"}
        assert R.apply_to_module_raw(attributes) == R.apply_to_module_raw(base_attributes)
        assert B.paths_for(c["live"], entry) == B.paths_for(c["live"], base_entry)
    for module_id, entry in c["disk"]["modules"].items():
        attributes = entry["attributes"]
        assert attributes["CardTitle"] == attributes["DisplayName"] == attributes["ModuleName"]
        assert attributes["RatingReferenceCockpitId"] == "exotic_03"
        assert attributes["TemplateType"] == "Module" and attributes["RetiredFromCatalog"] is False


def test_display_names_come_from_the_spec():
    c = ctx()
    spec = c["live"].spec
    for cockpit in B.COCKPITS:
        kit = spec["kits"][cockpit["spec_kit"]]["modules"]
        for slot in B.CORE_ORDER + B.BODY_ORDER:
            name = spec["modules"][slot][kit[slot]]["name"]
            if slot in B.CORE_SLOTS:
                ids = ["%s_%02d_%s" % (B.CORE_SLOTS[slot][0], cockpit["n"], variant) for variant in B.VARIANTS]
            else:
                ids = ["%s_%02d" % (B.BODY_SLOTS[slot][0], cockpit["n"])]
            for module_id in ids:
                assert c["disk"]["modules"][module_id]["attributes"]["DisplayName"] == name
                for trim in BODY_TRIM_FACTOR:
                    if module_id + "_" + trim in trim_module_ids():
                        assert c["disk"]["modules"][module_id + "_" + trim]["attributes"]["DisplayName"] == name + " " + trim


def test_cockpit_attribute_set_and_defaults():
    c = ctx()
    new_defaults = {"DefaultFrontBodyModuleId", "DefaultRearBodyModuleId", "DefaultSidePodsModuleId",
                    "DefaultFrontBumperModuleId", "DefaultRearBumperModuleId", "DefaultRearSpoilerModuleId"}
    for cockpit in B.COCKPITS:
        attributes = c["disk"]["cockpits"][cockpit["id"]]["attributes"]
        donor = c["live"].cockpits[cockpit["piercer"]]["attributes"]
        colours = {name for name, value in donor.items() if isinstance(value, dict)}
        assert colours == set(B.COCKPIT_COLOUR_ATTRIBUTES)
        # A mesh cockpit keeps all ten slots but declares no default for three of them (D8).
        empty = MESH_EMPTY_DEFAULTS if cockpit["n"] in MESH_KITS else set()
        assert set(attributes) == (set(donor) - colours) | (new_defaults - empty)
        for name, value in donor.items():
            if name not in colours:
                assert kind(attributes[name]) == kind(value), (cockpit["id"], name)
        n = cockpit["n"]
        expected = {
            "DefaultEngineModuleId": "MODULE_ENGINE_EXOTIC_%02d_STANDARD" % n,
            "DefaultFrontEngineModuleId": "MODULE_ENGINE_EXOTIC_%02d_STANDARD" % n,
            "DefaultEngineBModuleId": "MODULE_ENGINE_B_EXOTIC_%02d_STANDARD" % n,
            "DefaultRearEngineModuleId": "MODULE_ENGINE_B_EXOTIC_%02d_STANDARD" % n,
            "DefaultStabiliserModuleId": "MODULE_STABILISER_EXOTIC_%02d_STANDARD" % n,
            "DefaultStabilisersModuleId": "MODULE_STABILISER_EXOTIC_%02d_STANDARD" % n,
            "DefaultBoostModuleId": "MODULE_BOOST_EXOTIC_%02d_STANDARD" % n,
            "DefaultFrontBodyModuleId": "MODULE_FRONTBODY_EXOTIC_%02d" % n,
            "DefaultRearBodyModuleId": "MODULE_REARBODY_EXOTIC_%02d" % n,
            "DefaultSidePodsModuleId": "MODULE_SIDEPODS_EXOTIC_%02d" % n,
            "DefaultFrontBumperModuleId": "MODULE_FRONTBUMPER_EXOTIC_%02d" % n,
            "DefaultRearBumperModuleId": "MODULE_REARBUMPER_EXOTIC_%02d" % n,
            "DefaultRearSpoilerModuleId": "MODULE_REARSPOILER_EXOTIC_%02d" % n,
        }
        for name, module_id in expected.items():
            assert module_id in c["disk"]["modules"]
            if name in empty:
                assert name not in attributes  # the module still exists (primitive, as before); it is just not a default
            else:
                assert attributes[name] == module_id
        assert len([name for name in attributes if name.startswith("Default") and name.endswith("ModuleId")]) == 13 - len(empty)
        for name in ("Acceleration", "Boost", "Braking", "Drift", "Handling", "Power"):
            assert attributes[name] == donor[name]
        assert attributes["V2Materialised"] is True and attributes["TemplateType"] == "Cockpit"


def test_body_modules_are_lvl1_size_and_similar_value():
    c = ctx()
    for slot in B.BODY_ORDER:
        for kit in range(1, 7):
            attributes = c["disk"]["modules"]["%s_%02d" % (B.BODY_SLOTS[slot][0], kit)]["attributes"]
            assert 1 <= attributes["Weight"] <= 3
            for name in R.RAW_ORDER:
                assert abs(attributes[name]) <= 3, (attributes["ModuleId"], name)
                assert attributes[name] * 2 == int(attributes[name] * 2)  # half steps
                if name != "TopSpeed":
                    assert attributes[name] >= 0, (attributes["ModuleId"], name)
            assert attributes["TopSpeed"] >= -1
            for name in ("BoostForce", "BoostDuration", "BoostRecharge", "BoostRechargeDelay", "BoostEfficiency"):
                assert attributes[name] == 0
            # No Drag on any body part: a flat Drag value is not worth the same on every tier
            # (Gull's stock Drag is 0.325 above the technical minimum).
            assert attributes["Drag"] == 0 and attributes["PerformanceDelta_Drag"] == 0, attributes["ModuleId"]
    # Flavours differ inside a slot.
    for slot in B.BODY_ORDER:
        seen = set()
        for kit in range(1, 7):
            attributes = c["disk"]["modules"]["%s_%02d" % (B.BODY_SLOTS[slot][0], kit)]["attributes"]
            seen.add(tuple(attributes[name] for name in R.RAW_ORDER))
        assert len(seen) == 6
    # Similar value on every cockpit: swapping any style into a stock build moves PI very little.
    # The E limit is wider only because one half step of a stat is worth up to 1.3 PI on Spider.
    limit = {"E": 1.0, "D": 0.5, "C": 0.5, "B": 0.5, "A": 0.5, "S": 0.5}
    for slot in B.BODY_ORDER:
        for cockpit in B.COCKPITS:
            values = [c["analysis"]["body"][slot][kit][cockpit["id"]]["UnroundedPerformanceIndex"] for kit in range(1, 7)]
            # A slot that starts empty adds its part on top of the stock total, where Spider's curve is a little
            # steeper: Rear Bumper spreads 1.14 there (shown indices still within 1, checked below).
            extra = 0.2 if cockpit["tier"] == "E" and slot == "RearBumper" and slot not in B.stock_body(cockpit["n"]) else 0.0
            assert max(values) - min(values) <= limit[cockpit["tier"]] + extra, (slot, cockpit["id"], max(values) - min(values))
            shown = [c["analysis"]["body"][slot][kit][cockpit["id"]]["PerformanceIndex"] for kit in range(1, 7)]
            assert max(shown) - min(shown) <= 1, (slot, cockpit["id"], shown)
        for kit in range(1, 7):
            card = c["analysis"]["body"][slot][kit]["exotic_03"]["PerformanceIndex"]
            if slot in B.stock_body(3):
                assert abs(card - 540) <= 1, (slot, kit, card)
            else:  # a slot that starts empty on a mesh cockpit: the part adds to the stock total (D9), inside tier C
                assert 540 <= card <= 550 and c["live"].calculator.tier_for_index(card) == "C", (slot, kit, card)


def test_upgrade_paths():
    c = ctx()
    live = c["live"]
    tier_family = {"exotic_01": 2, "exotic_02": 3, "exotic_03": 1, "exotic_04": 4, "exotic_05": 5, "exotic_06": 6}
    for cockpit in B.COCKPITS:
        assert int(cockpit["piercer"][-2:]) == tier_family[cockpit["id"]]
        assert live.cockpits[cockpit["piercer"]]["attributes"]["TargetTier"] == cockpit["tier"]
        for slot in B.CORE_ORDER:
            stem, donor_stem = B.CORE_SLOTS[slot][0], B.CORE_SLOTS[slot][1]
            for variant in B.VARIANTS:
                entry = c["disk"]["modules"]["%s_%02d_%s" % (stem, cockpit["n"], variant)]
                donor_id = entry["upgradePathDonor"]
                assert donor_id == "%s_%02d_%s" % (donor_stem, tier_family[cockpit["id"]], variant)
                donor = live.modules[donor_id]
                assert len(donor["paths"]) == 3 and donor["attributes"]["RetiredFromCatalog"] is False
                assert donor["attributes"]["VariantName"].upper() == variant
                assert donor["attributes"]["SourceCockpitId"] == cockpit["piercer"]
        for slot in ("SidePods", "FrontBumper", "RearBumper", "RearSpoiler"):
            entry = c["disk"]["modules"]["%s_%02d" % (B.BODY_SLOTS[slot][0], cockpit["n"])]
            assert entry["upgradePathDonor"] == B.BODY_SLOTS[slot][1] and entry["upgradePathDonor"].endswith("_LVL1")
            assert len(live.modules[entry["upgradePathDonor"]]["paths"]) >= 2
            assert live.modules[entry["upgradePathDonor"]]["attributes"]["ModuleType"] == slot
    live_ids = set(live.live_path_ids)
    assert len(live_ids) == 19
    reserved = live_ids | set(B.LEGACY_UPGRADE_IDS)
    new_ids = []
    for slot in ("FrontBody", "RearBody"):
        reference = None
        for n in range(1, 7):
            paths = c["disk"]["modules"]["%s_%02d" % (B.BODY_SLOTS[slot][0], n)]["upgradePaths"]
            assert 2 <= len(paths) <= 3
            if reference is None:
                reference = paths
                new_ids.extend(path["PathId"] for path in paths)
            assert paths == reference  # the same paths on all six parts of the slot
            for path in paths:
                attributes = path["attributes"]
                assert attributes["PathId"] == path["PathId"]
                assert re.match(r"^[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+$", path["PathId"]), path["PathId"]
                assert path["PathId"] not in reserved, path["PathId"]
                assert attributes["MaxPoints"] == 3 and isinstance(attributes["Order"], int)
                assert isinstance(attributes["DisplayName"], str) and attributes["DisplayName"]
                deltas = {key: value for key, value in attributes.items() if key.startswith("Delta")}
                assert deltas and all(key.startswith("DeltaFlat_") and key[10:] in R.RAW_ORDER for key in deltas)
                assert all(1 <= abs(value) <= 4 for value in deltas.values())  # live accessory paths use 1 to 4
                assert "DeltaFlat_Drag" not in attributes  # no Drag on a new path, in either direction
                assert set(attributes) == {"PathId", "DisplayName", "MaxPoints", "Order"} | set(deltas)
    assert len(new_ids) == len(set(new_ids)) == 6
    assert sorted(new_ids) == ["DeckCooling", "LightweightDeck", "LightweightNose", "NoseCanards", "SlipstreamNose", "TailStrakes"]
    # A point on a new path is never worthless and never a loss, on any stock cockpit
    # (Hyper and Gull sit on the Weight minimum, so a weight path needs its second stat).
    worth = c["analysis"]["path_worth"]
    for slot in ("FrontBody", "RearBody"):
        assert sorted(worth[slot]) == sorted(path["PathId"] for path in c["disk"]["modules"]["%s_01" % B.BODY_SLOTS[slot][0]]["upgradePaths"])
        for path_id, entry in worth[slot].items():
            assert entry["new"] and entry["cost"] > 0
            for cockpit in B.COCKPITS:
                assert entry["gain"][cockpit["id"]] >= 0.05, (path_id, cockpit["id"], entry["gain"][cockpit["id"]])
    for path_id in ("LightweightNose", "LightweightDeck"):
        slot = "FrontBody" if path_id.endswith("Nose") else "RearBody"
        deltas = worth[slot][path_id]["deltas"]
        assert deltas["Weight"] == -3 and len(deltas) == 2 and all(value > 0 for name, value in deltas.items() if name != "Weight")


def test_body_parts_cannot_shift_a_tier():
    c = ctx()
    for cockpit in B.COCKPITS:
        mix = c["analysis"]["mix"][cockpit["id"]]
        stock = c["disk"]["cockpits"][cockpit["id"]]["stockPI"]
        for kit in range(1, 7):
            assert mix["whole"][kit]["Tier"] == cockpit["tier"]
            assert abs(mix["whole"][kit]["PerformanceIndex"] - stock) <= 1, (cockpit["id"], kit)
        for key in ("best", "worst"):
            index = R._luau_round(R._rounded(mix[key][0], 2))
            assert c["live"].calculator.tier_for_index(index) == cockpit["tier"], (cockpit["id"], key, index)
            assert abs(index - stock) <= 3, (cockpit["id"], key, index)
            # The mix covers the slots the stock build fills: six, or three on a mesh cockpit.
            assert len(mix[key][1]) == (3 if cockpit["n"] in MESH_KITS else 6)
        # Every body slot filled with the own kit. That is the stock build, except on a mesh cockpit, where the three
        # slots that start empty add stats on top of the target total (D9): the tier must still hold.
        full = c["analysis"]["exotic"][cockpit["id"]]["FULL_BODY"]["Overall"]
        assert full["Tier"] == cockpit["tier"], (cockpit["id"], full["PerformanceIndex"])
        if cockpit["n"] in MESH_KITS:
            # (Equal on exotic_06 only: +0.2 unrounded, so the shown index does not move.)
            assert stock < full["PerformanceIndex"] or (cockpit["id"] == "exotic_06" and stock == full["PerformanceIndex"]), (
                cockpit["id"], full["PerformanceIndex"])
        else:
            assert full["PerformanceIndex"] == stock, (cockpit["id"], full["PerformanceIndex"])


def test_no_build_reaches_a_higher_tier_than_piercer():
    """ANY_MAX is the highest build FOUND by a search over every own-family variant, every kit's
    body part (or none in an optional slot) and every upgrade allocation. ANY_CEILING is a bound no
    such build can beat. The tier claim is tested on the bound, so it does not rest on the search."""
    c = ctx()
    order = "EDCBAS"
    for cockpit in B.COCKPITS:
        exotic = c["analysis"]["exotic"][cockpit["id"]]
        piercer = c["analysis"]["piercer"][cockpit["piercer"]]
        found = exotic["ANY_MAX"][0]["Overall"]
        ceiling = exotic["ANY_CEILING"]["Overall"]
        piercer_top = piercer["ANY_MAX"][0]["Overall"]
        assert order.index(found["Tier"]) <= order.index(piercer_top["Tier"]), (cockpit["id"], found["Tier"])
        assert order.index(ceiling["Tier"]) <= order.index(piercer_top["Tier"]), (cockpit["id"], ceiling["Tier"])
        for key in ("STANDARD_MAX", "LIGHTWEIGHT_MAX", "POWER_MAX"):
            assert exotic[key][0]["Overall"]["UnroundedPerformanceIndex"] <= found["UnroundedPerformanceIndex"] + 1e-9, (cockpit["id"], key)
        assert found["UnroundedPerformanceIndex"] <= ceiling["UnroundedPerformanceIndex"]
        for key in ("LIGHTWEIGHT_MAX", "POWER_MAX"):
            assert piercer[key][0]["Overall"]["UnroundedPerformanceIndex"] <= piercer_top["UnroundedPerformanceIndex"] + 1e-9
        assert piercer_top["UnroundedPerformanceIndex"] <= piercer["ANY_CEILING"]["Overall"]["UnroundedPerformanceIndex"]
        assert exotic["LIGHTWEIGHT"]["Overall"]["Tier"] == cockpit["tier"]
        assert exotic["POWER"]["Overall"]["Tier"] == cockpit["tier"]
        assert exotic["POWER"]["Overall"]["PerformanceIndex"] > exotic["STANDARD"]["Overall"]["PerformanceIndex"]
    hyper = c["analysis"]["exotic"]["exotic_05"]["ANY_CEILING"]["Overall"]
    assert hyper["Tier"] == "A" and hyper["PerformanceIndex"] < c["live"].config.tier_bands["S"]


def test_ascii_and_plain_numbers():
    c = ctx()
    for path in (B.BALANCE_PATH, B.REPORT_PATH, HERE / "rating.py", HERE / "build_balance.py", Path(__file__)):
        data = path.read_bytes()
        assert all(byte < 128 for byte in data), "non-ASCII byte in " + path.name
        assert b"\r" not in data, "CR line ending in " + path.name

    def walk(value, trail):
        if isinstance(value, dict):
            for key, item in value.items():
                assert isinstance(key, str) and key.isascii()
                walk(item, trail + [key])
        elif isinstance(value, list):
            for item in value:
                walk(item, trail)
        elif isinstance(value, bool) or value is None:
            assert value is not None, trail
        elif isinstance(value, (int, float)):
            assert math.isfinite(value), trail
            text = repr(value)
            assert "e" not in text.lower() and text not in ("-0", "-0.0"), (trail, text)
            assert value == 0 or 1e-4 <= abs(value) < 1e15, (trail, value)
            assert round(value, 6) == value, (trail, value)
        else:
            assert isinstance(value, str) and value.isascii(), trail

    walk(c["disk"], [])
    assert b"-0," not in c["disk_text"] and b"-0\n" not in c["disk_text"] and b"-0.0" not in c["disk_text"]


TESTS = [value for name, value in sorted(globals().items()) if name.startswith("test_") and callable(value)]


def main():
    failed = 0
    for test in TESTS:
        try:
            test()
            print("ok    " + test.__name__)
        except Exception:  # noqa: BLE001 - report every failure
            failed += 1
            print("FAIL  " + test.__name__)
            traceback.print_exc()
    print("%d tests, %d failed" % (len(TESTS), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
