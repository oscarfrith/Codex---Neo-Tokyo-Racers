"""Classic baseline record for the Pulse UI restyle (plan section 1.8).

Reads   manifest_raw.json, config_raw.json, sources/*.lua   (integrator's read-only dump; never modified here)
Writes  manifest.json   path, class, file, length and two hashes for every script
        config.json     canonical typed record of Config.UI / Config.Development / Config.Player + service settings

Hashes (both over the raw source BYTES, both exact in Luau doubles):
  djb2     x = (x * 33 + byte) % 2^32, seed 5381. The project convention (scripts/hover_feel/build.py and
           installer_engine.lua use exactly this).
  fnv1a32  FNV-1a 32-bit, seed 2166136261, prime 16777619. Independent of djb2 (xor then multiply).
           In Luau the multiply is split so no product passes 2^53: see LUA_HASH in build_verify.py.

Run: py -3 build_manifest.py
"""
import io
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PLACE_ID = 93959280828322
PLACE_NAME = "Space Racers v3"
TAKEN = "2026-10-09"
CONFIG_ROOTS = (("configUI", "UI"), ("clientTools", "Development"), ("onboarding", "Player"))
SIMPLE_TYPES = ("number", "boolean", "string")
VECTOR_TYPES = ("Color3", "Vector3")


def djb2(data):
    x = 5381
    for b in data:
        x = (x * 33 + b) % 4294967296
    return x


def fnv1a32(data):
    x = 2166136261
    for b in data:
        x = ((x ^ b) * 16777619) & 0xFFFFFFFF
    return x


def read_bytes(relative):
    with open(os.path.join(HERE, relative), "rb") as handle:
        return handle.read()


def load_json(relative):
    return json.loads(read_bytes(relative).decode("utf-8"))


def write_json(relative, value):
    text = json.dumps(value, indent=1, sort_keys=True, ensure_ascii=True) + "\n"
    with io.open(os.path.join(HERE, relative), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def build_scripts():
    raw = load_json("manifest_raw.json")
    rows, problems, seen = [], [], set()
    for entry in raw:
        path = entry["path"]
        if path in seen:
            problems.append("duplicate path: " + path)
        seen.add(path)
        data = read_bytes(os.path.join("sources", entry["file"]))
        if len(data) != entry["length"]:
            problems.append("%s: file is %d bytes, manifest_raw says %d" % (path, len(data), entry["length"]))
        row = {
            "path": path,
            "class": entry["class"],
            "file": entry["file"],
            "length": len(data),
            "djb2": djb2(data),
            "fnv1a32": fnv1a32(data),
        }
        if entry.get("disabled"):
            row["disabled"] = True
        rows.append(row)
    on_disk = set(os.listdir(os.path.join(HERE, "sources")))
    listed = set(entry["file"] for entry in raw)
    for name in sorted(on_disk - listed):
        problems.append("sources/%s is not in manifest_raw.json" % name)
    if problems:
        raise SystemExit("manifest_raw.json does not match sources/:\n  " + "\n  ".join(problems))
    rows.sort(key=lambda row: row["path"])
    return rows


def canon_value(typed, where):
    """{t, v} from the raw dump -> canonical {t, v}. Vectors become lists of numbers."""
    kind, value = typed["t"], typed["v"]
    if kind == "number":
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise SystemExit("%s: number is not finite: %r" % (where, value))
    elif kind == "boolean":
        assert isinstance(value, bool), where
    elif kind == "string":
        assert isinstance(value, str), where
    elif kind in VECTOR_TYPES:
        if isinstance(value, str):
            value = [float(part) for part in value.split(",")]
        value = [float(part) for part in value]
        if len(value) != 3 or not all(math.isfinite(part) for part in value):
            raise SystemExit("%s: bad %s %r" % (where, kind, typed["v"]))
    else:
        # Unknown to this record: kept as the dump's text and compared against tostring() in Studio.
        print("WARNING %s: type %s is compared as text" % (where, kind), file=sys.stderr)
        value = value if isinstance(value, str) else json.dumps(value, sort_keys=True)
    return {"t": kind, "v": value}


def flatten(node, path, out):
    if path in out:
        raise SystemExit("config_raw.json: two nodes share the path " + path)
    record = {"class": node["class"], "attributes": {}}
    attributes = node.get("attributes") or {}  # an empty Luau table arrives as []
    for name in sorted(attributes):
        record["attributes"][name] = canon_value(attributes[name], path + "@" + name)
    if node.get("value") is not None:
        record["value"] = canon_value(node["value"], path + "@Value")
    out[path] = record
    for child in node.get("children") or []:
        flatten(child, path + "." + child["name"], out)


def canonical_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def build_config():
    raw = load_json("config_raw.json")
    roots = {}
    for key, name in CONFIG_ROOTS:
        node = raw[key]
        if node["name"] != name:
            raise SystemExit("config_raw.json: %s is named %s, expected %s" % (key, node["name"], name))
        nodes = {}
        flatten(node, name, nodes)
        blob = canonical_bytes(nodes)
        roots[name] = {
            "rawKey": key,
            "nodeCount": len(nodes),
            "attributeCount": sum(len(n["attributes"]) for n in nodes.values()),
            "valueCount": sum(1 for n in nodes.values() if "value" in n),
            "hash": {"djb2": djb2(blob), "fnv1a32": fnv1a32(blob)},
            "nodes": nodes,
        }
    services = dict(raw.get("services") or {})
    blob = canonical_bytes(services)
    return {
        "record": {
            "place": PLACE_NAME, "placeId": PLACE_ID, "taken": TAKEN, "mode": "Edit",
            "parent": "ReplicatedStorage.Config",
            "hashOf": "canonical JSON of nodes (sorted keys, no spaces, ASCII); Python-side record only",
        },
        "roots": roots,
        "services": {"hash": {"djb2": djb2(blob), "fnv1a32": fnv1a32(blob)}, "values": services},
    }


def main():
    rows = build_scripts()
    manifest = {
        "record": {
            "place": PLACE_NAME, "placeId": PLACE_ID, "taken": TAKEN, "mode": "Edit",
            "count": len(rows), "totalBytes": sum(row["length"] for row in rows),
            "hashes": {
                "djb2": "x=(x*33+byte)%2^32, seed 5381, over source bytes",
                "fnv1a32": "FNV-1a 32, seed 2166136261, prime 16777619, over source bytes",
            },
        },
        "scripts": rows,
    }
    write_json("manifest.json", manifest)
    config = build_config()
    write_json("config.json", config)
    print("manifest.json: %d scripts, %d bytes" % (len(rows), manifest["record"]["totalBytes"]))
    for name, root in config["roots"].items():
        print("config.json: %-12s %3d nodes %3d attributes %3d values  djb2=%d fnv1a32=%d" % (
            name, root["nodeCount"], root["attributeCount"], root["valueCount"],
            root["hash"]["djb2"], root["hash"]["fnv1a32"]))
    print("config.json: services %s" % json.dumps(config["services"]["values"], sort_keys=True))


if __name__ == "__main__":
    main()
