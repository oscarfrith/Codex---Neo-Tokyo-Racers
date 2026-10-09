"""Builds the review copy of the touch-controls fork and checks it. Not the integrator's fork tool.

py -3 forks/assemble_touch_fork.py          writes after/<module>.lua
py -3 forks/assemble_touch_fork.py --check  fails if the review copy differs, a kept line changed, or the
                                            input-state / attribute lines of Classic and the fork differ
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
FAMILY = os.path.dirname(HERE)
RESTYLE = os.path.normpath(os.path.join(FAMILY, "..", "..", ".."))

def read(path):
    with open(path, "rb") as handle:
        return handle.read().decode("utf-8")

def main():
    spec = json.loads(read(os.path.join(HERE, "FreeRoam.TouchControlsClient.json")))
    classic = read(os.path.join(RESTYLE, "classic", "sources", spec["source"] + ".lua"))
    assert "\r" not in classic
    lines = classic.split("\n")
    out, kept, cursor = [], [], 1
    for item in spec["replace"]:
        first, last = item["lines"]
        assert cursor <= first <= last <= len(lines)
        out += lines[cursor - 1:first - 1]
        kept += lines[cursor - 1:first - 1]
        span = read(os.path.join(HERE, item["with"]))
        assert "\r" not in span
        out += span.rstrip("\n").split("\n")
        cursor = last + 1
    out += lines[cursor - 1:]
    kept += lines[cursor - 1:]
    text = "\n".join(out)
    target = os.path.join(FAMILY, "after", spec["module"] + ".lua")

    # Every kept line appears in the fork, in order.
    position = 0
    for line in kept:
        position = out.index(line, position) + 1

    # Lines that write the input state, or touch an attribute, a bindable or a remote.
    pattern = re.compile(r"M\.State|M\.Analog|M\.SetSteering|M\.Refresh|M\.Throttle|M\.Steer|M\.Drift|M\.Boost"
                         r"|SetAttribute|GetAttribute|:Fire\(|:Invoke\(|InvokeServer|FireServer")
    def hits(source_lines):
        return [line for line in source_lines if pattern.search(line)]
    replaced = set()
    for item in spec["replace"]:
        replaced.update(range(item["lines"][0], item["lines"][1] + 1))
    classic_kept_hits = hits([line for number, line in enumerate(lines, 1) if number not in replaced])
    assert hits(kept) == classic_kept_hits
    fork_new_hits = [line for line in hits(out) if line not in classic_kept_hits]

    if "--check" in sys.argv:
        assert read(target) == text, "review copy differs from the assembled fork"
        print("ok: kept lines", len(kept), "fork lines", len(out))
    else:
        with open(target, "wb") as handle:
            handle.write(text.encode("utf-8"))
        print("wrote", target)
    print("new attribute / state lines in the replaced spans:")
    for line in fork_new_hits:
        print("  ", line.strip()[:200])
    dropped = [line for number, line in enumerate(lines, 1) if number in replaced and pattern.search(line)]
    print("Classic lines of that kind inside the replaced spans:", len(dropped))
    for line in dropped:
        print("  ", line.strip()[:160])

main()
