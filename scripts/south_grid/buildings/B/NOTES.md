# Agent B: P03, P04, X5 (+ XB34)

Regenerate with `py -3 scripts/south_grid/buildings/B/P03.py`, `P04.py` and `X5.py`. `X5.py` writes both X5.json and XB34.json. The shared helpers are in `bkit.py`: box-by-extents, face-mounted kits and panels, shopfront strips, and roof caps. All specs save with no warnings.

| spec | tris | parts | kit | bounds (min..max) |
|---|---|---|---|---|
| P03 | 17758 | 215 | 94 | 285,100,4082 .. 710,696,4574 |
| P04 | 19590 | 256 | 123 | 827,100,4104 .. 1235,696,4552 |
| X5 | 1632 | 8 | 4 | 382,339,4574 .. 418,373,4780 |
| XB34 | 984 | 4 | 3 | 696,307,4426 .. 836,329,4454 |

## P03 "Capsule Gate" (Metabolist)

The boulevard (west) face is the gateway. Two gate towers carry a Fuji-TV-style sky frame with a 66-stud steel sphere between them, at Y476-556 and z4168-4448. It reads from the Y200 boulevard deck, and P10's X1 frame shows through it beyond.

- **T1 (NW):** Nakagin tower. A round core, 44 across, to Y630, with a mast to Y696. It carries 40-stud porthole capsules (SG Windows Capsule), 2-3 per level, staggered ±8 so the silhouette is jagged.
- **T2 (SW):** Yamanashi-style tray tower.
  - Twin square cores, 36 x 36, to Y590 and Y610.
  - Three glazed floor trays (Windows Day) with `tray_edge_40` fascias and open sky gaps between them.
  - The middle tray cantilevers to z4574 and carries the X5 landing portal.
- **Capsule wall:** sits between the gates.
  - Shops at street level with SG Windows Blocks housing above.
  - A capsule-panel upper storey (Y208-300) carries 23 kit `capsule_unit`s. They are above Y200, so they can be seen from the boulevard.
  - Porthole panels on both ends.
- **T3 (NE):** Shizuoka-Press-style round core, 52 across, to Y566. Seven pinwheel office arms, 84 long, reach out between Y180 and Y520.
- **T5:** spiral capsule hotel on a market podium, top Y546. There are market stalls on the plaza north of it.
- **T4 (east street):** eight stacked capsule/blocks trays that alternate ±8 in x, top Y460. It carries laundry and AC, and lands XB34.
- **Street level:** shopfronts with recessed glass, chunky piers, awnings and roll shutters. Graffiti bands (SG Graffiti A/B) run on the podium storeys.

## P04 "Terrace Stack" (The Blocks)

Every mass uses SG Windows Blocks. A 3-stud floor plate every 40 studs, plus 4-stud fins every 40, gives deep 40 x 40 coffers at the same scale as the dealership coffers. A seeded scatter (`field()`, seed 21) fills the coffers with balcony runs (51), laundry, and SG Patched Panels infill (pastel).

- **S1 waterfront terrace:** two wings that step back from the water. The west wing tops out at 460 and the east wing at 540.
  - A sky slot (x1000-1060) separates the wings. It holds an exterior-stair tower and two slab skybridges (Y306-326 and Y426-446).
  - The terraces carry planters, shacks, tanks and dishes.
- **S2 west slab:** top 560, with a terrace setback at 420. Balconies and AC on the west face, exterior stairs on the south end. It lands XB34, and the XB34 bay is left clear.
- **S3 SE point tower:** top 660, with corner and mid fins, tanks and dishes. A detached lift/stair core (x1062-1098) rises to Y693 with a red neon beacon, tied to the tower by six short bridges, as in the D8 hero. It carries a blue banner.
- **Courtyard garage podium:** Y100-140, with roll shutters on the east street and a caged ball court on the roof.
- **Low workshop block:** a full-mass SG Graffiti A mural on the south street, with shuttered bays.

## Bridges and landing coordinates

- **X5 (owner B, tube):**
  - Runs along centre line x=400, from z4576 to z4780. The deck top is at **Y350**, with the tube axis at Y356.
  - Parts: four `bridge_tube_40` on a capsule-panel spine, a 32-stud porthole pod at mid-span (z4662-4694), and square collars 28 x 30 at both ends.
  - The underside is Y339, so it clears the Y200 road by 139 and the Y100 road by 239.
  - **P03 end:** a solid face at z4574, on T2's cantilevered tray (Y320-400, x300-500). The collar starts at z4574, which is 2 inside the parcel line so it meets the tray face. The portal panel is x382-418, Y344-376.
  - **P10 end:** the collar ends exactly at z4780, against E's X5Lobby (x384-416, Y344-373). E's thin X5Door panel (z4779.2-4780.4) sits inside my collar. It is hidden, and no fix is needed.
  - No flex was used.
- **XB34 (B's own pair, truss):**
  - Runs from P03 T4's east face (x696) to P04 S2's west face (x836), centre z4440, deck top ~Y311. The truss spans Y310-326 and the collars Y307-329.
  - It crosses the x765 road with about 207 clearance.
  - The spec id is XB34 and is not in parcels.json, so the assembler uses nearestBlock.

## Checks run

- Two design iterations, plus a third pass for density and fixes.
  - Iteration 1: massing.
  - Iteration 2: the capsule wall was raised above the Y200 boulevard deck, with balcony/patch scatter, banners and rooftop clutter.
  - Iteration 3: fixes for the overlap and floating checks below, and denser S3 balconies.
- A scratch script checked for coplanar same-facing faces. The only hits left are buried inner faces: embedded backs of kits and fins, and the pier/glass faces inside the ground boxes.
- A contact check found nothing floating.
- Nothing is on a road footprint: P03 x285-710, P04 x827-1235, z ≤ 4552. The roads are x199-274, x727-802, x1255-1330, z4002-4078 and z4575-4650. Only X5 and XB34 cross roads, and both are high above them.

## Notes for the integrator

- **Variant base materials assumed:** SG Windows *, SG Patched Panels and Windows Day on SmoothPlastic; SG Weathered Concrete, SG Capsule Panels and SG Graffiti * on Concrete; Metal Shutters on Metal. I could not verify Windows Day's BaseMaterial without touching Studio. If it is not SmoothPlastic, change `VARBASE["Windows Day"]` in `bkit.py` and re-run P03.py. Windows Day is used only on P03's glazed trays, office arms and frame glazing.
- **preview.py:** the cams `street:P03` and `street:P04` fail, because any `street:` spec is parsed as custom coordinates. I used custom street cams instead.
- **Neighbour, seen in passing:** the contact check found one `ac_cluster` in E's P10.json that touches nothing (bounds 385..395, 551..558, 4871..4875).
- **Previews:** `preview/` holds drone, parcel_P03, parcel_P04 and top_P03. It also has these street cams: boulevard deck (60,212,3990), waterfront (700,160,3850), X5 over the step (620,300,4700), P04 waterfront (1290,108,4000), x765 canyon (765,112,3990) and P04 from the south (1180,330,4690).
