# Street: frame standard (round 2, after critic fixes)

Status: design exploration, round 2, 2026-10-01. Not approved, not game content. Spec: [street.json](../../../scripts/vehicle_blockouts/specs/street.json), written by [gen/street.py](../../../scripts/vehicle_blockouts/gen/street.py). Previews: `scripts/vehicle_blockouts/previews/street/`. Brief: [contract](../../../scripts/vehicle_blockouts/CONTRACT.md).

Tuner and import cars on jets. No wheels, rotors, discs or rings anywhere. One compact body: a cabin, a front clip and a rear clip. The body is 20.8 long (Z -10.4 to 10.4) and 7.9 to 11.2 wide by clip. Arch jets reach X 6.1, so every build is 12.0 to 12.2 wide. Blockout content: 5 cockpits, 5 signature kits, 50 modules (5 per slot), 15 builds. Root space: +X right, +Y up, forward is -Z, studs. Boxes read `X; Y; Z`. `±` spans both sides. "Each side" means one box per side.

## Frame standard

| Slot id | Player label | Envelope | Anchor (seam) |
|---|---|---|---|
| Cockpit | Cabin | Door section ±4.0; 0.2..3.0; -3.0..3.4. Greenhouse ±4.0; 3.0..6.4; -5.6..4.9. Buttress zones 2.5..4.0 each side; 3.0..6.4; 4.9..9.0. Open-frame zone ±2.5; 4.4..6.4; 4.9..9.0 | Root |
| `FrontBody` | Front Clip | Collar ±4.0; 0.2..3.0; -4.8..-3.0. Cowl ±5.6; 2.6..3.0; -5.8..-4.8. Subframe ±2.7; 0.2..2.6; -8.2..-4.8. Fenders ±5.6; 1.6..2.6; -8.2..-4.8. Nose ±5.6; 0.2..2.6; -10.4..-8.2. Overhang ±5.6; 1.2..2.6; -11.8..-10.4. Fender crowns 2.6..5.6 each side; 2.6..3.9; -11.8..-5.8. Nose top ±2.6; 2.6..3.9; -11.8..-9.6 | Cockpit at Z -3.0 |
| `RearBody` | Rear Clip | Collar ±4.0; 0.2..3.0; 3.4..4.9. Bay floor ±2.7; 0.2..0.85; 4.9..8.6. Quarters 2.4..5.6 each side; 1.6..3.0; 4.9..8.3. Bay wall 2.4..2.7 each side; 0.2..1.6; 4.9..8.3. Tail corners 2.4..5.6 each side; 0.2..3.0; 8.3..10.4. Valance ±5.6; 0.2..0.85; 8.3..10.4. Haunch tops 4.0..5.6 each side; 3.0..3.9; 3.4..9.1 | Cockpit at Z 3.4 |
| `Engine1` | Bonnet Engine | ±2.5; 2.6..4.4; -9.6..-6.4 | Front Clip bonnet pad at Y 2.6 |
| `Engine2` | Tail Engine | In the bay ±2.4; 0.85..3.0; 4.9..11.2. Proud of the deck ±2.4; 3.0..4.3; 4.9..9.15 | Rear Clip bay pad at Y 0.8 |
| `Stabilisers` | Arch Jets | 2.7..6.1 each side; -1.7..1.6; -8.2..-4.8 (front pair) and 4.9..8.3 (rear pair) | Arch inner wall at X 2.7, on both clips |
| `Boost` | Exhaust Burner | Low band ±5.6; 0.2..0.85; 10.5..12.8. Corners 2.6..5.6 each side; 0.85..3.0; 10.5..12.8. Stacks 2.6..5.6 each side; 3.0..6.0; 11.7..12.8 | Rear Clip tail face at Z 10.4 |
| `SidePods` | Side Kit | Flank 4.0..5.8 each side; -1.3..3.0; -4.8..4.9. Flap pocket 2.7..5.8 each side; -1.3..0.2; 8.3..8.6 | Cockpit door face at X 4.0 |
| `FrontBumper` | Front Lip | Under ±5.8; -1.3..0.2; -12.2..-8.2. Face layer ±5.8; 0.2..1.2; -12.2..-10.4 | Front Clip underside at Y 0.2 and chin at Z -10.4 |
| `RearBumper` | Diffuser | ±5.6; -1.3..0.2; 8.6..12.0 | Rear Clip underside at Y 0.2 |
| `RearSpoiler` | Wing | ±5.8; 3.0..7.4; 9.2..11.6 | Rear Clip deck pad at Y 3.0 |

No two envelopes overlap. `Hood`, `Roof` and `Accessory` are not used: the bonnet belongs to the bonnet engine and the cockpit owns the roofline.

## Cockpits

Every cabin has the same door section. Only the greenhouse changes. No solid roof or centre glass passes Z 4.9, so the tail bay is open on all five. The `kei` id is kept, but the name is now Roadster: a tiny car cannot read as tiny on the shared 20.8 body.

| Id | Name | Shape | Greenhouse |
|---|---|---|---|
| `touge` | Touge | 90s coupé | 6.0 wide, top Y 4.6 (crown 4.8). Raked screen Z -4.6..-1.5, short roof, rear glass to Z 4.85, low sail fairings along the boot deck |
| `pocket` | Pocket | Hot hatch | 7.2 wide, top Y 5.9. Steep screen Z -4.8..-3.2, roof ends at Z 3.0, thick C-pillar, steep hatch glass, two buttresses down to Z 6.0, roof visor |
| `syndicate` | Syndicate | Sports saloon | 6.6 wide, top Y 5.25. Screen Z -4.2..-2.0, formal C-pillar, notch rear screen to Z 4.7 |
| `kei` | Roadster | Open targa roadster | Full-width framed screen (7.2 wide, top Y 4.6), short side glass, full-width targa hoop to Y 4.75, two buttresses at X 2.7..3.85 down to Z 8.9 |
| `estate` | Estate | Wagon | 6.3 wide, top Y 5.05 (rails 5.35). Set-back screen, solid roof to Z 4.85. Over the bay the roofline is an open frame: side rails, load-bay side glass, D-pillars, rear hoop, roof rails |

## The four fundamentals

- **Engine1, Bonnet Engine.** Stands on a dark pad in the bonnet. Every option ends at Z -6.45, so the Pocket screen is 1.6 clear. Outlets face sideways or up and out over the fenders, 0.8 across. None fires at the screen.
- **Engine2, Tail Engine.** Lies in the open bay. Each option has an intake that stands above the deck (scoops, airbox, ram hood, tower), a body, and a round nozzle in the rear panel. The Tail Letterbox has a slot nozzle 0.6 proud.
- **Stabilisers, Arch Jets.** Four units, one in each blanked arch. Each has an intake at the front and a nozzle at the back. Each has a thrust part outboard of X 5.6, so it shows in plan past the widest fender.
- **Boost, Exhaust Burner.** Its own shape language: square cans with a flared square petal, 2.2 to 2.4 behind the tail face. Bamboo Stacks are the exception: tall pipes that lean back.

Lowest free-outline scores (whole outline in brackets): Engine1 0.43 (0.26), Engine2 0.39 (0.31), Stabilisers 0.48 (0.41), Boost 0.59 (0.45). Target 0.35.

## Signature kits

| Kit | Native cockpit | Engine1 | Engine2 | Stabilisers | Boost |
|---|---|---|---|---|---|
| Touge | Touge | Twin Cam: two slim turbines, side exits | Twin Turbine: two turbines under twin deck scoops | Vector Pods: round pod, nozzle down and back, vane with a tip jet | Twin Tips: one 1.0 square burner each side |
| Kanjo | Pocket | ITB Four: four upright trumpets, side dumps | Quad Row: four small jets in a row, tall airbox | Twin Downjets: two upright nozzles across the arch, ram scoop outboard | Cannon: one big square burner on the right, jet 1.65 x 1.45 |
| Drift | Syndicate | Big Single: one fat turbine, two leaning dump stacks | Missile Can: one 2.3 turbine, 0.35 above the deck | Vane Cascade: blanked arch, vanes, wide slot jet on a rail | Bamboo Stacks: four tall pipes, 0.7 across, 0.62 tips |
| Time Attack | Roadster | Bonnet Letterbox: 1.4 tall body, 3.6 x 0.85 ram mouth, side slot jets 0.7 high | Tail Letterbox: ram hood, 3.5 x 0.8 mouth, slot jet 0.7 high | Blade Ducts: canted slot duct, end fence with a glowing rail | Slot Bar: 7.2 x 0.5 slot, 2.1 behind the tail |
| Rally | Estate | Snorkel: offset turbine, leaning dump stack, snorkel | Over-Under: two stacked turbines, tall intake tower | Outrigger Pods: square pod low and outboard, 1.3 x 0.9 nozzle | Quad Bank: four square burners in one upright bank on the left |

Body parts by kit (front clip, rear clip, side kit, lip, diffuser, wing). Touge: Pop-Up Wedge, Clean Tail, Slim Skirts, Chin Lip, Valance, Ducktail. Kanjo: Shorty, Bob Tail, Door Boards, Tow Bar, Bare Beam, Twin Fins. Drift: Wide Nose, Wide Tail, Deep Skirts, Intercooler Bumper, Bash Bar, GT Wing. Time Attack: Arrow Nose, Tunnel Tail, Sill Fairings, Splitter and Canards, Finned Diffuser, Swan Neck. Rally: Stage Nose, Stage Tail, Steps and Flaps, Skid Plate, Rear Guard, Box Wing.

## Datums and hardpoint pads

| Datum or pad | Value |
|---|---|
| Hover plane | Y -2.0. Nothing below Y -1.7 |
| Sill, arches, belt stripe | Sill Y 0.2. Arch top Y 1.6. Arches: Z -8.2..-4.8 and 4.9..8.3. Stripe Y 2.35..2.6 on the doors and both collars |
| Beltline, cowl pad, deck pad | Y 3.0 |
| Seams | Front Z -3.0, rear Z 3.4. Skins stop 0.1 short. A dark plate sits in the 0.2 gap |
| Collar | Both clips start with the door section: ±3.95, Y 0.2..3.0, 1.5 to 1.8 long |
| Bonnet engine pad | Y 2.6, ±2.4, Z -9.55..-5.8, flat and dark. Engines stop at Z -6.45 |
| Arch inner wall | X 2.7, Y 0.2..1.6, full arch length, dark. Arch jets start at X 2.75 |
| Tail bay pad | Y 0.8, ±2.7, Z 4.9..8.6. Bay is 4.8 wide and open above and behind |
| Roof end | Z 4.9. Behind it: buttresses at X 2.5..4.0, or bars above Y 4.4 |
| Wing pads | Y 3.0, X 2.9..3.6 each side, Z 9.3..10.3, on every tail |
| Chin and tail face | Z -10.4 below Y 1.2, and Z 10.4. Boost hangers land at X 2.7..3.9, Y 0.3..0.8 |
| Door face and width steps | Door face X 3.95; side kits butt it at X 4.0. Narrowest clips carry arch lips to X 4.6. Wide side kits taper to X 4.6 over their last stud at both ends. Lips are at most X 5.2, and 4.6 at the chin. The diffuser is at most X 4.6 |

## Authoring rules for artists

1. The cabin owns all glass and the roofline. Stop the solid roof and centre glass at Z 4.9. Carry a long roofline back as buttresses, side glass or an open frame.
2. Every cabin ships the same door section and seam plates. Change only the greenhouse. Every clip starts with the collar and carries every pad at the exact position. Do not move a pad. Pads are flat and level.
3. A short clip still reaches the chin and tail datums (bare beam on rails). A narrow clip carries an arch lip to X 4.6.
4. Keep the arches empty. Arch jets hang from the inner wall only. Each is a nacelle, longer than wide, with an intake, a nozzle and a glowing part outboard of X 5.6. No discs, rings or hoops.
5. Bonnet engines stop at Z -6.45 and exhaust sideways or up and out. Tail engines show an intake above the deck, a body and a round nozzle in the rear panel. Nothing above Y 3.0 behind Z 9.15.
6. Boost is square and flared and stands about 2 studs behind the tail. Do not copy the engine's round nozzles.
7. Side kits butt the door face along their length. No posts, no floating blades. Fences mount on the kit body.
8. Wings stand on the wing pads only. Leave a 0.2 to 0.6 gap at every join, bridged by a dark part. Options for one slot must differ in outline: width, length, height or count.

## Validator

`SPEC street: 0 error(s), 0 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 50, 'builds': 15, 'worst_gap': 0.2, 'min_distinctness': {'Engine1': 0.43, 'Engine2': 0.39, 'Stabilisers': 0.48, 'Boost': 0.59, 'FrontBody': 0.42, 'RearBody': 0.42, 'SidePods': 0.48, 'FrontBumper': 0.41, 'RearBumper': 0.52, 'RearSpoiler': 0.63, 'Cockpit': 0.49}, 'min_distinctness_whole': {'Engine1': 0.26, 'Engine2': 0.31, 'Stabilisers': 0.41, 'Boost': 0.45, 'FrontBody': 0.13, 'RearBody': 0.09, 'SidePods': 0.41, 'FrontBumper': 0.3, 'RearBumper': 0.33, 'RearSpoiler': 0.62, 'Cockpit': 0.14}, ...}`

`min_distinctness` is the free outline: the area all options share is removed. `min_distinctness_whole` is the whole outline. Clips and cockpits score low on the whole outline because the collar, pads and door section are shared by design. Builds use 146 to 184 parts and measure 12.0 to 12.2 wide, 5.3 to 8.9 high and 24.1 to 24.8 long. The closest cockpit pair is Pocket and Syndicate (0.49). Tunnel Tail now has an open channel right through each quarter; the closest rear clips are Wide Tail and Stage Tail (0.42).

## Open risks

- The brief lists six cockpits and six cultures. Wedgeback and an Underground kit are not built. A sixth cockpit needs a sixth full kit (ten modules).
- One body length and one door section. The cars still share a lower body, so cabins differ by roof, glass and buttresses only.
- Builds are 24.1 to 24.8 long against a brief of about 21. Lips reach Z -12.1 and burners reach Z 12.8. Arch jet tips reach X 6.1, so every build is about 12.2 wide against a brief of about 11. On narrow clips the jets stand up to 1.5 outboard of the arch lip.
- Wide clips (5.4 to 5.6) still step out from the 4.6 ends of the side kits. The step is a taper, not a blunt face.
- Cannon and Quad Bank sit on one side and cover part of that side's tail lamp.
- The Estate reads as a wagon in profile, but its load bay has no roof skin or tailgate. That is the price of an open tail engine.
- Flat pads cost style: real meshes need curvature that still ends on the pad. Cross-kit pairs are only checked for contact. Five mixed builds give the visual check, including the narrowest clips with both wide side kits.
