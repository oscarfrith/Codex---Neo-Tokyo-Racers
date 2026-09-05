# Phase 2 maintenance

Edit ProfileStore.lua, GarageRequestGuard.lua or the exact integration transforms in build_installer.py. Run `python scripts/architecture_phase2/build_installer.py` from the repository. The builder reads two immutable pre-phase Git blobs (requires repository history), generates the canonical installer and the isolated test runner, and never edits the generated Studio mirror. Do not edit both mirror source and helper source independently.

Run the generated safety tests in Studio Edit through MCP, then the canonical installer. It checks the entire expected source fingerprint and enabled state, stages and compiles both changes, and creates only two helper modules. AUDIT is read-only. ROLLBACK reverses source edits and removes those exact modules; it refuses intervening source changes. There are no in-game backups. Use the existing snapshot receiver/exporter afterward.

The fixed 180-second lease and 60-second renewal interval are private safety constants, not gameplay tuning. Production DataStore name and enablement are pinned at session creation; changing the config cannot turn a temporary/sandbox session into a writer. Renewal uses the latest encoded profile even when clean (approximately one write/minute/player). Store calls can outlive local deadlines; callback cancellation fences late writes, and the shutdown wait is bounded rather than claiming network cancellation.

Do not publish over old live profile writers. Drain old servers before deploying or rolling back. Test real save/rejoin in an isolated published place before release; current Studio sandbox deliberately suppresses profile writes. Existing racing PB and intro stores are separate owners, unchanged in this phase.
