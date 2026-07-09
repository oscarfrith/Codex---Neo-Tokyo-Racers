# Racing Phase 11L Arrow Visual Proxy Sync Repair

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11l_arrow_visual_proxy_sync_repair.lua`  
**Type:** Focused Studio Command Bar repair

## Purpose

This repair fixes the Phase 11L follow-up regression where solo time-trial arrow visuals could stop advancing after the early checkpoints even though the server arrow/barrier collision proxies were still being created and cleared correctly.

## Root Cause

The server collision service already tracks each active player's segment in:

```text
Workspace.NeoTokyoRacersWorld.RaceInstances.<RunId>.SessionAssets.ArrowBarrierProxies.ParticipantSegments
```

The Phase 11L client arrow visual script could still rely too heavily on its own local event timing and multi-session visibility state. If those client-side updates drifted, the visible arrow window could freeze while the server collision window kept working.

## What It Changes

- Canonically replaces only `RaceSessionAssetsClient_Active`.
- Keeps route arrow visibility multi-session aware.
- Reads the server `ArrowBarrierProxies.ParticipantSegments` value for the local player's current `RunId`.
- Uses that server segment as the source of truth/fallback for which `ArrowMarkers.CheckpointA-B` folders should be visible.
- Reapplies the visual window lightly while a local race/time-trial run is active, so missed checkpoint events do not leave arrows stuck.
- Uses local transparency only and does not rewrite the authored arrow assets' actual transparency, position, rotation, size, or folder placement.

## What It Does Not Change

- Rewards or reward config.
- Route-guide config or checkpoint label attributes.
- Server collision/proxy generation.
- Matchmaking.
- Time-trial personal best persistence.
- VFX/name-tag visibility owner.
- Driving physics.
- Main bootstrap.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11l_arrow_visual_proxy_sync_repair.lua
```

Restart Play after installing.

## Verification

1. Start a solo time trial on `ShiftedCanalSprint`.
2. Drive through checkpoints 1-5.
3. Confirm arrows continue advancing after checkpoint 3.
4. Confirm arrows only appear around the current segment window.
5. Confirm physical arrow/barrier collision still works in time trials.
6. Run a 2-player local race and confirm race arrow visuals still advance for the racer.
7. Confirm overlapping race/time-trial visibility still hides unrelated vehicles, VFX, and name tags.

## Rollback

If this causes no arrows to display, roll back `RaceSessionAssetsClient_Active` through Roblox version history or rerun the original Phase 11L script:

```text
scripts/roblox_racing_phase11l_multi_session_visibility_owner.lua
```

Then capture Studio Output and inspect whether `ArrowBarrierProxies.ParticipantSegments` is changing during the run.
