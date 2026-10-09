"""Decision logic of the UI restyle installer engine. Pure: no files, no Studio.

plan.lua is the line-for-line Luau mirror of this file. build.py uses this module for validation and the offline
dry run; test_engine.py tests it; selftest.lua replays vectors made here against plan.lua inside Studio, so the two
cannot drift without a failing case.

Conventions shared with plan.lua (JSON has no nil, so "none" is the empty string):
  state      "before" | "after" | "prior" | "blocked"
  reason     "" when not blocked
  rollback   "" when ROLLBACK may undo the op, else why it refuses

An observation is what the engine read from the place for one op:
  source     exists, ambiguous, className, fp
  create     parentExists, exists, ambiguous, className, mark, fp (scripts only), foreignChildren [names]
  attribute  exists, ambiguous, match ("before" | "after" | "prior" | "other")
  property   as attribute
"""

MODES = ("AUDIT", "APPLY", "ROLLBACK")
TRANSACTIONS = ("hierarchy", "sources")
HIERARCHY_KINDS = ("create", "attribute", "property")


def djb2(data):
    x = 5381
    for b in data:
        x = (x * 33 + b) % 4294967296
    return x


def fnv1a32(data):
    x = 2166136261
    for b in data:
        x = ((x ^ b) * 16777619) % 4294967296
    return x


def fingerprint(data):
    """data: bytes. Mirror of Hash.fingerprint in hash.lua."""
    return "%d-%d-%d" % (djb2(data), fnv1a32(data), len(data))


def transaction_of(op):
    if op["kind"] == "source":
        return "sources"
    if op["kind"] in HIERARCHY_KINDS:
        return "hierarchy"
    return ""


def classify(op, obs, parent_state=""):
    """-> (state, reason). parent_state is the state of the create op that makes this op's parent, or ""."""
    if obs.get("ambiguous"):
        return "blocked", "ambiguous path: two instances share a name"
    kind = op["kind"]
    if kind == "source":
        if not obs.get("exists"):
            return "blocked", "script is missing"
        if obs.get("className") != op["class"]:
            return "blocked", "class is %s, expected %s" % (obs.get("className"), op["class"])
        if obs.get("fp") == op["after"]:
            return "after", ""
        if obs.get("fp") == op["before"]:
            return "before", ""
        if obs.get("fp") in op.get("prior", []):
            return "prior", ""
        return "blocked", "source matches no recorded hash (%s)" % obs.get("fp")
    if kind == "create":
        if not obs.get("exists"):
            if obs.get("parentExists") or parent_state == "before":
                return "before", ""
            return "blocked", "parent is missing"
        if obs.get("className") != op["class"]:
            return "blocked", "exists as %s, expected %s" % (obs.get("className"), op["class"])
        if obs.get("mark") != op["mark"]:
            return "blocked", "exists and was not created by this installer (install mark absent or different)"
        if op.get("after") is None:
            return "after", ""
        if obs.get("fp") == op["after"]:
            return "after", ""
        if obs.get("fp") in op.get("prior", []):
            return "prior", ""
        return "blocked", "created script was edited since install (%s)" % obs.get("fp")
    if kind in ("attribute", "property"):
        if not obs.get("exists"):
            return "blocked", "target instance is missing"
        match = obs.get("match")
        if match in ("after", "before", "prior"):
            return match, ""
        return "blocked", "value was edited since it was recorded"
    return "blocked", "unknown op kind"


def rollback_block(op, obs, state):
    """Why ROLLBACK must refuse this op even though its state is known, or ""."""
    if op["kind"] == "create" and state in ("after", "prior"):
        foreign = obs.get("foreignChildren") or []
        if foreign:
            return "has children this installer did not create: " + ", ".join(foreign)
    return ""


def classify_all(ops, observations):
    """-> {id: {"state", "reason", "rollback"}}. A create op's parent op always comes earlier in ops."""
    results = {}
    for op in ops:
        obs = observations[op["id"]]
        parent = results.get(op.get("parentOp") or "")
        state, reason = classify(op, obs, parent["state"] if parent else "")
        results[op["id"]] = {"state": state, "reason": reason, "rollback": rollback_block(op, obs, state)}
    return results


def transaction_state(name, ops, results):
    states = [results[op["id"]]["state"] for op in ops if transaction_of(op) == name]
    if not states:
        return "empty"
    if "blocked" in states:
        return "blocked"
    if all(s == "after" for s in states):
        return "after"
    if all(s == "before" for s in states):
        return "before"
    return "mixed"


def action_for(mode, op, state):
    kind = op["kind"]
    if mode == "APPLY":
        if kind == "source":
            return "write"
        if kind == "create":
            return "create" if state == "before" else "rewrite"
        return "set"
    if kind == "source":
        return "restore"
    if kind == "create":
        return "remove"
    return "reset"


def decide(mode, ops, results, gate):
    """One run writes at most ONE transaction.

    APPLY order: hierarchy, then sources. ROLLBACK order: sources, then hierarchy (ops in reverse).
    gate: placeOk, isEdit, testWindow ("" or why the sandbox test window counts as open), notInstallable.
    -> {"blockers": [...], "states": {name: state}, "transaction": name or "", "actions": [{"id", "action"}],
        "write": bool}
    """
    blockers = []
    if mode not in MODES:
        blockers.append("unknown mode " + str(mode))
    if not gate.get("placeOk"):
        blockers.append("wrong place")
    if not gate.get("isEdit"):
        blockers.append("Studio is not in Edit mode")
    if mode != "AUDIT" and gate.get("notInstallable"):
        blockers.append("this phase is marked not installable")
    if mode == "APPLY" and gate.get("testWindow"):
        blockers.append("sandbox test window is open: " + gate["testWindow"])
    for op in ops:
        txn = transaction_of(op)
        if txn == "" or op.get("transaction", txn) != txn:
            blockers.append("%s: refusing to mix transactions (%s op declared in %s)" % (
                op["id"], op["kind"], op.get("transaction", "?")))
        result = results[op["id"]]
        if result["state"] == "blocked":
            blockers.append("%s: %s" % (op["id"], result["reason"]))
        elif mode == "ROLLBACK" and result["rollback"]:
            blockers.append("%s: %s" % (op["id"], result["rollback"]))
    states = {name: transaction_state(name, ops, results) for name in TRANSACTIONS}
    want = "before" if mode == "ROLLBACK" else "after"
    order = list(TRANSACTIONS)
    ordered = list(ops)
    if mode == "ROLLBACK":
        order.reverse()
        ordered.reverse()
    transaction, actions = "", []
    if mode in ("APPLY", "ROLLBACK"):
        for name in order:
            pending = [op for op in ordered if transaction_of(op) == name and results[op["id"]]["state"] != want]
            if pending:
                transaction = name
                actions = [{"id": op["id"], "action": action_for(mode, op, results[op["id"]]["state"])}
                           for op in pending if results[op["id"]]["state"] != "blocked"]
                break
    return {"blockers": blockers, "states": states, "transaction": transaction, "actions": actions,
            "write": not blockers and len(actions) > 0}


# ---------------------------------------------------------------------------------------------------------------
# Offline model of a place, used by the dry run and the tests. It holds one observation per op and applies the
# effect each action has in the engine, so a whole AUDIT / APPLY / ROLLBACK sequence can be replayed without Studio.

def baseline_observations(ops):
    """Every op in its recorded before state: scripts at their before-hash, nothing created, values untouched."""
    observations = {}
    for op in ops:
        if op["kind"] == "source":
            observations[op["id"]] = {"exists": True, "className": op["class"], "fp": op["before"]}
        elif op["kind"] == "create":
            observations[op["id"]] = {"exists": False, "parentExists": not op.get("parentOp")}
        else:
            observations[op["id"]] = {"exists": True, "match": "before"}
    return observations


def perform(ops, observations, actions):
    """Applies decide()'s actions to the model in place."""
    by_id = {op["id"]: op for op in ops}
    for item in actions:
        op, obs = by_id[item["id"]], observations[item["id"]]
        action = item["action"]
        if action in ("write", "rewrite"):
            obs["fp"] = op["after"]
        elif action == "restore":
            obs["fp"] = op["before"]
        elif action == "create":
            obs.update(exists=True, parentExists=True, className=op["class"], mark=op["mark"], foreignChildren=[])
            if op.get("after") is not None:
                obs["fp"] = op["after"]
            for child in ops:
                if child.get("parentOp") == op["id"]:
                    observations[child["id"]]["parentExists"] = True
        elif action == "remove":
            observations[item["id"]] = {"exists": False, "parentExists": True}
            for child in ops:
                if child.get("parentOp") == op["id"]:
                    observations[child["id"]]["parentExists"] = False
        elif action == "set":
            obs["match"] = "after"
        elif action == "reset":
            obs["match"] = "before"
        else:
            raise ValueError("unknown action " + action)


def run(mode, ops, observations, gate=None):
    """One engine run against the model. -> decide() result plus "results"."""
    gate = gate or {"placeOk": True, "isEdit": True, "testWindow": "", "notInstallable": False}
    results = classify_all(ops, observations)
    decision = decide(mode, ops, results, gate)
    if decision["write"]:
        txn = decision["transaction"]
        for item in decision["actions"]:
            op = next(o for o in ops if o["id"] == item["id"])
            assert transaction_of(op) == txn, "refusing to mix transactions"
        perform(ops, observations, decision["actions"])
    decision["results"] = results
    return decision
