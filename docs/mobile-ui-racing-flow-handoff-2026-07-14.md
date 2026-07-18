# Mobile UI And Racing Flow Handoff

**Date:** 2026-07-14  
**Status:** Current mobile free-roam/racing presentation user-confirmed working  
**Mirror status:** Refresh required before the next source patch

This is the current new-chat handoff for the mobile UI and racing-flow work completed after `docs/racing-ui-final-handoff-2026-07-13.md`. Read the normal startup documents first, then use this file for the latest mobile/racing baseline.

## Confirmed Outcome

The user reported the completed mobile presentation working well. The confirmed flow now includes:

- PC-parity mobile free-roam map, navigation, cash, speed/boost telemetry and Exit presentation;
- Arrows, Thumbstick and Tilt control modes, with borderless gradient arrow cards and image-only configurable pedals;
- equal square Accelerator/Brake image slots with configurable size, bottom/right offsets and gap;
- compact three-row mobile vehicle menu with fitted names, cash safeguards, approved dropdowns, gradients and Despawn treatment;
- safe-area Settings, Get Cash and dealership confirmation popups;
- scaled-PC Race Browser, Race/Time Trial entry pages, prize/records/vehicle pages and unified Results;
- mobile in-race lap, current time/position, PB/laps/standings, RESET and EXIT while preserving the approved bottom driving controls;
- responsive borderless-gradient `5, 4, 3, 2, 1, GO!` countdown with centred text and checkpoint guidance hidden until GO;
- compact race-queue banner, queued vehicle-change lock, footer-only race-menu exits and single-owner result cleanup;
- Time Trial RESET preserving the ongoing lap timer on both PC and mobile;
- complete free-roam HUD and vehicle-control suppression behind Race menus, Settings, Get Cash and dealership confirmation, including release of held inputs.

Mobile race maps remain intentionally disabled. Cash product purchase buttons and non-mobile-control Settings options remain visual-only until separately designed with server-authoritative persistence/receipt handling.

## Current Runtime Owners

Do not rebuild these systems in the register-limited bootstrap. The important isolated owners are:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.MobileFreeRoamHudController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceBrowserClient_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryPresentationController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceQueueClient_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceCountdownPresentationController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionPresentationController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTimeTrialResultCoachClient_Active
```

`RaceClient_Active`, `RaceSessionControlsClient_Active` and `RaceHudExitCleanupClient_Active` remain retired. Do not re-enable them to repair a visual issue.

## Current Configuration Roots

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud
ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing.MobileScaledDesktop
ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing.InRace
ReplicatedStorage.NeoTokyoRacers.Config.Racing.FlowUI
ReplicatedStorage.NeoTokyoRacers.Config.Racing.Matchmaking
```

Phase 1O uses the local player attribute `NTRMobileMajorMenuOpen` to bridge the mobile HUD popup owner to the separate vehicle-control owner. The control owner also treats its own disabled `ScreenGui` as blocked so full-screen Race menus release held inputs.

## Canonical Installers

These scripts represent the final steps of the current baseline. Do not rerun the earlier full repair ladder on a working place.

```text
scripts/roblox_ui_freeroam_mobile_phase1l_modal_safe_area_pc_cash.lua
scripts/roblox_ui_freeroam_mobile_phase1m_control_surface_opacity.lua
scripts/roblox_ui_freeroam_mobile_phase1n_square_pedal_layout.lua
scripts/roblox_ui_freeroam_mobile_phase1o_major_menu_suppression.lua
scripts/roblox_racing_ui_mobile_phase1_scaled_desktop_trial.lua
scripts/roblox_racing_ui_mobile_phase1b_top_gap_refinement.lua
scripts/roblox_racing_ui_mobile_phase2_in_race_hud.lua
scripts/roblox_racing_flow_countdown_queue_exit_ownership.lua
```

Each later script is a guarded refinement of the installed isolated owners. Missing anchors require a fresh mirror and source inspection, not a broad replacement.

## Locked Behaviour

- The mobile car menu intentionally leaves the approved top map/navigation/cash cluster visible but non-conflicting; Phase 1O does not change that contract.
- Major popups keep only their modal/shade visible and hide all free-roam HUD/control groups.
- Full-screen Race menus suppress all free-roam `ScreenGui` presentation.
- Active Race/Time Trial sessions retain the bottom mobile driving controls and telemetry.
- RESET repositions the vehicle without restarting the authoritative or displayed current-lap clock.
- Checkpoint frames/arrows/labels remain hidden during countdown and activate on GO.
- Queue membership and the queued vehicle lock remain server-owned.
- Browser, Entry and Results use footer actions instead of header X exits.
- No mobile race map is required in the current baseline.

## Mirror And Git Warning

The local full snapshot still reports:

```text
Generated in Studio: 2026-07-14 13:34:35
```

It predates the final unified race-flow/countdown refinement and Mobile Phase 1O install. Before the next source change:

1. Run `py scripts/receive_studio_full_snapshot_export.py` locally.
2. Run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in the Studio Command Bar.
3. Confirm the new mirror contains `NTR_RACING_FLOW_COUNTDOWN_VISUAL_V2`, `NTR_RACING_FLOW_COUNTDOWN_GUIDE_GATE_V2`, and `NTR_MOBILE_FREEROAM_UI_PHASE1O_MAJOR_MENU_SUPPRESSION`.
4. Commit generated changes under `roblox/exported_scripts/` and `roblox/studio_snapshot/`.
5. Do not commit `docs/studio-full-export-paste.txt`.

The working tree contains unrelated driving, camera, lighting and mirror changes belonging to the user. Preserve them and scope any next commit deliberately.

## Recommended Regression Before Release

- One real-device pass through Arrows, Thumbstick and Tilt.
- Open Settings, Get Cash, dealership confirmation and Race Browser while holding Accelerator/steering; verify input releases and restores cleanly.
- Complete one Time Trial with RESET and one result EXIT TO START.
- Complete a two-player Race queue/countdown/finish/exit flow and attempt a vehicle change while queued.
- Run the current installers' `SMOKE` modes after the refreshed mirror is captured.

## Suggested Next-Chat Opening

```text
Start from docs/mobile-ui-racing-flow-handoff-2026-07-14.md. The current mobile free-roam UI, mobile racing UI, unified countdown/queue/result flow, and Phase 1O major-menu suppression were user-confirmed working. Read AGENTS.md and the startup/current-issues docs, inspect Git status, and refresh the Studio mirror before any new source patch because the repo snapshot still reports 2026-07-14 13:34:35. Preserve the isolated owners, active-session bottom controls, footer-only race exits, RESET lap-clock behaviour, hidden countdown checkpoint guide, car-menu top-HUD contract, and the register-limited bootstrap boundary.
```
