# Racing Phase 8D Session Transition Camera Fade Plan

**Status:** Generated for Studio install as `scripts/roblox_racing_phase8d_session_transition_camera_fade.lua`  
**Scope:** Race/time-trial camera restore, quit wording, HUD suppression, and fade transitions

## Why This Phase Exists

Phase 8C repaired the session control installer and added reset/exit actions, but testing showed the original first-start camera issue still persists. `QUIT` also teleported/despawned correctly on the server while the local camera stayed fixed at the old race location.

That means the remaining problem is probably not only the pre-start free-roam driving handoff. It is a broader session transition/camera ownership issue, so the next phase should repair the transition layer before adding laps, infinite time trials, or session assets.

## Generated Scope

- Rename `EXIT TO START` to `QUIT RACE`.
- Add a quick fade-to-black/unfade around:
  - start staging;
  - reset to checkpoint;
  - quit race/time trial;
  - free-roam Race browser teleport-to-start;
  - future race-pocket/session teleports.
- The generated installer has been tuned so the black hold lasts slightly longer than the first Phase 8D pass. This gives server teleport/despawn/reset a cleaner moment to settle before the view returns.
- Restore camera cleanly after quit/reset/start transitions:
  - reset `CurrentCamera.CameraType` to `Custom`;
  - set a valid `CameraSubject` after the player/vehicle has moved;
  - clear any race-specific camera state that could leave the camera pinned.
- Hide free-roam nav HUD, free-roam car menu, and free-roam `EXIT VEHICLE` HUD during active race/time-trial sessions.
- Reset-to-checkpoint also re-zeroes vehicle velocity shortly after the server driving handoff. After the first server-only attempt still allowed client-owned vehicle momentum to carry through, the generated installer now also makes `RaceTransitionClient_Active` clear the local owner's vehicle velocity repeatedly for a short settle window after `TimeTrialReset` / `RaceReset`.
- Reset-to-checkpoint facing now uses the completed checkpoint part's authored `CFrame` instead of looking toward the next checkpoint. After the first server-only facing patch did not change live behavior, the reset payload now also sends `ResetCFrame` to the local transition client so the client-owned vehicle applies the checkpoint-facing pivot. Do this pivot once, then only clear velocity during the settle window; repeated pivots while hover physics wakes up can inject spin. Rotate checkpoint parts in Studio to control how cars face after reset.
- Keep driving-critical HUD/controls visible during a run, especially MPH, boost, and mobile controls.
- Add small diagnostics/smoke output for camera type/subject before and after start/reset/quit.

## Implementation Shape

- Install isolated `RaceTransitionClient_Active`; do not add bulky code to the register-limited bootstrap.
- Canonically replace the small isolated `RaceSessionControlsClient_Active`.
- Add `RaceTransitionRequest` / `RaceTransitionStateChanged` BindableEvents under the existing Racing client folder.
- Use a guarded exact source patch only for `RaceBrowserClient_Active` so `TELEPORT TO START` can use the same fade pattern.
- Drive presentation from existing Racing session events instead of per-frame polling.
- Use local fade/HUD/camera handling for presentation.
- Keep server-side movement/despawn authoritative; client fade should not be trusted for validation.
- Do not edit reward config, route-guide config, checkpoint timing, or route attributes.

## Install

Run this in Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_racing_phase8d_session_transition_camera_fade.lua
```

The script supports:

```lua
local MODE = "INSTALL" -- INSTALL or SMOKE
```

The browser teleport fade hook is intentionally guarded and source-anchor based. If it fails, refresh the Studio mirror and inspect `RaceBrowserClient_Active` before another repair.

## Verification

1. Start a first-launch time trial and confirm the camera no longer spins or pins awkwardly.
2. Start a multiplayer race and confirm staging/countdown/GO camera behavior is clean for both players.
3. Press `RESET TO LAST CHECKPOINT` and confirm fade, teleport, camera, controls recover, the vehicle is stationary, and the vehicle faces the same direction as the checkpoint part.
4. Press `QUIT RACE` and confirm fade, vehicle despawn, start teleport, camera restore, HUD cleanup, and unfade.
5. Confirm free-roam nav and free-roam `EXIT VEHICLE` are hidden while racing and return after quitting/finishing.
6. Confirm mobile driving controls, MPH, and boost remain available while racing.
7. Use the Race browser `TELEPORT TO START` and confirm it uses the same fade pattern.

## Deferred

- Lap selection `1-10` plus infinite time trials.
- Quit-time medal/prize summary.
- Server-side session blockers/collision assets.
- Race rewards.
