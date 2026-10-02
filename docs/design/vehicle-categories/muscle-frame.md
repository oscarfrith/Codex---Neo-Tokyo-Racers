# Muscle: frame standard (round 2, after the third fix round)

Status: design exploration, 2026-10-01, second review fixes and a third fix round 2026-10-02. Grey-box only. Not game content and not approved.
Source: `scripts/vehicle_blockouts/gen/muscle.py` writes `scripts/vehicle_blockouts/specs/muscle.json`. Previews: `scripts/vehicle_blockouts/previews/muscle/`.

American muscle and pony cars as one-piece hover jets. Long bonnet, short deck, wide haunches. No wheels: each arch is blanked, vented or filled by a lift jet. The cabin sits well back: the bonnet is 11.3 studs, the cabin 8.2 and the tail 5.4 to 6.9. The body is about 10.9 W x 6.6 H x 25.4 L. With side burners, tail engine and spoiler the 15 builds measure 12.3 to 12.7 W, 6.6 to 8.1 H and 26.1 to 27.0 L, against a 10 x 6 x 24 target.

Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | Envelope (X, Y, Z) | Anchor (parent, pad) |
|---|---|---|---|
| Cockpit | Cabin | X ±4.8, Y -0.4..6.2, Z -2.0..6.2. Roofline box: X ±4.4, Y 3.3..6.2, Z 6.2..10.1 | Root |
| `FrontBody` | Nose Clip | X ±5.5, Y -0.4..3.3, Z -13.4..-2.0. Wing crowns and bonnet peak to Y 3.9. Arches left open | Cockpit, cowl seam at Z -2.0 |
| `RearBody` | Tail and Haunches | X ±5.5, Y -0.4..3.3, Z 6.2..13.2. Hips to Y 3.8 outside X 4.5. Centre bay behind Z 10.2 left open | Cockpit, back seam at Z 6.2 |
| `Engine1` | Hood Engine | X ±2.2, Y 3.3..5.3, Z -9.0..-2.6 | FrontBody, bonnet pad at Y 3.3 |
| `Engine2` | Tail Engine | X ±3.3, Y 0.3..4.2, Z 10.2..13.6 | RearBody, bulkhead at Z 10.2 |
| `Stabilisers` | Lift Jets | Four arch boxes: X 3.4..6.0 (mirrored), Y -1.5..1.7, Z -9.5..-5.7 and Z 6.4..10.2 | FrontBody and RearBody, arch roof at Y 1.7 |
| `Boost` | Side Burners | X 4.8..6.3 (mirrored), Y -1.4..0.3, Z -2.0..6.3 | Cockpit, sill rail outer face |
| `SidePods` | Rockers | X 4.8..5.6 (mirrored), Y 0.3..2.3, Z -2.0..6.2 | Cockpit, door skin |
| `FrontBumper` | Front Bumper | X ±5.6, Y -1.2..0.3, Z -13.4..-9.6. Bar layer: Y 0.3..1.5, Z -13.4..-12.4 | FrontBody, bumper pad at Y 0.3 |
| `RearBumper` | Rear Bumper | X ±5.6, Y -1.2..0.3, Z 10.2..13.6. Corner bars: X 3.3..5.6, Y 0.3..1.6, Z 12.2..13.6 | RearBody, bumper pad at Y 0.3 |
| `RearSpoiler` | Spoiler | Feet: X 3.3..4.5 (mirrored), Y 3.3..4.3, Z 10.2..13.2. Blade: X ±5.6, Y 4.3..7.0, Z 10.2..13.6 | RearBody, haunch pads at Y 3.3 |

Envelopes do not overlap. `Hood`, `Roof` and `Accessory` are not used.

## Where the four fundamentals sit, and why

- **Engine1, Hood Engine.** A turbine stands on the bonnet pad, just ahead of the cowl, where a blower would burst through. Every thrust face is 0.6 to 0.75 across and points up and back.
- **Engine2, Tail Engine.** A turbine pack sits in an open bay between the haunch tails, where the boot was. It fills the chase camera. Over-Under closes its bay with a body-colour tail panel; its two nozzles are 1.6 across. Inline Four carries a body-colour deck lid (Y 3.35..3.75) on four body-colour runners, and its outer jets sit 0.7 ahead of the inner pair. Slot Burner has three raised louvres stepped up to Y 3.94. Every engine now tops out at Y 3.75 or more, so a spoiler ramp never roofs a deep hollow.
- **Stabilisers, Lift Jets.** Hardware in each arch. Each option fills, blanks or vents its arch and shows an intake, a body and a glowing nozzle. Every option reaches past the body skin (front arch to X 5.7 or more, rear arch to X 5.6 or more; the skin is at 4.9 to 5.5). Jet bodies are `secondary`, not dark `detail`. Corner Turbines, Big 'n' Little and Vector Cans have thrust faces 1.0 to 1.1 across. The other three keep 0.6 to 0.7. In the rear arch nothing sits outboard of X 5.65 below Y -0.35: that lane belongs to the Side Burner exhaust. So the rear Corner Turbines cant out less than the front pair and their forward can stands nearly upright, the fat rear nacelle of Big 'n' Little rides high (Y 0.55) with its nozzle firing down and back, the Vector Can hangs straight in its yoke on a trunnion, and the Outrigger pod rides at Y 0.45.
- **Boost, Side Burners.** Afterburners hang under the sills where side pipes ran. The glow shows from the side and the rear three-quarter. `thrust` marks nozzles only: the long edge strip on Sill Slots is `neon` lighting. The four burners that exit at the rear arch end in a tip turned outboard and 2 to 8 degrees down, so the jet fires past the arch, not into the Lift Jet: Side Pipes 24 degrees, Bazookas 16, Sill Slots 17 (a flat duct), Underslung Twins 39 and 27 (the outer pipe ends 1.4 studs early, so the two tips sit in echelon). Megaphones and Lake Trios exit mid-sill, 2 studs or more ahead of the arch.

Cylinders run fore and aft or cant down, back and out. Every pod, can and turned-out tip is longer than it is wide: whole units run from 1.4 times (Skirted Triples) to 3.3 times (the thin front jet of Big 'n' Little). None is a disc, ring or drum.

## Datums and hardpoint pads

Datums (Y): hover plane -2.0, floor -0.4, sill 0.3, arch roof 1.7, belt stripe 2.35..2.65, beltline 3.3, roof 6.0.
Datums (Z): nose shelf -12.3, cowl seam -2.0, cabin back seam 6.2, engine bulkhead 10.2, standard tail face 12.1. Arch centres at Z -7.6 and 8.3, half length 1.9. The rear arch starts 0.2 behind the back seam and ends at the bulkhead.
Datums (X): door skin 4.75, arch back wall 3.3, Hood Engine pad half width 2.2 (the bonnet pad itself is 2.3), engine bay half width 3.3.

| Pad | Owner | Position | Lands here |
|---|---|---|---|
| Seam plates | Cockpit | Z -2.0 and Z 6.2, section X ±4.75, Y 0.3..3.3 | Nose Clip, Tail |
| Sill rail | Cockpit | Outer face X 4.75, Y -0.4..0.3, Z -2.0..6.2 | Side Burners, Rockers |
| Bonnet pad | FrontBody | Flat at Y 3.3, X ±2.3, Z -9.5..-2.0 | Hood Engine |
| Arch roof pads | FrontBody, RearBody | Flat at Y 1.7 over each arch, back wall at X 3.3 | Lift Jets |
| Bumper pads | FrontBody, RearBody | Underside at Y 0.3 behind the nose face and under the haunch tails | Bumpers |
| Deck pad | RearBody | Flat at Y 3.3, X ±4.4, Z 6.2..10.1 | Every roofline, bed and buttress |
| Bulkhead | RearBody | Z 10.2, X ±3.3, Y 0.3..3.3 | Tail Engine |
| Haunch pads | RearBody | Flat at Y 3.3, X 3.35..4.5, Z 10.2..11.4 | Spoiler feet |

## Kits

| Kit | Native cockpit | Hood Engine | Tail Engine | Lift Jets | Side Burners | Nose and tail |
|---|---|---|---|---|---|---|
| Classic | Fastback | Shaker Turbine | Twin Barrel | Corner Turbines (two cans per arch, splayed and canted out) | Side Pipes (turned-out tip) | Shark Nose (wing tips ahead of a recessed grille, deep brow), Coke Hips |
| Pro Street | Hardtop | Blower Stack (low wide case, fat zoomies) | Mono Turbine | Big 'n' Little (fat rear nacelle proud of the skin, thin canted front jet) | Bazookas (turned-out nozzle) | Tilt Nose (wedge), Tubbed Tail |
| Trans-Am | Notch | Cross-Ram Twins | Over-Under (stack in a tail panel) | Outriggers (louvred arch panel, outboard pod) | Megaphones (four-step flare) | Raked Nose (flat grille), Flared Kamm |
| Modern | Modern | Cowl Slot Turbine (flat twin-rotor body, slot nozzle) | Slot Burner (stepped louvres) | Vector Cans (one large can, yoke arm outside the skin) | Sill Slots (boxed intake and nozzle, flat duct turned out) | Bluff Nose (crowns, dome), High Deck |
| Pony | Ragtop | Quad Pack | Quad Corners | Glide Paddles (nacelle, fin and swept paddle) | Lake Trios | Pony Beak (V prow), Slant Deck |
| Restomod | Ute | Tunnel Ram (one tall ram stack) | Inline Four (lid on four runners) | Skirted Triples (half skirt, scoop, three cans) | Underslung Twins (two tips in echelon) | Stacked Blades (lamp towers, arrow prow, power bulge), Square Tail |

Each kit also has its own Rockers, bumpers and spoiler. The Restomod kit is a clean modernised classic: Rocker Tube, Roll Pan, Tucked Pan and Fin Bar (two low fins joined by a light bar). Six kits by six cockpits gives 36 builds, all shown in `matrix.png` and, front and rear, in `row_<cockpit>.png`. `mix_a.png` and `mix_b.png` show twelve builds with a random option in every slot. Spoiler feet stand wholly on the haunch pads (Z 10.3 to 11.4), so they are supported on all six tails. Anything further back hangs from the blade, above Y 4.3. The Ducktail is a 9.0 wide ramp on two full-length buttresses: its ends are closed and the slot under the middle shows the tail engine. The gap between the ramp and the engine under it is 0.1 to 0.55 studs for all six engines (0.55 over Inline Four, 0.36 over Slot Burner).

Cockpits differ in roofline and glass, not only paint. Fastback: narrow (X ±3.9), roof peak over the B-pillar, then one louvred slope from Z 2.3 to the bulkhead. Hardtop: widest and tallest (X ±4.5, Y 6.2), upright screen, long thick C-pillar, upright rear window, two flying buttresses with bare deck between. Notch: smallest greenhouse (X ±3.1, Y 5.6), screen base at Z 0.0, C-pillar ends at Z 6.7, the most flat deck. Modern: shoulder at Y 4.25, slit glass, chopped black roof at Y 5.05, screen raked from the cowl to Z 2.6, shoulders that run on to the end of the deck. Ragtop: open, frameless screen. Ute: upright screen under a peaked visor, sheer cab back at Z 3.1, low open bed. Whole-outline scores between the four closed cabins are now 0.15 to 0.18 (they were 0.08 to 0.17).

## Authoring rules for real meshes

1. Author every module in cockpit-root space. Do not move a mount.
2. Stay inside the slot envelope. Nothing may cross into another envelope.
3. Every cockpit ships the same chassis: sill rails, seam plates, door body to Y 3.3 and the belt stripe. Only the glass, roof and deck trim change.
4. A cockpit that raises its shoulder above the belt must ramp back to Y 3.3 before each seam.
5. Every Nose Clip keeps the bonnet pad, both arch roofs, the arch back wall and the cowl section. Every Tail keeps the deck pad, both arch roofs, the bulkhead and the haunch pads flat to Z 11.4. Spoiler feet stay on those pads.
6. A clip wider than the door skin tapers back to X 4.9 or less at its seam. The front wing tapers over 3.2 studs and the haunch kicks out over 1.2: that is the Coke-bottle waist. No step at either seam.
7. Modules land on pads only, never on a styled surface. Sit within 0.1 stud of the pad, or bridge a wider shadow gap (0.6 at most) with dark `detail` linkage.
8. The cockpit owns all glass and the roofline. Each arch, nose, hip and tail belongs to one slot only.
9. Engines, Lift Jets and Side Burners show an intake, a body and a `thrust` nozzle from outside. A nozzle or pod is longer than it is wide. No rings, discs or drums. A Side Burner that exits within 1.5 studs of the rear arch turns its tip outboard. A rear Lift Jet keeps out of the lane outboard of X 5.65 below Y -0.35.
10. A Lift Jet module must leave no empty arch: fill it with the jet, or close it with a panel, skirt or liner inside the module. Part of it must stand outside the body skin, so it shows from above.
11. Carry the belt stripe at Y 2.35..2.65 on every body part. Give every part a paint channel.
12. Options for one slot differ in outline: length, plan shape, height or count. Detail alone is not enough.

## Validator result

`SPEC muscle: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 60, 'builds': 15, 'worst_gap': 0.1, ...}`
`'min_distinctness': {'Engine1': 0.42, 'Engine2': 0.38, 'Stabilisers': 0.48, 'Boost': 0.39, 'FrontBody': 0.44, 'RearBody': 0.38, 'SidePods': 0.45, 'FrontBumper': 0.51, 'RearBumper': 0.47, 'RearSpoiler': 0.6, 'Cockpit': 0.27}`
`'min_distinctness_whole': {'Engine1': 0.31, 'Engine2': 0.34, 'Stabilisers': 0.37, 'Boost': 0.35, 'FrontBody': 0.05, 'RearBody': 0.05, 'SidePods': 0.44, 'FrontBumper': 0.37, 'RearBumper': 0.27, 'RearSpoiler': 0.44, 'Cockpit': 0.08}`

The first line is the free outline: the area every option shares is removed. It is the score the targets apply to (0.35 for big slots, 0.25 for bumpers and cockpits). The second line is the whole outline. It stays low for noses, tails and cockpits because they all carry the same pads, arches and chassis by rule. The whole-outline cockpit minimum (0.08) is Fastback and Ute. The lowest pair of closed cabins is Notch and Modern at 0.15. Worst contact gap 0.1 studs. `gen/muscle.py --table` prints every pair. The generator also checks the exhaust lane for all 36 Side Burner and Lift Jet pairings and exits with an error if one fails: `exhaust lane: 0 of 36 pairings fail (limit 25%); worst rear-exit face hidden from behind 20%, worst plume blocked 0%`. "Hidden from behind" is the share of a thrust face that rear Lift Jet parts cover, looking straight from behind. "Plume blocked" is the share of a 3 stud plume, fired along the nozzle axis, that meets a rear Lift Jet part.

## Open risks

- Megaphones exit mid-sill at Z 2.2, 4.2 studs ahead of the rear arch. Their plume is clear, but seen straight from behind 46 to 50 percent of the face sits in line with the rear Corner Turbines, Big 'n' Little or Vector Cans (32 with Skirted Triples, 14 with Outriggers). The mouth is 1.15 across in a 1.5 wide envelope, so it cannot move outboard. The check prints this and does not enforce it for mid-sill burners. Lake Trios stay at 19 or less.
- The exhaust lane costs some rear Lift Jet stance. The rear Corner Turbines now reach X 5.6 (the front pair 5.9), which is only 0.1 outside the widest tail. Bazookas with Corner Turbines is the tightest rear pairing at 20 percent hidden. The burner tips sit within 0.03 of the envelope edge at X 6.3.
- Close pairs: Fastback and Ute (0.27 against 0.25), High Deck and Square Tail (0.38), Twin Barrel and Inline Four (0.38; it was 0.42 before the deck lid), Side Pipes and Lake Trios (0.39). Fastback and Ute stay at 0.08 whole outline. Lower bed rails and a shorter cab were tried and gave 0.09. A bed cut short at Z 8.6 gave 0.115 and cost three other Ute pairs. Reaching 0.15 needs a restyle of one of the two. Three closed-cabin pairs sit at 0.15 with no margin. The Notch greenhouse is narrow and the Modern roof is very low; real meshes may want softer numbers.
- The largest build (Ute with its Restomod kit) has 217 parts against a limit of 220. The rear overhang is short (1.4 to 2.9 studs), so tails vary only in length, hip line and lower edge. Builds stay wider and longer than the target because the Side Burners and Tail Engine sit outside the body.
- A short nose or tail leaves a long bumper standing clear of the body: about 1 stud with Bluff Nose or Pony Beak and the Chrome Blade, and 0.7 with Flared Kamm and Chrome Quarters or Tucked Pan. The Ducktail also overhangs Flared Kamm by 0.9, on a raked buttress. Slot Burner still shows a dark burner box under its nozzle. The Modern kit's tail engine and boost are still flat slot burners. The Modern paint has a black secondary, so its Lift Jet bodies are dark; the glow and the outboard stance carry them. Arch panels and skirts sit at fixed X (4.72 to 5.25): flush or 0.35 proud on the narrowest clip, up to 0.5 recessed on the widest.
- In this round all twelve mixes were viewed front and rear at full size, with the matrix, the Ute row, the Lift Jet and Side Burner rows of the fundamentals sheet, and one-off renders of the twelve flagged pairings (rear three-quarter and straight behind) and of the Ducktail over three engines. The tips moved 0.2 studs or less after that. Other pairings are covered by the validator and the exhaust lane check only.
- `docs/design/vehicle-categories/muscle.md` (concept sheet) still uses the old names Skirted Vanes, Sports Bar, Step Bumper, Nerf Rail and Bed Tail.
