"""Headless builder for one Modern Muscle car, so several cars can be worked on at once without the live
Blender session.

    "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" --background --factory-startup \
        --python scripts/exotic_category/categories/muscle/mesh/run_headless.py -- <module> [out_dir]

<module> is a file in this folder that defines build(out=None) and returns the build_car() result, for
example car_a. Use muscle_cars for the Brawler. The result is printed as one line starting RESULT.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [os.path.abspath(os.path.join(HERE, "..", "..", "..", "mesh")), HERE]
args = sys.argv[sys.argv.index("--") + 1:]
import exokit  # noqa: E402,F401
import musclekit  # noqa: E402,F401
module = __import__(args[0])
out = args[1] if len(args) > 1 else None
result = module.build(out=out) if hasattr(module, "build") else module.build_car("brawler", "F", module.car_f, out=out)
print("RESULT " + json.dumps({k: v for k, v in result.items() if k != "shots"}))
