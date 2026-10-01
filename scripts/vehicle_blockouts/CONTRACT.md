# Vehicle frame classes: exploration contract (round 2)

Status: design exploration, round 2, 2026-10-01. Nothing here is game content or approved. The design contract this feeds is [docs/design/vehicle-frame-classes.md](../../docs/design/vehicle-frame-classes.md).

This file is the shared brief for the parallel agents. The integrator (main session) owns Studio, git and every file not listed under "Who writes what". Round 1 specs are in git history (commit 7701b16).

## 0. What Oscar said after round 1

> "this seems a good start, however im not so sure about having wheels or wheel like aspects, more thruster and jet type stuff is better. i'd also like more categories similar to real life cars. doesnt matter if they are close to real cars, just generate anyway. also, make sure with these options, when you switch modules between cockpits, the assets fit well, look great, but still have good visual differences with other cockpit modules. continue to refine all the previous models you made, and make me 3 new categories for realistic looking cars, but hover jet versions. also, ensure each category has engine, stabiliser and boost modules on each cockpit, these are fundamental to the vehicles. they dont need to be in set locations, whatever works best for the category"

What that changes:

1. **No wheels and nothing wheel-like.** No rings, hoops, discs, rotors, drums, rims or tyre-shaped parts, upright or flat. Lift and thrust come from jets: turbines with an intake and a nozzle, downward lift jets, vectoring nozzles, afterburner cans, thrust paddles, vane cascades, small control jets. A nozzle or pod is longer than it is wide. Where a real car has a wheel arch, blank it, vent it, or put a lift jet in it.
2. **Engines, stabilisers and boost are real modules on every vehicle.** Round 1 relabelled the engine slots as body sections. That is undone. `Engine1`, `Engine2`, `Stabilisers` and `Boost` are jet hardware in every class, visible from outside, wherever suits the class. Body sections get their own slots (`FrontBody`, `RearBody`).
3. **Swaps must fit well, look great and look different.** Every cockpit has its own signature kit. Any cockpit wearing any other cockpit's kit must sit cleanly with no holes, floating parts or awkward steps. Two options for the same slot must be easy to tell apart at a glance, and so must two cockpits.
4. **Three new classes of realistic cars as hover jets:** Muscle, Exotic and GT. Likeness to real cars is fine. Use real-world proportions.
5. **Refine everything from round 1** under the same rules.

## 1. How the live system works today (verified in Studio, 2026-10-01)

- One category exists: folder `PIERCER`, `CategoryId = bruiser`, six cockpits (about 8 W x 6 H x 17 L studs; a full Piercer with kit is 20.5 x 7.6 x 29.2).
- Every cockpit has eight slots: `Engine1` (front engine), `Engine2` (rear engine), `Stabilisers`, `Boost`, `FrontBumper`, `RearBumper`, `RearSpoiler`, `SidePods`. Engines, stabilisers and boost carry the performance. Each cockpit has its own Standard, Lightweight and Power engine, stabiliser and boost modules.
- Every slot mount sits at the cockpit root origin. A module is authored in cockpit-root space, so it fits every cockpit in its category only if the cockpits share the same hardpoints.
- Parts carry a paint channel: Primary, Secondary, Detail, Glass, Neon, plus thrust colour. The player's paint recolours cockpit and modules together.

## 2. The frame standard: why parts always fit

A category is a **frame class**. Each class publishes one **frame standard** in cockpit-root space.

1. **Cockpit envelope.** A box (or union of boxes) every cockpit stays inside.
2. **Slot envelopes.** One box (or union) per slot. Envelopes never overlap each other or the cockpit envelope, so nothing can clip.
3. **Seams.** Each slot names the face (or faces) where it meets its parent, which is the cockpit or another slot. Every parent must reach the seam; every module must reach it too.
4. **Contact.** Every module must come within 0.6 studs of every possible parent (every cockpit, or every module of the parent slot). The validator checks all pairs. Over 1.0 is an error.
5. **Hardpoint pads.** Envelopes stop clipping but not floating. Each parent carries fixed flat pads at set positions, and modules land on pads, never on a body shape. Every cockpit in a class ships the same chassis and pads under a different cabin. Character goes in the glass, nose and tail faces.
6. **Shadow gap and linkage.** A 0.2 to 0.6 stud gap bridged by dark `detail` linkage is the house look. It hides the join between unlike parts.
7. **Datums.** Each class fixes a beltline, a sill height and the hover plane, so body lines run straight across the gaps.
8. **Paint unifies.** Every part declares a paint channel, so a mixed build still reads as one vehicle.
9. **One surface, one owner.** The cockpit owns all glass and the roofline. Each arch, nose, fin and pod belongs to exactly one slot.
10. **Signature kits.** Each cockpit has a signature kit: one module for every slot, designed with that cockpit. Kits carry a culture tag. Inside a class every kit fits every cockpit.
11. **Distinctness.** Two modules for the same slot differ in silhouette, not only in detail: different length, height, count (one, two, four), stance or outline. Two cockpits differ in roofline and glass. The validator scores this from side, top and front outlines (0 = identical, 1 = nothing shared). Targets: 0.35 or more for engines, stabilisers, boost, front body, rear body, mid section and spoiler; 0.25 or more for the rest and for cockpits.

Root space: +X right, +Y up, **forward is -Z**. Units are studs. A Roblox avatar is about 5 studs tall and 2 wide. Whole-vehicle limit for every class: X -12..12, Y -2.5..10, Z -19..19.

## 3. Slots

| Slot ID | Kind | Meaning in every class |
|---|---|---|
| `Engine1` | Fundamental | A jet engine module. Visible intake and nozzle. May be a mirrored pair. |
| `Engine2` | Fundamental | A second jet engine module, somewhere else on the vehicle. |
| `Stabilisers` | Fundamental | Hover stabiliser hardware: lift jets, vectoring nozzles, vanes with jet tips. Usually four corners or a pair. |
| `Boost` | Fundamental | The boost unit: afterburner cans, a slot burner, staged stacks. |
| `FrontBody` | Body (new) | The front body section: front half, front clip, prow. |
| `RearBody` | Body (new) | The rear body section: rear half, rear clip, deck, bed. |
| `SidePods` | Body | The middle section or flanks. |
| `FrontBumper` | Body | Front bumper, lip, splitter, nose tip. |
| `RearBumper` | Body | Rear bumper, diffuser. |
| `RearSpoiler` | Body | Spoiler, wing, fins. |
| `Hood`, `Roof`, `Accessory` | Cosmetic | Optional. Trim on top of the body or cockpit. |

The eight IDs the game already has (`Engine1`, `Engine2`, `Stabilisers`, `Boost`, `FrontBumper`, `RearBumper`, `RearSpoiler`, `SidePods`) are required in every class. `FrontBody`, `RearBody`, `Hood`, `Roof` and `Accessory` are optional per class. Each class chooses its own player labels and decides where each slot sits.

Rules for the fundamentals:

- Every build has all four. A kit without one is an error.
- Each fundamental module includes at least one `thrust` part (the glowing jet). It must be visible from outside: do not bury an engine inside bodywork. Show an intake, a body and a nozzle.
- At least four options per fundamental slot, one per signature kit, each clearly different: for example a single big turbine, a twin pair, a cluster of four small jets, a flat slot burner.
- Engines and boost should read from the chase camera (rear three-quarter). Stabilisers should read from the front three-quarter and from above.

## 4. The frame classes

Twelve classes plus the existing Piercer. `id` is the proposed stable `CategoryId`. Module names are yours to choose; keep cockpit names unless you have a good reason. Sizes are targets.

### Refined from round 1

**rift: Rift.** Classic coupé bodies sliced into floating sections (Oscar's first reference images). Cultures: Muscle, Pony, Pro Street, Euro GT, Wedge Exotic, Roadster. Two-door cabin; `FrontBody` is two long forward nacelles either side of a centre nose; `RearBody` is rear-quarter pods plus tail; `SidePods` is the mid section. About 17 W x 7 H x 34 L. Fundamentals: front engines slung under or inside the mouths of the nacelles, rear engines in the rear-quarter pods, stabiliser jets under the cabin and at the nacelle tips, afterburner in the centre tail. Cockpits: Brawler (70s fastback), Outlaw (60s notchback), Stiletto (70s wedge), Regent (grand tourer), Mamba (roadster), Nightshift (80s T-top).

**street: Street.** Tuner and import cars with clip-on aero. Cultures: Drift, Time Attack, Underground, Touge, Rally, Kanjo. One compact body: `FrontBody` front clip, `RearBody` rear clip, `SidePods` side kit. About 11 W x 6 H x 21 L. Round 1 used flat rotor discs in the arches: remove them. Arches are blanked or vented, with a vectoring lift nozzle in each. Engines: one showing through the bonnet or front grille, one in the tail with nozzles through the rear panel. Boost: exhaust afterburner. Cockpits: Touge (90s coupé), Pocket (hot hatch), Syndicate (sports saloon), Kei (tiny sports car), Wedgeback (80s liftback), Estate (wagon).

**rodder: Rodder.** Hot rods and drag rails. Cultures: Highboy, Rat Rod, T-Bucket, Gasser, Slingshot Drag, Salt Flat. Narrow cab at the back, exposed engine ahead on two frame rails behind a grille shell. About 13 W x 7 H x 30 L. Round 1 had fat rear drums and upright front discs: replace them. `Engine1` is the exposed front engine (keep the hot-rod look: blower, stacks, headers, as jet hardware). `Engine2` is a pair of long jet barrels beside the cab where the slicks were. `Stabilisers` are slim lift-jet pods on the front beam axle. `Boost` is the headers. Cockpits: Deuce, Bucket, Rat Cab, Slingshot, Lakester, Altered.

**rider: Rider.** Hoverbikes; the rider is always visible. Cultures: Supersport, Café Racer, Chopper, Motocross, Streetfighter, Speeder. About 6 W x 6 H x 14 L. Round 1 had hover rings where the wheels were: replace them. `Engine1` is the main turbine under the tank between the rider's legs. `Engine2` is a rear thruster on the swingarm (a long nozzle, not a ring). `Stabilisers` are a front lift-jet pod held by the fork plus small side jets. `Boost` is the exhaust. Body: fairing (`FrontBumper`), body panels (`SidePods`), seat unit (`RearSpoiler`), tail kit (`RearBumper`), tank (`Hood`), screen (`Roof`), bars (`Accessory`). Cockpits: Supersport, Café, Chopper, Scrambler, Streetfighter, Speeder.

**apex: Apex.** Circuit racers. Cultures: Formula, Vintage Grand Prix, Prototype, Wing Car, Speedway Sprint. Central tub, wings, sidepods. About 15 W x 5.5 H x 28 L. Round 1's outboard pods read as wheels: replace them. `Stabilisers` are four slender thruster pods on wishbones (long nacelles, nozzle down and back), open or faired under prototype arches. `Engine1` is the power unit behind the driver. `Engine2` is a second engine of your choice (sidepod jets, a nose lift engine). `Boost` is the exhaust. Cockpits: Formula, Cigar, Prototype, Wingcar, Sprint, Oval.

**cruiser: Cruiser.** Long, low land yachts. Cultures: Lowrider, Lead Sled, Fin Era, VIP, Kaido Racer. About 11 W x 6 H x 34 L. Round 1 had rotor discs under skirts: remove them. Jet-age styling suits this class: turbines in the tail fins or boot, bullet nozzles, long side vents. `Stabilisers` are vane cascades and lift jets along the sills and in the blanked arches. Cockpits: Hardtop, Sled, Finliner, VIP, Kaido, Longroof.

**hauler: Hauler.** Trucks and vans. Cultures: Prerunner, Lifted, Minitruck, Show Truck, Courier, Cab. Tall cab, `FrontBody` front clip, `RearBody` bed or box. About 13 W x 9 H x 30 L. Round 1 had disc pods at the corners: replace them with jet pods on arms (nozzle down, longer than wide). One engine can live in the bed. Cockpits: Single Cab, Crew Cab, Kei Cab, Cab-Over, Van Nose, Checker Cab.

**dart: Dart.** Anti-grav racing darts. Cultures: Works Team, Privateer, Prototype, Salvage. Slender fuselage, `FrontBody` prow of one to three prongs, `SidePods` wings. Keep it inside 34 L x 16 W (round 1 overran). `Engine1` main drive at the tail, `Engine2` prow or wing-root engines, `Stabilisers` airbrakes with control jets, `Boost` afterburner. Cockpits: Needle, Delta, Manta, Twinboom, Bubble, Arrowhead.

**tether: Tether.** Pod racers: a small pod towed by two huge engines. Cultures: Scrapyard, Works, Desert, Showboat. About 18 W x 7 H x 36 L. `Engine1` the tow engines (a mirrored pair is one module), `Engine2` the pod thruster, `Stabilisers` engine vanes, `Boost` afterburners, `SidePods` binder and cables. Already jet-led; refine fit and make the engine options more different. Cockpits: Bucket, Sled, Capsule, Chariot, Skiff, Bubble.

### New in round 2: realistic cars as hover jets

These three should look like real cars first. Use real proportions: bonnet length, cabin position, overhangs, roofline, glass. Then remove the wheels and add jet hardware. A viewer should name the kind of car at a glance.

**muscle: Muscle.** American muscle and pony cars, one-piece bodies (Rift is the split version). Cultures: Classic Muscle (late 60s), Pony, Modern Muscle, Pro Street, Restomod, Trans-Am racer. Long bonnet, short deck, wide haunches. About 10 W x 6 H x 24 L. `FrontBody` nose clip (grille, lamps, bonnet shape), `RearBody` tail and haunches, `SidePods` rockers and side pipes. Suggested fundamentals: an engine bursting through the bonnet (the blower becomes a turbine intake), a second engine pair in the tail, corner lift jets in blanked arches, side-pipe or bumper afterburners. Cockpits: Fastback (late-60s fastback), Hardtop (Coke-bottle coupé), Notch (60s pony notchback), Modern (retro-modern coupé), Ragtop (convertible), Ute (coupé utility).

**exotic: Exotic.** Mid-engined supercars and hypercars. Cultures: Wedge (70s and 80s poster cars), Analogue (90s curves), Hypercar (modern), Track Special, Longtail. Low, wide, cab-forward, engine behind the cabin. About 11 W x 5 H x 23 L. `FrontBody` nose, `RearBody` engine deck and tail, `SidePods` side intakes. Suggested fundamentals: the main turbine under a glass engine cover behind the cabin, side-intake engines, corner vectoring nozzles and active aero fins, a high central afterburner cluster. Cockpits: Wedge (scissor-door wedge), Curve (90s teardrop), Hyper (modern canopy), Spider (open top), Longtail (endurance tail), Gull (gullwing).

**gt: GT.** Front-engined sports cars and grand tourers, plus the rear-engined sports coupé. Cultures: Classic GT (60s long bonnet), Rear-Engine Sports, Modern GT, GT3 racer, Roadster, Shooting Brake. About 10 W x 5.5 H x 23 L. `FrontBody` long bonnet and nose, `RearBody` tail, `SidePods` sills and side vents. Suggested fundamentals: a front engine breathing through the grille with side-exit vents behind the front arches, a rear engine under the tail, corner lift jets, twin or quad afterburners where the exhausts were. Cockpits: Longnose (60s GT), Teardrop (rear-engined coupé), Bruiser (modern muscular GT), Roadster, Brake (shooting brake), Gullwing.

## 5. Blockout spec format (v2)

One JSON file per class at `scripts/vehicle_blockouts/specs/<id>.json`. The schema is enforced by `vbspec.py`; read `validate()` for the exact rules.

```json
{
  "id": "gt", "displayName": "GT", "tagline": "...",
  "standard": {
    "cockpitEnvelope": {"min": [-4, 0, -5], "max": [4, 5.5, 5]},
    "datums": {"beltline": 2.8, "sill": 0.2, "hoverPlane": -2.0},
    "slots": {
      "FrontBody": {"label": "Front Clip", "envelope": {"min": [-5, 0, -12], "max": [5, 3, -5]},
                    "anchor": {"to": "cockpit", "face": "+z"}, "explode": [0, 0, -6]},
      "Engine1": {"label": "Front Engine", "envelope": {"min": [-2, 3, -11], "max": [2, 4.6, -6]},
                  "anchor": {"to": "FrontBody", "face": "-y"}, "explode": [0, 5, -6]},
      "Stabilisers": {"label": "Stabilisers", "envelope": [{"min": [3, -1.6, -10], "max": [5.6, 0, -6], "mirror": true},
                                                           {"min": [3, -1.6, 6], "max": [5.6, 0, 10], "mirror": true}],
                      "anchor": [{"to": "FrontBody", "face": "+y"}, {"to": "RearBody", "face": "+y"}], "explode": [3, -5, 0]}
    }
  },
  "cockpits": {"longnose": {"name": "Longnose", "culture": "Classic GT", "kit": "classic", "parts": []}},
  "kits": {"classic": {"name": "Classic", "culture": "Classic GT",
                       "modules": {"Engine1": "inline_six", "Engine2": "tail_twin", "Stabilisers": "corner_jets", "Boost": "twin_cans", "FrontBody": "long_nose"}}},
  "modules": {"Engine1": {"inline_six": {"name": "Inline Stack", "culture": "Classic GT", "parts": []}}},
  "builds": [
    {"name": "Longnose, own kit", "cockpit": "longnose", "kit": "classic", "paint": {"primary": "#0b6b3a", "secondary": "#e8e2d0", "neon": "#fff2c0"}},
    {"name": "Longnose, GT3 kit", "cockpit": "longnose", "kit": "gt3", "paint": {"primary": "#0b6b3a", "secondary": "#e8e2d0", "neon": "#fff2c0"}},
    {"name": "Mixed", "cockpit": "longnose", "kit": "classic", "modules": {"RearSpoiler": "gt3_wing", "Boost": "quad_cans"}, "paint": {"primary": "#222", "secondary": "#d22", "neon": "#f55"}}
  ]
}
```

- `anchor` is `{to, face}` or a list of them. `face` is the face of this slot's own envelope that touches the parent: `-x +x -y +y -z +z`. For a mirrored envelope give the face for the +X box.
- `explode` is the exploded-view offset. For mirrored parts the X offset flips on the mirrored copy.
- A cockpit's `kit` is its signature kit. Every cockpit has its own.
- A build is `native` (cockpit with its own kit), `swap` (cockpit with another cockpit's kit) or `mixed` (has `modules` overrides).
- Part: `{shape, size:[x,y,z], pos:[x,y,z], rot?:[rx,ry,rz], ch?, mirror?, note?}`.
  - `shape`: `block`, `wedge`, `cyl_x`, `cyl_y`, `cyl_z`, `ball`. Cylinder size is its bounding box: `cyl_z` with size `[2,2,6]` is a 2-stud tube 6 long along Z.
  - `wedge`: full base, thin edge toward -Z (front), tall face at +Z (back). Use `rot: [0,180,0]` for a tail slope and `rot: [180,0,0]` to flip it under the body.
  - `rot` is Roblox Orientation in degrees. `ch`: `primary`, `secondary`, `detail`, `glass`, `neon`, `thrust`, `driver`. `mirror: true` adds the reflection across X.

Required (errors): at least 4 cockpits, each with its own signature kit; at least 3 modules in each of `Engine1`, `Engine2`, `Stabilisers`, `Boost` (4 is the target) and 2 in the other canonical slots; every kit and every build has all four fundamentals; every fundamental module has a `thrust` part; every cockpit has a native build and a swap build; all parts inside their envelopes; envelopes disjoint; no module more than 1.0 studs from any possible parent. Warnings to clear or explain: contact over 0.6, unreached seams, look-alike modules or cockpits, disc-like cylinders, over 220 parts in a build.

Tools (run from the repo root):

```
py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/<id>.json            validate and render everything
py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/<id>.json --check    validate only
py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/<id>.json --only matrix,fundamentals
```

Previews land in `scripts/vehicle_blockouts/previews/<id>/`: `matrix.png` (every cockpit in every kit: the interchange proof), `fundamentals.png` (each engine, stabiliser and boost option highlighted on one cockpit), `sheet.png`, `exploded.png`, `standard.png` and four views per build. The renderer has true occlusion, so what you see is what the model is.

Keep your spec reproducible: write it from a generator script at `scripts/vehicle_blockouts/gen/<id>.py` (plain Python that writes the JSON). Use only your own files; the session scratchpad is shared with other agents.

## 6. Concept image format (round 2)

Images go to `output/vehicle-categories-2026-10-01/<id>/NN-name.png` with a 1000 px JPEG copy in `docs/design/vehicle-categories/img/<id>/NN-name.jpg`. Round 1 images for existing classes move to `output/vehicle-categories-2026-10-01/<id>/v1/` and their JPEGs are deleted from `img/<id>/`.

```
py -3 scripts/vehicle_blockouts/gen_image.py output/vehicle-categories-2026-10-01/<id>/01-hero.png <prompt.txt> --jpg docs/design/vehicle-categories/img/<id>/01-hero.jpg
```

Save every prompt in `output/vehicle-categories-2026-10-01/<id>/prompts/NN-name.txt` and in `prompts.json` (`[{file, prompt}]`). One image takes one to two minutes. Run them one at a time.

Eight images per class:

1. `01-hero`: the class's most iconic build, three-quarter front.
2. `02-exploded`: exploded view. Cockpit in the middle, every module pulled away along its own axis. The engines, stabilisers and boost unit must be clearly separate pieces of jet hardware.
3. `03-one-kit-three-cockpits`: three different cockpits side by side wearing the same kit and paint.
4. `04-one-cockpit-three-kits`: one cockpit shown three times with three clearly different kits.
5. `05-engines`: one cockpit shown three times, rear three-quarter, identical except for three different engine modules.
6. `06-stabilisers-boost`: low rear three-quarter with the boost firing and the stabiliser jets working.
7. `07-<culture>`: another culture line or a mixed build.
8. `08-action`: the hero build at speed in a neon-lit futuristic city at night.

Style block for every prompt (adapt the wording, keep the constraints):

> High-quality 3D concept render of a hover vehicle for a futuristic street-racing game. The vehicle has no wheels, no tyres, no rims and no wheel-shaped or ring-shaped parts of any kind. It floats about half a metre above the floor on jet thrust: turbine engines with visible intakes and nozzles, downward lift jets, vectoring nozzles and an afterburner, with blue-white thrust glow. Where a car would have wheel arches they are blanked off or hold a lift-jet nozzle. Clean, readable shapes that would work as a low-poly game model. The body is built from separate bolt-on modules with thin dark shadow gaps and dark mechanical linkages between them. Glossy automotive paint with one main colour and one accent colour. Plain light-grey seamless studio background, soft shadow on the floor beneath the floating vehicle. No logos, badges, numbers, licence plates or readable text.

Real-car likeness is welcome: describe the real body style closely (era, country, body type, proportions), and you may name a real model as the body-style reference. Keep logos, badges and text off.

Look at every image. Regenerate (up to twice) if it shows wheels, tyres, rings, discs or rotors; readable text or badges; or no visible jet hardware.

## 7. Who writes what

| Agent | May write only |
|---|---|
| Blockout agents for `<id>` (build, fix) | `scripts/vehicle_blockouts/specs/<id>.json`, `scripts/vehicle_blockouts/gen/<id>.py`, `scripts/vehicle_blockouts/previews/<id>/`, `docs/design/vehicle-categories/<id>-frame.md` |
| Blockout critics for `<id>` | nothing (read-only; may run `preview.py --check`) |
| Concept agents for `<id>` | `output/vehicle-categories-2026-10-01/<id>/`, `docs/design/vehicle-categories/img/<id>/`, `docs/design/vehicle-categories/<id>.md` |

Agents do not touch Roblox Studio, Blender, git, the shared tools, the session scratchpad or any other file. Report tool problems in the final message.
