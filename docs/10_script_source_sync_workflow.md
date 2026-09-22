# Studio snapshot workflow

Windows folder promotion retries sharing/access-lock errors for up to five seconds per rename, then retains the existing rollback behavior. Eleven pipeline tests pass, including transient and persistent lock cases. Never bypass failed import verification or claim a stale mirror is current. Catalogue freshness check: scripts/performance_phase4/check_projection.py.

Current as of cleanup Phase 4, 2026-09-22. Studio remains authoritative; exported files are evidence, not automatic sync inputs.

1. Verify Space Racers v1 (121304917315753), stop Play, and inspect baseline/Git.
2. Run py scripts/receive_studio_snapshot.py locally. Discover Python 3 or the bundled interpreter if py is absent; never copy another machine's cache path.
3. Execute scripts/studio_export_snapshot.lua in Edit through MCP or Command Bar.
4. Run scripts/verify_studio_mirror.py. For the current performance Phase 5 delivery also run scripts/performance_phase5/verify_migration.py. Older cleanup parity verifiers apply only after dependent phases are rolled back. Future intentional changes need their own baseline comparison.
5. Review diagnostics, update docs and commit both mirror directories. Never commit docs/studio-full-export-paste.txt.

Receiver-only transport: 127.0.0.1:8765/studio-snapshot-chunk, STUDIO_SNAPSHOT_V1 / STUDIO_SNAPSHOT_END framing, schema revision 3. Producer/receiver/importer must agree. No Studio dump/backup instances are created. Only explicit --write-paste writes the raw blob.

Importer inherits repository ACLs on Windows, validates source hashes/identity/schema and restores both prior outputs on ordinary promotion failure. Do not use private tempfile.mkdtemp staging. After power loss inspect retained .mirror-stage-*; promotion is not power-loss atomic.

The mirror captures sources, hierarchy, attributes and an explicit property allowlist; not a complete place/terrain backup. Tags require a live audit. Duplicate paths need multiset/scoped inspection.

Old filenames/protocol are archived under scripts/history/snapshot_before_cleanup_phase4 and are not active entry points. Prior documentation is in history/cleanup-phase4-prior-docs.
