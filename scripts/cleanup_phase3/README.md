# Phase 3 canonical migration support

Complete cleanup Phases 1, 2 and 3 are installed and user-confirmed. Phase 4 remains unimplemented. Current mirror: 2026-09-05 16:06:57, 160 sources, 42,285 nodes and 266,840 properties, with exact expected source/hierarchy/property parity. The two lighting-tag renames on 62 enumerated WIP objects are approved and installed. Protected staging/archive disposition remains pending.

- Canonical Studio installer: ../roblox_cleanup_phase3_generic_naming.lua. Already installed through MCP; use AUDIT for inspection, ROLLBACK only for deliberate recovery.
- before/, baseline.json and hierarchy-before.json.gz are immutable repository recovery evidence, not an in-game implementation.
- build.py and source_edits.py generate reviewed whole-source projections; package.py builds payload.json and the canonical installer from installer.lua. Exact guarded anchors are used locally; Studio preflights the full source.
- check_projection.py verifies numeric tokens, external identifiers and scoped path references. Two server-created GarageSessionRequest references and one absent optional CameraAssist config are classified exceptions.
- test_contracts.py has six narrow contract tests.
- verify_migration.py and verification.json verify the final Phase 3 mirror with zero unexplained differences.
- verify_restored_baseline.py and restored-baseline-verification.json record the earlier exact restored Phase 2 comparison; this is historical recovery evidence.
- wip-lighting-tags.json is the authorised 62-object two-tag exception; no other WIP edits are allowed.
- Broad inventory keyword candidates contain false positives and must never be treated as a bulk replacement/deletion list.
