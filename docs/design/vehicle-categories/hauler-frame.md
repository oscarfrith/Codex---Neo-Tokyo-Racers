# Hauler: frame standard (round 2 blockout, after the second review)

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
| Boost, Stacks | Upright behind the cab, or low dumps beside it, or a pair on the bed tail corners | Truck exhaust stacks are the natural afterburner. The tail ports sit outboard of the Bed Engine column and differ from its nozzles in outline, height and colour, so engine and boost read as two parts |

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
| Cab seams, sill and lower body | Every cab | A body-colour lower body runs Z -5.8..2.8 on every cab, to Y 3.0 or higher. The Single Cab's pack carries stripe and belt back; the Kei Cab's tray stops at Y 3.0. Dark plates in the gaps. Sill at X 4.05, Y 0.5..0.9 | Front Clip, Bed, Side Gear |
| Roof and Extras pads | Every cab | Roof: body colour at Y 7.4, X ±3.3 or wider, Z -4.4..-2.4 or longer. Single Cab and Kei Cab carry a raised roof cap, X ±3.4, back to Z -1.6. No Roof Rig is wider than X ±3.6. Extras: cab side, Y 3.2..3.6, Z -5.0..-4.2 | Roof Rig, Extras |
| Hood pad | Every Front Clip | Y 3.6, X ±2.0, Z -12.2..-6.3. The Stub Nose carries it on to Z -13.8 with a dark hood shelf, X ±2.3 | Hood Engine cradle |
| Cowl deck | Every Front Clip | Flat at Y 3.6, X ±4.1, Z -10.4..-6.25 | Forward cab pods and nose sails stand on it. It also closes the step between a narrow clip and a wide cab |
| Front horns and nose face | Every Front Clip | Horns X 1.9..2.7 both sides, Y 0.55..1.25, face at Z -13.9. A face stands behind the bar on every clip: the Flare Nose has a skid face (X ±4.3, Y 1.4..2.5), the Stub Nose an apron tray (X ±3.4, Y 0.6..1.2, face at Z -13.85) | Front Bar |
| Deck pad | Every Bed | Y 2.0, X ±4.2, Z 3.35..13.85 | Bed Engine cradle |
| Shoulder pads | Every Bed | Y 3.0, X 4.4..5.4 both sides, Z 4.9..6.2 and Z 11.4..13.9 | Bed Rig feet. The rig is a portal over the bed |
| Rear horns and tail corners | Every Bed | Horns as the front, face at Z 13.9. Tail corner X 3.3..5.4, Y 2.0..3.0 at Z 13.9. Tail lamps above Y 3.5 or below Y 1.8. Every bed shows body colour at the tail: the Flatbed has painted wings, headboard hoop and tail sill | Rear Bar, flank-port Stacks |

## Cabs and kits

| Kit (culture) | Native cab | Hood Engine | Bed Engine | Lift Jets | Stacks | Front Clip, Bed |
|---|---|---|---|---|---|---|
| Dune Runner (Prerunner) | Single Cab: short chopped cab, then a body-colour pack at belt height with fuel cell, cans and roll hoop | Ram Single: one fat turbine, one big up-nozzle | Bed Turbine: one huge turbine | Long Travel: long pods on A-arms | Side Dumps: two fat cans a side, kicked outboard | Flare Nose, Chase Tub |
| Sky High (Lifted) | Crew Cab: long four-door, flat roof, upright rear, three side windows | Twin Ram: two turbines, tall scoop, two up-nozzles | Twin Barrels: two low, wide apart | Stilts: tall thruster legs | Shorty Stacks: four stepped | Square Body, Flatbed |
| Laid Out (Minitruck) | Kei Cab: tiny bubble cab, narrow above the belt, roof cap on a cab guard, drop-side tray with a load | Slot Scoop: flat burner under a 1.2 tall scoop, slot jets | Deck Burner: dark flat burner, bright turbine hump, raised full-width slot with a neon edge | Tucked Slots: flat pods under the body | Tail Slots: one flat duckbill a side, low on the tail corners, glow strip 2 wide | Smoothie, Laid Bed |
| Chrome Palace (Show Truck) | Cab-Over: twin pods either side of the open engine trench, sleeper behind | Six Pack: block 5 long, six barrels leaning up and out | Quad Chrome: four in a 2 x 2 block | Dually Vectors: twin tilted nozzles | Chrome Stacks: two tall stacks | Flat Face, Show Deck |
| Checker Line (Cab) | Checker Cab: three-box saloon, hat roof, low boot deck, checker belt | Trio: three turbines at the nose, three up-nozzles | Over-Under: two stacked | Jet Racks: vented housing, three nozzles 1.2 below it, side glow slot | Tail Cans: four round body-colour cans, two a side, high on the tail corners, the outer one longer | Round Nose, Fare Canopy |
| Last Mile (Courier) | Van Nose: one-box van, nose sails, big raked screen, high roof, blank sides | Doghouse: low cover by the cab, slim barrel out to a round nose intake, two up-nozzles in tandem | Tail Three: three side by side on the tail deck | Box Lifts: square lift ducts | Fishtails: riser pipes into flat fishtail blades | Stub Nose, Parcel Box |

Each kit also has its own Side Gear, Front Bar, Rear Bar, Bed Rig, Roof Rig and Extras. 6 cabs, 6 kits, 72 modules, 15 builds. The Parcel Box carries the cab roofline back at Y 7.0 to Z 9.6, then leaves an open tail deck so the Bed Engine shows. A barred hatch low in each box side (Y 2.7..4.3, Z 4.7..8.5) shows the engine from the front.

## Authoring rules for real meshes

1. Model every part in cab-root space, inside its slot envelope, 0.05 clear of each face. Do not move a part to make it fit one cab.
2. Land on the pad, never on a body shape. Leave a 0.2 to 0.3 gap and fill it with a dark linkage piece.
3. Every cab ships the same ladder frame, sill, seams and roof pad. The lower body runs the full cab length in body colour, so no cab leaves a notch ahead of the Bed. The roof under a Roof Rig is body colour at Y 7.4, never a narrow riser. Put the character above the belt: glass, roofline, pack.
4. A cab may stand forward only as two pods or sails on the cowl deck, X 2.2..4.2, back from Z -10.6. Nothing may roof or wall the engine trench (X ±2.0, Y 3.6..6.2) ahead of Z -6.8.
5. Every Front Clip keeps the hood pad, the cowl deck, the two horns and a face behind the Front Bar. A short clip fills the stand-off with a dark shelf and apron, so no Hood Engine or Front Bar hangs in space. Both sides of the Z -6 seam present the same section within 0.3. Below the belt and ahead of Z -10.4 the clip is free.
6. Every Bed keeps the deck at Y 2.0, the shoulder pads at Y 3.0, the horns, the tail corners and a tail face at Z 13.9. Walls, headboard, canopy and box are free. Leave the tail open so the Bed Engine shows. Body colour must reach the tail, so painted Rear Bars meet painted body.
7. Each fundamental shows an intake, a body and a glowing nozzle. A pod or nozzle is longer than it is wide. No rings, discs or drums. An engine cover must leave the turbine body and nozzles in view.
8. Every Hood Engine starts within 0.3 of Z -13.8 and ends in jets that fire up or outboard, with a thrust face at least 1.0 wide. No jet points at the screen.
9. Tail-mounted Stacks use the flank ports only. Nothing may sit behind the Bed Engine column (X ±3.2) above Y 1.8. They must not copy a Bed Engine nozzle row: use another outline, height and colour (a flat duckbill low, body-colour cans high).
10. One surface, one owner. The cab owns all glass. Arches and flares belong to the Front Clip or Bed, never to the Lift Jets. Keep the stripe band and the paint channels, so mixed kits read as one truck. An engine body uses a different channel from the deck it sits on.

## Validator result

`SPEC hauler: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 72, 'builds': 15, 'worst_gap': 0.27, 'min_distinctness': {'Engine1': 0.41, 'Engine2': 0.43, 'Stabilisers': 0.48, 'Boost': 0.49, 'FrontBody': 0.36, 'RearBody': 0.45, 'SidePods': 0.43, 'FrontBumper': 0.5, 'RearBumper': 0.6, 'RearSpoiler': 0.55, 'Roof': 0.56, 'Accessory': 0.58, 'Cockpit': 0.31}, 'min_distinctness_whole': {'Engine1': 0.26, 'Engine2': 0.29, 'Stabilisers': 0.42, 'Boost': 0.49, 'FrontBody': 0.13, 'RearBody': 0.15, 'SidePods': 0.39, 'FrontBumper': 0.39, 'RearBumper': 0.39, 'RearSpoiler': 0.51, 'Roof': 0.47, 'Accessory': 0.45, 'Cockpit': 0.07}, ...}`

No errors and no warnings. Worst contact gap is 0.27. No two envelopes overlap. Builds measure 12.4 to 13.8 W, 9.8 to 12.1 H, 30.1 to 31.8 L. The largest build has 218 parts (the limit is 220). The free-outline score (the area all options share is removed) meets every target: 0.35 for engines, lift jets, stacks, clips, beds, side gear and rigs, 0.25 for the rest and for cabs. The two lowest fell in this round: Front Clip 0.36 (was 0.39; the Stub Nose now has an apron) and Cab 0.31 (was 0.38; the Single Cab now has a full-length lower body). Stacks rose from 0.44 to 0.49. The whole-outline score is still under target for Hood Engine (0.26), Bed Engine (0.29), Front Clip (0.13), Bed (0.15) and Cab (0.07). That is the shared hull: every clip carries the same hood pad and cowl deck, every bed the same deck and shoulders, every cab the same frame and lower body.

## Open risks

1. Whole-outline scores for clips, beds and cabs stay low because the pads are shared. Raising them needs a looser hull, which would break the seams that make every swap fit.
2. Forward pods (Cab-Over) and nose sails (Van Nose) stand on the cowl deck. On Flare Nose, Smoothie and Round Nose that deck is a thin shelf with daylight under it. Real meshes need a clean underside there.
3. The Stub Nose body stops at Z -12.3. A dark porch (hood shelf, two uprights, apron tray) now carries Hood Engines and Front Bars ahead of it. The apron is X ±3.4, so the ends of wide bars still pass the cut-back nose corners. It was rendered only with Doghouse and Front Rack. The other pairings rest on measurement.
4. The roof pad is at Z -4.4..-2.6. On the Cab-Over that is the sleeper roof, 6 studs behind the pod screens, so a Light Bar reads as sleeper trim. The Doghouse cover also sits low between the Cab-Over pods: its barrel and nozzles show, its cover does not.
5. The Flatbed wings, Chase Tub flares and Show Deck fenders hide the rear Lift Jets from above. The Laid Bed shoulder drops to Y 2.6 between the two pads, so a Bed Rig brace that lands mid-bed leaves a 0.4 gap.
6. Paint can still flatten a build. With a near-black secondary (Checker Line paint) the Flatbed deck boards, a Deck Burner and a Top Box are all dark. The painted wings, hoop and sill frame them but do not lighten them. The Parcel Box hatch is see-through in a pure side view when the Bed Engine is low (Tail Three).
7. Builds are about 31 long and up to 12.1 tall with whip aerials and tall stacks, against a 30 x 13 x 9 target.
