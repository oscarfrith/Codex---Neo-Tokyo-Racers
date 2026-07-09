# Racing Phase 11F Runtime Isolation Diagnostic

**Created:** 2026-07-09  
**Type:** Read-only Studio Command Bar diagnostic  
**Script:** `scripts/roblox_racing_phase11f_runtime_isolation_diagnostic.lua`

## Why This Exists

Phase 11E was intended to fix three live multiplayer race isolation issues:

- arrow/barrier collision stopping after the first visible segment window;
- race/time-trial hover VFX leaking to free-roam players and vice versa;
- race vehicles colliding with each other.

The user reported that none of the Phase 11E fixes changed live behaviour. Per the continuous-improvement workflow, the next step is diagnostics rather than another guessed patch.

## What It Checks

The diagnostic prints:

- whether the live Studio sources contain the Phase 11E markers;
- whether the expected racing/VFX owners exist and are enabled;
- registered collision groups and the live collidability matrix for race assets/participants;
- active `RaceInstances` and `ArrowBarrierProxies` attributes;
- proxy segment keys, collision groups, and `CanCollide` state;
- runtime race vehicles, their race attributes, part collision groups, and VFX enabled counts;
- racing remotes present in `ReplicatedStorage`.

## How To Run

Run during the broken state, not just in Edit mode:

1. Start a 2-player local server race.
2. Drive past checkpoint 2, where multiplayer arrow/barrier collision stops working.
3. Paste/run `scripts/roblox_racing_phase11f_runtime_isolation_diagnostic.lua` in the Studio Command Bar.
4. Copy the full Output block back to Codex.

The script watches for roughly 24 seconds and samples every 3 seconds.

## How To Read The Result

- If Phase 11E markers are missing, the previous installer did not patch the live owner or the wrong owner is running.
- If markers are present but `ParticipantSegments` does not change as racers pass checkpoints, the race checkpoint update path is the root.
- If `ParticipantSegments` changes and proxies rebuild, but vehicle parts are not in `NTR_RaceParticipant`, the race vehicle collision-group handoff is the root.
- If proxy parts are not in `NTR_RaceSessionAsset`, the session asset service/proxy builder is the root.
- If the VFX marker is present but VFX still leaks, the cached thrust runtime is probably not the only active VFX owner, or the client is not receiving/using the race visibility payload as expected.

## Safety

This diagnostic is read-only. It does not patch sources, create instances, delete objects, or change collision groups.
