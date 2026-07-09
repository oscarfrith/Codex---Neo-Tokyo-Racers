# Racing Phase 11K Time Trial Result Exit Cleanup

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11k_time_trial_result_exit_cleanup.lua`  
**Type:** Small guarded Studio Command Bar repair

## Purpose

Phase 11K fixes a post-finish cleanup gap found during 2-player prototype testing.

Symptom:

- One player finished a time trial and exited after receiving Silver.
- After exit, that player could not re-enter the race, could not spawn a free-roam vehicle because the game reported no nearby spawns, and the Race browser teleport button did not move them.
- The other test player did not hit the issue.

Likely root:

- `finishRun()` removes the active time-trial run immediately after a valid finish.
- The result-panel `EXIT` button then calls `CancelTimeTrial`.
- Because the active run is already gone, the old cancel path can hide the result UI without running the proper result-exit cleanup: destroy finished race vehicle, teleport character back to the route start/teleport point, and send a `TimeTrialEnded` cleanup event.

## What It Changes

- Adds a small `finishedRunsByPlayer` cache inside `TimeTrialService_Active`.
- Stores the finished run until the player presses result-panel `EXIT`.
- Adds `ExitFinishedTimeTrial` as a server action.
- Makes `CancelTimeTrial` fall back to finished-run cleanup if no active run exists.
- Clears any stale finished-run cleanup record when a new time trial starts, so `RETRY` cannot inherit the previous result state.
- Updates the result-panel `EXIT` button in `RaceEntryMenuClient_Active` to call `ExitFinishedTimeTrial` first, with the old cancel action as fallback.

## What It Does Not Change

- Reward config.
- Route-guide config.
- Arrow/barrier segment folders.
- Matchmaking.
- VFX isolation.
- Driving physics.
- Personal-best persistence.

## How To Verify

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11k_time_trial_result_exit_cleanup.lua
```

Restart Play and test with two local players:

1. Player A starts and finishes a time trial.
2. Player A presses `EXIT` on the result panel.
3. Confirm Player A fades/returns to the route teleport/start location.
4. Confirm Player A can open the start-zone menu again.
5. Confirm Player A can spawn a free-roam vehicle from the car menu if near a valid road spawn.
6. Confirm Player A can use the Race browser `TELEPORT TO START`.
7. Repeat with Player B to check the cleanup is per-player.

## Notes

This is a guarded source-anchor repair against two isolated Racing scripts. If it reports a missing source anchor, refresh the Studio mirror before another repair.

After Phase 11K is confirmed, the next recommended feature phase remains time-trial personal-best persistence.
