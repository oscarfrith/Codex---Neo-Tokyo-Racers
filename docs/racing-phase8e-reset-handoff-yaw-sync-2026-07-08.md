# Racing Phase 8E Reset Handoff Yaw Sync

**Script:** `scripts/roblox_racing_phase8e_reset_handoff_yaw_sync.lua`  
**Status:** Superseded by Phase 8F after testing showed the full driving handoff during reset could disable the car/camera and disturb streaming  
**Scope:** Reset-to-checkpoint orientation handoff for time trials and multiplayer races

## Why This Phase Exists

Phase 8D got reset momentum mostly under control, but the vehicle still faced the direction it was driving before reset instead of the checkpoint's authored orientation.

The refreshed mirror showed the root cause: the active driving loop stores its own `yawHeading` when driving starts. A server `vehicle:PivotTo(checkpoint.CFrame)` can move the car correctly, but the next driving heartbeat can apply the old `yawHeading` through `Drive_TerrainYawAlign`, pulling the car back toward the previous direction.

So the right fix is not another checkpoint CFrame patch. The reset needs a handoff:

- server remains authoritative for the reset pose;
- client stops doing a competing reset `PivotTo`;
- client refreshes the existing driving handoff after reset so the driving loop re-reads heading from the reset pose.

## What It Changes

- Canonically replaces the isolated `RaceTransitionClient_Active`.
- Removes the client-side `vehicle:PivotTo(resetCFrame)` reset step.
- On `TimeTrialReset` / `RaceReset`, the transition client:
  - keeps the fade/camera/HUD behavior;
  - clears local vehicle momentum over a short settle window;
  - fires the existing `FreeRoamVehicleSpawned` driving handoff once after the server reset so `yawHeading` is rebuilt from the current root orientation.
- Patches only the reset pivot helpers in:
  - `TimeTrialService_Active`;
  - `RaceMatchmakingService_Active`.
- The server reset helper now briefly gives network ownership back to the server, anchors the root during the pivot, zeroes velocity, seats the player, then releases the vehicle through the normal driving preparation path.

It does not edit reward config, route-guide config, checkpoint visuals, route attributes, or the register-limited main client bootstrap.

## Install

Run this in Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_racing_phase8e_reset_handoff_yaw_sync.lua
```

The script supports:

```lua
local MODE = "INSTALL" -- INSTALL or SMOKE
```

## Verification

1. Restart Play after install.
2. Start a time trial and drive through at least one checkpoint.
3. Turn the car away from the route direction, then press `RESET TO LAST CHECKPOINT`.
4. Confirm the car becomes stationary and faces the checkpoint/reset pose direction, not the direction it was facing before reset.
5. Repeat before checkpoint 1 and confirm the start reset still faces the start/first gate correctly.
6. Run a 2-player local race and confirm one player's reset does not disturb the other player's vehicle.
7. Confirm Output includes:

```text
[NTR Racing Phase 8E] Fired driving yaw sync after reset
```

## Risks

- Superseded: Phase 8E reused the full `FreeRoamVehicleSpawned` / `startDriving` handoff to resync yaw. Testing showed that was too broad during an active reset. Use Phase 8F's yaw-only bridge instead.
- The client yaw sync reuses the existing `FreeRoamVehicleSpawned` handoff because the driving controller's `yawHeading` is local to the register-limited bootstrap. This avoids adding another bootstrap bridge, but it may reset transient driving state such as boost/drift charge after a checkpoint reset. If that becomes a competitive issue, the later clean version should expose a tiny table-backed `SyncDrivingYaw` bridge inside the bootstrap instead of restarting the whole driving handoff.
- The server replacements are still guarded source anchors, but they target only isolated Racing service helper functions. If either anchor fails, refresh the mirror and inspect the live service source before another repair.
- A future player-created race editor should prefer explicit per-checkpoint `ResetPose` parts/attachments. This phase still uses the existing checkpoint/start CFrames as the reset pose source.

## Rollback

Use Roblox version history to restore:

- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTransitionClient_Active`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active`

Then rerun the prior confirmed racing baseline if needed.
