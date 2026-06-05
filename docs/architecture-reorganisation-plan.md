# Architecture Reorganisation Plan

**Document status:** Proposed target architecture  
**Document created:** 2026-05-28  
**Document last updated:** 2026-05-28  
**Current status:** Planning / no game hierarchy changes made yet  
**Relevant docs file:** `docs/architecture-reorganisation-plan.md`  
**Relevant files to edit:** Documentation first. Later, migration scripts and Roblox hierarchy only after inventory is reviewed.

## Goal

Reorganise Neo Tokyo Racers into a consistent, future-proof Roblox hierarchy without breaking working prototype systems.

The main aim is to make the game easier to extend, debug, and hand off between Codex/ChatGPT sessions by separating:

- Shared data/config
- Client controllers
- Server services
- Vehicle assets
- VFX assets
- UI assets/theme
- World/race/runtime folders
- Legacy compatibility paths

## Non-Goals

- Do not immediately rewrite working vehicle, UI, VFX, or server systems.
- Do not rename every existing object in one patch.
- Do not delete legacy folders until all references have been migrated and tested.
- Do not replace `HOVER_RACING_V2_KIT` blindly; current scripts still expect it.
- Do not move large world/city assets until an inventory confirms the real hierarchy.

## Current Constraints

Known current root:

```text
ReplicatedStorage
- HOVER_RACING_V2_KIT
  - VEHICLE_CATEGORIES
  - CLIENT_MODULES
  - CONFIG
```

Known dependent script patterns:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers
ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
```

Because those paths exist in current scripts, the first migration should create new clean structure and compatibility links/resolvers rather than hard-renaming everything.

## Recommended Target Explorer Structure

Proposed long-term structure:

```text
ReplicatedStorage
- NeoTokyoRacers
  - Shared
    - Config
      - Gameplay
      - Vehicles
      - UI
      - VFX
      - World
    - Remotes
      - Garage
      - Vehicles
      - Racing
      - Economy
    - Modules
      - Utility
      - Data
      - Vehicle
      - UI
  - Assets
    - Vehicles
      - Categories
        - BRUISER
          - Cockpits
          - Modules
    - VFX
      - Templates
      - SharedTextures
    - UI
      - Theme
      - Templates
  - Compatibility
    - LegacyPathMap

ServerScriptService
- NeoTokyoRacers
  - Services
    - VehicleService
    - GarageService
    - RaceService
    - EconomyService
    - WorldService
  - ServerModules
    - Data
    - Validation
    - Runtime

StarterPlayer
- StarterPlayerScripts
  - NeoTokyoRacersClient
    - Controllers
      - DrivingController
      - GarageController
      - UIController
      - MobileControlsController
      - VFXController
      - CameraAssistController
    - ClientModules
      - Input
      - UI
      - Vehicle
      - VFX

StarterGui
- NeoTokyoRacersUI
  - Screens
  - Components
  - Theme

Workspace
- NeoTokyoRacersWorld
  - City
    - GeneratedCityBlocks
    - FarProxies
    - TrafficLights
  - RaceRoutes
  - Garages
  - Runtime
    - PlayerVehicles
    - RaceInstances
    - TemporaryVFX
  - SpawnPoints

ServerStorage
- NeoTokyoRacersServerStorage
  - PrivateTemplates
  - ImportStaging
```

## Compatibility Strategy

Use a transition layer before moving live systems.

Recommended compatibility rules:

- Keep `ReplicatedStorage.HOVER_RACING_V2_KIT` until all current scripts stop requiring it.
- Add `ReplicatedStorage.NeoTokyoRacers` as the new clean root.
- Add a path resolver ModuleScript so future code asks for systems by logical name instead of hard-coded paths.
- Do not duplicate large assets permanently. During migration, use references/config tables or one canonical asset location.
- Only remove legacy folders after a clean play-test confirms no script reads them.

Example logical names for a resolver:

```text
SharedConfig
VehicleCategories
ClientControllers
GarageRemotes
RuntimeVehicles
WorldRoot
```

## Naming System

Use PascalCase for services, controllers, modules, and main system folders:

```text
VehicleService
GarageController
CameraAssistController
VehicleStatsConfig
NeoTokyoRacersWorld
```

Use uppercase stable IDs only for game content identifiers:

```text
BRUISER
COCKPIT_BRUISER_ORIGIN
MODULE_FRONT_ENGINE_01
MODULE_REAR_ENGINE_01
MODULE_BOOST_01
```

Use suffixes only when they communicate behaviour:

```text
*_Runtime
*_DoNotRename
*_EditAttributes
*_Template
*_Config
*_Service
*_Controller
```

Avoid mixed styles like:

```text
MODULES_InterchangeableWithinCategory
HOVER_RACING_V2_Client
boost primary
traffic light light red
```

Those can stay during transition, but new systems should use consistent names.

## Vehicle Asset Target Structure

Long-term vehicle assets:

```text
ReplicatedStorage
- NeoTokyoRacers
  - Assets
    - Vehicles
      - Categories
        - BRUISER
          - Cockpits
            - COCKPIT_BRUISER_ORIGIN
          - Modules
            - FrontEngines
              - MODULE_FRONT_ENGINE_01
            - RearEngines
              - MODULE_REAR_ENGINE_01
            - Boost
              - MODULE_BOOST_01
            - Stabilisers
              - MODULE_STABILISER_01
            - Body
              - FrontBumpers
              - RearBumpers
              - RearSpoilers
              - SidePods
```

Keep the current clean module internals:

```text
MODULE_EXAMPLE
- ModuleRoot_DoNotRename
- VFX_ATTACHMENTS_DoNotRename
- PRIMARY_ReplaceWithPrimaryMeshes
- SECONDARY_ReplaceWithSecondaryMeshes
- DETAIL_ReplaceWithDetailMeshes
- NEON_OptionalLights
- THRUST_COLOR_WhiteByDefault
```

## Config Target Structure

Configs should move toward one place:

```text
ReplicatedStorage
- NeoTokyoRacers
  - Shared
    - Config
      - Vehicles
        - VehicleStatsConfig
        - ModuleSlotConfig
        - UpgradeConfig
      - Driving
        - DrivingMechanics_EditAttributes
        - DrivingCameraAssist_EditAttributes
        - HoverWobble_EditAttributes
      - UI
        - UITheme_EditAttributes
        - LayoutScaleConfig
      - VFX
        - VFXQualityConfig
        - ThrustColourDefaults
      - World
        - LODConfig
        - LightingPresets
```

Rules:

- Attribute folders are good for designer-tunable values.
- ModuleScripts are better for structured tables.
- Do not scatter tuning values across multiple unrelated scripts.
- When a config is read every frame, cache it at runtime and refresh only when needed.

## Runtime Folder Rules

Runtime objects should live under clear runtime roots:

```text
Workspace
- NeoTokyoRacersWorld
  - Runtime
    - PlayerVehicles
    - RaceInstances
    - TemporaryVFX
    - Debug
```

Rules:

- Runtime folders should be empty or safe to clear before play.
- Runtime objects should be named with owner/context where practical.
- Do not store source templates in runtime folders.
- Do not store permanent player-owned assets directly in Workspace.

## Remotes Target Structure

All RemoteEvents/RemoteFunctions should live together:

```text
ReplicatedStorage
- NeoTokyoRacers
  - Shared
    - Remotes
      - Garage
      - Vehicles
      - Racing
      - Economy
      - UI
```

Rules:

- Server validates purchases, upgrades, and vehicle spawns.
- Client may preview UI/visual changes, but server decides ownership and cost.
- Remote names should describe actions, not UI buttons.

Good examples:

```text
RequestBuyCockpit
RequestEquipModule
RequestSpawnVehicle
RequestStartRace
UpdateVehicleColours
```

## UI Target Structure

UI should be separated into screens, components, and theme:

```text
StarterGui
- NeoTokyoRacersUI
  - Screens
    - DealershipScreen
    - PaintScreen
    - ModuleBuildScreen
    - CustomiseScreen
    - DrivingHUD
  - Components
    - StatBar
    - Button
    - Card
    - ColourPicker
  - Theme
    - UITheme_EditAttributes
```

Rules:

- Keep visual theme in one place.
- Keep data/state out of UI objects where possible.
- Avoid creating/destroying large UI trees repeatedly; reuse panels/buttons where practical.
- Mobile layouts should be first-class, not a late patch.

## VFX Target Structure

VFX should separate source templates from runtime attachments:

```text
ReplicatedStorage
- NeoTokyoRacers
  - Assets
    - VFX
      - Templates
        - EngineJet
        - BoostJet
        - StabiliserJet
        - HoverDust
      - SharedTextures

Workspace
- NeoTokyoRacersWorld
  - Runtime
    - TemporaryVFX
```

Rules:

- Use cached runtime VFX where possible.
- Avoid cloning VFX every frame.
- Keep thrust colour separate from optional cosmetic neon.
- Beams can stay white unless the design changes.
- Particles/fire for thrust should read selected thrust colour.

## World Target Structure

World systems should be grouped by purpose:

```text
Workspace
- NeoTokyoRacersWorld
  - City
    - GeneratedCityBlocks
    - FarLOD5
    - TrafficLights
    - Landmarks
  - RaceRoutes
  - Garages
  - SpawnPoints
  - Runtime
```

Rules:

- City source assets should not be mixed with runtime vehicles.
- LOD roots should be easy to find.
- Race routes should be editable without opening vehicle systems.
- Traffic lights should be controlled centrally.

## Migration Phases

### Phase 0: Inventory

Run `scripts/roblox_studio_inventory_report_v1.lua` in Roblox Studio and paste the report back into Codex.

If the report is too long for chat, paste it into:

```text
docs/studio-inventory-report-2026-05-28.md
```

Outcome:

- Confirm exact Explorer hierarchy.
- Confirm script names and locations.
- Confirm where remotes/configs/assets currently live.

### Phase 1: Add New Roots

Create empty new roots only:

```text
ReplicatedStorage.NeoTokyoRacers
ServerScriptService.NeoTokyoRacers
StarterGui.NeoTokyoRacersUI
Workspace.NeoTokyoRacersWorld
```

Do not move live assets yet.

### Phase 2: Add Path Resolver

Create a shared resolver module that maps logical names to current or new locations.

Outcome:

- New code stops depending on hard-coded legacy paths.
- Old paths continue working.

### Phase 3: Move Configs

Move or mirror config folders into the new `Shared.Config` structure.

High priority:

- Driving camera assist
- Driving mechanics
- Hover wobble
- UI theme
- VFX quality

### Phase 4: Move Assets

Move vehicle/VFX templates after config migration is stable.

Rules:

- Move one category at a time.
- Test the dealership after every vehicle asset move.
- Keep compatibility aliases during the transition.

### Phase 5: Move Runtime Roots

Move runtime vehicles, race runtime folders, temporary VFX, and debug folders under `Workspace.NeoTokyoRacersWorld.Runtime`.

### Phase 6: Rename Scripts

Only after roots/assets/configs are stable, rename client/server scripts into `Service` and `Controller` naming.

### Phase 7: Remove Legacy Paths

Only after published-client testing confirms no script requires the old hierarchy.

## Risk Areas

- Hard-coded `HOVER_RACING_V2_KIT` paths.
- `WaitForChild` calls that will infinite-yield if paths move.
- UI scripts that assume fixed object names.
- VFX runtime scripts that search by specific folder names.
- Vehicle spawn logic that expects exact runtime folder names.
- Attribute folders read every frame.
- Studio-only script paths that differ from live published hierarchy.

## Inventory Report Needed

Before writing any migration script, collect:

- Top-level children of key services.
- Full paths of Scripts, LocalScripts, and ModuleScripts.
- Full paths of RemoteEvents and RemoteFunctions.
- Full paths of folders/models with attributes.
- Key runtime folders.
- Current vehicle category/module hierarchy.
- Lighting/post-processing objects.
- World roots such as city blocks, traffic lights, LOD folders, race routes, and garages.

The current inventory snapshot and migration plan are now recorded in:

```text
docs/studio-inventory-report-2026-05-28.md
docs/hierarchy-migration-plan-2026-05-28.md
```

## Codex Safety Notes

- This document is a target plan, not permission to migrate everything at once.
- Future Codex sessions should read this doc before writing hierarchy migration scripts.
- If the real inventory conflicts with this target, update this doc before writing migration code.
- Prefer compatibility bridges over destructive moves.
- Do not delete old roots until multiple Studio tests confirm the new structure works.
- Any migration script should print what it changed and be idempotent where possible.
