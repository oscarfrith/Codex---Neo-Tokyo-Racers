# Agent D: P07, P08 and bridges XD1

Generated specs (run `py -3 P07.py`, `py -3 P08.py`, `py -3 XD1.py` from this folder). Every script saves through sgspec with no warnings, then runs `dlib.check`. That check flags parts over a road (the underside must clear the road top by 60), ground-level parts within 8 studs of a road, coplanar faces with the same normal that are not hidden, parts that float without touching the ground or the neighbouring spec, and a top outside Y480–850.

| spec | title | lean | tris | parts | kit | top Y |
|---|---|---|---|---|---|---|
| P07 | Kofu Stack | metabolist | 18,928 | 137 | 96 | 816 (sphere frame; C2 core 800) |
| P08 | West Gate Estate | blocks | 19,744 | 289 | 110 | 843 (drum mast; tall slab 760) |
| XD1 | P07–P08 bridges | mixed | 2,136 | 4 | 6 | 494 |

## P07: Kofu Stack (Tange Yamanashi and Nakagin)
- **Cores:** six cylindrical service cores (SG Capsule Panels) on a 160×240 grid at x −1700/−1540/−1380 and z 4880/5120. Tops are 800, 780, 740, 710, 600 and 556, each with a dark cap and service rings.
- **Trays:** eleven floor trays span between the cores at staggered levels from Y280 to 760. Their E–W rows sit at z 4840–4920 and 5080–5160, and their N–S spines at x −1700, −1540 and −1380. The gaps between them leave sky visible through the lattice from every side.
  - Each tray has a 4-stud-deep SG Windows Capsule (or SG Windows Blocks) glazing recess between chunky tray slabs, with a mid slab on the 80-tall trays.
  - Some bays carry SG Patched Panels infill.
  - N4 cantilevers 120 studs off C2, and S4 rides on C4's cap.
- **Sphere:** a Fuji TV-style sphere sits in a frame on the high M1 spine (Y760–816).
- **Capsules:** 23 Nakagin capsule_units in clusters on the free lengths of the cores. The largest cluster faces west over the open lot and the ring road.
- **Podium:** a 40-tall market podium.
  - Shopfronts, shutters and neon strips sit under canopies on the N, S and E streets.
  - Graffiti covers the whole west wall, with four market stalls and vending machines in front of it.
  - Graffiti bands run above the canopies.
  - The podium roof carries a chain-link ball court, a shanty layer of rooftop shacks, water tanks and a steel stair up to the E1 spine.
- **Clutter:** laundry lines and AC units in the tray recesses, and masts, tanks and dishes on the core caps.

## P08: West Gate Estate (Western City Gate / Genex)
- **Twin slabs:** the west slab is x −1176..−1096, rising to 680 with a setback upper part to 760 on its north 240. The east slab is x −936..−856, rising to 556, with a 3-tile cantilever (560–680) that steps 40 studs out over the north street on two wedge corbels.
- **Gate bridge block:** x −1096..−936, z 4970–5050, Y600–686, with a small lit estate sign on its north face. You look through the gate from the north street and from the south.
- **Service tower:** a Genex-style detached tower (40×40, to Y780) stands in the gate gap. It is tied to the tall slab by four link bridges and carries the glazed lookout drum and a short mast (top 843).
- **Facades:** every long face is one deep 40×40 coffer grid over SG Windows Blocks.
  - Fins are 2 studs thick and 7 deep; bands are 3 tall and 8 deep (12 deep on the courtyard access-gallery faces).
  - Details: SG Patched Panels closed-in balconies, balcony_run_40 balconies, laundry and AC units.
  - Blank SG Weathered Concrete gables frame the grids.
  - Graffiti murals cover the lower storeys of the north gables, and a lit vertical sign hangs on the east slab's gable.
- **Walk-up:** an L-shaped deck-access block along the east street (north part to 360, south part to 440) and a south wing to 400.
  - Exterior stair stacks run up the east slab's south gable and the courtyard side.
  - The courtyard holds a chain-link car pound and sheds.
- **Ground storey:** garages with Metal Shutters, lit shops, neon strips and graffiti bays on the street faces. The gate court has market stalls, vending machines, a bench and a row of shuttered garages.
- **Rooftops:** a roof village of add-on shacks on the east slab, plus tanks, dishes and masts.

## Bridges (XD1.json, own spec, id "XD1")
The contract lets owners add bridges inside their own parcel pair. These bridges leave both parcels, so they are saved as a separate spec, the same way as X1–X6. The assembler places spec ids that are not in parcels.json in the nearest block.
- **a) Metabolist tube:** 3 × bridge_tube_40, centre Y480, z 4880, x −1290 → −1170. It runs from P07 tray N2 (east end x −1290) to the west slab's west face, entering between the fins at z 4860 and 4900. Underside Y471 (road top 201). SG Capsule Panels collars sit at both ends.
- **b) Steel truss:** 3 × bridge_truss_40, centre Y320, z 5120. It runs from P07 tray S1 to the west slab. Underside Y312. Concrete portals sit at both ends.
- No contract bridge (X1–X6) lands on P07 or P08.

## Integration notes
- **Variant base materials:** the SG Windows Blocks, SG Windows Capsule and SG Patched Panels parts use `SmoothPlastic`. The SG Weathered Concrete, SG Capsule Panels and SG Graffiti A/B parts use `Concrete`, matching the bases in variants.json. Windows Day is not used.
- **Setbacks and roads:** ground-floor walls sit at least 28 studs from the road edges; pavement space is left for the streetscape. Upper grids, caps and the cantilever stay inside the parcels (P08 min x −1186 against the road at −1204.5). Nothing sits on a road.
- **Layers:** balconies, laundry and AC units in the facade grids are on LOD2; everything else is LOD4.
- **Detail scale:** the facade detail is on the 20/40 grid. Windows come only from the tile variants, the fins, bands and slabs are at least 2 studs thick, and there is no greebling.
- **Tri headroom:** both buildings are close to the 20k limit. The kit counts in kit_catalog.json are maximums, so the real totals should drop after the FBX import. If trimming is needed, AC units and balconies are the cheapest to drop.

## Files
- `P07.py`, `P08.py`, `XD1.py`: generators. `dlib.py` holds the shared helpers and self-checks.
- `preview_d.py`: a copy of common/preview.py (paths fixed) that also colours the SG Windows variants blue and SG Graffiti pink, so facades read in Workbench. Run it the same way as preview.py.
- `preview/`: final renders with neighbours (`--all-specs`). `preview/it1`–`it4` hold the earlier iterations:
  - it1: sparse lattice.
  - it2: densified lattice, more trays and shacks.
  - it3: first P08 with the XD1 bridges.
  - it4: service tower, drum and wing setback, with neighbours.
