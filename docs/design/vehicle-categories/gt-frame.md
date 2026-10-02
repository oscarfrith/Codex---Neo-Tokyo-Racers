# GT: frame standard (round 2)

Status: design exploration, round 2 after the third fix pass (chin shelf and part budget), 2026-10-02. Not approved, not game content. Spec: [gt.json](../../../scripts/vehicle_blockouts/specs/gt.json), written by [gen/gt.py](../../../scripts/vehicle_blockouts/gen/gt.py). Previews: `scripts/vehicle_blockouts/previews/gt/`. Brief: [contract](../../../scripts/vehicle_blockouts/CONTRACT.md).

Front-engined sports cars and grand tourers on jets, plus the rear-engined coupé. No wheels, rings, discs or rotors anywhere. A real car body in three sections: nose and bonnet, cabin, tail. The body is 9.6 wide stock (11.7 with the GT3 arches). Builds are 10.6 to 11.7 wide and 24.1 to 25.8 long with lift jets, bumpers and burners. Blockout content: 6 cockpits, 6 signature kits, 60 modules (6 per slot), 18 builds. Root space: +X right, +Y up, forward is -Z, studs. Boxes read `X; Y; Z`. `±` spans both sides.

## Frame standard

| Slot id | Player label | Envelope | Anchor (seam) |
|---|---|---|---|
| Cockpit | Cabin | Tub ±4.7; 0..5.6; -2.6..5.0. Greenhouse ±3.7; 3.0..5.6; 5.0..7.0. Rails 1.7..3.7 each side; 3.0..5.6; 7.0..10.0. Roof bridge ±1.7; 3.5..5.6; 7.0..10.0 | Root |
| `FrontBody` | Nose and Bonnet | Nose ±5.9; 0..3.8; -12.8..-9.6. Wings 2.0..5.9 each side; 2.4..3.8; -9.6..-2.6. Bay floor ±2.0; 0..1.0; -9.6..-2.6. Arch walls 2.0..3.3 each side; 0..2.4; -9.6..-2.6. Arch pillars 3.3..5.9; 0..2.4; -9.6..-9.1 and -5.7..-5.2. Cove frame 3.3..5.9; 0..0.3 and 1.8..2.4; -5.2..-2.6 | Cockpit at Z -2.6 |
| `RearBody` | Tail | Deck and haunches 1.7..5.9 each side; 2.4..3.0; 5.0..12.4. Haunch tops 3.7..5.9; 3.0..3.7; 5.0..12.4. Hatch floor ±1.7; 0..1.0; 5.0..10.4. Front deck ±1.7; 1.0..3.0; 5.0..7.0. Arch walls 1.7..3.3; 0..2.4; 5.0..10.4. Arch pillars 3.3..5.9; 0..2.4; 5.0..5.5 and 8.9..10.4. Tail band 1.7..5.9; 1.0..2.4; 10.4..12.4 | Cockpit at Z 5.0 |
| `Engine1` | Front Engine | Bonnet bay ±2.0; 1.0..3.8; -9.6..-2.6. Side coves 3.3..5.9 each side; 0.3..1.8; -5.2..-2.6 | Nose bay floor at Y 1.0 |
| `Engine2` | Rear Engine | Hatch ±1.7; 1.0..3.5; 7.0..10.0. Nozzle run ±1.7; 1.0..3.0; 10.0..12.6 | Tail hatch floor at Y 1.0 |
| `Stabilisers` | Lift Jets | 3.3..5.9 each side; -1.6..2.4; -9.1..-5.7 (front pair) and 5.5..8.9 (rear pair) | Arch wall at X 3.3, on nose and tail |
| `Boost` | Afterburner | ±3.4; -0.25..1.0; 10.4..13.6 | Tail transom at Z 10.4 |
| `SidePods` | Sills | 4.7..5.9 each side; -1.2..1.5; -2.6..5.0 | Cockpit door face at X 4.7 |
| `FrontBumper` | Chin | ±5.9; -1.3..0; -13.6..-9.3 | Nose chin pad at Y 0 |
| `RearBumper` | Rear Valance | Floor ±5.9; -1.5..0; 8.9..10.4. Blade ±3.4; -1.5..-0.25; 10.4..13.6. Corners 3.4..5.9 each side; -1.5..1.0; 10.4..12.9 | Tail underside at Y 0 |
| `RearSpoiler` | Spoiler | Base ±3.7; 3.0..3.7; 10.0..12.9. Wing ±5.9; 3.7..6.9; 10.0..12.9 | Tail deck pad at Y 3.0 |

No two envelopes overlap. `Hood`, `Roof` and `Accessory` are not used: the bonnet opening belongs to the front engine and the cockpit owns all glass and the roofline.

## The four fundamentals

- **Engine1, Front Engine.** Sits in an open bay in the bonnet, between the wings. Every option carries a bright tray plate out to the bay edge, so the bay never reads as a hole. Five options stand above the bonnet line (3.4 to 3.8 high). Twin Ram is flush at 3.0 so the Sports bonnet reads as a lid. Side exits fire from a cove behind each front arch.
- **Engine2, Rear Engine.** Stands through a framed hatch in the tail deck (3.4 wide, Z 7 to 10) up to Y 3.5. Its nozzles run out through the open tail to Z 12.4 or further. Six outlines: two round tubes, one fat tube, four in a square, three in a row, two tall square-cut nozzles splayed in a vee, one thin flat slot pitched down at the tail.
- **Stabilisers, Lift Jets.** Four units, one in each blanked arch, hung from the arch wall. All six fire downwards. Slant Jets is a pod with two short fat nozzles whose tips stop just under the sill (Y -0.3). Outriggers hang one fat nacelle under a body-colour stub winglet (to Y -0.85). Comb Jets is a rail with four thin down-pipes over one thin strip of thrust. Twin Columns reach lowest, Y -1.25.
- **Boost, Afterburner.** Every unit sits on the transom between Y -0.25 and 1.0, so none hangs below a short bumper. Megaphones (long, flared, to Z 13.45), Stacked Twins (two fat cans, one high and one low), Single Cannon (right side only) and Blade Burners (upright square-cut can 0.85 wide, collar 0.95, slot jet 0.55 by 0.96, to Z 12.87) sit outboard under the lamps. Staged Pairs is an L each side: a long round can outboard and a short flat slot burner inboard of it. Quad Tips is a row of four across the centre, under the engine nozzles. Every burner has a dark collar and a glowing core.
- **All four.** Every option has an intake, a body and a glowing `thrust` part. Every pod, can and nozzle is longer than it is wide.

## Datums and hardpoint pads

| Datum | Value | Use |
|---|---|---|
| Hover plane | Y -2.0 | Ground reference |
| Sill and floor | Y 0 | Underside of all three body sections; chin and valance hang below |
| Arch top | Y 2.4 | Top of every blanked arch; lift jets stay below it |
| Shoulder and beltline | Y 2.6 and 3.0 | 0.45 chamfer between them; scuttle, door tops and deck pad all sit at 3.0 |
| Cowl and back seams | Z -2.6 and 5.0 | Every section is ±4.8 wide, 0 to 3.0 high here; the cockpit carries a 0.2 dark seam plate |
| Front and rear arch | Z -9.1..-5.7 and 5.5..8.9 | Arch centres Z -7.4 and 7.2; arch wall at X 3.3 |
| Engine hatch | ±1.7; Z 7.0..10.0 | The deck opening the rear engine stands through; engine top Y 3.5 |
| Transom | Z 10.4 | Afterburner and valance pad |
| Afterburner band | Y -0.25..1.0 | Boost stays inside it; the rear valance owns everything below Y -0.25 |
| Chin shelf | Y 0..0.2; ±3.6 at Z -11.6, swept at 45 degrees to ±4.6 at Z -10.6, straight back to Z -9.6 | Every nose fills this outline, so a chin plate shows the same narrow rim round every nose |

Pads (flat, fixed, the same on every option): bonnet bay floor ±2.0 at Y 1.0; tail hatch floor ±1.7 at Y 1.0; four arch walls at X 3.3, Y 0 to 2.0 or higher; side-cove back wall at X 3.3 with its sill and lintel; chin pad ±2.0 at Y 0, Z -10.8..-9.6, in the middle of the chin shelf; transom ±3.3 at Z 10.4; spoiler pads X 1.7..3.7 at Y 3.0, Z 10.0..10.6; door faces at X 4.7. Blunt noses (Shark, Square, Works) cover the chin shelf with bodywork. Pointed and short noses (Torpedo, Frogeye, Clubman) carry it as a thin dark swept undertray.

## Signature kits

| Kit | Culture | Native cockpit | Front engine | Rear engine | Lift jets | Afterburner |
|---|---|---|---|---|---|---|
| Classic | Classic GT | Longnose | Inline Stack | Tail Twin | Torpedo Lifts | Twin Megaphones |
| Sports | Rear-Engine Sports | Teardrop | Twin Ram | Fat Single | Twin Columns | Stacked Twins |
| Modern | Modern GT | Bruiser | Big Single | Quad Square | Vane Boxes | Quad Tips |
| Clubman | Roadster | Roadster | Quad Throttle | Triple Tube | Slant Jets | Single Cannon |
| Estate | Shooting Brake | Brake | Ram Scoop | Splay Vee | Comb Jets | Staged Pairs |
| GT3 | GT3 Racer | Gullwing | Bonnet Slot | Slot Vector | Outriggers | Blade Burners |

Body sections by kit, nose then tail:

- Classic: Torpedo Nose (longest, lowest, pointed, falling wing line, dark underbody on the chin shelf). Kamm Tail (shortest, hips rise to a high square cut).
- Sports: Frogeye Nose (shortest body, wings peak at 3.6, round lamp pods over a wrap-round bumper that reaches Z -11.0; the chin shelf shows 0.6 ahead of it as a dark lip). Wide Hips (5.6 wide, tail slopes to a low edge).
- Modern: Shark Nose (long, drooping to a blunt point in plan, wings hump to 3.75, arch blisters to 5.4). Muscle Haunch (peak over the arch, arch blisters, undercut tail edge). Its Diffuser is a body-colour valance with two wide dark tunnels that stops at Z 11.4; the long black floor, blade, strakes and fences belong to the GT3 Race Diffuser only.
- Clubman: Clubman Nose (narrow low cone, open front corners, lamps on posts; the chin shelf is its swept dark apron). Boat Tail (open rear corners, pointed stern).
- Estate: Square Nose (upright, full bonnet height, face at Z -11.6, mirrors on the wing edges). Square Tail (box ending at Z 11.0, rails at 3.7, lamp columns). Its spoiler is the Boot Rack, which needs no roof. Its Blade Bumper has two bright blades over a short dark step plate.
- GT3: Works Nose and Works Tail (box arches to 5.85 with louvres, low short nose, stripped short tail). Each box tapers back to the 4.8 body in plan, so it blends when the other end is narrow.

Cockpits, with roof height: Longnose 5.2 (small, tall, upright box cabin set back behind a long scuttle; thin pillars, bright roof lip, deep notch, short fastback). Teardrop 5.6 (screen at the cowl, round dome, one curve down, two buttresses beside the engine). Bruiser 4.3 (chopped roof as wide as the shoulders, slit glass, sunk rear window, two flying buttresses from roof height at Z 6.6 down to the deck at Z 10). Roadster (open, twin head fairings). Brake 5.4 (longest roof, open tailgate frame and roof rails over the engine, roof-height blade). Gullwing 5.5 (narrow leaning canopy, deep sills, proud door frames, a roof spine that runs down the back as a fin).

## Authoring rules for real meshes

1. Build in cockpit-root space. Do not move a pivot. Every slot mount is the cockpit origin.
2. Stay inside your slot envelope. Nothing may cross into another slot's box.
3. Every cockpit ships the same tub: floor, doors to X 4.7, scuttle and rear deck at Y 3.0, seam plates at Z -2.6 and 5.0. Only the glass, roof, shoulders and trim above the beltline change.
4. Every nose and tail meets the cockpit at the full seam section: ±4.8 wide, Y 0 to 3.0. Narrow or open-corner options flare out to it within 2.6 studs of the seam. Wide options taper back to it in plan.
5. Every nose and tail carries every pad listed above, flat and at the stated position. Modules land on pads, never on a styled surface.
6. Leave a 0.2 shadow gap at each seam and bridge it with dark `detail` linkage.
7. Engines stay open to view. Do not close the bonnet or the tail over them. Show intake, body and nozzle. Behind Z 7.0 a cockpit may only build beside the hatch (X 1.7 to 3.7) or bridge it above Y 3.5 with an open frame. No roof panel, glass or lid may cover the hatch. Every rear engine puts its intake behind Z 7.4, rises above the deck and reaches Z 12.4. Every engine covers its bay floor with a tray plate.
8. No wheel shapes. Arches are blanked with a dark wall. A lift jet is a tube, box or pod longer than it is wide. Keep its centre inside X 4.6 so it sits in the arch of a 4.8 body.
9. Wing and haunch tops may rise to Y 3.8 (nose) and 3.7 (tail), but must come back to 3.0 at the seam, or ramp to it.
10. Spoilers stand on the deck pads only and must work with no roof behind them. Roof-height trim belongs to the cockpit.
11. Afterburners stay between Y -0.25 and 1.0 and wear a dark collar. Only Quad Tips uses the centre line. Bumper blades, steps and valances must join the valance floor or corners with a visible part and stay inside X 5.1.
12. Chins are built to the chin shelf, not to one nose. A chin plate is dark, sweeps its front corners at 45 degrees, stays inside X 5.0 and stands no more than 0.45 outside the shelf (the Splitter: 0.3 ahead plus a 0.15 bright edge, 0.4 at the corners and sides). Put fences under the body side (X 4.85 or less). A nose that is narrower or shorter than the shelf must carry it. A sill floor stays inside X 5.3 and tapers at both ends.
13. Part budget: the heaviest cockpit plus the heaviest option in every slot must come to 220 parts or less. New detail must replace old detail. Paint channels: body `primary`, trim `secondary`, mechanics and linkage `detail`, plus `glass`, `neon`, `thrust`.

## Validator output

`SPEC gt: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 60, 'builds': 18, 'worst_gap': 0.14, 'min_distinctness': {'Engine1': 0.55, 'Engine2': 0.38, 'Stabilisers': 0.45, 'Boost': 0.38, 'FrontBody': 0.38, 'RearBody': 0.45, 'SidePods': 0.43, 'FrontBumper': 0.4, 'RearBumper': 0.33, 'RearSpoiler': 0.5, 'Cockpit': 0.34}, 'min_distinctness_whole': {'Engine1': 0.15, 'Engine2': 0.15, 'Stabilisers': 0.36, 'Boost': 0.32, 'FrontBody': 0.1, 'RearBody': 0.06, 'SidePods': 0.36, 'FrontBumper': 0.36, 'RearBumper': 0.28, 'RearSpoiler': 0.47, 'Cockpit': 0.08}, ...}`

`min_distinctness` is the free outline: the area every option shares is removed first. `min_distinctness_whole` is the whole outline. There are no warnings of any kind. The closest pairs are Frogeye Nose against Square Nose (0.38 free), Triple Tube against Slot Vector (0.38), Stacked Twins against Blade Burners (0.38), Diffuser against Race Diffuser (0.33; target 0.25) and Teardrop against Brake (0.34; cockpit target 0.25). Part budget: the worst free mix is 217 parts (Teardrop, Bruiser or Gullwing at 46, plus the heaviest option in every slot). It is a listed build, "Mixed: heaviest option in every slot", so the validator's 220 warning covers it. The twelve random mixes come to 166 to 206. Heaviest options: cockpit 46, nose 38, tail 30, lift jets 24, front engine 18, rear engine 14, afterburner 14, rear valance 11, sills 8, chin 7, spoiler 7. The validator checks contact per module, so a separate per-part pass was run over all 36 cockpit and kit pairs, the six mixed builds, the twelve random mixes and 360 single-module swaps (each kit with one slot changed to each option): every part sits within 0.12 of the rest of the vehicle.

## Open risks

- **The chin shelf shows on three noses.** It stands up to 0.8 outside the Torpedo body side, 0.6 ahead of the Frogeye bumper and about 1.5 either side of the Clubman cone, in every build. This is the price of one Splitter and one Lip for six noses. Plate area showing outside the nose, in square studs: Splitter 2.7 Torpedo, 5.0 Frogeye, 3.5 Clubman (were 4.7, 10.3, 7.6), against 1.3 Shark, 2.5 Square, 2.8 Works. Lip 1.6, 1.9, 1.8 (were 3.1, 6.6, 5.3). If the shelf is not wanted, the other route is a splitter variant per nose.
- **Close scores and low whole-outline scores.** Three slots sit at 0.38 against a 0.35 target. Blade Burners stop at Z 12.87: at Z 13.27 they scored 0.28 against the Megaphones. Whole scores are 0.06 to 0.15 for bodies, engines and cockpits, because they share pads, trays and the seam section.
- **Size and part count.** Builds are 24.1 to 25.8 long against a 23 target and 10.6 to 11.7 wide against 10. The longest carry the Megaphones (Z 13.45). The budget has three parts to spare. The trim removed small detail, such as door shut lines, stack and trumpet mouths, one louvre in three, Frogeye indicators.
- **Quad Tips, Single Cannon and Staged Pairs.** Quad Tips sits on the centre line under the engine nozzles; it reads apart by its dark collars, square tips and height. The Cannon is on the right side only. The Staged Pairs slot burner sits low under the outer engine nozzles. Check all three from the chase camera.
- **Engine view and open sections.** The Bruiser buttresses and the Teardrop buttresses stand beside the rear engine and hide part of it from the side. The Brake roof is open behind Z 7.4. Lift jets stand in the open beside the Clubman nose and Boat Tail. Box arches reach X 5.85. Check all of these in game.
