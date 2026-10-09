"""Turns the token dump of the Edit harness into integrator/tokens_flat.json (the input of assemble.py kit).

    py -3 tokens_from_dump.py <harness result .json>

The harness (tools/run_tests_phase2.lua) returns {"tokens": {name: {"Type": "number" | "string" | "boolean" |
"Color3", "Value": ...}}} from Tokens.Flatten(Tokens.Defaults) of the kit v2 source; a Color3 value is {r, g, b}
in 0..255, as in Phase 1. The output uses the engine's typed form (Color3 components 0..1), the same format as
phase1/tokens_flat.json. PerfDebug is carried over from Phase 1 (it is an attribute, not a token).
"""
import os

import common
from common import ToolError


def convert(tokens):
    out, problems = {}, []
    for name in sorted(tokens):
        item = tokens[name]
        kind, value = (item.get("Type"), item.get("Value")) if isinstance(item, dict) else (None, None)
        if kind == "Color3" and isinstance(value, list) and len(value) == 3:
            out[name] = {"Type": "Color3", "R": value[0] / 255, "G": value[1] / 255, "B": value[2] / 255}
        elif kind in ("number", "string", "boolean") and isinstance(value, (int, float, str, bool)):
            out[name] = value
        else:
            problems.append("%s: unsupported token value %r" % (name, item))
    return out, problems


def main(argv):
    layout, positional, _ = common.parse_args(argv)
    if len(positional) != 1:
        print(__doc__)
        return 2
    data = common.read_json(positional[0])
    if isinstance(data, str):                      # the harness result saved as a JSON string
        import json
        data = json.loads(data)
    if not isinstance(data.get("tokens"), dict) or not data["tokens"]:
        raise ToolError("no token dump in %s" % positional[0],
                        ["the harness writes \"tokens\" only when Kit.Tokens loads; read its results for Kit.Tokens"])
    tokens, problems = convert(data["tokens"])
    if problems:
        raise ToolError("the token dump cannot be converted", problems)
    old = common.read_json(os.path.join(common.PHASE1, "tokens_flat.json"))["tokens"]
    if "PerfDebug" in old:
        tokens.setdefault("PerfDebug", old["PerfDebug"])
    out = os.path.join(layout.integrator, "tokens_flat.json")
    common.write_json(out, {
        "_format": "name -> boolean | number | string | {Type: Color3, R, G, B} with components 0..1",
        "_source": "Tokens.Flatten(Tokens.Defaults) from the Edit harness result %s" % os.path.basename(positional[0]),
        "provisional": False,
        "tokens": tokens})
    print("%s: %d tokens (%d new since Phase 1, %d no longer flattened)" % (
        out, len(tokens), len(set(tokens) - set(old)), len(set(old) - set(tokens))))
    return 0


if __name__ == "__main__":
    common.run_main(main)
