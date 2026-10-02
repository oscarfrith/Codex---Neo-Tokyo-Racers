# Rift frame standard (round 2, after the verifier's fix round)

Status: design exploration, round 2, 2026-10-02. Primitive blockout only. Nothing here is game content or approved.
Spec: [rift.json](../../../scripts/vehicle_blockouts/specs/rift.json), written by [gen/rift.py](../../../scripts/vehicle_blockouts/gen/rift.py). Previews: [mix A](../../../scripts/vehicle_blockouts/previews/rift/mix_a.png) and [mix B](../../../scripts/vehicle_blockouts/previews/rift/mix_b.png) (every slot random), [matrix](../../../scripts/vehicle_blockouts/previews/rift/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/rift/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/rift/sheet.png), [standard](../../../scripts/vehicle_blockouts/previews/rift/standard.png), one `row_<cockpit>.png` per cockpit.

Rift is a classic coupé cut into floating sections. A centre spine (nose, cabin, tail) carries a front fender nacelle, a rocker and a rear-quarter pod on each side. There are no wheels or wheel-like parts. Engines, stabilisers and boost are separate jet modules. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Anchor |
|---|---|---|---|---|---|
| Cockpit | Cabin | -3.8..3.8 | 0..6.6 | -5.5..6.5 | root |
| FrontBody | Front Clip | nose -4.0..4.0; fenders 4.0..8.5, mirrored | nose 0..4.6; fenders 0.8..3.6; fender tail eave 2.5..3.6 | nose and fenders -16.5..-5.5; eave -7.6..-5.5 | cabin front seam, Z -5.5 |
| RearBody | Rear Clip | tail -4.0..4.0; pods 4.0..8.5, mirrored | tail 0..3.6; pods -0.8..4.6 | tail 6.5..14.0; pods 6.5..11.5 | cabin rear seam, Z 6.5 |
| SidePods | Rockers | 3.8..6.4, mirrored | 0..2.6 | -5.5..6.5 | cabin flank, X 3.8 |
| Engine1 | Front Engines | 4.0..8.5, mirrored | body -1.7..0.8; nozzle bay 0.8..2.5; top band 3.6..4.6 | body -18.0..-5.5; bay -7.6..-5.5; top band -14.0..-8.0 | fender underside, Y 0.8, and fender top, Y 3.6 |
| Engine2 | Rear Engines | 4.0..8.5, mirrored | -0.8..3.6 | 11.5..17.5 | pod bulkhead, Z 11.5 |
| Stabilisers | Stabilisers | A -9.0..9.0; B 6.4..9.0, mirrored | A -1.7..0; B 0..3.6 | -5.5..6.5 | cabin floor, Y 0 |
| Boost | Afterburner | -4.0..4.0 | 0.8..4.6 | 14.0..17.5 | tail panel, Z 14.0 |
| FrontBumper | Front Bumper | A -8.5..8.5; B -4.0..4.0 | A 0.8..3.6; B -1.2..0.8 | -18.0..-16.5 | fender tips, Z -16.5 |
| RearBumper | Rear Bumper | -4.0..4.0 | -1.2..0.8 | 14.0..17.0 | tail panel, Z 14.0 |
| RearSpoiler | Spoiler | A -4.0..4.0; B -8.5..8.5 | A 3.6..4.6; B 4.6..7.6 | A 6.5..14.0; B 6.5..17.5 | spoiler pad, Y 3.6 |

No two envelopes overlap. Hood, Roof and Accessory are not used. Built size: 17.6 to 17.9 wide, 34.8 to 35.2 long, 6.5 to 8.8 high. **Shared seam section.** Every cabin tub and every clip ends on the same painted section at the two seam planes: X ±3.4 (6.8 wide), Y 0.4 to 3.4. Each clip carries it as a shoulder collar 0.7 long, then tapers to its own nose or tail width. A cabin with lower shoulders (Stiletto, Mamba) still ends on the full section. So no cabin end face is ever bare. Rocker inner faces sit at X 4.0, so the gap to every cabin is the house 0.6.
**Pod end collar.** Every rear-quarter pod ends on the same painted section: X 4.9 to 7.7, Y 0.5 to 3.3 (2.8 square), Z 10.4 to 11.2. Each pod blends into it with ramps or tapers. Every rear engine is built to that section (within 0.4), so any engine meets a face of its own size on any pod. **Exhaust lane.** The front engine jets fire back from Z -5.8 at X 5.5 to 7.9, Y 0.6 to 2.3. The box X 5.5..7.9, Y 0.6..2.5, Z -5.5..-2.7 stays empty. Rockers stay inboard of X 5.4 ahead of Z -2.7. Stabilisers start behind Z -2.7. The lane is 2.8 long, so the datum `frontEnginePlumeMax` caps the flame effect at 2.5 studs. The noses straight behind the lane (Outrigger Nacelles, Gull Pods, Float Pods, Fuel Tanks) are dark scorch caps. Zoomie Rails are exempt: their pipes fire up at 50 degrees, over the rockers.

## Where the four fundamentals sit

| Slot | Position | Why |
|---|---|---|
| Engine1, Front Engines | Through each fender. Body and intake under the fender on a pylon. An intake stack on a pad on the fender top. The nozzle in a bay under the fender tail, facing back into the exhaust lane. | Each option has its own outline above the fender. The glow faces the chase camera across the open bay. |
| Engine2, Rear Engines | Behind each rear-quarter pod, bolted to its bulkhead behind the pod end collar, nozzles out the back to Z 17.5. | The chase camera sees both sets of nozzles either side of the tail. |
| Stabilisers | On a mount plate under the cabin floor, with outriggers into the open bay between fender and pod, behind the exhaust lane. Lift nozzles are canted 45 to 60 degrees outboard. Each unit has a neon intake on top. | The bay is empty in every kit, so the jets show from the front three-quarter, the side and above. |
| Boost, Afterburner | Centre tail, on the tail panel between the rear engines. | It is the middle of the chase view and never hidden by a spoiler. |

## Datums

| Datum | Value | Meaning |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing goes below Y -1.7. |
| Sill | Y 0.4 | Bottom edge of painted body on the spine and of the seam section. |
| Pod floor | Y 0.8 | Underside of every fender. Ceiling of the front engine bodies. |
| Stripe | Y 1.9 | Centre of the belt stripe and of most rift struts. |
| Beltline | Y 2.8 | Window sill and default shoulder. |
| Deck | Y 3.4 | Cowl, bonnet and boot surface at the seams. Top of the seam section. Fender and pad tops are 0.2 higher. |
| Seams | Z -5.5, 6.5, 11.5, 14.0 | Cabin to Front Clip; cabin to Rear Clip; pod bulkhead (rear engines); tail panel (afterburner, rear bumper). Painted body stops 0.3 short of the two cabin seams. The bay under each fender tail starts at Z -7.6. |

## Hardpoint pads

| Parent | Pad | Place |
|---|---|---|
| Every cockpit (shared chassis) | Floor pan | X ±1.4, Y 0..0.4, Z -4.2..5.2 |
| | Coupler flanges | X ±2.2, Y 0.5..2.6, on Z -5.5 and Z 6.5 |
| | Side hardpoints | X 2.0..3.8, Y 0.9..1.7, Z -3.2..-2.2 and 2.6..3.6 |
| Every clip | Coupler | X ±2.2, Y 0.5..2.6, the 0.3 next to its seam plane |
| | Shoulder collar (painted) | X ±3.4, Y 0.4..3.4, the next 0.7 (Z -6.5..-5.8 and 6.8..7.5) |
| Every Front Clip | Engine pad, under the fender | X 5.2..7.2, Y 0.8..1.0, Z -13.5..-9.5 |
| | Intake pad, fender top | X 5.4..7.0, Y 3.2..3.6, Z -11.8..-9.4 |
| | Nozzle bay bulkhead | X 4.9..7.7, Y 1.0..2.45, Z -7.9..-7.6 |
| | Bumper hardpoint, fender tip | X 5.6..6.8, Y 1.05..1.5, Z -16.5..-16.2 |
| | Centre bumper pad | X ±1.9, Y 0..1.4, Z -16.5..-16.0, on the bumper plane. Every nose reaches it, so any centre bumper closes onto it (0.05 to 0.1). |
| Every Rear Clip | Tail panel | X ±2.4, Y 0.4..3.2, Z 13.7..14.0. Afterburner above Y 1.0, bumper below. |
| | Spoiler pad | X ±2.0, Y 3.4..3.6, Z 11.0..13.5 |
| | Pod end collar (painted), then engine bulkhead | Collar X 4.9..7.7, Y 0.5..3.3, Z 10.4..11.2. Bulkhead X 5.3..7.1, Y 1.0..2.6, Z 11.2..11.5 |

## Kits

| Kit | Culture | Native cockpit | Front Engines | Rear Engines | Stabilisers | Afterburner | Clips, front and rear |
|---|---|---|---|---|---|---|---|
| Boulevard | Muscle | Brawler, 70s fastback: wide roof at Y 5.7, one painted slope to the tail, narrow rear glass between wide sail panels, flared haunches, cowl induction bulge at the front seam | Ram Turbine: one big turbine, chin scoop, ram scoop on top | Thunder Twins: a close pair of long slim cans | Outrigger Nacelles: two chunky nacelles a side (1.7 by 1.8 by 2.9) level with the sill, each on a painted pylon, with a dark deflector nose and a 0.9 lift jet below its outer flank | Quad Cannon: two-by-two block in a contrast shroud, raised | Twin Longhorn, Fastback Quarters |
| Quarter Mile | Pro Street | Outlaw, 60s notchback: the tallest roof (Y 6.3), upright screen, contrast roof with a visor, vertical rear screen, flat boot deck 4.3 long | Zoomie Rails: two slim tubes, twin upright stacks, swept zoomie pipes | Big Bertha: one long turbine, 2.8 across, 5.6 long, ram scoop, 1.5 glow in petals | Strake Rails: one rail 7.5 long, three flank nozzles | Big Bell: one bell (2.2) on a 2.5 long throat | Blower Rail, Tubbed (chamfered tubs that taper into the collar) |
| Folded Edge | Wedge Exotic | Stiletto, 70s wedge: low shoulders, narrow canopy, high engine deck, fins | Slot Ramjet: flat slab, slot intake on top, slot nozzle | Vector Slab: flat vectoring nozzle, intake slot on top, open glowing slot 2.6 by 0.8 split by a vane | Canard Vanes: swept vanes, 1.4 by 4.0 tip pod, winglet | Slot Burner: full-width slot | Pop-Up Prongs, Kamm Tail |
| Autostrada | Euro GT | Regent, grand tourer: slim glass teardrop, screen set forward, contrast roof band, glass fastback to the rear seam | Straight Six: long slim engine, cam cover with four trumpets, over-under megaphones | Trident: three pipes in a triangle behind a cowl | Gull Pods: slim pod held at the beltline on a gull arm | Wide Pair: two flat letterbox pipes in painted tail pods | Long Nose, Grand Tail |
| Riviera | Roadster | Mamba, open roadster: twin aero screens, twin headrest fairings | Quad Cluster: four slim jets, four trumpets, four small nozzles | Bullet: one slim tapered bullet on a chrome shoulder, dark shroud, 1.2 glow | Float Pods: one round pod a side, keel jet | Megaphones: two flared, swept up | Grand Quad, Boat Tail |
| Night Shift | Turbo Pony | Nightshift, 80s T-top notchback: lowest closed roof (Y 4.5), glass roof panels, raised targa hoop (Y 5.2) with an upright rear screen, then a flat louvred deck (Y 3.7) to the rear seam | Turbo Cassette: box, twin barrels, intercooler box on top, twin square outlets | Over-Under: two stacked cans | Fin Stacks: tall fin, jet pod at its foot | Tri-Stack: three stacked cans | Flip Nose, Slab Hatch |

Six cockpits, six kits, 60 modules, 19 builds (six native, six swapped, seven mixed; four of the mixed builds show Air Dam and Chin Bar on the Pop-Up Prongs and Blower Rail noses). Every kit also has its own Rockers, bumpers and spoiler. Push Bars are a low braced frame (Y 0.9 to 2.4) with a raked stay down to the hardpoint. Air Dam is a painted block (X ±3.2, Y 0 to 0.9, swept corners) that meets the light bar housing above and sits 0.05 from the centre bumper pad at the same height, with a dark skirt raked back under it; 56 to 59% of it lies within 1 stud of every nose (20% before). Every fender is at least 3.0 wide and 2.2 tall and runs tip to seam in paint. The narrowest centre nose and tail root are 4.4 wide (Grand Quad, Tubbed, Boat Tail).

## Authoring rules for real meshes

1. Stay inside the slot envelope. Leave 0.05 clear at every envelope face.
2. Carry every pad in the table at its exact place. Pads are flat and in the detail channel; the collars and tub ends are painted. Children land on pads only.
3. End every cabin and every clip on the shared seam section. Stop painted bodywork 0.3 short of each seam plane. Only dark couplers and struts cross a gap; no body shape bridges a rift. Give every part a paint channel.
4. Every cockpit uses the same chassis and tub. Put character in the cabin above the deck: roof height, roof length, glass area, screen rake. The cockpit owns all glass and the roofline.
5. No clip rises above the deck (Y 3.4) at a seam. Keep each fender underside flat at Y 0.8 over the engine pad, keep the bay under the fender tail open below Y 2.5, and reach the tip at Z -16.5 with an edge at least 0.5 tall. Bring the centre nose out to the centre bumper pad and keep lamps above Y 1.4 there. Only the rear-quarter pods may use Y -0.8..4.6. A spoiler wider than X ±4.0 stays above Y 4.6.
6. End every rear-quarter pod on the pod end collar. Build every rear engine to that section. Keep the exhaust lane empty. Every fundamental shows an intake, a body and a glowing nozzle from outside. Barrels and pods are longer than they are wide. No rings, discs, drums or tyre shapes.
7. A new option must differ in outline from every other option in its slot: length, height, count or plan shape. A bumper must look tied to a pointed nose and a blunt nose alike. No part sits more than 0.08 from the rest of its module (one group, or one per side; front engines two per side). The generator asserts this.

## Validator result

`SPEC rift: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 60, 'builds': 19, 'worst_gap': 0.05, 'min_distinctness': {'Engine1': 0.39, 'Engine2': 0.41, 'Stabilisers': 0.44, 'Boost': 0.38, 'FrontBody': 0.49, 'RearBody': 0.55, 'SidePods': 0.5, 'FrontBumper': 0.47, 'RearBumper': 0.47, 'RearSpoiler': 0.69, 'Cockpit': 0.48}, 'min_distinctness_whole': {'Engine1': 0.3, 'Engine2': 0.22, 'Stabilisers': 0.31, 'Boost': 0.34, 'FrontBody': 0.12, 'RearBody': 0.12, 'SidePods': 0.31, 'FrontBumper': 0.34, 'RearBumper': 0.35, 'RearSpoiler': 0.6, 'Cockpit': 0.07}, ...}`

`min_distinctness` is the free outline: the area every option shares is removed first. Every slot meets its target (0.35 for the big slots, 0.25 for the rest and for cockpits). `min_distinctness_whole` is the whole outline. It is low for cockpits (0.07), Front Clips (0.12) and Rear Clips (0.12) because the shared tub, collars and pads are most of each outline. Rear engines fell to 0.22 because they now share the collar section. That is the cost of the shared sections. Closest pairs: Ram Turbine and Quad Cluster 0.39, Big Bertha and Vector Slab 0.41, Quad Cannon and Big Bell 0.38, Brawler and Nightshift 0.48. Regent and Nightshift now score 0.63 free (0.08 whole): Nightshift is a notchback, Regent the glass fastback. Four builds have 220 parts, which is the limit.

## Open risks

- All six cabins share one 6.8 wide tub, and the cabin is about a third of the length. Roof heights now run from open (Mamba) through Y 4.5 to Y 6.3, but in the matrix a column still differs more by roof than by whole outline.
- Front engines occupy three places a side (under the fender, on its top pad, in the tail bay). A real module is one mesh that wraps the fender. Zoomie Rails and Quad Cluster put long tubes under the fender; with a dark secondary colour they can read as bare rails.
- The exhaust lane gives each front jet 2.8 studs of clear air. The 2.5 plume cap is a rule for the effects pass, not geometry: straight behind the lane the stabiliser and rocker noses still fill 19 to 39% of its section. Tubbed is still the bulkiest pod (4.0 wide at the shoulder). Fastback Quarters and Kamm Tail use the taller pod band (to Y 4.6); a future wide, low spoiler would collide with it.
- The Front Bumper envelope is 1.5 deep, so Push Bar stays and the Air Dam cannot run back along the fender or the nose; beside a pointed nose its outer thirds still stand ahead of open air, held by the light bar. Stabiliser jets are not at the fender tips, as the brief suggested: the tips carry the bumper hardpoint and the engine intakes. `FrontBody` and `RearBody` are new slot IDs. The live game has eight slots. Front engine options are 28 to 36 primitives each; a real mesh should merge them.
