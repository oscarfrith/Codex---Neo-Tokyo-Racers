"""Exotic category: one-command offline loop for refinements. See REFINE.md.

Usage (from the repo root):
  py -3 scripts/exotic_category/refine.py            regenerate, validate, test and build the three installers
  py -3 scripts/exotic_category/refine.py --previews  also render the offline preview sheets (slower)
  py -3 scripts/exotic_category/refine.py --skip-gen  keep specs/exotic.json as it is (hand-edited spec)

Steps, stopping at the first failure:
  1. gen/exotic.py                 geometry generator -> scripts/vehicle_blockouts/specs/exotic.json
  2. preview.py --check            frame-standard validator (errors stop the loop; warnings are printed)
  3. balance/build_balance.py      prices and stats -> balance/balance.json, then balance/test_balance.py
  4. stage_b/test_content.py       offline checks on the generated content
  5. stage_b/build_content.py      AUDIT, APPLY and ROLLBACK for the full scope ->
                                   stage_b/out/full_audit.lua, full_apply.lua, full_rollback.lua
It never touches Studio. It prints the Studio steps at the end.
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SPEC = os.path.join("scripts", "vehicle_blockouts", "specs", "exotic.json")
OUT = os.path.join(HERE, "stage_b", "out")


def run(label, args, tail=6):
    print("== " + label)
    proc = subprocess.run([sys.executable] + args, cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = [line for line in (proc.stdout + proc.stderr).splitlines() if line.strip()]
    for line in lines[-tail:]:
        print("   " + line[:240])
    if proc.returncode != 0:
        print("FAILED: " + label)
        sys.exit(1)


def main():
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
