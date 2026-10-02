# Muscle: frame standard (round 2, after the second review)

Status: design exploration, 2026-10-01, second review fixes 2026-10-02. Grey-box only. Not game content and not approved.
Source: `scripts/vehicle_blockouts/gen/muscle.py` writes `scripts/vehicle_blockouts/specs/muscle.json`. Previews: `scripts/vehicle_blockouts/previews/muscle/`.

American muscle and pony cars as one-piece hover jets. Long bonnet, short deck, wide haunches. No wheels: each arch is blanked, vented or filled by a lift jet. The cabin sits well back: the bonnet is 11.3 studs, the cabin 8.2 and the tail 5.4 to 6.9. The body is about 10.9 W x 6.6 H x 25.4 L. With side burners, tail engine and spoiler the 15 builds measure 12.3 to 12.6 W, 6.6 to 8.0 H and 26.1 to 27.0 L, against a 10 x 6 x 24 target.

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
- **Engine2, Tail Engine.** A turbine pack sits in an open bay between the haunch tails, where the boot was. It fills the chase camera. Over-Under closes its bay with a body-colour tail panel; its two nozzles are 1.6 across.
- **Stabilisers, Lift Jets.** Hardware in each arch. Each option fills, blanks or vents its arch and shows an intake, a body and a glowing nozzle. Every option reaches past the body skin (to X 5.7 or more; the skin is at 4.9 to 5.5). Jet bodies are `secondary`, not dark `detail`. Corner Turbines, Big 'n' Little and Vector Cans cant their nozzles outboard and have thrust faces 1.0 to 1.1 across. The other three keep 0.6 to 0.7.
- **Boost, Side Burners.** Afterburners hang under the sills where side pipes ran. The glow shows from the side and the rear three-quarter. `thrust` marks nozzles only: the long edge strip on Sill Slots is `neon` lighting.

Cylinders run fore and aft or cant down, back and out. Every pod and can is longer than it is wide: from 1.4 times (Skirted Triples) to 3.3 times (the thin front jet of Big 'n' Little). None is a disc, ring or drum.

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
| Classic | Fastback | Shaker Turbine | Twin Barrel | Corner Turbines (two cans per arch, splayed and canted out) | Side Pipes | Shark Nose (wing tips ahead of a recessed grille, deep brow), Coke Hips |
| Pro Street | Hardtop | Blower Stack (low wide case, fat zoomies) | Mono Turbine | Big 'n' Little (fat rear nacelle proud of the skin, thin canted front jet) | Bazookas | Tilt Nose (wedge), Tubbed Tail |
| Trans-Am | Notch | Cross-Ram Twins | Over-Under (stack in a tail panel) | Outriggers (louvred arch panel, outboard pod) | Megaphones (four-step flare) | Raked Nose (flat grille), Flared Kamm |
| Modern | Modern | Cowl Slot Turbine (flat twin-rotor body, slot nozzle) | Slot Burner | Vector Cans (one large can, yoke arm outside the skin) | Sill Slots (boxed intake and nozzle) | Bluff Nose (crowns, dome), High Deck |
| Pony | Ragtop | Quad Pack | Quad Corners | Glide Paddles (nacelle, fin and swept paddle) | Lake Trios | Pony Beak (V prow), Slant Deck |
| Restomod | Ute | Tunnel Ram (one tall ram stack) | Inline Four | Skirted Triples (half skirt, scoop, three cans) | Underslung Twins | Stacked Blades (lamp towers, arrow prow, power bulge), Square Tail |

Each kit also has its own Rockers, bumpers and spoiler. The Restomod kit is a clean modernised classic: Rocker Tube, Roll Pan, Tucked Pan and Fin Bar (two low fins joined by a light bar). Six kits by six cockpits gives 36 builds, all shown in `matrix.png` and, front and rear, in `row_<cockpit>.png`. `mix_a.png` and `mix_b.png` show twelve builds with a random option in every slot. Spoiler feet stand wholly on the haunch pads (Z 10.3 to 11.4), so they are supported on all six tails. Anything further back hangs from the blade, above Y 4.3. The Ducktail is a 9.0 wide ramp on two full-length buttresses: its ends are closed and the slot under the middle shows the tail engine.

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
9. Engines, Lift Jets and Side Burners show an intake, a body and a `thrust` nozzle from outside. A nozzle or pod is longer than it is wide. No rings, discs or drums.
10. A Lift Jet module must leave no empty arch: fill it with the jet, or close it with a panel, skirt or liner inside the module. Part of it must stand outside the body skin, so it shows from above.
11. Carry the belt stripe at Y 2.35..2.65 on every body part. Give every part a paint channel.
12. Options for one slot differ in outline: length, plan shape, height or count. Detail alone is not enough.

## Validator result

`SPEC muscle: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 60, 'builds': 15, 'worst_gap': 0.1, ...}`
`'min_distinctness': {'Engine1': 0.42, 'Engine2': 0.4, 'Stabilisers': 0.47, 'Boost': 0.39, 'FrontBody': 0.44, 'RearBody': 0.38, 'SidePods': 0.45, 'FrontBumper': 0.51, 'RearBumper': 0.47, 'RearSpoiler': 0.6, 'Cockpit': 0.27}`
`'min_distinctness_whole': {'Engine1': 0.31, 'Engine2': 0.37, 'Stabilisers': 0.35, 'Boost': 0.32, 'FrontBody': 0.05, 'RearBody': 0.05, 'SidePods': 0.44, 'FrontBumper': 0.37, 'RearBumper': 0.27, 'RearSpoiler': 0.44, 'Cockpit': 0.08}`

The first line is the free outline: the area every option shares is removed. It is the score the targets apply to (0.35 for big slots, 0.25 for bumpers and cockpits). The second line is the whole outline. It stays low for noses, tails and cockpits because they all carry the same pads, arches and chassis by rule. The whole-outline cockpit minimum (0.08) is Fastback and Ute. The lowest pair of closed cabins is Notch and Modern at 0.15. Worst contact gap 0.1 studs. `gen/muscle.py --table` prints every pair.

## Open risks

- Three pairs sit close to their targets: Fastback and Ute (0.27 against 0.25), High Deck and Square Tail (0.38), Side Pipes and Underslung Twins (0.39). Three closed-cabin pairs sit at 0.15 whole outline, which is the review's aim, with no margin. The part count is tight too: the largest build (Ute with its Restomod kit) has 219 parts against a limit of 220. The Notch greenhouse is now narrow (6.2 wide on a 9.5 wide body) and the Modern roof is very low (1.75 above the belt). Both were pushed to separate the cabins. Real meshes may want softer numbers.
- The rear overhang is short (1.4 to 2.9 studs), so tails vary only in length, hip line and lower edge. Builds stay wider and longer than the target because the Side Burners and Tail Engine sit outside the body.
- A short nose or tail leaves a long bumper standing clear of the body: about 1 stud with Bluff Nose or Pony Beak and the Chrome Blade, and 0.7 with Flared Kamm and Chrome Quarters or Tucked Pan. The Ducktail also overhangs Flared Kamm by 0.9, on a raked buttress. A spoiler cannot go below Y 4.3 over the engine bay, so the Ducktail always bridges the bay one stud above the deck. Its slot is deepest over Inline Four (1.55 studs).
- With Bazookas and Big 'n' Little the burner fires 0.2 studs ahead of the rear nacelle intake. It reads as two units, but it is close. The Modern kit's tail engine and boost are still flat slot burners. The Modern paint has a black secondary, so its Lift Jet bodies are dark; the glow and the outboard stance carry them.
- Arch panels and skirts sit at fixed X (4.72 to 5.25). On the narrowest clip the panel is flush and the skirt stands 0.35 proud; on the widest they sit up to 0.5 recessed.
- In this round all twelve mixes were viewed front and rear at full size after the last change, with 12 matrix cells, the Fastback row, parts of the Hardtop, Notch and Modern rows and the fundamentals sheet. Other pairings are covered by the validator's contact check only.
- `docs/design/vehicle-categories/muscle.md` (concept sheet) still uses the old names Skirted Vanes, Sports Bar, Step Bumper, Nerf Rail and Bed Tail.
