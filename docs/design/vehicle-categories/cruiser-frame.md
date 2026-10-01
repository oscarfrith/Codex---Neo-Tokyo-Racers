# Cruiser frame standard

Status: design exploration, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [cruiser.json](../../../scripts/vehicle_blockouts/specs/cruiser.json). Previews: [sheet](../../../scripts/vehicle_blockouts/previews/cruiser/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/cruiser/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/cruiser/standard.png).

Cruiser is a long, low land yacht in three slab-sided bodies: front clip, cabin, rear deck. One rotor frame hangs under all three. Trim, chrome, fins and pipes bolt on around them. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Envelopes

| Slot | Player label | X | Y | Z | Anchors to |
|---|---|---|---|---|---|
| Cockpit | Cabin | A: -4.8..4.8; B: -4.4..4.4 | A: 0..3.2; B: 3.2..4.9 | A: -5.5..6.0; B: -4.0..6.0 | root |
| Engine1 | Front Clip | -4.8..4.8 | 0..3.6 | -16.4..-5.5 | cockpit front, Z -5.5 |
| Engine2 | Rear Deck | -4.8..4.8 | 0..3.6 | 6.0..15.5 | cockpit rear, Z 6.0 |
| Stabilisers | Hover Rotors | -4.8..4.8 | -2.0..0 | -16.4..15.5 | cockpit floor, Y 0 |
| SidePods | Flanks | 4.8..5.6, mirrored | -1.6..3.6 | -14.5..14.0 | cockpit side, X ±4.8 |
| Boost | Pipes | -5.6..5.6 | A: -1.6..0; B: 0..9.8 | A: 15.5..19.0; B: 17.0..19.0 | Rear Deck tail, Z 15.5 |
| FrontBumper | Front Chrome | -5.6..5.6 | -1.6..3.6 | -18.4..-16.4 | Front Clip nose, Z -16.4 |
| RearBumper | Rear Chrome | -5.6..5.6 | 0..4.2 | 15.5..17.0 | Rear Deck tail, Z 15.5 |
| RearSpoiler | Deck Trim | -5.6..5.6 | 3.6..8.2 | 6.0..15.5 | Rear Deck top, Y 3.6 |
| Hood | Hood | -4.4..4.4 | 3.6..5.0 | -16.4..-5.5 | Front Clip top, Y 3.6 |
| Roof | Roof | -4.4..4.4 | 4.9..5.7 | -1.6..6.0 | cockpit roof, Y 4.9 |
| Accessory | Extras | A: -4.8..4.8; B: -4.4..4.4 | A: 3.2..5.7; B: 4.9..5.7 | A: -5.5..-4.0; B: -4.0..-1.6 | cowl, Y 3.2, and roof lip, Y 4.9 |

A and B are two boxes of one envelope. No two envelopes overlap. Built size: 11.0 to 11.2 wide, 34.9 to 37.3 long, roof 6.9 above the ground. Street is about 11 by 21, so the class reads on length alone.

## Datums

| Datum | Y | Meaning |
|---|---|---|
| Hover plane | -2.0 | Ground. Nothing goes below -1.6. |
| Sill | 0.2 | Bottom of painted body. Below it: rotors, skirts and pipes only. |
| Bar line | 1.4 | Chrome bars stay below. Lamps stay above. |
| Beltline | 3.0 | Window sill. Top of the flat body side on cabin, clip and deck. |
| Deck | 3.2..3.6 | Bonnet crown and boot top. Hood and Deck Trim seam is 3.6. |
| Roof | 4.65..4.9 | Crown of every cockpit. Roof and Extras seam is 4.9. |

## Pads and zones

Envelopes stop clipping. Pads stop holes and floating parts. The owner fills the pad. The user sits on it.

| Pad | Owner | Where | User |
|---|---|---|---|
| Hood pad | every Front Clip | X ±2.6, Z -12.3..-6.0, top 3.45 | Hood |
| Deck pad | every Rear Deck | X ±4.8, Z 7.0..15.2, top 3.1..3.6 | Deck Trim |
| Roof pad | every cockpit | X ±3.7, Z -1.6..1.6, crown 4.65..4.9 | Roof |
| Cowl | every cockpit | Z -5.5..-4.0, top 3.0, no glass | Extras |
| Flank strip | cabin, clip and deck | flat side at X ±4.8, Y 0.2..3.0, Z -14.5..14.0 | Flanks |
| Rotor wells | Hover Rotors | centres X ±3.0, Z -11.2 and 10.4, diameter 3.6 at most | Fender Skirts cover them |
| Lamp zone, front | Front Clip | lamps at X beyond ±2.0 and above Y 1.4 | Front Chrome stays below 1.4 there |
| Lamp zone, rear | Rear Deck | lamps at X beyond ±1.8 and above Y 1.4 | Rear Chrome stays below 1.4 there |

## Seam rules

- End seams (cabin to clip, cabin to deck, clip and deck to chrome): painted bodies stop 0.2 short. Each side adds a dark `detail` collar that reaches the seam. The gap is 0.4 and never see-through.
- Top seams (Hood, Deck Trim, Roof, Extras): the module starts on the seam plane. The owner's pad sits 0 to 0.5 below it.
- Hover Rotors anchor to the cockpit floor only. One dark spine runs under the clip and deck and carries all four discs. Clips and decks never carry rotor parts.
- Flanks anchor on the cabin side. Long trim is cut into three pieces at Z -5.5 and 6.0 so the gaps stay open.
- Pipes start at the deck seam, run under the Rear Chrome, and rise only behind it (Z 17 or more).
- Tail fins live in Deck Trim. No Rear Deck may rise above 3.6, so any deck can take fins or stay shaved.

## Authoring rules for real meshes

1. Keep the body side flat at X ±4.8 from sill to beltline on cabin, clip and deck. Shape the nose ahead of Z -14.5 and the tail behind 14.0. Flank parts have nothing else to sit on.
2. Above the beltline stay inside X ±4.4 and behind Z -4.0. That step is what gives Extras a home.
3. A cockpit is known by its glass, pillars and roof length, not its height. Every roof crown is within 0.3 of 4.9. The Sled gets its chop from a raised sill (3.5) and slit glass.
4. Bonnets and boots stay within 0.5 of the seam across their pad. Character comes from the nose face, tail face, shoulders and plan shape.
5. Line the main crease up with the beltline (3.0). Spears and stripes then flow across the gaps.
6. Keep lamps in the lamp zones and bars under the bar line. A bumper never hides a lamp, whatever the pairing.
7. Rotors stay 3.6 across or less and above -1.6. Skirts drop to -1.35 and hide them. Other flanks leave them showing.
8. Author the +X half and mirror it. Give every part a paint channel. Chrome is `secondary`. Seat the driver at X -2.2, Z -0.3, head top 4.45 (Sled 0.2 lower).

## Result

Final validator line: `SPEC cruiser: 0 error(s), 3 warning(s) {'cockpits': 5, 'modules': 34, 'builds': 8, 'parts_in_builds': 1042}`

- The three warnings are "cockpit appears in fewer than 2 builds" for Hardtop, VIP and Kaido. The brief fixes eight builds and three of them share one cockpit, so five cockpits cannot all appear twice.
- Five cockpits: Hardtop, Sled, Finliner, VIP, Kaido. Builds run 111 to 148 parts. Builds 1 to 3 put the Lowrider kit on Hardtop, Sled and VIP. Builds 4 to 6 put Lead Sled, Fin Era and Kaido kits on the Finliner. Builds 7 and 8 mix cultures.
- A separate sampled check found every part truly inside its envelope, including the stepped ones.

## Open risks

- "Chop" from the Roof roster cannot be a Roof module. A chop lowers the cockpit's own roof. It is the Sled cockpit instead. Roof has Vinyl and Bubble. Both ride 0.25 above the Sled roof, which is the limit before they read as floating.
- Flat body sides are the price of free flank trim. Real meshes will want curved flanks. Allow 0.2 of crown at most, or spears will float.
- Rotors are a performance slot but sit hidden under skirts. They need a tell: glow colour, or showing during hover hop and tilt.
- The Pipes column is 2 studs deep, so Bamboo Stacks rake back 7 degrees at most. Kaido builds already reach Z -18.4 and 18.9 against the ±19 limit, and 9.5 high. Check garage, camera and lane width at 37 long.
- Front Chrome meets very different noses. The Tube Grille stands proud of the undercut Shark Nose. Judge it on a real mesh.
- Longroof (wagon) is not built. It fits the envelope on paper. Its long roof is untested with the short Roof pad.
- Tool notes: the validator tests vertices only, so a part could cut a corner of a stepped envelope unseen. The preview sorts faces by centre, so small trim on a large face can vanish in one view.
