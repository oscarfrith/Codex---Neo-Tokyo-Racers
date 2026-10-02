# Apex frame standard (round 2 blockout)

Status: design exploration, round 2, 2026-10-01. Not game content. Spec: [apex.json](../../../scripts/vehicle_blockouts/specs/apex.json), written by [gen/apex.py](../../../scripts/vehicle_blockouts/gen/apex.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/apex/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/apex/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/apex/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/apex/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/apex/standard.png).

Circuit racers as hover jets. Root space: +X right, +Y up, forward is -Z, studs. "±" means centred on X. "Both sides" means mirrored. Built: 5 cockpits, 5 signature kits, 50 modules (5 per slot), 13 builds of 152 to 193 parts, about 14 W x 7 to 8 H x 28 L. There are no wheels, rings, discs or drums. Every round part is a tube that runs along the car and is longer than it is wide.

## Frame standard

| Part | Player label | Envelope (X, Y, Z) | Anchor |
|---|---|---|---|
| Cockpit | Cockpit | Tub ±1.75, -1.0..2.2, -8..3. Cabin (screen, halo, canopy, cage, head box) ±2.4, 2.2..4.6, -5.5..3 | Root |
| `Engine1` | Power Unit | ±2.0, 1.4..3.9, 3..13.2 | Top of `RearBody` |
| `Engine2` | Shoulder Jets | 2.4..4.6 both sides, 1.4..3.0, -3.6..4.5 | Top of `SidePods` |
| `Stabilisers` | Corner Thrusters | Front 4.0..7.5 both sides, -1.6..2.6, -10..-3.6. Front link 1.75..4.0, 0.2..1.9, -7.7..-5.3. Rear 4.0..7.5 both sides, -1.6..2.6, 4.6..11.5 | Tub side and `RearBody` side |
| `Boost` | Afterburner | ±3.4, 0.2..1.4, 12..14.6. Upper corners 2.0..3.4 both sides, 1.4..3.4, 12..14.6 | Rear face of `RearBody` |
| `FrontBody` | Nose | ±3.8, -0.5..2.2, -13.6..-8 | Front bulkhead of the tub |
| `RearBody` | Engine Deck | ±4.0, 0..1.4, 3..12. Haunch 2.0..4.0 both sides, 1.4..2.6, 5.4..9.6. Fender strip 2.8..4.0, 1.4..2.6, 9.6..12. Tail horns 3.4..5.0, 0..2.2, 12..14.6 | Rear bulkhead of the tub |
| `SidePods` | Sidepods | 1.75..4.6 both sides, -1.0..1.4, -3.6..3. Outer 4.6..6.4, -1.3..2.2. Shoulder 1.75..2.4, 1.4..2.2 | Tub side rail |
| `FrontBumper` | Front Wing | ±7.3, -1.5..-0.5, -14..-10.2. Endplates 3.9..7.3 both sides, -0.5..1.8 | Keel under `FrontBody` |
| `RearBumper` | Diffuser | ±4.0, -1.3..0, 6.5..12. Tail ±3.4, -1.3..0.2, 12..14.6. Corners 3.4..5.0, -1.3..0, 12..14.6 | Underside of `RearBody` |
| `RearSpoiler` | Rear Wing | ±6.6, 4.0..6.8, 9.6..14.6. Pylons 2.0..2.8 both sides, 1.4..4.0, 9.6..12. Top-wing zone ±5.2, 4.8..7.6, -3.5..9.6. End fins 5.0..6.6, -1.0..4.0, 11.6..14.6 | Wing pads on `RearBody` |

Envelopes do not overlap. The cabin box is the reserved driver head box. A future `Roof` slot would take it over; nothing else may enter it.

## Datums

| Datum | Value | What lines up on it |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Lowest hardware is a thruster nozzle at Y -1.6. |
| Sill | Y 0 | Tub and deck underside. Seam for the diffuser. |
| Beltline | Y 1.4 | Tub waist, sidepod top, engine deck top. Engines stand on it. |
| Rim | Y 2.2 | Cockpit rim. The cabin starts here. |
| Bulkheads | Z -8 and Z 3 | Nose seam and engine deck seam. |
| Deck end | Z 12 | Afterburner seam. |
| Tub side | X ±1.75 | Every side pad on the tub. |
| Stations | Z -6.5 and Z 8 | Front and rear wishbone stations. Rear hardpoint plane is X ±4.0. |

## Hardpoint pads

Every parent carries the same flat pads. Modules land on pads, never on body shape. A tub narrower than X ±1.75 reaches its pads on dark brackets or struts. Worst contact gap in the spec is 0.2 studs.

| Parent | Pad | What lands on it |
|---|---|---|
| Cockpit | Front bulkhead Z -8, X ±1.0, Y 0.2..1.6 | Nose collar |
| Cockpit | Rear bulkhead Z 3, X ±1.3, Y 0.2..1.6 | Engine deck collar |
| Cockpit | Wishbone plates X ±1.75, Y 0.35..1.75, Z -7.5..-5.5 | Front thruster arms |
| Cockpit | Sidepod rails X ±1.75, Y 0.2..1.25, Z -3.3..2.7 | Sidepods |
| `FrontBody` | Keel underside Y -0.5, X ±0.6, Z -11.4..-10.4 | Front wing pylon |
| `SidePods` | Shoulder pad top Y 1.4, X 2.6..4.2, Z -1.5..1.5 | Shoulder jet foot |
| `RearBody` | Engine mounts top Y 1.4, X ±1.1, Z 3.8..4.9 and 9.7..10.8 | Power unit feet |
| `RearBody` | Wing pads top Y 1.4, X 2.0..2.8, Z 10.1..11.5 | Rear wing feet |
| `RearBody` | Rear face Z 12, X ±1.5, Y 0.3..1.3 | Afterburner plate |
| `RearBody` | Rear hardpoints X ±4.0, Y 0.3..1.3, Z 7.2..8.8 | Rear thruster arms |
| `RearBody` | Underside Y 0.1, Z 7..11.8 | Diffuser |

## Where the four fundamentals sit, and why

| Slot | Where | Why |
|---|---|---|
| `Engine1` Power Unit | On the engine deck behind the driver, nozzle out of the back at Z 12 to 13 | This is where a circuit racer keeps its engine. It sits in the open above the beltline, so the chase camera sees the whole engine and its glow. |
| `Engine2` Shoulder Jets | A pair on top of the sidepods, beside the driver | Fills the sidepod tops, reads from the front three-quarter and from above, and keeps the two engines far apart. |
| `Stabilisers` Corner Thrusters | Four corners, outboard on wishbones, nozzles pointing down and back | They replace the round 1 outboard pods. Each is a slender nacelle along the car: open for formula kits, under an arch fairing for the prototype kit. |
| `Boost` Afterburner | On the deck rear face, under and beside the main nozzle | The last thing the chase camera sees. The upper corner boxes let cans and stacks stand up beside the engine nozzle. |

## Kits

| Kit | Culture | Native cockpit | Power Unit | Shoulder Jets | Corner Thrusters | Afterburner |
|---|---|---|---|---|---|---|
| Works | Formula | Formula (halo, low intake hoop, slim tub) | Works Turbine: one big barrel, square intake, long nozzle | Shoulder Turbines | Vector Pods | Twin Cans, high |
| Garagiste | Vintage Grand Prix | Cigar (round hull, open, tiny screen) | Stack Eight: block, eight trumpets, megaphones | Ram Bullets | Bullet Outriggers | Twin Megaphones, splayed |
| All-Nighter | Prototype | Prototype (wide closed canopy, fastback) | Twin Spool: two slim turbines and a fin | Slot Ducts | Arch Fairings | Slot Burner, full width |
| Ground Effect | Wing Car | Wingcar (driver far forward, tall periscope airbox) | Turbo Slot: turbo box, flat duct, slot nozzle | Turbo Stacks | Vane Cascades | Staged Triple |
| Dirt Outlaw | Speedway Sprint | Sprint (upright cage, tail tank) | Quad Cluster: four jets round a tall scoop | Twin Shorties | Stagger Stacks | Zoomie Stacks, upswept |

Body modules per kit, in the same order: noses Needle, Radiator Mouth, Shovel, Chisel, Grille Hood. Decks Coke Bottle, Tube Cradle, Long Tail, Tunnel Deck, Tank Tail. Sidepods Undercut, Pannier Tanks, Sponsons, Skirted, Nerf Bars. Front wings Cascade, Chin Blade, Splitter, Plank, Nerf Bumper. Diffusers Strake, Belly Pan, Long Extractor, Venturi, Push Bar. Rear wings High Downforce, High Strut, Low Drag Blade, Twin Plane Box, Sprint Top Wing.

## Authoring rules for real meshes

1. Author every part in cockpit-root space. Stay inside the slot envelope. Do not borrow space from a neighbour.
2. Keep every pad at its exact position and size, flat, on every cockpit and every parent module. Reach each pad with a dark `detail` foot, collar or bracket. Leave a 0.2 stud shadow gap.
3. Every tub ships the same four pads. Character goes in the cabin box, the tub width and the keel, never in the pad positions.
4. A nose must reach the front bulkhead and carry the keel pad. A deck must reach the rear bulkhead and carry both engine mounts, both wing pads, the afterburner face and both rear hardpoints, however slim the deck is.
5. Every fundamental shows an intake, a body and a nozzle with a `thrust` part. Keep it in the open. Do not cover the power unit with deck bodywork.
6. No wheel shapes. Round parts run along the car and are longer than wide. Cross tubes stay under 0.4 studs thick.
7. Rear thrusters start at X 4.0. Deck bodywork above the beltline stays inside X 4.0. Arch fairings belong to `Stabilisers`, not to the deck or sidepods.
8. The cockpit owns all glass and the roofline. No module enters the cabin box.
9. Two options for one slot must differ in outline: length, height, count or stance. Check with the validator, target 0.35 (0.25 for wings, diffusers and cockpits).
10. Give every part a paint channel so a mixed build reads as one car.

## Validator result

`SPEC apex: 0 error(s), 0 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 50, 'builds': 13, 'worst_gap': 0.2, 'min_distinctness': {'Engine1': 0.36, 'Engine2': 0.39, 'Stabilisers': 0.48, 'Boost': 0.43, 'FrontBody': 0.36, 'RearBody': 0.37, 'SidePods': 0.37, 'FrontBumper': 0.42, 'RearBumper': 0.27, 'RearSpoiler': 0.49, 'Cockpit': 0.25}, ...}` All 25 cockpit and kit pairs in the matrix were checked by eye after the last change.

## Open risks

- Cockpit distinctness is 0.25, right on the target. The shared tub and pads make every top view alike. The difference is carried by the cabin (halo, open hull, canopy, periscope airbox, cage). A real mesh that softens those will fall under the target.
- The contract lists a sixth cockpit, Oval. It is not built. It would need its own kit and a cabin that differs from Sprint.
- Engine decks all share one collar, one afterburner plate and the hardpoints, so their side views are close. They differ in plan and in what stands above the beltline. Coke Bottle is very slim: with wide sidepods from another kit there is a visible step at Z 3.
- Vane Cascades are not nacelles. They are a glowing burner sheet under vanes with a slot jet. They read as jets but are the least thruster-like option.
- Diffuser pairs Belly Pan and Push Bar, and Strake and Long Extractor, score 0.27: a pass, but the closest body options. Slim tubs (Formula, Cigar) show daylight between tub and sidepod on purpose; check it in game lighting.
