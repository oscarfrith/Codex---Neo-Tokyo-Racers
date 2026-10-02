# Rodder frame standard (round 2, after the second review fix pass)

Status: design exploration, round 2, 2026-10-02. Primitive blockout only. Nothing here is game content or approved.
Spec: [rodder.json](../../../scripts/vehicle_blockouts/specs/rodder.json), written by [gen/rodder.py](../../../scripts/vehicle_blockouts/gen/rodder.py). Previews: [mix A](../../../scripts/vehicle_blockouts/previews/rodder/mix_a.png) and [mix B](../../../scripts/vehicle_blockouts/previews/rodder/mix_b.png) (twelve builds with every slot random), [matrix](../../../scripts/vehicle_blockouts/previews/rodder/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/rodder/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/rodder/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/rodder/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rodder/standard.png), and one `row_<cab>.png` per cab.

Rodder is a hot rod on jet thrust. A narrow cab sits at the back of two bare frame rails. An exposed jet engine sits on the rails ahead of it, behind a grille shell. The front rails rake nose-down. There are no wheels, drums, discs or rings anywhere. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Lands on |
|---|---|---|---|---|---|
| Cockpit | Cab | -3.25..3.25 | -0.9..6.4 | 1..10 | root |
| Cockpit (rear horns) | | -3.25..3.25 | -0.9..0.6 | 10..13.5 | root |
| `FrontBody` | Frame and Shell | A, B: -3.1..3.1; C: -3.6..3.6 | A: -1.25..0.6; B: -1.9..0.6; C: 0.6..4.4 | A: -14.5..-9.5; B: -9.5..1; C: -14.5..-11.5 | cab rail couplers at the firewall, Z 1 |
| `Engine1` | Front Engine | -2.7..2.7 | 0.6..6.4 | -11.5..1 | frame pedestals, Y 0.6, and firewall plate, Z 1 |
| `Engine2` | Side Jets | 3.5..6.6, mirrored | -1.8..4.6 | 1.5..13.5 | cab barrel pads, X 3.25 |
| `Stabilisers` | Axle Jets | A: -3.6..3.6; B: 3.6..7.0, mirrored | A: -2.1..-1.25; B: -2.3..3.2 | A: -13.5..-9.5; B: -16..-9.5 | axle perch under the frame rails |
| `Boost` | Headers | 2.7..6.4, mirrored | 0.6..5.8 | -9..1 | engine port rail, X 2.65 |
| `SidePods` | Rail Dress | 3.1..6.5, mirrored | -2.0..0.6 | -9..1 | outer face of the frame rails, X 2.9 |
| `RearBody` | Tail | -3.25..3.25 | 0.6..4.6 | 10..13.5 | cab tail collar and bulkhead, and the horn tops |
| `FrontBumper` | Nose Gear | -3.6..3.6 | -2.2..3.6 | -16.5..-14.5 | front frame horns, Z -14.5 |
| `RearBumper` | Launch Gear | -4.5..4.5 | -2.0..3.0 | 13.5..16.5 | rear horns, Z 13.5 |
| `RearSpoiler` | Rear Rig | -5.5..5.5 | 4.6..9.6 | 10..15.5 | cab rig bar and the Tail's rear rig bar |

No two envelopes overlap. `Hood`, `Roof` and `Accessory` are not used. Built size: 12.5 to 14.0 wide, 30.8 to 32.9 long, 9.4 to 11.5 high over the rear rig.

## The four fundamentals

| Slot | Where | Why there |
|---|---|---|
| `Engine1` Front Engine | Level on the rails between the shell and the firewall, fully exposed | It is the hot-rod engine. Blower, stacks and scoops become jet intakes. The glow is a burner band on the engine body, 1.95 to 3.25 across, proud of the body. Flat Trio instead has three upswept nozzles, one 1.6 and two 1.0. |
| `Engine2` Side Jets | A long jet each side of the cab, on two outrigger pads | It takes the place of the slicks. Each is 8 to 12 long and 1.3 to 2.9 across, so it reads as a jet, not a tyre. Every body stops at Y 3.45 or lower, under the beltline; only the Lances' thin tail fin rises to 3.9. Nozzles face the chase camera. |
| `Stabilisers` Axle Jets | On a beam axle under the front rails, pods outboard at the front corners | It keeps the beam-axle face of a rod. Every option has a burner band 1.25 to 1.6 across that shows from above and from the front, plus a down nozzle 0.9 to 1.3 across. |
| `Boost` Headers | Bolted to the port rail on each side of the engine | Headers are where a rod shows fire. They carry the tip glows, are painted Primary and point out, up or back, clear of the engine and the Side Jets. Every option now shows glow to the chase camera. |

## Datums and hardpoint pads

| Datum or pad | Value | Use |
|---|---|---|
| Hover plane / sill / beltline | Y -2.0 / 0.6 / 3.6 | Ground; rail top, engine bed and tail floor; cowl and tub top. |
| Firewall / grille plane / cab back | Z 1 / -11.5 / 10 | Ends of the engine bay; start of Tail and Rear Rig. |
| Rail section | X 2.3..2.9, Y -0.3..0.6 | Same in the cab and the frame. Paint Secondary. |
| Rail coupler | Z 1.0..1.2 on each cab rail, dark | Bridges the firewall seam. Frame rails stop at Z 0.97 and butt against it. |
| Rake | 0.9 down over 15.4 (3.34 degrees), about the firewall | Frame, shell, Rail Dress, axle and Nose Gear follow it. The engine does not. |
| Engine pedestals | Z -9.5 and -2.5, tops at Y 0.6 | Part of the frame. They bring the raked rails back up to a level bed. |
| Firewall plate | X -1.7..1.7, Y 0.8..3.0, Z 1.0..1.45 | Every engine's transfer duct stops at Z 0.95, 0.05 short of it. It runs back to the cowl, so no slit shows. |
| Port rail | X 2.2..2.65, Y 1.4..2.0, Z -7..-4 | On every engine. Header flange sits at X 2.8..3.0. |
| Axle perch | Z -12, top at Y -1.27 | Ships with every Axle Jets module. Every frame's underside there is Y -1.07: box rails reach it, tube frames hang a dark block to it. |
| Barrel pads | X 3.0..3.25, Y 0.8..2.0, at Z 3.8 and 8.2 | On outrigger tubes through every cab. Side Jet pylons start at X 3.5. |
| Tail collar | X -2.0..2.0, Y 0.8..3.2, Z 9.4..9.75 | The same 4.0 by 2.4 section on every cab. Each cab blends its own body into it. |
| Rear bulkhead | X -1.9..1.9, Y 0.9..3.1, Z 9.75..9.95 | Dark shadow-gap plate. Every Tail starts 0.15 behind it with a first ring of the collar section. |
| Cab rig bar | Y 4.4, Z 9.78, X -2.0..2.0 | On every cab. The front of every Rear Rig stands on it. |
| Rear rig bar | Y 4.38, Z 12.2, X -2.0..2.0 | On every Tail, on that Tail's own posts. The back of every Rear Rig stands on it. |
| Horns | Rails end Z -14.4 (front, 0.9 low) and Z 13.4 (rear) | Bumper brackets, X 2.4..2.8. |

## Kits

| Kit and culture | Native cab | Front Engine | Side Jets | Axle Jets | Headers |
|---|---|---|---|---|---|
| Highboy | Deuce (chopped coupé, tub tucks in to the collar) | Blown Turbine: fat 3.0 barrel, blower and scoop, 3.25 burner band | Long Barrels: round, 2.4 by 11.8, low | Beam Lifters: one tall upright can a side | Lake Pipes: long pipe, 1.7 megaphone kicked up and out |
| T-Bucket | Bucket (open tub, tall screen, tank box behind) | Tunnel Ram: short block, tower, two intake bells, 2.3 burner can | Stub Ramjets: square, 2.4 by 2.4 by 8.2, top at Y 3.4 | Torpedoes: long pods, two tilted down nozzles | Staged Stacks: three a side, leaning 30 degrees out |
| Rat Rod | Rat Cab (tall pickup cab) | Flat Trio: one 2.1 turbine with two 1.3 helpers, three upswept nozzles | Over-Unders: stacked pairs | Quad Cans: two a side splayed in a V | Side Dumps: two low megaphones a side, 32 degrees out and back |
| Slingshot Drag | Slingshot (open cage, shoulder fairings) | Twin Mill: two slim turbines in tandem, forward-leaning ram horns | Lances: 1.3 spears, long needle intake, tail fin | Canard Vanes: 1.4 by 5.5 tip jets | Zoomies: four a side, swept back |
| Salt Flat | Lakester (4.6 by 3.4 oval tank, 3.0 bubble) | Turbine Swap: one slim 2.2 by 6.7 turbine on a keel, tall dorsal fin | Slab Pods: flat, dorsal scoop, slot nozzle | Faired Spats: a raked can through a low blade | Slot Burners: flat pod, glowing slots on the side, top and tail |

Body modules in the same order: Frame and Shell (Deuce Shell, Track Nose, Rat Frame, Sling Rails, Salt Nose), Tail (Turtle Deck, Strapped Trunk, Bobber Bed, Chute Tail, Boat Tail), Rail Dress (Nerf Rails, Running Boards, Saddle Tanks, Delta Strakes, Belly Skirts), Nose Gear, Launch Gear, Rear Rig (Roll Bar, Twin Fins, Headache Rack, Dragster Wing, Tail Fin). mix_a.png and mix_b.png are the per-module swap test. matrix.png shows all 25 cab and kit pairs.

## What the second fix pass changed

- **Rear Rig.** Every Tail now carries a rear rig bar on its own posts: on the deck, on the trunk lid, on the bed's stake posts, or as a hoop on the horns. Every rig uses both bars. Twin Fins and Headache Rack span them, Tail Fin has a second foot and its spine stops at Z 13.6, Roll Bar has back stays, and the Dragster Wing's rear struts start on the rear bar. No rig hangs over a low tail.
- **Sling Rails and seams.** The lower chord is a fish-belly truss, deepest mid-bay, and returns to the cab rail underside at the firewall. Tube frames (Sling Rails, Track Nose) have an axle hanger, so every axle seam is 0.2. Rail couplers, the longer firewall plate and longer ducts close the daylight slit at the firewall.
- **Glows.** Blown Turbine's band is 3.25 across and proud of the barrels, with a slimmer case behind it. Lake Pipes end in a 1.7 megaphone, glow face at Y 2.76. Slot Burners gained a top slot and a rear slot.
- **Side Jets and look-alikes.** Stub Ramjets are lowered to Y 1.0..3.4 and lengthened, so they no longer cover the door glass. Turbine Swap is slim and long with a tall fin. Lances are thin spears. Flat Trio is one main turbine and two helpers. Saddle Tanks are flat-sided box tanks, not tubes.

## Authoring rules for real meshes

1. Every cab ships the same chassis: rails, rail couplers and rear horns, firewall plate, two outrigger tubes with barrel pads, tail collar, rear bulkhead, rig bar. Model it once. Do not move or reshape a pad.
2. Cab character goes in the cowl, glass, roofline and how far back the driver sits. Stay inside X ±3.25 and under Y 6.4. Every cab must reach the collar section with no step wider than 0.4.
3. A module lands on its pad, never on a body shape. Engines sit on the two pedestals and end at the firewall plate. Headers bolt to the port rail. Side Jets hang on the two barrel pads and stay under the beltline. Tails start at the collar section and carry the rear rig bar. Rear Rigs stand on both rig bars.
4. Leave a 0.2 to 0.5 shadow gap at every join and bridge it with a dark Detail bracket, flange or pylon.
5. Author the frame, shell, Rail Dress, axle and Nose Gear on the raked line and everything else level. Every Frame and Shell keeps the rail section, both pedestals, the front horns and an underside at Y -1.07 over the perch.
6. Jet hardware is longer than it is wide. No part may read as a wheel: no rings, hoops, flat discs or short fat cylinders.
7. Engine stacks and horns are intakes: Secondary paint, bell mouths, no glow. The engine glows at a burner band that stands proud of the body. Headers are Primary and carry the tip glows.
8. Header tips stay ahead of Z 1. Side Jet intakes start behind Z 1.5.
9. Two options for a slot must differ in outline: section, length, height, count or stance.

## Validator

`SPEC rodder: 0 error(s), 0 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 50, 'builds': 13, 'worst_gap': 0.35, 'min_distinctness': {'Engine1': 0.59, 'Engine2': 0.44, 'Stabilisers': 0.57, 'Boost': 0.66, 'FrontBody': 0.53, 'RearBody': 0.58, 'SidePods': 0.66, 'FrontBumper': 0.61, 'RearBumper': 0.58, 'RearSpoiler': 0.69, 'Cockpit': 0.36}, 'min_distinctness_whole': {'Engine1': 0.31, 'Engine2': 0.31, 'Stabilisers': 0.45, 'Boost': 0.53, 'FrontBody': 0.35, 'RearBody': 0.25, 'SidePods': 0.64, 'FrontBumper': 0.54, 'RearBumper': 0.5, 'RearSpoiler': 0.64, 'Cockpit': 0.11}, ...}` (the line ends with the 13 build sizes, which did not change).

`min_distinctness` is the free-outline score: the area every option shares is removed first. It is the score the targets apply to (0.35 for fundamentals and main body slots, 0.25 for bumpers and cabs), and all targets are met. `min_distinctness_whole` is the whole-outline score. Closest pairs, free then whole: Bucket and Lakester 0.36 / 0.11; Blown Turbine and Turbine Swap 0.60 / 0.31 (was 0.50 / 0.26); Long Barrels and Slab Pods 0.44 / 0.31; Long Barrels and Lances 0.66 / 0.41; Turtle Deck and Strapped Trunk 0.58 / 0.26; Bobber Bed and Boat Tail 0.66 / 0.25. Thirteen builds: five native, five swapped, three mixed. The largest build has 219 parts (limit 220).

## Open risks

- Five cabs and five kits, not six: the Altered cab and a Gasser kit from the brief are not built. That needs one new cab and ten new modules, so it was left out of this fix pass. The part budget is also nearly full: Slingshot with the Rat Rod kit has 219 parts. A sixth kit or more detail needs parts trimmed elsewhere.
- Whole-outline scores are low for cabs (0.11) and Tails (0.25). The shared collar, first ring and rear rig bar make the shared area big. The parts differ in section and glass, which silhouettes do not see. Real meshes must keep the Bucket open and the Lakester round.
- The Rat Rod kit is still the busiest: three upswept nozzles, four megaphones and eight splayed cans. Lake Pipes next to Flat Trio put five glows close together. Thrust effects need a check for clutter.
- The rear rig bar stands on thin posts over the Turtle Deck (2.0 tall) and as a hoop over the Chute Tail and Boat Tail. Real meshes should make these read as deliberate rig frames.
- Stub Ramjets are plain boxes from behind; the ramp intake only shows from the front. The firewall plate still stands proud of the bare Slingshot torque tube.
- Builds are 30.8 to 32.9 long against a 30 target, and 9.4 to 11.5 high against 7. The Rear Rigs cause the height. Rake is baked into the front modules. The validator scores silhouettes only. The twelve mixes and 25 matrix cells were checked by eye.
