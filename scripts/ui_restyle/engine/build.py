"""Builds the guarded installer for one phase of the UI restyle programme (see README.md in this folder).

    py -3 scripts/ui_restyle/tools/serve.py                       (leave running; installers fetch sources from it)
    py -3 scripts/ui_restyle/engine/build.py <phase_dir>          writes out_audit.lua, out_apply.lua, out_rollback.lua
    py -3 scripts/ui_restyle/engine/build.py <phase_dir> --inline sources embedded, for a Studio with no network
    py -3 scripts/ui_restyle/engine/build.py --selftest           rewrites engine/selftest.lua

A phase folder holds spec.json (the ops), before/ and after/ sources. Each build appends the after-fingerprints to
<phase_dir>/applied_hashes.json, so a rebuilt phase can be applied over its own earlier build (hover_feel rule).
Nothing here talks to Studio.
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import plan  # noqa: E402
import vectors  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PLACE_ID = 103397770260610
PR98_PLACE_ID = 103397770260610  # the working place since 2026-10-09; a spec opts in with "placeId"
ORIGIN = "http://127.0.0.1:8796/"
MARK_ATTRIBUTE = "UIRestyleInstall"
CLASSIC_VERIFY = "scripts/ui_restyle/classic/out_verify_classic.lua"
MAX_SOURCE_CHARS = 150000
MAX_PART_CHARS = 190000
MODES = ("AUDIT", "APPLY", "ROLLBACK")
ROOTS = ("ReplicatedStorage", "ReplicatedFirst", "ServerStorage", "ServerScriptService", "StarterPlayer",
         "StarterGui", "StarterPack", "Workspace", "Lighting", "SoundService")
SCRIPT_CLASSES = ("ModuleScript", "LocalScript", "Script")
# No Script or LocalScript: a created one would be a second startup owner (AGENTS.md).
CREATE_CLASSES = ("Folder", "ModuleScript", "Configuration", "StringValue", "BoolValue", "NumberValue", "IntValue",
                  "Color3Value", "Vector3Value")
TYPED = {"Color3": ("R", "G", "B"), "Vector3": ("X", "Y", "Z"), "Vector2": ("X", "Y"), "UDim": ("Scale", "Offset"),
         "UDim2": ("XScale", "XOffset", "YScale", "YOffset")}
SPEC_KEYS = {"phase", "placeId", "ops", "classicVerify", "installable"}
OP_KEYS = {
    "source": {"id", "kind", "transaction", "path", "class", "before", "after", "prior"},
    "create": {"id", "kind", "transaction", "path", "class", "after", "prior", "attributes", "properties"},
    "tree": {"id", "kind", "transaction", "path", "tree"},
    "attribute": {"id", "kind", "transaction", "path", "key", "before", "after", "was"},
    "property": {"id", "kind", "transaction", "path", "key", "before", "after", "was"},
}
TREE_KEYS = {"name", "class", "after", "attributes", "properties", "children"}
ID_PATTERN = re.compile(r"[A-Za-z0-9_.-]+")
NAME_PATTERN = re.compile(r"[A-Za-z0-9_]+")
FILE_PATTERN = re.compile(r"[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*")


class SpecError(ValueError):
    pass


def fail(message):
    raise SpecError(message)


def read_text(path):
    return io.open(path, encoding="utf-8", newline="").read()


def write_text(path, text):
    io.open(path, "w", encoding="utf-8", newline="\n").write(text)


def notes_removed(mapping):
    """Keys starting with "_" are notes for people (the lighting spec convention)."""
    return {k: v for k, v in mapping.items() if not k.startswith("_")}


def check_value(value, where, allow_none=False):
    if value is None:
        if not allow_none:
            fail(where + ": a value is required")
        return
    if isinstance(value, (bool, int, float, str)):
        return
    if isinstance(value, dict) and value.get("Type") in TYPED:
        fields = TYPED[value["Type"]]
        if set(value) != set(fields) | {"Type"}:
            fail("%s: %s needs exactly %s" % (where, value["Type"], ", ".join(fields)))
        for field in fields:
            if isinstance(value[field], bool) or not isinstance(value[field], (int, float)):
                fail("%s: %s.%s must be a number" % (where, value["Type"], field))
        return
    fail(where + ": unsupported value (use a boolean, number, string, or a typed table: " + ", ".join(TYPED) + ")")


def check_path(path, where):
    if not isinstance(path, list) or len(path) < 2 or not all(isinstance(p, str) and p for p in path):
        fail(where + ": path must be a list of at least two names")
    if path[0] not in ROOTS:
        fail("%s: path must start at one of %s" % (where, ", ".join(ROOTS)))


def read_source(phase_dir, relative, folder, where):
    """-> (fingerprint, text). The file must sit in <phase_dir>/<folder>/."""
    if not isinstance(relative, str) or not FILE_PATTERN.fullmatch(relative) or ".." in relative.split("/"):
        fail("%s: bad file name %r" % (where, relative))
    if not relative.startswith(folder + "/"):
        fail("%s: %s must be inside %s/" % (where, relative, folder))
    full = os.path.join(phase_dir, *relative.split("/"))
    if not os.path.isfile(full):
        fail("%s: %s does not exist" % (where, relative))
    data = open(full, "rb").read()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        fail("%s: %s is not UTF-8" % (where, relative))
    if "\x00" in text:
        fail("%s: %s contains a NUL byte" % (where, relative))
    return plan.fingerprint(data), text


def check_after_source(text, relative, where):
    if len(text) > MAX_SOURCE_CHARS:
        fail("%s: %s is %d characters; the limit is %d. Split the module." % (
            where, relative, len(text), MAX_SOURCE_CHARS))
    if "\r" in text:
        fail("%s: %s contains carriage returns; save it with LF line endings" % (where, relative))


def expand_tree(op, where):
    """A tree op is shorthand for one create op per node. Child ids are <id>/<name>."""
    out = []

    def walk(node, op_id, path, where_node):
        if not isinstance(node, dict):
            fail(where_node + ": a tree node must be an object")
        node = notes_removed(node)
        unknown = set(node) - TREE_KEYS
        if unknown:
            fail("%s: unknown tree keys %s" % (where_node, sorted(unknown)))
        made = {"id": op_id, "kind": "create", "path": path, "class": node.get("class")}
        for key in ("after", "attributes", "properties"):
            if key in node:
                made[key] = node[key]
        if "transaction" in op:
            made["transaction"] = op["transaction"]
        out.append(made)
        seen = set()
        for child in node.get("children", []):
            name = child.get("name") if isinstance(child, dict) else None
            if not isinstance(name, str) or not NAME_PATTERN.fullmatch(name) or name in seen:
                fail("%s: every tree child needs a unique simple name" % where_node)
            seen.add(name)
            walk(child, op_id + "/" + name, path + [name], where_node + "/" + name)

    if "name" in notes_removed(op.get("tree") or {}):
        fail(where + ": the tree root takes its name from path")
    walk(op.get("tree"), op["id"], list(op["path"]), where)
    return out


def validate(spec, phase_dir):
    """-> (normalised ops ready for the engine, without prior hashes; {id: {"before"/"after": text}})."""
    if not isinstance(spec, dict):
        fail("spec.json must be an object")
    spec = notes_removed(spec)
    unknown = set(spec) - SPEC_KEYS
    if unknown:
        fail("unknown spec keys %s" % sorted(unknown))
    phase = spec.get("phase")
    if not isinstance(phase, str) or not NAME_PATTERN.fullmatch(phase.replace("-", "_")):
        fail("phase must be a short name (letters, digits, dash, underscore)")
    if phase != os.path.basename(os.path.normpath(phase_dir)):
        fail("phase %r must equal its folder name %r" % (phase, os.path.basename(os.path.normpath(phase_dir))))
    if spec.get("placeId", PLACE_ID) not in (PLACE_ID, PR98_PLACE_ID):
        fail("placeId must be %d (Space Racers v3) or %d (PR98)" % (PLACE_ID, PR98_PLACE_ID))
    for key in ("classicVerify", "installable"):
        if key in spec and not isinstance(spec[key], bool) and not (key == "classicVerify" and isinstance(spec[key], str)):
            fail(key + " must be true or false")
    raw_ops = spec.get("ops")
    if not isinstance(raw_ops, list) or not raw_ops:
        fail("ops must be a non-empty list")

    flat = []
    for index, op in enumerate(raw_ops):
        where = "ops[%d]" % index
        if not isinstance(op, dict):
            fail(where + " must be an object")
        op = notes_removed(op)
        if not isinstance(op.get("id"), str) or not ID_PATTERN.fullmatch(op["id"]):
            fail(where + ": id must be letters, digits, dot, dash or underscore")
        where = "op %s" % op["id"]
        kind = op.get("kind")
        if kind not in OP_KEYS:
            fail("%s: kind must be one of %s" % (where, ", ".join(sorted(OP_KEYS))))
        unknown = set(op) - OP_KEYS[kind]
        if unknown:
            fail("%s: unknown keys %s" % (where, sorted(unknown)))
        check_path(op.get("path"), where)
        flat.extend(expand_tree(op, where) if kind == "tree" else [op])

    ops, sources, ids, created, targets = [], {}, set(), {}, set()
    for op in flat:
        where = "op %s" % op["id"]
        kind = op["kind"]
        if op["id"] in ids:
            fail(where + ": duplicate id")
        ids.add(op["id"])
        out = {"id": op["id"], "kind": kind, "path": list(op["path"])}
        out["transaction"] = plan.transaction_of(out)
        if op.get("transaction", out["transaction"]) != out["transaction"]:
            fail("%s: a %s op belongs to the %s transaction, not %r. The two transactions are never mixed." % (
                where, kind, out["transaction"], op["transaction"]))
        target = ("/".join(op["path"]), op.get("key") if kind in ("attribute", "property") else None)
        if target in targets:
            fail(where + ": another op already targets " + ".".join(op["path"]))
        targets.add(target)
        inside = [c for c in created if op["path"][:len(c)] == list(c)]
        if kind != "create" and inside:
            fail("%s: targets an instance this spec creates (%s). Put attributes, properties and the source on "
                 "the create op." % (where, created[inside[0]]))

        if kind == "source":
            if op.get("class") not in SCRIPT_CLASSES:
                fail("%s: class must be one of %s" % (where, ", ".join(SCRIPT_CLASSES)))
            out["class"] = op["class"]
            out["before"], before_text = read_source(phase_dir, op.get("before"), "before", where)
            out["after"], after_text = read_source(phase_dir, op.get("after"), "after", where)
            if out["before"] == out["after"]:
                fail(where + ": before and after are identical")
            check_after_source(after_text, op["after"], where)
            out["file"] = {"before": op["before"], "after": op["after"]}
            out["prior"] = list(op.get("prior", []))
            sources[op["id"]] = {"before": before_text, "after": after_text}
        elif kind == "create":
            if op.get("class") not in CREATE_CLASSES:
                fail("%s: class must be one of %s" % (where, ", ".join(CREATE_CLASSES)))
            out["class"] = op["class"]
            out["mark"] = "%s:%s" % (phase, op["id"])
            parent = tuple(op["path"][:-1])
            if parent in created:
                out["parentOp"] = created[parent]
            elif inside:
                fail("%s: its parent %s is not created by this spec" % (where, ".".join(parent)))
            if tuple(op["path"]) in created:
                fail(where + ": created twice")
            if any(list(c[:len(op["path"])]) == list(op["path"]) for c in created):
                fail(where + ": a parent must be created before its children")
            created[tuple(op["path"])] = op["id"]
            if (op["class"] == "ModuleScript") != ("after" in op):
                fail(where + ": a ModuleScript needs an after file; other classes must not have one")
            if "after" in op:
                out["after"], after_text = read_source(phase_dir, op["after"], "after", where)
                check_after_source(after_text, op["after"], where)
                out["file"] = {"after": op["after"]}
                out["prior"] = list(op.get("prior", []))
                sources[op["id"]] = {"after": after_text}
            for group in ("attributes", "properties"):
                values = op.get(group, {})
                if not isinstance(values, dict):
                    fail("%s: %s must be an object" % (where, group))
                for key, value in values.items():
                    if not NAME_PATTERN.fullmatch(key) or key == MARK_ATTRIBUTE or key in ("Name", "Parent", "Source"):
                        fail("%s: bad %s key %r" % (where, group, key))
                    check_value(value, "%s %s.%s" % (where, group, key))
                if values:
                    out[group] = dict(values)
        else:
            key = op.get("key")
            if not isinstance(key, str) or not NAME_PATTERN.fullmatch(key) or key == MARK_ATTRIBUTE:
                fail(where + ": bad key")
            if kind == "property" and key in ("Name", "Parent", "Source"):
                fail(where + ": Name, Parent and Source are not property ops")
            out["key"] = key
            for side in ("before", "after"):
                # The prior value is recorded on purpose, including "absent" (null). A missing key is an error.
                if side not in op:
                    fail("%s: %s must be recorded (use null for an absent attribute)" % (where, side))
                check_value(op[side], "%s %s" % (where, side), allow_none=kind == "attribute")
                if op[side] is not None:
                    out[side] = op[side]
            if json.dumps(op["before"], sort_keys=True) == json.dumps(op["after"], sort_keys=True):
                fail(where + ": before and after are identical")
            was = op.get("was", [])
            if not isinstance(was, list):
                fail(where + ": was must be a list of earlier values of this delivery")
            for value in was:
                check_value(value, where + " was")
            if was:
                out["was"] = list(was)
        if "prior" in out:
            if not all(isinstance(p, str) for p in out["prior"]):
                fail(where + ": prior must be a list of fingerprints")
        ops.append(out)
    return ops, sources


def add_prior(ops, history):
    """hover_feel rule: earlier after-fingerprints of this phase count as known. Updates history in place."""
    for op in ops:
        if "after" not in op or op["kind"] not in ("source", "create"):
            continue
        current = (op["after"], op.get("before"))
        prior = []
        for fp in list(op.get("prior", [])) + list(history.get(op["id"], [])):
            if fp not in current and fp not in prior:
                prior.append(fp)
        op["prior"] = prior
        history[op["id"]] = prior + [op["after"]]


def lua_escape(data):
    """bytes -> list of Lua string-literal tokens, one per byte, ASCII only."""
    names = {10: "\\n", 13: "\\r", 9: "\\t", 34: '\\"', 92: "\\\\"}
    return [names.get(b) or (chr(b) if 32 <= b < 127 else "\\%03d" % b) for b in data]


PART_HEAD = '''-- Generated by scripts/ui_restyle/engine/build.py. Inline sources for %(base)sout_%(mode)s.lua, part %(index)d of %(count)d.
-- Run every part (any order), then out_%(mode)s.lua. A part only stores text in the Studio session; it writes
-- nothing to the place. The installer still checks every source against its recorded fingerprint.
shared.UIRestyleInline = shared.UIRestyleInline or {}
local stash = shared.UIRestyleInline["%(build)s"] or {}
shared.UIRestyleInline["%(build)s"] = stash
local function put(file, index, text)
	stash[file] = stash[file] or {}
	stash[file][index] = text
end
'''
PART_TAIL = 'return "ui_restyle inline %(build)s: stored part %(index)d of %(count)d"\n'


def inline_parts(files, base, mode, build, max_chars=MAX_PART_CHARS):
    """files: [(repo-relative name, bytes)]. -> ([part text], {name: chunk count}). Every part is under max_chars."""
    head_room = len(PART_HEAD % {"base": base, "mode": mode, "index": 9999, "count": 9999, "build": build})
    head_room += len(PART_TAIL % {"build": build, "index": 9999, "count": 9999})
    bodies, counts, body, used = [], {}, [], head_room
    for name, data in files:
        tokens = lua_escape(data)
        overhead = len('put("", 9999, "")\n') + len(name)
        if overhead + 8 >= max_chars - head_room:
            fail("inline part size %d is too small" % max_chars)
        position, chunk_index = 0, 0
        while position < len(tokens) or chunk_index == 0:
            if used + overhead + 8 >= max_chars:
                bodies.append(body)
                body, used = [], head_room
            room = max_chars - 1 - used - overhead
            size, end = 0, position
            while end < len(tokens) and size + len(tokens[end]) <= room:
                size += len(tokens[end])
                end += 1
            chunk_index += 1
            body.append('put("%s", %d, "%s")\n' % (name, chunk_index, "".join(tokens[position:end])))
            used += overhead + size
            position = end
        counts[name] = chunk_index
    if body:
        bodies.append(body)
    parts = []
    for index, lines in enumerate(bodies, 1):
        values = {"base": base, "mode": mode, "index": index, "count": len(bodies), "build": build}
        text = PART_HEAD % values + "".join(lines) + PART_TAIL % values
        if len(text) >= max_chars:
            fail("internal: inline part %d is %d characters" % (index, len(text)))
        parts.append(text)
    return parts, counts


def lua_library():
    return "".join(read_text(os.path.join(HERE, name)) for name in ("hash.lua", "plan.lua", "engine.lua"))


def embed_json(value):
    text = json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(",", ":"))
    if "]==]" in text:
        fail("data contains the long-string terminator ]==]")
    return 'game:GetService("HttpService"):JSONDecode([==[' + text + "]==])"


def dry_run(ops):
    """Replays the delivery order against the offline model. -> [text lines]. Raises if the plan misbehaves."""
    lines = []
    model = plan.baseline_observations(ops)
    with_hierarchy = any(plan.transaction_of(op) == "hierarchy" for op in ops)
    with_sources = any(plan.transaction_of(op) == "sources" for op in ops)
    expected_apply = [name for name, present in (("hierarchy", with_hierarchy), ("sources", with_sources)) if present]
    for mode, expected in (("APPLY", expected_apply), ("ROLLBACK", list(reversed(expected_apply))),
                           ("APPLY", expected_apply)):
        ran = []
        for _ in range(4):
            decision = plan.run(mode, ops, model)
            if decision["blockers"]:
                fail("dry run: %s blocked: %s" % (mode, "; ".join(decision["blockers"])))
            if not decision["write"]:
                break
            ran.append(decision["transaction"])
            lines.append("%-8s %-9s %s" % (mode, decision["transaction"], ", ".join(
                "%s %s" % (a["action"], a["id"]) for a in decision["actions"])))
        if ran != expected:
            fail("dry run: %s ran %s, expected %s" % (mode, ran, expected))
    return lines


def phase_base(phase_dir):
    relative = os.path.relpath(os.path.abspath(phase_dir), REPO).replace(os.sep, "/")
    if relative.startswith(".."):
        fail("the phase folder must be inside the repository (serve.py serves repository paths)")
    return relative + "/"


def emit(phase_dir, inline=False, base=None, record=True, write=True, max_part_chars=MAX_PART_CHARS):
    """-> {file name: text}. base overrides the served path of the phase folder (tests build copies elsewhere)."""
    spec = json.loads(read_text(os.path.join(phase_dir, "spec.json")))
    ops, sources = validate(spec, phase_dir)
    spec = notes_removed(spec)
    history_path = os.path.join(phase_dir, "applied_hashes.json")
    history = json.loads(read_text(history_path)) if os.path.exists(history_path) else {}
    add_prior(ops, history)
    lines = dry_run(ops)
    base = base or phase_base(phase_dir)
    data = {"engine": 1, "phase": spec["phase"], "placeId": spec.get("placeId", PLACE_ID), "base": base, "origin": ORIGIN,
            "markAttribute": MARK_ATTRIBUTE, "installable": spec.get("installable", True), "inline": inline,
            "ops": ops}
    if spec.get("classicVerify"):
        # True uses the baseline verify; a repo path names a phase's own build with its declared changes.
        data["classicVerify"] = spec["classicVerify"] if isinstance(spec["classicVerify"], str) else CLASSIC_VERIFY
    library = lua_library()
    bootstrap = read_text(os.path.join(HERE, "bootstrap.lua"))
    digest = plan.djb2("|".join("%s=%s/%s" % (op["id"], op.get("before"), op.get("after")) for op in ops).encode())
    out = {}
    for mode in MODES:
        mode_data = dict(data)
        if inline:
            build = "%s:%s:%d" % (spec["phase"], mode, digest)
            which = {"AUDIT": [], "APPLY": ["after"], "ROLLBACK": ["before"]}[mode]
            files = [(base + op["file"][side], sources[op["id"]][side].encode("utf-8"))
                     for op in ops for side in which
                     if side in op.get("file", {}) and (side == "after" or op["kind"] == "source")]
            parts, counts = inline_parts(files, base, mode.lower(), build, max_part_chars) if files else ([], {})
            mode_data.update(build=build, inlineFiles=counts)
            for index, text in enumerate(parts, 1):
                out["out_%s.part%d.lua" % (mode.lower(), index)] = text
        text = ("-- Generated by scripts/ui_restyle/engine/build.py from %sspec.json. Do not edit.\n"
                "-- Run in Studio Edit (Space Racers v3). One run writes at most one transaction: run AUDIT between runs.\n"
                'local MODE = "%s"\nlocal DATA = %s\n%s%s') % (base, mode, embed_json(mode_data), library, bootstrap)
        if len(text) >= max(max_part_chars, MAX_PART_CHARS):
            fail("out_%s.lua is %d characters; the spec is too large for one command" % (mode.lower(), len(text)))
        out["out_%s.lua" % mode.lower()] = text
    if write:
        for name in os.listdir(phase_dir):
            if re.fullmatch(r"out_(audit|apply|rollback)\.part\d+\.lua", name):
                os.remove(os.path.join(phase_dir, name))
        for name, text in out.items():
            write_text(os.path.join(phase_dir, name), text)
    if record:
        write_text(history_path, json.dumps(history, indent=1, sort_keys=True) + "\n")
    return out, ops, lines


def selftest_text():
    return ("-- selftest.lua  GENERATED by scripts/ui_restyle/engine/build.py --selftest. Do not edit.\n"
            "-- READ-ONLY to the game. Run in Studio Edit (execute_luau). It builds a detached tree with Instance.new,\n"
            "-- parents nothing to the DataModel, and returns one JSON string: { passed, failed, skipped, cases }.\n"
            "local CASES = %s\n%s%s") % (embed_json(vectors.compact_cases()), lua_library(),
                                         read_text(os.path.join(HERE, "selftest_body.lua")))


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    flags = {a for a in argv if a.startswith("--")}
    if flags - {"--inline", "--selftest", "--no-record"} or (not args and "--selftest" not in flags) or len(args) > 1:
        print(__doc__)
        return 2
    if "--selftest" in flags:
        text = selftest_text()
        write_text(os.path.join(HERE, "selftest.lua"), text)
        print("selftest.lua: %d characters, %d decision vectors" % (len(text), len(vectors.vectors())))
    if args:
        try:
            out, ops, lines = emit(args[0], inline="--inline" in flags, record="--no-record" not in flags)
        except SpecError as error:
            print("BUILD FAILED: %s" % error)
            return 1
        print("offline dry run (APPLY, ROLLBACK, APPLY from the recorded before state):")
        for line in lines:
            print("  " + line)
        print(json.dumps({"ops": len(ops),
                          "transactions": {name: sum(1 for op in ops if plan.transaction_of(op) == name)
                                           for name in plan.TRANSACTIONS},
                          "files": {name: len(text) for name, text in sorted(out.items())}}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
