"""Classic verify for the drivetrain_feel delivery (AGENTS: Classic is frozen and hash-checked).

    py -3 scripts/drivetrain_feel/classic_declared.py      (after build.py)

Starts from the cumulative declared set of the last ui_restyle install (phase2/install/07_shell/declared.json) and
re-pins every script this delivery changes to its after-hash: the Classic-recorded driving, audio and session scripts
under "scripts", the Pulse gauge and HUD under "addedScripts". Writes classic/declared.json and
classic/out_verify_classic_after.lua. Run that check after APPLY; before APPLY (and after ROLLBACK) the committed
07_shell set still applies (scripts/ui_restyle/phase2/install/07_shell/out_verify_classic.lua or a rebuild of it).
"""
import io
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CLASSIC = os.path.join(ROOT, "scripts", "ui_restyle", "classic")
BASE_DECLARED = os.path.join(ROOT, "scripts", "ui_restyle", "phase2", "install", "07_shell", "declared.json")
sys.path.insert(0, CLASSIC)
from build_manifest import djb2, fnv1a32  # noqa: E402

sys.path.insert(0, HERE)
from build import SCRIPTS  # noqa: E402

PULSE = {"HudView", "Kit.Gauge", "Fixtures.Gauge"}


def main():
    declared = json.load(io.open(BASE_DECLARED, encoding="utf-8"))
    changed = []
    for name, (path, file, part) in SCRIPTS.items():
        after = os.path.join(HERE, "after", file)
        if not os.path.exists(after):
            continue
        data = io.open(after, "rb").read()
        pin = {"length": len(data), "djb2": djb2(data), "fnv1a32": fnv1a32(data)}
        dotted = ".".join(path)
        if name in PULSE:
            entry = dict(declared["addedScripts"].get(dotted, {}))
            entry.update(pin)
            entry.setdefault("class", "ModuleScript")
            declared["addedScripts"][dotted] = entry
        else:
            declared["scripts"][dotted] = pin
        changed.append(dotted)
    out_dir = os.path.join(HERE, "classic")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "declared.json")
    io.open(path, "w", encoding="utf-8", newline="\n").write(json.dumps(declared, indent=1, sort_keys=True) + "\n")
    out = os.path.join(out_dir, "out_verify_classic_after.lua")
    subprocess.check_call([sys.executable, "build_verify.py", "--declared", path, "--out", out], cwd=CLASSIC)
    print("re-pinned", len(changed), "scripts:", ", ".join(sorted(changed)))


if __name__ == "__main__":
    main()
