# Current tools and recovery

Performance Phase 4 installed, 2026-09-22; user gameplay acceptance pending. All cleanup phases are confirmed.

| Purpose | Canonical script |
|---|---|
| Current migration | scripts/roblox_performance_phase4_vehicle_previews.lua — INSTALL / AUDIT / ROLLBACK |
| Read-only Studio audit | scripts/studio_cleanup_audit.lua |
| Current export | scripts/studio_export_snapshot.lua |
| Current receiver | scripts/receive_studio_snapshot.py |
| Current importer | scripts/import_studio_snapshot.py |
| Mirror integrity | scripts/verify_studio_mirror.py |
| Naming audit | scripts/audit_cleanup.py |
| Current exact parity | scripts/performance_phase4/verify_migration.py |
| Pipeline tests | scripts/test_studio_snapshot_pipeline.py |

No manual installer run is pending. Earlier installers are historical recovery only: roll back dependent phases in reverse order first. Old export tools are archived under scripts/history/snapshot_before_cleanup_phase4; do not mix protocols. Frozen sources/build support under scripts/cleanup_phase* are repository evidence, not runtime dependencies.

See performance-phase4-vehicle-previews.md. Roll back this delivery before cleanup recovery. Prior index: ../history/cleanup-phase4-prior-docs/installer-index.md.
