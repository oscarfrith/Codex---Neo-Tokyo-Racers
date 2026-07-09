# Racing Phase 11G Studio UserId Session Asset Fix

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11g_studio_userid_session_asset_fix.lua`

## Root Cause

Phase 11F diagnostics showed the multiplayer race proxy window stayed on:

```text
ParticipantSegments=-1:0,-2:0
Proxy segment counts: Checkpoint0-1, Checkpoint1-2, Checkpoint14-0
```

even while `RaceCheckpoint` events fired.

The root cause is Studio/local-server test player IDs. Roblox test players use negative UserIds such as `-1` and `-2`. `RaceSessionAssetService_Active` accepted those IDs during `ApplyParticipants`, but rejected them during:

- `UpdateParticipantSegment`, because it required `userId > 0`;
- `RemoveParticipant`, because it only removed participants when `userId > 0`.

That meant local multiplayer race checkpoint progress could never move the server-side arrow/barrier proxy window beyond segment `0`, and local test participants could remain in the collision/asset state after finish or exit.

## Fix

Phase 11G changes the session asset service to accept any non-zero numeric UserId.

Production UserIds are still positive, so production behaviour is unchanged. This restores parity for Studio local-server testing.

## Verification

After running the script in Edit mode and restarting Play:

1. Start a 2-player local server race.
2. Drive both cars past checkpoints 1, 2, and 3.
3. Confirm arrow/barrier collision follows later checkpoint segments.
4. Optionally rerun `scripts/roblox_racing_phase11f_runtime_isolation_diagnostic.lua` during the race.
5. Good diagnostic signs:

```text
ParticipantSegments=-1:2,-2:1
Proxy segment counts: Checkpoint1-2, Checkpoint2-3, Checkpoint3-4
```

Exact segment numbers will depend on where each test player is on the route.

## Rollback

Use Roblox place version history or revert only the two Phase 11G source edits in `RaceSessionAssetService_Active`. This phase only changes local-server test UserId acceptance; it does not touch reward config, route-guide config, VFX, matchmaking, or vehicle physics.
