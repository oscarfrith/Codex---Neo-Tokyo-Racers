# Racing Phase 10A - Session Asset Collision Foundation

**Script:** `scripts/roblox_racing_phase10a_session_asset_collision_foundation.lua`  
**Status:** Generated for Studio install/testing after Phase 9A was user-confirmed working.

## Purpose

Phase 10A adds the first server-owned layer for race/time-trial-only collidable assets, such as shortcut blockers, corner blockers, barriers, and later jump/boost/ramp assets.

The goal is simple and safe:

- author markers in the route folder;
- keep those markers hidden and non-collidable in free roam;
- clone simple runtime assets only into the active session folder;
- make runtime session assets collide with race participants, not default free-roam parts;
- clean the assets when the session ends.

## Installed Structure

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.SessionAssetMarkers
  Example_Blocker_Disabled

ServerStorage.NeoTokyoRacers.Racing.SessionAssetTemplates
  SimpleBarrier

ServerScriptService.NeoTokyoRacers.Services.Racing
  RaceSessionAssetService_Active
  RaceSessionAssetBindings.SessionAssets

StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing
  RaceSessionAssetsClient_Active
```

## Authoring Workflow

1. In Studio, find:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.SessionAssetMarkers.Example_Blocker_Disabled
```

2. Duplicate it.
3. Rename it, for example:

```text
Blocker_Shortcut_01
```

4. Move/rotate/scale it to cover the corner, shortcut, or lane you want blocked.
5. Set:

```text
Enabled = true
TemplateId = "SimpleBarrier"
Modes = "TimeTrial,Race"
RuntimeTransparency = 0.35
```

The marker itself stays hidden, non-collidable, non-touchable, and non-queryable. During a race or time trial, the server clones the runtime barrier into:

```text
Workspace.NeoTokyoRacersWorld.RaceInstances.<RunId>.SessionAssets
```

## Collision Model

Phase 10A creates fixed collision groups:

```text
NTR_RaceSessionAsset
NTR_RaceParticipant
```

Runtime session assets are put in `NTR_RaceSessionAsset`. Active participants' character and race vehicle parts are temporarily put in `NTR_RaceParticipant`.

The intended behavior is:

- participants collide with their active session blockers/assets;
- default free-roam parts do not collide with session blockers/assets;
- assets are destroyed when the run folder is cleaned up.
- after a Phase 8H reset respawns the race vehicle, participant collision groups are reapplied to the replacement vehicle.

## Scope Guard

This phase intentionally does not edit:

- reward config or reward multipliers;
- route-guide config or checkpoint label visuals;
- Phase 8H respawn reset architecture;
- Phase 9A lap/session scoring;
- the register-limited bootstrap;
- rich VFX/mesh art for race assets.

## Verification

1. Run `scripts/roblox_racing_phase10a_session_asset_collision_foundation.lua` in Studio Command Bar.
2. Restart Play.
3. Duplicate `Example_Blocker_Disabled` in the route's `SessionAssetMarkers` folder.
4. Move/scale it so it blocks part of the first test route.
5. Set `Enabled = true`.
6. Start a time trial and confirm a runtime asset appears under `RaceInstances.<RunId>.SessionAssets`.
7. Drive into it and confirm your race vehicle collides with it.
8. Quit/finish the session and confirm the runtime asset is destroyed.
9. Confirm normal checkpoints, lap sessions, rewards, and reset-to-checkpoint still work.
10. After resetting to checkpoint, drive into the same blocker again and confirm the replacement vehicle still collides with it.

## Risks

- Roblox collision groups affect physics, not just visibility. If a marker appears but does not block as expected, check the cloned runtime asset under `RaceInstances.<RunId>.SessionAssets` and confirm its parts use collision group `NTR_RaceSessionAsset`.
- This is an MVP same-server collision layer. It reduces free-roam interference, but true competitive race isolation should still move toward route pockets or reserved servers later.
- The current client visibility helper is presentation-only. The server collision groups are the important anti-interference layer.

## Rollback

Use Roblox version history, or disable/delete:

- `RaceSessionAssetService_Active`;
- `RaceSessionAssetsClient_Active`;
- `RaceSessionAssetBindings`;
- `ServerStorage.NeoTokyoRacers.Racing.SessionAssetTemplates`;
- route `SessionAssetMarkers` folders if you no longer want the authored markers.
