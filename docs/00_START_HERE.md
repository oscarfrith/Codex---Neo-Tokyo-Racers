# Space Racers — start here

Target: **Space Racers v2, place 71491191583884** (since 2026-09-26; v1 121304917315753 is historical). The start screen in v2 reads "Pulse Racers 2098". Updated 2026-09-27. This is the sole current-status entry point; historical handoffs describe evidence at the time they were written.

## Current task and next action

**World build: South Grid (2026-09-28), in Oscar's test copy "09282026_3" (place 86391254062492), not on v2 yet.**
- **What:** the 12 blockout parcels south of the bay are replaced by a mix of The Blocks and Metabolist housing, built as `Workspace.World.City["Block S9"]` (11 LOD-structured blocks), with 6 shared skybridges and streetscape. The streetscape covers kerbs, the step wall with stairs and market, the waterfront promenade and piers, the west park and the east car-meet lot.
- **How:** contract [south-grid-build-contract](architecture/south-grid-build-contract.md); pipeline in `scripts/south_grid/`. The pipeline is: sgspec JSON specs → Blender previews → `install/assemble.lua`.
- **Studio state:**
  - The kit FBX is imported to `ReplicatedStorage.Assets.World.SouthGridKit`.
  - 7 new `SG *` MaterialVariants are in MaterialService.
  - Far proxies are in `FarLOD5Proxies/Block_S9_*_LOD5`.
  - The replaced blockout boxes are in `ServerStorage.SouthGridReplacedBlockout`.
- **Evidence:** agent-verified in Edit and in a Play test (streaming, LOD culling, no errors). Not yet driven or play-tested by Oscar.
- **Next:** Oscar reviews in the copy, then copies Block S9 and its dependencies to v2. The dependencies are the kit folder, the SG variants and the LOD5 proxies.

**Feature work (Street Life, [design](design/street-life-update.md)).** Handoff 2026-09-27. Oscar's map and jobs refinement batch is complete and installed on v2 ([contract](architecture/map-markers-contract.md)). Everything is agent-verified in Studio, mostly with synthetic movement. Oscar reviewed the results as they were delivered ("looks good"); this is not a formal play-test sign-off.

- **Full-screen map** (MAP-03):
  - Opens with M or a minimap click and covers the whole blockout; ALL/F zooms out to fit it all.
  - The legend is the map key only. Click the map to set a waypoint.
  - The other HUDs and the tutorial objectives hide while it is open.
- **Map art:**
  - 4x4 hi-res tiles (4096²).
  - Glyph-only icons at about 2x size with a refined outline.
  - Dealership and garage icons come from the HUD icons, in cyan. The customisation icon is hidden.
  - Job icons are stationary ([map art README](../scripts/map_art/README.md)).
- **Minimap:** zooms out with speed (1x to 1.8x). **Route line v2:** straight lines with rounded turns ([options](../scripts/route_guide/ROUTE_LINE_OPTIONS.md)).
- **World jobs** (RP-02, [contract](../scripts/activities/world_jobs/CONTRACT.md)):
  - 8 taxi fares and 6 parcels are spread across the whole blockout, with about 3x longer trips.
  - A replacement appears in a new area; no job sits within 350 studs of a place.
  - The prompt is on your own car. The fare sits inside the cockpit.
  - Pay is higher for speed and lower after crashes; nothing auto-starts.
  - There is no JOBS panel; cancel with the X on the job strip.
- **Onboarding fix:** returning players get their saved tutorial progress, not the new-player trail.
- **Earlier RP features** (RP-01): Driver Rank, Passengers, Garage visits, free Street Duels. Stakes stay off.
- **Suggestions:** [open-world improvements](design/open-world-improvements.md). Items from the 2026-09-27 list still open:
  - job info card on map click;
  - VIP and rush jobs;
  - streak bonus;
  - finish rating;
  - next-turn arrow;
  - key filters;
  - district labels;
  - in-world GPS chevrons;
  - Skip tutorial;
  - mobile pass;
  - decide the hourly job cap.

Next action: Oscar play-tests with real driving on desktop, then picks the next feature batch from the suggestions. Open checks:

- mobile (prompt, pinch zoom, icon sizes);
- two-client job accept race;
- job pay and hourly cap (focused play now reaches the $40k cap after about 40 min);
- queue: ECON-01, DATA-01/02.

Latest targeted capture: **2026-09-27**, [refine4 after](../roblox/captures/refine4-after/capture.json), v2, 213 sources, 6 roots (Config.UI, Modules.Game.UI, Game.Activities client and server, Config.Activities, Remotes.Activities). All 12 sources changed in this batch match the repo.

### Previous status

Continuous lighting is **user-confirmed** (2026-09-26: "all looks good for now"). The brighter sunrise/sunset, restrained moon glare, larger sun and five-second holds are installed and committed (aa158d1). The 720-second cycle and strong horizon rays are preserved. Warm copies use exposure 0.15, post brightness 0.055, contrast 0.12 and lighter Decay; twilight/night glare is 1.5/0.45. ContinuousSky SunAngularSize is 9. Warm holds last five real seconds total, centered on 06:00 and 18:00. [Editing guide](architecture/lighting-authoring.md), [delivery/recovery](architecture/lighting-horizon-moon-handoff.md).

Next action: start feature work in a new chat (`/design <idea>`, then `/follow`), using the [new feature checklist](architecture/architecture-programme.md#new-feature-checklist) and [Studio testing playbook](architecture/studio-testing-playbook.md). Quick wins first: fix PB-01 (sandbox PB writes) and switch RACE-01 to Enforce after real sessions show no [RACE-01] warnings. Before release: DATA-01/02 published persistence test, ECON-01, device/multiplayer gates. The architecture programme (P1-P9; P7 limited to the FOV/zoom owner) is installed, Studio-verified and user-confirmed working on 2026-09-26. [Programme reference](architecture/architecture-programme.md). Lighting user-confirmed; device/two-client lighting checks stay open under LIGHT-01. Committed and pushed; not published.

Latest targeted capture: **2026-09-26**, [sources after architecture P9](../roblox/captures/arch-p9-after/capture.json), 184 sources. Lighting capture: 2026-09-23 19:55:46 UTC, [after](../roblox/captures/lighting-horizon-moon-after/capture.json), 168 sources/138 selected nodes. Fresh [before](../roblox/captures/lighting-horizon-moon-before/capture.json) matched V6 exactly. This refinement changes thirteen existing attributes and one ContinuousSky property, with zero source changes or new objects/assets. Pre-existing Edit Lighting.SunRays properties (enabled, intensity approximately 0.566, spread 1) and all other selected state remain unchanged. Studio is in Edit, Continuous, duration 720, auto/sync true and opt-in tools off. Original shared presets/skies and the 900-second Stepped schedule remain intact. REFINE / REVERT_REFINEMENT preserve guarded recovery without rerunning installed migrations. Full mirror and earlier handoffs remain historical.

Primary assistant moved from Codex to **Claude Code** on 2026-09-26 (repository/workflow only; no Studio changes). [Setup and Studio MCP rules](architecture/claude-code-setup.md), [docs index](README.md). Read-only connection check that day: Space Racers v1, Edit, 168 inventoried sources.

Workflow improvement **all four phases implemented and verified**. [Approved four-phase plan](architecture/workflow-improvement-plan.md).
No workflow phase remains. Use the [validation and handoff procedure](architecture/validation-and-handoffs.md) for future work; [Phase 4 evidence](architecture/workflow-phase4-handoff.md). Performance Phase 6 remains a separate open effort, not automatically resumed by completing this programme.
Routine full mirrors are replaced by [targeted captures](architecture/targeted-capture-workflow.md). Full checkpoints remain available for broad migrations/recovery. That workflow programme changed tools/docs only; the later lighting delivery above changes game code.

## Installed game and acceptance

All five original architecture phases and four cleanup phases are user-confirmed. Performance Phases 1–5 are installed; after Phase 6 checks the user reported “all worked well.” Record that as general gameplay confirmation, not proof of individual device, camera, memory or persistence gates.
[Performance Phase 6 acceptance](architecture/performance-phase6-validation.md) remains open: camera errors, detached UI references, normal-flow/route tests, iPhone 7, 15-player/soak and isolated published persistence evidence. See the [open issue ledger](06_current_known_issues.md). No new game code was installed during validation.

Retained full checkpoint (historical, not routinely refreshed): **2026-09-22 13:14:39**, 165 sources, 44,465 nodes, 276,087 properties; exact expected Phase 5 parity and fresh catalogue/preview projections. Live targeted verification on 2026-09-22: vehicle capture 19:41:24 UTC, sources 19:43:01 UTC, config 19:43:46 UTC. All 165 source hashes still match that baseline; selected vehicle properties match, projections are fresh. No whole-world physical parity claim.
Evidence: roblox/captures/workflow-phase2-check-b/capture.json (vehicles), workflow-phase2-sources/capture.json (source inventory), workflow-phase2-config/capture.json (config), all under roblox/captures. Follow each manifest row to its versioned source blob.
Earlier source handoff: [catalogue transport](architecture/performance-phase5-catalogue-transport.md). The lighting handoff above supersedes its affected sources only. No installer run pending.

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

Latest tooling evidence: [proportional delivery](architecture/proportional-mcp-delivery.md). Read-only Phase 3 before/after captures under roblox/captures/workflow-phase3-sources and workflow-phase3-after show zero differences across all 165 inventoried sources. No gameplay changes.

Phase 4 changed repository validation tools/docs only. No new Studio capture or gameplay test was needed; prior source evidence remains dated, not a claim of fresh whole-place parity.
