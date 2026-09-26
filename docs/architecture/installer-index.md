# Current tools and recovery

Current task, acceptance and pending runs: [start here](../00_START_HERE.md). This index owns tool paths and recovery ordering, not delivery status.

| Purpose | Canonical script |
|---|---|
| Continuous lighting | scripts/continuous_lighting/install.lua — AUDIT / APPLY / STEPPED / CONTINUOUS / ROLLBACK; [recovery guide](lighting-horizon-moon-handoff.md), [editing guide](lighting-authoring.md) |
| Catalogue transport recovery | scripts/roblox_performance_phase5_catalogue_transport.lua — INSTALL / AUDIT / ROLLBACK |
| Architecture programme installer | scripts/architecture/installer.py (+ installer.lua) — AUDIT / APPLY / ROLLBACK for source, module, attribute and remove_instance ops; per-phase specs in scripts/architecture/p1..p9; [programme](architecture-programme.md) |
| Read-only Studio audit | scripts/studio_cleanup_audit.lua |
| Deliberate full checkpoint exporter | scripts/studio_export_snapshot.lua |
| Full checkpoint receiver | scripts/receive_studio_snapshot.py |
| Full checkpoint importer | scripts/import_studio_snapshot.py |
| Mirror integrity | scripts/verify_studio_mirror.py |
| Source naming audit | scripts/audit_cleanup.py --capture <capture.json>; --legacy-mirror for deliberate historical input |
| Historical Phase 5 full-checkpoint parity | scripts/performance_phase5/verify_migration.py |
| Pipeline tests | scripts/test_studio_snapshot_pipeline.py |

Earlier installers are historical recovery only: roll back dependent phases in reverse order first. Old export tools are archived under scripts/history/snapshot_before_cleanup_phase4; do not mix protocols. Frozen sources/build support under scripts/cleanup_phase* are repository evidence, not runtime dependencies.

See performance-phase5-catalogue-transport.md. Roll back continuous lighting before any older recovery that touches its source owners; then restore dependent architecture deliveries in reverse order before cleanup recovery. Do not rerun installed migrations. Prior index: ../history/cleanup-phase4-prior-docs/installer-index.md.

Catalogue/preview freshness: scripts/performance_phase4/check_projection.py --capture <vehicles-capture.json>; --legacy-mirror for a deliberate full checkpoint. Workflow capture validation: scripts/workflow_phase2/verification.json. General snapshot procedure: [snapshot workflow](../10_script_source_sync_workflow.md).

Targeted capture/verify/compare: scripts/studio_capture.py. Presets sources/config/vehicles or explicit roots/properties; see [runbook](targeted-capture-workflow.md). Serializer tail: scripts/capture_scoped_tail.lua (generated producer support, not a standalone installer). Tests: scripts/test_studio_capture.py. Full-mirror directories are dated historical checkpoints, never a silent fallback for current input.

Guarded existing-source/primitive-attribute delivery: scripts/studio_delivery.py and scripts/studio_delivery.lua. AUDIT / APPLY / ROLLBACK generated into one task file; see [delivery runbook](proportional-mcp-delivery.md). Tests: scripts/test_studio_delivery.py and scripts/test_studio_delivery.luau. scripts/workflow_phase3/audit.lua is a frozen read-only example, not a pending game installer.

Reusable check recipes: scripts/validation_checks.json. Evidence init/check/handoff and artifact hashing: scripts/validation_record.py. Tests: scripts/test_validation_record.py. See [validation and handoffs](validation-and-handoffs.md); these are repository tools, not Studio installers. Reuse scripts/performance_phase1/runtime_sample.lua for bounded read-only Play measurements; scripts/performance_phase6/api_cycles.lua invokes APIs and is explicitly not UI evidence.
