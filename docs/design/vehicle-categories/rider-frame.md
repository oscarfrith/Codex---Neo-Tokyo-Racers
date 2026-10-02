# Rider frame standard (round 2)

Status: design exploration, round 2, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [rider.json](../../../scripts/vehicle_blockouts/specs/rider.json), written by [gen/rider.py](../../../scripts/vehicle_blockouts/gen/rider.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/rider/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/rider/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/rider/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/rider/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rider/standard.png).

Rider is a hoverbike. The rider is always on show. There are no wheels, rings, hoops or discs: every jet is longer than it is wide. The cockpit is a spine, a neck, a rear plate, the seat and the rider. Everything else bolts to those pads. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Anchor |
|---|---|---|---|---|---|
| Cockpit: spine | | ±0.9 | 1.6..2.2 | -3.1..3.3 | root |
| Cockpit: neck | | ±0.9 | 2.2..3.4 | -3.1..-2.6 | |
| Cockpit: seat | | ±0.9 | 2.2..3.4 | 0.15..3.3 | |
| Cockpit: rear plate | | ±0.9 | 0.3..1.6 | 2.6..3.3 | |
| Cockpit: leg channels | | 0.9..1.7, mirrored | 0.4..3.4 (0.4..2.2 ahead of Z -1.2) | -2.2..3.3 | |
| Cockpit: running-board shelf | | 1.7..2.4, mirrored | 0.4..1.3 | -2.2..0.6 | |
| Cockpit: rider upper body | | ±2.2 | 3.4..6.6 | -1.6..3.3 | |
| `Engine1` | Main Turbine | A ±0.9; B ±1.5 | A 0.3..1.55; B -1.6..0.3 | -2.55..2.5 | spine underside, Y 1.6 |
| `Engine2` | Rear Thruster | ±1.5 | -1.6..1.8 | 3.35..7.6 | rear plate, Z 3.3 |
| `Stabilisers` | Lift Fork | A ±2.4; B, C ±1.6 | A -1.6..1.0; B 1.0..2.0; C 2.0..2.9 | A -8.0..-2.8; B -6.6..-3.15; C -5.0..-3.15 | neck front, Z -3.1 |
| `Boost` | Afterburner | 1.5..2.9, mirrored | A -1.6..0.3; B -1.6..3.2 | A 0.6..3.3; B 3.3..7.8 | exhaust hanger, X 1.45 |
| `FrontBumper` | Fairing | ±1.6 | A 2.9..4.4; B 2.0..2.9; C 1.0..2.0 | A -7.2..-3.3; B -7.6..-5.0; C -7.6..-6.6 | neck front, Z -3.1 |
| `SidePods` | Side Panels | 1.7..2.6, mirrored | 1.3..3.4 | -3.2..3.3 | panel stays, X 1.65 |
| `RearSpoiler` | Seat Unit | ±1.4 | 1.85..4.6 | 3.35..6.8 | seat tail, Z 3.3 |
| `RearBumper` | Tail Kit | ±1.4 | 1.85..6.0 | 6.8..8.0 | Seat Unit tail rail, Z 6.7 |
| `Hood` | Tank | A ±0.9; B 0.9..1.6, mirrored | 2.2..3.4 | A -2.55..0.1; B -2.55..-1.2 | spine top, Y 2.2 |
| `Roof` | Screen | ±1.4 | 4.4..6.2 | -6.4..-3.3 | Fairing clocks pad, Y 4.35 |
| `Accessory` | Bars | ±2.3 | 3.4..5.6 | -3.25..-1.65 | neck top, Y 3.3 |

A, B and C are boxes of one envelope. No two envelopes overlap. Built size with the rider: 5.1 to 5.7 wide, 14.7 to 15.8 long, 6.6 to 8.1 high.

## Where the four fundamentals sit, and why

The four fundamentals are the bike's stance. Swapping one changes the outline, not a detail.

- **Stabilisers = the front end.** The fork holds the lift hardware where a front wheel was. It reads from the front and from above. Options: one boxy lift pod with winglet tip jets, a blade pod on a long rake with axle jets, two upright lift cans, twin pods under a canard, twin booms with vanes.
- **Engine1 = the main turbine**, under the spine between the rider's legs. Above Y 0.3 it stays between the legs (±0.9). Below the feet it may spread to ±1.5, so wide engines show from the side.
- **Engine2 = the rear end.** A thruster on its own swingarm where the rear wheel was. It reads from the chase camera. Options: one long barrel, a short fat block, a staggered over-under pair, twin side barrels, a flat fan-tail slot.
- **Boost = the exhaust.** Afterburner pipes on the flanks, beside and behind the rear thruster, so the glow sits next to the engine glow in the chase view.

## Datums and hardpoint pads

| Datum or pad | Owner | Value | Used by |
|---|---|---|---|
| Hover plane, floor | class | Y -2.0; nothing below Y -1.6 | all |
| Sill | class | Y 0.3: below it the engine may be wide | Engine1, Boost headers |
| Beltline | class | Y 2.2: spine top | Tank and seat sit on it |
| Hand datum | class | X ±1.15, Y 4.0, Z -1.3 | every rider's hands, every Bars grip end |
| Seat tail | class | Z 3.3, top at Y 3.0 | every cockpit seat ends here, every Seat Unit starts here |
| Fork pad | cockpit neck | front face Z -3.1, Y 1.7..2.9 | Lift Fork yokes |
| Fairing pad | cockpit neck | front face Z -3.1, Y 2.97..3.27 | Fairing bracket |
| Bar pad | cockpit neck | top face Y 3.3, Z -3.1..-2.6 | Bars clamp |
| Engine pad | cockpit spine | underside Y 1.75, Z -2.6..3.25 | Main Turbine top mount |
| Swingarm pad | cockpit rear plate | rear face Z 3.3, Y 0.35..1.75 | Rear Thruster pivot |
| Exhaust hanger | cockpit | X 0.75..1.45, Y 0.45..0.85, Z 2.8..3.25, both sides | Afterburner bracket |
| Panel stays | cockpit | out to X 1.65 at Y 1.95..2.15, Z -2.0..-1.8 and Z 2.9..3.1 | Side Panels |
| Clocks pad | every Fairing | X ±0.5, Y 4.05..4.35, Z -4.4..-3.7 | Screen base |
| Tail rail | every Seat Unit | X ±0.3, Y 1.9..2.15, Z 3.4..6.7 | Tail Kit bracket |

## Kits

| Kit | Culture | Native cockpit | Engine1 | Engine2 | Stabilisers | Boost |
|---|---|---|---|---|---|---|
| Paddock | Supersport | Supersport (full tuck, twin-spar frame) | Inline Turbine | Mono Thruster | Sport Fork | Twin Cans |
| Long Haul | Chopper | Chopper (laid back, running boards, king backrest) | V-Twin Jets | Fat Block | Long Rake | Shotgun Pipes |
| Holeshot | Motocross | Scrambler (standing, elbows out, tall bench) | Big Single | Over-Under | Lift Cans | High Megaphone |
| Bare Knuckle | Streetfighter | Streetfighter (upright, trellis frame) | Four-Poster | Twin Barrels | Girder Twin | Quad Stubs |
| Outrider | Speeder | Speeder (prone in a sled tub with gunwales) | Slot Burner | Fan Tail | Twin Boom | Slot Blades |

Each kit also has its own Fairing, Screen, Bars, Tank, Side Panels, Seat Unit and Tail Kit: 55 modules in 11 slots. All 25 cockpit and kit pairs are in matrix.png. 13 builds: 5 native, 5 swapped, 3 mixed.

## Authoring rules for real meshes

1. Author every mesh in cockpit root space. Keep every surface inside its slot envelope, not only the corners.
2. Land on pads, never on body shapes. End each module with a dark bracket that meets its pad with a 0.1 to 0.5 gap.
3. Do not move a pad. Every cockpit ships the same spine, neck, plate, hanger, stays and seat tail. Character goes in the seat, the frame and the rider's pose.
4. The rider is cockpit geometry. Hands sit on the hand datum in every pose. Grips end at the hand datum on every Bars module.
5. No module enters the cockpit envelope, so no module can cut the rider or the legs.
6. No wheel shapes. Every jet has an intake, a body, a nozzle and a glowing `thrust` face, and is longer than it is wide. Lamps are bullets or slits, not discs.
7. Every Fairing carries the clocks pad. Every Seat Unit carries the tail rail to Z 6.7. A short Seat Unit adds a boom along the rail so the Tail Kit never floats.
8. Above Y 0.3 the Main Turbine is at most 1.8 wide. Its top mount reaches Y 1.5.
9. Options in one slot must differ in outline: count, length, height or stance. Detail alone does not count.
10. Give every part a paint channel. Brackets and linkage are `detail`. Jet glow is `thrust`.

## Validator

`SPEC rider: 0 error(s), 0 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 55, 'builds': 13, 'worst_gap': 0.25, 'min_distinctness': {'Engine1': 0.37, 'Engine2': 0.42, 'Stabilisers': 0.42, 'Boost': 0.52, 'FrontBumper': 0.31, 'RearBumper': 0.43, 'RearSpoiler': 0.38, 'SidePods': 0.41, 'Hood': 0.27, 'Roof': 0.43, 'Accessory': 0.32, 'Cockpit': 0.26}}` Targets are 0.35 for the four fundamentals and the Seat Unit, and 0.25 for the rest and for cockpits. All are met.

## Open risks

- Cockpit distinctness is 0.26, just over the 0.25 target. A bike cockpit is mostly the rider, so the pose carries it. Real meshes must keep the five poses and the cockpit bodywork (backrest, running boards, gunwales) or the cockpits will blur.
- The brief names six cockpits. Café is not built. It needs its own kit of 11 modules.
- The Main Turbine sits under the rider. From a high chase camera the legs and frame hide half of it. The Inline Turbine is the weakest read. Wide engines (V-Twin, Four-Poster, Slot Burner) show best.
- Built length is 14.7 to 15.8, over the brief's 14. The Lift Fork and the Tail Kit account for the extra.
- One hand datum means Bars cannot move the hands. Apes rise and drop back to fixed grips. True apes need arm IK.
- The blockout rider is 1.5 wide at the torso and up to 4.2 across the elbows. A real R15 avatar and its astride animation are untested.
- Legal but weak mixes: a prone Speeder rider behind a tall Tourer screen; a Tail Wing behind the short Stub Tail sits on a thin boom; Saddlebags under the Speeder gunwales look heavy. Passengers, lean angle and ground clearance in a banked turn are untested.
