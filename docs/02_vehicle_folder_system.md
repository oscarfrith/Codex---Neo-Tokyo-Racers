# Vehicle Folder System

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

## Current Diagrams

- `diagrams/vehicle_asset_system.svg`
