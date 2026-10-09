#!/usr/bin/env python3
"""Generate actions.json for the Pulse garage family (agent F6a) from the Classic source.

Reads   classic/sources/ReplicatedStorage.Modules.Game.Garage.GarageUI.lua
        classic/sources/ReplicatedStorage.Modules.Game.Garage.GarageCatalogClient.lua   (its transport helper)
Writes  actions.json                 every remote call site: remote, action, payload keys and value sources,
                                     the Classic line, the enclosing function and the state that triggers it
        the generated block of       tests/ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageModel_test.lua
                                     (between the BEGIN/END GENERATED ACTIONS markers)

    py -3 gen_actions.py            write both
    py -3 gen_actions.py --check    fail when either differs from what is on disk, or when a call site in the
                                    Pulse model does not equal the Classic call site it cites

Standard library only. Nothing here is typed by hand except TRIGGER, which only adds a readable sentence to a call
site the parser already found (a missing or stale TRIGGER key fails the run).
"""
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))  # scripts/ui_restyle
SOURCES = os.path.join(ROOT, "classic", "sources")
GARAGE_UI = "ReplicatedStorage.Modules.Game.Garage.GarageUI.lua"
CATALOG_CLIENT = "ReplicatedStorage.Modules.Game.Garage.GarageCatalogClient.lua"
MODEL = os.path.join(HERE, "after", "ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageModel.lua")
MODEL_TEST = os.path.join(HERE, "tests", "ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageModel_test.lua")
OUT = os.path.join(HERE, "actions.json")
BEGIN = "-- BEGIN GENERATED ACTIONS (gen_actions.py; do not edit)"
END = "-- END GENERATED ACTIONS"

REMOTES = {
    "Call": "Remotes.Garage.GarageInvoke",
    "Session": "Remotes.UI.GarageSessionRequest",
}

# Readable trigger per call site, keyed "<line>:<action>:<index on that line>". The parser finds the sites;
# this only says, in words, which state and input reach them (read from the same lines).
TRIGGER = {
    "35:GetInitial:0": "open(): every entry, after the access check; through GarageCatalogClient.Fetch",
    "115:SetVehicleCosmeticColor:0": "Paint, colour committed (slider release or swatch), target THRUST_COLOR",
    "116:SetVehicleCosmeticColor:0": "Paint, colour committed, target UNDERGLOW",
    "117:SetCockpitColor:0": "Post-purchase paint (Stage Paint), colour committed, target WholeVehicle",
    "119:SetAllNeonColor:0": "Paint, colour committed, target ALL, channel Neon",
    "120:SetCockpitColor:0": "Paint, colour committed, target ALL, channel other than Neon",
    "121:SetCockpitColor:0": "Paint, colour committed, target Cockpit",
    "122:SetModuleColor:0": "Paint, colour committed, target is a slot id",
    "174:BuyGarageProperty:0": "Garage properties modal (Spaces plus), a property that is not owned is pressed",
    "183:End:0": "Drive pressed with engine, stabilisers and boost fitted (before SpawnVehicle)",
    "185:SpawnVehicle:0": "Drive pressed, after the session End succeeded",
    "194:SelectVehicleInstance:0": "Browser, ShopMode Customisation, primary action on the selected owned vehicle",
    "194:BuyCockpitInstance:1": "Browser, ShopMode Dealership, primary action (BUY) on the selected cockpit",
    "195:End:0": "Browser, Exit pressed",
    "288:EquipModuleInstance:0": "Parts, Owned list, EQUIP on the selected instance (AllowReassign true only after the move confirmation)",
    "358:BuyModuleInstance:0": "Parts, Shop list, BUY on the selected unlocked module",
    "437:UpgradeModule:0": "Upgrades, UPGRADE on the selected upgrade that is not maxed and within budget",
    "558:BuyVehicleCosmetic:0": "Paint, target THRUST_COLOR or UNDERGLOW not yet owned, BUY on the selected cosmetic",
    "604:BuyNeon:0": "Paint, slot target, BUY on the selected Neon Lights card that is not owned",
    "678:EnsureCustomisationAccess:0": "open() with mode Customisation or DriveIn, before anything else",
    "684:End:0": "open(): EnsureCustomisationAccess refused",
    "689:End:0": "open(): GetInitial failed",
    "691:DespawnVehicle:0": "open() with mode DriveIn, after GetInitial",
    "691:SelectVehicleInstance:1": "open() with mode DriveIn, when Profile.CurrentVehicleId was set before the despawn",
}


def read(name):
    path = os.path.join(SOURCES, name)
    with open(path, "rb") as handle:
        raw = handle.read()
    return raw.decode("utf-8"), hashlib.sha256(raw).hexdigest()


def split_top(text):
    """Split a table constructor body on top-level commas."""
    parts, depth, current, quote = [], 0, "", None
    for ch in text:
        if quote:
            current += ch
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
            current += ch
        elif ch in "({[":
            depth += 1
            current += ch
        elif ch in ")}]":
            depth -= 1
            current += ch
        elif ch == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += ch
    if current.strip():
        parts.append(current)
    return parts


def payload(text):
    """'{A=1,B=x}' -> (['A','B'], {'A':'1','B':'x'}). A non-constructor payload is returned as its expression."""
    text = text.strip()
    if not (text.startswith("{") and text.endswith("}")):
        return None, {"<expr>": text}
    keys, values = [], {}
    for part in split_top(text[1:-1]):
        match = re.match(r"\s*([A-Za-z_]\w*)\s*=\s*(.*)$", part, re.S)
        if not match:
            raise SystemExit("positional payload field: " + part)
        keys.append(match.group(1))
        values[match.group(1)] = match.group(2).strip()
    return keys, values


def brace_end(line, start):
    depth = 0
    for index in range(start, len(line)):
        if line[index] == "{":
            depth += 1
        elif line[index] == "}":
            depth -= 1
            if depth == 0:
                return index + 1
    raise SystemExit("unbalanced payload at column %d" % start)


# A function head at column 0 is a function of Client.start (the file does not indent that body).
FUNCTION_HEAD = re.compile(
    r"^(?:local\s+function\s+([\w.]+)|function\s+([\w.:]+)|([\w.]+)\s*=\s*function)\s*\(")
CLOSURE = re.compile(r"(\w+)\s*=\s*function\s*\(")
INDENTED_CLOSURE = re.compile(r"^	+.*?(\w+)\s*=\s*function\s*\([^)]*\)\s*$")


def parse_garage_ui(text):
    lines = text.split("\n")
    actions = []
    enclosing = None
    open_closure = None  # a closure whose head ends an earlier line of the same function
    for number, line in enumerate(lines, start=1):
        head = FUNCTION_HEAD.match(line)
        if head:
            enclosing = head.group(1) or head.group(2) or head.group(3)
            open_closure = None
        tail = INDENTED_CLOSURE.match(line)
        index_on_line = 0
        for match in re.finditer(r"\b(action|self):(Call|Session)\(\"(\w+)\",", line):
            method, action = match.group(2), match.group(3)
            start = match.end()
            while line[start] == " ":
                start += 1
            if line[start] != "{":
                raise SystemExit("line %d: payload is not a table constructor" % number)
            end = brace_end(line, start)
            keys, values = payload(line[start:end])
            closure = open_closure if line.startswith("		") else None
            for found in CLOSURE.finditer(line[:match.start()]):
                closure = found.group(1)
            key = "%d:%s:%d" % (number, action, index_on_line)
            if key not in TRIGGER:
                raise SystemExit("no TRIGGER text for call site " + key)
            actions.append({
                "id": "L%d.%s" % (number, action) if index_on_line == 0 else "L%d.%s.%d" % (number, action, index_on_line),
                "remote": REMOTES[method],
                "kind": "invoke",
                "wrapper": "Adapter:" + method,
                "action": action,
                "payload_keys": keys,
                "payload_values": values,
                "line": number,
                "in_function": enclosing,
                "closure": closure,
                "state": TRIGGER[key],
                "_trigger_key": key,
            })
            index_on_line += 1
        if tail:
            open_closure = tail.group(1)
        # Wrapper call sites that carry no action literal of their own.
        if re.search(r"\baction:Refresh\(\)", line):
            actions.append({"_refresh_site": number, "in_function": enclosing})
    used = {entry["_trigger_key"] for entry in actions if "_trigger_key" in entry}
    stale = sorted(set(TRIGGER) - used)
    if stale:
        raise SystemExit("TRIGGER keys with no call site: " + ", ".join(stale))
    refresh_sites = [entry["_refresh_site"] for entry in actions if "_refresh_site" in entry]
    actions = [entry for entry in actions if "_refresh_site" not in entry]
    for entry in actions:
        del entry["_trigger_key"]
        if entry["action"] == "GetInitial":
            entry["called_from_lines"] = refresh_sites
    return actions


def parse_wrappers(text):
    """The lines where the wrappers touch the remotes, so the reader can see what 'Adapter:Call' sends."""
    wrappers = []
    for number, line in enumerate(text.split("\n"), start=1):
        for match in re.finditer(r"(\w+):InvokeServer\(([^)]*)\)", line):
            wrappers.append({"line": number, "receiver": match.group(1), "arguments": match.group(2)})
        for match in re.finditer(r"CatalogTransport\.Fetch\(([^)]*)\)", line):
            wrappers.append({"line": number, "receiver": "CatalogTransport.Fetch", "arguments": match.group(1)})
    return wrappers


def parse_transport(text):
    sites, added = [], []
    for number, line in enumerate(text.split("\n"), start=1):
        for match in re.finditer(r"request\.(\w+)\s*=\s*([^;]+)", line):
            added.append({"line": number, "key": match.group(1), "value": match.group(2).strip()})
        for match in re.finditer(r"remote:InvokeServer\(\"(\w+)\",\s*(\w+)\)", line):
            sites.append({"line": number, "action": match.group(1), "payload": match.group(2)})
    return {"remote": REMOTES["Call"], "invoke_sites": sites, "request_fields": added,
            "note": "GetInitial is sent by this shared module (reused unchanged). The second site is its one "
                    "read-only recovery request; no other action is ever sent twice."}


def build():
    ui_text, ui_hash = read(GARAGE_UI)
    client_text, client_hash = read(CATALOG_CLIENT)
    actions = parse_garage_ui(ui_text)
    document = {
        "generated_by": "scripts/ui_restyle/phase2/families/garage/gen_actions.py",
        "sources": {GARAGE_UI: ui_hash, CATALOG_CLIENT: client_hash},
        "count": len(actions),
        "actions": actions,
        "wrappers": parse_wrappers(ui_text),
        "transport": parse_transport(client_text),
    }
    return document


def lua_string(value):
    return json.dumps(value)


def lua_block(document):
    rows = [BEGIN, "local EXPECTED_ACTIONS = {"]
    for entry in document["actions"]:
        keys = ", ".join(lua_string(key) for key in (entry["payload_keys"] or []))
        rows.append("\t{ Id = %s, Remote = %s, Action = %s, Keys = { %s }, Line = %d }," % (
            lua_string(entry["id"]), lua_string(entry["remote"]), lua_string(entry["action"]), keys, entry["line"]))
    rows.append("}")
    rows.append(END)
    return "\n".join(rows)


def splice(path, block):
    with open(path, "r", encoding="utf-8", newline="") as handle:
        text = handle.read()
    start = text.find(BEGIN)
    finish = text.find(END)
    if start < 0 or finish < 0:
        raise SystemExit("markers not found in " + path)
    return text, text[:start] + block + text[finish + len(END):]


MODEL_CALL = re.compile(
    r"call\(\"(GarageInvoke|GarageSessionRequest)\",\s*\"(\w+)\",\s*(\{.*?\})\)\s*--\s*GarageUI L(\d+)")
SHORT_REMOTE = {"GarageInvoke": REMOTES["Call"], "GarageSessionRequest": REMOTES["Session"]}


def check_model(document):
    """Every call site in the Pulse model cites a Classic line; remote, action and payload keys must match it,
    and every Classic call site must be cited at least once. Returns a list of problems."""
    if not os.path.exists(MODEL):
        return ["model source not found: " + MODEL]
    with open(MODEL, "r", encoding="utf-8") as handle:
        text = handle.read()
    by_site = {}
    for entry in document["actions"]:
        by_site.setdefault((entry["line"], entry["action"]), entry)
    problems, cited = [], set()
    total = len(re.findall(r"\bcall\(\"", text))
    found = 0
    for line in text.split("\n"):
        for match in MODEL_CALL.finditer(line):
            found += 1
            remote, action, body, cited_line = match.group(1), match.group(2), match.group(3), int(match.group(4))
            keys, _ = payload(body)
            classic = by_site.get((cited_line, action))
            if not classic:
                problems.append("model cites L%d %s, which is not a Classic call site" % (cited_line, action))
                continue
            cited.add((cited_line, action))
            if SHORT_REMOTE[remote] != classic["remote"]:
                problems.append("L%d %s: remote differs" % (cited_line, action))
            if keys != classic["payload_keys"]:
                problems.append("L%d %s: keys %s, Classic %s" % (cited_line, action, keys, classic["payload_keys"]))
    if found != total:
        problems.append("%d of %d call(\"...\") sites in the model are not in the checked one-line form" % (total - found, total))
    for site in sorted(set(by_site) - cited):
        problems.append("Classic call site L%d %s is not issued by the model" % site)
    return problems


def main():
    check = "--check" in sys.argv[1:]
    document = build()
    text = json.dumps(document, indent=1, sort_keys=False) + "\n"
    block = lua_block(document)
    failures = []
    if check:
        if not os.path.exists(OUT) or open(OUT, "r", encoding="utf-8", newline="").read() != text:
            failures.append("actions.json is stale")
        if os.path.exists(MODEL_TEST):
            before, after = splice(MODEL_TEST, block)
            if before != after:
                failures.append("generated block in the model test is stale")
        else:
            failures.append("model test not found")
        failures.extend(check_model(document))
        if failures:
            print("FAIL")
            for failure in failures:
                print("  " + failure)
            sys.exit(1)
        print("ok: %d actions; model call sites equal the Classic call sites" % document["count"])
        return
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    if os.path.exists(MODEL_TEST):
        before, after = splice(MODEL_TEST, block)
        if before != after:
            with open(MODEL_TEST, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(after)
    print("wrote actions.json: %d actions" % document["count"])


if __name__ == "__main__":
    main()
