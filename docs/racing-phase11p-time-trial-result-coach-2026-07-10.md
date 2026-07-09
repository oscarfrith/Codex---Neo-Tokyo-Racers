# Racing Phase 11P Time Trial Result Coach

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11p_time_trial_result_coach.lua`  
**Type:** Guarded isolated-client source patch

## Purpose

Phase 11P improves the time-trial result panel so players get clearer competitive feedback after each run.

This follows the confirmed Phase 11O V2 PB board. It deliberately stays out of DataStore/global leaderboard/private-server scope.

## What It Changes

Patches only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active
```

The result screen now:

- labels the result exit button as `EXIT TO START`;
- shows a new PB with the amount improved when a previous PB exists;
- shows a missed PB with the time gap to the current PB;
- shows next-medal guidance as `NEXT <MEDAL> <target> | NEED -<time>`;
- changes reward wording from `REWARD` to `PRIZE` on the result panel.

## What It Does Not Change

- Time-trial timing.
- PB recording/storage.
- Rewards or reward config.
- Route-guide config.
- Arrow/session asset visibility or collision.
- VFX/name-tag visibility.
- Matchmaking.
- Driving physics.
- DataStore settings.
- Global/friends leaderboards.
- Main bootstrap.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11p_time_trial_result_coach.lua
```

Restart Play after installing.

## Verification

1. Finish a time trial with no previous PB and confirm the result panel still opens cleanly.
2. Finish a faster time trial and confirm `NEW PERSONAL BEST` shows with an improvement delta when available.
3. Finish a slower time trial and confirm the panel shows the gap to the current PB.
4. Confirm the next-medal row shows the target and required time improvement.
5. Confirm the prize text still matches the granted cash amount.
6. Press `EXIT TO START` and confirm the existing clean return-to-start behavior still works.
7. Confirm retry, arrows, rewards, VFX hiding, race queue, and normal time-trial flow still behave as before.

## Risk Notes

This phase uses guarded exact source anchors against the isolated race entry/results client. If Studio says it cannot find an anchor, refresh the mirror and inspect the live `RaceEntryMenuClient_Active` source before writing another patch.

## Rollback

Use Roblox Studio version history, or rerun the last confirmed RaceEntryMenuClient baseline script that installed the current race entry/result UI.

Do not roll back rewards, arrows, VFX, or racing services for this UI-only phase.
