"""One table of every wave-2 unit: files present, lint findings, parity result, forks, assembled or not.

    py -3 status.py [--json]

Reads the agents' folders and install/state.json; runs lint_phase2 and parity_check in memory. Writes nothing.
"""
import json
import os

import common
from common import ToolError
import lint_phase2
import parity_check


def unit_row(layout, unit, known, entries, state):
    row = {"unit": common.unit_folder(unit), "sources": 0, "tests": 0, "missing": [], "lint": "-", "parity": "-",
           "forks": "-", "assembled": "no"}
    if unit == "kit":
        sources, tests, problems, present = common.kit_sources(layout)
        row["sources"], row["tests"] = len(sources), len(tests)
        row["missing"] = [agent for agent in common.KIT_AGENTS if agent not in present]
        if not os.path.isfile(os.path.join(layout.integrator, "tokens_flat.json")):
            row["missing"].append("tokens_flat.json")
        row["missing"] += [p for p in problems if "twice" in p]
    elif unit == "flip":
        row["sources"] = row["tests"] = "-"
    else:
        folder = layout.family_dir(unit)
        if not os.path.isdir(folder):
            row["missing"] = ["folder"]
        else:
            sources, tests, forks = common.family_sources(layout, unit)
            row["sources"], row["tests"] = len(sources), len(tests)
            for name in ("CONTRACT.md", "NOTES.md"):
                if not common.document_present(folder, name):
                    row["missing"].append(name)
            for base in ("contract", "routes", "spec_ops"):
                try:
                    if not common.fragments(folder, base):
                        row["missing"].append(base + ".json")
                except ToolError:
                    row["missing"].append(base + ".json (invalid JSON)")
            forks_dir = os.path.join(folder, "forks")
            declared = [n for n in os.listdir(forks_dir) if n.endswith(".json")] if os.path.isdir(forks_dir) else []
            if declared:
                index = os.path.join(layout.forks_out(unit), "forks.json")
                if os.path.isfile(index):
                    data = common.read_json(index)
                    differs = sum(1 for r in data["forks"] if r.get("handAssembled") == "differs")
                    row["forks"] = "%d of %d built%s%s" % (len(data["forks"]), len(declared),
                                                          ", %d differ" % differs if differs else "",
                                                          ", %d problems" % len(data["problems"]) if data.get("problems") else "")
                else:
                    row["forks"] = "%d not built" % len(declared)
            if "contract.json" not in row["missing"] and row["sources"]:
                try:
                    result = parity_check.check(layout, unit)
                    row["parity"] = "ok" if not result["open"] else "%d open" % result["open"]
                except ToolError as error:
                    row["parity"] = "error: " + error.title[:40]
    if unit != "flip" and row["sources"]:
        try:
            result = lint_phase2.lint_unit(layout, unit, known, entries)
            lint_phase2.apply_accept(result["findings"], lint_phase2.load_accept(
                os.path.join(layout.integrator, "lint_accept.json")))
            counts = lint_phase2.summarise(result)
            row["lint"] = "ok" if not counts["open"] else "%d open" % counts["open"]
            if counts["accepted"]:
                row["lint"] += " (%d accepted)" % counts["accepted"]
        except ToolError as error:
            row["lint"] = "error: " + error.title[:40]
    record = state["units"].get(common.unit_folder(unit))
    if record:
        built = os.path.isfile(os.path.join(layout.unit_dir(unit), "out_apply.lua"))
        row["assembled"] = ("provisional" if not record.get("installable", True) else "yes") + ("" if built else ", not built")
    return row


def main(argv):
    layout, positional, options = common.parse_args(argv, flags=("--json",))
    state_path = layout.state_path()
    state = common.read_json(state_path) if os.path.isfile(state_path) else {"units": {}}
    known, entries = lint_phase2.all_known(layout)
    rows = [unit_row(layout, unit, known, entries, state) for unit in common.ORDER]
    if "--json" in options:
        print(json.dumps(rows, indent=1))
        return 0
    print(common.table([[r["unit"], r["sources"], r["tests"], ", ".join(r["missing"]) or "-", r["forks"], r["lint"],
                         r["parity"], r["assembled"]] for r in rows],
                       ["unit", "sources", "tests", "missing", "forks", "lint", "parity", "assembled"]))
    noop = os.path.join(layout.integrator, "UIPulse.NoOp.lua")
    print("\nintegrator/UIPulse.NoOp.lua: %s   install chain: %s" % (
        "present" if os.path.isfile(noop) else "MISSING", ", ".join(sorted(state["units"])) or "nothing assembled"))
    return 0


if __name__ == "__main__":
    common.run_main(main)
