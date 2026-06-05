# Phase 9 Server Services Scaffold

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Prepared  
**Studio script:** `scripts/roblox_hierarchy_phase9_server_services_scaffold.lua`

## Goal

Phase 9 creates the future server service structure for the garage, vehicle, profile, and economy systems without replacing the current live `HOVER_RACING_V2_Server` action layer.

The current live server still owns `GarageInvoke.OnServerInvoke`. This phase only prepares safe targets for a future extraction.

## What The Script Creates

Under `ServerScriptService`:

```text
NeoTokyoRacers
+-- NeoTokyoRacersServer_Bootstrap_Disabled
+-- Services
|   +-- Economy
|   |   +-- EconomyService
|   +-- Garage
|   |   +-- GarageActionService
|   +-- Player
|   |   +-- ProfileService
|   +-- Vehicle
|       +-- VehicleBuildService
|       +-- VehicleCatalogService
|       +-- VehicleSpawnService
|       +-- VehicleStatsService
+-- State
    +-- RuntimeProfiles
```

Under `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data`:

```text
ServerContext
ServerServiceMigrationMap
```

Under `ReplicatedStorage.NeoTokyoRacers.Compatibility`:

```text
CurrentLiveServer
CurrentGarageInvoke
FutureServerRoot
```

## What It Does Not Change

The script does not:

- Edit `HOVER_RACING_V2_Server`.
- Disable or replace the current V56 `GarageInvoke.OnServerInvoke` handler.
- Require or enable the new services.
- Change profile data, cash, purchases, vehicle spawn, driving, VFX, client UI, mobile controls, LOD, lighting, traffic, or assets.

## Future Migration Map

The created `ServerServiceMigrationMap` records the intended split from the current V56 block:

- `ProfileService`: profile defaults, normalization, lookup, and leaderstats.
- `EconomyService`: price/cash checks and future Get More boundary.
- `VehicleCatalogService`: category, cockpit, slot, module, and catalog reading.
- `VehicleStatsService`: total stat calculation and profile-to-client payload shaping.
- `VehicleBuildService`: clone cockpit/modules, apply colours, weld model, create seat.
- `VehicleSpawnService`: current vehicle lifecycle, seat player, exit, and re-enter.
- `GarageActionService`: future `GarageInvoke` action router preserving the current response shape.

## Test Checklist

After running the Studio script:

- Cash still loads correctly.
- Dealership data still appears.
- Cockpit buying/selection still works.
- Cockpit paint still works.
- Module buying/equipping still works.
- Customisation and upgrades still work.
- Vehicle spawns normally.
- Vehicle driving still works.
- Exit/re-enter vehicle still works.
- New server bootstrap remains disabled.

## Codex Safety Notes

- Do not switch `GarageInvoke.OnServerInvoke` in the same pass as creating these services.
- Treat the current `V56_CONSOLIDATED_ACTION_CONTROLLER` block as the server source of truth until replacement services are tested.
- Do not patch the older top-level action layer unless deliberately removing it after the new services are live.
- Do not combine server extraction with client UI, driving, VFX, or mobile HUD changes.
- Keep `Workspace.Test + WIP Assets` excluded.
