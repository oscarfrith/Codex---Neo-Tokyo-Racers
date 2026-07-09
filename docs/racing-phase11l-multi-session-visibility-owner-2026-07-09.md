# Racing Phase 11L Multi-Session Visibility Owner

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11l_multi_session_visibility_owner.lua`  
**Type:** Focused Studio Command Bar repair

## Purpose

Phase 11L fixes race/time-trial visibility when sessions overlap in the same server.

Confirmed symptom:

- Player A stays in a multiplayer race.
- Player B exits that race and starts a solo time trial.
- When Player B enters the time trial, Player A's race vehicle can disappear, but Player B can still see Player A's idle engine VFX.

## Root Cause

Two client systems were still trying to own participant visibility:

- `RaceParticipantVisibilityClient_Active`, added by Phase 11H/11I, hides vehicles, name tags, and VFX.
- `RaceEntryMenuClient_Active` still had an older simple visibility loop from Phase 3 that only toggled `BasePart.LocalTransparencyModifier` using one global `state.Visibility`.

When a time trial started while a race was still active, the simple Phase 3 loop and the newer VFX/name-tag gate could disagree. That allowed a mixed state where the vehicle body was hidden but idle engine VFX still leaked.

## What It Changes

- Canonically replaces `RaceParticipantVisibilityClient_Active` with a multi-session visibility owner keyed by `RunId`.
- Tracks multiple active sessions at once.
- If the local player is in a session, they only see participants/vehicles that share that same session.
- If the local player is in free roam, they do not see active race/time-trial participants.
- Keeps Phase 11I idle VFX flushing behavior.
- Disables the old entry-menu visibility loop and its `RaceVisibilityUpdate` branch so it cannot fight the dedicated visibility owner.
- Canonically replaces `RaceSessionAssetsClient_Active` with a multi-session-aware arrow/session visual client, so a time-trial visibility update cannot hide the route arrows for a player still in a race.

## What It Does Not Change

- Rewards.
- Route-guide config.
- Arrow/barrier segment folders.
- Matchmaking.
- Race/session asset collision.
- Driving physics.
- Main bootstrap.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11l_multi_session_visibility_owner.lua
```

Restart Play after installing.

## Verification

Use two local players:

1. Start a multiplayer race with both players.
2. Let Player A remain in the race.
3. Have Player B exit and start a time trial.
4. Verify Player B cannot see Player A's race vehicle, name tag, or idle engine VFX.
5. Verify Player A cannot see Player B's time-trial vehicle, name tag, or VFX.
6. Verify two players in the same race still see each other.
7. Verify the player still in the race keeps seeing their nearby route arrows after the other player starts a time trial.
8. Verify free-roam players do not see active race/time-trial participants.
9. Exit both sessions and verify normal free-roam vehicles/VFX become visible again.

## Notes

This repair intentionally makes `RaceParticipantVisibilityClient_Active` the single owner of race/time-trial participant hiding. Future visibility fixes should extend that isolated client instead of re-enabling visibility logic in the race entry menu. Route arrow/session visual fixes should extend `RaceSessionAssetsClient_Active` without returning it to single global visibility state.

The next recommended feature phase after this repair is still time-trial personal-best persistence, once overlapping-session visibility is confirmed.
