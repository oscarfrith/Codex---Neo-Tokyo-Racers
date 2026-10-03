"""Generate balance.json and report.md for the Exotic category. Deterministic.

    py -3 scripts/exotic_category/balance/build_balance.py

Inputs (read-only):
  scripts/exotic_category/INTERFACE.md            ids, prices, targets (copied into the tables below)
  roblox/captures/exotic-before/capture.json      live Piercer attributes, upgrade paths, rating config
  scripts/vehicle_blockouts/specs/exotic.json     kit membership and module display names

Method (see report.md for the numbers):
  1. Target stock totals (17 raw stats) per Exotic cockpit: the Piercer stock profile of the same
     tier (Config.Vehicles.Performance.BalancedStockProfiles) times the Exotic character, then one
     scale (higher-is-better stats * s, lower-is-better stats / s, never under the technical
     minimum and never worse than the tier below) solved so the stock PI equals the target.
  2. Totals are split with the live ComponentAllocationPolicy shares. Lightweight and Power use
     the live VariantPolicy multipliers.
  3. The cockpit's own raw values are its share minus the flat stats of its default body
     modules, so cockpit + four Standard + default body = target total. Six defaults, except the
     mesh cockpits exotic_02 and exotic_05 (mesh/INTEGRATION.md D8, D9): three defaults (Nose,
     Engine Deck, Wing); Side Pods, Splitter and Diffuser start empty and the cockpit absorbs them.
"""
from __future__ import annotations

import itertools
import json
import math
import random
from pathlib import Path

import rating as R

HERE = Path(__file__).resolve().parent
REPO = R.REPO
SPEC_PATH = REPO / "scripts" / "vehicle_blockouts" / "specs" / "exotic.json"
BALANCE_PATH = HERE / "balance.json"
REPORT_PATH = HERE / "report.md"

# ---------------------------------------------------------------------------
# INTERFACE.md tables
# ---------------------------------------------------------------------------

CATEGORY_ID = "exotic"
RATING_REFERENCE_COCKPIT_ID = "exotic_03"

# N, CockpitId, model, DisplayName, spec cockpit, spec kit, kit name, tier, price, target PI,
# Piercer cockpit of the same tier.
COCKPITS = [
    (1, "exotic_01", "COCKPIT_EXOTIC_01", "Spider", "spider", "track", "Track", "E", 50000, 220, "bruiser_02"),
    (2, "exotic_02", "COCKPIT_EXOTIC_02", "Curve", "curve", "analogue", "Analogue", "D", 150000, 390, "bruiser_03"),
    (3, "exotic_03", "COCKPIT_EXOTIC_03", "Wedge", "wedge", "wedge", "Wedge", "C", 440000, 540, "bruiser_01"),
    (4, "exotic_04", "COCKPIT_EXOTIC_04", "Longtail", "longtail", "longtail", "Longtail", "B", 1400000, 675, "bruiser_04"),
    (5, "exotic_05", "COCKPIT_EXOTIC_05", "Hyper", "hyper", "hyper", "Hyper", "A", 4400000, 800, "bruiser_05"),
    (6, "exotic_06", "COCKPIT_EXOTIC_06", "Gull", "gull", "concept", "Concept", "S", 12500000, 938, "bruiser_06"),
]
COCKPIT_FIELDS = ["n", "id", "model", "name", "spec_cockpit", "spec_kit", "kit_name", "tier", "price", "target", "piercer"]
COCKPITS = [dict(zip(COCKPIT_FIELDS, row)) for row in COCKPITS]

VARIANTS = ["STANDARD", "LIGHTWEIGHT", "POWER"]

# SlotId -> (id stem, donor stem, ModuleFolder, ModuleType, ModuleSlot, EnginePosition, RearEngine)
CORE_SLOTS = {
    "Engine1": ("MODULE_ENGINE_EXOTIC", "MODULE_ENGINE_BRUISER", "Engines", "Engine", "Engine", "Front", False),
    "Engine2": ("MODULE_ENGINE_B_EXOTIC", "MODULE_ENGINE_B_BRUISER", "Engines_B", "Engine", "Engine", "Rear", True),
    "Stabilisers": ("MODULE_STABILISER_EXOTIC", "MODULE_STABILISER_BRUISER", "Stabilisers", "Stabilisers", "Stabilisers", None, None),
    "Boost": ("MODULE_BOOST_EXOTIC", "MODULE_BOOST_BRUISER", "Boost", "Boost", "Boost", None, None),
}
CORE_ORDER = ["Engine1", "Engine2", "Stabilisers", "Boost"]

# SlotId -> (id stem, live accessory donor, ModuleFolder)
BODY_SLOTS = {
    "FrontBody": ("MODULE_FRONTBODY_EXOTIC", "MODULE_FRONTBUMPER_LVL1", "FrontBodies"),
    "RearBody": ("MODULE_REARBODY_EXOTIC", "MODULE_REARBUMPER_LVL1", "RearBodies"),
    "SidePods": ("MODULE_SIDEPODS_EXOTIC", "MODULE_SIDEPODS_LVL1", "SidePods"),
    "FrontBumper": ("MODULE_FRONTBUMPER_EXOTIC", "MODULE_FRONTBUMPER_LVL1", "FrontBumpers"),
    "RearBumper": ("MODULE_REARBUMPER_EXOTIC", "MODULE_REARBUMPER_LVL1", "RearBumpers"),
    "RearSpoiler": ("MODULE_REARSPOILER_EXOTIC", "MODULE_REARSPOILER_LVL1", "RearSpoilers"),
}
BODY_ORDER = ["FrontBody", "RearBody", "SidePods", "FrontBumper", "RearBumper", "RearSpoiler"]
RAIL_LABEL = {"FrontBody": "Nose", "RearBody": "Engine Deck", "SidePods": "Side Pods", "FrontBumper": "Splitter",
              "RearBumper": "Diffuser", "RearSpoiler": "Wing", "Engine1": "Main Turbine", "Engine2": "Side Engines",
              "Stabilisers": "Stabilisers", "Boost": "Afterburner"}

BODY_PRICE_BY_KIT = [8000, 11000, 14000, 18000, 23000, 30000]
BODY_NEON_PRICE_BY_KIT = [6500, 7000, 7500, 8000, 8500, 9500]
CORE_NEON_PRICE = {"STANDARD": 5000, "LIGHTWEIGHT": 6500, "POWER": 8000}
VARIANT_ORDER = {"STANDARD": 10, "LIGHTWEIGHT": 20, "POWER": 30}
VARIANT_NAME = {"STANDARD": "Standard", "LIGHTWEIGHT": "Lightweight", "POWER": "Power"}
VARIANT_POINT_PERCENT = [8, 10, 12, 15, 18, 22]

LEGACY_DEFAULTS = {
    "DefaultEngineModuleId": "Engine1", "DefaultFrontEngineModuleId": "Engine1",
    "DefaultEngineBModuleId": "Engine2", "DefaultRearEngineModuleId": "Engine2",
    "DefaultStabiliserModuleId": "Stabilisers", "DefaultStabilisersModuleId": "Stabilisers",
    "DefaultBoostModuleId": "Boost",
}
NEW_DEFAULTS = {"Default%sModuleId" % slot: slot for slot in BODY_ORDER}

# Mesh kits (scripts/exotic_category/mesh/INTEGRATION.md D6 to D9). Written out here on purpose, as the
# INTERFACE.md tables above are: test_balance.py compares the ids with stage_b/data/mesh.json.
MESH_KITS = (2, 5)
# The stock body parts of a mesh cockpit. Its other three body slots declare no default and start empty.
MESH_STOCK_BODY = ["FrontBody", "RearBody", "RearSpoiler"]
# Extra ModuleIds per mesh kit and stock body slot: <base id>_<TRIM>. Same stats and upgrade paths as the
# base part; name = base name + " " + trim; Price = base price * percent / 100, rounded to 100.
BODY_TRIMS = [("GT", 200), ("EVO", 350)]


def stock_body(n):
    """Body slots that carry a default module on cockpit n, in BODY_ORDER order."""
    return [slot for slot in BODY_ORDER if n not in MESH_KITS or slot in MESH_STOCK_BODY]

# ---------------------------------------------------------------------------
# Balance design
# ---------------------------------------------------------------------------

# Exotic character against the Piercer of the same tier (INTERFACE.md "Balance data").
# Applied to the Piercer stock profile before the scale is solved.
CHARACTER = {
    "TopSpeed": 1.12,          # up: the class headline
    "SteeringResponse": 1.15,  # up: sharp turn-in
    "Weight": 0.90,            # lighter
    "HoverStability": 0.85,    # down: nervous near the limit
    "DriftControl": 0.85,      # down: hard to hold a slide
    "BoostDuration": 0.80,     # down: short bursts
}

# Decimal places kept on the stock totals.
TOTAL_DECIMALS = {name: 2 for name in R.RAW_ORDER}
TOTAL_DECIMALS.update({"BoostDuration": 3, "BoostRecharge": 3, "BoostRechargeDelay": 3, "Drag": 3})
MODULE_DECIMALS = 4
VALUE_DECIMALS = 6

# Body modules: flat raw stats at Piercer accessory LVL1 size (live LVL1: 1 or 2 per stat, Weight 2).
# Keyed by slot, then kit number 1..6. Flavour follows the part.
#
# Rule: every style in a slot is worth about the same on EVERY cockpit, so the price steps are
# cosmetic prestige. test_balance.py holds the PI spread between the six styles of a slot under
# 1.0 on the E tier cockpit and under 0.5 on the others (report.md section 6).
#
# No body part carries Drag, in either direction. A flat Drag value cannot be tier-neutral: the
# S tier stock Drag total is 1.325 against a technical minimum of 1, so +1 Drag costs Gull 2.9 PI
# and -0.5 Drag gains it 1.5 PI, while the same values are worth 0.3 PI or less on every other
# cockpit. The live LVL1 accessories carry no Drag either. A draggy shape is written as a small
# TopSpeed penalty and a slippery shape as TopSpeed.
#
# The mix of stats matters as much as the size. EngineOutput and BrakingForce are worth relatively
# more on fast cockpits; HoverStability, DriftControl and Downforce relatively more on slow ones.
# Each part balances the two groups so its value holds from E to S. Kit 1 feeds the E tier
# cockpit, so its stats also stay under 80 percent of that cockpit's share.
BODY_STATS = {
    "FrontBody": {
        1: ("Blunt Nose: big intake and dive planes. Grip and braking; the blunt face costs a little top speed.",
            {"TopSpeed": -0.5, "EngineOutput": 0.5, "SteeringResponse": 1, "HoverStability": 0.5, "BrakingForce": 0.5,
             "Downforce": 0.5, "Weight": 2.5}),
        2: ("Droplet Nose: short and round. Calm and direct.",
            {"TopSpeed": 1, "SteeringResponse": 1.5, "HoverStability": 0.5, "Weight": 2}),
        3: ("Shovel Nose: one flat chisel plane. Front downforce.",
            {"TopSpeed": 1, "SteeringResponse": 1, "BrakingForce": 0.5, "Downforce": 1.5, "Weight": 2}),
        4: ("Lowline Nose: long and low. Slippery: the most top speed.",
            {"TopSpeed": 2.5, "SteeringResponse": 1, "Weight": 2}),
        5: ("Keel Nose: raised keel with air channels. Most front downforce.",
            {"LateralGrip": 0.5, "SteeringResponse": 1.5, "Downforce": 2, "Weight": 2}),
        6: ("Visor Nose: flat low platform. Sharpest turn-in.",
            {"TopSpeed": 1, "SteeringResponse": 2, "Weight": 2}),
    },
    "RearBody": {
        1: ("Frame Tail: bare tube frame, engines in the open air. More output and a loose tail, less top speed.",
            {"TopSpeed": -1, "EngineOutput": 1, "LateralGrip": 0.5, "DriftControl": 1, "Downforce": 0.5, "Weight": 2}),
        2: ("Boat Tail: narrow drooping tail. Smooth air and top speed. Lightest.",
            {"TopSpeed": 2.5, "HoverStability": 1, "Downforce": 0.5, "Weight": 1.5}),
        3: ("Slab Deck: boxy full-width deck with room for cooling. Most output. Heavy.",
            {"TopSpeed": -0.5, "EngineOutput": 1.5, "HoverStability": 0.5, "Downforce": 0.5, "Weight": 3}),
        4: ("Streamer Tail: long tail booms. The slipperiest: most top speed.",
            {"TopSpeed": 3, "HoverStability": 1, "Weight": 2}),
        5: ("Tunnel Tail: open channels and wake fins. Most rear downforce.",
            {"EngineOutput": 0.5, "LateralGrip": 0.5, "HoverStability": 0.5, "Downforce": 3, "Weight": 2}),
        6: ("Kamm Tail: venturi tunnel and a sheer cut-off. Downforce and calm.",
            {"TopSpeed": 0.5, "EngineOutput": 0.5, "HoverStability": 1, "Downforce": 2.5, "Weight": 2}),
    },
    "SidePods": {
        1: ("Barge Trays: wide floor tray and barge boards. Grip, drift bite and braking.",
            {"EngineOutput": 1, "LateralGrip": 2, "SteeringResponse": 2, "HoverStability": 0.5, "DriftControl": 1.5,
             "DriftGrip": 2, "DriftChargeRate": 2, "BrakingForce": 1.5, "Weight": 2.5}),
        2: ("Torpedo Pods: round pods on pylons. All-round, close to the Piercer pods.",
            {"EngineOutput": 1, "LateralGrip": 2, "SteeringResponse": 2, "HoverStability": 1, "DriftControl": 2,
             "DriftGrip": 2, "DriftChargeRate": 2, "BrakingForce": 0.5, "Weight": 2}),
        3: ("Strake Intakes: straked intake wedge that feeds the side engines. Most output.",
            {"TopSpeed": -0.5, "EngineOutput": 2, "LateralGrip": 2, "SteeringResponse": 1.5, "HoverStability": 1.5,
             "DriftControl": 1, "DriftGrip": 2, "DriftChargeRate": 2, "Downforce": 0.5, "Weight": 2.5}),
        4: ("Full Fairings: smooth full-height fairing. Slippery and steady.",
            {"TopSpeed": 2.5, "EngineOutput": 1, "LateralGrip": 2, "SteeringResponse": 2, "HoverStability": 2,
             "DriftControl": 1, "DriftGrip": 1.5, "DriftChargeRate": 1, "Weight": 2}),
        5: ("Floating Blades: thin blade on struts, air runs behind it. Light, sharp, with downforce.",
            {"EngineOutput": 1, "LateralGrip": 2.5, "SteeringResponse": 2.5, "HoverStability": 1, "DriftControl": 1.5,
             "DriftGrip": 2, "DriftChargeRate": 0.5, "Downforce": 2.5, "Weight": 1.5}),
        6: ("Waisted Cheeks: low cheek intake that pinches to nothing. Light and quick to turn.",
            {"EngineOutput": 1, "LateralGrip": 2, "SteeringResponse": 2.5, "HoverStability": 1, "DriftControl": 2,
             "DriftGrip": 2, "DriftChargeRate": 2, "Weight": 1.5}),
    },
    "FrontBumper": {
        1: ("Plough: deep plough splitter. Bites, and costs a little top speed.",
            {"TopSpeed": -0.5, "LateralGrip": 0.5, "BrakingForce": 1.5, "Downforce": 1, "Weight": 2}),
        2: ("Soft Lip: small rounded lip. Light.",
            {"HoverStability": 0.5, "BrakingForce": 1.5, "Downforce": 0.5, "Weight": 1.5}),
        3: ("Chin Blade: flat chin blade.",
            {"SteeringResponse": 0.5, "BrakingForce": 1.5, "Downforce": 0.5, "Weight": 2}),
        4: ("Long Tongue: long low tongue. Slippery: top speed.",
            {"TopSpeed": 2, "BrakingForce": 1, "Weight": 2}),
        5: ("Keel Planes: stacked keel planes. Most front downforce, less top speed.",
            {"TopSpeed": -1, "SteeringResponse": 1, "BrakingForce": 1, "Downforce": 3, "Weight": 1.5}),
        6: ("Scoop Bib: bib scoop that feeds the brakes and intake.",
            {"EngineOutput": 0.5, "BrakingForce": 1, "Downforce": 1, "Weight": 2}),
    },
    "RearBumper": {
        1: ("Crash Bar: crash structure and rain light. Most braking. Heavy.",
            {"HoverStability": 0.5, "DriftGrip": 0.5, "BrakingForce": 2, "Weight": 3}),
        2: ("Smooth Valance: clean valance. A little of everything.",
            {"TopSpeed": 0.5, "HoverStability": 0.5, "DriftControl": 0.5, "BrakingForce": 1, "Downforce": 1, "Weight": 2}),
        3: ("Strake Diffuser: straked diffuser. Downforce and drift control.",
            {"DriftControl": 1, "BrakingForce": 1, "Downforce": 2.5, "Weight": 2}),
        4: ("Tail Tray: tray under the long tail. Steady, with some top speed.",
            {"TopSpeed": 1, "HoverStability": 1.5, "BrakingForce": 0.5, "Downforce": 0.5, "Weight": 2}),
        5: ("Venturi: deep venturi tunnels. Most rear downforce.",
            {"HoverStability": 0.5, "DriftControl": 1, "BrakingForce": 0.5, "Downforce": 3, "Weight": 2}),
        6: ("Keel Fin: centre keel fin. Stability. Light.",
            {"TopSpeed": 0.5, "HoverStability": 1.5, "DriftControl": 1, "Weight": 1.5}),
    },
    "RearSpoiler": {
        1: ("Twin Element: big two-element wing. Downforce, grip and braking, a little less top speed.",
            {"TopSpeed": -1, "LateralGrip": 2, "SteeringResponse": 1.5, "HoverStability": 0.5, "DriftControl": 0.5,
             "DriftGrip": 1, "BrakingForce": 1.5, "Downforce": 1, "Weight": 2.5}),
        2: ("Bridge Wing: low bridge between the buttresses. All-round, close to the Piercer spoiler.",
            {"TopSpeed": 1, "LateralGrip": 2, "SteeringResponse": 2, "HoverStability": 1, "DriftGrip": 1, "Weight": 2}),
        3: ("Poster Wing: tall poster wing. Grip, a little less top speed.",
            {"TopSpeed": -0.5, "LateralGrip": 2.5, "SteeringResponse": 2, "HoverStability": 1, "BrakingForce": 0.5,
             "Downforce": 1, "Weight": 2}),
        4: ("Tail Fins: two outboard fins. Slippery: most top speed.",
            {"TopSpeed": 2.5, "LateralGrip": 1.5, "SteeringResponse": 1.5, "HoverStability": 1, "DriftControl": 0.5,
             "DriftGrip": 0.5, "Weight": 1.5}),
        5: ("Active Blade: active blade that works as an air brake. Most downforce.",
            {"TopSpeed": 1, "LateralGrip": 2.5, "SteeringResponse": 1, "HoverStability": 0.5, "BrakingForce": 0.5,
             "Downforce": 3, "Weight": 2}),
        6: ("Split Winglets: two small winglets. Light and sharp.",
            {"TopSpeed": 1.5, "LateralGrip": 1.5, "SteeringResponse": 2.5, "HoverStability": 1, "DriftControl": 0.5,
             "Weight": 1.5}),
    },
}

# New upgrade paths for the two new slots. PathIds are saved keys (profile V2UpgradePoints).
# Flat deltas at accessory size (live accessory paths use 1 to 4 per point).
# - No new path carries Drag, for the reason given above BODY_STATS (the cloned live accessory
#   paths do, as on Piercer: report.md section 12).
# - The two weight paths carry a second delta. Hyper and Gull sit on the Weight minimum (60), where
#   a Weight cut alone is worth nothing in the rating or on the road. The second delta follows the
#   legacy definitions in VehicleUpgradeDefinitions (Lightweight Internals: Weight and
#   SteeringResponse +1; Lightweight Arms: Weight and DriftGrip +1).
NEW_UPGRADE_PATHS = {
    "FrontBody": [
        ("NoseCanards", "Nose Canards", 1, {"SteeringResponse": 2, "Downforce": 1, "TopSpeed": -1}),
        ("SlipstreamNose", "Slipstream Nose", 2, {"TopSpeed": 2, "Downforce": -1}),
        ("LightweightNose", "Lightweight Nose", 3, {"Weight": -3, "SteeringResponse": 1}),
    ],
    "RearBody": [
        ("DeckCooling", "Deck Cooling", 1, {"EngineOutput": 1, "BoostEfficiency": 2, "Weight": 1}),
        ("TailStrakes", "Tail Strakes", 2, {"HoverStability": 2, "DriftControl": 1, "TopSpeed": -1}),
        ("LightweightDeck", "Lightweight Deck", 3, {"Weight": -3, "DriftGrip": 1}),
    ],
}

# Ids that a new PathId must not reuse: legacy upgrade ids still mapped by
# PerformanceUpgradeRuntime.legacyMap, and the category UPGRADE_* ids.
LEGACY_UPGRADE_IDS = [
    "FuelInjection", "PowerConverter", "LightweightInternals", "TorqueMapping", "VectoringFirmware",
    "DriftCalibration", "ReactiveDampers", "LightweightArms", "HighFlowInjectors", "ExpandedCell",
    "RapidRecharge", "LightweightCell", "Brakes", "Converter", "FuelSystem",
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def num(value, decimals=VALUE_DECIMALS):
    """A JSON-safe number: rounded, no negative zero, whole numbers as int."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return value
    value = round(float(value), decimals)
    if value == 0:
        return 0
    if value == int(value) and abs(value) < 1e15:
        return int(value)
    return value


def half_up(value):
    return math.floor(value + 0.5)


def round_to_100(price, percent):
    """percent of price, rounded to the nearest 100 (integer arithmetic)."""
    return ((price * percent + 5000) // 10000) * 100


def module_id(stem, n, variant=None):
    return "%s_%02d%s" % (stem, n, "_" + variant if variant else "")


class Live:
    """Everything read from the capture and the spec."""

    def __init__(self):
        self.capture = R.Capture()
        self.config = R.LiveConfig(self.capture)
        self.calculator = R.Calculator(self.config)
        self.cockpits = self.capture.cockpits("PIERCER")
        self.modules = self.capture.modules("PIERCER")
        self.profiles = self.capture.stock_profiles()
        with open(SPEC_PATH, encoding="utf-8") as handle:
            self.spec = json.load(handle)
        self.shares = self._shares()
        self.variant_multipliers = self._variant_multipliers()
        self.live_path_ids = sorted({R.path_id(path) for module in self.modules.values() for path in module["paths"]})

    def _shares(self):
        """Component share of each stock total. Read from the policy attributes and checked
        against the six live ComponentAllocation tables (which also give Weight and Drag)."""
        policy = self.config.allocation_policy
        general = policy["CockpitGeneralShare"]
        engine = policy["EngineSharePerSlot"]
        stabiliser = policy["HandlingStabiliserShare"]
        boost = policy["BoostModuleShare"]
        handling = ["LateralGrip", "SteeringResponse", "HoverStability", "DriftControl", "DriftGrip",
                    "DriftChargeRate", "BrakingForce", "Downforce"]
        boost_stats = ["BoostForce", "BoostDuration", "BoostRecharge", "BoostRechargeDelay", "BoostEfficiency"]
        shares = {name: {"Cockpit": 0.0, "Engine1": 0.0, "Engine2": 0.0, "Stabilisers": 0.0, "Boost": 0.0} for name in R.RAW_ORDER}
        for name in ("TopSpeed", "EngineOutput"):
            shares[name].update({"Cockpit": general, "Engine1": engine, "Engine2": engine})
        for name in handling:
            shares[name].update({"Cockpit": general, "Stabilisers": stabiliser})
        for name in boost_stats:
            shares[name].update({"Cockpit": general, "Boost": boost})
        # Weight and Drag are not in the policy attributes. Take them from the live tables.
        live_names = {"Cockpit": "Cockpit", "FrontEngine": "Engine1", "RearEngine": "Engine2", "Stabilisers": "Stabilisers", "Boost": "Boost"}
        root = R.find_child(self.capture.performance, "BalancedStockProfiles")
        observed = {}
        for profile in root["children"]:
            totals = R.attr_values(profile)
            for component in R.find_child(profile, "ComponentAllocation")["children"]:
                values = R.attr_values(component)
                for name in R.RAW_ORDER:
                    observed.setdefault((name, live_names[component["name"]]), set()).add(round(values[name] / totals[name], 9))
        for (name, component), values in sorted(observed.items()):
            assert len(values) == 1, "share differs between cockpits: %s %s %s" % (name, component, values)
            value = values.pop()
            if name in ("Weight", "Drag"):
                shares[name][component] = value
            else:
                assert abs(shares[name][component] - value) < 1e-9, "policy share mismatch %s %s" % (name, component)
        for name in R.RAW_ORDER:
            assert abs(sum(shares[name].values()) - 1) < 1e-9, "shares of %s do not sum to 1" % name
        return shares

    def _variant_multipliers(self):
        """(slot, variant) -> {stat: multiplier}. From VariantPolicy, checked against live modules."""
        policy = self.config.variant_policy
        lower = set(R.LOWER_IS_BETTER)
        higher = {
            ("Engine", "LIGHTWEIGHT"): policy["LightweightEngineHigherMultiplier"],
            ("Stabilisers", "LIGHTWEIGHT"): policy["LightweightStabilisersHigherMultiplier"],
            ("Boost", "LIGHTWEIGHT"): policy["LightweightBoostHigherMultiplier"],
        }
        result = {}
        for slot in CORE_ORDER:
            kind = "Engine" if slot.startswith("Engine") else slot
            for variant in ("LIGHTWEIGHT", "POWER"):
                if variant == "LIGHTWEIGHT":
                    up, down = higher[(kind, variant)], policy["LightweightLowerBetterMultiplier"]
                else:
                    up, down = policy["PowerHigherMultiplier"], policy["PowerLowerBetterMultiplier"]
                result[(slot, variant)] = {name: (down if name in lower else up) for name in R.RAW_ORDER}
        # Check against every live Piercer family.
        for slot in CORE_ORDER:
            donor_stem = CORE_SLOTS[slot][1]
            for n in range(1, 7):
                standard = self.modules[module_id(donor_stem, n, "STANDARD")]["attributes"]
                for variant in ("LIGHTWEIGHT", "POWER"):
                    live = self.modules[module_id(donor_stem, n, variant)]["attributes"]
                    for name in R.RAW_ORDER:
                        if standard[name]:
                            ratio = live[name] / standard[name]
                            assert abs(ratio - result[(slot, variant)][name]) < 1e-9, (slot, n, variant, name, ratio)
                        else:
                            assert live[name] == 0
        return result


# ---------------------------------------------------------------------------
# Totals
# ---------------------------------------------------------------------------


def scaled_totals(live, piercer_id, scale, tier_below=None):
    """Stock totals for one cockpit.

    tier_below: the totals of the cockpit one tier down. A lower-is-better total is never allowed
    to be worse than there. Without this the ladder inverts where two Piercer profiles are equal
    (Forge and Vector both have Weight 220, Drag 100, BoostRecharge 14) and each tier solves its
    own scale: the D car came out heavier and draggier than the E car.
    """
    profile = live.profiles[piercer_id]
    totals = {}
    for name in R.RAW_ORDER:
        value = profile[name] * CHARACTER.get(name, 1.0)
        minimum = live.config.curves[name]["TechnicalMinimum"]
        if name in R.LOWER_IS_BETTER:
            value = value / scale
            if tier_below is not None:
                value = min(value, tier_below[name])
            value = max(value, minimum)
        else:
            value = max(value * scale, minimum)
        totals[name] = round(value, TOTAL_DECIMALS[name])
    return totals


def solve_scale(live, piercer_id, target, tier_below=None):
    """Smallest scale (to 1e-12) whose rounded totals rate at or above the target."""
    def index(scale):
        return live.calculator.calculate(scaled_totals(live, piercer_id, scale, tier_below))["Overall"]["UnroundedPerformanceIndex"]

    low, high = 0.5, 2.0
    assert index(low) < target <= index(high), "target out of range"
    for _ in range(60):
        middle = (low + high) / 2
        if index(middle) < target:
            low = middle
        else:
            high = middle
    return high


def body_stat_table():
    """slot -> kit n -> full 17 stat dict (missing stats are 0)."""
    table = {}
    for slot in BODY_ORDER:
        table[slot] = {}
        for n in range(1, 7):
            _, stats = BODY_STATS[slot][n]
            unknown = set(stats) - set(R.RAW_ORDER)
            assert not unknown, "unknown stat in body table: %s" % unknown
            table[slot][n] = {name: float(stats.get(name, 0)) for name in R.RAW_ORDER}
    return table


def enforce_cockpit_floor(live, cockpit, totals, body):
    """Reduce a kit's body stat when the cockpit's own value would fall under its floor.

    Floor: the technical minimum for higher-is-better stats (0, or 0.1 for BoostDuration) and 0
    for lower-is-better stats (their minimum applies to the build total, see report.md).
    The largest contributor is reduced first, half a point at a time. Returns the changes made.
    """
    changes = []
    n = cockpit["n"]
    for name in R.RAW_ORDER:
        share = totals[name] * live.shares[name]["Cockpit"]
        floor = 0.0 if name in R.LOWER_IS_BETTER else float(live.config.curves[name]["TechnicalMinimum"])
        while share - sum(body[slot][n][name] for slot in BODY_ORDER) < floor - 1e-9:
            slot = max(BODY_ORDER, key=lambda item: (body[item][n][name], -BODY_ORDER.index(item)))
            if body[slot][n][name] <= 0:
                raise AssertionError("cannot keep cockpit %s %s above its floor" % (cockpit["id"], name))
            before = body[slot][n][name]
            body[slot][n][name] = max(0.0, before - 0.5)
            changes.append((cockpit["id"], slot, name, before, body[slot][n][name]))
    return changes


# ---------------------------------------------------------------------------
# Attribute builders
# ---------------------------------------------------------------------------

CORE_COPY = [
    "Acceleration", "BalanceEditable", "BalanceNote", "Boost", "BoostNotes", "Braking", "CatalogPublishReady",
    "CatalogVisible", "Drift", "Handling", "HiddenFromCatalog", "Level", "MaxLevel", "MaxPointsPerPath",
    "NeonPrice", "Power", "PreviewImage", "RetiredFromCatalog", "TemplateType", "Tier", "Upgradable",
    "UpgradePointCapacity", "UpgradePrice", "V2IntegrationReady", "V2Materialised", "V2Published",
    "VariantName", "VariantOrder",
]
BODY_COPY = [
    "BalanceEditable", "BalanceNote", "Boost", "Level", "MaxLevel", "MaxPointsPerPath", "Point1CostGuide",
    "Point2CostGuide", "Point3CostGuide", "Point4CostGuide", "Point5CostGuide", "Point6CostGuide", "Power",
    "PreviewImage", "RetiredFromCatalog", "TemplateType", "UpgradePointCapacity", "UpgradePrice",
    "V2MaterialisationVersion", "V2Materialised",
]
COCKPIT_COPY = [
    "Acceleration", "Boost", "Braking", "CatalogPublishReady", "DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY",
    "DefaultColoursEditable", "DefaultColoursNote", "Drift", "Handling", "OwnedByDefault", "Power",
    "StandardAudioProfileId", "TemplateType", "V2IntegrationReady", "V2Materialised", "V2Published",
]
COCKPIT_COLOUR_ATTRIBUTES = [
    "DefaultDetailColor", "DefaultFrontLightsColor", "DefaultNeonColor", "DefaultPrimaryColor",
    "DefaultRearLightsColor", "DefaultSecondaryColor",
]


def spec_module_name(live, cockpit, slot):
    kit = live.spec["kits"][cockpit["spec_kit"]]
    assert kit["name"] == cockpit["kit_name"], "kit name differs from INTERFACE.md: %s" % kit["name"]
    return live.spec["modules"][slot][kit["modules"][slot]]["name"]


def build_core_module(live, cockpit, slot, variant, standard_raw):
    stem, donor_stem, folder, module_type, module_slot, engine_position, rear_engine = CORE_SLOTS[slot]
    this_id = module_id(stem, cockpit["n"], variant)
    donor = live.modules[module_id(donor_stem, 3, variant)]["attributes"]
    name = spec_module_name(live, cockpit, slot)
    if variant == "STANDARD":
        raw = dict(standard_raw)
        price = 0
    else:
        multipliers = live.variant_multipliers[(slot, variant)]
        raw = {stat: standard_raw[stat] * multipliers[stat] for stat in R.RAW_ORDER}
        price = cockpit["price"] * 12 // 100
        assert price * 100 == cockpit["price"] * 12, "variant price is not a whole number"
    attributes = {}
    for key, donor_value in donor.items():
        if key in R.RAW_ORDER:
            value = num(raw[key])
        elif key.startswith("PerformanceDelta_"):
            assert donor_value == 0, "donor carries a non-zero delta twin: " + key
            value = 0
        elif key in ("ModuleId", "V2PublishedModuleId"):
            value = this_id
        elif key in ("DisplayName", "ModuleName"):
            value = name
        elif key == "CategoryId":
            value = CATEGORY_ID
        elif key == "ModuleFolder":
            value = folder
        elif key == "ModuleType":
            value = module_type
        elif key == "ModuleSlot":
            value = module_slot
        elif key == "EnginePosition":
            value = donor_value if engine_position is None else engine_position
        elif key == "RearEngine":
            value = donor_value if rear_engine is None else rear_engine
        elif key == "SourceCockpitId":
            value = cockpit["id"]
        elif key == "SourceCockpitDisplayName":
            value = cockpit["name"]
        elif key in ("Price", "PurchasePrice"):
            value = price
        elif key.startswith("Point") and key.endswith("CostGuide"):
            if variant == "STANDARD":
                value = donor_value
            else:
                value = round_to_100(price, VARIANT_POINT_PERCENT[int(key[5]) - 1])
        elif key in CORE_COPY:
            value = donor_value
        else:
            raise AssertionError("no rule for donor attribute %s on %s" % (key, this_id))
        attributes[key] = value
    # INTERFACE.md values that must agree with the donor copy.
    assert attributes["VariantName"] == VARIANT_NAME[variant] and attributes["Tier"] == VARIANT_NAME[variant]
    assert attributes["VariantOrder"] == VARIANT_ORDER[variant]
    assert attributes["NeonPrice"] == CORE_NEON_PRICE[variant]
    assert attributes["UpgradePointCapacity"] == (2 if variant == "STANDARD" else 6)
    assert (attributes.get("MaxPointsPerPath") == 3) == (variant == "STANDARD")
    attributes["CardTitle"] = name
    attributes["RatingReferenceCockpitId"] = RATING_REFERENCE_COCKPIT_ID
    donor_for_paths = module_id(donor_stem, int(cockpit["piercer"][-2:]), variant)
    assert donor_for_paths in live.modules
    return this_id, {"attributes": dict(sorted(attributes.items())), "upgradePathDonor": donor_for_paths}


def legacy_body_headlines(raw):
    """Legacy headline attributes, following the live LVL1 accessories:
    Acceleration = EngineOutput, Braking = BrakingForce, Handling = the handling level,
    Drift = the drift level. Rounded half up to a whole number."""
    return {
        "Acceleration": half_up(raw["EngineOutput"]),
        "Braking": half_up(raw["BrakingForce"]),
        "Handling": half_up((raw["LateralGrip"] + raw["SteeringResponse"] + raw["HoverStability"]) / 3),
        "Drift": half_up((raw["DriftControl"] + raw["DriftGrip"] + raw["DriftChargeRate"]) / 3),
    }


def build_body_module(live, cockpit, slot, raw):
    stem, donor_id, folder = BODY_SLOTS[slot]
    this_id = module_id(stem, cockpit["n"])
    donor = live.modules[donor_id]["attributes"]
    name = spec_module_name(live, cockpit, slot)
    legacy = legacy_body_headlines(raw)
    attributes = {}
    for key, donor_value in donor.items():
        if key in R.RAW_ORDER:
            value = num(raw[key])
        elif key.startswith("PerformanceDelta_"):
            value = num(raw[key[len("PerformanceDelta_"):]])
        elif key in legacy:
            value = legacy[key]
        elif key == "ModuleId":
            value = this_id
        elif key in ("DisplayName", "ModuleName"):
            value = name
        elif key == "CategoryId":
            value = CATEGORY_ID
        elif key == "ModuleFolder":
            value = folder
        elif key in ("ModuleType", "ModuleSlot"):
            value = slot
        elif key == "Price":
            value = BODY_PRICE_BY_KIT[cockpit["n"] - 1]
        elif key == "NeonPrice":
            value = BODY_NEON_PRICE_BY_KIT[cockpit["n"] - 1]
        elif key == "Tier":
            value = cockpit["kit_name"]
        elif key in BODY_COPY:
            value = donor_value
        else:
            raise AssertionError("no rule for donor attribute %s on %s" % (key, this_id))
        attributes[key] = value
    assert attributes["UpgradePointCapacity"] == 6 and attributes["MaxPointsPerPath"] == 3
    assert "PurchasePrice" not in attributes and "SourceCockpitId" not in attributes
    attributes["CardTitle"] = name
    attributes["RatingReferenceCockpitId"] = RATING_REFERENCE_COCKPIT_ID
    entry = {"attributes": dict(sorted(attributes.items()))}
    if slot in NEW_UPGRADE_PATHS:
        paths = []
        for path_id, display_name, order, deltas in NEW_UPGRADE_PATHS[slot]:
            path_attributes = {"DisplayName": display_name, "MaxPoints": 3, "Order": order, "PathId": path_id}
            for stat, delta in deltas.items():
                assert stat in R.RAW_ORDER
                path_attributes["DeltaFlat_" + stat] = delta
            paths.append({"PathId": path_id, "attributes": dict(sorted(path_attributes.items()))})
        entry["upgradePaths"] = paths
    else:
        entry["upgradePathDonor"] = donor_id
    return this_id, entry


def build_body_trims(base_id, base_entry):
    """The GT and EVO ids of one mesh body part (D6, D7): every attribute of the base part, except the
    id, the three names and the Price. No VariantName; the same upgrade path source."""
    out = []
    for trim, percent in BODY_TRIMS:
        attributes = dict(base_entry["attributes"])
        name = "%s %s" % (attributes["DisplayName"], trim)
        attributes.update({"ModuleId": "%s_%s" % (base_id, trim), "DisplayName": name, "ModuleName": name, "CardTitle": name,
                           "Price": round_to_100(attributes["Price"], percent)})
        entry = {"attributes": dict(sorted(attributes.items()))}
        for key in ("upgradePaths", "upgradePathDonor"):
            if key in base_entry:
                entry[key] = json.loads(json.dumps(base_entry[key]))
        out.append((attributes["ModuleId"], entry))
    return out


def build_cockpit(live, cockpit, raw, defaults):
    donor = live.cockpits[cockpit["piercer"]]["attributes"]
    attributes = {}
    for key, donor_value in donor.items():
        if key in COCKPIT_COLOUR_ATTRIBUTES:
            continue  # Color3: not numeric or string; the content builder owns colours.
        if key in R.RAW_ORDER:
            value = num(raw[key])
        elif key.startswith("PerformanceDelta_"):
            assert donor_value == 0
            value = 0
        elif key in ("CockpitId", "V2PublishedCockpitId"):
            value = cockpit["id"]
        elif key == "CategoryId":
            value = CATEGORY_ID
        elif key == "DisplayName":
            value = cockpit["name"]
        elif key == "Price":
            value = cockpit["price"]
        elif key == "TargetStockPI":
            value = cockpit["target"]
        elif key == "TargetTier":
            value = cockpit["tier"]
        elif key in ("MenuImage", "PreviewImage"):
            value = ""
        elif key in LEGACY_DEFAULTS:
            value = defaults[LEGACY_DEFAULTS[key]]
        elif key in COCKPIT_COPY:
            value = donor_value
        else:
            raise AssertionError("no rule for cockpit attribute %s" % key)
        attributes[key] = value
    for key, slot in NEW_DEFAULTS.items():
        if slot in defaults:  # a slot that starts empty declares no default (mesh cockpits)
            attributes[key] = defaults[slot]
    return dict(sorted(attributes.items()))


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------


def paths_for(live, entry):
    """Upgrade path list (rating.py shape) for a balance.json module entry."""
    if "upgradePaths" in entry:
        return [{"Name": path["PathId"], "attributes": path["attributes"]} for path in entry["upgradePaths"]]
    return live.modules[entry["upgradePathDonor"]]["paths"]


def as_component(live, entry):
    return {"attributes": entry["attributes"], "paths": paths_for(live, entry)}


def build(live=None):
    live = live or Live()
    body = body_stat_table()
    design = {}
    reductions = []
    # Pass 1: totals in tier order (each tier is capped by the one below on lower-is-better stats),
    # then the floor guard (it may lower a body stat for every user of that part).
    tier_below = None
    for cockpit in COCKPITS:
        scale = solve_scale(live, cockpit["piercer"], cockpit["target"], tier_below)
        totals = scaled_totals(live, cockpit["piercer"], scale, tier_below)
        free = scaled_totals(live, cockpit["piercer"], scale)
        held = [name for name in R.RAW_ORDER if free[name] != totals[name]]
        design[cockpit["id"]] = {"scale": scale, "totals": totals, "held_by_tier_below": held}
        reductions.extend(enforce_cockpit_floor(live, cockpit, totals, body))
        tier_below = totals

    balance = {"cockpits": {}, "modules": {}}
    for cockpit in COCKPITS:
        n = cockpit["n"]
        totals = design[cockpit["id"]]["totals"]
        defaults = {}
        core_raw = {}
        for slot in CORE_ORDER:
            core_raw[slot] = {name: round(totals[name] * live.shares[name][slot], MODULE_DECIMALS) for name in R.RAW_ORDER}
            for variant in VARIANTS:
                this_id, entry = build_core_module(live, cockpit, slot, variant, core_raw[slot])
                assert this_id not in balance["modules"]
                balance["modules"][this_id] = entry
            defaults[slot] = module_id(CORE_SLOTS[slot][0], n, "STANDARD")
        for slot in BODY_ORDER:
            this_id, entry = build_body_module(live, cockpit, slot, body[slot][n])
            assert this_id not in balance["modules"]
            balance["modules"][this_id] = entry
            if slot in stock_body(n):
                defaults[slot] = this_id
            if n in MESH_KITS and slot in MESH_STOCK_BODY:
                for trim_id, trim_entry in build_body_trims(this_id, entry):
                    assert trim_id not in balance["modules"]
                    balance["modules"][trim_id] = trim_entry
        cockpit_raw = {}
        for name in R.RAW_ORDER:
            others = sum(core_raw[slot][name] for slot in CORE_ORDER) + sum(body[slot][n][name] for slot in stock_body(n))
            cockpit_raw[name] = round(totals[name] - others, VALUE_DECIMALS)
        attributes = build_cockpit(live, cockpit, cockpit_raw, defaults)
        stock_modules = [as_component(live, balance["modules"][defaults[slot]]) for slot in CORE_ORDER + stock_body(n)]
        result = live.calculator.calculate(R.sum_components(attributes, stock_modules))
        balance["cockpits"][cockpit["id"]] = {
            "attributes": attributes,
            "stockPI": result["Overall"]["PerformanceIndex"],
            "stockTier": result["Overall"]["Tier"],
            "headlines": {name: num(result["Headline"][name], 2) for name in R.HEADLINE_ORDER},
        }
        design[cockpit["id"]].update({"defaults": defaults, "result": result, "cockpit_raw": cockpit_raw})
    balance["cockpits"] = dict(sorted(balance["cockpits"].items()))
    balance["modules"] = dict(sorted(balance["modules"].items()))
    return balance, design, reductions, live


# ---------------------------------------------------------------------------
# Analysis for the report
# ---------------------------------------------------------------------------


def rate(live, cockpit_attributes, components, allocations=None):
    return live.calculator.calculate(R.sum_components(cockpit_attributes, components, allocations))


OPTIONAL_BODY_SLOTS = ["SidePods", "FrontBumper", "RearBumper", "RearSpoiler"]  # FrontBody and RearBody are required
PIERCER_ACCESSORIES = ["FRONTBUMPER", "REARBUMPER", "REARSPOILER", "SIDEPODS"]
SEARCH_STARTS = 16   # start points per search: 8 evenly spaced, 8 drawn from a fixed seed
SEARCH_SEED = 20261002


class FastIndex:
    """The unrounded performance index of a raw list (R.RAW_ORDER order), without the dict work.

    It only steers the searches below. Every number that is reported or tested is recomputed with
    R.Calculator, and test_balance.py checks that the two agree.
    """

    def __init__(self, config):
        self.curves = []
        for name in R.RAW_ORDER:
            curve = config.curves[name]
            assert curve.get("CurveType") == "Power"
            self.curves.append((
                max(R._finite(curve.get("Reference"), 1), 0.0001),
                R._clamp(R._finite(curve.get("Exponent"), 1), 0.01, 1),
                R._finite(curve.get("TechnicalMinimum"), 0),
                curve.get("LowerIsBetter") is True,
            ))
        position = {name: index for index, name in enumerate(R.RAW_ORDER)}
        self.headlines = []
        for name in R.HEADLINE_ORDER:
            weights = config.headline_weights[name]
            self.headlines.append([(position[key], weights[key]) for key in sorted(weights)
                                   if R._is_number(weights[key]) and key in position])
        settings = config.overall
        self.overall_weights = [settings.get(name) if R._is_number(settings.get(name)) else None for name in R.HEADLINE_ORDER]
        self.blend = R._clamp(R._finite(settings.get("InteractionBlend"), 0.30), 0, 1)
        balance = R._clamp(R._finite(settings.get("BalanceContribution"), 0.075), 0, 1)
        base = R._clamp(R._finite(settings.get("BaseContribution"), 1 - balance), 0, 1)
        total = max(base + balance, 0.0001)
        self.base, self.balance = base / total, balance / total
        self.minimum = R._finite(settings.get("PerformanceIndexMin"), 100)
        self.maximum = max(R._finite(settings.get("PerformanceIndexMax"), 999), self.minimum + 1)
        self.origin = R._finite(settings.get("PerformanceOrigin"), 0)
        self.scale = max(R._finite(settings.get("RatingScale"), 50.43508980641478), 0.0001)

    def __call__(self, raw):
        factors = []
        for value, (reference, exponent, minimum, lower) in zip(raw, self.curves):
            if lower:
                factors.append((reference / max(value, minimum, 0.0001)) ** exponent)
            else:
                factors.append((max(value, minimum, 0) / reference) ** exponent)
        headline = []
        for weights in self.headlines:
            total = weight_total = log_total = log_weight = 0.0
            zero = False
            for index, weight in weights:
                factor = factors[index]
                total += factor * weight
                weight_total += weight
                if factor <= 0 and weight > 0:
                    zero = True
                elif weight > 0:
                    log_total += math.log(factor) * weight
                    log_weight += weight
            arithmetic = total / weight_total if weight_total > 0 else 0
            geometric = 0 if zero or log_weight <= 0 else math.exp(log_total / log_weight)
            headline.append((arithmetic * (1 - self.blend) + geometric * self.blend) * 100)
        total = weight_total = 0.0
        for value, weight in zip(headline, self.overall_weights):
            if weight is not None:
                total += value * weight
                weight_total += weight
        weighted = total / weight_total if weight_total > 0 else 0
        lowest = sorted(headline)
        combined = max(weighted * self.base + (lowest[0] + lowest[1] + lowest[2]) / 3 * self.balance, 0)
        return self.minimum + (self.maximum - self.minimum) * (1 - math.exp(-max(combined - self.origin, 0) / self.scale))


def fast_index(live):
    if not hasattr(live, "_fast_index"):
        live._fast_index = FastIndex(live.config)
    return live._fast_index


def raw_list(raw):
    return [raw[name] for name in R.RAW_ORDER]


def all_allocations(component):
    """Every allocation the live NormalizeAllocation keeps as given."""
    attributes, paths = component["attributes"], component["paths"]
    ordered = R.sorted_paths(paths)
    _, _, capacity = R.normalize_allocation(attributes, paths, {})
    limits = [max(0, R._floor(R.path_max_points(attributes, path))) for path in ordered]
    result = []
    for combo in itertools.product(*[range(limit + 1) for limit in limits]):
        if sum(combo) <= capacity:
            result.append(dict(zip([R.path_id(path) for path in ordered], combo)))
    return result


def empty_component(slot):
    """An optional slot left empty: no stats, no upgrade points."""
    return {"attributes": {"ModuleId": "(empty %s)" % slot, "UpgradePointCapacity": 0}, "paths": []}


def position_options(positions):
    """positions -> per position, a list of (allocation, raw list, cash, component) for every
    candidate component and every allocation of it."""
    options = []
    for position in positions:
        candidates = position if isinstance(position, list) else [position]
        rows = []
        for component in candidates:
            for allocation in all_allocations(component):
                raw = R.apply_to_module_raw(component["attributes"], component["paths"], allocation)
                cost = R.allocation_cost(component["attributes"], component["paths"], allocation)
                rows.append((allocation, raw_list(raw), cost, component))
        options.append(rows)
    return options


def best_upgrades(live, cockpit_attributes, positions, starts=SEARCH_STARTS):
    """Highest PI build FOUND by local search from several start points (the same ones every run).

    positions: one entry per slot. An entry is a component, or a list of candidate components
    (a core slot that may take any own-family variant, a body slot that may take any kit's part,
    an optional slot that may be empty).

    From each start point two moves repeat until neither helps:
      1. Slot move: for each slot in turn, the candidate and upgrade allocation with the highest PI.
         A point that lowers PI is not bought. Ties keep the cheaper choice, then the first.
      2. Pair move: one step on each of two slots at once (a step is one upgrade point more or
         less, or one point moved to another path). Needed near the Weight and Drag minimums,
         where a weight cut on one module is worth nothing alone but pays for a heavier upgrade
         on another.

    This is a search, not a proof: a better build can exist. build_ceiling() gives the bound.

    Returns (result, {ModuleId: allocation} of the chosen modules, upgrade cash under the live
    cost rule, chosen components).
    """
    index = fast_index(live)
    base = raw_list(R.read_component_raw(cockpit_attributes))
    options = position_options(positions)
    count = len(R.RAW_ORDER)
    slots = range(len(options))

    # Rows one step away from each row, on the same component: one path up or down by one point,
    # or one point moved from one path to another.
    neighbours = []
    for rows in options:
        lookup = {(id(component), tuple(sorted(allocation.items()))): choice for choice, (allocation, _, _, component) in enumerate(rows)}
        near = []
        for allocation, _, _, component in rows:
            ids = sorted(allocation)
            steps = [((this_id, step),) for this_id in ids for step in (1, -1)]
            steps += [((up, 1), (down, -1)) for up in ids for down in ids if up != down]
            found = []
            for change in steps:
                changed = dict(allocation)
                for this_id, step in change:
                    changed[this_id] += step
                other = lookup.get((id(component), tuple(sorted(changed.items()))))
                if other is not None:
                    found.append(other)
            near.append(found)
        neighbours.append(near)

    def total(chosen, skip=()):
        raw = list(base)
        for position in slots:
            if position not in skip:
                part = options[position][chosen[position]][1]
                for i in range(count):
                    raw[i] += part[i]
        return raw

    def slot_moves(chosen, order):
        for _ in range(40):
            changed = False
            for position in order:
                rows = options[position]
                rest = total(chosen, skip=(position,))
                best_key, best_choice = None, chosen[position]
                for choice, (_, raw, cost, _component) in enumerate(rows):
                    key = (round(index([rest[i] + raw[i] for i in range(count)]), 9), -cost, -choice)
                    if best_key is None or key > best_key:
                        best_key, best_choice = key, choice
                if best_choice != chosen[position]:
                    chosen[position] = best_choice
                    changed = True
            if not changed:
                return
        raise AssertionError("upgrade search did not settle")

    def pair_move(chosen):
        """The best change of one point on each of two slots, if it beats the current build."""
        best_value, best_pair = round(index(total(chosen)), 9), None
        for first in slots:
            for second in range(first + 1, len(options)):
                rest = total(chosen, skip=(first, second))
                for a in neighbours[first][chosen[first]]:
                    raw_a = options[first][a][1]
                    part = [rest[i] + raw_a[i] for i in range(count)]
                    for b in neighbours[second][chosen[second]]:
                        raw_b = options[second][b][1]
                        value = round(index([part[i] + raw_b[i] for i in range(count)]), 9)
                        if value > best_value:
                            best_value, best_pair = value, (first, a, second, b)
        if best_pair is None:
            return False
        first, a, second, b = best_pair
        chosen[first], chosen[second] = a, b
        return True

    best = None
    generator = random.Random(SEARCH_SEED)
    for start in range(starts):
        order = list(slots)
        if start < 8:
            chosen = [(len(rows) * start) // 8 for rows in options]
            if start % 2:
                order.reverse()
        else:
            chosen = [generator.randrange(len(rows)) for rows in options]
            generator.shuffle(order)
        for _ in range(200):
            slot_moves(chosen, order)
            if not pair_move(chosen):
                break
        else:
            raise AssertionError("upgrade search did not settle")
        cost = sum(options[position][chosen[position]][2] for position in slots)
        key = (round(index(total(chosen)), 9), -cost)
        if best is None or key > best[0]:
            best = (key, list(chosen))
    chosen = best[1]
    allocations, components, cost = {}, [], 0
    for position in slots:
        allocation, _, point_cost, component = options[position][chosen[position]]
        allocations[component["attributes"]["ModuleId"]] = allocation
        cost += point_cost
        components.append(component)
    result = rate(live, cockpit_attributes, components, allocations)
    assert abs(result["Overall"]["UnroundedPerformanceIndex"] - best[0][0]) < 1e-6, "fast index differs from the port"
    return result, allocations, cost, components


def build_ceiling(live, cockpit_attributes, positions):
    """A rating no build from these positions can beat.

    The index never falls when a higher-is-better stat rises or a lower-is-better stat falls. So for
    one module, taking for every stat on its own the best value any of its upgrade allocations
    offers gives a row no allocation of that module beats. The ceiling is the highest index over
    EVERY choice of one module (or empty) per slot, each module standing in as that row. The choice
    of modules is exact; only the upgrade points are relaxed, so no single build reaches it.

    Found by branch and bound: a branch is dropped when even the per-stat best of all its remaining
    slots cannot beat the best choice so far, and a module whose row is no better on any stat than
    another module of the same slot is left out. Both rest on the same monotonicity, so the result
    is the true maximum over the choices.

    (Until 2026-10-03 the ceiling also took the best value per stat ACROSS the modules of a slot.
    That is a valid but looser bound. It stopped being enough for Hyper once the mesh cockpits
    absorbed three body parts: mesh/INTEGRATION.md D9, report.md "Mesh kits".)
    """
    index = fast_index(live)
    count = len(R.RAW_ORDER)
    lower = [name in R.LOWER_IS_BETTER for name in R.RAW_ORDER]
    base = raw_list(R.read_component_raw(cockpit_attributes))
    slots = []
    for position in positions:
        rows = []
        for component in (position if isinstance(position, list) else [position]):
            raws = [raw_list(R.apply_to_module_raw(component["attributes"], component["paths"], allocation)) for allocation in all_allocations(component)]
            row = tuple((min if lower[i] else max)(raw[i] for raw in raws) for i in range(count))
            if row not in rows:
                rows.append(row)
        slots.append([row for row in rows if not any(
            other is not row and all((other[i] <= row[i]) if lower[i] else (other[i] >= row[i]) for i in range(count)) for other in rows)])
    rest = [[0.0] * count for _ in range(len(slots) + 1)]  # per-stat best of the slots from k on
    for k in range(len(slots) - 1, -1, -1):
        for i in range(count):
            rest[k][i] = rest[k + 1][i] + (min if lower[i] else max)(row[i] for row in slots[k])
    best = [None, None]

    def walk(k, raw):
        if k == len(slots):
            value = index(raw)
            if best[0] is None or value > best[0]:
                best[0], best[1] = value, raw
            return
        if best[0] is not None and index([raw[i] + rest[k][i] for i in range(count)]) <= best[0]:
            return
        # Most promising module first, so the best choice is found early and the rest is dropped sooner.
        for row in sorted(slots[k], key=lambda row: -index([raw[i] + row[i] + rest[k + 1][i] for i in range(count)])):
            walk(k + 1, [raw[i] + row[i] for i in range(count)])

    walk(0, base)
    return live.calculator.calculate(dict(zip(R.RAW_ORDER, best[1])))


def exotic_set(live, balance, cockpit, variant, body_kit=None, core_family=None, body_slots=None):
    """Components of an Exotic build: four core modules of one variant and the body parts of one kit in
    the cockpit's stock body slots (six; three on a mesh cockpit), or in body_slots."""
    n = cockpit["n"]
    family = core_family or n
    kit = body_kit or n
    ids = [module_id(CORE_SLOTS[slot][0], family, variant) for slot in CORE_ORDER]
    ids += [module_id(BODY_SLOTS[slot][0], kit) for slot in (body_slots or stock_body(n))]
    return [as_component(live, balance["modules"][item]) for item in ids]


def exotic_any_positions(live, balance, cockpit):
    """Everything one Exotic cockpit can wear: any own-family variant per core slot, any kit's part
    per body slot, and the four optional slots may be empty."""
    positions = []
    for slot in CORE_ORDER:
        positions.append([as_component(live, balance["modules"][module_id(CORE_SLOTS[slot][0], cockpit["n"], variant)])
                          for variant in VARIANTS])
    for slot in BODY_ORDER:
        candidates = [as_component(live, balance["modules"][module_id(BODY_SLOTS[slot][0], kit)]) for kit in range(1, 7)]
        if slot in OPTIONAL_BODY_SLOTS:
            candidates.append(empty_component(slot))
        positions.append(candidates)
    return positions


def piercer_set(live, cockpit_id, variant, accessory_level=None):
    n = int(cockpit_id[-2:])
    ids = [module_id(CORE_SLOTS[slot][1], n, variant) for slot in CORE_ORDER]
    if accessory_level:
        ids += ["MODULE_%s_LVL%d" % (kind, accessory_level) for kind in PIERCER_ACCESSORIES]
    return [live.modules[item] for item in ids]


def piercer_any_positions(live, cockpit_id):
    """Everything one Piercer cockpit can wear: any own-family variant per core slot and any level
    of each accessory, or none."""
    n = int(cockpit_id[-2:])
    positions = [[live.modules[module_id(CORE_SLOTS[slot][1], n, variant)] for variant in VARIANTS] for slot in CORE_ORDER]
    for kind in PIERCER_ACCESSORIES:
        positions.append([live.modules["MODULE_%s_LVL%d" % (kind, level)] for level in (1, 2, 3)] + [empty_component(kind)])
    return positions


def analyse(balance, design, live):
    """Numbers for report.md and for the tests."""
    out = {"piercer": {}, "exotic": {}, "body": {}, "mix": {}}
    index = fast_index(live)
    piercer_rows = {row["CockpitId"]: row for row in R.piercer_stock_builds(live.capture, live.calculator)}
    out["piercer_stock"] = piercer_rows

    for cockpit in COCKPITS:
        cid = cockpit["id"]
        attributes = balance["cockpits"][cid]["attributes"]
        pid = cockpit["piercer"]
        p_attributes = live.cockpits[pid]["attributes"]
        row = {}
        for variant in VARIANTS:
            row[variant] = rate(live, attributes, exotic_set(live, balance, cockpit, variant))
        row["STANDARD_MAX"] = best_upgrades(live, attributes, exotic_set(live, balance, cockpit, "STANDARD"))
        row["LIGHTWEIGHT_MAX"] = best_upgrades(live, attributes, exotic_set(live, balance, cockpit, "LIGHTWEIGHT"))
        row["POWER_MAX"] = best_upgrades(live, attributes, exotic_set(live, balance, cockpit, "POWER"))
        any_positions = exotic_any_positions(live, balance, cockpit)
        row["ANY_MAX"] = best_upgrades(live, attributes, any_positions)
        row["ANY_CEILING"] = build_ceiling(live, attributes, any_positions)
        row["NO_OPTIONAL_BODY"] = rate(live, attributes, [
            as_component(live, balance["modules"][design[cid]["defaults"][slot]])
            for slot in CORE_ORDER + ["FrontBody", "RearBody"]])
        # Every body slot filled with the cockpit's own kit. On a mesh cockpit that is three parts more than stock.
        row["FULL_BODY"] = rate(live, attributes, exotic_set(live, balance, cockpit, "STANDARD", body_slots=BODY_ORDER))
        out["exotic"][cid] = row
        prow = {}
        for variant in VARIANTS:
            prow[variant] = rate(live, p_attributes, piercer_set(live, pid, variant))
        prow["STANDARD_LVL1_MAX"] = best_upgrades(live, p_attributes, piercer_set(live, pid, "STANDARD", 1))
        prow["STANDARD_LVL1"] = rate(live, p_attributes, piercer_set(live, pid, "STANDARD", 1))
        prow["POWER_LVL3"] = rate(live, p_attributes, piercer_set(live, pid, "POWER", 3))
        prow["LIGHTWEIGHT_MAX"] = best_upgrades(live, p_attributes, piercer_set(live, pid, "LIGHTWEIGHT", 3))
        prow["POWER_MAX"] = best_upgrades(live, p_attributes, piercer_set(live, pid, "POWER", 3))
        p_positions = piercer_any_positions(live, pid)
        prow["ANY_MAX"] = best_upgrades(live, p_attributes, p_positions)
        prow["ANY_CEILING"] = build_ceiling(live, p_attributes, p_positions)
        out["piercer"][pid] = prow

    # Body module value: PI of each stock build with one body part swapped.
    for slot in BODY_ORDER:
        out["body"][slot] = {}
        for kit in range(1, 7):
            part_id = module_id(BODY_SLOTS[slot][0], kit)
            part = as_component(live, balance["modules"][part_id])
            row = {}
            for cockpit in COCKPITS:
                defaults = design[cockpit["id"]]["defaults"]
                components = [as_component(live, balance["modules"][defaults[item]]) for item in CORE_ORDER + stock_body(cockpit["n"]) if item != slot]
                result = rate(live, balance["cockpits"][cockpit["id"]]["attributes"], components + [part])
                row[cockpit["id"]] = result["Overall"]
            out["body"][slot][kit] = row

    # Cross-kit mixes: whole foreign kits, then the best and worst part per slot (exhaustive 6^6).
    for cockpit in COCKPITS:
        cid = cockpit["id"]
        attributes = balance["cockpits"][cid]["attributes"]
        whole = {}
        for kit in range(1, 7):
            whole[kit] = rate(live, attributes, exotic_set(live, balance, cockpit, "STANDARD", body_kit=kit))["Overall"]
        core = R.sum_components(attributes, exotic_set(live, balance, cockpit, "STANDARD")[:4])
        mix_slots = stock_body(cockpit["n"])  # the styles are swapped in the slots the stock build fills
        raws = {slot: [R.apply_to_module_raw(balance["modules"][module_id(BODY_SLOTS[slot][0], kit)]["attributes"]) for kit in range(1, 7)]
                for slot in mix_slots}
        lists = [[raw_list(raw) for raw in raws[slot]] for slot in mix_slots]
        core_list = raw_list(core)
        best = worst = None
        for combo in itertools.product(range(6), repeat=len(mix_slots)):
            raw = list(core_list)
            for parts, choice in zip(lists, combo):
                part = parts[choice]
                for i in range(len(raw)):
                    raw[i] += part[i]
            value = index(raw)
            if best is None or value > best[0]:
                best = (value, combo)
            if worst is None or value < worst[0]:
                worst = (value, combo)
        checked = []
        for value, combo in (best, worst):
            raw = dict(core)
            for slot, choice in zip(mix_slots, combo):
                for name in R.RAW_ORDER:
                    raw[name] += raws[slot][choice][name]
            exact = live.calculator.calculate(raw)["Overall"]["UnroundedPerformanceIndex"]
            assert abs(exact - value) < 1e-6, "fast index differs from the port"
            checked.append((exact, combo))
        out["mix"][cid] = {"whole": whole, "best": checked[0], "worst": checked[1]}

    # What +1 Drag costs each stock build.
    out["drag_plus_one"] = {}
    for cockpit in COCKPITS:
        raw = dict(design[cockpit["id"]]["result"]["Raw"])
        before = live.calculator.calculate(raw)["Overall"]["UnroundedPerformanceIndex"]
        raw["Drag"] += 1
        out["drag_plus_one"][cockpit["id"]] = live.calculator.calculate(raw)["Overall"]["UnroundedPerformanceIndex"] - before

    # What three points on one body upgrade path are worth on each stock build.
    out["path_worth"] = {}
    for slot in BODY_ORDER:
        out["path_worth"][slot] = {}
        for cockpit in COCKPITS:
            defaults = design[cockpit["id"]]["defaults"]
            attributes = balance["cockpits"][cockpit["id"]]["attributes"]
            components = [as_component(live, balance["modules"][defaults[item]]) for item in CORE_ORDER + stock_body(cockpit["n"])]
            # A slot that starts empty (mesh cockpits): the cockpit's own-kit part is fitted first.
            part_id = defaults.get(slot) or module_id(BODY_SLOTS[slot][0], cockpit["n"])
            part = as_component(live, balance["modules"][part_id])
            if slot not in defaults:
                components = components + [part]
            before = rate(live, attributes, components)["Overall"]["UnroundedPerformanceIndex"]
            for path in R.sorted_paths(part["paths"]):
                this_id = R.path_id(path)
                allocation = {this_id: 3}
                after = rate(live, attributes, components, {part_id: allocation})["Overall"]["UnroundedPerformanceIndex"]
                entry = out["path_worth"][slot].setdefault(this_id, {
                    "cost": R.allocation_cost(part["attributes"], part["paths"], allocation),
                    "deltas": {key[10:]: value for key, value in path["attributes"].items() if key.startswith("DeltaFlat_")},
                    "new": slot in NEW_UPGRADE_PATHS, "gain": {}})
                entry["gain"][cockpit["id"]] = after - before

    # Core family swaps (owner of both cockpits): cheapest cockpit with the top family's set.
    low, high = COCKPITS[0], COCKPITS[-1]
    out["family_swap"] = {
        "exotic": rate(live, balance["cockpits"][low["id"]]["attributes"],
                       exotic_set(live, balance, low, "STANDARD", core_family=high["n"]))["Overall"],
        "exotic_power": rate(live, balance["cockpits"][low["id"]]["attributes"],
                             exotic_set(live, balance, low, "POWER", core_family=high["n"]))["Overall"],
        "piercer": rate(live, live.cockpits[low["piercer"]]["attributes"], piercer_set(live, high["piercer"], "STANDARD"))["Overall"],
        "piercer_power": rate(live, live.cockpits[low["piercer"]]["attributes"], piercer_set(live, high["piercer"], "POWER"))["Overall"],
    }
    return out


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------


def fmt(value, decimals=2):
    if isinstance(value, str):
        return value
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return "{:,}".format(value) if abs(value) >= 1000 else str(value)
    text = ("%." + str(decimals) + "f") % value
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def under(value):
    """value rounded up to one decimal, for "under X" sentences."""
    return math.ceil(value * 10 - 1e-9) / 10


def table(header, rows):
    lines = ["| " + " | ".join(header) + " |", "|" + "|".join("---" for _ in header) + "|"]
    for row in rows:
        lines.append("| " + " | ".join(str(cell) for cell in row) + " |")
    return "\n".join(lines)


def stat_summary(stats):
    parts = []
    for name in R.RAW_ORDER:
        value = stats.get(name, 0)
        if value:
            parts.append("%s %s%s" % (name, "+" if value > 0 else "", fmt(value)))
    return ", ".join(parts)


def write_report(balance, design, reductions, live, analysis):
    L = []
    add = L.append
    cockpits = balance["cockpits"]
    modules = balance["modules"]

    add("# Exotic category: balance report")
    add("")
    add("Generated by `scripts/exotic_category/balance/build_balance.py`. Do not edit by hand. Data: `balance.json`.")
    add("Baseline: `roblox/captures/exotic-before/capture.json` (place %s, captured %s)." % (
        live.capture.data["place_id"], live.capture.data["generated_in_studio"]))
    add("")
    add("Checks: `test_balance.py` (last output in `test_output.txt`). Rebuild with `py -3 scripts/exotic_category/balance/build_balance.py`.")
    add("")
    add("Evidence label for every number here: **generated**. Nothing is installed. Ratings come from `rating.py`, a Python port of the live calculator. No number here was measured in Play.")
    add("")

    # Mesh kits --------------------------------------------------------
    add("## Mesh kits (exotic_02 Curve, exotic_05 Hyper)")
    add("")
    add("From `scripts/exotic_category/mesh/INTEGRATION.md` (D6 to D9). It changes how the sections below read for these two cockpits; the other four are as before.")
    add("")
    add("- **Stock build**: cockpit + four Standard core modules + three body defaults (Nose, Engine Deck, Wing). `SidePods`, `FrontBumper` and `RearBumper` declare no default and start empty. The cockpit's own raw stats absorb those three parts, so the stock totals and the stock PI are unchanged. Wherever a section says \"six body parts\" or \"its six default body modules\", read three for these two cockpits.")
    add("- **Fitting the three empty slots adds stats on top of the target total.** With all six own-kit parts: %s." % "; ".join(
        "%s %s %d (stock %d, %+.2f unrounded)" % (c["id"], analysis["exotic"][c["id"]]["FULL_BODY"]["Overall"]["Tier"], analysis["exotic"][c["id"]]["FULL_BODY"]["Overall"]["PerformanceIndex"],
                                                  cockpits[c["id"]]["stockPI"], analysis["exotic"][c["id"]]["FULL_BODY"]["Overall"]["UnroundedPerformanceIndex"] - analysis["exotic"][c["id"]]["STANDARD"]["Overall"]["UnroundedPerformanceIndex"])
        for c in COCKPITS if c["n"] in MESH_KITS))
    add("  The tier does not change. \"Highest build found\" and \"Ceiling\" (section 7) already search every body slot, filled or empty.")
    add("- **Twelve new ModuleIds**: `_GT` and `_EVO` of the Nose, Engine Deck and Wing of kits 02 and 05. Each copies every attribute and the upgrade paths of its base part, so it rates exactly as the base part does. Only the names (base name plus the trim) and the `Price` differ: base x 2 (GT) and base x 3.5 (EVO), rounded to 100.")
    add("")
    rows = []
    for n in MESH_KITS:
        for slot in MESH_STOCK_BODY:
            base_id = module_id(BODY_SLOTS[slot][0], n)
            for this_id in [base_id] + ["%s_%s" % (base_id, trim) for trim, _ in BODY_TRIMS]:
                attributes = modules[this_id]["attributes"]
                rows.append(["`%s`" % this_id, attributes["DisplayName"], fmt(attributes["Price"]), fmt(attributes["NeonPrice"])])
    add(table(["ModuleId", "Name", "Price", "NeonPrice"], rows))
    add("")
    add("- In sections 6, 8 and 10 a style swap on these two cockpits is made in the three stock slots; a part of an empty slot is rated as fitted on top of the stock build.")
    add("")

    # 1 ----------------------------------------------------------------
    add("## 1. Rating port proof")
    add("")
    add("`rating.py` ports `PerformanceCalculator`, `PerformanceDefinitions`, `PerformanceRuntime.ReadComponentRaw` / `CalculateComponents` and `PerformanceUpgradeRuntime.NormalizeAllocation` / `ApplyToModuleRaw` / `NextPointCost`. The five source hashes in the capture manifest match the ones the port was written against. Config comes from the capture (`ReplicatedStorage.Config.Vehicles.Performance`), merged over the code defaults as the live code does.")
    add("")
    add("The port is exact for number attributes, which is every live and every Exotic value. Luau `or`, `tonumber`, `math.clamp` and `math.floor` are ported with their Luau meaning (0 and the empty string are kept by `or`; `tonumber` follows C `strtod`), checked against live Studio output for 31 strings. No number in this report depends on those cases.")
    add("")
    add("Live config used: `PerformanceOrigin=%s`, `RatingScale=%s`, `BaseContribution=%s`, `BalanceContribution=%s`, `InteractionBlend=%s`, `InternalPrecision=%s`, index range %s to %s. `TopSpeed` reference is %s (code default 130). Tier bands: %s." % (
        live.config.overall["PerformanceOrigin"], live.config.overall["RatingScale"], live.config.overall["BaseContribution"],
        live.config.overall["BalanceContribution"], live.config.overall["InteractionBlend"], live.config.overall["InternalPrecision"],
        live.config.overall["PerformanceIndexMin"], live.config.overall["PerformanceIndexMax"], live.config.curves["TopSpeed"]["Reference"],
        ", ".join("%s %s" % (tier, live.config.tier_bands[tier]) for tier in "EDCBAS")))
    add("")
    add("Six Piercer stock builds, recomputed from the capture attributes (cockpit + its four default Standard modules):")
    add("")
    rows = []
    for pid in R.PIERCER_TIER_ORDER:
        row = analysis["piercer_stock"][pid]
        overall = row["Result"]["Overall"]
        rows.append([pid, row["DisplayName"], row["TargetStockPI"], overall["PerformanceIndex"], fmt(overall["InternalPerformanceIndex"]),
                     overall["Tier"], "equal" if overall["PerformanceIndex"] == row["TargetStockPI"] else "%+d" % (overall["PerformanceIndex"] - row["TargetStockPI"])]
                    + [fmt(row["Result"]["Headline"][name]) for name in R.HEADLINE_ORDER])
    add(table(["Cockpit", "Name", "`TargetStockPI` attribute", "Computed PI", "Internal", "Tier", "Computed against attribute"] + R.HEADLINE_ORDER, rows))
    add("")
    add("- The computed values are 202, 374, 525, 662, 787, 925. They equal the independent read-only calibration in `output/exotic-impl/understand/ui.md` section 5.1.")
    add("- Live Studio was read again after the capture (read-only, 2026-10-02, place 133417340424236, Edit): every numeric attribute under `Config.Vehicles.Performance` (31 folders), the stock profiles (337 folders), the 6 Piercer cockpits and the 116 modules with their 249 upgrade paths gave the same checksums as the capture, and the five ported sources had the same lengths. Only `PIERCER` exists under `Categories`.")
    add("- Four of six equal the live `TargetStockPI` attribute. Forge computes 202 against an attribute of 200, and Vector 374 against 375. That is live data, not a port error: `TargetStockPI` is not read by any script, and the stock totals equal `BalancedStockProfiles` on all 17 stats.")
    add("")

    # 2 ----------------------------------------------------------------
    add("## 2. Prices")
    add("")
    rows = []
    for cockpit in COCKPITS:
        piercer_price = live.cockpits[cockpit["piercer"]]["attributes"]["Price"]
        variant = modules[module_id("MODULE_ENGINE_EXOTIC", cockpit["n"], "POWER")]["attributes"]
        rows.append([cockpit["id"], cockpit["name"], cockpit["tier"], fmt(cockpit["price"]), fmt(piercer_price),
                     "%+.1f%%" % ((cockpit["price"] / piercer_price - 1) * 100), fmt(variant["Price"]),
                     " / ".join(fmt(variant["Point%dCostGuide" % point]) for point in range(1, 7))])
    add(table(["Cockpit", "Name", "Tier", "Price", "Piercer price", "Over Piercer", "Lightweight or Power module (12%)", "`Point1..6CostGuide` on those modules"], rows))
    add("")
    add("- Standard core modules: `Price=0`, `PurchasePrice=0`, with the live type-flat guides (engine 6,050 / 7,563, stabilisers 4,950 / 6,188, boost 8,250 / 10,313).")
    add("- Variant guides are 8 / 10 / 12 / 15 / 18 / 22 percent of the module price, rounded to 100. The same rule reproduces all six live Piercer families.")
    add("- `NeonPrice` on core modules: 5,000 / 6,500 / 8,000 (Standard / Lightweight / Power), as live.")
    add("")
    rows = []
    for cockpit in COCKPITS:
        n = cockpit["n"]
        rows.append([n, cockpit["kit_name"], fmt(BODY_PRICE_BY_KIT[n - 1]), fmt(BODY_NEON_PRICE_BY_KIT[n - 1]), fmt(6 * BODY_PRICE_BY_KIT[n - 1])])
    add(table(["Kit", "Name", "Body part `Price`", "Body part `NeonPrice`", "Six body parts"], rows))
    add("")
    add("- Body parts carry `Price` only. Upgrade guides are the live accessory guides: Nose, Splitter, Engine Deck and Diffuser 3,025 / 3,781 / 4,538 / 5,596 / 6,806 / 8,168; Wing 3,575 / 4,469 / 5,363 / 6,614 / 8,044 / 9,653; Side Pods 3,850 / 4,813 / 5,775 / 7,123 / 8,663 / 10,395.")
    add("")

    # 3 ----------------------------------------------------------------
    add("## 3. Stock totals and character")
    add("")
    add("Target stock totals = Piercer stock profile of the same tier x character x scale. Character multipliers: %s. Higher-is-better stats are multiplied by the scale, lower-is-better stats are divided by it, no total goes under its technical minimum, and no lower-is-better total is worse than on the tier below." % ", ".join("`%s` x%s" % (name, fmt(value)) for name, value in CHARACTER.items()))
    add("")
    held = ["%s `%s`" % (cockpit["name"], "`, `".join(design[cockpit["id"]]["held_by_tier_below"])) for cockpit in COCKPITS if design[cockpit["id"]]["held_by_tier_below"]]
    add("Totals held at the value of the tier below: %s. Forge and Vector have the same `Weight`, `Drag` and `BoostRecharge`, and each tier solves its own scale, so without this rule the D cockpit came out slightly heavier and draggier than the E cockpit. The scale is solved with the rule applied, so the stock PI still lands on the target." % ("; ".join(held) if held else "none"))
    add("")
    rows = []
    for cockpit in COCKPITS:
        d = design[cockpit["id"]]
        rows.append([cockpit["id"], cockpit["name"], cockpit["tier"], cockpit["piercer"], "%.6f" % d["scale"], cockpit["target"],
                     cockpits[cockpit["id"]]["stockPI"], fmt(d["result"]["Overall"]["InternalPerformanceIndex"]), cockpits[cockpit["id"]]["stockTier"]])
    add(table(["Cockpit", "Name", "Tier", "Piercer base", "Solved scale", "Target PI", "Stock PI", "Internal", "Stock tier"], rows))
    add("")
    add("Exotic stock total, with the Piercer total of the same tier in brackets:")
    add("")
    rows = []
    for name in R.RAW_ORDER:
        row = [name]
        for cockpit in COCKPITS:
            row.append("%s (%s)" % (fmt(design[cockpit["id"]]["totals"][name], 3), fmt(live.profiles[cockpit["piercer"]][name], 3)))
        rows.append(row)
    add(table(["Stat"] + ["%s %s" % (cockpit["tier"], cockpit["name"]) for cockpit in COCKPITS], rows))
    add("")

    # 4 ----------------------------------------------------------------
    add("## 4. Stock PI, tier and headlines next to the Piercer of the same tier")
    add("")
    rows = []
    for cockpit in COCKPITS:
        entry = cockpits[cockpit["id"]]
        prow = analysis["piercer_stock"][cockpit["piercer"]]
        rows.append(["**%s %s**" % (cockpit["id"], cockpit["name"]), fmt(cockpit["price"]), "%s %d" % (entry["stockTier"], entry["stockPI"])]
                    + [fmt(entry["headlines"][name], 1) for name in R.HEADLINE_ORDER])
        rows.append(["%s %s" % (cockpit["piercer"], prow["DisplayName"]), fmt(prow["Price"]),
                     "%s %d" % (prow["Result"]["Overall"]["Tier"], prow["Result"]["Overall"]["PerformanceIndex"])]
                    + [fmt(prow["Result"]["Headline"][name], 1) for name in R.HEADLINE_ORDER])
    add(table(["Cockpit", "Price", "Stock"] + R.HEADLINE_ORDER, rows))
    add("")
    add("The garage bar is full at a headline of 180 (`Config.UI.GarageReplacement.StatReference`), so Gull fills every bar, as Zenith does.")
    add("")

    # 5 ----------------------------------------------------------------
    add("## 5. Component split")
    add("")
    add("Shares of each stock total (live `ComponentAllocationPolicy`, with the Weight and Drag rows read from the six live `ComponentAllocation` tables):")
    add("")
    groups = [("TopSpeed, EngineOutput", "TopSpeed"), ("Weight", "Weight"),
              ("LateralGrip, SteeringResponse, HoverStability, DriftControl, DriftGrip, DriftChargeRate, BrakingForce, Downforce", "LateralGrip"),
              ("BoostForce, BoostDuration, BoostRecharge, BoostRechargeDelay, BoostEfficiency", "BoostForce"), ("Drag", "Drag")]
    add(table(["Stats", "Cockpit", "Engine1", "Engine2", "Stabilisers", "Boost"],
              [[label] + [fmt(live.shares[name][part], 3) for part in ("Cockpit", "Engine1", "Engine2", "Stabilisers", "Boost")] for label, name in groups]))
    add("")
    add("The cockpit attribute is its share minus the six default body parts, so cockpit + four Standard + six body = the stock total. Cockpit raw values (share before the body parts in brackets):")
    add("")
    rows = []
    for name in R.RAW_ORDER:
        row = [name]
        for cockpit in COCKPITS:
            d = design[cockpit["id"]]
            row.append("%s (%s)" % (fmt(d["cockpit_raw"][name], 4), fmt(d["totals"][name] * live.shares[name]["Cockpit"], 4)))
        rows.append(row)
    add(table(["Stat"] + [cockpit["id"] for cockpit in COCKPITS], rows))
    add("")
    add("Floor rule used: no cockpit raw value is negative; higher-is-better stats stay at or above their technical minimum (0, and 0.1 for `BoostDuration`); for `Weight`, `BoostRecharge`, `BoostRechargeDelay` and `Drag` the minimum is checked on the stock total, because that is where the live calculator applies it (live Zenith cockpit `Weight` is 42 against a minimum of 60).")
    add("")
    if reductions:
        add("Body stats lowered by the floor rule:")
        add("")
        add(table(["Cockpit", "Slot", "Stat", "Designed", "Used"], [[a, b, c, fmt(d), fmt(e)] for a, b, c, d, e in reductions]))
    else:
        add("Body stats lowered by the floor rule: none. The designed values fit under every cockpit share.")
    add("")
    add("Standard core modules (Engine1 and Engine2 carry the same numbers, as on Piercer):")
    add("")
    rows = []
    for cockpit in COCKPITS:
        n = cockpit["n"]
        engine = modules[module_id("MODULE_ENGINE_EXOTIC", n, "STANDARD")]["attributes"]
        stabiliser = modules[module_id("MODULE_STABILISER_EXOTIC", n, "STANDARD")]["attributes"]
        boost = modules[module_id("MODULE_BOOST_EXOTIC", n, "STANDARD")]["attributes"]
        rows.append([cockpit["id"],
                     " / ".join(fmt(engine[name], 4) for name in ("TopSpeed", "EngineOutput", "Weight")),
                     " / ".join(fmt(stabiliser[name], 4) for name in ("Weight", "LateralGrip", "SteeringResponse", "HoverStability", "DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "Drag", "Downforce")),
                     " / ".join(fmt(boost[name], 4) for name in ("Weight", "BoostForce", "BoostDuration", "BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag"))])
    add(table(["Family", "Engine: TopSpeed / EngineOutput / Weight",
               "Stabilisers: Weight / LateralGrip / SteeringResponse / HoverStability / DriftControl / DriftGrip / DriftChargeRate / BrakingForce / Drag / Downforce",
               "Boost: Weight / BoostForce / BoostDuration / BoostRecharge / BoostRechargeDelay / BoostEfficiency / Drag"], rows))
    add("")
    policy = live.config.variant_policy
    add("Lightweight and Power use the live `VariantPolicy` multipliers on the Standard values: Lightweight higher-is-better x%s (engine), x%s (stabilisers), x%s (boost), lower-is-better x%s; Power x%s and x%s. They match all 48 live Piercer variant modules exactly." % (
        fmt(policy["LightweightEngineHigherMultiplier"]), fmt(policy["LightweightStabilisersHigherMultiplier"]), fmt(policy["LightweightBoostHigherMultiplier"]),
        fmt(policy["LightweightLowerBetterMultiplier"]), fmt(policy["PowerHigherMultiplier"]), fmt(policy["PowerLowerBetterMultiplier"])))
    add("")

    # 6 ----------------------------------------------------------------
    add("## 6. Body modules")
    add("")
    add("Size is the live accessory LVL1 size (live LVL1: 1 or 2 per stat and `Weight` 2). Each stat is written as the raw attribute and its `PerformanceDelta_` twin, as on the live accessories.")
    add("")
    add("Rule: the six styles of a slot are worth about the same on every cockpit, so the price steps are prestige only. Two things make that hold:")
    add("")
    add("- **No body part carries `Drag`.** A flat Drag value cannot be worth the same on every tier. Gull's stock `Drag` is %s against a minimum of 1, so +1 Drag costs Gull %.1f PI, while it costs %.1f PI or less on every other cockpit. The live LVL1 accessories carry no Drag either. A draggy shape is a small `TopSpeed` penalty; a slippery shape is `TopSpeed`." % (
        fmt(design["exotic_06"]["totals"]["Drag"], 3), -analysis["drag_plus_one"]["exotic_06"],
        under(max(-analysis["drag_plus_one"][c["id"]] for c in COCKPITS[:5]))))
    add("- **Each part mixes stats that gain value with tier and stats that lose it.** `EngineOutput` and `BrakingForce` are worth relatively more on fast cockpits; `HoverStability`, `DriftControl` and `Downforce` relatively more on slow ones.")
    add("")
    add("Measured below: the PI spread between the six styles of a slot is at most %.2f on Spider and at most %.2f on the other five cockpits." % (
        max(max(analysis["body"][slot][kit]["exotic_01"]["UnroundedPerformanceIndex"] for kit in range(1, 7))
            - min(analysis["body"][slot][kit]["exotic_01"]["UnroundedPerformanceIndex"] for kit in range(1, 7)) for slot in BODY_ORDER),
        max(max(analysis["body"][slot][kit][c["id"]]["UnroundedPerformanceIndex"] for kit in range(1, 7))
            - min(analysis["body"][slot][kit][c["id"]]["UnroundedPerformanceIndex"] for kit in range(1, 7)) for slot in BODY_ORDER for c in COCKPITS[1:])))
    add("")
    for slot in BODY_ORDER:
        donor_id = BODY_SLOTS[slot][1]
        donor = live.modules[donor_id]["attributes"]
        add("### %s (`%s`, donor `%s`: %s)" % (RAIL_LABEL[slot], slot, donor_id, stat_summary(donor)))
        add("")
        rows = []
        for cockpit in COCKPITS:
            n = cockpit["n"]
            part_id = module_id(BODY_SLOTS[slot][0], n)
            attributes = modules[part_id]["attributes"]
            swap = analysis["body"][slot][n]
            flavour = BODY_STATS[slot][n][0].split(": ", 1)[1]
            rows.append(["`%s`" % part_id, attributes["DisplayName"], fmt(attributes["Price"]), flavour, stat_summary(attributes),
                         swap[RATING_REFERENCE_COCKPIT_ID]["PerformanceIndex"]] + [swap[item["id"]]["PerformanceIndex"] for item in COCKPITS])
        add(table(["ModuleId", "Name", "Price", "Flavour", "Raw stats", "Card rating (on `exotic_03`)"] + ["On %s" % item["tier"] for item in COCKPITS], rows))
        add("")
        spread = []
        for item in COCKPITS:
            values = [analysis["body"][slot][kit][item["id"]]["UnroundedPerformanceIndex"] for kit in range(1, 7)]
            spread.append("%s %.2f" % (item["tier"], max(values) - min(values)))
        add("PI spread between the six styles, per tier: %s." % ", ".join(spread))
        add("")
    add("\"Card rating\" is the module card rating after Stage A (`RatingReferenceCockpitId=exotic_03`): the PI of a stock Wedge with that part swapped in. \"On E\" to \"On S\" is the PI of the stock cockpit of that tier with only this part swapped (its own part gives its stock PI).")
    add("")
    add("Sum of the six parts of each kit:")
    add("")
    rows = []
    for name in R.RAW_ORDER:
        values = [sum(modules[module_id(BODY_SLOTS[slot][0], n)]["attributes"][name] for slot in BODY_ORDER) for n in range(1, 7)]
        if any(values):
            rows.append([name] + [fmt(value) for value in values])
    add(table(["Stat"] + ["Kit %d %s" % (cockpit["n"], cockpit["kit_name"]) for cockpit in COCKPITS], rows))
    add("")

    # 7 ----------------------------------------------------------------
    add("## 7. Variant sets and upgrades")
    add("")
    add("Exotic rows keep the cockpit's own six body parts unless the column says otherwise. \"Max upgrades\" spends upgrade points for the highest PI found (a point that lowers PI is not bought). Piercer rows are the nearest like-for-like build.")
    add("")

    def cell(result):
        return "%s %d" % (result["Overall"]["Tier"], result["Overall"]["PerformanceIndex"])

    rows = []
    for cockpit in COCKPITS:
        e = analysis["exotic"][cockpit["id"]]
        rows.append([
            "**%s %s**" % (cockpit["id"], cockpit["name"]), cell(e["STANDARD"]), cell(e["NO_OPTIONAL_BODY"]),
            cell(e["LIGHTWEIGHT"]), cell(e["POWER"]), cell(e["STANDARD_MAX"][0]), cell(e["LIGHTWEIGHT_MAX"][0]),
            cell(e["POWER_MAX"][0]), cell(e["ANY_MAX"][0]), cell(e["ANY_CEILING"]),
        ])
        p = analysis["piercer"][cockpit["piercer"]]
        rows.append([
            "%s %s" % (cockpit["piercer"], live.cockpits[cockpit["piercer"]]["attributes"]["DisplayName"]),
            "%s (with four LVL1: %s)" % (cell(p["STANDARD"]), cell(p["STANDARD_LVL1"])), "stock has no body parts",
            cell(p["LIGHTWEIGHT"]), cell(p["POWER"]), cell(p["STANDARD_LVL1_MAX"][0]) + " (four LVL1)",
            cell(p["LIGHTWEIGHT_MAX"][0]) + " (four LVL3)", cell(p["POWER_MAX"][0]) + " (four LVL3)",
            cell(p["ANY_MAX"][0]), cell(p["ANY_CEILING"]),
        ])
    add(table(["Cockpit", "Stock", "Four optional body parts removed", "All Lightweight", "All Power", "Standard, max upgrades",
               "All Lightweight, max upgrades", "All Power, max upgrades", "Highest build found", "Ceiling"], rows))
    add("")
    add("- **Highest build found**: any own-family variant in each core slot, any kit's part in each body slot (Piercer: any accessory level), the four optional slots may be empty, any upgrade allocation. It is a search (best choice per slot in turn, then one upgrade step on two slots at once, until neither helps; %d start points that are the same on every run), not a proof that nothing higher exists." % SEARCH_STARTS)
    add("- **Ceiling**: a rating no build from the same choices can beat. Every choice of one module (or empty) per slot is rated, and each module takes, for every stat on its own, the best value any of its upgrade allocations offers. The module choice is exact; only the upgrade points are relaxed, so no real build reaches it. It is the proof for the tier statement below. (Since 2026-10-03. Before, the best value per stat was also taken across the modules of a slot: a looser bound, which gave Hyper A 849 with six default body parts and would give S 852 now that the Hyper cockpit absorbs three of them.)")
    add("")

    def picks(components):
        text = ""
        for component in components:
            this_id = component["attributes"]["ModuleId"]
            if this_id.startswith("(empty"):
                text += "-"
            elif this_id.rsplit("_", 1)[1] in VARIANTS:
                text += this_id.rsplit("_", 1)[1][0]
            else:
                text += this_id[-1]
        return text[:4] + " " + text[4:]

    add("Highest build found, as core variants (Main Turbine, Side Engines, Stabilisers, Afterburner: S, L or P) then kits (Nose, Deck, Pods, Splitter, Diffuser, Wing; `-` is empty): " + "; ".join(
        "%s %s" % (cockpit["id"], picks(analysis["exotic"][cockpit["id"]]["ANY_MAX"][3])) for cockpit in COCKPITS) + ".")
    add("")
    add("Tier reached, stock to highest found, with the ceiling tier in brackets: " + "; ".join(
        "%s %s to %s (%s), Piercer %s to %s (%s)" % (
            cockpit["name"], cockpit["tier"], analysis["exotic"][cockpit["id"]]["ANY_MAX"][0]["Overall"]["Tier"],
            analysis["exotic"][cockpit["id"]]["ANY_CEILING"]["Overall"]["Tier"],
            analysis["piercer"][cockpit["piercer"]]["STANDARD"]["Overall"]["Tier"],
            analysis["piercer"][cockpit["piercer"]]["ANY_MAX"][0]["Overall"]["Tier"],
            analysis["piercer"][cockpit["piercer"]]["ANY_CEILING"]["Overall"]["Tier"])
        for cockpit in COCKPITS) + ".")
    add("")
    proven = all("EDCBAS".index(analysis["exotic"][cockpit["id"]]["ANY_CEILING"]["Overall"]["Tier"])
                 <= "EDCBAS".index(analysis["piercer"][cockpit["piercer"]]["ANY_MAX"][0]["Overall"]["Tier"]) for cockpit in COCKPITS)
    add("No Exotic cockpit can reach a higher tier than the Piercer of its tier reaches today: %s." % (
        "every Exotic ceiling is inside the tier its Piercer reaches, so this is proven for own-family core modules and all 36 body parts (the twelve GT and EVO ids of the mesh kits carry the stats and upgrade paths of their base part, so they are covered)" if proven
        else "NOT proven by the ceiling for every cockpit; only the search supports it"))
    add("")

    # 8 ----------------------------------------------------------------
    add("## 8. Cross-kit mixes")
    add("")
    add("Each cockpit keeps its own four Standard core modules and wears the six body parts of one kit:")
    add("")
    rows = []
    for cockpit in COCKPITS:
        mix = analysis["mix"][cockpit["id"]]
        rows.append(["%s %s (%s, target %d)" % (cockpit["id"], cockpit["name"], cockpit["tier"], cockpit["target"])]
                    + ["%s %d" % (mix["whole"][kit]["Tier"], mix["whole"][kit]["PerformanceIndex"]) for kit in range(1, 7)])
    add(table(["Cockpit"] + ["Kit %d %s" % (cockpit["n"], cockpit["kit_name"]) for cockpit in COCKPITS], rows))
    add("")
    add("No cockpit moves more than %d PI in any whole kit." % max(
        abs(analysis["mix"][cockpit["id"]]["whole"][kit]["PerformanceIndex"] - cockpits[cockpit["id"]]["stockPI"]) for cockpit in COCKPITS for kit in range(1, 7)))
    add("")
    add("Best and worst part per slot (all 46,656 combinations checked per cockpit):")
    add("")
    rows = []
    for cockpit in COCKPITS:
        mix = analysis["mix"][cockpit["id"]]
        best_pi = R._luau_round(R._rounded(mix["best"][0], 2))
        worst_pi = R._luau_round(R._rounded(mix["worst"][0], 2))
        rows.append([cockpit["id"], cockpit["tier"], cockpits[cockpit["id"]]["stockPI"],
                     "%d (%+d), tier %s" % (best_pi, best_pi - cockpits[cockpit["id"]]["stockPI"], live.calculator.tier_for_index(best_pi)),
                     "".join(str(index + 1) for index in mix["best"][1]),
                     "%d (%+d), tier %s" % (worst_pi, worst_pi - cockpits[cockpit["id"]]["stockPI"], live.calculator.tier_for_index(worst_pi)),
                     "".join(str(index + 1) for index in mix["worst"][1])])
    add(table(["Cockpit", "Tier", "Stock PI", "Best mix", "Kits used (Nose, Deck, Pods, Splitter, Diffuser, Wing)", "Worst mix", "Kits used"], rows))
    add("")
    swap = analysis["family_swap"]
    add("Core modules are a different matter, and behave as on Piercer. A player who owns both cockpits can fit the top family's core set on the cheapest cockpit: Spider with the Gull Standard set rates %s %d (Power set: %s %d). Live Piercer today: Forge with the Zenith Standard set rates %s %d (Power set: %s %d)." % (
        swap["exotic"]["Tier"], swap["exotic"]["PerformanceIndex"], swap["exotic_power"]["Tier"], swap["exotic_power"]["PerformanceIndex"],
        swap["piercer"]["Tier"], swap["piercer"]["PerformanceIndex"], swap["piercer_power"]["Tier"], swap["piercer_power"]["PerformanceIndex"]))
    add("")

    # 9 ----------------------------------------------------------------
    add("## 9. Cost of a full build")
    add("")
    add("Stock = the cockpit price (four Standard core modules and the six signature body parts are granted with it). Upgrade cost is the cash for the max-PI allocation of section 7, under the live rule in `PerformanceUpgradeRuntime.NextPointCost` (the charge is the guide for the next point on that path).")
    add("")
    rows = []
    for cockpit in COCKPITS:
        e = analysis["exotic"][cockpit["id"]]
        variant_price = cockpit["price"] * 12 // 100
        power_total = cockpit["price"] + 4 * variant_price + e["POWER_MAX"][2]
        p = analysis["piercer"][cockpit["piercer"]]
        piercer_price = live.cockpits[cockpit["piercer"]]["attributes"]["Price"]
        piercer_total = piercer_price + 4 * (piercer_price * 12 // 100) + 4 * 19000 + p["POWER_MAX"][2]
        rows.append([cockpit["id"], fmt(cockpit["price"]), fmt(e["STANDARD_MAX"][2]), fmt(4 * variant_price), fmt(e["POWER_MAX"][2]),
                     fmt(power_total), "%s %d" % (e["POWER_MAX"][0]["Overall"]["Tier"], e["POWER_MAX"][0]["Overall"]["PerformanceIndex"]),
                     fmt(piercer_total), "%+.1f%%" % ((power_total / piercer_total - 1) * 100), fmt(6 * BODY_PRICE_BY_KIT[-1])])
    add(table(["Cockpit", "Stock (cockpit)", "Upgrades on the stock build", "Four Power modules", "Upgrades on the Power build (ten modules)",
               "Full Power build", "PI", "Piercer full Power build (four LVL3 accessories)", "Exotic over Piercer", "Optional: dearest foreign body kit (six parts)"], rows))
    add("")
    add("- The Piercer figure includes four LVL3 accessories at 19,000 each. The Exotic body parts come with the cockpit, which is why the Spider build is cheaper than the Forge build.")
    add("- Body and Standard upgrade guides do not scale with the cockpit (live pattern). On Spider a Standard engine point (6,050) costs more than a Lightweight engine (6,000). Forge has the same pattern today (4,800).")
    add("- A full Lightweight build costs the same as a full Power build apart from the upgrade choice. Neon is extra: `NeonPrice` per module.")
    add("")

    # 10 ---------------------------------------------------------------
    add("## 10. Upgrade paths")
    add("")
    add("Live `PathId`s in the capture (%d): %s." % (len(live.live_path_ids), ", ".join("`%s`" % item for item in live.live_path_ids)))
    add("")
    add("Core modules clone the paths of the live Piercer module of the same type, variant and tier position (`upgradePathDonor`). All 72 live core modules of one type carry identical paths, so the tier choice changes nothing today.")
    add("")
    rows = []
    for cockpit in COCKPITS:
        rows.append([cockpit["id"], cockpit["piercer"]] + ["`%s`" % modules[module_id(CORE_SLOTS[slot][0], cockpit["n"], "STANDARD")]["upgradePathDonor"].replace("_STANDARD", "_<VARIANT>") for slot in CORE_ORDER])
    add(table(["Family", "Piercer tier match", "Engine1", "Engine2", "Stabilisers", "Boost"], rows))
    add("")
    add("Body modules of the four existing slots clone the live LVL1 accessory paths: Side Pods `MODULE_SIDEPODS_LVL1`, Splitter `MODULE_FRONTBUMPER_LVL1`, Diffuser `MODULE_REARBUMPER_LVL1`, Wing `MODULE_REARSPOILER_LVL1`.")
    add("")
    add("New paths for the two new slots (explicit `upgradePaths`, the same on all six parts of the slot). **These `PathId`s are new saved keys.** None is a live `PathId`, a legacy upgrade id or a category `UPGRADE_*` id.")
    add("")
    rows = []
    for slot in ("FrontBody", "RearBody"):
        for path_id, display_name, order, deltas in NEW_UPGRADE_PATHS[slot]:
            rows.append([slot, "`%s`" % path_id, display_name, order, 3, ", ".join("`DeltaFlat_%s` %s%s" % (stat, "+" if delta > 0 else "", fmt(delta)) for stat, delta in deltas.items())])
    add(table(["Slot", "PathId (folder name)", "DisplayName", "Order", "MaxPoints", "Per point"], rows))
    add("")
    add("Each path folder carries `PathId`, `DisplayName`, `MaxPoints`, `Order` and the `DeltaFlat_` attributes, the same set as the live accessory paths. The folder must be named by its `PathId`: the live `NextPointCost` finds a path by folder name. The live runtime sorts paths by `PathId`, not by `Order`. `scripts/performance_phase3/catalogue.py` already projects `DeltaFlat_` for all 17 stats, so the new deltas reach the client data.")
    add("")
    add("What three points on one body path are worth: PI change on each stock cockpit (unrounded), and the cash for the three points.")
    add("")
    rows = []
    for slot in BODY_ORDER:
        for this_id, entry in analysis["path_worth"][slot].items():
            rows.append([RAIL_LABEL[slot], "`%s`" % this_id, "new" if entry["new"] else "cloned",
                         ", ".join("%s %s%s" % (stat, "+" if delta > 0 else "", fmt(delta)) for stat, delta in sorted(entry["deltas"].items())),
                         fmt(entry["cost"])] + ["%+.2f" % entry["gain"][cockpit["id"]] for cockpit in COCKPITS])
    add(table(["Slot", "PathId", "Source", "Per point", "Cash"] + ["%s %s" % (cockpit["tier"], cockpit["name"]) for cockpit in COCKPITS], rows))
    add("")
    add("- The six new paths gain PI on every cockpit. No new path carries `Drag` (section 6). `LightweightNose` and `LightweightDeck` carry a second stat because Hyper and Gull sit on the `Weight` minimum of 60, where a weight cut alone is worth nothing in the rating or on the road. The second stat follows the legacy `VehicleUpgradeDefinitions` (Lightweight Internals: `Weight` and `SteeringResponse` +1; Lightweight Arms: `Weight` and `DriftGrip` +1).")
    add("- Everything is small on Gull: the index curve is nearly flat at S.")
    add("- The cloned paths are the live Piercer paths, unchanged. Their odd rows are flagged in section 12.")
    add("")

    # 11 ---------------------------------------------------------------
    add("## 11. Attribute sets")
    add("")
    add("Every module in `balance.json` carries every attribute name of its live donor, plus the two opt-in attributes from INTERFACE.md (`CardTitle` = `DisplayName`, `RatingReferenceCockpitId` = `exotic_03`). The build fails if a donor attribute has no rule.")
    add("")
    for label, donor_id in [("Engine1 Standard", "MODULE_ENGINE_BRUISER_03_STANDARD"), ("Engine2 Standard", "MODULE_ENGINE_B_BRUISER_03_STANDARD"),
                            ("Stabilisers Standard", "MODULE_STABILISER_BRUISER_03_STANDARD"), ("Boost Standard", "MODULE_BOOST_BRUISER_03_STANDARD"),
                            ("Body (all six slots)", "MODULE_FRONTBUMPER_LVL1")]:
        names = sorted(live.modules[donor_id]["attributes"])
        add("- %s, donor `%s`, %d attributes: %s." % (label, donor_id, len(names), ", ".join("`%s`" % name for name in names)))
    add("- Lightweight and Power donors (`..._BRUISER_03_LIGHTWEIGHT`, `..._POWER`) add `Point3CostGuide` to `Point6CostGuide` and have no `MaxPointsPerPath`. The Exotic variants follow that.")
    add("- The four accessory donors carry the same 68 names.")
    add("")
    add("How each donor attribute gets its Exotic value:")
    add("")
    add(table(["Attributes", "Core modules", "Body modules"], [
        ["17 raw stats", "share of the stock total; variants by multiplier", "the flavour table in section 6"],
        ["`PerformanceDelta_*`", "0, as on the donor", "equal to the raw stat, as on the donor"],
        ["`Acceleration`, `Boost`, `Braking`, `Drift`, `Handling`, `Power` (legacy)", "copied from the donor of the same type and variant (constant across the six live families)",
         "`Acceleration` = `EngineOutput`, `Braking` = `BrakingForce`, `Handling` = mean of the three handling stats, `Drift` = mean of the three drift stats, rounded half up; `Boost` and `Power` 0. This reproduces all four live LVL1 donors"],
        ["`ModuleId`, `V2PublishedModuleId`", "INTERFACE.md id", "INTERFACE.md id (no `V2PublishedModuleId` on the donor)"],
        ["`DisplayName`, `ModuleName`", "spec display name, the same on the three variants", "spec display name"],
        ["`CategoryId`", "`exotic`", "`exotic`"],
        ["`ModuleFolder`, `ModuleType`, `ModuleSlot`, `EnginePosition`, `RearEngine`", "INTERFACE.md", "folder from INTERFACE.md; type and slot = slot id"],
        ["`SourceCockpitId`", "`exotic_0N`", "absent, as on the donor"],
        ["`SourceCockpitDisplayName` (engines only)", "the cockpit `DisplayName` (live value is the placeholder \"Bruiser Origin\")", "absent"],
        ["`Price`, `PurchasePrice`", "0 / 12% of the cockpit price", "`Price` by kit; no `PurchasePrice`"],
        ["`NeonPrice`", "5,000 / 6,500 / 8,000", "by kit"],
        ["`PointNCostGuide`, `UpgradePointCapacity`, `MaxPointsPerPath`, `UpgradePrice`", "section 2", "copied from the donor"],
        ["`Tier`, `VariantName`, `VariantOrder`", "Standard / Lightweight / Power, 10 / 20 / 30", "`Tier` = kit name (label only, not read); no `VariantName` or `VariantOrder`, as on the donor"],
        ["`Level`, `MaxLevel`, notes, flags (`BalanceEditable`, `BalanceNote`, `BoostNotes`, `CatalogPublishReady`, `CatalogVisible`, `HiddenFromCatalog`, `RetiredFromCatalog`, `Upgradable`, `TemplateType`, `PreviewImage`, `V2*`)", "copied from the donor", "copied from the donor"],
    ]))
    add("")
    cockpit_names = sorted(cockpits["exotic_01"]["attributes"])
    add("Cockpits carry the %d non-colour attributes of the live Piercer cockpit plus the six new `Default<Slot>ModuleId` names (%d in all): %s." % (
        len(cockpit_names) - 6, len(cockpit_names), ", ".join("`%s`" % name for name in cockpit_names)))
    add("")
    add("The mesh cockpits `exotic_02` and `exotic_05` carry three of the six new names (`DefaultFrontBodyModuleId`, `DefaultRearBodyModuleId`, `DefaultRearSpoilerModuleId`; %d attributes in all): a slot that starts empty has no default attribute." % len(cockpits["exotic_02"]["attributes"]))
    add("")
    add("Not in `balance.json`: the six `Default*Color` attributes (Color3, a paint decision) and the seat offsets. `MenuImage` and `PreviewImage` are empty strings. Legacy cockpit values `Acceleration=70`, `Handling=30`, `Drift=0`, `Braking=100`, `Boost=0`, `Power=40` are the constants on all six live cockpits.")
    add("")

    # 12 ---------------------------------------------------------------
    add("## 12. Things to know (flags)")
    add("")
    e6 = design["exotic_06"]
    hyper = analysis["exotic"]["exotic_05"]
    rally = analysis["piercer"]["bruiser_05"]
    spider = analysis["exotic"]["exotic_01"]
    worth = analysis["path_worth"]
    lowest_fraction = min(
        (design[c["id"]]["cockpit_raw"][name] / (design[c["id"]]["totals"][name] * live.shares[name]["Cockpit"]), c["id"], name)
        for c in COCKPITS for name in R.RAW_ORDER if name not in R.LOWER_IS_BETTER)

    def gains(slot, this_id):
        return worth[slot][this_id]["gain"]

    dead = []
    harmful = []
    for slot in BODY_ORDER:
        for this_id, entry in worth[slot].items():
            zero = [c["name"] for c in COCKPITS if abs(entry["gain"][c["id"]]) < 0.005]
            down = ["%s %.1f" % (c["name"], entry["gain"][c["id"]]) for c in COCKPITS if entry["gain"][c["id"]] <= -0.005]
            assert not (entry["new"] and (zero or down)), "a new path is worthless or harmful: " + this_id
            if zero:
                dead.append("%s `%s` on %s" % (RAIL_LABEL[slot], this_id, " and ".join(zero)))
            if down:
                harmful.append("%s `%s` (%s)" % (RAIL_LABEL[slot], this_id, ", ".join(down)))
    mixes = [(R._luau_round(R._rounded(analysis["mix"][c["id"]]["best"][0], 2)) - cockpits[c["id"]]["stockPI"],
              R._luau_round(R._rounded(analysis["mix"][c["id"]]["worst"][0], 2)) - cockpits[c["id"]]["stockPI"]) for c in COCKPITS]
    flags = [
        "**Weight cannot go lighter at the top.** The technical minimum is 60. Zenith is already at 60 and Rally at 61, so Gull equals Zenith (60) and Hyper is 1 lighter than Rally (60). The other four are 10 to 12 percent lighter than their Piercer.",
        "**Gull needed a larger scale (%.3f; the others %.3f to %.3f).** At S tier `Weight` and `BoostRecharge` are pinned at their minimum and the index curve is flat, so the other stats carry the 13 points over Zenith. Gull `TopSpeed` is %s against Zenith 360." % (
            e6["scale"], min(design[c["id"]]["scale"] for c in COCKPITS[:5]), max(design[c["id"]]["scale"] for c in COCKPITS[:5]), fmt(e6["totals"]["TopSpeed"])),
        "**Curve shares three totals with Spider.** `Weight`, `Drag` and `BoostRecharge` are equal on the E and D cockpits (section 3), as they are on Forge and Vector. Every other stat rises with the tier.",
        "**Gull is sensitive to Drag.** Its stock `Drag` is %s (minimum 1). +1 Drag costs it %.1f PI (Hyper %.2f, the rest %.2f or less). The live Zenith (`Drag` 1.475) has the same sensitivity. It is a rating effect only: the road drag factor is clamped at 0.65, which is reached at Drag 16.9 (runtime.md 7.4, read from source, not measured)." % (
            fmt(e6["totals"]["Drag"], 3), -analysis["drag_plus_one"]["exotic_06"], -analysis["drag_plus_one"]["exotic_05"],
            max(-analysis["drag_plus_one"][c["id"]] for c in COCKPITS[:4])),
        "**So nothing authored here carries Drag.** No body part and no new upgrade path has a Drag value. With that, any whole kit and any mix of parts moves a stock build by %+d to %+d PI at most (section 8)." % (
            min(low for _, low in mixes), max(high for high, _ in mixes)),
        "**The cloned accessory paths still carry Drag, as on Piercer.** Splitter, Diffuser, Wing and Side Pods clone the live LVL1 paths, as the brief asks. On a stock Gull three points of `FrontSplitter` cost %.1f PI, `RearDiffuser` %.1f, `DownforcePackage` %.1f and `DriftAero` %.1f, while `LowDragProfile` gains %.1f and `AirflowChannels` %.1f. Once `LowDragProfile` is bought (Drag -9) the total sits on the minimum and the other paths stop costing. Zenith with LVL accessories behaves the same today. Decision for Oscar: keep the clones, or give the four slots Exotic paths without Drag (`balance.json` allows explicit `upgradePaths` on any module)." % (
            -gains("FrontBumper", "FrontSplitter")["exotic_06"], -gains("RearBumper", "RearDiffuser")["exotic_06"],
            -gains("RearSpoiler", "DownforcePackage")["exotic_06"], -gains("RearSpoiler", "DriftAero")["exotic_06"],
            gains("RearSpoiler", "LowDragProfile")["exotic_06"], gains("SidePods", "AirflowChannels")["exotic_06"]),
        "**Cloned paths that are worth nothing at stock:** %s. These are pure `Weight` cuts on cockpits already at the 60 minimum, so they do nothing in the rating or on the road. Live Zenith has the same. The two new weight paths avoid it with a second stat (section 10)." % ("; ".join(dead) if dead else "none"),
        "**Cloned paths that lower PI at stock:** %s. The Splitter `LightweightMounts` trades `BrakingForce` -1 for `Weight` -3, which is a loss where weight is cheap. Live pattern, not changed." % ("; ".join(harmful) if harmful else "none"),
        "**Hyper stays in A.** A fully upgraded Hyper tops out at %s %d (highest build found: %s %d). The ceiling no Hyper build can beat is %s %d, under the S band at 850. Rally tops out at %s %d." % (
            hyper["POWER_MAX"][0]["Overall"]["Tier"], hyper["POWER_MAX"][0]["Overall"]["PerformanceIndex"],
            hyper["ANY_MAX"][0]["Overall"]["Tier"], hyper["ANY_MAX"][0]["Overall"]["PerformanceIndex"],
            hyper["ANY_CEILING"]["Overall"]["Tier"], hyper["ANY_CEILING"]["Overall"]["PerformanceIndex"],
            rally["ANY_MAX"][0]["Overall"]["Tier"], rally["ANY_MAX"][0]["Overall"]["PerformanceIndex"]),
        "**Exotic has two more upgradable slots than Piercer** (12 more points per build). The lower tiers cross one tier band with a full Power set and all upgrades, as Piercer does today (section 7).",
        "**A stock Exotic can be upgraded without buying anything else.** Its six body parts each take six points, so a Standard Spider reaches %s %d on upgrades alone. A stock Piercer has no body parts to upgrade; with four LVL1 accessories Forge reaches %s %d." % (
            spider["STANDARD_MAX"][0]["Overall"]["Tier"], spider["STANDARD_MAX"][0]["Overall"]["PerformanceIndex"],
            analysis["piercer"]["bruiser_02"]["STANDARD_LVL1_MAX"][0]["Overall"]["Tier"], analysis["piercer"]["bruiser_02"]["STANDARD_LVL1_MAX"][0]["Overall"]["PerformanceIndex"]),
        "**Body parts are worth more on cheap cockpits.** The same flat stat is a bigger share of an E tier total. Removing the four optional parts drops Spider to %d but Gull only to %d (section 7). The styles of a slot are still worth the same as each other on each cockpit." % (
            spider["NO_OPTIONAL_BODY"]["Overall"]["PerformanceIndex"], analysis["exotic"]["exotic_06"]["NO_OPTIONAL_BODY"]["Overall"]["PerformanceIndex"]),
        "**Cockpit raw values are lower than a Piercer cockpit's.** The body parts carry part of the cockpit share. The smallest remainder is %s `%s` at %.0f%% of its share. No value is negative." % (
            lowest_fraction[1], lowest_fraction[2], lowest_fraction[0] * 100),
        "**Dealership rating depends on Stage A.** Until `VehiclePerformanceResolver` counts the six body defaults, the dealership shows less than the stock PI (at most the \"optional body parts removed\" figure).",
        "**Extra Standard copies.** With `Price=0` and `PurchasePrice=0` the live `modulePurchasePrice` charges 12% of the source cockpit price, looked up in category `bruiser` (`GarageCatalogLookup` line 123). Stage A changes that lookup to the module's own category. Without it an extra Exotic Standard copy would cost 1,000.",
        "**`Point4CostGuide` to `Point6CostGuide` are never charged live.** `NextPointCost` is always called with a path id and uses the next point on that path (1 to 3). This is live behaviour for Piercer too. Reported, not changed. The guides are still written, as on the donors.",
        "**Three variants share one `DisplayName`** (INTERFACE.md: the spec display name). Any text that shows only the name cannot tell Standard from Power.",
        "**Road feel is not proven by the rating.** `VehicleDynamics` clamps most stats (runtime.md 7.4), so the top tiers differ less on the road than in PI. Raw `TopSpeed` barely moves road speed in the live tuning, so the slippery and draggy body flavours are rating flavours first. Check in Play.",
        "**`OwnedByDefault=true`** is copied from the live cockpits. No live script reads it.",
        "**`TargetStockPI` on Forge and Vector** is 200 and 375 live, but they compute to 202 and 374. Unrelated to Exotic. Reported, not changed.",
    ]
    for flag in flags:
        add("- " + flag)
    add("")

    # 13 ---------------------------------------------------------------
    add("## 13. For the content builder")
    add("")
    add("Seat-independent facts needed from this folder: none beyond `balance.json`.")
    add("")
    add("- `cockpits[id].attributes`: every attribute to set except the six `Default*Color` values and the seat offsets. Booleans are JSON booleans.")
    add("- `modules[id].attributes`: the full attribute set. `modules[id]` has **either** `upgradePathDonor` (clone that live module's `VehiclePerformanceV2UpgradePaths` folder) **or** `upgradePaths` (create one Folder per entry, named by `PathId`, with the listed attributes). Never both.")
    add("- Numbers are plain decimals with at most six places. None prints as an exponent, `inf`, `nan` or `-0`.")
    add("")
    # 14 ---------------------------------------------------------------
    add("## 14. Readings of INTERFACE.md, deviations and what is not verified")
    add("")
    add("Deviations and readings:")
    add("")
    for item in [
        "**Weight at A and S tier.** INTERFACE.md asks for a lighter `Weight` than the Piercer of the same tier. The live technical minimum is 60, so Hyper is 60 (Rally 61) and Gull is 60 (Zenith 60).",
        "**Floor rule.** \"No cockpit raw value below the technical minimum\" is applied to the cockpit for higher-is-better stats, and to the stock total for `Weight`, `BoostRecharge`, `BoostRechargeDelay` and `Drag`. A literal reading cannot be met: live Piercer cockpits already sit under those minimums (Zenith cockpit `Weight` 42, `BoostRecharge` 1.4).",
        "**Attribute values beyond numbers and strings.** INTERFACE.md says \"every numeric and string attribute\". Booleans from the donors are included too (for example `RearEngine`, `V2Materialised`). Color3 values are not.",
        "**Opt-in attributes included.** `CardTitle` and `RatingReferenceCockpitId` are in every module's attributes with the INTERFACE.md values, so the file is the whole attribute set.",
        "**Either/or.** A module entry has `upgradePathDonor` or `upgradePaths`, never both and never a null.",
        "**`MaxPointsPerPath` on variants.** Absent on Lightweight and Power, as on the live donors (INTERFACE.md names it for Standard only).",
        "**Engine split.** The design note \"Main Turbine leans on top speed, Side Engines on acceleration\" is not applied. Both engines carry the same numbers, as the live allocation policy and the task require.",
        "**No Drag on body parts.** The brief gives \"a long tail lowers drag\" as an example flavour. It is written as `TopSpeed` instead (Streamer Tail `TopSpeed` +3), because a flat Drag value breaks the rule that every style in a slot has similar value (section 6). This also drops the small negative Drag values the first build carried: -0.5 Drag was worth 1.5 PI on Gull and under 0.2 PI elsewhere, and Gull's own deck carried -0.5, so a deck without Drag cost Gull 1.7 PI.",
        "**Ladder rule.** A lower-is-better total is never worse than on the tier below (section 3). The brief does not ask for it; without it the D cockpit was heavier and draggier than the E cockpit.",
        "**New weight paths carry a second stat** (section 10), so a point is never worthless on the two cockpits at the `Weight` minimum.",
    ]:
        add("- " + item)
    add("")
    add("Not verified:")
    add("")
    for item in [
        "The port was not run against the live Luau modules (no gameplay module may be required through MCP). It reproduces the six Piercer stock ratings found independently in ui.md, and the source hashes match.",
        "Nothing was installed or driven. On-road speed, feel and the possible runtime double count (runtime.md 9.1) are open for Play.",
        "The dealership rating, the module card rating and the price of an extra Standard copy depend on Stage A code that other builders are writing.",
        "\"Similar overall value\" is measured as PI. Two parts with the same PI can still feel different.",
        "The \"highest build found\" column is a search. The tier statement in section 7 rests on the ceiling, which is a bound, and covers own-family core modules only (a player who owns two cockpits can move core sets between them: section 8).",
        "`test_balance.py` was run with `py -3` only. Its tests are plain `test_*` functions without fixtures, but pytest is not installed here, so a pytest run is not verified.",
    ]:
        add("- " + item)
    add("")
    REPORT_PATH.write_text("\n".join(L) + "\n", encoding="ascii", newline="\n")


def dump_balance(balance):
    return json.dumps(balance, indent=1, ensure_ascii=True) + "\n"


def main():
    balance, design, reductions, live = build()
    BALANCE_PATH.write_text(dump_balance(balance), encoding="ascii", newline="\n")
    analysis = analyse(balance, design, live)
    write_report(balance, design, reductions, live, analysis)
    print("wrote", BALANCE_PATH.relative_to(REPO).as_posix(), "(%d cockpits, %d modules)" % (len(balance["cockpits"]), len(balance["modules"])))
    print("wrote", REPORT_PATH.relative_to(REPO).as_posix())
    for cockpit in COCKPITS:
        entry = balance["cockpits"][cockpit["id"]]
        print("  %s %-8s target %d stock %s %d" % (cockpit["id"], cockpit["name"], cockpit["target"], entry["stockTier"], entry["stockPI"]))
    if reductions:
        print("  body stats lowered by the floor rule:", reductions)


if __name__ == "__main__":
    main()
