# Free Roam Vehicle Spawn Phase 1 Audit

**Script:** `scripts/roblox_freeroam_vehicle_spawn_phase1_audit.lua`  
**Status:** Prepared for Studio Command Bar  
**Type:** Read-only diagnostic

## Purpose

This phase audits the existing free-roam vehicle menu and server spawn path before adding click-to-spawn / click-to-swap behavior.

It checks:

- the active garage server has `SelectVehicleInstance`, `SpawnVehicle`, `ExitVehicle`, vehicle clear, build, spawn CFrame, and auto-seat helpers;
- the active free-roam nav client has the Phase 7 owned-cockpit card renderer and preserved `VehicleId` / `CockpitId` attributes;
- `FreeRoamNav` config values needed for the next click-action phase;
- whether the world already has explicit road spawn markers/tags;
- whether the city contains usable road surface parts that could support a marker-generation phase;
- in Play mode, the current player's approximate vehicle speed and `GetInitial` vehicle count.

## Expected Outcome

No live objects or scripts are changed. The Output should tell us whether Phase 2 can:

1. use existing explicit road spawn markers;
2. generate/tag road spawn markers from existing road surface parts; or
3. fall back to player-offset spawning until road markers are added manually.

## Recommendation

Use explicit road-centre spawn markers for the final system. The server-side spawn action should search those markers, enforce the `10 mph` speed gate, despawn the current vehicle if needed, spawn the selected owned vehicle, and seat the player automatically.
