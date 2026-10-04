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

## Round 2 (Oscar, 2026-10-04): the engines and side pods must be really distinctive

Oscar's review of the first six: "they all look good on the whole, but the engines, side pods etc. need to look more distinctive, all the vehicles look way too similar right now. make them really distinctive but ensure they look great, sleek, follow car design principles."

The cause: every car used the same fender-shaped pod and the same box sill. In this round each car gets its own POD AND SILL ARCHITECTURE (your task prompt names it). This overrides anything above that says pods are "fenders with rounded shoulders".

- The hero reference is now `car_f.py` (the Brawler). Shared helpers are in `muscle_cars.py`. All six cars are in `car_a.py` to `car_f.py`; `lineup.py` builds them together.
- Change FPOD, RPOD and STAB (and BOOST nozzles if your architecture needs it). Leave your COCKPIT, NOSE, TAIL and WING as they are unless your task prompt lists a fix.
- **Frame rule relaxed for pod ends.** A pod no longer has to end on the exact `SIDE_F` / `SIDE_R` section. It must still end at the planes `POD_FZ` (front pod rear end) and `POD_RZ` (rear pod front end), keep its inboard face at x 4.1, stay inside its envelope, and its end face must cover the sill's end (any sill fits in the box x 4.1 to 5.9, y -1.25 to 1.1), so no hole shows when another car's sill is fitted. The sill still runs from `POD_FZ + 0.1` to `POD_RZ - 0.1` and must stay inside that same box apart from its nozzles, so it fits between any car's pods.
- Distinctive means the silhouette of the pod itself differs: its section (round, square, hexagonal, blade, wedge), its plan shape, how it starts and ends, where its mass sits, and how the nozzle leaves it. Paint and small details do not count.
- Car design principles to hold to: one clear theme per car, repeated in pod, sill, lamp and nozzle; lines that flow from the nose through the pods to the tail with no breaks or kinks; calm surfaces with one or two strong lines rather than many; good stance (visually planted, nose slightly lower than tail); clean highlights; pods that look designed with the body, not bolted-on boxes; and proportion: rear pods no taller than the deck and not overpowering, front pods lower than the bonnet.
- Still clean and minimal (rule 1 above): the difference must come from form, not from added vents, bolts or greebles.
- Headlights stay on the front pods; the front pod jet still exits at its rear face or flank; no wheels and nothing wheel-like.

## Round 4 (Oscar, 2026-10-04): GT and EVO kits

Oscar: "ok looking good on the whole. lets do the gt and evo kits now. ensure the kits stay in theme for the cars, and accentuate their features, but still look like clear upgrades. for the challenger, the standard kit should have a basic hood, then the gt and evo can have hood scoops / turbines. the other cars can also have hood scoops or turbines as upgradable modules too. the themes of the cars are looking good though, just dive into those a bit further."

What a kit is. Every module slot except the cockpit exists in three versions on the same mounting: STD, GT and EVO. In the game each is a separate part a player buys and fits (Front Body = NOSE, Rear Body = TAIL, Front Engine = FPOD, Rear Engine = RPOD, Drift Thrusters = STAB, Overdrive = BOOST, Wing = WING), and any version of any part may be fitted to any car. So:

- Restructure your file: every module function except the cockpit takes `trim` and starts with `K.begin("<LETTER>", "<SLOT>", trim)`; `car_<l>()` builds the cockpit once and the seven modules for each of `TRIMS`. Use `LVL[trim]` and `pick(trim, std, gt, evo)` from `muscle_cars`. Your approved STD shapes must stay as they are, apart from the bonnet rule below.
- **The bonnet rule.** STD has a basic bonnet: the car's stripe, bulge or insert only, with NO scoop and NO turbine standing on it. GT adds a bonnet scoop or intake in your car's style. EVO adds the full bonnet turbine (or your car's top intake hardware). The bonnet hardware is part of NOSE and must stay inside the NOSE turbine zone (|x| under 2.2, y 3.0 to 5.2, z -11.0 to -5.2). If your STD car has a turbine or scoop today, move it to GT or EVO.
- **GT** = a clear step up that a player sees at a glance from front, side and rear: the first layer of performance hardware in your car's own language. **EVO** = the full kit: the same themes pushed further, bigger and more of them, clearly above GT. A car in all-EVO parts should look like the meanest version of THAT car, not like a different car, and not like any other car's EVO.
- Stay in theme and accentuate the car's own features. Take what already makes your car itself (its lamp shape, its nozzle shape, its pod architecture, its stripe, its line) and build the kit hardware from those shapes. The hardware that standard trim deliberately left out now belongs here: bonnet scoops and turbines, splitters, canards and dive planes, vents and louvres, side skirts and blades, bigger and more nozzles, intake rings, heat shields, diffusers and strakes, taller and wider wings, fins, extra lamps. Pick the ones that suit your car; do not use all of them.
- Do not share kit hardware designs with the other cars. On the previous category the owner rejected kits because "GT and EVO kits looked the same across cars". Your task prompt gives your car's kit motif.
- Each slot must change visibly in GT and again in EVO (seven slots, three versions each), including the engines: pods, sill and overdrive get more, bigger or more elaborate nozzles and hardware in your architecture. Rear pods may grow a little in EVO but must still not overpower the car.
- Still good design: clear, deliberate, well-proportioned parts with clean lines. More hardware, not clutter. Nothing floating, clashing or cut off. No wheels or wheel-like shapes.
- Frame and swap rules still hold for every trim: same seams, same pod planes and sill box, inside the envelopes (`K.check()` must return no problems for all 19 modules). Kit parts must make sense on other cars: wing uprights and fins should reach down to about y 2.9 so they bury into any deck (decks sit between about 3.3 and 3.6, and two cars have a load bed or tonneau there), and should stand between |x| 2.6 and 3.5; splitters belong to NOSE (zone below y 0.6, forward to z -13.9); diffusers and strakes belong to TAIL (zone below y 1.0, back to z 13.4) and must leave the BOOST zone (|x| under 2.9, y -0.8 to 1.5, z 10.6 to 13.4) clear; canards go on the FPOD or the NOSE inside their envelopes.
- Every module in every trim still needs at least one `primary` and one `secondary` face.

Building: the same headless command. `build_car` now detects your trims and writes, besides the STD renders under the old names: `previews/<name>_gt_*.jpg` and `<name>_evo_*.jpg` (front, rear, side, rearhigh, and close-ups c_nose, c_fpod, c_rpod, c_tail) and `previews/<name>_kits_front.jpg` / `_kits_rear.jpg` showing STD, GT and EVO side by side. The RESULT line lists `trims` and must show `"problems": []`. A build takes two to three minutes now.

Self-check for kits: look at the kits_front and kits_rear sheets first: is the step from STD to GT obvious, and GT to EVO obvious again, from across the room? Then every GT and EVO view and close-up: in theme, clean, nothing floating or clashing, STD unchanged apart from the bonnet. Three or more build-and-look rounds.

## Self-check before you report (look at every render)

Front, rear, side, top, front low, rear high, and the eight close-ups. For each: does it read as the real car at a glance; any wheel-like shape; any floating, intersecting or cut-off part; lamps present front and rear; glass surrounds even; nozzles glowing and clean; rear pods not too big; nothing outside the envelope. Fix, rebuild, look again. Three or more build-and-look rounds are expected.

## Report back (short)

The file you wrote; the final RESULT line; what the car's distinguishing features are (nose, lamps, bonnet, tail, pods, nozzles, wing, cabin); anything you could not make work or are unhappy with; anything in the frame that got in your way. Do not paste code.
