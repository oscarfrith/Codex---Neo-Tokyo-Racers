# Complete cleanup Phase 2 support

The only Studio entry point is `../roblox_cleanup_phase2_canonical_ownership.lua`. It is already installed. See `docs/architecture/cleanup-phase2-canonical-ownership.md` for status and recovery.

`before/`, `baseline.json` and `hierarchy-before.json.gz` freeze the user-confirmed pre-phase state. They are repository recovery history, not current implementations and never coexist with current code in Studio. Do not rerun prepare.py against the migrated mirror.

Current source projection: `projection-index.json` and its listed files in `projected/`. `module-map.json` and `runtime-map.json` describe ownership migration. `explicit_edits.py` records individually guarded semantic edits and the dead-helper retirement list; `path_analysis.py` resolves literal instance path expressions conservatively.

To rebuild from the frozen baseline, run build_projection.py then build_installer.py with Python. The latter packages full before/after sources in payload.json and the standalone installer. Source anchor drift must fail rather than guessing. Any repair belongs in this one installer; roll back its currently installed exact payload before installing a changed payload.

Verification: run test_migration.py, refresh the Edit mirror with the repo receiver/exporter, then run ../verify_studio_mirror.py and verify_migration.py. `verification.json` records the final source/hierarchy/property parity; `mirror-differences.json` must be empty on both sides. `runtime-console.txt` records the successful repeated time-trial lifecycle smoke before the final catalog/reporting path corrections, which subsequently passed startup/GetInitial/LOD status checks. It is evidence, not executable source. Server/client runtime-before.json are normal Play baseline inventories.

The inspect/check/find scripts are local analysis helpers. finalize_repository.py is a one-time, guarded handoff update for this completed delivery, not part of rebuild or Studio installation. No support script should be executed wholesale simply because it is in this folder.
