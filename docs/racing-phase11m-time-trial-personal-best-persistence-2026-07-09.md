# Racing Phase 11M Time Trial Personal Best Persistence

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11m_time_trial_personal_best_persistence.lua`  
**Type:** Focused Studio Command Bar install

## Purpose

Phase 11M adds the first persistent competitive record slice for time trials: saved personal bests per player, event, and vehicle tier.

This comes after Phase 11L was confirmed working. It intentionally does not add global leaderboards, friends leaderboards, ghosts, ranked logic, or private servers yet.

## What It Adds

- `ServerScriptService.NeoTokyoRacers.Services.Racing.RacePersonalBestService_Active`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.RacePersonalBestBindings`
  - `RecordTimeTrialBest`
  - `GetTimeTrialBest`
  - `SavePlayer`
- `ReplicatedStorage.NeoTokyoRacers.Config.Racing.PersonalBests`
  - `DataStoreEnabled` default `false`
  - `DataStoreName` default `NTR_TimeTrialPersonalBests_v1`
  - `SaveDebounceSeconds` default `6`

`TimeTrialService_Active` is patched so `sendTimeTrialResult()` records the result through the PB service before reward calculation. The PB service returns:

- previous best;
- current best;
- whether the latest run is a new PB.

The existing results UI already reads those fields, so no UI layout patch is needed for this phase.

## Why DataStore Defaults Off

This matches the existing project persistence style: Studio/prototype testing should be safe by default.

With `DataStoreEnabled = false`, PBs are session-only but still go through the same server service path. To test true cross-session persistence, enable Studio API services and set:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.PersonalBests.DataStoreEnabled = true
```

## What It Does Not Change

- Reward config.
- Race rewards.
- Route-guide config.
- Arrow/barrier folders.
- Matchmaking.
- Visibility/VFX isolation.
- Driving physics.
- Main bootstrap.
- Global/friends leaderboards.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11m_time_trial_personal_best_persistence.lua
```

Restart Play after installing.

## Verification

Session-only verification:

1. Finish a time trial and note the result.
2. Retry or start again with a slower time.
3. Confirm the results panel keeps the first PB rather than replacing it.
4. Run faster than the stored PB.
5. Confirm the result panel says `NEW PERSONAL BEST`.
6. Confirm rewards still use the correct PB/repeat behavior.

Optional DataStore verification:

1. Enable Studio API services.
2. Set `Config.Racing.PersonalBests.DataStoreEnabled.Value = true`.
3. Finish a time trial.
4. Stop and restart Play.
5. Finish a slower run on the same event/tier.
6. Confirm the previous saved PB is still shown.

## Rollback

Use Roblox version history, or remove/disable `RacePersonalBestService_Active` and restore `TimeTrialService_Active` from the previous Studio version.

## Next

After Phase 11M is confirmed, the next safe competitive phase is a small time-trial leaderboard/readout layer: either a local PB display in the entry/results UI, or an OrderedDataStore global leaderboard if DataStore behavior is confirmed.
