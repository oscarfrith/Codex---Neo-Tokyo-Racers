# Dart frame standard (round 2)

Status: design exploration, round 2, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [dart.json](../../../scripts/vehicle_blockouts/specs/dart.json), written by [gen/dart.py](../../../scripts/vehicle_blockouts/gen/dart.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/dart/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/dart/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/dart/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/dart/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/dart/standard.png).

Dart is one slender fuselage on the centreline. A prow bolts to its front collar and a main drive to its rear collar. Wings and wing engines hang off the flanks. Afterburner, airbrakes, tail fins and keel hang off the main drive. There are no wheels, rings, discs or rotors: every round part is a jet or pod longer than it is wide. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Anchors to |
|---|---|---|---|---|---|
| Cockpit | Fuselage | -3..3 | -0.6..3 | -8..8 | root |
| Cockpit (canopy zone) | | -2.2..2.2 | 3..5 | -7..3.5 | |
| `FrontBody` | Prow | -5..5 | -0.6..2.8 | -15..-8 | fuselage prow collar, Z -8 |
| `FrontBumper` | Nose Tip | -5..5 | -0.6..2.8 | -17..-15 | prow nose collar, Z -15 |
| `SidePods` | Wings | 3..8, mirrored | -1.6..1.7 | -8..8 | fuselage flank hardpoints, X ±3 |
| `Engine2` | Wing Engines | 3..5.8, mirrored | 1.7..4.2 | -1..8 | fuselage rear hardpoint plate, X ±3 |
| `Engine1` | Main Drive | -3..3 | -0.4..3.2 | 8..14.5 | fuselage drive collar, Z 8 |
| `Engine1` (scoop zone) | | -2.4..2.4 | 3.2..4.6 | 8..10.2 | |
| `Boost` | Afterburner | -2.4..2.4 | 3.2..5.2 | 10.2..16.5 | drive burner deck, Y 3.2 |
| `Stabilisers` | Airbrakes | 3..8, mirrored | -0.6..3.3 | 8..15.5 | drive hardpoint posts, X ±3 |
| `RearSpoiler` | Tail Fins | 2.4..6, mirrored | 3.3..7.4 | 8..16.5 | drive fin pads, Y 3.3 |
| `RearSpoiler` (centre span) | | -2.4..2.4 | 5.2..7.4 | 8..16.5 | |
| `RearBumper` | Keel | -2..2 | -1.8..-0.4 | 8..17 | drive belly pad, Y -0.4 |

No two envelopes overlap. `RearBody`, `Hood`, `Roof` and `Accessory` are not used. Built size: 12.7 to 15.9 wide, 31.6 to 34.0 long, 6.7 to 8.6 high. Every build is inside 34 L x 16 W.

## The four fundamentals

| Slot | Where | Why |
|---|---|---|
| `Engine1` Main Drive | Behind the fuselage, Z 8 to 14.5, on the thrust axis | The biggest nozzle on the vehicle, dead astern, full in the chase camera. |
| `Engine2` Wing Engines | A mirrored pair on the fuselage shoulders, above the wing roots | Clear of the wings and the canopy, so they read from the front, the side and above. |
| `Stabilisers` Airbrakes | A mirrored pair on the flanks of the main drive | Widest point at the tail. Brake surfaces and control jets read from above and from the front three-quarter. |
| `Boost` Afterburner | On the burner deck on top of the main drive | Highest jet on the tail, above the main nozzle, never hidden by the keel or the wings. |

Every option has a dark intake, a body and a glowing `thrust` nozzle. The control jets sit outboard of the brake surfaces so they show.

## Datums

| Datum | Value | Meaning |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing built goes below -1.8. |
| Sill | Y 0.0 | Underside of the painted hull. |
| Thrust axis and beltline | Y 1.3 | Centre of both collars, the prow and the wing roots. |
| Deck | Y 3.0 | Top of every hull. Only canopy and glass go above it. |
| Drive top | Y 3.2 | Top of every main drive: burner deck and fin pads. |

## Hardpoint pads

Modules land on these pads and nowhere else. Every parent ships all of its pads in the same place.

| Parent | Pad | X | Y | Z | Carries |
|---|---|---|---|---|---|
| Fuselage | Prow collar | -1.1..1.1 | 0.35..2.25 | -8..-7.6 | Prow |
| Fuselage | Drive collar | -1.1..1.1 | 0.35..2.25 | 7.6..8 | Main Drive |
| Fuselage | Front wing hardpoint | 2.7..3, both sides | 0.65..1.35 | -2.8..-1.2 | Wings (root rib) |
| Fuselage | Rear hardpoint plate | 2.7..3, both sides | 0.65..2.7 | 3.6..6.4 | Wings below, Wing Engines above |
| Prow | Nose collar | -0.45..0.45 | 0.85..1.75 | -15..-14.6 | Nose Tip |
| Main Drive | Burner deck | -1.2..1.2 | 3.0..3.2 | 10.8..12.4 | Afterburner |
| Main Drive | Hardpoint posts | 2.75..3, both sides | 1.3..3.2 | 11..12.2 | Airbrakes |
| Main Drive | Fin pads | 2.4..3, both sides | 3.0..3.2 | 11..12.2 | Tail Fins |
| Main Drive | Belly pad | -0.8..0.8 | -0.4..-0.15 | 9.5..12.5 | Keel |

## Signature kits

| Kit | Culture | Native cockpit | Main Drive | Wing Engines | Airbrakes | Afterburner |
|---|---|---|---|---|---|---|
| Record | Record Breaker | Needle (round tube, long flush canopy) | Mono Turbine: one big turbine, dorsal scoop | Lance Ramjets: thin, full length | Petal Slabs: one tall slab, jet on its tail | Stinger: one long thin burner |
| Works | Works Team | Delta (faceted wedge, tall wedge screen) | Twin Drive: two big barrels on a Y yoke | Shoulder Turbines: one round nacelle | Clamshell: two flaps round a jet | Twin Cans |
| Prototype | Prototype | Manta (wide head, horns, tapering tail) | Slot Burner: flat fishtail | Slot Ramjets: flat boxes | Vane Cascade: three louvres, tip lift jet | Slot Afterburner: flat and wide |
| Privateer | Privateer | Twinboom (upright greenhouse, two booms) | Quad Cluster: four small jets, short | Stacked Pair: two small jets, over and under | Outrigger Jets: boom, boxed lift jet, vane | Staged Bell: three growing stages |
| Salvage | Salvage | Bubble (glass dome on a bare keel beam) | Rack Triple: three jets stepped on a ladder | Scoop Burners: square scoop, thin tailpipe | Drag Paddles: square paddle, bottle jet | Rocket Bottles: two each side |

Body modules per kit, in the same order: prow Spear, Twin Prong, Trident, Hammerhead, Spade; wings Stub, Delta, Forward Swept, Pontoons, Plank; nose tip Pitot, Canards, Sensor Blade, Ram Scoop, Bash Bar; keel Tail Stinger, Keel Fin, Diffuser, Drogue Pods, Skid; tail fins Strakes, Twin Fins, Box Wing, V-Tail, Plank Spoiler.

## Authoring rules for real meshes

1. Author every part in cockpit-root space. Keep every vertex inside its slot envelope. Do not borrow space from a neighbour. Keep the whole build inside 34 L x 16 W and above Y -1.8.
2. Ship the pads exactly as listed: same position, same size, flat faces, dark `detail` material. Never move a pad to suit a shape.
3. Land on the pad, not on a body. A module's mating part matches the pad face and stops within 0.1 studs of it. The gap is the shadow gap.
4. Both seams are single collars on the centreline at Y 1.3. A fuselage may be any shape between the collars but must reach both, and must carry all four flank pads on struts if its hull is narrow.
5. Glass, pilot and roofline belong to the fuselage. Nothing else rises into the canopy zone.
6. Every main drive carries all five of its pads, even when its jets are small. The posts, deck and belly pad are what make the airbrakes, afterburner, fins and keel interchange.
7. Jets only. No rings, hoops, discs, rotors or drums. Any round body is at least 1.5 times as long as it is wide. Each fundamental shows an intake, a body and a `thrust` nozzle from outside.
8. Two options for one slot differ in outline: count, length, height or stance. Check with the validator, not by eye.
9. Give every part a paint channel. Pads and linkage are `detail`; jets glow on `thrust`; lights are `neon`.

## Validator result

`SPEC dart: 0 error(s), 0 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 45, 'builds': 12, 'worst_gap': 0.1, 'min_distinctness': {'Engine1': 0.36, 'Engine2': 0.4, 'Stabilisers': 0.46, 'Boost': 0.37, 'FrontBody': 0.38, 'SidePods': 0.35, 'FrontBumper': 0.38, 'RearBumper': 0.36, 'RearSpoiler': 0.56, 'Cockpit': 0.27}}` (build sizes omitted). All targets are met: 0.35 or more for the big slots, 0.25 or more for the rest and for cockpits.

## Open risks

- Five cockpits, not six. Arrowhead from the brief is not built. It would need a sixth kit of nine modules.
- Cockpit distinctness is 0.27. The hull is only 6 studs wide, so fuselages differ mostly in canopy and plan taper. Needle and Delta are the closest pair.
- The main drive envelope is small (6 x 3.6 x 6.5). Engine1 scores sit just over target (0.36). Quad Cluster and Rack Triple are small next to the Mono Turbine. Wings at 0.35 are on the line: Forward Swept is close to Delta and Plank.
- The tail is a stack: keel, drive, afterburner and fins all hang off one drive module on one collar. A real mesh needs a strong visual spine there or it looks skeletal from the side.
- Pontoons, hammerhead pods and lift jets are long tubes at the corners. They are longer than wide, but concept art must keep them slender so they never read as wheels.
- Nothing is tested in Studio. Live slots mount at the cockpit root, which this standard assumes.
