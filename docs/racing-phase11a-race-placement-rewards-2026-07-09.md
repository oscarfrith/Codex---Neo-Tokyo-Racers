# Racing Phase 11A - Race Placement Rewards

Generated: 2026-07-09

## Purpose

Phase 11A completes the deferred multiplayer race reward loop.

Races are still open-category at launch, but payout is based on finishing place:

- `Gold`: place `1`
- `Silver`: place `2`
- `Bronze`: place `3`
- no cash by default outside bronze placement

The exact place thresholds and multipliers already live in:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.Rewards.Race
```

This phase reads that config and does not change reward values.

## Studio Script

Run in Edit mode:

```text
scripts/roblox_racing_phase11a_race_placement_rewards.lua
```

Use `MODE = "INSTALL"` to install and `MODE = "SMOKE"` for a read-only source marker check.

If the first install reports this Play compile error:

```text
RaceMatchmakingService_Active:<line>: Expected <eof>, got 'end'
```

run this repair in Edit mode:

```text
scripts/roblox_racing_phase11a_race_matchmaking_parse_repair.lua
```

The repair removes any partial Phase 11A race-reward fragment from `RaceMatchmakingService_Active` and installs one canonical reward-enabled `finishEntry` block.

## What It Changes

- Replaces the isolated `RaceRewardService_Active` with a Phase 11A version that keeps time-trial rewards and adds `GrantRaceReward`.
- Adds a small reward bridge to `RaceMatchmakingService_Active`.
- Grants race cash once per player per race run when the player finishes.
- Sends `RaceMedal`, `RewardGranted`, `RewardAmount`, and `RewardMessage` in the existing `RaceFinished` payload.
- Updates `RaceQueueClient_Active` so the race finish panel shows the medal/reward line instead of the old deferred-reward copy.

## What It Does Not Change

- No reward config values are changed.
- No route-guide config is changed.
- No route arrows, barriers, checkpoints, or reset behavior are changed.
- No DataStore leaderboard work is added yet.
- No race tier brackets are added.

## Verification

1. Run the script in Studio Edit mode.
2. Restart Play with a local server.
3. Queue and finish a race.
4. Confirm the finish panel shows `Gold`, `Silver`, or `Bronze` and a reward line.
5. Confirm `leaderstats.Cash` increases once for the finisher.
6. Confirm rerunning finish/cleanup does not grant duplicate cash for the same player/run.
7. Confirm time-trial rewards still work.
8. Confirm `Config.Racing.Rewards.Race` values are unchanged.

## Rollback

Disable or replace:

- `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceRewardService_Active`
- the Phase 11A reward bridge markers in `RaceMatchmakingService_Active`
- the Phase 11A reward UI marker in `RaceQueueClient_Active`

The safest rollback is Roblox Studio version history because the phase touches live script source.
