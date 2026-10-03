# Exotic vehicle category contract

Status: **Approved by Oscar 2026-10-02 for the backup place; in delivery.**

Target: **Space Racers Backup v2, place 133417340424236** (universe 10768874893). Space Racers v2 (71491191583884) is not touched. This is a recorded exception to the project rule that names v2 as the working place. Oscar's request supersedes the "Design - not approved" status of [vehicle-frame-classes](../design/vehicle-frame-classes.md) for Exotic only, in the backup place only.

Sources this contract is built from:

- Build interface (authoritative for names, IDs and semantics): `scripts/exotic_category/INTERFACE.md`.
- Approved plan: "Plan: make Exotic a playable vehicle category (backup place)", Oscar, 2026-10-02.
- Read-only research of the live game: `output/exotic-impl/understand/` (`gaps.md` first).
- Rules: [delivery workflow](../13_efficient_feature_delivery_protocol.md), [readiness standard](../14_new_system_readiness_standard.md), [contract template](../15_new_system_contract_template.md).

Where this contract and `INTERFACE.md` differ, `INTERFACE.md` wins and this file is corrected.

Lines marked **Filled by the integrator after build** are facts a builder decides later. They are not to be guessed here.

Line numbers are `script_read` numbers in the before sources.

---

## 1. System/change

A second vehicle category, **Exotic** (`CategoryId = "exotic"`), in the playable game: six cockpits, 108 modules, ten slots (the eight Piercer slots plus `FrontBody` and `RearBody`), with prices, stats and ratings. It uses the Piercer authoring format, the same remote, the same money path and the same saved schema.

The work has four stages run by the integrator with no user-run steps:

| Stage | What | Proof |
|---|---|---|
| 0 | Prepare: contract, capture tools accept the backup place, before capture and projection check, sandbox on, golden "before" | Capture verified, projection fresh, golden hash stable over two runs |
| A | Remove the fixed assumptions in code. Piercer is still the only category. | Golden "after" equals golden "before" on every line that must match (section 8) |
| B | Exotic content through one dedicated installer. Pilot (Wedge) first, then the rest. | Golden with the flag off equals golden "before" on the same lines; Exotic tests with the flag on |
| C | Restart Play, tests, evidence, documents, commit | Sections 20 and 22 |

Two installers in one task is deliberate. The design requires the fixed-assumption removal to ship alone and be proven before any content.

## 2. Delivery lane and reason

**High-Risk.**

- It changes ownership and money code (`GarageServer` buy and grant paths).
- It adds permanent IDs that are saved in player profiles: one `CategoryId`, six `CockpitId`s, 108 `ModuleId`s, two slot keys and new upgrade `PathId`s.
- It changes the public catalogue format (`VehicleCatalogData` becomes an index plus chunks).
- It becomes a dependency for every later vehicle class.
- A small diff does not lower the lane (docs/13 section 2, docs/14 Fast Lane rule).

The lane and its safeguards stay active through repairs and follow-up refinements.

Safeguards that follow from the lane:

- This contract, complete, before any game write.
- `delivery-reviewer` subagent on the spec and diff before each APPLY.
- AUDIT, then APPLY, ROLLBACK, APPLY to prove recovery.
- `multi_edit` and the asset or generation tools are not used for any part of this task.
- No gameplay module `require` through MCP.

## 3. Goal

A player can open the dealership, choose Exotic, buy one of six cockpits, receive it complete with its own kit in all ten slots, customise, upgrade and paint it, spawn it and drive it. A Piercer-only player sees no change at all.

## 4. Current confirmed baseline

| Fact | Value | Evidence |
|---|---|---|
| Before capture | `roblox/captures/exotic-before/capture.json` | Generated in Studio 2026-10-02 21:05:39 UTC, Edit mode, place 133417340424236 |
| Capture roots | `ServerStorage.Assets.Vehicles`, `ReplicatedStorage.Assets.VehiclePreviews`, `ReplicatedStorage.Config`, `ServerStorage.Config`, `ReplicatedStorage.Assets.VFX.VehicleTemplates` | `request.roots`; no missing roots, no duplicate paths |
| Script sources | 213, each a blob in `roblox/source_store/` | `script_count`; `manifest` |
| Catalogue revision | `469d9bd81944a3d71a127ea1d5e702720b75f55524391cb27008e05e8fc2cf0e` | `VehicleCatalogData` blob and projection check |
| Projection | Fresh. Public catalogue and preview copy both match server authoring. | `py -3 scripts/performance_phase4/check_projection.py --capture roblox/captures/exotic-before/capture.json` returns `publicCatalogueFresh=true`, `previewProjectionFresh=true`, 2,105 preview instances (re-run for this contract, 2026-10-02) |
| Categories | One: folder `PIERCER`, `CategoryId = "bruiser"` | Capture hierarchy |
| Piercer content | 6 cockpits, 116 module models (84 live, 32 retired), 8 slots | Research, read live |
| `VehicleCatalogData` size | 197,226 characters, 122 records | Manifest `source_bytes` |
| Roblox `Source` ceiling | 199,999 characters accepted, 200,000 rejected | gaps.md C4, measured on an unparented scratch script |
| `ServerStorage.Config` attributes | `Flag_EnableDuelStakes = true` only | Capture |
| VFX templates | `EngineJet`, `BoostJet`, `StabiliserJet`, `HoverDust`, `BrakeSparks`, `00_GLOBAL_VFX_SETTINGS`, `SOCKET_GUIDE` | Capture |
| Sandbox attribute at capture time | `StudioVehicleSandboxEveryPlay = false` on `ReplicatedStorage.Config.Player.Onboarding` | Capture |
| Studio API access | Off for this universe. A DataStore read returns error 502. | gaps.md C1 |
| Saved schema | `PlayerProfileSchema.SchemaVersion = 1` | economy.md 2 |

The before sources are the blobs named in the capture manifest, byte for byte. No source is ever rebuilt from `script_read` output.

The sandbox attribute is switched on in Stage 0 after this capture. The capture therefore records it as `false`. Stage A touches no attribute on that folder.

## 5. Decisions

Approved by Oscar, 2026-10-02.

| Topic | Decision |
|---|---|
| Place | Backup v2 only. Nothing is copied to v2. |
| Category | Folder `ServerStorage.Assets.Vehicles.Categories.EXOTIC`, after `PIERCER`. `CategoryId="exotic"`, `DisplayName="Exotic"`. |
| Selling | Performance parts as Piercer: Standard free with the cockpit, Lightweight and Power at 12% of the cockpit price, family locked by `SourceCockpitId`. Body parts open to any Exotic owner. |
| Prices | Premium, about 25% over the matching Piercer. |
| Ratings | Slightly higher than the Piercer of the same tier, inside the same tier band. |
| Character | Against the Piercer of the same tier: higher top speed and steering response, lighter; lower hover stability, drift control and boost duration. |
| Lights | Nose and Engine Deck lamps always on. Neon on other modules is buyable neon. |
| Images | None uploaded. `MenuImage=""`. |
| Root and seats | The Piercer root part at the spec origin, all ten mounts at the origin, per-cockpit seat offsets. |
| Default kit | A bought Exotic arrives with its own kit in all ten slots, free. |
| Body slots | `FrontBody` and `RearBody` are required slots on a cockpit that has them. |
| Geometry source | Built from the repo spec `scripts/vehicle_blockouts/specs/exotic.json`. The Studio blockout is a part-count and position check only and is never referenced at runtime. |
| Flag | `VehicleClass_exotic` in `Core.FeatureFlags`, default off. |

## 6. Stable IDs

These tables are copied from `INTERFACE.md` and must not be changed. Every ID here is permanent once an Exotic is sold in a place that saves.

### 6.1 Cockpits

| N | CockpitId | Model name | DisplayName | Spec cockpit | Spec kit | Kit name | Tier | Price | Target stock PI |
|---|---|---|---|---|---|---|---|---:|---:|
| 01 | `exotic_01` | `COCKPIT_EXOTIC_01` | Spider | `spider` | `track` | Track | E | 50000 | 220 |
| 02 | `exotic_02` | `COCKPIT_EXOTIC_02` | Curve | `curve` | `analogue` | Analogue | D | 150000 | 390 |
| 03 | `exotic_03` | `COCKPIT_EXOTIC_03` | Wedge | `wedge` | `wedge` | Wedge | C | 440000 | 540 |
| 04 | `exotic_04` | `COCKPIT_EXOTIC_04` | Longtail | `longtail` | `longtail` | Longtail | B | 1400000 | 675 |
| 05 | `exotic_05` | `COCKPIT_EXOTIC_05` | Hyper | `hyper` | `hyper` | Hyper | A | 4400000 | 800 |
| 06 | `exotic_06` | `COCKPIT_EXOTIC_06` | Gull | `gull` | `concept` | Concept | S | 12500000 | 938 |

Kit N is the signature kit of cockpit N. Tier bands (live `PerformanceDefinitions`): E 100, D 300, C 450, B 600, A 725, S 850.

### 6.2 Modules

Model name equals `ModuleId`.

| Slot | ModuleType | ModuleFolder (folder name and attribute) | ModuleId | Count |
|---|---|---|---|---|
| `Engine1` | `Engine` | `Engines` (family folder `Exotic_0N`) | `MODULE_ENGINE_EXOTIC_0N_<STANDARD\|LIGHTWEIGHT\|POWER>` | 18 |
| `Engine2` | `Engine` | `Engines_B` (family folder `Exotic_0N`) | `MODULE_ENGINE_B_EXOTIC_0N_<VARIANT>` | 18 |
| `Stabilisers` | `Stabilisers` | `Stabilisers` (family folder `Exotic_0N`) | `MODULE_STABILISER_EXOTIC_0N_<VARIANT>` | 18 |
| `Boost` | `Boost` | `Boost` (family folder `Exotic_0N`) | `MODULE_BOOST_EXOTIC_0N_<VARIANT>` | 18 |
| `FrontBody` | `FrontBody` | `FrontBodies` | `MODULE_FRONTBODY_EXOTIC_0N` | 6 |
| `RearBody` | `RearBody` | `RearBodies` | `MODULE_REARBODY_EXOTIC_0N` | 6 |
| `SidePods` | `SidePods` | `SidePods` | `MODULE_SIDEPODS_EXOTIC_0N` | 6 |
| `FrontBumper` | `FrontBumper` | `FrontBumpers` | `MODULE_FRONTBUMPER_EXOTIC_0N` | 6 |
| `RearBumper` | `RearBumper` | `RearBumpers` | `MODULE_REARBUMPER_EXOTIC_0N` | 6 |
| `RearSpoiler` | `RearSpoiler` | `RearSpoilers` | `MODULE_REARSPOILER_EXOTIC_0N` | 6 |

72 core modules and 36 body modules. 108 in total.

Name rules that protect these IDs from text matching in live code:

- No instance inside a module template (the module Model and its descendants) has a name containing `cockpit`, `engineon`, `engineoff`, `booston`, `stabiliseron` or `stabilizeron`. Live code matches these words in instance paths: `cockpit` picks the cockpit light colours for Neon parts (`VehicleBuildService` 58-60, `OwnedGarageDisplay` 53, `PaintClient` 100-104); the other five classify VFX (`VehicleVFXClient` 162-168, `VehiclePreviewVFXClient` 96-99).
- Cockpit templates keep the Piercer names `COCKPIT_EXOTIC_0N`, `CockpitRoot_DoNotRename` and `COCKPITS_ReplaceAssetsHere`. The rule above does not apply to them.
- No body module instance name contains `engine`, `boost`, `stabiliser` or `stabilizer`. "Engine Deck" is a `DisplayName` only.
- No ID contains `BRUISER_`. Only Engine2 IDs contain `ENGINE_B`.
- IDs are unique across all categories, not only inside Exotic.

### 6.3 Slots

On every Exotic cockpit: `ModuleSlots/SLOT_<SlotId>`, all with `FixedSlot=true`, each with a child `Mount_DoNotRename` at the root origin. All six cockpits carry the same ten slot folders, because the catalogue reads the slot list from the first cockpit.

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

New saved slot keys: `FrontBody`, `RearBody`.

### 6.4 Other permanent names

| Name | Value |
|---|---|
| `CategoryId` | `exotic` |
| Feature flag key | `VehicleClass_exotic` |
| VFX template folders | `EngineJet_Exotic`, `BoostJet_Exotic`, `StabiliserJet_ExoticLeft`, `StabiliserJet_ExoticRight` |
| Catalogue chunk modules | `VehicleCatalogData.PIERCER_1`, `PIERCER_2`, later `EXOTIC_<n>` |

### 6.5 Values decided by builders

| Item | Value |
|---|---|
| New upgrade `PathId`s for `FrontBody` and `RearBody` modules (saved keys in `V2UpgradePoints`) | **Filled by the integrator after build** (from `upgradePaths[].PathId` in `balance.json`) |
| Upgrade path donor per core module and per body module | **Filled by the integrator after build** (from `upgradePathDonor` in `balance.json`) |
| Cockpit and module stat values, and the stock rating of each of the six builds | **Filled by the integrator after build** (from `scripts/exotic_category/balance/balance.json` and its report) |
| `DriverSeatOffsetX/Y/Z` and `PassengerSeatOffsetX/Y/Z` per cockpit | **Filled by the integrator after build** (starting point: driver about (-1.8, 0.25, 0.45), passenger mirrored at +1.8) |
| VFX socket count per cockpit and per module | **Filled by the integrator after build** |
| Number and names of `EXOTIC_<n>` catalogue chunks, and the new `Revision` | **Filled by the integrator after build** |
| Part count per full build | **Filled by the integrator after build** |

Fixed rules (from `INTERFACE.md`, not open to builders):

- Standard core modules: `Price = PurchasePrice = 0`, capacity 2, `MaxPointsPerPath = 3`. They are included free with the cockpit. An extra copy is not free: see the economy rules in section 14.
- Lightweight and Power: `Price = PurchasePrice = 12%` of the cockpit price, capacity 6, point costs 8/10/12/15/18/22% of the variant price rounded to 100. `VariantOrder` 10/20/30. `NeonPrice` 5000/6500/8000.
- Body parts by kit 01..06: `Price` 8000, 11000, 14000, 18000, 23000, 30000. Body `NeonPrice` 6500, 7000, 7500, 8000, 8500, 9500. Capacity 6, `MaxPointsPerPath = 3`.
- Body module stats stay at Piercer accessory LVL1 magnitude for every kit. Flavour differs between kits; size does not.
- Character against the Piercer of the same tier: `TopSpeed` and `SteeringResponse` up; `Weight` down; `HoverStability`, `DriftControl` and `BoostDuration` down.
- Stock build = cockpit + four Standard core modules + six default body modules. Its rating must be within 3 of the target and inside the tier band.

## 7. Required changes

### 7.1 Stage 0: prepare (no game code)

| # | Item | Owner |
|---|---|---|
| 0.1 | This contract | `docs/architecture/exotic-category-contract.md` |
| 0.2 | Capture tools accept place 133417340424236 | `scripts/studio_export_snapshot.lua` (23, 31), `scripts/studio_capture.py` (11), `scripts/import_studio_snapshot.py` (129) |
| 0.3 | Before capture; projection check | `roblox/captures/exotic-before/` |
| 0.4 | No-save sandbox on (after the capture, so the capture holds `false`) | Attribute `StudioVehicleSandboxEveryPlay = true` on `ReplicatedStorage.Config.Player.Onboarding`; spec `scripts/exotic_category/stage_0/spec-sandbox-on.json` |
| 0.5 | Golden "before", run twice | Runner `scripts/exotic_category/golden.lua` (section 8); before output `scripts/exotic_category/golden-before.txt`; second-run evidence **Filled by the integrator after build** |

The rows are in the order they were done.

The sandbox is not optional here. With API access off and the sandbox off, `ProfileServer` kicks the player because the profile cannot load.

### 7.2 Stage A: every changed owner and the exact change

One reversible bundle through `scripts/feature_installer.py` (source, new-module, folder and attribute operations; AUDIT, APPLY, ROLLBACK). Every new behaviour is opt-in through data that Piercer does not have.

**Server**

| Owner | Before lines | Exact change | Piercer effect |
|---|---|---|---|
| `ServerStorage.Modules.Game.Garage.GarageServer` `buyCockpitInstance` | 514-541 | New order: (1) find the cockpit in the requested category without mutating the profile; (2) the cockpit's own `CategoryId` attribute is the category written, and it must equal the requested category when one was sent; (3) flag check; (4) capacity and cash checks with today's messages and order; (5) pre-check every default module (template exists, slot exists, type and folder fit), else `false, "Vehicle unavailable."`; (6) only then set `CurrentCategory`, debit, create the vehicle and attach defaults. Unknown cockpit still returns `"Cockpit not found."` | Same replies, text and order for every request the client can send. A mismatched `CategoryId` is now refused (section 8 exception). |
| `GarageServer` default grants | 413-513 | The four legacy slots exactly as today. For every other `SLOT_<Id>` on the cockpit, read `Default<Id>ModuleId` when present. A new-slot default is granted only when the slot is empty **and** no owned instance already has the same `TemplateId` with `GrantedForVehicleId == vehicleId`. No new record fields. | None. Piercer cockpits carry no new-slot default attributes. The legacy grant loop is unchanged. |
| `GarageServer` `coreSlotRequired` | 572-579 | `FrontBody` and `RearBody` are required when the cockpit has those slots | None. Piercer has neither slot. |
| `GarageServer` `buyModuleInstance` | 601-611 | Look the module up in the target vehicle's category (fall back to `CurrentCategory` as today), then the flag check | None while the target is a Piercer |
| `GarageServer` reply path | 814-853 | A missing cockpit or module template for an owned vehicle is skipped with a `warn`, never a throw. As built: a vehicle whose cockpit template is missing or not `V2Materialised` is left out of the vehicle summaries with one warning per category and cockpit. Missing module templates already do not throw. | None while templates exist |
| `ServerStorage.Modules.Game.Garage.GarageClientProfile` | 73, 102-109 | Same skip-with-warning rule. As built: the reply carries no `Performance` block when the current cockpit template is missing. | None while templates exist |
| `ServerStorage.Modules.Game.Garage.GarageCatalogLookup` | 97, 123 (and 131 as built) | The two `"bruiser"` literals become the module's own `CategoryId` attribute, falling back to today's value. Line 123 is the price rule for a module with no positive price (section 14). | None. Piercer modules carry `CategoryId="bruiser"`. |
| `ServerStorage.Modules.Game.Garage.GarageCatalogService` | 162-218 (and 225-232 as built) | A category folder with `FeatureFlag` whose flag is off is left out of the catalogue. Slot field `RailLabel` and module field `CardTitle` are passed to the client when the attributes exist. | None. `PIERCER` has no `FeatureFlag`; its slots and modules have neither attribute. |
| `ServerStorage.Modules.Game.Garage.OwnedGarageDisplay` | 11-15 | Match the `CategoryId` attribute first, then the folder name as today | None. `bruiser` now matches by attribute and resolves to the same folder as the first-child fallback did. |
| `ServerStorage.Modules.Game.Vehicles.DriverSeatServer` | 34-41, 131 | Use cockpit attributes `DriverSeatOffsetX/Y/Z` when present; all three absent means the global `Config.Vehicles.DriverSeat` values as today | None |
| `ServerStorage.Modules.Game.Garage.VehicleBuildService` `addPassengerSeat` | 201-236 | Use cockpit attributes `PassengerSeatOffsetX/Y/Z` when present; absent means the global `Config.Activities.Passengers` values as today | None |

**Client**

| Owner | Before lines | Exact change | Piercer effect |
|---|---|---|---|
| `ReplicatedStorage.Modules.Game.UI.GarageWorkspaceUI` `artworkDefinitions` | 11-23 | Two new rows: `FrontBody` (label "Front Body", `SortOrder=72`) and `RearBody` (label "Rear Body", `SortOrder=74`), `ShowInBuild=true`, `ShowInCustomise=true`, images reused from existing artwork entries. A row appears only when the current category has that slot. | Eight cards as today |
| `ReplicatedStorage.Modules.Game.Garage.GarageUI` | about 332, 385, 541 | Where a slot label is shown, use the slot's `RailLabel` when present, else today's label | None |
| `ReplicatedStorage.Modules.Game.UI.GarageModuleCardViewModel` (and `GarageUI` where the card is built) | 6-13 | Card title is `CardTitle` when present, else today's title. Variant tag logic is unchanged for modules without `CardTitle`. Exotic body modules must not read "Level n". | None |
| `ReplicatedStorage.Modules.Game.Garage.GarageVehiclePreviewProfile` | 28-36 | Any cockpit key `Default<X>ModuleId` beyond the legacy ones is an optional default for slot `X` | None |
| `ReplicatedStorage.Modules.Game.Vehicles.Performance.VehiclePerformanceResolver` | 10-15, 69, 99 | Same optional defaults. Line 99: use the module's `RatingReferenceCockpitId` when present, else `bruiser_01` as today. | Ratings unchanged |
| `ReplicatedStorage.Modules.Game.Garage.PreviewCameraClient` | 10 | `FrontBody="Front"`, `RearBody="Rear45"` added to the view map | None |

**As built.** The hunk-by-hunk record, with the reason each hunk leaves Piercer unchanged, is `scripts/exotic_category/stage_a/server/CHANGES.md` and `scripts/exotic_category/stage_a/client/CHANGES.md`. Those two files win over this summary. The builders delivered these items beyond `INTERFACE.md`. Each is opt-in. The integrator and the `delivery-reviewer` accept or drop each one before APPLY:

| Owner | Hunk | Addition |
|---|---|---|
| `GarageCatalogLookup` `moduleLockedMessage` (131) | GL3 | The lock message looks the source cockpit up in the module's own category, so it shows the display name and not the raw id |
| `GarageCatalogService` snapshot (225, 232) | GC5, GC5b | The cached catalogue is rebuilt under a new revision when the on/off state of a flagged category changes. With no flagged category it is built once, as today. |
| `GarageServer` (56, 854) | GS1, GS11 | Requires `Core.FeatureFlags`; passes one gate function, `categoryFlagEnabled`, to `GarageCatalogService` so the catalogue and both buy actions cannot disagree |
| `GarageServer` `buyCockpitInstance` | GS7 | The reply to a mismatched `CategoryId` is `"Cockpit not found."` |
| `GarageUI` (347, 353), `GarageModuleCardViewModel` (29, 47) | U5, U6, V1-V3 | Card rows carry two display-only fields, `Title` and `Tag`. The six client sources must be installed together. |

**Catalogue**

| Owner | Exact change |
|---|---|
| `ReplicatedStorage.Modules.Game.Vehicles.VehicleCatalogData` | Keeps its path. Becomes a generated index: `Revision`, `SchemaVersion=1`, and for each name in a generated list `require(script:WaitForChild(name))`, copying records into `Cockpits` and `Modules` with a duplicate-id assert, then the existing freeze logic. |
| New children `VehicleCatalogData.PIERCER_1`, `PIERCER_2` | Each returns `{["Cockpits"]={...},["Modules"]={...}}` with today's record text. Packing: group by category folder (`TemplatePath[1]`); cockpits then modules, sorted by id; greedy fill to 150,000 characters; assert every source is under 190,000. |
| `Revision` | The same algorithm over the merged data. With Piercer only it must equal `469d9bd81944a3d71a127ea1d5e702720b75f55524391cb27008e05e8fc2cf0e`. |
| `ReplicatedStorage.Modules.Game.Vehicles.VehicleCatalog` and every reader | **Unchanged** |
| `scripts/performance_phase3/catalogue.py` | `project(h)` unchanged. `PUBLIC` gains the six new `Default<Slot>ModuleId` names and `RatingReferenceCockpitId` (other new names only if a reader needs them from the client data). New `chunk_sources(data)`. |
| `scripts/performance_phase3/check_catalogue.py`, `scripts/performance_phase4/check_projection.py` | Compare every generated source with the manifest rows at and under `VehicleCatalogData` |
| `scripts/exotic_category/catalogue/catalogue_gen.lua` | Read-only Luau generator. Returns `function() -> { index, chunks = { {name, source}, ... }, revision, cockpits, modules }` from `ServerStorage.Assets.Vehicles.Categories`. It never writes. It rejects non-ASCII text and numbers that print as `e`, `inf`, `nan` or `-0`. Both installers call it and write the sources. |

**Config**

| Owner | Exact change |
|---|---|
| `ServerStorage.Config` | Attribute `Flag_VehicleClass_exotic` (boolean Studio override). Initial value and the stage that creates it: **Filled by the integrator after build**. Absent reads as off. |
| `ReplicatedStorage.Config.UI.GarageReplacement.ModuleArtwork` | Two config folders, `FrontBody` and `RearBody`, are proposed in `scripts/exotic_category/stage_a/client/config_ops.json`: the same six attributes as the eleven live entries, images reused from the live `FrontBumper` and `RearBumper` entries, no upload. They only supply the card image. Whether they are installed with the Stage A bundle: **Filled by the integrator after build** |

Opt-in data attributes read by Stage A code (absent means today's behaviour):

| Where | Attribute | Type | Meaning |
|---|---|---|---|
| Category folder | `FeatureFlag` | string | Flag key. See section 12. |
| Slot folder | `RailLabel` | string | Player-facing slot label in this category |
| Module model | `CardTitle` | string | Title on the module's shop and inventory card. Set on all Exotic modules to the module `DisplayName`. |
| Module model | `RatingReferenceCockpitId` | string | Reference chassis for the module rating. Exotic modules use `exotic_03`. |
| Cockpit model | `Default<SlotId>ModuleId` | string | Default module for a slot other than the four legacy ones: `DefaultFrontBodyModuleId`, `DefaultRearBodyModuleId`, `DefaultSidePodsModuleId`, `DefaultFrontBumperModuleId`, `DefaultRearBumperModuleId`, `DefaultRearSpoilerModuleId` |
| Cockpit model | `DriverSeatOffsetX/Y/Z` | number | Driver seat offset in root local space |
| Cockpit model | `PassengerSeatOffsetX/Y/Z` | number | Passenger seat offset in root local space |

The four legacy slots keep their seven legacy attribute names exactly as the code reads them today (`DefaultEngineModuleId`, `DefaultFrontEngineModuleId`, `DefaultRearEngineModuleId`, `DefaultEngineBModuleId`, `DefaultStabilisersModuleId`, `DefaultStabiliserModuleId`, `DefaultBoostModuleId`). Exotic cockpits set all seven.

Stage A order: build, compile every file with `loadstring` in Edit, pure tests, AUDIT (expect state "before", 0 changed), `delivery-reviewer`, APPLY, ROLLBACK, capture compare, APPLY, recapture, golden "after" against golden "before" (section 8).

The capture compare after ROLLBACK must show no delta other than the Stage 0 attribute `StudioVehicleSandboxEveryPlay` (`false` in the before capture, `true` live; section 4). `ReplicatedStorage.Config` is a capture root, so that one attribute always shows.

### 7.3 Stage B: content (one dedicated installer under `scripts/exotic_category/`)

| # | Item | Where |
|---|---|---|
| B1 | Four Exotic-scaled jet template folders, cloned and scaled from the stock ones | `ReplicatedStorage.Assets.VFX.VehicleTemplates` |
| B2 | 108 module templates in ten folders: `ModuleRoot_DoNotRename`, `MountAttachment`, paint-channel folders, sockets, upgrade paths, attributes | `ServerStorage.Assets.Vehicles.Categories.EXOTIC.MODULES_InterchangeableWithinCategory` |
| B3 | 6 cockpit templates: root, ten slot folders, sockets, underglow mount, default colours, ten defaults, seat offsets, stats, price, `V2Materialised=true` | `...EXOTIC.COCKPITS_ReplaceAssetsHere` (first child of `EXOTIC`; `EXOTIC` added after `PIERCER`) |
| B4 | Category folder attributes `CategoryId="exotic"`, `DisplayName="Exotic"`, `FeatureFlag="VehicleClass_exotic"`, plus `Description` and `ModuleCompatibility` as `PIERCER` has them | `...Categories.EXOTIC` |
| B5 | Preview mirror: a clone of the category with every `VehiclePerformanceV2UpgradePaths` and `UpgradePaths` folder removed | `ReplicatedStorage.Assets.VehiclePreviews.Categories.EXOTIC` |
| B6 | Regenerated catalogue index and chunks, new `Revision` | `VehicleCatalogData` and children, through `catalogue_gen.lua` |
| B7 | Read-only checks: generator output identical, preview parity, template-path walk, paint-channel census, socket parents | Integrator |

Template format rules (same as Piercer):

- Root space: +X right, +Y up, forward -Z. `CockpitRoot_DoNotRename` is a copy of the Piercer root (7.5 x 1.2 x 10.5) at the spec origin. All ten mounts at the origin.
- Paint: channel folders plus a `PaintChannel` attribute on each part. Spec channel `thrust` becomes `ThrustColor` under `THRUST_COLOR_WhiteByDefault`. Spec channel `driver` parts are dropped.
- Neon parts on `FrontBody` and `RearBody` go in `LIGHTS_AlwaysOn` with `PaintChannel="Lights"`, Material Neon, part names without `neon`. Neon parts on other modules go in `NEON_OptionalLights`.
- VFX sockets are Attachments on the module or cockpit root part, flame along local +Z, `VFXSocket=true`, `VFXTemplate` naming an Exotic template.
- Core modules mirror the live Piercer family attribute set (donor `MODULE_<TYPE>_BRUISER_03_<VARIANT>`) with `SourceCockpitId="exotic_0N"` and `CategoryId="exotic"`.
- Body modules mirror the live accessory attribute set (donor `MODULE_<TYPE>_LVL1`; `FrontBody` uses the `FrontBumper` donor, `RearBody` the `RearBumper` donor): `Price` only, no `PurchasePrice`, no `SourceCockpitId`.
- Engine1 modules: `EnginePosition="Front"`, `RearEngine=false`. Engine2 modules: `EnginePosition="Rear"`, `RearEngine=true`. Both `ModuleSlot="Engine"`.

Pilot first: Wedge (`exotic_03`) and its ten modules only. With the flag off, golden parity again. Then flag on: buy, customise, spawn and drive it. Fix the recipe (seat, flame size, lamps, camera) before building the other five cockpits and their modules.

The pilot is a complete install of a declared content set: `exotic_03` and its ten default modules. It is not a partial install. It is removed with REMOVE before the full set is installed. That is allowed here because nothing is saved. The installer never extends a prior install in place.

The content installer must: assert place 133417340424236 and Edit mode; preflight unique paths; refuse a partial prior install (anything that is not exactly one declared content set, complete); create authoring, preview and catalogue together; on removal, delete exactly what it created and fail loudly if a created root was edited. It never writes to `Workspace.VehicleCategoryBlockouts`, `ServerStorage.Archive` or `ServerStorage.NeoTokyoRacers`.

### 7.4 Builder folders

Builders write repo files only, one folder each, and never touch Studio state or Git. The integrator owns Studio, captures, compiles, installs, review, Play tests and Git.

| Area | Folder |
|---|---|
| Contract | `docs/architecture/exotic-category-contract.md` (this file) |
| Catalogue split | `scripts/exotic_category/catalogue/` and the two `scripts/performance_phase*` tools named above |
| Balance | `scripts/exotic_category/balance/` |
| Server sources | `scripts/exotic_category/stage_a/server/` (`after/`, `ops.json`, `CHANGES.md`) |
| Client sources | `scripts/exotic_category/stage_a/client/` (`after/`, `ops.json`, `config_ops.json`, `CHANGES.md`) |
| Content installer | `scripts/exotic_category/stage_b/`. Installer file names: **Filled by the integrator after build** |

## 8. Must preserve

- **Piercer parity.** For every `GarageInvoke` request the client can send on a Piercer: same success flag, same message text, same reply content, same order of checks. `CategoryId "bruiser"` and the folder name `PIERCER` stay as they are. `PIERCER` stays the first child of `Categories`.
- **One deliberate exception.** `BuyCockpitInstance` with a `CategoryId` that is not exactly the cockpit template's `CategoryId` attribute is refused after Stage A. That covers an unknown category (`"zzz"`) and the folder name (`"PIERCER"` or `"piercer"`). Before Stage A such a request succeeded through the lookup fallback (`GarageCatalogLookup` 15-24: folder-name match, then first child) and the client string was saved as the vehicle's `CategoryId` (`GarageServer` 378, 517). No client sends this: the UI sends the catalogue `CategoryId`, which is `"bruiser"`. A request with no `CategoryId` is unchanged.
- **Golden sequence.** Runner: `scripts/exotic_category/golden.lua`, pasted into `execute_luau` on the client in a fresh sandbox Play. It is the 18 steps of `scripts/architecture/p5/golden.lua` plus eight crafted calls. Each reply is canonicalised (sorted keys, generated ids and the catalogue revision normalised, numbers `%.6g`) and reported as one line: label, length, FNV-1a hash, success and message. Before output: `scripts/exotic_category/golden-before.txt`.
  - Steps 01-18: GetInitial, BuyCockpit, BuyModule, BuyCosmetic, CosmeticColour, BuyNeon, Upgrade, CockpitColour, Unaffordable, BadField, UnknownCockpit, GetInitial, Select, Spawn, Exit, ReEnter, Despawn, GetInitialKnownRev.
  - X01-X06 (must stay identical): UnknownModule, WrongSlotType, UnknownSlot, BuyNoCategory, GarageFull, GetInitial.
  - Z01-Z02 (expected to differ after Stage A): UnknownCategory (`CategoryId="zzz"`), GetInitialAfter.

  Lines 01-18 and X01-X06 must be identical:
  1. between two "before" runs (stability);
  2. before and after Stage A;
  3. before, and with Exotic installed and the flag off.

  Z01 and Z02 are the exception above. Before: Z01 passes the category step, is refused later with `"Garage full. ..."`, and leaves `CurrentCategory = "zzz"` on the session profile, which Z02 shows. After Stage A: Z01 is refused with `"Cockpit not found."` and writes nothing, so Z02 is expected to equal X06 (same length and hash). If it does not, find the differing field before accepting. Z01 and Z02 must then be identical between the Stage A run and the run with Exotic installed and the flag off.
- The merged catalogue table deep-equals the old single-source table, and `Revision` is unchanged, while Piercer is the only category.
- Eight unchanged slot cards in the Piercer garage. Piercer ratings unchanged.
- Saved IDs and `SchemaVersion = 1`.
- `MoneyService.Debit` as the only spend path. `Core.Net` on `GarageInvoke`. `GarageRequestGuard` unchanged.
- `ClientBase` owns startup and starts `GarageUI`. `DriveSessionClient` owns vehicle callbacks. `StarterGui.ScreenOrientation = LandscapeSensor`.
- One physics tuning: the vehicle root, collision box and hover sensors are the Piercer root part.
- `VehicleCatalog` and every catalogue reader.
- Protected roots (`ServerStorage.Archive`, `ServerStorage.NeoTokyoRacers.VehiclePerformanceV2_Staging`) and `Workspace.VehicleCategoryBlockouts` are not written.

## 9. Explicit exclusions

- Space Racers v2. Nothing is installed, copied or published there.
- Card images. No upload. Dealership cards show the text placeholder; the free-roam menu and race entry show a blank picture.
- Final meshes. Geometry is the blockout primitives in the final template format.
- Hardening of existing Piercer rules: blocking retired or hidden modules, the legacy-slot re-grant loop, any other tightening. Findings are recorded in `docs/06_current_known_issues.md`, not fixed.
- Saving tests. Nothing can save in this place. Persistence stays open under DATA-01 and DATA-02.
- New remotes, actions, argument fields, saved profile fields or owners.
- Refund or compensation logic. No Cash grant of any kind.
- A sell path, or a change to the 10-vehicle garage cap.
- New driving mechanics, per-class physics tuning, liveries, audio profiles.
- Job and race pay review.
- Cockpit lamps: Exotic cockpits carry no lamps of their own, so the cockpit front and rear light swatches do nothing on an Exotic.
- Deleting or moving `Workspace.VehicleCategoryBlockouts`.
- Publishing.

## 10. Canonical owners

No owner is added. Every concern keeps the owner it has today.

- **State:**
  - Ownership, purchase, equip, upgrade, selection: `ServerStorage.Modules.Game.Garage.GarageServer` with its service modules (`GarageCatalogLookup`, `GarageModuleTransaction`, `GarageModuleInventory`, `GarageModuleInstanceCustomization`).
  - Category, slot and module definitions: the authoring tree `ServerStorage.Assets.Vehicles.Categories`. The slot list of a category is the `ModuleSlots` folder of its first cockpit.
  - Server catalogue sent to the client: `GarageCatalogService` (built once per server, frozen).
  - Client definitions: `VehicleCatalog` over generated `VehicleCatalogData`.
  - Client garage state: `GarageUI`.
  - Flag state: `ServerStorage.Modules.Core.FeatureFlags`.
- **Geometry/visibility (UI):** `GarageUI` with `GarageBrowserUI` (dealership), `GarageWorkspaceUI` (slot rail, module browser, upgrades, paint) and `GarageComponents` (shared cards, bars, shell layout). Slot rail rows: `GarageWorkspaceUI.artworkDefinitions`. Module card text: `GarageModuleCardViewModel`.
- **Geometry (world):** the cockpit and module templates. Collision, mass and hover sensors: `CockpitRoot_DoNotRename` only.
- **Preview:** `PreviewVehicleClient` builds the model from `ReplicatedStorage.Assets.VehiclePreviews`; `GarageVehiclePreviewProfile` chooses the default modules; `PreviewCameraClient` owns the preview camera; `PaintClient` owns preview paint.
- **Runtime attachment:**
  - Spawn, mount, weld, paint and passenger seat: `VehicleBuildService`. Free-roam and race placement: `VehicleSpawnService`. Exit, park, despawn: `VehicleLifecycleService`.
  - Driver seat position: `DriverSeatServer`.
  - Owned-garage display copies: `OwnedGarageDisplay`.
  - Spawned-vehicle performance: `VehiclePerformanceServer`.
  - VFX: `VehicleVFXClient` tracks vehicles; `VehiclePreviewVFXClient` is the only thing that clones VFX templates onto sockets. No second attacher.
  - Driving: `DrivingClient`, started by `DriveSessionClient`.
- **Persistence/authoritative mutation:** `PlayerProfileSchema` (shape), `ProfileServer` and `ProfileStore` (load, save, lease), `ProfileCompatibility` (transient view). Garage commands mutate the session profile and commit through `ProfileServer.commit_garage`. Cash is spent only through `MoneyService.Debit`.

## 11. Inputs, outputs and dependencies

| Kind | Item |
|---|---|
| Input | `scripts/vehicle_blockouts/specs/exotic.json` (`cockpits`, `kits`, `modules[slot][id]`) |
| Input | `scripts/exotic_category/balance/balance.json` (cockpit and module attributes, upgrade path donors or explicit paths) |
| Input | Live Piercer donors for the root part, attribute sets, upgrade paths and VFX templates |
| Input | Before capture and its source blobs |
| Output | Authoring category `ServerStorage.Assets.Vehicles.Categories.EXOTIC` |
| Output | Generated `ReplicatedStorage.Assets.VehiclePreviews.Categories.EXOTIC` |
| Output | Generated `VehicleCatalogData` index and chunks |
| Output | Four VFX template folders |
| Dependency | `Core.FeatureFlags`, `Core.Net`, `MoneyService` (all unchanged) |
| Dependency | `VehiclePreviews` and `VehicleCatalogData` are regenerated together after any authoring change, and Play is restarted |

## 12. Feature flag

| Item | Rule |
|---|---|
| Key | `VehicleClass_exotic`, named by the `FeatureFlag` attribute on the `EXOTIC` folder |
| Read | `FeatureFlags.IsEnabled(key, false)`. Default is off. |
| Studio override | Boolean attribute `Flag_VehicleClass_exotic` on `ServerStorage.Config` |
| Live value | Creator Dashboard config, 60-second refresh (not used in this place) |
| Flag off: catalogue | The category is left out of the server catalogue, so the dealership does not show it |
| Flag off: buy cockpit | `BuyCockpitInstance` for an Exotic cockpit, sent with `CategoryId="exotic"` as the UI sends it, returns `false, "Vehicle unavailable."` |
| Flag off: buy module | `BuyModuleInstance` for an Exotic module onto an owned Exotic returns `false, "Module unavailable."`. The module is looked up in the target vehicle's category first, so the same module onto a Piercer returns today's `"Module not found."` in any flag state. In this place an Exotic can be owned with the flag off only when the flag is switched off during the session. |
| Flag off: owned vehicles | Never hidden or blocked. Select, spawn, drive, equip owned parts, paint and upgrade are not gated. |
| Templates | The flag never removes or hides templates |
| A folder with no `FeatureFlag` | Today's behaviour. `PIERCER` has none. |

Today the server catalogue is built once per server and frozen. As built (section 7.2, hunks GC5 and GC5b), Stage A rebuilds it under a new revision when the on/off state of a flagged category changes. The two buy checks read the flag when the request arrives. In Studio the override attribute is read on every call, so a change on the running server takes effect at once.

Restart Play after a flag change all the same, unless the test is the mid-session switch itself. Whether an open dealership refreshes its list without a restart: **Filled by the integrator after build**.

The flag gates **buying only**. It is not a rollback of content and it does not undo a sale.

## 13. Entry, transitions, exit and cleanup

No new screen, state machine, connection, loop or task.

| Step | Behaviour |
|---|---|
| Entry | Dealership opens as today. Category buttons are built from the server catalogue: `ALL`, then categories sorted by display name. |
| Browse | Selecting a cockpit builds the 3D preview with all ten default modules and shows the rating from `VehicleCatalogData` |
| Buy | `BuyCockpitInstance {CockpitId, CategoryId}`. On success the flow goes to Paint, then the Hub, as today. |
| Customise | The slot rail shows ten cards for an Exotic and eight for a Piercer. Add Modules, Upgrade Modules and Paint Shop work per slot. |
| Back | Browsing a module and going back clears the unbought preview. Leaving customise clears temporary overrides. Unchanged owners. |
| Switch | Selecting a Piercer after an Exotic (and the reverse) changes `CurrentCategory` through `syncLegacyFromCurrentVehicle`, as today |
| Spawn | `SpawnVehicle` or `SpawnOwnedVehicleFromFreeRoam`. Ten modules mount, the driver sits at the per-cockpit offset, the passenger seat is added. |
| Exit | HUD exit, park, despawn through `VehicleLifecycleService`, as today |
| Cleanup | Preview models, VFX clones and display copies are released by their existing owners. Seat offsets are read once per build. |

Failed purchases leave no state behind: after Stage A, `CurrentCategory` is not written until the purchase is certain.

## 14. Client/server authority and remote validation

**Remotes.** None new. No new action, argument field or saved field. Everything stays on `Remotes.Garage.GarageInvoke` through `Core.Net` and `GarageRequestGuard`, which is unchanged: action allowlist, 20-field limit, identifiers are strings of at most 240 characters, unknown fields are rejected with `"Unknown request field."`, rate limit and busy lock.

**Economy rules.**

- Cash is spent only through `MoneyService.Debit`, with today's reasons (`CockpitInstance`, `ModuleInstance`, `ModuleUpgrade`, `Neon`, `VehicleCosmetic`) so analytics SKUs stay stable.
- Every check that can fail runs **before** the debit: cockpit found, category match, flag, capacity, cash, every default module (ECON-01).
- Prices come from template attributes on the server. A client price is never read.
- No grants. Exotic adds no `EconomyServer` command, writes no Cash upward and adds no refund.
- Every Exotic cockpit has `Price > 0`.
- Lightweight, Power and body modules set `Price > 0` explicitly (core modules also `PurchasePrice`).
- Standard core modules set `Price = PurchasePrice = 0`. They are included free with the cockpit and are family-locked. An extra copy is not free. `GarageCatalogLookup.modulePurchasePrice` (114-126) treats 0 as unset, so an extra copy is charged by the existing rule `max(1000, floor(source cockpit Price x 0.12))`, as on Piercer. That equals the Lightweight and Power price of the same family.
- That rule is correct for Exotic only because Stage A changes `GarageCatalogLookup` 123 to the module's own `CategoryId`. Every Standard module must therefore carry `SourceCockpitId` and `CategoryId="exotic"`. Without them the source cockpit is not found and the charge is $1,000, whatever the cockpit costs.
- The same function fills the `Price` field of the module in the server catalogue, so the card and the debit agree.

**Invariants.**

1. A rejected request changes neither Cash nor any profile field, including `CurrentCategory`.
2. The saved `CategoryId` of a vehicle is the cockpit template's own `CategoryId` attribute, never a client string.
3. A module is installed only in a slot that exists on that cockpit, with matching `ModuleType` and folder, in the vehicle's own category.
4. A bought Exotic has all ten slots filled, or the purchase is refused before the debit.
5. A new-slot default is granted at most once per vehicle and template.
6. `FrontBody` and `RearBody` are never left empty by a module move.
7. Each module instance is referenced by at most one slot (`GarageModuleInstanceCustomization.Validate`, unchanged).

**Threat cases** (each must be refused with Cash intact):

| Request | Expected |
|---|---|
| Unaffordable Exotic, then `GetInitial` | `"Not enough cash."`; `GetInitial` succeeds and the current vehicle is unchanged |
| Unknown `CategoryId`, or a `CategoryId` that does not match the cockpit | `"Cockpit not found."` (as built); nothing saved with a client-chosen category; `CurrentCategory` unchanged |
| Unknown `CockpitId` | `"Cockpit not found."` |
| `BuyModuleInstance` for an Exotic module onto a Piercer, any flag state | `"Module not found."` (as built) |
| `BuyModuleInstance` for a Piercer module onto an Exotic | `"Module not found."` (as built) |
| A Piercer module with `SlotId="FrontBody"` on a Piercer | `"Slot not found on this cockpit."` |
| Nose into Engine Deck | `"That module does not fit this slot."` |
| Side Engines part into Main Turbine (use a family that is owned, or the lock message comes first) | `"That module does not fit this slot."` |
| Locked family (source cockpit not owned) | `"Buy <name> before buying this module family."` |
| `BuyCockpitInstance` for an Exotic cockpit with `CategoryId="exotic"`, flag off | `"Vehicle unavailable."` |
| `BuyModuleInstance` for an Exotic module onto an owned Exotic, flag switched off during the session (set `Flag_VehicleClass_exotic=false` on `ServerStorage.Config` of the running server) | `"Module unavailable."` |
| Move a default body part to another Exotic, reselect the first, count instances | No extra free part |
| Extra request field (for example a price) | `"Unknown request field."` |

Rows marked "as built" take their text from `scripts/exotic_category/stage_a/server/CHANGES.md` (hunks GS7 and GS9). Text confirmed in Play: **Filled by the integrator after build**.

**Charge cases** (each must debit exactly the stated amount through `MoneyService.Debit`):

| Request | Expected |
|---|---|
| Buy a second Standard Exotic core module for a cockpit that is owned | The catalogue `Price` of the module and the Cash debit both equal 12% of the cockpit price. Not 0 and not $1,000. For `exotic_03`: 52,800. |
| Buy a Lightweight or Power module | Debit equals the module's `Price` attribute |
| Buy a body module | Debit equals the module's `Price` attribute |

## 15. Stable IDs, saved schema/API version and migration impact

**Schema unchanged.** `SchemaVersion` stays 1. No migration. No new record field. The change is additive values only:

| Saved place | New values |
|---|---|
| `Vehicles[id].CategoryId` | `exotic` |
| `OwnedCockpitInstances[id].TemplateId` | `exotic_01` .. `exotic_06` |
| `OwnedModuleInstances[id].TemplateId` | the 108 `ModuleId`s in section 6.2 |
| `Vehicles[id].InstalledModules` keys | `FrontBody`, `RearBody` |
| `OwnedModuleInstances[id].V2UpgradePoints` keys | existing Piercer `PathId`s (cloned paths) and the new body `PathId`s in section 6.5 |
| `OwnedModuleInstances[id].GrantedForVehicleId` | existing field, now also set on body-slot defaults |

Why no migration is needed: `CategoryId` is a free string, `InstalledModules` is a free dictionary, and `PlayerProfileSchema.Normalize` checks table shapes only. Persistence code iterates `pairs(vehicle.InstalledModules)` and never a fixed slot list. `CurrentCategory` is transient and is rebuilt from the current vehicle on load.

**Permanent IDs.** Every ID in section 6 is permanent from the first sale in a place that saves. They are never renamed, reused or repurposed. Display names, prices and stats may change.

**What an owned Exotic needs to keep loading.** For every saved Exotic vehicle, on every server that loads it:

1. A category folder under `ServerStorage.Assets.Vehicles.Categories` with `CategoryId="exotic"`.
2. A cockpit Model with the saved `CockpitId`, with `V2Materialised=true` and the 17 raw performance attributes.
3. A `ModuleSlots/SLOT_<SlotId>` folder with `Mount_DoNotRename` for every saved `InstalledModules` key.
4. A module Model with the saved `ModuleId` for every installed and owned instance, with `V2Materialised=true`, `ModuleType`, `ModuleFolder` and its upgrade path folders carrying the saved `PathId`s.
5. The matching preview copy and catalogue record, or the client has no model, rating or upgrade data for it.

**Why templates can never be removed once sold.** The profile stores IDs, not content. `VehicleModuleUpgradeRuntime` asserts that the current cockpit template exists and is materialised on every profile read, including `GetInitial`. Before Stage A a missing template fails every garage request for that player. After Stage A a missing template is skipped with a warning, so the garage still opens, but the player has paid for a vehicle they can no longer see, select or drive, and its module instances are orphaned. No installer rolls saved data back. So after the first saved sale: templates stay, IDs stay, slot folders stay, `PathId`s stay.

**The flag gates buying only.** Switching the flag off stops new sales and hides the dealership entry. It does not make an owned Exotic safe to remove.

**In this place** nothing can be saved (API access off, sandbox on), so no profile will hold an Exotic and content rollback is safe here. That is a property of this place, not of the design.

**API version.** `VehicleCatalogData` keeps `SchemaVersion=1` and its public shape (`Cockpits`, `Modules`, `Revision`). The index-plus-chunks layout is internal to the generated module. `GarageInvoke` payloads gain two optional reply fields (`RailLabel` on a slot, `CardTitle` on a module) that are absent for Piercer.

## 16. Expected scale, devices, streaming and failure

**Expected scale and bounded performance budget.**

| Dimension | Today | After |
|---|---|---|
| Categories | 1 | 2 |
| Catalogue records | 122 | 236 |
| `VehicleCatalogData` sources | 1 at 197,226 characters | index plus chunks, each under 190,000 (packed to 150,000) |
| Server catalogue payload | about 173 KB JSON | larger; exact size **Filled by the integrator after build**. Cached by revision after the first fetch. |
| Parts per full build | Piercer about 57 | Exotic about 150 to 195 (blockout primitives); exact **Filled by the integrator after build** |
| VFX sockets per vehicle | Piercer 12 | **Filled by the integrator after build** |
| Vehicle size | Piercer 20.5 x 29.2 | Exotic 10.94 to 11.90 wide, 23.68 to 25.47 long. Smaller in every direction, so preview pad, display bays, spawn clearance and camera distance are not at risk. |

No per-frame work is added. Catalogue chunks are required once at client start. Seat offsets are read once per build. Cost that grows with parts: one weld per part at spawn, the collision-group walk, the VFX scan, paint, and preview and display clones. This is untested on low-end devices and is recorded as deferred.

**Mobile, touch, controller and accessibility coverage.** Same components and one responsive composition. Slot cards and rails already scroll with eight slots; ten cards and fourteen paint targets use the same scrolling. No new layout, touch target or focus rule. Studio desktop is tested. Phone, tablet and controller are deferred with the open device gates (PERF-01, PERF-06).

**Streaming/open-world behaviour.** Unchanged. Vehicles are spawned by the server from templates under `PlayerVehicles`. VFX attach within 260 studs as today. No new world object, tag or scan.

**Failure, cancellation, retry and observability.**

- A refused purchase returns today's message and changes nothing.
- A missing template for an owned vehicle is skipped with one `warn` naming the system, the action and the stable ID. It never throws and never deletes the saved record.
- An unknown `CategoryId` or `SlotId` in a save is kept and ignored.
- Catalogue index: a duplicate id across chunks asserts at require time. This is deliberate; a silent merge would resolve the wrong template.
- Retry: `GarageInvoke` keeps its busy lock and rate limit. A double click cannot buy twice inside one request.
- Evidence owners: `ServerStorage.Runtime.NetStats` (calls and rejections per action), `ServerStorage.Runtime.Player.RuntimeProfiles.<UserId>` (`Dirty`, `VehicleCount`, `ModuleInstanceCount`, `LastError`), `MoneyService.RecentLedger()`, ServerBase and ClientBase `StartupState`.

## 17. Shared components/contracts to reuse

- UI: `GarageUI`, `GarageBrowserUI`, `GarageWorkspaceUI`, `GarageComponents`, `GarageModuleCardViewModel`. No copied coordinates, no page-specific layout. Existing artwork images are reused for the two new rail rows.
- Preview: `PreviewVehicleClient`, `PreviewCameraClient`, `PaintClient`, `GarageVehiclePreviewProfile`.
- Rating: `PerformanceCalculator`, `PerformanceDefinitions`, `VehiclePerformanceResolver`. The balance tool is a port of the live formula, not a second formula in the game.
- Upgrades: `PerformanceUpgradeRuntime` and `VehicleModuleUpgradeRuntime`, driven by path folders on the module.
- Paint and neon: channel folders and `PaintChannel` attributes as on Piercer.
- VFX: sockets and `VFXTemplate` selection in `VehiclePreviewVFXClient`. No VFX code change.
- Net and money: `Core.Net`, `GarageRequestGuard`, `MoneyService.Debit`.
- Flags: `Core.FeatureFlags`.
- Delivery: `scripts/feature_installer.py`, `scripts/studio_capture.py`, `scripts/performance_phase3/catalogue.py`, `scripts/performance_phase4/check_projection.py`, the 18-step sequence of `scripts/architecture/p5/golden.lua` (run through `scripts/exotic_category/golden.lua`, section 8), `scripts/validation_record.py`.

Documented exception: per-cockpit seat offsets. The global seat config stays the default owner of seat position; a cockpit attribute narrows it for that cockpit only.

## 18. Implementation/installer and rollback approach

| Stage | Installer | Before state comes from |
|---|---|---|
| 0 | Repo edits to three tool guards; `scripts/exotic_category/stage_0/` sandbox spec | Capture (`false`) |
| A | `scripts/feature_installer.py`, one bundle: after-sources, new chunk modules, attribute and folder ops. Inputs delivered: `stage_a/server/ops.json`, `stage_a/client/ops.json`, `stage_a/client/config_ops.json`, `catalogue/out/manifest.json` (all under `scripts/exotic_category/`). Combined spec and bundle file names: **Filled by the integrator after build** | `roblox/captures/exotic-before` |
| B | One dedicated canonical installer under `scripts/exotic_category/` with AUDIT, INSTALL and REMOVE in one scope. File names: **Filled by the integrator after build** | A fresh capture taken after Stage A |

After-files are complete sources made by copying the blob and editing it. Every projected source is compiled with `loadstring` in Edit before assignment. No in-game backup folders, no fallback implementation, no patch ladder: a failed installer is repaired, not patched around.

### Rollback for each stage

Rollback runs in reverse dependency order: **B before A, A before 0.**

| Stage | Fast switch-off | Full rollback | Proven by | Limits |
|---|---|---|---|---|
| 0 tools | n/a | Revert the three guard edits in the repo | Capture and pipeline tests | Do not revert while Stage A or B is installed: `studio_capture.load` rejects a capture from a place not in `PLACE_IDS`, so the Stage A ROLLBACK bundle could no longer be built from `exotic-before`. The place lock on installers is separate: `feature_installer.py` asserts `game.PlaceId == bundle.place_id`, taken from the capture. |
| 0 sandbox | n/a | Set `StudioVehicleSandboxEveryPlay` back to `false` with the same guarded spec reversed | AUDIT state | With API access off, Play cannot load a profile once it is off. Final state at handoff: **Filled by the integrator after build** |
| A | None needed: Stage A alone changes no Piercer behaviour that a client can reach (section 8) | `feature_installer.py --mode ROLLBACK` built from the same before capture and unchanged after-files. Restores the 13 sources and the single-source `VehicleCatalogData`, removes the chunk modules and the attribute or folder ops. | APPLY, ROLLBACK, APPLY during delivery; capture compare after ROLLBACK shows no delta other than the Stage 0 attribute `StudioVehicleSandboxEveryPlay` (`false` in the before capture, `true` live; section 4); `Revision` back to `469d9bd8...cf0e` | Refuses on any drift: every target must hold exactly its before or its after value. Stage B must be removed first, because Exotic records need the chunked catalogue. While Stage B is installed, Stage A AUDIT stops with drift on the index, which then lists the `EXOTIC_<n>` chunks. That is expected. |
| B | `Flag_VehicleClass_exotic = false`, then restart Play. Stops sales and hides the category. | Installer REMOVE: deletes `Categories.EXOTIC`, `VehiclePreviews.Categories.EXOTIC`, the four VFX folders, every `VehicleCatalogData.EXOTIC_<n>` chunk module and (if Stage B created it) the `Flag_VehicleClass_exotic` attribute; rewrites the index and the `PIERCER_<n>` chunks for Piercer only, through `catalogue_gen.lua`. | Remove, golden parity, projection check, reinstall. After REMOVE: Stage A AUDIT reports state "after" with 0 drift (index and `PIERCER_<n>` byte-identical to the Stage A after-files in `scripts/exotic_category/catalogue/out/`) and `Revision` is `469d9bd8...cf0e`. | Allowed only while no saved profile holds an Exotic. True in this place. After a saved sale anywhere, only the flag may be used. A leftover `EXOTIC_<n>` chunk reads as a stale catalogue in `check_projection.py` and is not removed by the Stage A ROLLBACK. |

Keep the before capture, the specs and the after-files unchanged in the repo for as long as rollback may be needed. Restoring source values does not undo runtime side effects; restart Play after any install or rollback.

## 19. Risks and mitigations

| # | Risk | Mitigation |
|---|---|---|
| 1 | The catalogue split rewrites the only client source for previews, ratings and upgrade data, and it can fail silently | Split with Piercer only first. Before install, load the generated chunks with `loadstring` in Edit and compare the merged table with the live data: 6 cockpits, 116 modules, same `Revision`. Checkers compare every generated source. |
| 2 | Blockout geometry on a Piercer-tuned runtime: driver inside the engine, flames wider than the car, hidden lamps, low roofs, off-centre camera | Per-cockpit seat offsets. Exotic-scaled jet templates. Fixed lamps on Nose and Engine Deck. Pilot one cockpit and its ten modules, drive it, and fix the recipe before generating the rest. |
| 3 | Money and ownership code changed in a place that cannot save | Sandbox on. Golden parity before and after. The crafted refusals in section 14. Persistence recorded as deferred under DATA-01. |
| 4 | A failed cross-category purchase corrupts the session (`CurrentCategory` written before validation) | Stage A validates before mutating. Test: unaffordable Exotic, then `GetInitial`. |
| 5 | Debit before ten grants widens ECON-01 | Every default is pre-checked before the debit. No refund logic. |
| 6 | Free-part loop through generalised defaults | Grant-once guard on new-slot defaults; `FrontBody` and `RearBody` required. The existing Piercer `Engine2` loop is out of scope and recorded. |
| 7 | A client saves an arbitrary `CategoryId` through the first-child fallback | The written category comes from the cockpit template and must match the request |
| 8 | Text matching: a body part named with "engine" becomes an engine; a missing `ModuleType` becomes "Misc" | Explicit `ModuleType`, `ModuleFolder`, `EnginePosition` on every slot and module; the name rules in section 6.2; installer census |
| 9 | A missing `Price` makes an item free or $1,000 | The installer asserts `Price > 0` on cockpits and on Lightweight, Power and body modules, and `Price = PurchasePrice = 0` with `SourceCockpitId` and `CategoryId` set on Standard modules. The Standard extra-copy charge is tested (section 14 charge cases). |
| 10 | The flag hides but does not block | Both buy actions check the flag on the server |
| 11 | Catalogue cached per server | Restart Play after every install. As built, a flag change rebuilds the server catalogue (GC5); restart Play after a flag change as well, unless the mid-session switch is the test. |
| 12 | 150 to 195 parts per car on low-end devices | Recorded as deferred. Final meshes replace primitives later in the same format. |
| 13 | Garage holds 10 vehicles with no sell path, against 12 cockpits | Known limit, recorded. Out of scope. |
| 14 | Garage rating may not equal the on-road rating (possible double count in `VehiclePerformanceServer`, affects Piercer equally) | Compare `PerformanceIndex` on a spawned Piercer with its garage rating in the first Play. Record the result; do not fix here. |
| 15 | Category order: categories sort by display name, so Exotic is listed before Piercer, and `GarageUI` falls back to the first category when `State.CategoryId` matches none | Check which category the dealership and workshop open on with the flag on. Record what is seen. |
| 16 | An owned Exotic with the flag off from server start: the category is absent from the server catalogue, so the workshop may fall back to the first category's slots and modules | From server start it cannot occur in this place, because nothing saves. The nearest case here is the flag switched off during a session with an Exotic owned (section 14 threat row); look at the workshop then and record what is seen. Must be tested in a saving place before any move to v2. Recorded under DATA-01. |
| 17 | `execute_luau` network access may be withdrawn again | One-line localhost probe at the start of each session; fall back to data carried in the code string |
| 18 | Wrong place | Every installer asserts place 133417340424236 and Edit. The Studio instance is rediscovered before every write batch. |

## 20. Verification matrix

Evidence categories are kept apart: **generated**, **installed**, **agent-verified** and **user-confirmed**. API replies are API evidence, not UI evidence. Sandbox results are not persistence evidence. Studio results are not device or multiplayer evidence.

- **Static/install:**
  - Capture tools: `py -3 scripts/test_studio_capture.py` and `py -3 scripts/test_studio_snapshot_pipeline.py` pass.
  - Before capture verified; projection fresh.
  - Every after-source compiles with `loadstring` in Edit. Pure tests pass.
  - Stage A AUDIT returns state "before", 0 changed. `delivery-reviewer` has no open blocker.
  - Stage A APPLY, ROLLBACK, APPLY. Capture compare after ROLLBACK shows no delta other than the Stage 0 attribute `StudioVehicleSandboxEveryPlay` (`false` in the before capture, `true` live; section 4). After capture compared; every source delta outside scope inspected.
  - Merged catalogue deep-equals the old table; `Revision` unchanged with Piercer only.
  - Stage B: generator output identical to installed sources; preview parity; template-path walk; paint-channel census; socket parents; `check_projection.py` passes on the after capture.
  - Stock rating of all six builds within 3 of target and inside the tier band (balance report).
- **Runtime transitions and cleanup** (real UI in Play, start screen passed, sandbox on, rendering checked first):
  - Piercer unchanged: golden lines 01-18 and X01-X06 identical before and after Stage A, and again with Exotic installed and the flag off; Z01 and Z02 differ as section 8 states; eight unchanged slot cards in the Piercer garage.
  - Dealership shows Exotic and six cards; card rating equals the balance report; preview shows all ten parts.
  - Buy: Cash falls by the price; ten included parts; first-purchase onboarding still completes.
  - For each of the ten slots: buy, equip, upgrade one point, paint. Neon on a glow-strip part. Underglow. Family lock message.
  - Spawn: ten parts installed, driver inside the cabin, passenger seat present. Drive, drift (left and right jets), boost, exit, despawn.
  - Free-roam car menu, race entry and tier, owned-garage bay, switching between a Piercer and an Exotic.
  - Module browse and back clears the unbought preview; customise and back clears temporary overrides.
  - Console clean of new errors across the flow.
- **Multi-client/security:**
  - Single client, API evidence: every threat case in section 14 refused with Cash intact; `NetStats` rejection counts recorded.
  - Charge cases in section 14. Buy a second Standard Exotic core module: the catalogue `Price` and the Cash debit both equal 12% of the cockpit price, not 0 and not $1,000.
  - Two-client checks (second client sees the right modules): deferred. One Studio client cannot satisfy this.
- **Save/rejoin/migration:** N/A in this place. API access is off, so nothing can be saved. Deferred under DATA-01 and DATA-02: a vehicle with the new slots survives rejoin, old saves load unchanged, and an owned Exotic stays usable with the flag off, all in an isolated published place before any move to v2.
- **Device/performance/streaming:** Studio desktop only. Physical phone, tablet, controller, low-end memory with 150 to 195 parts per car, and the 15-player case are deferred (PERF-01, PERF-06). Streaming N/A: no world-size change.
- **Rollback:** proven for Stage A and for the content installer (remove, parity, reinstall). After the content REMOVE: no `EXOTIC_<n>` chunk is left, Stage A AUDIT reports state "after" with 0 drift (index and `PIERCER_<n>` byte-identical to the Stage A after-files), `Revision` is `469d9bd8...cf0e`, and `check_projection.py` passes. This proves Stage A can still be rolled back.
- **Evidence record:** `scripts/validation_record.py` with checks `tooling installation startup garage race errors cleanup api persistence device multiplayer`; captures under `roblox/captures/exotic-category/`. Record and file names: **Filled by the integrator after build**.

Avoid finishing a time trial during these tests (PB-01 writes a personal best even in the sandbox), or accept the change on the dev account.

## 21. Readiness scorecard exceptions or deferred risks

| Area | Status | Note |
|---|---|---|
| Ownership | PASS expected | No owner added. Confirmed at handoff. |
| Security | PASS expected for single-client threat cases | A full exploit audit of each handler stays open under NET-01 |
| Data | PASS for IDs and schema; **DEFERRED** for save and rejoin | DATA-01, DATA-02. Must close before any move to v2. |
| Lifecycle | PASS expected | No new connections, loops or clones |
| Performance | **DEFERRED** | Part count on low-end devices (PERF-01, PERF-06) |
| Mobile/input | **DEFERRED** | Studio desktop only |
| Streaming | N/A | No change to streamed content |
| Failure handling | PASS expected | Validate before debit; skip-with-warning for missing templates |
| Observability | PASS expected | Existing counters and one warning per missing ID |
| Documentation | PASS when section 23 is done | |

Final values: **Filled by the integrator after build**. Each `DEFERRED` row is recorded in `docs/06_current_known_issues.md` with the point before which it must close.

Known limits after this work:

- Geometry is blockout primitives.
- No card images.
- Cockpit light swatches do nothing on an Exotic.
- Saving is untested.
- 10-vehicle cap with no sell path.
- Driving feel and looks are Oscar's to judge. Agent evidence is not user confirmation.

## 22. Done when

1. The capture tools accept the backup place and their tests pass.
2. The before capture is verified and the projection is fresh.
3. Golden "before" is stable over two runs.
4. Stage A is installed; APPLY, ROLLBACK, APPLY is proven; golden "after" equals golden "before" on lines 01-18 and X01-X06, and Z01-Z02 differ as section 8 states.
5. The merged catalogue equals the old one and `Revision` is `469d9bd8...cf0e` with Piercer only.
6. `delivery-reviewer` has no open blocker for Stage A or Stage B.
7. The Wedge pilot is bought, customised, spawned and driven, and the recipe is fixed.
8. All six cockpits and 108 modules are installed; the preview mirror and catalogue are regenerated; `check_projection.py` passes on the after capture.
9. With the flag off, golden equals golden "before" on lines 01-18 and X01-X06, and every Exotic buy is refused.
10. With the flag on, every check in section 20 "Runtime transitions and cleanup" passes through the real UI.
11. Every threat case in section 14 is refused with Cash intact, and every charge case debits the stated amount.
12. Content rollback is proven: remove, parity, reinstall. After REMOVE, Stage A AUDIT reports state "after" with 0 drift and `Revision` is `469d9bd8...cf0e`.
13. Every "Filled by the integrator after build" line in this file is filled.
14. The evidence record passes `validation_record.py check`, with deferred checks named.
15. The documents in section 23 are updated.
16. Verified work is committed with explicit paths and pushed to origin main.

Not required for done: Oscar's judgement of driving feel and looks, device tests, two-client tests, saving tests. They are recorded as open.

## 23. Documentation to update

| Document | Update |
|---|---|
| `docs/00_START_HERE.md` | Replace the "Design proposal: vehicle frame classes" block with the installed state: backup place only, not v2; before and after captures with date and roots; evidence level; next action |
| `docs/06_current_known_issues.md` | One row for the Exotic category with every open or deferred check; the out-of-scope observations (retired modules still buyable, legacy-slot re-grant loop, garage versus on-road rating, 10-vehicle cap, category order, owned Exotic with the flag off); TEST-01 if the sandbox state changed |
| `docs/07_patch_history.md` | One dated entry at the top |
| `docs/02_vehicle_folder_system.md` | More than one category, ten slots, the opt-in attributes, the content installer path, the catalogue split |
| `docs/architecture/installer-index.md` | The Stage A bundle, the content installer and their recovery order (B before A) |
| `docs/architecture/claude-code-setup.md` | The network note for `execute_luau`; the backup place id now accepted by the tools |
| `docs/design/vehicle-frame-classes.md` | Status for Exotic (installed in the backup place as primitive content); answers to the open questions |
| `docs/README.md` | Add this contract; move the design proposal out of "not approved" if its status changes |
| `docs/04_customisation_ui.md` | Only if the slot rail or browser contract text there is affected |
| `docs/12_continuous_improvement_workflow.md` | Only after confirmed evidence yields a reusable lesson |
| This file | Fill every integrator line; change the status to installed with the date |
| Evidence | `docs/architecture/<task>-validation.json` and `scripts/exotic_category/verification.json` |

Current task, status and next action belong only in `docs/00_START_HERE.md`.
