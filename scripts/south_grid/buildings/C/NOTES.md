# Agent C: P05, P12 (+P06 landmark), X6

Generators: `P05.py`, `P12.py`, `X6.py` (run from this folder; `python P05.py` etc.). Shared helpers are in `_cb.py`: bounds-based parts, storey levels, balcony plates and fins, and material presets. `_plan.py` checks road clearance and draws a top-down plan (`preview/plan_C.png`). `_render.sh <outdir> <cams...>` runs preview.py with `--all-specs`.

| spec | tris | parts | kit | bounds (min..max) |
|---|---|---|---|---|
| P05 | 18586 | 149 | 105 | 1358,100,4086 .. 1746,697,4563 |
| P12 | 16372 | 189 | 116 | 1146,200,4787 .. 1760,999,5209 |
| X6 | 240 | 20 | 0 | 1432,326,4558 .. 1468,384,4796 |

All three save with no warnings. `_plan.py` reports 0 road clashes: no element overlaps a blockout road footprint below road top + 60.

## P12 + P06: THE BEACON (lean: blocks, ground Y200)

A Trellick / Western City Gate type landmark, one spec with id `P12`.

- **Podium** x1170–1510, z4800–5200, top Y400.
  - Pit-garage shutters with piers, 2 storeys.
  - A 3-storey colour-bombed band (`SG Graffiti A`) wrapping all four faces.
  - 10 storeys of flats (`SG Windows Blocks`) with wrap-around balcony trays (`SG Patched Panels`) and fins every 40.
  - Roof: football cage (chainlink), tanks, shacks, dishes, laundry.
- **Slab tower** where P06 stood: x1250–1490, z4880–4970, Y405 to Y872, plant room and tanks to about Y920.
  - Open pilotis floor, then 34 storeys.
  - The north face carries a deep balcony grid: one plate per storey, plus fins every 40.
  - The south face has skip-floor access decks every third storey.
  - Solid board-marked end walls; the west end wall has a mural (`SG Graffiti B`).
  - A 2-storey glazed **sky-street void** about two-thirds up breaks the slab and reads from far away.
- **Detached service core** x1530–1580, z4900–4950. It rises from the ground (graffiti base) to Y876.
  - Glass stair and lift slots, two thin orange neon edge strips.
  - **Enclosed skybridges** at every access-deck level (every 3 storeys), plus a 2-storey top link.
- **Crown**: a cantilevered boiler house (x1505–1605, z4875–4975, Y872–918) on four wedge corbels.
  - Louvre-fin kit on all faces, a thin red neon ring, and a lattice mast (antenna_mast ×1.15) with a red beacon.
  - **Top 998.8.**
- **West stair tower** x1150–1194, z4936–4984, to Y533. It receives **X3** (owner F) and links to the slab west end at Y480.
- **East wing** x1620–1744, z4806–5046, top about Y387.
  - A deck-access slab over lock-ups, with E/W balconies, stacked exterior stairs on the east face, and a market stall and vending machines at the north end.
  - A deck link to the core.

## P05: HARBOUR STACK (lean: hybrid, ground Y100)

- **N1 waterfront slab** x1360–1740, z4106–4180.
  - Shops and garages, a mural band, then flats with balconies on both faces.
  - It steps from Y380 (west) down to Y300 (east), with a rooftop cage court on the low roof.
  - A graffiti-based **harbour stair tower** marks the step. It only protrudes to z4088 because the Y150–201 ramp road edge is at about z4075 there.
  - The east end wall has a mural facing the wedge lot.
- **W1 west slab** x1386–1466, z4226–4556, top about Y553. It runs north–south on the x≈1293 road.
  - The west face has a deep balcony grid; the east face has sparser fins and AC units.
  - 3 deck-access links to N1. The south end wall has a mural and is where **X6** lands.
- **S1 south slab** x1484–1744, z4506–4556, top Y300. It closes the courtyard and faces the step and The Beacon.
- **M1 Metabolist capsule stack**: core at x1640, z4430.
  - A market-hall base, then 10 porthole trays (`SG Windows Capsule` over `SG Capsule Panels` slabs). The trays alternate axis 0/90°, taper towards the top, and leave 2 void levels where 16 capsule units plug into the core.
  - A sphere crown in a ring frame with a cyan neon ring. **Top 697.**
  - A 3-segment `bridge_tube_40` tube bridge to W1 at about Y433.
- Courtyard: market stalls and vending machines.

## Bridges

**X6** (owner C) is a Blocks enclosed slab bridge.
- Construction: 30-deep box girder, patched parapets, a glazing band, a roof slab, and mullion fins every 40.
- Lighting: sodium neon strips.
- Landing collars at both ends.
- Centre line **x = 1450**, width 24, deck top **Y360**.
- It runs from the P05 W1 south mural face at **z = 4558** to the P12 podium north deck edge at **z = 4796**.
- Both landings are inside my own buildings. The P12 podium fin at x1454 is omitted so the collar sits clean.
- Deck and centre line are exactly as in the contract; only the span endpoints follow the facades (4558 and 4796 instead of 4576 and 4780).
- Clearance over the step roads: the underside is at Y326, so 225 over the Y101 road and 125 over the Y201 road.

**X3 landing** (owner F): a lip at x1146–1150, z4946–4974, top **Y470**, on the west stair tower. It has a dark opening (Y470–490) and an orange light. F's X3.json (x1030–1148, Y464–490, z4947–4973) meets it.

## Grid and detail

- Storeys are 40/3 studs, and every mass starts on a storey line from the parcel ground.
- Balcony plates are 4.5 tall and protrude 5–9 studs; fins are 1.6 thick every 40.
- No part is thinner than 1 stud except neon and glass strips.
- Windows come only from the window variants on big faces.
- Clutter (laundry, AC, dishes, pipes) is on LOD2; roof tanks, sheds, stairs and fences are on LOD3; everything else is on LOD4.
- The preview renders `SG *` window variants in their tint colour, not dark blue, because preview.py only darkens `Windows*`. Expect darker window faces in Studio.

## Iterations

1. **P12 v1**: slab x1170–1490 (320 wide), crown at 944 and a small mast. It read squat and the mast was invisible.
2. **P12 v2**: slab narrowed to 240 for verticality. Crown lowered to 872–918 so a full-size lattice mast fits under 1000. A west stair tower added to receive X3.
3. **P12 v3**: sky-street void and podium, wing and core life added.
4. **P05 v1**: a flat N1 slab and a uniform M1. N1 was changed to step down with a harbour stair tower and a roof court, and the M1 trays now taper with capsules at the tray ends.
5. **P05 v2**: S1 south slab added to close the courtyard and fill the empty south-east. AC and tube clashes fixed.

Studio capture was not used; the previews are in `preview/`.
