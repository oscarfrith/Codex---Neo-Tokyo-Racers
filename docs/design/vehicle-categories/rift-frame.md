# Rift frame standard

Status: design exploration, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [rift.json](../../../scripts/vehicle_blockouts/specs/rift.json). Previews: [sheet](../../../scripts/vehicle_blockouts/previews/rift/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/rift/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rift/standard.png).

Rift is a classic coupé cut into floating sections. A centre spine (nose, cabin, tail) carries three floating bodies per side: front nacelle, mid section, rear-quarter pod. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Envelopes

| Slot | Player label | X | Y | Z | Anchors to |
|---|---|---|---|---|---|
| Cockpit | Cabin | -3.8..3.8 | 0..5.4 | -4.5..5.5 | root |
| Engine1 | Front Half | -8.5..8.5 | -0.6..3.6 | -16.5..-4.5 | cockpit front, Z -4.5 |
| Engine2 | Rear Half | -8.5..8.5 | -0.6..3.6 | 5.5..14.5 | cockpit rear, Z 5.5 |
| SidePods | Mid Section | 3.8..8.5, mirrored | -0.6..3.4 | -4.5..5.5 | cockpit flank, X ±3.8 |
| Stabilisers | Hover Fins | A: -3.8..3.8; B: -8.5..8.5 | A: -0.6..0; B: -1.7..-0.6 | A: -4.5..5.5; B: -16.5..14.5 | cockpit floor, Y 0 |
| Boost | Afterburner | -3.0..3.0 | 1.2..3.6 | 14.5..17.5 | Rear Half tail panel, Z 14.5 |
| FrontBumper | Front Bumper | -8.5..8.5 | -1.3..3.6 | -18.0..-16.5 | Front Half nacelle tips, Z -16.5 |
| RearBumper | Rear Bumper | A: -8.5..8.5; B: 3.0..8.5, mirrored | A: -1.3..1.2; B: 1.2..3.6 | 14.5..16.5 | Rear Half, Z 14.5 |
| RearSpoiler | Spoiler | -8.5..8.5 | 3.6..7.4 | 5.5..17.0 | Rear Half deck, Y 3.6 |
| Hood | Hood | -2.8..2.8 | 3.6..5.0 | -9.0..-4.5 | Front Half deck, Y 3.6 |
| Roof | Roof | -3.8..3.8 | 5.4..6.8 | -4.5..5.5 | cockpit roof, Y 5.4 |

A and B are two boxes of one envelope. No two envelopes overlap. Accessory is not used. Built size: 16.2 to 16.6 wide, 35.0 to 35.5 long, 7.0 high (8.9 with the GT Wing).

## Datums

| Datum | Y | Meaning |
|---|---|---|
| Hover plane | -2.0 | Ground. Nothing goes below -1.7. |
| Sill | 0.4 | Bottom edge of painted body. Below it: dark detail and hover gear only. |
| Stripe line | 1.9 | Centre of the belt stripe on the cabin and on every outboard body. |
| Beltline | 2.8 | Window sill. Default shoulder of nacelles, mid sections and quarter pods. |
| Deck | 3.4 | Bonnet and boot surface. Cowl and rear deck of every cockpit. |
| Roof pad | 5.3 | Top of every cockpit. |

## Pads and hardpoints

Envelopes stop clipping. Pads stop holes and floating parts. The owner must fill its pad. The user must sit on it.

| Pad | Owner | Where | Used by |
|---|---|---|---|
| Bulkhead collars | Cockpit | dark, X ±3.0, Y 0.7..3.1, at Z -4.5 and Z 5.5 | Front Half, Rear Half |
| Side hardpoints | Cockpit | X ±3.8, Y 0.8..1.8, at Z -2.6 and Z 3.2 | Mid Section |
| Floor | Cockpit | Y 0, X ±3.5, Z -4.2..5.2 | Hover Fins |
| Roof pad | Cockpit | top at Y 5.3, X ±2.6, header line Z -1.0 and hoop line Z 1.6 | Roof |
| Hood pad | Front Half | top at Y 3.4, X ±2.4, Z -8.6..-4.8 | Hood |
| Front bumper hardpoints | Front Half | X ±6.3, Y 0.9, Z -16.5 | Front Bumper |
| Spoiler pad | Rear Half | top at Y 3.4, X ±2.4, Z 5.8..14.2 | Spoiler |
| Boost pad | Rear Half | tail panel at Z 14.2..14.4, X ±2.0, Y 1.4..3.0 | Afterburner |
| Rear bumper hardpoints | Rear Half | X ±6.3, Y 0.9, Z 14.2 | Rear Bumper |

## Seam rules

1. Painted surfaces stop 0.3 short of every seam plane, on both sides. The shadow gap is 0.6. Only dark `detail` parts touch the plane: collars, linkage blocks, brackets, struts.
2. A module touches its parent only at the pad or hardpoints in the table above.
3. Hood, Spoiler and Roof modules rest on their pad. They may overhang it by up to 1 stud. Wing blades may span wider above it.
4. Front Bumper parts outboard of X ±4 stay below Y 1.1. This keeps the headlight window (Y 1.1..2.8) clear.
5. Hover units under nacelles and quarter pods stay above Y -0.6. The slab below that belongs to Hover Fins.

## Authoring rules for real meshes

- Author every mesh in cockpit root space. Never fit a module to one cockpit by eye. Keep every vertex inside the slot envelope, including rotated and curved parts. Keep pads flat and at the datum. Sculpt everything else.
- Every Front Half has two nacelles at X 4.5..8.1 that reach Z -16.2 and carry the headlights. It also has a centre nose with the hood pad. The nose may end anywhere from Z -10 to Z -16. A short nose gives the catamaran notch.
- Keep at least 1 stud of dark gap between centre nose and nacelle, and between tail and quarter pod. Bridge it with two struts per side.
- Every Rear Half has two quarter pods that reach Z 14.2 and a centre tail that carries the spoiler pad and the boost pad.
- Every cockpit ends at the deck datum front and rear: cowl at Z -4.2, rear deck at Z 5.2. Higher is allowed (Stiletto engine deck is 4.4). Lower is not.
- Open cockpits still supply the roof pad: a screen header at Z -1.0 and braced hoops at Z 1.6, both at Y 5.3. Roof modules span from header line to hoop line and are at least 2.4 wide, so on a roadster they become a soft top.
- Put the belt stripe at Y 1.9 on the outer face of every outboard body. Shared paint and one stripe line make mixed kits read as one car. Each module carries its own lights and hover glow.
- Seat a 5-stud avatar: floor at 0.4, head top near 4.6, inner roof at 5.0, cabin 7.2 wide.

## What the blockout showed

- 4 cockpits: Brawler (fastback), Outlaw (notchback), Stiletto (wedge, high engine deck), Mamba (roadster). 37 modules: 4 Front Half, 4 Rear Half, 4 Mid Section, 3 Hover Fins, 3 Afterburner, 4 Front Bumper, 3 Rear Bumper, 4 Spoiler, 4 Hood, 4 Roof.
- 8 builds of 126 to 143 parts. Builds 1 to 3: Muscle kit on three cockpits. Builds 4 to 6: Outlaw with Wedge Exotic, Euro GT and Pro Street kits. Builds 7 and 8: mixed.
- Every module passes the envelope and seam checks alone, so every combination passes. A separate scratch check found every pad filled on all cockpits and modules. Four extra odd mixes were rendered and inspected.
- Main lesson: envelopes alone are not enough. The first pass had zero errors but had a floating ground plate, a bumper with no bracket and a tail with no bumper hardpoint. Named pads fixed all three.

Validator: `SPEC rift: 0 error(s), 1 warning(s) {'cockpits': 4, 'modules': 37, 'builds': 8, 'parts_in_builds': 1088}`
Warning left: `cockpit brawler appears in fewer than 2 builds`. Eight builds in the required 3 + 3 + 2 pattern cannot show four cockpits twice each.

## Open risks

- The validator does not know about pads, gap widths or strut counts. A module can pass and still float. Add pads to the spec schema and check them.
- The cabin is small against the car: 7.6 of 16.6 wide, 10 of 35 long. In a 3/4 view the cockpits read less differently than the front halves do.
- 35 long is 1 stud over the brief. 16.6 wide needs checking against lanes, garage bay and camera.
- The hood pad is only 3.8 long and the roof pad 2.6 long, so Hood and Roof modules are small. Longer pads would rule out the wedge nose and the short Stiletto roof.
- Three legal mixes look poor: Roof Scoop or Louvres on Mamba bridge open air; Light Bar crosses the Turbine Quarters exhausts; Ducktail and Louvre Deck overhang the narrow Boat Tail stern by up to 0.9 stud. Accept, or filter by tag.
- The Afterburner envelope is low (Y 1.2..3.6). Upswept stacks are not possible, so Twin Stack is two large horizontal barrels.
- Untested: one-sided modules (all parts are mirrored), the Nightshift and Regent cockpits, and Shark Nose.
