# Cleanup Phase M Post Kit Migration Audit

Generated: 2026-05-29

## Purpose

Cleanup Phase M is a read-only audit to run after Architecture Phase K and Phase L. It checks that the old `ReplicatedStorage.HOVER_RACING_V2_KIT` root is gone and looks for any stale cleanup candidates left behind by the migration.

## Script

Run in Roblox Studio Command Bar, Edit mode:

```text
scripts/roblox_cleanup_phaseM_post_kit_migration_audit.lua
```

## What It Checks

- Missing migrated `ReplicatedStorage.NeoTokyoRacers` folders.
- Unexpected active scripts.
- Missing expected active scripts.
- Remaining legacy source tokens such as `HOVER_RACING_V2_KIT`, `CLIENT_MODULES`, `VFX_TEMPLATES`, and `00_EDIT_ME_FIRST`.
- Stale ObjectValues, StringValues, or attributes pointing at old paths.
- Empty compatibility/remainder folders.
- Old report clutter.
- Legacy runtime-world source tokens such as `Workspace.HOVER_RACING_V2_WORLD` and `PLAYER_VEHICLES_Runtime`.
- Missing new runtime paths under `Workspace.NeoTokyoRacersWorld`.

## Safe Effects

The script only replaces its own previous Phase M report StringValues and writes a fresh report under:

```text
ReplicatedStorage.NeoTokyoRacers.Compatibility.CleanupReports
```

It does not move, rename, disable, enable, delete, clone, or edit gameplay objects.

## Expected Output

Successful run should print:

- `Post kit migration cleanup audit complete.`
- A `CleanupPhaseM_Summary` StringValue.
- One or more `CleanupPhaseM_PostKitMigrationAudit_###` report chunks.

Healthy post-K/L output should ideally show:

- Legacy kit exists: `false`
- Missing required migrated paths: `0`
- Source legacy token hits: `0`
- Unexpected active scripts: `0`
- Missing expected active scripts: `0`

## Next Step

Paste the Phase M summary back into Codex before generating any deletion script. The audit is intentionally conservative: report values, empty compatibility folders, and the legacy-named active world root should be reviewed before cleanup.

If the summary is not enough, run this helper to print only the actionable sections:

```text
scripts/roblox_cleanup_phaseM_print_action_sections.lua
```

If Phase M reports `Workspace.HOVER_RACING_V2_WORLD` as missing, run this probe before deleting stale ObjectValues:

```text
scripts/roblox_cleanup_phaseM_runtime_root_probe.lua
```

The 2026-05-29 probe found the old world root missing while live sources still referenced it. Use Phase N before generating cleanup deletion scripts:

```text
scripts/roblox_architecture_phaseN_runtime_world_path_repair.lua
```
