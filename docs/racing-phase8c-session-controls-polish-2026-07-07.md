# Racing Phase 8C Session Controls Polish

**Script:** `scripts/roblox_racing_phase8c_session_controls_polish.lua`  
**Status:** Installed, but transition/camera issues remain and should be handled by Phase 8D
**Scope:** Race/time-trial exit, reset-to-last-checkpoint, and first-start staging handoff polish

## Purpose

Phase 8C keeps the working Phase 8B race loop intact while fixing the rough session controls:

- add a small in-session `RESET TO LAST CHECKPOINT` / `EXIT TO START` control panel;
- make exits return the player to the route start teleport point and despawn the race/time-trial vehicle safely;
- reset vehicles server-side to the last completed checkpoint, or the start grid before checkpoint 1;
- stop the entry menu from firing the free-roam driving handoff immediately after selected-vehicle spawn.

The first-start camera/spawn spin was likely caused by that early handoff running before Racing teleported/froze/released the car. Testing after the Phase 8C fix showed this was incomplete: first start still has the issue, and quitting can leave the local camera fixed at the old race location after the server despawns/teleports correctly.

Treat the remaining issue as a broader session transition/camera ownership problem. The next planned phase is Phase 8D (`docs/racing-phase8d-session-transition-camera-fade-plan-2026-07-07.md`), which should rename the quit button, restore camera state, add fade transitions, and hide free-roam HUD during active sessions.

## What It Installs/Patches

- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionControlsClient_Active`
- guarded patch to `RaceEntryMenuClient_Active`
  - removes the pre-staging `FreeRoamVehicleSpawned` fire from both race and time-trial selected-vehicle start paths;
- guarded patch to `TimeTrialService_Active`
  - adds `ResetActiveTimeTrial`;
  - adds `ExitActiveTimeTrial`;
  - tracks the last completed gate;
  - stages the first start facing the first route gate;
- guarded patch to `RaceMatchmakingService_Active`
  - adds `ResetToLastCheckpoint`;
  - adds `ExitRaceToStart`;
  - tracks each racer’s last completed gate;
  - stages race starts facing the first route gate.

It does not edit reward config, route-guide config, payout logic, VFX, driving physics, dealership/customisation, or the register-limited main bootstrap.

## Verification

Run in Studio Edit mode:

```text
scripts/roblox_racing_phase8c_session_controls_polish.lua
```

Then restart Play.

Time trial checks:

1. Start a time trial from first launch, not Retry.
2. Confirm the car stages at the start line facing the route cleanly and the camera does not spin around.
3. After `GO`, confirm the car is drivable.
4. Press `RESET TO LAST CHECKPOINT` before checkpoint 1 and confirm the vehicle returns to the start.
5. Pass a checkpoint, press reset again, and confirm the vehicle returns near the last completed checkpoint facing the next gate.
6. Press `EXIT TO START` and confirm the player returns to the route teleport/start location, the race HUD clears, and the race vehicle despawns.

Race checks:

1. Start a 2-player local server race.
2. Confirm both racers stage cleanly and are drivable at `GO`.
3. Confirm each player sees the session control panel.
4. Press reset during the race and confirm only that player’s vehicle returns to their last completed checkpoint/start.
5. Press `EXIT TO START` for one racer and confirm they leave the race, their vehicle despawns, and the other racer can continue.
6. Confirm route-guide/reward config values remain unchanged.

## Risks

- This phase uses guarded exact source patches against isolated Racing scripts. If an anchor fails, refresh the Studio mirror before another repair.
- The first generated installer could abort with `Could not find second source anchor: pre-stage handoff block`. The updated installer fixes the root cause by handling the race and time-trial pre-stage handoff blocks separately; they contain the same logic, but the time-trial branch is indented one level differently.
- Phase 8C did not fully solve the first-start camera/spawn issue. Do not assume removing the early handoff is sufficient; Phase 8D needs camera-state diagnostics and explicit camera restoration.
- Reset currently has no time penalty. That is intentional for this polish phase; a future competitive phase should add a configurable reset penalty for races and possibly for time-trial best validation.
- Exit does not show a time-trial medal/prize summary yet. That belongs with the Gran Turismo-style lap/infinite time-trial session phase.

## Rollback

Restore these scripts from Roblox version history:

- `RaceEntryMenuClient_Active`
- `TimeTrialService_Active`
- `RaceMatchmakingService_Active`

Then disable or delete:

- `RaceSessionControlsClient_Active`
