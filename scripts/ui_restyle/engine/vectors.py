"""Decision vectors shared by test_engine.py and selftest.lua.

Each vector is one (mode, observations, gate) against a fixed op list, with the results plan.py gives. build.py
embeds them in selftest.lua, where plan.lua must give the same answers. Fingerprints here are short stand-ins.
"""
import copy

import plan

OPS = [
    {"id": "kit", "kind": "create", "transaction": "hierarchy", "class": "Folder",
     "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse"], "mark": "v:kit"},
    {"id": "probe", "kind": "create", "transaction": "hierarchy", "class": "ModuleScript",
     "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse", "Probe"], "mark": "v:probe", "parentOp": "kit",
     "after": "N2", "prior": ["N1"], "file": {"after": "after/Probe.lua"}},
    {"id": "style", "kind": "attribute", "transaction": "hierarchy",
     "path": ["ReplicatedStorage", "Config", "UI"], "key": "Style", "after": "Pulse", "was": ["Draft"]},
    {"id": "label", "kind": "property", "transaction": "hierarchy",
     "path": ["ReplicatedStorage", "Config", "UI", "Label"], "key": "Value", "before": "a", "after": "b"},
    {"id": "base", "kind": "source", "transaction": "sources", "class": "LocalScript",
     "path": ["StarterPlayer", "StarterPlayerScripts", "ClientBase"], "before": "B", "after": "A", "prior": ["P"],
     "file": {"before": "before/ClientBase.lua", "after": "after/ClientBase.lua"}},
    {"id": "map", "kind": "source", "transaction": "sources", "class": "ModuleScript",
     "path": ["ReplicatedStorage", "Modules", "Game", "UI", "FullMapUI"], "before": "MB", "after": "MA",
     "file": {"before": "before/FullMapUI.lua", "after": "after/FullMapUI.lua"}},
]

GATES = [
    {"placeOk": True, "isEdit": True, "testWindow": "", "notInstallable": False},
    {"placeOk": False, "isEdit": True, "testWindow": "", "notInstallable": False},
    {"placeOk": True, "isEdit": False, "testWindow": "", "notInstallable": False},
    {"placeOk": True, "isEdit": True, "testWindow": "StudioVehicleSandboxEveryPlay is true", "notInstallable": False},
    {"placeOk": True, "isEdit": True, "testWindow": "", "notInstallable": True},
]

# Every way one op can be found, by op id.
VARIANTS = {
    "kit": {
        "absent": {"exists": False, "parentExists": True},
        "no parent": {"exists": False, "parentExists": False},
        "marked": {"exists": True, "parentExists": True, "className": "Folder", "mark": "v:kit", "foreignChildren": []},
        "unmarked": {"exists": True, "parentExists": True, "className": "Folder", "foreignChildren": []},
        "other mark": {"exists": True, "parentExists": True, "className": "Folder", "mark": "other:kit",
                       "foreignChildren": []},
        "wrong class": {"exists": True, "parentExists": True, "className": "Model", "mark": "v:kit",
                        "foreignChildren": []},
        "children added": {"exists": True, "parentExists": True, "className": "Folder", "mark": "v:kit",
                           "foreignChildren": ["Notes", "Stray"]},
        "ambiguous": {"ambiguous": True, "exists": False, "parentExists": True},
    },
    "probe": {
        "absent": {"exists": False, "parentExists": True},
        "parent pending": {"exists": False, "parentExists": False},
        "after": {"exists": True, "parentExists": True, "className": "ModuleScript", "mark": "v:probe", "fp": "N2",
                  "foreignChildren": []},
        "prior": {"exists": True, "parentExists": True, "className": "ModuleScript", "mark": "v:probe", "fp": "N1",
                  "foreignChildren": []},
        "edited": {"exists": True, "parentExists": True, "className": "ModuleScript", "mark": "v:probe", "fp": "X",
                   "foreignChildren": []},
        "unmarked": {"exists": True, "parentExists": True, "className": "ModuleScript", "fp": "N2",
                     "foreignChildren": []},
        "children added": {"exists": True, "parentExists": True, "className": "ModuleScript", "mark": "v:probe",
                           "fp": "N2", "foreignChildren": ["Child"]},
    },
    "style": {
        "before": {"exists": True, "match": "before"},
        "after": {"exists": True, "match": "after"},
        "prior": {"exists": True, "match": "prior"},
        "edited since": {"exists": True, "match": "other"},
        "target missing": {"exists": False},
    },
    "label": {
        "before": {"exists": True, "match": "before"},
        "after": {"exists": True, "match": "after"},
        "edited since": {"exists": True, "match": "other"},
        "ambiguous": {"ambiguous": True},
    },
    "base": {
        "before": {"exists": True, "className": "LocalScript", "fp": "B"},
        "after": {"exists": True, "className": "LocalScript", "fp": "A"},
        "prior": {"exists": True, "className": "LocalScript", "fp": "P"},
        "unknown": {"exists": True, "className": "LocalScript", "fp": "X"},
        "missing": {"exists": False},
        "wrong class": {"exists": True, "className": "ModuleScript", "fp": "B"},
        "ambiguous": {"ambiguous": True},
    },
    "map": {
        "before": {"exists": True, "className": "ModuleScript", "fp": "MB"},
        "after": {"exists": True, "className": "ModuleScript", "fp": "MA"},
        "unknown": {"exists": True, "className": "ModuleScript", "fp": "X"},
    },
}

# Whole-place starting points: which variant each op is in.
WORLDS = {
    "all before": {"kit": "absent", "probe": "parent pending", "style": "before", "label": "before",
                   "base": "before", "map": "before"},
    "hierarchy applied": {"kit": "marked", "probe": "after", "style": "after", "label": "after",
                          "base": "before", "map": "before"},
    "all after": {"kit": "marked", "probe": "after", "style": "after", "label": "after",
                  "base": "after", "map": "after"},
    "half sources": {"kit": "marked", "probe": "after", "style": "after", "label": "after",
                     "base": "after", "map": "before"},
}


def observations_for(world):
    return {op_id: copy.deepcopy(VARIANTS[op_id][variant]) for op_id, variant in world.items()}


def expected(mode, ops, observations, gate):
    results = plan.classify_all(ops, observations)
    return {"results": results, "decision": plan.decide(mode, ops, results, gate)}


def vectors():
    """-> [{"name", "mode", "gate" (index), "world", "mixed", "observations", "results", "decision"}], fixed order."""
    out = []

    def add(name, mode, world, gate=0, mixed=False):
        observations = observations_for(world)
        answer = expected(mode, mixed_ops() if mixed else OPS, observations, GATES[gate])
        out.append({"name": name, "mode": mode, "gate": gate, "world": dict(world), "mixed": mixed,
                    "observations": observations, "results": answer["results"], "decision": answer["decision"]})

    for world_name, world in WORLDS.items():
        for mode in plan.MODES:
            add("%s / %s" % (world_name, mode), mode, world)
    # One op moved to each of its variants, from the two settled worlds.
    for world_name in ("all before", "all after"):
        for op_id, variants in VARIANTS.items():
            for variant in variants:
                if WORLDS[world_name][op_id] == variant:
                    continue
                world = dict(WORLDS[world_name], **{op_id: variant})
                for mode in plan.MODES:
                    add("%s, %s %s / %s" % (world_name, op_id, variant, mode), mode, world)
    for gate in range(1, len(GATES)):
        for world_name in ("all before", "all after"):
            for mode in plan.MODES:
                add("%s, gate %d / %s" % (world_name, gate, mode), mode, WORLDS[world_name], gate)
    for mode in plan.MODES:
        add("all before, mixed transaction / %s" % mode, mode, WORLDS["all before"], mixed=True)
    return out


def compact_cases():
    """The vectors in the short form selftest.lua carries (observations are named by world and variant)."""
    order = [op["id"] for op in OPS]
    cases = []
    for v in vectors():
        d = v["decision"]
        cases.append({
            "n": v["name"], "m": v["mode"], "g": v["gate"] + 1, "w": v["world"], "x": v["mixed"],
            "r": [[v["results"][i]["state"], v["results"][i]["reason"], v["results"][i]["rollback"]] for i in order],
            "b": d["blockers"], "s": [d["states"][name] for name in plan.TRANSACTIONS], "t": d["transaction"],
            "a": [[a["id"], a["action"]] for a in d["actions"]], "ok": d["write"],
        })
    return {"ops": OPS, "mixedOps": mixed_ops(), "gates": GATES, "variants": VARIANTS, "cases": cases,
            "hashes": hash_vectors()}


def mixed_ops():
    """The op list with one op declared in the wrong transaction (the engine must refuse it)."""
    ops = copy.deepcopy(OPS)
    ops[4]["transaction"] = "hierarchy"
    return ops


def hash_vectors():
    texts = ["", "a", "return {}\n", "local x = 1\r\n-- café 日本\n", "x" * 700,
             "".join(chr(32 + (i * 7) % 95) for i in range(3000))]
    return [{"text": text, "fp": plan.fingerprint(text.encode("utf-8"))} for text in texts]
