# Space Racers — current baseline

Updated 2026-09-22. Target: Space Racers v1, place 121304917315753.

## Current delivery

All five original architecture phases and all four complete-cleanup phases are user-confirmed. The user reports committing and pushing Phase 4. Post-confirmation mirror **2026-09-22 11:00:13** passes exact source/hierarchy/property parity. See [Phase 4 handoff](architecture/cleanup-phase4-finalisation.md). No further cleanup phase has been added.

The [performance and replication plan](architecture/performance-and-replication-plan.md) has Phase 1 approved: [local audit and initial measurements delivered](architecture/performance-phase1-baseline.md). iPhone 7 is the selected baseline phone; real-device, representative route and 15-player measurements remain pending. No performance migration installed. Phase 2's six exact moves need approval. Latest mirror **2026-09-22 11:13:49** passes exact cleanup Phase 4 parity; gameplay and storage are unchanged.

User approved preserving 628 moved race-arrow parts and 66 new Workspace thumbnail-model records. Phase 4 preserves this September 22 physical baseline. Protected staging and Archive disposition remains unresolved.

## Current owners

ServerBase starts ServerStorage.Modules.Core/Game features. ClientBase starts ReplicatedStorage.Modules.Core/Game features. GarageUI owns garage UI; DriveSessionClient owns vehicle-session callbacks. Feature endpoints live under ServerStorage.Runtime and PlayerScripts.Runtime.

Canonical roots: ReplicatedStorage.Assets/Config/Remotes, ServerStorage.Assets, Workspace.World and ReplicatedFirst.Loading. Shared renderers, preview, VFX, driving, racing and LOD owners are unchanged. No forwarding adapters or in-game backups. Mobile orientation remains LandscapeSensor; development tools remain opt-in.

Studio replay/sandbox suppresses saving. CAM-02 predates cleanup. Device, multiplayer and published persistence checks remain separate release gates.

## Entry points

Read AGENTS, current issues, Phase 4 handoff and relevant topic docs. Check Git and list Studio instances afresh before writes. Current installed script: scripts/roblox_cleanup_phase4_finalise.lua. No manual run needed.

Read-only audits: scripts/studio_cleanup_audit.lua and scripts/audit_cleanup.py. Current export: scripts/receive_studio_snapshot.py followed by scripts/studio_export_snapshot.lua in Edit. Validate using scripts/verify_studio_mirror.py and scripts/cleanup_phase4/verify_migration.py. Evidence is scripts/cleanup_phase4/verification.json.

See [sync workflow](10_script_source_sync_workflow.md), [tool index](architecture/installer-index.md) and [owner map](architecture/naming-and-owners.md). Older current-baseline prose is archived under docs/history/cleanup-phase4-prior-docs. Historical run instructions are not a pending queue.
