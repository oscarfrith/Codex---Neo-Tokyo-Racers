# Vehicle Folder System

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

Modules remain interchangeable within `BRUISER`; the per-cockpit folders are catalogue organisation and visual family groupings, not compatibility locks.

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

Bruiser cockpits can declare included standard modules with:

- `DefaultEngineModuleId`
- `DefaultStabilisersModuleId`
- `DefaultBoostModuleId`

`V75` adds missing Boost module attributes where possible:

- `Boost`
- `BoostDuration`
- `BoostRecharge`
- `BoostRechargeDelay`

## Spawn Markers

`Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint` is the migrated general vehicle spawn marker from Architecture Phase N.

The dealership intro flow adds `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint` for the final server-created drivable vehicle after customisation. This gives the dealership exit its own editable placement and facing direction without changing the client-only preview spawn.

## Current Diagrams

- `diagrams/vehicle_asset_system.svg`
