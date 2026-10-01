# Rider frame standard

Status: design exploration, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [rider.json](../../../scripts/vehicle_blockouts/specs/rider.json). Previews: [sheet](../../../scripts/vehicle_blockouts/previews/rider/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/rider/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rider/standard.png).

Rider is a hoverbike. The cockpit is the spine, the seat base and the rider. Every other slot wraps around the rider and never enters the rider's space. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Envelopes

| Slot | Player label | X | Y | Z | Anchors to |
|---|---|---|---|---|---|
| Cockpit | Spine, seat, rider | A, B: ±0.8; C: 0.8..1.6, mirrored; D: ±1.6 | A: -0.8..1.6; B: 1.6..3.2; C: 0..3.2; D: 3.2..6.6 | A, C: -2.8..3.4; B: -0.2..3.4; D: -1.6..3.4 | root |
| Engine1 | Front End | ±1.4 | A: -1.8..1.4; B: 1.4..2.2; C: 2.2..3.2 | A: -8.4..-2.8; B: -5.6..-2.8; C: -4.4..-2.8 | cockpit front, Z -2.8 |
| Engine2 | Rear End | ±1.4 | -1.8..1.6 | 3.4..7.6 | cockpit rear, Z 3.4 |
| Stabilisers | Winglets | A: 0.8..2.4; B: 2.4..3.0; both mirrored | A: -1.4..0; B: -1.4..2.2 | A: -2.8..3.0; B: -4.4..3.4 | cockpit belly, X ±0.8 |
| SidePods | Body Panels | 1.6..2.4, mirrored | 0..3.2 | -4.4..4.4 | cockpit panel stays, X ±1.6 |
| Boost | Exhaust | 1.4..2.4, mirrored | -1.4..2.8 | 4.4..8.2 | Rear End flank, X ±1.4 |
| FrontBumper | Fairing | ±1.6 | A: 2.2..3.9; B: 1.4..2.2 | A: -8.4..-4.4; B: -8.4..-5.6 | Front End, Z -4.4 |
| RearBumper | Tail Kit | ±1.3 | A: 1.6..5.8; B: -0.8..1.6 | A: 6.6..8.2; B: 7.6..8.2 | Seat Unit tail rail, Z 6.6 |
| RearSpoiler | Seat Unit | ±1.3 | 1.6..4.4 | 3.4..6.6 | cockpit rear, Z 3.4 |
| Hood | Tank | ±0.8 | 1.6..3.2 | -2.8..-0.2 | spine top, Y 1.6 |
| Roof | Screen | ±1.4 | 3.9..6.2 | -7.6..-4.4 | Fairing top, Y 3.9 |
| Accessory | Bars | ±2.2 | 3.2..5.8 | -4.4..-1.6 | Front End top yoke, Y 3.2 |

A to D are boxes of one envelope. Cockpit: A core, B seat base, C leg channels, D rider upper body. No two envelopes overlap. Built size: 4.8 to 6.0 wide, 14.4 to 16.5 long, 6.1 to 7.9 high with the rider (the bike alone is about 5.5).

## Datums

| Datum | Value | Meaning |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing goes below Y -1.55. |
| Sill | Y 0 | Bottom of panels and leg channels. Below it: belly, winglet struts, hover gear. |
| Beltline | Y 1.6 | Spine top. Tank, Seat Unit and tail rail sit on it. The Rear End stays under it. |
| Rake line | (Y 2.2, Z -4.4) to (Y 1.4, Z -5.6) | Fork behind it, Fairing ahead of it. |
| Hand datum | X ±1.15, Y 4.0, Z -1.3 | Where every cockpit puts the rider's hands. It never moves. |
| Grip box | X 0.85..1.7, Y 3.6..4.4, Z -2.2..-1.6 | Where every Bars module puts its grips. |
| Seat tail | top at Y 2.2..3.0, Z 3.35 | Where every cockpit's seat ends and every Seat Unit begins. |

## Pads and hardpoints

| Pad (owner fills it, user sits on it) | Owner | Where | Used by |
|---|---|---|---|
| Neck stub, rear plate | Cockpit | X ±0.35, Y 1.05..1.55 at Z -2.75; Y 0..1.0 at Z 3.35 | Front End head tube link; Rear End pivot link |
| Belly hardpoint | Cockpit | X ±0.75, Y -0.8..-0.2, Z -1.6..1.8 | Winglet struts |
| Panel stays | Cockpit | dark struts out to X 1.55 at Z -2.62 (Y 1.1) and Z 3.15 (Y 1.2) | Body Panels: cover at least one station |
| Top yoke, fairing stay | Front End | yoke top at Y 2.9..3.1, Z -3.8..-3.0; dark stay at the same height reaches Z -4.38 | Bars clamp; Fairing |
| Fairing top | Fairing | reaches Y 3.6 or higher, behind Z -5.6 | Screen |
| Tail rail | Seat Unit | dark, Y 1.67..1.89, Z 3.5..6.5 | cockpit rear, Tail Kit bracket |

## Seam rules

1. The rider is a cockpit part. No module enters the cockpit envelope, so no module can cut the rider.
2. Hands stay behind the plane Z -1.6. Grips stay ahead of it. They meet there, 0.05 apart.
3. Paint stops short of every seam. Only dark `detail` linkage crosses or touches it. Gaps used: 0.1 to 0.6.
4. Fork and Fairing split on the rake line. Body Panels hang outboard of the legs. The leg channel holds only legs, pegs and the two panel stays.

## Rider pose limits

- Hands sit on the hand datum in every cockpit. Shoulders stay within 2.2 studs of it (one arm). The blockout uses 1.2 (Speeder) to 2.1 (Chopper).
- Hips sit behind Z 0.3, because the Tank ends at Z -0.2. So "laid back" means straight arms and at most 12 degrees of back lean.
- A chest over the Tank stays above Y 3.2. The lowest crouch is about 35 degrees above level. Elbows bend down into the leg channel, never wider than X ±1.6.
- Feet rest on cockpit pegs: X 0.9..1.5, sole at Y 0.95..1.8, Z -2.4 (forward controls) to 3.3 (rear stirrups). Helmet top stays under Y 6.5; the tall Scrambler reaches 6.42.

## Authoring rules for real meshes

- Author every mesh in cockpit root space. Keep every surface inside the slot envelope, not only the corners. The envelopes have inside corners at the rake line steps and the Tank notch.
- Cockpit: spine no wider than 1.6. Own the seat, pegs, panel stays, neck stub and rear plate. Start the seat behind Z -0.2 and finish it at the seat tail datum.
- Front End: finish with a top yoke at Y 3.0 and a fairing stay. Ring top at Y 1.4 or lower. Rake from 22 to 52 degrees.
- Bars: put the grips in the grip box, always. The shape is free above and ahead of it, up to Y 5.8 and X ±2.2.
- Seat Unit: start at the seat tail datum and carry a tail rail to Z 6.5. Tail Kits bolt to the rail end, not to the bodywork.
- Hover rings: thin dark rim, large glowing core or no hub at all, bottom at Y -1.5. No tyre shapes. Each module carries its own lights and glow.

## What the blockout showed

- 5 cockpits: Supersport, Streetfighter, Scrambler, Chopper, Speeder. 42 modules: 5 Front End, 4 Rear End, 3 Winglets, 4 Body Panels, 4 Exhaust, 5 Fairing, 3 Tail Kit, 4 Seat Unit, 3 Tank, 3 Screen, 4 Bars. The blockout rider is 5 tall, 1.5 wide at the torso and 2.7 across the arms.
- 8 builds of 130 to 140 parts. Builds 1 to 3: Supersport kit on Supersport, Scrambler and Chopper. Builds 4 to 6: Streetfighter with Streetfighter, Chopper and Motocross kits. Builds 7 and 8: mixed.
- Every module passes alone, so every mix passes. A scratch surface check found no part cutting an inside corner. A scratch pad check found every pad filled. Four extra odd mixes were rendered and inspected.
- Main lesson: the rider is fixed geometry. Whatever the rider touches must be a class datum, not a module choice. One hand datum, one seat tail and cockpit-owned pegs made five poses fit every kit.
- The first pass had zero errors but a floating lamp, a hubless ring with no visible arm and side panels held by nothing. The fairing stay, a caliper arm and the panel stays fixed them. Pads matter as much as envelopes.

Validator: `SPEC rider: 0 error(s), 3 warning(s) {'cockpits': 5, 'modules': 42, 'builds': 8, 'parts_in_builds': 1095}`
Warnings left: cockpits `supersport`, `scrambler` and `speeder` each appear in fewer than 2 builds. Eight builds in the required 3 + 3 + 2 pattern cannot show five cockpits twice each.

## Open risks

- Bars cannot move the hands. Apes are a tall hoop over fixed grips, and Clip-ons are no lower than Drag Bars. True apes need arm IK and a taller grip box.
- A real R15 avatar is about 4 wide across the arms. The rider box is 3.2 wide. Test the real astride animation before any mesh is made.
- Body Panels sit outside the legs. A Full Fairing hides the Chopper's forward legs, and Tank Shrouds stand 0.85 off the Tank. Other legal but weak mixes: a Bobber Fender sits 0.9 below a sport seat tail; a crouched rider under Apes; a Luggage Rack behind an MX Fender tip.
- The rings still read as wheels in side view, as the design contract warns. The Hubless Ring is the safer look. Built length is 14.4 to 16.5, over the brief's 14. The bike is large against the avatar, so the helmet sits 3 studs behind any Screen.
- The validator checks corners only and knows no pads. A rotated part can cut an inside corner and still pass. Untested: the Café cockpit, a passenger, one-sided exhausts, lean and wheelie clearance.
