# South Grid build contract (The Blocks x Metabolist Row)

Status: **contract for the parallel build**, 2026-09-28. Target: Oscar's test copy **LucidityStudios's Place: 09282026_3 (placeId 86391254062492)**. Oscar copies approved work into Space Racers v2 himself. Design direction: [world design pass 2](../../output/world-design-2026-09-26/STYLE_GUIDE_V2.md). The references are the D6 Metabolist Row and D8 The Blocks paint-overs in `output/world-design-2026-09-26/D6` and `/D8`.

## Scope

- **Parcels:** the 12 blockout parcels of the South Grid, listed in `scripts/south_grid/common/parcels.json`:
  - Row 1 is the waterfront at ground Y100 (P01–P05).
  - Row 2 is the upper terrace at ground Y200 (P07–P12).
  - P06 is the tower on P12's podium; P12 and P06 are one landmark building.
  - The rows are split by the x=0 boulevard.
- **Streetscape:** the streets, the step between the rows (z≈4576–4780), the waterfront edge, the open west lot (between P01 and the ring road) and the east wedge lot (x≈1760–2800).
- **Blockout:** the replaced blockout boxes are in `ServerStorage.SouthGridReplacedBlockout`. Every other blockout part, especially **every road**, stays exactly as it is.

## Hard rules

1. **Roads are fixed.** Do not move, cover or reshape road parts. Kerbs, paving, crossings, planters and paths may sit on the pavement and parcel areas. Bridges must clear road surfaces by at least 60 studs (underside).
2. **Style:**
   - Every building is The Blocks (brutalist mass housing: deep balcony grids, laundry, patched panels, exterior stairs, rooftop clutter, graffiti on the lower storeys), Metabolist (cores and capsules, stacked trays, porthole panels, Fuji TV / Genex frames, spheres, masts), or a deliberate mix.
   - Follow each parcel's `lean` in parcels.json.
   - This is a poor, dense district: tall, packed and lived-in, not glossy.
3. **Detail scale must match the dealership and the finished city around it** (Oscar's rule). Measured reference, S2_R4_B1 Building a:
   - about 12k triangles in about 12 MeshParts, split by material layer;
   - big clean forms;
   - facade detail carried by tiled MaterialVariants (Windows Day tiles every 40 studs, Tiles Square Large every 20);
   - fins, bands and neon strips as a few chunky layers.

   So:
   - Work on a **20/40-stud facade grid**. A storey is about 13.3 studs (3 per 40-stud window tile).
   - Nothing thinner than 1 stud or smaller than about 3 studs across, except glass or neon strips.
   - No greebling.
   - Windows come from the window variants on big faces, not from modelled frames.
   - Detail density is similar to the dealership blocks: readable from a car at speed, not busier.
4. **Budgets per building spec** (enforced by sgspec.py): 20k triangles, 320 Parts, 160 kit instances.
   - Streetscape: 60k triangles, 1500 Parts, 400 kit instances.
   - Kit pieces: the per-piece `tris` in kit_catalog.json.
5. **Heights:**
   - Row 1 tops 380–700.
   - Row 2 tops 480–850.
   - P12+P06 landmark top 900–1000.
   - At least one bridge per building.
6. **Materials:**
   - Use the existing MaterialVariants (the list in sgspec.py) plus the new `SG *` variants in `scripts/south_grid/textures/variants.json`, which the textures agent is making.
   - Neon only as thin accent strips or small signs.
7. **Agents:**
   - Write only inside your own folder.
   - Never touch Studio, except the read-only camera captures allowed below.
   - Never use git.
   - The integrator (main session) owns Studio, installs, captures and Play tests.

## Coordinates and specs

- Roblox world studs, Y up. The street-facing front of a kit item is its −Z face.
- Rotations are degrees for `CFrame.fromOrientation(rx, ry, rz)`.
- Build with `scripts/south_grid/common/sgspec.py`: `part`, `kit`, `clone`, `group`, `save`. It validates materials, variants, budgets and the parcel footprint.
- Preview with Blender 4.5 headless:
  `"C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup -P scripts/south_grid/common/preview.py -- --specs <your.json> --out <dir> --cams parcel:P01 street:P01 top:P01 drone [--all-specs]`
  - `--all-specs` also draws every other agent's current specs, so you see your neighbours.
  - Workbench flat colours; window variants render dark blue.
- Kit items (kit_catalog.json) have exact sizes. Until Oscar imports the kit they appear in Studio as box proxies. After import they become MeshParts, instanced cheaply by Roblox, so repeat them freely within budget.
- Existing city props (`common/props_catalog.json`: street lamps, trees, bushes, bollards, railings, traffic lights) are placed with `clone(key, pos)`. Clone pivot = model pivot: use ground-level positions for trees and lamps.

## Shared bridges (both ends must provide a solid landing face at the given point)

| id | owner | from → to | deck centre line | deck Y (top) | width | style |
|---|---|---|---|---|---|---|
| X1 | E | P09 east face (x=-125) → P10 west face (x=125), over the boulevard | z=5000 | 440 | 40 | gate: Metabolist tube pair + Blocks slab |
| X2 | F | P10 east (x=530) → P11 west (x=606) | z=5060 | 400 | 20 | truss |
| X3 | F | P11 east (x=1070) → P12 west (x=1146) | z=4960 | 470 | 20 | tube |
| X4 | A | P02 south (z=4576) → P09 north (z=4780), over the step | x=-400 | 330 | 24 | truss + ext stair tower |
| X5 | B | P03 south (z=4576) → P10 north (z=4780), over the step | x=400 | 350 | 24 | tube |
| X6 | C | P05 south (z=4576) → P12 north (z=4780), over the step | x=1450 | 360 | 24 | Blocks slab bridge |

- Write each shared bridge as its own spec with id X1–X6 (`Spec("X4", kind="building")`, saved as `buildings/<X>/X4.json`). It is assembled into the nearest block, and the parcel footprint check is skipped.
- Owners may add more bridges inside their own parcel pair (P01↔P02 for A, P03↔P04 for B, P07↔P08 for D, P09↔P10 for E).
- Deck Y ±10 and centre line ±20 may flex to fit your facade grid; say so in NOTES.md.
- The non-owner side builds only the landing: an opening, a recess or a solid face.

## Studio captures (read-only, optional for building agents)

studio_id `0d264df7-bac9-4ba7-96a9-14a49123b478`, Edit datamodel. Only move the editor camera, and **set Focus as well** or the editor camera will turn away. Use the `_G.__shotBusy` lock pattern from AGENT_BRIEF_V2 with this body:
`cam.CFrame=CFrame.lookAt(p,t) cam.Focus=CFrame.new(t) task.wait(1.5) Http:PostAsync("http://127.0.0.1:8772/",Http:JSONEncode({name="SG_<agent>_<slug>"}))`, then restore both CFrame and Focus.

## Ownership

| Agent | Folder | Delivers |
|---|---|---|
| KIT | scripts/south_grid/kit/ | Blender kit (`kit/build_kit.py`), `kit/out/obj/<piece>.obj` (Roblox local coords), `kit/out/SouthGridKit.fbx`, `kit/out/kit_sheet.png`, `kit/NOTES.md` with real tri counts |
| TEX | scripts/south_grid/textures/ | tileable 1024 PNG maps per SG variant (`textures/out/<slug>_color.png`, `_normal.png`, `_roughness.png`), `textures/NOTES.md`, final `variants.json` (keep names) |
| A | buildings/A/ | P01, P02, bridge X4 |
| B | buildings/B/ | P03, P04, bridge X5 |
| C | buildings/C/ | P05, P12+P06 (landmark, as one spec with id P12), bridge X6 |
| D | buildings/D/ | P07, P08 |
| E | buildings/E/ | P09, P10, bridge X1 |
| F | buildings/F/ | P11, bridges X2, X3 |
| ST | scripts/south_grid/streetscape/ | `streetscape/streetscape.py` → `streetscape.json` (and optional split files) |

Each building agent writes `buildings/<X>/<Pxx>.py` (generator), `<Pxx>.json`, `NOTES.md` and a few preview PNGs in `buildings/<X>/preview/`.

## Integration (main session)

1. Serve `scripts/south_grid` on 127.0.0.1:8773.
2. `install/assemble.lua` builds the specs into `Workspace.World.City["Block S9"].Block_S9_R*_B*` (LOD1–4 folders, CenterPart/Root) for the existing LODRuntime.
3. Upload the textures and create the SG MaterialVariants.
4. Oscar imports the kit FBX to `ReplicatedStorage.Assets.World.SouthGridKit`, then re-assemble so the proxies swap to MeshParts.
5. Add far LOD5 proxies.
6. Screenshots and a Play test.
