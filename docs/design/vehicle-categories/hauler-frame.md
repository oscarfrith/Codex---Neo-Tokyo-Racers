# Hauler: frame standard (round 2 blockout)

Status: design exploration, round 2, 2026-10-01. Not approved, not game content. Spec: `scripts/vehicle_blockouts/specs/hauler.json`, written by `scripts/vehicle_blockouts/gen/hauler.py`. Previews: `scripts/vehicle_blockouts/previews/hauler/`. Class sheet: [hauler.md](hauler.md). Rules: [exploration contract](../../../scripts/vehicle_blockouts/CONTRACT.md). Root space: +X right, +Y up, forward is -Z, studs. "X ±4.4" means -4.4 to 4.4. "Both sides" means the box is mirrored across X. No wheels and nothing wheel-shaped: lift and thrust are jets.

## Frame standard

| Slot id | Player label | Envelope | Anchor (parent, seam) |
|---|---|---|---|
| Cockpit | Cab | Cab: X ±4.2, Y 0.4..7.6, Z -6..3. Forward cheeks, both sides: X 2.2..4.2, Y 3.6..7.6, Z -13.6..-6. Forward brow: X ±2.2, Y 5.4..7.6, Z -13.6..-6. Ladder frame: X ±3.4, Y -0.8..0.4, Z -14..14 | Root |
| FrontBody | Front Clip | Core: X ±4.4, Y 0.4..3.6, Z -14..-6. Arches, both sides: X 4.4..6.8, Y 2.0..3.6, Z -14..-6 | Cab, Z -6 |
| RearBody | Bed | Floor: X ±4.4, Y 0.4..2.0, Z 3..14. Headboard: X ±4.4, Y 2.0..7.0, Z 3..4. Walls, both sides: X 3.2..4.4, Y 2.0..7.0, Z 4..14. Canopy: X ±3.2, Y 6.0..7.0, Z 4..14. Shoulders, both sides: X 4.4..6.8, Y 2.0..3.0, Z 4.8..14 | Cab, Z 3 |
| Engine1 | Hood Engine | X ±2.0, Y 3.6..5.4, Z -13.8..-6.8 | Front Clip hood pad, Y 3.6 |
| Engine2 | Bed Engine | X ±3.2, Y 2.0..6.0, Z 4..14 | Bed deck, Y 2.0 |
| Stabilisers | Lift Jets | Four corners. Low: X 3.4..7.0, Y -2.4..0.4. High: X 4.4..7.0, Y 0.4..2.0. Front Z -13.6..-7.4, rear Z 6.4..12.6 | Cab axle beams, X 3.4 |
| Boost | Stacks | Stack bay, both sides: X 4.4..6.6, Y -0.8..9.8, Z 3..4.8. Dump bay, both sides: X 4.4..6.6, Y -0.8..2.0, Z 4.8..6.2. Tail port: X ±3.2, Y 2.0..3.4, Z 14..16.2 | Bed front corner, Z 3, or bed tail, Z 14 |
| SidePods | Side Gear | Both sides: X 4.2..6.6, Y -0.8..2.0, Z -5.8..2.8 | Cab sill, X 4.2 |
| FrontBumper | Front Bar | X ±6.8, Y -0.8..4.6, Z -16..-14 | Front Clip horns, Z -14 |
| RearBumper | Rear Bar | X ±6.8, Y -0.8..1.8, Z 14..16 | Bed horns, Z 14 |
| RearSpoiler | Bed Rig | Legs, both sides: X 4.4..5.4, Y 3.0..9.2, Z 4.8..14. Overhead: X ±4.4, Y 7.2..9.2, Z 4.8..14 | Bed shoulder pads, Y 3.0 |
| Roof | Roof Rig | X ±4.2, Y 7.6..9.6, Z -6..3 | Cab roof pad, Y 7.4 |
| Accessory | Extras | Both sides: X 4.2..5.8, Y 2.0..9.8, Z -5.8..2.8 | Cab side, X 4.2 |

## Where the four fundamentals sit, and why

| Slot | Where | Why |
|---|---|---|
| Engine1, Hood Engine | On top of the hood, full length, in the open | A truck has a long flat hood. The engine reads from the front and from above. On the Kei Cab and Cab-Over it runs through a tunnel in the cab and its intake is the grille |
| Engine2, Bed Engine | Lying in the bed, nozzle at the tail | The bed is the biggest open space on the vehicle. The engine can be large and it faces the chase camera |
| Stabilisers, Lift Jets | Four corners, on the ends of the two axle beams, nozzles down | They stand where wheels would. They read from the front three-quarter. Reach sets ride height: Stilts high, Tucked Slots low |
| Boost, Stacks | Upright behind the cab, or low dumps beside it, or a burner on the bed tail | Truck exhaust stacks are the natural afterburner. All three places face the chase camera |

## Datums

| Datum | Value | What lines up on it |
|---|---|---|
| Hover plane | Y -2.5 | Ground. Lift jet glow stops at Y -2.4. Only Lift Jets go below Y -0.8 |
| Sill | Y 0.4 | Frame top. Body undersides start at Y 0.5 |
| Deck | Y 2.0 | Bed deck, arch underside, Side Gear top, Lift Jet top |
| Stripe | Y 2.9..3.3 | Accent band on cabs, clips and beds |
| Beltline | Y 3.6 | Hood top, cab belt, floor of an overhanging cab |
| Roof | Y 7.4 | Roof pad on every cab |
| Axles | Z -10.5 and 9.5 | Lift Jet centres, arches, flares |

## Hardpoint pads

| Pad | Carried by | Position | Takes |
|---|---|---|---|
| Ladder frame | Every cab, identical | Rails X 1.95..2.65 both sides, Y -0.15..0.35, Z -11.4..10.4. Axle beams end at X ±3.35, Y -0.2 | Lift Jets on the beam ends |
| Cab seams and sill | Every cab | Lower cab ends at Z -5.8 and 2.8, dark plates in the gaps. Sill at X 4.05, Y 0.5..0.9, Z -5.8..2.8 | Front Clip, Bed, Side Gear |
| Roof and Extras pads | Every cab | Roof: Y 7.4, X ±2.4, Z -4.4..-2.6. Extras: cab side, Y 3.2..3.6, Z -5.0..-4.2 | Roof Rig, Extras |
| Hood pad | Every Front Clip | Y 3.6, X ±2.0, Z -12.2..-6.3 | Hood Engine cradle |
| Front horns | Every Front Clip | X 1.9..2.7 both sides, Y 0.55..1.25, face at Z -13.9 | Front Bar |
| Deck pad | Every Bed | Y 2.0, X ±4.2, Z 3.35..13.85 | Bed Engine cradle |
| Shoulder pads | Every Bed | Y 3.0, X 4.4..5.4 both sides, Z 4.9..6.2 and Z 11.4..13.0 | Bed Rig feet. The rig is a portal over the bed |
| Rear horns and tail face | Every Bed | Horns as the front, face at Z 13.9. Tail face at Z 13.9 | Rear Bar, tail-mounted Stacks |

## Kits

| Kit | Culture | Native cab | Hood Engine | Bed Engine | Lift Jets | Stacks | Front Clip, Bed |
|---|---|---|---|---|---|---|---|
| Dune Runner | Prerunner | Single Cab | Ram Single: one long turbine | Bed Turbine: one huge turbine | Long Travel: long pods on A-arms | Side Dumps: two cans a side | Flare Nose, Chase Tub |
| Sky High | Lifted | Crew Cab | Twin Ram: two turbines and a scoop | Twin Barrels: two low, wide apart | Stilts: tall thruster legs | Shorty Stacks: four stepped | Square Body, Flatbed |
| Laid Out | Minitruck | Kei Cab | Slot Scoop: flat slot burner | Deck Burner: flat, full-width slot | Tucked Slots: flat pods under the body | Tail Slot: one wide burner | Smoothie, Laid Bed |
| Chrome Palace | Show Truck | Cab-Over | Six Pack: six small jets in a block | Quad Chrome: four in a 2 x 2 block | Dually Vectors: twin tilted nozzles | Chrome Stacks: two tall stacks | Flat Face, Show Deck |
| Checker Line | Cab | Checker Cab | Trio: arrowhead of three | Over-Under: two stacked | Spats: blanked arches, jet rows | Tail Cans: two round cans | Round Nose, Fare Canopy |

Each kit also has its own Side Gear, Front Bar, Rear Bar, Bed Rig, Roof Rig and Extras. 60 modules in all. The Flat Face is a true slab to Z -13.7, so the Cab-Over gets a flat face that reaches the same seams.

## Authoring rules for real meshes

1. Model every part in cab-root space, inside its slot envelope, 0.05 clear of each face. Do not move a part to make it fit one cab.
2. Land on the pad, never on a body shape. Leave a 0.2 to 0.3 gap and fill it with a dark linkage piece.
3. Every cab ships the same ladder frame, sill, seams and roof pad. Put the character above the belt: glass, roofline, pack.
4. A cab may hang forward over the hood only inside the cheeks and brow. It must leave the engine tunnel (X ±2.0, Y 3.6..5.4) open.
5. Every Front Clip keeps the hood pad at Y 3.6 and the two horns. Below that it is free: chin height, wing height, width and flares may change.
6. Every Bed keeps the deck at Y 2.0, the shoulder pads at Y 3.0, the horns and a tail face at Z 13.9. Walls, headboard and canopy are free. Leave the bed open at the tail so the Bed Engine shows.
7. Each fundamental shows an intake, a body and a glowing nozzle. A pod or nozzle is longer than it is wide. No rings, discs or drums.
8. Every Hood Engine starts within 0.3 of Z -13.8, so the Cab-Over tunnel always has a grille.
9. One surface, one owner. The cab owns all glass. Arches and flares belong to the Front Clip or Bed, never to the Lift Jets. Keep the stripe band and the paint channels, so mixed kits read as one truck.

## Validator result

`SPEC hauler: 0 error(s), 25 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 60, 'builds': 13, 'worst_gap': 0.25, 'min_distinctness': {'Engine1': 0.39, 'Engine2': 0.36, 'Stabilisers': 0.48, 'Boost': 0.45, 'FrontBody': 0.21, 'RearBody': 0.26, 'SidePods': 0.4, 'FrontBumper': 0.37, 'RearBumper': 0.36, 'RearSpoiler': 0.53, 'Roof': 0.49, 'Accessory': 0.44, 'Cockpit': 0.07}, ...}`

All 25 warnings are look-alike scores. There are no fit, seam, contact or disc warnings. Worst contact gap is 0.25. No two envelopes overlap. Builds measure 12.4 to 13.5 W, 30.1 to 31.7 L, Y -2.4 to 9.7.

| Group | Pairs under target | Range | Why it is left |
|---|---|---|---|
| Front Clip | 8 of 10 | 0.21..0.32 (target 0.35) | Every clip must fill the same hull to reach the cab, the hood pad and the horns. Round 2 start was 0.07. Lowest pair: Smoothie and Flat Face |
| Bed | 9 of 10 | 0.26..0.33 (target 0.35) | Every bed shares the deck and shoulder pads, so the plan view is the same. Round 2 start was 0.18 |
| Cab | 8 of 10 | 0.07..0.25 (target 0.25) | The score includes the shared ladder frame and lower cab, which rule 3 makes identical. Rooflines and glass do differ |

## Open risks

1. Front Clip, Bed and Cab scores sit under target. Reaching it needs a looser hull: clips of different lengths, beds without the shared shoulder, or a cab-specific lower body, which would break the Side Gear seam.
2. The Cab-Over and Kei Cab overhang the Front Clip. On the low clips (Smoothie, Flare Nose, Round Nose) there is open space under the overhang. It reads as a cab-over, but real meshes need a clean cab underside. The Smoothie is 6.4 wide to match the Kei Cab. On the Crew Cab and Cab-Over it leaves a 0.9 step each side.
3. Hood Engines exhaust towards the windscreen, and into the tunnel on the Cab-Over. Real meshes should turn the nozzles out or up.
4. The Flatbed wings, Chase Tub flares and Show Deck fenders hide the rear Lift Jets from above. The Laid Bed shoulder drops to Y 2.6 between the two pads. A Bed Rig brace that lands mid-bed leaves a 0.5 gap there.
5. Five cabs are built. The Van Nose from the brief is not. Builds are 31 long and up to 12.1 tall with whip aerials, against a 30 x 13 x 9 target.
