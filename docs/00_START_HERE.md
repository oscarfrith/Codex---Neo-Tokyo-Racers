# Neo Tokyo Racers Project Context

Last updated: 2026-06-05

This folder is the handoff pack for new Codex or ChatGPT sessions. Read this file first, then use the other docs only as needed.

## Current Project

Neo Tokyo Racers is a Roblox open-world hover racing game with modular hovercars. The main vehicle category currently being built is `BRUISER`.

The vehicle system is category-based: cockpits and modules inside the same category share fixed slot locations, so modules can be swapped between similar cockpits.

## Current Script State

Known from chat:

- Architecture migration Phases 15-21 were committed after successful testing. Main client extraction Phase A-E later removed the final active legacy-named `HOVER_RACING` owner from live use.
- Main client extraction Phase A-E has passed. Phase D switched the active main client owner to `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`; Phase E audit passed cleanly with no active legacy-named `HOVER_RACING` scripts. The old `HOVER_RACING_V2_Client` is disabled and kept as rollback.
- Architecture Phase K completed successfully on 2026-05-29 at 17:31:59 in Studio: `ReplicatedStorage.HOVER_RACING_V2_KIT` contents moved into `ReplicatedStorage.NeoTokyoRacers`, 20 source objects patched, 112 replacements applied, and final legacy source hits were 0.
- Architecture Phase L completed successfully on 2026-05-29 at 17:35:09 in Studio: migrated folders were present, legacy source/ObjectValue references were 0, and `ReplicatedStorage.HOVER_RACING_V2_KIT` no longer exists.
- Architecture Phase N completed successfully on 2026-05-29 at 18:36:09 in Studio: 10 source objects patched, 24 replacements applied, stale ObjectValues repaired, `Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint` created, and final old runtime source hits were 0.
- World Phase F is prepared to move city blocks from `Workspace.GeneratedCityBlocks` into `Workspace.NeoTokyoRacersWorld.City.Block S#` and patch the active LOD client root resolver.
- World Phase J is prepared to move `ReplicatedStorage.FarLOD5` into `ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5Proxies` and patch the active LOD client far-proxy resolver.
- Cleanup Phase G is a read-only full hierarchy audit for identifying old inactive folders, disabled legacy scripts, rollback scripts, and report folders before any deletion script is generated.
- Cleanup Phase H is the targeted deletion phase for Phase G's confirmed inactive legacy items. It must be run in `DRY_RUN` first, then `DELETE` only after reviewing the exact path list.
- Cleanup Phase I is an aggressive one-step migration clutter cleanup. It deletes stale reports, reference ObjectValues, mirror-only generated config, non-live scaffold/shadow/snapshot code, and empty placeholder folders after confirming active owners are healthy.
- Cleanup Phase M is a post-K/L read-only audit for stale legacy kit references, empty compatibility folders, old reports, nil ObjectValues, and remaining cleanup candidates after `HOVER_RACING_V2_KIT` removal.
- Cleanup Phase O completed successfully. Final Phase M verification at 2026-05-29 18:55:53 showed 0 warnings, 0 missing required paths, 0 source legacy hits, 0 stale ObjectValues, 0 auto cleanup candidates, and 0 review-before-delete candidates.
- Architecture Phase P is present in the Git repo as the conservative first garage runtime startup repair, but it is superseded by Phase Q if the line 23 garage controller error remains.
- Architecture Phase Q repaired the post-Phase-N/P garage startup regression where `GarageActionController_Shadow_Disabled` errors near line 23 and the garage UI does not load. The user reported Phase Q worked.
- Lighting Phase R is prepared to repair `Fogcolor` typo warnings by changing lighting presets to Roblox's valid `FogColor` property and adding a compatibility alias in `LightingService_Active`.
- Vehicle Phase AI removes/deprioritises the cockpit car-light experiments from Phases S through AH. No cockpit SpotLight, Beam, smoother, projector, or diagnostic runtime should be considered current. Ordinary cosmetic neon colour channels remain.
- VFX Phase AJ is prepared to repair thrust VFX preview after Dealership Intro Phase 4 moved the local preview vehicle to `Workspace._NTR_ClientOnly.VehiclePreview`. Run `scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua` if thrust VFX no longer previews while editing thrust colour in the customisation menu.
- Dealership Intro Phases 1-7 were installed and confirmed working by the user on 2026-06-03. The flow now uses editable dealership markers, opens the full garage only at `GarageDeskTrigger`, delays the local preview until cockpit purchase/select succeeds, restores preview orbit camera behavior, spawns the final drivable vehicle from `VehicleExitSpawnPoint`, and includes an Exit button that only reopens after the player leaves and re-enters the desk zone. Phase 8 is generated in Git as the next Studio install/test step: it replaces fixed path arrows with a dynamic client-only arrow tether to the desk and persists first desk-objective completion.
- Phase 15 successfully moved live server action ownership to `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled`. The old `HOVER_RACING_V2_Server` remains available for rollback but is no longer the live server action owner.
- `V74` restored the pre-V72/default Roblox driving camera feel and added a light camera assist. The user confirmed this worked well.
- `V75` was generated next to add boost recharge delay and low-speed hover wobble. At the time of writing, no later user confirmation is present in this chat history.
- Character sprint install was run and reported working on 2026-06-04. The live runtime hierarchy now includes `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.CharacterSprintController_Active`; Shift sprint works on foot and Shift drift remains available while seated in a `VehicleSeat`. Mobile auto-sprint support is prepared in the installer and needs mobile/emulator verification.

Recommended baseline:

- Server action owner baseline: `GarageActionController_Shadow_Disabled` is currently the tested live owner after Phase 15.
- Dealership intro baseline: Phases 1-7 are the current tested startup/customisation flow. Phase 8 is prepared but needs Studio/DataStore play-test confirmation before treating it as stable. Use `docs/dealership-intro-flow-2026-06-03.md` before changing garage startup, preview timing, desk open behavior, objective persistence, or final vehicle spawn placement.
- Use `scripts/roblox_hover_racing_v74_pre_v72_camera_assist.lua` if camera stability is the priority.
- Use `scripts/roblox_hover_racing_v75_boost_delay_hover_wobble.lua` as the latest generated patch, then play-test fresh in Roblox Studio.
- Use `scripts/roblox_character_sprint_controller_install.lua` to install or roll back the on-foot sprint controller. It writes tuning attributes under `ReplicatedStorage.NeoTokyoRacers.Shared.Config.CharacterMovement_EditAttributes`.

## Important Working Style

- Prefer small command-bar scripts that modify one system at a time.
- Do not create in-game backup copies unless explicitly asked. Roblox version history is the preferred backup.
- Avoid large fragile patches against the main client script when a ModuleScript replacement or config folder can solve it.
- If a patch depends on a specific older script shape and may fail, say that before writing the script.

## Quick Links

- Current mechanics index: `docs/current-mechanics.md`
- Prompt pack for ChatGPT/Codex workflows: `prompts/README.md`
- Architecture reorganisation plan: `docs/architecture-reorganisation-plan.md`
- Game overview: `docs/01_game_overview.md`
- Vehicle folders/assets: `docs/02_vehicle_folder_system.md`
- Driving mechanics: `docs/03_driving_mechanics.md`
- Customisation UI: `docs/04_customisation_ui.md`
- VFX system: `docs/05_vfx_system.md`
- Known issues: `docs/06_current_known_issues.md`
- Patch history: `docs/07_patch_history.md`
- Script source sync workflow: `docs/10_script_source_sync_workflow.md`
- Manual script copy map: `docs/11_manual_script_copy_map.md`
- Script architecture review: `docs/script-architecture-review-2026-05-28.md`
- Phase 5 UI migration plan: `docs/phase5-ui-migration-plan-2026-05-28.md`
- Phase 7 shared UI helpers: `docs/phase7-shared-ui-helpers-2026-05-28.md`
- Phase 8 client UI controller scaffold: `docs/phase8-client-ui-controller-scaffold-2026-05-28.md`
- Phase 9 server services scaffold: `docs/phase9-server-services-scaffold-2026-05-28.md`
- Phase 10 runtime controller scaffold: `docs/phase10-runtime-controller-scaffold-2026-05-28.md`
- Phase 11 architecture readiness audit: `docs/phase11-architecture-readiness-audit-2026-05-28.md`
- Phase 12 server action snapshot: `docs/phase12-server-action-snapshot-2026-05-28.md`
- Phase 13 server parity harness: `docs/phase13-server-parity-harness-2026-05-28.md`
- Phase 14 server shadow action controller: `docs/phase14-server-shadow-action-controller-2026-05-28.md`
- Phase 15 server action owner switch: `docs/phase15-server-action-owner-switch-2026-05-28.md`
- Phase 16 runtime helper owner switch: `docs/phase16-runtime-helper-owner-switch-2026-05-28.md`
- Phase 17 driver seat owner switch: `docs/phase17-driver-seat-owner-switch-2026-05-28.md`
- Phase 18 LOD client owner switch: `docs/phase18-lod-client-owner-switch-2026-05-28.md`
- Phase 19 lighting service owner switch: `docs/phase19-lighting-service-owner-switch-2026-05-28.md`
- Phase 20 thrust preview owner switch: `docs/phase20-thrust-preview-owner-switch-2026-05-28.md`
- Phase 21 post-switch architecture audit: `docs/phase21-post-switch-architecture-audit-2026-05-28.md`
- Main client extraction plan: `docs/main-client-extraction-plan-2026-05-29.md`
- Main client Phase A core boundary: `docs/main-client-phaseA-core-boundary-2026-05-29.md`
- Main client Phase B preview/colour modules: `docs/main-client-phaseB-preview-colour-2026-05-29.md`
- Main client Phase C garage screen controllers: `docs/main-client-phaseC-garage-screens-2026-05-29.md`
- Main client Phase D owner switch: `docs/main-client-phaseD-owner-switch-2026-05-29.md`
- Main client Phase E post-switch audit: `docs/main-client-phaseE-post-switch-audit-2026-05-29.md`
- World Phase F city hierarchy and LOD migration: `docs/world-phaseF-city-hierarchy-lod-migration-2026-05-29.md`
- World Phase J Far LOD5 assets migration: `docs/world-phaseJ-far-lod5-assets-migration-2026-05-29.md`
- Architecture Phase K kit migration: `docs/architecture-phaseK-hover-kit-migration-2026-05-29.md`
- Architecture Phase L final kit removal: `docs/architecture-phaseL-final-hover-kit-removal-2026-05-29.md`
- Architecture Phase N runtime world path repair: `docs/architecture-phaseN-runtime-world-path-repair-2026-05-29.md`
- Architecture Phase P garage runtime startup repair: `docs/architecture-phaseP-garage-runtime-startup-repair-2026-06-02.md`
- Architecture Phase Q garage controller header repair: `docs/architecture-phaseQ-garage-controller-header-repair-2026-06-02.md`
- Lighting Phase R FogColor property repair: `docs/lighting-phaseR-fogcolor-property-repair-2026-06-02.md`
- VFX Phase AJ thrust preview root repair: `docs/vfx-phaseAJ-thrust-preview-root-repair-2026-06-05.md`
- Vehicle Phase AI cockpit light system removal: `docs/vehicle-phaseAI-cockpit-light-system-removal-2026-06-03.md`
- Dealership intro flow marker setup: `docs/dealership-intro-flow-2026-06-03.md`
- Character sprint controller handoff: `docs/character-sprint-controller-2026-06-04.md`
- Cleanup Phase G full hierarchy audit: `docs/cleanup-phaseG-full-hierarchy-audit-2026-05-29.md`
- Cleanup Phase H legacy inactive deletion: `docs/cleanup-phaseH-delete-legacy-inactive-items-2026-05-29.md`
- Cleanup Phase I aggressive migration cleanup: `docs/cleanup-phaseI-aggressive-migration-cleanup-2026-05-29.md`
- Cleanup Phase M post kit migration audit: `docs/cleanup-phaseM-post-kit-migration-audit-2026-05-29.md`
- Cleanup Phase O stale metadata/report cleanup: `docs/cleanup-phaseO-stale-metadata-report-cleanup-2026-05-29.md`
- Compressed architecture roadmap: `docs/compressed-architecture-roadmap-2026-05-28.md`

## Diagrams

- `diagrams/vehicle_asset_system.svg`
- `diagrams/driving_runtime_system.svg`
