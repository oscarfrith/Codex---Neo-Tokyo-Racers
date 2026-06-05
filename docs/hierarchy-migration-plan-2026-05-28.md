# Hierarchy Migration Plan

**Document status:** Proposed clean migration plan based on Studio inventory  
**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Source report:** `docs/studio-inventory-report-2026-05-28.md`  
**Current status:** Phase 6 world services migration prepared / Phase 1-5A installed by user  

## Roadmap Note

This document contains the original detailed migration ideas and older phase numbering. For the current compressed phase plan, use:

```text
docs/compressed-architecture-roadmap-2026-05-28.md
```

The compressed roadmap supersedes the old phase numbers below. The old sections are still useful as detail notes, but should not be treated as the active sequence.

## Summary

The Studio inventory was pasted correctly and is usable for architecture planning. The report has:

- A clear inventory start: `# Neo Tokyo Racers Studio Inventory Report`
- A generated timestamp: `2026-05-28 12:45:03`
- Top-level service children
- Service hierarchy sections
- Scripts/remotes/modules list
- Vehicle/module asset scan
- Lighting snapshot
- Important object paths
- Class counts at the end

No blank lines between copied `Inventory_001`, `Inventory_002`, etc. chunks is fine. The original report was one continuous string, so direct concatenation is acceptable.

## Important Exclusion

Do not reorganise:

```text
Workspace.Test + WIP Assets
```

Assets inside `Test + WIP Assets` are to be moved, replaced, or cleaned later. They should be ignored by the main hierarchy migration, except for documentation that notes they are excluded.

## Current Actual Hierarchy Snapshot

### ReplicatedStorage

Current top-level children:

```text
ReplicatedStorage
- FarLOD5
- HOVER_RACING_V2_KIT
- Shared
- zzVehicleModules
```

`HOVER_RACING_V2_KIT` is the active vehicle/game kit and should not be removed or renamed in the first migration.

Current `HOVER_RACING_V2_KIT` children:

```text
HOVER_RACING_V2_KIT
- 00_EDIT_ME_FIRST
- CLIENT_MODULES
- CONFIG
- PAINT_PRESETS_EditColoursHere
- REMOTES_DoNotRename
- SHARED_MODULES
- UI_THEME_DoNotRename
- VEHICLE_CATEGORIES
- VFX_TEMPLATES
```

Current important non-kit folders:

```text
ReplicatedStorage.Shared
- LightingPresets
- SkyPresets

ReplicatedStorage.zzVehicleModules
- Older/test vehicle module system
```

### ServerScriptService

Current top-level children:

```text
ServerScriptService
- HOVER_RACING_SERVER
- HOVER_RACING_V2_SERVER
- Lighting
- Traffic Lights
```

Active server scripts:

```text
ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server
ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_DriverSeatPosition
ServerScriptService.Lighting.LightingController
ServerScriptService.Traffic Lights
```

Legacy/disabled script:

```text
ServerScriptService.HOVER_RACING_SERVER.HOVER_RACING_Server_Consolidated
```

### StarterPlayerScripts

Current important children:

```text
StarterPlayer.StarterPlayerScripts
- HOVER_RACING_V2_CLIENT
- HOVER_RACING_V2_Client
- HOVER_RACING_V46_ThrustPreviewOnly
- HOVER_RACING_V64_CachedThrustVisualRuntime
- HOVER_RACING_V67_MobileDriveControls
- HOVER_RACING_V71_MobilePcHudSuppressor
- LOD System
- TEMP_LightingPreview
- LocalScript
- LocalScript
```

There are also several disabled historical helper LocalScripts. These should not be deleted in the first migration. They can be moved into a documented legacy folder later after a play-test confirms they are not needed.

### Workspace

Current top-level relevant children:

```text
Workspace
- GeneratedCityBlocks
- HOVER_RACING_V2_WORLD
- Test + WIP Assets
```

Current runtime world folder:

```text
Workspace.HOVER_RACING_V2_WORLD
- PLAYER_VEHICLES_Runtime
- GaragePreviewPad
- VehicleSpawnPoint
```

`GeneratedCityBlocks` is the active generated city/world content root.

`Test + WIP Assets` is explicitly excluded from migration for now.

### Lighting

Lighting currently contains:

```text
Lighting
- Atmosphere
- Bloom
- ColorCorrection
- ColorGrading
- DepthOfField
- Sky
- SunRays
```

Additional lighting preset data exists in:

```text
ReplicatedStorage.Shared.LightingPresets
ReplicatedStorage.Shared.SkyPresets
ServerScriptService.Lighting.LightingController
StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview
```

## Current System Ownership

### Vehicle / Garage / Customisation

Primary source:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT
ServerScriptService.HOVER_RACING_V2_SERVER
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
Workspace.HOVER_RACING_V2_WORLD
```

Current remotes:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename.GarageInvoke
ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename.GaragePush
```

### Driving

Primary modules/scripts:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.DrivingControllerV47
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.MobileDriveInputState
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.ReentryThrottle
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor
```

### VFX

Primary templates/runtime:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.VFX.VehicleVFXController
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Visuals.CachedThrustVisualRuntime
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime
```

### World / LOD

Primary folders/scripts:

```text
Workspace.GeneratedCityBlocks
ReplicatedStorage.FarLOD5
StarterPlayer.StarterPlayerScripts.LOD System
```

### Lighting

Primary folders/scripts:

```text
ReplicatedStorage.Shared.LightingPresets
ReplicatedStorage.Shared.SkyPresets
ServerScriptService.Lighting.LightingController
StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview
```

### Traffic Lights

Primary script:

```text
ServerScriptService.Traffic Lights
```

Traffic light assets appear in generated city/world areas. Do not move them separately until the world hierarchy is planned.

## Target Structure

The long-term target is still:

```text
ReplicatedStorage
- NeoTokyoRacers
  - Shared
    - Config
    - Remotes
    - Modules
  - Assets
    - Vehicles
    - VFX
    - UI
  - Compatibility

ServerScriptService
- NeoTokyoRacers
  - Services
  - ServerModules

StarterPlayer
- StarterPlayerScripts
  - NeoTokyoRacersClient
    - Controllers
    - ClientModules

StarterGui
- NeoTokyoRacersUI

Workspace
- NeoTokyoRacersWorld
  - City
  - RaceRoutes
  - Garages
  - Runtime
  - SpawnPoints
```

But the first migration should not hard-move everything into this shape. It should create compatibility and then migrate one system at a time.

## Migration Principles

- Keep `HOVER_RACING_V2_KIT` live until every reference is migrated.
- Keep `HOVER_RACING_V2_Client` and `HOVER_RACING_V2_Server` live until controller/service splits are proven.
- Move data/config before moving logic.
- Move assets before renaming scripts that consume them.
- Do not delete or disable old folders in the first pass.
- Do not touch `Workspace.Test + WIP Assets`.
- Use idempotent migration scripts that can run more than once safely.
- Add resolver modules before changing hard-coded paths.
- After each phase, play-test in Studio before continuing.

## Phase 1: Add Clean Roots Only

Create new empty roots without moving active content:

```text
ReplicatedStorage.NeoTokyoRacers
ReplicatedStorage.NeoTokyoRacers.Shared
ReplicatedStorage.NeoTokyoRacers.Shared.Config
ReplicatedStorage.NeoTokyoRacers.Shared.Remotes
ReplicatedStorage.NeoTokyoRacers.Shared.Modules
ReplicatedStorage.NeoTokyoRacers.Assets
ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles
ReplicatedStorage.NeoTokyoRacers.Assets.VFX
ReplicatedStorage.NeoTokyoRacers.Assets.UI
ReplicatedStorage.NeoTokyoRacers.Compatibility

ServerScriptService.NeoTokyoRacers
ServerScriptService.NeoTokyoRacers.Services
ServerScriptService.NeoTokyoRacers.ServerModules

StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.ClientModules

StarterGui.NeoTokyoRacersUI

Workspace.NeoTokyoRacersWorld
Workspace.NeoTokyoRacersWorld.City
Workspace.NeoTokyoRacersWorld.Runtime
Workspace.NeoTokyoRacersWorld.RaceRoutes
Workspace.NeoTokyoRacersWorld.Garages
Workspace.NeoTokyoRacersWorld.SpawnPoints
```

Also create a note/config object marking this as a transition hierarchy.

Risk: low. This should not affect running game logic if no old objects are moved.

## Phase 2: Add Compatibility Path Resolver

Create a resolver module such as:

```text
ReplicatedStorage.NeoTokyoRacers.Compatibility.PathResolver
```

The resolver should map logical names to current paths:

```text
LegacyKit -> ReplicatedStorage.HOVER_RACING_V2_KIT
VehicleCategories -> ReplicatedStorage.HOVER_RACING_V2_KIT.VEHICLE_CATEGORIES
GarageRemotes -> ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename
ClientModules -> ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES
SharedModules -> ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES
VFXTemplates -> ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES
VehicleRuntime -> Workspace.HOVER_RACING_V2_WORLD.PLAYER_VEHICLES_Runtime
GeneratedCityBlocks -> Workspace.GeneratedCityBlocks
FarLOD5 -> ReplicatedStorage.FarLOD5
LightingPresets -> ReplicatedStorage.Shared.LightingPresets
SkyPresets -> ReplicatedStorage.Shared.SkyPresets
```

Do not update all existing scripts to use it yet. First add it as a tool for new code and later targeted migrations.

Risk: low if only added, medium once scripts begin using it.

## Phase 2B: Add Live Reference Registry

Prepared script:

```text
scripts/roblox_hierarchy_phase2_live_references_registry.lua
```

This script adds a visual bridge layer after Phase 1. It creates ObjectValue references from the new `NeoTokyoRacers` architecture to the current live systems, and adds:

```text
ReplicatedStorage.NeoTokyoRacers.Compatibility.LiveSystemRegistry
```

This gives future scripts and future Codex sessions a central map of the live systems without moving anything yet.

It should not:

- Move assets.
- Rename active scripts.
- Disable scripts.
- Delete folders.
- Touch `Workspace.Test + WIP Assets`.
- Change driving, UI, VFX, lighting, LOD, traffic lights, or customisation behaviour.

Risk: low. ObjectValue references are inspection/migration aids only.

## Phase 3: Mirror Configs Into New Structure

Mirror, not move, current editable configs:

From:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG
ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST
ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename
ReplicatedStorage.HOVER_RACING_V2_KIT.PAINT_PRESETS_EditColoursHere
```

To:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving
ReplicatedStorage.NeoTokyoRacers.Shared.Config.Camera
ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI
ReplicatedStorage.NeoTokyoRacers.Shared.Config.Economy
ReplicatedStorage.NeoTokyoRacers.Shared.Config.VFX
ReplicatedStorage.NeoTokyoRacers.Shared.Config.Vehicles
```

The old config folders should remain authoritative until scripts are explicitly switched.

Risk: low if mirrored only.

Prepared script:

```text
scripts/roblox_hierarchy_phase3_config_registry_mirrors.lua
```

This script formalises the Phase 3 config bridge. It creates/refines:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config
ReplicatedStorage.NeoTokyoRacers.Shared.Config.ConfigRegistry
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.ConfigRegistry
```

It adds live ObjectValue references to current authoritative config folders and generated `_Mirror` folders for inspection only. The old config remains authoritative until a specific live system is intentionally migrated and play-tested.

It should not:

- Change live config values.
- Move assets.
- Rename or disable scripts.
- Switch live scripts to the new config paths.
- Touch `Workspace.Test + WIP Assets`.
- Change driving, UI, VFX, lighting, LOD, traffic lights, or customisation behaviour.

## Phase 4: Consolidate Lighting Docs/Refs, Then Migrate Lighting

Current lighting is split across:

```text
ReplicatedStorage.Shared.LightingPresets
ReplicatedStorage.Shared.SkyPresets
ServerScriptService.Lighting.LightingController
StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview
Lighting
```

Target:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.LightingPresets
ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.SkyPresets
ServerScriptService.NeoTokyoRacers.Services.LightingService
```

Suggested approach:

1. Leave current scripts in place.
2. Mirror preset modules/folders into target path.
3. Update only the lighting controller to read through `PathResolver`.
4. Test day/night switching.
5. Only then consider moving/renaming scripts.

Risk: medium because night sky already has known issues.

## Phase 5: Move World Runtime Root With Compatibility

Current:

```text
Workspace.HOVER_RACING_V2_WORLD
- PLAYER_VEHICLES_Runtime
- GaragePreviewPad
- VehicleSpawnPoint
```

Target:

```text
Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles
Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad
Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint
```

Suggested approach:

1. Create target folders.
2. Add ObjectValues or resolver mappings first.
3. Do not move `PLAYER_VEHICLES_Runtime` until vehicle spawn code reads the resolver.
4. Update one spawn/runtime lookup at a time.
5. Test spawn, drive, exit, re-enter, saved cars.

Risk: high if moved before server/client path references are updated.

## Phase 6: Vehicle Asset Migration

Current:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.VEHICLE_CATEGORIES.BRUISER
- COCKPITS_ReplaceAssetsHere
- MODULES_InterchangeableWithinCategory
- UPGRADES_InvisiblePerformance
```

Target:

```text
ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories.BRUISER
- Cockpits
- Modules
  - FrontEngines
  - RearEngines
  - Boost
  - Stabilisers
  - Body
- Upgrades
```

Suggested approach:

1. Do not move assets immediately.
2. Create a catalogue adapter that can read the old shape and later the new shape.
3. Rename only display labels first:
   - `Engine 1` -> `Front Engine`
   - `Engine 2` -> `Rear Engine`
4. Keep `AllowedModuleFolder=Engines` and `AllowedModuleFolder=Engines_B` until the server equip logic is updated.
5. Move/copy one module family at a time after the adapter is ready.

Risk: high because dealership, purchase, equip, colour, VFX, and spawn logic all depend on this hierarchy.

## Phase 7: VFX Migration

Current:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.VFX.VehicleVFXController
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Visuals.CachedThrustVisualRuntime
```

Target:

```text
ReplicatedStorage.NeoTokyoRacers.Assets.VFX.Templates
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.VFX
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.VFXController
```

Suggested approach:

1. Keep current templates live.
2. Mirror VFX templates into target folder.
3. Update cached runtime to read templates through resolver.
4. Test engine idle, engine acceleration, boost, stabiliser left/right, hover dust.
5. Only then move template source.

Risk: medium-high because thrust/neon flicker and weld leaks were past issues.

## Phase 8: Client Script Split

Current active client scripts:

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor
StarterPlayer.StarterPlayerScripts.LOD System
StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview
```

Target:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers
- BootController
- GarageController
- DrivingController
- CameraAssistController
- MobileControlsController
- VFXController
- LODController
- LightingPreviewController
```

Suggested approach:

1. Do not split the main client script all at once.
2. Add a `BootController` later that requires modules in a known order.
3. Move helper scripts into modules first.
4. Keep `HOVER_RACING_V2_Client` as the bootstrap until every subsystem is extracted.
5. Remove disabled legacy scripts only after confirmed unused.

Risk: very high if done as a large rewrite.

## Phase 9: Server Script Split

Current active server scripts:

```text
ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server
ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_DriverSeatPosition
ServerScriptService.Lighting.LightingController
ServerScriptService.Traffic Lights
```

Target:

```text
ServerScriptService.NeoTokyoRacers.Services
- GarageService
- VehicleService
- EconomyService
- RaceService
- LightingService
- TrafficLightService
```

Suggested approach:

1. Leave the current active server script in place.
2. Extract pure helper functions into server modules first.
3. Move traffic lights and lighting into service folders after path resolver is available.
4. Extract garage/vehicle/economy only after the remotes and catalogue paths are stable.

Risk: very high if server action layer is replaced in one pass; previous patch history shows this area is fragile.

## Phase 10: World Organisation

Current:

```text
Workspace.GeneratedCityBlocks
ReplicatedStorage.FarLOD5
StarterPlayer.StarterPlayerScripts.LOD System
Workspace.Test + WIP Assets
```

Target:

```text
Workspace.NeoTokyoRacersWorld.City.GeneratedCityBlocks
ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.LODController
```

Suggested approach:

1. Do not move `GeneratedCityBlocks` or `FarLOD5` until LOD script reads paths through resolver.
2. Exclude `Test + WIP Assets`.
3. Confirm LOD still works after any path change.
4. Test fast driving through city after path migration.

Risk: high because LOD and streaming are performance-critical.

## Phase 11: Legacy Cleanup

Only after all systems work in the target structure:

- Move disabled historical scripts into a `Legacy_Disabled` folder.
- Move `zzVehicleModules` into a documented archive or leave it excluded.
- Remove old compatibility mappings one at a time.
- Keep one stable rollback version in Roblox version history, not in-game backup folders.

Do not delete:

```text
Test + WIP Assets
```

until the user explicitly asks.

## Recommended First Migration Script

The first script should only:

1. Create the new root folders.
2. Add `PathResolver` with current legacy mappings.
3. Add notes/readme StringValues explaining the transition.
4. Create target config folders.
5. Mirror key config values into the new config location.

It should not:

- Move assets.
- Rename active scripts.
- Disable scripts.
- Delete folders.
- Touch `Test + WIP Assets`.
- Change driving, UI, VFX, lighting, or LOD behaviour.

Prepared script:

```text
scripts/roblox_hierarchy_phase1_architecture_resolver.lua
```

This script creates the clean future roots, installs `PathResolver`, and mirrors key config folders as generated reference copies only. It is deliberately non-destructive and leaves the current `HOVER_RACING_V2_*` live systems untouched. `StarterGui.NeoTokyoRacersUI` is created as an empty `ScreenGui` so future UI can be visually edited in Studio. World asset roots such as `FarLOD5` and `GeneratedCityBlocks` are recorded as live path references, not duplicated.

## Validation Checklist After Phase 1-3

After creating roots/resolver/config mirrors, confirm:

- Dealership opens.
- Cockpit preview appears.
- Cockpit purchase/select works.
- Module purchase/equip works.
- Customisation menus still open.
- Vehicle spawns.
- Vehicle hovers and drives.
- Mobile drive UI still appears on mobile.
- PC drive HUD is hidden on mobile.
- Engine/boost/stabiliser VFX still work.
- LOD script still runs.
- Lighting controller still switches presets.
- Traffic lights still cycle.

## Codex Safety Notes

- Future Codex sessions should use this plan plus `docs/architecture-reorganisation-plan.md`.
- Do not create migration scripts that modify all systems at once.
- If a phase fails, stop and roll back through Roblox version history before layering more patches.
- Prefer adding compatibility first, then moving systems later.
- Keep `Test + WIP Assets` untouched.
