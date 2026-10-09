#!/usr/bin/env python3
"""Generates Kit.Sprites (Pulse UI, wave 2) and the asset id block of Kit.Tokens.

Reads   scripts/ui_restyle/assets/out/{icons,map_icons,digits,rings,touch,static_geometry}.json
        scripts/ui_restyle/assets/uploaded_assets.json
Writes  after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Sprites.lua (next to this file)
        the lines between the GENERATED ASSETS markers of
        after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens.lua (the rest of that file is hand-written)

Usage:  py -3 gen_sprites.py [--assets DIR] [--out FILE] [--tokens FILE] [--check]
        --check  build in memory and fail if either file on disk differs; writes nothing

Deterministic: sheet order or sorted keys, LF line ends, no timestamp. Any missing file, key or
cross-check stops the run with a non-zero exit. Stdlib only; no Studio, no network.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# The file may be moved (API2 1.2 names phase2/kit/): paths and the label follow its real place.
UI_RESTYLE = next((parent for parent in Path(__file__).resolve().parents if parent.name == "ui_restyle"), None)
if UI_RESTYLE is None:
    sys.exit("gen_sprites: FAILED: this file must sit under scripts/ui_restyle")
DEFAULT_ASSETS = UI_RESTYLE / "assets"
KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."
DEFAULT_OUT = HERE / "after" / (KIT + "Sprites.lua")
DEFAULT_TOKENS = HERE / "after" / (KIT + "Tokens.lua")
GENERATOR_LABEL = Path(__file__).resolve().relative_to(UI_RESTYLE.parents[1]).as_posix()

GEOMETRY = ("icons.json", "map_icons.json", "digits.json", "rings.json", "touch.json", "static_geometry.json")
UPLOADED = "uploaded_assets.json"

BEGIN_MARK = "-- BEGIN GENERATED ASSETS"
END_MARK = "-- END GENERATED ASSETS"

# API2 1.1: Tokens.Assets holds exactly these 31 keys. The build stops if the upload record differs.
ASSET_KEYS = (
    "IconSheet", "MapIconSheet", "GlowSoft", "GlowTight", "GlowLine", "Digits256", "Digits128", "DigitsPunct",
    "GaugeTrack", "GaugeTicks", "GaugeGlow", "GaugeArc", "BoostArc", "MinimapRing", "MinimapVignette",
    "MapPlayerArrow", "RankArc", "SegmentStrip", "TitleSlash", "ChequerCorner", "KeyCap",
    "TouchAccelerate", "TouchAcceleratePressed", "TouchBrake", "TouchBrakePressed", "TouchTurn", "TouchTurnPressed",
    "TouchDrift", "TouchDriftPressed", "TouchBoost", "TouchBoostPressed",
)

# API2 1.2 values that the geometry files give only in prose. Each is cross-checked where a number exists.
ICON_COUNT = 58
MAP_ICON_COUNT = 14
MAP_PINS = ("Waypoint", "TaxiDrop", "CourierDrop")
PUNCT_TOKENS = (":", ".", ",", "$", "%", "+", "-", "/", "x", "K", "M", "MPH", "KM/H", "XP")
DIGIT_SIZES = (256, 128)
GAUGE_TIP_FRACTION = 0.09                 # rings.json gauge.leading_edge: "about 0.09 of the gauge frame"
RANK_START_DEG = 180                      # rings.json rank_arc use: "clockwise from 9 o'clock (180)"
RANK_SWEEP_REGULAR = 90                   # "90 degrees on desktop"
RANK_COMPACT_FROM_DEG = 165               # "165 to 285 on phones"
RANK_COMPACT_TO_DEG = 285
TOUCH_CONTROLS = ("Accelerate", "Brake", "Turn", "Drift", "Boost")
# Tokens.Slices is hand-written (API2 1.1, unchanged values); static_geometry.json must still agree with it.
SLICES = {
    "glow_soft.png": ([62, 62, 66, 66], "edge_inset", 44),
    "glow_tight.png": ([30, 30, 34, 34], "edge_inset", 20),
    "glow_line.png": ([30, 0, 34, 64], "end_inset", 20),
}
KEYCAP_SLICE = [20, 20, 44, 44]


class BuildError(Exception):
    pass


def need(table, key, where):
    if not isinstance(table, dict) or key not in table:
        raise BuildError(f"{where}: missing key '{key}'")
    return table[key]


def read_json(path: Path):
    if not path.is_file():
        raise BuildError(f"input not found: {path}")
    raw = path.read_bytes().replace(b"\r\n", b"\n")
    try:
        return json.loads(raw.decode("utf-8")), "sha256:" + hashlib.sha256(raw).hexdigest()
    except ValueError as exc:
        raise BuildError(f"{path.name}: not valid JSON ({exc})") from exc


def load(assets: Path):
    data, prints = {}, {}
    for name in GEOMETRY:
        data[name], prints[name] = read_json(assets / "out" / name)
    data[UPLOADED], prints[UPLOADED] = read_json(assets / UPLOADED)
    return data, prints


# ---------------------------------------------------------------- Luau values

class Raw(str):
    """Luau text written as it is (an expression such as 512 / 480)."""


def lua_string(text: str) -> str:
    out = []
    for char in text:
        code = ord(char)
        if char in ('"', "\\"):
            out.append("\\" + char)
        elif code < 32 or code > 126:
            raise BuildError(f"unexpected character {code} in '{text}'")
        else:
            out.append(char)
    return '"' + "".join(out) + '"'


def lua_number(value) -> str:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise BuildError(f"not a number: {value!r}")
    if float(value) == int(value):
        return str(int(value))
    return repr(float(value))


def lua_key(key) -> str:
    if isinstance(key, int):
        return f"[{key}]"
    if key.isidentifier() and key.isascii():
        return key
    return f"[{lua_string(key)}]"


def lua_inline(value) -> str:
    if isinstance(value, Raw):
        return str(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, (int, float)):
        return lua_number(value)
    if isinstance(value, (list, tuple)):
        return "table.freeze({ " + ", ".join(lua_inline(item) for item in value) + " })"
    raise BuildError(f"cannot write value {value!r}")


class Quoted(dict):
    """A map whose keys are always written as ["key"] (glyph names and punctuation tokens)."""


def lua_table(value, indent: int) -> list:
    """Lines of a frozen table literal for a dict; insertion order is kept. Lists and scalars stay on one line."""
    tabs = "\t" * indent
    lines = ["table.freeze({"]
    for key, item in value.items():
        name = f"[{lua_string(key)}]" if isinstance(value, Quoted) else lua_key(key)
        if isinstance(item, dict):
            inner = lua_table(item, indent + 1)
            lines.append(f"{tabs}\t{name} = {inner[0]}")
            lines += inner[1:-1]
            lines.append(inner[-1] + ",")
        else:
            lines.append(f"{tabs}\t{name} = {lua_inline(item)},")
    lines.append(f"{tabs}}})")
    return lines


# ---------------------------------------------------------------- asset keys

def build_assets(uploaded):
    assets = need(uploaded, "assets", UPLOADED)
    ids, by_file = {}, {}
    for key, entry in assets.items():
        asset_id = need(entry, "id", f"{UPLOADED} {key}")
        file = need(entry, "file", f"{UPLOADED} {key}")
        if not (isinstance(asset_id, str) and asset_id.startswith("rbxassetid://") and asset_id[13:].isdigit()):
            raise BuildError(f"{UPLOADED}: '{key}' has a malformed id '{asset_id}'")
        name = Path(file).name
        if name in by_file:
            raise BuildError(f"{UPLOADED}: '{name}' is uploaded under two keys")
        ids[key] = asset_id
        by_file[name] = key
    missing = sorted(set(ASSET_KEYS) - set(ids))
    extra = sorted(set(ids) - set(ASSET_KEYS))
    if missing or extra:
        raise BuildError(f"{UPLOADED} does not hold the 31 keys of API2 1.1 (missing {missing}, extra {extra})")
    if len(set(ids.values())) != len(ids):
        raise BuildError(f"{UPLOADED}: two keys share an id")
    return ids, by_file


def key_for(by_file, image, expected, where):
    key = by_file.get(image)
    if key != expected:
        raise BuildError(f"{where}: image '{image}' is uploaded as '{key}', expected '{expected}'")
    return key


# ---------------------------------------------------------------- sheets

def sheet_glyphs(table, where, count):
    """{name: [column, row]} in sheet order (row, then column), checked against the pixel rects."""
    cell = need(table, "cell", where)
    size = need(table, "size", where)
    glyphs = need(table, "glyphs", where)
    if len(glyphs) != count:
        raise BuildError(f"{where}: {len(glyphs)} glyphs, expected {count}")
    seen, rows = set(), []
    for name, glyph in glyphs.items():
        column, row = need(glyph, "cell", f"{where} {name}")
        if need(glyph, "ImageRectOffset", name) != [column * cell, row * cell] or need(glyph, "ImageRectSize", name) != [cell, cell]:
            raise BuildError(f"{where}: glyph '{name}' rect does not match its cell")
        if (column + 1) * cell > size[0] or (row + 1) * cell > size[1] or column < 0 or row < 0:
            raise BuildError(f"{where}: glyph '{name}' is outside the sheet")
        if (column, row) in seen:
            raise BuildError(f"{where}: two glyphs share cell {column},{row}")
        seen.add((column, row))
        rows.append((row, column, name))
    return cell, Quoted((name, [column, row]) for row, column, name in sorted(rows))


def build_icons(icons, by_file):
    cell, glyphs = sheet_glyphs(icons, "icons.json", ICON_COUNT)
    return {"Asset": key_for(by_file, need(icons, "image", "icons.json"), "IconSheet", "icons.json"),
            "Cell": cell, "Glyphs": glyphs}


def build_map_icons(table, by_file):
    cell, glyphs = sheet_glyphs(table, "map_icons.json", MAP_ICON_COUNT)
    pins = need(table, "pin_icons", "map_icons.json")
    if sorted(pins) != sorted(MAP_PINS):
        raise BuildError(f"map_icons.json: pin_icons is {pins}, API2 1.2 says {list(MAP_PINS)}")
    for pin in pins:
        if pin not in glyphs:
            raise BuildError(f"map_icons.json: pin '{pin}' is not a glyph")
    return {"Asset": key_for(by_file, need(table, "image", "map_icons.json"), "MapIconSheet", "map_icons.json"),
            "Cell": cell, "PinTipY": need(table, "pin_tip_y", "map_icons.json"),
            "Pins": dict((pin, True) for pin in MAP_PINS), "Glyphs": glyphs}


def build_digits(digits, by_file):
    sheets = need(digits, "sheets", "digits.json")
    punct = need(digits, "punctuation", "digits.json")
    punct_sizes = need(punct, "sizes", "digits.json punctuation")
    punct_asset = key_for(by_file, need(punct, "image", "digits.json punctuation"), "DigitsPunct", "digits.json")
    out_digits, out_punct = {}, {}
    for size in DIGIT_SIZES:
        where = f"digits.json sheets.{size}"
        sheet = need(sheets, str(size), "digits.json sheets")
        cell = need(sheet, "cell", where)
        glyphs = Quoted()
        for digit in "0123456789":
            glyph = need(need(sheet, "glyphs", where), digit, where)
            if need(glyph, "ImageRectSize", where) != cell:
                raise BuildError(f"{where}: digit {digit} is not one cell")
            x, y = need(glyph, "ImageRectOffset", where)
            glyphs[digit] = [x, y, need(glyph, "advance", where), need(glyph, "origin_x", where)]
        if len(need(sheet, "glyphs", where)) != 10:
            raise BuildError(f"{where}: expected the ten digits only")
        out_digits[size] = {
            "Asset": key_for(by_file, need(sheet, "image", where), f"Digits{size}", where),
            "Cell": cell,
            "Cap": need(sheet, "cap_height", where),
            "Baseline": need(sheet, "baseline_y", where),
            "Pitch": need(sheet, "pitch", where),
            "PitchTight": need(sheet, "pitch_tight", where),
            "Glyphs": glyphs,
        }
        where = f"digits.json punctuation.{size}"
        tokens = need(punct_sizes, str(size), "digits.json punctuation.sizes")
        if sorted(tokens) != sorted(PUNCT_TOKENS):
            raise BuildError(f"{where}: tokens are {sorted(tokens)}, API2 1.2 says {sorted(PUNCT_TOKENS)}")
        marks = Quoted()
        for token in PUNCT_TOKENS:
            glyph = tokens[token]
            x, y = need(glyph, "ImageRectOffset", where)
            w, h = need(glyph, "ImageRectSize", where)
            if h != size:
                raise BuildError(f"{where}: token '{token}' is {h} high, expected {size}")
            marks[token] = [x, y, w, h, need(glyph, "advance", where), need(glyph, "origin_x", where)]
        out_punct[size] = {"Asset": punct_asset, "Glyphs": marks}
    return out_digits, out_punct


def build_rings(rings, by_file):
    size = need(rings, "size", "rings.json")
    for image, key in (("gauge_track.png", "GaugeTrack"), ("gauge_ticks.png", "GaugeTicks"), ("gauge_glow.png", "GaugeGlow"),
                       ("gauge_arc_gradient.png", "GaugeArc"), ("boost_arc_gradient.png", "BoostArc"),
                       ("minimap_ring_gradient.png", "MinimapRing"), ("rank_arc_gradient.png", "RankArc"),
                       ("title_slash_gradient.png", "TitleSlash")):
        key_for(by_file, image, key, "rings.json")
    gauge = need(rings, "gauge", "rings.json")
    minimap = need(rings, "minimap_ring_gradient.png", "rings.json")
    rank = need(rings, "rank_arc_gradient.png", "rings.json")
    slash = need(rings, "title_slash_gradient.png", "rings.json")
    if str(GAUGE_TIP_FRACTION) not in need(gauge, "leading_edge", "rings.json gauge"):
        raise BuildError("rings.json gauge.leading_edge no longer names the tip fraction")
    use = need(rank, "use", "rings.json rank arc")
    for number in (RANK_START_DEG, RANK_SWEEP_REGULAR, RANK_COMPACT_FROM_DEG, RANK_COMPACT_TO_DEG):
        if str(number) not in use:
            raise BuildError(f"rings.json rank arc 'use' no longer names {number}")
    # The ring's outer edge is the map edge, so the image frame is the map diameter x size / (2 x outer radius).
    diameter = 2 * need(minimap, "ring_outer_radius", "rings.json minimap ring")
    rank_scale = need(rank, "frame_scale_vs_minimap_ring_frame", "rings.json rank arc")
    slash_size = need(slash, "size", "rings.json title slash")
    per_design = need(slash, "px_per_design_px", "rings.json title slash")
    return {
        "Size": size,
        "Gauge": {
            "StartDeg": need(gauge, "start_deg", "rings.json gauge"),
            "SweepDeg": need(gauge, "sweep_deg", "rings.json gauge"),
            "ArcRadius": need(gauge, "arc_radius", "rings.json gauge"),
            "BoostRadius": need(gauge, "boost_radius", "rings.json gauge"),
            "TipFraction": GAUGE_TIP_FRACTION,
        },
        "Minimap": {"FrameScale": Raw(f"{lua_number(size)} / {lua_number(diameter)}")},
        "Rank": {
            "FrameScale": Raw(f"{lua_number(rank_scale)} * {lua_number(size)} / {lua_number(diameter)}"),
            "StartDeg": RANK_START_DEG,
            "SweepRegular": RANK_SWEEP_REGULAR,
            "CompactFromDeg": RANK_COMPACT_FROM_DEG,
            "CompactToDeg": RANK_COMPACT_TO_DEG,
        },
        "TitleSlash": {"Size": slash_size, "Design": [round(slash_size[0] / per_design, 1), round(slash_size[1] / per_design, 1)]},
    }


def build_touch(touch, by_file):
    images = need(touch, "images", "touch.json")
    out = {}
    for control in TOUCH_CONTROLS:
        where = f"touch.json touch_{control.lower()}"
        idle = need(images, f"touch_{control.lower()}", "touch.json images")
        pressed_file = need(idle, "pressed", where)
        out[control] = {
            "Idle": key_for(by_file, need(idle, "file", where), f"Touch{control}", where),
            "Pressed": key_for(by_file, pressed_file, f"Touch{control}Pressed", where),
            "PlateDp": need(idle, "plate_dp", where),
            "FrameDp": need(idle, "frame_dp", where),
            "HitDp": need(idle, "hit_box_dp", where),
        }
    return out


def check_static(static, by_file):
    glow = need(static, "glow", "static_geometry.json")
    for image, (centre, inset_key, inset) in SLICES.items():
        entry = need(glow, image, "static_geometry.json glow")
        if need(entry, "SliceCenter", image) != centre or need(entry, inset_key, image) != inset:
            raise BuildError(f"static_geometry.json: {image} no longer matches Tokens.Slices (API2 1.1)")
        if image not in by_file:
            raise BuildError(f"static_geometry.json: {image} was not uploaded")
    if need(need(static, "keycap", "static_geometry.json"), "SliceCenter", "keycap") != KEYCAP_SLICE:
        raise BuildError("static_geometry.json: keycap no longer matches Tokens.Slices (API2 1.1)")


# ---------------------------------------------------------------- output

def build_sprites(data, prints, by_file) -> str:
    check_static(data["static_geometry.json"], by_file)
    digits, punct = build_digits(data["digits.json"], by_file)
    sections = [
        ("Icons", "UI glyph sheet: {column, row} in cells of Cell px, zero-based.", build_icons(data["icons.json"], by_file)),
        ("MapIcons", "Map marker sheet. Pin glyphs anchor at (0.5, PinTipY); the rest at the centre.",
         build_map_icons(data["map_icons.json"], by_file)),
        ("Digits", "Digit sheets by cell height: glyph = {x, y, advance, originX}.", digits),
        ("Punct", "Punctuation and unit words by cell height: glyph = {x, y, w, h, advance, originX}.", punct),
        ("Rings", "Angles are degrees clockwise from +X in screen space (0 = 3 o'clock, 90 = 6, 180 = 9, 270 = 12).",
         build_rings(data["rings.json"], by_file)),
        ("Touch", "Touch controls: asset keys and sizes in dp (ctx.Dp).", build_touch(data["touch.json"], by_file)),
    ]
    lines = [
        "-- Owns the generated sprite geometry of the uploaded Pulse images (sheet cells, digit metrics, ring angles, "
        "touch sizes); holds data only and no asset id.",
        f"-- Pulse UI (phase2). {KIT}Sprites. Requires: none.",
        "-- GENERATED by gen_sprites.py from scripts/ui_restyle/assets. Never edit by hand. Numbers are source-image pixels.",
        "local Sprites = {}",
    ]
    for name, comment, value in sections:
        body = lua_table(value, 0)
        lines += ["", f"-- {comment}", f"Sprites.{name} = {body[0]}"] + body[1:]
    lines += ["", "Sprites.Source = table.freeze({", f"\tGenerator = {lua_string(GENERATOR_LABEL)},", "\tInputs = table.freeze({"]
    lines += [f"\t\t[{lua_string(name)}] = {lua_string(prints[name])}," for name in sorted(prints)]
    lines += ["\t}),", "})", "", "return table.freeze(Sprites)", ""]
    text = "\n".join(lines)
    if len(text) >= 150000:
        raise BuildError(f"generated source is {len(text)} characters (limit 150,000)")
    return text


def build_tokens(ids, tokens_path: Path) -> str:
    """The Tokens source with its marked block replaced by the uploaded ids."""
    if not tokens_path.is_file():
        raise BuildError(f"Tokens source not found: {tokens_path}")
    raw = tokens_path.read_bytes()
    if b"\r" in raw:
        raise BuildError(f"{tokens_path.name} has CR line ends")
    lines = raw.decode("utf-8").split("\n")
    begins = [index for index, line in enumerate(lines) if line.startswith(BEGIN_MARK)]
    ends = [index for index, line in enumerate(lines) if line.startswith(END_MARK)]
    if len(begins) != 1 or len(ends) != 1 or ends[0] < begins[0]:
        raise BuildError(f"{tokens_path.name}: expected one '{BEGIN_MARK}' line followed by one '{END_MARK}' line")
    block = [f"{BEGIN_MARK} (gen_sprites.py, from scripts/ui_restyle/assets/{UPLOADED}; never edit by hand)",
             "Tokens.Assets = {"]
    block += [f"\t{key} = {lua_string(ids[key])}," for key in ASSET_KEYS]
    block += ["}", END_MARK]
    text = "\n".join(lines[:begins[0]] + block + lines[ends[0] + 1:])
    if len(text) >= 150000:
        raise BuildError(f"{tokens_path.name} is {len(text)} characters (limit 150,000)")
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--assets", type=Path, default=DEFAULT_ASSETS)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--tokens", type=Path, default=DEFAULT_TOKENS)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        data, prints = load(args.assets)
        ids, by_file = build_assets(data[UPLOADED])
        outputs = ((args.out, build_sprites(data, prints, by_file)), (args.tokens, build_tokens(ids, args.tokens)))
        for path, text in outputs:
            if args.check:
                if not path.is_file() or path.read_bytes() != text.encode("utf-8"):
                    raise BuildError(f"{path} is missing or differs from a fresh build")
                print(f"gen_sprites: {path.name} is up to date ({len(text)} characters)")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(text.encode("utf-8"))
                print(f"gen_sprites: wrote {path} ({len(text)} characters)")
        return 0
    except BuildError as exc:
        print(f"gen_sprites: FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
