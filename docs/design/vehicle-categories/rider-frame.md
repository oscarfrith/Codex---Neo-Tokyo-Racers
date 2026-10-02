# Rider frame standard (round 2, after the second review)

Status: design exploration, round 2, 2026-10-02. Primitive blockout only. Nothing here is game content or approved. Spec: [rider.json](../../../scripts/vehicle_blockouts/specs/rider.json), written by [gen/rider.py](../../../scripts/vehicle_blockouts/gen/rider.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/rider/matrix.png), [mix A](../../../scripts/vehicle_blockouts/previews/rider/mix_a.png), [mix B](../../../scripts/vehicle_blockouts/previews/rider/mix_b.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/rider/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/rider/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/rider/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rider/standard.png), and one `row_<cockpit>.png` per cockpit.

Rider is a hoverbike. The rider is always on show. There are no wheels, rings, hoops, discs or drums: every jet is longer than it is wide. The cockpit is a spine, a neck, a rear plate, the seat, its own bodywork and the rider. Everything else bolts to pads. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Anchor |
|---|---|---|---|---|---|
| Cockpit: spine | | ±0.9 | 1.6..2.2 | -3.1..3.3 | root |
| Cockpit: neck | | ±0.9 | 2.2..3.4 | -3.1..-2.6 | |
| Cockpit: seat | | ±0.9 | 2.2..3.4 | 0.15..3.3 | |
| Cockpit: rear plate | | ±0.9 | 0.3..1.6 | 2.6..3.3 | |
| Cockpit: leg channels | | 0.9..1.7, mirrored | 0.4..3.4 (0.4..2.2 ahead of Z -1.2) | -2.2..3.3 | |
| Cockpit: running-board shelf | | 1.7..2.4, mirrored | 0.4..1.3 | -2.2..0.6 | |
| Cockpit: upper body, hump, backrest | | ±2.2 | 3.4..6.6 | -1.6..3.3 | |
| `Engine1` | Main Turbine | A ±0.9; B, C ±1.5 | A 0.3..1.55; B -1.6..0.3; C -1.6..-0.55 | A, B -2.55..2.5; C 2.5..6.0 | spine underside, Y 1.6 |
| `Engine2` | Rear Thruster | ±1.5 | -0.5..1.8 | 3.35..7.4 | rear plate, Z 3.3 |
| `Stabilisers` | Lift Fork | A ±2.4; B, C ±1.6 | A -1.6..1.0; B 1.0..2.0; C 2.0..2.9 | A -7.7..-2.8; B -6.6..-3.15; C -5.0..-3.15 | neck front, Z -3.1 |
| `Boost` | Afterburner | 1.5..2.9, mirrored | A -1.6..0.3; B -1.6..3.2 | A 0.6..3.3; B 3.3..7.5 | exhaust hanger, X 1.45 |
| `FrontBumper` | Fairing | ±1.6 | A 2.9..4.4; B 2.0..2.9; C 1.0..2.0 | A -7.2..-3.3; B -7.3..-5.0; C -7.3..-6.6 | neck front, Z -3.1 |
| `SidePods` | Side Panels | 1.7..2.6, mirrored | 1.3..3.4 | -3.2..3.3 | panel stays, X 1.65 |
| `RearSpoiler` | Seat Unit | ±1.4 | 1.85..4.6 | 3.35..6.8 | seat tail, Z 3.3 |
| `RearBumper` | Tail Kit | ±1.4 | 1.85..5.0 | 6.8..7.7 | Seat Unit tail rail, Z 6.7 |
| `Hood` | Tank | A ±0.9; B 0.9..1.6, mirrored | 2.2..3.4 | A -2.55..0.1; B -2.55..-1.2 | spine top, Y 2.2 |
| `Roof` | Screen | ±1.4 | 4.4..6.0 | -5.0..-3.3 | Fairing screen deck, Y 4.35 |
| `Accessory` | Bars | ±2.3 | 3.4..5.6 | -3.25..-1.65 | neck top, Y 3.3 |

A, B and C are boxes of one envelope. No two envelopes overlap. The envelopes did not change in this round. Built size with the rider: 5.1 to 5.7 wide, 13.9 to 15.0 long, 6.7 to 8.1 high (measured from the lowest jet, Y -1.6).

## Where the four fundamentals sit, and why

The four fundamentals are the bike's stance: swapping one changes the outline, not a detail.
- **Stabilisers = the front end.** The fork holds the lift hardware where a front wheel was. It reads from the front and from above. Options: one boxy lift pod with side jets (Sport Fork), three torpedoes on a straight axle (Torpedo Fork), a 1.6-wide pod with an open intake mouth and canted 0.7 axle jets on a long rake (Long Rake), two upright lift cans, twin pods under a canard (Girder Twin), twin booms with vanes.
- **Engine1 = the main turbine**, under the spine between the rider's legs. Every option ends in a rear-facing glow at least 0.76 across in the exhaust tunnel (box C), between Z 4.9 and Z 5.9, so no boost pipe hides it in the chase view. Options: a body-colour intake 1.4 long and at most 1.25 across with a 0.9 spinner, then one long centre tailpipe (Inline); megaphones to Z 5.8 (Flat Twin); twin tailpipes from two slim cans in a V (V-Twin); one tall canted can with a single stinger to Z 5.5 (Big Single); four lift posts plus a stepped collector nozzle (Four-Poster); a slim plenum 1.1 wide and 1.3 high with side scoops over a 2.2-wide body-colour slab, 0.3 shadow gap between (Slot Burner).
- **Engine2 = the rear end.** A thruster on its own swingarm where the rear wheel was. Its floor is Y -0.5, so the Engine1 exhaust shows underneath. Options: one long barrel 1.5 across (Mono), three barrels (Trident), a tall narrow block with side scoops and a stepped nozzle (Fat Block), two 0.8 barrels stacked 2.3 high with the upper one 1.1 to 1.5 further back and a spine fin between (Over-Under), two 0.9 barrels 2.1 apart under a flat bridge plate (Twin Barrels), a flat fan-tail slot.
- **Boost = the exhaust.** Afterburner pipes on the flanks, beside and behind the rear thruster, so the glow sits next to the engine glow in the chase view.

## Datums and hardpoint pads

| Datum or pad | Owner | Value | Used by |
|---|---|---|---|
| Hover plane, sill, beltline | class | hover Y -2.0 (nothing below Y -1.6); sill Y 0.3 (below it the engine may be wide); beltline Y 2.2 (spine top) | all; Engine1 and Boost headers; Tank and seat |
| Hand datum | class | X ±1.15, Y 4.0, Z -1.3 | every rider's hands, every Bars grip end |
| Seat tail | class | Z 3.3, top at Y 3.4 | every cockpit hump falls to it, every Seat Unit starts at it |
| Exhaust tunnel | class | centre line Y -1.07, Z 2.5..6.0 | Main Turbine tailpipes |
| Fork, fairing and bar pads | cockpit neck | front face Z -3.1 at Y 1.7..2.9 (fork) and Y 2.97..3.27 (fairing); top face Y 3.3 (bars) | Lift Fork yokes, Fairing bracket, Bars clamp |
| Engine and swingarm pads | cockpit spine, rear plate | spine underside Y 1.75, Z -2.6..3.25; plate rear face Z 3.3, Y 0.35..1.75 | Main Turbine top mount; Rear Thruster pivot |
| Exhaust hanger, panel stays | cockpit | hanger X 0.75..1.45, Y 0.45..0.85, Z 2.8..3.25, both sides; stays out to X 1.65 at Y 1.95..2.15, Z -2.0..-1.8 and Z 2.9..3.1 | Afterburner bracket; Side Panels |
| Screen deck | every Fairing | X ±0.7, flat top at Y 4.35, Z -4.8..-3.6 | Screen base sits flush; no screen leaves this footprint |
| Tail rail | every Seat Unit | X ±0.3, Y 1.9..2.15, Z 3.4..6.7 | Tail Kit bracket |

## Cockpits and kits

| Cockpit | Pose | Owned shapes | Kit (culture) | Engine1 | Engine2 | Stabilisers | Boost |
|---|---|---|---|---|---|---|---|
| Supersport | full tuck | twin-spar frame in body colour; angular race hump to Y 4.3 with shoulders; aero winglets with end plates out to X 2.4 | Paddock (Supersport) | Inline Turbine | Mono Thruster | Sport Fork | Twin Cans |
| Café | crouch, seated forward | round dome hump 2.5 across, top at Y 4.7; long flat seat; loop frame in the accent colour | Ton-Up (Café Racer) | Flat Twin | Trident | Torpedo Fork | Reverse Cones |
| Chopper | laid back, feet forward | running boards; king backrest to Y 5.0 with a 3.4-wide top roll to Y 5.6 | Long Haul (Chopper) | V-Twin Jets | Fat Block | Long Rake | Shotgun Pipes |
| Scrambler | standing 0.7 clear of the seat, elbows out | tall flat bench; high side number boards, Y 1.4 to 4.4 | Holeshot (Motocross) | Big Single | Over-Under | Lift Cans | High Megaphone |
| Streetfighter | upright, elbows out | stepped seat; kicked tail 2.6 wide to Y 4.7; solid triangular frame panel in body colour | Bare Knuckle (Streetfighter) | Four-Poster | Twin Barrels | Girder Twin | Quad Stubs |
| Speeder | prone | sled tub walls, flared gunwales, haunch that peaks at Z 1.5 and runs out at the seat tail | Outrider (Speeder) | Slot Burner | Fan Tail | Twin Boom | Slot Blades |

Each cockpit owns large bodywork of its own, so it can be named under any kit. Each kit also has its own Fairing, Screen, Bars, Tank, Side Panels, Seat Unit and Tail Kit: 66 modules in 11 slots. All 36 cockpit and kit pairs are in matrix.png and the row files. mix_a.png and mix_b.png show twelve builds with a random option in every slot. 15 builds: 6 native, 6 swapped, 3 mixed.

## What the second review changed

- Inline Turbine: the black 1.5 x 0.85 intake drum is gone. The intake is body colour, stepped (1.05 then 1.25 across) and 1.4 long, with a 0.9 spinner standing out of the mouth. The Mono Thruster cowl is no longer black either.
- Slot Burner: no longer a plinth. The plenum went from 1.7 x 2.05 to 1.1 x 1.3 and gained side intake scoops. The slab went from 2.9 x 6.7 to 2.2 wide (1.8 at the tail) and 5.4 long, in body colour, on a strut over a 0.3 gap.
- Main Turbine glow: Flat Twin megaphones, the Big Single stinger and the Four-Poster collector now end at Z 5.3 to 5.8 (was 3.4 to 4.2), so Shotgun Pipes and Reverse Cones no longer hide them.
- Cockpits: Scrambler stands taller and its number boards rose from 2 to 3 studs. Streetfighter gained a stepped seat and a kicked tail. Café gained a larger dome and a loop frame. Supersport gained winglets. The Chopper backrest rose 0.3. The floating Streetfighter frame slider is removed.
- MX Fender: a rear number board drops from the fender tip to the rail end, so no tail kit hangs on bare rail. Stub Tail: the boom is at seat height (Y 3.3) to Z 6.7, so tall tail kits back onto bodywork.
- Number Plate fairing: the 2.1-long beak is now a 1.2-long lamp visor over a small lamp. Over-Under is plainly tall and Twin Barrels plainly wide and flat.

## Authoring rules for real meshes

1. Author every mesh in cockpit root space. Keep every surface inside its slot envelope, not only the corners.
2. Land on pads, never on body shapes. End each module with a dark bracket that meets its pad with a 0.1 to 0.5 gap.
3. Do not move a pad. Every cockpit ships the same spine, neck, plate, hanger, stays and seat tail. Character goes in the owned bodywork and the rider's pose.
4. The rider is cockpit geometry. Hands sit on the hand datum in every pose and every Bars grip ends there. No module enters the cockpit envelope, so none can cut the rider.
5. No wheel shapes. Every jet has an intake, a body, a nozzle and a glowing `thrust` face, and is longer than it is wide. No black intake wider than it is long. Lamps are bullets or slits. Large glowing faces are for thrust only.
6. Every Fairing carries the screen deck. Every Seat Unit starts at the seat tail datum and carries the tail rail to Z 6.7. A Seat Unit with a high tail brings bodywork down to the rail end, so a Tail Kit never floats.
7. Above Y 0.3 the Main Turbine is at most 1.8 wide. Its top mount reaches Y 1.5. Its exhaust exits in the tunnel, below Y -0.55, and the glow sits at Z 4.9 or further back. It must leave daylight under the spine: no full-length slab.
8. Options in one slot must differ in outline: count, length, height or stance. Detail alone does not count. Give every part a paint channel: brackets and linkage are `detail`, jet glow is `thrust`.

## Validator

`SPEC rider: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 66, 'builds': 15, 'worst_gap': 0.25, 'min_distinctness': {'Engine1': 0.5, 'Engine2': 0.48, 'Stabilisers': 0.41, 'Boost': 0.56, 'FrontBumper': 0.39, 'RearBumper': 0.41, 'RearSpoiler': 0.49, 'SidePods': 0.46, 'Hood': 0.41, 'Roof': 0.34, 'Accessory': 0.56, 'Cockpit': 0.56}, 'min_distinctness_whole': {'Engine1': 0.36, 'Engine2': 0.34, 'Stabilisers': 0.34, 'Boost': 0.5, 'FrontBumper': 0.24, 'RearBumper': 0.35, 'RearSpoiler': 0.3, 'SidePods': 0.44, 'Hood': 0.27, 'Roof': 0.24, 'Accessory': 0.33, 'Cockpit': 0.24}, 'build_sizes_WHL': {...}}`
The line ends with the size of each build; the range is given above. `min_distinctness` scores the free outline (the area all options share is removed). `min_distinctness_whole` scores the whole outline. Targets are 0.35 for the four fundamentals and the Seat Unit, and 0.25 for the rest and for cockpits. All free scores meet them.

## Open risks

- Whole-outline cockpit scores rose from 0.21 to 0.24 at worst, short of the 0.30 the second review asked for. Six of fifteen pairs are under 0.30: Supersport/Café 0.24, Café/Streetfighter 0.25, Supersport/Speeder 0.27, Chopper/Streetfighter 0.28, Supersport/Streetfighter 0.28, Café/Speeder 0.29. The cockpit envelope is one narrow box, so the rider and shared chassis fill most of the top and front outlines. Reaching 0.30 everywhere needs a wider cockpit envelope or a second leg position, which is a frame-standard change.
- Streetfighter's frame panel still sits low and Side Panels can cover it. Its kicked tail now carries the read under a foreign kit.
- Height is 6.7 to 8.1 against the brief's 6, and length up to 15.0 against 14. A 5-stud rider above a hover gap sets the height. The standing Scrambler is the tallest.
- The Fat Block is still a block by design. It reads as a jet through its scoops and stepped nozzle, not its outline. On the native Chopper the Short Sissy sits behind the cockpit's own king backrest.
- One hand datum means Bars cannot move the hands. True ape hangers need arm IK. Bubble and Canopy are the closest screens (0.34 free, target 0.25). Mono against Over-Under is 0.34 whole (0.52 free).
- The blockout rider is 1.5 wide at the torso and up to 4.2 across the elbows. A real R15 avatar and its astride animation are untested. Passengers, lean angle and ground clearance in a banked turn are untested.
