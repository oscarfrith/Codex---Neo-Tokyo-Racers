#!/usr/bin/env python3
"""Parity check of one family (API2 6.5, CONTRACT.md step 5).

    py -3 parity_check.py <family> [--json] [--all]

Three comparisons; each prints a table and any open row gives exit code 1.

A. Declaration against Classic. Each Pulse owner in contract.json (and contract_a/_b) is compared with the generated
   Classic contract classic/contracts/<Owner>.json of every script in its "replaces": remote actions and payload
   keys, remote listens, bindables fired / connected / invoked / handled, player attributes read / written /
   listened, ScreenGui names and DisplayOrder, reserved child names (names another Classic script looks up),
   context actions, render steps, audio cues.
     missing = Classic has it, the declaration does not   -> must be covered by a "dropped" entry
     extra   = the declaration has it, Classic does not    -> must be covered by an "added" entry
     changed = same item, different payload keys / order   -> must be covered by either
   An entry covers a row when its "item" text names the row's key word and its "reason" cites a section
   (for example "API2 5.2"). Rows that are covered are listed with --all only.

B. Declaration against the Pulse code. The same facts are extracted from the family's after-sources, twice and
   independently: with tools/extract_contracts.py (the Classic extractor, imported) and with a plain token scan for
   InvokeServer, FireServer, call(remote, "Action", {...}), :Fire(, :Invoke(, SetAttribute and Layers.Create.
     undeclared = the code does it, no owner of the family declares it
     not in code = an owner declares it, no family source contains the name
   Neither can be waved through with dropped / added: fix the code or the declaration.

C. Single listeners (API2 6.7): a bindable whose handler sends a remote is connected by one Pulse owner only,
   checked over the contract.json of every family on disk.

Fork-built sources are used when build_forks.py has run. Stdlib only; reads text, never Studio.
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
from common import ToolError  # noqa: E402
import lint_phase2  # noqa: E402

sys.path.insert(0, os.path.join(common.RESTYLE, "tools"))
import extract_contracts as ec  # noqa: E402

base = lint_phase2.base
STRICT_KINDS = {"player", "player?", "playerGui", "playerScripts", "character", "workspace"}
SINGLE_LISTENERS = {"StartRaceQueueRequest", "RaceEntryLegacyAction", "OpenRaceBrowser", "OpenOwnedGarageBrowser"}
REFERENCE = re.compile(r"\d+\.\d+|section\s+\d+|§\s*\d+", re.I)
DIRS = {"fires": "fire", "connects": "connect", "invokes": "invoke", "handlers": "handle"}


def leaf(name):
    return str(name).replace("/", ".").split(".")[-1] if name is not None else None


def remote_leaves(text):
    """Leaf names a Classic remote string may stand for ("<unresolved> ... one of: A | B" gives both)."""
    if not isinstance(text, str):
        return set()
    return {part.strip().split(".")[-1] for part in re.split(r"[|:]", text) if "." in part}


def classic_side(names):
    """-> (facts, [scripts], [unknown names]) merged over the Classic owners an owner replaces."""
    facts = {"remotes": {}, "listens": set(), "bindables": {}, "attributes": {}, "screenGuis": {}, "names": {},
             "contextActions": set(), "renderSteps": set(), "audio": set(), "other_attributes": 0, "loose": set()}
    scripts, unknown = [], []
    reserved = common.read_json(os.path.join(common.CONTRACTS, "_reserved_names.json"))["names"]
    for name in names:
        contract = lint_phase2.classic_contract(name)
        if contract is None:
            unknown.append(name)
            continue
        script = contract["script"]
        scripts.append(script)
        for call in contract["remotes"]["calls"]:
            kind = "invoke" if call.get("method") == "InvokeServer" else "fire"
            entry = facts["remotes"].setdefault((kind, call.get("action")), {"keys": None, "leaves": set(), "lines": []})
            entry["leaves"] |= remote_leaves(call.get("remote"))
            entry["lines"].append(call.get("line"))
            if call.get("payload_keys") is not None:
                entry["keys"] = set(entry["keys"] or ()) | set(call["payload_keys"])
        for item in contract["remotes"]["listens"]:
            for one in remote_leaves(item.get("remote")) or {str(item.get("remote"))}:
                facts["listens"].add(one)
        for group, direction in DIRS.items():
            for item in contract["bindables"].get(group, []):
                if isinstance(item.get("name"), str):
                    entry = facts["bindables"].setdefault((item["name"], direction), {"keys": None})
                    if item.get("payload_keys") is not None:
                        entry["keys"] = set(entry["keys"] or ()) | set(item["payload_keys"])
        for group, direction in (("reads", "read"), ("writes", "write"), ("listens", "listen")):
            for item in contract["attributes"].get(group, []):
                if not isinstance(item.get("name"), str):
                    continue
                if item.get("receiver_kind") in STRICT_KINDS:
                    facts["attributes"][(item["name"], direction)] = item.get("receiver_kind")
                else:
                    facts["loose"].add((item["name"], direction))
                    if item.get("receiver_kind") not in ("config", "config?"):
                        facts["other_attributes"] += 1
        for gui in contract["screenguis"]["created"]:
            if gui.get("class") == "ScreenGui" and isinstance(gui.get("Name"), str):
                facts["screenGuis"][gui["Name"]] = gui.get("DisplayOrder")
        for action in contract.get("context_actions", []):
            if isinstance(action.get("name"), str) and "Unbind" not in str(action.get("method")):
                facts["contextActions"].add(action["name"])
        for step in contract["run_service"]["render_steps"]:
            if isinstance(step.get("name"), str) and step.get("method") == "BindToRenderStep":
                facts["renderSteps"].add(step["name"])
        for call in contract["audio"]["bridge_calls"]:
            if isinstance(call.get("cue"), str):
                facts["audio"].add(call["cue"])
        gui_names = {gui.get("Name") for gui in contract["screenguis"]["created"] if isinstance(gui.get("Name"), str)}
        for name_, row in reserved.items():
            if any(definer.get("script") == script for definer in row.get("definers", [])):
                consumers = sorted({c.get("script", "?").split(".")[-1] for c in row.get("consumers", [])})
                # Strong: another script compares instance names with it (the onboarding targets), or looks it up
                # under a ScreenGui this owner creates. Otherwise the name is common and the match may be chance.
                strong = any(c.get("method") == "NameCompare" or any(
                    g in str(c.get("receiver_path") or "").split(".") for g in gui_names) for c in row.get("consumers", []))
                previous = facts["names"].get(name_)
                facts["names"][name_] = {"consumers": consumers, "strong": strong or bool(previous and previous["strong"])}
    return facts, scripts, unknown


def attribute_names(name):
    """An agent may list several attributes of one instance in one entry: "A, B, C"."""
    return [part.strip() for part in str(name).split(",") if part.strip()]


def declared_side(owner, problems):
    facts = {"remotes": {}, "listens": set(), "bindables": {}, "attributes": {}, "screenGuis": {}, "names": {},
             "contextActions": set(), "renderSteps": set(), "audio": set()}
    where = owner["owner"].split(".")[-1]

    def rows(key):
        value = owner.get(key, [])
        if not isinstance(value, list):
            problems.append("%s: \"%s\" must be a list" % (where, key))
            return []
        return value

    for row in rows("remotes"):
        if not isinstance(row, dict) or not isinstance(row.get("remote"), str):
            problems.append("%s: a remotes entry needs remote, kind, action, keys" % where)
            continue
        kind = str(row.get("kind", "invoke")).lower()
        kind = "invoke" if kind.startswith("invoke") else "fire"
        facts["remotes"][(kind, row.get("action"))] = {
            "keys": set(row["keys"]) if isinstance(row.get("keys"), list) else None, "leaves": {leaf(row["remote"])}}
    for row in rows("listens"):
        name = row.get("remote") or row.get("name") if isinstance(row, dict) else row
        if isinstance(name, str):
            facts["listens"].add(leaf(name))
    for row in rows("bindables"):
        if not isinstance(row, dict) or not isinstance(row.get("name"), str) or row.get("dir") not in ("fire", "connect", "invoke", "handle"):
            problems.append("%s: a bindables entry needs name and dir (fire | connect | invoke | handle): %r" % (where, row))
            continue
        facts["bindables"][(leaf(row["name"]), row["dir"])] = {
            "keys": set(row["keys"]) if isinstance(row.get("keys"), list) else None}
    for row in rows("attributes"):
        if not isinstance(row, dict) or not isinstance(row.get("name"), str) or row.get("dir") not in ("read", "write", "listen"):
            problems.append("%s: an attributes entry needs on, name and dir (read | write | listen): %r" % (where, row))
            continue
        for name in attribute_names(row["name"]):
            facts["attributes"][(name, row["dir"])] = row.get("on")
    for row in rows("screenGuis"):
        if isinstance(row, dict) and isinstance(row.get("name"), str):
            facts["screenGuis"][row["name"]] = row.get("displayOrder")
        elif isinstance(row, str):
            facts["screenGuis"][row] = None
    for key in ("names", "contextActions", "renderSteps", "audio"):
        for row in rows(key):
            name = row if isinstance(row, str) else (row.get("name") or row.get("cue")) if isinstance(row, dict) else None
            if isinstance(name, str):
                if key == "names":
                    facts["names"][name] = {"consumers": [], "strong": True}
                else:
                    facts[key].add(name)
    for key in ("dropped", "added"):
        for row in rows(key):
            if not isinstance(row, dict) or not isinstance(row.get("item"), str) or not isinstance(row.get("reason"), str):
                problems.append("%s: a %s entry needs item and reason" % (where, key))
            elif not REFERENCE.search(row["reason"]):
                problems.append("%s: %s entry %r has no section reference in its reason (API2 6.5)" % (where, key, row["item"][:60]))
    return facts


def compare(classic, declared):
    """-> [(category, key word, status, detail)]."""
    rows = []

    def both(category, c_keys, d_keys, word, detail_c=lambda k: "", detail_d=lambda k: ""):
        for key in sorted(set(c_keys) - set(d_keys), key=str):
            rows.append((category, word(key), "missing", detail_c(key)))
        for key in sorted(set(d_keys) - set(c_keys), key=str):
            rows.append((category, word(key), "extra", detail_d(key)))

    def show_action(key):
        return str(key[1]) if key[1] is not None else "<no action>"

    both("remote " + "action", classic["remotes"], declared["remotes"], show_action,
         lambda k: "%s on %s, Classic line %s" % (k[0], "/".join(sorted(classic["remotes"][k]["leaves"])) or "?",
                                                  ",".join(str(n) for n in classic["remotes"][k]["lines"])),
         lambda k: "%s on %s" % (k[0], "/".join(sorted(declared["remotes"][k]["leaves"]))))
    for key in sorted(set(classic["remotes"]) & set(declared["remotes"]), key=str):
        c, d = classic["remotes"][key], declared["remotes"][key]
        if c["leaves"] and not (d["leaves"] & c["leaves"]):
            rows.append(("remote action", show_action(key), "changed", "remote is %s, Classic uses %s" % (
                "/".join(sorted(d["leaves"])), "/".join(sorted(c["leaves"])))))
        if c["keys"] is not None and d["keys"] is not None and c["keys"] != d["keys"]:
            rows.append(("payload keys", show_action(key), "changed", "declared %s; Classic %s" % (
                sorted(d["keys"]), sorted(c["keys"]))))
        elif c["keys"] is not None and c["keys"] and d["keys"] is None:
            rows.append(("payload keys", show_action(key), "changed", "no keys declared; Classic %s" % sorted(c["keys"])))
    both("remote listen", classic["listens"], declared["listens"], str)
    both("bindable", classic["bindables"], declared["bindables"], lambda k: k[0], lambda k: k[1], lambda k: k[1])
    for key in sorted(set(classic["bindables"]) & set(declared["bindables"])):
        c, d = classic["bindables"][key]["keys"], declared["bindables"][key]["keys"]
        if c is not None and d is not None and c != d:
            # The extractor reads keys from table literals only; a wrapper that adds a key hides it. A declared
            # superset is therefore a row to read, not a failure. Remote payload keys stay strict.
            rows.append(("bindable keys", key[0], "review" if d > c else "changed",
                         "declared %s; Classic (literal keys seen) %s" % (sorted(d), sorted(c))))
    c_attr, d_attr = dict(classic["attributes"]), dict(declared["attributes"])
    for (name, direction) in list(c_attr):          # a Classic listen is met by a declared read or listen
        if direction == "listen" and (name, "listen") not in d_attr and (name, "read") in d_attr:
            del c_attr[(name, "listen")]
    for (name, direction) in list(d_attr):
        if direction == "listen" and (name, "listen") not in c_attr and (name, "read") in c_attr:
            del d_attr[(name, "listen")]
    for key in list(d_attr):                        # met by a Classic read on a config or GUI instance
        if key not in c_attr and (key in classic.get("loose", ()) or (key[0], "listen" if key[1] == "read" else key[1]) in classic.get("loose", ())):
            del d_attr[key]
    # A declared READ on an instance that is not the player, PlayerGui or character (a config folder, a vehicle, a
    # world part) has no strict Classic counterpart to compare with: listed for review, not counted.
    for key in sorted(k for k in d_attr if k not in c_attr and k[1] != "write"
                      and str(d_attr[k]).split(".")[0] not in ("Player", "PlayerGui", "Character", "Players")):
        rows.append(("attribute", key[0], "review", "%s on %s" % (key[1], d_attr[key])))
        del d_attr[key]
    both("attribute", c_attr, d_attr, lambda k: k[0], lambda k: "%s on %s" % (k[1], c_attr[k]),
         lambda k: "%s on %s" % (k[1], d_attr[k]))
    both("ScreenGui", classic["screenGuis"], declared["screenGuis"], str,
         lambda k: "DisplayOrder %s" % classic["screenGuis"][k], lambda k: "DisplayOrder %s" % declared["screenGuis"][k])
    for name in sorted(set(classic["screenGuis"]) & set(declared["screenGuis"])):
        c, d = classic["screenGuis"][name], declared["screenGuis"][name]
        if isinstance(c, (int, float)) and c != d:
            rows.append(("ScreenGui order", name, "changed", "declared %s; Classic %s" % (d, c)))
    for name in sorted(set(classic["names"]) - set(declared["names"]) - set(declared["screenGuis"])):
        info = classic["names"][name]
        rows.append(("reserved name", name, "missing" if info["strong"] else "review",
                     ("compared or looked up by " if info["strong"] else "common name; also looked up (maybe elsewhere) by ")
                     + ", ".join(info["consumers"])))
    both("context action", classic["contextActions"], declared["contextActions"], str)
    both("render step", classic["renderSteps"], declared["renderSteps"], str)
    both("audio cue", classic["audio"], declared["audio"], str)
    return rows


def covered_by(row, owner):
    category, word, status, _ = row
    if status == "review":
        return "review only (not counted)"
    lists = {"missing": ("dropped",), "extra": ("added",), "changed": ("dropped", "added")}[status]
    pattern = re.compile(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % re.escape(str(word)))
    for key in lists:
        for entry in owner.get(key) or []:
            if isinstance(entry, dict) and isinstance(entry.get("item"), str) and pattern.search(entry["item"]) \
                    and REFERENCE.search(str(entry.get("reason", ""))):
                return "%s: %s" % (key, entry["reason"])
    return None


# ------------------------------------------------------------------------------------------- B: the Pulse code
def extract_code(sources):
    """sources: {instance path: file}. -> (facts, [notes]). Two independent readings of the same files."""
    facts = {"actions": {}, "fires": {}, "invokes": {}, "writes": {}, "layers": {}, "words": set(), "strings": set()}
    notes = []

    def put(group, name, where, keys=None):
        entry = facts[group].setdefault(name, {"where": [], "keys": set()})
        entry["where"].append(where)
        if keys:
            entry["keys"].update(keys)

    classic_bindables = lint_phase2.classic_facts()["bindable_words"]
    remote_names = lint_phase2.classic_facts()["remote_names"]
    for path in sorted(sources):
        text = common.read_bytes(sources[path]).decode("utf-8", errors="replace")
        toks, _ = base.tokenize(text)
        func_of, func_end = base.structure(toks)
        n = len(toks)
        short = common.short(path)

        def sym(i, value):
            return 0 <= i < n and toks[i].type == "sym" and toks[i].value == value

        wrappers = set(lint_phase2.WRAPPER_NAMES)
        for i, tok in enumerate(toks):
            if tok.type == "str":
                facts["strings"].add(tok.value)
            elif tok.type == "name":
                facts["words"].add(tok.value)
            if tok.type == "name" and tok.value in ("FireServer", "InvokeServer") and sym(i - 1, ":") and sym(i + 1, "("):
                name, params = lint_phase2.enclosing_function(toks, func_of, i)
                close = base.match_paren(toks, i + 1, func_end)
                args = base.split_args(toks, i + 1, close, func_end)
                if args and args[0][1] - args[0][0] == 1 and toks[args[0][0]].value in params:
                    wrappers.add(name.replace(":", ".").split(".")[-1])
        for i, tok in enumerate(toks):
            if tok.type != "name" or not sym(i + 1, "("):
                continue
            where = "%s:%d" % (short, tok.line)
            close = base.match_paren(toks, i + 1, func_end)
            args = base.split_args(toks, i + 1, close, func_end)
            literal = [toks[a].value if b - a == 1 and toks[a].type == "str" else None for a, b in args]
            method = sym(i - 1, ":")
            if (method and tok.value in ("FireServer", "InvokeServer")) or (tok.value in wrappers and toks[i - 1].value != "function"):
                direct = method and tok.value in ("FireServer", "InvokeServer")
                found = lint_phase2.action_argument(toks, args, remote_names, direct)
                if found is not None:
                    action, table = found
                    keys = lint_phase2.table_keys(toks, table, base.match_paren(toks, table, func_end), func_end) if table is not None else None
                    put("actions", action, where, keys)
            elif method and tok.value in ("Fire", "Invoke"):
                receiver = toks[i - 2].value if toks[i - 2].type == "name" else None
                if receiver in classic_bindables:
                    put("fires" if tok.value == "Fire" else "invokes", receiver, where)
            elif method and tok.value == "SetAttribute" and literal and literal[0] is not None:
                put("writes", literal[0], where)
            elif tok.value == "Create" and sym(i - 1, ".") and toks[i - 2].value == "Layers" and literal and literal[0] is not None:
                put("layers", literal[0], where)
    # second reading: the Classic extractor on the same files
    try:
        if not ec.KNOWN_CLASSES:
            for row in common.classic_manifest().values():
                data = common.read_bytes(os.path.join(common.CLASSIC, "sources", row["file"])).decode("utf-8", errors="replace")
                ec.KNOWN_CLASSES.update(ec.INSTANCE_NEW_RE.findall(data))
        scripts = [ec.Script({"path": path, "class": "ModuleScript", "file": os.path.abspath(sources[path])})
                   for path in sorted(sources)]
        extractor = ec.Extractor(scripts)
        for script in scripts:
            extractor.scan(script)
        extractor.expand()
        for script in scripts:
            contract = ec.build_contract(script, [])
            short = common.short(script.path)
            for call in contract["remotes"]["calls"]:
                if isinstance(call.get("action"), str):
                    put("actions", call["action"], "%s:%s (extractor)" % (short, call.get("line")), call.get("payload_keys"))
            for item in contract["bindables"]["fires"]:
                if isinstance(item.get("name"), str):
                    put("fires", item["name"], "%s:%s (extractor)" % (short, item.get("line")))
            for item in contract["bindables"]["invokes"]:
                if isinstance(item.get("name"), str):
                    put("invokes", item["name"], "%s:%s (extractor)" % (short, item.get("line")))
            for item in contract["attributes"]["writes"]:
                if isinstance(item.get("name"), str):
                    put("writes", item["name"], "%s:%s (extractor)" % (short, item.get("line")))
            for gui in contract["screenguis"]["created"]:
                if isinstance(gui.get("Name"), str) and gui.get("class") == "ScreenGui":
                    put("layers", gui["Name"], "%s:%s (extractor: ScreenGui created outside Layers)" % (short, gui.get("line")))
    except Exception as error:      # the extractor was written for Classic sources; say so and keep the token scan
        notes.append("extract_contracts.py could not read the Pulse sources (%s: %s); only the token scan was used" % (
            type(error).__name__, error))
    return facts, notes


def compare_code(owners, code):
    """-> [(category, item, status, detail)] for the whole family."""
    rows = []
    declared = {"actions": {}, "fires": set(), "invokes": set(), "writes": set(), "layers": set(), "mentioned": []}
    for owner in owners:
        who = owner["owner"].split(".")[-1]
        for row in owner.get("remotes") or []:
            if isinstance(row, dict):
                declared["actions"].setdefault(row.get("action"), set()).update(row.get("keys") or [])
                declared["mentioned"].append(("remote action", row.get("action"), who))
                for key in row.get("keys") or []:
                    declared["mentioned"].append(("payload key", key, who))
                if isinstance(row.get("remote"), str):
                    declared["mentioned"].append(("remote name", leaf(row["remote"]), who))
        for row in owner.get("bindables") or []:
            if isinstance(row, dict) and isinstance(row.get("name"), str):
                name = leaf(row["name"])
                if row.get("dir") == "fire":
                    declared["fires"].add(name)
                elif row.get("dir") == "invoke":
                    declared["invokes"].add(name)
                declared["mentioned"].append(("bindable", name, who))
        for row in owner.get("attributes") or []:
            if isinstance(row, dict) and isinstance(row.get("name"), str):
                for name in attribute_names(row["name"]):
                    if row.get("dir") == "write":
                        declared["writes"].add(name)
                    declared["mentioned"].append(("attribute", name, who))
        for row in owner.get("screenGuis") or []:
            name = row.get("name") if isinstance(row, dict) else row
            if isinstance(name, str):
                declared["layers"].add(name)
                declared["mentioned"].append(("ScreenGui", name, who))
        for name in owner.get("names") or []:
            if isinstance(name, str):
                declared["mentioned"].append(("reserved name", name, who))
    for action, entry in sorted(code["actions"].items(), key=str):
        if action not in declared["actions"]:
            rows.append(("remote action", action, "undeclared", ", ".join(entry["where"][:3])))
        else:
            extra = entry["keys"] - declared["actions"][action]
            if extra:
                rows.append(("payload key", "%s: %s" % (action, ", ".join(sorted(extra))), "undeclared", ", ".join(entry["where"][:3])))
    for group, label in (("fires", "bindable fire"), ("invokes", "bindable invoke"), ("writes", "attribute write"),
                         ("layers", "ScreenGui")):
        for name, entry in sorted(code[group].items()):
            if name not in declared[group]:
                rows.append((label, name, "undeclared", ", ".join(entry["where"][:3])))
    seen = set()
    for category, name, who in declared["mentioned"]:
        if name is None or (category, name) in seen:
            continue
        seen.add((category, name))
        derived = category in ("ScreenGui", "reserved name") and any(   # Layers makes <name>Scrim and <name>Live
            name.endswith(suffix) and name[:-len(suffix)] in code["strings"] for suffix in ("Scrim", "Live"))
        if name not in code["strings"] and name not in code["words"] and not derived:
            rows.append((category, name, "not in code", "declared by " + who))
    return rows


def single_listeners(layout):
    rows, holders = [], {}
    names = set(SINGLE_LISTENERS)
    garage = lint_phase2.classic_contract("GarageUI")
    if garage:
        names.update(item["name"] for item in garage["bindables"]["connects"]
                     if isinstance(item.get("name"), str) and item["name"].startswith("Open"))
    for family in common.FAMILIES:
        try:
            owners = common.family_contract(layout.family_dir(family))
        except ToolError:
            continue
        for owner in owners:
            for row in owner.get("bindables") or []:
                if isinstance(row, dict) and row.get("dir") == "connect" and leaf(row.get("name")) in names:
                    holders.setdefault(leaf(row["name"]), []).append("%s (%s)" % (owner["owner"].split(".")[-1], family))
    for name, who in sorted(holders.items()):
        if len(who) > 1:
            rows.append(("single listener", name, "two listeners", "; ".join(who)))
    return rows


def check(layout, family):
    """-> result dict; result["open"] is the number of rows that fail the family."""
    if family not in common.FAMILIES:
        raise ToolError("parity_check: %r is not a family" % family, ["families: " + ", ".join(common.FAMILIES)])
    family_dir = layout.family_dir(family)
    owners = common.family_contract(family_dir)
    if not owners:
        raise ToolError("families/%s has no contract.json (also looked for contract_a.json, contract_b.json)" % family,
                        [family_dir])
    problems, per_owner = [], []
    for owner in owners:
        replaces = owner.get("replaces") or []
        classic, scripts, unknown = classic_side(replaces)
        for name in unknown:
            problems.append("%s replaces %r: no Classic contract with that entry or script name" % (owner["owner"], name))
        declared = declared_side(owner, problems)
        rows = []
        for row in compare(classic, declared):
            cover = covered_by(row, owner)
            rows.append({"category": row[0], "item": row[1], "status": row[2], "detail": row[3], "coveredBy": cover})
        per_owner.append({"owner": owner["owner"], "file": owner.get("_file"), "replaces": replaces, "classic": scripts,
                          "rows": rows, "otherAttributes": classic["other_attributes"]})
    sources, _, forks = common.family_sources(layout, family)
    code_sources = {p: f for p, f in sources.items()
                    if not common.short(p).startswith("Dev.") and p not in common.classic_manifest()}
    code, notes = extract_code(code_sources)
    code_rows = [{"category": r[0], "item": r[1], "status": r[2], "detail": r[3]} for r in compare_code(owners, code)]
    listener_rows = [{"category": r[0], "item": r[1], "status": r[2], "detail": r[3]} for r in single_listeners(layout)]
    if not code_sources:
        problems.append("families/%s/after has no source to check the declaration against" % family)
    open_rows = sum(1 for o in per_owner for r in o["rows"] if not r["coveredBy"]) + len(code_rows) + len(listener_rows)
    return {"family": family, "owners": per_owner, "code": code_rows, "listeners": listener_rows, "problems": problems,
            "notes": notes, "sources": len(code_sources), "forks": sorted(common.short(p) for p in forks),
            "open": open_rows + len(problems)}


def main(argv):
    layout, positional, options = common.parse_args(argv, flags=("--json", "--all"))
    if len(positional) != 1:
        print(__doc__)
        return 2
    result = check(layout, positional[0])
    if "--json" in options:
        print(json.dumps(result, indent=1))
        return 1 if result["open"] else 0
    print("== %s: A. declaration against Classic" % result["family"])
    for owner in result["owners"]:
        shown = [r for r in owner["rows"] if "--all" in options or not r["coveredBy"] or r["status"] == "review"]
        open_count = sum(1 for r in owner["rows"] if not r["coveredBy"])
        print("\n%s  replaces %s  (%d differences, %d covered by dropped/added, %d OPEN)" % (
            common.short(owner["owner"]), ", ".join(owner["replaces"]) or "nothing (Pulse-only)", len(owner["rows"]),
            len(owner["rows"]) - open_count, open_count))
        if owner["otherAttributes"]:
            print("  (%d Classic attribute reads/writes on instances that are not the player, PlayerGui, character or "
                  "workspace are not compared)" % owner["otherAttributes"])
        if shown:
            print(common.table([[r["category"], r["item"], r["status"], r["detail"], r["coveredBy"] or "OPEN"] for r in shown],
                               ["category", "item", "status", "detail", "covered by"]))
    print("\n== %s: B. declaration against the Pulse code (%d sources%s)" % (
        result["family"], result["sources"], ", forks: " + ", ".join(result["forks"]) if result["forks"] else ""))
    for note in result["notes"]:
        print("  note: " + note)
    if result["code"]:
        print(common.table([[r["category"], r["item"], r["status"], r["detail"]] for r in result["code"]],
                           ["category", "item", "status", "detail"]))
    else:
        print("  no difference")
    print("\n== C. single listeners (all families on disk)")
    if result["listeners"]:
        print(common.table([[r["category"], r["item"], r["status"], r["detail"]] for r in result["listeners"]],
                           ["category", "item", "status", "detail"]))
    else:
        print("  no bindable has two Pulse listeners")
    if result["problems"]:
        print("\nproblems in the declaration:")
        for problem in result["problems"]:
            print("  - " + problem)
    print("\n%s: %d open" % (result["family"], result["open"]))
    return 1 if result["open"] else 0


if __name__ == "__main__":
    common.run_main(main)
