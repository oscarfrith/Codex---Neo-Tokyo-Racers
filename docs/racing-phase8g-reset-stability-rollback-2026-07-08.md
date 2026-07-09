# Racing Phase 8G Reset Stability Rollback

**Script:** `scripts/roblox_racing_phase8g_reset_stability_rollback.lua`  
**Status:** Generated after Phase 8F still produced car/camera/streaming breakage on reset  
**Scope:** Restore stable reset behavior before continuing checkpoint-facing polish

## Why This Phase Exists

Phase 8F proved the yaw-only bridge fired successfully:

```text
[NTR Racing Phase 8F] Requested yaw-only driving sync after reset
[NTR Racing Phase 8F] Synced driving yaw only after reset.
```

But the car still shut off and the world still went low-res/weird. That means the reset instability is not only the yaw-sync bridge. The current reset flow still has too many actors touching the vehicle at once:

- the server reset moves/reseats/releases the vehicle;
- the reset button fires a direct `StopVehicle` transition;
- the reset event also makes the transition client stop/zero the vehicle;
- Phase 8E may still be present in live Studio and briefly server-own/anchor the vehicle root during reset.

Phase 8G rolls this back to the safer principle:

> The server owns reset movement. The client only handles fade/camera/HUD presentation.

This may bring back the less serious checkpoint-facing issue, but it should stop the car/camera/world breakage first.

## What It Changes

- Replaces `RaceTransitionClient_Active` with a Phase 8G version that:
  - does not zero vehicle velocity;
  - does not fire yaw sync;
  - does not request streaming;
  - ignores `StopVehicle` transition requests;
  - only handles fade, HUD suppression, and camera restore.
- Restores the bootstrap `FreeRoamVehicleSpawned` connection if the Phase 8F yaw-only bridge is present.
- Rolls back `TimeTrialService_Active` / `RaceMatchmakingService_Active` reset helpers if the Phase 8E anchored/network-owner handoff is present.
- Removes the duplicate `StopVehicle` call from the reset button path in `RaceSessionControlsClient_Active`.
- Keeps the cleaner Phase 8F button text style if already installed.

## Install

Run this in Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_racing_phase8g_reset_stability_rollback.lua
```

The script supports:

```lua
local MODE = "INSTALL" -- INSTALL or SMOKE
```

## Verification

1. Restart Play after install.
2. Start a time trial and pass a checkpoint.
3. Press `RESET TO LAST CHECKPOINT`.
4. Confirm the vehicle remains drivable, camera stays attached, and the world does not go low-res/weird.
5. Confirm Output does **not** include:

```text
Local reset momentum stop
Requested yaw-only driving sync
Synced driving yaw only after reset
```

6. Confirm Output may include:

```text
[NTR Racing Phase 8G] Ignored StopVehicle transition; server owns reset movement.
```

7. Once reset stability is confirmed, checkpoint-facing can be redesigned with a safer reset-pose system rather than more live vehicle handoff patches.

## Risks

- The car may again face its pre-reset direction or otherwise not perfectly match checkpoint orientation. That is acceptable for this rollback phase; stability comes first.
- If live Studio source differs from the mirror and a source anchor fails, stop and refresh the mirror before another repair.
- The better future fix is likely dedicated per-checkpoint `ResetPose` parts plus an explicit driving-controller API, not more transition-client vehicle manipulation.

## Rollback

Use Roblox version history to restore:

- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTransitionClient_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionControlsClient_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active`
