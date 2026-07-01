# Neo Tokyo Racers Project Context

Last updated: 2026-07-01

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
- Lighting Phase AP was installed and user-confirmed working. Building window
  MeshParts now use `Windows Day` / `Windows Night` MaterialVariants and switch
  with lighting mode. Separate Command Bar scripts preview either complete
  condition in Studio edit mode.
- Vehicle Phase AI removes/deprioritises the cockpit car-light experiments from Phases S through AH. No cockpit SpotLight, Beam, smoother, projector, or diagnostic runtime should be considered current. Ordinary cosmetic neon colour channels remain.
- VFX Phase AJ is prepared to repair thrust VFX preview after Dealership Intro Phase 4 moved the local preview vehicle to `Workspace._NTR_ClientOnly.VehiclePreview`. Run `scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua` if thrust VFX no longer previews while editing thrust colour in the customisation menu.
- VFX baseline was restored from the repo mirror after the late-socket/rescan repair sequence caused memory growth and VFX cut-outs. The confirmed follow-up is `scripts/roblox_vfx_mobile_delayed_attach_once.lua`, which delays mobile-only `VehicleVFXController.Attach` briefly and then performs one attach pass without continuous rescans or rebuild loops. The user reported VFX working again after this sequence.
- Vehicle Phase AK was installed and confirmed working through its follow-up repairs. Bruiser modules now use per-cockpit Standard/Lightweight/Power front engine, rear engine, stabiliser, and boost sets plus Lvl 1-3 bumpers/spoilers/side pods. Cockpit purchase grants standard core modules, dealership stats include them, required modules are gated, camera entry views are corrected, per-cockpit default colours live on cockpit attributes, and spawned module colours match preview.
- Vehicle Phase AL was installed and its read-only audit passed on 2026-06-08: 5 cockpits, 72 active modules, 23 planned upgrades, and 0 warnings.
- Vehicle Phase AM was installed and confirmed working on 2026-06-08. The isolated `VehiclePerformanceRuntimeService_Active` writes complete-build raw/normalized/headline/rating data; the audit passed `17/17`, `17/17`, `6/6`, and 0 warnings with a test rating of `D 407`. Detailed-variable V75 physics was then enabled and reported working well.
- Vehicle Phase AN was installed and confirmed working on 2026-06-08. Module-ID-scoped Fuel Injection level 1 cost `$4000`, changed the profile rating from `D 407` to `D 410`, reached the spawned engine as EngineOutput `+2` and TopSpeed `+1`, and passed the spawned-effect audit with 0 warnings.
- Vehicle Phase AO was installed and confirmed working on 2026-06-08. The visible legacy Brakes, Converter, Fuel System, and generic upgrade controls are replaced by per-module Performance cards, next-level previews, and purchases through the confirmed Phase AN action. The stats panel now keeps the E-S tier/index visible and shows contextual detailed variables for the selected module.
- Dealership Intro Phases 1-7 were installed and confirmed working by the user on 2026-06-03. The flow now uses editable dealership markers, opens the full garage only at `GarageDeskTrigger`, delays the local preview until cockpit purchase/select succeeds, restores preview orbit camera behavior, spawns the final drivable vehicle from `VehicleExitSpawnPoint`, and includes an Exit button that only reopens after the player leaves and re-enters the desk zone. Phase 8 is generated in Git as the next Studio install/test step: it replaces fixed path arrows with a dynamic client-only arrow tether to the desk and persists first desk-objective completion.
- Dealership cockpit module-slots text removal was installed and confirmed working. `scripts/roblox_dealership_remove_cockpit_module_slots_text.lua` removes the overlapping module count text from the cockpit selection stats panel without changing stats, purchase/select, or Build Modules behavior.
- Phase 15 successfully moved live server action ownership to `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled`. The old `HOVER_RACING_V2_Server` remains available for rollback but is no longer the live server action owner.
- `V74` restored the pre-V72/default Roblox driving camera feel and added a light camera assist. The user confirmed this worked well.
- `V75` was generated next to add boost recharge delay and low-speed hover wobble. At the time of writing, no later user confirmation is present in this chat history.
- Character sprint install was run and reported working on 2026-06-04. The live runtime hierarchy now includes `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.CharacterSprintController_Active`; Shift sprint works on foot and Shift drift remains available while seated in a `VehicleSeat`. Mobile auto-sprint support is prepared in the installer and needs mobile/emulator verification.
- The fixed mobile steering thumbstick V1 is installed and the user likes its current behavior/UI. The current design uses an outer drift ring with `1.8x` the inner radius, a darker translucent band, light-green idle cues, coordinated red drift cues, full outer-edge pointer travel, and `1.275x` frameless pedals. Installed V2/V2.1 places should run `scripts/roblox_mobile_drive_thumbstick_v2_2_drift_feedback.lua`.
- Mobile thumbstick V2.4 is installed and user-confirmed working well. It keeps zero deadzone/linear steering, enlarges the inner circle to `1.4x`, makes the outer drift ring `1.35x` the enlarged inner circle, and triggers drift at `0.95x` outer-ring travel with a `0.88` exit threshold.
- Persistence Phase 1 was installed in Studio and its audit passed on 2026-06-30. It added `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.PlayerProfileSchema` and `ReplicatedStorage.NeoTokyoRacers.Shared.Config.Persistence_EditAttributes` for instance-based cockpit/module ownership, two starting garage spaces, visitable garage access modes, and DataStore-safe encode/decode helpers. It does not switch active garage actions or write DataStores yet.
- Persistence Phase 2 was installed in Studio and its server audit passed on 2026-06-30. It installs `ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active`, keeps `DataStoreEnabled = false` by default, and exposes server BindableFunctions for future garage-profile bridge phases without patching the active garage action owner.
- Persistence Phase 3 was installed in Studio and its server audit passed on 2026-06-30. It installs `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.LegacyGarageProfileMapper` and `ServerScriptService.NeoTokyoRacers.Services.Player.LegacyGarageProfileBridge_Active` to convert the current V56 session-memory profile shape into the new instance-based profile schema.
- Persistence Phase 4 was installed in Studio and all audits passed on 2026-06-30. It patches `GarageActionController_Shadow_Disabled` to mirror the current V56 session profile into `ProfileService_Active` after `GetInitial` and successful garage actions. The current V56 profile remains the live source of truth; ProfileService receives converted snapshots only.
- Persistence Phase 5 was installed/tested in Studio and passed on 2026-06-30 after the `ImportProfileSnapshot` repair. Mirrored ProfileService snapshots can be saved/loaded through DataStore when Studio API access is enabled. It still does not make ProfileService the live garage source of truth.
- Persistence Phase 6 was installed in Studio and worked as expected on 2026-06-30. It patches `GarageActionController_Shadow_Disabled` so buying a new cockpit is blocked when the current V56 owned cockpit count reaches `Persistence_EditAttributes.StartingGarageCapacity`, default 2. Already-owned cockpit selection still works.
- Persistence Phase 7 was installed in Studio and worked as expected on 2026-06-30. It adds tunable upgrade cost/max/step config attributes, an `UpgradeGarageCapacity` garage action, Garage capacity data in profile responses, and mapper support so upgraded capacity mirrors into ProfileService snapshots.
- Persistence Phase 8 was installed and worked functionally, but its first `Garage Spaces` panel overlapped the left Categories panel. Phase 9 supersedes its visible layout and changes the direction from generic upgrades to physical garage-property purchases.
- Persistence Phase 9 was installed but caused the active client bootstrap to exceed Roblox's 200 local-register limit at `V75Driving`. Run the Phase 9 register-limit repair before retesting. The intended Phase 9 behavior moves the compact `Garage Spaces` panel beside the cash panel, removes the old next-price line, changes the button to `Buy More`, opens a garage-card menu, and seeds `GaragePropertyCatalog` for future server-owned garage locations.
- Persistence Phase 10 was installed and worked as expected. It stacks `Garage Spaces` above `Available Cash`, shrinks Categories around the left-column stack, and adds a 30% black modal backdrop behind the garage property menu.
- Persistence Phase 11 was installed and worked as expected. `Garage Spaces` is visible only on the cockpit-selection screen and hides during paint, module building, and customisation.
- Persistence Phase 12 was installed and worked as expected. It extracts the garage property menu card rendering into `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GaragePropertyMenuController` and leaves the active bootstrap with a small bridge so future garage-card work does not bloat the main client script.
- Persistence Phase 13 was installed through the repair path and the client smoke confirmed the core purchase/mirror/controller path on 2026-07-01. It adds real `BuyGarageProperty` server ownership, purchasable prices in `GaragePropertyCatalog`, `OwnedGarageProperties` profile/mirror data, capacity calculated from owned properties while preserving old Phase 7 capacity upgrades, and switches `GaragePropertyMenuController` from the temporary `UpgradeGarageCapacity` backend to `BuyGarageProperty`. The smoke test now treats the visual garage UI check as optional when the player has not reached the dealership desk yet.
- Persistence Phase 14 was installed and reported working well on 2026-07-01. It adds instance-backed `Vehicles`, `CurrentVehicleId`, `OwnedCockpitInstances`, and `OwnedModuleInstances` fields to the active garage profile while preserving the existing legacy UI fields. It adds direct server actions for `BuyCockpitInstance`, `BuyModuleInstance`, and `EquipModuleInstance`.
- Persistence Phase 15 was installed and reported working well on 2026-07-01. It adds visible duplicate-copy UI: owned cockpits show copy counts and `Buy Another`, and owned module options can `Equip Copy` or `Buy Copy` through the Phase 14 instance actions.
- Persistence Phase 16 was installed and its scripts worked well on 2026-07-01, but the module picker needs follow-up fixes: front/rear engine filtering, owned-vs-buy module menu separation, and per-instance owned module cards.
- Persistence Phase 17 is prepared in Git as the follow-up repair. It keeps Phase 16 source-cockpit purchase locks, restores front/rear engine slot filtering, adds `OWNED MODULES` / `BUY MODULES` bottom menu buttons, shows owned module copies as separate cards, removes `Buy Copy` / `Equip Copy` / `No Free Copy`, and previews locked buy modules on click.

Recommended baseline:

- Server action owner baseline: `GarageActionController_Shadow_Disabled` is currently the tested live owner after Phase 16. Phase 17 is prepared but not yet Studio-tested.
- Dealership intro baseline: Phases 1-7 are the current tested startup/customisation flow. Phase 8 is prepared but needs Studio/DataStore play-test confirmation before treating it as stable. Use `docs/dealership-intro-flow-2026-06-03.md` before changing garage startup, preview timing, desk open behavior, objective persistence, or final vehicle spawn placement.
- Use `scripts/roblox_hover_racing_v74_pre_v72_camera_assist.lua` if camera stability is the priority.
- Use `scripts/roblox_hover_racing_v75_boost_delay_hover_wobble.lua` as the latest generated patch, then play-test fresh in Roblox Studio.
- Use `scripts/roblox_character_sprint_controller_install.lua` to install or roll back the on-foot sprint controller. It writes tuning attributes under `ReplicatedStorage.NeoTokyoRacers.Shared.Config.CharacterMovement_EditAttributes`.
- Use `scripts/roblox_mobile_drive_thumbstick_v2_visual_refinement.lua` on the installed V1 mobile controller as the next mobile UI test. It is a guarded exact-source follow-up; refresh the Studio mirror after running it.
- Current mobile controls baseline is `scripts/roblox_mobile_drive_thumbstick_v2_4_large_edge_drift.lua`, installed and confirmed working.
- Current VFX baseline is the restored mirror source plus `scripts/roblox_vfx_mobile_delayed_attach_once.lua`, installed and confirmed working. Keep `scripts/roblox_vfx_restore_mirror_known_good_baseline.lua` as the rollback/recovery script for this VFX sequence.
- Do not reintroduce the removed VFX late-socket/rescan/rebuild repair ladder unless deliberately reproducing the failed experiment. That direction caused or failed to resolve RuntimeVFXController memory growth, 3-5 second cut-outs, frozen all-on VFX, or unparented Beam buildup.
- Use `scripts/roblox_dealership_remove_cockpit_module_slots_text.lua` to remove the overlapping "Module Slots" count text from the dealership cockpit selection panel. It is a guarded exact-source UI cleanup; refresh the Studio mirror after running and confirming it.
- Use `scripts/roblox_ui_shared_theme_back_exit_and_intro.lua` to add configurable `Back` and `Exit` colours to the shared UI theme and make the dealership intro objective use the same theme as the dealership UI. It is a guarded exact-source UI patch; refresh the Studio mirror after running and confirming it.
- Phase AK is installed. Keep its main installer and targeted repair scripts as recovery/history tools; do not rerun them on the confirmed live baseline unless the matching problem returns. These scripts use guarded source text replacement.
- Phases AL-AO are the confirmed current vehicle performance/customisation baseline. Do not rerun their installers on the working place unless recovering from a matching rollback. The Studio mirror was refreshed on 2026-06-30 at 17:37:33 and imported 65 scripts, including the confirmed mobile thumbstick, UI theme, lighting, and VFX delayed attach-once changes.
- If Phase 9 has been installed and the client reports `Out of local registers ... V75Driving`, run `scripts/roblox_persistence_phase9_register_limit_repair.lua`, then `scripts/roblox_persistence_phase9_register_limit_repair_audit.lua`, then restart Play and run `scripts/roblox_persistence_phase9_garage_property_menu_client_smoke.lua` from the CLIENT Command Bar.
- Use `scripts/roblox_persistence_phase10_garage_ui_layout_modal.lua` after the Phase 9 register repair to fix left-column stacking and add the garage property modal backdrop. Then run `scripts/roblox_persistence_phase10_garage_ui_layout_modal_audit.lua`, enter Play mode, and run `scripts/roblox_persistence_phase10_garage_ui_layout_modal_client_smoke.lua` from the CLIENT Command Bar.
- Use `scripts/roblox_persistence_phase11_garage_spaces_cockpit_only.lua` after Phase 10 if the Garage Spaces panel appears during customisation. Then run `scripts/roblox_persistence_phase11_garage_spaces_cockpit_only_audit.lua`, enter Play mode, and run `scripts/roblox_persistence_phase11_garage_spaces_cockpit_only_client_smoke.lua` from the CLIENT Command Bar.
- Use `scripts/roblox_persistence_phase12_garage_property_menu_controller_extract.lua` after Phase 11 to move the garage property menu rendering into a dedicated controller module. Then run `scripts/roblox_persistence_phase12_garage_property_menu_controller_audit.lua`, enter Play mode, and run `scripts/roblox_persistence_phase12_garage_property_menu_controller_client_smoke.lua` from the CLIENT Command Bar.
- Phase 13 is installed on the current Studio place. Do not rerun `scripts/roblox_persistence_phase13_garage_property_ownership.lua` or `scripts/roblox_persistence_phase13_garage_property_ownership_repair.lua` unless recovering from a matching rollback. To recheck it, enter Play mode and run `scripts/roblox_persistence_phase13_garage_property_ownership_client_smoke.lua` from the CLIENT Command Bar, then manually open the garage at the dealership desk to verify the `Buy More` gallery.
- Use `scripts/roblox_persistence_phase14_instance_inventory_bridge.lua` after Phase 13 to add the duplicate-capable instance inventory bridge. Then enter Play mode and run `scripts/roblox_persistence_phase14_instance_inventory_client_smoke.lua` from the CLIENT Command Bar. This is a guarded server-controller patch; if it aborts on a missing source anchor, refresh the Studio mirror before writing another Phase 14 patch.
- Use `scripts/roblox_persistence_phase15_duplicate_copy_ui.lua` after Phase 14 to expose duplicate cockpit/module copy controls in the current dealership UI. Then enter Play mode and run `scripts/roblox_persistence_phase15_duplicate_copy_ui_client_smoke.lua` from the CLIENT Command Bar. This is a guarded client-bootstrap patch; if it aborts on a missing source anchor, refresh the Studio mirror before writing another Phase 15 UI patch.
- Use `scripts/roblox_persistence_phase16_module_family_locks_and_sorting.lua` after Phase 15 to lock module purchases behind their source cockpit family, keep included starter modules as one attached set per cockpit instance, charge for extra Standard copies, and sort module cards owned-first with locked modules on the far right. Then enter Play mode and run `scripts/roblox_persistence_phase16_module_family_locks_and_sorting_client_smoke.lua` from the CLIENT Command Bar. This is a guarded server/client text patch; if it aborts on a missing source anchor, refresh the Studio mirror before writing another Phase 16 patch.
- Use `scripts/roblox_persistence_phase17_module_owned_buy_tabs.lua` after Phase 16 to split the module picker into `OWNED MODULES` and `BUY MODULES`, show owned copies as separate instance cards, remove copy wording, and enforce front/rear engine filtering. Then enter Play mode and run `scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua` from the CLIENT Command Bar. This is a guarded server/client text patch; if it aborts on a missing source anchor, refresh the Studio mirror before writing another Phase 17 patch.
- If the first Phase 17 installer causes `Incomplete statement: expected assignment or a function call` in `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`, run `scripts/roblox_persistence_phase17_owned_buy_tabs_repair_v3.lua` in Edit mode, restart Play, then rerun the Phase 17 client smoke. V3 supersedes the earlier v2 repair if the line 408 parse error remains.
- If the Phase 17 smoke reports all engines as rear, for example `Front=0, Rear=30`, run `scripts/roblox_persistence_phase17_front_rear_engine_metadata_repair.lua` in Edit mode. It makes front/rear engine identity explicit with `EnginePosition`, refreshes the catalog fields, and updates the Phase 17 slot checks to use that metadata.
- If the Phase 17 smoke passes but Play still reports the client bootstrap line 408 parse error, run `scripts/roblox_persistence_phase17_client_parse_line408_cleanup.lua` in Edit mode, then restart Play. If it says no dangling continuation lines were found, copy `ReplicatedStorage.NTR_DEBUG.COPY_THIS_LINE408_SOURCE_DUMP.Value` or the big Output copy block and paste it before another patch.
- If the line-408 dump shows a single stray `l` before `-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4`, run `scripts/roblox_persistence_phase17_remove_orphan_l_line408.lua` in Edit mode, then restart Play.
- If Play then reports `GarageActionController_Shadow_Disabled` reached EOF while expecting a final `end`, run `scripts/roblox_persistence_phase17_garage_server_final_end_repair.lua` in Edit mode. It restores only the missing final `end` before `-- V56_CONSOLIDATED_ACTION_CONTROLLER_END`.
- If that exact-tail repair does not clear the EOF error, run `scripts/roblox_persistence_phase17_garage_server_force_final_end_repair.lua` in Edit mode. It line-scans for the final V56 marker, inserts one `end` before it when missing, and prints a tail dump.

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
- Vehicle Phase AK Bruiser modular defaults: `docs/vehicle-phaseAK-bruiser-modular-defaults-2026-06-05.md`
- Vehicle Phase AL performance foundation: `docs/vehicle-phaseAL-performance-foundation-2026-06-08.md`
- Vehicle Phase AM runtime integration: `docs/vehicle-phaseAM-runtime-integration-2026-06-08.md`
- Vehicle Phase AN module upgrades: `docs/vehicle-phaseAN-module-upgrades-2026-06-08.md`
- Vehicle Phase AO upgrade UI: `docs/vehicle-phaseAO-upgrade-ui-2026-06-08.md`
- Persistence and garage profile plan: `docs/persistence-garage-profile-plan-2026-06-30.md`
- Cleanup Phase G full hierarchy audit: `docs/cleanup-phaseG-full-hierarchy-audit-2026-05-29.md`
- Cleanup Phase H legacy inactive deletion: `docs/cleanup-phaseH-delete-legacy-inactive-items-2026-05-29.md`
- Cleanup Phase I aggressive migration cleanup: `docs/cleanup-phaseI-aggressive-migration-cleanup-2026-05-29.md`
- Cleanup Phase M post kit migration audit: `docs/cleanup-phaseM-post-kit-migration-audit-2026-05-29.md`
- Cleanup Phase O stale metadata/report cleanup: `docs/cleanup-phaseO-stale-metadata-report-cleanup-2026-05-29.md`
- Compressed architecture roadmap: `docs/compressed-architecture-roadmap-2026-05-28.md`

## Diagrams

- `diagrams/vehicle_asset_system.svg`
- `diagrams/driving_runtime_system.svg`
