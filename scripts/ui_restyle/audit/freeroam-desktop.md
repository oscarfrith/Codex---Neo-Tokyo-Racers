# UI restyle audit: group "freeroam-desktop"

Audited 2026-10-08, read-only, from live Studio source (Space Racers v3, placeId 93959280828322, Edit mode). Nothing was run in Play, so every runtime statement below is read from source, and instance counts are estimates from the build code.

Scripts in this group:

| Script | Lines | Chars | Status |
|---|---:|---:|---|
| `ReplicatedStorage.Modules.Game.UI.DesktopFreeRoamHudUI` | 1377 | 75,271 | Live owner of the PC free-roam HUD |
| `ReplicatedStorage.Modules.Game.Activities.ActivityClient` | 323 | 15,105 | Live owner of the Street Life activity HUD |
| `ReplicatedStorage.Modules.Game.UI.FreeRoamVehicleExitButtonClient` | 15 | 451 | Inert stub, builds nothing |

All three paths exist as given. Line numbers are the live Studio line numbers.

---

## Headline findings

1. **`DesktopFreeRoamHudUI` is one closure.** State, remotes, view construction, layout and the per-frame loop all live inside `Client.start()` (lines 5-1375). The only public function is `Client.start()`. Other scripts reach it through bindable events, attributes and instance names, never through a function call.
2. **The old HUD has no working off switch.** `readValue` (line 121-124) returns the fallback when a BoolValue is `false`, so `Config.UI.DesktopFreeRoamHud.Enabled = false` is ignored (line 1126). The switch to a new presentation has to happen at the composition root (ClientBase), not through that config value.
3. **`Core.FeatureFlags` is server-only.** It lives in `ServerStorage.Modules.Core.FeatureFlags` and reads `ServerStorage.Config` attributes and ConfigService. Client UI cannot require it. The style sheet's "one Core.FeatureFlags flag" needs a replicated carrier (for example the server writes an attribute on `ReplicatedStorage.Config.UI.Style`).
4. **The scale clamp is the main scaling defect.** `clamp(min(vw/1920, vh/1080), 0.72, 1.12)` (line 1055). The HUD is 84% of its intended relative size at 2560x1440 and 56% at 3840x2160; at 1280x720 the 9 to 13 px text becomes 6.5 to 9.4 px.
5. **The UI SCALE setting is decoration.** `makeSegmented(right, 130, "UI SCALE", {"85%","100%","115%"}, "100%")` (line 629) passes no callback, and `makeSegmented` returns before wiring clicks when there is none (line 495). `Defaults.UiScalePercent` and `HudOpacityPercent` are read by no script in the place. Only PASSENGERS and MINIMAP do anything in the settings modal.
6. **The car panel does use the shared vehicle card** (`GarageComponents.VehicleCard`, lines 744 and 775), but everything around the cards (title, dropdowns, grid, despawn button) is local code, and the panel has no backing surface.
7. **The Telemetry cluster is also the in-race speedometer.** `RaceSession` and `RaceQueue` fire the presentation event with `KeepTelemetry = true`, which hides everything in this HUD except the speed and boost gauge. Restyling the gauge changes the race HUD.
8. **`ActivityClient` is already close to a view/contract split.** It builds everything through `RacingUIComponents` and hands views a `ctx.UI` table. It can be restyled through the shared components without a fork.

---

# 1. DesktopFreeRoamHudUI

## 1.1 Purpose and lifecycle

- Owns the PC free-roam HUD: action bar, cash and rank, minimap, speed and boost gauge, Controls and Exit buttons, the "My vehicles" car panel, and three modals (Controls, Get Cash, Settings).
- **Started by** `StarterPlayer.StarterPlayerScripts.ClientBase` (entry at ClientBase lines 65-66, `dependencies = {}`) through `Core.ClientLifecycle.start`, which spawns every entry in its own thread and calls `feature.start()` once.
- **Device gate** (lines 16-19): returns early only when `TouchEnabled and not (KeyboardEnabled or MouseEnabled)`. `MobileFreeRoamHudUI` line 13 returns only when `not TouchEnabled`. On a device with touch and a keyboard or mouse, both HUD owners start.
- **Start sequence:** resolve config folders and remotes with `WaitForChild` (lines 23-44, 100) → `ensureGui()` (1298) builds everything → `updateLayout()` (1299) → cash presenter bound (1301-1327) → viewport listeners (1329-1335) → presentation listener (1337-1348) → FullMapOpen listener (1351-1353) → 13 legacy `UnbindFromRenderStep` calls (1355-1367) → `BindToRenderStep("PCFreeRoamHudPhase4A", 3000, updateRuntime)` (1368).
- **Stop and cleanup:** none. There is no stop function, the render step is never unbound, and no connection is stored for disconnect except the cash connection (1309). The ScreenGui is `ResetOnSpawn = false` and lives for the session. `ensureGui` destroys an existing `DesktopFreeRoamHud` before building (1039-1040).
- **Start guard:** module-level `state` (lines 4-7, 1373-1374). A second `start()` asserts unless the first reached `"ready"`. A failure inside start leaves `state = "failed"` and rethrows.
- **Connections kept for the session:** about 32 `:Connect` sites; at run time roughly 53 buttons each hold two hover connections (106), plus about 35 click and signal connections.

## 1.2 Instance tree

```text
PlayerGui.DesktopFreeRoamHud      ScreenGui  DisplayOrder 85, IgnoreGuiInset true, ResetOnSpawn false,
                                  ZIndexBehavior Sibling; attributes DesktopInputEligible, SuppressedByMajorMenu   (1041-1042)
  DesignRoot                      Frame, transparent, Position 0,0, Size set in offsets by updateLayout            (1043)
    UIScale                       rootScale                                                                        (1044)
    ActionBar                     Frame 364x54, top-right; UIListLayout horizontal, right-aligned, 8 px gap        (860-861)
      Car (116x54), Garage, Race, Dealership, Settings (54x54)   TextButton + Icon ImageLabel 30x30                (863-890)
    LeftCluster                   Frame 245x293, AnchorPoint (0,1), bottom-left                                    (894)
      Money                       panel 245x40: Amount label, Plus button 32x30                                    (895-911)
        RankStrip                 Frame at y -26, 22 px tall: Rank, Xp, XpTrack > XpFill                           (913-918)
      Minimap                     CanvasGroup 245x245 at y 48, UICorner 9, ClipsDescendants                        (929-930)
        MapRotator > MapPanCarrier (+UIScale) > MapCanvas      tiles (MapTileSet, 4x4 grid), route lines           (932-937)
        MapMissing, PlayerMarker, other-player markers, map icons, RouteButton (invisible, opens full map),
        NorthArrow, EdgeLeft / EdgeRight / EdgeTop / EdgeBottom (48 px gradient fades)                             (938-975)
    BottomActions                 Frame 360x38, AnchorPoint (0.5,1): Controls 150x32, Exit 170x32                  (978-984)
    Telemetry                     Frame 420x250, AnchorPoint (1,1): BoostIconContainer, BoostTrack > BoostFill,
                                  Mph, Unit, GaugeSegment1..16                                                     (1010-1033)
    CarPanel                      Frame, transparent, 500 wide, at (20, 88), ZIndex 12                             (794)
      Title, Category, Sort, VehicleGrid (ScrollingFrame) > CardContent > UIGridLayout + BuyMore + Vehicle_<id>,
      Despawn                                                                                                      (796-836)
    ModalLayer                    Frame full size, ZIndex 40, hidden                                               (537)
      Backdrop (TextButton), Controls 900x550, Cash 840x650, Settings 980x650                                      (538-641)
    ChoiceList                    dropdown surface, created and destroyed on demand, ZIndex 30                     (709)
```

Teleport confirmation is not in this tree: `Foundation.Confirmation` builds its own ScreenGui `SharedConfirmationOverlay` at DisplayOrder 1250 (Foundation lines 326-336).

**Estimated instance count at start-up: about 610.**

| Part | Instances | Note |
|---|---:|---|
| Root, action bar, left cluster, minimap chrome, bottom buttons, telemetry | ~160 | 16 map tiles and 32 gauge instances included |
| Car panel chrome | ~32 | plus about 17 per card when open |
| Controls modal | ~109 | 11 key rows, each a full button (7 instances) plus a label |
| Get Cash modal | ~99 | four pack cards, each a full panel (9) |
| Settings modal | ~210 | 22 segmented buttons at 7 instances each |

About 420 of the 610 (69%) are modal contents built at start-up and hidden. Per-element cost of the local helpers: `button()` = 7 instances and 2 connections (TextButton, UICorner, bevel Frame with UICorner and UIGradient, two UIStrokes); `panel()` = 9 instances (Frame, UICorner, UIGradient, two UIStrokes, FacetPattern with three facets).

## 1.3 Scaling and layout

- **Reference canvas:** 1920x1080 from `Layout.BaseWidth` / `BaseHeight` (line 1054).
- **Scale formula** (1055): `scale = clamp(min(viewport.X / 1920, viewport.Y / 1080), MinScale 0.72, MaxScale 1.12)`, applied to one `UIScale` on `DesignRoot`.
- **Logical canvas** (1057-1059): `DesignRoot.Size = viewport / scale` in offsets. Clusters are then positioned in logical pixels from the logical width and height, so corner clusters do stay on the screen edges on ultrawide. This part is sound.
- **Anchoring** (1060-1070): ActionBar at `(logicalW - 364 - 20, 18)`; LeftCluster at `(20, logicalH - 20)` with anchor (0,1); BottomActions at `(logicalW / 2, logicalH - 20)`; Telemetry at `(logicalW - 20, logicalH - 20)` with anchor (1,1). All recomputed in script on every viewport change. No `UDim2` scale anchoring, no layout objects except the action bar list and the car grid.
- **Sizing style:** 134 `UDim2.fromOffset`, 44 `UDim2.new`, 22 `UDim2.fromScale`. Everything inside a cluster or modal is an absolute pixel offset.
- **Clamps:** scale 0.72 to 1.12; car panel height `max(620, logicalH - panelTop - 20)` (1083); boost bar width min 80, height min 6 (1073-1074); marker and north arrow min 8 (1063-1065).
- **Text:** fixed `TextSize` everywhere, scaled only by the root UIScale. No `TextScaled`, no `UITextSizeConstraint`, no minimum after scaling. Sizes come from `Typography` values (Heading 22, Body 14, Button 13, Caption 11, Metric 64, MetricUnit 20, CashMetric 18) and from literals 9, 10, 11, 12, 15, 18, 19, 24, 27.
- **Safe area:** none. `IgnoreGuiInset = true` and the layout uses `camera.ViewportSize`, not the ScreenGui's `AbsoluteSize`. On PC this is harmless. On any device with safe-area insets the right and bottom clusters would be placed against the raw viewport.
- **Viewport change:** `ViewportSize` changed signal calls `updateLayout` (1330), a camera swap rebinds (1331-1335), and the render step also compares the viewport every frame and calls `updateLayout` on a difference (1119-1120). So layout is triggered twice per change.
- **Result at common sizes:**

| Viewport | Raw scale | Applied | Effect |
|---|---:|---:|---|
| 1280x720 | 0.667 | 0.72 | HUD 8% larger than proportional; Caption 11 → 7.9 px, literal 9 → 6.5 px |
| 1920x1080 | 1.00 | 1.00 | Reference |
| 2560x1080 | 1.00 | 1.00 | Clusters on edges, correct |
| 2560x1440 | 1.33 | 1.12 | HUD 84% of proportional |
| 3440x1440 | 1.33 | 1.12 | Same, clusters on edges |
| 3840x2160 | 2.00 | 1.12 | HUD 56% of proportional; minimap 274 px on a 2160 px screen |

- **Dropdown placement** (707-709): converts the anchor's `AbsolutePosition` to logical pixels once when opened. It does not follow a later viewport change and has no click-outside close.

## 1.4 Config read

`ReplicatedStorage.Config.UI.DesktopFreeRoamHud`:

- `Enabled` (1126). Ineffective when false, see defect D1.
- `Colours` (all 13): Outline, OutlineSoft, Panel, PanelSoft, PanelDeep, PanelBlue, ElectricBlue, Telemetry, HighSpeed, Danger, Disabled, Muted, Text. 136 `C("...")` call sites.
- `Layout` NumberValues (63 `L("...")` sites): ProfileRefreshSeconds, ModalDimTransparency, DropdownGap, CardTopSafePadding, CardStrokeSafePadding, CarPanelWidth, CarPanelTop, CarPanelBottomMargin, CarHeaderHeight, CardGap, EdgeMargin, TopMargin, ActionButtonSize, ActionGap, MinimapSize, CashHeight, MapPlayerIconSize, MapNorthArrowSize, MapNorthArrowMargin, BaseWidth, BaseHeight, MinScale, MaxScale, BoostBarOffsetX, BoostBarOffsetY, BoostBarWidth, BoostBarHeight, BoostBarSmoothing, BoostIconSize, BoostIconGap, MapPixels, MapCalibrationPixels, MapCalibrationStuds, MapVisibleStuds, MapWorldCenterX, MapWorldCenterZ, MapCoordinateRotationDegrees, MapRotationOffsetDegrees, MapSmoothing, SpeedGaugeMaxMph (live value 180; code fallback 260).
- `Layout` speed-zoom keys MapSpeedZoomEnabled / StartMph / FullMph / MaxFactor / OutResponse / InResponse (137-148) are looked up as child values, but in the place they are **attributes** on the Layout folder. They are never found; the code fallbacks happen to equal the attribute values. Not read by this script: MapViewportFieldOfView.
- `Assets`: CarIcon, GarageIcon, RaceIcon, DealershipIcon, SettingsIcon, BoostIcon, MapPlayerIcon, MapNorthArrow. Map tiles come through `MapTileSet` (Config.UI.MapTiles, 4x4 grid).
- `Defaults`: MapFlipX, MapFlipZ, MapPlayerIconRotates. Not read by any script: Category, Graphics, HudOpacityPercent, Lighting, Minimap, MusicPercent, SfxPercent, Sort, SpeedUnit, UiScalePercent.
- `Typography`: PrimaryFont, BodyFont (both "Michroma"), the seven role sizes, and `<Role>Bold` / `<Role>Italic` booleans (only ButtonBold is true).
- `Effects`: GradientTransparency, GlowTransparency, ButtonGradientStrength, ButtonGradientRotation, PatternTransparency, ButtonTransparency, DropdownTransparency, PanelTransparency, MinimapEdgeOpacity.

Other config:

- `Config.Racing.PresentationPerformance.PauseFreeRoamMapDuringRace` (1142).
- `Config.UI.FreeRoamMapPlayerMarkers` attributes UseRelativeCanvasTransform, MapPanSubpixelFactor, MapPanResponse (1155-1156, 1194), plus whatever that module reads itself (MapRotationMode, MapNorthArrowMode and so on).
- `Config.UI.Theme` through `ResponsiveUIFoundation`: CornerScaleDesktop / Mobile, stroke widths, BevelStrength, BevelRotation, CashCountAnimationEnabled, CashCountDurationSeconds, CashCountEveryDollarLimit, CashCountLargeIncreaseMaximumSteps, FreeRoamCashUseFullFormatting.
- `Config.UI.Racing` (Colours, Layout, Typography) indirectly: the vehicle cards and the teleport confirmation are drawn by `RacingUIComponents`, so the car panel mixes two colour folders.
- `ReplicatedStorage.Assets.VehiclePreviews.Categories` model attributes CockpitId, TemplateId, DisplayName, MenuImage, CockpitImage, Price (650-685).

## 1.5 Dependencies and public API

**Public API:** `Client.start()` only. No functions for other modules, no returned handles.

**Remotes**

| Remote | Use | Line |
|---|---|---|
| `Remotes.Garage.GarageInvoke` | `GarageCatalogClient.Fetch(garageInvoke, {})` for profile and catalogue | 353 |
| same | `"SpawnOwnedVehicleFromFreeRoam"` `{VehicleId, CockpitId}` | 748 |
| same | `"DespawnVehicle"` | 829 |
| same | `"ExitVehicle"` | 1002 |
| `Remotes.UI.FreeRoamHudTeleportInvoke` | `"TeleportToDealership"` | 519 |
| `Remotes.Activities.ActivityInvoke` | `"SetPassengerAccess"` `{Access}` | 612 |
| `Remotes.Garage.GarageInteriorInvoke` | looked up, never used | 41 |

**Bindables in `PlayerScripts.Runtime.UI`**

| Name | Direction | Line |
|---|---|---|
| `LoadingTransitionInvoke` (BindableFunction) | invoke `Begin` / `Complete` / `Fail` | 40, 416-421, 517-528 |
| `ShowTopNotification` | fire (all toasts) | 100, 364-366 |
| `FreeRoamVehicleSpawned` | fire after a successful spawn | 749 |
| `FreeRoamVehicleExited` | fire on teleport, despawn, exit | 522, 828, 1001 |
| `OpenOwnedGarageBrowser`, `OpenRaceBrowser` | fire from action bar | 879, 883 |
| `OpenDrivingControlsFromOnboarding` | listen; opens Controls, optional first-drive reveal | 986-994 |
| `FreeRoamHudPresentationMode` | listen | 1337-1348 |

**Attributes and replicated state**

- Player, read: GarageSessionActive (380), PassengerAccess (598, 607, 617), MinimapMode (632), Rank / XpIntoRank / XpForNext (920-926), FullMapOpen (1116, 1351), OwnedGarageInside (1132).
- Player, written: DrivingControlsOpen (434, 470), FirstDrivePresentationPending (459, 990), MinimapMode (634).
- PlayerGui, read: OwnedGarageManagementOpen (1125).
- Vehicle model, read: OwnerUserId (402).
- `leaderstats.Cash` IntValue (1310-1318).
- Own ScreenGui, written: DesktopInputEligible (1042), SuppressedByMajorMenu (1127). No script reads either.

**Modules required:** GarageCatalogClient, RacingUIComponents (passed to Confirmation only), RouteGuide, ResponsiveUIFoundation, VehicleDisplayNames, GarageComponents, MobileDriveInputState, GameplayInputGate, MapTileSet, FreeRoamMapPlayerMarkers, MapIconLayer, and FullMapUI on minimap click (960-962). Also `RouteGuide.Arrived` (964).

**Speed and boost telemetry path**

1. `DrivingClient.updateExistingDriveUi` (DrivingClient 830-846) applies the HUD speed display curve and calls `context.PublishMobile(speedMph, state.Boost)`.
2. `DriveSessionClient` (lines 20-24) writes the shared module table `MobileDriveInputState`: `SpeedMph`, `BoostPercent` (0 to 100), `IsDriving = true`.
3. The HUD polls that table every render frame (1278-1293). Boost eases toward `BoostPercent / 100` at `BoostBarSmoothing` (14) and sets `BoostFill.Size`. Speed is `SpeedMph` while `IsDriving`, otherwise `AssemblyLinearVelocity.Magnitude * 0.625` of the vehicle root. The gauge lights `floor(speed / SpeedGaugeMaxMph * 16 + 0.5)` segments; segments above 82% use HighSpeed pink, the rest Telemetry cyan.

No event, attribute or signal is involved: it is a shared table read once per frame. "Driving" for HUD purposes means the local humanoid sits in a VehicleSeat under a Model whose `OwnerUserId` is the player (395-408), so passengers get no telemetry. The unit is always MPH.

**Cash count animation**

`Foundation.CreateCashDisplayPresenter(render)` (Foundation 134-208; HUD 1301-1327). `leaderstats.Cash.Value` changes call `presenter:SetTarget`. Increases animate over `CashCountDurationSeconds` (0.4 s, clamped 0.15 to 0.75) in at most `CashCountLargeIncreaseMaximumSteps` (20) steps, or dollar by dollar when the gain is at most `CashCountEveryDollarLimit` (12). Decreases and the first value snap. It runs on `task.wait`, not a frame loop, and a generation token cancels a superseded run. The render callback sets the HUD amount and the Get Cash modal's `BalanceChip` text. Formatting is `Foundation.FormatFreeRoamMoney` (full grouped digits while `FreeRoamCashUseFullFormatting` is true). The presenter is reusable as-is by a new view.

**How other screens hide or suppress this HUD**

| Mechanism | Who triggers | Effect | Line |
|---|---|---|---|
| `FreeRoamHudPresentationMode` with `KeepTelemetry = false` | RaceBrowser, RaceEntry, RaceResults, OwnedGarageBrowser, LoadingTransition (ReplicatedFirst), GarageInteriorTransitionUI, FullMapUI | Whole ScreenGui disabled; car panel, dropdown and modal closed | 1114, 1337-1348 |
| same with `KeepTelemetry = true` | RaceSession, RaceQueue, legacy string `"Racing"` | Only Telemetry stays; action bar, left cluster and bottom buttons hidden; map paused | 1133-1142 |
| Player attribute `FullMapOpen` | FullMapUI | ScreenGui disabled; dropdown and modal closed (not the onboarding Controls) | 1116, 1351-1353 |
| Poll every 0.1 s: `GarageSessionActive`, or a visible descendant named GarageRoot / DealershipRoot / CustomisationRoot / CustomizationRoot in any enabled ScreenGui | Garage and dealership screens | ScreenGui disabled | 377-393, 1121-1128 |
| PlayerGui attribute `OwnedGarageManagementOpen` | OwnedGarageWorkspaceUI | ScreenGui disabled | 1125-1128 |
| Player attribute `OwnedGarageInside` | Owned garage | Hides Car, Garage, Race, Dealership buttons and the minimap; moves the cash panel into the minimap's slot | 1132-1137 |

Owners are tracked by name in `presentationOwners`, so overlapping owners release correctly.

## 1.6 Input

- Mouse only. `Activated` and `MouseButton1Click` on buttons; `MouseEnter` / `MouseLeave` for hover.
- No `GuiService`, no `ContextActionService`, no `InputBegan`, no `Selectable` or `NextSelection*` settings in this script. There is no keyboard shortcut for the modals (Escape does not close them here), no controller navigation and no selection highlight.
- Modals close by clicking the backdrop (543) or their Done / Close button. The first-drive Controls reveal blocks backdrop close (442) and holds a `GameplayInputGate` token `"FirstDriveControls"` (991) until NEXT is pressed.
- Opening Settings or Get Cash does not gate driving input.
- Full map: a click on the minimap (958-963). Keyboard and controller opening is owned by FullMapUI, which checks that a descendant named `Minimap` is showing in this ScreenGui (FullMapUI 464-478).

## 1.7 Per-frame work and rebuild patterns

`updateRuntime(dt)` runs every render frame at priority 3000 for the whole session (1113-1296, bound at 1368).

Every frame:

- Presentation and FullMapOpen checks, then `gui.Enabled = true` (1117) followed by `gui.Enabled = enabled` (1128).
- Viewport comparison (1119-1120).
- `gui:SetAttribute("SuppressedByMajorMenu", ...)` (1127).
- `ownedVehicleSeat()` (1130).
- About 14 visibility and position writes whether or not anything changed (1133-1141).
- `despawnButton.BackgroundColor3` (1276), even with the car panel closed.

Every frame while the map is live (1142-1264): about 27 config lookups (`FindFirstChild` on a 41-child folder each), three attribute reads, tile culling, canvas position, rotator rotation, `mapPlayerMarkers:Step`, `mapIcons:Step`, `RouteGuide.Update`, `routeRenderer:Step`. If the vehicle has no PrimaryPart, `vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)` runs twice per frame (1145, 1283).

Every frame while driving (1277-1294): boost easing, `Mph` text, and for all 16 gauge segments a colour lookup, a `BackgroundColor3` write and a `BackgroundTransparency` write, whether or not the lit count changed. In total about 45 config `FindFirstChild` lookups per frame while driving.

Every 0.1 s: `isMajorMenuOpen()` (377-393) loops every ScreenGui in PlayerGui and, for each enabled one, runs up to four recursive `FindFirstChild(name, true)` searches.

Rebuild patterns:

- **Car panel** (`renderCars`, 754-791): destroys every card and recreates all of them on open, on category change and on sort change. Each card is about 17 instances. Before that, `rowsFromProfile` calls `cockpitModel` once per owned vehicle, and `cockpitModel` walks every descendant of `VehiclePreviews.Categories` (650-661). That folder currently holds **9,302 descendants and 440 models**, so ten owned vehicles means about 93,000 iterations with string work on each model, on the click.
- Opening the panel also forces a profile fetch (869), a yielding remote call; the panel is shown before the data returns.
- **Dropdown** (`showChoice`, 700-724): the list surface is created and destroyed each time.
- **Modals:** built once at start-up, shown and hidden.
- **Minimap:** persistent; tiles culled by visibility.

## 1.8 Mobile and touch

- Not built on touch-only devices (16-19); `MobileFreeRoamHudUI` owns those. The two share `Config.UI.DesktopFreeRoamHud` Colours, Layout, Assets, Defaults and Effects, so a config change here also changes the phone HUD.
- Touch plus keyboard or mouse: both owners start (see 1.1). Not verified in Play.
- `Foundation.IsMobile()` is `TouchEnabled`, so on such a device this HUD would use the mobile corner and stroke values.
- Hit targets are below 48 px: Plus button 32x30, Controls and Exit 32 tall, dropdown rows 34, strip-style segmented buttons 36.

## 1.9 Hard-coded colours, fonts and sizes

- **Colours:** 11 `Color3.fromRGB` and 3 `Color3.new`. Five are fallbacks for config colours (208, 278, 291, 321, 332); two are white text fallbacks (264, 284); one is the black modal backdrop (540); six are the tier colours E to S (694-696), which are not in config. Every other colour is a `C("...")` read, 136 sites, using the legacy names (Outline, Telemetry, ElectricBlue, PanelBlue and so on), not the five new roles.
- **Fonts:** `Enum.Font.Michroma` as the default at 46, 47, 170, 171; the real family comes from `Typography.PrimaryFont` / `BodyFont` as an `Enum.Font` name. `fontFace` (173-178) can only produce Regular or Bold, Normal or Italic, so SemiBold and ExtraBold are not expressible. `Foundation.StyleMetric` (Foundation 216-218) forces the cash label to the Michroma family file regardless of config.
- **Text sizes as literals:** 15 (546, 547, 585, 586), 12 (552, default at 265), 11 (556, 620, 621), 10 (551, 641, 916), 9 (569), 27 (574), 24 (575), 19 (910), 18 (1013).
- **Geometry as literals:** modal shells 900x550 (545), 840x650 (560), 980x650 (584); pack cards 375x215 on a 395x230 grid (567); card 220x194 (744, 775, 819); dropdown 220x64 (727); telemetry 420x250 (1010); gauge centre (302,133), radius 92, 16 segments of 10x26 over 92° to -70° (1024-1030); bottom bar 360x38 (978); edge fades 48 px (972-975); corner radii 3, 5, 6, 7, 8, 9; icon 30x30 (846).
- **Copy:** all strings are literals in the build code, including the four cash pack prices (563).

## 1.10 Defects

Scaling

- **D1. `readValue` cannot return false** (121-124): `item and item.Value ~= nil and item.Value or fallback` yields the fallback for a false BoolValue. Consequences: `Enabled = false` is ignored (1126); `PauseFreeRoamMapDuringRace = false` is ignored (1142); `MapPlayerIconRotates = false` is ignored (1223); `MapSpeedZoomEnabled = false` could not work even if it were a value (137).
- **D2. Scale clamp** (1055, config MinScale 0.72, MaxScale 1.12): HUD too small above 1080p and text too small at 720p. See the table in 1.3. The style sheet's "Label never below 11 px after scaling" is not met at any size below 1920x1080.
- **D3. UI SCALE and most settings do nothing** (590-593, 627-630, 636, 639): Graphics, Lighting, Camera shake, Reduce flashes, UI scale, Speed unit, the three sliders and Reset Defaults have no behaviour. The sliders are static frames.
- **D4. Speed-zoom tuning is dead** (137-148 against attributes on the Layout folder).
- **D5. Layout reads the camera viewport, not the ScreenGui size** (1052), so it ignores any safe-area inset.

Alignment and consistency

- **D6. Car panel has no backing surface** (794, `BackgroundTransparency = 1`): title, dropdowns and cards sit directly on the 3D scene.
- **D7. Opening the car panel hides cash, rank and the minimap** (866, 1135). The style sheet wants the cash chip in the same place on every screen.
- **D8. Local duplicates of shared components:** `panel`, `button`, `label`, `neutralSurface` (256-336), `makeSegmented` (483-506), `slider` (619-626), `showChoice` and `dropdownButton` (700-732). `GarageComponents` already has `AnchoredDropdown`, `AttachDropdownChevron`, `Panel` and `ActionButton`; `RacingUIComponents` has `Panel`, `Label`, `Button`.
- **D9. Selected state is carried only by stroke and fill colour** through `setAccent`, which looks up children named `Stroke` and `GlowStroke` (231-236, 500-501, 602-603, 867). A style with no strokes loses the state silently.
- **D10. Typographic role is guessed from the number** (`roleForSize`, 180-185): a literal size that happens to equal a config size takes that role's weight.
- **D11. Controls modal rows do not line up:** driving rows step 52 px, on-foot rows step 58 px (554-555). Settings divider is at x 489 while the columns end at 445 and start at 520 (587-589).
- **D12. Key caps and the balance chip are full interactive buttons** with hover effects and no action (550, 561).
- **D13. Dropdown list is fixed where it opened** and has no click-outside close (707-709).
- **D14. Card size argument is ignored:** cards are built at 220x194 (744, 775) and the grid resizes them to 226x198 (1100-1102).
- **D15. Two colour sources in one panel:** panel chrome from `DesktopFreeRoamHud.Colours`, cards from `Racing.Colours`.
- **D16. `cockpitModel` matches by substring** (657): the first model whose id contains the target wins, which can pick the wrong name or image.

Performance

- **D17. `gui.Enabled` is set true then false every frame** while a garage, dealership or owned-garage management screen is open (1117, 1128).
- **D18. Config is re-read every frame** by name lookup, about 45 lookups per frame while driving (1137-1291); nothing is cached.
- **D19. Gauge writes 32 properties per frame** regardless of change (1290-1293).
- **D20. `isMajorMenuOpen` polling** (377-393): recursive name searches across PlayerGui ten times a second, and the cheap `GarageSessionActive` check sits inside the loop instead of before it.
- **D21. Car panel open cost** (650-661, 754-778): full scan of 9,302 descendants per owned vehicle, then destroy and rebuild of every card, on open, filter and sort.
- **D22. Three modals built at start-up** (536-643): about 420 instances most sessions never show.
- **D23. Recursive root search per frame** when a vehicle has no PrimaryPart (1145, 1283). `PresentationPerformance.HudMapSubjectResolveSeconds` exists but this script does not use it.

Housekeeping

- Unused locals: `kit` (23), `garageRemotes` (37), `interiorInvoke` (41), `suppressLegacyDesktop` (423), `cachedCatalog` (written only), `_positive` (364).
- 13 legacy `UnbindFromRenderStep` calls for retired phase names (1355-1367).
- Camera swap adds a viewport listener without dropping the old one (1331-1335).
- Hybrid device double start (16-19 with MobileFreeRoamHudUI 13).

## 1.11 Seam for a switchable presentation

**What is state and logic**

| Concern | Lines |
|---|---|
| Config readers and font resolution | 121-192 |
| Profile fetch and cache | 341-362 |
| Major-menu detection, owned-seat test | 368-408 |
| Bindable and loading helpers | 410-421 |
| Modal state machine, including first-drive reveal, input gate token, DrivingControlsOpen, FirstDrivePresentationPending | 424-473 |
| Teleport flow (confirm, loading begin / complete / fail, remote) | 508-534 |
| Passenger access setting; MinimapMode | 594-618, 632-635 |
| Car rows: category, model lookup, sort and filter | 645-698, 758-774 |
| Spawn, despawn, exit calls with the `busy` guard | 746-751, 825-836, 996-1008 |
| Rank attributes | 919-927 |
| Per-frame: visibility rules, minimap maths, telemetry | 1113-1296 |
| Cash binding | 1301-1327 |
| Presentation owners and FullMapOpen | 1337-1353 |

That is roughly 450 lines.

**What is view construction**

| Concern | Lines |
|---|---|
| Primitive helpers (`new`, `corner`, `stroke`, gradients, glow, facet pattern, `label`, `button`, `neutralSurface`, `panel`) | 194-336 |
| Modal shells, segmented control, slider, all modal contents | 475-506, 536-643 |
| Dropdown | 700-739 |
| Car card and panel | 743-752, 775-778, 793-838 |
| Action bar and main HUD | 840-1036 |
| `ensureGui`, `updateLayout` | 1038-1111 |

The two are interleaved: view functions capture the state locals directly, and `updateRuntime` writes view properties inline. There is no boundary to plug a second view into without editing this script.

**Recommended seam**

- Leave `DesktopFreeRoamHudUI` byte-identical as the backup.
- Add a sibling module (for example `UI.PulseFreeRoamHudUI`) and choose between the two in ClientBase, where the entry's `path` is resolved (ClientBase 65-66 and 105-109). One of the two starts per session, which matches the style sheet's "takes effect on the next Play start". Selecting at the root is the only place that leaves the old script untouched, because the old script has no working off switch (D1).
- The new module can call everything the old one calls. Every dependency is reachable from outside the old script: the three remotes, the bindables in `PlayerScripts.Runtime.UI`, the attributes, `MobileDriveInputState`, `GameplayInputGate`, `Foundation.CreateCashDisplayPresenter`, `Foundation.Confirmation`, `GarageComponents.VehicleCard`, `MapTileSet`, `FreeRoamMapPlayerMarkers`, `MapIconLayer`, `RouteGuide`. Nothing is private except local functions.
- Structure the new module as a small controller (the 450 lines of logic, copied and cleaned) plus a view built from the shared components, so the phone HUD can later use the same controller.
- Cost: the logic exists twice while the backup exists. A behaviour fix has to be applied to both, or the backup is declared frozen.

**What must stay single-owner** (never run both HUDs in one session)

- The ScreenGui named `DesktopFreeRoamHud`: `ensureGui` destroys any existing one, and other scripts look it up by name.
- The per-frame `RouteGuide.Update(position)` call (1250). Exactly one HUD owner steps it; FullMapUI takes over while the full map is open (FullMapUI 815). If the old HUD does not run, the new one must call it.
- The listener for `OpenDrivingControlsFromOnboarding`, the writes to `DrivingControlsOpen` and `FirstDrivePresentationPending`, and the `"FirstDriveControls"` input gate token. Two responders would double-open; none would leave onboarding waiting.
- Spawn, despawn, exit and teleport callers behind one `busy` flag.
- Firing `FreeRoamVehicleSpawned` and `FreeRoamVehicleExited` (DriveSessionClient starts and stops driving on them).
- The `RouteGuide.Arrived` toast (964) and the `MinimapMode` writer.
- The render step name `PCFreeRoamHudPhase4A`.

**Other scripts that depend on this script's instance names**

| Script | Depends on | Line |
|---|---|---|
| OnboardingClient | `DesktopFreeRoamHud` > `DesignRoot` > `ModalLayer` > `Controls` | 459-463 |
| OnboardingClient | any visible object named `CarPanel` or `ModalLayer` (major-menu test) | 475-476 |
| OnboardingClient | visible objects named `Car`, `Race`, `Garage` as tutorial targets, and as the reference for objective card position and scale | 209-215, 614 |
| FullMapUI | `DesktopFreeRoamHud` with a showing descendant named `Minimap` | 464-478 |

`MobileFreeRoamHudUI` uses the same child names in its own tree. A new view that keeps the ScreenGui name and these child names (`DesignRoot`, `ModalLayer`, `Controls`, `CarPanel`, `Car`, `Garage`, `Race`, `Minimap`) needs no change in those scripts. Moving the action bar or changing its scale moves the onboarding objective cards with it.

---

# 2. ActivityClient

## 2.1 Purpose and lifecycle

- Street Life activity HUD owner: job strip, offer card, countdown, world beacons, rank-up card. Mounts four views and forwards server events to them. Presentation only.
- **Started by** ClientBase (lines 6-8) with dependency `SharedTopNotificationUI`.
- **Start:** resolves remotes and modules (14-30), builds the theme table (33-43), ensures the inert `OpenJobs` bindable (52-57), builds the ScreenGui and scaled root (71-88), builds the job strip (97-111), defines the factories, publishes `Client.Context` (289), mounts `CourierClientView`, `PassengerClientView`, `TaxiClientView`, `DuelClientView` in that order (291-303), connects `ActivityEvent` (305-314).
- **Stop and cleanup:** none. Offer, countdown and rank-up cards destroy themselves. Six connections are kept.

## 2.2 Instance tree

```text
PlayerGui.ActivityHud     ScreenGui  DisplayOrder 84, IgnoreGuiInset true, ResetOnSpawn false, ZIndexBehavior Sibling   (73)
  DesignRoot              Frame, transparent                                                                            (78)
    UIScale                                                                                                             (79)
    JobStrip              panel 560x44 (460x44 mobile), top-centre, y 18 (8 mobile), ZIndex 20: Text, Cancel            (99-107)
    Offer                 panel 560x170 (520 mobile), bottom-centre, y -190 (-150 mobile), ZIndex 30:
                          Title, Body, Option1..n, Timer                                              (on demand, 140-186)
    Countdown             panel 220x220 at (0.5, 0.42), ZIndex 40: Number, Label                      (on demand, 190-216)
    RankUp                panel 420x170 at (0.5, 0.36), ZIndex 45: Kicker, Rank, Reward, UIScale      (on demand, 252-268)
workspace.CurrentCamera.ActivityBeacon_<id>   Neon cylinder Part + PointLight (world, not UI)                           (220-233)
```

Persistent instances: about 20. Each transient card adds 15 to 40.

## 2.3 Scaling and layout

- Same pattern as the HUD, with the numbers written into the script (83): desktop `clamp(min(vw/1920, vh/1080), 0.72, 1.12)`, mobile `clamp(vh/720, 0.55, 1)`. Root size is `viewport / scale` (85).
- Cards use scale anchors for position (top-centre, bottom-centre, 0.42 and 0.36 of height) and offsets for size, so they stay centred at any aspect ratio.
- Text is fixed `TextSize` through `UI.Label` / `UI.Button`: 12, 13, 16, 17, 44, 96.
- No safe-area handling.
- Viewport listener is connected only to the camera that exists at start (88).

## 2.4 Config read

- None directly. Colours come through `RacingUIComponents.Colour` from `Config.UI.Racing.Colours` for 13 names: Panel, PanelDeep, PanelSoft, PanelBlue, Outline, OutlineSoft, Telemetry, ElectricBlue, HighSpeed, Danger, Text, Muted, Disabled (35-43), each with a literal fallback.
- `RacingUIComponents` supplies panel transparency, corner radius, typography sizes and the font family (`Racing.Typography.FontFamily`, default Michroma).

## 2.5 Dependencies and public API

- **Remotes:** `Remotes.Activities.ActivityInvoke` (`"Cancel"` here; views send their own actions through `ctx.Invoke`), `Remotes.Activities.ActivityEvent` (handles `Type = "Rank:Up"` here, forwards every payload to each view's `OnEvent`).
- **Bindables:** creates `OpenJobs` in `PlayerScripts.Runtime.UI` if missing (inert); fires `ShowTopNotification`.
- **Attributes:** player FullMapOpen (75-77), RaceQueueActive (245); vehicle RaceParticipant, RaceRunId (250).
- **Public API:** `Client.start()` and `Client.Context`:

```text
ctx = { Player, Invoke, Gui, Root, IsMobile, Theme, RouteGuide, Toast,
        UI = { Button, Label, Strip = { Set, Clear }, Offer, Countdown, Beacon },
        Jobs = { AddEntry, Refresh } }        -- Jobs is a kept no-op
```

- **What the views use** (counted from source): `ctx.UI.Strip.Set/Clear`, `ctx.UI.Offer`, `ctx.UI.Countdown`, `ctx.UI.Beacon`, `ctx.UI.Button`, `ctx.Root` (DuelClientView only), `ctx.Toast`, `ctx.Invoke`, `ctx.RouteGuide`, and `ctx.Theme.Telemetry / HighSpeed / ElectricBlue / PanelDeep / Text`. `JobClient` (used by the taxi and courier views) takes the same context.

## 2.6 Input

- Mouse and touch through `Activated` only. No keyboard, no controller selection, no ContextActionService.

## 2.7 Per-frame work and rebuilds

- Idle: nothing per frame.
- Countdown: one `RenderStepped` connection while a card exists, writing text and colour every frame (201-215), self-disconnecting.
- Rank-up: a 1 s poll while a race is presenting, up to 600 s (255).
- Offer: one tween for the timer bar and one `task.delay`.
- Offer, countdown and rank-up are created and destroyed per use; the strip is persistent and toggles `Visible`.

## 2.8 Mobile and touch

- `isMobile = TouchEnabled and not KeyboardEnabled` (32), a third definition beside the two HUD gates.
- Mobile scale floor 0.55: 12 px text becomes 6.6 px and the 48 px offer buttons become 26 px on a 390 px tall phone.
- Strip cancel button is 44x30 on mobile (36x30 desktop), below the 48 px target before scaling.

## 2.9 Hard-coded colours, fonts and sizes

- 13 `Color3.fromRGB` fallbacks (36-39). `FONT = Enum.Font.Michroma` (33) is stored in `theme.Font`; no view reads it.
- Text sizes: 13 (104), 12 (106, 149, 165), 17 (148), 96 (197), 13 (199, 260), 44 (261), 16 (263).
- Sizes: strip 560/460x44, cancel 36/44x30, offer 560/520x170 with 20 px padding and 10 px gap, option buttons 44/48 tall, timer bar 3 px, countdown 220x220, rank-up 420x170, beacon 260x6x6.
- Rank-up reward text uses ElectricBlue for cash (263); the new style uses Yellow for cash.

## 2.10 Defects

- **A1.** Scale constants duplicated from the HUD config instead of read from it (83); the same too-small-above-1080p clamp applies.
- **A2.** Viewport listener bound to the first camera only (88).
- **A3.** Hidden only by `FullMapOpen` (75-77). It does not listen to `FreeRoamHudPresentationMode` or the garage attributes, so the strip and offer card are not suppressed by race menus, garage screens or loading; they rely on being under those screens at DisplayOrder 84.
- **A4.** Strip colour is applied by finding a child named `Stroke` on the shared panel (119-120). A panel style with no stroke drops the cue.
- **A5.** Mobile scale floor and 30 px cancel button (see 2.8).
- **A6.** Job strip sits at top-centre, y 18. The new in-race timer is also top-centre; whether they can show together was not checked.

## 2.11 Seam

- This script is already split: visuals come from four factories (`panel` → `UI.Panel`, `UI.Label`, `UI.Button`, local `new`), and views only see `ctx`.
- If `RacingUIComponents.Panel / Label / Button / Colour` become style-aware behind the switch, this HUD and its four views restyle with no fork. What remains local is the literal sizes and positions, the `Stroke` lookup (A4), the timer bar, the countdown number and the rank-up card.
- Keep the `ctx` shape and the names `ActivityHud` and `DesignRoot`. No other script references this script's instance names (searched: `ActivityHud`, `JobStrip`, `Offer`, `Countdown`, `RankUp`).
- Single owner: the `ActivityEvent` connection and the mounted views. Do not start a second copy.

---

# 3. FreeRoamVehicleExitButtonClient

- 15 lines. `Client.start()` returns immediately with the comment "Superseded by the canonical isolated mobile HUD/control owners" (8-9).
- Builds no instances, reads no config, uses no remotes, has no input, per-frame work, colours or sizes.
- Still listed in ClientBase (67-68), so it reports `ready` at start-up.
- No restyle work. It can stay as it is; removing the entry is a separate retirement decision.

---

# 4. Notes for the restyle plan

- **Gauge and minimap are shared with racing.** The Telemetry cluster is what the player sees in a race, and `RaceSessionPresentationClient` reads `DesktopFreeRoamHud.Layout` and `.Assets` for its own map. Build steps 3 (free-roam HUD) and 4 (in-race HUD) cannot be verified separately for the gauge.
- **Phone HUD shares this config.** `MobileFreeRoamHudUI`, `GarageWorkspaceUI`, `GarageBrowserUI`, `MobileDriveControlsClient`, `FullMapUI`, `MapTileSet` and `LoadingTransitionRuntime` all read `Config.UI.DesktopFreeRoamHud`. Keep that folder unchanged for the old style and put new values in the new Style folder, as the sheet already says.
- **Layout moves that touch logic.** The sheet moves cash to a top-right status cluster and rank beside the map. Today cash, rank and minimap are one cluster, the car panel replaces that cluster, and the per-frame code repositions the cash panel inside the owned garage (1137). These rules need restating for the new layout, not copying.
- **Round minimap.** The existing CanvasGroup clip with a UICorner supports a round map; the four edge-fade frames (968-975) assume a square and would be replaced by the ring image.
- **Performance budget.** The sheet asks for no new frame loops and instance counts within 10% of today. A new view can come in well under today's 610 by building modals on first open, and can drop most per-frame cost by caching config, writing the gauge only when the lit count changes, and replacing the 0.1 s menu poll with the attributes and presentation events that already exist.
- **Scaling rule to settle.** Either raise or remove the 1.12 ceiling, or scale by height alone with a per-cluster minimum text size. A working UI SCALE setting would multiply that base scale; today nothing stores or applies it.

# 5. Not verified

- Nothing was observed in Play. Instance counts, the double-HUD case on touch plus keyboard devices, and the `gui.Enabled` toggling are read from source.
- Whether Roblox's default player list overlaps the top-right action bar. `leaderstats` exists and no script disables the PlayerList CoreGui (the only `SetCoreGuiEnabled` call is in the trailer dev tool).
- Internals of `MapTileSet`, `MapIconLayer`, `FreeRoamMapPlayerMarkers`, `RouteGuide` and `GameplayInputGate` beyond the calls made from this script.
- `MobileFreeRoamHudUI` beyond its start gate and its use of the shared config and presentation event.
