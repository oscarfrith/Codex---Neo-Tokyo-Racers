# Vehicle frame classes: exploration contract

Status: design exploration, 2026-10-01. Nothing here is game content or approved. The design contract this feeds is [docs/design/vehicle-frame-classes.md](../../docs/design/vehicle-frame-classes.md).

This file is the shared brief for the parallel agents. The integrator (main session) owns Studio, git and every file not listed under "Who writes what".

## 1. How the live system works today (verified in Studio, 2026-10-01)

- One category exists: folder `PIERCER`, `CategoryId = bruiser`, six cockpits (`bruiser_01`..`06`, about 8 W x 6 H x 17 L studs).
- A category holds `COCKPITS_ReplaceAssetsHere`, `MODULES_InterchangeableWithinCategory` and `UPGRADES_InvisiblePerformance`.
- Every cockpit has the same eight slots: `Engine1` (front engine), `Engine2` (rear engine), `Stabilisers`, `Boost`, `FrontBumper`, `RearBumper`, `RearSpoiler`, `SidePods`.
- Every slot mount sits at the cockpit root origin. A module is authored in cockpit-root space, so a module fits every cockpit in its category only because all cockpits in that category share the same body-kit geometry.
- Parts carry a paint channel: Primary, Secondary, Detail, Glass, Neon (plus Underglow and thrust colour). The player's paint recolours the whole car, cockpit and modules together.
- Engines, stabilisers and boost carry most of the performance stats. Bumpers, spoiler and side pods carry small ones.

## 2. The rule that makes a category seamless: the frame standard

A category is a **frame class**. Each frame class publishes one **frame standard** in cockpit-root space:

1. **Cockpit envelope.** A box (or union of boxes) every cockpit in the class must stay inside.
2. **Slot envelopes.** One box (or union) per slot. Every module for that slot must stay inside it. Envelopes never overlap each other or the cockpit envelope, so any cockpit with any set of modules cannot clip. This holds by construction, with no per-pair checking.
3. **Seams.** Each slot envelope names the face where it meets its parent (the cockpit or another slot). Every cockpit must reach every cockpit seam, and every module must reach its own seam and the seams of the slots that hang off it. This is what stops holes and floating parts. "Reach" means within 1 stud.
4. **Shadow gap and linkage.** Parts do not need to share surfaces. A gap of 0.2 to 0.8 studs with a dark `detail` linkage across it is the house look (see Oscar's split-body references). The gap is what lets a muscle nose sit next to a wedge cabin without a mismatched join.
5. **Datums.** Each class fixes a beltline height, a sill height and the hover plane. Modules line their main crease up with the beltline so stripes and body lines flow across the gaps.
6. **Paint unifies.** Every part declares a paint channel. Mixed-culture builds still look like one car because the paint is shared.
7. **Same eight performance slots.** Every class keeps the eight canonical slot IDs so the performance, upgrade and save systems are unchanged. Each class relabels them (for example `Engine1` is "Front Half" on Rift and "Front End" on Rider). A class may add up to three cosmetic slots from this fixed list: `Hood`, `Roof`, `Accessory` (also relabelled per class).
8. **Culture tags.** Cockpits and modules carry a culture tag (Drift, Drag, Muscle and so on). Tags drive shop filters and "full kit" names. They never restrict fitting: inside a class everything fits everything.

9. **Hardpoint pads (added after the blockouts).** Envelopes stop clipping but not floating. Each parent carries fixed flat pads at set positions and modules land on pads, never on a body shape. Every cockpit in a class ships the same chassis under a different cabin. The validator does not check pads yet.

Root space: +X right, +Y up, **forward is -Z**. Units are studs. A Roblox avatar is about 5 studs tall and 2 wide. Whole-vehicle limit for every class: X -12..12, Y -2.5..10, Z -19..19.

## 3. The frame classes

Working names. `id` is the proposed stable `CategoryId`. Slot labels are what the player sees. No real manufacturer or model names anywhere: use eras, genres and original names.

### rift: Rift
- Pitch: classic coupé bodies sliced into floating sections. This is Oscar's first four reference images.
- Cultures: Muscle, Pony, Pro Street (drag muscle), Euro GT, Wedge Exotic, Roadster.
- Layout: a two-door cabin in the middle. The front half is two long nacelles (the old front wings with the headlights) either side of an optional centre nose. The rear half is rear-quarter pods plus a tail. The mid section runs along the cabin flanks. Overall about 17 W x 7 H x 34 L.
- Cockpits: Brawler (70s fastback), Outlaw (60s notchback), Stiletto (70s wedge exotic), Regent (grand tourer), Mamba (open roadster), Nightshift (80s T-top).
- Slots: Engine1 Front Half; Engine2 Rear Half; SidePods Mid Section; Stabilisers Hover Fins; Boost Afterburner; FrontBumper Front Bumper; RearBumper Rear Bumper; RearSpoiler Spoiler; Hood Hood; Roof Roof.
- Modules: Front Half: Twin Longhorn, Shark Nose, Pop-Up Prongs, Grand Quad, Blower Rail. Rear Half: Fastback Quarters, Kammback, Turbine Quarters, Boat Tail. Mid Section: Side Pipes, Door Pods, Intake Scoops, Rocker Blades. Hover Fins: Keel Blades, Vane Plate, Outrigger Skids. Afterburner: Quad Cannon, Slot Burner, Twin Stack. Front Bumper: Chin Bar, Splitter, Chrome Blade, Ram Bar. Rear Bumper: Chrome Bar, Diffuser, Light Bar. Spoiler: Ducktail, Pedestal Wing, GT Wing, Louvre Deck. Hood: Shaker, Cowl Induction, Heat Vents, Blower. Roof: Vinyl Top, Louvres, Roof Scoop, T-Top.
- Feel: heavy hitters. Top speed and boost, wide stance, long drifts.

### street: Street
- Pitch: tuner bodies with clip-on aero and hover rotors where the wheels were.
- Cultures: Drift, Time Attack, Underground (neon street racing), Touge, Rally, Kanjo.
- Layout: one compact body silhouette. Front clip and rear clip bolt to the cabin. Four round hover rotors sit flat-ish in the wheel arches (they are the "rims"). About 11 W x 6 H x 21 L.
- Cockpits: Touge (90s coupé), Pocket (hot hatch), Syndicate (four-door sports saloon), Kei (tiny sports car), Wedgeback (80s liftback with pop-up lamps), Longroof (wagon).
- Slots: Engine1 Front Clip; Engine2 Rear Clip; Stabilisers Hover Rotors; SidePods Side Kit; Boost Exhaust; FrontBumper Front Lip; RearBumper Diffuser; RearSpoiler Wing; Hood Hood; Roof Roof; Accessory Extras.
- Modules: Front Clip: Stock, Widebody, Pop-Up, Shark, Rally (light pods). Rear Clip: Stock, Widebody, Hatch Bustle, Time-Attack Tail. Hover Rotors: Five-Spoke, Deep Dish, Turbofan, Mesh, Stance (cambered). Side Kit: Skirts, Bolt-on Overfenders, Side Splitters, Rally Flaps. Exhaust: Cannon, Twin Tip, Bamboo Stacks, Screamer. Front Lip: Lip, Splitter and Canards, Intercooler Bumper, Missile (zip-tied). Diffuser: Street, Finned, Bash Bar. Wing: Ducktail, GT Wing, Swan Neck, Roof Spoiler. Hood: Vented, Carbon Bulge, Cut-out. Roof: Roof Scoop, Rack, Light Pod Bar. Extras: Mirrors, Tow Strap, Antenna.
- Feel: drift and agility. Light, sharp steering, strong drift control.

### rodder: Rodder
- Pitch: chopped cabs, exposed engines and fat rear drums. Hot rods and drag rails in one class.
- Cultures: Highboy, Rat Rod, T-Bucket, Gasser, Slingshot Drag, Salt Flat.
- Layout: a narrow cab at the back. An exposed engine block sits ahead of it on two frame rails with a grille shell. Skinny front hover pods on a beam axle far forward; fat rear hover drums beside the cab. About 13 W x 7 H x 30 L.
- Cockpits: Deuce (chopped three-window coupé), Bucket (open tub), Rat Cab (pickup cab), Slingshot (rail cage, driver far back), Lakester (belly-tank teardrop), Altered (tiny upright coupé).
- Slots: Engine1 Engine Block; Engine2 Rear Drums; Stabilisers Front Axle; SidePods Fenders and Rails; Boost Headers; FrontBumper Grille Guard; RearBumper Launch Gear; RearSpoiler Rear Rig; Hood Hood; Roof Roof.
- Modules: Engine Block: Blown Eight, Flathead Trio, Twin Mill, Radial Nine, Turbine Swap. Rear Drums: Slick Drums, Dually Drums, Finned Drums. Front Axle: Skinny Pods, Suicide Front, Faired Spats. Fenders and Rails: Cycle Fenders, Running Boards, Open Rails. Headers: Zoomies, Lake Pipes, Side Dumps. Grille Guard: Nerf Bar, Moon Tank, Push Bar. Launch Gear: Wheelie Bars, Chute Pack, Nerf Rear. Rear Rig: Dragster Wing, Roll Hoop, Luggage Rack. Hood: Louvred Top, Side Panels, Scoop. Roof: Chopped Steel, Canvas, Roll Cage.
- Feel: launch monsters. Huge acceleration and boost, nose lifts under boost, weak sideways grip.

### rider: Rider
- Pitch: hoverbikes. The rider sits astride and is always visible.
- Cultures: Supersport, Café Racer, Chopper, Motocross, Streetfighter, Speeder.
- Layout: a slim spine with seat. Front end ahead (fork plus a hover ring or blade), rear end behind (swingarm plus hover ring or thruster). About 6 W x 6 H x 14 L. Draw the rider with `driver` parts in every cockpit.
- Cockpits: Supersport (crouched), Café (flat seat), Chopper (low, feet forward), Scrambler (tall), Streetfighter (naked, upright), Speeder (sci-fi sled).
- Slots: Engine1 Front End; Engine2 Rear End; Stabilisers Winglets; SidePods Body Panels; Boost Exhaust; FrontBumper Fairing; RearBumper Tail Kit; RearSpoiler Seat Unit; Hood Tank; Roof Screen; Accessory Bars.
- Modules: Front End: Sport Fork, Chopper Rake, Girder Fork, Hubless Ring, Speeder Vane. Rear End: Sport Swingarm, Fat Drum, Hardtail, Twin Thruster. Winglets: Aero Winglets, Outrigger Skids, Crash Sliders. Body Panels: Full Fairing, Tank Shrouds, Saddlebags, Number Boards. Exhaust: Under-tail, Shotgun Pipes, Megaphone, Stubby. Fairing: Race Nose, Bikini Fairing, Round Lamp, Number Plate, Fighter Mask. Tail Kit: Sissy Bar, Tail Tidy, Luggage Rack. Seat Unit: Race Cowl, Café Hump, Bobber Fender, MX Fender. Tank: Sculpted, Peanut, Teardrop. Screen: Bubble, Flyscreen, Tall Tourer. Bars: Clip-ons, Apes, MX Bars, Drag Bars.
- Feel: smallest and sharpest. Fits gaps cars cannot, wheelies on boost, pushed around in contact.

### apex: Apex
- Pitch: circuit racers. A central tub, outboard hover pods and serious aero.
- Cultures: Formula, Vintage Grand Prix, Prototype (endurance), Wing Car (80s), Speedway Sprint.
- Layout: a narrow tub on the centreline. Four hover pods stand off the body on wishbones, open or enclosed in fenders. Wings front and rear. About 15 W x 5.5 H x 28 L.
- Cockpits: Formula (open with halo), Cigar (60s tube), Prototype (closed bubble canopy), Wingcar (80s wedge tub), Sprint (upright cage), Oval (low speedway tub).
- Slots: Engine1 Front Pods; Engine2 Power Unit; Stabilisers Floor; SidePods Sidepods; Boost Exhaust; FrontBumper Nose and Wing; RearBumper Diffuser; RearSpoiler Rear Wing; Hood Airbox; Roof Halo or Canopy.
- Modules: Front Pods: Open Rings, Faired Pods, Prototype Arches, Vintage Wires. Power Unit: V-Cover, Turbo Stack, Prototype Tail, Sprint Rear. Floor: Flat Floor, Venturi Tunnels, Bargeboards. Sidepods: Coke Bottle, Zero Pod, Radiator Boxes, Skirted. Exhaust: Single Exit, Twin Megaphone, Blown Diffuser. Nose and Wing: Needle Nose, High Nose, Snowplough, Radiator Nose. Diffuser: Shallow, Deep Tunnel. Rear Wing: Low Drag, High Downforce, Twin Plane, Sprint Top Wing. Airbox: Tall, Split, Roll Hoop. Halo or Canopy: Halo, Aeroscreen, Bubble Canopy.
- Feel: grip and braking. Highest downforce, least drift, fragile in traffic.

### cruiser: Cruiser
- Pitch: long, low land yachts. Lowriders, lead sleds, fin-era chrome and VIP saloons.
- Cultures: Lowrider, Lead Sled, Fin Era, VIP, Kaido Racer.
- Layout: a long cabin, long front clip, long rear deck. Four hover rotors under skirts. Overall about 11 W x 6 H x 34 L, noticeably longer and lower than Street.
- Cockpits: Hardtop (60s pillarless), Sled (chopped late-40s), Finliner (late-50s bubble top), VIP (boxy 90s saloon), Kaido (70s coupé), Longroof (wagon).
- Slots: Engine1 Front Clip; Engine2 Rear Deck; Stabilisers Hover Rotors; SidePods Flanks; Boost Pipes; FrontBumper Front Chrome; RearBumper Rear Chrome; RearSpoiler Deck Trim; Hood Hood; Roof Roof; Accessory Extras.
- Modules: Front Clip: Quad Lamp, Frenched, Stacked Lamp, Shark Nose. Rear Deck: Bat Fins, Bullet Tail, Shaved Deck, Boxy Trunk. Hover Rotors: Wire Discs, Whitewall Discs, Deep Dish. Flanks: Fender Skirts, Lake Pipes, Chrome Spears. Pipes: Dual Tips, Bamboo Stacks, Side Exit. Front Chrome: Bullet Bumper, Chin Spoiler, Tube Grille. Rear Chrome: Bumper, Continental Spare, Shaved. Deck Trim: Tall Fins, Kaido Wing, Ducktail, Twin Antennas. Hood: Ornament, Louvres, Oil Cooler. Roof: Chop, Vinyl, Bubble. Extras: Spotlights, Sun Visor.
- Feel: heavy and smooth. Stable, fast in a straight line, slow to turn. Hover hop and tilt as showmanship.

### hauler: Hauler
- Pitch: trucks and vans. Prerunners, minitrucks, chrome-and-lights show trucks and hover-cabs.
- Cultures: Prerunner, Lifted, Minitruck, Show Truck (chrome and lights), Courier, Cab (taxi).
- Layout: a tall cab ahead of a cargo bed. Big hover pods low at the corners. About 13 W x 9 H x 30 L.
- Cockpits: Single Cab, Crew Cab, Kei Cab, Cab-Over, Van Nose, Checker Cab.
- Slots: Engine1 Front Clip; Engine2 Bed; Stabilisers Hover Pods; SidePods Side Gear; Boost Stacks; FrontBumper Front Bar; RearBumper Rear Bar; RearSpoiler Bed Rig; Hood Hood; Roof Roof Rig; Accessory Extras.
- Modules: Front Clip: Square Body, Prerunner Flare, Flat Face, Show Chrome. Bed: Tub Bed, Flatbed, Box Van, Turbine Bed, Camper. Hover Pods: Long Travel, Monster, Slammed, Dually. Side Gear: Steps, Fuel Tanks, Toolboxes. Stacks: Twin Stacks, Bed Burner, Under-bed Dump. Front Bar: Bull Bar, Winch Bumper, Plough, Chrome Bumper. Rear Bar: Hitch, Step, Roll Pan. Bed Rig: Chase Rack, Roll Bar, Ladder Rack. Hood: Scoop, Snorkel. Roof Rig: Light Bar, Rack, Taxi Sign, Visor.
- Feel: heaviest and most stable. Wins contact, slow steering. Natural fit for taxi and parcel jobs.

### dart: Dart
- Pitch: anti-grav darts. One slender fuselage, forward prongs, airbrakes. The pure sci-fi racer from the moodboard.
- Cultures: Works Team, Privateer, Prototype, Salvage.
- Layout: a long thin fuselage with the pilot mid or rear. A prow of one, two or three prongs. Stub wings or pontoons. A drive block at the tail. About 16 W x 5 H x 34 L.
- Cockpits: Needle, Delta, Manta, Twinboom, Bubble, Arrowhead.
- Slots: Engine1 Prow; Engine2 Drive; Stabilisers Airbrakes; SidePods Wings; Boost Afterburner; FrontBumper Nose Tip; RearBumper Tail Cone; RearSpoiler Tail Fins; Hood Spine; Roof Canopy.
- Modules: Prow: Twin Prong, Spear, Trident, Hammerhead. Drive: Mono Drive, Twin Drive, Tri Cluster, Vector Ring. Airbrakes: Clamshell, Petal, Dorsal. Wings: Delta, Forward Swept, Pontoons, Stub Winglets. Afterburner: Ring Burner, Slot Burner. Nose Tip: Pitot Spike, Canards, Ram Scoop. Tail Cone: Skid, Stinger. Tail Fins: Single Fin, Twin Fins, V-Tail. Spine: Dorsal Intake, Cable Run. Canopy: Teardrop, Flat Shield, Open Screen.
- Feel: highest top speed. Turns with airbrakes, punishes mistakes.

### tether: Tether
- Pitch: pod racers. A small pod towed by two huge engines.
- Cultures: Scrapyard, Works, Desert, Showboat.
- Layout: a small pod at the rear. Two large engines far ahead and apart, joined to each other by a glowing binder and to the pod by cables. About 18 W x 7 H x 36 L. Tethers anchor to the pod; engines anchor to the tethers.
- Cockpits: Bucket, Sled, Capsule, Chariot, Skiff, Bubble.
- Slots: Engine1 Tow Engines; Engine2 Pod Thruster; Stabilisers Engine Vanes; SidePods Binder and Cables; Boost Afterburners; FrontBumper Intake Cowls; RearBumper Pod Tail; RearSpoiler Pod Fins; Hood Engine Shrouds; Roof Windshield.
- Modules: Tow Engines: Long Barrels, Fat Turbines, Quad Cluster, Split Scoops. Pod Thruster: Single, Twin, Skid Jet. Engine Vanes: Petal Flaps, Side Vanes, Canard Rings. Binder and Cables: Twin Cable, Rigid Boom, Arc Binder. Afterburners: Ring, Staged. Intake Cowls: Round, Shark Mouth, Mesh. Pod Tail: Skid, Rudder. Pod Fins: Twin, Single Tall. Engine Shrouds: Bare, Armoured. Windshield: Low, Wrap, None.
- Feel: extreme speed, very wide and long. Threading traffic is the skill.

## 4. Blockout spec format

One JSON file per class at `scripts/vehicle_blockouts/specs/<id>.json`. Working example: `specs/_example.json`. The schema is enforced by `vbspec.py` (read `validate()` for the exact rules).

- `standard.cockpitEnvelope`: `{min:[x,y,z], max:[x,y,z]}` or a list of boxes. A box may set `mirror: true` to add its reflection across X.
- `standard.datums`: `{beltline, sill, hoverPlane}`. `hoverPlane` is the ground height below the root, normally -2.
- `standard.slots.<SlotId>`: `{label, envelope, anchor: {to: "cockpit" | "<SlotId>", face}, explode: [x,y,z]}`. `face` is the face of this slot's own envelope that touches its parent: one of `-x +x -y +y -z +z`. For a mirrored envelope give the face for the +X box. `explode` is the offset used in the exploded view.
- `cockpits.<id>`: `{name, culture, parts: [...]}`.
- `modules.<SlotId>.<id>`: `{name, culture, parts: [...]}`.
- `builds`: `[{name, cockpit, paint: {primary, secondary, neon}, modules: {SlotId: moduleId}, note?}]`.
- Part: `{shape, size:[x,y,z], pos:[x,y,z], rot?:[rx,ry,rz], ch?, mirror?, note?}`.
  - `shape`: `block`, `wedge`, `cyl_x`, `cyl_y`, `cyl_z`, `ball`. Cylinder size is its bounding box, so `cyl_z` with size `[2,2,6]` is a 2-stud-diameter tube 6 long pointing along Z.
  - `wedge`: full base, thin edge toward -Z (front), tall face at +Z (back). That is a bonnet or windscreen slope as-is. Use `rot: [0,180,0]` for a tail slope and `rot: [180,0,0]` to flip it under the body.
  - `rot` is Roblox Orientation in degrees.
  - `ch`: `primary`, `secondary`, `detail`, `glass`, `neon`, `thrust`, `driver`.
  - `mirror: true` adds the reflection across X. Author the +X side.

Required: at least 3 cockpits (4 preferred), at least 2 modules in each of the eight canonical slots (3 or more for Engine1, Engine2 and SidePods), at least 6 builds (8 preferred). The builds must include one kit repeated on three different cockpits and one cockpit shown with three different kits. Keep each build under 160 parts.

Check and preview offline:

```
py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/<id>.json
```

It prints errors and warnings and writes `scripts/vehicle_blockouts/previews/<id>/standard.png`, `exploded.png`, `sheet.png` and one four-view image per build. Zero errors is required. Explain any warning you leave.

## 5. Concept image format

Images go to `output/vehicle-categories-2026-10-01/<id>/NN-name.png` with a 1000 px JPEG copy in `docs/design/vehicle-categories/img/<id>/NN-name.jpg`. Generate with:

```
py -3 scripts/vehicle_blockouts/gen_image.py output/vehicle-categories-2026-10-01/<id>/01-hero.png <prompt.txt> --jpg docs/design/vehicle-categories/img/<id>/01-hero.jpg
```

Save every prompt in `output/vehicle-categories-2026-10-01/<id>/prompts.json` (`[{file, prompt}]`). One image takes one to two minutes. Run them one at a time.

Eight images per class:

1. `01-hero`: the class's most iconic build, three-quarter front.
2. `02-exploded`: exploded view. Cockpit in the middle, each module pulled away along its own axis, so the slots read clearly.
3. `03-one-kit-three-cockpits`: three different cockpits side by side wearing the same module kit and paint.
4. `04-one-cockpit-three-kits`: one cockpit shown three times with three different culture kits.
5. `05-<culture>`: a second culture line, three-quarter rear so the boost and spoiler show.
6. `06-<culture>`: a third culture line.
7. `07-<culture>`: a fourth culture line or a deliberately mixed-culture build.
8. `08-action`: the hero build at speed in a neon-lit futuristic city at night.

Shared style block for every prompt (adapt wording, keep the constraints):

> High-quality 3D concept render of an original hover vehicle for a stylised futuristic street-racing game. The vehicle has no wheels and no tyres. It floats about half a metre above the floor on anti-gravity hover units. Clean, readable shapes that would work as a low-poly game model. The body is built from separate bolt-on modules with thin dark shadow gaps and dark mechanical linkages between them. Glossy automotive paint with one main colour and one accent colour. Plain light-grey seamless studio background, soft shadow on the floor beneath the floating vehicle. Original design. No real manufacturer logos, badges, brand names, numbers, licence plates or readable text anywhere.

Look at every image you generate. Regenerate once if it shows wheels on the ground, readable brand text, or does not show the layout described for the class.

## 6. Who writes what

| Agent | May write only |
|---|---|
| Blockout agent for `<id>` | `scripts/vehicle_blockouts/specs/<id>.json`, `scripts/vehicle_blockouts/previews/<id>/`, `docs/design/vehicle-categories/<id>-frame.md` |
| Concept agent for `<id>` | `output/vehicle-categories-2026-10-01/<id>/`, `docs/design/vehicle-categories/img/<id>/`, `docs/design/vehicle-categories/<id>.md` |

Agents do not touch Roblox Studio, Blender, git, or any other file. Agents do not edit the shared tools; report tool problems in the final message instead.
