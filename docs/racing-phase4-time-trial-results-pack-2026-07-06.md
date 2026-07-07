# Racing Phase 4 Time Trial Results Pack

**Created:** 2026-07-06  
**Script:** `scripts/roblox_racing_phase4_time_trial_results_pack.lua`  
**Status:** Generated in Git for Studio install/testing.

## Purpose

Phase 4 builds on the confirmed Phase 3E staged time-trial flow and adds the non-economy finish loop:

```text
Finish line
  -> server medal calculation
  -> split/personal-best payload
  -> themed result panel
  -> Retry or Exit
```

It intentionally does not grant cash, write DataStores, add route arrows, or add multiplayer matchmaking.

## What It Changes

The installer patches only isolated Racing scripts:

```text
ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active
```

It also sets lightweight config attributes under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.UI
```

## Server Behavior

`TimeTrialService_Active` now:

- calculates `Bronze`, `Silver`, `Gold`, or `Platinum` from `RaceConfigReader.GetTimeTrialMedals(eventId, vehicleTier)`;
- sends checkpoint split times to the client;
- tracks in-session personal bests per player, event, and vehicle tier;
- includes medal, next-medal target, personal-best, vehicle tier/index, selected vehicle id, and splits in `TimeTrialFinished`;
- keeps reward/cash grants deferred until the later guarded Rewards Pack.

Personal bests are intentionally session-only in this phase. Persistent bests should wait until the profile bridge path is clean and does not require fragile garage-controller edits.

## Client Behavior

`RaceEntryMenuClient_Active` now:

- shows a centered themed result panel at finish;
- displays medal, final time, personal best, next medal target, and first few splits;
- adds `RETRY`, which restages the same event with the same selected vehicle id;
- adds `EXIT`, which hides the result/HUD and returns the player to free roam presentation.

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase4_time_trial_results_pack.lua
```

3. Leave:

```lua
local MODE = "INSTALL"
```

4. Restart Play after install.

Optional read-only check:

```lua
local MODE = "AUDIT"
```

## Verification

In Play:

1. Drive into a race/time-trial start zone.
2. Press `E` or tap the prompt.
3. Start a time trial with an owned vehicle.
4. Finish the route.
5. Confirm the result panel appears with medal, time, personal best, next medal target, and splits.
6. Click `RETRY` and confirm the same route restages at the start line with countdown.
7. Finish again and confirm personal best updates only if the second time is faster.
8. Click `EXIT` and confirm the race HUD/result panel closes and free-roam visibility/control remains normal.

## Expected Output

Install should print lines similar to:

```text
[NTR Racing Phase 4] Patched TimeTrialService_Active with medal calculation, splits, and in-session personal bests.
[NTR Racing Phase 4] Patched RaceEntryMenuClient_Active with finish results UI and retry/exit buttons.
```

If the script aborts with a missing source anchor, do not run another guessed repair. Refresh the Studio mirror and inspect the current `TimeTrialService_Active` / `RaceEntryMenuClient_Active` source first.

## Rollback

Use Roblox version history, or rerun the current Phase 3 installer to canonically replace the isolated Racing service/client back to the Phase 3E baseline:

```text
scripts/roblox_racing_phase3_entry_menu_staging_session.lua
```

Then restart Play.

## After Confirmation

Because this phase changes live Studio scripts and config attributes, refresh the Studio mirror after the phase is installed and tested:

```text
py scripts/receive_studio_full_snapshot_export.py
```

Then run this in the Roblox Studio Command Bar:

```text
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

Do not commit `docs/studio-full-export-paste.txt`.
