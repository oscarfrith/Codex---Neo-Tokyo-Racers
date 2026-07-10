# Racing Phase 11U Time Trial HUD Exit Cleanup

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11u_time_trial_hud_exit_cleanup.lua`  
**Type:** Isolated client cleanup phase

## Purpose

Phase 11U fixes the leftover top time-trial HUD card that can remain visible after using the Phase 11T result coach `EXIT TO START` button.

The screenshot showed the old `NTR_RaceHud_Phase3.Panel` still displaying the finished time and payout after exit. Phase 11T's result coach worked, but the older session HUD needed an extra local cleanup signal.

V2 narrows the cleanup after testing showed the first version was too broad: it could hide the legacy medal/result fallback panel, which could leave no result UI and block proper result exit cleanup if Phase 11T was not visible on that client.

## What It Changes

Creates/replaces only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceHudExitCleanupClient_Active
```

The cleanup client:

- listens to racing finish/end/error/exit events;
- listens to the existing `FreeRoamVehicleExited` bindable handoff;
- hides only the old top `NTR_RaceHud_Phase3.Panel` locally;
- never hides medal/result/exit panels;
- repeats the hide a few times over less than one second so late UI updates are caught.

## What It Does Not Change

- Time-trial timing.
- Rewards or reward config.
- PB persistence/readouts.
- Route guide or arrows.
- Session assets/collision.
- VFX/name-tag visibility.
- Matchmaking.
- Driving physics.
- The main bootstrap.
- `RaceEntryMenuClient_Active`.
- `RaceTimeTrialResultCoachClient_Active`.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11u_time_trial_hud_exit_cleanup.lua
```

Restart Play after installing.

## Verification

1. Finish a time trial.
2. Confirm the Phase 11T result coach appears.
3. Press `EXIT TO START`.
4. Confirm the medal/result UI remains visible.
5. Press `EXIT TO START`.
6. Confirm the old top timer/result card disappears.
7. Confirm vehicle HUD stays cleared.
8. Confirm the player can re-enter the race menu, teleport from the Race browser, and start another time trial.

## Rollback

Disable or delete:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceHudExitCleanupClient_Active
```

This returns behavior to the Phase 11T baseline.
