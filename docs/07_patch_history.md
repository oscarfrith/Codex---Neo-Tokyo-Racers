# Patch History

This is a high-level summary, not a complete changelog of every script.

## Documentation

- 2026-06-05: Added `scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua` and `docs/vfx-phaseAJ-thrust-preview-root-repair-2026-06-05.md` to repair missing thrust VFX preview after Dealership Intro Phase 4 moved the local preview vehicle to `Workspace._NTR_ClientOnly.VehiclePreview`. Updated the staged Phase B preview vehicle generator to use the same local-only preview root.
- 2026-06-04: Added `scripts/roblox_character_sprint_controller_install.lua`, a safe Studio command-bar installer for an on-foot sprint controller under `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime`. It removes the earlier broken `NTR_CharacterSprintDefaults`, stores sprint tuning in `ReplicatedStorage.NeoTokyoRacers.Shared.Config.CharacterMovement_EditAttributes`, and avoids consuming Shift so vehicle drift remains controlled by the driving system.
- 2026-06-04: User confirmed the character sprint install worked and moved/renamed the live `StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime` hierarchy to the clean controller names: `CharacterSprintController_Active`, `DriveHudController_Active`, `MobileDriveControlsController_Active`, and `RuntimeVFXController_Active`.
- 2026-06-04: Updated `scripts/roblox_character_sprint_controller_install.lua` with mobile auto-sprint. On touch devices, the sprint controller reads Roblox's standard PlayerModule move vector and starts sprinting when it reaches `MobileSprintMoveThreshold`, default `0.85`, while still disabling itself in `VehicleSeat`s so mobile/keyboard vehicle drift is unaffected.
- 2026-06-04: Added `docs/character-sprint-controller-2026-06-04.md` handoff. User confirmed sprint works in the clean runtime hierarchy; a blocked third-party custom sprint animation was resolved by disabling/replacing `AnimationId`, leaving Roblox's normal character animations active.
- 2026-05-28: Added dated current mechanics docs covering vehicle, lighting, LOD, traffic lights, mobile performance, customisation, UI, race events, and open-world city systems. These docs are a reference layer for future Codex/ChatGPT sessions and should not be treated as permission to rewrite unrelated systems.
- 2026-06-03: Added `prompts/`, a reusable ChatGPT/Codex prompt pack for session startup, Studio output debugging, feature planning, handoff, commit summaries, and docs database maintenance.
- 2026-06-03: Added `scripts/roblox_dealership_intro_phase0_audit.lua`, a read-only Studio command-bar audit for active client/server garage paths, legacy script state, world/intro marker presence, and likely auto-open/preview/purchase code paths.
- 2026-06-03: Added Dealership Intro Phase 1 marker setup docs and `scripts/roblox_dealership_intro_phase1_setup_markers.lua`, a safe rerunnable Studio command-bar script that creates editable intro spawn, desk trigger, camera, preview, and path markers without touching startup behavior.
- 2026-06-03: Added `scripts/roblox_dealership_intro_phase2_install_client.lua`, installing an isolated `DealershipIntroClient_Active` LocalScript for objective UI, local path arrows, camera intro, and desk distance detection. It expects the Phase 3 `OpenGarageFromIntro` hook for opening the full garage.
- 2026-06-03: Added `scripts/roblox_dealership_intro_phase3_gate_garage_startup.lua`, a guarded client patch that replaces the active bootstrap's auto `task.defer(init)` startup with a local `OpenGarageFromIntro` BindableEvent fired by the intro client at the desk.
- 2026-06-03: Added `scripts/roblox_dealership_intro_phase4_preview_after_purchase.lua`, a fragile guarded client patch that delays local preview vehicle creation until successful cockpit purchase/select, uses `Workspace._NTR_ClientOnly.VehiclePreview`, and reads dealership preview/camera markers.
- 2026-06-03: Added `scripts/roblox_dealership_intro_phase5_restore_preview_orbit_camera.lua`, restoring garage preview orbit camera behavior after Phase 4 so the preview camera starts from the marker but still rotates around the vehicle centre and responds to module selection focus.
- 2026-06-03: Added `scripts/roblox_dealership_intro_phase6_vehicle_exit_spawn_marker.lua`, creating `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint` and patching the active garage server controller so final drivable vehicles spawn from that editable marker.
- 2026-06-03: Added `scripts/roblox_dealership_intro_phase7_exit_button_reopen_gate.lua`, adding an Exit button to the first cockpit-buy menu and a leave/re-enter gate so exiting the dealership does not immediately reopen the menu.
- 2026-06-03: User confirmed Dealership Intro Phases 1-7 working, including desk-gated garage open, delayed preview, restored preview orbit camera, editable final exit spawn, and first-menu Exit/reopen behavior.
- 2026-05-29: Added Architecture Phase K command-bar migration plan/script to move `ReplicatedStorage.HOVER_RACING_V2_KIT` into `ReplicatedStorage.NeoTokyoRacers` domains with guarded source preflight.
- 2026-05-29: Updated Architecture Phase K preflight patching for registry/path-string source references to `00_EDIT_ME_FIRST` and `UI_THEME_DoNotRename`.
- 2026-05-29: Added Architecture Phase L command-bar deletion gate to verify no live dependencies remain, then destroy `ReplicatedStorage.HOVER_RACING_V2_KIT`.
- 2026-05-29: Confirmed Architecture Phase K and Phase L completed in Studio. The old `ReplicatedStorage.HOVER_RACING_V2_KIT` root is gone, with 0 legacy source hits and 0 legacy ObjectValue references in the Phase L report.
- 2026-05-28: Added target architecture reorganisation plan and Studio inventory report script for planning a safe future hierarchy migration.
- 2026-05-28: Added a dedicated Studio inventory report paste document for long Roblox Explorer hierarchy reports.
- 2026-05-28: Added hierarchy migration plan based on the pasted Studio inventory, with `Test + WIP Assets` explicitly excluded from migration.
- 2026-05-28: Added `scripts/roblox_hierarchy_phase1_architecture_resolver.lua`, a non-destructive Studio command-bar script that creates future `NeoTokyoRacers` architecture roots, adds a compatibility `PathResolver`, and mirrors key config folders without moving live systems.
- 2026-05-28: Added `scripts/roblox_hierarchy_phase2_live_references_registry.lua`, a non-destructive Studio command-bar script that adds visual ObjectValue references to current live systems and a `LiveSystemRegistry` bridge module for future targeted migrations.
- 2026-05-28: Added `scripts/roblox_studio_active_script_audit_v1.lua`, a read-only Studio command-bar audit that reports active scripts outside approved live roots and flags generic, temporary, WIP/test, and excluded-area scripts.
- 2026-05-28: Added `scripts/roblox_studio_suspicious_script_inspector_v1.lua`, a read-only Studio command-bar inspector that captures source previews, line counts, fingerprints, and keyword hints for unexpected/generic active scripts before any cleanup decisions.
- 2026-05-28: User manually removed two generic active `LocalScript`s from `StarterPlayerScripts`; `TEMP_LightingPreview` is intentionally kept as a day/night lighting preview tool.
- 2026-05-28: Updated audit/inspector scripts so `TEMP_LightingPreview` is treated as an intentional temporary lighting tool rather than accidental clutter.
- 2026-05-28: Added `scripts/roblox_studio_archive_disabled_legacy_scripts_v1.lua`, a cleanup script that archives disabled legacy `HOVER_RACING*` scripts into `ServerStorage.NeoTokyoRacers_LegacyArchive.DisabledScripts` without deleting them or touching active systems.
- 2026-05-28: Added `scripts/roblox_hierarchy_phase3_config_registry_mirrors.lua`, a non-destructive config migration script that creates/refines `NeoTokyoRacers.Shared.Config`, adds live config references, refreshes generated config mirrors, and installs `ConfigRegistry` without changing live config values or switching live scripts.
- 2026-05-28: Added a lightweight Studio-to-GitHub script source mirror workflow: `scripts/roblox_studio_export_scripts_for_github_v1.lua`, `scripts/import_studio_script_export.py`, `docs/10_script_source_sync_workflow.md`, and `roblox/exported_scripts/`.
- 2026-05-28: Imported the current Studio script export into `roblox/exported_scripts` and added `docs/11_manual_script_copy_map.md` for manual source copy guidance.
- 2026-05-28: Reviewed the exported Studio script mirror and added `docs/script-architecture-review-2026-05-28.md`, documenting the current client/server modularity risks, mobile performance priorities, and staged migration order.
- 2026-05-28: Added `scripts/roblox_hierarchy_phase4_architecture_staging_scaffold.lua`, a non-destructive Studio command-bar script that creates future service/controller/config folders and ObjectValue references without moving or changing live scripts.
- 2026-05-28: Added `scripts/roblox_hierarchy_phase4b_prepare_traffic_service_shadow.lua`, a non-destructive Studio command-bar script that copies the live traffic controller into the new architecture as a disabled shadow script for future migration testing.
- 2026-05-28: Added `docs/phase5-ui-migration-plan-2026-05-28.md` and `scripts/roblox_hierarchy_phase5_ui_module_shadow_extract.lua` to stage UI helper modules and future UI folders without switching live UI behaviour.
- 2026-05-28: Added `docs/compressed-architecture-roadmap-2026-05-28.md` to reduce the remaining architecture work to six broader phases.
- 2026-05-28: Added `scripts/roblox_hierarchy_phase6_world_services_migration.lua`, which migrates traffic lights to the new world service location and stages disabled lighting/LOD shadow copies for later migration.
- 2026-05-28: Added `docs/phase7-shared-ui-helpers-2026-05-28.md` and `scripts/roblox_hierarchy_phase7_shared_ui_helpers_promote.lua`, promoting final shared UI helper modules and mirrored UI theme config without switching live UI behaviour.
- 2026-05-28: Added `docs/phase8-client-ui-controller-scaffold-2026-05-28.md` and `scripts/roblox_hierarchy_phase8_client_ui_controller_scaffold.lua`, creating the future client UI controller structure without switching live UI, driving, VFX, server actions, mobile controls, LOD, lighting, traffic, or assets.
- 2026-05-28: Added `docs/phase9-server-services-scaffold-2026-05-28.md` and `scripts/roblox_hierarchy_phase9_server_services_scaffold.lua`, creating the future garage/vehicle/profile/economy server service structure without switching the current live `GarageInvoke` action layer.
- 2026-05-28: Added `docs/phase10-runtime-controller-scaffold-2026-05-28.md` and `scripts/roblox_hierarchy_phase10_runtime_controller_scaffold.lua`, creating future runtime controller ownership targets for driving bootstrap, camera, HUD, mobile controls, VFX, and vehicle access without changing active runtime behaviour.
- 2026-05-28: Added `docs/phase11-architecture-readiness-audit-2026-05-28.md` and `scripts/roblox_hierarchy_phase11_architecture_readiness_audit.lua`, a non-destructive readiness audit for missing architecture paths, unexpected active scripts, accidental enabled future bootstraps, and remaining live legacy names.
- 2026-05-28: Added `docs/phase12-server-action-snapshot-2026-05-28.md` and `scripts/roblox_hierarchy_phase12_server_action_snapshot.lua`, capturing the live V56 server action layer as a non-live snapshot/parity reference before extracting server services.
- 2026-05-28: Added `docs/phase13-server-parity-harness-2026-05-28.md` and `scripts/roblox_hierarchy_phase13_server_parity_harness.lua`, a non-destructive parity gate that compares the live V56 hash against the Phase 12 snapshot and optionally checks the `GetInitial` response shape in Play mode.
- 2026-05-28: Corrected Phase 12 snapshot generation so `V56ActionLayerSnapshot` is valid Lua, updated Phase 13 to avoid unsupported server-side `OnServerInvoke` reads, and added `scripts/roblox_hierarchy_phase13b_client_getinitial_shape_check.lua` for the client-side `GetInitial` shape check.
- 2026-05-28: Added `docs/phase14-server-shadow-action-controller-2026-05-28.md` and `scripts/roblox_hierarchy_phase14_server_shadow_action_controller.lua`, creating a disabled shadow server action controller from the verified V56 block without switching live server ownership.
- 2026-05-28: Added `docs/phase15-server-action-owner-switch-2026-05-28.md` and `scripts/roblox_hierarchy_phase15_server_action_owner_switch.lua`, a controlled server action owner switch with `SWITCH` and `ROLLBACK` modes.
- 2026-05-28: Phase 15 `SWITCH` was run and tested successfully. Output confirmed the active V56 controller now runs from `GarageActionController_Shadow_Disabled`; Phase 13 hash parity and Phase 13B client `GetInitial` shape checks passed after the switch.
- 2026-05-28: Added `docs/phase16-runtime-helper-owner-switch-2026-05-28.md` and `scripts/roblox_hierarchy_phase16_runtime_helper_owner_switch.lua`, a controlled runtime helper owner switch for cached thrust VFX, mobile controls, and mobile HUD suppression.
- 2026-05-28: Phase 16 `SWITCH` was run and tested successfully. Runtime helper ownership moved into `NeoTokyoRacersClient.Controllers.Runtime` without reported gameplay regressions.
- 2026-05-28: Added `docs/phase17-driver-seat-owner-switch-2026-05-28.md` and `scripts/roblox_hierarchy_phase17_driver_seat_owner_switch.lua`, a controlled driver seat keeper owner switch into the new vehicle service architecture.
- 2026-05-28: Phase 17 `SWITCH` was run and tested successfully. Driver seat position keeper ownership moved into `NeoTokyoRacers.Services.Vehicle` without reported gameplay regressions.
- 2026-05-28: Added `docs/phase18-lod-client-owner-switch-2026-05-28.md` and `scripts/roblox_hierarchy_phase18_lod_client_owner_switch.lua`, a controlled LOD client owner switch into the new world controller architecture.
- 2026-05-28: Phase 18 `SWITCH` was run and tested successfully. LOD client ownership moved into `NeoTokyoRacersClient.Controllers.World` without reported gameplay regressions.
- 2026-05-28: Added `docs/phase19-lighting-service-owner-switch-2026-05-28.md` and `scripts/roblox_hierarchy_phase19_lighting_service_owner_switch.lua`, a controlled server lighting owner switch into the new world lighting service architecture.
- 2026-05-28: Phase 19 `SWITCH` was run and tested successfully. Server lighting ownership moved into `NeoTokyoRacers.Services.World.Lighting` without reported gameplay regressions.
- 2026-05-28: Added `docs/phase20-thrust-preview-owner-switch-2026-05-28.md` and `scripts/roblox_hierarchy_phase20_thrust_preview_owner_switch.lua`, a controlled thrust preview owner switch into the new preview controller architecture.
- 2026-05-28: Phase 20 `SWITCH` was run and tested successfully. Thrust preview ownership moved into `NeoTokyoRacersClient.Controllers.Preview` without reported gameplay regressions.
- 2026-05-28: Added `docs/phase21-post-switch-architecture-audit-2026-05-28.md` and `scripts/roblox_hierarchy_phase21_post_switch_audit.lua`, a read-only checkpoint audit for all owner switches completed in Phases 15-20.
- 2026-05-28: Phase 21 audit passed cleanly: 11/11 expected active owners enabled, no unexpected active scripts, no active scripts in `Test + WIP Assets`, and only the intentionally remaining `HOVER_RACING_V2_Client` legacy owner active.
- 2026-05-29: Added `docs/main-client-extraction-plan-2026-05-29.md`, a five-phase plan for extracting `HOVER_RACING_V2_Client` into state/API/catalog modules, preview/colour controllers, garage screen controllers, a final bootstrap, and cleanup.
- 2026-05-29: Added `docs/main-client-phaseA-core-boundary-2026-05-29.md` and `scripts/roblox_client_phaseA_core_boundary_modules.lua`, creating staged Core modules for client state, garage API calls, catalog lookups, theme reads, and paint utilities without changing live client behaviour.
- 2026-05-29: Phase A was run and play-tested successfully by the user; added `docs/main-client-phaseB-preview-colour-2026-05-29.md` and `scripts/roblox_client_phaseB_preview_colour_modules.lua`, staging preview vehicle, preview camera, and colour picker modules without switching live client behaviour.
- 2026-05-29: Phase B was run and play-tested successfully by the user; added `docs/main-client-phaseC-garage-screens-2026-05-29.md` and `scripts/roblox_client_phaseC_garage_screen_controllers.lua`, staging dealership, cockpit paint, module shop, customisation, navigation, and stats panel controllers without switching live client behaviour.
- 2026-05-29: Phase C was run and play-tested successfully by the user; added `docs/main-client-phaseD-owner-switch-2026-05-29.md` and `scripts/roblox_client_phaseD_main_client_owner_switch.lua`, a controlled `SHADOW` / `SWITCH` / `ROLLBACK` owner-location switch for the remaining live `HOVER_RACING_V2_Client`.
- 2026-05-29: Phase D was run and play-tested successfully by the user; added `docs/main-client-phaseE-post-switch-audit-2026-05-29.md` and `scripts/roblox_client_phaseE_post_switch_audit.lua`, a read-only audit for confirming the new architecture-owned main client is active and the legacy `HOVER_RACING_V2_Client` is disabled.
- 2026-05-29: Phase E audit passed cleanly after rerunning Phase D with `MODE = "SWITCH"`: 11/11 expected active owners enabled, no unexpected active scripts, no active scripts in `Test + WIP Assets`, no active legacy-named `HOVER_RACING` scripts, and all staged Phase A-C modules present.
- 2026-05-29: Added `docs/world-phaseF-city-hierarchy-lod-migration-2026-05-29.md` and `scripts/roblox_world_phaseF_city_hierarchy_lod_migration.lua`, preparing a city hierarchy migration from `Workspace.GeneratedCityBlocks` to `Workspace.NeoTokyoRacersWorld.City.Block S#` plus a LOD root resolver fallback.
- 2026-05-29: Added `docs/world-phaseJ-far-lod5-assets-migration-2026-05-29.md` and `scripts/roblox_world_phaseJ_far_lod5_assets_migration.lua`, preparing migration of `ReplicatedStorage.FarLOD5` into `ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5Proxies` plus a LOD far-proxy resolver fallback.
- 2026-05-29: Added `docs/cleanup-phaseG-full-hierarchy-audit-2026-05-29.md` and updated `scripts/roblox_cleanup_phaseG_full_hierarchy_cleanup_audit.lua`, a read-only full hierarchy cleanup audit that classifies old inactive folders/scripts/assets before a separate deletion script is generated.
- 2026-05-29: Added `docs/cleanup-phaseH-delete-legacy-inactive-items-2026-05-29.md` and `scripts/roblox_cleanup_phaseH_delete_legacy_inactive_items.lua`, a targeted cleanup script with `DRY_RUN` / `DELETE` modes for removing the exact inactive legacy owners, rollback scripts, old report folders, and legacy archive confirmed by Cleanup Phase G.
- 2026-05-29: Added `docs/cleanup-phaseI-aggressive-migration-cleanup-2026-05-29.md` and `scripts/roblox_cleanup_phaseI_aggressive_migration_cleanup.lua`, a one-step aggressive cleanup for stale migration reports, reference ObjectValues, mirror-only generated config, non-live scaffold/shadow/snapshot code, and empty placeholder folders.
- 2026-05-29: Added `docs/cleanup-phaseM-post-kit-migration-audit-2026-05-29.md` and `scripts/roblox_cleanup_phaseM_post_kit_migration_audit.lua`, a read-only post-K/L audit for stale kit references, nil ObjectValues, empty compatibility folders, old report clutter, and remaining cleanup candidates.
- 2026-05-29: Added `scripts/roblox_cleanup_phaseM_print_action_sections.lua`, a read-only helper that prints only the actionable Phase M report sections for review.
- 2026-05-29: Added `scripts/roblox_cleanup_phaseM_runtime_root_probe.lua`, a read-only helper for checking whether `Workspace.HOVER_RACING_V2_WORLD` is still referenced before cleaning stale runtime ObjectValues.
- 2026-05-29: Added `scripts/roblox_architecture_phaseN_runtime_world_path_repair.lua`, a guarded source/object reference repair for retargeting old `Workspace.HOVER_RACING_V2_WORLD` runtime paths to `Workspace.NeoTokyoRacersWorld`.
- 2026-05-29: Updated Phase N after first Studio preflight to handle remaining `PLAYER_VEHICLES_Runtime` constant/variable source shapes in the garage action controller, driver seat service, and main client bootstrap.
- 2026-05-29: Phase N completed successfully in Studio: 10 source objects patched, 24 replacements applied, 8 ObjectValues repaired, `Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint` created, and final old runtime source hits were 0.
- 2026-05-29: Added `scripts/roblox_cleanup_phaseO_stale_metadata_report_cleanup.lua`, a guarded cleanup for stale migration metadata, old report folders, old path StringValue text, and exact empty placeholder folders after the clean Phase M audit.
- 2026-05-29: Phase O follow-up audit passed: 0 warnings, 0 missing required paths, 0 source legacy hits, 0 stale ObjectValues, and 0 auto cleanup candidates. Updated Phase M to stop flagging required empty architecture containers such as `Config.Runtime`.
- 2026-05-29: Final Phase M action-section verification passed cleanly: every actionable section printed `None`, including review-before-delete candidates.

## Early System

- Initial command-bar scripts created starter folders, template parts, module categories, UI, money, and a short checkpoint race.
- The system moved from cable-tied modular slots to fixed category-based module slots.

## Fixed-Slot Category System

- `V13` and later scripts introduced a fixed-slot category system.
- `BRUISER` became the active vehicle category.
- Modules became interchangeable within a vehicle category.

## UI and Mobile

- Multiple responsive/futuristic UI patches refined the dealership, module selection, colour picker, customisation menus, and mobile controls.
- The UI settled toward dark translucent panels, light green borders, and futuristic text.

## VFX

- V23-V31 introduced VFX templates for hover dust, engine jets, boost, stabilisers, and custom VFX hierarchies.
- V64-V66 added cached thrust visual runtime and fixed a weld leak.

## Server/Action Layer Recovery

- V52-V56 rebuilt or repaired server/action logic after earlier patch failures.
- Later guidance: avoid large brittle server/client rewrites unless necessary.
- 2026-06-02: Added `scripts/roblox_architecture_phaseP_garage_runtime_startup_repair.lua` in the Git repo for the conservative post-Phase-N garage runtime startup repair. Phase Q supersedes it if the line 23 startup error remains.
- 2026-06-02: Added `scripts/roblox_architecture_phaseQ_garage_controller_header_repair.lua` to repair a post-Phase-N/P startup failure in the active garage action controller by replacing only the V56 startup header with migrated NeoTokyoRacers paths.

## Lighting

- 2026-06-02: Added `scripts/roblox_lighting_phaseR_fogcolor_property_repair.lua` to fix the invalid `Fogcolor` preset key by changing it to Roblox's valid `FogColor` property and adding a compatibility alias in `LightingService_Active`.

## Vehicle Assets

- 2026-06-02: Experimented with cockpit car-light phases S through AH, covering native SpotLights, local projectors, root-only emitters, predictive hosts, and Beam visuals. These did not meet the desired quality bar at speed.
- 2026-06-03: Removed the cockpit car-light experiment scripts/docs from the active repo and added `scripts/roblox_vehicle_phaseAI_remove_cockpit_light_systems.lua` to remove installed helper scripts, light assets, root SpotLights, Beam/projector artifacts, and stale cockpit-light attributes from Studio. Front/rear long-range car lights are deferred.

## Driving

- V62 restored V47-style driving and replaced fallback driving paths with `DrivingControllerV47`.
- V67-V71 restored and corrected mobile driving HUD visibility.
- V72/V73 experimented with a fully scriptable chase camera but caused jitter and did not feel right.
- V74 restored the pre-V72/default Roblox camera feel with a light camera assist. User confirmed this worked well.
- V75 added boost recharge delay, editable boost module attributes, and low-speed hover wobble. Needs play-test confirmation unless confirmed later.

## Current Important Scripts

- `scripts/roblox_hover_racing_v74_pre_v72_camera_assist.lua`
- `scripts/roblox_hover_racing_v75_boost_delay_hover_wobble.lua`
- `scripts/roblox_architecture_phaseP_garage_runtime_startup_repair.lua`
- `scripts/roblox_architecture_phaseQ_garage_controller_header_repair.lua`
- `scripts/roblox_lighting_phaseR_fogcolor_property_repair.lua`
- Cockpit light removal/defer script: `scripts/roblox_vehicle_phaseAI_remove_cockpit_light_systems.lua`
- Dealership intro audit: `scripts/roblox_dealership_intro_phase0_audit.lua`
- Dealership intro marker setup: `scripts/roblox_dealership_intro_phase1_setup_markers.lua`
- Dealership intro client installer: `scripts/roblox_dealership_intro_phase2_install_client.lua`
- Dealership intro garage startup gate: `scripts/roblox_dealership_intro_phase3_gate_garage_startup.lua`
- Dealership intro preview-after-purchase patch: `scripts/roblox_dealership_intro_phase4_preview_after_purchase.lua`
- Dealership intro preview orbit camera fix: `scripts/roblox_dealership_intro_phase5_restore_preview_orbit_camera.lua`
- Dealership intro vehicle exit spawn marker: `scripts/roblox_dealership_intro_phase6_vehicle_exit_spawn_marker.lua`
- Dealership intro exit button/reopen gate: `scripts/roblox_dealership_intro_phase7_exit_button_reopen_gate.lua`
- No cockpit car-light renderer is current after Phase AI.
