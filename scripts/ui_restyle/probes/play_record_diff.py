#!/usr/bin/env python3
"""Compare two saved play_record.lua results (standard library only).

Usage:
    py -3 play_record_diff.py A.json B.json [--detail] [--visible-only] [--json]

Each file holds the JSON string returned by play_record.lua. A file that holds that string
JSON-encoded once more (a quoted string), or wrapped in other text by the tool, is accepted:
the first balanced {...} object that parses is used.

Two runs of the same capture point should match. Whatever differs between two runs of the
SAME style is an unstable field: add its instance name to ARGS.ignore.names (or the ScreenGui
to ARGS.ignore.guis, or a field to ARGS.ignore.fields) and take both runs again.

--detail        also compare per-instance rows (records taken with ARGS.detail)
--visible-only  compare visHash instead of hash (ignores hidden subtrees)
--json          print a machine-readable summary instead of text

Exit code: 0 identical, 1 different, 2 usage or file error.
"""
import json
import sys


def load(path):
    with open(path, "r", encoding="utf-8-sig") as handle:
        text = handle.read()
    value = None
    try:
        value = json.loads(text)
    except ValueError:
        value = None
    hops = 0
    while isinstance(value, str) and hops < 3:
        try:
            value = json.loads(value)
        except ValueError:
            break
        hops += 1
    if isinstance(value, dict) and "guis" in value:
        return value
    # Fall back: find the first balanced object in the text that parses and has "guis".
    decoder = json.JSONDecoder()
    start = text.find("{")
    while start != -1:
        try:
            candidate, _ = decoder.raw_decode(text[start:])
        except ValueError:
            candidate = None
        if isinstance(candidate, dict) and "guis" in candidate:
            return candidate
        start = text.find("{", start + 1)
    raise ValueError("%s: no play_record object found" % path)


def by_name(guis):
    """Map name -> list of entries (a name can occur more than once in PlayerGui)."""
    out = {}
    for entry in guis:
        out.setdefault(entry.get("name", "?"), []).append(entry)
    return out


def compare(a, b, visible_only=False, detail=False):
    hash_key = "visHash" if visible_only else "hash"
    report = {
        "labels": [a.get("label"), b.get("label")],
        "runs": [a.get("run"), b.get("run")],
        "settings": [],
        "missing_in_b": [],
        "missing_in_a": [],
        "changed": [],
        "same": [],
        "startup": [],
        "console_only_a": [],
        "console_only_b": [],
        "detail": [],
    }
    for key in ("geometry", "ignore", "viewport", "version"):
        if a.get(key) != b.get(key):
            report["settings"].append({"key": key, "a": a.get(key), "b": b.get(key)})

    left, right = by_name(a.get("guis", [])), by_name(b.get("guis", []))
    for name in sorted(set(left) | set(right)):
        entries_a, entries_b = left.get(name, []), right.get(name, [])
        if not entries_b:
            report["missing_in_b"].append(name)
            continue
        if not entries_a:
            report["missing_in_a"].append(name)
            continue
        if len(entries_a) != len(entries_b):
            report["changed"].append({"name": name, "fields": {"instances_of_gui": [len(entries_a), len(entries_b)]}})
            continue
        # play_record sorts same-named guis by hash, so pair them in order.
        for index, (one, two) in enumerate(zip(entries_a, entries_b)):
            fields = {}
            for key in ("enabled", "displayOrder", "count", "hashed", "visible", "ignoredSubtrees", hash_key):
                if one.get(key) != two.get(key):
                    fields[key] = [one.get(key), two.get(key)]
            label = name if len(entries_a) == 1 else "%s[%d]" % (name, index + 1)
            if fields:
                report["changed"].append({"name": label, "fields": fields})
            else:
                report["same"].append(label)

    states_a = (a.get("startupState") or {}).get("statuses") or {}
    states_b = (b.get("startupState") or {}).get("statuses") or {}
    for name in sorted(set(states_a) | set(states_b)):
        if states_a.get(name) != states_b.get(name):
            report["startup"].append({"name": name, "a": states_a.get(name), "b": states_b.get(name)})

    def messages(record):
        console = record.get("console") or {}
        return {row[0] for row in console.get("messages") or [] if row}

    console_a, console_b = messages(a), messages(b)
    report["console_only_a"] = sorted(console_a - console_b)
    report["console_only_b"] = sorted(console_b - console_a)

    if detail:
        detail_a, detail_b = a.get("detail"), b.get("detail")
        if not detail_a or not detail_b:
            report["detail"].append({"note": "one or both records have no detail rows (take them with ARGS.detail)"})
        elif (detail_a.get("gui"), detail_a.get("root")) != (detail_b.get("gui"), detail_b.get("root")):
            report["detail"].append({"note": "detail scopes differ", "a": [detail_a.get("gui"), detail_a.get("root")], "b": [detail_b.get("gui"), detail_b.get("root")]})
        else:
            key = "v" if visible_only else "h"
            rows_a = {row["p"]: row for row in detail_a.get("rows", [])}
            rows_b = {row["p"]: row for row in detail_b.get("rows", [])}
            for path in sorted(set(rows_a) | set(rows_b)):
                one, two = rows_a.get(path), rows_b.get(path)
                if one is None or two is None:
                    report["detail"].append({"path": path, "only_in": "a" if two is None else "b", "class": (one or two).get("c")})
                elif one.get(key) != two.get(key) or one.get("n") != two.get("n"):
                    row = {"path": path, "class": one.get("c"), "n": [one.get("n"), two.get("n")], "hash": [one.get(key), two.get(key)]}
                    if one.get("d") is not None or two.get("d") is not None:
                        row["descriptor"] = [one.get("d"), two.get("d")]
                    report["detail"].append(row)
            if detail_a.get("truncated") or detail_b.get("truncated"):
                report["detail"].append({"note": "detail rows were truncated; narrow ARGS.detail.root or lower depth"})

    report["identical"] = not (
        report["missing_in_a"] or report["missing_in_b"] or report["changed"] or report["startup"]
        or report["console_only_a"] or report["console_only_b"]
        or any("path" in row for row in report["detail"])
    )
    return report


def deepest(rows):
    """Detail rows that have no differing row beneath them: the places to look."""
    paths = [row["path"] for row in rows if "path" in row]
    out = []
    for row in rows:
        if "path" not in row:
            continue
        prefix = row["path"] + "."
        if not any(other.startswith(prefix) for other in paths):
            out.append(row)
    return out


def print_text(report, show_detail):
    print("A: label=%r run=%r" % (report["labels"][0], report["runs"][0]))
    print("B: label=%r run=%r" % (report["labels"][1], report["runs"][1]))
    for item in report["settings"]:
        print("SETTING DIFFERS  %s: %r vs %r  (records are not comparable unless this is intended)" % (item["key"], item["a"], item["b"]))
    for name in report["missing_in_b"]:
        print("ONLY IN A        %s" % name)
    for name in report["missing_in_a"]:
        print("ONLY IN B        %s" % name)
    for item in report["changed"]:
        parts = ["%s %r -> %r" % (key, pair[0], pair[1]) for key, pair in sorted(item["fields"].items())]
        print("DIFFERENT        %s: %s" % (item["name"], "; ".join(parts)))
    for item in report["startup"]:
        print("STARTUP STATE    %s: %r vs %r" % (item["name"], item["a"], item["b"]))
    for message in report["console_only_a"]:
        print("CONSOLE ONLY A   %s" % message)
    for message in report["console_only_b"]:
        print("CONSOLE ONLY B   %s" % message)
    if show_detail:
        rows = report["detail"]
        for row in rows:
            if "note" in row:
                print("DETAIL NOTE      %s" % row["note"])
        leaves = deepest(rows)
        for row in leaves:
            if "only_in" in row:
                print("DETAIL ONLY %s    %s (%s)" % (row["only_in"].upper(), row["path"], row.get("class")))
            else:
                print("DETAIL DIFFERENT %s (%s) n %r -> %r" % (row["path"], row.get("class"), row["n"][0], row["n"][1]))
                if "descriptor" in row:
                    print("    A: %s" % row["descriptor"][0])
                    print("    B: %s" % row["descriptor"][1])
        if leaves:
            names = sorted({row["path"].split(".")[-1].split("#")[0] for row in leaves})
            print("Candidate ARGS.ignore.names (check each before adding): %s" % ", ".join('"^%s$"' % name for name in names))
    print("%d ScreenGui(s) identical, %d different, %d only in one record" % (
        len(report["same"]), len(report["changed"]), len(report["missing_in_a"]) + len(report["missing_in_b"])))
    print("RESULT: %s" % ("IDENTICAL" if report["identical"] else "DIFFERENT"))


def main(argv):
    flags = {arg for arg in argv[1:] if arg.startswith("--")}
    files = [arg for arg in argv[1:] if not arg.startswith("--")]
    unknown = flags - {"--detail", "--visible-only", "--json"}
    if len(files) != 2 or unknown:
        sys.stderr.write(__doc__)
        return 2
    try:
        a, b = load(files[0]), load(files[1])
    except (OSError, ValueError) as error:
        sys.stderr.write("error: %s\n" % error)
        return 2
    report = compare(a, b, visible_only="--visible-only" in flags, detail="--detail" in flags)
    if "--json" in flags:
        print(json.dumps(report, indent=1, sort_keys=True))
    else:
        print_text(report, "--detail" in flags)
    return 0 if report["identical"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
