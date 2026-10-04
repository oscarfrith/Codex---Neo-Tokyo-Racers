# Modern Muscle category: game setup contract

Status: approved 2026-10-04 (Oscar asked for one contract, self-approved by the assistant, to be checked by him after the install). Place: **Space Racers v3 (93959280828322)**. Lane: High-Risk (prices, locks, saved ids). Route: [vehicle category playbook](vehicle-category-playbook.md), "Stats-first setup". Brief: [muscle.md](../design/vehicle-categories/muscle.md), "Game setup brief".

This step sets up ids, stats, prices, locks and placeholder geometry. No concept images and no Blender models. Mesh cars come later and must drop in under the same ids.

## Audit (read-only, 2026-10-04)

- **Game scripts: no change.** No live script names `exotic`. Category, feature flag, slots, labels, defaults, seat offsets and rating reference are read from data. The only category literals are legacy `bruiser` fallbacks (`GarageServer`, `GarageProfileView`, `GarageCatalogLookup`, `GarageProfileProjection`, `GarageUI`, `PreviewVehicleClient`, `VehiclePerformanceResolver`), which Exotic already lives with. Muscle modules always carry `SourceCockpitId` and `CategoryId`, so the `Bruiser` name parsing in `GarageCatalogLookup` is never reached.
- **Garage display:** attribute-only (`Hidden_<CategoryId>`, `VariantLabels_<CategoryId>`, `DealershipHiddenCategories`).
- **Tools:** the installer engine (`stage_b/installer_engine.lua`) and the catalogue generator are data-driven and are inside the Exotic content hash; they are not edited. The balance builder, the content builder and their tests were hard-wired; they now take `--category` (default `exotic`).
- **Driving model (matters for the feel):** `Config.Vehicles.Dynamics` maps `SteeringResponse` with exponent 0.1, so the stat barely changes steering on the road. `LateralGrip` uses exponent 0.4 with a floor of 0.82, reached at raw 30.4. Piercer E and D cars (18 and 27) are already on that floor. So through stats the corner weakness is physical on the Fastback and the Modern (and a little on the Hardtop); the three cheaper cars grip like a Forge or a Vector.

## Decisions

| # | Topic | Decision |
|---|---|---|
| 1 | Ids (permanent, saved) | `CategoryId` `muscle`; folder `MUSCLE`; flag key `VehicleClass_muscle`; cockpits `muscle_01` to `muscle_06` (`COCKPIT_MUSCLE_0N`); ModuleIds as Exotic with `MUSCLE` for `EXOTIC`: 72 core and 72 body, 144 in all. |
| 2 | Names (placeholders) | Notch, Ute, Ragtop, Hardtop, Fastback, Modern. Kit name = car name. Module names are the blockout names. Category `DisplayName` "Modern Muscle". |
| 3 | Tiers | E, D, D, C, C, B. See the table below. The category tops out at B. |
| 4 | Prices | Below Piercer and Exotic of the same tier. Starting Cash (140,000) buys any of the first three cars. |
| 5 | Character | Multipliers on the Piercer totals of the tier: `EngineOutput` 1.18, `BoostForce` 1.20, `TopSpeed` 1.10, `Weight` 1.20 (heavier); `LateralGrip` 0.72, `SteeringResponse` 0.75, `Downforce` 0.75, `BrakingForce` 0.90, `BoostDuration` 0.85. One scale per car then fits the target rating. |
| 6 | Slots | As Exotic: Front Body, Rear Body, Front Engine, Rear Engine, Drift Thrusters, Overdrive, Wing. Side Pods, Splitter and Diffuser exist, start empty and are hidden (`Hidden_muscle`). |
| 7 | Versions | Standard, GT, EVO on every module. Core modules keep `VariantName` Lightweight and Power and show as GT and EVO (`VariantLabels_muscle`). |
| 8 | Locks and part prices | Every module carries `SourceCockpitId`. Core GT and EVO cost V = 12% of the car. Front Body, Rear Body and Wing cost V/4, V/2 and V. No body part with a lock has `Price` 0. |
| 9 | GT and EVO body stats | GT one step, EVO two. Front Body: `Downforce`, `SteeringResponse`. Rear Body: less `Weight`, `EngineOutput`. Wing: `Downforce`, `LateralGrip`. A full EVO set adds 3.8 to 5.2 PI. |
| 10 | Do body parts fit only their own car? | **No. Any Muscle part fits any Muscle car**, as in Exotic. With one cap for the whole category the limiting build is the Modern with its own best parts, so a lock would not buy larger steps, and it would need a script change. |
| 11 | Cap proof | For every car: an exact upper bound over every Muscle core module of every family, every body part and version, every legal upgrade allocation. Limit 721.49 (3 PI under 724.495, where the shown index would read 725). It is `test_tier_cap` in `balance/test_balance.py --category muscle`. |
| 12 | Geometry | Primitives from `scripts/vehicle_blockouts/specs/muscle.json`. GT and EVO share the base part's shape. Seats are generated, not measured. No card images. |
| 13 | Visibility | `Flag_VehicleClass_muscle = true` on `ServerStorage.Config` (Studio override). `DealershipHiddenCategories = "bruiser,muscle"`: not on sale in the dealership until Oscar says. |

## Cars

| Id | Name | Tier | Stock PI | Price | V | Best build, own parts | Ceiling, any Muscle part |
|---|---|---|---:|---:|---:|---|---:|
| `muscle_01` | Notch | E | 230 | 32,000 | 3,840 | D 386 | 641.13 |
| `muscle_02` | Ute | D | 330 | 85,000 | 10,200 | C 460 | 651.58 |
| `muscle_03` | Ragtop | D | 410 | 110,000 | 13,200 | C 523 | 663.03 |
| `muscle_04` | Hardtop | C | 480 | 240,000 | 28,800 | C 578 | 674.98 |
| `muscle_05` | Fastback | C | 565 | 310,000 | 37,200 | B 647 | 695.99 |
| `muscle_06` | Modern | B | 630 | 850,000 | 102,000 | B 702 | 717.90 |

- The Modern's target is 630. At 635 the ceiling is 721.98, over the limit; 640 to 650 are further over.
- The ceilings of the five cheaper cars need the Modern's core modules, so they apply only to a player who also owns the Modern. A Notch can then reach B 624.
- Reference for module ratings: `muscle_04`.

## Owners (unchanged)

| Concern | Owner |
|---|---|
| Category folders, preview copy, four `*_Muscle` VFX templates, `MUSCLE_n` catalogue chunks | The content installer, marker `muscle_category/stage_b` |
| Purchases, locks, prices charged | `GarageServer`, `GarageCatalogLookup` (unchanged) |
| Catalogue | `VehicleCatalogData` index and chunks, generated by `catalogue_gen.lua` (unchanged) |
| Garage display | `GarageUI`, `GarageWorkspaceUI` reading `Config.UI.GarageReplacement` (unchanged) |
| Saved data | Profile schema unchanged. New saved keys are only the ids in decision 1. Front Body and Rear Body reuse the six Exotic upgrade `PathId`s. |

No new remote, action, saved field, owner or script.

## Delivery

1. `py -3 scripts/exotic_category/refine.py --category muscle` (spec check, balance build and tests, content tests, AUDIT and APPLY builds).
2. Studio Edit: `categories/muscle/out/full_audit.lua`, then `full_apply.lua`, a second AUDIT, `out/post_install_checks.lua`.
3. Config: `categories/muscle/config/out_audit.lua`, then `out_apply.lua` (six attributes; it refuses until the category is installed).
4. Before and after record: `categories/muscle/state_probe.lua` (the scoped capture tool does not accept the v3 place).

**Recovery.** Never run a ROLLBACK in v3, and none is built for Muscle. Before any profile owns a Muscle car: remove `Flag_VehicleClass_muscle`; the category then leaves the server catalogue and both buy actions refuse. Content faults are fixed by a new build and APPLY. Do not turn the flag off once a saved profile owns a Muscle car (EXO-02 applies).

**Must hold after install.** Exotic content hash `b2f4b211...` and its three chunk sources unchanged; Piercer chunks unchanged; no script other than the catalogue index and the new `MUSCLE_n` chunks changed.

## Review (`delivery-reviewer`, 2026-10-04, before APPLY)

Clean: economy and locks (all 144 modules carry `CategoryId` and the right `SourceCockpitId`; the server's `modulePurchasePrice` gives V, V/4, V/2, V and never 0), saved ids (no clash; the six reused `PathId`s are stored per module instance), scope and owners, and the garage cap (the reviewer recomputed the Modern ceiling at 717.90). No Exotic test was loosened: the Exotic expectations moved into `balance/categories/exotic.py` unchanged.

Conditions met before APPLY:
- Tests re-run on the frozen tree after the socket fix; the content hash is `ba880c2d...`.
- The v3 rating config was compared with the capture the proof uses: 368 folders, 3,974 values, no difference.
- The config installer now refuses unless `MUSCLE` is the full install of that content build.

Risks accepted or left open (Oscar to decide):
1. **The cap is proven for the garage rating only (MUS-01).** VEH-01 makes the on-road index higher than the garage index. The reviewer's estimate for the best Modern build (garage B 702) is A 727 to 749 on the road; a stock Modern stays B (654 to 680). `MatchmakingServer` and `TimeTrialServer` read the on-road `PerformanceTier`. Not measured: it needs a bought car. Options: fix VEH-01 (its own delivery, it affects every car), or lower the Modern's target to about 605.
2. **Not on sale is a client rule.** `DealershipHiddenCategories` hides the category in `GarageUI` only. With the Studio flag on, the server accepts a Muscle purchase from a remote call. A published server reads the dashboard key, which is unset.
3. **The first purchase closes the recovery.** v3 saves in Studio Play. Once a saved profile owns a Muscle car the flag must stay on (EXO-02) and the ids are in saved data.
4. **Limits of the proof.** Margin 6.59 PI. It assumes the index never falls when a stat improves (sampled 20,000 cases by the reviewer, none found; no test). It does not model an empty engine slot (the reviewer added it by hand: no change). Any new Muscle part, or a change to `Config.Vehicles.Performance`, needs the proof re-run.
5. **Recovery is partial.** Flag off leaves the folders, VFX templates and chunks in place and replicated.

## Not in this step

Concept art, Blender models, card images, slot diagrams, measured seats, final names. Driving-config changes to make steering and low-tier grip felt (they affect every car). Publishing: a published server reads the flag from the Creator Dashboard config key `VehicleClass_muscle`, not from the Studio attribute.
