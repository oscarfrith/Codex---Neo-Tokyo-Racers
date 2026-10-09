"""Generates phase1/spec.json (engine installer spec) and phase1/declared.json (Classic verify declarations).

    py -3 scripts/ui_restyle/phase1/gen_spec.py            writes both files
    py -3 scripts/ui_restyle/phase1/check_spec.py          validates them against CONTRACT.md and reports missing files

Inputs: the instance list below (CONTRACT section 2, in order), tokens_flat.json (CONTRACT section 3: the JSON of
Tokens.Flatten(Tokens.Defaults) plus PerfDebug; provisional until the Edit test run replaces it), ASSET_KEYS
(API.md 3.6) and the after/ folder (an added script is pinned in declared.json only when its file exists).
Op ids become the install marks ("phase1:<id>") on created instances: do not rename an id after the first APPLY.
Nothing here talks to Studio.
"""
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
UIP = ["ReplicatedStorage", "Modules", "Game", "UIPulse"]
CONFIG_UI = ["ReplicatedStorage", "Config", "UI"]
CLIENT_TOOLS = ["ReplicatedStorage", "Config", "Development", "ClientTools"]
CLIENTBASE = ["StarterPlayer", "StarterPlayerScripts", "ClientBase"]

# (op id, class, path) in the order of CONTRACT section 2. Rows 26 and 27 carry attributes (added below).
INSTANCES = [
    ("latch", "ModuleScript", ["ReplicatedFirst", "UIStyleSwitch"]),
    ("uipulse", "Folder", UIP),
    ("routes", "ModuleScript", UIP + ["Routes"]),
    ("kit", "Folder", UIP + ["Kit"]),
    ("kit.Tokens", "ModuleScript", UIP + ["Kit", "Tokens"]),
    ("kit.Metrics", "ModuleScript", UIP + ["Kit", "Metrics"]),
    ("kit.Perf", "ModuleScript", UIP + ["Kit", "Perf"]),
    ("kit.Layers", "ModuleScript", UIP + ["Kit", "Layers"]),
    ("kit.Input", "ModuleScript", UIP + ["Kit", "Input"]),
    ("kit.Contracts", "ModuleScript", UIP + ["Kit", "Contracts"]),
    ("kit.Text", "ModuleScript", UIP + ["Kit", "Text"]),
    ("kit.Surface", "ModuleScript", UIP + ["Kit", "Surface"]),
    ("kit.Controls", "ModuleScript", UIP + ["Kit", "Controls"]),
    ("kit.Collections", "ModuleScript", UIP + ["Kit", "Collections"]),
    ("kit.Overlay", "ModuleScript", UIP + ["Kit", "Overlay"]),
    ("toasts", "Folder", UIP + ["Toasts"]),
    ("toasts.ToastClient", "ModuleScript", UIP + ["Toasts", "ToastClient"]),
    ("dev", "Folder", UIP + ["Dev"]),
    ("dev.Gallery", "ModuleScript", UIP + ["Dev", "Gallery"]),
    ("fixtures", "Folder", UIP + ["Dev", "Fixtures"]),
    ("fixtures.Text", "ModuleScript", UIP + ["Dev", "Fixtures", "Text"]),
    ("fixtures.Surface", "ModuleScript", UIP + ["Dev", "Fixtures", "Surface"]),
    ("fixtures.Controls", "ModuleScript", UIP + ["Dev", "Fixtures", "Controls"]),
    ("fixtures.Collections", "ModuleScript", UIP + ["Dev", "Fixtures", "Collections"]),
    ("fixtures.Overlay", "ModuleScript", UIP + ["Dev", "Fixtures", "Overlay"]),
    ("config.Pulse", "Folder", CONFIG_UI + ["Pulse"]),
    ("config.Assets", "Folder", CONFIG_UI + ["Pulse", "Assets"]),
]
TOKEN_OP, ASSET_OP = "config.Pulse", "config.Assets"

# API.md 3.6, in its order. Every value is "" until the asset is uploaded.
ASSET_KEYS = ["IconSheet", "MapIconSheet", "GlowSoft", "GlowTight", "GlowLine", "Digits256", "Digits128", "DigitsPunct",
              "GaugeRing", "GaugeTicks", "MinimapRing", "MinimapVignette", "MapPlayerArrow", "SegmentStrip",
              "ChequerCorner", "TitleMark", "KeyCap", "MinimapRankRing", "TouchControls", "TouchControls2"]

# CONTRACT section 3, rows 1 to 3: (op id, path, key, after, was). before is always null (absent).
ATTRIBUTES = [
    ("attr.UIStyle", CONFIG_UI, "UIStyle", "Classic", ["Pulse"]),
    ("attr.UIStyleDevFamilies", CONFIG_UI, "UIStyleDevFamilies", "", ["Toasts", "Nope"]),
    ("attr.PulseGalleryEnabled", CLIENT_TOOLS, "PulseGalleryEnabled", False, [True]),
]


def source_file(path):
    return "after/" + ".".join(path) + ".lua"


def load_tokens():
    with io.open(os.path.join(HERE, "tokens_flat.json"), encoding="utf-8") as handle:
        data = json.load(handle)
    tokens = data["tokens"]
    if "PerfDebug" not in tokens:
        tokens = dict(tokens, PerfDebug=False)
    return tokens, bool(data.get("provisional", True)), data.get("_source", "")


def build_spec():
    tokens, provisional, token_source = load_tokens()
    ops = []
    for op_id, klass, path in INSTANCES:
        op = {"id": op_id, "kind": "create", "class": klass, "path": path}
        if klass == "ModuleScript":
            op["after"] = source_file(path)
        if op_id == TOKEN_OP:
            op["attributes"] = {name: tokens[name] for name in sorted(tokens)}
        if op_id == ASSET_OP:
            op["attributes"] = {name: "" for name in ASSET_KEYS}
        ops.append(op)
    for op_id, path, key, after, was in ATTRIBUTES:
        ops.append({"id": op_id, "kind": "attribute", "path": path, "key": key, "before": None, "after": after,
                    "was": was})
    ops.append({"id": "clientbase", "kind": "source", "class": "LocalScript", "path": CLIENTBASE,
                "before": "before/" + ".".join(CLIENTBASE) + ".lua", "after": source_file(CLIENTBASE)})
    return {
        "_note": "GENERATED by phase1/gen_spec.py. Do not edit by hand. Hierarchy transaction: ops 1 to 30 "
                 "(CONTRACT 2 in order, then the three attributes of CONTRACT 3). Sources transaction: clientbase.",
        "_tokens": {"provisional": provisional, "count": len(tokens), "source": token_source},
        "phase": "phase1",
        "classicVerify": "scripts/ui_restyle/phase1/out_verify_classic_phase1.lua",
        "installable": True,
        "ops": ops,
    }


def build_declared():
    """scripts: the ClientBase after-hash. addedScripts: the 20; pinned to their file when it exists."""
    added = {}
    for _, klass, path in INSTANCES:
        if klass != "ModuleScript":
            continue
        relative = source_file(path)
        present = os.path.isfile(os.path.join(HERE, *relative.split("/")))
        added[".".join(path)] = {"file": relative, "class": "ModuleScript"} if present else {}
    return {
        "scripts": {".".join(CLIENTBASE): {"file": source_file(CLIENTBASE)}},
        "addedScripts": added,
        "configNodes": ["UI.Pulse", "UI.Pulse.Assets"],
        "configAttrs": ["UI@UIStyle", "UI@UIStyleDevFamilies", "Development.ClientTools@PulseGalleryEnabled"],
    }


def dump(value):
    return json.dumps(value, indent=1) + "\n"


def main():
    for name, value in (("spec.json", build_spec()), ("declared.json", build_declared())):
        with io.open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(dump(value))
    spec, declared = build_spec(), build_declared()
    pinned = sum(1 for entry in declared["addedScripts"].values() if entry)
    print("spec.json: %d ops (%d token attributes%s, %d asset attributes)" % (
        len(spec["ops"]), spec["_tokens"]["count"], ", PROVISIONAL" if spec["_tokens"]["provisional"] else "",
        len(ASSET_KEYS)))
    print("declared.json: %d added scripts, %d pinned to a file, %d unpinned (file not in after/ yet)" % (
        len(declared["addedScripts"]), pinned, len(declared["addedScripts"]) - pinned))


if __name__ == "__main__":
    main()
