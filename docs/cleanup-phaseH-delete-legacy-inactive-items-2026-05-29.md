# Cleanup Phase H Delete Legacy Inactive Items

**Created / first designed:** 2026-05-29  
**Last updated:** 2026-05-29  
**Current status:** Script ready / dry-run first  
**Relevant script:** `scripts/roblox_cleanup_phaseH_delete_legacy_inactive_items.lua`

## What This Phase Does

Cleanup Phase H removes the inactive legacy items found by Cleanup Phase G after the user confirmed the current Roblox file has a backup.

It targets old disabled owners, rollback scripts, old report folders, the legacy archive, and old legacy script containers. It does not target live vehicle systems, current `NeoTokyoRacers` owner scripts, city blocks, `FarLOD5`, `HOVER_RACING_V2_KIT`, `HOVER_RACING_V2_WORLD`, spawn points, preview pads, or `Workspace.Test + WIP Assets`.

## How To Run

Run `scripts/roblox_cleanup_phaseH_delete_legacy_inactive_items.lua` in Roblox Studio Command Bar, preferably in Edit mode.

Run order:

1. Leave `MODE = "DRY_RUN"` and run once.
2. Check the `Would Delete` list.
3. Change `MODE = "DELETE"` and run again.
4. Play-test fresh.
5. Run Cleanup Phase G again to confirm no unexpected active scripts or unwanted legacy items remain.

## Paths Targeted

Main groups targeted:

- `ReplicatedStorage.NTR_AUDIT_REPORTS`
- `ReplicatedStorage.NTR_INVENTORY_REPORTS`
- `ServerScriptService.HOVER_RACING_SERVER`
- `ServerScriptService.HOVER_RACING_V2_SERVER`
- `ServerScriptService.Lighting`
- `ServerScriptService.Traffic Lights`
- `ServerStorage.NeoTokyoRacers_LegacyArchive`
- Disabled shadow/bootstrap rollback scripts under current architecture folders
- Disabled old `HOVER_RACING` LocalScripts in `StarterPlayerScripts`
- Disabled old `LOD System`
- Old `StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_CLIENT` folder

## Safety Checks

The script refuses to delete if:

- A protected active owner is missing or disabled.
- A target has a different class than expected.
- A target script is enabled when it should be disabled.
- A target is one of the explicitly protected current live roots.

## Codex Safety Notes

Do not expand this cleanup script to include assets or current architecture folders without a fresh Studio audit.

Do not delete `Workspace.HOVER_RACING_V2_WORLD` from this phase. It still contains runtime vehicle, preview pad, and spawn point objects.

Do not delete `ReplicatedStorage.HOVER_RACING_V2_KIT`, `ReplicatedStorage.FarLOD5`, or `Workspace.NeoTokyoRacersWorld`.
