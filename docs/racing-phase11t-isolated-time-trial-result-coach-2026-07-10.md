# Racing Phase 11T Isolated Time Trial Result Coach

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11t_isolated_time_trial_result_coach.lua`  
**Type:** Isolated client feature phase

## Purpose

Phase 11T reintroduces time-trial result polish using the safer architecture learned from Phase 11P/11Q/11R.

Instead of patching `RaceEntryMenuClient_Active` again, it creates a separate local result coach client that listens for `TimeTrialFinished`, hides the old local result panel, and shows a clearer result panel with its own `RETRY` and `EXIT TO START` buttons.

## Why This Shape

Phase 11P tried to polish result text inside `RaceEntryMenuClient_Active`, but testing exposed a finish/exit lifecycle problem. Phase 11Q/11R fixed and confirmed the real lifecycle baseline.

Phase 11T keeps that confirmed baseline untouched.

## What It Changes

Creates/replaces only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTimeTrialResultCoachClient_Active
```

The isolated coach:

- listens to `TimeTrialFinished`;
- fires the existing `FreeRoamVehicleExited` handoff defensively;
- hides the old `NTR_RaceResults_Phase4.Panel` locally;
- shows a clearer local time-trial result panel;
- displays medal, result time, PB/new-PB delta, next-medal target, prize, and recent laps/splits;
- retries through `StartStagedTimeTrial`;
- exits through `ExitFinishedTimeTrial`, falling back to `CancelTimeTrial` if needed;
- hides on staging/start/end/error events.

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
- Confirmed `RaceEntryMenuClient_Active` source.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11t_isolated_time_trial_result_coach.lua
```

Restart Play after installing.

## Verification

1. Finish a time trial.
2. Confirm the new result coach panel appears and the old result panel does not visibly overlap.
3. Confirm medal, result time, PB/new-PB text, next medal, prize, and lap/split rows are readable.
4. Press `EXIT TO START`.
5. Confirm vehicle HUD stays cleared and the player returns to the route start/teleport point.
6. Confirm Race browser teleport and race/time-trial re-entry still work.
7. Finish another time trial and press `RETRY`.
8. Confirm retry stages a new time trial cleanly.

## Risk Notes

This phase intentionally duplicates result-panel controls locally instead of patching the old panel. If both panels ever appear at once, the isolated coach should be adjusted to hide the old panel for longer rather than patching `RaceEntryMenuClient_Active`.

## Rollback

Disable or delete:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTimeTrialResultCoachClient_Active
```

The old confirmed result panel remains in `RaceEntryMenuClient_Active`.
