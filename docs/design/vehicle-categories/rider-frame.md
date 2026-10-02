# Rider frame standard (round 2, after review fixes)

Status: design exploration, round 2, 2026-10-02. Primitive blockout only. Nothing here is game content or approved.
Spec: [rider.json](../../../scripts/vehicle_blockouts/specs/rider.json), written by [gen/rider.py](../../../scripts/vehicle_blockouts/gen/rider.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/rider/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/rider/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/rider/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/rider/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rider/standard.png), and one `row_<cockpit>.png` per cockpit.

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

A, B and C are boxes of one envelope. No two envelopes overlap. Built size with the rider: 5.1 to 5.7 wide, 14.1 to 15.0 long, 6.8 to 8.0 high (measured from the lowest jet, Y -1.6).

## Where the four fundamentals sit, and why

The four fundamentals are the bike's stance: swapping one changes the outline, not a detail.
- **Stabilisers = the front end.** The fork holds the lift hardware where a front wheel was. It reads from the front and from above. Options: one boxy lift pod with side jets (Sport Fork), three torpedoes on a straight axle (Torpedo Fork), a 1.6-wide pod with an open intake mouth and canted 0.7 axle jets on a long rake (Long Rake), two upright lift cans, twin pods under a canard (Girder Twin), twin booms with vanes.
- **Engine1 = the main turbine**, under the spine between the rider's legs. Every option ends in a rear-facing glow at least 0.76 across in the exhaust tunnel (box C) under the swingarm, so it reads as a jet in the chase view: one long centre tailpipe (Inline), megaphones (Flat Twin), twin tailpipes from two slim cans in a V (V-Twin), one tall canted can with a single stinger (Big Single), four lift posts plus a rear collector nozzle (Four-Poster), a flat slot (Slot Burner).
- **Engine2 = the rear end.** A thruster on its own swingarm where the rear wheel was. Its floor is Y -0.5, so the Engine1 exhaust shows underneath. Options: one long barrel, three barrels (Trident), a tall narrow block with side scoops and a stepped nozzle with a recessed glow (Fat Block), an over-under pair, twin side barrels, a flat fan-tail slot.
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

Each cockpit owns bodywork of its own, so it can be named under any kit.

| Cockpit | Pose | Owned shapes | Kit (culture) | Engine1 | Engine2 | Stabilisers | Boost |
|---|---|---|---|---|---|---|---|
| Supersport | full tuck | twin-spar frame 0.6 thick in body colour; angular race hump to Y 4.3 with shoulders | Paddock (Supersport) | Inline Turbine | Mono Thruster | Sport Fork | Twin Cans |
| Café | crouch, rear-set feet | round dome hump; slim solo seat | Ton-Up (Café Racer) | Flat Twin | Trident | Torpedo Fork | Reverse Cones |
| Chopper | laid back, feet forward | running boards; king backrest to Y 5.3 | Long Haul (Chopper) | V-Twin Jets | Fat Block | Long Rake | Shotgun Pipes |
| Scrambler | standing, elbows out | tall flat bench; side number boards 2 high | Holeshot (Motocross) | Big Single | Over-Under | Lift Cans | High Megaphone |
| Streetfighter | upright, elbows out | solid triangular frame panel; kicked tail pad; frame sliders | Bare Knuckle (Streetfighter) | Four-Poster | Twin Barrels | Girder Twin | Quad Stubs |
| Speeder | prone | sled tub walls, flared gunwales, haunch that peaks at Z 1.5 and runs out at the seat tail | Outrider (Speeder) | Slot Burner | Fan Tail | Twin Boom | Slot Blades |

Each kit also has its own Fairing, Screen, Bars, Tank, Side Panels, Seat Unit and Tail Kit: 66 modules in 11 slots. All 36 cockpit and kit pairs are in matrix.png and the row files. 15 builds: 6 native, 6 swapped, 3 mixed.

## What the review fixes changed

- Café cockpit and Ton-Up kit added: six cockpits and six cultures, as the brief asks. Every cockpit gained owned bodywork (table above). Every hump falls to the seat tail datum, so none ends in a cliff. The Speeder haunch now peaks beside the hips.
- Every Main Turbine has a rear-facing glow in the new exhaust tunnel. The Rear Thruster floor rose from Y -1.6 to -0.5 to show it. Fat Block, Long Rake, V-Twin and Big Single were rebuilt as jet hardware. The squat Big Single drum is gone.
- Apes became wide Pullbacks under Y 4.5. The sissy bar is short (top at Y 4.2) and backs a pillion pad on the Bobber Fender. Saddlebag tops sit at Y 3.2.
- Every Fairing carries the screen deck and every Screen sits flush on it. The Stub Tail lamp is a 1.6 x 0.25 slit. Tail Kit capped at Y 5.0. Fork, fairing, thruster and tail envelopes each lost 0.2 to 0.3 of reach. Length fell from 14.7..15.8 to 14.1..15.0.

## Authoring rules for real meshes

1. Author every mesh in cockpit root space. Keep every surface inside its slot envelope, not only the corners.
2. Land on pads, never on body shapes. End each module with a dark bracket that meets its pad with a 0.1 to 0.5 gap.
3. Do not move a pad. Every cockpit ships the same spine, neck, plate, hanger, stays and seat tail. Character goes in the owned bodywork and the rider's pose.
4. The rider is cockpit geometry. Hands sit on the hand datum in every pose and every Bars grip ends there. No module enters the cockpit envelope, so none can cut the rider.
5. No wheel shapes. Every jet has an intake, a body, a nozzle and a glowing `thrust` face, and is longer than it is wide. Lamps are bullets or slits. Large glowing faces are for thrust only.
6. Every Fairing carries the screen deck. Every Seat Unit starts at the seat tail datum and carries the tail rail to Z 6.7, so a Tail Kit never floats.
7. Above Y 0.3 the Main Turbine is at most 1.8 wide. Its top mount reaches Y 1.5. Its exhaust exits in the tunnel, below Y -0.55.
8. Options in one slot must differ in outline: count, length, height or stance. Detail alone does not count. Give every part a paint channel: brackets and linkage are `detail`, jet glow is `thrust`.

## Validator

`SPEC rider: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 66, 'builds': 15, 'worst_gap': 0.25, 'min_distinctness': {'Engine1': 0.5, 'Engine2': 0.45, 'Stabilisers': 0.41, 'Boost': 0.56, 'FrontBumper': 0.39, 'RearBumper': 0.41, 'RearSpoiler': 0.49, 'SidePods': 0.46, 'Hood': 0.41, 'Roof': 0.34, 'Accessory': 0.56, 'Cockpit': 0.56}, 'min_distinctness_whole': {'Engine1': 0.39, 'Engine2': 0.31, 'Stabilisers': 0.34, 'Boost': 0.5, 'FrontBumper': 0.23, 'RearBumper': 0.35, 'RearSpoiler': 0.29, 'SidePods': 0.44, 'Hood': 0.27, 'Roof': 0.24, 'Accessory': 0.33, 'Cockpit': 0.21}, 'build_sizes_WHL': {...}}`
The line ends with the size of each build; the range is given above. `min_distinctness` scores the free outline (the area all options share is removed). `min_distinctness_whole` scores the whole outline. Targets are 0.35 for the four fundamentals and the Seat Unit, and 0.25 for the rest and for cockpits. All free scores meet them.

## Open risks

- Whole-outline cockpit scores are still low: Supersport against Café is 0.21, Chopper against Streetfighter and Supersport against Speeder are 0.26. The rider and the shared chassis are most of a bike's outline. The review asked for 0.35 whole; that is not met. The free score is 0.56.
- Streetfighter is the weakest cockpit under a foreign kit. Its frame panel sits low and Side Panels can cover it.
- Height is 6.8 to 8.0 against the brief's 6, and length up to 15.0 against 14. A 5-stud rider above a hover gap sets the height.
- The Fat Block is still a block by design. It reads as a jet through its scoops and stepped nozzle, not its outline. On the native Chopper the Short Sissy sits behind the cockpit's own king backrest. It backs the pillion pad, not the rider.
- One hand datum means Bars cannot move the hands. True ape hangers need arm IK. Bubble and Canopy are the closest screens (0.34 free, target 0.25).
- The blockout rider is 1.5 wide at the torso and up to 4.2 across the elbows. A real R15 avatar and its astride animation are untested. Passengers, lean angle and ground clearance in a banked turn are untested.
