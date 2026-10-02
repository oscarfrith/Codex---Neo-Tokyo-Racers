# Hauler: frame standard (round 2 blockout, after critic review)

Status: design exploration, round 2, 2026-10-02. Not approved, not game content. Spec: `scripts/vehicle_blockouts/specs/hauler.json`, written by `scripts/vehicle_blockouts/gen/hauler.py`. Previews: `scripts/vehicle_blockouts/previews/hauler/`. Class sheet: [hauler.md](hauler.md). Rules: [exploration contract](../../../scripts/vehicle_blockouts/CONTRACT.md). Root space: +X right, +Y up, forward is -Z, studs. "X ±4.4" means -4.4 to 4.4. "Both sides" means the box is mirrored across X. No wheels and nothing wheel-shaped: lift and thrust are jets.

## Frame standard

| Slot id | Player label | Envelope | Anchor (parent, seam) |
|---|---|---|---|
| Cockpit | Cab | Cab: X ±4.2, Y 0.4..7.6, Z -6..3. Forward pods, both sides: X 2.2..4.2, Y 3.6..7.6, Z -10.6..-6. Trench back wall: X ±2.2, Y 3.6..7.6, Z -6.8..-6. Ladder frame: X ±3.4, Y -0.8..0.4, Z -14..14 | Root |
| FrontBody | Front Clip | Core: X ±4.4, Y 0.4..3.6, Z -14..-6. Arches, both sides: X 4.4..6.8, Y 2.0..3.6, Z -14..-6 | Cab, Z -6 |
| RearBody | Bed | Floor: X ±4.4, Y 0.4..2.0, Z 3..14. Headboard: X ±4.4, Y 2.0..7.0, Z 3..4. Walls, both sides: X 3.2..4.4, Y 2.0..7.0, Z 4..14. Canopy: X ±3.2, Y 6.0..7.0, Z 4..14. Shoulders, both sides: X 4.4..6.8, Y 2.0..3.0, Z 4.8..14 | Cab, Z 3 |
| Engine1 | Hood Engine | X ±2.0, Y 3.6..6.2, Z -13.8..-6.8. An open trench: no cab may roof it | Front Clip hood pad, Y 3.6 |
| Engine2 | Bed Engine | X ±3.2, Y 2.0..6.0, Z 4..14 | Bed deck, Y 2.0 |
| Stabilisers | Lift Jets | Four corners. Low: X 3.4..7.0, Y -2.4..0.4. High: X 4.4..7.0, Y 0.4..2.0. Front Z -13.6..-7.4, rear Z 6.4..12.6 | Cab axle beams, X 3.4 |
| Boost | Stacks | Stack bay, both sides: X 4.4..6.6, Y -0.8..9.8, Z 3..4.8. Dump bay, both sides: X 4.4..6.6, Y -0.8..2.0, Z 4.8..6.2. Flank ports, both sides: X 3.3..5.6, Y 2.0..3.4, Z 14..16.2 | Bed front corner, Z 3, or bed tail corner, Z 14 |
| SidePods | Side Gear | Both sides: X 4.2..6.6, Y -0.8..2.0, Z -5.8..2.8 | Cab sill, X 4.2 |
| FrontBumper | Front Bar | X ±6.8, Y -0.8..4.6, Z -16..-14 | Front Clip horns, Z -14 |
| RearBumper | Rear Bar | X ±6.8, Y -0.8..1.8, Z 14..16 | Bed horns, Z 14 |
| RearSpoiler | Bed Rig | Legs, both sides: X 4.4..5.4, Y 3.0..9.2, Z 4.8..14. Overhead: X ±4.4, Y 7.2..9.2, Z 4.8..14 | Bed shoulder pads, Y 3.0 |
| Roof | Roof Rig | X ±4.2, Y 7.6..9.6, Z -6..3 | Cab roof pad, Y 7.4 |
| Accessory | Extras | Both sides: X 4.2..5.8, Y 2.0..9.8, Z -5.8..2.8 | Cab side, X 4.2 |

## Where the four fundamentals sit, and why

| Slot | Where | Why |
|---|---|---|
| Engine1, Hood Engine | On top of the hood, full length, in an open trench up to Y 6.2. Jets fire up or outboard near Z -9 | A truck has a long flat hood. Nothing covers the engine on any cab. Up-turned nozzles stand above the hood, clear of the screen, so they read from the front, from above and over the cab from behind |
| Engine2, Bed Engine | Lying in the bed, nozzle at the tail | The bed is the biggest open space on the vehicle. The engine can be large and it faces the chase camera. Nothing sits behind its nozzle |
| Stabilisers, Lift Jets | Four corners, on the ends of the two axle beams, nozzles down | They stand where wheels would. They read from the front three-quarter. Reach sets ride height: Stilts reach Y -2.4, Tucked Slots stop at Y -1.4 |
| Boost, Stacks | Upright behind the cab, or low dumps beside it, or a pair on the bed tail corners | Truck exhaust stacks are the natural afterburner. The tail ports sit outboard of the Bed Engine column, so engine and boost read as two parts |

## Datums

| Datum | Value | What lines up on it |
|---|---|---|
| Hover plane | Y -2.5 | Ground. Lift jet glow stops at Y -2.4. Only Lift Jets go below Y -0.8 |
| Sill | Y 0.4 | Frame top. Body undersides start at Y 0.5 |
| Deck | Y 2.0 | Bed deck, arch underside, Side Gear top, Lift Jet top |
| Stripe | Y 2.9..3.3 | Accent band on cabs, clips and beds |
| Beltline | Y 3.6 | Hood top, cowl deck, cab belt, floor of a forward cab pod |
| Roof | Y 7.4 | Roof pad on every cab |
| Axles | Z -10.5 and 9.5 | Lift Jet centres, arches, flares |

## Hardpoint pads

| Pad | Carried by | Position | Takes |
|---|---|---|---|
| Ladder frame | Every cab, identical | Rails X 1.95..2.65 both sides, Y -0.15..0.35, Z -11.4..10.4. Axle beams end at X ±3.35, Y -0.2 | Lift Jets on the beam ends |
| Cab seams and sill | Every cab | Lower cab ends at Z -5.8 and 2.8, dark plates in the gaps. Sill at X 4.05, Y 0.5..0.9, Z -5.8..2.8 | Front Clip, Bed, Side Gear |
| Roof and Extras pads | Every cab | Roof: Y 7.4, X ±2.4, Z -4.4..-2.6. Extras: cab side, Y 3.2..3.6, Z -5.0..-4.2 | Roof Rig, Extras |
| Hood pad | Every Front Clip | Y 3.6, X ±2.0, Z -12.2..-6.3 | Hood Engine cradle |
| Cowl deck | Every Front Clip | Flat at Y 3.6, X ±4.1, Z -10.4..-6.25 | Forward cab pods and nose sails stand on it. It also closes the step between a narrow clip and a wide cab |
| Front horns | Every Front Clip | X 1.9..2.7 both sides, Y 0.55..1.25, face at Z -13.9 | Front Bar |
| Deck pad | Every Bed | Y 2.0, X ±4.2, Z 3.35..13.85 | Bed Engine cradle |
| Shoulder pads | Every Bed | Y 3.0, X 4.4..5.4 both sides, Z 4.9..6.2 and Z 11.4..13.9 | Bed Rig feet. The rig is a portal over the bed |
| Rear horns and tail corners | Every Bed | Horns as the front, face at Z 13.9. Tail corner X 3.3..5.4, Y 2.0..3.0 at Z 13.9. Tail lamps above Y 3.5 or below Y 1.8 | Rear Bar, flank-port Stacks |

## Cabs and kits

| Kit (culture) | Native cab | Hood Engine | Bed Engine | Lift Jets | Stacks | Front Clip, Bed |
|---|---|---|---|---|---|---|
| Dune Runner (Prerunner) | Single Cab: short chopped cab, open pack and roll hoop behind | Ram Single: one fat turbine, one big up-nozzle | Bed Turbine: one huge turbine | Long Travel: long pods on A-arms | Side Dumps: two fat cans a side, kicked outboard | Flare Nose, Chase Tub |
| Sky High (Lifted) | Crew Cab: long four-door, flat roof, upright rear, three side windows | Twin Ram: two turbines, tall scoop, two up-nozzles | Twin Barrels: two low, wide apart | Stilts: tall thruster legs | Shorty Stacks: four stepped | Square Body, Flatbed |
| Laid Out (Minitruck) | Kei Cab: tiny bubble cab, narrow above the belt, drop-side tray with a load | Slot Scoop: flat burner under a 1.2 tall scoop, slot jets | Deck Burner: flat burner, turbine hump, raised full-width slot | Tucked Slots: flat pods under the body | Tail Slots: two upright slot burners on the tail corners | Smoothie, Laid Bed |
| Chrome Palace (Show Truck) | Cab-Over: twin pods either side of the open engine trench, sleeper behind | Six Pack: block 5 long, six barrels leaning up and out | Quad Chrome: four in a 2 x 2 block | Dually Vectors: twin tilted nozzles | Chrome Stacks: two tall stacks | Flat Face, Show Deck |
| Checker Line (Cab) | Checker Cab: three-box saloon, hat roof, low boot deck, checker belt | Trio: three turbines at the nose, three up-nozzles | Over-Under: two stacked | Jet Racks: vented housing, three nozzles 1.2 below it, side glow slot | Tail Cans: two cans in square shrouds on the tail corners | Round Nose, Fare Canopy |
| Last Mile (Courier) | Van Nose: one-box van, nose sails, big raked screen, high roof, blank sides | Doghouse: tall engine cover by the cab, lid vent jets | Tail Three: three side by side on the tail deck | Box Lifts: square lift ducts | Fishtails: riser pipes into flat fishtail blades | Stub Nose, Parcel Box |

Each kit also has its own Side Gear, Front Bar, Rear Bar, Bed Rig, Roof Rig and Extras. 6 cabs, 6 kits, 72 modules, 15 builds. The Parcel Box carries the cab roofline back at Y 7.0 to Z 9.6, then leaves an open tail deck so the Bed Engine shows.

## Authoring rules for real meshes

1. Model every part in cab-root space, inside its slot envelope, 0.05 clear of each face. Do not move a part to make it fit one cab.
2. Land on the pad, never on a body shape. Leave a 0.2 to 0.3 gap and fill it with a dark linkage piece.
3. Every cab ships the same ladder frame, sill, seams and roof pad. Put the character above the belt: glass, roofline, pack.
4. A cab may stand forward only as two pods or sails on the cowl deck, X 2.2..4.2, back from Z -10.6. Nothing may roof or wall the engine trench (X ±2.0, Y 3.6..6.2) ahead of Z -6.8.
5. Every Front Clip keeps the hood pad, the cowl deck and the two horns. Both sides of the Z -6 seam present the same section within 0.3. Below the belt and ahead of Z -10.4 the clip is free.
6. Every Bed keeps the deck at Y 2.0, the shoulder pads at Y 3.0, the horns, the tail corners and a tail face at Z 13.9. Walls, headboard, canopy and box are free. Leave the tail open so the Bed Engine shows.
7. Each fundamental shows an intake, a body and a glowing nozzle. A pod or nozzle is longer than it is wide. No rings, discs or drums.
8. Every Hood Engine starts within 0.3 of Z -13.8 and ends in jets that fire up or outboard, with a thrust face at least 1.0 wide. No jet points at the screen.
9. Tail-mounted Stacks use the flank ports only. Nothing may sit behind the Bed Engine column (X ±3.2) above Y 1.8.
10. One surface, one owner. The cab owns all glass. Arches and flares belong to the Front Clip or Bed, never to the Lift Jets. Keep the stripe band and the paint channels, so mixed kits read as one truck.

## Validator result

`SPEC hauler: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 72, 'builds': 15, 'worst_gap': 0.27, 'min_distinctness': {'Engine1': 0.4, 'Engine2': 0.45, 'Stabilisers': 0.48, 'Boost': 0.44, 'FrontBody': 0.39, 'RearBody': 0.43, 'SidePods': 0.43, 'FrontBumper': 0.5, 'RearBumper': 0.6, 'RearSpoiler': 0.55, 'Roof': 0.56, 'Accessory': 0.58, 'Cockpit': 0.38}, 'min_distinctness_whole': {'Engine1': 0.26, 'Engine2': 0.31, 'Stabilisers': 0.42, 'Boost': 0.44, 'FrontBody': 0.14, 'RearBody': 0.14, 'SidePods': 0.39, 'FrontBumper': 0.38, 'RearBumper': 0.39, 'RearSpoiler': 0.51, 'Roof': 0.47, 'Accessory': 0.45, 'Cockpit': 0.07}, ...}`

No errors and no warnings. Worst contact gap is 0.27. No two envelopes overlap. Builds measure 12.4 to 13.8 W, 9.8 to 12.1 H, 30.1 to 31.8 L. The free-outline score (the area all options share is removed) meets every target: 0.35 for engines, lift jets, stacks, clips, beds, side gear and rigs, 0.25 for the rest and for cabs. The whole-outline score is still under target for Hood Engine (0.26), Bed Engine (0.31), Front Clip (0.14), Bed (0.14) and Cab (0.07). That is the shared hull: every clip carries the same hood pad and cowl deck, every bed the same deck and shoulders, every cab the same frame and lower body.

## Open risks

1. Whole-outline scores for clips, beds and cabs stay low because the pads are shared. Raising them needs a looser hull, which would break the seams that make every swap fit.
2. Forward pods (Cab-Over) and nose sails (Van Nose) stand on the cowl deck. On Flare Nose, Smoothie and Round Nose that deck is a thin shelf with daylight under it. Real meshes need a clean underside there.
3. The Stub Nose stops at Z -12.3. Hood Engine intakes and the Front Bar stand about 1.5 ahead of it on frame prongs. It reads as a van, but each engine needs checking on it.
4. The roof pad is at Z -4.4..-2.6. On the Cab-Over that is the sleeper roof, 6 studs behind the pod screens, so a Light Bar reads as sleeper trim.
5. The Flatbed wings, Chase Tub flares and Show Deck fenders hide the rear Lift Jets from above. The Laid Bed shoulder drops to Y 2.6 between the two pads, so a Bed Rig brace that lands mid-bed leaves a 0.4 gap.
6. Builds are about 31 long and up to 12.1 tall with whip aerials and tall stacks, against a 30 x 13 x 9 target.
