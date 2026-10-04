# Modern Muscle: brief for building one car

You build ONE car as a Python file in this folder, to the standard of the finished hero car (the Brawler, car F in `muscle_cars.py`). Read these first, fully: `musclekit.py` (the frame), `muscle_cars.py` (shared helpers and car F, your reference), and `../../../mesh/exokit.py` (the modelling kit: `Hull`, `Loft`, regions `R`, `throat`, `cap`, `patch`, `box`, `check`). Look at the hero renders in `previews/brawler_*.jpg` and the concept images in `docs/design/vehicle-categories/img/muscle-modern/r2-*.jpg`.

## Rules of the job

- Write only `car_<letter>.py` in this folder and your own renders in `previews/` named `<name>_*.jpg`. Do not edit `musclekit.py`, `muscle_cars.py`, `exokit.py` or another car's file. Do not run git. Do not touch Roblox Studio or the live Blender session.
- Your file imports the shared helpers from `muscle_cars` (`tube`, `xtube`, `barrel`, `bazooka`, `halo`, `lift_glow`, `flange`, `tub`, `LINE`, `POD_LINE`, `SLOTS`, `build_car`) and the frame from `musclekit`. It defines one function per module (`<l>_cockpit`, `<l>_nose`, `<l>_tail`, `<l>_fpod`, `<l>_rpod`, `<l>_stab`, `<l>_boost`, `<l>_wing`), a `car_<l>()` that calls them, and `def build(out=None): return build_car("<name>", "<LETTER>", car_<l>, out=out)`.
- Build and render headless (takes about a minute), then LOOK at the renders with the Read tool and iterate. Run from the repo root:
  `"/c/Program Files/Blender Foundation/Blender 4.5/blender.exe" --background --factory-startup --python scripts/exotic_category/categories/muscle/mesh/run_headless.py -- car_<letter> 2>&1 | grep -E "RESULT|Error|Traceback|rror"`
  It prints `RESULT {...}`; `problems` must be an empty list (every module inside its envelope, with a primary and a secondary channel). It writes six full views and eight close-ups to `previews/<name>_*.jpg`.
- Write files with the file tools, not shell heredocs. ASCII only, UK English, short comments, match the style of `muscle_cars.py`.
- STD trim only. Begin every module with `K.begin("<LETTER>", "<SLOT>")`.

## The frame (do not break it)

Game space: +X right, +Y up, forward is -Z. Eight modules meet on fixed faces so any part fits any car:

- COCKPIT: `tub()` (the shared body between the seams, call it unchanged) plus your greenhouse on top. The greenhouse may only lap onto the cowl and deck inside the COCKPIT envelope.
- NOSE: starts from the front seam `SEAM_F` at `Z_F` and must end `GAP` short of it (`t1=Z_F - GAP`). Its last station is `(Z_F, SEAM_F)`.
- TAIL: first station `(Z_R, SEAM_R)`, built from `t0=Z_R + GAP`. Leave the lower rear centre open for BOOST (the Brawler kicks the floor up from z 10.6).
- FPOD: its last station is `(POD_FZ, SIDE_F)`. RPOD: its first station is `(POD_RZ, SIDE_R)`. Use `flange()` to fill the gap to the body.
- STAB: sill unit between the pods (z `POD_FZ + 0.1` to `POD_RZ - 0.1`), inboard face at x 4.1.
- BOOST: centre of the tail under the bumper. WING: on the deck.
- Envelopes are in `musclekit.K.ENV`. The check allows 0.1 of overrun.
- Headlights live on the FPOD front faces. The grille lives on the NOSE. Tail lamps live on the TAIL. The front pod's jet exits through its rear face (`pod.throat("noz", "max", ..., back="thrust")`); the rear pod has a nozzle at the tail; drift thrusters are in the sill and sweep back and down (`bazooka`); overdrive nozzles are in BOOST.
- No wheels and nothing wheel-like. Pod flanks are solid.
- Paint channels: `primary`, `secondary` (two-tone, player paintable), `detail` (dark trim), `glass`, `lights`, `lights_red`, `thrust` (jet glow), `metal` (bare metal hardware). Every module needs at least one `primary` and one `secondary` face. The preview paint for your letter is already in `musclekit.K.PAINT`.

## What Oscar approved on the hero car (apply all of it)

1. Clean and minimal. The standard trim is shape, lamps, glass, stripe and jets only. No vents, louvres, bolts, scoops, straps, door lines, handles or filler detail: those are for the GT and EVO upgrades later. It must read cleanly, sleek and sharp, and be recognisable at a glance.
2. Copy the real car. Proportions, roofline, grille shape, light signature and tail are the real car's, adapted to the frame. Less boxy: the body has tumblehome and crown, pods are fenders with rounded shoulders and one character line (`POD_LINE`), not plain boxes and not Exotic-style teardrops.
3. Cabin: wide (nearly the body width), long and low, one continuous roof arc with a moderate crown; body-colour pillars of medium width; a black centre pillar; each glass (`glass`, depth 0.04) set inside a thin black surround (`detail`, depth 0.015). See `f_cockpit` and keep those proportions unless your real car differs (say how).
4. Rear engine pods must not overpower the car: no taller than the deck, only a little bigger than the front pods.
5. Nozzles follow the car's shapes, not plain round pipes: use `barrel(..., ry=..., n=...)` and `bazooka(...)` for rounded rectangles; choose shapes that suit your car's lamps and grille and are different from the Brawler's where the visual language table says so.
6. Smooth lines: no kinks along the roof, bonnet or deck; no parts floating, clashing or showing cut ends; even shadow gaps.
7. The bonnet turbine is part of the NOSE and its size is per car (your spec says what you get).

## Self-check before you report (look at every render)

Front, rear, side, top, front low, rear high, and the eight close-ups. For each: does it read as the real car at a glance; any wheel-like shape; any floating, intersecting or cut-off part; lamps present front and rear; glass surrounds even; nozzles glowing and clean; rear pods not too big; nothing outside the envelope. Fix, rebuild, look again. Three or more build-and-look rounds are expected.

## Report back (short)

The file you wrote; the final RESULT line; what the car's distinguishing features are (nose, lamps, bonnet, tail, pods, nozzles, wing, cabin); anything you could not make work or are unhappy with; anything in the frame that got in your way. Do not paste code.
