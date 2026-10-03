# Exotic category: how to refine it

Read this before changing the look, names, stats or effects of the Exotic class. It assumes the class is installed in **Space Racers Backup v2 (place 133417340424236)**, which it is since 2026-10-03. v2 is not touched.

Background: [contract](../../docs/architecture/exotic-category-contract.md), [interface](INTERFACE.md), [evidence](verification.json), [content installer](stage_b/README.md).

## What a refinement is

A refinement changes **content only**: geometry, names, colours, stats, prices, jet effects, seat and socket positions. It goes through the content installer, which was reviewed and proven on 2026-10-03. No game script changes.

| Change | Lane | Route |
|---|---|---|
| Geometry, colours, names, VFX scales, sockets, seats, stats, prices | Standard | The loop below |
| Anything in `stage_a/` (garage, catalogue or UI code), a new slot, a new remote | High-Risk | New contract section, `delivery-reviewer`, golden parity (`golden.lua`) |
| Renaming an ID | Not allowed | IDs are saved in player profiles |

## Fixed, do not change

- `CategoryId` `exotic`; cockpit IDs `exotic_01` to `exotic_06`; every `ModuleId` (120, including the twelve `_GT` and `_EVO` body ids of kits 02 and 05); the ten slot IDs; the six new upgrade `PathId`s (`NoseCanards`, `SlipstreamNose`, `LightweightNose`, `DeckCooling`, `LightweightDeck`, `TailStrakes`).
- Which spec shape each ID uses: cockpit N wears kit N as its default (table in [INTERFACE.md](INTERFACE.md)). The spec keys (`spider`, `track`, `mono`, ...) are internal and may stay as they are even if the look changes.
- The vehicle root (`CockpitRoot_DoNotRename`, 7.5 x 1.2 x 10.5, copied from Piercer) and all ten mounts at the root origin. Driving physics depend on it.
- Oscar's design rules: jets, not wheels or anything wheel-like; engine, stabiliser and boost modules are visible jet hardware on every car; any part must fit any cockpit in the class and still look different from the other options.
- The cockpit owns all glass and the roofline. Modules carry no glass.
- Player-facing names are original. Real hypercars are inspiration for shape and proportion only: do not use real make or model names in `DisplayName`, `CardTitle` or descriptions.

## Free to change

| What | Where |
|---|---|
| Shape of a cockpit or module | `scripts/vehicle_blockouts/gen/exotic.py`: one function per shape (`cockpit_wedge`, `nose_shovel`, `deck_slab`, `e1_mono`, `st_vector`, ...). Shared chassis in `chassis()`; frame standard in `standard()`. |
| Display names and notes | The same generator (module and cockpit `name` fields). Update the names table in [INTERFACE.md](INTERFACE.md) and `stage_b/data/ids.json` if a cockpit name changes. |
| Default paint per cockpit | The native build `paint` in the generator; template colours and glass in `stage_b/data/colours.json`. |
| Jet flame size | `stage_b/data/vfx.json`. |
| Where flames come from | `stage_b/data/sockets.json` (computed from thrust parts; `overrides` for a single shape). |
| Driver and passenger position | `stage_b/data/seats.json` (rule or per-cockpit `overrides`). |
| Hover dust, underglow, cockpit lens lights | `stage_b/data/cockpit_fixtures.json`. |
| Stats, prices, upgrade paths | `balance/build_balance.py` (targets, character multipliers, body part flavours). Ratings come from `balance/rating.py`, a port of the live calculator. |

Changing the frame standard (envelopes, seams, pads) is allowed but touches every part: all six cockpits and sixty shapes must still validate with 0 errors.

**Mesh kits (02 Curve, 05 Hyper).** Since 2026-10-03 these two cockpits and their Nose, Engine Deck, Wing and core modules are not built from the spec: they are clones of uploaded MeshParts ([mesh/INTEGRATION.md](mesh/INTEGRATION.md)). Editing their spec shapes changes nothing in the game (the spec still gives them names, default paint and the fallback seat). To change them: rebuild the meshes in `mesh/`, upload, run `py -3 scripts/exotic_category/mesh/make_mesh_data.py <asset id>` (it writes `stage_b/data/mesh.json`: parts, centres, sockets), then the loop below. Their seats are `overrides` in `stage_b/data/seats.json`; their lamp colours are `meshLamp` and `meshLampRed` in `stage_b/data/colours.json`. Their Side Pods, Splitter and Diffuser are still spec shapes, and those three slots start empty on the two cockpits.

## The loop

1. **Edit** the generator or a data file.
2. **Build and check offline** (from the repo root):

   ```
   py -3 scripts/exotic_category/refine.py --previews
   ```

   It regenerates the spec, runs the frame-standard validator (errors stop it), rebuilds the balance data, runs the balance and content tests, and builds `stage_b/out/full_audit.lua`, `full_apply.lua` and `full_rollback.lua`. `--previews` also renders sheets to `scripts/vehicle_blockouts/previews/exotic/` (matrix, one sheet per cockpit, mix sheets). Look at those before going to Studio.
3. **Install in Studio** (Edit, Play stopped). Serve the repo root in the background, then run AUDIT and APPLY through `execute_luau`:

   ```
   py -3 -m http.server 8793 --bind 127.0.0.1
   ```

   ```lua
   local Http = game:GetService("HttpService")
   local function run(name)
       local src = Http:GetAsync("http://127.0.0.1:8793/scripts/exotic_category/stage_b/out/" .. name .. "?t=" .. os.clock(), true)
       return Http:JSONEncode(assert(loadstring(src, name))())
   end
   return run("full_audit.lua")   -- read the findings; then run("full_apply.lua")
   ```

   APPLY replaces this installer's own earlier content in one all-or-nothing step and rewrites only the `EXOTIC_n` catalogue chunks and the index. This path was proven on 2026-10-03 (same content, new build: 9 roots replaced, catalogue revision unchanged).
   AUDIT and APPLY load the mesh asset with `game:GetObjects` (a read). AUDIT reports a `mesh` BLOCKER if a part named in `mesh.json` is missing from the asset or its centre is more than 0.05 off.
4. **Check**: run `stage_b/post_install_checks.lua` the same way. Expect 0 unreachable templates, equal channel census, all sockets under parts, exact preview parity, and the mesh census: 189 mesh parts, `noMeshId=0 badProperties=0 sourceUsedTwice=0 mixedTemplates=0`, the same on server and preview.
5. **Look**: start Play. The dealership preview is the quickest view of all six cars (free, no purchase). Buy and drive the ones you changed. The sandbox gives $1,000,000; the `=` key adds $1,000,000 in Studio.
6. **Hand off**: targeted capture, `check_projection.py` and `check_catalogue.py` on it, then commit explicit paths.

Baseline for comparisons: `roblox/captures/exotic-refine-baseline/capture.json` (2026-10-03, content hash `5284a9ad...`, catalogue revision `37f47fad...`).

## Traps

- **Restart Play after every APPLY.** The catalogue is read once at start.
- **The Studio showroom block will be out of date** once the spec changes. `stage_b/data/ids.json` has `blockoutCheck: "warn"`, so the installer reports the difference and carries on. To refresh the showroom itself, use `scripts/vehicle_blockouts/install_showroom.lua` (it rebuilds all twelve class blocks).
- **Names inside module templates** must not contain `cockpit`, `engineon`, `engineoff`, `booston` or `stabiliseron`. Body module instance names must not contain `engine`, `boost` or `stabiliser`.
- **Lamps.** Neon-channel parts on the Nose and Engine Deck become fixed lights. Neon-channel parts on any other module are hidden until the player buys neon for that part.
- **Thrust parts decide the flames.** Each cluster of `thrust` parts gets one jet socket. Moving or adding nozzles moves the flames; check `stage_b/out/summary-full.json` for socket counts (13 to 15 per stock car today; the mesh Curve has 17, because its Standard boost has four jets in `mesh.json`). Mesh modules take their sockets from `mesh.json`, not from thrust parts.
- **Part count.** Stock primitive cars are 172 to 204 parts; the two mesh cars are 32 (Curve) and 35 (Hyper) MeshParts stock, about 51,500 and 57,100 triangles. Every part is welded at spawn. Treat about 220 as the ceiling until a low-end device has been tested.
- **Stat changes move ratings.** `refine.py` fails if a stock build leaves its tier band or target by more than 3. Body parts stay at accessory size so they cannot shift a tier.
- **The seat.** Roofs lower than about 3.9 studs (underside) put the driver's head through the roof. The Wedge is the lowest closed roof at 3.83.
- **Do not turn the category flag off** once a saved profile owns an Exotic.

## Starting points for real-car inspiration

These pair each existing cockpit and kit with the kind of real car its brief already points at. They are suggestions for the refinement, not decisions.

| Cockpit (kit) | Tier | Brief today | Real-world direction |
|---|---|---|---|
| Spider (Track) | E | Open top, low screen, roll humps, bare and loud | Open track specials and barchettas |
| Curve (Analogue) | D | 90s teardrop, glass fastback, round and smooth | 1990s analogue supercars with a central spine and round tail |
| Wedge (Wedge) | C | Flat razor roof, boxy and sharp | 1970s and 80s wedge supercars and wedge concepts |
| Longtail (Longtail) | B | Low bubble, roof scoop, rising twin fins | Endurance longtails and Le Mans streamliners |
| Hyper (Hyper) | A | Narrow canopy, shoulder wings, dorsal fin | Modern hypercars with fighter canopies and exposed aero tunnels |
| Gull (Concept) | S | Wide glasshouse, roof spine, glass turbine cover | Gullwing halo cars and one-off concept hypercars |

For concept images before modelling, use the Codex route in [exotic-art/BRIEF.md](../../docs/design/vehicle-categories/exotic-art/BRIEF.md). It already has Wedge and Hyper art made from the blockouts.

## Still open from the first delivery

- Cockpit card images (needs Oscar's approval to upload).
- Idle jet puffs read as white blobs: tune `vfx.json`.
- Oscar has not yet play-tested or confirmed driving feel, looks or stats.
- Open issues EXO-01 to EXO-04, VEH-01 and GAR-01 in [docs/06](../../docs/06_current_known_issues.md).
