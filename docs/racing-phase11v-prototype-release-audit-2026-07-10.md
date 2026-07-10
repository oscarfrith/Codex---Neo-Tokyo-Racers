# Racing Phase 11V Prototype Release Audit

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11v_prototype_release_audit.lua`  
**Type:** Read-only audit

## Purpose

Phase 11V is a read-only gate after the confirmed Phase 11U V2 result/HUD cleanup baseline.

It checks the current race/time-trial prototype stack before more feature work, DataStore PB verification, UX polish, or broader multiplayer smoke testing.

V2 note: the first run in Studio live-edit context reported healthy checks overall but treated missing runtime collision groups as failures. In Edit mode, the runtime services may not have registered collision groups yet, so V2 treats missing live groups as warnings there and keeps live collision policy as a Play/runtime gate.

## What It Checks

- Racing remotes and config folders.
- Reward and personal-best config.
- Racing server services when run from Edit/server context.
- Time-trial result exit cleanup.
- PB record/readout/board wiring.
- Race reward and exit-to-start wiring.
- Session asset service and collision groups.
- Arrow segment folder structure.
- Route start zones, checkpoints, spawn grid, teleport point, and finish line.
- Result coach and narrow HUD cleanup clients.
- VFX/name-tag visibility client markers.
- Runtime `RaceInstances` leftovers.
- Play-client `PlayerGui` result/HUD state when available.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11v_prototype_release_audit.lua
```

Recommended:

1. Run once in Edit mode for full server/source coverage.
2. Restart Play, finish a time trial, exit to start, then run it again from the Play client to inspect local UI/runtime state.
3. Optionally run during a 2-player local race to inspect active `RaceInstances` warnings while the session is live.

## Interpreting Results

`fail=0` is the gate for moving to the next feature phase.

Warnings can be acceptable when:

- running from a Play client, where `ServerScriptService` is not replicated;
- running in Edit mode before runtime collision groups have been registered;
- a race/time-trial is actively running and `RaceInstances` is expected to have children;
- PlayerGui has not created a racing UI yet in the current session.

## What It Does Not Change

This audit does not modify gameplay, source, assets, folders, config, rewards, VFX, UI, driving, matchmaking, or route data.

## Next Phase After Pass

After Phase 11V passes in Edit mode and a Play smoke, the recommended next phase is Phase 11W: DataStore-gated time-trial PB save/rejoin verification.
