# MCP delivery and verification

Current: performance Phase 2 installed, 2026-09-22; user playtest pending. Cleanup phases are confirmed.

1. Read AGENTS, startup/issues and relevant owner/topic docs. Check Git and list Studio instances afresh. Target Space Racers v1, 121304917315753.
2. Confirm Edit/Play mode and live parity. Source audit alone cannot prove physical parity: the arrival export revealed user-approved arrow movement and thumbnail content despite all sources matching.
3. Use one scoped canonical installer with exact preflight, compilation, repeat audit and rollback. No gameplay require through MCP; inspect normal ServerBase/ClientBase StartupState.
4. Run proportional normal runtime tests in the sandbox; preserve data protections. Keep Studio visible during input tests. No publishing without separate approval.
5. Stop Play; run scripts/receive_studio_snapshot.py locally, then scripts/studio_export_snapshot.lua. Validate with verify_studio_mirror.py and the applicable phase verifier.
6. Inspect diffs, record tested versus user-confirmed status, update current docs and provide commit text. Never commit docs/studio-full-export-paste.txt.

Current read-only audit: scripts/studio_cleanup_audit.lua. Local naming audit: scripts/audit_cleanup.py. Current exact source/property comparison: scripts/performance_phase2/verify_migration.py. Older exact-baseline verifiers require dependent phase rollback first. Full workflow/limitations: ../10_script_source_sync_workflow.md.

No hot reload, duplicate startup owners, automatic mirror-to-Studio syncing or persistent backup instances. Exporter/receiver failure must stop without creating in-game source dumps. Staging must inherit repository ACLs so GitHub Desktop can read the promoted mirror.

The mirror is not a full place backup. It has an explicit property allowlist and no CollectionService tag export. Tags are separately live-audited. Duplicate paths are multisets, not uniquely addressable names. Current evidence: scripts/performance_phase2/verification.json and runtime-verification.json. Historical workflow: ../history/cleanup-phase4-prior-docs/mcp-workflow.md.
