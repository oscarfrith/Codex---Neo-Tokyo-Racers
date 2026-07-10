# Racing Phase 11R Time Trial Exit Handoff Helper Repair

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11r_time_trial_exit_handoff_helper_repair.lua`  
**Type:** Guarded isolated-client source-shape repair

## Purpose

Phase 11Q was confirmed working by the user, and the Studio mirror was refreshed afterwards. The refreshed mirror showed the Phase 11Q helper marker and `local clientRoot` collapsed onto one comment line inside `RaceEntryMenuClient_Active`.

That malformed source shape could stop the helper from finding `FreeRoamVehicleExited` in future edge cases, even though the immediate playtest recovered the flow.

Phase 11R fixes only that helper formatting.

## What It Changes

Patches only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active
```

It replaces the malformed helper:

```text
-- NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF local clientRoot = ...
```

with the intended helper:

```text
-- NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF
local clientRoot = script.Parent.Parent
```

## What It Does Not Change

- Time-trial timing.
- Result panel design/copy.
- Rewards or reward config.
- PB recording/storage.
- Route-guide config.
- Arrow/session asset visibility or collision.
- VFX/name-tag visibility.
- Matchmaking.
- Driving physics.
- DataStore settings.
- Main bootstrap.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11r_time_trial_exit_handoff_helper_repair.lua
```

Restart Play after installing.

## Verification

1. Finish a time trial.
2. Confirm the result panel appears.
3. Press result `EXIT`.
4. Confirm the vehicle HUD clears.
5. Confirm Race browser teleport still works.
6. Confirm the player can enter/start another race or time trial.

## Risk Notes

This is a very small source-shape repair, but it still uses an exact source anchor. If Studio reports a missing anchor, stop and inspect the live mirror before patching again.

## Rollback

Use Roblox Studio version history, or rerun the last confirmed `RaceEntryMenuClient_Active` baseline.
