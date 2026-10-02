# Exotic frame standard (round 2)

Status: design exploration, 2026-10-02, after the second review (per-module swap test). Primitive blockout only. Nothing here is game content or approved.
Spec: [exotic.json](../../../scripts/vehicle_blockouts/specs/exotic.json), written by [gen/exotic.py](../../../scripts/vehicle_blockouts/gen/exotic.py). Previews: [mix A](../../../scripts/vehicle_blockouts/previews/exotic/mix_a.png), [mix B](../../../scripts/vehicle_blockouts/previews/exotic/mix_b.png), [matrix](../../../scripts/vehicle_blockouts/previews/exotic/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/exotic/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/exotic/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/exotic/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/exotic/standard.png).

Exotic is the mid-engined supercar as a hover jet. Low, wide, cab forward, turbine behind the cabin, a jet at every corner. No wheels: the arches hold the stabilisers. Root space: +X right, +Y up, forward is -Z. Units are studs. Built size over 17 builds: 10.9 to 11.9 wide, 23.7 to 25.5 long (the Longtail kit is the longest), 6.3 to 7.9 high (the tall figures are the Track wing). No two envelopes overlap. Hood, Roof and Accessory are not used.

## Frame standard

| Slot | Player label | X | Y | Z | Anchors to |
|---|---|---|---|---|---|
| Cockpit | Cabin | tub ±3.6; glass ±4.5; buttress 2.0..3.6 mirrored; roof bridge ±2.0 | tub -0.4..2.6; glass 2.6..5.2; buttress 2.8..5.2; bridge 4.6..5.2 | tub and glass -5.2..2.8; screen overhang to -6.8 (Y 2.6..3.8); buttress and bridge 2.8..8.6 | root |
| FrontBody | Nose | centre ±3.6; fenders 3.6..5.5 mirrored | centre -0.4..2.6; fenders -0.4..3.0, but 1.8..3.0 over the arch | -11.6..-5.2 (arch cut-out -9.0..-5.8) | cockpit front seam, Z -5.2 |
| RearBody | Engine Deck | centre ±3.6; haunch and corner 3.6..5.5 mirrored; tail posts 2.6..3.6 mirrored | centre -0.4..2.8; shelf -0.4..1.2; posts 1.2..2.8; haunch and corner -0.4..1.8 | centre 2.8..9.4; shelf 9.4..11.0; posts 9.4..13.0 (tail booms); haunch 2.8..5.2; corner 8.4..11.0 | cockpit rear seam, Z 2.8 |
| SidePods | Side Pods | 3.6..5.6 mirrored; top strip 4.5..5.6 | -0.6..2.6; top strip 2.6..3.2 | -5.2..2.8 | tub side, X ±3.6 |
| Engine1 | Main Turbine | ±2.0 | 2.8..4.6 | 2.8..9.4 | deck bay pad, Y 2.8 |
| Engine2 | Side Engines | 3.6..5.6 mirrored | 1.8..3.6 | 2.8..11.4 | deck rail, X ±3.6 |
| Stabilisers | Stabilisers | arch 3.6..6.0 mirrored; tip strip 5.6..6.0 | arch -1.6..1.8; tip strip 1.8..3.2 front, 1.8..3.6 rear | front -9.0..-5.8; rear 5.2..8.4 | nose arch wall and deck rail, X ±3.6 |
| Boost | Afterburner | ±2.6 | 1.2..3.2 | 9.4..12.6 | deck tail wall, Z 9.4 |
| FrontBumper | Splitter | ±5.8 | under floor -1.4..-0.4; lip -0.4..1.0 | under floor -12.6..-9.0; lip -12.6..-11.6 | nose underside, Y -0.4 |
| RearBumper | Diffuser | ±5.8 | under floor -1.4..-0.4; valance -0.4..1.2 | under floor 8.4..12.4; valance 11.0..12.4 | deck underside, Y -0.4 |
| RearSpoiler | Wing | uprights 2.6..3.6 mirrored; plane ±5.8 | uprights 2.8..3.8; plane 3.8..6.6 | uprights 9.4..11.0; plane 9.4..12.6 | wing pads, Y 2.8 |

## Where the four fundamentals sit, and why

- **Main Turbine (Engine1)** sits on the deck behind the cabin, between the cockpit's buttresses. This is the mid-engine statement. It is open to the sky and to the chase camera. The Gull puts a glass cover over it. Every option fills the bay: 2.6 to 4.0 wide, 6.0 to 6.4 long, exit at the back of the bay, thrust 1.3 across or the same area. The Lance is a 1.4 tube under a snorkel with an open mouth. It flares to a fishtail 3.2 wide and 1.1 tall, with a thrust slot 2.9 by 0.8 in three cells. No wing roofs the exhaust: a wing leaves the centre open (nothing inboard of X 2.4) or carries its plane at Y 4.8 or higher. Measured against the wing alone in the rear three-quarter view, every wing leaves 61% or more of every rear-facing turbine glow in view. The old full-width Tail Fins deck hid it.
- **Side Engines (Engine2)** sit on the rear haunches, one each side, fed by the side pods. They replace the side-intake radiators of a real supercar. Nozzles point straight back and end at Z 8.75 to 11.35. Thrust is 0.65 to 1.1 across.
- **Stabilisers** fill the four arches. Each corner has a jet that points down or down and back, and none sits behind a plate. Skirts stop at Y 0.7 and blades start at Y 0.6, so the jet hangs in view below them. Twin Lift Cans are the only upright cans: short, tucked into the arch, ending at Y -0.7. Skirt Trios are three flat slot nozzles raked 35 degrees back from vertical, ending near Y -0.8. Blades and tip jets may stand outboard of the body.
- **Afterburner (Boost)** hangs in a notch in the centre of the tail, high, under the turbine nozzle. It is the last thing the chase camera sees. Cans are longer than wide: Twin Cannons are 1.8 across and 2.6 long. Tri Cluster is one fat short can over two slim long ones set 2.9 apart, so all three glows show.

## Datums and hardpoint pads

| Datum | Value | Meaning |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing goes below Y -1.6. |
| Floor | Y -0.4 | Underside of every body section. Splitters and diffusers hang below it. |
| Sill | Y 0.2 | Bottom edge of painted body. |
| Arch top | Y 1.8 | Stabilisers stop here. Fenders and side engines start here. |
| Beltline | Y 2.6 | Tub top, cowl top, base of all glass. Scuttle top is Y 2.5. |
| Deck pad | Y 2.8 | Bay pad and wing pads (top surface at Y 2.75). |
| Boost shelf | Y 1.2 | Floor of the afterburner notch. |
| Seams | Z -5.2, Z 2.8 | Nose to cabin, cabin to deck. Skins stop 0.1 short. |
| Arches | Z -9.0..-5.8, Z 5.2..8.4 | Fixed for every nose and deck. |

Pads every parent must carry, in the same place:

- Tub side: X ±3.5, Y 0..2.6, the full cabin length. Side pods land here. It is painted, so it may show.
- Scuttle: nose top at Y 2.5, full tub width, from Z -6.6 back. Wedge, Curve and Hyper screens overhang it.
- Front arch wall: X ±3.5, Y 0..1.0, Z -8.4..-6.4. Stabiliser arms start at X 3.65.
- Nose underside: Y -0.4, at least |X| 1.2 wide at Z -9.6..-9.1. Every splitter has a mount plate there.
- Bay pad: X ±1.9, top Y 2.75, Z 2.95..9.3. Turbine cradles start at Y 2.85.
- Deck rail: X ±3.55, Y 1.9..2.75, Z 2.9..9.35 for side engines. Arch plate under it, Y 0..0.9, Z 5.6..8.0, for stabilisers.
- Tail wall and shelf: Z 9.4, shelf top Y 1.15. Afterburner back plates start at Z 9.5.
- Wing pads: X ±2.65..3.55, top Y 2.75, Z 9.4..10.0. Every wing upright stands at Z 9.5..10.1.
- Deck underside: Y -0.4 (Y 0.0 on the smooth-belly Boat, Frame and Streamer decks). Every diffuser carries a plate at least ±2.6 wide at Z 8.7..9.9.

## Kits

| Kit | Culture | Native cockpit | Main turbine | Side engines | Stabilisers | Afterburner |
|---|---|---|---|---|---|---|
| Wedge | Wedge (70s and 80s) | Wedge: flat low roof at Y 4.05, screen far forward, hard notch down to low air boxes | Mono Turbine: one fat tube | Ram Boxes | Vector Pods: slim pod, angled nozzle | Quad Cans |
| Analogue | Analogue (90s) | Curve: teardrop, thin roof, tapered glass fastback, flying buttresses down the deck | Twin Spool: two tubes, no lid | Round Pods | Twin Lift Cans: short, in the arch | Twin Cannons |
| Hyper | Hypercar | Hyper: narrow canopy, shoulder wings, snorkel and dorsal fin | Top-Exit Core: round core, two upward stacks | Stacked Pairs | Aero Blades: nacelle under a swept blade | Tri Cluster |
| Track | Track Special | Spider: open top, low screen, roll humps | Eight Stack: trumpets, twin megaphones | Stub Burners: painted duct, fat burner | Outriggers | Slot Burner |
| Longtail | Longtail | Longtail: low bubble, roof scoop, rising twin fins | Lance Turbine: slim tube, snorkel, three-cell fishtail | Long Lances: exposed tube, bellmouth | Skirt Trios: three raked slot nozzles under a louvred skirt | Big Bore |
| Concept | Concept (show cars) | Gull: double-bubble glass roof to Y 4.85, raised hinge spine to Y 5.0, door cuts, falling glass turbine cover | Cross Plenum: box plenum, twin pipes | Ear Scoops: pipe to the tail | Canard Tip Jets | Split Slots |

Body modules, in the same kit order. Nose: Shovel, Droplet, Keel, Blunt, Lowline, Visor. Deck: Slab, Boat Tail, Tunnel Tail, Frame Tail, Streamer Tail, Kamm Tail. Side pods: Strake Intakes, Torpedo Pods, Floating Blades, Barge Trays, Full Fairings, Waisted Cheeks. Splitter: Chin Blade, Soft Lip, Keel Planes, Plough, Long Tongue, Scoop Bib. Diffuser: Strake, Smooth Valance, Venturi, Crash Bar, Tail Tray, Keel Fin. Wing: Poster, Bridge, Active Blade, Twin Element, Tail Fins, Split Winglets. The Concept kit is new: the contract lists five cultures and six cockpits, and each cockpit needs its own kit. Four modules were renamed in this pass (Cross Plenum, Skirt Trios, Soft Lip, Smooth Valance) because their drum and spat shapes are gone. Module ids are unchanged. How the closed decks differ: Slab is chopped square at Z 10.0 with tall square corners. Boat has no corners and a tail that narrows in plan. Streamer runs twin tail booms to Z 12.9. Frame is a painted engine cradle inside a tube frame, with vented haunches and short low corners. The Keel nose widens to the scuttle through two faceted shoulders, and its fender blade covers the arch. Changed in the second review, with no renames: Tail Fins are now two outboard tail planes (X 2.6 to 5.4) with a rising fin each and an open centre. Split Winglets open from X 2.4. Poster and Bridge planes moved up to Y 4.8 and 4.85. Crash Bar is a painted beam at Z 11.0 to 11.4 standing on a painted lower valance, with no arms and no daylight under it. Venturi ends at Z 11.3 and its fog light is now a rain light on the fin end.

## Authoring rules for real meshes

1. Model in cockpit-root space. Mount at the root origin. Never move a mesh to make it fit.
2. Stay inside your slot envelope. No exceptions for "small" overhangs.
3. Every cockpit ships the same tub: floor, seam plates, tub sides, cowl and shelf. Only glass, roof and the parts in the buttress and bridge zones change.
4. Every nose and deck ships every pad above, at the listed place and size. Shape is free around the pads.
5. A module touches pads only. It never rests on a fender, haunch, roof or another module's skin.
6. Stop each skin 0.1 short of its seam. Fill the gap with dark `detail` linkage. Keep gaps between 0.2 and 0.6.
7. Finish every face. Noses, decks and pods may be open or short, so the tub side, the arch wall, the deck rail and all stabilisers are seen from every side.
8. No wheels and nothing wheel-like. A cylinder is a pod, can or nozzle and is longer than it is wide. No cylinder lies across the vehicle: the spec has no `cyl_x` part.
9. Each engine, stabiliser and afterburner shows an intake, a body and a glowing `thrust` nozzle. Do not bury them. A module never brings its own glass.
10. The cockpit owns all glass and the roofline. Glass may overhang the side pods above Y 2.6, out to X ±4.5.
11. Keep the turbine and its exhaust in view. Cockpit parts over the bay must be glass, a spine no wider than 0.6, or fins and buttresses at X 2.0 or wider. A wing has nothing inboard of X 2.4 below Y 4.8.
12. Tag every part with a paint channel. Belt stripe and accents use `secondary`.

## Validator output

`SPEC exotic: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 60, 'builds': 17, 'worst_gap': 0.45, 'min_distinctness': {'Engine1': 0.41, 'Engine2': 0.37, 'Stabilisers': 0.47, 'Boost': 0.42, 'FrontBody': 0.42, 'RearBody': 0.45, 'SidePods': 0.44, 'FrontBumper': 0.41, 'RearBumper': 0.39, 'RearSpoiler': 0.52, 'Cockpit': 0.41}, 'min_distinctness_whole': {'Engine1': 0.22, 'Engine2': 0.3, 'Stabilisers': 0.4, 'Boost': 0.37, 'FrontBody': 0.16, 'RearBody': 0.1, 'SidePods': 0.41, 'FrontBumper': 0.31, 'RearBumper': 0.27, 'RearSpoiler': 0.45, 'Cockpit': 0.12}, ...}`

No warnings. `min_distinctness` scores the free outline: the area every option in a slot shares is removed first. `min_distinctness_whole` scores the whole outline. Every slot clears its target on the free outline (0.35 for the big slots, 0.25 for bumpers and cockpits). The closest pairs are Stub Burners and Long Lances (0.37), Crash Bar and Smooth Valance (0.39), Lance Turbine and Top-Exit Core (0.41), Chin Blade and Plough (0.41), the Wedge and Curve cockpits (0.41), Twin Cannons and Tri Cluster (0.42) and the Droplet and Blunt noses (0.42). The pairs the second review named now score: Skirt Trios and Twin Lift Cans 0.47, Wedge and Gull cockpits 0.75 (0.28 whole). `py -3 scripts/vehicle_blockouts/gen/exotic.py --report` prints both scores for every pair.

## Open risks

- **Whole-outline scores stay low for noses, decks and cockpits** (0.16, 0.10 and 0.12). The shared tub, scuttle, bay pad, rails, shelf and wing pads are most of each outline. The options differ in the part that is free. A smaller fixed core would be a round 3 change to the standard.
- The Wedge and Curve cockpits are the closest pair. Both have shoulders that run down the deck. Curve is taller (5.1 against 4.1), narrower and falls to the rear.
- The Analogue kit is still mostly round pods and upright cans. The lift cans are now short and sit in the arch, but the kit needs real meshes to look sleek. Its Bridge wing stands tall (plane at Y 4.85 to 5.3) to clear the exhaust.
- The Longtail cockpit is no longer than the others: the buttress zone ends at Z 8.6. The Longtail kit carries the length (tail booms, lances, tail deck and tray).
- The Visor nose and the Tunnel and Kamm decks leave the arches open by design. The stabiliser is then the corner of the car and must look finished.
- Slab, Boat, Tunnel and Frame decks end their wing pads at Z 10.0, so long wing roots (Bridge, Tail Fins) overhang by up to 0.9. Length is 23.7 to 25.5 against a 23 target. Width reaches 11.9 with blades and canards. The diffuser envelope allows nothing above the floor ahead of Z 11.0. So the Crash Bar cannot move closer than Z 11.0, and on the Slab and Frame decks (tails at Z 10.0 and 9.9) a 1.0 stud step shows between tail and bar. The painted valance closes it from below. Moving the bar in needs a change to the standard.
- From a low side view the side engines and buttresses hide part of the main turbine. The chase camera sees it. From the three-quarter view an upright fin (Tail Fins, the Split Winglets fence) still hides part of the near nozzle of a twin-nozzle turbine: 61% to 76% stays in view.
- Not built or tested in Studio. Only the blockout renderer has seen these parts.
