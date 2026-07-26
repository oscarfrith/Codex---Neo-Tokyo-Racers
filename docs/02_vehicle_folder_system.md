# Vehicle Folder System

## Physical module-instance colour completion V1.1 (confirmed and handed off 2026-07-26)

The physical module-instance record remains the saved authority for installed module identity, colours, Neon, and upgrades. A newly purchased instance can currently contain `Colors={}`. Preview fills absent channels for presentation, while the server clone path interprets that empty table as a complete override and leaves authored grey. This explains preview/spawn mismatch and persistence after rejoin.

The V1 repair completes only missing `Primary`, `Secondary`, `Detail`, `Neon`, and applicable `ThrustColor` fields during canonical instance hydration. Existing explicit fields are never overwritten. `FrontLights` and `RearLights` remain cockpit-protected and are neither stored nor projected as module repair channels.

The user confirmed the physical module-colour repair and V1.1 corrective access flow working. The complete `20:46:20` mirror is current. The canonical installer audits every current cockpit for Boost, Engine1, Engine2, FrontBumper, RearBumper, RearSpoiler, SidePods, and Stabilisers slots, plus authoritative module-template coverage for those locations. Keep full runtime parity across every current vehicle, compatible location and rejoin transition in release regression. See `docs/customisation-access-onboarding-physical-colours-v1.md`.

## Multiplayer collision and speed-sensitive parking runtime contract

Vehicle Multiplayer VFX/Collision/Exit V1.1 adds no authored cockpit/module folder and changes no persistence. Runtime models beneath `Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles` are registered by `VehicleCollisionLifecycleService_Active`.

Free-roam BaseParts use `NTR_VehicleSlow` or `NTR_VehicleFast`; active race models remain under `NTR_RaceParticipant`. Faster exited vehicles transiently carry `NTR_ExitCoasting=true` plus `NTR_ExitCoastStartedAt` and stay in the fast character-pass-through group. Settled parked vehicles carry `NTR_ParkedFixed=true` and an anchored welded root until authoritative re-entry. These are runtime markers, not saved or authored asset metadata.

The user confirmed this runtime contract working, and the complete `2026-07-26 19:03:42` mirror contains its installed service/source markers and tuning revision. Treat V1.1 as the current vehicle-runtime baseline.

## Customisation three-workshop Neon capability

Vehicle Customisation V1 does not move or create vehicle assets. Module Neon availability is derived server-side from supported renderable descendants already authored beneath each module's `NEON_OptionalLights` folder. `NeonPrice` remains an optional module-model attribute with a server fallback of `5000`.

Paint Shop must not expose a module Neon colour channel until the equipped module instance owns Neon. The later confirmed Vehicle Cosmetics V1.2 supersedes the original bulk-only Underglow plan: Underglow is now a buyable per-vehicle cosmetic backed by attributed `SurfaceLight` objects beneath `UNDERGLOW_EMITTERS_DoNotRename` or the compatible legacy `UNDERGLOW_MOUNT_DoNotRename` ancestry. It does not reuse `NEON_OptionalLights`. Runtime owns only saved `Color` and purchased `Enabled`; Brightness, Range, Angle, Face, Shadows and emitter count remain authored per cockpit.

## Owned-Garage Production Asset Authority (Phase 13 V1.4)

Owned-garage runtime templates, structure, decorations, lighting and display-platform cosmetics resolve only from `ServerStorage.NeoTokyoRacers.OwnedGarage`. Editing or scratch copies are not a fallback, parity target or readiness dependency. An asset becomes production-ready only when the completed Model is copied into the matching authoritative ServerStorage path and passes the canonical audit.

Scratch libraries should not remain in ReplicatedStorage in a published build because their unused geometry can still contribute to client replication/download and memory. Keep scratch work in ServerStorage or a separate unpublished authoring place. This does not change vehicle/cockpit/module authority: display slots still store stable saved `VehicleId` references and platform cosmetics never own a vehicle.

## Loading Phase 3 Owned-Garage Vehicle Boundary

Loading/start-screen Phase 3 does not create, destroy, assign or clear an owned vehicle. `OwnedGarageManagementRuntime` keeps the confirmed revisioned display assignment and compensation contract, while the existing lifecycle bridge remains the only `GetDrivenVehicle`, `DespawnForGarage` and `SpawnFromGarage` owner. The loading system wraps browser/prompt activation and waits for the existing authoritative result.

Driven entry must still resolve one stable saved `VehicleId`, remove the live vehicle once, assign or retain one display slot and compensate on teleport/lifecycle failure. Drive-out must clear one saved display reference, spawn that same saved vehicle once at the property-owned `VehicleExitSpawn`, and restore the assignment if spawn fails. Phase 3 adds no asset folder, cockpit/module identity, spawn marker or saved field.

## Owned Garage Replacement Contract

The approved physical owned-garage replacement stores display assignments as stable keys into the existing `profile.Vehicles` dictionary. A display slot never owns, copies or deletes vehicle data: moving a vehicle clears its former display reference, and replacing a full slot changes only that reference. Phase 2 adds an inactive `OwnedGarageDisplayRuntime` that resolves the requested cockpit/module instances from the same saved vehicle dictionaries and live asset catalogue, then removes seats, scripts, VFX, collision, queries and shadows from the anchored presentation. It rejects a second visual placement of the same `VehicleId`. Phase 3 stages the replacement transaction and passes only the stable `VehicleId` through an unowned lifecycle bridge. Phase 4 adds the space-first management UI and server actions but routes every assignment/clear through that same transaction; it adds no vehicle clone/spawn owner.

Phase 6 keeps `profile.Garage` authoritative for vehicle capacity and existing cockpit purchase rules. Canonical property/display state lives separately at `profile.OwnedGarage`; the current vehicle snapshot-import path copies that namespace forward before replacing saved vehicle data. The lifecycle bridge calls the existing action owner's local build/despawn/select helpers and never creates another vehicle identity or save owner.

Phase 13 V1.1 treats display-platform geometry as an optional garage decoration, not as a vehicle or display-assignment owner. `DisplayPlatforms` assets may replace the template pad visuals, but vehicle identity remains a stable `VehicleId` in the existing display slots and the anchored vehicle presentation runtime remains unchanged. Platform models therefore belong under the owned-garage decoration asset roots, never under cockpit/module folders.

## Phase AM Performance Attributes

Vehicle Phase AM keeps the Phase AK folder layout unchanged. It adds zero-value tuning attributes directly to active cockpit and module models:

```text
PerformanceDelta_<RawVariableName>
```

Cockpits receive the detailed chassis variables. Modules receive only variables relevant to their `ModuleType`. These values are additive to the Phase AK legacy totals, so leaving them at `0` preserves the existing balance.

For a cockpit that must replace rather than add to a calculated value, use:

```text
PerformanceOverride_<RawVariableName>
```

Modules remain interchangeable across cockpits in the same vehicle category. Their performance deltas travel with the module template and are applied to whichever compatible cockpit equips it.

## High-Level Structure

The current vehicle asset system lives under `ReplicatedStorage.NeoTokyoRacers`:

```text
ReplicatedStorage
  NeoTokyoRacers
    Assets
      Vehicles
        Categories
          BRUISER
            COCKPITS
            MODULES_InterchangeableWithinCategory
      VFX
        VehicleTemplates
    Config
      Runtime
      Editable
      UI
        Theme
        PaintPresets
    Shared
      Modules
        Client
        Common
      Remotes
        Garage
```

This structure is based on the later fixed-slot category system, not the older cable-slot system.

Architecture Phase K moved the old kit contents into this layout, and Phase L confirmed `ReplicatedStorage.HOVER_RACING_V2_KIT` is gone.

## Category Rule

Vehicles inside the same category should share similar proportions and fixed slot locations. That lets a player buy one Bruiser cockpit and use compatible Bruiser modules across other Bruiser cockpits.

## Cockpit Assets

Cockpit assets should contain colour-channel folders or parts for:

- Primary
- Secondary
- Detail
- Glass
- Front neon/lights
- Rear neon/lights

Known default cockpit front/rear neon colours from the chat:

- Front lights: `Color3.fromRGB(252, 250, 255)`
- Rear lights: `Color3.fromRGB(255, 116, 116)`

Vehicle Phase AI removes the experimental cockpit SpotLight/Beam/projector systems from Phases S through AH. Front/rear cosmetic neon colour channels can remain, but there should be no current cockpit driving-light runtime, spotlight template folder, or helper LocalScript installed.

## Module Assets

Prepared Phase AK Bruiser shape:

```text
MODULES_InterchangeableWithinCategory
  Engines
    Bruiser_01
      MODULE_ENGINE_BRUISER_01_STANDARD
      MODULE_ENGINE_BRUISER_01_LIGHTWEIGHT
      MODULE_ENGINE_BRUISER_01_POWER
    ...
  Stabilisers
    Bruiser_01
      MODULE_STABILISER_BRUISER_01_STANDARD
      MODULE_STABILISER_BRUISER_01_LIGHTWEIGHT
      MODULE_STABILISER_BRUISER_01_POWER
    ...
  Boost
    Bruiser_01
      MODULE_BOOST_BRUISER_01_STANDARD
      MODULE_BOOST_BRUISER_01_LIGHTWEIGHT
      MODULE_BOOST_BRUISER_01_POWER
    ...
  FrontBumpers
    MODULE_FRONTBUMPER_LVL1
    MODULE_FRONTBUMPER_LVL2
    MODULE_FRONTBUMPER_LVL3
  RearBumpers
  RearSpoilers
  SidePods
```

Modules remain interchangeable within `BRUISER`; the per-cockpit folders are catalogue organisation, visual family groupings, and purchase-unlock families, not equip compatibility locks.

Persistence Phase 16 direction:

- a module from `Bruiser_02` can be equipped on a compatible `Bruiser_01` cockpit if the player owns that module copy;
- buying a new module copy from `Bruiser_02` is locked until the player owns the `bruiser_02` cockpit family;
- each cockpit purchase grants one included Standard starter set for that cockpit instance;
- buying extra Standard module copies must cost money, preferably through explicit `ExtraCopyPrice`, `ModuleCopyPrice`, `PurchasePrice`, or `Price` attributes on the module template.

Current clean module folder shape requested by the user:

```text
MODULE_EXAMPLE
  ModuleRoot_DoNotRename
  VFX_ATTACHMENTS_DoNotRename
  PRIMARY_ReplaceWithPrimaryMeshes
  SECONDARY_ReplaceWithSecondaryMeshes
  DETAIL_ReplaceWithDetailMeshes
  NEON_OptionalLights
  THRUST_COLOR_WhiteByDefault
```

`THRUST_COLOR_WhiteByDefault` applies to modules that have thrust visuals:

- Engines
- Boost
- Stabilisers

`NEON_OptionalLights` is for buyable cosmetic neon. The system should only offer neon purchase if this folder contains neon assets.

## Module Attributes

Known module/cockpit stat attributes used by server/driving logic:

- `Price`
- `ModuleId`
- `ModuleType`
- `TopSpeed`
- `Acceleration`
- `Handling`
- `Drift`
- `Braking`
- `Weight`
- `Boost`
- `BoostDuration`
- `BoostRecharge`
- `BoostRechargeDelay`

Phase AK also adds editable balancing metadata:

- `Tier`
- `Level`
- `Power`
- `NeonPrice`
- `BalanceEditable`
- `BalanceNote`

Persistence Phase 16 reads optional module economy/sorting metadata:

- `SourceCockpitId`
- `VariantName`
- `VariantOrder`
- `ExtraCopyPrice`
- `ModuleCopyPrice`
- `PurchasePrice`

Persistence Phase 17 should treat engine position as explicit metadata rather than inferring it only from names:

- Front engines live under `Engines` and should have `EnginePosition = "Front"` plus `RearEngine = false`.
- Rear engines live under `Engines_B` and should have `EnginePosition = "Rear"` plus `RearEngine = true`.
- `SLOT_Engine1` should use `AllowedModuleFolder = "Engines"` and `EnginePosition = "Front"`.
- `SLOT_Engine2` should use `AllowedModuleFolder = "Engines_B"` and `EnginePosition = "Rear"`.
- The old flat front-engine catalogue entries such as `Engine V1` through `Engine V4` should be retired/hidden rather than deleted. The visible front-engine list should use the same per-cockpit family style as rear engines, for example Bruiser family Standard/Lightweight/Power entries under `Engines/Bruiser_01` through `Engines/Bruiser_05`.

Bruiser cockpits can declare included standard modules with:

- `DefaultEngineModuleId`
- `DefaultStabilisersModuleId`
- `DefaultBoostModuleId`

`V75` adds missing Boost module attributes where possible:

- `Boost`
- `BoostDuration`
- `BoostRecharge`
- `BoostRechargeDelay`

## Phase AL Performance Foundation

Prepared shared paths:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common.Performance
ReplicatedStorage.NeoTokyoRacers.Shared.Config.VehiclePerformance_EditAttributes
```

Phase AL introduces detailed raw variables without switching live driving yet:

- `EngineOutput`
- `LateralGrip`
- `SteeringResponse`
- `HoverStability`
- `DriftControl`
- `DriftGrip`
- `DriftChargeRate`
- `BrakingForce`
- `BoostForce`
- `BoostEfficiency`
- `Drag`
- `Downforce`

The shared calculator converts these into Speed, Acceleration, Handling, Drift, Braking, Boost, and the overall E-S performance rating.

## Vehicle Performance V2 Phase 0

Phase 0 is deliberately non-mutating. `scripts/roblox_vehicle_performance_v2_phase0_audit.lua` verifies the live five-cockpit/72-module/23-upgrade foundation, the Viper donor models, and reserved `bruiser_06` / `BRUISER_06` identities before any sixth-vehicle cloning.

The six planned balanced stock guides are Forge E200, Vector D375, Viper C525, Nightline B662, Rally A787, and new Zenith S925. These are derived target centres, never rating overrides. Phase 0 does not change current vehicle assets, IDs, prices, module attributes, or hierarchy.

Future phases must keep the existing stable `bruiser_01` through `bruiser_05` IDs even though their current mirror path is under `Categories.PIERCER`. Zenith should use the reserved `bruiser_06` identity only after the audit confirms it is unused.

Phase 1 adds no vehicle folders or assets. Its only new hierarchy is isolated `VehiclePerformanceV2_EditAttributes`, `VehiclePerformanceV2Definitions`, and `VehiclePerformanceV2Calculator`. All current cockpit/module identities and Viper donor models remain untouched while their standard builds are calculated in shadow.

## Vehicle Performance V2 Phase 2 balanced stock catalogue

Phase 2 defines six complete-stock builds under the shadow config's `BalancedStockProfiles` folder. The five existing cockpit IDs remain unchanged and `bruiser_06` is reserved for Zenith; this phase does not create/copy its model. Every profile stores the same 17 raw variable attributes, target tier/PI, and a price guide. These are calibration definitions, not live cockpit/module attributes.

The intended future asset phase may copy the Viper standard visual structure to the six vehicle families only after this shadow catalogue passes. It must still preserve per-cockpit module IDs and slot ownership rather than making every cockpit point at one shared module asset.

Phase 2 subsequently passed `8/0/0` and its `2026-07-13 20:53:08` mirror contains all six profiles. Phase 3 keeps assets unchanged and defines five component owners beneath every shadow profile: `Cockpit`, `FrontEngine`, `RearEngine`, `Stabilisers`, and `Boost`. This lets donor-tier strength travel with interchangeable modules while every Standard build still recombines to its calibrated raw total.

The user completed Phase 3 and refreshed the mirror at `21:01:42`. Phase 4 then passed `7/0/0` and was mirrored at `21:21:01`: every replaceable component has `Standard`, `Lightweight`, and `Power` shadow definitions. Standard uses zero upgrade capacity; Lightweight/Power use six points and equal donor-tier price guides.

Phase 5 keeps the same shadow-only boundary and defines three paths per upgradable module, each capped at three points with six total points available. Engines choose among Velocity, Output, and Efficiency; stabilisers choose Grip, Response, and Drift; boost chooses Burst, Endurance, and Recovery. Efficiency combines Weight reduction with half-strength EngineOutput so it remains meaningful when an A/S build reaches the Weight rating curve's technical minimum. A fully upgraded module can max two paths or mix all three. Per-point guide costs are based on total points already spent, so the path choice does not create an economy exploit. Live module models still retain their existing V1 attributes and three-level upgrades until a later migration gate.

Phase 5 was subsequently confirmed passing and mirrored at `21:51:45`. Because the garage automatically discovers every cockpit under the live category, Phase 6 materialises the six new cockpit templates and 72 core module templates under `ServerStorage.NeoTokyoRacers.VehiclePerformanceV2_Staging` rather than publishing them into `ReplicatedStorage...Categories`. This staging root is intentional generated content, not a backup. It mirrors the eventual category structure, uses current Viper visuals, contains the confirmed V2 raw attributes/paths/prices, and remains explicitly `CatalogPublishReady = false` until runtime and garage compatibility are gated. The user confirmed the Phase 6 installer passed, but the locally received mirror remains the `21:51:45` pre-Phase-6 export and therefore does not yet prove the staging hierarchy.

The remaining work is condensed to two phases. Phase 7 combines the shared V2-to-driving adapter, V2 rating runtime, legacy field compatibility, six-point module-instance ownership/persistence, purchase/preview calculations, and migration validation behind disabled feature switches. Phase 8 is the only live boundary: it atomically publishes the staged catalogue, enables the validated switches, verifies E-S purchase/customisation/spawn/driving/racing flows, and either keeps the switch or rolls it back as one unit. Keeping publication separate is necessary because live cockpit discovery is automatic.

Phase 7 is implemented without patching the live garage, bootstrap, V1 performance modules, or `VehicleDynamicsModel`. New isolated `VehiclePerformanceV2Runtime`, `VehiclePerformanceV2UpgradeRuntime`, and `VehiclePerformanceV2DynamicsAdapter` modules consume the staged raw attributes, six-point path folders, and the same V2 curve definitions for rating and future physics factors. Module-instance allocations use a nested `V2UpgradePoints` table, which the existing generic profile schema can encode without a schema-source edit. Legacy levels are preserved on a preview copy; up to six become V2 points and overflow receives a calculated refund credit for Phase 8 review. `VehiclePerformanceV2ShadowService_Active` reacts only when a spawned vehicle's V1 raw-runtime folder is written, then publishes `V2Shadow...` diagnostics without overwriting V1 attributes.

The corrected Phase 7 run was user-confirmed working. Phase 8 is generated as `scripts/roblox_vehicle_performance_v2_phase8_atomic_live_launch.lua` and remains one final stage. It canonically replaces three isolated compatibility modules, makes one hard-preflighted garage catalogue-call edit, publishes the six staged cockpits and 72 core modules, preserves cosmetic families, and enables all V2 owners only after live E-S validation. Existing profile module instances migrate lazily; original legacy levels remain stored and overflow refund credit is applied once. The same script's `ROLLBACK_SWITCHES` mode restores V1 ownership without deleting published assets or profile data. No in-game backup hierarchy is created; full asset rollback uses Roblox version history.

## Spawn Markers

`Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint` is the migrated general vehicle spawn marker from Architecture Phase N.

The dealership intro flow adds `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint` for the final server-created drivable vehicle after customisation. This gives the dealership exit its own editable placement and facing direction without changing the client-only preview spawn.

Owned garages use a separate property-scoped exterior contract. The transition-completion installer creates `Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors.STARTER_TWO_BAY.FootExitSpawn` and `VehicleExitSpawn`; `OwnedGaragePropertyCatalog.ExteriorSpawnId` selects the folder. Future garages must add their own two markers instead of sharing the dealership/general vehicle spawn or storing a CFrame in player data. `SpawnFromGarage` remains the existing vehicle-construction owner and receives the resolved marker CFrame through the narrow owned-garage lifecycle bridge.

## Current Diagrams

- `diagrams/vehicle_asset_system.svg`
## Owned garage exterior entry markers

Each owned-garage property keeps its world transition markers under `Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors.<ExteriorSpawnId>`. `FootEntrance` and `DriveInEntrance` are movable transparent interaction parts; `FootExitSpawn` and `VehicleExitSpawn` remain separate return destinations. Moving an entrance part moves its native prompt, while moving an exit spawn changes where players or vehicles return to the city. Entry prompts open the existing owned-garage browser, whose authoritative server action decides between on-foot and current-vehicle entry.

## Vehicle underglow emitters

Vehicle Cosmetics V1.1 uses attributed Part emitters beneath every live cockpit template:

```text
CockpitRoot_DoNotRename
  UNDERGLOW_EMITTERS_DoNotRename [Folder]
    FrontEmitter [Part]
      UnderglowSurfaceLight [SurfaceLight]
    CentreEmitter [Part]
      UnderglowSurfaceLight [SurfaceLight]
    RearEmitter [Part]
      UnderglowSurfaceLight [SurfaceLight]
```

Place each emitter Part directly in its intended cockpit-local position. Do not parent Parts beneath an Attachment and expect the Attachment transform to position them; BasePart parenting is not a physical attachment. Do not add manual welds—the canonical vehicle builder welds every recognised massless emitter Part to `CockpitRoot_DoNotRename`.

Each SurfaceLight uses `VehicleCosmeticId="Underglow"`. The parent Part is invisible, unanchored, massless, collision/query/touch disabled and does not cast shadows. The old `UNDERGLOW_MOUNT_DoNotRename` Attachment remains compatible but is no longer the authoring authority.

SurfaceLight Brightness, Range, Angle, Face, Shadows and other presentation properties are authored independently on each vehicle template. Runtime customisation changes only the saved player colour and whether purchased underglow is enabled.

## Onboarding Studio vehicle sandbox

Player Onboarding V1.7 adds an opt-in Studio-only testing mode at `Config.Runtime.Onboarding_EditAttributes.StudioVehicleSandboxEveryPlay`. ProfileService still loads and owns the canonical profile, then clears vehicle ownership, module ownership and garage display vehicle references only in that in-memory session. Garage property ownership and garage customisation remain intact.

The session is marked `NoSave`, and ProfileService returns before profile encoding or any DataStore update on every normal, forced, removal and shutdown save path. `RunService:IsStudio()` is a hard activation requirement. Disable `StudioVehicleSandboxEveryPlay` before production persistence/rejoin testing; no stored vehicles are deleted and no migration is required.
