# Cleanup Phase G Full Hierarchy Audit

**Created / first designed:** 2026-05-29  
**Last updated:** 2026-05-29  
**Current status:** Audit ready / deletion not yet generated  
**Relevant script:** `scripts/roblox_cleanup_phaseG_full_hierarchy_cleanup_audit.lua`

## What This Phase Does

Cleanup Phase G scans the current Roblox Studio place after the architecture and main client migrations. It produces a full hierarchy report and classifies old inactive folders, disabled legacy scripts, old report folders, rollback scripts, and empty legacy roots as cleanup candidates.

This phase is intentionally an audit gate. It does not delete gameplay objects. The deletion script should be created only after reviewing the exact paths found in the report.

## How To Run

Run `scripts/roblox_cleanup_phaseG_full_hierarchy_cleanup_audit.lua` in Roblox Studio Command Bar, preferably in Edit mode.

The script writes reports under:

```text
ReplicatedStorage
+-- NeoTokyoRacers
    +-- Compatibility
        +-- CleanupReports
```

Main report values:

```text
CleanupPhaseG_Summary
CleanupPhaseG_FullHierarchyAudit_001
CleanupPhaseG_FullHierarchyAudit_002
...
```

## What To Paste Back

Paste the Studio Output summary first.

If cleanup candidates are found, also paste these sections from the report:

```text
Unexpected Active Scripts
Auto Cleanup Candidates
Review Before Delete Candidates
```

Only paste the full hierarchy chunks if Codex asks for them.

## Protected Areas

The audit excludes `Workspace.Test + WIP Assets` from cleanup candidate classification.

The audit also protects current live roots such as:

```text
Workspace.NeoTokyoRacersWorld
ReplicatedStorage.NeoTokyoRacers
ReplicatedStorage.HOVER_RACING_V2_KIT
ServerScriptService.NeoTokyoRacers
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient
```

## Expected Next Step

After the report is reviewed, create a separate targeted cleanup script with exact allowlisted paths.

The cleanup script should:

- Delete only reviewed paths from the audit.
- Avoid `Workspace.Test + WIP Assets`.
- Avoid current live `NeoTokyoRacers` roots.
- Print every deleted path.
- Stop if an expected path has changed class or is active when it should be disabled.
- Be run only after the current place backup has been confirmed.

## Codex Safety Notes

Do not infer deletion targets from names alone. Use the latest Studio audit output as the source of truth.

Do not delete disabled rollback scripts until the user confirms the backup/version history is enough.

Do not combine cleanup with gameplay changes, LOD changes, vehicle changes, UI changes, or asset migration.
