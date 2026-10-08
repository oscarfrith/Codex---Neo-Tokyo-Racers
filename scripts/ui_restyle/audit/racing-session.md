# UI restyle audit: group "racing-session"

Read-only audit, 2026-10-08, live Studio "Space Racers v3" (placeId 93959280828322), Edit datamodel.
Every script below was read in full with `script_read`. Line numbers are live-Studio line numbers.
Nothing was changed in Studio or the repo. No Play session was run, so anything about rendered size
on a device is arithmetic from the source ("by source"), not an observation.

All seven listed paths exist as named (all `ModuleScript` under `ReplicatedStorage.Modules.Game.Racing`).

| Script | Lines | Chars | Builds UI? |
|---|---:|---:|---|
| RaceSessionPresentationClient | 325 | 33,119 | Yes: in-race HUD |
| RaceTimeTrialResultCoachClient | 231 | 23,199 | Yes: results |
| RaceCountdownPresentationClient | 69 | 5,523 | Yes: countdown card |
| RaceQueueClient | 61 | 7,379 | Yes: queue banner (and owns queue join/leave) |
| RaceTransitionClient | 409 | 15,757 | Minimal: black fade + one label (mostly logic) |
| RaceRouteGuideClient | 451 | 17,390 | Yes: world checkpoint pill, world arrows, WRONG WAY label |
| RaceLifecyclePresentationClient | 309 | 11,113 | No UI. Start-zone aura/prompt owner, legacy GUI killer |

Supporting scripts read for context (not in the group): `StarterPlayerScripts.ClientBase` (113 lines, whole),
`Modules.Core.ClientLifecycle` (49, whole), `Modules.Game.UI.RacingUIComponents` (194, whole),
`RacingMobileScaledDesktopLayout` (89, whole), `LoadingTransitionUI` (28, whole), `RaceRouteDefinition` (227, whole),
`ResponsiveUIFoundation` L1-98, L205-443, `DesktopFreeRoamHudUI` L1325-1365, `MobileFreeRoamHudUI` L316-332,
`ServerStorage.Modules.Core.FeatureFlags` (61, whole), and payload-building ranges of
`ServerStorage.Modules.Game.Racing.MatchmakingServer` and `TimeTrialServer`.

---

## 0. Things that apply to the whole group

### 0.1 Start-up and lifecycle (same for all seven)

- Started by `StarterPlayer.StarterPlayerScripts.ClientBase` (the composition root). Its `entries` table lists
  each module by name and dotted path (ClientBase L32-56 for the Racing block). All seven have `dependencies={}`.
- `ClientLifecycle.start` (L20-47) `task.spawn`s every entry at once, waits for dependencies, `require`s the path
  and calls `feature.start()` inside `xpcall`. Status goes to `ClientBase.StartupState` attributes
  (`pending` / `starting` / `ready` / `failed` / `blocked` / `skipped`).
- Every module has the same wrapper: `Client.start()` guarded by a `state` flag, whole body inside one
  `xpcall` closure. **Nothing is exported except `start`.** There is no `stop`, no cleanup function, no public API.
  All state and all instance references are closure locals. Other modules cannot call into them.
- None of them is ever stopped. Connections live for the session. Only RaceRouteGuideClient (L436-442) and
  RaceLifecyclePresentationClient (L282-297) disconnect on `PlayerScripts.Destroying`.
- `ClientLifecycle` has a `tool` gate (Studio-only dev tools) but **no flag-selected alternate path**. The resolver
  is the closure at ClientBase L105-109 (`entry.path` -> `WaitForChild` chain -> `require`).
- Start order between the seven is not defined (all spawned in the same frame, no dependencies between them).
  The one cross-module ordering need is handled by an attribute (see 3.5).

### 0.2 Shared UI helpers they use

`RacingUIComponents` (`UI`): `Colour(name)`, `Layout(name)`, `Type(name)`, `AssetValue`, `Asset`, `Font`, `Corner`,
`SetCorner`, `Stroke`, `Label`, `Panel`, `Button`, `AttachResponsiveScale`, `ConfirmationModal`, `FormatMoney`.
Relevant behaviour for a restyle:

- `UI.Colour` reads `Config.UI.Racing.Colours` (12 Color3Values: Danger, Disabled, ElectricBlue, Muted, Outline,
  OutlineSoft, Panel, PanelBlue, PanelDeep, PanelSoft, Telemetry, Text). Fallback is white.
- `UI.Font` (L44-53): `Enum.Font.GothamBold/Gotham` then `Font.new(Typography.FontFamily)`; the family value is
  `rbxasset://fonts/families/Michroma.json` and the same string is the hard-coded fallback.
- `UI.Panel` (L89-111): Frame + UICorner + **two UIStrokes** ("Stroke" and "GlowStroke") = 4 instances.
- `UI.Button` (L113-154): TextButton + UICorner + bevel overlay (Frame + UICorner + UIGradient) + 2 UIStrokes
  = 7 instances. Hover is `MouseEnter`/`MouseLeave` only: no `SelectionGained`, no pressed state, no touch feedback.
- `UI.AttachResponsiveScale` (L155-175): UIScale = clamp(min((vx-2*max(48,0.10vx))/1200, (vy-2*max(48,0.08vy))/720),
  `ResponsiveScaleMin` 0.55, `ScaleMax` 1.15). Listens only to the camera that exists at attach time.
- `RacingMobileScaledDesktopLayout.Attach` (L19-86): 1200x720 shell, UIScale = clamp(min((vx-2*SafeSide)/1200,
  (vy-SafeTop-SafeBottom)/720), 0.25, 1) with config attributes `SafeTop=72, SafeBottom=10, SafeSide=10`.
  Rebinds on `CurrentCamera` change and on attribute change; cleans up on ancestry loss.
- `ResponsiveUIFoundation.Confirmation` (L315-441) is the real shared confirmation: own ScreenGui
  `SharedConfirmationOverlay` (DisplayOrder 1250), safe-area canvas, Escape / ButtonB bound through
  ContextActionService at priority 10000, `NextSelectionLeft/Right`, auto-selects NO for keyboard/gamepad.
  **The in-race exit confirmation does not use it** (see 1.10).

### 0.3 DisplayOrder stack (racing surfaces, live values)

| Order | ScreenGui | Owner |
|---:|---|---|
| 78 | `RaceRouteGuide_Phase5` (WRONG WAY label) | RaceRouteGuideClient L271-276 |
| 85 / 88 | free-roam HUD desktop / mobile | DesktopFreeRoamHudUI L1041 / MobileFreeRoamHudUI L75 |
| 96 | mobile drive controls | MobileDriveControlsClient L42 |
| 155 | `SharedInRaceHUD` | RaceSessionPresentationClient L80 |
| 170 / 180 | race browser / race entry | other group |
| 190 | `RaceQueueBanner` | RaceQueueClient L30 |
| 205 | `RaceCountdown` | RaceCountdownPresentationClient L20 |
| 210 | `RaceTransitionFade_Phase8H` | RaceTransitionClient L40-46 |
| 220 | `UnifiedRaceResults` | RaceTimeTrialResultCoachClient L202 |
| 1100 / 1250 | top notification / shared confirmation | ResponsiveUIFoundation L453 / L332 |

`script_grep` for each of the six ScreenGui names found **no reference outside the script that creates it**.
So no other script depends on these instance names.

### 0.4 Remote traffic the group depends on

Remotes: `ReplicatedStorage.Remotes.Racing.RaceEvent` (RemoteEvent), `RaceQueueEvent` (RemoteEvent),
`RaceRequest` (RemoteFunction, time-trial actions), `RaceQueueRequest` (RemoteFunction, race actions).
Both RemoteFunctions go through `Core.Net.invoke` on the server (TimeTrialServer L1330, MatchmakingServer L1191).

Important server fact: `MatchmakingServer` sends most race payloads **twice**, once on `RaceQueueEvent` (`fire`, L127)
and once on `RaceEvent` (`fireRace`, L131). `TimeTrialServer.fire` uses `RaceEvent` only.

Event types actually sent by the server (from `Type = "..."` sites):

- Time trial (RaceEvent): `TimeTrialStaged`, `TimeTrialCountdownReveal`, `TimeTrialCountdownScheduled`,
  `TimeTrialStarted`, `TimeTrialCheckpoint`, `TimeTrialLapCompleted`, `TimeTrialReset`, `TimeTrialFinished`,
  `TimeTrialEnded`, `TimeTrialError`, `OpenRaceEntry`, `RaceVisibilityUpdate`.
- Race (both events unless noted): `QueueJoined`, `QueueUpdate`, `QueueLeft` (queue event only), `RaceQueueError`,
  `RaceStaged`, `RaceCountdownReveal`, `RaceCountdownScheduled`, `RaceStarted`, `RaceCheckpoint`, `RaceLapCompleted`,
  `RacePositionUpdate`, `RaceReset`, `RaceFinished`, `RaceDNF` (queue event only), `RaceExitedToStart`, `RaceEnded`.
- **Never sent:** plain `TimeTrialCountdown` / `RaceCountdown`. Every client branch on those two names is dead.

Payload fields a new HUD/results view can rely on (no server change needed):

| Event | Fields |
|---|---|
| `RaceStarted` (MM L1054-1059) | RunId, EventId, RouteId, DisplayName, StartServerClock, **StartServerTime** (= GoAt, `GetServerTimeNow` basis), GateCount, NextGateIndex, CurrentLap, LapTarget, ParticipantCount |
| `TimeTrialStarted` (TT L1208-1222) | RunId, EventId, RouteId, DisplayName, StartServerClock, **StartServerTime**, GateCount, NextGateIndex, RouteType, LapTarget, CurrentLap, InfiniteLaps |
| `TimeTrialStaged` (TT L1117-1134) | + VehicleTier, VehicleIndex, Medals, Countdown, StreamPosition |
| `RaceCheckpoint` (MM L731) | NextGateIndex, GateCount, CheckpointIndex, Elapsed, LapElapsed, CurrentLap, LapTarget |
| `TimeTrialCheckpoint` (TT L932-944) | NextGateIndex, GateCount, CheckpointIndex, Elapsed (split), **Splits[]** {CheckpointIndex, Elapsed, Lap}, CurrentLap, LapTarget, InfiniteLaps |
| `RaceLapCompleted` (MM L725) | Lap, CurrentLap, LapTarget, LapElapsed, LapTimes[], BestLapSeconds, BestLapIndex, NextGateIndex, GateCount |
| `TimeTrialLapCompleted` (TT L873-887) | Lap, NextLap, LapTarget, InfiniteLaps, Elapsed (lap time), BestLapSeconds, BestLapIndex, GateCount, NextGateIndex (no LapTimes array) |
| `RacePositionUpdate` (MM L320-333) | RunId, Place, ParticipantCount, CurrentLap, CompletedLapCount, LapTarget, **Positions[]** {UserId, Name, Place, Finished, NextGateIndex, CurrentLap, CompletedLapCount, LapTarget, FinishElapsed, VehicleId, VehicleName}. Sent on every checkpoint by any racer. No gap times. |
| `QueueUpdate` (MM L1084-1093) | EventId, DisplayName, Count, MinPlayers, MaxPlayers, SecondsRemaining, Message. Sent once per second. |

**Result payloads (where results come from):**

`RaceFinished` is built in `MatchmakingServer.finishEntry` (L687-708), after `GrantRaceReward`:
Type, RunId, EventId, RouteId, DisplayName, **Place**, ParticipantCount, **Elapsed**, GateCount, NextGateIndex,
CurrentLap, CompletedLapCount, LapTarget, **LapTimes[]**, **BestLapSeconds**, BestLapIndex, **RaceMedal**,
**RewardGranted**, **RewardAmount**, **RewardMessage**, SelectedVehicleId.
The results client uses only DisplayName, Place, RewardAmount, Elapsed, EventId. BestLapSeconds, LapTimes,
RaceMedal, RewardGranted and RewardMessage are sent and ignored. The finishing order table comes from
`RacePositionUpdate.Positions`, not from this payload.

`TimeTrialFinished` is built in `TimeTrialServer.sendTimeTrialResult` (L750-816):
Type, EventId, RouteId, DisplayName, RunId, **Elapsed**, GateCount, VehicleTier, VehicleIndex, SelectedVehicleId,
Medals, **Medal**, MedalRank, MedalTargetSeconds, **NextMedalName, NextMedalSeconds, NextMedalDelta**,
**PreviousBestSeconds, PersonalBestSeconds**, PersonalBestMedal, **IsPersonalBest**, Splits, LapTimes[],
**BestLapSeconds**, BestLapIndex, CompletedLapCount, CurrentLap, LapTarget, RouteType, **FinishReason**
("Finished" / "LapTarget" / "PointToPoint" / "Quit"), CanRetry, **RewardGranted, RewardAmount**, RewardCash,
RewardMessage, **IntegrityRejected**, Message.
Used by the client: DisplayName, FinishReason, Medal, RewardAmount, BestLapSeconds/Elapsed, IsPersonalBest, LapTimes,
BestLapIndex, VehicleTier, EventId, SelectedVehicleId, LapTarget. The next-medal, previous-best and integrity fields
are sent and ignored.

**Neither result payload carries driver XP.** XP is granted later by `ProgressionService` (L147-148, reason
`RaceReward` / `TimeTrialReward`, `Rules.RaceXp(amount)`) and shows up only as replicated player attributes
`Rank`, `XpIntoRank`, `XpForNext` (L46-48). The style sheet's results hero number "driver XP" has no payload field today.

---

## 1. RaceSessionPresentationClient (in-race HUD)

### 1.1 Purpose and lifecycle
Shared in-race HUD for Race and Time Trial: lap card, primary metric card (position in a race, running lap timer in a
time trial), session board (live order or lap list), simplified race map with player marker, RESET / EXIT buttons and
the exit confirmation. Built once at start (L79-182), hidden (`canvas.Visible=false`), shown and hidden by RaceEvent
payloads. Never destroyed. Permanent connections: `Workspace.CurrentCamera` changed (L114), `gui.AbsoluteSize` (L115),
camera `ViewportSize` (rebinds, L108-113), 4 button `Activated` (L197-199), `MapOpacity.Changed` (L205-208),
`raceEvent.OnClientEvent` (L303), `RunService.RenderStepped` (L317).

### 1.2 Instance tree
```
PlayerGui.SharedInRaceHUD  ScreenGui  DisplayOrder=155  IgnoreGuiInset=true  ResetOnSpawn=false
                                      ZIndexBehavior=Global  ScreenInsets=None  ClipToDeviceSafeArea=false   (L80)
  ReferenceCanvas  Frame (transparent, Visible toggled)  + UIScale                                          (L81-82)
    LapProgress     UI.Panel + metricCard gradient      top-left      "LAP" / "1 / 3"                        (L145,154-155)
    PrimaryMetric   UI.Panel + metricCard gradient      top-centre    "POSITION 2 / 6" or "CURRENT LAP 00:41.228" (L146,156-157)
    SessionBoard    UI.Panel, borderless, Clips         top-right     boardTitle (dead) + boardBody rows     (L147,158-159)
    RaceMap         UI.Panel, borderless, Clips         bottom-left   SimplifiedRaceMap ImageLabel > PlayerMarker (L148-152)
    SessionControls Frame                               bottom-centre RESET, EXIT buttons                    (L165-174)
    ExitConfirmationShade Frame ZIndex 100 > ExitConfirmation panel (title, copy, NO, YES)                   (L176-182)
  ExitConfirmationFullScreenBackdrop  Frame, black 0.34, Active, ZIndex 90, full screen (outside the canvas) (L175)
```
At start it destroys any existing `SharedInRaceHUD` (L79).
Static instance count is about 66 (4 panels x 4-5, 5 labels, 4 buttons x 7, map 2, containers). Board rows add up to 42.

### 1.3 Scaling and layout
- **Reference canvas 1920x1080, uniform UIScale, safe-area aware** (L83-116). `safeViewportRect` uses
  `GuiService:GetInsetArea(ScreenInsets.None)` and `(DeviceSafeInsets)` inside `pcall`; the API exists in this Studio
  build (checked read-only: both return a Rect). `uniformScale = max(0.01, min(safe.X/1920, safe.Y/1080))`.
  The canvas is then **resized to `safeSize / uniformScale`** and centred on the safe rect (L104-106), so the canvas
  always covers the whole safe area in reference units. On 3440x1440 the scale is 1.333 and the canvas is 2580x1080
  logical: corner clusters stay on the real screen edges. This is the best scaling base in the group.
- No min or max clamp on the scale apart from 0.01. No breakpoints.
- Children are placed in reference pixels against canvas edges: left card `fromOffset(30,105)`; centre card
  `UDim2.new(.5,-w/2,0,30)`; board `UDim2.new(1,-30-340,0,38)`; map `UDim2.new(0,16,1,-16-420)`; controls
  AnchorPoint (.5,1) at `UDim2.new(.5,0,1,-30)` (desktop).
- All sizes are offset. All text is fixed `TextSize` in reference pixels, scaled only by the UIScale. No `TextScaled`,
  no `UITextSizeConstraint`, no `UIListLayout` / `UIPadding`: every row and label is positioned by hand.
- Viewport change: `updateScale` on camera `ViewportSize`, `CurrentCamera` and `gui.AbsoluteSize`. Positions and
  sizes read from config are **not** re-read (config is read once at build), except row metrics which are read on
  each board rebuild and `MapOpacity` which has a `Changed` listener.
- Only device insets are considered. The Roblox top bar (core UI inset) is not; the HUD keeps clear by fixed offsets.
- Rendered text size by source: 1920x1080 scale 1.0 (heading 15, value 36, rows 16, buttons 13);
  1280x720 scale 0.667 (heading 10 px, value 24, rows 10.7, **button text 8.7 px**);
  3440x1440 scale 1.333; 3840x2160 scale 2.0.

### 1.4 Config read
`Config.UI.Racing.InRace` NumberValues via `N()` (L22): PanelTransparency, MetricCardTransparency,
MetricCardCornerRadius, DataRowTransparency, DataRowCornerRadius, ProgressOffsetX/Y, ProgressWidth/Height,
MetricWidth, MetricHeight, EdgeY, BoardOffsetX/Y, BoardWidth, BoardHeight, MapOffsetX/Y, MapWidth, MapHeight,
MapInnerPadding, MapOpacity, MetricHeadingSize, MetricValueSize, BottomY, DataRowHeight, DataRowGap,
DataRowTextSize, DataRowMetricSize, LocalRowTransparency, BoardAvatarSize.
Color3Values: FirstPlaceColor, SecondPlaceColor, ThirdPlaceColor (L140-144).
`InRace.Mobile` via `MN()` (L24-27): Enabled, ProgressOffsetX/Y, ProgressWidth/Height, MetricWidth, MetricHeight,
MetricOffsetY, BoardOffsetX/Y, BoardWidth, BoardHeight, MetricHeadingSize, MetricValueSize, DataRow*, BoardAvatarSize,
SessionButtonWidth/Height/Gap/TextSize, SessionControlsCenterX, SessionControlsBottomOffset.
Present in the folder but **never read** by this script: `BoardHeadingSize`, `BoardMetricSize`, `BoardRowHeight`,
`BoardTextSize`, `EdgeX`.
Also: `Config.UI.Racing.Colours` (through `UI.Colour`); `Config.Racing.RaceCatalog` / `TimeTrialCatalog` event folders
(attributes `EventId`, `RouteId`/`RaceRouteId`, `RaceHudMapImage`, L30-31, L41-47); `Config.Racing.HudMapCatalog.<RouteId>`
(Enabled, Image, ImageWidthPixels, ImageHeightPixels, MapRotationDegrees, StudsPerPixel, FlipX, FlipY, StartPixelX/Y,
ClampMarkersToMap, Smoothing, MarkerRotationOffsetDegrees, PlayerMarkerScale, UseConfiguredWorldAnchor, WorldAnchorX/Z,
AnchorPartName; L216-230; `ShowOtherPlayers` and `OtherPlayerMarkerScale` exist but are not implemented);
`Config.Racing.PresentationPerformance.HudMapSubjectResolveSeconds` (L242);
`Config.UI.DesktopFreeRoamHud.Assets.MapPlayerIcon` and `.Layout.MapPlayerIconSize` (L152, L265);
`ResponsiveUIFoundation.ConfirmationLayout()` constants (L177).

### 1.5 Remotes, bindables, state, API
- Listens: `RaceEvent.OnClientEvent` (L303-316). Handled kinds: TimeTrialStaged/Started/Checkpoint/LapCompleted/Reset,
  RaceStaged/Started/Checkpoint/LapCompleted, RacePositionUpdate, and the terminal kinds
  TimeTrialFinished/RaceFinished/RaceEnded (hide) and TimeTrialEnded/TimeTrialError/RaceExitedToStart (hide).
  Not handled: RaceDNF, RaceReset.
- Invokes: `RaceRequest:InvokeServer("GetTimeTrialPersonalBest", {EventId, VehicleTier})` (L271, on TimeTrialStarted);
  Reset/Exit (L190-196): time trial -> `RaceRequest` `ResetActiveTimeTrial` / `ExitActiveTimeTrial`; race ->
  `RaceQueueRequest` `ResetToLastCheckpoint` / `ExitRaceToStart`, payload `{RunId, EventId}`.
- Fires bindables: `Runtime.UI.FreeRoamHudPresentationMode` `{Owner="RaceSession", Active, KeepTelemetry=true}` (L164)
  on every `show`/`hide`; `Runtime.Racing.RaceTransitionRequest` steps `FadeOut` / `RestoreCamera` / `FadeIn` (L189-194).
- Reads world: `Workspace.World.RaceRoutes.<RouteId>` anchor part (L66-75), local character seat / vehicle root (L55-65).
- No public API. Local state `active` = {Mode, RunId, EventId, VehicleTier, CurrentLap, LapTarget, ParticipantCount,
  LapTimes, Positions, Place, Running, LapLocalStart, PersonalBest}.
- `KeepTelemetry=true` means the free-roam HUD stays up in telemetry-only mode: **the speed gauge during a race is
  drawn by the free-roam HUD, not by this script.** The free-roam minimap is paused during a race
  (`PauseFreeRoamMapDuringRace`, DesktopFreeRoamHudUI L1142).

### 1.6 Input
Mouse / touch `Activated` on RESET, EXIT, NO, YES only. No keyboard shortcut, no ContextActionService, no
`GuiService.SelectedObject`, no selection wiring. Escape / gamepad B do not cancel the exit confirmation.

### 1.7 Per-frame and rebuild work
- `RenderStepped` (L317) is connected for the whole session; it returns immediately when no session is active.
  While active, every frame: `updateHudMapMarker(dt)` (L233-268: transform maths, one `FindFirstChild` for
  `MapPlayerIconSize`, one `AbsoluteSize` read, and writes `Size`, `Position`, `Rotation`, `Visible` on the marker
  whether or not they changed) and, in a time trial, `metricValue.Text = timeText(...)` (a `string.format` and a
  text layout every frame; Michroma is proportional, the label is centre-aligned, so the digits jitter).
- The lap timer is `os.clock()` since the `TimeTrialStarted` / `TimeTrialLapCompleted` event **arrived** (L306, L308).
  It is not tied to `StartServerTime`, and `TimeTrialReset` does not touch it.
- **Race mode has no timer at all.** The centre card shows position; nothing shows elapsed race time.
- Rebuild: `refresh()` (L298-302) runs on every handled event and calls `clear(boardBody)` then rebuilds every row.
  Race board: up to 6 rows x 7 instances (Frame, UICorner, UIGradient, 2 labels, avatar ImageLabel, UICorner) = 42
  instances destroyed and recreated per event. A racer crossing a checkpoint produces `RaceCheckpoint` plus
  `RacePositionUpdate` (2 rebuilds for that racer, 1 for every other racer).
  Time-trial board: PB row + one row per completed lap (5 instances each), rebuilt on every checkpoint.
- Avatars: `GetUserThumbnailAsync` once per user, cached in a table (L201-202).

### 1.8 Mobile / touch
`touch = UserInputService.TouchEnabled and Mobile.Enabled` (L23-26; true in config). On touch: positions and sizes come
from `InRace.Mobile`; the race map is hidden (`map.Visible = not touch`, L149; image cleared, L269); RESET and EXIT are
stacked vertically at `UDim2.new(0, SessionControlsCenterX=700, 1, -24)` (L168-174); `suppress()` disables five legacy
GUI names that no longer exist (L117-125). The same uniform UIScale applies, so on a phone the "mobile" sizes are
multiplied by about 0.36 (see 1.10).

### 1.9 Hard-coded style
- Colour: 3 `Color3.fromRGB` (L143: placement fallbacks 255,190,45 / 205,215,225 / 205,125,65), 1 `Color3.new(0,0,0)`
  backdrop (L175). 36 `C("...")` token reads: PanelDeep, PanelSoft, PanelBlue, Outline, OutlineSoft, Text, Telemetry.
- Font: none literal; all text goes through `UI.Label` / `UI.Button` (Michroma via config).
- Sizes: 20 `TextSize=` sites, 39 `fromOffset`, 18 `UDim2.new`. Literal examples: label rows `(0,6)` h26 and `(0,30)`
  (L154-157); controls 360x38, buttons 150x32 and 170x32, TextSize 13 (L165-167); row insets 8 / 10 / 30 / 40 / 50 / 60
  (L276-294); avatar corner 5 (L202); button transparency .48 (L166-167).

### 1.10 Defects
1. **HUD comes back after the session ended (multiplayer, by source).** L313: `RacePositionUpdate` with no active
   session calls `show(payload,"Race")`. The server calls `broadcastPositions(race)` right after `RaceFinished`
   (MM L704-706) and right after `RaceExitedToStart` (MM L646-661), and exited or finished players stay in
   `race.Participants`. So a player who finished or exited is re-shown the in-race HUD on the next position update,
   and again on every other racer's checkpoint, until `RaceEnded`. It also re-asserts the `RaceSession` presentation
   owner, so the free-roam HUD stays in racing mode. Default MinPlayers is 2, so this is the normal case.
2. **Phone sizes (by source).** The canvas scale is not touch-aware. On an 844x390 viewport the scale is about 0.36:
   `SessionButtonHeight=48` renders about 17 px tall, button text 15 -> 5.4 px, row text 14 -> 5 px, heading 13 -> 4.7 px.
   The 48 px touch target in the style sheet's "must preserve" list is not met by the current mobile HUD.
3. `SessionControlsCenterX=700` is an absolute X in a canvas whose width varies with aspect ratio (L170), so the
   mobile RESET/EXIT stack lands at a different fraction of the screen on every phone.
4. Exit confirmation is hand-built from `ConfirmationLayout()` numbers (L175-182) instead of
   `UI.ConfirmationModal` / `Foundation.Confirmation`: no Escape/B cancel, no controller focus, different ScreenGui
   and z-order from every other confirmation. YES (a destructive quit) is styled as the primary blue/teal action.
5. Time-trial board grows without bound in infinite-lap sessions: every lap adds a row, the panel clips at 276 px
   (about 5 rows), the newest laps are the ones clipped, and all rows are rebuilt on every checkpoint (L272-283).
6. Whole-board destroy-and-rebuild on every event (L273, L286) instead of updating six pooled rows.
7. Per-frame timer text with a proportional font (L317) and per-frame unconditional marker writes (L265-267).
8. Dead code and dead config: `boardTitle` (L158), `suppressed` (L117), `suppress()` targets, `hide(_restoreLegacy)`
   argument, branches for `TimeTrialCountdown`/`RaceCountdown`, unused locals `kit`, `shared`, `racingRemotes`, `L`, `T`,
   `freeRoamHudConfig`; five unread config values (see 1.4). `borderless()` leaves 4 invisible UIStrokes alive.
9. Position reads `-- / N` until the first `RacePositionUpdate`; the RaceEvent copy of `RaceStaged` appears to omit
   `ParticipantCount` (MM L966-975), so the count reads 1 until `RaceStarted`.
10. Layout config is read once; changing `InRace` values needs a new Play session (row metrics excepted).

### 1.11 Seam
- **State / logic:** the `active` reducer over RaceEvent payloads (L269-270, L303-316), `queryPB` (L271),
  `invokeSession` (L190-196), presentation-mode publish (L164), and the map projection maths
  (`prepareHudMapSession` L216-232, the transform half of `updateHudMapMarker` L246-264).
- **View:** L79-182 construction, `metricCard`/`dataRow`/`avatar`, `renderTimeTrialBoard`, `renderRaceBoard`, the
  label writes in `refresh` and in `RenderStepped`.
- Logic and view share one closure and nothing is exported, so a new view cannot reuse the old logic by calling it.
  A new module **can** listen to the same `RaceEvent` (multiple listeners are fine) and call the same remotes.
- **Single-owner items:** the `RaceSession` owner key on `FreeRoamHudPresentationMode`; the RESET / EXIT requests;
  the visible HUD itself. Two HUD modules must never both be started.
- Cleanest switch: choose the module path in the composition root (ClientBase resolver, L105-109) from the style
  setting, so exactly one of {this script, new HUD module} is started. This script stays byte-identical.
  The new module should be two files: a state module (reducer + map maths, no instances, unit-testable) and a
  view module built from the shared components. It should fix defect 1 by ignoring `RacePositionUpdate` when
  no session is active or `RunId` differs.
- New ScreenGui must not be named anything in the legacy kill list (section 7.5).

---

## 2. RaceTimeTrialResultCoachClient (results)

### 2.1 Purpose and lifecycle
Results screen for races and time trials. `build()` once at start (L201-212, called L223), hidden. `show(mode,payload)`
on `RaceFinished` / `TimeTrialFinished`; body and footer are destroyed and rebuilt on each render. Permanent
connection: `raceEvent.OnClientEvent` (L214). Footer button connections are recreated on each render.

### 2.2 Instance tree
```
PlayerGui.UnifiedRaceResults  ScreenGui  DisplayOrder=220  IgnoreGuiInset=true  ResetOnSpawn=false          (L202)
  overlay  Frame  black, transparency .32, full screen, Visible toggled                                    (L203)
    shell  UI.Panel  AnchorPoint .5,.5 centred, 2 px stroke, Clips                                          (L204-205)
      title (left, event name)   complete (centre, "RACE COMPLETE" / status)   divider                      (L206-208)
      body   Frame   rebuilt per render                                                                     (L210)
        race:       left 50% { YourResult panel, RaceHighlights panel }   right 50% { RaceResults table }   (L150-188)
        time trial: left 50% { YourResult panel, SessionLaps list }       right 50% { GlobalTop20 table }   (L124-142)
      footer Frame   two buttons, each 50% width                                                            (L211, L117-122)
```
Instance count per render, by source: race about 50 + 7 per finisher + 14 footer (about 105 with six racers);
time trial about 145 with a full top-20 board plus about 3 per lap.

### 2.3 Scaling and layout: three different mechanisms
`scaledDesktop = MobileScaledDesktop.IsEnabled(touchDevice)`; `touch = touchDevice and not scaledDesktop` (L27-28).
- **Desktop:** shell `fromOffset(ShellWidth=1200, ShellHeight=720)` + `UI.AttachResponsiveScale` (L205).
  Scale by source: 1280x720 -> 0.84 (shell 1008x605); 1920x1080 -> 1.15 (clamped; 1380x828);
  2560x1440, 3440x1440 and 3840x2160 -> **1.15 (clamped)**. The panel does not grow above 1080p: on 3440x1440 it
  covers 40% of the width, on 4K 36% x 38% with 10 to 16 px text.
- **Touch, config `MobileScaledDesktop.Enabled=true` (the live path):** the desktop layout inside a 1200x720 shell,
  scale clamp(min((vx-20)/1200, (vy-82)/720), 0.25, 1). On 844x390 that is about 0.43: shell 513x308 px, footer buttons
  about 20 px tall, table text 9 to 12 -> 4 to 5 px (by source).
- **Touch, config off (dormant):** shell `UDim2.new(1,-16,1,-16)`, no UIScale, separate hard-coded sizes. The source
  still carries **87 `touch and A or B` ternaries** for this path.
- Inside the shell everything is offsets from literals; columns are scale fractions (.12/.43/.25/.20) with 6 px insets.
  Lists are `ScrollingFrame` + `AutomaticCanvasSize.Y`, rows placed by `(index-1)*rowH` (no UIListLayout).
- No safe-area handling on the desktop or dormant-touch paths; the scaled-desktop path uses fixed margins, not insets.
- `AttachResponsiveScale` binds only to the camera present at build; a replaced camera stops updating the scale.

### 2.4 Config read
`Config.UI.Racing.Layout`: PanelTransparency, ShellStrokeWidth, ShellWidth, ShellHeight, HeaderHeight, OuterPadding,
Gap (+ DesktopEdgeBufferXRatio/YRatio, ResponsiveScaleMin, ScaleMax, CornerRadius through the components).
`Config.UI.Racing.Typography.Heading` (L206; everything else is a literal). `Config.UI.Racing.Assets.MedalAtlas`,
`MedalAtlasCellSize` (L59-63). `Config.UI.Racing.Colours` via `C`. `Config.UI.Racing.MobileScaledDesktop` attributes.

### 2.5 Remotes, bindables, state
- Listens `RaceEvent`: `RaceFinished` -> show race; `TimeTrialFinished` -> show time trial; `RacePositionUpdate` ->
  store positions and **re-render the whole race result if open** (L216); hide on TimeTrialEnded, RaceStaged,
  RaceStarted, TimeTrialStaged, TimeTrialStarted, RaceExitedToStart.
- Invokes: `RaceRequest` `GetTimeTrialLeaderboard {EventId, VehicleTier, Limit=20}` (L140; reads `Entries[]` with Rank,
  DisplayName/Username, BestSeconds, VehicleName/VehicleId, UserId), `ExitFinishedTimeTrial` (L145),
  `StartStagedTimeTrial {EventId, VehicleId=SelectedVehicleId, LapCount=LapTarget}` (L147);
  `RaceQueueRequest` `ExitRaceToStart` (L191).
- Fires bindables: `RaceTransitionRequest` steps BeginLoading / CompleteLoading / FailLoading (L144-146, L190-192);
  `FreeRoamHudPresentationMode {Owner="RaceResults", Active, KeepTelemetry=false}` (L92-96);
  `FreeRoamVehicleExited` (L101-104); `StartRaceQueueRequest {EventId, VehicleId, DisplayName}` for RACE AGAIN (L193).
- Reads player attributes `LastRacingEventId`, `LastRacingVehicleId` (set client-side by RaceQueueClient L44).
- No public API.

### 2.6 Input
Footer buttons use **`MouseButton1Click`** (L121), not `Activated`. No `SelectedObject`, no selection wiring, no
keyboard or ContextActionService binding. A controller cannot press the buttons except through the virtual cursor.
No busy guard: a double click sends the exit or restart request twice.

### 2.7 Per-frame and rebuild
No per-frame work. Full `clear(body)` + `clear(footer)` rebuild on every render. At a race finish the server sends
`RaceFinished` and then `RacePositionUpdate`, so the result is built twice within one frame or two; it is rebuilt again
for every checkpoint any remaining racer crosses (scroll position and hover state reset each time).

### 2.8 Mobile
Covered in 2.3. With the scaled-desktop flag on, a phone gets the desktop screen at about 0.43 scale.
`setSuppressed` on the dormant touch path toggles a legacy GUI name that no longer exists (L97-100).

### 2.9 Hard-coded style
- Colour: 1 literal (`Color3.new(0,0,0)` overlay, L203); 49 token reads (PanelDeep, PanelSoft, PanelBlue, Outline,
  Telemetry, Text, Muted).
- Font: through `UI.Label` only.
- Sizes: 28 `TextSize=` sites, nearly all literal pairs such as `touch and 9 or 13`. Smallest desktop sizes: table
  header 9 (L111), leaderboard rows 10 (L142), vehicle column 10 (L187), captions 11 (L162, L164).
  38 `fromOffset`, 69 `UDim2.new`.
- Money: private `money()` (L46-50, `$1,234`), not the shared compact formatter (`UI.FormatMoney`).

### 2.10 Defects
1. Three scaling mechanisms in one screen, none shared with the in-race HUD; the desktop cap of 1.15 leaves a small
   island on 1440p, ultrawide and 4K (2.3).
2. Phone: scaled-desktop path gives roughly 20 px buttons and 4 to 5 px table text (by source).
3. **Time-trial results have no buttons until the leaderboard call returns.** `renderTimeTrial` yields on
   `GetTimeTrialLeaderboard` at L140 and only creates the footer at L143. A slow or hung call leaves the player on a
   results screen with no way out. A second finish event during the yield would double-render.
4. Race results rebuilt wholesale on every `RacePositionUpdate` (L216), twice at the moment of finishing.
5. "RACE HIGHLIGHTS" is a placeholder: FASTEST LAP and HIGHEST SPEED are hard-coded `"--"` (L169, L172) and the two
   icons are grey squares (L173-175), although `BestLapSeconds` is in the payload. There is no data source for top speed.
6. `MouseButton1Click`, no focus, no busy guard (2.6). Not controller-operable.
7. Background differs by mode: for a race, RaceTransitionClient holds a full black fade under the results
   (`RaceFinished` -> `fadeOut("")`, L332-336, DisplayOrder 210); for a time trial the dimmed 3D scene shows through.
   A results design that assumes the car or scene behind it will not get that after a race (the server destroys the
   race vehicle 0.45 s after the finish, MM L705).
8. `lastPositions` is never cleared in `hide()` (L105-107); `RewardGranted=false` / `IntegrityRejected` are not
   shown (the prize just reads `$0`); `suppressed`, `shell`-level literals and the dormant touch branch are dead weight.

### 2.11 Seam
- **Logic:** `invoke`, the two footer action pairs (L143-147, L189-193), the leaderboard fetch, presentation publish,
  `fireDrivingExit`, show/hide dispatch (L196-221).
- **View:** `build`, `panel`, `heading`, `medalIcon`, `avatar`, `tableHeader`, `scrolling`, `footerButtons`,
  `renderTimeTrial`, `renderRace`.
- Same situation as the HUD: one closure, no API. A new results module can listen to `RaceEvent` and call the same
  four actions. **Single-owner:** the results surface and its actions, and the `RaceResults` presentation owner.
  Swap by module path; do not run both.
- The new module should render the static parts immediately, fetch the leaderboard asynchronously into its panel,
  and update position rows in place.

---

## 3. RaceCountdownPresentationClient

### 3.1 Purpose and lifecycle
Shared "GET READY 5..1 / GO!" card. Built at start (L19-29), hidden. Permanent connections:
camera `ViewportSize` (L23), `event.OnClientEvent` (L53). At the end of start it sets
`PlayerScripts.Runtime.Racing` attribute **`CountdownPresentationReady=true`** (L61).

### 3.2 Instance tree
```
PlayerGui.RaceCountdown  ScreenGui  DisplayOrder=205  IgnoreGuiInset=true  ResetOnSpawn=false               (L20)
  Frame (canvas 1920x1080, centred) + UIScale                                                              (L21-22)
    CountdownCard  Frame 260x260 centred, UICorner 18, 3-stop UIGradient, Clips                             (L25-27)
      Label "GET READY" (18)     Label number (130; GO! at 96)                                              (L28-29)
```
7 instances. Destroys an existing `RaceCountdown` at start (L19).

### 3.3 Scaling
Fixed 1920x1080 canvas centred in the viewport, `UIScale = min(vx/1920, vy/1080)` (L23). No safe-area handling, no
clamp. Binds only to the camera that exists at start; `CurrentCamera` replacement is not handled. Because the card is
centred this is harmless on ultrawide. Text is fixed sizes from config, scaled by the UIScale.

### 3.4 Config
`Config.Racing.FlowUI` NumberValues: CountdownCardSize 260, CountdownCardTransparency 0.18, CountdownGradientRotation
115, CountdownTextSize 130, GoTextSize 96, GoDuration 0.85, CountdownSeconds 5. Colours through `C`: PanelDeep,
PanelBlue, PanelSoft, Text, Telemetry.

### 3.5 Dependencies and API
- `RaceEvent` kinds: `*Staged` and `*CountdownReveal` -> hide; `*CountdownScheduled` -> `schedule(payload)` using
  `payload.GoAtServerTime` and `payload.Countdown`; `*Started` -> "GO!" for `GoDuration`; terminal kinds -> hide.
  The plain `*Countdown` branch (L57) is dead.
- **Contract with RaceTransitionClient:** `prepareStaging` (RaceTransitionClient L263-265, L284) waits up to 7.5 s for
  `CountdownPresentationReady` and reports the staging acknowledgement as *degraded* if it is not set. A replacement
  countdown module must set this attribute, or every race start is delayed and degraded.

### 3.6 Input
None.

### 3.7 Per-frame / polling
While a countdown is scheduled (about 5 s) a loop runs every 0.03 s reading `Workspace:GetServerTimeNow()` and only
writes the label when the whole second changes (L39-51). No work at other times. Nothing is rebuilt.

### 3.8 Mobile
No difference. On 844x390 the card is about 94 px square (by source).

### 3.9 Hard-coded style
No colour or font literals. Literals: corner 18 (L26), heading size 18 and position (L28), gradient transparency stops.
The card is a rounded gradient tile, the opposite of the sheet's square slate panel.

### 3.10 Defects
Camera rebind missing (L23); no safe-area or clamp; config read on every tick of `show` but layout fixed at build;
number label uses `Role="Metric"` with a proportional face.

### 3.11 Seam
Nearly pure view (about 35 lines of it). Swap by module path. Keep: the event mapping, the server-time schedule loop,
the token cancellation pattern, and **the readiness attribute**. Single-owner: the readiness attribute and the
on-screen countdown.

---

## 4. RaceQueueClient

### 4.1 Purpose and lifecycle
Owns joining and leaving a race queue **and** draws the queue banner. Built at start (L29-39), hidden. Permanent
connections: camera `ViewportSize` (L33), `startRequest.Event` (L44), `leave.Activated` (L45),
`RaceQueueEvent.OnClientEvent` (L46).

### 4.2 Instance tree
```
PlayerGui.RaceQueueBanner  ScreenGui  DisplayOrder=190  IgnoreGuiInset=true  ResetOnSpawn=false             (L30)
  Frame (canvas 1920x1080, centred) + UIScale                                                              (L31-32)
    QueueBanner  UI.Panel 720x86 at top-centre (y=24), Clips                                               (L34-35)
      title (event name, 15)   status (18, Telemetry)   details "2 / 6\n25s" (14)   LEAVE button (Danger)   (L36-39)
```
About 17 instances. At start it destroys a GUI named `RaceQueue_Phase8` (the old name), not its own name (L29).

### 4.3 Scaling
Same fixed 1920x1080 centred canvas with `UIScale = min(vx/1920, vy/1080)` (L33), camera-at-start only, no safe-area.
Because the canvas is fixed-size and centred, "top 24" is measured from the canvas top, not the screen top: on a
viewport taller than 16:9 (for example 1180x820) the banner sits about 78 px lower than intended. On 844x390 the
banner is about 260x31 px and the LEAVE button about 42x20 px (by source).

### 4.4 Config
`Config.Racing.FlowUI`: QueueBannerWidth 720, QueueBannerHeight 86, QueueBannerTop 24. Colours through `C`:
PanelDeep, Outline, Text, Telemetry, Danger.

### 4.5 Dependencies
- Listens: `Runtime.Racing.StartRaceQueueRequest.Event` (fired by RaceEntryMenuClient L23 and by the results
  "RACE AGAIN" button). On fire: sets player attributes `LastRacingEventId` / `LastRacingVehicleId`, shows
  "JOINING QUEUE", **invokes `RaceQueueRequest` `JoinQueue {EventId, VehicleId}`** (L44).
- `leave.Activated` -> `RaceQueueRequest` `LeaveQueue` (L45).
- `RaceQueueEvent`: QueueJoined / QueueUpdate -> show; QueueLeft, RaceQueueError, RaceStaged, RaceFinished, RaceDNF,
  RaceEnded, RaceExitedToStart -> hide; `RaceStarted` -> hide, then `RequestStreamAroundAsync` on the next gate (L27)
  and fire `Runtime.UI.FreeRoamVehicleSpawned` twice (L26, L51).
- Fires `FreeRoamHudPresentationMode {Owner="RaceQueue", Active, KeepTelemetry=true}` on **every** show and hide (L25).
- Reads player attribute `RaceQueueActive` (server-set).

### 4.6 Input
`Activated` on LEAVE. Nothing else.

### 4.7 Per-frame / polling
None. Event-driven at 1 Hz from the server. `show()` republishes the presentation mode on every `QueueUpdate`, so once
per second the free-roam HUD handler runs and force-closes the car panel, choice list and modal
(DesktopFreeRoamHudUI L1339-1346). Labels are updated in place (no rebuild).

### 4.8 Mobile
No difference; see 4.3 for size.

### 4.9 Hard-coded style
No colour or font literals. Literal text sizes 15 / 18 / 14 / 13 and all inner positions (L36-39).

### 4.10 Defects
Fixed centred canvas (wrong top edge on tall aspect ratios, no safe-area); camera rebind missing; phone touch target
about 20 px tall; presentation mode fired every second; `MinPlayers` is sent but not shown, so "2 / 6" does not say
how many are needed; destructive LEAVE is a red outline on a dark button rather than the destructive button style.

### 4.11 Seam
This file mixes the **queue controller** (join, leave, last-event attributes, stream request, driving handoff: about
15 lines) with the **banner view** (about 12 lines). The controller must be single-owner: two listeners on
`StartRaceQueueRequest` would send `JoinQueue` twice. Swap by module path with the controller lines carried over
unchanged into the new module and only the banner rebuilt from shared components. Do not add a second listener.

---

## 5. RaceTransitionClient

### 5.1 Purpose and lifecycle
Race transition and camera controller. Owns: the session-active flag, the staging readiness handshake with the server,
camera restore, hand-off to the shared loading screen, and a fallback black fade. Built at start. Permanent
connections: `RaceTransitionRequest.Event` (L355), `RaceEvent` (L385), `RaceQueueEvent` (L389),
`player.CharacterAdded` (L395).

### 5.2 Instance tree
```
PlayerGui.RaceTransitionFade_Phase8H  ScreenGui  DisplayOrder=210  IgnoreGuiInset=true  ResetOnSpawn=false (L40-46)
  Fade   Frame  black, full screen, transparency tweened 1 <-> 0, Visible toggled                          (L48-55)
    Label  TextLabel 360x44 centred, TextSize 17, text stroke                                              (L57-72)
```
3 instances. It does not destroy a previous copy.

### 5.3 Scaling
None. Full-screen frame by scale; the label is a fixed 360x44 px box with 17 px text at every resolution.

### 5.4 Config
None.

### 5.5 Dependencies and API
- Bindable in: `Runtime.Racing.RaceTransitionRequest` with `payload.Step` = SessionActive, FadeOut, FadeIn,
  BeginLoading, CompleteLoading, FailLoading, RestoreCamera, StopVehicle (ignored), StartTransition (L355-383).
  Callers: RaceSessionPresentationClient, RaceTimeTrialResultCoachClient, RaceEntryMenuClient, RaceBrowserClient.
  This bindable is the module's de facto public API.
- Bindable out: `RaceTransitionStateChanged {Active}` (L108-112). `script_grep` finds **no listener**.
- BindableFunction: `Runtime.UI.LoadingTransitionInvoke` actions Begin / Complete / Fail (L81-106), served by
  LoadingTransitionUI -> `ReplicatedFirst.Loading.LoadingTransitionRuntime`. The loading screen is the main
  transition; the black fade is used only when `Begin` returns nothing, for RESET, and as the hold under race results.
- Remotes: `RaceRequest` / `RaceQueueRequest` `AcknowledgeStagingReady {RunId, Phase="AssetsReady"|"CountdownVisible",
  Degraded, Detail}` (L223-239). Reads attribute `CountdownPresentationReady`, vehicle attributes `OwnerUserId`,
  `RaceRunId`, `RaceParticipant`. Calls `RequestStreamAroundAsync` and `ContentProvider:PreloadAsync`.
- Writes `Camera.CameraType = Custom` and `CameraSubject` (L186-200).

### 5.6 Input
None.

### 5.7 Per-frame / polling
No per-frame work. During staging only: two loops at 0.05 s for at most 7.5 s (L263-267, L282). Fade is a
TweenService tween (0.24 s out, 0.3 s in).

### 5.8 Mobile
No difference.

### 5.9 Hard-coded style
`Color3.fromRGB(0,0,0)` fade (L50), `Color3.fromRGB(230,255,246)` label (L64), `Enum.Font.GothamBold` then a literal
`Font.new("rbxasset://fonts/families/Michroma.json", Bold)` (L68-71), TextSize 17 (L65).

### 5.10 Defects
- Every race-mode payload is handled twice, because the handler is connected to both remotes (L385-391) and the
  server sends race payloads on both. Result: duplicate fades on `RaceReset`, duplicate `finishTransition` on
  `RaceStarted`, and three delayed camera restores each time, each printing a line (L193).
- Label is the one place the old typeface is a script literal that a token folder cannot reach; it does not scale.
- Dead code: `suppressFreeRoamHud()` is an empty function still called 8 times (L130); `savedHudEnabled`,
  `suppressGuiNames`, `lastHudPulse`, `RunService`, `racingFolder` are unused; `RaceTransitionStateChanged` has no
  listener; the plain `*Countdown` branch (L320-323) is never reached.

### 5.11 Seam
This is logic with two UI instances attached. **Do not fork it and do not start a second copy**: it owns the server
staging acknowledgement, the camera and the loading generation. It should run unchanged under both styles. The black
fade is style-neutral. The only style content is the label's font, colour and size; that is either accepted as-is
(it is seen briefly, mainly "RESETTING"), or handled as a declared small exception (read font/colour from the style
tokens when the new style is active, fall back to the current literals). The primary loading screen belongs to
another group's audit.

---

## 6. RaceRouteGuideClient

### 6.1 Purpose and lifecycle
In-world guidance during a run: a billboard pill over the next gate, optional corner ticks and chevron arrows built
from Neon parts, and a screen "WRONG WAY" prompt. Built at start. Permanent connections: `RaceEvent` (L418),
`RunService.Heartbeat` (L432, always on, including free roam), `PlayerScripts.Destroying` (L436).

### 6.2 Instance tree
```
PlayerGui.RaceRouteGuide_Phase5  ScreenGui  DisplayOrder=78  IgnoreGuiInset=true  ResetOnSpawn=false       (L271-276)
  WrongWayPrompt  TextLabel 280x38, AnchorPoint .5,0, Position (0.5,0, 0,178), UICorner 6, UIStroke        (L278-300)

Workspace.ClientOnly.RaceRouteGuide.ActiveGuide  Folder (destroyed and recreated when the next gate changes)
  NextGateLabel  BillboardGui (Adornee = gate part) > TextLabel + UICorner + UIStroke                      (L132-172)
  NextGateCorner_* x8 Parts            only if ShowCheckpointFrames and CheckpointFrameStyle ~= Off  (off) (L206-227)
  DynamicArrow_Left/Right/Stem Parts   only if ShowCheckpointArrows and ShowDynamicNextArrow         (off) (L242-255)
  AuthoredArrow_<n>_* Parts            only if ShowCheckpointArrows and ShowAuthoringArrows          (off) (L257-269)
```
With the live config only the billboard pill is drawn: 5 instances per gate change. `Workspace.ClientOnly` is shared
with onboarding, dealership and garage preview scripts.

### 6.3 Scaling
- WRONG WAY: no UIScale, fixed 280x38 px at y=178 px, 18 px text. Its position does not track the HUD: at 4K the
  in-race centre card (scaled x2) spans y 60 to 244 px and covers it, and the prompt is at DisplayOrder 78, underneath
  the HUD (155). On a 390 px tall phone it sits at 46% of the screen height.
- Billboard pill: `Size = fromOffset(CheckpointPillWidth*s, CheckpointPillHeight*s)`, text
  `max(8, CheckpointWorldTextSize*s)`, where `s` is 1 on desktop and `MobileCheckpointUIScale` (0.6) when
  `Foundation.IsMobile()` (L64-67, L136-156). Offset-sized billboards are constant in screen pixels: 125x24 px with
  12 px text at 1080p **and** at 4K; 75x14 px with 8 px text on phones. `AlwaysOnTop` from config.

### 6.4 Config
`Config.Racing.RouteGuide` **attributes** (not Values), read through `configFolder()` on every access (L31-62):
EnableRouteGuide, ShowWorldCheckpointLabel, CheckpointWorldTextAlwaysOnTop, CheckpointPillWidth/Height/YOffset,
CheckpointPillBackgroundTransparency, CheckpointPillCornerRadius, CheckpointPillStrokeThickness/Transparency,
CheckpointWorldTextStrokeTransparency, CheckpointWorldTextSize, MobileCheckpointUIScale, ShowCheckpointFrames,
CheckpointFrameStyle, CheckpointFrameTransparency, CheckpointCornerTickThickness/Length, ShowCheckpointArrows,
ShowDynamicNextArrow, DynamicArrowBackStuds/HeightStuds/Scale, ShowAuthoringArrows, ShowWrongWayPrompt,
WrongWayMinSpeed, WrongWayIgnoreNearGateStuds, WrongWayDotThreshold, WrongWayCheckInterval, WrongWayDelaySeconds,
and Color3 attributes **CheckpointColor** (70,255,190), **FinishColor** (255,226,80), **WarningColor** (255,74,116),
**ArrowColor** (255,68,196).
Attributes on the folder that this script does not read: CheckpointHud*, CheckpointLabel*, CheckpointWorldTextYOffset,
ShowCheckpointHudBadge, ArrowMarkersDormant, CheckpointGuideArrowsDisabled, ShowRouteArrowMarkers.
Route geometry through `RaceRouteDefinition` (`Workspace.World.RaceRoutes.<RouteId>`).

### 6.5 Dependencies
`RaceEvent`: `*Staged` -> clear; `*Started`, `*Checkpoint`, `*LapCompleted` -> `setActive(payload)` (uses RunId,
EventId, RouteId, DisplayName, NextGateIndex, GateCount, NextLap/CurrentLap, LapTarget); TimeTrialFinished / Ended /
Error, RaceFinished, RaceEnded -> clear. Reads `Workspace.World.Runtime.PlayerVehicles` children attribute
`OwnerUserId` (L302-316). No remotes invoked, no bindables, no public API.

### 6.6 Input
None.

### 6.7 Per-frame / polling / rebuild
- `Heartbeat` runs every frame for the whole session. Each frame `updateWrongWay` reads `WrongWayCheckInterval`
  through `configFolder()`, which is three `FindFirstChild`/`WaitForChild` chains plus a `GetAttribute`
  (L31-35, L349). The real check runs every 0.12 s and only does work while a run is active: it walks every player's
  vehicle to find the local one, then one velocity dot product (L326-346).
- Gate change: `clearGuide()` destroys the `ActiveGuide` folder, then the billboard (and any enabled parts) are
  recreated (L365-387). `RouteDefinition.GetRouteDefinition` is rebuilt from the workspace on every checkpoint event
  before the "same gate" early-out (L371-381); it is not cached.

### 6.8 Mobile
Pill and its text scaled by 0.6 (6.3). WRONG WAY identical to desktop.

### 6.9 Hard-coded style
10 `Color3.fromRGB`: pill background black (L147), text stroke (L154), four colour fallbacks repeated (L177, L179,
L185, L187, L189, L287, L414), prompt background 24,8,15 (L283). Font: `Enum.Font.GothamBold` + literal Michroma at
L158-161 (pill) and L290-293 (prompt). Sizes: 280x38, y=178, text 18, corner 6 (L281-295).
Colour-role conflicts with the sheet: the finish gate is yellow (sheet: yellow is Cash only) and checkpoints are mint
(sheet: live route values are Cyan).

### 6.10 Defects
1. Guide is not cleared on `RaceExitedToStart` or `RaceDNF` (L427 list). After quitting a multiplayer race the
   next-gate pill and wrong-way detection stay live until the race is cleaned up for everyone (by source).
2. WRONG WAY is fixed pixels in its own unscaled ScreenGui, under the HUD, and collides with the centre card at
   high resolution (6.3).
3. Pill does not scale with resolution; 8 px text on phones (6.3).
4. Config lookups every frame, forever, including in free roam (6.7).
5. Route definition rebuilt on every checkpoint (6.7).
6. Font and several colours are literals outside any token folder. `setCheckpointHud` is an empty stub and
   `checkpointHudLabel` is unused (L127-131).

### 6.11 Seam
Logic (run tracking, wrong-way test, which gate to mark) and view (pill, parts, prompt) are again in one closure.
The colours are already config attributes, but **both styles would share them**, so a new module should take its
colours from the new token folder and leave the `RouteGuide` colour attributes alone for the old style. Swap by module
path. In the new module the WRONG WAY prompt belongs inside the in-race HUD's canvas (same scale, same safe area),
which means the HUD view should own it and the route-guide module should only publish "wrong way on/off".
World Neon parts are style-neutral. Single-owner: `Workspace.ClientOnly.RaceRouteGuide` and the prompt.

---

## 7. RaceLifecyclePresentationClient

### 7.1 Purpose and lifecycle
No UI. Three jobs: (a) destroy legacy racing ScreenGuis by name, at start and on every `PlayerGui.ChildAdded`;
(b) own local visibility of start-zone `vfx_aura` content; (c) own `Enabled` on each start zone's
`ProximityPrompt` named `RaceEntryPrompt`. Built at start; full cleanup on `PlayerScripts.Destroying` (L282-297).
Sets `Runtime.Racing` attributes `AuraVisibilityOwnerReady` and `PromptVisibilityOwnerReady` (L300-301; no reader found).

### 7.2 to 7.4 Tree, scaling, config
No instances built. No config folder read. Reads zone attributes `Mode`, `Enabled` and the parent name `StartZones`.

### 7.5 Dependencies (and the name trap)
- **Legacy kill list (L23-35):** `RaceHud`, `RaceHud_Phase3`, `RaceCheckpointBadge_Phase5D`, `RaceQueue_Phase8`,
  `RaceSessionControls_Phase8C`, `RaceSessionControls_Phase8D`, `RaceResults_Phase4`, `TimeTrialResultCoach`,
  `RaceEntry`, `RaceEntryProbe`, `TimeTrialPersonalBestBoard`. **Any new ScreenGui given one of these names is
  destroyed the moment it is parented to PlayerGui.** `RaceHud` and `RaceEntry` are names a new build could easily pick.
- Blocking state for prompts and auras (`isBlocked`, L101-108): player attributes `StartScreenActive`,
  `RaceQueueActive`; `Runtime.UI.LoadingPresentationState` attribute `Active`; local flags from `RaceEvent`
  (`OpenRaceEntry`, the active kinds, the terminal kinds) and from bindable `Runtime.Racing.RaceEntryLegacyAction`
  (`"Close"`, `"StartSelectedVehicle"`).
- The prompt itself is created by the server (`TimeTrialServer` L1293-1314): KeyboardKeyCode E, GamepadKeyCode ButtonX,
  **`Style = Default`** (the stock Roblox prompt UI), ActionText from the zone, ObjectText "Race" / "Time Trial".

### 7.6 Input
None directly (it gates the ProximityPrompt).

### 7.7 Per-frame / polling
No per-frame work. One `Workspace:GetDescendants()` scan at start (L197-199) and a permanent
`Workspace.DescendantAdded` listener (L200-202) that runs a cheap test for every instance added anywhere in the
workspace (vehicles, VFX, route-guide parts). State changes re-apply all zones through `task.defer` with a generation
counter.

### 7.8 to 7.10
No mobile difference. No style literals. Defects for this audit: the kill list is an invisible naming constraint; the
workspace-wide `DescendantAdded` listener is broader than it needs to be.

### 7.11 Seam
Keep exactly one copy running under both styles; it is not part of the swap. The style sheet's "Start banner over the
start zone with the single interact key cap" and the event card must follow this owner's result (for example by
reacting to the prompt being shown or hidden for prompts named `RaceEntryPrompt`), not compute eligibility again.
A custom banner also needs the prompt's `Style` to be `Custom`, which is set by a server script today.

---

## 8. What the style sheet asks for versus what exists (in-race and results)

| Sheet item | Today | Data available without a server change? |
|---|---|---|
| Position top-left, largest element | Position is the top-centre card, same size as lap | Yes: `RacePositionUpdate.Place`, `ParticipantCount` |
| Lap beneath position | Top-left card | Yes |
| Timer top-centre, pink underline | Time trial only: client-arrival lap timer. **No race timer** | Yes: `StartServerTime` in both `*Started` payloads; lap times in `*LapCompleted` |
| Cyan delta chip | Does not exist | Partly: lap delta against `PersonalBest` at lap end, or against the session-best lap's splits kept on the client. Per-checkpoint delta against the saved personal best needs PB splits, which the server does not send |
| Checkpoint pips | Do not exist (HUD ignores NextGateIndex / GateCount) | Yes: both fields are in Started / Checkpoint / LapCompleted / Reset payloads |
| Live order, four rows around the player, player row white | First six rows, player row dark blue with teal name | Yes: `Positions[]` (no time gaps) |
| Minimap and gauge "as in free roam" | Square 420 px route image with a marker, desktop only; gauge is the free-roam HUD's (KeepTelemetry) | Map: existing HudMapCatalog projection. Gauge: owned by the free-roam HUD group |
| Exit confirmation | Hand-built copy, no cancel key or focus | Use the shared confirmation |
| Results: cash hero number (yellow) | "PRIZE $x" small teal text | Yes: `RewardAmount` (+ `RewardGranted`, `RewardMessage`) |
| Results: driver XP hero number (pink) | Not shown | **No field in either payload.** Only `XpIntoRank` / `Rank` attributes change afterwards |
| Results strip: finish, time, best lap | Place and time shown; best lap is `"--"` in races | Yes: `Place`, `Elapsed`, `BestLapSeconds` |
| Buttons centred: Race again, Continue (main) | EXIT TO START (left), RACE/TRY AGAIN (right, primary) | Same four server actions. Note the sheet makes "Continue" the main button; today "again" is the highlighted one |
| Medals, leaderboard, lap list, finishing order | All present today | The mockup does not show them; decide whether they stay (they are useful and the data is already there) |

---

## 9. Recommended switch design for this group

1. **Switch at the composition root, not inside each script.** ClientBase resolves each entry's path at L105-109.
   A style-keyed override map there (old path / new path per entry name) starts exactly one presentation per surface
   and leaves all seven old scripts byte-identical as the backup. It matches the sheet's rule that a style change
   takes effect at the next Play start; none of these modules can be stopped mid-session.
2. **The flag is not readable by clients today.** `FeatureFlags` lives in `ServerStorage.Modules.Core` and reads
   ConfigService or a `ServerStorage.Config` attribute. ClientBase needs a replicated projection of the style choice
   that is guaranteed to be present before it resolves entries (for example a value under `ReplicatedStorage.Config.UI.Style`
   written by the server before players load, with ClientBase defaulting to the old style if it is absent).
3. **Swap (new module per surface):** in-race HUD, results, countdown, queue banner, route guide.
   **Keep single and unchanged under both styles:** RaceTransitionClient, RaceLifecyclePresentationClient.
4. **One HUD canvas helper for the whole group.** Lift the safe-area canvas from RaceSessionPresentationClient L83-116
   into the shared foundation (with a touch-aware minimum scale) and use it for HUD, countdown, queue banner and the
   WRONG WAY prompt, so they share one scale, one safe area and one camera-rebind rule. Results and the other full
   menus need the same helper with a higher maximum than 1.15.
5. **State separated from view in the new modules**, so the next restyle does not need another copy of the logic:
   a race-session state module (payload reducer, timers from `StartServerTime`, map projection) with change signals,
   and views that only draw.
6. **Rows pooled, not rebuilt:** fixed row pools for the live order and results tables, text updated in place; timer
   text written only when the displayed value changes, with fixed-width digit cells.
7. Preserve when rewriting: `CountdownPresentationReady` attribute; `RaceSession` / `RaceQueue` / `RaceResults` owner
   keys and their `KeepTelemetry` values; the `LastRacingEventId` / `LastRacingVehicleId` attributes; the
   `RaceTransitionRequest` step names; the exact remote action names and payload keys in 1.5, 2.5, 4.5.

## 10. Not verified / open

- Rendered sizes on phones and at 1280x720, 3440x1440 are computed from the source; no Play session or device capture
  was allowed in this audit.
- The "HUD comes back after finish or exit" and "guide stays after exit" findings are from reading both sides of the
  protocol; they need a two-client Play test to confirm.
- `RaceSessionAssetsClient` (287 lines, same folder, reads `ArrowProxyPollSeconds`) and `RaceParticipantVisibilityClient`
  were not in this group's list and were not read.
- `ReplicatedFirst.Loading.LoadingTransitionRuntime` (the real loading screen behind race transitions) was not read.
- Whether `GetTimeTrialLeaderboard` can be slow enough to matter (defect 2.10.3) depends on the leaderboard service,
  which was not read.
- Whether the RaceEvent copy of `RaceStaged` omits `ParticipantCount` was read only up to MM L975.
