# Space Racers — current baseline

Updated 2026-09-22. Target: Space Racers v1, place 121304917315753.

## Current delivery

All five original architecture phases and all four complete-cleanup phases are user-confirmed. The user reports committing and pushing Phase 4. Post-confirmation mirror **2026-09-22 11:00:13** passes exact source/hierarchy/property parity. See [Phase 4 handoff](architecture/cleanup-phase4-finalisation.md). No further cleanup phase has been added.

The [performance and replication plan](architecture/performance-and-replication-plan.md) has **Phase 4 installed and agent-verified; user playthrough pending**. Original full vehicle templates now live in ServerStorage.Assets.Vehicles; generated client preview copies omit only 333 upgrade-definition folders. ReplicatedStorage descendants: 4,313 -> 3,980. See [Phase 4 handoff](architecture/performance-phase4-vehicle-previews.md). Latest mirror **2026-09-22 12:47:08** verifies 164 sources, 44,464 nodes and 276,087 properties. Phase 3 was accepted for continuation; no specific visual/device tests inferred. Mesh/texture cost is unchanged and join/memory gains remain unmeasured. iPhone 7, route and 15-player gates remain pending. Phase 5 is next after acceptance.

User approved preserving 628 moved race-arrow parts and 66 new Workspace thumbnail-model records. Phase 4 preserves this September 22 physical baseline. Protected staging and Archive disposition remains unresolved.

## Current owners

ServerBase starts ServerStorage.Modules.Core/Game features. ClientBase starts ReplicatedStorage.Modules.Core/Game features. GarageUI owns garage UI; DriveSessionClient owns vehicle-session callbacks. Feature endpoints live under ServerStorage.Runtime and PlayerScripts.Runtime.

Canonical roots: ReplicatedStorage.Assets/Config/Remotes, ServerStorage.Assets/Config, Workspace.World and ReplicatedFirst.Loading. Profile schema/projection and vehicle writer modules are now server-only; Persistence, PersonalBests and Leaderboards settings live under ServerStorage.Config. Shared renderers, preview, VFX, driving, racing and LOD owners are unchanged. No forwarding adapters or in-game backups. Mobile orientation remains LandscapeSensor; development tools remain opt-in.

Studio replay/sandbox suppresses saving. CAM-02 predates cleanup. Device, multiplayer and published persistence checks remain separate release gates.

## Entry points

Read AGENTS, current issues, performance Phase 4 handoff and relevant topic docs. Check Git and list Studio instances afresh before writes. Current installed script: scripts/roblox_performance_phase4_vehicle_previews.lua. No manual run needed. Roll this phase back before older cleanup recovery.

Read-only audits: scripts/studio_cleanup_audit.lua and scripts/audit_cleanup.py. Current export: scripts/receive_studio_snapshot.py followed by scripts/studio_export_snapshot.lua in Edit. Validate using scripts/verify_studio_mirror.py and scripts/performance_phase4/verify_migration.py. Evidence is scripts/performance_phase4/verification.json.

See [sync workflow](10_script_source_sync_workflow.md), [tool index](architecture/installer-index.md) and [owner map](architecture/naming-and-owners.md). Older current-baseline prose is archived under docs/history/cleanup-phase4-prior-docs. Historical run instructions are not a pending queue.
