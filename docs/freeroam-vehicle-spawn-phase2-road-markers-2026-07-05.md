# Free Roam Vehicle Spawn Phase 2 Road Markers

**Script:** `scripts/roblox_freeroam_vehicle_spawn_phase2_road_spawn_markers.lua`  
**Status:** Prepared for Studio Command Bar  
**Type:** World/config setup, no spawn behavior patch

## Purpose

Phase 1 confirmed the existing server and free-roam UI hooks are ready, but the world has no explicit road spawn markers. It found many road-like surfaces, including large path-edge meshes, so Phase 2 avoids broad guessing and creates markers only from safer exact `Road` / `Road Asphalt` parts.

## What It Creates

- `Workspace.NeoTokyoRacersWorld.SpawnPoints.RoadSpawnMarkers`
- Invisible anchored marker parts tagged `NTR_RoadSpawnPoint`
- `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.FreeRoamVehicleSpawn`

Default config values:

- `MaxSpawnSpeedMph = 10`
- `SpawnCooldownSeconds = 1`
- `RoadSearchRadius = 300`
- `SpawnHeightOffset = 4`
- `SpawnClearanceRadius = 16`
- `StudsPerSecondToMph = 0.625`
- `AllowFallbackToPlayerOffset = false`

## Safety Notes

The script does not patch the garage server or free-roam client. It only prepares explicit road placement data for Phase 3. It ignores road markings, dividers, edge meshes, lights, and crossings.

If the installed markers do not land on the visible road centres in Studio, do not continue to Phase 3 yet. Move or add markers manually, or adjust the marker generation filter.
