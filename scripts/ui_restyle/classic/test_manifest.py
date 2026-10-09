"""Self-test for the Classic baseline record. Run: py -3 test_manifest.py   (after build_manifest.py and build_verify.py)

Checks the Python hashes against a line-by-line port of the Luau arithmetic in build_verify.LUA_HASH, carried out in
IEEE doubles exactly as Luau does, on every captured source (including the non-ASCII and CRLF ones).
"""
import io
import json
import math
import os
import re

import build_manifest
import build_verify
from build_manifest import HERE, djb2, fnv1a32

TWO53 = 9007199254740992.0


def bit32_bxor(a, b):
    assert a == math.floor(a) and 0 <= a < 4294967296.0
    return float((int(a) ^ int(b)) & 0xFFFFFFFF)


def bit32_lshift(a, n):
    assert a == math.floor(a) and 0 <= a < 4294967296.0
    return float((int(a) << n) & 0xFFFFFFFF)


def luau_mod(a, b):
    return a - math.floor(a / b) * b  # Luau: a % b == a - floor(a / b) * b


def luau_hashes(s):
    """Port of LUA_HASH. Each line below is the Luau line in the comment, in doubles."""
    peak = 0.0
    d = 5381.0                                                   # local d = 5381
    f = 2166136261.0                                             # local f = 2166136261
    for b in s:                                                  # for i = 1, #s do  local b = string.byte(s, i)
        t = d * 33.0 + b
        d = luau_mod(t, 4294967296.0)                            # d = (d * 33 + b) % 4294967296
        f = bit32_bxor(f, b)                                     # f = bit32.bxor(f, b)
        u = bit32_lshift(f, 24) + f * 403.0
        f = luau_mod(u, 4294967296.0)                            # f = (bit32.lshift(f, 24) + f * 403) % 4294967296
        if t > peak:
            peak = t
        if u > peak:
            peak = u
    return int(d), int(f), peak                                  # return d, f


PORTED_LINES = [
    "local d = 5381",
    "local f = 2166136261",
    "local b = string.byte(s, i)",
    "d = (d * 33 + b) % 4294967296",
    "f = bit32.bxor(f, b)",
    "f = (bit32.lshift(f, 24) + f * 403) % 4294967296",
    "return d, f",
]


def strip_lua(text):
    # One left-to-right pass so a quote inside the other kind of string, or inside a comment, cannot mispair.
    pattern = r'''"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|--[^\n]*'''
    return re.sub(pattern, lambda m: "" if m.group(0).startswith("--") else '""', text)


def main():
    # Known vectors.
    assert fnv1a32(b"") == 0x811C9DC5 and fnv1a32(b"a") == 0xE40C292C and fnv1a32(b"foobar") == 0xBF9CF968
    assert djb2(b"") == 5381 and djb2(b"a") == 177670
    synthetic = [b"", b"a", b"foobar", bytes(range(256)) * 9, b"\xff" * 70000, b"\r\n\r\n", "café — \U0001f3ce".encode("utf-8")]
    for data in synthetic:
        d, f, peak = luau_hashes(data)
        assert (d, f) == (djb2(data), fnv1a32(data)), data[:16]
        assert peak < TWO53

    # The generated script carries exactly the arithmetic ported above.
    with io.open(os.path.join(HERE, "out_verify_classic.lua"), encoding="ascii") as handle:
        lua = handle.read()
    assert build_verify.LUA_HASH in lua
    body = [line.strip() for line in build_verify.LUA_HASH.splitlines()]
    for line in PORTED_LINES:
        assert line in body, line
    assert len(lua) < build_verify.SIZE_LIMIT, len(lua)
    assert lua == build_verify.build(None), "out_verify_classic.lua is stale or was built with --declared"

    # manifest.json against the raw record and the sources, through both implementations.
    with io.open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as handle:
        manifest = json.load(handle)
    raw = build_manifest.load_json("manifest_raw.json")
    rows = manifest["scripts"]
    assert len(rows) == len(raw) == manifest["record"]["count"] == 221
    assert [r["path"] for r in rows] == sorted(e["path"] for e in raw)
    raw_by_path = {e["path"]: e for e in raw}
    non_ascii = crlf = 0
    peak = 0.0
    pairs = set()
    for row in rows:
        data = build_manifest.read_bytes(os.path.join("sources", row["file"]))
        entry = raw_by_path[row["path"]]
        assert len(data) == row["length"] == entry["length"], row["path"]
        assert row["class"] == entry["class"] and row["file"] == entry["file"]
        d, f, top = luau_hashes(data)
        assert d == row["djb2"] == djb2(data), row["path"]
        assert f == row["fnv1a32"] == fnv1a32(data), row["path"]
        peak = max(peak, top)
        non_ascii += any(b > 127 for b in data)
        crlf += b"\r\n" in data
        pairs.add((row["length"], d, f))
        assert ("%d,%d,%d," % (row["length"], d, f)) in lua, row["path"]
        assert build_verify.lua_string(row["path"]) in lua, row["path"]
    assert peak < TWO53
    assert non_ascii > 0 and crlf > 0, "expected sources with non-ASCII bytes and CRLF"

    # config.json: stable, complete, and every value is in the generated script.
    with io.open(os.path.join(HERE, "config.json"), encoding="utf-8") as handle:
        config = json.load(handle)
    assert config == json.loads(json.dumps(build_manifest.build_config()))
    assert sorted(config["roots"]) == ["Development", "Player", "UI"]
    for name, root in config["roots"].items():
        blob = build_manifest.canonical_bytes(root["nodes"])
        assert root["hash"] == {"djb2": djb2(blob), "fnv1a32": fnv1a32(blob)}
        assert root["nodeCount"] == len(root["nodes"])
        for path, node in root["nodes"].items():
            assert path == name or path.startswith(name + ".")
            assert build_verify.lua_string(path) in lua
            for typed in list(node["attributes"].values()) + ([node["value"]] if "value" in node else []):
                if typed["t"] in ("Color3", "Vector3"):
                    assert len(typed["v"]) == 3
                assert build_verify.lua_typed(typed) in lua

    # The generated script is read-only and structurally balanced.
    logic = strip_lua(build_verify.TEMPLATE)
    for banned in ("Instance.new", "SetAttribute", ".Source =", ".Value =", ".Parent =", ":Destroy", ":Clone", ":Remove",
                   "ClearAllChildren", "loadstring", "require(", "HttpService", ":Fire", ":Invoke", "ChangeHistory",
                   ".Name =", ".Disabled =", ".Enabled ="):
        assert banned not in logic, banned
    assert "task.wait()" in logic and "YIELD_EVERY" in logic
    full = strip_lua(lua)
    openers = len(re.findall(r"\b(?:function|if|do|repeat)\b", full))
    closers = len(re.findall(r"\b(?:end|until)\b", full))
    assert openers == closers, (openers, closers)
    for a, b in ("()", "{}", "[]"):
        assert full.count(a) == full.count(b), (a, full.count(a), full.count(b))

    print("OK  %d scripts, %d with non-ASCII bytes, %d with CRLF, peak intermediate 2^%.1f, verify script %d characters" % (
        len(rows), non_ascii, crlf, math.log2(peak), len(lua)))


if __name__ == "__main__":
    main()
