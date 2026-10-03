# Exotic vehicle category contract

Status: **Installed in the backup place on 2026-10-03. Agent-verified in Studio.** Approved by Oscar on 2026-10-02 for the backup place only. Not user-confirmed. Nothing is published.

As-delivered record: [section 24](#24-as-delivered-2026-10-03). Evidence: `scripts/exotic_category/verification.json`.

Target: **Space Racers Backup v2, place 133417340424236** (universe 10768874893). Space Racers v2 (71491191583884) is not touched. This is a recorded exception to the project rule that names v2 as the working place. Oscar's request supersedes the "Design - not approved" status of [vehicle-frame-classes](../design/vehicle-frame-classes.md) for Exotic only, in the backup place only.

Sources this contract is built from:

- Build interface (authoritative for names, IDs and semantics): `scripts/exotic_category/INTERFACE.md`.
- Approved plan: "Plan: make Exotic a playable vehicle category (backup place)", Oscar, 2026-10-02.
- Read-only research of the live game: `output/exotic-impl/understand/` (`gaps.md` first).
- Rules: [delivery workflow](../13_efficient_feature_delivery_protocol.md), [readiness standard](../14_new_system_readiness_standard.md), [contract template](../15_new_system_contract_template.md).

Where this contract and `INTERFACE.md` differ, `INTERFACE.md` wins and this file is corrected.

Lines marked **As delivered** were filled by the integrator on 2026-10-03 from the build files and `verification.json`. Where a value was not measured, the line says so. Nothing is guessed.

Line numbers are `script_read` numbers in the before sources.

---

## 1. System/change

A second vehicle category, **Exotic** (`CategoryId = "exotic"`), in the playable game: six cockpits, 108 modules, ten slots (the eight Piercer slots plus `FrontBody` and `RearBody`), with prices, stats and ratings. It uses the Piercer authoring format, the same remote, the same money path and the same saved schema.

The work has four stages run by the integrator with no user-run steps:

| Stage | What | Proof |
|---|---|---|
| 0 | Prepare: contract, capture tools accept the backup place, before capture and projection check, sandbox on, golden "before" | Capture verified, projection fresh, golden hash stable over two runs |
| A | Remove the fixed assumptions in code. Piercer is still the only category. | Golden "after" equals golden "before" on every line that must match (section 8) |
| B | Exotic content through one dedicated installer. Pilot first (Wedge and 18 modules), rolled back, then the full set. | Golden with the flag off equals golden "before" on the same lines; Exotic tests with the flag on |
| C | Restart Play, tests, evidence, documents, commit | Sections 20 and 22 |

Two installers in one task is deliberate. The design requires the fixed-assumption removal to ship alone and be proven before any content.

## 2. Delivery lane and reason

**High-Risk.**

- It changes ownership and money code (`GarageServer` buy and grant paths).
- It adds permanent IDs that are saved in player profiles: one `CategoryId`, six `CockpitId`s, 108 `ModuleId`s, two slot keys and six new upgrade `PathId`s.
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

Integrator decisions, recorded 2026-10-03:

| Topic | Decision |
|---|---|
| Flag off | The category is left out of the server catalogue and both buy actions refuse. `PurchaseDisabled` is a reserved category field and must not be set. Do not turn the flag off once a saved profile owns an Exotic. See section 12. |
| Pilot | One cockpit (`exotic_03`) and 18 modules: the three variants of its four core modules and its six body parts. It was removed with ROLLBACK before the full install. |
| Seats | Accepted as measured in the pilot: `rootPartCentreAboveSeatTop` 1.437, which gives seat Y -0.262. The first guess of Y 0.25 was not used. Looks are Oscar's to judge. |
| Glass | Darkened after the pilot to `#18202a` at transparency 0.3. The blockout glass (`#5f8fb0` at 0.35) read milky white under the garage lights. |
| Cockpit lights | Exotic cockpits carry the two invisible lens light parts cloned from the Piercer root. The cockpit front and rear light colour swatches tint the light they cast. There are no visible cockpit lamp parts. |
| Piercer hardening | Stayed out of scope. Findings are recorded, not fixed. |
| Catalogue regeneration | After any authoring edit the route is the generator `scripts/exotic_category/catalogue/catalogue_gen.lua`, which the Stage B installer calls. The Python checkers accept the split form. |

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
| Catalogue chunk modules | `VehicleCatalogData.PIERCER_1`, `PIERCER_2`, `EXOTIC_1`, `EXOTIC_2` as delivered. The names are generated. The number of chunks can change with content. |
| New upgrade `PathId`s (saved keys) | `NoseCanards`, `SlipstreamNose`, `LightweightNose`, `DeckCooling`, `TailStrakes`, `LightweightDeck` (section 6.5) |

### 6.5 Values decided by builders

All values in this section are **as delivered**. Sources: `scripts/exotic_category/balance/report.md` (generated), `scripts/exotic_category/stage_b/out/summary-full.json` (generated) and `scripts/exotic_category/verification.json` (installed and agent-verified).

**New upgrade `PathId`s.** Six, checked against `balance/report.md` section 10. They are saved keys in `V2UpgradePoints`. None is a live `PathId`, a legacy upgrade id or a category `UPGRADE_*` id. Each path folder is named by its `PathId`, because the live `NextPointCost` finds a path by folder name. The same three paths sit on all six parts of a slot.

| Slot | PathId | DisplayName | Order | MaxPoints | Per point |
|---|---|---|---|---|---|
| `FrontBody` | `NoseCanards` | Nose Canards | 1 | 3 | `SteeringResponse` +2, `Downforce` +1, `TopSpeed` -1 |
| `FrontBody` | `SlipstreamNose` | Slipstream Nose | 2 | 3 | `TopSpeed` +2, `Downforce` -1 |
| `FrontBody` | `LightweightNose` | Lightweight Nose | 3 | 3 | `Weight` -3, `SteeringResponse` +1 |
| `RearBody` | `DeckCooling` | Deck Cooling | 1 | 3 | `EngineOutput` +1, `BoostEfficiency` +2, `Weight` +1 |
| `RearBody` | `TailStrakes` | Tail Strakes | 2 | 3 | `HoverStability` +2, `DriftControl` +1, `TopSpeed` -1 |
| `RearBody` | `LightweightDeck` | Lightweight Deck | 3 | 3 | `Weight` -3, `DriftGrip` +1 |

**Upgrade path donors.**

| Modules | Paths come from |
|---|---|
| Core modules of `exotic_01` | The live Piercer module of the same type and variant in family `bruiser_02` |
| Core modules of `exotic_02` | Family `bruiser_03` |
| Core modules of `exotic_03` | Family `bruiser_01` |
| Core modules of `exotic_04`, `exotic_05`, `exotic_06` | Families `bruiser_04`, `bruiser_05`, `bruiser_06` |
| Side Pods, Splitter, Diffuser, Wing | `MODULE_SIDEPODS_LVL1`, `MODULE_FRONTBUMPER_LVL1`, `MODULE_REARBUMPER_LVL1`, `MODULE_REARSPOILER_LVL1` |
| Nose, Engine Deck | The six explicit paths above |

The cloned accessory paths carry `Drag`, as on Piercer. That lowers the rating on S tier until the low-drag path is bought (`balance/report.md` section 12; EXO-04 in `docs/06_current_known_issues.md`).

**Prices and stock ratings.** The dealership in Play showed the same price and rating as the balance report for all six.

| Cockpit | Name | Tier | Price | Over Piercer | Stock rating | Lightweight or Power module |
|---|---|---|---:|---:|---|---:|
| `exotic_01` | Spider | E | 50,000 | +25.0% | E 220 | 6,000 |
| `exotic_02` | Curve | D | 150,000 | +25.0% | D 390 | 18,000 |
| `exotic_03` | Wedge | C | 440,000 | +25.7% | C 540 | 52,800 |
| `exotic_04` | Longtail | B | 1,400,000 | +27.3% | B 675 | 168,000 |
| `exotic_05` | Hyper | A | 4,400,000 | +25.7% | A 800 | 528,000 |
| `exotic_06` | Gull | S | 12,500,000 | +25.0% | S 938 | 1,500,000 |

Every stock rating equals its target. Stat values are not repeated here: stock totals are in `balance/report.md` section 3, the component split in section 5, body modules in section 6, variant sets and upgrade ceilings in section 7, and every attribute in `balance/balance.json`.

**Seat offsets.** Seat centre in root local space, from `stage_b/out/summary-full.json`.

| Cockpit | Driver X, Y, Z | Passenger X, Y, Z |
|---|---|---|
| `exotic_01` | -2.0, -0.262, 0.45 | 2.0, -0.262, 0.45 |
| `exotic_02` | -1.5, -0.262, 0.45 | 1.5, -0.262, 0.45 |
| `exotic_03` to `exotic_06` | -1.8, -0.262, 0.45 | 1.8, -0.262, 0.45 |

The rule is in `stage_b/data/seats.json`. The seat height comes from the blockout driver dummy and one measured number: `rootPartCentreAboveSeatTop` 1.437 (2026-10-03, pilot `exotic_03`, R15 avatar, server read while seated). On the Wedge the occupant top is at Y 3.58 against the lowest closed roof underside at 3.83. The pilot record in `seats.json` notes that the feet end below the tub underside, hidden by the body.

**VFX sockets.**

| Where | Sockets |
|---|---|
| Each cockpit root | 5 (the hover dust attachments in `stage_b/data/cockpit_fixtures.json`) |
| Main Turbine module | 1 or 2, by shape |
| Side Engines module | 2 |
| Stabilisers module | 4 |
| Afterburner module | 1 or 2, by shape |
| Body modules | 0 |
| All 108 modules | 162 |
| Installed category | 192, all under parts |
| Stock vehicle | Spider 14, Curve 15, Wedge 13, Longtail 13, Hyper 14, Gull 15 (Piercer 12) |

Socket names per shape are in `stage_b/out/summary-full.json`.

**Catalogue.** Two Exotic chunks, `EXOTIC_1` and `EXOTIC_2`. The installed catalogue is the index plus `PIERCER_1`, `PIERCER_2`, `EXOTIC_1` and `EXOTIC_2`: 12 cockpits and 224 modules. `Revision` is `37f47fadff3d352d2bcc97399369f46044dd022e1d2e1661bcb28d642f5b986f`.

**Part count.** The category holds 1,746 template parts. A spawned stock Exotic has 172 to 204 parts (all six measured in Play). A figure per cockpit is not recorded.

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
| 0.2 | Capture tools accept place 133417340424236, for scoped captures only. The full mirror is never taken from this place. | `scripts/studio_export_snapshot.lua` (23, 31), `scripts/studio_capture.py` (11), `scripts/import_studio_snapshot.py` (127) |
| 0.3 | Before capture; projection check | `roblox/captures/exotic-before/` |
| 0.4 | No-save sandbox on (after the capture, so the capture holds `false`) | Attribute `StudioVehicleSandboxEveryPlay = true` on `ReplicatedStorage.Config.Player.Onboarding`; spec `scripts/exotic_category/stage_0/spec-sandbox-on.json` (`sandbox_audit.lua`, `sandbox_apply.lua`) |
| 0.5 | Golden "before", run twice | Runner `scripts/exotic_category/golden.lua` (section 8); before output `scripts/exotic_category/golden-before.txt`. **As delivered:** recorded twice in fresh sandbox sessions; the two runs were identical. The `delivery-reviewer` found that the recorder hashed `os.time()` stamps. Keys ending `AtUnix` are now tokenised, and the baseline was re-recorded twice before APPLY. |

The rows are in the order they were done.

The sandbox is not optional here. With API access off and the sandbox off, `ProfileServer` kicks the player because the profile cannot load.

### 7.2 Stage A: every changed owner and the exact change

One reversible bundle through `scripts/feature_installer.py` (source, new-module, folder and attribute operations; AUDIT, APPLY, ROLLBACK). Every new behaviour is opt-in through data that Piercer does not have.

**As delivered:** the spec is `scripts/exotic_category/stage_a/spec.json`, with 19 operations.

| Operations | Count | Targets |
|---|---:|---|
| New chunk modules | 2 | `VehicleCatalogData.PIERCER_1`, `PIERCER_2` |
| Catalogue index (existing source) | 1 | `VehicleCatalogData` |
| Server sources (existing) | 7 | `GarageServer`, `GarageCatalogLookup`, `GarageCatalogService`, `GarageClientProfile`, `OwnedGarageDisplay`, `VehicleBuildService`, `DriverSeatServer` |
| `ModuleArtwork` folders (new) | 2 | `FrontBody`, `RearBody` |
| Client sources (existing) | 7 | `GarageWorkspaceUI`, `GarageUI`, `GarageBrowserUI`, `GarageModuleCardViewModel`, `GarageVehiclePreviewProfile`, `VehiclePerformanceResolver`, `PreviewCameraClient` |

That is 14 existing sources, the catalogue index, two new chunk modules and two new folders: 19 operations.

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
| `ServerStorage.Modules.Game.Vehicles.DriverSeatServer` | 34-41, 131 | Use cockpit attributes `DriverSeatOffsetX/Y/Z` when present. The fallback is per axis: an axis without a numeric attribute uses the global `Config.Vehicles.DriverSeat` value as today. | None |
| `ServerStorage.Modules.Game.Garage.VehicleBuildService` `addPassengerSeat` | 199-236 | Use cockpit attributes `PassengerSeatOffsetX/Y/Z` when present. The fallback is per axis: an axis without one uses the global `Config.Activities.Passengers` value as today. The same clamp applies. | None |

**Client**

| Owner | Before lines | Exact change | Piercer effect |
|---|---|---|---|
| `ReplicatedStorage.Modules.Game.UI.GarageWorkspaceUI` `artworkDefinitions` | 11-23 | Two new rows: `FrontBody` (label "Front Body", `SortOrder=72`) and `RearBody` (label "Rear Body", `SortOrder=74`), `ShowInBuild=true`, `ShowInCustomise=true`, images reused from existing artwork entries. A row appears only when the current category has that slot. | Eight cards as today |
| `ReplicatedStorage.Modules.Game.Garage.GarageUI` | about 332, 385, 541 | Where a slot label is shown, use the slot's `RailLabel` when present, else today's label | None |
| `GarageUI` and `ReplicatedStorage.Modules.Game.UI.GarageBrowserUI` | 57-59, 186; 115 | Reserved plumbing for a category field `PurchaseDisabled` (hunks U7-U10 and B1). No server code sends the field, so these hunks are inert. See section 12. | None. The same category tables reach the browser in the same order. |
| `ReplicatedStorage.Modules.Game.UI.GarageModuleCardViewModel` (and `GarageUI` where the card is built) | 6-13 | Card title is `CardTitle` when present, else today's title. Variant tag logic is unchanged for modules without `CardTitle`. Exotic body modules must not read "Level n". | None |
| `ReplicatedStorage.Modules.Game.Garage.GarageVehiclePreviewProfile` | 28-36 | Any cockpit key `Default<X>ModuleId` beyond the legacy ones is an optional default for slot `X` | None |
| `ReplicatedStorage.Modules.Game.Vehicles.Performance.VehiclePerformanceResolver` | 10-15, 69, 99 | Same optional defaults. Line 99: use the module's `RatingReferenceCockpitId` when present, else `bruiser_01` as today. | Ratings unchanged |
| `ReplicatedStorage.Modules.Game.Garage.PreviewCameraClient` | 10 | `FrontBody="Front"`, `RearBody="Rear45"` added to the view map | None |

**As built.** The hunk-by-hunk record, with the reason each hunk leaves Piercer unchanged, is `scripts/exotic_category/stage_a/server/CHANGES.md` and `scripts/exotic_category/stage_a/client/CHANGES.md`. Those two files win over this summary. The builders delivered these items beyond `INTERFACE.md`. Each is opt-in or cannot be reached with Piercer data. All were installed: the bundle writes the after-sources those files describe, and the `delivery-reviewer` found no blocker in any after-source before APPLY.

| Owner | Hunk | Addition |
|---|---|---|
| `GarageCatalogLookup` `moduleLockedMessage` (131) | GL3 | The lock message looks the source cockpit up in the module's own category, so it shows the display name and not the raw id |
| `GarageCatalogService` snapshot (225, 232) | GC5, GC5b | The cached catalogue is rebuilt under a new revision when the on/off state of a flagged category changes. With no flagged category it is built once, as today. |
| `GarageServer` (56, 854) | GS1, GS11 | Requires `Core.FeatureFlags`; passes one gate function, `categoryFlagEnabled`, to `GarageCatalogService` so the catalogue and both buy actions cannot disagree |
| `GarageCatalogService` (6) | GC1 | If `GarageServer` does not pass `categoryFlagEnabled`, the service warns once and hides every flagged category. Piercer stays listed. The two sources must be installed together. |
| `GarageServer` `buyCockpitInstance` | GS7 | The reply to a mismatched `CategoryId` is `"Cockpit not found."`. A cockpit with no `CategoryId` attribute takes the id of the category folder that holds it. |
| `GarageServer` default grants (507) | GS6b | On a cockpit with new-slot defaults, the session `NeonOwned` mirror entry of a granted slot is set to false. This closes free neon on the granted Exotic defaults. No new field. |
| `GarageUI` (347, 353), `GarageModuleCardViewModel` (29, 47) | U5, U6, V1-V3 | Card rows carry two display-only fields, `Title` and `Tag`. The seven client sources are installed together. |
| `GarageModuleCardViewModel` (8) | V4 | The name of a module with a `CardTitle` is never searched for a variant. Its sort key is its explicit `VariantName` when that is one of the three, else Standard. |
| `GarageUI` (57-59, 186), `GarageBrowserUI` (115) | U7-U10, B1 | Reserved `PurchaseDisabled` plumbing. Inert: no server code sends the field (section 12). |

Findings the builders reported and did not fix are in `stage_a/server/CHANGES.md` under "Findings not fixed". The open ones are recorded in `docs/06_current_known_issues.md` (GAR-01, EXO-02).

**Catalogue**

| Owner | Exact change |
|---|---|
| `ReplicatedStorage.Modules.Game.Vehicles.VehicleCatalogData` | Keeps its path. Becomes a generated index: `Revision`, `SchemaVersion=1`, and for each name in a generated list `require(script:WaitForChild(name))`, copying records into `Cockpits` and `Modules` with a duplicate-id assert, then the existing freeze logic. |
| New children `VehicleCatalogData.PIERCER_1`, `PIERCER_2` | Each returns `{["Cockpits"]={...},["Modules"]={...}}` with today's record text. Packing: group by category folder (`TemplatePath[1]`); cockpits then modules, sorted by id; greedy fill to 150,000 characters; assert every source is under 190,000. |
| `Revision` | The same algorithm over the merged data. With Piercer only it must equal `469d9bd81944a3d71a127ea1d5e702720b75f55524391cb27008e05e8fc2cf0e`. |
| `ReplicatedStorage.Modules.Game.Vehicles.VehicleCatalog` and every reader | **Unchanged** |
| `scripts/performance_phase3/catalogue.py` | `project(h)` unchanged. `PUBLIC` gains the six new `Default<Slot>ModuleId` names and `RatingReferenceCockpitId` (other new names only if a reader needs them from the client data). New `chunk_sources(data)`. |
| `scripts/performance_phase3/check_catalogue.py`, `scripts/performance_phase4/check_projection.py` | Compare every generated source with the manifest rows at and under `VehicleCatalogData` |
| `scripts/exotic_category/catalogue/catalogue_gen.lua` | Read-only Luau generator. Returns `function() -> { index, chunks = { {name, source}, ... }, revision, cockpits, modules }` from `ServerStorage.Assets.Vehicles.Categories`. It never writes. It rejects non-ASCII text and numbers that print as `e`, `inf`, `nan` or `-0`. As delivered: the Stage B installer calls it and writes the sources. Stage A wrote the Python-generated files in `scripts/exotic_category/catalogue/out/` (named in `spec.json`); the Stage B AUDIT then found the installed sources equal to the generator output. |

**Config**

| Owner | Exact change |
|---|---|
| `ServerStorage.Config` | Attribute `Flag_VehicleClass_exotic` (boolean Studio override). Absent reads as off. **As delivered:** neither Stage A nor Stage B creates it. It has its own Standard-lane spec, `scripts/exotic_category/flag/spec-flag-on.json` (`flag_audit.lua`, `flag_apply.lua`, `flag_rollback.lua`), which sets it to `true`. ROLLBACK removes the attribute. Value in the backup place since 2026-10-03: `true`. |
| `ReplicatedStorage.Config.UI.GarageReplacement.ModuleArtwork` | Two config folders, `FrontBody` and `RearBody`, with the same six attributes as the eleven live entries. No upload. They only supply the card image. **As delivered:** installed with the Stage A bundle, as two folder operations in `spec.json` taken from `scripts/exotic_category/stage_a/client/config_ops.json`. Values below. |

`ModuleArtwork` folders as delivered. Both also carry `ShowInBuild=true` and `ShowInCustomise=true`.

| Folder | `DisplayName` | `TargetId` | `SortOrder` | `Image` (reused) |
|---|---|---|---:|---|
| `FrontBody` | Front Body | FrontBody | 72 | `rbxassetid://76594522686468`, the live `FrontBumper` image |
| `RearBody` | Rear Body | RearBody | 74 | `rbxassetid://136042248946525`, the live `RearBumper` image |

Opt-in data attributes read by Stage A code (absent means today's behaviour):

| Where | Attribute | Type | Meaning |
|---|---|---|---|
| Category folder | `FeatureFlag` | string | Flag key. See section 12. |
| Slot folder | `RailLabel` | string | Player-facing slot label in this category |
| Module model | `CardTitle` | string | Title on the module's shop and inventory card. Set on all Exotic modules to the module `DisplayName`. |
| Module model | `RatingReferenceCockpitId` | string | Reference chassis for the module rating. Exotic modules use `exotic_03`. |
| Cockpit model | `Default<SlotId>ModuleId` | string | Default module for a slot other than the four legacy ones: `DefaultFrontBodyModuleId`, `DefaultRearBodyModuleId`, `DefaultSidePodsModuleId`, `DefaultFrontBumperModuleId`, `DefaultRearBumperModuleId`, `DefaultRearSpoilerModuleId` |
| Cockpit model | `DriverSeatOffsetX/Y/Z` | number | Driver seat offset in root local space. The fallback is per axis: a missing `DriverSeatOffsetY` uses the global Y. |
| Cockpit model | `PassengerSeatOffsetX/Y/Z` | number | Passenger seat offset in root local space. The fallback is per axis. |

Exotic cockpits always set all six seat offsets.

The four legacy slots keep their seven legacy attribute names exactly as the code reads them today (`DefaultEngineModuleId`, `DefaultFrontEngineModuleId`, `DefaultRearEngineModuleId`, `DefaultEngineBModuleId`, `DefaultStabilisersModuleId`, `DefaultStabiliserModuleId`, `DefaultBoostModuleId`). Exotic cockpits set all seven.

Stage A order: build, compile every file with `loadstring` in Edit, pure tests, AUDIT (expect state "before", 0 changed), `delivery-reviewer`, APPLY, ROLLBACK, capture compare, APPLY, recapture, golden "after" against golden "before" (section 8).

The capture compare after ROLLBACK must show no delta other than the Stage 0 attribute `StudioVehicleSandboxEveryPlay` (`false` in the before capture, `true` live; section 4). `ReplicatedStorage.Config` is a capture root, so that one attribute always shows.

**As delivered:** AUDIT before, APPLY 19, AUDIT after, ROLLBACK 19, AUDIT before, APPLY 19, repeat APPLY 0. The state after the ROLLBACK was proved by AUDIT returning "before": the installer accepts a target only when it holds exactly its before or its after value. `verification.json` records no capture between the ROLLBACK and the second APPLY. The after capture is `roblox/captures/exotic-stage-a/capture.json` (2026-10-03 09:55:39 UTC, 215 sources).

### 7.3 Stage B: content (one dedicated installer under `scripts/exotic_category/`)

| # | Item | Where |
|---|---|---|
| B1 | Four Exotic-scaled jet template folders, cloned and scaled from the stock ones | `ReplicatedStorage.Assets.VFX.VehicleTemplates` |
| B2 | 108 module templates in ten folders: `ModuleRoot_DoNotRename`, `MountAttachment`, paint-channel folders, sockets, upgrade paths, attributes | `ServerStorage.Assets.Vehicles.Categories.EXOTIC.MODULES_InterchangeableWithinCategory` |
| B3 | 6 cockpit templates: root, ten slot folders, sockets, underglow mount, default colours, ten defaults, seat offsets, stats, price, `V2Materialised=true` | `...EXOTIC.COCKPITS_ReplaceAssetsHere` (first child of `EXOTIC`; `EXOTIC` added after `PIERCER`) |
| B4 | Category folder attributes `CategoryId="exotic"`, `DisplayName="Exotic"`, `FeatureFlag="VehicleClass_exotic"`, plus `Description` and `ModuleCompatibility` as `PIERCER` has them | `...Categories.EXOTIC` |
| B5 | Preview mirror: a clone of the category with every `VehiclePerformanceV2UpgradePaths` and `UpgradePaths` folder removed | `ReplicatedStorage.Assets.VehiclePreviews.Categories.EXOTIC` |
| B6 | Regenerated catalogue index and the `EXOTIC_<n>` chunks, new `Revision`. The `PIERCER_<n>` chunks are asserted equal to the generator output and are not rewritten. | `VehicleCatalogData` and children, through `catalogue_gen.lua` |
| B7 | Read-only checks: generator output identical, preview parity, template-path walk, paint-channel census, socket parents | Integrator |

Template format rules (same as Piercer):

- Root space: +X right, +Y up, forward -Z. `CockpitRoot_DoNotRename` is a copy of the Piercer root (7.5 x 1.2 x 10.5) at the spec origin. All ten mounts at the origin.
- Paint: channel folders plus a `PaintChannel` attribute on each part. Spec channel `thrust` becomes `ThrustColor` under `THRUST_COLOR_WhiteByDefault`. Spec channel `driver` parts are dropped.
- Neon parts on `FrontBody` and `RearBody` go in `LIGHTS_AlwaysOn` with `PaintChannel="Lights"`, Material Neon, part names without `neon`. Neon parts on other modules go in `NEON_OptionalLights`.
- VFX sockets are Attachments on the module or cockpit root part, flame along local +Z, `VFXSocket=true`, `VFXTemplate` naming an Exotic template.
- Core modules mirror the live Piercer family attribute set (donor `MODULE_<TYPE>_BRUISER_03_<VARIANT>`) with `SourceCockpitId="exotic_0N"` and `CategoryId="exotic"`.
- Body modules mirror the live accessory attribute set (donor `MODULE_<TYPE>_LVL1`; `FrontBody` uses the `FrontBumper` donor, `RearBody` the `RearBumper` donor): `Price` only, no `PurchasePrice`, no `SourceCockpitId`.
- Engine1 modules: `EnginePosition="Front"`, `RearEngine=false`. Engine2 modules: `EnginePosition="Rear"`, `RearEngine=true`. Both `ModuleSlot="Engine"`.

As delivered (`scripts/exotic_category/stage_b/README.md` and `data/*.json`):

- `CockpitRoot_DoNotRename` is a clone of the live `bruiser_03` root. Its two invisible lens light parts come with it and are moved inside the nose and the tail wall. There are no visible cockpit lamp parts.
- A cockpit carries 77 attributes: the 59 non-colour Piercer attributes, six default colours, the six new `Default<Slot>ModuleId` names and six seat offsets. `OwnedByDefault` is `false` on every Exotic cockpit.
- Glass is `#18202a` at transparency 0.3. It was darkened after the pilot.
- Lamp parts in `LIGHTS_AlwaysOn` have names that end `_lamp`. Their colour is the native neon paint of the cockpit that owns the kit.
- The four jet templates are scaled by `data/vfx.json`. The stabiliser templates keep the centre jet only.
- Created roots carry `InstalledBy = "exotic_category/stage_b"`, `InstalledScope`, `InstalledContentHash` and a signature of their descendants. The marker, not the name, makes something the installer's own.

Pilot first. **As delivered:** the pilot scope was one cockpit, `exotic_03` (Wedge), and 18 modules: the three variants of its four core modules and its six body parts. With the flag off, golden parity again. Then flag on: buy, customise, spawn and drive it. The pilot changed two things in the recipe before the rest was built: the seat rule took the measured value (section 6.5) and the glass was darkened.

The pilot is a complete install of a declared content set. It is not a partial install. It was removed with ROLLBACK before the full set was installed. That is allowed here because nothing is saved. The installer never extends a prior install in place: APPLY with a larger scope or a new build replaces the installer's own earlier content.

The content installer must: assert place 133417340424236 and Edit mode; preflight unique paths; refuse a partial prior install (anything that is not exactly one declared content set, complete); create authoring, preview and catalogue together; on removal, delete exactly what it created and fail loudly if a created root was edited. It never writes to `Workspace.VehicleCategoryBlockouts`, `ServerStorage.Archive` or `ServerStorage.NeoTokyoRacers`.

**As delivered:** its modes are AUDIT, APPLY and ROLLBACK, and its scopes are `pilot` and `full`. It refuses to APPLY until Stage A is installed: `VehicleCatalogData` in the split form and equal to the generator output, and the four Stage A server probes present. The `delivery-reviewer` found no blocker before APPLY. Three installer safety fixes were applied first: the content hash covers the engine and the generator; the marker is set before parenting; rollback rewrites the index before detaching chunks.

### 7.4 Builder folders

Builders write repo files only, one folder each, and never touch Studio state or Git. The integrator owns Studio, captures, compiles, installs, review, Play tests and Git.

| Area | Folder |
|---|---|
| Contract | `docs/architecture/exotic-category-contract.md` (this file) |
| Catalogue split | `scripts/exotic_category/catalogue/` and the two `scripts/performance_phase*` tools named above |
| Balance | `scripts/exotic_category/balance/` |
| Server sources | `scripts/exotic_category/stage_a/server/` (`after/`, `ops.json`, `CHANGES.md`) |
| Client sources | `scripts/exotic_category/stage_a/client/` (`after/`, `ops.json`, `config_ops.json`, `CHANGES.md`) |
| Content installer | `scripts/exotic_category/stage_b/`. **As delivered:** `build_content.py` builds `out/installer.lua` for one mode and one scope from `installer_engine.lua`, `data/*.json`, `balance/balance.json` and `catalogue/catalogue_gen.lua`. Checks: `test_content.py`, `post_install_checks.lua`, `measure_seat.lua`. Guide: `README.md`. |

Integrator files, as delivered:

| Purpose | Files |
|---|---|
| Stage 0 sandbox | `scripts/exotic_category/stage_0/spec-sandbox-on.json`, `sandbox_audit.lua`, `sandbox_apply.lua` |
| Stage A bundle | `scripts/exotic_category/stage_a/spec.json`; built bundles `stage_a/out/install_audit.lua`, `install_apply.lua`, `install_rollback.lua` |
| Flag | `scripts/exotic_category/flag/spec-flag-on.json`, `flag_audit.lua`, `flag_apply.lua`, `flag_rollback.lua` |
| Golden recorder | `scripts/exotic_category/golden.lua`, `golden-before.txt`, `golden-after-stage-a.txt` |
| Evidence | `scripts/exotic_category/verification.json` |

## 8. Must preserve

- **Piercer parity.** For every `GarageInvoke` request the client can send on a Piercer: same success flag, same message text, same reply content, same order of checks. `CategoryId "bruiser"` and the folder name `PIERCER` stay as they are. `PIERCER` stays the first child of `Categories`.
- **One deliberate exception.** `BuyCockpitInstance` with a `CategoryId` that is not exactly the cockpit template's `CategoryId` attribute is refused after Stage A. That covers an unknown category (`"zzz"`) and the folder name (`"PIERCER"` or `"piercer"`). Before Stage A such a request succeeded through the lookup fallback (`GarageCatalogLookup` 15-24: folder-name match, then first child) and the client string was saved as the vehicle's `CategoryId` (`GarageServer` 378, 517). No client sends this: the UI sends the catalogue `CategoryId`, which is `"bruiser"`. A request with no `CategoryId` is unchanged.
- **Golden sequence.** Runner: `scripts/exotic_category/golden.lua`, pasted into `execute_luau` on the client in a fresh sandbox Play. It is the 18 steps of `scripts/architecture/p5/golden.lua` plus eight crafted calls, 26 lines in all. Each reply is canonicalised (generated ids normalised before the keys are sorted, the catalogue revision normalised, keys ending `AtUnix` tokenised, numbers `%.6g`) and reported as one line: label, length, FNV-1a hash, success and message. Before output: `scripts/exotic_category/golden-before.txt`. Result after Stage A: `scripts/exotic_category/golden-after-stage-a.txt`.
  - Steps 01-18: GetInitial, BuyCockpit, BuyModule, BuyCosmetic, CosmeticColour, BuyNeon, Upgrade, CockpitColour, Unaffordable, BadField, UnknownCockpit, GetInitial, Select, Spawn, Exit, ReEnter, Despawn, GetInitialKnownRev.
  - X01-X06 (must stay identical): UnknownModule, WrongSlotType, UnknownSlot, BuyNoCategory, GarageFull, GetInitial.
  - Z01-Z02 (expected to differ after Stage A): UnknownCategory (`CategoryId="zzz"`), GetInitialAfter.

  Lines 01-18 and X01-X06 must be identical:
  1. between two "before" runs (stability);
  2. before and after Stage A;
  3. before, and with Exotic installed and the flag off.

  Z01 and Z02 are the exception above. Before: Z01 passes the category step, is refused later with `"Garage full. ..."`, and leaves `CurrentCategory = "zzz"` on the session profile, which Z02 shows. After Stage A: Z01 is refused with `"Cockpit not found."` and writes nothing, so Z02 is expected to equal X06 (same length and hash). If it does not, find the differing field before accepting. Z01 and Z02 must then be identical between the Stage A run and the run with Exotic installed and the flag off.

  **As delivered:** all three comparisons hold. After Stage A, 24 of 24 must-match lines are identical in length and hash; Z01 returns `"Cockpit not found."` and Z02 equals X06. With the pilot installed and the flag off, all 26 lines equal the Stage A result. The flag-off run was made with the pilot scope. It was not repeated with the full scope installed.
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
- Card images. No upload. `MenuImage` is empty, so dealership cards show the text placeholder (the HOVERCAR text); the free-roam menu and race entry show a blank picture.
- Final meshes. Geometry is the blockout primitives in the final template format.
- Hardening of existing Piercer rules: blocking retired or hidden modules, the legacy-slot re-grant loop, any other tightening. Findings are recorded in `docs/06_current_known_issues.md`, not fixed.
- Saving tests. Nothing can save in this place. Persistence stays open under DATA-01 and DATA-02.
- New remotes, actions, argument fields, saved profile fields or owners.
- Refund or compensation logic. No Cash grant of any kind.
- A sell path, or a change to the 10-vehicle garage cap.
- New driving mechanics, per-class physics tuning, liveries, audio profiles.
- Job and race pay review.
- Visible cockpit lamps. Exotic cockpits have no visible lamp parts of their own. As delivered they do carry the two invisible lens light parts cloned from the Piercer root, so the cockpit front and rear light colour swatches tint the light they cast.
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
| Value in the backup place | `true` since 2026-10-03, set by `scripts/exotic_category/flag` |
| Live value | Creator Dashboard config, 60-second refresh (not used in this place) |
| Flag off: catalogue | The category is left out of the server catalogue, so the dealership does not show it |
| Flag off: buy cockpit | `BuyCockpitInstance` for an Exotic cockpit, sent with `CategoryId="exotic"` as the UI sends it, returns `false, "Vehicle unavailable."` |
| Flag off: buy module | `BuyModuleInstance` for an Exotic module onto an owned Exotic returns `false, "Module unavailable."`. The module is looked up in the target vehicle's category first, so the same module onto a Piercer returns today's `"Module not found."` in any flag state. In this place an Exotic can be owned with the flag off only when the flag is switched off during the session. |
| Flag off: owned vehicles | Server actions on an owned Exotic are not gated: select, spawn, drive, equip owned parts, paint and upgrade. The garage UI is not covered: see "Flag off with an owned Exotic" below. |
| Templates | The flag never removes or hides templates |
| A folder with no `FeatureFlag` | Today's behaviour. `PIERCER` has none. |
| Missing gate | `GarageCatalogService` warns once and hides flagged categories if `GarageServer` does not pass `categoryFlagEnabled`. The two sources are installed together; the installer refuses a mixed state. |

**Flag off with an owned Exotic (decision, 2026-10-03).** Flag off leaves the category out of the server catalogue. The client has no other source for that category's slots, modules and cockpit names. So for a player who owns an Exotic the garage UI for that category would be missing. Read from the sources, not tested in Play: the owned Exotic is not listed in the Customisation browser; if it is the current vehicle the pages show the first category's slots and modules; race entry lists it by cockpit id under `OTHER`. Nothing is lost or saved wrongly, and turning the flag on again restores everything.

- **Do not turn the flag off once any saved profile owns an Exotic.** In this place nothing saves, so no saved profile can own one.
- `PurchaseDisabled` is a **reserved** category field. The client hunks that read it (`GarageUI` U7-U10, `GarageBrowserUI` B1) are inert plumbing. No server code sends it.
- **Never set a `PurchaseDisabled` attribute on a category folder.** Folder attributes are copied to the client, so it would hide the category on the client with no server enforcement.
- Keeping a flagged-off category in the payload, marked not on sale, was proposed and not built. It needs a contract decision and a test in a saving place before any move to v2 (EXO-02 in `docs/06_current_known_issues.md`).

Today the server catalogue is built once per server and frozen. As built (section 7.2, hunks GC5 and GC5b), Stage A rebuilds it under a new revision when the on/off state of a flagged category changes. The two buy checks read the flag when the request arrives. In Studio the override attribute is read on every call, so a change on the running server takes effect at once.

Restart Play after a flag change all the same, unless the test is the mid-session switch itself. **As delivered:** whether an open dealership refreshes its list without a restart was not tested. `verification.json` has no record of it.

The flag gates **buying only**, and the dealership entry. It is not a rollback of content and it does not undo a sale.

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

Rows marked "as built" take their text from `scripts/exotic_category/stage_a/server/CHANGES.md` (hunks GS7 and GS9).

**As delivered** (`verification.json`, `exotic_play_tests`; API evidence in Play, single client). Refused with Cash intact:

- Exotic buys with the flag off;
- nose into Engine Deck;
- a Side Engines part into Main Turbine, and the reverse;
- a Piercer part on an Exotic;
- an Exotic cockpit under the Piercer category;
- a locked family, with the text `"Buy Gull before buying this module family."`;
- neon on a part without optional neon;
- a third vehicle with a full garage.

No re-grant: a default nose was moved to a second Wedge and both vehicles were reselected; nose instances stayed at three.

The record quotes the reply text for the lock message only. It does not list these rows of the table: an unaffordable Exotic followed by `GetInitial`; an Exotic module onto a Piercer; an extra request field on an Exotic request; a module buy after the flag is switched off during a session. The Piercer golden steps 09, 10, 11, X01, X02, X03 and X05 return the same messages as before on Piercer data.

**Charge cases** (each must debit exactly the stated amount through `MoneyService.Debit`):

| Request | Expected |
|---|---|
| Buy a second Standard Exotic core module for a cockpit that is owned | The catalogue `Price` of the module and the Cash debit both equal 12% of the cockpit price. Not 0 and not $1,000. For `exotic_03`: 52,800. |
| Buy a Lightweight or Power module | Debit equals the module's `Price` attribute |
| Buy a body module | Debit equals the module's `Price` attribute |

**As delivered** (`verification.json`, `module_economy`):

| Charge | Amount |
|---|---:|
| Lightweight and Power module on Wedge | 52,800 |
| Extra Standard copy on Wedge | 52,800 |
| Body parts, by kit | 14,000 / 23,000 / 30,000 |
| Upgrade points | 3,025 and 3,575 |
| Neon on a part with optional neon | 7,000 |
| Underglow and thrust colour | 5,000 |

The Wedge itself was bought through the UI: Cash went from 1,000,000 to 560,000.

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

**The flag gates buying only.** Switching the flag off stops new sales and hides the dealership entry. It also leaves the category out of the server catalogue. The client has no other source for that category, so the garage UI for an owned Exotic is missing. Do not turn it off once a saved profile owns an Exotic (section 12). It does not make an owned Exotic safe to remove.

**In this place** nothing can be saved (API access off, sandbox on), so no profile will hold an Exotic and content rollback is safe here. That is a property of this place, not of the design.

**API version.** `VehicleCatalogData` keeps `SchemaVersion=1` and its public shape (`Cockpits`, `Modules`, `Revision`). The index-plus-chunks layout is internal to the generated module. `GarageInvoke` payloads gain two optional reply fields (`RailLabel` on a slot, `CardTitle` on a module) that are absent for Piercer.

## 16. Expected scale, devices, streaming and failure

**Expected scale and bounded performance budget.**

| Dimension | Before | As delivered |
|---|---|---|
| Categories | 1 | 2 |
| Catalogue records | 122 | 236 (12 cockpits, 224 modules) |
| `VehicleCatalogData` sources | 1 at 197,226 characters | index plus four chunks (`PIERCER_1`, `PIERCER_2`, `EXOTIC_1`, `EXOTIC_2`), each under 190,000 (packed to 150,000) |
| Script sources in the scoped capture | 213 | 217 |
| Preview instances (`check_projection.py`) | 2,105 | 5,340 |
| Server catalogue payload | about 173 KB JSON. The canonical Piercer-only `GetInitial` reply is 172,437 characters (golden step 01). | Larger. Not measured with Exotic on. Cached by revision after the first fetch. |
| Parts per full build | Piercer about 57 | Exotic 172 to 204 per spawned stock vehicle (blockout primitives; all six measured in Play) |
| VFX sockets per vehicle | Piercer 12 | Exotic 13 to 15 |
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
| 0 | Repo edits to three tool guards; `scripts/exotic_category/stage_0/` sandbox spec (`spec-sandbox-on.json`, `sandbox_audit.lua`, `sandbox_apply.lua`) | Capture (`false`) |
| A | `scripts/feature_installer.py`, one bundle: after-sources, new chunk modules and folder ops. Inputs delivered: `stage_a/server/ops.json`, `stage_a/client/ops.json`, `stage_a/client/config_ops.json`, `catalogue/out/manifest.json` (all under `scripts/exotic_category/`). **As delivered:** combined spec `scripts/exotic_category/stage_a/spec.json` (19 operations); built bundles `stage_a/out/install_audit.lua`, `install_apply.lua`, `install_rollback.lua`. | `roblox/captures/exotic-before` |
| B | One dedicated canonical installer with AUDIT, APPLY and ROLLBACK in one scope (`pilot` or `full`). **As delivered:** `scripts/exotic_category/stage_b/build_content.py` builds `stage_b/out/installer.lua` for one mode and one scope; the logic is `installer_engine.lua`. The built files for each mode are kept as `out/pilot_*.lua` and `out/full_*.lua`. | Live state, audited by the installer itself. Reference capture after Stage A: `roblox/captures/exotic-stage-a`. |
| Flag | `scripts/exotic_category/flag/spec-flag-on.json` (`flag_audit.lua`, `flag_apply.lua`, `flag_rollback.lua`). One attribute operation, Standard lane. | The attribute is absent before |

After-files are complete sources made by copying the blob and editing it. Every projected source is compiled with `loadstring` in Edit before assignment. No in-game backup folders, no fallback implementation, no patch ladder: a failed installer is repaired, not patched around.

### Rollback for each stage

Rollback runs in reverse dependency order: **B before A, A before 0.**

| Stage | Fast switch-off | Full rollback | Proven by | Limits |
|---|---|---|---|---|
| 0 tools | n/a | Revert the three guard edits in the repo | Capture and pipeline tests | Do not revert while Stage A or B is installed: `studio_capture.load` rejects a capture from a place not in `PLACE_IDS`, so the Stage A ROLLBACK bundle could no longer be built from `exotic-before`. The place lock on installers is separate: `feature_installer.py` asserts `game.PlaceId == bundle.place_id`, taken from the capture. |
| 0 sandbox | n/a | Set `StudioVehicleSandboxEveryPlay` back to `false` with the same guarded spec reversed | AUDIT state | With API access off, Play cannot load a profile once it is off. **As delivered:** the sandbox is on at handoff (`StudioVehicleSandboxEveryPlay = true`). It is required in this place. |
| A | None needed: Stage A alone changes no Piercer behaviour that a client can reach (section 8) | `feature_installer.py --mode ROLLBACK` built from `stage_a/spec.json`, the same before capture and unchanged after-files. Restores the 14 sources and the single-source `VehicleCatalogData`, and removes the two chunk modules and the two `ModuleArtwork` folders. | **As delivered:** AUDIT before, APPLY 19, AUDIT after, ROLLBACK 19, AUDIT before, APPLY 19, repeat APPLY 0. The state after ROLLBACK was proved by AUDIT; no capture was taken at that point (section 7.2). | Refuses on any drift: every target must hold exactly its before or its after value. Stage B must be removed first, because Exotic records need the chunked catalogue. While Stage B is installed, Stage A AUDIT stops with drift on the index, which then lists the `EXOTIC_<n>` chunks. That is expected. |
| B | `Flag_VehicleClass_exotic` off (flag ROLLBACK removes the attribute; absent reads as off), then restart Play. Stops sales and hides the category. Not to be used once a saved profile owns an Exotic (section 12). | Installer ROLLBACK (`build_content.py --mode ROLLBACK --scope full`, run in Edit): removes both `EXOTIC` category folders, the four VFX template folders and every `VehicleCatalogData.EXOTIC_<n>` chunk, and regenerates the index for what remains through `catalogue_gen.lua`. It does not touch the `PIERCER_<n>` chunks or the flag attribute. The flag has its own ROLLBACK, run after it. | **As delivered:** proven on the pilot scope, twice. First: ROLLBACK, then Stage A AUDIT reports "after" with 0 changed and `Revision` is `469d9bd8...cf0e`. Second, after the Play tests: ROLLBACK, then capture `exotic-pilot-removed` compared with `exotic-stage-a` shows no source delta; only the flag attribute differs. ROLLBACK of the full scope has not been run. | Allowed only while no saved profile holds an Exotic. True in this place. After a saved sale anywhere, content must stay. ROLLBACK fails loudly, and changes nothing, if a created root holds something the installer did not create, if the state is partial or foreign, or if the catalogue is stale. A leftover `EXOTIC_<n>` chunk reads as a stale catalogue in `check_projection.py` and is not removed by the Stage A ROLLBACK. |
| Flag | n/a | `flag_rollback.lua`: removes `Flag_VehicleClass_exotic` from `ServerStorage.Config` | No flag ROLLBACK run is recorded in `verification.json` | Run after the Stage B ROLLBACK and before the Stage A ROLLBACK |

**As delivered, the full order is:** Stage B ROLLBACK (full scope, in Edit), then the flag ROLLBACK, then the Stage A ROLLBACK from `spec.json` against `exotic-before`. Stage B must be removed before Stage A.

Keep the before capture, the specs and the after-files unchanged in the repo for as long as rollback may be needed. Restoring source values does not undo runtime side effects; restart Play after any install or rollback.

## 19. Risks and mitigations

| # | Risk | Mitigation |
|---|---|---|
| 1 | The catalogue split rewrites the only client source for previews, ratings and upgrade data, and it can fail silently | Split with Piercer only first. Before install, load the generated chunks with `loadstring` in Edit and compare the merged table with the live data: 6 cockpits, 116 modules, same `Revision`. Checkers compare every generated source. |
| 2 | Blockout geometry on a Piercer-tuned runtime: driver inside the engine, flames wider than the car, hidden lamps, low roofs, off-centre camera | Per-cockpit seat offsets. Exotic-scaled jet templates. Fixed lamps on Nose and Engine Deck. Pilot one cockpit and its 18 modules, drive it, and fix the recipe before generating the rest. As delivered: the pilot caught the seat height and the glass colour. |
| 3 | Money and ownership code changed in a place that cannot save | Sandbox on. Golden parity before and after. The crafted refusals in section 14. Persistence recorded as deferred under DATA-01. |
| 4 | A failed cross-category purchase corrupts the session (`CurrentCategory` written before validation) | Stage A validates before mutating. Test: unaffordable Exotic, then `GetInitial`. |
| 5 | Debit before ten grants widens ECON-01 | Every default is pre-checked before the debit. No refund logic. |
| 6 | Free-part loop through generalised defaults | Grant-once guard on new-slot defaults; `FrontBody` and `RearBody` required. The existing Piercer `Engine2` loop is out of scope and recorded. |
| 7 | A client saves an arbitrary `CategoryId` through the first-child fallback | The written category comes from the cockpit template and must match the request |
| 8 | Text matching: a body part named with "engine" becomes an engine; a missing `ModuleType` becomes "Misc" | Explicit `ModuleType`, `ModuleFolder`, `EnginePosition` on every slot and module; the name rules in section 6.2; installer census |
| 9 | A missing `Price` makes an item free or $1,000 | The installer asserts `Price > 0` on cockpits and on Lightweight, Power and body modules, and `Price = PurchasePrice = 0` with `SourceCockpitId` and `CategoryId` set on Standard modules. The Standard extra-copy charge is tested (section 14 charge cases). |
| 10 | The flag hides but does not block | Both buy actions check the flag on the server |
| 11 | Catalogue cached per server | Restart Play after every install. As built, a flag change rebuilds the server catalogue (GC5); restart Play after a flag change as well, unless the mid-session switch is the test. |
| 12 | 150 to 195 parts per car on low-end devices (as delivered: 172 to 204 per spawned stock vehicle) | Recorded as deferred (EXO-01). Final meshes replace primitives later in the same format. |
| 13 | Garage holds 10 vehicles with no sell path, against 12 cockpits | Known limit, recorded (EXO-01). Out of scope. |
| 14 | Garage rating may not equal the on-road rating (possible double count in `VehiclePerformanceServer`, affects Piercer equally) | Compare `PerformanceIndex` on a spawned Piercer with its garage rating in the first Play. Record the result; do not fix here. As delivered: confirmed. A spawned vehicle double-counts module `TopSpeed`, `Weight` and three boost stats. Forge reads 245 on the road against 202 in the garage; Wedge 566 against 540. The tiers still match. Recorded as VEH-01. |
| 15 | Category order: categories sort by display name, so Exotic is listed before Piercer, and `GarageUI` falls back to the first category when `State.CategoryId` matches none | Check which category the dealership and workshop open on with the flag on. Record what is seen. As delivered: `verification.json` does not record which category opens first. The Piercer category view lists six Piercer cards only. |
| 16 | An owned Exotic with the flag off from server start: the category is absent from the server catalogue, so the workshop may fall back to the first category's slots and modules | From server start it cannot occur in this place, because nothing saves. The nearest case here is the flag switched off during a session with an Exotic owned (section 14 threat row); look at the workshop then and record what is seen. Must be tested in a saving place before any move to v2. Recorded under DATA-01. As delivered: not tested. It is documented as unsupported (section 12, EXO-02). |
| 17 | `execute_luau` network access may be withdrawn again | One-line localhost probe at the start of each session; fall back to data carried in the code string. As delivered: `execute_luau` reached localhost on 2026-10-02 and 2026-10-03. |
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
- **Save/rejoin/migration:** N/A in this place. API access is off, so nothing can be saved. Deferred under DATA-01 and DATA-02: a vehicle with the new slots survives rejoin, old saves load unchanged, and the flag-off case for an owned Exotic, which is unsupported until the server half is decided and built (EXO-02), all in an isolated published place before any move to v2.
- **Device/performance/streaming:** Studio desktop only. Physical phone, tablet, controller, low-end memory with 172 to 204 parts per spawned stock car, and the 15-player case are deferred (PERF-01, PERF-06). Streaming N/A: no world-size change.
- **Rollback:** proven for Stage A and for the content installer (remove, parity, reinstall). After the content ROLLBACK: no `EXOTIC_<n>` chunk is left, Stage A AUDIT reports state "after" with 0 drift (index and `PIERCER_<n>` byte-identical to the Stage A after-files), `Revision` is `469d9bd8...cf0e`, and `check_projection.py` passes. This proves Stage A can still be rolled back. **As delivered:** proven for Stage A, and for the content installer on the pilot scope only. The full-scope ROLLBACK has not been run. The record has a capture compare after the pilot ROLLBACK, not a `check_projection.py` run (section 24.3).
- **Evidence record:** `scripts/validation_record.py` with checks `tooling installation startup garage race errors cleanup api persistence device multiplayer`; captures under `roblox/captures/exotic-category/`. **As delivered:** the evidence record is `scripts/exotic_category/verification.json`. Screenshots are `roblox/captures/exotic-category/01-dealership-wedge-pilot.jpg` to `10-my-vehicles-hyper.jpg`. No `validation_record.py` record for this task was found in the repository on 2026-10-03.

Results against this matrix are in section 24.

Avoid finishing a time trial during these tests (PB-01 writes a personal best even in the sandbox), or accept the change on the dev account.

## 21. Readiness scorecard exceptions or deferred risks

Final values as delivered, 2026-10-03. "PASS" here means agent-verified in Studio. It is not user confirmation.

| Area | Status | Note |
|---|---|---|
| Ownership | PASS | No owner added. No new remote, action, argument field or saved field. |
| Security | PASS for the single-client refusals recorded in `verification.json` | Four threat rows are not in the record (section 14). A full exploit audit of each handler stays open under NET-01. |
| Data | PASS for IDs and schema; **DEFERRED** for save and rejoin | DATA-01, DATA-02. Must close before any move to v2. |
| Lifecycle | PASS | No new connections, loops or clones. Server and client logs show no error or warning from this work. |
| Performance | **DEFERRED** | Part count on low-end devices (PERF-01, PERF-06) |
| Mobile/input | **DEFERRED** | Studio desktop only |
| Streaming | N/A | No change to streamed content |
| Failure handling | PASS on the pure tests (server 28 of 28) | Validate before debit; skip-with-warning for missing templates. No template was missing in Play, so the warning paths did not run there. |
| Observability | PASS on the pure tests | Existing counters and one warning per missing ID. `NetStats` rejection counts are not in the record. |
| Documentation | PASS | Section 23 documents updated 2026-10-03, with the two gaps named in section 24.4 item 15. `docs/04_customisation_ui.md` needed no change. |

Each `DEFERRED` row is recorded in `docs/06_current_known_issues.md` (EXO-01) with the point before which it must close.

Known limits after this work:

- Geometry is blockout primitives.
- No card images (EXO-03).
- No visible cockpit lamp parts. The cockpit light swatches tint the cast light only.
- Saving is untested.
- Flag off is not supported once an Exotic is owned (EXO-02).
- The on-road rating is higher than the garage rating. This is existing behaviour for both categories (VEH-01).
- Neon inheritance and the legacy four-slot default re-grant are unchanged (GAR-01).
- Cloned accessory upgrade paths carry `Drag` (EXO-04).
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
12. Content rollback is proven: remove, parity, reinstall. After ROLLBACK, Stage A AUDIT reports state "after" with 0 drift and `Revision` is `469d9bd8...cf0e`.
13. Every integrator line in this file is filled (they now read "As delivered").
14. The evidence record passes `validation_record.py check`, with deferred checks named.
15. The documents in section 23 are updated.
16. Verified work is committed with explicit paths and pushed to origin main.

Not required for done: Oscar's judgement of driving feel and looks, device tests, two-client tests, saving tests. They are recorded as open.

The result against each item is in section 24.

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

## 24. As delivered (2026-10-03)

This section records the delivery. It does not repeat the evidence. Read `scripts/exotic_category/verification.json` for what was installed, every test and its result, what is not verified, the known issues and the rollback order.

### 24.1 Evidence level

| Item | Level |
|---|---|
| Balance data, prices, ratings, upgrade paths (`balance/report.md`) | Generated. The six stock ratings and prices were then read in the dealership in Play. |
| Stage A (19 operations) | Installed in Space Racers Backup v2 (133417340424236) |
| Stage B, full scope (6 cockpits, 108 modules, 1,746 template parts, 162 module sockets) | Installed in the same place |
| `Flag_VehicleClass_exotic = true`; no-save sandbox on | Installed in the same place |
| Edit checks and Play tests | Agent-verified in Studio |
| Oscar's play test | Not done. Nothing is user-confirmed. |
| Space Racers v2 (71491191583884) | Untouched |
| Publishing | None |

### 24.2 Captures

All four are scoped captures taken in Edit, with the five roots in section 4.

| Capture | Taken (UTC) | Sources | State |
|---|---|---:|---|
| `roblox/captures/exotic-before/capture.json` | 2026-10-02 21:05:39 | 213 | Baseline |
| `roblox/captures/exotic-stage-a/capture.json` | 2026-10-03 09:55:39 | 215 | Stage A installed |
| `roblox/captures/exotic-pilot-removed/capture.json` | 2026-10-03 10:21:22 | 215 | Pilot rolled back. No source delta against `exotic-stage-a`; only the flag attribute differs. |
| `roblox/captures/exotic-after/capture.json` | 2026-10-03 10:22:35 | 217 | Full content installed |

Screenshots: `roblox/captures/exotic-category/` (ten images).

### 24.3 Results against the verification matrix

| Area | Result | Key in `verification.json` |
|---|---|---|
| Static/install | Pass. `check_projection.py` and `check_catalogue.py` pass on `exotic-after` in the split form. Post-install checks: 0 unreachable template paths, channel census equal, 192 sockets all under parts, preview parity exact. Attribute census: 0 problems across 6 cockpits and 108 modules. | `installation`, `state_after` |
| Piercer parity | Pass. Golden 24 of 24 must-match lines. Seats unchanged on a spawned Piercer. Dealership ratings unchanged. Pure tests: server 28 of 28, client 20 of 20. | `piercer_parity` |
| Exotic in Play | Pass for what was run. The Wedge went through the real UI: dealership, purchase, paint, garage, drive. The other five were bought and spawned through API calls. | `exotic_play_tests` |
| Refusals and charges | Pass for the rows in the record (section 14) | `refusals_cash_intact`, `module_economy`, `no_regrant` |
| Rollback | Stage A: proven. Stage B: proven on the pilot scope. | `installation`, `rollback` |
| Review | Six builders, each followed by an independent reviewer and a fix pass. `delivery-reviewer` before each APPLY: no blocker. | `review` |
| Save and rejoin, devices, two clients | Not verified | `not_verified` |

Not verified, from the record: saving and rejoin; mobile and low-end devices; two-client behaviour; race entry and time trial with an Exotic; the owned-garage display bay with an Exotic; driving feel, looks and VFX taste; flag off after an Exotic is owned.

Matrix lines with no entry in the record: a buy, equip, upgrade and paint pass on each of the ten slots through the UI; module browse and back; switching between a Piercer and an Exotic; the passenger seat on an Exotic; `NetStats` rejection counts; the four threat rows named in section 14; golden with the full scope installed and the flag off; a run of the two capture tool tests; eight unchanged slot cards in the Piercer garage in Play (covered by the client pure tests only); the capture compare after the Stage A ROLLBACK (AUDIT was used instead, section 7.2).

### 24.4 Result against "Done when"

| # | Result |
|---|---|
| 1 | The tools accept the backup place for scoped captures. A run of the tool tests is not recorded. |
| 2 | Met (section 4) |
| 3 | Met. Two identical runs, re-recorded after the recorder fix. |
| 4 | Met |
| 5 | Met. Catalogue split parity identical; `Revision` `469d9bd8...cf0e` with Piercer only. |
| 6 | Met |
| 7 | Met, through the real UI |
| 8 | Met |
| 9 | Met with the pilot scope installed |
| 10 | Partly. Wedge through the real UI; the other five by API. Race entry, time trial and the owned-garage bay were not run. |
| 11 | Partly. Every recorded row passes. Four threat rows are not in the record. |
| 12 | Met on the pilot scope |
| 13 | Filled. Three lines say a value was not measured: the catalogue payload with Exotic on, the open-dealership refresh after a flag change, and which category opens first. |
| 14 | Not met. No `validation_record.py` record was found. `verification.json` is the record. |
| 15 | Met on 2026-10-03, with two gaps: no `docs/architecture/<task>-validation.json` (item 14), and the open questions in `docs/design/vehicle-frame-classes.md` are not answered. |
| 16 | The integrator's step. Not recorded in this file. |

Open items are in `docs/06_current_known_issues.md`: EXO-01 to EXO-04, VEH-01 and GAR-01.
