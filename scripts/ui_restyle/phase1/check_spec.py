"""Checks phase1/spec.json against CONTRACT.md and API.md, and reports which after-files are still missing.

    py -3 scripts/ui_restyle/phase1/check_spec.py                 report; exit 0 ready, 2 files missing, 1 invalid
    py -3 scripts/ui_restyle/phase1/check_spec.py --fix-entries   rewrites the generated entry table in the Routes test

The expected instance list, attribute rows, ClientBase lines and asset keys are parsed from the two documents, not
from gen_spec.py, so a spec that drifts from the contract fails here. Nothing here talks to Studio.
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RESTYLE = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(RESTYLE, "engine"))
import gen_spec  # noqa: E402
import plan  # noqa: E402

MAX_SOURCE_CHARS = 150000
CLASSIC_CLIENTBASE = os.path.join(RESTYLE, "classic", "sources", "StarterPlayer.StarterPlayerScripts.ClientBase.lua")
ENTRIES_JSON = os.path.join(RESTYLE, "classic", "contracts", "_clientbase_entries.json")
ROUTES_TEST = os.path.join(HERE, "tests", "ReplicatedStorage.Modules.Game.UIPulse.Routes_test.lua")
PREFIXES = (("UIP", "ReplicatedStorage.Modules.Game.UIPulse"), ("RS", "ReplicatedStorage"))


def read(path):
    return io.open(path, encoding="utf-8", newline="").read().replace("\r\n", "\n")


def expand(name):
    for short, full in PREFIXES:
        if name == short or name.startswith(short + "."):
            return full + name[len(short):]
    return name


def section(text, number, document):
    match = re.search(r"^## %d\. .*?$(.*?)(?=^## \d+\. |\Z)" % number, text, re.S | re.M)
    if not match:
        raise SystemExit("%s: section %d not found" % (document, number))
    return match.group(1)


def contract_instances(contract):
    """-> [(path string, class)] in order, from the table of CONTRACT section 2."""
    out = []
    for line in section(contract, 2, "CONTRACT.md").split("\n"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3 or not re.fullmatch(r"\d+(-\d+)?", cells[0]):
            continue
        numbers = [int(n) for n in cells[0].split("-")]
        wanted = numbers[-1] - numbers[0] + 1
        row_class = cells[2].split(",")[0].strip()
        made, previous = [], None
        for item in re.finditer(r"`([^`]+)`(\s*\(Folder\))?", cells[1]):
            name = item.group(1)
            if name.startswith("."):
                name = previous.rsplit(".", 1)[0] + name
            previous = name
            made.append((expand(name), "Folder" if item.group(2) else row_class))
        if len(made) != wanted or numbers[0] != len(out) + 1:
            raise SystemExit("CONTRACT.md section 2: row %s lists %d instances" % (cells[0], len(made)))
        out.extend(made)
    return out


def contract_attributes(contract):
    """-> [(path string, key, after, was list)] for the rows of CONTRACT section 3 that are attribute ops."""
    out = []
    for line in section(contract, 3, "CONTRACT.md").split("\n"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 5 or "`attribute`" not in cells[4]:
            continue
        was = re.search(r"was: (\[.*?\])", cells[4])
        if "before `null`" not in cells[4] or not was:
            raise SystemExit("CONTRACT.md section 3: cannot read the op of %s" % cells[1])
        out.append((expand(cells[0].strip("`")), cells[1].strip("`"), json.loads(cells[3].strip("`")),
                    json.loads(was.group(1))))
    return out


def contract_clientbase_lines(contract):
    """-> the ten lines of the 'After, lines 104 to 113' block of CONTRACT section 4."""
    match = re.search(r"After, lines 104 to 113:\n\n```lua\n(.*?)```", contract, re.S)
    if not match:
        raise SystemExit("CONTRACT.md section 4: after block not found")
    return match.group(1).split("\n")[:-1]


def api_asset_keys(api):
    match = re.search(r"^### 3\.6 .*?```text\n(.*?)```", api, re.S | re.M)
    if not match:
        raise SystemExit("API.md 3.6: asset key block not found")
    return match.group(1).split()


def entries_block():
    entries = json.loads(read(ENTRIES_JSON))["entries"]
    lines = ["local ENTRY_COUNT = %d" % len(entries), "local ENTRIES = {"]
    for entry in entries:
        for text in [entry["name"], entry["path"], entry.get("tool") or ""] + list(entry["dependencies"]):
            if not re.fullmatch(r"[A-Za-z0-9_.]*", text):
                raise SystemExit("_clientbase_entries.json: unexpected character in %r" % text)
        line = '\t{ name = "%s", path = "%s", dependencies = { %s }' % (
            entry["name"], entry["path"], ", ".join('"%s"' % d for d in entry["dependencies"]))
        if entry.get("tool"):
            line += ', tool = "%s"' % entry["tool"]
        lines.append(line.replace("{  }", "{}") + " },")
    lines.append("}")
    return "\n".join(lines) + "\n"


ENTRIES_PATTERN = re.compile(r"(-- BEGIN ENTRIES\n)(.*?)(-- END ENTRIES\n)", re.S)


def fix_entries():
    text = read(ROUTES_TEST)
    if not ENTRIES_PATTERN.search(text):
        raise SystemExit("Routes test: BEGIN/END ENTRIES markers not found")
    made = ENTRIES_PATTERN.sub(lambda m: m.group(1) + entries_block() + m.group(3), text)
    io.open(ROUTES_TEST, "w", encoding="utf-8", newline="\n").write(made)
    print("Routes test: entry table written (%d lines)" % entries_block().count("\n"))


def main(argv):
    if "--fix-entries" in argv:
        fix_entries()
    contract = read(os.path.join(HERE, "CONTRACT.md"))
    api = read(os.path.join(HERE, "API.md"))
    spec = json.loads(read(os.path.join(HERE, "spec.json")))
    errors, notes, missing = [], [], []

    def check(condition, message):
        if not condition:
            errors.append(message)

    ops = spec.get("ops", [])
    creates = [op for op in ops if op["kind"] == "create"]
    attributes = [op for op in ops if op["kind"] == "attribute"]
    sources = [op for op in ops if op["kind"] == "source"]
    check(spec.get("phase") == "phase1" and spec.get("installable") is True and bool(spec.get("classicVerify")),
          "spec header: phase1, installable and classicVerify are required")
    check(len(ops) == len(creates) + len(attributes) + len(sources), "spec: an op kind other than create, attribute, source")
    check(ops == creates + attributes + sources, "spec: order must be creates, then attributes, then the source op")
    check(len({op["id"] for op in ops}) == len(ops), "spec: duplicate op id")

    # CONTRACT 2: every instance, in order.
    expected = contract_instances(contract)
    check(len(expected) == 27, "CONTRACT section 2 lists %d instances, not 27" % len(expected))
    got = [(".".join(op["path"]), op["class"]) for op in creates]
    check(got == expected, "create ops differ from CONTRACT section 2:\n    spec only: %s\n    contract only: %s%s" % (
        [g for g in got if g not in expected], [e for e in expected if e not in got],
        "" if sorted(got) != sorted(expected) else "\n    (same set, different order)"))
    modules = [op for op in creates if op["class"] == "ModuleScript"]
    check(len(modules) == 20, "spec creates %d ModuleScripts, not 20" % len(modules))
    check(all(op["class"] in ("Folder", "ModuleScript") for op in creates), "spec creates a class other than Folder or ModuleScript")
    for op in creates:
        wanted = "after/" + ".".join(op["path"]) + ".lua" if op["class"] == "ModuleScript" else None
        check(op.get("after") == wanted, "op %s: after must be %s" % (op["id"], wanted))

    # CONTRACT 3: the three attribute ops.
    wanted_attributes = contract_attributes(contract)
    check(len(wanted_attributes) == 3, "CONTRACT section 3 lists %d attribute ops, not 3" % len(wanted_attributes))
    got_attributes = [(".".join(op["path"]), op["key"], op["after"], op.get("was", [])) for op in attributes]
    check(got_attributes == wanted_attributes, "attribute ops differ from CONTRACT section 3: %r" % (got_attributes,))
    check(all("before" in op and op["before"] is None for op in attributes), "attribute ops: before must be null")

    # CONTRACT 3 rows 4 and 5: token and asset attributes on the two config folders.
    by_path = {".".join(op["path"]): op for op in creates}
    tokens, provisional, token_source = gen_spec.load_tokens()
    pulse = by_path.get("ReplicatedStorage.Config.UI.Pulse", {})
    check(pulse.get("attributes") == tokens, "Config.UI.Pulse attributes differ from tokens_flat.json (run gen_spec.py)")
    check(tokens.get("PerfDebug") is False, "Config.UI.Pulse: PerfDebug must be false")
    for name, value in tokens.items():
        typed = isinstance(value, dict) and value.get("Type") == "Color3" and set(value) == {"Type", "R", "G", "B"}
        check(typed or isinstance(value, (bool, int, float, str)), "token %s: unsupported value %r" % (name, value))
        check(re.fullmatch(r"[A-Za-z0-9_]+", name) is not None, "token %s: bad attribute name" % name)
    asset_keys = api_asset_keys(api)
    check(len(asset_keys) == 20 and len(set(asset_keys)) == 20, "API.md 3.6 lists %d asset keys, not 20" % len(asset_keys))
    assets = by_path.get("ReplicatedStorage.Config.UI.Pulse.Assets", {})
    check(assets.get("attributes") == {key: "" for key in asset_keys}, "Config.UI.Pulse.Assets attributes differ from API.md 3.6")
    for op in creates:
        if op is not pulse and op is not assets:
            check("attributes" not in op and "properties" not in op, "op %s: unexpected attributes" % op["id"])
    if provisional:
        notes.append("token attributes are PROVISIONAL (%d, typed from API.md); replace tokens_flat.json with the "
                     "Tokens.Flatten output of the Edit test run and rerun gen_spec.py before APPLY" % len(tokens))

    # CONTRACT 4: the only source op.
    check(len(sources) == 1 and sources[0]["path"] == gen_spec.CLIENTBASE and sources[0]["class"] == "LocalScript",
          "spec: exactly one source op, ClientBase (LocalScript)")
    if sources:
        before_path = os.path.join(HERE, *sources[0]["before"].split("/"))
        after_path = os.path.join(HERE, *sources[0]["after"].split("/"))
        if os.path.isfile(before_path) and os.path.isfile(after_path):
            classic = open(CLASSIC_CLIENTBASE, "rb").read()
            before, after = open(before_path, "rb").read(), open(after_path, "rb").read()
            check(before == classic, "before/ClientBase is not byte-identical to classic/sources")
            block = contract_clientbase_lines(contract)
            old, new = before.split(b"\n"), after.split(b"\n")
            check(len(old) == 113 and len(classic) == 7577, "ClientBase baseline is not 112 lines, 7,577 bytes")
            check(new[:104] == old[:104] and new[112:] == old[104:] and len(new) == len(old) + 8,
                  "after/ClientBase: lines outside the eight inserted ones differ")
            check([line.decode("utf-8") for line in new[103:113]] == block,
                  "after/ClientBase lines 104 to 113 differ from CONTRACT section 4")
            check(b"\r" not in after, "after/ClientBase contains carriage returns")
            notes.append("ClientBase before %s, after %s (8 lines inserted after line 104, %d bytes added)" % (
                plan.fingerprint(before), plan.fingerprint(after), len(after) - len(before)))
        else:
            errors.append("ClientBase before/ or after/ file is missing")

    # After-files: present, size, line endings, header lines (API.md 11.2 and 11.11).
    print("after-files (ModuleScripts of CONTRACT section 2):")
    for op in modules:
        full = os.path.join(HERE, *op["after"].split("/"))
        path = ".".join(op["path"])
        if not os.path.isfile(full):
            missing.append(op["after"])
            print("  MISSING  %s" % op["after"])
            continue
        data = open(full, "rb").read()
        text = data.decode("utf-8", errors="replace")
        problems = []
        if b"\r" in data:
            problems.append("carriage returns")
        if len(text) > MAX_SOURCE_CHARS:
            problems.append("over %d characters" % MAX_SOURCE_CHARS)
        if b"\x00" in data or "�" in text:
            problems.append("not clean UTF-8")
        head = text.split("\n")
        if not head[0].startswith("-- Owns "):
            problems.append("line 1 must start '-- Owns '")
        if len(head) < 2 or not head[1].startswith("-- Pulse UI (phase1). %s. Requires: " % path):
            problems.append("line 2 must start '-- Pulse UI (phase1). %s. Requires: '" % path)
        test = os.path.join(HERE, "tests", path + "_test.lua")
        print("  %-8s %7d chars  %s  %s%s" % ("ok" if not problems else "PROBLEM", len(text), plan.fingerprint(data),
                                              op["after"], "" if os.path.isfile(test) else "  (no test file)"))
        for problem in problems:
            errors.append("%s: %s" % (op["after"], problem))

    # declared.json is what gen_spec.py would write now (pins follow the files present).
    declared_path = os.path.join(HERE, "declared.json")
    if os.path.isfile(declared_path):
        declared = json.loads(read(declared_path))
        check(declared == gen_spec.build_declared(), "declared.json is stale (run gen_spec.py)")
        check(sorted(declared["addedScripts"]) == sorted(".".join(op["path"]) for op in modules), "declared.json: addedScripts differ from the spec")
        unpinned = sorted(path for path, entry in declared["addedScripts"].items() if not entry)
        if unpinned:
            notes.append("declared.json: %d added scripts are not pinned to a hash yet" % len(unpinned))
    else:
        errors.append("declared.json is missing (run gen_spec.py)")
    check(spec == gen_spec.build_spec(), "spec.json is stale (run gen_spec.py)")

    # The Routes test carries the recorded ClientBase entry table.
    if os.path.isfile(ROUTES_TEST):
        match = ENTRIES_PATTERN.search(read(ROUTES_TEST))
        check(match is not None and match.group(2) == entries_block(), "Routes test: entry table differs from "
              "classic/contracts/_clientbase_entries.json (run --fix-entries)")

    for note in notes:
        print("note: " + note)
    for error in errors:
        print("INVALID: " + error)
    print("%d ops (%d create, %d attribute, %d source); %d of %d after-files missing; %d validation errors" % (
        len(ops), len(creates), len(attributes), len(sources), len(missing), len(modules), len(errors)))
    if errors:
        return 1
    if missing:
        print("NOT READY: engine/build.py will fail until the missing files are copied into after/")
        return 2
    print("READY: run  py -3 scripts/ui_restyle/engine/build.py scripts/ui_restyle/phase1")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
