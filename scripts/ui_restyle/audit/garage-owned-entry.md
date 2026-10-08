# UI restyle audit: group "garage-owned-entry"

Audited 2026-10-08, read-only, from live Studio (Space Racers v3, placeId 93959280828322, Edit mode).
Nothing here was run in Play. Every "defect" is read from source and should be confirmed in Play before it is fixed.
Line numbers are the live script line numbers. Several scripts are minified: one line can hold a whole page of logic (longest line 2,779 characters), so a line number often points at a long line rather than one statement.

Scripts read completely:

| Script | Lines | Chars | Notes |
|---|---:|---:|---|
| ReplicatedStorage.Modules.Game.UI.OwnedGarageBrowserUI | 148 | 26,279 | 13 lines over 500 chars |
| ReplicatedStorage.Modules.Game.UI.OwnedGarageWorkspaceUI | 189 | 45,386 | 25 lines over 500 chars, longest 2,779 |
| ReplicatedStorage.Modules.Game.UI.OwnedGarageClient | 18 | 944 | starter only |
| ReplicatedStorage.Modules.Game.UI.GarageInteriorModeUI | 281 | 24,152 | about 200 lines are a touch camera guard, not UI |
| ReplicatedStorage.Modules.Game.UI.GarageInteriorTransitionUI | 14 | 1,650 | no UI |
| ReplicatedStorage.Modules.Game.Dealership.DealershipIntroClient | 738 | 26,374 | readable formatting |
| ReplicatedStorage.Modules.Game.Dealership.GarageEntranceClient | 227 | 9,204 | readable formatting |
| ReplicatedStorage.Modules.Game.UI.LoadingTransitionUI | 28 | 1,393 | wrapper only |

All eight paths exist as listed. Also read because the listed scripts are thin shells over them:
ReplicatedFirst.Loading.LoadingTransitionRuntime (177), LoadingScreenView (314), LoadingArtworkCatalog (109), InitialLoadingAndStartScreenClient (329), StarterPlayerScripts.ClientBase (113), Core.ClientLifecycle (49), RacingUIComponents (194), RacingMobileScaledDesktopLayout (89), UITheme (97), and the parts of GarageComponents and GarageWorkspaceUI that these scripts call.

---

## 0. Findings that affect the whole restyle plan

1. **Core.FeatureFlags is server-only.** It lives at `ServerStorage.Modules.Core.FeatureFlags` and no client-visible script mentions it. `ReplicatedStorage.Modules.Core` holds only CameraService, ClientLifecycle, ConfigReader, ConnectionScope, PathResolver, Signal, Tags. The style sheet says UI owners read "Core.FeatureFlags for the style switch". Client UI cannot do that today. The switch needs a replicated projection (for example a server script that copies the flag onto an attribute of `ReplicatedStorage.Config.UI.Style`), or a plain replicated config value.
2. **The loading screen is built in ReplicatedFirst, before ClientBase.** `InitialLoadingAndStartScreenClient:23` calls `LoadingTransitionRuntime.Start`, which is a singleton and builds the view once (`LoadingTransitionRuntime:34,47`). `LoadingTransitionUI` only receives the already-built singleton. So the style must be readable at ReplicatedFirst time, and a server-set attribute may not have arrived yet. The first loading screen needs a defined fallback.
3. **All entrance and garage prompts are native Roblox ProximityPrompts (Style = Default).** Found in the place: `OwnedGarageFootEntryPrompt`, `OwnedGarageDriveInEntryPrompt` (Workspace), `FootExitPrompt`, `ManageGaragePrompt` (ServerStorage templates, two each), plus the three created by GarageEntranceClient. No script handles `PromptShown`. The engine draws them, so they will not pick up the new style. Matching the sheet's "Start banner with one key cap" for these needs a custom prompt renderer (Style = Custom), which is new work and one more shared component.
4. **Three private toast/status labels duplicate the shared top notification** (`ShowTopNotification` / `Foundation.CreateTopNotificationController`): the interior HUD `GarageStatus` label, the entrance `GarageEntranceStatus` label and the browser `Status` label. Each has its own size, font size, colours and timing.
5. **Two ScreenGuis use ZIndexBehavior = Global.** A probe confirmed `Instance.new("ScreenGui").ZIndexBehavior` is `Global` in this engine version. `OwnedGarageBrowser` (BrowserUI:11) and `GarageEntranceStatus` (EntranceClient:70) never set it. The shared components compute ZIndex as `parent.ZIndex + n`, which behaves differently under Global and Sibling. New views should set Sibling explicitly.
6. **The dealership intro objective UI is switched off by config in v3.** `Workspace.World.Dealership.Intro` has `ShowObjectiveText = false`, `DynamicArrowTetherEnabled = false`, `AutoOpenGarageAtDesk = false`. The objective pill and the arrow tether are never built. Only the camera intro and the completion mark still run.
7. **No script in this group handles keyboard or gamepad.** No `GuiService.SelectedObject`, no `ContextActionService`, no Escape or ButtonB close. The only gamepad support is the shared confirmation modal (`ResponsiveUIFoundation.Confirmation`, lines 315 to 440) and the native prompts (`GamepadKeyCode = ButtonX`).
8. **Clients have no stop or cleanup path.** `ClientLifecycle` is start-only ("No individual feature hot reload", line 1). Every connection below lives for the session. A style switch can only take effect on the next Play start, which matches the sheet.

DisplayOrder map for this group:

| ScreenGui | DisplayOrder | IgnoreGuiInset | ResetOnSpawn | ZIndexBehavior | Built by |
|---|---:|---|---|---|---|
| DealershipIntroObjective | 18 | true | false | Sibling | DealershipIntroClient:173 (only if ShowObjectiveText) |
| CanonicalGarageGui (shared with GarageUI) | 40 | true | false | Sibling | GarageComponents.CanonicalHost:295 |
| OwnedGarageInteriorHUD | 58 | **false** | false | Sibling | GarageInteriorModeUI:11 |
| GarageEntranceStatus | 90 | true | false | Global (default) | GarageEntranceClient:70 |
| OwnedGarageBrowser | 171 | true | false | Global (default) | OwnedGarageBrowserUI:11 |
| LoadingBackground | 1000 (config) | true, ScreenInsets None | false | Sibling | LoadingScreenView:31 |
| LoadingSafeContent | 1001 | true, CoreUISafeInsets | false | Sibling | LoadingScreenView:40 |

Start-up chain: `StarterPlayerScripts.ClientBase` (LocalScript) passes an explicit entry list to `Core.ClientLifecycle.start`. Each entry's module `.start()` runs in its own task once its dependencies report ready (30 s deadline, ClientLifecycle:30 to 37). Status is written to `ClientBase.StartupState` attributes. Entries for this group (ClientBase lines 21 to 27, 69 to 70, 75 to 77):

- DealershipIntroClient, depends on GarageUI
- GarageEntranceClient, depends on LoadingTransitionUI and GarageUI
- LoadingTransitionUI, no dependencies
- OwnedGarageClient, depends on LoadingTransitionUI

---

## 1. OwnedGarageBrowserUI ("My Garages" and "Visit" browser)

### 1.1 Purpose and lifecycle
- Modal browser that lists the player's garage properties and, on a second tab, same-server garages open to visit. It also owns several non-visual jobs (see 1.5).
- Started by `OwnedGarageClient.start` (first in its order list, OwnedGarageClient:8 to 9) through `Controller.Start()` (line 5). Guarded by `started` (line 6).
- Everything is built once in `Start`. Nothing is ever destroyed except cards, tabs and the replacement prompt. No stop function.
- Public API: `Controller.Start()`, `Controller.Close(reason)`, `Controller.IsOpen()` (lines 3 to 5). Before `Start`, `Close` is a no-op and `IsOpen` returns false (line 2).
- 13 `:Connect` calls, all permanent.

### 1.2 Instance tree
```
ScreenGui "OwnedGarageBrowser"  DisplayOrder 171, IgnoreGuiInset true, ResetOnSpawn false   (line 11)
  Frame "Overlay"  full screen, black 0.38, Visible=false, not Active                        (line 12)
    Frame "OwnedGarageShell"  UI.Panel, PanelDeep, stroke 2 + glow, clips, centred            (line 13)
      UIScale "ResponsiveScale" (desktop) or "MobileScaledDesktopScale" (touch)              (line 14)
      TextLabel "Title"  (24,0) 55% x 64                                                     (line 20)
      Frame divider at y=64, 1 px                                                            (line 20)
      Frame content  (24,88) size (1,-48, 1,-176)                                            (line 21)
        ScrollingFrame "GarageList"  38% wide, AutomaticCanvasSize Y, scrollbar 6            (line 22)
          Frame "CardContent" + UIListLayout (padding 12) + UIPadding                        (lines 23 to 24)
            Shared.Card "Garage_<PropertyId>" or "Visit_<OwnerUserId>"  (1,0,0,158), image 148
        Frame detail  62% wide                                                               (line 36)
          Shared.Panel "GarageImage" 290 tall + ImageLabel "Image" + TextLabel "Placeholder" (lines 37 to 38)
          TextLabel "GarageTitle" y=308, "District" y=347, "Description" y=382 (72 tall)     (line 39)
          Shared.MetricCard "Capacity" y=466, 54 tall, TextScaled label                      (line 40)
      TextLabel "Status"                                                                     (lines 41, 43)
      TextButton "Exit"  left half of footer                                                 (line 44)
      TextButton "Enter" right half of footer                                                (line 45)
      TextButton "MineTab", "VisitTab"  180 x 44, top right (only when visits are enabled)   (line 71)
      Frame "ReplacementPrompt" (ZIndex 200) + Shared.Panel "Panel" (ZIndex 201) + rows      (lines 95 to 105)
```
Instance estimate: about 44 static, 14 for the two tabs, about 17 per card. Roughly 60 + 17 per garage.

### 1.3 Scaling and layout
- Fixed logical canvas 1200 x 720, every child positioned with pixel offsets inside it (30 `UDim2.new`, 18 `UDim2.fromOffset`, 5 `fromScale`).
- **Desktop** (line 14): `shell.Size = 1200 x 720`, then `UI.AttachResponsiveScale` (RacingUIComponents:155 to 175):
  `scale = clamp(min((vw - 2*max(48, vw*0.10)) / 1200, (vh - 2*max(48, vh*0.08)) / 720), 0.55, 1.15)`.
  Values come from `Config.UI.Racing.Layout` (DesktopEdgeBufferXRatio 0.1, DesktopEdgeBufferYRatio 0.08, ShellWidth 1200, ShellHeight 720, ResponsiveScaleMin 0.55, ScaleMax 1.15).

  | Viewport | Scale | Shell on screen | Share of width |
  |---|---:|---|---:|
  | 1280 x 720 | 0.84 | 1008 x 605 | 79% |
  | 1920 x 1080 | 1.15 (capped) | 1380 x 828 | 72% |
  | 2560 x 1440 | 1.15 | 1380 x 828 | 54% |
  | 3440 x 1440 | 1.15 | 1380 x 828 | 40% |
  | 3840 x 2160 | 1.15 | 1380 x 828 | 36% |

  Above 1080p the panel stops growing, so text is the same pixel size on 4K as on 1080p (Heading 22 becomes 25 px).
- **Touch** (line 14): `Mobile.Attach(shell)` (RacingMobileScaledDesktopLayout:19 to 86). Shell is forced to 1200 x 720 and scaled:
  `scale = clamp(min((vw - 20) / 1200, (vh - 72 - 10) / 720), 0.25, 1)`, centred in the safe box. Attributes on `Config.UI.Racing.MobileScaledDesktop`: ReferenceWidth 1200, ReferenceHeight 720, SafeTop 72, SafeBottom 10, SafeSide 10, ScaleMin 0.25, ScaleMax 1.

  | Viewport | Scale | Heading 22 | Body 15 | Caption 11 | Footer button 48 | Tab 44 |
  |---|---:|---:|---:|---:|---:|---:|
  | 844 x 390 phone | 0.43 | 9.4 px | 6.4 px | 4.7 px | 20.5 px | 18.8 px |
  | 932 x 430 phone | 0.48 | 10.6 px | 7.2 px | 5.3 px | 23.2 px | 21.3 px |
  | 1180 x 820 tablet | 0.97 | 21 px | 14.5 px | 10.6 px | 46 px | 43 px |

- Safe area: the fixed SafeTop/SafeBottom/SafeSide numbers above are the only handling. No `GuiService:GetInsetArea`. The ScreenGui uses `IgnoreGuiInset = true`, which keeps device safe insets.
- Text sizing: fixed `TextSize` from `Config.UI.Racing.Typography` (Heading 22, Body 14, Caption 11, Metric 22, Button 14) with literal overrides at lines 20, 38, 39, 40, 41, 95. Only the capacity label uses `TextScaled` with a `UITextSizeConstraint` (min 8, max 30 on touch, else Metric) (line 40).
- Touch hardening (`hardenTouch`, line 18): walks every descendant of the overlay and raises fixed-height `GuiButton`s to `ceil(max(32, MinimumTouchTargetPixels) / scale)` logical pixels. Skips anything with `SkipTouchHardening`. Exit, Enter and both tabs carry that attribute (lines 44, 45, 71), so the main actions are exactly the ones not protected.
- Stroke clearance (`layoutListEdges`, lines 25 to 33) converts physical stroke width to logical pixels so the selected card glow is not clipped by the scroller.
- Viewport change: the UIScale updates. Two listeners on `layoutScale.Scale` (lines 19 and 35) re-run hardening and list edges when the browser is visible. Desktop scale listens to the camera that existed at attach time only (RacingUIComponents:172 to 173). The touch path rebinds on `CurrentCamera` change.

### 1.4 Config read
- `Config.UI.Racing.Colours` through `UI.Colour`: PanelDeep, Outline, Muted, Telemetry, Text, Danger, PanelSoft, PanelBlue.
- `Config.UI.Racing.Layout` through `UI.Layout`: PanelTransparency, ShellStrokeWidth, OuterPadding (24), Gap (16), plus the six scale values above.
- `Config.UI.Racing.Typography`: Heading, Caption, Body, Metric, FontFamily (Michroma).
- `Config.UI.Racing.MobileScaledDesktop` attributes (8).
- `Config.Garage.Interior` attribute `MinimumTouchTargetPixels` (44; the style sheet says 48).
- `Config.UI.GarageReplacement.OwnedGarageIcons.Browser` attribute `Cancel` (blank). `Enter` and `Exit` exist there but are not read.
- `Config.UI.Theme` indirectly (stroke widths, corner scale, bevel) through ResponsiveUIFoundation.

### 1.5 Remotes, bindables, attributes, state
- `Remotes.Garage.OwnedGarageInvoke` (RemoteFunction) actions: `GetState`, `GetVisitableGarages`, `VisitGarage {OwnerUserId}`, `LeaveVisit`, `EnterSelectedGarage {PropertyId, ReplacementSlotId?}`, `ExitOnFoot` (lines 56, 87, 91, 101, 108, 116).
- `Remotes.Garage.OwnedGarageEvent` (RemoteEvent) received: `OwnedGarageStreamRequest`, `DriveOut`, `DriveOutResult`, `FootExitResult`, `VisitEnded` (lines 135 to 144). Sent: `OwnedGarageStreamReady {Token, Success, Message}` (line 138).
- Bindables in `PlayerScripts.Runtime.UI`: listens to `OpenOwnedGarageBrowser` (line 119, fired by DesktopFreeRoamHudUI:879 and MobileFreeRoamHudUI:315); invokes `LoadingTransitionInvoke` Begin / Complete / Fail (lines 57 to 59); fires `FreeRoamHudPresentationMode {Owner="OwnedGarageBrowser", Active, KeepTelemetry=false}` (line 55); fires `ShowTopNotification` (line 50).
- `ProximityPromptService.PromptTriggered` (line 120): prompt names `FootExitPrompt`, `DriveOutPrompt`; prompt attributes `OwnedGarageEntryPrompt`, `OwnedGaragePropertyId`.
- Player attributes read: `OwnedGarageInside`, `OwnedGarageVisitor`.
- Streaming: `player:RequestStreamAroundAsync` then a 0.05 s poll for `Workspace.World.Interiors.OwnedGarageInstances.<name>` or `World.OwnedGarageExteriors.<id>` markers, up to 3 to 15 s (lines 130 to 138).

### 1.6 Input
Mouse and touch through `Activated` only. No keyboard shortcut, no gamepad focus or cancel. The label argument "E" passed to `Shared.SetActionButton` at line 66 is dropped, because `enter` is a plain `UI.Button` with no `ActionContent` child (GarageComponents:57).

### 1.7 Per-frame, polling, rebuild
- No per-frame work. The only poll is the 0.05 s stream-ready wait during a transition.
- `render()` (lines 82 to 85) destroys and recreates both tabs and every card on each selection click, on each mode change and after each refresh. Hover state and any controller selection are lost on every click.
- `hardenTouch` runs `overlay:GetDescendants()` after every render on touch.

### 1.8 Mobile differences
Scaled-desktop path (1.3), touch hardening, a larger replacement modal (720 x 600 with 112-tall rows, against 560 x 330 with 58-tall rows on desktop, lines 95 to 105), and a larger capacity text maximum. Layout is otherwise identical to desktop.

### 1.9 Hard-coded style
- Colours: `Color3.new(0,0,0)` twice (lines 12, 95). All other colours come from Racing.Colours. Selected and muted card colours are literals inside `GarageComponents.Card` (lines 73 to 74).
- Fonts: none directly; Michroma arrives through `RacingUIComponents.Font` (line 47 of that module).
- Sizes: canvas 1200 x 720 (line 14); header 64; content inset 24/88/176; hero 290; detail rows at 308, 347, 382, 466; card 158 with image 148; tabs 180 x 44; footer button 48 at -64; modal sizes above; 11 literal text sizes (22, 20, 26, 13, 15, 16, 11, 24, 14).

### 1.10 Defects seen in source
1. **Status text sits behind the footer buttons.** Line 41 places `Status` at `1,-82`; line 43 moves it to `1,-58` with height 20, inside the button band (`1,-64` to `1,-16`). The label has ZIndex 1 and the buttons ZIndex 3, so "LOADING GARAGES..." and every error message are drawn under EXIT and ENTER (lines 41 to 45).
2. **Phone touch targets about 20 px.** Exit, Enter and tabs are exempt from hardening and scale to about 0.43 on a phone (1.3). The sheet requires 48 px.
3. **Phone text 5 to 9 px** for captions, body and card names (1.3).
4. **Scale capped at 1.15**, so the browser is a small centred box on 1440p, ultrawide and 4K (1.3).
5. **Replacement modal has a fixed height and no scrolling** (lines 95 to 105). Desktop rows start at y=112 with a 68 pitch inside a 330 panel whose Cancel button occupies 274 to 316: the third row overlaps Cancel and a fourth leaves the panel. The only garage in the place today is "KANDA TWO-BAY", so this is latent.
6. **The modal and the overlay do not block input.** `shade`, `overlay` and `shell` are plain Frames with `Active = false`; buttons behind the modal stay clickable and clicks on the dimmed area reach the world.
7. **Full list and tab rebuild on every click** (1.7).
8. **ZIndexBehavior left at Global** (line 11); the modal relies on literal ZIndex 200 to 203.
9. Disabled Enter state is text colour only (line 52); no shared disabled look.
10. Desktop scale does not rebind when `CurrentCamera` changes (RacingUIComponents:172).

### 1.11 Seam for a switchable view
- View code and controller code share one closure. View: lines 11 to 45 (build), 60 to 85 (render), 94 to 106 (modal), 18 to 19 and 25 to 35 (touch and edge layout). Controller: 55 to 59, 86 to 93, 107 to 144.
- The controller half must have exactly one owner. A second running copy would acknowledge each `OwnedGarageStreamRequest` token twice, call loading Begin twice and show the visit-ended toast twice.
- Token-level change comes free: every surface is `UI.Panel`, `UI.Label`, `UI.Button`, `Shared.Panel`, `Shared.MetricCard`, `Shared.Card`, `Shared.ActionButton`. If those shared components switch on the style, this script changes colour, font, corner and stroke with no edit.
- Structural change (full-screen tint, title top-left, list on the left, buttons bottom-right, phone layout) needs a new module. Cleanest route that leaves this file untouched: a new module with the same API (`Start`, `Close`, `IsOpen`), its own copy of the controller half, and a new view; `OwnedGarageClient` starts one or the other. The cost is a duplicated controller that can drift.
- Names other scripts rely on: ScreenGui name `OwnedGarageBrowser` (OnboardingClient:216 and 469 via `screenRoot`), descendants named `GarageList` and `Enter` (OnboardingClient:198), presentation owner string `"OwnedGarageBrowser"` (GarageInteriorTransitionUI:10). A new view must keep all three.
- `GarageInteriorTransitionUI:6` requires this module by name to call `Close`. If a new module has a different name, that script must close whichever is active. Calling `Close` on the idle one is safe.

---

## 2. OwnedGarageWorkspaceUI (management desk)

### 2.1 Purpose and lifecycle
- Controller for the in-garage management desk: Display Cars, Build Garage, Style Garage. It contains no view code at all (0 `Instance.new`, 0 `UDim2`, 0 `TextSize`). It builds a "context" table per page and hands it to the shared view `GarageWorkspaceUI`.
- Started second by `OwnedGarageClient`. `Start` (line 9) creates one `WorkspaceUI.new()` instance for the session and renames its root to `OwnedGarageCanonicalWorkspace` (line 13).
- Public API: `Start`, `Close(reason)`, `IsOpen()`, `IsCameraTouchBlocked(position)` (lines 3 to 9). The last is called by GarageInteriorModeUI:242.
- Two permanent connections (lines 175 and 176) plus whatever the shared view keeps.

### 2.2 Instance tree
Built by `GarageWorkspaceUI.new` (lines 141 to 185 of that module) inside the shared host from `GarageComponents.CanonicalHost` (lines 295 to 311):
```
ScreenGui "CanonicalGarageGui"  DisplayOrder 40, IgnoreGuiInset true, ResetOnSpawn false, Sibling
  Frame "CanonicalCanvas" + UIScale "CanonicalScale"
    Frame "OwnedGarageCanonicalWorkspace"  (attributes TutorialWorkspace=true, TutorialPageId)
      "Header" (title + subtitle), "Categories" (left rail), "Right" (Stats, Economy: Cash, Capacity),
      "TutorialCardCarousel" > "TutorialCardScroller", "Previous"/"Next" arrows,
      "Back", "Continue", "Exit" action buttons, "UpgradeBudget", popup
```
The same host ScreenGui and canvas are shared with the dealership and customisation garage (GarageUI). `Shared.AcquirePresentation` hides the other root when one shows (GarageComponents:181 to 194).

### 2.3 Scaling and layout
All in the shared view (`GarageComponents.LayoutGarageShell`, lines 274 to 293). In short:
- `scale = clamp(min(availW / 1600, availH / 900), minimum, 1.02)`; minimum is 0.68 on desktop (`DesktopMinScale`) and 0.25 on touch (`TouchScaleMin`). The canvas is then resized to `availW / scale` by `availH / scale`, so clusters are anchored to the real screen edges in logical pixels. This is already the "anchored clusters" model the sheet asks for, and it behaves on ultrawide.
- 1280 x 720 gives 0.8; 1920 x 1080 and everything larger gives 1.02, so nothing grows on 1440p or 4K.
- Phone 844 x 390 gives about 0.42: header title 22 becomes 9 px, 46-tall action buttons become about 20 px. Only the carousel arrows are hardened (`applyTouchPresentation`, GarageComponents:251 to 256).
- Touch safe margins are fixed attributes (TouchSafeTop/Bottom/Side = 4).
- This controller picks which layout flags to set (line 126): `LeftFloating`, `LeftCardMode`, `LeftSharedCardSize`, `LeftAlignCarouselBottom`, `ExitBelowEconomy`, `ShowStats=false`.

### 2.4 Config read
- `Config.Garage.Interior` attributes: `MobileManagementVisibleSurfaceMapEnabled` (13), `OwnedGarageCategoryCardImageZoom` (27), `DebugTimingEnabled` (30, 168).
- `Config.UI.GarageReplacement` attribute `OwnedGarageUnaffordablePriceColor` (143, 145, 147).
- `Config.UI.GarageReplacement.NavigationIcons` attributes as legacy fallback: OwnedModulesIcon, BuildModulesIcon, CustomiseModulesIcon, BuyModulesIcon, BackIcon, ExitIcon, ModuleLockIcon (line 22). `ModuleLockIcon` does not exist there; the primary `States.Locked` does.
- `Config.UI.GarageReplacement.OwnedGarageIcons` folders: Modes, Families, Navigation, Actions, States, Economy, StructureLocations, DecorationLocations, Materials, Sizing (lines 22 to 29). Blank today: `Actions.InstallAsset`, `Economy.Capacity`.

### 2.5 Remotes, attributes, state, view contract
- `OwnedGarageInvoke` actions: GetManagementState, SetManagementOpen, CancelAllPreviews, PreviewDisplay, AssignDisplay, PreviewStructure, CancelStructurePreview, PreviewStructureFinish, PreviewStructureFinishAll, ConfigureStructure (Purchase, Equip, SetFinish, SetFinishAll), PreviewDecoration, CancelDecorationPreview, PreviewDecorationFinish, PreviewDecorationFinishAll, ConfigureDecoration (Purchase, Place, Clear, SetFinish, SetFinishAll), PreviewLighting, CancelLightingPreview, ConfigureLighting (Purchase, Equip, SetFinish), SetAccessMode, SetInvitation.
- Every mutation carries `BaseRevision` and a GUID `RequestId` (line 51). Purchases spend Cash on the server. This is High-Risk territory: the view may change, the call sequence may not.
- `OwnedGarageEvent` received: OpenManagement, DriveOut, ManagementUpdated (revision-gated, queued while busy), DriveOutResult (lines 176 to 185).
- Bindable `OpenOwnedGarageWorkspace` (line 175). No script fires it; the desk opens through the server push `OpenManagement` (OwnedGarageManagement:241).
- Writes `PlayerGui` attribute `OwnedGarageManagementOpen` (line 35). Read by DesktopFreeRoamHudUI:1125, MobileFreeRoamHudUI:330, OnboardingClient:470 and 662, FullMapUI:456, PreviewCameraClient:41, GarageInteriorModeUI. Single owner.
- Cash shown is a projection: `Shared.ProjectEconomy` on every response (line 30).
- Audio: `PresentationAudioBridge.Result` on assign, structure and decoration results (lines 52 to 56).
- **View contract** (fields this controller sets on the context table): TutorialPageId, Title, Subtitle, ShowLeft, LeftItems `{Id, Text, Image, ImageZoom, Selected, OnSelect}`, LeftFloating, LeftCardMode, LeftSharedCardSize, LeftAlignCarouselBottom, Cards `{Id, CardKind (nil | "Vehicle" | "Listing"), DisplayName, VehicleName, Image, ImageZoom, Badge, BadgeColor, Footer, Selected, Muted, EmptyPlus, Price, PriceColor, SemanticState ("Equipped" | "Available" | "Locked"), LockImage, OnSelect}`, Cash, CapacityText, CapacityIcon, ShowStats, ShowCashPlus, ShowCapacityPlus, NextVisible, NextText, NextIcon, OnNext, BackVisible, BackText, BackIcon, OnBack, ExitVisible, ExitText, ExitIcon, OnExit, ExitBelowEconomy, CarouselScrollKey, CategoryScrollKey, RuntimeAudit, SelectedAction `{RowId, Text, OnActivate}`, EmptyMessage, ColorChannels, MaterialChannels, SelectedChannel, Colors, OnChannel, OnColor(channel, colour, commit).
- View methods used: `new()`, `.Root`, `.TouchMapEnabled`, `:Show(context)`, `:RefreshCards(context)`, `:Message(text)`, `:Hide()`, `:IsTouchBlocked(position)`.
- Pages: Home, DisplaySpaces, DisplayVehicles, Build, Style, BuildStructure, BuildDecorations, BuildLighting, StyleStructure, StyleStructureColour, StyleStructureMaterial, StyleDecorations, StyleDecorationsColour, StyleLighting, Access, AccessInvites, and a placeholder fallthrough (lines 130 to 166).

### 2.6 Input
None of its own. Whatever the shared view provides (mouse, touch, mouse wheel on the rail). No gamepad.

### 2.7 Per-frame, polling, rebuild
- No per-frame work here.
- `render(true)` calls `workspace:Show`, a full rebuild of rail, stats, economy and cards with two layout passes. `render(false)` calls `RefreshCards` (cards only) (line 168). Many handlers use the full rebuild where cards-only would do: channel switches on the colour pages (151, 156, 159) and every colour commit.
- The touch surface map is rebuilt after any descendant change while open (shared view).

### 2.8 Mobile differences
Only `TouchMapEnabled` (line 13) and `IsCameraTouchBlocked`. Everything else is in the shared view.

### 2.9 Hard-coded style
- 9 `Color3.fromRGB`: the six tier colours (line 15: E 132,142,145; D 105,190,129; C 74,204,211; B 82,137,235; A 244,188,65; S 236,92,168) and the unaffordable red fallback 255,75,85 three times (143, 145, 147).
- These are passed to the view as `BadgeColor` and `PriceColor`. The sheet replaces both (white tier badge, muted unaffordable price), so a new view should ignore the two fields rather than this controller changing.
- Title "GARAGE MANAGEMENT" and all subtitles and footers are literal strings here.

### 2.10 Defects seen in source
1. **Server calls block the UI thread inside click handlers.** Rail clicks call `request("CancelStructurePreview")` or `request("CancelDecorationPreview")` before rendering (lines 113, 115). Card clicks call `PreviewStructure`, `PreviewDecoration`, `PreviewLighting` or a finish preview before `render(false)` (143, 145, 147, 152). Back buttons do the same (143, 145, 147, 153, 157, 159). The highlight therefore waits for a round trip, and there is no busy guard on these paths, so quick clicks stack requests.
2. **Access and AccessInvites pages are unreachable** (lines 160 to 163). Nothing navigates to "Access" and nothing fires `OpenOwnedGarageWorkspace`. The interior HUD dropdowns do this job now. Do not spend restyle effort on them.
3. Full rebuild used where a card refresh would do (2.7).
4. Tier colours duplicated here as literals instead of coming from a shared tier source (line 15).
5. Minified source: lines up to 2,779 characters make anchor-based patching fragile. Prefer whole-script replacement if this file ever has to change.

### 2.11 Seam
- This is already the cleanest seam in the group: controller here, view in `GarageWorkspaceUI`. If the style switch lives inside `GarageWorkspaceUI` and `GarageComponents` (or `GarageWorkspaceUI` hands back a style-specific implementation of the same contract), this script needs no edit and the management desk is restyled together with the dealership and customisation screens.
- A new view must keep: root attributes `TutorialWorkspace` and `TutorialPageId` (OnboardingClient:186, 468) with page ids GarageHome, DisplayCars, GarageAssetFamilies, BuildStructure, BuildDecorations; card instance names equal to card Ids (`DisplayCars`, `BuildGarage`, `StyleGarage`, `Structure`, `Decorations`, `Lighting`; OnboardingClient:199 to 200); descendants named `Categories` and `TutorialCardScroller`; and a working `IsTouchBlocked`.
- Must stay single-owner: `OwnedGarageManagementOpen`, the revision and request-id sequence, preview cancel on close.

---

## 3. OwnedGarageClient

- 18 lines. `Client.start()` requires and starts, in order: OwnedGarageBrowserUI, OwnedGarageWorkspaceUI, GarageInteriorModeUI, GarageInteriorTransitionUI (lines 8 to 9), asserting each returns ok. Then sets attribute `OwnedGarageClientStarted` on `PlayerScripts.Runtime.UI` (line 10).
- No UI, no config, no remotes.
- This is the natural place to choose between an old and a new browser or interior HUD module: one name in the `order` table. It is also the only script that would need a line changed to do so.

---

## 4. GarageInteriorModeUI (interior HUD: access mode and invites)

### 4.1 Purpose and lifecycle
- Two jobs in one module. (a) A small owner-only HUD inside the owned garage: an access-mode button and an invite button, each with a dropdown, plus a status toast. (b) A touch camera guard for walking inside the garage (lines 48 to 270), which is not UI.
- Started third by `OwnedGarageClient`. Built once in `Start` (line 3). 16 permanent connections; one camera `ViewportSize` connection that is rebound on camera change (line 47).
- No public API beyond `Start`.

### 4.2 Instance tree
```
ScreenGui "OwnedGarageInteriorHUD"  DisplayOrder 58, IgnoreGuiInset FALSE, ResetOnSpawn false, Sibling  (line 11)
  Frame "AccessControls"  (18,18) 330 x 48 + UIScale "ResponsiveScale"                                 (lines 12 to 13)
    Shared.ActionButton "Access"  158 x 46 + "DropdownChevron"                                         (line 14)
    Shared.ActionButton "Invite"  158 x 46 + "DropdownChevron"                                         (line 15)
    Frame "AnchoredDropdown" > ScrollingFrame "Choices" > TextButton "Choice<n>"   (built on open)
  TextLabel "GarageStatus"  420 x 34, child of the ScreenGui, not scaled                               (line 16)
```
About 31 static instances; a dropdown adds 2 plus 7 per row.

### 4.3 Scaling and layout (`layout`, line 45)
- **Desktop: scale is always 1.** Buttons are 158 x 46 px and label text 14 px at every resolution, including 4K.
- **Touch:** `scale = clamp(min(vw / 800, vh / 600), 0.72, 1)` when `InteriorHudTouchResponsiveScale` is not false. On 844 x 390 this is 0.72.
- Button width `max(106, min(base, floor((vw/scale - 2*margin - gap) / 2)))`, base 158 (150 on touch). Height `max(40 or 44, configured)`, 46 (48 on touch).
- Phone result: 150 x 48 logical becomes about 108 x 35 px. Dropdown rows inherit the button height (line 29), so they are also about 35 px, with 11 and 9 logical text (about 8 and 6.5 px).
- The toast is parented to the ScreenGui, outside the UIScale: always 34 px tall, 12 px text, width 220 to 420.
- `IgnoreGuiInset = false`, the only ScreenGui in this group that sits below the Roblox top bar. Position is top-left at the margin (18).
- Viewport change: `layout` re-runs on `ViewportSize` and on `CurrentCamera` change; the dropdown is re-placed (`dropdown:Relayout`).

### 4.4 Config read (`Config.Garage.Interior` attributes unless noted)
InteriorHudTouchResponsiveScale, InteriorHudTouchReferenceWidth (800), InteriorHudTouchReferenceHeight (600), InteriorHudTouchMinimumScale (0.72), InteriorHudTouchMaximumScale (1), InteriorHudMargin (18), InteriorHudGap (8), InteriorHudButtonWidth (158), InteriorHudTouchButtonWidth (150), InteriorHudButtonHeight (46), InteriorHudTouchButtonHeight (48), InteriorHudDropdownGap (5), InteriorHudDropdownRowGap (5), InteriorHudDropdownRows (5), InteriorHudTouchDropdownRows (4), legacy icon strings InteriorHudPrivateIcon / FriendsIcon / InviteOnlyIcon / PublicIcon / InviteIcon (all blank), MobileWalkingCameraGuardEnabled, MobileTouchCameraRecoveryEnabled, MobileThumbstickSemanticConfirmWindowSeconds.
- `Config.UI.GarageReplacement.OwnedGarageIcons.Access` attributes Private, FriendsOnly, InviteOnly, Public, Invite: all blank.
- `Config.UI.Racing.Colours`: PanelSoft, Outline, PanelBlue, Telemetry, PanelDeep, Danger.
- Present in config but never read: `InteriorHudDropdownRowHeight` (38), `InteriorHudTouchDropdownRowHeight` (44).

### 4.5 Remotes, attributes, state
- `OwnedGarageInvoke`: GetManagementState (line 27), SetAccessMode, SetInvitation with BaseRevision and RequestId (lines 31, 38, 42).
- `OwnedGarageEvent`: DriveOutResult (toast), ManagementUpdated (refresh and reopen the dropdown) (line 277).
- Player attributes read: OwnedGarageInside, OwnedGarageVisitor, MobileMajorMenuOpen, GarageSessionActive, RaceSessionActive.
- `PlayerGui` attributes: reads OwnedGarageManagementOpen; writes OwnedGarageInteriorMode (line 10; no reader found in any script).
- Calls `OwnedGarageWorkspaceUI.IsCameraTouchBlocked` (line 242).
- Reads Roblox touch controls by name: `PlayerGui.TouchGui.TouchControlFrame.DynamicThumbstickFrame.ThumbstickStart` (lines 114 to 119).
- Visibility rule (line 273): inside, management closed, no mobile major menu, not a visitor.

### 4.6 Input
- Mouse and touch `Activated` on the two buttons; outside click closes the dropdown (GarageComponents:350).
- Raw `UserInputService.InputBegan / InputChanged / InputEnded` for the camera guard, touch only (lines 238 to 254).
- No keyboard, no gamepad.

### 4.7 Per-frame, polling, rebuild
- `RunService:BindToRenderStep("OwnedGarageTouchCameraGuard", Camera+1)` only while a guarded touch is held (lines 170 to 183). Touch devices only. Sets camera CFrame and Focus each frame.
- The three input connections are always live; they return early on non-touch input.
- Each time the HUD becomes visible it calls `GetManagementState` (line 273), and again on every `ManagementUpdated` push. That is the full management payload (structure, decoration and lighting catalogues) fetched to read `AccessMode` and `InvitationRows`.
- The dropdown is destroyed and rebuilt on every open and every refresh. The invite button opens it, refreshes, then opens it again (line 275).

### 4.8 Mobile differences
Touch scale, touch button sizes, fewer dropdown rows, slightly larger dropdown text (11/9 against 10/8, line 29), and the whole camera guard.

### 4.9 Hard-coded style
- No colour literals; all through Racing.Colours.
- Text sizes: toast 12 (line 16), dropdown 10/11 and 8/9 (line 29); button label 14 and glyph 22 inside `Shared.ActionButton`.
- Sizes: root 330 x 48, buttons 158 x 46, toast 420 x 34 at y = margin + height + 8, corner 6, toast lifetime 2.4 s.
- Icons are unicode glyphs because every icon id is blank: lock U+1F512, people U+1F465, envelope U+2709, target U+25CE, dot U+25CF (lines 14, 15, 21). These render from a fallback emoji font, not Michroma, and will not match the sheet's single-colour icon set.

### 4.10 Defects seen in source
1. **No desktop scaling at all**: fixed 158 x 46 px buttons on every monitor (line 45).
2. **Phone buttons and dropdown rows about 35 px tall**, under both the 44 px config value and the sheet's 48 px (4.3).
3. **Dropdown text about 6 to 8 px on phones** (4.3).
4. **Emoji glyphs instead of icons** (4.9).
5. **Private toast**, unscaled, duplicating the shared top notification (line 16).
6. `IgnoreGuiInset = false` while every other HUD uses true, so its top margin is measured from a different origin than the free-roam HUD.
7. Heavy `GetManagementState` call for two fields, repeated on every update (4.7).
8. Two dead config attributes (4.4); `InteriorHudMargin` fallback for small screens never applies because the attribute is set (line 45).
9. UI and camera lifecycle share one module, so the UI cannot be replaced by a parallel copy without also moving or duplicating the camera guard.

### 4.11 Seam
- View: lines 11 to 18 (build), 44 to 47 (layout), 36 to 43 (dropdown rows). Access state: 19 to 35. Camera guard: 48 to 270. Visibility and wiring: 271 to 278.
- Token-level change comes free: both buttons are `Shared.ActionButton`, the dropdown is `Shared.AnchoredDropdown`, the toast is `UI.Label`.
- The scaling, touch-target and toast fixes need either a small edit here or a replacement module started in its place. A replacement must carry the camera guard too, or the guard must first move to its own module; two copies would both bind the render step name `OwnedGarageTouchCameraGuard` and both process the same touches.
- No other script references `OwnedGarageInteriorHUD`, `AccessControls` or `GarageStatus`.

---

## 5. GarageInteriorTransitionUI

- 14 lines, no UI, no config, no remotes.
- `Start` (line 3) closes the browser and the management desk (`Browser.Close("Transition")`, `Workspace.Close("Transition")`) when: `OwnedGarageInside` stops being true (line 8); the character respawns outside a garage (line 9); or any other owner activates `FreeRoamHudPresentationMode` (owner not `OwnedGarageBrowser` or `OwnedGarageWorkspace`, line 10).
- Three permanent connections.
- Observation: the management desk never fires `FreeRoamHudPresentationMode` with owner `OwnedGarageWorkspace`; only the browser fires its own owner string. Harmless today.
- Seam: it requires the two modules by name. If new modules replace them under new names, this script must close the active ones. Keeping the module names, or calling `Close` on both old and new, avoids editing the logic.

---

## 6. DealershipIntroClient (intro objective and desk guidance)

### 6.1 Purpose and lifecycle
- First-visit guidance to the dealership desk: an objective pill, a 3D arrow tether, a short camera intro, a persisted "objective complete" mark, and a leave-and-re-enter gate for reopening the desk.
- Started by ClientBase (depends on GarageUI). `Client.start` spawns `run()` in a task (lines 724 to 731).
- `run` (line 633) waits for the character and `Workspace.World.Dealership.Intro`, builds UI and tether if the objective is incomplete, then loops forever at 0.15 s (lines 689 to 721).
- Cleanup (line 622) only sets the ScreenGui `Enabled = false` and stops the tether. The GUI is not destroyed and its viewport connection stays.

### 6.2 Instance tree (only when `ShowObjectiveText` is true; it is false in v3)
```
ScreenGui "DealershipIntroObjective"  DisplayOrder 18, IgnoreGuiInset true, ResetOnSpawn false, Sibling  (lines 173 to 179)
  Frame "ObjectiveRoot"  anchor (0.5,0), position (0.5,0, 0,18), size 360 x 46                          (lines 181 to 189)
    UIScale, UICorner (theme.PanelCornerRadius), UIStroke (theme.Accent, width 1)                       (lines 191 to 203)
    TextLabel "ObjectiveText"  TextSize 13, wrapped, centred                                            (lines 205 to 217)
```
World objects (only when `DynamicArrowTetherEnabled`; false in v3): `Workspace.ClientOnly.IntroPath` with up to 18 arrow models of three neon parts each, plus two beams.

### 6.3 Scaling
`scale = clamp(min(vw / 1280, vh / 720), 0.78, 1)` (line 222). Never above 1: 360 x 46 px with 13 px text on 1080p and on 4K; about 281 x 36 with 10 px text on a phone. Listens to `ViewportSize` of the camera captured at build time only (lines 219 to 228). No safe-area handling; with `IgnoreGuiInset = true` and y = 18 it sits in the top-bar band.

### 6.4 Config read
- `UITheme.Read()` (legacy `Config.UI.Theme`): Panel, Text, Accent, PanelTransparency, PanelStrokeTransparency, StrokeWidth, PanelCornerRadius, FontFamily (lines 35 to 63). This is the old palette (Text 255,218,246; Accent 255,172,234), not the Racing colours used everywhere else in this group.
- `Workspace.World.Dealership.Intro` attributes (39 exist; about 30 read at lines 109 to 149): Enabled, DeskActivationDistance, AutoOpenGarageAtDesk, ShowObjectiveText, IntroObjectiveText, CameraIntroEnabled, CameraIntroDuration, PersistIntroObjectiveCompletion, the DynamicArrowTether* family, Debug. Also `GarageDeskTrigger.ActivationDistance`.

### 6.5 Remotes, bindables, attributes
- `Remotes.DealershipIntro.GetDealershipIntroObjectiveComplete` (RemoteFunction) and `CompleteDealershipIntroObjective` (RemoteEvent), both behind Core.Net on the server (IntroProgressServer:196, 200).
- Bindables in `PlayerScripts.Runtime.Dealership`: fires `OpenGarageFromIntro` (line 614, only when AutoOpenGarageAtDesk); listens to `GarageClosedFromDealershipExit` (line 687; fired by GarageUI).
- Player attribute `DealershipIntroObjectiveComplete`; camera attribute `DealershipIntroCameraActive`.

### 6.6 Input
None.

### 6.7 Per-frame and polling
- `RenderStepped` tether update, up to 54 part CFrames per frame (lines 420 to 458). Off in v3.
- 0.15 s distance poll for the whole session (line 720). With auto-open off, its only remaining effects are marking the objective complete once and writing log lines.
- Camera intro: one tween and a delayed restore (lines 475 to 525).

### 6.8 Mobile differences
None beyond the scale clamp.

### 6.9 Hard-coded style
- 6 `Color3.fromRGB`: theme fallbacks at lines 37 to 39 (5,9,7; 218,255,231; 172,255,197) and tether defaults at 139, 140, 142.
- Font: Michroma literal at line 44 (fallback), applied with `Font.new(theme.FontFamily)` at line 210.
- Sizes: 360 x 46, y offset 18, padding 12/5, TextSize 13, scale base 1280 x 720.
- Corner uses the raw theme radius, bypassing the foundation corner scale (line 196).

### 6.10 Defects seen in source
1. The objective pill is styled from the legacy Theme folder, so it would not match anything else if it were re-enabled.
2. Scale never exceeds 1 and the text is 13 px (6.3).
3. Viewport connection and disabled ScreenGui are left behind after completion (lines 226 to 228, 622 to 625).
4. A session-long 0.15 s poll that does almost nothing with the current config (6.7).
5. Stale header comment and warning text refer to `Workspace.NeoTokyoRacersWorld` and old installer scripts (lines 12, 616).

### 6.11 Seam
- View is one function, `createObjectiveGui` (lines 165 to 231), plus `clearObjectiveGui`. Everything else is logic or world effects.
- Because the UI is off in v3, the cheapest correct plan is to leave this script untouched and decide separately whether the objective returns. If it does, it should be drawn by a shared objective or notification component rather than a private pill.
- No other script references the ScreenGui name `DealershipIntroObjective` (the IntroProgressServer match is the remote name).

---

## 7. GarageEntranceClient (dealership and customisation entrance prompts)

### 7.1 Purpose and lifecycle
- Creates the three native entrance prompts and handles their trigger: server begin, loading transition, hand-off to GarageUI.
- Started by ClientBase (depends on LoadingTransitionUI and GarageUI). All work happens inside `Client.start` (line 4).
- Destroys any earlier `GarageEntranceStatus` ScreenGui (lines 65 to 66) and any earlier `Canonical<Mode>` prompt (lines 149 to 150) before creating its own.
- Permanent: three `Triggered` connections, one attribute signal, one `CharacterAdded`, one 0.25 s loop.

### 7.2 Instance tree
```
ScreenGui "GarageEntranceStatus"  DisplayOrder 90, IgnoreGuiInset true, ResetOnSpawn false  (lines 70 to 75)
  TextLabel (unnamed)  anchor (0.5,1), position (0.5,0, 1,-28), size 420 x 42, hidden      (lines 77 to 87)
    UICorner 4, UIStroke width 1                                                           (lines 88 to 91)
```
World: `ProximityPrompt` named `CanonicalDealership`, `CanonicalCustomisation`, `CanonicalDriveIn` on `World.Dealership.Intro.Desk.GarageDeskTrigger`, `World.Dealership.Customisation.CustomisationDeskTrigger`, `...DriveInCustomisationTrigger` (lines 30 to 54, 152 to 163). Style Default, ActionText "Enter", ObjectText "Dealership" or "Customisation", key E, gamepad ButtonX, clickable, no hold, distance from config, no line of sight.

### 7.3 Scaling
None. The label is 420 x 42 px with 13 px text on every device. No UIScale, no wrap, no truncation, no text size constraint. Bottom offset is a fixed 28 px; no safe-area handling.

### 7.4 Config read
`Config.UI.GarageExperience` values: PanelDeep, Text, Structure (colours, lines 81 to 90), PromptDistance (14, line 161). This is a third colour folder, different from the Racing folder and from Theme.

### 7.5 Remotes, bindables, attributes
- `Remotes.UI.GarageSessionRequest:InvokeServer("Begin", {Mode})` and `("End", {ReturnToEntry=true})` (lines 178, 196).
- `LoadingTransitionInvoke` Begin and Fail (lines 189, 198).
- Fires `PlayerScripts.Runtime.Dealership.<Event>` with `{LoadingGeneration, LoadingDestination}`: OpenGarageFromIntro, OpenOwnedCockpitCustomisation, OpenDrivingVehicleCustomisation (lines 192 to 194). GarageUI listens.
- Sets player attribute `GarageEntryMode` (line 190); GarageUI clears it.
- `ShowTopNotification` for one specific message only (lines 95 to 98). `PresentationAudioBridge.Emit("UI.PurchaseRejected")` (line 182).

### 7.6 Input
Native prompt input only (E, ButtonX, tap).

### 7.7 Per-frame and polling
A 0.25 s loop for the whole session re-evaluates all three prompts (lines 215 to 220). Only the drive-in prompt needs it, to notice the player sitting or standing.

### 7.8 Mobile differences
None.

### 7.9 Hard-coded style
- 2 `Color3.fromRGB` fallbacks (lines 81, 90) and one `Color3.new(1,1,1)` (line 83).
- Font: Michroma literal, not read from any config (line 84).
- Sizes: 420 x 42, offset -28, TextSize 13, corner 4, stroke 1, lifetime 2 s.

### 7.10 Defects seen in source
1. **Two message routes.** One message goes to the shared top notification; every other one goes to the private bottom label (lines 94 to 106).
2. No scaling, wrapping or truncation: a long server message overflows 420 px; the label is tiny on 4K (7.3).
3. Font and colours bypass the shared components; ZIndexBehavior left at Global (line 70).
4. The server call runs before the loading screen begins (lines 177 to 189), so there is no feedback for one round trip after pressing the prompt.
5. Session-long 0.25 s poll where a seat-change signal would do (7.7).
6. The prompts themselves are engine-drawn and cannot follow the new style (section 0, item 3).

### 7.11 Seam
- View is the status label and `flash` (lines 65 to 106). Everything else is prompt ownership and session logic and must have one owner: a second copy would destroy the first copy's prompts on start (lines 149 to 150).
- Smallest route to the new look: send every `flash` message to the shared top notification when the style is on, and keep the label as the old-style branch. That is a few lines inside this script. A full replacement module is not worth it for one label.
- No other script references `GarageEntranceStatus` or the `Canonical<Mode>` prompt names.

---

## 8. LoadingTransitionUI and the loading view behind it

### 8.1 Purpose and lifecycle
- `LoadingTransitionUI` (28 lines) is a wrapper. `Client.start` calls `LoadingTransitionRuntime.Start({UIFolder})` (line 10), binds `LoadingTransitionInvoke.OnInvoke` to `api:Handle(action, payload)` inside a pcall (lines 13 to 18) and sets `LoadingPresentationState.ControllerReady = true` (line 20).
- The runtime is a singleton (`LoadingTransitionRuntime:34`). It is first created by `ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient:23`, before ClientBase runs, unless `StartScreenEnabled` is false. The view is therefore built once, very early.
- Runtime actions: Begin, Progress, Complete, Fail, Cancel, GetState (`LoadingTransitionRuntime:156 to 170`). Begin acquires a gameplay input lock, picks artwork, shows the view, fires `FreeRoamHudPresentationMode {Owner="LoadingTransition"}`, starts audio ducking and a 12 s timeout (lines 76 to 126). Finish holds for the minimum visible time, fills the bar, fades and releases (lines 128 to 154).
- Callers of `LoadingTransitionInvoke`: OwnedGarageBrowserUI, DesktopFreeRoamHudUI, MobileFreeRoamHudUI, GarageUI, GarageEntranceClient, RaceTransitionClient.
- State published: `LoadingPresentationState` attributes Active, Generation, Destination, FadeStarted, Reason, ControllerReady; bindable `LoadingPresentationChanged`. Readers: VehicleAudioClient, OnboardingClient, RaceLifecyclePresentationClient.

### 8.2 Instance tree (`LoadingScreenView.Create`, lines 20 to 68)
```
ScreenGui "LoadingBackground"  DisplayOrder 1000 (config), IgnoreGuiInset, ScreenInsets None, Sibling, disabled
  Frame "BlackBacking" (Active)
    Frame "ArtworkClip" > Frame "ArtworkMotion" (1.08 scale) > ImageLabel "SingleArtwork", Frame "GridArtwork" (+ up to 6 tiles)
    TextButton "InputBlocker" (Modal)
ScreenGui "LoadingSafeContent"  DisplayOrder 1001, ScreenInsets CoreUISafeInsets, Sibling, disabled
  Frame "SafeRoot"
    TextLabel "Status"  anchor (0.5,1), position (0.5, 0.79), size (0.72, 0, 0, 34) + UISizeConstraint 220..820 x 34
    Frame "ProgressTrack"  position (0.5, 0.81), size (0.58, 0, 0, 22) + UISizeConstraint 220..720 x 22 + UICorner 9
      Frame "ProgressFill" + UICorner 8 + UIGradient
```
About 23 instances including grid tiles. The start screen adds `StartScreenActions` with two `RacingUIComponents.Button`s under `SafeRoot`.

### 8.3 Scaling
- No UIScale. Artwork is scale-sized and cropped, with a cover calculation for the 3 x 2 grid (lines 70 to 81), so the picture fills any aspect ratio including ultrawide.
- Status text is a fixed 15 px. The bar is a fixed 22 px tall and at most 720 px wide. On 3440 x 1440 the bar is 21% of the width; on 4K it is 19% with 15 px text.
- Safe area: handled properly by the two-ScreenGui split (full-bleed background, safe-inset content).
- The start screen picks one of four fixed layouts by breakpoint, including a portrait branch (InitialLoadingAndStartScreenClient:238 to 272).

### 8.4 Config read
- `Config.UI.LoadingSystem` attributes (36): DisplayOrder, MinimumVisibleSeconds, CompletionFillSeconds, ReadyHoldSeconds, FadeOutSeconds, TimeoutSeconds, WarmPoolSize, Motion* (6), Grid* (4), the audio set, StartScreen* values. Child folder `Artworks`.
- `Config.UI.DesktopFreeRoamHud.Colours`: Text, PanelSoft, Telemetry, ElectricBlue (LoadingTransitionRuntime:40, LoadingScreenView:43 to 51).

### 8.5 Per-frame work
One `RenderStepped` loop while a transition is active, setting the fill size (LoadingTransitionRuntime:101 to 119). One looping artwork tween. Both stop when the screen hides. Fade uses 5 tweens plus one per grid tile.

### 8.6 Hard-coded style
- `Enum.Font.Michroma` literal (LoadingScreenView:43). This is one of the script literals the sheet's font change has to reach, and it is not in any config value.
- 5 `Color3.fromRGB` fallbacks (lines 43 to 51).
- Sizes: text 15, bar 22, corners 9 and 8, positions 0.79 and 0.81.
- Status strings are literals in the callers ("ENTERING OWNED GARAGE", "RETURNING TO CITY", "ENTERING DEALERSHIP", "LOADING NEO TOKYO" at InitialLoadingAndStartScreenClient:38, and so on). "LOADING NEO TOKYO" is the old game name.

### 8.7 Defects seen in source
1. Status text and bar do not scale; small on 1440p and above (8.3).
2. Rounded bar with a blue-to-teal gradient and Michroma: opposite to the sheet (square, no gradient outside the main button, one typeface).
3. The start screen reaches into the view by instance name (`LoadingSafeContent`, `SafeRoot`, `Status`, `ProgressTrack`, `ProgressFill`) and clones the fill (InitialLoadingAndStartScreenClient:78 to 104). Any new loading view must keep these names or that script breaks.
4. Old title string "LOADING NEO TOKYO".

### 8.8 Seam
- `LoadingTransitionUI` needs no change under any plan.
- The view is already a separate module with a small interface: `Create(playerGui, config, colours)`, `Warm`, `SetArtwork`, `Show`, `SetStatus`, `SetProgress`, `SetProgressImmediate`, `StartMotion`, `FadeOut`, `Hide`, `Destroy`. A second view module with the same interface and the same five instance names can be selected at `LoadingTransitionRuntime:8` and `:47`. That is a one-line choice in the runtime, with the old view untouched as the backup.
- The choice is made at ReplicatedFirst time (section 0, item 2).
- Single owner: the runtime (input lock, audio mix, presentation state). Do not create a second runtime.

---

## 9. Cross-cutting summary for the restyle

### 9.1 What the shared components already cover
| Screen | Built from shared components | Private view code that would not follow a component-level switch |
|---|---|---|
| Garage browser | Panel, Label, Button, Shared.Panel, MetricCard, Card, ActionButton | 1200 x 720 layout, text sizes, black overlay, modal, status label |
| Management desk | Entirely GarageWorkspaceUI + GarageComponents | Nothing in this script except tier and price colours it passes in |
| Interior HUD | ActionButton, AnchoredDropdown, Label | Scale formula, toast, glyph icons, text sizes |
| Entrance status | None | Whole label |
| Intro objective | None (legacy UITheme) | Whole pill (off in v3) |
| Loading screen | None (start-screen buttons use RacingUIComponents.Button) | Whole view |

### 9.2 Three different scale models in one group
| Screen | Reference | Formula | Min | Max |
|---|---|---|---:|---:|
| Garage browser, desktop | 1200 x 720 with 10% / 8% edge buffer | min of fit X, fit Y | 0.55 | 1.15 |
| Garage browser, touch | 1200 x 720 inside fixed safe margins | min of fit X, fit Y | 0.25 | 1 |
| Management desk | 1600 x 900, canvas resized to the viewport | min of fit X, fit Y | 0.68 (0.25 touch) | 1.02 |
| Interior HUD | 800 x 600, touch only | min of fit X, fit Y | 0.72 | 1 (desktop fixed 1) |
| Intro objective | 1280 x 720 | min of fit X, fit Y | 0.78 | 1 |
| Entrance status, loading text | none | fixed pixels | - | - |

None of them grows past about 1.15, so everything in this group shrinks relative to the screen above 1080p. On phones the two menu screens fall to about 0.42 to 0.48, which is where the unreadable text and small targets come from.

### 9.3 Colour sources used by this group
`Config.UI.Racing.Colours` (browser, management desk, interior HUD), `Config.UI.DesktopFreeRoamHud.Colours` (loading), `Config.UI.GarageExperience` (entrance status), `Config.UI.Theme` (intro objective), plus literals: 9 in OwnedGarageWorkspaceUI, 6 in DealershipIntroClient, 2 in GarageEntranceClient, 5 in LoadingScreenView, and the selected/muted card literals in GarageComponents.Card.

### 9.4 Michroma sites reached from this group
`Config.UI.Racing.Typography.FontFamily`, `Config.UI.Theme.FontFamily`, `Config.UI.GarageExperience.FontFamily` (config values); literals at RacingUIComponents:47, UITheme:29, DealershipIntroClient:44, GarageEntranceClient:84, LoadingScreenView:43 (`Enum.Font.Michroma`).

### 9.5 Names and strings other scripts depend on
| Name | Used by |
|---|---|
| ScreenGui `OwnedGarageBrowser`; descendants `GarageList`, `Enter` | OnboardingClient:198, 216, 469 |
| Presentation owner `"OwnedGarageBrowser"`, `"OwnedGarageWorkspace"` | GarageInteriorTransitionUI:10 |
| Root attributes `TutorialWorkspace`, `TutorialPageId`; page ids GarageHome, DisplayCars, GarageAssetFamilies, BuildStructure, BuildDecorations | OnboardingClient:186, 217 to 221, 468 |
| Card names DisplayCars, BuildGarage, StyleGarage, Structure, Decorations, Lighting; `Categories`; `TutorialCardScroller` | OnboardingClient:199 to 200 |
| `LoadingSafeContent` > `SafeRoot` > `Status`, `ProgressTrack` > `ProgressFill` | InitialLoadingAndStartScreenClient:78 to 98 |
| `PlayerGui` attribute `OwnedGarageManagementOpen` | DesktopFreeRoamHudUI, MobileFreeRoamHudUI, OnboardingClient, FullMapUI, PreviewCameraClient, GarageInteriorModeUI |
| `LoadingPresentationState` attributes, `LoadingPresentationChanged` | VehicleAudioClient, OnboardingClient, RaceLifecyclePresentationClient |
| Module names OwnedGarageBrowserUI, OwnedGarageWorkspaceUI | GarageInteriorTransitionUI:6, GarageInteriorModeUI:52, OwnedGarageClient:8 |

### 9.6 Things that must keep a single owner
- OwnedGarage stream acknowledgement, physical loading begin and finish, and the prompt-trigger listener (browser controller).
- `OwnedGarageManagementOpen`, the revision and request-id sequence, preview cancel (management controller).
- The touch camera guard and its render-step name (interior HUD module).
- The three `Canonical<Mode>` prompts and `GarageEntryMode` (entrance client).
- The loading runtime singleton: input lock, audio mix, presentation state.

### 9.7 Suggested order of work for this group (for the planner)
1. Decide how the client reads the style switch, including at ReplicatedFirst time.
2. Management desk: no work here; it follows the shared garage view.
3. Loading screen: second view module behind a one-line choice in the runtime.
4. Garage browser: new module with the same API and names, chosen in OwnedGarageClient; fix the status overlap, modal, touch targets and input blocking in the new view.
5. Interior HUD: first move the camera guard out or accept one small edit; then scale, targets, icons, shared notification.
6. Entrance status: route to the shared notification.
7. Intro objective: leave as is while it is off.
8. Native prompts: decide whether a custom prompt renderer is in scope.
