# Racing UI Final Handoff

> Superseded for current mobile/racing-flow work by `docs/mobile-ui-racing-flow-handoff-2026-07-14.md`. Retain this document for the confirmed Phase 16F PC architecture and performance history.

**Date:** 2026-07-13  
**Status:** Racing UI through Phase 16F confirmed working  
**Baseline:** Phase 4A PC free-roam presentation plus the current isolated Racing presentation

> Refresh and push the post-Phase-16F Studio mirror before the next source change. The repository mirror at handoff still contains the Phase 16E arrow owner, although Phase 16F was installed and confirmed in Studio.

This is the authoritative handoff for the race/time-trial UI stream completed after `docs/racing-next-chat-handoff-2026-07-10.md`. Read the normal startup documents first, then use this file instead of reconstructing the implementation from every intermediate repair.

## Confirmed Outcome

The user confirmed the current interface, the Phase 16E performance cleanup, and the Phase 16F local course-arrow repair are working. The presentation now covers:

- free-roam Race Browser;
- race/time-trial entry and tab switching;
- tiered time-trial prizes, PB and medal targets;
- race overview and fixed event information;
- time-trial records/global-ranking presentation;
- mode-aware owned-vehicle selection;
- shared race/time-trial in-session HUD;
- fixed configurable course map with one local moving marker;
- reset and exit-confirmation UX;
- race and time-trial result screens;
- retry/race-again and exit-to-start actions;
- responsive PC sizing and shared visual tokens;
- explicit UI lifecycle ownership and retired obsolete PC presentation.

## Locked Gameplay And Lifecycle Boundaries

Future presentation work must preserve:

- Phase 8H reset: respawn/rebuild at the last checkpoint. Do not return to live vehicle teleport/yaw repair.
- Phase 11Y finish lifecycle: finished time-trial vehicles remain frozen, drive-disabled and pending cleanup until result exit confirms.
- Reward calculation/idempotency and PB calculation/persistence remain server-owned.
- Matchmaking, queue membership, finish order and route progression remain server-owned.
- `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled` is register-limited. Do not add new top-level helpers or large feature blocks.
- LOD is intentionally retained and was not the source of the reported hitch.
- Mobile presentation remains a separate path; Phase 16E's PC retirement must not delete mobile UI.

## Current Presentation Owners

Important isolated owners under `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing` are:

```text
RaceBrowserClient_Active
RaceEntryMenuClient_Active                 (headless state/action bridge after Phase 16E)
RaceEntryPresentationController_Active
RaceParticipantVisibilityClient_Active
RaceRouteGuideClient_Active
RaceSessionAssetsClient_Active
RaceSessionPresentationController_Active
RaceTimeTrialResultCoachClient_Active
RaceTransitionClient_Active
```

`RaceClient_Active`, `RaceSessionControlsClient_Active` and `RaceHudExitCleanupClient_Active` are retired. Obsolete PC navigation, vehicle-exit and drive-HUD presentation must not be constructed. Do not re-enable these to fix a visual regression; inspect the current isolated owner.

## Confirmed Screen Contracts

### Race Browser

- Shared responsive shell and Phase 4A magenta/cyan language.
- Large simplified event cards; selected event is cyan.
- Race name comes from Phase 1F's shared display-name owner.
- Event image, menu map and simplified HUD map are separate configurable assets.
- Event icons/text are aligned as one row; `PRIZE` is white and cash cyan.
- Footer buttons use the shared neutral/confirm gradient treatment.
- Background presentation is suppressed through explicit ownership, not repeated GUI scans.

### Entry, Records And Vehicle Selection

- Time Trial is the default tab and selected tabs remain cyan.
- Race and Time Trial reuse the same outer dimensions, equal columns, gaps, footer and responsive bounds.
- Time Trial uses E-S tiers. Locked tiers can be inspected on page one, but cannot proceed without an owned vehicle; highest owned tier is the intended default.
- On later Time Trial pages, the chosen tier is filled and other tiers are display-only. Tier changes require Back.
- Multiplayer Race is open-category and has no tier brackets.
- Time-trial lap count is adjustable within configured limits; Race lap count is event-owned and fixed.
- Records preserve a 50/50 split and must show honest unavailable states when global server data is absent.
- Time Trial vehicle selection shows owned vehicles in the chosen class; Race shows all eligible owned vehicles with Category and Sort By controls.
- Vehicle card content is physically inset from the scrolling boundary. This is the confirmed top/left stroke-clipping fix.

### Results

- Race and Time Trial results share the outer shell, equal columns, footer sizing and button treatment.
- Time Trial shows medal, prize, best lap/PB state, readable scrollable session laps and global tier table/unavailable state.
- Race gives the left result/highlights column visual weight and uses the right for ordered results.
- Top-three placement supports medal imagery; result rows support player thumbnails.
- Race result truth is supplied by Phase 12's isolated snapshot bridge, not calculated in the visual controller.
- Retry/race-again and exit continue through the existing lifecycle bridge.

### In-Race HUD

- Unrelated PC UI is inactive during an active race/time trial.
- Top left: large lap `X / X` card.
- Top centre: current lap time for Time Trial or placement-coloured position for Race.
- Top right: borderless Gran Turismo-style PB/session rows. Race may show textual standings when authoritative data exists.
- Bottom left: fixed simplified course artwork with no decorative border and one local moving/rotating arrow.
- Bottom centre: Reset and Exit reuse free-roam action-button geometry/style with racing actions.
- Exit uses the same centred modal proportions and design as dealership confirmation.
- Bottom right: shared speed/boost telemetry remains available without running the full free-roam shell.

## In-Race Map Contract

Route-local calibration lives at:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.HudMapCatalog.<RouteId>
```

It includes the simplified image, original image size, start pixel X/Y, pixel-to-stud scale, map/world rotation, flips, optional configured world anchor, marker rotation offset and clamp behavior. The map is fixed; only the local player marker translates and rotates. The marker reuses the Phase 4A free-roam arrow asset/size.

Shared layout tuning lives at:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing.InRace
```

Confirmed Phase 16C2 defaults:

```text
MapWidth = 420
MapHeight = 420
MapOffsetX = 16
MapOffsetY = 16
MapInnerPadding = 0
MapOpacity = 0.78
```

`MapOpacity` uses `0 = invisible`, `1 = opaque` and affects only map artwork. Layout uses the 1920x1080 racing reference canvas and scales down for smaller PC viewports.

No opponent/other-player map markers are created or rendered. This is an intentional performance decision, not an incomplete phase. Text standings may still list competitors.

## Performance And Ownership Lessons

The periodic hitch came from presentation work, not LOD. Preserve these lessons:

1. Do not merely hide obsolete PC GUIs; their objects, loops and connections must not be constructed.
2. Do not repeatedly scan `PlayerGui` to suppress interfaces; use explicit presentation state/ownership signals.
3. Free-roam work pauses during a race or full-screen racing menu. Entry, session and result controllers update only in their active state.
4. Shared speed/boost telemetry remains usable independently of the full free-roam shell.
5. Arrow visibility is incremental by segment; never traverse every arrow descendant every frame.
6. Participant visibility is event-driven, not a render-step descendant sweep.
7. Opponent map markers are removed completely. Only the local marker is supported.
8. Cache stable map/calibration inputs; keep only necessary local subject/position work live.

Phase 16E produced a substantial user-confirmed lag improvement.

## StreamingEnabled Arrow Lesson

Phase 16E's transparency fallback was correct, but local course arrows stayed invisible because a streamed segment folder could exist before its MeshParts. The client cached an empty descendant list and then skipped later work behind an unchanged run/route/segment signature.

Phase 16F is the confirmed repair:

- register existing and late `DescendantAdded` BaseParts per segment;
- immediately apply the segment's current state to late parts;
- do not cache a missing `ArrowMarkers` root as a valid empty route;
- invalidate the lightweight signature when segment folders arrive/leave;
- resolve routes exactly first, then by normalized name/`RouteId`;
- visible transparency uses `NTR_ArrowOriginalTransparency` or `0`, never the hidden value.

This retains the low-cost Phase 16E architecture. Server collision proxies and route progression remain unchanged.

## Visual-System Lessons

- Magenta is structure/navigation; cyan is selected/active/confirm; red is destructive.
- Border/glow colours must agree. Gradients sit beneath text/images, not over them.
- Use one maximum PC panel size and safe edge buffer across Browser, Entry, Records, Vehicle and Results.
- Preserve shared gaps between columns, tabs, frames and footer buttons.
- Equal column widths improved hierarchy and future mobile migration.
- Clip media inside rounded wrappers so image corners cannot escape borders.
- Atlas icons need explicit source rectangles and per-icon X/Y offsets; icon and label belong in one row container.
- A 1024x1024 2x2 medal atlas is the current quality baseline.
- Use scale layout with bounded pixel offsets; runtime absolute-bound inspection is better than guessing.

Authoritative tokens:

```text
docs/ui-free-roam-pc-design-system-2026-07-10.md
docs/racing-ui-design-system-2026-07-11.md
```

## Key Installers

```text
scripts/roblox_racing_ui_phase1_shared_shell_browser.lua
scripts/roblox_racing_ui_phase1f_shared_display_name.lua
scripts/roblox_racing_ui_phase2_time_trial_startup.lua
scripts/roblox_racing_ui_phase9a_global_time_trial_leaderboard.lua
scripts/roblox_racing_ui_phase11_unified_results_presentation.lua
scripts/roblox_racing_ui_phase12_race_result_snapshot_bridge.lua
scripts/roblox_racing_ui_phase13_results_visual_hierarchy.lua
scripts/roblox_racing_ui_phase14_vehicle_grid_edge_padding.lua
scripts/roblox_racing_ui_phase16a_shared_in_race_hud.lua
scripts/roblox_racing_ui_phase16b_gt_hud_controls_suppression.lua
scripts/roblox_racing_ui_phase16b2_hud_visual_alignment.lua
scripts/roblox_racing_ui_phase16c_config_driven_hud_map.lua
scripts/roblox_racing_ui_phase16c1_map_anchor_size_repair.lua
scripts/roblox_racing_ui_phase16c2_map_opacity_edge_alignment.lua
scripts/roblox_racing_ui_phase16d_presentation_performance.lua
scripts/roblox_racing_ui_phase16e_runtime_ownership_cleanup.lua
scripts/roblox_racing_ui_phase16f_streaming_safe_arrow_visibility.lua
```

Do not rerun the full ladder on a confirmed place. Start from the refreshed live mirror and patch only the current isolated owner.

## Required Next-Chat Startup

1. Read `AGENTS.md`, `docs/00_START_HERE.md`, `docs/06_current_known_issues.md`, and `docs/12_continuous_improvement_workflow.md`.
2. Read this handoff and both design-system documents.
3. Check Git status. Existing driving-feel and mirror changes belong to the user.
4. Confirm the Studio mirror was refreshed after Phase 16F; it was still pre-16F at handoff time.
5. Never include or edit `docs/studio-full-export-paste.txt` in a handoff/commit.
6. Prefer one isolated controller/config change over cross-owner patching.
7. If two anchors fail in one live script, stop and inspect the refreshed mirror.

## Sensible Next Branches

- Full Browser -> Entry -> Vehicle -> Session -> Results -> Retry/Exit regression, including two-player Race.
- Mobile-specific racing UI migration without changing the confirmed PC baseline. Phase 1 is installed and user-confirmed: Browser, Entry submenus, and unified Results select their existing PC composition on touch and share a config-driven safe-area scale. Phase 1B is the next config-only step and changes `SafeTop` from `84` to `72` for a tighter gap beneath Roblox controls; see `docs/racing-ui-mobile-phase1b-top-gap-refinement-2026-07-13.md`.
- Real server-backed world records/global leaderboard production contract.
- Additional-track authoring/calibration tools for media, HUD maps and arrow segments.
- Multiplayer reliability/standing telemetry polish while retaining server authority.
- Replay/spectate as a separate feature, not an implicit result-cleanup extension.

## Suggested Next-Chat Opening

```text
Start from docs/racing-ui-final-handoff-2026-07-13.md. Racing UI Phase 16F is confirmed: Phase 16E fixed the presentation hitch and Phase 16F repaired StreamingEnabled local course arrows. Check AGENTS.md, startup docs, Git status, and confirm the Studio mirror was refreshed after Phase 16F. Preserve Phase 8H reset, Phase 11Y finish cleanup, reward/PB ownership, matchmaking, LOD, mobile separation, local-only map markers, and the register-limited bootstrap.
```
