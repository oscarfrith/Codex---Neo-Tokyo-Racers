#!/usr/bin/env python3
"""Writes tokens_flat.json for wave 2: the token attributes that are new since Phase 1, and the asset ids.

Reads   after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens.lua (next to this file; parsed as text)
        scripts/ui_restyle/phase1/tokens_flat.json (the installed attributes)
        scripts/ui_restyle/phase1/after/<the same Tokens file> (the Phase 1 asset keys)
Writes  tokens_flat.json (next to this file), in the format of the Phase 1 file

Usage:  py -3 gen_tokens_flat.py [--check]

The flat names follow Tokens.Flatten. The run stops if a Phase 1 token is missing or has another value
(API2 2.2 adds tokens and changes none). This is a desk check: the integrator still regenerates the
attribute ops from Tokens.Flatten(Tokens.Defaults) in Studio. Stdlib only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
UI_RESTYLE = next((parent for parent in Path(__file__).resolve().parents if parent.name == "ui_restyle"), None)
if UI_RESTYLE is None:
    sys.exit("gen_tokens_flat: FAILED: this file must sit under scripts/ui_restyle")
TOKENS = HERE / "after" / "ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens.lua"
PHASE1 = UI_RESTYLE / "phase1" / "tokens_flat.json"
PHASE1_TOKENS = UI_RESTYLE / "phase1" / "after" / "ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens.lua"
OUT = HERE / "tokens_flat.json"

# Group -> flat prefix; a nested group maps its two halves.
PLAIN = {"Colour": "Colour", "Tier": "Tier", "Opacity": "Opacity", "Space": "Space", "Type": "Type", "Scale": "Scale"}
NESTED = {"Cap": {"Regular": "Cap", "Compact": "CompactCap"},
          "NumberCap": {"Regular": "NumberCap", "Compact": "CompactNumberCap"}}
# API2 1.1: Phase 1 asset attributes that stay on the folder as "" and are ignored.
RETIRED_ASSETS = ("GaugeRing", "MinimapRankRing", "TouchControls", "TouchControls2", "TitleMark")
NOT_TOKENS = ("PerfDebug",)             # on the same folder, read by Kit.Perf

GROUP = re.compile(r"^Tokens\.(\w+) = \{$")
HALF = re.compile(r"^\t(\w+) = \{$")
ENTRY = re.compile(r"^\t+(\w+) = (.+),$")
NUMBER = re.compile(r"^-?\d+(\.\d+)?( / \d+(\.\d+)?)?$")
COLOUR = re.compile(r"^rgb\((\d+), (\d+), (\d+)\)$")


class BuildError(Exception):
    pass


def value_of(text: str, where: str):
    colour = COLOUR.match(text)
    if colour:
        r, g, b = (int(part) for part in colour.groups())
        return {"Type": "Color3", "R": r / 255, "G": g / 255, "B": b / 255}
    if NUMBER.match(text):
        if " / " in text:
            top, bottom = text.split(" / ")
            return float(top) / float(bottom)
        number = float(text)
        return int(number) if number == int(number) else number
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"' and "\\" not in text:
        return text[1:-1]
    raise BuildError(f"{where}: cannot read value {text}")


def parse(source: str):
    """Flat name -> value for the token groups, and the asset key -> id map."""
    flat, assets = {}, {}
    group, half = None, None
    for number, line in enumerate(source.split("\n"), 1):
        if group is None:
            match = GROUP.match(line)
            if match and (match.group(1) in PLAIN or match.group(1) in NESTED or match.group(1) == "Assets"):
                group = match.group(1)
            continue
        if line == "}":
            group, half = None, None
            continue
        if group in NESTED:
            if line == "\t},":
                half = None
                continue
            match = HALF.match(line)
            if match:
                half = match.group(1)
                if half not in NESTED[group]:
                    raise BuildError(f"line {number}: unknown half '{half}' of {group}")
                continue
        stripped = line.strip()
        if stripped == "" or stripped.startswith("--"):
            continue
        match = ENTRY.match(line)
        if not match:
            raise BuildError(f"line {number}: cannot read '{line}' inside Tokens.{group}")
        key, value = match.group(1), value_of(match.group(2), f"line {number}")
        if group == "Assets":
            assets[key] = value
            continue
        if group in NESTED:
            if half is None:
                raise BuildError(f"line {number}: entry outside Regular or Compact")
            name = NESTED[group][half] + key
        else:
            name = PLAIN[group] + key
        if name in flat:
            raise BuildError(f"flat name collision: {name}")
        flat[name] = value
    if group is not None:
        raise BuildError("Tokens source ended inside a group")
    return flat, assets


def same(a, b) -> bool:
    if isinstance(a, dict) or isinstance(b, dict):
        return (isinstance(a, dict) and isinstance(b, dict) and a.get("Type") == b.get("Type")
                and all(abs(a[c] - b[c]) < 1e-12 for c in "RGB"))
    if isinstance(a, str) or isinstance(b, str):
        return a == b
    return abs(a - b) < 1e-12


def build() -> str:
    flat, assets = parse(TOKENS.read_bytes().decode("utf-8"))
    old = json.loads(PHASE1.read_text(encoding="utf-8"))["tokens"]
    for name, value in old.items():
        if name in NOT_TOKENS:
            continue
        if name not in flat:
            raise BuildError(f"Phase 1 token {name} is gone")
        if not same(flat[name], value):
            raise BuildError(f"Phase 1 token {name} changed from {value} to {flat[name]}")
    new = {name: value for name, value in flat.items() if name not in old}
    if len(assets) != 31 or any(not str(v).startswith("rbxassetid://") for v in assets.values()):
        raise BuildError("Tokens.Assets does not hold 31 uploaded ids")
    if any(name in assets for name in RETIRED_ASSETS):
        raise BuildError("a retired asset key is still in Tokens.Assets")
    _, old_assets = parse(PHASE1_TOKENS.read_bytes().decode("utf-8"))
    if sorted(set(old_assets) - set(assets)) != sorted(RETIRED_ASSETS):
        raise BuildError("the Phase 1 asset keys that are gone are not the five of API2 1.1")
    document = {
        "_format": "name -> boolean | number | string | {Type: Color3, R, G, B} with components 0..1 (the engine's typed value form)",
        "_source": "new since Phase 1 only: parsed from the wave-2 Kit.Tokens source by phase2/kit/k1/gen_tokens_flat.py "
                   f"({len(flat)} flat tokens in all, {len(new)} new, 0 changed). Attributes on Config.UI.Pulse; before = absent",
        "provisional": False,
        "tokens": new,
        "_assets": "attributes on Config.UI.Pulse.Assets (same name, same string). assets_before is the Phase 1 value: "
                   "\"\" for a key that existed, null for a new key. assets_retired stay \"\" and are ignored (API2 1.1)",
        "assets": assets,
        "assets_before": {key: ("" if key in old_assets else None) for key in assets},
        "assets_retired": list(RETIRED_ASSETS),
    }
    return json.dumps(document, indent=1, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        text = build()
        if args.check:
            if not OUT.is_file() or OUT.read_bytes() != text.encode("utf-8"):
                raise BuildError(f"{OUT} is missing or differs from a fresh build")
            print(f"gen_tokens_flat: {OUT.name} is up to date")
            return 0
        OUT.write_bytes(text.encode("utf-8"))
        print(f"gen_tokens_flat: wrote {OUT}")
        return 0
    except BuildError as exc:
        print(f"gen_tokens_flat: FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
