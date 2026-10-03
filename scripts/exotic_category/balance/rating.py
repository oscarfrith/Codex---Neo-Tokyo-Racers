"""Python port of the live Space Racers V2 performance rating.

Ported line by line from these live sources (blobs named in the baseline capture
roblox/captures/exotic-before/capture.json, place 133417340424236):

  ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceCalculator
  ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceDefinitions
  ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceRuntime
      (ReadComponentRaw, CalculateComponents)
  ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceUpgradeRuntime
      (NormalizeAllocation, ApplyToModuleRaw, NextPointCost)
  ReplicatedStorage.Modules.Game.Vehicles.VehicleDefinition

Config values are never typed in here. They are read from the capture hierarchy
(ReplicatedStorage.Config.Vehicles.Performance) and merged over the code defaults
exactly as PerformanceDefinitions.readAttributes does.

Flow: raw totals -> effective factors -> six headlines -> overall -> PI and tier.

Run this file to print the proof: the six Piercer stock builds recomputed from the
capture attributes (cockpit + its four default Standard modules).

    py -3 scripts/exotic_category/balance/rating.py

How exact it is:

- Finite number attributes (every live and every Exotic value): the same arithmetic
  as the Luau, step for step. The only difference is float summation order inside
  pairs() loops (Luau table order is not defined). That is about 1e-13, and PI is
  rounded to two places and then to an integer, so it does not show.
- Luau `a or b` falls through only on nil and false (0 and "" are kept). The port
  uses lua_or() for every ported `or`, never Python truthiness.
- Luau tonumber() on strings follows C strtod. _tonumber() matches the cases read
  from live Studio on 2026-10-02 (read-only, place 133417340424236): "inf",
  "infinity" and "nan" are numbers, hex ("0x10", "0x1p4") is a number, "1_0", "",
  "5x" and non-ASCII digits are nil.
- math.clamp and math.floor keep NaN as Luau does (_clamp, _floor).
- No live or Exotic attribute is a string, a zero point limit, an empty PathId or
  a non-finite number, so the last three points change no number in this folder.
- Not done: running the port against the live Luau modules (no gameplay module may
  be required through MCP). The proof is the six Piercer stock builds below.
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CAPTURE_PATH = REPO / "roblox" / "captures" / "exotic-before" / "capture.json"

# sha256 of the live sources this port was written against (capture manifest).
PORTED_SOURCES = {
    "ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceCalculator":
        "d91de47730ec7020d61e9d17ced2ba41412d9f2c91ab9d911fa1f364fad64a98",
    "ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceDefinitions":
        "9720b4e33a72403abfe69fbf165f8503d8b5620ef39aa46e5df57ed1894edd28",
    "ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceRuntime":
        "a63c7b8799d11cc81ff220d4c8d492dde908ca63e6b8e08eab503a6f18a8b048",
    "ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceUpgradeRuntime":
        "8eb4b5a64780049896c75c72fe32f2627141ec5934e5e541a5046c38cf30855e",
    "ReplicatedStorage.Modules.Game.Vehicles.VehicleDefinition":
        "d4ca3721612c9b074e2fa6799f54f16d164634fa0e05f92dbc4f0fa500853114",
}

# ---------------------------------------------------------------------------
# PerformanceDefinitions (code defaults; live attributes are merged over them)
# ---------------------------------------------------------------------------

RAW_ORDER = [
    "TopSpeed", "EngineOutput", "Weight", "LateralGrip", "SteeringResponse", "HoverStability",
    "DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostForce", "BoostDuration",
    "BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce",
]

HEADLINE_ORDER = ["Speed", "Acceleration", "Handling", "Drift", "Braking", "Boost"]

DEFAULT_CURVES = {
    "TopSpeed": {"CurveType": "Power", "Reference": 130, "Exponent": 0.55, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "EngineOutput": {"CurveType": "Power", "Reference": 60, "Exponent": 0.75, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "Weight": {"CurveType": "Power", "Reference": 118, "Exponent": 0.35, "TechnicalMinimum": 60, "LowerIsBetter": True},
    "LateralGrip": {"CurveType": "Power", "Reference": 50, "Exponent": 0.55, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "SteeringResponse": {"CurveType": "Power", "Reference": 50, "Exponent": 0.45, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "HoverStability": {"CurveType": "Power", "Reference": 50, "Exponent": 0.35, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "DriftControl": {"CurveType": "Power", "Reference": 50, "Exponent": 0.40, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "DriftGrip": {"CurveType": "Power", "Reference": 50, "Exponent": 0.50, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "DriftChargeRate": {"CurveType": "Power", "Reference": 50, "Exponent": 0.45, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "BrakingForce": {"CurveType": "Power", "Reference": 60, "Exponent": 0.70, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "BoostForce": {"CurveType": "Power", "Reference": 30, "Exponent": 0.55, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "BoostDuration": {"CurveType": "Power", "Reference": 2, "Exponent": 0.45, "TechnicalMinimum": 0.1, "LowerIsBetter": False},
    "BoostRecharge": {"CurveType": "Power", "Reference": 9, "Exponent": 0.50, "TechnicalMinimum": 4, "LowerIsBetter": True},
    "BoostRechargeDelay": {"CurveType": "Power", "Reference": 0.5, "Exponent": 0.35, "TechnicalMinimum": 0.05, "LowerIsBetter": True},
    "BoostEfficiency": {"CurveType": "Power", "Reference": 50, "Exponent": 0.45, "TechnicalMinimum": 0, "LowerIsBetter": False},
    "Drag": {"CurveType": "Power", "Reference": 50, "Exponent": 0.35, "TechnicalMinimum": 1, "LowerIsBetter": True},
    "Downforce": {"CurveType": "Power", "Reference": 50, "Exponent": 0.35, "TechnicalMinimum": 0, "LowerIsBetter": False},
}

DEFAULT_HEADLINE_WEIGHTS = {
    "Speed": {"TopSpeed": 0.70, "Drag": 0.20, "Weight": 0.10},
    "Acceleration": {"EngineOutput": 0.60, "Weight": 0.25, "BoostForce": 0.15},
    "Handling": {"LateralGrip": 0.35, "SteeringResponse": 0.25, "HoverStability": 0.20, "Downforce": 0.10, "Weight": 0.10},
    "Drift": {"DriftControl": 0.35, "DriftGrip": 0.25, "DriftChargeRate": 0.25, "SteeringResponse": 0.15},
    "Braking": {"BrakingForce": 0.60, "LateralGrip": 0.15, "HoverStability": 0.15, "Weight": 0.10},
    "Boost": {"BoostForce": 0.35, "BoostDuration": 0.20, "BoostRecharge": 0.20, "BoostRechargeDelay": 0.10, "BoostEfficiency": 0.15},
}

DEFAULT_OVERALL = {
    "Speed": 0.22, "Acceleration": 0.20, "Handling": 0.20, "Drift": 0.14, "Braking": 0.10, "Boost": 0.14,
    "BaseContribution": 0.925, "BalanceContribution": 0.075, "InteractionBlend": 0.30,
    "RatingScale": 150, "PerformanceIndexMin": 100, "PerformanceIndexMax": 999, "InternalPrecision": 2,
}

DEFAULT_TIER_BANDS = {"E": 100, "D": 300, "C": 450, "B": 600, "A": 725, "S": 850}

LOWER_IS_BETTER = [name for name in RAW_ORDER if DEFAULT_CURVES[name]["LowerIsBetter"]]


# ---------------------------------------------------------------------------
# Capture access
# ---------------------------------------------------------------------------

def _is_number(value):
    """Luau typeof(value) == "number" (a boolean is not a number)."""
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def attr_values(node):
    """Attribute name -> plain value. Color3 and other structured types keep their dict."""
    result = {}
    attributes = node.get("attributes") or {}
    if isinstance(attributes, list):
        return result
    for name, item in attributes.items():
        if "value" in item:
            result[name] = item["value"]
        else:
            result[name] = dict(item)
    return result


def find_child(node, *names):
    for name in names:
        matches = [child for child in node["children"] if child["name"] == name]
        if not matches:
            return None
        node = matches[0]
    return node


class Capture:
    """Read-only view of the baseline capture."""

    def __init__(self, path=CAPTURE_PATH):
        with open(path, encoding="utf-8") as handle:
            self.data = json.load(handle)
        self.roots = {root["path"]: root for root in self.data["hierarchy"]}
        self.performance = find_child(self.roots["ReplicatedStorage.Config"], "Vehicles", "Performance")
        self.categories = find_child(self.roots["ServerStorage.Assets.Vehicles"], "Categories")
        assert self.performance is not None, "Config.Vehicles.Performance missing from capture"
        assert self.categories is not None, "Vehicles.Categories missing from capture"

    # -- config -----------------------------------------------------------
    def config_attributes(self, *names):
        node = find_child(self.performance, *names)
        return attr_values(node) if node is not None else None

    def stock_profiles(self):
        """CockpitId -> the 17 stock totals in Config.Vehicles.Performance.BalancedStockProfiles."""
        root = find_child(self.performance, "BalancedStockProfiles")
        return {child["name"]: attr_values(child) for child in root["children"]}

    # -- vehicles ---------------------------------------------------------
    def cockpits(self, category="PIERCER"):
        root = find_child(self.categories, category, "COCKPITS_ReplaceAssetsHere")
        result = {}
        for child in root["children"]:
            attributes = attr_values(child)
            if "CockpitId" in attributes:
                result[attributes["CockpitId"]] = {"name": child["name"], "attributes": attributes}
        return result

    def modules(self, category="PIERCER"):
        """ModuleId -> {name, folder (names under the modules folder), attributes, paths}."""
        root = find_child(self.categories, category, "MODULES_InterchangeableWithinCategory")
        result = {}

        def walk(node, trail):
            attributes = attr_values(node)
            if node["class_name"] == "Model" and "ModuleId" in attributes:
                paths_root = find_child(node, "VehiclePerformanceV2UpgradePaths") or find_child(node, "UpgradePaths")
                paths = []
                if paths_root is not None:
                    for path in paths_root["children"]:
                        if path["class_name"] == "Folder":
                            paths.append({"Name": path["name"], "attributes": attr_values(path)})
                assert attributes["ModuleId"] not in result, "duplicate ModuleId " + attributes["ModuleId"]
                result[attributes["ModuleId"]] = {
                    "name": node["name"], "folder": trail, "attributes": attributes, "paths": paths,
                }
                return
            for child in node["children"]:
                walk(child, trail + [child["name"]])

        walk(root, [])
        return result

    def manifest_sha(self, roblox_path):
        for row in self.data["manifest"]:
            if row["roblox_path"] == roblox_path:
                return row["source_sha256"]
        return None


class LiveConfig:
    """PerformanceDefinitions.Get* with the live attributes merged over the code defaults."""

    def __init__(self, capture):
        def merged(default, live):
            result = dict(default or {})
            result.update(live or {})
            return result

        self.curves = {name: merged(DEFAULT_CURVES.get(name), capture.config_attributes("StatCurves", name)) for name in RAW_ORDER}
        self.headline_weights = {
            name: merged(DEFAULT_HEADLINE_WEIGHTS.get(name), capture.config_attributes("HeadlineWeights", name))
            for name in HEADLINE_ORDER
        }
        self.overall = merged(DEFAULT_OVERALL, capture.config_attributes("OverallRating"))
        self.tier_bands = merged(DEFAULT_TIER_BANDS, capture.config_attributes("TierBands"))
        self.allocation_policy = capture.config_attributes("ComponentAllocationPolicy")
        self.variant_policy = capture.config_attributes("VariantPolicy")


# ---------------------------------------------------------------------------
# PerformanceCalculator
# ---------------------------------------------------------------------------

def _finite(value, fallback):
    if _is_number(value) and value == value and -math.inf < value < math.inf:
        return value
    return fallback


def _clamp(value, low, high):
    """Luau math.clamp: NaN stays NaN (both comparisons are false)."""
    if value < low:
        return low
    if value > high:
        return high
    return value


def _floor(value):
    """Luau math.floor: NaN and the infinities pass through (Python raises on them).
    A numeric string is coerced, as Luau does for arithmetic library arguments."""
    if isinstance(value, str):
        value = _tonumber(value)
    if not _is_number(value):
        raise TypeError("math.floor: number expected")
    if value != value or value in (math.inf, -math.inf):
        return value
    return math.floor(value)


def lua_or(*values):
    """Luau `a or b or c`: the first value that is not nil and not false, else the last."""
    for value in values[:-1]:
        if value is not None and value is not False:
            return value
    return values[-1]


def _rounded(value, places):
    scale = 10 ** max(0, _floor(_finite(places, 2)))
    return math.floor(value * scale + 0.5) / scale


def _luau_round(value):
    """Luau math.round: half away from zero."""
    return math.floor(value + 0.5) if value >= 0 else math.ceil(value - 0.5)


class Calculator:
    def __init__(self, config):
        self.config = config

    def clone_raw(self, raw):
        return {name: _finite(raw.get(name) if raw else None, 0) for name in RAW_ORDER}

    def effective_factor(self, name, raw_value):
        curve = self.config.curves[name]
        assert curve.get("CurveType") == "Power", name + " has unsupported V2 curve type " + str(curve.get("CurveType"))
        reference = max(_finite(curve.get("Reference"), 1), 0.0001)
        exponent = _clamp(_finite(curve.get("Exponent"), 1), 0.01, 1)
        technical_minimum = _finite(curve.get("TechnicalMinimum"), 0)
        raw = _finite(raw_value, technical_minimum)
        if curve.get("LowerIsBetter") is True:
            factor = (reference / max(raw, technical_minimum, 0.0001)) ** exponent
        else:
            factor = (max(raw, technical_minimum, 0) / reference) ** exponent
        assert factor == factor and factor < math.inf, name + " produced a non-finite effective factor"
        return factor

    def curve_raw(self, raw):
        return {name: self.effective_factor(name, raw.get(name) if raw else None) for name in RAW_ORDER}

    @staticmethod
    def _weighted_arithmetic(values, weights):
        total = 0.0
        weight_total = 0.0
        for key in sorted((weights or {}).keys()):
            weight = weights[key]
            if _is_number(weight) and _is_number(values.get(key)):
                total += values[key] * weight
                weight_total += weight
        return total / weight_total if weight_total > 0 else 0

    @staticmethod
    def _weighted_geometric(values, weights):
        log_total = 0.0
        weight_total = 0.0
        for key in sorted((weights or {}).keys()):
            weight = weights[key]
            value = values.get(key)
            if _is_number(weight) and _is_number(value):
                if value <= 0 and weight > 0:
                    return 0
                if weight > 0:
                    log_total += math.log(value) * weight
                    weight_total += weight
        return math.exp(log_total / weight_total) if weight_total > 0 else 0

    def calculate_headlines(self, effective):
        settings = self.config.overall
        interaction_blend = _clamp(_finite(settings.get("InteractionBlend"), 0.30), 0, 1)
        headline = {}
        for name in HEADLINE_ORDER:
            weights = self.config.headline_weights[name]
            arithmetic = self._weighted_arithmetic(effective, weights)
            geometric = self._weighted_geometric(effective, weights)
            factor = arithmetic * (1 - interaction_blend) + geometric * interaction_blend
            headline[name] = factor * 100
        return headline

    def tier_for_index(self, performance_index):
        bands = self.config.tier_bands
        for tier, default in (("S", 850), ("A", 725), ("B", 600), ("C", 450), ("D", 300), ("E", 100)):
            if performance_index >= _finite(bands.get(tier), default):
                return tier
        return "E"

    def calculate_overall(self, headline):
        settings = self.config.overall
        # weightedArithmetic(headline, settings): only keys that are headline names count.
        weighted = self._weighted_arithmetic(headline, settings)
        values = sorted(_finite(headline.get(name), 0) for name in HEADLINE_ORDER)
        weakest_three = (values[0] + values[1] + values[2]) / 3
        balance = _clamp(_finite(settings.get("BalanceContribution"), 0.075), 0, 1)
        base = _clamp(_finite(settings.get("BaseContribution"), 1 - balance), 0, 1)
        contribution_total = max(base + balance, 0.0001)
        base /= contribution_total
        balance /= contribution_total
        combined = max(weighted * base + weakest_three * balance, 0)
        minimum = _finite(settings.get("PerformanceIndexMin"), 100)
        maximum = max(_finite(settings.get("PerformanceIndexMax"), 999), minimum + 1)
        origin = _finite(settings.get("PerformanceOrigin"), 0)
        rating_input = max(combined - origin, 0)
        rating_scale = max(_finite(settings.get("RatingScale"), 50.43508980641478), 0.0001)
        internal = minimum + (maximum - minimum) * (1 - math.exp(-rating_input / rating_scale))
        retained = _rounded(internal, _finite(settings.get("InternalPrecision"), 2))
        displayed = _luau_round(retained)
        return {
            "Score": combined,
            "WeightedHeadlineScore": weighted,
            "WeakestThreeScore": weakest_three,
            "UnroundedPerformanceIndex": internal,
            "InternalPerformanceIndex": retained,
            "PerformanceIndex": displayed,
            "Tier": self.tier_for_index(displayed),
        }

    def calculate(self, raw):
        raw_copy = self.clone_raw(raw)
        effective = self.curve_raw(raw_copy)
        headline = self.calculate_headlines(effective)
        return {"Raw": raw_copy, "EffectiveFactor": effective, "Headline": headline, "Overall": self.calculate_overall(headline)}


# ---------------------------------------------------------------------------
# PerformanceRuntime / PerformanceUpgradeRuntime (component reads and upgrade points)
# ---------------------------------------------------------------------------

def read_component_raw(attributes):
    """PerformanceRuntime.ReadComponentRaw (used for the cockpit)."""
    raw = {}
    for name in RAW_ORDER:
        raw[name] = _finite(attributes.get(name), _finite(attributes.get("PerformanceDelta_" + name), 0))
    return raw


_DECIMAL = re.compile(r"[+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\Z")
_HEX = re.compile(r"[+-]?0[xX](?:[0-9a-fA-F]+\.?[0-9a-fA-F]*|\.[0-9a-fA-F]+)(?:[pP][+-]?[0-9]+)?\Z")
_SPECIAL = re.compile(r"[+-]?(?:inf(?:inity)?|nan(?:\([0-9A-Za-z_]*\))?)\Z", re.IGNORECASE)
_C_SPACE = " \t\n\v\f\r"


def _tonumber(value):
    """Luau tonumber (base 10 form): numbers pass, strings parse as C strtod does, the rest is nil.

    Python float() is not used on its own: it accepts "1_0" and non-ASCII digits, which Luau
    rejects, and it rejects hex, which Luau accepts.
    """
    if _is_number(value):
        return value
    if not isinstance(value, str):
        return None
    text = value.strip(_C_SPACE)
    if _DECIMAL.match(text):
        return float(text)
    if _HEX.match(text):
        return float.fromhex(text)
    if _SPECIAL.match(text):
        if text.lstrip("+-")[:3].lower() == "nan":
            return math.nan
        return -math.inf if text.startswith("-") else math.inf
    return None


def _tostring(value):
    """Luau tostring for the id values used here (strings, booleans and whole numbers)."""
    if value is True:
        return "true"
    if value is False:
        return "false"
    if _is_number(value) and value == value and abs(value) < 1e15 and value == int(value):
        return str(int(value))
    return str(value)


def path_id(path):
    """tostring(Definition.Attribute(path, "PathId") or path.Name)."""
    return _tostring(lua_or(path["attributes"].get("PathId"), path["Name"]))


def path_max_points(attributes, path):
    """NormalizeAllocation: tonumber(path MaxPoints) or module MaxPointsPerPath or 3 (before the floor)."""
    return lua_or(_tonumber(path["attributes"].get("MaxPoints")), attributes.get("MaxPointsPerPath"), 3)


def sorted_paths(paths):
    return sorted(paths or [], key=path_id)


def normalize_allocation(attributes, paths, allocation):
    """PerformanceUpgradeRuntime.NormalizeAllocation -> (points by PathId, spent, capacity)."""
    allocation = allocation if isinstance(allocation, dict) else {}
    capacity = max(0, _floor(lua_or(_tonumber(attributes.get("UpgradePointCapacity")), 0)))
    result = {}
    spent = 0
    for path in sorted_paths(paths):
        this_id = path_id(path)
        max_path = max(0, _floor(path_max_points(attributes, path)))
        points = _clamp(_floor(lua_or(_tonumber(allocation.get(this_id)), 0)), 0, max_path)
        points = min(points, max(0, capacity - spent))
        result[this_id] = points
        spent += points
    return result, spent, capacity


def apply_to_module_raw(attributes, paths=None, allocation=None):
    """PerformanceUpgradeRuntime.ApplyToModuleRaw."""
    normalized, _, _ = normalize_allocation(attributes, paths, allocation)
    raw = {}
    for name in RAW_ORDER:
        raw[name] = lua_or(_tonumber(attributes.get(name)), _tonumber(attributes.get("PerformanceDelta_" + name)), 0)
    for path in sorted_paths(paths):
        points = lua_or(normalized.get(path_id(path)), 0)
        if points > 0:
            for name in RAW_ORDER:
                fraction = path["attributes"].get("DeltaFraction_" + name)
                if _is_number(fraction):
                    raw[name] *= 1 + fraction * points
                flat = path["attributes"].get("DeltaFlat_" + name)
                if _is_number(flat):
                    raw[name] += flat * points
    return raw


def next_point_cost(attributes, paths, allocation, wanted_path_id):
    """PerformanceUpgradeRuntime.NextPointCost with a path id (the only live call form).

    The point number is the next point ON THAT PATH (1..MaxPoints), not the total spent.
    The path is found by folder Name (Definition.Path), so a path can only be bought when its
    folder is named by its PathId. MaxPoints does not fall back to MaxPointsPerPath here (live code).
    """
    normalized, spent, capacity = normalize_allocation(attributes, paths, allocation)
    if spent >= capacity:
        return None
    wanted = _tostring(wanted_path_id)
    path = next((item for item in (paths or []) if item["Name"] == wanted), None)
    if path is None:
        return None
    level = max(0, _floor(lua_or(_tonumber(normalized.get(wanted)), 0)))
    maximum = max(0, _floor(lua_or(_tonumber(path["attributes"].get("MaxPoints")), 3)))
    if level >= maximum:
        return None
    point = level + 1
    override = path["attributes"].get("Point%dCostGuide" % point)
    if override is not None:
        return max(0, lua_or(_tonumber(override), 0))
    return max(0, lua_or(_tonumber(attributes.get("Point%dCostGuide" % point)), 0))


def allocation_cost(attributes, paths, allocation):
    """Cash to buy an allocation one point at a time (path order does not change the total)."""
    total = 0
    current = {}
    target, _, _ = normalize_allocation(attributes, paths, allocation)
    for this_id in sorted(target):
        for _ in range(target[this_id]):
            cost = next_point_cost(attributes, paths, current, this_id)
            assert cost is not None, "allocation is not purchasable"
            total += cost
            current[this_id] = current.get(this_id, 0) + 1
    return total


def sum_components(cockpit_attributes, modules, allocations=None):
    """Raw totals as PerformanceRuntime.CalculateComponents builds them.

    modules: list of {"attributes":..., "paths":[...]}; allocations: ModuleId -> {PathId: points}.
    """
    raw = read_component_raw(cockpit_attributes)
    for module in modules or []:
        module_id = _tostring(lua_or(module["attributes"].get("ModuleId"), module.get("name")))
        allocation = allocations.get(module_id) if allocations else None
        module_raw = apply_to_module_raw(module["attributes"], module.get("paths"), allocation)
        for name in RAW_ORDER:
            raw[name] = _finite(raw.get(name), 0) + _finite(module_raw.get(name), 0)
    return raw


# ---------------------------------------------------------------------------
# Proof
# ---------------------------------------------------------------------------

LEGACY_DEFAULT_ATTRIBUTES = [
    "DefaultEngineModuleId", "DefaultEngineBModuleId", "DefaultStabilisersModuleId", "DefaultBoostModuleId",
]

# Tier order of the live Piercer ladder.
PIERCER_TIER_ORDER = ["bruiser_02", "bruiser_03", "bruiser_01", "bruiser_04", "bruiser_05", "bruiser_06"]


def piercer_stock_builds(capture=None, calculator=None):
    """Recompute the six Piercer stock builds from the capture attributes."""
    capture = capture or Capture()
    calculator = calculator or Calculator(LiveConfig(capture))
    cockpits = capture.cockpits("PIERCER")
    modules = capture.modules("PIERCER")
    profiles = capture.stock_profiles()
    rows = []
    for cockpit_id in PIERCER_TIER_ORDER:
        cockpit = cockpits[cockpit_id]["attributes"]
        defaults = [modules[cockpit[name]] for name in LEGACY_DEFAULT_ATTRIBUTES]
        raw = sum_components(cockpit, defaults)
        result = calculator.calculate(raw)
        profile = profiles[cockpit_id]
        rows.append({
            "CockpitId": cockpit_id,
            "DisplayName": cockpit["DisplayName"],
            "Price": cockpit["Price"],
            "TargetStockPI": cockpit["TargetStockPI"],
            "TargetTier": cockpit["TargetTier"],
            "ProfileTargetPI": profile.get("TargetPI"),
            "Raw": raw,
            "ProfileMaxAbsDiff": max(abs(raw[name] - profile[name]) for name in RAW_ORDER),
            "Result": result,
        })
    return rows


def main():
    capture = Capture()
    config = LiveConfig(capture)
    print("Capture place", capture.data["place_id"], "generated", capture.data["generated_in_studio"])
    for path, sha in PORTED_SOURCES.items():
        live = capture.manifest_sha(path)
        print("  source", path.split(".")[-1], "matches port" if live == sha else "CHANGED since port: " + str(live))
    print("OverallRating", json.dumps(config.overall, sort_keys=True))
    print("TierBands", json.dumps(config.tier_bands, sort_keys=True))
    print()
    print("Piercer stock builds (cockpit + four default Standard modules), recomputed from capture attributes")
    header = "%-11s %-10s %9s %6s %9s %5s %5s  %s" % (
        "CockpitId", "Name", "TargetAtt", "PI", "Internal", "Tier", "Diff", " ".join("%7s" % name[:7] for name in HEADLINE_ORDER))
    print(header)
    for row in piercer_stock_builds(capture, Calculator(config)):
        overall = row["Result"]["Overall"]
        match = "%+d" % (overall["PerformanceIndex"] - row["TargetStockPI"])
        print("%-11s %-10s %9d %6d %9.2f %5s %5s  %s" % (
            row["CockpitId"], row["DisplayName"], row["TargetStockPI"], overall["PerformanceIndex"],
            overall["InternalPerformanceIndex"], overall["Tier"], match,
            " ".join("%7.2f" % row["Result"]["Headline"][name] for name in HEADLINE_ORDER)))
        assert row["ProfileMaxAbsDiff"] < 1e-9, "stock totals differ from BalancedStockProfiles"
    print("TargetAtt is the live TargetStockPI attribute (not read by any script). Diff = computed PI minus it.")
    print("Stock totals equal Config.Vehicles.Performance.BalancedStockProfiles on all 17 stats (max diff < 1e-9).")


if __name__ == "__main__":
    main()
