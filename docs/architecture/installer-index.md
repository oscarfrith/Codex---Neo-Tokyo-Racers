# Current tools and recovery

Phase 4 installed, 2026-09-22; user gameplay acceptance pending.

| Purpose | Canonical script |
|---|---|
| Current cleanup | scripts/roblox_cleanup_phase4_finalise.lua — INSTALL / AUDIT / ROLLBACK |
| Read-only Studio audit | scripts/studio_cleanup_audit.lua |
| Current export | scripts/studio_export_snapshot.lua |
| Current receiver | scripts/receive_studio_snapshot.py |
| Current importer | scripts/import_studio_snapshot.py |
| Mirror integrity | scripts/verify_studio_mirror.py |
| Naming audit | scripts/audit_cleanup.py |
| Phase 4 parity | scripts/cleanup_phase4/verify_migration.py |
| Pipeline tests | scripts/test_studio_snapshot_pipeline.py |

No manual installer run is pending. Earlier installers are historical recovery only: roll back dependent phases in reverse order first. Old export tools are archived under scripts/history/snapshot_before_cleanup_phase4; do not mix protocols. Frozen sources/build support under scripts/cleanup_phase* are repository evidence, not runtime dependencies.

See cleanup-phase4-finalisation.md. Prior index: ../history/cleanup-phase4-prior-docs/installer-index.md.
