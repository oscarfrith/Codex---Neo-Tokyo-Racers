# Racing Phase 11W Time Trial PB DataStore Verification

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11w_time_trial_pb_datastore_verification.lua`  
**Type:** Config/audit helper

**V2 note:** The first audit treated missing `RacePersonalBestBindings` as Edit-mode failures. Those BindableFunctions are created by `RacePersonalBestService_Active` when Play/runtime starts, so V2 reports them as expected Edit-mode warnings and keeps binding checks for Play/server context.

## Purpose

Phase 11W verifies the Phase 11M/N/O time-trial personal-best persistence path without adding more gameplay code.

The default mode is read-only. DataStore writes are only enabled if the script is deliberately changed to `MODE = "ENABLE_DATASTORE_TEST"`.

## What It Checks

- `Config.Racing.PersonalBests` exists and has:
  - `DataStoreEnabled`
  - `DataStoreName`
  - `SaveDebounceSeconds`
- `RacePersonalBestService_Active` exists and still has the Phase 11M markers.
- In Play/server context, `RacePersonalBestBindings` has:
  - `RecordTimeTrialBest`
  - `GetTimeTrialBest`
  - `SavePlayer`
- `TimeTrialService_Active` still records and exposes PB lookups.
- In Play mode, each loaded player can query PBs for `shifted_canal_sprint_tt` tiers `E` through `S`.
- In Play server context, the forced save binding returns a clear success/warning message.
- In Play client context, PB lookup uses the same `RaceRequest` remote action as the UI because server-only bindings are not replicated to clients.

## Modes

Default:

```lua
local MODE = "AUDIT"
```

Read-only. Use this first in Edit mode and again from Play.

Enable saved PB testing:

```lua
local MODE = "ENABLE_DATASTORE_TEST"
```

This sets `PersonalBests.DataStoreEnabled = true`. By default it also changes the store name to:

```text
NTR_TimeTrialPersonalBests_StudioTest_v1
```

That keeps prototype Studio testing away from the production-looking default store name.

Disable saved PB testing:

```lua
local MODE = "DISABLE_DATASTORE_TEST"
```

This sets `PersonalBests.DataStoreEnabled = false` again.

## How To Verify Save/Rejoin

1. Run the script in Edit mode with `MODE = "AUDIT"`.
2. Change `MODE` to `ENABLE_DATASTORE_TEST`, run it once in Edit mode, then restart Play.
3. Make sure Studio API Services are enabled in Game Settings.
4. Finish a time trial with a new PB.
5. Check Output for Phase 11M PB service save messages or run 11W in Play mode with `MODE = "AUDIT"`.
6. Leave Play, start a new Play session, open the race menu, and confirm the PB card/board still shows the saved result.
7. Run 11W in Play mode again and confirm it reports the saved tier PB.
8. If this was only a prototype test, change `MODE` to `DISABLE_DATASTORE_TEST`, run it in Edit mode, then restart Play.

## Expected Warnings

- In local server tests with negative Studio UserIds, DataStore saves are skipped by design.
- If Studio API Services are off, DataStore load/save may warn even when the session-only PB path works.
- If no PB exists yet for a tier, the audit reports that tier as healthy but empty.
- From the Play client, forced-save binding checks are skipped. Use the server Output plus the leave/rejoin smoke for the true save confirmation.
- In Edit mode before Play starts, missing `RacePersonalBestBindings` is expected because the PB service creates those bindings at runtime.

## What It Does Not Change

Phase 11W does not edit gameplay scripts, UI, rewards, route-guide config, route arrows, collisions, driving, VFX, matchmaking, or the main bootstrap.

## Next Step After Pass

After save/rejoin is confirmed, the safer next branch is broader race/time-trial polish and multiplayer regression testing. Global/friends leaderboards, ghosts, ranked seasons, and reserved-server race matchmaking should remain deferred until the local PB save path is boringly reliable.
