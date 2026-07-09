# Racing Phase 11J Prototype Baseline Audit

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11j_prototype_baseline_audit.lua`  
**Type:** Read-only Studio Command Bar audit

## Purpose

Phase 11J locks the current prototype race/time-trial baseline before adding persistence or more competitive UX.

The user confirmed:

- multiplayer arrow/barrier collision works after Phase 11G;
- race/time-trial visibility and name tags mostly work after Phase 11H;
- idle engine VFX hiding works after Phase 11I.

This phase intentionally does not add gameplay features. It checks that the prototype stack is structurally healthy.

## What It Checks

- Racing remotes and shared route/config modules.
- Global race/time-trial reward config folders.
- Matchmaking config folder.
- `ShiftedCanalSprint` route structure:
  - start zones;
  - checkpoints;
  - spawn grid;
  - teleport points;
  - segmented `ArrowMarkers.CheckpointA-B` folders and arrow parts.
- Collision groups:
  - `NTR_RaceSessionAsset`;
  - `NTR_RaceParticipant`;
  - asset/participant collision;
  - asset/default non-collision;
  - participant/participant non-collision.
- Key source markers:
  - server grid spawning;
  - race finish boundary cleanup;
  - folder arrow barrier service;
  - Studio local-server UserId fix;
  - visibility/VFX/name tag gate;
  - idle VFX flush.
- Runtime state when run during Play:
  - active `RaceInstances`;
  - proxy segment/debug attributes;
  - runtime vehicle race attributes.

## How To Run

Run in Roblox Studio Command Bar:

```text
scripts/roblox_racing_phase11j_prototype_baseline_audit.lua
```

Recommended passes:

1. Run once in Edit mode.
2. Restart Play and run during a solo time trial.
3. Restart a 2-player local server race and run during the race, ideally after checkpoint 2.

Edit mode is the main source-marker audit. If this script is run from a Play client, server-only script source checks may warn because `ServerScriptService` source is not visible to that client context; use the Edit-mode result as the hard source baseline.

## Interpreting Results

- `FAIL=0` means the prototype baseline has no hard structural failures.
- Warnings are review items, not automatic blockers.
- If the runtime audit shows `ParticipantSegments` advancing during a race, the Phase 11G collision-window fix is still healthy.
- If source marker checks fail after Studio changes, refresh the Studio mirror before writing another patch.

## Next Phase

After Phase 11J passes and the Studio mirror is refreshed, the recommended next feature phase is personal-best persistence for time trials. Private/reserved race servers, advanced session assets, and player-created race tooling are intentionally deferred for prototype scope.
