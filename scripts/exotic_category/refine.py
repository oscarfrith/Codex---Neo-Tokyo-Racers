"""Vehicle categories: one-command offline loop for refinements. See REFINE.md.

Usage (from the repo root):
  py -3 scripts/exotic_category/refine.py            regenerate, validate, test and build the three installers
  py -3 scripts/exotic_category/refine.py --previews  also render the offline preview sheets (slower)
  py -3 scripts/exotic_category/refine.py --skip-gen  keep specs/exotic.json as it is (hand-edited spec)
  py -3 scripts/exotic_category/refine.py --category muscle   the same loop for another category (see below)

Steps for Exotic (the default), stopping at the first failure:
  1. gen/exotic.py                 geometry generator -> scripts/vehicle_blockouts/specs/exotic.json
  2. preview.py --check            frame-standard validator (errors stop the loop; warnings are printed)
  3. balance/build_balance.py      prices and stats -> balance/balance.json, then balance/test_balance.py
  4. stage_b/test_content.py       offline checks on the generated content
  5. stage_b/build_content.py      AUDIT, APPLY and ROLLBACK for the full scope ->
                                   stage_b/out/full_audit.lua, full_apply.lua, full_rollback.lua

Steps for another category (categories/<id>/category.json names its spec):
  1. preview.py --check            on the category's spec. The spec generator is NOT run: the spec is kept as it is.
  2. balance/build_balance.py --category <id>, then balance/test_balance.py --category <id>
  3. stage_b/test_content.py --category <id>
  4. stage_b/build_content.py --category <id>   AUDIT and APPLY for the full scope ->
                                   categories/<id>/out/full_audit.lua, full_apply.lua (and post_install_checks.lua)
     No ROLLBACK installer is built: the working place saves, and ROLLBACK is not used there.
It never touches Studio. It prints the Studio steps at the end.
"""
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SPEC = os.path.join("scripts", "vehicle_blockouts", "specs", "exotic.json")
OUT = os.path.join(HERE, "stage_b", "out")
DEFAULT_CATEGORY = "exotic"


def run(label, args, tail=6):
    print("== " + label)
    proc = subprocess.run([sys.executable] + args, cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = [line for line in (proc.stdout + proc.stderr).splitlines() if line.strip()]
    for line in lines[-tail:]:
        print("   " + line[:240])
    if proc.returncode != 0:
        print("FAILED: " + label)
        sys.exit(1)


def category_argument(argv):
    """The value after --category, or exotic."""
    if "--category" not in argv:
        return DEFAULT_CATEGORY
    index = argv.index("--category")
    if index + 1 >= len(argv) or argv[index + 1].startswith("--"):
        print("FAILED: --category needs a category id (for example muscle)")
        sys.exit(1)
    return argv[index + 1]


def refine_category(category):
    """The loop for a category other than Exotic. Its spec is validated as it is; no ROLLBACK installer is built."""
    root = os.path.join(HERE, "categories", category)
    config_path = os.path.join(root, "category.json")
    if not os.path.isfile(config_path):
        print("FAILED: unknown category %r (%s is missing)" % (category, config_path))
        sys.exit(1)
    with open(config_path, "r", encoding="utf-8") as f:
        spec = json.load(f)["spec"]
    out = os.path.join(root, "out")
    relative_out = os.path.relpath(out, REPO).replace("\\", "/")
    select = ["--category", category]
    run("validate the frame standard", ["scripts/vehicle_blockouts/preview.py", spec, "--check"], tail=12)
    if "--previews" in sys.argv:
        run("render previews", ["scripts/vehicle_blockouts/preview.py", spec], tail=4)
    run("rebuild the balance data", ["scripts/exotic_category/balance/build_balance.py"] + select, tail=3)
    run("balance tests", ["scripts/exotic_category/balance/test_balance.py"] + select, tail=2)
    run("content tests", ["scripts/exotic_category/stage_b/test_content.py"] + select, tail=2)
    for mode in ("AUDIT", "APPLY"):
        run("build %s (full)" % mode, ["scripts/exotic_category/stage_b/build_content.py"] + select
            + ["--mode", mode, "--scope", "full", "--out", os.path.join(out, "full_%s.lua" % mode.lower())], tail=1)
    print("""
Offline loop passed for %s. In Studio (Space Racers v3, Edit, Play stopped):
  1. Serve the repo:  py -3 -m http.server 8793 --bind 127.0.0.1   (from the repo root, in the background)
  2. Run %s/full_audit.lua, read the findings, then full_apply.lua:
       return loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8793/%s/full_audit.lua", true))()
     APPLY replaces this installer's earlier content; the chunks of other categories must not change.
     There is no ROLLBACK installer for this category.
  3. Run %s/post_install_checks.lua the same way, restart Play, and look at the result in the dealership.
""" % (category, relative_out, relative_out, relative_out))


def main():
    category = category_argument(sys.argv)
    if category != DEFAULT_CATEGORY:
        refine_category(category)
        return
    if "--skip-gen" not in sys.argv:
        run("generate the spec", ["scripts/vehicle_blockouts/gen/exotic.py"], tail=2)
    run("validate the frame standard", ["scripts/vehicle_blockouts/preview.py", SPEC, "--check"], tail=12)
    if "--previews" in sys.argv:
        run("render previews", ["scripts/vehicle_blockouts/preview.py", SPEC], tail=4)
    run("rebuild the balance data", ["scripts/exotic_category/balance/build_balance.py"], tail=3)
    run("balance tests", ["scripts/exotic_category/balance/test_balance.py"], tail=2)
    run("content tests", ["scripts/exotic_category/stage_b/test_content.py"], tail=2)
    for mode in ("AUDIT", "APPLY", "ROLLBACK"):
        run("build %s (full)" % mode, ["scripts/exotic_category/stage_b/build_content.py", "--mode", mode, "--scope", "full"], tail=1)
        shutil.copyfile(os.path.join(OUT, "installer.lua"), os.path.join(OUT, "full_%s.lua" % mode.lower()))
    print("""
Offline loop passed. In Studio (Space Racers v3, Edit, Play stopped):
  1. Serve the repo:  py -3 -m http.server 8793 --bind 127.0.0.1   (from the repo root, in the background)
  2. Run stage_b/out/full_audit.lua, read the findings, then full_apply.lua (REFINE.md has the snippet).
     APPLY replaces this installer's earlier content; Piercer chunks must not change.
  3. Run stage_b/post_install_checks.lua, restart Play, and look at the result in the dealership.
""")


if __name__ == "__main__":
    main()
