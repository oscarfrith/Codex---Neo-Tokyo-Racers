# Free Roam Vehicle Spawn Phase 3 Click Spawn

**Script:** `scripts/roblox_freeroam_vehicle_spawn_phase3_click_spawn.lua`  
**Status:** Prepared for Studio Command Bar  
**Type:** Guarded server/client source patch

## Purpose

Adds the first functional free-roam owned-vehicle spawning flow.

When a player clicks an owned cockpit card in the free-roam `Car` menu:

1. The client calls `GarageInvoke` action `SpawnOwnedVehicleFromFreeRoam`.
2. The server validates the requested `VehicleId` belongs to the player.
3. The server blocks spawning if current speed is above `MaxSpawnSpeedMph`, default `10`.
4. The server picks the nearest enabled marker tagged `NTR_RoadSpawnPoint`.
5. The server rejects blocked markers using a simple collision overlap check.
6. The existing current vehicle is cleared by the normal `V56_buildVehicle` path.
7. The selected owned vehicle is spawned at the marker and the player is seated.

## Dependencies

Run and verify the preferred marker setup first:

```text
scripts/roblox_freeroam_vehicle_spawn_phase2_blockout_road_markers.lua
```

The marker setup should create:

```text
Workspace.NeoTokyoRacersWorld.SpawnPoints.RoadSpawnMarkers
```

with tagged `NTR_RoadSpawnPoint` parts.

## Config

Phase 3 reads:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.FreeRoamVehicleSpawn
```

Useful values:

- `MaxSpawnSpeedMph`
- `SpawnCooldownSeconds`
- `RoadSearchRadius`
- `SpawnHeightOffset`
- `SpawnClearanceRadius`
- `StudsPerSecondToMph`
- `AllowFallbackToPlayerOffset`

## Safety Notes

This phase patches the active garage server and isolated free-roam nav client. The script is guarded and should stop if the expected source anchors are missing.

If spawning fails with `No clear road spawn nearby`, inspect nearby markers and collision blockers before increasing the search radius or enabling fallback spawning.
