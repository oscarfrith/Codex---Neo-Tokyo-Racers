# Exotic category: build interface (authoritative for every builder)

Status: approved by Oscar on 2026-10-02 for **Space Racers Backup v2, place 133417340424236** only. v2 is not touched.

This file fixes the names, IDs and semantics that more than one builder depends on. If something here is wrong against live source, do not silently diverge: say so in your return value and build to the nearest correct form.

Research (read-only map of the live game): `output/exotic-impl/understand/` (`gaps.md` first, then `authoring.md`, `catalogue.md`, `hardcodes.md`, `runtime.md`, `ui.md`, `economy.md`, `process.md`, `exotic.md`, `paintvfx.md`). Approved plan: section "Approved decisions" below.

Baseline capture: `roblox/captures/exotic-before/capture.json` (213 sources; roots: both vehicle roots, both Config trees, `ReplicatedStorage.Assets.VFX.VehicleTemplates`). Each manifest row has `path_parts` and `file` (a blob under `roblox/source_store/`). **Before-sources are those blobs, byte for byte.** Never rebuild a source from `script_read` output.

## Rules for builders

- Write only inside the folder you are given. Never touch Studio state (read-only inspection is allowed), never run Git.
- Piercer behaviour must not change: same replies, same text, same order. Every new behaviour is opt-in through data that Piercer does not have.
- No new remote, action, argument field or saved profile field. No new owner. No fallback copies or backups in the game.
- Luau after-files are complete sources (the whole script), made by copying the blob and editing it. Keep the existing code style of each file. Keep edits minimal.
- Never `require` a gameplay module through MCP.
- Public strings are ASCII. UK English, short sentences in any docs.

## Approved decisions

| Topic | Decision |
|---|---|
| Category | Folder `ServerStorage.Assets.Vehicles.Categories.EXOTIC`, after `PIERCER`. `CategoryId="exotic"`, `DisplayName="Exotic"`. |
| Selling | Performance parts as Piercer: Standard free with the cockpit, Lightweight and Power at 12% of the cockpit price, family locked by `SourceCockpitId`. Body parts open to any Exotic owner. |
| Prices | Premium, about 25% over the matching Piercer. |
| Lights | Nose and Engine Deck lamps always on. Neon on other modules is buyable neon. |
| Images | None uploaded. `MenuImage=""`. |

## IDs (permanent, saved in profiles)

| N | CockpitId | Model name | DisplayName | Spec cockpit | Spec kit | Kit name | Tier | Price | Target stock PI |
|---|---|---|---|---|---|---|---|---:|---:|
| 01 | `exotic_01` | `COCKPIT_EXOTIC_01` | Stinger | `spider` | `track` | Track | E | 50000 | 220 |
| 02 | `exotic_02` | `COCKPIT_EXOTIC_02` | Zephyr | `curve` | `analogue` | Analogue | D | 150000 | 390 |
| 03 | `exotic_03` | `COCKPIT_EXOTIC_03` | Aurora | `wedge` | `wedge` | Wedge | C | 440000 | 540 |
| 04 | `exotic_04` | `COCKPIT_EXOTIC_04` | Endura | `longtail` | `longtail` | Longtail | B | 1400000 | 675 |
| 05 | `exotic_05` | `COCKPIT_EXOTIC_05` | Rosso | `hyper` | `hyper` | Hyper | A | 4400000 | 800 |
| 06 | `exotic_06` | `COCKPIT_EXOTIC_06` | Seraph | `gull` | `concept` | Concept | S | 12500000 | 938 |

Spec = `scripts/vehicle_blockouts/specs/exotic.json` (`cockpits`, `kits`, `modules[slot][id]`). Kit N is the signature kit of cockpit N.

Module IDs (model name = `ModuleId`):

| Slot | ModuleType | ModuleFolder (folder name and attribute) | ModuleId | Count |
|---|---|---|---|---|
| `Engine1` | `Engine` | `Engines` (family folder `Exotic_0N`) | `MODULE_ENGINE_EXOTIC_0N_<STANDARD\|LIGHTWEIGHT\|POWER>` | 18 |
| `Engine2` | `Engine` | `Engines_B` (family folder `Exotic_0N`) | `MODULE_ENGINE_B_EXOTIC_0N_<VARIANT>` | 18 |
| `Stabilisers` | `Stabilisers` | `Stabilisers` (family folder `Exotic_0N`) | `MODULE_STABILISER_EXOTIC_0N_<VARIANT>` | 18 |
| `Boost` | `Boost` | `Boost` (family folder `Exotic_0N`) | `MODULE_BOOST_EXOTIC_0N_<VARIANT>` | 18 |
| `FrontBody` | `FrontBody` | `FrontBodies` | `MODULE_FRONTBODY_EXOTIC_0N`; kits 02 and 05 also `_GT`, `_EVO` | 6 + 4 |
| `RearBody` | `RearBody` | `RearBodies` | `MODULE_REARBODY_EXOTIC_0N`; kits 02 and 05 also `_GT`, `_EVO` | 6 + 4 |
| `SidePods` | `SidePods` | `SidePods` | `MODULE_SIDEPODS_EXOTIC_0N` | 6 |
| `FrontBumper` | `FrontBumper` | `FrontBumpers` | `MODULE_FRONTBUMPER_EXOTIC_0N` | 6 |
| `RearBumper` | `RearBumper` | `RearBumpers` | `MODULE_REARBUMPER_EXOTIC_0N` | 6 |
| `RearSpoiler` | `RearSpoiler` | `RearSpoilers` | `MODULE_REARSPOILER_EXOTIC_0N`; kits 02 and 05 also `_GT`, `_EVO` | 6 + 4 |

- 72 core modules and 48 body modules (36 plus the twelve mesh trims below): 120 in all. The three variants of a core module share the kit's geometry, except on the mesh kits.
- **Mesh kits 02 and 05** (2026-10-03, [mesh/INTEGRATION.md](mesh/INTEGRATION.md), which is the authority for them). Cockpits `exotic_02` and `exotic_05` and their Nose, Engine Deck, Wing and core modules are clones of uploaded MeshParts (model asset `112592679936648`, listed in `stage_b/data/mesh.json`), one mesh per ModuleId. Twelve new permanent ids: `MODULE_FRONTBODY_EXOTIC_0N_GT`, `_EVO`, `MODULE_REARBODY_EXOTIC_0N_GT`, `_EVO`, `MODULE_REARSPOILER_EXOTIC_0N_GT`, `_EVO` for N in 2, 5. Each copies its base part (stats, upgrade paths, attribute set, no `VariantName`); `DisplayName`, `ModuleName` and `CardTitle` are the base name plus " GT" or " EVO"; `Price` is base x 2 or x 3.5. Their Side Pods, Splitter and Diffuser modules stay primitive.
- Engine1 modules: `EnginePosition="Front"`, `RearEngine=false`, `ModuleSlot="Engine"`. Engine2 modules: `EnginePosition="Rear"`, `RearEngine=true`, `ModuleSlot="Engine"`.
- Core modules mirror the live Piercer family attribute set exactly (donor: `MODULE_<TYPE>_BRUISER_03_<VARIANT>`), with `SourceCockpitId="exotic_0N"`, `CategoryId="exotic"`. Standard: `Price=0`, `PurchasePrice=0`, `UpgradePointCapacity=2`, `MaxPointsPerPath=3`, type-flat `Point1/2CostGuide`. Lightweight and Power: `Price=PurchasePrice=12%` of the cockpit price, capacity 6, `Point1..6CostGuide` = 8/10/12/15/18/22% of the variant price rounded to 100. `VariantOrder` 10/20/30. `NeonPrice` 5000/6500/8000.
- Body modules mirror the live accessory attribute set (donor: `MODULE_<TYPE>_LVL1`; FrontBody uses the FrontBumper donor, RearBody the RearBumper donor): `Price` only (no `PurchasePrice`, no `SourceCockpitId`), each stat as raw plus `PerformanceDelta_` twin, capacity 6, `MaxPointsPerPath=3`, accessory cost guides.
- Module `DisplayName` is the spec display name ("Mono Turbine", "Shovel Nose"). Never put `cockpit`, `engineon`, `engineoff`, `booston` or `stabiliseron` in any instance name. Body module instance names must not contain `engine`, `boost`, `stabiliser` or `stabilizer`.

Slot folders on every Exotic cockpit (`ModuleSlots/SLOT_<SlotId>`, all with `FixedSlot=true`, child `Mount_DoNotRename` at the root origin):

| SlotId | DisplayName and RailLabel | ModuleType | AllowedModuleFolder | Order | CountLabel | EnginePosition |
|---|---|---|---|---|---|---|
| `Engine1` | Main Turbine | `Engine` | `Engines` | 1 | Engines | Front |
| `Engine2` | Side Engines | `Engine` | `Engines_B` | 2 | Engines | Rear |
| `Stabilisers` | Stabilisers | `Stabilisers` | `Stabilisers` | 3 | Stabilisers | |
| `Boost` | Afterburner | `Boost` | `Boost` | 4 | Boost | |
| `FrontBumper` | Splitter | `FrontBumper` | `FrontBumpers` | 5 | Splitters | |
| `RearBumper` | Diffuser | `RearBumper` | `RearBumpers` | 6 | Diffusers | |
| `RearSpoiler` | Wing | `RearSpoiler` | `RearSpoilers` | 7 | Wings | |
| `SidePods` | Side Pods | `SidePods` | `SidePods` | 8 | Side Pods | |
| `FrontBody` | Nose | `FrontBody` | `FrontBodies` | 9 | Noses | |
| `RearBody` | Engine Deck | `RearBody` | `RearBodies` | 10 | Engine Decks | |

(Mirror the live Piercer slot attribute set for the eight existing slots; check the live `CountLabel` values and follow their pattern.)

## Opt-in data attributes (absent means today's behaviour)

| Where | Attribute | Type | Meaning | Readers |
|---|---|---|---|---|
| Category folder | `FeatureFlag` | string | Flag key. When present and `FeatureFlags.IsEnabled(key, false)` is false: the category is left out of the server catalogue, `BuyCockpitInstance` for its cockpits returns `false, "Vehicle unavailable."`, `BuyModuleInstance` for its modules returns `false, "Module unavailable."`. Owned vehicles are never hidden or blocked. | `GarageCatalogService`, `GarageServer` |
| `ServerStorage.Config` | `Flag_VehicleClass_exotic` | boolean | Studio override read by `Core.FeatureFlags`. The EXOTIC folder carries `FeatureFlag="VehicleClass_exotic"`. | `Core.FeatureFlags` (unchanged) |
| Slot folder | `RailLabel` | string | Player-facing slot label in this category (rail, slot cards, paint targets, messages that name the slot in the UI). Absent: the artwork label as today. Passed to the client as slot field `RailLabel`. | `GarageCatalogService`, `GarageUI` |
| Module model | `CardTitle` | string | Title shown on the module's shop and inventory card. Absent: today's title. Passed to the client as module field `CardTitle`. Set on all Exotic modules to the module `DisplayName`. | `GarageCatalogService`, `GarageModuleCardViewModel` / `GarageUI` |
| Module model | `RatingReferenceCockpitId` | string | Cockpit used as the reference chassis for the module's rating. Absent: `bruiser_01` as today. Exotic modules use `exotic_03`. Must be in the public catalogue list. | `VehiclePerformanceResolver` |
| Cockpit model | `Default<SlotId>ModuleId` | string | Default module for any slot other than the four legacy ones. New names: `DefaultFrontBodyModuleId`, `DefaultRearBodyModuleId`, `DefaultSidePodsModuleId`, `DefaultFrontBumperModuleId`, `DefaultRearBumperModuleId`, `DefaultRearSpoilerModuleId`. The four legacy slots keep their legacy names exactly as `GarageServer` 413-421 and `VehiclePerformanceResolver` 10-15 read them; Exotic cockpits set all seven legacy attributes. Must be in the public catalogue list. | `GarageServer`, `GarageVehiclePreviewProfile`, `VehiclePerformanceResolver`, catalogue generator |
| Cockpit model | `DriverSeatOffsetX/Y/Z` | number | Driver seat offset in root local space. All three absent: the global `Config.Vehicles.DriverSeat` values as today. | `DriverSeatServer` |
| Cockpit model | `PassengerSeatOffsetX/Y/Z` | number | Passenger seat offset in root local space. Absent: the global `Config.Activities.Passengers` values as today. | `VehicleBuildService.addPassengerSeat` |

## Server semantics (Stage A)

- `buyCockpitInstance`: (1) find the cockpit in the requested category without mutating the profile; (2) the cockpit's own `CategoryId` attribute is the category that is written, and it must equal the requested category when one was sent; (3) flag check; (4) capacity and cash checks with the same messages and order as today; (5) pre-check every default module (template exists, slot exists, type and folder fit), else `false, "Vehicle unavailable."`; (6) only then set `CurrentCategory`, debit, create the vehicle and attach defaults. Unknown cockpit still returns "Cockpit not found."
- Defaults: the four legacy slots exactly as today. For every other `SLOT_<Id>` on the cockpit, `Default<Id>ModuleId` when present. New-slot defaults are granted only when the slot is empty **and** no owned instance already has the same `TemplateId` with `GrantedForVehicleId == vehicleId`. Legacy-slot grant logic is unchanged. No new record fields.
- `coreSlotRequired`: `FrontBody` and `RearBody` are required when the cockpit has those slots.
- `buyModuleInstance`: the module is looked up in the target vehicle's category (fall back to `CurrentCategory` as today), then the flag check.
- A missing cockpit or module template for an owned vehicle is skipped with a `warn`, never a throw (`GarageServer` 814-853, `GarageClientProfile` 102-109).
- `GarageCatalogLookup` 97 and 123: use the module's own `CategoryId` attribute, falling back to today's value.
- `OwnedGarageDisplay` 11-15: match the `CategoryId` attribute first, then the folder name as today.
- Not in scope: blocking retired or hidden modules, changing the legacy-slot grant loop, any other hardening. Report such findings; do not fix them.

## Client semantics (Stage A)

- `GarageWorkspaceUI.artworkDefinitions`: two new rows, `FrontBody` (label "Front Body", `SortOrder=72`) and `RearBody` (label "Rear Body", `SortOrder=74`), `ShowInBuild=true`, `ShowInCustomise=true`, images reused from existing artwork entries (no upload). A row appears only when the current category has that slot, so Piercer shows eight cards as today.
- `GarageUI`: where a slot label is shown (about lines 332, 385, 541), use the slot's `RailLabel` when present, else today's label.
- Module cards: title is `CardTitle` when present, else today's title. Variant tag logic is unchanged for modules without `CardTitle`. For Exotic body modules the tag must read sensibly (not "Level n").
- `GarageVehiclePreviewProfile` and `VehiclePerformanceResolver`: any cockpit key `Default<X>ModuleId` beyond the legacy ones is an optional default for slot `X`. Piercer results are unchanged.
- `VehiclePerformanceResolver` line 99: use `RatingReferenceCockpitId` when present.
- `PreviewCameraClient` line 10: `FrontBody="Front"`, `RearBody="Rear45"`.

## Catalogue split (Stage A)

- `ReplicatedStorage.Modules.Game.Vehicles.VehicleCatalogData` keeps its path and becomes a generated **index**: `Revision`, `SchemaVersion=1`, and for each name in a generated list `require(script:WaitForChild(name))`, copying records into `Cockpits` and `Modules` with a duplicate-id assert, then the existing freeze logic. `VehicleCatalog` and every reader stay unchanged.
- Chunks are child ModuleScripts `VehicleCatalogData.<FOLDER>_<n>` (`PIERCER_1`, `PIERCER_2`, later `EXOTIC_1`...), each `return {["Cockpits"]={...},["Modules"]={...}}` with today's record text.
- Packing: group by category folder (`TemplatePath[1]`); cockpits then modules, sorted by id; greedy fill to 150,000 characters; assert every source is under 190,000.
- `Revision`: the same algorithm over the merged data. With Piercer only it must equal `469d9bd81944a3d71a127ea1d5e702720b75f55524391cb27008e05e8fc2cf0e`.
- `scripts/performance_phase3/catalogue.py`: keep `project(h)` unchanged; add the six new `Default<Slot>ModuleId` names, `RatingReferenceCockpitId` and (only if a reader needs them from the client data) other new names to `PUBLIC`; add `chunk_sources(data)`. `check_projection.py` and `check_catalogue.py` compare every generated source with the manifest rows at and under `VehicleCatalogData`.
- Luau generator `scripts/exotic_category/catalogue/catalogue_gen.lua`: a chunk that returns `function() -> { index = <source>, chunks = { {name=..., source=...}, ... }, revision = <hex>, cockpits = n, modules = n }` computed read-only from `ServerStorage.Assets.Vehicles.Categories`. It never writes. Stage A and Stage B installers call it and write the sources. It rejects non-ASCII text and numbers that print as `e`, `inf`, `nan` or `-0`.

## Balance data (Stage B input): `scripts/exotic_category/balance/balance.json`

```
{
  "cockpits": { "exotic_01": { "attributes": { <every numeric and string attribute to set on the cockpit: 17 raw stats, legacy headline stats, Price, TargetTier, TargetStockPI, ...> }, "stockPI": 220, "stockTier": "E", "headlines": {...} }, ... },
  "modules":  { "<ModuleId>": { "attributes": { <stats, Price, PurchasePrice, NeonPrice, UpgradePointCapacity, MaxPointsPerPath, PointNCostGuide, VariantName, VariantOrder, Tier, ...> }, "upgradePathDonor": "<live Piercer ModuleId to clone VehiclePerformanceV2UpgradePaths from>", "upgradePaths": [ {"PathId": ..., "attributes": {...}} ]  }, ... }
}
```

- Either `upgradePathDonor` or explicit `upgradePaths` per module. FrontBody and RearBody need explicit new paths with new `PathId`s (saved keys): fix them here and list them in the report.
- Body part prices by kit number 01..06: 8000, 11000, 14000, 18000, 23000, 30000. Body `NeonPrice` by kit: 6500, 7000, 7500, 8000, 8500, 9500.
- Body stats stay at Piercer accessory LVL1 magnitude for every kit (flavour differs, size does not).
- Character against the Piercer of the same tier: `TopSpeed` and `SteeringResponse` up; `Weight` down (lighter); `HoverStability`, `DriftControl` and `BoostDuration` down.
- Stock build = cockpit + four Standard core modules + the six default body modules. Its PI must be within 3 of the target and inside the tier band. Mesh cockpits `exotic_02` and `exotic_05`: three default body modules (Nose, Engine Deck, Wing); they declare no `DefaultSidePodsModuleId`, `DefaultFrontBumperModuleId` or `DefaultRearBumperModuleId`, those slots start empty, and the cockpit's raw stats absorb the three parts. Fitting them adds to the stock total (Curve D 406 with all six, Hyper A 802).

## Template format (Stage B)

Same as Piercer (see `authoring.md` sections 3-10, `runtime.md` 13, `paintvfx.md` 10). Root space: +X right, +Y up, forward -Z. `CockpitRoot_DoNotRename` is a copy of the Piercer root (7.5 x 1.2 x 10.5) at the spec origin; all ten mounts at the origin.

- Paint: channel folders plus `PaintChannel` attribute on each part. Spec channel `thrust` becomes `ThrustColor` under `THRUST_COLOR_WhiteByDefault`. Spec channel `driver` parts are dropped. Neon parts on `FrontBody` and `RearBody` go in a folder `LIGHTS_AlwaysOn` with `PaintChannel="Lights"`, Material Neon, part names without `neon`. Neon parts on other modules go in `NEON_OptionalLights`.
- VFX sockets are Attachments parented to the module or cockpit root part, flame along local +Z, `VFXSocket=true`, `VFXTemplate` naming an Exotic-scaled template: `EngineJet_Exotic`, `BoostJet_Exotic`, `StabiliserJet_ExoticLeft`, `StabiliserJet_ExoticRight` (new folders in `ReplicatedStorage.Assets.VFX.VehicleTemplates`, cloned and scaled from the stock ones by the installer).
- Seat offsets from the blockout driver position: driver about (-1.8, 0.25, 0.45), passenger mirrored (+1.8), per cockpit.
- Mesh templates (kits 02 and 05): each part is a `MeshPart` named `mesh_<channel suffix>` in the same channel folders, with `PaintChannel` and `MeshSource` (the source part name in the asset). Always-on lamps go in `LIGHTS_AlwaysOn` on any mesh module that has them (white, and red `mesh_lampred` parts at 255, 30, 20). Sockets come from `stage_b/data/mesh.json`.

## As built (2026-10-03, after the two delivery reviews)

- **Flag off.** The category is left out of the server catalogue and both buy actions refuse, as written above. `PurchaseDisabled` is a **reserved** category field: the client hunks that read it (GarageUI U7-U10, GarageBrowserUI B1) are inert plumbing and no server code sends it. Never set a `PurchaseDisabled` attribute on a category folder: folder attributes are copied to the client, so it would hide the category on the client with no server enforcement. Do not turn the flag off once any saved profile owns an Exotic; owners keep their cars, but the garage UI for that category would be missing.
- **Seat offsets fall back per axis**, not all-or-nothing: a missing `DriverSeatOffsetY` uses the global Y. Exotic cockpits always set all six.
- **Missing gate.** `GarageCatalogService` warns once and hides flagged categories if `GarageServer` does not pass `categoryFlagEnabled` (the two must be installed together; the installer refuses a mixed state).
- **Defaults pre-check** covers only the defaults a cockpit declares. The Stage B installer must assert all ten on every Exotic cockpit, except the slots a cockpit lists in `stage_b/data/ids.json` `emptySlots` (mesh cockpits: `SidePods`, `FrontBumper`, `RearBumper`), where it asserts that no default is declared.
- **Golden recorder**: `scripts/exotic_category/golden.lua`. Keys ending `AtUnix` are tokenised so runs on different days compare.
- **Known live issue, not changed here:** a spawned vehicle's `PerformanceIndex` double-counts module TopSpeed, Weight and three boost stats (a stock Forge reads E 245 on the road against 202 in the garage). It affects Piercer today and will affect Exotic the same way.
