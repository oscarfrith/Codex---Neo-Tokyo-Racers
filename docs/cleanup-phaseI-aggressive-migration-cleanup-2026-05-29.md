# Cleanup Phase I Aggressive Migration Cleanup

**Created / first designed:** 2026-05-29  
**Last updated:** 2026-05-29  
**Current status:** One-step aggressive cleanup ready  
**Relevant script:** `scripts/roblox_cleanup_phaseI_aggressive_migration_cleanup.lua`

## What This Phase Does

Cleanup Phase I is an aggressive one-step cleanup requested after Phase H was deleted and play-tested successfully.

It removes migration scaffolding clutter that is no longer useful after the owner switches:

- Old migration and cleanup report StringValues.
- Stale `ReferenceOnly` ObjectValues.
- Mirror-only config/reference copies created by early architecture phases.
- Non-live `ScaffoldOnly`, `ShadowCopyOnly`, `SnapshotOnly`, and disabled future bootstrap code.
- Empty placeholder folders from staged client/server architecture.

## Protected Systems

The script does not delete:

- Current active owner scripts.
- `ReplicatedStorage.HOVER_RACING_V2_KIT`
- `ReplicatedStorage.FarLOD5`
- `Workspace.NeoTokyoRacersWorld`
- `Workspace.HOVER_RACING_V2_WORLD`
- `Workspace.Test + WIP Assets`
- `StarterGui.NeoTokyoRacersUI`

## Important Behaviour

This script does not have a dry-run mode. It performs the cleanup immediately after confirming the expected active owner scripts exist and are enabled.

If an active owner is missing or disabled, the script stops before deleting anything.

## After Running

After running Phase I:

1. Play-test fresh.
2. Run Cleanup Phase G again.
3. Confirm active scripts are still expected and unexpected active scripts are `0`.
4. Commit the cleanup checkpoint if the play-test is clean.

## Codex Safety Notes

Do not add gameplay folders, vehicle asset folders, city folders, VFX templates, or the live kit to this script.

Do not delete `HOVER_RACING_V2_WORLD` in this phase; it still contains runtime vehicle and spawn/preview objects.

Use a fresh audit before creating any cleanup phase after this one.
