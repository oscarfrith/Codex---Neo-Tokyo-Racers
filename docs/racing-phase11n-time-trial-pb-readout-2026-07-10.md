# Racing Phase 11N Time Trial PB Readout

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11n_time_trial_pb_readout.lua`  
**Type:** Focused Studio Command Bar feature phase

## Purpose

Phase 11N adds a prototype-safe personal-best readout layer for time trials.

It follows the confirmed Phase 11M personal-best persistence service and the confirmed Phase 11L V2 arrow visibility repair. This is not a global leaderboard phase.

## What It Changes

- Adds a server action on `TimeTrialService_Active`:

```text
GetTimeTrialPersonalBest
```

- The action reads the existing `RacePersonalBestService_Active` binding:

```text
RacePersonalBestBindings.GetTimeTrialBest
```

- Updates `RaceEntryMenuClient_Active` so owned vehicle cards in the time-trial picker show the current PB for that event and vehicle tier.
- Caches PB lookups by `EventId + VehicleTier` so several vehicles in the same tier do not spam the server.
- Updates the selected-vehicle status line with the tier PB.
- Refreshes the local PB cache from the `TimeTrialFinished` payload so a newly set PB is reflected the next time the menu opens.

## What It Does Not Change

- Global OrderedDataStore leaderboards.
- Friends leaderboards.
- Ghosts or replay data.
- Rewards or reward config.
- Route-guide config.
- Arrow/session asset visibility or collision.
- Matchmaking.
- VFX/name-tag visibility.
- Driving physics.
- Main bootstrap.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11n_time_trial_pb_readout.lua
```

Restart Play after installing.

## Verification

1. Open the Race browser or drive to the race start and open the race menu.
2. Choose `START TIME TRIAL`.
3. Confirm owned vehicle cards show `PB --` or `PB <time> / <medal>` based on that vehicle's tier.
4. Select a vehicle and confirm the menu status line includes the same PB readout.
5. Finish a time trial and confirm the result panel still shows the PB.
6. Reopen the time-trial vehicle picker and confirm the new/updated PB appears without needing a server restart.
7. Confirm races, rewards, arrows, VFX hiding, and checkpoint flow still behave as before.

## Notes

This is intentionally local player PB readout only. Global/friends leaderboards should wait until DataStore behavior is tested with `Config.Racing.PersonalBests.DataStoreEnabled = true` and a rejoin check.

## Rollback

Use Roblox version history to restore:

```text
ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active
```

The phase does not create persistent data or config that needs cleanup.
