# Racing Phase 10B - Folder Arrow Barriers

Generated: 2026-07-09

## Purpose

Phase 10B changes race-only corner blockers from example marker parts to the real arrow assets already placed on the route.

The authoring model is folder-based:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.ArrowMarkers
  Checkpoint0-1
  Checkpoint1-2
  ...
  Checkpoint14-0
  Unassigned_Arrows
```

For circuit routes, the final segment wraps back to the start, such as `Checkpoint14-0`. For point-to-point routes, the final segment is `Checkpoint14-Finish`.

## Studio Script

Run this in Edit mode:

```text
scripts/roblox_racing_phase10b_folder_arrow_barriers.lua
```

Use `MODE = "INSTALL"` for setup/install and `MODE = "SMOKE"` for a read-only check.

If the route already has exactly 14 checkpoints and only the folder structure is needed, this smaller helper creates the expected folders without touching scripts or moving arrows:

```text
scripts/roblox_racing_phase10b_create_14_checkpoint_arrow_folders.lua
```

## What It Installs

- Creates checkpoint segment folders under each route's `ArrowMarkers`.
- Moves loose `race arrows group` models into `Unassigned_Arrows` so they can be manually sorted without losing placement.
- Stores original arrow transparency on each arrow part.
- Replaces the isolated `RaceSessionAssetService_Active` with a folder-arrow barrier service.
- Replaces the isolated `RaceSessionAssetsClient_Active` with a client visibility controller.
- Adds small guarded hooks to `TimeTrialService_Active` and `RaceMatchmakingService_Active` so server colliders update when players pass checkpoints or reset.
- Uses Roblox's current `RegisterCollisionGroup` API only, avoiding the deprecated `CreateCollisionGroup` warning.

## Runtime Behavior

- Free roam players do not see or collide with race arrows.
- During a race or time trial, the client locally shows only nearby segment folders.
- The default visibility window is one segment behind, the current segment, and one segment ahead.
- For lap routes, the window wraps around the final segment, so `Checkpoint14-0` can be visible near the start.
- The server creates invisible simple box proxies from the visible segment arrows for collision.
- The visual arrow meshes remain client-local presentation; the physical blockers are invisible, simple, anchored server parts.

## Editable Values

On `ArrowMarkers`:

- `SegmentWindowBehind`: default `1`
- `SegmentWindowAhead`: default `1`
- `DefaultColliderThickness`: default `3`

On each arrow part:

- `NTR_ArrowColliderThickness`: optional per-arrow override for proxy thickness

On each segment folder:

- `Enabled`: set to `false` to disable that folder without deleting assets

## Verification

1. Run the script in Edit mode.
2. Drag some arrow groups from `Unassigned_Arrows` into `Checkpoint0-1`, `Checkpoint1-2`, and the final wrap folder.
3. Restart Play.
4. In free roam, confirm the race arrows are hidden and non-collidable.
5. Start a time trial and confirm nearby segment arrows appear.
6. Drive through checkpoints and confirm older/farther segments disappear while the next segment appears.
7. Try driving into the visible arrow barrier and confirm the vehicle collides.
8. Reset to checkpoint and confirm the correct nearby arrows reappear.

## Rollback

Disable or delete:

- `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionAssetsClient_Active`

The route arrow folders and original arrow assets remain editable in Studio. The old `SessionAssetMarkers.Example_Blocker_Disabled` path is superseded by this workflow for arrow barriers, but can be kept as historical/test infrastructure until cleanup.
