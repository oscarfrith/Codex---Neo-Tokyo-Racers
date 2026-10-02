# Apex frame standard (round 2 blockout, after the second review)

Status: design exploration, round 2, 2026-10-02. Not game content. Spec: [apex.json](../../../scripts/vehicle_blockouts/specs/apex.json), written by [gen/apex.py](../../../scripts/vehicle_blockouts/gen/apex.py). Previews: [mix A](../../../scripts/vehicle_blockouts/previews/apex/mix_a.png), [mix B](../../../scripts/vehicle_blockouts/previews/apex/mix_b.png), [matrix](../../../scripts/vehicle_blockouts/previews/apex/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/apex/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/apex/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/apex/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/apex/standard.png), one `row_<cockpit>.png` per cockpit. Circuit racers as hover jets. Root space: +X right, +Y up, forward is -Z, studs. "±" means centred on X. "Both sides" means mirrored. Built: 6 cockpits, 6 signature kits, 60 modules (6 per slot), 15 builds of 164 to 218 parts, 10.9 to 14.4 W x 6.2 to 7.7 H x 27.1 to 28.5 L. There are no wheels, rings, discs or drums. The spec has 146 cylinders. Each is at least as long as it is wide (least ratio 1.00). The generator refuses to write the spec otherwise.

## Frame standard

Envelopes do not overlap. The cabin box belongs to the cockpit. Each cockpit fills it with its own roofline, so it keeps its identity under any kit.

| Part | Player label | Envelope (X, Y, Z) | Anchor |
|---|---|---|---|
| Cockpit | Cockpit | Tub ±1.75, -1.0..2.2, -8..3. Cabin (screen, halo, canopy, cage, airbox, roof) ±2.4, 2.2..4.6, -7.5..3 | Root |
| `Engine1` | Power Unit | ±2.0, 1.4..3.9, 4.6..13.2. Over the deck shoulder ±2.0, 2.2..3.9, 3..4.6 | Top of `RearBody` |
| `Engine2` | Shoulder Jets | 2.4..4.6 both sides, 1.4..3.0, -3.6..4.5 | Top of `SidePods` |
| `Stabilisers` | Corner Thrusters | Front 4.0..7.5 both sides, -1.6..2.6, -10..-3.6. Front link 1.75..4.0, 0.2..1.9, -7.7..-3.6. Rear 4.0..7.5 both sides, -1.6..2.6, 4.6..11.5 | Tub side and `RearBody` side |
| `Boost` | Afterburner | ±3.4, 0.2..1.4, 12..14.6. Upper corners 2.0..3.4 both sides, 1.4..3.4, 12..14.6. Tail lances 2.0..3.4, 0.2..1.5, 14.6..16 | Rear face of `RearBody` |
| `FrontBody` | Nose | ±3.8, -0.5..2.2, -13.6..-8 | Front bulkhead of the tub |
| `RearBody` | Engine Deck | ±4.0, 0..1.4, 3..12. Shoulder ±2.0, 1.4..2.2, 3..4.6. Haunch 2.0..4.0 both sides, 1.4..2.6, 5.4..9.6. Fender strip 2.8..4.0, 1.4..2.6, 9.6..12. Tail horns 3.4..5.0, 0..2.2, 12..14.6 | Rear bulkhead of the tub |
| `SidePods` | Sidepods | 1.75..4.6 both sides, -1.0..1.4, -3.6..3. Outer 4.6..6.4, -1.3..2.2. Shoulder 1.75..2.4, 1.4..2.2 | Tub side rail |
| `FrontBumper` | Front Wing | ±7.3, -1.5..-0.5, -14..-10.2. Endplates 3.9..7.3 both sides, -0.5..1.8 | Keel under `FrontBody` |
| `RearBumper` | Diffuser | ±4.0, -1.3..0, 6.5..12. Tail ±3.4, -1.3..0.2, 12..14.6. Corners 3.4..5.0, -1.3..0, 12..14.6 | Underside of `RearBody` |
| `RearSpoiler` | Rear Wing | ±6.6, 4.0..6.8, 9.6..14.6. Pylons 2.0..2.8 both sides, 1.4..4.0, 9.6..12. Top-wing zone ±5.2, 4.8..7.6, -3.5..9.6. Front posts 2.0..2.4, 1.4..4.8, 4.6..5.4. Braces 2.0..2.4, 2.6..4.8, 5.4..9.6. End fins 5.0..6.6, -1.0..4.0, 11.6..14.6 | Wing pads on `RearBody` |

## Datums

| Datum | Value | What lines up on it |
|---|---|---|
| Hover plane | Y -2.0 | Ground. The lowest part is a front wing at Y -1.5. |
| Sill | Y 0 | Tub and deck underside. Seam for the diffuser. |
| Beltline | Y 1.4 | Tub waist, sidepod top, engine deck top. Engines stand on it. |
| Rim | Y 2.2 | Cockpit rim. The cabin starts here. |
| Bulkheads | Z -8 and Z 3 | Nose seam and engine deck seam. Section X ±1.75, Y 0..2.2 at both. |
| Deck end, tub side | Z 12, X ±1.75 | Afterburner seam. Every side pad on the tub. |
| Stations | Z -6.5 and Z 8 | Front and rear wishbone stations. Rear hardpoint plane is X ±4.0. |

## Hardpoint pads

Every parent carries the same flat pads. Modules land on pads, never on body shape. Worst contact gap in the spec is 0.1 studs.

| Parent | Pad | What lands on it |
|---|---|---|
| Cockpit | Front bulkhead Z -8, full section X ±1.75, Y 0..2.2 | Nose collar, then the nose shoulder at Z -8.25 |
| Cockpit | Rear bulkhead Z 3, full section X ±1.75, Y 0..2.2 | Deck collar, then the deck shoulder at Z 3.25 |
| Cockpit | Wishbone plates X ±1.75, Y 0.35..1.75, Z -7.5..-5.5 | Front thruster arms, arch bridge panel |
| Cockpit | Sidepod rails X ±1.75, Y 0.2..1.25, Z -3.3..2.7 | Sidepods |
| `FrontBody` | Keel underside Y -0.5, X ±0.6, Z -11.4..-10.4 | Front wing pylon |
| `SidePods` | Shoulder pad top Y 1.4, X 2.6..4.2, Z -1.5..1.5 | Shoulder jet foot |
| `RearBody` | Engine mounts top Y 1.4, X ±1.1, Z 4.8..5.9 and 9.7..10.8 | Power unit feet |
| `RearBody` | Wing pads top Y 1.4, X 2.0..2.8, Z 10.1..11.5 | Rear wing feet |
| `RearBody` | Frame pads top Y 1.4, X 2.0..2.4, Z 4.8..5.4 | Front posts of the Sprint Top Wing |
| `RearBody` | Rear face Z 12, X ±1.5, Y 0.3..1.3 | Afterburner plate |
| `RearBody` | Rear hardpoints X ±4.0, Y 0.3..1.3, Z 7.2..8.8, on a shelf Y 0.45..1.15, Z 6.4..9.6 | Rear thruster arms. The shelf fills the gap beside a slim deck |
| `RearBody` | Underside Y 0.1, Z 7..11.8 | Diffuser |

## Where the four fundamentals sit, and why

| Slot | Where | Why |
|---|---|---|
| `Engine1` Power Unit | On the engine deck behind the driver, nozzle out of the back at Z 12 to 13 | This is where a circuit racer keeps its engine. It stands in the open above the beltline, so the chase camera sees the engine and its glow. |
| `Engine2` Shoulder Jets | A pair on top of the sidepods, beside the driver | Reads from the front three-quarter and from above. Keeps the two engines far apart. Every option is 4 studs or more of jet hardware with its glow centred at Y 2.0 or higher. |
| `Stabilisers` Corner Thrusters | Four corners, outboard, nozzles pointing down and back | They replace the round 1 outboard pods. Every option shows a nose or intake, a body and a nozzle that points down and back, from the side. Arch Fairings hide that nozzle, so each arch top carries a glowing lift vent. |
| `Boost` Afterburner | On the deck rear face, under and beside the main nozzle | The last thing the chase camera sees. Each option has its own layout: high pair, long low pair, full-width slot, centre three, upswept stacks, splayed side exits. |

## Cockpits and kits

| Kit (culture) | Native cockpit: the cabin that survives a kit swap | Power Unit | Shoulder Jets | Corner Thrusters | Afterburner |
|---|---|---|---|---|---|
| Works (Formula) | Formula: wide halo, tall airbox to Y 4.6 on an engine-cover shoulder | Works Turbine: square plenum, big barrel, long nozzle | Shoulder Turbines: one long turbine a side | Vector Pods: slender nacelle, blade in the mouth | Twin Cans: fat pair, high and outboard |
| Garagiste (Vintage Grand Prix) | Cigar: round hull, coaming hump, wraparound screen, exposed driver, long tapered headrest | Stack Eight: block, eight trumpets, one megaphone | Ram Bullets: chrome, 1.3 across, bell intake | Bullet Outriggers: high bullets, lift nozzle under each | Twin Megaphones: one long low pipe a side, flaring in steps to a bell at Z 15.7 |
| All-Nighter (Prototype) | Prototype: closed bubble far forward, long fastback, dorsal fin, deep belly that rises to the sill at both ends | Twin Spool: two slim turbines and a fin | Slot Ducts: raised scoop, kicked-up slot nozzle | Arch Fairings: blanked arches, bridge panel to the tub, glowing lift vent in each arch top, scoop and canted nozzle below | Slot Burner, full width |
| Ground Effect (Wing Car) | Wingcar: driver far forward, periscope airbox behind the head, wide flat engine cover | Turbo Slot: turbo box, flat duct, slot nozzle | Turbo Stacks: horn, compressor drum, long nozzle | Vane Cascades: nacelle with scoop and nozzle over open vanes | Staged Triple |
| Dirt Outlaw (Speedway Sprint) | Sprint: upright cage to Y 4.6 with a roof plate, arm-guard boards, tall tail tank | Quad Cluster: four jets round a tall scoop | Twin Shorties: two short barrels a side, forward-set | Stagger Stacks: twin stack in front, over-and-under unit at the rear | Zoomie Stacks: three fat upswept stacks a side on a collector box |
| Stocker (Stock Oval) | Oval: tall boxy greenhouse wider than the tub, flat roof with a number panel | Big Bore: low cowl, one very fat nozzle | Side Dumps: rear-set, tall square scoop, big nozzle turned fully sideways | Triple Packs: three small tubes per corner | Lake Pipes: short side exits, splayed 35 degrees outboard |

Body modules per kit, in the same order: noses Needle, Radiator Mouth, Shovel, Chisel, Grille Hood, Bluff. Decks Coke Bottle, Tube Cradle, Long Tail, Tunnel Deck, Tank Tail, Trunk Deck. Sidepods Undercut, Pannier Tanks, Sponsons, Skirted, Nerf Bars, Door Slabs. Front wings Cascade, Chin Blade, Splitter, Plank, Nerf Bumper, Air Dam. Diffusers Strake, Belly Pan, Long Extractor, Venturi, Push Bar, Valance. Rear wings High Downforce, High Strut, Low Drag Blade, Twin Plane Box, Sprint Top Wing, Stand-Up Spoiler. Swap fixes from the second review: Sponsons are 6.2 out, with a chamfered front corner and a tail that tapers in plan to X 4.2. The Sprint Top Wing is a 7.0 x 5.4 slab over Z 0.4..5.8. It stands on front posts at Z 5 and on the wing pads, with a diagonal brace each side. The Cascade Wing sits back at Z -12.9..-11.3 with a painted centre section. The Nerf Bumper is a two-bar hoop 6.8 wide that reaches Z -13.85. Push Bar and Belly Pan each carry an upright painted or chrome element at the tail.

## Authoring rules for real meshes

1. Author every part in cockpit-root space. Stay inside the slot envelope. Do not borrow space from a neighbour.
2. Every cockpit reaches the full bulkhead section (X ±1.75, Y 0..2.2) at Z -8 and Z 3 and carries the four side pads. Character goes in the cabin box and the keel.
3. Every nose and deck starts at the full bulkhead section behind a dark collar, then tapers to its own width within about 2 studs. No step at the seam.
4. A nose carries the keel pad. A deck carries both engine mounts, both wing pads, both frame pads, the afterburner face and both rear hardpoints on their shelves, however slim it is.
5. Every fundamental shows an intake, a body and a nozzle with a `thrust` part, in the open. Nothing on a body module may imitate a jet (no round tanks with end caps).
6. No wheel shapes. Every round part is at least as long as it is wide. No oversize intake collars and no hub bosses: use a lip in the body colour, a dark recessed face and a blade or spike. Cross tubes stay under 0.4 studs thick.
7. Arch fairings belong to `Stabilisers`. They own the front link box as a solid bridge panel to the tub and run back to the sidepod front. The rear pair stand on the deck shelf. Nothing round sits under an arch.
8. The cockpit owns all glass and the roofline. No module enters the cabin box.
9. Two options for one slot must differ in outline: length, height, count or stance. Check with the validator, target 0.35 (0.25 for wings, diffusers and cockpits).
10. A wide module must not end in a square face beside a slim neighbour. Taper or chamfer the end that meets the next slot.
11. Give every part a paint channel so a mixed build reads as one car.

## Validator result

`SPEC apex: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 60, 'builds': 15, 'worst_gap': 0.1, 'min_distinctness': {'Engine1': 0.55, 'Engine2': 0.39, 'Stabilisers': 0.53, 'Boost': 0.4, 'FrontBody': 0.42, 'RearBody': 0.6, 'SidePods': 0.41, 'FrontBumper': 0.42, 'RearBumper': 0.33, 'RearSpoiler': 0.42, 'Cockpit': 0.46}, 'min_distinctness_whole': {'Engine1': 0.31, 'Engine2': 0.34, 'Stabilisers': 0.46, 'Boost': 0.35, 'FrontBody': 0.2, 'RearBody': 0.11, 'SidePods': 0.31, 'FrontBumper': 0.38, 'RearBumper': 0.24, 'RearSpoiler': 0.38, 'Cockpit': 0.16}, ...}` `min_distinctness` is the free outline: the area all options share is removed. `min_distinctness_whole` is the whole outline. The twelve all-random mixes and the 36 cockpit and kit pairs were checked by eye, front and rear.

## Open risks

- Whole-outline cockpit scores are 0.16 to 0.23, because every cockpit shares the full-section tub and pads. The free outline is 0.46 to 0.92. The closest pair is Wingcar and Oval (0.46). Noses and decks share the shoulder, collar, pads and now the hardpoint shelf, so their whole-outline scores are low (0.20 and 0.11). They differ in everything else (free 0.42 and 0.60).
- The hardpoint shelf is a dark slab up to 2.95 wide on Coke Bottle and Tank Tail. It closes the gap beside the rear Arch Fairings. It also shows under the other thrusters. A real mesh should shape it as a floor or stub wing.
- Builds are 6.2 to 7.7 tall against a 5.5 target. The cabin box tops out at Y 4.6, the rear wing must clear the power unit at Y 3.9, and front wings reach down to Y -1.5.
- The Sprint Top Wing overhangs its front posts by 4.6 studs. It covers the roll hoop and the engine intake, not the driver. Its front posts stand 0.05 inboard of the shoulder-jet zone, so check them against real jet exhaust. Side Dumps fire sideways at Z 3.75. The glow shows from the side and the three-quarter views, not from dead astern. Lake Pipes fire 35 degrees outboard. On Long Tail the plume passes over the low tip of the tail horns.
- The closest pairs are diffusers Strake and Long Extractor (0.33) and Strake and Valance (0.34), then Shoulder Turbines and Slot Ducts (0.39). Formula with the All-Nighter kit is 218 parts, just under the 220 warning.
