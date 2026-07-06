# Free Roam Vehicle Spawn Phase 2 Blockout Road Markers

**Script:** `scripts/roblox_freeroam_vehicle_spawn_phase2_blockout_road_markers.lua`  
**Status:** Prepared for Studio Command Bar  
**Type:** World/config setup, no spawn behavior patch

## Why This Supersedes The Broad Road Scan

The user confirmed there is a curated road blockout source:

```text
Workspace.Test + WIP Assets.Blockout.Roads
```

Each road surface is a part named `Road`, though some are nested inside folders/models. This is a better first-pass source than scanning the full city hierarchy because it avoids road markings, dividers, path-edge meshes, pavements, and building-detail assets.

## What It Creates

For every `BasePart` named exactly `Road` under the blockout roads folder with part colour `RGB(95, 95, 95)` / `#5f5f5f`, the script creates one invisible marker above the road part centre:

```text
Workspace.NeoTokyoRacersWorld.SpawnPoints.RoadSpawnMarkers
```

Each marker:

- is a tiny anchored invisible part;
- has `CanCollide = false`, `CanTouch = false`, `CanQuery = false`;
- has no scripts, constraints, lights, or descendants;
- is tagged `NTR_RoadSpawnPoint`;
- stores source-road attributes for debugging.

Road-named parts with different colours are skipped, so similarly named wall pieces in the blockout source do not receive spawn markers.

The script also ensures:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.FreeRoamVehicleSpawn
```

## Performance Notes

This is a good first-pass method. These markers are very cheap compared with city meshes because they are invisible, non-colliding, non-query, anchored, scriptless, and can be cached by the server once at startup.

If the road blockout has hundreds of matching grey road parts, that is still expected to be fine. If it has thousands, the next refinement should merge markers by distance or use a CFrame data module, but editable invisible marker parts are the best balance for now.

## Verification

After running the script:

1. Inspect `Workspace.NeoTokyoRacersWorld.SpawnPoints.RoadSpawnMarkers`.
2. Confirm the markers sit above road centres.
3. Delete or disable any marker that lands in a bad spot, such as under/inside a building or on a non-drivable path.
4. Refresh the Studio mirror before Phase 3.
