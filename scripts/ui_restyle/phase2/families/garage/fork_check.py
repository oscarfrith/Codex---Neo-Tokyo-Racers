#!/usr/bin/env python3
"""Fork check for the Pulse garage family, half B (agent F6b). Standard library only.

    py -3 scripts/ui_restyle/phase2/families/garage/fork_check.py            check every forks/*.json
    py -3 scripts/ui_restyle/phase2/families/garage/fork_check.py --json     the same, result as JSON on stdout

For each forks/<Pulse module name>.json it:
  1. confirms the Classic source still equals the programme record (classic/manifest.json: length, djb2, fnv1a32);
  2. rebuilds the fork from the Classic source plus the listed spans;
  3. confirms the rebuilt text equals the hand-assembled after/ file, byte for byte;
  4. confirms, with an independent line diff, that every Classic line that changed lies inside a listed span
     and that every kept line is present, unchanged and in order;
  5. extracts remote calls (InvokeServer, FireServer), bindable calls (:Fire, :Invoke), attribute writes
     (SetAttribute) and the wrapped call sites (request, operate, call, mutate, loadingAction with a literal
     action) from both sources and confirms the two lists are identical. The one allowed difference is a
     call the fork JSON lists under "_moved" (TouchCameraGuard: the interior HUD statements of the removed
     ranges), and then the target module must contain the stated text, or the entry must carry a reason;
  6. lists every `.Enabled =` write that survives in the fork (ScreenGui.Enabled must never be among them).

Exit code 0 only when every fork passes.
"""
import collections
import difflib
import glob
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))  # scripts/ui_restyle
SOURCES = os.path.join(ROOT, "classic", "sources")
MANIFEST = os.path.join(ROOT, "classic", "manifest.json")
FORKS = os.path.join(HERE, "forks")
AFTER = os.path.join(HERE, "after")

CALL = re.compile(r"([A-Za-z_][A-Za-z0-9_\.]*)\s*:\s*(InvokeServer|FireServer|Fire|Invoke|SetAttribute)\s*\(")
# Local wrappers the Classic owners send their remote and loading calls through; the first argument is the action.
WRAPPED = re.compile(r"(?<![A-Za-z0-9_\.:])(request|operate|call|mutate|loadingAction)\s*\(\s*(?=[\"'])")
ENABLED_WRITE = re.compile(r"([A-Za-z_][A-Za-z0-9_\.]*)\.Enabled\s*=(?!=)")


def read(path):
    with io.open(path, "r", encoding="utf-8", newline="") as handle:
        return handle.read()


def djb2(data):
    value = 5381
    for byte in data:
        value = (value * 33 + byte) % 4294967296
    return value


def fnv1a32(data):
    value = 2166136261
    for byte in data:
        value = ((value ^ byte) * 16777619) % 4294967296
    return value


def manifest_entry(instance_path):
    with io.open(MANIFEST, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    for script in manifest["scripts"]:
        if script["path"] == instance_path:
            return script
    return None


def split_lines(text):
    """Lines without their LF. A trailing LF gives a last empty element, which join() restores."""
    return text.split("\n")


def balanced_arguments(text, open_index):
    """Text between the parenthesis at open_index and its match, skipping strings."""
    depth = 0
    index = open_index
    quote = None
    while index < len(text):
        char = text[index]
        if quote:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return text[open_index + 1:index]
        index += 1
    return text[open_index + 1:]


def strip_comment(line):
    """Drops a trailing `-- comment` (not inside a string). Block comments on one line are dropped too."""
    line = re.sub(r"--\[\[.*?\]\]", "", line)
    quote = None
    index = 0
    while index < len(line) - 1:
        char = line[index]
        if quote:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "-" and line[index + 1] == "-":
            return line[:index]
        index += 1
    return line


def extract_calls(text):
    """[(line, normalised call)] for every remote call, bindable call and attribute write."""
    found = []
    for number, raw in enumerate(split_lines(text), start=1):
        line = strip_comment(raw)
        for match in CALL.finditer(line):
            arguments = balanced_arguments(line, match.end() - 1)
            call = "%s:%s(%s)" % (match.group(1), match.group(2), re.sub(r"\s+", "", arguments))
            found.append((number, call))
        for match in WRAPPED.finditer(line):
            arguments = balanced_arguments(line, line.index("(", match.start()))
            found.append((number, "%s(%s)" % (match.group(1), re.sub(r"\s+", "", arguments))))
    return found


def enabled_writes(text):
    found = []
    for number, raw in enumerate(split_lines(text), start=1):
        line = strip_comment(raw)
        for match in ENABLED_WRITE.finditer(line):
            found.append({"line": number, "receiver": match.group(1), "text": line.strip()[:160]})
    return found


def rebuild(classic_lines, spans):
    """Classic lines with each 1-based inclusive span replaced by its file's lines."""
    out = []
    cursor = 1
    for first, last, replacement in spans:
        out.extend(classic_lines[cursor - 1:first - 1])
        out.extend(replacement)
        cursor = last + 1
    out.extend(classic_lines[cursor - 1:])
    return out


def check_fork(spec_path):
    name = os.path.splitext(os.path.basename(spec_path))[0]
    result = {"fork": name, "ok": False, "problems": [], "spans": [], "calls": 0, "enabledWrites": []}
    problems = result["problems"]
    with io.open(spec_path, "r", encoding="utf-8") as handle:
        spec = json.load(handle)

    source_path = os.path.join(SOURCES, spec["source"] + ".lua")
    if not os.path.isfile(source_path):
        problems.append("Classic source missing: " + source_path)
        return result
    with io.open(source_path, "rb") as handle:
        classic_bytes = handle.read()
    classic = classic_bytes.decode("utf-8")
    if "\r" in classic:
        problems.append("Classic source has CR line ends")

    entry = manifest_entry(spec["source"])
    if entry is None:
        problems.append("Classic source is not in classic/manifest.json")
    elif (entry["length"], entry["djb2"], entry["fnv1a32"]) != (len(classic_bytes), djb2(classic_bytes), fnv1a32(classic_bytes)):
        problems.append("Classic source differs from classic/manifest.json (a changed Classic source stops the build)")

    classic_lines = split_lines(classic)
    classic_count = len(classic_lines) - 1 if classic.endswith("\n") else len(classic_lines)

    spans = []
    previous_last = 0
    for item in sorted(spec["replace"], key=lambda entry_: entry_["lines"][0]):
        first, last = item["lines"]
        span_path = os.path.join(FORKS, item["with"])
        if not os.path.isfile(span_path):
            problems.append("span file missing: " + item["with"])
            return result
        span_text = read(span_path)
        if "\r" in span_text:
            problems.append("span file has CR line ends: " + item["with"])
        if not span_text.endswith("\n"):
            problems.append("span file must end with LF: " + item["with"])
        if not (1 <= first <= last <= classic_count):
            problems.append("span %d-%d is outside the Classic source (%d lines)" % (first, last, classic_count))
            return result
        if first <= previous_last:
            problems.append("spans overlap or are out of order at %d-%d" % (first, last))
            return result
        previous_last = last
        spans.append((first, last, split_lines(span_text)[:-1]))
        result["spans"].append("%d-%d" % (first, last) if first != last else str(first))

    built_lines = rebuild(classic_lines, spans)
    built = "\n".join(built_lines)

    after_path = os.path.join(AFTER, spec["_target"] + ".lua")
    if not os.path.isfile(after_path):
        problems.append("hand-assembled after/ file missing: " + os.path.basename(after_path))
        return result
    after = read(after_path)
    if after != built:
        problems.append("rebuilt fork differs from the hand-assembled after/ file")
    if "\r" in after:
        problems.append("after/ file has CR line ends")
    if len(after) >= 150000:
        problems.append("after/ file is over 150,000 characters")

    # Independent diff of Classic against the hand-assembled file: changed Classic lines must lie inside spans.
    after_lines = split_lines(after)
    matcher = difflib.SequenceMatcher(None, classic_lines, after_lines, autojunk=False)
    covered = set()
    for first, last, _ in spans:
        covered.update(range(first, last + 1))
    changed = set()
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        if i1 == i2:
            # pure insertion: it must sit at a span (the line before or after is a replaced line)
            neighbours = {i1, i1 + 1}
            if not (neighbours & covered):
                problems.append("insertion outside the listed spans before Classic line %d" % (i1 + 1))
        changed.update(range(i1 + 1, i2 + 1))
    # difflib may pair a blank kept line that sits between two spans with a blank line of a replacement; the
    # exact check below is the authority for kept lines, so only non-blank lines are reported from this diff.
    outside = sorted(number for number in changed - covered if classic_lines[number - 1].strip() != "")
    if outside:
        problems.append("Classic lines changed outside the listed spans: " + ", ".join(map(str, outside[:20])))
    # Every kept line is present, unchanged and in order (exact, not heuristic).
    kept = [line for number, line in enumerate(classic_lines, start=1) if number not in covered]
    replacement_total = sum(len(replacement) for _, _, replacement in spans)
    if len(after_lines) != len(kept) + replacement_total:
        problems.append("line count is not kept lines plus span lines")
    cursor = 0
    position = 1
    rebuilt_kept = []
    for first, last, replacement in spans:
        take = first - position
        rebuilt_kept.extend(after_lines[cursor:cursor + take])
        cursor += take + len(replacement)
        position = last + 1
    rebuilt_kept.extend(after_lines[cursor:])
    if rebuilt_kept != kept:
        problems.append("a kept Classic line is missing, changed or out of order")
    result["keptLines"] = len(kept) - (1 if classic.endswith("\n") else 0)
    result["classicLines"] = classic_count

    # Remote calls, bindable calls and attribute writes.
    classic_calls = collections.Counter(call for _, call in extract_calls(classic))
    fork_calls = collections.Counter(call for _, call in extract_calls(after))
    result["calls"] = sum(fork_calls.values())
    result["classicCalls"] = sum(classic_calls.values())
    only_classic = classic_calls - fork_calls
    only_fork = fork_calls - classic_calls
    moved = spec.get("_moved", [])
    declared = collections.Counter(re.sub(r"\s+", "", item["call"]) for item in moved)
    if only_fork:
        problems.append("calls only in the fork: " + "; ".join(sorted(only_fork.elements())))
    if only_classic != declared:
        missing = only_classic - declared
        extra = declared - only_classic
        if missing:
            problems.append("calls only in Classic and not declared as moved: " + "; ".join(sorted(missing.elements())))
        if extra:
            problems.append("declared as moved but not actually removed: " + "; ".join(sorted(extra.elements())))
    result["moved"] = []
    for item in moved:
        target = item.get("to")
        if target:
            target_path = os.path.join(AFTER, target + ".lua")
            if not os.path.isfile(target_path):
                problems.append("moved call target missing: " + target)
            elif item["expect"] not in read(target_path):
                problems.append("moved call not found in %s: %s" % (target, item["expect"]))
            result["moved"].append("%s -> %s" % (item["call"], target.split(".")[-1]))
        elif not item.get("reason"):
            problems.append("moved call has neither a target nor a reason: " + item["call"])
        else:
            result["moved"].append("%s -> dropped (%s)" % (item["call"], item["reason"]))
    # Calls in kept lines must be the same lines of text (already proven by step 4); count them for the report.
    result["keptCalls"] = sum(1 for number, _ in extract_calls(classic) if number not in covered)

    result["enabledWrites"] = enabled_writes(after)
    for write in result["enabledWrites"]:
        if re.search(r"(?i)gui$|screen", write["receiver"]):
            problems.append("possible ScreenGui.Enabled write at line %d: %s" % (write["line"], write["text"]))

    result["ok"] = not problems
    return result


def main():
    as_json = "--json" in sys.argv[1:]
    specs = sorted(glob.glob(os.path.join(FORKS, "*.json")))
    results = [check_fork(path) for path in specs]
    if not specs:
        results.append({"fork": "(none)", "ok": False, "problems": ["no forks/*.json found"], "spans": []})
    ok = all(item["ok"] for item in results)
    if as_json:
        print(json.dumps({"ok": ok, "forks": results}, indent=1))
    else:
        for item in results:
            print("%s  %s  spans %s  kept %s of %s Classic lines  calls %s (Classic %s)" % (
                "PASS" if item["ok"] else "FAIL", item["fork"], ", ".join(item["spans"]) or "-",
                item.get("keptLines", "?"), item.get("classicLines", "?"), item.get("calls", "?"), item.get("classicCalls", "?")))
            for line in item.get("moved", []):
                print("      moved: " + line)
            for write in item.get("enabledWrites", []):
                print("      Enabled write kept, line %d (%s): %s" % (write["line"], write["receiver"], write["text"]))
            for problem in item["problems"]:
                print("      PROBLEM: " + problem)
        print("fork_check: %s (%d forks)" % ("PASS" if ok else "FAIL", len(results)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
