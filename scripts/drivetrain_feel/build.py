"""drivetrain_feel delivery: composes the parts into after-sources and the guarded installer (contract: CONTRACT.md).

    py -3 scripts/drivetrain_feel/serve.py        (leave running; the installer reads sources from it)
    py -3 scripts/drivetrain_feel/build.py        (writes after/*.lua, out_audit/apply_config/apply/rollback.lua)
    py -3 scripts/drivetrain_feel/build.py --diff (also prints a diff stat per script)

Each part owns whole scripts: <part>/after/<file> replaces before/<file>. Config comes from <part>/config.py
(INSTANCES and ATTRIBUTES, format in CONTRACT.md section 2). before/ holds the exact live sources and config captured
from PR98 on 2026-10-20. Each full build appends the after-hashes to applied_hashes.json so a later build can be applied
over an earlier one.
"""
import difflib
import importlib.util
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "scripts/drivetrain_feel/"
PLACE_ID = 103397770260610
VEHICLES = ["ReplicatedStorage", "Modules", "Game", "Vehicles"]
AUDIO = ["ReplicatedStorage", "Modules", "Game", "Audio"]
PULSE = ["ReplicatedStorage", "Modules", "Game", "UIPulse"]
# name: (instance path, before/after file, owning part)
SCRIPTS = {
    "DrivingClient": (VEHICLES + ["DrivingClient"], "DrivingClient.lua", "physics"),
    "VehicleDynamics": (VEHICLES + ["VehicleDynamics"], "VehicleDynamics.lua", "physics"),
    "VehicleAudioClient": (AUDIO + ["VehicleAudioClient"], "VehicleAudioClient.lua", "audio"),
    "VehicleAudioCatalog": (AUDIO + ["VehicleAudioCatalog"], "VehicleAudioCatalog.lua", "audio"),
    "DriveSessionClient": (VEHICLES + ["DriveSessionClient"], "DriveSessionClient.lua", "hud"),
    "HudView": (PULSE + ["FreeRoam", "HudView"], "HudView.lua", "hud"),
    "Kit.Gauge": (PULSE + ["Kit", "Gauge"], "Gauge.lua", "hud"),
    "Fixtures.Gauge": (PULSE + ["Dev", "Fixtures", "Gauge"], "Fixtures.Gauge.lua", "hud"),
    "DrivingCameraClient": (VEHICLES + ["DrivingCameraClient"], "DrivingCameraClient.lua", "camerafx"),
    "VehicleVFXClient": (VEHICLES + ["VehicleVFXClient"], "VehicleVFXClient.lua", "camerafx"),
}
CONFIG_PARTS = ["physics", "audio", "camerafx"]
MAX_SOURCE = 199999


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
    path = os.path.join(HERE, part, "config.py")
    if not os.path.exists(path):
        return None
    spec = importlib.util.spec_from_file_location("drivetrain_feel_" + part, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def captured_attributes():
    found = {}
    for record in json.load(io.open(os.path.join(HERE, "before", "config.json"), encoding="utf-8")):
        path = "ReplicatedStorage/Config/" + record["path"]
        for key, value in (record.get("attrs") or {}).items():
            found[(path, key)] = value
    return found


def main():
    sources = {}
    for name, (path, file, part) in SCRIPTS.items():
        after = os.path.join(HERE, part, "after", file)
        sources[name] = io.open(after, encoding="utf-8", newline="").read() if os.path.exists(after) else read("before/" + file)
        if len(sources[name]) > MAX_SOURCE:
            raise SystemExit("%s is %d characters, over the Roblox source limit" % (name, len(sources[name])))

    instances, attributes = [], []
    for part in CONFIG_PARTS:
        module = load(part)
        if module is None:
            print("part %s: no config.py" % part)
            continue
        instances += list(getattr(module, "INSTANCES", []))
        attributes += [tuple(row) for row in getattr(module, "ATTRIBUTES", [])]

    seen = set()
    for path, key, _ in attributes:
        k = ("/".join(path), key)
        if k in seen:
            raise SystemExit("attribute %s @%s set by more than one row" % k)
        seen.add(k)

    history_path = os.path.join(HERE, "applied_hashes.json")
    history = json.load(open(history_path)) if os.path.exists(history_path) else {}
    scripts = {}
    for name, (path, file, part) in SCRIPTS.items():
        before = read("before/" + file)
        if sources[name] == before:
            continue
        write("after/" + file, sources[name])
        b, a = djb2(before), djb2(sources[name])
        prior = [h for h in history.get(name, []) if h not in (a, b)]
        scripts[name] = {"path": path, "before": b, "after": a, "prior": prior,
                         "file": {"before": "before/" + file, "after": "after/" + file}}
        history[name] = prior + [a]
        if "--diff" in sys.argv:
            lines = list(difflib.unified_diff(before.splitlines(), sources[name].splitlines(), lineterm="", n=0))
            added = sum(1 for l in lines if l.startswith("+") and not l.startswith("+++"))
            removed = sum(1 for l in lines if l.startswith("-") and not l.startswith("---"))
            print("%-20s +%d -%d lines (%d -> %d chars)" % (name, added, removed, len(before), len(sources[name])))
    json.dump(history, open(history_path, "w"), indent=1, sort_keys=True)

    captured = captured_attributes()
    rows = []
    for path, key, value in attributes:
        row = {"path": list(path), "key": key, "value": value}
        old = captured.get(("/".join(path), key))
        if old is not None:
            if isinstance(old, dict):
                raise SystemExit("%s @%s is a %s attribute; this delivery only writes primitives" % ("/".join(path), key, old.get("__type")))
            row["before"] = old
        rows.append(row)

    data = json.dumps({"placeId": PLACE_ID, "base": BASE, "scripts": scripts, "attributes": rows,
                       "instances": instances}, sort_keys=True)
    if "]==]" in data:
        raise SystemExit("config text contains the long-string terminator")
    engine = read("installer_engine.lua")
    for mode in ("AUDIT", "APPLY_CONFIG", "APPLY", "ROLLBACK"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])\n%s' % (mode, data, engine)
        if len(out) > MAX_SOURCE:
            raise SystemExit("out_%s.lua is %d characters, over the limit" % (mode.lower(), len(out)))
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print(json.dumps({name: {"before": "%08x" % s["before"], "after": "%08x" % s["after"], "prior": len(s["prior"])}
                      for name, s in scripts.items()}, sort_keys=True))
    print("attributes", len(rows), "(existing:", sum(1 for r in rows if "before" in r), ") instances", len(instances))


if __name__ == "__main__":
    main()
