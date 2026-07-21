# Racing Staging Readiness Gate

**Date:** 2026-07-21
**Lane:** High-Risk connected runtime/networking
**Status:** User-confirmed working and present in refreshed `2026-07-21 09:20:03` mirror
**Installer:** `scripts/roblox_racing_staging_readiness_gate.lua`
**Revision:** `NTR_RACING_STAGING_READINESS_GATE_V1`

## Acceptance Contract

- **Goal:** show the complete loading transition first, then a fully visible synchronized five-second countdown, then authoritative GO.
- **Server authority:** `TimeTrialService_Active` owns solo staging/readiness/start; `RaceMatchmakingService_Active` owns multiplayer staging/readiness/start. Client acknowledgements cannot start, finish, reward, time or alter a race.
- **Client preparation owner:** `RaceTransitionClient_Active` confirms the local staged vehicle/seat, countdown presenter, requested start-area streaming and bounded critical vehicle preload.
- **Countdown presentation owner:** `RaceCountdownPresentationController_Active` derives each displayed number from `Workspace:GetServerTimeNow()` and the server-issued GO timestamp.
- **Loading/UI/input:** the existing Phase 4 loading runtime remains the only full-screen loading, UI-suppression, audio-mix and neutral-input owner. Destination UI is restored behind its fade before readiness is acknowledged.
- **Preserved:** matchmaking/queue rules, checkpoints, server timers, reset, exit, results, rewards, PBs, vehicle construction/cleanup and all persistence/economy schemas.
- **Devices:** the existing responsive countdown and loading geometry continues to cover desktop, tablet and phone.
- **Done when:** Time Trial and two-client Race both reveal a complete `5, 4, 3, 2, 1, GO!`; no acceleration/boost occurs before GO; a staging disconnect does not block remaining racers; timeout cancels safely; reset/results/rewards regressions are absent.

## State And Message Contract

```text
Server Staging
  -> client local preparation
  -> AssetsReady acknowledgement
  -> server waits for every active participant (18 s bound)
  -> CountdownReveal
  -> loading completes and fades
  -> CountdownVisible acknowledgement
  -> server waits for every active participant (8 s bound)
  -> CountdownScheduled { GoAtServerTime }
  -> synchronized 5-second presentation
  -> server GO / vehicle unlock / authoritative timer start
```

The existing `RaceRequest` and `RaceQueueRequest` RemoteFunctions carry `AcknowledgeStagingReady`; no new RemoteEvent or hierarchy owner is introduced. The server validates exact run ID, player membership, staging state and one of two named phases. Duplicate acknowledgements are idempotent. A disconnected/DNF participant is no longer required by the multiplayer barrier.

The client has a 7.5-second preparation deadline. It may report `Degraded=true` after a non-fatal stream/preload warning so the event is logged without deadlocking an otherwise usable race. A missing/stale acknowledgement never starts a race: server timeouts publish an error, release staged vehicles through the existing cleanup owner and end the staged run.

## Readiness Scorecard

| Concern | Result | Evidence / mitigation |
|---|---|---|
| Authority/security | Pass by design | Server validates run, membership, phase and state; acknowledgement grants no gameplay result. |
| Persistence/economy | N/A | No saved schema, cash, inventory, reward or PB write path changes. |
| Lifecycle | Requires Play proof | Bounded cancellation, active-run validation and disconnect exclusion prevent permanent staging. |
| Performance | Bounded | One start-area stream request and one staged-vehicle preload per local run; no heartbeat polling after acknowledgement. |
| Mobile/input | Requires device proof | Existing loading input gate remains locked through fade; shared responsive countdown is retained. |
| Streaming | Bounded/degraded | Requested around server-provided grid position with a client deadline; warning is observable. |
| Observability | Pass by design | Degraded readiness and failed acknowledgements warn with run/phase/player context; timeout reason is player-visible. |
| Rollback | Pass | One source-only transaction; Studio history before install is the clean rollback point. |

## Studio Verification

1. Run the canonical installer in Edit mode, restart Play and confirm no compile/runtime error.
2. Start a Time Trial. Confirm the loading screen stays on top, fades completely, and only then shows the full synchronized five-second countdown.
3. Hold throttle and boost throughout staging. Confirm the vehicle remains frozen and no input applies until GO; confirm control works normally after GO.
4. Complete/reset/exit a Time Trial. Confirm timing, checkpoint reset, result, PB/reward and Exit to Start remain unchanged; reset must not show the full loading screen.
5. Run a two-client Race. Confirm both clients finish loading before either sees the countdown, both display the same number, and both unlock at GO.
6. Repeat while one client leaves during staging. Confirm the remaining client either proceeds after satisfying readiness or the race ends cleanly if nobody remains.
7. For timeout proof, temporarily disable `RaceTransitionClient_Active` in a disposable Studio session and confirm staging cancels after the bounded timeout and the vehicle is not left frozen. Restore the script immediately; do not save that test change.
8. Recheck Race exit while driving, results Exit to Start, queue Leave, ordinary vehicle spawning and race/TT reset exclusions.
9. Run the installer once more with `MODE = "AUDIT"`; expect `AUDIT PASS` and no mutation.
10. Refresh the full Studio mirror and confirm all four sources contain `NTR_RACING_STAGING_READINESS_GATE_V1`.

## Risks And Rollback

The installer uses exact, uniqueness-checked source anchors across large racing scripts. If any preflight anchor or marker fails, stop and refresh/inspect the mirror; do not loosen the anchor or create a repair ladder. The installer compiles every projection before assignment and restores all four original sources if final verification fails.

The user confirmed the installed flow working and refreshed the mirror with all four revision markers. Preserve this as the current racing baseline. The clean rollback remains the Studio history version immediately before installation. No in-game backup objects were created.
