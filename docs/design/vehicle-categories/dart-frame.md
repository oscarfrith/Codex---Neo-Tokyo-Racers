# Dart frame standard (round 2, after critic review)

Status: design exploration, round 2, 2026-10-02. Primitive blockout only. Nothing here is game content or approved.
Spec: [dart.json](../../../scripts/vehicle_blockouts/specs/dart.json), written by [gen/dart.py](../../../scripts/vehicle_blockouts/gen/dart.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/dart/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/dart/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/dart/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/dart/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/dart/standard.png), one `row_<cockpit>.png` per fuselage.

Dart is one slender fuselage on the centreline. A prow bolts to its front ring frame and a main drive to its rear ring frame. Wings and wing engines hang off the flanks. Afterburner, airbrakes, tail fins and keel hang off the main drive. There are no wheels, rings, discs or rotors: every round part is a jet, tank or pod longer than it is wide, or a ball. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Anchors to |
|---|---|---|---|---|---|
| Cockpit | Fuselage | -3..3 | -1.4..5.6 | -8..8 | root |
| `FrontBody` | Prow | -5..5 | -0.6..2.8 | -15..-8 | fuselage prow ring frame, Z -8 |
| `FrontBumper` | Nose Tip | -5..5 | -0.6..2.8 | -17..-15 | prow nose collar, Z -15 |
| `SidePods` | Wings | 3..8, mirrored | -1.6..1.7 | -8..8 | fuselage flank hardpoints, X ±3 |
| `Engine2` | Wing Engines | 3..5.8, mirrored | 1.7..4.2 | -1..8 | fuselage rear hardpoint plate, X ±3 |
| `Engine1` | Main Drive | -3..3 | -0.4..3.2 | 8..14.5 | fuselage drive ring frame, Z 8 |
| `Engine1` (scoop zone) | | -2.4..2.4 | 3.2..4.6 | 8..10.2 | |
| `Boost` | Afterburner | -2.4..2.4 | 3.2..5.2 | 10.2..16.5 | drive burner deck, Y 3.2 |
| `Stabilisers` | Airbrakes | 3..8, mirrored | -0.6..3.3 | 8..15.5 | drive hardpoint posts, X ±3 |
| `RearSpoiler` | Tail Fins | 2.4..6, mirrored | 3.3..7.4 | 8..16.5 | drive fin pads, Y 3.3 |
| `RearSpoiler` (centre span) | | -2.4..2.4 | 5.2..7.4 | 8..16.5 | |
| `RearBumper` | Keel | -2..2 | -1.8..-0.4 | 8..17 | drive belly pad, Y -0.4 |

No two envelopes overlap. `RearBody`, `Hood`, `Roof` and `Accessory` are not used. Built size: 13.9 to 15.9 wide, 31.6 to 34.0 long, 6.7 to 9.1 high. Every build is inside 34 L x 16 W.

## The four fundamentals

| Slot | Where | Why |
|---|---|---|
| `Engine1` Main Drive | Behind the fuselage, Z 8 to 14.5, on the thrust axis | Dead astern, full in the chase camera. It has the most glow: 2.6 to 4.5 square studs of thrust, against 1.7 at most for any other slot. |
| `Engine2` Wing Engines | A mirrored pair on the fuselage shoulders, above the wing roots | Clear of the wings and the canopy, so they read from the front, the side and above. |
| `Stabilisers` Airbrakes | A mirrored pair on the flanks of the main drive | Widest point at the tail. Each has a control jet at least 1.3 across (thrust 0.86 or more) outboard of the brake surface, plus vents that glow upward and outboard. |
| `Boost` Afterburner | On the burner deck on top of the main drive | Highest jet on the tail, above the main nozzle, never hidden by the keel or the wings. |

Every option has a dark intake, a body and a glowing `thrust` nozzle. The generator checks three class rules on every run: the main drive out-glows every afterburner and wing-engine pair; no prow, drive or fuselage is thinner than 2.2 x 1.9 beside a seam; every airbrake has a real control jet and a glow that faces up or outboard.

## Datums

| Datum | Value | Meaning |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing built goes below -1.8. |
| Sill | Y 0.0 | Underside of the painted hull. A fuselage may hang a tank, duct or fin down to Y -1.4. |
| Thrust axis and beltline | Y 1.3 | Centre of both ring frames, the prow and the wing roots. |
| Deck | Y 3.0 | Top of the hull proper. Canopy, roofline, spine fins and fletches go above it, up to the roof at Y 5.6. |
| Drive top | Y 3.2 | Top of every main drive: burner deck and fin pads. |
| Ring frame | 3.0 x 2.4 | The shared section at both seams. Smallest neck allowed beside a seam is 2.2 x 1.9. |

## Hardpoint pads

Modules land on these pads and nowhere else. Every parent ships all of its pads in the same place.

| Parent | Pad | X | Y | Z | Carries |
|---|---|---|---|---|---|
| Fuselage | Prow ring frame | -1.5..1.5 | 0.1..2.5 | -8..-7.6 | Prow |
| Fuselage | Drive ring frame | -1.5..1.5 | 0.1..2.5 | 7.6..8 | Main Drive |
| Fuselage | Front wing hardpoint | 2.7..3, both sides | 0.65..1.35 | -2.8..-1.2 | Wings (root rib) |
| Fuselage | Rear hardpoint plate | 2.7..3, both sides | 0.65..2.7 | 3.6..6.4 | Wings below, Wing Engines above |
| Prow | Nose collar | -0.45..0.45 | 0.85..1.75 | -15..-14.6 | Nose Tip |
| Main Drive | Burner deck | -1.2..1.2 | 3.0..3.2 | 10.8..12.4 | Afterburner |
| Main Drive | Hardpoint posts | 2.75..3, both sides | 1.3..3.2 | 11..12.2 | Airbrakes |
| Main Drive | Fin pads | 2.4..3, both sides | 3.0..3.2 | 11..12.2 | Tail Fins |
| Main Drive | Belly pad | -0.8..0.8 | -0.4..-0.15 | 9.5..12.5 | Keel |

## Signature kits

| Kit | Native fuselage (its roofline feature shows over any kit) | Main Drive | Wing Engines | Airbrakes | Afterburner |
|---|---|---|---|---|---|
| Record | Needle: round tube over a belly tank, long bare nose, small canopy far aft, razorback | Mono Turbine: one big turbine, raked dorsal scoop | Lance Ramjets: thin, full length | Petal Slabs: tall slab, jet on its trailing edge | Stinger: long, thin, flared bell (thrust 0.95) |
| Works | Delta: faceted wedge, long windscreen to a peak at Y 5.5, dorsal spine fin to the tail | Twin Drive: two big barrels behind box intakes | Shoulder Turbines: round nacelle, shock cone | Clamshell: two flaps, jet outboard on the hinge bar | Twin Cans |
| Prototype | Manta: wafer hull, deck at Y 1.8, blister 4.4 wide, two horns at X ±2.6 standing above the deck | Slot Burner: flat fishtail | Slot Ramjets: flat boxes | Vane Cascade: three louvres, tip jet firing up and down | Slot Afterburner: flat and wide |
| Privateer | Twinboom: upright greenhouse far forward, two box rails at sill height, tail yoke | Quad Cluster: four 1.65 jets in a 2 x 2 block | Stacked Pair: over and under, full length | Outrigger Jets: boom, cowled lift jet, vane | Staged Bell: three growing stages |
| Salvage | Bubble: glass dome far forward, painted pressure tank behind it, side tanks | Rack Triple: three 1.7 jets stepped low to high | Scoop Burners: big square scoop, thin tailpipe | Drag Paddles: square paddle, fat jet outboard | Rocket Bottles: four 1.1 bottles in an arch |
| Interceptor | Arrowhead: arrow-shaped deck and canopy, swept barbs, two tall fletches and a ventral one | Vector Blade: one tall vertical slot nozzle | Chine Ramjets: faceted, sloped outer face | Droop Tailerons: jet low on each tip | Aerospike: plug body, glowing stepped spike |

Body modules per kit, in the same order: prow Spear, Twin Prong, Trident, Hammerhead, Spade, Broadhead; wings Stub, Delta, Forward Swept, Pontoons, Plank, Tandem Blades; nose tip Pitot, Canards, Sensor Blade, Ram Scoop, Bash Bar, Chisel; keel Tail Stinger, Keel Fin, Diffuser, Drogue Pods, Skid, Ventral V; tail fins Strakes, Twin Fins, Box Wing, V-Tail, Plank Spoiler, A-Tail.

## Authoring rules for real meshes

1. Author every part in cockpit-root space. Keep every vertex inside its slot envelope. Keep the whole build inside 34 L x 16 W and above Y -1.8.
2. Ship the pads exactly as listed: same position, same size, flat faces, dark `detail` material. Never move a pad to suit a shape.
3. Land on the pad, not on a body. A module's mating part matches the pad face and stops within 0.1 studs of it. The gap is the shadow gap.
4. Both seams are the 3.0 x 2.4 ring frame at Y 1.3. A fuselage tapers to it over its last two studs. A prow or drive starts with a dark ring (0.4), then a painted root fairing of ring section for 1.5 studs, and never necks below 2.2 x 1.9 in its first two studs. That removes the wasp waist.
5. A fuselage narrower than the hull fills out to the flank pads with a painted wing-root shelf, so wings meet body colour, not struts. Glass, pilot and roofline belong to the fuselage. Give each one a roofline or deck feature that shows over any kit. Every main drive carries all five of its pads, even when its jets are small.
6. Jets only. No rings, hoops, discs, rotors or drums. Any round body is at least 1.5 times as long as it is wide. An intake face wider than 1.7 is a square mouth or carries a shock cone, never a plain disc.
7. Two options for one slot differ in outline: count, length, height or stance. Check with the validator, not by eye. Give every part a paint channel. Pads and linkage are `detail`; jets glow on `thrust`; lights are `neon`. Keep linkage short: paint structure that is longer than a stud.

## Validator result

`SPEC dart: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 54, 'builds': 14, 'worst_gap': 0.1, 'min_distinctness': {'Engine1': 0.42, 'Engine2': 0.49, 'Stabilisers': 0.47, 'Boost': 0.42, 'FrontBody': 0.48, 'SidePods': 0.58, 'FrontBumper': 0.39, 'RearBumper': 0.34, 'RearSpoiler': 0.63, 'Cockpit': 0.46}, 'min_distinctness_whole': {'Engine1': 0.13, 'Engine2': 0.33, 'Stabilisers': 0.33, 'Boost': 0.22, 'FrontBody': 0.24, 'SidePods': 0.29, 'FrontBumper': 0.3, 'RearBumper': 0.24, 'RearSpoiler': 0.51, 'Cockpit': 0.24}}` (build sizes omitted).

`min_distinctness` is the free outline: the area every option shares is removed first. All targets are met on it: 0.35 or more for the big slots and for cockpits (class rule), 0.25 or more for the rest. `min_distinctness_whole` is the whole outline. The generator prints `class rules: 0 problem(s), 15 note(s)`; the notes list the fuselage pairs under 0.35 on the whole outline.

## Open risks

- Whole-outline cockpit score is 0.24, under the 0.35 the critic asked for. All six fuselages share the ring frames, the four flank pads and the 6-stud hull width, so plan views overlap by design. The free-outline score is 0.46. Closest pairs: Bubble with Arrowhead, Delta with Bubble. Whole-outline Engine1 is 0.13 for the same reason (shared root fairing, posts, deck and belly pad); its free score is 0.42.
- The Prototype tail is still three flat layers: Slot Burner, Slot Afterburner and the Box Wing plane. Daylight shows between them, but a real mesh should keep the top plane thin. Privateer has many parallel tubes: four drive jets, stacked wing jets, pontoons, hammerhead pods and drogue tubes. Vary their size clearly and keep them slender so they never read as wheels.
- The Rack Triple has the least thrust area of the drives (2.6). It still beats every afterburner (1.5 at most), but the margin is the smallest.
- Nothing is tested in Studio. Live slots mount at the cockpit root, which this standard assumes.
