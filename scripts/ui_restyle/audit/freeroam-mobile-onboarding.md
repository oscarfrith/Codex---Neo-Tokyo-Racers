# UI restyle audit: free-roam mobile HUD, touch controls, onboarding, top notifications

Group: `freeroam-mobile-onboarding`
Audited: 2026-10-08, read-only, live Studio "Space Racers v3" (placeId 93959280828322), Edit mode.
Nothing in the repo or Studio was changed. No Play session was run, so every runtime statement below is from source reading, not from observation.

Scripts read completely (all lines):

| Script | Lines | Chars | `Color3.fromRGB` | Font literal | `UDim2.*` |
|---|---:|---:|---:|---|---:|
| `ReplicatedStorage.Modules.Game.UI.MobileFreeRoamHudUI` | 503 | 55,184 | 22 | `Enum.Font.Michroma` (40) | 167 |
| `ReplicatedStorage.Modules.Game.Vehicles.MobileDriveControlsClient` | 209 | 17,707 | 7 | `Enum.Font.Michroma` (29) | 41 |
| `ReplicatedStorage.Modules.Game.UI.OnboardingClient` | 766 | 55,484 | 4 | `Enum.Font.Michroma` (34) | 48 |
| `ReplicatedStorage.Modules.Game.UI.OnboardingGuideTrailRenderer` | 139 | 10,514 | 2 | none | 0 |
| `ReplicatedStorage.Modules.Game.UI.SharedTopNotificationUI` | 27 | 1,286 | 0 | none (view is in the foundation) | 0 |

Also read for context: `ResponsiveUIFoundation` (562 lines, all), `RacingUIComponents` (40-194), `MobileDriveInputState` (all), `Core.ClientLifecycle` (all), `ClientBase` (all), `ServerStorage.Modules.Core.FeatureFlags` (all), `DesktopFreeRoamHudUI` 1-40, `FullMapUI` 440-480, `FreeRoamVehicleExitButtonClient` (all).

All five listed paths exist as given.

---

## 0. Cross-cutting findings (read these first)

### 0.1 How desktop versus mobile HUD is chosen

- `ClientBase` starts **both** HUDs unconditionally, in parallel (`task.spawn` per entry in `ClientLifecycle.start`, lines 28-45): `DesktopFreeRoamHudUI` (ClientBase 65-66), `MobileFreeRoamHudUI` (71-72), `MobileDriveControlsClient` (61-62). None has dependencies.
- Each one decides for itself on its first lines, once, at start:
  - `MobileFreeRoamHudUI:13` and `MobileDriveControlsClient:12`: `if not UserInputService.TouchEnabled then return end`.
  - `DesktopFreeRoamHudUI:16-19`: `desktopInputEligible = KeyboardEnabled or MouseEnabled; if TouchEnabled and not desktopInputEligible then return end`.
- The early `return` is inside the `xpcall`, so the lifecycle records the module as `ready` even though it built nothing.
- The choice is never re-evaluated (no `LastInputTypeChanged`, no `PreferredInput`).
- **The two gates are not complementary.** A device with touch plus a keyboard or mouse (touch laptop, Chromebook, tablet with a keyboard case) passes both, so it gets `DesktopFreeRoamHud` (DisplayOrder 85) and `MobileFreeRoamHud_Phase1` (88) and `MobileDriveControls_Phase1` (96) at the same time. Both HUDs then call `RouteGuide.Update` each frame, both bind cash, both draw a minimap.
- Mobile detection is inconsistent across the place: `TouchEnabled` (these scripts, `Foundation.IsMobile`, racing clients); `TouchEnabled and not KeyboardEnabled` (`FullMapUI:50`, `ActivityClient:32`); `TouchEnabled and short side <= 700` (start screen); `short side <= 650` with no touch test (`OnboardingClient:231-234`). A new style needs one shared "form factor" answer.

### 0.2 The style switch cannot read Core.FeatureFlags from the client

- The style sheet (line 265) and AGENTS.md say the switch is "one Core.FeatureFlags flag". `FeatureFlags` lives at `ServerStorage.Modules.Core.FeatureFlags` and is server-only (reads `ServerStorage.Config` `Flag_<Key>` in Studio, then a ConfigService snapshot refreshed every 60 s). There is no client FeatureFlags module in `ReplicatedStorage.Modules.Core` (children: ClientLifecycle, ConnectionScope, ConfigReader, PathResolver, Signal, Tags, CameraService).
- All UI in this group is built at client start by `ClientBase`. The switch therefore needs a replicated value that exists before `ClientBase` runs (for example an attribute the server stamps on `ReplicatedStorage.Config.UI.Style` at boot, or a player attribute `ClientBase` waits for).
- `FeatureFlags.Get` returns the caller's default until the first ConfigService fetch lands, so a fresh server can hand early joiners the default and later joiners the dashboard value. Read it once per session and do not change it mid-session.

### 0.3 Three different safe-area approaches

| Owner | ScreenGui inset setting | Where its layout numbers come from |
|---|---|---|
| `MobileFreeRoamHud_Phase1`, `MobileDriveControls_Phase1`, `SharedTopNotification` | `IgnoreGuiInset=true` only (engine maps this to device-safe insets) | `workspace.CurrentCamera.ViewportSize` (full viewport) plus constant margins 10/14/16 px and config constants `ModalSafeTop=72`, `ModalSafeBottom=10`, `ModalSafeSide=10` |
| `Onboarding` | `IgnoreGuiInset=true`, `ScreenInsets=None`, `ClipToDeviceSafeArea=false` (82-83) | `overlay.AbsoluteSize`, target `AbsolutePosition - overlay.AbsolutePosition`, `GuiService:GetGuiInset()` |
| `SharedConfirmationOverlay` (foundation 328-336, 396-420) | `ScreenInsets=None`, `ClipToDeviceSafeArea=false` | `GuiService:GetInsetArea(DeviceSafeInsets)` against `GetInsetArea(None)`: the only real device-safe-area maths in the place |

The mobile HUD and the touch controls measure the full viewport but place children inside a ScreenGui whose origin and size may be inset by the device safe area. On a notched phone that would push right-anchored items (minimap, cash, pedals) right by the left inset and clip them. **Not verified in Play** (read-only audit); it needs one check on an emulated notched phone before the restyle copies this pattern. The confirmation overlay's `safeViewportRect` (foundation 396-409) is the pattern worth sharing.

### 0.4 The free-roam telemetry cluster is also the in-race gauge

`RaceSessionPresentationClient:164` and `RaceQueueClient:25` fire `FreeRoamHudPresentationMode` with `KeepTelemetry=true`. Both HUDs then stay enabled and show only speed, boost and the gauge (`MobileFreeRoamHudUI:393-405`, `DesktopFreeRoamHudUI:1341-1344`). So build step 3 (free-roam HUD) and step 4 (in-race HUD) of the style sheet share one gauge owner on each platform.

### 0.5 The palette has no tutorial colour

Onboarding uses `TutorialGold` = `255,196,66` (config attribute, fallback literal at `OnboardingClient:31`, `OnboardingGuideTrailRenderer:76,121`) for the highlight border, connector, bubble stroke, Next button, objective card stroke and the world guide trail. The style sheet reserves `Yellow 255,228,51` for Cash only and lists no guide/tutorial role. Gold and cash yellow are close enough to be confused. Needs an owner decision (see Unknowns).

### 0.6 DisplayOrder map around this group

`DesktopFreeRoamHud` 85, `MobileFreeRoamHud_Phase1` 88, `MobileDriveControls_Phase1` 96, `SharedInRaceHUD` 155, `RaceBrowser` 170, `OwnedGarageBrowser` 171, `RaceEntryPresentation` 180, `Onboarding` 990 (`LoadingSystem.DisplayOrder` 1000 minus 10), loading 1000/1001, `SharedTopNotification` 1100, `SharedConfirmationOverlay` 1250. Top notifications therefore draw over the loading screen and over the tutorial dimmer.

---

## 1. MobileFreeRoamHudUI

### 1.1 Purpose and lifecycle
- The whole touch free-roam HUD: minimap, cash chip and + button, driver rank strip, five shortcut buttons, speed/boost telemetry, Exit vehicle, the "my vehicles" car panel, the settings modal and the (placeholder) cash-store modal, teleport-to-dealership confirmation.
- Started by `ClientBase` (71-72). `Client.start()` (5) is start-once (asserts on a second call unless already `ready`). Returns at 13 when not touch.
- No stop, no cleanup, no public API. 28 `:Connect(` calls, 0 `Disconnect`. On start it destroys any earlier `MobileFreeRoamHud_Phase1` (74).
- Connections kept for the session: `RenderStepped` (391); `Rank`, `XpIntoRank`, `XpForNext`, `OwnedGarageInside` attribute signals (126); `cash` Position/Size/Visible property signals (122, 126); `FullMapOpen` attribute (331); `FreeRoamHudPresentationMode.Event` (320); `RouteGuide.Arrived` (266); about 12 `Activated` handlers; `Foundation.BindReplicatedCash` (342, the returned disconnect function is discarded).

### 1.2 Instance tree
```
ScreenGui "MobileFreeRoamHud_Phase1"  IgnoreGuiInset=true ResetOnSpawn=false DisplayOrder=88 ZIndexBehavior=Sibling   (75)
  Frame "Root" scale 1,1                                                                                               (76)
    CanvasGroup "Minimap"            (80)  -> MapRotator -> MapPanCarrier(+UIScale) -> MapCanvas (tiles from MapTileSet)
                                            Missing, PlayerMarker, North, EdgeLeft/Right/Top/Bottom (Frame+UIGradient),
                                            marker/icon/route layers from shared modules, RouteButton (full-size tap target, 264)
    Frame "Cash"                     (117) -> Value (TextScaled 5..14), Plus button
    Frame "RankStrip"                (120) -> Rank, Xp, XpTrack -> XpFill
    Frame "Navigation"               (128) -> Car, Garage, Race, Dealership, Settings   (TextButtons with Icon ImageLabel)
    Frame "Telemetry" 420x190 +UIScale .72 (137) -> BoostIconContainer, BoostTrack/BoostFill, Speed, Unit,
                                            GaugeSegment1..16, ExitVehicle
    TextButton "CarMenuOutsideTap"   (149) full screen, ZIndex 18
    Frame "CarPanel"                 (150) -> Category, Sort (dropdown buttons), VehicleGrid (ScrollingFrame) -> Content -> UIGridLayout + cards,
                                            Despawn, ChoiceList (created on demand, 288)
    TextButton "Shade"               (170) full screen black .35
    Frame "Modal"                    (171) +UIScale "SafeAreaScale", SurfaceGradient, FacetPattern, Title, Body
```
The teleport confirmation is a separate ScreenGui made by `Foundation.Confirmation` (`SharedConfirmationOverlay`, DisplayOrder 1250).

Static instance estimate: about 170 before map tiles and markers (Navigation about 36, Telemetry about 50, Cash about 11, CarPanel shell about 28, Modal shell about 11, Minimap shell about 20). Settings modal body adds about 96 (14 segmented buttons at 6 instances each). Cash modal body adds about 83. Each vehicle card is a `GarageComponents.VehicleCard`.

### 1.3 Scaling and layout
- **No reference canvas and no root UIScale.** Every position and size is a pixel offset computed in `layout()` (346-366) from `Camera.ViewportSize`.
- `layout()` runs every `RenderStepped` frame and returns early when the viewport and the `OwnedGarageInside` flag are unchanged (347). There is no `ViewportSize` signal; resize is detected by polling.
- One binary breakpoint: `tiny = vp.Y < 500` (348). Values jump at 500 px rather than interpolating.
- Minimap: `floor(clamp(vp.Y*.27, tiny 128 | 145, tiny 160 | MinimapSize))`; live `MinimapSize` is 170, so above about 630 px of height the map stops growing (348). Top-right at `EdgeMargin`.
- Navigation: `navSize = tiny 34 | NavButtonSize 42`; Car is double width; row sits left of the minimap on the top edge (349-351).
- Cash: same width as the map, directly under it, height `tiny 30 | CashHeight 34` (352, 358). Rank strip follows the cash chip through property signals, fixed 18 px tall (121-122).
- Inside an owned garage: only Settings (top-right) and Cash (bottom-left) are placed (353-355).
- Telemetry: fixed 420x190 design frame, `AnchorPoint (.5,1)`, bottom-centre, `UIScale` .72 (.62 when tiny) (360). It does not scale with the viewport, so on a tablet it stays about 302x137 px.
- Exit button lives inside the scaled telemetry frame; its Y is derived from `steeringBottomMargin = tiny 10 | 16` (360), a copy of the margin constants in `MobileDriveControlsClient:179`.
- Car panel (361-364): left edge, top `CarMenuTop` (82, 68 tiny), two columns, card width `max(64, min(CarMenuTargetCardWidth 92, fit-by-width, fit-by-height))`, aspect .88, three visible rows; dropdown row 28 px; Despawn 20 px.
- Modal (178-186): each modal sets a reference size (Settings 720 x max(490, 420); Cash 840 x 650) and `SafeAreaScale = clamp(min(availW/refW, availH/refH), ModalScaleMin .25, ModalScaleMax 1)`, centred in a rectangle defined by the three `ModalSafe*` constants. Never scales above 1.
- Text: fixed `TextSize` everywhere (7 to 27, speed 64). Only the cash value (117) and the balance chip (217) use `TextScaled` with a `UITextSizeConstraint`. `Foundation.StyleMetric` forces Michroma Bold on the cash value (334; foundation 217).
- Anchors: almost none. Only Telemetry (.5,1), Modal (.5,.5), MapRotator/MapCanvas/markers (.5,.5) and North use `AnchorPoint`; everything else is top-left with computed offsets.

### 1.4 Config read
- `Config.UI.MobileFreeRoamHud` attributes: `EdgeMargin`, `MinimapSize`, `NavButtonSize`, `NavGap`, `TopClusterGap`, `CashHeight`, `TelemetryBottomMargin`, `CarMenuTop`, `CarMenuBottomMargin`, `CarMenuPanelPadding`, `CarMenuCardGap`, `CarMenuCardTopSafePadding`, `CarMenuCardBottomSafePadding`, `CarMenuCardStrokeSafePadding`, `CarMenuVisibleRows`, `CarMenuCardAspect`, `CarMenuTargetCardWidth`, `CarMenuDespawnHeight`, `CarMenuFooterGap`, `CarMenuHeaderHeight`, `CarMenuMaxWidthRatio`, `CarMenuLeftMargin`, `CarMenuDropdownHeight`, `CarMenuDespawnGradientTransparency`, `ModalSafeTop/Bottom/Side`, `ModalScaleMin/Max`, `SettingsModalWidth/Height`, `CashModalWidth/Height`, `DefaultControlMode`.
- Present in the folder but read by no script: `CarMenuWidth`, `CarMenuWidthRatio`, `CarMenuVehicleImageYOffset`, `ConfirmModalWidth`, `ConfirmModalHeight`, `ControlButtonSize`, `HudScale`, `PedalHeight`, `PedalWidth`, `ThumbstickSize`.
- `Config.UI.DesktopFreeRoamHud.Colours` (45, 100): `Panel`, `PanelDeep`, `PanelSoft`, `Outline`, `OutlineSoft`, `Telemetry`, `ElectricBlue`, `Text`, `Muted`, `Danger`, `HighSpeed`. The mobile HUD has no colour folder of its own.
- `...DesktopFreeRoamHud.Layout`: `MapPixels`, `MapCalibrationPixels`, `MapCalibrationStuds`, `MapVisibleStuds`, `MapWorldCenterX/Z`, `MapCoordinateRotationDegrees`, `MapRotationOffsetDegrees`, `SpeedGaugeMaxMph`, `MapSpeedZoomEnabled/StartMph/FullMph/MaxFactor/OutResponse/InResponse`.
- `...DesktopFreeRoamHud.Assets`: `MapPlayerIcon`, `MapNorthArrow`, `CarIcon`, `GarageIcon`, `RaceIcon`, `DealershipIcon`, `SettingsIcon`, `BoostIcon`. `.Defaults`: `MapFlipX`, `MapFlipZ`, `MapPlayerIconRotates`. `.Effects`: `ButtonGradientStrength`, `ButtonGradientRotation`, `GradientTransparency`, `PatternTransparency`, `DropdownTransparency`, `GlowTransparency`.
- `Config.UI.FreeRoamMapPlayerMarkers` attributes: `UseRelativeCanvasTransform`, `MapPanSubpixelFactor`, `MapPanResponse` (417-418, 443).
- `Config.UI.Theme` through the foundation (corner scale, stroke widths, bevel, cash formatting and count-up).
- `ReplicatedStorage.Assets.VehiclePreviews.Categories` models and their attributes `CockpitId`, `TemplateId`, `MenuImage`, `CockpitImage`, `DisplayName`, `Price` (271, 276).

### 1.5 Dependencies and API
- Remotes: `Remotes.Garage.GarageInvoke` actions `GetInitial` (through `GarageCatalogClient.Fetch`, 70), `SpawnOwnedVehicleFromFreeRoam` (294), `DespawnVehicle` (310), `ExitVehicle` (316); `Remotes.UI.FreeRoamHudTeleportInvoke` `TeleportToDealership` (243); `Remotes.Activities.ActivityInvoke` `SetPassengerAccess` (209-210). `GarageInteriorInvoke` is fetched (32) and never used.
- Bindables in `PlayerScripts.Runtime.UI`: fires `ShowTopNotification`, `FreeRoamVehicleSpawned`, `FreeRoamVehicleExited`, `OpenRaceBrowser`, `OpenOwnedGarageBrowser`; invokes `LoadingTransitionInvoke` (`Begin`/`Complete`/`Fail`); listens to `FreeRoamHudPresentationMode`.
- Player attributes read: `Rank`, `XpIntoRank`, `XpForNext`, `OwnedGarageInside`, `GarageSessionActive`, `FullMapOpen`, `MobileControlMode`, `PassengerAccess`. PlayerGui attribute read: `OwnedGarageManagementOpen`.
- Player attributes **written**: `MobileFreeRoamCarMenuOpen` (168, 284), `MobileMajorMenuOpen` (187, 188, 190), `MobileControlMode` (201).
- State modules: `MobileDriveInputState.IsDriving/SpeedMph/BoostPercent`; `RouteGuide.Update(position)` once per frame (486) and `RouteGuide.Arrived`; `FullMapUI.Open()` (262); `leaderstats.Cash` through `Foundation.BindReplicatedCash` and `CreateCashDisplayPresenter`.
- Shared modules used: `RacingUIComponents`, `ResponsiveUIFoundation`, `GarageComponents.VehicleCard`, `VehicleDisplayNames`, `MapTileSet`, `FreeRoamMapPlayerMarkers`, `MapIconLayer`, `RouteGuide.newMapRenderer`.
- Public API: none beyond `start()`.

### 1.6 Input
Touch only, through `GuiButton.Activated`. No keyboard, no gamepad selection, no ContextActionService.

### 1.7 Per-frame work and rebuilds
- `RenderStepped` (391-495), every frame:
  - about 10 `Visible`/`Enabled` writes regardless of change (398, 401, 404-405);
  - when not hidden: roughly 30 config lookups per frame, each a `FindFirstChild` plus `GetAttribute` (`read`, 41) at 410-434, 456, 465, 487, 493 and six more inside `speedZoomFactor` (375-386);
  - `mapTiles:Cull`, `mapPlayerMarkers:Step`, `mapIcons:Step`, `RouteGuide.Update`, `routeRenderer:Step`;
  - while driving: speed text, boost fill, and two property writes on each of 16 gauge segments every frame (493).
- `cockpitModel` (271) walks `categories:GetDescendants()` for every owned vehicle each time `renderCars` runs.
- Rebuilds: `renderCars` (296-305) destroys every card and rebuilds on open, on category change and on sort change. It destroys first (297) and then may yield on `GetInitial` (cache 2 s, 270), so the panel can be empty for a round trip. The settings modal is destroyed and rebuilt on every option tap (201) and again when the passenger reply returns (210). The cash modal is rebuilt on every open. The dropdown choice list is created and destroyed per open.

### 1.8 Hard-coded style
- Colours: 10 config-backed fallbacks on line 45; truly fixed: `8,42,84` cash chip / active segment / balance / best-value (117, 195, 217, 225), gauge off `81,88,99` (146, 493), six tier colours (273), black shade (170).
- Font: `Enum.Font.Michroma` (40), passed on to `MapIconLayer` (99) and `RouteGuide` (104).
- Text sizes: 7 (Despawn, 163), 8 (rank XP, dropdown labels, icon fallbacks), 9, 10, 11 (button default, 55), 12 (label default, 51), 14, 15, 18, 20, 24, 27, 64.
- Corner radii 3 to 10 through `Foundation.Corner`; stroke widths mostly through `Foundation.StrokeWidth("Structural")`, but 1.4 and 4 are literal (68).
- Content that is placeholder, not style: `GRAPHICS`, `UI SCALE` and `SPEED UNIT` rows have empty callbacks and always show HIGH / 100% / MPH (203-205); cash packs are literal strings with "CASH PRODUCTS ARE NOT ENABLED YET" (218-228); coin art is the text "C  C  C" (223).

### 1.9 Defects
1. Touch targets under the 48 px rule the style sheet preserves: nav 42 px, 34 px when tiny (349); cash + 28x26 (117); dropdowns 28 px (363); choice rows 27 px (289); Despawn 20 px (163, 361); Exit 76x30 design px times .72 = about 55x22 px (147, 360); segmented buttons 34 px and Done 38 px before the modal scale (195, 212).
2. Text far below the sheet's 11 px floor: 7 to 9 px labels at scale 1; telemetry text times .72/.62 (Exit label about 6 px); modal text times a scale that reaches about .43 for the cash modal and .57 for settings on a 360 px tall phone (179-181).
3. Layout uses the full viewport and constant margins, not real safe-area insets (347-365). See 0.3.
4. No growth on tablets: minimap capped at `MinimapSize`, telemetry fixed at .72, nav fixed at 42 px, modal capped at scale 1.
5. Binary `tiny` breakpoint at 500 px (348) rather than a continuous rule.
6. Per-frame config lookups and unconditional gauge writes (391-495).
7. Can coexist with the desktop HUD on touch-plus-keyboard devices (13). See 0.1.
8. Three settings rows do nothing (203-205).
9. The car panel has no panel behind it (`BackgroundTransparency=1`, 150); cards float on the scene, unlike the desktop car panel.
10. Minimap maths (406-487) duplicates the desktop HUD's; two copies to keep in step.

### 1.10 Seam for a switchable presentation
- The script is one closure: state, remote calls, input wiring and instance construction are interleaved, and nothing is exported. It cannot host a second view without edits.
- **State and logic** a new view would repeat or share: `call`/`fire`/`loadingAction` helpers (70-72); teleport flow (233-256); profile cache, `vehicleRows`, filter and sort (268-305); `presentationOwners` and `majorMenu` visibility rules (318-331, 393-405); minimap maths and speed zoom (368-389, 406-487); cash presenter (335-345); rank attributes (125).
- **View only**: lines 40-69 helpers, 74-190 construction, `segmented`, `showSettings`, `showCash`, `makeCarCard`, `layout`.
- A new module can call the same remotes and bindables; nothing is private to this script. The shared pieces (`MapTileSet`, `FreeRoamMapPlayerMarkers`, `MapIconLayer`, `RouteGuide`, `GarageComponents.VehicleCard`, foundation cash and confirmation) are already modules.
- Cleanest switch: the composition root starts either this module or a new one (never both). Keeping this script byte-identical is then possible.
- **Must stay single-owner** (so the two presentations must never both run): the per-frame `RouteGuide.Update` call; writers of `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen`, `MobileControlMode`; the `FreeRoamVehicleSpawned`/`Exited` fires; the minimap layers; the ScreenGui name (the old script destroys any `MobileFreeRoamHud_Phase1` it finds at start).
- **Names other scripts look up**: ScreenGui `MobileFreeRoamHud_Phase1` with a descendant named `Minimap` (`FullMapUI:465-467`, gate for keyboard/controller map open); buttons named `Car`, `Garage`, `Race` and a frame named `CarPanel` (OnboardingClient 194, 209-215, 475, 614, 669); the three player attributes (MobileDriveControlsClient 197, GarageInteriorModeUI 273-276, FullMapUI 450, OnboardingClient 473-474).

---

## 2. MobileDriveControlsClient

### 2.1 Purpose and lifecycle
- On-screen driving controls in three modes (Arrows, Thumbstick, Tilt), writing `MobileDriveInputState`.
- Started by `ClientBase` (61-62); start-once; returns at 12 when not touch. No stop or cleanup. Destroys an earlier `MobileDriveControls_Phase1` at start (41).
- Connections kept: `InputBegan`/`InputEnded` per button (118-119); `UserInputService.InputEnded` twice (121, 142); `InputChanged` (141); `DeviceRotationChanged` (151); `MobileControlMode` attribute (172); `tiltRecenter.Activated` (150); `RenderStepped` (196).

### 2.2 Instance tree
```
ScreenGui "MobileDriveControls_Phase1"  IgnoreGuiInset=true ResetOnSpawn=false DisplayOrder=96 ZIndexBehavior=Sibling  (42)
  Frame "Root" scale 1,1, Visible=false until driving                                                                   (43)
    TextButton TurnLeft, TurnRight, DriftLeft, DriftRight   ("Arrow" visual: card + CardGradient + Art image)
    TextButton Accelerator, Brake                            ("Pedal" visual: transparent card + Art image)
    TextButton Boost -> BoostPlate (round, gradient), BoostIcon, Fallback
    TextButton ThumbstickHit -> OuterDriftRing -> InnerTurnRing, Knob, DriftLabel
    TextButton TiltDrift, TiltRecenter; TextLabel TiltStatus
```
About 50 instances, built once, never rebuilt.

### 2.3 Scaling and layout (177-192)
- Pixel offsets from `Camera.ViewportSize`, recomputed when the viewport changes (polled each frame, 178). No UIScale, no anchors except centred children.
- `tiny = vp.Y < 500`; `margin = tiny 10 | 16` (literal, does not read `EdgeMargin`); `unit = floor(clamp(vp.Y*.118, tiny 60 | 68, tiny 76 | 90))`; `gap = tiny 7 | 10`.
- Arrows: 2x2 block bottom-left, each `unit*ArrowWidthMultiplier(1.5)` wide by `unit` tall; drift row above turn row (180-184).
- Boost: 44 px (tiny) or 52 px square, centred above the arrow block with an 8/12 px gap (185).
- Thumbstick: `clamp(vp.Y*.265, 132, 188)` square, bottom-left (186).
- Tilt: Drift `unit*1.45` by `unit`; Recenter `unit*1.45` by `unit*.72`; status label 22 px above (187-188).
- Pedals: `PedalSize` attribute (live 125, fallback 104, minimum 44), bottom-right, `PedalRightOffset` 10, `PedalBottomOffset` 8, `PedalGap` 0; Brake to the left of Accelerator (189-191). **Pedals do not scale with the viewport.**
- Fallback text sizes are fixed (9 to 28) and only show if an image id is missing.

### 2.4 Config read
- `Config.UI.MobileFreeRoamHud` attributes: `ArrowCardOpacity`, `ArrowCardGradientRotation`, `ArrowImageOpacity`, `ArrowPressedOpacityBoost`, `ArrowWidthMultiplier`, `PedalCardOpacity`, `PedalImageOpacity`, `ControlPressedImageOpacityBoost`, `BoostPlateScale`, `BoostPlateGradientRotation`, `BoostIconScale`, `PedalSize`, `PedalBottomOffset`, `PedalRightOffset`, `PedalGap`, `TiltDeadzoneDegrees`, `TiltMaxDegrees`, `TiltSmoothing`, `DefaultControlMode`.
- `Config.UI.MobileFreeRoamHud.Assets`: `TurnArrowImage`, `DriftArrowImage`, `AcceleratorImage`, `BrakeImage`. `Config.UI.DesktopFreeRoamHud.Assets.BoostIcon`.
- `Config.Vehicles.MobileControls`: `DriftEnterThreshold`, `DriftExitThreshold` (132-133). The other attributes in that folder that describe this UI (`ThumbstickSizePixels`, `ThumbstickTravelRatio`, `ThumbstickInnerScale`, `ThumbstickOuterRingScale`, `PedalScale`, `HudLiftPixels`, `TouchHitAreaMultiplier`, `BoostToOuterRingBufferPixels`, `SteeringDeadzone`) are read by no script.
- Colours are **not** read from config: seven literals (22-28) repeat the desktop colour defaults.

### 2.5 Dependencies and API
- Writes `MobileDriveInputState`: `State.Accelerate/Brake/TurnLeft/TurnRight/DriftLeft/DriftRight/Boost`, `SetSteering(steer, drift)`, `AnalogDrift`, `Refresh()`. Reads `IsDriving`.
- Player attributes: reads and writes `MobileControlMode` (153, 166, 172-174); reads `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen` (197).
- Sets `ControlVisual` and `UIAudioSuppressClick` on its buttons (54, 95); `PresentationAudioClient:302` honours the second.
- No remotes. No public API.

### 2.6 Input
- `InputBegan`/`InputEnded` for `Touch` and `MouseButton1`, tracked per `InputObject` in `activeInputs` so multi-touch works (117-121).
- Thumbstick: one captured `InputObject`, drift latch with enter/exit thresholds (127-142).
- Tilt: `DeviceRotationChanged` roll against a calibrated neutral, dead zone and maximum from config, smoothed in `RenderStepped` (144-156, 200).
- No keyboard, no gamepad, no ContextActionService.

### 2.7 Per-frame work
`RenderStepped` (196-201): `layout()` early-out, three attribute reads, one `Visible` write, tilt smoothing in Tilt mode. Light.

### 2.8 Hard-coded style
- Seven colour literals (22-28); `Enum.Font.Michroma` (29).
- Raw `UICorner` (35) with radii 12/16/999 and raw `UIStroke` thickness 2/3 (36, 73): both bypass `Foundation.Corner` and `Foundation.StrokeWidth`, so theme changes to corner scale or stroke width never reach this script.
- Literal sizes: margins 10/16, gaps 7/10, boost 44/52, icon 32 px (92), thumb ratios .73/.28 (186), knob travel .34 (135).

### 2.9 Defects
1. No safe-area handling: 10/16 px margins and a 10 px pedal offset measured from the full viewport (179, 189-191). See 0.3.
2. Pedals and the boost plate are fixed pixels while arrows and thumbstick are viewport-proportional; proportions drift between phone and tablet.
3. Boost is 44 px when tiny (185) and Tilt Recenter is about 43 px when tiny (188): both under 48 px.
4. `updateThumb` resolves two `WaitForChild` chains to the config folder on every touch-move event (132-133).
5. Colours, corners and strokes bypass shared tokens (22-28, 35-36).
6. `not gui.Enabled` (197) tests this script's own ScreenGui, which nothing else disables: a dead condition.
7. Geometry is shared with other scripts by copying numbers, not by contract: the HUD Exit button repeats the 10/16 margin (`MobileFreeRoamHudUI:360`); onboarding finds the Boost button by name to shrink its cards (`OnboardingClient:624-631`).
8. About ten dead config attributes describe thumbstick and pedal sizes that the code ignores.

### 2.10 Seam
- Logic: button-to-state map (105-121), thumb maths (123-142), tilt (144-156), mode switching and `clearInputs` (158-174), the driving/menu gate (194-201). View: `controlButton`, `pressed`, the thumbstick frames, `layout`.
- Small and self-contained, but still one closure with no exports. A new presentation would be a new module that writes the same `MobileDriveInputState` contract and honours the same three player attributes; the composition root starts one or the other.
- **Single-owner**: one writer of `MobileDriveInputState.State` and the analog steer (two would fight every frame); `GameplayInputGate` also resets it.
- **Names other scripts look up**: `DriftLeft`, `DriftRight`, `Boost` (OnboardingClient 193, 208, 624).
- The arrow and pedal art are uploaded images; the restyle mostly touches the thumbstick rings, boost plate and tilt buttons. This is the lowest-value target in the group for a full second view.

---

## 3. OnboardingClient

### 3.1 Purpose and lifecycle
Five jobs in one closure:
1. Callout tutorial: "pages" of steps, each pinning a dimmer, gold border, connector and text bubble to live UI elements of other screens.
2. Objective cards (three objectives) top-left.
3. World guide trail to the dealership desk or the nearest garage desk (through `OnboardingGuideTrailRenderer`).
4. Locks the HUD shortcut buttons until their tutorial page has been seen (`applyLocks`, 666-671).
5. Triggers the first-drive controls modal on PC (`tryBeginFirstDriveControls`, 681-699).

Started by `ClientBase` (73-74), every platform, start-once, no stop. 19 `:Connect(`; only the per-target connections are disconnected (342-345). Prints a line on every begin/advance/complete.

### 3.2 Instance tree
```
ScreenGui "Onboarding"  IgnoreGuiInset=true ScreenInsets=None ClipToDeviceSafeArea=false ResetOnSpawn=false
                        DisplayOrder=max(1, LoadingSystem.DisplayOrder-10) = 990  ZIndexBehavior=Sibling          (82-83)
  Frame "Overlay" scale 1,1                                                                                        (84)
    TextButton Shade1..Shade4   black, DimTransparency .35, Active                                                 (87)
    TextButton "Advance"        full screen, transparent, Modal=true                                               (88)
    Frame "HighlightBorder"     Racing.Panel, transparent fill, gold Stroke + GlowStroke                           (89)
    Frame "Connector"           gold bar                                                                           (90)
    Frame "Bubble"              Racing.Panel -> "Copy" label, "Next" button                                        (91-94)
  Frame "Objectives" scale 1,1                                                                                     (85)
    CanvasGroup "Objective<n>" -> "Panel" (Racing.Panel) -> 4 labels      created and destroyed on demand          (505-515, 592)
```
About 25 static instances plus about 9 per objective card.

### 3.3 Scaling and layout
- Canvas is `overlay.AbsoluteSize` (225-230).
- **Scale is borrowed from the target.** `ownerScale` (235-246) walks up from each highlighted object and takes the first ancestor that has a `UIScale` child, clamped to `TutorialMinimumScale .38` .. `TutorialMaximumScale 1.08`. With no UIScale found: `LandscapePhoneScale .6` when the short side is at most 650 px, otherwise `clamp(min(X/1600, Y/900), .68, 1.08)`.
- Text size: `max(9 phone | 11 desktop, floor(TutorialTextSize 14 * scale + .5))` (247-251).
- Safe rectangle (264-276): `CalloutMarginPixels * scale` plus `GuiService:GetGuiInset()` (the top bar; not the device notch). The top bar is reserved on desktop only.
- Bubble (288-318): width from `TextService:GetTextSize(copy, textSize, Enum.Font.Michroma, ...)`; stacked layout when the safe width is under `TutorialStackedWidthPixels 560`; Next button `max(80, 104*scale)` by `max(44, 44*scale)`; placement tries Above/Below/Left/Right in an order chosen per step (`placement`, 80) and clamps into the safe rectangle.
- Dimmer: four rectangles around the padded target rectangle with `EdgeOverscanPixels` (360-364). Stroke widths scale with the borrowed scale (365-366).
- Re-layout triggers: overlay `AbsolutePosition`/`AbsoluteSize` (385-386); each target's `AbsolutePosition`, `AbsoluteSize`, `Visible`, `AncestryChanged` (394-397); a stability wait of `TargetStabilityFrames` frames before drawing (370-384).
- Objective cards (`refreshObjective`, 612-645, every 0.2 s): width `min(350*scale, safe width)`; height `98*scale` (min 68) on desktop or a fixed 48 px on phones; left safe edge; Y = `max(top, 66)` on desktop, or just under the HUD button it finds by name on phones; shrinks if the `Boost` button overlaps (624-631); inside an owned garage it hangs under `AccessControls` (634-640). Inner offsets are literals (524-535). Desktop text is multiplied by `ObjectiveDesktopTextMultiplier 1.5` (517).

### 3.4 Config read
- `Config.Player.Onboarding` attributes: `TutorialGold`, `DimTransparency`, `NextGradientTransparency`, `HighlightPaddingPixels`, `CalloutMarginPixels`, `EdgeOverscanPixels`, `TargetStabilityFrames`, `PageAbandonSeconds`, `LandscapePhoneShortSidePixels`, `LandscapePhoneScale`, `LandscapePhoneTextWidthRatio`, `LandscapePhoneShortcutWidthRatio`, `LandscapePhoneShortcutGapPixels`, `ShortcutCalloutGapPixels`, `TutorialTextSize`, `TutorialMinimumScale`, `TutorialMaximumScale`, `TutorialDesktopMinimumScale`, `TutorialDesktopMinimumTextSize`, `TutorialPhoneMinimumTextSize`, `TutorialMaximumTextWidth`, `TutorialStackedWidthPixels`, and 22 `Objective*` values.
- In the folder but unread: `MaximumTextSize`, `MinimumTextSize`, `ObjectivePhoneTopGapPixels`, `PageLossGraceSeconds`, `ShadeOverlapPixels`, `GuideTrailArrowLength`.
- `Config.UI.LoadingSystem.DisplayOrder` (82).
- Through `RacingUIComponents`: `Config.UI.Racing.Colours/Layout/Typography` (panel colour, corner radius, `FontFamily`).

### 3.5 Dependencies and API
- Remotes: `Remotes.Onboarding.OnboardingInvoke` actions `GetState` (750) and `MarkSeen {PageId}` (437); `OnboardingStateChanged.OnClientEvent` (725). The server validates page ids against an allow-list (`OnboardingServer:35, 61-67`), so page ids are saved state and must not be renamed.
- Bindables: listens to `FreeRoamVehicleSpawned` (713), `FreeRoamHudPresentationMode` (726), `LoadingPresentationChanged` (744); fires `OpenDrivingControlsFromOnboarding` (686-696).
- Attributes read: player `StartScreenActive`, `FullMapOpen`, `DrivingControlsOpen`, `OwnedGarageInside`, `GarageSessionActive`, `GarageSessionMode`, `RaceSessionActive`, `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen`; PlayerGui `OwnedGarageManagementOpen`; `LoadingPresentationState` `Active`, `Destination`. Written: player `FirstDrivePresentationPending` (689, 692).
- Workspace paths: `World.Dealership.Intro.Desk.GarageDeskTrigger` (660); any `DeskPromptAnchor` under a `ManagementDesk` (649-650); `World.Runtime.PlayerVehicles` (673).
- `PresentationAudioBridge.Emit("Objective.Complete")` (608).
- Writes onto other scripts' buttons: `Active`, `Selectable`, `AutoButtonColor` (669).
- Public API: none.

### 3.6 Input
- `Advance` (full-screen, `Modal=true`) and `Next` both call `advance` (451), debounced .18 s (442).
- Action steps (`N6`, `X3`, line 79) leave the target clickable and advance on the target's own `Activated` (398-404).
- No keyboard or gamepad path: nothing sets `GuiService.SelectedObject` and nothing binds a confirm key, so a controller-only player cannot advance a callout.

### 3.7 Polling and rebuilds
- One `RenderStepped` connection throttled to every 0.2 s (757) runs, for the whole session and for every player including fully onboarded ones:
  - `applyLocks()`: three full `playerGui:GetDescendants()` walks (668-670);
  - `refreshObjective()`: up to four `named()` walks, plus `majorMenuOpen()` (465-478: one more full walk, three `screenRoot` checks, two `visibleRoot` walks) whenever an objective is pending;
  - `updateGuideTrail()`: `nearestGarageDesk()` walks **`workspace:GetDescendants()`** (649) five times a second while the player is inside an owned garage and has not yet opened garage management;
  - `pollPages()`: one signal per unseen page, most of which are full PlayerGui walks (`named`, `workspacePage`), up to 19.
- Rough cost: a new player triggers on the order of 20 to 40 full PlayerGui walks per tick (100 to 200 per second); a finished player still triggers about 4 to 6 per tick. The cost grows with total GUI instance count. 14 `GetDescendants` call sites in the file.
- `scheduleResolve` retries every 0.08 s while a target is missing (411, 420, 428).
- Rebuilds: objective cards are created on enter and destroyed after the exit tween; the callout instances are reused.

### 3.8 Mobile differences
- `isLandscapePhone` (short side <= 650, no touch test) switches text minimum, width ratios, top-bar reservation and the compact 48 px objective card.
- `MobileDriving` page (drift and boost callouts) only when `TouchEnabled` (208). The PC first-drive controls modal only when not touch (682, 715).
- On phones the shortcut callouts use a tighter gap and narrower bubble (290, 300-304).

### 3.9 Hard-coded style
- `DEEP 10,14,23` (32), `TEXT 246,248,252` (33), hint text `190,196,210` (510), black shade (87), gold fallback `255,196,66` (31).
- `Enum.Font.Michroma` (34), used only for text measurement.
- Sizes: Next 104x44, padding 16, gap 14 (291); reference 1600x900 (245); objective Y 66 (615); phone and desktop card offsets (524-535); stroke widths 2/3/4 (89, 91, 365-366, 541).

### 3.10 How the tutorial finds UI: the coupling table

**Yes, onboarding is coupled to the current UI tree, almost entirely by instance name, with some matches on visible text and a few on attributes.** There is no registration API; the tutorial searches PlayerGui.

Lookup helpers: `named(name, root)` = first visible descendant with that `Name` (115-122); `buttonWithText(text, root)` = first visible `GuiButton` whose own or child text equals the string, case-insensitive (123-131); `screenRoot(name)` = enabled ScreenGui of that name (136-141); `workspacePage(id)` = visible GuiObject with attributes `TutorialWorkspace=true` and `TutorialPageId=id` (184-188); `cardGroup` / `visibleScrollerCards` = buttons with attribute `CanonicalGarageCard=true`, optionally filtered by `CanonicalGarageCardId` (154-183); `scopeRoot` stops at a ScreenGui child or at a frame named `CanonicalCanvas` (106-114).

| Page id (saved) | How the page is detected (202-222) | Step: what is highlighted (189-201) | Where the name is created today |
|---|---|---|---|
| `Dealership` | `CanonicalGarageGui.CanonicalCanvas.CanonicalGarageBrowser` visible **and** a visible label or button whose text is exactly `DEALERSHIP` (142-147) | G1 `Categories`; G4 `Stats`; A2 `Capacity`; G2 cards inside `VehicleScroller` | GarageComponents 300-304; GarageBrowserUI 27, 29, 31, 33, 36 |
| `CustomisationHome` | attributes `TutorialWorkspace` + `TutorialPageId` | J1/J2/J3: cards with `CanonicalGarageCardId` = `AddModules` / `UpgradeModules` / `PaintShop` | GarageWorkspaceUI 143, 246, 351; GarageUI 205 |
| `AddModules` | same attributes | K1 cards inside `TutorialCardScroller` | GarageWorkspaceUI 165; GarageUI 313 |
| `UpgradeModules` | same | L1 `Categories`; L2 `UpgradeBudget` | GarageWorkspaceUI 147, 175; GarageUI 452 |
| `PaintShop` | same | M1 `Categories` | GarageUI 627 |
| `MobileDriving` | touch and a visible `DriftLeft` | D7 `DriftLeft`, `DriftRight`; D8 `Boost` | MobileDriveControlsClient 84-85, 88 |
| `VehicleShortcut` | stage >= 2 and a visible `Car` | B2 `Car` | DesktopFreeRoamHudUI 863; MobileFreeRoamHudUI 135 |
| `GarageShortcut` | previous seen and a visible `Garage` | B3 `Garage` | Desktop 878; Mobile 135 |
| `RaceShortcut` | previous seen and a visible `Race` | B4 `Race` | Desktop 882; Mobile 135 |
| `RaceBrowser` | ScreenGui named `RaceBrowser` | N1 `CardContent`; N6 `TeleportToStart` (action step) | RaceBrowserClient 460, 543, 595 |
| `EventMode` | ScreenGui `RaceEntryPresentation` with buttons whose text is `TIME TRIAL` and `RACE` | O1 those two buttons, by text | RaceEntryPresentationClient 828 |
| `TimeTrialSetup` | visible `TierE` and `LapSelector` | Q1 `TierE`..`TierS`; Q5 `PrizeSummary`; Q8 `MedalTargets`; Q4 `LapSelector` | RaceEntryPresentationClient 387, 716, 747, 783 |
| `RaceSetup` | visible `RaceFormat` | P1 `RaceFormat` | RaceEntryPresentationClient 440 |
| `GarageBrowser` | ScreenGui `OwnedGarageBrowser` | X1 `GarageList`; X3 `Enter` (action step) | OwnedGarageBrowserUI 11, 22, 45 |
| `GarageHome`, `DisplayCars`, `GarageAssetFamilies`, `BuildStructure`, `BuildDecorations` | attributes | Z1-Z3 cards `DisplayCars`/`BuildGarage`/`StyleGarage`; AA1 `TutorialCardScroller`; AB1 cards `Structure`/`Decorations`/`Lighting`; AC1, AD1 `Categories` | GarageWorkspaceUI; OwnedGarageWorkspaceUI 126 |

Other name lookups outside the step table:
- `applyLocks` (666-671) sets `Active`/`Selectable`/`AutoButtonColor` on **every** `GuiButton` in PlayerGui named `Car`, `Race` or `Garage`, whatever screen it is on.
- `refreshObjective` uses `AccessControls` (GarageInteriorModeUI 12), then `Car`/`Race`/`Garage`, then `BoostButton`/`Boost` as layout references (613-624).
- `majorMenuOpen` uses `CarPanel` (Desktop 794, Mobile 150) and `ModalLayer` (Desktop 537) (475-476).
- `controlsOpen` walks the literal path `DesktopFreeRoamHud.DesignRoot.ModalLayer.Controls` (459-463).
- Dead alternates with no creator anywhere in the place: `DriftLeftButton`, `DriftRightButton`, `BoostButton`, `DetailColumn`.
- An unused better contract already exists: `GarageWorkspaceUI:165` sets attribute `TutorialTargetId="CardScroller"` on the scroller, and nothing reads it.

### 3.11 Defects
1. Name and text coupling as above. Any new view that renames, re-nests under a different ScreenGui name, changes the `DEALERSHIP` / `TIME TRIAL` / `RACE` labels, or drops the `Tutorial*`/`CanonicalGarageCard*` attributes silently loses its tutorial: the page never begins, or logs "waiting for target" and is abandoned after 3 s (417-419, 427).
2. `applyLocks` matches bare names. A new button called `Race`, `Car` or `Garage` anywhere (a tab, an action-bar tile, a mode switch) is disabled for every player who has not seen that shortcut page, and may be chosen as the highlight target.
3. Locked shortcut buttons have no visual state; only `Active` changes (669). Before `GetState` returns (retry loop 747-755) the buttons are inert for everyone, including returning players, and look normal.
4. Text is measured with `Enum.Font.Michroma` (292, 295, 298, 302) but drawn by `Racing.Label`, whose face comes from `Config.UI.Racing.Typography.FontFamily`. Changing the typeface makes every bubble the wrong size; a wider face would clip.
5. Callout scale depends on whether the target happens to sit under a `UIScale` (235-246). The style sheet asks for anchored clusters rather than one scaled canvas, which changes the answer for every callout.
6. Polling cost (757) and the workspace walk (649). See 3.7. Never switches off after onboarding is complete.
7. No controller path to advance a callout (3.6).
8. Next button minimum 44 px (291), under 48.
9. Objective cards sit top-left at a literal Y of 66 on desktop (615), where the style sheet puts the screen title on menus and the event card at a race start.
10. Hybrid of safe-area methods: reserves the top bar but not the device notch (270-276).

### 3.12 Seam
Two separate questions:

**A. Keeping the tutorial working on new views.** The new views must satisfy the lookup table: same ScreenGui names, same target names, same attributes, same three literal texts. That is cheap if written into the contract for each screen build and expensive if discovered afterwards. Structural changes in the style sheet that break steps even with names kept:
- "Customise: ... three tabs, removing the hub screen" removes the three hub cards that J1/J2/J3 highlight. `CustomisationHome` is a saved, allow-listed page id.
- Race entry tier rail, prize chip, medal rows and lap selector must keep `TierE`..`TierS`, `PrizeSummary`, `MedalTargets`, `LapSelector`, `RaceFormat`.
- The race menu's main button must stay `TeleportToStart`; the action bar tiles must stay `Car`, `Garage`, `Race`.
- Icon-only tabs or renamed titles break the three text matches.

**B. Restyling onboarding's own visuals.** Its panels, labels and Next button come from `RacingUIComponents.Panel/Label/Button`, so if those shared components take the new style behind the switch, the bubble and objective cards follow with no edit here. What does not follow: the gold accent, `DEEP`/`TEXT` literals, glow strokes passed explicitly (89, 91, 507), the Michroma measurement, and the literal card offsets.

- Logic that is not view: page tables and order (37-80, 223), resolvers and signals (189-222), server state and `markSeen`, gating (329-341, 728-744), first-drive trigger (677-719), guide-trail target choice (646-665).
- View: 82-94, `renderPinned`, `placeBubble`, `placeConnector`, objective card create/style/tween.
- **Single-owner**: one onboarding client only. Two would double `MarkSeen` calls, fight over `Active` on the shortcut buttons, both write `FirstDrivePresentationPending`, and both own `Workspace.ClientOnly.OnboardingGuideTrail` (the renderer destroys any existing folder of that name, `OnboardingGuideTrailRenderer:74`).
- No other script references the `Onboarding` ScreenGui or its children.

---

## 4. OnboardingGuideTrailRenderer

- World-space only: no GUI. A class (`Renderer.new(config)`, `SetTarget(part)`, `Clear()`, `Update(dt)`, `Destroy()`), constructed once by `OnboardingClient:28`.
- `new` connects `RenderStepped` permanently (67); `Update` returns immediately with no target (100). `Destroy` disconnects, but nothing calls it.
- Builds `Workspace.ClientOnly.OnboardingGuideTrail` on demand (70-86): a `DynamicBeam` folder with two anchor parts, two attachments and `AuraBeam`, `CoreBeam`, optional `ChevronBeam`; part arrows (up to `GuideTrailMaximumArrows`, three parts each) only when there is no chevron texture or `GuideTrailPartArrowsEnabled` is true. Live config has a chevron texture and part arrows off, so about 9 instances. Folder is destroyed on `Clear` and rebuilt on the next target.
- Config: about 30 `GuideTrail*` attributes on `Config.Player.Onboarding`, plus `TutorialGold`.
- Per frame while a target is set: about 14 `GetAttribute` reads (104-121), two CFrame writes, and three new `ColorSequence` objects assigned every frame (122) even though the colour does not change.
- Hard-coded: gold fallback (76, 121), beam brightness and segments (41-45), part thickness .16 (52-53).
- Restyle relevance: colour only (see 0.5). No scaling, input or mobile concerns. Leave as is; if the tutorial colour changes it is one attribute.

---

## 5. SharedTopNotificationUI and Foundation.CreateTopNotificationController

### 5.1 Purpose and lifecycle
- `SharedTopNotificationUI` (27 lines) is only a starter. It finds the `ShowTopNotification` BindableEvent in `PlayerScripts.Runtime.UI` (it already exists as a static instance in `StarterPlayerScripts.Runtime.UI`; the `Instance.new` fallback at 14 is not normally reached), calls `Foundation.CreateTopNotificationController(playerGui)` (17) and connects `event.Event -> controller.Show(message, duration)` (18-20).
- Started by `ClientBase` (78-79). `ActivityClient` (ClientBase 8) and `GarageUI` (91) declare it as a dependency by entry name.
- No stop. The controller is local to the closure; nothing else can reach it.
- Because the BindableEvent is static, callers that `WaitForChild` it never block; a notification fired before line 18 connects is lost.

### 5.2 Callers (the contract is `Fire(message, durationSeconds)`)
`MobileFreeRoamHudUI:38/78`, `DesktopFreeRoamHudUI:100`, `OwnedGarageBrowserUI:50`, `FullMapUI:92`, `GarageUI:681`, `GarageEntranceClient:96`, `RaceBrowserClient:452`, `ActivityClient:60`. The mobile HUD's `showToast(text, positive)` drops the positive/negative flag (78). `GarageInteriorModeUI` keeps a separate local toast (line 45), so this is not the only notification surface.

### 5.3 Instance tree (foundation 444-558)
```
ScreenGui "SharedTopNotification"  IgnoreGuiInset=true ResetOnSpawn=false DisplayOrder=1100   (449-454)
  Frame "Stack"  AnchorPoint (.5,0), AutomaticSize Y, UIListLayout (padding 6, centred)       (455-466)
    Frame "Message<n>"  + UICorner + UIGradient "GreyGradient" + TextLabel "Text"             (526-551)
```
Four instances per card, at most `TopNotificationMaxCards` cards (Theme value absent, so 3).

### 5.4 Scaling and layout
- `relayout()` (488-508) runs on `ViewportSize` change (510-515) and on every `show`.
- Two fixed profiles chosen by `Foundation.IsMobile()` = `TouchEnabled` (470-477):
  - touch: side 12, max width `min(vp.X-24, 280)`, min width 120, padding 22/14, text 12, min height 30;
  - other: side 24, max width `min(vp.X-48, 820)`, min width 170, padding 34/18, text 15, min height 38.
- Position: horizontally `vp.X*.5`, vertically `max(12, GuiInset.Y + 10)` (493).
- Card size from `TextService:GetTextSize` with `Enum.Font.Michroma` (480, 484); wraps when the measured width reaches the limit.
- No UIScale and no resolution scaling: 15 px text at 1280x720 and at 3440x1440.
- No enter or exit animation; cards appear and are destroyed after `clamp(duration or 2.5, .5, 10)` s (554).

### 5.5 Config read
`Config.UI.Theme`: `TopNotificationMaxCards` (not present), `CornerScaleMobile`/`CornerScaleDesktop` through `Foundation.Corner`. Nothing else; colours and sizes are literals.

### 5.6 Hard-coded style
Card `72,76,84` with gradient `105,109,117` to `48,52,60` (529, 538); white text (546); Michroma Bold (550); the two size profiles (472-477, 485).

### 5.7 Defects
1. Measured with `Enum.Font.Michroma` (regular) but drawn in Michroma **Bold** (550): the measured width is narrower than the drawn text, so long messages can truncate or wrap late. Also tied to the old typeface by literal.
2. Grey gradient card matches neither the old pink-outline style nor the new sheet; it is a third look.
3. No severity. Success and failure look the same; callers already know which it is.
4. No de-duplication: repeated identical messages stack up to the cap.
5. Fixed top-centre position collides with the planned in-race timer (style sheet: "Timer top-centre") and, at DisplayOrder 1100, draws over the loading screen and the tutorial dimmer.
6. Uses the full viewport centre while the ScreenGui is device-safe inset (see 0.3); only the top bar inset is considered.
7. No scaling with resolution; touch width capped at 280 px even on tablets.

### 5.8 Seam
- The cleanest seam in the group. The contract is already a bindable with two arguments; every caller is decoupled from the view.
- The whole view is one foundation function returning `{Gui, Show, Relayout, Count}`. A second controller with the same return shape can sit beside it, and the old one stays untouched as the backup.
- The switch point is line 17 of `SharedTopNotificationUI` (which controller to construct). That is a small edit to this starter rather than "untouched"; the alternative, a second starter module, must keep the lifecycle entry name `SharedTopNotificationUI` because two other entries depend on it by name.
- **Single-owner**: one listener on `ShowTopNotification` (two would show every message twice) and one ScreenGui named `SharedTopNotification` (the old controller destroys any existing one, 447-448).
- No script other than the foundation references the `SharedTopNotification` ScreenGui by name.

---

## 6. Shared components these scripts use today (and what they would need)

| Need | Used today | Gap |
|---|---|---|
| Panel / label / button | `RacingUIComponents.Panel/Label/Button` (onboarding, confirmation); local `panel`/`label`/`button` helpers in the mobile HUD (50-56); local `controlButton` in touch controls | The mobile HUD and touch controls build their own primitives; restyling the shared ones will not reach them |
| Vehicle card | `GarageComponents.VehicleCard` (mobile car panel 292, 301) | Already shared |
| Corners, strokes, bevel | `Foundation.Corner/StrokeWidth/StyleStroke/ApplyBevel` | Touch controls bypass them; the sheet wants corner scale 0 and no structural strokes, which these functions can express only if every caller uses them |
| Money and cash count-up | `Foundation.FormatFreeRoamMoney`, `CreateCashDisplayPresenter`, `BindReplicatedCash` | Already shared; presentation only |
| Confirmation | `Foundation.Confirmation` (teleport) | Already shared, with correct safe-area maths |
| Notification | `Foundation.CreateTopNotificationController` | One implementation, hard-coded look |
| Segmented control, dropdown, modal shell | Local to the mobile HUD (151-157, 178-196, 287-290) | No shared component; the desktop HUD has its own copies |
| Minimap | Shared layers, but the pan/rotate/zoom maths is copied in both HUDs | No shared minimap controller |
| Safe area / form factor | None shared | Needed before any new view |

## 7. Counts for the restyle estimate (this group only)

- Colour literals: 35 `Color3.fromRGB` (22 + 7 + 4 + 2 + 0) plus 3 in the notification controller. Of the mobile HUD's 22, 10 are config-backed fallbacks.
- Font literals: `Enum.Font.Michroma` in three scripts (as the face for all text in two, for measurement in one) plus three Michroma references in the notification controller and one in `StyleMetric`.
- `UDim2` constructors: 256 across the group, 164 of them `fromOffset`.
- Frame loops: 4 permanent `RenderStepped` connections (mobile HUD, touch controls, onboarding 0.2 s tick, guide trail) plus transient `RenderStepped:Wait()` loops in onboarding.
