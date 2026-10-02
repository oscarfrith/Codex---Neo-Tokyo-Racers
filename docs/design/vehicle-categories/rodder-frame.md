# Rodder frame standard (round 2, after the critic fix pass)

Status: design exploration, round 2, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [rodder.json](../../../scripts/vehicle_blockouts/specs/rodder.json), written by [gen/rodder.py](../../../scripts/vehicle_blockouts/gen/rodder.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/rodder/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/rodder/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/rodder/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/rodder/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rodder/standard.png), and one `row_<cab>.png` per cab.

Rodder is a hot rod on jet thrust. A narrow cab sits at the back of two bare frame rails. An exposed jet engine sits on the rails ahead of it, behind a grille shell. The front rails rake nose-down. There are no wheels, drums, discs or rings anywhere. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Lands on |
|---|---|---|---|---|---|
| Cockpit | Cab | -3.25..3.25 | -0.9..6.4 | 1..10 | root |
| Cockpit (rear horns) | | -3.25..3.25 | -0.9..0.6 | 10..13.5 | root |
| `FrontBody` | Frame and Shell | A, B: -3.1..3.1; C: -3.6..3.6 | A: -1.25..0.6; B: -1.9..0.6; C: 0.6..4.4 | A: -14.5..-9.5; B: -9.5..1; C: -14.5..-11.5 | cab rails at the firewall, Z 1 |
| `Engine1` | Front Engine | -2.7..2.7 | 0.6..6.4 | -11.5..1 | frame pedestals, Y 0.6, and firewall plate, Z 1 |
| `Engine2` | Side Jets | 3.5..6.6, mirrored | -1.8..4.6 | 1.5..13.5 | cab barrel pads, X 3.25 |
| `Stabilisers` | Axle Jets | A: -3.6..3.6; B: 3.6..7.0, mirrored | A: -2.1..-1.25; B: -2.3..3.2 | A: -13.5..-9.5; B: -16..-9.5 | axle perch under the frame rails |
| `Boost` | Headers | 2.7..6.4, mirrored | 0.6..5.8 | -9..1 | engine port rail, X 2.65 |
| `SidePods` | Rail Dress | 3.1..6.5, mirrored | -2.0..0.6 | -9..1 | outer face of the frame rails, X 2.9 |
| `RearBody` | Tail | -3.25..3.25 | 0.6..4.6 | 10..13.5 | cab tail collar and bulkhead, and the horn tops |
| `FrontBumper` | Nose Gear | -3.6..3.6 | -2.2..3.6 | -16.5..-14.5 | front frame horns, Z -14.5 |
| `RearBumper` | Launch Gear | -4.5..4.5 | -2.0..3.0 | 13.5..16.5 | rear horns, Z 13.5 |
| `RearSpoiler` | Rear Rig | -5.5..5.5 | 4.6..9.6 | 10..15.5 | cab rig bar, Y 4.4 |

No two envelopes overlap. The Headers envelope grew from X 5.8 to 6.4 in the fix pass so the stacks can lean out. `Hood`, `Roof` and `Accessory` are not used. Built size: 12.5 to 14.0 wide, 30.8 to 32.9 long, 9.4 to 11.5 high over the rear rig.

## The four fundamentals

| Slot | Where | Why there |
|---|---|---|
| `Engine1` Front Engine | Level on the rails between the shell and the firewall, fully exposed | It is the hot-rod engine. Blower, stacks and scoops become jet intakes. The glow is a burner band on the engine body, 1.9 to 2.5 across. Flat Trio instead has three 1.2 upswept nozzles. |
| `Engine2` Side Jets | A long jet each side of the cab, on two outrigger pads | It takes the place of the slicks. Each is 7 to 12 long and 1.6 to 2.9 across, so it reads as a jet, not a tyre. Nozzles face the chase camera. |
| `Stabilisers` Axle Jets | On a beam axle under the front rails, pods outboard at the front corners | It keeps the beam-axle face of a rod. Every option has a burner band 1.25 to 1.6 across that shows from above and from the front, plus a down nozzle tilted 20 to 25 degrees outward. |
| `Boost` Headers | Bolted to the port rail on each side of the engine | Headers are where a rod shows fire. They carry the tip glows, are painted Primary and point out, up or back, clear of the engine and the Side Jets. |

## Datums and hardpoint pads

| Datum or pad | Value | Use |
|---|---|---|
| Hover plane / sill / beltline | Y -2.0 / 0.6 / 3.6 | Ground; rail top, engine bed and tail floor; cowl and tub top. |
| Firewall / grille plane / cab back | Z 1 / -11.5 / 10 | Ends of the engine bay; start of Tail and Rear Rig. |
| Rail section | X 2.3..2.9, Y -0.3..0.6 | Same in the cab and the frame. Paint Secondary. 0.3 shadow gap at the firewall. |
| Rake | 0.9 down over 15.4 (3.34 degrees), about the firewall | Frame, shell, Rail Dress, axle and Nose Gear follow it. The engine does not. |
| Engine pedestals | Z -9.5 and -2.5, tops at Y 0.6 | Part of the frame. They bring the raked rails back up to a level bed. |
| Firewall plate | X -1.7..1.7, Y 0.8..3.0, Z 1.1..1.35 | Every engine's transfer duct ends here. |
| Port rail | X 2.2..2.65, Y 1.4..2.0, Z -7..-4 | On every engine. Header flange sits at X 2.8..3.0. |
| Axle perch | Z -12, top at Y -1.27 | Ships with every Axle Jets module, 0.2 under the rails. |
| Barrel pads | X 3.0..3.25, Y 0.8..2.0, at Z 3.8 and 8.2 | On outrigger tubes through every cab. Side Jet pylons start at X 3.5. |
| Tail collar | X -2.0..2.0, Y 0.8..3.2, Z 9.4..9.75 | The same 4.0 by 2.4 section on every cab. Each cab blends its own body into it. |
| Rear bulkhead | X -1.9..1.9, Y 0.9..3.1, Z 9.75..9.95 | Dark shadow-gap plate. Every Tail starts 0.15 behind it with a first ring of the collar section. |
| Rig bar | Y 4.4, Z 9.78, X -2.0..2.0 | Every Rear Rig stands on it. |
| Horns | Rails end Z -14.4 (front, 0.9 low) and Z 13.4 (rear) | Bumper brackets, X 2.4..2.8. |

## Kits

| Kit and culture | Native cab | Front Engine | Side Jets | Axle Jets | Headers |
|---|---|---|---|---|---|
| Highboy | Deuce (chopped coupé, tub tucks in to the collar) | Blown Turbine: fat barrel, blower and scoop | Long Barrels: round, 2.4 by 11.8, low | Beam Lifters: one tall upright can a side | Lake Pipes |
| T-Bucket | Bucket (open tub, tall screen, tank box behind) | Tunnel Ram: short block, tower, two intake bells, 2.3 burner can | Stub Ramjets: square, 2.4 by 2.4 by 7, at beltline height | Torpedoes: long pods, two tilted down nozzles | Staged Stacks: three a side, leaning 30 degrees out |
| Rat Rod | Rat Cab (tall pickup cab) | Flat Trio: three 1.5 turbines abreast, three upswept nozzles | Over-Unders: stacked pairs | Quad Cans: two a side splayed in a V | Side Dumps: two low megaphones a side, 32 degrees out and back |
| Slingshot Drag | Slingshot (open cage, shoulder fairings) | Twin Mill: two slim turbines in tandem, forward-leaning ram horns | Lances: slim, finned | Canard Vanes: 1.4 by 5.5 tip jets | Zoomies: four a side, swept back |
| Salt Flat | Lakester (4.6 by 3.4 oval tank, 3.0 bubble) | Turbine Swap: one 2.8 by 5.8 turbine on a keel fairing | Slab Pods: flat, dorsal scoop, slot nozzle | Faired Spats: a raked can through a low blade | Slot Burners |

Body modules in the same order: Frame and Shell (Deuce Shell, Track Nose, Rat Frame, Sling Rails, Salt Nose), Tail (Turtle Deck, Strapped Trunk, Bobber Bed, Chute Tail, Boat Tail), Rail Dress, Nose Gear, Launch Gear, Rear Rig. matrix.png shows all 25 cab and kit pairs. fundamentals.png shows every engine, stabiliser and boost option; each has an intake, a body and a `thrust` part.

## What the fix pass changed

- **Rear fit.** The tail collar is new. Deuce tucks in to it, Slingshot grows shoulder fairings to it, the Lakester tank flares down to it and Bucket fills its old 3-stud hole with a tank box. All five Tails were re-authored from the collar section: the deck, trunk, bed front, chute taper and boat tail all start 4.0 wide by 2.4 high.
- **Lakester.** The tank is now a flattened oval, 4.6 by 3.4, with a Secondary stripe and a blunt nose over the firewall plate. It no longer matches any Side Jet.
- **Look-alikes.** Stub Ramjets are square and high; Long Barrels are round, slim and low. Quad Cans are a splayed V; Beam Lifters stay upright.
- **Fundamentals.** Canard Vanes, Faired Spats, Flat Trio, Turbine Swap and Side Dumps were rebuilt as visible jet hardware. Engine intakes no longer glow, so engine and boost read apart.

## Authoring rules for real meshes

1. Every cab ships the same chassis: rails and rear horns, firewall plate, two outrigger tubes with barrel pads, tail collar, rear bulkhead, rig bar. Model it once. Do not move or reshape a pad.
2. Cab character goes in the cowl, glass, roofline and how far back the driver sits. Stay inside X ±3.25 and under Y 6.4. Every cab must reach the collar section with no step wider than 0.4.
3. A module lands on its pad, never on a body shape. Engines sit on the two pedestals and end at the firewall plate. Headers bolt to the port rail. Side Jets hang on the two barrel pads. Tails start at the collar section and then grow or taper.
4. Leave a 0.2 to 0.5 shadow gap at every join and bridge it with a dark Detail bracket, flange or pylon.
5. Author the frame, shell, Rail Dress, axle and Nose Gear on the raked line and everything else level. Every Frame and Shell keeps the rail section, both pedestals and the front horns.
6. Jet hardware is longer than it is wide. No part may read as a wheel: no rings, hoops, flat discs or short fat cylinders.
7. Engine stacks and horns are intakes: Secondary paint, bell mouths, no glow. The engine glows at a burner band. Headers are Primary and carry the tip glows.
8. Header tips stay ahead of Z 1. Side Jet intakes start behind Z 1.5.
9. Two options for a slot must differ in outline: section, length, height, count or stance.

## Validator

`SPEC rodder: 0 error(s), 0 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 50, 'builds': 13, 'worst_gap': 0.44, 'min_distinctness': {'Engine1': 0.5, 'Engine2': 0.41, 'Stabilisers': 0.57, 'Boost': 0.59, 'FrontBody': 0.53, 'RearBody': 0.56, 'SidePods': 0.61, 'FrontBumper': 0.61, 'RearBumper': 0.58, 'RearSpoiler': 0.74, 'Cockpit': 0.34}, 'min_distinctness_whole': {'Engine1': 0.26, 'Engine2': 0.31, 'Stabilisers': 0.45, 'Boost': 0.46, 'FrontBody': 0.35, 'RearBody': 0.26, 'SidePods': 0.59, 'FrontBumper': 0.54, 'RearBumper': 0.5, 'RearSpoiler': 0.7, 'Cockpit': 0.11}, ...}` (the line ends with the 13 build sizes).

`min_distinctness` is the free-outline score: the area every option shares is removed first. It is the score the targets apply to (0.35 for fundamentals and main body slots, 0.25 for bumpers and cabs), and all targets are met. `min_distinctness_whole` is the whole-outline score. Closest pairs, free then whole: Bucket and Lakester 0.34 / 0.11; Blown Turbine and Turbine Swap 0.50 / 0.26; Long Barrels and Slab Pods 0.41 / 0.31; Turtle Deck and Boat Tail 0.56 / 0.26. Thirteen builds: five native, five swapped, three mixed. The largest build has 216 parts (limit 220).

## Open risks

- Whole-outline scores fell for cabs (0.25 to 0.11) and Tails (0.41 to 0.26). The shared collar, first ring and tank fill make the shared area bigger. The parts differ in section and glass, which silhouettes do not see. Real meshes must keep the Bucket open and the Lakester round.
- The Rat Rod kit is the busiest: three upswept nozzles, four megaphones and eight splayed cans. Thrust effects need a check for clutter.
- Turbine Swap and Blown Turbine are both fat barrels; they differ by the scoop, the keel and one stud of height. Stub Ramjets are plain boxes from behind; the ramp intake only shows from the front.
- The firewall plate still stands proud of the bare Slingshot torque tube.
- Five cabs, not six: the Altered cab and a Gasser kit from the brief are not built. Builds are 30.8 to 32.9 long against a 30 target, and 9.4 to 11.5 high against 7. The Rear Rigs cause the height.
- Rake is baked into the front modules. A different angle means re-authoring them.
- The validator scores silhouettes only. The 25 matrix cells were checked by eye.
