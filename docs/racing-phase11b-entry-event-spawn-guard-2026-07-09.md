# Racing Phase 11B - Entry Event Pairing And Spawn Guard

Generated: 2026-07-09

## Purpose

Phase 11B fixes two entry-flow problems seen after Phase 11A testing:

- `START RACE` could send the time-trial event id, such as `shifted_canal_sprint_tt`, into race matchmaking.
- Starting a race/time trial could unnecessarily run the free-roam garage spawn path before the racing service accepted and staged the session.

## Studio Script

Run in Edit mode:

```text
scripts/roblox_racing_phase11b_entry_event_and_spawn_guard.lua
```

## What It Changes

- Adds a client-side `raceEventIdForStart()` helper.
- Stores `RaceEventId` separately from `TimeTrialEventId` when available.
- If the menu was opened from a time-trial event, `START RACE` derives the paired `_race` event id.
- Validates the race event before any garage spawn/select action.
- Skips the garage respawn path when the selected card is already the current vehicle.
- Applies the same current-vehicle respawn skip for time trials.

## What It Does Not Fully Solve Yet

If the player chooses a different owned vehicle, the current flow still uses the existing garage spawn/swap path before staging.

The cleaner future phase is a server-side staging spawn:

- client sends `VehicleId` only;
- race/time-trial service validates ownership and event first;
- selected vehicle is spawned directly at the race grid/start line;
- no free-roam/customisation fallback spawn is involved.

That should be done as a separate phase because it changes ownership between Racing services and the Garage spawn system.

## Verification

1. Open the race menu from both race and time-trial start zones.
2. Press `START RACE` and choose the current vehicle.
3. Confirm matchmaking no longer says `Race event not found: shifted_canal_sprint_tt`.
4. Confirm the current vehicle is not respawned outside customisation/free roam before queueing.
5. Press `START TIME TRIAL` with the current vehicle and confirm it stages directly at the race start.
6. Try choosing a different vehicle and note whether the existing garage swap path still feels disruptive; if so, prioritize the server-side staging spawn phase next.
