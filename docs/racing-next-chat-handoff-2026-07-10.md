# Racing Next Chat Handoff

**Created:** 2026-07-10  
**Status:** Phase 11Z locked as the current racing prototype baseline  
**Mirror:** User refreshed the Studio mirror and pushed to Git before this handoff.

Use this as the quick handoff for the next racing chat. Still read the required project startup docs first:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- `docs/07_patch_history.md`
- `docs/10_script_source_sync_workflow.md`
- `docs/11_manual_script_copy_map.md`
- `docs/12_continuous_improvement_workflow.md`
- this file
- `docs/race-time-trial-system-plan-2026-07-06.md`

Then check `git status --short`.

## Locked Baseline

Racing Phase 11Z is the current release-candidate gate:

```text
scripts/roblox_racing_phase11z_post_11y_release_candidate_audit.lua
```

The user confirmed the post-11Y racing loop is working and asked to lock in 11Z before moving further adjustments into new chats.

Current confirmed racing behavior:

- Solo time trials: entry menu, owned vehicle selection, start-grid spawn, countdown, checkpoints, lap sessions including infinite, rewards, PB persistence verification path, result coach, exit cleanup, re-entry, Race browser teleport, and free-roam vehicle spawning all recovered.
- Multiplayer races: same-server prototype queue, selected-vehicle grid spawn, countdown, checkpoint progression, placement rewards, route arrows/barriers, player/vehicle/VFX/name-tag visibility isolation, and exit-to-start are working at prototype level.
- Route arrows/barriers: `ArrowMarkers.CheckpointA-B` segment folders are the current authoring baseline. The Phase 11L V2 arrow visual proxy sync marker must be preserved.
- Reset: Phase 8H respawn-on-reset is the stable architecture. Do not return to live vehicle teleport/yaw patches.
- Result/HUD: Phase 11T result coach plus Phase 11U V2 narrow stale-HUD cleanup are the current UI baseline.
- Finish lifecycle: Phase 11Y is the current time-trial finish lifecycle baseline. Finished TT vehicles must remain frozen, drive-disabled, and pending cleanup until result exit confirms.

## Key Scripts

Keep these as the main known-good racing references:

```text
scripts/roblox_racing_phase8h_respawn_reset_system.lua
scripts/roblox_racing_phase9a_route_type_lap_sessions.lua
scripts/roblox_racing_phase10b_folder_arrow_barriers.lua
scripts/roblox_racing_phase11l_arrow_visual_proxy_sync_repair.lua
scripts/roblox_racing_phase11t_isolated_time_trial_result_coach.lua
scripts/roblox_racing_phase11u_time_trial_hud_exit_cleanup.lua
scripts/roblox_racing_phase11w_time_trial_pb_datastore_verification.lua
scripts/roblox_racing_phase11y_time_trial_finish_lifecycle_recovery.lua
scripts/roblox_racing_phase11z_post_11y_release_candidate_audit.lua
```

Phase 11P is not a confirmed baseline and should not be used as the starting point for result polish.

## Recommended Next Branches

Choose one branch per new chat where possible:

1. Small racing UI/UX polish: result-copy wording, entry menu layout, countdown polish, race browser usability, mobile fit. Keep this isolated and avoid patching confirmed lifecycle services unless required.
2. Multiplayer reliability and balance: queue edge cases, leave/disconnect handling, finish ordering, anti-grief collision policy, min/max players, rewards, and smoke audits.
3. Competitive layer: local/global/friends leaderboards, ghost planning, PB display improvements, and DataStore production readiness.
4. Track content scaling: tooling for more routes, checkpoint validation, route audit scripts, arrow-folder creation for new checkpoint counts, reward/base-time balancing helpers.
5. Deferred architecture: private/reserved race servers, cross-lobby matchmaking, and player-created races. These are not needed for the current prototype unless explicitly chosen.

## Next Requested Branch: Race And Prize UI

As of 2026-07-11, the user has paused later PC free-roam UI phases and wants the next chat to focus on race/time-trial menus and prize presentation. Begin with a read-only audit of the Phase 11Z racing mirror and preserve its lifecycle/reward ownership. Compare the current entry menu, time-trial HUD, countdown, result coach, rewards, PB display, race browser, and multiplayer result flow against the shared PC UI design system before proposing changes.

Use the confirmed Phase 4A free-roam design language and semantic tokens, but implement racing presentation in isolated Racing UI controllers. Do not rewrite `TimeTrialService_Active`, reward idempotency, Phase 8H reset, Phase 11Y finish cleanup, or the register-limited bootstrap merely to restyle screens. Separate visual/menu work from any economy, reward-balance, persistence, or matchmaking changes.

### Approved Racing UI Design Gate (2026-07-11)

The user approved the desktop entry/records/vehicle/race overview layouts, the
equal-column race and time-trial results, the simplified free-roam Race Browser,
and the responsive/component direction. The authoritative specification is:

```text
docs/racing-ui-design-system-2026-07-11.md
```

The pre-install audit passed `103/1/0`. The first visible installer is now:

```text
scripts/roblox_racing_ui_phase1_shared_shell_browser.lua
```

It safely combines shared Racing UI semantic config/components with the
canonical isolated Race Browser replacement. Entry presentation was deliberately
kept out of the first install because the existing entry owner also contains
confirmed PB, vehicle-selection, retry, and exit behavior. Do not combine global
leaderboard persistence, new race telemetry, rewards, matchmaking, reset, or
finish lifecycle changes into the visual installer.

## Workflow Notes For Next Chat

- Apply the project `follow:` / `suggest:` rule from `docs/12_continuous_improvement_workflow.md`.
- Prefer isolated companion scripts/services over patching `RaceEntryMenuClient_Active` again.
- Do not add bulky helpers to `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`; it is register-limited.
- Preserve reward config under `Config.Racing.Rewards`; do not casually move multipliers back onto route folders.
- Preserve route-guide config and the Phase 5F checkpoint pill baseline unless the task is specifically route-guide UI.
- Preserve Phase 8H reset architecture and Phase 11Y finish lifecycle.
- If a fragile source anchor fails twice in the same live script, stop and inspect the refreshed mirror before writing another repair.

## Remaining Risks

- Same-server race isolation is good enough for the prototype, but launch-quality competitive races should likely move to reserved/private servers or race pockets.
- PB DataStore testing is deliberately controlled through Phase 11W; enable/disable saved testing intentionally.
- Mobile racing UI still deserves a focused pass after core flow changes slow down.
- Player-created races are future-proofed at the route-contract/authoring-folder level, but creator tools, validation, storage, moderation, and public discovery remain future work.
- Economy/reward values are prototype-balanced; tune through `Config.Racing.Rewards` and per-event `BaseReward`.

## Suggested Next-Chat Opening

```text
Start from docs/racing-next-chat-handoff-2026-07-10.md. The current racing baseline is Phase 11Z confirmed. I want to work on [chosen branch]. Please check the startup docs, git status, and the relevant mirror files before planning or changing anything.
```
