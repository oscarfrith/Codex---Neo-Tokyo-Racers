# Racing Phase 11X Prototype Release Candidate Audit

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11x_prototype_release_candidate_audit.lua`  
**Type:** Read-only audit

## Purpose

Phase 11X is the post-PB-save release-candidate gate for the current racing prototype.

It does not install a new feature. It checks that the working race/time-trial stack is still coherent before choosing the next real feature, polish pass, or broader multiplayer test.

## What It Checks

- Racing remotes.
- Reward, matchmaking, route-guide, and personal-best config.
- Whether PB DataStore testing is currently enabled or has been disabled again.
- Server services and key source markers, when run from Edit/server context.
- Client racing controllers and key source markers.
- `ShiftedCanalSprint` route structure:
  - 14 checkpoint prototype baseline;
  - race/time-trial start zones;
  - finish line;
  - teleport point;
  - spawn grid;
  - `ArrowMarkers.CheckpointA-B` folders and arrow parts.
- Runtime `RaceInstances` leftovers.
- Race collision groups and collision policy.
- In Play-client context:
  - local PB lookup through the same `RaceRequest` action used by UI;
  - stale `NTR_RaceHud_Phase3.Panel` visibility;
  - result coach GUI presence.

## How To Run

Run in Studio Command Bar:

```text
scripts/roblox_racing_phase11x_prototype_release_candidate_audit.lua
```

Recommended sequence:

1. Run once in Edit mode.
2. Restart Play.
3. Finish a solo time trial, exit to start, and run it again from the Play client.
4. Run a 2-player same-server race smoke, finish/exit, and run it again from the Play client.

## Interpreting Results

`fail=0` is the gate.

Expected warnings can include:

- server checks skipped from a Play client;
- runtime collision groups missing in Edit mode before services start;
- no PBs found for a player that has not saved PBs in the selected store;
- `RaceInstances` has children while a race/time trial is actively running;
- PlayerGui result/HUD objects not created yet in a fresh session.

## What It Does Not Change

Phase 11X does not modify Studio hierarchy, source, rewards, route-guide config, arrows, collisions, driving, VFX, UI, matchmaking, DataStore config, or the main bootstrap.

## Next Step After Pass

After Phase 11X passes in Edit and after the solo/multiplayer smoke, the sensible next fork is:

- small racing UI/flow polish if you want the prototype to feel nicer;
- a focused multiplayer race balance/reliability pass;
- or a new feature branch such as leaderboards/ghosts, with a fresh plan before implementation.

Private/reserved servers and player-created race tooling remain larger deferred systems.
