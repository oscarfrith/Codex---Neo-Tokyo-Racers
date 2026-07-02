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

## Spawn Markers

`Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint` is the migrated general vehicle spawn marker from Architecture Phase N.

The dealership intro flow adds `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint` for the final server-created drivable vehicle after customisation. This gives the dealership exit its own editable placement and facing direction without changing the client-only preview spawn.

## Current Diagrams

- `diagrams/vehicle_asset_system.svg`
