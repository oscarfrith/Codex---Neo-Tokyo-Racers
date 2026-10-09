"""Builds the after-file of every fork of one family (API2 6.1) and compares it with the agent's hand-assembled copy.

    py -3 build_forks.py <family> [--quiet]

Fork format, families/<family>/forks/<Pulse module name>.json:
    {"source": "<classic instance path>",
     "replace": [{"lines": [from, to], "with": "<file in forks/>"}],
     "path": "<full Pulse instance path>"}            optional; see "target" below

- lines are 1-based, inclusive, in the numbering of classic/sources/<source>.lua. [n, n-1] inserts before line n.
  "with": null deletes the lines. Spans must be in order and must not overlap.
- The Classic source is checked against classic/manifest.json (length, djb2, fnv1a32) before anything is built.
- target: "path" (also read: "target", "module", "_target") when given; a file name that is already a full
  instance path; else the one op in spec_ops*.json whose path ends with the file name; else the one
  after/*.<name>.lua file.
- Output (never inside families/): integrator/forks_out/<family>/after/<path>.lua and forks.json, which records,
  per fork, the after-file line ranges that are NEW code. lint_phase2.py and parity_check.py read it: lines outside
  those ranges are kept Classic text (API2 6.6 rule 4).
- A hand-assembled families/<family>/after/<path>.lua is compared byte for byte; the built file is the one installed.
- "watch" lists every removed Classic line and every new line that mentions a guarded word (MobileDriveInputState
  writes, remote calls, bindable fires, attribute writes), so CONTRACT step 5 can be read off the report.

Exit code 1 when a fork cannot be built or a hand-assembled file differs. Nothing here talks to Studio.
"""
import os
import re

import common
from common import ToolError

TARGET_KEYS = ("path", "target", "module", "_target", "_module", "_path")
WATCH = re.compile(r"MobileDriveInputState|FireServer|InvokeServer|:Fire\(|:Invoke\(|SetAttribute|\.Enabled\s*=")


def split_lines(text):
    """-> (lines without terminators, ends_with_newline)."""
    if text == "":
        return [], False
    ends = text.endswith("\n")
    return (text[:-1] if ends else text).split("\n"), ends


def resolve_target(family_dir, name, data, problems):
    for key in TARGET_KEYS:
        if isinstance(data.get(key), str) and data[key].split(".")[0] in common.ROOTS:
            return data[key]
    if name.split(".")[0] in common.ROOTS and "." in name:
        return name
    candidates = set()
    for _, fragment in common.fragments(family_dir, "spec_ops"):
        ops = fragment.get("ops") if isinstance(fragment, dict) else fragment
        for op in ops or []:
            if isinstance(op, dict) and isinstance(op.get("path"), list) and op["path"]:
                dotted = ".".join(str(part) for part in op["path"])
                if dotted.endswith("." + name):
                    candidates.add(dotted)
    if not candidates:
        for path in common.lua_files(os.path.join(family_dir, "after")):
            if path.endswith("." + name):
                candidates.add(path)
    if len(candidates) == 1:
        return candidates.pop()
    problems.append("forks/%s.json: cannot tell which instance path it builds (%s). Add \"path\" to the fork file." % (
        name, "no spec_ops op or after/ file ends in ." + name if not candidates else "candidates: " + ", ".join(sorted(candidates))))
    return None


def build_one(family_dir, name, data, problems):
    """-> record or None."""
    where = "forks/%s.json" % name
    forks_dir = os.path.join(family_dir, "forks")
    source = data.get("source")
    row = common.classic_manifest().get(source) if isinstance(source, str) else None
    if row is None:
        problems.append("%s: source %r is not a script of classic/manifest.json" % (where, source))
        return None
    raw = common.read_bytes(os.path.join(common.CLASSIC, "sources", row["file"]))
    if (len(raw), common.djb2(raw), common.fnv1a32(raw)) != (row["length"], row["djb2"], row["fnv1a32"]):
        problems.append("%s: classic/sources/%s does not match classic/manifest.json (the baseline file was changed)" % (
            where, row["file"]))
        return None
    if b"\r" in raw:
        problems.append("%s: the Classic source has CR line ends; a fork of it cannot be an LF after-file" % where)
        return None
    classic_lines, classic_newline = split_lines(raw.decode("utf-8"))
    path = resolve_target(family_dir, name, data, problems)
    spans = data.get("replace")
    if not isinstance(spans, list) or not spans:
        problems.append("%s: replace must be a non-empty list" % where)
        return None
    out, new_ranges, replaced, watch = [], [], [], []
    cursor, ok = 1, True
    for index, span in enumerate(spans):
        lines = span.get("lines") if isinstance(span, dict) else None
        if isinstance(lines, list) and len(lines) == 1:
            lines = [lines[0], lines[0]]
        if not (isinstance(lines, list) and len(lines) == 2 and all(isinstance(v, int) and not isinstance(v, bool) for v in lines)):
            problems.append("%s: replace[%d].lines must be [from, to]" % (where, index))
            ok = False
            continue
        first, last = lines
        if first < cursor or last < first - 1 or last > len(classic_lines) or first < 1:
            problems.append("%s: replace[%d] lines %d to %d are out of order, overlap the span before, or are outside "
                            "the %d lines of the source" % (where, index, first, last, len(classic_lines)))
            ok = False
            continue
        with_name = span.get("with")
        new_lines = []
        if with_name is not None:
            with_file = os.path.join(forks_dir, *str(with_name).split("/"))
            if ".." in str(with_name).split("/") or not os.path.isfile(with_file):
                problems.append("%s: replace[%d] file forks/%s does not exist" % (where, index, with_name))
                ok = False
                continue
            text_bytes = common.read_bytes(with_file)
            if b"\r" in text_bytes:
                problems.append("%s: forks/%s has CR line ends; save it with LF" % (where, with_name))
                ok = False
                continue
            new_lines, _ = split_lines(text_bytes.decode("utf-8"))
        out.extend(classic_lines[cursor - 1:first - 1])
        start = len(out) + 1
        out.extend(new_lines)
        if new_lines:
            new_ranges.append([start, len(out)])
        replaced.append({"lines": [first, last], "with": with_name, "afterLines": [start, len(out)]})
        for number in range(first, last + 1):
            if WATCH.search(classic_lines[number - 1]):
                watch.append({"side": "removed", "line": number, "text": classic_lines[number - 1].strip()[:160]})
        for offset, line in enumerate(new_lines):
            if WATCH.search(line):
                watch.append({"side": "new", "line": start + offset, "file": with_name, "text": line.strip()[:160]})
        cursor = last + 1
    if not ok or path is None:
        return None
    out.extend(classic_lines[cursor - 1:])
    text = "\n".join(out) + ("\n" if classic_newline or (spans and spans[-1]["lines"][-1] == len(classic_lines)) else "")
    removed = sum(item["lines"][1] - item["lines"][0] + 1 for item in replaced)
    return {"name": name, "path": path, "source": source, "sourceFingerprint": common.fingerprint(raw),
            "sourceLines": len(classic_lines), "replaced": replaced, "newRanges": new_ranges,
            "keptLines": len(classic_lines) - removed, "newLines": sum(b - a + 1 for a, b in new_ranges),
            "afterLines": len(out), "after": common.fingerprint(text.encode("utf-8")), "watch": watch, "_text": text}


def build(layout, family, write=True):
    """-> ([records], [problems]). Writes integrator/forks_out/<family>/ when write is true."""
    if family not in common.FAMILIES:
        raise ToolError("build_forks: %r is not a family" % family, ["families: " + ", ".join(common.FAMILIES)])
    family_dir = layout.family_dir(family)
    forks_dir = os.path.join(family_dir, "forks")
    out_dir = layout.forks_out(family)
    records, problems = [], []
    names = sorted(n[:-5] for n in os.listdir(forks_dir) if n.endswith(".json")) if os.path.isdir(forks_dir) else []
    for name in names:
        try:
            data = common.read_json(os.path.join(forks_dir, name + ".json"))
        except ValueError as error:
            problems.append("forks/%s.json is not valid JSON: %s" % (name, error))
            continue
        if not isinstance(data, dict):
            problems.append("forks/%s.json must be an object" % name)
            continue
        record = build_one(family_dir, name, data, problems)
        if record is None:
            continue
        if any(other["path"] == record["path"] for other in records):
            problems.append("forks/%s.json: %s is built by two fork files" % (name, record["path"]))
            continue
        hand = os.path.join(family_dir, "after", record["path"] + ".lua")
        text = record.pop("_text")
        if os.path.isfile(hand):
            hand_bytes = common.read_bytes(hand)
            if hand_bytes == text.encode("utf-8"):
                record["handAssembled"] = "match"
            else:
                record["handAssembled"] = "differs"
                hand_lines = hand_bytes.decode("utf-8", errors="replace").split("\n")
                built_lines = text.split("\n")
                first = next((i for i in range(min(len(hand_lines), len(built_lines)))
                              if hand_lines[i] != built_lines[i]), min(len(hand_lines), len(built_lines)))
                record["firstDifference"] = {
                    "line": first + 1,
                    "built": built_lines[first][:160] if first < len(built_lines) else "<end of file>",
                    "hand": hand_lines[first][:160] if first < len(hand_lines) else "<end of file>"}
                problems.append("%s: the hand-assembled after/ file differs from the fork build at line %d" % (
                    record["path"], first + 1))
        else:
            record["handAssembled"] = "absent"
        if write:
            common.write_text(os.path.join(out_dir, "after", record["path"] + ".lua"), text)
        records.append(record)
    if write and (records or os.path.isdir(out_dir)):
        keep = {record["path"] + ".lua" for record in records}
        after_dir = os.path.join(out_dir, "after")
        if os.path.isdir(after_dir):
            for name in os.listdir(after_dir):
                if name not in keep:
                    os.remove(os.path.join(after_dir, name))
        common.write_json(os.path.join(out_dir, "forks.json"), {
            "_note": "GENERATED by phase2/tools/build_forks.py. newRanges are after-file lines that are new code; "
                     "every other line is kept Classic text.",
            "family": family, "forks": records, "problems": problems})
    return records, problems


def new_line_set(record):
    lines = set()
    for first, last in record.get("newRanges", []):
        lines.update(range(first, last + 1))
    return lines


def main(argv):
    layout, positional, options = common.parse_args(argv, flags=("--quiet",))
    if len(positional) != 1:
        print(__doc__)
        return 2
    family = positional[0]
    records, problems = build(layout, family)
    if not records and not problems:
        print("%s: no forks/*.json" % family)
        return 0
    rows = [[r["name"], common.short(r["path"]), common.short(r["source"]).split(".")[-1], r["sourceLines"],
             len(r["replaced"]), r["keptLines"], r["newLines"], r["handAssembled"]] for r in records]
    print(common.table(rows, ["fork", "builds", "from Classic", "lines", "spans", "kept", "new", "hand-assembled"]))
    if "--quiet" not in options:
        for record in records:
            if record.get("firstDifference"):
                d = record["firstDifference"]
                print("\n%s differs at line %d\n  built: %s\n  hand:  %s" % (record["name"], d["line"], d["built"], d["hand"]))
            if record["watch"]:
                print("\n%s: guarded words inside the replaced spans (read each one; CONTRACT step 5)" % record["name"])
                for item in record["watch"]:
                    print("  %-7s line %-5d %s" % (item["side"], item["line"], item["text"]))
    if problems:
        raise ToolError("%s: %d fork problem(s)" % (family, len(problems)), problems)
    print("\nbuilt %d fork(s) into %s" % (len(records), layout.forks_out(family)))
    return 0


if __name__ == "__main__":
    common.run_main(main)
