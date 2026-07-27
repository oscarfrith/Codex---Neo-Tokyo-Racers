# Racing Presentation And Lifecycle Refinements V1.4

**Date:** 2026-07-26  
**Lane:** High-Risk connected race lifecycle/presentation  
**Status:** V1.4 user-confirmed, fully mirrored at `2026-07-27 10:05:47` and handed off  
**Installer:** `scripts/roblox_racing_presentation_lifecycle_refinements_v1.lua`  
**Revision:** `NTR_RACING_PRESENTATION_LIFECYCLE_V1_4`

## V1.4 Focused Continuation

The complete `2026-07-27 09:55:18` mirror contains 189 exported scripts and the user-confirmed V1.3 state. It proves the legacy PB board is gone and the EXIT backdrop is full physical screen. It also exposes the remaining wide-screen root cause: the shared HUD's child panels are correctly anchored, but all are parented to a fixed `1920×1080` canvas scaled and centred with the smaller viewport axis. Ultrawide and tall/windowed screens therefore leave unused aspect space outside that canvas.

V1.4 retains `RaceSessionPresentationController_Active` as the one HUD/map/RESET/EXIT geometry owner. Its single scale remains uniform, so card, text and map proportions do not stretch. The logical canvas now expands to the current `GuiService` `DeviceSafeInsets` rectangle; existing left/right/bottom/centre anchors then consume all safe width and height. It also:

- rebinds the viewport listener if `Workspace.CurrentCamera` is replaced;
- updates after viewport, window, orientation or safe-content size changes;
- keeps touch session controls at their authored horizontal avoidance position while anchoring them to the true safe bottom;
- leaves the V1.3 black EXIT backdrop directly under the no-inset `ScreenGui`, outside the device-safe content canvas.

At a 16:9 viewport with no device cutout the logical canvas remains equivalent to `1920×1080`. No race state, timing, lap, PB, reward, map-tracking, remote, driving, VFX or persistence owner changes.

## V1.3 Focused Continuation

The complete `23:12:59` V1.2 mirror has 190 matching exported scripts, source-manifest entries and checksums. It proves:

- `RaceEntryMenuClient_Active` is the intended headless state/action bridge and constructs no UI.
- `RaceEntryPresentationController_Active` is the current entry UI and already owns personal-best and records presentation.
- `RacePersonalBestBoardClient_Active` is still enabled, separately listens for `OpenRaceEntry`, and creates `NTR_TimeTrialPersonalBestBoard`.
- The shared in-race EXIT shade is parented to the aspect-scaled 1920×1080 reference canvas, so it cannot cover letterboxed PC/mobile edges.

V1.3 removes only the superseded standalone PB-board script, adds its exact GUI name to lifecycle cleanup, and keeps the headless bridge/current entry owner. It adds a full-screen backdrop directly under `NTR_SharedInRaceHUD`, uses the project-confirmed no-inset/no-safe-area-clipping contract, and keeps the modal panel inside the existing scaled canvas.

## V1.2 Focused Continuation

The user confirmed the V1.1 aura, route `ArrowMarkers`, checkpoint-guide-arrow removal and surrounding racing presentation working. Two bounded refinements remain:

- `TimeTrialStartZone` is a separate `Mode="TimeTrial"` part. V1.1 only registered the `Mode="Race"` start zone, so its native E prompt remained visible during Time Trial countdown and racing.
- The shared checkpoint world pill is correctly sized on PC but too large on mobile.

V1.2 registers both supported start-zone modes in the existing local eligibility owner. It also reuses `ResponsiveUIFoundation.IsMobile()` and applies `MobileCheckpointUIScale=0.6` to the existing checkpoint pill width, height, text, corner and stroke. PC remains exactly `1.0`.

## V1 Runtime Finding And V1.1 Correction

The first Studio run exposed three presentation-boundary defects:

- the eligible free-roam aura inherited authored-disabled emitter state instead of being explicitly shown;
- the server-owned native prompt remained locally visible during the participant's Race/Time Trial;
- `RaceSessionAssetsClient_Active` consumed the checkpoint-guide-arrow switch, so it also hid the intended physical route `ArrowMarkers`.

V1.1 repairs those exact boundaries in the same canonical installer. It does not add a second gameplay owner, remote or race-state path.

## Acceptance Contract

### Goal

Refine racing entry and route presentation without changing server race authority, timing, checkpoints, rewards, PBs, vehicle construction, reset, exit or persistence.

### Required Presentation

- No dynamic checkpoint arrow or authored checkpoint-guide-arrow clone is visible.
- Physical route-segment `ArrowMarkers` are visible through the existing session-window owner while racing.
- Every authored `ArrowMarkers` folder and useful route-authoring instance remains present and readable.
- Existing checkpoint HUD/world marker and wrong-way presentation remains available.
- `RaceStartZone.vfx_aura` is local presentation:
  - explicitly visible for an eligible free-roam local player, even if an authored effect was disabled;
  - hidden while that client is in the start screen, race entry, launch/loading, queue, staging, countdown, active Race or active Time Trial;
  - restored after a failed launch, queue failure, staging timeout/cancellation, finish, DNF/end, result exit, active quit, cleanup or later eligible state;
  - unchanged on a non-participant client.
- The start zone uses Roblox's native `ProximityPrompt` with keyboard `E`, controller `ButtonX` and touch/click presentation.
- That prompt is locally enabled only for an eligible client and hidden for the participant during loading, queue, staging, countdown and active Race/Time Trial.
- Both `RaceStartZone` and `TimeTrialStartZone` consume that same eligibility contract.
- Checkpoint world-pill presentation remains full size on PC and is reduced by 40% on mobile.
- A multi-lap finishing gate reads `LAP 1`, then the applicable current lap, and `FINAL LAP` on the final lap.
- A genuine single-lap finishing gate reads `FINISH LINE`.
- Retired race HUD, controls, menu, badge, queue and result surfaces are removed by exact name on initial client load and if any are later recreated.
- The standalone `MY TIME TRIAL BESTS` board is retired because its data and records view now live in the current entry presentation.
- The in-session EXIT confirmation black backdrop covers the complete physical viewport, including aspect-ratio bars and rounded mobile safe-area edges.

### Preserved Behaviour

- `TimeTrialService_Active` and `RaceMatchmakingService_Active` remain authoritative for membership, staging, GO, timing, checkpoints, laps, placement, finish and cleanup.
- Existing trusted `RaceEvent` payloads remain the only lap/session input to presentation.
- `RaceSessionPresentationController_Active` remains the shared PC/mobile HUD, responsive geometry and RESET/EXIT owner.
- Current queue, countdown, unified results, rewards, PBs, reset/respawn, exit-to-start, participant visibility, collision/VFX isolation and driving handoff remain unchanged.
- No remote, saved field, reward calculation, receipt, economy mutation, DataStore, checkpoint touch or vehicle lifecycle owner is added.
- Desktop, native controller prompt and touch prompt use the same server entry path.

### Done-When

- Installer preflight, projection compile, committed audit, idempotent rerun and automatic failure rollback pass.
- The complete runtime matrix below passes in a fresh server.
- Repeated sessions do not grow aura/legacy cleanup connections or leave a stale visibility owner.
- The full Studio mirror is refreshed and contains the new revision, controller, disabled legacy clients and configuration.

## Confirmed Owner Map

| Concern | Owner after V1 | Notes |
|---|---|---|
| Prompt creation/trigger | `TimeTrialService_Active` | Existing server prompt and distance validation retained; native input properties are explicit. |
| Prompt eligibility presentation | `RaceLifecyclePresentationController_Active` | Local visibility only; it does not trigger or validate entry. |
| Aura visibility | `RaceLifecyclePresentationController_Active` | Local-only presentation owner; no server/world visibility mutation. |
| Physical route-segment `ArrowMarkers` | `RaceSessionAssetsClient_Active` | Existing active-session/segment-window and streaming owner, gated separately from checkpoint arrows. |
| Dynamic/authored checkpoint-guide arrows | `RaceRouteGuideClient_Active` | Existing renderer consumes the checkpoint-guide-arrow switch and remains disabled. |
| Checkpoint HUD/world marker | `RaceRouteGuideClient_Active` and shared race HUD | Preserved. |
| Mobile checkpoint world-pill scale | `RaceRouteGuideClient_Active` using `ResponsiveUIFoundation.IsMobile()` | `0.6` mobile, `1.0` PC; normal config attribute controls the mobile multiplier. |
| Lap state | `TimeTrialService_Active` / `RaceMatchmakingService_Active` | Existing `CurrentLap`, `NextLap` and `LapTarget` payloads only. |
| Finish-gate wording | `RaceRouteGuideClient_Active` | Presentation projection of authoritative lap state. |
| Shared race HUD/reset/exit | `RaceSessionPresentationController_Active` | Existing panels and actions retained; V1.4 changes only the shared root transform. |
| HUD safe-edge geometry | `RaceSessionPresentationController_Active` | One uniformly scaled canvas spans `DeviceSafeInsets`; no second layout owner. |
| EXIT modal/backdrop | `RaceSessionPresentationController_Active` | Existing modal retained; new direct full-screen backdrop and atomic visibility helper. |
| Queue/countdown/results/PB/rewards | Existing isolated racing owners/services | Unchanged. |
| Legacy race UI cleanup | `RaceLifecyclePresentationController_Active` | Exact allowlist only; no broad `PlayerGui` deletion. |
| Personal-best entry presentation | `RaceEntryPresentationController_Active` | Integrated PB/records owner; standalone Phase 11O board retired. |

## Documentation/Live-Source Contradiction

The complete `22:35:11` mirror is internally consistent and does not appear stale: all 189 exported scripts, source-manifest entries and checksums match.

It proves:

- `RaceClient_Active.Disabled=true`;
- `RaceSessionControlsClient_Active.Disabled=false`;
- `RaceHudExitCleanupClient_Active.Disabled=false`.

Phase 16E and the unified race-flow smoke contract explicitly require all three clients retired. The later shared responsive-foundation installer included `RaceSessionControlsClient_Active` as an enabled styling target, explaining how a superseded control owner returned. The V1 installer disables the two live superseded clients and audits all three as retired. It does not re-enable `RaceClient_Active` or disable any current shared owner.

## State Contract

```text
Eligible free roam
  -> aura explicitly visible
  -> local native E / touch / controller prompt enabled

Open entry
  -> aura hidden
  -> prompt hidden
  -> exact legacy surfaces removed

Close entry / rejected launch / queue failure
  -> eligible free roam
  -> aura restored

Launch or queue
  -> aura and prompt hidden
  -> loading/staging/readiness/countdown
  -> active Race or Time Trial
  -> aura remains hidden

Finish / DNF / cancellation / timeout / error / active quit
  -> current run-id ownership released
  -> aura restored when loading/queue/start-screen blocks are clear

Result exit
  -> loading temporarily hides aura
  -> eligible free roam restores aura
```

Delayed terminal events only release the matching active run ID. Visual writes also carry a monotonically increasing local generation, so a deferred write from an older state cannot overwrite the current state.

Each client owns only its own aura visibility. A participant hiding the aura does not change the replicated emitter state seen by a non-participant.

## Arrow Configuration And Authoring

The existing folder remains:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide
```

V1.1 records:

```text
ShowCheckpointArrows = false
ShowRouteArrowMarkers = true
ArrowMarkersDormant = false
CheckpointGuideArrowsDisabled = true
PresentationLifecycleRevision = NTR_RACING_PRESENTATION_LIFECYCLE_V1_1
```

`ShowCheckpointArrows=false` gates only the dynamic/authored checkpoint-guide arrows rendered by `RaceRouteGuideClient_Active`. Existing `ShowDynamicNextArrow` and `ShowAuthoringArrows` values are preserved behind it.

`ShowRouteArrowMarkers=true` is consumed only by `RaceSessionAssetsClient_Active`. The existing authoritative local-session and segment-window logic therefore reveals the physical route-segment markers while racing and hides them outside the active route window.

V1.2 also records:

```text
MobileCheckpointUIScale = 0.6
PresentationLifecycleRevision = NTR_RACING_PRESENTATION_LIFECYCLE_V1_2
```

The installer counts authored arrow roots and BaseParts before and after its transaction. A missing baseline or changed count fails and rolls back. It never deletes, reparents or edits authored route instances.

## Native Prompt Contract

`TimeTrialService_Active` retains prompt creation, periodic recovery, `Triggered` connection and server-side start-zone validation. V1 explicitly sets:

```text
KeyboardKeyCode = E
GamepadKeyCode = ButtonX
ClickablePrompt = true
Style = Default
```

`PromptActionText` remains authored on the start zone and is used when present. Roblox supplies the native keyboard, touch and controller affordances; no replacement button or second prompt owner is created.

## Legacy Retirement

The installer retires:

```text
RaceClient_Active
RaceSessionControlsClient_Active
RaceHudExitCleanupClient_Active
```

The new local cleanup owner removes only these historical `ScreenGui` names:

```text
NTR_RaceHud
NTR_RaceHud_Phase3
NTR_RaceCheckpointBadge_Phase5D
NTR_RaceQueue_Phase8
NTR_RaceSessionControls_Phase8C
NTR_RaceSessionControls_Phase8D
NTR_RaceResults_Phase4
NTR_TimeTrialResultCoach
NTR_RaceEntry
NTR_RaceEntryProbe
NTR_TimeTrialPersonalBestBoard
```

Current `NTR_SharedInRaceHUD`, `NTR_RaceQueueBanner`, `NTR_RaceCountdown`, `NTR_RaceEntryPresentation`, `NTR_UnifiedRaceResults`, `NTR_RaceRouteGuide_Phase5` and PB presentation are not deleted.

The phrase “PB presentation” above means the PB/records content inside `NTR_RaceEntryPresentation` and the in-session/result PB content. The separate `NTR_TimeTrialPersonalBestBoard` is superseded and removed in V1.3.

## Readiness Scorecard

| Concern | Result | Evidence / mitigation |
|---|---|---|
| Authority/security | Pass by design | No new remote; client presentation consumes existing trusted events and cannot start, finish, reward or time a race. |
| Persistence/economy | N/A | No saved schema, cash, ownership, reward, PB or receipt change. |
| Lifecycle | Confirmed baseline | Iterative user verification accepted the entry/session/exit behaviour; retain the complete matrix for release regression. |
| Streaming | Bounded | One fixed workspace discovery connection plus one connection per streamed race start zone/aura; connections are disconnected with zone/script lifetime. |
| Performance | Bounded/improved | Disabled authored-arrow polling does no session work; no frame loop is added. |
| Devices | Confirmed baseline | User confirmed the adaptive layout; native E, touch/click and ButtonX remain explicit. Retain physical-device/orientation coverage for release regression. |
| Multiplayer | Requires two-client proof | Aura state is local; server participant visibility remains unchanged. |
| Observability | Pass by design | Installer prints one install/audit line and records one revision. |
| Rollback | Pass | All projected sources compile before mutation; failed committed audit restores sources, attributes and enabled states in memory. Studio history is the durable rollback. |

## Exact Recovery/Audit Procedure

V1.4 is installed, confirmed and fully mirrored. No Studio command is pending for ordinary use. The procedure below is retained only for intentional exact-scope recovery or audit.

1. Open `scripts/roblox_racing_presentation_lifecycle_refinements_v1.lua`.
2. Leave `MODE = "INSTALL"`.
3. Paste the complete file into the Studio Command Bar in Edit mode and run it once.
4. Expect:

```text
[NTR Racing Presentation Lifecycle V1.4] AUDIT PASS | shared HUD=aspect-adaptive device-safe edges | 16:9 reference sizing=preserved | exit backdrop=full physical screen | entry owner=new presentation only | standalone PB board=removed | native prompt=all start zones+session hidden | checkpoint UI=PC 100%/mobile 60% | route ArrowMarkers=on and preserved=<count> parts/<count> roots | legacy owners retired
[NTR Racing Presentation Lifecycle V1.4] INSTALL PASS | restart Play, run the full verification matrix, then rerun this same script with MODE="AUDIT".
```

5. Restart Play; do not test in the same running client.
6. After the matrix passes, stop Play, change only `MODE = "AUDIT"` in the same local installer and run it again in Edit mode.
7. Expect the same `AUDIT PASS` line and no mutation.

If the installer reports `INSTALL ROLLED BACK`, an anchor mismatch, compile failure or authored-arrow count change, stop. Refresh and inspect the live mirror; repair this canonical installer rather than creating a patch.

## Verification Matrix

| Scenario | Required result |
|---|---|
| Fresh PC free roam | Aura is visibly emitting and the native prompt is enabled; no legacy race surface exists before first menu open. |
| Entry open | Only `NTR_RaceEntryPresentation` appears; no separate `MY TIME TRIAL BESTS` board flashes or remains. Integrated PB and Records content still loads. |
| Keyboard entry | Native prompt displays `E`; entry opens once through the existing server owner. |
| Touch entry | Native touch/click prompt opens the same entry flow; no custom prompt overlay. |
| Controller entry | Native `ButtonX` prompt opens the same entry flow and focus remains correct. |
| Entry close | Aura restores; current free-roam HUD returns; no old race menu/HUD appears. |
| Rejected/failed launch | Loading/error clears and aura restores without a stale hidden owner. |
| Solo Time Trial | Aura and prompt hide from launch through active session; route `ArrowMarkers` appear through the existing segment window; five-second readiness countdown, HUD, PB, reward and driving handoff remain correct. |
| Time Trial prompt lifecycle | `TimeTrialStartZone` E/touch/controller prompt is absent throughout staging, countdown and the active run, then returns in eligible free roam. |
| PC checkpoint pill | Existing approved size, text and placement are unchanged. |
| Mobile checkpoint pill | Width, height, text, corner and stroke are 60% of the PC/configured base; text remains readable in portrait and landscape. |
| Two-client Race | Participant client hides aura and prompt; non-participant client continues to see both; racers retain route markers, synchronized countdown and participant visibility. |
| Queue leave/failure | Aura restores after queue state clears. |
| Staging timeout/cancellation | Session cancels safely; aura and free-roam presentation restore. |
| Normal finish | Aura eligibility restores; only unified Results appears. |
| Result exit | Loading may hide aura transiently; it restores at free-roam start. |
| Active quit | Existing authoritative cleanup completes; aura restores; no stale HUD/control. |
| EXIT modal PC | Black backdrop covers the entire viewport on 16:9, ultrawide and tall/windowed aspect ratios; modal remains centred and usable. |
| EXIT modal mobile | Backdrop reaches all portrait/landscape edges, including rounded safe-area regions; NO and YES remain safe and usable. |
| EXIT modal cleanup | NO, YES, successful/failed exit, terminal cleanup and repeated sessions never leave the backdrop visible. |
| 16:9 PC | Approved panel sizes and relative composition remain unchanged; lap is left, time/position top-centre, session board right, map bottom-left and controls bottom-centre. |
| Ultrawide PC | Lap/map reach the configured safe left edge and session board reaches the configured safe right edge; central timing/position remains centred; no horizontal stretching. |
| Tall/windowed PC | Bottom map/controls follow the safe bottom and top/side surfaces retain their anchors; no centred 16:9 letterbox island. |
| Tablet landscape/portrait | Every visible shared race surface stays within device-safe edges after orientation change; card/text proportions remain uniform. |
| Phone landscape/portrait | Lap, metric, board and touch RESET/EXIT remain usable inside device cutouts; touch controls follow the safe bottom and do not move into the driving-control lane. |
| Runtime resize/camera swap | Resizing the emulator/window or replacing `CurrentCamera` recomputes once per change; no duplicate HUD, stale bounds or connection growth appears. |
| RESET | Current reset/respawn and lap clock remain correct; aura stays hidden while the session is still active. |
| Respawn cleanup | A terminally cleaned session restores aura; an in-session reset cannot be mistaken for terminal cleanup. |
| Repeated entry | Ten entry/close and five complete session cycles show no duplicate legacy UI, aura conflict or growing callback effect. |
| Checkpoints | Checkpoint HUD/world label and wrong-way presentation still work; zero checkpoint-attached/dynamic guide arrows are visible; physical route `ArrowMarkers` are visible while racing. |
| Two-lap wording | First pass finish gate reads `LAP 1`; second/final pass reads `FINAL LAP`. |
| Three-lap wording | Reads `LAP 1`, `LAP 2`, then `FINAL LAP`. |
| Single-lap wording | Finish gate reads `FINISH LINE`. |
| Infinite laps | Finish gate uses current `LAP N` wording and never claims `FINAL LAP`. |
| Regression | Queue, countdown, results, rewards, PBs, reset/exit, collision/VFX isolation and driving handoff match the confirmed baseline. |

For connection-growth proof, use the Studio Developer Console or MicroProfiler while repeating sessions. The controller must remain one LocalScript with one workspace discovery connection and one bounded record per currently streamed start zone; callbacks and Instance count must return to a stable range.

## Mirror Status

The complete `2026-07-27 10:05:47` mirror is fresh for the installed, user-confirmed V1.4 state. All 189 exported-script, source-manifest, checksum and hierarchy entries agree with zero path/checksum mismatches.

It contains both `NTR_RACING_PRESENTATION_LIFECYCLE_V1_4` revision attributes, the V1.4 adaptive-safe-edge and retained V1.3 full-screen EXIT markers, `RaceLifecyclePresentationController_Active`, all three legacy clients disabled, no `RacePersonalBestBoardClient_Active`, `ShowCheckpointArrows=false`, `ShowRouteArrowMarkers=true`, `MobileCheckpointUIScale=0.6` and retained authored `ArrowMarkers`.

The Studio mirror is refreshed and no additional export is pending. Do not commit `docs/studio-full-export-paste.txt`.

## Risks And Rollback

- The installer uses exact, uniqueness-checked route-guide anchors from the confirmed mirror and accepts the known V1/V1.1 lifecycle revisions. A live mismatch is a hard stop.
- The active shared UI foundation's old recovery installer still describes the retired session-control client as an enabled styling target. Do not rerun that old `INSTALL` after this lifecycle V1 without first updating its recovery contract.
- Native prompt appearance is Roblox-owned and should be checked on a real controller and touch device/emulator.
- Eligible aura effects are explicitly enabled. The controller remembers authored values only so script removal/rollback can restore them.
- Prompt suppression is client presentation only. The server continues to create, recover and validate the one native prompt.
- V1.3 deletes one exact, mirrored superseded LocalScript. The installer holds its source/disabled state/attributes only in memory during the transaction and recreates it if committed audit fails; no in-game backup object is created.
- V1.4 uses runtime `DeviceSafeInsets`; verify physical devices/emulator cutouts and both orientations because those inset values are device/Roblox-client dependent.
- The repeated `ClipsDescendants is always true on CanvasGroup` warning comes from an unrelated onboarding objective-card assignment. Roblox ignores it; existing glow-safe padding remains intact, so it is accepted as a non-blocking handoff note.
- Clean rollback is the Studio history version immediately before V1.4. Git now captures the confirmed V1.4 mirror.
