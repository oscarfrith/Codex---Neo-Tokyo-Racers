# Racing Phase 8H Respawn Reset System

**Script:** `scripts/roblox_racing_phase8h_respawn_reset_system.lua`  
**Status:** Generated after choosing the systematic reset option: respawn-on-reset  
**Scope:** Race/time-trial checkpoint reset stability, momentum clearing, and authored facing

## Why This Phase Exists

The previous reset attempts tried to move the already-running vehicle assembly. That created a tug-of-war between:

- server reset movement;
- client driving heading/momentum state;
- camera subject recovery;
- streaming focus;
- reset transition effects;
- active hover/drive forces.

The user chose the cleaner option: hide reset behind the existing fade, discard the active race vehicle, and spawn a clean replacement at the checkpoint reset pose.

This makes reset behave like a racing checkpoint respawn instead of a live physics teleport.

## What It Changes

- Replaces `RaceTransitionClient_Active` with a presentation-only reset client:
  - fade/camera/HUD only;
  - no local velocity zeroing;
  - no yaw sync;
  - no client-side vehicle movement.
- Removes duplicate client `StopVehicle` from the reset button path if still present.
- Replaces the isolated reset helper in:
  - `TimeTrialService_Active`;
  - `RaceMatchmakingService_Active`.
- On reset, the server:
  - clones the active race vehicle while it still has the selected build/stats/modules;
  - unseats the player;
  - destroys the old active vehicle;
  - parents the clean clone to `Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles`;
  - pivots the clone to the reset CFrame;
  - zeroes all clone velocity;
  - reseats the player;
  - runs the normal race driving preparation;
  - updates the active session's `Vehicle` reference to the replacement.

## Why This Should Fix The Current Problems

- **No momentum after reset:** the old physics assembly is destroyed, so old velocity cannot survive.
- **Correct facing:** the replacement spawns at the reset CFrame instead of being pulled by stale client driving yaw.
- **Camera/streaming stability:** the reset no longer asks the client to poke physics or rerun driving. It only restores camera after the server respawn.
- **Player penalty:** the fade/respawn delay becomes a natural reset penalty.

## Install

Run this in Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_racing_phase8h_respawn_reset_system.lua
```

The script supports:

```lua
local MODE = "INSTALL" -- INSTALL or SMOKE
```

## Verification

1. Restart Play after install.
2. Start a time trial.
3. Drive through a checkpoint with speed.
4. Turn away from the route, then press `RESET TO LAST CHECKPOINT`.
5. Confirm:
   - screen fades during reset;
   - old momentum is gone;
   - vehicle remains drivable;
   - camera stays attached;
   - world does not drop low-res/weird;
   - vehicle faces the checkpoint/reset pose direction.
6. Repeat before checkpoint 1.
7. Repeat in a 2-player local race and confirm only the resetting player's vehicle is replaced.

Expected install/smoke output:

```text
[NTR Racing Phase 8H] Smoke passed: Phase 8H respawn reset system is installed.
```

## Risks

- This clones the current active race vehicle. If future client-only runtime objects ever replicate into the server model, they may be cloned too. Current driving forces are client-created and should not be present on the server clone.
- If a vehicle model has `Archivable = false`, the installer temporarily enables it during clone and restores the old value.
- This does not yet create dedicated `ResetPose` parts. It uses the existing reset CFrame logic, currently checkpoint/start CFrames. A later route-authoring phase should add optional `ResetPose` parts/attachments for exact player-created route control.
- If the car still faces wrong after this phase, the likely issue is authored checkpoint orientation, not reset physics.

## Rollback

Use Roblox version history to restore:

- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTransitionClient_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionControlsClient_Active`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active`
