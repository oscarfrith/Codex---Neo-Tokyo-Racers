"""Driving tune delivery: composes the parts into after-sources and the guarded installer (contract: CONTRACT.md).

    py -3 scripts/driving_tune/serve.py              (leave running; the installer reads sources from it)
    py -3 scripts/driving_tune/build.py              (all parts: writes after/*.lua and out_audit/apply/rollback.lua)
    py -3 scripts/driving_tune/build.py --part pose  (one part alone, into <part>/after/, no installer: anchor check)

Each part is scripts/driving_tune/<part>/edits.py with EDITS, INSTANCES and ATTRIBUTES (format in CONTRACT.md).
before/ holds the exact live sources and config captured from Space Racers v3 on 2026-10-06.
Each full build appends the after-hashes to applied_hashes.json so a later build can be applied over an earlier one.
"""
import importlib.util
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "scripts/driving_tune/"
PLACE_ID = 93959280828322
VEHICLES = ["ReplicatedStorage", "Modules", "Game", "Vehicles"]
PARTS = ["balance", "pose", "integrator"]
UI = ["ReplicatedStorage", "Modules", "Game", "UI"]
SCRIPTS = {"DrivingClient": VEHICLES, "VehicleDynamics": VEHICLES, "FreeRoamParkedHoverClient": VEHICLES,
           "DesktopFreeRoamHudUI": UI}


def djb2(text):
    x = 5381
    for b in text.encode("utf-8"):
        x = (x * 33 + b) % 4294967296
    return x


def read(relative):
    return io.open(os.path.join(HERE, relative), encoding="utf-8", newline="").read()


def write(relative, text):
    path = os.path.join(HERE, relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    io.open(path, "w", encoding="utf-8", newline="").write(text)


def load(part):
    path = os.path.join(HERE, part, "edits.py")
    if not os.path.exists(path):
        return None
    spec = importlib.util.spec_from_file_location("driving_tune_" + part, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def compose(parts):
    sources = {name: read("before/%s.lua" % name) for name in SCRIPTS}
    instances, attributes = [], []
    for part in parts:
        module = load(part)
        if module is None:
            print("part %s: no edits.py yet" % part)
            continue
        for name, edits in getattr(module, "EDITS", {}).items():
            if name not in sources:
                raise SystemExit("%s: unknown script %s" % (part, name))
            for old, new, count in edits:
                found = sources[name].count(old)
                if found != count:
                    raise SystemExit("%s: %s anchor found %d times, expected %d: %r" % (part, name, found, count, old[:90]))
                sources[name] = sources[name].replace(old, new)
        instances += list(getattr(module, "INSTANCES", []))
        attributes += [tuple(row) for row in getattr(module, "ATTRIBUTES", [])]
    return sources, instances, attributes


def captured_attributes():
    found = {}
    for record in json.load(io.open(os.path.join(HERE, "before", "config.json"), encoding="utf-8")):
        path = "ReplicatedStorage/Config/" + record["path"]
        for key, value in (record["attrs"] or {}).items():
            found[(path, key)] = value
    return found


def main():
    if "--part" in sys.argv:
        part = sys.argv[sys.argv.index("--part") + 1]
        sources, instances, attributes = compose([part])
        for name, text in sources.items():
            if text != read("before/%s.lua" % name):
                write("%s/after/%s.lua" % (part, name), text)
                print("%s: %s changed, %d lines" % (part, name, text.count("\n") + 1))
        print("instances", len(instances), "attributes", len(attributes))
        return

    sources, instances, attributes = compose(PARTS)
    history_path = os.path.join(HERE, "applied_hashes.json")
    history = json.load(open(history_path)) if os.path.exists(history_path) else {}
    scripts = {}
    for name in SCRIPTS:
        before = read("before/%s.lua" % name)
        if sources[name] == before:
            continue
        write("after/%s.lua" % name, sources[name])
        b, a = djb2(before), djb2(sources[name])
        prior = [h for h in history.get(name, []) if h not in (a, b)]
        scripts[name] = {"path": SCRIPTS[name] + [name], "before": b, "after": a, "prior": prior,
                         "file": {"before": "before/%s.lua" % name, "after": "after/%s.lua" % name}}
        history[name] = prior + [a]
    json.dump(history, open(history_path, "w"), indent=1, sort_keys=True)

    captured = captured_attributes()
    rows = []
    for path, key, value in attributes:
        row = {"path": path, "key": key, "value": value}
        old = captured.get(("/".join(path), key))
        if old is not None:
            row["before"] = old
        rows.append(row)

    data = json.dumps({"placeId": PLACE_ID, "base": BASE, "scripts": scripts, "attributes": rows,
                       "instances": instances}, sort_keys=True)
    if "]==]" in data:
        raise SystemExit("config text contains the long-string terminator")
    engine = read("installer_engine.lua")
    for mode in ("AUDIT", "APPLY", "ROLLBACK"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])\n%s' % (mode, data, engine)
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print(json.dumps({name: {"before": "%08x" % s["before"], "after": "%08x" % s["after"], "prior": len(s["prior"])}
                      for name, s in scripts.items()}, sort_keys=True))
    print("attributes", len(rows), "instances", len(instances))


if __name__ == "__main__":
    main()
