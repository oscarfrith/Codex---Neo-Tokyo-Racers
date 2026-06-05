# Phase 12 Server Action Snapshot

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Prepared  
**Studio script:** `scripts/roblox_hierarchy_phase12_server_action_snapshot.lua`

## Goal

Phase 12 captures the current live V56 server action layer into the new architecture as a snapshot/parity reference.

This is the first step toward extracting `HOVER_RACING_V2_Server` into proper services, but it does not switch live behaviour yet.

## What The Script Creates

Under `ServerScriptService.NeoTokyoRacers.Services.Garage`:

```text
V56ActionLayerSnapshot
```

Under `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data`:

```text
ServerServiceExtractionPlan
```

Under `ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports`:

```text
Phase12_ServerActionSnapshotReport
```

It also tags the staged service modules with:

```text
V56SnapshotHash
V56SnapshotSource
ExtractionPlan
LiveEnabled = false
```

## What It Does Not Change

The script does not:

- Edit `HOVER_RACING_V2_Server`.
- Disable `HOVER_RACING_V2_Server`.
- Replace `GarageInvoke.OnServerInvoke`.
- Enable `NeoTokyoRacersServer_Bootstrap_Disabled`.
- Change cash, purchases, catalog data, vehicle spawn, driving, VFX, UI, mobile controls, LOD, lighting, traffic, or assets.

## Why This Phase Exists

The live server contains both an older top-level action layer and the current V56 consolidated action layer. The V56 block is the current source of truth.

Before moving behaviour into services, future scripts need a stable snapshot of the exact V56 block, its function list, action list, line range, and hash. This makes it easier to detect accidental drift and avoids patching the wrong server layer.

## Test Checklist

After running the Studio script:

- Cash still loads.
- Dealership still loads.
- Cockpit/module purchase still works.
- Customisation still works.
- Vehicle spawning still works.
- Driving still works.
- Report exists in `ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports`.
- `V56ActionLayerSnapshot` exists but is not required by live gameplay.
- `V56ActionLayerSnapshot` can be required by Phase 13 without a table syntax error.

## Codex Safety Notes

- Do not switch `GarageInvoke` in this phase.
- Do not remove the old top-level action layer yet.
- Use the generated V56 hash/report as the parity target for future server service extraction.
- The next server phase should create a shadow service implementation or parity harness before any live switch.

## 2026-05-28 Note

The snapshot generator was corrected so the generated `V56ActionLayerSnapshot` table includes commas between fields. If an older snapshot was generated before this correction, rerun Phase 12 before running Phase 13.
