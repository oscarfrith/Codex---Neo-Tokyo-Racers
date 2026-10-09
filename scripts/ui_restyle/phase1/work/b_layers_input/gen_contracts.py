#!/usr/bin/env python3
"""Generates Kit.Contracts (Pulse UI, Phase 1) from the Classic contract tables.

Reads   scripts/ui_restyle/classic/contracts/{_reserved_names,_onboarding_targets,
        _player_attributes,_screenguis,RaceLifecyclePresentationClient}.json
Writes  after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Contracts.lua (next to this file)

Usage:  py -3 gen_contracts.py [--contracts DIR] [--out FILE] [--check]
        --check  build in memory and fail if the file on disk differs; writes nothing

Deterministic: sorted keys, LF line ends, no timestamp. Any missing file, key or
cross-check stops the run with a non-zero exit. Stdlib only; no Studio, no network.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_CONTRACTS = HERE.parents[2] / "classic" / "contracts"
DEFAULT_OUT = HERE / "after" / "ReplicatedStorage.Modules.Game.UIPulse.Kit.Contracts.lua"
GENERATOR_LABEL = "scripts/ui_restyle/phase1/work/b_layers_input/gen_contracts.py"
INSTANCE_PATH = "ReplicatedStorage.Modules.Game.UIPulse.Kit.Contracts"

INPUTS = (
    "_reserved_names.json",
    "_onboarding_targets.json",
    "_player_attributes.json",
    "_screenguis.json",
    "RaceLifecyclePresentationClient.json",
)

# API.md section 9 names these by hand; each must still be found in the tables.
TRAP_PLAYERGUI_LOOKUPS = ("DriveHUD", "TouchGui")       # looked up under PlayerGui, defined by no script
TRAP_SCREENGUIS = ("DrivingSpeedEffect",)               # a Classic ScreenGui Pulse must never reuse
TRAP_DESCENDANTS = ("GarageRoot", "DealershipRoot", "CustomisationRoot", "CustomizationRoot")
KILL_LIST_TABLE = "legacyNames"                         # RaceLifecyclePresentationClient

# Programme contract 2.3, "Reserved names kept". The build stops if one is not generated.
PROGRAMME_RESERVED = (
    "DesktopFreeRoamHud", "DesignRoot", "ModalLayer", "Controls", "CarPanel", "Minimap",
    "MobileDriveControls_Phase1", "DriftLeft", "DriftRight", "Boost", "ActivityHud",
    "RaceBrowser", "CardContent", "TeleportToStart", "RaceEntryPresentation",
    "TierE", "TierD", "TierC", "TierB", "TierA", "TierS",
    "LapSelector", "PrizeSummary", "MedalTargets", "RaceFormat",
    "CanonicalGarageGui", "CanonicalCanvas", "CanonicalGarageBrowser", "CanonicalGarageWorkspace",
    "OwnedGarageBrowser", "AccessControls", "SharedTopNotification", "SharedConfirmationOverlay",
    "LoadingSafeContent", "SafeRoot", "Status", "ProgressTrack", "ProgressFill",
)
PROGRAMME_TEXTS = ("TIME TRIAL", "RACE", "DEALERSHIP")

# How each OnboardingClient helper finds its target. `needs` is checked against the
# table's own helper_kinds, so a changed helper stops the build instead of drifting.
HELPERS = {
    "group": {"kind": "name", "needs": ("name",)},
    "named": {"kind": "name", "needs": ("name",)},
    "screenRoot": {"kind": "screen", "needs": ("child-of-PlayerGui", "isa:ScreenGui")},
    "textGroup": {"kind": "text", "needs": ("text",)},
    "buttonWithText": {"kind": "text", "needs": ("text",)},
    "visibleScrollerCards": {"kind": "scroller", "needs": ("name", "attribute:CanonicalGarageCard")},
    "cardGroup": {"kind": "card", "needs": ("attribute:CanonicalGarageCard", "attribute:CanonicalGarageCardId")},
    "workspacePage": {"kind": "page", "needs": ("attribute:TutorialWorkspace", "attribute:TutorialPageId")},
}


class BuildError(Exception):
    pass


def need(table, key, where):
    if not isinstance(table, dict) or key not in table:
        raise BuildError(f"{where}: missing key '{key}'")
    return table[key]


def load(contracts: Path):
    data, prints = {}, {}
    for name in INPUTS:
        path = contracts / name
        if not path.is_file():
            raise BuildError(f"input table not found: {path}")
        raw = path.read_bytes().replace(b"\r\n", b"\n")
        prints[name] = "sha256:" + hashlib.sha256(raw).hexdigest()
        try:
            data[name] = json.loads(raw.decode("utf-8"))
        except ValueError as exc:
            raise BuildError(f"{name}: not valid JSON ({exc})") from exc
    return data, prints


# ---------------------------------------------------------------- onboarding

def onboarding_targets(onboarding):
    """Every helper call the onboarding client makes, as (helper, literal) pairs."""
    kinds = need(onboarding, "helper_kinds", "_onboarding_targets")
    for helper, spec in HELPERS.items():
        have = need(kinds, helper, "_onboarding_targets.helper_kinds")
        for feature in spec["needs"]:
            if feature not in have:
                raise BuildError(f"onboarding helper '{helper}' no longer matches on '{feature}'")
    if need(onboarding, "missing_tables", "_onboarding_targets"):
        raise BuildError("_onboarding_targets.missing_tables is not empty")
    pairs = []
    cards = need(onboarding, "cards", "_onboarding_targets")
    pages = need(onboarding, "pages", "_onboarding_targets")
    groups = [(f"card {key}", need(card, "targets", f"card {key}")) for key, card in cards.items()]
    groups += [(f"page {key}", need(page, "signal_targets", f"page {key}")) for key, page in pages.items()]
    for where, targets in groups:
        for target in targets:
            helper = need(target, "helper", where)
            if helper not in HELPERS:
                raise BuildError(f"{where}: unknown onboarding helper '{helper}'")
            for literal in need(target, "literals", where):
                if not isinstance(literal, str) or literal == "":
                    raise BuildError(f"{where}: helper '{helper}' has a non-string target")
                pairs.append((helper, literal))
    if not pairs:
        raise BuildError("_onboarding_targets: no targets found")
    return pairs


def pascal(text: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", text)
    if not words:
        raise BuildError(f"cannot build a mark key from text '{text}'")
    return "".join(word[:1].upper() + word[1:].lower() for word in words)


def build_marks(onboarding, pairs):
    marks = {}

    def put(key, value):
        if key in marks and marks[key] != value:
            raise BuildError(f"mark key collision: '{key}'")
        marks[key] = value

    texts = need(onboarding, "texts_used", "_onboarding_targets")
    has_cards = False
    for helper, literal in pairs:
        kind = HELPERS[helper]["kind"]
        if kind == "name":
            put(literal, {"Name": literal})
        elif kind == "scroller":
            put(literal, {"Name": literal})
            has_cards = True
        elif kind == "card":
            put("Card." + literal, {"Attributes": {"CanonicalGarageCard": True, "CanonicalGarageCardId": literal}})
            has_cards = True
        elif kind == "page":
            put("Page." + literal, {"Attributes": {"TutorialWorkspace": True, "TutorialPageId": literal}})
        elif kind == "text":
            if literal not in texts:
                raise BuildError(f"onboarding text '{literal}' is missing from texts_used")
        elif kind != "screen":
            raise BuildError(f"unhandled helper kind '{kind}'")
    if has_cards:
        put("Card", {"Attributes": {"CanonicalGarageCard": True}})
    for text in texts:
        put("Text." + pascal(text), {"Text": text})
    for text in PROGRAMME_TEXTS:
        if text not in texts:
            raise BuildError(f"programme text '{text}' is missing from texts_used")
    return marks


# ---------------------------------------------------------------- names

def build_traps(reserved_table, screenguis, lifecycle):
    orphans = need(reserved_table, "lookups_without_static_definer", "_reserved_names")
    trap = set()
    for name in TRAP_PLAYERGUI_LOOKUPS:
        consumers = need(need(orphans, name, "_reserved_names.lookups_without_static_definer"), "consumers", name)
        if not any(c.get("receiver_path") == "Players.LocalPlayer.PlayerGui" for c in consumers):
            raise BuildError(f"trap name '{name}' is no longer looked up under PlayerGui")
        trap.add(name)
    made = {g.get("Name") for g in need(screenguis, "screenguis", "_screenguis") if g.get("class") == "ScreenGui"}
    for name in TRAP_SCREENGUIS:
        if name not in made:
            raise BuildError(f"trap ScreenGui '{name}' is missing from _screenguis")
        trap.add(name)
    looked_up = need(need(lifecycle, "names", "RaceLifecyclePresentationClient"), "looked_up", "names")
    kill = {
        need(item, "name", "kill list") for item in looked_up
        if item.get("method") == "NameSet" and item.get("table") == KILL_LIST_TABLE
        and "ScreenGui" in (item.get("receiver_isa") or [])
    }
    if not kill:
        raise BuildError(f"RaceLifecyclePresentationClient: kill list '{KILL_LIST_TABLE}' not found")
    trap |= kill
    for name in TRAP_DESCENDANTS:
        need(orphans, name, "_reserved_names.lookups_without_static_definer")
    return trap, set(TRAP_DESCENDANTS)


def build_reserved(reserved_table, pairs):
    names = set(need(reserved_table, "names", "_reserved_names"))
    own = need(reserved_table, "names_looked_up_only_by_their_definer", "_reserved_names")
    # A ScreenGui its own owner finds on start (to adopt or destroy) is PlayerGui-wide, so it is reserved too.
    for name, entry in own.items():
        if any(d.get("class") == "ScreenGui" for d in need(entry, "definers", name)):
            names.add(name)
    for helper, literal in pairs:
        if HELPERS[helper]["kind"] in ("name", "scroller", "screen"):
            names.add(literal)
    return names


def build_locked(onboarding):
    locks = need(onboarding, "name_locks", "_onboarding_targets")
    names = set()
    for lock in locks:
        if "GuiButton" not in (lock.get("receiver_isa") or []) or "Active" not in (lock.get("properties_written") or []):
            raise BuildError("name_locks: a lock is no longer a GuiButton Active write")
        names.add(need(lock, "name", "name_locks"))
    if not names:
        raise BuildError("_onboarding_targets.name_locks is empty")
    return names


# ---------------------------------------------------------------- player attributes

def whole_call(expr: str, prefixes) -> bool:
    """True when expr is exactly one call to one of `prefixes` (the first '(' closes at the end)."""
    for prefix in prefixes:
        if expr.startswith(prefix + "("):
            depth = 0
            for index, char in enumerate(expr):
                if char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
                    if depth == 0:
                        return index == len(expr) - 1
    return False


def value_type(value):
    """Type of one written value; None when it tells nothing (a clear, or an opaque expression)."""
    if value is None:
        return None
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, dict) and isinstance(value.get("expr"), str):
        expr = value["expr"].strip()
        if whole_call(expr, ("tostring", "string.sub", "string.format", "string.upper", "string.lower")):
            return "string"
        if whole_call(expr, ("math.floor", "math.max", "math.min", "math.clamp", "math.round", "tonumber")):
            return "number"
        if re.search(r"\bor\s+(\"\"|'')$", expr):
            return "string"
        if re.search(r"\bor\s+-?\d+(\.\d+)?$", expr):
            return "number"
        if re.search(r"==|~=", expr) and not re.search(r"\b(and|or)\b", expr):
            return "boolean"
    return None


def build_player_attributes(table):
    result = {}
    for key, entry in need(table, "attributes", "_player_attributes").items():
        name = need(entry, "attribute", key)
        kinds = {value_type(w.get("value")) for w in need(entry, "writers", key)} - {None}
        kind = "unknown" if not kinds else (kinds.pop() if len(kinds) == 1 else "mixed")
        if name in result and result[name] != kind:
            # The same name on the player and on PlayerGui: keep the one that is known.
            known = {result[name], kind} - {"unknown"}
            kind = known.pop() if len(known) == 1 else "mixed"
        result[name] = kind
    if not result:
        raise BuildError("_player_attributes: no attributes")
    return result


# ---------------------------------------------------------------- Luau output

def lua_string(text: str) -> str:
    out = []
    for char in text:
        code = ord(char)
        if char in ('"', "\\"):
            out.append("\\" + char)
        elif char == "\n":
            out.append("\\n")
        elif code < 32 or code > 126:
            raise BuildError(f"unexpected character {code} in '{text}'")
        else:
            out.append(char)
    return '"' + "".join(out) + '"'


def lua_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, (int, float)):
        return repr(value)
    raise BuildError(f"cannot write value {value!r}")


def lua_set(name: str, names) -> list:
    lines = [f"Contracts.{name} = table.freeze({{"]
    lines += [f"\t[{lua_string(item)}] = true," for item in sorted(names)]
    lines.append("})")
    return lines


def lua_map(name: str, mapping) -> list:
    lines = [f"Contracts.{name} = table.freeze({{"]
    lines += [f"\t[{lua_string(key)}] = {lua_value(mapping[key])}," for key in sorted(mapping)]
    lines.append("})")
    return lines


def lua_marks(marks) -> list:
    lines = ["Contracts.Marks = table.freeze({"]
    for key in sorted(marks):
        mark = marks[key]
        parts = []
        if "Name" in mark:
            parts.append("Name = " + lua_string(mark["Name"]))
        if "Text" in mark:
            parts.append("Text = " + lua_string(mark["Text"]))
        if "Attributes" in mark:
            attrs = ", ".join(f"[{lua_string(k)}] = {lua_value(v)}" for k, v in sorted(mark["Attributes"].items()))
            parts.append("Attributes = table.freeze({" + attrs + "})")
        lines.append(f"\t[{lua_string(key)}] = table.freeze({{{', '.join(parts)}}}),")
    lines.append("})")
    return lines


def build(contracts: Path) -> str:
    data, prints = load(contracts)
    reserved_table = data["_reserved_names.json"]
    onboarding = data["_onboarding_targets.json"]

    pairs = onboarding_targets(onboarding)
    marks = build_marks(onboarding, pairs)
    trap, trap_descendants = build_traps(reserved_table, data["_screenguis.json"],
                                         data["RaceLifecyclePresentationClient.json"])
    reserved = build_reserved(reserved_table, pairs)
    locked = build_locked(onboarding)
    attributes = build_player_attributes(data["_player_attributes.json"])

    missing = [name for name in PROGRAMME_RESERVED if name not in reserved]
    if missing:
        raise BuildError("programme reserved names not generated: " + ", ".join(missing))
    clash = sorted(reserved & (trap | trap_descendants))
    if clash:
        raise BuildError("names both reserved and trap: " + ", ".join(clash))
    if trap & trap_descendants:
        raise BuildError("a name is both a trap and a trap descendant")
    for name in locked:
        if marks.get(name) != {"Name": name}:
            raise BuildError(f"locked button name '{name}' has no name mark")

    lines = [
        "-- Owns the generated Classic contract tables Pulse must honour (reserved, trap and tutorial names, "
        "player attributes); holds data only and decides nothing.",
        f"-- Pulse UI (phase1). {INSTANCE_PATH}. Requires: none.",
        "-- GENERATED by gen_contracts.py from scripts/ui_restyle/classic/contracts. Never edit by hand.",
        "local Contracts = {}",
        "",
        "-- Names one Classic script assigns and another looks up, plus ScreenGuis and tutorial targets.",
    ]
    lines += lua_set("Reserved", reserved)
    lines += ["", "-- ScreenGui names that would wake dormant Classic code, or that Classic destroys on sight."]
    lines += lua_set("Trap", trap)
    lines += ["", "-- A visible descendant with one of these names makes the Classic HUD hide itself."]
    lines += lua_set("TrapDescendants", trap_descendants)
    lines += ["", "-- Classic onboarding writes Active on every GuiButton with one of these names."]
    lines += lua_set("LockedButtonNames", locked)
    lines += ["", "-- Keys: a legacy name; Card and Card.<id>; Page.<id>; Text.<Words>."]
    lines += lua_marks(marks)
    lines += ["", "-- Type read from the values Classic writes; \"unknown\" when no writer shows one."]
    lines += lua_map("PlayerAttributes", attributes)
    lines += ["", "Contracts.Source = table.freeze({", f"\tGenerator = {lua_string(GENERATOR_LABEL)},",
              "\tInputs = table.freeze({"]
    lines += [f"\t\t[{lua_string(name)}] = {lua_string(prints[name])}," for name in sorted(prints)]
    lines += ["\t}),", "})", "", "return table.freeze(Contracts)", ""]
    text = "\n".join(lines)
    if len(text) >= 150000:
        raise BuildError(f"generated source is {len(text)} characters (limit 150,000)")
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--contracts", type=Path, default=DEFAULT_CONTRACTS)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        text = build(args.contracts)
        if args.check:
            if not args.out.is_file() or args.out.read_bytes() != text.encode("utf-8"):
                raise BuildError(f"{args.out} is missing or differs from a fresh build")
            print(f"gen_contracts: {args.out.name} is up to date ({len(text)} characters)")
            return 0
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_bytes(text.encode("utf-8"))
        print(f"gen_contracts: wrote {args.out} ({len(text)} characters)")
        return 0
    except BuildError as exc:
        print(f"gen_contracts: FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
