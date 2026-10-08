# UI restyle audit - group "followup-dev-studio-panels"

Read-only audit, 2026-10-09. Source of truth: live Studio, Space Racers v3 (placeId 93959280828322), Edit mode.
Nothing was changed in Studio or the repo. Play was not started, so every behavioural statement below is a
reading of the source, not a runtime observation.

Scripts read completely:

| Script | Lines | Builds UI? |
|---|---:|---|
| `ReplicatedStorage.Modules.Game.Development.DriveToEarnCashTelemetryClient` | 95 | 1 ScreenGui, 5 instances |
| `ReplicatedStorage.Modules.Game.Development.StudioCashGrantClient` | 59 | No. Roblox core notification only |
| `ReplicatedStorage.Modules.Game.Development.TrailerModeClient` | 89 | No. Toggles other people's UI |

All three paths exist as given. Supporting reads: `StarterPlayerScripts.ClientBase` (113 lines),
`ReplicatedStorage.Modules.Core.ClientLifecycle` (49), `ServerStorage.Modules.Game.Development.StudioCashGrantServer` (77),
`ServerStorage.Modules.Core.FeatureFlags` (61), and targeted line ranges of the UI owners that write `ScreenGui.Enabled`.

## Headline answers

1. **Excluded from the restyle: yes, but only implicitly.** The style sheet scope (line 5) lists player-facing
   screens only, and all three scripts hard-gate on `RunService:IsStudio()`, so no published player can see them.
   The sheet's "Explicit exclusions" (lines 42-43) does not name them. Recommend one added line so a literal sweep
   or a "replace every Michroma / fromRGB" pass does not touch `Game.Development.*`.
2. **Zero coupling to the UI system.** None of the three reads `Config.UI.*`, `UITheme`, `ResponsiveUIFoundation`,
   `RacingUIComponents` or `GarageComponents`. Adding `Config.UI.Style`, and later removing the old colour folders,
   cannot break them.
3. **Trailer mode will hide new ScreenGuis only under conditions, and it already fails for the main HUD.**
   It is name-agnostic (any `ScreenGui` directly under `PlayerGui` at the moment H is pressed), so new ScreenGuis
   are covered in principle. But it is a one-shot write of `Enabled=false`, and the free-roam HUD re-writes
   `gui.Enabled` every render frame. See "Trailer mode against the UI owners" below.
4. **Current live state:** `TrailerModeEnabled=false` and `StudioTelemetryEnabled=false`, so today neither the H key
   nor the telemetry panel exists in a Play session. The cash key is live in Studio (`CashGrant.Enabled=true`,
   key `Equals`, amount 1,000,000).

---

## 1. DriveToEarnCashTelemetryClient

### 1.1 Purpose and lifecycle
- Read-only Studio overlay showing drive-to-earn economy counters (comment lines 8-9).
- Started by `ClientBase` (entry at ClientBase lines 16-18, no dependencies, **no `tool` flag**), through
  `ClientLifecycle.start` (ClientLifecycle 28-45), which calls `Client.start()` once in its own thread.
- `start()` guard: lines 5-6, `state` goes nil -> "starting" -> "ready"/"failed" (91-92). A second call asserts.
- Gates: `RunService:IsStudio()` (line 14) then `Config.Vehicles.DriveRewards@StudioTelemetryEnabled == true`
  (line 18). Either failing returns before any instance is made; `state` still becomes "ready".
- The gate at line 18 is read **once**. Turning the attribute on mid-session builds nothing (needs a fresh Play).
  Turning it off mid-session hides the gui (58-60) but the loop keeps polling.
- No stop or cleanup API. The loop (82-88) ends only when `gui.Parent` becomes nil. `ResetOnSpawn=false`, so that
  is the whole session. A stale gui of the same name is destroyed at start (20-21).
- Connections kept: none. One `task.spawn` loop.

### 1.2 Instance tree (5 instances)
```
PlayerGui.DriveToEarnCashTelemetry   ScreenGui  DisplayOrder=2000  IgnoreGuiInset=false  ResetOnSpawn=false   (23-28)
  ReadOnlyPanel                      Frame      Anchor (1,0)  Pos (1,-12, 0,12)  Size 470x286 offset        (29-37)
    UICorner                         radius 8 px                                                           (38)
    UIStroke                         1 px, (0,220,255), transparency 0.15                                  (39)
    TelemetryText                    TextLabel  Pos offset (12,10)  Size (1,-24, 1,-20)                    (40-51)
```
ZIndexBehavior, ScreenInsets and ClipToDeviceSafeArea are left at defaults. The Frame is not `Active`.

DisplayOrder context (from source): DrivingSpeedEffect -10, CanonicalGarageGui 40, OwnedGarageInteriorHUD 58,
RaceRouteGuide_Phase5 78, ActivityHud 84, DesktopFreeRoamHud 85, MobileFreeRoamHud_Phase1 88, FullMap 90 (config),
MobileDriveControls_Phase1 96, SharedInRaceHUD 155, OwnedGarageBrowser 171, RaceQueueBanner 190, RaceCountdown 205,
RaceTransitionFade_Phase8H 210, UnifiedRaceResults 220, Onboarding 990, Loading 1000/1001, SharedTopNotification 1100,
SharedConfirmationOverlay 1250, **DriveToEarnCashTelemetry 2000**. It sits above everything, including
confirmations and the loading screen.

### 1.3 Scaling and layout
- No reference canvas, no UIScale, no aspect constraint. Pure pixel offsets anchored top-right with a 12 px margin.
- Size clamp recomputed every poll (line 65): width `max(280, min(470, viewport.X-24))`, height
  `max(240, min(286, viewport.Y-24))`.
- Text: `Enum.Font.Code`, `TextSize` 14, or 11 when `viewport.X < 600` (line 66). `TextWrapped=true`, left/top
  aligned. No `TextScaled`, no `TextTruncate`, no `ClipsDescendants`.
- Safe area: only what `IgnoreGuiInset=false` gives (top-bar inset). No explicit safe-area clamp.
- Viewport change: no `ViewportSize` signal. The 0.25 s poll re-reads `CurrentCamera.ViewportSize` (63-64), so a
  resize is picked up within a quarter second.

### 1.4 Config read
- `ReplicatedStorage.Config.Vehicles.DriveRewards@StudioTelemetryEnabled` (lines 17-18, 58). Live value: `false`.
  (docs/drive-to-earn-cash-system-v1.md line 181 lists the default as `true`; the live place has it off.)
- Nothing under `Config.UI`.

### 1.5 Dependencies and API
- Player attributes, written by `ServerStorage.Modules.Game.Vehicles.DriveRewardsServer` lines 270-281, only when
  Studio and `StudioTelemetryEnabled` (server line 253), every `TelemetryRefreshSeconds` (live 2 s, clamped 0.5-30):
  `DriveCashAcceptedStuds`, `DriveCashRejectedStudsByReason` (server caps at 900 chars), `DriveCashAccumulatedUngranted`,
  `DriveCashGranted`, `DriveCashCurrentHourly`, `DriveCashProjectedHourly`, `DriveCashCapUsage`, `DriveCashCapUsed`,
  `DriveCashLastReason`, `DriveCashVehicleIdentity` and `DriveCashSessionIdentity` (240 chars each).
- No remote, no bindable. This is the only client script that mentions `DriveCash*`.
- Public API: `Client.start()` only. Fires nothing, listens to nothing.
- Name references: `"DriveToEarnCashTelemetry"` appears only in this script (20, 24) and the ClientBase entry.

### 1.6 Input
None.

### 1.7 Per-frame, polling, rebuild
- 4 Hz loop (line 85). Each tick: 1 config `GetAttribute`, 11 player `GetAttribute`, a 12-part `table.concat`,
  and writes to `Enabled`, `Size`, `TextSize`, `Text` whether or not anything changed. Cost is negligible.
  The server only refreshes every 2 s, so 7 of 8 ticks write identical values.
- No rebuild: the 5 instances are created once.

### 1.8 Mobile and touch
- Only difference is the `viewport.X < 600` text breakpoint, which a phone in landscape never meets (typical
  widths 667-932). On an 812x375 emulated phone the panel is 470x286: about 58% of the width and 76% of the height.
- Not touch-interactive.

### 1.9 Hard-coded style (all of it; there is no config)
| Line | Value |
|---:|---|
| 32 | margin 12 px |
| 33, 65 | 470x286, minimum 280x240 |
| 34-35 | background `Color3.fromRGB(12,17,25)`, transparency 0.08 |
| 38 | corner 8 px |
| 39 | stroke `Color3.fromRGB(0,220,255)`, 1 px, transparency 0.15 |
| 42-43 | padding 12 / 10 px |
| 45 | `Enum.Font.Code` |
| 46, 66 | TextSize 14 / 11 |
| 47 | text `Color3.fromRGB(225,245,255)` |

Counts: 3 `Color3.fromRGB`, 1 `Enum.Font`, 2 `TextSize` sites. These 3 literals are part of the "about 230"
project total and should be excluded from the burn-down target.

### 1.10 Defects
- **Self re-enable (line 62).** `gui.Enabled=true` every 0.25 s. Anything else that hides it is overridden within a
  quarter second: trailer mode (TrailerModeClient 51), the race browser's blanket suppression (RaceBrowserClient
  407-408) and race entry's (RaceEntryPresentationClient 353-354). With telemetry on, the panel shows through
  trailer mode and over both race menus.
- **Overflow (33, 50, 65).** Height is capped at 286 px but the text wraps and three values can be long (900 and
  2 x 240 chars). Nothing clips or truncates, so text spills below the panel.
- **Covers the new top-right cluster.** At 12 px from the top-right corner and 470x286, it sits over the planned
  status cluster, action bar and (garage) stat panel. The Frame is not `Active`, so it should not swallow clicks
  (PreviewCameraClient line 32 only treats buttons, scrolling frames and Active objects as blocking).
- **Start gate read once (18)** while the run gate is polled forever (58): asymmetric, and leaves a loop running.
- Polls for data that changes every 2 s; attribute-changed signals would do. Trivial cost.

### 1.11 Restyle seam
- Excluded. Leave untouched. It is deliberately off-style (monospace, cyan stroke) so it reads as a debug tool.
- It is all view: there is no state to separate. If it were ever restyled it would be a 5-instance rewrite.
- Single-owner items: the ScreenGui name `DriveToEarnCashTelemetry`; DisplayOrder 2000. Recommend the new
  style's layer plan reserves 2000+ for development overlays and keeps all game UI at or below 1250.

---

## 2. StudioCashGrantClient

### 2.1 Purpose and lifecycle
- Studio-only hotkey that asks the server for test Cash and reports the result.
- Started by `ClientBase` (lines 18-20, no dependencies, no `tool` flag). Same `start()` guard (5-6, 55-56).
- Gate: `RunService:IsStudio()` (line 14) before any `WaitForChild` on the remote, so a live client never yields
  on it.
- Connections kept for the session, never disconnected: `remote.OnClientEvent` (45),
  `config:GetAttributeChangedSignal("Enabled")` (50) and `("KeyCode")` (51). No stop API. The action is unbound
  only by a re-bind (28).

### 2.2 Instance tree
None. The only visible output is `StarterGui:SetCore("SendNotification", {Title, Text, Duration=2.5})`
(lines 21-25, inside `pcall`). This is Roblox core UI: bottom-right corner, Roblox styling, not themable, not in
`PlayerGui`. It is the **only** `SetCore` call in the place.

### 2.3 Scaling and layout
Not applicable. Roblox owns the notification's size and position.

### 2.4 Config read
`ReplicatedStorage.Config.Development.CashGrant` (Folder) attributes:
| Attribute | Live | Read by |
|---|---|---|
| `Enabled` | true | client 29, 50; server 24 |
| `KeyCode` | "Equals" | client 30, 51 |
| `Amount` | 1000000 | client 42 (print only); server 38 |
| `StudioOnly` | true | server 24 |
| `AllowedUserName` | "LucidityStudios" | server 28 |
| `CooldownSeconds` | 0.5 | server 34 |

### 2.5 Dependencies and API
- Remote: `ReplicatedStorage.Remotes.Debug.StudioCashGrantRequest` (RemoteEvent, both directions). Client fires with
  no arguments (39). Server handler goes through `Net.event` (server line 21, capacity 10, refill 2), re-checks
  Studio (23), config (24), user name (28-32) and cooldown (33-36), then grants through
  `ServerStorage.Runtime.Garage.GarageProfileMutationBindings.GrantCash` with reason `StudioCashGrantHotkey`
  (48-56). Reply payload `{Success, Message, Cash}` (17-19).
- ContextActionService action name `"StudioCashGrant"` (19).
- Public API: `Client.start()` only.
- Side effect useful to the restyle: the grant moves `leaderstats.Cash`, so the HUD cash readout counts up. This
  is a ready-made way to exercise the new yellow Cash chip with seven-figure values.

### 2.6 Input
- Keyboard only: `ContextActionService:BindAction(ACTION, handler, false, keyCode)` (36-41). No touch button, no
  gamepad. Returns `Sink` on Begin, `Pass` if a TextBox is focused (38).
- No `GuiService` selection.

### 2.7 Per-frame, polling, rebuild
None. Event-driven.

### 2.8 Mobile and touch
No touch path (`createTouchButton=false`). On the Studio device emulator it still works from the keyboard.

### 2.9 Hard-coded style
No colours, fonts or sizes. Literals: notification `Duration = 2.5` (23), titles "TEST CASH ADDED" /
"TEST CASH FAILED" (47), fallback amount 100000 in the print (42).

### 2.10 Defects
- **`=` collides with the full map.** `FullMapUI` line 681 uses `Equals` for zoom in and line 674 ignores
  processed input. Because this script sinks `Equals`, in Studio the `=` zoom does not work while the map is open
  and each press also grants 1,000,000 Cash. E and keypad plus still zoom. Relevant when testing the restyled map.
- Message text is built server-side with `tostring(amount)` ("+$1000000 test cash", server 63), not the shared
  compact money formatter. Acceptable for a Studio tool; note it so nobody "fixes" it into the restyle.
- The core notification appears bottom-right for 2.5 s, over the planned speed gauge / button row. Do not press
  `=` just before a verification capture.

### 2.11 Restyle seam
- Excluded. No view to restyle. Keep the core notification: moving it onto `SharedTopNotification` would restyle a
  dev tool and couple it to the UI foundation for no player benefit.
- Single-owner items: the `SetCore("SendNotification")` call (new game UI should keep using
  `ResponsiveUIFoundation`'s `SharedTopNotification`, never core notifications); the action name
  `StudioCashGrant`; the `Equals` key in Studio.

---

## 3. TrailerModeClient

### 3.1 Purpose and lifecycle
- Studio filming tool: press H to hide Roblox core UI and every ScreenGui; press H again to restore (11-14).
- Registered in `ClientBase` lines 98-100 with `tool="TrailerModeEnabled"`. `ClientLifecycle.start` line 29 marks
  it `skipped` and never requires the module unless `ClientLifecycle.tool_enabled(IsStudio, Config.Development.ClientTools,
  "TrailerModeEnabled")` is true (ClientLifecycle 17-19). The module repeats the same check itself (6-8).
- Live: `Config.Development.ClientTools@TrailerModeEnabled = false` (also `TrailerShotEnabled`,
  `TrailerVehicleCameraEnabled`, `LightingPreviewEnabled`, all false). Change in Edit, then start a fresh Play.
- When the flag is off the function returns at line 8 with `state` still nil (the "starting" assignment is on
  line 9). Harmless.
- Connection kept for the session: `UserInputService.InputBegan` (74-82). No stop API, no disconnect.
- Startup status is observable at `StarterPlayerScripts.ClientBase.StartupState@TrailerModeClient` (ClientBase 104-111).

### 3.2 Instance tree
None of its own.

### 3.3 What it does (the whole mechanism)
- **Core UI** (28-42, 68): `StarterGui:SetCoreGuiEnabled` for Backpack, Chat, PlayerList, Health, EmotesMenu, each
  in a `pcall`. On restore it sets all five to `true` unconditionally. This is the **only** `SetCoreGuiEnabled`
  caller in the place.
- **PlayerGui** (44-63): on hide, a single pass over `playerGui:GetChildren()`; for each direct child that
  `IsA("ScreenGui")` it records `child.Enabled` in `savedGuiStates` and sets `Enabled=false`. On restore it writes
  each saved value back if the gui still has a parent, then clears the table.
- No `ChildAdded` hook, no polling, no attribute or bindable published. Nothing else in the place can tell that
  trailer mode is active.

### 3.4 Config read
`ReplicatedStorage.Config.Development.ClientTools@TrailerModeEnabled` (lines 6-8). Note line 6 indexes
`.ClientTools` directly after `WaitForChild("Development")`.

### 3.5 Dependencies and API
- Public API: `Client.start()` only. No remote, bindable or attribute.
- Name references: `TrailerMode*` appears only here and in ClientBase.

### 3.6 Input
- `UserInputService.InputBegan`, key `Enum.KeyCode.H` (23, 79), ignored when `gameProcessed` (75).
- No other script or config value uses H. Other development tools use P, B (TrailerShot), C, V, B
  (TrailerVehicleCamera), 1-8, M, N, R, `[`, `]` (LightingPreview). `FullMapUI` already uses M and C, which collide
  with those tools when they are enabled together.

### 3.7 Per-frame, polling, rebuild
None. Two one-shot passes per toggle (about 20 ScreenGuis and 5 pcalls).

### 3.8 Mobile and touch
Keyboard only. The sweep also disables Roblox's `TouchGui` and `MobileDriveControls_Phase1`, so touch driving is
not possible while trailer mode is on. `TouchGui.Enabled` is also written by `VehicleVFXClient` 1061 and
`ThrustPreviewClient` 30.

### 3.9 Hard-coded style
None. Hard-coded key H (23) and the five CoreGuiTypes (28-34).

### 3.10 Trailer mode against the UI owners (the important part)

Writers of `ScreenGui.Enabled` found in client source:

| Owner | Lines | Pattern |
|---|---|---|
| `DesktopFreeRoamHudUI` | 1114, 1116, 1117, 1128; bound at 1368 | **Every render step** (`BindToRenderStep("PCFreeRoamHudPhase4A", 3000)`): sets `true` then `enabled` |
| `MobileFreeRoamHudUI` | 398; loop at 391 | **Every RenderStepped**: `gui.Enabled = not hidden` |
| `DriveToEarnCashTelemetryClient` | 59, 62 | Every 0.25 s |
| `DrivingCameraClient` (speed lines) | 371, 409, 413, 623 | On threshold crossing while driving |
| `RaceBrowserClient` | 407-410 | Blanket save/disable of every other ScreenGui + `ChildAdded`; restore on close |
| `RaceEntryPresentationClient` | 353-357 | Same blanket pattern |
| `RaceTransitionClient` | 119-124 | Restores saved HUD states when a session ends |
| `RaceTimeTrialResultCoachClient` | 99 | One named legacy gui, touch only |
| `RaceSessionPresentationClient` | 123 | Named legacy guis, touch only |
| `FullMapUI` | 501, 504, 525 | On open/close |
| `ActivityClient` | 75-77 | On `FullMapOpen` change |
| `OnboardingClient` | 730, 734 | On loading/full-map gate change |
| `GarageComponents` | 301 | When the garage gui is ensured |
| `DealershipIntroClient` | 624 | On objective end |

Consequences, from source:

1. **The free-roam HUD is not hidden by trailer mode on either platform.** Trailer mode writes `false` once
   (line 51); the desktop HUD writes `true` on the next render step (1117) and the mobile HUD on the next
   RenderStepped (398). So the claim "trailer mode disables every ScreenGui" is true only for an instant for the
   two most visible ScreenGuis. This is a pre-existing gap, not something the restyle introduces, but a new HUD
   view that copies the per-frame `Enabled` write will inherit it.
2. **Late ScreenGuis are missed.** These are created lazily, after start-up: RaceBrowser gui (RaceBrowserClient
   459), race entry gui (RaceEntryPresentationClient 827), `UnifiedRaceResults` (RaceTimeTrialResultCoachClient 202),
   dealership intro (DealershipIntroClient 173), `DrivingSpeedEffect` (DrivingCameraClient 366),
   `SharedConfirmationOverlay` (ResponsiveUIFoundation 328), `SharedTopNotification` (449), `CanonicalGarageGui`
   (GarageComponents 300). Any of them created while trailer mode is on stays visible.
3. **Three independent save/restore owners of the same property.** TrailerMode (44-63), RaceBrowserClient
   (407-410) and RaceEntryPresentationClient (353-357) each snapshot `Enabled` and write it back later. Interleaved
   order goes wrong: trailer on (saves true, sets false) -> race browser opens (saves false) -> trailer off
   (restores true, so HUDs appear under the open browser) -> browser closes (restores false). Event-driven guis
   (ActivityHud, RaceQueueBanner, MobileDriveControls) then stay hidden until their owner next writes.
4. **Restore can be stale.** If an owner changes state while hidden (for example M opens the full map, FullMapUI
   525 sets `Enabled=true`), trailer-off writes back the old `false` while `FullMapOpen` is still true, so the
   map is invisible and the HUD stays suppressed by it.
5. **Only `ScreenGui` directly under `PlayerGui` (line 49).** Not covered: BillboardGuis (RaceRouteGuideClient 137
   checkpoint pills; 18 static in Workspace), SurfaceGuis (226 static), ProximityPrompts (2 static plus scripted),
   Highlights, the core notification, and anything under a Folder in PlayerGui. Also not covered: a `BlurEffect`.
6. **Core UI is otherwise never managed.** Since this disabled Studio tool is the only `SetCoreGuiEnabled` caller,
   in normal play PlayerList, Chat, Backpack, Health and Emotes are at Roblox defaults, and `leaderstats.Cash`
   exists (EconomyServer 41-54), so the Roblox leaderboard has a Cash column. The mockup capture
   `assets/ui/mockups/pulse_restyle/01-free-roam.jpg` shows no leaderboard or top bar. Whether the leaderboard
   overlaps the planned top-right status cluster needs a Play check on desktop.

### 3.11 What the new presentation must do so trailer mode keeps working (leaving this script untouched)
- Parent every new ScreenGui **directly** under `PlayerGui`. No holder Folder, no CoreGui.
- Create new ScreenGuis at start-up and show/hide content through a root container's `Visible` (or a
  CanvasGroup), not by creating the ScreenGui on first open.
- Never write `ScreenGui.Enabled` per frame. Write it only on a state transition, or better, leave
  `ScreenGui.Enabled` to the cross-cutting suppressors (trailer mode, race browser, race entry) and drive the
  view's own visibility from its root container.
- If old and new ScreenGuis coexist with one set disabled by the style switch, trailer mode's save/restore handles
  that correctly (it saves `false` and restores `false`).
- Planned elements that trailer mode cannot hide if built as world or post-process objects: the **Start banner
  over the start zone** (sheet line 220) if it is a BillboardGui, and the **optional whole-screen blur**
  (sheet line 170) if it is a `BlurEffect`. Build the banner as a ScreenGui element projected from world position,
  or accept that trailer mode leaves it.

### 3.12 Optional follow-up (not part of the restyle; needs its own approval)
The HUD owners already accept arbitrary presentation owners through the existing bindable
`PlayerScripts.Runtime.UI.FreeRoamHudPresentationMode` with payload `{Owner, Active, KeepTelemetry}`
(DesktopFreeRoamHudUI 1340-1346, MobileFreeRoamHudUI 393-398, OnboardingClient 726-727). If trailer mode fired
`{Owner="TrailerMode", Active=true}` on hide and `Active=false` on restore, the per-frame HUD writers would hide
themselves (desktop line 1114) through an existing contract, with no new owner. That would close gap 1 above.
It edits a development tool, not the old UI, so it does not affect the backup.

---

## 4. Cross-cutting notes for the integrator

- **Style switch source.** The sheet says the switch is "one Core.FeatureFlags flag" (line 265). `FeatureFlags`
  is server-only: `ServerStorage.Modules.Core.FeatureFlags` (Studio override `ServerStorage.Config@Flag_<Key>`,
  then ConfigService, then default; lines 37-54). Clients cannot require it. The switch needs a replicated
  projection that exists before `ClientBase` builds the first screen. The development tools show the working
  precedent: a replicated config attribute read at start, changed in Edit, effective on the next Play
  (`Config.Development.ClientTools`, ClientLifecycle 17-19).
- **`Config.UI.Style` does not exist yet.** `Config.UI` children today: Theme, PaintPresets, DriveInCustomisation,
  RaceBrowser, DesktopFreeRoamHud, Racing, MobileFreeRoamHud, GarageExperience, GarageReplacement, LoadingSystem,
  FreeRoamMapPlayerMarkers, RouteGuide, MapIcons, MapIconLayer, FullMap, MapPois, MapTiles.
- **Generic sweeps over PlayerGui** that will also see any new ScreenGui: RaceBrowserClient 407-408 and
  RaceEntryPresentationClient 353-354 (disable everything else), DesktopFreeRoamHudUI 377-389 (every 0.1 s, treats
  any enabled ScreenGui containing a visible descendant named `GarageRoot`, `DealershipRoot`, `CustomisationRoot` or
  `CustomizationRoot` as "major menu open"), RaceLifecyclePresentationClient 54-61 (destroys ScreenGuis whose name is
  in its legacy list). New ScreenGui and root names must be chosen with these in mind.
- **Literal sweep guard.** Any scripted replacement of colour or font literals must skip `Game.Development.*`.
- **Studio test hooks worth using during the restyle:** `=` for Cash chip count-up with large numbers; the
  `StartupState` attributes on `ClientBase` to confirm no owner failed with the switch on.

## 5. Not verified
- Nothing was run in Play. The trailer-mode findings are from source order of writes, not observation.
- Whether the Roblox leaderboard is visible in normal desktop play, and whether it overlaps the planned top-right
  cluster.
- Whether the non-Active telemetry Frame really lets clicks through to buttons beneath it.
- `TrailerShotClient`, `TrailerVehicleCameraClient` and `LightingPreviewClient` were only scanned for UI and keys
  (they build no UI); they were not read in full because they are outside this group.
