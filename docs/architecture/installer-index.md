# Current tools and recovery

Current task, acceptance and pending runs: [start here](../00_START_HERE.md). This index owns tool paths and recovery ordering, not delivery status.

| Purpose | Canonical script |
|---|---|
| Current migration | scripts/roblox_performance_phase5_catalogue_transport.lua — INSTALL / AUDIT / ROLLBACK |
| Read-only Studio audit | scripts/studio_cleanup_audit.lua |
| Current export | scripts/studio_export_snapshot.lua |
| Current receiver | scripts/receive_studio_snapshot.py |
| Current importer | scripts/import_studio_snapshot.py |
| Mirror integrity | scripts/verify_studio_mirror.py |
| Naming audit | scripts/audit_cleanup.py |
| Current exact parity | scripts/performance_phase5/verify_migration.py |
| Pipeline tests | scripts/test_studio_snapshot_pipeline.py |

Earlier installers are historical recovery only: roll back dependent phases in reverse order first. Old export tools are archived under scripts/history/snapshot_before_cleanup_phase4; do not mix protocols. Frozen sources/build support under scripts/cleanup_phase* are repository evidence, not runtime dependencies.

See performance-phase5-catalogue-transport.md. Roll back this delivery before cleanup recovery. Prior index: ../history/cleanup-phase4-prior-docs/installer-index.md.

Catalogue/preview freshness: scripts/performance_phase4/check_projection.py (currently requires full hierarchy capture). Latest validation evidence: scripts/performance_phase6/mirror-verification.json. General snapshot procedure: [snapshot workflow](../10_script_source_sync_workflow.md).
