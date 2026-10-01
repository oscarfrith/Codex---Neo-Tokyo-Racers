# Rodder frame standard

Status: design exploration, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [rodder.json](../../../scripts/vehicle_blockouts/specs/rodder.json). Previews: [sheet](../../../scripts/vehicle_blockouts/previews/rodder/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/rodder/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/rodder/standard.png).

Rodder is a narrow cab at the back of two frame rails. An exposed engine sits on the rails between a grille plane and a firewall plane. Skinny hover pods hang on a beam axle at the front. Fat hover drums flank the cab. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Envelopes

| Slot | Player label | X | Y | Z | Anchors to |
|---|---|---|---|---|---|
| Cockpit | Cab | -3.25..3.25 | -0.9..5.8 | 1..12 | root |
| Engine1 | Engine Block | -2.7..2.7 | 0.6..3.8 | -12..1 | cab firewall, Z 1 |
| Engine2 | Rear Drums | 3.5..6.5, mirrored | -1.7..4.4 | 3.8..9.8 | cab hub flange, X 3.5 |
| Stabilisers | Front Axle | A: -3.6..3.6; B: 3.6..6.5, mirrored | A: -1.7..-0.4; B: -1.7..1.2 | -14.5..-9.5 | rail underside, Y -0.4 |
| SidePods | Fenders and Rails | ribbon of seven boxes, see below | | | cab rails, Z 1 |
| Boost | Headers | A: 3.1..5.6; B: 3.4..5.6, both mirrored | A: 0.6..5.2; B: 0.6..3.2 | A: -9..1; B: 1..3.3 | engine port rail, X 3.1 |
| FrontBumper | Grille Guard | A: -4.5..4.5; B: -2.7..2.7 | A: -1.5..3.8; B: 0.6..3.8 | A: -17..-14.5; B: -14.5..-12 | rail horns, Z -14.5 |
| RearBumper | Launch Gear | -4.5..4.5 | -1.8..2.2 | 12..19 | cab rear crossmember, Z 12 |
| RearSpoiler | Rear Rig | -5.5..5.5 | 2.2..9.8 | 12..16.5 | cab back, Z 12 |
| Hood | Hood | A: -2.7..2.7; B: 2.7..3.1, mirrored | A: 3.8..6.2; B: 1.0..3.8 | A: -12..1; B: -11..0.8 | engine end plates, Y 3.8 |
| Roof | Roof | -3.25..3.25 | 5.8..7.2 | 1..12 | cab roof rests, Y 5.8 |

Fenders and Rails ribbon (all but the slab are mirrored). It runs over the pod, down, along the cab, up and over the drum.

| Box | X | Y | Z | Holds |
|---|---|---|---|---|
| Rail slab | -3.6..3.6 | -0.4..0.6 | -14.5..1 | rails, crossmembers |
| Lamp column | 2.8..3.6 | 0.6..3.0 | -14.5..-11 | headlamp stalks, fender stays |
| Front shelf | 3.6..6.5 | 1.2..3.0 | -14.5..-9.5 | fender over the pod |
| Front drop | 3.6..6.5 | -0.9..3.0 | -9.5..-9 | fender falls to the board |
| Board strip | 3.6..6.5 | -0.9..0.6 | -9..3.3 | running board, step |
| Rear rise | 3.4..6.5 | -0.9..5.6 | 3.3..3.8 | rear fender leading face |
| Rear shelf | 3.4..6.5 | 4.4..5.6 | 3.8..9.8 | fender over the drum |

No two envelopes overlap. Accessory is not used. Built size: 13.0 wide, 30 to 32 long (34.6 with Wheelie Bars), 8.5 high with a Roll Hoop (11.3 with the Dragster Wing).

## Datums

| Datum | Value | Meaning |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing goes below -1.8. |
| Sill | Y 0.6 | Rail top. Cab, engine and headers sit on it. |
| Beltline | Y 3.6 | Cowl top, tub top, body moulding. |
| Hood line | Y 3.8 | Top of every engine. Underside of every hood. |
| Roof seam | Y 5.8 | Roofs start here. Cab roof rests stop at 5.4 to 5.7. |
| Firewall plane / grille plane | Z 1 / Z -12 | Back and front of the engine bay. |
| Rail section | X 2.3..3.1, Y -0.4..0.6 | Same section in the cab and in the rail slab. Paint Secondary. |
| Rear hub | X 3.25, Y 1.4, Z 6.8 | Drum axis. Largest drum 5.6 across, 2.7 wide. |
| Front hub | X 5.4 (±0.4), Y -0.25, Z -12.25 | Pod axis. Largest pod 2.8 across. |
| Port rail | X 2.7 to 3.1, Y 1.45..2.05, Z -8.6..-2.6 | Where engine flange meets header flange. |
| Induction pad | Y 3.4..3.8, Z -6.8..-4.4 | Where a scoop lands on any engine. |

## Seam rules

Every seam is a shadow gap of 0.15 to 0.5 with a dark Detail part across it.

- Firewall: engine rear plate ends Z 0.7, cab cowl starts Z 1.2. Slab rails end Z 0.9, cab rails start Z 1.2.
- Rear hubs: cab flange ends X 3.25, drum coupling starts X 3.5.
- Port rail: engine flange ends X 2.65, header flange starts X 3.15. The Hood side panel lives in this gap.
- Hood: end plates top out at Y 3.6 to 3.8, hood underside is 3.83 or higher.
- Roof: roof rests top out at Y 5.4 to 5.7, roof underside is 5.82 or higher.
- Rail horns: rails end Z -14.4, guard brackets end Z -14.55. Axle perch sits 0.1 under the rails.
- Rear: crossmember and back panel end Z 11.95, Launch Gear and Rear Rig start Z 12.1 to 12.2.

## Authoring rules (what the blockout taught)

1. Every cab ships the same chassis: cab rails, drum spindle with hub flanges, rear crossmember, a firewall face at Z 1.2. A cage or a teardrop tank carries all of it too. The first draft hid this inside wide bodies and the narrow cabs left the drums floating.
2. Every cab gives two roof rests: front at Z 2.5..5.5, rear at Z 8.3..9.3. Every roof is one rigid piece over both stations. The Slingshot needed a front hoop, the Rat Cab a bed hoop, the Lakester a dorsal spine.
3. Every engine ships two end plates: a grille shell, ring or hoop at Z -12..-11 and a rear plate at Z 0.3..0.7, both to the hood line. Hoods rest on the plates, never on the engine. A short Flathead and a long Twin Mill then take the same hood.
4. Headers start at the port rail and scoops land on the induction pad. Never shape either to one engine.
5. Pods, drums and fenders are all drawn round the hub datums. A pod set off-hub (first Suicide Front) sat outside the fender.
6. Rails paint Secondary everywhere. Mixed channels broke the frame in two at the firewall.
7. Header outlets face sideways or up. A rear-facing tip is blocked by the rear fender face 0.1 behind it.
8. The drum top (Y 4.2) is above the beltline, so only the greenhouse shows in side view. Put the cab's character in the roofline, the cowl and the tail. Author one side and mirror.

## Validator

`SPEC rodder: 0 error(s), 3 warning(s) {'cockpits': 5, 'modules': 32, 'builds': 8, 'parts_in_builds': 1149}`

The three warnings are "cockpit deuce / rat_cab / slingshot appears in fewer than 2 builds". Eight builds in the 3 + 3 + 2 pattern cannot show five cockpits twice each. Builds run 132 to 150 parts.

## Open risks

- Fender shelves are flat boxes. A fender cannot wrap below Y 1.2 at the front or Y 4.4 at the rear, and Dually Drums (4.6 across) leave 1.3 of air under the rear crown. Real arcs need chamfered pod and drum envelopes, or fenders that ship with the pod or drum.
- The frame is level. Rake reads only from hub heights. A 2 degree nose-down hover trim would sell it but is a driving change.
- Hood side panels have 0.4 of depth. Headers appear to pass through them, so the panel mesh needs port cut-outs.
- Roofs fit every cab but a closed roof over the Slingshot cage or the Lakester bubble looks odd. Use culture tags for shop suggestions.
- The hood line caps Radial Nine at 3.2 across. Length is 34.6 with Wheelie Bars against a 30 brief; cutting Launch Gear to Z 17 fixes it.
- The validator checks part vertices only and passes a multi-box envelope if any one box is reached. Parts that cross ribbon boxes, and the stays that hold the shelves, were checked by hand.
