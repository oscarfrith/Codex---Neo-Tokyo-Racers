"""Offline tests of the UI restyle installer engine. Plain asserts, standard library only.

    py -3 scripts/ui_restyle/engine/test_engine.py

Luau cannot run offline, so these cover the Python decision logic (plan.py), the build (build.py), the emitted
files, and a structural lint of the Lua. plan.lua and engine.lua are exercised by selftest.lua in Studio Edit.
"""
import contextlib
import copy
import io
import json
import os
import re
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build  # noqa: E402
import plan  # noqa: E402
import vectors  # noqa: E402

SAMPLE = os.path.join(HERE, "sample_phase")
SAMPLE_BASE = "scripts/ui_restyle/engine/sample_phase/"
GATE = {"placeOk": True, "isEdit": True, "testWindow": "", "notInstallable": False}
TESTS = []


def test(fn):
    TESTS.append(fn)
    return fn


def raises(fn, fragment):
    try:
        fn()
    except build.SpecError as error:
        assert fragment in str(error), "expected %r in %r" % (fragment, str(error))
        return
    raise AssertionError("expected a SpecError containing %r" % fragment)


class Phase:
    """A throwaway phase folder. with Phase(spec, files) as path: ..."""

    def __init__(self, spec=None, files=None, name="demo"):
        self.spec, self.files, self.name = spec, files or {}, name

    def __enter__(self):
        self.root = tempfile.mkdtemp(prefix="ui_restyle_engine_")
        self.path = os.path.join(self.root, self.name)
        os.makedirs(self.path)
        files = {"before/A.lua": "return 1\n", "after/A.lua": "return 2\n", "after/New.lua": "return {}\n"}
        files.update(self.files)
        for relative, text in files.items():
            full = os.path.join(self.path, *relative.split("/"))
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "wb") as handle:
                handle.write(text if isinstance(text, bytes) else text.encode("utf-8"))
        if self.spec is not None:
            with open(os.path.join(self.path, "spec.json"), "w", encoding="utf-8") as handle:
                json.dump(self.spec, handle)
        return self.path

    def __exit__(self, *args):
        shutil.rmtree(self.root, ignore_errors=True)


def good_spec():
    return {"phase": "demo", "ops": [
        {"id": "kit", "kind": "create", "class": "Folder", "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse"],
         "attributes": {"Accent": {"Type": "Color3", "R": 0.1, "G": 0.2, "B": 0.3}}},
        {"id": "new", "kind": "create", "class": "ModuleScript",
         "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse", "New"], "after": "after/New.lua"},
        {"id": "style", "kind": "attribute", "path": ["ReplicatedStorage", "Config", "UI"], "key": "Style",
         "before": None, "after": "Pulse"},
        {"id": "a", "kind": "source", "class": "ModuleScript", "path": ["ReplicatedStorage", "Modules", "A"],
         "before": "before/A.lua", "after": "after/A.lua"},
    ]}


def validate(spec, files=None):
    with Phase(spec, files) as path:
        return build.validate(spec, path)


def bad(change, fragment, files=None):
    spec = good_spec()
    change(spec)
    raises(lambda: validate(spec, files), fragment)


# ------------------------------------------------------------------------------------------------------- hashes

@test
def hash_matches_known_values():
    assert plan.djb2(b"") == 5381 and plan.fnv1a32(b"") == 2166136261
    assert plan.fnv1a32(b"a") == 0xE40C292C and plan.fnv1a32(b"foobar") == 0xBF9CF968
    assert plan.djb2(b"a") == 5381 * 33 + 97
    assert plan.fingerprint(b"a") == "%d-%d-1" % (5381 * 33 + 97, 0xE40C292C)


@test
def hash_matches_classic_manifest():
    manifest = os.path.join(HERE, "..", "classic", "manifest.json")
    if not os.path.exists(manifest):
        return "skipped: classic/manifest.json is not there yet"
    rows = {row["path"]: row for row in json.load(open(manifest, encoding="utf-8"))["scripts"]}
    row = rows["StarterPlayer.StarterPlayerScripts.ClientBase"]
    data = open(os.path.join(SAMPLE, "before", "ClientBase.lua"), "rb").read()
    assert plan.fingerprint(data) == "%d-%d-%d" % (row["djb2"], row["fnv1a32"], row["length"])


@test
def lua_hash_split_multiply_is_exact():
    # hash.lua computes f * 16777619 as lshift(f, 24) + f * 403; check the identity and the double-precision bound.
    for f in (0, 1, 255, 256, 0x811C9DC5, 0xFFFFFFFF, 0x12345678):
        split = ((f << 24) % 2 ** 32 + f * 403) % 2 ** 32
        assert split == (f * 16777619) % 2 ** 32
        assert (f << 24) % 2 ** 32 + f * 403 < 2 ** 53


# ---------------------------------------------------------------------------------------------- spec validation

@test
def valid_spec_normalises():
    ops, sources = validate(good_spec())
    assert [op["id"] for op in ops] == ["kit", "new", "style", "a"]
    assert [op["transaction"] for op in ops] == ["hierarchy", "hierarchy", "hierarchy", "sources"]
    assert ops[0]["mark"] == "demo:kit" and ops[1]["mark"] == "demo:new" and ops[1]["parentOp"] == "kit"
    assert "parentOp" not in ops[0] and "before" not in ops[2] and ops[2]["after"] == "Pulse"
    assert ops[3]["before"] == plan.fingerprint(b"return 1\n") and ops[3]["after"] == plan.fingerprint(b"return 2\n")
    assert ops[3]["file"] == {"before": "before/A.lua", "after": "after/A.lua"}
    assert sources["new"] == {"after": "return {}\n"} and sources["a"]["before"] == "return 1\n"


@test
def notes_are_ignored():
    spec = good_spec()
    spec["_note"] = "for people"
    spec["ops"][0]["_why"] = "kit folder"
    assert len(validate(spec)[0]) == 4


@test
def spec_shape_is_checked():
    bad(lambda s: s.pop("ops"), "ops must be a non-empty list")
    bad(lambda s: s.update(ops=[]), "ops must be a non-empty list")
    bad(lambda s: s.update(extra=1), "unknown spec keys")
    bad(lambda s: s.update(phase="other"), "must equal its folder name")
    bad(lambda s: s.update(placeId=121304917315753), "placeId must be")
    bad(lambda s: s.update(installable="no"), "installable must be true or false")
    bad(lambda s: s["ops"][0].update(kind="delete"), "kind must be one of")
    bad(lambda s: s["ops"][0].update(colour="red"), "unknown keys")
    bad(lambda s: s["ops"][0].update(id="bad id"), "id must be")
    bad(lambda s: s["ops"][1].update(id="kit"), "duplicate id")


@test
def paths_are_checked():
    bad(lambda s: s["ops"][3].update(path=["ReplicatedStorage"]), "at least two names")
    bad(lambda s: s["ops"][3].update(path=["CoreGui", "X"]), "path must start at one of")
    bad(lambda s: s["ops"][3].update(path="ReplicatedStorage.Modules.A"), "at least two names")
    spec = good_spec()
    spec["ops"].append(dict(spec["ops"][3], id="again"))
    raises(lambda: validate(spec), "another op already targets")


@test
def source_files_are_checked():
    bad(lambda s: s["ops"][3].update(after="after/Missing.lua"), "does not exist")
    bad(lambda s: s["ops"][3].update(after="before/A.lua"), "must be inside after/")
    bad(lambda s: s["ops"][3].update(before="../before/A.lua"), "bad file name")
    bad(lambda s: s["ops"][3].update(before="after/A.lua"), "must be inside before/")
    bad(lambda s: s["ops"][3].update(**{"class": "Folder"}), "class must be one of")
    bad(lambda s: None, "before and after are identical", {"after/A.lua": "return 1\n"})
    bad(lambda s: None, "carriage returns", {"after/A.lua": "return 2\r\n"})
    bad(lambda s: None, "not UTF-8", {"after/A.lua": b"return '\xff'\n"})
    bad(lambda s: None, "NUL byte", {"after/A.lua": "return 2\x00\n"})


@test
def create_rules():
    bad(lambda s: s["ops"][0].update(**{"class": "LocalScript"}), "class must be one of")
    bad(lambda s: s["ops"][0].update(**{"class": "Script"}), "class must be one of")
    bad(lambda s: s["ops"][1].pop("after"), "a ModuleScript needs an after file")
    bad(lambda s: s["ops"][0].update(after="after/New.lua"), "other classes must not have one")
    bad(lambda s: s["ops"][0].update(attributes={"UIRestyleInstall": "x"}), "bad attributes key")
    bad(lambda s: s["ops"][0].update(attributes={"A": [1, 2]}), "unsupported value")
    bad(lambda s: s["ops"][0].update(attributes={"A": {"Type": "Color3", "R": 1, "G": 1}}), "needs exactly")
    bad(lambda s: s["ops"].reverse(), "must be created before its children")
    deep = {"id": "deep", "kind": "create", "class": "Folder",
            "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse", "Views", "Deep"]}
    bad(lambda s: s["ops"].insert(0, deep), "must be created before its children")
    bad(lambda s: s["ops"].append(deep), "is not created by this spec")


@test
def ops_on_created_instances_are_refused():
    bad(lambda s: s["ops"].append({"id": "x", "kind": "attribute", "key": "K", "before": None, "after": 1,
                                   "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse"]}),
        "targets an instance this spec creates")
    bad(lambda s: s["ops"].append({"id": "x", "kind": "source", "class": "ModuleScript", "before": "before/A.lua",
                                   "after": "after/A.lua",
                                   "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse", "New"]}),
        "another op already targets")


@test
def attribute_prior_value_must_be_recorded():
    bad(lambda s: s["ops"][2].pop("before"), "before must be recorded")
    bad(lambda s: s["ops"][2].pop("after"), "after must be recorded")
    bad(lambda s: s["ops"][2].update(after=None), "before and after are identical")
    bad(lambda s: s["ops"][2].update(key="bad key"), "bad key")
    bad(lambda s: s["ops"][2].update(was="Draft"), "was must be a list")
    bad(lambda s: s["ops"][2].update(kind="property"), "a value is required")
    bad(lambda s: s["ops"][2].update(kind="property", before="x", key="Name"), "not property ops")
    spec = good_spec()
    spec["ops"][2].update(before="Classic", after=None, was=["Draft"])
    op = validate(spec)[0][2]
    assert op["before"] == "Classic" and "after" not in op and op["was"] == ["Draft"]


@test
def transactions_cannot_be_mixed_in_a_spec():
    bad(lambda s: s["ops"][3].update(transaction="hierarchy"), "never mixed")
    bad(lambda s: s["ops"][2].update(transaction="sources"), "never mixed")
    spec = good_spec()
    spec["ops"][3]["transaction"] = "sources"
    assert validate(spec)[0][3]["transaction"] == "sources"


@test
def tree_expands_to_marked_creates():
    spec = good_spec()
    spec["ops"] = [{"id": "kit", "kind": "tree", "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse"], "tree": {
        "class": "Folder", "children": [
            {"name": "Views", "class": "Folder", "attributes": {"Order": 1}, "children": [
                {"name": "New", "class": "ModuleScript", "after": "after/New.lua"}]},
            {"name": "Config", "class": "Configuration"}]}}]
    ops, _ = validate(spec)
    assert [op["id"] for op in ops] == ["kit", "kit/Views", "kit/Views/New", "kit/Config"]
    assert [op.get("parentOp") for op in ops] == [None, "kit", "kit/Views", "kit"]
    assert ops[2]["path"][-2:] == ["Views", "New"] and ops[2]["mark"] == "demo:kit/Views/New"
    assert all(op["kind"] == "create" and op["transaction"] == "hierarchy" for op in ops)
    spec["ops"][0]["tree"]["children"].append({"name": "Views", "class": "Folder"})
    raises(lambda: validate(spec), "unique simple name")


# ------------------------------------------------------------------------------------------------- block matrix

def classify(op_id, obs, parent_state=""):
    op = next(op for op in vectors.OPS if op["id"] == op_id)
    return plan.classify(op, obs, parent_state)


@test
def source_hash_matrix():
    base = {"exists": True, "className": "LocalScript"}
    assert classify("base", dict(base, fp="B")) == ("before", "")
    assert classify("base", dict(base, fp="A")) == ("after", "")
    assert classify("base", dict(base, fp="P")) == ("prior", "")
    state, reason = classify("base", dict(base, fp="X"))
    assert state == "blocked" and "no recorded hash" in reason and "X" in reason
    assert classify("base", {"exists": False})[0] == "blocked"
    assert classify("base", dict(base, className="ModuleScript", fp="B"))[0] == "blocked"
    assert classify("base", {"ambiguous": True})[0] == "blocked"
    assert classify("map", {"exists": True, "className": "ModuleScript", "fp": "P"})[0] == "blocked", "prior is per op"


@test
def create_mark_matrix():
    there = {"exists": True, "parentExists": True, "className": "Folder", "foreignChildren": []}
    assert classify("kit", {"exists": False, "parentExists": True}) == ("before", "")
    assert classify("kit", {"exists": False, "parentExists": False})[0] == "blocked"
    assert classify("kit", dict(there, mark="v:kit")) == ("after", "")
    assert "not created by this installer" in classify("kit", there)[1]
    assert classify("kit", dict(there, mark="v:probe"))[0] == "blocked"
    assert classify("kit", dict(there, mark="v:kit", className="Model"))[0] == "blocked"
    module = dict(there, className="ModuleScript", mark="v:probe")
    assert classify("probe", dict(module, fp="N2")) == ("after", "")
    assert classify("probe", dict(module, fp="N1")) == ("prior", "")
    assert "edited since install" in classify("probe", dict(module, fp="X"))[1]
    assert classify("probe", {"exists": False, "parentExists": False}, "before") == ("before", "")
    assert classify("probe", {"exists": False, "parentExists": False}, "after")[0] == "blocked"
    assert classify("probe", {"exists": False, "parentExists": False}, "blocked")[0] == "blocked"


@test
def rollback_refuses_children_it_did_not_create():
    kit = vectors.OPS[0]
    obs = {"exists": True, "parentExists": True, "className": "Folder", "mark": "v:kit", "foreignChildren": ["Stray"]}
    assert "Stray" in plan.rollback_block(kit, obs, "after")
    assert plan.rollback_block(kit, dict(obs, foreignChildren=[]), "after") == ""
    assert plan.rollback_block(kit, obs, "before") == ""
    world = dict(vectors.WORLDS["all after"], kit="children added")
    observations = vectors.observations_for(world)
    results = plan.classify_all(vectors.OPS, observations)
    rollback = plan.decide("ROLLBACK", vectors.OPS, results, GATE)
    assert not rollback["write"] and any("Notes, Stray" in b for b in rollback["blockers"])
    # APPLY and AUDIT are not affected by it.
    assert plan.decide("APPLY", vectors.OPS, results, GATE)["blockers"] == []
    assert plan.decide("AUDIT", vectors.OPS, results, GATE)["blockers"] == []


@test
def attribute_edited_since_blocks_both_directions():
    assert classify("style", {"exists": True, "match": "before"}) == ("before", "")
    assert classify("style", {"exists": True, "match": "after"}) == ("after", "")
    assert classify("style", {"exists": True, "match": "prior"}) == ("prior", "")
    assert classify("style", {"exists": True, "match": "other"}) == ("blocked", "value was edited since it was recorded")
    assert classify("style", {"exists": False})[0] == "blocked"
    for world_name in ("all before", "all after"):
        observations = vectors.observations_for(dict(vectors.WORLDS[world_name], style="edited since"))
        for mode in ("APPLY", "ROLLBACK"):
            decision = plan.run(mode, vectors.OPS, observations)
            assert not decision["write"] and any(b.startswith("style: ") for b in decision["blockers"])


@test
def nothing_is_written_if_anything_blocks():
    seen_blocked = 0
    for v in vectors.vectors():
        decision = v["decision"]
        if decision["blockers"]:
            seen_blocked += 1
            assert decision["write"] is False, v["name"]
        if v["mode"] == "AUDIT":
            assert decision["write"] is False and decision["actions"] == [], v["name"]
        blocked = [i for i, r in v["results"].items() if r["state"] == "blocked"]
        for op_id in blocked:
            assert any(b.startswith(op_id + ": ") for b in decision["blockers"]), v["name"]
            assert all(a["id"] != op_id for a in decision["actions"]), v["name"]
    assert seen_blocked > 100


@test
def gate_rules():
    observations = vectors.observations_for(vectors.WORLDS["all before"])
    results = plan.classify_all(vectors.OPS, observations)

    def blockers(mode, **gate):
        return plan.decide(mode, vectors.OPS, results, dict(GATE, **gate))["blockers"]

    for mode in plan.MODES:
        assert blockers(mode, placeOk=False) == ["wrong place"]
        assert blockers(mode, isEdit=False) == ["Studio is not in Edit mode"]
    assert blockers("APPLY", testWindow="StudioVehicleSandboxEveryPlay is true") == [
        "sandbox test window is open: StudioVehicleSandboxEveryPlay is true"]
    assert blockers("AUDIT", testWindow="x") == [] and blockers("ROLLBACK", testWindow="x") == []
    assert blockers("APPLY", notInstallable=True) and blockers("ROLLBACK", notInstallable=True)
    assert blockers("AUDIT", notInstallable=True) == []
    assert blockers("INSTALL") == ["unknown mode INSTALL"]


# ------------------------------------------------------------------------------------------ transaction ordering

@test
def one_run_writes_one_transaction():
    for v in vectors.vectors():
        kinds = {plan.transaction_of(next(op for op in vectors.OPS if op["id"] == a["id"]))
                 for a in v["decision"]["actions"]}
        assert len(kinds) <= 1, v["name"]
        if kinds:
            assert kinds == {v["decision"]["transaction"]}, v["name"]


@test
def apply_runs_hierarchy_then_sources_and_rollback_reverses():
    model = plan.baseline_observations(vectors.OPS)
    audit = plan.run("AUDIT", vectors.OPS, model)
    assert audit["states"] == {"hierarchy": "before", "sources": "before"} and not audit["write"]
    first = plan.run("APPLY", vectors.OPS, model)
    assert first["transaction"] == "hierarchy"
    assert [a["id"] for a in first["actions"]] == ["kit", "probe", "style", "label"]
    assert [a["action"] for a in first["actions"]] == ["create", "create", "set", "set"]
    assert model["base"]["fp"] == "B", "a source was written in the hierarchy run"
    mid = plan.run("AUDIT", vectors.OPS, model)
    assert mid["states"] == {"hierarchy": "after", "sources": "before"}
    second = plan.run("APPLY", vectors.OPS, model)
    assert second["transaction"] == "sources" and [a["id"] for a in second["actions"]] == ["base", "map"]
    third = plan.run("APPLY", vectors.OPS, model)
    assert not third["write"] and third["blockers"] == [] and third["transaction"] == ""
    assert plan.run("AUDIT", vectors.OPS, model)["states"] == {"hierarchy": "after", "sources": "after"}
    back = plan.run("ROLLBACK", vectors.OPS, model)
    assert back["transaction"] == "sources" and [a["id"] for a in back["actions"]] == ["map", "base"]
    assert model["kit"]["exists"], "the hierarchy was rolled back in the sources run"
    back = plan.run("ROLLBACK", vectors.OPS, model)
    assert back["transaction"] == "hierarchy"
    assert [(a["id"], a["action"]) for a in back["actions"]] == [
        ("label", "reset"), ("style", "reset"), ("probe", "remove"), ("kit", "remove")]
    assert not plan.run("ROLLBACK", vectors.OPS, model)["write"]
    assert plan.run("AUDIT", vectors.OPS, model)["states"] == {"hierarchy": "before", "sources": "before"}


@test
def partial_and_prior_states():
    model = vectors.observations_for(vectors.WORLDS["half sources"])
    assert plan.run("AUDIT", vectors.OPS, model)["states"]["sources"] == "mixed"
    apply = plan.run("APPLY", vectors.OPS, copy.deepcopy(model))
    assert [a["id"] for a in apply["actions"]] == ["map"]
    rollback = plan.run("ROLLBACK", vectors.OPS, copy.deepcopy(model))
    assert [a["id"] for a in rollback["actions"]] == ["base"]
    model = vectors.observations_for(dict(vectors.WORLDS["all after"], probe="prior", base="prior"))
    apply = plan.run("APPLY", vectors.OPS, model)
    assert apply["transaction"] == "hierarchy" and apply["actions"] == [{"id": "probe", "action": "rewrite"}]
    apply = plan.run("APPLY", vectors.OPS, model)
    assert apply["transaction"] == "sources" and apply["actions"] == [{"id": "base", "action": "write"}]


@test
def an_op_declared_in_the_wrong_transaction_is_refused_at_run_time():
    ops = vectors.mixed_ops()
    for mode in plan.MODES:
        decision = plan.run(mode, ops, plan.baseline_observations(ops))
        assert not decision["write"]
        assert decision["blockers"] == ["base: refusing to mix transactions (source op declared in hierarchy)"]


@test
def dry_run_reports_the_delivery_order():
    with Phase(good_spec()) as path:
        ops, _ = build.validate(good_spec(), path)
    lines = build.dry_run(ops)
    assert [line.split()[:2] for line in lines] == [
        ["APPLY", "hierarchy"], ["APPLY", "sources"], ["ROLLBACK", "sources"], ["ROLLBACK", "hierarchy"],
        ["APPLY", "hierarchy"], ["APPLY", "sources"]]
    only_sources = [op for op in ops if op["kind"] == "source"]
    assert [line.split()[:2] for line in build.dry_run(only_sources)] == [
        ["APPLY", "sources"], ["ROLLBACK", "sources"], ["APPLY", "sources"]]


# ---------------------------------------------------------------------------------------------- build and guards

@test
def size_guard():
    at_limit = "-- " + "x" * (build.MAX_SOURCE_CHARS - 4) + "\n"
    assert len(at_limit) == build.MAX_SOURCE_CHARS
    validate(good_spec(), {"after/A.lua": at_limit})
    raises(lambda: validate(good_spec(), {"after/A.lua": at_limit + "\n"}), "the limit is 150000")
    raises(lambda: validate(good_spec(), {"after/New.lua": at_limit + "\n"}), "the limit is 150000")
    # The limit is characters, not bytes: 150,000 two-byte characters pass.
    validate(good_spec(), {"after/A.lua": "é" * build.MAX_SOURCE_CHARS})


def unescape(literal):
    out = bytearray()
    names = {"n": 10, "r": 13, "t": 9, '"': 34, "\\": 92}
    i = 0
    while i < len(literal):
        if literal[i] != "\\":
            out.append(ord(literal[i]))
            i += 1
        elif literal[i + 1].isdigit():
            out.append(int(literal[i + 1:i + 4]))
            i += 4
        else:
            out.append(names[literal[i + 1]])
            i += 2
    return bytes(out)


def reassemble(parts):
    found = {}
    for text in parts:
        for name, index, literal in re.findall(r'^put\("([^"]+)", (\d+), "((?:[^"\\\n]|\\.)*)"\)$', text, re.M):
            found.setdefault(name, {})[int(index)] = unescape(literal)
    return {name: b"".join(chunks[i] for i in range(1, len(chunks) + 1)) for name, chunks in found.items()}


@test
def inline_parts_split_and_reassemble():
    tricky = ('local s = "quote \\" and backslash \\\\"\n\tlocal t = [==[\nlong ]] string]==]\n-- café 日本\n'
              * 400).encode("utf-8")
    files = [("p/after/A.lua", tricky), ("p/after/Empty.lua", b""), ("p/after/B.lua", b"return 1\n")]
    for limit in (2000, 5000, build.MAX_PART_CHARS):
        parts, counts = build.inline_parts(files, "p/", "apply", "demo:APPLY:1", limit)
        assert all(len(part) < limit for part in parts), limit
        assert all(part.isascii() for part in parts)
        assert reassemble(parts) == dict(files), limit
        assert counts["p/after/Empty.lua"] == 1 and counts["p/after/B.lua"] == 1
        if limit == 2000:
            assert len(parts) > 20 and counts["p/after/A.lua"] > 20
        assert lua_lint("\n".join(parts)) == []
    raises(lambda: build.inline_parts(files, "p/", "apply", "demo:APPLY:1", 300), "too small")


@test
def inline_build_keeps_every_file_under_the_limit():
    big = "".join("local v%d = %d -- é\n" % (i, i) for i in range(6200))
    assert 140000 < len(big) <= build.MAX_SOURCE_CHARS
    spec = good_spec()
    spec["ops"].append({"id": "b", "kind": "source", "class": "ModuleScript", "path": ["ReplicatedStorage", "B"],
                        "before": "before/B.lua", "after": "after/B.lua"})
    files = {"after/A.lua": big, "after/B.lua": big + "-- b\n", "before/B.lua": "return 0\n", "after/New.lua": big}
    with Phase(spec, files) as path:
        out, ops, _ = build.emit(path, inline=True, base="scripts/ui_restyle/demo/", record=False)
        assert sorted(os.listdir(path)) == sorted(list(out) + ["after", "before", "spec.json"])
        assert all(len(text) < build.MAX_PART_CHARS for text in out.values())
        apply_parts = [out[name] for name in sorted(out) if name.startswith("out_apply.part")]
        rollback_parts = [out[name] for name in sorted(out) if name.startswith("out_rollback.part")]
        assert len(apply_parts) >= 3 and len(rollback_parts) == 1
        assert not any(name.startswith("out_audit.part") for name in out)
        got = reassemble(apply_parts)
        assert got == {"scripts/ui_restyle/demo/after/A.lua": big.encode(), "scripts/ui_restyle/demo/after/B.lua":
                       (big + "-- b\n").encode(), "scripts/ui_restyle/demo/after/New.lua": big.encode()}
        assert reassemble(rollback_parts) == {"scripts/ui_restyle/demo/before/A.lua": b"return 1\n",
                                              "scripts/ui_restyle/demo/before/B.lua": b"return 0\n"}
        data = embedded_data(out["out_apply.lua"])
        assert data["inline"] is True and data["build"].startswith("demo:APPLY:")
        assert set(data["inlineFiles"]) == set(got) and data["inlineFiles"]["scripts/ui_restyle/demo/after/A.lua"] >= 1
        assert ('shared.UIRestyleInline["%s"]' % data["build"]) in apply_parts[0]
        # A later non-inline build removes the stale part files.
        build.emit(path, base="scripts/ui_restyle/demo/", record=False)
        assert not [name for name in os.listdir(path) if ".part" in name]


def embedded_data(text):
    start = text.index("JSONDecode([==[") + len("JSONDecode([==[")
    return json.loads(text[start:text.index("]==])", start)])


@test
def emitted_files_are_small_and_carry_the_spec():
    out, ops, _ = build.emit(SAMPLE, record=False, write=False)
    assert sorted(out) == ["out_apply.lua", "out_audit.lua", "out_rollback.lua"]
    library = build.lua_library()
    for mode in build.MODES:
        text = out["out_%s.lua" % mode.lower()]
        assert len(text) < 60000, "the HTTP build must stay small"
        assert text.count('local MODE = "%s"\n' % mode) == 1
        assert library in text and text.endswith(build.read_text(os.path.join(build.HERE, "bootstrap.lua")))
        data = embedded_data(text)
        assert data["ops"] == ops and data["placeId"] == 93959280828322 and data["inline"] is False
        assert data["base"] == SAMPLE_BASE and data["origin"] == "http://127.0.0.1:8796/"
        assert data["markAttribute"] == "UIRestyleInstall" and data["installable"] is False
        assert data["classicVerify"] == "scripts/ui_restyle/classic/out_verify_classic.lua"
        assert "return { sample = true }" not in text, "sources are fetched, not embedded"
    by_id = {op["id"]: op for op in ops}
    assert by_id["probe"]["mark"] == "sample_phase:probe" and by_id["probe"]["transaction"] == "hierarchy"
    assert by_id["clientbase"]["before"] == plan.fingerprint(
        open(os.path.join(SAMPLE, "before", "ClientBase.lua"), "rb").read())


@test
def golden_files_are_deterministic():
    committed = {name: build.read_text(os.path.join(SAMPLE, name))
                 for name in ("out_audit.lua", "out_apply.lua", "out_rollback.lua")}
    root = tempfile.mkdtemp(prefix="ui_restyle_engine_")
    try:
        copy_path = os.path.join(root, "sample_phase")
        shutil.copytree(SAMPLE, copy_path)
        for name in committed:
            os.remove(os.path.join(copy_path, name))
        first, _, _ = build.emit(copy_path, base=SAMPLE_BASE)
        second, _, _ = build.emit(copy_path, base=SAMPLE_BASE)
        assert first == second, "two builds of the same phase differ"
        assert first == committed, "sample_phase/out_*.lua are stale: run build.py on engine/sample_phase"
        assert {name: build.read_text(os.path.join(copy_path, name)) for name in committed} == committed
        history = build.read_text(os.path.join(copy_path, "applied_hashes.json"))
        assert history == build.read_text(os.path.join(SAMPLE, "applied_hashes.json"))
    finally:
        shutil.rmtree(root, ignore_errors=True)


@test
def a_rebuilt_phase_accepts_its_own_earlier_build():
    with Phase(good_spec()) as path:
        _, ops1, _ = build.emit(path, base="x/")
        first_after = {op["id"]: op["after"] for op in ops1 if op["kind"] in ("source", "create") and "after" in op}
        assert all(op["prior"] == [] for op in ops1 if "prior" in op)
        for relative in ("after/A.lua", "after/New.lua"):
            with open(os.path.join(path, *relative.split("/")), "ab") as handle:
                handle.write(b"-- round 2\n")
        _, ops2, _ = build.emit(path, base="x/")
        by_id = {op["id"]: op for op in ops2}
        assert by_id["a"]["prior"] == [first_after["a"]] and by_id["new"]["prior"] == [first_after["new"]]
        _, ops3, _ = build.emit(path, base="x/")
        assert ops3 == ops2, "an unchanged rebuild must not grow the prior list"
        # Round 1's source is now a known state that APPLY upgrades.
        model = plan.baseline_observations(ops2)
        model["a"]["fp"] = first_after["a"]
        assert plan.classify_all(ops2, model)["a"]["state"] == "prior"


@test
def build_cli_reports_failures():
    spec = good_spec()
    spec["ops"][3]["transaction"] = "hierarchy"
    printed = io.StringIO()
    with contextlib.redirect_stdout(printed):
        with Phase(spec) as path:
            assert build.main([path, "--no-record"]) == 1
            assert not os.path.exists(os.path.join(path, "out_apply.lua"))
        assert build.main([]) == 2 and build.main(["a", "b"]) == 2 and build.main(["a", "--bogus"]) == 2
    assert "BUILD FAILED: op a: a source op belongs to the sources transaction" in printed.getvalue()
    with Phase(good_spec()) as path:
        raises(lambda: build.emit(path, record=False), "inside the repository")


# ------------------------------------------------------------------------------------------------------ the Lua

def lua_tokens(text):
    """Code tokens of a Luau chunk with comments and string contents removed."""
    pattern = re.compile(r"""
        --\[(=*)\[.*?\]\1\]            # long comment
      | --[^\n]*                        # line comment
      | \[(=*)\[.*?\]\2\]              # long string
      | "(?:[^"\\\n]|\\.)*"             # string
      | '(?:[^'\\\n]|\\.)*'             # string
      | [A-Za-z_][A-Za-z0-9_]*          # word
      | [(){}\[\]]                      # brackets
      | \S                              # anything else
    """, re.S | re.X)
    tokens = []
    for match in pattern.finditer(text):
        token = match.group(0)
        if token.startswith("--"):
            continue
        tokens.append('""' if token[0] in "\"'" or re.match(r"\[=*\[", token) else token)
    return tokens


def lua_lint(text):
    """Structural problems: unbalanced blocks or brackets, and syntax Luau does not have."""
    tokens = lua_tokens(text)
    problems = []
    count = {word: tokens.count(word) for word in ("function", "do", "if", "end", "repeat", "until", "then")}
    if count["function"] + count["do"] + count["if"] != count["end"]:
        problems.append("blocks: %d openers, %d end" % (count["function"] + count["do"] + count["if"], count["end"]))
    if count["repeat"] != count["until"]:
        problems.append("repeat/until")
    if tokens.count("then") != count["if"] + tokens.count("elseif"):
        problems.append("then count")
    stack = []
    pairs = {")": "(", "}": "{", "]": "["}
    for token in tokens:
        if token in "({[" and len(token) == 1:
            stack.append(token)
        elif token in pairs:
            if not stack or stack.pop() != pairs[token]:
                problems.append("bracket " + token)
                break
    if stack:
        problems.append("unclosed " + "".join(stack))
    joined = " ".join(tokens)
    for wrong in ("! =", "elif", "else if", "None", "True", "False", "null", "+ +", "& &", "| |"):
        if re.search(r"(^| )%s( |$)" % re.escape(wrong), joined):
            problems.append("not Luau: " + wrong)
    return problems


@test
def lua_lint_catches_mistakes():
    assert lua_lint("local function f(a)\n\tif a then\n\t\treturn 1\n\tend\nend\n") == []
    assert lua_lint('local s = "end if (" -- end\nlocal t = [==[ end ]==]\n') == []
    assert lua_lint("if a then\n") and lua_lint("f(a\n") and lua_lint("if a != b then end") and lua_lint("x = None")
    assert lua_lint("for i = 1, 2 do\n\tif i then\n\tend\n")


@test
def lua_sources_are_structurally_sound():
    for name in ("hash.lua", "plan.lua", "engine.lua", "bootstrap.lua", "selftest_body.lua", "selftest.lua"):
        text = build.read_text(os.path.join(HERE, name))
        assert lua_lint(text) == [], "%s: %s" % (name, lua_lint(text))
        assert "\r" not in text and "\t" in text
    out, _, _ = build.emit(SAMPLE, record=False, write=False)
    for name, text in out.items():
        assert lua_lint(text) == [], name


@test
def lua_library_defines_what_the_callers_use():
    library = build.lua_library()
    for needed in ("local Hash = {}", "function Hash.fingerprint(", "local Plan = {}", "function Plan.classify(",
                   "function Plan.classifyAll(", "function Plan.rollbackBlock(", "function Plan.decide(",
                   "function Plan.transactionOf(", "local Engine = {}", "function Engine.run(MODE, DATA, env)",
                   "function Engine.loadChunk(", "function Engine.classicVerify("):
        assert library.count(needed) == 1, needed
    # Order matters: the files are concatenated and each uses the ones above it.
    assert library.index("local Hash = {}") < library.index("local Plan = {}") < library.index("local Engine = {}")
    engine = build.read_text(os.path.join(HERE, "engine.lua"))
    for call in set(re.findall(r"\b(?:Plan|Hash)\.[A-Za-z]+", engine)):
        assert ("function " + call + "(") in library or (call + " = ") in library, call
    for field in set(re.findall(r"\benv\.([A-Za-z]+)", engine)):
        for user in ("bootstrap.lua", "selftest_body.lua"):
            assert re.search(r"\b%s = " % field, build.read_text(os.path.join(HERE, user))), (user, field)
    # The engine itself reaches the place only through env: no services, no direct Source access.
    code = " ".join(lua_tokens(engine))
    assert "game" not in lua_tokens(engine) and ". Source" not in code and "GetService" not in code


@test
def plan_lua_mirrors_plan_py_messages():
    lua = build.read_text(os.path.join(HERE, "plan.lua"))
    python = build.read_text(os.path.join(HERE, "plan.py"))
    body = python[python.index("def transaction_of"):python.index("# -----")]
    messages = re.findall(r'(?:return "blocked", |blockers\.append\(|return )"([^"]+)"', body)
    assert len(messages) >= 20, len(messages)
    for message in messages:
        for fragment in re.split(r"%[sd]", message):
            assert fragment in lua, "plan.lua lacks %r" % fragment
    for state in ("before", "after", "prior", "blocked", "mixed", "empty", "hierarchy", "sources", "create", "rewrite",
                  "remove", "reset", "restore", "write", "set"):
        assert '"%s"' % state in lua and '"%s"' % state in python, state


@test
def selftest_is_current_and_fits_one_command():
    text = build.read_text(os.path.join(HERE, "selftest.lua"))
    assert text == build.selftest_text(), "selftest.lua is stale: run build.py --selftest"
    assert len(text) < build.MAX_PART_CHARS and text.isascii()
    cases = embedded_data(text)
    assert len(cases["cases"]) == len(vectors.vectors()) > 150 and len(cases["hashes"]) >= 5
    assert text.count("\ncase(") >= 25
    # It must not touch the DataModel: no service but HttpService, nothing parented to game.
    body = build.read_text(os.path.join(HERE, "selftest_body.lua"))
    assert re.findall(r'GetService\("(\w+)"\)', body) == ["HttpService"]
    tokens = lua_tokens(body)
    assert tokens.count("game") == 2 and "workspace" not in tokens, "selftest may only use game for HttpService/IsDescendantOf"


@test
def vectors_cover_the_block_matrix():
    names = [v["name"] for v in vectors.vectors()]
    assert len(names) == len(set(names))
    for needed in ("base unknown", "base prior", "kit unmarked", "kit children added", "probe edited",
                   "style edited since", "mixed transaction", "gate 3"):
        assert any(needed in name for name in names), needed
    by_name = {v["name"]: v for v in vectors.vectors()}
    v = by_name["all before / APPLY"]["decision"]
    assert v["transaction"] == "hierarchy" and v["write"] and len(v["actions"]) == 4
    v = by_name["all after, kit children added / ROLLBACK"]["decision"]
    assert not v["write"] and v["blockers"] == ["kit: has children this installer did not create: Notes, Stray"]
    v = by_name["all before, base unknown / APPLY"]["decision"]
    assert not v["write"] and v["states"] == {"hierarchy": "before", "sources": "blocked"}


def main():
    failed = skipped = 0
    for fn in TESTS:
        try:
            result = fn()
        except Exception as error:  # noqa: BLE001
            failed += 1
            print("FAIL %s: %s: %s" % (fn.__name__, type(error).__name__, error))
            continue
        if isinstance(result, str) and result.startswith("skipped"):
            skipped += 1
            print("SKIP %s (%s)" % (fn.__name__, result))
    print("%d tests, %d failed, %d skipped" % (len(TESTS), failed, skipped))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
