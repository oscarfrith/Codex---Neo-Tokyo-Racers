# Phase 11 Architecture Readiness Audit

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Prepared  
**Studio script:** `scripts/roblox_hierarchy_phase11_architecture_readiness_audit.lua`

## Goal

Phase 11 checks whether the new architecture scaffold is complete and highlights what still depends on old live `HOVER_RACING` scripts.

This is intentionally an audit/report phase, not a destructive cleanup phase. The current live UI, server, driving, VFX, mobile controls, and gameplay scripts should not be renamed or removed until replacement owners are switched and tested.

## What The Script Does

The script scans:

- Expected `NeoTokyoRacers` architecture folders/modules/scripts from Phases 6-10.
- Active scripts outside the approved current live roots.
- Active scripts inside excluded `Workspace.Test + WIP Assets`.
- Disabled legacy `HOVER_RACING` scripts.
- Whether disabled future bootstraps accidentally became enabled.
- Whether traffic lights are using the new service instead of the old top-level script.

It writes a report to:

```text
ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports.Phase11_ArchitectureReadinessAudit
```

It also prints the report to Output.

## What It Does Not Change

The script does not:

- Move anything.
- Rename anything.
- Enable or disable scripts.
- Delete or clone gameplay scripts.
- Edit script source.
- Change UI, driving, VFX, server actions, mobile controls, LOD, lighting, traffic, assets, or `Workspace.Test + WIP Assets`.

## Why This Phase Is Not A Rename Pass

The roadmap originally describes final naming and legacy cleanup after all live systems have moved. At this point, the new architecture is scaffolded, but the working owners are still mostly the current `HOVER_RACING` scripts.

Renaming those live scripts now would be risky because current references, compatibility ObjectValues, Studio habits, and future migration maps still point at those names.

## Test Checklist

After running the Studio script:

- Confirm a report appears under `ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports`.
- Confirm there are no unexpected active scripts.
- Confirm no expected-disabled future bootstrap is enabled.
- Confirm traffic lights still work.
- Confirm dealership/customisation still work.
- Confirm driving/mobile/VFX still work.

## Future Cleanup Rule

Only perform final legacy cleanup after:

- UI ownership has moved out of `HOVER_RACING_V2_Client`.
- Server action ownership has moved out of `HOVER_RACING_V2_Server`.
- Runtime ownership has moved out of the patch-style mobile/HUD/VFX helper scripts.
- A fresh active script audit shows no unexpected active scripts.
- A play-test confirms dealership, customisation, spawn, driving, mobile controls, VFX, exit/re-enter, traffic, lighting, and LOD still work.

## Codex Safety Notes

- Treat this script as the checkpoint before any risky rename/removal work.
- Do not use this audit as permission to delete live `HOVER_RACING` scripts.
- Keep `TEMP_LightingPreview` intentionally allowed.
- Keep `Workspace.Test + WIP Assets` excluded.
