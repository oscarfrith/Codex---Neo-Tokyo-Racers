# UI restyle audit: foundation-startup group

Read-only audit, 2026-10-08. Source of truth: live Studio, Space Racers v3 (placeId 93959280828322), Edit mode.
Nothing was changed in Studio or the repo. Nothing was Play-tested: every runtime statement below is read from
source, and sizes on phone/ultrawide are computed, not observed.

Scripts read completely:

| Script | Lines | Kind |
|---|---:|---|
| ReplicatedStorage.Modules.Game.UI.ResponsiveUIFoundation | 562 | ModuleScript, stateless library |
| ReplicatedStorage.Modules.Game.UI.UITheme | 97 | ModuleScript, legacy theme reader |
| StarterPlayer.StarterPlayerScripts.ClientBase | 113 | LocalScript, client composition root |
| ReplicatedStorage.Modules.Core.PathResolver | 82 | ModuleScript, path helper |
| ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient | 329 | LocalScript, first loading + start screen |
| ReplicatedFirst.Loading.LoadingScreenView | 314 | ModuleScript, loading view |

Also read because the focus list needed them: Core.ClientLifecycle (49), ServerStorage.Modules.Core.FeatureFlags (61),
ServerStorage.Modules.Core.Net (167), ServerStorage.Modules.Core.ServerLifecycle (45), ServerScriptService.ServerBase (157),
ReplicatedFirst.Loading.LoadingTransitionRuntime (177), ReplicatedFirst.Loading.LoadingArtworkCatalog (109),
UI.SharedTopNotificationUI (27), UI.LoadingTransitionUI (28), UI.RacingUIComponents (194, whole file),
Core.ConfigReader (103), Core.ConnectionScope (44), and DrivingCameraClient lines 22-68, 330-470, 728-775.

All listed paths exist. Two names in the style sheet do not exist in Studio:
- `Core.FeatureFlags` is at **ServerStorage**.Modules.Core.FeatureFlags, not under ReplicatedStorage. Same for Core.Net.
- There is no module named `GarageReplacementComponents`. The shared vehicle card lives in UI.GarageComponents;
  `Config.UI.GarageReplacement` is a config folder only.
- `Config.UI.Style` does not exist yet.

---

## 0. Headline findings

1. **A client cannot read a feature flag.** FeatureFlags is server-only and nothing replicates flags. The style
   switch needs a small server-to-client projection (section 7). This is new connected state, not just a flag read.
2. **ClientBase is the one place a UI module set can be chosen**, at its resolve callback (lines 105-109). Skipping
   entries does not work, because dependants of a skipped entry go to `blocked`. Alternatives must keep the entry
   name and swap the path (section 3.11).
3. **The loading and start screens are outside ClientBase.** They run from ReplicatedFirst and need their own gate.
4. **This group alone has four unrelated scaling mechanisms** (uniform 1920x1080 canvas, fixed pixel presets by
   device class, four breakpoint presets, scale with pixel clamps). None share a scale source.
5. **The shared confirmation is very small on a phone**: computed about 234 x 97 px with 19 px-high buttons at 844x390.
6. `Config.UI.Theme` is shared by the old look and holds behaviour attributes. Do not edit it to get the new look.

---

## 1. ResponsiveUIFoundation

### 1.1 Purpose and lifecycle
Stateless helper library. No `start`. Required (directly) by 8 scripts: DesktopFreeRoamHudUI:26, MobileFreeRoamHudUI:19,
SharedTopNotificationUI:13, RacingUIComponents:7, UITheme:4, RaceRouteGuideClient:17, RaceSessionPresentationClient:177,
ActivityClient:24. First require in a session is from ReplicatedFirst time:
InitialLoadingAndStartScreenClient:22 -> RacingUIComponents:7 -> Foundation.

Line 10 does `WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Theme")` at module load. If the Theme folder is
ever removed, every requirer yields forever.

Two functions create long-lived things: `Confirmation` (one overlay per call, cleaned on close) and
`CreateTopNotificationController` (one controller for the session, never destroyed).

### 1.2 Full public API

| Function | Lines | What it does | Style or logic |
|---|---|---|---|
| `IsMobile()` | 19-21 | `UserInputService.TouchEnabled`. Not cached | logic |
| `CornerScale()` | 23-25 | Theme `CornerScaleMobile` (.5) or `CornerScaleDesktop` (.7) | style |
| `CornerRadius(base)` | 27-29 | `max(0, base * CornerScale())` | style |
| `SetCorner(corner, base)` | 31-36 | Writes attribute `BaseCornerRadius`, sets `UDim.new(0, radius)` | style |
| `Corner(parent, base)` | 38-43 | New UICorner through SetCorner | style |
| `StrokeWidth(role)` | 45-53 | Glow 3/2, Emphasis or Selected 1.5/1.25, Structural 1.2/1 (desktop/mobile) | style |
| `StyleStroke(stroke, role)` | 55-60 | Sets Thickness, writes attribute `StrokeRole` | style |
| `ApplyBevel(parent, options)` | 62-97 | Child Frame `GradientOverlay` + UICorner + UIGradient `NeutralOverlay`. Options: Strength (clamp 0-.35, default Theme `BevelStrength` .1), Radius (6), Rotation (Theme `BevelRotation` 90), ZIndex | style |
| `FormatNumber(v)` | 99-106 | Rounds, groups thousands, keeps sign | logic |
| `FormatCompactMoney(v)` | 108-113 | `$1,234` under 1,000,000; `$1.2M` above (floored to tenths). No K or B step | logic |
| `FormatFullMoney(v)` | 123-125 | `$` + grouped, floored, min 0 | logic |
| `FormatFreeRoamMoney(v)` | 127-132 | Full when Theme attribute `FreeRoamCashUseFullFormatting` is true (it is), else compact | logic |
| `CreateCashDisplayPresenter(render, options)` | 134-208 | Count-up animation. Returns `{SetTarget(value, forceSnap), Snap(value), GetDisplayed(), GetAuthoritative(), Destroy()}`. Options: Enabled, DurationSeconds, EveryDollarLimit, MaximumSteps | logic |
| `StyleMetric(label, kind)` | 210-220 | Attributes `SharedMetric`, `MetricKind`; no wrap, no truncate; **hard-codes Michroma Bold** (217) | style |
| `ProjectEconomy(response, fallback)` | 222-251 | Reads Cash / Used / Capacity out of several server reply shapes | logic |
| `BindReplicatedCash(player, callback)` | 253-288 | Follows `leaderstats.Cash`; returns a disconnect function | logic |
| `ConfirmationLayout()` | 297-313 | Table of 13 layout numbers at 1920x1080 | style |
| `Confirmation(root, options, components)` | 315-441 | Modal overlay. Returns `{Root, Cancel(), Confirm(), Relayout()}` | mixed, see 1.5 |
| `CreateTopNotificationController(playerGui)` | 444-558 | Toast stack. Returns `{Gui, Show(message, duration), Relayout(), Count()}` | mixed, see 1.6 |

Dead code: `rootLogicalSize` (290-295) is never called. `kit` (9) and several service locals are unused.

### 1.3 Who calls what (counted over all 219 scripts)

Direct calls on the Foundation table:

| Function | Callers (count) |
|---|---|
| IsMobile | RaceRouteGuideClient 1 (plus internal) |
| CornerRadius | DealershipIntroClient 1 (through UITheme) |
| SetCorner | RacingUIComponents (alias), RaceSessionPresentationClient 1, GarageComponents 1 (through alias) |
| Corner | DesktopFreeRoamHudUI:202, MobileFreeRoamHudUI:48, RacingUIComponents:56, RaceRouteGuideClient 2, RaceSessionPresentationClient 2 |
| StrokeWidth | 22 call sites: DesktopFreeRoamHudUI 4, MobileFreeRoamHudUI 2, RacingUIComponents 3, GarageComponents 5, GarageWorkspaceUI 2, GarageBrowserUI 2, OwnedGarageBrowserUI 1, RaceRouteGuideClient 1, DealershipIntroClient 1 |
| StyleStroke | DesktopFreeRoamHudUI 2 (843, 909), MobileFreeRoamHudUI 3 |
| ApplyBevel | DesktopFreeRoamHudUI:229, MobileFreeRoamHudUI 4 (59, 131, ...), RacingUIComponents:130 (every `Components.Button`) |
| FormatCompactMoney | As `Components.FormatMoney`: GarageUI 4, GarageComponents 3, GarageWorkspaceUI 2, GarageBrowserUI 1, ActivityClient 1 |
| FormatFreeRoamMoney | DesktopFreeRoamHudUI:339, MobileFreeRoamHudUI:337 |
| FormatNumber, FormatFullMoney, CornerScale | internal only |
| CreateCashDisplayPresenter | DesktopFreeRoamHudUI:1302, MobileFreeRoamHudUI:335 |
| StyleMetric | DesktopFreeRoamHudUI:905, MobileFreeRoamHudUI:334, RacingUIComponents:187 (`MetricLabel`, used by GarageComponents 1) |
| ProjectEconomy | As `Components.ProjectEconomy`: GarageComponents 2, GarageUI 1, OwnedGarageWorkspaceUI 1 |
| BindReplicatedCash | MobileFreeRoamHudUI:342, GarageWorkspaceUI 1, GarageBrowserUI 1 |
| ConfirmationLayout | RaceSessionPresentationClient:177 (builds its own "EXIT RACE?" modal from the numbers, 178-182; it does not call Confirmation) |
| Confirmation | DesktopFreeRoamHudUI:509 and MobileFreeRoamHudUI:234 (both pass `SharedUI` = RacingUIComponents), RacingUIComponents:190 `ConfirmationModal` (called by GarageComponents 2, OwnedGarageWorkspaceUI 1) |
| CreateTopNotificationController | SharedTopNotificationUI:17 only |

Fan-in of the component libraries that sit on top of Foundation:
- RacingUIComponents is required by 19 scripts (all garage, HUD, racing, map, onboarding, activity owners and the start screen).
- GarageComponents is required by 9.
- RacingMobileScaledDesktopLayout is required by 4.

RacingUIComponents caches Foundation functions at load (176-182), and so does UITheme (89-94). Replacing a function on
the Foundation table after load would not reach them.

### 1.4 Config read
All from `ReplicatedStorage.Config.UI.Theme`, by NumberValue child first, then attribute (12-17), or BoolValue then
attribute (116-121):

| Key | Present in Studio | Fallback |
|---|---|---|
| CornerScaleDesktop / CornerScaleMobile | NumberValue .7 / .5 | .7 / .5 |
| GlowStrokeDesktop/Mobile, EmphasisStrokeDesktop/Mobile, StructuralStrokeDesktop/Mobile | absent | 3/2, 1.5/1.25, 1.2/1 |
| BevelStrength, BevelRotation | absent | .1, 90 |
| TopNotificationMaxCards | absent | 3 |
| CashCountAnimationEnabled | attribute true | true |
| CashCountDurationSeconds | attribute 0.4 | 0.4 (clamp .15-.75) |
| CashCountEveryDollarLimit | attribute 12 | 12 (clamp 1-24) |
| CashCountLargeIncreaseMaximumSteps | attribute 20 | 20 (clamp 4-60) |
| FreeRoamCashUseFullFormatting | attribute true | true |

So the Theme folder is not only the legacy colour set. It also carries the cash-count behaviour. It cannot be
deleted when the old style is retired unless those five attributes move first.

### 1.5 Confirmation in detail (315-441)

Instance tree (about 22 instances with RacingUIComponents as `components`):
```
PlayerGui.SharedConfirmationOverlay   ScreenGui  DisplayOrder 1250, IgnoreGuiInset true, ResetOnSpawn false,
                                                 ZIndexBehavior Global, ScreenInsets None, ClipToDeviceSafeArea false
  Backdrop          Frame, Active, black, transparency .34, full screen, ZIndex 300
  ReferenceCanvas   Frame 1920x1080, centred, UIScale child
    SharedConfirmation   Frame, full size
      Panel         components.Panel (650 x 270)  StrokeColor ElectricBlue, NoGlow
        title Label  (20,8) size (1,-40, 0,54)  TextSize 22, Heading, centred
        body Label   (20,88) size (1,-40, 0,44) TextSize 15, wrapped, centred
        NO Button    (30,182) 270x54  TextSize 13  PanelDeep / Outline
        YES Button   (350,182) 270x54 TextSize 13  PanelBlue / Telemetry
```
Scaling (396-420): safe rect = `GuiService:GetInsetArea(DeviceSafeInsets)` relative to `GetInsetArea(None)`;
`scale = max(.01, min(safeW/1920, safeH/1080))`; canvas is centred on the safe rect and resized to `safe/scale`.
Recomputed on camera ViewportSize change and on CurrentCamera change. There is no minimum scale and no phone branch.

Computed results (not observed):

| Viewport | Scale | Panel | Button | Title / body / button text |
|---|---:|---|---|---|
| 1920x1080 | 1.00 | 650 x 270 | 270 x 54 | 22 / 15 / 13 px |
| 1280x720 | 0.67 | 433 x 180 | 180 x 36 | 14.7 / 10 / 8.7 px |
| 3440x1440 | 1.33 | 867 x 360 | 360 x 72 | 29 / 20 / 17 px |
| 844x390 phone | 0.36 | 235 x 97 | 97 x 19 | 7.9 / 5.4 / 4.7 px |

Behaviour (the part worth preserving):
- Saves `GuiService.SelectedObject` (322) and restores it on close if focus was on NO or YES (390).
- Binds a uniquely named ContextActionService action at priority 10000 for Escape and ButtonB; Begin closes as
  cancel and the input is sunk (423-426). Unbound on close (382).
- NO is on the left, YES on the right; `NextSelectionRight/Left` wired (376-379).
- If the last input was keyboard or gamepad, NO gets selection after a defer (435-439). Touch and mouse get none.
- `close` is once-only (387-388), destroys the gui, then calls `OnConfirm` or `OnCancel`.
- The backdrop is `Active` so clicks do not pass through. Clicking the backdrop does not cancel.
- Options: `Title`, `Body`, `ConfirmText`, `CancelText`, `OnConfirm`, `OnCancel`.

The `components` contract it needs: `Panel(parent, {Name, StrokeColor, NoGlow})`, `Label(parent, {Text, Position,
Size, TextSize, Role, XAlignment, Wrapped})`, `Button(parent, {Text, Position, Size, TextSize, Color, StrokeColor,
ZIndex})`, `Colour(name)` answering `ElectricBlue`, `PanelDeep`, `Outline`, `PanelBlue`, `Telemetry`.

The `root` argument is only used to find PlayerGui (319-321).

### 1.6 Top notifications in detail (444-558)

Instance tree:
```
PlayerGui.SharedTopNotification   ScreenGui  DisplayOrder 1100, IgnoreGuiInset true, ResetOnSpawn false
  Stack   Frame, anchor (.5,0), AutomaticSize Y, UIListLayout (padding 6, centred, LayoutOrder)
    Message<N>   Frame grey (72,76,84) transparency .04, UICorner (6 scaled), UIGradient GreyGradient
      Text       TextLabel white, Michroma Bold, centred
```
4 instances per card, at most `TopNotificationMaxCards` (3) cards.

Sizing (470-487, 488-508): no UIScale. Two fixed presets chosen by `IsMobile()`:

| | Desktop | Mobile |
|---|---|---|
| Side margin | 24 | 12 |
| Max width | min(viewport - 48, 820) | min(viewport - 24, 280) |
| Min width | 170 | 120 |
| Padding h / v | 34 / 18 | 22 / 14 |
| Text | 15 px | 12 px |
| Min height | 38 | 30 |

Position: `y = max(12, GuiService:GetGuiInset().Y + 10)`, centred on viewport X (493). Card width comes from
`TextService:GetTextSize` (480, 484). Relayout runs on show and on viewport change.

Behaviour: text is upper-cased (522); oldest card is removed when the cap is hit (525); each card is removed by
`task.delay(clamp(duration or 2.5, .5, 10))` (554). No enter or exit animation, no de-duplication, no severity
colour, no icon.

Public path: nobody calls the controller directly. `SharedTopNotificationUI` (a ClientBase entry) creates the
controller and connects `PlayerScripts.Runtime.UI.ShowTopNotification.Event` to `controller.Show(message, duration)`.
Nine scripts fire that bindable: OwnedGarageBrowserUI, DesktopFreeRoamHudUI, MobileFreeRoamHudUI, FullMapUI, GarageUI,
GarageEntranceClient, RaceBrowserClient, ActivityClient (and SharedTopNotificationUI owns it). No other script
touches the `SharedTopNotification` ScreenGui by name.

### 1.7 Cash presenter (134-208)
Count-up only when the target rises; a drop snaps (157). An increase of 12 or less steps by one; larger increases
take at most 20 steps over 0.4 s. One `task.spawn` loop per increase, cancelled by a generation token. At most 20
render callbacks per change. Authoritative cash stays `leaderstats.Cash` (comment 114-115). This is pure logic and
any new view can reuse it unchanged.

### 1.8 Input
Only inside Confirmation: GuiService selection save/restore, ContextActionService sink for Escape and ButtonB,
`UserInputService:GetLastInputType()`. Nothing else in the module reads input.

### 1.9 Per-frame and rebuild
No per-frame work. Confirmation is built on open and destroyed on close. Notification cards are created and
destroyed per message. `number()` does a `FindFirstChild` and possibly a `GetAttribute` on every call, so each
Corner, StrokeWidth and Bevel call costs one or two lookups (uncached). Small, but it multiplies in screens that
rebuild many cards.

Instance cost of the current look, per element (RacingUIComponents.Button, 113-154): TextButton + UICorner + bevel
Frame + bevel UICorner + bevel UIGradient + UIStroke `Stroke` + UIStroke `GlowStroke` = 7 instances and 2
connections. A Panel with stroke and glow = 4.

### 1.10 Mobile differences
`IsMobile()` switches corner scale (.5 vs .7), stroke widths, and the toast preset. Nothing else. The confirmation
has no mobile branch.

### 1.11 Hard-coded style
- Colours: 4 `Color3.fromRGB` (90 bevel grey, 529 card grey, 538 gradient x2) and 4 `Color3.new` (73, 90, 340, 546).
- Font: Michroma at 217 and 550 (FontFace, Bold), 480 and 484 (`Enum.Font.Michroma`, used for measuring).
- Sizes: the 13 numbers in ConfirmationLayout (298-312); canvas 1920x1080 (299, 352); toast presets (472-477, 485,
  492-493); list padding 6 (463); card corner 6 (535); bevel radius 6 (81); backdrop transparency .34 (341).

### 1.12 Defects
1. **Confirmation shrinks without a floor** (416-419). On a phone the buttons compute to about 19 px high and the
   text to under 6 px. At 1280x720 the button text is 8.7 px. The style sheet requires 48 px targets and 11 px text.
2. **Opening a second confirmation orphans the first** (326-327). The old overlay is destroyed without calling its
   `close`, so its ContextActionService binding and camera connections stay, and its `OnCancel` fires later on an
   unrelated Escape or B press.
3. **Toast width is measured with the wrong font** (480, 484 measure Michroma Regular through the legacy
   `GetTextSize`; 550 renders Michroma Bold). Bold is wider, so text can clip or wrap unexpectedly.
4. **Toasts do not scale.** 15 px text at every desktop resolution: large against a 720p HUD, small at 3440x1440.
5. **`IsMobile()` is touch-only** (19-21), but DesktopFreeRoamHudUI gates on "touch and no keyboard or mouse"
   (16-19) and MobileFreeRoamHudUI on "touch" (13). On a touch device with a keyboard or mouse, both HUD gates pass
   and desktop UI gets mobile corner, stroke and toast metrics. Source reading only; needs a Play check.
6. **Pixel strokes and corners sit inside scaled canvases.** A 1.2 px stroke under a 0.67 UIScale is 0.8 px, and
   about 0.4 px on a phone. Lines become uneven or vanish. The new 2 px hairlines will hit the same problem unless
   they are pixel-snapped (see 9.3).
7. **Bevel overlay is a child Frame over the button** (65-79). It draws above the button's own text (a faint white
   wash) and would be picked up by any UIListLayout placed on the button.
8. **`StyleMetric` hard-codes Michroma Bold** (217), ignoring the configured FontFamily values.
9. **Camera handlers stack** (429-432, 511-514): each CurrentCamera change adds another ViewportSize connection.
   The confirmation clears them on close; the notification controller never does.
10. `BindReplicatedCash` adds a nested ChildAdded connection each time `leaderstats` is re-added (273-278).
11. Body text box is 44 px high at 15 px text, about two lines; longer bodies truncate.

### 1.13 Seam
- **Reuse unchanged from a new kit:** IsMobile (or better, a corrected device test), FormatNumber,
  FormatCompactMoney, FormatFullMoney, FormatFreeRoamMoney, CreateCashDisplayPresenter, ProjectEconomy,
  BindReplicatedCash. These carry no look. Requiring Foundation from the new kit keeps one money formatter.
- **Needs a new-style equivalent:** Corner, StrokeWidth, StyleStroke, ApplyBevel, StyleMetric, ConfirmationLayout,
  Confirmation, CreateTopNotificationController.
- **Confirmation can be reused as-is** by passing a new components table that implements Panel, Label, Button and
  Colour. That keeps focus and cancel behaviour for free, but inherits defect 1, the fixed layout table, the black
  backdrop and the five Racing colour names. A new `Confirmation` with the same options, the same return table,
  the same overlay name (`SharedConfirmationOverlay`, so the replace-by-name at 326 still works across both kits)
  and DisplayOrder 1250 is the cleaner route. Copy the behaviour list in 1.5 exactly.
- **Single owner:** one overlay named `SharedConfirmationOverlay`; one ScreenGui named `SharedTopNotification`;
  exactly one listener on `ShowTopNotification`.
- **Do not change `Config.UI.Theme` values for the new look.** Setting `CornerScaleDesktop` to 0 would square every
  corner in the old UI too, and the backup would no longer look like the backup.

---

## 2. UITheme

### 2.1 Purpose and lifecycle
Legacy theme reader. Stateless. `UITheme.Read()` (60-88) returns a snapshot table from `Config.UI.Theme`:
13 colours (Panel, PanelSoft, Card, Selected, Text, Muted, Accent, Cash, Danger, Back, Exit, Buy, Disabled),
9 numbers (PanelTransparency, ButtonTransparency, PanelStrokeTransparency, ButtonStrokeTransparency, StrokeWidth,
PanelCornerRadius, ButtonCornerRadius, CornerScaleDesktop, CornerScaleMobile) and FontFamily. It also re-exports
six Foundation functions (89-94).

**Only one consumer:** DealershipIntroClient (35-49 wraps the require in its own fallback; uses theme.Panel,
PanelTransparency, PanelCornerRadius, Accent, StrokeWidth, PanelStrokeTransparency, FontFamily, Text at 186-212).
`PathResolver.UITheme()` returns the same folder and has no UI caller.

### 2.2 to 2.8
Builds no instances, has no scaling, no remotes, no input, no per-frame work, no mobile branch.
Config: `Config.UI.Theme` children only. Aliases accepted: `CardHot` for Selected, `BackButton`, `ExitButton`.

### 2.9 Hard-coded style
13 `Color3.fromRGB` defaults (7-19) and Michroma (29). The defaults are a green palette that no longer matches the
live folder (live `Selected` is 118,36,98; `Accent` 255,172,234; `Text` 255,218,246). Live `Danger` is
74,176,99 (green) and live `Cash` is 139,255,119 (green), which look like leftovers.

### 2.10 Defects
- Defaults disagree with live values, so a missing value silently gives an off-palette green.
- Read is a one-off snapshot with no change signal (the folder's `HowToUse` attribute says "Stop and Play again").

### 2.11 Seam
Leave untouched. The new style should not read it. It stays for DealershipIntroClient's old look.

---

## 3. ClientBase (and Core.ClientLifecycle)

### 3.1 Purpose and lifecycle
The only LocalScript in StarterPlayerScripts (the only other client LocalScript in the place is
ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient). It is the explicit client composition root: a static
list of 46 entries (5-103), a `StartupState` folder parented to the script (104), and one call to
`ClientLifecycle.start(entries, resolve, emit, enabled)` (105-112). No discovery, no gameplay state, no stop or
cleanup, no hot reload.

### 3.2 How modules are found and started
Entry shape: `{name, path, dependencies = {names}, tool = optional flag name}`.

`ClientLifecycle.start` (ClientLifecycle 20-47):
1. `validate` asserts unique names, that every dependency names an entry, and no cycles (3-16).
2. Every entry is set to `pending`.
3. Every entry gets its own `task.spawn`, in list order (28).
4. If `entry.tool` is set and `enabled(entry.tool)` is false, the entry is `skipped` (29).
5. It waits for each dependency, polling every 0.05 s for up to 30 s. A dependency that is not `ready`
   (failed, blocked or skipped) makes this entry `blocked` (31-37).
6. `starting`, then `resolve(entry)` and `feature.start()` inside `xpcall`; result `ready` or `failed` (38-44).

`resolve` (ClientBase 105-109) walks `entry.path` from `game` with `WaitForChild` and `require`s the module.
`emit` (109-112) mirrors every status to an attribute on `ClientBase.StartupState` and warns with the message.
`enabled` is `lifecycle.tool_enabled(IsStudio, Config.Development.ClientTools, flag)`: Studio only, attribute true.
All four ClientTools attributes are false now.

There is no ordering other than list order plus dependencies. Entries with no dependencies start in the same
frame, in list order, each yielding independently.

Every feature module follows the same shape: `Client.start()` with a once-only `state` guard and one large
`xpcall` closure (for example SharedTopNotificationUI 4-25, DesktopFreeRoamHudUI 5-8). State and view construction
live in that one closure.

### 3.3 The 46 entries

UI owners (build player-facing ScreenGuis or drive them): ActivityClient, DealershipIntroClient,
GarageEntranceClient, RaceBrowserClient, RaceCountdownPresentationClient, RaceEntryMenuClient,
RaceEntryPresentationClient, RaceQueueClient, RaceRouteGuideClient, RaceSessionPresentationClient,
RaceTimeTrialResultCoachClient, RaceTransitionClient, MobileDriveControlsClient, DesktopFreeRoamHudUI,
FreeRoamVehicleExitButtonClient, LoadingTransitionUI, MobileFreeRoamHudUI, FullMapUI, OnboardingClient,
OwnedGarageClient, SharedTopNotificationUI, GarageUI, DriveToEarnCashTelemetryClient (dev overlay).

Not UI: LightingClient, DriveSessionClient, the four audio runtimes, StudioCashGrantClient,
GaragePreviewPresentationClient, ThrustPreviewClient, RaceLifecyclePresentationClient,
RaceParticipantVisibilityClient, RaceSessionAssetsClient, CharacterSprintClient, FreeRoamParkedHoverClient,
RuntimeVFXClient, LODClient, NightLamppostLightClient, OwnedGarageEnvironmentLightingClient, WindowMaterialClient.

Tool-gated (Studio only): TrailerVehicleCameraClient, LightingPreviewClient, TrailerModeClient, TrailerShotClient.

Dependencies that involve UI owners:
- ActivityClient -> SharedTopNotificationUI
- DealershipIntroClient -> GarageUI
- GarageEntranceClient -> LoadingTransitionUI, GarageUI
- RaceEntryPresentationClient -> LoadingTransitionUI
- OwnedGarageClient -> LoadingTransitionUI
- GarageUI -> DriveSessionClient, LoadingTransitionUI, SharedTopNotificationUI

Desktop and mobile HUD are both always started; each returns early from `start()` on the wrong device
(DesktopFreeRoamHudUI:16-19, MobileFreeRoamHudUI:13). That is the existing precedent for "two alternative UI
modules, one active": both are required, one self-disables. It is weaker than choosing before `require`.

### 3.4 to 3.9
Builds no UI. Reads `Config.Development.ClientTools` (4). Publishes `ClientBase.StartupState` attributes
(one per entry: pending, starting, ready, failed, blocked, skipped). ServerBase has the same folder on the server.
No remotes, input, per-frame work, mobile branch or style literals.

### 3.10 Defects
- No timeout on `resolve`: a wrong path yields forever in `WaitForChild` and the entry stays `starting` with only
  Roblox's infinite-yield warning.
- The 30 s dependency deadline is shared across all of an entry's dependencies, not per dependency.
- A `skipped` dependency blocks its dependants (see 3.11).

### 3.11 Where a UI module set can be selected

**The seam is the resolve callback, ClientBase 105-109.** It is the only code that turns an entry into a module.

Recommended shape: keep each entry's `name` and `dependencies`, add an optional second path for the new style, and
let the resolver pick by a style value that is read once and latched before `lifecycle.start` runs.

```lua
-- illustration only, not installed
{name="GarageUI", path="ReplicatedStorage.Modules.Game.Garage.GarageUI",
 pulsePath="ReplicatedStorage.Modules.Game.UIPulse.GarageUI", dependencies={...}}
...
local path = (activeStyle == "Pulse" and entry.pulsePath) or entry.path
```

Why this and not the alternatives:
- **Same name, different path** leaves the dependency graph, the `StartupState` attribute names and every
  `blocked`/`ready` rule exactly as they are. Only one of the two modules is ever `require`d, so the other never
  runs a line, creates no ScreenGui, binds no bindable and calls no remote.
- **Separate entries gated by `tool`** does not work: `tool_enabled` is Studio-only, and a skipped entry blocks
  everything that depends on it (ClientLifecycle 36). GarageUI skipped would block DealershipIntroClient and
  GarageEntranceClient.
- **Both started, one self-disables** (the HUD precedent) means editing every old owner to add a guard, which is
  the opposite of an untouched backup.

ClientBase itself must change for this (one optional field per swapped entry and about three lines in the
resolver). ClientLifecycle does not change. A missing or failing `pulsePath` should fall back to `path` and warn
once, which matches the style sheet's failure rule.

What must stay single-owner whichever set runs: `LoadingTransitionInvoke.OnInvoke` (LoadingTransitionUI:13),
the one listener on `ShowTopNotification`, DriveSessionClient's vehicle callbacks, and each remote's client caller
(Net rate limits are per player per remote, section 8).

---

## 4. PathResolver

Static path helper, 15 functions, all `WaitForChild` chains. UI-related: `UITheme()` (53-55) and `PaintPresets()`
(57-59). **Only PreviewVehicleClient requires it** (3 references). Every UI script inlines its own
`WaitForChild("Config"):WaitForChild("UI")...` chain instead (for example DesktopFreeRoamHudUI 29-36).

No UI, scaling, remotes, input, per-frame work or style literals. `VehicleCategories()` (32-35) branches on
`RunService:IsServer()`.

Seam: none needed. It is not a shared UI config path today, so adding a `UIStyle()` helper here would not make
anyone use it. A new style reader should be its own small module (section 9.1). Leave PathResolver untouched.

---

## 5. Loading and start screens

Four pieces, all in ReplicatedFirst.Loading:

| Piece | Role |
|---|---|
| LoadingTransitionRuntime (ModuleScript, 177) | Logic: singleton controller, generations, input gate, audio duck, state publishing |
| LoadingScreenView (ModuleScript, 314) | View: the two ScreenGuis, artwork, progress bar |
| LoadingArtworkCatalog (ModuleScript, 109) | Data: artwork list and weighted shuffle bag |
| InitialLoadingAndStartScreenClient (LocalScript, 329) | First load progress and the Play / Shop start screen |

### 5.1 Lifecycle
1. InitialLoadingAndStartScreenClient auto-runs from ReplicatedFirst. It waits for PlayerGui, PlayerScripts,
   `Config.UI.LoadingSystem` (8-13) and `PlayerScripts.Runtime.UI` (20), then requires LoadingTransitionRuntime
   and RacingUIComponents (21-22).
2. If `LoadingSystem.StartScreenEnabled == false` it removes Roblox's default loading screen and returns (15-18).
3. `Runtime.Start({UIFolder})` (23) creates the singleton and the view (LoadingTransitionRuntime 33-47).
4. It calls `Begin` with `Destination = "StartScreen"` (37-39). To do that it temporarily edits shared config on
   the client: sets `TimeoutSeconds` to 86400 and disables every artwork that is not `StartScreenEligible`, then
   restores both (26-46).
5. Sets player attribute `StartScreenActive = true`, removes the default loading screen (52-53).
6. Polls every 0.05 s until `game:IsLoaded()`, `Workspace.World` exists and the character has a root part, or
   `StartScreenLoadTimeoutSeconds` (default 20) passes (59-75).
7. Finds `PlayerGui.LoadingSafeContent.SafeRoot` and its `Status` and `ProgressTrack` (78-88), clones
   `ProgressFill` to animate completion (94-108), hides status and track (110-111).
8. Builds the Play / Shop menu into `SafeRoot` (113-272).
9. Play -> `release(true, "Play")`. Shop -> `Remotes.UI.FreeRoamHudTeleportInvoke:InvokeServer("TeleportToDealership")`,
   then fires `Runtime.UI.FreeRoamVehicleExited`, then release (306-326).
10. `release` (293-304) disconnects layout connections, clears `StartScreenActive`, calls `Complete` or `Fail`,
    destroys the menu.

Later, the ClientBase entry `LoadingTransitionUI` calls `Runtime.Start` again, gets the same singleton
(LoadingTransitionRuntime 34), sets `LoadingTransitionInvoke.OnInvoke` and marks
`LoadingPresentationState.ControllerReady = true`. Six scripts call that BindableFunction for transitions:
OwnedGarageBrowserUI, DesktopFreeRoamHudUI, MobileFreeRoamHudUI, GarageUI, GarageEntranceClient, RaceTransitionClient.

The view is never destroyed; `Hide` only disables the two ScreenGuis (LoadingScreenView 299-305).

### 5.2 Instance tree
```
PlayerGui.LoadingBackground   ScreenGui  DisplayOrder = LoadingSystem.DisplayOrder (1000), IgnoreGuiInset true,
                                         ResetOnSpawn false, ZIndexBehavior Sibling, ScreenInsets None, Enabled false
  BlackBacking      Frame, Active, black, opaque
    ArtworkClip     Frame, ClipsDescendants
      ArtworkMotion Frame, centred, scale 1.08 (tweened 1.06 -> 1.10 with a small pan)
        SingleArtwork  ImageLabel, Crop, anchor = focal point
        GridArtwork    Frame, hidden until promoted, 6 x Tile ImageLabel (3 x 2, 1 px overlap)
    InputBlocker    TextButton, Modal true, full screen

PlayerGui.LoadingSafeContent  ScreenGui  DisplayOrder 1001, IgnoreGuiInset true, ResetOnSpawn false,
                                         ScreenInsets CoreUISafeInsets, Enabled false
  SafeRoot          Frame, full size
    Status          TextLabel, anchor (.5,1), position (.5,.79), size (.72, 0, 0, 34), UISizeConstraint 220-820 x 34
    ProgressTrack   Frame, anchor (.5,0), position (.5,.81), size (.58, 0, 0, 22), UISizeConstraint 220-720 x 22, UICorner 9
      ProgressFill  Frame, UICorner 8, UIGradient ElectricBlue -> Telemetry
    StartScreenActions   (added by the start screen) Frame 560x52 at (.5,.82)
      Buttons       Frame + UIListLayout (horizontal, padding 16)
        Play, Shop  RacingUIComponents.Button 270x52, each with Content (Frame + UIListLayout + Icon + Label)
```
About 19 instances for the view, about 25 more for the start menu.

### 5.3 Scaling and layout
- **Artwork:** cover-fit. `_UpdateCompositeCover` (70-81) resizes the grid to cover the viewport from the entry's
  AspectRatio, on `ArtworkClip.AbsoluteSize` change (64-66). Works at any aspect.
- **Status and progress:** width by scale (72% and 58%) with pixel clamps; height and text in fixed pixels
  (34 px box, 15 px text, 22 px track). Vertical position by scale (.79 and .81). No UIScale.
- **Start buttons:** four fixed presets chosen in `updateLayout` (238-272):

| Case | Test | Menu | Button | Icon | Text |
|---|---|---|---|---:|---:|
| Phone portrait | touch and short side <= 700 and taller than wide | 190 x 90, vertical | 190 x 40 | 17 | 12 |
| Phone landscape | touch and short side <= 700 | 388 x 40, horizontal | 188 x 40 | 17 | 12 |
| Narrow or portrait | width < 800 or taller than wide | 240 x 108, vertical | 240 x 48 | 20 | 13 |
| Desktop | otherwise | 560 x 52, horizontal | 270 x 52 | 22 | 14 |

  Vertical position from attributes `StartScreenButtonYScaleDesktop` (.82), `...LandscapePhone` (.84),
  `...Portrait` (.80), clamped to .5-.95 and so the menu stays 8 px inside `SafeRoot` (231-236).
  Re-run on camera ViewportSize, on `SafeRoot.AbsoluteSize`, and when any of the three attributes change (273-280).
- **Safe area:** content ScreenGui uses `ScreenInsets = CoreUISafeInsets`, so `SafeRoot` is already inside the
  notch and top bar. The background uses `ScreenInsets = None` to bleed to the edges. This is the cleanest
  safe-area handling in the group.

### 5.4 Config read
`Config.UI.LoadingSystem` attributes (36 exist): StartScreenEnabled (absent, so enabled), TimeoutSeconds,
StartScreenLoadTimeoutSeconds (absent, 20), MinimumVisibleSeconds 1.2, CompletionFillSeconds .2, ReadyHoldSeconds .06,
FadeOutSeconds .3, DisplayOrder 1000, WarmPoolSize 1, MotionEnabled, MotionStartScale 1.06, MotionEndScale 1.1,
MotionTravelPercent .012, MotionDurationSeconds 7, GridOverlapPixels 1, GridPreloadAttempts 2,
GridPreloadRetrySeconds .25, GridPromotionWaitSeconds 3, StartScreenPlayText / ShopText (absent: PLAY, SHOP),
StartScreenPlayIconAssetId, StartScreenShopIconAssetId, the three button Y scales, plus audio values used by
AudioMixClient.
`Config.UI.LoadingSystem.Artworks.<name>` attributes: ArtworkId, ImageAssetId, Weight, FocalPointX/Y, MotionPreset,
Layout, Columns, Rows, AspectRatio, Destinations, Enabled, StartScreenEligible; child `Tiles.R<r>C<c>` with
ImageAssetId. One artwork exists: NeoTokyoStreet01 (Grid3x2, start-screen eligible).
`Config.UI.DesktopFreeRoamHud.Colours` (LoadingTransitionRuntime:40): Text, PanelSoft, Telemetry, ElectricBlue.
Through RacingUIComponents: `Config.UI.Racing.Colours` PanelBlue, PanelSoft, Telemetry, ElectricBlue, Text, Outline;
`Racing.Typography.FontFamily`; `Racing.Layout.CornerRadius`.

### 5.5 Dependencies and public API
- Runtime API: `api:Handle(action, payload)` with actions Begin, Progress, Complete, Fail, Cancel, GetState
  (LoadingTransitionRuntime 156-170). Exposed to other scripts as BindableFunction `Runtime.UI.LoadingTransitionInvoke`.
- View API used by the runtime: `Create`, `Warm`, `SetArtwork`, `Show`, `SetStatus`, `SetProgress`,
  `SetProgressImmediate`, `StartMotion`, `FadeOut`, `Hide`. The runtime uses methods only, never view fields.
- Publishes: `Runtime.UI.LoadingPresentationState` attributes Active, Generation, Destination, FadeStarted, Reason
  (read by VehicleAudioClient, OnboardingClient, RaceLifecyclePresentationClient); fires
  `LoadingPresentationChanged` (OnboardingClient) and `FreeRoamHudPresentationMode` with
  `{Owner="LoadingTransition", Active, KeepTelemetry=false}` (12 scripts listen or fire).
- Uses `GameplayInputGate.Acquire/Release` and `AudioMixClient.Start/Begin/MarkReady/Finish`.
- Player attribute `StartScreenActive`, read by OnboardingClient:330, 739 and RaceLifecyclePresentationClient:102, 262.
  DriveRewardsServer:135 also reads it, but it is set by a LocalScript, and client-set attributes do not replicate
  to the server, so that server check looks dead (outside UI scope; noted only).
- Remote: `Remotes.UI.FreeRoamHudTeleportInvoke` action `TeleportToDealership` (315-316).
- **Instance names another script depends on:** InitialLoadingAndStartScreenClient reaches into the view by name:
  `LoadingSafeContent`, `SafeRoot`, `Status`, `ProgressTrack`, `ProgressFill` (78-103), and parents its menu into
  `SafeRoot`. Nothing else references `LoadingBackground`, `LoadingSafeContent` or `StartScreenActions`.

### 5.6 Input
`InputBlocker` (Modal TextButton) swallows clicks and frees the mouse. `GameplayInputGate` locks driving input.
Start buttons respond to `Activated` only. There is **no GuiService selection, no default focus and no key bind**:
a gamepad or keyboard player has no direct way to press Play. Hover feedback is `MouseEnter`/`MouseLeave` inside
RacingUIComponents.Button (137-152), so touch and gamepad get no focus state.

### 5.7 Per-frame and polling
- LoadingTransitionRuntime runs a `RenderStepped` loop for the life of each transition and sets `Fill.Size` every
  frame (101-119). On the start screen the transition stays open until Play is pressed, so that loop keeps writing
  to a hidden bar for the whole time the player sits on the start screen.
- First-load polling every 0.05 s (64-71), each tick calling `Progress`.
- Grid promotion waits on `RenderStepped` until six tiles are loaded or 3 s pass (LoadingScreenView 186-188).
- Tweens: progress (255), motion (278, infinite reversing while visible), fade (287-296, 5 tweens plus 6 tiles).
- Nothing is rebuilt per transition; the view is reused. `Warm` creates and destroys temporary ImageLabels (207-226).

### 5.8 Mobile
Start screen presets above. Loading view has no mobile branch. The portrait presets exist although the game is
landscape-only (LandscapeSensor); they still apply to a narrow desktop window.

### 5.9 Hard-coded style
- LoadingScreenView: `Enum.Font.Michroma` (43); 5 `Color3.fromRGB` fallbacks (43, 46, 49, 51 x2) and black (33);
  text 15, box 34, track 22, corners 9 and 8 (43-50) set with raw `UICorner`, bypassing Foundation.
- InitialLoadingAndStartScreenClient: no colour literals (all through `UI.Colour`), font through
  `UI.Font(label, "Button")`; about 40 size literals (118-119, 129, 136, 142, 150, 172, 181, 192, 203, 206, 244-270).
- Status strings: "LOADING NEO TOKYO" (38), "LOADING WORLD", "PREPARING CITY", "FINALISING", "READY",
  "ENTERING", "TRAVELLING", "SHOP - TRY AGAIN".

### 5.10 Defects
1. **No scaling on status, bar or buttons.** 270 x 52 buttons and 15 px status text are the same pixels at
   1280x720 and at 3440x1440.
2. **Phone-landscape buttons are 40 px high** (255), under the 48 px target.
3. **No gamepad or keyboard route to Play** (5.6).
4. **Stale title:** "LOADING NEO TOKYO" (38). The game is Pulse Racers.
5. **Shop uses a blocking `InvokeServer` with no timeout** (316); the buttons stay inert until it returns.
6. **Client edits shared config to pass parameters** (26-46). If `Begin` errored between the edit and the restore
   the values would stay changed for the session (it is wrapped in `pcall`, so the restore does run; fragile, not broken).
7. Progress loop runs every frame while the start screen is idle (5.7).
8. Status sits at .79 and the bar at .81 of the safe height with fixed pixel heights, so on a very short viewport
   the 34 px status box and the bar can touch; on a tall one they drift apart. Buttons at .82 reuse the bar's place.
9. Raw `UICorner` radii (48, 50) ignore the shared corner scale.

### 5.11 Seam
The logic/view split is already clean: LoadingTransitionRuntime is logic, LoadingScreenView is view. But the
choice of view is hard-wired (`require` at LoadingTransitionRuntime:8, colours folder at :40), and the start menu
is built inline in the LocalScript.

A new-style loading screen therefore needs:
- a second view module with the same method list (5.5) **and the same instance names** `LoadingSafeContent`,
  `SafeRoot`, `Status`, `ProgressTrack`, `ProgressFill`, or a forked start-screen script that does not reach in;
- a two-line change in LoadingTransitionRuntime to choose the view (or a forked runtime, which is worse: it owns
  the singleton, the input gate token and the audio duck, and must stay single);
- a gate for the auto-running LocalScript. It already has an early-return pattern at 15-18. Either add one style
  guard there, or add a second LocalScript that returns unless the style is the new one. Exactly one may run,
  because both would call `Begin` and both would set `StartScreenActive`.

Must stay single-owner: the `Runtime.Start` singleton, `LoadingTransitionInvoke.OnInvoke`,
`LoadingPresentationState`, the `GameplayInputGate` token, `StartScreenActive`.

The style value has to be readable here, before ClientBase runs. See section 7.3 for timing.

The style sheet excludes the start screen logo art. The artwork pipeline (catalog, grid, motion) does not need to
change; only Status, ProgressTrack and the two buttons carry the old look.

---

## 6. DrivingSpeedEffect (DrivingCameraClient, speed-line part only)

- **Owner:** the driving camera controller. Built in `Controller.Start` when the scripted chase camera is on (747),
  destroyed in `Controller.Stop` (766). So it is rebuilt on every drive start.
- **Tree (361-401):** `PlayerGui.DrivingSpeedEffect` ScreenGui, DisplayOrder -10, IgnoreGuiInset true,
  ResetOnSpawn false, Enabled false until needed -> `Lines` CanvasGroup (full screen, GroupTransparency 1,
  not Active, not Interactable) -> N x `Line` Frame (white, centred anchor) each with one UIGradient.
  N = `ChaseSpeedLineCount` (default 64, clamp 0-120), halved on touch-only devices (381).
  So 130 instances on desktop, 66 on a phone.
- **Config:** `Config.Vehicles.Camera` attributes ChaseSpeedLinesEnabled, ChaseSpeedLineCount,
  ChaseSpeedLineStartMph (110), ChaseSpeedLineFullMph (230), ChaseSpeedLineOpacity (.7); refreshed every
  `ConfigRefreshSeconds` (.25) (41-49).
- **Per frame (402-430, called from the render step at 612):** computes an amount from speed and boost; disables
  the ScreenGui below .02; writes `GroupTransparency` only when it moves by more than .01; every 0.04 s re-places
  6 lines (Rotation, Size, Position each).
- **Layout:** lines are placed in pixels from `viewport.Magnitude` (352-360). A viewport change is absorbed as
  lines are re-placed, about 0.43 s for 64 lines.
- **Style literals:** white (390), thickness 2 to 4.5 px (358), gradient keypoints (393).
- **Performance note:** a full-screen CanvasGroup has to redraw its texture whenever a child changes. With 6 lines
  moved every 0.04 s that is about 25 redraws a second while the lines are visible. Not measured.
- **Restyle:** this is a driving effect, and the style sheet excludes driving changes. Leave it alone. It sits at
  DisplayOrder -10, under every HUD, so a new HUD at any positive order stays above it. If the new style wants a
  tinted version, that is a separate driving change.

---

## 7. FeatureFlags and the style switch

### 7.1 What FeatureFlags is
`ServerStorage.Modules.Core.FeatureFlags`, strict Luau, 61 lines. It is the only match for "FeatureFlags" in the
tree. There is no ReplicatedStorage copy.

API:
- `FeatureFlags.Get(key, default)` (37-54)
- `FeatureFlags.IsEnabled(key, default)` (56-58): `Get(...) == true`

Resolution order (comment 2-6):
1. Studio only: attribute `Flag_<Key>` on `ServerStorage.Config`. Live now: `Flag_EnableDuelStakes`,
   `Flag_VehicleClass_exotic`, `Flag_VehicleClass_muscle`, all true.
2. Creator Dashboard configs: `ConfigService:GetConfigAsync()` snapshot, refreshed every 60 s on a background
   thread, memoised per key per snapshot (19-35, 44-52).
3. The caller's default.

Reads never yield. The first call starts the refresh loop (26-35), so **the first read on a new server returns the
default** until the first snapshot arrives. There is no "ready" signal; `snapshot` is private.

Callers today, all server: OwnedGarageManagement, GarageServer (category gate, 424-428), AnalyticsServer,
RaceIntegrity, ProgressionService, CourierJob, PassengerService, TaxiJob, DuelService.

### 7.2 Can a client read a flag at start-up?
**No.** ServerStorage does not replicate, the Studio override attributes are on ServerStorage.Config, and
ConfigService is read on the server. Nothing publishes flags to clients. Clients only see the effect of a flag
through server replies (for example the garage catalogue omits a category).

So the style sheet's line "reads ... Core.FeatureFlags for the style switch" cannot be done from a UI owner as
written. A projection is needed.

### 7.3 A projection that fits the existing rules
Server (one small owner, started from ServerBase):
- reads `FeatureFlags.Get("<style key>", default)`;
- writes the result to one replicated place, for example an attribute on `ReplicatedStorage.Config.UI`;
- re-reads on a timer so later joiners follow a dashboard change.

Client:
- one tiny module reads that attribute **once** and latches it for the session;
- ClientBase's resolver and the ReplicatedFirst loading code both ask that module.

Latching once per session is what guarantees only one UI set is ever active, and it matches the style sheet
("switching style takes effect on the next Play start").

Timing:
- Attributes arrive with their instance. The loading script already waits for `Config.UI.LoadingSystem` (13), so
  `Config.UI` and its attributes are present by then, with no extra wait.
- In Studio the server starts before the client and the `Flag_<Key>` override is immediate, so on/off testing is
  reliable: set the attribute on ServerStorage.Config in Edit mode, then Play.
- On a new production server the first joiner can arrive before the ConfigService snapshot. That player would get
  the default style. Options: accept it (they get the old, known-good UI); or have the server also write a
  "resolved" marker after its first refresh attempt and have the client wait a short bounded time for it while
  Roblox's own loading screen is still up (InitialLoading does not remove it until line 53).

Precedent: the server already sets many replicated player attributes (ProfileServer 13 sites, GarageServer 9,
OwnedGarageManagement 15). A per-player override attribute (for example to let only Oscar see the new style in the
live game) would follow the same pattern and is worth considering.

This adds one server writer and one replicated value. It is presentation-only, but it is a new connected state, so
it should be named in the delivery contract with its single owner.

---

## 8. Runtime bindables and Core.Net, in brief

### 8.1 PlayerScripts.Runtime
`StarterPlayerScripts.Runtime` is authored in Studio and cloned into each player's PlayerScripts. Folders: UI,
Racing, Dealership, Garage (empty), Vehicles (empty), World (empty). Scripts reach endpoints with
`Players.LocalPlayer.PlayerScripts.Runtime.<Area>.<Name>` through `WaitForChild` chains. These bindables are the
client's internal API between owners; a new UI set must use the same ones.

| Endpoint | Class | Owner (listener) | Callers |
|---|---|---|---|
| UI.ShowTopNotification | BindableEvent `(message, duration)` | SharedTopNotificationUI | 8 scripts |
| UI.LoadingTransitionInvoke | BindableFunction `(action, payload)` | LoadingTransitionUI | 6 scripts |
| UI.LoadingPresentationState | Folder with attributes | LoadingTransitionRuntime writes | 3 readers |
| UI.LoadingPresentationChanged | BindableEvent | LoadingTransitionRuntime fires | OnboardingClient |
| UI.FreeRoamHudPresentationMode | BindableEvent `{Owner, Active, KeepTelemetry}` | both HUDs listen | 10 scripts fire |
| UI.FreeRoamVehicleExited / Spawned | BindableEvent | several | DriveSessionClient, HUDs, GarageUI, race clients, start screen |
| UI.OpenRaceBrowser | BindableEvent | RaceBrowserClient | both HUDs |
| UI.OpenOwnedGarageBrowser / Workspace | BindableEvent | OwnedGarage UIs | both HUDs |
| UI.OpenDrivingControlsFromOnboarding | BindableEvent | DesktopFreeRoamHudUI | OnboardingClient |
| Racing.StartRaceQueueRequest, RaceTransitionRequest, RaceTransitionStateChanged, RaceEntryPresentationRequest, RaceEntryLegacyAction | BindableEvent | race owners | race owners |
| Dealership.OpenGarageFromIntro, GarageClosedFromDealershipExit, OpenDrivingVehicleCustomisation, OpenOwnedCockpitCustomisation | BindableEvent | GarageUI and friends | intro, HUD, garage |

SharedTopNotificationUI creates its bindable if it is missing (14-16); most others assume it exists.

### 8.2 Core.Net
Server-only, `ServerStorage.Modules.Core.Net`. `Net.invoke(spec, handler)` and `Net.event(spec, handler)` wrap the
server handlers. For each call: action allow-list, payload sanity (depth under 4, at most 64 keys, strings up to
8192, finite numbers), a per-player token bucket (default capacity 60, refill 20 per second), optional busy lock.
Rejections come back as `{Ok=false, Success=false, Message=...}`, and normal replies get both `Ok` and `Success`.

**There is no client wrapper.** Clients call remotes directly: 28 `InvokeServer` sites in 19 scripts, 4
`FireServer`, 19 `OnClientEvent`. Convention: `Remotes.<Area>.<Remote>:InvokeServer(action, payload)` inside
`pcall`, then test `result.Success == true` and show `result.Message or result.Error`.

Remotes: Garage (GarageInvoke, OwnedGarageInvoke, OwnedGarageEvent), Racing (RaceRequest, RaceEvent,
RaceBrowserTeleportInvoke, RaceQueueRequest, RaceQueueEvent), UI (FreeRoamHudTeleportInvoke), DealershipIntro (2),
Onboarding (2), Activities (2), Audio (1), Debug (1).

For a restyle: a new view can call the same remotes with the same action strings and payloads and nothing on the
server changes. It must handle the `{Ok=false, Message}` rejection shape, including the rate-limit message. Two UI
sets alive at once would double every poll against the same token bucket, which is one more reason to choose the
set before `require`.

---

## 9. Cross-cutting observations for the restyle

### 9.1 Style tokens
Font and colour sources found in this group's reach:
- Michroma is named in three config values (`Theme.FontFamily`, `Racing.Typography.FontFamily`,
  `GarageExperience.FontFamily`), in 9 `Michroma.json` literals and 13 `Enum.Font.Michroma` literals across client
  scripts. (The earlier pass said four config values; three were found here.)
- `Color3.fromRGB` literals in client scripts: 273 (GarageComponents 40, MobileFreeRoamHudUI 22, GarageUI 22,
  GarageWorkspaceUI 16, UITheme 13, FullMapUI 13, ActivityClient 13, DesktopFreeRoamHudUI 11, ...).
- `Core.ConfigReader` already has typed, warn-once readers (`Color`, `Number`, `String`, `Attribute`,
  `NumberAttribute`, `BoolAttribute`). Only DriveTuning and four race scripts use it. A new token reader for
  `Config.UI.Style` can be built on it and gets "warn once, fall back" for free, which is the style sheet's
  failure rule.
- `Core.ConnectionScope` exists (connect, add, task, destroy in reverse order) and only two scripts use it. New
  shared components should take a scope so cleanup is one call.

### 9.2 Scaling
Mechanisms seen from this group:

| Where | Mechanism |
|---|---|
| Foundation.Confirmation | 1920x1080 canvas, uniform UIScale to the device-safe rect, no floor |
| Foundation toasts | no scale, two pixel presets by touch |
| Start screen | no scale, four breakpoint presets |
| Loading view | scale width with pixel clamps, fixed pixel heights and text |
| RacingUIComponents.AttachResponsiveScale (155-175) | 1200x720 shell, 10% / 8% edge buffers (min 48 px), UIScale clamp .55 to 1.15 |
| Corner and stroke | device-class presets, then scaled again by any UIScale above them |

`ViewportSize` is referenced 48 times in 22 client scripts, and `Instance.new("UIScale")` appears in 10. Each owner
listens to the camera on its own.

A shared scale source would remove most of this: one module that watches the viewport and safe insets once,
computes one scale with a phone floor (so `Label` stays at or above 11 px and targets at or above 48 px), and
exposes it with a change signal. Screens then anchor clusters to their corners and give each cluster a UIScale
bound to that value, which is the "anchored clusters, not one scaled canvas" rule in the style sheet and keeps
corner clusters on the edges at 3440x1440.

### 9.3 Hairlines
The new style replaces UIStroke outlines with 2 px Frames. Under a UIScale of 0.67 a 2 px Frame is 1.33 px and
will render soft or uneven between panels. Snap them: thickness = `max(1, round(2 * scale)) / scale`, updated when
the shared scale changes. The same applies to the 4 px tab underline and the 6 px selected base line.

### 9.4 Instance budget
Old button: 7 instances (bevel 3, strokes 2). A new-style button is the TextButton plus two hairline Frames, plus
one glow ImageLabel only on the main button: 3 or 4. Old panel with stroke and glow: 4; new panel: 3. So the new
look should come in under today's counts, inside the style sheet's "within 10%" budget, as long as glow images are
not added to every tile.

### 9.5 DisplayOrder ladder (from source literals)
-10 DrivingSpeedEffect; 18 DealershipIntro; 40 GarageComponents; 58 GarageInteriorModeUI; 78 RaceRouteGuide;
84 ActivityClient; 85 DesktopFreeRoamHud; 88 MobileFreeRoamHud_Phase1; 90 GarageEntrance; 96 MobileDriveControls;
155 RaceSessionPresentation; 170 RaceBrowser; 171 OwnedGarageBrowser; 180 RaceEntryPresentation; 190 RaceQueue;
205 RaceCountdown; 210 RaceTransition; 220 RaceTimeTrialResultCoach; 1000 LoadingBackground;
1001 LoadingSafeContent; 1100 SharedTopNotification; 1250 SharedConfirmationOverlay; 2000 DriveToEarnCashTelemetry.
FullMapUI and OnboardingClient compute theirs from config. A new set should reuse these numbers so layering with
any untouched owner stays the same; a shared constants table would stop them being scattered.

### 9.6 What "old UI kept as a backup" means for this group

| Script | Can stay byte-identical? | Note |
|---|---|---|
| ResponsiveUIFoundation | Yes | New kit requires it for money, cash presenter, economy, cash binding |
| UITheme | Yes | Not used by the new style |
| PathResolver | Yes | Not involved |
| LoadingScreenView | Yes | New view module beside it |
| ClientLifecycle | Yes | No change needed |
| ClientBase | No | Composition root; needs the optional path field and resolver choice |
| LoadingTransitionRuntime | No, 2 lines | View and colours choice; must remain the one singleton |
| InitialLoadingAndStartScreenClient | No, 1 guard, or fork with a guard in each | It auto-runs; exactly one may run |
| Config.UI.Theme | Yes, and it must | Changing its values changes the old look |

Rollback evidence for the three that change belongs in the repository (AGENTS.md: no in-game backup scripts unless
asked). The owner has asked for the old UI to be kept and switchable; the old owners staying in place as the
`path` of each entry is that backup, and it is selected by the flag rather than stored as a dead copy.

---

## 10. Not verified

- Nothing was run. Phone, 720p and ultrawide sizes are arithmetic from the source.
- Whether both HUDs really appear together on a touch device with a keyboard or mouse.
- Whether `ConfigService:GetConfigAsync()` returns before the first client starts on a fresh live server.
- UIStroke thickness and UICorner radius are assumed to scale with an ancestor UIScale (current engine behaviour as
  far as known); the hairline note in 9.3 depends on Frames only, which do scale.
- The CanvasGroup redraw cost of the speed lines was not measured.
- Whether Titillium Web loads without a visible font swap when first used from ReplicatedFirst.
- RacingUIComponents and GarageComponents were read here only as far as this group needs; their own group owns the detail.
