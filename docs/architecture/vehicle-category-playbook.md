# Vehicle category playbook

How to add a modular vehicle category after Exotic. Written 2026-10-04 from the Exotic build (Space Racers v3, place 93959280828322). Read this before starting a category; it replaces re-reading the Exotic chat.

Reference build: `scripts/exotic_category/` ([interface](../../scripts/exotic_category/INTERFACE.md), [refine loop](../../scripts/exotic_category/REFINE.md), [mesh contract](../../scripts/exotic_category/mesh/INTEGRATION.md)). Game-side contract: [exotic-category-contract.md](exotic-category-contract.md).

## What already exists and is reused

| Thing | State | Where |
|---|---|---|
| Second-category support in the game (catalogue split, garage, feature flag per class) | Installed in v3 for Exotic. **Audit first** whether a third category needs any script change: read `stage_a/spec.json` and the "hardcodes" notes named in INTERFACE.md before assuming none. | `scripts/exotic_category/stage_a/` |
| Content installer (AUDIT / APPLY, content hash, post-install checks) | Proven. Exotic-specific names inside. | `stage_b/` |
| Balance generator and rating port | Proven. Tier proofs and ceilings. | `balance/` |
| Blender modelling kit (`Hull`, `Loft`, envelopes, `check()`, `shot()`) | Proven. | `mesh/exokit.py` |
| Export, upload, mesh data | Proven, automated. | `mesh/export.py`, `fbx_export.py`, `upload_asset.py`, `make_mesh_data.py` |
| Card images and slot diagrams | Proven. | `mesh/images.py`, `compose_diagrams.py`, `upload_image.py` |
| Garage UI per-category display | **Config only, no script change:** `Image_<CategoryId>` and `Hidden_<CategoryId>` on `ModuleArtwork.<Slot>`, `UnderglowSidebarIcon_<CategoryId>`, `VariantLabels_<CategoryId>`, `DealershipHiddenCategories`. | `Config.UI.GarageReplacement`; installers `scripts/exotic_category/ui_*` |
| Paint and lighting | `MaterialService.ExoticFlakePaint` on primary paint, reflectance P 0.22 / S 0.14 / glass 0.3, night `EnvironmentSpecularScale` 0.7. Reuse as is. | `stage_b/data/colours.json`, `mesh/paint/` |

First engineering step for a new category: make the Exotic tools take a category config (id, names, place id, kit table) instead of forking them. Fork only if that costs more than a day.

## Decisions to fix in the contract before any modelling

Each of these was decided late on Exotic and cost a rebuild. Put all of them in one contract table and get one approval.

1. **Ids** (permanent, saved): `CategoryId`, six cockpit ids, ModuleId pattern. Never renamed later.
2. **Slots:** seven mesh slots in this order and with these labels: Front Body, Rear Body, Front Engine, Rear Engine, Drift Thrusters, Overdrive, Wing. Side Pods, Splitter and Diffuser exist but start empty and are hidden.
3. **Versions:** every module has Standard, GT and EVO. Core modules keep `VariantName` Lightweight and Power in data and show as GT and EVO through `VariantLabels_<CategoryId>`. Body parts carry `VariantName` Standard / GT / EVO, `VariantOrder` 10 / 20 / 30, `CardTitle` = base name.
4. **Locking and prices:** every module carries `SourceCockpitId` (locked until the car is owned). Body parts cost V/4, V/2 and V, where V is the kit's core variant price. No `PurchasePrice` on body parts; a `Price` of 0 on a locked part is charged 12% of the cockpit price by the server.
5. **Body stats:** GT adds one step, EVO two. Front Body: Downforce, SteeringResponse. Rear Body: less Weight, EngineOutput. Wing: Downforce, LateralGrip.
6. **Tiers and ceilings:** one cockpit per tier E to S. Any owned part fits any car in the category, so the best kit is limited by the tier ceiling of the car below it. The tier is read from the rounded index (S starts at 849.495). Size the steps with the ceiling test from the start, and leave at least 3 PI of room.
7. **Names:** car names and all module names are original and match the final designs. Decide them with the concept sheet, not after install. Kit name = car name.
8. **Default paint** per car, chosen with the concept.
9. **Card images and diagrams** are part of the first install, not a follow-up.
10. **Place:** v3 saves. Never run the content installer's ROLLBACK there; recovery is APPLY of the previous build.

## Design process (what Oscar accepts)

Standing art rules are in the memory note `feedback-vehicle-design-direction` and REFINE.md: no actual wheels; engine, stabiliser and boost are visible jet hardware on every car; headlights on the front engine modules; boost where the exhausts would be; primary and secondary paint on every module; any part fits any car and still looks different.

What went wrong on Exotic, and the rule that prevents it:

| Round lost | Rule |
|---|---|
| Six cars shared one nose, tail and engine side | Write a **visual language table** first: per car, one distinct choice for nose (length, depth, thickness), tail, engine side treatment (smooth, gills, slots, open, louvred), light signature and position, wing type, kit motif. No two cars share a cell. |
| Radical new engine architectures were rejected ("I preferred it before") | Keep the shared architecture. Differentiate by profile, surfacing and detail. Enhance, do not reinvent. |
| Lights on the wrong module or missing on a nose | Check every car for front lights on the front of the car and rear lights on the tail before showing it. |
| GT and EVO kits looked the same across cars | Kit hardware (canards, fins, vanes, splitter plates, wings) is designed per car from its kit motif. |
| Floating or clashing kit parts | Run a view-by-view pass on every car and version (front, rear, side, top, three-quarter) before showing; fix, then show. |
| Models "need cleaning" after approval of shape | Finish pass is a planned step: flowing lines, sharp creases, even panel gaps. |

Order that works: concept sheet (six cars, one image each plus one lineup) → visual language table → base models, shown as a lineup of all six from front and rear three-quarter → clean pass → GT and EVO kits per car → view-by-view confirmation → export and install.

Show Oscar the lineup of all six together at each gate. Three gates only: concepts, base models, kits. Triangle budgets may be exceeded a little; an artist reworks the meshes later.

## Images

- **Cards:** Blender render of the standard car in its default paint, then a Codex paint-over in the style of the existing cards. One per car. Tell Codex: no logos, badges or text.
- **Slot diagrams:** one car only; orthographic, front three-quarter (`images.py`: azimuth 142, elevation 36); no outlines; flat grey car with a layered pink highlight on the slot; GT wing and a larger boost so small parts read; gaps filled; 512 px. Only the seven mesh slots, plus All and Cockpit.
- **Thrust colour diagram:** flames behind the main engines only, same angle. **Underglow diagram:** strong, obvious glow under the car.
- Upload with `upload_image.py`; ids go in `ids.json` (`cardImage`) and the UI config attributes.

## Build and install route

1. Model in live Blender through scripts; `export.to_json()`.
2. Headless Blender `fbx_export.py` (never build FBX or call `normals_split_custom_set` in Oscar's live Blender).
3. `upload_asset.py` (key in env `ROBLOX_ASSETS_KEY`; never print it), then `make_mesh_data.py <assetId>`.
4. `refine.py`: balance, tests, AUDIT / APPLY builds.
5. Serve the repo on `127.0.0.1:8793`; in Studio run `full_audit.lua`, then `full_apply.lua`. Check the `mode=` header first: `out/installer.lua` is whichever mode was built last.
6. Second AUDIT (nothing to apply), `post_install_checks.lua`, attribute read-back, start Play once and read both logs. Oscar does the real Play test.
7. `delivery-reviewer` before APPLY for anything that changes game scripts, prices, locks or stats.
8. Commit explicit paths, update `docs/00_START_HERE.md` and `docs/07_patch_history.md`, push.

## Pitfalls that cost time

- Bash heredocs break on apostrophes: write scripts with the Write tool.
- Blender loses `sys.path` after a restart: insert the mesh folder before importing.
- Do not use `rm` with a variable path; overwrite files instead.
- Any edit to `installer_engine.lua`, even a comment, changes the content hash.
- Tests hold exact counts (kits, modules, checks). Update them with the data, and never loosen a tier test to pass.
- A cosmetic rename after install is a full content build. Batch names, colours and reflectance into one build.
- Envelope overruns: clamp heights in the kit, do not widen the envelope.
- Verify claims about the server from source before telling Oscar (new profiles own no vehicle and start with 140,000 Cash).

## Open on Exotic (do not copy as solved)

Seats are measured on one car only. Save and rejoin with an owned Exotic is not verified. Starting Cash buys only the cheapest car. The on-road index is higher than the garage index (VEH-01). Rosso and Seraph body trims are small because of the Rosso tier ceiling.
