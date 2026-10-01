# Street: frame standard

Status: design exploration, 2026-10-01. Not approved, not game content. Spec: [street.json](../../../scripts/vehicle_blockouts/specs/street.json). Previews: `scripts/vehicle_blockouts/previews/street/`. Class sheet: [street.md](street.md). Brief: [contract](../../../scripts/vehicle_blockouts/CONTRACT.md).

Root space: +X right, +Y up, forward is -Z, studs. Boxes read `X; Y; Z`. `±` means the box spans both sides. "Both sides" means one box on each side. The body is 21 long (Z -10.6 to 10.4), 8.8 wide stock and 10.4 widebody. With every part fitted the car stays inside X ±5.8, Y -1.3 to 7.4, Z -11.6 to 12.8.

## Frame standard

| Slot id | Player label | Envelope | Anchor (seam) |
|---|---|---|---|
| Cockpit | Cabin | Cabin ±4.0; -0.6..5.2; -4.0..4.2. Greenhouse extension ±4.0; 3.0..5.2; 4.2..9.0 | Root |
| `Engine1` | Front Clip | Nose ±5.2; 0.2..2.8; -10.6..-8.1. Over arch ±5.2; 1.7..2.8; -8.1..-4.7. Subframe ±2.6; -0.6..1.7; -8.1..-4.7. Seam strip ±5.2; -0.6..2.8; -4.7..-4.0. Upper ring for lamp pods: 2.6..5.2 both sides; 2.8..3.9; -10.6..-4.0, and ±2.6; 2.8..3.9; -10.6..-8.1 | Cockpit at Z -4.0 |
| `Engine2` | Rear Clip | Seam strip ±5.2; -0.6..3.0; 4.2..4.8. Subframe ±2.6; -0.6..1.7; 4.8..8.2. Over arch ±5.2; 1.7..3.0; 4.8..8.2. Tail ±5.2; 0.2..3.0; 8.2..10.4 | Cockpit at Z 4.2 |
| `Stabilisers` | Hover Rotors | 2.6..5.8 both sides; -1.7..1.7; -8.1..-4.7 (front pair) and 4.8..8.2 (rear pair) | Clip subframe at X 2.6 |
| `SidePods` | Side Kit | Flank 4.0..5.8 both sides; -1.3..3.0; -4.0..4.2. Overfender strips 5.2..5.8; 1.7..3.0; -8.6..-4.0 and 4.2..8.6. Flap pocket 2.6..5.8; -1.3..0.2; 8.2..8.6 | Cockpit at X 4.0 |
| `Boost` | Exhaust | ±4.6; 0.2..3.0; 10.4..12.8. Stack box ±4.6; 3.0..6.4; 11.4..12.8 | Rear Clip tail face at Z 10.4 |
| `FrontBumper` | Front Lip | Under ±5.8; -1.3..0.2; -11.6..-8.1. Face layer ±5.8; 0.2..1.6; -11.6..-10.6 | Front Clip underside at Y 0.2 |
| `RearBumper` | Diffuser | ±5.6; -1.3..0.2; 8.6..11.2 | Rear Clip underside at Y 0.2 |
| `RearSpoiler` | Wing | ±5.8; 3.0..7.4; 9.0..11.4 | Rear Clip deck pad at Y 3.0 |
| `Hood` | Hood | ±2.6; 2.8..4.0; -8.1..-4.0 | Front Clip hood pad at Y 2.8 |
| `Roof` | Roof | ±3.4; 5.2..6.6; -2.4..4.2 | Cockpit roof pad at Y 5.2 |
| `Accessory` | Extras | 4.0..5.4 both sides; 3.0..7.0; -4.0..-2.0 | Cockpit A-pillar foot at X 4.0 |

No two envelopes overlap. The blockout has 4 cockpits (Touge, Pocket, Syndicate, Kei) and 37 modules. That is 1,990,656 possible full builds.

## Datums

- Hover plane Y -2.0. Nothing goes below Y -1.3.
- Floor Y -0.6. Sill line Y 0.2: every bumper and door skin ends here. Front Lip and Diffuser hang below it.
- Axles Z -6.4 and 6.5. Arch top Y 1.7. Arch lip X 5.0.
- Belt stripe Y 2.45 to 2.7, on the cabin and both clips.
- Hood pad Y 2.8, flat, X ±2.6, Z -8.1 to -4.0.
- Beltline and deck pad Y 3.0. The whole rear clip top is flat at this height.
- Roof pad Y 5.2, flat, X ±2.6, Z -1.2 to 1.4.
- Seated avatar: head top Y 3.9, roof underside Y 4.9, cabin 7 wide inside.

## Seam rules

1. Clip to cabin. Clip skins stop 0.1 short of the seam. Cabin skins start 0.1 inside it. The cabin carries a dark plate in the 0.2 gap.
2. Rotor to clip. Each clip has a dark subframe wall at X 2.5 for the full arch length. Each rotor has a dark hub arm starting at X 2.65.
3. Lip and Diffuser hang from the sill line. Every clip puts a surface at Y 0.2 above them.
4. Exhaust starts at Z 10.4. Every rear clip reaches Z 10.3.
5. Hood, Wing and Roof modules stand on their pad. Their lowest face is the pad height.
6. Side Kit butts the door at X 4.0. Overfenders start at X 5.2 and rely on the arch lip.
7. Extras clamp to the door top at X 4.0, Y 3.0.

Checked by script over every child and parent pairing: the worst closest-part gap is 0.20 studs and no part boxes overlap across slots.

## Authoring rules for artists

1. The cabin owns everything above the beltline, back to Z 9.0. The rear clip never rises above Y 3.0. This lets a coupé, a saloon, a hatch and a tiny targa share one rear clip.
2. Pads are flat and level. A module sits in root space and cannot follow a slope. Slope the nose ahead of Z -8.1 and the wings outside X 2.6, not the pad.
3. The roof pad is sized to the shortest roof (Kei). Roof modules mount inside it and may overhang.
4. Clips own the arches, but arch width is a datum. Every clip carries an arch lip out to X 5.0 along the whole rotor zone. Without it, overfenders float beside a stock clip.
5. A wide clip ends in a finished face at the cabin seam (a vent or a cut flare). The parts next to it may be narrow.
6. Keep the rotor zone empty. Clips stay above Y 1.7 between X 2.6 and 5.8.
7. A rotor is a disc up to 3.0 across and 0.8 thick, tilted 18 to 50 degrees with the outer edge down. Rim face up and out, thrust face down. The whole tilted disc stays inside the box.
8. Every rear clip keeps the full deck pad to Z 10.15, even with the bumper cut away (Time-Attack Tail).
9. Keep the stripe band clear. Arch crowns stop at Y 2.3.
10. Exhausts begin at the tail face. Tall pipes use only the stack box behind Z 11.4, so they clear the Wing.
11. Use dark `detail` parts for every linkage: seam plates, hub arms, wing uprights, splitter rods.

Roster changes forced by the standard:

- Roof Spoiler is not a Wing. Roof ends differ by cockpit (Z 1.8 to 8.0), so it cannot interchange. Make it a cockpit feature. Pocket carries one.
- Tow Strap is not an Extra. It needs a bumper anchor and a slot has one anchor. Move it into the Front Lip slot.
- Shark, Hatch Bustle and Mesh were not built in this pass. Nothing in the standard blocks them.

## Validator

`SPEC street: 0 error(s), 1 warning(s) {'cockpits': 4, 'modules': 37, 'builds': 8, 'parts_in_builds': 1092}`

Warning left: `cockpit syndicate appears in fewer than 2 builds`. Eight builds in the required pattern (3 cockpits, then 1 cockpit three times, then 2 wildcards) always leave one of four cockpits with a single build. Builds use 122 to 149 parts.

## Open risks

- Kei scale. The class has one body length. Kei reads as a small cab on a full-size car, not as a tiny car.
- Flat pads cost style. Every bonnet and boot is level. Real meshes need curvature that still ends on the pad.
- Rotors tuck under widebody clips and overfenders. Check the rim face still reads in game.
- Stock clips show a 0.2 gap to overfenders. Widebody clips sit flush. Decide if that gap needs bolts.
- Pop-up lamps move. The upper ring is reserved to Y 3.9 for the raised state.
- The validator allows one anchor per slot. The rear rotor seam to the Rear Clip is not checked by it.
- The preview sorts faces by centre depth. Small parts on the far half of a large face vanish in the three-quarter views. Top and side views are correct.
- Exhausts sit behind the crash bar on the Time-Attack Tail. It works but looks busy.
- Five-Spoke rotors cost 32 parts. No ring shape exists, so the rim is an open star.
- With splitter and bamboo stacks the car is 24.2 long. The body is 21.
