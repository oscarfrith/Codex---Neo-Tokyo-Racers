# Racing Phase 11Z - Post-11Y Release Candidate Audit

**Script:** `scripts/roblox_racing_phase11z_post_11y_release_candidate_audit.lua`  
**Type:** Read-only audit  
**Status:** Generated for Studio audit/testing  
**Date:** 2026-07-10

## Purpose

Phase 11Z is the release-candidate audit after the confirmed Phase 11Y lifecycle recovery.

It does not install a new feature. It checks that the racing prototype still has the expected remotes, config, services, route structure, PB/reward systems, route arrows, collision groups, result UI, and the new 11Y finish-cleanup safeguards.

## What It Adds Over 11X

- Checks `TimeTrialService_Active` for `NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY`.
- Checks `RaceTimeTrialResultCoachClient_Active` for `NTR_RACING_PHASE11Y_RESULT_COACH_CONFIRMED_EXIT`.
- Audits `Runtime.PlayerVehicles` for stale or unsafe race vehicles:
  - pending finished TT vehicles must be drive-disabled;
  - pending finished TT vehicles must not keep `DriverUserId`;
  - orphan grid-spawned vehicles outside pending cleanup are failures;
  - in Play-client context, the local player must not still be seated in a finished-pending TT vehicle.

## How To Run

Run in Studio Command Bar:

```text
scripts/roblox_racing_phase11z_post_11y_release_candidate_audit.lua
```

Recommended sequence:

1. Run once in Edit mode.
2. Restart Play.
3. Finish and exit the same solo time trial at least three times.
4. Run the audit from the Play client after the final exit.
5. Run a 2-player same-server race smoke, finish/exit, and run the audit again from the Play client.

## Interpreting Results

`fail=0` is the gate.

Expected warnings can include:

- server checks skipped from a Play client;
- runtime collision groups missing in Edit mode before services start;
- no PBs found for a player that has no saved PB in the selected store;
- `RaceInstances` or pending finished vehicles while a result panel/session is still genuinely active.

Unexpected failures include:

- missing 11Y source markers;
- pending finished TT vehicles still drive-ready;
- pending finished TT vehicles still holding `DriverUserId`;
- orphan grid-spawned race vehicles after exit cleanup;
- local player still seated in a finished-pending TT vehicle.

## Next Step After Pass

After Phase 11Z passes in Edit and after repeated solo/multiplayer smoke tests, the racing prototype is safe to branch into one of:

- small racing UI/flow polish;
- multiplayer race reliability/balance;
- leaderboard/ghost planning;
- or another focused feature branch.

Private/reserved servers and player-created race tooling remain deferred larger systems.
