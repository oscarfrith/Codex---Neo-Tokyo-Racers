# Space Racers — start here

Target: Space Racers v1, place **121304917315753**. Updated 2026-09-22. This is the sole current-status entry point; historical handoffs describe evidence at the time they were written.

## Current task and next action

Workflow improvement **Phase 1: documentation consolidation complete**. [Approved four-phase plan](architecture/workflow-improvement-plan.md).
Next approved step is **workflow Phase 2: targeted capture**, when the user asks to continue. Do not confuse this with performance Phase 6.
Full-mirror policy remains in force for Studio changes until Phase 2 replaces its dependencies. This documentation-only phase needs no Studio execution/export.

## Installed game and acceptance

All five original architecture phases and four cleanup phases are user-confirmed. Performance Phases 1–5 are installed; after Phase 6 checks the user reported “all worked well.” Record that as general gameplay confirmation, not proof of individual device, camera, memory or persistence gates.
[Performance Phase 6 acceptance](architecture/performance-phase6-validation.md) remains open: camera errors, detached UI references, normal-flow/route tests, iPhone 7, 15-player/soak and isolated published persistence evidence. See the [open issue ledger](06_current_known_issues.md). No new game code was installed during validation.

Last verified mirror: **2026-09-22 13:14:39**, 165 sources, 44,465 nodes, 276,087 properties; exact expected Phase 5 parity and fresh catalogue/preview projections. This is a dated observation, not a claim that live Studio was checked this session.
Current source handoff: [catalogue transport](architecture/performance-phase5-catalogue-transport.md). No installer run pending.

## Owners and boundaries

ServerBase starts ServerStorage.Modules.Core/Game; ClientBase starts ReplicatedStorage.Modules.Core/Game. GarageUI owns UI; DriveSessionClient owns vehicle callbacks; feature endpoints are ServerStorage.Runtime and PlayerScripts.Runtime.
Full vehicle templates live in ServerStorage.Assets.Vehicles; public definitions and generated preview geometry remain replicated. See [vehicle authoring](02_vehicle_folder_system.md).
Preserve the September 22 physical baseline: 628 moved race-arrow parts and 66 added thumbnail records. Workspace work remains limited to World plus the previously approved exact two lighting-tag exceptions. Protected staging/Archive disposition is unresolved.
Protected roots: ServerStorage.NeoTokyoRacers.VehiclePerformanceV2_Staging and ServerStorage.Archive. Their historical names are not permission to delete physical assets.
Studio replay/sandbox suppresses saving; opt-in tools remain off; mobile orientation remains LandscapeSensor.

## Read by task

- Delivery, testing, recovery and Git: [workflow](13_efficient_feature_delivery_protocol.md).
- Scripts/export/verifiers: [tool index](architecture/installer-index.md); [snapshot procedure](10_script_source_sync_workflow.md).
- Systems: [vehicles](02_vehicle_folder_system.md), [driving](03_driving_mechanics.md), [UI](04_customisation_ui.md), [VFX/audio](05_vfx_system.md), [world/LOD](world-streaming-and-lod.md).
- New/expanded systems: [readiness](14_new_system_readiness_standard.md), [contract](15_new_system_contract_template.md).
- History and decisions: [patch history](07_patch_history.md), [lesson index](12_continuous_improvement_workflow.md), [owner map](architecture/naming-and-owners.md).

Read only relevant historical entries when investigating a regression or recovery. Never infer a run queue from historical installers.
