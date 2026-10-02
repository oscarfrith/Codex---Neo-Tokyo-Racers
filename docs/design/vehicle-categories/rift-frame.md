# Rift frame standard (round 2)

Status: design exploration, round 2, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [rift.json](../../../scripts/vehicle_blockouts/specs/rift.json), written by [gen/rift.py](../../../scripts/vehicle_blockouts/gen/rift.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/rift/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/rift/fundamentals.png), [exploded](../../../scripts/vehicle_blockouts/previews/rift/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rift/standard.png).

Rift is a classic coupé cut into floating sections. A centre spine (nose, cabin, tail) carries a front nacelle, a rocker and a rear-quarter pod on each side. Round 2 has no wheels or wheel-like parts. Engines, stabilisers and boost are separate jet modules. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Anchor |
|---|---|---|---|---|---|
| Cockpit | Cabin | -3.8..3.8 | 0..6.6 | -5.5..6.5 | root |
| FrontBody | Front Clip | nose -4.0..4.0; nacelles 4.0..8.5, mirrored | nose 0..4.6; nacelles 0.8..3.6 | -16.5..-5.5 | cabin front seam, Z -5.5 |
| RearBody | Rear Clip | tail -4.0..4.0; pods 4.0..8.5, mirrored | tail 0..3.6; pods -0.8..4.6 | tail 6.5..14.0; pods 6.5..11.5 | cabin rear seam, Z 6.5 |
| SidePods | Rockers | 3.8..6.4, mirrored | 0..2.6 | -5.5..6.5 | cabin flank, X 3.8 |
| Engine1 | Front Engines | 4.0..8.5, mirrored | -1.7..0.8 | -18.0..-5.5 | underside of the nacelle, Y 0.8 |
| Engine2 | Rear Engines | 4.0..8.5, mirrored | -0.8..3.6 | 11.5..17.5 | pod bulkhead, Z 11.5 |
| Stabilisers | Stabilisers | A -9.0..9.0; B 6.4..9.0, mirrored | A -1.7..0; B 0..3.6 | -5.5..6.5 | cabin floor, Y 0 |
| Boost | Afterburner | -4.0..4.0 | 0.8..4.6 | 14.0..17.5 | tail panel, Z 14.0 |
| FrontBumper | Front Bumper | A -8.5..8.5; B -4.0..4.0 | A 0.8..3.6; B -1.2..0.8 | -18.0..-16.5 | nacelle tips, Z -16.5 |
| RearBumper | Rear Bumper | -4.0..4.0 | -1.2..0.8 | 14.0..17.0 | tail panel, Z 14.0 |
| RearSpoiler | Spoiler | A -4.0..4.0; B -8.5..8.5 | A 3.6..4.6; B 4.6..7.6 | A 6.5..14.0; B 6.5..17.5 | spoiler pad, Y 3.6 |

No two envelopes overlap. Hood, Roof and Accessory are not used. Built size: 16.7 to 17.6 wide, 34.9 to 35.1 long, 6.3 to 8.8 high.

## Where the four fundamentals sit

| Slot | Position | Why |
|---|---|---|
| Engine1, Front Engines | Slung under each nacelle on a pylon. Intake at or ahead of the nacelle tip, nozzle beside the front of the cabin. | The nacelle shell stays a clean body shape. The engine shows from the front, the side and below the beltline. |
| Engine2, Rear Engines | Behind each rear-quarter pod, bolted to its bulkhead, nozzles out the back to Z 17.5. | The chase camera sees both nozzles either side of the tail. |
| Stabilisers | On a mount plate under the cabin floor, with outriggers into the open bay between nacelle and pod. | The bay is empty in every kit, so lift jets show from the front three-quarter and from above. |
| Boost, Afterburner | Centre tail, on the tail panel between the rear engines. | It is the middle of the chase view and never hidden by a spoiler. |

## Datums

| Datum | Value | Meaning |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing goes below Y -1.7. |
| Sill | Y 0.4 | Bottom edge of painted body on the spine. |
| Pod floor | Y 0.8 | Underside of every nacelle. Ceiling of the front engines. |
| Stripe | Y 1.9 | Centre of the belt stripe and of the rift struts. |
| Beltline | Y 2.8 | Window sill and default shoulder. |
| Deck | Y 3.4 | Cowl, bonnet and boot surface at the seams. |
| Seams | Z -5.5 and 6.5 | Cabin to Front Clip, cabin to Rear Clip. Painted body stops 0.3 short. |
| Bulkhead, tail panel | Z 11.5, Z 14.0 | Rear engine seam, afterburner and rear bumper seam. |

## Hardpoint pads

| Parent | Pad | Place |
|---|---|---|
| Every cockpit (shared chassis) | Floor pan | X ±1.4, Y 0..0.4, Z -4.2..5.2 |
| | Coupler flanges | X ±2.2, Y 0.5..2.6, on Z -5.5 and Z 6.5 |
| | Side hardpoints | X 2.0..3.8, Y 0.9..1.7, Z -3.2..-2.2 and 2.6..3.6 |
| Every Front Clip | Rear collar | X ±2.2, Y 0.5..2.6, Z -5.8..-5.5 |
| | Engine pad | X 5.2..7.2, Y 0.8..1.0, Z -13.5..-9.5 |
| | Bumper hardpoint | X 5.6..6.8, Y 1.05..1.5, Z -16.5..-16.2 |
| Every Rear Clip | Front collar | X ±2.2, Y 0.5..2.6, Z 6.5..6.8 |
| | Tail panel | X ±2.4, Y 0.4..3.2, Z 13.7..14.0. Afterburner above Y 1.0, bumper below. |
| | Spoiler pad | X ±2.0, Y 3.4..3.6, Z 11.0..13.5 |
| | Engine bulkhead | X 5.3..7.1, Y 1.0..2.6, Z 11.2..11.5 |

## Kits

| Kit | Culture | Native cockpit | Front Engines | Rear Engines | Stabilisers | Afterburner | Clips, front and rear |
|---|---|---|---|---|---|---|---|
| Boulevard | Muscle | Brawler, 70s fastback: wide, tall, one slope to the tail | Ram Turbine: one turbine, square chin scoop | Thunder Twins: two long slim cans | Outrigger Cans: four upright lift cans | Quad Cannon: four in a row | Twin Longhorn, Fastback Quarters |
| Quarter Mile | Pro Street | Outlaw, 60s notchback: narrow, upright, tallest | Zoomie Rails: two wide-set tubes with stacks | Big Bertha: one huge short turbine | Strake Rails: one long rail, three nozzles | Big Bell: one bell nozzle | Blower Rail, Tubbed |
| Folded Edge | Wedge Exotic | Stiletto, 70s wedge: narrow arrowhead, high rear deck, fins | Slot Ramjet: flat slab, slot nozzle | Vector Slab: low vectoring slot | Canard Vanes: swept vanes, tip jets | Slot Burner: full-width slot | Pop-Up Prongs, Kamm Tail |
| Riviera | Roadster | Mamba, open roadster: twin aero screens, boat tail | Quad Cluster: four small jets | Bullet: one tapered bullet | Float Pods: one round pod, keel jet | Megaphones: two flared, swept up | Grand Quad, Boat Tail |
| Night Shift | Turbo Pony | Nightshift, 80s T-top: widest cabin, lowest roof | Turbo Cassette: box, twin barrels, side dump | Over-Under: two stacked cans | Fin Stacks: tall fin, jet at its foot | Tri-Stack: three stacked cans | Flip Nose, Slab Hatch |

## Authoring rules for real meshes

1. Stay inside the slot envelope. Leave 0.05 clear at every envelope face.
2. Carry every pad in the table at its exact place, flat and in the detail channel. Children land on pads only, never on a body shape.
3. Stop painted bodywork 0.3 short of each seam plane. The gap is the shadow gap. Only dark pads and struts cross it.
4. Every cockpit uses the same chassis. Put character in the cabin above it. The cockpit owns all glass and the roofline.
5. No clip rises above the deck (Y 3.4) at a seam. Keep each nacelle underside flat at Y 0.8 over the engine pad, and reach the tip at Z -16.5.
6. Only the rear-quarter pods may use Y -0.8..4.6. A spoiler wider than X ±4.0 stays above Y 4.6.
7. Every fundamental shows an intake, a body and a glowing nozzle from outside. Barrels are longer than they are wide. No rings, discs, drums or tyre shapes.
8. Join floating sections with dark struts. Do not let a body shape bridge a rift. Give every part a paint channel and keep the belt stripe at Y 1.9.
9. A new option must differ in outline from every other option in its slot: length, height, count or plan shape.

## Validator result

`SPEC rift: 0 error(s), 2 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 50, 'builds': 13, 'worst_gap': 0.05, ...}`

Lowest distinctness per slot: Engine1 0.41, Engine2 0.36, Stabilisers 0.40, Boost 0.42, FrontBody 0.35, RearBody 0.35, SidePods 0.36, FrontBumper 0.47, RearBumper 0.37, RearSpoiler 0.59, Cockpit 0.21. Every module slot meets its target. Warnings left: Brawler and Stiletto score 0.22, Mamba and Nightshift score 0.21 (target 0.25). The other eight cockpit pairs pass. The shared chassis and the shared sill, beltline and deck fill most of each cabin's outline, so the score only sees the top two studs.

## Open risks

- Cockpit scores sit close to the target. A sixth cockpit (Regent, grand tourer) would need a new roofline and its own kit.
- The brief suggested stabiliser jets at the nacelle tips. They are not there: the tips carry the bumper hardpoint and the engine intakes.
- Narrow cabins (Outlaw 2.7, Mamba 2.6 half width) leave a gap of about 1.2 to the Rockers, bridged by two brackets. The house gap is 0.6.
- Mamba between the wide Flip Nose and Slab Hatch has a narrow waist in plan. It fits but is the weakest matrix cell. Its scuttle is 0.4 below a full bonnet.
- Tubbed, Kamm Tail and Slab Hatch sit below the deck behind tall cabins. This reads as a planned step.
- Front engines hang under the nacelles. They show well from the front and side but only partly from the chase camera.
- Fastback Quarters and Kamm Tail use the taller pod band (to Y 4.6). A future wide, low spoiler would collide with it.
- `FrontBody` and `RearBody` are new slot IDs. The live game has eight slots. Quad Cluster is 44 primitives; a real mesh should merge them.
