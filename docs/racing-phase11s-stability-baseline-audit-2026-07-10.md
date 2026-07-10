# Racing Phase 11S Stability Baseline Audit

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11s_stability_baseline_audit.lua`  
**Type:** Read-only Studio Command Bar audit

## Purpose

Phase 11S is a read-only baseline audit after the confirmed Phase 11Q/11R time-trial finish/exit handoff work.

V2 update: if the audit is run from a Play client, server-only `ServerScriptService` checks are skipped with a warning instead of counted as failures. Roblox does not replicate server scripts to clients, so those failures were false negatives.

The goal is to lock the current prototype loop before adding more polish or features:

- time-trial finish;
- reward payout;
- result exit;
- driving HUD/controller cleanup;
- Race browser teleport/re-entry;
- PB readouts/board;
- arrow/session asset visibility baseline;
- multiplayer race matchmaking/reward baseline.

## What It Checks

- Racing remotes:
  - `RaceRequest`
  - `RaceEvent`
  - `RaceQueueEvent`
- Config:
  - `Config.Racing.Rewards`
  - `Config.Racing.PersonalBests`
- Server racing services:
  - `TimeTrialService_Active`
  - `RaceMatchmakingService_Active`
  - `RaceRewardService_Active`
  - `RacePersonalBestService_Active`
  - `RaceSessionAssetService_Active`
- Client racing controllers:
  - `RaceEntryMenuClient_Active`
  - `RaceTransitionClient_Active`
  - `RaceSessionAssetsClient_Active`
  - `RaceParticipantVisibilityClient_Active`
  - `RaceQueueClient_Active`
  - `RacePersonalBestBoardClient_Active`
  - `RaceRouteGuideClient_Active`
- Route structure for `ShiftedCanalSprint`.
- Whether runtime `RaceInstances` are still present after a session.

## What It Does Not Change

This audit is read-only. It does not edit:

- scripts;
- attributes;
- rewards;
- route guide config;
- arrows/session assets;
- VFX/name-tag visibility;
- matchmaking;
- driving physics;
- DataStore settings;
- UI layout.

## How To Run

Run in Studio Command Bar, Edit or Play mode:

```text
scripts/roblox_racing_phase11s_stability_baseline_audit.lua
```

## Verification

Treat `fail=0` as the gate before the next feature phase.

Warnings can be acceptable if they identify runtime objects still present during an active session, or if the audit is running from a Play client and skips server-only source checks. After finishing/exiting a time trial there should not be stale race instances left behind.

Recommended quick smoke:

1. Run the audit in Edit mode for full server/client source checks.
2. Play a time trial.
3. Finish and exit the result panel.
4. Run the audit again in Play mode.
5. Confirm `fail=0`; a client-mode warning about skipped server checks is acceptable.

## Next Step

After a clean Phase 11S audit, the next useful phase can be either:

- a safer result-panel polish pass as an isolated/canonical UI replacement; or
- a DataStore-enabled PB save/rejoin verification if Studio API services are ready.
