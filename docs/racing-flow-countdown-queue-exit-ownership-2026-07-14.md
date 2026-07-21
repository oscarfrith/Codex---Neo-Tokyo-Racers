# Unified Racing Flow: Countdown, Queue And Exit Ownership

**Date:** 2026-07-14  
**Status:** Existing presentation baseline confirmed; readiness-gated scheduling generated and awaiting Studio verification
**Installer:** `scripts/roblox_racing_flow_countdown_queue_exit_ownership.lua`

This single coordinated installer preserves the confirmed racing gameplay baseline while repairing presentation and lifecycle ownership.

The user accepted the final countdown/flow presentation and subsequently confirmed the completed mobile menu-suppression integration works well. Preserve this as the current racing-flow UI baseline. A two-player release regression and refreshed Studio export remain recommended.

## 2026-07-21 Readiness-Gated Scheduling

Loading Phase 4 exposed that the existing server countdown began at staging and was therefore mostly hidden behind the loading cover. `scripts/roblox_racing_staging_readiness_gate.lua` preserves this document's presentation and authoritative GO owners but changes scheduling: every active participant completes bounded local preparation, loading fully fades, clients acknowledge countdown visibility, and the server then publishes one `GoAtServerTime` timestamp for the shared five-second presenter.

This is pending Studio verification. It does not change the queue, checkpoints, reset, timing, results, rewards, PBs or vehicle lifecycle. See `docs/racing-staging-readiness-gate-2026-07-21.md` for the contract and regression matrix.

## Changes

- Race and Time Trial both use a configurable five-second server countdown.
- A shared responsive central overlay displays `5, 4, 3, 2, 1, GO!` on PC and mobile. Its card is borderless and uses the racing palette as a gradient; the countdown number/GO text is centred horizontally and vertically.
- Route-guide checkpoint frames, arrows, world labels and wrong-way presentation remain cleared during staging/countdown and activate only when the server sends GO.
- The old Phase 8 queue/finish panel is canonically replaced by a compact top queue banner with event, status, player count, remaining queue time and LEAVE.
- Queue presentation hides navigation, map, cash and car/settings menus while retaining necessary telemetry/controls.
- `NTR_RaceQueueActive` is server-owned. Vehicle selection, free-roam spawn/swap, normal spawn and despawn are rejected while queued.
- Browser, Entry and unified Results no longer have header X buttons; footer actions own exit/back/retry.
- Result EXIT waits for successful server cleanup before closing.
- The generic `TimeTrialEnded` fallback result is removed, preventing the obsolete second exit menu.
- The old queue client never shows post-race results; unified Results is the sole result owner.
- Time-trial checkpoint RESET preserves the original lap clock. The server already preserved authoritative elapsed time; the shared PC/mobile HUD no longer restarts its local display clock.

## Verification

1. Run `INSTALL` in Edit mode and restart Play.
2. Start a Time Trial on PC and mobile. Confirm the borderless gradient card, centred 5-to-GO text, no checkpoint guidance during countdown, and that guidance/controls activate on GO.
3. During a Time Trial, wait several seconds, press RESET, and confirm the lap timer continues rather than returning to zero.
4. Queue two players for a Race. Confirm the compact banner scales on both devices, LEAVE works, and free-roam menus are unavailable underneath.
5. While queued, attempt car selection/spawn/despawn through every available route; confirm the server returns `Leave the race queue before changing vehicles.`
6. Confirm the Race countdown also shows 5-to-GO and the queue banner disappears before staging.
7. Finish both a Race and Time Trial. Confirm only unified Results appears, header X is absent, and EXIT TO START closes everything in one click after cleanup.
8. Open car/settings, then open Browser/Entry. Confirm the previous menu closes and no free-roam UI remains beneath the racing menu.
9. Run `SMOKE` in Edit mode, then refresh the full Studio mirror.

## Risks And Rollback

The installer performs guarded exact replacements across current isolated racing owners plus one small garage server guard. It preflights every source in memory before assigning any source. If an anchor fails, stop and refresh the mirror rather than guessing another patch.

Clean rollback is the immediately preceding Studio history version. Do not re-enable retired race HUD/session clients as a workaround.
