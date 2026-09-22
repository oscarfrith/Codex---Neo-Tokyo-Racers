# Space Racers — current baseline

Updated 2026-09-22. Target: Space Racers v1, place 121304917315753.

## Current delivery

**Current work: [Performance Phase 6 validation](architecture/performance-phase6-validation.md), acceptance OPEN.** Phase 5 accepted for continuation; gameplay code unchanged. Twenty short API cycles pass, but start-screen state remained active and they do not count as full gameplay cycles. CAM-02 reproduced; 111 detached UI buttons need lifecycle investigation. iPhone 7 and isolated multiplayer testing are unavailable. Latest mirror **2026-09-22 13:14:39** passes exact Phase 5 source/hierarchy/property parity and projection freshness. No installer to run; do not rerun earlier phases. Historical delivery figures below describe Phase 5 installation, not current acceptance.

All five original architecture phases and all four complete-cleanup phases are user-confirmed. The user reports committing and pushing Phase 4. Post-confirmation mirror **2026-09-22 11:00:13** passes exact source/hierarchy/property parity. See [Phase 4 handoff](architecture/cleanup-phase4-finalisation.md). No further cleanup phase has been added.

The [performance and replication plan](architecture/performance-and-replication-plan.md) has **Phase 5 installed and agent-verified; user playthrough pending**. GarageServer builds one immutable catalogue per session; GarageCatalogClient reuses it across existing callers while preserving fresh profile reads. Eight matched samples reduce warm response JSON from **177,251 to 3,956 bytes (97.8%)**; these are not compressed-wire or FPS measurements. See [Phase 5 handoff](architecture/performance-phase5-catalogue-transport.md). Latest mirror **2026-09-22 13:01:09** verifies 165 sources, 44,465 nodes and 276,087 properties. Phase 4 accepted for continuation; no specific device test inferred. Phase 6 iPhone 7, route, multiplayer and soak acceptance remains pending.

User approved preserving 628 moved race-arrow parts and 66 new Workspace thumbnail-model records. Phase 4 preserves this September 22 physical baseline. Protected staging and Archive disposition remains unresolved.

## Current owners

ServerBase starts ServerStorage.Modules.Core/Game features. ClientBase starts ReplicatedStorage.Modules.Core/Game features. GarageUI owns garage UI; DriveSessionClient owns vehicle-session callbacks. Feature endpoints live under ServerStorage.Runtime and PlayerScripts.Runtime.

Canonical roots: ReplicatedStorage.Assets/Config/Remotes, ServerStorage.Assets/Config, Workspace.World and ReplicatedFirst.Loading. Profile schema/projection and vehicle writer modules are now server-only; Persistence, PersonalBests and Leaderboards settings live under ServerStorage.Config. Shared renderers, preview, VFX, driving, racing and LOD owners are unchanged. No forwarding adapters or in-game backups. Mobile orientation remains LandscapeSensor; development tools remain opt-in.

Studio replay/sandbox suppresses saving. CAM-02 predates cleanup. Device, multiplayer and published persistence checks remain separate release gates.

## Entry points

Read AGENTS, current issues, performance Phase 5 handoff and relevant topic docs. Check Git and list Studio instances afresh before writes. Current installed script: scripts/roblox_performance_phase5_catalogue_transport.lua. No manual run needed. Roll this phase back before older cleanup recovery.

Read-only audits: scripts/studio_cleanup_audit.lua and scripts/audit_cleanup.py. Current export: scripts/receive_studio_snapshot.py followed by scripts/studio_export_snapshot.lua in Edit. Validate using scripts/verify_studio_mirror.py and scripts/performance_phase5/verify_migration.py. Evidence is scripts/performance_phase5/verification.json.

See [sync workflow](10_script_source_sync_workflow.md), [tool index](architecture/installer-index.md) and [owner map](architecture/naming-and-owners.md). Older current-baseline prose is archived under docs/history/cleanup-phase4-prior-docs. Historical run instructions are not a pending queue.
